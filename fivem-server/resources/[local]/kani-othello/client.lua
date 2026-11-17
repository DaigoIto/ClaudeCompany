local isOpen = false
local currentTable = nil   -- 着席中の卓id
local mySeat = nil         -- 1 or 2
local seated = false

local spawned = {}         -- [tid] = { table = obj, chairs = {obj, obj}, top = z }
local boards = {}          -- [tid] = { stones = {{x,y,c}...}, names = {n1, n2}, last = {x,y} }

---------------------------------------------------------------- helpers
local function toWorld(t, ox, oy, oz)
    local r = math.rad(t.heading or 0.0)
    local cs, sn = math.cos(r), math.sin(r)
    return vec3(t.coords.x + ox * cs - oy * sn, t.coords.y + ox * sn + oy * cs, t.coords.z + (oz or 0.0))
end

-- 固定の卓 (Config.Tables) + アイテムで置かれた卓 (サーバーから受信)
local placedTables = {}
local allList = Config.Tables
local function rebuildAll()
    allList = {}
    for _, t in ipairs(Config.Tables) do allList[#allList + 1] = t end
    for _, t in ipairs(placedTables) do allList[#allList + 1] = t end
end
local function allTables() return allList end

local function tableById(tid)
    for _, t in ipairs(allList) do if t.id == tid then return t end end
end

local function loadFirstModel(list)
    for _, name in ipairs(list) do
        local hash = joaat(name)
        if IsModelInCdimage(hash) and IsModelValid(hash) then
            RequestModel(hash)
            local n = 0
            while not HasModelLoaded(hash) and n < 100 do Wait(50) n = n + 1 end
            if HasModelLoaded(hash) then return hash end
        end
    end
end

-- 席の位置と向き(卓の方を向く)。席1は卓の手前(-Y)、席2は奥(+Y)
local function seatPose(t, seat)
    local d = Config.SeatDistance
    local oy = seat == 1 and -d or d
    local heading = (t.heading or 0.0) + (seat == 1 and 0.0 or 180.0)
    return toWorld(t, 0.0, oy, 0.0), heading
end

local function drawText3D(pos, text)
    SetDrawOrigin(pos.x, pos.y, pos.z, 0)
    SetTextScale(0.0, 0.32)
    SetTextFont(0)
    SetTextCentre(true)
    SetTextOutline()
    SetTextColour(232, 198, 106, 230)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

---------------------------------------------------------------- 着席
local function sitDown()
    local t = tableById(currentTable)
    if not t or not mySeat or seated then return end
    local pos, heading = seatPose(t, mySeat)
    local sp = spawned[t.id]
    local z = pos.z - 1.0
    if sp and sp.chairs[mySeat] then z = GetEntityCoords(sp.chairs[mySeat]).z end
    TaskStartScenarioAtPosition(PlayerPedId(), Config.SitScenario, pos.x, pos.y, z + Config.SitZOffset, heading, 0, true, true)
    seated = true
end

local function standUp()
    if seated then ClearPedTasks(PlayerPedId()) end
    seated = false
end

---------------------------------------------------------------- UI
local function setOpen(open, tableId)
    isOpen = open
    SetNuiFocus(open, open)
    if open then
        local bd = tableId and boards[tableId]
        SendNUIMessage({ type = 'open', tableId = tableId, bets = Config.Bets, maxBet = Config.MaxBet, currency = Config.Currency, tableBet = bd and bd.bet or nil })
        if tableId then TriggerServerEvent('kani-othello:getMoney') end
    else
        SendNUIMessage({ type = 'close' })
    end
end

local function leaveTable()
    if currentTable then
        TriggerServerEvent('kani-othello:leave')
        currentTable, mySeat = nil, nil
    end
    standUp()
end

RegisterCommand(Config.Command, function()
    if not isOpen then setOpen(true, nil) end
end, false)

---------------------------------------------------------------- ブリップ
CreateThread(function()
    for _, t in ipairs(Config.Tables) do
        local blip = AddBlipForCoord(t.coords.x, t.coords.y, t.coords.z)
        SetBlipSprite(blip, 304)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 5)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(t.label)
        EndTextCommandSetBlipName(blip)
    end
end)

---------------------------------------------------------------- 卓と椅子の生成(近くに来たら)
-- 床の高さを取得 (マップが未読込なら少し待つ。取れなければ座標の1m下)
local function groundZ(t)
    for _ = 1, 15 do
        local found, gz = GetGroundZFor_3dCoord(t.coords.x, t.coords.y, t.coords.z + 0.5, false)
        if found then return gz end
        Wait(100)
    end
    return t.coords.z - 1.0
end

local function spawnTable(t)
    local sp = { chairs = {} }
    local D = Config.TableDesign
    sp.ground = groundZ(t)
    sp.top = sp.ground + D.height          -- 天板の上面の高さ (机本体は drawTable で描く)

    -- 当たり判定だけ欲しい場合: 透明なプロップを置く(任意)
    if D.collisionModel then
        local hash = loadFirstModel({ D.collisionModel })
        if hash then
            local obj = CreateObject(hash, t.coords.x, t.coords.y, sp.ground, false, false, false)
            SetEntityHeading(obj, t.heading or 0.0)
            PlaceObjectOnGroundProperly(obj)
            SetEntityVisible(obj, false, false)
            FreezeEntityPosition(obj, true)
            sp.table = obj
            SetModelAsNoLongerNeeded(hash)
        end
    end

    local ch = loadFirstModel(Config.ChairModels)
    if ch then
        for seat = 1, 2 do
            local pos, heading = seatPose(t, seat)
            local obj = CreateObject(ch, pos.x, pos.y, pos.z - 1.0, false, false, false)
            SetEntityHeading(obj, heading + Config.ChairHeadingOffset)
            PlaceObjectOnGroundProperly(obj)
            FreezeEntityPosition(obj, true)
            sp.chairs[seat] = obj
        end
        SetModelAsNoLongerNeeded(ch)
    end
    spawned[t.id] = sp
end

local function despawnTable(tid)
    local sp = spawned[tid]
    if not sp then return end
    if sp.table then DeleteEntity(sp.table) end
    for _, c in pairs(sp.chairs) do DeleteEntity(c) end
    spawned[tid] = nil
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local exists = {}
        for _, t in ipairs(allTables()) do
            exists[t.id] = true
            local near = #(pos - t.coords) < 80.0
            if near and not spawned[t.id] then spawnTable(t)
            elseif not near and spawned[t.id] then despawnTable(t.id) end
        end
        for tid in pairs(spawned) do        -- 片付けられた卓の椅子を消す
            if not exists[tid] then despawnTable(tid) end
        end
        Wait(1000)
    end
end)

