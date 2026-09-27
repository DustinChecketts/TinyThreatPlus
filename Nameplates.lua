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

    if TTP.Compat.IsForever() then
        -- Forever's four visible presets are ordered:
        -- Default (thin), Large (large), Block (large), Cast Focus (thin).
        -- Use the actual CVar index instead of Retail enum semantics; the
        -- latter classified Forever Default as a large bar.
        -- Live Forever testing shows Default and Large are the inverse
        -- of the initial CVar mapping.  Block remains tall; Cast Focus thin.
        -- Forever CVar order: Default=0, Large=1, Block=2, Cast Focus=3.
        if style == 0 or style == 2 then
            return STYLE_FAMILY_LARGE
        end
        return STYLE_FAMILY_THIN
    end

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
        fontSize = 10,

        -- Live Forever calibration: the geometry previously used by our
        -- Default/Cast Focus plate visually matches Blizzard Large/Block.
        heights = {
            [1] = 14,
            [2] = 16,
            [3] = 17,
            [4] = 18,
            [5] = 21,
        },
    },
    [STYLE_FAMILY_THIN] = {
        width = 42,
        fontSize = 9,

        -- Default/Cast Focus are distinctly slimmer in Blizzard's preview.
        -- Keep the same size progression but at the thinner native profile.
        heights = {
            [1] = 9,
            [2] = 10,
            [3] = 11,
            [4] = 12,
            [5] = 14,
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

    -- Forever has a native HD circular unit-frame medallion. Keep this on the
    -- addon-owned badge so the level background uses Blizzard art rather than
    -- masked ColorTextures. Anniversary continues to use the legacy layers.
    -- Confirmed Blizzard Forever level medallion.
    badge.foreverCircle = badge:CreateTexture(nil, "OVERLAY", nil, 5)
    badge.foreverCircle:SetAllPoints()
    badge.foreverCircle:SetAtlas("UI-HUD-UnitFrame-SmallCircle", false)
    badge.foreverCircle:SetIgnoreParentAlpha(true)
    badge.foreverCircle:Hide()

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
    badge.text:SetDrawLayer("OVERLAY", 7)

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

    -- Anniversary uses a shared slot, so raid markers take priority there.
    -- Forever has dedicated positions for raid marker and rarity, allowing
    -- both to remain visible just like the established TTP information map.
    if HasBlizzardRaidMarker(nameplate)
        and not TTP.Compat.IsForever()
    then
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

    if TTP.Compat.IsForever() then
        -- Anniversary parity: rarity/classification owns the immediate-left
        -- slot; Blizzard's raid marker sits above that cluster instead of
        -- replacing it.
        if classificationFrame then
            classificationFrame:ClearAllPoints()
            classificationFrame:SetPoint(
                "RIGHT",
                anchorFrame,
                "LEFT",
                -2,
                0
            )
        end

        if raidTargetFrame then
            raidTargetFrame:ClearAllPoints()
            raidTargetFrame:SetPoint(
                "BOTTOM",
                anchorFrame,
                "TOPLEFT",
                -7,
                2
            )
        end
        return
    end

    -- Anniversary/Classic keeps its established shared information slot.
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
    -- Keep Blizzard's functional cast bar, but anchor its container to our
    -- custom health-bar geometry. Forever otherwise retains coordinates from
    -- the native nameplate style, which makes the cast bar float through the
    -- name/health row after we resize HealthBarsContainer.
    local castContainer = unitFrame.CastBarsContainer
    if castContainer then
        -- Forever's CastBarsContainer has its own native internal geometry.
        -- Resizing the container and then stretching castBar to it caused the
        -- live cast fill/text to overlap the health row. Keep Blizzard's cast
        -- bar dimensions and move the *actual cast bar* below our health bar.
        local castBar = castContainer.castBar or unitFrame.castBar

        if castBar then
            castBar:ClearAllPoints()
            PixelSetPoint(castBar, "TOP", healthBar, "BOTTOM", 0, -2)
            PixelSetSize(castBar, 137, 12)
        else
            -- Fallback for builds where only the container is exposed.
            castContainer:ClearAllPoints()
            PixelSetPoint(castContainer, "TOP", healthBar, "BOTTOM", 0, -2)
        end
    end

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

    if TTP.Compat.IsForever() then
        -- Mirror the Anniversary information hierarchy while using Forever's
        -- circular level treatment: rarity/raid marker | health row, with
        -- level tucked into the health bar's upper-left corner.
        PixelSetPoint(
            badge,
            "CENTER",
            healthBar,
            "TOPLEFT",
            -4,
            0
        )
        PositionBlizzardInfoSlot(nameplate, healthBar)
        return
    end

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

local function ApplyForeverLevelBadgeScale(badge, healthHeight)
    -- Keep the level readable while remaining subordinate to the health row.
    -- The badge may exceed the bar by only 2px total (1px per side), rather
    -- than shrinking the numeral into an unreadable dot at Default size.
    -- Fixed Forever medallion size across all four Blizzard styles.
    -- Default/Cast Focus therefore stay slim without shrinking the level,
    -- while Large/Block gain height independently beneath the same badge.
    local size = 17
    local bevelSize = 15
    local innerSize = 13

    PixelSetSize(badge, size, size)
    PixelSetSize(badge.modernBevel, bevelSize, bevelSize)
    PixelSetSize(badge.modernInner, innerSize, innerSize)
    PixelSetSize(badge.text, size, size)
    PixelSetSize(badge.skull, math.max(6, size - 4), math.max(6, size - 4))
    PixelSetSize(badge.foreverCircle, size, size)

    badge.TinyThreatPlusLevelScale = 1
    badge.TinyThreatPlusLevelBaseSize = size
end

-- Forever custom presentation keeps Blizzard's live UnitFrame and StatusBar
-- logic, but takes ownership of visible geometry/art. This follows the safe
-- pattern proven by ClassicUIForever: never replace the world nameplate or
-- hook into Blizzard's protected health update; restyle it from our own pass.
local function SetRegionAlpha(region, alpha)
    if region and region.SetAlpha then
        region:SetAlpha(alpha)
    end
end

local function SetRoundedChromeShown(frame, shown)
    local chrome = frame and frame.TinyThreatPlusRoundedChrome
    if not chrome then return end
    for _, region in pairs(chrome) do
        if region then
            if shown and region.Show then region:Show()
            elseif not shown and region.Hide then region:Hide() end
        end
    end
end

-- Native diagnostic mode must be a true Blizzard-owned presentation. This
-- restores every presentation property that the Forever custom pass mutates
-- and hides all addon-owned chrome, so recycled nameplates cannot retain a
-- half-custom/half-native state after switching modes.
local function RestoreForeverNativePresentation(nameplate, healthBar)
    if not TTP.Compat.IsForever() or not nameplate or not healthBar then
        return
    end

    local unitFrame = nameplate.UnitFrame
    local container = unitFrame and unitFrame.HealthBarsContainer
    if not unitFrame or not container then return end

    HideLevelBadge(nameplate)
    ResetClassificationFrame(nameplate)

    if healthBar.TinyThreatPlusForeverShell then
        healthBar.TinyThreatPlusForeverShell:Hide()
        SetRoundedChromeShown(healthBar.TinyThreatPlusForeverShell, false)
    end
    if healthBar.TinyThreatPlusTargetHighlight then
        healthBar.TinyThreatPlusTargetHighlight:Hide()
        SetRoundedChromeShown(healthBar.TinyThreatPlusTargetHighlight, false)
    end
    if healthBar.TinyThreatPlusForeverBorder then
        healthBar.TinyThreatPlusForeverBorder:Hide()
    end

    local unitSelection =
        unitFrame.selectionHighlight or unitFrame.SelectionHighlight
    SetRegionAlpha(unitSelection, 1)

    for _, key in ipairs({
        "LevelFrame",
        "PlayerLevelDifferentialFrame",
        "PlayerLevelDiffFrame",
    }) do
        SetRegionAlpha(unitFrame[key], 1)
    end

    for _, key in ipairs({
        "selectedBorder",
        "SelectedBorder",
        "deselectedOverlay",
        "DeselectedOverlay",
    }) do
        SetRegionAlpha(healthBar[key], 1)
    end

    if healthBar.bgTexture then
        healthBar.bgTexture:SetAlpha(1)
        if healthBar.bgTexture.SetTexCoord then
            healthBar.bgTexture:SetTexCoord(0, 1, 0, 1)
        end
    end

    -- Ask Blizzard's own mixins to reassert the selected/level presentation
    -- after we restore visibility. These are presentation refreshes only; TTP
    -- does not replace or hook their protected update path.
    if unitFrame.UpdateLevel then
        pcall(unitFrame.UpdateLevel, unitFrame)
    end
    if unitFrame.UpdateSelectionHighlight then
        pcall(unitFrame.UpdateSelectionHighlight, unitFrame)
    elseif unitFrame.UpdateSelection then
        pcall(unitFrame.UpdateSelection, unitFrame)
    end

    -- We cannot reliably reconstruct Blizzard's style-specific anchors after
    -- our custom pass has cleared them. Mark this plate native and let a
    -- /reload (or Blizzard recycling it) instantiate pristine geometry. The
    -- mode itself will no longer mutate native presentation after reload.
    nameplate.TinyThreatPlusForeverHostile = nil
    nameplate.TinyThreatPlusNativePresentation = true
end

local function ApplyForeverCustomLayout(nameplate, healthBar, unit)
    if not TTP.Compat.IsForever()
        or not nameplate
        or not healthBar
        or not unit
    then
        return false
    end

    -- Remember that this world plate belongs to a hostile NPC while that
    -- relationship is accessible. Forever can protect UnitCanAttack/level
    -- data at distance; abandoning the custom pass at that point lets pieces
    -- of Blizzard's native presentation (including its "..." level cap)
    -- reappear on an otherwise TTP-owned plate.
    if TTP.IsHostileNPC(unit) then
        nameplate.TinyThreatPlusForeverHostile = true
    elseif not nameplate.TinyThreatPlusForeverHostile then
        return false
    end

    local unitFrame = nameplate.UnitFrame
    local container = unitFrame and unitFrame.HealthBarsContainer
    if not unitFrame or not container then return false end

    -- Blizzard's own threat-box profile already encodes the visible height
    -- of each selected Nameplate Style + Nameplate Size combination. Use that
    -- same value as the health row's single geometry authority so health and
    -- threat can never drift apart again.
    local horizontalScale = select(1, GetNameplateVisualScales())
    local styleProfile = GetThreatBoxStyleProfile()
    local nativeRowHeight = GetThreatBoxHeight(styleProfile)
    local baseWidth = 137

    container:SetScale(1)
    container:ClearAllPoints()
    PixelSetSize(
        container,
        baseWidth * horizontalScale,
        nativeRowHeight
    )
    PixelSetPoint(container, "BOTTOM", unitFrame, "BOTTOM", 0, 4)

    healthBar:ClearAllPoints()
    healthBar:SetAllPoints(container)

    -- Use Blizzard's native Forever StatusBar fill artwork as well as its
    -- outer shell. The art diagnostic showed the live StatusBar itself using
    -- UI-HUD-CoolDownManager-Bar at 132.9x12.7, with Bar-BG surrounding it
    -- at 140.5x21.6. Keeping the StatusBar as the geometry authority while
    -- applying Blizzard's fill atlas preserves normal fill/clipping behavior
    -- and gives the red/green bar the same shaped interior as the native UI.
    local statusTexture = healthBar:GetStatusBarTexture()
    if statusTexture and statusTexture.SetAtlas then
        statusTexture:SetAtlas("UI-HUD-CoolDownManager-Bar", false)
        statusTexture:SetTexCoord(0, 1, 0, 1)
    end

    -- Blizzard's native Forever bar shell. The live asset lab confirmed
    -- UI-HUD-CoolDownManager-Bar-BG is the neutral HD frame/background that
    -- matches the native presentation without adding selection or aggro glow.
    local healthShell = healthBar.TinyThreatPlusForeverShell
    if not healthShell then
        healthShell = CreateFrame("Frame", nil, healthBar)
        healthShell:SetAllPoints(healthBar)
        healthShell:SetFrameLevel((healthBar:GetFrameLevel() or 1) + 2)

        local frameArt = healthShell:CreateTexture(nil, "OVERLAY", nil, 0)
        frameArt:SetAtlas("UI-HUD-CoolDownManager-Bar-BG", false)
        frameArt:SetIgnoreParentAlpha(true)
        healthShell.frameArt = frameArt

        healthBar.TinyThreatPlusForeverShell = healthShell
    end

    SetRoundedChromeShown(healthShell, false)
    healthShell:ClearAllPoints()
    healthShell:SetPoint("CENTER", healthBar, "CENTER", 0, 0)

    -- The Default/Large live diagnostics show that Blizzard does NOT scale
    -- the shell proportionally with row height. The same art keeps essentially
    -- fixed edge thickness: 216.4x21.0 -> 224.0x29.8 (Default) and
    -- 216.4x31.7 -> 224.0x40.6 (Large). Preserve that fixed overhang so the
    -- HD edge/corner pixels are not stretched on thin bars.
    local shellWidth = healthBar:GetWidth() + 7.6
    local shellHeight = healthBar:GetHeight() + 8.8
    PixelSetSize(healthShell, shellWidth, shellHeight)

    healthShell.frameArt:ClearAllPoints()
    healthShell.frameArt:SetAllPoints(healthShell)
    healthShell.frameArt:SetVertexColor(1, 1, 1, 1)
    healthShell.frameArt:Show()
    healthShell:Show()

    -- Remove any temporary asset-lab regions left on frames created before a
    -- /reload; a reload normally recreates these, but this keeps ownership
    -- explicit for future diagnostic passes.
    if healthShell.candidates then
        for _, entry in ipairs(healthShell.candidates) do
            if entry.texture then entry.texture:Hide() end
            if entry.label then entry.label:Hide() end
        end
    end

    -- Suppress Blizzard's presentation art while retaining the StatusBar.
    -- The visible Forever level cap is coupled to this presentation rather
    -- than the nominal LevelFrame, which is why hiding LevelFrame alone did
    -- not remove it in live world plates.
    if healthBar.bgTexture then healthBar.bgTexture:SetAlpha(0) end

    -- Forever's native target-selection highlight retains Blizzard's original
    -- geometry after we resize HealthBarsContainer, producing the oversized
    -- bright white outline seen around selected custom plates. The custom
    -- layout owns its border, so suppress that native presentation layer.
    if unitFrame.selectionHighlight then
        unitFrame.selectionHighlight:SetAlpha(0)
    end
    if unitFrame.SelectionHighlight then
        unitFrame.SelectionHighlight:SetAlpha(0)
    end

    for _, key in ipairs({
        "LevelFrame",
        "PlayerLevelDifferentialFrame",
        "PlayerLevelDiffFrame",
    }) do
        local frame = unitFrame[key]
        if frame then frame:SetAlpha(0) end
    end

    -- Blizzard exposes additional selection art on the health StatusBar
    -- itself. This is the thick white frame still visible in live testing;
    -- suppress it along with the UnitFrame-level highlight.
    for _, key in ipairs({
        "selectedBorder",
        "SelectedBorder",
        "deselectedOverlay",
        "DeselectedOverlay",
    }) do
        local region = healthBar[key]
        if region then region:SetAlpha(0) end
    end

    -- Selection highlight intentionally remains disabled while the native shell is validated.
    if healthBar.TinyThreatPlusTargetHighlight then
        healthBar.TinyThreatPlusTargetHighlight:Hide()
    end

    -- The native targeted atlas supplies the visible edge treatment. Do not
    -- stack the legacy WHITE8X8 rectangle over it; that produced the 1px
    -- black box visible along the custom bar.
    if healthBar.TinyThreatPlusForeverBorder then
        healthBar.TinyThreatPlusForeverBorder:Hide()
    end

    -- Reuse our addon-owned circular level badge. Unlike Forever's native
    -- cap this is a normal FontString/texture hierarchy we fully control.
    if ShouldShowLevel(unit) then
        local level = UnitLevel(unit)
        local secret = type(issecretvalue) == "function" and issecretvalue(level)
        local accessible = level ~= nil
            and not secret
            and (
                type(canaccessvalue) ~= "function"
                or canaccessvalue(level)
            )

        -- Forever can return a protected/inaccessible level as the unit moves
        -- out of information range. Passing that value to a FontString is
        -- rendered by Blizzard as "...". Never render protected level data;
        -- hide our badge until a normal numeric level is accessible again.
        if accessible and type(level) == "number" and level ~= 0 then
            local badge = CreateLevelBadge(nameplate)
            ApplyForeverLevelBadgeScale(badge, healthBar:GetHeight())
            ApplyLevelBadgeStyle(badge)

            -- Use the same HD circular frame Blizzard uses on Forever's
            -- player/target unit frames. Hide the old hand-built bronze rings;
            -- retain only a dark masked center behind the level numeral.
            badge.foreverCircle:Show()
            badge.foreverCircle:SetVertexColor(1, 1, 1, 1)
            badge.modernOuter:Hide()
            badge.modernBevel:Hide()
            badge.modernInner:Hide()
            badge.fill:SetColorTexture(0.025, 0.025, 0.022, 0.98)

            PositionModernLevel(nameplate, healthBar, badge)

            local playerLevel = UnitLevel("player")
            local isSkullLevel =
                level < 0
                or (
                    type(playerLevel) == "number"
                    and playerLevel > 0
                    and level > playerLevel + 10
                    and not TinyThreatPlusDB.showSkullEnemyLevels
                )

            if isSkullLevel then
                badge.text:Hide()
                badge.skull:Show()
            else
                local red, green, blue = GetDifficultyColor(level)
                badge.skull:Hide()
                badge.text:SetFont(
                    STANDARD_TEXT_FONT,
                    9,
                    ""
                )
                badge.text:ClearAllPoints()
                badge.text:SetPoint(
                    "CENTER",
                    badge,
                    "CENTER",
                    level < 10 and -0.25 or -0.5,
                    0.5
                )
                badge.text:SetJustifyH("CENTER")
                badge.text:SetJustifyV("MIDDLE")
                badge.text:SetText(tostring(level))
                badge.text:SetTextColor(red, green, blue)
                badge.text:Show()
            end
            badge:Show()
        else
            HideLevelBadge(nameplate)
            PositionInfoWithoutLevel(nameplate, healthBar)
        end
    else
        HideLevelBadge(nameplate)
        PositionInfoWithoutLevel(nameplate, healthBar)
    end

    -- Forever cast presentation is a sibling system, not part of the health
    -- bar. Move the exposed Blizzard cast bar itself in this live layout pass.
    local castContainer = unitFrame.CastBarsContainer
    local castBar = castContainer and (castContainer.castBar or castContainer.CastBar)
        or unitFrame.castBar
        or unitFrame.CastBar

    if castBar then
        castBar:ClearAllPoints()
        PixelSetPoint(castBar, "TOP", healthBar, "BOTTOM", 0, -3)
        local castHeight = math.max(9, math.floor(nativeRowHeight * 0.55 + 0.5))
        PixelSetSize(castBar, healthBar:GetWidth(), castHeight)

        local castShell = castBar.TinyThreatPlusForeverShell
        if not castShell then
            castShell = CreateFrame("Frame", nil, castBar)
            castShell:SetAllPoints(castBar)
            castShell:SetFrameLevel((castBar:GetFrameLevel() or 1) + 3)
            castBar.TinyThreatPlusForeverShell = castShell
        end
        TTP.ApplyForeverRoundedChrome(
            castShell,
            0, 0, 0, 0,
            0.30, 0.28, 0.24, 0.95
        )
        castShell:Show()
    elseif castContainer then
        castContainer:ClearAllPoints()
        PixelSetPoint(castContainer, "TOP", healthBar, "BOTTOM", 0, -2)
    end

    -- Classic-style health readout: current value left, percentage right.
    -- Forever exposes these FontStrings under different keys between builds,
    -- so resolve the known native fields without creating duplicate text.
    local healthValueText =
        healthBar.healthValue
        or healthBar.HealthValue
        or healthBar.healthText
        or healthBar.HealthText
        or healthBar.LeftText
        or healthBar.leftText
    local healthPercentText =
        healthBar.healthPercent
        or healthBar.HealthPercent
        or healthBar.healthPercentage
        or healthBar.HealthPercentage
        or healthBar.RightText
        or healthBar.rightText

    -- Eight-pixel Friz glyphs rasterize poorly on Forever's thin rows.
    -- Keep the readout at a crisp 9px for thin bars and allow 10px on tall.
    local healthFontSize = nativeRowHeight <= 12 and 9 or 10

    -- Match Forever's player/target unit-frame convention:
    -- percentage on the left, current health value on the right.
    -- Live Forever exposes these native fields with counterintuitive names:
    -- healthValue renders the percentage and healthPercent renders the value.
    if healthValueText and healthValueText.ClearAllPoints then
        healthValueText:ClearAllPoints()
        PixelSetPoint(healthValueText, "LEFT", healthBar, "LEFT", 4, 0)
        if healthValueText.SetJustifyH then
            healthValueText:SetJustifyH("LEFT")
        end
        if healthValueText.SetFont then
            healthValueText:SetFont(STANDARD_TEXT_FONT, healthFontSize, "OUTLINE")
        end
    end
    if healthPercentText and healthPercentText.ClearAllPoints then
        healthPercentText:ClearAllPoints()
        PixelSetPoint(healthPercentText, "RIGHT", healthBar, "RIGHT", -4, 0)
        if healthPercentText.SetJustifyH then
            healthPercentText:SetJustifyH("RIGHT")
        end
        if healthPercentText.SetFont then
            healthPercentText:SetFont(STANDARD_TEXT_FONT, healthFontSize, "OUTLINE")
        end
    end

    local nameText = GetNativeNameFontString(nameplate, healthBar)
    if nameText then
        nameText:ClearAllPoints()
        nameText:SetJustifyH("LEFT")
        PixelSetPoint(nameText, "BOTTOMLEFT", healthBar, "TOPLEFT", 0, 2)
        nameText:SetWidth(healthBar:GetWidth())
    end

    return true
end

local function UpdateLevelAndClassification(nameplate, healthBar, unit)
    -- Forever's native inline level badge does not fit TinyThreatPlus's
    -- presentation. Hide Blizzard's LevelFrame for hostile NPCs; a future
    -- pass will replace it with a TinyThreatPlus level treatment matching the
    -- target-frame artwork. Leave non-hostile plates alone.
    if TTP.Compat.IsForever() then
        -- Native presentation mode deliberately leaves Blizzard's nameplate
        -- geometry and artwork untouched. TinyThreatPlus can still append its
        -- threat indicator/counter/leader elsewhere in the update pass. This
        -- also gives /ttp art a pristine Blizzard frame to inspect.
        if TinyThreatPlusDB.nameplatePresentation == "BLIZZARD" then
            RestoreForeverNativePresentation(nameplate, healthBar)
            return
        end

        UpdateClassificationFrame(nameplate, healthBar, unit)
        ApplyForeverCustomLayout(nameplate, healthBar, unit)
        return
    end

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
-- Forever hover art diagnostic
-- ---------------------------------------------------------------------------
local function SafeObjectName(object)
    if not object or not object.GetName then return "<unnamed>" end
    local ok, value = pcall(object.GetName, object)
    return ok and value or "<protected>"
end

local function PrintArtRegion(region, prefix)
    if not region or not region.GetObjectType then return end
    local kind = region:GetObjectType()
    if kind ~= "Texture" and kind ~= "MaskTexture" then return end

    local atlas
    if region.GetAtlas then
        local ok, value = pcall(region.GetAtlas, region)
        if ok then atlas = value end
    end

    local texture
    if region.GetTexture then
        local ok, value = pcall(region.GetTexture, region)
        if ok then texture = value end
    end

    local layer, sublevel
    if region.GetDrawLayer then
        local ok, a, b = pcall(region.GetDrawLayer, region)
        if ok then layer, sublevel = a, b end
    end

    local width = region.GetWidth and region:GetWidth() or 0
    local height = region.GetHeight and region:GetHeight() or 0
    print(string.format(
        "%s%s name=%s size=%.1fx%.1f atlas=%s texture=%s layer=%s:%s",
        prefix or "",
        kind,
        tostring(SafeObjectName(region)),
        width or 0,
        height or 0,
        tostring(atlas),
        tostring(texture),
        tostring(layer),
        tostring(sublevel)
    ))

    if region.GetTexCoord then
        local ok, l, r, t, b = pcall(region.GetTexCoord, region)
        if ok and l then
            print(string.format(
                "%s  texcoord=%.4f,%.4f,%.4f,%.4f",
                prefix or "", l, r, t, b
            ))
        end
    end
end

local function DumpArtObject(object, depth, seen)
    if not object or seen[object] or depth > 3 then return end
    seen[object] = true

    local kind = object.GetObjectType and object:GetObjectType() or "?"
    local width = object.GetWidth and object:GetWidth() or 0
    local height = object.GetHeight and object:GetHeight() or 0
    local prefix = string.rep("  ", depth)
    print(string.format(
        "%s[%s] %s size=%.1fx%.1f",
        prefix, kind, tostring(SafeObjectName(object)), width or 0, height or 0
    ))

    if kind == "Texture" or kind == "MaskTexture" then
        PrintArtRegion(object, prefix .. "  ")
    end

    if object.GetRegions then
        local regions = { object:GetRegions() }
        for _, region in ipairs(regions) do
            PrintArtRegion(region, prefix .. "  ")
        end
    end

    if object.GetChildren then
        local children = { object:GetChildren() }
        for _, child in ipairs(children) do
            DumpArtObject(child, depth + 1, seen)
        end
    end
end

function TTP.DumpHoveredArt()
    if not TTP.Compat.IsForever() then
        print("TinyThreatPlus art diagnostic is intended for WoW Forever.")
        return
    end

    local function DumpCandidate(label, object)
        if not object then return false end
        print(label .. ": " .. tostring(SafeObjectName(object)))
        DumpArtObject(object, 0, {})
        return true
    end

    -- World nameplates are not normal mouse-interactive UI, so GetMouseFoci()
    -- commonly returns an anonymous 0x0 world-cursor proxy. When the player
    -- has a target, inspect the target's actual Blizzard nameplate directly.
    local targetPlate =
        C_NamePlate
        and C_NamePlate.GetNamePlateForUnit
        and C_NamePlate.GetNamePlateForUnit("target")

    if targetPlate then
        if TinyThreatPlusDB.nameplatePresentation ~= "BLIZZARD" then
            print("TinyThreatPlus art diagnostic: switch Nameplate Presentation to Blizzard + TTP Additions, then /reload before sampling native art.")
            return
        end

        local targetHealthBar = TTP.GetNameplateHealthBar(targetPlate)
        if targetHealthBar
            and (
                (targetHealthBar.TinyThreatPlusForeverShell and targetHealthBar.TinyThreatPlusForeverShell:IsShown())
                or (targetHealthBar.TinyThreatPlusForeverBorder and targetHealthBar.TinyThreatPlusForeverBorder:IsShown())
                or (targetHealthBar.TinyThreatPlusTargetHighlight and targetHealthBar.TinyThreatPlusTargetHighlight:IsShown())
            )
        then
            print("TinyThreatPlus art diagnostic: this nameplate still contains visible custom TTP presentation from before the mode switch. /reload once, then run /ttp art again.")
            return
        end

        print("TinyThreatPlus Forever art diagnostic: PRISTINE TARGET NAMEPLATE")
        DumpCandidate("NamePlate", targetPlate)

        local unitFrame = targetPlate.UnitFrame
        if unitFrame then
            DumpCandidate("UnitFrame", unitFrame)

            local container = unitFrame.HealthBarsContainer
            if container then
                DumpCandidate("HealthBarsContainer", container)
                DumpCandidate(
                    "HealthBar",
                    container.healthBar
                        or unitFrame.healthBar
                        or unitFrame.HealthBar
                )
            else
                DumpCandidate(
                    "HealthBar",
                    unitFrame.healthBar or unitFrame.HealthBar
                )
            end

            DumpCandidate("LevelFrame", unitFrame.LevelFrame)
            DumpCandidate("ClassificationFrame", unitFrame.ClassificationFrame)
            DumpCandidate("RaidTargetFrame", unitFrame.RaidTargetFrame)
        end
        return
    end

    -- Normal UI frames (player/target frame, options, etc.) can still be
    -- inspected by hover. Walk upward through several parents because the
    -- visible border texture is often owned above the mouse-enabled child.
    local foci = type(GetMouseFoci) == "function" and { GetMouseFoci() } or {}
    if #foci == 0 and type(GetMouseFocus) == "function" then
        local focus = GetMouseFocus()
        if focus then foci[1] = focus end
    end

    if #foci == 0 then
        print("TinyThreatPlus art diagnostic: no target nameplate or mouse focus.")
        return
    end

    print("TinyThreatPlus Forever art diagnostic: HOVERED UI")
    for index, focus in ipairs(foci) do
        local object = focus
        local seenParents = {}
        for depth = 0, 6 do
            if not object or seenParents[object] then break end
            seenParents[object] = true
            print(string.format(
                "Focus %d parent-depth %d: %s",
                index,
                depth,
                tostring(SafeObjectName(object))
            ))
            DumpArtObject(object, 0, {})
            object = object.GetParent and object:GetParent() or nil
        end
    end
end

-- ---------------------------------------------------------------------------
-- Forever player/target-frame art diagnostic
-- ---------------------------------------------------------------------------
function TTP.DumpForeverUnitFrameArt()
    if not TTP.Compat.IsForever() then
        print("TinyThreatPlus unit-frame art diagnostic is Forever-only.")
        return
    end

    print("TinyThreatPlus Forever art diagnostic: PLAYER / TARGET UNIT FRAMES")

    local candidates = {
        { "PlayerFrame", _G.PlayerFrame },
        { "TargetFrame", _G.TargetFrame },
        { "PlayerFrame.PlayerFrameContent", _G.PlayerFrame and _G.PlayerFrame.PlayerFrameContent },
        { "TargetFrame.TargetFrameContent", _G.TargetFrame and _G.TargetFrame.TargetFrameContent },
    }

    for _, candidate in ipairs(candidates) do
        local label, object = candidate[1], candidate[2]
        if object then
            print("=== " .. label .. " ===")
            DumpArtObject(object, 0, {})
        end
    end

    print("Tip: look for bronze portrait/level-ring atlas names in this output.")
end

-- ---------------------------------------------------------------------------
-- Forever native level diagnostic
-- ---------------------------------------------------------------------------
local function DescribeRegion(region)
    if not region then return "nil" end

    local name = region.GetName and region:GetName() or nil
    local objectType = region.GetObjectType and region:GetObjectType() or "?"
    local shown = region.IsShown and region:IsShown() or false
    local width = region.GetWidth and region:GetWidth() or 0
    local height = region.GetHeight and region:GetHeight() or 0

    local extra = ""
    if objectType == "FontString" and region.GetText then
        extra = " text=" .. tostring(region:GetText())
    elseif objectType == "Texture" then
        local atlas = region.GetAtlas and region:GetAtlas() or nil
        local texture = region.GetTexture and region:GetTexture() or nil
        extra = " atlas=" .. tostring(atlas) .. " texture=" .. tostring(texture)
    end

    return string.format(
        "%s name=%s shown=%s size=%.1fx%.1f%s",
        tostring(objectType),
        tostring(name),
        tostring(shown),
        tonumber(width) or 0,
        tonumber(height) or 0,
        extra
    )
end

function TTP.DumpForeverNameplateLevel(unit)
    if not TTP.Compat.IsForever() then
        print("TinyThreatPlus: Forever level diagnostic is Forever-only.")
        return
    end

    unit = unit or "target"
    local nameplate = C_NamePlate and C_NamePlate.GetNamePlateForUnit
        and C_NamePlate.GetNamePlateForUnit(unit)

    if not nameplate then
        print("TinyThreatPlus: no visible nameplate for " .. tostring(unit) .. ".")
        return
    end

    local unitFrame = nameplate.UnitFrame
    print("TinyThreatPlus Forever level diagnostic: " .. tostring(UnitName(unit) or unit))
    print(" nameplate: " .. DescribeRegion(nameplate))
    print(" UnitFrame: " .. DescribeRegion(unitFrame))

    if not unitFrame then return end

    local candidates = {
        "LevelFrame", "levelFrame", "Level", "level", "LevelText", "levelText",
        "ClassificationFrame", "HealthBarsContainer", "healthBar", "HealthBar",
    }

    for _, key in ipairs(candidates) do
        local value = unitFrame[key]
        if value then
            print(" UnitFrame." .. key .. ": " .. DescribeRegion(value))
        end
    end

    if unitFrame.GetRegions then
        local regions = { unitFrame:GetRegions() }
        for index, region in ipairs(regions) do
            local text = region.GetText and region:GetText() or nil
            if text == tostring(UnitLevel(unit)) then
                print(" MATCH UnitFrame region[" .. index .. "]: " .. DescribeRegion(region))
            end
        end
    end

    local targetLevel = tostring(UnitLevel(unit))

    local function ScanFrame(frame, path, depth)
        if not frame or depth > 5 then return end

        if frame.GetRegions then
            local regions = { frame:GetRegions() }
            for regionIndex, region in ipairs(regions) do
                local text = region.GetText and region:GetText() or nil
                if text == targetLevel then
                    print(" MATCH " .. path .. " region[" .. regionIndex .. "]: " .. DescribeRegion(region))
                end
            end
        end

        if frame.GetChildren then
            local children = { frame:GetChildren() }
            for index, child in ipairs(children) do
                ScanFrame(child, path .. ".child[" .. index .. "]", depth + 1)
            end
        end
    end

    -- The visible Forever level is not a direct UnitFrame region: LevelFrame
    -- is already hidden while the number remains visible. Recursively scan
    -- both the Blizzard UnitFrame and the whole nameplate tree.
    ScanFrame(unitFrame, "UnitFrame", 0)
    ScanFrame(nameplate, "NamePlate", 0)

    -- If no text region matches, dump all direct UnitFrame fields that are
    -- frames/regions. Forever's level may be rendered by a mixin-owned field
    -- that is not part of the normal child/region traversal.
    print(" TinyThreatPlus: UnitFrame object fields:")
    for key, value in pairs(unitFrame) do
        local valueType = type(value)
        if valueType == "table" or valueType == "userdata" then
            local okType, objectType = pcall(function()
                return value.GetObjectType and value:GetObjectType()
            end)
            if okType and objectType then
                print("  [" .. tostring(key) .. "] " .. DescribeRegion(value))
            end
        end
    end

    -- Also report the health bar's anchor and right edge. The visible level
    -- appears immediately after it even though LevelFrame itself is hidden.
    if healthBar then
        local left = healthBar.GetLeft and healthBar:GetLeft() or nil
        local right = healthBar.GetRight and healthBar:GetRight() or nil
        print(" healthBar edges: left=" .. tostring(left) .. " right=" .. tostring(right))
    end
end

SLASH_TINYTHREATPLUSLEVELDIAG1 = "/ttplevel"
SlashCmdList.TINYTHREATPLUSLEVELDIAG = function()
    TTP.DumpForeverNameplateLevel("target")
end

-- ---------------------------------------------------------------------------
-- Threat-box and Blizzard side-aura layout
-- ---------------------------------------------------------------------------
local function AnchorThreatBox(nameplate, healthBar, box)
    box:ClearAllPoints()

    -- Forever's LevelFrame is visually inline but its frame bounds are not a
    -- reliable external anchor; in live plates they can overlap the health
    -- bar. Anchor from the health bar's right edge instead. The threat box
    -- then becomes the first addon-owned element after Blizzard's native row.
    if TTP.Compat.IsForever() then
        PixelSetPoint(box, "LEFT", healthBar, "RIGHT", 1, 0)
        return
    end

    PixelSetPoint(box, "LEFT", healthBar, "RIGHT", 1, 0)
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
    if TTP.Compat.IsForever() then
        RestoreSideAuraLayout(nameplate)
        return
    end

    local unitFrame = nameplate and nameplate.UnitFrame
    local aurasFrame = unitFrame and unitFrame.AurasFrame

    if not aurasFrame then
        return
    end

    local crowdControlFrame = aurasFrame.CrowdControlListFrame
    local lossOfControlFrame = aurasFrame.LossOfControlFrame

    local anchor

    -- Anchor Blizzard's Shared CC / Loss-of-Control icons after the
    -- right-most TinyThreatPlus element that is actually visible.
    --
    -- Threat Box + Counter:
    --   Health Bar > Threat Box > Target Counter > Shared CC
    --
    -- Threat Box only:
    --   Health Bar > Threat Box > Shared CC
    --
    -- Neither:
    --   Restore Blizzard's native positioning.
    if box and box:IsShown() then
        local counter =
            box.counter

        if counter
            and counter:IsShown()
            and TinyThreatPlusDB.showTargetCounter
        then
            anchor = counter
        else
            anchor = box
        end
    end

    if not anchor then
        RestoreSideAuraLayout(nameplate)
        return
    end

    -- Keep Blizzard's original small visual gap after whichever element is
    -- right-most. No fixed counter-width approximation is needed.
    if crowdControlFrame then
        crowdControlFrame:ClearAllPoints()
        PixelSetPoint(
            crowdControlFrame,
            "LEFT",
            anchor,
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
            anchor,
            "RIGHT",
            5,
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
    if not box or not box.counterRing then
        return
    end

    local _, _, classificationScale =
        GetNameplateVisualScales()

    local userScale =
        (TinyThreatPlusDB.nameplateThreatScale or 100) / 100

    local scale = classificationScale * userScale
    if TTP.Compat.IsForever() then
        scale = scale * 0.78
    end

    box.counterRing:SetScale(scale)

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
    local fontSize = (TTP.Compat.IsForever() and 9 or 10) * textScale

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

    if TTP.Compat.IsForever() then
        -- The Forever custom layout owns a stable health-bar container.
        -- Keep priority emphasis tight to that bar instead of using the old
        -- Anniversary padding, which collides with our name and cast rows.
        marker:SetPoint("TOPLEFT", healthBar, "TOPLEFT", -2, 2)
        marker:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 2, -2)
    else
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
    end

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

    if TTP.Compat.IsForever() then
        TTP.ApplyForeverRoundedChrome(
            marker,
            color[1], color[2], color[3], opacity,
            TTP.colors.border[1],
            TTP.colors.border[2],
            TTP.colors.border[3],
            TTP.colors.border[4] or 1
        )
    end
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
    nameplate.TinyThreatPlusForeverHostile = nil
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


-- Focused Forever nameplate-art diagnostic. Unlike /ttp unitart, this only
-- inspects the live Blizzard nameplate and its health-bar container so short
-- and tall style assets can be compared without flooding chat.
local function PlateArtDescribeRegion(region, indent)
    if not region then return end
    indent = indent or "  "

    local objectType = region.GetObjectType and region:GetObjectType() or "Region"
    local width = region.GetWidth and region:GetWidth() or 0
    local height = region.GetHeight and region:GetHeight() or 0
    local layer, sublevel
    if region.GetDrawLayer then
        layer, sublevel = region:GetDrawLayer()
    end

    local atlas = region.GetAtlas and region:GetAtlas() or nil
    local texture = region.GetTexture and region:GetTexture() or nil
    local effectiveScale = region.GetEffectiveScale and region:GetEffectiveScale() or nil

    print(string.format(
        "%s%s size=%.1fx%.1f atlas=%s texture=%s layer=%s:%s scale=%s",
        indent,
        tostring(objectType),
        tonumber(width) or 0,
        tonumber(height) or 0,
        tostring(atlas),
        tostring(texture),
        tostring(layer),
        tostring(sublevel),
        effectiveScale and string.format("%.3f", effectiveScale) or "nil"
    ))
end

local function PlateArtDumpFrame(label, frame)
    if not frame then
        print(label .. ": <nil>")
        return
    end

    local width = frame.GetWidth and frame:GetWidth() or 0
    local height = frame.GetHeight and frame:GetHeight() or 0
    local scale = frame.GetScale and frame:GetScale() or nil
    local effectiveScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or nil

    print(string.format(
        "%s size=%.1fx%.1f scale=%s effective=%s",
        label,
        tonumber(width) or 0,
        tonumber(height) or 0,
        scale and string.format("%.3f", scale) or "nil",
        effectiveScale and string.format("%.3f", effectiveScale) or "nil"
    ))

    if frame.GetRegions then
        local regions = { frame:GetRegions() }
        for _, region in ipairs(regions) do
            PlateArtDescribeRegion(region, "  ")
        end
    end
end

function TTP.DumpForeverNameplateArt(unit)
    if not TTP.Compat.IsForever() then
        print("TinyThreatPlus /ttp plateart is Forever-only.")
        return
    end

    unit = unit or "target"
    if not UnitExists(unit) then
        print("TinyThreatPlus /ttp plateart: target a unit with a visible Blizzard nameplate.")
        return
    end

    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate then
        print("TinyThreatPlus /ttp plateart: no live nameplate found for target.")
        return
    end

    local unitFrame = nameplate.UnitFrame
    local container = unitFrame and unitFrame.HealthBarsContainer
    local healthBar = TTP.GetNameplateHealthBar(nameplate)

    print("=== TinyThreatPlus Forever nameplate health art ===")
    print("Style CVar:", tostring(GetNameplateStyleValue()), "Size CVar:", tostring(GetNameplateSizeSetting()))
    PlateArtDumpFrame("NamePlate", nameplate)
    PlateArtDumpFrame("UnitFrame", unitFrame)
    PlateArtDumpFrame("HealthBarsContainer", container)
    PlateArtDumpFrame("HealthBar", healthBar)

    -- These are the direct children most likely to own border/background art.
    if container and container.GetChildren then
        local children = { container:GetChildren() }
        for index, child in ipairs(children) do
            PlateArtDumpFrame("HealthBarsContainer child " .. index, child)
        end
    end

    if healthBar and healthBar.GetChildren then
        local children = { healthBar:GetChildren() }
        for index, child in ipairs(children) do
            PlateArtDumpFrame("HealthBar child " .. index, child)
        end
    end

    print("=== end /ttp plateart ===")
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
    local boxWidth = profile.width * horizontalScale * userScale
    local boxFontSize = profile.fontSize * verticalScale * userScale

    if TTP.Compat.IsForever() then
        -- The health StatusBar is the trustworthy geometry source on Forever.
        -- Its live height distinguishes the short Default/Cast Focus family
        -- from the taller Large/Block family. LevelFrame bounds are not used
        -- because Blizzard's inline level artwork can extend outside them.
        local nativeHeight = healthBar:GetHeight()

        if nativeHeight and nativeHeight > 0 then
            boxHeight = nativeHeight
            boxFontSize =
                math.max(8, math.min(11, nativeHeight * 0.52))
        end

        -- Compact Forever threat cell: same height as health, just wide
        -- enough for signed deltas without becoming a second health bar.
        boxWidth = 28 * userScale
    end

    box:SetScale(1)

    -- Keep addon-owned threat information above Blizzard's selected-nameplate
    -- presentation. The native selected shell grows beyond the health row and
    -- otherwise occludes the threat cell even though its anchor is correct.
    if TTP.Compat.IsForever() and box.SetFrameLevel then
        local unitFrame = nameplate and nameplate.UnitFrame
        local healthLevel = healthBar.GetFrameLevel and healthBar:GetFrameLevel() or 1
        local unitLevel = unitFrame and unitFrame.GetFrameLevel and unitFrame:GetFrameLevel() or 1
        box:SetFrameLevel(math.max(healthLevel, unitLevel) + 8)
    end

    AnchorThreatBox(nameplate, healthBar, box)

    -- On Forever, the Threat Box is part of the same horizontal row as the
    -- health bar and level badge. Keep its outer height exactly equal to the
    -- live health bar; the user's threat scale changes width/text, not height.
    local renderedBoxHeight = boxHeight * userScale
    if TTP.Compat.IsForever() then
        renderedBoxHeight = healthBar:GetHeight()
    end

    TTP.UpdateThreatBox(
        box,
        boxWidth,
        renderedBoxHeight,
        boxFontSize,
        text,
        red,
        green,
        blue,
        TTP.GetTargetCounter(unit)
    )

    if box.counterRing then
        box.counterRing:ClearAllPoints()
        box.counterRing:SetPoint("CENTER", box, "RIGHT", 4, 0)
    end

    ApplyTargetCounterScale(box)

    -- Forever now has a sanitized numeric threat path too, so active threat
    -- should receive the same full-opacity treatment as other clients.
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
