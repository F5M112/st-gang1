local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local PlayerGang = nil
local UIOpen = false

-- Initialize
CreateThread(function()
    Wait(1000)
    PlayerData = QBCore.Functions.GetPlayerData()
    TriggerServerEvent('gang:server:requestGangData')
end)

-- Player loaded
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    TriggerServerEvent('gang:server:requestGangData')
end)

-- Receive gang data
RegisterNetEvent('gang:client:receiveGangData', function(gangData)
    PlayerGang = gangData
end)

-- Key mapping
RegisterCommand('gangmenu', function()
    if not PlayerGang then
        QBCore.Functions.Notify('You are not in a gang!', 'error')
        return
    end
    OpenGangMenu()
end)

RegisterCommand('mafiamenu', function()
    -- Check if mafia
    QBCore.Functions.TriggerCallback('gang:server:isMafia', function(isMafia)
        if isMafia then
            OpenMafiaMenu()
        else
            QBCore.Functions.Notify('Access denied!', 'error')
        end
    end)
end)

RegisterKeyMapping('gangmenu', 'Open Gang Menu', 'keyboard', 'F6')
RegisterKeyMapping('mafiamenu', 'Open Mafia Menu', 'keyboard', 'F7')

-- Open Gang Menu
function OpenGangMenu()
    if UIOpen then return end
    
    UIOpen = true
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        action = 'openMenu',
        type = 'gang',
        data = {
            gang = PlayerGang
        }
    })
end

-- Open Mafia Menu
function OpenMafiaMenu()
    if UIOpen then return end
    
    UIOpen = true
    SetNuiFocus(true, true)
    TriggerServerEvent('mafia:server:getAllGangs')
    TriggerServerEvent('mafia:server:getStatistics')
    
    SendNUIMessage({
        action = 'openMenu',
        type = 'mafia'
    })
end

-- Receive all gangs (Mafia)
RegisterNetEvent('mafia:client:receiveAllGangs', function(gangs)
    SendNUIMessage({
        action = 'updateGangs',
        data = gangs
    })
end)

-- Receive statistics (Mafia)
RegisterNetEvent('mafia:client:receiveStatistics', function(stats)
    SendNUIMessage({
        action = 'updateStatistics',
        data = stats
    })
end)

