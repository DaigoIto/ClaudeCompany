# kani-othello 導入メモ(BANAN_City / Qbox)

このファイルはアップロードしないこと(メモ用)。アップロードするのは `kani-othello` フォルダだけ。

## 1. アップロード手順(オーナー作業)
1. **バックアップ**: サーバーの `[Kani-script]` を WinSCP でダウンロードして `BANAN_City\server-copy\` に保存
2. `my-changes\[Kani-script]\kani-othello` フォルダごと、次へアップロード
   `/opt/fivem/fivem_server/txData/Qbox_5515B3.base/resources/[Kani-script]/kani-othello`
3. リソースを再起動(または `ensure kani-othello`)

## 2. 友人(サーバー管理者)に頼むこと — `[Kani-script]` の外なので私は触れない
### (a) アイテムの追加: `ox_inventory/data/items.lua`
詳しくは `ox_inventory登録用\オセロ卓の登録.md`(五目並べセットと同じ書き方)。
- アイテムを配る(ショップ・クラフト・管理者コマンドなど)のは友人側の運用

### (b) 起動設定(`[Kani-script]` が起動対象でない場合のみ)
`server.cfg` に `ensure kani-othello`(`ensure [Kani-script]` 等で既に起動されるなら不要)

### (c) 依存(たぶん導入済み)
- `qbx_core`(お金: cash を自動検出)
- `ox_inventory`(アイテム)
- `ox_target`(Alt の目から片付け。無くても G キーで片付け可)

## 3. 動作確認チェックリスト
- アイテム使用 → 目の前に黒い机と椅子と盤が出る
- 卓の席側で E → メニュー(賭け金入力 / CPU戦)。CPU戦は卓から
- 2人で座って対局(賭けなし → 賭けあり)。賭け金の預かり・勝者への支払い・引き分けの返金
- 対局中に片方が退席 → 引き分け・返金、相手も卓から外れる
- 持ち主がログアウト/切断 → 卓が消える(座っていた人はメニューへ戻る)
- 空の卓を G / Alt の目で片付け → 卓が消える(アイテムは消費しないので持ち物はそのまま)
- 椅子の向き(`ChairHeadingOffset`)・座る高さ(`SitZOffset`)・石の大きさ(`Board.stoneScale`)が合っているか

## 4. 設定の場所
`kani-othello/config.lua`(賭け金上限 `MaxBet`、手数料 `Rake`、卓の設定 `Placeable` など)

## 5. 既知の注意点
- 切断した側への賭け金返金は、Qbox がプレイヤー情報を先に消すと失敗することがある(残った側は確実)
- キャラクターのログアウト検知はフレームワークのイベントに依存。Qbox で卓が消えない場合は連絡
