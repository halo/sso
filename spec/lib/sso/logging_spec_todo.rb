require 'spec_helper'

RSpec.describe SSO::Logging do

  let(:logger) { ::SSO.config.logger }

  describe '.debug' do
    it 'logs a debug message' do
      #expect(logger).to receive(:debug).with('Module').and_yield :some_yielded_value
      #expect { |block| SSO.debug &block }.to yield_with_args :some_yielded_value
    end
  end

end
