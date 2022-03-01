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


  sub_test_case "resource_mapping" do
    test "_lm.resourceId sent in the record, should not use resource_mapping, and forward the same object " do
      plugin = create_driver(%[
      ]).instance
      tag = "lm.test"
      time = Time.parse("2020-08-23T00:53:15+00:00").to_i
      record = {"message" => "Hello from test", "_lm.resourceId" => { "lm_property": "lm_property_value"   }}
    
      result = plugin.process_record(tag, time, record)
    
      expected = {
          "message" => "Hello from test",
          "_lm.resourceId" => record["_lm.resourceId"],
          "timestamp" => "2020-08-23T00:53:15+00:00"
      }

      assert_equal expected, result
    end

    test "resource_mapping passed, should extract value from record" do
        plugin = create_driver(%[
            resource_mapping {"a.b": "lm_property"} 
        ]).instance
        tag = "lm.test"
        time = Time.parse("2020-08-23T00:53:15+00:00").to_i
        record = {"message" => "Hello from test", "a" => { "b" => "lm_property_value" } }
      
        result = plugin.process_record(tag, time, record)
      
        expected = {
            "message" => "Hello from test",
            "_lm.resourceId" => {
                "lm_property" => "lm_property_value"
            },
            "timestamp" => "2020-08-23T00:53:15+00:00"
        }
  
        assert_equal expected, result
      end
  end

  sub_test_case "force_encoding" do
    test "force_encoding passed as true, should convert invalid utf-8 characters" do
      plugin = create_driver(%[
          resource_mapping {"a.b": "lm_property"} 
          force_encoding ISO-8859-1
      ]).instance

      tag = "lm.test"
      time = Time.parse("2020-08-23T00:53:15+00:00").to_i
      event = {"message" => "LogicMonitor\xAE", "a" => { "b" => "lm_property_value" } }
    
      event = plugin.process_record(tag, time, event)

      assert_equal "LogicMonitor®", event["message"]
    end
  end
  

  sub_test_case "time" do
    test "timestamp passed in the record, it should use that" do
      plugin = create_driver(%[
        resource_mapping {"a.b": "lm_property"} 
      ]).instance

      tag = "lm.test"
      time = Time.parse("2020-08-23T00:53:15+00:00").to_i
      record = {"message" => "Hello from test",  "timestamp" => "2020-10-30T00:29:08.629701504Z" ,"a" => { "b" => "lm_property_value" } }
    
      result = plugin.process_record(tag, time, record)
        
      expected = {
          "message" => "Hello from test",
          "_lm.resourceId" => {
              "lm_property" => "lm_property_value"
          },
          "timestamp" => "2020-10-30T00:29:08.629701504Z"
      }

      assert_equal expected, result
    end
  end

  sub_test_case "include_metadata" do
    test "include_metadata passed as true, it should include other record items as additional metadata" do
      plugin = create_driver(%[
        resource_mapping {"a.b": "lm_property"} 
        include_metadata true
      ]).instance

      tag = "lm.test"
      time = Time.parse("2020-08-23T00:53:15+00:00").to_i
      record = {"message" => "Hello from test",  "timestamp" => "2020-10-30T00:29:08.629701504Z", "tag" => "lm.test" , "_lm.resourceId" => { "lm_property": "lm_property_value" } }

      result = plugin.process_record(tag, time, record)
        
      expected = {
          "message" => "Hello from test",
          "_lm.resourceId" => record["_lm.resourceId"],
          "timestamp" => "2020-10-30T00:29:08.629701504Z",
          "tag" => "lm.test"
      }

      assert_equal expected, result
    end

    test "include_metadata passed as false, it should exclude other record items as additional metadata" do
      plugin = create_driver(%[
        resource_mapping {"a.b": "lm_property"} 
        include_metadata false
      ]).instance

      tag = "lm.test"
      time = Time.parse("2020-08-23T00:53:15+00:00").to_i
      record = {"message" => "Hello from test",  "timestamp" => "2020-10-30T00:29:08.629701504Z", "tag" => "lm.test" , "_lm.resourceId" => { "lm_property": "lm_property_value" } }

      result = plugin.process_record(tag, time, record)
        
      expected = {
          "message" => "Hello from test",
          "_lm.resourceId" => record["_lm.resourceId"],
          "timestamp" => "2020-10-30T00:29:08.629701504Z"
      }

      assert_equal expected, result
    end

    test "include_metadata true, try to include everything except in metadata_to_exclude" do
      plugin = create_driver(%[
        resource_mapping {"someProp": "lm_property"} 
        include_metadata true
        metadata_to_exclude ["meta1", "meta3","someProp"]
      ]).instance
      tag = "lm.test"
      time = Time.parse("2020-08-23T00:53:15+00:00").to_i
      record = {"message" => "Hello from test",  "timestamp" => "2020-10-30T00:29:08.629701504Z" , "meta1" => "testMeta1" , "meta2" => "testMeta2", "meta3" => "testMeta3", "meta4" => "testMeta4", "meta5" => {"key1" => "value1", "key2" => {"key2_1" => "value2_1"}}, "someProp" => "resourcePropVal" }

      result = plugin.process_record(tag, time, record)
        
      expected = {
          "message" => "Hello from test",
          "timestamp" => "2020-10-30T00:29:08.629701504Z",
          "_lm.resourceId" => {"lm_property" => "resourcePropVal"},
          "meta2" => "testMeta2",
          "meta4" => "testMeta4", 
          "meta5" => {"key1" => "value1", "key2" => {"key2_1" => "value2_1"}},
      }
      assert_equal expected, result
    end
  end
  

  sub_test_case "device_less_logs" do
    test "if device_less_logs is true, resource_mapping to be skipped and metadata to be added" do
      plugin = create_driver(%[
        resource_mapping {"a.b": "lm_property"} 
        device_less_logs true
      ]).instance
      tag = "lm.test"
      time = Time.parse("2020-08-23T00:53:15+00:00").to_i
      record = {"message" => "Hello from test",  "timestamp" => "2020-10-30T00:29:08.629701504Z", "tag" => "lm.test", "meta1" => "metadata1", "meta2" => "metadata2", "service" => "lm-service", "namespace" => "lm-namepsace"}

      result = plugin.process_record(tag, time, record)
        
      expected = {
          "message" => "Hello from test",
          "timestamp" => "2020-10-30T00:29:08.629701504Z",
          "tag" => "lm.test",
          "meta1" => "metadata1",
          "meta2" => "metadata2",
          "service" => "lm-service", 
          "namespace" => "lm-namepsace"
      }
      assert_equal expected, result
    end

    test "if device_less_logs is true even when include_metadata false, skip metadata defined  in metadata_to_exclude and resource_mapping" do
      plugin = create_driver(%[
        resource_mapping {"a.b": "lm_property"} 
        device_less_logs true
        include_metadata false
        metadata_to_exclude ["meta1", "meta3"]
      ]).instance
      tag = "lm.test"
      time = Time.parse("2020-08-23T00:53:15+00:00").to_i
      record = {"message" => "Hello from test",  "timestamp" => "2020-10-30T00:29:08.629701504Z" , "meta1" => "testMeta1" , "meta2" => "testMeta2", "meta3" => "testMeta3", "meta4" => "testMeta4", "meta5" => {"key1" => "value1", "key2" => {"key2_1" => "value2_1"}}, "service" => "lm-service", "namespace" => "lm-namepsace" }

      result = plugin.process_record(tag, time, record)
        
      expected = {
          "message" => "Hello from test",
          "timestamp" => "2020-10-30T00:29:08.629701504Z",
          "meta2" => "testMeta2",
          "meta4" => "testMeta4", 
          "meta5" => {"key1" => "value1", "key2" => {"key2_1" => "value2_1"}},
          "service" => "lm-service",
          "namespace" => "lm-namepsace"
      }
      assert_equal expected, result
    end

    test "when device_less_logs is true record must have \'service\' and \'namespace\'" do
      plugin = create_driver(%[
        resource_mapping {"a.b": "lm_property"} 
        device_less_logs true
        include_metadata false
        metadata_to_exclude ["meta1", "meta3"]
      ]).instance
      tag = "lm.test"
      time = Time.parse("2020-08-23T00:53:15+00:00").to_i
      record = {"message" => "Hello from test",  "timestamp" => "2020-10-30T00:29:08.629701504Z" , "meta1" => "testMeta1" , "meta2" => "testMeta2", "meta3" => "testMeta3", "meta4" => "testMeta4", "meta5" => {"key1" => "value1", "key2" => {"key2_1" => "value2_1"}}, "service" => "lm-service" }

      result = plugin.process_record(tag, time, record)
        
      expected = nil
      assert_equal expected, result
    end
 
  end
end