---------------------------------------------------------------- 3D描画 (黒い机 + 盤面)
-- 卓ローカル座標(ox,oy) + 絶対高さ zabs -> ワールド座標
local function W(t, ox, oy, zabs)
    return toWorld(t, ox, oy, zabs - t.coords.z)
end

-- 三角形/四角形 (カリングされないよう両面を描く)
local function tri2(a, b, c, col)
    DrawPoly(a.x,a.y,a.z, b.x,b.y,b.z, c.x,c.y,c.z, col[1],col[2],col[3],255)
    DrawPoly(c.x,c.y,c.z, b.x,b.y,b.z, a.x,a.y,a.z, col[1],col[2],col[3],255)
end
local function quad(a, b, c, d, col)
    tri2(a, b, c, col)
    tri2(a, c, d, col)
end

-- 直方体 (底面は描かない)。edge を渡すと上面の縁に線を引く
local function drawBox(t, cx, cy, hx, hy, z0, z1, topCol, sideCol, edge)
    local p = {
        W(t, cx-hx, cy-hy, z0), W(t, cx+hx, cy-hy, z0), W(t, cx+hx, cy+hy, z0), W(t, cx-hx, cy+hy, z0),
        W(t, cx-hx, cy-hy, z1), W(t, cx+hx, cy-hy, z1), W(t, cx+hx, cy+hy, z1), W(t, cx-hx, cy+hy, z1),
    }
    quad(p[5], p[6], p[7], p[8], topCol)
    quad(p[1], p[2], p[6], p[5], sideCol)
    quad(p[2], p[3], p[7], p[6], sideCol)
    quad(p[3], p[4], p[8], p[7], sideCol)
    quad(p[4], p[1], p[5], p[8], sideCol)
    if edge then
        for i = 0, 3 do
            local a, b = p[5 + i], p[5 + (i + 1) % 4]
            DrawLine(a.x,a.y,a.z, b.x,b.y,b.z, edge[1],edge[2],edge[3],255)
        end
    end
end

