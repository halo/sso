module SSO
  module Server
    module Warden
      module Strategies
        class Passport < ::Warden::Strategies::Base
          include ::SSO::Logging

          def valid?
            params['auth_version'].to_s != '' && params['state'] != ''
          end

          def authenticate!
            debug { 'Authenticating from Passport...' }

            authentication = nil
            time = Benchmark.realtime do
              authentication = ::SSO::Server::Authentications::Passport.new(request).authenticate
            end

            info { "The Passport verification took #{(time * 1000).round}ms" }

            if authentication.success?
              debug { 'Authentication from Passport successful.' }
              debug { "Responding with #{authentication.object}" }
              custom! authentication.object
            else
              debug { 'Authentication from Passport failed.' }
              fail authentication.code
            end

          rescue => exception
            error { "An internal error occured #{exception.class.name} #{exception.message} #{exception.backtrace[0..5].join(' ') rescue nil}" }
            # The show must co on
          end

        end
      end
    end
  end
end
