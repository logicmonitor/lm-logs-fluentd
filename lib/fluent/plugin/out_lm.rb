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
require('zlib')


module Fluent
  class LmOutput < BufferedOutput
    Fluent::Plugin.register_output('lm', self)

    # config_param defines a parameter. You can refer a parameter via @path instance variable

    config_param :access_id,  :string, :default => "access_id"

    config_param :access_key,  :string, :default => "access_key"

    config_param :company_name,  :string, :default => "company_name"

    config_param :resource_mapping,  :hash, :default => {"host": "system.hostname", "hostname": "system.hostname"}

    config_param :debug,  :bool, :default => false

    config_param :include_metadata,  :bool, :default => false
		
    config_param :force_encoding,  :string, :default => ""

    config_param :compression,  :string, :default => ""

    config_param :log_source,  :string, :default => "lm-logs-fluentd"

    config_param :version_id,  :string, :default => "version_id"

    config_param :device_less_logs,  :bool, :default => false

    config_param :metadata_to_exclude,  :array, default: [], value_type: :string
  
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
      if !@device_less_logs
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
      end

      if record["timestamp"] != nil
        lm_event["timestamp"] = record["timestamp"]
      else
        lm_event["timestamp"] = Time.at(time).utc.to_datetime.rfc3339
      end

      if @include_metadata || @device_less_logs
        record.each do |key, value|
          case key
          when *@metadata_to_exclude.concat(["timestamp","_lm.resourceId","log","message"])
            log.debug "excluding metadata : #{key}"
          else    
            log.debug "attaching metadata : #{key}"
              lm_event["#{key}"] = value
  
              if @force_encoding != ""
                  lm_event["#{key}"] = lm_event["#{key}"].force_encoding(@force_encoding).encode("UTF-8")
              end
          end
        end
      end
      lm_event["message"] = record["message"]
    
      if @force_encoding != ""
        lm_event["message"] = lm_event["message"].force_encoding(@force_encoding).encode("UTF-8")
      end

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
      request['User-Agent'] = log_source + "/" + version_id

      if @compression == "gzip"
        request['Content-Encoding'] = "gzip"
        gzip = Zlib::GzipWriter.new(StringIO.new)
        gzip << body
        request.body = gzip.close.string
      else
        request.body = body
      end

      if @debug
        log.info "Sending the below request headers to logicmonitor:"
        request.each_header {|key,value| log.info "#{key} = #{value}" }
      end

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