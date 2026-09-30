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
-- Threat calculation remains in TinyThreatPlus.lua. This file is presentation only.

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

local UpdateCastFrame
local ResetNativeEnhancement

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
    -- The native target-frame cast bar uses a simple gold fill rather than the
    -- CoolDownManager atlas. A flat texture also avoids the atlas' pale edge
    -- treatment that made our copied cast progress appear white.
    plate.cast:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    plate.cast:SetStatusBarColor(1.0, 0.72, 0.08)

    plate.castBackground = plate.cast:CreateTexture(nil, "BACKGROUND")
    plate.castBackground:SetAllPoints()
    plate.castBackground:SetColorTexture(0.08, 0.06, 0.02, 0.90)

    plate.castShell = plate:CreateTexture(nil, "BORDER")
    plate.castShell:SetAtlas("UI-HUD-CoolDownManager-Bar-BG", false)
    plate.castShell:SetIgnoreParentAlpha(true)

    plate.castTextLayer = CreateFrame("Frame", nil, plate)
    plate.castTextLayer:SetFrameLevel(plate.cast:GetFrameLevel() + 4)

    plate.castName = plate.castTextLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    plate.castName:SetJustifyH("LEFT")
    plate.castName:SetTextColor(1, 1, 1)
    plate.castName:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")

    plate.cast:Hide()
    plate.castShell:Hide()
    plate.castName:Hide()

    plate:SetScript("OnUpdate", function(self)
        UpdateCastFrame(self)
    end)

    nameplate.TinyThreatPlusPlate = plate
    return plate
end

