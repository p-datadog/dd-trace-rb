require_relative 'redactor'

module Datadog
  module DI
    #
    # @api private
    class Serializer
      def initialize(settings, redactor)
        @settings = settings
        @redactor = redactor
      end

      attr_reader :settings
      attr_reader :redactor

      def serialize_value(name, value, depth: settings.dynamic_instrumentation.max_capture_depth)
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
          if depth < 0
            serialized.update(notCapturedReason: 'depth')
          else
            max = settings.dynamic_instrumentation.max_capture_collection_size
            if max != 0 && value.length > max
              serialized.update(notCapturedReason: 'collectionSize', size: value.length)
              value = value[0...max]
            end
            entries = value.map do |elt|
              serialize_value(nil, elt, depth: depth - 1)
            end
            serialized.update(elements: entries)
          end
        when Hash
          if depth < 0
            serialized.update(notCapturedReason: 'depth')
          else
            max = settings.dynamic_instrumentation.max_capture_collection_size
            cur = 0
            entries = []
            value.each do |k, v|
              if max != 0 && cur >= max
                serialized.update(notCapturedReason: 'collectionSize', size: value.length)
                break
              end
              cur += 1
              entries << [serialize_value(nil, k, depth: depth - 1), serialize_value(k, v, depth: depth - 1)]
            end
            serialized.update(entries: entries)
          end
        else
          if depth < 0
            serialized.update(notCapturedReason: 'depth')
          else
            fields = {}
            max = settings.dynamic_instrumentation.max_capture_attribute_count
            cur = 0
            value.instance_variables.each do |ivar|
              if cur >= max
                serialized.update(notCapturedReason: 'fieldCount', fields: fields)
                break
              end
              cur += 1
              # TODO @ prefix for instance variable serialization conflicts with expression language
              fields[ivar] = serialize_value(ivar, value.instance_variable_get(ivar), depth: depth - 1)
            end
            serialized.update(fields: fields)
          end
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
