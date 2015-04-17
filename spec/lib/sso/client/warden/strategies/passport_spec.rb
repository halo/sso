require 'spec_helper'

RSpec.describe SSO::Client::Warden::Strategies::Passport do

  let(:env)      { env_with_params }
  let(:strategy) { described_class.new env }

  describe '#valid?' do
    context 'with :auth_version and :state' do
      let(:env) { env_with_params '/', auth_version: '4.2', state: 'abc' }

      it 'is true' do
        expect(strategy).to be_valid
      end
    end

    context 'blank :auth_version' do
      let(:env) { env_with_params '/', auth_version: '', state: 'abc' }

      it 'is false' do
        expect(strategy).not_to be_valid
      end
    end

    context 'blank :state' do
      let(:env) { env_with_params '/', auth_version: '5.5', state: '' }

      it 'is false' do
        expect(strategy).not_to be_valid
      end
    end

    context 'nil :auth_version' do
      let(:env) { env_with_params '/', state: 'xzy' }

      it 'is false' do
        expect(strategy).not_to be_valid
      end
    end
  end

  describe '#authenticate!' do

    context 'invalid passport' do
      it 'is a custom response' do
        expect(strategy.authenticate!).to eq :custom
      end
    end

    it 'fails' do
      expect(strategy).to receive(:custom!) do |rack_array|
        expect(rack_array.size).to eq 3
        expect(rack_array[0]).to eq 200
        expect(rack_array[1]).to eq 'Content-Type' => 'application/json'
        expect(rack_array[2]).to eq ['{"success":true,"code":"passport_verification_failed"}']
      end
      strategy.authenticate!
    end

    context 'valid passport' do
      let(:operation)      { Operations.success :some_code, object: :authentication_object }
      let(:authentication) { double :authentication, authenticate: operation }

      before do
        allow(::SSO::Client::Authentications::Passport).to receive(:new).and_return authentication
        allow(authentication).to receive(:success?).and_return true
      end

      it 'is a success response' do
        expect(strategy.authenticate!).to eq :success
      end

      it 'succeeds' do
        expect(strategy).to receive(:success!).with :authentication_object
        strategy.authenticate!
      end
    end

  end

end
