-- @description Move MIDI notes up one semitone if none selected, move all notes
-- @version 1.0
-- @tags midi, notes, move notes up
-- @changelog First version
-- @author drzk

local transposeAmount = 1

local function CountSelectedMIDINotes(take)
  local _, noteCount = reaper.MIDI_CountEvts(take)
  local count = 0
  for i = 0, noteCount - 1 do
    local _, selected = reaper.MIDI_GetNote(take, i)
    if selected then count = count + 1 end
  end
  return count
end

local function transposeNotes(take, amount, onlySelected)
  local _, noteCount = reaper.MIDI_CountEvts(take)
  for i = 0, noteCount - 1 do
    local retval, selected, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if retval and (not onlySelected or selected) then
      local newPitch = pitch + amount
      if newPitch >= 0 and newPitch <= 127 then
        reaper.MIDI_SetNote(take, i, nil, nil, nil, nil, nil, newPitch, nil, false)
      end
    end
  end
  reaper.MIDI_Sort(take)
end

local function main()
  local numItems = reaper.CountSelectedMediaItems(0)
  if numItems == 0 then return end

  local takes = {}
  local anySelectedNotes = false

  for i = 0, numItems -1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    if item then
      local take = reaper.GetActiveTake(item)
      if take and reaper.TakeIsMIDI(take) then
        takes[#takes+1] = take
        if not anySelectedNotes and CountSelectedMIDINotes(take) > 0 then
          anySelectedNotes = true
        end
      end
    end
  end

  reaper.Undo_BeginBlock()

  for _, take in ipairs(takes) do
    if anySelectedNotes then
      transposeNotes(take, transposeAmount, true)
    else
      transposeNotes(take, transposeAmount, false)
    end
  end

  reaper.Undo_EndBlock("Move notes up one semitone", -1)
  reaper.UpdateArrange()
end

main()