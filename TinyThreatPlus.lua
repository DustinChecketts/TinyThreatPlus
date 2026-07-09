local ADDON_NAME = ...
local TTP = CreateFrame("Frame", "TinyThreatPlusFrame")

TinyThreatPlusDB = TinyThreatPlusDB or {}

local DB_DEFAULTS = {
    enabled = true,
    showNameplates = true,
    showTargetFrame = true,
    includePets = true,
    recolorNameplates = true,
    showTargetCounter = true,
    roleBasedColors = true,

    displayMode = "VALUE",
    smoothThreat = true,
    smoothingSpeed = 12,

    fontSize = 12,

    nameplateBoxWidth = 52,
    nameplateBoxMinHeight = 8,
    nameplateXOffset = 6,
    nameplateYOffset = 0,
    classicLevelBadgeOffset = 22,

    targetBoxWidth = 52,
    targetBoxHeight = 18,
    targetXOffset = 0,
    targetYOffset = 2,
}

TinyThreatPlusDefaults = DB_DEFAULTS

local activeNameplates = {}
local smoothedValues = {}
local elapsedSinceUpdate = 0
local isApplyingColor = false

local COLORS = {
    good = { 0.10, 0.85, 0.10 },
    warn = { 1.00, 0.82, 0.00 },
    bad = { 1.00, 0.10, 0.10 },

    bg = { 0.02, 0.02, 0.02, 0.86 },
    border = { 0.72, 0.72, 0.72, 1.00 },
}

function TinyThreatPlus_ApplyDefaults()
    TinyThreatPlusDB = TinyThreatPlusDB or {}

    for k, v in pairs(DB_DEFAULTS) do
        if TinyThreatPlusDB[k] == nil then
            TinyThreatPlusDB[k] = v
        end
    end
end

function TinyThreatPlus_ResetDefaults()
    TinyThreatPlusDB = {}

    for k, v in pairs(DB_DEFAULTS) do
        TinyThreatPlusDB[k] = v
    end

    smoothedValues = {}

    if TinyThreatPlus_UpdateAll then
        TinyThreatPlus_UpdateAll(0.08)
    end
end

local function Abbrev(value)
    value = math.floor(math.abs(value) + 0.5)

    if value >= 1000000 then
        return string.format("%.1fm", value / 1000000)
    elseif value >= 10000 then
        return string.format("%dk", math.floor(value / 1000 + 0.5))
    elseif value >= 1000 then
        return string.format("%.1fk", value / 1000)
    end

    return tostring(value)
end

local function FormatSignedNumber(value)
    if value > 0 then
        return "+" .. Abbrev(value)
    elseif value < 0 then
        return "-" .. Abbrev(value)
    end

    return "0"
end

local function FormatSignedPercent(value)
    value = math.floor(value + 0.5)

    if value > 0 then
        return "+" .. value .. "%"
    elseif value < 0 then
        return value .. "%"
    end

    return "0%"
end

local function GetGroupUnits(includePets)
    local units = { "player" }

    if includePets and UnitExists("pet") then
        table.insert(units, "pet")
    end

    if IsInRaid() then
        for i = 1, 40 do
            local unit = "raid" .. i
            if UnitExists(unit) then
                table.insert(units, unit)
            end

            local pet = unit .. "pet"
            if includePets and UnitExists(pet) then
                table.insert(units, pet)
            end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                table.insert(units, unit)
            end

            local pet = unit .. "pet"
            if includePets and UnitExists(pet) then
                table.insert(units, pet)
            end
        end
    end

    return units
end

