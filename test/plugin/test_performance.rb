require "fluent/test"
require "fluent/test/helpers"
require "fluent/test/driver/output"
require "./lib/fluent/plugin/out_lm"
require 'benchmark'


class FluentLMTest < Test::Unit::TestCase
  include Fluent::Test::Helpers

  def setup
    Fluent::Test.setup
  end

  def create_driver(conf = CONFIG)
    Fluent::Test::Driver::Output.new(Fluent::LmOutput).configure(conf)
  end

  def create_valid_subject
    create_driver(%[
        api_key = foo
      ]).instance
  end
  @@benchmark_time = File.read("test/tmp/time_taken_by_stable_version.txt").to_f
  @@loop_size=File.read("test/number_of_iterations.txt").to_i
  @@tag = "lm.test"
  @@time = Time.parse("2020-08-23T00:53:15+00:00").to_i
  @@bulky_record = JSON.parse(File.read('test/plugin/bulkyrecord.json'))

    def is_tolerable_performance(plugin, tag, time, record, toleration_factor)
        time_taken = Benchmark.realtime {
            @@loop_size.times do 
                plugin.process_record(tag, time, record)
            end
        }
        puts "time taken by plugin : #{time_taken} , time taken by stable version : #{@@benchmark_time}"
        if time_taken/@@benchmark_time >= toleration_factor
            return false
        else
            return true
        end
      end 

## we should add performance tests as new feature gets added to the plugin.
  sub_test_case "performance tests" do
    test "include_metadata configs" do

      puts "\ninclude_metadata configs"
      config1 = "include_metadata true"  
      plugin1 = create_driver(%[
        resource_mapping {"someProp": "lm_property"} 
        include_metadata true
      ]).instance


      config2 = "include_metadata false"  
      plugin2 = create_driver(%[
        resource_mapping {"someProp": "lm_property"} 
        include_metadata false
      ]).instance


      Benchmark.bmbm( 50 ) do |bm|  # The 50 is the width of the first column in the output.
        bm.report( "#{config1}" ) do 
            @@loop_size.times do
                plugin1.process_record(@@tag, @@time, @@bulky_record)
            end    
        end
       
        bm.report( "#{config2}" ) do
            @@loop_size.times do
                plugin2.process_record(@@tag, @@time, @@bulky_record)
            end
        end
      end
      assert_equal true, is_tolerable_performance(plugin1,@@tag, @@time, @@bulky_record, 2)
      assert_equal true, is_tolerable_performance(plugin2,@@tag, @@time, @@bulky_record, 2)
    end
    test "device_less_logs" do

        puts "\ndevice_less_logs configs"
        config1 = "device_less_logs true"  
        plugin1 = create_driver(%[
          device_less_logs true
        ]).instance
  
  
        config2 = "device_less_logs false"  
        plugin2 = create_driver(%[
          resource_mapping {"someProp": "lm_property"} 
          device_less_logs false
        ]).instance
  
        Benchmark.bmbm( 50 ) do |bm|  # The 50 is the width of the first column in the output.
          bm.report( "#{config1}" ) do 
              @@loop_size.times do
                  plugin1.process_record(@@tag, @@time, @@bulky_record)
              end    
          end
         
          bm.report( "#{config2}" ) do
              @@loop_size.times do
                  plugin2.process_record(@@tag, @@time, @@bulky_record)
              end
          end
        end

        assert_equal true, is_tolerable_performance(plugin1,@@tag, @@time, @@bulky_record, 2)
        assert_equal true, is_tolerable_performance(plugin2,@@tag, @@time, @@bulky_record, 2)


      end

  end
end