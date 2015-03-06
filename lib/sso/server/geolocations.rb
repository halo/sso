module SSO
  module Server
    module Geolocations
      def self.human_readable_location_for_ip(_)
        # Implement your favorite GeoIP lookup here
        'New York'
      end
    end
  end
end
