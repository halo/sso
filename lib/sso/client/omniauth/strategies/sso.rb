require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class SSO < OmniAuth::Strategies::OAuth2

      def self.endpoint
        if ENV['OMNIAUTH_SSO_ENDPOINT'].to_s != ''
          ENV['OMNIAUTH_SSO_ENDPOINT'].to_s
        elsif development_environment?
          ENV['OMNIAUTH_SSO_ENDPOINT'] || 'http://sso.dev:8080'
        elsif test_environment?
          'https://sso.example.com'
        else
          fail 'You must set OMNIAUTH_SSO_ENDPOINT to point to the SSO OAuth server'
        end
      end

      def self.development_environment?
        defined?(Rails) && Rails.env.development?
      end

      def self.test_environment?
        defined?(Rails) && Rails.env.test? || ENV['RACK_ENV'] == 'test'
      end

      def self.passports_path
        if ENV['OMNIAUTH_SSO_PASSPORTS_PATH'].to_s != ''
          ENV['OMNIAUTH_SSO_PASSPORTS_PATH'].to_s
        else
          # We know this namespace is not occupied because /oauth is owned by Doorkeeper
          '/oauth/sso/v1/passports'
        end
      end

      option :name, :sso
      option :client_options, site: endpoint, authorize_path: '/oauth/authorize'

      uid { raw_info['id'] if raw_info }

      info do
        {
          # Passport
          id:     uid,
          state:  raw_info['state'],
          secret: raw_info['secret'],
          user:   raw_info['user'],
        }
      end

      def raw_info
        params = { ip: request.ip, agent: request.user_agent }
        @raw_info ||= access_token.post(self.class.passports_path, params: params).parsed
      end

    end
  end
end
