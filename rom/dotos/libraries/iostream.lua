-- iostream: Create an IO stream from a surface --
-- allows terminals and whatnot --

local vt = require("vt100")

local lib = {}

function lib.wrap(surface)
  checkArg(1, surface, "table")
  local s = {}

  function s.read(n)
    checkArg(1, n, "number")
    return s.vt:read(n)
  end

  function s.readLine(keepnl)
    keepnl = not not keepnl
    return s.vt:readLine()
  end

  function s.readAll()
    return s.vt:read(math.huge)
  end

  function s.write(str)
    return s.vt:write(str)
  end

  function s.flush()
    return s.vt:flush()
  end

  function s.close()
    return s.vt:close()
  end

  s.vt=vt.new(surface)
  return dotos.mkfile(s, "rw")
end

return lib
