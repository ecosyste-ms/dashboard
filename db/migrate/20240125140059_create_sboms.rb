class CreateSboms < ActiveRecord::Migration[7.1]
  def change
    create_table :sboms do |t|
      t.text :raw
      t.text :converted

      t.timestamps
    end
  end
end
