class Commit < ApplicationRecord
  belongs_to :project

  scope :since, ->(date) { where('timestamp > ?', date) }
  scope :until, ->(date) { where('timestamp < ?', date) }

  scope :author, ->(author) { where(author: author) }
  scope :committer, ->(committer) { where(committer: committer) }
  scope :merges, -> { where(merge: true) }

  scope :created_after, ->(date) { where('commits.timestamp > ?', date) }
  scope :created_before, ->(date) { where('commits.timestamp < ?', date) }

  scope :this_period, ->(period) { where('commits.timestamp > ?', period.days.ago) }
  scope :last_period, ->(period) { where('commits.timestamp > ?', (period*2).days.ago).where('commits.timestamp < ?', period.days.ago) }

  scope :between, ->(start_date, end_date) { where('commits.timestamp > ?', start_date).where('commits.timestamp < ?', end_date) }

  def html_url
    "#{project.repository_url}/commit/#{sha}"
  end

  def first_line
    return '' if message.nil?
    message.split("\n").first
  end

  def the_rest_of_the_message
    return '' if message.nil?
    return "" if message.split("\n").length < 2
    message.split("\n")[1..-1].join("\n")
  end
end
