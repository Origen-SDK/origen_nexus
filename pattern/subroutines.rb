# Pattern to exercise the reading and writing of a register using Nexus
# subroutine definition using 'data_only' methods
if ($tester.respond_to?('start_subroutine'))
  Pattern.create(options={:name => "subroutines_#{$dut.tclk_format.upcase}#{$dut.tclk_multiple}"}) do
  
    # initialize register with value
    $dut.reg(:testme32).write(0xFFFF0000)
  
    cc "Write Overlay TESTME32 with 0x%08X" % [ $dut.reg(:testme32).data ]
    $tester.start_subroutine("write_overlay")
    $dut.nexus.write_data_only($dut.reg(:testme32))
    $tester.end_subroutine

    cc "Read Overlay TESTME32 with 0x%08X" % [ $dut.reg(:testme32).data ]
    $tester.start_subroutine("read_overlay")
    $dut.nexus.read_data_only($dut.reg(:testme32))
    $tester.end_subroutine

    cc "Write Overlay 0x55555555"
    $tester.start_subroutine("write_overlay2")
    $dut.nexus.write_data_only(0x55555555)
    $tester.end_subroutine

    cc "Write Overlay 0xAAAAAAAA"
    $tester.start_subroutine("read_overlay2")
    $dut.nexus.read_data_only(0xAAAAAAAA)
    $tester.end_subroutine

  end
end
