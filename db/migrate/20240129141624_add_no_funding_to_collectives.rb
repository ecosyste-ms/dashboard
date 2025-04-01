class AddNoFundingToCollectives < ActiveRecord::Migration[7.1]
  def change
    add_column :collectives, :no_funding, :boolean
  end
end
