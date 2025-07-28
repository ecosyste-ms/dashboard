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
end

# VCR Configuration
VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock
  config.ignore_localhost = true
  
  # Use recorded cassettes by default, record new ones if they don't exist
  config.default_cassette_options = { 
    record: :once,  # Record once, then playback
    allow_unused_http_interactions: true
  }
  
  # Filter out sensitive information
  config.filter_sensitive_data('<FILTERED>') { ENV['GITHUB_TOKEN'] }
  config.filter_sensitive_data('<FILTERED>') { ENV['API_KEY'] }
  
  # Log HTTP interactions
  config.debug_logger = $stdout if ENV['VCR_DEBUG']
  
  # Hook to log when VCR is recording vs replaying
  config.before_record do |interaction|
    puts "🎬 VCR RECORDING: #{interaction.request.method.upcase} #{interaction.request.uri}"
  end
  
  config.before_playback do |interaction|
    puts "📼 VCR PLAYBACK: #{interaction.request.method.upcase} #{interaction.request.uri}"
  end
end

class ActionDispatch::IntegrationTest
  def login_as(user)
    # For Rails 8, we need to mock the session by stubbing current_user
    ApplicationController.any_instance.stubs(:current_user).returns(user)
  end
end
