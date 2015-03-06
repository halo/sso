ENV['RACK_ENV'] = 'test'

require File.expand_path('../dummy/config/environment', __FILE__)
ActiveRecord::Migration.maintain_test_schema!

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

  #config.before :each do
  #  redirect_httparty_to_rails_stack
  #  DatabaseCleaner.start
  #end
  #
  #config.after :each do
  #  DatabaseCleaner.clean
  #  Timecop.return
  #end

end
