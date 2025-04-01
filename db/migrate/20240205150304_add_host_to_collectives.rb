class AddHostToCollectives < ActiveRecord::Migration[7.1]
  def change
    add_column :collectives, :host, :string
  end
end
