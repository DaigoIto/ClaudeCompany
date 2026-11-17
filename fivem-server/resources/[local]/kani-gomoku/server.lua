local N = 15
local DIRS = { {1,0}, {0,1}, {1,1}, {1,-1} }

local tables = {}      -- [tableId] = state
local seatOf = {}      -- [src] = { tid = , seat = }

local function resetTable(t)
    t.seats, t.names = {}, {}
    t.phase, t.board, t.result, t.winLine, t.last = 'empty', nil, nil, nil, nil
    t.wins, t.gameNo, t.ready = { 0, 0 }, 0, {}
    t.bet, t.escrow = 0, {}
end

for _, tc in ipairs(Config.Tables) do
    local t = { id = tc.id }
    resetTable(t)
    tables[tc.id] = t
end

local function fmt(n)
    local s = tostring(math.floor(n)):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return Config.Currency .. s
end

local function notice(src, text) TriggerClientEvent('kani-gomoku:notice', src, text) end

local function newBoard()
    local b = {}
    for y = 1, N do
        b[y] = {}
        for x = 1, N do b[y][x] = 0 end
    end
    return b
end

-- 1局ごとに先手(黒)を交代: gameNo が偶数なら席1が黒
local function colorOfSeat(t, seat)
    local seat1Black = (t.gameNo % 2 == 0)
    if seat == 1 then return seat1Black and 1 or 2 end
    return seat1Black and 2 or 1
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
        winLine  = t.winLine,
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

-- 見物用: 卓の盤面と対局者名を全員へ (225文字の '0'/'1'/'2')
local function encodeBoard(board)
    if not board then return nil end
    local parts = {}
    for y = 1, N do
        for x = 1, N do parts[#parts + 1] = tostring(board[y][x]) end
    end
    return table.concat(parts)
end

local function syncBoard(t, target)
    TriggerClientEvent('kani-gomoku:board', target or -1, t.id, encodeBoard(t.board), { t.names[1] or false, t.names[2] or false }, t.last)
end

local function broadcast(t)
    syncBoard(t)
    for seat = 1, 2 do
        local src = t.seats[seat]
        if src then TriggerClientEvent('kani-gomoku:state', src, publicState(t, seat)) end
    end
end

---------------------------------------------------------------- 賭け金
-- 両者から預かる。どちらかが払えなければ払えた側に返して false
local function collectBets(t)
    if t.bet <= 0 then t.escrow = {} return true end
    t.escrow = {}
    for seat = 1, 2 do
        if Money.remove(t.seats[seat], t.bet, 'kani-gomoku: 賭け金') then
            t.escrow[seat] = t.bet
        else
            for s, amt in pairs(t.escrow) do Money.add(t.seats[s], amt, 'kani-gomoku: 返金') end
            t.escrow = {}
            return false, seat
        end
    end
    return true
end

local function refundAll(t)
    for seat, amt in pairs(t.escrow) do
        if t.seats[seat] then Money.add(t.seats[seat], amt, 'kani-gomoku: 返金') end
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
    if pay > 0 then Money.add(t.seats[seat], pay, 'kani-gomoku: 勝利') end
    return pay, rake
end

---------------------------------------------------------------- 卓から外す
local function kick(src, reason)
    seatOf[src] = nil
    TriggerClientEvent('kani-gomoku:kicked', src, reason)
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
    t.turn, t.moves, t.last, t.winLine, t.result = 1, 0, nil, nil, nil
    t.phase = 'playing'
    t.ready = {}
    return true
end

local function winLinesAt(board, x, y, p)
    local res = {}
    for _, d in ipairs(DIRS) do
        local line = { { x - 1, y - 1 } }  -- クライアントへは0始まりで返す
        for _, s in ipairs({ 1, -1 }) do
            local i = 1
            while true do
                local nx, ny = x + d[1] * i * s, y + d[2] * i * s
                if nx < 1 or ny < 1 or nx > N or ny > N or board[ny][nx] ~= p then break end
                line[#line + 1] = { nx - 1, ny - 1 }
                i = i + 1
            end
        end
        if #line >= 5 then res[#res + 1] = line end
    end
    return res
end

local function finishGame(t, winnerSeat, lines)
    local res = { winnerSeat = winnerSeat, bet = t.bet }
    if winnerSeat > 0 then
        t.wins[winnerSeat] = t.wins[winnerSeat] + 1
        res.payout, res.rake = payWinner(t, winnerSeat)
    else
        res.draw = true
        refundAll(t)
    end
    t.result = res
    t.phase = 'result'
    t.winLine = lines
end

---------------------------------------------------------------- イベント
-- 卓の様子 (着席前の確認用)
RegisterNetEvent('kani-gomoku:tableInfo', function(tid)
    local src = source
    local t = tables[tid]
    if not t then return end
    local count = (t.seats[1] and 1 or 0) + (t.seats[2] and 1 or 0)
    TriggerClientEvent('kani-gomoku:tableInfo', src, {
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
RegisterNetEvent('kani-gomoku:join', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    local tid, bet = tonumber(data.tableId), tonumber(data.bet)
    local t = tables[tid]
    if not t or seatOf[src] or not bet then return end
    bet = math.floor(bet)
    local count = (t.seats[1] and 1 or 0) + (t.seats[2] and 1 or 0)

    local function reject(msg)
        notice(src, msg)
        TriggerClientEvent('kani-gomoku:joinFailed', src)
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

RegisterNetEvent('kani-gomoku:leave', function()
    removePlayer(source, 'leave')
end)

AddEventHandler('playerDropped', function()
    removePlayer(source, 'drop')
end)

RegisterNetEvent('kani-gomoku:move', function(x, y)
    local src = source
    local info = seatOf[src]
    if not info or type(x) ~= 'number' or type(y) ~= 'number' then return end
    local t = tables[info.tid]
    if not t or t.phase ~= 'playing' then return end
    x, y = math.floor(x) + 1, math.floor(y) + 1   -- 0始まり -> 1始まり
    if x < 1 or y < 1 or x > N or y > N then return end
    local color = colorOfSeat(t, info.seat)
    if t.turn ~= color or t.board[y][x] ~= 0 then return end

    t.board[y][x] = color
    t.moves = t.moves + 1
    t.last = { x = x - 1, y = y - 1 }
    local lines = winLinesAt(t.board, x, y, color)
    if #lines > 0 then
        finishGame(t, info.seat, lines)
    elseif t.moves >= N * N then
        finishGame(t, 0, {})
    else
        t.turn = 3 - color
    end
    broadcast(t)
end)

-- 結果画面の「再戦」: 両者が押したら賭け金を預かり、先手を交代して次の対局
RegisterNetEvent('kani-gomoku:next', function()
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

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, t in pairs(tables) do
        if t.phase == 'playing' then refundAll(t) end
    end
end)
