-- @description Set velocity 100 for selected or all MIDI notes
-- @version 1.0
-- @tags midi, velocity, notes
-- @changelog First version
-- @author drzk

local midi_editor = reaper.MIDIEditor_GetActive()
if not midi_editor then return end

local take = reaper.MIDIEditor_GetTake(midi_editor)
if not take or not reaper.TakeIsMIDI(take) then return end

reaper.Undo_BeginBlock()

local _, noteCount = reaper.MIDI_CountEvts(take)
local has_selected = false

-- Проверяем, есть ли выделенные ноты
for i = 0, noteCount - 1 do
  local retval, sel = reaper.MIDI_GetNote(take, i)
  if retval and sel then
    has_selected = true
    break
  end
end

for i = 0, noteCount - 1 do
  local retval, sel, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
  if retval then
    if (has_selected and sel) or (not has_selected) then
      reaper.MIDI_SetNote(take, i, sel, muted, startppqpos, endppqpos, chan, pitch, 100, false)
    end
  end
end

reaper.MIDI_Sort(take)
reaper.Undo_EndBlock("Set velocity to 100 for selected or all notes", -1)