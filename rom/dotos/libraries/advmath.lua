-- additional mathematical functions --

local lib = {}

-- linear interpolation
function lib.lerp(start, finish, duration, elapsed)
  return start + (finish - start) * (math.min(duration, elapsed) / duration)
end

return lib
