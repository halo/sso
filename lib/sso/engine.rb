module SSO
  class Engine < ::Rails::Engine
    isolate_namespace SSO

    initializer "my_engine.add_middleware" do |app|
      app.middleware.insert_after ::ActionDispatch::Flash, ::Warden::Manager do |manager|
        manager.failure_app = ::SSO::Warden::FailureApp
        manager.intercept_401 = false
      end

      app.middleware.insert_after ::Warden::Manager, ::SSO::Doorkeeper::GrantMarker
     end

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_girl, dir: 'spec/factories'
    end
  end
end
