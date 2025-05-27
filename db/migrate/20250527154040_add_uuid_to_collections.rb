class AddUuidToCollections < ActiveRecord::Migration[8.0]
  def change
    add_column :collections, :uuid, :uuid, default: -> { "gen_random_uuid()" }, null: false
  end
end