local function LayoutPlate(nameplate, plate)
    local unitFrame = nameplate.UnitFrame
    if not unitFrame then return end

    local height = GetBarHeight()
    local scale = GetCustomScale()
    local healthScale = math.max(0.75, math.min(1.50,
        (tonumber(TinyThreatPlusDB.customHealthScale) or 100) / 100))

    -- Layout is static until a presentation setting changes. Re-clearing and
    -- re-anchoring every 80 ms can make thin atlas edges jump between pixel
    -- rounding positions while Blizzard is smoothly moving a distant plate.
    local layoutKey = table.concat({
        tostring(height),
        tostring(scale),
        tostring(healthScale),
        tostring(TinyThreatPlusDB.healthFrameOffsetX),
        tostring(TinyThreatPlusDB.healthFrameOffsetY),
        tostring(TinyThreatPlusDB.customNameFontSize),
        tostring(TinyThreatPlusDB.customLevelBadgeSize),
        tostring(TinyThreatPlusDB.customLevelFontSize),
        tostring(TinyThreatPlusDB.customLevelOffsetX),
        tostring(TinyThreatPlusDB.customLevelOffsetY),
        tostring(TinyThreatPlusDB.nameplateThreatWidth),
        tostring(TinyThreatPlusDB.nameplateThreatHeight),
        tostring(TinyThreatPlusDB.nameplateThreatScale),
    }, ":")
    if plate.TinyThreatPlusLayoutKey == layoutKey then
        return
    end
    plate.TinyThreatPlusLayoutKey = layoutKey

    plate:SetScale(scale)
    plate:ClearAllPoints()
    PixelPoint(plate, "BOTTOM", unitFrame, "BOTTOM", 0, 4)
    local threatWidth = math.max(28, math.min(60,
        tonumber(TinyThreatPlusDB.nameplateThreatWidth) or 36))
    PixelSize(plate, BASE_WIDTH + BAR_GAP + threatWidth, height + 28)

    plate.health:ClearAllPoints()
    PixelPoint(plate.health, "BOTTOMLEFT", plate, "BOTTOMLEFT", 0, 0)
    PixelSize(plate.health, BASE_WIDTH * healthScale, height * healthScale)

    local priorityPadding = 4 + math.max(1, math.min(6,
        tonumber(TinyThreatPlusDB.priorityMarkerSizeRating) or 3))
    plate.priority:ClearAllPoints()
    PixelPoint(plate.priority, "TOPLEFT", plate.health, "TOPLEFT", -priorityPadding, priorityPadding)
    PixelPoint(plate.priority, "BOTTOMRIGHT", plate.health, "BOTTOMRIGHT", priorityPadding, -priorityPadding)

    plate.healthShell:ClearAllPoints()
    local frameX = math.max(-4, math.min(4, tonumber(TinyThreatPlusDB.healthFrameOffsetX) or 2))
    local frameY = math.max(-4, math.min(4, tonumber(TinyThreatPlusDB.healthFrameOffsetY) or -2))
    PixelPoint(plate.healthShell, "CENTER", plate.health, "CENTER", frameX, frameY)
    PixelSize(plate.healthShell, (BASE_WIDTH * healthScale) + 8, (height * healthScale) + 9)

    plate.textLayer:ClearAllPoints()
    plate.textLayer:SetAllPoints(plate.health)

    plate.healthBorder:ClearAllPoints()
    -- This atlas is a dark deselected overlay, not the visible frame chrome.
    -- Keep it centered on the fill; healthShell owns the visible frame.
    PixelPoint(plate.healthBorder, "CENTER", plate.health, "CENTER", 0, 0)
    PixelSize(plate.healthBorder, BASE_WIDTH * healthScale, (height * healthScale) + 2)

    plate.targetHighlight:ClearAllPoints()
    PixelPoint(plate.targetHighlight, "CENTER", plate.health, "CENTER", 0, 0)
    PixelSize(plate.targetHighlight, (BASE_WIDTH * healthScale) + 11, (height * healthScale) + 9)

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
    local levelX = math.max(-20, math.min(20, tonumber(TinyThreatPlusDB.customLevelOffsetX) or -4))
    local levelY = math.max(-20, math.min(20, tonumber(TinyThreatPlusDB.customLevelOffsetY) or 0))
    PixelPoint(plate.level, "CENTER", plate.health, "TOPLEFT", levelX, levelY)

    plate.threat:ClearAllPoints()
    PixelPoint(plate.threat, "LEFT", plate.health, "RIGHT", BAR_GAP, 0)
    plate.threat:SetScale(math.max(0.50, math.min(1.50,
        (tonumber(TinyThreatPlusDB.nameplateThreatScale) or 100) / 100)))

    plate.cast:ClearAllPoints()
    PixelPoint(plate.cast, "TOPLEFT", plate.health, "BOTTOMLEFT", 0, -3)
    PixelSize(plate.cast, BASE_WIDTH, CAST_HEIGHT)

    plate.castShell:ClearAllPoints()
    PixelPoint(plate.castShell, "CENTER", plate.cast, "CENTER", 1, -1)
    PixelSize(plate.castShell, BASE_WIDTH + 8, CAST_HEIGHT + 7)

    plate.castTextLayer:ClearAllPoints()
    plate.castTextLayer:SetAllPoints(plate.cast)

    plate.castName:ClearAllPoints()
    PixelPoint(plate.castName, "CENTER", plate.castTextLayer, "CENTER", 0, 0)
    plate.castName:SetWidth(BASE_WIDTH - 8)
    plate.castName:SetJustifyH("CENTER")
end

