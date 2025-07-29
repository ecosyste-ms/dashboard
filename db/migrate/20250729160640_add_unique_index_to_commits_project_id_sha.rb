class AddUniqueIndexToCommitsProjectIdSha < ActiveRecord::Migration[8.0]
  def change
    add_index :commits, [:project_id, :sha], unique: true, name: 'index_commits_on_project_id_and_sha'
  end
end
