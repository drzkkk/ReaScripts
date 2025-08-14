-- @description Toggle select EVEN items on track or selected items if any
-- @version 1.0
-- @tags even items
-- @changelog First version
-- @author drzk

local r = reaper
local state_key = "toggle_even_selection"

local track = r.GetSelectedTrack(0, 0)
if not track then return end

local function sort_items_by_pos(items)
  table.sort(items, function(a, b) return a.pos < b.pos end)
end

local selected_items = {}
local item_count = r.CountTrackMediaItems(track)
for i = 0, item_count - 1 do
  local item = r.GetTrackMediaItem(track, i)
  if r.GetMediaItemInfo_Value(item, "B_UISEL") == 1 then
    local pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
    table.insert(selected_items, {item = item, pos = pos})
  end
end

local items_to_process = nil

if #selected_items > 0 then
  items_to_process = selected_items
else
  items_to_process = {}
  for i = 0, item_count - 1 do
    local item = r.GetTrackMediaItem(track, i)
    local pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
    table.insert(items_to_process, {item = item, pos = pos})
  end
end

if #items_to_process == 0 then return end

sort_items_by_pos(items_to_process)

local state = r.GetExtState("MyScriptNamespace", state_key)
local active = (state == "1")

r.Undo_BeginBlock()
r.PreventUIRefresh(1)

if not active then
  for i = 0, item_count - 1 do
    local itm = r.GetTrackMediaItem(track, i)
    r.SetMediaItemInfo_Value(itm, "B_UISEL", 0)
  end
  for i, itm in ipairs(items_to_process) do
    local sel = (i % 2 == 0)
    r.SetMediaItemInfo_Value(itm.item, "B_UISEL", sel and 1 or 0)
  end
  r.SetExtState("MyScriptNamespace", state_key, "1", true)
else
  for i = 0, item_count - 1 do
    local itm = r.GetTrackMediaItem(track, i)
    r.SetMediaItemInfo_Value(itm, "B_UISEL", 0)
  end
  r.SetExtState("MyScriptNamespace", state_key, "0", true)
end

r.PreventUIRefresh(-1)
r.Undo_EndBlock("Toggle select even items on track", -1)
r.UpdateArrange()