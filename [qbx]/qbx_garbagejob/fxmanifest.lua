fx_version 'cerulean'
game 'gta5'

name 'qbx_garbagejob'
description 'Garbage Collector Job for QBX Core'
author 'Kiro AI'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua'
}

client_scripts {
    'config/client.lua',
    'client/main.lua'
}

server_scripts {
    'config/server.lua',
    'server/main.lua'
}

files {
    'locales/*.lua'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
    'qbx_vehiclekeys'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'