local spawned = {}

local function loadModel(name)
    local hash = type(name) == 'number' and name or joaat(name)
    if not IsModelInCdimage(hash) then
        print(('[myworld] 不明なモデル: %s'):format(tostring(name)))
        return nil
    end
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) do
        Wait(10)
        if GetGameTimer() - t > 5000 then return nil end
    end
    return hash
end

local function placeProps()
    for _, p in ipairs(Config.Props) do
        local hash = loadModel(p[1])
        if hash then
            local pos = Config.Center + p[2]
            local obj = CreateObjectNoOffset(hash, pos.x, pos.y, pos.z, false, false, false)
            SetEntityHeading(obj, p[3] + 0.0)
            PlaceObjectOnGroundProperly(obj)
            FreezeEntityPosition(obj, true)
            spawned[#spawned + 1] = obj
            SetModelAsNoLongerNeeded(hash)
        end
    end
end

local function placeVehicles()
    for _, v in ipairs(Config.Vehicles) do
        local hash = loadModel(v[1])
        if hash then
            local pos = Config.Center + v[2]
            local veh = CreateVehicle(hash, pos.x, pos.y, pos.z, v[3] + 0.0, false, false)
            SetVehicleOnGroundProperly(veh)
            SetEntityAsMissionEntity(veh, true, true)
            spawned[#spawned + 1] = veh
            SetModelAsNoLongerNeeded(hash)
        end
    end
end

local function addBlip()
    local b = AddBlipForCoord(Config.Center.x, Config.Center.y, Config.Center.z)
    SetBlipSprite(b, Config.Blip.sprite)
    SetBlipColour(b, Config.Blip.colour)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Blip.label)
    EndTextCommandSetBlipName(b)
end

CreateThread(function()
    addBlip()
    -- 広場の近くに来たらロード (遠いと地形が未ロードで地面に置けないため)
    local built = false
    while true do
        local dist = #(GetEntityCoords(PlayerPedId()) - Config.Center)
        if dist < 250.0 and not built then
            RequestCollisionAtCoord(Config.Center.x, Config.Center.y, Config.Center.z)
            placeProps()
            placeVehicles()
            built = true
        elseif dist > 400.0 and built then
            for _, e in ipairs(spawned) do
                if DoesEntityExist(e) then DeleteEntity(e) end
            end
            spawned = {}
            built = false
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, e in ipairs(spawned) do
        if DoesEntityExist(e) then DeleteEntity(e) end
    end
end)

-- /tpworld で広場にテレポート
RegisterCommand('tpworld', function()
    local c = Config.Center
    SetEntityCoords(PlayerPedId(), c.x + 6.0, c.y, c.z + 1.0, false, false, false, false)
end, false)
