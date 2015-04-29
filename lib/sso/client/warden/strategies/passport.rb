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
            track key: 'client.warden.strategies.passport.authentication', tags: { scope: scope }

            if authentication.success?
              debug { 'Authentication on Client from Passport successful.' }
              debug { "Persisting trusted Passport #{authentication.object.inspect}" }
              track key: "client.warden.strategies.passport.#{authentication.code}", tags: { scope: scope }
              success! authentication.object
            else
              debug { 'Authentication from Passport on Client failed.' }
              debug { "Responding with #{authentication.object.inspect}" }
              track key: "client.warden.strategies.passport.#{authentication.code}", tags: { scope: scope }
              custom! authentication.object
            end

          rescue => exception
            ::SSO.config.exception_handler.call exception
          end

          def passport_authentication
            benchmark(name: 'Passport proxy verification request', metric: 'client.passport.proxy_verification.duration') do
              ::SSO::Client::Authentications::Passport.new(request).authenticate
            end
          end

        end
      end
    end
  end
end
