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

    host = (record['host'] || record['hostname'] || '').to_s
    msg = (record['message'] || '').to_s
    program = (record['syslog_program'] || '').to_s
    tags = record['tags'] || []
    tag_down = tag&.downcase || ''

    host_down = host.downcase
    msg_down = msg.downcase
    program_down = program.downcase
    # From tag pattern (case-insensitive)
    return 'WindowsServer' if tag_down.include?('windows')
    return 'LinuxServer' if tag_down.include?('linux')
    return 'Kubernetes/Node' if tag_down.include?('k8s') || tag_down.include?('kubernetes')
    return 'Docker/Host' if tag_down.include?('docker')

    # Structured metadata
    return 'Kubernetes/Node' if record.key?('kubernetes')
    return 'Docker/Host' if record.key?('container_id') || record.dig('docker', 'container_id')
    return 'AWS/VirtualMachine' if host_down.start_with?('ip-') || msg_down.include?('amazon')
    return 'GCP/VirtualMachine' if host_down.include?('.c.') || host_down.include?('gcp')
    return 'Azure/VirtualMachine' if host_down.include?('cloudapp.net') || msg_down.include?('azure')
    return 'VMware/VirtualMachine' if msg_down.include?('vmware') || host_down.include?('vmware')

    return 'WindowsServer' if record.key?('EventID') || record.key?('ProviderName') || record.key?('Computer')
    return 'LinuxServer' if record.key?('syslog_facility') || program_down != ''

    return 'Firewall' if program_down.downcase.include?('firewalld') || msg_down.downcase.include?('iptables') || msg_down.include?('blocked by policy')
    return 'ACMEServer' if host_down.include?('acme') || msg_down.include?('ACME-Request') || tags.include?('acme')
    return 'WebServer' if msg_down.include?('nginx') || msg_down.include?('apache')
    return 'DatabaseServer' if msg_down.include?('mysql') || msg_down.include?('postgres') || msg_down.include?('oracle')

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
    return { runtime: 'vm', provider: provider_info[:provider], details: provider_info[:details] } if provider_info

    os = detect_os
    product = detect_product_info

    if product.downcase.include?('xen hvm domu') && os.downcase.include?('amazon')
      return { runtime: 'vm', provider: 'aws', details: { os: os, product: product } }
    end

    { runtime: 'physical', os: os, product: product }
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
