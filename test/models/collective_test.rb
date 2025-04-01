require 'test_helper'

class CollectiveTest < ActiveSupport::TestCase
  test "project_url" do
    collective = Collective.new
    collective.website = 'https://github.com/Chinachu/Chinachu'
    collective.social_links = [{"type"=>"WEBSITE", "url"=>"https://github.com/Chinachu/Chinachu"},
    {"type"=>"TWITTER", "url"=>"https://twitter.com/chinachu_rec"},
    {"type"=>"GITHUB", "url"=>"https://github.com/Chinachu"}]
  
    assert_equal 'https://github.com/Chinachu/Chinachu', collective.project_url
  end
end