local TTP = _G.TinyThreatPlus or select(2, ...)
if not TTP then return end

-- TinyThreatPlus custom nameplates
--
-- Blizzard owns discovery, visibility, world positioning and unit tokens.
-- TinyThreatPlus owns every visible element of the custom presentation.
-- We never resize or repurpose Blizzard's visual health/cast bars on Forever.
--
-- Lifecycle:
--   CreatePlate -> LayoutPlate -> UpdatePlate -> ResetPlate
--
-- Threat calculation remains in TinyThreatPlus.lua. Diagnostics remain in
-- ThreatDiagnostic.lua. This file is presentation only.

local BASE_WIDTH = 172
local BASE_BAR_HEIGHT = 20
local BAR_GAP = 3
local CAST_HEIGHT = 10

local function PixelSize(frame, width, height)
    if PixelUtil and PixelUtil.SetSize then
        PixelUtil.SetSize(frame, width, height)
    else
        frame:SetSize(width, height)
    end
end

local function PixelPoint(frame, point, relativeTo, relativePoint, x, y)
    if PixelUtil and PixelUtil.SetPoint then
        PixelUtil.SetPoint(frame, point, relativeTo, relativePoint, x, y)
    else
        frame:SetPoint(point, relativeTo, relativePoint, x, y)
    end
end

local function IsAccessible(value)
    return value ~= nil
        and not TTP.Compat.IsSecretValue(value)
        and TTP.Compat.CanAccessValue(value)
end

function TTP.GetNameplateHealthBar(nameplate)
    local unitFrame = nameplate and nameplate.UnitFrame
    if not unitFrame then return nil end
    local container = unitFrame.HealthBarsContainer
    if container and container.healthBar then return container.healthBar end
    return unitFrame.healthBar or unitFrame.HealthBar
end

local function GetNativeCastBar(nameplate)
    local unitFrame = nameplate and nameplate.UnitFrame
    if not unitFrame then return nil end
    local container = unitFrame.CastBarsContainer
    if container then
        return container.castBar or container.CastBar
    end
    return unitFrame.castBar or unitFrame.CastBar
end

local function GetCustomScale()
    return math.max(0.75, math.min(1.50,
        (tonumber(TinyThreatPlusDB.customNameplateScale) or 100) / 100))
end

local function GetBarHeight()
    return math.max(12, math.min(32,
        tonumber(TinyThreatPlusDB.customNameplateBarHeight) or BASE_BAR_HEIGHT))
end

local function SetStatusBarAtlas(bar, atlas)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    local texture = bar:GetStatusBarTexture()
    if texture and texture.SetAtlas then
        texture:SetAtlas(atlas, false)
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function CreateLevelBadge(parent)
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetFrameLevel(parent:GetFrameLevel() + 5)

    badge.art = badge:CreateTexture(nil, "ARTWORK")
    badge.art:SetAllPoints()
    badge.art:SetAtlas("UI-HUD-UnitFrame-SmallCircle", false)
    badge.art:SetIgnoreParentAlpha(true)

    badge.text = badge:CreateFontString(nil, "OVERLAY", "GameNormalNumberFont")
    badge.text:SetAllPoints()
    badge.text:SetJustifyH("CENTER")
    badge.text:SetJustifyV("MIDDLE")
    badge.text:SetFont(STANDARD_TEXT_FONT, 8, "")
    badge.text:SetTextColor(1, 1, 1)

    return badge
end

local function CreateThreatBox(parent)
    local box = TTP.CreateThreatBox(parent, nil)
    box:SetFrameLevel(parent:GetFrameLevel() + 6)
    return box
end

