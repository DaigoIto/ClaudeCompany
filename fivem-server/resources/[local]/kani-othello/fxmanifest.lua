fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'kanimiso'
description 'オセロ: CPU戦 / 2人対戦。フレームワーク非依存'
version '1.0.0'

shared_script 'config.lua'
client_script 'client.lua'
server_scripts { 'money.lua', 'inventory.lua', 'server.lua' }

ui_page 'html/index.html'
files { 'html/index.html' }
