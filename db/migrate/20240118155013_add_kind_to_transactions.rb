class AddKindToTransactions < ActiveRecord::Migration[7.1]
  def change
    add_column :transactions, :transaction_kind, :string
    add_column :transactions, :transaction_expense_type, :string
    rename_column :transactions, :kind, :transaction_type
  end
end
