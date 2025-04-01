class CreateCommits < ActiveRecord::Migration[7.1]
  def change
    create_table :commits do |t|
      t.integer :project_id, index: true, null: false
      t.string :sha
      t.string :message
      t.datetime :timestamp
      t.boolean :merge
      t.string :author
      t.string :committer
      t.integer :stats

      t.timestamps
    end
  end
end
