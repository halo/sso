require 'spec_helper'

RSpec.describe 'OAuth 2.0 Authorization Grant Flow', type: :request, db: true do

  let!(:user)        { create :user }
  let!(:client)      { create :unscoped_doorkeeper_application }
  let(:redirect_uri) { client.redirect_uri }

  let(:grant_params)    { { client_id: client.uid, redirect_uri: redirect_uri, response_type: :code, scope: :insider, state: 'some_random_string' } }
  let(:latest_grant)    { Doorkeeper::AccessGrant.last }
  let(:latest_passport) { SSO::Server::Passport.last }

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

    context 'Exchanging the Authorization Grant for an Access Token' do
      let(:grant)        { ::Rack::Utils.parse_query(URI.parse(response.location).query).fetch('code') }
      let(:grant_type)   { :authorization_code }
      let(:params)       { { client_id: client.uid, client_secret: client.secret, code: grant, grant_type: grant_type, redirect_uri: redirect_uri } }
      let(:access_token) { JSON.parse(response.body).fetch 'access_token' }

      before do
        post '/oauth/token', params
      end

      it 'gets the access token' do
        expect(access_token).to be_present
      end
    end
  end

end
