-- お金の出し入れ。Qbox / QBCore / ESX を自動検出し、どれも無ければ内蔵の財布(KVP保存)を使う
Money = {}

local fw, core

local function started(res) return GetResourceState(res) == 'started' end

local function detect()
    local want = (Config.Money.Framework or 'auto'):lower()
    if (want == 'auto' or want == 'qbox') and started('qbx_core') then
        fw = 'qbox'
    elseif (want == 'auto' or want == 'qbcore') and started('qb-core') then
        fw = 'qbcore'
        core = exports['qb-core']:GetCoreObject()
    elseif (want == 'auto' or want == 'esx') and started('es_extended') then
        fw = 'esx'
        core = exports['es_extended']:getSharedObject()
    else
        fw = 'wallet'
    end
    print(('[kani-othello] money framework: %s (account: %s)'):format(fw, Config.Money.Account))
end

local function account()
    local a = Config.Money.Account == 'bank' and 'bank' or 'cash'
    if fw == 'esx' and a == 'cash' then return 'money' end
    return a
end

local function qbPlayer(src)
    if fw == 'qbox' then return exports.qbx_core:GetPlayer(src) end
    return core.Functions.GetPlayer(src)
end

---------------------------------------------------------------- 内蔵の財布
local function walletKey(src)
    local id = GetPlayerIdentifierByType(src, 'license')
    if not id then
        for _, v in ipairs(GetPlayerIdentifiers(src)) do id = v break end
    end
    return id and ('wallet:' .. id) or nil
end

local function walletGet(src)
    local key = walletKey(src)
    if not key then return 0 end
    local v = GetResourceKvpString(key)
    if not v then
        v = tostring(math.floor(Config.Money.StartBalance or 0))
        SetResourceKvp(key, v)
    end
    return tonumber(v) or 0
end

local function walletSet(src, amount)
    local key = walletKey(src)
    if key then SetResourceKvp(key, tostring(math.floor(amount))) end
end

---------------------------------------------------------------- 公開API
function Money.balance(src)
    if not fw then detect() end
    local ok, res = pcall(function()
        if fw == 'wallet' then return walletGet(src) end
        if fw == 'esx' then
            local xp = core.GetPlayerFromId(src)
            local acc = xp and xp.getAccount(account())
            return acc and acc.money or 0
        end
        local p = qbPlayer(src)
        return p and p.PlayerData.money[account()] or 0
    end)
    return ok and (tonumber(res) or 0) or 0
end

-- 引けたら true
function Money.remove(src, amount, reason)
    if amount <= 0 then return true end
    if not fw then detect() end
    if Money.balance(src) < amount then return false end
    local ok, res = pcall(function()
        if fw == 'wallet' then
            walletSet(src, walletGet(src) - amount)
            return true
        end
        if fw == 'esx' then
            local xp = core.GetPlayerFromId(src)
            if not xp then return false end
            xp.removeAccountMoney(account(), amount, reason)
            return true
        end
        local p = qbPlayer(src)
        if not p then return false end
        return p.Functions.RemoveMoney(account(), amount, reason) ~= false
    end)
    return ok and res == true
end

function Money.add(src, amount, reason)
    if amount <= 0 then return true end
    if not fw then detect() end
    local ok, res = pcall(function()
        if fw == 'wallet' then
            walletSet(src, walletGet(src) + amount)
            return true
        end
        if fw == 'esx' then
            local xp = core.GetPlayerFromId(src)
            if not xp then return false end
            xp.addAccountMoney(account(), amount, reason)
            return true
        end
        local p = qbPlayer(src)
        if not p then return false end
        return p.Functions.AddMoney(account(), amount, reason) ~= false
    end)
    if not (ok and res) then
        print(('[kani-othello] ^1返金/支払い失敗^7 src=%s amount=%s reason=%s'):format(src, amount, reason))
    end
    return ok and res == true
end

CreateThread(function() Wait(1000) if not fw then detect() end end)
