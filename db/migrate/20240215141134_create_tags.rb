class CreateTags < ActiveRecord::Migration[7.1]
  def change
    create_table :tags do |t|
      t.integer :project_id, null: false, index: true
      t.string :name
      t.string :sha
      t.string :kind
      t.datetime :published_at

      t.timestamps
    end
  end
end