local function SetNativePresentation(nameplate, visible)
    local unitFrame = nameplate and nameplate.UnitFrame
    if not unitFrame then return end

    if visible then
        unitFrame.TinyThreatPlusSuppressNative = false
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

    -- Blizzard can refresh/recycle UnitFrame presentation independently of our
    -- 80 ms state pass. Keep its visual layer suppressed while our custom plate
    -- owns presentation, preventing one-frame native flashes.
    if not unitFrame.TinyThreatPlusAlphaHooked and hooksecurefunc then
        unitFrame.TinyThreatPlusAlphaHooked = true
        hooksecurefunc(unitFrame, "SetAlpha", function(self, alpha)
            if self.TinyThreatPlusSuppressNative and alpha ~= 0 then
                self:SetAlpha(0)
            end
        end)
    end
    unitFrame.TinyThreatPlusSuppressNative = true
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

    local level = UnitEffectiveLevel and UnitEffectiveLevel(unit) or UnitLevel(unit)
    if not IsAccessible(level) or type(level) ~= "number" or level == 0 then
        plate.level:Hide()
        return
    end

    plate.level.text:SetText(level < 0 and "??" or tostring(level))

    -- Forever's target frame is authoritative for creature difficulty. Use
    -- the same dynamic Classic XP thresholds previously validated in MobXP;
    -- the grey cutoff changes as the player levels.
    local playerLevel = UnitEffectiveLevel and UnitEffectiveLevel("player") or UnitLevel("player")
    if level < 0 then
        plate.level.text:SetTextColor(1, 0.1, 0.1)
    elseif IsAccessible(playerLevel) and type(playerLevel) == "number" then
        local difference = level - playerLevel

        -- Classic/Turtle MobXP grey cutoff is dynamic with player level.
        -- Calculate the actual lowest XP-bearing mob level, rather than using
        -- a fixed level difference.
        local greyLevel
        if playerLevel <= 5 then
            greyLevel = playerLevel - 5
        elseif playerLevel <= 49 then
            greyLevel = playerLevel - math.floor(playerLevel / 10) - 5
        elseif playerLevel == 50 then
            greyLevel = playerLevel - 10
        elseif playerLevel <= 59 then
            greyLevel = playerLevel - math.floor(playerLevel / 5) - 1
        else
            greyLevel = playerLevel - 9
        end

        if level <= greyLevel then
            plate.level.text:SetTextColor(0.5, 0.5, 0.5)
        elseif difference >= 5 then
            plate.level.text:SetTextColor(1, 0.1, 0.1)
        elseif difference >= 3 then
            plate.level.text:SetTextColor(1, 0.5, 0)
        elseif difference >= -2 then
            plate.level.text:SetTextColor(1, 1, 0)
        else
            plate.level.text:SetTextColor(0.25, 0.75, 0.25)
        end
    else
        plate.level.text:SetTextColor(1, 1, 1)
    end

    plate.level:Show()
end

local function UpdateCast(nameplate, plate)
    local nativeCast = GetNativeCastBar(nameplate)
    plate.TinyThreatPlusNativeCast = nativeCast
    if not nativeCast or not nativeCast:IsShown() then
        plate.cast:Hide()
        plate.castShell:Hide()
        plate.castName:Hide()
        return
    end

    CopyStatus(nativeCast, plate.cast)

    -- Match Blizzard's target-frame cast presentation rather than inheriting
    -- the nameplate cast bar's pale/white status color.
    plate.cast:SetStatusBarColor(1.0, 0.72, 0.08)

    local text = nativeCast.Text or nativeCast.text or nativeCast.SpellName
    plate.castName:SetText(text and text.GetText and text:GetText() or "")
    plate.cast:Show()
    plate.castShell:Show()
    plate.castName:Show()
end

UpdateCastFrame = function(plate)
    if not plate or not plate:IsShown() then return end
    local nativeCast = plate.TinyThreatPlusNativeCast
    if not nativeCast or not nativeCast:IsShown() then return end

    -- Cast progress is animation, not game-state polling. Mirror Blizzard's
    -- StatusBar every rendered frame so our bar moves as smoothly as theirs.
    -- Secret values are passed directly StatusBar-to-StatusBar; Lua never
    -- compares or performs arithmetic on them.
    CopyStatus(nativeCast, plate.cast)
end

