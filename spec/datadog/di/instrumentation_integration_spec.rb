require 'datadog/di'

RSpec.describe 'Instrumentation integration' do
  before(:all) do
    Datadog::DI.activate_tracking!
    require_relative 'instrumentation_integration_test_class'
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

  context 'log probe' do
    before do
      allow(agent_settings).to receive(:hostname)
      allow(agent_settings).to receive(:port)
      allow(agent_settings).to receive(:timeout_seconds).and_return(1)
      allow(agent_settings).to receive(:ssl)

      allow(Datadog::DI).to receive(:component).and_return(component)
    end

    context 'line probe' do
      let(:probe_rc_spec) do
         {"id"=>"3ecfd456-2d7c-4359-a51f-d4cc44141ffe",
          "version"=>0,
          "type"=>"LOG_PROBE",
          "language"=>"ruby",
          "where"=>{"sourceFile"=>"instrumentation_integration_test_class.rb", "lines"=>['4']},
          "tags"=>[],
          "template"=>"In aaa, line 1",
          "segments"=>[{"str"=>"In aaa, line 1"}],
          "captureSnapshot"=>false,
          "capture"=>{"maxReferenceDepth"=>3},
          "sampling"=>{"snapshotsPerSecond"=>5000},
          "evaluateAt"=>"EXIT"}
      end

      it 'invokes probe' do
        remote_processor.process(probe_rc_spec)
=begin
        expect(Datadog::DI::ProbeNotifier).to receive(:notify_executed).and_call_original do |_probe, **opts|
          p _probe
          p opts[:tracepoint].binding.local_variables
        end
        expect(Datadog::DI::ProbeNotifier).to receive(:notify_snapshot).and_call_original do |_probe, **opts|
          p _probe
          p opts[:tracepoint].binding.local_variables
        end
=end
        expect(InstrumentationIntegrationTestClass.new.test_method).to eq(42)
      end
    end
  end
end
