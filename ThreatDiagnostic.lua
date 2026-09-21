-- TinyThreatPlus threat diagnostics
-- Temporary-but-safe diagnostic tooling for mapping WoW Forever's threat API.
-- It never compares or performs arithmetic on secret values.

local ADDON_NAME, addonTable = ...
local TTP = _G.TinyThreatPlus or addonTable or {}
_G.TinyThreatPlus = TTP

TTP.ThreatDiagnostic = TTP.ThreatDiagnostic or {}
local D = TTP.ThreatDiagnostic

D.enabled = false
D.samples = {}
D.eventCounts = {}
D.lastSignature = nil
D.maxSamples = 80
D.startedAt = nil

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) or false
end

local function Describe(value)
    if IsSecret(value) then
        return "<secret:" .. type(value) .. ">"
    end
    if value == nil then return "<nil>" end
    if type(value) == "string" then return string.format("%q", value) end
    return tostring(value)
end

local function DescribeAccess(value)
    local secret = IsSecret(value)
    local accessible = nil
    if type(canaccessvalue) == "function" then
        accessible = canaccessvalue(value)
    end
    return string.format("%s secret=%s access=%s", type(value), tostring(secret), tostring(accessible))
end

local function CaptureDetailed(sourceUnit, targetUnit)
    if type(UnitDetailedThreatSituation) ~= "function" then
        return "missing"
    end
    local a,b,c,d,e = UnitDetailedThreatSituation(sourceUnit, targetUnit)
    return table.concat({
        "tank=" .. Describe(a) .. "[" .. DescribeAccess(a) .. "]",
        "status=" .. Describe(b) .. "[" .. DescribeAccess(b) .. "]",
        "scaled=" .. Describe(c) .. "[" .. DescribeAccess(c) .. "]",
        "rawPct=" .. Describe(d) .. "[" .. DescribeAccess(d) .. "]",
        "rawThreat=" .. Describe(e) .. "[" .. DescribeAccess(e) .. "]",
    }, " ")
end

local function CaptureSituation(sourceUnit, targetUnit)
    if type(UnitThreatSituation) ~= "function" then return "missing" end
    local value
    if targetUnit then value = UnitThreatSituation(sourceUnit, targetUnit)
    else value = UnitThreatSituation(sourceUnit) end
    return Describe(value) .. "[" .. DescribeAccess(value) .. "]"
end

local function SafeUnitName(unit)
    if not UnitExists(unit) then return "<missing>" end
    local name = UnitName(unit)
    if IsSecret(name) then return "<secret-name>" end
    return name or unit
end

local function AddLine(lines, label, value)
    lines[#lines + 1] = label .. ": " .. value
end

local function BuildSnapshot(reason)
    local lines = {}
    AddLine(lines, "reason", reason or "manual")
    AddLine(lines, "combat", tostring(InCombatLockdown and InCombatLockdown() or false))
    AddLine(lines, "target", SafeUnitName("target"))
    AddLine(lines, "targetGUID", Describe(UnitExists("target") and UnitGUID("target") or nil))
    AddLine(lines, "pet", SafeUnitName("pet"))

    AddLine(lines, "UDTS player,target", CaptureDetailed("player", "target"))
    AddLine(lines, "UTS player,target", CaptureSituation("player", "target"))
    AddLine(lines, "UTS player", CaptureSituation("player"))

    if UnitExists("pet") then
        AddLine(lines, "UDTS pet,target", CaptureDetailed("pet", "target"))
        AddLine(lines, "UTS pet,target", CaptureSituation("pet", "target"))
        AddLine(lines, "UTS pet", CaptureSituation("pet"))
    end

    if UnitExists("targettarget") then
        AddLine(lines, "targettarget", SafeUnitName("targettarget"))
        local isPlayer = UnitIsUnit("targettarget", "player")
        local isPet = UnitExists("pet") and UnitIsUnit("targettarget", "pet") or false
        AddLine(lines, "targettarget=player", Describe(isPlayer) .. "[" .. DescribeAccess(isPlayer) .. "]")
        AddLine(lines, "targettarget=pet", Describe(isPet) .. "[" .. DescribeAccess(isPet) .. "]")
    end

    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
    if plate then
        local uf = plate.UnitFrame
        AddLine(lines, "nameplate", "present")
        if uf then
            AddLine(lines, "UnitFrame", "present")
            local hb = (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar) or uf.healthBar
            if hb then
                local hasSecrets = hb.HasSecretValues and hb:HasSecretValues()
                local anchoringSecret = hb.IsAnchoringSecret and hb:IsAnchoringSecret()
                AddLine(lines, "healthBar secrets", "values=" .. Describe(hasSecrets) .. " anchors=" .. Describe(anchoringSecret))
            end
        end
    else
        AddLine(lines, "nameplate", "missing")
    end

    return lines
end

local function Signature(lines)
    return table.concat(lines, "\n")
end

function D.Capture(reason, force)
    if not D.enabled and not force then return end
    if not UnitExists("target") then return end
    local lines = BuildSnapshot(reason)
    local signature = Signature(lines)
    if not force and signature == D.lastSignature then return end
    D.lastSignature = signature
    D.samples[#D.samples + 1] = { time = GetTime(), lines = lines }
    while #D.samples > D.maxSamples do table.remove(D.samples, 1) end
end

function D.NoteEvent(event, unit)
    if not D.enabled then return end
    D.eventCounts[event] = (D.eventCounts[event] or 0) + 1
    if unit == nil or unit == "target" or unit == "player" or unit == "pet" then
        D.Capture(event .. (unit and (":" .. unit) or ""), false)
    end
end

function D.Start()
    wipe(D.samples)
    wipe(D.eventCounts)
    D.lastSignature = nil
    D.startedAt = GetTime()
    D.enabled = true
    D.Capture("START", true)
    print("TinyThreatPlus threat diagnostic: ON")
    print("Fight with your pet, pull aggro, let the pet regain it, then run /ttp threatreport.")
end

function D.Stop()
    D.Capture("STOP", true)
    D.enabled = false
    print("TinyThreatPlus threat diagnostic: OFF")
end

function D.PrintReport()
    D.Capture("REPORT", true)
    print("========== TinyThreatPlus Threat Diagnostic ==========")
    print("Build:", select(2, GetBuildInfo()), "Interface:", select(4, GetBuildInfo()), "Forever:", tostring(TTP.Compat.IsForever()))
    print("Secret APIs:", "issecretvalue=" .. tostring(type(issecretvalue) == "function"),
        "canaccessvalue=" .. tostring(type(canaccessvalue) == "function"),
        "scrubsecretvalues=" .. tostring(type(scrubsecretvalues) == "function"))
    print("Samples:", #D.samples)
    local eventParts = {}
    for event, count in pairs(D.eventCounts) do eventParts[#eventParts + 1] = event .. "=" .. count end
    table.sort(eventParts)
    print("Events:", #eventParts > 0 and table.concat(eventParts, ", ") or "<none>")
    for index, sample in ipairs(D.samples) do
        print(string.format("--- Sample %d @ %.2f ---", index, sample.time or 0))
        for _, line in ipairs(sample.lines) do print(line) end
    end
    print("========== End Threat Diagnostic ==========")
end
