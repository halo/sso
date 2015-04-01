module SSO
  module Client
    module Warden
      module Hooks
        # This is a helpful `Warden::Manager.after_fetch` hook for Alpha and Beta.
        # Whenever Carol is fetched out of the session, we also verify her passport.
        #
        # Usage:
        #
        #   SSO::Client::Warden::Hooks::AfterFetch.activate scope: :vip
        #
        class AfterFetch
          include ::SSO::Logging
          include ::SSO::Benchmarking

          attr_reader :passport, :warden, :options
          delegate :request, to: :warden

          def self.activate(warden_options)
            ::Warden::Manager.after_fetch(warden_options) do |passport, warden, options|
              ::SSO::Client::Warden::Hooks::AfterFetch.new(passport: passport, warden: warden, options: options).call
            end
          end

          def initialize(passport:, warden:, options:)
            @passport, @warden, @options = passport, warden, options
          end

          def call
            return unless passport.is_a?(::SSO::Client::Passport)
            verify

          rescue Timeout::Error
            error { 'SSO Server timed out. Continuing with last known authentication/authorization...' }
            # meter status: :timeout, scope: scope, passport_id: user.passport_id, timeout_ms: human_readable_timeout_in_ms

          rescue => exception
            ::SSO.config.exception_handler.call exception
          end

          private


          def verifier
            ::SSO::Client::PassportVerifier.new passport_id: passport.id, passport_state: passport.state, passport_secret: passport.secret, user_ip: ip, user_agent: agent, device_id: device_id
          end

          def verification
            @verification ||= verifier.call
          end

          def verification_code
            verification.code
          end

          def verify
            debug { "Validating Passport #{passport.id.inspect} of logged in #{passport.user.class} in scope #{warden_scope.inspect}" }

            case verification_code
            when :server_unreachable                    then server_unreachable!
            when :server_response_not_parseable         then server_response_not_parseable!
            when :server_response_missing_success_flag! then server_response_missing_success_flag!
            when :server_response_unsuccessful!         then server_response_unsuccessful!
            when :passport_valid                        then passport_valid!
            when :passport_valid_and_modified           then passport_valid_and_modified!
            when :passport_invalid                      then passport_invalid!
            else                                             unexpected_server_response_status!
            end
          end

          def passport_valid_and_modified!
            debug { 'Valid passport, but state changed' }
            passport.verified!
            # meter status: :valid, passport_id: user.passport_id
          end

          def passport_valid!
            debug { 'Valid passport, no changes' }
            passport.verified!
            # meter status: :valid, passport_id: user.passport_id
          end

          def passport_invalid!
            info { 'Your Passport is not valid any more.' }
            warden.logout warden_scope
            # meter status: :invalid, passport_id: user.passport_id
          end

          def server_unreachable!
            error { "SSO Server responded with an unexpected HTTP status code (#{response.code.inspect} instead of 200)." }
          end

          def server_response_missing_success_flag!
            error { 'SSO Server response did not include the expected success flag.' }
          end

          def unexpected_server_response_status!
            error { "SSO Server response did not include a known passport status code. #{verification_code.inspect}" }
          end

          def server_response_not_parseable!
            error { 'SSO Server response could not be parsed at all.' }
          end

          def meter(*_)
            # This will be a hook for e.g. statistics, benchmarking, etc, measure everything
          end

          # TODO Use ActionDispatch remote IP or you might get the Load Balancer's IP instead :(
          def ip
            request.ip
          end

          def agent
            request.user_agent
          end

          def device_id
            request.params['udid']
          end

          def warden_scope
            options[:scope]
          end

        end
      end
    end
  end
end
