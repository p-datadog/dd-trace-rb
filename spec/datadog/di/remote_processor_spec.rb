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

    context 'log probe' do
      let(:config) do
         {"id"=>"3ecfd456-2d7c-4359-a51f-d4cc44141ffe",
          "version"=>0,
          "type"=>"LOG_PROBE",
          "language"=>"python",
          "where"=>{"sourceFile"=>"aaa", "lines"=>[nil]},
          "tags"=>[],
          "template"=>"In aaa, line 1",
          "segments"=>[{"str"=>"In aaa, line 1"}],
          "captureSnapshot"=>false,
          "capture"=>{"maxReferenceDepth"=>3},
          "sampling"=>{"snapshotsPerSecond"=>5000},
          "evaluateAt"=>"EXIT"}
      end

      it 'parses the probe and adds it to the defined probe list' do
        processor.process(config)
      end
    end
  end
end
