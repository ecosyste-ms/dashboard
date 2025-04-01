class AddKindToCollectives < ActiveRecord::Migration[7.1]
  def change
    add_column :collectives, :kind, :string
  end
end
