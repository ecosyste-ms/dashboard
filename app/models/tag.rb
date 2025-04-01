class Tag < ApplicationRecord
  belongs_to :project

  scope :displayable, -> { where.not(published_at: nil) }

  scope :since, ->(date) { where('tags.published_at > ?', date) }
  scope :until, ->(date) { where('tags.published_at < ?', date) }

  scope :created_after, ->(date) { where('tags.published_at > ?', date) }
  scope :created_before, ->(date) { where('tags.published_at < ?', date) }

  scope :this_period, ->(period) { where('tags.published_at > ?', period.days.ago) }
  scope :last_period, ->(period) { where('tags.published_at > ?', (period*2).days.ago).where('tags.published_at < ?', period.days.ago) }

  scope :between, ->(start_date, end_date) { where('tags.published_at > ?', start_date).where('tags.published_at < ?', end_date) }
end
