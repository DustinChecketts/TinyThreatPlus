local PANEL_NAME = "TinyThreatPlus"

local panel = CreateFrame("Frame", "TinyThreatPlusOptionsPanel")
panel.name = PANEL_NAME

local controls = {}
local radioButtons = {}

local function ApplyDefaults()
    if TinyThreatPlus_ApplyDefaults then
        TinyThreatPlus_ApplyDefaults()
    end
end

local function RefreshAddon()
    if TinyThreatPlus_UpdateAll then
        TinyThreatPlus_UpdateAll(0.08)
    end
end

local function AddTooltip(frame, title, text)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)

        if text and text ~= "" then
            GameTooltip:AddLine(text, nil, nil, nil, true)
        end

        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function MakeTitle(parent, text)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(text)
    return title
end

local function MakeSubtitle(parent, text, anchor)
    local subtitle = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    subtitle:SetText(text)
    subtitle:SetJustifyH("LEFT")
    return subtitle
end

local function MakeCheckbox(parent, label, dbKey, x, y, tooltip)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetText(label)

    AddTooltip(cb, label, tooltip)

    cb:SetScript("OnClick", function(self)
        ApplyDefaults()
        TinyThreatPlusDB[dbKey] = self:GetChecked() and true or false
        RefreshAddon()
    end)

    cb.Refresh = function()
        ApplyDefaults()
        cb:SetChecked(TinyThreatPlusDB[dbKey] and true or false)
    end

    table.insert(controls, cb)
    return cb
end

local function MakeRadio(parent, label, dbKey, value, x, y, tooltip)
    local rb = CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate")
    rb:SetPoint("TOPLEFT", x, y)
    rb.text:SetText(label)

    AddTooltip(rb, label, tooltip)

    rb:SetScript("OnClick", function()
        ApplyDefaults()
        TinyThreatPlusDB[dbKey] = value

        for _, button in ipairs(radioButtons) do
            if button.dbKey == dbKey then
                button:SetChecked(TinyThreatPlusDB[dbKey] == button.value)
            end
        end

        RefreshAddon()
    end)

    rb.dbKey = dbKey
    rb.value = value

    rb.Refresh = function()
        ApplyDefaults()
        rb:SetChecked(TinyThreatPlusDB[dbKey] == value)
    end

    table.insert(radioButtons, rb)
    table.insert(controls, rb)

    return rb
end

local function MakeSlider(parent, label, dbKey, minVal, maxVal, step, x, y)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(220)

    slider.Text:SetText(label)
    slider.Low:SetText(tostring(minVal))
    slider.High:SetText(tostring(maxVal))

    slider.valueText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slider.valueText:SetPoint("LEFT", slider, "RIGHT", 12, 0)

    slider:SetScript("OnValueChanged", function(self, value)
        ApplyDefaults()

        local rounded = math.floor(value + 0.5)
        TinyThreatPlusDB[dbKey] = rounded

        self.valueText:SetText(tostring(rounded))
        RefreshAddon()
    end)

    slider.Refresh = function()
        ApplyDefaults()

        local value = TinyThreatPlusDB[dbKey]
        if value == nil and TinyThreatPlusDefaults then
            value = TinyThreatPlusDefaults[dbKey]
        end
        if value == nil then
            value = minVal
        end

        slider:SetValue(value)
        slider.valueText:SetText(tostring(value))
    end

    table.insert(controls, slider)
    return slider
end

local title = MakeTitle(panel, "TinyThreatPlus")
MakeSubtitle(panel, "Lightweight threat lead values for Blizzard nameplates and the target frame.", title)

