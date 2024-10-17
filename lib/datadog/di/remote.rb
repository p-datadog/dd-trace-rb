# frozen_string_literal: true

module Datadog
  module DI
    # Provides an interface expected by the core Remote subsystem to
    # receive DI-specific remote configuration.
    #
    # In order to apply (i.e., act on) the configuration, we need the
    # state stored under DI Component. Thus, this module forwards actual
    # configuration application to the ProbeManager associated with the
    # global DI Component.
    #
    # @api private
    module Remote
      class ReadError < StandardError; end

      class << self
        PRODUCT = 'LIVE_DEBUGGING'

        def products
          [PRODUCT]
        end

        def capabilities
          []
        end

        def receivers(telemetry)
          receiver do |repository, _changes|
            # DEV: Filter our by product. Given it will be very common
            # DEV: we can filter this out before we receive the data in this method.
            # DEV: Apply this refactor to AppSec as well if implemented.

            component = DI.component
            # TODO when would this happen? Do we request DI RC when DI is not on?
            # Or we always get RC even if DI is not turned on?
            # -- in dev. env when component is not built but config is still requested?
            # TODO log something?
            if component

              probe_manager = component.probe_manager

              current_probe_ids = {}
              repository.contents.each do |content|
                case content.path.product
                when PRODUCT
                  probe_spec = parse_content(content)
                  probe = ProbeBuilder.build_from_remote_config(probe_spec)
                  payload = component.probe_notification_builder.build_received(probe)
                  component.probe_notifier_worker.add_status(payload)
                  puts "Received probe from RC: #{probe.type} #{probe.location}"

                  begin
                    # TODO test exception capture
                    probe_manager.add_probe(probe)
                    content.applied
                  rescue => e
                    raise if component.settings.dynamic_instrumentation.propagate_all_exceptions

                    # TODO log?
                    puts "#{e.class}: #{e}"

                    content.errored("Error applying dynamic instrumentation configuration: #{e.class.name} #{e.message}: #{Array(e.backtrace).join("\n")}")
                  end

                  # Important: even if processing fails for this probe config,
                  # we need to note it as being current so that we do not
                  # try to remove instrumentation that is still supposed to be
                  # active.
                  current_probe_ids[probe_spec.fetch('id')] = true
                end
              end

              begin
                # TODO test exception capture
                probe_manager.remove_other_probes(current_probe_ids.keys)
              rescue => e
                raise if component.settings.dynamic_instrumentation.propagate_all_exceptions

                # TODO log?
                puts "#{e.class}: #{e}"
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
