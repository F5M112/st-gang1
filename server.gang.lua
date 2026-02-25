local QBCore = exports['qb-core']:GetCoreObject()

-- Create Gang
RegisterNetEvent('gang:server:createGang', function(gangName, gangLabel, leaderIdentifier)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player is mafia
    if not IsMafia(Player.PlayerData.citizenid) then
        NotifyPlayer(src, 'Only Mafia can create gangs!', 'error')
        return
    end
    
    -- Check if gang exists
    local exists = MySQL.scalar.await('SELECT id FROM gangs WHERE name = ?', {gangName})
    if exists then
        NotifyPlayer(src, 'Gang name already exists!', 'error')
        return
    end
    
    -- Create gang
    local gangId = MySQL.insert.await('INSERT INTO gangs (name, label, leader, balance, level, reputation) VALUES (?, ?, ?, ?, ?, ?)', {
        gangName,
        gangLabel,
        leaderIdentifier,
        0,
        Config.DefaultGangLevel,
        0
    })
    
    if gangId then
        -- Add leader as member
        MySQL.insert('INSERT INTO gang_members (gang_id, identifier, rank) VALUES (?, ?, ?)', {
            gangId,
            leaderIdentifier,
            4 -- Leader rank
        })
        
        -- Update cache
        GangCache[gangId] = {
            id = gangId,
            name = gangName,
            label = gangLabel,
            leader = leaderIdentifier,
            balance = 0,
            level = Config.DefaultGangLevel,
            reputation = 0,
            kills = 0,
            deaths = 0,
            vault_coords = nil,
            upgrades = {},
            members = {{identifier = leaderIdentifier, rank = 4, joined_at = os.date('%Y-%m-%d %H:%M:%S')}}
        }
        PlayerGangs[leaderIdentifier] = gangId
        
        AddGangLog(gangId, 'GANG_CREATED', 'Gang created by Mafia', Player.PlayerData.citizenid)
        NotifyPlayer(src, 'Gang created successfully!', 'success')
        
        -- Notify leader
        local LeaderPlayer = QBCore.Functions.GetPlayerByCitizenId(leaderIdentifier)
        if LeaderPlayer then
            NotifyPlayer(LeaderPlayer.PlayerData.source, 'You have been assigned as leader of ' .. gangLabel, 'success')
        end
    end
end)

