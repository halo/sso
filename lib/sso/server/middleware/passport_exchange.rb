module SSO
  module Server
    module Middleware
      # Hands out the Passport when presented with the corresponding Access Token.
      #
      class PassportExchange
        include ::SSO::Logging

        def initialize(app)
          @app = app
        end

        def call(env)
          request = Rack::Request.new(env)

          unless request.post? && request.path == passports_path
            debug { "I'm not interested in this #{request.request_method.inspect} request to #{request.path.inspect} I only care for POST #{passports_path.inspect}" }
            return @app.call(env)
          end

          token = request.params['access_token']
          debug { "Detected incoming Passport exchange request for access token #{token.inspect}" }
          access_token = ::Doorkeeper::AccessToken.find_by_token token

          return json_error :access_token_not_found unless access_token
          return json_error :access_token_invalid unless access_token.valid?

          finding = ::SSO::Server::Passports.find_by_access_token_id(access_token.id)
          if finding.failure?
            # This should never happen. Every Access Token should be connected to a Passport.
            return json_error :passport_not_found
          end
          passport = finding.object

          ::SSO::Server::Passports.update_activity passport_id: passport.id, request: request

          debug { "Attaching user and chip to passport #{passport.inspect}" }
          passport.load_user!
          passport.create_chip!

          payload = { success: true, code: :here_is_your_passport, passport: passport.export }
          debug { "Created Passport #{passport.id}, sending it including user #{passport.user.inspect}}" }

          [200, { 'Content-Type' => 'application/json' }, [payload.to_json]]
        end

        def json_error(code)
          [200, { 'Content-Type' => 'application/json' }, [{ success: false, code: code }.to_json]]
        end

        def passports_path
          OmniAuth::Strategies::SSO.passports_path
        end

      end
    end
  end
end
