# frozen_string_literal: true

module Datadog
  module DI
    module Configuration
      # Settings
      module Settings

        def self.extended(base)
          base = base.singleton_class unless base.is_a?(Class)
          add_settings!(base)
        end

        # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/BlockLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        def self.add_settings!(base)
          base.class_eval do
            # The setting has "internal" prefix to prevent it from being
            # prematurely turned on by customers.
            settings :internal_dynamic_instrumentation do
              option :enabled do |o|
                o.type :bool
                # The environment variable has an "internal" prefix so that
                # any customers that have the "proper" environment variable
                # turned on (i.e. DD_DYNAMIC_INSTRUMENTATION_ENABLED)
                # do not enable Ruby DI until the latter is ready for
                # customer testing.
                o.env 'DD_INTERNAL_DYNAMIC_INSTRUMENTATION_ENABLED'
                o.default false
              end

            end
          end
        end
      end
    end
  end
end
