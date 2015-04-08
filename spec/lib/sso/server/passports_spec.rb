require 'spec_helper'

RSpec.describe SSO::Server::Passports do
  let(:passports) { described_class }

  before do
    Timecop.freeze
  end

  describe '.update_activity' do
    let(:env)             { { 'REMOTE_ADDR' => ip, 'rack.input' => '', 'HTTP_USER_AGENT' => 'Safari', 'QUERY_STRING' => 'agent=Chrome&ip=198.51.100.1&device_id=my_device_id' } }
    let(:ip)              { '198.51.100.99' }
    let(:request)         { Rack::Request.new env  }

    let(:another_env)     { { 'REMOTE_ADDR' => another_ip, 'rack.input' => '', 'HTTP_USER_AGENT' => 'Opera', 'QUERY_STRING' => 'agent=Firefox&ip=198.51.100.2&device_id=another_my_device_id' } }
    let(:another_ip)      { '198.51.100.100' }
    let(:another_request) { Rack::Request.new another_env  }

    let(:insider)         { false }
    let(:passport)        { create :passport, activity_at: 1.week.ago, insider: insider }

    before do
      passports.update_activity passport_id: passport.id, request: request
    end

    context 'outsider' do
      it 'creates a brand new stamp' do
        expect(passport.reload.stamps).to eq '198.51.100.99' => Time.now.to_i.to_s
      end

      it 'tracks the imediate IP' do
        expect(passport.reload.ip).to eq '198.51.100.99'
        expect(passport.reload.agent).to eq 'Safari'
        expect(passport.reload.device).to eq 'my_device_id'
      end

      it 'updates activity_at' do
        expect(passport.reload.activity_at.to_i).to eq Time.now.to_i
      end

      context 'another request' do
        before do
          Timecop.freeze 5.minutes.from_now
          passports.update_activity passport_id: passport.id, request: another_request
        end

        it 'adds another stamp' do
          expect(passport.reload.stamps).to eq '198.51.100.99' => 5.minutes.ago.to_i.to_s, '198.51.100.100' => Time.now.to_i.to_s
        end

        it 'updates activity_at' do
          expect(passport.reload.activity_at.to_i).to eq Time.now.to_i
        end

        it 'updates the imediate IP' do
          expect(passport.reload.ip).to eq '198.51.100.100'
          expect(passport.reload.agent).to eq 'Opera'
          expect(passport.reload.device).to eq 'another_my_device_id'
        end
      end
    end

    context 'insider' do
      let(:insider) { true }

      it 'creates a brand new stamp' do
        expect(passport.reload.stamps).to eq '198.51.100.1' => Time.now.to_i.to_s
      end

      it 'tracks the proxied IP' do
        expect(passport.reload.ip).to eq '198.51.100.1'
        expect(passport.reload.agent).to eq 'Chrome'
        expect(passport.reload.device).to eq 'my_device_id'
      end

      it 'updates activity_at' do
        expect(passport.reload.activity_at.to_i).to eq Time.now.to_i
      end

      context 'another request' do
        before do
          Timecop.freeze 5.minutes.from_now
          passports.update_activity passport_id: passport.id, request: another_request
        end

        it 'adds another stamp' do
          expect(passport.reload.stamps).to eq '198.51.100.1' => 5.minutes.ago.to_i.to_s, '198.51.100.2' => Time.now.to_i.to_s
        end

        it 'updates activity_at' do
          expect(passport.reload.activity_at.to_i).to eq Time.now.to_i
        end

        it 'updates the proxied IP' do
          expect(passport.reload.ip).to eq '198.51.100.2'
          expect(passport.reload.agent).to eq 'Firefox'
          expect(passport.reload.device).to eq 'another_my_device_id'
        end
      end
    end

  end

end
