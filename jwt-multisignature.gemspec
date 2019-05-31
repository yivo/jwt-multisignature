# encoding: UTF-8
# frozen_string_literal: true

require_relative "lib/jwt-multisignature/version"

Gem::Specification.new do |s|
  s.name            = "jwt-multisignature"
  s.version         = JWT::Multisignature::VERSION
  s.author          = "Yaroslav Konoplov"
  s.email           = "eahome00@gmail.com"
  s.summary         = "Implements JWT with multiple signatures (RFC 7515)"
  s.description     = "The gem implements support of RFC 7515 providing easy way to create JWT and add/remove/verify signatures."
  s.homepage        = "https://github.com/yivo/jwt-multisignature"
  s.license         = "Apache-2.0"
  s.files           = `git ls-files -z`.split("\x0")
  s.test_files      = `git ls-files -z -- {test,spec,features}/*`.split("\x0")
  s.require_paths   = ["lib"]
  s.required_ruby_version = "~> 2.5"

  s.add_dependency             "jwt",           "~> 2.1"
  s.add_dependency             "activesupport", ">= 4.0", "< 6.0"
  s.add_development_dependency "bundler",       "~> 1.16"
end
