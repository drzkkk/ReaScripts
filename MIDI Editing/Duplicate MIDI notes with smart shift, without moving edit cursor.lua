-- @description Duplicate MIDI notes with smart shift, without moving edit cursor
-- @version 1.0
-- @tags midi, notes, duplicate
-- @changelog First version
-- @author MPL + small improvements by drzk
-- @about
--   Duplicates selected MIDI notes with an intelligent time shift.
--   Keeps the edit cursor position unchanged.

for key in pairs(reaper) do _G[key]=reaper[key]  end 
---------------------------------------------------
function VF_CheckReaperVrs(rvrs, showmsg) 
  local vrs_num =  GetAppVersion()
  vrs_num = tonumber(vrs_num:match('[%d%.]+'))
  if rvrs > vrs_num then 
    if showmsg then reaper.MB('Update REAPER to newer version '..'('..rvrs..' or newer)', '', 0) end
    return
  else
    return true
  end
end

-----------------------------------------------------------------------------------------  
function SmartDuplicateNotes()
  local ME = MIDIEditor_GetActive()
  if not ME then return end
  local take = MIDIEditor_GetTake(ME)
  if not take then return end
  local data = ParseRAWMIDI(take)
  local item = GetMediaItemTake_Item(take)
  local item_pos = GetMediaItemInfo_Value(item, 'D_POSITION')
  
  local ret, ppq_shift = CalcSmartShift(item, item_pos, take, data)
  if not ret then return end
  
  local extendMIDI, noteoff_ppq = AddShiftedSelectedEvents(take, data, ppq_shift)
  
  if extendMIDI then
    local start_qn = TimeMap2_timeToQN(0, item_pos)
    local end_qn = reaper.MIDI_GetProjQNFromPPQPos(take, noteoff_ppq)
    MIDI_SetItemExtents(item, start_qn, end_qn)
  end
end

-----------------------------------------------------------------------------------------  
function ParseRAWMIDI(take)
  local data = {}
  local gotAllOK, MIDIstring = MIDI_GetAllEvts(take, "")
  if not gotAllOK then return end
  local s_unpack = string.unpack
  local s_pack = string.pack
  local MIDIlen = MIDIstring:len()
  local idx = 0    
  local offset, flags, msg1
  local ppq_pos = 0
  local nextPos, prevPos = 1, 1 
  while nextPos <= MIDIlen do 
      prevPos = nextPos
      offset, flags, msg1, nextPos = s_unpack("i4Bs4", MIDIstring, prevPos)
      idx = idx + 1
      ppq_pos = ppq_pos + offset
      data[idx] = {
        rawevt = s_pack("i4Bs4", offset, flags , msg1),
        offset = offset, 
        flags = flags, 
        selected = (flags & 1) == 1,
        muted = (flags & 2) == 2,
        msg1 = msg1,
        ppq_pos = ppq_pos,
        isNoteOn = (msg1:byte(1) >> 4) == 0x9,
        isNoteOff = (msg1:byte(1) >> 4) == 0x8,
        isCC = (msg1:byte(1) >> 4) == 0xB,
        chan = 1 + (msg1:byte(1) & 0xF),
        vel = msg1:byte(2) or 0
      }
  end
  return data
end

----------------------------------------------------------------------------------------- 
function CalcSmartShift(item, item_pos, take, data)
  local min_ppq, max_ppq
  for i = 1, #data do
    if data[i].selected then
      if not min_ppq or data[i].ppq_pos < min_ppq then min_ppq = data[i].ppq_pos end
      if not max_ppq or data[i].ppq_pos > max_ppq then max_ppq = data[i].ppq_pos end
    end
  end
  if not min_ppq or not max_ppq then return end

  local selection_length = max_ppq - min_ppq

  local time_of_measure = reaper.TimeMap2_beatsToTime(0, 0, 1) 
  local measure_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, time_of_measure + item_pos)

  local start_measure_num = math.floor(min_ppq / measure_ppq)
  local end_measure_num = math.floor(max_ppq / measure_ppq)
  local next_measure_start = (end_measure_num + 1) * measure_ppq

  local shift_exact = selection_length

  local shifted_end = max_ppq + shift_exact

  if shifted_end <= next_measure_start then
    return true, shift_exact
  else
    return true, next_measure_start - min_ppq
  end
end

-----------------------------------------------------------------------------------------  
function AddShiftedSelectedEvents(take, data, ppq_shift)
  local str = ''
  local last_ppq
  for i = 1, #data-1 do      
    local flag
    if (data[i].flags & 1) == 1 then flag = data[i].flags - 1 else flag = data[i].flags end
    local str_per_msg = string.pack("i4Bs4", data[i].offset, flag, data[i].msg1)
    str = str .. str_per_msg
    last_ppq = data[i].ppq_pos
  end
  
  for i = 1, #data-1 do   
    if data[i].selected then
      local new_ppq = data[i].ppq_pos + ppq_shift
      local str_per_msg = string.pack("i4Bs4", new_ppq - last_ppq, data[i].flags, data[i].msg1)
      str = str .. str_per_msg
      last_ppq = new_ppq
    end
  end
  
  local noteoffoffs = data[#data].ppq_pos - last_ppq
  if data[#data].ppq_pos < last_ppq then noteoffoffs = 1 end
  str = str .. string.pack("i4Bs4", noteoffoffs, data[#data].flags, data[#data].msg1)
  
  MIDI_SetAllEvts(take, str) 
  
  if data[#data].ppq_pos < last_ppq then 
    return true, noteoffoffs + last_ppq  
  end
end

--------------------------------------------------------------------
if VF_CheckReaperVrs(6, true) then
  Undo_BeginBlock2(0)
  SmartDuplicateNotes()
  Undo_EndBlock2(0, 'Smart duplicate notes', 0)
end