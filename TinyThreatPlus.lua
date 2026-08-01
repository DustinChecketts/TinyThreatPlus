local ADDON_NAME = ...
local addon = CreateFrame("Frame", "TinyThreatPlusFrame")
TinyThreatPlusDB = TinyThreatPlusDB or {}
local DEFAULTS = {
    showNameplates = true,
    showTargetFrame = true,
    showMobLevel = true,
    showFriendlyLevel = true,
    showRareBorders = true,
    levelPosition = 2,
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
TinyThreatPlusDefaults = DEFAULTS
local COLORS = {
    good = { 0.10, 0.85, 0.10 },
    warn = { 1.00, 0.82, 0.00 },
    bad = { 1.00, 0.10, 0.10 },
    background = { 0.02, 0.02, 0.02, 0.86 },
    border = { 0.72, 0.72, 0.72, 1.00 },
    gold = { 0.92, 0.72, 0.18, 0.95 },
}
local CLASSIFICATION_ATLASES = {
    elite = {
        atlas = "nameplates-icon-elite-gold",
        desaturated = false,
        color = { 1, 1, 1, 1 },
    },
    worldboss = {
        atlas = "nameplates-icon-elite-gold",
        desaturated = false,
        color = { 1, 1, 1, 1 },
    },
    rareelite = {
        atlas = "nameplates-icon-elite-silver",
        desaturated = false,
        color = { 1, 1, 1, 1 },
    },
    rare = {
        atlas = "nameplates-icon-elite-silver",
        desaturated = true,
        color = { 0.78, 0.79, 0.82, 1.00 },
    },
}
local activeNameplates = {}
local updateElapsed = 0
local applyingHealthColor = false
local function ApplyDefaults()
    TinyThreatPlusDB = TinyThreatPlusDB or {}
    for key, value in pairs(DEFAULTS) do
        if TinyThreatPlusDB[key] == nil then
            TinyThreatPlusDB[key] = value
        end
    end
end
function TinyThreatPlus_ApplyDefaults()
    ApplyDefaults()
end
local function GetCVarValue(name)
    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar(name)
    end
    if GetCVar then
        return GetCVar(name)
    end
end
local function SetBooleanCVar(name, enabled)
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
    ApplyDefaults()
    SetBooleanCVar(
        "nameplateShowClassColor",
        TinyThreatPlusDB.enemyPlayerClassColors
    )
    SetBooleanCVar(
        "nameplateShowFriendlyClassColor",
        TinyThreatPlusDB.friendlyPlayerClassColors
    )
end
function TinyThreatPlus_ResetDefaults()
    TinyThreatPlusDB = {}
    for key, value in pairs(DEFAULTS) do
        TinyThreatPlusDB[key] = value
    end
    TinyThreatPlus_ApplyClassColorSettings()
    if TinyThreatPlus_UpdateAll then
        TinyThreatPlus_UpdateAll()
    end
end
local function Round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end
local function Abbreviate(value)
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
local function FormatSignedValue(value)
    if TinyThreatPlusDB.displayMode == "PERCENT" then
        value = Round(value)
        if value > 0 then
            return "+" .. value .. "%"
        elseif value < 0 then
            return value .. "%"
        end
        return "0%"
    end
    if value > 0 then
        return "+" .. Abbreviate(value)
    elseif value < 0 then
        return "-" .. Abbreviate(value)
    end
    return "0"
end
local function GetGroupUnits()
    local units = { "player" }
    if IsInRaid() then
        for index = 1, 40 do
            local unit = "raid" .. index
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                units[#units + 1] = unit
            end
        end
    elseif IsInGroup() then
        for index = 1, 4 do
            local unit = "party" .. index
            if UnitExists(unit) then
                units[#units + 1] = unit
            end
        end
    end
    return units
end
local function GetThreatData(unit)
    if not unit
        or not UnitExists(unit)
        or UnitIsDead(unit)
        or UnitIsPlayer(unit)
        or not UnitCanAttack("player", unit)
    then
        return nil
    end
    local _, _, _, _, playerThreat =
        UnitDetailedThreatSituation("player", unit)
    local highestOtherThreat = 0
    local hasThreatData = playerThreat ~= nil
    for _, groupUnit in ipairs(GetGroupUnits()) do
        if not UnitIsUnit(groupUnit, "player") then
            local _, _, _, _, threat =
                UnitDetailedThreatSituation(groupUnit, unit)
            if threat ~= nil then
                hasThreatData = true
                highestOtherThreat = math.max(highestOtherThreat, threat)
            end
        end
    end
    if not hasThreatData and not TinyThreatPlusDB.alwaysShowThreatBoxes then
        return nil
    end
    playerThreat = playerThreat or 0
    local lead = (playerThreat - highestOtherThreat) / 100
    local percent = 0
    if highestOtherThreat > 0 then
        percent =
            ((playerThreat - highestOtherThreat) / highestOtherThreat) * 100
    elseif playerThreat > 0 then
        percent = 100
    end
    return lead, percent, hasThreatData
end
local function GetTargetCounter(unit)
    if not TinyThreatPlusDB.showTargetCounter
        or (not IsInGroup() and not IsInRaid())
    then
        return nil
    end
    local targetGUID = UnitGUID(unit)
    if not targetGUID then
        return nil
    end
    local count = 0
    for _, groupUnit in ipairs(GetGroupUnits()) do
        local targetUnit = groupUnit .. "target"
        if UnitExists(targetUnit) and UnitGUID(targetUnit) == targetGUID then
            count = count + 1
        end
    end
    return count > 0 and count or nil
end
local function PlayerIsTank()
    return TinyThreatPlusDB.roleBasedColors
        and UnitGroupRolesAssigned
        and UnitGroupRolesAssigned("player") == "TANK"
end
local function GetThreatColor(unit, lead)
    local status = UnitThreatSituation("player", unit)
    if PlayerIsTank() then
        if status == 3 and lead and lead >= 0 then
            return unpack(COLORS.good)
        elseif status == 1 or status == 2 then
            return unpack(COLORS.warn)
        end
        return unpack(COLORS.bad)
    end
    if status == 3 and lead and lead >= 0 then
        return unpack(COLORS.bad)
    elseif status == 1 or status == 2 then
        return unpack(COLORS.warn)
    end
    return unpack(COLORS.good)
end
local function GetDisplayValue(lead, percent)
    if TinyThreatPlusDB.displayMode == "PERCENT" then
        return percent or 0
    end
    return lead or 0
end
local function IsClassicNameplateStyle()
    return GetCVarValue("nameplateStyle") == "0"
end
local function GetClassicLevelOffset(healthBar)
    if not IsClassicNameplateStyle() then
        return 0
    end
    local barScale =
        healthBar.GetEffectiveScale and healthBar:GetEffectiveScale() or 1
    local uiScale =
        UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    return math.floor(22 * (barScale / uiScale) + 0.5)
end
local function ApplyBoxStyle(frame, height)
    local edgeSize = 10
    local inset = 2
    if height <= 10 then
        edgeSize = 6
        inset = 1
    elseif height <= 14 then
        edgeSize = 8
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
        insets = {
            left = inset,
            right = inset,
            top = inset,
            bottom = inset,
        },
    })
    frame:SetBackdropColor(unpack(COLORS.background))
    frame:SetBackdropBorderColor(unpack(COLORS.border))
end
local function CreateThreatBox(parent, key, globalName)
    if parent[key] then
        return parent[key]
    end
    local box =
        CreateFrame("Frame", globalName, parent, "BackdropTemplate")
    box:SetFrameStrata(parent:GetFrameStrata())
    box:SetFrameLevel((parent:GetFrameLevel() or 1) + 30)
    box.text =
        box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    box.text:SetPoint("CENTER")
    box.text:SetJustifyH("CENTER")
    box.text:SetJustifyV("MIDDLE")
    box.counterRing = box:CreateTexture(nil, "ARTWORK")
    box.counterRing:SetSize(18, 18)
    box.counterRing:SetAtlas("PetJournal-LevelBubble")
    box.counterRing:SetPoint("CENTER", box, "RIGHT", 5, 0)
    box.counterRing:Hide()
    box.counterText =
        box:CreateFontString(nil, "OVERLAY", "GameNormalNumberFont")
    box.counterText:SetSize(18, 18)
    box.counterText:SetJustifyH("CENTER")
    box.counterText:SetJustifyV("MIDDLE")
    box.counterText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    box.counterText:SetTextColor(1, 1, 1)
    box.counterText:Hide()
    box:Hide()
    parent[key] = box
    return box
end
local function UpdateCounter(box, count)
    if not count then
        box.counterRing:Hide()
        box.counterText:Hide()
        return
    end
    local xOffset = count < 10 and -0.5 or 0
    local fontSize = count < 10 and 10 or 9
    box.counterText:ClearAllPoints()
    box.counterText:SetPoint(
        "CENTER",
        box.counterRing,
        "CENTER",
        xOffset,
        0
    )
    box.counterText:SetFont(
        STANDARD_TEXT_FONT,
        fontSize,
        "OUTLINE"
    )
    box.counterText:SetText(count)
    box.counterRing:Show()
    box.counterText:Show()
end
local function UpdateThreatBox(
    box,
    width,
    height,
    fontSize,
    text,
    red,
    green,
    blue,
    counter
)
    ApplyBoxStyle(box, height)
    box:SetSize(width, height)
    box.text:SetFont(
        STANDARD_TEXT_FONT,
        fontSize,
        "OUTLINE"
    )
    box.text:SetText(text)
    box.text:SetTextColor(red, green, blue)
    UpdateCounter(box, counter)
    box:Show()
end
local function GetNameplateHealthBar(nameplate)
    local unitFrame = nameplate and nameplate.UnitFrame
    if not unitFrame then
        return nil
    end
    if unitFrame.HealthBarsContainer
        and unitFrame.HealthBarsContainer.healthBar
    then
        return unitFrame.HealthBarsContainer.healthBar
    end
    return unitFrame.healthBar or unitFrame.HealthBar
end
local function IsHostileNPC(unit)
    return unit
        and UnitExists(unit)
        and not UnitIsPlayer(unit)
        and UnitCanAttack("player", unit)
        and not UnitIsFriend("player", unit)
end
local function ShouldShowLevel(unit)
    if not unit or not UnitExists(unit) or UnitIsPlayer(unit) then
        return false
    end
    if UnitCanAttack("player", unit) then
        return TinyThreatPlusDB.showMobLevel
    end
    return UnitIsFriend("player", unit)
        and TinyThreatPlusDB.showFriendlyLevel
end
local function GetDifficultyColor(level)
    if GetQuestDifficultyColor then
        local color = GetQuestDifficultyColor(level)
        if color then
            return color.r or 1, color.g or 1, color.b or 1
        end
    end
    local difference = level - (UnitLevel("player") or level)
    if difference >= 5 then
        return 1.00, 0.10, 0.10
    elseif difference >= 3 then
        return 1.00, 0.50, 0.00
    elseif difference >= -2 then
        return 1.00, 1.00, 0.00
    elseif difference >= -5 then
        return 0.10, 1.00, 0.10
    end
    return 0.50, 0.50, 0.50
end
local function CreateLevelBadge(nameplate)
    if nameplate.TinyThreatPlusLevel then
        return nameplate.TinyThreatPlusLevel
    end
    local badge = CreateFrame("Frame", nil, nameplate)
    badge:SetFrameStrata(nameplate:GetFrameStrata())
    badge:SetFrameLevel((nameplate:GetFrameLevel() or 1) + 32)
    badge:SetSize(24, 24)
    badge.fill = badge:CreateTexture(nil, "BACKGROUND")
    badge.fill:SetAllPoints()
    badge.fill:SetColorTexture(
        COLORS.background[1],
        COLORS.background[2],
        COLORS.background[3],
        0.32
    )
    badge.mask = badge:CreateMaskTexture(nil, "BACKGROUND")
    badge.mask:SetAllPoints()
    badge.mask:SetTexture(
        "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
    )
    badge.fill:AddMaskTexture(badge.mask)
    badge.ring = badge:CreateTexture(nil, "BORDER")
    badge.ring:SetAllPoints()
    badge.ring:SetAtlas("plunderstorm-nameplates-icon-ring")
    badge.ring:SetDesaturated(true)
    badge.ring:SetVertexColor(unpack(COLORS.border))
    badge.text =
        badge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    badge.text:SetSize(24, 24)
    badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0)
    badge.text:SetJustifyH("CENTER")
    badge.text:SetJustifyV("MIDDLE")
    badge.text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    badge.skull = badge:CreateTexture(nil, "OVERLAY")
    badge.skull:SetSize(14, 14)
    badge.skull:SetPoint("CENTER")
    badge.skull:SetTexture(
        "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
    )
    badge.skull:Hide()
    badge:Hide()
    nameplate.TinyThreatPlusLevel = badge
    return badge
