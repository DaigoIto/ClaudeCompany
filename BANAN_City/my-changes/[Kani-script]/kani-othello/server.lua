local N = 8
local DIRS = { {1,0}, {-1,0}, {0,1}, {0,-1}, {1,1}, {1,-1}, {-1,1}, {-1,-1} }

local tables = {}      -- [tableId] = state
local seatOf = {}      -- [src] = { tid = , seat = }

local function resetTable(t)
    t.seats, t.names = {}, {}
    t.phase, t.board, t.result, t.passed, t.last = 'empty', nil, nil, nil, nil
    t.wins, t.gameNo, t.ready = { 0, 0 }, 0, {}
    t.bet, t.escrow = 0, {}
end

local function newTable(id, label, coords, heading, owner)
    local t = { id = id, label = label, coords = coords, heading = heading or 0.0, owner = owner }
    resetTable(t)
    tables[id] = t
    return t
end

for _, tc in ipairs(Config.Tables) do newTable(tc.id, tc.label, tc.coords, tc.heading) end

-- クライアントへ配る卓の一覧
local function tableList()
    local list = {}
    for _, t in pairs(tables) do
        list[#list + 1] = { id = t.id, label = t.label, coords = t.coords, heading = t.heading, owner = t.owner or false }
    end
    return list
end

local function syncTables(target)
    TriggerClientEvent('kani-othello:tables', target or -1, tableList())
end

local function fmt(n)
    local s = tostring(math.floor(n)):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return Config.Currency .. s
end

local function notice(src, text) TriggerClientEvent('kani-othello:notice', src, text) end

-- 石の番号: 1 = 白(先手), 2 = 黒(後手)
local function newBoard()
    local b = {}
    for y = 1, N do
        b[y] = {}
        for x = 1, N do b[y][x] = 0 end
    end
    b[4][4], b[5][5] = 1, 1
    b[4][5], b[5][4] = 2, 2
    return b
end

-- 1局ごとに先手(白)を交代: gameNo が偶数なら席1が白(先手)
local function colorOfSeat(t, seat)
    local seat1First = (t.gameNo % 2 == 0)
    if seat == 1 then return seat1First and 1 or 2 end
    return seat1First and 2 or 1
end

local function publicState(t, seat)
    local src = t.seats[seat]
    return {
        phase    = t.phase,
        mySeat   = seat,
        myColor  = t.board and colorOfSeat(t, seat) or nil,
        turn     = t.turn,
        board    = t.board,
        last     = t.last,
        passed   = t.passed,
        moves    = t.moves,
        gameNo   = t.gameNo,
        myWins   = t.wins[seat],
        oppWins  = t.wins[3 - seat],
        oppName  = t.names[3 - seat] or '相手',
        result   = t.result,
        bet      = t.bet,
        balance  = src and Money.balance(src) or 0,
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
    TriggerClientEvent('kani-othello:board', target or -1, t.id, encodeBoard(t.board), { t.names[1] or false, t.names[2] or false }, t.last)
end

local function broadcast(t)
    syncBoard(t)
    for seat = 1, 2 do
        local src = t.seats[seat]
        if src then TriggerClientEvent('kani-othello:state', src, publicState(t, seat)) end
    end
end

---------------------------------------------------------------- 賭け金
-- 両者から預かる。どちらかが払えなければ払えた側に返して false
local function collectBets(t)
    if t.bet <= 0 then t.escrow = {} return true end
    t.escrow = {}
    for seat = 1, 2 do
        if Money.remove(t.seats[seat], t.bet, 'kani-othello: 賭け金') then
            t.escrow[seat] = t.bet
        else
            for s, amt in pairs(t.escrow) do Money.add(t.seats[s], amt, 'kani-othello: 返金') end
            t.escrow = {}
            return false, seat
        end
    end
    return true
end

local function refundAll(t)
    for seat, amt in pairs(t.escrow) do
        if t.seats[seat] then Money.add(t.seats[seat], amt, 'kani-othello: 返金') end
    end
    t.escrow = {}
end

-- 勝者に預かり金を全額(手数料を引いて)渡す。受取額と手数料を返す
local function payWinner(t, seat)
    local pot = 0
    for _, amt in pairs(t.escrow) do pot = pot + amt end
    t.escrow = {}
    local rake = math.floor(pot * (Config.Rake or 0) / 100)
    local pay = pot - rake
    if pay > 0 then Money.add(t.seats[seat], pay, 'kani-othello: 勝利') end
    return pay, rake
end

---------------------------------------------------------------- 卓から外す
local function kick(src, reason)
    seatOf[src] = nil
    TriggerClientEvent('kani-othello:kicked', src, reason)
end

-- 1人でも抜けたら卓を解散 (対局中なら引き分け扱いで全額返金)
local function dissolve(t, leaverSeat, reasonForOther)
    if t.phase == 'playing' then refundAll(t) end
    t.escrow = {}
    for seat = 1, 2 do
        local src = t.seats[seat]
        if src then
            if seat == leaverSeat then
                seatOf[src] = nil
            else
                kick(src, reasonForOther)
            end
        end
    end
    resetTable(t)
    syncBoard(t)
end

local function removePlayer(src, why)
    local info = seatOf[src]
    if not info then return end
    local t = tables[info.tid]
    if not t then seatOf[src] = nil return end
    local wasPlaying = t.phase == 'playing'
    local msg
    if wasPlaying then
        msg = (why == 'drop' and '相手が切断しました。' or '相手が退席しました。') .. '引き分け扱いで賭け金は全額返金されました'
    else
        msg = why == 'drop' and '相手が切断したため、卓を離れました' or '相手が退席したため、卓を離れました'
    end
    dissolve(t, info.seat, msg)
    if wasPlaying and why ~= 'drop' then notice(src, '引き分け扱いで賭け金は全額返金されました') end
end

---------------------------------------------------------------- 対局
local function startGame(t)
    local ok, badSeat = collectBets(t)
    if not ok then
        local bad, other = t.seats[badSeat], t.seats[3 - badSeat]
        if bad then kick(bad, '所持金が足りないため、卓を離れました') end
        if other then kick(other, '相手の所持金が足りないため、卓を離れました') end
        resetTable(t)
        syncBoard(t)
        return false
    end
    t.board = newBoard()
    t.turn, t.moves, t.last, t.passed, t.result = 1, 0, nil, nil, nil
    t.phase = 'playing'
    t.ready = {}
    return true
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
    local w, b = 0, 0   -- 白(1), 黒(2)
    for y = 1, N do
        for x = 1, N do
            if board[y][x] == 1 then w = w + 1 elseif board[y][x] == 2 then b = b + 1 end
        end
    end
    return w, b
end

-- 終局: 石の多い方が勝ち。同数は引き分け
local function finishGame(t)
    local w, b = countStones(t.board)
    local res = { bet = t.bet, white = w, black = b, winnerSeat = 0 }
    if w ~= b then
        local winnerSeat
        for seat = 1, 2 do
            if colorOfSeat(t, seat) == (w > b and 1 or 2) then winnerSeat = seat end
        end
        res.winnerSeat = winnerSeat
        t.wins[winnerSeat] = t.wins[winnerSeat] + 1
        res.payout, res.rake = payWinner(t, winnerSeat)
    else
        res.draw = true
        refundAll(t)
    end
    t.result = res
    t.phase = 'result'
end

---------------------------------------------------------------- イベント
-- 卓の様子 (着席前の確認用)
RegisterNetEvent('kani-othello:tableInfo', function(tid)
    local src = source
    local t = tables[tid]
    if not t then return end
    local count = (t.seats[1] and 1 or 0) + (t.seats[2] and 1 or 0)
    TriggerClientEvent('kani-othello:tableInfo', src, {
        tableId  = tid,
        status   = count == 0 and 'empty' or (count == 1 and 'host' or 'full'),
        hostName = t.names[1] or t.names[2],
        bet      = t.bet,
        balance  = Money.balance(src),
        maxBet   = Config.MaxBet,
        bets     = Config.Bets,
        rake     = Config.Rake,
        currency = Config.Currency,
    })
end)

-- data = { tableId, mode = 'host'|'accept', bet }
RegisterNetEvent('kani-othello:join', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    local tid, bet = tonumber(data.tableId), tonumber(data.bet)
    local t = tables[tid]
    if not t or seatOf[src] or not bet then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - t.coords) > 6.0 then return end
    bet = math.floor(bet)
    local count = (t.seats[1] and 1 or 0) + (t.seats[2] and 1 or 0)

    local function reject(msg)
        notice(src, msg)
        TriggerClientEvent('kani-othello:joinFailed', src)
    end

    if data.mode == 'host' then
        if count ~= 0 then return reject('先に座った人がいます。金額を確認してください') end
        if bet < 0 or bet > Config.MaxBet then return reject('賭け金は 0〜' .. fmt(Config.MaxBet) .. ' で入力してください') end
        if Money.balance(src) < bet then return reject('所持金が足りません') end
        t.bet = bet
        t.seats[1], t.names[1] = src, GetPlayerName(src) or ('Player ' .. src)
        seatOf[src] = { tid = tid, seat = 1 }
        t.phase = 'waiting'
        broadcast(t)
    elseif data.mode == 'accept' then
        if count ~= 1 then return reject(count == 0 and '卓に誰もいません' or 'この卓は満席です') end
        if bet ~= t.bet then return reject('賭け金が変わっています。もう一度確認してください') end
        if Money.balance(src) < t.bet then return reject('所持金が足りません') end
        local seat = t.seats[1] and 2 or 1
        t.seats[seat], t.names[seat] = src, GetPlayerName(src) or ('Player ' .. src)
        seatOf[src] = { tid = tid, seat = seat }
        t.wins, t.gameNo = { 0, 0 }, 0
        if startGame(t) then broadcast(t) end
    end
end)

RegisterNetEvent('kani-othello:leave', function()
    removePlayer(source, 'leave')
end)

local function removeTable(t, reasonForSeated)
    dissolve(t, nil, reasonForSeated)
    tables[t.id] = nil
    syncTables()
end

AddEventHandler('playerDropped', function()
    local src = source
    removePlayer(src, 'drop')
    for _, t in pairs(tables) do
        if t.owner == src then removeTable(t, '卓の持ち主が抜けたため、卓が片付けられました') end
    end
end)

-- キャラクターのログアウト(切断せず別キャラ選択へ戻る場合)。フレームワークのイベントに依存
local function onLogout(src)
    if not src then return end
    removePlayer(src, 'drop')
    for _, t in pairs(tables) do
        if t.owner == src then removeTable(t, '卓の持ち主がログアウトしたため、卓が片付けられました') end
    end
end
AddEventHandler('QBCore:Server:OnPlayerUnload', onLogout)   -- QBCore / Qbox(互換イベント)
AddEventHandler('esx:playerLogout', onLogout)               -- ESX

---------------------------------------------------------------- アイテムで置く卓
local nextId = 1000

local function ownedTable(src)
    for _, t in pairs(tables) do if t.owner == src then return t end end
end

-- アイテムを使った: 置く位置はクライアントで決めてもらう
Item.onUse(function(src)
    if ownedTable(src) then return notice(src, 'もう卓を置いています。先に片付けてください') end
    TriggerClientEvent('kani-othello:placeSet', src)
end)

RegisterNetEvent('kani-othello:place', function(coords, heading)
    local src = source
    if type(coords) ~= 'vector3' or type(heading) ~= 'number' then return end
    if not Item.has(src) then return notice(src, 'オセロ卓を持っていません') end
    if ownedTable(src) then return notice(src, 'もう卓を置いています。先に片付けてください') end
    local count = 0
    for _, t in pairs(tables) do
        if t.owner then count = count + 1 end
        if #(t.coords - coords) < Config.Item.MinGap then return notice(src, '近くに別の卓があります') end
    end
    if count >= Config.Item.MaxPlaced then return notice(src, 'これ以上卓を置けません') end
    if #(GetEntityCoords(GetPlayerPed(src)) - coords) > Config.Item.Distance + 2.0 then return end
    nextId = nextId + 1
    local t = newTable(nextId, Config.Item.Label, coords, heading, src)
    syncTables()
    syncBoard(t)
    notice(src, '卓を置きました。片付けるときは卓の前で G')
end)

RegisterNetEvent('kani-othello:pickup', function(tid)
    local src = source
    local t = tables[tonumber(tid)]
    if not t or not t.owner then return end
    if Config.Item.OnlyOwnerPickup and t.owner ~= src and not IsPlayerAceAllowed(src, 'command.othellopickup') then
        return notice(src, '他の人の卓は片付けられません')
    end
    if #(GetEntityCoords(GetPlayerPed(src)) - t.coords) > 4.0 then return end
    if t.seats[1] or t.seats[2] then return notice(src, '人が座っている間は片付けられません') end
    tables[t.id] = nil
    syncTables()
    notice(src, '卓を片付けました')
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
        t.passed = opp          -- 相手は置ける所が無くパス
    else
        finishGame(t)
    end
    broadcast(t)
end)

-- 結果画面の「再戦」: 両者が押したら賭け金を預かり、先手を交代して次の対局
RegisterNetEvent('kani-othello:next', function()
    local src = source
    local info = seatOf[src]
    if not info then return end
    local t = tables[info.tid]
    if not t or t.phase ~= 'result' then return end
    t.ready[info.seat] = true
    if t.ready[1] and t.ready[2] then
        t.gameNo = t.gameNo + 1
        if startGame(t) then broadcast(t) end
    else
        local other = t.seats[3 - info.seat]
        if other then notice(other, (t.names[info.seat] or '相手') .. ' が再戦を希望しています') end
    end
end)

-- クライアント起動時: 卓の一覧と盤面を送る
RegisterNetEvent('kani-othello:requestBoards', function()
    local src = source
    syncTables(src)
    for _, t in pairs(tables) do syncBoard(t, src) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, t in pairs(tables) do
        if t.phase == 'playing' then refundAll(t) end
    end
end)
