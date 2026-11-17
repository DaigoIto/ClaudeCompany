local isOpen = false
local currentTable = nil   -- 着席中の卓id
local mySeat = nil         -- 1 or 2
local seated = false

local spawned = {}         -- [tid] = { table, chairs = {obj, obj}, top = z, goban, gobanTop = z, stoneObjs = {[x..','..y] = {obj, c}}, ver }
local boards = {}          -- [tid] = { stones = {{x,y,c}...}, names = {n1, n2}, last = {x,y}, ver }
local boardVer = 0
local tableList = {}       -- サーバーから届く卓の一覧 { id, label, coords, heading, owner }
local myServerId = GetPlayerServerId(PlayerId())

---------------------------------------------------------------- helpers
local function toWorld(t, ox, oy, oz)
    local r = math.rad(t.heading or 0.0)
    local cs, sn = math.cos(r), math.sin(r)
    return vec3(t.coords.x + ox * cs - oy * sn, t.coords.y + ox * sn + oy * cs, t.coords.z + (oz or 0.0))
end

local function tableById(tid)
    for _, t in ipairs(tableList) do if t.id == tid then return t end end
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
    SendNUIMessage({ type = open and 'open' or 'close', tableId = tableId })
end

local function leaveTable()
    if currentTable then
        TriggerServerEvent('kani-gomoku:leave')
        currentTable, mySeat = nil, nil
    end
    standUp()
end

if Config.Command then
    RegisterCommand(Config.Command, function()
        if not isOpen then setOpen(true, nil) end
    end, false)
end

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
local function spawnTable(t)
    local sp = { chairs = {} }
    local th = loadFirstModel(Config.TableModels)
    if th then
        local obj = CreateObject(th, t.coords.x, t.coords.y, t.coords.z - 1.0, false, false, false)
        SetEntityHeading(obj, t.heading or 0.0)
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
        local _, maxDim = GetModelDimensions(th)
        sp.table = obj
        sp.top = GetEntityCoords(obj).z + maxDim.z
        SetModelAsNoLongerNeeded(th)
    else
        sp.top = t.coords.z - 1.0 + 0.8
    end
    -- 自作の碁盤を天板に載せる
    local gh = Config.BoardModel and loadFirstModel({ Config.BoardModel })
    if gh then
        local c = toWorld(t, 0.0, 0.0, sp.top - t.coords.z)
        local obj = CreateObject(gh, c.x, c.y, c.z, false, false, false)
        SetEntityHeading(obj, t.heading or 0.0)
        SetEntityCoordsNoOffset(obj, c.x, c.y, c.z, false, false, false)
        FreezeEntityPosition(obj, true)
        SetEntityCollision(obj, false, false)
        local _, maxDim = GetModelDimensions(gh)
        sp.goban, sp.gobanTop = obj, c.z + maxDim.z
        SetModelAsNoLongerNeeded(gh)
        -- 石のモデルも読んでおく
        sp.stoneModels = {}
        for i, name in ipairs(Config.StoneModels or {}) do sp.stoneModels[i] = loadFirstModel({ name }) end
    end
    sp.stoneObjs = {}
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
    if sp.goban then DeleteEntity(sp.goban) end
    for _, s in pairs(sp.stoneObjs or {}) do DeleteEntity(s[1]) end
    for _, h in pairs(sp.stoneModels or {}) do SetModelAsNoLongerNeeded(h) end
    spawned[tid] = nil
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local alive = {}
        for _, t in ipairs(tableList) do
            alive[t.id] = true
            local near = #(pos - t.coords) < 80.0
            if near and not spawned[t.id] then spawnTable(t)
            elseif not near and spawned[t.id] then despawnTable(t.id) end
        end
        for tid in pairs(spawned) do
            if not alive[tid] then despawnTable(tid) end
        end
        Wait(2000)
    end
end)

---------------------------------------------------------------- 3D盤面の描画
-- 盤の(x,y) → 卓ローカル座標。y=0 が席2側(奥)
local function stoneLocal(gx, gy)
    local half, step = Config.Board.size / 2, Config.Board.size / 14
    return -half + gx * step, half - gy * step
end

