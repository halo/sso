module SSO
  module Client
    class Passport

      attr_reader :id, :secret, :chip
      attr_accessor :state, :user

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

      def modified!
        @modified = true
      end

      def modified?
        @modified == true
      end

      def unmodified?
        !modified?
      end

      def delta
        { state: state, user: user }
      end

    end
  end
end
