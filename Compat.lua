-- TinyThreatPlus client/API compatibility layer
--
-- Keep differences between WoW client API surfaces here so feature code can
-- remain client-agnostic. Prefer capability detection over project IDs.

local ADDON_NAME, addonTable = ...
local TTP = _G.TinyThreatPlus or addonTable or {}
_G.TinyThreatPlus = TTP

TTP.Compat = TTP.Compat or {}
local Compat = TTP.Compat

-- WoW Forever currently reports the Mainline project ID. Its interface
-- generation is 16000-series (currently 16001), so project ID alone cannot
-- distinguish Forever from Retail.
function Compat.IsForever()
    local interfaceVersion = select(4, GetBuildInfo())
    return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
        and type(interfaceVersion) == "number"
        and interfaceVersion >= 16000
        and interfaceVersion < 17000
end

function Compat.GetCVar(name)
    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar(name)
    end
    if GetCVar then
        return GetCVar(name)
    end
end

function Compat.SetCVar(name, value)
    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar(name, value)
        return true
    end
    if SetCVar then
        SetCVar(name, value)
        return true
    end
    return false
end

local function Accessible(value)
    if value == nil then return nil end
    if type(canaccessvalue) == "function" and not canaccessvalue(value) then return nil end
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    return value
end

function Compat.GetDetailedThreatSituation(sourceUnit, targetUnit)
    if type(UnitDetailedThreatSituation) ~= "function" then return nil end
    local isTanking, status, scaledPercent, rawPercent, threatValue =
        UnitDetailedThreatSituation(sourceUnit, targetUnit)
    return Accessible(isTanking), Accessible(status), Accessible(scaledPercent),
        Accessible(rawPercent), Accessible(threatValue)
end

function Compat.GetThreatSituation(sourceUnit, targetUnit)
    if type(UnitThreatSituation) ~= "function" then return nil end
    return Accessible(UnitThreatSituation(sourceUnit, targetUnit))
end

function Compat.HasCombatLogEventInfo()
    return type(CombatLogGetCurrentEventInfo) == "function"
end

function Compat.GetCombatLogEventInfo()
    if not Compat.HasCombatLogEventInfo() then
        return nil
    end
    return CombatLogGetCurrentEventInfo()
end

function Compat.CanUseDamageFallback()
    return Compat.HasCombatLogEventInfo()
end

function Compat.HasNamePlateAPI()
    return C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function"
end

-- Forever uses modern secret values for combat-sensitive information. Addons
-- must not compare, branch on, or perform arithmetic with those values.
-- scrubsecretvalues() preserves ordinary values and replaces secret values
-- with nil, giving the feature layer a normal "data unavailable" signal.
function Compat.ScrubSecretValues(...)
    if Compat.IsForever() and type(scrubsecretvalues) == "function" then
        return scrubsecretvalues(...)
    end
    return ...
end

