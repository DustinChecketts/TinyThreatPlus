local ADDON_NAME = ...
local TTP = CreateFrame("Frame", "TinyThreatPlusFrame")

TinyThreatPlusDB = TinyThreatPlusDB or {}

local DB_DEFAULTS = {
    showNameplates = true,
    showTargetFrame = true,
    alwaysShowThreatBoxes = true,

    roleBasedColors = true,
    showTargetCounter = true,
    enemyPlayerClassColors = true,
    friendlyPlayerClassColors = false,

    displayMode = "VALUE",

    nameplateFontSize = 14,
    nameplateBoxWidth = 52,
    nameplateBoxHeight = 22,
    nameplateXOffset = 1,
    nameplateYOffset = 0,

    targetFontSize = 12,
    targetBoxWidth = 52,
    targetBoxHeight = 20,
    targetXOffset = 0,
    targetYOffset = 2,
}

TinyThreatPlusDefaults = DB_DEFAULTS

local activeNameplates = {}
local elapsedSinceUpdate = 0
local isApplyingColor = false

local COLORS = {
    good = { 0.10, 0.85, 0.10 },
    warn = { 1.00, 0.82, 0.00 },
    bad = { 1.00, 0.10, 0.10 },

    bg = { 0.02, 0.02, 0.02, 0.86 },
    border = { 0.72, 0.72, 0.72, 1.00 },
}

local function GetCVarValue(name)
    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar(name)
    end

    if GetCVar then
        return GetCVar(name)
    end

    return nil
end

local function SetCVarValue(name, enabled)
    local value = enabled and "1" or "0"

    if GetCVarValue(name) == value then
        return
    end

    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar(name, value)
    elseif SetCVar then
        SetCVar(name, value)
    end
end

function TinyThreatPlus_ApplyClassColorSettings()
    SetCVarValue(
        "nameplateShowClassColor",
        TinyThreatPlusDB.enemyPlayerClassColors
    )

    SetCVarValue(
        "nameplateShowFriendlyClassColor",
        TinyThreatPlusDB.friendlyPlayerClassColors
    )
end

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

    TinyThreatPlus_ApplyClassColorSettings()

    if TinyThreatPlus_UpdateAll then
        TinyThreatPlus_UpdateAll()
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

local function GetGroupUnits()
    local units = { "player" }

    if IsInRaid() then
        for i = 1, 40 do
            local unit = "raid" .. i
            if UnitExists(unit) then
                table.insert(units, unit)
            end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                table.insert(units, unit)
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
    local highestOtherThreat = 0
    local hasThreatData = playerThreat ~= nil

    for _, groupUnit in ipairs(GetGroupUnits()) do
        if groupUnit ~= "player" and UnitExists(groupUnit) then
            local _, _, _, _, threatValue = UnitDetailedThreatSituation(groupUnit, unit)

            if threatValue ~= nil then
                hasThreatData = true

                if threatValue > highestOtherThreat then
                    highestOtherThreat = threatValue
                end
            end
        end
    end

    if not hasThreatData and not TinyThreatPlusDB.alwaysShowThreatBoxes then
        return nil
    end

    playerThreat = playerThreat or 0

    local lead = (playerThreat - highestOtherThreat) / 100
    local percent

    if highestOtherThreat > 0 then
        percent = ((playerThreat - highestOtherThreat) / highestOtherThreat) * 100
    elseif playerThreat > 0 then
        percent = 100
    else
        percent = 0
    end

    return lead, percent, hasThreatData
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

    for _, groupUnit in ipairs(GetGroupUnits()) do
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

    return math.floor(22 * relativeScale + 0.5)
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

    local fontSize

    if isNameplate then
        fontSize = tonumber(TinyThreatPlusDB.nameplateFontSize) or 14
    else
        fontSize = tonumber(TinyThreatPlusDB.targetFontSize) or 12
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

local function IsHostileNameplateUnit(unit)
    return unit
        and UnitExists(unit)
        and not UnitIsPlayer(unit)
        and UnitCanAttack("player", unit)
        and not UnitIsFriend("player", unit)
end

local function ClearNameplateAssignment(nameplate, healthBar)
    healthBar = healthBar
        or (nameplate and nameplate.TinyThreatPlusHealthBar)
        or FindNameplateHealthBar(nameplate)

    if healthBar then
        healthBar.TinyThreatPlusUnit = nil
    end

    if nameplate then
        nameplate.TinyThreatPlusHealthBar = nil

        if nameplate.TinyThreatPlusBox then
            nameplate.TinyThreatPlusBox:Hide()
        end
    end
end

local function GetNameplateBoxHeight()
    return math.max(6, math.min(40, tonumber(TinyThreatPlusDB.nameplateBoxHeight) or 22))
end

local function ApplyNameplateColor(healthBar, unit, lead)
    if not TinyThreatPlusDB.roleBasedColors
        or not healthBar
        or not healthBar.SetStatusBarColor
        or not IsHostileNameplateUnit(unit)
    then
        return
    end

    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate or FindNameplateHealthBar(nameplate) ~= healthBar then
        healthBar.TinyThreatPlusUnit = nil
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
        if isApplyingColor or not TinyThreatPlusDB.roleBasedColors then
            return
        end

        local hookedUnit = bar.TinyThreatPlusUnit

        if not IsHostileNameplateUnit(hookedUnit) then
            bar.TinyThreatPlusUnit = nil
            return
        end

        local nameplate = C_NamePlate.GetNamePlateForUnit(hookedUnit)
        if not nameplate or FindNameplateHealthBar(nameplate) ~= bar then
            bar.TinyThreatPlusUnit = nil
            return
        end

        local lead = GetThreatData(hookedUnit)
        if lead ~= nil then
            ApplyNameplateColor(bar, hookedUnit, lead)
        end
    end)
