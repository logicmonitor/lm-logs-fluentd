Gem::Specification.new do |spec|
  spec.name          = "lm-logs-fluentd"
  spec.version       = '0.0.1'
  spec.authors       = ["LM"]

  spec.summary       = "Send logs to Logic Monitor"
  spec.description   = "Send logs to Logic Monitor"
  spec.homepage      = "https://github.com/logicmonitor/lm-logs-fluentd"
  spec.license       = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]
  spec.required_ruby_version = '>= 2.0.0'

  spec.add_runtime_dependency "fluentd", "~> 0.12"
  spec.add_runtime_dependency "http", "< 3"

  spec.add_development_dependency "bundler", "~> 2.0.1"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "webmock", "~> 2.1"
  spec.add_development_dependency "test-unit"
end
