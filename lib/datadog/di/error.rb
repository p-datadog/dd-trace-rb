# frozen_string_literal: true

module Datadog
  module DI
    class Error < StandardError
      class AgentCommunicationError < Error
      end
    end
  end
end