local function GetThreatData(unit)
    if not unit or not UnitExists(unit) or UnitIsDead(unit) then
        return nil
    end

    if UnitIsPlayer(unit) or not UnitCanAttack("player", unit) then
        return nil
    end

    local _, _, _, _, playerThreat = UnitDetailedThreatSituation("player", unit)
    if not playerThreat then
        return nil
    end

    local highestOtherThreat = 0

    for _, groupUnit in ipairs(GetGroupUnits(TinyThreatPlusDB.includePets)) do
        if groupUnit ~= "player" and UnitExists(groupUnit) then
            local _, _, _, _, threatValue = UnitDetailedThreatSituation(groupUnit, unit)
            threatValue = threatValue or 0

            if threatValue > highestOtherThreat then
                highestOtherThreat = threatValue
            end
        end
    end

    local lead = (playerThreat - highestOtherThreat) / 100
    local percent

    if highestOtherThreat > 0 then
        percent = ((playerThreat - highestOtherThreat) / highestOtherThreat) * 100
    elseif playerThreat > 0 then
        percent = 100
    else
        percent = 0
    end

    return lead, percent
end

local function GetTargetCounter(unit)
    if not TinyThreatPlusDB.showTargetCounter then
        return nil
    end

    if not IsInGroup() and not IsInRaid() then
        return nil
    end

    local guid = UnitGUID(unit)
    if not guid then
        return nil
    end

    local count = 0

    for _, groupUnit in ipairs(GetGroupUnits(false)) do
        local targetUnit = groupUnit .. "target"
        if UnitExists(targetUnit) and UnitGUID(targetUnit) == guid then
            count = count + 1
        end
    end

    if count <= 0 then
        return nil
    end

    return count
end

local function PlayerIsTank()
    if not TinyThreatPlusDB.roleBasedColors then
        return false
    end

    return UnitGroupRolesAssigned and UnitGroupRolesAssigned("player") == "TANK"
end

local function GetThreatColor(unit, lead)
    local playerStatus = UnitThreatSituation("player", unit)

    if PlayerIsTank() then
        if playerStatus == 3 and lead and lead >= 0 then
            return unpack(COLORS.good)
        end

        if playerStatus == 2 or playerStatus == 1 then
            return unpack(COLORS.warn)
        end

        return unpack(COLORS.bad)
    end

    if playerStatus == 3 and lead and lead >= 0 then
        return unpack(COLORS.bad)
    end

    if playerStatus == 2 or playerStatus == 1 then
        return unpack(COLORS.warn)
    end

    return unpack(COLORS.good)
end

local function GetDisplayRawValue(lead, percent)
    if TinyThreatPlusDB.displayMode == "PERCENT" then
        return percent or 0
    end

    return lead or 0
end

local function FormatDisplayValue(value)
    if TinyThreatPlusDB.displayMode == "PERCENT" then
        return FormatSignedPercent(value)
    end

    return FormatSignedNumber(value)
end

local function GetSmoothKey(prefix, unit)
    local guid = UnitGUID(unit)
    if guid then
        return prefix .. ":" .. guid
    end

    return prefix .. ":" .. unit
end

local function SmoothValue(key, rawValue, dt)
    if not TinyThreatPlusDB.smoothThreat then
        smoothedValues[key] = rawValue
        return rawValue
    end

    local previous = smoothedValues[key]
    if previous == nil then
        smoothedValues[key] = rawValue
        return rawValue
    end

    local speed = TinyThreatPlusDB.smoothingSpeed or 12
    local alpha = math.min(1, (dt or 0.08) * speed)
    local smoothed = previous + ((rawValue - previous) * alpha)

    if math.abs(smoothed - rawValue) < 0.5 then
        smoothed = rawValue
    end

    smoothedValues[key] = smoothed
    return smoothed
end

local function IsClassicNameplateStyle()
    return C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("nameplateStyle") == "0"
end

local function GetClassicScaledOffset(healthBar)
    if not IsClassicNameplateStyle() then
        return 0
    end

    local scale = healthBar.GetEffectiveScale and healthBar:GetEffectiveScale() or 1
    local uiScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local relativeScale = scale / uiScale

    return math.floor((TinyThreatPlusDB.classicLevelBadgeOffset or 22) * relativeScale + 0.5)
end

