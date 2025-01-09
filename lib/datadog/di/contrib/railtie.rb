# frozen_string_literal: true

module Datadog
  module DI
    module Contrib
      # Railtie class initializes
      class Railtie < Rails::Railtie
        initializer 'datadog.dynamic_instrumentation.initialize' do |app|
          Contrib.load_now
        end
      end
    end
  end
end
