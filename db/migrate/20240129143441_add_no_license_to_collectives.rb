class AddNoLicenseToCollectives < ActiveRecord::Migration[7.1]
  def change
    add_column :collectives, :no_license, :boolean
  end
end
