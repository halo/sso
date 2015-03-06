require 'active_record'

module SSO
  module Server
    # This could be MongoDB or whatever
    class Passport < ActiveRecord::Base
      include ::SSO::Logging

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

      def export
        debug { "Exporting Passport #{id} including the encapsulated user." }
        {
          id: id,
          secret: secret,
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
        result = nil
        time = Benchmark.realtime do
          result = OpenSSL::HMAC.hexdigest user_state_digest, user_state_key, user_state_base
        end
        debug { "The user state digest is #{result.inspect}" }
        debug { "Calculating the user state took #{(time * 1000).round(2)}ms" }
        result
      end

      def user_state_digest
        OpenSSL::Digest.new 'sha1'
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
