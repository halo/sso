module SSO
  module Server
    module Warden
      module Hooks
        class BeforeLogout
          include ::SSO::Logging

          attr_reader :user, :warden, :options
          delegate :request, to: :warden
          delegate :params, to: :request
          delegate :session, to: :request

          def self.to_proc
            proc do |user, warden, options|
              begin
                new(user: user, warden: warden, options: options).call
              rescue => exception
                ::SSO.config.exception_handler.call exception
              end
            end
          end

          def initialize(user:, warden:, options:)
            @user, @warden, @options = user, warden, options
          end

          def call
            debug { 'Before warden destroys the passport in the cookie, it will revoke all connected Passports as well.' }
            revoking = Passports.logout passport_id: params['passport_id']

            error { 'Could not revoke the Passports.' } if revoking.failure?
            debug { 'Finished.' }
          end
        end
      end
    end
  end
end
