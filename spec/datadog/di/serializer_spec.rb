require 'datadog/di/serializer'

RSpec.describe Datadog::DI::Serializer do
  let(:redactor) do
    double('redactor')
  end

  let(:serializer) do
    described_class.new(redactor)
  end

  describe '.serialize_vars' do
    let(:serialized) do
      serializer.serialize_vars(vars)
    end

    CASES = [
      ['int value', {a: 42}, {a: {type: 'Integer', value: 42}}],
      ['redacted value in predefined list', {password: '123'},
        {password: {type: 'String', notCapturedReason: 'redactedIdent'}}],
    ]

    CASES.each do |(name, value_, expected_)|
      value = value_
      expected = expected_

      context name do

        let(:vars) { value }

        it 'serializes as expected' do
          expect(serialized).to eq(expected)
        end
      end
    end
  end

  describe '.serialize_args' do
    let(:serialized) do
      serializer.serialize_args(args, kwargs)
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
