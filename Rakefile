require "bundler/gem_tasks"
require "rake/testtask"
task default: "test"

Rake::TestTask.new do |task|
 task.libs << "test"
 task.test_files = Dir.glob('test/plugin/*.rb') - ['test/plugin/test_performance.rb']
end
