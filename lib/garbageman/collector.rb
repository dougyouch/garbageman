require 'singleton'
require 'fileutils'

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

    module Messages
      CAN_NOT_DISABLE_GC = "can not disable gc"
      QUEUING_REQUESTS = "queuing request, enabling gc"
      WAITED_TOO_LONG = "waited %.2f seconds to gc"
      DISABLE_GC = "disabling gc"
      CANT_TURN_OFF = "enabling gc, can not turn off"
      CONNECTIONS_DID_NOT_DRAIN_IN_TIME = 'connections did not drain in time'
    end

    include Messages

    attr_accessor :request_count, :will_collect, :will_select_next_server, :show_gc_times
    attr_reader :fiber_poll, :last_gc_finished_at, :before_gc_callbacks, :after_gc_callbacks, :selected_to_collect_at

    def initialize
      @show_gc_times = true
      @before_gc_callbacks = []
      @after_gc_callbacks = []
      reset
    end

    # for use with rack-fiber_pool
    def register_fiber_pool(pool)
      @fiber_poll = pool
    end

    def healthy?
      unless can_disable?
        warn CAN_NOT_DISABLE_GC
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
        @selected_to_collect_at ||= Time.now
        write_gc_yaml server_index, WILL_COLLECT
        false
      else
        true
      end
    end

    def collect
      # if we are starting to queue requests turn on gc, we could be in trouble
      if Config.check_request_queue? && queuing?
        warn QUEUING_REQUESTS
        GC.enable
      elsif waited_too_long_to_gc?
        warn (WAITED_TOO_LONG % (Time.now - @last_gc_finished_at))
        GC.enable
      end

      unless can_collect?
        return unless will_collect # return unless been selected to gc
        if waited_too_long_for_connections_to_drain?
          warn CONNECTIONS_DID_NOT_DRAIN_IN_TIME
        else
          return
        end
      end

      File.open(Config.gc_last_collected_file, 'w') { |f| f.write Time.now.to_i.to_s }

      before_gc_callbacks.each(&:call)

      write_gc_yaml server_index, STARTING
      debug "starting gc"
      starts = Time.now
      GC.enable
      GC.start
      @last_gc_finished_at = Time.now
      diff = (@last_gc_finished_at - starts) * 1000
      info "GC took #{'%.2f' % diff}ms for #{@request_count} requests" if @show_gc_times
      write_gc_yaml server_index, NEXT_SERVER

      after_gc_callbacks.each(&:call)

      reset

      if can_disable?
        debug DISABLE_GC
        GC.disable
      else
        warn CANT_TURN_OFF
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

    def warn(msg)
      logger.warn msg
    end

    def select_next_server
      return unless @will_select_next_server
      return unless @request_count >= Config.num_request_before_selecting_next_server
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

    private

    def server_index
      Thin::Backends::Base.server_index
    end

    def num_servers
      Config.thin_config['servers']
    end

    WRITE_MOVE_OPTIONS = {:force => true}
    def write_gc_yaml(index, status)
      config = {'gc' => {'server' => index, 'status' => status}}
      File.open(Config.gc_yaml_tmp_file, 'w') { |f| f.write config.to_yaml }
      # atomic write
      FileUtils.mv Config.gc_yaml_tmp_file, Config.gc_yaml_file, WRITE_MOVE_OPTIONS
    end

    def reset
      @request_count = 0
      @will_collect = false
      @will_select_next_server = false
      @selected_to_collect_at = nil
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

    def forcing_gc?
      File.exists?(Config.enable_gc_file)
    end
 
    def not_forcing_gc?
      ! forcing_gc?
    end

    def uses_sockets?
      Config.thin_config.has_key?('socket')
    end

    def can_disable?
      uses_sockets? &&
        not_queuing? &&
        not_forcing_gc? &&
        enough_running_servers?
    end

    def num_running_servers
      count = 0
      Config.thin_config['servers'].times do |i|
        count += 1 if i == server_index || File.exists?(socket_file(i))
      end
      count
    end

    # make sure there are 3 or more servers running before disabling gc
    def enough_running_servers?
      num_servers >= Config.min_servers_to_disable_gc && num_running_servers >= Config.min_servers_to_disable_gc
    end

    def socket_file(index)
      Config.thin_config['socket'].sub '.sock', ".#{index}.sock"
    end

    def waited_too_long_to_gc?
      return false unless @last_gc_finished_at
      (Time.now - @last_gc_finished_at) >= Config.max_time_without_gc
    end

    def waited_too_long_for_connections_to_drain?
      @selected_to_collect_at && (Time.now - @selected_to_collect_at) >= Config.max_connection_drain_time
    end
  end
end

