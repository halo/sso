Gem::Specification.new do |s|
  s.name        = 'sso'
  s.version     = '0.1.3'
  s.date        = '2015-03-26'
  s.summary     = 'Leveraging Doorkeeper as single-sign-on OAuth server.'
  s.description = "#{s.summary} To provide true single-sign-OUT, every request on an OAuth client app is verified with the SSO server."
  s.author      = 'halo'
  s.license     = 'MIT'
  s.homepage    = 'https://github.com/halo/sso'

  s.required_ruby_version = '>= 2.0.0'

  s.files       = Dir['lib/**/*'] & `git ls-files -z`.split("\0")
  s.test_files  = Dir['spec/**/*'] & `git ls-files -z`.split("\0")

  # Server
  s.add_runtime_dependency 'doorkeeper', '>= 2.0.0'

  # Client
  s.add_runtime_dependency 'httparty'

  # Both
  s.add_runtime_dependency 'omniauth-oauth2'
  s.add_runtime_dependency 'signature', '>=  0.1.8'
  s.add_runtime_dependency 'warden', '>= 1.2.3'
  s.add_runtime_dependency 'operation', '~> 0.0.3'

  # Development
  s.add_development_dependency 'database_cleaner'
  s.add_development_dependency 'factory_girl_rails'
  s.add_development_dependency 'guard-rspec', '>= 4.2.3'
  s.add_development_dependency 'guard-rubocop'
  s.add_development_dependency 'pg'
  s.add_development_dependency 'rails'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'simplecov', '>= 0.9.0'
  s.add_development_dependency 'timecop'
  s.add_development_dependency 'webmock'
end
