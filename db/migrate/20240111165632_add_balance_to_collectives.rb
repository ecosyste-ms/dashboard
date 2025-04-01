class AddBalanceToCollectives < ActiveRecord::Migration[7.1]
  def change
    add_column :collectives, :balance, :float
  end
end
