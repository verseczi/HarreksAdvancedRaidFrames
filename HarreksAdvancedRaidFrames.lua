--[[----------------------------------
    Utilities
------------------------------------]]

--Initialize default data
local gameVersion = select(4, GetBuildInfo())
local currentLayout = nil
local unitFrameMap = {}
local playerClass = nil
local supportedBuffTracking = {
    SHAMAN = {
        spell = 'Riptide',
        utility = {
            earthShield = nil
        }
    },
    EVOKER = {
        spell = 'Echo',
        utility = {
            filteredSpellTimestamp = nil,
            filteredSpells = {
                [366155] = true,
                [1256581] = true,
                [374227] = true,
                [369459] = true
            },
            filteredBuffs = {}
        }
    },
    PRIEST = {
        spell = 'Atonement',
        utility = {
            isDisc = false,
            filteredSpellTimestamp = nil,
            filteredSpells = {}
        }
    }
}
local spotlightAnchors = {
    spotlights = {},
    defaults = {}
}
local defaultSettings = {
    clickThroughBuffs = true,
    buffIcons = 6,
    debuffIcons = 3,
    frameTransparency = false,
    nameScale = 1,
    colorNames = false,
    buffTracking = false,
    trackingType = 'icon',
    trackingColor = { r = 0, g = 1, b = 0 },
    spotlight = {
        point = 'CENTER',
        x = 0,
        y = 0,
        grow = 'Right',
        names = {}
    }
}

--Build a list of strings that match the default frame elements
local frameList = { party = {}, raid = {} }
for i = 1, 30 do
    local partyFrame, raidFrame
    if i <= 5 then
        partyFrame = 'CompactPartyFrameMember' .. i
        frameList.party[partyFrame] = {
            buffs = {},
            debuffs = {},
            name = partyFrame .. 'Name',
            centerIcon = partyFrame .. 'CenterStatusIcon',
            defensive = { type = 'defensive', frame = partyFrame }
        }
    end
    raidFrame = 'CompactRaidFrame' .. i
    frameList.raid[raidFrame] = {}
    frameList.raid[raidFrame] = {
        buffs = {},
        debuffs = {},
        name = raidFrame .. 'Name',
        centerIcon = raidFrame .. 'CenterStatusIcon',
        defensive = { type = 'defensive', frame = raidFrame }
    }
    for j = 1, 6 do
        if j <= 3 then
            if partyFrame then
                frameList.party[partyFrame].debuffs[j] = partyFrame .. 'Debuff' .. j
            end
            frameList.raid[raidFrame].debuffs[j] = raidFrame .. 'Debuff' .. j
        end
        if partyFrame then
            frameList.party[partyFrame].buffs[j] = partyFrame .. 'Buff' .. j
        end
        frameList.raid[raidFrame].buffs[j] = raidFrame .. 'Buff' .. j
    end
end

--Function to format decimals out for display
local function formatForDisplay(number)
    return math.floor(number * 10 + 0.5) / 10
end

--The addon uses some tables to keep track of unit frames and specific auras, every now and then we empty these tables to remove irrelevant data
--Currently this happens when we remap out frames to new units after a roster update, as the info is tied to a specific player occupying a specific frame
local function CleanUtilityTables()
    unitFrameMap = {}
    supportedBuffTracking.EVOKER.utility.filteredBuffs = {}
end

--Return the list of raid frames depending on raid or party
local function GetRelevantList()
    return IsInRaid() and frameList.raid or frameList.party
end

local function GetSpotlightNames()
    if IsInRaid() then
        local frames = GetRelevantList()
        local raidNameList = {}
        if currentLayout and HARFDB[currentLayout] and HARFDB[currentLayout].spotlight.names then
            for name, _ in pairs(HARFDB[currentLayout].spotlight.names) do
                table.insert(raidNameList, { text = name })
            end
        end
        for frameString, _ in pairs(frames) do
            if _G[frameString] then
                local frame = _G[frameString]
                local unitName = UnitName(frame.unit)
                if not UnitIsUnit(frame.unit, 'player') and not HARFDB[currentLayout].spotlight.names[unitName] then
                    table.insert(raidNameList, { text = unitName })
                end
            end
        end
        return raidNameList
    else
        return HARFDB[currentLayout].spotlight.names
    end
