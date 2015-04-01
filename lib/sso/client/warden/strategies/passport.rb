module SSO
  module Client
    module Warden
      module Strategies
        # When the iPhone presents a Passport to Alpha, this is how Alpha verifies it with Bouncer.
        class Passport < ::Warden::Strategies::Base
          include ::SSO::Logging

          def valid?
            params['auth_version'].to_s != '' && params['state'] != ''
          end

          def authenticate!
            debug { 'Authenticating from Passport...' }

            authentication = nil
            time = Benchmark.realtime do
              authentication = ::SSO::Client::Authentications::Passport.new(request).authenticate
            end

            info { "The Passport verification took #{(time * 1000).round}ms" }

            if authentication.success?
              debug { 'Authentication from Passport successful.' }
              debug { "Persisting trusted Passport #{authentication.object.inspect}" }
              success! authentication.object
            else
              debug { 'Authentication from Passport failed.' }
              debug { "Responding with #{authentication.object.inspect}" }
              custom! authentication.object
            end

          #rescue => exception
          #  ::SSO.config.exception_handler.call exception
          end

        end
      end
    end
  end
end
