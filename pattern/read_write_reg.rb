# Pattern to exercise the reading and writing of a register using Nexus
Pattern.create(options={:name => "read_write_reg_#{$dut.tclk_format.upcase}#{$dut.tclk_multiple}"}) do

  ss "Test write register with all 1s"
  $dut.reg(:testme32).write!(0xFFFFFFFF)
  ss "Test read register after all 1s write"
  $dut.reg(:testme32).read!

  ss "Test write register with all 0s"
  $dut.reg(:testme32).write!(0x00000000)
  ss "Test read register after all 0s write"
  $dut.reg(:testme32).read!

  ss "Test write value, should write value 0x55AA55AA to address 0xAB"
  $dut.nexus.write 0x55AA55AA, :address => 0xAB
  ss "Test read value, should read value 0x55AA55AA from address 0xAB"
  $dut.nexus.read 0x55AA55AA, :address => 0xAB

  ss "Test Disable OnCE"
  $dut.nexus.disable_once

  ss "Test Enable IPS access block form"
  $dut.nexus.enable_nexus_access do
    $dut.nexus.write 0x55AA55AA, :address => 0xAB
  end

  ss "Test single write access directly"
  $dut.nexus.single_write_access 0xAB, 0x55AA55AA
  ss "Test single read access directly"
  $dut.nexus.single_read_access 0xAB, 0x55AA55AA

  ss "Test store register, the whole register data should be stored"
  $dut.reg(:testme32).store!

  ss "Test store bits, only enable bit should be captured"
  $dut.reg(:testme32).bit(:enable).store!


  ss "Test store bits, only port A should be captured"
  $dut.reg(:testme32).bits(:portA).store!

  ss "Test read of partial register, only portA should be read"
  $dut.reg(:testme32).bits(:portB).read!

  ss "Test overlay, all reg vectors should be from subroutine"
  $dut.reg(:testme32).overlay("write_overlay")
  $dut.reg(:testme32).write!
  
  ss "Test overlay, same again but for read"
  $dut.reg(:testme32).overlay("read_overlay")
  $dut.reg(:testme32).read!

  ss "Test bit level write overlay, only portA should be from subroutine"
  $dut.reg(:testme32).overlay(nil)  # have to reset overlay bits as they are sticky from last overlay set
  $dut.reg(:testme32).bits(:portA).overlay("write_overlay")
  $dut.reg(:testme32).bits(:portA).write!

  ss "Test bit level read overlay, only portA should be from subroutine"
  $dut.reg(:testme32).overlay(nil)
  $dut.reg(:testme32).bits(:portA).overlay("read_overlay")
  $dut.reg(:testme32).bits(:portA).read!

end
