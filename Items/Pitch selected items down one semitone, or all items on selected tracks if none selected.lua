-- @description Pitch selected items down one semitone, or all items on selected tracks if none selected
-- @version 1.0
-- @tags pitch items down
-- @changelog First version
-- @author drzk

local function pitch_item(item)
  local take = reaper.GetActiveTake(item)
  if take then
    local pitch = reaper.GetMediaItemTakeInfo_Value(take, "D_PITCH")
    reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", pitch - 1)
  end
end

reaper.Undo_BeginBlock()

local sel_item_count = reaper.CountSelectedMediaItems(0)

if sel_item_count > 0 then
  for i = 0, sel_item_count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    pitch_item(item)
  end
else
  local sel_track_count = reaper.CountSelectedTracks(0)
  if sel_track_count > 0 then
    for t = 0, sel_track_count - 1 do
      local track = reaper.GetSelectedTrack(0, t)
      local item_count = reaper.CountTrackMediaItems(track)
      for i = 0, item_count - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        pitch_item(item)
      end
    end
  else
    reaper.ShowMessageBox("", "Error", 0)
  end
end

reaper.UpdateArrange()
reaper.Undo_EndBlock("Pitch items down one semitone", -1)