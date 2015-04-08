require 'spec_helper'

RSpec.describe SSO::Server::Middleware::PassportDestruction, type: :request, db: true do

  let(:updated_passport) { ::SSO::Server::Passports.find(passport.id).object }

  before do
    Timecop.freeze
  end

  context 'passport exists' do
    let!(:passport) { create :passport }

    it 'succeeds' do
      delete "/oauth/sso/v1/passports/#{passport.id}"
      expect(response.status).to eq 200
    end

    it 'revokes the passport' do
      delete "/oauth/sso/v1/passports/#{passport.id}"
      expect(updated_passport.revoked_at.to_i).to eq Time.now.to_i
    end

    it 'logs out from warden' do
      Warden.on_next_request do |proxy|
        expect(proxy).to receive(:logout)
      end

      delete "/oauth/sso/v1/passports/#{passport.id}"
    end
  end

end
