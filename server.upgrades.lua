local QBCore = exports['qb-core']:GetCoreObject()

-- ============= UPGRADES SYSTEM =============

RegisterNetEvent('gang:server:purchaseUpgrade', function(upgradeType, level)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local gang = GetPlayerGang(Player.PlayerData.citizenid)
    if not gang then
        NotifyPlayer(src, 'You must be in a gang!', 'error')
        return
    end
    
    local rank = GetPlayerRankInGang(Player.PlayerData.citizenid, gang.id)
    local rankData = Config.GangRanks[rank]
    
    if not rankData or not rankData.canUpgrade then
        NotifyPlayer(src, 'You do not have permission to purchase upgrades!', 'error')
        return
    end
    
    local upgradeConfig = Config.Upgrades[upgradeType]
    if not upgradeConfig or not upgradeConfig.levels[level] then
        NotifyPlayer(src, 'Invalid upgrade!', 'error')
        return
    end
    
    local upgrade = upgradeConfig.levels[level]
    local currentLevel = gang.upgrades[upgradeType] or 0
    
    if level ~= currentLevel + 1 then
        NotifyPlayer(src, 'Must purchase upgrades in order!', 'error')
        return
    end
    
    if gang.balance < upgrade.cost then
        NotifyPlayer(src, 'Gang does not have enough money!', 'error')
        return
    end
    
    -- Purchase upgrade
    gang.balance = gang.balance - upgrade.cost
    gang.upgrades[upgradeType] = upgrade.value
    
    MySQL.update('UPDATE gangs SET balance = ?, upgrades = ? WHERE id = ?', {
        gang.balance,
        json.encode(gang.upgrades),
        gang.id
    })
    
    AddGangLog(gang.id, 'UPGRADE_PURCHASED', 
        string.format('%s Level %d purchased for $%d', upgradeConfig.name, level, upgrade.cost),
        Player.PlayerData.citizenid
    )
    
    NotifyPlayer(src, string.format('Purchased %s Level %d!', upgradeConfig.name, level), 'success')
    
    -- Notify all gang members
    for _, member in ipairs(gang.members) do
        local MemberPlayer = QBCore.Functions.GetPlayerByCitizenId(member.identifier)
        if MemberPlayer and MemberPlayer.PlayerData.source ~= src then
            NotifyPlayer(MemberPlayer.PlayerData.source, 
                string.format('%s purchased %s Level %d', 
                    Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                    upgradeConfig.name,
                    level
                ),
                'success'
            )
        end
    end
end)

RegisterNetEvent('gang:server:getUpgrades', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local gang = GetPlayerGang(Player.PlayerData.citizenid)
    if gang then
        TriggerClientEvent('gang:client:receiveUpgrades', src, gang.upgrades)
    end
end)

-- ============= LEADERBOARD SYSTEM =============

local Leaderboards = {
    money = {},
    territories = {},
    kills = {},
    reputation = {}
}

-- Update leaderboards
function UpdateLeaderboards()
    -- Money leaderboard
    Leaderboards.money = {}
    for gangId, gang in pairs(GangCache) do
        table.insert(Leaderboards.money, {
            gangId = gangId,
            name = gang.label,
            value = gang.balance
        })
    end
    table.sort(Leaderboards.money, function(a, b) return a.value > b.value end)
    
    -- Territories leaderboard
    Leaderboards.territories = {}
    local territories = MySQL.query.await('SELECT gang_id, COUNT(*) as count FROM gang_territories WHERE gang_id IS NOT NULL GROUP BY gang_id', {})
    for _, data in ipairs(territories) do
        local gang = GangCache[data.gang_id]
        if gang then
            table.insert(Leaderboards.territories, {
                gangId = data.gang_id,
                name = gang.label,
                value = data.count
            })
        end
    end
    table.sort(Leaderboards.territories, function(a, b) return a.value > b.value end)
    
    -- Kills leaderboard
    Leaderboards.kills = {}
    for gangId, gang in pairs(GangCache) do
        table.insert(Leaderboards.kills, {
            gangId = gangId,
            name = gang.label,
            value = gang.kills
        })
    end
    table.sort(Leaderboards.kills, function(a, b) return a.value > b.value end)
    
    -- Reputation leaderboard
    Leaderboards.reputation = {}
    for gangId, gang in pairs(GangCache) do
        table.insert(Leaderboards.reputation, {
            gangId = gangId,
            name = gang.label,
            value = gang.reputation
        })
    end
    table.sort(Leaderboards.reputation, function(a, b) return a.value > b.value end)
end

-- Auto update leaderboards
CreateThread(function()
    while true do
        Wait(Config.Leaderboard.updateInterval)
        UpdateLeaderboards()
    end
end)

-- Weekly reset
CreateThread(function()
    while true do
        Wait(3600000) -- Check every hour
        
        local date = os.date('*t')
        if date.wday == Config.Leaderboard.weeklyResetDay and date.hour == 0 then
            -- Save to history
            local week = os.date('%W')
            local year = os.date('%Y')
            
            for category, leaderboard in pairs(Leaderboards) do
                for position, data in ipairs(leaderboard) do
                    if position <= 3 then
                        MySQL.insert('INSERT INTO leaderboard_history (week, year, gang_id, category, position, value) VALUES (?, ?, ?, ?, ?, ?)', {
                            week, year, data.gangId, category, position, data.value
                        })
                        
                        -- Give rewards
                        local reward = Config.Leaderboard.weeklyRewards[position]
                        if reward then
                            local gang = GangCache[data.gangId]
                            if gang then
                                gang.balance = gang.balance + reward.money
                                AddReputation(data.gangId, reward.reputation)
                                MySQL.update('UPDATE gangs SET balance = ? WHERE id = ?', {gang.balance, data.gangId})
                                
                                -- Notify gang
                                for _, member in ipairs(gang.members) do
                                    local Player = QBCore.Functions.GetPlayerByCitizenId(member.identifier)
                                    if Player then
                                        NotifyPlayer(Player.PlayerData.source, 
                                            string.format('Weekly reward: #%d in %s! +$%d +%d Rep', 
                                                position, category, reward.money, reward.reputation
                                            ),
                                            'success'
                                        )
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            -- Reset weekly stats (optional)
            -- MySQL.update('UPDATE gangs SET kills = 0, deaths = 0', {})
        end
    end
end)

RegisterNetEvent('gang:server:getLeaderboards', function()
    local src = source
    UpdateLeaderboards()
    TriggerClientEvent('gang:client:receiveLeaderboards', src, Leaderboards)
end)

RegisterNetEvent('gang:server:getLeaderboardHistory', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local gang = GetPlayerGang(Player.PlayerData.citizenid)
    if not gang then return end
    
    local history = MySQL.query.await('SELECT * FROM leaderboard_history WHERE gang_id = ? ORDER BY year DESC, week DESC LIMIT 20', {gang.id})
    TriggerClientEvent('gang:client:receiveLeaderboardHistory', src, history)
end)

-- Initialize leaderboards on start
CreateThread(function()
    Wait(5000)
    UpdateLeaderboards()
end)