-- @description Auto move instrument FX to top of chain (background)
-- @version 1.0
-- @tags fx, fx chain, instrument, automation
-- @changelog First version
-- @author drzk

-- @about
--   Automatically moves a newly added instrument plugin (VSTi, VST3i, or synth)
--   to the top of the FX chain on the selected track.
--   Helps maintain consistent plugin order (e.g., instruments before FX like EQ or reverb).
--   Runs continuously in the background.

local function IsInstrument(track, fx_idx)
    local _, fx_name = reaper.TrackFX_GetFXName(track, fx_idx, "")
    if not fx_name then return false end
    fx_name = fx_name:lower()
    return fx_name:find("vsti") ~= nil or fx_name:find("vst3i") or fx_name:find("synth")  ~= nil
end

local function MoveNewInstrumentToTop(track, last_fx)
    if last_fx > 0 and IsInstrument(track, last_fx) then
        reaper.TrackFX_CopyToTrack(track, last_fx, track, 0, true)
    end
end

local function CheckFXChain()
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then return end

    local current_fx_count = reaper.TrackFX_GetCount(track)
    if current_fx_count < 1 then return end

    local last_fx_count = tonumber(reaper.GetExtState("MoveVSTiToTop", "LastFXCount")) or 0

    if current_fx_count > last_fx_count then
        MoveNewInstrumentToTop(track, current_fx_count - 1)
    end

    reaper.SetExtState("MoveVSTiToTop", "LastFXCount", tostring(current_fx_count), false)
end

local function Main()
    CheckFXChain()
    reaper.defer(Main)
end

Main()

reaper.atexit(function()
    reaper.DeleteExtState("MoveVSTiToTop", "LastFXCount", false)
end)