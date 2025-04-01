class CreateAdvisories < ActiveRecord::Migration[7.1]
  def change
    create_table :advisories do |t|
      t.integer :project_id
      t.string :uuid
      t.string :url
      t.string :title
      t.text :description
      t.string :origin
      t.string :severity
      t.datetime :published_at
      t.datetime :withdrawn_at
      t.string :classification
      t.float :cvss_score
      t.string :cvss_vector
      t.string :references, default: [], array: true
      t.string :source_kind
      t.string :identifiers, default: [], array: true
      t.jsonb :packages, default: []
      t.string :repository_url

      t.timestamps
    end
  end
end
