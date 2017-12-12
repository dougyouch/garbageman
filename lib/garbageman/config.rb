module GarbageMan
  class Config
    @@gc_health_check_request_path = '/gc_health_check'
    def self.gc_health_check_request_path; @@gc_health_check_request_path; end

    @@gc_yaml_file = nil
    def self.gc_yaml_file; @@gc_yaml_file ||= "./data/gc.yml"; end
    def self.gc_yaml_file=(file); @@gc_yaml_file = file; end

    @@gc_yaml_tmp_file = nil
    def self.gc_yaml_tmp_file; @@gc_yaml_tmp_file ||= "./data/.tmp.gc.yml"; end
    def self.gc_yaml_tmp_file=(file); @@gc_yaml_tmp_file = file; end

    @@gc_last_collected_file = nil
    def self.gc_last_collected_file; @@gc_last_collected_file ||= "./data/gc-last-collection-time.timestamp"; end
    def self.gc_last_collected_file=(file); @@gc_last_collected_file = file; end

    def self.gc_config
      begin
        File.exists?(self.gc_yaml_file) ? YAML.load_file(self.gc_yaml_file) : nil
      rescue Exception => e
        nil
      end
    end

    @@thin_config = nil
    def self.thin_config; @@thin_config ||= YAML.load_file("./config/thin.yml"); end

    @@enable_gc_file = "./data/enable_gc"
    def self.enable_gc_file; @@enable_gc_file; end

    @@num_request_before_collecting = 20
    def self.num_request_before_collecting; @@num_request_before_collecting; end
    def self.num_request_before_collecting=(val); @@num_request_before_collecting = val; end

    # can configure to turn on gc if server starts queuing requests
    @@check_request_queue = false
    def self.check_request_queue?; @@check_request_queue; end
    def self.check_request_queue=(val); @@check_request_queue = val; end

    # absolutely make sure we are in the pool again before selecting next server
    @@num_request_before_selecting_next_server = 5
    def self.num_request_before_selecting_next_server; @@num_request_before_selecting_next_server; end
    def self.num_request_before_selecting_next_server=(n); @@num_request_before_selecting_next_server = n; end

    @@min_servers_to_disable_gc = 3
    def self.min_servers_to_disable_gc; @@min_servers_to_disable_gc; end
    def self.min_servers_to_disable_gc=(n); @@min_servers_to_disable_gc = n; end

    # if we have not GC in 40 seconds turn back on GC
    @@max_time_without_gc = 60
    def self.max_time_without_gc; @@max_time_without_gc; end
    def self.max_time_without_gc=(time); @@max_time_without_gc = time; end

    # max time to wait for connections to drain
    @@max_connection_drain_time = 60
    def self.max_connection_drain_time; @@max_connection_drain_time; end
    def self.max_connection_drain_time=(time); @@max_connection_drain_time = time; end

    @@gc_starts = 1
    def self.gc_starts; @@gc_starts; end
    def self.gc_starts=(v); @@gc_starts = v; end

    @@gc_sleep = 0.00
    def self.gc_sleep; @@gc_sleep; end
    def self.gc_sleep=(v); @@gc_sleep = v || 10; end

    # after selected and connections are drained, wait this many seconds before
    # collecting so that all proxies are aware that this process will collect
    @@time_to_wait_before_collecting = 2.0
    def self.time_to_wait_before_collecting; @@time_to_wait_before_collecting; end
    def self.time_to_wait_before_collecting=(v); @@time_to_wait_before_collecting = v || 2.0; end
  end
end
