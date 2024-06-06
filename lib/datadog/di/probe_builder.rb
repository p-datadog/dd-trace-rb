module Datadog
  module DI
    # @api private
    module ProbeBuilder
      module_function def build_from_remote_config(config)
        Probe.new(
          id: config.fetch('id'),
          type: config.fetch('type'),
          file: config['where']&.[]('sourceFile'),
          # Sometimes lines are received as an array of nil
          line_nos: config['where']&.[]('lines')&.compact&.map(&:to_i),
          type_name: config['where']&.[]('typeName'),
          method_name: config['where']&.[]('methodName'),
          template: config['template'],
          capture_snapshot: !!config['captureSnapshot'],
        )
      end
    end
  end
end
