-- @description Mute selected Items or Razor Edit area, if no selected mute Under Mouse Cursor
-- @version 1.0
-- @tags mute
-- @changelog First version
-- @author drzk

local r = reaper

r.PreventUIRefresh(1)
r.Undo_BeginBlock()

local function RazorEditSelectionExists()
  for i = 0, r.CountTracks(0) - 1 do
    local retval, x = r.GetSetMediaTrackInfo_String(r.GetTrack(0, i), "P_RAZOREDITS", "string", false)
    if x ~= "" then return true end
  end
  return false
end

local function GetItemUnderMouse()
  local screen_x, screen_y = reaper.GetMousePosition()
  local item, take = reaper.GetItemFromPoint(screen_x, screen_y, true)
  return item
end

local function SelectedItemsExist()
  return reaper.CountSelectedMediaItems(0) > 0
end

if RazorEditSelectionExists() or SelectedItemsExist() then
  if RazorEditSelectionExists() then
    r.Main_OnCommand(40061, 0)
  end
  r.Main_OnCommand(40175, 0)
else
  local item = GetItemUnderMouse()
  if item then
    local muted = reaper.GetMediaItemInfo_Value(item, "B_MUTE")
    reaper.SetMediaItemInfo_Value(item, "B_MUTE", muted == 0 and 1 or 0)
    reaper.UpdateItemInProject(item)
  end
end

r.Undo_EndBlock('Smart Mute', 0)
r.PreventUIRefresh(-1)
r.UpdateArrange()
r.UpdateTimeline()