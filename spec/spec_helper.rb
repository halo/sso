ENV['RACK_ENV'] = 'test'

require File.expand_path('../dummy/config/environment', __FILE__)

require 'rspec/rails'
require 'database_cleaner'
require 'timecop'
require 'webmock'

Dir[Pathname.pwd.join('spec/support/**/*.rb')].each { |f| require f }

RSpec.configure do |config|

  config.include Doorkeeper::Test::Helpers
  config.include SSO::Test::Helpers

  config.raise_errors_for_deprecations!
  config.disable_monkey_patching!
  config.color = true
  config.fail_fast = true
  config.use_transactional_fixtures = false

  config.before :suite do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with :truncation
  end

  config.before :each do
    redirect_httparty_to_rails_stack
    DatabaseCleaner.start
    Doorkeeper::Test.setup
  end

  config.after :each do
    DatabaseCleaner.clean
    Timecop.return
  end

end
