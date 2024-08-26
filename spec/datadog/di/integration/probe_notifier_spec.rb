require 'datadog/di'

RSpec.describe Datadog::DI::ProbeNotifier do
  describe 'log probe' do

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

    context 'line probe' do
      let(:probe) do
        Datadog::DI::Probe.new(id: '123', type: 'LOG_PROBE', file: 'X', line_nos: [1])
      end

      context 'with snapshot' do
        let(:vars) do
          {hello: 42, hash: {hello: 42, password: 'redacted'}, array: [true]}
        end

        let(:captures) do
          {lines: {1 => {
            locals: {
              hello: {type: 'Integer', value: 42},
              hash: {type: 'Hash', entries: [
                [{type: 'Symbol', value: 'hello'}, {type: 'Integer', value: 42}],
                [{type: 'Symbol', value: 'password'}, {type: 'String', notCapturedReason: 'redactedIdent'}],
              ]},
              array: {type: 'Array', entries: [
                {type: 'TrueClass', value: true},
              ]},
            },
          }}}
        end

        it 'notifies' do
          payload = nil
          expect(component.probe_notifier_worker).to receive(:add_snapshot) do |payload_|
            payload = payload_
          end
          described_class.notify_snapshot(probe, snapshot: vars)
          expect(payload).to be_a(Hash)
          expect(payload.fetch(:'debugger.snapshot').fetch(:captures)).to eq(captures)
        end
      end
    end

    context 'method probe' do
      let(:probe) do
        Datadog::DI::Probe.new(id: '123', type: 'LOG_PROBE', type_name: 'X', method_name: 'y')
      end

      context 'with snapshot' do
        let(:vars) do
          {hello: 42, hash: {hello: 42, password: 'redacted'}, array: [true]}
        end

        it 'notifies' do
          pending

          payload = nil
          expect(component.probe_notifier_worker).to receive(:add_snapshot) do |payload_|
            payload = payload_
          end
          described_class.notify_snapshot(probe, snapshot: vars)
          expect(payload).to be_a(Hash)
          expect(payload.fetch(:'debugger.snapshot')).to eq({})
        end
      end
    end
  end
end
