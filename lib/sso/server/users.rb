module SSO
  module Server
    module Users
      def self.find_by_id(id)
        # Implement your Business logic to fetch users here
        # Example:
        ::User.find_by_id id
      end
    end
  end
end
