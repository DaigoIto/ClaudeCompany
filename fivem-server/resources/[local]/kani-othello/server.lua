local N = 8
local DIRS = { {1,0}, {-1,0}, {0,1}, {0,-1}, {1,1}, {1,-1}, {-1,1}, {-1,-1} }

local tables = {}      -- [tableId] = state
local seatOf = {}      -- [src] = { tid = , seat = }

for _, t in ipairs(Config.Tables) do
    tables[t.id] = { id = t.id, seats = {}, names = {}, phase = 'waiting' }
end

local function newBoard()
    local b = {}
    for y = 1, N do
        b[y] = {}
        for x = 1, N do b[y][x] = 0 end
    end
    b[4][4], b[5][5] = 1, 1   -- 1=白(先手) 2=黒(後手)
    b[4][5], b[5][4] = 2, 2
    return b
end

local function resetMatch(t)
    t.game = 0
    t.wins = { 0, 0 }
    t.ready = {}
end

-- 1=白(先手) 2=黒(後手)。game が偶数のとき席1が先手、1戦ごとに交代
local function colorOfSeat(t, seat)
    local seat1First = (t.game % 2 == 0)
    if seat == 1 then return seat1First and 1 or 2 end
    return seat1First and 2 or 1
end

local function seatOfColor(t, color)
    return colorOfSeat(t, 1) == color and 1 or 2
end

