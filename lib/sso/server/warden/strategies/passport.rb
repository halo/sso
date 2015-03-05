module SSO
  module Server
    module Warden
      module Strategies
        class Passport < ::Warden::Strategies::Base

          def valid?
            params['auth_version'].to_s != '' && params['state'] != ''
          end

          def authenticate!
            fail 'wam'
          end

        end
      end
    end
  end
end
