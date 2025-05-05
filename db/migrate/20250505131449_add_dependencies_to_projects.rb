class AddDependenciesToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :dependencies, :json
  end
end
