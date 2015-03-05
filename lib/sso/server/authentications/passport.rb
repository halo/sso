module SSO
  module Server
    module Authentications
      class Passport
        include ::SSO::Logging

        def initialize(verb:, path:, params:)
          @verb, @path, @params = verb, path, params
        end

        def authenticate
          result = authenticate!

          if result.success?
            result
          else
            # TODO: Prevent Flooding here.
            debug { "The Passport authentication failed: #{result.code}" }
            Operations.failure :passport_authentication_failed, object: failure_rack_array
          end
        end

        private

        attr_reader :verb, :path, :params

        def authenticate!
          return Operations.failure :missing_verb          if verb.blank?
          return Operations.failure :missing_passport_id   if passport_id.blank?
          return Operations.failure :missing_state         if state.blank?
          return Operations.failure :passport_not_found    if passport.blank?
          return Operations.failure :passport_revoked      if passport.invalid?
          # return Operations.failure :user_not_encapsulated if passport.user.blank?

          unless valid_signature?
            warn { "I found the corresponding passport, but the request was not properly signed with it." }
            return Operations.failure :invalid_signature, object: failure_rack_array
          end

          debug { "The request was properly signed, I found the corresponding passport." }
          update_passport

          if passport.state == state
            Operations.success :signature_approved_no_changes, object: success_same_state_rack_array
          else
            debug { "The current user state #{passport.state.inspect} does not match the provided state #{state.inspect}" }
            Operations.success :signature_approved_state_changed, object: success_new_state_rack_array
          end
        end

        def success_new_state_rack_array
          payload = passport.as_json
          [201, { 'Content-Type' => 'application/json' }, [payload.to_json]]
        end

        def success_same_state_rack_array
          [204, { 'Content-Type' => 'application/json' }, []]
        end

        def failure_rack_array
          payload = { status: :error, code: :passport_authentication_failed }
          [401, { 'Content-Type' => 'application/json' }, [payload.to_json]]
        end

        def passport
          @passport ||= backend.find_by_id passport_id
        end

        def passport_id
          request.authenticate { |passport_id| return passport_id }
        rescue Signature::AuthenticationError
          nil
        end

        def valid_signature?
          !!request.authenticate { Signature::Token.new passport_id, passport.secret }
        rescue Signature::AuthenticationError => exception
          false
        end

        def request
          @request ||= Signature::Request.new verb, path, params
        end

        def update_passport
          if passport.ip == ip && passport.agent == user_agent
            # For some reason we never get here so we update it all all the time right now.
            Operations.success :already_up_to_date
          else
            debug { "Updating activity of Passport #{passport.id}" }
            passport.update_attributes ip: ip, agent: user_agent, activity_at: Time.now
          end
        end

        def ip
          params['ip']
        end

        def user_agent
          params['user_agent']
        end

        def state
          params['state']
        end

        def backend
          ::SSO::Server::Passport
        end

      end
    end
  end
end
