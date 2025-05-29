class Collection < ApplicationRecord
  has_many :collection_projects, dependent: :destroy
  has_many :projects, through: :collection_projects

  has_many :issues, through: :projects
  has_many :commits, through: :projects
  has_many :tags, through: :projects
  has_many :packages, through: :projects
  has_many :advisories, through: :projects

  belongs_to :user

  scope :visible, -> { where(visibility: 'public') }

  after_create :import_projects

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

  def import_projects
    update(status: 'syncing')
    if respond_to?(:github_organization_url) && github_organization_url.present?
      import_from_github_org
    elsif respond_to?(:collective_url) && collective_url.present?
      import_from_opencollective
    elsif respond_to?(:github_repo_url) && github_repo_url.present?
      import_from_repo
    elsif respond_to?(:dependency_file) && dependency_file.present?
      import_from_dependency_file
    end
    update(status: 'ready')
  rescue StandardError
    update(status: 'error')
  end

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
    # fetch all projects from the Open Collective API
    oc_api_url = "https://opencollective.ecosyste.ms/api/v1/collectives/#{org_name}/projects"
    resp = Faraday.get(oc_api_url)
    if resp.status == 200
      data = JSON.parse(resp.body)
      urls = data.map { |p| p['url'] }.uniq.reject(&:blank?)
      urls.each do |url|
        puts url
        project = Project.find_or_create_by(url: url)
        project.sync_async unless project.last_synced_at.present?
        collection_projects.find_or_create_by(project: project)
      end
    end
  end

  def import_from_repo
    # TODO: implement GitHub repo import
  end

  def import_from_dependency_file
    # TODO: implement dependency file import
  end

  def self.import_github_org(org_name)
    collection = Collection.find_or_create_by(name: org_name) do |collection|
      collection.name = org_name
      collection.description = "Collection of repositories for #{org_name}"
    end
    collection.import_github_org(org_name)
  end

  def import_github_org(org_name)
    page = 1
    loop do
      resp = Faraday.get("https://repos.ecosyste.ms/api/v1/hosts/GitHub/owners/#{org_name}/repositories?per_page=100&page=#{page}")
      break unless resp.status == 200

      data = JSON.parse(resp.body)
      break if data.empty?

      urls = data.map{|p| p['html_url'] }.uniq.reject(&:blank?)
      urls.each do |url|
        puts url
        project = Project.find_or_create_by(url: url)
        project.sync_async unless project.last_synced_at.present?
        collection_projects.find_or_create_by(project: project)
      end

      page += 1
    end
  end

  def to_s
    name
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
end

