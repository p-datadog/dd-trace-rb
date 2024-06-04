RSpec.describe Datadog::DI::Configuration::Settings do
  subject(:settings) { Datadog::Core::Configuration::Settings.new }

  describe 'internal_dynamic_instrumentation' do
    describe '#enabled' do
      subject(:enabled) { settings.internal_dynamic_instrumentation.enabled }

      context 'when DD_DYNAMIC_INSTRUMENTATION_ENABLED' do
        around do |example|
          ClimateControl.modify('DD_DYNAMIC_INSTRUMENTATION_ENABLED' => dynamic_instrumentation_enabled) do
            example.run
          end
        end

        context 'is not defined' do
          let(:dynamic_instrumentation_enabled) { nil }

          it { is_expected.to eq false }
        end

        # Currently we use the internal environment variable name to
        # avoid enabling DI in production for customers who have the
        # standard environment variable set to true for whatever reason.
        context 'is not defined' do
          let(:dynamic_instrumentation_enabled) { 'true' }

          it { is_expected.to eq(false) }
        end
      end

      context 'when DD_INTERNAL_DYNAMIC_INSTRUMENTATION_ENABLED' do
        around do |example|
          ClimateControl.modify('DD_INTERNAL_DYNAMIC_INSTRUMENTATION_ENABLED' => dynamic_instrumentation_enabled) do
            example.run
          end
        end

        context 'is not defined' do
          let(:dynamic_instrumentation_enabled) { nil }

          it { is_expected.to eq false }
        end

        context 'is defined' do
          let(:dynamic_instrumentation_enabled) { 'true' }

          it { is_expected.to eq(true) }
        end
      end
    end

    describe '#enabled=' do
      subject(:set_dynamic_instrumentation_enabled) { settings.internal_dynamic_instrumentation.enabled = dynamic_instrumentation_enabled }

      [true, false].each do |value|
        context "when given #{value}" do
          let(:dynamic_instrumentation_enabled) { value }

          before { set_dynamic_instrumentation_enabled }

          it { expect(settings.internal_dynamic_instrumentation.enabled).to eq(value) }
        end
      end
    end

  end
end
