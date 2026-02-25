fx_version 'cerulean'
game 'gta5'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/territory.lua',
    'client/war.lua',
    'client/leaderboard.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/gang.lua',
    'server/mafia.lua',
    'server/territory.lua',
    'server/war.lua',
    'server/upgrades.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

lua54 'yes'