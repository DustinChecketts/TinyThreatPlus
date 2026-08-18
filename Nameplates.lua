local TTP = _G.TinyThreatPlus or select(2, ...)

if not TTP then
    error("TinyThreatPlus: shared addon namespace is unavailable.")
end

local function PixelSetPoint(frame, ...)
    if PixelUtil and PixelUtil.SetPoint then
        PixelUtil.SetPoint(frame, ...)
    else
        frame:SetPoint(...)
    end
end

local function PixelSetSize(frame, width, height)
    if PixelUtil and PixelUtil.SetSize then
        PixelUtil.SetSize(frame, width, height)
    else
        frame:SetSize(width, height)
    end
end

-- ---------------------------------------------------------------------------
-- Blizzard nameplate discovery and style helpers
-- ---------------------------------------------------------------------------
local RARE_DRAGON_STYLE = {
    atlas = "nameplates-icon-elite-silver",
    desaturated = true,
    color = { 0.78, 0.79, 0.82, 1.00 },
}

function TTP.GetNameplateHealthBar(nameplate)
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

    local playerLevel = UnitLevel("player") or level
    local difference = level - playerLevel

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

local STYLE_FAMILY_LARGE = "LARGE"
local STYLE_FAMILY_THIN = "THIN"

local function GetNameplateStyleValue()
    return tonumber(TTP.GetCVar("nameplateStyle"))
end

local function GetNameplateStyleFamily()
    local style = GetNameplateStyleValue()

    if Enum and Enum.NamePlateStyle then
        if style == Enum.NamePlateStyle.Modern
            or style == Enum.NamePlateStyle.Block
            or style == Enum.NamePlateStyle.HealthFocus
        then
            return STYLE_FAMILY_LARGE
        end
    else
        -- Anniversary fallback if the enum table is unavailable.
        if style == 0 then
            return STYLE_FAMILY_THIN
        end
    end

    return STYLE_FAMILY_THIN
end

local function IsClassicNameplateStyle()
    local style = GetNameplateStyleValue()

    if Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.Classic ~= nil then
        return style == Enum.NamePlateStyle.Classic
    end

    return style == 0
end

local function GetNameplateSizeSetting()
    local value = tonumber(TTP.GetCVar("nameplateSize")) or 2

    value = math.floor(value + 0.5)

    return math.max(1, math.min(5, value))
end

local THREAT_BOX_STYLE_PROFILES = {
    [STYLE_FAMILY_LARGE] = {
        width = 42,
        fontSize = 12,

        -- Calibrated to visually match Blizzard's combined health-bar +
        -- border height at Nameplate Sizes 1-5.
        heights = {
            [1] = 22,
            [2] = 25,
            [3] = 28,
            [4] = 30,
            [5] = 32,
        },
    },
    [STYLE_FAMILY_THIN] = {
        width = 42,
        fontSize = 10,

        -- Classic shares the thin family for threat-box height.
        heights = {
            [1] = 14,
            [2] = 16,
            [3] = 17,
            [4] = 18,
            [5] = 21,
        },
    },
}

local function GetThreatBoxStyleProfile()
    return THREAT_BOX_STYLE_PROFILES[GetNameplateStyleFamily()]
        or THREAT_BOX_STYLE_PROFILES[STYLE_FAMILY_THIN]
end

local function GetThreatBoxHeight(profile)
    local size = GetNameplateSizeSetting()

    return profile.heights[size]
        or profile.heights[2]
end

local NAMEPLATE_SIZE_SCALES = {
    [1] = {
        modernHorizontal = 0.75,
        modernVertical = 0.80,
        modernClassification = 0.80,
        classicHorizontal = 0.80,
        classicVertical = 0.80,
        classicClassification = 0.80,
    },
    [2] = {
        modernHorizontal = 1.00,
        modernVertical = 1.00,
        modernClassification = 1.00,
        classicHorizontal = 1.00,
        classicVertical = 1.00,
        classicClassification = 1.00,
    },
    [3] = {
        modernHorizontal = 1.25,
        modernVertical = 1.25,
        modernClassification = 1.25,
        classicHorizontal = 1.25,
        classicVertical = 1.25,
        classicClassification = 1.25,
    },
    [4] = {
        modernHorizontal = 1.40,
        modernVertical = 1.40,
        modernClassification = 1.40,
        classicHorizontal = 1.40,
        classicVertical = 1.40,
        classicClassification = 1.40,
    },
    [5] = {
        modernHorizontal = 1.60,
        modernVertical = 1.60,
        modernClassification = 1.60,
        classicHorizontal = 1.60,
        classicVertical = 1.60,
        classicClassification = 1.60,
    },
}

local function GetNameplateVisualScales()
    local size = GetNameplateSizeSetting()
    local native = NAMEPLATE_SIZE_SCALES[size]

    if IsClassicNameplateStyle() then
        return
            native.classicHorizontal,
            native.classicVertical,
            native.classicClassification
    end

    return
        native.modernHorizontal,
        native.modernVertical,
        native.modernClassification
end

local function GetActualNameplateScales()
    local size = GetNameplateSizeSetting()
    local native = NAMEPLATE_SIZE_SCALES[size]

    if IsClassicNameplateStyle() then
        return
            native.classicHorizontal,
            native.classicVertical,
            native.classicClassification
    end

    return
        native.modernHorizontal,
        native.modernVertical,
        native.modernClassification
end

