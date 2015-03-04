require 'spec_helper'

RSpec.describe 'OAuth 2.0 Resource Owner Password Credentials Grant', type: :request, db: true, create_customers: true do

  let(:username) { 'carol@example.com' }
  let(:password) { 'p4ssword' }
  let(:params)   { { grant_type: :password, client_id: alpha_id, client_secret: alpha_secret, username: username, password: password } }
  let(:headers)  { { 'HTTP_ACCEPT' => 'application/json' } }

  let(:latest_access_token) { Doorkeeper::AccessToken.last }

  context 'via JSON API' do
    let(:result) { JSON.parse(response.body) }

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

      it 'includes not more information than needed' do
        expect(result.keys).to eq %w(access_token token_type)
      end

      it 'includes the access_token' do
        expect(result['access_token']).to eq latest_access_token.token
      end

      it 'includes the token_type' do
        expect(result['token_type']).to eq 'bearer'
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

      it 'includes no sensitive keys' do
        expect(result.keys).to eq %w(status code)
      end

      it 'provides a errornous status' do
        expect(result['status']).to eq 'error'
      end

      it 'provides a useful code' do
        expect(result['code']).to eq 'authentication_failed'
      end
    end
  end

end