end

local function MapSpotlightAnchors()
    spotlightAnchors = { spotlights = {}, defaults = {} }
    local units = HARFDB[currentLayout].spotlight.names
    local frames = frameList.raid
    for frameString, _ in pairs(frames) do
        if _G[frameString] and _G[frameString].unit then
            local currentFrame = _G[frameString]
            local unit = currentFrame.unit
            if unit ~= 'player' then
                local unitName = UnitName(unit)
                local frameIndex = frameString:gsub('CompactRaidFrame', '')
                if units[unitName] then
                    spotlightAnchors.spotlights[frameIndex] = frameString
                else
                    spotlightAnchors.defaults[frameIndex] = frameString
                end
            end
        end
    end
    for type, list in pairs(spotlightAnchors) do
        local framesIndexes = {}
        for index in pairs(list) do
            table.insert(framesIndexes, tonumber(index))
        end
        table.sort(framesIndexes)
        local orderedFrameList = {}
        local order = 1
        for _, index in ipairs(framesIndexes) do
            orderedFrameList[order] = list[tostring(index)]
            order = order + 1
        end
        spotlightAnchors[type] = orderedFrameList
    end
end

function ReanchorSpotlights()
    for index, frameString in ipairs(spotlightAnchors.spotlights) do
        local frame = _G[frameString]
        frame:ClearAllPoints()
        if index == 1 then
            frame:SetPoint('TOP', 'AdvancedRaidFramesSpotlight', 'TOP')
        else
            local previousFrame = _G[spotlightAnchors.spotlights[index - 1]]
            local childPoint, parentPoint
            if HARFDB[currentLayout].spotlight.grow == 'right' then
                childPoint, parentPoint = 'LEFT', 'RIGHT'
            else
                childPoint, parentPoint = 'TOP', 'BOTTOM'
            end
            frame:SetPoint(childPoint, previousFrame, parentPoint)
        end
    end
    for index, frameString in ipairs(spotlightAnchors.defaults) do
        local frame = _G[frameString]
        frame:ClearAllPoints()
        if index == 1 then
            frame:SetPoint('TOPLEFT', 'CompactRaidFrameContainer', 'TOPLEFT')
        else
            if (index - 1) % 5 == 0 then
                local previousFrame = _G[spotlightAnchors.defaults[index - 5]]
                frame:SetPoint('TOP', previousFrame, 'BOTTOM')
            else
                local previousFrame = _G[spotlightAnchors.defaults[index - 1]]
                frame:SetPoint('LEFT', previousFrame, 'RIGHT')
            end
        end
    end
end

--[[----------------------------------
    Core Functions
------------------------------------]]

--Takes a string, checks global table for frame with that name and changes mouse interaction on it
local function ChangeFrameMouseInteraction(frameString, value)
    local frame
    --Special handling for the center defensive because it doesn't have a direct name to access
    if type(frameString) == 'table' and frameString.type and frameString.type == 'defensive' then
        if _G[frameString.frame] and _G[frameString.frame].CenterDefensiveBuff then
            frame = _G[frameString.frame].CenterDefensiveBuff
        end
    else
        if _G[frameString] then
            frame = _G[frameString]
        end
    end
    if frame and frame:IsMouseEnabled() ~= value then
        frame:EnableMouse(value)
    end
end

--Hides elements by changing opacity
local function ToggleTransparency(frameString, shouldShow)
    if _G[frameString] then
        if shouldShow then
            _G[frameString]:SetAlpha(1)
        else
            _G[frameString]:SetAlpha(0)
        end
    end
end

--Toggles mouse interaction on raid frame icons, pass true for enabled and false for disabled, third param is the elements of the edited frame
local function ToggleAurasMouseInteraction(value, _, elements)
    for _, buff in ipairs(elements.buffs) do
        ChangeFrameMouseInteraction(buff, value)
    end
    for _, debuff in ipairs(elements.debuffs) do
        ChangeFrameMouseInteraction(debuff, value)
    end
    ChangeFrameMouseInteraction(elements.centerIcon, value)
    ChangeFrameMouseInteraction(elements.defensive, value)