end

local function UpdateNameplate(unit)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)

    if not nameplate or nameplate:IsForbidden() then
        return
    end

    local healthBar = FindNameplateHealthBar(nameplate)

    if not TinyThreatPlusDB.showNameplates then
        ClearNameplateAssignment(nameplate, healthBar)
        return
    end

    if not healthBar or not IsHostileNameplateUnit(unit) then
        ClearNameplateAssignment(nameplate, healthBar)
        return
    end

    local box = EnsureThreatBox(nameplate, "TinyThreatPlusBox", nil)
    local lead, percent, hasThreatData = GetThreatData(unit)

    if lead == nil then
        healthBar.TinyThreatPlusUnit = nil
        box:Hide()
        return
    end

    nameplate.TinyThreatPlusHealthBar = healthBar
    healthBar.TinyThreatPlusUnit = unit
    HookHealthBarColor(healthBar)

    local display = GetDisplayRawValue(lead, percent)
    local height = GetNameplateBoxHeight()
    local r, g, b = GetThreatColor(unit, lead)
    local counter = GetTargetCounter(unit)
    local extraOffset = GetClassicScaledOffset(healthBar)

    box:ClearAllPoints()
    box:SetPoint(
        "LEFT",
        healthBar,
        "RIGHT",
        (TinyThreatPlusDB.nameplateXOffset or 1) + extraOffset,
        TinyThreatPlusDB.nameplateYOffset or 0
    )

    UpdateThreatBox(
        box,
        TinyThreatPlusDB.nameplateBoxWidth or 52,
        height,
        FormatDisplayValue(display),
        r,
        g,
        b,
        counter,
        true
    )

    if hasThreatData then
        ApplyNameplateColor(healthBar, unit, lead)
    end
end

local function HideNameplate(unit)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)

    if nameplate then
        ClearNameplateAssignment(nameplate)
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

local function UpdateTargetFrame()
    local box = EnsureTargetBox()

    if not TinyThreatPlusDB.showTargetFrame or not UnitExists("target") then
        box:Hide()
        return
    end

    local lead, percent = GetThreatData("target")
    if lead == nil then
        box:Hide()
        return
    end

    local anchor = FindTargetNameAnchor()
    if not anchor then
        box:Hide()
        return
    end

    local display = GetDisplayRawValue(lead, percent)
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
        TinyThreatPlusDB.targetBoxHeight or 20,
        FormatDisplayValue(display),
        r,
        g,
        b,
        counter,
        false
    )
end

function TinyThreatPlus_UpdateAll()
    TinyThreatPlus_ApplyDefaults()

    for unit in pairs(activeNameplates) do
        if UnitExists(unit) then
            UpdateNameplate(unit)
        else
            activeNameplates[unit] = nil
        end
    end

    UpdateTargetFrame()
end

TTP:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        TinyThreatPlus_ApplyDefaults()
        TinyThreatPlus_ApplyClassColorSettings()
        TinyThreatPlus_UpdateAll()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        activeNameplates[arg1] = true
        UpdateNameplate(arg1)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        activeNameplates[arg1] = nil
        HideNameplate(arg1)
    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateTargetFrame()
    elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_THREAT_SITUATION_UPDATE" then
        TinyThreatPlus_UpdateAll()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
        TinyThreatPlus_UpdateAll()
    end
end)

TTP:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed

    if elapsedSinceUpdate >= 0.08 then
        elapsedSinceUpdate = 0
        TinyThreatPlus_UpdateAll()
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

    if msg == "colors" then
        TinyThreatPlusDB.roleBasedColors = not TinyThreatPlusDB.roleBasedColors
        print("TinyThreatPlus role-based nameplate colors:", TinyThreatPlusDB.roleBasedColors and "on" or "off")
    elseif msg == "enemyclass" then
        TinyThreatPlusDB.enemyPlayerClassColors = not TinyThreatPlusDB.enemyPlayerClassColors
        TinyThreatPlus_ApplyClassColorSettings()
        print("TinyThreatPlus enemy player class colors:", TinyThreatPlusDB.enemyPlayerClassColors and "on" or "off")
    elseif msg == "friendlyclass" then
        TinyThreatPlusDB.friendlyPlayerClassColors = not TinyThreatPlusDB.friendlyPlayerClassColors
        TinyThreatPlus_ApplyClassColorSettings()
        print("TinyThreatPlus friendly player class colors:", TinyThreatPlusDB.friendlyPlayerClassColors and "on" or "off")
    elseif msg == "counter" then
        TinyThreatPlusDB.showTargetCounter = not TinyThreatPlusDB.showTargetCounter
        print("TinyThreatPlus target counter:", TinyThreatPlusDB.showTargetCounter and "on" or "off")
    elseif msg == "preview" then
        TinyThreatPlusDB.alwaysShowThreatBoxes = not TinyThreatPlusDB.alwaysShowThreatBoxes
        print("TinyThreatPlus always show threat boxes:", TinyThreatPlusDB.alwaysShowThreatBoxes and "on" or "off")
    elseif msg == "reset" then
        TinyThreatPlus_ResetDefaults()
        print("TinyThreatPlus settings reset.")
    else
        print("TinyThreatPlus commands:")
        print("/ttp colors")
        print("/ttp enemyclass")
        print("/ttp friendlyclass")
        print("/ttp counter")
        print("/ttp preview")
        print("/ttp reset")
    end

    TinyThreatPlus_UpdateAll()
end
