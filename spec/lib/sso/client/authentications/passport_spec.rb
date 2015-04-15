require 'spec_helper'

RSpec.describe SSO::Client::Authentications::Passport, type: :request, db: true do

  # Untrusted Client
  let(:request_method)    { 'GET' }
  let(:request_path)      { '/some/resource' }
  let(:request_params)    { { passport_chip: passport_chip } }
  let(:signature_token)   { Signature::Token.new passport_id, passport_secret }
  let(:signature_request) { Signature::Request.new(request_method, request_path, request_params) }
  let(:auth_hash)         { signature_request.sign signature_token }
  let(:query_params)      { request_params.merge auth_hash }
  let(:ip)                { '198.51.100.74' }
  let(:agent)             { 'IE7' }

  # Trusted Client
  let(:rack_request)    { double :rack_request, request_method: request_method, ip: ip, user_agent: agent, path: request_path, query_parameters: query_params.stringify_keys, params: query_params.stringify_keys }
  let(:warden_env)      { {} }
  let(:warden_request)  { double :warden_request, ip: ip, user_agent: agent, env: warden_env }
  let(:warden)          { double :warden, request: warden_request }
  let(:client_user)     { double :client_user }
  let(:client_passport) { ::SSO::Client::Passport.new id: passport_id, secret: passport_secret, state: passport_state, user: client_user }
  let(:authentication)  { described_class.new rack_request }
  let(:operation)       { authentication.authenticate }
  let(:passport)        { operation.object }

  # Shared
  let(:passport_id)     { server_passport.id }
  let(:passport_state)  { server_passport.state }
  let(:passport_secret) { server_passport.secret }
  let(:passport_chip)   { server_passport.chip! }

  # Server
  let(:insider)          { false }
  let(:server_user)      { create :user, name: 'Emily', tags: %i(cool nice) }
  let!(:server_passport) { create :passport, user: server_user, owner_id: server_user.id, ip: ip, agent: agent, insider: insider }

  before do
    SSO.config.passport_chip_key = SecureRandom.hex
  end

  context 'no changes' do
    before do
      operation
    end

    context 'outsider passport' do
      it 'succeeds' do
        expect(operation).to be_success
      end

      it 'verifies the passport' do
        expect(passport).to be_verified
      end

      it 'modifies the passport' do
        expect(passport).to be_modified
      end

      it 'tracks the immediate request IP' do
        expect(server_passport.reload.ip).to eq '127.0.0.1'
      end

      it 'attaches the user attributes to the passport' do
        expect(passport.user).to be_instance_of Hash
        expect(passport.user['name']).to eq 'Emily'
        expect(passport.user['email']).to eq 'emily@example.com'
        expect(passport.user['tags'].sort).to eq %w(cool is_working_from_home nice).sort
      end
    end

    context 'insider passport' do
      let(:insider) { true }

      it 'succeeds' do
        expect(operation).to be_success
      end

      it 'verifies the passport' do
        expect(passport).to be_verified
      end

      it 'modifies the passport' do
        expect(passport).to be_modified
      end

      it 'tracks the untrusted client IP' do
        expect(server_passport.reload.ip).to eq ip
      end

      it 'attaches the user attributes to the passport' do
        expect(passport.user).to be_instance_of Hash
        expect(passport.user['name']).to eq 'Emily'
        expect(passport.user['email']).to eq 'emily@example.com'
        expect(passport.user['tags'].sort).to eq %w(cool is_at_the_office nice).sort
      end
    end
  end

end
