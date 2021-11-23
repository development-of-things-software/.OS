-- screen buffering
-- this is similar to the Window api provided by CraftOS, but:
--   - it does not attempt to provide an API similar to term,
--     instead preferring a custom set of commands
--   - it uses proper object-orientation rather than...
--     whatever it is the Window api does

local s = {}

function s:draw()
end

local buf = {}

return buf
