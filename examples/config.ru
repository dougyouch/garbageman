require 'rubygems'
require 'bundler'

Bundler.require

require './app'
use GarbageMan::Rack::Middleware

Thin::Server.add_before_startup_callback do
  EM.add_periodic_timer(0.5) do
    GarbageMan::Collector.instance.collect
  end
end

Thin::Server.add_after_startup_callback do
  GarbageMan::Collector.instance.create_gc_yaml
end

run App
