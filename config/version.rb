module Nexus
  MAJOR = 0
  MINOR = 6
  BUGFIX = 0
  DEV = 5

  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
