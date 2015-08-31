# This file should be used to extend the origen command line tool with tasks 
# specific to your application.
# The comments below should help to get started and you can also refer to
# lib/origen/commands.rb in your Origen core workspace for more examples and 
# inspiration.
#
# Also see the official docs on adding commands:
#   http://origen.freescale.net/origen/latest/guides/custom/commands/

# Map any command aliases here, for example to allow origen -x to refer to a 
# command called execute you would add a reference as shown below: 
aliases ={
#  "-x" => "execute",
}

# The requested command is passed in here as @command, this checks it against
# the above alias table and should not be removed.
@command = aliases[@command] || @command

# Now branch to the specific task code
case @command

# Here is an example of how to implement a command, the logic can go straight
# in here or you can require an external file if preferred.
#when "execute"
#  puts "Executing something..."
#  require "commands/execute"    # Would load file lib/commands/execute.rb
#  # You must always exit upon successfully capturing a command to prevent 
#  # control flowing back to Origen
#  e it 0
when "specs"
  require "rspec"
  exit RSpec::Core::Runner.run(['spec'])

when "examples", "test"
  Origen.load_application
  status = 0

  # Pattern generator tests
  # (btw, %w() is ruby shorthand for making an array of strings)
   ARGV = %w(regression.list -t debug_RH1 -r approved)
   load "#{Origen.top}/lib/origen/commands/generate.rb"
   ARGV = %w(regression.list -t debug_RL1 -r approved)
   load "#{Origen.top}/lib/origen/commands/generate.rb"
   ARGV = %w(regression.list -t debug_RH4 -r approved)
   load "#{Origen.top}/lib/origen/commands/generate.rb"
   ARGV = %w(regression.list -t debug_RL4 -r approved)
   load "#{Origen.top}/lib/origen/commands/generate.rb"

  # check if nothing changed or nothing added
  if Origen.app.stats.changed_files == 0 && 
     Origen.app.stats.new_files == 0 &&
     Origen.app.stats.changed_patterns == 0 &&
     Origen.app.stats.new_patterns == 0
 
    # report examples having passed
    Origen.app.stats.report_pass
  else
    # report examples having failed
    Origen.app.stats.report_fail
    status = 1
  end
  puts
  if @command == "test"
    Origen.app.unload_target!
    require "rspec"
    result = RSpec::Core::Runner.run(['spec'])
    status = status == 1 ? 1 : result
  end
  exit status

# Always leave an else clause to allow control to fall back through to the
# Origen command handler.
# You probably want to also add the command details to the help shown via
# origen -h, you can do this be assigning the required text to @application_commands
# before handing control back to Origen. Un-comment the example below to get started.
else
  @application_commands = <<-EOT
 specs         Run the specs (tests), -c will enable coverage
 examples      Run the examples (tests), -c will enable coverage
 test          Run both specs and examples, -c will enable coverage
  EOT

end 