local function UpdateThreat(plate, unit, data)
    if not TinyThreatPlusDB.showNameplateThreat or not data then
        plate.threat:Hide()
        return
    end

    local height = GetBarHeight()
    local boxScale = math.max(0.50, math.min(1.50,
        (tonumber(TinyThreatPlusDB.nameplateThreatScale) or 100) / 100))
    local width = math.max(28, math.min(60,
        tonumber(TinyThreatPlusDB.nameplateThreatWidth) or 36))
    local boxHeight = math.max(12, math.min(32,
        tonumber(TinyThreatPlusDB.nameplateThreatHeight) or 20))
    local fontSize = math.max(8, math.min(14,
        tonumber(TinyThreatPlusDB.nameplateThreatFontSize) or 9))
    local text = TTP.GetThreatDisplayText(data)
    local r, g, b = TTP.GetThreatColor(unit, data)

    TTP.UpdateThreatBox(
        plate.threat,
        width,
        boxHeight,
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
            math.max(0.10, math.min(1.00,
                (tonumber(TinyThreatPlusDB.targetHighlightOpacity) or 70) / 100))
        )
        plate.targetHighlight:Show()
    else
        plate.targetHighlight:Hide()
    end
    UpdateCast(nameplate, plate)

    local targeted = UnitIsUnit(unit, "target")
    local active = data and data.hasThreatData
        and ((data.playerThreat or 0) > 0 or (data.highestOtherThreat or 0) > 0)
    -- Lua's and/or expression would return the boolean true when targeted.
    -- Resolve the state explicitly so SetAlpha always receives a number.
    local opacity
    if targeted or active then
        opacity = 1
    else
        opacity = math.max(0.20, math.min(1.00,
            (tonumber(TinyThreatPlusDB.customNameplateInactiveOpacity) or 70) / 100))
    end
    if plate.TinyThreatPlusAlpha ~= opacity then
        plate.TinyThreatPlusAlpha = opacity
        plate:SetAlpha(opacity)
    end
    plate:Show()
end

local function ResetPlate(nameplate)
    if not nameplate then return end
    local plate = nameplate.TinyThreatPlusPlate
    if plate then
        plate.TinyThreatPlusLayoutKey = nil
        plate.TinyThreatPlusAlpha = nil
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
    ResetNativeEnhancement(nameplate)
end

local function CreateNativeEnhancement(nameplate)
    if nameplate.TinyThreatPlusNativeEnhancement then
        return nameplate.TinyThreatPlusNativeEnhancement
    end

    local unitFrame = nameplate.UnitFrame
    local overlay = CreateFrame("Frame", nil, nameplate)
    overlay:SetFrameStrata(nameplate:GetFrameStrata())
    overlay:SetFrameLevel((unitFrame and unitFrame:GetFrameLevel() or 1) + 20)

    -- Native mode keeps Blizzard's health/name presentation, replaces its
    -- redundant level readout with our HD level badge on the left, and turns
    -- the native right-side level box into the TinyThreatPlus threat box.
    overlay.level = CreateLevelBadge(overlay)

    -- Addon-owned target highlight lets Native mode retain Blizzard's plate
    -- while giving TinyThreatPlus deterministic tint/opacity control.
    overlay.targetHighlight = overlay:CreateTexture(nil, "OVERLAY")
    overlay.targetHighlight:SetAtlas("UI-HUD-Nameplates-TargetedByEnemy", false)
    overlay.targetHighlight:Hide()

    overlay.threatBadge = CreateFrame("Frame", nil, overlay)
    overlay.threatBadge:SetFrameLevel(overlay:GetFrameLevel() + 5)
    overlay.threatBadge.art = overlay.threatBadge:CreateTexture(nil, "ARTWORK")
    overlay.threatBadge.art:SetAllPoints()
    overlay.threatBadge.art:SetAtlas("UI-HUD-Nameplates-LevelIndicator", false)
    overlay.threatBadge.art:SetIgnoreParentAlpha(true)

    overlay.threat = overlay.threatBadge:CreateFontString(nil, "OVERLAY", "GameNormalNumberFont")
    overlay.threat:SetJustifyH("CENTER")
    overlay.threat:SetJustifyV("MIDDLE")
    overlay.threat:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")

    overlay.counterRing = overlay:CreateTexture(nil, "OVERLAY")
    overlay.counterRing:SetSize(18, 18)
    overlay.counterRing:SetAtlas("PetJournal-LevelBubble")
    overlay.counterRing:Hide()
    overlay.counterText = overlay:CreateFontString(nil, "OVERLAY", "GameNormalNumberFont")
    overlay.counterText:SetSize(18, 18)
    overlay.counterText:SetJustifyH("CENTER")
    overlay.counterText:SetJustifyV("MIDDLE")
    overlay.counterText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    overlay.counterText:SetTextColor(1, 1, 1)
    overlay.counterText:Hide()
    overlay:Hide()

    nameplate.TinyThreatPlusNativeEnhancement = overlay
    return overlay
