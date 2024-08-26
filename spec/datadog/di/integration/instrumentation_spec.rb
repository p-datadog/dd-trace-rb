require 'datadog/di'

RSpec.describe 'Instrumentation integration' do
  before(:all) do
    Datadog::DI.activate_tracking!
    require_relative 'instrumentation_integration_test_class'
  end

  after do
    component.shutdown!
  end

  let(:settings) do
    settings = Datadog::Core::Configuration::Settings.new
    settings.internal_dynamic_instrumentation.enabled = true
    settings.internal_dynamic_instrumentation.propagate_all_exceptions = true
    settings
  end

  let(:hook_manager) do
    component.hook_manager
  end

  let(:defined_probes) do
    {}
  end

  let(:installed_probes) do
    {}
  end

  let(:remote_processor) do
    component.remote_processor
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
      context 'simple log probe' do
        let(:probe_rc_spec) do
           {"id"=>"3ecfd456-2d7c-4359-a51f-d4cc44141ffe",
            "version"=>0,
            "type"=>"LOG_PROBE",
            "language"=>"ruby",
            "where"=>{"sourceFile"=>"instrumentation_integration_test_class.rb", "lines"=>['10']},
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
          expect(Datadog::DI.component.probe_notifier_worker).to receive(:add_snapshot).once.and_call_original
          expect(InstrumentationIntegrationTestClass.new.test_method).to eq(42)
        end

        it 'assembles expected notification payload' do
          remote_processor.process(probe_rc_spec)
          payload = nil
          expect(Datadog::DI.component.probe_notifier_worker).to receive(:add_snapshot) do |_payload|
            payload = _payload
          end
          expect(InstrumentationIntegrationTestClass.new.test_method).to eq(42)
          expect(payload).to be_a(Hash)
          snapshot = payload.fetch(:'debugger.snapshot')
          expect(snapshot.fetch(:captures)).to be nil
        end
      end

      context 'enriched probe' do
        let(:probe_rc_spec) do
           {"id"=>"3ecfd456-2d7c-4359-a51f-d4cc44141ffe",
            "version"=>0,
            "type"=>"LOG_PROBE",
            "language"=>"ruby",
            "where"=>{"sourceFile"=>"instrumentation_integration_test_class.rb", "lines"=>['10']},
            "tags"=>[],
            "template"=>"In aaa, line 1",
            "segments"=>[{"str"=>"In aaa, line 1"}],
            "captureSnapshot"=>true,
            "capture"=>{"maxReferenceDepth"=>3},
            "sampling"=>{"snapshotsPerSecond"=>5000},
            "evaluateAt"=>"EXIT"}
        end

        let(:expected_captures) do
          {lines: {10 => {locals: {
            a: {type: 'Integer', value: 21},
          }}}}
        end

        it 'invokes probe' do
          remote_processor.process(probe_rc_spec)
          expect(Datadog::DI.component.probe_notifier_worker).to receive(:add_snapshot).once.and_call_original
          expect(InstrumentationIntegrationTestClass.new.test_method).to eq(42)
        end

        it 'assembles expected notification payload' do
          remote_processor.process(probe_rc_spec)
          payload = nil
          expect(Datadog::DI.component.probe_notifier_worker).to receive(:add_snapshot) do |_payload|
            payload = _payload
          end
          expect(InstrumentationIntegrationTestClass.new.test_method).to eq(42)
          expect(payload).to be_a(Hash)
          captures = payload.fetch(:'debugger.snapshot').fetch(:captures)
          expect(captures).to eq(expected_captures)
        end
      end
    end
  end
end
