class AddIssuesCountToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :issues_count, :integer, default: 0
  end
end
