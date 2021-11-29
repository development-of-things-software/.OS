-- textutils --

local lib = {}

lib.wordbreak = "[ %-=%+%*/%%]"

function lib.escape(text)
  checkArg(1, text, "string")
  return text:gsub("[%%%$%^%&%*%(%)%-%+%[%]%?%.]", "%%%1")
end

-- wrap text to the specified width
function lib.wrap(text, w)
  checkArg(1, text, "string")
  checkArg(2, w, "number")
  local lines = {""}
  local i = 1
  for c in text:gmatch(".") do
    if c == "\n" or #lines[i] >= w then
      i = i + 1
      lines[i] = ""
    end
    lines[i] = lines[i] .. c
  end
  return lines
end

-- word-wrap text to the specified width
function lib.wordwrap(text, w)
  checkArg(1, text, "string")
  checkArg(2, w, "number")
  local lines = {""}
  local word = ""
  local i = 1
  for c in text:gmatch(".") do
    if c:match(lib.wordbreak) then
      if #lines[i] + #word > w and #lines[i] > 0 then
        i = i + 1
        lines[i] = c
      else
        lines[i] = lines[i] .. word
        word = c
      end
      if c == "\n" then
        i = i + 1
        lines[i] = ""
      end
    else
      word = word .. c
    end
  end
  if #lines[i] + #word > w and #lines[i] > 0 then
    i = i + 1
    lines[i] = word
  else
    lines[i] = lines[i] .. word
  end
  return lines
end

return lib
