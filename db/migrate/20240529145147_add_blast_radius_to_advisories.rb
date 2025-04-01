class AddBlastRadiusToAdvisories < ActiveRecord::Migration[7.1]
  def change
    add_column :advisories, :blast_radius, :float
  end
end
