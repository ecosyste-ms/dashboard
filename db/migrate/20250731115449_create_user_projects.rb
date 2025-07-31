class CreateUserProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :user_projects do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :user_projects, [:user_id, :project_id], unique: true
    add_index :user_projects, :deleted_at
  end
end
