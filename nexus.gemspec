# coding: utf-8
config = File.expand_path('../config', __FILE__)
require "#{config}/version"

Gem::Specification.new do |spec|
  spec.name          = "nexus"
  spec.version       = Nexus::VERSION
  spec.authors       = ["Daniel Hadad"]
  spec.email         = ["ra6854@freescale.com"]
  spec.summary       = "This plugin provides an RGen API to use the Nexus interface."
  spec.homepage      = "http://rgen.freescale.net/nexus"

  spec.required_ruby_version     = '>= 1.9.3'
  spec.required_rubygems_version = '>= 1.8.11'

  # Only the files that are hit by these wildcards will be included in the
  # packaged gem, the default should hit everything in most cases but this will
  # need to be added to if you have any custom directories
  spec.files         = Dir["lib/**/*.rb", "templates/**/*", "config/**/*.rb",
                           "bin/*", "lib/tasks/**/*.rake", "pattern/**/*.rb",
                           "program/**/*.rb"
                          ]
  spec.executables   = []
  spec.require_paths = ["lib"]

  # Add any gems that your plugin needs to run within a host application
  spec.add_runtime_dependency "rgen_core", ">= 2.5.0.pre14"
  spec.add_runtime_dependency "jtag", ">= 0.10.0"

end
