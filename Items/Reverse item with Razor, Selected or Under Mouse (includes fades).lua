-- @description Smart Reverse Audio Items with Razor, Selected or Under Mouse (includes fades)
-- @version 1.0
-- @tags reverse items
-- @changelog First version
-- @author drzk

local r = reaper

function GetItemsInRange(track, areaStart, areaEnd)
    local items = {}
    local itemCount = r.CountTrackMediaItems(track)
    for k = 0, itemCount - 1 do 
        local item = r.GetTrackMediaItem(track, k)
        local pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
        local length = r.GetMediaItemInfo_Value(item, "D_LENGTH")
        local itemEndPos = pos + length

        local take = r.GetActiveTake(item)
        if take and r.TakeIsMIDI(take) then goto continue end

        if (itemEndPos > areaStart and itemEndPos <= areaEnd) or
           (pos >= areaStart and pos < areaEnd) or
           (pos <= areaStart and itemEndPos >= areaEnd) then
            table.insert(items, item)
        end

        ::continue::
    end
    return items
end

function GetRazorEdits()
    local trackCount = r.CountTracks(0)
    local areaMap = {}
    for i = 0, trackCount - 1 do
        local track = r.GetTrack(0, i)
        local _, area = r.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)
        if area ~= '' then
            local str = {}
            for j in string.gmatch(area, "%S+") do
                table.insert(str, j)
            end

            local j = 1
            while j <= #str do
                local areaStart = tonumber(str[j])
                local areaEnd = tonumber(str[j+1])
                local guid = str[j+2]
                local items = GetItemsInRange(track, areaStart, areaEnd)
                table.insert(areaMap, {
                    areaStart = areaStart,
                    areaEnd = areaEnd,
                    track = track,
                    items = items,
                    guid = guid
                })
                j = j + 3
            end
        end
    end
    return areaMap
end

function SaveRazorEdits()
    local razorEdits = {}
    local trackCount = r.CountTracks(0)
    for i = 0, trackCount - 1 do
        local track = r.GetTrack(0, i)
        local _, area = r.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)
        if area ~= '' then
            razorEdits[track] = area
        end
    end
    return razorEdits
end

function RestoreRazorEdits(razorEdits)
    for track, area in pairs(razorEdits) do
        r.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', area, true)
    end
end

function SplitAreas(areaList)
    local areaItems = {}
    local tracks = {}
    r.PreventUIRefresh(1)
    for i = 1, #areaList do
        local area = areaList[i]
        local items = area.items
        if tracks[area.track] then
            items = GetItemsInRange(area.track, area.areaStart, area.areaEnd)
        end
        for j = 1, #items do
            local item = items[j]
            local newItem = r.SplitMediaItem(item, area.areaStart)
            if not newItem then
                r.SplitMediaItem(item, area.areaEnd)
                table.insert(areaItems, item)
            else
                r.SplitMediaItem(newItem, area.areaEnd)
                table.insert(areaItems, newItem)
            end
        end
        tracks[area.track] = true
    end
    r.PreventUIRefresh(-1)
    return areaItems
end

function swap(item, p1, p2)
    local a = r.GetMediaItemInfo_Value(item, p1)
    local b = r.GetMediaItemInfo_Value(item, p2)
    r.SetMediaItemInfo_Value(item, p1, b)
    r.SetMediaItemInfo_Value(item, p2, a)
end

function GetItemUnderMouse()
    local x, y = r.GetMousePosition()
    local item = r.GetItemFromPoint(x, y, true)
    return item
end

r.Undo_BeginBlock()

local savedRazorEdits = SaveRazorEdits()

local razor = GetRazorEdits()
local combined = {}
for i = 1, #razor do table.insert(combined, razor[i]) end

local itemsToReverse = {}
if #combined > 0 then
    itemsToReverse = SplitAreas(combined)
elseif r.CountSelectedMediaItems(0) > 0 then
    for i = 0, r.CountSelectedMediaItems(0)-1 do
        itemsToReverse[#itemsToReverse+1] = r.GetSelectedMediaItem(0, i)
    end
else
    local itemUnderMouse = GetItemUnderMouse()
    if itemUnderMouse then
        itemsToReverse[1] = itemUnderMouse
    end
end

local prevSelectedItems = {}
for i = 0, r.CountSelectedMediaItems(0)-1 do
    prevSelectedItems[#prevSelectedItems+1] = r.GetSelectedMediaItem(0, i)
end

r.SelectAllMediaItems(0, false)

for i = 1, #itemsToReverse do
    local item = itemsToReverse[i]
    local take = r.GetActiveTake(item)
    if take and not r.TakeIsMIDI(take) then
        local len = r.GetMediaItemInfo_Value(item, "D_LENGTH")
        local snap = r.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
        if snap == 0 or snap >= len then
            r.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", 0)
        else
            r.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", len - snap)
        end

        swap(item, 'D_FADEINLEN', 'D_FADEOUTLEN')
        swap(item, 'D_FADEINDIR', 'D_FADEOUTDIR')
        swap(item, 'C_FADEINSHAPE', 'C_FADEOUTSHAPE')
    end

    r.SetMediaItemSelected(item, true)
    r.Main_OnCommand(41051, 0)
    r.SetMediaItemSelected(item, false)
end

r.SelectAllMediaItems(0, false)
for i = 1, #prevSelectedItems do
    r.SetMediaItemSelected(prevSelectedItems[i], true)
end

RestoreRazorEdits(savedRazorEdits)

r.Undo_EndBlock("Smart Reverse", -1)
r.UpdateArrange()