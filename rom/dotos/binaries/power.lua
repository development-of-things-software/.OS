local args, opts = require("argparser")(...)

if opts.s then
  os.shutdown()
elseif opts.r then
  os.reboot()
else
  error("usage: power [-s|-r]", 0)
end
