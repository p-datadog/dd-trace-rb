require 'datadog/di/probe'

RSpec.describe Datadog::DI::RemoteProcessor do
  let(:hook_manager) do
    double('hook manager')
  end

  let(:defined_probes) do
    {}
  end

  let(:installed_probes) do
    {}
  end

  let(:processor) do
    described_class.new(hook_manager, defined_probes, installed_probes)
  end

  describe '.new' do
    it 'creates an instance' do
      expect(processor).to be_a(described_class)
    end
  end

  describe '#process' do
    context 'no config' do
      let(:config) do
        {}
      end

      it 'does nothing and does not raise exceptions' do
        processor.process(config)
      end
    end
  end
end
