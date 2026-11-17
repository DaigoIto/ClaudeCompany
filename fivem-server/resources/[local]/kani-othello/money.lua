-- 金銭アダプタ: Qbox / QBCore / ESX を自動検出。どれも無ければ内蔵の財布(スタンドアロン)
Money = {}

local function framework()
    local f = Config.Money.Framework
    if f ~= 'auto' then return f end
    if GetResourceState('qbx_core') == 'started' then return 'qbx' end
    if GetResourceState('qb-core') == 'started' then return 'qb' end
    if GetResourceState('es_extended') == 'started' then return 'esx' end
    return 'standalone'
end
Money.framework = framework

local function qbPlayer(src, fw)
    if fw == 'qbx' then return exports.qbx_core:GetPlayer(src) end
    return exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
end

local function esxPlayer(src)
    return exports['es_extended']:getSharedObject().GetPlayerFromId(src)
end

Money.qbPlayer, Money.esxPlayer = qbPlayer, esxPlayer

-- スタンドアロン: license ごとに resource KVP へ保存
local function walletKey(src)
    local id = GetPlayerIdentifierByType(src, 'license') or ('src:' .. src)
    return 'wallet:' .. id
end

local function standaloneGet(src)
    local v = tonumber(GetResourceKvpString(walletKey(src)) or '')
    if v == nil then
        v = Config.Money.StartBalance
        SetResourceKvp(walletKey(src), tostring(v))
    end
    return v
end

local function standaloneSet(src, v)
    SetResourceKvp(walletKey(src), tostring(math.max(0, math.floor(v))))
end

function Money.get(src)
    local fw, acc = framework(), Config.Money.Account
    if fw == 'qbx' or fw == 'qb' then
        local p = qbPlayer(src, fw)
        return p and (p.Functions.GetMoney(acc) or 0) or 0
    elseif fw == 'esx' then
        local p = esxPlayer(src)
        if not p then return 0 end
        if acc == 'bank' then return p.getAccount('bank').money end
        return p.getMoney()
    end
    return standaloneGet(src)
end

function Money.add(src, amount, reason)
    amount = math.floor(amount)
    if amount <= 0 then return true end
    local fw, acc = framework(), Config.Money.Account
    reason = reason or 'kani-othello'
    if fw == 'qbx' or fw == 'qb' then
        local p = qbPlayer(src, fw)
        return p and p.Functions.AddMoney(acc, amount, reason) or false
    elseif fw == 'esx' then
        local p = esxPlayer(src)
        if not p then return false end
        if acc == 'bank' then p.addAccountMoney('bank', amount, reason) else p.addMoney(amount, reason) end
        return true
    end
    standaloneSet(src, standaloneGet(src) + amount)
    return true
end

-- 残高が足りなければ false (何も引かない)
function Money.remove(src, amount, reason)
    amount = math.floor(amount)
    if amount <= 0 then return true end
    if Money.get(src) < amount then return false end
    local fw, acc = framework(), Config.Money.Account
    reason = reason or 'kani-othello'
    if fw == 'qbx' or fw == 'qb' then
        local p = qbPlayer(src, fw)
        return p and p.Functions.RemoveMoney(acc, amount, reason) or false
    elseif fw == 'esx' then
        local p = esxPlayer(src)
        if not p then return false end
        if acc == 'bank' then p.removeAccountMoney('bank', amount, reason) else p.removeMoney(amount, reason) end
        return true
    end
    standaloneSet(src, standaloneGet(src) - amount)
    return true
end
