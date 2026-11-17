# アイテム「五目並べセット」の登録 (サーバー管理者向け)

このフォルダは kani-gomoku 本体では読み込まれません。インベントリ側に1回だけ登録してください。

## ox_inventory (Qbox の標準)
1. `ox_inventory/data/items.lua` の `return {` の中に、次を追加
   ```lua
   ['gomoku_set'] = {
       label = '五目並べセット',
       weight = 3000,
       stack = false,
       close = true,
       consume = 0,
       description = '使うと目の前に五目並べの卓を置く。卓の前で G で片付け',
       server = { export = 'kani-gomoku.gomoku_set' },
   },
   ```
2. `gomoku_set.png` を `ox_inventory/web/images/` に置く
3. サーバー再起動(または ox_inventory と kani-gomoku を restart)
4. 確認: 管理者で `/giveitem <自分のID> gomoku_set 1` → インベントリから使う

## QBCore (qb-inventory) / ESX の場合
- QBCore: `qb-core/shared/items.lua` に `gomoku_set` を追加(`useable = true`)。画像は qb-inventory の images へ
- ESX: `items` テーブルに `gomoku_set` を追加
- どちらも「使う」の登録は kani-gomoku が自動で行う