end
local function GetClassificationFrame(nameplate)
    local unitFrame = nameplate and nameplate.UnitFrame
    return unitFrame
        and unitFrame.ClassificationFrame
        or nil
end
local function ResetClassificationFrame(nameplate)
    local unitFrame = nameplate and nameplate.UnitFrame
    local frame = unitFrame and unitFrame.ClassificationFrame
    if not frame or not frame.TinyThreatPlusModified then
        return
    end
    frame:ClearAllPoints()
    if unitFrame.RaidTargetFrame then
        frame:SetPoint(
            "RIGHT",
            unitFrame.RaidTargetFrame,
            "LEFT",
            0,
            0
        )
    end
    frame:SetSize(20, 20)
    frame:SetScale(1)
    local indicator = frame.classificationIndicator
    if indicator then
        indicator:ClearAllPoints()
        indicator:SetPoint("CENTER")
        indicator:SetSize(20, 20)
        indicator:SetDesaturated(false)
        indicator:SetVertexColor(1, 1, 1, 1)
        indicator:SetDrawLayer("OVERLAY")
    end
    frame.TinyThreatPlusModified = nil
    if frame.UpdateClassificationIndicator then
        frame:UpdateClassificationIndicator()
    elseif frame.UpdateShownState then
        frame:UpdateShownState()
    end
