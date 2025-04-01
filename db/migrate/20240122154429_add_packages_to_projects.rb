class AddPackagesToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :packages, :json, default: []
  end
end