-- 黒い机: 天板 + 4本脚
local function drawTable(t, sp)
    local D = Config.TableDesign
    local half = D.size / 2
    local topZ = sp.top
    local slabZ = topZ - D.thickness
    local lh = D.legSize / 2
    local lo = half - D.legInset - lh
    for _, sx in ipairs({ -1, 1 }) do
        for _, sy in ipairs({ -1, 1 }) do
            drawBox(t, sx * lo, sy * lo, lh, lh, sp.ground, slabZ, D.legColor, D.legColor)
        end
    end
    drawBox(t, 0.0, 0.0, half, half, slabZ, topZ, D.topColor, D.sideColor, D.edgeColor)
end

local function drawBoard(t, sp)
    local B = Config.Board
    local S, half = B.size, B.size / 2
    local step = S / 8
    local base = sp.top + B.zOffset            -- 枠の高さ
    local zf = base                            -- 枠(木)
    local zb = base + 0.004                    -- 盤面(フェルト)
    local zl = base + 0.006                    -- 罫線・星
    local zs = base + 0.006                    -- 石の下面
    local fw = B.frameWidth
    local fc, c, lc = B.frameColor, B.color, B.lineColor

    -- 枠(木)と盤面(緑)
    local o = half + fw
    quad(W(t,-o,-o,zf), W(t,o,-o,zf), W(t,o,o,zf), W(t,-o,o,zf), fc)
    quad(W(t,-half,-half,zb), W(t,half,-half,zb), W(t,half,half,zb), W(t,-half,half,zb), c)

    -- 罫線
    for i = 0, 8 do
        local p = -half + i * step
        local a, b = W(t, p, -half, zl), W(t, p, half, zl)
        DrawLine(a.x,a.y,a.z, b.x,b.y,b.z, lc[1],lc[2],lc[3],255)
        a, b = W(t, -half, p, zl), W(t, half, p, zl)
        DrawLine(a.x,a.y,a.z, b.x,b.y,b.z, lc[1],lc[2],lc[3],255)
    end
    -- 星(4か所)
    local sc = B.starColor
    for _, ix in ipairs({ 2, 6 }) do
        for _, iy in ipairs({ 2, 6 }) do
            local w = W(t, -half + ix * step, half - iy * step, zl + 0.0005)
            DrawMarker(1, w.x, w.y, w.z, 0,0,0, 0,0,0, 0.012, 0.012, 0.001, sc[1], sc[2], sc[3], 255, false, false, 2, false, nil, nil, false)
        end
    end

    -- 石 (盤の(x,y) → 卓ローカル座標。y=0 が席2側(奥))。円盤(円柱)で描く
    local bd = boards[t.id]
    if bd then
        local d, h = B.stoneScale, B.stoneHeight
        for _, st in ipairs(bd.stones) do
            local w = W(t, -half + (st[1] + 0.5) * step, half - (st[2] + 0.5) * step, zs + h * 0.5)
            local col = st[3] == 1 and 245 or 18
            DrawMarker(1, w.x, w.y, w.z, 0,0,0, 0,0,0, d, d, h, col, col, col, 255, false, false, 2, false, nil, nil, false)
        end
        if bd.last then
            local w = W(t, -half + (bd.last[1] + 0.5) * step, half - (bd.last[2] + 0.5) * step, zs + h + 0.001)
            DrawMarker(1, w.x, w.y, w.z, 0,0,0, 0,0,0, d * 0.28, d * 0.28, 0.002, 224, 48, 30, 255, false, false, 2, false, nil, nil, false)
        end
        local n1, n2 = bd.names[1], bd.names[2]
        local label = (n1 and n2) and (n1 .. '  vs  ' .. n2) or ((n1 or n2) and ((n1 or n2) .. '  vs  募集中') or '空席')
        if (n1 or n2) and bd.bet then
            label = label .. (bd.bet > 0 and ('  [賭け金 ' .. Config.Currency .. bd.bet .. ']') or '  [賭けなし]')
        end
        drawText3D(W(t, 0.0, 0.0, zb + 0.6), label)
    else
        drawText3D(W(t, 0.0, 0.0, zb + 0.6), '空席')
    end
end

