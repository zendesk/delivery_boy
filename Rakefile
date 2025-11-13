require "bundler/setup"
require "bundler/gem_tasks"
begin
  require "standard/rake"
rescue LoadError
  :noop
end
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec
