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
  spec.required_ruby_version = ">= 3.1"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.require_paths = ["lib"]
  spec.executables   = ["coach"]

  spec.add_dependency "actionpack", ">= 7.0"
  spec.add_dependency "activesupport", ">= 7.0"
  spec.add_dependency "commander", "~> 4.5"

  spec.metadata["rubygems_mfa_required"] = "true"
end
