module SSO
  module Client
    class Passport

      attr_reader :id, :secret, :state, :user, :chip

      def initialize(id:, secret:, state:, user:, chip: nil)
        @id     = id
        @secret = secret
        @state  = state
        @user   = user
        @chip   = chip
      end

      def verified!
        @verified = true
      end

      def verified?
        @verified == true
      end

      def unverified?
        !verified?
      end

    end
  end
end
