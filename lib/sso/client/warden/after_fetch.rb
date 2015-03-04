require 'sso/client/omniauth/strategies/sso'

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

        attr_reader :passport, :warden, :options

        def self.activate(options)
          ::Warden::Manager.after_fetch(options) do |passport, warden, options|
            SSO::Client::Warden::AfterFetch.new(passport: passport, warden: warden, options: options).call
          end
        end

        def initialize(passport: passport, warden: warden, options: options)
          @passport, @warden, @options = passport, warden, options
        end

        def call
          return unless passport.is_a?(::SSO::Client::Passport)
          verify!

        rescue Timeout::Error => exception
          error { 'SSO Server timed out. Continuing with last known authentication/authorization...' }
          #meter status: :timeout, scope: scope, passport_id: user.passport_id, timeout_ms: human_readable_timeout_in_ms

        rescue => exception
          # call bugsnag or something without halting the flow. the show must go on!
          raise
        end

        private

        def verify!
          debug { "Validating Passport #{passport.id.inspect} of logged in #{passport.user.class} in scope #{warden_scope.inspect}" }

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
          OmniAuth::Strategies::SSO.passports_path
        end

        def base_endpoint
          OmniAuth::Strategies::SSO.endpoint
        end

        def meter(*args)
          # This will be a hook for e.g. statistics, benchmarking, etc, measure everything
        end


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
