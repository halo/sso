module SSO
  module Doorkeeper

    def self.resource_owner_authenticator(&block)
      Proc.new do
        OpenStruct.new id: 42
      end
    end

  end
end
