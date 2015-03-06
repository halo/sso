require 'spec_helper'

RSpec.describe SSO::Client::Warden::Hooks::AfterFetch, type: :request do

  # Client side
  let(:ip)              { '198.51.100.74' }
  let(:agent)           { 'IE7' }
  let(:warden_env)      { { } }
  let(:warden_request)  { double :warden_request, ip: ip, user_agent: agent, env: warden_env }
  let(:warden)          { double :warden, request: warden_request }
  let(:hook)            { described_class.new passport: client_passport, warden: warden, options: {} }
  let(:client_user)     { double :client_user }
  let(:client_passport) { ::SSO::Client::Passport.new id: passport_id, secret: passport_secret, state: passport_state, user: client_user }

  # Shared
  let!(:oauth_client)   { create :unscoped_doorkeeper_application }
  let(:passport_id)     { server_passport.id }
  let(:passport_state)  { server_passport.state }
  let(:passport_secret) { server_passport.secret }

  # Server side
  let!(:server_user)     { create :user }
  let!(:server_passport) { ::SSO::Server::Passport.create! user: server_user, owner_id: server_user.id, group_id: SecureRandom.uuid, ip: '198.51.100.1', agent: 'Google Chrome', application_id: oauth_client.id }

  context 'no changes' do
    it 'verifies the passport' do
      expect(client_passport).to receive(:verified!)
      hook.call
    end
  end

  context 'a user attribute changed which is not included in the state digest' do
    before do
      server_user.update_attribute :name, 'Something new'
    end

    it 'verifies the passport' do
      expect(client_passport).to receive(:verified!)
      hook.call
    end
  end

end