end

ResetNativeEnhancement = function(nameplate)
    local overlay = nameplate and nameplate.TinyThreatPlusNativeEnhancement
    if not overlay then return end
    local unitFrame = nameplate.UnitFrame
    local healthBar = unitFrame and unitFrame.healthBar
    if unitFrame and unitFrame.selectionHighlight then
        unitFrame.selectionHighlight:SetAlpha(1)
    end
    if healthBar and healthBar.selectedBorder then
        healthBar.selectedBorder:SetAlpha(1)
    end
    overlay:Hide()
    overlay.level:Hide()
    overlay.targetHighlight:Hide()
    overlay.threatBadge:Hide()
    overlay.threat:SetText("")
    overlay.counterRing:Hide()
    overlay.counterText:Hide()
    if overlay.TinyThreatPlusHiddenNativeLevel
        and overlay.TinyThreatPlusHiddenNativeLevel.Show
    then
        overlay.TinyThreatPlusHiddenNativeLevel:Show()
        overlay.TinyThreatPlusHiddenNativeLevel = nil
    end
end

local NATIVE_FONTS = {
    FRIZQT = "Fonts\\FRIZQT__.TTF",
    ARIALN = "Fonts\\ARIALN.TTF",
}

local function GetNativeFont(key)
    return NATIVE_FONTS[key] or STANDARD_TEXT_FONT
end

local function ApplyNativeTextTreatment(fontString, fontPath, size, treatment, color)
    if not fontString then return end
    local flag = ""
    if treatment == "OUTLINE" then
        flag = "OUTLINE"
    elseif treatment == "THICKOUTLINE" then
        flag = "THICKOUTLINE"
    end
    fontString:SetFont(fontPath or STANDARD_TEXT_FONT, size, flag)

    local c = color or { 0, 0, 0 }
    if treatment == "SHADOW" then
        fontString:SetShadowColor(c[1] or 0, c[2] or 0, c[3] or 0, 1)
        fontString:SetShadowOffset(1, -1)
    else
        -- WoW's native OUTLINE flags have a fixed outline color. Clear our
        -- custom shadow so the selected treatment is visually unambiguous.
        fontString:SetShadowColor(0, 0, 0, 0)
        fontString:SetShadowOffset(0, 0)
    end
end

local function LayoutNativeText(healthBar)
    if not healthBar then return end

    local nameSize = math.max(8, math.min(16,
        tonumber(TinyThreatPlusDB.nativeNameFontSize) or 10))
    local nameTreatment = TinyThreatPlusDB.nativeNameOutline or "SHADOW"
    local nameFont = GetNativeFont(TinyThreatPlusDB.nativeNameFont)
    local nameColor = TinyThreatPlusDB.nativeNameOutlineColor or { 0, 0, 0 }

    local name = healthBar.unitNameFontString
    if name then
        name:ClearAllPoints()
        PixelPoint(name, "BOTTOMLEFT", healthBar, "TOPLEFT", 0, 2)
        PixelPoint(name, "BOTTOMRIGHT", healthBar, "TOPRIGHT", 0, 2)
        name:SetJustifyH("LEFT")
        name:SetJustifyV("BOTTOM")
        ApplyNativeTextTreatment(name, nameFont, nameSize, nameTreatment, nameColor)
    end

    local healthFontSize = math.max(8, math.min(14,
        tonumber(TinyThreatPlusDB.nativeHealthFontSize) or 9))
    local healthTreatment = TinyThreatPlusDB.nativeHealthOutline or "SHADOW"
    local healthFont = GetNativeFont(TinyThreatPlusDB.nativeHealthFont)
    local healthColor = TinyThreatPlusDB.nativeHealthOutlineColor or { 0, 0, 0 }

    if healthBar.LeftText then
        healthBar.LeftText:ClearAllPoints()
        PixelPoint(healthBar.LeftText, "LEFT", healthBar, "LEFT", 4, 0)
        healthBar.LeftText:SetJustifyH("LEFT")
        ApplyNativeTextTreatment(healthBar.LeftText, healthFont, healthFontSize, healthTreatment, healthColor)
        healthBar.LeftText:Show()
    end

    if healthBar.RightText then
        healthBar.RightText:ClearAllPoints()
        PixelPoint(healthBar.RightText, "RIGHT", healthBar, "RIGHT", -4, 0)
        healthBar.RightText:SetJustifyH("RIGHT")
        ApplyNativeTextTreatment(healthBar.RightText, healthFont, healthFontSize, healthTreatment, healthColor)
        healthBar.RightText:Show()
    end

    if healthBar.TextString then
        healthBar.TextString:Hide()
    end
