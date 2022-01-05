local look = table.concat({...}, " ")
local search = "/dotos/help/?;/shared/help/?"
local aliases = {
  dotos = main,
  [""] = "main"
}
look = aliases[look or "main"] or look or "main"
local path = package.searchpath(look, search)
if not path then
  error("no available help entry", 0)
end
assert(loadfile("/dotos/binaries/pager.lua"))("-E", path)
