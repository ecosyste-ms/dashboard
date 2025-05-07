class Collection < ApplicationRecord
  has_many :collection_projects, dependent: :destroy
  has_many :projects, through: :collection_projects

  has_many :issues, through: :projects
  has_many :commits, through: :projects
  has_many :tags, through: :projects
  has_many :packages, through: :projects
  has_many :advisories, through: :projects


  validates :name, presence: true

  def self.import_github_org(org_name)

    collection = Collection.find_or_create_by(name: org_name) do |collection|
      collection.name = org_name
      collection.description = "Collection of repositories for #{org_name}"
    end

    page = 1
    loop do
      resp = Faraday.get("https://repos.ecosyste.ms/api/v1/hosts/GitHub/owners/#{org_name}/repositories?per_page=100&page=#{page}")
      break unless resp.status == 200

      data = JSON.parse(resp.body)
      break if data.empty? # Stop if there are no more repositories

      urls = data.map{|p| p['html_url'] }.uniq.reject(&:blank?)
      urls.each do |url|
        puts url
        project = Project.find_or_create_by(url: url)
        project.sync_async unless project.last_synced_at.present?
        collection.collection_projects.find_or_create_by(project: project)
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

  def stars
    projects.map(&:stars).compact.sum
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
    projects.sum(&:watchers)
  end

  def forks
    projects.sum(&:forks)
  end

  def stars
    projects.sum(&:stars)
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
