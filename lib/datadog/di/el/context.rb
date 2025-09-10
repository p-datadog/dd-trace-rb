# frozen_string_literal: true

module Datadog
  module DI
    module EL
      # Contains local and instance variables used when evaluating
      # expressions in DI Expression Language.
      #
      # TODO move to DI::Context
      #
      # @api private
      class Context
        def initialize(probe:, settings:, serializer:, locals:, target_self:)
          @probe = probe
          @settings = settings
          @serializer = serializer
          @locals = locals
          @target_self = target_self
        end

        attr_reader :probe
        attr_reader :settings
        attr_reader :serializer
        attr_reader :locals
        attr_reader :target_self

        def serialized_locals
          # TODO cache?
          serializer.serialize_vars(locals,
            depth: probe.max_capture_depth || settings.dynamic_instrumentation.max_capture_depth,
            attribute_count: probe.max_capture_attribute_count || settings.dynamic_instrumentation.max_capture_attribute_count,)
        end

        def fetch(var_name)
          unless locals
            # TODO return "undefined" instead?
            return nil
          end
          locals[var_name.to_sym]
        end

        def fetch_ivar(var_name)
          target_self.instance_variable_get(var_name)
        end
      end
    end
  end
end
