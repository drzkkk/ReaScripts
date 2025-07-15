-- @description Auto name track from instrument FX or Media (cleaned) (background)
-- @version 1.2
-- @changelog Fixed tags
-- @tags fx, fx chain, instrument, name, auto
-- @author drzk

-- @about
--   Automatically renames a track based on the name of the first instrument plugin
--   (e.g., "Serum", "Kontakt") or the first media item (e.g., "Vocal.wav").
--   Cleans names by removing numbers, suffixes, and unnecessary characters
--   (e.g., "152 BPM A Min Vocal 3.wav" becomes "Vocal").
--   Designed to run in the background.

local prev_fx_table = {}
local prev_inst_table = {}
local prev_item_ids = {}
local prev_item_count = {}
local track_pending_rename = {}
local prev_auto_name = {}

local last_change_count = reaper.GetProjectStateChangeCount()

local special_names = {
  "Pad", "Vocal", "Acapella", "Bass", "Arpeggio", "Arp", "Synth", "Hat", "Kick", "Snare", "Clap",
  "Percussion", "Tom", "Cymbal", "Crash", "Ride", "Rim", "Lead", "Chords", "BuildUp", "Build-up", "Shaker", "Drums", "Top Drum Loop", "Drum Loop",
  "Drone", "Atmosphere", "FX", "Impact", "Ambiance", "Sweep", "Riser", "Vinyl", "Brass", "Flute", "Guitar", "Piano", "Keys", "Strings", "Fill", "Amen", "Vox", "Cowbell", "Bell", "Phrase", "Tambourine", "Transition"
}

local function SanitizeFileName(path)
  local name = path:match("([^/\\]+)$") or path
  return name:gsub("%..-$", ""):match("^%s*(.-)%s*$")
end

local function SanitizeFXName(name)
  name = name:gsub("VSTi:%s*", "")
  name = name:gsub("VST3:%s*", "")
  name = name:gsub("VST:%s*", "")
  name = name:gsub("%(.-%)", "")
  name = name:match("([^/\\]+)$") or name
  name = name:match("^[^%:]+:%s*(.*)$") or name
  name = name:gsub("%.dll$", "")
  name = name:gsub("%.vst3$", "")
  return name:match("^%s*(.-)%s*$")
end

local function CheckSpecialName(name)
  if not name then return nil end
  local lname = name:lower()
  
  if lname:find("vocal") then
    if lname:find("female") then return "Vocal female" end
    if lname:find("male") then return "Vocal male" end
    if lname:find("pad") then return "Vocal pad" end
    if lname:find("synth") then return "Vocal synth" end
    if lname:find("chop") then return "Vocal chop" end
    return "Vocal"
  end
  if lname:find("loop") then
    if lname:find("melody") then return "Melody loop" end
    if lname:find("lead") then return "Lead loop" end
    if lname:find("bass") then return "Bass loop" end
    if lname:find("pad") then return "Pad loop" end
    if lname:find("arp") then return "Arp loop" end
    if lname:find("chord") then return "Chord loop" end
    if lname:find("organ") then return "Organ loop" end
    if lname:find("orchestra") then return "Orchestra loop" end
    if lname:find("guitar") then return "Guitar loop" end
    if lname:find("granular") then return "Granular loop" end
    if lname:find("texture") then return "Texture loop" end
    if lname:find("melodic") then return "Melodic loop" end
    if lname:find("shaker") then return "Shaker loop" end
    if lname:find("kick") then return "Kick loop" end
    if lname:find("snare") then return "Snare loop" end
    if lname:find("clap") then return "Clap loop" end
    if lname:find("hat") then return "Hat loop" end
    if lname:find("cowbell") then return "Cowbell loop" end
    if lname:find("crash") then return "Crash loop" end
    if lname:find("rim") then return "Rim loop" end
    if lname:find("perc") then return "Perc loop" end
    if lname:find("laser") then return "Laser loop" end
    if lname:find("build") then return "BuildUp" end
    if lname:find("synth") then return "Synth loop" end
    if lname:find("top") then return "Top loop" end
    if lname:find("beat") then return "Beat loop" end
    if lname:find("drum") then return "Drum loop" end
  end
  if lname:find("drum") then
    if lname:find("build") then return "BuildUp" end
    if lname:find("fill") then return "Drum Fill" end
    return "Drums"
  end
  if lname:find("laugh") then
    return "Vocal Laugh"
  end
  if lname:find("scream") then
    return "Vocal Scream"
  end
  if lname:find("atmo") then
    return "Atmoshpere"
  end
  if lname:find("hh") or lname:find("chat") then
    return "Hat"
  end
  if lname:find("open hat") or lname:find"(oh)" then
    return "Open hat"
  end
  if lname:find("closed hat") or lname:find"(ch)" then
    return "Closed hat"
  end
  if lname:find("perc") or lname:find("percs") or lname:find("prc") then
    return "Percussion"
  end
  if lname:find("bass") then
    if lname:find("808") then return "Bass 808" end
    if lname:find("reese") then return "Bass reese" end
    return "Bass"
  end
  if lname:find("808") then
    return "Bass 808"
  end
  
  for _, key in ipairs(special_names) do
    if lname:find(key:lower()) then return key end
  end
  return nil
