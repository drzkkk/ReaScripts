-- @description Create folder from selected tracks (smart naming)
-- @version 1.0
-- @tags tracks, folder
-- @changelog First version
-- @author drzk

local r = reaper

function nothing() end
function bla() r.defer(nothing) end

function get_folder_name_from_tracks(tracks)
  local name_keywords = {
    Claps = { "clap", "clap loop" },
    Percs = { "perc", "perc loop" },
    Snares = { "snare", "snare loop" },
    Hats = { "hat", "hat loop" },
    Drums = { "kick", "clap", "snare", "hat", "drum loop", "drum" },
    Bass = { "bass", "sub" },
    Vocals = { "vocal", "vox", "voice", "vocal male", "vocal female", "phrase" },
    FX = { "fx", "sweep", "impact", "riser", "atmo" },
    Arps = { "arp", "arp loop" },
    Pads = { "pad", "pad loop" },
    Leads = { "lead", "lead loop" },
    Synths = { "synth", "lead", "pluck", "arp", "pad" },
    Guitars = { "guitar" },
  }

  local counts = {}

  for _, tr in ipairs(tracks) do
    if tr then
      local _, name = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
      name = name:lower():match("%S") and name:lower() or nil

      if name then
        for group, keywords in pairs(name_keywords) do
          for _, keyword in ipairs(keywords) do
            if name:match(keyword) then
              counts[group] = (counts[group] or 0) + 1
            end
          end
        end
      end
    end
  end

  local max_count = 0
  local best_group = nil
  for group, count in pairs(counts) do
    if count > max_count then
      max_count = count
      best_group = group
    end
  end

  return best_group
end

function create_folder_from_selected_tracks()
  local sel_count = r.CountSelectedTracks(0)
  if sel_count == 0 then bla() return end

  local selected_tracks = {}
  for i = 0, sel_count - 1 do
    selected_tracks[#selected_tracks + 1] = r.GetSelectedTrack(0, i)
  end

  local first_track = selected_tracks[1]
  local last_track = selected_tracks[#selected_tracks]
  local first_track_num = r.GetMediaTrackInfo_Value(first_track, "IP_TRACKNUMBER")

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  r.InsertTrackAtIndex(first_track_num - 1, true)
  r.TrackList_AdjustWindows(false)
  local folder_track = r.GetTrack(0, first_track_num - 1)

  r.SetMediaTrackInfo_Value(folder_track, "I_FOLDERDEPTH", 1)
  r.SetMediaTrackInfo_Value(last_track, "I_FOLDERDEPTH",
    r.GetMediaTrackInfo_Value(last_track, "I_FOLDERDEPTH") - 1)

  r.PreventUIRefresh(-1)
  r.TrackList_AdjustWindows(true)

  r.SetOnlyTrackSelected(folder_track)
  r.Main_OnCommand(40914, 0)

  local suggested_name = get_folder_name_from_tracks(selected_tracks)
  if suggested_name and suggested_name:match("%S") then
    r.GetSetMediaTrackInfo_String(folder_track, "P_NAME", suggested_name, true)
  else
    r.Main_OnCommand(40696, 0)
  end

  r.Undo_EndBlock("Create folder from selected tracks (smart name)", -1)
end

create_folder_from_selected_tracks()