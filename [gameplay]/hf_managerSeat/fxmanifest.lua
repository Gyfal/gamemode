fx_version 'cerulean'
game 'gta5'

dependency 'ox_lib'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua'
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client.lua'
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



name 'hf_managerSeat'
description 'seat manager'
version '1.0.0'
lua54 'yes'
use_experimental_fxv2_oal 'yes'