local _, NS = ...
local Data = NS.Data
local Util = NS.Util
local Core = NS.Core
local Opt = NS.Opt

--Initialize default data
Data.gameVersion = select(4, GetBuildInfo())
Data.unitFrameMap = {}
Data.initializerList = {}
Data.playerClass = nil
Data.allowedCastDelay = 0.25
Data.buffFilter = 'PLAYER|HELPFUL|RAID_IN_COMBAT'
Data.supportedBuffTracking = {
    SHAMAN = {
        spell = 'Riptide',
        utility = {
            earthShield = nil,
            activeAuras = {}
        }
    },
    EVOKER = {
        spell = 'Echo',
        utility = {
            filteredSpellTimestamp = nil,
            filteredSpells = {
                [366155] = true,
                [357170] = true,
                [1256581] = true,
                [360995] = true
            },
            filteredEmpowers = {
                [355936] = true,
                [382614] = true
            },
            allEmpowers = {
                [355936] = true,
                [382614] = true,
                [357208] = true,
                [382266] = true
            },
            ttsActive = false,
            filteredBuffs = {},
            activeAuras = {}
        }
    },
    PRIEST = {
        spell = 'Atonement',
        utility = {
            isDisc = false,
            filteredSpellTimestamp = nil,
            --Disc works the other way around, tracks the casts that apply atonement
            filteredSpells = {
                [200829] = true,
                [2061] = true,
                [17] = true,
                [47540] = true,
                [194509] = true
            },
            filteredBuffs = {},
            activeAuras = {}
        }
    }
}

Data.spotlightAnchors = {
    spotlights = {},
    defaults = {},
}

Data.settings = {
    {
        key = 'clickThroughBuffs',
        type = 'checkbox',
        text = 'Click Through Aura Icons',
        default = true,
        tooltip = 'Disables mouse interaction on the aura icons on the frame, letting you mouseover and click through them.',
        func = 'ToggleAurasMouseInteraction'
    },
    {
        key = 'buffIcons',
        type = 'slider',
        text = 'Buff Icons',
        min = 0,
        max = 6,
        step = 1,
        default = 6,
        tooltip = 'Changes the maximum amount of buff icons on the default frames.',
        func = 'ToggleBuffIcons'
    },
    {
        key = 'debuffIcons',
        type = 'slider',
        text = 'Debuff Icons',
        min = 0,
        max = 3,
        step = 1,
        default = 3,
        tooltip = 'Changes the maximum amount of debuff icons on the default frames.',
        func = 'ToggleDebuffIcons'
    },
    {
        key = 'frameTransparency',
        type = 'checkbox',
        text = 'Frame Transparency',
        default = false,
        tooltip = 'Disabling frame transparency keeps the frame fully solid even when out of range.',
        func = 'SetGroupFrameTransparency'
    },
    {
        key = 'nameScale',
        type = 'slider',
        text = 'Name Size',
        min = 0.5,
        max = 3,
        step = 0.1,
        default = 1,
        tooltip = 'Changes the size of the unit names.',
        func = 'ScaleNames'
    },
    {
        key = 'colorNames',
        type = 'checkbox',
        text = 'Class Colored Names',
        default = false,
        tooltip = 'Replaces the unit name for class-colored ones.',
        func = 'ColorNames'
    },
    {
        key = 'buffTrackingHeader',
        type = 'header',
        text = 'Advanced Buff Tracking'
    },
    {
        key = 'buffTracking',
        type = 'checkbox',
        text = 'Buff Tracking',
        default = true,
        tooltip = 'Some specializations can track a specific buff better on their frames, this enables that tracking.',
        func = 'MapOutUnits'
    },
    {
        key = 'trackingType',
        type = 'dropdown',
        text = 'Tracking Type',
        items = {
            { text = 'Icon', value = 'icon' },
            { text = 'Bar Recolor', value = 'color' }
        },
        default = 'color',
        tooltip = 'Choose how to track the buffs.',
        parent = 'buffTracking'
    },
    {
        key = 'trackingColor',
        type = 'color',
        text = 'Tracking Color',
        default = 'ff00ff00',
        tooltip = 'Color to change the bars into when the buff is present.'
    },
    {
        key = 'addonsHeader',
        type = 'header',
        text = 'Frame AddOn Compatibility'
    },
    {
        key = 'dandersCompat',
        type = 'checkbox',
        text = 'DandersFrames Compatibility',
        default = false,
        tooltip = 'Enables highlighting on buffs for the addon frame.'
    }
}

Data.trackedEvents = {
    general = {
        'PLAYER_LOGIN',
        'GROUP_ROSTER_UPDATE'
    },
    player = {
        'UNIT_SPELLCAST_SUCCEEDED',
        'UNIT_SPELLCAST_EMPOWER_STOP'
    }
}

--Build a list of strings that match the default frame elements
Data.frameList = { party = {}, raid = {} }
for i = 1, 30 do
    local partyFrame, raidFrame
    if i <= 5 then
        partyFrame = 'CompactPartyFrameMember' .. i
        Data.frameList.party[partyFrame] = {
            buffs = {},
            debuffs = {},
            name = partyFrame .. 'Name',
            centerIcon = partyFrame .. 'CenterStatusIcon',
            isColored = false,
            defensive = { type = 'defensive', frame = partyFrame }
        }
    end
    raidFrame = 'CompactRaidFrame' .. i
    Data.frameList.raid[raidFrame] = {
        buffs = {},
        debuffs = {},
        name = raidFrame .. 'Name',
        centerIcon = raidFrame .. 'CenterStatusIcon',
        isColored = false,
        defensive = { type = 'defensive', frame = raidFrame }
    }
    for j = 1, 6 do
        if j <= 3 then
            if partyFrame then
                Data.frameList.party[partyFrame].debuffs[j] = partyFrame .. 'Debuff' .. j
            end
            Data.frameList.raid[raidFrame].debuffs[j] = raidFrame .. 'Debuff' .. j
        end
        if partyFrame then
            Data.frameList.party[partyFrame].buffs[j] = partyFrame .. 'Buff' .. j
        end
        Data.frameList.raid[raidFrame].buffs[j] = raidFrame .. 'Buff' .. j
    end
end
