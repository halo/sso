module SSO
  module Server
    module Passports
      class Backend < ActiveRecord::Base

        before_validation :ensure_secret
        before_validation :ensure_group_id
        before_validation :ensure_activity_at

        before_save :update_location

        belongs_to :application, class_name: 'Doorkeeper::Application'

        validates :secret, :group_id, presence: true
        validates :oauth_access_token_id, uniqueness: { scope: [:owner_id, :revoked_at], allow_blank: true }
        validates :revoke_reason, allow_blank: true, format: { with: /\A[a-z_]+\z/ }
        validates :application_id, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

        def to_s
          ['Passport', owner_id, ip, activity_at].join ', '
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
          location_name = ::SSO::Server::Geolocations.human_readable_location_for_ip self.ip
          logger.debug { "Updating geolocation for #{self.ip} which is #{location_name}" }
          self.location = location_name
        end

      end
    end
  end
end
