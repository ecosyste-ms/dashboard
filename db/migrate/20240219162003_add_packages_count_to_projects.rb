class AddPackagesCountToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :packages_count, :integer
  end
end
