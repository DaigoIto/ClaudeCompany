# kani-othello 導入メモ(BANAN_City / Qbox)

このファイルと `othello_table.png` はアップロードしないこと(メモ・友人に渡す用)。アップロードするのは `kani-othello` フォルダだけ。

## 1. アップロード手順(オーナー作業)
1. **バックアップ**: サーバーの `[Kani-script]` を WinSCP でダウンロードして `BANAN_City\server-copy\` に保存
2. `my-changes\[Kani-script]\kani-othello` フォルダごと、次へアップロード
   `/opt/fivem/fivem_server/txData/Qbox_5515B3.base/resources/[Kani-script]/kani-othello`
3. リソースを再起動(または `ensure kani-othello`)

## 2. 友人(サーバー管理者)に頼むこと — `[Kani-script]` の外なので私は触れない
### (a) アイテムの追加: `ox_inventory/data/items.lua`
```lua
['othello_table'] = {
    label = 'オセロ卓',
    weight = 3000,
    stack = false,
    close = true,
    consume = 0,   -- 消費はしない(ox 側で消さない)
    description = '地面に置いてオセロができる卓',
},
```
- アイテムを配る(ショップ・クラフト・管理者コマンドなど)のは友人側の運用
- アイテム画像(任意): 同じフォルダの `othello_table.png` を `ox_inventory/web/images/othello_table.png` に

### (b) 起動設定(`[Kani-script]` が起動対象でない場合のみ)
`server.cfg` に `ensure kani-othello`(`ensure [Kani-script]` 等で既に起動されるなら不要)

### (c) 依存(たぶん導入済み)
- `qbx_core`(お金: cash を自動検出 / アイテムの「使う」を登録)
- `ox_inventory`(アイテム)
- `ox_target`(心の目(Alt)から「着席する」「片付ける」を選ぶ。無い場合は、床のマーカー + E キー(着席)/ G キー(片付け)の方式で動く)

### (d) 任意: 管理者が他人の卓を片付けられるようにする
`server.cfg` などで `add_ace group.admin command.othellopickup allow`

## 3. 動作確認チェックリスト
- アイテム使用 → 目の前に黒い卓・オセロ盤・椅子2脚が出る(自作モデル。石がマスの中央に乗るか)
- 卓に心の目(Alt)を合わせて「着席する」→ メニュー(賭け金入力 / CPU戦)。CPU戦は卓から。床のマーカー(ポータル)は出ない
- 2人で座って対局(賭けなし → 賭けあり)。賭け金の預かり・勝者への支払い・引き分けの返金
- 対局中に片方が退席 → 引き分け・返金、相手も卓から外れる
- 持ち主がログアウト/切断 → 卓が消える(座っていた人はメニューへ戻る)
- 空の卓を心の目の「片付ける」で片付け(持ち主だけに出る) → 卓が消える(アイテムは消費しないので持ち物はそのまま)
- 白が先手。置ける所が無い側は自動でパスされる。両者置けなければ終局で石の多い方の勝ち
- 石が裏返るたびに、卓の上の円盤の色が変わる(白黒がマスに乗っているか)
- 卓をすり抜けないか(当たり判定)
- 椅子の向き(`ChairHeadingOffset`)・座る位置(`SeatDistance`)・座る高さ(`SitZOffset`)が合っているか

## 4. 設定の場所
`kani-othello/config.lua`(賭け金上限 `MaxBet`、手数料 `Rake`、置く卓の設定 `Item` など)

## 5. 既知の注意点
- 切断した側への賭け金返金は、Qbox がプレイヤー情報を先に消すと失敗することがある(残った側は確実)
- キャラクターのログアウト検知はフレームワークのイベントに依存。Qbox で卓が消えない場合は連絡
- 卓・オセロ盤・円盤の元データは `BANAN_City\assets\kani-othello\`(アップロード不要)