end

local function UpdateNativeEnhancement(unit, nameplate)
    if not TTP.IsHostileNPC(unit) then
        ResetNativeEnhancement(nameplate)
        return
    end

    -- Native mode is additive: Blizzard owns all of its original presentation.
    SetNativePresentation(nameplate, true)
    local custom = nameplate.TinyThreatPlusPlate
    if custom then custom:Hide() end

    local healthBar = TTP.GetNameplateHealthBar(nameplate)
    local unitFrame = nameplate.UnitFrame
    if not healthBar or not unitFrame then
        ResetNativeEnhancement(nameplate)
        return
    end

    LayoutNativeText(healthBar)

    -- Native + TTP owns selected-target treatment so its color/opacity controls
    -- are deterministic instead of stacking over Blizzard's yellow treatment.
    if unitFrame.selectionHighlight then
        unitFrame.selectionHighlight:SetAlpha(0)
    end
    if healthBar.selectedBorder then
        healthBar.selectedBorder:SetAlpha(0)
    end

    local overlay = CreateNativeEnhancement(nameplate)
    overlay.targetHighlight:ClearAllPoints()
    -- Anchor the artwork around Blizzard's bar instead of reading its width
    -- or height. Forever can make native geometry secret in combat.
    PixelPoint(overlay.targetHighlight, "TOPLEFT", healthBar, "TOPLEFT", -5, 4)
    PixelPoint(overlay.targetHighlight, "BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 5, -4)
    if TinyThreatPlusDB.showTargetHighlight and UnitIsUnit(unit, "target") then
        local color = TinyThreatPlusDB.targetHighlightColor or TTP.defaults.targetHighlightColor or { 1, 1, 1 }
        overlay.targetHighlight:SetVertexColor(
            color[1] or 1, color[2] or 1, color[3] or 1,
            math.max(0.10, math.min(1.00,
                (tonumber(TinyThreatPlusDB.targetHighlightOpacity) or 70) / 100))
        )
        overlay.targetHighlight:Show()
    else
        overlay.targetHighlight:Hide()
    end

    -- Forever exposes its right-side level presentation as a stable frame.
    -- Hide the frame itself rather than inspecting its potentially-secret text.
    -- Our HD badge on the left is the authoritative level presentation.
    local nativeLevelFrame = unitFrame.PlayerLevelDiffFrame
    if nativeLevelFrame and nativeLevelFrame.Hide then
        nativeLevelFrame:Hide()
    end

    overlay:ClearAllPoints()
    PixelPoint(overlay, "BOTTOM", unitFrame, "BOTTOM", 0, 4)
    PixelSize(overlay, 40, 40)

    local levelSize = math.max(24, math.min(48,
        tonumber(TinyThreatPlusDB.nativeLevelBadgeSize) or 34))
    PixelSize(overlay.level, levelSize, levelSize)
    overlay.level:ClearAllPoints()
    local levelX = math.max(-30, math.min(10, tonumber(TinyThreatPlusDB.nativeLevelOffsetX) or -6))
    local levelY = math.max(-20, math.min(20, tonumber(TinyThreatPlusDB.nativeLevelOffsetY) or 0))
    PixelPoint(overlay.level, "CENTER", healthBar, "LEFT", levelX, levelY)
    overlay.level.text:SetFont(
        STANDARD_TEXT_FONT,
        math.max(8, math.min(16, tonumber(TinyThreatPlusDB.nativeLevelFontSize) or 10)),
        ""
    )

    -- Reuse the exact custom difficulty calculation and HD badge.
    UpdateLevel(overlay, unit)

    -- Never inspect Blizzard-rendered FontString text on Forever. Instance
    -- nameplates can mark those strings secret even out of combat. The native
    -- level is suppressed through PlayerLevelDiffFrame above; our readout
    -- remains additive and never reads Blizzard's protected text.

    local threatBadgeWidth = math.max(20, math.min(60,
        tonumber(TinyThreatPlusDB.nativeThreatWidth) or 34))
    local threatBadgeHeight = math.max(14, math.min(40,
        tonumber(TinyThreatPlusDB.nativeThreatHeight) or 24))
    PixelSize(overlay.threatBadge, threatBadgeWidth, threatBadgeHeight)
    overlay.threatBadge:ClearAllPoints()
    local threatX = math.max(-10, math.min(40, tonumber(TinyThreatPlusDB.nativeThreatOffsetX) or 22))
    local threatY = math.max(-20, math.min(20, tonumber(TinyThreatPlusDB.nativeThreatOffsetY) or 0))
    PixelPoint(overlay.threatBadge, "LEFT", healthBar, "RIGHT", threatX, threatY)
    overlay.threat:ClearAllPoints()
    overlay.threat:SetAllPoints(overlay.threatBadge)
    overlay.threat:SetFont(
        STANDARD_TEXT_FONT,
        math.max(8, math.min(16, tonumber(TinyThreatPlusDB.nativeThreatFontSize) or 12)),
        "OUTLINE"
    )

    local data = TTP.GetThreatData(unit)
    if TinyThreatPlusDB.showNameplateThreat and data then
        local text = TTP.GetThreatDisplayText(data)
        local r, g, b = TTP.GetThreatColor(unit, data)
        overlay.threat:SetText(text)
        overlay.threat:SetTextColor(r, g, b)
        overlay.threatBadge:Show()
        overlay.threat:Show()

        local count = TTP.GetTargetCounter(unit)
        if count then
            overlay.counterRing:ClearAllPoints()
            PixelPoint(overlay.counterRing, "CENTER", overlay.threatBadge, "RIGHT", 5, 0)
            overlay.counterText:ClearAllPoints()
            local counterX = count < 10 and -0.5 or 0
            PixelPoint(overlay.counterText, "CENTER", overlay.counterRing, "CENTER", counterX, 0)
            overlay.counterText:SetFont(STANDARD_TEXT_FONT, count < 10 and 10 or 9, "OUTLINE")
            overlay.counterText:SetText(count)
            overlay.counterRing:Show()
            overlay.counterText:Show()
        else
            overlay.counterRing:Hide()
            overlay.counterText:Hide()
        end
    else
        overlay.threat:SetText("")
        overlay.threat:Hide()
        overlay.threatBadge:Hide()
        overlay.counterRing:Hide()
        overlay.counterText:Hide()
    end

    overlay:Show()
end

local function UpdateForeverNameplate(unit, nameplate)
    local nativeHealth = TTP.GetNameplateHealthBar(nameplate)
    if not nativeHealth then
        ResetPlate(nameplate)
        return
    end

    if TinyThreatPlusDB.nameplateMode == "NATIVE" then
        ResetPlate(nameplate)
        UpdateNativeEnhancement(unit, nameplate)
        return
    end

    ResetNativeEnhancement(nameplate)
    if not TTP.IsHostileNPC(unit) then
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
