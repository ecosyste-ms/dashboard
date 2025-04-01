class CreateCollectives < ActiveRecord::Migration[7.1]
  def change
    create_table :collectives do |t|
      t.string :uuid
      t.string :slug
      t.string :name
      t.string :description
      t.string :tags, array: true, default: []
      t.string :website
      t.string :github
      t.string :twitter
      t.string :repository_url
      t.json :social_links
      t.string :currency

      t.integer :projects_count
      t.datetime :last_synced_at
      
      t.timestamps
    end
  end
end
