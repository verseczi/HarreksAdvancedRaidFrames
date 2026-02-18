local _, NS = ...
local Data = NS.Data
local Ui = NS.Ui
local Util = NS.Util
local Core = NS.Core
local API = NS.API
local SavedIndicators = HARFDB.savedIndicators
local Options = HARFDB.options

function Core.ParseRestorationDruidBuffs(unit, updateInfo)
    local unitAuras = Data.state.auras[unit]
    local state = Data.state
    local currentTime = GetTime()
    if updateInfo.addedAuras then
        for _, aura in ipairs(updateInfo.addedAuras) do
            if Util.IsAuraFromPlayer(unit, aura.auraInstanceID) and unitAuras[aura.auraInstanceID] == 'Rejuvenation' then
                if Util.AreTimestampsEqual(currentTime, state.casts[33763]) then
                    unitAuras[aura.auraInstanceID] = 'Lifebloom'
                end
            end
        end
    end
end

--PENDING ISSUES FOR PRES TODO:
--Lifebind+VerdantEmbrace and DreamBreath+EchoDreamBreath are handled manually assuming application order and a certain time window
--This means the buffs will be 'wrong' for 0.1 seconds before getting re-checked. The amount of time can be lowered down but that risk miss matches
--Need to investigate if db is always a very short amount regardless of distance and if there is a better way to track the first application for any VE buff
function Core.ParsePreservationEvokerBuffs(unit, updateInfo)
    local unitAuras = Data.state.auras[unit]
    local state = Data.state

    --Pres handles separate lists to parse buffs
    if not state.extras.echo then state.extras.echo = {} end
    if not state.extras.db then state.extras.db = {} end
    if not state.extras.ve then state.extras.ve = {} end

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
                if unitAuras[aura.auraInstanceID] == 'DreamBreath' and state.extras.db[unit] and state.extras.db[unit].pending then
                    local dbTable = state.extras.db[unit]
                    --We check if this unit is preparing to parse its dbs
                    if dbTable and dbTable.pending then
                        --If this unit had its echo consumed, we insert the dbs in the table for later parsing
                        table.insert(dbTable.dbs, aura.auraInstanceID)
                        --If we haven't already, we start a timer to check the dbs after 0.2s
                        if not dbTable.timer then
                            C_Timer.After(0.1, function()
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
                            end)
                            state.extras.db[unit].timer = true
                        end
                    end
                elseif unitAuras[aura.auraInstanceID] == 'VerdantEmbrace' then
                    if not state.extras.ve[unit] then state.extras.ve[unit] = { pending = false, buffs = {}, timer = false } end
                    local veTable = state.extras.ve[unit]
                    table.insert(veTable.buffs, aura.auraInstanceID)
                    if not veTable.timer then
                        C_Timer.After(0.1, function()
                            veTable.timer = false
                            if #veTable.buffs == 2 then
                                unitAuras[veTable.buffs[1]] = 'Lifebind'
                            else
                                if UnitIsUnit(unit, 'player') then
                                    unitAuras[veTable.buffs[1]] = 'Lifebind'
                                end
                            end
                            wipe(veTable.buffs)
                            Util.UpdateIndicatorsForUnit(unit)
                        end)
                    end
                end
            end
        end
    end

    --Save the echoes
    for instanceId, aura in pairs(unitAuras) do
        if aura == 'Echo' and not state.extras.echo[unit] then
            state.extras.echo[unit] = instanceId
        end
    end

end

--PENDING ISSUES FOR HPAL TODO:
-- Armaments is wonky because of the travel time, i expect to see errors when you cast both charges back to back
function Core.ParseHolyPaladinBuffs(unit, updateInfo)
    local unitAuras = Data.state.auras[unit]

    if updateInfo.addedAuras then
        for _, aura in ipairs(updateInfo.addedAuras) do
            if Util.IsAuraFromPlayer(unit, aura.auraInstanceID) then
                if unitAuras[aura.auraInstanceID] == 'SacredWeapon' then
                    local castedSpell = C_Spell.GetSpellTexture(375576) == 5927637 and 'HolyBulwark' or 'SacredWeapon'
                    print(castedSpell)
                    if UnitIsUnit(unit, 'player') then
                        unitAuras[aura.auraInstanceID] = castedSpell
                    else
                        --This will fail if the unit is too far away and you press the spell before it lands, leaving it as a stub
                        unitAuras[aura.auraInstanceID] = castedSpell
                    end
                end
            end
        end
    end
    --[[
    --If this is the player, we save the armament buffs of to check if they were recently added down below
    if isPlayer then
        for instanceId, buff in pairs(unitAuras) do
            if buff == 'HolyBulwark' or buff == 'SacredWeapon' then
                table.insert(playerArmamentBuffs, instanceId)
            end
        end
    end

    if updateInfo.addedAuras then
        local lastCastTime = state.casts[state.lastCast]
        for _, aura in ipairs(updateInfo.addedAuras) do
            local pointCount = #aura.points
            --Same as PI, virtue gets lost in the initial filter because its not in raid in combat
            if state.lastCast == specData.virtue and Util.AreTimestampsEqual(currentTime, lastCastTime)
            and Util.DoesAuraPassRaidFilter(unit, aura.auraInstanceID) and Util.DoesAuraDifferBetweenFilters(unit, aura.auraInstanceID) then
                if pointCount == specData.auras.BeaconOfVirtue then
                    unitAuras[aura.auraInstanceID] = 'BeaconOfVirtue'
                end
            end
            if state.lastCast == specData.armaments and not isPlayer and Util.AreTimestampsEqual(currentTime, lastCastTime, 2) then --2 seconds is insanity wtf
                if Util.IsAuraFromPlayer(unit, aura.auraInstanceID) and pointCount == specData.auras.SacredWeapon then --both arms have the same count
                    unitAuras[aura.auraInstanceID] = Core.IdentifyHolyArmaments()
                end
            end
            --If the player has armaments, check if they were added in this run by the gen function, if they were confirm they are correctly marked
            if isPlayer and #playerArmamentBuffs > 0 then
                for _, instanceId in pairs(playerArmamentBuffs) do
                    if aura.auraInstanceID == instanceId then
                        unitAuras[instanceId] = Core.IdentifyHolyArmaments()
                    end
                end
            end
            --Other buffs that got all the way here and have 7 points have to be beacon of the savior
            if pointCount == 7 and not unitAuras[aura.auraInstanceID] then
                unitAuras[aura.auraInstanceID] = 'BeaconOfTheSavior'
            end
        end
    end
    ]]
end

--Check data of UNIT_AURA to update its status
function Core.UpdateAuraStatus(unit, updateInfo)
    local state = Data.state
    if not updateInfo then updateInfo = {} end

    --lets try to init the auras on this unit
    if not state.auras[unit] then
        state.auras[unit] = {}
        local auras = C_UnitAuras.GetUnitAuras(unit, 'PLAYER|HELPFUL')
        for _, aura in ipairs(auras) do
            state.auras[unit][aura.auraInstanceID] = Util.MatchAuraInfo(unit, aura)
        end
    end

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
        for _, aura in ipairs(updateInfo.addedAuras) do
            if Util.IsAuraFromPlayer(unit, aura.auraInstanceID) and not state.auras[unit][aura.auraInstanceID] then
                state.auras[unit][aura.auraInstanceID] = Util.MatchAuraInfo(unit, aura)
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