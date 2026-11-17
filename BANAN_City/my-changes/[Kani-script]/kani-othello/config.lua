Config = {}

Config.Command   = false        -- どこでも CPU 戦を開けるコマンド名 (例 'othello')。false で無し
Config.UseKey    = 38           -- 卓で押すキー (38 = E)
Config.DrawDist  = 12.0         -- マーカーを描画する距離
Config.UseDist   = 1.8          -- 操作できる距離
Config.BoardDist = 15.0         -- 3D盤面を描画する距離

-- 賭け (対人戦のみ)
Config.MaxBet   = 50000000      -- 賭け金の上限。0〜上限の整数を入力でき、0 は賭けなし
Config.Bets     = { 0, 1000, 10000, 100000, 1000000, 10000000 }  -- クイック選択ボタン
Config.Rake     = 0             -- 手数料(%)。勝者の受取額から引く
Config.Currency = '$'           -- 通貨記号(表示用)

Config.Money = {
    Framework    = 'auto',      -- auto / qbox / qbcore / esx / wallet
    Account      = 'cash',      -- cash / bank
    StartBalance = 10000,       -- 内蔵の財布(wallet)の初期所持金(初回のみ)
}

-- アイテム「オセロ卓」: 使うと目の前に卓を置く (kani-gomoku と同じルール)
-- アイテムは減らない。1人1卓まで。空いていれば G / ターゲット(Altの目)で片付け
-- 持ち主のログアウト・切断、サーバー停止で卓は消える(保存しない)
-- アイテム定義(ox_inventory の data/items.lua)はサーバー側で追加が必要 → my-changes/導入メモ_kani-othello.md
Config.Item = {
    Name       = 'othello_table',  -- インベントリのアイテム名
    Label      = 'オセロ卓',     -- 卓の上に出る名前
    MaxPlaced  = 10,            -- サーバー全体で置ける卓の数
    Distance   = 1.7,           -- 自分から卓の中心までの距離(m)
    MinGap     = 3.5,           -- 他の卓とあける間隔(m)
    PickupKey  = 47,            -- 片付けるキー (47 = G)
    UseTarget  = true,          -- ターゲット(Altの目: ox_target / qb-target)からも片付けられるようにする
    OnlyOwnerPickup = true,     -- 置いた本人だけ片付けられる。管理者(ace command.othellopickup)は常に可
}

-- 常設の卓(任意)。座標を書けばアイテム無しでも置いておける (id は 1〜999)
-- coords: 卓の中心(プレイヤーが立つ高さ = 地面+約1m), heading: 卓の向き(席1→席2 がこの向き)
Config.Tables = {
    -- { id = 1, label = 'オセロ卓', coords = vec3(1694.0, 3256.0, 41.1), heading = 0.0 },
}

-- 卓・椅子のモデル。先頭から順に「ゲームに存在するもの」を使う
-- kani_ で始まるものはこのリソースの stream/ に入っている自作モデル(卓は五目並べの卓を黒くしたもの)
-- vw_ で始まるものはカジノDLC(ゲームビルド2060以上)が必要。無ければ次の候補になる
Config.TableModels = { 'kani_othello_table', 'vw_prop_casino_3cardpoker_01', 'prop_table_03' }
-- 椅子は木製の prop_chair 系。先頭で存在するものが使われる(02 が無ければ 03、…の順)
-- 見た目や座る高さが合わなければ、先頭を入れ替えるか SitZOffset / ChairHeadingOffset で調整
Config.ChairModels = { 'prop_chair_02', 'prop_chair_03', 'prop_chair_04a', 'prop_chair_04b', 'prop_chair_05', 'prop_chair_01a' }

-- 自作のオセロ盤と石(円盤)。読み込めなければ下の Config.Board の簡易描画になる
-- 石の番号: 1 = 白(先手), 2 = 黒(後手)
Config.BoardModel  = 'kani_othello_board'
Config.StoneModels = { 'kani_disc_white', 'kani_disc_black' }  -- 白, 黒

Config.SeatDistance       = 0.95  -- 卓の中心から椅子までの距離(m)
Config.ChairHeadingOffset = 0.0   -- 椅子が後ろ向きに出たら 180.0 に
Config.SitScenario        = 'PROP_HUMAN_SEAT_CHAIR_MP_PLAYER'
Config.SitZOffset         = 0.5   -- 座る高さの調整(椅子の位置からの上下)

-- 卓の上の3D盤面 (8×8)
-- size はマス目全体の一辺(自作のオセロ盤 kani_othello_board は 0.60 でマスに合う)
-- zOffset / stoneScale / color / lineColor は自作の盤が使えないときの簡易描画用
Config.Board = {
    size       = 0.60,   -- マス目の一辺(m)。1マス = size / 8
    zOffset    = 0.01,   -- 卓の天板からの浮かせ量(m)
    stoneScale = 0.058,  -- 石の直径(m)。大きすぎ/小さすぎたらここを調整
    color      = { 20, 110, 60 },
    lineColor  = { 5, 40, 20 },
}
