require 'fluent/output'
require 'date'
require 'time'
require 'uri'
require 'digest'
require 'json'
require 'openssl'
require 'base64'
require 'net/http'
require 'net/https'


module Fluent
  class LmOutput < BufferedOutput
    Fluent::Plugin.register_output('lm', self)

    # config_param defines a parameter. You can refer a parameter via @path instance variable

    config_param :access_id,  :string, :default => "access_id"

    config_param :access_key,  :string, :default => "access_key"

    config_param :company_name,  :string, :default => "company_name"

    config_param :resource_mapping,  :hash, :default => {"host": "system.hostname", "hostname": "system.hostname"}

    config_param :debug,  :bool, :default => false

    # This method is called before starting.
    # 'conf' is a Hash that includes configuration parameters.
    # If the configuration is invalid, raise Fluent::ConfigError.
    def configure(conf)
      super
    end

    # This method is called when starting.
    # Open sockets or files here.
    def start
      super
    end

    # This method is called when shutting down.
    # Shutdown the thread and close sockets or files here.
    def shutdown
      super
    end

    # This method is called when an event reaches to Fluentd.
    # Convert the event to a raw string.
    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    # This method is called every flush interval. Write the buffer chunk
    # to files or databases here.
    # 'chunk' is a buffer chunk that includes multiple formatted
    # events. You can use 'data = chunk.read' to get all events and
    # 'chunk.open {|io| ... }' to get IO objects.
    #
    # NOTE! This method is called by internal thread, not Fluentd's main thread. So IO wait doesn't affect other plugins.
    def write(chunk)
      events = []
      chunk.msgpack_each do |(tag, time, record)|
        event = process_record(tag,time,record)
        events.push(event)
      end
      send_batch(events)
    end

    def process_record(tag, time, record)
      resource_map = {}
      lm_event = {}
      lm_event["message"] = record["message"]
      if record["_lm.resourceId"] == nil
          @resource_mapping.each do |key, value|
            k = value
            nestedVal = record
            key.to_s.split('.').each { |x| nestedVal = nestedVal[x] }
            if nestedVal != nil
              resource_map[k] = nestedVal
            end
          end
        lm_event["_lm.resourceId"] = resource_map
      else
        lm_event["_lm.resourceId"] = record["_lm.resourceId"]
      end
  
      lm_event["timestamp"] = Time.at(time).utc.to_datetime.rfc3339
      return lm_event
    end

    def send_batch(events)
      url = "https://#{@company_name}.logicmonitor.com/rest/log/ingest"
      body = events.to_json
      uri = URI.parse(url)
      
      if @debug
        log.info "Sending #{events.length} events to logic monitor at #{url}"
        log.info "Request json #{body}"
      end

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.request_uri)
      request['authorization'] = generate_token(events)
      request['Content-type'] = "application/json"  
      request.body = body

      resp = http.request(request)
      if @debug || (!resp.kind_of? Net::HTTPSuccess)
        log.info "Status code:#{resp.code} Request Id:#{resp.header['x-request-id']}"
      end
    end


    def generate_token(events)
      timestamp = DateTime.now.strftime('%Q')
      signature = Base64.strict_encode64(
          OpenSSL::HMAC.hexdigest(
              OpenSSL::Digest.new('sha256'),
              @access_key,
              "POST#{timestamp}#{events.to_json}/log/ingest"
          )
      )
      "LMv1 #{@access_id}:#{signature}:#{timestamp}"
    end
  end
end
