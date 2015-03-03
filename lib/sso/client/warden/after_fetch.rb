module SSO
  module Client
    module Warden
      # This is a helpful `Warden::Manager.after_fetch` hook for Alpha and Beta.
      # Whenever Carol is fetched out of the session, we also verify her passport.
      #
      # Usage:
      #
      #   SSO::Client::Warden::AfterFetch.activate scope: :vip
      #
      class AfterFetch
        include ::SSO::Logging

        attr_reader :user, :warden, :options

        def self.activate(options)
          ::Warden::Manager.after_fetch(options) do |user, warden, options|
            SSO::Client::Warden::AfterFetch.new(user: user, warden: warden, options: options).call
          end
        end

        def initialize(user: user, warden: warden, options: options)
          @user, @warden, @options = user, warden, options
        end

        def call
          return unless relevant?
          verify!

        rescue Timeout::Error => exception
          error { 'SSO Server timed out. Continuing with last known authentication/authorization...' }
          meter status: :timeout, scope: scope, passport_id: user.passport_id, timeout_ms: human_readable_timeout_in_ms

        rescue => exception
          # bugsnag or something
          raise
        end

        private

        def relevant?
          user_supports_passports? && user_has_passport?
        end

        def user_supports_passports?
          return true if user.respond_to?(:passport_id)
          debug { "The User object in this scope (#{warden_scope.inspect}) does not support Passports. I will not verify any Passports for now." }
          meter status: :unsupported, scope: scope
          false
        end

        def user_has_passport?
          return true if user.passport_id.present?
          warn { 'It seems that your session was not created with the most recent code base. I will not verify any Passport for now.' }
          meter status: :missing, scope: scope
          false
        end

        def verify!
          debug { "Validating Passport #{user.passport_id.inspect} of logged in #{user.class} in scope #{warden_scope.inspect}" }

          case response.code
          when 201 then valid_passport_changed!
          when 204 then valid_passport_remains!
          when 401 then invalid_passport!
          else          unexpected_sso_server_response!
          end
        end

        def valid_passport_changed!
          debug { 'Valid passport, but state changed' }
          user.attributes = response.parsed_response
          # See https://github.com/hassox/warden/issues/103
          warden.set_user user.attributes, scope: scope
          warden.set_user user, store: false
          # Be careful to NOT persist the verified-flag, though!
          user.verified!
          meter status: :valid, passport_id: user.passport_id
        end

        def valid_passport_remains!
          debug { 'Valid passport, no changes' }
          user.verified!
          meter status: :valid, passport_id: user.passport_id
        end

        def invalid_passport!
          warn { 'Your Passport is not valid any more.' }
          warden.logout scope
          meter status: :invalid, passport_id: user.passport_id
        end

        def unexpected_sso_server_response!
          error 'SSOServer is behaving weirdly!'
          debug UnexpectedSSOServerBehavior.new('SSOServer responded with an unexpected HTTP status code.'), actual_response_code: response.code.inspect
        end

        def endpoint
          URI.join(base_endpoint, path).to_s
        end

        def query_params
          params.merge auth_hash
        end

        # Needs to be configurable
        def path
          '/api/v1/passports/verify'
        end

        def meter(*args)
          # This will be a hook for e.g. statistics, benchmarking, etc, measure everything
        end

        def base_endpoint
          # Could simply be derived from: OmniAuth::Strategies::SSO.endpoint
          # Depends on your use case I guess
          SSO::Test.endpoint
        end

        def ip
          warden.request.ip
        end

        def warden_scope
          options[:scope]
        end

        def params
          { ip: ip, agent: warden.request.user_agent, state: user.state }
        end

        def token
          Signature::Token.new user.passport_id, user.passport_secret
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
          result = nil
          seconds = Benchmark.realtime {
            result = ::HTTParty.get endpoint, timeout: timeout_in_seconds, query: query_params, headers: { 'Accept' => 'application/json' }
          }
          info { "Passport authorization request took #{(seconds * 1000).round}ms" }
          result
        end

      end
    end
  end
end
