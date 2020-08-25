# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Logic Monitor (https://www.logicmonitor.com).
# Copyright 2020 Logic Monitor, Inc.

Gem::Specification.new do |spec|
  spec.name                           = "fluent-plugin-lm-logs"
  spec.version                        = '0.0.6'
  spec.authors                        = ["Logic Monitor"]
  spec.email                          = "rubygems@logicmonitor.com"
  spec.summary                        = "Logic Monitor logs fluentd output plugin"
  spec.description                    = "This output plugin sends fluentd records to the configured LogicMonitor account."
  spec.homepage                       = "https://www.logicmonitor.com"
  spec.license                        = "Apache-2.0"

  spec.metadata["source_code_uri"]    = "https://github.com/logicmonitor/lm-logs-fluentd"
  spec.metadata["documentation_uri"]  = "https://www.rubydoc.info/gems/lm-logs-fluentd"

  spec.files         = [".gitignore", "Gemfile", "LICENSE", "README.md", "Rakefile", "fluent-plugin-lm-logs.gemspec", "lib/fluent/plugin/out_lm.rb"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = '>= 2.0.0'

  spec.add_runtime_dependency "fluentd", [">= 1", "< 2"]
end