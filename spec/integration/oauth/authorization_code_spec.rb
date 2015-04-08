require 'spec_helper'

RSpec.describe 'OAuth 2.0 Authorization Grant Flow', type: :request, db: true do

  let!(:user)        { create :user }
  let!(:client)      { create :outsider_doorkeeper_application }
  let(:redirect_uri) { client.redirect_uri }

  let(:scope)           { :outsider }
  let(:grant_params)    { { client_id: client.uid, redirect_uri: redirect_uri, response_type: :code, scope: scope, state: 'some_random_string' } }
  let(:result)          { JSON.parse(response.body) }

  let(:latest_grant)        { ::Doorkeeper::AccessGrant.last }
  let(:latest_access_token) { ::Doorkeeper::AccessToken.last }
  let(:access_token_count)  { ::Doorkeeper::AccessToken.count }
  let(:grant_count)         { ::Doorkeeper::AccessGrant.count }

  let(:latest_passport)     { ::SSO::Server::Passport.last }
  let(:passport_count)      { ::SSO::Server::Passport.count }

  before do
    get_via_redirect '/oauth/authorize', grant_params
  end

  it 'remembers the return path' do
    expect(session[:return_path]).to eq "/oauth/authorize?#{grant_params.to_query}"
  end

  it 'shows to the login page' do
    expect(response).to render_template 'sessions/new'
  end

  context 'Logging in' do
    before do
      post '/sessions', username: user.email, password: user.password
      follow_redirect!
    end

    it 'redirects to the application callback including the Grant Token' do
      expect(latest_grant).to be_present
      expect(response).to redirect_to "#{client.redirect_uri}?code=#{latest_grant.token}&state=some_random_string"
    end

    it 'generates a passport with the grant token attached to it' do
      expect(latest_passport.oauth_access_grant_id).to eq latest_grant.id
    end

    it 'does not generate multiple authorization grants' do
      expect(grant_count).to eq 1
    end

    context 'Exchanging the Authorization Grant for an Access Token' do
      let(:grant)      { ::Rack::Utils.parse_query(URI.parse(response.location).query).fetch('code') }
      let(:grant_type) { :authorization_code }
      let(:params)     { { client_id: client.uid, client_secret: client.secret, code: grant, grant_type: grant_type, redirect_uri: redirect_uri } }
      let(:token)      { JSON.parse(response.body).fetch 'access_token' }

      before do
        post '/oauth/token', params
      end

      it 'succeeds' do
        expect(response.status).to eq 200
      end

      it 'responds with JSON serialized params' do
        expect(result).to be_instance_of Hash
      end

      it 'includes the access_token' do
        expect(result['access_token']).to eq latest_access_token.token
      end

      it 'generates a passport with the grant token attached to it' do
        expect(latest_passport.oauth_access_token_id).to eq latest_access_token.id
      end

      it 'does not generate multiple passports' do
        expect(passport_count).to eq 1
      end

      it 'does not generate multiple access tokens' do
        expect(access_token_count).to eq 1
      end

      it 'succeeds' do
        expect(response.status).to eq 200
      end

      context 'Exchanging the Access Token for a Passport' do
        before do
          SSO.config.passport_chip_key = SecureRandom.hex
          post '/oauth/sso/v1/passports', access_token: token
        end

        it 'succeeds' do
          expect(response.status).to eq 200
        end

        it 'gets the passport' do
          expect(result['passport']).to be_present
        end

        it 'is the passport for that access token' do
          expect(result['passport']['id']).to eq latest_passport.id
          expect(latest_passport.oauth_access_token_id).to eq latest_access_token.id
        end

        it 'is an outsider passport' do
          expect(latest_passport).to_not be_insider
        end

        context 'insider application' do
          let!(:client) { create :insider_doorkeeper_application }
          let(:scope)   { :insider }

          it 'is an insider passport' do
            expect(latest_passport).to be_insider
          end
        end
      end

    end
  end

end
