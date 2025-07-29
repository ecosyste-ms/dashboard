class AddUniqueIndexToTagsProjectIdName < ActiveRecord::Migration[8.0]
  def change
    add_index :tags, [:project_id, :name], unique: true, name: 'index_tags_on_project_id_and_name'
  end
end
