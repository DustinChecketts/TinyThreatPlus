local ADDON_NAME, addonTable = ...

local TTP = _G.TinyThreatPlus or addonTable or {}
_G.TinyThreatPlus = TTP
TinyThreatPlusDB = TinyThreatPlusDB or {}

-- ---------------------------------------------------------------------------
-- Defaults and persistent settings
-- ---------------------------------------------------------------------------
TTP.defaults = {
    showNameplates = true,
    showTargetFrame = true,
    alwaysShowThreatBoxes = true,
    roleBasedColors = true,
    showTargetCounter = true,

    showPriorityMarker = true,
    priorityWhileSolo = false,
    priorityThreatThreshold = 80,
    priorityMarkerColor = { 0, 0.0627451, 0.3960784 },
    priorityMarkerOpacity = 100,
    priorityMarkerSizeRating = 3,

    showThreatLeader = true,
    showThreatLeaderClassIcon = true,
    showThreatLeaderRole = true,

    showMobLevel = true,
    showFriendlyLevel = true,

    enemyPlayerClassColors = true,
    friendlyPlayerClassColors = false,

    displayMode = "VALUE",

    nameplateThreatScale = 100,
    targetThreatScale = 100,
}

TTP.colors = {
    good = { 0.10, 0.85, 0.10 },
    warn = { 1.00, 0.82, 0.00 },
    bad = { 1.00, 0.10, 0.10 },
    background = { 0.02, 0.02, 0.02, 0.86 },
    border = { 0.72, 0.72, 0.72, 1.00 },
    levelBorder = { 0.86, 0.86, 0.89, 1.00 },
    levelBorderInactive = { 0.26, 0.26, 0.29, 1.00 },
    levelBevelDark = { 0.12, 0.12, 0.14, 1.00 },
    modernLevelFill = { 0.05, 0.05, 0.06, 0.96 },
    gold = { 0.92, 0.72, 0.18, 0.95 },
}

TTP.activeNameplates = TTP.activeNameplates or {}
TTP.applyingHealthColor = false

-- ---------------------------------------------------------------------------
-- Saved-variable migrations and defaults
-- ---------------------------------------------------------------------------
function TTP.ApplyDefaults()
    TinyThreatPlusDB = TinyThreatPlusDB or {}

    if TinyThreatPlusDB.priorityMarkerSizeRating == nil
        and TinyThreatPlusDB.priorityMarkerSize ~= nil
    then
        local oldPixels =
            tonumber(TinyThreatPlusDB.priorityMarkerSize) or 5

        oldPixels =
            math.max(
                5,
                math.min(10, oldPixels)
            )

        TinyThreatPlusDB.priorityMarkerSizeRating =
            math.max(
                1,
                math.min(
                    6,
                    math.floor(oldPixels - 4)
                )
            )
    end

    if TinyThreatPlusDB.priorityThreatThreshold == nil
        and TinyThreatPlusDB.threatSafetyBuffer ~= nil
    then
        TinyThreatPlusDB.priorityThreatThreshold =
            math.max(
                0,
                math.min(
                    100,
                    100 - TinyThreatPlusDB.threatSafetyBuffer
                )
            )
    end

    if TinyThreatPlusDB.showPriorityMarker == nil
        and TinyThreatPlusDB.highlightWeakestThreatLead ~= nil
    then
        TinyThreatPlusDB.showPriorityMarker =
            TinyThreatPlusDB.highlightWeakestThreatLead
    end

    if TinyThreatPlusDB.showThreatLeader == nil
        and TinyThreatPlusDB.showTargetOfTarget ~= nil
    then
        TinyThreatPlusDB.showThreatLeader =
            TinyThreatPlusDB.showTargetOfTarget
    end

    if TinyThreatPlusDB.showThreatLeaderClassIcon == nil
        and TinyThreatPlusDB.showToTClassIcon ~= nil
    then
        TinyThreatPlusDB.showThreatLeaderClassIcon =
            TinyThreatPlusDB.showToTClassIcon
    end

    if TinyThreatPlusDB.showThreatLeaderRole == nil
        and TinyThreatPlusDB.showToTRole ~= nil
    then
        TinyThreatPlusDB.showThreatLeaderRole =
            TinyThreatPlusDB.showToTRole
    end

    for key, value in pairs(TTP.defaults) do
        if TinyThreatPlusDB[key] == nil then
            if type(value) == "table" then
                TinyThreatPlusDB[key] = {}
                for index, item in pairs(value) do
                    TinyThreatPlusDB[key][index] = item
                end
            else
                TinyThreatPlusDB[key] = value
            end
        end
    end
