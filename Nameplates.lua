local TTP = _G.TinyThreatPlus or select(2, ...)
if not TTP then return end

-- TinyThreatPlus nameplate presentation
--
-- Forever keeps Blizzard's native plate geometry and visibility. TinyThreatPlus
-- only normalizes native text and adds threat, level, target-counter, target
-- highlight, priority, and group-threat information. Legacy clients retain the
-- established compact threat-box augmentation.
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

    -- Group threat leader belongs with the mob it describes, not the target
    -- frame. Keep this deliberately compact beneath the native health bar.
    overlay.leader = CreateFrame("Frame", nil, overlay)
    overlay.leader:SetSize(150, 16)
    overlay.leader.icon = overlay.leader:CreateTexture(nil, "ARTWORK")
    overlay.leader.icon:SetSize(14, 14)
    overlay.leader.icon:SetPoint("LEFT", overlay.leader, "LEFT", 0, 0)
    overlay.leader.roleIcon = overlay.leader:CreateTexture(nil, "ARTWORK")
    overlay.leader.roleIcon:SetSize(14, 14)
    overlay.leader.name = overlay.leader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    overlay.leader.name:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    overlay.leader.name:SetJustifyH("LEFT")
    overlay.leader:Hide()
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
        unitFrame.selectionHighlight:SetDesaturated(false)
        unitFrame.selectionHighlight:SetVertexColor(1, 1, 1, 1)
        unitFrame.selectionHighlight:SetAlpha(1)
    end
    if healthBar and healthBar.selectedBorder then
        healthBar.selectedBorder:SetDesaturated(false)
        healthBar.selectedBorder:SetVertexColor(1, 1, 1, 1)
        healthBar.selectedBorder:SetAlpha(1)
    end
    overlay:Hide()
    overlay.level:Hide()
    overlay.threatBadge:Hide()
    overlay.threat:SetText("")
    overlay.counterRing:Hide()
    overlay.counterText:Hide()
    overlay.stableThreatState = nil
    local resetHealth = TTP.GetNameplateHealthBar(nameplate)
    if resetHealth then resetHealth.TinyThreatPlusUnit = nil end
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

local function GetNativeThreatBarColor(healthBar, state)
    -- Tint Blizzard's existing status-bar texture rather than replacing or
    -- layering artwork. Use the native hostile red as the saturation/value
    -- reference, then rotate only its hue for warning/safe states.
    if not healthBar.TinyThreatPlusNativeColor then
        local r, g, b = healthBar:GetStatusBarColor()
        if IsAccessible(r) and IsAccessible(g) and IsAccessible(b) then
            healthBar.TinyThreatPlusNativeColor = { r, g, b }
        else
            healthBar.TinyThreatPlusNativeColor = { 0.72, 0.10, 0.10 }
        end
    end
    local n = healthBar.TinyThreatPlusNativeColor
    local hi = math.max(n[1], n[2], n[3])
    local lo = math.min(n[1], n[2], n[3])
    if state == "good" then return lo, hi, lo end
    if state == "warn" then return hi, hi * 0.78, lo end
    return n[1], n[2], n[3]
end

local function GetStableThreatState(unit, data)
    local r, g, b = TTP.GetThreatColor(unit, data)
    if g > r and g > b then return "good" end
    if r > 0.7 and g > 0.45 then return "warn" end
    return "bad"
end

local function ApplyForeverProtectedThreatText(fontString, unit)
    -- Forever can protect nameplate threat percentages while still allowing
    -- them to flow directly into a FontString. Do not inspect, compare,
    -- round, or stringify the protected value in Lua; SetFormattedText is the
    -- presentation sink. This mirrors the proven Forever threat-meter pattern.
    if not TTP.Compat.IsForever() or not fontString or not fontString.SetFormattedText then
        return false
    end

    local _, _, scaledPercent = UnitDetailedThreatSituation("player", unit)
    if not TTP.Compat.IsSecretValue(scaledPercent) then
        return false
    end

    fontString:SetFormattedText("%.0f%%", scaledPercent)
    return true
end