local function ApplyThreatBoxStyle(frame, height)
    local edgeSize = 10
    local inset = 2

    if height <= 10 then
        edgeSize = 6
        inset = 1
    elseif height <= 14 then
        edgeSize = 8
        inset = 2
    end

    local styleKey = edgeSize .. ":" .. inset
    if frame.TinyThreatPlusStyleKey == styleKey then
        return
    end

    frame.TinyThreatPlusStyleKey = styleKey

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = edgeSize,
        insets = { left = inset, right = inset, top = inset, bottom = inset }
    })

    frame:SetBackdropColor(COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], COLORS.bg[4])
    frame:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], COLORS.border[4])
end

local function EnsureThreatBox(parent, key, globalName)
    if parent[key] then
        return parent[key]
    end

    local box = CreateFrame("Frame", globalName, parent, "BackdropTemplate")
    box:SetFrameStrata(parent:GetFrameStrata())
    box:SetFrameLevel((parent:GetFrameLevel() or 1) + 30)

    box.text = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    box.text:SetPoint("CENTER", box, "CENTER", 0, 0)
    box.text:SetJustifyH("CENTER")
    box.text:SetJustifyV("MIDDLE")

    box.counterBg = box:CreateTexture(nil, "ARTWORK")
    box.counterBg:SetSize(18, 18)
    box.counterBg:SetAtlas("PetJournal-LevelBubble")
    box.counterBg:SetPoint("CENTER", box, "RIGHT", 5, 0)
    box.counterBg:Hide()

    box.counterText = box:CreateFontString(nil, "OVERLAY", "GameNormalNumberFont")
    box.counterText:SetSize(18, 18)
    box.counterText:SetPoint("CENTER", box.counterBg, "CENTER", 0, 0)
    box.counterText:SetJustifyH("CENTER")
    box.counterText:SetJustifyV("MIDDLE")
    box.counterText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    box.counterText:SetTextColor(1, 1, 1)
    box.counterText:Hide()

    box:Hide()
    parent[key] = box

    return box
end

local function UpdateThreatBox(box, width, height, text, r, g, b, counter, isNameplate)
    ApplyThreatBoxStyle(box, height)

    box:SetSize(width, height)

    local fontSize = TinyThreatPlusDB.fontSize or 12
    if isNameplate and height <= 10 then
        fontSize = math.max(8, fontSize - 2)
    elseif isNameplate and height <= 14 then
        fontSize = math.max(8, fontSize - 1)
    end

    box.text:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    box.text:SetText(text)
    box.text:SetTextColor(r, g, b)

    if counter then
        box.counterText:SetText(counter)
        box.counterBg:Show()
        box.counterText:Show()
    else
        box.counterBg:Hide()
        box.counterText:Hide()
    end

    box:Show()
end

local function FindNameplateHealthBar(nameplate)
    if not nameplate then
        return nil
    end

    local uf = nameplate.UnitFrame

    if uf then
        return uf.healthBar
            or uf.HealthBar
            or uf.healthBarContainer
            or uf.HealthBarsContainer
            or uf
    end

    return nameplate
end

local function GetNameplateHealthHeight(healthBar)
    if not healthBar or not healthBar.GetHeight then
        return TinyThreatPlusDB.nameplateBoxMinHeight or 8
    end

    local height = math.floor((healthBar:GetHeight() or 0) + 0.5)
    local minHeight = TinyThreatPlusDB.nameplateBoxMinHeight or 8

    if height < minHeight then
        height = minHeight
    end

    return height
end

local function ApplyNameplateColor(healthBar, unit, lead)
    if not TinyThreatPlusDB.recolorNameplates or not healthBar or not healthBar.SetStatusBarColor then
        return
    end

    local r, g, b = GetThreatColor(unit, lead)

    isApplyingColor = true
    healthBar:SetStatusBarColor(r, g, b)
    isApplyingColor = false
end

local function HookHealthBarColor(healthBar)
    if not healthBar or healthBar.TinyThreatPlusHooked then
        return
    end

    healthBar.TinyThreatPlusHooked = true

    hooksecurefunc(healthBar, "SetStatusBarColor", function(bar)
        if isApplyingColor or not TinyThreatPlusDB.recolorNameplates then
            return
        end

        local hookedUnit = bar.TinyThreatPlusUnit
        if not hookedUnit or not UnitExists(hookedUnit) then
            return
        end

        local lead = GetThreatData(hookedUnit)
        if lead then
            ApplyNameplateColor(bar, hookedUnit, lead)
        end
    end)
