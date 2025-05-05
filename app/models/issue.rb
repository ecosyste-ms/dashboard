class Issue < ApplicationRecord
  belongs_to :project
  counter_culture :project, column_name: 'issues_count', execute_after_commit: true

  MAINTAINER_ASSOCIATIONS = ["MEMBER", "OWNER", "COLLABORATOR"]

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


  def to_param
    number.to_s
  end
end
