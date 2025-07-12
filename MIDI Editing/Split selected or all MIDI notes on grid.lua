-- @description Split selected or all MIDI notes on grid
-- @version 1.0
-- @tags midi, split midi notes, grid
-- @changelog First version
-- @author drzk

local editor = reaper.MIDIEditor_GetActive()
if not editor then return end
local take = reaper.MIDIEditor_GetTake(editor)
if not take then return end

local function hasSelectedNotes(take)
  local idx = 0
  while true do
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, idx)
    if not retval then break end
    if selected then return true end
    idx = idx + 1
  end
  return false
end

local function selectAllNotes(take)
  local idx = 0
  while true do
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, idx)
    if not retval then break end
    reaper.MIDI_SetNote(take, idx, true, muted, startppqpos, endppqpos, chan, pitch, vel, false)
    idx = idx + 1
  end
end

if not hasSelectedNotes(take) then
  selectAllNotes(take)
  reaper.MIDI_Sort(take)
end

reaper.MIDIEditor_OnCommand(editor, 40641)
reaper.MIDI_Sort(take)