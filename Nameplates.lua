local TTP = _G.TinyThreatPlus or select(2, ...)
if not TTP then return end

-- Nameplate presentation only.
-- Threat collection and shared threat-box behavior live in TinyThreatPlus.lua.
-- Forever keeps Blizzard's live nameplate/StatusBar and replaces only the
-- visible arrangement with positively identified Blizzard UI assets.

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

function TTP.GetNameplateHealthBar(nameplate)
    local unitFrame = nameplate and nameplate.UnitFrame
    if not unitFrame then return nil end

    local container = unitFrame.HealthBarsContainer
    if container and container.healthBar then
        return container.healthBar
    end

    return unitFrame.healthBar or unitFrame.HealthBar
end

local function IsAccessible(value)
    return value ~= nil
        and not TTP.Compat.IsSecretValue(value)
        and TTP.Compat.CanAccessValue(value)
end

local function GetCustomProfile()
    -- Custom geometry is intentionally independent of Blizzard's Nameplates
    -- Style and Size settings. Blizzard still owns plate discovery/visibility.
    local scale = math.max(0.75, math.min(1.50,
        (tonumber(TinyThreatPlusDB.customNameplateScale) or 100) / 100))
    local height = math.max(12, math.min(32,
        tonumber(TinyThreatPlusDB.customNameplateBarHeight) or 20))

    return 172 * scale, height * scale, scale
end

local function HideRegion(region)
    if region and region.SetAlpha then region:SetAlpha(0) end
end

local function ShowRegion(region)
    if region and region.SetAlpha then region:SetAlpha(1) end
end

local function GetNameText(nameplate, healthBar)
    local unitFrame = nameplate and nameplate.UnitFrame
    return (unitFrame and unitFrame.name)
        or (healthBar and healthBar.unitNameFontString)
end

local function RestoreForeverNative(nameplate, healthBar)
    local unitFrame = nameplate and nameplate.UnitFrame
    if not unitFrame or not healthBar then return end

    local shell = healthBar.TinyThreatPlusForeverShell
    if shell then shell:Hide() end
    local highlight = healthBar.TinyThreatPlusTargetHighlight
    if highlight then highlight:Hide() end

    ShowRegion(healthBar.bgTexture)
    ShowRegion(healthBar.selectedBorder)
    ShowRegion(healthBar.SelectedBorder)
    ShowRegion(healthBar.deselectedOverlay)
    ShowRegion(healthBar.DeselectedOverlay)
    ShowRegion(unitFrame.selectionHighlight)
    ShowRegion(unitFrame.SelectionHighlight)
    ShowRegion(unitFrame.LevelFrame)
    ShowRegion(unitFrame.PlayerLevelDifferentialFrame)
    ShowRegion(unitFrame.PlayerLevelDiffFrame)
end

local function GetForeverShell(healthBar)
    local shell = healthBar.TinyThreatPlusForeverShell
    if shell then return shell end

    -- Crucially, the native Bar-BG is behind the StatusBar fill. The previous
    -- renderer put this atlas above the fill and darkened the health color.
    shell = CreateFrame("Frame", nil, healthBar:GetParent())
    shell:SetFrameStrata(healthBar:GetFrameStrata())
    shell:SetFrameLevel(math.max(0, (healthBar:GetFrameLevel() or 1) - 1))

    shell.art = shell:CreateTexture(nil, "BACKGROUND")
    shell.art:SetAllPoints()
    shell.art:SetAtlas("UI-HUD-CoolDownManager-Bar-BG", false)
    shell.art:SetIgnoreParentAlpha(true)

    healthBar.TinyThreatPlusForeverShell = shell
    return shell
end

local function ApplyForeverHealthRow(nameplate, healthBar)
    local unitFrame = nameplate.UnitFrame
    local container = unitFrame.HealthBarsContainer
    if not container then return false end

    local width, height = GetCustomProfile()

    container:SetScale(1)
    container:ClearAllPoints()
    PixelSize(container, width, height)
    PixelPoint(container, "BOTTOM", unitFrame, "BOTTOM", 0, 4)

    healthBar:ClearAllPoints()
    healthBar:SetAllPoints(container)
    healthBar:SetAlpha(1)

    local fill = healthBar:GetStatusBarTexture()
    if fill and fill.SetAtlas then
        fill:SetAtlas("UI-HUD-CoolDownManager-Bar", false)
        fill:SetTexCoord(0, 1, 0, 1)
        fill:SetAlpha(1)
    end

    -- Hide Blizzard presentation layers that no longer match our geometry.
    HideRegion(healthBar.bgTexture)
    HideRegion(healthBar.selectedBorder)
    HideRegion(healthBar.SelectedBorder)
    HideRegion(healthBar.deselectedOverlay)
    HideRegion(healthBar.DeselectedOverlay)
    HideRegion(unitFrame.selectionHighlight)
    HideRegion(unitFrame.SelectionHighlight)
    HideRegion(unitFrame.LevelFrame)
    HideRegion(unitFrame.PlayerLevelDifferentialFrame)
    HideRegion(unitFrame.PlayerLevelDiffFrame)

    local shell = GetForeverShell(healthBar)
    shell:ClearAllPoints()
    shell:SetPoint("CENTER", healthBar, "CENTER", 1, -1)
    PixelSize(shell, healthBar:GetWidth() + 8, healthBar:GetHeight() + 9)
    shell:Show()

    local highlight = healthBar.TinyThreatPlusTargetHighlight
    if not highlight then
        highlight = healthBar:CreateTexture(nil, "OVERLAY")
        highlight:SetAtlas("UI-HUD-CoolDownManager-Selected-yellow", false)
        highlight:SetIgnoreParentAlpha(true)
        healthBar.TinyThreatPlusTargetHighlight = highlight
    end
    highlight:ClearAllPoints()
    highlight:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
    PixelSize(highlight, healthBar:GetWidth() + 11, healthBar:GetHeight() + 9)
    if TinyThreatPlusDB.showTargetHighlight and UnitIsUnit(healthBar.TinyThreatPlusUnit, "target") then
        highlight:Show()
    else
        highlight:Hide()
    end

    return true
