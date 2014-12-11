module Nexus
  # Returns an instance of the Nexus::Driver
  def nexus
    @nexus ||= Driver.new(self)
  end
end
