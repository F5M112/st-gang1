local QBCore = exports['qb-core']:GetCoreObject()
local ActiveWars = {}

-- Declare war
RegisterNetEvent('gang:server:declareWar', function(targetGangId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local attackerGang = GetPlayerGang(Player.PlayerData.citizenid)
    if not attackerGang then
        NotifyPlayer(src, 'You must be in a gang!', 'error')
        return
    end
    
    if attackerGang.leader ~= Player.PlayerData.citizenid then
        NotifyPlayer(src, 'Only the leader can declare war!', 'error')
        return
    end
    
    local defenderGang = GangCache[targetGangId]
    if not defenderGang then
        NotifyPlayer(src, 'Gang not found!', 'error')
        return
    end
    
    if attackerGang.id == targetGangId then
        NotifyPlayer(src, 'Cannot declare war on your own gang!', 'error')
        return
    end
    
    -- Check active wars
    local activeWars = MySQL.scalar.await('SELECT COUNT(*) FROM gang_wars WHERE (attacker_gang_id = ? OR defender_gang_id = ?) AND status IN (?, ?)', {
        attackerGang.id, attackerGang.id, 'pending', 'active'
    })
    
    if activeWars >= Config.War.maxActiveWars then
        NotifyPlayer(src, 'Your gang has too many active wars!', 'error')
        return
    end
    
    -- Check cooldown
    local lastWar = MySQL.single.await('SELECT * FROM gang_wars WHERE (attacker_gang_id = ? OR defender_gang_id = ?) AND ended_at IS NOT NULL ORDER BY ended_at DESC LIMIT 1', {
        attackerGang.id, attackerGang.id
    })
    
    if lastWar and lastWar.ended_at then
        local lastTime = os.time(os.date("!*t", lastWar.ended_at))
        local now = os.time()
        if now - lastTime < Config.War.cooldown then
            local remaining = Config.War.cooldown - (now - lastTime)
            NotifyPlayer(src, string.format('War cooldown! %d seconds remaining', remaining), 'error')
            return
        end
    end
    
    -- Check minimum members
    local onlineMembers = 0
    for _, member in ipairs(attackerGang.members) do
        if QBCore.Functions.GetPlayerByCitizenId(member.identifier) then
            onlineMembers = onlineMembers + 1
        end
    end
    
    if onlineMembers < Config.War.minMembers then
        NotifyPlayer(src, string.format('Need at least %d gang members online!', Config.War.minMembers), 'error')
        return
    end
    
    -- Create war
    local warId = MySQL.insert.await('INSERT INTO gang_wars (attacker_gang_id, defender_gang_id, status) VALUES (?, ?, ?)', {
        attackerGang.id, targetGangId, 'pending'
    })
    
    if warId then
        AddGangLog(attackerGang.id, 'WAR_DECLARED', 'Declared war on ' .. defenderGang.label, Player.PlayerData.citizenid)
        AddGangLog(targetGangId, 'WAR_RECEIVED', 'War declared by ' .. attackerGang.label, 'SYSTEM')
        
        NotifyPlayer(src, 'War declared on ' .. defenderGang.label .. '!', 'success')
        
        -- Notify defender leader
        local DefenderLeader = QBCore.Functions.GetPlayerByCitizenId(defenderGang.leader)
        if DefenderLeader then
            NotifyPlayer(DefenderLeader.PlayerData.source, attackerGang.label .. ' declared war on your gang!', 'error')
            TriggerClientEvent('gang:client:receiveWarRequest', DefenderLeader.PlayerData.source, warId, attackerGang.label)
        end
    end
end)

-- Accept war
RegisterNetEvent('gang:server:acceptWar', function(warId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local gang = GetPlayerGang(Player.PlayerData.citizenid)
    if not gang then
        NotifyPlayer(src, 'You must be in a gang!', 'error')
        return
    end
    
    if gang.leader ~= Player.PlayerData.citizenid then
        NotifyPlayer(src, 'Only the leader can accept wars!', 'error')
        return
    end
    
    local war = MySQL.single.await('SELECT * FROM gang_wars WHERE id = ? AND status = ?', {warId, 'pending'})
    if not war then
        NotifyPlayer(src, 'War not found or already started!', 'error')
        return
    end
    
    if war.defender_gang_id ~= gang.id then
        NotifyPlayer(src, 'This war is not for your gang!', 'error')
        return
    end
    
    -- Start war
    MySQL.update('UPDATE gang_wars SET status = ?, started_at = NOW() WHERE id = ?', {'active', warId})
    
    local attackerGang = GangCache[war.attacker_gang_id]
    
    ActiveWars[warId] = {
        id = warId,
        attacker_gang_id = war.attacker_gang_id,
        defender_gang_id = war.defender_gang_id,
        attacker_kills = 0,
        defender_kills = 0,
        start_time = os.time(),
        duration = Config.War.duration
    }
    
    AddGangLog(gang.id, 'WAR_ACCEPTED', 'Accepted war from ' .. attackerGang.label, Player.PlayerData.citizenid)
    AddGangLog(war.attacker_gang_id, 'WAR_STARTED', 'War with ' .. gang.label .. ' has started', 'SYSTEM')
    
    TriggerClientEvent('gang:client:warStarted', -1, warId, attackerGang.label, gang.label, Config.War.duration)
    
    -- Notify all members
    for _, member in ipairs(gang.members) do
        local MemberPlayer = QBCore.Functions.GetPlayerByCitizenId(member.identifier)
        if MemberPlayer then
            NotifyPlayer(MemberPlayer.PlayerData.source, 'War with ' .. attackerGang.label .. ' has started!', 'error')
        end
    end
    
    for _, member in ipairs(attackerGang.members) do
        local MemberPlayer = QBCore.Functions.GetPlayerByCitizenId(member.identifier)
        if MemberPlayer then
            NotifyPlayer(MemberPlayer.PlayerData.source, 'War with ' .. gang.label .. ' has started!', 'error')
        end
    end
    
    -- War timer
    CreateThread(function()
        Wait(Config.War.duration * 1000)
        if ActiveWars[warId] then
            EndWar(warId)
        end
    end)
end)

-- Decline war
RegisterNetEvent('gang:server:declineWar', function(warId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local gang = GetPlayerGang(Player.PlayerData.citizenid)
    if not gang or gang.leader ~= Player.PlayerData.citizenid then
        return
    end
    
    local war = MySQL.single.await('SELECT * FROM gang_wars WHERE id = ? AND status = ?', {warId, 'pending'})
    if war and war.defender_gang_id == gang.id then
        MySQL.update('UPDATE gang_wars SET status = ?, ended_at = NOW() WHERE id = ?', {'cancelled', warId})
        
        local attackerGang = GangCache[war.attacker_gang_id]
        
        -- Notify attacker
        local AttackerLeader = QBCore.Functions.GetPlayerByCitizenId(attackerGang.leader)
        if AttackerLeader then
            NotifyPlayer(AttackerLeader.PlayerData.source, gang.label .. ' declined the war!', 'error')
        end
        
        NotifyPlayer(src, 'War declined!', 'success')
    end
end)

-- War kill
RegisterNetEvent('gang:server:warKill', function(victimId)
    local src = source
    local Killer = QBCore.Functions.GetPlayer(src)
    local Victim = QBCore.Functions.GetPlayer(victimId)
    
    if not Killer or not Victim then return end
    
    local killerGang = GetPlayerGang(Killer.PlayerData.citizenid)
    local victimGang = GetPlayerGang(Victim.PlayerData.citizenid)
    
    if not killerGang or not victimGang then return end


    -- Find active war
    for warId, war in pairs(ActiveWars) do
        if (war.attacker_gang_id == killerGang.id and war.defender_gang_id == victimGang.id) or
           (war.defender_gang_id == killerGang.id and war.attacker_gang_id == victimGang.id) then

            if war.attacker_gang_id == killerGang.id then
                war.attacker_kills = war.attacker_kills + 1
            else
                war.defender_kills = war.defender_kills + 1
            end

            MySQL.update('UPDATE gang_wars SET attacker_kills = ?, defender_kills = ? WHERE id = ?', {
                war.attacker_kills, war.defender_kills, warId
            })

            AddReputation(killerGang.id, Config.War.killReward)
            killerGang.kills = killerGang.kills + 1
            victimGang.deaths = victimGang.deaths + 1

            MySQL.update('UPDATE gangs SET kills = ? WHERE id = ?', {killerGang.kills, killerGang.id})
            MySQL.update('UPDATE gangs SET deaths = ? WHERE id = ?', {victimGang.deaths, victimGang.id})

            TriggerClientEvent('gang:client:updateWarKills', -1, warId, war.attacker_kills, war.defender_kills)

            break
        end
    end
end)

-- End war
function EndWar(warId)
    local war = ActiveWars[warId]
    if not war then return end

    local attackerGang = GangCache[war.attacker_gang_id]
    local defenderGang = GangCache[war.defender_gang_id]

    local winnerId = nil
    local winnerLabel = ''

    if war.attacker_kills > war.defender_kills then
        winnerId = war.attacker_gang_id
        winnerLabel = attackerGang.label
    elseif war.defender_kills > war.attacker_kills then
        winnerId = war.defender_gang_id
        winnerLabel = defenderGang.label
    end

    MySQL.update('UPDATE gang_wars SET status = ?, winner_gang_id = ?, ended_at = NOW() WHERE id = ?', {
        'finished', winnerId, warId
    })

    if winnerId then
        local winner = GangCache[winnerId]
        local loserId = winnerId == war.attacker_gang_id and war.defender_gang_id or war.attacker_gang_id
        local loser = GangCache[loserId]

        -- Rewards
        winner.balance = winner.balance + Config.War.winReward
        MySQL.update('UPDATE gangs SET balance = ? WHERE id = ?', {winner.balance, winnerId})

        AddReputation(winnerId, Config.War.winReputation)
        AddReputation(loserId, -Config.War.loseReputation)


        AddGangLog(winnerId, 'WAR_WON', 'Won war against ' .. loser.label, 'SYSTEM')
        AddGangLog(loserId, 'WAR_LOST', 'Lost war against ' .. winner.label, 'SYSTEM')


        -- Notify all
        for _, member in ipairs(winner.members) do
            local Player = QBCore.Functions.GetPlayerByCitizenId(member.identifier)
            if Player then
                NotifyPlayer(Player.PlayerData.source, 'Your gang won the war! Reward: $' .. Config.War.winReward, 'success')
            end
        end

        for _, member in ipairs(loser.members) do
            local Player = QBCore.Functions.GetPlayerByCitizenId(member.identifier)
            if Player then
                NotifyPlayer(Player.PlayerData.source, 'Your gang lost the war!', 'error')
            end
        end
    else
        AddGangLog(war.attacker_gang_id, 'WAR_DRAW', 'War ended in a draw', 'SYSTEM')
        AddGangLog(war.defender_gang_id, 'WAR_DRAW', 'War ended in a draw', 'SYSTEM')
    end

    TriggerClientEvent('gang:client:warEnded', -1, warId, winnerLabel)
    ActiveWars[warId] = nil
end

-- Get active wars
RegisterNetEvent('gang:server:getActiveWars', function()
    local src = source
    TriggerClientEvent('gang:client:receiveActiveWars', src, ActiveWars)
end)

-- Get war history
RegisterNetEvent('gang:server:getWarHistory', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    local gang = GetPlayerGang(Player.PlayerData.citizenid)
    if not gang then return end

    local history = MySQL.query.await('SELECT * FROM gang_wars WHERE (attacker_gang_id = ? OR defender_gang_id = ?) AND status = ? ORDER BY ended_at DESC LIMIT 50', {
        gang.id, gang.id, 'finished'
    })

    TriggerClientEvent('gang:client:receiveWarHistory', src, history)
end)