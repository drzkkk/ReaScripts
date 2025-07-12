-- @description Smart show volume envelope (using Utility jsfx) if already added show all envelopes
-- @version 1.0
-- @tags volume envelope
-- @changelog First version
-- @author drzk

local r = reaper

local target_fx_name = "JS: Utility (Vol, Pan, Width, Mono Low with Cutoff) [drzk]"
local search_name = "Utility (Vol, Pan, Width, Mono Low with Cutoff) [drzk]"
local tr = r.GetSelectedTrack(0, 0)
if not tr then return end

local function find_js_fx(track, fx_name)
    local fx_count = r.TrackFX_GetCount(track)
    for i = 0, fx_count - 1 do
        local _, name = r.TrackFX_GetFXName(track, i, "")
        if name == fx_name then
            return i
        end
    end
    return -1
end

local function copy_to_clipboard(text)
    if r.CF_SetClipboard then
        r.CF_SetClipboard(text)
    else
        if r.GetOS():match("Win") then
            text = text:gsub('"', '\\"')
            r.ExecProcess("cmd /c echo " .. text .. " | clip", 0)
        else
            r.ShowMessageBox("Install SWS Extension to copy to clipboard", "No SWS", 0)
        end
    end
end

local fx_idx = find_js_fx(tr, target_fx_name)
local just_created_env = false

if fx_idx == -1 then
    fx_idx = r.TrackFX_AddByName(tr, target_fx_name, false, -1)
    if fx_idx == -1 then
        copy_to_clipboard(search_name)
        r.ShowMessageBox(
            "FX Utility by drzk is not installed.\n\nPress Ctrl+V or CMD+V in the search bar to find:\n\n" ..
            search_name ..
            "\n\nInstall it and after installation, right-click in FX Browser -> 'Scan for new plugins', then re-run this script.",
            "FX is missing",
            0
        )
        local reapack_cmd_id = r.NamedCommandLookup("_REAPACK_BROWSE")
        if reapack_cmd_id ~= 0 then
            r.Main_OnCommand(reapack_cmd_id, 0)
        end
        return
    end

    local env = r.GetFXEnvelope(tr, fx_idx, 0, false)
    if not env then
        env = r.GetFXEnvelope(tr, fx_idx, 0, true)
        just_created_env = true
    end
else
    local env = r.GetFXEnvelope(tr, fx_idx, 0, false)
    if not env then
        env = r.GetFXEnvelope(tr, fx_idx, 0, true)
        just_created_env = true

        if not r.TrackFX_GetEnabled(tr, fx_idx) then
            r.TrackFX_SetEnabled(tr, fx_idx, true)
        end
    else
        just_created_env = false
    end

    if not just_created_env then
        local toggle_cmd_id = r.NamedCommandLookup("_BR_T_SHOW_ACT_FX_ENV_SEL_TRACK")
        if toggle_cmd_id ~= 0 then
            r.Main_OnCommand(toggle_cmd_id, 0)
        else
            r.ShowMessageBox("SWS/BR command '_BR_T_SHOW_ACT_FX_ENV_SEL_TRACK' not found.\nPlease install SWS Extension / Bridge.", "Error", 0)
        end
    end
end

r.UpdateArrange()

