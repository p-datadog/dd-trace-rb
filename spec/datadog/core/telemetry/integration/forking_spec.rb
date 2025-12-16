# frozen_string_literal: true

require 'spec_helper'

require 'datadog/core/telemetry/component'

RSpec.describe 'Telemetry full integration tests' do
  skip_unless_integration_testing_enabled

  context 'when parent forks' do
    it 'exits' do
      Datadog.configure do |c|
        c.telemetry.enabled = true
      end

      pid = fork do
      Thread.new do
Datadog.shutdown!
end
        p 1
        sleep 1
      end

      Process.wait(pid)
    end
  end
end