local function ApplyForeverProtectedThreatColor(healthBar, unit)
    -- Modern Blizzard clients may protect UnitThreatSituation for off-target
    -- nameplates. Do not discard that state: the protected comparison/color
    -- pipeline can consume it without exposing the result to Lua.
    if not TTP.Compat.IsForever()
        or not C_Secrets or not C_Secrets.IsEqual
        or not C_CurveUtil or not C_CurveUtil.EvaluateColorValueFromBoolean
    then return false end

    local status = UnitThreatSituation("player", unit)
    if status == nil or not TTP.Compat.IsSecretValue(status) then return false end

    local native = healthBar.TinyThreatPlusNativeColor
    if not native then
        local nr, ng, nb = healthBar:GetStatusBarColor()
        if not IsAccessible(nr) or not IsAccessible(ng) or not IsAccessible(nb) then return false end
        native = { nr, ng, nb }
        healthBar.TinyThreatPlusNativeColor = native
    end

    local hi = math.max(native[1], native[2], native[3])
    local lo = math.min(native[1], native[2], native[3])
    local goodR, goodG, goodB = lo, hi, lo
    local warnR, warnG, warnB = hi, hi * 0.78, lo
    local badR, badG, badB = native[1], native[2], native[3]

    local isThree = C_Secrets.IsEqual(status, 3)
    local isOne = C_Secrets.IsEqual(status, 1)
    local isTwo = C_Secrets.IsEqual(status, 2)
    local isWarn = C_Secrets.Select and C_Secrets.Select(isOne, true, isTwo) or nil
    if isWarn == nil then return false end

    local tank = TTP.PlayerIsTank()
    local terminalR = C_CurveUtil.EvaluateColorValueFromBoolean(isThree,
        tank and goodR or badR, tank and badR or goodR)
    local terminalG = C_CurveUtil.EvaluateColorValueFromBoolean(isThree,
        tank and goodG or badG, tank and badG or goodG)
    local terminalB = C_CurveUtil.EvaluateColorValueFromBoolean(isThree,
        tank and goodB or badB, tank and badB or goodB)
    local r = C_CurveUtil.EvaluateColorValueFromBoolean(isWarn, warnR, terminalR)
    local g = C_CurveUtil.EvaluateColorValueFromBoolean(isWarn, warnG, terminalG)
    local b = C_CurveUtil.EvaluateColorValueFromBoolean(isWarn, warnB, terminalB)

    TTP.applyingHealthColor = true
    healthBar:SetStatusBarColor(r, g, b)
    TTP.applyingHealthColor = false
    return true
end

local function ApplyForeverThreatColor(healthBar, unit, data)
    if not healthBar or not healthBar.SetStatusBarColor then return end
    if not TinyThreatPlusDB.roleBasedColors or not data or not data.hasThreatData then return end

    local state = GetStableThreatState(unit, data)
    local r, g, b = GetNativeThreatBarColor(healthBar, state)
    TTP.applyingHealthColor = true
    healthBar:SetStatusBarColor(r, g, b)
    TTP.applyingHealthColor = false
end

local function HookForeverHealthBarColor(healthBar)
    if not healthBar or healthBar.TinyThreatPlusForeverColorHooked then return end
    healthBar.TinyThreatPlusForeverColorHooked = true

    -- Mirror the mature Anniversary implementation: whenever Blizzard
    -- restores/recolors its native bar, immediately reapply the current threat
    -- state instead of racing it from our update loop.
    hooksecurefunc(healthBar, "SetStatusBarColor", function(bar)
        if TTP.applyingHealthColor or not TinyThreatPlusDB.roleBasedColors then return end
        local unit = bar.TinyThreatPlusUnit
        if not unit or not UnitExists(unit) then return end
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if not plate or TTP.GetNameplateHealthBar(plate) ~= bar then
            bar.TinyThreatPlusUnit = nil
            return
        end
        local data = TTP.GetThreatData(unit)
        if ApplyForeverProtectedThreatColor(bar, unit) then return end
        if data and data.hasThreatData then ApplyForeverThreatColor(bar, unit, data) end
    end)
end

