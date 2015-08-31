require 'spec_helper'

describe OrigenNexus do

  it "will use the host JTAG if available" do
    OrigenNexus::DUTWithJTAG.new.nexus.jtag.should == :used_host_jtag
  end

end
