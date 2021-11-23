-- UILisp: The User Interface Lisp --
--
-- UILisp is a simple, easy-to-read, Lisp-y format for defining graphical user
-- interfaces under .OS.  It provides support for such features as Lua
-- callbacks, so for example you can execute arbitrary code when a button is
-- clicked.

local uiml = {}

local surface = require("dotui.surface")

local sexpr_pattern = "%b()"

local function new_context()
  return {
    surface = surface.new(1, 1, 1, 1),
    defined = {}
  }
end

local uiml_builtins = {
}

function uiml.evaluate(uicontext, data)
end

function uiml.load(file)
  local handle = assert(io.open(file, "r"))
  local data = handle:read("a")
  handle:close()
  local uicont = new_uicontext()
  local ui_structure = uiml.evaluate(uicont, data)
end

return uiml