end
local function UpdateClassificationFrame(nameplate, healthBar, unit)
    local frame = GetClassificationFrame(nameplate)
    local indicator = frame and frame.classificationIndicator
    local classification = UnitClassification(unit)
    local style = CLASSIFICATION_ATLASES[classification]
    if not TinyThreatPlusDB.showRareBorders
        or not IsHostileNPC(unit)
        or not style
        or not frame
        or not indicator
    then
        ResetClassificationFrame(nameplate)
        return nil
    end
    frame:ClearAllPoints()

    -- Leave the level badge anchored consistently to the health bar,
    -- but shift classification artwork farther left so the badge does
    -- not cover most of the dragon.
    frame:SetPoint("RIGHT", healthBar, "LEFT", -7, 0)
    frame:SetSize(20, 20)
    frame:SetScale(1)
    indicator:ClearAllPoints()
    indicator:SetPoint("CENTER")
    indicator:SetSize(20, 20)
    indicator:SetAtlas(style.atlas, false)
    indicator:SetDesaturated(style.desaturated)
    indicator:SetVertexColor(unpack(style.color))
    indicator:SetDrawLayer("OVERLAY", 1)
    frame.TinyThreatPlusModified = true
    frame:Show()
    indicator:Show()
    return frame
end
local function HideLevelBadge(nameplate)
    if nameplate and nameplate.TinyThreatPlusLevel then
        nameplate.TinyThreatPlusLevel:Hide()
    end
