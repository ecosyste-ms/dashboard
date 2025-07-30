require 'test_helper'

class PackageTest < ActiveSupport::TestCase
  test "order_by_rankings sorts by average ranking ascending with nulls last" do
    project = create(:project)
    
    # Create packages with different rankings
    pkg_with_null = create(:package, project: project, name: "no-ranking", metadata: {})
    pkg_with_high_ranking = create(:package, project: project, name: "high-ranking", 
                                  metadata: { "rankings" => { "average" => "0.85" } })
    pkg_with_low_ranking = create(:package, project: project, name: "low-ranking", 
                                 metadata: { "rankings" => { "average" => "0.15" } })
    
    ordered_packages = Package.order_by_rankings.to_a
    
    # Should be ordered: low ranking (0.15), high ranking (0.85), null ranking
    low_index = ordered_packages.index(pkg_with_low_ranking)
    high_index = ordered_packages.index(pkg_with_high_ranking)  
    null_index = ordered_packages.index(pkg_with_null)
    
    assert low_index < high_index, "Low ranking package should come before high ranking package"
    assert high_index < null_index, "Packages with rankings should come before packages without rankings"
  end
end