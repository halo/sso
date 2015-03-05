module SSO
  class Engine < ::Rails::Engine
    isolate_namespace SSO

    initializer "my_engine.add_middleware" do |app|
      app.middleware.insert_after ::Warden::Manager, ::SSO::Server::Middleware::PassportVerification
      app.middleware.insert_after ::Warden::Manager, ::SSO::Server::Doorkeeper::GrantMarker
      app.middleware.insert_after ::Warden::Manager, ::SSO::Server::Doorkeeper::AccessTokenMarker
     end

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_girl, dir: 'spec/factories'
    end
  end
end
