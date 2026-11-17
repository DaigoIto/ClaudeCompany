-- 最初の1回だけスポーン位置を設定 (spawnmanager 使用)
local spawnPoint = vector4(-1042.0, -2745.0, 21.4, 330.0) -- LS国際空港付近

AddEventHandler('onClientMapStart', function()
    exports.spawnmanager:setAutoSpawn(true)
    exports.spawnmanager:setAutoSpawnCallback(function()
        exports.spawnmanager:spawnPlayer({
            x = spawnPoint.x, y = spawnPoint.y, z = spawnPoint.z,
            heading = spawnPoint.w, model = `mp_m_freemode_01`, skipFade = false
        })
    end)
end)

-- 固定の晴れ・時間固定にしたい場合はここで調整
CreateThread(function()
    while true do
        SetWeatherTypePersist('EXTRASUNNY')
        SetWeatherTypeNow('EXTRASUNNY')
        SetWeatherTypeNowPersist('EXTRASUNNY')
        Wait(5000)
    end
end)

-- サーバー時刻の同期
RegisterNetEvent('worldsettings:time', function(h, m)
    NetworkOverrideClockTime(h, m, 0)
end)
CreateThread(function()
    Wait(2000)
    TriggerServerEvent('worldsettings:requestTime')
end)

-- 通行人・車の密度 (1.0 = 通常)
CreateThread(function()
    while true do
        SetPedDensityMultiplierThisFrame(0.6)
        SetVehicleDensityMultiplierThisFrame(0.5)
        SetRandomVehicleDensityMultiplierThisFrame(0.5)
        SetParkedVehicleDensityMultiplierThisFrame(0.5)
        Wait(0)
    end
end)
