class AddStatusToCollections < ActiveRecord::Migration[8.0]
  def change
    add_column :collections, :status, :string, default: 'pending', null: false
  end
end
