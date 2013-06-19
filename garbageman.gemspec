# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "garbageman"
  s.version = "0.1.18"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Doug Youch"]
  s.date = "2013-06-19"
  s.description = "Disable GC while processing requests.  By using nginx upstream health checks to garbage collect when no one is there."
  s.email = "doug@sessionm.com"
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  s.files = [
    ".document",
    ".rvmrc",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "examples/config.ru",
    "examples/nginx.conf",
    "garbageman.gemspec",
    "lib/garbageman.rb",
    "lib/garbageman/collector.rb",
    "lib/garbageman/config.rb",
    "lib/garbageman/ext/fiber_pool.rb",
    "lib/garbageman/ext/thin.rb",
    "lib/garbageman/rack/middleware.rb",
    "test/helper.rb",
    "test/test_garbageman.rb"
  ]
  s.homepage = "http://github.com/dyouch5@yahoo.com/garbageman"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.23"
  s.summary = "Process requests without garbage collection"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rdoc>, ["~> 3.12"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.8.4"])
      s.add_development_dependency(%q<rspec>, [">= 0"])
    else
      s.add_dependency(%q<rdoc>, ["~> 3.12"])
      s.add_dependency(%q<jeweler>, ["~> 1.8.4"])
      s.add_dependency(%q<rspec>, [">= 0"])
    end
  else
    s.add_dependency(%q<rdoc>, ["~> 3.12"])
    s.add_dependency(%q<jeweler>, ["~> 1.8.4"])
    s.add_dependency(%q<rspec>, [">= 0"])
  end
end

