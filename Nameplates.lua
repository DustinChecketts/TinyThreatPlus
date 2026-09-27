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
        -- Forever CVar order: Default=0, Large=1, Block=2, Cast Focus=3.
        -- Default/Cast Focus use the short health row; Large/Block use tall.
        if style == 1 or style == 2 then
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
            [1] = 11,
            [2] = 12,
            [3] = 13,
            [4] = 14,
            [5] = 16,
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
    local sizeSetting = GetNameplateSizeSetting()
    local size = ({ 19, 20, 21, 23, 25 })[sizeSetting] or 20
    local bevelSize = size - 2
    local innerSize = size - 4

    PixelSetSize(badge, size, size)
    if badge.modernBevel then PixelSetSize(badge.modernBevel, bevelSize, bevelSize) end
    if badge.modernInner then PixelSetSize(badge.modernInner, innerSize, innerSize) end
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
    local baseWidth = 172

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
        statusTexture:SetAlpha(1)
    end
    healthBar:SetAlpha(1)

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
    if healthBar.TinyThreatPlusForeverBorder then healthBar.TinyThreatPlusForeverBorder:Hide() end
    if healthBar.TinyThreatPlusTargetHighlight then
        healthBar.TinyThreatPlusTargetHighlight:Hide()
        SetRoundedChromeShown(healthBar.TinyThreatPlusTargetHighlight, false)
    end
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

    -- Optional target highlight. Reuse Blizzard's confirmed Forever targeted
    -- nameplate atlas instead of drawing addon-owned border lines.
    local targetHighlight = healthBar.TinyThreatPlusTargetHighlight
    if not targetHighlight then
        targetHighlight = healthBar:CreateTexture(nil, "OVERLAY", nil, 1)
        targetHighlight:SetAtlas("UI-HUD-Nameplates-TargetedByEnemy", false)
        targetHighlight:SetIgnoreParentAlpha(true)
        healthBar.TinyThreatPlusTargetHighlight = targetHighlight
    end
    targetHighlight:ClearAllPoints()
    targetHighlight:SetPoint("CENTER", healthShell, "CENTER", 0, 0)
    PixelSetSize(targetHighlight, healthShell:GetWidth(), healthShell:GetHeight())
    if TinyThreatPlusDB.showTargetHighlight and UnitIsUnit(unit, "target") then
        targetHighlight:Show()
    else
        targetHighlight:Hide()
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

            -- Use the same HD circular frame Blizzard uses on Forever's
            -- player/target unit frames. Hide the old hand-built bronze rings;
            -- retain only a dark masked center behind the level numeral.
            badge.foreverCircle:Show()
            badge.foreverCircle:SetVertexColor(1, 1, 1, 1)
            if badge.modernOuter then badge.modernOuter:Hide() end
            if badge.modernBevel then badge.modernBevel:Hide() end
            if badge.modernInner then badge.modernInner:Hide() end
            if badge.fill then badge.fill:Hide() end

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

        -- Keep the mob name aligned to the health bar's left edge, but make
        -- it slightly less dominant than Blizzard's stock world-name size.
        -- Cache Blizzard's original font metrics once so repeated update
        -- passes never progressively shrink the text.
        if not nameText.TinyThreatPlusOriginalFontSize and nameText.GetFont then
            local fontFile, fontSize, fontFlags = nameText:GetFont()
            nameText.TinyThreatPlusOriginalFontFile = fontFile
            nameText.TinyThreatPlusOriginalFontSize = fontSize
            nameText.TinyThreatPlusOriginalFontFlags = fontFlags
        end
        local originalSize = nameText.TinyThreatPlusOriginalFontSize
        if originalSize and nameText.SetFont then
            nameText:SetFont(
                nameText.TinyThreatPlusOriginalFontFile or STANDARD_TEXT_FONT,
                math.max(9, originalSize - 4),
                nameText.TinyThreatPlusOriginalFontFlags or "OUTLINE"
            )
        end
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
-- Runtime nameplate lifecycle -------------------------------------------------
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
