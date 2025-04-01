class AddArchivedToCollectives < ActiveRecord::Migration[7.1]
  def change
    add_column :collectives, :archived, :boolean
  end
end