end
local function UpdateLevelAndClassification(nameplate, healthBar, unit)
    local classificationFrame =
        UpdateClassificationFrame(nameplate, healthBar, unit)
    if not ShouldShowLevel(unit) then
        HideLevelBadge(nameplate)
        return
    end
    local level = UnitLevel(unit)
    if not level or level == 0 then
        HideLevelBadge(nameplate)
        return
    end
    local badge = CreateLevelBadge(nameplate)
    local classification = UnitClassification(unit)
    badge.ring:SetDesaturated(true)
    if classification == "elite"
        or classification == "rareelite"
        or classification == "worldboss"
    then
        badge.ring:SetVertexColor(unpack(COLORS.gold))
    else
        badge.ring:SetVertexColor(unpack(COLORS.border))
    end
    badge:ClearAllPoints()

    local levelPosition =
        tonumber(TinyThreatPlusDB.levelPosition) or 2

    local healthBarHeight = healthBar:GetHeight() or 0
    local yOffset = 0

    if levelPosition == 1 then
        yOffset = healthBarHeight / 2
    elseif levelPosition == 3 then
        yOffset = -(healthBarHeight / 2)
    end

    -- Always position the level relative to the health bar itself.
    -- Classification artwork remains centered on the bar's left edge,
    -- so rare and normal mobs use identical level placement.
    badge:SetPoint(
        "CENTER",
        healthBar,
        "LEFT",
        -4,
        yOffset
    )
    if level < 0 then
        badge.text:Hide()
        badge.skull:Show()
    else
        local red, green, blue = GetDifficultyColor(level)
        badge.skull:Hide()

        local levelText = tostring(level)
        local fontSize = #levelText >= 2 and 9 or 10
        local xOffset = #levelText == 1 and 1 or 0

        badge.text:SetFont(
            STANDARD_TEXT_FONT,
            fontSize,
            "OUTLINE"
        )

        badge.text:ClearAllPoints()
        badge.text:SetPoint(
            "CENTER",
            badge,
            "CENTER",
            xOffset,
            0
        )

        badge.text:SetText(levelText)
        badge.text:SetTextColor(red, green, blue)
        badge.text:Show()
    end
    badge:Show()
