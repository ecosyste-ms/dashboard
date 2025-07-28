ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

require 'webmock/minitest'
require 'vcr'
require 'mocha/minitest'
require 'factory_bot_rails'

require 'sidekiq_unique_jobs/testing'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class ActiveSupport::TestCase
  include FactoryBot::Syntax::Methods

  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :minitest
      with.library :rails
    end
  end

  # Log test timing to identify slow tests
  def setup
    @test_start_time = Time.now
  end

  def teardown
    return unless @test_start_time
    duration = Time.now - @test_start_time
    if duration > 1  # Log tests taking more than 50ms
      puts "⏱️  SLOW TEST: #{self.class}##{@NAME} took #{duration.round(3)}s"
    end
  end
end


# VCR Configuration
VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock
  config.ignore_localhost = true
  
  # Use recorded cassettes only, no new recordings for offline testing
  config.default_cassette_options = { 
    record: :none,  # Only use existing cassettes, no new recordings
    allow_unused_http_interactions: true,
    match_requests_on: [:method, :host, :path, :query, :body]  # Match ignoring port and query param order
  }
  
  # Configure VCR to handle redirects properly  
  config.allow_http_connections_when_no_cassette = false
  
  # Disable all real HTTP connections for offline testing
  WebMock.disable_net_connect!(allow_localhost: true)
  
  # Filter out sensitive information
  config.filter_sensitive_data('<FILTERED>') { ENV['GITHUB_TOKEN'] }
  config.filter_sensitive_data('<FILTERED>') { ENV['API_KEY'] }
  
  # Hook to log when VCR is recording vs replaying
  config.before_record do |interaction|
    puts "🎬 VCR RECORDING: #{interaction.request.method.upcase} #{interaction.request.uri}"
  end
end

class ActionDispatch::IntegrationTest
  def login_as(user)
    # For Rails 8, we need to mock the session by stubbing current_user
    ApplicationController.any_instance.stubs(:current_user).returns(user)
  end
end
