-- @description Select MIDI note to the right of current selection
-- @version 1.0
-- @tags midi, notes, select
-- @changelog First version
-- @author drzk

local editor = reaper.MIDIEditor_GetActive()
if not editor then return end
local take = reaper.MIDIEditor_GetTake(editor)
if not take then return end

local _, note_count = reaper.MIDI_CountEvts(take)
if note_count == 0 then return end

local current_note = nil
for i=0, note_count-1 do
  local _, selected, _, startppq, _, _, pitch = reaper.MIDI_GetNote(take,i)
  if selected then
    current_note = {startppq=startppq, pitch=pitch}
    break
  end
end
if not current_note then return end

local candidates = {}
for i=0, note_count-1 do
  local _, _, _, startppq, _, _, pitch = reaper.MIDI_GetNote(take,i)
  if startppq > current_note.startppq then
    table.insert(candidates, {index=i, startppq=startppq, pitch=pitch})
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
  table.sort(same_pitch_candidates, function(a,b) return a.startppq < b.startppq end)
  target = same_pitch_candidates[1]
else

  table.sort(candidates, function(a,b) return a.startppq < b.startppq end)
  
  local min_pitch_diff = 128
  local min_pitch_diff_candidates = {}
  for _, c in ipairs(candidates) do
    local pitch_diff = math.abs(c.pitch - current_note.pitch)
    if pitch_diff < min_pitch_diff then
      min_pitch_diff = pitch_diff
      min_pitch_diff_candidates = {c}
    elseif pitch_diff == min_pitch_diff then
      table.insert(min_pitch_diff_candidates, c)
    end
  end
  
  table.sort(min_pitch_diff_candidates, function(a,b) return a.startppq < b.startppq end)
  target = min_pitch_diff_candidates[1]
end

for i=0, note_count-1 do
  local retval, sel, mut, sppq, eppq, ch, pit, vel = reaper.MIDI_GetNote(take,i)
  reaper.MIDI_SetNote(take,i,false,mut,sppq,eppq,ch,pit,vel,false)
end

local retval, _, mut, sppq, eppq, ch, pit, vel = reaper.MIDI_GetNote(take,target.index)
reaper.MIDI_SetNote(take,target.index,true,mut,sppq,eppq,ch,pit,vel,false)

reaper.MIDI_Sort(take)