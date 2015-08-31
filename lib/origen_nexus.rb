require 'origen'
require_relative '../config/application.rb'
require_relative '../config/environment.rb'
require 'origen_jtag' # required for runtime dep gems

module OrigenNexus
  # Returns an instance of the Nexus::Driver
  def nexus
    @nexus ||= Driver.new(self)
  end
end
