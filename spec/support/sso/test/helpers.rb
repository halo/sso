require 'httparty'

module SSO
  module Test
    module Helpers

      def redirect_httparty_to_rails_stack
        redirect_httparty :get
        redirect_httparty :post
      end

      private

      def redirect_httparty(method)
        allow(HTTParty).to receive(method) do |url, options|
          ::SSO.config.logger.warn('SSO::Test::Helpers') do
            "RSpec caught an outgoing HTTParty request to #{url.inspect} and re-routes it back into the Rails integration test framework..."
          end

          url = URI.parse url
          expect(url.host).to include '.example.com'
          expect(url.scheme).to eq 'https'

          if options[:basic_auth].present?
            basic_auth_header = 'Basic ' + Base64.encode64("#{options[:basic_auth][:username]}:#{options[:basic_auth][:password]}")
            options[:headers]['HTTP_AUTHORIZATION'] = basic_auth_header
          end

          case method
          when :post
            query_string = options[:query].to_query.present? ? "?#{options[:query].to_query}" : nil
            send method, "#{url.path}#{query_string}", options[:body], options[:headers]
          when :get
            send method, url.path, options[:query], options[:headers]
          else
            fail NotImplementedError
          end

          convert_rails_response_to_httparty_response response
        end
      end

      def convert_rails_response_to_httparty_response(response)
        parsed_response = JSON.parse response.body
        OpenStruct.new code: response.code.to_i, parsed_response: parsed_response

      rescue JSON::ParserError
        ::SSO.config.logger.warn('SSO::Test::Helpers') do
          'It looks like I could not parse that JSON response. I will behave just like HTTParty and not raise an Exception for this.'
        end
        OpenStruct.new code: response.code.to_i
      end

    end
  end
end
