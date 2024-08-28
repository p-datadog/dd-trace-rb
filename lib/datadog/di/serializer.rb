require_relative 'redactor'

module Datadog
  module DI
    #
    # @api private
    class Serializer
      def initialize(redactor)
        @redactor = redactor
      end

      attr_reader :redactor

      def serialize_value(name, value)
        if redactor.redact_type?(value)
          return {type: class_name(value.class), notCapturedReason: 'redactedType'}
        end

        if name && redactor.redact_identifier?(name)
          return {type: class_name(value.class), notCapturedReason: 'redactedIdent'}
        end

        serialized = {type: class_name(value.class)}
        case value
        # TODO would `nil` work here? Is operator used for comparison overridable?
        # TODO test this case
        when NilClass
          serialized.update(isNull: true)
        when Integer, Float, TrueClass, FalseClass, String
          serialized.update(value: value)
        when Symbol
          serialized.update(value: value.to_s)
        when Array
          # TODO array length limit
          entries = value.map do |elt|
            serialize_value(nil, elt)
          end
          serialized.update(entries: entries)
        when Hash
          # TODO array length limit
          entries = value.map do |k, v|
            [serialize_value(nil, k), serialize_value(k, v)]
          end
          serialized.update(entries: entries)
        else
          # TODO hash, object with fields
          # item count limit; traversal limit
          '[object]'
        end
        serialized
      end

      def serialize_args(args, kwargs)
        counter = 0
        combined = args.inject({}) do |c, value|
          counter += 1
          # Conversion to symbol is needed here to put args ahead of
          # kwargs when they are merged below.
          c[:"arg#{counter}"] = value
          c
        end.update(kwargs)
        serialize_vars(combined)
      end

      def serialize_vars(vars)
        Hash[vars.map do |k, v|
          [k, serialize_value(k, v)]
        end]
      end

      private

      def class_name(cls)
        # We could call `cls.to_s` to get the "standard" Ruby inspection of
        # the class, but it is likely that user code can override #to_s
        # and we don't want to invoke user code.
        cls.name || '[Unnamed class]'
      end
    end
  end
end