local function CreatePlate(nameplate)
    if nameplate.TinyThreatPlusPlate then
        return nameplate.TinyThreatPlusPlate
    end

    local unitFrame = nameplate.UnitFrame
    local plate = CreateFrame("Frame", nil, nameplate)
    plate:SetFrameStrata(nameplate:GetFrameStrata())
    plate:SetFrameLevel((unitFrame and unitFrame:GetFrameLevel() or 1) + 20)
    plate:Hide()

    plate.priority = plate:CreateTexture(nil, "BACKGROUND")
    plate.priority:SetTexture("Interface\\Buttons\\WHITE8X8")
    plate.priority:Hide()

    plate.health = CreateFrame("StatusBar", nil, plate)
    plate.health:SetFrameLevel(plate:GetFrameLevel() + 2)
    SetStatusBarAtlas(plate.health, "UI-HUD-CoolDownManager-Bar")

    plate.healthShell = plate:CreateTexture(nil, "BACKGROUND")
    plate.healthShell:SetAtlas("UI-HUD-CoolDownManager-Bar-BG", false)
    plate.healthShell:SetIgnoreParentAlpha(true)

    -- Border-only Blizzard overlay sits above the StatusBar fill. Bar-BG stays
    -- below as the empty-bar/background layer, so the fill can never paint
    -- over the chrome and the background cannot darken the fill.
    plate.healthBorder = plate:CreateTexture(nil, "OVERLAY")
    plate.healthBorder:SetAtlas("ui-hud-nameplates-deselected-overlay", false)
    plate.healthBorder:SetIgnoreParentAlpha(true)

    plate.targetHighlight = plate:CreateTexture(nil, "OVERLAY")
    plate.targetHighlight:SetAtlas("UI-HUD-CoolDownManager-Selected-yellow", false)
    plate.targetHighlight:SetDesaturated(true)
    plate.targetHighlight:SetIgnoreParentAlpha(true)
    plate.targetHighlight:Hide()

    plate.name = plate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    plate.name:SetJustifyH("LEFT")
    plate.name:SetTextColor(1, 1, 1)

    -- Text lives on a dedicated top frame so the selected-target artwork can
    -- never wash it out. A stronger shadow remains readable at world distance.
    plate.textLayer = CreateFrame("Frame", nil, plate)
    plate.textLayer:SetAllPoints(plate.health)
    plate.textLayer:SetFrameLevel(plate:GetFrameLevel() + 8)

    plate.healthPercent = plate.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    plate.healthPercent:SetJustifyH("LEFT")
    plate.healthPercent:SetTextColor(1, 1, 1)

    plate.healthPercent:SetShadowColor(0, 0, 0, 1)
    plate.healthPercent:SetShadowOffset(1, -1)

    plate.healthValue = plate.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    plate.healthValue:SetJustifyH("RIGHT")
    plate.healthValue:SetTextColor(1, 1, 1)
    plate.healthValue:SetShadowColor(0, 0, 0, 1)
    plate.healthValue:SetShadowOffset(1, -1)

    plate.level = CreateLevelBadge(plate)
    plate.threat = CreateThreatBox(plate)

    plate.cast = CreateFrame("StatusBar", nil, plate)
    plate.cast:SetFrameLevel(plate:GetFrameLevel() + 2)
    SetStatusBarAtlas(plate.cast, "UI-HUD-CoolDownManager-Bar")
    plate.cast:SetStatusBarColor(1.0, 0.70, 0.15)

    plate.castShell = plate:CreateTexture(nil, "BACKGROUND")
    plate.castShell:SetAtlas("UI-HUD-CoolDownManager-Bar-BG", false)
    plate.castShell:SetIgnoreParentAlpha(true)

    plate.castName = plate:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    plate.castName:SetJustifyH("LEFT")
    plate.castName:SetTextColor(1, 1, 1)
    plate.castName:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")
    plate.cast:Hide()
    plate.castShell:Hide()
    plate.castName:Hide()

    nameplate.TinyThreatPlusPlate = plate
    return plate
end

