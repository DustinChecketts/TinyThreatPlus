local TTP = _G.TinyThreatPlus or select(2, ...)

if not TTP then
    error("TinyThreatPlus: shared addon namespace is unavailable.")
end

local PANEL_NAME = "TinyThreatPlus"
local panel = CreateFrame("Frame", "TinyThreatPlusOptionsPanel")
panel.name = PANEL_NAME

local controls = {}

-- ---------------------------------------------------------------------------
-- Options helpers
-- ---------------------------------------------------------------------------

local function EnsureCore()
    if type(TTP.ApplyDefaults) ~= "function" then
        error("TinyThreatPlus: core file did not initialize correctly.")
    end

    TTP.ApplyDefaults()
end

local function RefreshAddon()
    EnsureCore()

    if type(TTP.UpdateAll) == "function" then
        TTP.UpdateAll()
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

local scrollFrame = CreateFrame(
    "ScrollFrame",
    "TinyThreatPlusOptionsScrollFrame",
    panel,
    "UIPanelScrollFrameTemplate"
)

scrollFrame:SetPoint("TOPLEFT", 8, -8)
scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(620, 1155)
scrollFrame:SetScrollChild(content)

local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 22, -18)
title:SetText("TinyThreatPlus")

local subtitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
subtitle:SetText("Threat intelligence and information enhancements for Blizzard nameplates.")

local reset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
reset:SetSize(100, 22)
reset:SetPoint("TOPRIGHT", content, "TOPRIGHT", -34, -18)
reset:SetText("Defaults")

local function Section(text, y)
    local header = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 32, y)
    header:SetText(text)

    local line = content:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.45, 0.45, 0.45, 0.45)
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    line:SetSize(510, 1)
end

