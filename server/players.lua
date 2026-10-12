-- WHISKY LOADSCREEN | PRIVATE | LIVE CONNECTED PLAYER ROSTER
-- Only GetPlayers() is used to determine which players appear here.
-- NO StaffDiscord.Members list is read or used as the player list.
local root = WhiskyLoadscreenConfig or {}
local opts = type(root.PlayerList) == 'table' and root.PlayerList or {}
local staffDiscord = type(root.StaffDiscord) == 'table' and root.StaffDiscord or root
local onlineNicknames, pending, queue = {}, {}, {}
local workerActive = false

local function nameClean(v)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('%^%d', ''):gsub('[%c]', ''):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    return v ~= '' and v:sub(1, 56) or nil
end
local function snowflake(v)
    return type(v) == 'string' and #v >= 17 and #v <= 22 and v:match('^%d+$') ~= nil
end
local function mode()
    if opts.NameMode == 'discord' or opts.NameMode == 'fivem' then return opts.NameMode end
    return 'framework'
end
local function framework()
    if opts.Framework == 'qbx' or opts.Framework == 'qb' or opts.Framework == 'esx' then return opts.Framework end
    if GetResourceState('qbx_core') == 'started' then return 'qbx' end
    if GetResourceState('qb-core') == 'started' then return 'qb' end
    if GetResourceState('es_extended') == 'started' then return 'esx' end
    return nil
end
local function fullName(first, last)
    local a, b = nameClean(first), nameClean(last)
    return a and b and nameClean(a .. ' ' .. b) or a or b
end
local function getCharacterName(src)
    local selected = framework()
    if not selected then return nil end
    local ok, value = pcall(function()
        if selected == 'qbx' and GetResourceState('qbx_core') == 'started' then
            local p = exports.qbx_core:GetPlayer(src)
            local info = p and p.PlayerData and p.PlayerData.charinfo
            return info and fullName(info.firstname, info.lastname)
        elseif selected == 'qb' and GetResourceState('qb-core') == 'started' then
            local core = exports['qb-core']:GetCoreObject()
            local p = core and core.Functions and core.Functions.GetPlayer(src)
            local info = p and p.PlayerData and p.PlayerData.charinfo
            return info and fullName(info.firstname, info.lastname)
        elseif selected == 'esx' and GetResourceState('es_extended') == 'started' then
            local core = exports['es_extended']:getSharedObject()
            local p = core and core.GetPlayerFromId(src)
            if not p then return nil end
            local a, b
            if type(p.get) == 'function' then
                a, b = p.get('firstName'), p.get('lastName')
                if not a or not b then a, b = p.get('firstname'), p.get('lastname') end
            end
            if not a and type(p.variables) == 'table' then
                a = p.variables.firstName or p.variables.firstname
                b = p.variables.lastName or p.variables.lastname
            end
            return fullName(a, b) or (type(p.getName) == 'function' and nameClean(p.getName()))
        end
        return nil
    end)
    return ok and nameClean(value) or nil
end
local function discordId(src)
    local value
    if type(GetPlayerIdentifierByType) == 'function' then
        local ok, result = pcall(GetPlayerIdentifierByType, src, 'discord')
        if ok then value = result end
    end
    if not value then
        for _, identifier in ipairs(GetPlayerIdentifiers(src) or {}) do
            if identifier:sub(1, 8) == 'discord:' then value = identifier; break end
        end
    end
    local id = type(value) == 'string' and value:match('^discord:(%d+)$') or nil
    return snowflake(id) and id or nil
end
local function credentials()
    local guild = staffDiscord.GuildId
    local token = staffDiscord.BotToken
    if not snowflake(guild) or type(token) ~= 'string' or token == '' or
        token == 'PUT_YOUR_DISCORD_BOT_TOKEN_HERE' then return nil, nil end
    return guild, token
end
local function processQueue()
    if workerActive or #queue == 0 then return end
    local guild, token = credentials()
    if not guild then return end
    workerActive = true
    local function nextOne()
        local id = table.remove(queue, 1)
        if not id then workerActive = false; return end
        local completed = false
        local function complete(status, body)
            if completed then return end
            completed = true
            local found
            if tonumber(status) == 200 then
                local ok, member = pcall(json.decode, body or '')
                if ok and type(member) == 'table' and type(member.user) == 'table' then
                    found = nameClean(member.nick) or nameClean(member.user.global_name) or
                        nameClean(member.user.username)
                end
            end
            local ttl = math.max(2, tonumber(opts.DiscordCacheMinutes) or 30) * 60
            onlineNicknames[id] = {name = found, expires = os.time() + (found and ttl or 300)}
            pending[id] = nil
            SetTimeout(450, nextOne)
        end
        SetTimeout(18000, function() complete(0, '') end)
        PerformHttpRequest(
            'https://discord.com/api/v10/guilds/' .. guild .. '/members/' .. id,
            function(status, body) complete(status, body) end,
            'GET', '', {
                ['Authorization'] = 'Bot ' .. token,
                ['Accept'] = 'application/json',
                ['User-Agent'] = 'WhiskyLoadscreen/2.1'
            }
        )
    end
    nextOne()
end
local function queueId(id)
    if not id or not credentials() or pending[id] then return end
    local result = onlineNicknames[id]
    if result and result.expires > os.time() then return end
    pending[id] = true
    queue[#queue + 1] = id
    processQueue()
end
local function prefetch()
    if opts.Enabled == false or mode() ~= 'discord' then return end
    for _, raw in ipairs(GetPlayers()) do
        local src = tonumber(raw)
        if src then queueId(discordId(src)) end
    end
end
CreateThread(function()
    Wait(1500)
    while true do prefetch(); Wait(60000) end
end)
AddEventHandler('playerJoining', function()
    if mode() ~= 'discord' then return end
    local src = source
    SetTimeout(2000, function()
        if GetPlayerName(src) then queueId(discordId(src)) end
    end)
end)

local function publicRoster()
    local enabled = opts.Enabled ~= false
    local members = {}
    if enabled then
        local ids = GetPlayers() or {}
        table.sort(ids, function(a,b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
        local maximum = math.max(1, math.min(256, math.floor(tonumber(opts.MaxDisplayed) or 80)))
        for _, raw in ipairs(ids) do
            if #members >= maximum then break end
            local src = tonumber(raw)
            if src then
                local result = nameClean(GetPlayerName(src)) or 'Player'
                if mode() == 'framework' then
                    result = getCharacterName(src) or result
                elseif mode() == 'discord' then
                    local id = discordId(src)
                    if id then
                        queueId(id)
                        local cached = onlineNicknames[id]
                        if cached and cached.name and cached.expires > os.time() then
                            result = cached.name
                        elseif opts.DiscordFallback ~= 'fivem' then
                            result = getCharacterName(src) or result
                        end
                    elseif opts.DiscordFallback ~= 'fivem' then
                        result = getCharacterName(src) or result
                    end
                end
                members[#members + 1] = {id = src, name = result}
            end
        end
    end
    return {
        enabled = enabled,
        mode = mode(),
        defaultOpen = opts.StartExpanded ~= false,
        showIds = opts.ShowServerIds ~= false,
        members = members
    }
end

WhiskyPlayersService = { getPublic = publicRoster }