end

local function UpdateNameplate(unit, dt)
    if not TinyThreatPlusDB.enabled or not TinyThreatPlusDB.showNameplates then
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
        if nameplate and nameplate.TinyThreatPlusBox then
            nameplate.TinyThreatPlusBox:Hide()
        end
        return
    end

    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate or nameplate:IsForbidden() then
        return
    end

    local healthBar = FindNameplateHealthBar(nameplate)
    local box = EnsureThreatBox(nameplate, "TinyThreatPlusBox", nil)
    local lead, percent = GetThreatData(unit)

    if not healthBar or not lead then
        box:Hide()
        return
    end

    healthBar.TinyThreatPlusUnit = unit
    HookHealthBarColor(healthBar)

    local rawDisplay = GetDisplayRawValue(lead, percent)
    local display = SmoothValue(GetSmoothKey("nameplate", unit), rawDisplay, dt)

    local height = GetNameplateHealthHeight(healthBar)
    local r, g, b = GetThreatColor(unit, lead)
    local counter = GetTargetCounter(unit)
    local extraOffset = GetClassicScaledOffset(healthBar)

    box:ClearAllPoints()
    box:SetPoint(
        "LEFT",
        healthBar,
        "RIGHT",
        (TinyThreatPlusDB.nameplateXOffset or 6) + extraOffset,
        TinyThreatPlusDB.nameplateYOffset or 0
    )

    UpdateThreatBox(
        box,
        TinyThreatPlusDB.nameplateBoxWidth or 52,
        height,
        FormatDisplayValue(display),
        r, g, b,
        counter,
        true
    )

    ApplyNameplateColor(healthBar, unit, lead)
end

local function HideNameplate(unit)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if nameplate and nameplate.TinyThreatPlusBox then
        nameplate.TinyThreatPlusBox:Hide()
    end
end

local function FindTargetNameAnchor()
    if TargetFrameTextureFrameName then
        return TargetFrameTextureFrameName
    end

    if TargetFrame and TargetFrame.name then
        return TargetFrame.name
    end

    if TargetFrameName then
        return TargetFrameName
    end

    return TargetFrame
end

local function EnsureTargetBox()
    if TTP.targetBox then
        return TTP.targetBox
    end

    local parent = TargetFrameTextureFrame or TargetFrame or UIParent
    local box = EnsureThreatBox(parent, "TinyThreatPlusTargetBox", "TinyThreatPlusTargetBox")
    TTP.targetBox = box

    return box
end

local function UpdateTargetFrame(dt)
    local box = EnsureTargetBox()

    if not TinyThreatPlusDB.enabled or not TinyThreatPlusDB.showTargetFrame or not UnitExists("target") then
        box:Hide()
        return
    end

    local lead, percent = GetThreatData("target")
    if not lead then
        box:Hide()
        return
    end

    local anchor = FindTargetNameAnchor()
    if not anchor then
        box:Hide()
        return
    end

    local rawDisplay = GetDisplayRawValue(lead, percent)
    local display = SmoothValue(GetSmoothKey("target", "target"), rawDisplay, dt)

    local r, g, b = GetThreatColor("target", lead)
    local counter = GetTargetCounter("target")

    box:ClearAllPoints()
    box:SetPoint(
        "BOTTOM",
        anchor,
        "TOP",
        TinyThreatPlusDB.targetXOffset or 0,
        TinyThreatPlusDB.targetYOffset or 2
    )

    UpdateThreatBox(
        box,
        TinyThreatPlusDB.targetBoxWidth or 52,
        TinyThreatPlusDB.targetBoxHeight or 18,
        FormatDisplayValue(display),
        r, g, b,
        counter,
        false
    )
end

