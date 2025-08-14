-- @description Toggle Bypass all FX without instruments on selected tracks
-- @version 1.0
-- @tags fx chain, tracks
-- @changelog First version
-- @author drzk

local r = reaper

function main_toggle_fx_on_selected_tracks()
    for key in pairs(r) do _G[key] = r[key] end

    local function SaveProcessedTracks(track_guids)
        r.SetProjExtState(0, 'ToggleFXScript', 'LAST_TRACKS', table.concat(track_guids, '\n'))
    end

    local function GetProcessedTracks()
        local retval, track_list_str = r.GetProjExtState(0, 'ToggleFXScript', 'LAST_TRACKS')
        local guids = {}
        if retval == 1 and track_list_str ~= '' then
            for guid in track_list_str:gmatch('[^\n]+') do
                table.insert(guids, guid)
            end
        end
        return guids
    end

    local function GetTrackByGUID(guid)
        for i = 0, r.CountTracks(0) - 1 do
            local tr = r.GetTrack(0, i)
            if r.GetTrackGUID(tr) == guid then
                return tr
            end
        end
        return nil
    end

    local function SaveFXBypassState(track)
        local bypass_state_str = ''
        for fx_idx = 0, r.TrackFX_GetCount(track) - 1 do
            local is_enabled = r.TrackFX_GetEnabled(track, fx_idx)
            if not is_enabled then
                bypass_state_str = bypass_state_str .. fx_idx .. ' '
            end
        end
        local track_guid = r.GetTrackGUID(track)
        local ext_state_key = 'MPL_BYPASSFX_SINGLE_TRACK_' .. track_guid
        r.SetProjExtState(0, 'ToggleFXScript', ext_state_key, bypass_state_str)
    end

    local function GetFXBypassState(track)
        local track_guid = r.GetTrackGUID(track)
        local ext_state_key = 'MPL_BYPASSFX_SINGLE_TRACK_' .. track_guid
        local retval, state_str = r.GetProjExtState(0, 'ToggleFXScript', ext_state_key)
        local bypassed_fx_indices = {}
        if retval == 1 and state_str ~= '' then
            for idx_str in state_str:gmatch('(%d+)') do
                bypassed_fx_indices[tonumber(idx_str)] = true
            end
        end
        return bypassed_fx_indices
    end

    local function IsInstrument(track, fx_idx)
        return r.TrackFX_GetInstrument(track) == fx_idx
    end

    local _, _, section_id, command_id = r.get_action_context()
    local current_toggle_state = r.GetToggleCommandStateEx(section_id, command_id)

    if current_toggle_state == -1 or current_toggle_state == 0 then
        -- === BYPASS FX ===
        local track_count = r.CountSelectedTracks(0)
        if track_count == 0 then
            r.ShowConsoleMsg("Please select at least one track.\n")
            return
        end

        local processed_guids = {}
        for i = 0, track_count - 1 do
            local track = r.GetSelectedTrack(0, i)
            local guid = r.GetTrackGUID(track)
            table.insert(processed_guids, guid)

            SaveFXBypassState(track)

            for fx_idx = 0, r.TrackFX_GetCount(track) - 1 do
                if not IsInstrument(track, fx_idx) then
                    local retval, fx_name = r.TrackFX_GetFXName(track, fx_idx, "")
                    if fx_name == "VST3: Melodyne (Celemony)" then
                        r.TrackFX_SetEnabled(track, fx_idx, true)
                    else
                        r.TrackFX_SetEnabled(track, fx_idx, false)
                    end
                else
                    r.TrackFX_SetEnabled(track, fx_idx, true)
                end
            end
        end

        SaveProcessedTracks(processed_guids)
        r.SetToggleCommandState(section_id, command_id, 1)

    elseif current_toggle_state == 1 then
        -- === RESTORE FX ===
        local guids = GetProcessedTracks()
        if #guids == 0 then
            r.ShowConsoleMsg("No tracks saved from last toggle.\n")
            return
        end

        for _, guid in ipairs(guids) do
            local track = GetTrackByGUID(guid)
            if track then
                local bypassed_fx_indices = GetFXBypassState(track)

                for fx_idx = 0, r.TrackFX_GetCount(track) - 1 do
                    if bypassed_fx_indices[fx_idx] then
                        r.TrackFX_SetEnabled(track, fx_idx, false)
                    else
                        r.TrackFX_SetEnabled(track, fx_idx, true)
                    end
                end

                local ext_state_key = 'MPL_BYPASSFX_SINGLE_TRACK_' .. guid
                r.SetProjExtState(0, 'ToggleFXScript', ext_state_key, '')
            end
        end

        r.SetProjExtState(0, 'ToggleFXScript', 'LAST_TRACKS', '')
        r.SetToggleCommandState(section_id, command_id, 0)
    end

    r.UpdateArrange()
end

local script_title = "Toggle Bypass all FX without instruments on selected tracks"
r.Undo_BeginBlock()
main_toggle_fx_on_selected_tracks()
r.Undo_EndBlock(script_title, -1)
