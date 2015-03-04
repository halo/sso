module SSO
  module Server
    module Doorkeeper
      class GrantMarker
        include ::SSO::Logging

        def initialize(app)
          @app = app
        end

        def call(env)
          @env = env
          @response = @app.call @env

          return response unless outgoing_grant_token

          if passport_id
            debug { %{Detected outgoing "Authorization Grant Token" #{outgoing_grant_token.inspect} of the "Authorization Code Grant" flow. Augmenting Passport #{passport_id.inspect} with it.} }
            registration = ::SSO::Server::Passports.register_authorization_grant passport_id: passport_id, token: outgoing_grant_token

            if registration.failure?
              warn { "The passport could not be augmented. Destroying warden session." }
              warden.logout
            end
          end

          response
        end

        def request
          ::ActionDispatch::Request.new @env
        end

        def response
          @response
        end

        def code
          response.first
        end

        def session
          request.session
        end

        def warden
          request.env['warden']
        end

        def passport_id
          session['passport_id']
        end

        def location_header
          unless code == 302
            # debug { "Uninteresting response, because it is not a redirect" }
            return
          end

          response.second['Location']
        end

        def redirect_uri
          unless location_header
            # debug { "Uninteresting response, because there is no Location header" }
            return
          end

          ::URI.parse location_header
        end

        def redirect_uri_params
          return unless redirect_uri
          ::Rack::Utils.parse_query redirect_uri.query
        end

        def outgoing_grant_token
          unless redirect_uri_params && redirect_uri_params['code']
            # debug { "Uninteresting response, because there is no code parameter sent" }
            return
          end

          redirect_uri_params['code']
        end

      end
    end
  end
end
