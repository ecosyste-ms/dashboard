class AddImportStatusToCollections < ActiveRecord::Migration[8.0]
  def change
    add_column :collections, :import_status, :string, default: 'pending'
    rename_column :collections, :status, :sync_status
    
    # Update existing data
    reversible do |dir|
      dir.up do
        execute "UPDATE collections SET sync_status = 'pending' WHERE sync_status IS NULL"
        execute "UPDATE collections SET import_status = 'completed' WHERE sync_status = 'ready'"
      end
    end
  end
end
