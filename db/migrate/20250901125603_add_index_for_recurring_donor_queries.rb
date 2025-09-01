class AddIndexForRecurringDonorQueries < ActiveRecord::Migration[8.0]
  def change
    add_index :transactions, [:collective_id, :transaction_type, :created_at], name: 'index_transactions_on_collective_type_created'
  end
end