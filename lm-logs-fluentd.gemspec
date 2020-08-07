Gem::Specification.new do |spec|
  spec.name          = "lm-logs-fluentd"
  spec.version       = '0.0.2'
  spec.authors       = ["LM"]

  spec.summary       = "Send logs to Logic Monitor"
  spec.description   = "Send logs to Logic Monitor"
  spec.homepage      = "https://github.com/logicmonitor/lm-logs-fluentd"
  spec.license       = "Apache"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage

  spec.files         = [".gitignore", "Gemfile", "LICENSE", "README.md", "Rakefile", "lm-logs-fluentd.gemspec", "lib/fluentd/plugin/out_lm.rb"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = '>= 2.0.0'

  spec.add_runtime_dependency "fluentd", "~> 0.12"
  spec.add_runtime_dependency "http", "< 3"
end