-- (x,y) に color が置いたとき裏返る石のリスト (1始まり)。置けなければ空
local function flipsAt(board, x, y, color)
    local res = {}
    if board[y][x] ~= 0 then return res end
    for _, d in ipairs(DIRS) do
        local line = {}
        local nx, ny = x + d[1], y + d[2]
        while nx >= 1 and ny >= 1 and nx <= N and ny <= N and board[ny][nx] == 3 - color do
            line[#line + 1] = { nx, ny }
            nx, ny = nx + d[1], ny + d[2]
        end
        if #line > 0 and nx >= 1 and ny >= 1 and nx <= N and ny <= N and board[ny][nx] == color then
            for _, c in ipairs(line) do res[#res + 1] = c end
        end
    end
    return res
end

local function hasMove(board, color)
    for y = 1, N do
        for x = 1, N do
            if board[y][x] == 0 and #flipsAt(board, x, y, color) > 0 then return true end
        end
    end
    return false
end

local function countStones(board)
    local b, w = 0, 0
    for y = 1, N do
        for x = 1, N do
            if board[y][x] == 1 then b = b + 1 elseif board[y][x] == 2 then w = w + 1 end
        end
    end
    return b, w
end

local function startRound(t)
    t.board = newBoard()
    t.turn, t.moves, t.last, t.result, t.passed = 1, 0, nil, nil, nil
    t.phase = 'playing'
    t.ready = {}
end

local function publicState(t, seat)
    return {
        phase = t.phase,
        mySeat = seat,
        myColor = t.board and colorOfSeat(t, seat) or nil,
        turn = t.turn,
        board = t.board,
        last = t.last,
        passed = t.passed,
        moves = t.moves,
        game = (t.game or 0) + 1,
        myWins = t.wins and t.wins[seat],
        oppWins = t.wins and t.wins[3 - seat],
        oppName = t.names[3 - seat] or '相手',
        bet = t.bet or 0,
        result = t.result,
    }
end

-- 見物用: 卓の盤面と対局者名を全員へ (64文字の '0'/'1'/'2')
local function encodeBoard(board)
    if not board then return nil end
    local parts = {}
    for y = 1, N do
        for x = 1, N do parts[#parts + 1] = tostring(board[y][x]) end
    end
    return table.concat(parts)
end

local function syncBoard(t, target)
    TriggerClientEvent('kani-othello:board', target or -1, t.id, encodeBoard(t.board), { t.names[1] or false, t.names[2] or false }, t.last, t.bet)
end

local function sendMoney(src)
    if src then TriggerClientEvent('kani-othello:money', src, Money.get(src)) end
end

local function broadcast(t)
    syncBoard(t)
    for seat = 1, 2 do
        local src = t.seats[seat]
        if src then TriggerClientEvent('kani-othello:state', src, publicState(t, seat)) end
    end
end

local function finishRound(t)
    local b, w = countStones(t.board)
    -- b = 白(先手)の数, w = 黒(後手)の数
    local res = { winnerSeat = 0, black = w, white = b }
    if b ~= w then
        local wseat = seatOfColor(t, b > w and 1 or 2)
        res.winnerSeat = wseat
        t.wins[wseat] = t.wins[wseat] + 1
    else
        res.draw = true
    end

    -- 賭け金の精算
    local bet = t.bet or 0
    res.bet = bet
    if bet > 0 and (t.pot or 0) > 0 then
        if res.draw then
            for seat = 1, 2 do
                if t.seats[seat] then Money.add(t.seats[seat], bet, 'othello draw refund') end
            end
        else
            local rake = math.floor(t.pot * (Config.Rake or 0) / 100)
            res.payout, res.rake = t.pot - rake, rake
            Money.add(t.seats[res.winnerSeat], res.payout, 'othello win')
        end
        t.pot = 0
        for seat = 1, 2 do sendMoney(t.seats[seat]) end
    end

    t.result = res
    t.phase = 'result'
end

-- src が退席(切断)したら、相手も卓から外してメニューへ戻す。otherText: 相手に出す理由(省略可)
local function removePlayer(src, otherText)
    local info = seatOf[src]
    if not info then return end
    local t = tables[info.tid]
    seatOf[src] = nil
    if not t then return end
    local other = t.seats[3 - info.seat]

    -- 対局中の退席・切断は引き分け扱い: 預かっている賭け金は両者へ全額返金 (没収なし)
    local text = otherText or '相手が退席したため、卓を終了しました'
    if t.phase == 'playing' and (t.pot or 0) > 0 and other then
        local bet = t.bet or 0
        Money.add(other, bet, 'othello leave refund')
        Money.add(src, bet, 'othello leave refund')     -- 切断時は失敗することがある(フレームワーク側の仕様)
        sendMoney(src)
        text = ('相手が退席したため引き分けとなり、賭け金 %s%d は返金されました。卓を終了しました'):format(Config.Currency, bet)
    end

    -- 卓を空にする (相手も退席扱い)
    t.seats, t.names = {}, {}
    t.pot, t.bet = 0, nil
    t.phase, t.board, t.result, t.last, t.passed = 'waiting', nil, nil, nil, nil
    if other then
        seatOf[other] = nil
        TriggerClientEvent('kani-othello:kicked', other, text, t.id, nil)
        sendMoney(other)
    end
    syncBoard(t)
end

-- 預かり金を出せない人を卓から外す
local function kick(t, seat, text)
    local src = t.seats[seat]
    if not src then return end
    TriggerClientEvent('kani-othello:kicked', src, text, t.id, t.bet)
    removePlayer(src, '相手の所持金が足りないため、卓を終了しました')
end

-- 対局開始前に両者から賭け金を預かる。失敗したら false (足りない人は卓から外れる)
local function escrow(t)
    local bet = t.bet or 0
    t.pot = 0
    if bet <= 0 then return true end
    local ok = {}
    for seat = 1, 2 do ok[seat] = Money.remove(t.seats[seat], bet, 'othello bet') end
    if ok[1] and ok[2] then
        t.pot = bet * 2
        for seat = 1, 2 do sendMoney(t.seats[seat]) end
        return true
    end
    for seat = 1, 2 do
        if ok[seat] then Money.add(t.seats[seat], bet, 'othello refund') end
    end
    for seat = 1, 2 do
        if not ok[seat] then kick(t, seat, '所持金が足りないため卓から外れました') end
    end
    return false
end

RegisterNetEvent('kani-othello:requestBoards', function()
    local src = source
    for _, t in pairs(tables) do syncBoard(t, src) end
    TriggerEvent('kani-othello:internalSendPlaced', src)
end)

RegisterNetEvent('kani-othello:getMoney', function()
    sendMoney(source)
end)

local function validBet(bet)
    return type(bet) == 'number' and bet == bet and bet >= 0 and bet <= Config.MaxBet and bet == math.floor(bet)
end

RegisterNetEvent('kani-othello:join', function(tid, bet)
    local src = source
    local t = tables[tid]
    if not t or seatOf[src] then return end
    local seat = (not t.seats[1]) and 1 or ((not t.seats[2]) and 2 or nil)
    if not seat then
        TriggerClientEvent('kani-othello:kicked', src, 'この卓は満席です', tid, t.bet)
        return
    end

    -- 卓が空なら着席者が賭け金を決める。誰かいればその卓の賭け金に従う
    local empty = not t.seats[1] and not t.seats[2]
    local need
    if empty then
        bet = tonumber(bet)
        if not bet or not validBet(bet) then
            TriggerClientEvent('kani-othello:kicked', src, '賭け金が不正です', tid, nil)
            return
        end
        bet = math.floor(bet)
        need = bet
    else
        -- 2人目: 画面で承諾した賭け金が、今の卓の賭け金と一致しなければ着席させない
        need = t.bet or 0
        if tonumber(bet) ~= need then
            TriggerClientEvent('kani-othello:kicked', src, '賭け金が変更されています。内容を確認してください', tid, t.bet)
            return
        end
    end
    if Money.get(src) < need then
        TriggerClientEvent('kani-othello:kicked', src, '所持金が足りません', tid, (not empty) and t.bet or nil)
        sendMoney(src)
        return
    end
    if empty then t.bet = need end

    t.seats[seat] = src
    t.names[seat] = GetPlayerName(src) or ('Player ' .. src)
    seatOf[src] = { tid = tid, seat = seat }
    if t.seats[1] and t.seats[2] then
        resetMatch(t)
        if not escrow(t) then return end    -- 失敗時は kick 側で同期済み
        startRound(t)
    else
        t.phase = 'waiting'
    end
    broadcast(t)
    sendMoney(src)
end)

RegisterNetEvent('kani-othello:leave', function()
    removePlayer(source)
end)

AddEventHandler('playerDropped', function()
    removePlayer(source)
end)

RegisterNetEvent('kani-othello:move', function(x, y)
    local src = source
    local info = seatOf[src]
    if not info or type(x) ~= 'number' or type(y) ~= 'number' then return end
    local t = tables[info.tid]
    if not t or t.phase ~= 'playing' then return end
    x, y = math.floor(x) + 1, math.floor(y) + 1   -- 0始まり -> 1始まり
    if x < 1 or y < 1 or x > N or y > N then return end
    local color = colorOfSeat(t, info.seat)
    if t.turn ~= color then return end
    local flips = flipsAt(t.board, x, y, color)
    if #flips == 0 then return end

    t.board[y][x] = color
    for _, c in ipairs(flips) do t.board[c[2]][c[1]] = color end
    t.moves = t.moves + 1
    t.last = { x = x - 1, y = y - 1 }
    t.passed = nil

    local opp = 3 - color
    if hasMove(t.board, opp) then
        t.turn = opp
    elseif hasMove(t.board, color) then
        t.turn = color
        t.passed = opp      -- opp 側がパス
    else
        finishRound(t)
    end
    broadcast(t)
end)

-- 結果画面から「もう一度」: 両者が押したら次の対局開始(先手後手交代)
RegisterNetEvent('kani-othello:next', function()
    local src = source
    local info = seatOf[src]
    if not info then return end
    local t = tables[info.tid]
    if not t or t.phase ~= 'result' then return end
    t.ready[info.seat] = true
    if t.ready[1] and t.ready[2] then
        t.game = t.game + 1
        if not escrow(t) then return end    -- 失敗時は kick 側で同期済み
        startRound(t)
        broadcast(t)
    end
end)

-- ---------------------------------------------------------------- スタンドアロン財布用コマンド
-- /othellowallet : 自分の所持金 (スタンドアロン時のみ)
RegisterCommand('othellowallet', function(src)
    if src == 0 then return end
    local msg = Money.framework() == 'standalone'
        and ('所持金: %s%d'):format(Config.Currency, Money.get(src))
        or 'このコマンドはスタンドアロン財布のときだけ使えます'
    TriggerClientEvent('chat:addMessage', src, { args = { 'オセロ', msg } })
end, false)

-- othellogive <プレイヤーID> <金額> : 管理者(ace: command.othellogive)/サーバーコンソール用
RegisterCommand('othellogive', function(src, args)
    local target, amount = tonumber(args[1]), tonumber(args[2])
    local function reply(m)
        if src == 0 then print(m) else TriggerClientEvent('chat:addMessage', src, { args = { 'オセロ', m } }) end
    end
    if Money.framework() ~= 'standalone' then return reply('スタンドアロン財布のときだけ使えます') end
    if not target or not amount or not GetPlayerName(target) then return reply('使い方: othellogive <プレイヤーID> <金額>') end
    Money.add(target, amount, 'othellogive')
    reply(('%s に %s%d 付与 (現在 %s%d)'):format(GetPlayerName(target), Config.Currency, amount, Config.Currency, Money.get(target)))
    sendMoney(target)
end, true)

-- リソース停止時: 対局中の預かり金は両者へ返金
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, t in pairs(tables) do
        if (t.pot or 0) > 0 then
            for seat = 1, 2 do
                if t.seats[seat] then Money.add(t.seats[seat], t.bet or 0, 'othello stop refund') end
            end
            t.pot = 0
        end
    end
end)

-- ---------------------------------------------------------------- アイテムで置ける卓
local placed = {}              -- [id] = { id, x, y, z, h, owner, free }
local nextPlacedId = 1000

local function licenseOf(src)
    return GetPlayerIdentifierByType(src, 'license') or ('src:' .. src)
end

local function toast(src, text)
    TriggerClientEvent('kani-othello:toast', src, text)
end

local function placedList()
    local l = {}
    for _, p in pairs(placed) do l[#l + 1] = { id = p.id, x = p.x, y = p.y, z = p.z, h = p.h } end
    table.sort(l, function(a, b) return a.id < b.id end)
    return l
end

local function sendPlaced(target)
    TriggerClientEvent('kani-othello:placed', target or -1, placedList())
end

AddEventHandler('kani-othello:internalSendPlaced', function(src) sendPlaced(src) end)

local function savePlaced()
    if not Config.Placeable.Persist then return end
    local arr = {}
    for _, p in pairs(placed) do arr[#arr + 1] = p end
    SetResourceKvp('placed_tables', json.encode(arr))
end

local function addPlacedTable(p)
    placed[p.id] = p
    tables[p.id] = { id = p.id, seats = {}, names = {}, phase = 'waiting' }
    if p.id >= nextPlacedId then nextPlacedId = p.id + 1 end
end

-- 起動時: 保存済みの卓を復元
do
    local raw = Config.Placeable.Persist and GetResourceKvpString('placed_tables') or nil
    local arr = raw and json.decode(raw) or nil
    if arr then
        for _, p in ipairs(arr) do addPlacedTable(p) end
    end
end

local lastUse = {}
-- consume=true: アイテムを1個消費して置く。false: 管理者コマンド(消費なし)
local function placeTableFor(src, consume)
    local P = Config.Placeable
    local now = GetGameTimer()
    if lastUse[src] and now - lastUse[src] < 1500 then return false end   -- 二重発火の防止
    lastUse[src] = now

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pc, h = GetEntityCoords(ped), GetEntityHeading(ped)
    local r = math.rad(h)
    local x, y = pc.x - math.sin(r) * P.Distance, pc.y + math.cos(r) * P.Distance

    local owner = licenseOf(src)
    local count, total = 0, 0
    for _, p in pairs(placed) do
        total = total + 1
        if p.owner == owner then count = count + 1 end
    end
    if total >= P.MaxTotal then toast(src, 'これ以上は卓を置けません') return false end
    if count >= P.MaxPerPlayer then
        toast(src, ('卓は1人%d台まで置けます。先に片付けてください'):format(P.MaxPerPlayer))
        return false
    end
    local function tooClose(cx, cy)
        local dx, dy = x - cx, y - cy
        return (dx * dx + dy * dy) < P.MinSpacing * P.MinSpacing
    end
    for _, t in ipairs(Config.Tables) do
        if tooClose(t.coords.x, t.coords.y) then toast(src, '他の卓に近すぎます') return false end
    end
    for _, p in pairs(placed) do
        if tooClose(p.x, p.y) then toast(src, '他の卓に近すぎます') return false end
    end

    if consume and not Inv.remove(src) then
        toast(src, '卓を置けませんでした(アイテムを使用できません)')
        return false
    end

    local p = { id = nextPlacedId, x = x, y = y, z = pc.z, h = h, owner = owner, free = not consume or nil }
    addPlacedTable(p)
    savePlaced()
    sendPlaced()
    syncBoard(tables[p.id])
    toast(src, '卓を置きました。片付けるときは卓の横で G キー')
    return true
end

RegisterNetEvent('kani-othello:pickupTable', function(tid)
    local src = source
    local p, t = placed[tid], tables[tid]
    if not p or not t then return end
    if t.seats[1] or t.seats[2] then toast(src, '使用中の卓は片付けられません') return end
    if Config.Placeable.OnlyOwnerPickup and p.owner ~= licenseOf(src)
        and not IsPlayerAceAllowed(src, 'command.othellopickup') then
        toast(src, '他の人の卓は片付けられません')
        return
    end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - vec3(p.x, p.y, p.z)) > 4.0 then return end
    if not p.free and Inv.available() then
        if not Inv.add(src) then toast(src, '持ち物がいっぱいで片付けられません') return end
    end
    placed[tid], tables[tid] = nil, nil
    savePlaced()
    sendPlaced()
    toast(src, p.free and '卓を片付けました' or '卓を片付けました(アイテムに戻りました)')
end)

-- 使えるアイテムとして登録 (フレームワークの起動順を待つ)
CreateThread(function()
    Wait(1500)
    local item, fw = Config.Placeable.Item, Money.framework()
    local function use(source) placeTableFor(source, true) end
    if fw == 'qbx' then
        exports.qbx_core:CreateUseableItem(item, use)
    elseif fw == 'qb' then
        exports['qb-core']:GetCoreObject().Functions.CreateUseableItem(item, use)
    elseif fw == 'esx' then
        exports['es_extended']:getSharedObject().RegisterUsableItem(item, use)
    end
end)

-- ox_inventory の item 定義で server = { export = 'kani-othello.othello_table' } を使う場合(フレームワーク無しの ox 用)
exports('othello_table', function(event, item, inventory)
    if event == 'usingItem' and inventory and inventory.id then
        placeTableFor(inventory.id, true)
        return false
    end
end)

-- 管理者コマンド: アイテム無しで卓を置く(ace: command.othelloplace)。サーバーコンソールからは使えない
RegisterCommand('othelloplace', function(src)
    if src == 0 then print('ゲーム内から実行してください') return end
    placeTableFor(src, false)
end, true)
