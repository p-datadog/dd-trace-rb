require 'datadog/di/probe'

RSpec.describe Datadog::DI::Probe do
  context '.new' do
    let(:probe) do
      described_class.new(id: '42', type: 'foo')
    end

    it 'creates an instance' do
      expect(probe).to be_a(described_class)
      expect(probe.id).to eq '42'
      expect(probe.type).to eq 'foo'
    end
  end
end
