# frozen_string_literal: true

# TODO: what is the purpose of starting/started/stopping?

module Datadog
  module Core
    module Remote
      # Worker executes a block every interval on a separate Thread
      class Worker
        def initialize(interval:, &block)
          @mutex = Mutex.new
          @thr = nil

          @starting = false
          @stopping = false
          @started = false

          @interval = interval
          raise ArgumentError, 'can not initialize a worker without a block' unless block

          @block = block
        end

        def start
        puts "** Maybe starting worker #{object_id}"
          Datadog.logger.debug { 'remote worker starting' }

          # TODO: log under the lock?
          @mutex.synchronize do
          puts "start #{object_id} #{@stopping}"
            return if @starting || @started || @stopped

            @starting = true
            puts "** really starting #{object_id}"
            #require'byebug';byebug

            thread = Thread.new { poll(@interval) }
            thread.name = self.class.name unless Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.3')
            thread.thread_variable_set(:fork_safe, true)
            @thr = thread

            @started = true
            @starting = false
          end

          Datadog.logger.debug { 'remote worker started' }
        end

        def stop
        puts "** stopping #{object_id}"
        #require'byebug';byebug
          Datadog.logger.debug { 'remote worker stopping' }

          # TODO: log under the lock?
          @mutex.synchronize do
          p "!! stop #{object_id}"
            @stopping = true

            thread = @thr

            if thread
              thread.kill
              thread.join
            end

            @started = false
            @stopping = false
            @thr = nil
            @stopped = true
          end

          Datadog.logger.debug { 'remote worker stopped' }
        end

        def started?
          @started
        end

        private

        def poll(interval)
          loop do
            break unless @mutex.synchronize { @starting || @started }

            call

            sleep(interval)
          end
        end

        def call
          Datadog.logger.debug { 'remote worker perform' }

          @block.call
        end
      end
    end
  end
end
