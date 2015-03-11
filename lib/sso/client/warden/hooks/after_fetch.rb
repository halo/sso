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

          def verify
            debug { "Validating Passport #{passport.id.inspect} of logged in #{passport.user.class} in scope #{warden_scope.inspect}" }
            return server_unreachable!                   unless response.code == 200
            return server_response_not_parseable!        unless parsed_response
            return server_response_missing_success_flag! unless response_has_success_flag?
            return server_response_unsuccessful!         unless parsed_response['success'].to_s == 'true'
            verify!

          rescue JSON::ParserError
            error { 'SSO Server response is not valid JSON.' }
            error { response.inspect }
          end

          def verify!
            code = parsed_response['code'].to_s == '' ? :unknown_response_code : parsed_response['code'].to_s.to_sym

            case code
            when :passport_changed    then valid_passport_changed!
            when :passpord_unmodified then valid_passport_remains!
            when :passport_invalid    then invalid_passport!
            else                           unexpected_server_response_status!
            end
          end

          def parsed_response
            response.parsed_response
          end

          def response_has_success_flag?
            parsed_response && parsed_response.respond_to?(:key?) && parsed_response.key?('success')
          end

          def valid_passport_changed!
            debug { 'Valid passport, but state changed' }
            passport.verified!
            # meter status: :valid, passport_id: user.passport_id
          end

          def valid_passport_remains!
            debug { 'Valid passport, no changes' }
            user.verified!
            # meter status: :valid, passport_id: user.passport_id
          end

          def invalid_passport!
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
            error { 'SSO Server response did not include a known passport status code.' }
          end

          def server_response_not_parseable!
            error { 'SSO Server response could not be parsed at all.' }
          end

          def endpoint
            URI.join(base_endpoint, path).to_s
          end

          def query_params
            params.merge auth_hash
          end

          # Needs to be configurable
          def path
            OmniAuth::Strategies::SSO.passports_path
          end

          def base_endpoint
            OmniAuth::Strategies::SSO.endpoint
          end

          def meter(*_)
            # This will be a hook for e.g. statistics, benchmarking, etc, measure everything
          end

          # TODO: Use ActionDispatch remote IP or you might get the Load Balancer's IP instead :(
          def ip
            warden.request.ip
          end

          def agent
            warden.request.user_agent
          end

          def warden_scope
            options[:scope]
          end

          def params
            { ip: ip, agent: agent, state: passport.state }
          end

          def token
            Signature::Token.new passport.id, passport.secret
          end

          def signature_request
            Signature::Request.new('GET', path, params)
          end

          def auth_hash
            signature_request.sign token
          end

          def human_readable_timeout_in_ms
            (timeout_in_seconds * 1000).round
          end

          def timeout_in_seconds
            0.1.seconds
          end

          def response
            @response ||= response!
          end

          def response!
            benchmark 'Passport authorization request' do
              ::HTTParty.get endpoint, timeout: timeout_in_seconds, query: query_params, headers: { 'Accept' => 'application/json' }
            end
          end

        end
      end
    end
  end
end
