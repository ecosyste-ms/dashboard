class Collection < ApplicationRecord
  include EcosystemsApiClient
  
  has_many :collection_projects, dependent: :destroy
  has_many :projects, through: :collection_projects

  has_many :issues, through: :projects
  has_many :commits, through: :projects
  has_many :tags, through: :projects
  has_many :packages, through: :projects
  has_many :advisories, through: :projects

  belongs_to :user

  scope :visible, -> { where(visibility: 'public') }


  before_validation :set_name_from_source
  validate :at_least_one_import_source
  
  validates :github_organization_url, format: { with: %r{\Ahttps://github\.com/[^/]+/?\z}, message: "must be a valid GitHub organization URL" }, allow_blank: true
  validates :collective_url, format: { with: %r{\Ahttps://opencollective\.com/[^/]+/?\z}, message: "must be a valid Open Collective URL" }, allow_blank: true
  validates :github_repo_url, format: { with: %r{\Ahttps://github\.com/[^/]+/[^/]+/?\z}, message: "must be a valid GitHub repository URL" }, allow_blank: true


  def set_name_from_source
    return if name.present?

    self.name =
      github_organization_url&.sub(%r{\Ahttps://}, '') ||
      collective_url&.sub(%r{\Ahttps://}, '') ||
      github_repo_url&.sub(%r{\Ahttps://}, '') ||
      (dependency_file.presence && "SBOM from upload")
  end

  def at_least_one_import_source
    if github_organization_url.blank? &&
      collective_url.blank? &&
      github_repo_url.blank? &&
      dependency_file.blank?
      errors.add(:base, "You must provide a source: GitHub org, Open Collective URL, repo URL, or dependency file.")
    end
  end

  def to_param
    uuid
  end

  def import_projects_sync
    import_projects_with_mode
  end

  def import_projects_async
    ImportCollectionWorker.perform_async(id)
  end

  # Deprecated method for backwards compatibility
  def import_projects
    import_projects_async
  end

  private

  def import_projects_with_mode
    update_with_broadcast(import_status: 'importing', sync_status: 'pending', last_error_message: nil, last_error_backtrace: nil, last_error_at: nil)
    
    if respond_to?(:github_organization_url) && github_organization_url.present?
      import_from_github_org
    elsif respond_to?(:collective_url) && collective_url.present?
      import_from_opencollective
    elsif respond_to?(:github_repo_url) && github_repo_url.present?
      import_from_repo
    elsif respond_to?(:dependency_file) && dependency_file.present?
      import_from_dependency_file
    end
    
    update_with_broadcast(import_status: 'completed', sync_status: 'syncing')
    
    # Start background job to monitor individual project sync completion
    CheckCollectionSyncStatusWorker.perform_async(id)
  rescue StandardError => e
    Rails.logger.error "Error importing projects for collection #{id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    update_with_broadcast(
      import_status: 'error',
      sync_status: 'error',
      last_error_message: e.message,
      last_error_backtrace: e.backtrace.join("\n"),
      last_error_at: Time.current
    )
  end

  public

  def import_from_github_org
    return if github_organization_url.blank?
    uri = URI.parse(github_organization_url)
    org_name = uri.path.split("/")[1]
    import_github_org(org_name)
  end

  def import_from_opencollective
    return if collective_url.blank?
    uri = URI.parse(collective_url)
    org_name = uri.path.split("/")[1]
    
    oc_api_url = "https://opencollective.ecosyste.ms/api/v1/collectives/#{org_name}/projects"
    resp = Faraday.get(oc_api_url)
    if resp.status == 200
      data = JSON.parse(resp.body)
      urls = data.map { |p| p['url'] }.uniq.reject(&:blank?)
      urls.each do |url|
        puts url
        next if url.blank?
        
        begin
          project = Project.find_or_create_by(url: url)
          next unless project&.persisted?
          
          collection_projects.find_or_create_by(project: project)
          
          # Queue individual sync job for each project if it needs syncing
          if project.last_synced_at.blank?
            SyncProjectWorker.perform_async(project.id)
          end
          
          broadcast_sync_progress
        rescue => e
          Rails.logger.error "Error creating project for URL #{url}: #{e.message}"
          next
        end
      end
    else
      update_with_broadcast(import_status: 'error', sync_status: 'error')
    end
  end

  def import_from_repo
    repos_url = "https://repos.ecosyste.ms/api/v1/repositories/lookup?url=#{CGI.escape(github_repo_url)}"
    
    conn = Faraday.new do |f|
      f.options.timeout = 30  # 30 seconds timeout
      f.options.open_timeout = 10  # 10 seconds to establish connection
      f.request :retry, max: 3, interval: 2, backoff_factor: 2, 
                retry_statuses: [429, 500, 502, 503, 504],
                methods: [:get]
    end
    
    begin
      resp = conn.get(repos_url)
    rescue Faraday::Error => e
      Rails.logger.error "Error fetching repo lookup for #{github_repo_url}: #{e.message}"
      update_with_broadcast(import_status: 'error', sync_status: 'error')
      return
    end
    if resp.status == 200
      data = JSON.parse(resp.body)
      sbom_url = data['sbom_url']
      if sbom_url.present?
        sbom = conn.get(sbom_url)
        if sbom.status == 200
          json = JSON.parse(sbom.body)
          purls = Sbom.extract_purls_from_json(json)
          urls = Sbom.fetch_project_urls_from_purls(purls)
          urls.each do |url|
            puts "Importing project: #{url}"
            next if url.blank?
            
            begin
              project = Project.find_or_create_by(url: url)
              next unless project&.persisted?
              
              collection_projects.find_or_create_by(project: project)
              
              # Queue individual sync job for each project if it needs syncing
              if project.last_synced_at.blank?
                SyncProjectWorker.perform_async(project.id)
              end
              
              broadcast_sync_progress
            rescue => e
              Rails.logger.error "Error creating project for URL #{url}: #{e.message}"
              next
            end
          end
        else
          update_with_broadcast(import_status: 'error', sync_status: 'error')
        end
      end
    end
  end

  def import_from_dependency_file
    return if dependency_file.blank?
    
    begin
      # Create SBOM record to handle processing
      Sbom.create!(raw: dependency_file)
      
      # Parse the SBOM JSON
      json = JSON.parse(dependency_file)
      
      # Extract PURLs from the SBOM using the SBOM class method
      purls = Sbom.extract_purls_from_json(json)
      
      # Convert PURLs to project URLs using the SBOM class method
      urls = Sbom.fetch_project_urls_from_purls(purls)
      
      # Create projects for each URL
      urls.each do |url|
        puts "Importing project from SBOM: #{url}"
        next if url.blank?
        
        begin
          project = Project.find_or_create_by(url: url)
          next unless project&.persisted?
          
          collection_projects.find_or_create_by(project: project)
          
          # Queue individual sync job for each project if it needs syncing
          if project.last_synced_at.blank?
            SyncProjectWorker.perform_async(project.id)
          end
          
          broadcast_sync_progress
        rescue => e
          Rails.logger.error "Error creating project for URL #{url}: #{e.message}"
          next
        end
      end
      
      Rails.logger.info "Successfully imported #{urls.length} projects from SBOM dependency file"
      
    rescue JSON::ParserError => e
      Rails.logger.error "Error parsing SBOM JSON: #{e.message}"
      update_with_broadcast(import_status: 'error', sync_status: 'error', last_error_message: "Invalid SBOM file format: #{e.message}")
      raise e
    rescue => e
      Rails.logger.error "Error importing from dependency file: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      update_with_broadcast(import_status: 'error', sync_status: 'error', last_error_message: e.message, last_error_backtrace: e.backtrace.join("\n"))
      raise e
    end
  end


  def self.import_github_org(org_name, user:)
    collection = Collection.find_or_create_by(name: org_name, user: user) do |collection|
      collection.name = org_name
      collection.description = "Collection of repositories for #{org_name}"
      collection.user = user
    end
    collection.import_github_org(org_name)
  end

  def import_github_org(org_name)
    page = 1
    loop do
      conn = Faraday.new do |f|
        f.options.timeout = 30  # 30 seconds timeout
        f.options.open_timeout = 10  # 10 seconds to establish connection
        f.request :retry, max: 3, interval: 2, backoff_factor: 2, 
                  retry_statuses: [429, 500, 502, 503, 504],
                  methods: [:get]
      end
      
      begin
        resp = conn.get("https://repos.ecosyste.ms/api/v1/hosts/GitHub/owners/#{org_name}/repositories?per_page=100&page=#{page}")
        break unless resp.status == 200
      rescue Faraday::Error => e
        Rails.logger.error "Error fetching GitHub org repos for #{org_name}, page #{page}: #{e.message}"
        break
      end

      data = JSON.parse(resp.body)
      break if data.empty?

      urls = data.map{|p| p['html_url'] }.uniq.reject(&:blank?)
      urls.each do |url|
        puts url
        next if url.blank?
        
        begin
          project = Project.find_or_create_by(url: url)
          next unless project&.persisted?
          
          collection_projects.find_or_create_by(project: project)
          
          # Queue individual sync job for each project if it needs syncing
          if project.last_synced_at.blank?
            SyncProjectWorker.perform_async(project.id)
          end
          
          broadcast_sync_progress
        rescue => e
          Rails.logger.error "Error creating project for URL #{url}: #{e.message}"
          next
        end
      end

      page += 1
    end
  end

  def to_s
    name
  end

  def syncing?
    import_status == 'importing' || sync_status == 'syncing'
  end

  def ready?
    import_status == 'completed' && sync_status == 'ready'
  end

  def check_and_update_sync_status
    # Check if all projects have been synced
    total_projects = projects.count
    synced_projects = projects.where.not(last_synced_at: nil).count
    
    if total_projects == 0
      # No projects found during import - mark as ready
      update_with_broadcast(sync_status: 'ready')
    elsif synced_projects == total_projects
      # All projects have been synced - mark as ready
      update_with_broadcast(sync_status: 'ready')
    else
      # Still syncing projects - broadcast progress update
      broadcast_sync_progress
    end
  end

  def projects_sync_progress
    total = projects.count
    synced = projects.where.not(last_synced_at: nil).count
    { total: total, synced: synced }
  end

  def avatar_url
    ''
  end

  def last_synced_at
    nil
  end

  def last_commit_at
    projects.map(&:last_commit_at).compact.max
  end

  def latest_tag_name
    projects.select{|p| p.latest_tag.present? }.sort_by(&:latest_tag_published_at).last&.latest_tag_name
  end

  def latest_tag_published_at
    projects.map(&:latest_tag_published_at).compact.max
  end

  def links
    projects.map(&:links).flatten.uniq
  end

  def licenses
    projects.map(&:licenses).flatten.uniq
  end

  def collective
    nil # TODO: Fix this 🐉
  end

  def watchers
    projects.map(&:watchers).compact.sum
  end

  def forks
    projects.map(&:forks).compact.sum
  end

  def stars
    projects.map(&:stars).compact.sum
  end

  def direct_dependencies
    projects.map(&:direct_dependencies).flatten.uniq
  end

  def development_dependencies
    projects.map(&:development_dependencies).flatten.uniq
  end

  def transitive_dependencies
    projects.map(&:transitive_dependencies).flatten.uniq
  end

  def dependent_packages_count
    projects.map(&:dependent_packages_count).compact.sum
  end

  def dependent_repos_count
    projects.map(&:dependent_repos_count).compact.sum
  end

  def downloads
    projects.map(&:downloads).compact.sum
  end

  def broadcast_sync_progress
    begin
      data = {
        type: 'progress_update',
        progress: projects_sync_progress,
        sync_status: sync_status
      }
      
      Rails.logger.info "Broadcasting progress update for collection #{id}: #{data}"
      
      CollectionSyncChannel.broadcast_to(self, data)
    rescue => e
      Rails.logger.error "Error broadcasting progress update for collection #{id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  def test_broadcast
    Rails.logger.info "Sending test broadcast for collection #{id}"
    CollectionSyncChannel.broadcast_to(
      self,
      {
        type: 'test',
        message: 'Test broadcast from collection',
        timestamp: Time.current.iso8601
      }
    )
  end

  private

  def update_with_broadcast(attributes)
    update(attributes)
    broadcast_sync_update
  end

  def broadcast_sync_update
    begin
      html_content = ApplicationController.render(
        partial: 'collections/sync_status',
        locals: { collection: self }
      )
      
      data = {
        type: 'status_update',
        import_status: import_status,
        sync_status: sync_status,
        progress: projects_sync_progress,
        error_message: last_error_message,
        html: html_content
      }
      
      Rails.logger.info "Broadcasting sync update for collection #{id}: #{data.except(:html)}"
      
      CollectionSyncChannel.broadcast_to(self, data)
    rescue => e
      Rails.logger.error "Error broadcasting sync update for collection #{id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Fallback broadcast without HTML
      fallback_data = {
        type: 'status_update',
        import_status: import_status,
        sync_status: sync_status,
        progress: projects_sync_progress,
        error_message: last_error_message
      }
      
      CollectionSyncChannel.broadcast_to(self, fallback_data)
    end
  end
end

