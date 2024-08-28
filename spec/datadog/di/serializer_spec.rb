require 'datadog/di/serializer'

RSpec.describe Datadog::DI::Serializer do
  class SensitiveType
  end

  class WildCardClass; end

  class InstanceVariable
    def initialize(value)
      @ivar = value
    end
  end

  class RedactedInstanceVariable
    def initialize(value)
      @session = value
    end
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
      allow(settings).to receive(:redacted_type_names).and_return(%w[SensitiveType WildCard*])
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
      ['redacted wild card type', {value: WildCardClass.new},
        {value: {type: 'WildCardClass', notCapturedReason: 'redactedType'}}],
      ['empty array', {arr: []},
        {arr: {type: 'Array', entries: []}}],
      ['array of primitives', {arr: [42, 'hello', nil, true]},
        {arr: {type: 'Array', entries: [
          {type: 'Integer', value: 42},
          {type: 'String', value: 'hello'},
          {type: 'NilClass', isNull: true},
          {type: 'TrueClass', value: true},
        ]}}],
      ['array with value of redacted type', {arr: [1, SensitiveType.new]},
        {arr: {type: 'Array', entries: [
          {type: 'Integer', value: 1},
          {type: 'SensitiveType', notCapturedReason: 'redactedType'},
        ]}}],
      ['empty hash', {h: {}}, {h: {type: 'Hash', entries: []}}],
      ['hash with symbol key', {h: {hello: 42}}, {h: {type: 'Hash', entries: [
        [{type: 'Symbol', value: 'hello'}, {type: 'Integer', value: 42}],
        ]}}],
      ['hash with string key', {h: {'hello' => 42}}, {h: {type: 'Hash', entries: [
        [{type: 'String', value: 'hello'}, {type: 'Integer', value: 42}],
        ]}}],
      ['hash with redacted identifier', {h: {'session-key' => 42}}, {h: {type: 'Hash', entries: [
        [{type: 'String', value: 'session-key'}, {type: 'Integer', notCapturedReason: 'redactedIdent'}],
        ]}}],
      ['empty object', {x: Object.new}, {x: {type: 'Object', fields: {}}}],
      ['object with instance variable', {x: InstanceVariable.new(42)},
        {x: {type: 'InstanceVariable', fields: {
          :@ivar => {type: 'Integer', value: 42},
        }}}],
      ['object with redacted instance variable', {x: RedactedInstanceVariable.new(42)},
        {x: {type: 'RedactedInstanceVariable', fields: {
          :@session => {type: 'Integer', notCapturedReason: 'redactedIdent'},
        }}}],
      # TODO hash with a complex object as key?
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

    CASES = [
      ['both args and kwargs',
        [1, 'x'],
        {a: 42},
          arg1: {type: 'Integer', value: 1},
          arg2: {type: 'String', value: 'x'},
          a: {type: 'Integer', value: 42},
      ],
      ['kwargs contains redacted identifier',
        [1, 'x'],
        {password: 42},
          arg1: {type: 'Integer', value: 1},
          arg2: {type: 'String', value: 'x'},
          password: {type: 'Integer', notCapturedReason: 'redactedIdent'},
      ],
    ]

    CASES.each do |(name, args_, kwargs_, expected_)|
      args = args_
      kwargs = kwargs_
      expected = expected_

      context name do

        let(:args) { args }
        let(:kwargs) { kwargs }

        it 'serializes as expected' do
          expect(serialized).to eq(expected)
        end
      end
    end
  end
end
