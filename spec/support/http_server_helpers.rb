require 'webrick'

module HttpServerHelpers
  module ClassMethods
    def define_http_server(&block)
      let(:http_server_port) { http_server[:Port] }
      let(:http_server_init_signal) { Queue.new }
      let(:http_server_options) { {} }

      let(:http_server) do
        options = {
          Port: 0,
          StartCallback: -> { http_server_init_signal.push(1) }
        }.merge(http_server_options)
        WEBrick::HTTPServer.new(options).tap do |http_server|
          instance_exec(http_server, &block)
        end
      end
    end

    def http_server(&block)
      define_http_server(&block)

      around do |example|
        @server_thread = Thread.new do
          http_server.start
        rescue Exception
          http_server_init_signal.push(1)
          raise
        end
        http_server_init_signal.pop
        expect(@server_thread).to be_alive

        example.run

        http_server.shutdown
        @server_thread.join
      end
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end
end
