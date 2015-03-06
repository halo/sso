#!/usr/bin/env rake
begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

Bundler::GemHelper.install_tasks

# For your convenience, when you're in the root directory of this repository
# running `rake` will proxy you to the `spec/dummy` Rakefile using the test environment.
ENV['RAILS_ENV'] = 'test'

# Delegate everything to the dummy
APP_RAKEFILE = File.expand_path("../spec/dummy/Rakefile", __FILE__)
load 'rails/tasks/engine.rake'
