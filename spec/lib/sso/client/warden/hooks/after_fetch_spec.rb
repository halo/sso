require 'spec_helper'

RSpec.describe SSO::Client::Warden::Hooks::AfterFetch, type: :request, db: true do

  # Client side
  let(:warden_env)      { {} }
  let(:client_params)   { { device_id: 'unique device identifier' } }
  let(:warden_request)  { double :warden_request, ip: ip, user_agent: agent, params: client_params, env: warden_env }
  let(:warden)          { double :warden, request: warden_request }
  let(:hook)            { described_class.new passport: client_passport, warden: warden, options: {} }
  let(:client_user)     { double :client_user, name: 'Good old client user' }
  let(:client_passport) { ::SSO::Client::Passport.new id: passport_id, secret: passport_secret, state: passport_state, user: client_user }

  # Shared
  let!(:oauth_app)      { create :outsider_doorkeeper_application }
  let(:passport_id)     { server_passport.id }
  let(:passport_state)  { server_passport.state }
  let(:passport_secret) { server_passport.secret }
  let(:ip)              { '198.51.100.74' }
  let(:agent)           { 'IE7' }

  # Server side
  let!(:server_user)     { create :user, tags: %w(wears_glasses never_gives_up) }
  let!(:server_passport) { create :passport, user: server_user, owner_id: server_user.id, ip: ip, agent: agent }

  before do
    # The server dynamically injects some tags. In order to calculate the user state correctly in our test setup,
    # We need to "simulate" what the tags will look like once the server modified them. No big problem.
    allow(server_user).to receive(:tags).and_return %w(wears_glasses is_working_from_home never_gives_up)
  end

  context 'user does not change' do
    it 'verifies the passport' do
      expect(client_passport).to_not be_verified
      hook.call
      expect(client_passport).to be_verified
    end

    it 'does not modify the passport' do
      expect(client_passport).to_not be_modified
      hook.call
      expect(client_passport).to_not be_modified
    end

    it 'does not modify the encapsulated user' do
      hook.call
      expect(client_passport.user.name).to eq 'Good old client user'
    end
  end

  context 'user attribute changed which is not included in the state digest' do
    before do
      hook
      server_user.update_attribute :name, 'Something new'
    end

    it 'verifies the passport' do
      expect(client_passport).to_not be_verified
      hook.call
      expect(client_passport).to be_verified
    end

    it 'does not modify the passport' do
      expect(client_passport).to_not be_modified
      hook.call
      expect(client_passport).to_not be_modified
    end

    it 'does not modify the encapsulated user' do
      hook.call
      expect(client_passport.user.name).to eq 'Good old client user'
    end
  end

  context 'user attribute changed which results in a new state digest' do
    before do
      hook
      server_user.update_attribute :email, 'brand-new@example.com'
    end

    it 'verifies the passport' do
      expect(client_passport).to_not be_verified
      hook.call
      expect(client_passport).to be_verified
    end

    it 'modifies the passport' do
      expect(client_passport).to_not be_modified
      hook.call
      expect(client_passport).to be_modified
    end

    it 'updates the client user to reflect the server user' do
      hook.call
      expect(client_passport.user['name']).to eq server_user.name
    end
  end

end
