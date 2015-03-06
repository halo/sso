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
          ::SSO.config.logger.warn('SSO::Test::Helpers') { "RSpec caught an outgoing HTTParty request to #{url.inspect} and re-routes it back into the Rails integration test framework..." }

          url = URI.parse url
          expect(url.host).to include '.example.com'
          expect(url.scheme).to eq 'https'

          if options[:basic_auth].present?
            options[:headers]['HTTP_AUTHORIZATION'] = "Basic " + Base64::encode64("#{options[:basic_auth][:username]}:#{options[:basic_auth][:password]}")
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

          parsed_response = JSON.parse(response.body) rescue nil
          OpenStruct.new code: response.code.to_i, parsed_response: parsed_response
        end
      end

    end
  end
end
