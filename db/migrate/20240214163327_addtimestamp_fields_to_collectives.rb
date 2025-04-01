class AddtimestampFieldsToCollectives < ActiveRecord::Migration[7.1]
  def change
    add_column :collectives, :collective_created_at, :datetime
    add_column :collectives, :collective_updated_at, :datetime
  end
end
