module SSO
  module Doorkeeper

    def self.resource_owner_authenticator(&block)
      Proc.new do
        true
      end
    end

  end
end
