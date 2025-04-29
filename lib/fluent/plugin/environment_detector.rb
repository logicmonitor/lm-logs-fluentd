require 'net/http'
require 'timeout'
require 'json'

class EnvironmentDetector
  METADATA_TIMEOUT = 1

  def detect
    if running_in_kubernetes?
      { runtime: 'kubernetes' }.merge(detect_node_info)
    elsif running_in_docker?
      { runtime: 'docker' }.merge(detect_node_info)
    else
      detect_host_environment
    end
  end

  private

  def running_in_kubernetes?
    ENV.key?('KUBERNETES_SERVICE_HOST') || ENV.key?('KUBERNETES_PORT')
  end

  def running_in_docker?
    return true if ENV['container'] == 'docker'

    cgroup_content = File.read('/proc/1/cgroup') rescue ''
    return true if cgroup_content.include?('docker') || cgroup_content.include?('containerd')

    File.exist?('/.dockerenv')
  end

  def detect_host_environment
    provider_info = detect_cloud_provider
    if provider_info
      { runtime: 'vm', provider: provider_info[:provider], details: provider_info[:details] }
    else
      { runtime: 'physical', os: detect_os, product: detect_product_info }
    end
  end

  def detect_cloud_provider
    azure_metadata || aws_metadata || gcp_metadata
  end

  def azure_metadata
    url = 'http://169.254.169.254/metadata/instance?api-version=2021-02-01'
    headers = { 'Metadata' => 'true' }
    response = fetch_metadata(url, headers)
    return unless response

    json = JSON.parse(response) rescue {}
    {
      provider: 'azure',
      details: {
        vm_id: json.dig('compute', 'vmId'),
        location: json.dig('compute', 'location'),
        name: json.dig('compute', 'name'),
        vm_size: json.dig('compute', 'vmSize')
      }
    }
  end

  def aws_metadata
    url = 'http://169.254.169.254/latest/meta-data/instance-id'
    response = fetch_metadata(url)
    return unless response

    { provider: 'aws', details: { instance_id: response.strip } }
  end

  def gcp_metadata
    url = 'http://169.254.169.254/computeMetadata/v1/instance/id'
    headers = { 'Metadata-Flavor' => 'Google' }
    response = fetch_metadata(url, headers)
    return unless response

    { provider: 'gcp', details: { instance_id: response.strip } }
  end

  def fetch_metadata(url, headers = {}, timeout_sec = METADATA_TIMEOUT)
    uri = URI(url)

    Timeout.timeout(timeout_sec) do
      req = Net::HTTP::Get.new(uri)
      headers.each { |k, v| req[k] = v }

      res = Net::HTTP.start(uri.host, uri.port, open_timeout: timeout_sec, read_timeout: timeout_sec) do |http|
        http.request(req)
      end

      return res.body if res.is_a?(Net::HTTPSuccess)
    end
  rescue Timeout::Error, SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, EOFError
    nil
  end

  def detect_os
    if File.exist?('/etc/os-release')
      os_info = {}
      File.foreach('/etc/os-release') do |line|
        key, value = line.strip.split('=', 2)
        os_info[key] = value&.gsub('"', '')
      end
      "#{os_info['NAME']} #{os_info['VERSION']}"
    else
      `uname -a`.strip
    end
  rescue
    'unknown'
  end

  def detect_product_info
    vendor = read_file('/sys/class/dmi/id/sys_vendor')
    product = read_file('/sys/class/dmi/id/product_name')
    "#{vendor} #{product}".strip
  rescue
    'unknown'
  end

  def read_file(path)
    File.read(path).strip if File.exist?(path)
  end

  def detect_node_info
    {
      node_os: detect_os,
      node_product: detect_product_info
    }
  end

end
