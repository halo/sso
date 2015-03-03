require 'spec_helper'

RSpec.describe SSO::Doorkeeper::GrantMarker, type: :request do

  let(:grant_params)    { { client_id: alpha_id, redirect_uri: alpha_redirect_uri, response_type: :code, state: 'some_random_string' } }
  #let(:latest_grant)    { Doorkeeper::AccessGrant.last }
  #let(:latest_passport) { Passports::Backend.last }

  before do
    get_via_redirect '/oauth/authorize', grant_params
  end

  it 'works' do
    post '/sessions', username: 'alice', password: 'p4ssword'
    follow_redirect!
  end

end
