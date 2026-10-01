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
reset:SetSize(110, 22)
reset:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -18)
reset:SetText("Page Defaults")

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
MakeTab("STYLING", "Styling", 150)

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
CreatePage("STYLING")

Section("GENERAL", "Nameplates", "Turns TinyThreatPlus features on or off while Blizzard retains ownership of the native nameplate.")
MakeToggle("GENERAL", "Show Threat Readout", "showNameplateThreat", "Shows TinyThreatPlus threat information on hostile nameplates.")
MakeToggle("GENERAL", "Always Show Threat Readout", "alwaysShowThreatBoxes", "Shows an idle threat readout before active threat information exists.")
MakeToggle("GENERAL", "Use Role-Based Threat Colors", "roleBasedColors", "Colors threat state according to your assigned role.")
MakeChoice("GENERAL", "Threat Display", "displayMode", {
    { label="Value Difference", value="VALUE" },
    { label="Percentage", value="PERCENT" },
}, "Chooses exact threat difference or percentage display.")
MakeToggle("GENERAL", "Show Mob Level", "showMobLevel", "Shows the difficulty-colored mob-level badge.")
MakeToggle("GENERAL", "Highlight Current Target", "showTargetHighlight", "Uses Blizzard's native selected-target border for the current target.")

Section("GENERAL", "Group Threat Information", "Group and raid information. The solo preview is a positioning aid and remains off by default.")
MakeToggle("GENERAL", "Show Nameplate Target Counter", "showTargetCounter", "Shows how many party or raid members are targeting each hostile nameplate.")
MakeToggle("GENERAL", "Show Target Frame Target Counter", "showTargetFrameCounter", "Shows how many party or raid members are targeting your current hostile target.")
MakeToggle("GENERAL", "Show Threat Leader", "showThreatLeader", "Shows the player or pet currently leading threat on your target.")
MakeToggle("GENERAL", "Show Threat Leader Role", "showThreatLeaderRole", "Shows the threat leader's assigned Tank, Healer, or Damage role when available.")
MakeToggle("GENERAL", "Preview Group Threat While Solo", "previewGroupThreatSolo", "Testing aid: shows solo placeholder group-threat information for positioning.")

Section("GENERAL", "Target Frame", "Controls TinyThreatPlus information added to Blizzard's target frame.")
MakeToggle("GENERAL", "Show Target Frame Threat Readout", "showTargetFrame", "Shows the TinyThreatPlus threat readout on the target frame.")

Section("GENERAL", "Target Priority", "Marks one enemy that deserves attention when fighting multiple targets.")
MakeToggle("GENERAL", "Enable Target Priority", "showPriorityMarker", "Enables automatic target-priority highlighting.")
MakeToggle("GENERAL", "Enable Target Priority While Solo", "priorityWhileSolo", "Allows priority logic while solo with an active pet.")
MakeSlider("GENERAL", "Target Priority Threat Threshold", "priorityThreatThreshold", 0, 100, 5, "%", "Sets the threat safety gate used by Target Priority.")

