local _, NS = ...
local Data = NS.Data
local Ui = NS.Ui
local Util = NS.Util
local Core = NS.Core
local SavedIndicators = HARFDB.savedIndicators
local Options = HARFDB.options

--Get or Create the Designer Frame
function Ui.GetDesignerFrame()
    if not Ui.DesignerFrame then
        local designer = CreateFrame('Frame', 'HarreksAdvancedDesigner', UIParent)
        Ui.DesignerFrame = designer

        --The preview is our top container
        local preview = CreateFrame('Frame', nil, designer)
        preview:SetPoint('TOPLEFT', designer, 'TOPLEFT')
        preview:SetPoint('TOPRIGHT', designer, 'TOPRIGHT', -15, 0)
        preview:SetHeight(200)
        designer.Preview = preview

        --We have an example frame to set up our indicators in the middle of the preview
        local exampleFrame = CreateFrame('Frame', nil, designer)
        exampleFrame:SetSize(165, 65)
        exampleFrame:SetScale(1.5)
        exampleFrame:SetPoint('CENTER', preview, 'CENTER')
        exampleFrame.bg = exampleFrame:CreateTexture(nil, 'BACKGROUND')
        exampleFrame.bg:SetAllPoints(exampleFrame)
        exampleFrame.bg:SetTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
        local disclaimer = exampleFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
        disclaimer:SetPoint('TOP', exampleFrame, 'BOTTOM', 0, -3)
        disclaimer:SetWidth(250)
        disclaimer:SetScale(0.7)
        disclaimer:SetText('*Indicator size in the preview might not match real bars exactly')
        exampleFrame.Disclaimer = disclaimer
        preview.Frame = exampleFrame

        --Preview has a name
        local name = exampleFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
        name:SetPoint('TOP', exampleFrame, 'TOP', 0, -5)
        name:SetText('Harrek')
        exampleFrame.Name = name

        --And a health number in the middle
        local health = exampleFrame:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
        health:SetPoint('CENTER', exampleFrame, 'CENTER')
        health:SetText('100%')
        exampleFrame.Health = health

        --The config is the bottom container where we design our indicators
        local config = CreateFrame('Frame', nil, designer)
        config:SetPoint('TOPLEFT', preview, 'BOTTOMLEFT')
        config:SetPoint('TOPRIGHT', preview, 'BOTTOMRIGHT')
        config:SetHeight(80)
        designer.Config = config

        --First we make the spec selector
        local specSelector = CreateFrame('Frame', nil, config)
        specSelector:SetPoint('TOP', config, 'TOP', 0, -20)
        specSelector:SetSize(1, 1)
        config.SpecSelector = specSelector
        local specText = specSelector:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
        specText:SetPoint('RIGHT', specSelector, 'LEFT')
        specText:SetText('Currently Editing: ')
        specSelector.Text = specText
        local specDropdown = CreateFrame('DropdownButton', nil, config, 'WowStyle1DropdownTemplate')
        specDropdown:SetPoint('LEFT', specSelector, 'RIGHT')
        specDropdown:SetWidth(200)
        specDropdown:SetupMenu(function(_, root)
            root:CreateTitle('Pick Specialization')
            for spec, data in pairs(Data.specInfo) do
                root:CreateRadio(
                    data.display,
                    function() return Options.editingSpec == spec end,
                    function()
                        Options.editingSpec = spec
                        designer.RefreshScrollBox()
                        designer.RefreshPreview()
                    end
                )
            end
        end)
        specSelector.Dropdown = specDropdown

        --Now we make the buttons to add indicators
        local indicatorCreator = CreateFrame('Frame', nil, config)
        indicatorCreator:SetPoint('TOP', specSelector, 'BOTTOM', 0, -30)
        indicatorCreator:SetSize(1, 1)
        config.IndicatorCreator = indicatorCreator

        local indicatorText = indicatorCreator:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
        indicatorText:SetPoint('LEFT', indicatorCreator, 'LEFT', -180, 0)
        indicatorText:SetText('New Indicator: ')
        indicatorCreator.Text = indicatorText

        local typeDropdown = CreateFrame('DropdownButton', nil, config, "WowStyle1DropdownTemplate")
        typeDropdown:SetPoint('LEFT', indicatorText, 'RIGHT', 5, 0)
        typeDropdown:SetWidth(120)
        typeDropdown:SetupMenu(function(owner, root)
            for key, data in pairs(Data.indicatorTypes) do
                root:CreateRadio(
                    data.display,
                    function() return Data.selectedType and Data.selectedType == key end,
                    function() Data.selectedType = key end
                )
            end
        end)
        indicatorCreator.TypeDropdown = typeDropdown

        local createButton = CreateFrame('Button', nil, config, 'UIPanelButtonTemplate')
        createButton:SetSize(80, 22)
        createButton:SetText('Create')
        createButton:SetPoint('LEFT', typeDropdown, 'RIGHT', 5, 0)
        createButton:SetScript('OnClick', function()
            if Data.selectedType and Options.editingSpec then
                --Add this new option to the saved variables for this spec
                if not SavedIndicators[Options.editingSpec] then
                    SavedIndicators[Options.editingSpec] = {}
                end
                table.insert(SavedIndicators[Options.editingSpec], Util.GetDefaultSettingsForIndicator(Data.selectedType))
                --Refresh the display
                designer.RefreshScrollBox()
                designer:RefreshPreview()
            end
        end)
        indicatorCreator.CreateButton = createButton

        --The final part of the designer is a scroll box that shows the options for the currently selected spec
        local indicatorScroll = CreateFrame('Frame', nil, designer, 'WowScrollBoxList')
        indicatorScroll:SetPoint('TOPRIGHT', config, 'BOTTOMRIGHT', -5, 0)
        indicatorScroll:SetPoint('BOTTOMLEFT', designer, 'BOTTOMLEFT')
        designer.IndicatorScroll = indicatorScroll

        local scrollBar = CreateFrame('EventFrame', nil, designer, 'MinimalScrollBar')
        scrollBar:SetPoint('TOPLEFT', indicatorScroll, 'TOPRIGHT', 3, 0)
        scrollBar:SetPoint('BOTTOMLEFT', indicatorScroll, 'BOTTOMRIGHT', 3, 0)
        scrollBar:SetHideIfUnscrollable(true)

        local DataProvider = CreateDataProvider()
        local ScrollView = CreateScrollBoxListLinearView()
        ScrollView:SetElementExtent(80)

        ScrollView:SetElementInitializer('Frame', function(frame, data)
            if not frame.optFrame then
                frame.optFrame = Ui.CreateIndicatorOptions(data.Type, Options.editingSpec, data)
            end

            frame.optFrame:SetParent(frame)
            frame.optFrame:ClearAllPoints()
            frame.optFrame:SetAllPoints(frame)
            frame.optFrame:Show()

            frame.optFrame.savedSetting.spec = Options.editingSpec
            frame.optFrame.savedSetting.index = data.index
            frame.optFrame:SetupText(data.index)
        end)

        ScrollView:SetElementResetter(function(frame)
            if frame.optFrame then
                frame.optFrame:Release()
                frame.optFrame = nil
            end
        end)

        ScrollUtil.InitScrollBoxListWithScrollBar(indicatorScroll, scrollBar, ScrollView)
        ScrollView:SetDataProvider(DataProvider)

        designer.RefreshScrollBox = function()
            local spec = Options.editingSpec
            DataProvider:Flush()

            if SavedIndicators and SavedIndicators[spec] then
                for index, savedSetting in ipairs(SavedIndicators[spec]) do
                    local settingsData = CopyTable(savedSetting)
                    settingsData.index = index
                    DataProvider:Insert(settingsData)
                end
            end
        end

        designer.RefreshPreview = function()
            if preview.Overlay then preview.Overlay:Delete() end
            local exampleIndicatorOverlay = Ui.CreateIndicatorOverlay(SavedIndicators[Options.editingSpec])
            if exampleIndicatorOverlay then
                exampleIndicatorOverlay:SetParent(preview)
                exampleIndicatorOverlay:AttachToFrame(exampleFrame)
                exampleIndicatorOverlay:ShowPreview()
                preview.Overlay = exampleIndicatorOverlay
            end
        end

        designer.RefreshScrollBox()
        designer.RefreshPreview()

        designer:SetScript('OnHide', function()
            Util.MapOutUnits()
        end)
    end
    return Ui.DesignerFrame
end