require "datadog/di/spec_helper"
require 'datadog/di'
require 'datadog/di/probe_file_loader'
require 'spec_helper'

RSpec.describe Datadog::DI::ProbeFileLoader do
  di_test

  let(:loader) { described_class }

  context 'valid file' do
    with_env DD_DYNAMIC_INSTRUMENTATION_ENABLED: 'true',
      DD_REMOTE_CONFIGURATION_ENABLED: 'true',
      DD_DYNAMIC_INSTRUMENTATION_PROBE_FILE: File.join(File.dirname(__FILE__), 'probe_files', 'one.json')

    before do
      expect(Datadog::Core::Environment::Execution).to receive(:development?).and_return(false).at_least(:once)
    end

    around do |example|
      Datadog.configuration.reset!
      example.run
      Datadog.configuration.reset!
    end

    it 'parses and adds probes' do
      described_class.load_now
    end
  end
end
