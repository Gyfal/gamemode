fx_version 'cerulean'
game 'gta5'

description 'HF Safe Zone - Green zones with disabled collisions'
version '1.0.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'locales/*.json',
    'config/shared.lua'
}

dependencies {
    'qbx_core',
    'ox_lib'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'