# kani-othello — オセロ for FiveM

フレームワーク非依存(Qbox/ESX/QBCore どれでも/なしでも動く)。kani-gomoku と同じ構成。

- アイテム「オセロ卓」(`othello_table`)を使う : 目の前に卓を置く。空いていれば G / ターゲット(Altの目)で片付け
  - アイテムは減らない。置けるのは1人1卓、サーバー全体で `Config.Item.MaxPlaced` 卓まで。持ち主のログアウト・切断で卓も消える
  - インベントリへの登録手順は `BANAN_City/my-changes/導入メモ_kani-othello.md`(ox_inventory 用の定義。アイコンは同じ場所の `othello_table.png`)
- 卓の近くで E : 2人対戦(賭けあり)か CPU 戦(強さ3段階)。2人座ると開始、判定・賭け金はサーバー側で管理
- 常設の卓も `Config.Tables` に座標を書けば置ける。`Config.Command` にコマンド名を入れると、どこでも CPU 戦を開ける(初期値は無し)
- ルール: 8×8。白が先手・黒が後手。置ける所が無ければ自動パス、両者置けなければ終局で石の多い方が勝ち。1戦ごとに先手(白)を交代し、勝ち数を表示

## 賭け (対人戦)
設定は `config.lua` の `MaxBet` / `Bets` / `Rake` / `Currency` / `Money`。
お金は Qbox → QBCore → ESX の順に自動検出し、どれも無ければ内蔵の財布(KVP保存)を使う(`money.lua`)。

1. 卓に最初に座った人が賭け金を入力(0〜MaxBet、0 は賭けなし)
2. 2人目は金額を確認して「承諾して着席」。承諾額が卓の金額と違えば拒否
3. 対局開始時と再戦のたびに両者から賭け金を預かる
4. 勝者が預かり金を全額受け取る(Rake% を引く)。引き分けは両者に返金
5. 対局中の退席・切断は引き分け扱いで両者に全額返金(没収なし)。退席前に警告。退席すると相手も卓から外れる
6. 再戦時に所持金が足りない人がいると、両者とも卓から外れる

## 卓
- 卓・オセロ盤・石は自作モデル(`stream/` の `kani_othello_table` / `kani_othello_board` / `kani_disc_white` / `kani_disc_black`、定義は `kani_othello.ytyp`)。卓は五目並べの卓を黒檀色にしたもので、当たり判定あり。椅子はGTAの既存モデル
- 自作モデルが読めないときは、卓はGTAの既存モデル、盤と石は簡易描画(`Config.Board`)に切り替える
- モデルの元データと変換スクリプトは `BANAN_City/assets/kani-othello/`(サーバーには上げない。`make_blend.py` で元データを作り、`sollumz/build_sollumz.py` を Blender + Sollumz で実行すると ydr/ytyp を作り直せる)
- 対人戦で着席すると席1/席2の椅子に座るアニメーション。閉じると立つ
- 卓の上に3D盤面。対局中の石・最終手・対局者名が周りの全員に見える
- 椅子の向き・座る高さ・石の大きさは `config.lua` で調整

## 導入
手順・友人に頼むこと・確認項目は `BANAN_City/my-changes/導入メモ_kani-othello.md`(kani-gomoku と同じ形式)