end

--Controls visibility on buff icons, takes how many buffs are to be shown and the element list of the frame to be modified
local function ToggleBuffIcons(amount, _, elements)
    for i = 1, 6 do
        if i <= amount then
            ToggleTransparency(elements.buffs[i], true)
            if _G[elements.buffs[i]] and not _G[elements.buffs[i]]:IsMouseEnabled() and not HARFDB[currentLayout].clickThroughBuffs then
                ChangeFrameMouseInteraction(elements.buffs[i], true)
            end
        else
            ToggleTransparency(elements.buffs[i], false)
            if _G[elements.buffs[i]] and _G[elements.buffs[i]]:IsMouseEnabled() then
                ChangeFrameMouseInteraction(elements.buffs[i], false)
            end
        end
    end
end

--Controls visibility on debuff icons, takes how many debuffs are to be shown and the element list of the frame to be modified
local function ToggleDebuffIcons(amount, _, elements)
    for i = 1, 3 do
        if i <= amount then
            ToggleTransparency(elements.debuffs[i], true)
            if _G[elements.debuffs[i]] and not _G[elements.debuffs[i]]:IsMouseEnabled() and not HARFDB[currentLayout].clickThroughBuffs then
                ChangeFrameMouseInteraction(elements.buffs[i], true)
            end
        else
            ToggleTransparency(elements.debuffs[i], false)
            if _G[elements.debuffs[i]] and _G[elements.debuffs[i]]:IsMouseEnabled() then
                ChangeFrameMouseInteraction(elements.buffs[i], false)
            end
        end
    end
end

--Toggles frame transparency, true for enabled false for disabled, takes frameString to be modified
function SetGroupFrameTransparency(value, frameString, _)
    if _G[frameString] then
        _G[frameString].background:SetIgnoreParentAlpha(not value)
    end
end

--Scale names, value for the new scale and element list to access the name
function ScaleNames(value, _, elements)
    if _G[elements.name] then
        _G[elements.name]:SetScale(value)
    end
    if elements.customName then
        elements.customName:SetScale(value)
        local width = _G[elements.name]:GetWidth()
        if not issecretvalue(width) then
            elements.customName:SetWidth(width)
        end
    end
end

--Class coloring for names, value is true for class colored and false for defaults. takes frameString of the frame to modify and its elements
function ColorNames(value, frameString, elements)
    if _G[frameString] and _G[frameString].unit then
        local frame = _G[frameString]
        local nameFrame = _G[elements.name]
        local customName
        if not elements.customName then
            customName = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            local font, size, flags = frame.name:GetFont()
            customName:SetScale(nameFrame:GetScale())
            customName:SetFont(font, size, flags)
            customName:SetWordWrap(false)
            customName:SetWidth(nameFrame:GetWidth())
            if string.find(frameString, 'Raid') then
                customName:SetJustifyH('CENTER')
                customName:SetPoint('CENTER', nameFrame, 'CENTER')
            else
                customName:SetJustifyH('LEFT')
                customName:SetPoint('TOPLEFT', nameFrame, 'TOPLEFT')
            end
            elements.customName = customName
        else
            customName = elements.customName
        end
        customName:SetText(GetUnitName(frame.unit, true))
        local _, class = UnitClass(frame.unit)
        if class then
            local color = RAID_CLASS_COLORS[class]
            if color then
                customName:SetTextColor(color.r, color.g, color.b)
            end
        end
        if value then
            nameFrame:SetAlpha(0)
            customName:SetAlpha(1)
        else
            nameFrame:SetAlpha(1)
            customName:SetAlpha(0)
        end
    end
end