end

local function GetLevelBadge(nameplate)
    local badge = nameplate.TinyThreatPlusLevel
    if badge then return badge end

    badge = CreateFrame("Frame", nil, nameplate)
    badge:SetFrameStrata("HIGH")

    badge.art = badge:CreateTexture(nil, "ARTWORK")
    badge.art:SetAllPoints()
    badge.art:SetAtlas("UI-HUD-UnitFrame-SmallCircle", false)
    badge.art:SetIgnoreParentAlpha(true)

    badge.text = badge:CreateFontString(nil, "OVERLAY", "GameNormalNumberFont")
    badge.text:SetAllPoints()
    badge.text:SetJustifyH("CENTER")
    badge.text:SetJustifyV("MIDDLE")

    nameplate.TinyThreatPlusLevel = badge
    return badge
end

local function UpdateForeverLevel(nameplate, healthBar, unit)
    local badge = nameplate.TinyThreatPlusLevel

    if not TinyThreatPlusDB.showMobLevel then
        if badge then badge:Hide() end
        return
    end

    local level = UnitLevel(unit)
    if not IsAccessible(level) or type(level) ~= "number" or level == 0 then
        if badge then badge:Hide() end
        return
    end

    badge = GetLevelBadge(nameplate)
    local size = 21
    PixelSize(badge, size, size)
    badge:ClearAllPoints()
    PixelPoint(badge, "CENTER", healthBar, "TOPLEFT", -4, 0)

    badge.text:SetFont(STANDARD_TEXT_FONT, 8, "")
    badge.text:SetText(level < 0 and "??" or tostring(level))
    badge.text:SetTextColor(1, 1, 1)
    badge:Show()
end

local function UpdateForeverText(nameplate, healthBar)
    local name = GetNameText(nameplate, healthBar)
    if name then
        name:ClearAllPoints()
        PixelPoint(name, "BOTTOMLEFT", healthBar, "TOPLEFT", 0, 2)
        name:SetWidth(healthBar:GetWidth())
        name:SetJustifyH("LEFT")
        if not name.TinyThreatPlusOriginalFontSize and name.GetFont then
            local file, size, flags = name:GetFont()
            name.TinyThreatPlusOriginalFontFile = file
            name.TinyThreatPlusOriginalFontSize = size
            name.TinyThreatPlusOriginalFontFlags = flags
        end
        if name.TinyThreatPlusOriginalFontSize then
            name:SetFont(
                name.TinyThreatPlusOriginalFontFile or STANDARD_TEXT_FONT,
                math.max(9, name.TinyThreatPlusOriginalFontSize - 4),
                name.TinyThreatPlusOriginalFontFlags or "OUTLINE"
            )
        end
    end

    -- Forever's native fields are counterintuitively named: LeftText is the
    -- percentage readout and RightText is the current value in the live UI.
    local left = healthBar.LeftText
    local right = healthBar.RightText
    -- Use discrete typography for the two native bar families. Scaling the
    -- same font with the bar made the thin styles feel crowded and uneven.
    local thin = healthBar:GetHeight() < 17
    local fontSize = thin and 8 or 10

    if left then
        left:ClearAllPoints()
        PixelPoint(left, "LEFT", healthBar, "LEFT", thin and 3 or 4, 0)
        left:SetJustifyH("LEFT")
        left:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    end
    if right then
        right:ClearAllPoints()
        PixelPoint(right, "RIGHT", healthBar, "RIGHT", thin and -3 or -4, 0)
        right:SetJustifyH("RIGHT")
        right:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    end
end

local function UpdateForeverCastBar(nameplate, healthBar)
    local unitFrame = nameplate.UnitFrame
    local container = unitFrame.CastBarsContainer
    local castBar = container and (container.castBar or container.CastBar)
        or unitFrame.castBar
        or unitFrame.CastBar

    if not castBar then return end

    castBar:ClearAllPoints()
    PixelPoint(castBar, "TOP", healthBar, "BOTTOM", 0, -3)
    PixelSize(castBar, healthBar:GetWidth(), math.max(9, healthBar:GetHeight() * 0.55))
