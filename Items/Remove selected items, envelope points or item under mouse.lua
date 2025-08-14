-- @description Remove selected items, envelope points or item under mouse
-- @version 1.0
-- @tags remove
-- @changelog First version
-- @author drzk

function GetTotalItemCount()
  return reaper.CountMediaItems(0)
end

function GetItemUnderMouse()
  local x, y = reaper.GetMousePosition()
  local item = reaper.GetItemFromPoint(x, y, true)
  return item
end

function main()
  local beforeCount = GetTotalItemCount()
  reaper.Undo_BeginBlock()
  reaper.Main_OnCommand(40184, 0)
  local afterCount = GetTotalItemCount()
  if beforeCount == afterCount then
    local item = GetItemUnderMouse()
    if item then
      reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(item), item)
      reaper.UpdateArrange()
    end
  end
  reaper.Undo_EndBlock("Remove selected", -1)
end

main()