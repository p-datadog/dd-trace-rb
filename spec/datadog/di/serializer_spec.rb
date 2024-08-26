require 'datadog/di/serializer'

RSpec.describe Datadog::DI::Serializer do
  class SensitiveType
  end

  let(:settings) do
    double('settings').tap do |settings|
      allow(settings).to receive(:internal_dynamic_instrumentation).and_return(di_settings)
    end
  end

  let(:di_settings) do
    double('di settings').tap do |settings|
      allow(settings).to receive(:enabled).and_return(true)
      allow(settings).to receive(:propagate_all_exceptions).and_return(false)
      allow(settings).to receive(:redacted_identifiers).and_return([])
      allow(settings).to receive(:redacted_types).and_return([SensitiveType])
    end
  end

  let(:redactor) do
    #double('redactor')
    Datadog::DI::Redactor.new(settings)
  end

  let(:serializer) do
    described_class.new(redactor)
  end

  describe '#serialize_vars' do
    let(:serialized) do
      serializer.serialize_vars(vars)
    end

    CASES = [
      ['int value', {a: 42}, {a: {type: 'Integer', value: 42}}],
      ['redacted value in predefined list', {password: '123'},
        {password: {type: 'String', notCapturedReason: 'redactedIdent'}}],
      ['redacted type', {value: SensitiveType.new},
        {value: {type: 'SensitiveType', notCapturedReason: 'redactedType'}}],
      ['empty array', {arr: []},
        {arr: {type: 'Array', entries: []}}],
      ['array of primitives', {arr: [42, 'hello', nil, true]},
        {arr: {type: 'Array', entries: [
          {type: 'Integer', value: 42},
          {type: 'String', value: 'hello'},
          {type: 'NilClass', value: nil},
          {type: 'TrueClass', value: true},
        ]}}],
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

  describe '#serialize_args' do
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