CreateThread(function()
    while true do
        local wait = 500
        local pos = GetEntityCoords(PlayerPedId())
        for _, t in ipairs(allTables()) do
            local d = #(pos - t.coords)
            local sp = spawned[t.id]
            if sp and d < Config.BoardDist then
                wait = 0
                drawTable(t, sp)
                drawBoard(t, sp)
            end
            if not isOpen and not seated and d < Config.DrawDist then
                wait = 0
                local m = toWorld(t, 0.0, -(Config.SeatDistance + 0.8), -0.95)
                DrawMarker(1, m.x, m.y, m.z, 0,0,0, 0,0,0, 0.8,0.8,0.4, 232,198,106, 120, false, false, 2, false)
                local nearE = #(pos - vec3(m.x, m.y, pos.z)) < Config.UseDist
                if nearE then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ ' .. t.label .. 'を開く')
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustReleased(0, Config.UseKey) then
                        setOpen(true, t.id)
                    end
                elseif t.placed then
                    -- アイテムで置いた卓: 空いていれば横に立って G で片付け
                    local bd = boards[t.id]
                    local empty = not bd or (not bd.names[1] and not bd.names[2])
                    if empty then
                        for _, sx in ipairs({ -1, 1 }) do
                            local pt = toWorld(t, sx * 0.95, 0.0, 0.0)
                            if #(vec2(pos.x, pos.y) - vec2(pt.x, pt.y)) < 0.8 then
                                BeginTextCommandDisplayHelp('STRING')
                                AddTextComponentSubstringPlayerName('~INPUT_DETONATE~ ' .. t.label .. 'を片付ける')
                                EndTextCommandDisplayHelp(0, false, true, -1)
                                if IsControlJustReleased(0, Config.Placeable.PickupKey) then
                                    TriggerServerEvent('kani-othello:pickupTable', t.id)
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
        Wait(wait)
    end
end)

---------------------------------------------------------------- NUI -> client
RegisterNUICallback('close', function(_, cb)
    leaveTable()
    setOpen(false)
    cb('ok')
end)

RegisterNUICallback('join', function(data, cb)
    currentTable = tonumber(data.tableId)
    TriggerServerEvent('kani-othello:join', currentTable, tonumber(data.bet))
    cb('ok')
end)

RegisterNUICallback('leave', function(_, cb)
    leaveTable()
    cb('ok')
end)

RegisterNUICallback('move', function(data, cb)
    TriggerServerEvent('kani-othello:move', tonumber(data.x), tonumber(data.y))
    cb('ok')
end)

RegisterNUICallback('next', function(_, cb)
    TriggerServerEvent('kani-othello:next')
    cb('ok')
end)

---------------------------------------------------------------- server -> client
RegisterNetEvent('kani-othello:state', function(state)
    if state.mySeat and currentTable then
        mySeat = state.mySeat
        sitDown()
    end
    SendNUIMessage({ type = 'state', state = state })
end)

RegisterNetEvent('kani-othello:money', function(amount)
    SendNUIMessage({ type = 'money', money = amount })
end)

-- 着席できなかった / 所持金不足で卓から外れた: メニューへ戻す
RegisterNetEvent('kani-othello:kicked', function(text, tid, bet)
    currentTable, mySeat = nil, nil
    standUp()
    SendNUIMessage({ type = 'kicked', text = text, tableId = tid, tableBet = bet })
end)

-- アイテムで置かれた卓の一覧 (置く/片付けるたびに全員へ)
RegisterNetEvent('kani-othello:placed', function(list)
    placedTables = {}
    local keep = {}
    for _, p in ipairs(list or {}) do
        keep[p.id] = true
        placedTables[#placedTables + 1] = {
            id = p.id, label = Config.Placeable.Label, coords = vec3(p.x, p.y, p.z), heading = p.h, placed = true,
        }
    end
    for tid in pairs(boards) do          -- 片付けられた卓の盤面データを捨てる
        if tid >= 1000 and not keep[tid] then boards[tid] = nil end
    end
    rebuildAll()
end)

RegisterNetEvent('kani-othello:toast', function(text)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, true)
end)

RegisterNetEvent('kani-othello:notice', function(text)
    SendNUIMessage({ type = 'notice', text = text })
end)

-- 全員に配られる盤面 (見物用)。board は 64文字の '0'/'1'/'2'
RegisterNetEvent('kani-othello:board', function(tid, board, names, last, bet)
    local stones = {}
    if board then
        for i = 1, #board do
            local v = board:byte(i) - 48
            if v > 0 then
                local idx = i - 1
                stones[#stones + 1] = { idx % 8, idx // 8, v }
            end
        end
    end
    boards[tid] = { stones = stones, names = names or {}, last = last and { last.x, last.y } or nil, bet = bet }
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then TriggerServerEvent('kani-othello:requestBoards') end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    standUp()
    for tid in pairs(spawned) do despawnTable(tid) end
end)
