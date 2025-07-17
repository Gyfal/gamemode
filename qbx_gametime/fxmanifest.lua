fx_version 'cerulean'
game 'gta5'

name 'qbx_gametime'
description 'Game time system with Moscow timezone sync'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config/shared.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'locales/*.json'
}

ox_lib 'locale'

dependencies {
    'ox_lib',
    'qbx_core'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'