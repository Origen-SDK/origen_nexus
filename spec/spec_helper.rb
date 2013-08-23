$VERBOSE=nil  # Don't care about world writable dir warnings and the like

require "rgen"
require "#{RGen.top}/spec/format/rgen_formatter"
# also could add later: require "#{RGen.top}/spec/shared/common_helpers"

RGen.app.require_environment!
require "#{RGen.root}/config/development.rb"

RSpec.configure do |config|
  config.formatter = RGenFormatter
end
