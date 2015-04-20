module SSO
  module Server
    module Authentications
      class Passport
        include ::SSO::Logging

        def initialize(request)
          @request = request
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

        attr_reader :request

        def authenticate!
          check_arguments { |failure| return failure }

          unless valid_signature?
            warn { 'I found the corresponding passport, but the request was not properly signed with it.' }
            return Operations.failure :invalid_signature, object: failure_rack_array
          end

          debug { 'The request was properly signed, I found the corresponding passport. Updating activity...' }
          update_passport
          debug { 'Attaching user to passport' }
          passport.load_user!

          if passport.state == state
            debug { "The current user state #{passport.state.inspect} did not change." }
            Operations.success :signature_approved_no_changes, object: success_same_state_rack_array
          else
            debug { "The current user state #{passport.state.inspect} does not match the provided state #{state.inspect}" }
            Operations.success :signature_approved_state_changed, object: success_new_state_rack_array
          end
        end

        def check_arguments
          debug { 'Checking arguments...' }
          yield Operations.failure :missing_verb         if verb.blank?
          yield Operations.failure :missing_passport_id  if passport_id.blank?
          yield Operations.failure :missing_state        if state.blank?
          yield Operations.failure :passport_not_found   if passport.blank?
          yield Operations.failure :passport_revoked     if passport.invalid?
          debug { 'Arguments are fine.' }
          Operations.success :arguments_are_valid
        end

        def success_new_state_rack_array
          payload = { success: true, code: :passport_changed, passport: passport.export }
          [200, { 'Content-Type' => 'application/json' }, [payload.to_json]]
        end

        def success_same_state_rack_array
          payload = { success: true, code: :passpord_unmodified }
          [200, { 'Content-Type' => 'application/json' }, [payload.to_json]]
        end

        # You might be wondering why we don't simply return a 401 or 404 status code.
        # The reason is that the receiving end would have no way to determine whether that reply is due to a
        # nginx configuration error or because the passport is actually invalid. We don't want to revoke
        # all passports simply because a load balancer is pointing to the wrong Rails application or something.
        #
        def failure_rack_array
          payload = { success: true, code: :passport_invalid }
          [200, { 'Content-Type' => 'application/json' }, [payload.to_json]]
        end

        def passport
          @passport ||= passport!
        end

        def passport!
          record = backend.find_by_id(passport_id)
          return unless record
          debug { "Successfully loaded Passport #{passport_id} from database." }
          record
        end

        def passport_id
          signature_request.authenticate { |passport_id| return passport_id }

        rescue Signature::AuthenticationError
          nil
        end

        def valid_signature?
          debug { 'Checking request signature...' }
          signature_request.authenticate { Signature::Token.new passport_id, passport.secret }
          true
        rescue Signature::AuthenticationError
          debug { 'It looks like the API signature for the passport verification was incorrect.' }
          false
        end

        def signature_request
          @signature_request ||= Signature::Request.new verb, path, params
        end

        def update_passport
          ::SSO::Server::Passports.update_activity passport_id: passport.id, request: request
        end

        def verb
          request.request_method
        end

        def path
          request.path
        end

        def params
          request.params
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
