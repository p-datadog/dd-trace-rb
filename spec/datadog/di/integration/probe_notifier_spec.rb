require 'datadog/di'

RSpec.describe Datadog::DI::ProbeNotifier do
  describe 'log probe' do
    let(:probe) do
      Datadog::DI::Probe.new(id: '123', type: 'LOG_PROBE', type_name: 'X', method_name: 'y')
    end

    before do
      allow(agent_settings).to receive(:hostname)
      allow(agent_settings).to receive(:port)
      allow(agent_settings).to receive(:timeout_seconds).and_return(1)
      allow(agent_settings).to receive(:ssl)

      allow(Datadog::DI).to receive(:component).and_return(component)
    end

    let(:settings) do
      settings = Datadog::Core::Configuration::Settings.new
      settings.internal_dynamic_instrumentation.enabled = true
      settings.internal_dynamic_instrumentation.propagate_all_exceptions = true
      settings
    end

    let(:hook_manager) do
      Datadog::DI::HookManager.new(settings)
    end

    let(:defined_probes) do
      {}
    end

    let(:installed_probes) do
      {}
    end

    let(:remote_processor) do
      Datadog::DI::RemoteProcessor.new(
        settings, hook_manager, defined_probes, installed_probes)
    end

    let(:agent_settings) do
      double('agent settings')
    end

    let(:component) do
      Datadog::DI::Component.new(settings, agent_settings)
    end

    before do
      expect(Datadog::DI).to receive(:component).and_return(component)
    end

    context 'with snapshot' do
      let(:vars) do
        {hello: 42, hash: {hello: 42, password: 'redacted'}, array: [true]}
      end

      it 'notifies' do
        described_class.notify_snapshot(probe, snapshot: vars)
      end
    end
  end
end
