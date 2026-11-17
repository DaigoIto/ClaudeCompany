fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'kanimiso'
description 'オセロ: アイテムで卓を置いて2人対戦(賭けあり) / CPU戦'
version '1.0.0'

shared_script 'config.lua'
client_script 'client.lua'
server_scripts { 'money.lua', 'item.lua', 'server.lua' }

ui_page 'html/index.html'
files { 'html/index.html', 'stream/kani_othello.ytyp' }

-- 自作モデル(卓・盤・石)。stream/ の ydr は自動で配信される
data_file 'DLC_ITYP_REQUEST' 'stream/kani_othello.ytyp'