-- ---------------------------------------------------------------------------
-- Mob level and rarity / raid-marker layout
-- ---------------------------------------------------------------------------
local function ApplyModernLevelBadgeScale(badge)
    local _, _, classificationScale =
        GetNameplateVisualScales()

    local baseSize = 20
    local bevelSize = 18
    local innerSize = 16
    local skullSize = 12

    PixelSetSize(
        badge,
        baseSize * classificationScale,
        baseSize * classificationScale
    )

    PixelSetSize(
        badge.modernBevel,
        bevelSize * classificationScale,
        bevelSize * classificationScale
    )

    PixelSetSize(
        badge.modernInner,
        innerSize * classificationScale,
        innerSize * classificationScale
    )

    PixelSetSize(
        badge.text,
        baseSize * classificationScale,
        baseSize * classificationScale
    )

    PixelSetSize(
        badge.skull,
        skullSize * classificationScale,
        skullSize * classificationScale
    )

    badge.TinyThreatPlusLevelScale = classificationScale
    badge.TinyThreatPlusLevelBaseSize = baseSize
end

local function ApplyLevelBadgeStyle(badge)
    local borderColor = TTP.colors.levelBorderInactive

    badge.modernOuter:SetVertexColor(
        TTP.colors.levelBevelDark[1],
        TTP.colors.levelBevelDark[2],
        TTP.colors.levelBevelDark[3],
        1
    )

    badge.modernBevel:SetVertexColor(
        borderColor[1],
        borderColor[2],
        borderColor[3],
        1
    )

    badge.fill:SetColorTexture(
        TTP.colors.modernLevelFill[1],
        TTP.colors.modernLevelFill[2],
        TTP.colors.modernLevelFill[3],
        TTP.colors.modernLevelFill[4]
    )
end

local function CreateLevelBadge(nameplate)
    if nameplate.TinyThreatPlusLevel then
        return nameplate.TinyThreatPlusLevel
    end

    local badge = CreateFrame("Frame", nil, nameplate)

    badge:SetFrameStrata("HIGH")
    badge:SetFrameLevel((nameplate:GetFrameLevel() or 1) + 80)
    PixelSetSize(badge, 20, 20)
    badge:SetIgnoreParentAlpha(true)
    badge:SetAlpha(1)

    badge.fill = badge:CreateTexture(nil, "BACKGROUND")
    badge.fill:SetAllPoints()
    badge.fill:SetIgnoreParentAlpha(true)
    badge.fill:SetAlpha(1)
    badge.fill:SetColorTexture(0.02, 0.02, 0.02, 0.72)

    badge.mask = badge:CreateMaskTexture(nil, "BACKGROUND")
    badge.mask:SetAllPoints()
    badge.mask:SetTexture(
        "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
    )
    badge.fill:AddMaskTexture(badge.mask)

    -- Modern outer edge: dark base, similar to the shadowed edge
    -- of the TinyThreatPlus threat-box border.
    badge.modernOuter =
        badge:CreateTexture(nil, "BORDER", nil, 1)

    badge.modernOuter:SetAllPoints()
    badge.modernOuter:SetColorTexture(
        TTP.colors.levelBevelDark[1],
        TTP.colors.levelBevelDark[2],
        TTP.colors.levelBevelDark[3],
        1
    )

    badge.modernOuterMask =
        badge:CreateMaskTexture(nil, "BORDER")

    badge.modernOuterMask:SetAllPoints()
    badge.modernOuterMask:SetTexture(
        "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
    )
    badge.modernOuter:AddMaskTexture(badge.modernOuterMask)

    -- Middle circle supplies the subtle silver/gray bevel.
    badge.modernBevel =
        badge:CreateTexture(nil, "ARTWORK", nil, 1)

    PixelSetSize(badge.modernBevel, 18, 18)
    PixelSetPoint(
        badge.modernBevel,
        "CENTER",
        badge,
        "CENTER",
        0,
        0
    )
    badge.modernBevel:SetColorTexture(0.86, 0.86, 0.89, 1)

    badge.modernBevelMask =
        badge:CreateMaskTexture(nil, "ARTWORK")

    badge.modernBevelMask:SetAllPoints(badge.modernBevel)
    badge.modernBevelMask:SetTexture(
        "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
    )
    badge.modernBevel:AddMaskTexture(badge.modernBevelMask)

    -- Inner dark circle completes the beveled effect.
    badge.modernInner =
        badge:CreateTexture(nil, "ARTWORK", nil, 2)

    PixelSetSize(badge.modernInner, 16, 16)
    PixelSetPoint(
        badge.modernInner,
        "CENTER",
        badge,
        "CENTER",
        0,
        0
    )
    badge.modernInner:SetColorTexture(
        TTP.colors.modernLevelFill[1],
        TTP.colors.modernLevelFill[2],
        TTP.colors.modernLevelFill[3],
        1
    )

    badge.modernInnerMask =
        badge:CreateMaskTexture(nil, "ARTWORK")

    badge.modernInnerMask:SetAllPoints(badge.modernInner)
    badge.modernInnerMask:SetTexture(
        "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
    )
    badge.modernInner:AddMaskTexture(badge.modernInnerMask)

    badge.text =
        badge:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormal",
            7
        )

    PixelSetSize(badge.text, 20, 20)
    badge.text:SetIgnoreParentAlpha(true)
    badge.text:SetAlpha(1)
    PixelSetPoint(
        badge.text,
        "CENTER",
        badge,
        "CENTER",
        0,
        0
    )
    badge.text:SetJustifyH("CENTER")
    badge.text:SetJustifyV("MIDDLE")

    badge.skull =
        badge:CreateTexture(nil, "OVERLAY", nil, 7)

    PixelSetSize(badge.skull, 12, 12)
    PixelSetPoint(
        badge.skull,
        "CENTER",
        badge,
        "CENTER",
        0,
        0
    )
    badge.skull:SetIgnoreParentAlpha(true)
    badge.skull:SetAlpha(1)
    badge.skull:SetTexture(
        "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
    )
    badge.skull:Hide()

    badge:Hide()
    nameplate.TinyThreatPlusLevel = badge

    return badge