local function UpdateNativeEnhancement(unit, nameplate)
    if not TTP.IsHostileNPC(unit) then
        ResetNativeEnhancement(nameplate)
        return
    end

    -- Native presentation is additive: Blizzard owns the base plate.

    local healthBar = TTP.GetNameplateHealthBar(nameplate)
    local unitFrame = nameplate.UnitFrame
    if not healthBar or not unitFrame then
        ResetNativeEnhancement(nameplate)
        return
    end

    LayoutNativeText(healthBar)

    -- Blizzard owns the registered border geometry for every Forever plate
    -- style. TinyThreatPlus only desaturates/tints those native textures.
    -- Priority uses the same geometry, deliberately stronger and navy by
    -- default, rather than introducing another independently scaled atlas.
    local isCurrentTarget = UnitIsUnit(unit, "target")
    local isPriority = TinyThreatPlusDB.showPriorityMarker
        and TTP.priorityUnit
        and UnitIsUnit(unit, TTP.priorityUnit)

    local highlightColor = TinyThreatPlusDB.targetHighlightColor
        or TTP.defaults.targetHighlightColor
        or { 1, 1, 1 }
    local highlightAlpha = math.max(0.10, math.min(1.00,
        (tonumber(TinyThreatPlusDB.targetHighlightOpacity) or 100) / 100))
    local priorityColor = TinyThreatPlusDB.priorityMarkerColor
        or TTP.defaults.priorityMarkerColor
        or { 0, 0.0627451, 0.3960784 }
    local priorityAlpha = math.max(0.10, math.min(1.00,
        (tonumber(TinyThreatPlusDB.priorityMarkerOpacity) or 100) / 100))

    local borderR, borderG, borderB, borderA = 1, 1, 1, 0
    if isPriority then
        borderR, borderG, borderB, borderA =
            priorityColor[1] or 0,
            priorityColor[2] or 0.0627451,
            priorityColor[3] or 0.3960784,
            priorityAlpha
    elseif isCurrentTarget and TinyThreatPlusDB.showTargetHighlight then
        borderR, borderG, borderB, borderA =
            highlightColor[1] or 1,
            highlightColor[2] or 1,
            highlightColor[3] or 1,
            highlightAlpha
    end

    -- The normal target uses Blizzard's tight selectedBorder. Priority also
    -- enables Blizzard's broader selectionHighlight layer, giving it a more
    -- exaggerated silhouette without any addon-owned geometry or scaling.
    if unitFrame.selectionHighlight then
        unitFrame.selectionHighlight:SetDesaturated(true)
        unitFrame.selectionHighlight:SetVertexColor(borderR, borderG, borderB, 1)
        unitFrame.selectionHighlight:SetAlpha(isPriority and borderA or 0)
        if isPriority then
            unitFrame.selectionHighlight:Show()
        end
    end
    if healthBar.selectedBorder then
        healthBar.selectedBorder:SetDesaturated(true)
        healthBar.selectedBorder:SetVertexColor(borderR, borderG, borderB, 1)
        healthBar.selectedBorder:SetAlpha(borderA)
        if isPriority then
            healthBar.selectedBorder:Show()
        end
    end

    -- Retired replacement texture remains hidden for compatibility while the
    -- prototype is cleaned up; it can be removed entirely before release.
    local overlay = CreateNativeEnhancement(nameplate)

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

    -- Forever places important debuffs immediately to the right of the native
    -- health bar. Our threat badge occupies that same lane, so move Blizzard's
    -- aura container just beyond the complete TinyThreatPlus right-side stack.
    -- Keep Blizzard as the owner of the aura buttons and their filtering.
    local auraFrame = unitFrame.AurasFrame
        or unitFrame.aurasFrame
        or unitFrame.DebuffFrame
        or unitFrame.debuffFrame
        or unitFrame.BuffFrame
        or unitFrame.buffFrame
    if auraFrame and auraFrame.ClearAllPoints and auraFrame.SetPoint then
        -- AurasFrame is a restricted Blizzard region in Forever. Reading its
        -- geometry (GetPoint/GetNumPoints/GetSize/etc.) taints immediately.
        -- Treat it as write-only presentation: Blizzard owns its contents and
        -- lifecycle; TinyThreatPlus only supplies a safe anchor.
        auraFrame:ClearAllPoints()
        local auraGap = TinyThreatPlusDB.showTargetCounter and 16 or 4
        PixelPoint(auraFrame, "LEFT", overlay.threatBadge, "RIGHT", auraGap, 0)
    end

    -- Role-based threat state colors the native Blizzard health bar. The
    -- threshold uses the existing threat-safety slider: tanks are green while
    -- securely ahead, yellow inside the caution band, red after losing aggro;
    -- DPS/healers use the inverse semantics.
    -- Match Anniversary's ownership model. Blizzard still owns the native
    -- bar/texture; TinyThreatPlus only overrides its color while this visible
    -- enemy has meaningful threat data. The secure post-hook above prevents
    -- Blizzard health updates from flashing the bar back to its base color.
    healthBar.TinyThreatPlusUnit = unit
    HookForeverHealthBarColor(healthBar)
    if TinyThreatPlusDB.roleBasedColors and ApplyForeverProtectedThreatColor(healthBar, unit) then
        -- Protected off-target threat was applied without inspecting it in Lua.
    elseif TinyThreatPlusDB.roleBasedColors and data and data.hasThreatData then
        ApplyForeverThreatColor(healthBar, unit, data)
    elseif healthBar.TinyThreatPlusNativeColor then
        -- Leaving the threat table returns the exact Blizzard color captured
        -- for this bar rather than leaving the last combat state behind.
        local n = healthBar.TinyThreatPlusNativeColor
        TTP.applyingHealthColor = true
        healthBar:SetStatusBarColor(n[1], n[2], n[3])
        TTP.applyingHealthColor = false
    end

    local leader = overlay.leader
    if leader then
        leader:Hide()
        if TinyThreatPlusDB.showThreatLeader and data and data.leaderName then
            local leaderUnit = data.leaderUnit
            local _, class = leaderUnit and UnitExists(leaderUnit) and UnitClass(leaderUnit) or nil, nil
            if leaderUnit and UnitExists(leaderUnit) then
                _, class = UnitClass(leaderUnit)
            end
            local classAtlases = {
                WARRIOR="groupfinder-icon-class-warrior", MAGE="groupfinder-icon-class-mage",
                ROGUE="groupfinder-icon-class-rogue", DRUID="groupfinder-icon-class-druid",
                HUNTER="groupfinder-icon-class-hunter", SHAMAN="groupfinder-icon-class-shaman",
                PRIEST="groupfinder-icon-class-priest", WARLOCK="groupfinder-icon-class-warlock",
                PALADIN="groupfinder-icon-class-paladin", DEATHKNIGHT="groupfinder-icon-class-deathknight",
            }
            leader.icon:Hide()
            leader.roleIcon:Hide()
            if TinyThreatPlusDB.showThreatLeaderClassIcon and class and classAtlases[class] then
                leader.icon:SetAtlas(classAtlases[class])
                leader.icon:Show()
            elseif TinyThreatPlusDB.showThreatLeaderClassIcon and leaderUnit
                and (leaderUnit == "pet" or string.match(leaderUnit, "^partypet%d+$") or string.match(leaderUnit, "^raidpet%d+$")) then
                SetPortraitTexture(leader.icon, leaderUnit)
                leader.icon:Show()
            end
            local role = leaderUnit and UnitExists(leaderUnit) and TTP.GetUnitRole(leaderUnit) or nil
            local roleAtlas = role == "TANK" and "roleicon-tiny-tank"
                or role == "HEALER" and "roleicon-tiny-healer"
                or role == "DAMAGER" and "roleicon-tiny-dps" or nil
            if TinyThreatPlusDB.showThreatLeaderRole and roleAtlas then
                leader.roleIcon:SetAtlas(roleAtlas)
                leader.roleIcon:Show()
            end
            leader.icon:ClearAllPoints()
            leader.roleIcon:ClearAllPoints()
            leader.name:ClearAllPoints()
            leader.icon:SetPoint("LEFT", leader, "LEFT", 0, 0)
            if leader.icon:IsShown() then leader.roleIcon:SetPoint("LEFT", leader.icon, "RIGHT", 2, 0)
            else leader.roleIcon:SetPoint("LEFT", leader, "LEFT", 0, 0) end
            if leader.roleIcon:IsShown() then leader.name:SetPoint("LEFT", leader.roleIcon, "RIGHT", 3, 0)
            elseif leader.icon:IsShown() then leader.name:SetPoint("LEFT", leader.icon, "RIGHT", 3, 0)
            else leader.name:SetPoint("LEFT", leader, "LEFT", 0, 0) end
            leader.name:SetText(data.leaderName)
            if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
                local color = RAID_CLASS_COLORS[class]
                leader.name:SetTextColor(color.r, color.g, color.b)
            else leader.name:SetTextColor(1, 1, 1) end
            leader:ClearAllPoints()
            -- The native cast bar owns the entire strip beneath the health
            -- bar. Stack Threat Leader above our right-side threat badge
            -- instead, left-aligned to the badge and expanding to the right.
            PixelPoint(leader, "BOTTOMLEFT", overlay.threatBadge, "TOPLEFT", 0, 2)
            leader:SetWidth(150)
            leader.name:SetJustifyH("LEFT")
            leader:Show()
        end
    end

    if TinyThreatPlusDB.showNameplateThreat then
        -- Prefer the normal readable TinyThreatPlus presentation whenever the
        -- API gives us ordinary values. For protected off-target nameplates,
        -- pass Blizzard's live threat percentage straight into the FontString.
        -- The addon never learns or branches on that protected number.
        local hasThreatText = ApplyForeverProtectedThreatText(overlay.threat, unit)
        if hasThreatText then
            overlay.threat:SetTextColor(1, 1, 1)
        elseif data then
            local text = TTP.GetThreatDisplayText(data)
            local r, g, b = TTP.GetThreatColor(unit, data)
            overlay.threat:SetText(text)
            overlay.threat:SetTextColor(r, g, b)
            hasThreatText = true
        end

        if hasThreatText then
            overlay.threatBadge:Show()
            overlay.threat:Show()
        else
            overlay.threat:SetText("")
            overlay.threat:Hide()
            overlay.threatBadge:Hide()
        end

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
        ResetNativeEnhancement(nameplate)
        return
    end
    UpdateNativeEnhancement(unit, nameplate)
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
