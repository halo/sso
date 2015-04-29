require 'spec_helper'

RSpec.describe ::SSO::Benchmarking do

  let(:instance) { MyTestNamespace::MyClass.new }

  before do
    stub_const 'MyTestNamespace', Module.new
    stub_const 'MyTestNamespace::MyClass', Class.new { include SSO::Benchmarking }
  end

  describe '#benchmark' do
    context 'without block' do
      it 'is nil' do
        expect(instance.benchmark).to be_nil
      end
    end

    context 'block given' do
      context 'without arguments' do
        it 'returns what was passed in' do
          duration = instance.benchmark { :something }
          expect(duration).to eq :something
        end

        it 'logs' do
          expect(instance).to receive(:debug) do |_, &block|
            expect(block.call).to eq 'Benchmark took 0ms'
          end
          instance.benchmark {}
        end

        it 'does not meter' do
          expect(::SSO.config).to_not receive(:metric)
          instance.benchmark {}
        end
      end

      context 'only with name' do
        it 'logs with the name' do
          expect(instance).to receive(:debug) do |_, &block|
            expect(block.call).to eq 'Long calculation took 0ms'
          end
          instance.benchmark(name: 'Long calculation') {}
        end

        it 'does not meter' do
          expect(instance).to_not receive(:timing)
          instance.benchmark(name: 'Long calculation') {}
        end
      end

      context 'only with metric' do
        it 'logs with the metric' do
          expect(instance).to receive(:debug).twice do |_, &block|
            next if block.call.include?('Measuring')
            expect(block.call).to eq 'blob.serialization took 0ms'
          end
          instance.benchmark(metric: 'blob.serialization') {}
        end

        it 'meters as timing with the metric as name' do
          expect(instance).to receive(:timing).with key: 'blob.serialization', value: 0
          instance.benchmark(metric: 'blob.serialization') {}
        end
      end

      context 'with name and metric' do
        it 'logs with the name' do
          expect(instance).to receive(:debug).twice do |_, &block|
            next if block.call.include?('Measuring')
            expect(block.call).to eq 'Synchronous encryption took 0ms'
          end
          instance.benchmark(name: 'Synchronous encryption', metric: 'encryption.aes') {}
        end

        it 'meters as timing with the metric as name' do
          expect(instance).to receive(:timing).with key: 'encryption.aes', value: 0
          instance.benchmark(name: 'Synchronous encryption', metric: 'encryption.aes') {}
        end
      end
    end
  end

end
