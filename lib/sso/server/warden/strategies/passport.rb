module SSO
  module Server
    module Warden
      module Strategies
        class Passport < ::Warden::Strategies::Base

          def valid?
            fail 'bom'
          end

          def authenticate!
            fail 'wam'
          end

        end
      end
    end
  end
end

