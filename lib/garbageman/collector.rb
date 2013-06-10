require 'singleton'

module GarbageMan
  class Collector
    include Singleton

    attr_accessor :request_count, :will_collect
    attr_reader :fiber_poll

    def initialize
      reset
    end

    def register_fiber_pool(pool)
      @fiber_poll = pool
    end

    def healthy?
      unless can_disable?
        debug "can not disable gc"
        GC.enable
        return true
      end

      if should_collect?
        write_gc_yaml server_index, 'will_collect'
        false
      else
        true
      end
    end

    def collect
      return unless can_collect?

      write_gc_yaml server_index, 'starting'
      debug "starting gc"
      starts = Time.now
      GC.enable
      GC.start
      diff = (Time.now - starts) * 1000
      info "GC took #{'%.2f' % diff}ms"
      write_gc_yaml server_index, 'finished'

      reset

      if can_disable? && select_next_server
        debug "disabling gc"
        GC.disable
      else
        debug "enabling gc, can not turn off"
        GC.enable
      end
    end

    def create_gc_yaml
      return unless server_index
      return if File.exists?(Config.gc_yaml_file)
      write_gc_yaml server_index, 'selected'
    end

    def logger; GarbageMan.logger; end

    def debug(msg)
      logger.debug msg
    end

    def info(msg)
      logger.info msg
    end

    private

    def server_index
      Thin::Backends::Base.server_index
    end

    def num_servers
      Config.thin_config['servers']
    end

    def write_gc_yaml(index, status)
      config = {'gc' => {'server' => index, 'status' => status}}
      File.open(Config.gc_yaml_file, 'w+') { |f| f.write config.to_yaml }
    end

    def select_next_server
      Config.thin_config['servers'].times do |i|
        next_server_index = (server_index + i + 1) % num_servers
        file = socket_file next_server_index
        next unless File.exists?(file)
        debug "selected #{next_server_index}"
        write_gc_yaml next_server_index, 'selected'
        return true
      end
      false
    end

    def reset
      @request_count = 0
      @will_collect = false
    end

    def busy?
      fiber_poll && fiber_poll.busy_fibers.size > 0
    end

    # no traffic and we've been selected by health check
    def can_collect?
      @will_collect && ! busy? && Thin::Backends::Base.num_connections == 0
    end

    # if the request count is high enough and it is our turn
    def should_collect?
      @will_collect = (@request_count >= Config.num_request_before_collecting && current_server?)
    end

    def current_server?
      config = Config.gc_config
      config && config['gc'] && config['gc']['server'] && config['gc']['server'] == server_index
    end

    def can_disable?
      Config.thin_config.has_key?('socket') && not_alone?
    end

    # make sure I'm not the only server running
    def not_alone?
      Config.thin_config['servers'].times do |i|
        next if i == server_index
        file = socket_file i
        if File.exists?(file)
          return true
        end
      end

      debug "no other servers found"
      false
    end

    def socket_file(index)
      Config.thin_config['socket'].sub '.sock', ".#{index}.sock"
    end
  end
end

