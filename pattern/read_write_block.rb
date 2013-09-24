# Pattern to exercise the reading and writing of a register using Nexus
Pattern.create do

  block_address = 0x5A

  block_data = [ 0x00000000,
                 0x11111111,
                 0x22222222,
                 0x33333333 ]

  c2 "BLOCK DATA TO WRITE TO ADDRESS: 0x%06X" % [ block_address ]

  block_data.each do |data|
    cc "  0x%08X" % [ data ]
  end

  ss "Test Block Write"
  $dut.nexus.block_write_access block_address, block_data

  ss "Test Block Read"
  $dut.nexus.block_read_access block_address, block_data

end
