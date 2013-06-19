module GarbageMan
  class Config
    @@gc_health_check_request_path = '/gc_health_check'
    def self.gc_health_check_request_path; @@gc_health_check_request_path; end

    @@gc_yaml_file = nil
    def self.gc_yaml_file; @@gc_yaml_file ||= "./data/gc.yml"; end
    def self.gc_yaml_file=(file); @@gc_yaml_file = file; end

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

    def self.num_request_before_collecting; 20; end
    # absolutely make sure we are in the pool again before selecting next server
    def self.num_request_before_selecting_next_server; 10; end
    def self.min_servers_to_disable_gc; 2; end
    # if we have not GC in 20 seconds turn back on GC
    def self.max_time_without_gc; 20; end
  end
end
