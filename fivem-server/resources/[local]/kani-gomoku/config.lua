Config = {}

Config.Command   = false        -- どこでも CPU 戦を開けるコマンド名 (例 'gomoku')。false で無し
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

-- アイテム「五目並べセット」: 使うと目の前に卓を置く。置いた人だけが片付けられる
-- (アイテムは減らない。1人1卓まで。置いた人が抜けると卓も消える)
Config.Item = {
    Name       = 'gomoku_set',  -- インベントリのアイテム名
    Label      = '五目並べ卓',   -- 卓の上に出る名前
    MaxPlaced  = 10,            -- サーバー全体で置ける卓の数
    Distance   = 1.7,           -- 自分から卓の中心までの距離(m)
    MinGap     = 3.5,           -- 他の卓とあける間隔(m)
    PickupKey  = 47,            -- 片付けるキー (47 = G)
}

-- 常設の卓(任意)。座標を書けばアイテム無しでも置いておける (id は 1〜999)
-- coords: 卓の中心(プレイヤーが立つ高さ = 地面+約1m), heading: 卓の向き(席1→席2 がこの向き)
Config.Tables = {
    -- { id = 1, label = '五目並べ卓', coords = vec3(1694.0, 3256.0, 41.1), heading = 0.0 },
}

-- 卓・椅子のモデル。先頭から順に「ゲームに存在するもの」を使う
-- kani_ で始まるものはこのリソースの stream/ に入っている自作モデル
-- vw_ で始まるものはカジノDLC(ゲームビルド2060以上)が必要。無ければ次の候補になる
Config.TableModels = { 'kani_gomoku_table', 'vw_prop_casino_3cardpoker_01', 'prop_table_03' }
Config.ChairModels = { 'vw_prop_casino_chair_01a', 'prop_chair_01a' }

-- 自作の碁盤と石。読み込めなければ下の Config.Board の簡易描画になる
Config.BoardModel  = 'kani_goban'
Config.StoneModels = { 'kani_stone_black', 'kani_stone_white' }  -- 黒, 白

Config.SeatDistance       = 0.95  -- 卓の中心から椅子までの距離(m)
Config.ChairHeadingOffset = 0.0   -- 椅子が後ろ向きに出たら 180.0 に
Config.SitScenario        = 'PROP_HUMAN_SEAT_CHAIR_MP_PLAYER'
Config.SitZOffset         = 0.5   -- 座る高さの調整(椅子の位置からの上下)

-- 卓の上の3D盤面
-- size は罫線の端から端(自作の碁盤 kani_goban は 0.60 で線に合う)
-- zOffset / stoneScale / color / lineColor は自作の碁盤が使えないときの簡易描画用
Config.Board = {
    size       = 0.60,   -- 罫線の一辺(m)
    zOffset    = 0.01,   -- 卓の天板からの浮かせ量(m)
    stoneScale = 0.019,  -- 石の大きさ。大きすぎ/小さすぎたらここを調整
    color      = { 217, 168, 91 },
    lineColor  = { 60, 40, 15 },
}
