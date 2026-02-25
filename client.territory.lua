local QBCore = exports['qb-core']:GetCoreObject()
local TerritoryBlips = {}
local CaptureBlips = {}
local InTerritory = false
local CurrentTerritory = nil

-- Initialize territories
CreateThread(function()
    Wait(2000)
    CreateTerritoryBlips()
    TriggerServerEvent('gang:server:getTerritories')
end)

-- Create territory blips
function CreateTerritoryBlips()
    for _, territory in ipairs(Config.Territories) do
        local blip = AddBlipForRadius(territory.coords.x, territory.coords.y, territory.coords.z, territory.radius)
        SetBlipRotation(blip, 0)
        SetBlipColour(blip, territory.blip.color)
        SetBlipAlpha(blip, 128)
        
        local blipMarker = AddBlipForCoord(territory.coords.x, territory.coords.y, territory.coords.z)
        SetBlipSprite(blipMarker, territory.blip.sprite)
        SetBlipDisplay(blipMarker, 4)
        SetBlipScale(blipMarker, territory.blip.scale)
        SetBlipColour(blipMarker, territory.blip.color)
        SetBlipAsShortRange(blipMarker, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(territory.name)
        EndTextCommandSetBlipName(blipMarker)
        
        TerritoryBlips[territory.name] = {
            radius = blip,
            marker = blipMarker
        }
    end
end

-- Check player in territory
CreateThread(function()
    while true do
        Wait(1000)
        
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local inAnyTerritory = false
        
        for _, territory in ipairs(Config.Territories) do
            local distance = #(playerCoords - territory.coords)
            
            if distance <= territory.radius then
                inAnyTerritory = true
                if CurrentTerritory ~= territory.name then
                    CurrentTerritory = territory.name
                    InTerritory = true
                    QBCore.Functions.Notify('Entered ' .. territory.name, 'primary')
                    ShowTerritoryInfo(territory)
                end
                break
            end
        end
        
        if not inAnyTerritory and InTerritory then
            InTerritory = false
            CurrentTerritory = nil
        end
    end
end)

-- Show territory info
function ShowTerritoryInfo(territory)
    TriggerServerEvent('gang:server:getTerritories')
end

-- Receive territories data
RegisterNetEvent('gang:client:receiveTerritories', function(territories)
    -- Update territory blip colors based on ownership
    for _, territoryData in ipairs(territories) do
        if TerritoryBlips[territoryData.territory_name] then
            local color = territoryData.gang_id and 1 or 2  -- Red if owned, Green if available
            SetBlipColour(TerritoryBlips[territoryData.territory_name].marker, color)
        end
    end
end)

-- Territory capture UI
CreateThread(function()
    while true do
        Wait(0)
        
        if InTerritory and CurrentTerritory then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            
            for _, territory in ipairs(Config.Territories) do
                if territory.name == CurrentTerritory then
                    -- Draw marker
                    DrawMarker(1, territory.coords.x, territory.coords.y, territory.coords.z - 1.0, 
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                        territory.radius * 2, territory.radius * 2, 1.0, 
                        0, 255, 0, 50, false, true, 2, false, nil, nil, false)
                    
                    local distance = #(playerCoords - territory.coords)
                    if distance < 5.0 then
                        QBCore.Functions.DrawText3D(territory.coords.x, territory.coords.y, territory.coords.z + 1.0, 
                            '[E] Capture Territory')
                        
                        if IsControlJustReleased(0, 38) then -- E key
                            TriggerServerEvent('gang:server:startCapture', territory.name)
                        end
                    end
                    break
                end
            end
        else
            Wait(500)
        end
    end
end)

-- Capture events
RegisterNetEvent('gang:client:startCapture', function(territoryName, gangId, gangLabel, duration)
    QBCore.Functions.Notify(gangLabel .. ' is capturing ' .. territoryName .. '!', 'primary', duration * 1000)
    
    -- Create capture blip
    for _, territory in ipairs(Config.Territories) do
        if territory.name == territoryName then
            local blip = AddBlipForCoord(territory.coords.x, territory.coords.y, territory.coords.z)
            SetBlipSprite(blip, 486)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, 1.2)
            SetBlipColour(blip, 1)
            SetBlipFlashes(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName('CAPTURING: ' .. territoryName)
            EndTextCommandSetBlipName(blip)
            
            CaptureBlips[territoryName] = blip
            
            -- Remove after duration
            SetTimeout(duration * 1000, function()
                RemoveBlip(blip)
                CaptureBlips[territoryName] = nil
            end)
            break
        end
    end
end)

RegisterNetEvent('gang:client:captureSuccess', function(territoryName, gangId, gangLabel)
    QBCore.Functions.Notify(gangLabel .. ' captured ' .. territoryName .. '!', 'success')
    
    -- Remove capture blip
    if CaptureBlips[territoryName] then
        RemoveBlip(CaptureBlips[territoryName])
        CaptureBlips[territoryName] = nil
    end
    
    -- Update territory blip color
    if TerritoryBlips[territoryName] then
        SetBlipColour(TerritoryBlips[territoryName].marker, 1) -- Red for owned
    end
end)

RegisterNetEvent('gang:client:captureCancelled', function(territoryName)
    QBCore.Functions.Notify('Territory capture cancelled!', 'error')
    
    if CaptureBlips[territoryName] then
        RemoveBlip(CaptureBlips[territoryName])
        CaptureBlips[territoryName] = nil
    end
end)

RegisterNetEvent('gang:client:captureDefended', function(territoryName, gangLabel)
    QBCore.Functions.Notify(gangLabel .. ' defended ' .. territoryName .. '!', 'error')
    
    if CaptureBlips[territoryName] then
        RemoveBlip(CaptureBlips[territoryName])
        CaptureBlips[territoryName] = nil
    end
end)

RegisterNetEvent('gang:client:territoryAvailable', function(territoryName)
    QBCore.Functions.Notify(territoryName .. ' is now available for capture!', 'success')
    
    -- Update blip color
    if TerritoryBlips[territoryName] then
        SetBlipColour(TerritoryBlips[territoryName].marker, 2) -- Green for available
    end
end)

RegisterNetEvent('gang:client:updateTerritories', function()
    TriggerServerEvent('gang:server:getTerritories')
end)