module SSO
  module Server
    module Passports
      class Activity
        include ::SSO::Logging

        attr_reader :passport, :request

        def initialize(passport:, request:)
          @passport = passport
          @request = request
        end

        def call
          if passport.insider? || trusted_proxy_app?
            proxied_ip = request['ip']
            unless proxied_ip
              warn { "There should have been a proxied IP param, but there was none. I will use the immediate IP #{immediate_ip} now." }
              proxied_ip = immediate_ip
            end
            attributes = { ip: proxied_ip, agent: request['agent'], device: request['device_id'] }
          else
            attributes = { ip: immediate_ip, agent: request.user_agent, device: request['device_id'] }
          end
          attributes.merge! activity_at: Time.now

          passport.stamps ||= {}  # <- Not thread-safe, this may potentially delete all existing stamps, I guess
          passport.stamps[attributes[:ip]] = Time.now.to_i

          debug { "Updating activity of #{passport.insider? ? :insider : :outsider} Passport #{passport.id.inspect} using IP #{attributes[:ip]} agent #{attributes[:agent]} and device #{attributes[:device]}" }
          if passport.update_attributes(attributes)
            Operations.success :passport_metadata_updated
          else
            Operations.failure :could_not_update_passport_activity, object: passport.errors.to_hash
          end
        end

        def trusted_proxy_app?
          unless insider_id
            debug { 'This is an immediate request because there is no insider_id param' }
            return
          end

          unless insider_signature
            debug { 'This is an immediate request because there is no insider_signature param' }
            return
          end

          unless application = ::Doorkeeper::Application.find_by_id(insider_id)
            warn { 'The insider_id param does not correspond to an existing Doorkeeper Application' }
            return
          end

          unless application.scopes.include?('insider')
            warn { 'The Doorkeeper Application belonging to this insider_id param is considered an outsider' }
            return
          end

          expected_signature = ::OpenSSL::HMAC.hexdigest signature_digest, application.secret, proxied_ip
          unless insider_signature == expected_signature
            warn { "The insider signature #{insider_signature.inspect} does not match my expectation #{expected_signature.inspect}" }
            return
          end

          debug { 'This is a proxied request because insider_id and insider_signature are valid' }
          true
        end

        def signature_digest
          OpenSSL::Digest.new 'sha1'
        end

        def proxied_ip
          request['ip']
        end

        def insider_id
          request['insider_id']
        end

        def insider_signature
          request['insider_signature']
        end

        def immediate_ip
          request.respond_to?(:remote_ip) ? request.remote_ip : request.ip
        end
      end
    end
  end
end