end

local function HideLevelBadge(nameplate)
    if nameplate and nameplate.TinyThreatPlusLevel then
        nameplate.TinyThreatPlusLevel:Hide()
    end
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

    frame.TinyThreatPlusModified = nil

    local indicator = frame.classificationIndicator

    if indicator then
        indicator:SetIgnoreParentAlpha(false)
        indicator:SetAlpha(1)
        indicator:SetDesaturated(false)
        indicator:SetVertexColor(1, 1, 1, 1)
    end

    -- Return control completely to Blizzard.
    if frame.UpdateClassificationIndicator then
        frame.classificationAtlasElement = nil
        frame:UpdateClassificationIndicator()
    elseif frame.UpdateShownState then
        frame:UpdateShownState()
    end
end

local function HasBlizzardRaidMarker(nameplate)
    local unitFrame = nameplate and nameplate.UnitFrame
    local raidTargetFrame = unitFrame and unitFrame.RaidTargetFrame

    if not raidTargetFrame then
        return false
    end

    local raidTargetIndex =
        raidTargetFrame.raidTargetIndex
        or (
            unitFrame.GetRaidTargetIndex
            and unitFrame:GetRaidTargetIndex()
        )

    return raidTargetIndex ~= nil and raidTargetIndex ~= 0
end

local function BlizzardShowsRarityIcon(frame)
    if not frame then
        return false
    end

    if frame.ShouldShowPvEClassificationIndicator then
        return frame:ShouldShowPvEClassificationIndicator() == true
    end

    return frame:IsShown()
end

local function UpdateClassificationFrame(nameplate, healthBar, unit)
    local frame = GetClassificationFrame(nameplate)

    if not frame
        or not unit
        or not UnitExists(unit)
        or UnitIsPlayer(unit)
        or not TTP.IsHostileNPC(unit)
    then
        ResetClassificationFrame(nameplate)
        return nil
    end

    local classification = UnitClassification(unit)

    -- Blizzard raid markers intentionally take priority over classification
    -- artwork. Never force TinyThreatPlus's plain-rare dragon into the same
    -- information slot while a raid marker is assigned.
    if HasBlizzardRaidMarker(nameplate) then
        ResetClassificationFrame(nameplate)
        return nil
    end

    -- Blizzard owns elite, rare-elite and world-boss icons. TinyThreatPlus
    -- only corrects the missing/undesirable plain-rare treatment.
    if classification ~= "rare" then
        ResetClassificationFrame(nameplate)
        return frame:IsShown() and frame or nil
    end

    if not BlizzardShowsRarityIcon(frame) then
        ResetClassificationFrame(nameplate)
        return nil
    end

    local indicator = frame.classificationIndicator

    if not indicator then
        return nil
    end

    -- Keep Blizzard's frame, size and visibility behavior. Only swap the
    -- plain-rare artwork to a muted silver dragon.
    indicator:SetAtlas(RARE_DRAGON_STYLE.atlas, false)
    indicator:SetDesaturated(RARE_DRAGON_STYLE.desaturated)
    indicator:SetVertexColor(unpack(RARE_DRAGON_STYLE.color))
    indicator:SetAlpha(1)

    frame.TinyThreatPlusModified = true
    frame:Show()
    indicator:Show()

    return frame
end

local function GetNativeLevelFrame(nameplate)
    local unitFrame = nameplate and nameplate.UnitFrame

    return unitFrame and unitFrame.LevelFrame or nil
end

local function PositionBlizzardInfoSlot(nameplate, anchorFrame)
    local unitFrame = nameplate and nameplate.UnitFrame

    if not unitFrame or not anchorFrame then
        return
    end

    local classificationFrame = unitFrame.ClassificationFrame
    local raidTargetFrame = unitFrame.RaidTargetFrame

    -- Classification and raid-target artwork intentionally share one slot.
    -- Blizzard decides which is visible; TinyThreatPlus only standardizes
    -- where that slot lives.
    if classificationFrame then
        classificationFrame:ClearAllPoints()
        classificationFrame:SetPoint(
            "RIGHT",
            anchorFrame,
            "LEFT",
            -1,
            0
        )
    end

    if raidTargetFrame then
        raidTargetFrame:ClearAllPoints()
        raidTargetFrame:SetPoint(
            "RIGHT",
            anchorFrame,
            "LEFT",
            -1,
            0
        )
    end
end

local function RestoreClassicHealthBarLayout(nameplate, healthBar)
    if not healthBar then
        return
    end

    local unitFrame = nameplate and nameplate.UnitFrame
    local container = unitFrame and unitFrame.HealthBarsContainer
    local bgTexture = healthBar.bgTexture

    if not container then
        return
    end

    if not IsClassicNameplateStyle() then
        -- Restore Blizzard's modern StatusBar geometry without measuring any
        -- restricted regions.
        healthBar:ClearAllPoints()
        PixelSetPoint(
            healthBar,
            "TOPLEFT",
            container,
            "TOPLEFT",
            0,
            0
        )
        PixelSetPoint(
            healthBar,
            "BOTTOMRIGHT",
            container,
            "BOTTOMRIGHT",
            0,
            0
        )

        if bgTexture then
            bgTexture:SetTexCoord(0, 1, 0, 1)
        end
    end