end

TinyThreatPlus_ApplyDefaults = TTP.ApplyDefaults
TinyThreatPlusDefaults = TTP.defaults

function TTP.GetCVar(name)
    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar(name)
    end

    if GetCVar then
        return GetCVar(name)
    end
end

local function SetBooleanCVar(name, enabled)
    local value = enabled and "1" or "0"

    if TTP.GetCVar(name) == value then
        return
    end

    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar(name, value)
    elseif SetCVar then
        SetCVar(name, value)
    end
end

function TTP.ApplyClassColorSettings()
    TTP.ApplyDefaults()

    SetBooleanCVar(
        "nameplateShowClassColor",
        TinyThreatPlusDB.enemyPlayerClassColors
    )

    SetBooleanCVar(
        "nameplateShowFriendlyClassColor",
        TinyThreatPlusDB.friendlyPlayerClassColors
    )
end

TinyThreatPlus_ApplyClassColorSettings = TTP.ApplyClassColorSettings

function TTP.ResetDefaults()
    TinyThreatPlusDB = {}

    for key, value in pairs(TTP.defaults) do
        if type(value) == "table" then
            TinyThreatPlusDB[key] = {}

            for index, item in pairs(value) do
                TinyThreatPlusDB[key][index] = item
            end
        else
            TinyThreatPlusDB[key] = value
        end
    end

    TTP.ApplyClassColorSettings()
    TTP.UpdateAll()
end

TinyThreatPlus_ResetDefaults = TTP.ResetDefaults

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

function TTP.FormatThreatValue(value)
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

function TTP.GetGroupUnits()
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

