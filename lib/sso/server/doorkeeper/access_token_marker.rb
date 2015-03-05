module SSO
  module Server
    module Doorkeeper
      class AccessTokenMarker
        include ::SSO::Logging

        def initialize(app)
          @app = app
        end

        def call(env)
          @env = env
          @request = ::ActionDispatch::Request.new @env
          @response = @app.call @env

          return response unless request.method == 'POST'
          return response unless authorization_grant_flow? || password_flow?
          return response unless response_code == 200
          return response unless response_body
          return response unless outgoing_access_token

          if authorization_grant_flow?
            # We cannot rely on session[:passport_id] here because the end-user might have cookies disabled.
            # The only thing we can rely on to identify the user/Passport is the incoming grant token.
            debug { %{Detected outgoing "Access Token" #{outgoing_access_token.inspect} of the "Authorization Code Grant" flow (belonging to "Authorization Grant Token" #{grant_token.inspect}). Augmenting related Passport with it.} }
            registration = ::SSO::Server::Passports.register_access_token_from_grant grant_token: grant_token, access_token: outgoing_access_token

            if registration.failure?
              warn { "The passport could not be augmented. Destroying warden session." }
              warden.logout
            end

          elsif password_flow?
            local_passport_id = session[:passport_id] # <- We know this is always set because it was set in this very response
            debug { %{Detected outgoing "Access Token" #{outgoing_access_token.inspect} of the "Resource Owner Password Credentials Grant" flow. Augmenting local Passport #{local_passport_id.inspect} with it.} }
            generation = ::SSO::Server::Passports.register_access_token passport_id: local_passport_id, access_token: outgoing_access_token

            if generation.failure?
              warn { "The passport could not be generated. Destroying warden session." }
              warden.logout
            end

          else
            fail NotImplementedError
          end

          response
        end

        def request
          @request
        end

        def response
          @response
        end

        def response_body
          response.last.first.presence
        end

        def response_code
          response.first
        end

        def parsed_response_body
          return unless response_body
          ::JSON.parse response_body
        rescue JSON::ParserError => exception
          Trouble.notify exception
          nil
        end

        def outgoing_access_token
          return unless parsed_response_body
          parsed_response_body['access_token']
        end

        def warden
          request.env['warden']
        end

        def params
          request.params
        end

        def authorization_grant_flow?
          grant_token.present?
        end

        def password_flow?
          grant_type == 'password'
        end

        def grant_token
          params['code']
        end

        def grant_type
          params['grant_type']
        end

        def session
          @env['rack.session']
        end

      end
    end
  end
end
