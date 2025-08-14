-- @description Smart Add FX To selected item or track
-- @version 1.0
-- @tags fx chain, fx
-- @changelog First version
-- @author drzk

local r = reaper

function IsMidiTake(take)
  if not take then return false end
  local source = r.GetMediaItemTake_Source(take)
  if not source then return false end
  local type = r.GetMediaSourceType(source, "")
  return type:find("MIDI") ~= nil
end

function Main()
  local item_count = r.CountSelectedMediaItems(0)
  local opened_fx = false

  if item_count > 0 then
    for i = 0, item_count - 1 do
      local item = r.GetSelectedMediaItem(0, i)
      local take = r.GetActiveTake(item)
      if take and not IsMidiTake(take) then
        r.Main_OnCommand(40289, 0)
        r.SetMediaItemSelected(item, true)
        r.Main_OnCommand(40638, 0)
        opened_fx = true
        break
      end
    end
  end

  if not opened_fx then
    r.Main_OnCommand(40271, 0)
  end
end

Main()