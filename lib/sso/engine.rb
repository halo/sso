module SSO
  class Engine < ::Rails::Engine
    isolate_namespace SSO

    middleware.insert_after ActionDispatch::Flash, Warden::Manager do |manager|
      manager.failure_app = SSO::Unauthenticated
      manager.intercept_401 = false
    end

    middleware.insert_after Warden::Manager, SSO::Doorkeeper::GrantMarker

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_girl, dir: 'spec/factories'
    end
  end
end
