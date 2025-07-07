ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

require 'webmock/minitest'
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

class ActionDispatch::IntegrationTest
  def login_as(user)
    # For Rails 8, we need to mock the session by stubbing current_user
    ApplicationController.any_instance.stubs(:current_user).returns(user)
  end
end
