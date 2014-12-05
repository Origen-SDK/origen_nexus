require 'rgen'
require 'jtag'
require_relative '../config/application.rb'
require_relative '../config/environment.rb'


module Nexus
  # Returns an instance of the Nexus::Driver
  def nexus
    @nexus ||= Driver.new(self)
  end
end
