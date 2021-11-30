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

-- split text into lines
function lib.lines(text)
  checkArg(1, text, "string")
  local lines = {""}
  for c in text:gmatch(".") do
    if c == "\n" then
      lines[#lines+1] = ""
    else
      lines[#lines] = lines[#lines] .. c
    end
  end
  if lines[#lines] == "" then lines[#lines] = nil end
  return lines
end

-- word-wrap text to the specified width
function lib.wordwrap(text, w)
  checkArg(1, text, "string")
  checkArg(2, w, "number")
  local lines = {}
  for _, line in ipairs(lib.lines(text)) do
    if #line == 0 then
      lines[#lines+1] = ""
    else
      while #line > 0 do
        local chunk = line:sub(1, w)
        if #chunk == w then
          local offset = chunk:reverse():find(lib.wordbreak) or 1
          chunk = chunk:sub(1, -offset)
        end
        line = line:sub(#chunk + 1)
        lines[#lines+1] = chunk
      end
    end
  end
  return lines
end

function lib.padRight(text, w)
  checkArg(1, text, "string")
  checkArg(2, w, "number")
  return text .. (" "):rep(w - #text)
end

function lib.padLeft(text, w)
  checkArg(1, text, "string")
  checkArg(2, w, "number")
  return (" "):rep(w - #text) .. text
end

return lib
