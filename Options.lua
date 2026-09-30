local TTP = _G.TinyThreatPlus or select(2, ...)
if not TTP then error("TinyThreatPlus: shared addon namespace is unavailable.") end

local PANEL_NAME = "TinyThreatPlus"
local panel = CreateFrame("Frame", "TinyThreatPlusOptionsPanel")
panel.name = PANEL_NAME

local controls = {}
local pages = {}
local tabs = {}
local refreshing = false
local activePage = "GENERAL"

local function EnsureCore()
    if type(TTP.ApplyDefaults) ~= "function" then
        error("TinyThreatPlus: core file did not initialize correctly.")
    end
    TTP.ApplyDefaults()
end

local function RefreshAddon()
    if refreshing then return end
    EnsureCore()
    if type(TTP.UpdateAll) == "function" then TTP.UpdateAll() end
end

local function AddTooltip(frame, title, text)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if text and text ~= "" then GameTooltip:AddLine(text, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 20, -18)
title:SetText("TinyThreatPlus")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
subtitle:SetText("Threat-focused nameplates and target-frame information.")

local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
reset:SetSize(90, 22)
reset:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -18)
reset:SetText("Defaults")

local tabBar = CreateFrame("Frame", nil, panel)
tabBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -58)
tabBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -58)
tabBar:SetHeight(28)

local function CreatePage(key)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -92)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)

    local page = CreateFrame("Frame", nil, scroll)
    page:SetSize(620, 1600)
    scroll:SetScrollChild(page)
    scroll:Hide()
    pages[key] = { scroll = scroll, content = page, nextY = -16 }
    return pages[key]
end

local function SetPage(key)
    activePage = key
    for pageKey, page in pairs(pages) do
        if pageKey == key then page.scroll:Show() else page.scroll:Hide() end
    end
    for tabKey, button in pairs(tabs) do
        button:SetEnabled(tabKey ~= key)
    end
end

local function MakeTab(key, label, x)
    local button = CreateFrame("Button", nil, tabBar, "UIPanelButtonTemplate")
    button:SetSize(145, 24)
    button:SetPoint("LEFT", tabBar, "LEFT", x, 0)
    button:SetText(label)
    button:SetScript("OnClick", function() SetPage(key) end)
    tabs[key] = button
end

MakeTab("GENERAL", "General", 0)
MakeTab("CUSTOM", "Custom Plates", 150)
if TTP.Compat.IsForever() then MakeTab("NATIVE", "Native Plates", 300) end

local function Section(page, text, description)
    local p = pages[page]
    local header = p.content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 24, p.nextY)
    header:SetText(text)
    p.nextY = p.nextY - 30
    if description then
        local desc = p.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", 40, p.nextY)
        desc:SetWidth(510)
        desc:SetJustifyH("LEFT")
        desc:SetText(description)
        p.nextY = p.nextY - 38
    end
end

local function NextRow(page, height)
    local p = pages[page]
    local y = p.nextY
    p.nextY = p.nextY - (height or 38)
    return p.content, y
end

