-- @description Duplicate items or tracks (without move visible area)
-- @version 1.1
-- @tags duplicate, items, tracks
-- @changelog First version
-- @author drzk

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local cursor_pos = reaper.GetCursorPosition()
local view_start, view_end = reaper.GetSet_ArrangeView2(0, false, 0, 0)

local focus = reaper.GetCursorContext2(true)

if focus == 0 then
  reaper.Main_OnCommand(40062, 0)
elseif focus == 1 then
  reaper.Main_OnCommand(41295, 0)
end

reaper.SetEditCurPos(cursor_pos, false, false)
reaper.GetSet_ArrangeView2(0, true, 0, 0, view_start, view_end)

reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Duplicate items or tracks", 0)
reaper.UpdateArrange()