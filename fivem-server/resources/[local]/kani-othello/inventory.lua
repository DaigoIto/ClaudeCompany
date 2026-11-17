-- アイテム操作アダプタ: ox_inventory があれば優先。無ければ Qbox / QBCore / ESX。スタンドアロンは不可
Inv = {}

local function oxStarted()
    return GetResourceState('ox_inventory') == 'started'
end

function Inv.available()
    return oxStarted() or Money.framework() ~= 'standalone'
end

-- 1個消費。成功したら true
function Inv.remove(src)
    local item = Config.Placeable.Item
    if oxStarted() then
        return exports.ox_inventory:RemoveItem(src, item, 1) and true or false
    end
    local fw = Money.framework()
    if fw == 'qbx' or fw == 'qb' then
        local p = Money.qbPlayer(src, fw)
        return p and p.Functions.RemoveItem(item, 1) and true or false
    elseif fw == 'esx' then
        local p = Money.esxPlayer(src)
        if not p or p.getInventoryItem(item).count < 1 then return false end
        p.removeInventoryItem(item, 1)
        return true
    end
    return false
end

-- 1個返す。持ち物がいっぱいなら false (何も返さない)
function Inv.add(src)
    local item = Config.Placeable.Item
    if oxStarted() then
        if not exports.ox_inventory:CanCarryItem(src, item, 1) then return false end
        return exports.ox_inventory:AddItem(src, item, 1) and true or false
    end
    local fw = Money.framework()
    if fw == 'qbx' or fw == 'qb' then
        local p = Money.qbPlayer(src, fw)
        return p and p.Functions.AddItem(item, 1) and true or false
    elseif fw == 'esx' then
        local p = Money.esxPlayer(src)
        if not p or not p.canCarryItem(item, 1) then return false end
        p.addInventoryItem(item, 1)
        return true
    end
    return false
end
