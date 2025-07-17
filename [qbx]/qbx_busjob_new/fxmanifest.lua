fx_version 'cerulean'
game 'gta5'

description 'QBX Bus Job New'
repository 'https://github.com/Qbox-project/qbx_busjob_new'
version '1.0.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua'
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'locales/*.json',
    'config/client.lua',
    'config/server.lua',
    'config/shared.lua'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
    'oxmysql',
    'qbx_vehiclekeys'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'