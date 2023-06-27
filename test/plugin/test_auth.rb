require "fluent/test"
require "fluent/test/helpers"
require "fluent/test/driver/output"
require "./lib/fluent/plugin/out_lm"


class FluentLMTest < Test::Unit::TestCase
  include Fluent::Test::Helpers

  def setup
    Fluent::Test.setup
  end

  def create_driver(conf)
    Fluent::Test::Driver::Output.new(Fluent::LmOutput).configure(conf)
  end

  def create_valid_subject
    create_driver(%[
        api_key = foo
      ]).instance
  end
  sub_test_case "Authentication" do
    test "If bearer_token, access_id, access_key not specified throw an error" do
      plugin = create_driver(%[]).instance
      assert_raise(ArgumentError) { plugin.configure_auth() }
    end

    test "access_key id is specified with no bearer " do
      plugin = create_driver(%[
        access_key abcd
        access_id abcd
      ]).instance
      tag = "lm.test"
      time = Time.parse("2020-08-23T00:53:15+00:00")
      record = {
                "message" => "Hello there",  
                "timestamp" => "2020-10-30T00:29:08.629701504Z" 
                     }
      events = [record]  

      result = plugin.generate_token(events)
      assert_match "LMv1 abcd:", result
    end

    test "when access id /key not specified but bearer specified " do
      plugin = create_driver(%[
        access_id abcd
        bearer_token abcd
      ]).instance
      plugin.configure_auth()
      tag = "lm.test"
      time = Time.parse("2020-08-23T00:53:15+00:00").to_i
      record = {"message" => "Hello from test",  
                "timestamp" => "2020-10-30T00:29:08.629701504Z" 
              }

      events = [record]  

      result = plugin.generate_token(events)
        
      assert_match "Bearer abcd", result
    end 

    test "when access id /key bearer all specified, use lmv1 " do
        plugin = create_driver(%[
          access_id abcd
          access_key abcd
          bearer_token abcd
        ]).instance
        plugin.configure_auth()
        tag = "lm.test"
        time = Time.parse("2020-08-23T00:53:15+00:00").to_i
        record = {"message" => "Hello from test",  
                  "timestamp" => "2020-10-30T00:29:08.629701504Z" 
                }
  
        events = [record]  
  
        result = plugin.generate_token(events)
          
        assert_match "LMv1 abcd:", result
    end
  end
end