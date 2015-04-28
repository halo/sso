module SSO
  module Server
    module Warden
      module Strategies
        class Passport < ::Warden::Strategies::Base
          include ::SSO::Logging
          include ::SSO::Benchmarking

          def valid?
            params['auth_version'].to_s != '' && params['state'] != ''
          end

          def authenticate!
            debug { 'Authenticating from Passport...' }

            authentication = passport_authentication

            if authentication.success?
              debug { 'Authentication on Server from Passport successful.' }
              debug { "Responding with #{authentication.object}" }
              custom! authentication.object
            else
              debug { 'Authentication from Passport on Server failed.' }
              custom! authentication.object
            end

          rescue => exception
            ::SSO.config.exception_handler.call exception
          end

          def passport_authentication
            benchmark(name: 'Passport verification') do
              ::SSO::Server::Authentications::Passport.new(request).authenticate
            end
          end

        end
      end
    end
  end
end
