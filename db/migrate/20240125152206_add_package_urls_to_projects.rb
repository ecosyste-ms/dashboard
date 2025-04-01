class AddPackageUrlsToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :package_urls, :string, array: true, default: []
  end
end