-- 自作の碁盤: 盤面が変わったときだけ石のオブジェクトを置き直す
local function syncStoneObjects(t, sp)
    local bd = boards[t.id]
    local ver = bd and bd.ver or -1
    if sp.ver == ver then return end
    sp.ver = ver
    local want = {}
    for _, s in ipairs(bd and bd.stones or {}) do want[s[1] .. ',' .. s[2]] = s end
    for key, o in pairs(sp.stoneObjs) do
        local w = want[key]
        if not w or w[3] ~= o[2] then DeleteEntity(o[1]) sp.stoneObjs[key] = nil end
    end
    for key, s in pairs(want) do
        local h = sp.stoneModels and sp.stoneModels[s[3]]
        if h and not sp.stoneObjs[key] then
            local ox, oy = stoneLocal(s[1], s[2])
            local w = toWorld(t, ox, oy, sp.gobanTop - t.coords.z)
            local obj = CreateObject(h, w.x, w.y, w.z, false, false, false)
            SetEntityCoordsNoOffset(obj, w.x, w.y, w.z, false, false, false)
            SetEntityHeading(obj, ((s[1] * 37 + s[2] * 61) % 360) + 0.0)
            FreezeEntityPosition(obj, true)
            SetEntityCollision(obj, false, false)
            sp.stoneObjs[key] = { obj, s[3] }
        end
    end
end

local function drawLabel(t, z)
    local bd = boards[t.id]
    local label = '空席'
    if bd then
        local n1, n2 = bd.names[1], bd.names[2]
        label = (n1 and n2) and (n1 .. '  vs  ' .. n2) or ((n1 or n2) and ((n1 or n2) .. '  vs  募集中') or '空席')
    end
    drawText3D(toWorld(t, 0.0, 0.0, z + 0.6), label)
end

local function drawBoard(t, sp)
    -- 自作の碁盤があれば、石はオブジェクト。最終手の印と名前だけ描く
    if sp.goban then
        syncStoneObjects(t, sp)
        local z = sp.gobanTop - t.coords.z
        local bd = boards[t.id]
        if bd and bd.last then
            local ox, oy = stoneLocal(bd.last[1], bd.last[2])
            local w = toWorld(t, ox, oy, z + 0.022)
            DrawMarker(28, w.x, w.y, w.z, 0,0,0, 0,0,0, 0.007, 0.007, 0.004, 224, 48, 30, 255, false, false, 2, false, nil, nil, false)
        end
        drawLabel(t, z)
        return
    end

    local B = Config.Board
    local S, half = B.size, B.size / 2
    local pad = S * 0.06
    local z = sp.top + B.zOffset - t.coords.z
    local c, lc = B.color, B.lineColor

    -- 盤(両面から見えるよう2回描く)
    local p1 = toWorld(t, -half - pad, -half - pad, z)
    local p2 = toWorld(t,  half + pad, -half - pad, z)
    local p3 = toWorld(t,  half + pad,  half + pad, z)
    local p4 = toWorld(t, -half - pad,  half + pad, z)
    DrawPoly(p1.x,p1.y,p1.z, p2.x,p2.y,p2.z, p3.x,p3.y,p3.z, c[1],c[2],c[3],255)
    DrawPoly(p1.x,p1.y,p1.z, p3.x,p3.y,p3.z, p4.x,p4.y,p4.z, c[1],c[2],c[3],255)
    DrawPoly(p3.x,p3.y,p3.z, p2.x,p2.y,p2.z, p1.x,p1.y,p1.z, c[1],c[2],c[3],255)
    DrawPoly(p4.x,p4.y,p4.z, p3.x,p3.y,p3.z, p1.x,p1.y,p1.z, c[1],c[2],c[3],255)

    -- 罫線
    local step = S / 14
    local lz = z + 0.002
    for i = 0, 14 do
        local o = -half + i * step
        local a, b = toWorld(t, o, -half, lz), toWorld(t, o, half, lz)
        DrawLine(a.x,a.y,a.z, b.x,b.y,b.z, lc[1],lc[2],lc[3],255)
        a, b = toWorld(t, -half, o, lz), toWorld(t, half, o, lz)
        DrawLine(a.x,a.y,a.z, b.x,b.y,b.z, lc[1],lc[2],lc[3],255)
    end

    -- 石
    local bd = boards[t.id]
    if bd then
        local r = B.stoneScale
        for _, s in ipairs(bd.stones) do
            local ox, oy = stoneLocal(s[1], s[2])
            local w = toWorld(t, ox, oy, z + r * 0.5)
            local col = s[3] == 1 and 15 or 240
            DrawMarker(28, w.x, w.y, w.z, 0,0,0, 0,0,0, r, r, r * 0.5, col, col, col, 255, false, false, 2, false, nil, nil, false)
        end
        if bd.last then
            local ox, oy = stoneLocal(bd.last[1], bd.last[2])
            local w = toWorld(t, ox, oy, z + r * 1.2)
            DrawMarker(28, w.x, w.y, w.z, 0,0,0, 0,0,0, r * 0.35, r * 0.35, r * 0.2, 224, 48, 30, 255, false, false, 2, false, nil, nil, false)
        end
    end
    drawLabel(t, z)
