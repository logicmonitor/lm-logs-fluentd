require 'fluent/output'
require 'date'
require 'time'
require 'uri'
require 'digest'
require 'json'
require 'openssl'
require 'base64'
require 'net/http'
require 'net/http/persistent'
require 'net/https'
require('zlib')

require_relative "version"



module Fluent
  module Plugin
    class LmOutput < Fluent::Plugin::Output
      Fluent::Plugin.register_output('lm', self)

      RESOURCE_MAPPING_KEY      = "_lm.resourceId".freeze
      DEVICELESS_KEY_SERVICE    = "resource.service.name".freeze
      DEVICELESS_KEY_NAMESPACE  = "resource.service.namespace".freeze

      # config_param defines a parameter. You can refer a parameter via @path instance variable

      config_param :access_id,  :string, :default => nil

      config_param :access_key,  :string, :default => nil, secret: true

      config_param :company_name,  :string, :default => "company_name"

      config_param :resource_mapping,  :hash, :default => {"host": "system.hostname", "hostname": "system.hostname"}

      config_param :debug,  :bool, :default => false

      config_param :include_metadata,  :bool, :default => false

      config_param :force_encoding,  :string, :default => ""

      config_param :compression,  :string, :default => ""

      config_param :log_source,  :string, :default => "lm-logs-fluentd"

      config_param :version_id,  :string, :default => "version_id"

      config_param :device_less_logs,  :bool, :default => false

      config_param :http_proxy,   :string, :default => nil

      config_param :company_domain ,  :string, :default => "logicmonitor.com"

      config_param :resource_type,  :string, :default => ""
      # Use bearer token for auth.
      config_param :bearer_token, :string, :default => nil, secret: true

      # This method is called before starting.
      # 'conf' is a Hash that includes configuration parameters.
      # If the configuration is invalid, raise Fluent::ConfigError.
      def configure(conf)
        super
      end

      def multi_workers_ready?
        true
      end

      # This method is called when starting.
      # Open sockets or files here.
      def start
        super
        configure_auth
        proxy_uri = :ENV
        if @http_proxy
          proxy_uri = URI.parse(http_proxy)
        elsif ENV['HTTP_PROXY'] || ENV['http_proxy']
          log.info("Using HTTP proxy defined in environment variable")
        end
        @http_client = Net::HTTP::Persistent.new name: "fluent-plugin-lm-logs", proxy: proxy_uri
        @http_client.override_headers["Content-Type"] = "application/json"
        @http_client.override_headers["User-Agent"] = log_source + "/" + LmLogsFluentPlugin::VERSION
        @url = "https://#{@company_name}.#{@company_domain}/rest/log/ingest"
        @uri = URI.parse(@url)
      end

      def configure_auth
        @use_bearer_instead_of_lmv1 = false
        if is_blank(@access_id) || is_blank(@access_key)
          log.info "Access Id or access key blank / null. Using bearer token for authentication."
          @use_bearer_instead_of_lmv1 = true
        end
        if @use_bearer_instead_of_lmv1 && is_blank(@bearer_token)
          log.error "Bearer token not specified. Either access_id and access_key both or bearer_token must be specified for authentication with Logicmonitor."
          raise ArgumentError, 'No valid authentication specified. Either access_id and access_key both or bearer_token must be specified for authentication with Logicmonitor.'
        end
      end
      # This method is called when shutting down.
      # Shutdown the thread and close sockets or files here.
      def shutdown
        super
        @http_client.shutdown
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

      def formatted_to_msgpack_binary?
        true
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

        if !is_blank(@resource_type)
          lm_event['_resource.type'] = resource_type
        end

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
        body = events.to_json

        if @debug
          log.info "Sending #{events.length} events to logic monitor at #{@url}"
          log.info "Request json #{body}"
        end

        request = Net::HTTP::Post.new(@uri.request_uri)
        request['authorization'] = generate_token(events)

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

        resp = @http_client.request @uri, request
        if @debug || resp.kind_of?(Net::HTTPMultiStatus) || !resp.kind_of?(Net::HTTPSuccess)
          log.info "Status code:#{resp.code} Request Id:#{resp.header['x-request-id']} message:#{resp.body}"
        end
      end


      def generate_token(events)

        if @use_bearer_instead_of_lmv1
          return "Bearer #{@bearer_token}"
        else
          timestamp = DateTime.now.strftime('%Q')
          signature = Base64.strict_encode64(
              OpenSSL::HMAC.hexdigest(
                  OpenSSL::Digest.new('sha256'),
                  @access_key,
                  "POST#{timestamp}#{events.to_json}/log/ingest"
              )
          )
          return "LMv1 #{@access_id}:#{signature}:#{timestamp}"
        end
      end

      def is_blank(str)
        if str.nil? || str.to_s.strip.empty?
          return true
        else
          return false
        end
      end

    end
  end
end
