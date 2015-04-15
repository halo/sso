module SSO
  module Client
    module Warden
      module Strategies
        # When the iPhone presents a Passport to Alpha, this is how Alpha verifies it with Bouncer.
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
              debug { 'Authentication on Client from Passport successful.' }
              debug { "Persisting trusted Passport #{authentication.object.inspect}" }
              success! authentication.object
            else
              debug { 'Authentication from Passport failed.' }
              debug { "Responding with #{authentication.object.inspect}" }
              custom! authentication.object
            end

          rescue => exception
            ::SSO.config.exception_handler.call exception
          end

          def passport_authentication
            benchmark 'Passport proxy verification' do
              ::SSO::Client::Authentications::Passport.new(request).authenticate
            end
          end

        end
      end
    end
  end
end