-- Delete Gang
RegisterNetEvent('gang:server:deleteGang', function(gangId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player is mafia
    if not IsMafia(Player.PlayerData.citizenid) then
        NotifyPlayer(src, 'Only Mafia can delete gangs!', 'error')
        return
    end
    
    local gang = GangCache[gangId]
    if not gang then
        NotifyPlayer(src, 'Gang not found!', 'error')
        return
    end
    
    -- Notify all members
    for _, member in ipairs(gang.members) do
        PlayerGangs[member.identifier] = nil
        local MemberPlayer = QBCore.Functions.GetPlayerByCitizenId(member.identifier)
        if MemberPlayer then
            NotifyPlayer(MemberPlayer.PlayerData.source, 'Your gang has been dissolved by the Mafia', 'error')
        end
    end
    
    -- Delete from database
    MySQL.update('DELETE FROM gangs WHERE id = ?', {gangId})
    
    -- Remove from cache
    GangCache[gangId] = nil
    
    NotifyPlayer(src, 'Gang deleted successfully!', 'success')
end)

-- Change Leader
RegisterNetEvent('gang:server:changeLeader', function(gangId, newLeaderIdentifier)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player is mafia
    if not IsMafia(Player.PlayerData.citizenid) then
        NotifyPlayer(src, 'Only Mafia can change leaders!', 'error')
        return
    end
    
    local gang = GangCache[gangId]
    if not gang then
        NotifyPlayer(src, 'Gang not found!', 'error')
        return
    end
    
    -- Check if new leader is in gang
    local isMember = false
    for _, member in ipairs(gang.members) do
        if member.identifier == newLeaderIdentifier then
            isMember = true
            member.rank = 4 -- Set as leader
            break
        end
    end
    
    if not isMember then
        NotifyPlayer(src, 'Player is not a member of this gang!', 'error')
        return
    end
    
    -- Update old leader rank
    for _, member in ipairs(gang.members) do
        if member.identifier == gang.leader then
            member.rank = 3 -- Co-Leader
            MySQL.update('UPDATE gang_members SET rank = ? WHERE gang_id = ? AND identifier = ?', {
                3, gangId, member.identifier
            })
            break
        end
    end
    
    -- Update new leader
    gang.leader = newLeaderIdentifier
    MySQL.update('UPDATE gangs SET leader = ? WHERE id = ?', {newLeaderIdentifier, gangId})
    MySQL.update('UPDATE gang_members SET rank = ? WHERE gang_id = ? AND identifier = ?', {
        4, gangId, newLeaderIdentifier
    })
    
    AddGangLog(gangId, 'LEADER_CHANGED', 'Leadership changed by Mafia', Player.PlayerData.citizenid)
    NotifyPlayer(src, 'Leader changed successfully!', 'success')
    
    -- Notify new leader
    local NewLeader = QBCore.Functions.GetPlayerByCitizenId(newLeaderIdentifier)
    if NewLeader then
        NotifyPlayer(NewLeader.PlayerData.source, 'You are now the leader of ' .. gang.label, 'success')
    end
end)

-- Invite Member
RegisterNetEvent('gang:server:inviteMember', function(targetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(targetId)
    
    if not Player or not Target then return end
    
    local gang = GetPlayerGang(Player.PlayerData.citizenid)
    if not gang then
        NotifyPlayer(src, 'You are not in a gang!', 'error')
        return
    end
    
    local rank = GetPlayerRankInGang(Player.PlayerData.citizenid, gang.id)
    local rankData = Config.GangRanks[rank]
    
    if not rankData or not rankData.canInvite then
        NotifyPlayer(src, 'You do not have permission to invite members!', 'error')
        return
    end
    
    -- Check if target is already in a gang
    if GetPlayerGang(Target.PlayerData.citizenid) then
        NotifyPlayer(src, 'Player is already in a gang!', 'error')
        return
    end
    
    -- Check member limit
    local maxSlots = Config.DefaultMemberSlots
    if gang.upgrades.member_slots then
        maxSlots = maxSlots + gang.upgrades.member_slots
    end
    
    if #gang.members >= maxSlots then
        NotifyPlayer(src, 'Gang has reached maximum member limit!', 'error')
        return
    end
    
    -- Send invite
    TriggerClientEvent('gang:client:receiveInvite', targetId, gang.id, gang.label, src)
    NotifyPlayer(src, 'Invite sent to ' .. Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname, 'success')
end)

-- Accept Invite
RegisterNetEvent('gang:server:acceptInvite', function(gangId, inviterSource)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local gang = GangCache[gangId]
    if not gang then
        NotifyPlayer(src, 'Gang not found!', 'error')
        return
    end
    
    -- Check if already in gang
    if GetPlayerGang(Player.PlayerData.citizenid) then
        NotifyPlayer(src, 'You are already in a gang!', 'error')
        return
    end
    
    -- Add member
    MySQL.insert('INSERT INTO gang_members (gang_id, identifier, rank) VALUES (?, ?, ?)', {
        gangId,
        Player.PlayerData.citizenid,
        1 -- Recruit
    })
    
    table.insert(gang.members, {
        identifier = Player.PlayerData.citizenid,
        rank = 1,
        joined_at = os.date('%Y-%m-%d %H:%M:%S')
    })
    PlayerGangs[Player.PlayerData.citizenid] = gangId
    
    AddGangLog(gangId, 'MEMBER_JOINED', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' joined the gang', Player.PlayerData.citizenid)
    NotifyPlayer(src, 'You joined ' .. gang.label .. '!', 'success')
    NotifyPlayer(inviterSource, Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' joined the gang!', 'success')
end)

-- Kick Member
RegisterNetEvent('gang:server:kickMember', function(targetIdentifier)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local gang = GetPlayerGang(Player.PlayerData.citizenid)
    if not gang then
        NotifyPlayer(src, 'You are not in a gang!', 'error')
        return
    end
    
    local rank = GetPlayerRankInGang(Player.PlayerData.citizenid, gang.id)
    local rankData = Config.GangRanks[rank]
    
    if not rankData or not rankData.canKick then
        NotifyPlayer(src, 'You do not have permission to kick members!', 'error')
        return
    end
    
    -- Remove member
    MySQL.update('DELETE FROM gang_members WHERE gang_id = ? AND identifier = ?', {gang.id, targetIdentifier})
    
    for i, member in ipairs(gang.members) do
        if member.identifier == targetIdentifier then
            table.remove(gang.members, i)
            PlayerGangs[targetIdentifier] = nil
            break
        end
    end
    
    AddGangLog(gang.id, 'MEMBER_KICKED', 'Member was kicked from the gang', Player.PlayerData.citizenid)
    NotifyPlayer(src, 'Member kicked successfully!', 'success')
    
    -- Notify kicked player
    local Target = QBCore.Functions.GetPlayerByCitizenId(targetIdentifier)
    if Target then
        NotifyPlayer(Target.PlayerData.source, 'You have been kicked from ' .. gang.label, 'error')
    end
end)

-- Leave Gang
RegisterNetEvent('gang:server:leaveGang', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local gang = GetPlayerGang(Player.PlayerData.citizenid)
    if not gang then
        NotifyPlayer(src, 'You are not in a gang!', 'error')
        return
    end
    
    -- Check if leader
    if gang.leader == Player.PlayerData.citizenid then
        NotifyPlayer(src, 'Leaders cannot leave! Transfer leadership first.', 'error')
        return
    end
    
    -- Remove member
    MySQL.update('DELETE FROM gang_members WHERE gang_id = ? AND identifier = ?', {gang.id, Player.PlayerData.citizenid})
    
    for i, member in ipairs(gang.members) do
        if member.identifier == Player.PlayerData.citizenid then
            table.remove(gang.members, i)
            PlayerGangs[Player.PlayerData.citizenid] = nil
            break
        end
    end
    
    AddGangLog(gang.id, 'MEMBER_LEFT', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' left the gang', Player.PlayerData.citizenid)
    NotifyPlayer(src, 'You left the gang!', 'success')
end)

-- Deposit Money
RegisterNetEvent('gang:server:depositMoney', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local gang = GetPlayerGang(Player.PlayerData.citizenid)
    if not gang then
        NotifyPlayer(src, 'You are not in a gang!', 'error')
        return
    end
    
    if Player.PlayerData.money.cash < amount then
        NotifyPlayer(src, 'You do not have enough cash!', 'error')
        return
    end
    
    -- Check vault size
    local maxVault = Config.DefaultVaultSize
    if gang.upgrades.vault_size then
        maxVault = gang.upgrades.vault_size
    end
    
    if gang.balance + amount > maxVault then
        NotifyPlayer(src, 'Gang vault is full!', 'error')
        return
    end
    
    Player.Functions.RemoveMoney('cash', amount)
    gang.balance = gang.balance + amount
    MySQL.update('UPDATE gangs SET balance = ? WHERE id = ?', {gang.balance, gang.id})
    
    AddGangLog(gang.id, 'DEPOSIT', string.format('$%d deposited by %s %s', amount, Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname), Player.PlayerData.citizenid)
    NotifyPlayer(src, 'Deposited $' .. amount .. ' to gang vault!', 'success')
end)

-- Withdraw Money
RegisterNetEvent('gang:server:withdrawMoney', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local gang = GetPlayerGang(Player.PlayerData.citizenid)
    if not gang then
        NotifyPlayer(src, 'You are not in a gang!', 'error')
        return
    end
    
    local rank = GetPlayerRankInGang(Player.PlayerData.citizenid, gang.id)
    local rankData = Config.GangRanks[rank]
    
    if not rankData or not rankData.canWithdraw then
        NotifyPlayer(src, 'You do not have permission to withdraw money!', 'error')
        return
    end
    
    if gang.balance < amount then
        NotifyPlayer(src, 'Gang does not have enough money!', 'error')
        return
    end
    
    gang.balance = gang.balance - amount
    Player.Functions.AddMoney('cash', amount)
    MySQL.update('UPDATE gangs SET balance = ? WHERE id = ?', {gang.balance, gang.id})
    
    AddGangLog(gang.id, 'WITHDRAW', string.format('$%d withdrawn by %s %s', amount, Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname), Player.PlayerData.citizenid)
    NotifyPlayer(src, 'Withdrew $' .. amount .. ' from gang vault!', 'success')
end)

-- Set Vault Location
RegisterNetEvent('gang:server:setVaultLocation', function(coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local gang = GetPlayerGang(Player.PlayerData.citizenid)
    if not gang then
        NotifyPlayer(src, 'You are not in a gang!', 'error')
        return
    end
    
    if gang.leader ~= Player.PlayerData.citizenid then
        NotifyPlayer(src, 'Only the leader can set vault location!', 'error')
        return
    end
    
    gang.vault_coords = coords
    MySQL.update('UPDATE gangs SET vault_coords = ? WHERE id = ?', {json.encode(coords), gang.id})
    
    AddGangLog(gang.id, 'VAULT_LOCATION', 'Vault location updated', Player.PlayerData.citizenid)
    NotifyPlayer(src, 'Vault location set successfully!', 'success')
    TriggerClientEvent('gang:client:updateVaultLocation', -1, gang.id, coords)
end)