function TTP.GetThreatUnits()
    local units = { "player" }

    -- Treat the player's active pet as an independent threat source.
    -- This covers Hunter/Warlock pets and other classes whose summon is
    -- exposed through the standard "pet" unit token.
    if UnitExists("pet") then
        units[#units + 1] = "pet"
    end

    if IsInRaid() then
        for index = 1, 40 do
            local playerUnit = "raid" .. index
            local petUnit = "raidpet" .. index

            if UnitExists(playerUnit)
                and not UnitIsUnit(playerUnit, "player")
            then
                units[#units + 1] = playerUnit
            end

            if UnitExists(petUnit) then
                units[#units + 1] = petUnit
            end
        end
    elseif IsInGroup() then
        for index = 1, 4 do
            local playerUnit = "party" .. index
            local petUnit = "partypet" .. index

            if UnitExists(playerUnit) then
                units[#units + 1] = playerUnit
            end

            if UnitExists(petUnit) then
                units[#units + 1] = petUnit
            end
        end
    end

    return units
end

local function GetPetOwnerUnit(unit)
    if unit == "pet" then
        return "player"
    end

    local raidIndex = string.match(unit or "", "^raidpet(%d+)$")
    if raidIndex then
        return "raid" .. raidIndex
    end

    local partyIndex = string.match(unit or "", "^partypet(%d+)$")
    if partyIndex then
        return "party" .. partyIndex
    end

    return nil
end

TTP.damageFallback = TTP.damageFallback or {}
TTP.affiliatedGUIDs = TTP.affiliatedGUIDs or {}

local function RefreshAffiliatedGUIDs()
    wipe(TTP.affiliatedGUIDs)
    for _, unit in ipairs(TTP.GetThreatUnits()) do
        local guid = UnitGUID(unit)
        if guid then TTP.affiliatedGUIDs[guid] = unit end
    end
end

local function FindThreatUnitByGUID(guid)
    if not guid then return nil end
    local cached = TTP.affiliatedGUIDs[guid]
    if cached and UnitExists(cached) and UnitGUID(cached) == guid then return cached end
    for _, unit in ipairs(TTP.GetThreatUnits()) do
        if UnitGUID(unit) == guid then return unit end
    end
    return nil
end

local function GetDamageFallback(destGUID)
    local targetData = destGUID and TTP.damageFallback[destGUID]

    if not targetData then
        return nil
    end

    local bestGUID
    local bestName
    local bestAmount = 0
    local playerAmount = 0
    local playerGUID = UnitGUID("player")

    for sourceGUID, sourceData in pairs(targetData) do
        if sourceGUID == playerGUID then
            playerAmount = sourceData.amount or 0
        end

        if (sourceData.amount or 0) > bestAmount then
            bestGUID = sourceGUID
            bestAmount = sourceData.amount or 0
            bestName = sourceData.name
        end
    end

    if not bestGUID or bestAmount <= 0 then
        return nil
    end

    return bestAmount,
        FindThreatUnitByGUID(bestGUID),
        bestName,
        playerAmount
end

local function RecordDamageEvent()
    local info = { CombatLogGetCurrentEventInfo() }
    local subevent, sourceGUID, sourceName, destGUID = info[2], info[4], info[5], info[8]
    if subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" then
        if destGUID then TTP.damageFallback[destGUID] = nil end
        return
    end
    if not sourceGUID or not destGUID or not TTP.affiliatedGUIDs[sourceGUID] then return end
    local amount
    if subevent == "SWING_DAMAGE" then amount = info[12]
    elseif subevent == "ENVIRONMENTAL_DAMAGE" then amount = info[13]
    elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE"
        or subevent == "RANGE_DAMAGE" or subevent == "DAMAGE_SHIELD"
        or subevent == "DAMAGE_SPLIT" then amount = info[15] end
    if not amount or amount <= 0 then return end
    local targetData = TTP.damageFallback[destGUID]
    if not targetData then targetData = {}; TTP.damageFallback[destGUID] = targetData end
    local sourceData = targetData[sourceGUID]
    if not sourceData then sourceData = { amount = 0, name = sourceName }; targetData[sourceGUID] = sourceData end
    sourceData.amount = sourceData.amount + amount
    sourceData.name = sourceName or sourceData.name
end

-- ---------------------------------------------------------------------------
-- Threat collection and fallback data
-- ---------------------------------------------------------------------------
function TTP.GetThreatData(unit)
    if not unit or not UnitExists(unit) or UnitIsDead(unit) or UnitIsPlayer(unit)
        or not UnitCanAttack("player", unit) then return nil end
    TTP.threatCache = TTP.threatCache or {}
    if TTP.threatCache[unit] then return TTP.threatCache[unit] end
    local data = { unit=unit, playerThreat=0, highestOtherThreat=0, highestOtherUnit=nil,
        highestOtherOwner=nil, playerStatus=nil, playerIsTanking=false, aggroUnit=nil,
        leaderUnit=nil, leaderThreat=0, leaderName=nil, hasThreatData=false,
        isDamageFallback=false, fallbackDamage=0, fallbackPlayerDamage=0 }
    local playerIsTanking, playerStatus, _, _, playerThreat = UnitDetailedThreatSituation("player", unit)
    if playerThreat ~= nil then
        data.hasThreatData=true; data.playerThreat=playerThreat; data.leaderUnit="player";
        data.leaderThreat=playerThreat; data.leaderName=UnitName("player")
    end
    data.playerStatus=playerStatus; data.playerIsTanking=playerIsTanking==true
    if data.playerIsTanking then data.aggroUnit="player" end
    for _, threatUnit in ipairs(TTP.GetThreatUnits()) do
        if not UnitIsUnit(threatUnit,"player") then
            local isTanking,_,_,_,threat=UnitDetailedThreatSituation(threatUnit,unit)
            if threat ~= nil then
                data.hasThreatData=true
                if threat > data.highestOtherThreat then
                    data.highestOtherThreat=threat; data.highestOtherUnit=threatUnit;
                    data.highestOtherOwner=GetPetOwnerUnit(threatUnit)
                end
                if threat > data.leaderThreat then
                    data.leaderThreat=threat; data.leaderUnit=threatUnit; data.leaderName=UnitName(threatUnit)
                end
            end
            if isTanking==true then data.aggroUnit=threatUnit end
        end
    end
    if not data.aggroUnit then
        if data.playerThreat > data.highestOtherThreat and data.playerThreat > 0 then data.aggroUnit="player"
        elseif data.highestOtherUnit then data.aggroUnit=data.highestOtherUnit end
    end
    data.lead=(data.playerThreat-data.highestOtherThreat)/100
    if data.highestOtherThreat>0 then
        if data.playerThreat>=data.highestOtherThreat then data.percent=(data.playerThreat/data.highestOtherThreat)*100
        else data.percent=((data.playerThreat-data.highestOtherThreat)/data.highestOtherThreat)*100 end
    elseif data.playerThreat>0 then data.percent=100 else data.percent=0 end
    if not data.hasThreatData then
        local amount, sourceUnit, sourceName, playerAmount =
            GetDamageFallback(UnitGUID(unit))

        if amount then
            data.isDamageFallback = true
            data.fallbackDamage = amount
            data.fallbackPlayerDamage = playerAmount or 0
            data.leaderUnit = sourceUnit
            data.leaderName =
                (sourceUnit and UnitName(sourceUnit))
                or sourceName
        elseif not TinyThreatPlusDB.alwaysShowThreatBoxes then return nil end
    end
    TTP.threatCache[unit]=data
    return data
end

function TTP.GetGroupTargetCount(unit)
    if not IsInGroup() and not IsInRaid() then
        return 0
    end

    local targetGUID = UnitGUID(unit)

    if not targetGUID then
        return 0
    end

    local count = 0

    for _, groupUnit in ipairs(TTP.GetGroupUnits()) do
        local targetUnit = groupUnit .. "target"

        if UnitExists(targetUnit)
            and UnitGUID(targetUnit) == targetGUID
        then
            count = count + 1
        end
    end

    return count
end

function TTP.GetTargetCounter(unit)
    if not TinyThreatPlusDB.showTargetCounter then
        return nil
    end

    local count = TTP.GetGroupTargetCount(unit)
    return count > 0 and count or nil
end

function TTP.IsUnitTank(unit)
    if not unit or not UnitExists(unit) then
        return false
    end

    if UnitGroupRolesAssigned
        and UnitGroupRolesAssigned(unit) == "TANK"
    then
        return true
    end

    if GetPartyAssignment
        and GetPartyAssignment("MAINTANK", unit)
    then
        return true
    end

    return false
end

function TTP.PlayerIsTank()
    return TTP.IsUnitTank("player")
end

function TTP.GetUnitRole(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return nil end
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
    if role and role ~= "NONE" then return role end
    if TTP.IsUnitTank(unit) then return "TANK" end
    return nil
end

function TTP.IsOwnPetUnit(unit)
    return unit
        and UnitExists(unit)
        and (
            unit == "pet"
            or (
                GetPetOwnerUnit(unit)
                and UnitIsUnit(GetPetOwnerUnit(unit), "player")
            )
        )
        or false
end

function TTP.IsThreatSourceTank(unit)
    if not unit or not UnitExists(unit) then return false end
    if TTP.IsUnitTank(unit) then return true end
    local owner = GetPetOwnerUnit(unit)
    return owner and not UnitIsUnit(owner,"player") and TTP.IsUnitTank(owner) or false
end

function TTP.GetThreatDisplayText(data)
    if not data then return "", nil end
    if data.isDamageFallback then return Abbreviate(data.fallbackDamage), true end
    return TTP.FormatThreatValue(TTP.GetDisplayValue(data.lead,data.percent)), false
end

function TTP.GetThreatColor(unit, data)
    -- The Anniversary client can expose a visible nameplate and combat-log
    -- damage before UnitDetailedThreatSituation starts returning threat.
    -- In that window, use our damage fallback only when it gives us a
    -- meaningful ownership signal.
    if data and data.isDamageFallback then
        if data.leaderUnit and TTP.IsOwnPetUnit(data.leaderUnit) then
            local petDamage = data.fallbackDamage or 0
            local playerDamage = data.fallbackPlayerDamage or 0

            if petDamage > 0 then
                local ratio = playerDamage / petDamage

                if ratio >= 0.90 then
                    return unpack(TTP.colors.warn)
                end
            end

            return unpack(TTP.colors.good)
        end

        if data.leaderUnit
            and UnitExists(data.leaderUnit)
            and UnitIsUnit(data.leaderUnit, "player")
        then
            return unpack(TTP.colors.bad)
        end
    end

    local status = data and data.playerStatus
        or UnitThreatSituation("player", unit)

    if TTP.PlayerIsTank() then
        if data and data.playerIsTanking then
            return unpack(TTP.colors.good)
        end

        if data
            and data.aggroUnit
            and TTP.IsThreatSourceTank(data.aggroUnit)
        then
            return unpack(TTP.colors.good)
        end

        if status == 1 or status == 2 then
            return unpack(TTP.colors.warn)
        end

        return unpack(TTP.colors.bad)
    end

    -- DPS/healer logic for pet classes:
    -- your own pet holding aggro is a safe state, not danger.
    if data and data.aggroUnit and TTP.IsOwnPetUnit(data.aggroUnit) then
        if status == 1
            or status == 2
            or TTP.GetPetThreatWarning(unit, data)
        then
            return unpack(TTP.colors.warn)
        end

        return unpack(TTP.colors.good)
    end

    -- If the player is currently tanking the mob, this is danger for DPS.
    if data and data.playerIsTanking then
        return unpack(TTP.colors.bad)
    end

    if status == 3 and data and data.lead >= 0 then
        return unpack(TTP.colors.bad)
    elseif status == 1 or status == 2 then
        return unpack(TTP.colors.warn)
    end

    return unpack(TTP.colors.good)
end

function TTP.GetPetThreatWarning(unit, data)
    if not data
        or not data.aggroUnit
        or not TTP.IsOwnPetUnit(data.aggroUnit)
        or not data.highestOtherThreat
        or data.highestOtherThreat <= 0
    then
        return false
    end

    local ratio = (data.playerThreat or 0) / data.highestOtherThreat

    -- Treat ~90%+ of the pet's threat as a caution zone.
    return ratio >= 0.90 and ratio < 1.00
end

function TTP.GetDisplayValue(lead, percent)
    if TinyThreatPlusDB.displayMode == "PERCENT" then
        return percent or 0
    end

    return lead or 0
end

function TTP.IsHostileNPC(unit)
    return unit
        and UnitExists(unit)
        and not UnitIsPlayer(unit)
        and UnitCanAttack("player", unit)
        and not UnitIsFriend("player", unit)
end

-- ---------------------------------------------------------------------------
-- Shared threat-box presentation
-- ---------------------------------------------------------------------------
function TTP.ApplyBoxStyle(frame, height)
    -- Use the heavier border treatment that previously looked best on the
    -- large nameplate family, and apply it consistently to both large and
    -- thin threat-box profiles.
    local edgeSize = 10
    local inset = 2
    local styleKey = "fixed:10:2"

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

    frame:SetBackdropColor(unpack(TTP.colors.background))
    frame:SetBackdropBorderColor(unpack(TTP.colors.border))
end

function TTP.CreateThreatBox(parent, key, globalName)
    if key and parent[key] then
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
    box.counterText:SetTextColor(1, 1, 1)
    box.counterText:Hide()

    box:Hide()

    if key then
        parent[key] = box
    end

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

function TTP.UpdateThreatBox(
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
    TTP.ApplyBoxStyle(box, height)
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

local function GetTargetNameAnchor()
    return TargetFrameTextureFrameName
        or (TargetFrame and TargetFrame.name)
        or TargetFrameName
        or TargetFrame
end

function TTP.GetTargetBox()
    if TTP.targetBox then
        return TTP.targetBox
    end

    local parent = TargetFrameTextureFrame or TargetFrame or UIParent

    TTP.targetBox =
        TTP.CreateThreatBox(
            parent,
            nil,
            "TinyThreatPlusTargetBox"
        )

    return TTP.targetBox
end

function TTP.UpdateTargetFrame()
    local box = TTP.GetTargetBox()

    if not TinyThreatPlusDB.showTargetFrame
        or not UnitExists("target")
    then
        box:Hide()
        return
    end

    local data = TTP.GetThreatData("target")

    if not data then
        box:Hide()
        return
    end

    local anchor = GetTargetNameAnchor()

    if not anchor then
        box:Hide()
        return
    end

    local red, green, blue = TTP.GetThreatColor("target", data)
    local text, isFallback = TTP.GetThreatDisplayText(data)
    if isFallback then red, green, blue = 1, 1, 1 end

    box:SetScale((TinyThreatPlusDB.targetThreatScale or 100) / 100)

    box:ClearAllPoints()
    box:SetPoint(
        "BOTTOM",
        anchor,
        "TOP",
        0,
        2
    )

    TTP.UpdateThreatBox(
        box,
        52,
        20,
        12,
        text,
        red,
        green,
        blue,
        TTP.GetTargetCounter("target")
    )
end

-- ---------------------------------------------------------------------------
-- Target Priority
-- ---------------------------------------------------------------------------
function TTP.GetPriorityRole()
    if TTP.PlayerIsTank() then
        return "TANK"
    end

    local role = TTP.GetUnitRole("player")

    if role == "HEALER" then
        return "HEALER"
    end

    return "DAMAGE"
end

local function FindVisibleUnitByGUID(guid)
    if not guid then
        return nil
    end

    for unit in pairs(TTP.activeNameplates) do
        if UnitExists(unit) and UnitGUID(unit) == guid then
            return unit
        end
    end

    return nil
end

function TTP.StartPriorityTest()
    if not UnitExists("target")
        or not TTP.IsHostileNPC("target")
    then
        print(
            "TinyThreatPlus: target a hostile NPC before using /ttp testpriority."
        )
        return
    end

    TTP.priorityTestGUID = UnitGUID("target")
    TTP.priorityTestUntil = GetTime() + 10

    print(
        "TinyThreatPlus: forcing Priority Marker on current target for 10 seconds."
    )

    TTP.UpdateAll()

    if C_Timer and C_Timer.After then
        C_Timer.After(10, function()
            if TTP.priorityTestUntil
                and GetTime() >= TTP.priorityTestUntil
            then
                TTP.priorityTestGUID = nil
                TTP.priorityTestUntil = nil
                TTP.UpdateAll()
            end
        end)
    end
end

function TTP.PrintPriorityDebug()
    local role = TTP.GetPriorityRole()

    if role == "HEALER" then
        print(
            "TinyThreatPlus Priority: disabled for Healer role."
        )
        return
    end

    local unit = TTP.priorityUnit

    if not unit or not UnitExists(unit) then
        print("TinyThreatPlus Priority: no target currently needs priority.")
        return
    end

    local data = TTP.GetThreatData(unit)
    local name = UnitName(unit) or unit
    local maxHealth = UnitHealthMax(unit) or 0
    local healthPercent =
        maxHealth > 0
        and math.floor((UnitHealth(unit) / maxHealth) * 100 + 0.5)
        or 0

    print("TinyThreatPlus Priority:")
    print(" Target:", name)
    print(" Role:", role)
    print(" Health:", healthPercent .. "%")

    if TTP.priorityReason then
        print(" Reason:", TTP.priorityReason)
    end

    if TTP.priorityDataSource then
        print(" Data:", TTP.priorityDataSource)
    end

    if role == "DAMAGE" and (IsInGroup() or IsInRaid()) then
        print(
            " Group Target Count:",
            TTP.GetGroupTargetCount(unit)
        )
    end

    if data then
        if role == "TANK" then
            print(
                " Threat Lead:",
                TTP.FormatThreatValue(data.lead or 0)
            )
        else
            print(
                " Threat:",
                math.floor((data.percent or 0) + 0.5) .. "%"
            )
            print(
                " Threat Threshold:",
                tostring(
                    tonumber(
                        TinyThreatPlusDB.priorityThreatThreshold
                    ) or 80
                ) .. "%"
            )
        end
    end
end

-- ---------------------------------------------------------------------------
-- Global refresh
-- ---------------------------------------------------------------------------
function TTP.UpdateAll()
    TTP.ApplyDefaults()
    RefreshAffiliatedGUIDs()
    TTP.threatCache={}
    TTP.priorityUnit = nil
    TTP.priorityReason = nil
    TTP.priorityDataSource = nil

    local priorityRole = TTP.GetPriorityRole()
    local visibleHostiles = 0

    for unit in pairs(TTP.activeNameplates) do
        if UnitExists(unit)
            and TTP.IsHostileNPC(unit)
        then
            visibleHostiles = visibleHostiles + 1
        end
    end

    local inGroup =
        IsInGroup()
        or IsInRaid()

    local soloPriorityAllowed =
        TinyThreatPlusDB.priorityWhileSolo == true
        and UnitExists("pet")

    if TinyThreatPlusDB.showPriorityMarker
        and priorityRole ~= "HEALER"
        and visibleHostiles > 1
        and (
            inGroup
            or soloPriorityAllowed
        )
    then
        local threshold =
            tonumber(
                TinyThreatPlusDB.priorityThreatThreshold
            ) or 80

        threshold =
            math.max(
                0,
                math.min(100, threshold)
            )

        if priorityRole == "TANK" then
            local highestRiskRatio = nil

            for unit in pairs(TTP.activeNameplates) do
                if UnitExists(unit)
                    and TTP.IsHostileNPC(unit)
                then
                    local data = TTP.GetThreatData(unit)

                    if data and data.hasThreatData then
                        local otherTank =
                            data.aggroUnit
                            and not UnitIsUnit(
                                data.aggroUnit,
                                "player"
                            )
                            and TTP.IsThreatSourceTank(
                                data.aggroUnit
                            )

                        if not otherTank then
                            local risky = false
                            local riskRatio = 0
                            local reason

                            if not data.playerIsTanking then
                                risky = true
                                riskRatio = 101
                                reason =
                                    "Aggro lost or not secured"
                            elseif (data.playerThreat or 0) > 0
                                and (data.highestOtherThreat or 0) > 0
                            then
                                riskRatio =
                                    (
                                        data.highestOtherThreat
                                        / data.playerThreat
                                    ) * 100

                                if riskRatio >= threshold then
                                    risky = true
                                    reason =
                                        string.format(
                                            "Competitor at %.0f%% of your threat",
                                            riskRatio
                                        )
                                end
                            end

                            if risky
                                and (
                                    highestRiskRatio == nil
                                    or riskRatio > highestRiskRatio
                                )
                            then
                                highestRiskRatio = riskRatio
                                TTP.priorityUnit = unit
                                TTP.priorityReason = reason
                            end
                        end
                    end
                end
            end
        else
            local bestTargetCount = nil
            local bestHealthPercent = nil
            local bestThreatRatio = nil

            for unit in pairs(TTP.activeNameplates) do
                if UnitExists(unit)
                    and TTP.IsHostileNPC(unit)
                then
                    local data = TTP.GetThreatData(unit)

                    if data then
                        local threatRatio
                        local eligible = false
                        local source = "UNKNOWN"

                        if data.hasThreatData
                            and not data.playerIsTanking
                            and (data.highestOtherThreat or 0) > 0
                        then
                            threatRatio =
                                (
                                    (data.playerThreat or 0)
                                    / data.highestOtherThreat
                                ) * 100

                            eligible =
                                threatRatio <= threshold

                            source = "REAL"
                        elseif not inGroup
                            and soloPriorityAllowed
                            and data.isDamageFallback
                            and (data.fallbackDamage or 0) > 0
                        then
                            -- Solo pet classes can optionally use combat-log
                            -- fallback while Blizzard has not exposed a real
                            -- threat table. Empty/unknown data is NOT treated
                            -- as zero threat.
                            threatRatio =
                                (
                                    (data.fallbackPlayerDamage or 0)
                                    / data.fallbackDamage
                                ) * 100

                            eligible =
                                threatRatio <= threshold

                            source = "FALLBACK"
                        end

                        if eligible then
                            local maxHealth =
                                UnitHealthMax(unit) or 0

                            local healthPercent =
                                maxHealth > 0
                                and UnitHealth(unit) / maxHealth
                                or 1

                            local targetCount =
                                inGroup
                                and TTP.GetGroupTargetCount(unit)
                                or 0

                            local better = false

                            if bestTargetCount == nil
                                or targetCount > bestTargetCount
                            then
                                better = true
                            elseif targetCount == bestTargetCount then
                                if bestHealthPercent == nil
                                    or healthPercent < bestHealthPercent
                                then
                                    better = true
                                elseif math.abs(
                                    healthPercent - bestHealthPercent
                                ) < 0.001
                                    and (
                                        bestThreatRatio == nil
                                        or threatRatio < bestThreatRatio
                                    )
                                then
                                    better = true
                                end
                            end

                            if better then
                                bestTargetCount = targetCount
                                bestHealthPercent = healthPercent
                                bestThreatRatio = threatRatio
                                TTP.priorityUnit = unit

                                if inGroup then
                                    TTP.priorityReason =
                                        string.format(
                                            "Group focus: %d targeting, %.0f%% health, %.0f%% threat",
                                            targetCount,
                                            healthPercent * 100,
                                            threatRatio
                                        )
                                else
                                    TTP.priorityReason =
                                        string.format(
                                            "Solo pet fallback: %.0f%% player damage ratio",
                                            threatRatio
                                        )
                                end

                                TTP.priorityDataSource = source
                            end
                        end
                    end
                end
            end
        end
    end

    local testActive =
        TTP.priorityTestGUID
        and TTP.priorityTestUntil
        and GetTime() < TTP.priorityTestUntil

    if testActive then
        local testUnit =
            FindVisibleUnitByGUID(TTP.priorityTestGUID)

        if testUnit then
            TTP.priorityUnit = testUnit
            TTP.priorityReason = "Forced visual test"
            TTP.priorityTestActive = true
        else
            TTP.priorityTestActive = false
        end
    else
        TTP.priorityTestActive = false
        TTP.priorityTestGUID = nil
        TTP.priorityTestUntil = nil
    end

    for unit in pairs(TTP.activeNameplates) do
        if UnitExists(unit) then if TTP.UpdateNameplate then TTP.UpdateNameplate(unit) end
        else TTP.activeNameplates[unit]=nil end
    end
    TTP.UpdateTargetFrame()
end

TinyThreatPlus_UpdateAll = TTP.UpdateAll

local eventFrame = CreateFrame("Frame")
local updateElapsed = 0

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then
            return
        end

        TTP.ApplyDefaults()
        TTP.ApplyClassColorSettings()
        TTP.UpdateAll()
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        RecordDamageEvent()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        wipe(TTP.damageFallback)
    end

    if event == "NAME_PLATE_UNIT_ADDED" then
        TTP.activeNameplates[arg1] = true

        if TTP.UpdateNameplate then
            TTP.UpdateNameplate(arg1)
        end

        return
    end

    if event == "NAME_PLATE_UNIT_REMOVED" then
        local nameplate = C_NamePlate.GetNamePlateForUnit(arg1)

        TTP.activeNameplates[arg1] = nil

        if TTP.ClearNameplate then
            TTP.ClearNameplate(nameplate)
        end

        return
    end

    TTP.UpdateAll()
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
    updateElapsed = updateElapsed + elapsed

    if updateElapsed < 0.08 then
        return
    end

    updateElapsed = 0
    TTP.UpdateAll()
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
eventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
eventFrame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
eventFrame:RegisterEvent("RAID_TARGET_UPDATE")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

SLASH_TINYTHREATPLUS1 = "/ttp"
SLASH_TINYTHREATPLUS2 = "/tpp"
SLASH_TINYTHREATPLUS3 = "/tinythreatplus"

SlashCmdList.TINYTHREATPLUS = function(message)
    local command = string.lower(message or "")

    if command == "colors" then
        TinyThreatPlusDB.roleBasedColors =
            not TinyThreatPlusDB.roleBasedColors

        print(
            "TinyThreatPlus role-based colors:",
            TinyThreatPlusDB.roleBasedColors and "on" or "off"
        )
    elseif command == "enemyclass" then
        TinyThreatPlusDB.enemyPlayerClassColors =
            not TinyThreatPlusDB.enemyPlayerClassColors

        TTP.ApplyClassColorSettings()

        print(
            "TinyThreatPlus enemy player class colors:",
            TinyThreatPlusDB.enemyPlayerClassColors and "on" or "off"
        )
    elseif command == "friendlyclass" then
        TinyThreatPlusDB.friendlyPlayerClassColors =
            not TinyThreatPlusDB.friendlyPlayerClassColors

        TTP.ApplyClassColorSettings()

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
    elseif command == "priority" then
        TinyThreatPlusDB.showPriorityMarker =
            not TinyThreatPlusDB.showPriorityMarker
        print("TinyThreatPlus priority marker:", TinyThreatPlusDB.showPriorityMarker and "on" or "off")
    elseif command == "testpriority" then
        TTP.StartPriorityTest()
        return
    elseif command == "prioritydebug" then
        TTP.PrintPriorityDebug()
        return
    elseif command == "reset" then
        TTP.ResetDefaults()
        print("TinyThreatPlus settings reset.")
        return
    else
        print("TinyThreatPlus commands:")
        print("/ttp colors")
        print("/ttp enemyclass")
        print("/ttp friendlyclass")
        print("/ttp levels")
        print("/ttp friendlylevels")
        print("/ttp counter")
        print("/ttp preview")
        print("/ttp priority")
        print("/ttp testpriority")
        print("/ttp prioritydebug")
        print("/ttp reset")
    end

    TTP.UpdateAll()
end
