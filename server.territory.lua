local QBCore = exports['qb-core']:GetCoreObject()
local ActiveCaptures = {}

-- Get territories
RegisterNetEvent('gang:server:getTerritories', function()
    local src = source
    local territories = MySQL.query.await('SELECT * FROM gang_territories', {})
    TriggerClientEvent('gang:client:receiveTerritories', src, territories)
end)

-- Start territory capture
RegisterNetEvent('gang:server:startCapture', function(territoryName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local gang = GetPlayerGang(Player.PlayerData.citizenid)
    if not gang then
        NotifyPlayer(src, 'You must be in a gang to capture territory!', 'error')
        return
    end
    
    -- Check if already capturing
    if ActiveCaptures[territoryName] then
        NotifyPlayer(src, 'This territory is already being captured!', 'error')
        return
    end
    
    -- Find territory config
    local territoryConfig = nil
    for _, terr in ipairs(Config.Territories) do
        if terr.name == territoryName then
            territoryConfig = terr
            break
        end
    end
    
    if not territoryConfig then
        NotifyPlayer(src, 'Territory not found!', 'error')
        return
    end
    
    -- Check minimum members online
    local onlineMembers = 0
    for _, member in ipairs(gang.members) do
        if QBCore.Functions.GetPlayerByCitizenId(member.identifier) then
            onlineMembers = onlineMembers + 1
        end
    end
    
    if onlineMembers < territoryConfig.minMembers then
        NotifyPlayer(src, string.format('Need at least %d gang members online!', territoryConfig.minMembers), 'error')
        return
    end
    
    -- Check cooldown
    local territory = MySQL.single.await('SELECT * FROM gang_territories WHERE territory_name = ?', {territoryName})
    if territory and territory.last_capture_attempt then
        local lastAttempt = os.time(os.date("!*t", territory.last_capture_attempt))
        local now = os.time()
        if now - lastAttempt < territoryConfig.cooldown then
            local remaining = territoryConfig.cooldown - (now - lastAttempt)
            NotifyPlayer(src, string.format('Territory on cooldown! %d seconds remaining', remaining), 'error')
            return
        end
    end
    
    -- Check if territory is owned by same gang
    if territory and territory.gang_id == gang.id then
        NotifyPlayer(src, 'Your gang already owns this territory!', 'error')
        return
    end
    
    -- Start capture
    local captureTime = territoryConfig.captureTime
    
    -- Apply upgrade
    if gang.upgrades.capture_speed then
        captureTime = captureTime * (1 - gang.upgrades.capture_speed / 100)
    end
    
    ActiveCaptures[territoryName] = {
        gangId = gang.id,
        startTime = os.time(),
        duration = captureTime,
        source = src
    }
    
    MySQL.update('UPDATE gang_territories SET last_capture_attempt = NOW() WHERE territory_name = ?', {territoryName})
    
    TriggerClientEvent('gang:client:startCapture', -1, territoryName, gang.id, gang.label, captureTime)
    
    -- Notify defenders
    if territory and territory.gang_id then
        local defenderGang = GangCache[territory.gang_id]
        if defenderGang then
            for _, member in ipairs(defenderGang.members) do
                local DefenderPlayer = QBCore.Functions.GetPlayerByCitizenId(member.identifier)
                if DefenderPlayer then
                    NotifyPlayer(DefenderPlayer.PlayerData.source, gang.label .. ' is attacking ' .. territoryName .. '!', 'error')
                end
            end
        end
    end
    
    -- Set timer
    CreateThread(function()
        Wait(captureTime * 1000)
        
        if ActiveCaptures[territoryName] and ActiveCaptures[territoryName].gangId == gang.id then
            -- Capture successful
            local oldGangId = territory and territory.gang_id or nil
            
            MySQL.update('UPDATE gang_territories SET gang_id = ?, captured_at = NOW() WHERE territory_name = ?', {
                gang.id, territoryName
            })
            
            AddReputation(gang.id, Config.Reputation.captureTerritory)
            AddGangLog(gang.id, 'TERRITORY_CAPTURED', territoryName .. ' has been captured', 'SYSTEM')
            
            TriggerClientEvent('gang:client:captureSuccess', -1, territoryName, gang.id, gang.label)
            
            -- Notify gang
            for _, member in ipairs(gang.members) do
                local MemberPlayer = QBCore.Functions.GetPlayerByCitizenId(member.identifier)
                if MemberPlayer then
                    NotifyPlayer(MemberPlayer.PlayerData.source, 'Successfully captured ' .. territoryName .. '!', 'success')
                end
            end
            
            -- Notify old owner
            if oldGangId then
                local oldGang = GangCache[oldGangId]
                if oldGang then
                    for _, member in ipairs(oldGang.members) do
                        local OldMemberPlayer = QBCore.Functions.GetPlayerByCitizenId(member.identifier)
                        if OldMemberPlayer then
                            NotifyPlayer(OldMemberPlayer.PlayerData.source, 'Lost control of ' .. territoryName .. '!', 'error')
                        end
                    end
                end
            end
            
            ActiveCaptures[territoryName] = nil
        end
    end)
end)

-- Cancel capture
RegisterNetEvent('gang:server:cancelCapture', function(territoryName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local capture = ActiveCaptures[territoryName]
    if not capture then
        return
    end
    
    local gang = GetPlayerGang(Player.PlayerData.citizenid)
    if not gang or gang.id ~= capture.gangId then
        return
    end
    
    ActiveCaptures[territoryName] = nil
    TriggerClientEvent('gang:client:captureCancelled', -1, territoryName)
    
    for _, member in ipairs(gang.members) do
        local MemberPlayer = QBCore.Functions.GetPlayerByCitizenId(member.identifier)
        if MemberPlayer then
            NotifyPlayer(MemberPlayer.PlayerData.source, 'Territory capture cancelled!', 'error')
        end
    end
end)

-- Defend territory (interrupt capture)
RegisterNetEvent('gang:server:defendTerritory', function(territoryName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local gang = GetPlayerGang(Player.PlayerData.citizenid)
    if not gang then
        return
    end
    
    local capture = ActiveCaptures[territoryName]
    if not capture then
        return
    end
    
    -- Check if this gang owns the territory
    local territory = MySQL.single.await('SELECT * FROM gang_territories WHERE territory_name = ?', {territoryName})
    if not territory or territory.gang_id ~= gang.id then
        return
    end
    
    -- Cancel capture
    ActiveCaptures[territoryName] = nil
    TriggerClientEvent('gang:client:captureDefended', -1, territoryName, gang.label)
    
    local attackerGang = GangCache[capture.gangId]
    if attackerGang then
        for _, member in ipairs(attackerGang.members) do
            local AttackerPlayer = QBCore.Functions.GetPlayerByCitizenId(member.identifier)
            if AttackerPlayer then
                NotifyPlayer(AttackerPlayer.PlayerData.source, 'Territory capture was defended by ' .. gang.label .. '!', 'error')
            end
        end
    end
    
    for _, member in ipairs(gang.members) do
        local DefenderPlayer = QBCore.Functions.GetPlayerByCitizenId(member.identifier)
        if DefenderPlayer then
            NotifyPlayer(DefenderPlayer.PlayerData.source, 'Successfully defended ' .. territoryName .. '!', 'success')
        end
    end
    
    AddReputation(gang.id, Config.Reputation.captureTerritory / 2)
end)

-- Get capture progress
RegisterNetEvent('gang:server:getCaptureProgress', function()
    local src = source
    TriggerClientEvent('gang:client:updateCaptureProgress', src, ActiveCaptures)
end)