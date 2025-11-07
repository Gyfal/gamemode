fx_version 'cerulean'
game 'gta5'

author 'HF Team'
description 'Dialog System for Bus Job (Svelte)'
version '1.0.0'

client_scripts {
    'client/main.lua',
    'client/bus_integration.lua',
}

shared_scripts {
    'config.lua',
}

files {
    'web/dist/index.html',
    'web/dist/**/*',
}

lua54 'yes'

ui_page 'web/dist/index.html'
