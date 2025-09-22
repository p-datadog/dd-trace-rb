# frozen_string_literal: true

module Datadog
  module DI
    module EL
      # DI Expression Language compiler.
      #
      # Converts AST in probe definitions into Expression objects.
      #
      # WARNING: this class produces strings that are then eval'd as
      # Ruby code. Input ASTs are user-controlled. As such the compiler
      # must sanitize and escape all input to avoid injection.
      #
      # Besides quotes and backslashes we must also escape # which is
      # starting string interpolation (#{...}).
      #
      # @api private
      class Compiler
        def compile(ast)
          Expression.new(compile_partial(ast))
        end

        private

        OPERATORS = {
          'eq' => '==',
          'ne' => '!=',
          'ge' => '>=',
          'gt' => '>',
          'le' => '<=',
          'lt' => '<',
        }.freeze

        SINGLE_ARG_METHODS = %w[
          len isEmpty isUndefined
        ].freeze

        TWO_ARG_METHODS = %w[
          startsWith endsWith contains matches
          getmember index instanceof
        ].freeze

        MULTI_ARG_METHODS = {
          'and' => '&&',
          'or' => '||',
        }.freeze

        def compile_partial(ast)
          case ast
          when Hash
            if ast.length != 1
              raise DI::Error::InvalidExpression, "Expected hash of length 1: #{ast}"
            end
            op, target = ast.first
            case op
            when 'ref'
              unless String === target
                raise DI::Error::InvalidExpression, "Bad ref value type: #{target.class}: #{target}"
              end
              case target
              when '@it'
                lambda do
                  @stack.last.first
                end
              when '@key'
                lambda do
                  @stack.last[1]
                end
              when '@value'
                lambda do
                  @stack.last[2]
                end
              when '@return'
                # TODO implement
                raise NotImplementedError
              when '@duration'
                # TODO implement
                raise NotImplementedError
              when '@exception'
                # TODO implement
                raise NotImplementedError
              else
                # Ruby technically allows all kinds of symbols in variable
                # names, for example spaces and many characters.
                # Start out with strict validation to avoid possible
                # surprises and need to escape.
                unless target =~ %r{\A(@?)([a-zA-Z0-9_]+)\z}
                  raise DI::Error::BadVariableName, "Bad variable name: #{target}"
                end
                if $1 == '@'
                  lambda do
                    iref(target)
                  end
                else
                  lambda do
                    ref(target)
                  end
                end
              end
            when *SINGLE_ARG_METHODS
              method_name = op.gsub(/[A-Z]/) { |m| "_#{m.downcase}" }
              inner = compile_partial(target)
              target_name = var_name_maybe(target)
              lambda do
                send(method_name, instance_exec(&inner), target_name)
              end
            when *TWO_ARG_METHODS
              unless Array === target && target.length == 2
                raise DI::Error::InvalidExpression, "Improper #{op} syntax"
              end
              method_name = op.gsub(/[A-Z]/) { |m| "_#{m.downcase}" }
              inner_first = compile_partial(target[0])
              inner_second = compile_partial(target[1])
              lambda do
                send(method_name, instance_exec(&inner_first), instance_exec(&inner_second))
              end
            when *MULTI_ARG_METHODS.keys
              unless Array === target && target.length >= 1
                raise DI::Error::InvalidExpression, "Improper #{op} syntax"
              end
              inners = target.map do |item|
                compile_partial(item)
              end
              compiled_op = MULTI_ARG_METHODS[op]
              if compiled_op == '||'
                lambda do
                  inners.inject(false) do |current, block|
                    current || instance_exec(&block)
                  end
                end
              else
                lambda do
                  inners.inject(true) do |current, block|
                    current && instance_exec(&block)
                  end
                end
              end
            when 'substring'
              unless Array === target && target.length == 3
                raise DI::Error::InvalidExpression, "Improper #{op} syntax"
              end
              inners = target.map do |item|
                compile_partial(item)
              end
              lambda do
                substring(
                  instance_exec(&inners[0]),
                  instance_exec(&inners[1]),
                  instance_exec(&inners[2]),
                )
              end
            when 'not'
              inner = compile_partial(target)
              lambda do
                !instance_exec(&inner)
              end
            when *OPERATORS.keys
              unless Array === target && target.length == 2
                raise DI::Error::InvalidExpression, "Improper #{op} syntax"
              end
              operator = OPERATORS.fetch(op)
              inner_first = compile_partial(target[0])
              inner_second = compile_partial(target[1])
              lambda do
                instance_exec(&inner_first).send(operator, instance_exec(&inner_second))
              end
            when 'any', 'all', 'filter'
              unless Array === target && target.length == 2
                raise DI::Error::InvalidExpression, "Improper #{op} syntax"
              end
              inner_arg = compile_partial(target[0])
              inner_block = compile_partial(target[1])
              lambda do
                send(op, instance_exec(&inner_arg), &inner_block)
              end
            else
              raise DI::Error::InvalidExpression, "Unknown operation: #{op}"
            end
          when Numeric, true, false, nil, String
            # No escaping is needed for the values here.
            lambda do
              ast
            end
          when Array
            # Arrays are commonly used as arguments of operators/methods,
            # but there are no arrays at the top level in the syntax that
            # we currently understand. Provide a helpful error message in case
            # syntax is expanded in the future.
            raise DI::Error::InvalidExpression, "Array is not valid at its location, do you need to upgrade dd-trace-rb? #{ast}"
          else
            raise DI::Error::InvalidExpression, "Unknown type in AST: #{ast}"
          end
        end

        # Returns a textual description of +target+ for use in exception
        # messages. +target+ could be any expression language expression.
        # WARNING: the result of this method is included in eval'd code,
        # it must be sanitized to avoid injection.
        def var_name_maybe(target)
          if Hash === target && target.length == 1 && target.keys.first == 'ref' &&
              String === (value = target.values.first)
            escape(value)
          else
            '(expression)'
          end
        end

        def escape(needle)
          needle.gsub("\\") { "\\\\" }.gsub('"') { "\\\"" }.gsub('#') { "\\#" }
        end
      end
    end
  end
end
