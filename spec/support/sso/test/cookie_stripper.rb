module SSO
  module Test
    # There is no good way to simulate disabled cookies in Rails,
    # so we inject this Middleware which actually removes them from our incoming requests.
    #
    class CookieStripper

      def initialize(app)
        fail 'What are you doing?' unless Rails.env.test?
        @app = app
      end

      def call(env)
        Rack::Request.new(env).cookies.clear if SSO::Test.strip_cookies
        @app.call(env)
      end

    end
  end
end
