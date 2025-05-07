class CreateCollectionProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :collection_projects do |t|
      t.references :collection, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
    end
  end
end
