require 'webrick'

module HttpServerHelpers
  module ClassMethods
    def http_server(append: false, &block)
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
        unless append
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
        unless append
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
