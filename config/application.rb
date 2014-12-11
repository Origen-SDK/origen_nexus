class Nexus_Application < RGen::Application

  # This file contains examples of some of the most common configuration options,
  # to see a real production example from a large application have a look at:
  # sync://sync-15088:15088/Projects/common_tester_blocks/blocks/C90TFS_NVM_tester/tool_data/rgen_v2/config/application.rb

  # This information is used in headers and email templates, set it specific
  # to your application
  config.name     = "Nexus"
  config.initials = "Nexus"
  config.vault    = "sync://sync-15088:15088/Projects/common_tester_blocks/rgen_blocks/protocol/Nexus/tool_data/rgen" 

  # Force naming of gem
  self.name = "rgen_nexus"

  # To enable deployment of your documentation to a web server (via the 'rgen web'
  # command) fill in these attributes. The example here is configured to deploy to
  # the rgen.freescale.net domain, which is an easy option if you don't have another
  # server already in mind. To do this you will need an account on CDE and be a member
  # of the 'rgen' group.
  config.web_directory = "/proj/.web_rgen/html/nexus"
  config.web_domain = "http://rgen.freescale.net/nexus"

  # You can map moo numbers to targets here, this allows targets to be selected via
  # rgen t <moo>
  #config.production_targets = {
  #  "1m79x" => "production",
  #}


  # Versioning is based on a timestamp by default, if you would rather use semantic
  # versioning, i.e. v1.0.0 format, then set this to true.
  # In parallel go and edit config/version.rb to enable the semantic version code.
  config.semantically_version = true

  # An example of how to set application specific LSF parameters
  #config.lsf.project = "msg.te"
  
  # An exmaple of how to specify a prefix to add to all generated patterns
  #config.pattern_prefix = "nvm"

  # An example of how to add header comments to all generated patterns
  #config.pattern_header do
  #  cc "This is a pattern created by the example rgen application"
  #end

  # By default all generated output will end up in ./output.
  # Here you can specify an alternative directory entirely, or make it dynamic such that
  # the output ends up in a setup specific directory. 
  #config.output_directory do
  #  "#{RGen.root}/output/#{$dut.class}"
  #end

  # Similary for the reference files, generally you want to setup the reference directory
  # structure to mirror that of your output directory structure.
  #config.reference_directory do
  #  "#{RGen.root}/.ref/#{$dut.class}"
  #end

  # Run code coverage when deploying the web site
  def before_deploy_site
    Dir.chdir RGen.root do
      system "rgen examples -c"
      system "rgen specs -c"
      dir = "#{RGen.root}/web/output/coverage"
      FileUtils.remove_dir(dir, true) if File.exists?(dir)
      system "mv #{RGen.root}/coverage #{dir}"
    end
  end

  # To automatically deploy your documentation after every tag use this code
  def after_release_email(tag, note, type, selector, options)
    deployer = RGen.app.deployer
    if deployer.running_on_cde? && deployer.user_belongs_to_rgen?
      command = "rgen web compile --remote --api"
      if RGen.app.version.production?
        command += " --archive #{RGen.app.version}"
      end
      Dir.chdir RGen.root do
        system command
      end
    end 
  end

=begin
  # To enabled source-less pattern generation create a class (for example PatternDispatcher)
  # to generate the pattern. This should return false if the requested pattern has been
  # dispatched, otherwise RGen will proceed with looking up a pattern source as normal.
  #def before_pattern_lookup(requested_pattern)
  #  PatternDispatcher.new.dispatch_or_return(requested_pattern)
  #end

  # If you use pattern iterators you may come accross the case where you request a pattern
  # like this:
  #   rgen g example_pat_b0.atp
  #
  # However it cannot be found by RGen since the pattern name is actually example_pat_bx.atp
  # In the case where the pattern cannot be found RGen will pass the name to this translator
  # if it exists, and here you can make any substitutions to help RGen find the file you 
  # want. In this example any instances of _b\d, where \d means a number, are replaced by
  # _bx.
  #config.pattern_name_translator do |name|
  #  name.gsub(/_b\d/, "_bx")
  #end

  # If you want to use pattern iterators, that is the ability to generate multiple pattern
  # variants from a single source file, then you can define the required behavior here.
  # The examples below implement some of the iterators that were available in RGen 1,
  # you can remove them if you don't want to use them, or of course modify or add new 
  # iterators specific to your application logic.
  
  # By setting iterator
  config.pattern_iterator do |iterator|
    # Define a key that you will use to enable this in a pattern, here the iterator
    # can be enabled like this: Pattern.create(:by_setting => [1,2,3]) do
    iterator.key = :by_setting

    # The value passed from the pattern via the key comes in here as the first
    # argument, the name applied here can be anything, but settings seem reasonable since
    # an array of setting values is expected.
    # The last argument &pattern is mandatory and represents the pattern block (the bit contained
    # within Pattern.create do ... end)
    iterator.loop do |settings, &pattern|
      # Implement the loop however you like, here we loop for each value in the array
      settings.each do |setting|
        # Now call the pattern passing in the setting argument, this would be captured
        # in the pattern like this:
        #   Pattern.create do |setting|
        pattern.call(setting)
      end
    end

    # Each pattern iteration needs a unique name, otherwise RGen will simply overwrite 
    # the same output file each time.
    # The base pattern name and the pattern argument, in this case the setting, will be
    # passed in here and whatever is returned is what will be used as the name.
    iterator.pattern_name do |name, setting|
      # Substitute _x in the name with the setting, _1, _2, etc.
      name.gsub("_x", "_#{setting}")
    end
  end
=end

end