end

local function ApplyForeverPresentation(nameplate, healthBar, unit)
    healthBar.TinyThreatPlusUnit = unit
    if not ApplyForeverHealthRow(nameplate, healthBar) then return false end
    UpdateForeverLevel(nameplate, healthBar, unit)
    UpdateForeverText(nameplate, healthBar)
    UpdateForeverCastBar(nameplate, healthBar)
    return true
end

local function AnchorThreatBox(healthBar, box)
    box:ClearAllPoints()
    if TTP.Compat.IsForever() then
        PixelPoint(box, "LEFT", healthBar, "RIGHT", 3, 0)
    else
        PixelPoint(box, "LEFT", healthBar, "RIGHT", 2, 0)
    end
end

local function RestoreHealthColor(healthBar)
    if not healthBar or not healthBar.SetStatusBarColor then return end
    -- Ask Blizzard to refresh naturally on the next nameplate update. Avoid
    -- caching protected color/health state in the presentation layer.
    healthBar.TinyThreatPlusUnit = nil
end

local function ApplyThreatColor(healthBar, unit, data)
    if not TinyThreatPlusDB.roleBasedColors then return end
    local r, g, b = TTP.GetThreatColor(unit, data)
    TTP.applyingHealthColor = true
    healthBar:SetStatusBarColor(r, g, b)
    TTP.applyingHealthColor = false
end

local function GetOrCreateThreatBox(nameplate)
    return TTP.CreateThreatBox(nameplate, "TinyThreatPlusBox")
end

local function HideAddonPresentation(nameplate)
    if nameplate.TinyThreatPlusBox then nameplate.TinyThreatPlusBox:Hide() end
    if nameplate.TinyThreatPlusLevel then nameplate.TinyThreatPlusLevel:Hide() end
    local healthBar = TTP.GetNameplateHealthBar(nameplate)
    if healthBar and healthBar.TinyThreatPlusTargetHighlight then
        healthBar.TinyThreatPlusTargetHighlight:Hide()
    end
end

function TTP.ClearNameplate(nameplate)
    if not nameplate then return end
    local healthBar = nameplate.TinyThreatPlusHealthBar or TTP.GetNameplateHealthBar(nameplate)

    HideAddonPresentation(nameplate)

    if TTP.Compat.IsForever() and healthBar then
        RestoreForeverNative(nameplate, healthBar)
    end

    if healthBar then RestoreHealthColor(healthBar) end
    nameplate.TinyThreatPlusHealthBar = nil
end

function TTP.UpdateNameplate(unit)
    if not TTP.Compat.HasNamePlateAPI() then return end

    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate or nameplate:IsForbidden() then return end

    local healthBar = TTP.GetNameplateHealthBar(nameplate)
    if not healthBar then
        TTP.ClearNameplate(nameplate)
        return
    end

    nameplate.TinyThreatPlusHealthBar = healthBar

    if not TTP.IsHostileNPC(unit) then
        HideAddonPresentation(nameplate)
        RestoreHealthColor(healthBar)
        return
    end

    if TTP.Compat.IsForever() then
        if not TinyThreatPlusDB.enableCustomNameplates then
            HideAddonPresentation(nameplate)
            RestoreForeverNative(nameplate, healthBar)
            RestoreHealthColor(healthBar)
            return
        end

        ApplyForeverPresentation(nameplate, healthBar, unit)
    end

    if not TinyThreatPlusDB.showNameplateThreat then
        if nameplate.TinyThreatPlusBox then nameplate.TinyThreatPlusBox:Hide() end
        RestoreHealthColor(healthBar)
        return
    end

    local data = TTP.GetThreatData(unit)
    if not data then
        if nameplate.TinyThreatPlusBox then nameplate.TinyThreatPlusBox:Hide() end
        RestoreHealthColor(healthBar)
        return
    end

    local box = GetOrCreateThreatBox(nameplate)
    AnchorThreatBox(healthBar, box)

    local height = TTP.Compat.IsForever() and healthBar:GetHeight() or 18
    local width = TTP.Compat.IsForever() and 28 or 42
    local fontSize = TTP.Compat.IsForever() and 8 or 10
    local text = TTP.GetThreatDisplayText(data)
    local r, g, b = TTP.GetThreatColor(unit, data)

    TTP.UpdateThreatBox(
        box,
        width,
        height,
        fontSize,
        text,
        r, g, b,
        TTP.GetTargetCounter(unit)
    )

    local active = data.hasThreatData
        and ((data.playerThreat or 0) > 0 or (data.highestOtherThreat or 0) > 0)
    box:SetAlpha((UnitIsUnit(unit, "target") or active) and 1 or 0.58)

    if TinyThreatPlusDB.roleBasedColors and active then
        ApplyThreatColor(healthBar, unit, data)
    end
end
