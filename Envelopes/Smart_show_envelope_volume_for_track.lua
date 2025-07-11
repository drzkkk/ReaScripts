-- @description Smart show volume envelope (using Utility jsfx) for tracks
-- @author drzk
-- @version 1.0
-- @tags volume envelope

local r = reaper

local target_fx_name = "JS: Utility (Vol, Pan, Width, Mono Low with Cutoff) [drzk]"

local tr = r.GetSelectedTrack(0, 0)
if not tr then return end

local function find_js_fx(tr, fx_name)
    local fx_count = r.TrackFX_GetCount(tr)
    for i = 0, fx_count - 1 do
        local ret, name = r.TrackFX_GetFXName(tr, i, "")
        if ret and name == fx_name then
            return i
        end
    end
    return -1
end

local fx_idx = find_js_fx(tr, target_fx_name)

if fx_idx == -1 then
    fx_idx = r.TrackFX_AddByName(tr, target_fx_name, false, -1)
    if fx_idx == -1 then
        r.ShowMessageBox("Failed to add plugin "..target_fx_name, "Error", 0)
        return
    end
    r.TrackFX_SetEnabled(tr, fx_idx, true)
else
    local enabled = r.TrackFX_GetEnabled(tr, fx_idx)
    local env = r.GetFXEnvelope(tr, fx_idx, 0, false)

    if not enabled and not env then
        r.TrackFX_SetEnabled(tr, fx_idx, true)
    elseif not enabled and env then
        return
    end
end

local env = r.GetFXEnvelope(tr, fx_idx, 0, false)
if not env then
    env = r.GetFXEnvelope(tr, fx_idx, 0, true)
    if env and r.SetEnvelopeInfo_Value then
        r.SetEnvelopeInfo_Value(env, "I_VIS", 1)
        r.UpdateArrange()
    end
end
