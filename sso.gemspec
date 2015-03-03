Gem::Specification.new do |s|
  s.name        = 'sso'
  s.version     = '0.0.2'
  s.date        = '2015-02-02'
  s.summary     = 'Working towards a single-sign on rack middleware.'
  s.description = 'Working towards a single-sign on rack middleware. To provide true single-sign-OUT, every request on a client app is verified with the SSO server.'
  s.authors     = %w(halo)

  s.files       = Dir[*%w( lib/sso** )] & `git ls-files -z`.split("\0")
  s.homepage    = 'https://github.com/halo/oauth-sso/issues/1'
  s.test_files  = Dir['spec/**/*'] & `git ls-files -z`.split("\0")

  s.add_dependency 'factory_girl_rails'
  s.add_dependency 'httparty'
  s.add_dependency 'doorkeeper'
  s.add_dependency 'omniauth-oauth2'
  s.add_dependency 'signature'
  s.add_dependency 'warden'

  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'guard-rspec'
  s.add_development_dependency 'rspec-rails'
end
