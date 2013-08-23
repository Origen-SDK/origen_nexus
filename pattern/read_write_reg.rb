# Pattern to exercise the reading and writing of a register using Nexus
Pattern.create do

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

end
