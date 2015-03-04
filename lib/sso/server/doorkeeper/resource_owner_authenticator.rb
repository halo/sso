module SSO
  module Server
    module Doorkeeper
      class ResourceOwnerAuthenticator
        include ::SSO::Logging

        attr_reader :controller

        def self.call
          proc { ::SSO::Server::Doorkeeper::ResourceOwnerAuthenticator.new(controller: self).call }
        end

        def initialize(controller:)
          @controller = controller
        end

        def call
          debug { 'Detected "Authorization Code Grant" flow. Checking resource owner authentication...' }

          unless warden
            fail ::SSO::Server::Errors::WardenMissing, 'Please use the Warden middleware.'
          end

          if current_user
            debug { "Yes, User with ID #{current_user.inspect} has a session." }
            current_user
          else
            debug { "No, no User is logged in right now. Initializing authentication procedure..." }
            warden.authenticate! :password
          end
        end

        def warden
          controller.request.env['warden']
        end

        def current_user
          warden.user
        end

      end
    end
  end
end
