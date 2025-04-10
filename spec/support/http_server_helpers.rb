require 'webrick'

module HttpServerHelpers
  def http_server(port)
    let(:http_server_port) { 48485 }

    let(:server) do
      WEBrick::HTTPServer.new(
        Port: http_server_port,
      ).tap do |server|
        yield server
      end
    end

    around do |example|
      @server_thread = Thread.new do
        server.start
      end
      loop do
        break if server.status == :Running || !@server_thread.alive?
        sleep 0.5
      end
      expect(@server_thread).to be_alive
      example.run
      @server_thread.kill
      loop do
        break unless @server_thread.alive?
        sleep 0.5
      end
    end
  end
end
