class CreateTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :transactions do |t|
      t.integer :collective_id, index: true
      t.string :uuid
      t.float :amount
      t.float :net_amount
      t.string :kind
      t.string :currency
      t.string :account
      t.string :description

      t.timestamps
    end

    add_index :transactions, :uuid, unique: true
  end
end
