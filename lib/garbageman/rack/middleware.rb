module GarbageMan
  module Rack
    class Middleware
      def initialize(app)
        @app = app
      end

      @@ok_response = [200, {'Content-Length' => '0'}, '']
      @@gc_response = [589, {'Content-Length' => '0'}, '']
      def call(env)
        GarbageMan::Collector.instance.request_count += 1

        if env['REQUEST_PATH'] == GarbageMan::Config.gc_health_check_request_path
          GarbageMan::Collector.instance.healthy? ? @@ok_response : @@gc_response
        else
          GarbageMan::Collector.instance.logger.error("still receiving traffic even though I'm waiting to GC") if GarbageMan::Collector.instance.will_collect
          @app.call(env)
        end
      end
    end
  end
end
