require "fluent/test"
require "fluent/test/helpers"
require "fluent/test/driver/output"
require "../../lib/fluent/plugin/out_lm"

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
      record = {"message" => "Hello from test", "_lm.resourceId" => { "lm_property": "lm_property_value"  } , "a": "b"}
    
      result = plugin.process_record(tag, time, record)
			
      expected = {
          "message" => "Hello from test",
          "_lm.resourceId" => record["_lm.resourceId"],
          "timestamp" => "2020-08-23T00:53:15+00:00"
      }

      assert_equal result.to_json ,expected.to_json
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

    test "invalid utf-8 character passed, it should convert" do
      plugin = create_driver(%[
          resource_mapping {"a.b": "lm_property"} 
          force_encoding true
      ]).instance
      tag = "lm.test"
      time = Time.parse("2020-08-23T00:53:15+00:00").to_i
      record = {"message" => "LogicMonitor\xAE", "a" => { "b" => "lm_property_value" } }
    
      event = plugin.process_record(tag, time, record)
  
      assert_equal "LogicMonitor®", event["message"]
    end
  end
end