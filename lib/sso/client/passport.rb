module SSO
  module Client
    class Passport

      attr_reader :id, :secret, :state, :user

      def initialize(id:, secret:, state:, user:)
        @id, @secret, @state, @user = id, secret, state, user
      end

      def verify!
        verified = true
      end

      def verified?
        !!verified
      end

      def unverified?
        !verified?
      end

      private

      attr_writer :verified

    end
  end
end
