class Package < ApplicationRecord
  belongs_to :project

  counter_culture :project, column_name: 'packages_count', execute_after_commit: true

  validates :name, presence: true
  validates :ecosystem, presence: true

  scope :package_url, ->(package_url) { where(purl: Package.purl_without_version(package_url)) }
  scope :package_urls, ->(package_urls) { where(purl: package_urls.map{|p| Package.purl_without_version(p) }) }

  scope :active, -> { where("(metadata ->> 'status') is null") }
  scope :order_by_rankings, -> { order(Arel.sql("metadata -> 'rankings' ->> 'average' asc")) }

  def self.purl_without_version(purl)
    PackageURL.new(**PackageURL.parse(purl.to_s).to_h.except(:version, :scheme)).to_s
  end

  def registry_name
    metadata["registry"]["name"]
  end

  def keywords
    metadata['keywords']
  end

  def funding
    metadata['metadata']['funding']
  end

  def downloads_period
    metadata['downloads_period']
  end

  def downloads
    metadata['downloads'] || 0
  end

  def dependents
    metadata['dependents'] || 0
  end

  def dependent_repos_count
    metadata['dependent_repos_count'] || 0
  end

  def licenses
    metadata['licenses']
  end

  def rankings
    metadata['rankings']
  end

  def registry_url
    metadata['registry_url']
  end

  def latest_release_number
    metadata['latest_release_number']
  end

  def status
    metadata['status']
  end
  
  def description
    metadata['description']
  end

  def description_with_fallback
    description.presence || project.description
  end

  def versions_count
    metadata['versions_count']
  end

  def latest_release_published_at
    metadata['latest_release_published_at']
  end

  def dependent_packages_count
    metadata['dependent_packages_count'] || 0
  end

  def repo_metadata
    metadata['repo_metadata']
  end

  def maintainers_count
    metadata['maintainers_count']
  end

  def documentation_url
    metadata['documentation_url']
  end

  def registry_url
    metadata['registry_url']
  end

  def homepage_url
    metadata['homepage']
  end

  def last_synced_at
    metadata['last_synced_at']
  end
end
