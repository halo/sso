module SSO
  module Server
    # This is the one interaction point with persisting and querying Passports.
    module Passports
      extend ::SSO::Logging

      def self.find(id)
        record = backend.find_by_id(id)

        if record
          Operations.success(:record_found, object: record)
        else
          Operations.failure :record_not_found
        end

      rescue => exception
        Operations.failure :backend_error, object: exception
      end

      def self.generate(owner_id:, ip:, agent:, device: nil)
        debug { "Generating Passport for user ID #{owner_id.inspect} and IP #{ip.inspect} and Agent #{agent.inspect} and Device #{device.inspect}" }

        record = backend.create owner_id: owner_id, ip: ip, agent: agent, device: device

        if record.persisted?
          debug { "Successfully generated passport with ID #{record.id}" }
          Operations.success :generation_successful, object: record.id
        else
          Operations.failure :persistence_failed, object: record.errors.to_hash
        end
      end

      def self.register_authorization_grant(passport_id:, token:)
        record       = find_valid_passport(passport_id) { |failure| return failure }
        access_grant = find_valid_access_grant(token)   { |failure| return failure }

        if record.update_attribute :oauth_access_grant_id, access_grant.id
          debug { "Successfully augmented Passport #{record.id} with Authorization Grant ID #{access_grant.id} which is #{access_grant.token}" }
          Operations.success :passport_augmented_with_access_token
        else
          Operations.failure :could_not_augment_passport_with_access_token
        end
      end

      def self.register_access_token_from_grant(grant_token:, access_token:)
        access_grant = find_valid_access_grant(grant_token)             { |failure| return failure }
        access_token = find_valid_access_token(access_token)            { |failure| return failure }
        record       = find_valid_passport_by_grant_id(access_grant.id) { |failure| return failure }

        if record.update_attribute :oauth_access_token_id, access_token.id
          debug { "Successfully augmented Passport #{record.id} with Access Token ID #{access_token.id} which is #{access_token.token}" }
          Operations.success :passport_known_by_grant_augmented_with_access_token
        else
          Operations.failure :could_not_augment_passport_known_by_grant_with_access_token
        end
      end

      def self.register_access_token_from_id(passport_id:, access_token:)
        access_token = find_valid_access_token(access_token) { |failure| return failure }
        record       = find_valid_passport(passport_id)      { |failure| return failure }

        if record.update_attribute :oauth_access_token_id, access_token.id
          debug { "Successfully augmented Passport #{record.id} with Access Token ID #{access_token.id} which is #{access_token.token}" }
          Operations.success :passport_augmented_with_access_token
        else
          Operations.failure :could_not_augment_passport_with_access_token
        end
      end

      def self.logout(passport_id:)
        return Operations.failure(:missing_passport_id) if passport_id.blank?

        debug { "Logging out Passport with ID #{passport_id.inspect}" }
        record = backend.find_by_id passport_id
        return Operations.success(:passport_does_not_exist) unless record
        return Operations.success(:passport_already_revoked) if record.revoked_at

        if record.update_attributes revoked_at: Time.now, revoke_reason: :logout
          Operations.success :passports_revoked
        else
          Operations.failure :backend_could_not_revoke_passport
        end
      end

      private

      def self.find_valid_passport(id)
        record = backend.where(revoked_at: nil).find_by_id(id)
        return record if record

        debug { "Could not find valid passport with ID #{id.inspect}" }
        debug { "All I have is #{backend.all.inspect}" }
        yield Operations.failure :passport_not_found if block_given?
        nil
      end

      def self.find_valid_passport_by_grant_id(id)
        record = backend.where(revoked_at: nil).find_by_oauth_access_grant_id(id)
        return record if record

        warn { "Could not find valid passport by Authorization Grant ID #{id.inspect}" }
        yield Operations.failure :passport_not_found
        nil
      end

      def self.find_valid_access_grant(token)
        record = ::Doorkeeper::AccessGrant.find_by_token token

        if record && record.valid?
          record
        else
          warn { "Could not find valid Authorization Grant Token #{token.inspect}" }
          yield Operations.failure :access_grant_not_found
          nil
        end
      end

      def self.find_valid_access_token(token)
        record = ::Doorkeeper::AccessToken.find_by_token token

        if record && record.valid?
          record
        else
          warn { "Could not find valid OAuth Access Token #{token.inspect}" }
          yield Operations.failure :access_token_not_found
          nil
        end
      end

      def self.backend
        ::SSO::Server::Passport
      end

    end
  end
end