end
local function RestoreHealthBarColor(nameplate)
    local unitFrame = nameplate and nameplate.UnitFrame
    if unitFrame and CompactUnitFrame_UpdateHealthColor then
        CompactUnitFrame_UpdateHealthColor(unitFrame)
    end
end
local function ClearNameplate(nameplate)
    if not nameplate then
        return
    end
    local healthBar =
        nameplate.TinyThreatPlusHealthBar
        or GetNameplateHealthBar(nameplate)
    if healthBar then
        healthBar.TinyThreatPlusUnit = nil
    end
    if nameplate.TinyThreatPlusBox then
        nameplate.TinyThreatPlusBox:Hide()
    end
    HideLevelBadge(nameplate)
    ResetClassificationFrame(nameplate)
    RestoreHealthBarColor(nameplate)
    nameplate.TinyThreatPlusHealthBar = nil
end
local function ApplyNameplateColor(healthBar, unit, lead)
    if not TinyThreatPlusDB.roleBasedColors
        or not healthBar
        or not healthBar.SetStatusBarColor
        or not IsHostileNPC(unit)
    then
        return
    end
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate or GetNameplateHealthBar(nameplate) ~= healthBar then
        healthBar.TinyThreatPlusUnit = nil
        return
    end
    local red, green, blue = GetThreatColor(unit, lead)
    applyingHealthColor = true
    healthBar:SetStatusBarColor(red, green, blue)
    applyingHealthColor = false
end
local function HookHealthBarColor(healthBar)
    if not healthBar or healthBar.TinyThreatPlusHooked then
        return
    end
    healthBar.TinyThreatPlusHooked = true
    hooksecurefunc(healthBar, "SetStatusBarColor", function(bar)
        if applyingHealthColor or not TinyThreatPlusDB.roleBasedColors then
            return
        end
        local unit = bar.TinyThreatPlusUnit
        if not IsHostileNPC(unit) then
            bar.TinyThreatPlusUnit = nil
            return
        end
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
        if not nameplate or GetNameplateHealthBar(nameplate) ~= bar then
            bar.TinyThreatPlusUnit = nil
            return
        end
        local lead = GetThreatData(unit)
        if lead ~= nil then
            ApplyNameplateColor(bar, unit, lead)
        end
    end)
