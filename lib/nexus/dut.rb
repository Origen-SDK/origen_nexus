module Nexus
  # This is a dummy DUT model that provides an example of how 
  # the Nexus module should be included
  class DUT

    # Include the Nexus protocol
    include Nexus

    include RGen::Callbacks
    include RGen::Pins
    include RGen::Registers

    def initialize
      # Any DUT that uses Nexus must declare these pins
      # (or an alias)

      # OnCE Debug Port pins
      add_pin :tclk
      add_pin :tms
      add_pin :tdi
      add_pin :tdo

      # Define dummy register to use to test Nexus
      # driver for test purposes
      add_reg32 :testme32, 0x007a,   :enable => {pos: 0},
                                     :portA =>  {pos: 8, bits: 8},
                                     :portB =>  {pos: 16, bits: 16}

      add_reg32 :status32, 0x007b,   :error_bit => {pos: 0, bits: 1, writable: false},
                                     :fail_vals => {pos: 16, bits: 16, writable: false}

      add_reg :testme16, 0x007c, 16, :portC => {pos: 0, bits: 8},
                                     :portD => {pos: 8, bits: 8}
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
