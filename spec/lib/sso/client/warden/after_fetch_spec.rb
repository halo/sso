require 'spec_helper'

RSpec.describe SSO::Client::Warden::AfterFetch, type: :request do

  let(:ip)           { '198.51.100.74' }
  let(:agent)        { 'IE7' }
  let(:state)        { '5eef53c9f9b2cfda98c9fd17c4ae3727ae6ad4e5' }
  let(:carol_client) { double :carol_client, id: carol_server.id, state: state, passport_id: passport.id, passport_secret: passport.secret }

  let(:carol_server) { ::SSO::Server::Users.find_by_id carol_id }



  let(:user)           { ::SSO::User.new id: server_user.id, state: state, passport_id: passport.id, passport_secret: passport.secret }
  let(:warden_env)     { { } }
  let(:warden_request) { double :warden_request, ip: ip, user_agent: agent, env: warden_env }
  let(:warden)         { double :warden, request: warden_request }
  let(:warden_options) { { } }
  let(:original_attributes) { 'overriden in before block' }
  let(:scope)          { nil }

  let(:passport)     { SSO::Server::Passports::Backend.create! owner_id: carol_server.id, group_id: SecureRandom.uuid, ip: '198.51.100.1', agent: 'Internet Explorer', application_id: 99 }
  let(:hook_options) { { scope: :admin } }
  let(:hook)         { described_class.new hook_options }

  before do

  end

  context 'no changes' do
    it 'verifies the user' do
      hook.call
      expect(user).to be_verified
    end
  end

end
