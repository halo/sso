module SSO
  module Server
    module Middleware
      class PassportVerification
        include ::SSO::Logging

        def initialize(app)
          @app = app
        end

        def call(env)
          request = Rack::Request.new(env)

          if request.get? && request.path == passports_path
            debug { "Detected incoming Passport verification request." }
            env['warden'].authenticate! :passport
          else
            debug { "I'm not interested in this request to #{request.path}" }
            @app.call(env)
          end
        end

        def passports_path
          OmniAuth::Strategies::SSO.passports_path
        end

      end
    end
  end
end
