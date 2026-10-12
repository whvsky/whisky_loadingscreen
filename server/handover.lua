-- WHISKY LOADSCREEN | PRIVATE | CONNECTION HANDOVER
-- Combines two independent services into ONE official FiveM handover payload.
-- Neither service can overwrite the other; staff is never based on GetPlayers().
local function serverName()
    local name = GetConvar('sv_projectName', '')
    if type(name) ~= 'string' or name:match('^%s*$') then
        name = GetConvar('sv_hostname', 'FiveM Server')
    end
    name = tostring(name):gsub('%^%d', ''):match('^%s*(.-)%s*$')
    return name ~= '' and name or 'FiveM Server'
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    if not deferrals or type(deferrals.handover) ~= 'function' then return end
    local max = GetConvarInt('sv_maxclients', 48)
    local staff = WhiskyStaffService and WhiskyStaffService.getPublic() or {}
    local players = WhiskyPlayersService and WhiskyPlayersService.getPublic() or {
        enabled = false, mode = 'fivem', members = {}
    }
    local payload = {
        whiskyServer = {
            name = serverName(),
            players = #GetPlayers(),
            maxPlayers = max > 0 and max or nil
        },
        whiskyStaff = { members = staff },
        whiskyPlayers = players
    }
    local ok, err = pcall(function() deferrals.handover(payload) end)
    if not ok then print('^1[Whisky Loadscreen]^7 Handover error: ' .. tostring(err)) end
end)
