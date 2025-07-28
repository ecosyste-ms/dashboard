class AddLastSyncedAtToCollections < ActiveRecord::Migration[8.0]
  def change
    add_column :collections, :last_synced_at, :datetime
  end
end
