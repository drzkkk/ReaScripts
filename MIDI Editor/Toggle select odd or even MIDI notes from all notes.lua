-- @description Toggle select odd or even MIDI notes from all notes
-- @version 1.0
-- @tags midi, notes, select
-- @changelog First version
-- @author drzk

local r = reaper

local editor = r.MIDIEditor_GetActive()
if not editor then return end

local take = r.MIDIEditor_GetTake(editor)
if not take or not r.TakeIsMIDI(take) then return end

local _, note_count = r.MIDI_CountEvts(take)
if note_count == 0 then return end

-- Считываем все ноты
local notes = {}
for i = 0, note_count - 1 do
  local _, sel, muted, startppq, endppq, chan, pitch, vel = r.MIDI_GetNote(take, i)
  notes[#notes + 1] = {
    index = i,
    sel = sel,
    muted = muted,
    startppq = startppq,
    endppq = endppq,
    chan = chan,
    pitch = pitch,
    vel = vel
  }
end

table.sort(notes, function(a, b) return a.startppq < b.startppq end)

local last_ppq = -1
local odd = true
local odd_indices = {}
local even_indices = {}

for _, note in ipairs(notes) do
  if note.startppq ~= last_ppq then
    odd = not odd
    last_ppq = note.startppq
  end
  if odd then
    odd_indices[note.index] = true
  else
    even_indices[note.index] = true
  end
end

local odd_selected = true
for _, note in ipairs(notes) do
  if odd_indices[note.index] and not note.sel then
    odd_selected = false
    break
  end
  if not odd_indices[note.index] and note.sel then
    odd_selected = false
    break
  end
end

local select_indices = odd_selected and even_indices or odd_indices

r.Undo_BeginBlock()
r.PreventUIRefresh(1)

for _, note in ipairs(notes) do
  local sel = select_indices[note.index] == true
  r.MIDI_SetNote(take, note.index, sel, note.muted, note.startppq, note.endppq, note.chan, note.pitch, note.vel)
end

r.PreventUIRefresh(-1)
r.Undo_EndBlock("Toggle odd/even notes", -1)
r.MIDI_Sort(take)