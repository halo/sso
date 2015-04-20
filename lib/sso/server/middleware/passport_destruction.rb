module SSO
  module Server
    module Middleware
      class PassportDestruction
        include ::SSO::Logging

        def initialize(app)
          @app = app
        end

        def call(env)
          request = Rack::Request.new(env)

          unless request.delete? && request.path.start_with?(passports_path)
            debug { "I'm not interested in this #{request.request_method.inspect} request to #{request.path.inspect} I only care for DELETE #{passports_path.inspect}" }
            return @app.call(env)
          end

          passport_id = request.path.to_s.split('/').last
          revocation = ::SSO::Server::Passports.logout passport_id: passport_id
          env['warden'].logout

          payload = { success: true, code: revocation.code }
          debug { "Revoked Passport with ID #{passport_id.inspect}" }

          [200, { 'Content-Type' => 'application/json' }, [payload.to_json]]
        end

        def json_code(code)
          [200, { 'Content-Type' => 'application/json' }, [{ success: true, code: code }.to_json]]
        end

        def passports_path
          OmniAuth::Strategies::SSO.passports_path
        end

      end
    end
  end
end
