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
          debug { "Verifying request signature using Passport secret #{passport_secret.inspect}" }
          signature_request.authenticate do |passport_id|
            @passport_id = passport_id
            Signature::Token.new passport_id, passport_secret
          end
          debug { 'Signature looks legit.' }
          Operations.success :passport_signature_valid

        rescue ::Signature::AuthenticationError => exception
          debug { "The Signature Authentication failed. #{exception.message}" }
          yield Operations.failure :invalid_passport_signature
        end

        def verifier
          ::SSO::Client::PassportVerifier.new passport_id: passport_id, passport_state: 'refresh', passport_secret: passport_secret, user_ip: ip, user_agent: agent, device_id: device_id
        end

        def verification
          @verification ||= verifier.call
        end

        def failure_rack_array
          payload = { success: true, code: :invalid_passport_signature }
          [200, { 'Content-Type' => 'application/json' }, [payload.to_json]]
        end

        def signature_request
          debug { "Verifying signature of #{request.request_method.inspect} #{request.path.inspect} #{request.params.inspect}"}
          ::Signature::Request.new request.request_method, request.path, request.params
        end

        def check_chip
          Operations.success :chip_syntax_valid
        end

        def chip_decryption
          debug { "Validating chip decryptability of raw chip #{chip.inspect}"}
          yield Operations.failure(:missing_chip, object: params) if chip.blank?
          yield Operations.failure(:missing_chip_key) unless chip_key
          yield Operations.failure(:missing_chip_iv) unless chip_iv
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

        def passport_secret
          decrypt_chip
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
          request.params['udid']
        end

      end
    end
  end
end
