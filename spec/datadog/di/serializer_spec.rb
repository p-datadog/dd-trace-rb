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
      allow(settings).to receive(:max_capture_collection_size).and_return(10)
    end
  end

  let(:redactor) do
    #double('redactor')
    Datadog::DI::Redactor.new(settings)
  end

  let(:serializer) do
    described_class.new(settings, redactor)
  end

  describe '#serialize_vars' do
    let(:serialized) do
      serializer.serialize_vars(vars)
    end

    def self.define_cases(cases)
      cases.each do |(name, value_, expected_)|
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

    CASES = [
      ['int value', {a: 42}, {a: {type: 'Integer', value: 42}}],
      ['redacted value in predefined list', {password: '123'},
        {password: {type: 'String', notCapturedReason: 'redactedIdent'}}],
      ['redacted type', {value: SensitiveType.new},
        {value: {type: 'SensitiveType', notCapturedReason: 'redactedType'}}],
      ['redacted wild card type', {value: WildCardClass.new},
        {value: {type: 'WildCardClass', notCapturedReason: 'redactedType'}}],
      ['empty array', {arr: []},
        {arr: {type: 'Array', elements: []}}],
      ['array of primitives', {arr: [42, 'hello', nil, true]},
        {arr: {type: 'Array', elements: [
          {type: 'Integer', value: 42},
          {type: 'String', value: 'hello'},
          {type: 'NilClass', isNull: true},
          {type: 'TrueClass', value: true},
        ]}}],
      ['array with value of redacted type', {arr: [1, SensitiveType.new]},
        {arr: {type: 'Array', elements: [
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

    define_cases(CASES)

    context 'when data exceeds limits' do
      before do
        allow(di_settings).to receive(:max_capture_collection_size).and_return(3)
      end

      LIMITED_CASES = [
        ['array too long', {a: [10] * 1000}, {a: {type: 'Array',
          elements: [
            {type: 'Integer', value: 10},
            {type: 'Integer', value: 10},
            {type: 'Integer', value: 10},
          ], notCapturedReason: 'collectionSize', size: 1000}}],
        ['hash too long', {v: {a: 1, b: 2, c: 3, d: 4, e: 5}}, {v: {type: 'Hash',
          entries: [
            [{type: 'Symbol', value: 'a'}, {type: 'Integer', value: 1}],
            [{type: 'Symbol', value: 'b'}, {type: 'Integer', value: 2}],
            [{type: 'Symbol', value: 'c'}, {type: 'Integer', value: 3}],
          ], notCapturedReason: 'collectionSize', size: 5}}],
      ]

      define_cases(LIMITED_CASES)
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