local function LayoutPlate(nameplate, plate)
    local unitFrame = nameplate.UnitFrame
    if not unitFrame then return end

    local height = GetBarHeight()
    local scale = GetCustomScale()

    plate:SetScale(scale)
    plate:ClearAllPoints()
    PixelPoint(plate, "BOTTOM", unitFrame, "BOTTOM", 0, 4)
    local threatWidth = math.max(28, math.min(60,
        tonumber(TinyThreatPlusDB.nameplateThreatWidth) or 36))
    PixelSize(plate, BASE_WIDTH + BAR_GAP + threatWidth, height + 28)

    plate.health:ClearAllPoints()
    PixelPoint(plate.health, "BOTTOMLEFT", plate, "BOTTOMLEFT", 0, 0)
    PixelSize(plate.health, BASE_WIDTH, height)

    local priorityPadding = 4 + math.max(1, math.min(6,
        tonumber(TinyThreatPlusDB.priorityMarkerSizeRating) or 3))
    plate.priority:ClearAllPoints()
    PixelPoint(plate.priority, "TOPLEFT", plate.health, "TOPLEFT", -priorityPadding, priorityPadding)
    PixelPoint(plate.priority, "BOTTOMRIGHT", plate.health, "BOTTOMRIGHT", priorityPadding, -priorityPadding)

    plate.healthShell:ClearAllPoints()
    PixelPoint(plate.healthShell, "CENTER", plate.health, "CENTER", 1, -1)
    PixelSize(plate.healthShell, BASE_WIDTH + 8, height + 9)

    plate.textLayer:ClearAllPoints()
    plate.textLayer:SetAllPoints(plate.health)

    plate.healthBorder:ClearAllPoints()
    PixelPoint(plate.healthBorder, "CENTER", plate.health, "CENTER", 0, 0)
    PixelSize(plate.healthBorder, BASE_WIDTH, height + 2)

    plate.targetHighlight:ClearAllPoints()
    PixelPoint(plate.targetHighlight, "CENTER", plate.health, "CENTER", 0, 0)
    PixelSize(plate.targetHighlight, BASE_WIDTH + 11, height + 9)

    plate.name:ClearAllPoints()
    PixelPoint(plate.name, "BOTTOMLEFT", plate.health, "TOPLEFT", 0, 2)
    plate.name:SetWidth(BASE_WIDTH)
    plate.name:SetHeight(18)
    local nameSize = math.max(8, math.min(18,
        tonumber(TinyThreatPlusDB.customNameFontSize) or 10))
    local nameColor = TinyThreatPlusDB.customNameFontColor
        or TTP.defaults.customNameFontColor
        or { 1, 1, 1 }
    plate.name:SetFont(STANDARD_TEXT_FONT, nameSize, "OUTLINE")
    plate.name:SetTextColor(nameColor[1] or 1, nameColor[2] or 1, nameColor[3] or 1)
    if TinyThreatPlusDB.customNameFontShadow then
        plate.name:SetShadowColor(0, 0, 0, 1)
        plate.name:SetShadowOffset(1, -1)
    else
        plate.name:SetShadowColor(0, 0, 0, 0)
        plate.name:SetShadowOffset(0, 0)
    end

    local healthFont = height < 17 and 8 or 10
    local inset = height < 17 and 3 or 4
    plate.healthPercent:SetFont(STANDARD_TEXT_FONT, healthFont, "OUTLINE")
    plate.healthPercent:ClearAllPoints()
    PixelPoint(plate.healthPercent, "LEFT", plate.health, "LEFT", inset, 0)

    plate.healthValue:SetFont(STANDARD_TEXT_FONT, healthFont, "OUTLINE")
    plate.healthValue:ClearAllPoints()
    PixelPoint(plate.healthValue, "RIGHT", plate.health, "RIGHT", -inset, 0)

    local levelSize = math.max(20, math.min(32,
        tonumber(TinyThreatPlusDB.customLevelBadgeSize) or 24))
    PixelSize(plate.level, levelSize, levelSize)
    plate.level.text:SetFont(
        STANDARD_TEXT_FONT,
        math.max(8, math.min(14,
            tonumber(TinyThreatPlusDB.customLevelFontSize) or 9)),
        ""
    )
    plate.level:ClearAllPoints()
    PixelPoint(plate.level, "CENTER", plate.health, "TOPLEFT", -4, 0)

    plate.threat:ClearAllPoints()
    PixelPoint(plate.threat, "LEFT", plate.health, "RIGHT", BAR_GAP, 0)

    plate.cast:ClearAllPoints()
    PixelPoint(plate.cast, "TOPLEFT", plate.health, "BOTTOMLEFT", 0, -3)
    PixelSize(plate.cast, BASE_WIDTH, CAST_HEIGHT)

    plate.castShell:ClearAllPoints()
    PixelPoint(plate.castShell, "CENTER", plate.cast, "CENTER", 1, -1)
    PixelSize(plate.castShell, BASE_WIDTH + 8, CAST_HEIGHT + 7)

    plate.castName:ClearAllPoints()
    PixelPoint(plate.castName, "LEFT", plate.cast, "LEFT", 3, 0)
    plate.castName:SetWidth(BASE_WIDTH - 6)
end

local function SetNativePresentation(nameplate, visible)
    local unitFrame = nameplate and nameplate.UnitFrame
    if not unitFrame then return end

    if visible then
        if unitFrame.TinyThreatPlusOriginalAlpha ~= nil then
            unitFrame:SetAlpha(unitFrame.TinyThreatPlusOriginalAlpha)
            unitFrame.TinyThreatPlusOriginalAlpha = nil
        else
            unitFrame:SetAlpha(1)
        end
        return
    end

    if unitFrame.TinyThreatPlusOriginalAlpha == nil then
        unitFrame.TinyThreatPlusOriginalAlpha = unitFrame:GetAlpha()
    end
    unitFrame:SetAlpha(0)
