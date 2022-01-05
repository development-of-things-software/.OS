-- text splitters --

local lib = {}

-- simple gmatch splitter
function lib.simple(str, char)
  checkArg(1, str, "string")
  checkArg(2, char, "string")
  
  local res = {}

  for str in str:gmatch("[^"..char.."]+") do
    res[#res+1] = str
  end

  return res
end

-- shell-style splitter
function lib.complex(str)
  checkArg(1, str, "string")

  local res = {}
  local word, instr = "", false

  for c in str:gmatch(".") do
    if c == '"' then
      instr = not instr
    --  word = word .. c
    elseif instr then
      word = word .. c
    elseif c == " " then
      if #word > 0 then res[#res+1] = word end
      word = ""
    else
      word = word .. c
    end
  end
  if #word > 0 then res[#res+1] = word end

  return res
end

return lib
