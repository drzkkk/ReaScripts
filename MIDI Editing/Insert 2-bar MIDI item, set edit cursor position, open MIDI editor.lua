-- @description Insert 2-bar MIDI item, set edit cursor position, open MIDI editor
-- @version 1.0
-- @tags midi insert
-- @changelog First version
-- @author MPL + mini improves by drzk

local r = reaper
local undo = "Insert 2-bar MIDI item"
local tr, retval, name, m_pos, qn_st, qn_end

function qntime(qn)
    return r.TimeMap2_QNToTime(0, qn)
end

function insert(st_p, end_p)
    local item = r.CreateNewMIDIItemInProj(tr, st_p, end_p, false)
    if not item then return end
    local take = r.GetActiveTake(item)
    if take then
        r.GetSetMediaItemTakeInfo_String(take, 'P_NAME', name or "", true)
    end
    r.SetMediaItemInfo_Value(item, 'B_LOOPSRC', 0)
    r.SetMediaItemSelected(item, true)
    r.SetEditCurPos(st_p, true, false)
    r.Main_OnCommand(40153, 0)
end

r.BR_GetMouseCursorContext()
tr = r.BR_GetMouseCursorContext_Track()
if not tr then return end

m_pos = r.BR_GetMouseCursorContext_Position()
retval, name = r.GetSetMediaTrackInfo_String(tr, 'P_NAME', '', false)

r.Undo_BeginBlock()
r.PreventUIRefresh(-1)

local qn = r.TimeMap_timeToQN(m_pos)
retval, qn_st, qn_end = r.TimeMap_QNToMeasures(0, qn)
local msr_st = qntime(qn_st)
local msr_end = qntime(qn_end)
local len = msr_end - msr_st
insert(msr_st, msr_st + len * 2)

r.PreventUIRefresh(1)
r.Undo_EndBlock(undo, -1)