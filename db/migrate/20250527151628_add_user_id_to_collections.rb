class AddUserIdToCollections < ActiveRecord::Migration[8.0]
  def change
    Collection.find_each(&:destroy)
    add_column :collections, :user_id, :integer, null: false
    add_index :collections, :user_id
  end
end
