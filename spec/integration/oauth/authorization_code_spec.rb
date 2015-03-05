require 'spec_helper'

RSpec.describe 'OAuth 2.0 Authorization Grant Flow', type: :request, db: true, create_employees: true do

  let(:grant_params)    { { client_id: alpha_id, redirect_uri: alpha_redirect_uri, response_type: :code, state: 'some_random_string' } }
  let(:latest_grant)    { Doorkeeper::AccessGrant.last }
  let(:latest_passport) { SSO::Server::Passports::Passport.last }

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
      post '/sessions', username: 'carol', password: 'p4ssword'
      follow_redirect!
    end

    it 'redirects to the application callback including the Grant Token' do
      expect(latest_grant).to be_present
      expect(response).to redirect_to "https://alpha.example.com/auth/sso/callback?code=#{latest_grant.token}&state=some_random_string"
    end

    it 'generates a passport with the grant token attached to it' do
      expect(latest_passport.oauth_access_grant_id).to eq latest_grant.id
    end

    context 'Exchanging the Authorization Grant for an Access Token' do
      let(:grant_token)     { ::Rack::Utils.parse_query(URI.parse(response.location).query).fetch('code') }
      let(:exchange_params) { { client_id: alpha_id, client_secret: alpha_secret, code: grant_token, grant_type: :authorization_code, redirect_uri: alpha_redirect_uri } }
      let(:access_token)    { JSON.parse(response.body).fetch 'access_token' }

      before do
        post '/oauth/token', exchange_params
      end

      it 'gets the access token' do
        expect(access_token).to be_present
      end
    end
  end

end
