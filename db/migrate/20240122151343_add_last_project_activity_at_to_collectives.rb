class AddLastProjectActivityAtToCollectives < ActiveRecord::Migration[7.1]
  def change
    add_column :collectives, :last_project_activity_at, :datetime
  end
end
