require 'spec_helper'

RSpec.describe SSO::Logging do

  let(:instance) { MyTestNamespace::MyClass.new }
  let(:logger)   { ::Logger.new '/dev/null' }

  before do
    ::SSO.config.logger = logger
    stub_const 'MyTestNamespace', Module.new
    stub_const 'MyTestNamespace::MyClass', Class.new {  include SSO::Logging }
  end

  describe '#logger' do
    it 'is a logger' do
      expect(instance.logger).to be_instance_of ::Logger
    end
  end

  describe '#debug' do
    it 'delegates to the logger' do
      expect(logger).to receive(:debug).with('MyTestNamespace::MyClass') do |_, &block|
        expect(block.call).to eq 'Say what?'
      end
      instance.debug { 'Say what?' }
    end
  end

  context 'logger missing' do
    let(:logger) { }

    describe '#debug' do
      it 'does not break' do
        instance.debug { 'Should I freak out now?' }
      end
    end
  end

end