-- NUI Callbacks
RegisterNUICallback('closeMenu', function(data, cb)
    UIOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('inviteMember', function(data, cb)
    local playerId = tonumber(data.playerId)
    if playerId then
        TriggerServerEvent('gang:server:inviteMember', playerId)
    end
    cb('ok')
end)

RegisterNUICallback('kickMember', function(data, cb)
    TriggerServerEvent('gang:server:kickMember', data.identifier)
    cb('ok')
end)

RegisterNUICallback('leaveGang', function(data, cb)
    TriggerServerEvent('gang:server:leaveGang')
    PlayerGang = nil
    cb('ok')
end)

RegisterNUICallback('deposit', function(data, cb)
    local amount = tonumber(data.amount)
    if amount and amount > 0 then
        TriggerServerEvent('gang:server:depositMoney', amount)
    end
    cb('ok')
end)

RegisterNUICallback('withdraw', function(data, cb)
    local amount = tonumber(data.amount)
    if amount and amount > 0 then
        TriggerServerEvent('gang:server:withdrawMoney', amount)
    end
    cb('ok')
end)

RegisterNUICallback('setVaultLocation', function(data, cb)
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('gang:server:setVaultLocation', {x = coords.x, y = coords.y, z = coords.z})
    cb('ok')
end)

RegisterNUICallback('declareWar', function(data, cb)
    TriggerServerEvent('gang:server:declareWar', tonumber(data.gangId))
    cb('ok')
end)

RegisterNUICallback('acceptWar', function(data, cb)
    TriggerServerEvent('gang:server:acceptWar', tonumber(data.warId))
    cb('ok')
end)

RegisterNUICallback('declineWar', function(data, cb)
    TriggerServerEvent('gang:server:declineWar', tonumber(data.warId))
    cb('ok')
end)

RegisterNUICallback('purchaseUpgrade', function(data, cb)
    TriggerServerEvent('gang:server:purchaseUpgrade', data.upgradeType, tonumber(data.level))
    cb('ok')
end)

RegisterNUICallback('startCapture', function(data, cb)
    TriggerServerEvent('gang:server:startCapture', data.territoryName)
    cb('ok')
end)

-- Mafia callbacks
RegisterNUICallback('createGang', function(data, cb)
    TriggerServerEvent('gang:server:createGang', data.name, data.label, data.leaderIdentifier)
    cb('ok')
end)

RegisterNUICallback('deleteGang', function(data, cb)
    TriggerServerEvent('gang:server:deleteGang', tonumber(data.gangId))
    cb('ok')
end)

RegisterNUICallback('changeLeader', function(data, cb)
    TriggerServerEvent('gang:server:changeLeader', tonumber(data.gangId), data.newLeaderIdentifier)
    cb('ok')
end)

RegisterNUICallback('setTax', function(data, cb)
    TriggerServerEvent('mafia:server:setGangTax', tonumber(data.tax))
    cb('ok')
end)

RegisterNUICallback('withdrawFromGang', function(data, cb)
    TriggerServerEvent('mafia:server:withdrawFromGang', tonumber(data.gangId), tonumber(data.amount))
    cb('ok')
end)

RegisterNUICallback('resetGang', function(data, cb)
    TriggerServerEvent('mafia:server:resetGang', tonumber(data.gangId))
    cb('ok')
end)

RegisterNUICallback('giveMoneyToGang', function(data, cb)
    TriggerServerEvent('mafia:server:giveMoneyToGang', tonumber(data.gangId), tonumber(data.amount))
    cb('ok')
end)

RegisterNUICallback('startTerritoryEvent', function(data, cb)
    TriggerServerEvent('mafia:server:startTerritoryEvent', data.territoryName)
    cb('ok')
end)

RegisterNUICallback('forceEndWar', function(data, cb)
    TriggerServerEvent('mafia:server:forceEndWar', tonumber(data.warId))
    cb('ok')
end)

RegisterNUICallback('getGangLogs', function(data, cb)
    TriggerServerEvent('mafia:server:getGangLogs', tonumber(data.gangId))
    cb('ok')
end)

-- Receive gang logs
RegisterNetEvent('mafia:client:receiveGangLogs', function(logs)
    SendNUIMessage({
        action = 'updateLogs',
        data = logs
    })
end)

-- Receive invite
RegisterNetEvent('gang:client:receiveInvite', function(gangId, gangLabel, inviterSource)
    QBCore.Functions.Notify(gangLabel .. ' invited you to join!', 'primary', 10000)
    
    exports['qb-menu']:openMenu({
        {
            header = 'Gang Invite',
            txt = 'Join ' .. gangLabel .. '?',
            params = {
                event = 'gang:client:acceptInvite',
                args = {gangId = gangId, inviterSource = inviterSource}
            }
        },
        {
            header = 'Decline',
            txt = 'Decline the invitation',
            params = {
                event = 'gang:client:closeMenu'
            }
        }
    })
end)

RegisterNetEvent('gang:client:acceptInvite', function(data)
    TriggerServerEvent('gang:server:acceptInvite', data.gangId, data.inviterSource)
    exports['qb-menu']:closeMenu()
end)

RegisterNetEvent('gang:client:closeMenu', function()
    exports['qb-menu']:closeMenu()
end)

-- Vault interaction
CreateThread(function()
    while true do
        Wait(0)
        
        if PlayerGang and PlayerGang.vault_coords then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local vaultCoords = vector3(PlayerGang.vault_coords.x, PlayerGang.vault_coords.y, PlayerGang.vault_coords.z)
            local distance = #(playerCoords - vaultCoords)
            
            if distance < 10.0 then
                DrawMarker(27, vaultCoords.x, vaultCoords.y, vaultCoords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 1.0, 0, 255, 0, 100, false, true, 2, false, nil, nil, false)
                
                if distance < 2.0 then
                    QBCore.Functions.DrawText3D(vaultCoords.x, vaultCoords.y, vaultCoords.z, '[E] Gang Vault')
                    
                    if IsControlJustReleased(0, 38) then
                        OpenGangMenu()
                    end
                end
            end
        else
            Wait(1000)
        end
    end
end)

-- Death handler for war kills
AddEventHandler('gameEventTriggered', function(event, data)
    if event == 'CEventNetworkEntityDamage' then
        local victim = data[1]
        local attacker = data[2]
        
        if victim == PlayerPedId() and IsPedAPlayer(attacker) then
            local attackerId = NetworkGetPlayerIndexFromPed(attacker)
            if attackerId then
                local attackerServerId = GetPlayerServerId(attackerId)
                if attackerServerId then
                    TriggerServerEvent('gang:server:warKill', attackerServerId)
                end
            end
        end
    end
end)