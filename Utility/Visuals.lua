local _, NS = ...
local Data = NS.Data
local Ui = NS.Ui
local Util = NS.Util
local Core = NS.Core
local SavedIndicators = HARFDB.savedIndicators
local Options = HARFDB.options

function Util.UpdateIndicatorsForUnit(unit)
    local unitList = Util.GetRelevantList()
    local elements = unitList[unit]
    if elements then
        if elements.indicatorOverlay then
            elements.indicatorOverlay:UpdateIndicators()
        end
        if elements.extraFrames then
            --TODO this will be an api point, so extra frames get their own indicator overlays updated as well
        end
    end
end

--What a stupid fucking function to have to write
function Util.FigureOutBarAnchors(barData)
    local points = {
        { point = barData.Position, relative = barData.Position }
    }
    local sizing = {}

    if barData.Orientation == 'Vertical' then
        sizing.Orientation = 'VERTICAL'
    else
        sizing.Orientation = 'HORIZONTAL'
    end

    if barData.Position == 'TOPRIGHT' then
        if barData.Orientation == 'Vertical' then
            if barData.Scale == 'Full' then
                table.insert(points, { point = 'BOTTOMRIGHT', relative = 'BOTTOMRIGHT' })
            elseif barData.Scale == 'Half' then
                table.insert(points, { point = 'BOTTOMRIGHT', relative = 'RIGHT' })
            end
        elseif barData.Orientation == 'Horizontal' then
            if barData.Scale == 'Full' then
                table.insert(points, { point = 'TOPLEFT', relative = 'TOPLEFT' })
            elseif barData.Scale == 'Half' then
                table.insert(points, { point = 'TOPLEFT', relative = 'TOP' })
            end
        end
    elseif barData.Position == 'TOPLEFT' then
        if barData.Orientation == 'Vertical' then
            if barData.Scale == 'Full' then
                table.insert(points, { point = 'BOTTOMLEFT', relative = 'BOTTOMLEFT' })
            elseif barData.Scale == 'Half' then
                table.insert(points, { point = 'BOTTOMLEFT', relative = 'LEFT' })
            end
        elseif barData.Orientation == 'Horizontal' then
            sizing.Reverse = true
            if barData.Scale == 'Full' then
                table.insert(points, { point = 'TOPRIGHT', relative = 'TOPRIGHT' })
            elseif barData.Scale == 'Half' then
                table.insert(points, { point = 'TOPRIGHT', relative = 'TOP' })
            end
        end
    elseif barData.Position == 'BOTTOMRIGHT' then
        if barData.Orientation == 'Vertical' then
            sizing.Reverse = true
            if barData.Scale == 'Full' then
                table.insert(points, { point = 'TOPRIGHT', relative = 'TOPRIGHT' })
            elseif barData.Scale == 'Half' then
                table.insert(points, { point = 'TOPRIGHT', relative = 'RIGHT' })
            end
        elseif barData.Orientation == 'Horizontal' then
            if barData.Scale == 'Full' then
                table.insert(points, { point = 'BOTTOMLEFT', relative = 'BOTTOMLEFT' })
            elseif barData.Scale == 'Half' then
                table.insert(points, { point = 'BOTTOMLEFT', relative = 'BOTTOM' })
            end
        end
    elseif barData.Position == 'BOTTOMLEFT' then
        sizing.Reverse = true
        if barData.Orientation == 'Vertical' then
            if barData.Scale == 'Full' then
                table.insert(points, { point = 'TOPLEFT', relative = 'TOPLEFT' })
            elseif barData.Scale == 'Half' then
                table.insert(points, { point = 'TOPLEFT', relative = 'LEFT' })
            end
        elseif barData.Orientation == 'Horizontal' then
            if barData.Scale == 'Full' then
                table.insert(points, { point = 'BOTTOMRIGHT', relative = 'BOTTOMRIGHT' })
            elseif barData.Scale == 'Half' then
                table.insert(points, { point = 'BOTTOM', relative = 'BOTTOM' })
            end
        end
    end
    return { points = points, sizing = sizing }
end

--There must be a better way to do this?
--Do i have to rewrite my whole data tables so i can share it between the functions?
function Util.GetDefaultSettingsForIndicator(type)
    local data = { Type = type }
        if type == 'healthColor' then
        data.Color = { r = 0, g = 1, b = 0, a = 1 }
    elseif type == 'icon' then
        data.Position = 'CENTER'
        data.Size = 25
        data.xOffset = 0
        data.yOffset = 0
    elseif type == 'square' then
        data.Color = { r = 0, g = 1, b = 0, a = 1 }
        data.Position = 'CENTER'
        data.Size = 25
        data.xOffset = 0
        data.yOffset = 0
    elseif type == 'bar' then
        data.Color = { r = 0, g = 1, b = 0, a = 1 }
        data.Position = 'TOPRIGHT'
        data.Scale = 'Full'
        data.Orientation = 'Horizontal'
        data.Size = 15
    end
    for spell, _ in pairs(Data.specInfo[Options.editingSpec].auras) do
        data.Spell = spell
        break
    end
    return data
end