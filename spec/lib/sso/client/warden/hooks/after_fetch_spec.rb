require 'spec_helper'

RSpec.describe SSO::Client::Warden::Hooks::AfterFetch, type: :request do

  # Client side
  let(:ip)              { '198.51.100.74' }
  let(:agent)           { 'IE7' }
  let(:client_user)     { double :user }
  let(:warden_env)      { { } }
  let(:warden_request)  { double :warden_request, ip: ip, user_agent: agent, env: warden_env }
  let(:warden)          { double :warden, request: warden_request }
  let(:hook)            { described_class.new passport: client_passport, warden: warden, options: {} }
  let(:client_passport) { ::SSO::Client::Passport.new id: passport_id, secret: passport_secret, state: passport_state, user: client_user }

  # Shared
  let(:passport_id)     { 123 }
  let(:passport_state)  { 'abc' }
  let(:passport_secret) { 'xyz' }

  # Server side
  let(:server_user)      { ::User.find_by_id 42 }
  let!(:server_passport) { ::SSO::Server::Passports::Passport.create! owner_id: server_user.id, group_id: SecureRandom.uuid, ip: '198.51.100.1', agent: 'Google Chrome', application_id: 99 }

  context 'no changes' do
    it 'verifies the user' do
      expect(client_user).to receive(:verified!)
      hook.call
    end
  end

end