local function MakeToggle(label, key, y, tooltip)
    local labelText = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 78, y)
    labelText:SetText(label)

    local check = CreateFrame(
        "CheckButton",
        nil,
        content,
        "InterfaceOptionsCheckButtonTemplate"
    )
    check:SetPoint("TOPLEFT", 380, y + 6)
    check.Text:SetText("")

    AddTooltip(check, label, tooltip)

    check:SetScript("OnClick", function(self)
        EnsureCore()
        TinyThreatPlusDB[key] = self:GetChecked() == true

        if key == "enemyPlayerClassColors"
            or key == "friendlyPlayerClassColors"
        then
            if type(TTP.ApplyClassColorSettings) == "function" then
                TTP.ApplyClassColorSettings()
            end
        end

        RefreshAddon()
    end)

    check.Refresh = function()
        EnsureCore()
        check:SetChecked(TinyThreatPlusDB[key] == true)
    end

    controls[#controls + 1] = check
    return check
end

local function MakeSlider(label, key, minimum, maximum, step, y, suffix, tooltip)
    local labelText = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 78, y)
    labelText:SetText(label)

    local slider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 290, y + 2)
    slider:SetWidth(220)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText("")
    slider.High:SetText("")
    slider.Text:SetText("")

    slider.valueText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    slider.valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)

    AddTooltip(slider, label, tooltip)

    slider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor((value / step) + 0.5) * step
        TinyThreatPlusDB[key] = rounded
        self.valueText:SetText(tostring(rounded) .. (suffix or ""))
        RefreshAddon()
    end)

    slider.Refresh = function()
        EnsureCore()
        local value = tonumber(TinyThreatPlusDB[key]) or TTP.defaults[key] or minimum
        slider:SetValue(value)
        slider.valueText:SetText(tostring(value) .. (suffix or ""))
    end

    controls[#controls + 1] = slider
    return slider
end

local function MakeColorPicker(label, key, y, tooltip)
    local labelText =
        content:CreateFontString(
            nil,
            "ARTWORK",
            "GameFontNormal"
        )

    labelText:SetPoint("TOPLEFT", 78, y)
    labelText:SetText(label)

    local swatch =
        CreateFrame(
            "Button",
            nil,
            content,
            "BackdropTemplate"
        )

    swatch:SetSize(44, 20)
    swatch:SetPoint("TOPLEFT", 380, y + 2)

    swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = {
            left = 2,
            right = 2,
            top = 2,
            bottom = 2,
        },
    })

    AddTooltip(swatch, label, tooltip)

    local function GetColor()
        EnsureCore()

        local color =
            TinyThreatPlusDB[key]
            or TTP.defaults[key]
            or { 1, 1, 1 }

        return color[1] or 1, color[2] or 1, color[3] or 1
    end

    local function ApplyColor(r, g, b)
        TinyThreatPlusDB[key] = { r, g, b }
        swatch:SetBackdropColor(r, g, b, 1)
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
                ApplyColor(
                    previous.r or previous[1] or oldR,
                    previous.g or previous[2] or oldG,
                    previous.b or previous[3] or oldB
                )
            else
                ApplyColor(oldR, oldG, oldB)
            end
        end

        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = oldR,
                g = oldG,
                b = oldB,
                swatchFunc = Changed,
                cancelFunc = Cancelled,
            })
        else
            ColorPickerFrame.previousValues =
                { oldR, oldG, oldB }

            ColorPickerFrame.func = Changed
            ColorPickerFrame.cancelFunc = Cancelled
            ColorPickerFrame:SetColorRGB(
                oldR,
                oldG,
                oldB
            )
            ColorPickerFrame:Show()
        end
    end)

    swatch.Refresh = function()
        local r, g, b = GetColor()
        swatch:SetBackdropColor(r, g, b, 1)
    end

    controls[#controls + 1] = swatch
    return swatch
end

local function MakeChoice(label, key, choices, y, tooltip)
    local labelText = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 78, y)
    labelText:SetText(label)

    local left = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    left:SetSize(24, 22)
    left:SetPoint("TOPLEFT", 285, y + 4)
    left:SetText("<")

    local choice = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    choice:SetSize(195, 22)
    choice:SetPoint("LEFT", left, "RIGHT", 5, 0)

    local right = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    right:SetSize(24, 22)
    right:SetPoint("LEFT", choice, "RIGHT", 5, 0)
    right:SetText(">")

    AddTooltip(left, label, tooltip)
    AddTooltip(choice, label, tooltip)
    AddTooltip(right, label, tooltip)

    local function FindIndex()
        EnsureCore()
        for index, item in ipairs(choices) do
            if TinyThreatPlusDB[key] == item.value then
                return index
            end
        end
        return 1
    end

    local function SetIndex(index)
        if index < 1 then index = #choices end
        if index > #choices then index = 1 end
        TinyThreatPlusDB[key] = choices[index].value
        choice:SetText(choices[index].label)
        RefreshAddon()
    end

    left:SetScript("OnClick", function() SetIndex(FindIndex() - 1) end)
    right:SetScript("OnClick", function() SetIndex(FindIndex() + 1) end)
    choice:SetScript("OnClick", function() SetIndex(FindIndex() + 1) end)

    choice.Refresh = function()
        local index = FindIndex()
        choice:SetText(choices[index].label)
    end

    controls[#controls + 1] = choice
    return choice
end

Section("Health Bar", -85)
MakeToggle(
    "Enable Threat Coloring",
    "roleBasedColors",
    -125,
    "Colors hostile NPC health bars by threat state. Other assigned tanks holding aggro are treated as safe."
)

Section("Threat Indicator", -180)
MakeToggle(
    "Show on Nameplates",
    "showNameplates",
    -220,
    "Shows TinyThreatPlus threat information beside hostile nameplates."
)
MakeToggle(
    "Show on Target Frame",
    "showTargetFrame",
    -252,
    "Shows the same threat indicator above the target frame."
)
MakeToggle(
    "Always Show Indicator",
    "alwaysShowThreatBoxes",
    -284,
    "Shows an idle indicator even before active threat information exists."
)
MakeChoice(
    "Threat Indicator Mode",
    "displayMode",
    {
        { label = "Value Difference", value = "VALUE" },
        { label = "Percentage", value = "PERCENT" },
    },
    -326,
    "Choose between exact threat difference and percentage display."
)
MakeSlider(
    "Nameplate Indicator Scale",
    "nameplateThreatScale",
    50,
    150,
    5,
    -368,
    "%",
    "Scales the complete nameplate threat indicator, including text and target counter."
)
MakeSlider(
    "Target Frame Indicator Scale",
    "targetThreatScale",
    50,
    150,
    5,
    -410,
    "%",
    "Scales the complete target-frame threat indicator."
)

Section("Threat Leader", -470)
MakeToggle(
    "Show Threat Leader",
    "showThreatLeader",
    -510,
    "Shows the unit currently leading threat below the threat indicator."
)
MakeToggle(
    "Show Class / Pet Icon",
    "showThreatLeaderClassIcon",
    -542,
    "Shows a player class icon or pet portrait for the current threat leader."
)
MakeToggle(
    "Show Role Icon",
    "showThreatLeaderRole",
    -574,
    "Shows the Tank, Healer, or Damage role for player threat leaders when available."
)

Section("Target Priority", -630)
MakeToggle(
    "Enable Target Priority",
    "showPriorityMarker",
    -670,
    "Highlights one useful priority target when multiple hostile nameplates are visible. Automatic priority is normally limited to parties and raids."
)
MakeToggle(
    "Enable While Solo (Pet Classes)",
    "priorityWhileSolo",
    -702,
    "Allows Target Priority while solo when you have an active pet. Uses real threat when available and combat-log fallback only when real threat data is unavailable."
)
MakeColorPicker(
    "Priority Color",
    "priorityMarkerColor",
    -744,
    "Choose the background color used to identify the Target Priority. Dark navy blue is the default."
)
MakeSlider(
    "Opacity",
    "priorityMarkerOpacity",
    10,
    100,
    5,
    -786,
    "%",
    "Controls the opacity of the Target Priority background."
)
MakeSlider(
    "Size",
    "priorityMarkerSizeRating",
    1,
    6,
    1,
    -828,
    "",
    "Controls Target Priority background size from 1 to 6. Each step adds 1 pixel of padding: 1 = 5 px through 6 = 10 px."
)
MakeSlider(
    "Threat Threshold",
    "priorityThreatThreshold",
    0,
    100,
    5,
    -870,
    "%",
    "Threat safety gate for Target Priority. Tanks mark the enemy most at risk of being lost. Damage only considers targets at or below this percentage of the threat leader, then prefers group focus, lower health, and finally lower personal threat. Healers receive no automatic priority target."
)

Section("Nameplate Information", -928)
MakeToggle("Show Enemy Level", "showMobLevel", -968, "Restores enemy levels on modern Blizzard nameplate styles. Classic displays levels natively.")
MakeToggle("Show Friendly Level", "showFriendlyLevel", -1000, "Restores friendly NPC levels on modern Blizzard nameplate styles.")
MakeToggle("Show Target Counter", "showTargetCounter", -1032, "Shows how many group members are targeting each enemy.")
MakeToggle("Enemy Player Class Colors", "enemyPlayerClassColors", -1064, "Uses Blizzard class colors for hostile players.")
MakeToggle("Friendly Player Class Colors", "friendlyPlayerClassColors", -1096, "Uses Blizzard class colors for friendly players.")

reset:SetScript("OnClick", function()
    if type(TTP.ResetDefaults) == "function" then
        TTP.ResetDefaults()
    end

    for _, control in ipairs(controls) do
        if control.Refresh then control.Refresh() end
    end
end)

panel:SetScript("OnShow", function()
    EnsureCore()

    if type(TTP.ApplyClassColorSettings) == "function" then
        TTP.ApplyClassColorSettings()
    end

    for _, control in ipairs(controls) do
        if control.Refresh then control.Refresh() end
    end
end)

if Settings
    and Settings.RegisterCanvasLayoutCategory
    and Settings.RegisterAddOnCategory
then
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
