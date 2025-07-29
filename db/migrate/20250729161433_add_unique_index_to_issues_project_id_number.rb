class AddUniqueIndexToIssuesProjectIdNumber < ActiveRecord::Migration[8.0]
  def change
    add_index :issues, [:project_id, :number], unique: true, name: 'index_issues_on_project_id_and_number'
  end
end