# This file defines the users associated with your project, it is basically the 
# mailing list for release notes.
#
# You can split your users into "admin" and "user" groups, the main difference 
# between the two is that admin users will get all tag emails, users will get
# emails on external/official releases only.
#
# Users are also prohibited from running the "rgen tag" task, but this is 
# really just to prevent a casual user from executing it inadvertently and is
# not intended to be a serious security gate.
module RGen
  module Users
    def users
      @users ||= [

        # Admins
        User.new("Daniel Hadad", "ra6854", :admin),
 #       User.new("Stephen McGinty", "r49409", :admin),
 #       User.new("Jiang Liu", "b20251", :admin),
 #       User.new("Gordon Campbell", "r11981", :admin),

        # Users
        #User.new("Thao Huynh", "r6aanf"),
        # The r-number attribute can be anything that can be prefixed to an 
        # @freescale.com email address, so you can add mailing list references
        # as well like this:
        #User.new("RGen Users", "rgen"),  # The RGen mailing list
        
      ]
    end
  end
end