MakeCheckbox(panel, "Enable TinyThreatPlus", "enabled", 20, -70, "Enables all TinyThreatPlus features.")
MakeCheckbox(panel, "Show Threat on Nameplates", "showNameplates", 20, -100, "Displays your threat lead beside enemy nameplates.")
MakeCheckbox(panel, "Show Threat on Target Frame", "showTargetFrame", 20, -130, "Displays your threat lead above the target frame.")
MakeCheckbox(panel, "Recolor Nameplates", "recolorNameplates", 20, -160, "Colors enemy nameplates based on your role and threat status.\n\nDPS/Healer:\nGreen: Tank or pet has threat.\nYellow: You are close to taking threat.\nRed: You currently have threat.\n\nTank:\nGreen: You currently have threat.\nYellow: You are close to losing threat.\nRed: You do not have threat.")

MakeCheckbox(panel, "Use Role-Based Colors", "roleBasedColors", 360, -70, "Automatically reverses threat colors when your assigned role is Tank, keeping green as good and red as bad.")
MakeCheckbox(panel, "Include Pets", "includePets", 360, -100, "Includes player and party pets when calculating threat.")
MakeCheckbox(panel, "Show Target Counter", "showTargetCounter", 360, -130, "Displays the number of group members currently targeting the enemy.")
MakeCheckbox(panel, "Smooth Threat Updates", "smoothThreat", 360, -160, "Smooths threat number changes so values feel less jumpy during combat.")

local displayHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
displayHeader:SetPoint("TOPLEFT", 20, -205)
displayHeader:SetText("Threat Display")

MakeRadio(panel, "Threat Value", "displayMode", "VALUE", 24, -235, "Displays your threat lead as a value.\n\nExamples: +243, -1.2k, +13k")
MakeRadio(panel, "Threat Percentage", "displayMode", "PERCENT", 180, -235, "Displays your threat lead as a percentage above or below the next highest threat holder.\n\nExamples: +15%, -8%")

local nameplateHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
nameplateHeader:SetPoint("TOPLEFT", 20, -285)
nameplateHeader:SetText("Nameplate Threat Box")

MakeSlider(panel, "Font Size", "fontSize", 8, 16, 1, 24, -320)
MakeSlider(panel, "Box Width", "nameplateBoxWidth", 32, 100, 1, 24, -365)
MakeSlider(panel, "Minimum Height", "nameplateBoxMinHeight", 6, 24, 1, 24, -410)
MakeSlider(panel, "X Offset", "nameplateXOffset", -20, 80, 1, 24, -455)
MakeSlider(panel, "Y Offset", "nameplateYOffset", -30, 30, 1, 24, -500)
MakeSlider(panel, "Classic Level Badge Offset", "classicLevelBadgeOffset", 0, 120, 1, 24, -545)

local targetHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
targetHeader:SetPoint("TOPLEFT", 360, -285)
targetHeader:SetText("Target Frame Threat Box")

MakeSlider(panel, "Target Box Width", "targetBoxWidth", 32, 120, 1, 364, -320)
MakeSlider(panel, "Target Box Height", "targetBoxHeight", 10, 32, 1, 364, -365)
MakeSlider(panel, "Target X Offset", "targetXOffset", -80, 80, 1, 364, -410)
MakeSlider(panel, "Target Y Offset", "targetYOffset", -40, 40, 1, 364, -455)
MakeSlider(panel, "Smoothing Speed", "smoothingSpeed", 4, 30, 1, 364, -500)

local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
reset:SetSize(130, 24)
reset:SetPoint("TOPLEFT", 364, -555)
reset:SetText("Reset Defaults")
reset:SetScript("OnClick", function()
    if TinyThreatPlus_ResetDefaults then
        TinyThreatPlus_ResetDefaults()
    end

    for _, control in ipairs(controls) do
        if control.Refresh then
            control.Refresh()
        end
    end

    print("TinyThreatPlus settings reset.")
end)

panel:SetScript("OnShow", function()
    ApplyDefaults()

    for _, control in ipairs(controls) do
        if control.Refresh then
            control.Refresh()
        end
    end
end)

local category

if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    category = Settings.RegisterCanvasLayoutCategory(panel, PANEL_NAME)
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
        print("TinyThreatPlus: options panel is registered, but this client has no known settings open API.")
    end
end