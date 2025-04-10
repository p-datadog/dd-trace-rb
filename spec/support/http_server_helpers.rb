require 'webrick'

module HttpServerHelpers
  module ClassMethods
    def http_server(&block)
      let(:http_server_port) { http_server[:Port] }
      let(:http_server_init_signal) { Queue.new }
      let(:http_server_options) { {} }

      let(:http_server) do
        WEBrick::HTTPServer.new({
          Port: 0,
          StartCallback: -> { http_server_init_signal.push(1) }
        }.merge(http_server_options)).tap do |http_server|
          instance_exec(http_server, &block)
        end
      end

      around do |example|
        # If there are multiple http_server calls in an example
        # (for example, some are from an outer context),
        # the above let blocks would be replaced but the around hook
        # will be invoked once for each http_server call whereas the server
        # startup and shutdown only needs to be executed once per example.
        # Track whether the hook was invoked already and skip startup and
        # shutdown on the inner invocations, but still invoke the example
        # itself from each hook invocation.
        do_cleanup = false
        unless @http_server_hook_executed
          @http_server_hook_executed = true
          do_cleanup = true

          @server_thread = Thread.new do
            http_server.start
          rescue Exception
            http_server_init_signal.push(1)
            raise
          end
          http_server_init_signal.pop
          expect(@server_thread).to be_alive
        end

        example.run

        if do_cleanup
          http_server.shutdown
          @server_thread.join
        end
      end
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end
end
