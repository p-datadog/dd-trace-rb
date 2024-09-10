require 'datadog/di/component'

RSpec.describe Datadog::DI::Component do
  describe '.build' do
    let(:settings) do
      settings = Datadog::Core::Configuration::Settings.new
      settings.dynamic_instrumentation.enabled = dynamic_instrumentation_enabled
      settings
    end

    let(:agent_settings) do
      double('agent settings')
    end

    context 'when dynamic instrumentation is enabled' do
      let(:dynamic_instrumentation_enabled) { true }

      before do
        allow(agent_settings).to receive(:hostname)
        allow(agent_settings).to receive(:port)
        allow(agent_settings).to receive(:timeout_seconds).and_return(1)
        allow(agent_settings).to receive(:ssl)
      end

      it 'returns a Datadog::DI::Component instance' do
        component = described_class.build(settings, agent_settings)
        expect(component).to be_a(described_class)
      end
    end

    context 'when dynamic instrumentation is disabled' do
      let(:dynamic_instrumentation_enabled) { false }

      it 'returns nil' do
        component = described_class.build(settings, agent_settings)
        expect(component).to be nil
      end
    end
  end
end
