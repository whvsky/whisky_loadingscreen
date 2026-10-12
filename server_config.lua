WhiskyLoadscreenConfig = {
    -- Discord Developer Portal -> Your Application -> Bot -> Token.
    -- Invite the bot to the guild specified below.
    BotToken = 'BOT_TOKEN_HERE',

    -- Discord server ID (Developer Mode -> right-click server -> Copy Server ID).
    GuildId = 'SERVER_ID_HERE',

    -- Minutes between staff lookups. Profiles are saved in FXServer's KVP
    -- so the staff panel keeps the last successful Discord name/avatar even
    -- after a server restart or temporary Discord outage.
    RefreshMinutes = 0,
    MaxVisibleStaff = 8,

    -- PLAYERS CURRENTLY IN SERVER (online player roster)
    PlayerList = {
        Enabled = true,
        -- 'framework' = in-character first/last names from Qbox/QBCore/ESX.
        -- 'discord'   = their nickname in your configured Discord guild.
        -- 'fivem'     = their FiveM player name.
        NameMode = 'framework',
        -- 'auto' automatically detects qbx_core, qb-core, or es_extended.
        -- Other values: 'qbx', 'qb', 'esx'. Only used for framework mode
        -- and as Discord's fallback if a nickname isn't available.
        Framework = 'auto',
        -- If a Discord nickname cannot be fetched, fall back to 'framework'
        -- (which itself falls back to their FiveM player name), or 'fivem'.
        DiscordFallback = 'framework',
        -- Show the roster on connection, or require clicking the player count.
        StartExpanded = true,
        -- Display server IDs next to names (e.g., #12).
        ShowServerIds = true,
        -- Limits transmitted list size/UI clutter; count still shows everybody.
        MaxDisplayed = 80,
        -- Refresh cached Discord guild nicknames no more often than 30 min.
        -- New names are looked up server-side on joining / server start.
        DiscordCacheMinutes = 30
    },

    -- In display order. User IDs MUST be quoted strings for precision.
    -- Role is the custom label under their Discord server nickname.
    -- fallbackName shows if there has never been a successful Discord lookup.
    -- Staff cards ALWAYS show, including when the account is offline,
    -- the Discord bot is unavailable, or userId has not been configured yet.
    Staff = {
        { userId = 'USER_ID_HERE', role = 'OWNER',      fallbackName = 'Owner' } -- add a comma if you put more users.
    --    { userId = 'USER_ID_HERE', role = 'CO-OWNER',   fallbackName = 'Co-Owner' },
    --    { userId = 'USER_ID_HERE', role = 'DEVELOPER',  fallbackName = 'Developer' },
    --    { userId = 'USER_ID_HERE', role = 'MANAGEMENT', fallbackName = 'Management' }
    }
}
