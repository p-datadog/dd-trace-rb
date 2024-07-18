require 'datadog/di/code_tracker'

RSpec.describe Datadog::DI::CodeTracker do
  let(:tracker) do
    described_class.new
  end

  describe '.new' do
    it 'creates an instance' do
      expect(tracker).to be_a(described_class)
    end
  end

  describe '#start' do
    after do
      tracker.stop
    end

    it 'tracks loaded files' do
      # The expectations appear to be lazy-loaded, therefore
      # we need to invoke the same expectation before starting
      # code tracking as we'll be using later in the test.
      expect(tracker.send(:registry)).to be_empty
      tracker.start
      # Should still be empty here.
      expect(tracker.send(:registry)).to be_empty
      require_relative 'code_tracker_test_class_1'
      # TODO due to a hack we currently have 2 entries for every file,
      # one with full path and one with basename only.
      expect(tracker.send(:registry).each.to_a.length).to eq(2)

      path = tracker.send(:registry).each.to_a.first.first
      # The full path is dependent on the environment/system
      # running the tests, but we can assert on the basename
      # which will be the same.
      expect(File.basename(path)).to eq('code_tracker_test_class_1.rb')
      # And, we should in fact have a full path.
      expect(path).to start_with('/')
    end
  end
end
