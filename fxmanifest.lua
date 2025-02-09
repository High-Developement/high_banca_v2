fx_version 'adamant'
game 'gta5'
lua54 'yes'
author 'Alessio'

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

shared_script {
    'config.lua'
}

shared_script '@ox_lib/init.lua'