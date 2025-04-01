class AddTransactionsCountToCollectives < ActiveRecord::Migration[7.1]
  def change
    add_column :collectives, :transactions_count, :integer
  end
end
