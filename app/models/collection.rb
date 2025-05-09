class Collection < ApplicationRecord
  has_many :collection_projects, dependent: :destroy
  has_many :projects, through: :collection_projects

  has_many :issues, through: :projects
  has_many :commits, through: :projects
  has_many :tags, through: :projects
  has_many :packages, through: :projects
  has_many :advisories, through: :projects

  scope :visible, -> { where(visibility: 'public') }

  validates :name, presence: true

  after_create :import_projects_from_url

  def import_projects_from_url
    return if url.blank?
    # if url is a github org, import all repos
    if url =~ /github\.com\/([^\/]+)/
      org_name = $1
      import_github_org(org_name)
    else
      # TODO open collective url 
      # TODO single repo (dependencies)
      # TODO ecosystem fund url 
    end
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
    nil
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
end
