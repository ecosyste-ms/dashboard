class Transaction < ApplicationRecord
  belongs_to :collective
  validates :uuid, uniqueness: true

  counter_culture :collective, execute_after_commit: true

  scope :collectives, -> { joins(:collective).where('collectives.account_type = ?', 'COLLECTIVE') }
  scope :opensource, -> { joins(:collective).where('collectives.host = ?', 'opensource') }

  scope :donations, -> { where(transaction_type: 'CREDIT') }
  scope :expenses, -> { where(transaction_type: 'DEBIT') }
  scope :host_fees, -> { where(transaction_kind: ['PAYMENT_PROCESSOR_FEE', 'PAYMENT_PROCESSOR_COVER', 'HOST_FEE'])}
  scope :not_host_fees, -> { where.not(transaction_kind: ['PAYMENT_PROCESSOR_FEE', 'PAYMENT_PROCESSOR_COVER', 'HOST_FEE'])}  

  scope :created_after, ->(date) { where('transactions.created_at > ?', date) }
  scope :created_before, ->(date) { where('transactions.created_at < ?', date) }
  scope :between, ->(start_date, end_date) { where('transactions.created_at > ?', start_date).where('transactions.created_at < ?', end_date) }

  scope :this_period, ->(period) { where('transactions.created_at > ?', period.days.ago) }
  scope :last_period, ->(period) { where('transactions.created_at > ?', (period*2).days.ago).where('transactions.created_at < ?', period.days.ago) }
end
