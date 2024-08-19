require 'datadog/di/probe_notifier'

RSpec.describe Datadog::DI::ProbeNotifier do
  describe '.serialize_vars' do
    let(:serialized) do
      described_class.serialize_vars(vars)
    end

    context 'int value' do
      let(:vars) do
        {a: 42}
      end

      it 'serializes as expected' do
        expect(serialized).to eq(a: {type: 'Integer', value: 42})
      end
    end
  end

  describe '.serialize_args' do
    let(:serialized) do
      described_class.serialize_args(args, kwargs)
    end

    context 'both args and kwards' do
      let(:args) do
        [1, 'x']
      end

      let(:kwargs) do
        {a: 42}
      end

      it 'serializes as expected' do
        expect(serialized).to eq(
          arg1: {type: 'Integer', value: 1},
          arg2: {type: 'String', value: 'x'},
          a: {type: 'Integer', value: 42},
        )
      end
    end
  end
end
