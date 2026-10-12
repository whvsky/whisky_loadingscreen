-- WHISKY LOADSCREEN | PRIVATE | DISCORD STAFF SERVICE
-- ONLY configured StaffDiscord.Members are used here. Connected players are
-- NEVER consulted. Keep this file outside escrow_ignore so Cfx can encrypt it.
local root = WhiskyLoadscreenConfig
if type(root) ~= 'table' then error('[Whisky Loadscreen] Missing server_config.lua') end

-- Backwards-compatible with pre-2.1 config files. Prefer the new StaffDiscord section.
local config = root.StaffDiscord
if type(config) ~= 'table' then
    config = {
        BotToken = root.BotToken, GuildId = root.GuildId,
        RefreshMinutes = root.RefreshMinutes, MaxVisibleStaff = root.MaxVisibleStaff,
        Members = root.Staff
    }
end

local resource = GetCurrentResourceName()
local guildId = tostring(config.GuildId or '')
local storedProfiles = {} -- Discord member IDs -> last successful member name + avatar
local currentlyRefreshing = false
local lastLog = nil
local lastSnapshot = nil

local function log(msg) print('^5[Whisky Loadscreen/Staff]^7 ' .. tostring(msg)) end
local function report(msg)
    if msg ~= lastLog then log(msg); lastLog = msg end
end
local function trimmed(v)
    if type(v) ~= 'string' then return nil end
    v = v:match('^%s*(.-)%s*$')
    return v ~= '' and v or nil
end
local function snowflake(v)
    return type(v) == 'string' and #v >= 17 and #v <= 22 and v:match('^%d+$') ~= nil
end
local function safeName(name, maximum)
    name = trimmed(name)
    if not name then return nil end
    return name:gsub('[%c]', ''):sub(1, maximum or 48)
end
local function validAvatar(url)
    if type(url) ~= 'string' then return nil end
    if url:match('^https://cdn%.discordapp%.com/[%w_/%.-]+%?size=%d+$') or
       url:match('^https://cdn%.discordapp%.com/[%w_/%.-]+$') then return url end
    return nil
end
local function staffSlots()
    local result, seen = {}, {}
    local max = math.max(1, math.min(16, math.floor(tonumber(config.MaxVisibleStaff) or 8)))
    for _, entry in ipairs(config.Members or {}) do
        if type(entry) == 'table' then
            local id = trimmed(entry.userId)
            if id and not snowflake(id) then
                report('Invalid staff Discord user ID, using fallback for that slot.')
                id = nil
            end
            if not id or not seen[id] then
                if id then seen[id] = true end
                result[#result + 1] = {
                    id = id,
                    role = safeName(entry.role, 32) or 'STAFF',
                    fallback = safeName(entry.fallbackName, 48) or 'Staff Member',
                    fallbackAvatar = validAvatar(entry.fallbackAvatar)
                }
                if #result >= max then break end
            end
        end
    end
    if #result == 0 then
        result[1] = { role = 'SERVER STAFF', fallback = 'Staff Team' }
    end
    return result
end
local function kvpKey(id)
    return 'whisky_staff_v21:' .. guildId .. ':' .. id
end

-- Hydrate cached profiles BEFORE any network activity. Staff does not depend on
-- whether its members are online in FiveM or Discord.
for _, slot in ipairs(staffSlots()) do
    if slot.id then
        local raw = GetResourceKvpString(kvpKey(slot.id))
        -- Migrate cache from previous versions if v2.1 key isn't present.
        if not raw then raw = GetResourceKvpString('whisky_loadscreen:staff:' .. slot.id) end
        if raw then
            local ok, saved = pcall(json.decode, raw)
            if ok and type(saved) == 'table' then
                local name = safeName(saved.name, 48)
                if name then
                    storedProfiles[slot.id] = { name = name, avatar = validAvatar(saved.avatar) }
                end
            end
        end
    end
end

local function staffPublic()
    local members = {}
    for i, slot in ipairs(staffSlots()) do
        local found = slot.id and storedProfiles[slot.id] or nil
        members[#members + 1] = {
            slot = i,
            name = found and found.name or slot.fallback,
            role = slot.role,
            avatar = found and found.avatar or slot.fallbackAvatar,
            verified = found ~= nil
        }
    end
    return members
end