end

local function GetNativeNameFontString(nameplate, healthBar)
    local unitFrame = nameplate and nameplate.UnitFrame

    return
        (unitFrame and unitFrame.name)
        or (healthBar and healthBar.unitNameFontString)
        or nil
end

local function PositionClassicName(nameplate, healthBar)
    local nameText = GetNativeNameFontString(nameplate, healthBar)

    if not nameText then
        return
    end

    nameText:ClearAllPoints()
    nameText:SetJustifyH("LEFT")

    PixelSetPoint(
        nameText,
        "BOTTOMLEFT",
        healthBar,
        "TOPLEFT",
        0,
        2
    )
end

local function PositionClassicLevel(nameplate, healthBar)
    local unitFrame = nameplate and nameplate.UnitFrame
    local container = unitFrame and unitFrame.HealthBarsContainer
    local levelFrame = GetNativeLevelFrame(nameplate)
    local bgTexture = healthBar and healthBar.bgTexture

    if not container
        or not levelFrame
        or not healthBar
        or not bgTexture
    then
        return nil
    end

    local horizontalScale, verticalScale =
        GetActualNameplateScales()

    -- Mirror Blizzard's exact Classic StatusBar insets. This moves the
    -- reserved level-cap area from the right side of the bar to the left
    -- without ever calling GetPoint() or otherwise measuring the protected
    -- StatusBar.
    healthBar:ClearAllPoints()

    PixelSetPoint(
        healthBar,
        "TOPLEFT",
        container,
        "TOPLEFT",
        20.75 * horizontalScale,
        0.5 * verticalScale
    )

    PixelSetPoint(
        healthBar,
        "BOTTOMRIGHT",
        container,
        "BOTTOMRIGHT",
        -3.5 * horizontalScale,
        0.5 * verticalScale
    )

    -- Blizzard's Classic level background is part of Nameplate-Border.
    -- Keep the native 128x16 asset and scale, but mirror it horizontally so
    -- the complete gold level cap moves to the left.
    bgTexture:ClearAllPoints()
    bgTexture:SetTexCoord(1, 0, 0.5, 1)

    PixelSetPoint(
        bgTexture,
        "CENTER",
        container,
        "CENTER",
        0,
        0
    )

    PixelSetSize(
        bgTexture,
        128 * horizontalScale,
        16 * verticalScale
    )

    -- Blizzard normally anchors LevelFrame 11 pixels inside the right cap.
    -- Mirror that exact placement into the left cap.
    levelFrame:ClearAllPoints()

    PixelSetPoint(
        levelFrame,
        "CENTER",
        bgTexture,
        "LEFT",
        11 * horizontalScale,
        0
    )

    PositionBlizzardInfoSlot(nameplate, levelFrame)

    return levelFrame
end

local function PositionModernLevel(nameplate, healthBar, badge)
    badge:ClearAllPoints()

    PixelSetPoint(
        badge,
        "RIGHT",
        healthBar,
        "LEFT",
        -1,
        0
    )

    PositionBlizzardInfoSlot(nameplate, badge)
end

local function PositionInfoWithoutLevel(nameplate, healthBar)
    -- If the custom modern level is disabled, rarity / raid-marker artwork
    -- simply occupies the position immediately left of the health bar.
    PositionBlizzardInfoSlot(nameplate, healthBar)
end

