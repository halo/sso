module SSO
  module Server
    module Doorkeeper
      class ResourceOwnerAuthenticator

        def self.to_proc
          proc do
            ::SSO.config.logger.debug { 'Detected "Authorization Code Grant" flow. Checking resource owner authentication...' }

            unless warden = request.env['warden']
              fail ::SSO::Server::Errors::WardenMissing 'Please use the Warden middleware.'
            end

            if warden.user
              ::SSO.config.logger.debug { "Yes, User with ID #{warden.user.id.inspect} has a session." }
              warden.user
            else
              ::SSO.config.logger.debug { "No, no User is logged in right now. Initializing authentication procedure..." }
              warden.authenticate! :password
            end
          end
        end

      end
    end
  end
end
