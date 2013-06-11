require 'singleton'

module GarbageMan
  class Collector
    include Singleton

    module Status
      SELECTED = 'selected'
      WILL_COLLECT = 'will_collect'
      STARTING = 'starting'
      NEXT_SERVER = 'next_server'
    end

    include Status

    attr_accessor :request_count, :will_collect, :will_select_next_server
    attr_reader :fiber_poll

    def initialize
      reset
    end

    # for use with rack-fiber_pool
    def register_fiber_pool(pool)
      @fiber_poll = pool
    end

    def healthy?
      unless can_disable?
        debug "can not disable gc"
        GC.enable
        return true
      end

      if select_next_server?
        if @will_select_next_server
          select_next_server
        else
          # wait until we receive another request before selecting the next server
          @will_select_next_server = true
        end
        return true
      end

      if should_collect?
        write_gc_yaml server_index, WILL_COLLECT
        false
      else
        true
      end
    end

    def collect
      # if we are starting to queue requests turn on gc, we could be in trouble
      if queuing?
        debug "queuing request, enabling gc"
        GC.enable
        return
      end

      return unless can_collect?

      write_gc_yaml server_index, STARTING
      debug "starting gc"
      starts = Time.now
      GC.enable
      GC.start
      diff = (Time.now - starts) * 1000
      info "GC took #{'%.2f' % diff}ms"
      write_gc_yaml server_index, NEXT_SERVER

      reset

      if can_disable?
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
      write_gc_yaml server_index, SELECTED
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
      return unless @will_select_next_server
      @will_select_next_server = false

      Config.thin_config['servers'].times do |i|
        next_server_index = (server_index + i + 1) % num_servers
        file = socket_file next_server_index
        next unless File.exists?(file)
        debug "selected #{next_server_index}"
        write_gc_yaml next_server_index, SELECTED
        return true
      end
      false
    end

    def reset
      @request_count = 0
      @will_collect = false
      @will_select_next_server = false
    end

    def busy?
      fiber_poll && fiber_poll.busy_fibers.size > 0
    end

    def queuing?
      fiber_poll && fiber_poll.queue.size > 0
    end

    def not_queuing?
      ! queuing?
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

    def select_next_server?
      config = Config.gc_config
      config && config['gc'] && config['gc']['server'] && config['gc']['server'] == server_index && config['gc']['status'] == 'next_server'
    end

    def can_disable?
      Config.thin_config.has_key?('socket') && not_queuing? && min_running_servers?
    end

    def num_running_servers
      count = 0
      Config.thin_config['servers'].times do |i|
        count += 1 if i == server_index || File.exists?(socket_file(i))
      end
      count
    end

    # make sure there are 3 or more servers running before disabling gc
    def min_running_servers?
      num_servers >= Config.min_servers_to_disable_gc && num_running_servers >= Config.min_servers_to_disable_gc
    end

    def socket_file(index)
      Config.thin_config['socket'].sub '.sock', ".#{index}.sock"
    end
  end
end

