module SSO
  module Client
    class PassportVerifier
      include ::SSO::Benchmarking

      attr_reader :passport_id, :passport_state, :passport_secret, :user_ip, :user_agent, :device_id

      def initialize(passport_id:, passport_state:, passport_secret:, user_ip:, user_agent: nil, device_id: nil)
        @passport_id     = passport_id
        @passport_state  = passport_state
        @passport_secret = passport_secret
        @user_ip         = user_ip
        @user_agent      = user_agent
        @device_id       = device_id
      end

      def call
        fetch_response { |failure| return failure }
        interpret_response

      rescue JSON::ParserError
        error { 'SSO Server response is not valid JSON.' }
        error { response.inspect }
      end

      private

      def fetch_response
        yield Operations.failure(:server_unreachable, object: response)                   unless response.code == 200
        yield Operations.failure(:server_response_not_parseable, object: response)        unless parsed_response
        yield Operations.failure(:server_response_missing_success_flag, object: response) unless response_has_success_flag?
        yield Operations.failure(:server_response_unsuccessful, object: response)         unless parsed_response['success'].to_s == 'true'
        Operations.success :server_response_looks_legit
      end

      def interpret_response
        debug { "Interpreting response code #{response_code.inspect}" }

        case response_code
        when :passpord_unmodified then Operations.success(:passport_valid)
        when :passport_changed    then Operations.success(:passport_valid_and_modified, object: received_passport)
        when :passport_invalid    then Operations.failure(:passport_invalid)
        else                           Operations.failure(:unexpected_server_response_status, object: response)
        end
      end

      def response_code
        return :unknown_response_code if parsed_response['code'].to_s == ''
        parsed_response['code'].to_s.to_sym
      end

      def received_passport
        ::SSO::Client::Passport.new received_passport_attributes

      rescue ArgumentError => exception
        error { "Could not instantiate Passport from serialized response #{received_passport_attributes.inspect}" }
        raise
      end

      def received_passport_attributes
        attributes = parsed_response['passport']
        attributes.keys.each do |key|
          attributes[(key.to_sym rescue key) || key] = attributes.delete(key)
        end
        attributes
      end

      def params
        { ip: user_ip, agent: user_agent, device_id: device_id, state: passport_state }
      end

      def token
        Signature::Token.new passport_id, passport_secret
      end

      def signature_request
        Signature::Request.new('GET', path, params)
      end

      def auth_hash
        signature_request.sign token
      end

      def timeout_in_milliseconds
        ::SSO.config.passport_verification_timeout_ms.to_i
      end

      def timeout_in_seconds
        (timeout_in_milliseconds / 1000).round 2
      end

      # TODO Needs to be configurable
      def path
        OmniAuth::Strategies::SSO.passports_path
      end

      def base_endpoint
        OmniAuth::Strategies::SSO.endpoint
      end

      def endpoint
        URI.join(base_endpoint, path).to_s
      end

      def query_params
        params.merge auth_hash
      end

      def response
        @response ||= response!
      end

      def response!
        debug { "Fetching Passport from #{endpoint.inspect}" }
        benchmark 'Passport authorization request' do
          ::HTTParty.get endpoint, timeout: timeout_in_seconds, query: query_params, headers: { 'Accept' => 'application/json' }
        end
      end

      def parsed_response
        response.parsed_response
      end

      def response_has_success_flag?
        parsed_response && parsed_response.respond_to?(:key?) && parsed_response.key?('success')
      end

    end
  end
end
