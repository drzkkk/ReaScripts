-- @description Set loop and time selection to Razor Edit area or selected items, enable repeat
-- @version 1.0
-- @tags loop
-- @changelog First version
-- @author drzk

local function get_razor_edit_bounds()
  local start_pos, end_pos = nil, nil
  local track_count = reaper.CountTracks(0)

  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    local retval, area = reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", "", false)
    if retval and area ~= "" then
      for segment in area:gmatch("[^,]+") do
        local s, e = segment:match("([%d%.]+) ([%d%.]+)")
        if s and e then
          s, e = tonumber(s), tonumber(e)
          if not start_pos or s < start_pos then start_pos = s end
          if not end_pos or e > end_pos then end_pos = e end
        end
      end
    end
  end

  return start_pos, end_pos
end

local function get_selected_items_bounds()
  local count = reaper.CountSelectedMediaItems(0)
  if count == 0 then return nil, nil end

  local start_pos, end_pos = nil, nil
  for i = 0, count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = pos + len
    if not start_pos or pos < start_pos then start_pos = pos end
    if not end_pos or item_end > end_pos then end_pos = item_end end
  end
  return start_pos, end_pos
end

local function set_loop_and_selection_and_cursor(start_pos, end_pos)
  if start_pos and end_pos and end_pos > start_pos then
    reaper.GetSet_LoopTimeRange(true, true, start_pos, end_pos, false)
    reaper.SetEditCurPos(start_pos, true, false)
    if reaper.GetToggleCommandState(1068) == 0 then
      reaper.Main_OnCommand(1068, 0)
    end
  end
end

reaper.Undo_BeginBlock()

local razor_start, razor_end = get_razor_edit_bounds()

if razor_start and razor_end and razor_start < razor_end then
  set_loop_and_selection_and_cursor(razor_start, razor_end)
else
  local item_start, item_end = get_selected_items_bounds()
  if item_start and item_end and item_start < item_end then
    set_loop_and_selection_and_cursor(item_start, item_end)
  end
end

reaper.Undo_EndBlock("Set loop and time selection", -1)