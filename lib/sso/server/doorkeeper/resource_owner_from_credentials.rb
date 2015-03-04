module SSO
  module Server
    module Doorkeeper
      class ResourceOwnerFromCredentials

        def self.to_proc
          proc do
            fail self.inspect
            ::User.find 99
          end
        end

      end
    end
  end
end
