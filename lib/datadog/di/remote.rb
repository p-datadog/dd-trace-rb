module Datadog
  module Debugging
    module Remote
      class ReadError < StandardError; end

      INSTALLED_PROBES = Concurrent::Map.new

      class << self
        PRODUCT = 'LIVE_DEBUGGING'

        def products
          [PRODUCT]
        end

        def capabilities
          []
        end

        def process_config(config, content)
          # config is one probe info
          component = Datadog.send(:components).debugging

          puts '--- got probe:'
          pp config

          probe = Probe.from_remote_config(config)
          ProbeNotifier.notify_received(probe)

          if probe.line?
            Hook.hook_line(probe.file, probe.line_nos.first) do |tp|
              puts '*** line probe executed ***'
              ProbeNotifier.notify_emitting(probe)
              ProbeNotifier.notify_executed(probe, tracepoint: tp)
            end

            INSTALLED_PROBES[probe.id] = probe
          elsif probe.method?
            Hook.hook_method(probe.type_name, probe.method_name) do |**opts|
              puts "*** method probe executed: #{opts} ***"
              #byebug
              ProbeNotifier.notify_emitting(probe)
              ProbeNotifier.notify_executed(probe, **opts)
            end
          else
            puts "Not a line or method probe"
          end

          ProbeNotifier.notify_installed(probe)

          component.add_probe_from_remote(config)

          content.applied

#          Datadog.send(:components).telemetry.client_configuration_change!(env_vars)
        rescue => e
        raise
          content.errored("#{e.class.name} #{e.message}: #{Array(e.backtrace).join("\n")}")
        end

        def receivers
          receiver do |repository, _changes|
            # DEV: Filter our by product. Given it will be very common
            # DEV: we can filter this out before we receive the data in this method.
            # DEV: Apply this refactor to AppSec as well if implemented.
            repository.contents.map do |content|
              case content.path.product
              when PRODUCT
                config = parse_content(content)
                process_config(config, content)
              end
            end
          end
        end

        def receiver(products = [PRODUCT], &block)
          matcher = Core::Remote::Dispatcher::Matcher::Product.new(products)
          [Core::Remote::Dispatcher::Receiver.new(matcher, &block)]
        end

        private

        def parse_content(content)
          data = content.data.read

          content.data.rewind

          raise ReadError, 'EOF reached' if data.nil?

          JSON.parse(data)
        end
      end
    end
  end
end
