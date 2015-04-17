require 'spec_helper'

RSpec.describe SSO::Server::Warden::Hooks::BeforeLogout do

  let(:proc)     { described_class.to_proc }
  let(:calling)  { proc.call(user, warden, options) }
  let(:user)     { double :user }
  let(:request)  { double :request, params: params.stringify_keys }
  let(:params)   { { passport_id: passport.id } }
  let(:warden)   { double :warden, request: request }
  let(:options)  { double :options }
  let(:passport) { create :passport }

  before do
    Timecop.freeze
  end

  describe '.to_proc' do
    it 'is a proc' do
      expect(proc).to be_instance_of Proc
    end
  end

  describe '#call' do
    it 'accepts the three warden arguments and returns nothing' do
      expect(calling).to be_nil
    end

    it 'revokes the passport' do
      calling
      passport.reload
      expect(passport.revoked_at.to_i).to eq Time.now.to_i
      expect(passport.revoke_reason).to eq 'logout'
    end

    it 'survives an exception' do
      allow(described_class).to receive(:new).and_raise NoMethodError, 'I am a problem'
      expect(::SSO.config.logger).to receive(:error)
      expect(calling).to be_nil
    end
  end

end
