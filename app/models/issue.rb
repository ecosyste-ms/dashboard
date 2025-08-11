class Issue < ApplicationRecord
  belongs_to :project
  counter_culture :project, column_name: 'issues_count', execute_after_commit: true

  MAINTAINER_ASSOCIATIONS = ["MEMBER", "OWNER", "COLLABORATOR"]
  DEPENDABOT_USERNAMES = ['dependabot[bot]', 'dependabot-preview[bot]'].freeze

  scope :label, ->(labels) { where("labels && ARRAY[?]::varchar[]", labels) }
  scope :past_year, -> { where('issues.created_at > ?', 1.year.ago) }
  scope :bot, -> { where('issues.user ILIKE ?', '%[bot]') }
  scope :human, -> { where.not('issues.user ILIKE ?', '%[bot]') }
  scope :with_author_association, -> { where.not(author_association: nil) }
  scope :merged, -> { where.not(merged_at: nil) }
  scope :not_merged, -> { where(merged_at: nil).where.not(closed_at: nil) }
  scope :open, -> { where(closed_at: nil) }
  scope :closed, -> { where.not(closed_at: nil) }
  scope :created_after, ->(date) { where('issues.created_at > ?', date) }
  scope :created_before, ->(date) { where('issues.created_at < ?', date) }
  scope :updated_after, ->(date) { where('updated_at > ?', date) }
  scope :pull_request, -> { where(pull_request: true) }
  scope :issue, -> { where(pull_request: false) }
  scope :maintainers, -> { where(author_association: MAINTAINER_ASSOCIATIONS) }

  scope :this_period, ->(period) { where('issues.created_at > ?', period.days.ago) }
  scope :last_period, ->(period) { where('issues.created_at > ?', (period*2).days.ago).where('issues.created_at < ?', period.days.ago) }
  scope :between, ->(start_date, end_date) { where('issues.created_at > ?', start_date).where('issues.created_at < ?', end_date) }

  scope :closed_this_period, ->(period) { where('issues.closed_at > ?', period.days.ago) }
  scope :closed_last_period, ->(period) { where('issues.closed_at > ?', (period*2).days.ago).where('issues.closed_at < ?', period.days.ago) }
  scope :closed_between, ->(start_date, end_date) { where('issues.closed_at > ?', start_date).where('issues.closed_at < ?', end_date) }

  scope :merged_this_period, ->(period) { where('issues.merged_at > ?', period.days.ago) }
  scope :merged_last_period, ->(period) { where('issues.merged_at > ?', (period*2).days.ago).where('issues.merged_at < ?', period.days.ago) }
  scope :merged_between, ->(start_date, end_date) { where('issues.merged_at > ?', start_date).where('issues.merged_at < ?', end_date) }

  scope :not_merged_this_period, ->(period) { where('issues.closed_at > ?', period.days.ago).where(merged_at: nil) }
  scope :not_merged_last_period, ->(period) { where('issues.closed_at > ?', (period*2).days.ago).where('issues.closed_at < ?', period.days.ago).where(merged_at: nil) }
  scope :not_merged_between, ->(start_date, end_date) { where('issues.closed_at > ?', start_date).where('issues.closed_at < ?', end_date).where(merged_at: nil) }

  scope :open_this_period, ->(period) { where('issues.created_at > ?', period.days.ago).where(closed_at: nil) }
  scope :open_last_period, ->(period) { where('issues.created_at > ?', (period*2).days.ago).where('issues.created_at < ?', period.days.ago).where(closed_at: nil) }
  scope :open_between, ->(start_date, end_date) { where('issues.created_at > ?', start_date).where('issues.created_at < ?', end_date).where(closed_at: nil) }

  # Dependabot-specific scopes
  scope :with_dependency_metadata, -> { where.not(dependency_metadata: nil) }
  scope :ecosystem, ->(ecosystem_name) { where("dependency_metadata::jsonb -> 'packages' @> ?::jsonb", [{ ecosystem: ecosystem_name }].to_json) }
  scope :package_name, ->(name) { where("dependency_metadata::jsonb -> 'packages' @> ?::jsonb", [{ name: name }].to_json) }
  scope :has_body, -> { where.not(body: [nil, '']) }
  scope :security_prs, -> { 
    where("title ~* 'CVE-\\d{4}-\\d+|GHSA-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}|RUSTSEC-\\d{4}-\\d+|security|vulnerability'")
    .or(where("dependency_metadata::jsonb ->> 'security' = 'true'"))
    .or(where("dependency_metadata::jsonb -> 'packages' @> '[{\"security\": true}]'::jsonb"))
    .or(where("labels && ARRAY[?]::varchar[]", 'security'))
  }
  scope :dependabot, -> { where(user: DEPENDABOT_USERNAMES) }

  def to_param
    number.to_s
  end

  # Dependabot-specific methods
  def bot?
    user&.include?('[bot]') || dependabot?
  end

  def dependabot?
    DEPENDABOT_USERNAMES.include?(user)
  end

  def security_related?
    return false unless dependency_metadata.present?
    
    # Check title and body for security keywords
    security_keywords = %w[security vulnerability cve advisory patch fix]
    text_to_check = "#{title} #{body}".downcase
    
    security_keywords.any? { |keyword| text_to_check.include?(keyword) } ||
      has_security_identifier?
  end

  def has_security_identifier?
    return false unless dependency_metadata.present?
    
    text_to_check = "#{title} #{body} #{dependency_metadata.to_json}".downcase
    
    # Look for CVE identifiers, GHSA identifiers, or other security patterns
    text_to_check.match?(/cve-\d{4}-\d{4,}/) ||
      text_to_check.match?(/ghsa-[\w\d]+-[\w\d]+-[\w\d]+/) ||
      text_to_check.match?(/security advisory/) ||
      text_to_check.match?(/vulnerability/)
  end

  def parse_dependabot_metadata
    return {} unless dependabot?
    
    metadata = dependency_metadata&.deep_dup || {}
    
    # Extract package information from title if not already in metadata
    if title.present? && metadata['packages'].blank?
      # Parse titles like "Bump lodash from 4.17.20 to 4.17.21"
      if match = title.match(/bump\s+(.+?)\s+from\s+(.+?)\s+to\s+(.+)/i)
        metadata['packages'] = [{
          'name' => match[1].strip,
          'old_version' => match[2].strip,
          'new_version' => match[3].strip
        }]
      end
    end
    
    metadata
  end

  def effective_state
    return 'merged' if merged_at.present?
    return 'closed' if closed_at.present?
    'open'
  end

  def user_avatar_url(size: 40)
    return nil unless user.present?
    
    # Extract username from user string (handles cases like "dependabot[bot]")
    username = user.gsub(/\[bot\]/, '').strip
    "https://github.com/#{username}.png?size=#{size}"
  end

  def packages
    return [] unless dependency_metadata.present? && dependency_metadata['packages'].present?
    dependency_metadata['packages']
  end

  def package_names
    packages.map { |pkg| pkg['name'] }.compact.uniq
  end

  def ecosystems
    packages.map { |pkg| pkg['ecosystem'] }.compact.uniq
  end

  def version_changes
    packages.map do |pkg|
      next unless pkg['old_version'] && pkg['new_version']
      {
        name: pkg['name'],
        from: pkg['old_version'],
        to: pkg['new_version']
      }
    end.compact
  end
end
