class Advisory < ApplicationRecord
  belongs_to :project

  scope :this_period, ->(period) { where('advisories.published_at > ?', period.days.ago) }
  scope :last_period, ->(period) { where('advisories.published_at > ?', (period*2).days.ago).where('advisories.published_at < ?', period.days.ago) }
  scope :between, ->(start_date, end_date) { where('advisories.published_at > ?', start_date).where('advisories.published_at < ?', end_date) }

  scope :published_after, ->(date) { where('advisories.published_at > ?', date) }
  scope :published_before, ->(date) { where('advisories.published_at < ?', date) }

  def source
    source_kind
  end

  def to_s
    uuid
  end

  def ecosystems
    packages.map{|p| p['ecosystem'] }.uniq
  end

  def package_names
    packages.map{|p| p['package_name'] }.uniq
  end

  def withdrawn?
    withdrawn_at.present?
  end
end