end
local function UpdateNameplate(unit)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate or nameplate:IsForbidden() then
        return
    end
    local healthBar = GetNameplateHealthBar(nameplate)
    if not healthBar then
        ClearNameplate(nameplate)
        return
    end
    nameplate.TinyThreatPlusHealthBar = healthBar
    UpdateLevelAndClassification(nameplate, healthBar, unit)
    if not IsHostileNPC(unit) then
        healthBar.TinyThreatPlusUnit = nil
        if nameplate.TinyThreatPlusBox then
            nameplate.TinyThreatPlusBox:Hide()
        end
        return
    end
    if not TinyThreatPlusDB.showNameplates then
        healthBar.TinyThreatPlusUnit = nil
        if nameplate.TinyThreatPlusBox then
            nameplate.TinyThreatPlusBox:Hide()
        end
        RestoreHealthBarColor(nameplate)
        return
    end
    local lead, percent, hasThreatData = GetThreatData(unit)
    if lead == nil then
        healthBar.TinyThreatPlusUnit = nil
        if nameplate.TinyThreatPlusBox then
            nameplate.TinyThreatPlusBox:Hide()
        end
        return
    end
    healthBar.TinyThreatPlusUnit = unit
    HookHealthBarColor(healthBar)
    local box =
        CreateThreatBox(nameplate, "TinyThreatPlusBox", nil)
    local red, green, blue = GetThreatColor(unit, lead)
    local height =
        math.max(
            6,
            math.min(
                40,
                tonumber(TinyThreatPlusDB.nameplateBoxHeight) or 22
            )
        )
    box:ClearAllPoints()
    box:SetPoint(
        "LEFT",
        healthBar,
        "RIGHT",
        (TinyThreatPlusDB.nameplateXOffset or 1)
            + GetClassicLevelOffset(healthBar),
        TinyThreatPlusDB.nameplateYOffset or 0
    )
    UpdateThreatBox(
        box,
        TinyThreatPlusDB.nameplateBoxWidth or 52,
        height,
        TinyThreatPlusDB.nameplateFontSize or 14,
        FormatSignedValue(GetDisplayValue(lead, percent)),
        red,
        green,
        blue,
        GetTargetCounter(unit)
    )
    if hasThreatData and TinyThreatPlusDB.roleBasedColors then
        ApplyNameplateColor(healthBar, unit, lead)
    elseif not TinyThreatPlusDB.roleBasedColors then
        RestoreHealthBarColor(nameplate)
    end
end
local function GetTargetNameAnchor()
    return TargetFrameTextureFrameName
        or (TargetFrame and TargetFrame.name)
        or TargetFrameName
        or TargetFrame
end
local function GetTargetBox()
    if addon.targetBox then
        return addon.targetBox
    end
    local parent = TargetFrameTextureFrame or TargetFrame or UIParent
    addon.targetBox =
        CreateThreatBox(
            parent,
            "TinyThreatPlusTargetBox",
            "TinyThreatPlusTargetBox"
        )
    return addon.targetBox
end
local function UpdateTargetFrame()
    local box = GetTargetBox()
    if not TinyThreatPlusDB.showTargetFrame
        or not UnitExists("target")
    then
        box:Hide()
        return
    end
    local lead, percent = GetThreatData("target")
    if lead == nil then
        box:Hide()
        return
    end
    local anchor = GetTargetNameAnchor()
    if not anchor then
        box:Hide()
        return
    end
    local red, green, blue = GetThreatColor("target", lead)
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
        TinyThreatPlusDB.targetFontSize or 12,
        FormatSignedValue(GetDisplayValue(lead, percent)),
        red,
        green,
        blue,
        GetTargetCounter("target")
    )
end
function TinyThreatPlus_UpdateAll()
    ApplyDefaults()
    for unit in pairs(activeNameplates) do
        if UnitExists(unit) then
            UpdateNameplate(unit)
        else
            activeNameplates[unit] = nil
        end
    end
    UpdateTargetFrame()
