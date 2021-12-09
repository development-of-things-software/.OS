local args, opts = require("argparser")(...)

local ok, err = require("fs").delete(args[1])
if not ok and err then error(args[1] .. ": " .. err, 0) end
os.exit()
