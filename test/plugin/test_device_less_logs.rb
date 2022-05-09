require "fluent/test"
require "fluent/test/helpers"
require "fluent/test/driver/output"
require "./lib/fluent/plugin/out_lm"

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
  sub_test_case "device_less_logs" do
    test "if device_less_logs is true, resource_mapping to be skipped" do
      plugin = create_driver(%[
        resource_mapping {"someProp": "lm_property"} 
        device_less_logs true
      ]).instance
      tag = "lm.test"
      time = Time.parse("2020-08-23T00:53:15+00:00").to_i
      record = {"message" => "Hello from test",  
                "timestamp" => "2020-10-30T00:29:08.629701504Z", 
                "tag" => "lm.test", 
                "meta1" => "metadata1", 
                "meta2" => "metadata2", 
                "resource.service.name" => "lm-service", 
                "resource.service.namespace" => "lm-namepsace",
                "someProp" => "someVal"}

      result = plugin.process_record(tag, time, record)
        
      expected = {
          "message" => "Hello from test",
          "timestamp" => "2020-10-30T00:29:08.629701504Z",
          "resource.service.name" => "lm-service"
      }
      assert_equal expected, result
    end

    test "if device_less_logs and include_metadata true along with metadata, record needs service" do
      plugin = create_driver(%[
        resource_mapping {"a.b": "lm_property"} 
        device_less_logs true
        include_metadata true
      ]).instance
      tag = "lm.test"
      time = Time.parse("2020-08-23T00:53:15+00:00").to_i
      record = {
                "message" => "Hello from test",  
                "timestamp" => "2020-10-30T00:29:08.629701504Z" , 
                "meta1" => "testMeta1" , 
                "meta2" => "testMeta2", 
                "meta3" => "testMeta3", 
                "meta4" => "testMeta4", 
                "meta5" => {"key1" => "value1", "key2" => {"key2_1" => "value2_1"}}, 
                "resource.service.name" => "lm-service" }

      result = plugin.process_record(tag, time, record)
        
      expected = {
          "message" => "Hello from test",
          "timestamp" => "2020-10-30T00:29:08.629701504Z",
          "meta1" => "testMeta1" , 
          "meta2" => "testMeta2", 
          "meta3" => "testMeta3", 
          "meta4" => "testMeta4", 
          "meta5" => {"key1" => "value1", "key2" => {"key2_1" => "value2_1"}}, 
          "resource.service.name" => "lm-service"
      }
      assert_equal expected, result
    end

    test "when device_less_logs is true record must have \'service\' " do
      plugin = create_driver(%[
        resource_mapping {"a.b": "lm_property"} 
        device_less_logs true
      ]).instance
      tag = "lm.test"
      time = Time.parse("2020-08-23T00:53:15+00:00").to_i
      record = {"message" => "Hello from test",  
                "timestamp" => "2020-10-30T00:29:08.629701504Z" 
              }

      result = plugin.process_record(tag, time, record)
        
      expected = nil
      assert_equal expected, result
    end
  end
end