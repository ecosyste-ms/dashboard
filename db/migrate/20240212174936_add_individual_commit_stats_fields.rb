class AddIndividualCommitStatsFields < ActiveRecord::Migration[7.1]
  def change
    add_column :commits, :additions, :integer
    add_column :commits, :deletions, :integer
    add_column :commits, :files_changed, :integer
    remove_column :commits, :stats
  end
end
