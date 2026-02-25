-- WAR CLIENT SCRIPT
local QBCore = exports['qb-core']:GetCoreObject()
local ActiveWars = {}

-- Receive war request
RegisterNetEvent('gang:client:receiveWarRequest', function(warId, attackerLabel)
    QBCore.Functions.Notify(attackerLabel .. ' declared war on your gang!', 'error', 10000)
    
    exports['qb-menu']:openMenu({
        {
            header = 'War Declaration',
            txt = attackerLabel .. ' wants to start a war!',
            params = {
                event = 'gang:client:acceptWarMenu',
                args = {warId = warId}
            }
        },
        {
            header = 'Accept War',
            txt = 'Accept the war challenge',
            params = {
                event = 'gang:client:confirmAcceptWar',
                args = {warId = warId}
            }
        },
        {
            header = 'Decline War',
            txt = 'Decline the war',
            params = {
                event = 'gang:client:confirmDeclineWar',
                args = {warId = warId}
            }
        }
    })
end)

RegisterNetEvent('gang:client:confirmAcceptWar', function(data)
    TriggerServerEvent('gang:server:acceptWar', data.warId)
    exports['qb-menu']:closeMenu()
end)

RegisterNetEvent('gang:client:confirmDeclineWar', function(data)
    TriggerServerEvent('gang:server:declineWar', data.warId)
    exports['qb-menu']:closeMenu()
end)

-- War started
RegisterNetEvent('gang:client:warStarted', function(warId, attackerLabel, defenderLabel, duration)
    QBCore.Functions.Notify('WAR STARTED: ' .. attackerLabel .. ' vs ' .. defenderLabel, 'error', 5000)
    
    ActiveWars[warId] = {
        attacker = attackerLabel,
        defender = defenderLabel,
        startTime = GetGameTimer(),
        duration = duration
    }
    
    -- Show war HUD
    CreateThread(function()
        while ActiveWars[warId] do
            Wait(0)
            
            local war = ActiveWars[warId]
            local timeLeft = math.max(0, war.duration - (GetGameTimer() - war.startTime) / 1000)
            
            if timeLeft > 0 then
                DrawAdvancedText(0.5, 0.02, 0.005, 0.0028, 0.5, 
                    string.format('~r~WAR: ~w~%s ~r~vs~w~ %s | ~y~Time: %02d:%02d', 
                        war.attacker, war.defender, 
                        math.floor(timeLeft / 60), math.floor(timeLeft % 60)),
                    255, 255, 255, 255, 4, 0)
            else
                ActiveWars[warId] = nil
            end
        end
    end)
end)

-- Update war kills
RegisterNetEvent('gang:client:updateWarKills', function(warId, attackerKills, defenderKills)
    if ActiveWars[warId] then
        ActiveWars[warId].attackerKills = attackerKills
        ActiveWars[warId].defenderKills = defenderKills
        
        QBCore.Functions.Notify(string.format('War Score: %d - %d', attackerKills, defenderKills), 'primary')
    end
end)

-- War ended
RegisterNetEvent('gang:client:warEnded', function(warId, winnerLabel)
    if ActiveWars[warId] then
        if winnerLabel and winnerLabel ~= '' then
            QBCore.Functions.Notify(winnerLabel .. ' won the war!', 'success', 5000)
        else
            QBCore.Functions.Notify('War ended in a draw!', 'primary', 5000)
        end
        
        ActiveWars[warId] = nil
    end
end)

-- Helper function for advanced text drawing
function DrawAdvancedText(x, y, w, h, scale, text, r, g, b, a, font, jus)
    SetTextFont(font)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextJustification(jus)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x - w / 2, y - h / 2 + 0.005)
end