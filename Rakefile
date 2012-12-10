require 'rspec/core/rake_task'
require 'bundler/gem_tasks'
require 'rdoc/task'

task :default => :spec

RSpec::Core::RakeTask.new

RDoc::Task.new do |i|
  i.rdoc_files = FileList['lib/**/*.rb']
end

# vim: set sw=2 et cc=80:
