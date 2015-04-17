require 'spec_helper'

RSpec.describe SSO::Configuration do

  let(:config) { described_class.new }

  describe '.human_readable_location_for_ip' do
    let(:lookup) { SSO.config.human_readable_location_for_ip }

    context 'default' do
      it 'is a proc' do
        expect(lookup).to be_instance_of Proc
      end

      it 'is a String' do
        expect(lookup.call('198.51.100.88')).to eq 'Unknown'
      end
    end

    context 'customized' do
      before do
        SSO.config.human_readable_location_for_ip = proc { |ip| "Location of #{ip}" }
      end

      it 'is a custom String' do
        expect(lookup.call('198.51.100.89')).to eq 'Location of 198.51.100.89'
      end
    end
  end

end
