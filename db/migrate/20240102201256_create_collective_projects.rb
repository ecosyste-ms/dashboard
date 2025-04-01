class CreateCollectiveProjects < ActiveRecord::Migration[7.1]
  def change
    create_table :collective_projects do |t|
      t.integer :collective_id
      t.integer :project_id
      t.string :name
      t.string :description
      t.string :category
      t.string :sub_category

      t.timestamps
    end
  end
end
