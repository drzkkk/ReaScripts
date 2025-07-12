-- @description Duplicate selected MIDI notes one semitone down
-- @version 1.0
-- @tags midi, notes, duplicate
-- @changelog First version
-- @author drzk

local editor = reaper.MIDIEditor_GetActive()
if not editor then return end

local take = reaper.MIDIEditor_GetTake(editor)
if not take or not reaper.TakeIsMIDI(take) then return end

local _, note_count = reaper.MIDI_CountEvts(take)
if note_count == 0 then return end

local selected_notes = {}
local all_notes = {}

for i = 0, note_count - 1 do
  local retval, selected, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
  table.insert(all_notes, {
    index = i,
    selected = selected,
    muted = muted,
    startppq = startppq,
    endppq = endppq,
    chan = chan,
    pitch = pitch,
    vel = vel
  })
  if selected then
    table.insert(selected_notes, {
      startppq = startppq,
      endppq = endppq,
      chan = chan,
      pitch = pitch,
      vel = vel,
      muted = muted
    })
  end
end

if #selected_notes == 0 then return end

local min_selected_pitch = 127
for _, n in ipairs(selected_notes) do
  if n.pitch < min_selected_pitch then min_selected_pitch = n.pitch end
end

local base_pitch = min_selected_pitch - 1
if base_pitch < 0 then return end

local function is_pitch_time_busy(pitch, chan, startppq, endppq)
  for _, n in ipairs(all_notes) do
    if n.chan == chan and n.pitch == pitch then
      if not (endppq <= n.startppq or startppq >= n.endppq) then
        return true
      end
    end
  end
  return false
end

local function find_free_pitch_down(pitch, chan, startppq, endppq)
  local test_pitch = pitch
  while test_pitch >= 0 do
    if not is_pitch_time_busy(test_pitch, chan, startppq, endppq) then
      return test_pitch
    end
    test_pitch = test_pitch - 1
  end
  return nil
end

reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)

for _, n in ipairs(all_notes) do
  reaper.MIDI_SetNote(take, n.index, false, n.muted, n.startppq, n.endppq, n.chan, n.pitch, n.vel, false)
end

for _, note in ipairs(selected_notes) do
  local relative_pitch = note.pitch - min_selected_pitch
  local desired_pitch = base_pitch + relative_pitch
  local free_pitch = find_free_pitch_down(desired_pitch, note.chan, note.startppq, note.endppq)
  if free_pitch then
    reaper.MIDI_InsertNote(
      take,
      true,
      note.muted,
      note.startppq,
      note.endppq,
      note.chan,
      free_pitch,
      note.vel,
      false
    )

    table.insert(all_notes, {
      index = -1,
      selected = true,
      muted = note.muted,
      startppq = note.startppq,
      endppq = note.endppq,
      chan = note.chan,
      pitch = free_pitch,
      vel = note.vel
    })
  end
end

reaper.MIDI_Sort(take)
reaper.Undo_EndBlock("Duplicate selected MIDI notes one semitone down", -1)