# kani-othello — オセロ for FiveM

kani-gomoku と同じ構成。フレームワーク非依存。

- CPU戦も卓から(卓のメニュー →「CPUと対戦」)。卓を開くコマンドは無い
- 卓の近くで E : 2人対戦。卓はアイテムで置く(下記)。固定卓は初期状態では無し(必要なら `Config.Tables` に追加)。判定はサーバー側で管理
- ルール: 8×8。白(先手)が先に打ち、後手は黒。置ける所が無ければ自動パス、両者置けなければ終局。石の多い方が勝ち
- 先手後手は1戦ごとに交代。勝ち数を表示

## 導入
`resources/[local]/kani-othello` を置いて `server.cfg` に `ensure kani-othello`。
卓の座標・プロップ・キーは `config.lua`。

## 卓と盤面(3D)
- 机はモデルを使わず、スクリプトで黒い天板+4本脚を描画(`Config.TableDesign` でサイズ・色・高さを調整)。当たり判定は無し(通り抜け可)。必要なら `collisionModel` に透明な当たり判定用プロップを指定
- 盤面は 木の枠+緑の盤面+罫線+星+円盤状の石(`Config.Board`)。直前の手に赤いマーカー
- 椅子は既存モデル(`Config.ChairModels`)

## アイテムで机を出す(可搬式の卓)
- アイテム `othello_table`(`Config.Placeable.Item`)を使うと、目の前(1.4m)に卓が置かれる。**アイテムは消費しない**
- 空いている卓は、横に立って **G**、またはターゲット(**Alt の目**。ox_target / qb-target があるとき)の「片付ける」で消せる(置いた本人のみ。管理者は ace `command.othellopickup` で可)
- 1人1台まで・サーバー全体20台まで・他の卓と2.5m以上離す
- **卓は保存しない**: 持ち主のログアウト(キャラ切替含む)・切断、サーバー/リソースの停止で、卓は自動で片付く。座っていた人は退席扱い(対局中なら賭け金は返金)
- 卓を出すコマンドは無い(アイテムのみ)。アイテムの仕組みが無いスタンドアロン構成では卓を置けない
- 使えるアイテムの登録は Qbox / QBCore / ESX は自動
- ログアウトの検知は、フレームワークのイベント(`QBCore:Server:OnPlayerUnload` / `esx:playerLogout`)と切断(`playerDropped`)に依存

### アイテム定義(サーバー側の別リソースに追加が必要)
ox_inventory の `data/items.lua`:
```lua
['othello_table'] = {
    label = 'オセロ卓',
    weight = 5000,
    stack = false,
    close = true,
    consume = 0,   -- 消費はこのリソースが扱わない(アイテムは減らない)ので ox 側でも消さない
    description = '使うと目の前にオセロの卓を置く。卓の横で G(またはAltの目)で片付け',
    server = { export = 'kani-othello.othello_table' },
},
```
- QBCore は `qb-core/shared/items.lua`(`useable = true`)、ESX は `items` テーブルに同名のアイテムを追加。「使う」の登録はこのリソースが自動で行う
- 二重に反応しても、1.5秒以内の連続使用は無視されるので卓は1台しか置かれない
- 友人サーバー(BANAN_City)では、これらは `[Kani-script]` の外なので、サーバー管理者側で追加が必要

## 賭け(対人戦のみ。CPU戦は賭けなし)
設定は `config.lua` の「賭け」ブロックに集約。

| 設定 | 初期値 | 内容 |
|---|---|---|
| `Config.MaxBet` | 50,000,000 | 賭け金の上限(0〜上限の整数を自由入力。0 = 賭けなし) |
| `Config.Bets` | 0 / 1千 / 1万 / 10万 / 100万 / 1000万 | 入力欄横のクイック選択ボタン |
| `Config.Rake` | 0 | 手数料(%)。勝者の受取額から引く |
| `Config.Currency` | `$` | 通貨記号(表示用) |
| `Config.Money.Framework` | `auto` | `auto` / `qbx` / `qb` / `esx` / `standalone` |
| `Config.Money.Account` | `cash` | `cash` or `bank` |
| `Config.Money.StartBalance` | 10000 | 内蔵財布の初期所持金(初回のみ) |

### ルール
1. 卓に最初に座った人が賭け金を入力。2人目は金額を確認して「承諾して着席」(承諾額が卓の現在額と違えば拒否)
2. 対局開始時(再戦ごと)に両者から賭け金を預かる
3. 勝者が預かり金を全額(手数料を引いて)受け取る。引き分けは返金
4. 対局中の退席・切断は引き分け扱いで両者に全額返金(没収なし)。退席前に警告ダイアログが出る。どちらかが退席・切断すると相手も卓から外れる
5. 再戦時に所持金が足りない人は卓から外れる(相手も外れる)

### 金銭
- Qbox / QBCore / ESX を自動検出。どれも無ければ内蔵の財布(license ごとに保存)
- 内蔵財布: `/othellowallet` で所持金表示、`othellogive <ID> <金額>` で付与(サーバーコンソール、または ace `command.othellogive`)
- 切断時の返金: 切断した側の返金は、フレームワークが切断時にプレイヤー情報を先に消すと失敗することがある(残った側は確実)
