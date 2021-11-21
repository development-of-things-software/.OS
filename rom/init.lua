-- DoT OS initialization file --

-- if we're running in Lua 5.1, replace load() and remove its legacy things
-- (or, rather, place them in _G.lua51
if _VERSION == "Lua 5.1" then
  _G.lua51 = {
    load = load,
    loadstring = loadstring,
    setfenv = setfenv,
    getfenv = getfenv,
    unpack = unpack,
    log10 = math.log10,
    maxn = table.maxn
  }
end

while true do coroutine.yield() end
