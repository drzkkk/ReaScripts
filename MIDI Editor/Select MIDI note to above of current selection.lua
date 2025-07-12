-- @description Select MIDI note to above of current selection
-- @version 1.1
-- @tags midi, notes, select
-- @changelog Added logic to select lowest note if none selected
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
  local lowest_index = 0
  local _, _, _, _, _, _, lowest_pitch = r.MIDI_GetNote(take, 0)

  for i = 1, note_count - 1 do
    local _, _, _, _, _, _, pitch = r.MIDI_GetNote(take, i)
    if pitch < lowest_pitch then
      lowest_index = i
      lowest_pitch = pitch
    end
  end

  for i = 0, note_count - 1 do
    local ret, sel, mut, sppq, eppq, ch, pit, vel = r.MIDI_GetNote(take, i)
    r.MIDI_SetNote(take, i, false, mut, sppq, eppq, ch, pit, vel, false)
  end


  local ret, _, mut, sppq, eppq, ch, pit, vel = r.MIDI_GetNote(take, lowest_index)
  r.MIDI_SetNote(take, lowest_index, true, mut, sppq, eppq, ch, pit, vel, false)

  r.MIDI_Sort(take)
  return
end

local TIME_SCALE = 480

local candidates = {}
for i = 0, note_count - 1 do
  local _, _, _, startppq, _, _, pitch = r.MIDI_GetNote(take, i)
  if pitch > current_note.pitch then
    table.insert(candidates, { index = i, startppq = startppq, pitch = pitch })
  end
end
if #candidates == 0 then return end

local function distance(cand)
  local dp = cand.pitch - current_note.pitch
  local dt = (cand.startppq - current_note.startppq) / TIME_SCALE
  return math.sqrt(dp * dp + dt * dt)
end

table.sort(candidates, function(a, b) return distance(a) < distance(b) end)
local target = candidates[1]

for i = 0, note_count - 1 do
  local retval, sel, mut, sppq, eppq, ch, pit, vel = r.MIDI_GetNote(take, i)
  r.MIDI_SetNote(take, i, false, mut, sppq, eppq, ch, pit, vel, false)
end

local retval, _, mut, sppq, eppq, ch, pit, vel = r.MIDI_GetNote(take, target.index)
r.MIDI_SetNote(take, target.index, true, mut, sppq, eppq, ch, pit, vel, false)

r.MIDI_Sort(take)