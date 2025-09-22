# frozen_string_literal: true

module Datadog
  module DI
    module EL
      # Represents an Expression Language expression.
      #
      # @api private
      class Expression
        def initialize(compiled_expr)
          unless Proc === compiled_expr
            raise ArgumentError, "compiled_expr must be a Proc: #{compiled_expr}"
          end

          #puts RubyVM::InstructionSequence.disasm(compiled_expr)

          cls = Class.new(Evaluator)
          cls.class_exec do
            define_method(:evaluate) do |context|
              instance_variable_set('@context', context)
              instance_exec(&compiled_expr)
            end
          end
          @evaluator = cls.new
        end

        attr_reader :evaluator

        def evaluate(context)
          @evaluator.evaluate(context)
        end

        def satisfied?(context)
          !!evaluate(context)
        end
      end
    end
  end
end
