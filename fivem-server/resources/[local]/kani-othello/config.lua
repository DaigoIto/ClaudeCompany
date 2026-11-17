Config = {}

Config.Command   = 'othello'    -- どこでも開けるコマンド(CPU戦)
Config.UseKey    = 38           -- 卓で押すキー (38 = E)
Config.DrawDist  = 12.0         -- マーカーを描画する距離
Config.UseDist   = 1.8          -- 操作できる距離
Config.BoardDist = 15.0         -- 3D盤面を描画する距離

-- ================================ 賭け(対人戦のみ。CPU戦は賭けなし) ================================
-- 流れ
--   1. 卓に最初に座った人が賭け金を自由入力(0〜MaxBet の整数。0 = 賭けなし)
--   2. 2人目は賭け金を確認して「承諾して着席」(承諾した金額が卓の現在の金額と違えば拒否)
--   3. 対局開始時(再戦ごと)に両者から賭け金を預かる
--   4. 勝者が預かり金を全額(手数料を引いて)受け取る。引き分けは両者に返金
--   5. 対局中の退席・切断は引き分け扱い: 両者に全額返金(没収なし)。相手も卓から外れる
--   6. 再戦時に所持金が足りない人は卓から外れる(相手も外れる)
Config.MaxBet   = 50000000   -- 賭け金の上限
Config.Bets     = { 0, 1000, 10000, 100000, 1000000, 10000000 }   -- 入力欄の横に出るクイック選択ボタン
Config.Rake     = 0          -- 手数料(%)。勝者の受取額から引く。0なら全額
Config.Currency = '$'        -- 通貨記号(表示用)

-- 金銭の扱い。Qbox / QBCore / ESX は自動検出。どれも無ければ内蔵の財布(license ごとに保存)
--   内蔵財布の操作: /othellowallet(所持金表示) / othellogive <ID> <金額>(付与。コンソールか ace command.othellogive)
Config.Money = {
    Framework    = 'auto',   -- 'auto' / 'qbx' / 'qb' / 'esx' / 'standalone'
    Account      = 'cash',   -- 'cash' or 'bank'
    StartBalance = 10000,    -- 内蔵財布の初期所持金(初回のみ)
}
-- ====================================================================================================

-- 対人戦の卓。座標を増やせば卓が増える (id は重複させない)
-- coords: 卓の中心(プレイヤーが立つ高さ = 地面+約1m), heading: 卓の向き(席1→席2 がこの向き)
-- 五目並べの卓(1694,3256)の隣に配置
Config.Tables = {
    { id = 1, label = 'オセロ卓', coords = vec3(1698.0, 3256.0, 41.1), heading = 0.0 },
}

-- 黒い机(スクリプトで描画。モデルは使わない)。サイズ・色はここで調整
Config.TableDesign = {
    size = 0.90,        -- 天板の一辺(m)
    thickness = 0.06,   -- 天板の厚み(m)
    height = 0.75,      -- 床から天板の上面までの高さ(m)
    legSize = 0.07,     -- 脚の太さ(m)
    legInset = 0.06,    -- 脚を天板の角から内側へ寄せる量(m)
    topColor  = { 24, 24, 28 },
    sideColor = { 10, 10, 12 },
    legColor  = { 14, 14, 16 },
    edgeColor = { 75, 75, 85 },   -- 天板の縁の線
    -- 描画だけの机には当たり判定が無い。歩いて通り抜けるのが気になるなら、透明な当たり判定用プロップを指定
    -- (例 'prop_table_03'。大きさが合わなければ使わない)。nil なら無し
    collisionModel = nil,
}

-- 椅子のモデル。先頭から順に「ゲームに存在するもの」を使う
Config.ChairModels = { 'vw_prop_casino_chair_01a', 'prop_chair_01a' }

Config.SeatDistance       = 0.95
Config.ChairHeadingOffset = 0.0   -- 椅子が後ろ向きに出たら 180.0 に
Config.SitScenario        = 'PROP_HUMAN_SEAT_CHAIR_MP_PLAYER'
Config.SitZOffset         = 0.5

-- 卓の上に置く3D盤面 (8x8)
Config.Board = {
    size        = 0.60,   -- 盤面(マス目部分)の一辺(m)
    zOffset     = 0.002,  -- 天板からの浮かせ量(m)
    frameWidth  = 0.035,  -- 木の枠の幅(m)
    stoneScale  = 0.058,  -- 石の直径(m)。大きすぎ/小さすぎたらここを調整
    stoneHeight = 0.012,  -- 石の厚み(m)
    color       = { 20, 110, 60 },    -- 盤面(緑)
    frameColor  = { 70, 42, 20 },     -- 枠(木)
    lineColor   = { 5, 40, 20 },
    starColor   = { 5, 40, 20 },
}
