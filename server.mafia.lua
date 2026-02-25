local QBCore = exports['qb-core']:GetCoreObject()

-- Get all gangs
RegisterNetEvent('mafia:server:getAllGangs', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not IsMafia(Player.PlayerData.citizenid) then
        return
    end
    
    TriggerClientEvent('mafia:client:receiveAllGangs', src, GangCache)
end)

-- Get gang logs
RegisterNetEvent('mafia:server:getGangLogs', function(gangId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not IsMafia(Player.PlayerData.citizenid) then
        return
    end
    
    local logs = MySQL.query.await('SELECT * FROM gang_logs WHERE gang_id = ? ORDER BY created_at DESC LIMIT 100', {gangId})
    TriggerClientEvent('mafia:client:receiveGangLogs', src, logs)
end)

-- Set gang tax
RegisterNetEvent('mafia:server:setGangTax', function(newTax)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not IsMafia(Player.PlayerData.citizenid) then
        NotifyPlayer(src, 'Access denied!', 'error')
        return
    end
    
    if newTax < 0 or newTax > 50 then
        NotifyPlayer(src, 'Tax must be between 0-50%!', 'error')
        return
    end
    
    Config.MafiaTax = newTax
    NotifyPlayer(src, 'Global tax set to ' .. newTax .. '%!', 'success')
    
    -- Notify all online gang members
    for _, gang in pairs(GangCache) do
        for _, member in ipairs(gang.members) do
            local MemberPlayer = QBCore.Functions.GetPlayerByCitizenId(member.identifier)
            if MemberPlayer then
                NotifyPlayer(MemberPlayer.PlayerData.source, 'Mafia changed global tax to ' .. newTax .. '%', 'primary')
            end
        end
    end
end)

-- Withdraw from gang balance
RegisterNetEvent('mafia:server:withdrawFromGang', function(gangId, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not IsMafia(Player.PlayerData.citizenid) then
        NotifyPlayer(src, 'Access denied!', 'error')
        return
    end
    
    local gang = GangCache[gangId]
    if not gang then
        NotifyPlayer(src, 'Gang not found!', 'error')
        return
    end
    
    if gang.balance < amount then
        NotifyPlayer(src, 'Gang does not have enough money!', 'error')
        return
    end
    
    gang.balance = gang.balance - amount
    Player.Functions.AddMoney('cash', amount)
    MySQL.update('UPDATE gangs SET balance = ? WHERE id = ?', {gang.balance, gangId})
    
    AddGangLog(gangId, 'MAFIA_WITHDRAW', string.format('Mafia withdrew $%d', amount), Player.PlayerData.citizenid)
    NotifyPlayer(src, 'Withdrew $' .. amount .. ' from ' .. gang.label, 'success')
    
    -- Notify gang leader
    local Leader = QBCore.Functions.GetPlayerByCitizenId(gang.leader)
    if Leader then
        NotifyPlayer(Leader.PlayerData.source, 'Mafia withdrew $' .. amount .. ' from gang vault!', 'error')
    end
end)

-- Force end war
RegisterNetEvent('mafia:server:forceEndWar', function(warId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not IsMafia(Player.PlayerData.citizenid) then
        NotifyPlayer(src, 'Access denied!', 'error')
        return
    end
    
    MySQL.update('UPDATE gang_wars SET status = ?, ended_at = NOW() WHERE id = ?', {'cancelled', warId})
    
    NotifyPlayer(src, 'War cancelled!', 'success')
    TriggerClientEvent('gang:client:warEnded', -1, warId)
end)

-- Reset gang
RegisterNetEvent('mafia:server:resetGang', function(gangId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not IsMafia(Player.PlayerData.citizenid) then
        NotifyPlayer(src, 'Access denied!', 'error')
        return
    end
    
    local gang = GangCache[gangId]
    if not gang then
        NotifyPlayer(src, 'Gang not found!', 'error')
        return
    end
    
    -- Reset gang stats
    gang.level = 1
    gang.reputation = 0
    gang.kills = 0
    gang.deaths = 0
    gang.balance = 0
    gang.upgrades = {}
    
    MySQL.update('UPDATE gangs SET level = 1, reputation = 0, kills = 0, deaths = 0, balance = 0, upgrades = NULL WHERE id = ?', {gangId})
    
    -- Remove territories
    MySQL.update('UPDATE gang_territories SET gang_id = NULL WHERE gang_id = ?', {gangId})
    
    AddGangLog(gangId, 'MAFIA_RESET', 'Gang was reset by Mafia', Player.PlayerData.citizenid)
    NotifyPlayer(src, gang.label .. ' has been reset!', 'success')
    
    -- Notify all gang members
    for _, member in ipairs(gang.members) do
        local MemberPlayer = QBCore.Functions.GetPlayerByCitizenId(member.identifier)
        if MemberPlayer then
            NotifyPlayer(MemberPlayer.PlayerData.source, 'Your gang has been reset by the Mafia!', 'error')
        end
    end
end)

-- Give money to gang
RegisterNetEvent('mafia:server:giveMoneyToGang', function(gangId, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not IsMafia(Player.PlayerData.citizenid) then
        NotifyPlayer(src, 'Access denied!', 'error')
        return
    end
    
    local gang = GangCache[gangId]
    if not gang then
        NotifyPlayer(src, 'Gang not found!', 'error')
        return
    end
    
    gang.balance = gang.balance + amount
    MySQL.update('UPDATE gangs SET balance = ? WHERE id = ?', {gang.balance, gangId})
    
    AddGangLog(gangId, 'MAFIA_DONATION', string.format('Mafia gave $%d to the gang', amount), Player.PlayerData.citizenid)
    NotifyPlayer(src, 'Gave $' .. amount .. ' to ' .. gang.label, 'success')
    
    -- Notify gang leader
    local Leader = QBCore.Functions.GetPlayerByCitizenId(gang.leader)
    if Leader then
        NotifyPlayer(Leader.PlayerData.source, 'Mafia gave $' .. amount .. ' to gang vault!', 'success')
    end
end)

-- Start territory event
RegisterNetEvent('mafia:server:startTerritoryEvent', function(territoryName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not IsMafia(Player.PlayerData.citizenid) then
        NotifyPlayer(src, 'Access denied!', 'error')
        return
    end
    
    -- Reset territory
    MySQL.update('UPDATE gang_territories SET gang_id = NULL, captured_at = NULL WHERE territory_name = ?', {territoryName})
    
    NotifyPlayer(src, territoryName .. ' is now available for capture!', 'success')
    TriggerClientEvent('gang:client:territoryAvailable', -1, territoryName)
    
    -- Notify all gangs
    for _, gang in pairs(GangCache) do
        for _, member in ipairs(gang.members) do
            local MemberPlayer = QBCore.Functions.GetPlayerByCitizenId(member.identifier)
            if MemberPlayer then
                NotifyPlayer(MemberPlayer.PlayerData.source, territoryName .. ' is now available for capture!', 'primary')
            end
        end
    end
end)

-- Get mafia statistics
RegisterNetEvent('mafia:server:getStatistics', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not IsMafia(Player.PlayerData.citizenid) then
        return
    end
    
    local stats = {
        totalGangs = 0,
        totalMembers = 0,
        totalMoney = 0,
        activeWars = 0,
        capturedTerritories = 0
    }
    
    for _, gang in pairs(GangCache) do
        stats.totalGangs = stats.totalGangs + 1
        stats.totalMembers = stats.totalMembers + #gang.members
        stats.totalMoney = stats.totalMoney + gang.balance
    end
    
    local wars = MySQL.scalar.await('SELECT COUNT(*) FROM gang_wars WHERE status = ?', {'active'})
    stats.activeWars = wars or 0
    
    local territories = MySQL.scalar.await('SELECT COUNT(*) FROM gang_territories WHERE gang_id IS NOT NULL', {})
    stats.capturedTerritories = territories or 0
    
    TriggerClientEvent('mafia:client:receiveStatistics', src, stats)
end)

-- Update gang rank
RegisterNetEvent('mafia:server:updateMemberRank', function(gangId, memberIdentifier, newRank)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not IsMafia(Player.PlayerData.citizenid) then
        NotifyPlayer(src, 'Access denied!', 'error')
        return
    end
    
    local gang = GangCache[gangId]
    if not gang then
        NotifyPlayer(src, 'Gang not found!', 'error')
        return
    end
    
    MySQL.update('UPDATE gang_members SET rank = ? WHERE gang_id = ? AND identifier = ?', {
        newRank, gangId, memberIdentifier
    })
    
    for _, member in ipairs(gang.members) do
        if member.identifier == memberIdentifier then
            member.rank = newRank
            break
        end
    end
    
    AddGangLog(gangId, 'RANK_CHANGED', 'Member rank changed by Mafia', Player.PlayerData.citizenid)
    NotifyPlayer(src, 'Member rank updated!', 'success')
end)