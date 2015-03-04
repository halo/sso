module SSO
  module Server
    module Middleware
      class PassportVerification
        include ::SSO::Logging

        def initialize(app)
          @app = app
        end

        def call(env)
          @env = env

          if applicable?
            debug { "Detected incoming Passport verification request." }
            warden.authenticate! :passport
          else
            debug { "Request uninteresting." }
            @app.call(env)
          end
        end

        def applicable?
          request.get? && request.path == passports_path
        end

        def passports_path
          OmniAuth::Strategies::SSO.passports_path
        end

        def request
          @request ||= Rack::Request.new(@env)
        end

        def warden
          @env['warden']
        end

      end
    end
  end
end
