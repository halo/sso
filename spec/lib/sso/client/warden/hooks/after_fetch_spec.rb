require 'spec_helper'

RSpec.describe SSO::Client::Warden::Hooks::AfterFetch, type: :request, db: true do

  # Client side
  let(:warden_env)      { {} }
  let(:client_params)   { { udid: 'unique device identifier' } }
  let(:warden_request)  { double :warden_request, ip: ip, user_agent: agent, params: client_params, env: warden_env }
  let(:warden)          { double :warden, request: warden_request }
  let(:hook)            { described_class.new passport: client_passport, warden: warden, options: {} }
  let(:client_user)     { double :client_user }
  let(:client_passport) { ::SSO::Client::Passport.new id: passport_id, secret: passport_secret, state: passport_state, user: client_user }

  # Shared
  let!(:oauth_app)      { create :unscoped_doorkeeper_application }
  let(:passport_id)     { server_passport.id }
  let(:passport_state)  { server_passport.state }
  let(:passport_secret) { server_passport.secret }
  let(:ip)              { '198.51.100.74' }
  let(:agent)           { 'IE7' }

  # Server side
  let!(:server_user)     { create :user }
  let!(:server_passport) { create :passport, user: server_user, owner_id: server_user.id, ip: ip, agent: agent }

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
