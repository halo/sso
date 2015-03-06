require 'spec_helper'

RSpec.describe 'OAuth 2.0 Resource Owner Password Credentials Grant', type: :request do

  let!(:user)    { create :user }
  let!(:client)  { create :unscoped_doorkeeper_application }

  let(:params_password) { user.password }
  let(:params)          { { grant_type: :password, client_id: client.uid, client_secret: client.secret, username: user.email, password: params_password } }
  let(:headers)         { { 'HTTP_ACCEPT' => 'application/json' } }

  let(:latest_passport)     { ::SSO::Server::Passport.last }
  let(:passport_count)      { ::SSO::Server::Passport.count }
  let(:latest_access_token) { ::Doorkeeper::AccessToken.last }
  let(:result)              { JSON.parse(response.body) }

  before do
    post '/oauth/token', params, headers
  end

  context 'correct password' do
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
  end

  context 'wrong password' do
    let(:params_password) { 'wrong-password-sent-by-hackerz' }

    it 'fails' do
      expect(response.status).to eq 401
    end

    it 'responds with JSON serialized params' do
      expect(result).to be_instance_of Hash
    end

    it 'provides a errornous status' do
      expect(result['status']).to eq 'error'
    end

    it 'provides a useful code' do
      expect(result['code']).to eq 'authentication_failed'
    end

    it 'does not generate anny passports' do
      expect(passport_count).to eq 0
    end
  end

end
