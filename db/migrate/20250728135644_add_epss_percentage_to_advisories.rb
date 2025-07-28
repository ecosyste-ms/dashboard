class AddEpssPercentageToAdvisories < ActiveRecord::Migration[8.0]
  def change
    add_column :advisories, :epss_percentage, :float
  end
end
