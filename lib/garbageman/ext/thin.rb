module Thin
  module Backends
    class Base
      @@num_connections = 0
      def self.num_connections; @@num_connections; end
      @@server_index = nil
      def self.server_index; @@server_index; end
      def self.server_index=(index); @@server_index = index; end

      def connection_finished_with_count(connection)
        connection_finished_without_count(connection).tap { @@num_connections -= 1 }
      end
      alias connection_finished_without_count connection_finished
      alias connection_finished connection_finished_with_count

      protected

      def initialize_connection_with_count(connection)
        initialize_connection_without_count(connection).tap { @@num_connections += 1 }
      end
      alias initialize_connection_without_count initialize_connection
      alias initialize_connection initialize_connection_with_count
    end

    class TcpServer
      def connect_with_callbacks
        Thin::Server.run_before_startup_callbacks
        connect_without_callbacks.tap do
          Thin::Server.run_after_startup_callbacks
        end
      end
      alias connect_without_callbacks connect
      alias connect connect_with_callbacks
    end

    class UnixServer
      def connect_with_callbacks
        Thin::Server.run_before_startup_callbacks
        connect_without_callbacks.tap do
          Thin::Backends::Base.server_index = @socket.to_s.sub(/^.*?\.(\d+)\.sock$/, '\\1').to_i
          Thin::Server.run_after_startup_callbacks
        end
      end
      alias connect_without_callbacks connect
      alias connect connect_with_callbacks
    end
  end

  class Server
    @@before_startup_callbacks = []
    @@after_startup_callbacks = []
    @@close_callbacks = []

    # thin is not yet excepting requests, but EM has started
    def self.add_before_startup_callback(proc=nil, &block)
      @@before_startup_callbacks << (proc || block)
    end

    # this is excepting requests and has written the socket file
    def self.add_after_startup_callback(proc=nil, &block)
      @@after_startup_callbacks << (proc || block)
    end

    # these callbacks are called after all the requests have been processed
    def self.add_close_callback(proc=nil, &block)
      @@close_callbacks << (proc || block)
    end

    def self.run_before_startup_callbacks
      @@before_startup_callbacks.each { |c| c.call } if @@before_startup_callbacks
      @@before_startup_callbacks = nil
    end

    def self.run_after_startup_callbacks
      @@after_startup_callbacks.each { |c| c.call } if @@after_startup_callbacks
      @@after_startup_callbacks = nil
    end

    def stop_with_callbacks
      stop_without_callbacks.tap do
        @@close_callbacks.each { |c| c.call } if @@close_callbacks
        @@close_callbacks = nil
      end
    end
    alias stop_without_callbacks stop
    alias stop stop_with_callbacks
  end
end
