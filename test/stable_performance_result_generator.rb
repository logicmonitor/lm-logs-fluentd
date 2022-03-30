require 'benchmark'
require 'rubygems'
require 'rubygems/commands/install_command'
require 'rubygems/commands/environment_command'
require 'rubygems/commands/uninstall_command'
require 'rubygems/commands/search_command'
require "fluent/test"
require "fluent/test/helpers"
require "fluent/test/driver/output"
require "json"
require 'fileutils'


$stable_version = "0.0.12"
$plugin_name = "fluent-plugin-lm-logs"
$number = File.read("test/number_of_iterations.txt").to_i
$result_file = "test/tmp/time_taken_by_stable_version.txt"
$record = JSON.parse(File.read('test/plugin/bulkyrecord.json'))

def create_driver(conf = CONFIG)
    Fluent::Test::Driver::Output.new(Fluent::LmOutput).configure(conf)
end

def create_valid_subject
    create_driver(%[
        api_key = foo
      ]).instance
end
def get_real_time_benchmark(number,tag, time, record )
    ## installing stable versioned fluent-plugin lm-logs
    cmd = Gem::Commands::InstallCommand.new
    cmd.handle_options [ $plugin_name, '--version', $stable_version]
    begin 
        cmd.execute
      rescue Gem::SystemExitException => e
        puts "DONE: #{e.exit_code}"
    end

    ## require the stable version path
    stable_gem_path = get_gem_path()
    require stable_gem_path

    ## calculate realtime taken to perform test
    plugin1 = create_driver(%[
        resource_mapping {"someProp": "lm_property"} 
      ]).instance
    time_taken =  Benchmark.realtime {
        number.times do 
            plugin1.process_record(tag, time, record)
        end
    }    
    puts "time taken by stable version (#{$stable_version})  : #{time_taken}"

    ## uninstall the installed plugin
    cmd = Gem::Commands::UninstallCommand.new
    cmd.handle_options ['-x', '-I', $plugin_name, '--version', $stable_version]
    begin 
        cmd.execute
        puts "uninstall done"
      rescue Gem::SystemExitException => e
        puts "DONE: #{e.exit_code}"
    end
    return time_taken
end    


def get_gem_path()
    return Gem.dir + "/gems/" + $plugin_name + "-" + $stable_version + "/lib/fluent/plugin/out_lm" 
end

def write_result_to_file(path)
    time_taken = get_real_time_benchmark($number,$tag, $time, $record )  
    FileUtils.mkdir_p 'test/tmp/'
    File.open(path, "w+") { |file| file.write(time_taken) }
end

def read_json_to_map()
    data = JSON.parse(File.read('test/plugin/bulkyrecord.json'))
    puts data
end

puts "writing stable version's performance result to file "
write_result_to_file($result_file)
