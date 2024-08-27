require 'datadog/di/probe'

RSpec.describe Datadog::DI::RemoteProcessor do
  let(:settings) do
    double('settings').tap do |settings|
      allow(settings).to receive(:internal_dynamic_instrumentation).and_return(di_settings)
    end
  end

  let(:di_settings) do
    double('di settings').tap do |settings|
      allow(settings).to receive(:enabled).and_return(true)
      allow(settings).to receive(:propagate_all_exceptions).and_return(false)
    end
  end

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
    described_class.new(settings, hook_manager, defined_probes, installed_probes)
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

    context 'log probe' do
      let(:config) do
         {"id"=>"3ecfd456-2d7c-4359-a51f-d4cc44141ffe",
          "version"=>0,
          "type"=>"LOG_PROBE",
          "language"=>"ruby",
          "where"=>{"sourceFile"=>"aaa", "lines"=>[2]},
          "tags"=>[],
          "template"=>"In aaa, line 1",
          "segments"=>[{"str"=>"In aaa, line 1"}],
          "captureSnapshot"=>false,
          "capture"=>{"maxReferenceDepth"=>3},
          "sampling"=>{"snapshotsPerSecond"=>5000},
          "evaluateAt"=>"EXIT"}
      end

      it 'parses the probe and adds it to the defined probe list' do
        expect(hook_manager).to receive(:hook_line).with('aaa', 2, rate_limiter: nil)

        processor.process(config)

        expect(defined_probes.length).to eq 1
        expect(defined_probes["3ecfd456-2d7c-4359-a51f-d4cc44141ffe"]).to be_a(Datadog::DI::Probe)
      end

      context 'lines is array of nil' do
        let(:config) do
           {"id"=>"3ecfd456-2d7c-4359-a51f-d4cc44141ffe",
            "version"=>0,
            "type"=>"LOG_PROBE",
            "language"=>"ruby",
            "where"=>{"sourceFile"=>"aaa", "lines"=>[nil]},
            "tags"=>[],
            "template"=>"In aaa, line 1",
            "segments"=>[{"str"=>"In aaa, line 1"}],
            "captureSnapshot"=>false,
            "capture"=>{"maxReferenceDepth"=>3},
            "sampling"=>{"snapshotsPerSecond"=>5000},
            "evaluateAt"=>"EXIT"}
        end

        it 'fails to parse the probe and does not add it to the defined probe list' do
          expect(hook_manager).not_to receive(:hook_line)

          processor.process(config)

          expect(defined_probes.length).to eq 0
        end
      end
    end
  end
end