end

local function CopyStatus(nativeBar, customBar)
    if not nativeBar or not customBar then return end

    -- Secret numeric values can still be passed directly between StatusBars.
    -- We never compare or perform arithmetic on them.
    local minValue, maxValue = nativeBar:GetMinMaxValues()
    local value = nativeBar:GetValue()
    -- Some Forever builds mark these numbers secret. StatusBar methods may
    -- accept them even though Lua cannot inspect them; pcall keeps presentation
    -- failure isolated if Blizzard tightens that contract.
    pcall(customBar.SetMinMaxValues, customBar, minValue, maxValue)
    pcall(customBar.SetValue, customBar, value)
end

local function CopyNativeHealthText(nativeBar, plate)
    -- Never change Blizzard TextStatusBar display flags here. In Forever combat
    -- the health values become secret; touching showPercentage/showNumeric from
    -- addon execution taints Blizzard's formatter and makes its comparisons
    -- illegal. We only consume whatever strings Blizzard already rendered.
    local left = nativeBar and nativeBar.LeftText
    local right = nativeBar and nativeBar.RightText

    plate.healthPercent:SetText(left and left:GetText() or "")
    plate.healthValue:SetText(right and right:GetText() or "")
end

local function UpdateLevel(plate, unit)
    if not TinyThreatPlusDB.showMobLevel then
        plate.level:Hide()
        return
    end

    local level = UnitLevel(unit)
    if not IsAccessible(level) or type(level) ~= "number" or level == 0 then
        plate.level:Hide()
        return
    end

    plate.level.text:SetText(level < 0 and "??" or tostring(level))
    plate.level:Show()
end

local function UpdateCast(nameplate, plate)
    local nativeCast = GetNativeCastBar(nameplate)
    if not nativeCast or not nativeCast:IsShown() then
        plate.cast:Hide()
        plate.castShell:Hide()
        plate.castName:Hide()
        return
    end

    CopyStatus(nativeCast, plate.cast)

    local r, g, b = nativeCast:GetStatusBarColor()
    if r and g and b then plate.cast:SetStatusBarColor(r, g, b) end

    local text = nativeCast.Text or nativeCast.text or nativeCast.SpellName
    plate.castName:SetText(text and text.GetText and text:GetText() or "")
    plate.cast:Show()
    plate.castShell:Show()
    plate.castName:Show()
end

local function UpdateThreat(plate, unit, data)
    if not TinyThreatPlusDB.showNameplateThreat or not data then
        plate.threat:Hide()
        return
    end

    local height = GetBarHeight()
    local width = math.max(28, math.min(60,
        tonumber(TinyThreatPlusDB.nameplateThreatWidth) or 36))
    local fontSize = math.max(8, math.min(14,
        tonumber(TinyThreatPlusDB.nameplateThreatFontSize) or 9))
    local text = TTP.GetThreatDisplayText(data)
    local r, g, b = TTP.GetThreatColor(unit, data)

    TTP.UpdateThreatBox(
        plate.threat,
        width,
        height,
        fontSize,
        text,
        r, g, b,
        TTP.GetTargetCounter(unit)
    )

    local active = data.hasThreatData
        and ((data.playerThreat or 0) > 0 or (data.highestOtherThreat or 0) > 0)
    plate.threat:SetAlpha((UnitIsUnit(unit, "target") or active) and 1 or 0.58)
end

local function UpdateHealthColor(nativeBar, plate, unit, data)
    local active = data and data.hasThreatData
        and ((data.playerThreat or 0) > 0 or (data.highestOtherThreat or 0) > 0)

    if TinyThreatPlusDB.roleBasedColors and active then
        local r, g, b = TTP.GetThreatColor(unit, data)
        plate.health:SetStatusBarColor(r, g, b)
        return
    end

    local r, g, b = nativeBar:GetStatusBarColor()
    if r and g and b then
        plate.health:SetStatusBarColor(r, g, b)
    else
        plate.health:SetStatusBarColor(1, 0, 0)
    end
end

