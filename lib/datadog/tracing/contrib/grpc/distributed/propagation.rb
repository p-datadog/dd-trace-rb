require_relative '../../distributed/propagation'
require_relative 'b3'
require_relative 'b3_single'
require_relative 'datadog'

module Datadog
  module Tracing
    module Contrib
      module GRPC
        module Distributed
          # Extracts and injects propagation data into gRPC request metadata.
          class Propagation < Contrib::Distributed::Propagation
            def initialize
              super(
                propagation_styles: {
                  Tracing::Configuration::Ext::Distributed::PROPAGATION_STYLE_B3 => B3.new,
                  Tracing::Configuration::Ext::Distributed::PROPAGATION_STYLE_B3_SINGLE_HEADER => B3Single.new,
                  Tracing::Configuration::Ext::Distributed::PROPAGATION_STYLE_DATADOG => Datadog.new,
                })
            end
          end
        end
      end
    end
  end
end