local function MakeToggle(page, label, key, tooltip)
    local parent, y = NextRow(page, 34)
    local check = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", 44, y + 6)
    check.Text:SetText(label)
    check.Text:SetPoint("LEFT", check, "RIGHT", 4, 1)
    AddTooltip(check, label, tooltip)
    check:SetScript("OnClick", function(self)
        EnsureCore()
        TinyThreatPlusDB[key] = self:GetChecked() == true
        RefreshAddon()
    end)
    check.Refresh = function() check:SetChecked(TinyThreatPlusDB[key] == true) end
    controls[#controls + 1] = check
end

local function MakeSlider(page, label, key, minimum, maximum, step, suffix, tooltip)
    local parent, y = NextRow(page, 42)
    local labelText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 44, y)
    labelText:SetText(label)

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 255, y + 2)
    slider:SetWidth(220)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText("")
    slider.High:SetText("")
    slider.Text:SetText("")

    slider.valueText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    slider.valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)
    AddTooltip(slider, label, tooltip)

    slider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor((value / step) + 0.5) * step
        self.valueText:SetText(tostring(rounded) .. (suffix or ""))
        if refreshing then return end
        TinyThreatPlusDB[key] = rounded
        RefreshAddon()
    end)
    slider.Refresh = function()
        local value = tonumber(TinyThreatPlusDB[key]) or TTP.defaults[key] or minimum
        slider:SetValue(value)
        slider.valueText:SetText(tostring(value) .. (suffix or ""))
    end
    controls[#controls + 1] = slider
end

local function MakeChoice(page, label, key, choices, tooltip)
    local parent, y = NextRow(page, 42)
    local labelText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 44, y)
    labelText:SetText(label)

    local left = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    left:SetSize(24, 22)
    left:SetPoint("TOPLEFT", 250, y + 4)
    left:SetText("<")
    local choice = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    choice:SetSize(190, 22)
    choice:SetPoint("LEFT", left, "RIGHT", 5, 0)
    local right = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    right:SetSize(24, 22)
    right:SetPoint("LEFT", choice, "RIGHT", 5, 0)
    right:SetText(">")

    AddTooltip(left, label, tooltip)
    AddTooltip(choice, label, tooltip)
    AddTooltip(right, label, tooltip)

    local function FindIndex()
        for index, item in ipairs(choices) do
            if TinyThreatPlusDB[key] == item.value then return index end
        end
        return 1
    end
    local function SetIndex(index)
        if index < 1 then index = #choices elseif index > #choices then index = 1 end
        TinyThreatPlusDB[key] = choices[index].value
        choice:SetText(choices[index].label)
        RefreshAddon()
    end
    left:SetScript("OnClick", function() SetIndex(FindIndex() - 1) end)
    right:SetScript("OnClick", function() SetIndex(FindIndex() + 1) end)
    choice:SetScript("OnClick", function() SetIndex(FindIndex() + 1) end)
    choice.Refresh = function() choice:SetText(choices[FindIndex()].label) end
    controls[#controls + 1] = choice
end

local function MakeColorPicker(page, label, key, tooltip)
    local parent, y = NextRow(page, 36)
    local labelText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 44, y)
    labelText:SetText(label)

    local swatch = CreateFrame("Button", nil, parent)
    swatch:SetSize(44, 20)
    swatch:SetPoint("TOPLEFT", 350, y + 2)
    swatch.texture = swatch:CreateTexture(nil, "ARTWORK")
    swatch.texture:SetAllPoints()
    swatch.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    AddTooltip(swatch, label, tooltip)

    local function GetColor()
        local color = TinyThreatPlusDB[key] or TTP.defaults[key] or { 1, 1, 1 }
        return color[1] or 1, color[2] or 1, color[3] or 1
    end
    local function ApplyColor(r, g, b)
        TinyThreatPlusDB[key] = { r, g, b }
        swatch.texture:SetVertexColor(r, g, b)
        RefreshAddon()
    end
    swatch:SetScript("OnClick", function()
        local oldR, oldG, oldB = GetColor()
        local function Changed()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            ApplyColor(r, g, b)
        end
        local function Cancelled(previous)
            if type(previous) == "table" then
                ApplyColor(previous.r or previous[1] or oldR, previous.g or previous[2] or oldG, previous.b or previous[3] or oldB)
            else
                ApplyColor(oldR, oldG, oldB)
            end
        end
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({ r=oldR, g=oldG, b=oldB, swatchFunc=Changed, cancelFunc=Cancelled })
        else
            ColorPickerFrame.previousValues = { oldR, oldG, oldB }
            ColorPickerFrame.func = Changed
            ColorPickerFrame.cancelFunc = Cancelled
            ColorPickerFrame:SetColorRGB(oldR, oldG, oldB)
            ColorPickerFrame:Show()
        end
    end)
    swatch.Refresh = function()
        local r, g, b = GetColor()
        swatch.texture:SetVertexColor(r, g, b)
    end
    controls[#controls + 1] = swatch
end

CreatePage("GENERAL")
CreatePage("CUSTOM")
if TTP.Compat.IsForever() then CreatePage("NATIVE") end

Section("GENERAL", "Presentation", "Shared behavior for TinyThreatPlus threat information.")
if TTP.Compat.IsForever() then
    MakeChoice("GENERAL", "Nameplate Mode", "nameplateMode", {
        { label="TinyThreatPlus Custom", value="CUSTOM" },
        { label="Blizzard + TinyThreatPlus", value="NATIVE" },
    }, "Switches between the full custom renderer and Blizzard's native Forever plate with TinyThreatPlus additions.")
end
MakeToggle("GENERAL", "Show Nameplate Threat", "showNameplateThreat", "Shows threat information on hostile nameplates.")
MakeToggle("GENERAL", "Enable Role-Based Colors", "roleBasedColors", "Colors threat state according to your assigned role.")
MakeToggle("GENERAL", "Always Show Threat Indicator", "alwaysShowThreatBoxes", "Shows an idle indicator before active threat information exists.")
MakeChoice("GENERAL", "Threat Display", "displayMode", {
    { label="Value Difference", value="VALUE" },
    { label="Percentage", value="PERCENT" },
}, "Choose exact threat difference or percentage display.")

Section("GENERAL", "Target Frame", "Target-frame threat and group targeting are controlled independently.")
MakeToggle("GENERAL", "Show Threat Indicator", "showTargetFrame", "Shows threat information above the target frame.")
MakeToggle("GENERAL", "Show Target Counter", "showTargetFrameCounter", "Shows how many party or raid members are targeting your hostile target.")
if TTP.Compat.IsForever() then
    MakeSlider("GENERAL", "Threat Box Width", "targetThreatWidth", 28, 64, 1, " px", "Sets the Forever target-frame threat width.")
    MakeSlider("GENERAL", "Threat Box Height", "targetThreatHeight", 16, 28, 1, " px", "Sets the Forever target-frame threat height.")
    MakeSlider("GENERAL", "Threat Font Size", "targetThreatFontSize", 8, 16, 1, " px", "Sets the Forever target-frame threat font size.")
    MakeSlider("GENERAL", "Threat Indicator Scale", "targetThreatScale", 50, 150, 5, "%", "Scales the target-frame threat presentation.")
end

Section("GENERAL", "Threat Leader", "Identifies the player or pet currently leading threat.")
MakeToggle("GENERAL", "Show Threat Leader", "showThreatLeader", "Shows the current threat leader below the target threat indicator.")
MakeToggle("GENERAL", "Show Class / Pet Icon", "showThreatLeaderClassIcon", "Shows a class icon or pet portrait.")
MakeToggle("GENERAL", "Show Role Icon", "showThreatLeaderRole", "Shows the assigned role when available.")

Section("GENERAL", "Target Priority", "Highlights one enemy that deserves attention when fighting multiple targets.")
MakeToggle("GENERAL", "Enable Target Priority", "showPriorityMarker", "Enables automatic target-priority highlighting.")
MakeToggle("GENERAL", "Enable While Solo (Pet Classes)", "priorityWhileSolo", "Allows priority logic while solo with an active pet.")
MakeColorPicker("GENERAL", "Priority Color", "priorityMarkerColor", "Sets the priority highlight color.")
MakeSlider("GENERAL", "Priority Opacity", "priorityMarkerOpacity", 10, 100, 5, "%", "Sets priority highlight opacity.")
MakeSlider("GENERAL", "Priority Size", "priorityMarkerSizeRating", 1, 6, 1, "", "Sets priority highlight padding.")
MakeSlider("GENERAL", "Threat Threshold", "priorityThreatThreshold", 0, 100, 5, "%", "Sets the threat safety gate used by Target Priority.")

Section("GENERAL", "Target Counter", "Shows how many party or raid members are targeting an enemy.")
MakeToggle("GENERAL", "Show on Nameplates", "showTargetCounter", "Shows group target count on hostile nameplates.")

Section("CUSTOM", "Custom Nameplates", "Styling for the full TinyThreatPlus Forever renderer.")
MakeSlider("CUSTOM", "Nameplate Scale", "customNameplateScale", 75, 150, 5, "%", "Scales the complete custom nameplate.")
MakeSlider("CUSTOM", "Health Bar Height", "customNameplateBarHeight", 12, 32, 1, " px", "Sets custom health-bar height.")
MakeSlider("CUSTOM", "Health Bar Scale", "customHealthScale", 75, 150, 5, "%", "Scales the custom health bar independently.")
MakeSlider("CUSTOM", "Frame X Offset", "healthFrameOffsetX", -4, 4, 1, " px", "Moves health-bar artwork horizontally.")
MakeSlider("CUSTOM", "Frame Y Offset", "healthFrameOffsetY", -4, 4, 1, " px", "Moves health-bar artwork vertically.")
MakeSlider("CUSTOM", "Inactive Opacity", "customNameplateInactiveOpacity", 20, 100, 5, "%", "Sets opacity for inactive custom plates.")

Section("CUSTOM", "Mob Name")
MakeSlider("CUSTOM", "Font Size", "customNameFontSize", 8, 18, 1, " px", "Sets mob-name font size.")
MakeColorPicker("CUSTOM", "Font Color", "customNameFontColor", "Sets mob-name text color.")
MakeToggle("CUSTOM", "Text Shadow", "customNameFontShadow", "Adds a black text shadow.")

Section("CUSTOM", "Mob Level")
MakeToggle("CUSTOM", "Show Mob Level", "showMobLevel", "Shows the difficulty-colored level badge.")
MakeSlider("CUSTOM", "Badge Size", "customLevelBadgeSize", 20, 32, 1, " px", "Sets custom level-badge size.")
MakeSlider("CUSTOM", "Level Font Size", "customLevelFontSize", 8, 14, 1, " px", "Sets custom level font size.")
MakeSlider("CUSTOM", "Badge X Offset", "customLevelOffsetX", -20, 20, 1, " px", "Moves the badge horizontally.")
MakeSlider("CUSTOM", "Badge Y Offset", "customLevelOffsetY", -20, 20, 1, " px", "Moves the badge vertically.")

Section("CUSTOM", "Current Target")
MakeToggle("CUSTOM", "Highlight Current Target", "showTargetHighlight", "Shows Blizzard-style selected-target artwork.")
MakeColorPicker("CUSTOM", "Highlight Color", "targetHighlightColor", "Tints the selected-target artwork.")
MakeSlider("CUSTOM", "Highlight Opacity", "targetHighlightOpacity", 10, 100, 5, "%", "Sets target-highlight opacity.")

Section("CUSTOM", "Threat Indicator")
MakeSlider("CUSTOM", "Box Width", "nameplateThreatWidth", 28, 60, 1, " px", "Sets custom nameplate threat width.")
MakeSlider("CUSTOM", "Box Height", "nameplateThreatHeight", 12, 32, 1, " px", "Sets custom nameplate threat height.")
MakeSlider("CUSTOM", "Font Size", "nameplateThreatFontSize", 8, 14, 1, " px", "Sets custom nameplate threat font size.")
MakeSlider("CUSTOM", "Box Scale", "nameplateThreatScale", 50, 150, 5, "%", "Scales the complete custom threat indicator.")

if TTP.Compat.IsForever() then
    Section("NATIVE", "Native Forever Plates", "Blizzard keeps ownership of the plate; TinyThreatPlus normalizes its text layout and adds independently tunable level and threat information.")
    MakeSlider("NATIVE", "Enemy Name Font Size", "nativeNameFontSize", 8, 16, 1, " px", "Sets the Blizzard native enemy-name font size above the health bar.")
    MakeSlider("NATIVE", "Health Text Font Size", "nativeHealthFontSize", 8, 14, 1, " px", "Sets Blizzard's native health value and percentage font size inside the bar.")
    MakeToggle("NATIVE", "Show Mob Level", "showMobLevel", "Shows the TinyThreatPlus HD level badge.")
    MakeSlider("NATIVE", "Level Badge Size", "nativeLevelBadgeSize", 24, 48, 1, " px", "Sets the Native level-badge size.")
    MakeSlider("NATIVE", "Level Font Size", "nativeLevelFontSize", 8, 16, 1, " px", "Sets the Native level font size.")
    MakeSlider("NATIVE", "Level X Offset", "nativeLevelOffsetX", -30, 10, 1, " px", "Moves the Native level badge horizontally.")
    MakeSlider("NATIVE", "Level Y Offset", "nativeLevelOffsetY", -20, 20, 1, " px", "Moves the Native level badge vertically.")

    Section("NATIVE", "Threat Readout", "Positions TinyThreatPlus threat over Blizzard's right-side native indicator area.")
    MakeSlider("NATIVE", "Threat Font Size", "nativeThreatFontSize", 8, 16, 1, " px", "Sets Native threat font size.")
    MakeSlider("NATIVE", "Threat X Offset", "nativeThreatOffsetX", -10, 40, 1, " px", "Moves Native threat horizontally.")
    MakeSlider("NATIVE", "Threat Y Offset", "nativeThreatOffsetY", -20, 20, 1, " px", "Moves Native threat vertically.")
end

local function RefreshControls()
    EnsureCore()
    refreshing = true
    for _, control in ipairs(controls) do
        if control.Refresh then control.Refresh() end
    end
    refreshing = false
end

reset:SetScript("OnClick", function()
    if type(TTP.ResetDefaults) == "function" then TTP.ResetDefaults() end
    RefreshControls()
end)

panel:SetScript("OnShow", function()
    RefreshControls()
    if not pages[activePage] then activePage = "GENERAL" end
    SetPage(activePage)
end)

SetPage("GENERAL")

if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, PANEL_NAME)
    category.ID = PANEL_NAME
    Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
end

SLASH_TINYTHREATPLUSOPTIONS1 = "/ttpoptions"
SlashCmdList.TINYTHREATPLUSOPTIONS = function()
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(PANEL_NAME)
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    else
        print("TinyThreatPlus: unable to open the options panel on this client.")
    end
end
