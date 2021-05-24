# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "coach/version"

Gem::Specification.new do |spec|
  spec.name          = "coach"
  spec.version       = Coach::VERSION
  spec.summary       = "Alternative controllers built with middleware"
  spec.authors       = %w[GoCardless]
  spec.homepage      = "https://github.com/gocardless/coach"
  spec.email         = %w[developers@gocardless.com]
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.5"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(%r{^spec/})
  spec.require_paths = ["lib"]
  spec.executables   = ["coach"]

  spec.add_dependency "actionpack", ">= 4.2"
  spec.add_dependency "activesupport", ">= 4.2"
  spec.add_dependency "commander", "~> 4.5"

  spec.add_development_dependency "gc_ruboconfig", "= 2.18.0"
  spec.add_development_dependency "pry", "~> 0.10"
  spec.add_development_dependency "rspec", "~> 3.2"
  spec.add_development_dependency "rspec-its", "~> 1.2"
  spec.add_development_dependency "rspec_junit_formatter", "~> 0.4.0"
end