end

CreateThread(function()
    while true do
        local wait = 500
        local pos = GetEntityCoords(PlayerPedId())
        for _, t in ipairs(tableList) do
            local d = #(pos - t.coords)
            local sp = spawned[t.id]
            if sp and d < Config.BoardDist then
                wait = 0
                drawBoard(t, sp)
            end
            if not isOpen and not seated and d < Config.DrawDist then
                wait = 0
                local m = toWorld(t, 0.0, -(Config.SeatDistance + 0.8), -0.95)
                DrawMarker(1, m.x, m.y, m.z, 0,0,0, 0,0,0, 0.8,0.8,0.4, 232,198,106, 120, false, false, 2, false)
                if #(pos - vec3(m.x, m.y, pos.z)) < Config.UseDist then
                    local mine = t.owner == myServerId
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ ' .. t.label .. 'を開く' .. (mine and '~n~~INPUT_DETONATE~ 卓を片付ける' or ''))
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustReleased(0, Config.UseKey) then
                        setOpen(true, t.id)
                    elseif mine and IsControlJustReleased(0, Config.Item.PickupKey) then
                        TriggerServerEvent('kani-gomoku:pickup', t.id)
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

RegisterNUICallback('tableInfo', function(data, cb)
    TriggerServerEvent('kani-gomoku:tableInfo', tonumber(data.tableId))
    cb('ok')
end)

-- data = { tableId, mode = 'host'|'accept', bet }
RegisterNUICallback('join', function(data, cb)
    currentTable = tonumber(data.tableId)
    TriggerServerEvent('kani-gomoku:join', { tableId = currentTable, mode = data.mode, bet = tonumber(data.bet) })
    cb('ok')
end)

RegisterNUICallback('leave', function(_, cb)
    leaveTable()
    cb('ok')
end)

RegisterNUICallback('move', function(data, cb)
    TriggerServerEvent('kani-gomoku:move', tonumber(data.x), tonumber(data.y))
    cb('ok')
end)

RegisterNUICallback('next', function(_, cb)
    TriggerServerEvent('kani-gomoku:next')
    cb('ok')
end)

---------------------------------------------------------------- server -> client
RegisterNetEvent('kani-gomoku:state', function(state)
    if state.mySeat and currentTable then
        mySeat = state.mySeat
        sitDown()
    end
    SendNUIMessage({ type = 'state', state = state })
end)

RegisterNetEvent('kani-gomoku:notice', function(text)
    SendNUIMessage({ type = 'notice', text = text })
    if not isOpen then
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName('五目並べ: ' .. text)
        EndTextCommandThefeedPostTicker(false, false)
    end
end)

RegisterNetEvent('kani-gomoku:tableInfo', function(info)
    SendNUIMessage({ type = 'tableInfo', info = info })
end)

RegisterNetEvent('kani-gomoku:joinFailed', function()
    currentTable, mySeat = nil, nil
    SendNUIMessage({ type = 'joinFailed' })
end)

-- サーバー側で卓から外された (相手の退席・所持金不足など)
RegisterNetEvent('kani-gomoku:kicked', function(reason)
    currentTable, mySeat = nil, nil
    standUp()
    SendNUIMessage({ type = 'kicked', text = reason })
    if not isOpen then
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName('五目並べ: ' .. reason)
        EndTextCommandThefeedPostTicker(false, false)
    end
end)

---------------------------------------------------------------- ターゲット(Altの目)で片付け
-- ox_target / qb-target がある場合、置いた卓に「片付ける」を出す。空いている卓だけ (kani-othello と同じ)
local targetZones = {}   -- [tid] = { kind = 'ox'|'qb', id = zoneId or name }

local function targetKind()
    if not Config.Item.UseTarget then return nil end
    if GetResourceState('ox_target') == 'started' then return 'ox' end
    if GetResourceState('qb-target') == 'started' then return 'qb' end
end

local function tableIsEmpty(tid)
    local bd = boards[tid]
    return not bd or (not bd.names[1] and not bd.names[2])
end

local function removeTargetZone(tid)
    local z = targetZones[tid]
    if not z then return end
    targetZones[tid] = nil
    if z.kind == 'ox' then
        pcall(function() exports.ox_target:removeZone(z.id) end)
    else
        pcall(function() exports['qb-target']:RemoveZone(z.id) end)
    end
end

local function addTargetZone(t)
    if targetZones[t.id] then return end
    local kind = targetKind()
    if not kind then return end
    local tid = t.id
    local center = vec3(t.coords.x, t.coords.y, t.coords.z - 1.0 + 0.4)
    local label = t.label .. 'を片付ける'
    local function pick() TriggerServerEvent('kani-gomoku:pickup', tid) end
    local function can() return not isOpen and not seated and tableIsEmpty(tid) end
    if kind == 'ox' then
        local id = exports.ox_target:addSphereZone({
            coords = center, radius = 0.9, debug = false,
            options = { {
                name = 'gomoku_pickup_' .. tid, icon = 'fa-solid fa-hand', label = label,
                distance = 2.0, canInteract = can, onSelect = pick,
            } },
        })
        targetZones[tid] = { kind = 'ox', id = id }
    else
        local name = 'gomoku_pickup_' .. tid
        exports['qb-target']:AddCircleZone(name, center, 0.9, { name = name, useZ = true, debugPoly = false }, {
            options = { { type = 'client', icon = 'fas fa-hand', label = label, canInteract = can, action = pick } },
            distance = 2.0,
        })
        targetZones[tid] = { kind = 'qb', id = name }
    end
end

-- 置いた卓(持ち主あり)だけにゾーンを張る。持ち主以外の判定はサーバー側
local function refreshTargets()
    local keep = {}
    for _, t in ipairs(tableList) do
        if t.owner then keep[t.id] = true addTargetZone(t) end
    end
    for tid in pairs(targetZones) do
        if not keep[tid] then removeTargetZone(tid) end
    end
end

AddEventHandler('onClientResourceStart', function(res)
    if res == 'ox_target' or res == 'qb-target' then
        targetZones = {}
        refreshTargets()
    end
end)

-- 卓の一覧 (常設 + アイテムで置かれた卓)
RegisterNetEvent('kani-gomoku:tables', function(list)
    tableList = list or {}
    refreshTargets()
    -- 着席中の卓が消えたら立つ
    if currentTable and not tableById(currentTable) then
        currentTable, mySeat = nil, nil
        standUp()
    end
end)

-- アイテムを使った: 目の前の地面に卓を置く
RegisterNetEvent('kani-gomoku:placeSet', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsPedSwimming(ped) or IsPedFalling(ped) then
        return TriggerEvent('kani-gomoku:notice', 'ここでは卓を置けません')
    end
    local heading = GetEntityHeading(ped)
    local p = GetOffsetFromEntityInWorldCoords(ped, 0.0, Config.Item.Distance, 0.0)
    local found, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z + 1.0, false)
    if not found or math.abs(gz - (p.z - 1.0)) > 1.0 then
        return TriggerEvent('kani-gomoku:notice', '平らな地面の上で使ってください')
    end
    -- 卓の向き: 席1(手前)が自分の側になるようにする
    TriggerServerEvent('kani-gomoku:place', vector3(p.x, p.y, gz + 1.0), heading + 0.0)
end)

-- 全員に配られる盤面 (見物用)。board は 225文字の '0'/'1'/'2'
RegisterNetEvent('kani-gomoku:board', function(tid, board, names, last)
    local stones = {}
    if board then
        for i = 1, #board do
            local v = board:byte(i) - 48
            if v > 0 then
                local idx = i - 1
                stones[#stones + 1] = { idx % 15, idx // 15, v }
            end
        end
    end
    boardVer = boardVer + 1
    boards[tid] = { stones = stones, names = names or {}, last = last and { last.x, last.y } or nil, ver = boardVer }
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then TriggerServerEvent('kani-gomoku:requestBoards') end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    standUp()
    for tid in pairs(spawned) do despawnTable(tid) end
    for tid in pairs(targetZones) do removeTargetZone(tid) end
end)