local function UpdatePriority(plate, unit)
    if not TinyThreatPlusDB.showPriorityMarker
        or not TTP.priorityUnit
        or not UnitIsUnit(unit, TTP.priorityUnit)
    then
        plate.priority:Hide()
        return
    end

    local color = TinyThreatPlusDB.priorityMarkerColor or TTP.defaults.priorityMarkerColor
    local alpha = math.max(0.10, math.min(1.00,
        (tonumber(TinyThreatPlusDB.priorityMarkerOpacity) or 100) / 100))
    plate.priority:SetColorTexture(color[1] or 0, color[2] or 0.06, color[3] or 0.40, alpha)
    plate.priority:Show()
end

local function UpdatePlate(nameplate, plate, unit, nativeHealth)
    LayoutPlate(nameplate, plate)
    SetNativePresentation(nameplate, false)

    CopyStatus(nativeHealth, plate.health)
    CopyNativeHealthText(nativeHealth, plate)

    local name = UnitName(unit)
    plate.name:SetText(IsAccessible(name) and name or "")

    UpdateLevel(plate, unit)
    UpdatePriority(plate, unit)

    local data = TTP.GetThreatData(unit)
    UpdateHealthColor(nativeHealth, plate, unit, data)
    UpdateThreat(plate, unit, data)

    if TinyThreatPlusDB.showTargetHighlight and UnitIsUnit(unit, "target") then
        local color = TinyThreatPlusDB.targetHighlightColor
            or TTP.defaults.targetHighlightColor
            or { 1, 1, 1 }
        plate.targetHighlight:SetVertexColor(
            color[1] or 1,
            color[2] or 1,
            color[3] or 1,
            1
        )
        plate.targetHighlight:Show()
    else
        plate.targetHighlight:Hide()
    end

    UpdateCast(nameplate, plate)
    plate:Show()
end

local function ResetPlate(nameplate)
    if not nameplate then return end
    local plate = nameplate.TinyThreatPlusPlate
    if plate then
        plate:Hide()
        plate.threat:Hide()
        plate.level:Hide()
        plate.targetHighlight:Hide()
        plate.priority:Hide()
        plate.cast:Hide()
        plate.castShell:Hide()
        plate.castName:Hide()
    end
    SetNativePresentation(nameplate, true)
end

function TTP.ClearNameplate(nameplate)
    ResetPlate(nameplate)
end

local function UpdateForeverNameplate(unit, nameplate)
    local nativeHealth = TTP.GetNameplateHealthBar(nameplate)
    if not nativeHealth then
        ResetPlate(nameplate)
        return
    end

    if not TinyThreatPlusDB.enableCustomNameplates or not TTP.IsHostileNPC(unit) then
        ResetPlate(nameplate)
        return
    end

    local plate = CreatePlate(nameplate)
    UpdatePlate(nameplate, plate, unit, nativeHealth)
end

local function UpdateLegacyNameplate(unit, nameplate)
    -- Anniversary/Era retain Blizzard presentation. TinyThreatPlus only adds
    -- the compact threat box, preserving the established legacy behavior.
    local healthBar = TTP.GetNameplateHealthBar(nameplate)
    if not healthBar or not TTP.IsHostileNPC(unit) then
        if nameplate.TinyThreatPlusLegacyThreat then
            nameplate.TinyThreatPlusLegacyThreat:Hide()
        end
        return
    end

    if not TinyThreatPlusDB.showNameplateThreat then
        if nameplate.TinyThreatPlusLegacyThreat then
            nameplate.TinyThreatPlusLegacyThreat:Hide()
        end
        return
    end

    local data = TTP.GetThreatData(unit)
    if not data then return end

    local box = nameplate.TinyThreatPlusLegacyThreat
    if not box then
        box = TTP.CreateThreatBox(nameplate, "TinyThreatPlusLegacyThreat")
    end

    box:ClearAllPoints()
    PixelPoint(box, "LEFT", healthBar, "RIGHT", 2, 0)

    local text = TTP.GetThreatDisplayText(data)
    local r, g, b = TTP.GetThreatColor(unit, data)
    TTP.UpdateThreatBox(box, 42, 18, 10, text, r, g, b, TTP.GetTargetCounter(unit))
end

function TTP.UpdateNameplate(unit)
    if not TTP.Compat.HasNamePlateAPI() then return end

    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate or nameplate:IsForbidden() then return end

    if TTP.Compat.IsForever() then
        UpdateForeverNameplate(unit, nameplate)
    else
        UpdateLegacyNameplate(unit, nameplate)
    end
end