--Map out unitsIds to the frameString of their frame for buff tracking, also creates the icon
function MapOutUnits(value, frameString, elements)
    if value and _G[frameString] and _G[frameString].unit then
        local unit = _G[frameString].unit
        local frame = _G[frameString]
        unitFrameMap[unit] = frameString
        local r, g, b = frame.healthBar:GetStatusBarColor()
        elements.originalColor = { r = r, g = g, b = b }
        if not elements.buffTrackingIcon then
            local buffIcon = CreateFrame('Frame', nil, UIParent)
            buffIcon:SetSize(25, 25)
            buffIcon:SetPoint('RIGHT', frame, 'RIGHT', -2, 0)
            buffIcon.texture = buffIcon:CreateTexture(nil, 'ARTWORK')
            buffIcon.texture:SetAllPoints()
            buffIcon.cooldown = CreateFrame('Cooldown', nil, buffIcon, 'CooldownFrameTemplate')
            buffIcon.cooldown:SetAllPoints()
            buffIcon.cooldown:SetReverse(true)
            buffIcon:Hide()
            elements.buffTrackingIcon = buffIcon
        end
    end
end

--Check aura status to see if the unit has the relevant buff
function CheckAuraStatus(unit, updateInfo)
    local util = supportedBuffTracking[playerClass].utility
    local hasBuff = false
    local isPlayer = UnitIsUnit(unit, 'player')
    local auras
    if playerClass == 'SHAMAN' then
        auras = C_UnitAuras.GetUnitAuras(unit, 'PLAYER|HELPFUL|RAID_IN_COMBAT', 2, Enum.UnitAuraSortRule.ExpirationOnly)
        if #auras == 2 then
            hasBuff = true
            if not isPlayer then
                util.earthShield = unit
            end
        elseif #auras == 1 and not isPlayer and (util.earthShield == nil or util.earthShield ~= unit) then
            hasBuff = true
        end
    elseif playerClass == 'EVOKER' then
        local currentTime = GetTime()
        auras = C_UnitAuras.GetUnitAuras(unit, 'PLAYER|HELPFUL|RAID', 2, Enum.UnitAuraSortRule.NameOnly)
        if currentTime == util.filteredSpellTimestamp and updateInfo.addedAuras then
            --This unit just got an invalid aura applied
            for _, aura in ipairs(updateInfo.addedAuras) do
                if C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, aura.auraInstanceID, 'PLAYER') then
                    util.filteredSpells[aura.auraInstanceID] = unit
                end
            end
        end
        if #auras > 0 then
            for _, aura in ipairs(auras) do
                if not util.filteredBuffs[aura.auraInstanceID] or not util.filteredBuffs[aura.auraInstanceID] == unit then
                    hasBuff = true
                end
            end
        end
    elseif playerClass == 'PRIEST' and util.isDisc then
        local currentTime = GetTime()
        if currentTime == util.filteredSpellTimestamp and updateInfo.addedAuras then
            --This update is at the same time as Pain Sup cast and applied an aura
            for _, aura in ipairs(updateInfo.addedAuras) do
                if C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, aura.auraInstanceID, 'PLAYER') then
                    util.filteredSpells[aura.auraInstanceID] = unit
                end
            end
        end
        auras = C_UnitAuras.GetUnitAuras(unit, 'PLAYER|HELPFUL|RAID_IN_COMBAT', 1, Enum.UnitAuraSortRule.NameOnly)
        if #auras == 1 and not util.filteredSpells[auras[1].auraInstanceID]  then
            hasBuff = true
        end
    end
    local elements = GetRelevantList()[unitFrameMap[unit]]
    local buffIcon = elements.buffTrackingIcon
    local healthBar = _G[unitFrameMap[unit]].healthBar
    local trackingColor = HARFDB[currentLayout].trackingColor
    local originalColor = elements.originalColor
    if hasBuff then
        local trackingType = HARFDB[currentLayout].trackingType
        if trackingType == 'icon' then
            buffIcon.texture:SetTexture(auras[1].icon)
            local duration = C_UnitAuras.GetAuraDuration(unit, auras[1].auraInstanceID)
            buffIcon.cooldown:SetCooldownFromDurationObject(duration)
            buffIcon:Show()
        elseif trackingType == 'color' then
            healthBar:SetStatusBarColor(trackingColor.r, trackingColor.g, trackingColor.b)
        end
    else
        buffIcon:Hide()
        healthBar:SetStatusBarColor(originalColor.r, originalColor.g, originalColor.b)
    end
end

