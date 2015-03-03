ENV['RACK_ENV'] = 'test'

# Booting Rails
require File.expand_path('../dummy/config/environment', __FILE__)

# Loading RSpec support
require 'rspec/rails'
Dir[Pathname.pwd.join('spec/support/**/*.rb')].each { |f| require f }

RSpec.configure do |config|

  config.include Doorkeeper::Test::Helpers

  config.raise_errors_for_deprecations!
  config.disable_monkey_patching!
  config.color = true
  config.fail_fast = true

  config.before :each do
    #DatabaseCleaner.start
    Doorkeeper::Test.setup
  end

end
