module SSO
  module Client
    module Authentications
      class Passport
        include ::SSO::Logging
        include ::SSO::Benchmarking

        delegate :params, to: :request

        def initialize(request)
          @request = request
        end

        def authenticate
          debug { "Performing authentication..." }
          result = authenticate!

          if result.success?
            debug { "Authentication succeeded." }
            return result
          end

          debug { "The Client Passport authentication failed: #{result.code}" }
          Operations.failure :passport_authentication_failed, object: failure_rack_array
        end

        private

        attr_reader :request, :passport_id

        def authenticate!
          chip_decryption         { |failure| return failure }
          check_request_signature { |failure| return failure }
          passport = retrieve_passport { |failure| return failure }
          passport.verified!

          Operations.success :passport_received, object: passport
        end

        def retrieve_passport
          debug { 'Retrieving Passport from server...' }
          if verification.success? && verification.code == :passport_valid_and_modified
            passport = verification.object

            debug { "Successfully retrieved Passport with ID #{passport_id} from server." }
            return passport
          else
            debug { 'Could not obtain Passport from server.' }
            yield verification
          end
        end

        def check_request_signature
          debug { "Verifying request signature using Passport secret #{chip_passport_secret.inspect}" }
          signature_request.authenticate do |passport_id|
            Signature::Token.new passport_id, chip_passport_secret
          end
          debug { 'Signature looks legit.' }
          Operations.success :passport_signature_valid

        rescue ::Signature::AuthenticationError => exception
          debug { "The Signature Authentication failed. #{exception.message}" }
          yield Operations.failure :invalid_passport_signature
        end

        def verifier
          ::SSO::Client::PassportVerifier.new passport_id: passport_id, passport_state: 'refresh', passport_secret: chip_passport_secret, user_ip: ip, user_agent: agent, device_id: device_id
        end

        def verification
          @verification ||= verifier.call
        end

        def failure_rack_array
          payload = { success: true, code: :passport_verification_failed }
          [200, { 'Content-Type' => 'application/json' }, [payload.to_json]]
        end

        def signature_request
          debug { "Verifying signature of #{request.request_method.inspect} #{request.path.inspect} #{request.params.inspect}"}
          ::Signature::Request.new request.request_method, request.path, request.params
        end

        def passport_id
          return @passport_id if @passport_id
          signature_request.authenticate do |auth_key|
            return @passport_id = auth_key
          end

        rescue ::Signature::AuthenticationError
          nil
        end

        def chip_decryption
          debug { "Validating chip decryptability of raw chip #{chip.inspect}"}
          yield Operations.failure(:missing_chip, object: params) if chip.blank?
          yield Operations.failure(:missing_chip_key) unless chip_key
          yield Operations.failure(:missing_chip_iv) unless chip_iv
          yield Operations.failure(:chip_does_not_belong_to_passport) unless chip_belongs_to_passport?
          Operations.success :here_is_your_chip_plaintext, object: decrypt_chip

        rescue OpenSSL::Cipher::CipherError => exception
          yield Operations.failure :chip_decryption_failed, object: exception.message
        end

        def decrypt_chip
          @decrypt_chip ||= decrypt_chip!
        end

        def decrypt_chip!
          benchmark 'Passport chip decryption' do
            decipher = chip_digest
            decipher.decrypt
            decipher.key = chip_key
            decipher.iv = chip_iv
            plaintext = decipher.update(chip_ciphertext) + decipher.final
            logger.debug { "Decryptied chip plaintext #{plaintext.inspect} using key #{chip_key.inspect} and iv #{chip_iv.inspect} and ciphertext #{chip_ciphertext.inspect}"}
            plaintext
          end
        end

        def chip_passport_secret
          decrypt_chip.to_s.split('|').last
        end

        def chip_passport_id
          decrypt_chip.to_s.split('|').first
        end

        def chip_belongs_to_passport?
          unless passport_id
            debug { "Unknown passport_id" }
            return false
          end

          unless chip_passport_id
            debug { "Unknown passport_id" }
            return false
          end

          if passport_id.to_s == chip_passport_id
            debug { "The chip on passport #{passport_id.inspect} appears to belong to it." }
            true
          else
            info { "The passport with ID #{passport_id.inspect} has a chip with the wrong ID #{chip_passport_id.inspect}" }
            false
          end
        end

        def chip_key
          ::SSO.config.passport_chip_key
        end

        def user_state_digest
          ::OpenSSL::Digest.new 'sha1'
        end

        def chip_ciphertext
          Base64.decode64 encoded_chip_ciphertext
        end

        def encoded_chip_ciphertext
          chip_ciphertext_and_iv.first
        end

        def chip_iv
          Base64.decode64 chip_ciphertext_and_iv.last
        end

        def encoded_chip_iv
          chip_iv
        end

        def chip_ciphertext_and_iv
          chip.to_s.split '|'
        end

        def chip
          params['passport_chip']
        end

        #def warden
        #  request.env['warden']
        #end

        def chip_digest
          ::OpenSSL::Cipher::AES256.new :CBC
        end

        # TODO Use ActionDispatch remote IP or you might get the Load Balancer's IP instead :(
        def ip
          request.ip
        end

        def agent
          request.user_agent
        end

        def device_id
          request.params['device_id']
        end

      end
    end
  end
end
