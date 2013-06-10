module GarbageMan
  class Config
    @@gc_health_check_request_path = '/gc_health_check'
    def self.gc_health_check_request_path; @@gc_health_check_request_path; end

    @@gc_yaml_file = nil
    def self.gc_yaml_file; @@gc_yaml_file ||= "#{Rails.root}/data/gc.yml"; end
    def self.gc_yaml_file=(file); @@gc_yaml_file = file; end

    def self.gc_config
      begin
        File.exists?(self.gc_yaml_file) ? YAML.load_file(self.gc_yaml_file) : nil
      rescue Errno::ENOENT => e
        nil
      end
    end

    @@thin_config = nil
    def self.thin_config; @@thin_config ||= YAML.load_file("#{Rails.root}/config/thin.yml"); end

    def self.num_request_before_collecting; 10; end
  end
end
