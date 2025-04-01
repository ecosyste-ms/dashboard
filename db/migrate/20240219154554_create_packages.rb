class CreatePackages < ActiveRecord::Migration[7.1]
  def change
    create_table :packages do |t|
      t.integer :project_id, null: false, index: true
      t.string :name
      t.string :ecosystem
      t.string :purl
      t.json :metadata

      t.timestamps
    end
  end
end
