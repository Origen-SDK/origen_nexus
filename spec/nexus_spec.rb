require 'spec_helper'

describe Nexus do

  it "will use the host JTAG if available" do
    Nexus::DUTWithJTAG.new.nexus.jtag.should == :used_host_jtag
  end

end
