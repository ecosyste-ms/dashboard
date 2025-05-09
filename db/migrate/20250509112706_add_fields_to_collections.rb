class AddFieldsToCollections < ActiveRecord::Migration[8.0]
  def change
    add_column :collections, :url, :string
    add_column :collections, :visibility, :string, default: 'public'
  end
end
