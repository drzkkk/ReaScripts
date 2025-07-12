-- @description Toggle mute for selected MIDI notes or note under mouse if none selected
-- @version 1.0
-- @tags midi, mute midi notes
-- @changelog First version
-- @author drzk

local function CountSelectedMIDINotes(take)
  local _, noteCount = reaper.MIDI_CountEvts(take)
  local count = 0
  for i = 0, noteCount - 1 do
    local _, selected = reaper.MIDI_GetNote(take, i)
    if selected then count = count + 1 end
  end
  return count
end

local function MuteNoteUnderMouse()
  local MIDIEditor = reaper.MIDIEditor_GetActive()
  if not MIDIEditor then return false end
  local take = reaper.MIDIEditor_GetTake(MIDIEditor)
  if not take or not reaper.TakeIsMIDI(take) then return false end

  local window, segment, details = reaper.BR_GetMouseCursorContext()
  if window ~= "midi_editor" or segment ~= "notes" then return false end

  local noteRow = ({reaper.BR_GetMouseCursorContext_MIDI()})[3]
  if noteRow < 0 then return false end

  local mouseTime = reaper.BR_GetMouseCursorContext_Position()
  local ppqPosition = reaper.MIDI_GetPPQPosFromProjTime(take, mouseTime)

  local retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
  if notecnt == 0 then return false end

  for i = 0, notecnt - 1 do
    local retval, selected, muted, startNote, endNote, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if startNote <= ppqPosition and endNote >= ppqPosition and pitch == noteRow then
      reaper.MIDI_SetNote(take, i, nil, not muted, nil, nil, nil, nil, nil, false)
      reaper.MIDI_Sort(take)
      return true
    end
  end

  return false
end

local function main()
  local editor = reaper.MIDIEditor_GetActive()
  if not editor then return end
  local take = reaper.MIDIEditor_GetTake(editor)
  if not take or not reaper.TakeIsMIDI(take) then return end

  reaper.Undo_BeginBlock()

  if CountSelectedMIDINotes(take) > 0 then
    reaper.MIDIEditor_OnCommand(editor, 40055)
  else
    MuteNoteUnderMouse()
  end

  reaper.Undo_EndBlock("Toggle mute selected notes or note under mouse", -1)
  reaper.UpdateArrange()
end

main()