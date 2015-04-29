require 'spec_helper'

RSpec.describe SSO::Client::Warden::Hooks::AfterFetch, type: :request, db: true, stub_benchmarks: true do

  # Client side
  let(:warden_env)      { {} }
  let(:client_params)   { { device_id: 'unique device identifier' } }
  let(:warden_request)  { double :warden_request, ip: ip, user_agent: agent, params: client_params, env: warden_env }
  let(:warden)          { double :warden, request: warden_request }
  let(:hook)            { described_class.new passport: client_passport, warden: warden, options: {} }
  let(:client_user)     { double :client_user, name: 'Good old client user' }
  let(:client_passport) { ::SSO::Client::Passport.new id: passport_id, secret: passport_secret, state: passport_state, user: client_user }
  let(:operation)       { hook.call }

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
    SSO.config.oauth_client_id = SecureRandom.hex
    SSO.config.oauth_client_secret = SecureRandom.hex
  end

  context 'invalid passport' do
    let(:passport_secret) { SecureRandom.uuid }

    before do
      expect(warden).to receive :logout
    end

    it 'does not verify the passport' do
      expect(client_passport).to_not be_verified
      hook.call
      expect(client_passport).to_not be_verified
    end

    it 'does not modify the passport' do
      expect(client_passport).to_not be_modified
      hook.call
      expect(client_passport).to_not be_modified
    end

    it 'fails' do
      expect(operation).to be_failure
    end

    it 'has a useful error code' do
      expect(operation.code).to eq :invalid
    end

    it 'meters the invalid passport' do
      expect(::SSO.config.metric).to receive(:call).with type: :timing, key: 'sso.client.passport.verification.duration', value: 42_000, tags: nil, data: { caller: 'SSO::Client::PassportVerifier' }
      expect(::SSO.config.metric).to receive(:call).with type: :increment, key: 'sso.client.warden.hooks.after_fetch.invalid', value: 1, tags: { scope: nil }, data: { passport_id: client_passport.id, caller: 'SSO::Client::Warden::Hooks::AfterFetch' }
      hook.call
    end
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

    it 'succeeds' do
      expect(operation).to be_success
    end

    it 'has a useful error code' do
      expect(operation.code).to eq :valid
    end

    it 'meters the invalid passport' do
      expect(::SSO.config.metric).to receive(:call).with type: :timing, key: 'sso.client.passport.verification.duration', value: 42_000, tags: nil, data: { caller: 'SSO::Client::PassportVerifier' }
      expect(::SSO.config.metric).to receive(:call).with type: :increment, key: 'sso.client.warden.hooks.after_fetch.valid', value: 1, tags: { scope: nil }, data: { passport_id: client_passport.id, caller: 'SSO::Client::Warden::Hooks::AfterFetch' }
      hook.call
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

    it 'succeeds' do
      expect(operation).to be_success
    end

    it 'has a useful error code' do
      expect(operation.code).to eq :valid
    end

    it 'meters the invalid passport' do
      expect(::SSO.config.metric).to receive(:call).with type: :timing, key: 'sso.client.passport.verification.duration', value: 42_000, tags: nil, data: { caller: 'SSO::Client::PassportVerifier' }
      expect(::SSO.config.metric).to receive(:call).with type: :increment, key: 'sso.client.warden.hooks.after_fetch.valid', value: 1, tags: { scope: nil }, data: { passport_id: client_passport.id, caller: 'SSO::Client::Warden::Hooks::AfterFetch' }
      hook.call
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

    it 'succeeds' do
      expect(operation).to be_success
    end

    it 'has a useful error code' do
      expect(operation.code).to eq :valid_and_modified
    end

    it 'meters the invalid passport' do
      expect(::SSO.config.metric).to receive(:call).with type: :timing, key: 'sso.client.passport.verification.duration', value: 42_000, tags: nil, data: { caller: 'SSO::Client::PassportVerifier' }
      expect(::SSO.config.metric).to receive(:call).with type: :increment, key: 'sso.client.warden.hooks.after_fetch.valid_and_modified', value: 1, tags: { scope: nil }, data: { passport_id: client_passport.id, caller: 'SSO::Client::Warden::Hooks::AfterFetch' }
      hook.call
    end
  end

  context 'server request times out' do
    before do
      expect(::HTTParty).to receive(:get).and_raise ::Net::ReadTimeout
    end

    it 'fails' do
      expect(operation).to be_failure
    end

    it 'has a useful error code' do
      expect(operation.code).to eq :server_request_timed_out
    end

    it 'meters the timeout' do
      expect(::SSO.config.metric).to receive(:call).with type: :increment, key: 'sso.client.warden.hooks.after_fetch.timeout', value: 1, tags: { scope: nil }, data: { timeout_ms: '100ms', passport_id: client_passport.id, caller: 'SSO::Client::Warden::Hooks::AfterFetch' }
      hook.call
    end
  end

  context 'server unreachable' do
    before do
      expect(::HTTParty).to receive(:get).and_return double(:response, code: 302)
    end

    it 'fails' do
      expect(operation).to be_failure
    end

    it 'has a useful error code' do
      expect(operation.code).to eq :server_unreachable
    end

    it 'meters the timeout' do
      expect(::SSO.config.metric).to receive(:call).with type: :timing, key: 'sso.client.passport.verification.duration', value: 42_000, tags: nil, data: { caller: 'SSO::Client::PassportVerifier' }
      expect(::SSO.config.metric).to receive(:call).with type: :increment, key: 'sso.client.warden.hooks.after_fetch.server_unreachable', value: 1, tags: { scope: nil }, data: { passport_id: client_passport.id, caller: 'SSO::Client::Warden::Hooks::AfterFetch' }
      hook.call
    end
  end

  context 'server response not parseable' do
    let(:response) { double :response, code: 200 }

    before do
      expect(::HTTParty).to receive(:get).and_return response
      allow(response).to receive(:parsed_response).and_raise ::JSON::ParserError
    end

    it 'fails' do
      expect(operation).to be_failure
    end

    it 'has a useful error code' do
      expect(operation.code).to eq :server_response_not_parseable
    end

    it 'meters the timeout' do
      expect(::SSO.config.metric).to receive(:call).with type: :timing, key: 'sso.client.passport.verification.duration', value: 42_000, tags: nil, data: { caller: 'SSO::Client::PassportVerifier' }
      expect(::SSO.config.metric).to receive(:call).with type: :increment, key: 'sso.client.warden.hooks.after_fetch.server_response_not_parseable', value: 1, tags: { scope: nil }, data: { passport_id: client_passport.id, caller: 'SSO::Client::Warden::Hooks::AfterFetch' }
      hook.call
    end
  end

  context 'server response has no success flag at all' do
    let(:response) { double :response, code: 200, parsed_response: { some: :thing } }

    before do
      expect(::HTTParty).to receive(:get).and_return response
    end

    it 'fails' do
      expect(operation).to be_failure
    end

    it 'has a useful error code' do
      expect(operation.code).to eq :server_response_missing_success_flag
    end

    it 'meters the timeout' do
      expect(::SSO.config.metric).to receive(:call).with type: :timing, key: 'sso.client.passport.verification.duration', value: 42_000, tags: nil, data: { caller: 'SSO::Client::PassportVerifier' }
      expect(::SSO.config.metric).to receive(:call).with type: :increment, key: 'sso.client.warden.hooks.after_fetch.server_response_missing_success_flag', value: 1, tags: { scope: nil }, data: { passport_id: client_passport.id, caller: 'SSO::Client::Warden::Hooks::AfterFetch' }
      hook.call
    end
  end

  context 'server behaves weirdly' do
    let(:response) { double :response, code: 200, parsed_response: { success: true } }

    before do
      expect(::HTTParty).to receive(:get).and_return response
    end

    it 'fails' do
      expect(operation).to be_failure
    end

    it 'has a useful error code' do
      expect(operation.code).to eq :unexpected_server_response_status
    end

    it 'meters the timeout' do
      expect(::SSO.config.metric).to receive(:call).with type: :timing, key: 'sso.client.passport.verification.duration', value: 42_000, tags: nil, data: { caller: 'SSO::Client::PassportVerifier' }
      expect(::SSO.config.metric).to receive(:call).with type: :increment, key: 'sso.client.warden.hooks.after_fetch.unexpected_server_response_status', value: 1, tags: { scope: nil }, data: { passport_id: client_passport.id, caller: 'SSO::Client::Warden::Hooks::AfterFetch' }
      hook.call
    end
  end

  context 'client-side exception' do
    before do
      expect(::HTTParty).to receive(:get).and_raise ArgumentError
    end

    it 'fails' do
      expect(operation).to be_failure
    end

    it 'has a useful error code' do
      expect(operation.code).to eq :client_exception_caught
    end
  end

  describe '.activate' do

    it 'proxies the options to warden' do
      expect(::Warden::Manager).to receive(:after_fetch).with(scope: :insider).and_yield :passport, :warden, :options
      described_class.activate scope: :insider
    end
  end

end
