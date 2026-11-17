-- サーバー時間を進める (昼夜サイクル)。全クライアントに現在時刻を送る
local hour, minute = 12, 0

CreateThread(function()
    while true do
        Wait(2000) -- 2秒 = ゲーム内1分 (1時間=2分で1日48分)
        minute = minute + 1
        if minute >= 60 then minute = 0; hour = (hour + 1) % 24 end
        TriggerClientEvent('worldsettings:time', -1, hour, minute)
    end
end)

RegisterNetEvent('worldsettings:requestTime', function()
    TriggerClientEvent('worldsettings:time', source, hour, minute)
end)
