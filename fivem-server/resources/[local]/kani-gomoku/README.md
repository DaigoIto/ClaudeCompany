# kani-gomoku — 五目並べ for FiveM

フレームワーク非依存(Qbox/ESX/QBCore どれでも/なしでも動く)。

- アイテム「五目並べセット」(`gomoku_set`)を使う : 目の前に卓を置く。置いた人は卓の前で G で片付け
  - アイテムは減らない。置けるのは1人1卓、サーバー全体で `Config.Item.MaxPlaced` 卓まで。置いた人が抜けると卓も消える
  - インベントリへの登録手順は `install/README.md`(ox_inventory 用の定義とアイコン画像入り)
- 卓の近くで E : 2人対戦(賭けあり)か CPU 戦(強さ3段階)。2人座ると開始、勝敗判定はサーバー側で管理
- 常設の卓も `Config.Tables` に座標を書けば置ける。`Config.Command` にコマンド名を入れると、どこでも CPU 戦を開ける(初期値は無し)
- ルール: 15×15・五連以上で勝ち。1局ごとに先手(黒)を交代し、勝ち数を表示

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
- テーブル+椅子2脚を自動配置(`Config.TableModels` / `Config.ChairModels` の先頭から存在するモデルを使用。カジノ卓はゲームビルド2060以上)
- 卓・碁盤・石は自作モデル(`stream/` の `kani_gomoku_table` / `kani_goban` / `kani_stone_black` / `kani_stone_white`、定義は `kani_gomoku.ytyp`)。卓には当たり判定あり。椅子はGTAの既存モデル
- 自作の碁盤が読めないときは、盤と石を簡易描画(`Config.Board`)に切り替える
- モデルの元データと変換スクリプトは `assets/kani-gomoku/`(`sollumz/build_sollumz.py` を Blender + Sollumz で実行すると作り直せる)
- 対人戦で着席すると席1/席2の椅子に座るアニメーション。閉じると立つ
- 卓の上に3D盤面。対局中の石・最終手・対局者名が周りの全員に見える
- 椅子の向き・座る高さ・石の大きさは `config.lua` で調整

## 導入
1. `kani-gomoku` フォルダをリソースに置き、起動されるようにする(`ensure kani-gomoku` など)
2. `install/README.md` の手順でアイテム `gomoku_set` をインベントリに登録
3. 設定は `config.lua`
