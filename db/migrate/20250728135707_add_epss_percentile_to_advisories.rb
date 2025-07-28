class AddEpssPercentileToAdvisories < ActiveRecord::Migration[8.0]
  def change
    add_column :advisories, :epss_percentile, :float
  end
end
