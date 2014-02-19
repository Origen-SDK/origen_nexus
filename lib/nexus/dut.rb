module Nexus
  # This is a dummy DUT model that provides an example of how 
  # the Nexus module should be included
  class DUT

    # Include the Nexus protocol
    include Nexus

    include RGen::Callbacks
    include RGen::Pins
    include RGen::Registers

    NEXUS_CONFIG = {
      :tclk_format => :rh,
      :tclk_multiple => 1
    }

    def initialize(options={})
      NEXUS_CONFIG[:tclk_format] = options[:tclk_format] if options[:tclk_format]
      NEXUS_CONFIG[:tclk_multiple] = options[:tclk_multiple] if options[:tclk_multiple]

      # Any DUT that uses Nexus must declare these pins
      # (or an alias)

      # OnCE Debug Port pins
      add_pin :tclk
      add_pin :tms
      add_pin :tdi
      add_pin :tdo

      # Define dummy register to use to test Nexus
      # driver for test purposes
      reg :testme32, 0x007a, :size => 32 do
        bit 31..16, :portB
        bit 15..8,  :portA
        bit 0,      :enable
      end

      reg :status32, 0x007b, :size => 32 do
        bit 31..16,  :fail_vals, :writable => false
        bit 0,       :error_bit, :writable => false
      end

      reg :testme16, 0x007c, :size => 16 do
        bit 15..8, :portD
        bit 7..0,  :portC
      end

    end


    def startup(options)
      $tester.set_timeset("tp0", 60)
    end

    def read_register(reg, options={})
     # $tester.dont_compress = true
      nexus.read_register(reg, options)
     # $tester.dont_compress = false
    end

    def write_register(reg, options={})
     # $tester.dont_compress = true
      nexus.write_register(reg, options)
     # $tester.dont_compress = false
    end

    def tclk_format
      NEXUS_CONFIG[:tclk_format]
    end

    def tclk_multiple
      NEXUS_CONFIG[:tclk_multiple]
    end

  end

  # used to test that Nexus will use the host's
  # JTAG if present
  class DUTWithJTAG
    include Nexus
     
    # basically if this attribute available then shows that DUTWithJTAG's
    # JTAG driver was used instead of imported JTAG driver class.
    def jtag
      :used_host_jtag
    end

  end


end
