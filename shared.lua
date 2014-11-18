-- By using this table, we can have data shared between multiple modules,
-- without using global variables.
--
-- This only needs to be used for data that is SET after "require"ing of
-- modules happens. If stuff is read-only (e.g. a function field that does
-- not change, or a constant-value field), then there's no need to use this.
--
-- Idea from: http://coronalabs.com/blog/2013/05/28/tutorial-goodbye-globals/

local M = {}
return M
