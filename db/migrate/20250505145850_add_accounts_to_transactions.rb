class AddAccountsToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :transactions, :from_account, :string
    add_column :transactions, :to_account, :string
  end
end
