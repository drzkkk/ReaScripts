-- @description Duplicate track below with FX and automation, copying only selected or Razor Edit items
-- @version 1.0
-- @tags tracks, fx, duplicate
-- @changelog First version
-- @author drzk

local r = reaper

local function GetRazorEditTrackAndRanges()
  for i = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    local ok, str = r.GetSetMediaTrackInfo_String(tr, "P_RAZOREDITS", "", false)
    if ok and str ~= "" then
      local ranges = {}
      for start_s, end_s in str:gmatch("([%d%.]+) ([%d%.]+)") do
        table.insert(ranges, {tonumber(start_s), tonumber(end_s)})
      end
      return tr, ranges
    end
  end
  return nil, nil
end

local function ItemInRanges(item, ranges)
  local pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local len = r.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_end = pos + len
  for _, range in ipairs(ranges) do
    if pos < range[2] and item_end > range[1] then
      return true
    end
  end
  return false
end

local function DuplicateTrack(src_track)
  local src_idx = r.GetMediaTrackInfo_Value(src_track, "IP_TRACKNUMBER") - 1
  r.InsertTrackAtIndex(src_idx + 1, true)
  local dst_track = r.GetTrack(0, src_idx + 1)

  local _, name = r.GetTrackName(src_track, "")
  r.GetSetMediaTrackInfo_String(dst_track, "P_NAME", name, true)

  local _, chunk = r.GetTrackStateChunk(src_track, "", false)
  local fx_start = chunk:find("<FXCHAIN")
  if fx_start then
    local fx_chunk = chunk:sub(fx_start)
    local _, dst_chunk = r.GetTrackStateChunk(dst_track, "", false)
    dst_chunk = dst_chunk:gsub("<FXCHAIN.-\n", fx_chunk .. "\n")
    r.SetTrackStateChunk(dst_track, dst_chunk, false)
  end

  local env_count = r.CountTrackEnvelopes(src_track)
  for i = 0, env_count - 1 do
    local env = r.GetTrackEnvelope(src_track, i)
    local _, env_chunk = r.GetEnvelopeStateChunk(env, "", false)
    local dst_env = r.GetTrackEnvelope(dst_track, i)
    if dst_env then
      r.SetEnvelopeStateChunk(dst_env, env_chunk, false)
    end
  end

  return dst_track
end

local function MuteItems(track, items_to_mute)
  for i = 0, r.CountTrackMediaItems(track) - 1 do
    local item = r.GetTrackMediaItem(track, i)
    if items_to_mute[item] then
      r.SetMediaItemInfo_Value(item, "B_MUTE", 1)
    end
  end
end

local function DeleteUnselectedItems(track)
  for i = r.CountTrackMediaItems(track) - 1, 0, -1 do
    local item = r.GetTrackMediaItem(track, i)
    if not r.IsMediaItemSelected(item) then
      r.DeleteTrackMediaItem(track, item)
    end
  end
end

local function SelectItemsInRanges(track, ranges)
  for i = 0, r.CountMediaItems(0) - 1 do
    r.SetMediaItemSelected(r.GetMediaItem(0, i), false)
  end
  for i = 0, r.CountTrackMediaItems(track) - 1 do
    local item = r.GetTrackMediaItem(track, i)
    if ItemInRanges(item, ranges) then
      r.SetMediaItemSelected(item, true)
    end
  end
end

local function GetTrackOfSelectedItems()
  local sel_items_count = r.CountSelectedMediaItems(0)
  if sel_items_count == 0 then return nil end
  return r.GetMediaItem_Track(r.GetSelectedMediaItem(0, 0))
end

local function RunSwsSmartSplit()
  local cmdID = r.NamedCommandLookup("_SWS_SMARTSPLIT2")
  if cmdID == 0 then
    r.ShowMessageBox("SWS smart split command (_SWS_SMARTSPLIT2) not found. Please install SWS extension.", "Error", 0)
    return false
  end
  r.Main_OnCommand(cmdID, 0)
  return true
end

function Main()
  r.Undo_BeginBlock()

  local razor_track, razor_ranges = GetRazorEditTrackAndRanges()
if razor_track then
  r.SetOnlyTrackSelected(razor_track)
  r.SetCursorContext(1, nil)
  local ok = RunSwsSmartSplit()
  if not ok then
    r.Undo_EndBlock("", -1)
    return
  end
  r.UpdateArrange()
  SelectItemsInRanges(razor_track, razor_ranges)
end


  local sel_items_count = r.CountSelectedMediaItems(0)
  if sel_items_count == 0 then
    r.ShowMessageBox("No selected items to duplicate after split.", "Error", 0)
    r.Undo_EndBlock("", -1)
    return
  end

  local src_track = GetTrackOfSelectedItems()
  if not src_track then
    r.ShowMessageBox("Can't determine source track.", "Error", 0)
    r.Undo_EndBlock("", -1)
    return
  end

  local items_to_copy = {}
  for i = 0, sel_items_count - 1 do
    local item = r.GetSelectedMediaItem(0, i)
    items_to_copy[item] = true
  end

  local dst_track = DuplicateTrack(src_track)
  MuteItems(src_track, items_to_copy)

  for i = 0, r.CountTrackMediaItems(dst_track) - 1 do
    r.SetMediaItemSelected(r.GetTrackMediaItem(dst_track, i), false)
  end

  for i = 0, r.CountTrackMediaItems(dst_track) - 1 do
    local dst_item = r.GetTrackMediaItem(dst_track, i)
    local dst_pos = r.GetMediaItemInfo_Value(dst_item, "D_POSITION")
    local dst_len = r.GetMediaItemInfo_Value(dst_item, "D_LENGTH")
    for orig_item in pairs(items_to_copy) do
      local orig_pos = r.GetMediaItemInfo_Value(orig_item, "D_POSITION")
      local orig_len = r.GetMediaItemInfo_Value(orig_item, "D_LENGTH")
      if math.abs(orig_pos - dst_pos) < 0.001 and math.abs(orig_len - dst_len) < 0.001 then
        r.SetMediaItemSelected(dst_item, true)
        break
      end
    end
  end

  DeleteUnselectedItems(dst_track)

  r.TrackList_AdjustWindows(false)
  r.UpdateArrange()
  r.Undo_EndBlock("Duplicate track below with FX and automation", -1)
end

Main()