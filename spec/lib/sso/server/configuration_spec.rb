require 'spec_helper'

RSpec.describe SSO::Configuration do

  let(:config) { described_class.new }

  describe '#human_readable_location_for_ip' do
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

  describe '#environment' do
    context 'with Rails' do
      it 'is the Rails environment' do
        expect(config.environment).to be ::Rails.env
      end
    end

    context 'without Rails' do
      before do
        hide_const 'Rails'
        stub_const 'ENV', 'RACK_ENV' => 'rackish'
      end

      it 'is the RACK_ENV' do
        expect(config.environment).to eq 'rackish'
      end

      context 'without RACK_ENV' do
        before do
          stub_const 'ENV', {}
        end

        it 'is unknown' do
          expect(config.environment).to eq 'unknown'
        end
      end
    end
  end

  context 'test environment' do

    describe '#logger' do
      context 'with Rails' do
        it 'is the Rails logger' do
          expect(config.logger).to be ::Rails.logger
        end

        it 'is on the Rails logger level' do
          expect(config.logger.level).to be ::Rails.logger.level
        end
      end

      context 'without Rails' do
        before do
          hide_const 'Rails'
        end

        it 'is a Logger' do
          expect(config.logger).to be_instance_of ::Logger
        end

        it 'is on UNKNOWN level' do
          expect(config.logger.level).to eq ::Logger::UNKNOWN
        end
      end
    end

  end

  context 'development environment' do
    before do
      config.environment = :development
    end

    describe '#logger' do
      context 'with Rails' do
        it 'is the Rails logger' do
          expect(config.logger).to be ::Rails.logger
        end

        it 'is on the Rails logger level' do
          expect(config.logger.level).to be ::Rails.logger.level
        end
      end

      context 'without Rails' do
        before do
          hide_const 'Rails'
        end

        it 'is a Logger' do
          expect(config.logger).to be_instance_of ::Logger
        end

        it 'is on DEBUG level' do
          expect(config.logger.level).to eq ::Logger::DEBUG
        end
      end
    end

  end

  context 'production environment' do
    before do
      config.environment = :production
    end

    describe '#logger' do
      context 'with Rails' do
        it 'is the Rails logger' do
          expect(config.logger).to be ::Rails.logger
        end

        it 'is on the Rails logger level' do
          expect(config.logger.level).to be ::Rails.logger.level
        end
      end

      context 'without Rails' do
        before do
          hide_const 'Rails'
        end

        it 'is a Logger' do
          expect(config.logger).to be_instance_of ::Logger
        end

        it 'is on WARN level' do
          expect(config.logger.level).to eq ::Logger::WARN
        end
      end
    end

  end

end
