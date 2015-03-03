module SSO
  module Client
    module Warden
      # This is a helpful `Warden::Manager.after_fetch` hook for Alpha and Beta.
      # Whenever Carol is fetched out of the session, we also verify her passport.
      #
      # Usage:
      #
      #  options = { scope: :admin, not_if: -> { |user| user.critical? } }
      #  ::Warden::Manager.after_fetch SSO::Client::Warden::AfterFetch(options)
      #
      class AfterFetch

        def self.call(options, &block)
          fail options.inspect
        end

        def initialize()

        end

        def warden_scope
          options[:scope]
        end

        def relevant_warden_scope?
          return true if scope.blank? && warden_scope.blank?
          return true if scope.blank? && warden_scope == :default
          scope.to_s == warden_scope.to_s
        end

        def base_endpoint
          OmniAuth::Strategies::SSO.endpoint
        end

        def ip
          warden.request.ip
        end

      end
    end
  end
end
