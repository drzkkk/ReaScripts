-- @description Arpeggio Generator
-- @version 1.1
-- @tags arpeggio, midi, notes
-- @changelog First version
-- @author drzk

local ctx = reaper.ImGui_CreateContext("Arpeggio Generator")
local FONT = reaper.ImGui_CreateFont("sans-serif", 16)
reaper.ImGui_Attach(ctx, FONT)

local NOTES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local ARP_DIRECTIONS = {"Up", "Down", "Random"}

local root_note_idx = 0
local root_octave = 5
local arp_direction_idx = 0

local note_length_options = {
  {label = "1/32", ppq = 120},
  {label = "1/16", ppq = 240},
  {label = "1/8",  ppq = 480},
  {label = "1/4",  ppq = 960},
  {label = "1/2",  ppq = 1920},
  {label = "1",    ppq = 3840},
}

local selected_note_length_idx = 3

local function get_note_number(note_idx_0based, octave)
  return (octave + 1) * 12 + note_idx_0based
end

local function generate_arp_notes(root_note_num, direction_idx, count)
  local octave_step = 12
  local notes = {}
  if count < 1 then count = 1 end

  if direction_idx == 0 then
    for i = 0, count - 1 do
      notes[#notes + 1] = (i % 2 == 0) and root_note_num or math.min(root_note_num + octave_step, 127)
    end
  elseif direction_idx == 1 then
    for i = 0, count - 1 do
      notes[#notes + 1] = (i % 2 == 0) and math.min(root_note_num + octave_step, 127) or root_note_num
    end
  else
    for i = 1, count do
      if math.random() < 0.5 then
        notes[#notes + 1] = root_note_num
      else
        notes[#notes + 1] = math.min(root_note_num + octave_step, 127)
      end
    end
  end

  return notes
end

local function insert_arp(notes, note_length_ppq, take, start_ppq)
  local max_notes = #notes
  local end_ppq = start_ppq + max_notes * note_length_ppq
  local _, total_notes = reaper.MIDI_CountEvts(take)

  for i = total_notes - 1, 0, -1 do
    local _, _, _, note_start, note_end = reaper.MIDI_GetNote(take, i)
    if not (note_end <= start_ppq or note_start >= end_ppq) then
      reaper.MIDI_DeleteNote(take, i)
    end
  end

  for i = 1, max_notes do
    local pitch = notes[((i - 1) % #notes) + 1]
    if pitch >= 0 and pitch <= 127 then
      local note_start = start_ppq + (i - 1) * note_length_ppq
      local note_end = note_start + note_length_ppq
      reaper.MIDI_InsertNote(take, false, false, note_start, note_end, 0, pitch, 100, false)
    end
  end
end

local function arpeggiate_selected_or_all(note_length_ppq, direction_idx)
  local item = reaper.GetSelectedMediaItem(0, 0)
  if not item then
    reaper.ShowMessageBox("Select a MIDI item first.", "Error", 0)
    return
  end
  local take = reaper.GetActiveTake(item)
  if not take or not reaper.TakeIsMIDI(take) then
    reaper.ShowMessageBox("Selected item is not a MIDI take.", "Error", 0)
    return
  end

  local _, note_count = reaper.MIDI_CountEvts(take)
  if note_count == 0 then
    reaper.ShowMessageBox("No notes in the MIDI take.", "Error", 0)
    return
  end

  local notes_to_process = {}
  local has_selected = false
  for i = 0, note_count - 1 do
    local _, selected, _, startppq, endppq, _, pitch = reaper.MIDI_GetNote(take, i)
    if selected then
      has_selected = true
      table.insert(notes_to_process, {start = startppq, finish = endppq, pitch = pitch})
    end
  end
  if not has_selected then
    for i = 0, note_count - 1 do
      local _, _, _, startppq, endppq, _, pitch = reaper.MIDI_GetNote(take, i)
      table.insert(notes_to_process, {start = startppq, finish = endppq, pitch = pitch})
    end
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  for i = note_count - 1, 0, -1 do
    local _, _, _, startppq, endppq = reaper.MIDI_GetNote(take, i)
    for _, note in ipairs(notes_to_process) do
      if not (endppq <= note.start or startppq >= note.finish) then
        reaper.MIDI_DeleteNote(take, i)
        break
      end
    end
  end

  for _, note in ipairs(notes_to_process) do
    local total_len = note.finish - note.start
    local count = math.floor(total_len / note_length_ppq)
    if count < 1 then count = 1 end

    local arp_notes = generate_arp_notes(note.pitch, direction_idx, count)

    for i = 1, #arp_notes do
      local start_pos = note.start + (i - 1) * note_length_ppq
      local end_pos = start_pos + note_length_ppq
      if arp_notes[i] >= 0 and arp_notes[i] <= 127 then
        reaper.MIDI_InsertNote(take, false, false, start_pos, end_pos, 0, arp_notes[i], 100, false)
      end
    end
  end

  reaper.MIDI_Sort(take)
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Arpeggiate Selected or All", -1)
end

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local res = {}
  for k,v in pairs(t) do
    res[k] = deepcopy(v)
  end
  return res
end

local function chord_arp(note_length_ppq, direction_idx)
  local item = reaper.GetSelectedMediaItem(0, 0)
  if not item then
    reaper.ShowMessageBox("Select a MIDI item first.", "Error", 0)
    return
  end
  local take = reaper.GetActiveTake(item)
  if not take or not reaper.TakeIsMIDI(take) then
    reaper.ShowMessageBox("Selected item is not a MIDI take.", "Error", 0)
    return
  end

  local _, note_count = reaper.MIDI_CountEvts(take)
  if note_count == 0 then
    reaper.ShowMessageBox("No notes in the MIDI take.", "Error", 0)
    return
  end

  local notes_to_process = {}
  local has_selected = false
  for i = 0, note_count - 1 do
    local _, selected, _, startppq, _, _, pitch = reaper.MIDI_GetNote(take, i)
    if selected then
      has_selected = true
    end
  end
  for i = 0, note_count - 1 do
    local _, selected, _, startppq, endppq, _, pitch = reaper.MIDI_GetNote(take, i)
    if (has_selected and selected) or (not has_selected) then
      table.insert(notes_to_process, {start = startppq, finish = endppq, pitch = pitch})
    end
  end

  local groups = {}
  for _, note in ipairs(notes_to_process) do
    groups[note.start] = groups[note.start] or {}
    table.insert(groups[note.start], note)
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  for i = note_count -1, 0, -1 do
    local _, _, _, startppq, endppq = reaper.MIDI_GetNote(take, i)
    for group_start, group_notes in pairs(groups) do
      for _, note in ipairs(group_notes) do
        if not (endppq <= note.start or startppq >= note.finish) then
          reaper.MIDI_DeleteNote(take, i)
          break
        end
      end
    end
  end

  local function sort_notes(notes, dir)
    if dir == 0 then
      table.sort(notes, function(a,b) return a.pitch < b.pitch end)
    elseif dir == 1 then
      table.sort(notes, function(a,b) return a.pitch > b.pitch end)
    elseif dir == 2 then
      local shuffled = {}
      for i=1,#notes do shuffled[i] = notes[i] end
      for i=#shuffled,2,-1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
      end
      return shuffled
    else
      return notes
    end
    return notes
  end

  for group_start, group_notes in pairs(groups) do
    local sorted_notes = sort_notes(deepcopy(group_notes), direction_idx)

    local max_len = 0
    for _, n in ipairs(group_notes) do
      local len = n.finish - n.start
      if len > max_len then max_len = len end
    end

    local count = math.floor(max_len / note_length_ppq)
    if count < 1 then count = 1 end

    local pos = group_start
    local idx = 1
    for i = 1, count do
      local n = sorted_notes[((idx - 1) % #sorted_notes) + 1]
      local note_start = pos + (i - 1) * note_length_ppq
      local note_end = note_start + note_length_ppq
      reaper.MIDI_InsertNote(take, false, false, note_start, note_end, 0, n.pitch, 100, false)
      idx = idx + 1
    end
  end

  reaper.MIDI_Sort(take)
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Chord Arpeggiate", -1)
end

local function loop()
  reaper.ImGui_SetNextWindowSize(ctx, 300, 190, reaper.ImGui_Cond_Always())
  local window_flags = reaper.ImGui_WindowFlags_NoResize()
  local visible, open = reaper.ImGui_Begin(ctx, "Arpeggio Generator", true, window_flags)
  if visible then
    reaper.ImGui_PushFont(ctx, FONT)

    local changed

    changed, root_note_idx = reaper.ImGui_SliderInt(
      ctx,
      "##RootNoteSlider",
      root_note_idx,
      0,
      #NOTES - 1,
      NOTES[root_note_idx + 1] .. tostring(root_octave)
    )
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "-##OctDown") then
      root_octave = math.max(0, root_octave - 1)
    end
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, "Oct")
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "+##OctUp") then
      root_octave = math.min(9, root_octave + 1)
    end

    reaper.ImGui_AlignTextToFramePadding(ctx)
    reaper.ImGui_Text(ctx, note_length_options[selected_note_length_idx].label)
    reaper.ImGui_SameLine(ctx, 45)
    if reaper.ImGui_Button(ctx, "-##LenDown") then
      selected_note_length_idx = math.max(1, selected_note_length_idx - 1)
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "+##LenUp") then
      selected_note_length_idx = math.min(#note_length_options, selected_note_length_idx + 1)
    end

    reaper.ImGui_SameLine(ctx, 95)
    reaper.ImGui_Text(ctx, ARP_DIRECTIONS[arp_direction_idx + 1])
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "-##DirDown") then
      arp_direction_idx = (arp_direction_idx - 1) % #ARP_DIRECTIONS
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "+##DirUp") then
      arp_direction_idx = (arp_direction_idx + 1) % #ARP_DIRECTIONS
    end

    if reaper.ImGui_Button(ctx, "Random notes (In Octave)") then
      local root_note_num = get_note_number(root_note_idx, root_octave)
      local item = reaper.GetSelectedMediaItem(0, 0)
      if item then
        local take = reaper.GetActiveTake(item)
        if take and reaper.TakeIsMIDI(take) then
          local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
          local item_length_sec = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
          local ppq_start = reaper.MIDI_GetPPQPosFromProjTime(take, item_start)
          local ppq_end = reaper.MIDI_GetPPQPosFromProjTime(take, item_start + item_length_sec)
          local item_length_ppq = ppq_end - ppq_start
          local length_ppq = note_length_options[selected_note_length_idx].ppq
          local max_notes = math.floor(item_length_ppq / length_ppq + 0.999)
          local full_random_notes = {}
          for i = 1, max_notes do
            full_random_notes[#full_random_notes + 1] = math.random(root_note_num, math.min(root_note_num + 12, 127))
          end
          insert_arp(full_random_notes, length_ppq, take, ppq_start)
        end
      end
    end
   if reaper.ImGui_Button(ctx, "Arpeggio for Chord/s") then
      local length_ppq = note_length_options[selected_note_length_idx].ppq
      chord_arp(length_ppq, arp_direction_idx)
    end

    if reaper.ImGui_Button(ctx, "Arpeggio for Note/s") then
      local length_ppq = note_length_options[selected_note_length_idx].ppq
      arpeggiate_selected_or_all(length_ppq, arp_direction_idx)
    end
    if reaper.ImGui_Button(ctx, "New Arpeggio (With Settings)") then
      local root_note_num = get_note_number(root_note_idx, root_octave)
      local length_ppq = note_length_options[selected_note_length_idx].ppq
      local item = reaper.GetSelectedMediaItem(0, 0)
      if item then
        local take = reaper.GetActiveTake(item)
        if take and reaper.TakeIsMIDI(take) then
          local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
          local item_length_sec = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
          local ppq_start = reaper.MIDI_GetPPQPosFromProjTime(take, item_start)
          local ppq_end = reaper.MIDI_GetPPQPosFromProjTime(take, item_start + item_length_sec)
          local item_length_ppq = ppq_end - ppq_start
          local max_notes = math.floor(item_length_ppq / length_ppq + 0.999)
          local base_pattern = generate_arp_notes(root_note_num, arp_direction_idx, max_notes)
          insert_arp(base_pattern, length_ppq, take, ppq_start)
        end
      end
    end


    reaper.ImGui_PopFont(ctx)
    reaper.ImGui_End(ctx)
  end

  if open then reaper.defer(loop) end
end

math.randomseed(os.time())
reaper.defer(loop)