end
local function IsDefaultReaperName(name)
  if not name then return false end
  for _, key in ipairs(special_names) do
    if name:match("^" .. key .. " %d+$") then
      return true
    end
  end
  if name:match("^.+ %d+$") or name:match("^Track %d+$") or name:match("^Item %d+$") then
    return true
  end
  return false
end

local function GetTrackItemsInfo(track)
  local count = reaper.CountTrackMediaItems(track)
  local items = {}
  local names = {}
  for i = 0, count - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    local take = reaper.GetActiveTake(item)
    local name
    if take then
      local ok, takeName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
if ok and takeName ~= "" then
  name = SanitizeFileName(takeName)
else
  local src = reaper.GetMediaItemTake_Source(take)
  local path = reaper.GetMediaSourceFileName(src, "")
  name = SanitizeFileName(path)
end

    end
    if name and name ~= "" then
      items[item] = true
      names[item] = name
    end
  end
  return items, names, count
end

local function SetTrackName(track, guid, name)
  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)
  prev_auto_name[guid] = name
end

local function UpdateTracks()
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local guid = reaper.GetTrackGUID(track)

    local _, cur_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local fx_count = reaper.TrackFX_GetCount(track)
    local inst_index = reaper.TrackFX_GetInstrument(track)
    local inst_name = ""
    if inst_index ~= -1 then
      local _, fxname = reaper.TrackFX_GetFXName(track, inst_index, "")
      inst_name = SanitizeFXName(fxname)
    end

    if cur_name ~= "" and cur_name ~= prev_auto_name[guid] and not IsDefaultReaperName(cur_name) then
      prev_auto_name[guid] = nil
    end

    local prev_fx = prev_fx_table[guid] or 0
    local prev_inst = prev_inst_table[guid] or ""
    local prev_ids = prev_item_ids[guid] or {}
    local prev_count = prev_item_count[guid] or 0
    local items, names, count = GetTrackItemsInfo(track)

    local new_items = false
    for item in pairs(items) do
      if not prev_ids[item] then
        new_items = true
        break
      end
    end

    if new_items then
      if cur_name == "" or cur_name == prev_auto_name[guid] or IsDefaultReaperName(cur_name) or prev_auto_name[guid] == nil then
        local first_item, first_pos = nil, math.huge
        for item in pairs(items) do
          local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
          if pos < first_pos then
            first_pos = pos
            first_item = item
          end
        end
        if first_item then
          local name = names[first_item]
          local special = CheckSpecialName(name)
          SetTrackName(track, guid, special or name)
        end
      end
    end

    if fx_count > prev_fx and (cur_name == "" or cur_name == prev_auto_name[guid] or IsDefaultReaperName(cur_name)) and inst_name ~= "" then
      SetTrackName(track, guid, inst_name)
    elseif fx_count < prev_fx and inst_index == -1 and cur_name == prev_inst then
      SetTrackName(track, guid, "")
    elseif inst_index ~= -1 and cur_name == prev_inst and inst_name ~= prev_inst then
      SetTrackName(track, guid, inst_name)
    end

    if inst_index == -1 and count == 0 and cur_name ~= "" then
      if cur_name == prev_auto_name[guid] or IsDefaultReaperName(cur_name) then
        SetTrackName(track, guid, "")
      end
    end

    prev_fx_table[guid] = fx_count
    prev_inst_table[guid] = inst_name
    prev_item_ids[guid] = items
    prev_item_count[guid] = count
  end
end

local function Main()
  local current_change_count = reaper.GetProjectStateChangeCount()
  if current_change_count ~= last_change_count then
    last_change_count = current_change_count
    UpdateTracks()
  end
  reaper.defer(Main)
end

Main()