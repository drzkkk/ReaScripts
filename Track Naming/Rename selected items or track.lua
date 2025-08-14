-- @description Rename selected takes or last touched track
-- @version 1.0
-- @tags rename
-- @changelog First version
-- @author drzk

local r = reaper

function Main()
  local num_items = r.CountSelectedMediaItems(0)
  if num_items > 0 then
    r.Main_OnCommand(r.NamedCommandLookup("_XENAKIOS_RENMTAKEALL"), 0)
  else
    r.Main_OnCommand(40696, 0)
  end
end

Main()