--[[----------------------------------
    Setup and Options
------------------------------------]]
local function SetupSettings(modifiedSettingFunction, newValue)
    if not InCombatLockdown() then
        local relevantFrameList = GetRelevantList()
        local layoutInfo = HARFDB[currentLayout]
        local functionsToRun = {}
        if not modifiedSettingFunction or modifiedSettingFunction == MapOutUnits then
            if playerClass == 'PRIEST' and layoutInfo.buffTracking then
                supportedBuffTracking.PRIEST.utility.isDisc = C_SpecializationInfo.GetSpecialization() == 1
            end
            CleanUtilityTables()
        end

        if modifiedSettingFunction and type(modifiedSettingFunction) == 'function' then
            table.insert(functionsToRun, { func = modifiedSettingFunction, val = newValue } )
        else
            table.insert(functionsToRun, { func = ToggleBuffIcons, val = layoutInfo.buffIcons } )
            table.insert(functionsToRun, { func = ToggleDebuffIcons, val = layoutInfo.debuffIcons } )
            table.insert(functionsToRun, { func = ToggleAurasMouseInteraction, val = not layoutInfo.clickThroughBuffs } )
            table.insert(functionsToRun, { func = SetGroupFrameTransparency, val = layoutInfo.frameTransparency } )
            table.insert(functionsToRun, { func = ScaleNames, val = layoutInfo.nameScale } )
            table.insert(functionsToRun, { func = ColorNames, val = layoutInfo.colorNames } )
            table.insert(functionsToRun, { func = MapOutUnits, val = layoutInfo.buffTracking } )
        end

        for frameString, elements in pairs(relevantFrameList) do
            for _, functionData in ipairs(functionsToRun) do
                functionData.func(functionData.val, frameString, elements)
            end
        end

        if IsInRaid() and HARFDB[currentLayout].spotlight.names then
            MapSpotlightAnchors()
            ReanchorSpotlights()
        end
    end
end

local clickableOptionsFrame = CreateFrame('Frame', 'HarreksAdvancedRaidFrames', UIParent, 'InsetFrameTemplate')
clickableOptionsFrame:SetSize(150, 45)
clickableOptionsFrame:SetPoint('TOPRIGHT', CompactPartyFrame, 'TOPLEFT', -5, 0)
clickableOptionsFrame.text = clickableOptionsFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
clickableOptionsFrame.text:SetPoint("CENTER", clickableOptionsFrame, 'CENTER')
clickableOptionsFrame.text:SetText('Advanced Raid Frames')
clickableOptionsFrame:Hide()

local spotlightOptionsFrame = CreateFrame('Frame', 'AdvancedRaidFramesSpotlight', UIParent, 'InsetFrameTemplate')
spotlightOptionsFrame:SetSize(200, 50)
spotlightOptionsFrame:SetPoint('CENTER', UIParent, 'CENTER')
spotlightOptionsFrame.text = spotlightOptionsFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
spotlightOptionsFrame.text:SetPoint("CENTER", spotlightOptionsFrame, 'CENTER')
spotlightOptionsFrame.text:SetText('Advanced Raid Frames\nSpotlight')
spotlightOptionsFrame:SetAlpha(0)

local trackedEvents = {
    'PLAYER_LOGIN',
    'GROUP_ROSTER_UPDATE',
    'UNIT_SPELLCAST_SUCCEEDED',
    'UNIT_AURA'
}
local eventTracker = CreateFrame('Frame')
for _, event in ipairs(trackedEvents) do
    eventTracker:RegisterEvent(event)