end
addon:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" then
        if unit ~= ADDON_NAME then
            return
        end
        ApplyDefaults()
        TinyThreatPlus_ApplyClassColorSettings()
        TinyThreatPlus_UpdateAll()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        activeNameplates[unit] = true
        UpdateNameplate(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
        activeNameplates[unit] = nil
        ClearNameplate(nameplate)
    else
        TinyThreatPlus_UpdateAll()
    end
end)
addon:SetScript("OnUpdate", function(_, elapsed)
    updateElapsed = updateElapsed + elapsed
    if updateElapsed < 0.08 then
        return
    end
    updateElapsed = 0
    TinyThreatPlus_UpdateAll()
end)
addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("NAME_PLATE_UNIT_ADDED")
addon:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
addon:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
addon:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
addon:RegisterEvent("PLAYER_TARGET_CHANGED")
addon:RegisterEvent("GROUP_ROSTER_UPDATE")
addon:RegisterEvent("PLAYER_ROLES_ASSIGNED")
addon:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
SLASH_TINYTHREATPLUS1 = "/ttp"
SLASH_TINYTHREATPLUS2 = "/tinythreatplus"
SlashCmdList.TINYTHREATPLUS = function(message)
    local command = string.lower(message or "")
    if command == "colors" then
        TinyThreatPlusDB.roleBasedColors =
            not TinyThreatPlusDB.roleBasedColors
        print(
            "TinyThreatPlus role-based nameplate colors:",
            TinyThreatPlusDB.roleBasedColors and "on" or "off"
        )
    elseif command == "enemyclass" then
        TinyThreatPlusDB.enemyPlayerClassColors =
            not TinyThreatPlusDB.enemyPlayerClassColors
        TinyThreatPlus_ApplyClassColorSettings()
        print(
            "TinyThreatPlus enemy player class colors:",
            TinyThreatPlusDB.enemyPlayerClassColors and "on" or "off"
        )
    elseif command == "friendlyclass" then
        TinyThreatPlusDB.friendlyPlayerClassColors =
            not TinyThreatPlusDB.friendlyPlayerClassColors
        TinyThreatPlus_ApplyClassColorSettings()
        print(
            "TinyThreatPlus friendly player class colors:",
            TinyThreatPlusDB.friendlyPlayerClassColors and "on" or "off"
        )
    elseif command == "levels" then
        TinyThreatPlusDB.showMobLevel =
            not TinyThreatPlusDB.showMobLevel
        print(
            "TinyThreatPlus enemy levels:",
            TinyThreatPlusDB.showMobLevel and "on" or "off"
        )
    elseif command == "friendlylevels" then
        TinyThreatPlusDB.showFriendlyLevel =
            not TinyThreatPlusDB.showFriendlyLevel
        print(
            "TinyThreatPlus friendly levels:",
            TinyThreatPlusDB.showFriendlyLevel and "on" or "off"
        )
    elseif command == "rareborders" then
        TinyThreatPlusDB.showRareBorders =
            not TinyThreatPlusDB.showRareBorders
        print(
            "TinyThreatPlus classification icons:",
            TinyThreatPlusDB.showRareBorders and "on" or "off"
        )
    elseif command == "counter" then
        TinyThreatPlusDB.showTargetCounter =
            not TinyThreatPlusDB.showTargetCounter
        print(
            "TinyThreatPlus target counter:",
            TinyThreatPlusDB.showTargetCounter and "on" or "off"
        )
    elseif command == "preview" then
        TinyThreatPlusDB.alwaysShowThreatBoxes =
            not TinyThreatPlusDB.alwaysShowThreatBoxes
        print(
            "TinyThreatPlus always show threat boxes:",
            TinyThreatPlusDB.alwaysShowThreatBoxes and "on" or "off"
        )
    elseif command == "reset" then
        TinyThreatPlus_ResetDefaults()
        print("TinyThreatPlus settings reset.")
    else
        print("TinyThreatPlus commands:")
        print("/ttp colors")
        print("/ttp enemyclass")
        print("/ttp friendlyclass")
        print("/ttp levels")
        print("/ttp friendlylevels")
        print("/ttp rareborders")
        print("/ttp counter")
        print("/ttp preview")
        print("/ttp reset")
    end
    TinyThreatPlus_UpdateAll()
end
