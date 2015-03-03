require 'spec_helper'

RSpec.describe SSO::Client::Warden::AfterFetch, type: :request do

  # Client side
  let(:ip)           { '198.51.100.74' }
  let(:agent)        { 'IE7' }
  let(:carol_client) { double :carol_client, id: carol_id, state: carol_server.state, passport_id: passport.id, passport_secret: passport.secret }
  let(:hook)         { described_class.new user: carol_client, warden: warden, options: warden_options }

  # Server side
  let(:carol_id)       { 42 }
  let(:state)          { 'abc' }
  let(:carol_server)   { double :carol_server, id: carol_id, state: state, passport_id: passport.id, passport_secret: passport.secret }
  let(:warden_env)     { { } }
  let(:warden_request) { double :warden_request, ip: ip, user_agent: agent, env: warden_env }
  let(:warden)         { double :warden, request: warden_request }
  let(:warden_options) { { } }
  let(:passport)       { SSO::Server::Passports::Passport.create! owner_id: carol_id, group_id: SecureRandom.uuid, ip: '198.51.100.1', agent: 'Internet Explorer', application_id: 99 }

  before do
    allow(::User).to receive(:find_by_id).and_return carol_server
  end

  context 'no changes' do
    it 'verifies the user' do
      expect(carol_client).to receive(:verified!)
      hook.call
    end
  end

end
