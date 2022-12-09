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

    RESOURCE_MAPPING_KEY      = "_lm.resourceId".freeze
    DEVICELESS_KEY_SERVICE    = "resource.service.name".freeze
    DEVICELESS_KEY_NAMESPACE  = "resource.service.namespace".freeze

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

    config_param :proxy_host,  :string, :default => nil

    config_param :proxy_port,  :string, :default => nil
    
    config_param :proxy_user,  :string, :default => nil

    config_param :proxy_pass,  :string, :default => nil

    config_param :proxy_use_ssl,  :bool, :default => false

    config_param :proxy_ignore_cert_errors,  :bool, :default => false
  
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
        if event != nil
          events.push(event)
        end
      end
      send_batch(events)
    end

    def process_record(tag, time, record)
      resource_map = {}
      lm_event = {}

      if @include_metadata
        lm_event = get_metadata(record)
      end

      if !@device_less_logs
        # With devices
        if record[RESOURCE_MAPPING_KEY] == nil
            @resource_mapping.each do |key, value|
              k = value
              nestedVal = record
              key.to_s.split('.').each { |x| nestedVal = nestedVal[x] }
              if nestedVal != nil
                resource_map[k] = nestedVal
              end
            end
          lm_event[RESOURCE_MAPPING_KEY] = resource_map
        else
          lm_event[RESOURCE_MAPPING_KEY] = record[RESOURCE_MAPPING_KEY]
        end
      else
        # Device less
        if record[DEVICELESS_KEY_SERVICE]==nil
          log.error "When device_less_logs is set \'true\', record must have \'service\'. Ignoring this event #{lm_event}."
          return nil
        else
          lm_event[DEVICELESS_KEY_SERVICE] = encode_if_necessary(record[DEVICELESS_KEY_SERVICE])
          if record[DEVICELESS_KEY_NAMESPACE]!=nil
            lm_event[DEVICELESS_KEY_NAMESPACE] = encode_if_necessary(record[DEVICELESS_KEY_NAMESPACE]) 
          end
        end
      end

      if record["timestamp"] != nil
        lm_event["timestamp"] = record["timestamp"]
      else
        lm_event["timestamp"] = Time.at(time).utc.to_datetime.rfc3339
      end

      lm_event["message"] = encode_if_necessary(record["message"])

      return lm_event
    end

    def get_metadata(record)
      #if encoding is not defined we will skip going through each key val 
      #and return the whole record for performance reasons in case of a bulky record.
      if @force_encoding == "" 
        return record
      else
        lm_event = {}
        record.each do |key, value| 
          lm_event["#{key}"] = get_encoded_string(value)
        end
        return lm_event
      end
    end

    def encode_if_necessary(str)
      if @force_encoding != ""
        return get_encoded_string(str)
      else
        return str
      end
    end

    def get_encoded_string(str)
      return str.force_encoding(@force_encoding).encode("UTF-8")
    end

    def send_batch(events)
      url = "https://#{@company_name}.logicmonitor.com/rest/log/ingest"
      body = events.to_json
      uri = URI.parse(url)
      
      if @debug
        log.info "Sending #{events.length} events to logic monitor at #{url}"
        log.info "Request json #{body}"
      end

      #Check if proxy settings were passed, if so open HTTP connection using supplied proxy settings
      if (!@proxy_host.nil? && !@proxy_port.nil?)
        if @debug
          log.info "Using proxy settings #{proxy_host}:#{proxy_port} to send events to logicmonitor"
        end
        http = Net::HTTP.new(uri.host, uri.port, proxy_host, proxy_port, proxy_user, proxy_pass)
        if @proxy_ignore_cert_errors
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        http.use_ssl = proxy_use_ssl
      else
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
      end

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

      #Attempt sending request, if we get an exception, log the error. Could be an issue with proxy settings specified
      begin
        resp = http.request(request)

        if @debug || (!resp.kind_of? Net::HTTPSuccess)
          log.info "Status code:#{resp.code} Request Id:#{resp.header['x-request-id']}"
        end
        if (resp.kind_of? Net::HTTPMultiStatus)
            log.info "Partial messages accepted by Logicmonitor. This might have been caused by a failure in resource mapping or logs older than 3 hrs."
        end
      rescue Net::HTTPServerException => e
        log.info "Error submitting request:#{e}"
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