-- Public snapshot is for standalone web previews and loading before handover.
-- It contains ONLY display names, roles and CDN avatars, never IDs/bot token.
local function publishSnapshot()
    local ok, payload = pcall(json.encode, staffPublic())
    if not ok or type(payload) ~= 'string' then return end
    local contents = '/* Public server staff display data. No Discord IDs or bot token. */\n' ..
                     'window.WhiskyStaffSnapshot = ' .. payload .. ';\n'
    if contents == lastSnapshot then return end
    if SaveResourceFile(resource, 'html/staff_snapshot.js', contents, #contents) then
        lastSnapshot = contents
    else
        report('Could not write html/staff_snapshot.js. Check file permissions / escrow_ignore.')
    end
end

local function avatarIndex(id, discriminator)
    if type(discriminator) == 'string' and discriminator ~= '0' then
        local n = tonumber(discriminator)
        if n then return n % 5 end
    end
    -- Bit-safe approach for big Discord IDs.
    local modulus = 4194304 * 6
    local remainder = 0
    for digit in id:gmatch('%d') do
        remainder = (remainder * 10 + tonumber(digit)) % modulus
    end
    return math.floor(remainder / 4194304)
end
local function getAvatar(id, member, user)
    local prefix = 'https://cdn.discordapp.com/'
    local memberHash = member.avatar
    if type(memberHash) == 'string' and memberHash:match('^[%w_]+$') then
        return prefix .. 'guilds/' .. guildId .. '/users/' .. id .. '/avatars/' .. memberHash ..
            (memberHash:sub(1,2) == 'a_' and '.gif' or '.png') .. '?size=128'
    end
    local userHash = user.avatar
    if type(userHash) == 'string' and userHash:match('^[%w_]+$') then
        return prefix .. 'avatars/' .. id .. '/' .. userHash ..
            (userHash:sub(1,2) == 'a_' and '.gif' or '.png') .. '?size=128'
    end
    return prefix .. 'embed/avatars/' .. avatarIndex(id, user.discriminator) .. '.png'
end

local function refreshStaff()
    if currentlyRefreshing then return end
    local token = trimmed(config.BotToken)
    if not snowflake(guildId) or not token or token == 'PUT_YOUR_DISCORD_BOT_TOKEN_HERE' then
        report('Configure StaffDiscord.GuildId and StaffDiscord.BotToken in server_config.lua; cached/fallback staff remain visible.')
        return
    end
    local targets = {}
    for _, slot in ipairs(staffSlots()) do
        if slot.id then targets[#targets + 1] = slot.id end
    end
    if #targets == 0 then
        report('No valid StaffDiscord.Members IDs configured; showing staff fallback slots.')
        return
    end
    currentlyRefreshing = true
    local current, successes = 1, 0
    local function nextMember()
        local id = targets[current]
        if not id then
            currentlyRefreshing = false
            if successes > 0 then
                lastLog = nil
                log(('Updated %d / %d configured staff member(s).'):format(successes, #targets))
            end
            return
        end
        local completed = false
        local function complete(status, body)
            if completed then return end
            completed = true
            status = tonumber(status) or 0
            local delay = 400
            if status == 200 then
                local ok, member = pcall(json.decode, body or '')
                if ok and type(member) == 'table' and type(member.user) == 'table' then
                    local user = member.user
                    local name = safeName(member.nick, 48) or
                                 safeName(user.global_name, 48) or safeName(user.username, 48)
                    if name then
                        local profile = { name = name, avatar = getAvatar(id, member, user) }
                        storedProfiles[id] = profile
                        local serializedOK, serialized = pcall(json.encode, profile)
                        if serializedOK and type(serialized) == 'string' then
                            SetResourceKvp(kvpKey(id), serialized)
                        end
                        -- Publish successful lookups immediately. Handover always
                        -- reads the current cache, including across restarts.
                        publishSnapshot()
                        successes = successes + 1
                    end
                end
            elseif status == 429 then
                report('Discord rate limit (429); retaining previous cached staff.')
                delay = 2000
            elseif status == 401 or status == 403 then
                report('Discord HTTP ' .. status .. '. Check staff bot token and guild access.')
            elseif status == 404 then
                report('Configured staff ID ' .. id .. ' is not in this guild (404).')
            else
                report('Discord request failed (HTTP ' .. status .. '); cached staff remain visible.')
            end
            current = current + 1
            SetTimeout(delay, nextMember)
        end
        -- A network request that never responds must not lock out all future refreshes.
        SetTimeout(18000, function() complete(0, '') end)
        PerformHttpRequest(
            'https://discord.com/api/v10/guilds/' .. guildId .. '/members/' .. id,
            function(status, body) complete(status, body) end,
            'GET', '', {
                ['Authorization'] = 'Bot ' .. token,
                ['Accept'] = 'application/json',
                ['User-Agent'] = 'WhiskyLoadscreen/2.1'
            }
        )
    end
    nextMember()
end

WhiskyStaffService = { getPublic = staffPublic, refresh = refreshStaff }

CreateThread(function()
    Wait(250)
    publishSnapshot() -- Ensures configured staff slots exist even before Discord answers.
    while true do
        refreshStaff()
        Wait(math.max(2, tonumber(config.RefreshMinutes) or 10) * 60000)
    end
end)

RegisterCommand('whisky_staff_refresh', function(src)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'command.whisky_staff_refresh') then return end
    refreshStaff()
end, true)
