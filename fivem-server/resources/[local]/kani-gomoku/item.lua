-- アイテム「五目並べセット」。ox_inventory / Qbox / QBCore / ESX を自動検出して「使う」を登録する
-- 使うと卓を置く(アイテムは減らない。置けるのは1人1卓まで。片付けると次また置ける)
Item = {}

local name = Config.Item.Name
local inv   -- 'ox' / 'qbox' / 'qbcore' / 'esx' / nil
local core

local function started(res) return GetResourceState(res) == 'started' end

-- アイテムを持っているか
function Item.has(src)
    local ok, res = pcall(function()
        if inv == 'ox' then
            return (exports.ox_inventory:GetItemCount(src, name) or 0) > 0
        elseif inv == 'qbox' or inv == 'qbcore' then
            local p = inv == 'qbox' and exports.qbx_core:GetPlayer(src) or core.Functions.GetPlayer(src)
            return p and p.Functions.GetItemByName(name) ~= nil
        elseif inv == 'esx' then
            local x = core.GetPlayerFromId(src)
            local it = x and x.getInventoryItem(name)
            return it and (it.count or 0) > 0
        end
        return false
    end)
    return ok and res or false
end

local onUse   -- server.lua から渡される: function(src)

function Item.onUse(fn) onUse = fn end

local function use(src)
    if onUse then onUse(src) end
end

-- ox_inventory は items.lua の server.export からここを呼ぶ (export 名 = アイテム名)
exports(name, function(event, item, inventory, slot, data)
    if event == 'usingItem' then
        use(inventory.id)
        return false   -- 使用アニメ・消費をしない
    end
end)

CreateThread(function()
    Wait(500)
    if started('ox_inventory') then
        inv = 'ox'
    elseif started('qbx_core') then
        inv = 'qbox'
        exports.qbx_core:CreateUseableItem(name, function(src) use(src) end)
    elseif started('qb-core') then
        inv = 'qbcore'
        core = exports['qb-core']:GetCoreObject()
        core.Functions.CreateUseableItem(name, function(src) use(src) end)
    elseif started('es_extended') then
        inv = 'esx'
        core = exports['es_extended']:getSharedObject()
        core.RegisterUsableItem(name, function(src) use(src) end)
    end
    print(('[kani-gomoku] item "%s": %s'):format(name, inv or 'インベントリが見つかりません'))
end)
