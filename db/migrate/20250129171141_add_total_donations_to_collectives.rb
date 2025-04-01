class AddTotalDonationsToCollectives < ActiveRecord::Migration[8.0]
  def change
    add_column :collectives, :total_donations, :float
  end
end
