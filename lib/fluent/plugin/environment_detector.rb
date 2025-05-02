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

  def format_environment(env_info)
    runtime = env_info[:runtime]
    provider = env_info[:provider] if env_info.key?(:provider)

    case runtime
    when 'kubernetes'
      'Kubernetes/Node'
    when 'docker'
      'Docker/Host'
    when 'vm'
      case provider&.downcase
      when 'azure'
        'Azure/VirtualMachine'
      when 'aws'
        'AWS/EC2'
      when 'gcp'
        'GCP/ComputeEngine'
      else
        'Unknown/VirtualMachine'
      end
    when 'physical'
      os = env_info[:os] || 'UnknownOS'
      product = env_info[:product] || 'UnknownHardware'
      "#{os} / #{product}"
    else
      'UnknownEnvironment'
    end
  end

  def infer_resource_type(record, tag = nil)
    return record['resource_type'] if record['resource_type']

    host = record['host'] || record['hostname'] || ''
    msg = record['message'] || ''
    program = record['syslog_program'] || ''
    tags = record['tags'] || []

    # From tag pattern
    if tag&.include?('windows')
      return 'WindowsServer'
    elsif tag&.include?('linux')
      return 'LinuxServer'
    elsif tag&.include?('k8s') || tag&.include?('kubernetes')
      return 'Kubernetes/Node'
    elsif tag&.include?('docker')
      return 'Docker/Host'
    end

    # Structured metadata
    return 'Kubernetes/Node' if record.key?('kubernetes')
    return 'Docker/Host' if record.key?('container_id') || record.dig('docker', 'container_id')
    return 'AWS/EC2' if host.start_with?('ip-') || msg.include?('amazon')
    return 'GCP/ComputeEngine' if host.include?('.c.') || host.include?('gcp')
    return 'Azure/VirtualMachine' if host.include?('cloudapp.net') || msg.include?('azure')
    return 'VMware/VirtualMachine' if msg.include?('vmware') || host.include?('vmware')

    return 'WindowsServer' if record.key?('EventID') || record.key?('ProviderName') || record.key?('Computer')
    return 'LinuxServer' if record.key?('syslog_facility') || program != ''

    return 'Firewall' if program.downcase.include?('firewalld') || msg.downcase.include?('iptables') || msg.include?('blocked by policy')
    return 'ACMEServer' if host.include?('acme') || msg.include?('ACME-Request') || tags.include?('acme')
    return 'WebServer' if msg.include?('nginx') || msg.include?('apache')
    return 'DatabaseServer' if msg.include?('mysql') || msg.include?('postgres') || msg.include?('oracle')

    'Unknown'
  end

  private

  def running_in_kubernetes?
    ENV.key?('KUBERNETES_SERVICE_HOST') || ENV.key?('KUBERNETES_PORT')
  end

  def running_in_docker?
    return true if ENV['container'] == 'docker'
    cgroup = File.read('/proc/1/cgroup') rescue ''
    return true if cgroup.include?('docker') || cgroup.include?('containerd')
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

  def detect_node_info
    { node_os: detect_os, node_product: detect_product_info }
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
      res = Net::HTTP.start(uri.host, uri.port, open_timeout: timeout_sec, read_timeout: timeout_sec) { |http| http.request(req) }
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
    elsif RUBY_PLATFORM.include?('darwin')
      product_name = `sw_vers -productName`.strip
      product_version = `sw_vers -productVersion`.strip
      "#{product_name} #{product_version}"
    else
      `uname -a`.strip
    end
  rescue
    'unknown'
  end

  def detect_product_info
    if File.exist?('/sys/class/dmi/id/sys_vendor') && File.exist?('/sys/class/dmi/id/product_name')
      vendor = read_file('/sys/class/dmi/id/sys_vendor')
      product = read_file('/sys/class/dmi/id/product_name')
      "#{vendor} #{product}".strip
    elsif RUBY_PLATFORM.include?('darwin')
      model = `system_profiler SPHardwareDataType | awk '/Model Identifier/ { print $3 }'`.strip
      model.empty? ? 'Mac' : model
    else
      'unknown'
    end
  rescue
    'unknown'
  end

  def read_file(path)
    File.read(path).strip if File.exist?(path)
  end
end
