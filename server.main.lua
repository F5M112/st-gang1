local QBCore = exports['qb-core']:GetCoreObject()

-- Cache
GangCache = {}
PlayerGangs = {}

-- Initialize
CreateThread(function()
    Wait(1000)
    LoadAllGangs()
    StartPassiveIncomeThread()
    StartTerritoryThread()
end)

-- Load all gangs into cache
function LoadAllGangs()
    local result = MySQL.query.await('SELECT * FROM gangs', {})
    if result then
        for _, gang in ipairs(result) do
            GangCache[gang.id] = {
                id = gang.id,
                name = gang.name,
                label = gang.label,
                leader = gang.leader,
                balance = gang.balance,
                level = gang.level,
                reputation = gang.reputation,
                kills = gang.kills,
                deaths = gang.deaths,
                vault_coords = json.decode(gang.vault_coords),
                upgrades = gang.upgrades and json.decode(gang.upgrades) or {},
                members = {}
            }
        end
    end
    
    -- Load members
    local members = MySQL.query.await('SELECT * FROM gang_members', {})
    if members then
        for _, member in ipairs(members) do
            if GangCache[member.gang_id] then
                table.insert(GangCache[member.gang_id].members, {
                    identifier = member.identifier,
                    rank = member.rank,
                    joined_at = member.joined_at
                })
                PlayerGangs[member.identifier] = member.gang_id
            end
        end
    end
    
    print('^2[Gang System]^7 Loaded ' .. #result .. ' gangs')
end

-- Get player gang
function GetPlayerGang(identifier)
    local gangId = PlayerGangs[identifier]
    if gangId then
        return GangCache[gangId]
    end
    return nil
end

-- Get player rank in gang
function GetPlayerRankInGang(identifier, gangId)
    local gang = GangCache[gangId]
    if gang then
        for _, member in ipairs(gang.members) do
            if member.identifier == identifier then
                return member.rank
            end
        end
    end
    return nil
end

-- Check if player is mafia
function IsMafia(identifier)
    for _, mafiaId in ipairs(Config.MafiaIdentifiers) do
        if identifier == mafiaId then
            return true
        end
    end
    return false
end

-- Notify player
function NotifyPlayer(source, message, type)
    TriggerClientEvent('QBCore:Notify', source, message, type or 'primary')
end

-- Add reputation
function AddReputation(gangId, amount)
    if GangCache[gangId] then
        GangCache[gangId].reputation = GangCache[gangId].reputation + amount
        MySQL.update('UPDATE gangs SET reputation = ? WHERE id = ?', {
            GangCache[gangId].reputation,
            gangId
        })
        
        -- Check level up
        CheckGangLevelUp(gangId)
    end
end

-- Check gang level up
function CheckGangLevelUp(gangId)
    local gang = GangCache[gangId]
    if gang then
        local requiredRep = gang.level * 1000
        if gang.reputation >= requiredRep and gang.level < Config.MaxGangLevel then
            gang.level = gang.level + 1
            gang.reputation = gang.reputation - requiredRep
            MySQL.update('UPDATE gangs SET level = ?, reputation = ? WHERE id = ?', {
                gang.level,
                gang.reputation,
                gangId
            })
            
            -- Notify all gang members
            for _, member in ipairs(gang.members) do
                local Player = QBCore.Functions.GetPlayerByCitizenId(member.identifier)
                if Player then
                    NotifyPlayer(Player.PlayerData.source, 'Your gang leveled up to level ' .. gang.level .. '!', 'success')
                end
            end
            
            AddReputation(gangId, Config.Reputation.levelUpBonus)
            AddGangLog(gangId, 'LEVEL_UP', 'Gang reached level ' .. gang.level, 'SYSTEM')
        end
    end
end

-- Add gang log
function AddGangLog(gangId, action, details, creator)
    MySQL.insert('INSERT INTO gang_logs (gang_id, action, details, created_by) VALUES (?, ?, ?, ?)', {
        gangId,
        action,
        details,
        creator
    })
end

-- Passive income thread
function StartPassiveIncomeThread()
    CreateThread(function()
        while true do
            Wait(3600000) -- Every hour
            
            local territories = MySQL.query.await('SELECT * FROM gang_territories WHERE gang_id IS NOT NULL', {})
            if territories then
                for _, territory in ipairs(territories) do
                    local gang = GangCache[territory.gang_id]
                    if gang then
                        -- Find territory config
                        for _, terr in ipairs(Config.Territories) do
                            if terr.name == territory.territory_name then
                                local income = terr.passiveIncome
                                
                                -- Apply upgrades
                                if gang.upgrades.passive_income then
                                    income = income * (1 + gang.upgrades.passive_income / 100)
                                end
                                
                                -- Apply mafia tax
                                local tax = Config.MafiaTax
                                if gang.upgrades.tax_reduction then
                                    tax = tax - gang.upgrades.tax_reduction
                                end
                                
                                local taxAmount = math.floor(income * (tax / 100))
                                local netIncome = income - taxAmount
                                
                                gang.balance = gang.balance + netIncome
                                MySQL.update('UPDATE gangs SET balance = ? WHERE id = ?', {
                                    gang.balance,
                                    territory.gang_id
                                })
                                
                                AddGangLog(territory.gang_id, 'PASSIVE_INCOME', 
                                    string.format('Received $%d from %s (Tax: $%d)', netIncome, territory.territory_name, taxAmount),
                                    'SYSTEM'
                                )
                                
                                break
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- Territory thread
function StartTerritoryThread()
    CreateThread(function()
        while true do
            Wait(60000) -- Every minute
            TriggerClientEvent('gang:client:updateTerritories', -1)
        end
    end)
end

-- Events
RegisterNetEvent('gang:server:requestGangData', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local gang = GetPlayerGang(Player.PlayerData.citizenid)
        TriggerClientEvent('gang:client:receiveGangData', src, gang)
    end
end)

RegisterNetEvent('gang:server:requestAllGangs', function()
    local src = source
    TriggerClientEvent('gang:client:receiveAllGangs', src, GangCache)
end)

-- Exports
exports('GetPlayerGang', GetPlayerGang)
exports('GetPlayerRankInGang', GetPlayerRankInGang)
exports('IsMafia', IsMafia)
exports('AddReputation', AddReputation)
exports('AddGangLog', AddGangLog)