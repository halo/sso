module SSO
  module Server
    module Doorkeeper
      class ResourceOwnerAuthenticator

        def self.call(&block)
          Proc.new do
            OpenStruct.new id: 42
          end
        end

      end
    end
  end
end
