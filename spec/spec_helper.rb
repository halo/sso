ENV['RACK_ENV'] = 'test'

unless ENV['TRAVIS']
  require 'simplecov'
  SimpleCov.start
end

require 'sso'
require 'sso/server'  # <- The dummy app is an SSO Server
require 'sso/client'  # <- For integration tests from client to server

require File.expand_path('../dummy/config/environment', __FILE__)

require 'rspec/rails'
require 'factory_girl_rails'
require 'database_cleaner'
require 'timecop'
require 'webmock'

Dir[Pathname.pwd.join('spec/support/**/*.rb')].each { |f| require f }

RSpec.configure do |config|

  config.include FactoryGirl::Syntax::Methods
  config.include SSO::Test::Helpers

  config.color = true
  config.disable_monkey_patching!
  config.fail_fast = true
  config.raise_errors_for_deprecations!
  config.use_transactional_fixtures = false

  config.before :suite do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with :truncation
  end

  config.before :each do
    redirect_httparty_to_rails_stack
  end

  config.before :each, db: true do
    DatabaseCleaner.start
  end

  config.after :each do
    Timecop.return
  end

  config.after :each, db: true do
    DatabaseCleaner.clean
  end

end
