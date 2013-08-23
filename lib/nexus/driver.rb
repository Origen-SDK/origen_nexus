module Nexus
  class Driver

    # Include JTAG driver instance to fall back on (if owner doesn't have)
    include JTAG

    # Include registers as Nexus has its own registers
    include RGen::Registers

    alias :local_jtag :jtag

    # Returns the underlying JTAG driver.  If the owner has its own JTAG driver
    # then this will be returned, otherwise it will be a fall back driver included
    # by the Nexus module.
    def jtag
      owner.respond_to?(:jtag) ? owner.jtag : local_jtag
    end

    # Returns the object that included the Nexus module,
    # should always be the top-level model
    attr_reader :owner

    # OnCE Command Register (OCMD) width in bits
    # OnCE (On-Chip Emulation)
    attr_reader :once_ocmd_width
    
    # The OnCE Nexus access instruction (NEXUS-ACCESS)
    # OnCE command value to enable Nexus
    attr_reader :once_nexus_access_instr

    # The OnCE bypass instruction (BYPASS)
    # OnCE command value to bypass OnCE
    attr_reader :once_bypass_instr

    # Nexus command width
    # width of commands used in first DR pass to read/write
    # a Nexus register
    attr_reader :nexus_command_width


    def initialize(owner, options={})

      # Doesn't seem to be the need to vary this on a per SoC basis
      # this may change down the road

      @once_ocmd_width = 10
      @once_nexus_access_instr = 0b0001111100
      @once_bypass_instr = 0b0001111111
      @nexus_command_width = 8

      # Define nexus registers
      define_nexus_registers

      @owner = owner

    end

    # This proxies all pin requests from our local JTAG driver to
    # our parent DUT model
    def pin(*args)
      owner.pin(*args)
    end
    alias :pins :pin

    # Define Nexus registers
    # For now only those related to RWA will be defined.
    # RWA (read/write access) provides DMA-like access to memory-mapped resources on
    # the AHB system bus either while the processor is halted or during runtime.
    def define_nexus_registers
      # Each register has a Nexus Opcode, which we will use as 'address' below, and 
      #  corresponding read addresses and write addresses
      #  DDHH not sure yet how to use the latter yet
      #DDHH address of the register depends on whether you are writing to it or reading it!


      # RWCS - Read/Write Access Control Register
      #        read addr = 0x0E, write addr = 0x0F
      add_reg32 :rwcs, 0x0E,  :ac => {pos: 31},
                              :rw => {pos: 30},
                              :sz => {pos: 27, bits: 3},
                              :map => {pos: 24, bits: 3},
                              :pr => {pos: 22, bits: 2},
                              :cnt => {pos: 2, bits: 14},
                              :err => {pos: 1, :writable =>  false},
                              :dv => {pos: 0, :writable =>  false}

      # RWD - Read/Write Access Data
      #       read addr = 0x12, write addr = 0x13
      add_reg32 :rwa,  0x12, :addr => {pos: 0, bits: 32}

      # RWD - Read/Write Access Data
      #       read addr = 0x14, write addr = 0x15
      add_reg32 :rwd,  0x14, :data => {pos: 0, bits: 32}

    end

    # Enable Nexus module
    # Loads NEXUS-ACCESS instruction into JTAG Instruction
    # Register (OnCE OCMD register).
    # repeated calls will not generate vectors if the instruction
    # is already loaded
    # 
    # Optionally also accepts a block to allow temporary Nexus access
    #
    #   nexus.enable_nexus_access do
    #      # Do something with nexus enabled
    #   end
    #   # Nexus access disabled
    #
    def enable_nexus_access
      if @ir_reg_value != once_nexus_access_instr
        log "Enable Nexus Access: OnCE_Send(#{once_ocmd_width}, 0x%02X)" % [ once_nexus_access_instr ]
        jtag.write_ir once_nexus_access_instr, :size => once_ocmd_width
        @ir_reg_value = once_nexus_access_instr
      end
      if block_given?
        yield
        disable_once
      end
    end

    # Disable OnCE
    def disable_once
      if @ir_reg_value != once_bypass_instr
        log "Bypass OnCE: OnCE_Send(#{once_ocmd_width}, 0x%02X)" % [ once_bypass_instr ]
        jtag.write_ir once_bypass_instr, :size => once_ocmd_width
        @ir_reg_value = once_bypass_instr
      end
    end

    # Write a given Nexus register
    def write_nexus_register(id, options={})
      options = { :reg_data => :default, # default use value from register itself
                  :write => true,        # whether to write or read
                }.merge(options)

      if reg(id).respond_to?(:address)
        addr = reg(id).address
        if options[:write] then addr = addr + 1 end # offset address by 1 since writing
        size = reg(id).size         # get size of register
        if options[:reg_data] == :default
          data = reg(id).data
        else
          data = options[:reg_data]
        end
      else
        raise "ERROR! Invalid register passed to write_nexus_register\n"
      end

      if options[:write]
        log "Write Nexus Reg: #{id.to_s.upcase} at 0x%04X with 0x%08X" % [ addr, data ]
      else
        log "Read Nexus Reg: #{id.to_s.upcase} at 0x%04X with 0x%08X" % [ addr, data ]
      end

      # first pass : select register via nexus command
      log "OnCE_Send(#{nexus_command_width}, 0x%02X)" % [ addr ]
      jtag.write_dr addr, :size => nexus_command_width

      if options[:write]
        # second pass : pass data to register
        log "OnCE_Send(#{size}, 0x%08X)" % [ data ]
        jtag.write_dr data, :size => size
      else
        # second pass : read data from register
        log "OnCE_Read(#{size}, 0x%08X)" % [ data ]
        jtag.read_dr data, :size => size
      end

    end

    # Read a given Nexus register
    def read_nexus_register(id, options={})
      write_nexus_register(id, options.merge(:write => false))
    end


    # Write a memory-mapped resource
    # for now only supports 32-bit data
    def single_write_access(address, data, options={})
      options={:write => true,    # whether to write or read the register
              }.merge(options)

      enable_nexus_access

      # Send command to write RWA reg
      # Send address value to RWA reg 
      write_nexus_register(:rwa, :reg_data => address)

      # Send command to write RWCS reg
      # Send settings to RWCS
      reg(:rwcs).bits(:ac).write(1)
      reg(:rwcs).bits(:rw).write(options[:write]? 1: 0)
      reg(:rwcs).bits(:sz).write(0b010)   # word size = 32 bit
      reg(:rwcs).bits(:map).write(0b000)  # map select = primary
      reg(:rwcs).bits(:pr).write(0b11)    # priority = highest
      reg(:rwcs).bits(:cnt).write(1)      # single access
      reg(:rwcs).bits(:err).write(0)      # read/write access error
      reg(:rwcs).bits(:dv).write(0)       # read/write access data valid
      write_nexus_register(:rwcs)

      if options[:write]
        # Send command to write RWD reg
        # Send data value to be written to RWD reg
        write_nexus_register(:rwd, :reg_data => data)
      else 
        # Send command to read RWD reg
        # Read RWD reg value
        read_nexus_register(:rwd, :reg_data => data)
      end

    end

    # Read a memory-mapped resource
    # for now only supports 32-bit data
    def single_read_access(address, data, options={})
      single_write_access(address, data, options.merge(:write => false))
    end

    # Write the given register (or system memory location) or given value to a specified address
    # reg_or_val          := register symbol to use -- assumes register preloaded with
    #                        required data to use, can override by using :address option
    #                        in which case data to use provided here
    #
    # options[:address]   := address to write to.  This is mandatory in the case of the
    #                        reg_or_val argument being a value (for data), if it is a
    #                        Register object then this is optional and if present then
    #                        will override the register's address.
    #
    def write_register(reg_or_val, options={})
      options={:write => true,    # whether to write or read the register
              }.merge(options)
      address = exact_address(reg_or_val, options)
      data = exact_data(reg_or_val, options)
       
      name = reg_or_val.respond_to?(:name) ? reg_or_val.name.upcase : "n/a"
      op = options[:write] ? "Write" : "Read"

      cc "**************************** NEXUS REGISTER #{op.upcase} BEGIN ****************************"
      cc "- #{op} Register #{name}: addr: 0x%08X, data: 0x%08X\n" % [ address, data ] 
      single_write_access(address, data, options)
      cc "**************************** NEXUS REGISTER #{op.upcase} END ****************************"
    end
    alias :write :write_register

    # Read the given register (or system memory location) or given value from a specified address
    # reg_or_val          := register symbol to use -- assumes register preloaded with
    #                        required data to use, can override by using :address option
    #                        in which case data to use provided here
    #
    # options[:address]   := address to read from.  This is mandatory in the case of the
    #                        reg_or_val argument being a value (for data), if it is a
    #                        Register object then this is optional and if present then
    #                        will override the register's address.
    #
    def read_register(reg_or_val, options={})
       write_register(reg_or_val, options.merge(:write => false))
    end
    alias :read :read_register

    # Provides exact address value either if a defined register is
    # provided or if an address is provided
    def exact_address(reg_or_val, options={})
      address = options[:addr] || options[:address]
      unless address
        # if no address provided as option then use register address
        if reg_or_val.respond_to?(:address)         # if register has :address property
          address = reg_or_val.address       # use register address
        else
          raise "An :address option must be supplied when not providing a register to Nexus!\n"
        end
      end
      address
    end

    # Provides exact data value either if a defined register is
    # provided or if an address is provided
    def exact_data(reg_or_val, options={})
      # if no data provided as option then use register data
      if reg_or_val.respond_to?(:data)     # if register has :data property
        data = reg_or_val.data             # use register value
      else
        data = reg_or_val                  # use reg_or_val passed as data
      end
      data
    end


    def log(msg)
      cc "Nexus::Driver - #{msg}"
    end
  end
end
