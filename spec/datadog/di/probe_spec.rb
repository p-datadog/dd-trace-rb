require 'datadog/di/probe'

RSpec.describe Datadog::DI::Probe do
  describe '.new' do
    let(:probe) do
      described_class.new(id: '42', type: 'foo')
    end

    it 'creates an instance' do
      expect(probe).to be_a(described_class)
      expect(probe.id).to eq '42'
      expect(probe.type).to eq 'foo'
    end
  end

  describe '#line?' do
    context 'line probe' do
      let(:probe) do
        described_class.new(id: '42', type: 'foo', file: 'bar.rb', line_nos: [5])
      end

      it 'is true' do
        expect(probe.line?).to be true
      end
    end

    context 'method probe' do
      let(:probe) do
        described_class.new(id: '42', type: 'foo', type_name: 'FooClass', method_name: "bar")
      end

      it 'is false' do
        expect(probe.line?).to be false
      end
    end
  end

  describe '#method?' do
    context 'line probe' do
      let(:probe) do
        described_class.new(id: '42', type: 'foo', file: 'bar.rb', line_nos: [5])
      end

      it 'is false' do
        expect(probe.method?).to be false
      end
    end

    context 'method probe' do
      let(:probe) do
        described_class.new(id: '42', type: 'foo', type_name: 'FooClass', method_name: "bar")
      end

      it 'is true' do
        expect(probe.method?).to be true
      end
    end
  end
end
