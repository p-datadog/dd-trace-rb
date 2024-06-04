require 'datadog/di/component'

RSpec.describe Datadog::DI::Component do
  describe '.build' do
    let(:settings) do
      settings = Datadog::Core::Configuration::Settings.new
      settings.internal_dynamic_instrumentation.enabled = dynamic_instrumentation_enabled
      settings
    end

    context 'when dynamic instrumentation is enabled' do
      let(:dynamic_instrumentation_enabled) { true }

      it 'returns a Datadog::DI::Component instance' do
        component = described_class.build(settings)
        expect(component).to be_a(described_class)
      end
    end

    context 'when dynamic instrumentation is disabled' do
      let(:dynamic_instrumentation_enabled) { false }

      it 'returns nil' do
        component = described_class.build(settings)
        expect(component).to be nil
      end
    end
  end
end
