guard :rspec, cmd: 'bundle exec rspec' do
  require 'guard/rspec/dsl'
  dsl = Guard::RSpec::Dsl.new(self)

  rspec = dsl.rspec
  watch(rspec.spec_helper)  { rspec.spec_dir }
  watch(rspec.spec_support) { rspec.spec_dir }
  watch(rspec.spec_files)

  watch(%r{^lib/sso/server/warden/strategies/passport.rb}) { 'spec/lib/sso/client/warden/hooks/after_fetch_spec.rb' }

  ruby = dsl.ruby
  dsl.watch_spec_files_for(ruby.lib_files)
end
