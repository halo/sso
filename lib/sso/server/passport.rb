require 'active_record'

module SSO
  module Server
    # This could be MongoDB or whatever
    class Passport < ActiveRecord::Base
      include ::SSO::Logging
      include ::SSO::Benchmarking

      self.table_name = 'passports'

      before_validation :ensure_secret
      before_validation :ensure_group_id
      before_validation :ensure_activity_at

      before_save :update_location

      belongs_to :application, class_name: 'Doorkeeper::Application'

      validates :secret, :group_id, presence: true
      validates :oauth_access_token_id, uniqueness: { scope: [:owner_id, :revoked_at], allow_blank: true }
      validates :revoke_reason, allow_blank: true, format: { with: /\A[a-z_]+\z/ }
      validates :application_id, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

      attr_accessor :user
      attr_reader :chip

      def export
        debug { "Exporting Passport #{id} including the encapsulated user." }
        {
          id: id,
          secret: secret,
          state: state,
          chip: chip,
          user: user,
        }
      end

      def to_s
        ['Passport', owner_id, ip, activity_at].join ', '
      end

      def state
        if user
          @state ||= state!
        else
          warn { 'Wait a minute, this Passport is not encapsulating a user!' }
          'missing_user_for_state_calculation'
        end
      end

      def state!
        benchmark 'Passport user state calculation' do
          OpenSSL::HMAC.hexdigest user_state_digest, user_state_key, user_state_base
        end
      end

      def create_chip!
        @chip = chip!
      end

      def chip!
        benchmark 'Passport chip encryption' do
          ensure_secret
          cipher = chip_digest
          cipher.encrypt
          cipher.key = chip_key
          chip_iv = cipher.random_iv
          ciphertext = cipher.update chip_plaintext
          ciphertext << cipher.final
          debug { "The Passport chip plaintext #{chip_plaintext.inspect} was encrypted using key #{chip_key.inspect} and IV #{chip_iv.inspect} and resultet in ciphertext #{ciphertext.inspect}" }
          chip = [Base64.encode64(ciphertext).strip(), Base64.encode64(chip_iv).strip()].join('|')
          logger.debug { "Augmented passport #{id.inspect} with chip #{chip.inspect}" }
          chip
        end
      end

      def user_state_digest
        OpenSSL::Digest.new 'sha1'
      end

      def chip_digest
        OpenSSL::Cipher::AES256.new :CBC
      end

      def chip_key
        SSO.config.passport_chip_key
      end

      # Don't get confused, the chip plaintext is the passport secret
      def chip_plaintext
        secret
      end

      def user_state_key
        ::SSO.config.user_state_key
      end

      def user_state_base
        ::SSO.config.user_state_base.call user
      end

      private

      def ensure_secret
        self.secret ||= SecureRandom.uuid
      end

      def ensure_group_id
        self.group_id ||= SecureRandom.uuid
      end

      def ensure_activity_at
        self.activity_at ||= Time.now
      end

      def update_location
        location_name = ::SSO::Server::Geolocations.human_readable_location_for_ip ip
        debug { "Updating geolocation for #{ip} which is #{location_name}" }
        self.location = location_name
      end

    end
  end
end
