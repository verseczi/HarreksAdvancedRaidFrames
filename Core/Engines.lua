local _, NS = ...
local Data = NS.Data
local Ui = NS.Ui
local Util = NS.Util
local Core = NS.Core
local SavedIndicators = HARFDB.savedIndicators
local Options = HARFDB.options

--This is fairly easy, if we ever get here the unit had an echo consumed by db
--They are guaranteed to get an echoed db, and if they get a normal one it would apply first
function Core.IdentifyDreamBreaths(unit)
    local unitAuras = Data.state.auras[unit]
    local dbTable = Data.state.extras.db[unit]
    dbTable.timer = false
    dbTable.pending = false
    if #dbTable.dbs == 2 then
        unitAuras[dbTable.dbs[1]] = 'DreamBreath'
        unitAuras[dbTable.dbs[2]] = 'EchoDreamBreath'
    else
        unitAuras[dbTable.dbs[1]] = 'EchoDreamBreath'
    end
    wipe(dbTable.dbs)
    Util.UpdateIndicatorsForUnit(unit)
end

--PENDING ISSUES FOR DRUID TODO:
-- Spellqueueing Barkskin off of WildGrowth will mark the WildGrowths as Barkskins
function Core.ParseRestorationDruidBuffs(unit, updateInfo)
    local unitAuras = Data.state.auras[unit]
    local state = Data.state
    --Convoke will apply WildGrowth, Regrowth and Rejuv with no cast events, but we can diff those using points
    if updateInfo.addedAuras and state.extras.isConvoking then
        for _, aura in ipairs(updateInfo.addedAuras) do
            if Util.IsAuraFromPlayer(unit, aura.auraInstanceID) then
                local pointCount = #aura.points
                if pointCount == 1 then
                    unitAuras[aura.auraInstanceID] = 'Rejuvenation'
                elseif pointCount == 2 then
                    unitAuras[aura.auraInstanceID] = 'WildGrowth'
                elseif pointCount == 3 then
                    unitAuras[aura.auraInstanceID] = 'Regrowth'
                end
            end
        end
    end

    --One of the resto druid issues is separating rejuv from germ. We do that here
    for instanceId, aura in pairs(unitAuras) do
        if aura == 'Rejuvenation' then
            if Util.DoesAuraDifferBetweenFilters(unit, instanceId) then
                unitAuras[instanceId] = 'Germination'
            end
        end
    end
end

--PENDING ISSUES FOR PRES TODO:
-- Sending a flying TA and immediately dreamflying will cause the echoes from TA to get marked as dreamflight hots
-- The current dreamflight landing detecting is just a 2 seconds timer (this sucks)
function Core.ParsePreservationEvokerBuffs(unit, updateInfo)
    local unitAuras = Data.state.auras[unit]
    local currentTime = GetTime()
    local state = Data.state
    local lastCastTime = state.casts[state.lastCast]

    --Pres handles separate lists to parse db
    if not state.extras.echo then state.extras.echo = {} end
    if not state.extras.db then state.extras.db = {} end
    --If we have this unit saved as having echo beforehand we check if it was removed
    if state.extras.echo[unit] and updateInfo.removedAuraInstanceIDs then
        for _, removedAuraId in ipairs(updateInfo.removedAuraInstanceIDs) do
            --If echo was removed, we init this units table in the dbs to parse later
            if state.extras.echo[unit] == removedAuraId then
                state.extras.db[unit] = { dbs = {}, timer = false, pending = true }
                state.extras.echo[unit] = nil
                break
            end
        end
    end

    if updateInfo.addedAuras then
        for _, aura in ipairs(updateInfo.addedAuras) do
            if Util.IsAuraFromPlayer(unit, aura.auraInstanceID) then
                local pointCount = #aura.points
                --This count can cause issues for auras not from casts
                if pointCount == 2 and not Util.AreTimestampsEqual(currentTime, lastCastTime) then
                    --If we are dreamflying, we assume these are dreamflight hots
                    if state.extras.dreamflight then
                        state.auras[unit][aura.auraInstanceID] = 'DreamFlight'
                    else
                        --Otherwise these have to be echoes from a flying TA
                        state.auras[unit][aura.auraInstanceID] = 'Echo'
                    end
                --If this is a dream breath
                elseif pointCount == 3 and state.lastCast == 'DreamBreath' and Util.AreTimestampsEqual(currentTime, lastCastTime) then
                    --We check if this unit is preparing to parse its dbs
                    if state.extras.db[unit] and state.extras.db[unit].pending then
                        --If this unit had its echo consumed, we insert the dbs in the table for later parsing
                        table.insert(state.extras.db[unit].dbs, aura.auraInstanceID)
                        --If we haven't already, we start a timer to check the dbs after 0.2s
                        if not state.extras.db[unit].timer then
                            C_Timer.After(0.1, function() Core.IdentifyDreamBreaths(unit) end)
                            state.extras.db[unit].timer = true
                        end
                    else
                        --If the unit is not waiting to parse then they didn't had an echo before this application, so this is a normal db
                        state.auras[unit][aura.auraInstanceID] = 'DreamBreath'
                    end
                end
            end
        end
    end

    --Gen function might put several reversions on the same unit when there is echoes
    for instanceId, aura in pairs(unitAuras) do
        if aura == 'Reversion' then
            if Util.DoesAuraDifferBetweenFilters(unit, instanceId) then
                unitAuras[instanceId] = 'EchoReversion'
            end
        elseif aura == 'Echo' and not state.extras.echo[unit] then
            state.extras.echo[unit] = instanceId
        end
    end

end

--Check data of UNIT_AURA to update its status
function Core.UpdateAuraStatus(unit, updateInfo)
    local specInfo = Data.specInfo[Data.playerSpec]
    local currentTime = GetTime()
    local state = Data.state
    if not state.auras[unit] then state.auras[unit] = {} end
    if not updateInfo then updateInfo = {} end

    --If an auraInstanceID that we have saved has been removed, get it away
    if updateInfo.removedAuraInstanceIDs then
        local currentUnitAuras = state.auras[unit]
        if currentUnitAuras then
            for _, auraId in ipairs(updateInfo.removedAuraInstanceIDs) do
                if currentUnitAuras[auraId] then
                    currentUnitAuras[auraId] = nil
                end
            end
        end
    end

    --If the unit got new auras added, check if they came from a cast
    if updateInfo.addedAuras then
        local lastCastTime = state.casts[state.lastCast]
        --If these auras match a spell cast
        if lastCastTime and Util.AreTimestampsEqual(currentTime, lastCastTime) then
            --Get the buffs this cast can apply
            local castBuffs = specInfo.casts[state.lastCast]
            for _, aura in ipairs(updateInfo.addedAuras) do
                local pointCount = #aura.points
                for _, buff in ipairs(castBuffs) do
                    if Util.IsAuraFromPlayer(unit, aura.auraInstanceID) and pointCount == specInfo.auras[buff] then
                        state.auras[unit][aura.auraInstanceID] = buff
                        break
                    end
                end
            end
        end
    end

    --We pass the data to specialized functions
    local engineFunction = Data.engineFunctions[Data.playerSpec]
    if engineFunction then
        engineFunction(unit, updateInfo)
    end

    --Hit a refresh of the indicators at the end
    Util.UpdateIndicatorsForUnit(unit)
end