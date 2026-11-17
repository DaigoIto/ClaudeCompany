Config = {}

-- 拠点広場の中心 (砂漠の平地 Sandy Shores 付近の空き地)
Config.Center = vector3(1700.0, 3250.0, 41.1)

-- 配置するオブジェクト: model, 中心からのオフセット(x,y,z), 向き(heading)
-- モデル名は https://gta-objects.xyz などで探して追加できます
Config.Props = {
    -- 中央のステージ
    { 'prop_beach_fire',        vec3(0.0, 0.0, 0.0),    0.0 },
    { 'prop_bench_01a',         vec3(4.0, 0.0, 0.0),   90.0 },
    { 'prop_bench_01a',         vec3(-4.0, 0.0, 0.0), 270.0 },
    { 'prop_bench_01a',         vec3(0.0, 4.0, 0.0),  180.0 },
    { 'prop_bench_01a',         vec3(0.0, -4.0, 0.0),   0.0 },
    -- 街灯
    { 'prop_streetlight_01',    vec3(8.0, 8.0, 0.0),    0.0 },
    { 'prop_streetlight_01',    vec3(-8.0, 8.0, 0.0),   0.0 },
    { 'prop_streetlight_01',    vec3(8.0, -8.0, 0.0),   0.0 },
    { 'prop_streetlight_01',    vec3(-8.0, -8.0, 0.0),  0.0 },
    -- 看板・バリア
    { 'prop_roadcone02a',       vec3(12.0, 0.0, 0.0),   0.0 },
    { 'prop_roadcone02a',       vec3(-12.0, 0.0, 0.0),  0.0 },
    { 'prop_barrier_work05',    vec3(0.0, 14.0, 0.0),   0.0 },
    { 'prop_barrier_work05',    vec3(0.0, -14.0, 0.0),  0.0 },
}

-- 広場に置く乗り物
Config.Vehicles = {
    { 'adder',   vec3(10.0, 3.0, 0.0),  90.0 },
    { 'sanchez', vec3(10.0, -3.0, 0.0), 90.0 },
}

-- マップ上のブリップ
Config.Blip = { sprite = 436, colour = 5, label = '拠点広場' }
