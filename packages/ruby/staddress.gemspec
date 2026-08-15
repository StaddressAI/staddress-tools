# frozen_string_literal: true

require_relative "lib/staddress/version"

Gem::Specification.new do |spec|
  spec.name = "staddress"
  spec.version = Staddress::VERSION
  spec.authors = ["StaddressAI"]

  spec.summary = "Official Ruby client for Staddress AI address parsing API"
  spec.description = "Ruby SDK for the Staddress AI address parsing API " \
                     "(parse_address / parse_batch / get_usage). Zero runtime dependencies."
  spec.homepage = "https://staddress.com/api"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/StaddressAI/staddress-tools",
    "bug_tracker_uri" => "https://github.com/StaddressAI/staddress-tools/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "webmock", "~> 3.23"
end