function TinyThreatPlus_UpdateAll(dt)
    TinyThreatPlus_ApplyDefaults()

    if not TinyThreatPlusDB.enabled then
        for unit in pairs(activeNameplates) do
            HideNameplate(unit)
        end

        if TTP.targetBox then
            TTP.targetBox:Hide()
        end

        return
    end

    for unit in pairs(activeNameplates) do
        if UnitExists(unit) then
            UpdateNameplate(unit, dt or 0.08)
        else
            activeNameplates[unit] = nil
        end
    end

    UpdateTargetFrame(dt or 0.08)
end

TTP:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        TinyThreatPlus_ApplyDefaults()
        TinyThreatPlus_UpdateAll(0.08)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        activeNameplates[arg1] = true
        UpdateNameplate(arg1, 0.08)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        activeNameplates[arg1] = nil
        HideNameplate(arg1)
    elseif event == "PLAYER_TARGET_CHANGED" then
        smoothedValues["target:" .. (UnitGUID("target") or "target")] = nil
        UpdateTargetFrame(0.08)
    elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_THREAT_SITUATION_UPDATE" then
        TinyThreatPlus_UpdateAll(0.08)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
        TinyThreatPlus_UpdateAll(0.08)
    end
end)

TTP:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed

    if elapsedSinceUpdate >= 0.08 then
        local dt = elapsedSinceUpdate
        elapsedSinceUpdate = 0
        TinyThreatPlus_UpdateAll(dt)
    end
end)

TTP:RegisterEvent("ADDON_LOADED")
TTP:RegisterEvent("NAME_PLATE_UNIT_ADDED")
TTP:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
TTP:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
TTP:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
TTP:RegisterEvent("PLAYER_TARGET_CHANGED")
TTP:RegisterEvent("GROUP_ROSTER_UPDATE")
TTP:RegisterEvent("PLAYER_ROLES_ASSIGNED")

SLASH_TINYTHREATPLUS1 = "/ttp"
SLASH_TINYTHREATPLUS2 = "/tinythreatplus"
SlashCmdList.TINYTHREATPLUS = function(msg)
    msg = string.lower(msg or "")

    if msg == "on" then
        TinyThreatPlusDB.enabled = true
        print("TinyThreatPlus enabled.")
    elseif msg == "off" then
        TinyThreatPlusDB.enabled = false
        print("TinyThreatPlus disabled.")
    elseif msg == "pets" then
        TinyThreatPlusDB.includePets = not TinyThreatPlusDB.includePets
        print("TinyThreatPlus include pets:", TinyThreatPlusDB.includePets and "on" or "off")
    elseif msg == "colors" then
        TinyThreatPlusDB.recolorNameplates = not TinyThreatPlusDB.recolorNameplates
        print("TinyThreatPlus nameplate recolor:", TinyThreatPlusDB.recolorNameplates and "on" or "off")
    elseif msg == "rolecolors" then
        TinyThreatPlusDB.roleBasedColors = not TinyThreatPlusDB.roleBasedColors
        print("TinyThreatPlus role-based colors:", TinyThreatPlusDB.roleBasedColors and "on" or "off")
    elseif msg == "counter" then
        TinyThreatPlusDB.showTargetCounter = not TinyThreatPlusDB.showTargetCounter
        print("TinyThreatPlus target counter:", TinyThreatPlusDB.showTargetCounter and "on" or "off")
    elseif msg == "smooth" then
        TinyThreatPlusDB.smoothThreat = not TinyThreatPlusDB.smoothThreat
        smoothedValues = {}
        print("TinyThreatPlus threat smoothing:", TinyThreatPlusDB.smoothThreat and "on" or "off")
    elseif msg == "reset" then
        TinyThreatPlus_ResetDefaults()
        print("TinyThreatPlus settings reset.")
    else
        print("TinyThreatPlus commands:")
        print("/ttp on")
        print("/ttp off")
        print("/ttp pets")
        print("/ttp colors")
        print("/ttp rolecolors")
        print("/ttp counter")
        print("/ttp smooth")
        print("/ttp reset")
    end

    TinyThreatPlus_UpdateAll(0.08)
end