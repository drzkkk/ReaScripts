-- @description Smart coloring tracks & folders
-- @version 1.0
-- @tags track coloring, color
-- @changelog First version
-- @author drzk

function SetTrackAndItemsColor(track, color)
  if not track then return end
  reaper.SetMediaTrackInfo_Value(track, 'I_CUSTOMCOLOR', color | 0x1000000)

  local itemCount = reaper.CountTrackMediaItems(track)
  for i = 0, itemCount - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    reaper.SetMediaItemInfo_Value(item, 'I_CUSTOMCOLOR', color | 0x1000000)
  end
end

function GetSelectedTracks()
  local t = {}
  local count = reaper.CountSelectedTracks(0)
  for i = 0, count - 1 do
    t[#t + 1] = reaper.GetSelectedTrack(0, i)
  end
  return t
end

function IsFolder(track)
  return reaper.GetMediaTrackInfo_Value(track, 'I_FOLDERDEPTH') == 1
end

function GetFolderChildren(folderTrack)
  local t = {}
  local idx = reaper.GetMediaTrackInfo_Value(folderTrack, 'IP_TRACKNUMBER') - 1
  local total = reaper.CountTracks(0)
  local depth = 1
  for i = idx + 1, total - 1 do
    local tr = reaper.GetTrack(0, i)
    local d = reaper.GetMediaTrackInfo_Value(tr, 'I_FOLDERDEPTH')
    t[#t + 1] = tr
    if d == 1 then depth = depth + 1 end
    if d == -1 then depth = depth - 1 end
    if depth <= 0 then break end
  end
  return t
end

function AllTracksHaveColor(tracks, color)
  for _, tr in ipairs(tracks) do
    local c = reaper.GetMediaTrackInfo_Value(tr, 'I_CUSTOMCOLOR')
    if c ~= color then return false end
  end
  return true
end

function RandomColorSingleTrack(track)
  if not track then return end
  local prevSelected = {}
  for i = 0, reaper.CountSelectedTracks(0)-1 do
    prevSelected[#prevSelected+1] = reaper.GetSelectedTrack(0,i)
  end

  reaper.Main_OnCommand(40297, 0)
  reaper.SetTrackSelected(track, true)
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_RANDOMCOLALL"), 0)

  local newColor = reaper.GetMediaTrackInfo_Value(track, 'I_CUSTOMCOLOR')
  SetTrackAndItemsColor(track, newColor)

  reaper.Main_OnCommand(40297, 0)
  for _, tr in ipairs(prevSelected) do
    reaper.SetTrackSelected(tr, true)
  end
end

function RandomColorMultipleTracksIndividually(tracks)
  for _, tr in ipairs(tracks) do
    RandomColorSingleTrack(tr)
  end
end

function RunRandomColorAndApplyToItemsForTracks(tracks)

  local prevSelected = {}
  for i = 0, reaper.CountSelectedTracks(0)-1 do
    prevSelected[#prevSelected+1] = reaper.GetSelectedTrack(0,i)
  end

  reaper.Main_OnCommand(40297, 0)
  for _, tr in ipairs(tracks) do
    reaper.SetTrackSelected(tr, true)
  end

  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_RANDOMCOLALL"), 0)

  for _, tr in ipairs(tracks) do
    local c = reaper.GetMediaTrackInfo_Value(tr, 'I_CUSTOMCOLOR')
    SetTrackAndItemsColor(tr, c)
  end

  reaper.Main_OnCommand(40297, 0)
  for _, tr in ipairs(prevSelected) do
    reaper.SetTrackSelected(tr, true)
  end
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local selectedTracks = GetSelectedTracks()
local selCount = #selectedTracks

if selCount >= 2 then
  local baseColor = reaper.GetMediaTrackInfo_Value(selectedTracks[1], 'I_CUSTOMCOLOR')
  if AllTracksHaveColor(selectedTracks, baseColor) then
    RandomColorMultipleTracksIndividually(selectedTracks)
  else
    for i = 1, selCount do
      SetTrackAndItemsColor(selectedTracks[i], baseColor)
    end
  end

elseif selCount == 1 then
  local track = selectedTracks[1]

  if IsFolder(track) then
    local folderColor = reaper.GetMediaTrackInfo_Value(track, 'I_CUSTOMCOLOR')
    local children = GetFolderChildren(track)

    if #children > 0 and AllTracksHaveColor(children, folderColor) then
      local group = {track}
      for _, tr in ipairs(children) do group[#group+1] = tr end
      RunRandomColorAndApplyToItemsForTracks(group)
    else
      for _, tr in ipairs(children) do
        SetTrackAndItemsColor(tr, folderColor)
      end
    end

  else
    RandomColorSingleTrack(track)
  end
end

reaper.UpdateArrange()
reaper.TrackList_AdjustWindows(false)
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Smart color tracks", -1)