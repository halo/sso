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

          debug { 'The request was properly signed, I found the corresponding passport.' }
          update_passport

          if passport.state == state
            Operations.success :signature_approved_no_changes, object: success_same_state_rack_array
          else
            debug { "The current user state #{passport.state.inspect} does not match the provided state #{state.inspect}" }
            Operations.success :signature_approved_state_changed, object: success_new_state_rack_array
          end
        end

        def check_arguments
          yield Operations.failure :missing_verb         if verb.blank?
          yield Operations.failure :missing_passport_id  if passport_id.blank?
          yield Operations.failure :missing_state        if state.blank?
          yield Operations.failure :passport_not_found   if passport.blank?
          yield Operations.failure :passport_revoked     if passport.invalid?
          # yield Operations.failure :user_not_encapsulated if passport.user.blank?
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
          @passport ||= backend.find_by_id passport_id
        end

        def passport_id
          signature_request.authenticate { |passport_id| return passport_id }
        rescue Signature::AuthenticationError
          nil
        end

        def valid_signature?
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
          debug { "Will update activity of Passport #{passport.id} if neccesary..." }
          if passport.ip.to_s == ip.to_s && passport.agent.to_s == user_agent.to_s
            debug { "No changes in IP or User Agent so I won't perform an update now..." }
            Operations.success :already_up_to_date
          else
            debug { "Yes, it is necessary, updating activity of Passport #{passport.id}" }
            passport.update_attributes ip: ip.to_s, agent: user_agent, activity_at: Time.now
            Operations.success :passport_metadata_updated
          end
        end

        def application
          passport.application
        end

        def app_scopes
          application.scopes
        end

        def insider?
          if app_scopes.empty?
            warn { "Doorkeeper::Application #{application.name} with ID #{application.id} has no scope restrictions. Assuming 'outsider' for now." }
            return false
          end

          app_scopes.has_scopes? [:insider]
        end

        def ip
          if insider?
            params['ip']
          else
            request_ip
          end
        end

        def user_agent
          if insider?
            params['user_agent']
          else
            request.user_agent
          end
        end

        def request_ip
          request.env['action_dispatch.remote_ip'] || fail('Whoops, I thought you were using Rails, but action_dispatch.remote_ip is empty!')
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
