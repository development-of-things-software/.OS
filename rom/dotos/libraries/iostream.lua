-- iostream: Create an IO stream from a surface --
-- allows terminals and whatnot --

local vt = require("vt100")

local lib = {}

function lib.wrap(surface)
  checkArg(1, surface, "table")
  local s = {}

  function s.read(n)
    checkArg(1, n, "number")
    return self.vt:read(n)
  end

  function s.readLine(keepnl)
    keepnl = not not keepnl
    return self.vt:readLine()
  end

  function s.readAll()
    return self.vt:read(math.huge)
  end

  function s.write()
  end

  function s.flush()
  end

  function s.close()
  end

  s.vt=vt.new(surface)
  return dotos.mkfile(s, "rw")
end

return lib