end
eventTracker:SetScript('OnEvent', function(self, event, ...)
    if event == 'PLAYER_LOGIN' then

        HARFDB = HARFDB or {}
        playerClass = UnitClassBase('player')

        local LEM = LibStub('LibEditMode')

        LEM:RegisterCallback('enter', function()
            clickableOptionsFrame:Show()
            spotlightOptionsFrame:SetAlpha(1)
        end)

        LEM:RegisterCallback('exit', function()
            clickableOptionsFrame:Hide()
            spotlightOptionsFrame:SetAlpha(0)
            if IsInRaid() and not InCombatLockdown() and HARFDB[currentLayout].spotlight.names then
                ReanchorSpotlights()
            end
        end)

        LEM:RegisterCallback('layout', function(layout)
            currentLayout = layout
            if not HARFDB[layout] then
                HARFDB[layout] = CopyTable(defaultSettings)
            else
                for option, value in pairs(defaultSettings) do
                    if not HARFDB[layout][option] then
                        HARFDB[layout][option] = value
                    end
                end
            end
            SetupSettings()

            spotlightOptionsFrame:SetPoint(HARFDB[layout].spotlight.point, HARFDB[layout].spotlight.x, HARFDB[layout].spotlight.y)
        end)

        local options = {
            {
                name = 'Click Through Aura Icons',
                kind = LEM.SettingType.Checkbox,
                default = defaultSettings.clickThroughBuffs,
                desc = 'Disables mouse interaction on the aura icons on the frame, letting you mouseover and click through them.',
                get = function(layout)
                    return HARFDB[layout].clickThroughBuffs
                end,
                set = function(layout, value)
                    HARFDB[layout].clickThroughBuffs = value
                    SetupSettings(ToggleAurasMouseInteraction, not value)
                end
            },
            {
                name = 'Buff Icons',
                kind = LEM.SettingType.Slider,
                default = defaultSettings.buffIcons,
                desc = 'Changes the maximum amount of buff icons on the frame.',
                get = function(layout)
                    return HARFDB[layout].buffIcons
                end,
                set = function(layout, value)
                    HARFDB[layout].buffIcons = value
                    SetupSettings(ToggleBuffIcons, value)
                end,
                minValue = 0,
                maxValue = 6,
                valueStep = 1
            },
            {
                name = 'Debuff Icons',
                kind = LEM.SettingType.Slider,
                default = defaultSettings.debuffIcons,
                desc = 'Changes the maximum amount of debuff icons on the frame.',
                get = function(layout)
                    return HARFDB[layout].debuffIcons
                end,
                set = function(layout, value)
                    HARFDB[layout].debuffIcons = value
                    SetupSettings(ToggleDebuffIcons, value)
                end,
                minValue = 0,
                maxValue = 3,
                valueStep = 1
            },
            {
                name = 'Frame Transparency',
                kind = LEM.SettingType.Checkbox,
                default = defaultSettings.frameTransparency,
                desc = 'Disabling frame transparency keeps the frame fully solid even when out of range.',
                get = function(layout)
                    return HARFDB[layout].frameTransparency
                end,
                set = function(layout, value)
                    HARFDB[layout].frameTransparency = value
                    SetupSettings(SetGroupFrameTransparency, value)
                end
            },
            {
                name = 'Name Size',
                kind = LEM.SettingType.Slider,
                default = defaultSettings.nameScale,
                desc = 'Changes the size of the unit name.',
                get = function(layout)
                    return HARFDB[layout].nameScale
                end,
                set = function(layout, value)
                    HARFDB[layout].nameScale = value
                    SetupSettings(ScaleNames, value)
                end,
                formatter = formatForDisplay,
                minValue = 0.5,
                maxValue = 3,
                valueStep = 0.1
            },
            {
                name = 'Class Colored Names',
                kind = LEM.SettingType.Checkbox,
                default = defaultSettings.colorNames,
                desc = 'Replaces the unit name for class-colored ones.',
                get = function(layout)
                    return HARFDB[layout].colorNames
                end,
                set = function(layout, value)
                    HARFDB[layout].colorNames = value
                    SetupSettings(ColorNames, value)
                end
            }
        }
        if supportedBuffTracking[playerClass] and gameVersion >= 120001 then
            local conditionalOptions = {
                {
                    name = 'Buff Tracking: ' .. supportedBuffTracking[playerClass].spell,
                    kind = LEM.SettingType.Checkbox,
                    default = defaultSettings.buffTracking,
                    desc = 'Some specializations can track a specific buff better on their frames, this enables that tracking.',
                    get = function(layout)
                        return HARFDB[layout].buffTracking
                    end,
                    set = function(layout, value)
                        HARFDB[layout].buffTracking = value
                        SetupSettings(MapOutUnits, value)
                    end
                },
                {
                    name = 'Tracking Type',
                    kind = LEM.SettingType.Dropdown,
                    default = defaultSettings.trackingType,
                    desc = 'Choose how to track the buffs.',
                    get = function(layout)
                        return HARFDB[layout].trackingType
                    end,
                    set = function(layout, value)
                        HARFDB[layout].trackingType = value
                    end,
                    values = {
                        icon = { text = 'Icon', value = 'icon'},
                        color = { text = 'Bar Recolor', value = 'color' }
                    }
                },
                {
                    name = 'Tracking Bar Color',
                    kind = LEM.SettingType.ColorPicker,
                    default = CreateColor(defaultSettings.trackingColor.r, defaultSettings.trackingColor.g, defaultSettings.trackingColor.b),
                    desc = 'Color to change the bars into when the buff is present.',
                    get = function(layout)
                        local currentColor = HARFDB[layout].trackingColor
                        return CreateColor(currentColor.r, currentColor.g, currentColor.b)
                    end,
                    set = function(layout, value)
                        local r, g, b = value:GetRGB()
                        HARFDB[layout].trackingColor = { r = r, g = g, b = b }
                    end
                }
            }
            for _, option in ipairs(conditionalOptions) do
                table.insert(options, option)
            end
        end

        LEM:AddFrame(clickableOptionsFrame, function(frame)
            frame:ClearAllPoints()
            frame:SetPoint("TOPRIGHT", CompactPartyFrame, "TOPLEFT", -5, 0)
        end, { point = 'CENTER', x = 0, y = 0})
        LEM:AddFrameSettings(clickableOptionsFrame, options)

        LEM:AddFrame(spotlightOptionsFrame, function(frame, layout, point, x, y)
            HARFDB[layout].spotlight.point = point
            HARFDB[layout].spotlight.x = x
            HARFDB[layout].spotlight.y = y
        end)
        LEM:AddFrameSettings(spotlightOptionsFrame, {
            {
                name = 'Player List',
                kind = LEM.SettingType.Dropdown,
                default = defaultSettings.spotlight.names,
                desc = 'Select the players to be shown in the spotlight',
                multiple = true,
                get = function(layout)
                    local nameList = {}
                    for name, _ in pairs(HARFDB[layout].spotlight.names) do
                        table.insert(nameList, name)
                    end
                    return nameList
                end,
                set = function(layout, value)
                    if HARFDB[layout].spotlight.names[value] then
                        HARFDB[layout].spotlight.names[value] = nil
                    else
                        HARFDB[layout].spotlight.names[value] = true
                    end
                    MapSpotlightAnchors()
                end,
                values = GetSpotlightNames()
            },
            {
                name = 'Grow Direction',
                kind = LEM.SettingType.Dropdown,
                default = defaultSettings.spotlight.grow,
                desc = 'Grow direction for the spotlight frames',
                get = function(layout)
                    return HARFDB[layout].spotlight.grow
                end,
                set = function(layout, value)
                    HARFDB[layout].spotlight.grow = value
                end,
                values = {
                    { text = 'Right', value = 'right' },
                    { text = 'Bottom', value = 'bottom' }
                }
            }
        })

    elseif event == 'GROUP_ROSTER_UPDATE' then

        SetupSettings()

    elseif event == 'UNIT_AURA' and HARFDB[currentLayout].buffTracking then

        local unit, updateInfo = ...
        if supportedBuffTracking[playerClass] and unitFrameMap[unit] then
            CheckAuraStatus(unit, updateInfo)
        end

    elseif event == 'UNIT_SPELLCAST_SUCCEEDED' and supportedBuffTracking[playerClass] and HARFDB[currentLayout].buffTracking then

        local unit, _, spellId = ...
        if not issecretvalue(spellId) and not issecretvalue(unit) and unit == 'player' then
            if playerClass == 'EVOKER' and supportedBuffTracking.EVOKER.utility.filteredSpells[spellId] then
                supportedBuffTracking.EVOKER.utility.filteredSpellTimestamp = GetTime()
            elseif playerClass == 'PRIEST' and supportedBuffTracking.PRIEST.utility.isDisc and spellId == 33206 then
                supportedBuffTracking.PRIEST.utility.filteredSpellTimestamp = GetTime()
            end
        end

    end
end)