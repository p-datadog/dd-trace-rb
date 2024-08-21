module Datadog
  module DI
    #
    # @api private
    class Serializer
      def initialize(redactor)
        @redactor = redactor
      end

      attr_reader :redactor

      def serialize_value(value)
        {type: class_name(value.class), value: value}
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
          [k, serialize_value(v)]
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