if TTP.Compat.IsForever() then
    Section("STYLING", "Nameplate Text", "Adjusts Blizzard's native enemy-name and health text without replacing the underlying plate.")
    MakeChoice("STYLING", "Enemy Name Font", "nativeNameFont", {
        { label="Friz Quadrata", value="FRIZQT" },
        { label="Arial Narrow", value="ARIALN" },
    }, "Selects the font used by Blizzard's native enemy-name FontString.")
    MakeSlider("STYLING", "Enemy Name Font Size", "nativeNameFontSize", 8, 16, 1, " px", "Sets enemy-name font size above the health bar.")
    MakeChoice("STYLING", "Enemy Name Edge", "nativeNameOutline", {
        { label="Off", value="NONE" }, { label="Shadow", value="SHADOW" },
        { label="Thin Outline", value="OUTLINE" }, { label="Thick Outline", value="THICKOUTLINE" },
    }, "Selects the enemy-name edge treatment.")
    MakeColorPicker("STYLING", "Enemy Name Shadow Color", "nativeNameOutlineColor", "Sets the shadow color when Enemy Name Edge is Shadow.")

    MakeChoice("STYLING", "Health Text Font", "nativeHealthFont", {
        { label="Friz Quadrata", value="FRIZQT" },
        { label="Arial Narrow", value="ARIALN" },
    }, "Selects the font used by Blizzard's native health value and percentage.")
    MakeSlider("STYLING", "Health Text Font Size", "nativeHealthFontSize", 8, 14, 1, " px", "Sets health value and percentage font size.")
    MakeChoice("STYLING", "Health Text Edge", "nativeHealthOutline", {
        { label="Off", value="NONE" }, { label="Shadow", value="SHADOW" },
        { label="Thin Outline", value="OUTLINE" }, { label="Thick Outline", value="THICKOUTLINE" },
    }, "Selects the health-text edge treatment.")
    MakeColorPicker("STYLING", "Health Text Shadow Color", "nativeHealthOutlineColor", "Sets the shadow color when Health Text Edge is Shadow.")

    Section("STYLING", "Mob Level")
    MakeSlider("STYLING", "Level Badge Size", "nativeLevelBadgeSize", 24, 48, 2, " px", "Sets mob-level badge size.")
    MakeSlider("STYLING", "Level Font Size", "nativeLevelFontSize", 8, 16, 1, " px", "Sets mob-level font size.")
    MakeSlider("STYLING", "Level X Offset", "nativeLevelOffsetX", -30, 10, 1, " px", "Moves the mob-level badge horizontally.")
    MakeSlider("STYLING", "Level Y Offset", "nativeLevelOffsetY", -20, 20, 1, " px", "Moves the mob-level badge vertically.")

    Section("STYLING", "Current Target")
    MakeColorPicker("STYLING", "Current Target Highlight Color", "targetHighlightColor", "Tints Blizzard's desaturated selected-target border.")
    MakeSlider("STYLING", "Current Target Highlight Opacity", "targetHighlightOpacity", 10, 100, 5, "%", "Sets current-target highlight opacity.")

    Section("STYLING", "Target Priority")
    MakeColorPicker("STYLING", "Target Priority Color", "priorityMarkerColor", "Tints Blizzard's native priority-highlight geometry.")
    MakeSlider("STYLING", "Target Priority Opacity", "priorityMarkerOpacity", 10, 100, 5, "%", "Sets target-priority highlight opacity.")
    MakeSlider("STYLING", "Target Priority Size", "priorityMarkerScale", 50, 200, 5, "%", "Scales the broader target-priority highlight.")
    MakeSlider("STYLING", "Target Priority X Offset", "priorityMarkerOffsetX", -40, 40, 1, " px", "Moves the target-priority highlight horizontally.")
    MakeSlider("STYLING", "Target Priority Y Offset", "priorityMarkerOffsetY", -30, 30, 1, " px", "Moves the target-priority highlight vertically.")

    Section("STYLING", "Nameplate Threat Readout")
    MakeSlider("STYLING", "Threat Readout Width", "nativeThreatWidth", 20, 60, 2, " px", "Sets nameplate threat-readout width.")
    MakeSlider("STYLING", "Threat Readout Height", "nativeThreatHeight", 14, 40, 2, " px", "Sets nameplate threat-readout height.")
    MakeSlider("STYLING", "Threat Readout Font Size", "nativeThreatFontSize", 8, 16, 1, " px", "Sets nameplate threat font size.")
    MakeSlider("STYLING", "Threat Readout X Offset", "nativeThreatOffsetX", -10, 40, 1, " px", "Moves the nameplate threat readout horizontally.")
    MakeSlider("STYLING", "Threat Readout Y Offset", "nativeThreatOffsetY", -20, 20, 1, " px", "Moves the nameplate threat readout vertically.")

    Section("STYLING", "Target Frame Threat Readout")
    MakeSlider("STYLING", "Target Frame Threat Width", "targetThreatWidth", 28, 64, 2, " px", "Sets target-frame threat-readout width.")
    MakeSlider("STYLING", "Target Frame Threat Height", "targetThreatHeight", 16, 28, 2, " px", "Sets target-frame threat-readout height.")
    MakeSlider("STYLING", "Target Frame Threat Font Size", "targetThreatFontSize", 8, 16, 1, " px", "Sets target-frame threat font size.")
    MakeSlider("STYLING", "Target Frame Threat X Offset", "targetThreatOffsetX", -40, 40, 1, " px", "Moves the target-frame threat readout horizontally.")
    MakeSlider("STYLING", "Target Frame Threat Y Offset", "targetThreatOffsetY", -30, 40, 1, " px", "Moves the target-frame threat readout vertically.")
    MakeSlider("STYLING", "Target Frame Threat Scale", "targetThreatScale", 50, 150, 5, "%", "Scales the target-frame TinyThreatPlus threat presentation.")

    Section("STYLING", "Target Frame Target Counter")
    MakeSlider("STYLING", "Target Counter Size", "targetCounterSize", 14, 32, 2, " px", "Sets target-frame target-counter size.")
    MakeSlider("STYLING", "Target Counter X Offset", "targetCounterOffsetX", -40, 40, 1, " px", "Moves the target-frame target counter horizontally.")
    MakeSlider("STYLING", "Target Counter Y Offset", "targetCounterOffsetY", -40, 40, 1, " px", "Moves the target-frame target counter vertically.")
end

local PAGE_DEFAULT_KEYS = {
    GENERAL = {
        "showNameplateThreat", "alwaysShowThreatBoxes", "roleBasedColors",
        "displayMode", "showMobLevel", "showTargetHighlight",
        "showTargetCounter", "showTargetFrameCounter", "showThreatLeader",
        "showThreatLeaderRole",
        "previewGroupThreatSolo", "showTargetFrame", "showPriorityMarker",
        "priorityWhileSolo", "priorityThreatThreshold",
    },
    STYLING = {
        "nativeNameFont", "nativeNameFontSize", "nativeNameOutline",
        "nativeNameOutlineColor", "nativeHealthFont", "nativeHealthFontSize",
        "nativeHealthOutline", "nativeHealthOutlineColor",
        "nativeLevelBadgeSize", "nativeLevelFontSize", "nativeLevelOffsetX",
        "nativeLevelOffsetY", "targetHighlightColor", "targetHighlightOpacity",
        "priorityMarkerColor", "priorityMarkerOpacity", "priorityMarkerScale",
        "priorityMarkerOffsetX", "priorityMarkerOffsetY",
        "nativeThreatWidth", "nativeThreatHeight", "nativeThreatFontSize",
        "nativeThreatOffsetX", "nativeThreatOffsetY",
        "targetThreatWidth", "targetThreatHeight", "targetThreatFontSize",
        "targetThreatOffsetX", "targetThreatOffsetY", "targetThreatScale",
        "targetCounterSize", "targetCounterOffsetX", "targetCounterOffsetY",
    },
}

local function CopyDefault(key)
    local value = TTP.defaults[key]
    if type(value) == "table" then
        TinyThreatPlusDB[key] = {}
        for index, item in pairs(value) do TinyThreatPlusDB[key][index] = item end
    else
        TinyThreatPlusDB[key] = value
    end
end

local function ResetActivePage()
    EnsureCore()
    for _, key in ipairs(PAGE_DEFAULT_KEYS[activePage] or {}) do
        CopyDefault(key)
    end
    RefreshAddon()
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
    ResetActivePage()
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
