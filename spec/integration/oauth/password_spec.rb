require 'spec_helper'

RSpec.describe 'OAuth 2.0 Resource Owner Password Credentials Grant', type: :request, db: true do

  let!(:user)    { create :user }
  let!(:client)  { create :outsider_doorkeeper_application }

  let(:scope)    { :outsider }
  let(:password) { user.password }
  let(:params)   { { grant_type: :password, client_id: client.uid, client_secret: client.secret, username: user.email, password: password, scope: scope } }
  let(:headers)  { { 'HTTP_ACCEPT' => 'application/json' } }

  let(:latest_access_token) { ::Doorkeeper::AccessToken.last }
  let(:latest_passport)     { ::SSO::Server::Passport.last }
  let(:passport_count)      { ::SSO::Server::Passport.count }
  let(:result)              { JSON.parse(response.body) }

  before do
    SSO.config.passport_chip_key = SecureRandom.hex
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

    context 'Exchanging the Access Token for a Passport' do
      let(:token) { JSON.parse(response.body).fetch 'access_token' }

      before do
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

  context 'wrong password' do
    let(:password) { 'wrong-password-sent-by-hackerz' }

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
