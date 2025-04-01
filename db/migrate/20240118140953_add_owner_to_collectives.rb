class AddOwnerToCollectives < ActiveRecord::Migration[7.1]
  def change
    add_column :collectives, :owner, :json
  end
end
