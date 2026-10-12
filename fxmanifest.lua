fx_version 'cerulean'
game 'gta5'

author 'Whisky Development'
description 'MP4 loadscreen with independent persistent Discord staff and online player roster'
version '2.1.1'

loadscreen 'html/index.html'
loadscreen_cursor 'yes'

server_scripts {
    'server_config.lua',
    'server/staff.lua',
    'server/players.lua',
    'server/handover.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/media_config.js',
    'html/staff_snapshot.js',
    'html/script.js',
    'html/assets/*.mp4',
    'html/assets/logo.png'
}
