module SSO
  module Server
    module Middleware
      class PassportCreation
        include ::SSO::Logging

        def initialize(app)
          @app = app
        end

        def call(env)
          request = Rack::Request.new(env)
          remote_ip = request.env['action_dispatch.remote_ip'].to_s

          if !(request.post? && request.path == passports_path)
            debug { "I'm not interested in this request to #{request.path}" }
            return @app.call(env)
          end

          token = request.params['access_token']
          debug { "Detected incoming Passport creation request for access token #{token.inspect}" }
          access_token = ::Doorkeeper::AccessToken.find_by_token token

          unless access_token
            return json_code :access_token_not_found
          end

          unless access_token.valid?
            return json_code :access_token_invalid
          end

          creation = ::SSO::Server::Passports.generate owner_id: access_token.resource_owner_id, ip: remote_ip, agent: request.user_agent
          passport_id = creation.object
          finding = ::SSO::Server::Passports.find(passport_id)

          if finding.failure?
            error { "Could not find newly generated Passport #{finding.code.inspect} - #{finding.object.inspect}"}
            return json_code :access_token_not_attached_to_valid_passport
          end

          passport = finding.object
          debug { "Attaching user to passport #{passport.inspect}" }
          passport.user = SSO.config.find_user_for_passport.call(passport: passport, ip: remote_ip)
          payload = { success: true, code: :here_is_your_passport, passport: passport.export }
          debug { "Created Passport #{passport.id}, sending it including user #{passport.user.inspect}}"}

          return [200, { 'Content-Type' => 'application/json' }, [payload.to_json]]
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
