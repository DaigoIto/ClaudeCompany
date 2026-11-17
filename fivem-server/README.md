# kanimiso World — FiveM サーバー

## セットアップ手順 (Windows)
1. サーバー本体(artifacts)をダウンロード  
   https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/  
   最新の `server.7z` を `fivem-server\server\` に展開 (`FXServer.exe` ができる)
2. ライセンスキー取得: https://keymaster.fivem.net → `server.cfg` の `sv_licenseKey` に貼る
3. 標準リソース(mapmanager, chat, spawnmanager, sessionmanager, hardcap)を取得  
   https://github.com/citizenfx/cfx-server-data の `resources` を `resources\` にコピー
4. 起動: `server\FXServer.exe +exec ..\server.cfg` (初回は txAdmin の設定画面が開く場合あり)
5. FiveM クライアントから `connect localhost:30120` (他人を招待するなら 30120 をポート開放)

## ワールド
- `resources/[local]/myworld` : 拠点広場(プロップ+車+ブリップ)。`config.lua` で座標・物を編集
- `resources/[local]/worldsettings` : スポーン地点・天候・時間・人/車の密度
- ゲーム内コマンド `/tpworld` で広場へ移動

## 次の拡張案
- MLO(建物)・YMAP の導入、ESX/QBCore などフレームワーク、DB(oxmysql)
