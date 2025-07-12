-- @description Select MIDI note to the left of current selection
-- @version 1.1
-- @tags midi, notes, select
-- @changelog Added logic to select latest note if none selected
-- @author drzk

local r = reaper

local editor = r.MIDIEditor_GetActive()
if not editor then return end
local take = r.MIDIEditor_GetTake(editor)
if not take then return end

local _, note_count = r.MIDI_CountEvts(take)
if note_count == 0 then return end

local current_note = nil
for i = 0, note_count - 1 do
  local _, selected, _, startppq, _, _, pitch = r.MIDI_GetNote(take, i)
  if selected then
    current_note = { startppq = startppq, pitch = pitch }
    break
  end
end

if not current_note then
  local last_index = 0
  local _, _, _, last_ppq = r.MIDI_GetNote(take, 0)
  for i = 1, note_count - 1 do
    local _, _, _, ppq = r.MIDI_GetNote(take, i)
    if ppq > last_ppq then
      last_index = i
      last_ppq = ppq
    end
  end

  for i = 0, note_count - 1 do
    local ret, sel, mut, sppq, eppq, ch, pit, vel = r.MIDI_GetNote(take, i)
    r.MIDI_SetNote(take, i, false, mut, sppq, eppq, ch, pit, vel, false)
  end

  local ret, _, mut, sppq, eppq, ch, pit, vel = r.MIDI_GetNote(take, last_index)
  r.MIDI_SetNote(take, last_index, true, mut, sppq, eppq, ch, pit, vel, false)

  r.MIDI_Sort(take)
  return
end

local candidates = {}
for i = 0, note_count - 1 do
  local _, _, _, startppq, _, _, pitch = r.MIDI_GetNote(take, i)
  if startppq < current_note.startppq then
    table.insert(candidates, { index = i, startppq = startppq, pitch = pitch })
  end
end
if #candidates == 0 then return end

local same_pitch_candidates = {}
for _, c in ipairs(candidates) do
  if c.pitch == current_note.pitch then
    table.insert(same_pitch_candidates, c)
  end
end

local target = nil

if #same_pitch_candidates > 0 then
  table.sort(same_pitch_candidates, function(a, b) return a.startppq > b.startppq end)
  target = same_pitch_candidates[1]
else
  table.sort(candidates, function(a, b) return a.startppq > b.startppq end)

  local min_pitch_diff = 128
  local min_pitch_diff_candidates = {}
  for _, c in ipairs(candidates) do
    local pitch_diff = math.abs(c.pitch - current_note.pitch)
    if pitch_diff < min_pitch_diff then
      min_pitch_diff = pitch_diff
      min_pitch_diff_candidates = { c }
    elseif pitch_diff == min_pitch_diff then
      table.insert(min_pitch_diff_candidates, c)
    end
  end

  table.sort(min_pitch_diff_candidates, function(a, b) return a.startppq > b.startppq end)
  target = min_pitch_diff_candidates[1]
end

for i = 0, note_count - 1 do
  local retval, sel, mut, sppq, eppq, ch, pit, vel = r.MIDI_GetNote(take, i)
  r.MIDI_SetNote(take, i, false, mut, sppq, eppq, ch, pit, vel, false)
end

local retval, _, mut, sppq, eppq, ch, pit, vel = r.MIDI_GetNote(take, target.index)
r.MIDI_SetNote(take, target.index, true, mut, sppq, eppq, ch, pit, vel, false)

r.MIDI_Sort(take)