local function UpdateLevelAndClassification(nameplate, healthBar, unit)
    UpdateClassificationFrame(nameplate, healthBar, unit)

    if IsClassicNameplateStyle() then
        -- Classic already provides the level natively. We only relocate
        -- Blizzard's LevelFrame into the same inline information hierarchy
        -- used by modern TinyThreatPlus plates.
        HideLevelBadge(nameplate)
        PositionClassicLevel(nameplate, healthBar)
        PositionClassicName(nameplate, healthBar)
        return
    end

    RestoreClassicHealthBarLayout(nameplate, healthBar)

    if not ShouldShowLevel(unit) then
        HideLevelBadge(nameplate)
        PositionInfoWithoutLevel(nameplate, healthBar)
        return
    end

    local level = UnitLevel(unit)

    if not level or level == 0 then
        HideLevelBadge(nameplate)
        PositionInfoWithoutLevel(nameplate, healthBar)
        return
    end

    local badge = CreateLevelBadge(nameplate)

    local healthLevel =
        healthBar.GetFrameLevel
        and healthBar:GetFrameLevel()
        or 1

    local classificationFrame = GetClassificationFrame(nameplate)

    local classificationLevel =
        classificationFrame
        and classificationFrame.GetFrameLevel
        and classificationFrame:GetFrameLevel()
        or 1

    badge:SetFrameStrata("HIGH")
    badge:SetFrameLevel(
        math.max(
            (nameplate:GetFrameLevel() or 1) + 80,
            healthLevel + 20,
            classificationLevel + 20
        )
    )

    ApplyModernLevelBadgeScale(badge)
    ApplyLevelBadgeStyle(badge)

    badge:SetIgnoreParentAlpha(true)
    badge:SetAlpha(1)
    badge.fill:SetAlpha(1)
    badge.modernOuter:SetAlpha(1)
    badge.modernBevel:SetAlpha(1)
    badge.modernInner:SetAlpha(1)
    badge.text:SetAlpha(1)
    badge.skull:SetAlpha(1)

    PositionModernLevel(nameplate, healthBar, badge)

    if level < 0 then
        badge.text:Hide()
        badge.skull:Show()
    else
        local red, green, blue = GetDifficultyColor(level)
        local levelText = tostring(level)
        local badgeScale =
            badge.TinyThreatPlusLevelScale or 1

        local baseSize =
            badge.TinyThreatPlusLevelBaseSize or 20

        local baseFont =
            baseSize <= 16
            and (#levelText >= 2 and 8 or 9)
            or (#levelText >= 2 and 9 or 10)

        local fontSize = baseFont * badgeScale

        local xOffset =
            (#levelText == 1 and 1 or 0) * badgeScale

        badge.skull:Hide()

        badge.text:SetFont(
            STANDARD_TEXT_FONT,
            fontSize,
            "OUTLINE"
        )
        badge.text:ClearAllPoints()
        PixelSetPoint(
            badge.text,
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

-- ---------------------------------------------------------------------------
-- Threat-box and Blizzard side-aura layout
-- ---------------------------------------------------------------------------
local function AnchorThreatBox(nameplate, healthBar, box)
    box:ClearAllPoints()

    PixelSetPoint(
        box,
        "LEFT",
        healthBar,
        "RIGHT",
        1,
        0
    )
end


local function RestoreSideAuraLayout(nameplate)
    local unitFrame = nameplate and nameplate.UnitFrame
    local aurasFrame = unitFrame and unitFrame.AurasFrame
    local healthBarsContainer =
        unitFrame and unitFrame.HealthBarsContainer

    if not aurasFrame or not healthBarsContainer then
        return
    end

    local crowdControlFrame = aurasFrame.CrowdControlListFrame
    local lossOfControlFrame = aurasFrame.LossOfControlFrame

    -- Blizzard's native layout places Shared CC / Crowd Control and
    -- Loss-of-Control icons immediately to the right of the health bars.
    if crowdControlFrame then
        crowdControlFrame:ClearAllPoints()
        PixelSetPoint(
            crowdControlFrame,
            "LEFT",
            healthBarsContainer,
            "RIGHT",
            5,
            0
        )
    end

    if lossOfControlFrame then
        lossOfControlFrame:ClearAllPoints()
        PixelSetPoint(
            lossOfControlFrame,
            "LEFT",
            healthBarsContainer,
            "RIGHT",
            5,
            0
        )
    end
end

local function UpdateSideAuraLayout(nameplate, box)
    local unitFrame = nameplate and nameplate.UnitFrame
    local aurasFrame = unitFrame and unitFrame.AurasFrame

    if not aurasFrame or not box or not box:IsShown() then
        RestoreSideAuraLayout(nameplate)
        return
    end

    local crowdControlFrame = aurasFrame.CrowdControlListFrame
    local lossOfControlFrame = aurasFrame.LossOfControlFrame

    -- TinyThreatPlus uses Blizzard's native right-side information slot for
    -- the threat box. Preserve Blizzard's horizontal CC layout by moving
    -- those native side-aura frames to immediately AFTER our threat box:
    --
    -- Health Bar > Threat Box > Target Counter > Shared CC / Loss of Control
    --
    -- We do not reparent the aura frames, touch their LayoutFrame children,
    -- or force a layout pass.
    if crowdControlFrame then
        crowdControlFrame:ClearAllPoints()
        PixelSetPoint(
            crowdControlFrame,
            "LEFT",
            box,
            "RIGHT",
            22,
            0
        )
    end

    if lossOfControlFrame then
        lossOfControlFrame:ClearAllPoints()
        PixelSetPoint(
            lossOfControlFrame,
            "LEFT",
            box,
            "RIGHT",
            22,
            0
        )
    end
end

local function RestoreHealthBarColor(nameplate)
    local unitFrame = nameplate and nameplate.UnitFrame

    if unitFrame and CompactUnitFrame_UpdateHealthColor then
        CompactUnitFrame_UpdateHealthColor(unitFrame)
    end
end

local CLASS_ICON_ATLASES = {
    WARRIOR = "groupfinder-icon-class-warrior",
    MAGE = "groupfinder-icon-class-mage",
    ROGUE = "groupfinder-icon-class-rogue",
    DRUID = "groupfinder-icon-class-druid",
    HUNTER = "groupfinder-icon-class-hunter",
    SHAMAN = "groupfinder-icon-class-shaman",
    PRIEST = "groupfinder-icon-class-priest",
    WARLOCK = "groupfinder-icon-class-warlock",
    PALADIN = "groupfinder-icon-class-paladin",
    DEATHKNIGHT = "groupfinder-icon-class-deathknight",
}

local ROLE_ICON_ATLASES = {
    TANK = "groupfinder-icon-role-large-tank",
    HEALER = "groupfinder-icon-role-large-heal",
    DAMAGER = "groupfinder-icon-role-large-dps",
}

-- ---------------------------------------------------------------------------
-- Threat Leader and Target Counter
-- ---------------------------------------------------------------------------
local function GetThreatLeaderFrame(nameplate)
    if nameplate.TinyThreatPlusThreatLeader then return nameplate.TinyThreatPlusThreatLeader end
    local frame=CreateFrame("Frame",nil,nameplate)
    frame:SetFrameStrata(nameplate:GetFrameStrata()); frame:SetFrameLevel((nameplate:GetFrameLevel() or 1)+34)
    frame:SetHeight(15); frame:SetWidth(140)
    frame.classIcon=frame:CreateTexture(nil,"ARTWORK"); frame.classIcon:SetSize(14,14); frame.classIcon:SetPoint("LEFT",frame,"LEFT",0,0); frame.classIcon:Hide()
    frame.classIconBorder=frame:CreateTexture(nil,"OVERLAY"); frame.classIconBorder:SetSize(14,14); frame.classIconBorder:SetPoint("CENTER",frame.classIcon,"CENTER",0,0); frame.classIconBorder:SetAtlas("Capacitance-General-PortraitRing"); frame.classIconBorder:Hide()
    frame.name=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); frame.name:SetJustifyH("LEFT"); frame.name:SetJustifyV("MIDDLE")
    local font,size=frame.name:GetFont(); frame.name:SetFont(font,size,"OUTLINE")
    frame.roleIcon=frame:CreateTexture(nil,"OVERLAY"); frame.roleIcon:SetSize(14,14); frame.roleIcon:Hide()
    frame:Hide(); nameplate.TinyThreatPlusThreatLeader=frame; return frame
end

local function IsPetUnit(unit)
    return unit and (unit=="pet" or string.match(unit,"^partypet%d+$") or string.match(unit,"^raidpet%d+$")) or false
end

local function SetThreatLeaderClassIcon(texture, class)
    if not texture or not class then
        return false
    end

    local atlas = CLASS_ICON_ATLASES[class]

    if atlas then
        texture:SetTexCoord(0, 1, 0, 1)
        texture:SetAtlas(atlas)
        return true
    end

    -- Classic-safe fallback if one of the Group Finder class atlases is
    -- unavailable in this Anniversary client.
    local coords =
        CLASS_ICON_TCOORDS
        and CLASS_ICON_TCOORDS[class]

    if coords then
        texture:SetTexture(
            "Interface\GLUES\CHARACTERCREATE\UI-CHARACTERCREATE-CLASSES"
        )
        texture:SetTexCoord(
            coords[1],
            coords[2],
            coords[3],
            coords[4]
        )
        return true
    end

    return false
end

local function SetThreatLeaderRoleIcon(texture, role)
    if not texture or not role then
        return false
    end

    local atlas = ROLE_ICON_ATLASES[role]

    if not atlas then
        return false
    end

    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetAtlas(atlas)

    return true
end

local function ApplyTargetCounterScale(box)
    if not box or not box.counter then
        return
    end

    local _, _, classificationScale =
        GetNameplateVisualScales()

    local userScale =
        (TinyThreatPlusDB.nameplateThreatScale or 100) / 100

    local scale = classificationScale * userScale

    box.counter:SetScale(scale)

    if box.counterText then
        box.counterText:SetScale(1)
    end
end

local function ApplyThreatLeaderScale(frame)
    local _, verticalScale, classificationScale =
        GetNameplateVisualScales()

    local userScale =
        (TinyThreatPlusDB.nameplateThreatScale or 100) / 100

    local iconScale = classificationScale * userScale
    local textScale = verticalScale * userScale

    frame:SetHeight(15 * textScale)

    frame.classIcon:SetSize(
        14 * iconScale,
        14 * iconScale
    )

    frame.classIconBorder:SetSize(
        14 * iconScale,
        14 * iconScale
    )

    frame.roleIcon:SetSize(
        14 * iconScale,
        14 * iconScale
    )

    local font = STANDARD_TEXT_FONT
    local fontSize = 10 * textScale

    frame.name:SetFont(
        font,
        fontSize,
        "OUTLINE"
    )

    frame.TinyThreatPlusIconSpacing =
        math.max(1, math.floor(iconScale + 0.5))
end

local function UpdateThreatLeader(nameplate, threatBox, data)
    local frame = GetThreatLeaderFrame(nameplate)

    ApplyThreatLeaderScale(frame)

    if not TinyThreatPlusDB.showThreatLeader
        or not threatBox
        or not threatBox:IsShown()
        or not data
        or not data.leaderName
    then
        frame:Hide()
        return
    end

    local leaderUnit = data.leaderUnit
    local leaderName = data.leaderName
    local unitExists =
        leaderUnit
        and UnitExists(leaderUnit)

    local isPlayer =
        unitExists
        and UnitIsPlayer(leaderUnit)

    local isPet =
        unitExists
        and IsPetUnit(leaderUnit)

    local class

    if isPlayer then
        local _
        _, class = UnitClass(leaderUnit)
    end

    frame:ClearAllPoints()
    frame:SetPoint(
        "TOPLEFT",
        threatBox,
        "BOTTOMLEFT",
        0,
        1
    )

    frame.classIcon:Hide()
    frame.classIconBorder:Hide()

    if TinyThreatPlusDB.showThreatLeaderClassIcon then
        if isPlayer and class then
            if SetThreatLeaderClassIcon(
                frame.classIcon,
                class
            ) then
                frame.classIcon:Show()
            end
        elseif isPet then
            frame.classIcon:SetTexCoord(0, 1, 0, 1)
            SetPortraitTexture(
                frame.classIcon,
                leaderUnit
            )
            frame.classIcon:Show()
            frame.classIconBorder:Show()
        end
    end

    frame.name:ClearAllPoints()

    if frame.classIcon:IsShown() then
        frame.name:SetPoint(
            "LEFT",
            frame.classIcon,
            "RIGHT",
            frame.TinyThreatPlusIconSpacing or 1,
            0
        )
    else
        frame.name:SetPoint(
            "LEFT",
            frame,
            "LEFT",
            0,
            0
        )
    end

    frame.name:SetText(leaderName)

    if isPlayer
        and class
        and RAID_CLASS_COLORS
        and RAID_CLASS_COLORS[class]
    then
        local color = RAID_CLASS_COLORS[class]

        frame.name:SetTextColor(
            color.r,
            color.g,
            color.b
        )
    else
        frame.name:SetTextColor(1, 1, 1)
    end

    frame.roleIcon:Hide()

    if TinyThreatPlusDB.showThreatLeaderRole
        and isPlayer
    then
        local role = TTP.GetUnitRole(leaderUnit)

        if role then
            frame.roleIcon:ClearAllPoints()
            frame.roleIcon:SetPoint(
                "LEFT",
                frame.name,
                "RIGHT",
                1,
                0
            )

            if SetThreatLeaderRoleIcon(
                frame.roleIcon,
                role
            ) then
                frame.roleIcon:Show()
            end
        end
    end

    local width = frame.name:GetStringWidth()

    if frame.classIcon:IsShown() then
        width =
            width
            + frame.classIcon:GetWidth()
            + (frame.TinyThreatPlusIconSpacing or 1)
    end

    if frame.roleIcon:IsShown() then
        width =
            width
            + frame.roleIcon:GetWidth()
            + (frame.TinyThreatPlusIconSpacing or 1)
    end

    frame:SetWidth(math.max(20, width))
    frame:SetAlpha(threatBox:GetAlpha() or 1)
    frame:Show()
end

local function HideThreatLeader(nameplate)
    if nameplate and nameplate.TinyThreatPlusThreatLeader then nameplate.TinyThreatPlusThreatLeader:Hide() end
end

-- ---------------------------------------------------------------------------
-- Target Priority presentation
-- ---------------------------------------------------------------------------
local function GetPriorityMarker(nameplate)
    if nameplate.TinyThreatPlusPriorityMarker then
        return nameplate.TinyThreatPlusPriorityMarker
    end

    local marker =
        CreateFrame(
            "Frame",
            nil,
            nameplate,
            "BackdropTemplate"
        )

    marker:SetFrameStrata(nameplate:GetFrameStrata())
    marker:Hide()

    nameplate.TinyThreatPlusPriorityMarker = marker
    return marker
end

local function ApplyPriorityMarkerAppearance(
    marker,
    healthBar
)
    local color =
        TinyThreatPlusDB.priorityMarkerColor
        or TTP.defaults.priorityMarkerColor
        or { 0.01, 0.04, 0.10 }

    local opacity =
        math.max(
            0,
            math.min(
                1,
                (tonumber(
                    TinyThreatPlusDB.priorityMarkerOpacity
                ) or 100) / 100
            )
        )

    local sizeRating =
        math.max(
            1,
            math.min(
                6,
                tonumber(
                    TinyThreatPlusDB.priorityMarkerSizeRating
                ) or 3
            )
        )

    -- User-facing Size is a simple 1-6 rating.
    -- Each step is exactly one pixel:
    -- 1=5px, 2=6px, 3=7px, 4=8px, 5=9px, 6=10px.
    local padding =
        sizeRating + 4

    marker:ClearAllPoints()
    marker:SetPoint(
        "TOPLEFT",
        healthBar,
        "TOPLEFT",
        -padding,
        padding
    )
    marker:SetPoint(
        "BOTTOMRIGHT",
        healthBar,
        "BOTTOMRIGHT",
        padding,
        -padding
    )

    -- Reuse exactly the same border/backdrop treatment as the threat box.
    -- Only the interior background color is different.
    TTP.ApplyBoxStyle(
        marker,
        healthBar:GetHeight() + (padding * 2)
    )

    marker:SetBackdropColor(
        color[1],
        color[2],
        color[3],
        opacity
    )

    marker:SetBackdropBorderColor(
        unpack(TTP.colors.border)
    )
end

local function HidePriorityMarker(marker)
    if marker then
        marker:Hide()
    end
end

local function UpdatePriorityMarker(
    nameplate,
    healthBar,
    unit
)
    local marker = GetPriorityMarker(nameplate)

    local allowed =
        TinyThreatPlusDB.showPriorityMarker
        or TTP.priorityTestActive

    if not allowed
        or (
            TTP.GetPriorityRole() == "HEALER"
            and not TTP.priorityTestActive
        )
        or unit ~= TTP.priorityUnit
    then
        HidePriorityMarker(marker)
        return
    end

    local healthLevel =
        healthBar.GetFrameLevel
        and healthBar:GetFrameLevel()
        or 1

    marker:SetFrameStrata(
        healthBar:GetFrameStrata()
    )

    marker:SetFrameLevel(
        math.max(
            0,
            healthLevel - 1
        )
    )

    ApplyPriorityMarkerAppearance(
        marker,
        healthBar
    )

    marker:SetAlpha(1)
    marker:Show()
end

-- ---------------------------------------------------------------------------
-- Nameplate lifecycle and threat coloring
-- ---------------------------------------------------------------------------
function TTP.ClearNameplate(nameplate)
    if not nameplate then
        return
    end

    local healthBar =
        nameplate.TinyThreatPlusHealthBar
        or TTP.GetNameplateHealthBar(nameplate)

    if healthBar then
        healthBar.TinyThreatPlusUnit = nil
    end

    if nameplate.TinyThreatPlusBox then
        nameplate.TinyThreatPlusBox:Hide()
    end

    if nameplate.TinyThreatPlusPriorityMarker then
        HidePriorityMarker(
            nameplate.TinyThreatPlusPriorityMarker
        )
    end

    HideThreatLeader(nameplate)
    HideLevelBadge(nameplate)
    RestoreSideAuraLayout(nameplate)
    ResetClassificationFrame(nameplate)

    if healthBar then
        RestoreClassicHealthBarLayout(nameplate, healthBar)
    end

    RestoreHealthBarColor(nameplate)

    nameplate.TinyThreatPlusHealthBar = nil
end

local function ApplyNameplateColor(healthBar, unit, data)
    if not TinyThreatPlusDB.roleBasedColors
        or not healthBar
        or not healthBar.SetStatusBarColor
        or not TTP.IsHostileNPC(unit)
    then
        return
    end

    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)

    if not nameplate
        or TTP.GetNameplateHealthBar(nameplate) ~= healthBar
    then
        healthBar.TinyThreatPlusUnit = nil
        return
    end

    local red, green, blue = TTP.GetThreatColor(unit, data)

    TTP.applyingHealthColor = true
    healthBar:SetStatusBarColor(red, green, blue)
    TTP.applyingHealthColor = false
end

local function HookHealthBarColor(healthBar)
    if not healthBar or healthBar.TinyThreatPlusHooked then
        return
    end

    healthBar.TinyThreatPlusHooked = true

    hooksecurefunc(healthBar, "SetStatusBarColor", function(bar)
        if TTP.applyingHealthColor
            or not TinyThreatPlusDB.roleBasedColors
        then
            return
        end

        local unit = bar.TinyThreatPlusUnit

        if not TTP.IsHostileNPC(unit) then
            bar.TinyThreatPlusUnit = nil
            return
        end

        local nameplate = C_NamePlate.GetNamePlateForUnit(unit)

        if not nameplate
            or TTP.GetNameplateHealthBar(nameplate) ~= bar
        then
            bar.TinyThreatPlusUnit = nil
            return
        end

        local data = TTP.GetThreatData(unit)

        if data then
            ApplyNameplateColor(bar, unit, data)
        end
    end)
end

function TTP.UpdateNameplate(unit)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)

    if not nameplate or nameplate:IsForbidden() then
        return
    end

    local healthBar = TTP.GetNameplateHealthBar(nameplate)

    if not healthBar then
        TTP.ClearNameplate(nameplate)
        return
    end

    nameplate.TinyThreatPlusHealthBar = healthBar

    UpdateLevelAndClassification(nameplate, healthBar, unit)

    if not TTP.IsHostileNPC(unit) then
        healthBar.TinyThreatPlusUnit = nil

        if nameplate.TinyThreatPlusBox then
            nameplate.TinyThreatPlusBox:Hide()
        end

        if nameplate.TinyThreatPlusPriorityMarker then
            nameplate.TinyThreatPlusPriorityMarker:Hide()
        end

        HideThreatLeader(nameplate)
        RestoreSideAuraLayout(nameplate)
        return
    end

    if not TinyThreatPlusDB.showNameplates then
        healthBar.TinyThreatPlusUnit = nil

        if nameplate.TinyThreatPlusBox then
            nameplate.TinyThreatPlusBox:Hide()
        end

        if nameplate.TinyThreatPlusPriorityMarker then
            nameplate.TinyThreatPlusPriorityMarker:Hide()
        end

        HideThreatLeader(nameplate)
        RestoreSideAuraLayout(nameplate)
        RestoreHealthBarColor(nameplate)
        return
    end

    local data = TTP.GetThreatData(unit)

    if not data then
        healthBar.TinyThreatPlusUnit = nil

        if nameplate.TinyThreatPlusBox then
            nameplate.TinyThreatPlusBox:Hide()
        end

        if nameplate.TinyThreatPlusPriorityMarker then
            nameplate.TinyThreatPlusPriorityMarker:Hide()
        end

        HideThreatLeader(nameplate)
        RestoreSideAuraLayout(nameplate)
        RestoreHealthBarColor(nameplate)
        return
    end

    healthBar.TinyThreatPlusUnit = unit
    HookHealthBarColor(healthBar)

    local box =
        TTP.CreateThreatBox(
            nameplate,
            "TinyThreatPlusBox",
            nil
        )

    local red, green, blue = TTP.GetThreatColor(unit, data)
    local text, isFallback = TTP.GetThreatDisplayText(data)
    if isFallback then red, green, blue = 1, 1, 1 end

    local userScale =
        (TinyThreatPlusDB.nameplateThreatScale or 100) / 100

    local horizontalScale, verticalScale =
        GetNameplateVisualScales()

    local profile = GetThreatBoxStyleProfile()
    local boxHeight = GetThreatBoxHeight(profile)

    box:SetScale(1)

    AnchorThreatBox(nameplate, healthBar, box)

    TTP.UpdateThreatBox(
        box,
        profile.width * horizontalScale * userScale,
        boxHeight * userScale,
        profile.fontSize * verticalScale * userScale,
        text,
        red,
        green,
        blue,
        TTP.GetTargetCounter(unit)
    )

    ApplyTargetCounterScale(box)

    local hasActiveThreat =
        data.hasThreatData
        and (
            (data.playerThreat or 0) > 0
            or (data.highestOtherThreat or 0) > 0
        )

    local emphasizeThreatBox =
        UnitIsUnit(unit, "target")
        or hasActiveThreat

    box:SetAlpha(emphasizeThreatBox and 1.00 or 0.58)

    UpdateSideAuraLayout(nameplate, box)
    UpdateThreatLeader(nameplate, box, data)

    local canApplyThreatColor =
        data.hasThreatData
        or (
            data.isDamageFallback
            and data.leaderUnit
            and (
                TTP.IsOwnPetUnit(data.leaderUnit)
                or UnitIsUnit(data.leaderUnit, "player")
            )
        )

    if canApplyThreatColor and TinyThreatPlusDB.roleBasedColors then
        ApplyNameplateColor(healthBar, unit, data)
    elseif not TinyThreatPlusDB.roleBasedColors then
        RestoreHealthBarColor(nameplate)
    end

    UpdatePriorityMarker(nameplate, healthBar, unit)
end
