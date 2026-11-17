# kani-gomoku 導入メモ(BANAN_City / Qbox)

このファイルと `gomoku_set.png` はアップロードしないこと(メモ・友人に渡す用)。アップロードするのは `kani-gomoku` フォルダだけ。

## 1. アップロード手順(オーナー作業)
1. **バックアップ**: サーバーの `[Kani-script]` を WinSCP でダウンロードして `BANAN_City\server-copy\` に保存
2. `my-changes\[Kani-script]\kani-gomoku` フォルダごと、次へアップロード
   `/opt/fivem/fivem_server/txData/Qbox_5515B3.base/resources/[Kani-script]/kani-gomoku`
3. リソースを再起動(または `ensure kani-gomoku`)

## 2. 友人(サーバー管理者)に頼むこと — `[Kani-script]` の外なので私は触れない
### (a) アイテムの追加: `ox_inventory/data/items.lua`
```lua
['gomoku_set'] = {
    label = '五目並べセット',
    weight = 3000,
    stack = false,
    close = true,
    consume = 0,   -- 消費はしない(ox 側で消さない)
    description = '地面に置いて五目並べができる卓',
},
```
- アイテムを配る(ショップ・クラフト・管理者コマンドなど)のは友人側の運用
- アイテム画像(任意): 同じフォルダの `gomoku_set.png` を `ox_inventory/web/images/gomoku_set.png` に

### (b) 起動設定(`[Kani-script]` が起動対象でない場合のみ)
`server.cfg` に `ensure kani-gomoku`(`ensure [Kani-script]` 等で既に起動されるなら不要)

### (c) 依存(たぶん導入済み)
- `qbx_core`(お金: cash を自動検出 / アイテムの「使う」を登録)
- `ox_inventory`(アイテム)
- `ox_target`(Alt の目から片付け。無くても G キーで片付け可)

### (d) 任意: 管理者が他人の卓を片付けられるようにする
`server.cfg` などで `add_ace group.admin command.gomokupickup allow`

## 3. 動作確認チェックリスト
- アイテム使用 → 目の前に木の卓・碁盤・椅子2脚が出る(自作モデル。碁盤の線に石が乗るか)
- 卓の席側で E → メニュー(賭け金入力 / CPU戦)。CPU戦は卓から
- 2人で座って対局(賭けなし → 賭けあり)。賭け金の預かり・勝者への支払い・引き分けの返金
- 対局中に片方が退席 → 引き分け・返金、相手も卓から外れる
- 持ち主がログアウト/切断 → 卓が消える(座っていた人はメニューへ戻る)
- 空の卓を G / Alt の目で片付け → 卓が消える(アイテムは消費しないので持ち物はそのまま)
- 卓をすり抜けないか(当たり判定)
- 椅子の向き(`ChairHeadingOffset`)・座る位置(`SeatDistance`)・座る高さ(`SitZOffset`)が合っているか

## 4. 設定の場所
`kani-gomoku/config.lua`(賭け金上限 `MaxBet`、手数料 `Rake`、置く卓の設定 `Item` など)

## 5. 既知の注意点
- 切断した側への賭け金返金は、Qbox がプレイヤー情報を先に消すと失敗することがある(残った側は確実)
- キャラクターのログアウト検知はフレームワークのイベントに依存。Qbox で卓が消えない場合は連絡
- 卓・碁盤・石の元データは `BANAN_City\assets\kani-gomoku\`(アップロード不要)
