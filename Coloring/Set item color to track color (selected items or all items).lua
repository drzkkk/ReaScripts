-- @description Set item color to track color (selected items or all items)
-- @version 1.0
-- @tags item color
-- @changelog First version
-- @author drzk

function SetItemColorToTrack(item)
  local track = reaper.GetMediaItem_Track(item)
  if not track then return end

  local _, trackColor = reaper.GetSetMediaTrackInfo_String(track, "P_COLOR", "", false)

  if reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR") ~= 0 then
    reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR"))
  else
    reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", 0)
  end
end

function Main()
  reaper.Undo_BeginBlock()
  local count_sel = reaper.CountSelectedMediaItems(0)

  if count_sel > 0 then
    for i = 0, count_sel-1 do
      local item = reaper.GetSelectedMediaItem(0, i)
      SetItemColorToTrack(item)
    end
  else
    local track = reaper.GetSelectedTrack(0, 0)
    if track then
      local itemCount = reaper.CountTrackMediaItems(track)
      for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        SetItemColorToTrack(item)
      end
    else
      reaper.ShowMessageBox("Please select track", "Error", 0)
    end
  end

  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Set item color to track color", -1)
end

Main()