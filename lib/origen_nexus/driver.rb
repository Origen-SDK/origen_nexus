module OrigenNexus
  class Driver
    # Include JTAG driver instance to fall back on (if owner doesn't have)
    include OrigenJTAG

    # Allow for JTAG optionality
    # blank for now
    JTAG_CONFIG = {}

    # Include registers as Nexus has its own registers
    include Origen::Registers

    alias_method :local_jtag, :jtag

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

    attr_reader :cpuscr_reg_width

    attr_reader :once_cpuscr_go_exit_instr

    def initialize(owner, options = {})
      if defined?(owner.class::NEXUS_CONFIG)
        options = owner.class::NEXUS_CONFIG.merge(options)
      end

      # Fallback defaults
      options = {
        tclk_format:               :rh,                      # format of JTAG clock used:  ReturnHigh (:rh), ReturnLo (:rl)
        tclk_multiple:             1,                      # number of cycles for one clock pulse, assumes 50% duty cycle. Uses tester non-return format to spread TCK across multiple cycles.
        #    e.g. @tclk_multiple = 2, @tclk_format = :rh, means one cycle with Tck low (non-return), one with Tck high (NR)
        #         @tclk_multiple = 4, @tclk_format = :rl, means 2 cycles with Tck high (NR), 2 with Tck low (NR)
        tdo_strobe:                :tclk_high,                # when using multiple cycles for TCK, which state of TCK to strobe for TDO, :tclk_high or :tclk_low or :tclk_all
        tdo_store_cycle:           0,                    # store vector cycle within TCK (i.e. when to indicate to tester to store vector within TCK cycle.  0 is first vector, 1 is second, etc.)
        #
        once_ocmd_width:           10,                   # Width of OnCE OCMD instruction reg in bits
        once_nexus_access_instr:   0b0001111100, # Instruction used to access nexus via OnCE, default: 0x07C.
        once_bypass_instr:         0b0001111111,       # Instruction used to bypass OnCE, default: 0x07F.
        once_cpuscr_go_exit_instr: 0b0110010000,  # Instruction used to exit debug mode and kick off code execution from desired address.
        nexus_command_width:       8,                # Width of Nexus command data regs, default: 8.
        cpuscr_reg_width:          192,              # Width of cpuscr reg
      }.merge(options)

      # Define JTAG configs based on Nexus config
      JTAG_CONFIG[:tclk_format] = options[:tclk_format]
      JTAG_CONFIG[:tclk_multiple] = options[:tclk_multiple]
      JTAG_CONFIG[:tdo_strobe] = options[:tdo_strobe]
      JTAG_CONFIG[:tdo_store_cycle] = options[:tdo_store_cycle]

      @once_ocmd_width = options[:once_ocmd_width]
      @once_nexus_access_instr = options[:once_nexus_access_instr]
      @once_bypass_instr = options[:once_bypass_instr]
      @once_cpuscr_go_exit_instr = options[:once_cpuscr_go_exit_instr]
      @nexus_command_width = options[:nexus_command_width]
      @cpuscr_reg_width = options[:cpuscr_reg_width]

      # Define nexus registers
      define_nexus_registers

      # Define CPU registers
      define_cpu_registers

      @owner = owner
    end

    def on_created
    end

    # This proxies all pin requests from our local JTAG driver to
    # our parent DUT model
    def pin(*args)
      owner.pin(*args)
    end
    alias_method :pins, :pin

    # Define Nexus registers
    # For now only those related to RWA will be defined.
    # RWA (read/write access) provides DMA-like access to memory-mapped resources on
    # the AHB system bus either while the processor is halted or during runtime.
    def define_nexus_registers
      # Each register has a Nexus Opcode, which we will use as 'address' below, and
      #  corresponding read addresses and write addresses

      # RWCS - Read/Write Access Control Register
      #        read addr = 0x0E, write addr = 0x0F
      reg :rwcs, 0x0E, size: 32 do
        bit 31,     :ac
        bit 30,     :rw
        bit 29..27, :sz
        bit 26..24, :map
        bit 23..22, :pr
        bit 15..2,  :cnt
        bit 1,      :err, writable: false
        bit 0,      :dv, writable: false
      end

      # RWD - Read/Write Access Data
      #       read addr = 0x12, write addr = 0x13
      reg :rwa, 0x12, size: 32 do
        bit 31..0, :addr
      end

      # RWD - Read/Write Access Data
      #       read addr = 0x14, write addr = 0x15
      reg :rwd, 0x14, size: 32 do
        bit 31..0, :data
      end
    end

    def define_cpu_registers
      reg :cpuscr, 0x0, size: 192 do
        bit 191..160, :ctl
        bit 159..128, :ir
        bit 127..96,  :pc
        bit 95..64,   :msr
        bit 63..32,   :wbbrh
        bit 31..0,    :wbbrl
      end
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
        jtag.write_ir once_nexus_access_instr, size: once_ocmd_width, msg: log2("Enable Nexus Access: OnCE_Send(#{once_ocmd_width}, 0x%02X)" % [once_nexus_access_instr])
        @ir_reg_value = once_nexus_access_instr
      end
      if block_given?
        yield
        disable_once
      end  # whether to mark all bits in RWD for read
    end

    # Disable OnCE
    def disable_once
      if @ir_reg_value != once_bypass_instr
        jtag.write_ir once_bypass_instr, size: once_ocmd_width, msg: log2("Bypass OnCE: OnCE_Send(#{once_ocmd_width}, 0x%02X)" % [once_bypass_instr])
        @ir_reg_value = once_bypass_instr
      end
    end

    def go_exit(code_start_address = 0x4)
      jtag.write_ir once_cpuscr_go_exit_instr, size: once_ocmd_width, msg: log2('Enabling CPUSCR register for read/write access')
      regs(:cpuscr).bit(:wbbrl).write(0x00000000)
      regs(:cpuscr).bit(:wbbrh).write(0x00000000)
      regs(:cpuscr).bit(:msr).write(0x00000000)
      regs(:cpuscr).bit(:pc).write(code_start_address - 4)
      regs(:cpuscr).bit(:ir).write(0x7c0004ac)
      regs(:cpuscr).bit(:ctl).write(0x00000000)
      jtag.write_dr regs(:cpuscr).value, size: cpuscr_reg_width, msg: log2('Writing GO+EXIT to CPUSCR')
    end

    # Write a given Nexus register
    def write_nexus_register(reg_or_val, options = {})
      options = { write:    true,        # whether to write or read
                  overlay:  false,
                  care_out: false
                }.merge(options)
      addr = exact_address(reg_or_val, options)
      addr += 1 if options[:write] # offset address by 1 since writing
      data = exact_data(reg_or_val, options)
      size = exact_size(reg_or_val, options)
      name = exact_name(reg_or_val, options)

      if options[:write]
        log "Write Nexus Reg: #{name.upcase} at 0x%04X with 0x%08X" % [addr, data]
      else
        log "Read Nexus Reg: #{name.upcase} at 0x%04X with 0x%08X" % [addr, data]
      end

      # first pass : select register via nexus command
      jtag.write_dr addr, size: nexus_command_width, msg: log2("OnCE_Send(#{nexus_command_width}, 0x%02X)" % [addr])
      if options[:overlay] == true
        # if we want to overlay expect values, then
        #   put dummy data in vectors to force them to be uncompressable by pattern generator.
        reg_or_val.data = 0x55555555
        data = exact_data(reg_or_val, options)
      end

      if options[:capture]
        reg(reg_or_val.name).store
      end

      if options[:write]
        # second pass : pass data to register
        jtag.write_dr reg_or_val, overlay: options[:overlay], overlay_label: options[:overlay_label], size: size, msg: log2("OnCE_Send(#{size}, 0x%08X)" % [data])
      else
        if options[:care_output]
          reg(reg_or_val.name).read
        end
        # second pass : read data from register
        jtag.read_dr(reg_or_val, overlay: options[:overlay], overlay_label: options[:overlay_label], size: size, msg: log2("OnCE_Read(#{size}, 0x%08X)" % [data]))
      end
    end

    # Read a given Nexus register
    def read_nexus_register(reg_or_val, options = {})
      write_nexus_register(reg_or_val, options.merge(write: false))
    end

    # Write data cycles only for a Register
    # Used if only want data cycles for overlay subroutines
    def write_data_only(reg_or_val, options = {})
      options = { write: true,        # whether to write or read
                }.merge(options)

      data = exact_data(reg_or_val, options)

      # Size of RWD register being used for output
      size = reg(:rwd).size

      # if reading a real register then need to handle copying over all data and flags
      # undefined regs will be handled in lower function so that default is to treat
      # as undefined reg (just simple accesses)
      reg(:rwd).overlay(nil)  # clear overlay flags if there, as sticky
      if real_reg?(reg_or_val)
        reg(:rwd).copy_all(reg_or_val)
      end

      if options[:write]
        # Send command to write RWD reg
        # Send data value to be written to RWD reg
        reg(:rwd).write(data)

        jtag.shift(reg(:rwd), options.merge(size: size, cycle_last: true, includes_last_bit: true))

      else
        # Mark all bits for read
        reg(:rwd).read

        jtag.shift(reg(:rwd), options.merge(size: size, read: true, cycle_last: true, includes_last_bit: true))

      end

      # Clear flags so as to not affect subsequent reg reads/writes
      reg(:rwd).clear_flags
      reg_or_val.clear_flags if reg_or_val.respond_to?(:clear_flags)
    end

    # Read data cycles only for RWD Register
    def read_data_only(reg_or_val, options = {})
      write_data_only(reg_or_val, options.merge(write: false))
    end

    # Single Write to memory-mapped resource
    # for now only supports 32-bit data
    def single_write_access(address, data, options = {})
      options = { write:      true,          # whether to write or read the register
                  undef:      true,          # whether IPS being accessed is a register or undefined
                  count:      1,             # by default use single address access mode
                  overlay:    false,                         # default: assume not a real register
                  nexus_init: true,
                  width:      32,      # default write width to 32 bits
              }.merge(options)
      if options[:width] == 8
        write_width = 0b0
      elsif options[:width] == 16
        write_width = 0b1
      elsif  options[:width] == 32
        write_width = 0b10
      elsif  options[:width] == 64
        write_width = 0b11
      else
        Origen.log.warn 'Nexus 3 width supplied is invalid, defaulting to 32 bit width.'
      end

      if options[:nexus_init]
        enable_nexus_access
      end
      # Send command to write RWA reg
      # Send address value to RWA reg
      reg(:rwa).write(address)
      write_nexus_register(reg(:rwa))

      # Send command to write RWCS reg
      # Send settings to RWCS
      reg(:rwcs).bits(:ac).write(1)
      reg(:rwcs).bits(:rw).write(options[:write] ? 1 : 0)
      reg(:rwcs).bits(:sz).write(write_width)                 # write_width, defaul value = 32 bits.
      reg(:rwcs).bits(:map).write(0b000)                # map select = primary
      reg(:rwcs).bits(:pr).write(0b11)                  # priority = highest
      reg(:rwcs).bits(:cnt).write(options[:count])      # single access
      reg(:rwcs).bits(:err).write(0)                    # read/write access error
      reg(:rwcs).bits(:dv).write(0)                     # read/write access data valid
      write_nexus_register(reg(:rwcs))

      if options[:write]
        # Send command to write RWD reg
        # Send data value to be written to RWD reg
        reg(:rwd).write(data)
        write_nexus_register(reg(:rwd), options.reject { |x| x == :address })
      else
        # If undefined reg, then mark all bits for read
        if options[:undef]
          reg(:rwd).read
        end
        # Send command to read RWD reg
        # Read RWD reg value
        reg(:rwd).write(data)
        read_nexus_register(reg(:rwd), options.reject { |x| x == :address })
      end
    end

    # Single Read from memory-mapped resource
    # for now only supports 32-bit data
    def single_read_access(address, data, options = {})
      single_write_access(address, data, options.merge(write: false))
    end

    # Block Write to memory-mapped resources
    # for now only supports 32-bit data
    #
    # address = address at start of block
    # block_data = array of 32-bit values of block data to write
    def block_write_access(address, block_data = [], options = {})
      options = { write: true,          # whether to write or read the block
                  width: 32       # width default to 32 bits
              }.merge(options)
      block_data.each_index do |i|
        if i == 0                                  # first do single write access with count > 1
          single_write_access(address, block_data[0], options.merge(count: block_data.count))
          if options[:width] > 32
            reg(:rwd).write(block_data[i = i + 1])
            if options[:write]
              write_nexus_register(reg(:rwd), options)
            else
              read_nexus_register(reg(:rwd), options)
            end
          end
        else
          next if i.odd? && options[:width] > 32
          reg(:rwd).write(block_data[i])
          if options[:write]
            write_nexus_register(reg(:rwd), options)
          else
            read_nexus_register(reg(:rwd), options)
          end
          if options[:width] > 32
            reg(:rwd).write(block_data[i = i + 1])
            if options[:write]
              write_nexus_register(reg(:rwd), options)
            else
              read_nexus_register(reg(:rwd), options)
            end
          end
        end
      end
    end

    # Block Read of memory-mapped resources
    # for now only supports 32-bit data
    #
    # address = address at start of block
    # block_data = array of 32-bit values of block data to read
    def block_read_access(address, block_data = [], options = {})
      block_write_access(address, block_data, options.merge(write: false))
    end

    #    def test_read_flag(reg_to_check)
    #      reg_to_check.size.times do |i|
    #        if reg_to_check.bit(i).is_to_be_read?
    #          print "\t\tBIT #{i} of #{reg_to_check.name.upcase} has read flag!\n"
    #        else
    #          print "\t\tBIT #{i} of #{reg_to_check.name.upcase} DOES NOT HAVE read flag!\n"
    #        end
    #      end
    #    end
    #
    #    def test_store_flag(reg_to_check)
    #      reg_to_check.size.times do |i|
    #        if reg_to_check.bit(i).is_to_be_stored?
    #          print "\t\tBIT #{i} of #{reg_to_check.name.upcase} has store flag!\n"
    #        else
    #          print "\t\tBIT #{i} of #{reg_to_check.name.upcase} DOES NOT HAVE store flag!\n"
    #        end
    #      end
    #    end
    #
    #    def test_overlay_flag(reg_to_check, options={})
    #      options={:msg => ""}.merge(options)
    #      reg_to_check.size.times do |i|
    #        if reg_to_check.bit(i).has_overlay?
    #          print "\t\t#{options[:msg]}: BIT #{i} of #{reg_to_check.name.upcase} has overlay flag!\n"
    #        else
    #          print "\t\t#{options[:msg]}: BIT #{i} of #{reg_to_check.name.upcase} DOES NOT HAVE overlay flag!\n"
    #        end
    #      end

    # determines whether real register or not
    def real_reg?(reg_or_val)
      reg_or_val.respond_to?(:name)
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
    def write_register(reg_or_val, options = {})
      options = { write:   true,    # whether to write or read the register
                  overlay: false
              }.merge(options)
      address = exact_address(reg_or_val, options)
      data = exact_data(reg_or_val, options)
      size = exact_size(reg_or_val, options)
      name = (exact_name(reg_or_val, options)).upcase

      op = options[:write] ? 'Write' : 'Read'

      # Set undefined register flag to override option for simple_write_access below
      options[:undef] = !real_reg?(reg_or_val)

      # if reading a real register then need to handle copying over all data and flags
      # undefined regs will be handled in lower function so that default is to treat
      # as undefined reg (just simple accesses)
      reg(:rwd).overlay(nil)  # clear overlay flags if there, as sticky
      if real_reg?(reg_or_val)
        reg(:rwd).copy_all(reg_or_val)
      end

      cc "**************************** NEXUS REGISTER #{op.upcase} BEGIN ****************************"
      cc "- #{op} Register #{name}: addr: 0x%08X, data: 0x%08X\n" % [address, data]
      single_write_access(address, data, options)
      cc "**************************** NEXUS REGISTER #{op.upcase} END ****************************"

      # Clear flags so as to not affect subsequent reg reads/writes
      reg(:rwd).clear_flags
      reg_or_val.clear_flags if reg_or_val.respond_to?(:clear_flags)
    end
    alias_method :write, :write_register

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
    def read_register(reg_or_val, options = {})
      write_register(reg_or_val, options.merge(write: false))
    end
    alias_method :read, :read_register

    # Provides exact address value either if a defined register is
    # provided or if an address is provided
    def exact_address(reg_or_val, options = {})
      address = options[:addr] || options[:address]
      unless address
        # if no address provided as option then use register address
        if real_reg?(reg_or_val)             # if real register
          address = reg_or_val.address       # use register address
        else
          fail "An :address option must be supplied when not providing a register to Nexus!\n"
        end
      end
      address
    end

    # Provides exact data value either if a defined register is
    # provided or if an address is provided
    def exact_data(reg_or_val, _options = {})
      # if no data provided as option then use register data
      if real_reg?(reg_or_val)             # if real register
        data = reg_or_val.data             # use register value
      else
        data = reg_or_val                  # use reg_or_val passed as data
      end
      data
    end

    # Provide size of register if real register passed--
    #  otherwise indicate number of bits of data value
    def exact_size(reg_or_val, _options = {})
      if real_reg?(reg_or_val)             # if real register
        size = reg_or_val.size             # use register size
      else
        size = reg_or_val.to_s(2).size     # get number of bits in value
      end
      size
    end

    # Provide name of register, if real register passed
    # otherwise given 'undef' as name
    def exact_name(reg_or_val, _options = {})
      if real_reg?(reg_or_val)             # if real register
        name = reg_or_val.name             # use register name
      else
        name = 'undef'                     # undefined register
      end
      name
    end

    def log2(msg)
      "Nexus::Driver - #{msg}"
    end

    def log(msg)
      cc "#{log2(msg)}"
    end
  end
end
