class AddGithubSponsorsToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :github_sponsors, :json, default: {}
  end
end
