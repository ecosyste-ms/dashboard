class Project < ApplicationRecord
  include Stats

  has_many :collection_projects, dependent: :destroy
  has_many :collections, through: :collection_projects

  has_many :issues, dependent: :delete_all
  has_many :commits, dependent: :delete_all
  has_many :tags, dependent: :delete_all
  has_many :packages, dependent: :delete_all
  has_many :advisories, dependent: :delete_all

  belongs_to :collective, optional: true

  validates :url, presence: true, uniqueness: { case_sensitive: false }

  scope :active, -> { where("(repository ->> 'archived') = ?", 'false') }
  scope :archived, -> { where("(repository ->> 'archived') = ?", 'true') }

  scope :fork, -> { where("(repository ->> 'fork') = ?", 'true') }
  scope :source, -> { where("(repository ->> 'fork') = ?", 'false') }

  scope :language, ->(language) { where("(repository ->> 'language') = ?", language) }
  scope :owner, ->(owner) { where("(repository ->> 'owner') = ?", owner) }
  scope :keyword, ->(keyword) { where("keywords @> ARRAY[?]::varchar[]", keyword) }
  scope :with_repository, -> { where.not(repository: nil) }

  scope :with_packages, -> { where('packages_count > 0') }
  scope :without_packages, -> { where(packages_count: 0) }

  scope :order_by_stars, -> { order(Arel.sql("(repository ->> 'stargazers_count')::int desc nulls last")) }

  scope :between, ->(start_date, end_date) { where('projects.created_at > ?', start_date).where('projects.created_at < ?', end_date) }

  def self.purl_without_version(purl)
    PackageURL.new(**PackageURL.parse(purl.to_s).to_h.except(:version, :scheme)).to_s
  end

  def self.sync_least_recently_synced
    Project.where(last_synced_at: nil).or(Project.where("last_synced_at < ?", 1.day.ago)).order('last_synced_at asc nulls first').limit(1000).each do |project|
      project.sync_async
    end
  end

  def self.sync_all
    Project.all.each do |project|
      project.sync_async
    end
  end

  def to_s
    display_name
  end

  def repository_url
    repo_url = github_pages_to_repo_url(url)
    return repo_url if repo_url.present?
    url
  end

  def display_name
    url.gsub(/https?:\/\//, '').gsub(/www\./, '').gsub(/\/$/, '')
  end

  def stars
    return unless repository.present?
    repository['stargazers_count']
  end

  def forks
    return unless repository.present?
    repository['forks_count']
  end

  def watchers
    return unless repository.present?
    repository['subscribers_count']
  end

  def github_pages_to_repo_url(github_pages_url)
    match = github_pages_url.chomp('/').match(/https?:\/\/(.+)\.github\.io\/(.+)/)
    return nil unless match
  
    username = match[1]
    repo_name = match[2]
  
    "https://github.com/#{username}/#{repo_name}"
  end

  def first_created
    return unless repository.present?
    Time.parse(repository['created_at'])
  end

  def sync
    return if last_synced_at.present? && last_synced_at > 1.day.ago
    check_url
    fetch_repository
    fetch_packages
    if repository && uninteresting_fork?
      # Don't sync tags, commits or issues for uninteresting forks
    else
      fetch_readme
      sync_tags
      sync_advisories
      sync_issues
      sync_commits     
      fetch_dependencies 
      fetch_collective
    end
    return if destroyed?
    update_column(:last_synced_at, Time.now) 
    ping
  end

  def uninteresting_fork?
    return false unless repository.present?
    return false unless repository['fork']
    return false unless packages_count.zero?
    return false if repository['archived']
    return false if repository['stargazers_count'] > 10
    true
  end

  def sync_async
    SyncProjectWorker.perform_async(id)
  end

  def check_url
    url.chomp!('/')
    conn = Faraday.new(url: url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get
    return unless response.success?

    update!(url: response.env.url.to_s) 
    # TODO avoid duplicates
  rescue ActiveRecord::RecordInvalid => e
    puts "Duplicate url #{url}"
    puts e.class
    destroy
  rescue
    puts "Error checking url for #{url}"
  end

  def ping
    ping_urls.each do |url|
      Faraday.get(url) rescue nil
    end
  end

  def ping_urls
    ([repos_ping_url] + [issues_ping_url] + [commits_ping_url] + packages_ping_urls).compact.uniq
  end

  def repos_ping_url
    return unless repository.present?
    "https://repos.ecosyste.ms/api/v1/hosts/#{repository['host']['name']}/repositories/#{repository['full_name']}/ping"
  end

  def issues_ping_url
    return unless repository.present?
    "https://issues.ecosyste.ms/api/v1/hosts/#{repository['host']['name']}/repositories/#{repository['full_name']}/ping"
  end

  def commits_ping_url
    return unless repository.present?
    "https://commits.ecosyste.ms/api/v1/hosts/#{repository['host']['name']}/repositories/#{repository['full_name']}/ping"
  end

  def packages_ping_urls
    return [] if packages_count.zero?
    packages.map do |package|
      "https://packages.ecosyste.ms/api/v1/registries/#{package.registry_name}/packages/#{package.name}/ping"
    end
  end

  def packages_url(page: 1)
    "https://packages.ecosyste.ms/api/v1/packages/lookup?page=#{page}&repository_url=#{repository_url}"
  end
  
  def description
    return unless repository.present?
    repository["description"]
  end

  def repos_api_url
    "https://repos.ecosyste.ms/api/v1/repositories/lookup?url=#{repository_url}"
  end

  def repos_url
    return unless repository.present?
    "https://repos.ecosyste.ms/hosts/#{repository['host']['name']}/repositories/#{repository['full_name']}"
  end

  def fetch_repository
    conn = Faraday.new(url: repos_api_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get
    return unless response.success?
    self.repository = JSON.parse(response.body)
    self.keywords = combined_keywords
    self.save
  rescue
    puts "Error fetching repository for #{repository_url}"
  end

  def combined_keywords
    keywords = []
    keywords += repository["topics"] if repository.present?
    keywords += packages.map(&:keywords).flatten unless packages_count.zero?
    keywords.uniq.reject(&:blank?)
  end
  
  def timeline_url
    return unless repository.present?
    return unless repository["host"]["name"] == "GitHub"

    "https://timeline.ecosyste.ms/api/v1/events/#{repository['full_name']}/summary"
  end

  def language
    return unless repository.present?
    repository['language']
  end

  def language_with_default
    language.presence || 'Unknown'
  end

  def owner_name
    return unless repository.present?
    repository['owner']
  end

  def owner
    return unless repository.present?
    repository['owner']
  end

  def name
    return unless repository.present?
    repository['full_name'].split('/').last
  end

  def avatar_url
    return unless repository.present?
    repository['icon_url']
  end

  def repository_license
    return nil unless repository.present?
    repository['license'] || repository.dig('metadata', 'files', 'license')
  end

  def licenses
    (packages_licenses + [repository_license]).compact.uniq
  end

  def open_source_license?
    licenses.any?
  end

  def no_license?
    !open_source_license?
  end

  def dependent_packages_count
    return 0 if packages_count.zero?
    packages.select{|p| p.dependent_packages_count }.map{|p| p.dependent_packages_count || 0 }.sum
  end

  def dependent_repos_count
    return 0 if packages_count.zero?
    packages.select{|p| p.dependent_repos_count }.map{|p| p.dependent_repos_count || 0 }.sum
  end

  def archived?
    return false unless repository.present?
    repository['archived']
  end

  def active?
    return false if archived?
  end

  def fork?
    return false unless repository.present?
    repository['fork']
  end

  def download_url
    return unless repository.present?
    repository['download_url']
  end

  def archive_url(path)
    return unless download_url.present?
    "https://archives.ecosyste.ms/api/v1/archives/contents?url=#{download_url}&path=#{path}"
  end

  def blob_url(path)
    return unless repository.present?
    "#{repository['html_url']}/blob/#{repository['default_branch']}/#{path}"
  end 

  def raw_url(path)
    return unless repository.present?
    "#{repository['html_url']}/raw/#{repository['default_branch']}/#{path}"
  end 

  def no_funding?
    funding_links.empty?
  end

  def funding_links
    (repo_funding_links + package_funding_links + owner_funding_links + readme_funding_links).uniq
  end

  def package_funding_links
    return [] if packages_count.zero?
    packages.map(&:funding).compact.map{|f| f.is_a?(Hash) ? f['url'] : f }.flatten.compact
  end

  def owner_funding_links
    return [] unless owner
    return [] if owner["metadata"].blank?
    return [] unless owner["metadata"]['has_sponsors_listing']
    ["https://github.com/sponsors/#{owner['login']}"]
  end

  def repo_funding_links
    return [] if repository.blank? || repository['metadata'].blank? ||  repository['metadata']["funding"].blank?
    return [] if repository['metadata']["funding"].is_a?(String)
    repository['metadata']["funding"].map do |key,v|
      next if v.blank?
      case key
      when "github"
        Array(v).map{|username| "https://github.com/sponsors/#{username}" }
      when "tidelift"
        "https://tidelift.com/funding/github/#{v}"
      when "community_bridge"
        "https://funding.communitybridge.org/projects/#{v}"
      when "issuehunt"
        "https://issuehunt.io/r/#{v}"
      when "open_collective"
        "https://opencollective.com/#{v}"
      when "ko_fi"
        "https://ko-fi.com/#{v}"
      when "liberapay"
        "https://liberapay.com/#{v}"
      when "custom"
        v
      when "otechie"
        "https://otechie.com/#{v}"
      when "patreon"
        "https://patreon.com/#{v}"
      when "polar"
        "https://polar.sh/#{v}"
      when 'buy_me_a_coffee'
        "https://buymeacoffee.com/#{v}"
      when 'thanks_dev'
        "https://thanks.dev/#{v}"
      else
        v
      end
    end.flatten.compact
  end

  def issues_api_url
    "https://issues.ecosyste.ms/api/v1/repositories/lookup?url=#{repository_url}"
  end

  def sync_issues
    return unless repository.present?
    conn = Faraday.new(url: issues_api_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end
    response = conn.get
    return unless response.success?
    self.issues_last_synced_at = JSON.parse(response.body)['last_synced_at']
    self.save
    issues_list_url = JSON.parse(response.body)['issues_url'] + '?per_page=100'

    page = 1
    loop do
      paginated_issues_url = "#{issues_list_url}&page=#{page}"
      conn = Faraday.new(url: paginated_issues_url) do |faraday|
        faraday.response :follow_redirects
        faraday.adapter Faraday.default_adapter
      end
      response = conn.get
      return unless response.success?

      issues_json = JSON.parse(response.body)
      break if issues_json.empty? # Stop if there are no more issues

      # TODO: Use bulk insert
      issues_json.each do |issue|
        i = issues.find_or_create_by(number: issue['number']) 
        i.assign_attributes(issue)
        i.save(touch: false)
      end

      page += 1
      break if page > 50 # Stop if there are too many issues
    end
    
  rescue
    puts "Error fetching issues for #{repository_url}"
  end

  def commits_api_url
    "https://commits.ecosyste.ms/api/v1/repositories/lookup?url=#{repository_url}"
  end

  def sync_commits
    return unless repository.present?
    conn = Faraday.new(url: commits_api_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end
    response = conn.get
    return unless response.success?
    commits_list_url = JSON.parse(response.body)['commits_url'] + '?per_page=100&sort=timestamp'

    page = 1
    loop do
      paginated_commits_url = "#{commits_list_url}&page=#{page}"
      conn = Faraday.new(url: paginated_commits_url) do |faraday|
        faraday.response :follow_redirects
        faraday.adapter Faraday.default_adapter
      end
      response = conn.get
      return unless response.success?

      commits_json = JSON.parse(response.body)
      break if commits_json.empty? # Stop if there are no more commits

      # TODO: Use bulk insert
      commits_json.each do |commit|
        c = commits.find_or_create_by(sha: commit['sha']) 
        commit_attributes = commit.except('stats', 'html_url')
        commit_attributes['additions'] = commit['stats']['additions']
        commit_attributes['deletions'] = commit['stats']['deletions']
        commit_attributes['files_changed'] = commit['stats']['files_changed']
        c.assign_attributes(commit_attributes)
        c.save(touch: false)
      end

      page += 1
      break if page > 50 # Stop if there are too many commits
    end

  rescue
    puts "Error fetching commits for #{repository_url}"
  end

  def tags_api_url(page: 1)
    "https://repos.ecosyste.ms/api/v1/hosts/#{repository['host']['name']}/repositories/#{repository['full_name']}/tags?page=#{page}"
  end

  def sync_tags
    return unless repository.present?

    page = 1
    loop do
      conn = Faraday.new(url: tags_api_url(page: page)) do |faraday|
        faraday.response :follow_redirects
        faraday.adapter Faraday.default_adapter
      end
      response = conn.get
      return unless response.success?

      tags_json = JSON.parse(response.body)
      break if tags_json.empty? # Stop if there are no more tags

      tags_json.each do |tag|
        t = tags.find_or_create_by(name: tag['name'])
        tag_attributes = tag.slice('sha', 'kind', 'published_at', 'html_url')
        t.assign_attributes(tag_attributes)
        t.save(touch: false)
      end

      page += 1
      break if page > 50 # Stop if there are too many tags
    end
  rescue
    puts "Error fetching tags for #{repository_url}"
  end

  def sync_advisories
    return unless repository.present?

    page = 1
    loop do
      conn = Faraday.new(url: advisories_api_url(page: page)) do |faraday|
        faraday.response :follow_redirects
        faraday.adapter Faraday.default_adapter
      end
      response = conn.get
      return unless response.success?

      advisories_json = JSON.parse(response.body)
      break if advisories_json.empty? # Stop if there are no more advisories

      advisories_json.each do |advisory|
        a = advisories.find_or_create_by(uuid: advisory['uuid'])
        advisory_attributes = advisory
        a.assign_attributes(advisory_attributes)
        a.save(touch: false)
      end

      page += 1
      break if page > 50 # Stop if there are too many advisories
    end
  rescue
    puts "Error fetching advisories for #{repository_url}"
  end

  def advisories_api_url(page: 1)
    "https://advisories.ecosyste.ms/api/v1/advisories?page=#{page}&repository_url=#{repository_url}"
  end

  def last_activity_at
    return unless repository.present?
    return unless repository['pushed_at'].present?
    Time.parse(repository['pushed_at'])
    # TODO: Use issues updated_at
  end

  def last_commit_at
    return unless commits.present?
    commits.order('timestamp desc').first.timestamp
  end

  def latest_tag
    return unless tags.present?
    tags.order('published_at desc').first
  end

  def latest_tag_name
    return unless tags.present?
    latest_tag.name
  end

  def latest_tag_published_at
    return unless tags.present?
    latest_tag.try(:published_at)
  end

  def packages_homepage_urls
    packages.map(&:homepage_url).compact.uniq
  end

  def homepage_url
    return unless repository.present?
    return unless repository['homepage'].present?
    ([repository['homepage']] + packages_homepage_urls).compact.uniq
  end

  def documentation_urls
    packages.map(&:documentation_url).compact.uniq
  end

  def registry_urls
    packages.map(&:registry_url).compact.uniq
  end

  def links
    [
      url,
      homepage_url,
      documentation_urls,
      registry_urls,
      funding_links
  ].flatten.compact.uniq
  end

  def fetch_packages
    page = 1
    loop do
      conn = Faraday.new(url: packages_url(page: page)) do |faraday|
        faraday.response :follow_redirects
        faraday.adapter Faraday.default_adapter
      end

      response = conn.get
      return unless response.success?

      packages_json = JSON.parse(response.body)
      break if packages_json.empty? # Stop if there are no more packages

      packages_json.each do |pkg|
        p = packages.find_or_create_by(ecosystem: pkg['ecosystem'], name: pkg['name'])
        p.purl = pkg['purl']
        p.metadata = pkg.except('repo_metadata')
        p.save(touch: false)
      end

      page += 1
    end
  rescue
    puts "Error fetching packages for #{repository_url}"
  end

  def packages_count
    # TODO use counter cache instead
    packages.count
  end

  def advisories_count
    advisories.count
  end

  def monthly_downloads
    return 0 if packages_count.zero?
    packages.select{|p| p.downloads_period == 'last-month' }.map{|p| p.downloads || 0 }.sum
  end

  def downloads
    return 0 if packages_count.zero?
    packages.map{|p| p.downloads || 0 }.sum
  end

  def dependent_packages
    return 0 if packages_count.zero?
    packages.select{|p| p.dependents }.map{|p| p.dependents || 0 }.sum
  end

  def dependent_repositories
    return 0 if packages_count.zero?
    packages.select{|p| p.dependent_repos_count }.map{|p| p.dependent_repos_count || 0 }.sum
  end

  def dependents
    dependent_packages + dependent_repositories
  end

  def packages_licenses
    return [] if packages_count.zero?
    packages.map{|p| p.licenses }.compact
  end

  def purl_kind
    return unless repository.present?
    repository['host']['kind']
  end

  def project_purl
    return unless repository.present?
    PackageURL.new(
      type: purl_kind,
      namespace: owner_name,
      name: name
    ).to_s
  end

  def purls
    return if packages.blank?
    @purls ||= packages.map{|p| PackageURL.parse(p.purl) }
  end

  def self.find_by_purl(purl)
    package_url(purl.to_s).first
  end

  def readme_file_name
    return unless repository.present?
    return unless repository['metadata'].present?
    return unless repository['metadata']['files'].present?
    repository['metadata']['files']['readme']
  end

  def fetch_readme
    if readme_file_name.blank? || download_url.blank?
      fetch_readme_fallback
    else
      conn = Faraday.new(url: archive_url(readme_file_name)) do |faraday|
        faraday.response :follow_redirects
        faraday.adapter Faraday.default_adapter
      end
      response = conn.get
      return unless response.success?
      json = JSON.parse(response.body)

      self.readme = json['contents']
      self.save
    end
  rescue
    puts "Error fetching readme for #{repository_url}"
    fetch_readme_fallback
  end

  def fetch_readme_fallback
    file_name = readme_file_name.presence || 'README.md'
    conn = Faraday.new(url: raw_url(file_name)) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get
    return unless response.success?
    self.readme = response.body
    self.save
  rescue
    puts "Error fetching readme for #{repository_url}"
  end

  def readme_url
    return unless repository.present?
    "#{repository['html_url']}/blob/#{repository['default_branch']}/#{readme_file_name}"
  end

  def readme_urls
    return [] unless readme.present?
    urls = URI.extract(readme.gsub(/[\[\]]/, ' '), ['http', 'https']).uniq
    # remove trailing garbage
    urls.map{|u| u.gsub(/\:$/, '').gsub(/\*$/, '').gsub(/\.$/, '').gsub(/\,$/, '').gsub(/\*$/, '').gsub(/\)$/, '').gsub(/\)$/, '').gsub('&nbsp;','') }
  end

  def funding_domains
    ['opencollective.com', 'ko-fi.com', 'liberapay.com', 'patreon.com', 'otechie.com', 'issuehunt.io', 'thanks.dev',
    'communitybridge.org', 'tidelift.com', 'buymeacoffee.com', 'paypal.com', 'paypal.me','givebutter.com', 'polar.sh']
  end

  def readme_funding_links
    urls = readme_urls.select{|u| funding_domains.any?{|d| u.include?(d) } || u.include?('github.com/sponsors') }.reject{|u| ['.svg', '.png'].include? File.extname(URI.parse(u).path) }
    # remove anchors
    urls = urls.map{|u| u.gsub(/#.*$/, '') }.uniq
    # remove sponsor/9/website from open collective urls
    urls = urls.map{|u| u.gsub(/\/sponsor\/\d+\/website$/, '') }.uniq
  end

  def badges
    Rails.cache.fetch("badges:#{id}", expires_in: 1.month) do
      [
        fork_badge,
        archived_badge,
        package_badge,
        mature_age_badge,
        veteran_age_badge,
        new_age_badge,
        star_popularity_badge,
        download_popularity_badge,
        dependents_popularity_badge,
        high_contributors_badge,
        low_contributors_badge,
        active_badge,
        inactive_badge
      ].compact
    end
  end

  def fork_badge
    return unless fork?
    {
      label: 'Fork',
      class: 'warning'
    }
  end

  def archived_badge
    return unless archived?
    {
      label: 'Archived',
      class: 'danger'
    }
  end

  def package_badge
    return if packages_count.zero?
    {
      label: 'Package',
      class: 'info'
    }
  end

  def mature_age_badge
    return unless first_created.present?
    return unless first_created < 5.year.ago
    return unless first_created > 10.year.ago
    {
      label: 'Mature',
      class: 'success'
    }
  end

  def veteran_age_badge
    return unless first_created.present?
    return unless first_created < 10.year.ago
    {
      label: 'Veteran',
      class: 'primary'
    }
  end

  def new_age_badge
    return unless first_created.present?
    return unless first_created > 6.month.ago
    {
      label: 'Emerging',
      class: 'secondary'
    }
  end

  def star_popularity_badge
    if stars.present? && stars > 1000
      {
        label: 'Popular: Stars',
        class: 'success'
      }
    end
  end

  def download_popularity_badge
    if downloads > 10000
      {
        label: 'Popular: Downloads',
        class: 'success'
      }
    end
  end

  def dependents_popularity_badge
    if dependents > 100
      {
        label: 'Popular: Dependents',
        class: 'success'
      }
    end
  end

  def high_contributors_badge
    if issues.group(:user).count.count > 30
      {
        label: 'Many Contributors',
        class: 'success'
      }
    end
  end

  def low_contributors_badge
    if issues.group(:user).count.count < 3
      {
        label: 'Few contributors',
        class: 'warning'
      }
    end
  end

  def active_badge
    if (last_activity_at && last_activity_at > 1.month.ago) || issues.where('created_at > ?', 1.month.ago).count > 0 || issues.where('closed_at > ?', 1.month.ago).count > 0
      {
        label: 'Active',
        class: 'info'
      }
    end
  end

  def inactive_badge
    if (last_activity_at && last_activity_at  < 2.year.ago) || (issues.where('closed_at > ?',  1.year.ago).count == 0 && (last_activity_at && last_activity_at  < 1.year.ago)) 
      {
        label: 'Inactive',
        class: 'danger'
      }
    end
  end

  def maintainers(range: 30)
    
  end

  def fetch_dependencies
    return unless repository.present?
    conn = Faraday.new(url: repository['manifests_url']) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end
    response = conn.get
    return unless response.success?
    self.dependencies = JSON.parse(response.body)
    self.save
  rescue
    puts "Error fetching dependencies for #{url}"
  end

  def all_dependencies
    return [] if dependencies.blank?
    dependencies.map{|m| m['dependencies'] }.flatten.compact
  end

  def direct_dependencies
    return [] if dependencies.blank?
    all_dependencies.select{|d| d['direct'] == true }
  end

  def development_dependencies
    return [] if dependencies.blank?
    all_dependencies.select{|d| ['development', 'dev', 'test', 'build'].include? d['kind']  }
  end

  def transitive_dependencies
    return [] if dependencies.blank?
    all_dependencies.select{|d| d['direct'] == false }
  end

  def fetch_collective
    return unless funding_links.any?{|f| f.include?('opencollective.com') }
    return if collective_id.present?
    
    slug = funding_links.find{|f| f.include?('opencollective.com') }.split('/').last

    c = Collective.find_or_create_by(slug: slug) 

    if c.persisted?
      c.sync_async 
      self.collective_id = c.id
      save
    end
  end
end
