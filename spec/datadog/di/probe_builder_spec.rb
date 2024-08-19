require 'datadog/di/probe'

RSpec.describe Datadog::DI::ProbeBuilder do
  describe '.build_from_remote_config' do
    let(:probe) do
      described_class.build_from_remote_config(rc_probe_spec)
    end

    context 'typical line probe' do
      let(:rc_probe_spec) do
       {"id"=>"3ecfd456-2d7c-4359-a51f-d4cc44141ffe",
        "version"=>0,
        "type"=>"LOG_PROBE",
        "language"=>"python",
        "where"=>{"sourceFile"=>"aaa.rb", "lines"=>[4321]},
        "tags"=>[],
        "template"=>"In aaa, line 1",
        "segments"=>[{"str"=>"In aaa, line 1"}],
        "captureSnapshot"=>false,
        "capture"=>{"maxReferenceDepth"=>3},
        "sampling"=>{"snapshotsPerSecond"=>5000},
        "evaluateAt"=>"EXIT"}
      end

      it 'creates line probe with corresponding values' do
        expect(probe.id).to eq "3ecfd456-2d7c-4359-a51f-d4cc44141ffe"
        expect(probe.type).to eq 'LOG_PROBE'
        expect(probe.file).to eq 'aaa.rb'
        expect(probe.line_nos).to eq [4321]
        expect(probe.type_name).to be nil
        expect(probe.method_name).to be nil

        expect(probe.line?).to be true
        expect(probe.method?).to be false
      end
    end

    context 'when lines is an array of nil' do
      let(:rc_probe_spec) do
       {"id"=>"3ecfd456-2d7c-4359-a51f-d4cc44141ffe",
        "version"=>0,
        "type"=>"LOG_PROBE",
        "language"=>"python",
        "where"=>{"sourceFile"=>"aaa.rb", "lines"=>[nil]},
        "tags"=>[],
        "template"=>"In aaa, line 1",
        "segments"=>[{"str"=>"In aaa, line 1"}],
        "captureSnapshot"=>false,
        "capture"=>{"maxReferenceDepth"=>3},
        "sampling"=>{"snapshotsPerSecond"=>5000},
        "evaluateAt"=>"EXIT"}
      end

      describe '#file' do
        it 'is the specified file' do
          expect(probe.file).to eq 'aaa.rb'
        end
      end

      describe '#line_nos' do
        it 'is an empty list' do
          expect(probe.line_nos).to eq []
        end
      end
    end

    context 'RC payload with capture snapshot' do
      let(:rc_probe_spec) do
         {"id"=>"3ecfd456-2d7c-4359-a51f-d4cc44141ffe",
          "version"=>0,
          "type"=>"LOG_PROBE",
          "language"=>"python",
          "where"=>{"sourceFile"=>"aaa", "lines"=>[nil]},
          "tags"=>[],
          "template"=>"In aaa, line 1",
          "segments"=>[{"str"=>"In aaa, line 1"}],
          "captureSnapshot"=>true,
          "capture"=>{"maxReferenceDepth"=>3},
          "sampling"=>{"snapshotsPerSecond"=>5000},
          "evaluateAt"=>"EXIT"}
      end

      it 'capture_snapshot? is true' do
        expect(probe.capture_snapshot?).to be true
      end
    end

    context 'RC payload without capture snapshot' do
      let(:rc_probe_spec) do
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

      it 'capture_snapshot? is false' do
        expect(probe.capture_snapshot?).to be false
      end
    end
  end
end
