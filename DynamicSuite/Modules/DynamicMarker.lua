local addonName = ...
local ADDON_FOLDER = (type(addonName) == "string" and addonName ~= "") and addonName or "DynamicSuite"

-- Hard mutual exclusion: when running as the standalone DynamicMarker addon while DynamicSuite
-- is loaded or enabled, immediately disable standalone DynamicMarker and abort execution before
-- any frames, SavedVariables mutations, or slash commands are registered.
if ADDON_FOLDER ~= "DynamicSuite" then
    local isSuiteLoaded = (C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" and C_AddOns.IsAddOnLoaded("DynamicSuite"))
        or (type(_G.IsAddOnLoaded) == "function" and _G.IsAddOnLoaded("DynamicSuite"))
        or (_G.DynamicSuite and _G.DynamicSuite._isHubLoaded == true)
    local isSuiteEnabled = false
    if C_AddOns and type(C_AddOns.GetAddOnEnableState) == "function" then
        local pName = type(_G.UnitName) == "function" and _G.UnitName("player") or nil
        if type(pName) == "string" and pName ~= "" and pName ~= "Unknown" and pName ~= _G.UNKNOWNOBJECT then
            local ok, st = pcall(C_AddOns.GetAddOnEnableState, "DynamicSuite", pName)
            if ok and type(st) == "number" and st > 0 then isSuiteEnabled = true end
        end
        if not isSuiteEnabled then
            local ok2, st2 = pcall(C_AddOns.GetAddOnEnableState, "DynamicSuite")
            if ok2 and type(st2) == "number" and st2 > 0 then isSuiteEnabled = true end
        end
        if not isSuiteEnabled then
            local pGuid = type(_G.UnitGUID) == "function" and _G.UnitGUID("player") or nil
            if type(pGuid) == "string" and pGuid ~= "" then
                local ok3, st3 = pcall(C_AddOns.GetAddOnEnableState, "DynamicSuite", pGuid)
                if ok3 and type(st3) == "number" and st3 > 0 then isSuiteEnabled = true end
            end
        end
    end
    if isSuiteLoaded or isSuiteEnabled then
        _G.DynamicSuite = _G.DynamicSuite or {}
        _G.DynamicSuite.standaloneMarkerWasEnabledAtBoot = true
        if C_AddOns and type(C_AddOns.DisableAddOn) == "function" then
            local pName = type(_G.UnitName) == "function" and _G.UnitName("player") or nil
            if type(pName) == "string" and pName ~= "" and pName ~= "Unknown" and pName ~= _G.UNKNOWNOBJECT then
                pcall(C_AddOns.DisableAddOn, "DynamicMarker", pName)
            end
            pcall(C_AddOns.DisableAddOn, "DynamicMarker")
        end
        if type(_G.DynamicSuite.EnforceStandaloneDynamicMarkerExclusion) == "function" then
            pcall(_G.DynamicSuite.EnforceStandaloneDynamicMarkerExclusion, true)
        end
        return
    end
end

local function ResolveAddonVersion(folderName, fallback)
    local fb = fallback or "2.6.5"
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    if type(getMeta) == "function" then
        local ok, ver = pcall(getMeta, folderName or ADDON_FOLDER, "Version")
        if ok and type(ver) == "string" and ver ~= "" and not ver:find("@") then
            return ver:gsub("^[vV]", "")
        end
        if folderName ~= "DynamicSuite" then
            local ok2, ver2 = pcall(getMeta, "DynamicSuite", "Version")
            if ok2 and type(ver2) == "string" and ver2 ~= "" and not ver2:find("@") then
                return ver2:gsub("^[vV]", "")
            end
        end
    end
    return fb
end

local function CompareSemVer(vA, vB)
    local a1, a2, a3 = tostring(vA or "0.0.0"):gsub("^[vV]", ""):match("^(%d+)%.?(%d*)%.?(%d*)")
    local b1, b2, b3 = tostring(vB or "0.0.0"):gsub("^[vV]", ""):match("^(%d+)%.?(%d*)%.?(%d*)")
    local nA1, nA2, nA3 = tonumber(a1) or 0, tonumber(a2) or 0, tonumber(a3) or 0
    local nB1, nB2, nB3 = tonumber(b1) or 0, tonumber(b2) or 0, tonumber(b3) or 0
    if nA1 ~= nB1 then return (nA1 > nB1) and 1 or -1 end
    if nA2 ~= nB2 then return (nA2 > nB2) and 1 or -1 end
    if nA3 ~= nB3 then return (nA3 > nB3) and 1 or -1 end
    return 0
end

local function ShouldYieldToOtherInstall(addonFolder, standaloneName, thisVersion, globalTbl)
    local isAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
    local getAddOnEnableState = (C_AddOns and C_AddOns.GetAddOnEnableState) or _G.GetAddOnEnableState
    local function isOtherEnabled(name)
        if type(isAddOnLoaded) == "function" and isAddOnLoaded(name) then
            return true
        end
        if type(getAddOnEnableState) == "function" then
            local pName = type(_G.UnitName) == "function" and _G.UnitName("player") or nil
            if type(pName) == "string" and pName ~= "" and pName ~= "Unknown" and pName ~= _G.UNKNOWNOBJECT then
                local ok, st = pcall(getAddOnEnableState, name, pName)
                if ok and type(st) == "number" and st > 0 then return true end
            end
            local ok2, st2 = pcall(getAddOnEnableState, name)
            if ok2 and type(st2) == "number" and st2 > 0 then return true end
            local pGuid = type(_G.UnitGUID) == "function" and _G.UnitGUID("player") or nil
            if type(pGuid) == "string" and pGuid ~= "" then
                local ok3, st3 = pcall(getAddOnEnableState, name, pGuid)
                if ok3 and type(st3) == "number" and st3 > 0 then return true end
            end
        end
        return false
    end
    if addonFolder ~= "DynamicSuite" then
        local suiteVer = (type(globalTbl) == "table" and (globalTbl._loadedVersion or globalTbl.version or globalTbl.VERSION))
            or (_G.DynamicSuite and _G.DynamicSuite.version)
            or "2.6.5"
        if suiteVer and CompareSemVer(suiteVer, "0.0.0") >= 0 then
            -- Never run standalone DynamicMarker alongside DynamicSuite
        end
        if isOtherEnabled("DynamicSuite")
            or (type(globalTbl) == "table" and globalTbl._loadedBySuite == true)
            or (_G.DynamicSuite and _G.DynamicSuite._isHubLoaded == true)
        then
            _G.DynamicSuite_StandaloneMarkerWasEnabledAtBoot = true
            if _G.DynamicSuite then
                _G.DynamicSuite.standaloneMarkerWasEnabledAtBoot = true
                _G.DynamicSuite._standaloneMarkerConflictDetected = true
            end
            if C_AddOns and type(C_AddOns.DisableAddOn) == "function" then
                local pName = type(_G.UnitName) == "function" and _G.UnitName("player") or nil
                if type(pName) == "string" and pName ~= "" and pName ~= "Unknown" and pName ~= _G.UNKNOWNOBJECT then
                    pcall(C_AddOns.DisableAddOn, standaloneName or addonFolder, pName)
                end
                pcall(C_AddOns.DisableAddOn, standaloneName or addonFolder)
            end
            return true
        end
        return false
    end
    return false
end

local VERSION = ResolveAddonVersion(ADDON_FOLDER, "2.6.5")
if ShouldYieldToOtherInstall(ADDON_FOLDER, "DynamicMarker", VERSION, _G.DynamicMarker) then
    return
end
local DM_NS = {}
local isInitialized = false

local function IsModuleDisabledInSuite(modName)
    local key = modName or "DynamicMarker"
    local shortK = key:gsub("^Dynamic", ""):lower()
    local db = _G.DynamicSuiteDB
    if type(db) == "table" then
        if type(db.disabledModules) == "table" and (db.disabledModules[key] or db.disabledModules[shortK]) then
            return true
        end
        if type(db.global) == "table" and type(db.global.disabledModules) == "table" and (db.global.disabledModules[key] or db.global.disabledModules[shortK]) then
            return true
        end
    end
    return false
end

-- ============================================================================
-- 1. GLOBAL SUITE NAMESPACE & MODULE REGISTRATION
-- ============================================================================

_G.DynamicSuite = _G.DynamicSuite or {}
local Suite = _G.DynamicSuite
Suite.modules = Suite.modules or {}
Suite.hudElements = Suite.hudElements or {}
Suite.Changelogs = Suite.Changelogs or {}

local DM
if ADDON_FOLDER == "DynamicSuite" then
    if type(_G.DynamicMarker) == "table" and _G.DynamicMarker._loadedBySuite == true then
        DM = _G.DynamicMarker
    else
        DM = DM_NS
        _G.DynamicMarker = DM
    end
    DM._loadedBySuite = true
else
    DM = _G.DynamicMarker or DM_NS
    _G.DynamicMarker = DM
    DM._loadedBySuite = false
end
DM._loadedVersion = VERSION

DM.name = "DynamicMarker"
DM.key = "marker"
DM.version = VERSION
DM.slash = "/dm"

-- ============================================================================
-- 2. CONSTANTS, ICON TABLES & CLASS INTERRUPT MATRIX
-- ============================================================================

local ICON_CHECK_PATH   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_check.tga"
local ICON_CHEVRON_DOWN = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga"
local ICON_CHEVRON_UP   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga"
local ICON_COG_PATH     = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_cog.tga"
local READY_CHECK_TEX   = "|TInterface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_check:12:12:0:0|t"

local RAID_ICONS = {
    [1] = { index = 1, name = "Star",     emoji = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14:0:0|t", label = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14:0:0|t Star (1)",     color = { r = 0.98, g = 0.80, b = 0.08 }, coords = { 0.00, 0.25, 0.00, 0.25 } },
    [2] = { index = 2, name = "Circle",   emoji = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:14:14:0:0|t", label = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:14:14:0:0|t Circle (2)",   color = { r = 0.98, g = 0.57, b = 0.24 }, coords = { 0.25, 0.50, 0.00, 0.25 } },
    [3] = { index = 3, name = "Diamond",  emoji = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:14:14:0:0|t", label = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:14:14:0:0|t Diamond (3)",  color = { r = 0.75, g = 0.52, b = 0.99 }, coords = { 0.50, 0.75, 0.00, 0.25 } },
    [4] = { index = 4, name = "Triangle", emoji = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:14:14:0:0|t", label = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:14:14:0:0|t Triangle (4)", color = { r = 0.29, g = 0.87, b = 0.50 }, coords = { 0.75, 1.00, 0.00, 0.25 } },
    [5] = { index = 5, name = "Moon",     emoji = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:14:14:0:0|t", label = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:14:14:0:0|t Moon (5)",     color = { r = 0.58, g = 0.77, b = 0.99 }, coords = { 0.00, 0.25, 0.25, 0.50 } },
    [6] = { index = 6, name = "Square",   emoji = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:14:14:0:0|t", label = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:14:14:0:0|t Square (6)",   color = { r = 0.22, g = 0.74, b = 0.97 }, coords = { 0.25, 0.50, 0.25, 0.50 } },
    [7] = { index = 7, name = "Cross",    emoji = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:14:14:0:0|t", label = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:14:14:0:0|t Cross (7)",    color = { r = 0.97, g = 0.44, b = 0.44 }, coords = { 0.50, 0.75, 0.25, 0.50 } },
    [8] = { index = 8, name = "Skull",    emoji = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:14:14:0:0|t", label = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:14:14:0:0|t Skull (8)",    color = { r = 0.95, g = 0.96, b = 0.98 }, coords = { 0.75, 1.00, 0.25, 0.50 } },
}
DM.RAID_ICONS = RAID_ICONS

-- World Marker numeric indices (1..8) as used by Blizzard /wm and SecureActionButton worldmarker
local WORLD_FLARES = {
    [1] = { index = 1, name = "Blue",   emoji = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:14:14:0:0|t", short = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:14:14:0:0|t Blue",   raidIcon = 6, color = { r = 0.22, g = 0.74, b = 0.97 }, hex = "38BDF8" },
    [2] = { index = 2, name = "Green",  emoji = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:14:14:0:0|t", short = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:14:14:0:0|t Green",  raidIcon = 4, color = { r = 0.29, g = 0.87, b = 0.50 }, hex = "4ADE80" },
    [3] = { index = 3, name = "Purple", emoji = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:14:14:0:0|t", short = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:14:14:0:0|t Purple", raidIcon = 3, color = { r = 0.75, g = 0.52, b = 0.99 }, hex = "C084FC" },
    [4] = { index = 4, name = "Red",    emoji = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:14:14:0:0|t", short = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:14:14:0:0|t Red",    raidIcon = 7, color = { r = 0.97, g = 0.44, b = 0.44 }, hex = "F87171" },
    [5] = { index = 5, name = "Yellow", emoji = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14:0:0|t", short = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14:0:0|t Yellow", raidIcon = 1, color = { r = 0.98, g = 0.80, b = 0.08 }, hex = "FACC15" },
    [6] = { index = 6, name = "Orange", emoji = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:14:14:0:0|t", short = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:14:14:0:0|t Orange", raidIcon = 2, color = { r = 0.98, g = 0.57, b = 0.24 }, hex = "FB923C" },
    [7] = { index = 7, name = "Silver", emoji = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:14:14:0:0|t", short = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:14:14:0:0|t Silver", raidIcon = 5, color = { r = 0.82, g = 0.88, b = 0.95 }, hex = "CBD5E1" },
    [8] = { index = 8, name = "Skull",  emoji = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:14:14:0:0|t", short = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:14:14:0:0|t Skull",  raidIcon = 8, color = { r = 0.98, g = 0.98, b = 1.00 }, hex = "FFFFFF" },
}
DM.WORLD_FLARES = WORLD_FLARES

local GROUP_SCOPE_OPTIONS = {
    { value = "BOTH",  label = "Party & Raid" },
    { value = "PARTY", label = "Party" },
    { value = "RAID",  label = "Raid" },
    { value = "ALL",   label = "All" },
}

local CHAT_ANNOUNCE_OPTIONS = {
    { value = "MUTED",  label = "Off" },
    { value = "ACTIVE", label = "Enabled" },
}

local CHAT_CHANNEL_OPTIONS = {
    { value = "PARTY_INSTANCE", label = "Group & Raid" },
    { value = "PARTY",          label = "Party Only" },
    { value = "SAY",            label = "Say" },
}

local BAR_VISIBILITY_OPTIONS = {
    { value = "HIDDEN", label = "Off" },
    { value = "GROUP",  label = "Group" },
    { value = "ALWAYS", label = "Always" },
}

local BAR_ORIENTATION_OPTIONS = {
    { value = "HORIZONTAL", label = "Horizontal" },
    { value = "VERTICAL",   label = "Vertical" },
}

local HUD_BORDER_STYLE_OPTIONS = {
    { value = "ACCENT", label = "Suite Accent" },
    { value = "DARK",   label = "Subtle Dark" },
    { value = "NONE",   label = "Borderless" },
}

local CLEAR_MODIFIER_OPTIONS = {
    { value = "NONE",  label = "None" },
    { value = "shift", label = "Shift" },
    { value = "alt",   label = "Alt" },
    { value = "ctrl",  label = "Ctrl" },
}

local FOCUS_TARGET_MODE_OPTIONS = {
    { value = "MOUSEOVER_TARGET", label = "Mouseover + Target" },
    { value = "TARGET_ONLY",      label = "Target Only" },
    { value = "MANUAL",           label = "Manual (Custom)" },
}

local KICK_PRIORITY_OPTIONS = {
    { value = "SMART_AUTOTARGET", label = "Smart Auto-Target (Mouseover > Focus > Nearest)" },
    { value = "MO_FOCUS_TARGET",  label = "Standard: Mouseover > Focus > Target", cond = "[@mouseover,exists,nodead,harm][@focus,exists,nodead,harm][]" },
    { value = "FOCUS_MO_TARGET",  label = "Standard: Focus > Mouseover > Target", cond = "[@focus,exists,nodead,harm][@mouseover,exists,nodead,harm][]" },
    { value = "FOCUS_ONLY",       label = "Strict Focus Only (@focus)",             cond = "[@focus,exists,nodead,harm]" },
}

local KICK_SPEC_MODE_OPTIONS = {
    { value = "SMART_SWAP", label = "Smart Auto-Swap" },
    { value = "SEPARATE",   label = "Separate Macros" },
}

local HEALER_NO_KICK_SPECS = {
    [65]   = true, -- Holy Paladin
    [105]  = true, -- Restoration Druid
    [256]  = true, -- Discipline Priest
    [257]  = true, -- Holy Priest
    [270]  = true, -- Mistweaver Monk
    [1468] = true, -- Preservation Evoker
}

local SPELL_NAME_TO_ID = {
    ["Mind Freeze"]       = 47528,
    ["Disrupt"]           = 183752,
    ["Skull Bash"]        = 106839,
    ["Solar Beam"]        = 78675,
    ["Quell"]             = 351338,
    ["Counter Shot"]      = 147362,
    ["Muzzle"]            = 187707,
    ["Counterspell"]      = 2139,
    ["Spear Hand Strike"] = 116705,
    ["Rebuke"]            = 96231,
    ["Silence"]           = 15487,
    ["Kick"]              = 1766,
    ["Wind Shear"]        = 57994,
    ["Command Demon"]     = 119898,
    ["Pummel"]            = 6552,
}

local CLASS_INTERRUPTS = {
    DEATHKNIGHT = { default = "Mind Freeze",       spells = { "Mind Freeze" } },
    DEMONHUNTER = { default = "Disrupt",           spells = { "Disrupt" } },
    DRUID       = { default = "Skull Bash",        spells = { "Skull Bash", "Solar Beam" }, bySpecID = { [102] = "Solar Beam", [103] = "Skull Bash", [104] = "Skull Bash", [105] = "Skull Bash" } },
    EVOKER      = { default = "Quell",             spells = { "Quell" } },
    HUNTER      = { default = "Counter Shot",      spells = { "Counter Shot", "Muzzle" },   bySpecID = { [253] = "Counter Shot", [254] = "Counter Shot", [255] = "Muzzle" } },
    MAGE        = { default = "Counterspell",      spells = { "Counterspell" } },
    MONK        = { default = "Spear Hand Strike", spells = { "Spear Hand Strike" } },
    PALADIN     = { default = "Rebuke",            spells = { "Rebuke" } },
    PRIEST      = { default = "Silence",           spells = { "Silence" } },
    ROGUE       = { default = "Kick",              spells = { "Kick" } },
    SHAMAN      = { default = "Wind Shear",        spells = { "Wind Shear" } },
    WARLOCK     = { default = "Command Demon",     spells = { "Command Demon" } },
    WARRIOR     = { default = "Pummel",            spells = { "Pummel" } },
}

local CONFLICT_ADDONS = {
    { name = "FocusMarker",  label = "FocusMarker",  isLegacy = true },
    { name = "TargetCharms", label = "TargetCharms", isLegacy = false },
    { name = "DejaMark",     label = "DejaMark",     isLegacy = false },
    { name = "EasyMarker",   label = "EasyMarker",   isLegacy = false },
    { name = "DecorVendor",  label = "Decor Vendor", isLegacy = false },
}

local ADVISORY_CONFLICT_ADDONS = {}

local SUITE_MODULE_LIST = {
    { key = "load",   addon = "DynamicLoad",   title = "DynamicLoad",   sub = "Zone Addon Profiles",    subtitle = "Zone Addon Profiles",    slash = "/dl",     desc = "Automatically stages addon loadouts across Outdoor, Delves, Dungeons, Raid, and PvP using By Zone, Always, and Never rules." },
    { key = "marker", addon = "DynamicMarker", title = "DynamicMarker", sub = "Targets, Flares, Macros", subtitle = "Targets, Flares, Macros", slash = "/dm",     desc = "One-button focus target marking, optional ground flare hotkeys (unbound by default), and an auto-swapping interrupt macro across all 13 classes." },
    { key = "zoom",   addon = "DynamicZoom",   title = "DynamicZoom",   sub = "Max Zoom & Camera",      subtitle = "Max Zoom & Camera",      slash = "/dz",     desc = "Unlocks 39-yard max camera distance, fast scroll wheel boost, see-through trees and pillars, and automatic zone zoom." },
    { key = "fps",    addon = "DynamicFPS",    title = "DynamicFPS",    sub = "Zone Graphics & FPS",    subtitle = "Zone Graphics & FPS",    slash = "/dfps",   desc = "Switches graphics settings per zone without reloading, protects combat FPS, tunes spell queue, and keeps boss swirlies visible." },
    { key = "prep",   addon = "DynamicPrep",   title = "DynamicPrep",   sub = "Stats, Buffs & QoL",     subtitle = "Stats, Buffs & QoL",     slash = "/dprep",  desc = "Live stat and readiness top bar, clickable raid buffs and consumables, Omni Folio tracking, quest/cutscene skipping, and survival macros." },
    { key = "group",  addon = "DynamicGroup",  title = "DynamicGroup",  sub = "LFG Filter & Invites",   subtitle = "LFG Filter & Invites",   slash = "/dgroup", desc = "Filters Premade Groups by datacentre region, M+ score, and Lust/CR utility, with 1-click sign-up, auto-invite, and M+ keystone slotting." },
    { key = "bags",   addon = "DynamicBags",   title = "DynamicBags",   sub = "Bags & Alt Vault",       subtitle = "Bags & Alt Vault",       slash = "/dbag",   desc = "Zero-lag category bags, companion Bank/Warband/Guild Bank window, alt item vault, auto-repair, auto-sell junk, and fast auto-loot." },
    { key = "chat",   addon = "DynamicChat",   title = "DynamicChat",   sub = "Target /ww & Chat QoL",  subtitle = "Target /ww & Chat QoL",  slash = "/dchat",  desc = "Instant /ww target whispers, smoked-glass chat skin with left shortcut bar, clickable links, and saved chat history across reloads." },
}

local THEME_PRESETS = {
    OBSIDIAN = { name = "Obsidian Silver", r = 0.80, g = 0.84, b = 0.88, hex = "CBD5E1" },
    CLASS    = { name = "Player Class Colour", isClass = true },
    CYAN     = { name = "Midnight Cyan",   r = 0.22, g = 0.74, b = 0.97, hex = "38BDF8" },
    CRIMSON  = { name = "Crimson Core",    r = 0.97, g = 0.44, b = 0.44, hex = "F87171" },
    GOLD     = { name = "Royal Amber",     r = 0.96, g = 0.72, b = 0.18, hex = "F5B82E" },
}

local SURFACE_THEMES = {
    MIDNIGHT_BLACK = {
        name   = "Midnight Pitch Black",
        header = { r = 0.015, g = 0.018, b = 0.024, a = 1.00 },
        rail   = { r = 0.024, g = 0.027, b = 0.035, a = 1.00 },
        panel  = { r = 0.035, g = 0.039, b = 0.051, a = 0.99 },
        card   = { r = 0.055, g = 0.063, b = 0.082, a = 0.96 },
    },
    OBSIDIAN_DARK = {
        name   = "Obsidian Dark (Default)",
        header = { r = 0.035, g = 0.039, b = 0.051, a = 1.00 },
        rail   = { r = 0.047, g = 0.055, b = 0.071, a = 0.99 },
        panel  = { r = 0.067, g = 0.075, b = 0.094, a = 0.98 },
        card   = { r = 0.090, g = 0.102, b = 0.129, a = 0.96 },
    },
    SLATE_STEEL = {
        name   = "Slate Steel",
        header = { r = 0.055, g = 0.067, b = 0.090, a = 1.00 },
        rail   = { r = 0.071, g = 0.086, b = 0.114, a = 0.99 },
        panel  = { r = 0.090, g = 0.106, b = 0.141, a = 0.98 },
        card   = { r = 0.118, g = 0.137, b = 0.180, a = 0.96 },
    },
    SMOKED_GLASS = {
        name   = "Smoked Glass",
        header = { r = 0.045, g = 0.055, b = 0.075, a = 0.92 },
        rail   = { r = 0.055, g = 0.067, b = 0.090, a = 0.88 },
        panel  = { r = 0.075, g = 0.090, b = 0.118, a = 0.86 },
        card   = { r = 0.102, g = 0.122, b = 0.157, a = 0.84 },
    },
}

local function GetStandaloneSurfaceColors(dm)
    local gTbl = (dm and dm.suiteGlobal) or (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global)
    local key = gTbl and gTbl.surfaceTheme
    if key and SURFACE_THEMES[key] then
        return SURFACE_THEMES[key], key
    end
    return SURFACE_THEMES.OBSIDIAN_DARK, "OBSIDIAN_DARK"
end

-- ============================================================================
-- 3. SAVEDVARIABLES DEFAULTS, FOCUSMARKER BRIDGE & INITIALIZATION
-- ============================================================================

local DB_DEFAULTS = {
    focusIcon            = 8,
    iconOrder            = { 1, 2, 3, 4, 5, 6, 7, 8 },
    groupScope           = "BOTH",
    chatAnnounce         = "ACTIVE",
    chatChannel          = "PARTY",
    tuneChatExpanded     = true,
    targetBarVisibility  = "GROUP",
    targetBarOrientation = "HORIZONTAL",
    targetBarScale       = 1.00,
    targetBarOpacity     = 0.95,
    targetBarPoint       = "CENTER",
    targetBarRelPoint    = "CENTER",
    targetBarX           = 0,
    targetBarY           = -140,
    targetBarPos         = { point = "CENTER", relPoint = "CENTER", x = 0, y = -140 },
    tuneTargetBarExpanded = true,
    flareCycleKey        = "",
    flareClearKey        = "",
    flareOrder           = { 1, 2, 3, 4, 5, 6, 7, 8 },
    flareEnabled         = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true },
    flareEnabledAll8MigratedV2 = false,
    flareBarVisibility   = "GROUP",
    flareBarOrientation  = "HORIZONTAL",
    flareBarScale        = 1.00,
    flareBarOpacity      = 0.95,
    flareBarPoint        = "CENTER",
    flareBarRelPoint     = "CENTER",
    flareBarX            = 0,
    flareBarY            = -182,
    flareBarPos          = { point = "CENTER", relPoint = "CENTER", x = 0, y = -182 },
    tuneFlareBarExpanded = true,
    hudBorderStyle       = "ACCENT",
    focusClearModifier   = "NONE",
    focusTargetMode      = "MOUSEOVER_TARGET",
    kickPriority         = "SMART_AUTOTARGET",
    kickPriorityMigratedV2 = false,
    kickSpecMode         = "SMART_SWAP",
    activeSubTab         = 1,
    hudShowGrid          = true,
    migratedFromFocusMarker = false,
    focusMarkerBridgeVersion = 0,
    focusMarkerHintShown = false,
    dismissedAdvisoryConflicts = {},
}

local SUITE_GLOBAL_DEFAULTS = {
    window = {
        width    = 980,
        height   = 680,
        scale    = 1.0,
        point    = "CENTER",
        relPoint = "CENTER",
        x        = 0,
        y        = 0,
    },
    theme           = "GOLD",
    fontKey         = "EXPRESSWAY",
    fontFamily      = "EXPRESSWAY",
    fontScale       = 1.0,
    fontOutline     = "",
    guidedSetupDone = false,
    hudPositions    = {},
}

local function DeepCopyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = DeepCopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

local FOCUSMARKER_BRIDGE_VERSION = 3
local VALID_HUD_ANCHORS = {
    CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
    TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
}

local function IsFiniteNum(n)
    return type(n) == "number" and n == n and n > -1e9 and n < 1e9
end

local function SafeDeepCopyValue(val, depth, seen)
    local tv = type(val)
    if tv == "number" then
        return IsFiniteNum(val) and val or nil
    elseif tv == "string" or tv == "boolean" then
        return val
    elseif tv ~= "table" then
        return nil
    end
    depth = depth or 0
    if depth > 5 then return nil end
    seen = seen or {}
    if seen[val] then return nil end
    seen[val] = true
    local out = {}
    for k, sub in pairs(val) do
        local tk = type(k)
        if tk == "number" or tk == "string" then
            local copied = SafeDeepCopyValue(sub, depth + 1, seen)
            if copied ~= nil then
                out[k] = copied
            end
        end
    end
    seen[val] = nil
    return out
end

local function SanitizePermutation1To8(tbl)
    local seen = {}
    local clean = {}
    local hadAny = false
    if type(tbl) == "table" then
        for i = 1, 8 do
            local v = tbl[i]
            local n = (type(v) == "number" or type(v) == "string") and tonumber(v) or nil
            if n and IsFiniteNum(n) then
                n = math.floor(n + 0.5)
                if n >= 1 and n <= 8 and not seen[n] then
                    seen[n] = true
                    clean[#clean + 1] = n
                    hadAny = true
                end
            end
        end
        for _, v in ipairs(tbl) do
            local n = (type(v) == "number" or type(v) == "string") and tonumber(v) or nil
            if n and IsFiniteNum(n) then
                n = math.floor(n + 0.5)
                if n >= 1 and n <= 8 and not seen[n] then
                    seen[n] = true
                    clean[#clean + 1] = n
                    hadAny = true
                end
            end
        end
    end
    for i = 1, 8 do
        if not seen[i] then
            clean[#clean + 1] = i
        end
    end
    return clean, hadAny
end

local function NormalizeBarVisibilityValue(val)
    if val == false or val == 0 then
        return "off", "HIDDEN", false
    elseif val == true then
        return "always", "ALWAYS", false
    end
    if type(val) ~= "string" and type(val) ~= "number" then
        return "group", "GROUP", false
    end
    local s = tostring(val):upper():match("^%s*(.-)%s*$") or ""
    if s == "OFF" or s == "HIDDEN" or s == "HIDE" or s == "NONE" or s == "DISABLED" or s == "NEVER" or s == "0" then
        return "off", "HIDDEN", false
    elseif s == "SOLO" then
        return "always", "ALWAYS", true
    elseif s == "ALWAYS" or s == "ALL" or s == "SHOW" or s == "SHOWN" or s == "ON" or s == "ENABLED" or s == "1" then
        return "always", "ALWAYS", false
    elseif s == "GROUP" or s == "PARTY" or s == "RAID" or s == "BOTH" or s == "INGROUP" then
        return "group", "GROUP", false
    else
        return "group", "GROUP", false
    end
end

local function NormalizeGroupScopeValue(val)
    if type(val) ~= "string" then
        return "both", "BOTH"
    end
    local s = val:upper():match("^%s*(.-)%s*$") or ""
    if s == "PARTY" or s == "PARTY ONLY" then
        return "party", "PARTY"
    elseif s == "RAID" or s == "RAID ONLY" then
        return "raid", "RAID"
    elseif s == "ALL" or s == "SOLO" or s == "ALWAYS" then
        return "all", "ALL"
    else
        return "both", "BOTH"
    end
end

local function NormalizeOrientationValue(val)
    if type(val) ~= "string" then return nil end
    local s = val:upper():match("^%s*(.-)%s*$") or ""
    if s == "VERTICAL" or s == "VERT" or s == "V" then
        return "VERTICAL"
    elseif s == "HORIZONTAL" or s == "HORIZ" or s == "H" then
        return "HORIZONTAL"
    end
    return nil
end

local function SanitizeAnchorPoint(pt, fallback)
    local fb = fallback or "CENTER"
    if type(pt) ~= "string" then return fb end
    local u = pt:upper():match("^%s*(.-)%s*$") or ""
    if VALID_HUD_ANCHORS[u] then
        return u
    end
    return fb
end

local function GetAnchorFraction(pointStr)
    local pt = type(pointStr) == "string" and pointStr:upper() or "CENTER"
    local fx = 0.5
    local fy = 0.5
    if pt:find("LEFT", 1, true) then
        fx = 0.0
    elseif pt:find("RIGHT", 1, true) then
        fx = 1.0
    end
    if pt:find("BOTTOM", 1, true) then
        fy = 0.0
    elseif pt:find("TOP", 1, true) then
        fy = 1.0
    end
    return fx, fy
end

local function RoundHUDCoord(v)
    return math.floor((tonumber(v) or 0) + 0.5)
end

local function FM_CollectCandidateSources(raw)
    local sources = {}
    local seenTbls = {}
    local function PushTbl(t)
        if type(t) == "table" and not seenTbls[t] then
            seenTbls[t] = true
            sources[#sources + 1] = t
        end
    end
    if type(raw) ~= "table" then return sources end

    if type(raw.profiles) == "table" then
        local charKey, playerName
        if type(UnitName) == "function" then
            local okN, name = pcall(UnitName, "player")
            local okR, realm = pcall(GetRealmName)
            if okN and type(name) == "string" and name ~= "" then
                playerName = name
                if okR and type(realm) == "string" and realm ~= "" then
                    charKey = name .. " - " .. realm
                end
            end
        end
        local profileName
        if type(raw.profileKeys) == "table" then
            local pKey = (charKey and raw.profileKeys[charKey]) or (playerName and raw.profileKeys[playerName])
            if type(pKey) == "string" and pKey ~= "" then
                profileName = pKey
            end
        end
        if profileName and type(raw.profiles[profileName]) == "table" then
            PushTbl(raw.profiles[profileName])
        end
        PushTbl(raw.profiles["Default"])
        PushTbl(raw.profiles["default"])
        local extraKeys = {}
        for k, v in pairs(raw.profiles) do
            if type(k) == "string" and type(v) == "table" and not seenTbls[v] then
                extraKeys[#extraKeys + 1] = k
            end
        end
        table.sort(extraKeys)
        for _, k in ipairs(extraKeys) do
            PushTbl(raw.profiles[k])
        end
    end

    PushTbl(raw.profile)
    PushTbl(raw.char)
    PushTbl(raw.global)
    PushTbl(raw)
    return sources
end

local function FM_ReadFirstValid(sources, keys, validator)
    for _, src in ipairs(sources) do
        if type(src) == "table" then
            for _, k in ipairs(keys) do
                local v = src[k]
                if v ~= nil and (not validator or validator(v)) then
                    return v, src, k
                end
            end
        end
    end
    return nil, nil, nil
end

local function FM_ExtractBarPosition(sources, tableKeys, pointKeys, relPointKeys, xKeys, yKeys, defaultY)
    local tbl = FM_ReadFirstValid(sources, tableKeys, function(v) return type(v) == "table" end)
    if type(tbl) == "table" then
        if IsFiniteNum(tbl.x) and IsFiniteNum(tbl.y) then
            local pt = SanitizeAnchorPoint(tbl.point or tbl.anchor, "CENTER")
            local rp = SanitizeAnchorPoint(tbl.relPoint or tbl.relativePoint or tbl.anchorTo, pt)
            local x = math.max(-4000, math.min(4000, math.floor(tbl.x + 0.5)))
            local y = math.max(-4000, math.min(4000, math.floor(tbl.y + 0.5)))
            return { point = pt, relPoint = rp, x = x, y = y }
        elseif IsFiniteNum(tbl.xOfs) and IsFiniteNum(tbl.yOfs) then
            local pt = SanitizeAnchorPoint(tbl.point or tbl.anchor, "CENTER")
            local rp = SanitizeAnchorPoint(tbl.relPoint or tbl.relativePoint or tbl.anchorTo, pt)
            local x = math.max(-4000, math.min(4000, math.floor(tbl.xOfs + 0.5)))
            local y = math.max(-4000, math.min(4000, math.floor(tbl.yOfs + 0.5)))
            return { point = pt, relPoint = rp, x = x, y = y }
        elseif IsFiniteNum(tbl[4]) and IsFiniteNum(tbl[5]) then
            local pt = SanitizeAnchorPoint(tbl[1], "CENTER")
            local rp = SanitizeAnchorPoint(tbl[3], pt)
            local x = math.max(-4000, math.min(4000, math.floor(tbl[4] + 0.5)))
            local y = math.max(-4000, math.min(4000, math.floor(tbl[5] + 0.5)))
            return { point = pt, relPoint = rp, x = x, y = y }
        elseif IsFiniteNum(tbl[3]) and IsFiniteNum(tbl[4]) then
            local pt = SanitizeAnchorPoint(tbl[1], "CENTER")
            local rp = SanitizeAnchorPoint(tbl[2], pt)
            local x = math.max(-4000, math.min(4000, math.floor(tbl[3] + 0.5)))
            local y = math.max(-4000, math.min(4000, math.floor(tbl[4] + 0.5)))
            return { point = pt, relPoint = rp, x = x, y = y }
        elseif IsFiniteNum(tbl[1]) and IsFiniteNum(tbl[2]) then
            local x = math.max(-4000, math.min(4000, math.floor(tbl[1] + 0.5)))
            local y = math.max(-4000, math.min(4000, math.floor(tbl[2] + 0.5)))
            return { point = "CENTER", relPoint = "CENTER", x = x, y = y }
        end
    end

    local fx = FM_ReadFirstValid(sources, xKeys, IsFiniteNum)
    local fy = FM_ReadFirstValid(sources, yKeys, IsFiniteNum)
    if fx ~= nil or fy ~= nil then
        local pt = SanitizeAnchorPoint(FM_ReadFirstValid(sources, pointKeys, function(v) return type(v) == "string" end), "CENTER")
        local rp = SanitizeAnchorPoint(FM_ReadFirstValid(sources, relPointKeys, function(v) return type(v) == "string" end), pt)
        local cx = IsFiniteNum(fx) and math.max(-4000, math.min(4000, math.floor(fx + 0.5))) or 0
        local cy = IsFiniteNum(fy) and math.max(-4000, math.min(4000, math.floor(fy + 0.5))) or (defaultY or 0)
        return { point = pt, relPoint = rp, x = cx, y = cy }
    end
    return nil
end

local function FM_NormalizeScale(rawScale, rawIconSize)
    if IsFiniteNum(rawScale) and rawScale > 0 then
        local s = rawScale
        if s > 3 and s <= 300 then
            s = s / 100
        end
        if s >= 0.2 and s <= 3.0 then
            return math.max(0.60, math.min(1.50, math.floor(s * 20 + 0.5) / 20))
        end
    end
    if IsFiniteNum(rawIconSize) and rawIconSize >= 12 and rawIconSize <= 96 then
        local ratio = rawIconSize / 32
        return math.max(0.60, math.min(1.50, math.floor(ratio * 20 + 0.5) / 20))
    end
    return nil
end

local function FM_NormalizeOpacity(rawOpacity)
    if not IsFiniteNum(rawOpacity) then return nil end
    local op = rawOpacity
    if op > 1 and op <= 100 then
        op = op / 100
    end
    if op >= 0 and op <= 1 then
        return math.max(0.20, math.min(1.00, math.floor(op * 20 + 0.5) / 20))
    end
    return nil
end

function DM:RunOneTimeFocusMarkerMigration(srcRoot, dstDB, force)
    if type(dstDB) ~= "table" then
        return false, "DynamicMarker settings are not ready yet.", nil
    end
    if not force and dstDB.migratedFromFocusMarker == true then
        return false, "Already migrated.", nil
    end
    if type(srcRoot) ~= "table" or next(srcRoot) == nil then
        return false, "No FocusMarker settings found.", nil
    end

    local sources = FM_CollectCandidateSources(srcRoot)
    if #sources == 0 then
        dstDB.migratedFromFocusMarker = true
        dstDB.focusMarkerBridgeVersion = FOCUSMARKER_BRIDGE_VERSION
        return false, "FocusMarker settings table was empty.", nil
    end

    local applied = {}
    local migratedFlags = { targetPos = false, flarePos = false }
    local function Mark(label)
        applied[#applied + 1] = label
    end

    -- 1. Bar Positions (Icon Bar & Flare Bar)
    local tPos = FM_ExtractBarPosition(sources,
        { "targetBarPos", "targetPosition", "targetPos", "iconBarPos", "barPos", "position", "pos" },
        { "targetBarPoint", "barPoint", "point" },
        { "targetBarRelPoint", "barRelPoint", "relPoint", "relativePoint" },
        { "targetBarX", "barX", "xOfs", "x" },
        { "targetBarY", "barY", "yOfs", "y" },
        -140)
    if tPos then
        dstDB.targetBarPoint    = tPos.point
        dstDB.targetBarRelPoint = tPos.relPoint
        dstDB.targetBarX        = tPos.x
        dstDB.targetBarY        = tPos.y
        dstDB.targetBarPos      = { point = tPos.point, relPoint = tPos.relPoint, x = tPos.x, y = tPos.y }
        migratedFlags.targetPos = true
        Mark("Icon bar position")
    end

    local fPos = FM_ExtractBarPosition(sources,
        { "flareBarPos", "flarePosition", "flarePos", "worldMarkerPos" },
        { "flareBarPoint", "flarePoint" },
        { "flareBarRelPoint", "flareRelPoint" },
        { "flareBarX", "flareX" },
        { "flareBarY", "flareY" },
        -182)
    if fPos then
        dstDB.flareBarPoint    = fPos.point
        dstDB.flareBarRelPoint = fPos.relPoint
        dstDB.flareBarX        = fPos.x
        dstDB.flareBarY        = fPos.y
        dstDB.flareBarPos      = { point = fPos.point, relPoint = fPos.relPoint, x = fPos.x, y = fPos.y }
        migratedFlags.flarePos = true
        Mark("Flare bar position")
    end

    -- 2. Scales & Opacity
    local tScale = FM_NormalizeScale(
        FM_ReadFirstValid(sources, { "targetBarScale", "iconBarScale", "barScale", "scale" }, IsFiniteNum),
        FM_ReadFirstValid(sources, { "iconSize", "buttonSize" }, IsFiniteNum)
    )
    if tScale then
        dstDB.targetBarScale = tScale
        Mark("Icon bar scale")
    end

    local fScale = FM_NormalizeScale(
        FM_ReadFirstValid(sources, { "flareBarScale", "flareScale", "worldMarkerScale" }, IsFiniteNum),
        FM_ReadFirstValid(sources, { "flareIconSize", "flareButtonSize" }, IsFiniteNum)
    )
    if fScale then
        dstDB.flareBarScale = fScale
        Mark("Flare bar scale")
    end

    local tOpacity = FM_NormalizeOpacity(
        FM_ReadFirstValid(sources, { "targetBarOpacity", "barOpacity", "opacity", "alpha" }, IsFiniteNum)
    )
    if tOpacity then
        dstDB.targetBarOpacity = tOpacity
        Mark("Icon bar opacity")
    end

    local fOpacity = FM_NormalizeOpacity(
        FM_ReadFirstValid(sources, { "flareBarOpacity", "flareOpacity", "flareAlpha" }, IsFiniteNum)
    )
    if fOpacity then
        dstDB.flareBarOpacity = fOpacity
        Mark("Flare bar opacity")
    end

    -- 3. Visibility Rules (Solo / Group / Always / Hidden) & Group Scope
    local rawScope = FM_ReadFirstValid(sources, { "groupScope", "markGroupMode", "groupMode", "visibilityMode" }, function(v)
        return type(v) == "string"
    end)
    local scopeMode, scopeCanon
    if rawScope then
        scopeMode, scopeCanon = NormalizeGroupScopeValue(rawScope)
        dstDB.groupScope = scopeCanon
        Mark("Group scope")
    end

    local rawTargetVis = FM_ReadFirstValid(sources, {
        "targetBarVisibility", "barVisibility", "iconBarVisibility", "visibility", "barVisible", "showBar", "showTargetBar",
    }, function(v)
        return type(v) == "string" or type(v) == "boolean" or type(v) == "number"
    end)
    if rawTargetVis ~= nil then
        local _, tCanon, wasSolo = NormalizeBarVisibilityValue(rawTargetVis)
        if type(rawTargetVis) == "boolean" and rawTargetVis == true and scopeMode == "all" then
            tCanon = "ALWAYS"
        end
        dstDB.targetBarVisibility = tCanon
        if wasSolo and not rawScope then
            dstDB.groupScope = "ALL"
        end
        Mark("Icon bar visibility")
    elseif scopeMode == "all" then
        dstDB.targetBarVisibility = "ALWAYS"
        Mark("Icon bar visibility")
    end

    local rawFlareVis = FM_ReadFirstValid(sources, {
        "flareBarVisibility", "flareVisibility", "flareVisible", "showFlareBar", "flareBarShown",
    }, function(v)
        return type(v) == "string" or type(v) == "boolean" or type(v) == "number"
    end)
    if rawFlareVis ~= nil then
        local _, fCanon = NormalizeBarVisibilityValue(rawFlareVis)
        if type(rawFlareVis) == "boolean" and rawFlareVis == true and scopeMode == "all" then
            fCanon = "ALWAYS"
        end
        dstDB.flareBarVisibility = fCanon
        Mark("Flare bar visibility")
    end

    -- 4. Orientation
    local tOrient = NormalizeOrientationValue(
        FM_ReadFirstValid(sources, { "targetBarOrientation", "barOrientation", "iconBarOrientation", "orientation" }, function(v)
            return type(v) == "string"
        end)
    )
    if tOrient then
        dstDB.targetBarOrientation = tOrient
        Mark("Icon bar orientation")
    end

    local fOrient = NormalizeOrientationValue(
        FM_ReadFirstValid(sources, { "flareBarOrientation", "flareOrientation", "worldMarkerOrientation", "orientation" }, function(v)
            return type(v) == "string"
        end)
    )
    if fOrient then
        dstDB.flareBarOrientation = fOrient
        Mark("Flare bar orientation")
    end

    -- 5. Icon & Flare Ordering and Toggles
    local rawIconOrder = FM_ReadFirstValid(sources, { "iconOrder", "targetOrder", "targetIconOrder", "raidIconOrder", "markerOrder" }, function(v)
        return type(v) == "table"
    end)
    if type(rawIconOrder) == "table" then
        local cleanIconOrder, hadIconOrder = SanitizePermutation1To8(rawIconOrder)
        if hadIconOrder then
            dstDB.iconOrder = cleanIconOrder
            Mark("Icon order")
        end
    end

    local rawFlareOrder = FM_ReadFirstValid(sources, { "flareOrder", "worldMarkerOrder", "flareIconOrder", "flaresOrder" }, function(v)
        return type(v) == "table"
    end)
    if type(rawFlareOrder) == "table" then
        local cleanFlareOrder, hadFlareOrder = SanitizePermutation1To8(rawFlareOrder)
        if hadFlareOrder then
            dstDB.flareOrder = cleanFlareOrder
            Mark("Flare order")
        end
    end

    local rawFlareEnabled = FM_ReadFirstValid(sources, { "flareEnabled", "enabledFlares", "activeFlares" }, function(v)
        return type(v) == "table"
    end)
    if type(rawFlareEnabled) == "table" then
        local fe = {}
        local foundAnyBool = false
        for i = 1, 8 do
            local v = rawFlareEnabled[i]
            if v == nil then v = rawFlareEnabled[tostring(i)] end
            if type(v) == "boolean" then
                fe[i] = v
                foundAnyBool = true
            else
                fe[i] = true
            end
        end
        if foundAnyBool then
            dstDB.flareEnabled = fe
            dstDB.flareEnabledAll8MigratedV2 = true
            Mark("Enabled flares")
        end
    end

    -- 6. Focus Icon, Chat Announce & Keybind / Macro Preferences
    local rawFocusIcon = FM_ReadFirstValid(sources, { "focusIcon", "preferredIcon", "defaultIcon", "raidIcon" }, IsFiniteNum)
    if rawFocusIcon then
        local idx = math.floor(rawFocusIcon + 0.5)
        if idx >= 1 and idx <= 8 then
            dstDB.focusIcon = idx
            Mark("Focus icon")
        end
    end

    local rawMuted = FM_ReadFirstValid(sources, { "isMuted" }, function(v) return type(v) == "boolean" end)
    local rawAnnounce = FM_ReadFirstValid(sources, { "chatAnnounce", "announce" }, function(v)
        return type(v) == "boolean" or type(v) == "string"
    end)
    if rawAnnounce ~= nil then
        if type(rawAnnounce) == "boolean" then
            dstDB.chatAnnounce = rawAnnounce and "ACTIVE" or "MUTED"
        elseif type(rawAnnounce) == "string" then
            local au = rawAnnounce:upper()
            dstDB.chatAnnounce = (au == "MUTED" or au == "OFF" or au == "FALSE") and "MUTED" or "ACTIVE"
        end
        Mark("Chat announce")
    elseif type(rawMuted) == "boolean" then
        dstDB.chatAnnounce = rawMuted and "MUTED" or "ACTIVE"
        Mark("Chat announce")
    end

    local rawChatChan = FM_ReadFirstValid(sources, { "chatChannel" }, function(v) return type(v) == "string" end)
    if rawChatChan then
        local cu = rawChatChan:upper()
        if cu == "PARTY" or cu == "SAY" or cu == "PARTY_INSTANCE" then
            dstDB.chatChannel = cu
            Mark("Chat channel")
        end
    end

    local rawClearMod = FM_ReadFirstValid(sources, { "focusClearModifier", "clearModifier", "modifier" }, function(v)
        return type(v) == "string"
    end)
    if rawClearMod then
        local mu = rawClearMod:upper()
        if mu == "SHIFT" or mu == "CTRL" or mu == "ALT" or mu == "NONE" then
            dstDB.focusClearModifier = mu
            Mark("Clear modifier")
        end
    end

    local rawCycleKey = FM_ReadFirstValid(sources, { "flareCycleKey", "cycleKey" }, function(v) return type(v) == "string" and v ~= "" end)
    if rawCycleKey then
        dstDB.flareCycleKey = rawCycleKey
        Mark("Flare cycle key")
    end

    local rawClearKey = FM_ReadFirstValid(sources, { "flareClearKey", "clearKey" }, function(v) return type(v) == "string" and v ~= "" end)
    if rawClearKey then
        dstDB.flareClearKey = rawClearKey
        Mark("Flare clear key")
    end

    local rawBorder = FM_ReadFirstValid(sources, { "hudBorderStyle", "borderStyle" }, function(v) return type(v) == "string" end)
    if rawBorder then
        local bu = rawBorder:upper()
        if bu == "ACCENT" or bu == "DARK" or bu == "NONE" then
            dstDB.hudBorderStyle = bu
            Mark("Border style")
        end
    end

    dstDB.migratedFromFocusMarker = true
    dstDB.focusMarkerBridgeVersion = FOCUSMARKER_BRIDGE_VERSION
    return true, applied, migratedFlags
end

function DM:InitDB()
    local existingDB = _G.DynamicMarkerDB
    if type(existingDB) ~= "table" then
        existingDB = {}
    end

    local hadSavedTargetPos = (existingDB.targetBarX ~= nil or existingDB.targetBarY ~= nil or type(existingDB.targetBarPos) == "table" or type(existingDB.targetPos) == "table")
    local hadSavedFlarePos  = (existingDB.flareBarX ~= nil or existingDB.flareBarY ~= nil or type(existingDB.flareBarPos) == "table" or type(existingDB.flarePos) == "table")

    -- One-Time FocusMarkerDB -> DynamicMarkerDB Migration Bridge (runs BEFORE fresh defaults)
    local didMigrateNow = false
    local migratedFlags = nil
    if existingDB.migratedFromFocusMarker ~= true and type(_G.FocusMarkerDB) == "table" and next(_G.FocusMarkerDB) ~= nil then
        local okMig, _, flags = self:RunOneTimeFocusMarkerMigration(_G.FocusMarkerDB, existingDB, false)
        if okMig then
            didMigrateNow = true
            migratedFlags = flags
            self._migratedFocusMarkerOnInit = true
        end
    end

    _G.DynamicMarkerDB = DeepCopyDefaults(DB_DEFAULTS, existingDB)
    self.db = _G.DynamicMarkerDB

    if type(self.db.migratedFromFocusMarker) ~= "boolean" then
        self.db.migratedFromFocusMarker = false
    end

    -- Ensure iconOrder and flareOrder have all 8 indices 1..8
    local cleanIcons = SanitizePermutation1To8(self.db.iconOrder)
    self.db.iconOrder = cleanIcons

    local cleanFlares = SanitizePermutation1To8(self.db.flareOrder)
    self.db.flareOrder = cleanFlares

    if type(self.db.flareEnabled) ~= "table" or not self.db.flareEnabledAll8MigratedV2 then
        self.db.flareEnabled = {
            [1] = true, [2] = true, [3] = true, [4] = true,
            [5] = true, [6] = true, [7] = true, [8] = true,
        }
        self.db.flareEnabledAll8MigratedV2 = true
    else
        for i = 1, 8 do
            if type(self.db.flareEnabled[i]) ~= "boolean" then
                self.db.flareEnabled[i] = true
            end
        end
    end

    if not self.db.kickPriorityMigratedV2 then
        if self.db.kickPriority == "MOUSEOVER_FOCUS_TARGET" or not self.db.kickPriority then
            self.db.kickPriority = "SMART_AUTOTARGET"
        elseif self.db.kickPriority == "FOCUS_MOUSEOVER_TARGET" then
            self.db.kickPriority = "FOCUS_MO_TARGET"
        end
        self.db.kickPriorityMigratedV2 = true
    end

    local _, targetCanon = NormalizeBarVisibilityValue(self.db.targetBarVisibility)
    self.db.targetBarVisibility = targetCanon
    local _, flareCanon = NormalizeBarVisibilityValue(self.db.flareBarVisibility)
    self.db.flareBarVisibility = flareCanon
    local _, scopeCanon = NormalizeGroupScopeValue(self.db.groupScope)
    self.db.groupScope = scopeCanon

    -- Normalize flat + nested position mirrors inside DynamicMarkerDB (canonical UIParent-local CENTER offsets)
    local tx = IsFiniteNum(self.db.targetBarX) and math.floor(self.db.targetBarX + 0.5)
        or (type(self.db.targetBarPos) == "table" and IsFiniteNum(self.db.targetBarPos.x) and math.floor(self.db.targetBarPos.x + 0.5))
        or 0
    local ty = IsFiniteNum(self.db.targetBarY) and math.floor(self.db.targetBarY + 0.5)
        or (type(self.db.targetBarPos) == "table" and IsFiniteNum(self.db.targetBarPos.y) and math.floor(self.db.targetBarPos.y + 0.5))
        or -140
    local tPt = SanitizeAnchorPoint(self.db.targetBarPoint or (type(self.db.targetBarPos) == "table" and self.db.targetBarPos.point), "CENTER")
    local tRp = SanitizeAnchorPoint(self.db.targetBarRelPoint or (type(self.db.targetBarPos) == "table" and self.db.targetBarPos.relPoint), tPt)

    local fx = IsFiniteNum(self.db.flareBarX) and math.floor(self.db.flareBarX + 0.5)
        or (type(self.db.flareBarPos) == "table" and IsFiniteNum(self.db.flareBarPos.x) and math.floor(self.db.flareBarPos.x + 0.5))
        or 0
    local fy = IsFiniteNum(self.db.flareBarY) and math.floor(self.db.flareBarY + 0.5)
        or (type(self.db.flareBarPos) == "table" and IsFiniteNum(self.db.flareBarPos.y) and math.floor(self.db.flareBarPos.y + 0.5))
        or -182
    local fPt = SanitizeAnchorPoint(self.db.flareBarPoint or (type(self.db.flareBarPos) == "table" and self.db.flareBarPos.point), "CENTER")
    local fRp = SanitizeAnchorPoint(self.db.flareBarRelPoint or (type(self.db.flareBarPos) == "table" and self.db.flareBarPos.relPoint), fPt)

    if not self.db.canonicalUIParentCoordsV199 then
        self.db.canonicalUIParentCoordsV199 = true
        if hadSavedTargetPos and tPt == "CENTER" and tRp == "CENTER" then
            local tScale = tonumber(self.db.targetBarScale) or tonumber(self.db.barScale) or 1.0
            if IsFiniteNum(tScale) and tScale > 0 and math.abs(tScale - 1.0) > 0.001 then
                tx = math.floor(tx * tScale + 0.5)
                ty = math.floor(ty * tScale + 0.5)
            end
        end
        if hadSavedFlarePos and fPt == "CENTER" and fRp == "CENTER" then
            local fScale = tonumber(self.db.flareBarScale) or 1.0
            if IsFiniteNum(fScale) and fScale > 0 and math.abs(fScale - 1.0) > 0.001 then
                fx = math.floor(fx * fScale + 0.5)
                fy = math.floor(fy * fScale + 0.5)
            end
        end
    end

    self.db.targetBarPoint    = tPt
    self.db.targetBarRelPoint = tRp
    self.db.targetBarX        = tx
    self.db.targetBarY        = ty
    self.db.targetBarPos      = { point = tPt, relPoint = tRp, x = tx, y = ty }

    self.db.flareBarPoint    = fPt
    self.db.flareBarRelPoint = fRp
    self.db.flareBarX        = fx
    self.db.flareBarY        = fy
    self.db.flareBarPos      = { point = fPt, relPoint = fRp, x = fx, y = fy }

    _G.DynamicSuiteDB = type(_G.DynamicSuiteDB) == "table" and _G.DynamicSuiteDB or {}
    _G.DynamicSuiteDB.global = DeepCopyDefaults(SUITE_GLOBAL_DEFAULTS, _G.DynamicSuiteDB.global)
    _G.DynamicSuiteDB.disabledModules = type(_G.DynamicSuiteDB.disabledModules) == "table" and _G.DynamicSuiteDB.disabledModules or {}
    self.suiteGlobal = _G.DynamicSuiteDB.global
    self.suiteGlobal.hudPositions = type(self.suiteGlobal.hudPositions) == "table" and self.suiteGlobal.hudPositions or {}

    -- Capture snapshot (read-only) once FocusMarkerDB is present
    if didMigrateNow and type(_G.FocusMarkerDB) == "table" and self.CaptureFocusMarkerSnapshot then
        pcall(self.CaptureFocusMarkerSnapshot, self)
    end

    -- Sync HUD coordinates between DynamicMarkerDB (authoritative) and DynamicSuiteDB.global.hudPositions
    local suiteGlobalScope = (_G.DynamicSuite and type(_G.DynamicSuite.GetSuiteGlobal) == "function") and _G.DynamicSuite.GetSuiteGlobal() or nil
    if type(suiteGlobalScope) == "table" then
        suiteGlobalScope.hudPositions = type(suiteGlobalScope.hudPositions) == "table" and suiteGlobalScope.hudPositions or {}
    end
    local hp = self.suiteGlobal.hudPositions
    local hpScope = (type(suiteGlobalScope) == "table") and suiteGlobalScope.hudPositions or nil
    local existingTarget = (hpScope and (hpScope["TARGET"] or hpScope["TargetBar"] or hpScope["target"] or hpScope["DynamicMarkerTargetBar"]))
        or hp["TARGET"] or hp["TargetBar"] or hp["target"] or hp["DynamicMarkerTargetBar"]
    if (not hadSavedTargetPos) and (not (didMigrateNow and migratedFlags and migratedFlags.targetPos))
        and type(existingTarget) == "table" and (tonumber(existingTarget.x) ~= nil or tonumber(existingTarget.y) ~= nil)
    then
        local mTx = (tonumber(existingTarget.x) ~= nil) and tonumber(existingTarget.x) or 0
        local mTy = (tonumber(existingTarget.y) ~= nil) and tonumber(existingTarget.y) or -140
        local mPt = SanitizeAnchorPoint(existingTarget.point, "CENTER")
        local mRp = SanitizeAnchorPoint(existingTarget.relPoint, mPt)
        local tEntry = { point = mPt, relPoint = mRp, x = mTx, y = mTy }
        hp["TARGET"]                 = tEntry
        hp["target"]                 = tEntry
        hp["TargetBar"]              = tEntry
        hp["DynamicMarkerTargetBar"] = tEntry
        if hpScope then
            hpScope["TARGET"]                 = tEntry
            hpScope["target"]                 = tEntry
            hpScope["TargetBar"]              = tEntry
            hpScope["DynamicMarkerTargetBar"] = tEntry
        end
        self.db.targetBarPoint    = mPt
        self.db.targetBarRelPoint = mRp
        self.db.targetBarX        = mTx
        self.db.targetBarY        = mTy
        self.db.targetBarPos      = { point = mPt, relPoint = mRp, x = mTx, y = mTy }
    else
        local tEntry = { point = tPt, relPoint = tRp, x = tx, y = ty }
        hp["TARGET"]                 = tEntry
        hp["target"]                 = tEntry
        hp["TargetBar"]              = tEntry
        hp["DynamicMarkerTargetBar"] = tEntry
        if hpScope then
            hpScope["TARGET"]                 = tEntry
            hpScope["target"]                 = tEntry
            hpScope["TargetBar"]              = tEntry
            hpScope["DynamicMarkerTargetBar"] = tEntry
        end
    end

    local existingFlare = (hpScope and (hpScope["FLARE"] or hpScope["FlareBar"] or hpScope["flare"] or hpScope["DynamicMarkerFlareBar"]))
        or hp["FLARE"] or hp["FlareBar"] or hp["flare"] or hp["DynamicMarkerFlareBar"]
    if (not hadSavedFlarePos) and (not (didMigrateNow and migratedFlags and migratedFlags.flarePos))
        and type(existingFlare) == "table" and (tonumber(existingFlare.x) ~= nil or tonumber(existingFlare.y) ~= nil)
    then
        local mFx = (tonumber(existingFlare.x) ~= nil) and tonumber(existingFlare.x) or 0
        local mFy = (tonumber(existingFlare.y) ~= nil) and tonumber(existingFlare.y) or -182
        local mPt = SanitizeAnchorPoint(existingFlare.point, "CENTER")
        local mRp = SanitizeAnchorPoint(existingFlare.relPoint, mPt)
        local fEntry = { point = mPt, relPoint = mRp, x = mFx, y = mFy }
        hp["FLARE"]                 = fEntry
        hp["flare"]                 = fEntry
        hp["FlareBar"]              = fEntry
        hp["DynamicMarkerFlareBar"] = fEntry
        if hpScope then
            hpScope["FLARE"]                 = fEntry
            hpScope["flare"]                 = fEntry
            hpScope["FlareBar"]              = fEntry
            hpScope["DynamicMarkerFlareBar"] = fEntry
        end
        self.db.flareBarPoint    = mPt
        self.db.flareBarRelPoint = mRp
        self.db.flareBarX        = mFx
        self.db.flareBarY        = mFy
        self.db.flareBarPos      = { point = mPt, relPoint = mRp, x = mFx, y = mFy }
    else
        local fEntry = { point = fPt, relPoint = fRp, x = fx, y = fy }
        hp["FLARE"]                 = fEntry
        hp["flare"]                 = fEntry
        hp["FlareBar"]              = fEntry
        hp["DynamicMarkerFlareBar"] = fEntry
        if hpScope then
            hpScope["FLARE"]                 = fEntry
            hpScope["flare"]                 = fEntry
            hpScope["FlareBar"]              = fEntry
            hpScope["DynamicMarkerFlareBar"] = fEntry
        end
    end
end

function DM:GetSetting(key)
    if not self.db then self:InitDB() end
    return self.db and self.db[key]
end

function DM:SetSetting(key, val)
    if not self.db then self:InitDB() end
    if self.db then
        self.db[key] = val
    end
end

-- ============================================================================
-- 4. STYLING & PIXEL-PERFECT OBSIDIAN HELPERS
-- ============================================================================

local COLORS = {
    BgVoid       = { r = 0.024, g = 0.027, b = 0.035, a = 0.98 }, -- #060709
    BgCanvas     = { r = 0.047, g = 0.055, b = 0.075, a = 0.98 }, -- #0C0E13
    BgTabCell    = { r = 0.063, g = 0.075, b = 0.102, a = 1.00 }, -- #10131A
    BgSurface    = { r = 0.071, g = 0.082, b = 0.110, a = 1.00 }, -- #12151C
    BgElevated   = { r = 0.102, g = 0.118, b = 0.153, a = 1.00 }, -- #1A1E27
    BgHover      = { r = 0.145, g = 0.168, b = 0.215, a = 1.00 }, -- #252B37
    BorderDim    = { r = 1.000, g = 1.000, b = 1.000, a = 0.08 },
    BorderStrong = { r = 1.000, g = 1.000, b = 1.000, a = 0.15 },
    TextPrimary  = { r = 0.953, g = 0.961, b = 0.973, a = 1.00 }, -- #F3F5F8
    TextSilver   = { r = 0.796, g = 0.835, b = 0.882, a = 1.00 }, -- #CBD5E1
    TextMuted    = { r = 0.580, g = 0.639, b = 0.722, a = 1.00 }, -- #94A3B8
    Cyan         = { r = 0.220, g = 0.741, b = 0.973, a = 1.00 }, -- #38BDF8
    Green        = { r = 0.133, g = 0.773, b = 0.369, a = 1.00 }, -- #22C55E
    Amber        = { r = 0.961, g = 0.620, b = 0.043, a = 1.00 }, -- #F59E0B
    Red          = { r = 0.973, g = 0.443, b = 0.443, a = 1.00 }, -- #F87171
}
DM.COLORS = COLORS

local function SanitizeHex6(hex, r, g, b)
    if type(hex) == "string" and hex ~= "" then
        local clean = hex:gsub("^|c", ""):gsub("^#", "")
        if #clean == 8 then
            clean = clean:sub(3, 8)
        end
        if #clean == 6 and clean:match("^%x%x%x%x%x%x$") then
            return clean:upper()
        end
    end
    local ri = math.max(0, math.min(255, math.floor((tonumber(r) or 0.8) * 255 + 0.5)))
    local gi = math.max(0, math.min(255, math.floor((tonumber(g) or 0.84) * 255 + 0.5)))
    local bi = math.max(0, math.min(255, math.floor((tonumber(b) or 0.88) * 255 + 0.5)))
    return string.format("%02X%02X%02X", ri, gi, bi)
end

function DM:GetAccentColor()
    if Suite and type(Suite.GetSuiteAccent) == "function" then
        local ok, r, g, b, hex = pcall(Suite.GetSuiteAccent, Suite)
        if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return r, g, b, SanitizeHex6(hex, r, g, b)
        elseif ok and type(r) == "table" then
            local tr = tonumber(r.r or r[1]) or 0.961
            local tg = tonumber(r.g or r[2]) or 0.722
            local tb = tonumber(r.b or r[3]) or 0.180
            return tr, tg, tb, SanitizeHex6(r.hex, tr, tg, tb)
        end
    end
    local gTbl = self.suiteGlobal or (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global)
    local accentKey = gTbl and gTbl.accentKey
    if accentKey == "CUSTOM" and type(gTbl.customAccent) == "table" then
        local r = tonumber(gTbl.customAccent.r) or 0.961
        local g = tonumber(gTbl.customAccent.g) or 0.722
        local b = tonumber(gTbl.customAccent.b) or 0.180
        return r, g, b, SanitizeHex6(nil, r, g, b)
    elseif accentKey == "AUTO_CLASS" then
        local _, classFile = UnitClass("player")
        local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
        if c then
            return c.r, c.g, c.b, SanitizeHex6(c.colorStr, c.r, c.g, c.b)
        end
    elseif accentKey == "ALERT_GOLD" then
        local p = THEME_PRESETS.GOLD
        return p.r, p.g, p.b, p.hex
    elseif accentKey == "ASTRAL_COBALT" then
        return 0.376, 0.647, 0.980, "60A5FA"
    elseif accentKey == "EMERALD_MINT" then
        return 0.063, 0.725, 0.506, "10B981"
    elseif accentKey == "OBSIDIAN_SLATE" then
        local p = THEME_PRESETS.OBSIDIAN
        return p.r, p.g, p.b, p.hex
    elseif type(accentKey) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[accentKey] then
        local c = RAID_CLASS_COLORS[accentKey]
        return c.r, c.g, c.b, SanitizeHex6(c.colorStr, c.r, c.g, c.b)
    end
    local themeKey = (self.suiteGlobal and self.suiteGlobal.theme) or "GOLD"
    local preset = THEME_PRESETS[themeKey] or THEME_PRESETS.GOLD
    if preset.isClass then
        local _, classFile = UnitClass("player")
        local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
        if c then
            return c.r, c.g, c.b, SanitizeHex6(c.colorStr or preset.hex, c.r, c.g, c.b)
        end
    end
    return preset.r, preset.g, preset.b, SanitizeHex6(preset.hex, preset.r, preset.g, preset.b)
end

function DM:GetAccentColorTable(alpha)
    local r, g, b = self:GetAccentColor()
    return { r = r, g = g, b = b, a = alpha or 1.0 }
end

function DM:GetPixelSize(frame, pixels)
    pixels = pixels or 1
    if PixelUtil and PixelUtil.GetNearestPixelSize then
        local scale = (frame and frame.GetEffectiveScale and frame:GetEffectiveScale()) or UIParent:GetEffectiveScale() or 1
        if scale <= 0 then scale = 1 end
        return PixelUtil.GetNearestPixelSize(pixels, scale)
    end
    return pixels
end

function DM:ApplyBackdrop(frame, bgColor, borderColor, edgePixels)
    if not frame or not frame.SetBackdrop then return end
    local px = self:GetPixelSize(frame, edgePixels or 1)
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = px,
        insets   = { left = px, right = px, top = px, bottom = px },
    })
    local bg = bgColor or COLORS.BgSurface
    local bd = borderColor or COLORS.BorderDim
    frame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 1)
    frame:SetBackdropBorderColor(bd.r, bd.g, bd.b, bd.a or 1)
end

local dmFontProbeFS = nil
local dmFontProbeCache = {}
local dmStyledFontStrings = setmetatable({}, { __mode = "k" })
local dmStandaloneFonts = { scanned = false, options = {}, byKey = {} }

local function CanSetDMFontPath(path)
    if type(path) ~= "string" or path == "" then return false end
    if dmFontProbeCache[path] ~= nil then return dmFontProbeCache[path] end
    if not dmFontProbeFS and UIParent and UIParent.CreateFontString then
        dmFontProbeFS = UIParent:CreateFontString(nil, "BACKGROUND")
        dmFontProbeFS:Hide()
    end
    if not dmFontProbeFS then return false end
    local ok, applied = pcall(dmFontProbeFS.SetFont, dmFontProbeFS, path, 12, "")
    local fetched = ok and dmFontProbeFS:GetFont() or nil
    local valid = (ok and applied ~= false and fetched ~= nil)
    dmFontProbeCache[path] = valid
    return valid
end

function DM:ScanStandaloneFonts(force)
    if dmStandaloneFonts.scanned and not force then
        return dmStandaloneFonts
    end

    local builtinList = {
        { value = "EXPRESSWAY",      label = "Expressway",          path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.ttf" },
        { value = "EXPRESSWAY_BOLD", label = "Expressway Bold",     path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway Bold.ttf" },
        { value = "EXPRESSWAY_CAPS", label = "Expressway CAPS",     path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway CAPS.ttf" },
        { value = "POPPINS",         label = "Poppins",             path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Poppins.ttf" },
        { value = "FIRA_SANS",       label = "Fira Sans",           path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Medium.ttf" },
        { value = "UBUNTU",          label = "Ubuntu",              path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Ubuntu.ttf" },
    }
    local blizzardList = {
        { value = "FRIZ_QUADRATA", label = "Friz Quadrata",           path = "Fonts\\FRIZQT__.TTF" },
        { value = "MODERN_SANS",   label = "2002",                    path = "Fonts\\2002.TTF" },
        { value = "BLIZZ_2002B",   label = "2002 Bold",               path = "Fonts\\2002B.TTF" },
        { value = "BLIZZ_ARIALN",  label = "Arial Narrow (Blizzard)", path = "Fonts\\ARIALN.TTF" },
        { value = "RPG_SERIF",     label = "Morpheus",                path = "Fonts\\MORPHEUS.TTF" },
        { value = "BLIZZ_SKURRI",  label = "Skurri",                  path = "Fonts\\SKURRI.TTF" },
    }

    local byKey = {}
    local seenPaths = {}
    local seenNames = {}
    local opts = {}

    local validBuiltin = {}
    for _, item in ipairs(builtinList) do
        if CanSetDMFontPath(item.path) then
            item.fontPath = item.path
            byKey[item.value] = item
            byKey[item.label] = item
            seenPaths[item.path:lower():gsub("/", "\\")] = true
            seenNames[item.label:lower()] = true
            table.insert(validBuiltin, item)
        end
    end
    if #validBuiltin > 0 then
        table.insert(opts, { isHeader = true, label = "BUILT-IN FONTS" })
        for _, item in ipairs(validBuiltin) do
            table.insert(opts, item)
        end
    end

    local validBlizz = {}
    for _, item in ipairs(blizzardList) do
        if CanSetDMFontPath(item.path) then
            item.fontPath = item.path
            byKey[item.value] = item
            byKey[item.label] = item
            seenPaths[item.path:lower():gsub("/", "\\")] = true
            seenNames[item.label:lower()] = true
            table.insert(validBlizz, item)
        end
    end
    if #validBlizz > 0 then
        table.insert(opts, { isHeader = true, label = "BLIZZARD" })
        for _, item in ipairs(validBlizz) do
            table.insert(opts, item)
        end
    end

    local extItems = {}
    local function TryAddExternalFont(prefix, rawName, rawPath, srcTag)
        if type(rawName) ~= "string" or type(rawPath) ~= "string" or rawName == "" or rawPath == "" then return end
        local cleanName = rawName:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if cleanName == "" or not CanSetDMFontPath(rawPath) then return end
        local normP = rawPath:lower():gsub("/", "\\")
        local normN = cleanName:lower()
        if seenPaths[normP] or seenNames[normN] then return end
        seenPaths[normP] = true
        seenNames[normN] = true
        local key = prefix .. ":" .. cleanName
        local entry = {
            value    = key,
            label    = srcTag and (cleanName .. " (" .. srcTag .. ")") or cleanName,
            name     = cleanName,
            path     = rawPath,
            fontPath = rawPath,
            source   = srcTag or "SharedMedia",
        }
        byKey[key] = entry
        byKey[cleanName] = entry
        table.insert(extItems, entry)
    end

    local LSM = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
    if LSM then
        if type(LSM.HashTable) == "function" then
            local okH, hTbl = pcall(LSM.HashTable, LSM, "font")
            if okH and type(hTbl) == "table" then
                for kName, kPath in pairs(hTbl) do
                    TryAddExternalFont("LSM", kName, kPath, "SharedMedia")
                end
            end
        end
        if type(LSM.List) == "function" and type(LSM.Fetch) == "function" then
            local okL, listTbl = pcall(LSM.List, LSM, "font")
            if okL and type(listTbl) == "table" then
                for _, lName in ipairs(listTbl) do
                    local okF, fPath = pcall(LSM.Fetch, LSM, "font", lName, true)
                    if okF and fPath then
                        TryAddExternalFont("LSM", lName, fPath, "SharedMedia")
                    end
                end
            end
        end
    end

    local function ScanAddonFontTable(tbl, prefix, srcTag)
        if type(tbl) ~= "table" then return end
        for k, v in pairs(tbl) do
            if type(v) == "table" then
                local nm = v.text or v.name or v.label or (type(k) == "string" and k) or nil
                local fp = v.path or v.font or v.value
                TryAddExternalFont(prefix, nm and tostring(nm) or nil, fp, srcTag)
            elseif type(k) == "string" and type(v) == "string" and v:find("[\\/]") then
                TryAddExternalFont(prefix, k, v, srcTag)
            elseif type(v) == "string" and type(k) == "string" and k:find("[\\/]") then
                TryAddExternalFont(prefix, v, k, srcTag)
            end
        end
    end

    if type(_G.DBM) == "table" then
        ScanAddonFontTable(_G.DBM.Fonts, "DBM", "DBM")
        ScanAddonFontTable(_G.DBM.Font, "DBM", "DBM")
    end
    if type(_G.WeakAuras) == "table" then
        ScanAddonFontTable(_G.WeakAuras.fonts or _G.WeakAuras.Fonts, "WA", "WeakAuras")
    end
    if type(_G.ElvUI) == "table" and _G.ElvUI[1] then
        local E = _G.ElvUI[1]
        if E.Media and type(E.Media.Fonts) == "table" then
            ScanAddonFontTable(E.Media.Fonts, "ELV", "ElvUI")
        end
    end

    if #extItems > 0 then
        table.sort(extItems, function(a, b) return (a.name or a.label):lower() < (b.name or b.label):lower() end)
        table.insert(opts, { isHeader = true, label = "SHAREDMEDIA / ADDONS" })
        for _, item in ipairs(extItems) do
            table.insert(opts, item)
        end
    end

    dmStandaloneFonts.options = opts
    dmStandaloneFonts.byKey = byKey
    dmStandaloneFonts.scanned = true
    return dmStandaloneFonts
end

function DM:GetAvailableFonts(force)
    local sharedUI = _G.DynamicSuite and _G.DynamicSuite.UI
    if sharedUI and type(sharedUI.BuildFontDropdownOptions) == "function" then
        local rawOpts = sharedUI.BuildFontDropdownOptions(force)
        local out = {}
        for _, opt in ipairs(rawOpts or {}) do
            if opt.isHeader then
                table.insert(out, { isHeader = true, label = opt.label })
            elseif opt.value then
                local fPath = (type(sharedUI.GetFont) == "function" and sharedUI.GetFont(opt.fontKey or opt.value)) or nil
                table.insert(out, {
                    value    = opt.value,
                    label    = opt.label,
                    fontPath = fPath,
                })
            end
        end
        return out
    end
    local reg = self:ScanStandaloneFonts(force)
    return reg.options
end

function DM:GetActiveFontKeySafe()
    local sharedUI = _G.DynamicSuite and _G.DynamicSuite.UI
    if sharedUI and type(sharedUI.GetActiveFontKey) == "function" then
        return sharedUI.GetActiveFontKey()
    end
    local g = self.suiteGlobal or {}
    local key = g.fontKey or g.fontFamily or "EXPRESSWAY"
    local reg = self:ScanStandaloneFonts(false)
    local hit = reg.byKey[key]
    if not hit and type(key) == "string" then
        local stripped = key:gsub("^LSM:", ""):gsub("^DBM:", ""):gsub("^BW:", ""):gsub("^WA:", ""):gsub("^ELV:", "")
        hit = reg.byKey[stripped]
    end
    if hit and CanSetDMFontPath(hit.path) then
        return hit.value
    end
    if reg.byKey["EXPRESSWAY"] and CanSetDMFontPath(reg.byKey["EXPRESSWAY"].path) then
        return "EXPRESSWAY"
    end
    return "FRIZ_QUADRATA"
end

function DM:ResolveStandaloneFontPath(fontKeyOverride)
    local sharedUI = _G.DynamicSuite and _G.DynamicSuite.UI
    if sharedUI and type(sharedUI.GetFont) == "function" then
        local p = sharedUI.GetFont(fontKeyOverride)
        if p then return p end
    end
    local key = fontKeyOverride or (self.suiteGlobal and (self.suiteGlobal.fontKey or self.suiteGlobal.fontFamily)) or "EXPRESSWAY"
    local reg = self:ScanStandaloneFonts(false)
    local hit = reg.byKey[key]
    if not hit and type(key) == "string" then
        local stripped = key:gsub("^LSM:", ""):gsub("^DBM:", ""):gsub("^BW:", ""):gsub("^WA:", ""):gsub("^ELV:", "")
        hit = reg.byKey[stripped]
    end
    if hit and CanSetDMFontPath(hit.path) then
        return hit.path
    end
    local bundledExpressway = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.ttf"
    if CanSetDMFontPath(bundledExpressway) then
        return bundledExpressway
    end
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

function DM:ApplyAllStandaloneFonts()
    local fontPath = self:ResolveStandaloneFontPath()
    local scale = (self.suiteGlobal and self.suiteGlobal.fontScale) or 1.0
    local defaultOutline = (self.suiteGlobal and self.suiteGlobal.fontOutline) or ""
    for fs in pairs(dmStyledFontStrings) do
        if fs and fs.SetFont and not fs._dmIsDropdownPreview then
            local baseSize = fs._dmFontBaseSize or 12
            local outline = fs._dmFontFlags
            if outline == nil then outline = defaultOutline end
            local finalSize = math.max(9, math.floor(baseSize * scale + 0.5))
            local ok, applied = pcall(fs.SetFont, fs, fontPath, finalSize, outline)
            if not ok or applied == false or not fs:GetFont() then
                pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", finalSize, outline)
            end
        end
    end
end

function DM:StyleFont(fs, size, flags, colorTable)
    if not fs then return end
    fs._dmFontBaseSize = size or fs._dmFontBaseSize or 12
    fs._dmFontFlags = flags
    if not fs._dmIsDropdownPreview then
        dmStyledFontStrings[fs] = true
    end
    local fontPath = (fs._dmCustomFontPath and CanSetDMFontPath(fs._dmCustomFontPath) and fs._dmCustomFontPath) or self:ResolveStandaloneFontPath()
    local scale = (self.suiteGlobal and self.suiteGlobal.fontScale) or 1.0
    local outline = flags
    if outline == nil then
        outline = (self.suiteGlobal and self.suiteGlobal.fontOutline) or ""
    end
    local finalSize = math.max(9, math.floor((size or 12) * scale + 0.5))
    local ok, applied = pcall(fs.SetFont, fs, fontPath, finalSize, outline)
    if not ok or applied == false or not fs:GetFont() then
        pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", finalSize, outline)
    end
    fs:SetShadowColor(0, 0, 0, 0.6)
    fs:SetShadowOffset(1, -1)
    if colorTable then
        fs:SetTextColor(colorTable.r, colorTable.g, colorTable.b, colorTable.a or 1)
    end
end

function DM:CreateButton(parent, text, width, height, onClick, isAccent)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    local baseW = width or 120
    btn.minWidth = baseW
    btn.isAccent = not not isAccent
    btn:SetSize(baseW, height or 28)

    local function RefreshBtnColors(hovered)
        local ar, ag, ab = self:GetAccentColor()
        if btn.isAccent then
            if hovered then
                self:ApplyBackdrop(btn, { r = ar * 0.35, g = ag * 0.35, b = ab * 0.35, a = 1 }, { r = ar, g = ag, b = ab, a = 0.95 })
            else
                self:ApplyBackdrop(btn, { r = ar * 0.22, g = ag * 0.22, b = ab * 0.22, a = 1 }, { r = ar, g = ag, b = ab, a = 0.70 })
            end
        else
            if hovered then
                self:ApplyBackdrop(btn, COLORS.BgHover, { r = ar, g = ag, b = ab, a = 0.65 })
            else
                self:ApplyBackdrop(btn, COLORS.BgElevated, COLORS.BorderStrong)
            end
        end
    end

    btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.Text:SetPoint("LEFT", btn, "LEFT", 6, 0)
    btn.Text:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    btn.Text:SetJustifyH("CENTER")
    btn.Text:SetWordWrap(false)
    self:StyleFont(btn.Text, 11, "", COLORS.TextPrimary)
    btn.Text:SetText(text or "")
    if text and text ~= "" and baseW >= 72 then
        local strW = (btn.Text.GetUnboundedStringWidth and btn.Text:GetUnboundedStringWidth()) or btn.Text:GetStringWidth() or 0
        if strW > 0 then
            btn:SetWidth(math.max(baseW, math.ceil(strW + 24)))
        end
    end

    btn.RefreshStyle = RefreshBtnColors
    RefreshBtnColors(false)

    btn:SetScript("OnEnter", function(s)
        RefreshBtnColors(true)
        if s.tooltipText then
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText(s.tooltipTitle or text or "DynamicMarker", 1, 1, 1)
            GameTooltip:AddLine(s.tooltipText, 0.8, 0.85, 0.92, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function()
        RefreshBtnColors(false)
        if GameTooltip:IsOwned(btn) then GameTooltip:Hide() end
    end)
    if onClick then
        btn:SetScript("OnClick", onClick)
    end

    function btn:SetLabel(newText)
        self.Text:SetText(newText or "")
        if newText and newText ~= "" and (self.minWidth or 120) >= 72 then
            local strW = (self.Text.GetUnboundedStringWidth and self.Text:GetUnboundedStringWidth()) or self.Text:GetStringWidth() or 0
            if strW > 0 then
                self:SetWidth(math.max(self.minWidth or 120, math.ceil(strW + 28)))
            end
        end
    end

    return btn
end

function DM:CreateEditHudButton(parent, onClick, isActiveFn)
    local btn = self:CreateButton(parent, "Edit HUD", 86, 22, onClick, false)
    btn.minWidth = 82
    btn:SetWidth(86)
    btn.isEditHudButton = true

    local function RefreshEditHudStyle(hovered)
        local active = (isActiveFn and isActiveFn()) or (DM.isEditMode == true)
        if active then
            DM:ApplyBackdrop(btn, { r = 0.22, g = 0.10, b = 0.025, a = 0.98 }, { r = 0.976, g = 0.451, b = 0.086, a = 1.0 }, 1)
        elseif hovered then
            DM:ApplyBackdrop(btn, { r = 0.16, g = 0.08, b = 0.02, a = 0.98 }, { r = 0.976, g = 0.451, b = 0.086, a = 1.0 }, 1)
        else
            DM:ApplyBackdrop(btn, { r = 0.043, g = 0.051, b = 0.071, a = 0.96 }, { r = 0.976, g = 0.451, b = 0.086, a = 0.85 }, 1)
        end
        if btn.Text then
            DM:StyleFont(btn.Text, 11, "", { r = 0.976, g = 0.984, b = 1.0, a = 1.0 })
        end
    end

    btn.RefreshStyle = RefreshEditHudStyle
    btn:SetScript("OnEnter", function(s)
        RefreshEditHudStyle(true)
        if s.tooltipText then
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText(s.tooltipTitle or "Edit HUD", 1, 1, 1)
            GameTooltip:AddLine(s.tooltipText, 0.8, 0.85, 0.92, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(s)
        RefreshEditHudStyle(false)
        if GameTooltip:IsOwned(s) then GameTooltip:Hide() end
    end)
    function btn:SetLabel(newText)
        self.Text:SetText(newText or "")
        local strW = (self.Text.GetUnboundedStringWidth and self.Text:GetUnboundedStringWidth()) or self.Text:GetStringWidth() or 0
        self:SetWidth(math.max(82, math.ceil((strW > 0 and strW or 48) + 22)))
        RefreshEditHudStyle(false)
    end
    RefreshEditHudStyle(false)
    return btn
end

-- ============================================================================
-- 5. DROPDOWN POPOVER & DIRECTION A SEGMENTED PILL ENGINES (ZERO TAINT)
-- ============================================================================

local activeDropdownMenu

local function StripOptionPrefix(str)
    if type(str) ~= "string" then return tostring(str or "") end
    return (str:gsub("^%d+%.%s*", ""):gsub("^%*%s*", ""))
end

function DM:CloseDropdownMenu()
    if activeDropdownMenu and activeDropdownMenu:IsShown() then
        activeDropdownMenu:Hide()
    end
    if self.editInspector and self.editInspector.selectorPopup and self.editInspector.selectorPopup:IsShown() then
        self.editInspector.selectorPopup:Hide()
    elseif _G.DynamicMarkerHudSelectorPopup and _G.DynamicMarkerHudSelectorPopup:IsShown() then
        _G.DynamicMarkerHudSelectorPopup:Hide()
    end
end

local function RegisterMarkerPopupCloser()
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.RegisterPopupCloser) == "function" then
        pcall(_G.DynamicSuite.UI.RegisterPopupCloser, "DynamicMarker", function() DM:CloseDropdownMenu() end)
    end
end
RegisterMarkerPopupCloser()

local function EnsureDMUISpecialFrame(frameName)
    if type(UISpecialFrames) ~= "table" or not frameName then return end
    for i = 1, #UISpecialFrames do
        if UISpecialFrames[i] == frameName then
            return
        end
    end
    table.insert(UISpecialFrames, frameName)
end

function DM:CreateDropdown(parent, width, options, getter, setter, onBeforeOpen)
    local dd = CreateFrame("Button", nil, parent, "BackdropTemplate")
    dd:SetSize(width or 240, 26)
    self:ApplyBackdrop(dd, COLORS.BgElevated, COLORS.BorderStrong)

    dd.Text = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dd.Text:SetPoint("LEFT", dd, "LEFT", 10, 0)
    dd.Text:SetPoint("RIGHT", dd, "RIGHT", -24, 0)
    dd.Text:SetJustifyH("LEFT")
    dd.Text:SetWordWrap(false)
    self:StyleFont(dd.Text, 12, "", COLORS.TextPrimary)

    dd.Chevron = dd:CreateTexture(nil, "OVERLAY")
    dd.Chevron:SetSize(12, 12)
    dd.Chevron:SetPoint("RIGHT", dd, "RIGHT", -8, 0)
    dd.Chevron:SetTexture(ICON_CHEVRON_DOWN)
    dd.Chevron:SetVertexColor(COLORS.TextSilver.r, COLORS.TextSilver.g, COLORS.TextSilver.b, 0.95)

    function dd:SetOptions(newOpts)
        options = newOpts or {}
        self:RefreshValue()
    end

    function dd:RefreshValue()
        local val = getter()
        local foundLabel = StripOptionPrefix(tostring(val))
        for _, opt in ipairs(options or {}) do
            if not opt.isHeader and not opt.isEmptyNotice and opt.value == val then
                foundLabel = StripOptionPrefix(opt.label)
                break
            end
        end
        self.Text:SetText(foundLabel)
        if activeDropdownMenu and activeDropdownMenu:IsShown() and activeDropdownMenu.owner == self then
            self.Chevron:SetTexture(ICON_CHEVRON_UP)
        else
            self.Chevron:SetTexture(ICON_CHEVRON_DOWN)
        end
    end

    dd:SetScript("OnEnter", function(s)
        local ar, ag, ab = DM:GetAccentColor()
        DM:ApplyBackdrop(s, COLORS.BgHover, { r = ar, g = ag, b = ab, a = 0.75 })
        s.Chevron:SetVertexColor(ar, ag, ab, 1.0)
    end)
    dd:SetScript("OnLeave", function(s)
        DM:ApplyBackdrop(s, COLORS.BgElevated, COLORS.BorderStrong)
        s.Chevron:SetVertexColor(COLORS.TextSilver.r, COLORS.TextSilver.g, COLORS.TextSilver.b, 0.95)
    end)

    if not dd._dmOnHideHooked then
        dd._dmOnHideHooked = true
        dd:HookScript("OnHide", function(s)
            if activeDropdownMenu and activeDropdownMenu.owner == s then
                activeDropdownMenu:Hide()
            end
        end)
    end

    dd:SetScript("OnClick", function(s)
        RegisterMarkerPopupCloser()
        if onBeforeOpen then
            local updated = onBeforeOpen(s)
            if type(updated) == "table" then
                options = updated
            end
        end

        if not activeDropdownMenu then
            activeDropdownMenu = CreateFrame("Frame", "DynamicMarkerDropdownPopover", UIParent, "BackdropTemplate")
            activeDropdownMenu:SetFrameStrata("TOOLTIP")
            activeDropdownMenu:SetFrameLevel(220)
            activeDropdownMenu:SetToplevel(true)
            activeDropdownMenu:SetClampedToScreen(true)
            activeDropdownMenu:EnableMouse(true)
            activeDropdownMenu.rows = {}
            EnsureDMUISpecialFrame("DynamicMarkerDropdownPopover")

            local searchWrap = CreateFrame("Frame", nil, activeDropdownMenu, "BackdropTemplate")
            searchWrap:SetHeight(24)
            searchWrap:SetPoint("TOPLEFT", activeDropdownMenu, "TOPLEFT", 6, -5)
            searchWrap:SetPoint("TOPRIGHT", activeDropdownMenu, "TOPRIGHT", -6, -5)
            searchWrap:SetFrameLevel(224)
            DM:ApplyBackdrop(searchWrap, { r = 0.035, g = 0.042, b = 0.060, a = 0.98 }, COLORS.BorderStrong)
            activeDropdownMenu.searchWrap = searchWrap

            local sb = CreateFrame("EditBox", nil, searchWrap)
            sb:SetFrameLevel(225)
            sb:SetPoint("TOPLEFT", searchWrap, "TOPLEFT", 8, -2)
            sb:SetPoint("BOTTOMRIGHT", searchWrap, "BOTTOMRIGHT", -24, 2)
            sb:SetAutoFocus(false)
            sb:SetMaxLetters(64)
            DM:StyleFont(sb, 11, "", COLORS.TextPrimary)
            activeDropdownMenu.searchBox = sb

            local ph = searchWrap:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            ph:SetPoint("LEFT", sb, "LEFT", 0, 0)
            DM:StyleFont(ph, 11, "", COLORS.TextMuted)
            ph:SetText("Search...")
            activeDropdownMenu.searchPlaceholder = ph

            local clrBtn = CreateFrame("Button", nil, searchWrap)
            clrBtn:SetSize(18, 18)
            clrBtn:SetPoint("RIGHT", searchWrap, "RIGHT", -3, 0)
            clrBtn:SetFrameLevel(226)
            local clrTxt = clrBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            clrTxt:SetPoint("CENTER", 0, 0)
            DM:StyleFont(clrTxt, 10, "", COLORS.TextSilver)
            clrTxt:SetText("X")
            clrBtn.txt = clrTxt
            clrBtn:Hide()
            clrBtn:SetScript("OnClick", function()
                sb:SetText("")
                sb:ClearFocus()
            end)
            activeDropdownMenu.searchClear = clrBtn

            sb:SetScript("OnEscapePressed", function()
                activeDropdownMenu:Hide()
            end)

            local sf = CreateFrame("ScrollFrame", nil, activeDropdownMenu)
            sf:SetFrameLevel(222)
            sf:SetClipsChildren(true)
            sf:EnableMouseWheel(true)
            activeDropdownMenu.scrollFrame = sf

            local sc = CreateFrame("Frame", nil, sf)
            sc:SetFrameLevel(223)
            sc:SetSize(240, 100)
            sf:SetScrollChild(sc)
            activeDropdownMenu.scrollChild = sc

            local sbTrack = CreateFrame("Frame", nil, activeDropdownMenu)
            sbTrack:SetFrameLevel(224)
            sbTrack:SetWidth(4)
            sbTrack:EnableMouse(true)
            sbTrack.bg = sbTrack:CreateTexture(nil, "ARTWORK")
            sbTrack.bg:SetAllPoints(sbTrack)
            sbTrack.bg:SetColorTexture(1, 1, 1, 0.06)
            activeDropdownMenu.sbTrack = sbTrack

            local sbThumb = CreateFrame("Button", nil, sbTrack)
            sbThumb:SetFrameLevel(225)
            sbThumb:SetSize(4, 32)
            sbThumb:SetPoint("TOP", sbTrack, "TOP", 0, 0)
            sbThumb:EnableMouse(true)
            sbThumb.bg = sbThumb:CreateTexture(nil, "OVERLAY")
            sbThumb.bg:SetAllPoints(sbThumb)
            sbThumb.bg:SetColorTexture(0.38, 0.45, 0.56, 0.85)
            activeDropdownMenu.sbThumb = sbThumb

            local borderOverlay = CreateFrame("Frame", nil, activeDropdownMenu, "BackdropTemplate")
            borderOverlay:SetAllPoints(activeDropdownMenu)
            borderOverlay:SetFrameLevel(230)
            activeDropdownMenu.borderOverlay = borderOverlay

            local function RefreshMenuThumbColor()
                if sbThumb.isDragging then
                    local r2, g2, b2 = DM:GetAccentColor()
                    sbThumb.bg:SetColorTexture(r2, g2, b2, 0.95)
                elseif sbThumb:IsMouseOver() then
                    sbThumb.bg:SetColorTexture(0.52, 0.60, 0.72, 0.95)
                else
                    sbThumb.bg:SetColorTexture(0.38, 0.45, 0.56, 0.85)
                end
            end

            local function UpdateMenuThumb()
                local maxScroll = math.max(0, (sc:GetHeight() or 0) - (sf:GetHeight() or 0))
                if maxScroll <= 1 then
                    sbTrack:Hide()
                    sbThumb:Hide()
                    sf:SetVerticalScroll(0)
                    return
                end
                sbTrack:Show()
                sbThumb:Show()
                local trackH = math.max(20, sbTrack:GetHeight() or 180)
                local ratio = math.min(1, (sf:GetHeight() or 1) / math.max(1, sc:GetHeight() or 1))
                local thumbH = math.max(24, math.floor(trackH * ratio))
                sbThumb:SetSize(4, thumbH)
                local cur = math.min(maxScroll, math.max(0, sf:GetVerticalScroll() or 0))
                local travel = math.max(1, trackH - thumbH)
                sbThumb:ClearAllPoints()
                sbThumb:SetPoint("TOP", sbTrack, "TOP", 0, -(cur / maxScroll) * travel)
                RefreshMenuThumbColor()
            end
            activeDropdownMenu.UpdateMenuThumb = UpdateMenuThumb

            sf:SetScript("OnMouseWheel", function(sFrame, delta)
                local maxScroll = math.max(0, sc:GetHeight() - sFrame:GetHeight())
                local nextVal = math.max(0, math.min(maxScroll, sFrame:GetVerticalScroll() - (delta * 26)))
                sFrame:SetVerticalScroll(nextVal)
                UpdateMenuThumb()
            end)

            sbTrack:SetScript("OnMouseDown", function(selfTrack, button)
                if button ~= "LeftButton" then return end
                local maxScroll = math.max(0, (sc:GetHeight() or 0) - (sf:GetHeight() or 0))
                if maxScroll <= 0 then return end
                local scale = selfTrack:GetEffectiveScale() or 1
                local _, cy = GetCursorPosition()
                cy = cy / scale
                local top, bottom = selfTrack:GetTop(), selfTrack:GetBottom()
                if top and bottom and top > bottom then
                    local trackH = top - bottom
                    local thumbH = sbThumb:GetHeight() or 24
                    local travel = math.max(1, trackH - thumbH)
                    local ratio = math.max(0, math.min(1, ((top - cy) - (thumbH * 0.5)) / travel))
                    sf:SetVerticalScroll(ratio * maxScroll)
                    UpdateMenuThumb()
                end
            end)

            sbThumb:SetScript("OnEnter", function() RefreshMenuThumbColor() end)
            sbThumb:SetScript("OnLeave", function() RefreshMenuThumbColor() end)
            sbThumb:SetScript("OnMouseDown", function(selfThumb, button)
                if button ~= "LeftButton" then return end
                selfThumb.isDragging = true
                RefreshMenuThumbColor()
                local startY = select(2, GetCursorPosition()) / (selfThumb:GetEffectiveScale() or 1)
                local startScroll = sf:GetVerticalScroll() or 0
                selfThumb:SetScript("OnUpdate", function()
                    if not IsMouseButtonDown("LeftButton") then
                        selfThumb.isDragging = false
                        selfThumb:SetScript("OnUpdate", nil)
                        RefreshMenuThumbColor()
                        return
                    end
                    local curY = select(2, GetCursorPosition()) / (selfThumb:GetEffectiveScale() or 1)
                    local maxScroll = math.max(0, (sc:GetHeight() or 0) - (sf:GetHeight() or 0))
                    local trackH = math.max(20, sbTrack:GetHeight() or 180)
                    local travel = math.max(1, trackH - (selfThumb:GetHeight() or 24))
                    sf:SetVerticalScroll(math.min(maxScroll, math.max(0, startScroll + ((startY - curY) / travel) * maxScroll)))
                    UpdateMenuThumb()
                end)
            end)
            sbThumb:SetScript("OnMouseUp", function(selfThumb)
                selfThumb.isDragging = false
                selfThumb:SetScript("OnUpdate", nil)
                RefreshMenuThumbColor()
            end)
            sbThumb:SetScript("OnHide", function(selfThumb)
                selfThumb.isDragging = false
                selfThumb:SetScript("OnUpdate", nil)
                RefreshMenuThumbColor()
            end)

            local catcher = CreateFrame("Button", nil, activeDropdownMenu)
            catcher:SetAllPoints(UIParent)
            catcher:SetFrameStrata("TOOLTIP")
            catcher:SetFrameLevel(215)
            catcher:RegisterForClicks("AnyDown")
            catcher:SetScript("OnClick", function()
                activeDropdownMenu:Hide()
            end)
            activeDropdownMenu.clickCatcher = catcher

            activeDropdownMenu:SetScript("OnHide", function(menu)
                if menu.searchBox then menu.searchBox:ClearFocus() end
                if menu.owner and menu.owner.Chevron then
                    menu.owner.Chevron:SetTexture(ICON_CHEVRON_DOWN)
                end
                menu.owner = nil
            end)
        end

        if activeDropdownMenu:IsShown() and activeDropdownMenu.owner == s then
            activeDropdownMenu:Hide()
            return
        end

        local ar, ag, ab = DM:GetAccentColor()
        DM:ApplyBackdrop(activeDropdownMenu, COLORS.BgVoid, { r = ar, g = ag, b = ab, a = 0.90 })
        if activeDropdownMenu.borderOverlay then
            activeDropdownMenu.borderOverlay:SetFrameLevel(230)
            DM:ApplyBackdrop(activeDropdownMenu.borderOverlay, { r = 0, g = 0, b = 0, a = 0 }, { r = ar, g = ag, b = ab, a = 0.90 }, 1)
        end
        if activeDropdownMenu.searchWrap then
            DM:ApplyBackdrop(activeDropdownMenu.searchWrap, { r = 0.035, g = 0.042, b = 0.060, a = 0.98 }, { r = ar, g = ag, b = ab, a = 0.35 })
        end
        activeDropdownMenu.owner = s
        s.Chevron:SetTexture(ICON_CHEVRON_UP)

        local rawOpts = options or {}
        local showSearch = (#rawOpts > 12)
        local searchAreaH = showSearch and 28 or 0
        local maxVisibleH = 264
        activeDropdownMenu.searchWrap:SetShown(showSearch)

        local maxOptionWidth = 0
        for _, opt in ipairs(rawOpts) do
            if not opt.isHeader and not opt.isEmptyNotice then
                local cleanL = StripOptionPrefix(opt.label or opt.value or "")
                maxOptionWidth = math.max(maxOptionWidth, #cleanL * 6.8)
            end
        end

        local function RenderDMOptions(query)
            local qLower = tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
            if activeDropdownMenu.searchPlaceholder then
                activeDropdownMenu.searchPlaceholder:SetShown(qLower == "" and not activeDropdownMenu.searchBox:HasFocus())
            end
            if activeDropdownMenu.searchClear then
                activeDropdownMenu.searchClear:SetShown(qLower ~= "")
            end

            local filtered = {}
            if qLower == "" then
                filtered = rawOpts
            else
                local pendingHdr = nil
                for _, opt in ipairs(rawOpts) do
                    if opt.isHeader then
                        pendingHdr = opt
                    elseif not opt.isEmptyNotice then
                        local cleanL = StripOptionPrefix(opt.label or opt.value or "")
                        local vStr = tostring(opt.value or "")
                        if cleanL:lower():find(qLower, 1, true) or vStr:lower():find(qLower, 1, true) then
                            if pendingHdr then
                                table.insert(filtered, pendingHdr)
                                pendingHdr = nil
                            end
                            table.insert(filtered, opt)
                        end
                    end
                end
                if #filtered == 0 then
                    table.insert(filtered, { isEmptyNotice = true, label = "No matching options" })
                end
            end

            for _, r in ipairs(activeDropdownMenu.rows) do
                r:Hide()
            end

            local curVal = getter()
            local yOff = 0
            for i, opt in ipairs(filtered) do
                local row = activeDropdownMenu.rows[i]
                if not row then
                    row = CreateFrame("Button", nil, activeDropdownMenu.scrollChild, "BackdropTemplate")
                    row:SetFrameLevel(225)
                    row.HdrLine = row:CreateTexture(nil, "ARTWORK")
                    row.HdrLine:SetHeight(1)
                    row.HdrLine:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 1)
                    row.HdrLine:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 1)
                    row.HdrLine:Hide()

                    row.Check = row:CreateTexture(nil, "OVERLAY")
                    row.Check:SetSize(12, 12)
                    row.Check:SetPoint("LEFT", row, "LEFT", 10, 0)
                    row.Check:SetTexture(ICON_CHECK_PATH)

                    row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    row.Text._dmIsDropdownPreview = true
                    row.Text:SetPoint("LEFT", row, "LEFT", 28, 0)
                    row.Text:SetPoint("RIGHT", row, "RIGHT", -10, 0)
                    row.Text:SetJustifyH("LEFT")
                    row.Text:SetWordWrap(false)
                    activeDropdownMenu.rows[i] = row
                end

                local rH = opt.isHeader and 20 or 26
                row:SetHeight(rH)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", activeDropdownMenu.scrollChild, "TOPLEFT", 0, -yOff)
                row:SetPoint("TOPRIGHT", activeDropdownMenu.scrollChild, "TOPRIGHT", 0, -yOff)
                yOff = yOff + rH

                if opt.isHeader then
                    row:Disable()
                    row.Check:Hide()
                    row.HdrLine:Show()
                    row.HdrLine:SetColorTexture(ar, ag, ab, 0.42)
                    row.Text:ClearAllPoints()
                    row.Text:SetPoint("LEFT", row, "LEFT", 10, 0)
                    row.Text:SetPoint("RIGHT", row, "RIGHT", -10, 0)
                    row.Text._dmCustomFontPath = nil
                    DM:StyleFont(row.Text, 10, "", { r = ar, g = ag, b = ab, a = 0.95 })
                    row.Text:SetText(tostring(opt.label or ""):upper())
                    DM:ApplyBackdrop(row, { r = 0.082, g = 0.098, b = 0.137, a = 0.85 }, { r = 0, g = 0, b = 0, a = 0 })
                    row:SetScript("OnEnter", nil)
                    row:SetScript("OnLeave", nil)
                    row:SetScript("OnClick", nil)
                elseif opt.isEmptyNotice then
                    row:Disable()
                    row.Check:Hide()
                    row.HdrLine:Hide()
                    row.Text:ClearAllPoints()
                    row.Text:SetPoint("LEFT", row, "LEFT", 12, 0)
                    row.Text:SetPoint("RIGHT", row, "RIGHT", -10, 0)
                    row.Text._dmCustomFontPath = nil
                    DM:StyleFont(row.Text, 11, "", COLORS.TextMuted)
                    row.Text:SetText(tostring(opt.label or "No matching options"))
                    DM:ApplyBackdrop(row, COLORS.BgVoid, { r = 0, g = 0, b = 0, a = 0 })
                    row:SetScript("OnEnter", nil)
                    row:SetScript("OnLeave", nil)
                    row:SetScript("OnClick", nil)
                else
                    row:Enable()
                    row.HdrLine:Hide()
                    row.Text:ClearAllPoints()
                    row.Text:SetPoint("LEFT", row, "LEFT", 28, 0)
                    row.Text:SetPoint("RIGHT", row, "RIGHT", -10, 0)

                    local cleanLabel = StripOptionPrefix(opt.label)
                    local isSelected = (opt.value == curVal)
                    row.Text._dmCustomFontPath = opt.fontPath or opt.path
                    DM:StyleFont(row.Text, 12, "", isSelected and { r = ar, g = ag, b = ab, a = 1 } or COLORS.TextPrimary)
                    row.Text:SetText(cleanLabel)

                    local strW = (row.Text.GetUnboundedStringWidth and row.Text:GetUnboundedStringWidth()) or row.Text:GetStringWidth() or (#cleanLabel * 7)
                    if strW > maxOptionWidth then
                        maxOptionWidth = strW
                    end

                    if isSelected then
                        row.Check:SetVertexColor(ar, ag, ab, 1.0)
                        row.Check:Show()
                    else
                        row.Check:Hide()
                    end

                    DM:ApplyBackdrop(row, isSelected and COLORS.BgElevated or COLORS.BgVoid, { r = 0, g = 0, b = 0, a = 0 })
                    row:SetScript("OnEnter", function(rBtn)
                        DM:ApplyBackdrop(rBtn, COLORS.BgHover, { r = 0, g = 0, b = 0, a = 0 })
                    end)
                    row:SetScript("OnLeave", function(rBtn)
                        DM:ApplyBackdrop(rBtn, isSelected and COLORS.BgElevated or COLORS.BgVoid, { r = 0, g = 0, b = 0, a = 0 })
                    end)
                    row:SetScript("OnClick", function()
                        activeDropdownMenu:Hide()
                        setter(opt.value)
                        s:RefreshValue()
                    end)
                end
                row:Show()
            end

            local totalH = math.max(26, yOff)
            local viewH = math.min(totalH, maxVisibleH)
            local hasScroll = (totalH > viewH + 1)
            local menuWidth = math.max(s:GetWidth(), math.ceil(maxOptionWidth + 52), 250)
            local menuHeight = searchAreaH + viewH + 6
            activeDropdownMenu:SetSize(menuWidth, menuHeight)

            local topScrollOffset = 3 + searchAreaH
            activeDropdownMenu.scrollFrame:ClearAllPoints()
            activeDropdownMenu.scrollFrame:SetPoint("TOPLEFT", activeDropdownMenu, "TOPLEFT", 2, -topScrollOffset)
            activeDropdownMenu.scrollFrame:SetPoint("BOTTOMRIGHT", activeDropdownMenu, "BOTTOMRIGHT", hasScroll and -10 or -2, 3)
            activeDropdownMenu.scrollChild:SetSize(menuWidth - (hasScroll and 12 or 4), totalH)
            activeDropdownMenu.scrollFrame:SetVerticalScroll(0)

            activeDropdownMenu.sbTrack:ClearAllPoints()
            activeDropdownMenu.sbTrack:SetPoint("TOPRIGHT", activeDropdownMenu, "TOPRIGHT", -3, -topScrollOffset)
            activeDropdownMenu.sbTrack:SetPoint("BOTTOMRIGHT", activeDropdownMenu, "BOTTOMRIGHT", -3, 3)
            if activeDropdownMenu.UpdateMenuThumb then
                activeDropdownMenu.UpdateMenuThumb()
            end
        end

        activeDropdownMenu.searchBox:SetScript("OnTextChanged", function(sbEdit)
            if activeDropdownMenu:IsShown() and activeDropdownMenu.owner == s then
                RenderDMOptions(sbEdit:GetText())
            end
        end)
        activeDropdownMenu.searchBox:SetScript("OnEditFocusGained", function()
            if activeDropdownMenu.searchPlaceholder then
                activeDropdownMenu.searchPlaceholder:Hide()
            end
        end)
        activeDropdownMenu.searchBox:SetScript("OnEditFocusLost", function(sbEdit)
            if activeDropdownMenu.searchPlaceholder then
                activeDropdownMenu.searchPlaceholder:SetShown((sbEdit:GetText() or "") == "")
            end
        end)

        activeDropdownMenu.searchBox:SetText("")
        activeDropdownMenu.searchBox:ClearFocus()
        RenderDMOptions("")

        activeDropdownMenu:ClearAllPoints()
        activeDropdownMenu:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 0, -2)
        activeDropdownMenu:Show()
    end)

    dd:RefreshValue()
    return dd
end

local function IsNegativePillOption(val, label)
    local lbl = tostring(label or ""):upper():gsub("^|C%x%x%x%x%x%x%x%x", ""):gsub("|R", "")
    if lbl ~= "" then
        if lbl == "LOW" or lbl == "FAIR" or lbl == "GOOD" or lbl == "HIGH" or lbl == "ULTRA" or lbl == "ULTRA HIGH" or lbl == "ESSENTIAL" or lbl == "REDUCED" or lbl == "EVERYTHING" then
            return false
        end
        if lbl == "OFF" or lbl == "DISABLED" or lbl == "NONE" or lbl == "MUTED" or lbl == "HIDDEN" or lbl == "NEVER" or lbl == "MANUAL" or lbl == "RESET TO PREVIOUS" or string.find(lbl, "^OFF ") then
            return true
        end
        if val == false then return true end
        local s = tostring(val or ""):upper()
        if s == "OFF" or s == "DISABLED" or s == "NONE" or s == "MUTED" or s == "HIDDEN" or s == "NEVER" or s == "MANUAL" or s == "BLIZZARD_DEFAULT" then
            return true
        end
        return false
    end
    if val == false or val == 0 or val == "0" then return true end
    local s = tostring(val or ""):upper()
    if s == "OFF" or s == "DISABLED" or s == "NONE" or s == "MUTED" or s == "HIDDEN" or s == "NEVER" or s == "MANUAL" or s == "BLIZZARD_DEFAULT" then
        return true
    end
    return false
end

local function GetPillTierUnderlineColor(val, label)
    local lbl = tostring(label or ""):upper():gsub("^|C%x%x%x%x%x%x%x%x", ""):gsub("|R", "")
    -- Tier 0: Off / Disabled / None (Slate-Charcoal pill + Coral-Rose bar #F87171)
    if IsNegativePillOption(val, lbl) then
        return 0.973, 0.443, 0.443, 0.90, true
    end
    -- Tier 1: Low / Essential / 120 Lines / Clear 0% (Cool Ice-Cyan #38BDF8)
    if lbl == "LOW" or lbl == "ESSENTIAL" or lbl == "120 LINES" or lbl:find("^CLEAR") then
        return 0.220, 0.741, 0.973, 0.95, false
    end
    -- Tier 2: Fair / Reduced / 250 Lines / Smoked 45% (Emerald Green #34D399)
    if lbl == "FAIR" or lbl == "REDUCED" or lbl == "250 LINES" or lbl:find("^SMOKED") then
        return 0.204, 0.827, 0.600, 0.95, false
    end
    -- Tier 3: Good / 500 Lines / Obsidian 72% (Warm Amber-Gold #FACC15)
    if lbl == "GOOD" or lbl == "500 LINES" or lbl:find("^OBSIDIAN") then
        return 0.980, 0.800, 0.082, 0.95, false
    end
    -- Tier 4: High / Everything / 1000 Lines / Solid 92% (Vibrant Tangerine #FB923C)
    if lbl == "HIGH" or lbl == "EVERYTHING" or lbl == "1000 LINES" or lbl:find("^SOLID") then
        return 0.984, 0.573, 0.235, 0.95, false
    end
    -- Tier 5: Ultra / Ultra High (Royal Amethyst #C084FC)
    if lbl == "ULTRA" or lbl == "ULTRA HIGH" then
        return 0.753, 0.518, 0.988, 0.95, false
    end
    return nil, nil, nil, nil, false
end

function DM:CreateSegmentedPills(parent, options, getter, setter, totalWidth)
    local count = #options
    local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    local baseW = totalWidth or (count == 2 and 196 or (count == 3 and 246 or 276))
    holder:SetSize(baseW, 26)
    self:ApplyBackdrop(holder, COLORS.BgVoid, COLORS.BorderStrong, 1)

    holder.pills = {}
    local gap = 2
    local minPillW = math.max(54, math.floor((baseW - 4 - (count - 1) * gap) / count))

    for i, opt in ipairs(options) do
        local p = CreateFrame("Button", nil, holder, "BackdropTemplate")
        p:SetHeight(22)

        p.Check = p:CreateTexture(nil, "OVERLAY")
        p.Check:SetSize(6, 6)
        p.Check:SetPoint("LEFT", p, "LEFT", 8, 0)
        p.Check:SetColorTexture(1, 1, 1, 0.98)
        p.Check:Hide()

        p.OffBar = p:CreateTexture(nil, "OVERLAY")
        p.OffBar:SetHeight(1.5)
        p.OffBar:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 1, 1)
        p.OffBar:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -1, 1)
        p.OffBar:SetColorTexture(0.973, 0.443, 0.443, 0.90)
        p.OffBar:Hide()
        p.TierBar = p.OffBar

        p.Text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        p.Text:SetPoint("LEFT", p, "LEFT", 6, 0); p.Text:SetPoint("RIGHT", p, "RIGHT", -6, 0); p.Text:SetJustifyH("CENTER")
        p.Text:SetWordWrap(false)
        self:StyleFont(p.Text, 11, "", COLORS.TextMuted)
        p.Text:SetText(StripOptionPrefix(opt.label))

        p:SetScript("OnClick", function()
            setter(opt.value)
            holder:RefreshValue()
        end)
        p:SetScript("OnEnter", function(s)
            if getter() ~= opt.value then
                local clean = StripOptionPrefix(opt.label)
                if IsNegativePillOption(opt.value, clean) then
                    DM:ApplyBackdrop(s, COLORS.BgHover, { r = 0.392, g = 0.455, b = 0.545, a = 0.85 })
                else
                    local ar, ag, ab = DM:GetAccentColor()
                    DM:ApplyBackdrop(s, COLORS.BgHover, { r = ar, g = ag, b = ab, a = 0.45 })
                end
                s.Text:SetTextColor(COLORS.TextPrimary.r, COLORS.TextPrimary.g, COLORS.TextPrimary.b, 1)
            end
        end)
        p:SetScript("OnLeave", function()
            holder:RefreshValue()
        end)

        holder.pills[i] = p
    end

    function holder:RefreshValue()
        local cur = getter()
        local ar, ag, ab = DM:GetAccentColor()
        local xCursor = 2
        for i, opt in ipairs(options) do
            local p = self.pills[i]
            local active = (opt.value == cur)
            local clean = StripOptionPrefix(opt.label)
            local tr, tg, tb, ta, isNeg = GetPillTierUnderlineColor(opt.value, clean)
            p.Text:SetText(clean)
            if active then
                if isNeg then
                    DM:ApplyBackdrop(p, { r = 0.118, g = 0.141, b = 0.188, a = 0.98 }, { r = 0.392, g = 0.455, b = 0.545, a = 0.90 }, 1)
                    DM:StyleFont(p.Text, 11, "", { r = 0.886, g = 0.910, b = 0.941, a = 1.0 })
                    p.OffBar:SetColorTexture(tr or 0.973, tg or 0.443, tb or 0.443, ta or 0.90)
                    p.OffBar:Show()
                else
                    local fillAlpha = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42
                    DM:ApplyBackdrop(p, { r = ar * fillAlpha, g = ag * fillAlpha, b = ab * fillAlpha, a = 1 }, { r = ar, g = ag, b = ab, a = 0.90 }, 1)
                    DM:StyleFont(p.Text, 11, "", COLORS.TextPrimary)
                    if tr then
                        p.OffBar:SetColorTexture(tr, tg, tb, ta)
                        p.OffBar:Show()
                    else
                        p.OffBar:Hide()
                    end
                end
                p.Text:SetText(clean)
                p.Check:ClearAllPoints()
                p.Check:SetPoint("LEFT", p, "LEFT", 8, 0)
                p.Check:SetColorTexture(1, 1, 1, 0.98)
                p.Check:Hide()
                p.Text:ClearAllPoints()
                p.Text:SetPoint("LEFT", p, "LEFT", 6, 0); p.Text:SetPoint("RIGHT", p, "RIGHT", -6, 0); p.Text:SetJustifyH("CENTER")
            else
                p.OffBar:Hide()
                DM:ApplyBackdrop(p, COLORS.BgElevated, { r = 0, g = 0, b = 0, a = 0 }, 1)
                DM:StyleFont(p.Text, 11, "", COLORS.TextMuted)
                p.Text:SetText(clean)
                p.Check:Hide()
                p.Text:ClearAllPoints()
                p.Text:SetPoint("LEFT", p, "LEFT", 6, 0); p.Text:SetPoint("RIGHT", p, "RIGHT", -6, 0); p.Text:SetJustifyH("CENTER")
            end

            local rawW = (p.Text.GetUnboundedStringWidth and p.Text:GetUnboundedStringWidth()) or p.Text:GetStringWidth() or 0; local strW = math.max(rawW, #clean * 6.8)
            local pillW = math.max(minPillW, math.ceil(strW + 20))
            p:SetWidth(pillW)
            p:ClearAllPoints()
            p:SetPoint("LEFT", self, "LEFT", xCursor, 0)
            xCursor = xCursor + pillW + gap
        end
        local finalW = math.max(baseW, xCursor - gap + 2)
        self:SetWidth(finalW)
    end

    holder:HookScript("OnShow", function(s) s:RefreshValue() end)
    holder:RefreshValue()
    return holder
end

-- ============================================================================
-- 6. TWO-POINT C++ STRETCHING OPTION ROW & SLIDER FACTORIES
-- ============================================================================

local function CreateSectionHeader(parent, arg2, arg3, subtitleText, padOverride)
    local text, yOffset
    if type(arg2) == "number" then
        yOffset = arg2
        text = arg3
    else
        text = arg2
        yOffset = arg3
    end
    local padX = padOverride or parent.innerPadX or 0
    local hasSub = (subtitleText and subtitleText ~= "")
    local hdr = CreateFrame("Frame", nil, parent)
    hdr:SetHeight(hasSub and 36 or 20)
    hdr.hasSub = hasSub
    local y = yOffset or 0
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
    hdr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -padX, y)
    local ar, ag, ab = DM:GetAccentColor()
    local leftBar = hdr:CreateTexture(nil, "ARTWORK")
    leftBar:SetSize(3, hasSub and 34 or 16)
    leftBar:SetPoint("TOPLEFT", hdr, "TOPLEFT", 0, -1)
    leftBar:SetColorTexture(ar, ag, ab, 1.0)
    hdr.leftBar = leftBar
    local botLine = hdr:CreateTexture(nil, "ARTWORK")
    botLine:SetHeight(1)
    botLine:SetPoint("TOPLEFT", leftBar, "BOTTOMLEFT", 0, 0)
    botLine:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
    botLine:SetColorTexture(ar, ag, ab, 0.35)
    hdr.botLine = botLine
    local title = hdr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if hasSub then
        title:SetPoint("TOPLEFT", leftBar, "TOPRIGHT", 8, 0)
    else
        title:SetPoint("LEFT", leftBar, "RIGHT", 8, 0)
    end
    DM:StyleFont(title, 11, "", { r = ar, g = ag, b = ab, a = 1.0 })
    title:SetText(string.upper(text or ""))
    hdr.title = title

    if hasSub then
        local sub = hdr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
        sub:SetPoint("RIGHT", hdr, "RIGHT", -12, 0)
        sub:SetJustifyH("LEFT")
        sub:SetWordWrap(false)
        DM:StyleFont(sub, 10, "", { r = 0.64, g = 0.70, b = 0.78, a = 1.0 })
        sub:SetText(subtitleText)
        hdr.subtitle = sub
    end

    function hdr:SetText(newText)
        if self.title then
            self.title:SetText(string.upper(newText or ""))
        end
    end

    function hdr:RefreshAccent()
        local r, g, b = DM:GetAccentColor()
        if self.leftBar then self.leftBar:SetColorTexture(r, g, b, 1.0) end
        if self.botLine then self.botLine:SetColorTexture(r, g, b, 0.35) end
        if self.title then self.title:SetTextColor(r, g, b, 1.0) end
        if self.subtitle then self.subtitle:SetTextColor(0.64, 0.70, 0.78, 1.0) end
    end
    DM.sectionHeaders = DM.sectionHeaders or {}
    table.insert(DM.sectionHeaders, hdr)
    return hdr
end

function DM:CreateSectionBox(parent, yOffset, height)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box.innerPadX = 14
    if yOffset ~= nil then
        box:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
        box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    end
    box:SetHeight(height or 200)
    self:ApplyBackdrop(box, COLORS.BgCanvas, COLORS.BorderStrong)
    return box
end

function DM:CreateSectionHeader(parent, yOffset, text, subtitleText, padOverride)
    return CreateSectionHeader(parent, yOffset, text, subtitleText, padOverride)
end
DM.CreateSectionHeader = function(arg1, arg2, arg3, arg4, arg5, arg6)
    if arg1 == DM then
        return CreateSectionHeader(arg2, arg3, arg4, arg5, arg6)
    else
        return CreateSectionHeader(arg1, arg2, arg3, arg4, arg5)
    end
end

function DM:CreateSpaciousRow(parent, yOffset, height, titleText, descText, isSubRow)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(height or (isSubRow and 54 or 58))
    -- Two-Point C++ Horizontal Anchor (Zero OnUpdate during resize!)
    local padX = parent.innerPadX or 0
    local leftInset = isSubRow and 10 or padX
    local rightInset = isSubRow and -10 or -padX
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", leftInset, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", rightInset, yOffset)
    local subBorderCol = { r = 0.145, g = 0.165, b = 0.212, a = 0.95 }
    self:ApplyBackdrop(row, isSubRow and COLORS.BgVoid or COLORS.BgSurface, isSubRow and subBorderCol or COLORS.BorderDim)
    row.isSubRow = not not isSubRow

    local cleanTitle = (titleText or ""):gsub("^|%-%s*", ""):gsub("^'%-%s*", "")
    local leftPad = isSubRow and 22 or 14

    row.Title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.Title:SetPoint("TOPLEFT", row, "TOPLEFT", leftPad, -9)
    row.Title:SetPoint("RIGHT", row, "RIGHT", -310, 0)
    row.Title:SetJustifyH("LEFT")
    row.Title:SetWordWrap(false)
    local ar, ag, ab = self:GetAccentColor()
    self:StyleFont(row.Title, 11, "", COLORS.TextPrimary)
    row.Title:SetText(cleanTitle)

    if isSubRow then
        local bar = row:CreateTexture(nil, "OVERLAY")
        bar:SetWidth(2)
        bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
        bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
        bar:SetColorTexture(ar, ag, ab, 0.85)
        row.SubAccentBar = bar

        local pip = row:CreateTexture(nil, "OVERLAY")
        pip:SetSize(5, 5)
        pip:SetPoint("RIGHT", row.Title, "LEFT", -6, 0)
        pip:SetColorTexture(ar, ag, ab, 0.95)
        row.SubPip = pip
    end

    row.Desc = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.Desc:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -3)
    row.Desc:SetPoint("RIGHT", row, "RIGHT", -310, 0)
    row.Desc:SetJustifyH("LEFT")
    row.Desc:SetWordWrap(true); if row.Desc.SetMaxLines then row.Desc:SetMaxLines(2) end
    self:StyleFont(row.Desc, 11, "", COLORS.TextMuted)
    row.Desc:SetText(descText or "")

    function row:BindControl(ctrlWidget, leftAccessoryWidget)
        if not ctrlWidget then return end
        self.boundCtrl = ctrlWidget
        self.boundAccessory = leftAccessoryWidget
        local anchorTarget = (leftAccessoryWidget and leftAccessoryWidget:IsShown()) and leftAccessoryWidget or ctrlWidget
        local pad = self.isSubRow and 22 or 14
        self.Title:ClearAllPoints()
        self.Title:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -9)
        self.Title:SetPoint("RIGHT", anchorTarget, "LEFT", -14, 0)
        self.Desc:ClearAllPoints()
        self.Desc:SetPoint("TOPLEFT", self.Title, "BOTTOMLEFT", 0, -3)
        self.Desc:SetPoint("RIGHT", anchorTarget, "LEFT", -14, 0)
    end

    function row:SetVerticalOffset(newY)
        local pPad = parent.innerPadX or 0
        local lIn = self.isSubRow and 10 or pPad
        local rIn = self.isSubRow and -10 or -pPad
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", parent, "TOPLEFT", lIn, newY)
        self:SetPoint("TOPRIGHT", parent, "TOPRIGHT", rIn, newY)
    end

    row:SetScript("OnEnter", function(s)
        if s.hasTuneBar and s.RefreshGroupBorder then
            s:RefreshGroupBorder(true)
        else
            self:ApplyBackdrop(s, COLORS.BgElevated, COLORS.BorderStrong)
        end
    end)
    row:SetScript("OnLeave", function(s)
        if s.hasTuneBar and s.RefreshGroupBorder then
            s:RefreshGroupBorder(false)
        elseif s.isSubRow then
            self:ApplyBackdrop(s, COLORS.BgVoid, subBorderCol)
        else
            self:ApplyBackdrop(s, COLORS.BgSurface, COLORS.BorderDim)
        end
    end)

    return row
end

local function DisableTexturePixelSnap(tex)
    if not tex then return end
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.DisablePixelSnap) == "function" then
        pcall(_G.DynamicSuite.UI.DisablePixelSnap, tex)
    end
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
end

function DM:AttachHorizontalChevronBar(groupRow, subCount, isEnabledGetter, isExpandedGetter, onToggle)
    groupRow.hasTuneBar = true

    local tuneBar = CreateFrame("Button", nil, groupRow, "BackdropTemplate")
    tuneBar:SetHeight(24)
    tuneBar:SetPoint("TOPLEFT", groupRow, "TOPLEFT", 10, -52)
    tuneBar:SetPoint("TOPRIGHT", groupRow, "TOPRIGHT", -10, -52)
    tuneBar:RegisterForClicks("LeftButtonUp")
    groupRow.tuneBar = tuneBar

    local tuneLabel = tuneBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tuneLabel:SetPoint("CENTER", tuneBar, "CENTER", 8, 0)
    self:StyleFont(tuneLabel, 11, "", COLORS.TextPrimary)
    tuneLabel:SetText(string.format("Sub-Settings (%d)", subCount or 1))
    tuneBar.Label = tuneLabel

    local tuneChevron = tuneBar:CreateTexture(nil, "ARTWORK")
    tuneChevron:SetSize(11, 11)
    tuneChevron:SetPoint("RIGHT", tuneLabel, "LEFT", -6, 0)
    DisableTexturePixelSnap(tuneChevron)
    tuneBar.Chevron = tuneChevron

    function groupRow:RefreshGroupBorder(rowHovered)
        local enabled = not not (isEnabledGetter and isEnabledGetter())
        local expanded = enabled and not not (isExpandedGetter and isExpandedGetter())
        local ar, ag, ab = DM:GetAccentColor()
        if not enabled then
            DM:ApplyBackdrop(self, rowHovered and COLORS.BgElevated or COLORS.BgSurface, rowHovered and COLORS.BorderStrong or COLORS.BorderDim, 1)
        elseif expanded then
            DM:ApplyBackdrop(self, COLORS.BgSurface, { r = ar, g = ag, b = ab, a = 0.85 }, 1)
        else
            DM:ApplyBackdrop(self, COLORS.BgSurface, { r = ar * 0.65, g = ag * 0.65, b = ab * 0.65, a = 0.80 }, 1)
        end
    end

    function tuneBar:RefreshState(hovered)
        local enabled = not not (isEnabledGetter and isEnabledGetter())
        local expanded = enabled and not not (isExpandedGetter and isExpandedGetter())
        local ar, ag, ab = DM:GetAccentColor()
        local fillAlpha = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42

        self:SetShown(enabled)
        self.Chevron:SetTexture(expanded and ICON_CHEVRON_UP or ICON_CHEVRON_DOWN)
        DisableTexturePixelSnap(self.Chevron)

        if hovered then
            local hovA = math.min(0.65, fillAlpha + 0.10)
            DM:ApplyBackdrop(self, { r = ar * hovA, g = ag * hovA, b = ab * hovA, a = 0.98 }, { r = ar, g = ag, b = ab, a = 1.0 }, 1)
            self.Chevron:SetVertexColor(1, 1, 1, 1)
            self.Label:SetTextColor(1, 1, 1, 1)
        elseif expanded then
            local expA = fillAlpha * 0.60
            DM:ApplyBackdrop(self, { r = ar * expA, g = ag * expA, b = ab * expA, a = 0.96 }, { r = ar, g = ag, b = ab, a = 0.95 }, 1)
            self.Chevron:SetVertexColor(1, 1, 1, 1)
            self.Label:SetTextColor(1, 1, 1, 1)
        else
            DM:ApplyBackdrop(self, { r = 0.078, g = 0.090, b = 0.122, a = 0.96 }, { r = 0.145, g = 0.165, b = 0.212, a = 0.95 }, 1)
            self.Chevron:SetVertexColor(ar, ag, ab, 0.95)
            self.Label:SetTextColor(0.84, 0.89, 0.96, 1.0)
        end

        groupRow:RefreshGroupBorder(groupRow:IsMouseOver())
    end

    tuneBar:SetScript("OnEnter", function(s)
        s:RefreshState(true)
    end)
    tuneBar:SetScript("OnLeave", function(s)
        s:RefreshState(false)
    end)
    tuneBar:SetScript("OnClick", function(s)
        if onToggle then onToggle() end
        s:RefreshState(s:IsMouseOver())
    end)

    tuneBar:RefreshState(false)
    return tuneBar
end

function DM:CreateTuneButton(parent, isExpandedGetter, onToggle)
    local sharedUI = _G.DynamicSuite and _G.DynamicSuite.UI
    if sharedUI and type(sharedUI.CreateSubDrawerButton) == "function" then
        local ok, sharedBtn = pcall(sharedUI.CreateSubDrawerButton, parent, onToggle)
        if ok and sharedBtn and type(sharedBtn) == "table" and sharedBtn.SetPoint then
            sharedBtn:SetSize(26, 26); if sharedBtn.Cog then sharedBtn.Cog:Hide() end; if sharedBtn.Chevron then sharedBtn.Chevron:ClearAllPoints(); sharedBtn.Chevron:SetPoint("CENTER", sharedBtn, "CENTER", 0, 0); sharedBtn.Chevron:SetSize(12, 12) end
            if sharedBtn.Text then sharedBtn.Text:SetText(""); sharedBtn.Text:Hide() end
            if sharedBtn.label then sharedBtn.label:SetText(""); sharedBtn.label:Hide() end
            if sharedBtn.Cog then DisableTexturePixelSnap(sharedBtn.Cog) end
            if sharedBtn.Chevron then DisableTexturePixelSnap(sharedBtn.Chevron) end
            local origRefresh = sharedBtn.RefreshState or sharedBtn.UpdateState or sharedBtn.Refresh
            function sharedBtn:RefreshState(hovered)
                local expanded = not not (isExpandedGetter and isExpandedGetter())
                if self.SetOpen then pcall(self.SetOpen, self, expanded) end
                if self.SetExpanded then pcall(self.SetExpanded, self, expanded) end
                if origRefresh then pcall(origRefresh, self, expanded, hovered) end
            end
            sharedBtn:SetScript("OnClick", function(s)
                if onToggle then onToggle() end
                s:RefreshState(false)
            end)
            sharedBtn:RefreshState(false)
            return sharedBtn
        end
    end

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(32, 26)
    btn:RegisterForClicks("LeftButtonUp")

    btn.Cog = btn:CreateTexture(nil, "ARTWORK")
    btn.Cog:SetSize(1, 1); btn.Cog:Hide()
    btn.Cog:SetPoint("LEFT", btn, "CENTER", -13.5, 0)
    btn.Cog:SetTexture(ICON_COG_PATH)
    DisableTexturePixelSnap(btn.Cog)

    btn.Chevron = btn:CreateTexture(nil, "ARTWORK")
    btn.Chevron:SetSize(10, 10)
    btn.Chevron:SetPoint("LEFT", btn.Cog, "RIGHT", 3, 0)
    DisableTexturePixelSnap(btn.Chevron)

    function btn:RefreshState(hovered)
        local expanded = not not (isExpandedGetter and isExpandedGetter())
        local ar, ag, ab = DM:GetAccentColor()
        self.Chevron:SetTexture(expanded and ICON_CHEVRON_UP or ICON_CHEVRON_DOWN)
        DisableTexturePixelSnap(self.Cog)
        DisableTexturePixelSnap(self.Chevron)
        if hovered then
            DM:ApplyBackdrop(self, COLORS.BgHover, { r = ar, g = ag, b = ab, a = 0.85 }, 1)
            self.Cog:SetVertexColor(ar, ag, ab, 1.0)
            self.Chevron:SetVertexColor(ar, ag, ab, 1.0)
        elseif expanded then
            DM:ApplyBackdrop(self, { r = ar * 0.18, g = ag * 0.18, b = ab * 0.18, a = 1 }, { r = ar, g = ag, b = ab, a = 0.65 }, 1)
            self.Cog:SetVertexColor(ar, ag, ab, 0.95)
            self.Chevron:SetVertexColor(ar, ag, ab, 0.95)
        else
            DM:ApplyBackdrop(self, COLORS.BgElevated, COLORS.BorderStrong, 1)
            self.Cog:SetVertexColor(ar, ag, ab, 0.85)
            self.Chevron:SetVertexColor(COLORS.TextMuted.r, COLORS.TextMuted.g, COLORS.TextMuted.b, 0.90)
        end
    end

    btn:SetScript("OnEnter", function(s)
        s:RefreshState(true)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText("Advanced Options", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(s)
        s:RefreshState(false)
        if GameTooltip:IsOwned(s) then GameTooltip:Hide() end
    end)
    btn:SetScript("OnClick", function(s)
        if onToggle then onToggle() end
        s:RefreshState(false)
    end)

    btn:RefreshState(false)
    return btn
end
DM.CreateSubDrawerButton = DM.CreateTuneButton

function DM:CreateSliderControl(parent, minVal, maxVal, stepVal, getter, setter, formatFn)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(256, 26)
    stepVal = stepVal or 0.05

    local valText = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
    valText:SetWidth(52)
    valText:SetJustifyH("RIGHT")
    valText:SetWordWrap(false)
    self:StyleFont(valText, 11, "", self:GetAccentColorTable(1.0))

    local slider = CreateFrame("Slider", nil, holder, "BackdropTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetPoint("LEFT", holder, "LEFT", 0, 0)
    slider:SetPoint("RIGHT", valText, "LEFT", -10, 0)
    slider:SetHeight(4)
    slider:SetHitRectInsets(0, 0, -10, -10)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(stepVal)
    slider:SetObeyStepOnDrag(false)
    slider:EnableMouse(true)
    slider:EnableMouseWheel(true)
    self:ApplyBackdrop(slider, { r = 0.035, g = 0.039, b = 0.051, a = 0.98 }, { r = 1, g = 1, b = 1, a = 0.14 })

    local ar0, ag0, ab0 = self:GetAccentColor()
    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", slider, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", slider, "BOTTOMLEFT", 1, 1)
    fill:SetWidth(1)
    fill:SetColorTexture(ar0, ag0, ab0, 0.85)
    slider.FillBar = fill

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(6, 14)
    thumb:SetColorTexture(0.97, 0.98, 1.00, 1.0)
    if thumb.SetSnapToPixelGrid then
        thumb:SetSnapToPixelGrid(false)
        thumb:SetTexelSnappingBias(0)
    end
    slider:SetThumbTexture(thumb)

    local updating = false
    local isDragging = false
    local lastCommittedValue = nil

    local function SnapValue(v)
        v = math.max(minVal, math.min(maxVal, v))
        if stepVal and stepVal > 0 then
            v = math.floor((v - minVal) / stepVal + 0.5) * stepVal + minVal
        end
        return math.max(minVal, math.min(maxVal, v))
    end

    local function UpdateFillAndThumb(rawVal)
        local r, g, b = DM:GetAccentColor()
        fill:SetColorTexture(r, g, b, 0.85)
        valText:SetTextColor(r, g, b, 1.0)
        if isDragging or slider:IsMouseOver() then
            thumb:SetColorTexture(r, g, b, 1.0)
        else
            thumb:SetColorTexture(0.97, 0.98, 1.00, 1.0)
        end
        local v = rawVal or slider:GetValue() or minVal
        local pct = (maxVal > minVal) and ((v - minVal) / (maxVal - minVal)) or 0
        pct = math.max(0, math.min(1, pct))
        local tw = slider:GetWidth()
        if not tw or tw <= 0 then tw = 194 end
        fill:SetWidth(math.max(1, pct * math.max(1, tw - 2)))
    end

    slider:SetScript("OnValueChanged", function(_, value)
        if updating then return end
        local stepped = SnapValue(value)
        if formatFn then
            valText:SetText(formatFn(stepped))
        else
            valText:SetText(string.format("%d%%", math.floor(stepped * 100 + 0.5)))
        end
        UpdateFillAndThumb(value)
        if stepped ~= lastCommittedValue then
            lastCommittedValue = stepped
            setter(stepped)
        end
    end)

    local function UpdateSliderFromCursor()
        if isDragging and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            isDragging = false
            slider:SetScript("OnUpdate", nil)
            holder:RefreshValue()
            return
        end
        local scale = slider:GetEffectiveScale()
        local cx = GetCursorPosition() / scale
        local left, tw = slider:GetLeft(), slider:GetWidth()
        if left and tw and tw > 0 then
            local pct = math.max(0, math.min(1, (cx - left) / tw))
            slider:SetValue(minVal + pct * (maxVal - minVal))
        end
    end

    slider:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            isDragging = true
            UpdateSliderFromCursor()
            self:SetScript("OnUpdate", UpdateSliderFromCursor)
        end
    end)
    slider:SetScript("OnMouseUp", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
        holder:RefreshValue()
    end)
    slider:SetScript("OnHide", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
    end)
    slider:SetScript("OnEnter", function(self)
        UpdateFillAndThumb()
        if GameTooltip then
            local r, g, b = DM:GetAccentColor()
            local hex = string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(string.format("|cFF%sLeft-Click / Drag:|r |cFFE2E8F0Adjust value|r", hex))
            GameTooltip:AddLine(string.format("|cFF%sMousewheel:|r |cFFE2E8F0Fine-tune by 1 step|r", hex))
            GameTooltip:Show()
        end
    end)
    slider:SetScript("OnLeave", function()
        UpdateFillAndThumb()
        if GameTooltip then GameTooltip:Hide() end
    end)
    slider:SetScript("OnMouseWheel", function(_, delta)
        local cur = getter() or minVal
        local newVal = SnapValue(cur + (delta > 0 and stepVal or -stepVal))
        lastCommittedValue = newVal
        setter(newVal)
        holder:RefreshValue()
    end)
    slider:SetScript("OnSizeChanged", function()
        UpdateFillAndThumb()
    end)

    function holder:RefreshValue()
        updating = true
        local v = SnapValue(getter() or minVal)
        lastCommittedValue = v
        slider:SetValue(v)
        if formatFn then
            valText:SetText(formatFn(v))
        else
            valText:SetText(string.format("%d%%", math.floor(v * 100 + 0.5)))
        end
        UpdateFillAndThumb(v)
        updating = false
    end

    holder:HookScript("OnShow", function(s) C_Timer.After(0, function() s:RefreshValue() end) end)
    holder:RefreshValue()
    return holder
end

function DM:CreateObsidianScrollPage(parent, topAnchor, contentHeight)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", topAnchor, "BOTTOMLEFT", 0, -10)
    page:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -16, 12)
    page:Hide()

    local sf = CreateFrame("ScrollFrame", nil, page)
    sf:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    sf:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    sf:EnableMouseWheel(true)

    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(700, contentHeight or 460)
    sf:SetScrollChild(child)

    -- Unified 4px Slate-Grey Scrollbar Docked at -6px from Workspace Right (+10px outside ScrollFrame)
    local track = CreateFrame("Frame", nil, page)
    track:SetWidth(4)
    track:SetPoint("TOPRIGHT", page, "TOPRIGHT", 10, 0)
    track:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 10, 0)
    track:EnableMouse(true)
    track.bg = track:CreateTexture(nil, "BACKGROUND")
    track.bg:SetAllPoints(track)
    track.bg:SetColorTexture(1, 1, 1, 0.05)
    track:Hide()

    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(4)
    thumb:SetHeight(48)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    thumb:EnableMouse(true)
    thumb.bg = thumb:CreateTexture(nil, "ARTWORK")
    thumb.bg:SetAllPoints(thumb)
    thumb.bg:SetColorTexture(0.38, 0.45, 0.56, 0.85)

    local function RefreshPageThumbColor()
        if thumb.isDragging then
            local ar, ag, ab = DM:GetAccentColor()
            thumb.bg:SetColorTexture(ar, ag, ab, 0.95)
        elseif thumb:IsMouseOver() then
            thumb.bg:SetColorTexture(0.52, 0.60, 0.72, 0.95)
        else
            thumb.bg:SetColorTexture(0.38, 0.45, 0.56, 0.85)
        end
    end

    local function UpdateScrollLayout()
        local viewH = page:GetHeight() or 0
        local viewW = page:GetWidth() or 0
        local maxScroll = math.max(0, (contentHeight or 460) - viewH)

        sf:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
        child:SetWidth(math.max(200, viewW))

        if maxScroll > 2 and viewH > 40 then
            track:Show()
            local cur = math.min(maxScroll, math.max(0, sf:GetVerticalScroll() or 0))
            sf:SetVerticalScroll(cur)

            local trackH = track:GetHeight() or viewH
            local thumbH = math.max(28, math.floor(trackH * (viewH / (contentHeight or 460))))
            thumb:SetHeight(thumbH)
            local travel = math.max(1, trackH - thumbH)
            local offset = -(cur / maxScroll) * travel
            thumb:ClearAllPoints()
            thumb:SetPoint("TOP", track, "TOP", 0, offset)
            RefreshPageThumbColor()
        else
            track:Hide()
            sf:SetVerticalScroll(0)
        end
    end

    sf:SetScript("OnMouseWheel", function(_, delta)
        DM:CloseDropdownMenu()
        local viewH = page:GetHeight() or 0
        local maxScroll = math.max(0, (contentHeight or 460) - viewH)
        if maxScroll <= 0 then return end
        local cur = sf:GetVerticalScroll() or 0
        local nextVal = math.min(maxScroll, math.max(0, cur - delta * 36))
        sf:SetVerticalScroll(nextVal)
        UpdateScrollLayout()
    end)

    track:SetScript("OnMouseDown", function(selfTrack, btn)
        if btn ~= "LeftButton" then return end
        DM:CloseDropdownMenu()
        local viewH = page:GetHeight() or 0
        local maxScroll = math.max(0, (contentHeight or 460) - viewH)
        if maxScroll <= 0 then return end
        local scale = selfTrack:GetEffectiveScale() or 1
        local _, cy = GetCursorPosition()
        cy = cy / scale
        local top, bottom = selfTrack:GetTop(), selfTrack:GetBottom()
        if top and bottom and top > bottom then
            local trackH = top - bottom
            local thumbH = thumb:GetHeight() or 28
            local travel = math.max(1, trackH - thumbH)
            local ratio = math.max(0, math.min(1, ((top - cy) - (thumbH * 0.5)) / travel))
            sf:SetVerticalScroll(ratio * maxScroll)
            UpdateScrollLayout()
        end
    end)

    thumb:SetScript("OnEnter", function() RefreshPageThumbColor() end)
    thumb:SetScript("OnLeave", function() RefreshPageThumbColor() end)
    thumb:SetScript("OnMouseDown", function(s, btn)
        if btn ~= "LeftButton" then return end
        DM:CloseDropdownMenu()
        s.isDragging = true
        RefreshPageThumbColor()
        local _, startCursorY = GetCursorPosition()
        local scale = s:GetEffectiveScale() or 1
        startCursorY = startCursorY / scale
        local startScroll = sf:GetVerticalScroll() or 0

        s:SetScript("OnUpdate", function()
            if not IsMouseButtonDown("LeftButton") then
                s.isDragging = false
                s:SetScript("OnUpdate", nil)
                RefreshPageThumbColor()
                return
            end
            local viewH = page:GetHeight() or 0
            local maxScroll = math.max(0, (contentHeight or 460) - viewH)
            if maxScroll <= 0 then return end
            local trackH = track:GetHeight() or viewH
            local thumbH = thumb:GetHeight() or 48
            local travel = math.max(1, trackH - thumbH)
            local _, curY = GetCursorPosition()
            curY = curY / (s:GetEffectiveScale() or 1)
            local dy = startCursorY - curY
            local nextScroll = math.min(maxScroll, math.max(0, startScroll + (dy / travel) * maxScroll))
            sf:SetVerticalScroll(nextScroll)
            UpdateScrollLayout()
        end)
    end)
    thumb:SetScript("OnMouseUp", function(s)
        s.isDragging = false
        s:SetScript("OnUpdate", nil)
        RefreshPageThumbColor()
    end)
    thumb:SetScript("OnHide", function(s)
        s.isDragging = false
        s:SetScript("OnUpdate", nil)
        RefreshPageThumbColor()
    end)

    function page:SetContentHeight(newH)
        contentHeight = newH or 460
        child:SetHeight(contentHeight)
        UpdateScrollLayout()
    end

    page:SetScript("OnSizeChanged", UpdateScrollLayout)
    page:SetScript("OnShow", UpdateScrollLayout)
    page.content = child
    page.scrollFrame = sf
    page.scrollTrack = track
    page.scrollThumb = thumb
    page.UpdateScrollLayout = UpdateScrollLayout
    return page
end

-- ============================================================================
-- 7. LEGACY FOCUSMARKER CONFLICT SCANNER & 1-CLICK MIGRATION ENGINE
-- ============================================================================

function DM:IsAddonEnabled(addonFolder)
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        local ok, state = pcall(C_AddOns.GetAddOnEnableState, addonFolder, UnitName("player"))
        if not ok or type(state) ~= "number" then
            ok, state = pcall(C_AddOns.GetAddOnEnableState, addonFolder)
        end
        if ok and type(state) == "number" then
            return state > 0
        end
    end
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, addonFolder)
        return ok and (loaded == true) or false
    end
    return false
end

-- ----------------------------------------------------------------------------
-- FocusMarker -> DynamicMarker SavedVariables Migration Bridge (v3)
-- ----------------------------------------------------------------------------
-- FocusMarkerDB is read-only: DynamicMarker never mutates _G.FocusMarkerDB so it
-- stays intact as a safe fallback. Automatic migration runs strictly once in
-- DM:InitDB() on ADDON_LOADED (before DB_DEFAULTS are applied) when
-- FocusMarkerDB is non-empty and DynamicMarkerDB.migratedFromFocusMarker ~= true.
-- Both AceDB-3.0 (profiles/profileKeys) and flat schemas are supported safely.
local FOCUSMARKER_SNAPSHOT_KEYS = {
    "preferredIcon", "focusIcon", "defaultIcon", "raidIcon",
    "markGroupMode", "groupScope", "groupMode", "visibilityMode",
    "isMuted", "chatAnnounce", "announce", "chatChannel",
    "barVisible", "showBar", "showTargetBar", "visibility", "barVisibility", "iconBarVisibility", "targetBarVisibility",
    "flareVisible", "showFlareBar", "flareBarShown", "flareVisibility", "flareBarVisibility",
    "orientation", "barOrientation", "iconBarOrientation", "targetBarOrientation",
    "flareOrientation", "flareBarOrientation", "worldMarkerOrientation",
    "iconSize", "buttonSize", "scale", "barScale", "iconBarScale", "targetBarScale",
    "flareIconSize", "flareButtonSize", "flareScale", "flareBarScale", "worldMarkerScale",
    "opacity", "alpha", "barOpacity", "targetBarOpacity", "flareOpacity", "flareAlpha", "flareBarOpacity",
    "position", "pos", "barPos", "targetPos", "targetPosition", "iconBarPos", "targetBarPos",
    "point", "relPoint", "relativePoint", "x", "y", "xOfs", "yOfs",
    "barPoint", "barRelPoint", "barX", "barY", "targetBarPoint", "targetBarRelPoint", "targetBarX", "targetBarY",
    "flarePos", "flarePosition", "flareBarPos", "worldMarkerPos",
    "flarePoint", "flareRelPoint", "flareX", "flareY", "flareBarPoint", "flareBarRelPoint", "flareBarX", "flareBarY",
    "iconOrder", "targetOrder", "targetIconOrder", "raidIconOrder", "markerOrder",
    "flareOrder", "worldMarkerOrder", "flareIconOrder", "flaresOrder",
    "flareEnabled", "enabledFlares", "activeFlares",
    "focusClearModifier", "clearModifier", "modifier",
    "flareCycleKey", "cycleKey", "flareClearKey", "clearKey",
    "hudBorderStyle", "borderStyle", "isLocked",
    "useClassAccent", "accentColor", "interruptsEnabled", "interruptSpellID", "soundID",
}

local function FM_Today()
    if type(date) == "function" then
        local ok, s = pcall(date, "%d/%m/%Y %H:%M")
        if ok and type(s) == "string" then return s end
    end
    return "unknown"
end

function DM:ResolveFocusMarkerSettings(raw)
    if type(raw) ~= "table" then return nil, nil end
    local schema = (type(raw.profiles) == "table") and "ace" or "flat"
    local sources = FM_CollectCandidateSources(raw)
    if #sources > 0 then
        return sources[1], schema
    end
    return nil, nil
end

function DM:CaptureFocusMarkerSnapshot()
    if not self.db or type(_G.FocusMarkerDB) ~= "table" or next(_G.FocusMarkerDB) == nil then
        return false
    end
    local src, schema = self:ResolveFocusMarkerSettings(_G.FocusMarkerDB)
    if not src then return false end
    local data, n = {}, 0
    for _, k in ipairs(FOCUSMARKER_SNAPSHOT_KEYS) do
        local v = src[k]
        if v ~= nil then
            local c = SafeDeepCopyValue(v, 0)
            if c ~= nil then
                data[k] = c
                n = n + 1
            end
        end
    end
    local ver
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, v = pcall(C_AddOns.GetAddOnMetadata, "FocusMarker", "Version")
        if ok and type(v) == "string" and v ~= "" then ver = v end
    end
    local prev = type(self.db.legacyFocusMarker) == "table" and self.db.legacyFocusMarker or {}
    self.db.legacyFocusMarker = {
        schema        = schema,
        sourceVersion = ver or prev.sourceVersion or "unknown",
        capturedAt    = FM_Today(),
        keyCount      = n,
        data          = data,
        migratedAt    = prev.migratedAt,
        applied       = prev.applied,
    }
    return true
end

function DM:IsFocusMarkerInstalled()
    if not (C_AddOns and C_AddOns.GetAddOnInfo) then return false end
    local ok, name = pcall(C_AddOns.GetAddOnInfo, "FocusMarker")
    return ok and type(name) == "string" and name ~= ""
end

-- Returns true, appliedList on success; false, reason on failure.
function DM:MigrateFromFocusMarker(force)
    if not self.db then return false, "DynamicMarker settings are not ready yet." end
    if self.db.migratedFromFocusMarker == true and not force then
        return false, "Already imported."
    end

    if type(_G.FocusMarkerDB) == "table" and next(_G.FocusMarkerDB) ~= nil then
        self:CaptureFocusMarkerSnapshot()
    end
    local snap = type(self.db.legacyFocusMarker) == "table" and self.db.legacyFocusMarker or nil
    local liveOrSnap = (type(_G.FocusMarkerDB) == "table" and next(_G.FocusMarkerDB) ~= nil)
        and _G.FocusMarkerDB
        or (snap and type(snap.data) == "table" and snap.data or nil)
    if not liveOrSnap then
        return false, "No FocusMarker settings found. Enable FocusMarker for one /reload, then run /dm import."
    end

    local ok, applied, flags = self:RunOneTimeFocusMarkerMigration(liveOrSnap, self.db, force)
    if not ok then
        return false, applied or "FocusMarker import failed."
    end

    -- Backfill any omitted keys with current defaults and push migrated bar positions to Suite mirrors
    _G.DynamicMarkerDB = DeepCopyDefaults(DB_DEFAULTS, self.db)
    self.db = _G.DynamicMarkerDB
    if flags and flags.targetPos and self.SaveHUDPosition then
        pcall(self.SaveHUDPosition, self, self.targetBar, "TargetBar", true,
            self.db.targetBarPoint or "CENTER", self.db.targetBarRelPoint or "CENTER",
            self.db.targetBarX or 0, self.db.targetBarY or -140)
    end
    if flags and flags.flarePos and self.SaveHUDPosition then
        pcall(self.SaveHUDPosition, self, self.flareBar, "FlareBar", true,
            self.db.flareBarPoint or "CENTER", self.db.flareBarRelPoint or "CENTER",
            self.db.flareBarX or 0, self.db.flareBarY or -182)
    end
    if self.ApplyHUDPosition and not (InCombatLockdown and InCombatLockdown()) then
        if self.targetBar then self:ApplyHUDPosition(self.targetBar, "TargetBar", -140) end
        if self.flareBar then self:ApplyHUDPosition(self.flareBar, "FlareBar", -182) end
    end
    if self.RefreshTargetBar then self:RefreshTargetBar() end
    if self.RefreshFlareBar then self:RefreshFlareBar() end
    if self.SyncSecureFlareEngine then self:SyncSecureFlareEngine() end

    if type(self.db.legacyFocusMarker) == "table" then
        self.db.legacyFocusMarker.migratedAt = FM_Today()
        self.db.legacyFocusMarker.applied = applied
    end
    return true, applied
end

function DM:PrintFocusMarkerImportStatus()
    local snap = self.db and self.db.legacyFocusMarker
    local p = "|cFF38BDF8DynamicMarker|r: "
    if type(snap) ~= "table" then
        if self:IsFocusMarkerInstalled() then
            print(p .. "FocusMarker is installed but its settings have not been captured yet. Enable FocusMarker for one /reload, then run |cFFFFFFFF/dm import|r.")
        else
            print(p .. "No FocusMarker settings captured (FocusMarker not installed).")
        end
        return
    end
    print(p .. string.format("FocusMarker v%s settings captured %s (%s schema, %d keys).",
        tostring(snap.sourceVersion), tostring(snap.capturedAt), tostring(snap.schema), tonumber(snap.keyCount) or 0))
    if snap.migratedAt then
        print(p .. string.format("Imported %s: %s.", tostring(snap.migratedAt),
            (type(snap.applied) == "table" and #snap.applied > 0) and table.concat(snap.applied, ", ") or "nothing to change"))
    else
        print(p .. "Not imported yet - run |cFFFFFFFF/dm import|r.")
    end
end

local FreezeAddonInLoadDB

function DM:ScanConflicts()
    local activeConflicts = {}
    local session = _G.DynamicSuite_RaidTaintModalSession
    local quarantined = (type(session) == "table" and type(session.quarantined) == "table") and session.quarantined or nil
    for _, item in ipairs(CONFLICT_ADDONS) do
        if not item.isSoft and self.pendingConflictReload ~= item.name and not (quarantined and quarantined[item.name]) then
            local isLoaded = (item.name == "DecorVendor")
                and (C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" and C_AddOns.IsAddOnLoaded(item.name) == true)
                or false
            if self:IsAddonEnabled(item.name) or isLoaded then
                table.insert(activeConflicts, item)
            end
        end
    end
    self.activeConflicts = activeConflicts
    return activeConflicts
end

function DM:ResolveConflictUseDynamic(conflictAddonName)
    if conflictAddonName == "FocusMarker" then
        self:MigrateFromFocusMarker(true)
    end

    if C_AddOns and C_AddOns.DisableAddOn then
        pcall(C_AddOns.DisableAddOn, conflictAddonName, UnitName("player"))
        pcall(C_AddOns.DisableAddOn, conflictAddonName)
    end

    if Suite and type(Suite.SetAddonFrozen) == "function" then
        pcall(Suite.SetAddonFrozen, conflictAddonName, true)
    end
    if type(FreezeAddonInLoadDB) == "function" then
        FreezeAddonInLoadDB(conflictAddonName)
    end
    if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.global) == "table" then
        _G.DynamicSuiteDB.global.acknowledgedConflicts = _G.DynamicSuiteDB.global.acknowledgedConflicts or {}
        _G.DynamicSuiteDB.global.acknowledgedConflicts[tostring(conflictAddonName) .. "_DynamicMarker"] = "USE_DYNAMIC"
    end
    if conflictAddonName == "DecorVendor" then
        _G.DynamicSuite_RaidTaintModalSession = type(_G.DynamicSuite_RaidTaintModalSession) == "table" and _G.DynamicSuite_RaidTaintModalSession or {}
        _G.DynamicSuite_RaidTaintModalSession.quarantined = _G.DynamicSuite_RaidTaintModalSession.quarantined or {}
        _G.DynamicSuite_RaidTaintModalSession.quarantined["DecorVendor"] = true
    end

    self.pendingConflictReload = conflictAddonName
    self:ScanConflicts()
    self:RefreshAll()
    if conflictAddonName == "DecorVendor" then
        print("|cFF38BDF8DynamicMarker|r: Disabled |cFFFFFFFFDecorVendor|r and set it to |cFF34D399Never|r across all zone profiles. Please completely |cFFF97316Exit & Restart|r World of Warcraft now (/reload alone will not clear SetRaidTarget taint).")
    else
        print(string.format("|cFF38BDF8DynamicMarker|r: Imported settings and disabled |cFFFFFFFF%s|r. Click |cFF10B981[Reload UI]|r to complete.", conflictAddonName))
    end
end

function DM:ResolveConflictKeepOther(conflictAddonName)
    if C_AddOns and C_AddOns.DisableAddOn and C_AddOns.GetAddOnInfo and C_AddOns.GetAddOnInfo("DynamicMarker") then
        pcall(C_AddOns.DisableAddOn, "DynamicMarker", UnitName("player"))
        pcall(C_AddOns.DisableAddOn, "DynamicMarker")
    end
    _G.DynamicSuiteDB = _G.DynamicSuiteDB or {}
    _G.DynamicSuiteDB.disabledModules = _G.DynamicSuiteDB.disabledModules or {}
    _G.DynamicSuiteDB.disabledModules["DynamicMarker"] = true
    if _G.DynamicSuiteDB.global then
        _G.DynamicSuiteDB.global.disabledModules = _G.DynamicSuiteDB.global.disabledModules or {}
        _G.DynamicSuiteDB.global.disabledModules["DynamicMarker"] = true
    end
    self.pendingConflictReload = "DynamicMarker"
    self:RefreshAll()
    print(string.format("|cFF38BDF8DynamicMarker|r: Kept |cFFFFFFFF%s|r and staged |cFFFFFFFFDynamicMarker|r for disable. Click |cFF10B981[Reload UI]|r to apply.", conflictAddonName))
end

local function IsAddonFrozenInLoadDB(addonName)
    local dl = _G.DynamicLoadDB
    if type(dl) ~= "table" then return false end
    if (dl.addonStates and dl.addonStates[addonName] == "FROZEN")
        or (dl.frozenAddons and dl.frozenAddons[addonName] == true) then
        return true
    end
    if type(dl.globalData) == "table" then
        if (dl.globalData.addonStates and dl.globalData.addonStates[addonName] == "FROZEN")
            or (dl.globalData.frozenAddons and dl.globalData.frozenAddons[addonName] == true) then
            return true
        end
    end
    return false
end

FreezeAddonInLoadDB = function(addonName)
    if type(_G.DynamicLoadDB) ~= "table" then return end
    local function ApplyFreeze(tbl)
        if type(tbl) ~= "table" then return end
        tbl.addonStates = type(tbl.addonStates) == "table" and tbl.addonStates or {}
        tbl.frozenAddons = type(tbl.frozenAddons) == "table" and tbl.frozenAddons or {}
        tbl.lockedAddons = type(tbl.lockedAddons) == "table" and tbl.lockedAddons or {}
        tbl.addonStates[addonName] = "FROZEN"
        tbl.frozenAddons[addonName] = true
        tbl.lockedAddons[addonName] = nil
        if type(tbl.profiles) == "table" then
            for _, prof in pairs(tbl.profiles) do
                if type(prof) == "table" and type(prof.addons) == "table" then
                    prof.addons[addonName] = nil
                end
            end
        end
        if type(tbl.zones) == "table" then
            for _, zTbl in pairs(tbl.zones) do
                if type(zTbl) == "table" then
                    zTbl[addonName] = nil
                end
            end
        end
        for _, zKey in ipairs({ "outdoor", "delves", "dungeons", "raid", "pvp" }) do
            if type(tbl[zKey]) == "table" then
                tbl[zKey][addonName] = nil
            end
        end
    end
    ApplyFreeze(_G.DynamicLoadDB)
    ApplyFreeze(_G.DynamicLoadDB.globalData)
    if type(_G.DynamicLoadDB.charData) == "table" then
        for _, cd in pairs(_G.DynamicLoadDB.charData) do
            ApplyFreeze(cd)
        end
    end
end

function DM:ScanAdvisoryConflicts()
    local advisories = {}
    local dismissed = (self.db and type(self.db.dismissedAdvisoryConflicts) == "table") and self.db.dismissedAdvisoryConflicts or nil
    for _, item in ipairs(ADVISORY_CONFLICT_ADDONS) do
        local isDismissed = dismissed and dismissed[item.name] == true
        local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(item.name) == true
        local isActive = self:IsAddonEnabled(item.name) or isLoaded
        if isActive and not isDismissed and not IsAddonFrozenInLoadDB(item.name) and self.pendingConflictReload ~= item.name then
            table.insert(advisories, item)
        end
    end
    self.activeAdvisoryConflicts = advisories
    return advisories
end

function DM:ResolveAdvisoryDisable(addonName)
    if not addonName or addonName == "" then return end
    if C_AddOns and C_AddOns.DisableAddOn then
        pcall(C_AddOns.DisableAddOn, addonName, UnitName("player"))
        pcall(C_AddOns.DisableAddOn, addonName)
    end
    if Suite and type(Suite.SetAddonFrozen) == "function" then
        pcall(Suite.SetAddonFrozen, addonName, true)
    end
    FreezeAddonInLoadDB(addonName)
    if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.global) == "table" then
        _G.DynamicSuiteDB.global.acknowledgedConflicts = _G.DynamicSuiteDB.global.acknowledgedConflicts or {}
        _G.DynamicSuiteDB.global.acknowledgedConflicts[tostring(addonName) .. "_DynamicMarker"] = "USE_DYNAMIC"
    end
    self.pendingConflictReload = addonName
    self:ScanAdvisoryConflicts()
    self:RefreshAll()
    print(string.format("|cFF38BDF8DynamicMarker|r: Disabled |cFFFFFFFF%s|r and set it to Never in DynamicLoad. Click |cFF10B981[Reload UI]|r (or completely restart the game if Blizzard's /tm lockout already occurred).", addonName))
end

function DM:DismissAdvisoryConflict(addonName)
    if not addonName or addonName == "" then return end
    if self.db then
        self.db.dismissedAdvisoryConflicts = type(self.db.dismissedAdvisoryConflicts) == "table" and self.db.dismissedAdvisoryConflicts or {}
        self.db.dismissedAdvisoryConflicts[addonName] = true
    end
    self:ScanAdvisoryConflicts()
    self:RefreshAll()
    print(string.format("|cFF38BDF8DynamicMarker|r: Dismissed compatibility notice for |cFFFFFFFF%s|r.", addonName))
end

-- ============================================================================
-- 8. SECURE WORLD FLARE ENGINE (OPTIONAL CYCLE / CLEAR HOTKEYS)
-- ============================================================================

function DM:GetActiveFlareSequence()
    local seq = {}
    if not self.db then return { 1, 2, 3, 4, 5, 6, 7, 8 } end
    local order = SanitizePermutation1To8(self.db.flareOrder)
    self.db.flareOrder = order
    local enabled = type(self.db.flareEnabled) == "table" and self.db.flareEnabled or {}
    for _, rawID in ipairs(order) do
        local flareID = tonumber(rawID)
        if flareID and WORLD_FLARES[flareID] then
            local isOn = enabled[flareID]
            if isOn == nil then isOn = enabled[tostring(flareID)] end
            if isOn ~= false then
                table.insert(seq, flareID)
            end
        end
    end
    if #seq == 0 then
        table.insert(seq, order[1] or 1)
    end
    return seq
end

function DM:GetActiveFlareSequenceSummary()
    local seq = self:GetActiveFlareSequence()
    local parts = {}
    for _, id in ipairs(seq) do
        local info = WORLD_FLARES[id]
        if info then
            table.insert(parts, info.short)
        end
    end
    return table.concat(parts, " -> ")
end

function DM:ConfigureSecureButtonClicks(btn)
    if not btn then return end
    self.secureButtons = self.secureButtons or {}
    self.secureButtons[btn] = true
    if InCombatLockdown() then
        self.pendingSecureClickSync = true
        return
    end
    local useKeyDown = (C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("ActionButtonUseKeyDown"))
        or (type(GetCVarBool) == "function" and GetCVarBool("ActionButtonUseKeyDown"))
        or false
    btn:SetAttribute("useOnKeyDown", useKeyDown)
    btn:RegisterForClicks("AnyDown", "AnyUp")
end

function DM:RefreshAllSecureButtonClicks()
    if InCombatLockdown() then
        self.pendingSecureClickSync = true
        return
    end
    self.pendingSecureClickSync = false
    if not self.secureButtons then return end
    local useKeyDown = (C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("ActionButtonUseKeyDown"))
        or (type(GetCVarBool) == "function" and GetCVarBool("ActionButtonUseKeyDown"))
        or false
    for btn in pairs(self.secureButtons) do
        btn:SetAttribute("useOnKeyDown", useKeyDown)
        btn:RegisterForClicks("AnyDown", "AnyUp")
    end
end

function DM:InitSecureFlareButtons()
    if self.flareCycleBtn and self.flareClearBtn then return end
    if InCombatLockdown() then
        self.pendingFlareEngineSync = true
        self.pendingKeybindSync = true
        return
    end

    local header = self.flareSecureHeader or _G.DynamicMarkerFlareHeader or CreateFrame("Frame", "DynamicMarkerFlareHeader", UIParent, "SecureHandlerBaseTemplate")
    self.flareSecureHeader = header

    -- 1. Cycle Ground Flare Secure Button (anchored on-screen at 0 alpha / mouse-disabled so Retail 12.1.5 SetOverrideBindingClick never culls it)
    local cycleBtn = _G.DynamicMarkerFlareCycleBtn or CreateFrame("Button", "DynamicMarkerFlareCycleBtn", UIParent, "SecureActionButtonTemplate")
    cycleBtn:SetSize(1, 1)
    cycleBtn:ClearAllPoints()
    cycleBtn:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    cycleBtn:SetAlpha(0)
    cycleBtn:EnableMouse(false)
    cycleBtn:Show()
    self:ConfigureSecureButtonClicks(cycleBtn)
    cycleBtn:SetAttribute("type", "macro")
    cycleBtn:SetAttribute("type1", "macro")
    cycleBtn:SetAttribute("macrotext", "/wm [@cursor] 1")
    cycleBtn:SetAttribute("macrotext1", "/wm [@cursor] 1")
    cycleBtn:SetAttribute("action", "set")
    cycleBtn:SetAttribute("action1", "set")
    cycleBtn:SetAttribute("marker", 1)
    cycleBtn:SetAttribute("marker1", 1)

    if not cycleBtn._dmWrapped and SecureHandlerWrapScript and header then
        cycleBtn._dmWrapped = true
        SecureHandlerWrapScript(cycleBtn, "OnClick", header, [=[
            local useDown = self:GetAttribute("useOnKeyDown") and true or false
            if down ~= nil then
                local isDown = down and true or false
                if isDown ~= useDown then return false end
            end
            local count = self:GetAttribute("flareSeqCount") or 0
            local m = 1
            if count > 0 then
                local idx = self:GetAttribute("flareSeqIdx") or 1
                if idx < 1 or idx > count then idx = 1 end
                m = self:GetAttribute("flareSlot" .. idx) or 1
                self:SetAttribute("flareSeqIdx", (idx % count) + 1)
            elseif _order and #_order > 0 then
                if not _idx or _idx < 1 or _idx > #_order then _idx = 1 end
                m = _order[_idx] or 1
                _idx = (_idx % #_order) + 1
            end
            local cmd = "/wm [@cursor] " .. m
            self:SetAttribute("marker", m)
            self:SetAttribute("marker1", m)
            self:SetAttribute("macrotext", cmd)
            self:SetAttribute("macrotext1", cmd)
        ]=])
    end

    -- 2. Clear All Flares Secure Button (anchored on-screen at 0 alpha / mouse-disabled so Retail 12.1.5 SetOverrideBindingClick never culls it)
    local clearBtn = _G.DynamicMarkerFlareClearBtn or CreateFrame("Button", "DynamicMarkerFlareClearBtn", UIParent, "SecureActionButtonTemplate")
    clearBtn:SetSize(1, 1)
    clearBtn:ClearAllPoints()
    clearBtn:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    clearBtn:SetAlpha(0)
    clearBtn:EnableMouse(false)
    clearBtn:Show()
    self:ConfigureSecureButtonClicks(clearBtn)
    local clearCmd = "/cwm all"
    clearBtn:SetAttribute("type", "macro")
    clearBtn:SetAttribute("type1", "macro")
    clearBtn:SetAttribute("macrotext", clearCmd)
    clearBtn:SetAttribute("macrotext1", clearCmd)
    clearBtn:SetAttribute("action", "clear")
    clearBtn:SetAttribute("action1", "clear")
    clearBtn:SetAttribute("marker", 0)
    clearBtn:SetAttribute("marker1", 0)

    if not clearBtn._dmWrapped and SecureHandlerWrapScript and header then
        clearBtn._dmWrapped = true
        SecureHandlerWrapScript(clearBtn, "OnClick", header, [=[
            local useDown = self:GetAttribute("useOnKeyDown") and true or false
            if down ~= nil then
                local isDown = down and true or false
                if isDown ~= useDown then return false end
            end
        ]=])
    end

    self.flareCycleBtn = cycleBtn
    self.flareClearBtn = clearBtn

    self:SyncSecureFlareEngine()
    self:ApplyFlareKeybinds()
end

function DM:SyncSecureFlareEngine()
    if not self.flareCycleBtn or not self.flareClearBtn then return end
    if InCombatLockdown() then
        self.pendingFlareEngineSync = true
        return
    end
    self.pendingFlareEngineSync = false

    local seq = self:GetActiveFlareSequence()
    local count = #seq
    local listStr = table.concat(seq, ", ")

    local cycleBtn = self.flareCycleBtn
    cycleBtn:SetAttribute("flareSeq", table.concat(seq, ","))
    cycleBtn:SetAttribute("flareSeqCount", count)
    cycleBtn:SetAttribute("flareSeqIdx", 1)
    for idx = 1, 8 do
        cycleBtn:SetAttribute("flareSlot" .. idx, seq[idx] or seq[1] or 1)
    end

    if self.flareSecureHeader and self.flareSecureHeader.Execute then
        self.flareSecureHeader:Execute(string.format([=[
            _order = newtable(%s)
            _idx = 1
        ]=], listStr))
    end

    local firstWM = seq[1] or 1
    local firstCmd = "/wm [@cursor] " .. firstWM
    cycleBtn:SetAttribute("type", "macro")
    cycleBtn:SetAttribute("type1", "macro")
    cycleBtn:SetAttribute("macrotext", firstCmd)
    cycleBtn:SetAttribute("macrotext1", firstCmd)
    cycleBtn:SetAttribute("action", "set")
    cycleBtn:SetAttribute("action1", "set")
    cycleBtn:SetAttribute("marker", firstWM)
    cycleBtn:SetAttribute("marker1", firstWM)

    local clearCmd = "/cwm all"
    local clearBtn = self.flareClearBtn
    clearBtn:SetAttribute("type", "macro")
    clearBtn:SetAttribute("type1", "macro")
    clearBtn:SetAttribute("macrotext", clearCmd)
    clearBtn:SetAttribute("macrotext1", clearCmd)
    clearBtn:SetAttribute("action", "clear")
    clearBtn:SetAttribute("action1", "clear")
    clearBtn:SetAttribute("marker", 0)
    clearBtn:SetAttribute("marker1", 0)
end

function DM:ApplyFlareKeybinds()
    if not self.flareCycleBtn or not self.flareClearBtn then
        if not InCombatLockdown() then
            self:InitSecureFlareButtons()
        else
            self.pendingKeybindSync = true
        end
        if not self.flareCycleBtn or not self.flareClearBtn then return end
    end
    if InCombatLockdown() then
        self.pendingKeybindSync = true
        return
    end
    self.pendingKeybindSync = false

    self.flareCycleBtn:Show()
    self.flareClearBtn:Show()
    ClearOverrideBindings(self.flareCycleBtn)
    ClearOverrideBindings(self.flareClearBtn)

    if IsModuleDisabledInSuite("DynamicMarker") then
        return
    end

    local cycleKey = self.db and self.db.flareCycleKey
    if cycleKey and cycleKey ~= "" and cycleKey ~= "NONE" then
        SetOverrideBindingClick(self.flareCycleBtn, true, cycleKey, "DynamicMarkerFlareCycleBtn", "LeftButton")
    end

    local clearKey = self.db and self.db.flareClearKey
    if clearKey and clearKey ~= "" and clearKey ~= "NONE" then
        SetOverrideBindingClick(self.flareClearBtn, true, clearKey, "DynamicMarkerFlareClearBtn", "LeftButton")
    end
end

-- ============================================================================
-- 9. SMART MACRO GENERATOR ([DynamicMark] & [DynamicKick])
-- ============================================================================

local FOCUS_MACRO_NAME = "DynamicMark"
local KICK_MACRO_NAME  = "DynamicKick"

function DM:FindFocusMacroIndex()
    local idx = GetMacroIndexByName(FOCUS_MACRO_NAME)
    if idx and idx > 0 then
        return idx, FOCUS_MACRO_NAME
    end
    local legacy1 = GetMacroIndexByName("FocusMarker")
    if legacy1 and legacy1 > 0 then
        return legacy1, "FocusMarker"
    end
    local legacy2 = GetMacroIndexByName("FocusMark")
    if legacy2 and legacy2 > 0 then
        return legacy2, "FocusMark"
    end
    return 0, nil
end

function DM:FindActiveKickMacroIndex()
    if not GetMacroIndexByName then return 0, nil end
    local activeSpell, classSpells = self:ResolveActiveInterruptSpell()
    local mode = (self.db and self.db.kickSpecMode) or "SMART_SWAP"
    if mode == "SEPARATE" and classSpells and #classSpells > 1 and activeSpell then
        local sepName = "DKick" .. activeSpell:gsub("%s+", ""):sub(1, 10)
        local sepIdx = GetMacroIndexByName(sepName)
        if sepIdx and sepIdx > 0 then
            return sepIdx, sepName
        end
    end
    local idx = GetMacroIndexByName(KICK_MACRO_NAME)
    if idx and idx > 0 then
        return idx, KICK_MACRO_NAME
    end
    if classSpells and #classSpells > 1 then
        for _, sp in ipairs(classSpells) do
            local mName = "DKick" .. sp:gsub("%s+", ""):sub(1, 10)
            local mIdx = GetMacroIndexByName(mName)
            if mIdx and mIdx > 0 then
                return mIdx, mName
            end
        end
    end
    return 0, nil
end

function DM:IsMacroOnActionBar(macroName)
    if not GetActionInfo then return false, nil end
    local altKickName = nil
    if macroName == KICK_MACRO_NAME then
        local _, foundName = self:FindActiveKickMacroIndex()
        if foundName and foundName ~= KICK_MACRO_NAME then
            altKickName = foundName
        end
    end
    for slot = 1, 180 do
        local actionType, id = GetActionInfo(slot)
        if actionType == "macro" then
            local mText = GetActionText and GetActionText(slot)
            local mName = (id and GetMacroInfo and (select(1, GetMacroInfo(id)))) or nil
            if mText == macroName or mName == macroName then
                return true, slot
            end
            if altKickName and (mText == altKickName or mName == altKickName) then
                return true, slot
            end
            if macroName == FOCUS_MACRO_NAME and (mText == "FocusMarker" or mName == "FocusMarker" or mText == "FocusMark" or mName == "FocusMark") then
                return true, slot
            end
        end
    end
    return false, nil
end

function DM:BuildFocusMarkerMacroBody()
    local iconIndex = (self.db and self.db.focusIcon) or 8
    local mod = (self.db and self.db.focusClearModifier) or "NONE"
    local scope = (self.db and self.db.groupScope) or "BOTH"
    local targetMode = (self.db and self.db.focusTargetMode) or "MOUSEOVER_TARGET"

    local lines = { "#showtooltip" }
    if mod ~= "NONE" then
        table.insert(lines, string.format("/clearfocus [mod:%s]", mod))
    end
    if targetMode == "TARGET_ONLY" then
        table.insert(lines, "/focus [@target,exists,nodead][]")
    else
        table.insert(lines, "/focus [@mouseover,exists,nodead][]")
    end

    local tmCond = "[@focus,exists]"
    if scope == "PARTY" then
        tmCond = "[nogroup,@focus,exists][group:party,@focus,exists]"
    elseif scope == "RAID" then
        tmCond = "[group:raid,@focus,exists]"
    end
    table.insert(lines, string.format("/tm %s ~%d", tmCond, iconIndex))

    return table.concat(lines, "\n")
end

function DM:ResolveActiveInterruptSpell()
    local _, classToken = UnitClass("player")
    local entry = classToken and CLASS_INTERRUPTS[classToken]
    if not entry then
        return "Kick", { "Kick" }, true, nil, "Kick"
    end

    local specIndex = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()) or (GetSpecialization and GetSpecialization())
    local specID, specName = nil, nil
    if specIndex then
        if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
            specID, specName = C_SpecializationInfo.GetSpecializationInfo(specIndex)
        elseif GetSpecializationInfo then
            specID, specName = GetSpecializationInfo(specIndex)
        end
    end

    local chosen = entry.default
    if specID and entry.bySpecID and entry.bySpecID[specID] then
        chosen = entry.bySpecID[specID]
    end

    -- Check specialization overrides for multi-kick classes (Druid Solar Beam vs Skull Bash, Hunter Muzzle vs Counter Shot)
    if classToken == "DRUID" then
        if specID == 102 then
            chosen = "Solar Beam"
        else
            chosen = "Skull Bash"
        end
    elseif classToken == "HUNTER" then
        if specID == 255 then
            chosen = "Muzzle"
        else
            chosen = "Counter Shot"
        end
    end

    local hasActiveKick = true
    local offSpecDisplay = chosen
    if specID and HEALER_NO_KICK_SPECS[specID] then
        local spellID = SPELL_NAME_TO_ID[chosen]
        local isKnown = false
        if spellID then
            if C_SpellBook and C_SpellBook.IsSpellKnown then
                local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
                local ok, res = pcall(C_SpellBook.IsSpellKnown, spellID, bank)
                if ok and res then isKnown = true end
            end
            if not isKnown and C_SpellBook and C_SpellBook.IsSpellInSpellBook then
                local ok, res = pcall(C_SpellBook.IsSpellInSpellBook, spellID)
                if ok and res then isKnown = true end
            end
            if not isKnown and IsPlayerSpell then
                local ok, res = pcall(IsPlayerSpell, spellID)
                if ok and res then isKnown = true end
            end
        end
        if not isKnown then
            hasActiveKick = false
            if classToken == "DRUID" and specID == 105 then
                offSpecDisplay = "Skull Bash / Solar Beam"
            end
        end
    end

    return chosen, entry.spells, hasActiveKick, specName, offSpecDisplay
end

function DM:BuildDynamicKickMacroBody(overrideSpell)
    local spellName = overrideSpell or self:ResolveActiveInterruptSpell()
    local prioKey = (self.db and self.db.kickPriority) or "SMART_AUTOTARGET"

    if prioKey == "SMART_AUTOTARGET" then
        return "#showtooltip\n" ..
            "/cast [@mouseover,exists,nodead,harm] [@focus,exists,nodead,harm] " .. spellName .. "\n" ..
            "/stopmacro [@mouseover,exists,nodead,harm][@focus,exists,nodead,harm]\n" ..
            "/focus target\n" ..
            "/cleartarget\n" ..
            "/targetenemy\n" ..
            "/cast " .. spellName .. "\n" ..
            "/target focus\n" ..
            "/clearfocus\n" ..
            "/startattack"
    elseif prioKey == "FOCUS_MO_TARGET" or prioKey == "FOCUS_MOUSEOVER_TARGET" then
        return "#showtooltip " .. spellName .. "\n/stopcasting\n/cast [@focus,exists,nodead,harm][@mouseover,exists,nodead,harm][] " .. spellName
    elseif prioKey == "FOCUS_ONLY" then
        return "#showtooltip " .. spellName .. "\n/stopcasting\n/cast [@focus,exists,nodead,harm] " .. spellName
    else
        return "#showtooltip " .. spellName .. "\n/stopcasting\n/cast [@mouseover,exists,nodead,harm][@focus,exists,nodead,harm][] " .. spellName
    end
end

function DM:PatchFocusMarkerMacroBody(existingBody)
    if type(existingBody) ~= "string" or existingBody == "" then
        return self:BuildFocusMarkerMacroBody(), false
    end

    local iconIndex = (self.db and self.db.focusIcon) or 8
    local mod = (self.db and self.db.focusClearModifier) or "NONE"
    local scope = (self.db and self.db.groupScope) or "BOTH"

    local tmCond = "[@focus,exists]"
    if scope == "PARTY" then
        tmCond = "[nogroup,@focus,exists][group:party,@focus,exists]"
    elseif scope == "RAID" then
        tmCond = "[group:raid,@focus,exists]"
    end
    local desiredTmLine = string.format("/tm %s ~%d", tmCond, iconIndex)
    local desiredClearLine = (mod ~= "NONE") and string.format("/clearfocus [mod:%s]", mod) or nil

    local normalized = existingBody:gsub("\r\n", "\n"):gsub("\r", "\n")
    local rawLines = {}
    for line in (normalized .. "\n"):gmatch("(.-)\n") do
        table.insert(rawLines, line)
    end
    if #rawLines > 0 and rawLines[#rawLines] == "" then
        table.remove(rawLines, #rawLines)
    end

    local outLines = {}
    local replacedTm = false
    local replacedClear = false
    local showTooltipIdx = nil

    for _, line in ipairs(rawLines) do
        local trimmed = line:match("^%s*(.-)%s*$") or ""
        local lower = trimmed:lower()
        if lower:match("^/tm%s") or lower == "/tm" then
            if not replacedTm then
                table.insert(outLines, desiredTmLine)
                replacedTm = true
            end
        elseif lower:match("^/clearfocus%s") or lower == "/clearfocus" then
            if desiredClearLine and not replacedClear then
                table.insert(outLines, desiredClearLine)
                replacedClear = true
            elseif not desiredClearLine then
                replacedClear = true
            end
        else
            table.insert(outLines, line)
            if not showTooltipIdx and lower:match("^#showtooltip") then
                showTooltipIdx = #outLines
            end
        end
    end

    if desiredClearLine and not replacedClear then
        local insertPos = showTooltipIdx and (showTooltipIdx + 1) or 1
        table.insert(outLines, insertPos, desiredClearLine)
    end
    if not replacedTm then
        table.insert(outLines, desiredTmLine)
    end

    local patched = table.concat(outLines, "\n")
    if #patched > 255 then
        return existingBody, true
    end
    return patched, false
end

local function ResolveFocusMacroEditIcon(idx)
    local _, iconTex = GetMacroInfo(idx)
    if iconTex == nil or iconTex == "" or iconTex == 134400 or iconTex == "INV_MISC_QUESTIONMARK" then
        return "INV_MISC_QUESTIONMARK"
    end
    return nil
end

function DM:CreateOrUpdateFocusMarkerMacro(modeOrInitiated, customBody)
    local isExplicitUser = (modeOrInitiated == true or modeOrInitiated == "USER" or modeOrInitiated == "USER_FORCE")
    local isSettingChange = (modeOrInitiated == "SETTING")

    if InCombatLockdown() then
        self.pendingFocusMacroSync = true
        if isExplicitUser then
            print("|cFF38BDF8DynamicMarker|r: Cannot modify macros in combat. Queued for combat exit.")
        end
        return false
    end
    self.pendingFocusMacroSync = false

    local targetMode = (self.db and self.db.focusTargetMode) or "MOUSEOVER_TARGET"
    local idx, foundName = self:FindFocusMacroIndex()

    if targetMode == "MANUAL" and idx and idx > 0 then
        if not isExplicitUser and not isSettingChange then
            -- Passive login / reload / auto-sync: keep custom macro untouched.
            return true
        end
        if isSettingChange then
            local _, _, existingBody = GetMacroInfo(idx)
            local patchedBody, overLimit = self:PatchFocusMarkerMacroBody(existingBody)
            if overLimit then
                print("|cFFF59E0BDynamicMarker|r: Custom [DynamicMark] macro exceeds 255 characters after patching; kept your existing macro untouched.")
                return false
            end
            EditMacro(idx, FOCUS_MACRO_NAME, ResolveFocusMacroEditIcon(idx), patchedBody)
            return true
        end
    end

    local body = self:BuildFocusMarkerMacroBody()
    local isCustomSave = false
    if isExplicitUser and targetMode == "MANUAL" and type(customBody) == "string" then
        local trimmed = customBody:sub(1, 255)
        if trimmed:match("%S") then
            body = trimmed
            isCustomSave = true
        end
    end

    if idx and idx > 0 then
        EditMacro(idx, FOCUS_MACRO_NAME, ResolveFocusMacroEditIcon(idx), body)
        if isExplicitUser then
            if isCustomSave then
                print(string.format("|cFF38BDF8DynamicMarker|r: Saved custom General Macro |cFFFFFFFF[%s]|r.", FOCUS_MACRO_NAME))
            elseif foundName and foundName ~= FOCUS_MACRO_NAME then
                print(string.format("|cFF22C55EDynamicMarker|r: Migrated [%s] in-place to General Macro |cFFFFFFFF[%s]|r (Icon: %s).", foundName, FOCUS_MACRO_NAME, RAID_ICONS[self.db.focusIcon].label))
            else
                print(string.format("|cFF38BDF8DynamicMarker|r: Updated General Macro |cFFFFFFFF[%s]|r (Icon: %s).", FOCUS_MACRO_NAME, RAID_ICONS[self.db.focusIcon].label))
            end
        end
        return true
    elseif isExplicitUser then
        local numGlobal = GetNumMacros()
        if numGlobal >= (MAX_ACCOUNT_MACROS or 120) then
            print("|cFFF87171DynamicMarker|r: General Macros are full! Please free 1 General Macro slot and try again.")
            return false
        end
        local newIdx = CreateMacro(FOCUS_MACRO_NAME, "INV_MISC_QUESTIONMARK", body, false)
        if newIdx and newIdx > 0 then
            if isCustomSave then
                print(string.format("|cFF22C55EDynamicMarker|r: Created custom General Macro |cFFFFFFFF[%s]|r! Click Step 2 to place it on your action bar.", FOCUS_MACRO_NAME))
            else
                print(string.format("|cFF22C55EDynamicMarker|r: Created General Macro |cFFFFFFFF[%s]|r! Click Step 2 to place it on your action bar.", FOCUS_MACRO_NAME))
            end
            return true
        end
    end
    return false
end

function DM:CreateOrUpdateDynamicKickMacro(userInitiated)
    if InCombatLockdown() then
        self.pendingKickMacroSync = true
        if userInitiated then
            print("|cFF38BDF8DynamicMarker|r: Cannot modify macros in combat. Queued for combat exit.")
        end
        return false
    end
    self.pendingKickMacroSync = false

    local activeSpell, classSpells = self:ResolveActiveInterruptSpell()
    local mode = (self.db and self.db.kickSpecMode) or "SMART_SWAP"

    if mode == "SEPARATE" and userInitiated then
        local createdCount = 0
        for _, sp in ipairs(classSpells) do
            local mName = (#classSpells > 1) and ("DKick" .. sp:gsub("%s+", ""):sub(1, 10)) or KICK_MACRO_NAME
            local mBody = self:BuildDynamicKickMacroBody(sp)
            local idx = GetMacroIndexByName(mName)
            if idx and idx > 0 then
                EditMacro(idx, mName, "INV_MISC_QUESTIONMARK", mBody)
                createdCount = createdCount + 1
            else
                local _, numChar = GetNumMacros()
                if numChar < (MAX_CHARACTER_MACROS or 30) then
                    CreateMacro(mName, "INV_MISC_QUESTIONMARK", mBody, true)
                    createdCount = createdCount + 1
                end
            end
        end
        print(string.format("|cFF22C55EDynamicMarker|r: Synced %d Per-Spell Character Interrupt Macro(s).", createdCount))
        return true
    end

    local body = self:BuildDynamicKickMacroBody(activeSpell)
    local idx = GetMacroIndexByName(KICK_MACRO_NAME)
    if idx and idx > 0 then
        EditMacro(idx, KICK_MACRO_NAME, "INV_MISC_QUESTIONMARK", body)
        if userInitiated then
            print(string.format("|cFF38BDF8DynamicMarker|r: Updated Character Macro |cFFFFFFFF[%s]|r -> |cFF38BDF8%s|r.", KICK_MACRO_NAME, activeSpell))
        end
        return true
    elseif userInitiated then
        local _, numChar = GetNumMacros()
        if numChar >= (MAX_CHARACTER_MACROS or 30) then
            print("|cFFF87171DynamicMarker|r: Character Macros are full! Please free 1 Character Macro slot and try again.")
            return false
        end
        local newIdx = CreateMacro(KICK_MACRO_NAME, "INV_MISC_QUESTIONMARK", body, true)
        if newIdx and newIdx > 0 then
            print(string.format("|cFF22C55EDynamicMarker|r: Created Character Macro |cFFFFFFFF[%s]|r (|cFF38BDF8%s|r)! Click Step 2 to place it on your action bar.", KICK_MACRO_NAME, activeSpell))
            return true
        end
    end
    return false
end

-- ============================================================================
-- 10. CHAT ANNOUNCEMENT ENGINE & STATUS BAR FORMATTER
-- ============================================================================

function DM:AnnounceFocusIcon(isReadyCheck)
    if not self.db then return end
    if self.db.chatAnnounce == "MUTED" then
        if not isReadyCheck then
            local iconInfo = RAID_ICONS[self.db.focusIcon] or RAID_ICONS[8]
            print(string.format("|cFF38BDF8DynamicMarker|r: Focus Icon set to %s (Muted).", iconInfo.label))
        end
        return
    end

    local iconIndex = self.db.focusIcon or 8
    local iconInfo = RAID_ICONS[iconIndex] or RAID_ICONS[8]
    local msg = (isReadyCheck and "[Ready Check] " or "") .. "My Focus Icon is {rt" .. iconIndex .. "} (" .. iconInfo.name .. ")"
    local chanPref = self.db.chatChannel or "PARTY_INSTANCE"
    local SendMsg = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage

    if (C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()) or (IsEncounterInProgress and IsEncounterInProgress()) then
        if not isReadyCheck then
            print(string.format("|cFF38BDF8DynamicMarker|r: Focus Icon set to %s (Encounter chat lockdown).", iconInfo.label))
        end
        return
    end

    if chanPref == "SAY" then
        if IsInInstance() then
            pcall(SendMsg, msg, "SAY")
        elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            pcall(SendMsg, msg, "INSTANCE_CHAT")
        elseif IsInGroup(LE_PARTY_CATEGORY_HOME) or IsInGroup() then
            pcall(SendMsg, msg, IsInRaid() and "RAID" or "PARTY")
        elseif not isReadyCheck then
            print(string.format("|cFF38BDF8DynamicMarker|r: Focus Icon set to %s.", iconInfo.label))
        end
    elseif chanPref == "PARTY" then
        if IsInRaid() then
            if not isReadyCheck then
                print(string.format("|cFF38BDF8DynamicMarker|r: Focus Icon set to %s (Silent in Raid).", iconInfo.label))
            end
        elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            pcall(SendMsg, msg, "INSTANCE_CHAT")
        elseif IsInGroup(LE_PARTY_CATEGORY_HOME) or IsInGroup() then
            pcall(SendMsg, msg, "PARTY")
        elseif not isReadyCheck then
            print(string.format("|cFF38BDF8DynamicMarker|r: Focus Icon set to %s.", iconInfo.label))
        end
    else
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            pcall(SendMsg, msg, "INSTANCE_CHAT")
        elseif IsInRaid() then
            pcall(SendMsg, msg, "RAID")
        elseif IsInGroup(LE_PARTY_CATEGORY_HOME) or IsInGroup() then
            pcall(SendMsg, msg, "PARTY")
        elseif not isReadyCheck then
            print(string.format("|cFF38BDF8DynamicMarker|r: Focus Icon set to %s.", iconInfo.label))
        end
    end
end

function DM:SetFocusIcon(iconIndex, announce)
    iconIndex = tonumber(iconIndex) or 8
    if iconIndex < 1 or iconIndex > 8 then iconIndex = 8 end
    self.db.focusIcon = iconIndex

    self:CreateOrUpdateFocusMarkerMacro("SETTING")
    self:RefreshTargetBar()
    self:RefreshAll()

    if announce then
        self:AnnounceFocusIcon(false)
    end
end

function DM:FormatKeyShort(keyStr)
    if not keyStr or keyStr == "" or keyStr == "NONE" then
        return "Unbound"
    end
    return keyStr:gsub("BUTTON", "MB"):gsub("MiddleButton", "MB3")
end

function DM:GetStatusText()
    if not self.db then return "|cFF22C55E*|r DynamicMarker Ready" end
    local iconInfo = RAID_ICONS[self.db.focusIcon or 8] or RAID_ICONS[8]
    local cyc = self:FormatKeyShort((self.db.flareCycleKey ~= nil) and self.db.flareCycleKey or "")
    local clr = self:FormatKeyShort((self.db.flareClearKey ~= nil) and self.db.flareClearKey or "")
    local chatState = (self.db.chatAnnounce == "MUTED") and "Off" or "Enabled"
    return string.format("|cFF22C55E*|r Focus Icon: %s %s | World Flares: %s Cycle - %s Clear | Chat: %s",
        iconInfo.emoji, iconInfo.name, cyc, clr, chatState)
end

function DM:GetSubTab2Title()
    local cyc = self:FormatKeyShort((self.db and self.db.flareCycleKey ~= nil) and self.db.flareCycleKey or "")
    local clr = self:FormatKeyShort((self.db and self.db.flareClearKey ~= nil) and self.db.flareClearKey or "")
    if cyc == "Unbound" and clr == "Unbound" then
        return "World Flare Keys"
    end
    return string.format("World Flare Keys (%s / %s)", cyc, clr)
end

function DM:RefreshKeybindTelemetryAndTabTitle()
    if not self.db then return end
    local statusStr = self:GetStatusText()
    if self.moduleEntry then
        self.moduleEntry.statusText = statusStr
        self.moduleEntry.status = statusStr
    end
    if self.workspaceFrame then
        local ws = self.workspaceFrame
        if ws.subTabBtns and ws.subTabBtns[2] and ws.subTabBtns[2].Text then
            ws.subTabBtns[2].Text:SetText(self:GetSubTab2Title())
        end
        if ws.ReflowSubTabBar then
            ws.ReflowSubTabBar()
        end
    end
    if self.shellFrame and self.shellFrame.StatusText then
        self.shellFrame.StatusText:SetText(statusStr)
    end
    local ds = _G.DynamicSuite
    if type(ds) == "table" then
        if type(ds.UpdateHeaderTelemetry) == "function" then
            pcall(ds.UpdateHeaderTelemetry, ds, "marker", statusStr)
        elseif type(ds.UpdateHeaderStatus) == "function" then
            pcall(ds.UpdateHeaderStatus, ds, "marker", statusStr)
        elseif type(ds.RefreshHeaderStatus) == "function" then
            pcall(ds.RefreshHeaderStatus, ds, "marker", statusStr)
        end
        if ds.statusTextWidget and ds.activeModule == "marker" and ds.statusTextWidget.SetText then
            pcall(ds.statusTextWidget.SetText, ds.statusTextWidget, statusStr)
        end
    end
    if type(self._refreshSuiteSetupKeys) == "function" then
        pcall(self._refreshSuiteSetupKeys)
    end
end

-- ============================================================================
-- 11. ON-SCREEN RAID TARGET BAR & WORLD FLARE BAR + EDIT MODE (HUDS)
-- ============================================================================

function DM:NormalizeBarVisibility(val)
    local mode, upper = NormalizeBarVisibilityValue(val)
    return mode, upper
end

function DM:NormalizeGroupScope(val)
    return NormalizeGroupScopeValue(val)
end

function DM:IsGroupScopeSatisfied(forBarVisibility)
    local inGroup = (IsInGroup and IsInGroup()) or false
    local inRaid = (IsInRaid and IsInRaid()) or false
    if forBarVisibility and not (inGroup or inRaid) then
        return false
    end
    local scopeMode = self:NormalizeGroupScope(self.db and self.db.groupScope)
    if scopeMode == "party" then
        return inGroup and not inRaid
    elseif scopeMode == "raid" then
        return inRaid
    elseif scopeMode == "all" and not forBarVisibility then
        return true
    else
        return inGroup or inRaid
    end
end

function DM:GetGroupVisibilityStateDriver()
    local scopeMode = self:NormalizeGroupScope(self.db and self.db.groupScope)
    if scopeMode == "party" then
        return "[group:party,nogroup:raid] show; hide"
    elseif scopeMode == "raid" then
        return "[group:raid] show; hide"
    end
    return "[group] show; hide"
end

function DM:ShouldShowBar(visibilitySetting, barFrame)
    if self.isEditMode or (barFrame and barFrame._dsEditModeActive) then
        return true
    end
    local mode = self:NormalizeBarVisibility(visibilitySetting)
    if mode == "off" then
        return false
    elseif mode == "always" then
        return true
    end
    return self:IsGroupScopeSatisfied(true)
end

function DM:IsBarNormallyShown(hudKey)
    local primaryKey = (hudKey == "FlareBar" or hudKey == "FLARE" or hudKey == "flareBar") and "FlareBar" or "TargetBar"
    if not self.db then return true end
    local visVal = (primaryKey == "FlareBar") and self.db.flareBarVisibility or self.db.targetBarVisibility
    local mode = self:NormalizeBarVisibility(visVal)
    return mode ~= "off"
end

function DM:IsEditMoverVisible(hudKey)
    if not self.isEditMode then return false end
    local primaryKey = (hudKey == "FlareBar" or hudKey == "FLARE" or hudKey == "flareBar") and "FlareBar" or "TargetBar"
    if self._suitePreviewState and (self:IsRunningInSuite() or self:IsSuiteHudInspectorActive()) then
        if primaryKey == "FlareBar" then
            return self._suitePreviewState.showFlare == true
        end
        return self._suitePreviewState.showTarget == true
    end
    if self:IsBarNormallyShown(primaryKey) then
        return true
    end
    return (self._previewHiddenMoverKey == primaryKey) and ((self.selectedHUDKey or "TargetBar") == primaryKey)
end

function DM:UpdateTargetBarVisibility()
    if not self.targetBar or not self.db then return end
    local bar = self.targetBar
    if InCombatLockdown() then
        self.pendingTargetBarSync = true
        self.pendingBarVisibilityUpdate = true
        return
    end
    local mode, canonical = self:NormalizeBarVisibility(self.db.targetBarVisibility)
    self.db.targetBarVisibility = canonical

    local isEdit = not not (self.isEditMode or bar._dsEditModeActive)
    if isEdit then
        if UnregisterStateDriver then
            pcall(UnregisterStateDriver, bar, "visibility")
        end
        local shouldPreview = self:IsEditMoverVisible("TargetBar")
        if shouldPreview then
            bar:Show()
        else
            bar:Hide()
            if bar.editMover then bar.editMover:Hide() end
            if bar._dsDragShield then bar._dsDragShield:Hide() end
        end
        return
    end

    if mode == "off" then
        if UnregisterStateDriver then
            pcall(UnregisterStateDriver, bar, "visibility")
        end
        bar:Hide()
    elseif mode == "always" then
        if UnregisterStateDriver then
            pcall(UnregisterStateDriver, bar, "visibility")
        end
        bar:Show()
    else
        local shouldShow = self:IsGroupScopeSatisfied(true)
        if RegisterStateDriver then
            pcall(RegisterStateDriver, bar, "visibility", self:GetGroupVisibilityStateDriver())
        end
        bar:SetShown(shouldShow)
    end
end

function DM:UpdateFlareBarVisibility()
    if not self.flareBar or not self.db then return end
    local bar = self.flareBar
    if InCombatLockdown() then
        self.pendingFlareBarSync = true
        self.pendingBarVisibilityUpdate = true
        return
    end
    local mode, canonical = self:NormalizeBarVisibility(self.db.flareBarVisibility)
    self.db.flareBarVisibility = canonical

    local isEdit = not not (self.isEditMode or bar._dsEditModeActive)
    if isEdit then
        if UnregisterStateDriver then
            pcall(UnregisterStateDriver, bar, "visibility")
        end
        local shouldPreview = self:IsEditMoverVisible("FlareBar")
        if shouldPreview then
            bar:Show()
        else
            bar:Hide()
            if bar.editMover then bar.editMover:Hide() end
            if bar._dsDragShield then bar._dsDragShield:Hide() end
        end
        return
    end

    if mode == "off" then
        if UnregisterStateDriver then
            pcall(UnregisterStateDriver, bar, "visibility")
        end
        bar:Hide()
    elseif mode == "always" then
        if UnregisterStateDriver then
            pcall(UnregisterStateDriver, bar, "visibility")
        end
        bar:Show()
    else
        local shouldShow = self:IsGroupScopeSatisfied(true)
        if RegisterStateDriver then
            pcall(RegisterStateDriver, bar, "visibility", self:GetGroupVisibilityStateDriver())
        end
        bar:SetShown(shouldShow)
    end
end

function DM:GetHUDBorderColor(barKey)
    local style = (barKey == "FlareBar" and self.db and self.db.flareBarBorderStyle)
        or (barKey == "TargetBar" and self.db and self.db.targetBarBorderStyle)
        or (self.db and self.db.hudBorderStyle)
        or "ACCENT"
    if style == "NONE" then
        return { r = 0, g = 0, b = 0, a = 0 }
    elseif style == "DARK" or style == "SUBTLE" then
        return COLORS.BorderStrong
    else
        local ar, ag, ab = self:GetAccentColor()
        return { r = ar, g = ag, b = ab, a = 0.85 }
    end
end

local function ResolveHUDKeyAliases(hudKey)
    local k = tostring(hudKey or "TargetBar"):lower()
    if k:find("flare") then
        return "FlareBar", "flare", "DynamicMarkerFlareBar", "flareBar", -182, "FLARE"
    end
    return "TargetBar", "target", "DynamicMarkerTargetBar", "targetBar", -140, "TARGET"
end

function DM:SyncBarScaleAndSizeToDB(frame, hudKey)
    if type(frame) == "string" and hudKey == nil then
        hudKey = frame
        frame = nil
    end
    local primaryKey, _, _, dbPrefix, _, upperKey = ResolveHUDKeyAliases(hudKey or ((frame and frame == self.flareBar) and "FlareBar" or "TargetBar"))
    local isFlare = (primaryKey == "FlareBar") or (frame and frame == self.flareBar)
    if type(frame) ~= "table" then
        frame = isFlare and self.flareBar or self.targetBar
    end
    local scaleKey = isFlare and "flareBarScale" or "targetBarScale"
    local orientKey = isFlare and "flareBarOrientation" or "targetBarOrientation"

    local scaleVal = tonumber(self.db and self.db[scaleKey])
    if not IsFiniteNum(scaleVal) and not isFlare and self.db then
        scaleVal = tonumber(self.db.barScale)
    end
    if not IsFiniteNum(scaleVal) then
        local dsScales = _G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.hudScales
        scaleVal = type(dsScales) == "table" and tonumber(dsScales[upperKey] or dsScales[primaryKey]) or nil
    end
    if not IsFiniteNum(scaleVal) then
        scaleVal = 1.00
    end
    scaleVal = math.floor(math.max(0.50, math.min(2.00, scaleVal)) * 100 + 0.5) / 100

    if self.db then
        self.db[scaleKey] = scaleVal
        if not isFlare then
            self.db.barScale = scaleVal
        end
    end
    if type(_G.DynamicSuiteDB) == "table" then
        _G.DynamicSuiteDB.global = _G.DynamicSuiteDB.global or {}
        _G.DynamicSuiteDB.global.hudScales = _G.DynamicSuiteDB.global.hudScales or {}
        _G.DynamicSuiteDB.global.hudScales[upperKey] = scaleVal
    end

    if frame then
        local targetOrient = (self.db and self.db[orientKey] == "VERTICAL") and "VERTICAL" or "HORIZONTAL"
        local wantW = (targetOrient == "VERTICAL") and 40 or (8 * 32 + 9 * 4)
        local wantH = (targetOrient == "VERTICAL") and (8 * 32 + 9 * 4) or 40
        if not (InCombatLockdown and InCombatLockdown()) then
            if frame.SetScale and math.abs((frame:GetScale() or 1) - scaleVal) > 0.001 then
                frame:SetScale(scaleVal)
            end
            if frame.SetSize then
                local curW = (frame.GetWidth and frame:GetWidth()) or 0
                local curH = (frame.GetHeight and frame:GetHeight()) or 0
                if math.abs(curW - wantW) > 0.5 or math.abs(curH - wantH) > 0.5 then
                    frame:SetSize(wantW, wantH)
                end
            end
            if frame.SetClampRectInsets then
                frame:SetClampRectInsets(0, 0, 0, 0)
            end
        end
    end
    return scaleVal
end

-- Canonical SetPoint wrapper: stored uiX/uiY are strictly in UIParent-local offsets
-- relative to screen CENTER (unscaled by barScale). Divide by barScale strictly at SetPoint
-- after SetScale and SetSize have been applied, then enable SetClampedToScreen(true).
function DM:SetBarCenterPoint(frame, uiX, uiY, hudKey)
    if not frame then return end
    local primaryKey = ResolveHUDKeyAliases(hudKey or ((frame == self.flareBar) and "FlareBar" or "TargetBar"))
    local scaleVal = self:SyncBarScaleAndSizeToDB(frame, primaryKey)
    local barScale = (frame.GetScale and frame:GetScale()) or scaleVal or 1.0
    if not IsFiniteNum(barScale) or barScale <= 0 then barScale = 1.0 end
    local nx = tonumber(uiX) or 0
    local ny = tonumber(uiY) or 0
    if not IsFiniteNum(nx) then nx = 0 end
    if not IsFiniteNum(ny) then ny = 0 end
    if not (InCombatLockdown and InCombatLockdown()) then
        if frame.SetClampRectInsets then
            frame:SetClampRectInsets(0, 0, 0, 0)
        end
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", nx / barScale, ny / barScale)
        if frame.SetClampedToScreen then
            frame:SetClampedToScreen(true)
        end
    end
end

function DM:ConvertAnchorToCenterLocal(frame, point, relPoint, rawX, rawY, hudKey)
    local pt = SanitizeAnchorPoint(point, "CENTER")
    local rp = SanitizeAnchorPoint(relPoint or pt, pt)
    local nx = tonumber(rawX)
    local ny = tonumber(rawY)
    local inX = (nx ~= nil and IsFiniteNum(nx)) and nx or 0
    local inY = (ny ~= nil and IsFiniteNum(ny)) and ny or 0
    if pt == "CENTER" and rp == "CENTER" then
        return RoundHUDCoord(inX), RoundHUDCoord(inY), "CENTER", "CENTER"
    end
    local primaryKey, _, _, _, _, _ = ResolveHUDKeyAliases(hudKey or (frame and frame == self.flareBar and "FlareBar" or "TargetBar"))
    local scaleVal = self:SyncBarScaleAndSizeToDB(frame, primaryKey)
    local relScale = (frame and frame.GetScale and frame:GetScale()) or scaleVal
    if not IsFiniteNum(relScale) or relScale <= 0 then relScale = scaleVal end
    local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
    local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
    local isFlare = (primaryKey == "FlareBar") or (frame and frame == self.flareBar)
    local orientKey = isFlare and "flareBarOrientation" or "targetBarOrientation"
    local isVert = (self.db and self.db[orientKey] == "VERTICAL")
    local frameW = (frame and frame.GetWidth and frame:GetWidth()) or 0
    local frameH = (frame and frame.GetHeight and frame:GetHeight()) or 0
    if frameW <= 1 then frameW = isVert and 40 or 292 end
    if frameH <= 1 then frameH = isVert and 292 or 40 end
    local visW = frameW * relScale
    local visH = frameH * relScale
    local pfx, pfy = GetAnchorFraction(pt)
    local rfx, rfy = GetAnchorFraction(rp)
    local anchorVisX = (rfx * screenW) + inX
    local anchorVisY = (rfy * screenH) + inY
    local cx = anchorVisX + (0.5 - pfx) * visW
    local cy = anchorVisY + (0.5 - pfy) * visH
    return RoundHUDCoord(cx - (screenW * 0.5)),
           RoundHUDCoord(cy - (screenH * 0.5)),
           "CENTER",
           "CENTER"
end

function DM:WriteHUDCoordsToDB(hudKey, pt, rp, x, y)
    local primaryKey, shortKey, frameKey, dbPrefix, _, upperKey = ResolveHUDKeyAliases(hudKey)
    local cleanPt = SanitizeAnchorPoint(pt, "CENTER")
    local cleanRp = SanitizeAnchorPoint(rp or cleanPt, cleanPt)
    local cleanX = RoundHUDCoord(x)
    local cleanY = RoundHUDCoord(y)
    local entry = { point = cleanPt, relPoint = cleanRp, x = cleanX, y = cleanY }

    self:SetSetting(dbPrefix .. "Point",    cleanPt)
    self:SetSetting(dbPrefix .. "RelPoint", cleanRp)
    self:SetSetting(dbPrefix .. "X",        cleanX)
    self:SetSetting(dbPrefix .. "Y",        cleanY)
    self:SetSetting(dbPrefix .. "Pos",      { point = cleanPt, relPoint = cleanRp, x = cleanX, y = cleanY })

    if self.db then
        if primaryKey == "TargetBar" then
            self.db.barPoint    = cleanPt
            self.db.barRelPoint = cleanRp
            self.db.barX        = cleanX
            self.db.barY        = cleanY
            self.db.targetPos   = { point = cleanPt, relPoint = cleanRp, x = cleanX, y = cleanY }
        else
            self.db.flarePos    = { point = cleanPt, relPoint = cleanRp, x = cleanX, y = cleanY }
        end
        if type(self.db.profiles) == "table" then
            for _, pTbl in pairs(self.db.profiles) do
                if type(pTbl) == "table" then
                    pTbl[dbPrefix .. "Point"]    = cleanPt
                    pTbl[dbPrefix .. "RelPoint"] = cleanRp
                    pTbl[dbPrefix .. "X"]        = cleanX
                    pTbl[dbPrefix .. "Y"]        = cleanY
                    pTbl[dbPrefix .. "Pos"]      = { point = cleanPt, relPoint = cleanRp, x = cleanX, y = cleanY }
                    if primaryKey == "TargetBar" then
                        pTbl.barPoint    = cleanPt
                        pTbl.barRelPoint = cleanRp
                        pTbl.barX        = cleanX
                        pTbl.barY        = cleanY
                        pTbl.targetPos   = { point = cleanPt, relPoint = cleanRp, x = cleanX, y = cleanY }
                    else
                        pTbl.flarePos    = { point = cleanPt, relPoint = cleanRp, x = cleanX, y = cleanY }
                    end
                end
            end
        end
    end

    if type(_G.DynamicSuiteDB) == "table" or type(self.suiteGlobal) == "table" then
        _G.DynamicSuiteDB = _G.DynamicSuiteDB or {}
        _G.DynamicSuiteDB.global = _G.DynamicSuiteDB.global or {}
        _G.DynamicSuiteDB.global.hudPositions = _G.DynamicSuiteDB.global.hudPositions or {}
        self.suiteGlobal = _G.DynamicSuiteDB.global
        self.suiteGlobal.hudPositions[upperKey]   = entry
        self.suiteGlobal.hudPositions[primaryKey] = entry
        self.suiteGlobal.hudPositions[shortKey]   = entry
        self.suiteGlobal.hudPositions[frameKey]   = entry
    end
    local activeScope = (_G.DynamicSuite and type(_G.DynamicSuite.GetSuiteGlobal) == "function") and _G.DynamicSuite.GetSuiteGlobal() or nil
    if type(activeScope) == "table" and activeScope ~= self.suiteGlobal then
        activeScope.hudPositions = type(activeScope.hudPositions) == "table" and activeScope.hudPositions or {}
        activeScope.hudPositions[upperKey]   = entry
        activeScope.hudPositions[primaryKey] = entry
        activeScope.hudPositions[shortKey]   = entry
        activeScope.hudPositions[frameKey]   = entry
    end
    if type(_G.DynamicLoadDB) == "table" and type(_G.DynamicLoadDB.charData) == "table" then
        for _, cd in pairs(_G.DynamicLoadDB.charData) do
            if type(cd) == "table" and type(cd.theme) == "table" and type(cd.theme.hudPositions) == "table" then
                cd.theme.hudPositions[upperKey]   = entry
                cd.theme.hudPositions[primaryKey] = entry
                cd.theme.hudPositions[shortKey]   = entry
                cd.theme.hudPositions[frameKey]   = entry
            end
        end
    end
end

function DM:GetStoredHUDPosition(hudKey, fallbackY)
    local primaryKey, shortKey, frameKey, dbPrefix, defY, upperKey = ResolveHUDKeyAliases(hudKey)
    local defaultY = (tonumber(fallbackY) ~= nil and IsFiniteNum(tonumber(fallbackY))) and tonumber(fallbackY) or defY
    local hp = (self.suiteGlobal and self.suiteGlobal.hudPositions)
        or (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.hudPositions)
    local targetFrame = (primaryKey == "FlareBar") and self.flareBar or self.targetBar

    -- 1. Check DynamicMarkerDB first (authoritative SavedVariables storage for standalone & bundled)
    local dbX = tonumber(self:GetSetting(dbPrefix .. "X"))
    local dbY = tonumber(self:GetSetting(dbPrefix .. "Y"))
    local dbPt = self:GetSetting(dbPrefix .. "Point")
    local dbPos = self:GetSetting(dbPrefix .. "Pos")
    local dmEntry = nil
    if IsFiniteNum(dbX) or IsFiniteNum(dbY) or type(dbPt) == "string" or type(dbPos) == "table" then
        local posTbl = (type(dbPos) == "table") and dbPos or {}
        local rawX = IsFiniteNum(dbX) and dbX or tonumber(posTbl.x)
        local rawY = IsFiniteNum(dbY) and dbY or tonumber(posTbl.y)
        local cx = IsFiniteNum(rawX) and rawX or 0
        local cy = IsFiniteNum(rawY) and rawY or defaultY
        local pt = SanitizeAnchorPoint(type(dbPt) == "string" and dbPt or posTbl.point, "CENTER")
        local rawRp = self:GetSetting(dbPrefix .. "RelPoint")
        local rp = SanitizeAnchorPoint(type(rawRp) == "string" and rawRp or posTbl.relPoint, pt)
        if pt ~= "CENTER" or rp ~= "CENTER" then
            cx, cy = self:ConvertAnchorToCenterLocal(targetFrame, pt, rp, cx, cy, primaryKey)
            pt, rp = "CENTER", "CENTER"
            self:WriteHUDCoordsToDB(primaryKey, "CENTER", "CENTER", cx, cy)
        else
            cx, cy = RoundHUDCoord(cx), RoundHUDCoord(cy)
        end
        dmEntry = { point = "CENTER", relPoint = "CENTER", x = cx, y = cy }
    end

    if dmEntry then
        if type(hp) == "table" then
            hp[upperKey]   = dmEntry
            hp[primaryKey] = dmEntry
            hp[shortKey]   = dmEntry
            hp[frameKey]   = dmEntry
        end
        local activeScope = (_G.DynamicSuite and type(_G.DynamicSuite.GetSuiteGlobal) == "function") and _G.DynamicSuite.GetSuiteGlobal() or nil
        if type(activeScope) == "table" and type(activeScope.hudPositions) == "table" then
            activeScope.hudPositions[upperKey]   = dmEntry
            activeScope.hudPositions[primaryKey] = dmEntry
            activeScope.hudPositions[shortKey]   = dmEntry
            activeScope.hudPositions[frameKey]   = dmEntry
        end
        return dmEntry
    end

    -- 2. Fallback to DynamicSuiteDB.global.hudPositions only when DynamicMarkerDB is unset
    if type(hp) == "table" then
        local c = hp[upperKey] or hp[primaryKey] or hp[shortKey] or hp[frameKey]
        if type(c) == "table" then
            local rawX = tonumber(c.x)
            local rawY = tonumber(c.y)
            if IsFiniteNum(rawX) or IsFiniteNum(rawY) then
                local cx = IsFiniteNum(rawX) and rawX or 0
                local cy = IsFiniteNum(rawY) and rawY or defaultY
                local pt = SanitizeAnchorPoint(c.point, "CENTER")
                local rp = SanitizeAnchorPoint(c.relPoint, pt)
                if pt ~= "CENTER" or rp ~= "CENTER" then
                    cx, cy = self:ConvertAnchorToCenterLocal(targetFrame, pt, rp, cx, cy, primaryKey)
                else
                    cx, cy = RoundHUDCoord(cx), RoundHUDCoord(cy)
                end
                local entry = { point = "CENTER", relPoint = "CENTER", x = cx, y = cy }
                self:WriteHUDCoordsToDB(primaryKey, "CENTER", "CENTER", cx, cy)
                return entry
            end
        end
    end

    if dmEntry then
        return dmEntry
    end
    return { point = "CENTER", relPoint = "CENTER", x = 0, y = defaultY }
end

function DM:ApplyHUDPosition(frame, hudKey, defaultY)
    if not frame or frame._dmDragging or frame._dsDragging or self.isDraggingHUD then return end
    if InCombatLockdown() then
        self.pendingHUDPositionSync = true
        return
    end
    local primaryKey, _, _, _, defY = ResolveHUDKeyAliases(hudKey)
    -- Apply configured scale & orientation size BEFORE clamping and SetPoint
    self:SyncBarScaleAndSizeToDB(frame, primaryKey)

    local pos = self:GetStoredHUDPosition(hudKey, defaultY)
    local px = (tonumber(pos.x) ~= nil and IsFiniteNum(tonumber(pos.x))) and tonumber(pos.x) or 0
    local py = (tonumber(pos.y) ~= nil and IsFiniteNum(tonumber(pos.y))) and tonumber(pos.y) or ((tonumber(defaultY) ~= nil) and tonumber(defaultY) or defY)
    local cx, cy = self:ClampHUDPositionToScreen(frame, primaryKey, "CENTER", "CENTER", px, py, { enableSnap = false })
    self.isApplyingHUDPos = true
    self:SetBarCenterPoint(frame, cx, cy, primaryKey)
    self.isApplyingHUDPos = false
    if frame.editMover and frame.editMover.UpdateCoordLabel then
        frame.editMover:UpdateCoordLabel()
    elseif frame.moverOverlay and frame.moverOverlay.UpdateCoordLabel then
        frame.moverOverlay:UpdateCoordLabel()
    end
end
DM.ApplyBarPosition = DM.ApplyHUDPosition

function DM:SaveHUDPosition(frame, hudKey, noSnap, explicitPoint, explicitRelPoint, explicitX, explicitY)
    if not frame and not explicitPoint then return end
    if (frame and (frame._dmDragging or frame._dsDragging)) or self.isDraggingHUD then return end
    local primaryKey, _, _, _, defY, upperKey = ResolveHUDKeyAliases(hudKey)
    if frame then
        self:SyncBarScaleAndSizeToDB(frame, primaryKey)
    end

    local cx, cy
    if explicitPoint ~= nil or explicitX ~= nil or explicitY ~= nil then
        local pt = SanitizeAnchorPoint(explicitPoint, "CENTER")
        local rp = SanitizeAnchorPoint(explicitRelPoint or pt, pt)
        local nx = tonumber(explicitX)
        local ny = tonumber(explicitY)
        local rawX = (nx ~= nil and IsFiniteNum(nx)) and nx or 0
        local rawY = (ny ~= nil and IsFiniteNum(ny)) and ny or defY
        cx, cy = self:ConvertAnchorToCenterLocal(frame, pt, rp, rawX, rawY, primaryKey)
    elseif frame and frame.GetCenter then
        local scaleVal = self:SyncBarScaleAndSizeToDB(frame, primaryKey)
        local relScale = (frame.GetScale and frame:GetScale()) or scaleVal
        if not IsFiniteNum(relScale) or relScale <= 0 then relScale = scaleVal end
        local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
        local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
        local fCx, fCy = frame:GetCenter()
        if fCx and fCy and IsFiniteNum(fCx) and IsFiniteNum(fCy) then
            cx = RoundHUDCoord((fCx * relScale) - (screenW * 0.5))
            cy = RoundHUDCoord((fCy * relScale) - (screenH * 0.5))
        else
            local p, _, rp, fx, fy = frame:GetPoint(1)
            if not p then return end
            cx, cy = self:ConvertAnchorToCenterLocal(frame, p, rp, (tonumber(fx) or 0) * relScale, (tonumber(fy) or 0) * relScale, primaryKey)
        end
    else
        return
    end

    local skipSnap = noSnap
        or self._inExternalSetEditMode
        or (frame and (frame._dsEditModeActive or frame._dsDragging or (frame._dsDragShield and frame._dsDragShield:IsShown())))

    local rx, ry = self:ClampHUDPositionToScreen(frame, primaryKey, "CENTER", "CENTER", cx, cy, { enableSnap = not skipSnap })
    if frame and not InCombatLockdown() then
        self.isApplyingHUDPos = true
        self:SetBarCenterPoint(frame, rx, ry, primaryKey)
        self.isApplyingHUDPos = false
    end

    self:WriteHUDCoordsToDB(primaryKey, "CENTER", "CENTER", rx, ry)

    if frame and frame.editMover and frame.editMover.UpdateCoordLabel then
        frame.editMover:UpdateCoordLabel()
    elseif frame and frame.moverOverlay and frame.moverOverlay.UpdateCoordLabel then
        frame.moverOverlay:UpdateCoordLabel()
    end
    self:RefreshEditModeInspector()
    if not self._suppressSuiteNotify and _G.DynamicSuite and type(_G.DynamicSuite.NotifyExternalHudChanged) == "function" then
        pcall(_G.DynamicSuite.NotifyExternalHudChanged, upperKey)
    end
end
DM.SaveBarPosition = DM.SaveHUDPosition

function DM:SetBarChildButtonsMouseEnabled(bar, enabled)
    if not bar or InCombatLockdown() then return end
    local flag = not not enabled
    if bar.buttons then
        for _, btn in ipairs(bar.buttons) do
            btn:EnableMouse(flag)
        end
    end
    if bar.clearBtn then
        bar.clearBtn:EnableMouse(flag)
    end
end

function DM:InitTargetBar()
    if self.targetBar then return end

    local bar = CreateFrame("Frame", "DynamicMarkerTargetBar", UIParent, "BackdropTemplate")
    bar:SetSize(8 * 32 + 9 * 4, 40)
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(false)
    if bar.SetClampRectInsets then bar:SetClampRectInsets(0, 0, 0, 0) end
    bar:SetMovable(true)
    bar:RegisterForDrag("LeftButton")
    self:ApplyBackdrop(bar, COLORS.BgCanvas, self:GetHUDBorderColor())
    bar.SetEditMode = function(_, enabled)
        self._inExternalSetEditMode = true
        if not InCombatLockdown() then
            bar:SetClampedToScreen(false)
        else
            self.pendingTargetBarSync = true
        end
        self:SetEditMode(enabled, { fromSuite = self:IsRunningInSuite() })
        self._inExternalSetEditMode = nil
    end
    bar.SaveEditPosition = function(a1, a2, a3, a4, a5)
        local pt, rp, sx, sy = a2, a3, a4, a5
        if type(a1) == "string" then
            pt, rp, sx, sy = a1, a2, a3, a4
        end
        if type(pt) == "string" and tonumber(rp) ~= nil and tonumber(sx) ~= nil then
            sy = sx
            sx = rp
            rp = pt
        elseif tonumber(pt) ~= nil and tonumber(rp) ~= nil then
            sx, sy = pt, rp
            pt, rp = "CENTER", "CENTER"
        end
        self:SaveHUDPosition(bar, "TargetBar", true, pt, rp, sx, sy)
    end
    bar:SetScript("OnDragStart", function(b)
        if not self.isEditMode or InCombatLockdown() then return end
        if b._dsDragging or self.isDraggingHUD or (b._dsDragShield and b._dsDragShield:IsShown()) then return end
        self.selectedHUDKey = "TargetBar"
        b:SetClampedToScreen(false)
        b:StartMoving()
        self:RefreshEditModeInspector()
    end)
    bar:SetScript("OnDragStop", function(b)
        if b._dsDragging or self.isDraggingHUD or (b._dsDragShield and b._dsDragShield:IsShown()) then return end
        b:StopMovingOrSizing()
        b:SetClampedToScreen(false)
        self:SaveHUDPosition(b, "TargetBar")
    end)

    bar.cells = {}
    bar.buttons = {}
    for i = 1, 8 do
        local info = RAID_ICONS[i]
        -- Pure visual BackdropTemplate cell (never mixed onto SecureActionButtonTemplate)
        local cell = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        cell:SetSize(32, 32)
        cell:SetPoint("LEFT", bar, "LEFT", 4 + (i - 1) * 36, 0)
        self:ApplyBackdrop(cell, COLORS.BgElevated, COLORS.BorderDim)

        local tex = cell:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", cell, "TOPLEFT", 4, -4)
        tex:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -4, 4)
        tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        tex:SetTexCoord(unpack(info.coords))
        cell.Icon = tex

        local activeBar = cell:CreateTexture(nil, "OVERLAY")
        activeBar:SetHeight(2)
        activeBar:SetPoint("BOTTOMLEFT", cell, "BOTTOMLEFT", 1, 1)
        activeBar:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -1, 1)
        activeBar:Hide()
        cell.ActiveBar = activeBar

        -- Pure untainted SecureActionButtonTemplate overlay
        local btn = CreateFrame("Button", "DynamicMarkerTargetBarBtn" .. i, bar, "SecureActionButtonTemplate")
        btn:SetAllPoints(cell)
        self:ConfigureSecureButtonClicks(btn)
        local markCmd = "/tm [@target,exists][@focus,exists][@mouseover,exists] " .. i
        local clearCmd = "/tm [@target,exists][@focus,exists][@mouseover,exists] 0"
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("type1", "macro")
        btn:SetAttribute("macrotext", markCmd)
        btn:SetAttribute("macrotext1", markCmd)
        btn:SetAttribute("type2", "macro")
        btn:SetAttribute("macrotext2", clearCmd)

        btn:SetScript("PostClick", function(_, mouseBtn)
            if mouseBtn == "LeftButton" then
                local changed = (self.db and self.db.focusIcon ~= i)
                self:SetFocusIcon(i, changed)
            end
        end)

        btn:SetScript("OnEnter", function(s)
            local ar, ag, ab = self:GetAccentColor()
            self:ApplyBackdrop(cell, COLORS.BgHover, { r = ar, g = ag, b = ab, a = 0.9 })
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText(info.label, 1, 1, 1)
            GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Set " .. info.name .. " as Focus Marker & Mark Target|r", 1, 1, 1, true)
            GameTooltip:AddLine("|cFFF87171Right-Click:|r |cFFE2E8F0Clear Raid Target Icon|r", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(s)
            if GameTooltip:IsOwned(s) then GameTooltip:Hide() end
            self:RefreshTargetBar()
        end)

        bar.cells[i] = cell
        bar.buttons[i] = btn
    end

    self.targetBar = bar
    local targetHudEntry = {
        key = "TargetBar",
        label = "DynamicMarker: Icon Bar",
        frame = bar,
        defaultY = -140,
        module = "DynamicMarker",
        SetEditMode = function(_, state)
            self._inExternalSetEditMode = true
            self:SetEditMode(state, { fromSuite = true })
            self._inExternalSetEditMode = nil
        end,
    }
    Suite.hudElements["TargetBar"] = targetHudEntry
    Suite.hudElements["target"]    = targetHudEntry
    Suite.hudFrames = Suite.hudFrames or {}
    Suite.hudFrames["TargetBar"] = bar
    Suite.hudFrames["target"]    = bar
    self:AttachMoverOverlay(bar, "TargetBar", "DynamicMarker: Icon Bar", -140)
    self:RefreshTargetBar()
end

function DM:RefreshTargetBar()
    if not self.targetBar or not self.db then return end
    local bar = self.targetBar
    local ar, ag, ab = self:GetAccentColor()

    local targetOpa = self.db.targetBarOpacity or 0.95
    if self.isEditMode then
        local isNorm = self:IsBarNormallyShown("TargetBar")
        bar:SetAlpha(isNorm and targetOpa or math.min(0.65, targetOpa))
    else
        bar:SetAlpha(targetOpa)
    end
    self:ApplyBackdrop(bar, COLORS.BgCanvas, self:GetHUDBorderColor("TargetBar"))

    local selected = self.db.focusIcon or 8
    local isVertNow = (self.db.targetBarOrientation == "VERTICAL")
    if bar.cells then
        for i, cell in ipairs(bar.cells) do
            if i == selected then
                self:ApplyBackdrop(cell, { r = ar * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), g = ag * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), b = ab * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), a = 1 }, { r = ar, g = ag, b = ab, a = 0.95 })
                if cell.ActiveBar then
                    cell.ActiveBar:ClearAllPoints()
                    cell.ActiveBar:SetColorTexture(ar, ag, ab, 1.0)
                    if isVertNow then
                        cell.ActiveBar:SetWidth(2)
                        cell.ActiveBar:SetPoint("TOPLEFT", cell, "TOPLEFT", 1, -1)
                        cell.ActiveBar:SetPoint("BOTTOMLEFT", cell, "BOTTOMLEFT", 1, 1)
                    else
                        cell.ActiveBar:SetHeight(2)
                        cell.ActiveBar:SetPoint("BOTTOMLEFT", cell, "BOTTOMLEFT", 1, 1)
                        cell.ActiveBar:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -1, 1)
                    end
                    cell.ActiveBar:Show()
                end
            else
                self:ApplyBackdrop(cell, COLORS.BgElevated, COLORS.BorderDim)
                if cell.ActiveBar then cell.ActiveBar:Hide() end
            end
        end
    end

    if InCombatLockdown() then
        self.pendingTargetBarSync = true
        return
    end
    self.pendingTargetBarSync = false
    self:SetBarChildButtonsMouseEnabled(bar, not self.isEditMode)

    local order = SanitizePermutation1To8(self.db.iconOrder)
    self.db.iconOrder = order
    local isVert = (self.db.targetBarOrientation == "VERTICAL")
    if isVert then
        bar:SetSize(40, 8 * 32 + 9 * 4)
        for posIdx = 1, 8 do
            local iconId = order[posIdx] or posIdx
            local cell = bar.cells[iconId]
            if cell then
                cell:ClearAllPoints()
                cell:SetPoint("TOP", bar, "TOP", 0, -4 - (posIdx - 1) * 36)
            end
        end
    else
        bar:SetSize(8 * 32 + 9 * 4, 40)
        for posIdx = 1, 8 do
            local iconId = order[posIdx] or posIdx
            local cell = bar.cells[iconId]
            if cell then
                cell:ClearAllPoints()
                cell:SetPoint("LEFT", bar, "LEFT", 4 + (posIdx - 1) * 36, 0)
            end
        end
    end

    self:SyncBarScaleAndSizeToDB(bar, "TargetBar")
    if not self.isApplyingHUDPos and not self._dmRefreshingBars and not InCombatLockdown() then
        self._dmRefreshingBars = true
        self:ApplyHUDPosition(bar, "TargetBar", -140)
        self._dmRefreshingBars = false
    end
    self:UpdateTargetBarVisibility()
    if bar.editMover and bar.editMover.RefreshMoverVisual then
        bar.editMover:RefreshMoverVisual()
    end
end

function DM:InitFlareBar()
    if self.flareBar then return end

    local bar = CreateFrame("Frame", "DynamicMarkerFlareBar", UIParent, "BackdropTemplate")
    bar:SetSize(8 * 32 + 9 * 4, 40)
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(false)
    if bar.SetClampRectInsets then bar:SetClampRectInsets(0, 0, 0, 0) end
    bar:SetMovable(true)
    bar:RegisterForDrag("LeftButton")
    self:ApplyBackdrop(bar, COLORS.BgCanvas, self:GetHUDBorderColor())
    bar.SetEditMode = function(_, enabled)
        self._inExternalSetEditMode = true
        if not InCombatLockdown() then
            bar:SetClampedToScreen(false)
        else
            self.pendingFlareBarSync = true
        end
        self:SetEditMode(enabled, { fromSuite = self:IsRunningInSuite() })
        self._inExternalSetEditMode = nil
    end
    bar.SaveEditPosition = function(a1, a2, a3, a4, a5)
        local pt, rp, sx, sy = a2, a3, a4, a5
        if type(a1) == "string" then
            pt, rp, sx, sy = a1, a2, a3, a4
        end
        if type(pt) == "string" and tonumber(rp) ~= nil and tonumber(sx) ~= nil then
            sy = sx
            sx = rp
            rp = pt
        elseif tonumber(pt) ~= nil and tonumber(rp) ~= nil then
            sx, sy = pt, rp
            pt, rp = "CENTER", "CENTER"
        end
        self:SaveHUDPosition(bar, "FlareBar", true, pt, rp, sx, sy)
    end
    bar:SetScript("OnDragStart", function(b)
        if not self.isEditMode or InCombatLockdown() then return end
        if b._dsDragging or self.isDraggingHUD or (b._dsDragShield and b._dsDragShield:IsShown()) then return end
        self.selectedHUDKey = "FlareBar"
        b:SetClampedToScreen(false)
        b:StartMoving()
        self:RefreshEditModeInspector()
    end)
    bar:SetScript("OnDragStop", function(b)
        if b._dsDragging or self.isDraggingHUD or (b._dsDragShield and b._dsDragShield:IsShown()) then return end
        b:StopMovingOrSizing()
        b:SetClampedToScreen(false)
        self:SaveHUDPosition(b, "FlareBar")
    end)

    bar.cells = {}
    bar.buttons = {}
    for i = 1, 8 do
        local fInfo = WORLD_FLARES[i]
        local rInfo = RAID_ICONS[fInfo.raidIcon]
        local cell = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        cell:SetSize(32, 32)
        cell:SetPoint("LEFT", bar, "LEFT", 4 + (i - 1) * 36, 0)
        self:ApplyBackdrop(cell, COLORS.BgElevated, { r = fInfo.color.r, g = fInfo.color.g, b = fInfo.color.b, a = 0.55 })

        local tex = cell:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", cell, "TOPLEFT", 5, -5)
        tex:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -5, 5)
        tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        tex:SetTexCoord(unpack(rInfo.coords))
        cell.Icon = tex

        local badge = cell:CreateTexture(nil, "OVERLAY")
        badge:SetHeight(3)
        badge:SetPoint("BOTTOMLEFT", cell, "BOTTOMLEFT", 2, 2)
        badge:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -2, 2)
        badge:SetColorTexture(fInfo.color.r, fInfo.color.g, fInfo.color.b, 0.95)

        local btn = CreateFrame("Button", "DynamicMarkerFlareBarBtn" .. i, bar, "SecureActionButtonTemplate")
        btn:SetAllPoints(cell)
        self:ConfigureSecureButtonClicks(btn)

        local placeFlareCmd = "/wm " .. i
        local clearFlaresCmd = "/cwm 0\n/cwm all"
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("type1", "macro")
        btn:SetAttribute("macrotext", placeFlareCmd)
        btn:SetAttribute("macrotext1", placeFlareCmd)
        btn:SetAttribute("type2", "macro")
        btn:SetAttribute("macrotext2", clearFlaresCmd)

        btn:SetScript("OnEnter", function(s)
            self:ApplyBackdrop(cell, COLORS.BgHover, { r = fInfo.color.r, g = fInfo.color.g, b = fInfo.color.b, a = 1.0 })
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText(fInfo.short .. " World Flare", 1, 1, 1)
            GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Place " .. fInfo.short .. " World Marker|r", 1, 1, 1, true)
            GameTooltip:AddLine("|cFFF87171Right-Click:|r |cFFE2E8F0Clear All World Markers|r", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(s)
            self:ApplyBackdrop(cell, COLORS.BgElevated, { r = fInfo.color.r, g = fInfo.color.g, b = fInfo.color.b, a = 0.55 })
            if GameTooltip:IsOwned(s) then GameTooltip:Hide() end
        end)

        bar.cells[i] = cell
        bar.buttons[i] = btn
    end

    self.flareBar = bar
    local flareHudEntry = {
        key = "FlareBar",
        label = "DynamicMarker: Flare Bar",
        frame = bar,
        defaultY = -182,
        module = "DynamicMarker",
        SetEditMode = function(_, state)
            self._inExternalSetEditMode = true
            self:SetEditMode(state, { fromSuite = true })
            self._inExternalSetEditMode = nil
        end,
    }
    Suite.hudElements["FlareBar"] = flareHudEntry
    Suite.hudElements["flare"]    = flareHudEntry
    Suite.hudFrames = Suite.hudFrames or {}
    Suite.hudFrames["FlareBar"] = bar
    Suite.hudFrames["flare"]    = bar
    self:AttachMoverOverlay(bar, "FlareBar", "DynamicMarker: Flare Bar", -182)
    self:RefreshFlareBar()
end

function DM:RefreshFlareBar()
    if not self.flareBar or not self.db then return end
    local bar = self.flareBar
    local flareOpa = self.db.flareBarOpacity or 0.95
    if self.isEditMode then
        local isNorm = self:IsBarNormallyShown("FlareBar")
        bar:SetAlpha(isNorm and flareOpa or math.min(0.65, flareOpa))
    else
        bar:SetAlpha(flareOpa)
    end
    self:ApplyBackdrop(bar, COLORS.BgCanvas, self:GetHUDBorderColor("FlareBar"))

    if InCombatLockdown() then
        self.pendingFlareBarSync = true
        return
    end
    self.pendingFlareBarSync = false
    self:SetBarChildButtonsMouseEnabled(bar, not self.isEditMode)

    local activeSeq = self:GetActiveFlareSequence()
    local count = math.max(1, #activeSeq)
    for i = 1, 8 do
        if bar.cells and bar.cells[i] then bar.cells[i]:Hide() end
        if bar.buttons and bar.buttons[i] then bar.buttons[i]:Hide() end
    end

    local isVert = (self.db.flareBarOrientation == "VERTICAL")
    if isVert then
        bar:SetSize(40, count * 32 + (count + 1) * 4)
        for posIdx, flareID in ipairs(activeSeq) do
            local cell = bar.cells and bar.cells[flareID]
            local btn = bar.buttons and bar.buttons[flareID]
            if cell then
                cell:ClearAllPoints()
                cell:SetPoint("TOP", bar, "TOP", 0, -4 - (posIdx - 1) * 36)
                cell:Show()
            end
            if btn then
                btn:Show()
            end
        end
    else
        bar:SetSize(count * 32 + (count + 1) * 4, 40)
        for posIdx, flareID in ipairs(activeSeq) do
            local cell = bar.cells and bar.cells[flareID]
            local btn = bar.buttons and bar.buttons[flareID]
            if cell then
                cell:ClearAllPoints()
                cell:SetPoint("LEFT", bar, "LEFT", 4 + (posIdx - 1) * 36, 0)
                cell:Show()
            end
            if btn then
                btn:Show()
            end
        end
    end

    self:SyncBarScaleAndSizeToDB(bar, "FlareBar")
    if not self.isApplyingHUDPos and not self._dmRefreshingBars and not InCombatLockdown() then
        self._dmRefreshingBars = true
        self:ApplyHUDPosition(bar, "FlareBar", -182)
        self._dmRefreshingBars = false
    end
    self:UpdateFlareBarVisibility()
    if bar.editMover and bar.editMover.RefreshMoverVisual then
        bar.editMover:RefreshMoverVisual()
    end
end

-- ============================================================================
-- 12. EDIT MODE (HUDS) - GRID, SUITE ACCENT MOVERS & DOCKED HEADER PILLS
-- ============================================================================

function DM:IsRunningInSuite()
    if ADDON_FOLDER == "DynamicSuite" or self._loadedBySuite == true then
        return true
    end
    if _G.DynamicSuite and _G.DynamicSuite._isHubLoaded == true then
        return true
    end
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" and C_AddOns.IsAddOnLoaded("DynamicSuite") then
        return true
    end
    if type(_G.IsAddOnLoaded) == "function" and _G.IsAddOnLoaded("DynamicSuite") then
        return true
    end
    return false
end

function DM:EnsureGridOverlay()
    if self:IsRunningInSuite() then
        if self.gridOverlay and self.gridOverlay.Hide then self.gridOverlay:Hide() end
        if _G.DynamicMarkerGridOverlay and _G.DynamicMarkerGridOverlay.Hide then _G.DynamicMarkerGridOverlay:Hide() end
        return nil
    end
    if self.gridOverlay then return self.gridOverlay end
    local grid = _G.DynamicMarkerGridOverlay or CreateFrame("Frame", "DynamicMarkerGridOverlay", UIParent)
    grid:SetAllPoints(UIParent)
    grid:SetFrameStrata("BACKGROUND")
    grid:Hide()

    if not grid.initialized then
        grid.initialized = true
        local vCenter = grid:CreateTexture(nil, "OVERLAY")
        vCenter:SetColorTexture(0.22, 0.74, 0.97, 0.45)
        vCenter:SetWidth(1)
        vCenter:SetPoint("TOP", UIParent, "TOP", 0, 0)
        vCenter:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)

        local hCenter = grid:CreateTexture(nil, "OVERLAY")
        hCenter:SetColorTexture(0.22, 0.74, 0.97, 0.45)
        hCenter:SetHeight(1)
        hCenter:SetPoint("LEFT", UIParent, "LEFT", 0, 0)
        hCenter:SetPoint("RIGHT", UIParent, "RIGHT", 0, 0)
    end

    self.gridOverlay = grid
    return grid
end

function DM:IsHudGridEnabled()
    if not self.db then return true end
    return self.db.hudShowGrid ~= false
end

function DM:NudgeSpecificHUD(hudKey, dx, dy, defaultY)
    if InCombatLockdown() then return end
    local primaryKey, _, _, _, defY = ResolveHUDKeyAliases(hudKey)
    local entry = Suite.hudElements[primaryKey]
    if not entry or not entry.frame then return end
    local pos = self:GetStoredHUDPosition(primaryKey, defaultY or entry.defaultY or defY)
    local nx = (pos.x or 0) + dx
    local ny = (pos.y or 0) + dy
    self:SaveHUDPosition(entry.frame, primaryKey, true, pos.point or "CENTER", pos.relPoint or pos.point or "CENTER", nx, ny)
    self:ApplyHUDPosition(entry.frame, primaryKey, defaultY or entry.defaultY or defY)
    self:RefreshEditModeInspector()
end

function DM:AttachButtonIcon(btn, texPath, rotationRad, labelText)
    if not btn then return end
    if not btn.IconTex then
        btn.IconTex = btn:CreateTexture(nil, "OVERLAY")
        btn.IconTex:SetSize(12, 12)
    end
    btn.IconTex:SetTexture(texPath)
    if btn.IconTex.SetRotation then
        btn.IconTex:SetRotation(rotationRad or 0)
    end
    btn.IconTex:SetVertexColor(COLORS.TextPrimary.r, COLORS.TextPrimary.g, COLORS.TextPrimary.b, 0.95)
    if labelText and labelText ~= "" then
        btn.IconTex:ClearAllPoints()
        btn.IconTex:SetPoint("LEFT", btn, "LEFT", 8, 0)
        btn.Text:ClearAllPoints()
        btn.Text:SetPoint("LEFT", btn.IconTex, "RIGHT", 4, 0)
        btn.Text:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
        btn.Text:SetJustifyH("CENTER")
        btn.Text:SetText(labelText)
    else
        btn.IconTex:ClearAllPoints()
        btn.IconTex:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.Text:SetText("")
    end
end

DM.HasEncapsulatedHudMovers = true

local function ApplyMoverPixelBorder(frame, thickness, r, g, b, a)
    if not frame then return end
    if not frame._pixelEdges then
        local function MakeEdge()
            local tex = frame:CreateTexture(nil, "OVERLAY", nil, 7)
            DisableTexturePixelSnap(tex)
            return tex
        end
        local top = MakeEdge()
        top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        local bottom = MakeEdge()
        bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        local left = MakeEdge()
        left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        local right = MakeEdge()
        right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frame._pixelEdges = { top = top, bottom = bottom, left = left, right = right }
    end
    local px = DM:GetPixelSize(frame, thickness or 1)
    local edges = frame._pixelEdges
    edges.top:SetHeight(px)
    edges.bottom:SetHeight(px)
    edges.left:SetWidth(px)
    edges.right:SetWidth(px)
    for _, edge in pairs(edges) do
        edge:SetColorTexture(r or 0.22, g or 0.74, b or 0.97, a or 1.0)
    end
end

local EDGE_SNAP_THRESHOLD = 11
local BAR_SNAP_THRESHOLD  = 9

local function EnsureSnapGuideOverlay()
    local ov = _G.DynamicSuiteSnapGuideOverlay
    if not ov then
        ov = CreateFrame("Frame", "DynamicSuiteSnapGuideOverlay", UIParent)
        ov:SetAllPoints(UIParent)
        ov:SetFrameStrata("FULLSCREEN_DIALOG")
        ov:SetFrameLevel(200)
        ov:EnableMouse(false)

        local vLine = ov:CreateTexture(nil, "OVERLAY")
        DisableTexturePixelSnap(vLine)
        vLine:Hide()
        ov.vLine = vLine

        local hLine = ov:CreateTexture(nil, "OVERLAY")
        DisableTexturePixelSnap(hLine)
        hLine:Hide()
        ov.hLine = hLine

        ov.HideGuides = function()
            if ov.vLine then ov.vLine:Hide() end
            if ov.hLine then ov.hLine:Hide() end
        end

        ov.ShowGuides = function(gx, gy, r, g, b)
            local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
            local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
            local cr, cg, cb = r or 0.22, g or 0.74, b or 0.97
            if gx ~= nil then
                ov.vLine:ClearAllPoints()
                ov.vLine:SetColorTexture(cr, cg, cb, 0.85)
                if gx <= 1 then
                    ov.vLine:SetWidth(2)
                    ov.vLine:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
                    ov.vLine:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
                elseif gx >= screenW - 1 then
                    ov.vLine:SetWidth(2)
                    ov.vLine:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
                    ov.vLine:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
                else
                    ov.vLine:SetWidth(1.5)
                    ov.vLine:SetPoint("TOP", UIParent, "BOTTOMLEFT", gx, screenH)
                    ov.vLine:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", gx, 0)
                end
                ov.vLine:Show()
            else
                ov.vLine:Hide()
            end

            if gy ~= nil then
                ov.hLine:ClearAllPoints()
                ov.hLine:SetColorTexture(cr, cg, cb, 0.85)
                if gy <= 1 then
                    ov.hLine:SetHeight(2)
                    ov.hLine:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
                    ov.hLine:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
                elseif gy >= screenH - 1 then
                    ov.hLine:SetHeight(2)
                    ov.hLine:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
                    ov.hLine:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
                else
                    ov.hLine:SetHeight(1.5)
                    ov.hLine:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, gy)
                    ov.hLine:SetPoint("RIGHT", UIParent, "BOTTOMLEFT", screenW, gy)
                end
                ov.hLine:Show()
            else
                ov.hLine:Hide()
            end
        end
    end
    return ov
end

local function HideSnapGuides()
    local ov = _G.DynamicSuiteSnapGuideOverlay
    if ov and ov.HideGuides then
        ov.HideGuides()
    end
end

local function UpdateSnapGuides(gx, gy)
    if gx == nil and gy == nil then
        HideSnapGuides()
        return
    end
    local ov = EnsureSnapGuideOverlay()
    local ar, ag, ab = DM:GetAccentColor()
    ov.ShowGuides(gx, gy, ar, ag, ab)
end

local function CollectPeerHudBoundsUIParent(excludeFrame, uScale)
    local bounds = {}
    local seen = {}
    if excludeFrame then seen[excludeFrame] = true end

    local function AddFrame(f)
        if not f or seen[f] then return end
        seen[f] = true
        if not (f.IsShown and f:IsShown()) then return end
        if not (f.GetCenter and f.GetWidth and f.GetHeight) then return end
        local oFScale = (f.GetEffectiveScale and f:GetEffectiveScale()) or uScale
        if oFScale <= 0 then oFScale = uScale end
        local oRelScale = oFScale / uScale
        local oW = (f:GetWidth() or 0) * oRelScale
        local oH = (f:GetHeight() or 0) * oRelScale
        if oW <= 1 or oH <= 1 then return end
        local oCxLocal, oCyLocal = f:GetCenter()
        if not oCxLocal or not oCyLocal or not IsFiniteNum(oCxLocal) or not IsFiniteNum(oCyLocal) then return end
        local oCx = oCxLocal * oRelScale
        local oCy = oCyLocal * oRelScale
        table.insert(bounds, {
            left   = oCx - (oW / 2),
            right  = oCx + (oW / 2),
            bottom = oCy - (oH / 2),
            top    = oCy + (oH / 2),
            cx     = oCx,
            cy     = oCy,
        })
    end

    AddFrame(DM.targetBar)
    AddFrame(DM.flareBar)
    if type(Suite.hudElements) == "table" then
        for _, entry in pairs(Suite.hudElements) do
            if type(entry) == "table" and entry.frame then
                AddFrame(entry.frame)
            end
        end
    end
    if type(Suite.hudFrames) == "table" then
        for _, f in pairs(Suite.hudFrames) do
            AddFrame(f)
        end
    end
    if _G.DynamicSuite and type(_G.DynamicSuite.GetActiveHudFrames) == "function" then
        local ok, extraFrames = pcall(_G.DynamicSuite.GetActiveHudFrames)
        if ok and type(extraFrames) == "table" then
            for _, f in ipairs(extraFrames) do
                AddFrame(f)
            end
        end
    end
    return bounds
end

local function GetLocalFrameScreenExtents(frame, hudKey)
    local primaryKey = ResolveHUDKeyAliases(hudKey or ((frame and frame == DM.flareBar) and "FlareBar" or "TargetBar"))
    local scaleVal = DM:SyncBarScaleAndSizeToDB(frame, primaryKey)
    local uScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if not IsFiniteNum(uScale) or uScale <= 0 then uScale = 1 end
    local relScale = (frame and frame.GetScale and frame:GetScale()) or scaleVal
    if not IsFiniteNum(relScale) or relScale <= 0 then relScale = scaleVal end
    local fScale = uScale * relScale
    local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
    local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
    local uiW_local = screenW / relScale
    local uiH_local = screenH / relScale
    local isFlare = (primaryKey == "FlareBar") or (frame and frame == DM.flareBar)
    local orientKey = isFlare and "flareBarOrientation" or "targetBarOrientation"
    local isVert = (DM.db and DM.db[orientKey] == "VERTICAL")
    local frameW = (frame and frame.GetWidth and frame:GetWidth()) or 0
    local frameH = (frame and frame.GetHeight and frame:GetHeight()) or 0
    if frameW <= 1 then frameW = isVert and 40 or 292 end
    if frameH <= 1 then frameH = isVert and 292 or 40 end
    return uiW_local, uiH_local, fScale, uScale, relScale, frameW, frameH
end

local function GetLiveFrameCenterOffset(frame, hudKey, defaultY)
    local primaryKey = ResolveHUDKeyAliases(hudKey or ((frame and frame == DM.flareBar) and "FlareBar" or "TargetBar"))
    if frame and frame.GetCenter then
        local _, _, _, _, relScale = GetLocalFrameScreenExtents(frame, primaryKey)
        local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
        local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
        local fCx, fCy = frame:GetCenter()
        if fCx and fCy and IsFiniteNum(fCx) and IsFiniteNum(fCy) then
            local curX = (fCx * relScale) - (screenW * 0.5)
            local curY = (fCy * relScale) - (screenH * 0.5)
            return math.floor(curX + 0.5), math.floor(curY + 0.5)
        end
    end
    local pos = DM:GetStoredHUDPosition(primaryKey, defaultY)
    return math.floor((tonumber(pos and pos.x) or 0) + 0.5),
           math.floor((tonumber(pos and pos.y) or defaultY or 0) + 0.5)
end
DM.GetLiveFrameCenterOffset = function(self, frame, hudKey, defaultY)
    return GetLiveFrameCenterOffset(frame, hudKey, defaultY)
end

function DM:GetCanonicalHUDPosition(hudKey, defaultY)
    local primaryKey, _, _, _, defY = ResolveHUDKeyAliases(hudKey)
    local frame = (primaryKey == "FlareBar") and self.flareBar or self.targetBar
    if frame and (frame._dmDragging or frame._dsDragging or self.isDraggingHUD) then
        local lx, ly = GetLiveFrameCenterOffset(frame, primaryKey, defaultY or defY)
        return "CENTER", "CENTER", lx, ly
    end
    local pos = self:GetStoredHUDPosition(primaryKey, defaultY or defY)
    return "CENTER", "CENTER", RoundHUDCoord(pos and pos.x or 0), RoundHUDCoord(pos and pos.y or defaultY or defY)
end

local function ResolveActiveHudSnapMode()
    if DM.externalSnapMode ~= nil and DM:IsSuiteHudInspectorActive() then
        return DM.externalSnapMode
    end
    if _G.DynamicSuite and type(_G.DynamicSuite.GetHudSnapMode) == "function" then
        local ok, m = pcall(_G.DynamicSuite.GetHudSnapMode)
        if ok and m ~= nil then return m end
    end
    local gTbl = _G.DynamicSuiteDB and _G.DynamicSuiteDB.global
    if type(gTbl) == "table" and gTbl.hudSnapMode ~= nil then
        return gTbl.hudSnapMode
    end
    return "MAGNET"
end

function DM:ClampHUDPositionToScreen(frame, hudKey, point, relPoint, rawX, rawY, opts)
    opts = type(opts) == "table" and opts or {}
    if frame and self.SyncBarScaleAndSizeToDB then
        self:SyncBarScaleAndSizeToDB(frame, hudKey)
    end
    local primaryKey = ResolveHUDKeyAliases(hudKey)
    local pt = SanitizeAnchorPoint(point, "CENTER")
    local rp = SanitizeAnchorPoint(relPoint or pt, pt)
    local _, _, _, uScale, relScale, frameW, frameH = GetLocalFrameScreenExtents(frame, primaryKey)
    local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
    local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
    local screenCx = screenW / 2
    local screenCy = screenH / 2

    local visW = (frameW or 0) * relScale
    local visH = (frameH or 0) * relScale
    local halfW = math.max(0, visW / 2)
    local halfH = math.max(0, visH / 2)

    local pfx, pfy = GetAnchorFraction(pt)
    local rfx, rfy = GetAnchorFraction(rp)
    local refX = rfx * screenW
    local refY = rfy * screenH

    local inX = tonumber(rawX) or 0
    local inY = tonumber(rawY) or 0
    if not IsFiniteNum(inX) then inX = 0 end
    if not IsFiniteNum(inY) then inY = 0 end

    -- Canonical UIParent-local coordinates: inX/inY are already in UIParent-local space
    local anchorVisX = refX + inX
    local anchorVisY = refY + inY
    local candCx = anchorVisX + (0.5 - pfx) * visW
    local candCy = anchorVisY + (0.5 - pfy) * visH

    local guideX, guideY = nil, nil
    local snapMode = ResolveActiveHudSnapMode()
    local bypassSnap = (IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown())
    if opts.enableSnap and not bypassSnap then
        if snapMode == "MAGNET" or snapMode == nil then
            local candL = candCx - halfW
            local candR = candCx + halfW
            local candB = candCy - halfH
            local candT = candCy + halfH

            local bestDeltaX, bestGX = nil, nil
            local bestDeltaY, bestGY = nil, nil

            local function ConsiderX(delta, gLine, limit)
                if math.abs(delta) <= limit then
                    if bestDeltaX == nil or math.abs(delta) < math.abs(bestDeltaX) then
                        bestDeltaX = delta
                        bestGX = gLine
                    end
                end
            end
            local function ConsiderY(delta, gLine, limit)
                if math.abs(delta) <= limit then
                    if bestDeltaY == nil or math.abs(delta) < math.abs(bestDeltaY) then
                        bestDeltaY = delta
                        bestGY = gLine
                    end
                end
            end

            -- Screen-edge & center magnetic snapping (~11px in UIParent coordinates)
            ConsiderX(0 - candL, 0, EDGE_SNAP_THRESHOLD)
            ConsiderX(screenW - candR, screenW, EDGE_SNAP_THRESHOLD)
            ConsiderX(screenCx - candCx, screenCx, EDGE_SNAP_THRESHOLD)

            ConsiderY(0 - candB, 0, EDGE_SNAP_THRESHOLD)
            ConsiderY(screenH - candT, screenH, EDGE_SNAP_THRESHOLD)
            ConsiderY(screenCy - candCy, screenCy, EDGE_SNAP_THRESHOLD)

            -- Bar-to-bar flush stacking & flush alignment across all visible HUDs (~9px)
            local peers = CollectPeerHudBoundsUIParent(frame, uScale)
            for _, peer in ipairs(peers) do
                ConsiderX(peer.right - candL, peer.right, BAR_SNAP_THRESHOLD)
                ConsiderX(peer.left - candR, peer.left, BAR_SNAP_THRESHOLD)
                ConsiderX(peer.left - candL, peer.left, BAR_SNAP_THRESHOLD)
                ConsiderX(peer.right - candR, peer.right, BAR_SNAP_THRESHOLD)
                ConsiderX(peer.cx - candCx, peer.cx, BAR_SNAP_THRESHOLD)

                ConsiderY(peer.bottom - candT, peer.bottom, BAR_SNAP_THRESHOLD)
                ConsiderY(peer.top - candB, peer.top, BAR_SNAP_THRESHOLD)
                ConsiderY(peer.top - candT, peer.top, BAR_SNAP_THRESHOLD)
                ConsiderY(peer.bottom - candB, peer.bottom, BAR_SNAP_THRESHOLD)
                ConsiderY(peer.cy - candCy, peer.cy, BAR_SNAP_THRESHOLD)
            end

            if bestDeltaX ~= nil then
                candCx = candCx + bestDeltaX
                guideX = bestGX
            end
            if bestDeltaY ~= nil then
                candCy = candCy + bestDeltaY
                guideY = bestGY
            end
        elseif snapMode == 16 or snapMode == 32 then
            local step = snapMode * relScale
            if math.abs(candCx - screenCx) <= EDGE_SNAP_THRESHOLD then
                candCx = screenCx
                guideX = screenCx
            elseif step > 0 then
                candCx = screenCx + math.floor(((candCx - screenCx) / step) + 0.5) * step
            end
            if math.abs(candCy - screenCy) <= EDGE_SNAP_THRESHOLD then
                candCy = screenCy
                guideY = screenCy
            elseif step > 0 then
                candCy = screenCy + math.floor(((candCy - screenCy) / step) + 0.5) * step
            end
        end
    end

    -- Hard screen-boundary clamping ALWAYS takes final precedence
    local minCx = halfW
    local maxCx = screenW - halfW
    local minCy = halfH
    local maxCy = screenH - halfH

    if minCx > maxCx then
        candCx = screenCx
    else
        if candCx < minCx then
            candCx = minCx
            if guideX ~= nil and guideX ~= 0 then guideX = nil end
        elseif candCx > maxCx then
            candCx = maxCx
            if guideX ~= nil and guideX ~= screenW then guideX = nil end
        end
    end

    if minCy > maxCy then
        candCy = screenCy
    else
        if candCy < minCy then
            candCy = minCy
            if guideY ~= nil and guideY ~= 0 then guideY = nil end
        elseif candCy > maxCy then
            candCy = maxCy
            if guideY ~= nil and guideY ~= screenH then guideY = nil end
        end
    end

    local rawOutX = (candCx - (0.5 - pfx) * visW) - refX
    local rawOutY = (candCy - (0.5 - pfy) * visH) - refY
    local outX = math.floor(rawOutX + 0.5)
    local outY = math.floor(rawOutY + 0.5)

    local minLocalX = (minCx - (0.5 - pfx) * visW) - refX
    local maxLocalX = (maxCx - (0.5 - pfx) * visW) - refX
    local minLocalY = (minCy - (0.5 - pfy) * visH) - refY
    local maxLocalY = (maxCy - (0.5 - pfy) * visH) - refY

    if minLocalX <= maxLocalX then
        local loX = math.ceil(minLocalX - 1e-6)
        local hiX = math.floor(maxLocalX + 1e-6)
        if loX <= hiX then
            outX = math.max(loX, math.min(hiX, outX))
        end
    else
        outX = math.floor(((screenCx - (0.5 - pfx) * visW) - refX) + 0.5)
    end

    if minLocalY <= maxLocalY then
        local loY = math.ceil(minLocalY - 1e-6)
        local hiY = math.floor(maxLocalY + 1e-6)
        if loY <= hiY then
            outY = math.max(loY, math.min(hiY, outY))
        end
    else
        outY = math.floor(((screenCy - (0.5 - pfy) * visH) - refY) + 0.5)
    end

    local didAdjust = (outX ~= math.floor(inX + 0.5)) or (outY ~= math.floor(inY + 0.5))
    return outX, outY, didAdjust, guideX, guideY
end

local function ComputeSnappedAndClampedOffset(frame, rawX, rawY, hudKey, enableSnap)
    local outX, outY, didAdjust, guideX, guideY = DM:ClampHUDPositionToScreen(
        frame,
        hudKey,
        "CENTER",
        "CENTER",
        rawX,
        rawY,
        { enableSnap = (enableSnap ~= false) }
    )
    return outX, outY, guideX, guideY, didAdjust
end

function DM:AttachMoverOverlay(targetFrame, hudKey, labelText, defaultY)
    if not targetFrame then return end
    local primaryKey, _, _, dbPrefix, defY, upperKey = ResolveHUDKeyAliases(hudKey)
    local scaleKey = dbPrefix .. "Scale"
    local visKey   = dbPrefix .. "Visibility"
    local displayTitle = labelText or ((primaryKey == "FlareBar") and "DynamicMarker: Flare Bar" or "DynamicMarker: Icon Bar")

    local mover = CreateFrame("Button", nil, targetFrame, "BackdropTemplate")
    mover:SetAllPoints(targetFrame)
    mover:SetIgnoreParentAlpha(true)
    mover:SetFrameStrata("HIGH")
    mover:SetFrameLevel(math.max((targetFrame:GetFrameLevel() or 10) + 50, 80))
    mover:EnableMouse(false)
    mover:EnableMouseWheel(true)
    mover:RegisterForDrag("LeftButton")
    mover:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    mover.bg = mover:CreateTexture(nil, "BACKGROUND")
    mover.bg:SetAllPoints(mover)
    mover.bg:SetColorTexture(0.03, 0.04, 0.06, 0.84)

    mover.Label = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mover.Label:SetPoint("CENTER", mover, "CENTER", 0, 0)
    mover.Label:SetJustifyH("CENTER")
    self:StyleFont(mover.Label, 11, "OUTLINE", COLORS.TextPrimary)
    mover.label = mover.Label

    -- Compact floating header pill above the mover when the bar is oriented vertically (40px wide)
    local badge = CreateFrame("Frame", nil, mover)
    badge:SetHeight(22)
    badge:SetWidth(240)
    badge:SetPoint("BOTTOM", mover, "TOP", 0, 4)
    badge:SetIgnoreParentAlpha(true)
    badge:SetFrameLevel((mover:GetFrameLevel() or 40) + 2)
    badge.bg = badge:CreateTexture(nil, "BACKGROUND")
    badge.bg:SetAllPoints(badge)
    badge.bg:SetColorTexture(0.03, 0.04, 0.06, 0.92)
    badge.Text = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badge.Text:SetPoint("CENTER", badge, "CENTER", 0, 0)
    badge.Text:SetJustifyH("CENTER")
    badge.Text:SetWordWrap(false)
    self:StyleFont(badge.Text, 10, "OUTLINE", COLORS.TextPrimary)
    badge:Hide()
    mover.Badge = badge

    function mover:UpdateCoordLabel(overrideX, overrideY)
        local xVal, yVal
        if overrideX ~= nil and overrideY ~= nil then
            xVal = math.floor(overrideX + 0.5)
            yVal = math.floor(overrideY + 0.5)
        else
            xVal, yVal = GetLiveFrameCenterOffset(targetFrame, primaryKey, defaultY or defY)
        end
        local scaleVal = tonumber(DM:GetSetting(scaleKey)) or 1.0
        local scalePct = math.floor(scaleVal * 100 + 0.5)
        local isShownNormally = DM:IsBarNormallyShown(primaryKey)
        local isHidden = not isShownNormally
        local isSelected = ((DM.selectedHUDKey or "TargetBar") == primaryKey)
        local ar, ag, ab = DM:GetAccentColor()
        local aHex = string.format("%02X%02X%02X", math.floor(ar * 255 + 0.5), math.floor(ag * 255 + 0.5), math.floor(ab * 255 + 0.5))
        local titleColor = isSelected and ("|cFF" .. aHex) or "|cFFCBD5E1"
        local hiddenTag = isHidden and "  |cFFEF4444[HIDDEN (Click Shown to Enable)]|r" or ""

        local fW = (targetFrame.GetWidth and targetFrame:GetWidth()) or 292
        if fW < 160 then
            self.Badge:Show()
            self.Badge.Text:SetText(string.format("%s%s|r  |cFF94A3B8(|r|cFFF8FAFCX: %d, Y: %d|r|cFF94A3B8)|r%s", titleColor, displayTitle, xVal, yVal, hiddenTag))
            local textW = self.Badge.Text:GetStringWidth() or 180
            self.Badge:SetWidth(math.max(190, textW + 18))
            self.Label:SetWordWrap(true)
            self.Label:SetText(string.format("%s%d%%|r\nX:%d\nY:%d", titleColor, scalePct, xVal, yVal))
        else
            if isHidden then
                self.Badge:Show()
                self.Badge.Text:SetText("|cFFEF4444HIDDEN (Click Shown to Enable)|r")
                local textW = self.Badge.Text:GetStringWidth() or 190
                self.Badge:SetWidth(math.max(200, textW + 18))
                self.Label:SetWordWrap(false)
                self.Label:SetText(string.format("%s%s|r  |cFF64748B|||r  |cFFF3F5F8%d%%|r  |cFF64748B|||r  |cFFF8FAFCX: %d, Y: %d|r", titleColor, displayTitle, scalePct, xVal, yVal))
            else
                self.Badge:Hide()
                self.Label:SetWordWrap(false)
                self.Label:SetText(string.format("%s%s|r  |cFF64748B|||r  |cFFF3F5F8%d%%|r  |cFF64748B|||r  |cFFF8FAFCX: %d, Y: %d|r", titleColor, displayTitle, scalePct, xVal, yVal))
            end
        end
    end

    function mover:RefreshMoverVisual()
        local isSelected = ((DM.selectedHUDKey or "TargetBar") == primaryKey)
        local ar, ag, ab = DM:GetAccentColor()
        local br, bgC, bb, ba, thickness
        if self._isHovered then
            br, bgC, bb, ba = ar, ag, ab, 1.0
            thickness = isSelected and 2 or 1
        elseif isSelected then
            br, bgC, bb, ba = ar, ag, ab, 1.0
            thickness = 2
        else
            br, bgC, bb, ba = 0.28, 0.34, 0.44, 0.92
            thickness = 1
        end
        ApplyMoverPixelBorder(self, thickness, br, bgC, bb, ba)
        ApplyMoverPixelBorder(self.Badge, thickness, br, bgC, bb, ba)
        if self.bg then
            self.bg:SetColorTexture(0.03, 0.04, 0.06, isSelected and 0.86 or 0.72)
        end
        if self.Badge and self.Badge.bg then
            self.Badge.bg:SetColorTexture(0.03, 0.04, 0.06, isSelected and 0.94 or 0.86)
        end
        self:UpdateCoordLabel()
    end

    mover:RefreshMoverVisual()

    mover:SetScript("OnShow", function(s)
        if not DM.isEditMode then
            s:EnableMouse(false)
            s:Hide()
            return
        end
        s:EnableMouse(true)
        s:SetFrameLevel((targetFrame:GetFrameLevel() or 10) + 30)
        if s.Badge then
            s.Badge:SetFrameLevel(s:GetFrameLevel() + 2)
        end
        if s.headerPill then s.headerPill:Hide() end
        if targetFrame.headerPill then targetFrame.headerPill:Hide() end
        s:RefreshMoverVisual()
    end)

    mover:SetScript("OnEnter", function(s)
        s._isHovered = true
        s:RefreshMoverVisual()
        local ar, ag, ab = DM:GetAccentColor()
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(displayTitle, ar, ag, ab)
        GameTooltip:AddLine("|cFF34D399Left-Drag:|r |cFFE2E8F0Move bar (Hold Shift to bypass snap)|r", 1, 1, 1)
        GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Select bar for precision nudge|r", 1, 1, 1)
        GameTooltip:AddLine("|cFF34D399Mouse Wheel:|r |cFFE2E8F0Adjust bar scale (60% - 150%)|r", 1, 1, 1)
        GameTooltip:AddLine("|cFFF59E0BShift + Right-Click:|r |cFFE2E8F0Reset position & scale|r", 1, 1, 1)
        GameTooltip:Show()
    end)

    mover:SetScript("OnLeave", function(s)
        s._isHovered = false
        if GameTooltip:IsOwned(s) then GameTooltip:Hide() end
        if DM.isEditMode then
            s:RefreshMoverVisual()
        end
    end)

    mover:SetScript("OnDragStart", function(s)
        if InCombatLockdown() or not DM.isEditMode then return end
        DM.selectedHUDKey = primaryKey
        DM.isDraggingHUD = true
        targetFrame._dmDragging = true
        if DM:IsSuiteHudInspectorActive() and _G.DynamicSuite and type(_G.DynamicSuite.NotifyExternalHudSelected) == "function" then
            DM._dispatchingExternalEdit = true
            pcall(_G.DynamicSuite.NotifyExternalHudSelected, upperKey)
            DM._dispatchingExternalEdit = false
        end
        if DM.targetBar and DM.targetBar.editMover and DM.targetBar.editMover.RefreshMoverVisual then
            DM.targetBar.editMover:RefreshMoverVisual()
        end
        if DM.flareBar and DM.flareBar.editMover and DM.flareBar.editMover.RefreshMoverVisual then
            DM.flareBar.editMover:RefreshMoverVisual()
        end
        DM:SyncBarScaleAndSizeToDB(targetFrame, primaryKey)
        if targetFrame.StopMovingOrSizing then pcall(targetFrame.StopMovingOrSizing, targetFrame) end
        if targetFrame.SetClampedToScreen then targetFrame:SetClampedToScreen(false) end
        if targetFrame.SetClampRectInsets then targetFrame:SetClampRectInsets(0, 0, 0, 0) end

        local startX, startY = GetLiveFrameCenterOffset(targetFrame, primaryKey, defaultY or defY)
        local _, _, _, uScale, relScale = GetLocalFrameScreenExtents(targetFrame, primaryKey)
        local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
        local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
        local fCx, fCy = targetFrame.GetCenter and targetFrame:GetCenter()
        local startVisOffX, startVisOffY
        if fCx and fCy and IsFiniteNum(fCx) and IsFiniteNum(fCy) then
            startVisOffX = (fCx * relScale) - (screenW / 2)
            startVisOffY = (fCy * relScale) - (screenH / 2)
        else
            startVisOffX = startX
            startVisOffY = startY
        end
        local rawCurX, rawCurY = GetCursorPosition()
        local startCurX = (rawCurX or 0) / uScale
        local startCurY = (rawCurY or 0) / uScale
        s._dragGrabVisX = startVisOffX - startCurX
        s._dragGrabVisY = startVisOffY - startCurY
        s._lastDragX = startX
        s._lastDragY = startY
        DM:RefreshEditModeInspector()

        s:SetScript("OnUpdate", function(m)
            if not IsMouseButtonDown("LeftButton") or InCombatLockdown() or not DM.isEditMode then
                m:SetScript("OnUpdate", nil)
                HideSnapGuides()
                return
            end
            local _, _, _, curUScale = GetLocalFrameScreenExtents(targetFrame, primaryKey)
            local cxRaw, cyRaw = GetCursorPosition()
            local rawX = ((cxRaw or 0) / curUScale) + (m._dragGrabVisX or 0)
            local rawY = ((cyRaw or 0) / curUScale) + (m._dragGrabVisY or 0)
            local lx, ly, gx, gy = ComputeSnappedAndClampedOffset(targetFrame, rawX, rawY, primaryKey, true)
            UpdateSnapGuides(gx, gy)
            if lx == m._lastDragX and ly == m._lastDragY then
                return
            end
            m._lastDragX = lx
            m._lastDragY = ly
            if not InCombatLockdown() then
                DM:SetBarCenterPoint(targetFrame, lx, ly, primaryKey)
            end
            m:UpdateCoordLabel(lx, ly)
            if DM.editInspector and DM.editInspector:IsShown() then
                if DM.editInspector.CoordText then
                    DM.editInspector.CoordText:SetText(string.format("Anchor: CENTER  |  X: %d  |  Y: %d  (1px drag + Magnetic Snap, Shift bypass)", lx, ly))
                end
                if DM.editInspector.EditX and not DM.editInspector.EditX:HasFocus() then
                    DM.editInspector.EditX:SetText(tostring(lx))
                end
                if DM.editInspector.EditY and not DM.editInspector.EditY:HasFocus() then
                    DM.editInspector.EditY:SetText(tostring(ly))
                end
            end
            if DM:IsSuiteHudInspectorActive() and _G.DynamicSuite and type(_G.DynamicSuite.NotifyExternalHudCoords) == "function" then
                pcall(_G.DynamicSuite.NotifyExternalHudCoords, upperKey, "CENTER", lx, ly)
            end
        end)
    end)

    mover:SetScript("OnDragStop", function(s)
        s:SetScript("OnUpdate", nil)
        HideSnapGuides()
        local lx, ly
        if s._dragGrabVisX ~= nil and s._dragGrabVisY ~= nil then
            local _, _, _, curUScale = GetLocalFrameScreenExtents(targetFrame, primaryKey)
            local cxRaw, cyRaw = GetCursorPosition()
            local curVisOffX = ((cxRaw or 0) / curUScale) + s._dragGrabVisX
            local curVisOffY = ((cyRaw or 0) / curUScale) + s._dragGrabVisY
            lx, ly = ComputeSnappedAndClampedOffset(targetFrame, curVisOffX, curVisOffY, primaryKey, true)
        elseif s._lastDragX ~= nil and s._lastDragY ~= nil then
            lx, ly = ComputeSnappedAndClampedOffset(targetFrame, s._lastDragX, s._lastDragY, primaryKey, false)
        else
            lx, ly = GetLiveFrameCenterOffset(targetFrame, primaryKey, defaultY or defY)
        end
        DM.isDraggingHUD = false
        targetFrame._dmDragging = false
        s._dragGrabVisX = nil
        s._dragGrabVisY = nil
        s._lastDragX = nil
        s._lastDragY = nil
        if not InCombatLockdown() then
            DM:SetBarCenterPoint(targetFrame, lx, ly, primaryKey)
        end
        DM:SaveHUDPosition(targetFrame, primaryKey, true, "CENTER", "CENTER", lx, ly)
        s:RefreshMoverVisual()
        DM:RefreshEditModeInspector()
    end)

    mover:SetScript("OnHide", function(s)
        s:SetScript("OnUpdate", nil)
        HideSnapGuides()
        s._dragGrabVisX = nil
        s._dragGrabVisY = nil
        s._lastDragX = nil
        s._lastDragY = nil
        if targetFrame._dmDragging then
            targetFrame._dmDragging = false
            DM.isDraggingHUD = false
        end
    end)

    mover:SetScript("OnMouseWheel", function(s, delta)
        if InCombatLockdown() or not DM.isEditMode then return end
        DM.selectedHUDKey = primaryKey
        local posBefore = DM:GetStoredHUDPosition(primaryKey, defaultY or defY)
        local curX = posBefore and posBefore.x or 0
        local curY = posBefore and posBefore.y or (defaultY or defY)
        local curScale = tonumber(DM:GetSetting(scaleKey)) or 1.0
        local nextScale = math.floor(math.max(0.60, math.min(1.50, curScale + (delta > 0 and 0.05 or -0.05))) * 100 + 0.5) / 100
        DM:SetSetting(scaleKey, nextScale)
        if not (primaryKey == "FlareBar") then
            DM:SetSetting("barScale", nextScale)
        end
        if primaryKey == "FlareBar" then
            DM:RefreshFlareBar()
        else
            DM:RefreshTargetBar()
        end
        local cx, cy = ComputeSnappedAndClampedOffset(targetFrame, curX, curY, primaryKey, false)
        DM:SetBarCenterPoint(targetFrame, cx, cy, primaryKey)
        DM:SaveHUDPosition(targetFrame, primaryKey, true, "CENTER", "CENTER", cx, cy)
        if DM.targetBar and DM.targetBar.editMover and DM.targetBar.editMover.RefreshMoverVisual then
            DM.targetBar.editMover:RefreshMoverVisual()
        end
        if DM.flareBar and DM.flareBar.editMover and DM.flareBar.editMover.RefreshMoverVisual then
            DM.flareBar.editMover:RefreshMoverVisual()
        end
        DM:RefreshEditModeInspector()
        DM:RefreshAll()
    end)

    mover:SetScript("OnClick", function(s, buttonName)
        if InCombatLockdown() or not DM.isEditMode then return end
        if buttonName == "RightButton" and IsShiftKeyDown() then
            DM.selectedHUDKey = primaryKey
            DM:ResetSingleHUDPosition(primaryKey, true)
            return
        end
        DM.selectedHUDKey = primaryKey
        if DM.targetBar and DM.targetBar.editMover and DM.targetBar.editMover.RefreshMoverVisual then
            DM.targetBar.editMover:RefreshMoverVisual()
        end
        if DM.flareBar and DM.flareBar.editMover and DM.flareBar.editMover.RefreshMoverVisual then
            DM.flareBar.editMover:RefreshMoverVisual()
        end
        DM:RefreshEditModeInspector()
        if DM:IsSuiteHudInspectorActive() and _G.DynamicSuite and type(_G.DynamicSuite.NotifyExternalHudSelected) == "function" then
            pcall(_G.DynamicSuite.NotifyExternalHudSelected, upperKey)
        end
    end)

    mover:Hide()
    targetFrame.editMover    = mover
    targetFrame.moverOverlay = mover
end

function DM:EnsureEditModeInspector()
    if self:IsRunningInSuite() then
        if self.editInspector and self.editInspector.Hide then
            self.editInspector:Hide()
        end
        if _G.DynamicMarkerEditModeInspector and _G.DynamicMarkerEditModeInspector.Hide then
            _G.DynamicMarkerEditModeInspector:Hide()
        end
        return nil
    end
    if self.editInspector then return self.editInspector end

    local insp = CreateFrame("Frame", "DynamicMarkerEditModeInspector", UIParent, "BackdropTemplate")
    insp:SetSize(560, 110)
    insp:SetFrameStrata("DIALOG")
    insp:SetFrameLevel(200)
    insp:SetToplevel(true)

    local function ApplyInspectorClampInsets(modal)
        local target = modal or insp
        if not target then return end
        local w = (target.GetWidth and target:GetWidth()) or 560
        local h = (target.GetHeight and target:GetHeight()) or 110
        local keepVisible = 60
        local allowOffX = math.max(0, w - keepVisible)
        local allowOffY = math.max(0, h - keepVisible)
        if target.SetClampedToScreen then target:SetClampedToScreen(true) end
        if target.SetClampRectInsets then
            target:SetClampRectInsets(allowOffX, -allowOffX, -allowOffY, allowOffY)
        end
    end

    function insp:RestoreSavedPosition()
        ApplyInspectorClampInsets(self)
        local pos = DM.db and DM.db.editModeModalPos
        self:ClearAllPoints()
        if type(pos) == "table" and pos.x ~= nil and pos.y ~= nil then
            local w = (self.GetWidth and self:GetWidth()) or 560
            local h = (self.GetHeight and self:GetHeight()) or 110
            local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
            local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
            local allowOffX = math.max(0, w - 60)
            local allowOffY = math.max(0, h - 60)
            local minX = -(screenW / 2) + (w / 2) - allowOffX
            local maxX = (screenW / 2) - (w / 2) + allowOffX
            local minY = -(screenH / 2) + (h / 2) - allowOffY
            local maxY = (screenH / 2) - (h / 2) + allowOffY
            local cx = math.max(minX, math.min(maxX, tonumber(pos.x) or 0))
            local cy = math.max(minY, math.min(maxY, tonumber(pos.y) or 0))
            self:SetPoint("CENTER", UIParent, "CENTER", cx, cy)
        else
            self:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
        end
    end

    local function SaveInspectorPosition()
        insp:StopMovingOrSizing()
        local cx, cy = insp:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if cx and cy and ux and uy then
            local dx = math.floor((cx - ux) + 0.5)
            local dy = math.floor((cy - uy) + 0.5)
            insp:ClearAllPoints()
            insp:SetPoint("CENTER", UIParent, "CENTER", dx, dy)
            if DM.db then
                DM.db.editModeModalPos = { point = "CENTER", relPoint = "CENTER", x = dx, y = dy }
            end
        end
    end

    insp:RestoreSavedPosition()
    insp:SetMovable(true)
    insp:EnableMouse(true)
    insp:RegisterForDrag("LeftButton")
    insp:SetScript("OnDragStart", function()
        if insp.selectorPopup and insp.selectorPopup:IsShown() then insp.selectorPopup:Hide() end
        insp:StartMoving()
    end)
    insp:SetScript("OnDragStop", SaveInspectorPosition)
    self:ApplyBackdrop(insp, COLORS.BgVoid, self:GetAccentColorTable(0.95), 1)

    local function TightenLabel(btn, padX, fixedW)
        if fixedW then btn:SetWidth(fixedW) end
        if btn and btn.Text then
            local px = padX or 3
            btn.Text:ClearAllPoints()
            btn.Text:SetPoint("LEFT", btn, "LEFT", px, 0)
            btn.Text:SetPoint("RIGHT", btn, "RIGHT", -px, 0)
            btn.Text:SetJustifyH("CENTER")
            btn.Text:SetWordWrap(false)
            if btn.Text.SetMaxLines then btn.Text:SetMaxLines(1) end
        end
    end

    local function AttachToggleStyle(btn, isNegative)
        btn._isToggleSelected = false
        btn._isNegative = not not isNegative
        if isNegative then
            local bar = btn:CreateTexture(nil, "OVERLAY", nil, 3)
            bar:SetHeight(1.5)
            bar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
            bar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
            bar:SetColorTexture(0.973, 0.443, 0.443, 0.92)
            bar:Hide()
            btn.offBar = bar
        end
        local function Paint(hovered)
            local ar, ag, ab = DM:GetAccentColor()
            if btn._isToggleSelected then
                if btn._isNegative then
                    DM:ApplyBackdrop(btn, { r = 0.118, g = 0.141, b = 0.188, a = 0.98 }, { r = 0.392, g = 0.455, b = 0.545, a = 0.90 }, 1)
                    if btn.Text then btn.Text:SetTextColor(0.886, 0.910, 0.941, 1.0) end
                    if btn.offBar then btn.offBar:Show() end
                else
                    DM:ApplyBackdrop(btn, { r = ar * 0.40, g = ag * 0.40, b = ab * 0.40, a = 0.95 }, { r = ar, g = ag, b = ab, a = 0.95 }, 1)
                    if btn.Text then btn.Text:SetTextColor(1, 1, 1, 1) end
                    if btn.offBar then btn.offBar:Hide() end
                end
            else
                if btn.offBar then btn.offBar:Hide() end
                if hovered then
                    DM:ApplyBackdrop(btn, COLORS.BgHover, { r = ar, g = ag, b = ab, a = 0.65 }, 1)
                    if btn.Text then btn.Text:SetTextColor(0.97, 0.98, 1.0, 1.0) end
                else
                    DM:ApplyBackdrop(btn, COLORS.BgElevated, COLORS.BorderStrong, 1)
                    if btn.Text then btn.Text:SetTextColor(0.78, 0.83, 0.90, 1.0) end
                end
            end
        end
        btn.RefreshStyle = Paint
        btn:SetScript("OnEnter", function(s)
            Paint(true)
            if s.tooltipText then
                GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
                GameTooltip:SetText(s.tooltipTitle or s.Text:GetText() or "DynamicMarker", 1, 1, 1)
                GameTooltip:AddLine(s.tooltipText, 0.80, 0.85, 0.92, true)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function()
            Paint(false)
            if GameTooltip:IsOwned(btn) then GameTooltip:Hide() end
        end)
        function btn:SetSelected(sel)
            self._isToggleSelected = not not sel
            Paint(false)
        end
        Paint(false)
    end

    local function SelectStandaloneHudKey(nextKey)
        local primaryKey = ResolveHUDKeyAliases(nextKey or "TargetBar")
        DM.selectedHUDKey = primaryKey
        if not DM:IsBarNormallyShown(primaryKey) then
            DM._previewHiddenMoverKey = primaryKey
        else
            DM._previewHiddenMoverKey = nil
        end
        DM:UpdateTargetBarVisibility()
        DM:UpdateFlareBarVisibility()
        if DM.SyncEditBarStates then DM:SyncEditBarStates() end
        DM:RefreshEditModeInspector()
    end

    local function SetSelectedHudVisibility(isShown)
        local primaryKey = ResolveHUDKeyAliases(DM.selectedHUDKey or "TargetBar")
        local visKey = (primaryKey == "FlareBar") and "flareBarVisibility" or "targetBarVisibility"
        local modeVal = isShown and "ALWAYS" or "HIDDEN"
        if DM.db then
            DM.db[visKey] = modeVal
        end
        if isShown then
            if DM._previewHiddenMoverKey == primaryKey then
                DM._previewHiddenMoverKey = nil
            end
        else
            DM._previewHiddenMoverKey = primaryKey
        end
        DM:UpdateTargetBarVisibility()
        DM:UpdateFlareBarVisibility()
        if primaryKey == "FlareBar" then
            DM:RefreshFlareBar()
        else
            DM:RefreshTargetBar()
        end
        if DM.SyncEditBarStates then DM:SyncEditBarStates() end
        DM:RefreshEditModeInspector()
        DM:RefreshAll()
    end

    -- Row 1: Compact Command & Selector Bar (34px tall)
    do
        local mHdr = CreateFrame("Frame", nil, insp)
        mHdr:SetPoint("TOPLEFT", insp, "TOPLEFT", 1, -1)
        mHdr:SetPoint("TOPRIGHT", insp, "TOPRIGHT", -1, -1)
        mHdr:SetHeight(34)
        mHdr.bg = mHdr:CreateTexture(nil, "BACKGROUND", nil, 1)
        mHdr.bg:SetAllPoints()
        mHdr.bg:SetColorTexture(0.030, 0.035, 0.048, 1.0)
        mHdr:EnableMouse(true)
        mHdr:RegisterForDrag("LeftButton")
        mHdr:SetScript("OnDragStart", function()
            if insp.selectorPopup and insp.selectorPopup:IsShown() then insp.selectorPopup:Hide() end
            insp:StartMoving()
        end)
        mHdr:SetScript("OnDragStop", SaveInspectorPosition)
        insp.mHdr = mHdr

        local mHdrDiv = mHdr:CreateTexture(nil, "OVERLAY", nil, 2)
        mHdrDiv:SetPoint("BOTTOMLEFT", mHdr, "BOTTOMLEFT", 0, 0)
        mHdrDiv:SetPoint("BOTTOMRIGHT", mHdr, "BOTTOMRIGHT", 0, 0)
        mHdrDiv:SetHeight(1)
        mHdr.hdrDiv = mHdrDiv

        local mLogo = CreateFrame("Frame", nil, mHdr, "BackdropTemplate")
        mLogo:SetSize(18, 18)
        mLogo:SetPoint("LEFT", mHdr, "LEFT", 8, 0)
        DM:ApplyBackdrop(mLogo, COLORS.BgVoid, DM:GetAccentColorTable(0.85), 1)
        mLogo.txt = mLogo:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        mLogo.txt:SetPoint("CENTER", mLogo, "CENTER", 0, 0)
        DM:StyleFont(mLogo.txt, 9, "OUTLINE", COLORS.TextPrimary)
        mLogo.txt:SetText("DM")
        insp.mLogo = mLogo

        local selectorBtn = DM:CreateButton(mHdr, "Focus Icons", 162, 22, nil, false)
        selectorBtn:SetWidth(162)
        selectorBtn:SetPoint("LEFT", mLogo, "RIGHT", 6, 0)
        selectorBtn.visDot = selectorBtn:CreateTexture(nil, "OVERLAY", nil, 3)
        selectorBtn.visDot:SetSize(6, 6)
        selectorBtn.visDot:SetPoint("LEFT", selectorBtn, "LEFT", 7, 0)
        selectorBtn.visDot:SetColorTexture(0.133, 0.773, 0.369, 1.0)
        selectorBtn.chevron = selectorBtn:CreateTexture(nil, "OVERLAY", nil, 3)
        selectorBtn.chevron:SetSize(10, 10)
        selectorBtn.chevron:SetPoint("RIGHT", selectorBtn, "RIGHT", -6, 0)
        selectorBtn.chevron:SetTexture(ICON_CHEVRON_DOWN)
        if selectorBtn.chevron.SetSnapToPixelGrid then
            selectorBtn.chevron:SetSnapToPixelGrid(false)
            selectorBtn.chevron:SetTexelSnappingBias(0)
        end
        if selectorBtn.Text then
            selectorBtn.Text:ClearAllPoints()
            selectorBtn.Text:SetPoint("LEFT", selectorBtn.visDot, "RIGHT", 5, 0)
            selectorBtn.Text:SetPoint("RIGHT", selectorBtn, "RIGHT", -18, 0)
            selectorBtn.Text:SetJustifyH("LEFT")
            selectorBtn.Text:SetWordWrap(false)
        end
        insp.selectorBtn = selectorBtn

        local hudDefs = {
            { key = "TargetBar", label = "Focus Icons" },
            { key = "FlareBar",  label = "World Flare Bar" },
        }

        local function EnsureSelectorPopup()
            if insp.selectorPopup then return insp.selectorPopup end
            local pop = CreateFrame("Frame", "DynamicMarkerHudSelectorPopup", UIParent, "BackdropTemplate")
            pop:SetFrameStrata("TOOLTIP")
            pop:SetFrameLevel(250)
            pop:SetToplevel(true)
            pop:SetClampedToScreen(true)
            pop:EnableMouse(true)
            DM:ApplyBackdrop(pop, { r = 0.043, g = 0.051, b = 0.071, a = 0.99 }, DM:GetAccentColorTable(0.85), 1)
            EnsureDMUISpecialFrame("DynamicMarkerHudSelectorPopup")

            local catcher = CreateFrame("Button", nil, pop)
            catcher:SetAllPoints(UIParent)
            catcher:SetFrameStrata("TOOLTIP")
            catcher:SetFrameLevel(245)
            catcher:RegisterForClicks("AnyDown", "AnyUp")
            catcher:SetScript("OnClick", function() pop:Hide() end)
            pop.catcher = catcher
            pop:SetScript("OnHide", function()
                if selectorBtn and selectorBtn.chevron then
                    selectorBtn.chevron:SetTexture(ICON_CHEVRON_DOWN)
                end
            end)
            pop:Hide()

            pop.rows = {}
            local rowH, gapY, pad = 22, 2, 4
            for i, hDef in ipairs(hudDefs) do
                local rb = DM:CreateButton(pop, hDef.label, 178, rowH, nil, false)
                rb:SetWidth(178)
                rb:SetPoint("TOPLEFT", pop, "TOPLEFT", pad, -(pad + (i - 1) * (rowH + gapY)))
                rb.hudKey = hDef.key
                rb.baseLabel = hDef.label
                rb.visDot = rb:CreateTexture(nil, "OVERLAY", nil, 3)
                rb.visDot:SetSize(6, 6)
                rb.visDot:SetPoint("LEFT", rb, "LEFT", 7, 0)
                rb.visDot:SetColorTexture(0.133, 0.773, 0.369, 1.0)
                if rb.Text then
                    rb.Text:ClearAllPoints()
                    rb.Text:SetPoint("LEFT", rb.visDot, "RIGHT", 6, 0)
                    rb.Text:SetPoint("RIGHT", rb, "RIGHT", -6, 0)
                    rb.Text:SetJustifyH("LEFT")
                    rb.Text:SetWordWrap(false)
                end
                AttachToggleStyle(rb, false)
                rb:SetScript("OnClick", function()
                    pop:Hide()
                    SelectStandaloneHudKey(hDef.key)
                end)
                pop.rows[i] = rb
            end
            pop:SetSize(186, (pad * 2) + (#hudDefs * rowH) + ((#hudDefs - 1) * gapY))
            insp.selectorPopup = pop
            return pop
        end

        if not selectorBtn._dmOnHideHooked then
            selectorBtn._dmOnHideHooked = true
            selectorBtn:HookScript("OnHide", function()
                if insp.selectorPopup and insp.selectorPopup:IsShown() then
                    insp.selectorPopup:Hide()
                end
            end)
        end

        selectorBtn:SetScript("OnClick", function(sBtn)
            local pop = EnsureSelectorPopup()
            if pop:IsShown() then
                pop:Hide()
                return
            end
            if sBtn.chevron then
                sBtn.chevron:SetTexture(ICON_CHEVRON_UP)
            end
            DM:ApplyBackdrop(pop, { r = 0.043, g = 0.051, b = 0.071, a = 0.99 }, DM:GetAccentColorTable(0.85), 1)
            local selKey = ResolveHUDKeyAliases(DM.selectedHUDKey or "TargetBar")
            for _, rb in ipairs(pop.rows) do
                local isVis = DM:IsBarNormallyShown(rb.hudKey)
                rb:SetSelected(rb.hudKey == selKey)
                if rb.visDot then
                    rb.visDot:SetColorTexture(isVis and 0.133 or 0.937, isVis and 0.773 or 0.267, isVis and 0.369 or 0.267, 1.0)
                end
            end
            pop:ClearAllPoints()
            pop:SetPoint("TOPLEFT", sBtn, "BOTTOMLEFT", 0, -2)
            pop:Show()
        end)

        local visHiddenBtn = DM:CreateButton(mHdr, "Hidden", 60, 22, function()
            SetSelectedHudVisibility(false)
        end, false)
        TightenLabel(visHiddenBtn, 3, 60)
        AttachToggleStyle(visHiddenBtn, true)
        visHiddenBtn:SetPoint("LEFT", selectorBtn, "RIGHT", 6, 0)
        insp.visHiddenBtn = visHiddenBtn

        local visShownBtn = DM:CreateButton(mHdr, "Shown", 60, 22, function()
            SetSelectedHudVisibility(true)
        end, false)
        TightenLabel(visShownBtn, 3, 60)
        AttachToggleStyle(visShownBtn, false)
        visShownBtn:SetPoint("LEFT", visHiddenBtn, "RIGHT", 3, 0)
        insp.visShownBtn = visShownBtn

        -- Right cluster: [Grid] [Reset] [Back to Suite] [X]
        local closeBtn = CreateFrame("Button", nil, mHdr, "BackdropTemplate")
        closeBtn:SetSize(22, 22)
        closeBtn:SetPoint("RIGHT", mHdr, "RIGHT", -6, 0)
        DM:ApplyBackdrop(closeBtn, { r = 1, g = 1, b = 1, a = 0.03 }, { r = 1, g = 1, b = 1, a = 0.12 }, 1)
        local line1 = closeBtn:CreateTexture(nil, "OVERLAY")
        line1:SetSize(10, 1.5)
        line1:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
        line1:SetColorTexture(1, 1, 1, 0.70)
        if line1.SetRotation then line1:SetRotation(math.rad(45)) end
        local line2 = closeBtn:CreateTexture(nil, "OVERLAY")
        line2:SetSize(10, 1.5)
        line2:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
        line2:SetColorTexture(1, 1, 1, 0.70)
        if line2.SetRotation then line2:SetRotation(math.rad(-45)) end
        closeBtn:SetScript("OnEnter", function(s)
            DM:ApplyBackdrop(s, { r = 1, g = 0.25, b = 0.25, a = 0.18 }, { r = 1, g = 0.35, b = 0.35, a = 0.75 }, 1)
            line1:SetColorTexture(1, 0.35, 0.35, 1)
            line2:SetColorTexture(1, 0.35, 0.35, 1)
        end)
        closeBtn:SetScript("OnLeave", function(s)
            DM:ApplyBackdrop(s, { r = 1, g = 1, b = 1, a = 0.03 }, { r = 1, g = 1, b = 1, a = 0.12 }, 1)
            line1:SetColorTexture(1, 1, 1, 0.70)
            line2:SetColorTexture(1, 1, 1, 0.70)
        end)
        closeBtn:SetScript("OnClick", function()
            DM:SetEditMode(false)
        end)

        local backBtn = DM:CreateButton(mHdr, "Back to Suite", 84, 22, function()
            DM:SetEditMode(false)
            local sf = DM:EnsureStandaloneShell()
            if sf and sf.Show then
                sf:Show()
                if sf.Raise then sf:Raise() end
            end
        end, true)
        TightenLabel(backBtn, 3, 84)
        backBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
        backBtn.tooltipTitle = "Return to DynamicMarker"
        backBtn.tooltipText = "Exits HUD Edit Mode and reopens the main DynamicMarker window."
        insp.backBtn = backBtn

        local resetConfirmPending = false
        local btnReset = DM:CreateButton(mHdr, "Reset", 46, 22, nil, false)
        TightenLabel(btnReset, 3, 46)
        btnReset:SetPoint("RIGHT", backBtn, "LEFT", -4, 0)
        btnReset:SetScript("OnClick", function()
            if InCombatLockdown() then
                print("|cFF38BDF8DynamicMarker|r: Cannot reset HUD positions during combat lockdown.")
                return
            end
            if not resetConfirmPending then
                resetConfirmPending = true
                if btnReset.Text then btnReset.Text:SetText("Sure?") end
                DM:ApplyBackdrop(btnReset, { r = 0.96, g = 0.72, b = 0.18, a = 0.32 }, { r = 0.96, g = 0.72, b = 0.18, a = 0.95 }, 1)
                C_Timer.After(3.5, function()
                    if resetConfirmPending then
                        resetConfirmPending = false
                        if btnReset.Text then btnReset.Text:SetText("Reset") end
                        btnReset.RefreshStyle(false)
                    end
                end)
                return
            end
            resetConfirmPending = false
            if btnReset.Text then btnReset.Text:SetText("Reset") end
            btnReset.RefreshStyle(false)
            local primaryKey = ResolveHUDKeyAliases(DM.selectedHUDKey or "TargetBar")
            if primaryKey == "FlareBar" then
                DM:SetSetting("flareBarScale", 1.0)
            else
                DM:SetSetting("targetBarScale", 1.0)
            end
            DM:ResetSingleHUDPosition(primaryKey, true)
            DM:RefreshEditModeInspector()
        end)
        btnReset.tooltipTitle = "Reset HUD"
        btnReset.tooltipText = "Reset the selected HUD bar's position, scale, opacity, border style, and orientation to defaults."
        insp.btnReset = btnReset

        local btnGrid = DM:CreateButton(mHdr, "Grid", 42, 22, function()
            if DM.db then
                DM.db.hudShowGrid = not DM:IsHudGridEnabled()
            end
            if DM.gridOverlay and DM.gridOverlay.SetShown then
                DM.gridOverlay:SetShown(DM:IsHudGridEnabled())
            end
            DM:RefreshEditModeInspector()
        end, false)
        TightenLabel(btnGrid, 3, 42)
        AttachToggleStyle(btnGrid, false)
        btnGrid:SetPoint("RIGHT", btnReset, "LEFT", -4, 0)
        btnGrid.tooltipTitle = "Toggle Alignment Grid"
        btnGrid.tooltipText = "Show or hide the screen alignment grid overlay."
        insp.btnGrid = btnGrid
    end

    -- Row 2: Compact Inspector Controls (36px tall, draggable dock body)
    do
        local inspCard = CreateFrame("Frame", nil, insp, "BackdropTemplate")
        inspCard:SetPoint("TOPLEFT", insp.mHdr, "BOTTOMLEFT", 4, -1)
        inspCard:SetPoint("TOPRIGHT", insp.mHdr, "BOTTOMRIGHT", -4, -1)
        inspCard:SetHeight(36)
        DM:ApplyBackdrop(inspCard, { r = 0.075, g = 0.086, b = 0.110, a = 0.96 }, { r = 1, g = 1, b = 1, a = 0.10 }, 1)
        inspCard:EnableMouse(true)
        inspCard:RegisterForDrag("LeftButton")
        inspCard:SetScript("OnDragStart", function()
            if insp.selectorPopup and insp.selectorPopup:IsShown() then insp.selectorPopup:Hide() end
            insp:StartMoving()
        end)
        inspCard:SetScript("OnDragStop", SaveInspectorPosition)
        insp.inspCard = inspCard

        local function CommitTypedCoord(axis, rawText)
            if InCombatLockdown() then return end
            local val = tonumber(rawText)
            if not val then
                DM:RefreshEditModeInspector()
                return
            end
            local primaryKey, _, _, _, defY = ResolveHUDKeyAliases(DM.selectedHUDKey or "TargetBar")
            local entry = Suite.hudElements[primaryKey]
            if not entry or not entry.frame then return end
            local pos = DM:GetStoredHUDPosition(primaryKey, entry.defaultY or defY)
            local nx = (axis == "X") and math.floor(val + 0.5) or (pos.x or 0)
            local ny = (axis == "Y") and math.floor(val + 0.5) or (pos.y or 0)
            DM:SaveHUDPosition(entry.frame, primaryKey, true, "CENTER", "CENTER", nx, ny)
            DM:ApplyHUDPosition(entry.frame, primaryKey, entry.defaultY or defY)
            DM:RefreshEditModeInspector()
        end

        local function CreateCoordEditBox(labelText, axis)
            local lbl = inspCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            DM:StyleFont(lbl, 10, "", COLORS.TextMuted)
            lbl:SetText(labelText)

            local box = CreateFrame("EditBox", nil, inspCard, "BackdropTemplate")
            box:SetSize(44, 22)
            box:SetAutoFocus(false)
            box:SetMaxLetters(6)
            box:SetJustifyH("CENTER")
            box:SetFontObject("GameFontHighlightSmall")
            DM:ApplyBackdrop(box, { r = 0.043, g = 0.051, b = 0.071, a = 0.98 }, COLORS.BorderStrong, 1)

            box:SetScript("OnEditFocusGained", function(eb)
                DM:ApplyBackdrop(eb, { r = 0.043, g = 0.051, b = 0.071, a = 0.98 }, DM:GetAccentColorTable(1.0), 1)
                eb:HighlightText()
            end)
            box:SetScript("OnEditFocusLost", function(eb)
                DM:ApplyBackdrop(eb, { r = 0.043, g = 0.051, b = 0.071, a = 0.98 }, COLORS.BorderStrong, 1)
                eb:HighlightText(0, 0)
                CommitTypedCoord(axis, eb:GetText())
            end)
            box:SetScript("OnEnterPressed", function(eb)
                local raw = eb:GetText()
                eb:ClearFocus()
                CommitTypedCoord(axis, raw)
            end)
            box:SetScript("OnEscapePressed", function(eb)
                eb:ClearFocus()
                DM:RefreshEditModeInspector()
            end)
            return lbl, box
        end

        local lblX, boxX = CreateCoordEditBox("X:", "X")
        lblX:SetPoint("LEFT", inspCard, "LEFT", 8, 0)
        boxX:SetPoint("LEFT", lblX, "RIGHT", 3, 0)
        insp.EditX = boxX

        local lblY, boxY = CreateCoordEditBox("Y:", "Y")
        lblY:SetPoint("LEFT", boxX, "RIGHT", 6, 0)
        boxY:SetPoint("LEFT", lblY, "RIGHT", 3, 0)
        insp.EditY = boxY

        local function MakeArrowBtn(texPath, rotRad, tt, fn)
            local b = DM:CreateButton(inspCard, "", 20, 22, fn, false)
            b:SetWidth(20)
            local tex = b:CreateTexture(nil, "OVERLAY")
            tex:SetSize(11, 11)
            tex:SetPoint("CENTER", b, "CENTER", 0, 0)
            tex:SetTexture(texPath)
            tex:SetRotation(rotRad or 0)
            if tex.SetSnapToPixelGrid then
                tex:SetSnapToPixelGrid(false)
                tex:SetTexelSnappingBias(0)
            end
            local ar, ag, ab = DM:GetAccentColor()
            tex:SetVertexColor(ar, ag, ab, 1.0)
            b.arrowTex = tex
            b.tooltipTitle = tt
            b.tooltipText = "Hold Shift to nudge by 10px instead of 1px."
            return b
        end

        local btnLeft  = MakeArrowBtn(ICON_CHEVRON_UP, math.rad(90), "Nudge Left (-X)", function()
            local s = IsShiftKeyDown() and 10 or 1
            DM:NudgeSpecificHUD(DM.selectedHUDKey or "TargetBar", -s, 0)
        end)
        local btnUp    = MakeArrowBtn(ICON_CHEVRON_UP, 0, "Nudge Up (+Y)", function()
            local s = IsShiftKeyDown() and 10 or 1
            DM:NudgeSpecificHUD(DM.selectedHUDKey or "TargetBar", 0, s)
        end)
        local btnDown  = MakeArrowBtn(ICON_CHEVRON_DOWN, 0, "Nudge Down (-Y)", function()
            local s = IsShiftKeyDown() and 10 or 1
            DM:NudgeSpecificHUD(DM.selectedHUDKey or "TargetBar", 0, -s)
        end)
        local btnRight = MakeArrowBtn(ICON_CHEVRON_UP, math.rad(-90), "Nudge Right (+X)", function()
            local s = IsShiftKeyDown() and 10 or 1
            DM:NudgeSpecificHUD(DM.selectedHUDKey or "TargetBar", s, 0)
        end)
        btnLeft:SetPoint("LEFT", boxY, "RIGHT", 6, 0)
        btnUp:SetPoint("LEFT", btnLeft, "RIGHT", 2, 0)
        btnDown:SetPoint("LEFT", btnUp, "RIGHT", 2, 0)
        btnRight:SetPoint("LEFT", btnDown, "RIGHT", 2, 0)
        insp.arrowBtns = { btnLeft, btnUp, btnDown, btnRight }

        local btnCenterH = DM:CreateButton(inspCard, "Center X", 58, 22, function()
            if InCombatLockdown() then return end
            local primaryKey, _, _, _, defY = ResolveHUDKeyAliases(DM.selectedHUDKey or "TargetBar")
            local entry = Suite.hudElements[primaryKey]
            if not entry or not entry.frame then return end
            local pos = DM:GetStoredHUDPosition(primaryKey, entry.defaultY or defY)
            DM:SaveHUDPosition(entry.frame, primaryKey, true, "CENTER", "CENTER", 0, pos.y or 0)
            DM:ApplyHUDPosition(entry.frame, primaryKey, entry.defaultY or defY)
            DM:RefreshEditModeInspector()
        end)
        TightenLabel(btnCenterH, 3, 58)
        btnCenterH:SetPoint("LEFT", btnRight, "RIGHT", 6, 0)

        local btnCenterV = DM:CreateButton(inspCard, "Center Y", 58, 22, function()
            if InCombatLockdown() then return end
            local primaryKey, _, _, _, defY = ResolveHUDKeyAliases(DM.selectedHUDKey or "TargetBar")
            local entry = Suite.hudElements[primaryKey]
            if not entry or not entry.frame then return end
            local pos = DM:GetStoredHUDPosition(primaryKey, entry.defaultY or defY)
            DM:SaveHUDPosition(entry.frame, primaryKey, true, "CENTER", "CENTER", pos.x or 0, 0)
            DM:ApplyHUDPosition(entry.frame, primaryKey, entry.defaultY or defY)
            DM:RefreshEditModeInspector()
        end)
        TightenLabel(btnCenterV, 3, 58)
        btnCenterV:SetPoint("LEFT", btnCenterH, "RIGHT", 3, 0)

        local HUD_MIN_SCALE, HUD_MAX_SCALE, HUD_SCALE_STEP, SLIDER_W = 0.60, 1.50, 0.05, 76
        local function GetSelectedHudScale()
            local primaryKey = ResolveHUDKeyAliases(DM.selectedHUDKey or "TargetBar")
            local scaleKey = (primaryKey == "FlareBar") and "flareBarScale" or "targetBarScale"
            return math.max(HUD_MIN_SCALE, math.min(HUD_MAX_SCALE, tonumber(DM:GetSetting(scaleKey)) or 1.0))
        end
        local function SetSelectedHudScale(val)
            if InCombatLockdown() then return end
            local primaryKey, _, _, _, defY = ResolveHUDKeyAliases(DM.selectedHUDKey or "TargetBar")
            local clamped = math.max(HUD_MIN_SCALE, math.min(HUD_MAX_SCALE, math.floor((val or 1.0) * 20 + 0.5) / 20))
            if primaryKey == "FlareBar" then
                DM:SetSetting("flareBarScale", clamped)
                DM:RefreshFlareBar()
                if DM.flareBar then DM:ApplyHUDPosition(DM.flareBar, "FlareBar", defY) end
            else
                DM:SetSetting("targetBarScale", clamped)
                DM:RefreshTargetBar()
                if DM.targetBar then DM:ApplyHUDPosition(DM.targetBar, "TargetBar", defY) end
            end
            DM:RefreshAll()
        end

        local scaleMinusBtn = DM:CreateButton(inspCard, "-", 20, 22, function()
            SetSelectedHudScale(GetSelectedHudScale() - HUD_SCALE_STEP)
            DM:RefreshEditModeInspector()
        end)
        TightenLabel(scaleMinusBtn, 2, 20)
        scaleMinusBtn:SetPoint("LEFT", btnCenterV, "RIGHT", 8, 0)

        local sliderHit = CreateFrame("Frame", nil, inspCard)
        sliderHit:SetSize(SLIDER_W, 22)
        sliderHit:SetPoint("LEFT", scaleMinusBtn, "RIGHT", 4, 0)
        sliderHit:EnableMouse(true)
        sliderHit:EnableMouseWheel(true)

        local track = sliderHit:CreateTexture(nil, "ARTWORK", nil, 1)
        track:SetSize(SLIDER_W, 4)
        track:SetPoint("CENTER", sliderHit, "CENTER", 0, 0)
        track:SetColorTexture(0.035, 0.039, 0.051, 0.98)

        local fill = sliderHit:CreateTexture(nil, "ARTWORK", nil, 2)
        fill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
        fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
        fill:SetWidth(1)

        local thumb = sliderHit:CreateTexture(nil, "OVERLAY", nil, 4)
        thumb:SetSize(6, 14)
        thumb:SetColorTexture(0.97, 0.98, 1.00, 1.0)
        if thumb.SetSnapToPixelGrid then
            thumb:SetSnapToPixelGrid(false)
            thumb:SetTexelSnappingBias(0)
        end

        local scalePlusBtn = DM:CreateButton(inspCard, "+", 20, 22, function()
            SetSelectedHudScale(GetSelectedHudScale() + HUD_SCALE_STEP)
            DM:RefreshEditModeInspector()
        end)
        TightenLabel(scalePlusBtn, 2, 20)
        scalePlusBtn:SetPoint("LEFT", sliderHit, "RIGHT", 4, 0)

        local scaleBadge = CreateFrame("Frame", nil, inspCard, "BackdropTemplate")
        scaleBadge:SetSize(42, 22)
        scaleBadge:SetPoint("LEFT", scalePlusBtn, "RIGHT", 4, 0)
        DM:ApplyBackdrop(scaleBadge, { r = 0.043, g = 0.051, b = 0.071, a = 0.98 }, COLORS.BorderStrong, 1)
        local scaleBadgeText = scaleBadge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        scaleBadgeText:SetPoint("CENTER", scaleBadge, "CENTER", 0, 0)
        DM:StyleFont(scaleBadgeText, 10, "", COLORS.TextPrimary)
        scaleBadgeText:SetText("100%")

        local function UpdateScaleVisual(val)
            local v = math.max(HUD_MIN_SCALE, math.min(HUD_MAX_SCALE, val or 1.0))
            local pct = (v - HUD_MIN_SCALE) / (HUD_MAX_SCALE - HUD_MIN_SCALE)
            local xOff = pct * SLIDER_W
            local r, g, b = DM:GetAccentColor()
            fill:SetColorTexture(r, g, b, 0.95)
            fill:SetWidth(math.max(1, xOff))
            thumb:ClearAllPoints()
            thumb:SetPoint("CENTER", track, "LEFT", xOff, 0)
            scaleBadgeText:SetText(string.format("%d%%", math.floor(v * 100 + 0.5)))
        end
        insp.UpdateScaleVisual = UpdateScaleVisual
        insp.GetSelectedHudScale = GetSelectedHudScale

        sliderHit:SetScript("OnMouseDown", function(s, button)
            if button == "LeftButton" then
                s:SetScript("OnUpdate", function(selfHit)
                    if not IsMouseButtonDown("LeftButton") or InCombatLockdown() then
                        selfHit:SetScript("OnUpdate", nil)
                        return
                    end
                    local eff = track:GetEffectiveScale()
                    local cx = GetCursorPosition() / eff
                    local left = track:GetLeft()
                    if left then
                        local pct = math.max(0, math.min(1, (cx - left) / SLIDER_W))
                        local raw = HUD_MIN_SCALE + pct * (HUD_MAX_SCALE - HUD_MIN_SCALE)
                        local snapped = math.floor(raw * 20 + 0.5) / 20
                        snapped = math.max(HUD_MIN_SCALE, math.min(HUD_MAX_SCALE, snapped))
                        if selfHit._lastSnapped ~= snapped then
                            selfHit._lastSnapped = snapped
                            if math.abs(snapped - GetSelectedHudScale()) >= 0.01 then
                                SetSelectedHudScale(snapped)
                            end
                            UpdateScaleVisual(snapped)
                        end
                    end
                end)
            elseif button == "RightButton" then
                SetSelectedHudScale(1.0)
                DM:RefreshEditModeInspector()
            end
        end)
        sliderHit:SetScript("OnMouseUp", function(s, button)
            if button == "LeftButton" then
                s:SetScript("OnUpdate", nil)
                DM:RefreshEditModeInspector()
            end
        end)
        sliderHit:SetScript("OnHide", function(s) s:SetScript("OnUpdate", nil) end)
        sliderHit:SetScript("OnMouseWheel", function(_, delta)
            SetSelectedHudScale(GetSelectedHudScale() + (delta > 0 and HUD_SCALE_STEP or -HUD_SCALE_STEP))
            DM:RefreshEditModeInspector()
        end)
    end

    -- Row 3: Live Appearance Bar (36px tall, Opacity | Border Style | Orientation)
    do
        local inspRow3 = CreateFrame("Frame", nil, insp, "BackdropTemplate")
        inspRow3:SetPoint("TOPLEFT", insp.inspCard, "BOTTOMLEFT", 0, -1)
        inspRow3:SetPoint("TOPRIGHT", insp.inspCard, "BOTTOMRIGHT", 0, -1)
        inspRow3:SetHeight(36)
        DM:ApplyBackdrop(inspRow3, { r = 0.075, g = 0.086, b = 0.110, a = 0.96 }, { r = 1, g = 1, b = 1, a = 0.10 }, 1)
        inspRow3:EnableMouse(true)
        inspRow3:RegisterForDrag("LeftButton")
        inspRow3:SetScript("OnDragStart", function()
            if insp.selectorPopup and insp.selectorPopup:IsShown() then insp.selectorPopup:Hide() end
            insp:StartMoving()
        end)
        inspRow3:SetScript("OnDragStop", SaveInspectorPosition)
        insp.inspRow3 = inspRow3

        -- Left cluster: Opacity Slider (20% - 100%, step 5%)
        local HUD_MIN_OPA, HUD_MAX_OPA, HUD_OPA_STEP, OPA_SLIDER_W = 0.20, 1.00, 0.05, 44
        local opaLbl = inspRow3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        opaLbl:SetPoint("LEFT", inspRow3, "LEFT", 6, 0)
        DM:StyleFont(opaLbl, 10, "", COLORS.TextMuted)
        opaLbl:SetText("Opacity:")

        local function GetSelectedHudOpacity()
            local primaryKey = ResolveHUDKeyAliases(DM.selectedHUDKey or "TargetBar")
            local opaKey = (primaryKey == "FlareBar") and "flareBarOpacity" or "targetBarOpacity"
            return math.max(HUD_MIN_OPA, math.min(HUD_MAX_OPA, tonumber(DM:GetSetting(opaKey)) or 0.95))
        end

        local function SetSelectedHudOpacity(val)
            if InCombatLockdown() then return end
            local primaryKey = ResolveHUDKeyAliases(DM.selectedHUDKey or "TargetBar")
            local clamped = math.max(HUD_MIN_OPA, math.min(HUD_MAX_OPA, math.floor((val or 0.95) * 20 + 0.5) / 20))
            if primaryKey == "FlareBar" then
                DM:SetSetting("flareBarOpacity", clamped)
                DM:RefreshFlareBar()
            else
                DM:SetSetting("targetBarOpacity", clamped)
                DM:RefreshTargetBar()
            end
            if DM.SyncEditBarStates then DM:SyncEditBarStates() end
            DM:RefreshAll()
        end

        local opaMinusBtn = DM:CreateButton(inspRow3, "-", 18, 22, function()
            SetSelectedHudOpacity(GetSelectedHudOpacity() - HUD_OPA_STEP)
            DM:RefreshEditModeInspector()
        end)
        TightenLabel(opaMinusBtn, 2, 18)
        opaMinusBtn:SetPoint("LEFT", opaLbl, "RIGHT", 3, 0)

        local opaHit = CreateFrame("Frame", nil, inspRow3)
        opaHit:SetSize(OPA_SLIDER_W, 22)
        opaHit:SetPoint("LEFT", opaMinusBtn, "RIGHT", 3, 0)
        opaHit:EnableMouse(true)
        opaHit:EnableMouseWheel(true)

        local opaTrack = opaHit:CreateTexture(nil, "ARTWORK", nil, 1)
        opaTrack:SetSize(OPA_SLIDER_W, 4)
        opaTrack:SetPoint("CENTER", opaHit, "CENTER", 0, 0)
        opaTrack:SetColorTexture(0.035, 0.039, 0.051, 0.98)

        local opaFill = opaHit:CreateTexture(nil, "ARTWORK", nil, 2)
        opaFill:SetPoint("TOPLEFT", opaTrack, "TOPLEFT", 0, 0)
        opaFill:SetPoint("BOTTOMLEFT", opaTrack, "BOTTOMLEFT", 0, 0)
        opaFill:SetWidth(1)

        local opaThumb = opaHit:CreateTexture(nil, "OVERLAY", nil, 4)
        opaThumb:SetSize(6, 14)
        opaThumb:SetColorTexture(0.97, 0.98, 1.00, 1.0)
        if opaThumb.SetSnapToPixelGrid then
            opaThumb:SetSnapToPixelGrid(false)
            opaThumb:SetTexelSnappingBias(0)
        end

        local opaPlusBtn = DM:CreateButton(inspRow3, "+", 18, 22, function()
            SetSelectedHudOpacity(GetSelectedHudOpacity() + HUD_OPA_STEP)
            DM:RefreshEditModeInspector()
        end)
        TightenLabel(opaPlusBtn, 2, 18)
        opaPlusBtn:SetPoint("LEFT", opaHit, "RIGHT", 3, 0)

        local opaBadge = CreateFrame("Frame", nil, inspRow3, "BackdropTemplate")
        opaBadge:SetSize(34, 22)
        opaBadge:SetPoint("LEFT", opaPlusBtn, "RIGHT", 3, 0)
        DM:ApplyBackdrop(opaBadge, { r = 0.043, g = 0.051, b = 0.071, a = 0.98 }, COLORS.BorderStrong, 1)
        local opaBadgeText = opaBadge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        opaBadgeText:SetPoint("CENTER", opaBadge, "CENTER", 0, 0)
        DM:StyleFont(opaBadgeText, 10, "", COLORS.TextPrimary)
        opaBadgeText:SetText("95%")

        local function UpdateOpacityVisual(val)
            local v = math.max(HUD_MIN_OPA, math.min(HUD_MAX_OPA, val or 0.95))
            local pct = (v - HUD_MIN_OPA) / (HUD_MAX_OPA - HUD_MIN_OPA)
            local xOff = pct * OPA_SLIDER_W
            local r, g, b = DM:GetAccentColor()
            opaFill:SetColorTexture(r, g, b, 0.95)
            opaFill:SetWidth(math.max(1, xOff))
            opaThumb:ClearAllPoints()
            opaThumb:SetPoint("CENTER", opaTrack, "LEFT", xOff, 0)
            opaBadgeText:SetText(string.format("%d%%", math.floor(v * 100 + 0.5)))
        end
        insp.UpdateOpacityVisual = UpdateOpacityVisual
        insp.GetSelectedHudOpacity = GetSelectedHudOpacity

        opaHit:SetScript("OnMouseDown", function(s, button)
            if button == "LeftButton" then
                s:SetScript("OnUpdate", function(selfHit)
                    if not IsMouseButtonDown("LeftButton") or InCombatLockdown() then
                        selfHit:SetScript("OnUpdate", nil)
                        return
                    end
                    local eff = opaTrack:GetEffectiveScale()
                    local cx = GetCursorPosition() / eff
                    local left = opaTrack:GetLeft()
                    if left then
                        local pct = math.max(0, math.min(1, (cx - left) / OPA_SLIDER_W))
                        local raw = HUD_MIN_OPA + pct * (HUD_MAX_OPA - HUD_MIN_OPA)
                        local snapped = math.floor(raw * 20 + 0.5) / 20
                        snapped = math.max(HUD_MIN_OPA, math.min(HUD_MAX_OPA, snapped))
                        if selfHit._lastSnapped ~= snapped then
                            selfHit._lastSnapped = snapped
                            if math.abs(snapped - GetSelectedHudOpacity()) >= 0.01 then
                                SetSelectedHudOpacity(snapped)
                            end
                            UpdateOpacityVisual(snapped)
                        end
                    end
                end)
            elseif button == "RightButton" then
                SetSelectedHudOpacity(0.95)
                DM:RefreshEditModeInspector()
            end
        end)
        opaHit:SetScript("OnMouseUp", function(s, button)
            if button == "LeftButton" then
                s:SetScript("OnUpdate", nil)
                DM:RefreshEditModeInspector()
            end
        end)
        opaHit:SetScript("OnHide", function(s) s:SetScript("OnUpdate", nil) end)
        opaHit:SetScript("OnMouseWheel", function(_, delta)
            SetSelectedHudOpacity(GetSelectedHudOpacity() + (delta > 0 and HUD_OPA_STEP or -HUD_OPA_STEP))
            DM:RefreshEditModeInspector()
        end)

        -- Center cluster: Border Style Segmented Pills (Accent | Dark | None) + Apply All
        local bdrLbl = inspRow3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bdrLbl:SetPoint("LEFT", opaBadge, "RIGHT", 5, 0)
        DM:StyleFont(bdrLbl, 10, "", COLORS.TextMuted)
        bdrLbl:SetText("Border:")

        local function GetSelectedHudBorderStyle()
            local primaryKey = ResolveHUDKeyAliases(DM.selectedHUDKey or "TargetBar")
            local style = (primaryKey == "FlareBar" and DM:GetSetting("flareBarBorderStyle"))
                or (primaryKey == "TargetBar" and DM:GetSetting("targetBarBorderStyle"))
                or DM:GetSetting("hudBorderStyle")
                or "ACCENT"
            if style == "SUBTLE" then style = "DARK" end
            return style
        end

        local function SetSelectedHudBorderStyle(val)
            if InCombatLockdown() then return end
            local primaryKey = ResolveHUDKeyAliases(DM.selectedHUDKey or "TargetBar")
            local perBarKey = (primaryKey == "FlareBar") and "flareBarBorderStyle" or "targetBarBorderStyle"
            DM:SetSetting(perBarKey, val)
            DM:SetSetting("hudBorderStyle", val)
            if primaryKey == "FlareBar" then
                DM:RefreshFlareBar()
            else
                DM:RefreshTargetBar()
            end
            DM:RefreshEditModeInspector()
            DM:RefreshAll()
        end

        local bdrAccentBtn = DM:CreateButton(inspRow3, "Accent", 42, 22, function() SetSelectedHudBorderStyle("ACCENT") end, false)
        TightenLabel(bdrAccentBtn, 2, 42)
        if bdrAccentBtn.Text then DM:StyleFont(bdrAccentBtn.Text, 10, "", COLORS.TextPrimary) end
        AttachToggleStyle(bdrAccentBtn, false)
        bdrAccentBtn:SetPoint("LEFT", bdrLbl, "RIGHT", 3, 0)

        local bdrDarkBtn = DM:CreateButton(inspRow3, "Dark", 34, 22, function() SetSelectedHudBorderStyle("DARK") end, false)
        TightenLabel(bdrDarkBtn, 2, 34)
        if bdrDarkBtn.Text then DM:StyleFont(bdrDarkBtn.Text, 10, "", COLORS.TextPrimary) end
        AttachToggleStyle(bdrDarkBtn, false)
        bdrDarkBtn:SetPoint("LEFT", bdrAccentBtn, "RIGHT", 2, 0)

        local bdrNoneBtn = DM:CreateButton(inspRow3, "None", 34, 22, function() SetSelectedHudBorderStyle("NONE") end, false)
        TightenLabel(bdrNoneBtn, 2, 34)
        if bdrNoneBtn.Text then DM:StyleFont(bdrNoneBtn.Text, 10, "", COLORS.TextPrimary) end
        AttachToggleStyle(bdrNoneBtn, true)
        bdrNoneBtn:SetPoint("LEFT", bdrDarkBtn, "RIGHT", 2, 0)

        local applyAllBtn = DM:CreateButton(inspRow3, "Apply All", 52, 22, function()
            if InCombatLockdown() then
                print("|cFFF97316DynamicMarker|r: Cannot apply HUD appearance during combat lockdown.")
                return
            end
            local curOpa = GetSelectedHudOpacity()
            local curBdr = GetSelectedHudBorderStyle()
            DM:SetSetting("targetBarOpacity", curOpa)
            DM:SetSetting("flareBarOpacity", curOpa)
            DM:SetSetting("targetBarBorderStyle", curBdr)
            DM:SetSetting("flareBarBorderStyle", curBdr)
            DM:SetSetting("hudBorderStyle", curBdr)
            DM:RefreshTargetBar()
            DM:RefreshFlareBar()
            if DM.SyncEditBarStates then DM:SyncEditBarStates() end
            DM:RefreshEditModeInspector()
            DM:RefreshAll()
            local bdrName = (curBdr == "DARK" and "Dark") or (curBdr == "NONE" and "None") or "Accent"
            print(string.format("|cFFF97316DynamicMarker|r: Applied %d%% opacity and %s border style to all bars.", math.floor(curOpa * 100 + 0.5), bdrName))
        end, false)
        TightenLabel(applyAllBtn, 2, 52)
        if applyAllBtn.Text then DM:StyleFont(applyAllBtn.Text, 10, "", { r = 0.976, g = 0.451, b = 0.086 }) end
        AttachToggleStyle(applyAllBtn, false)
        applyAllBtn:SetPoint("LEFT", bdrNoneBtn, "RIGHT", 5, 0)
        applyAllBtn.tooltipTitle = "Apply Opacity & Border to All Bars"
        applyAllBtn.tooltipText = "Copies the current Opacity and Border Style to both Focus Icons and World Flare Bar."
        insp.applyAllBtn = applyAllBtn

        insp.borderBtns = {
            ACCENT = bdrAccentBtn,
            DARK   = bdrDarkBtn,
            NONE   = bdrNoneBtn,
        }
        insp.GetSelectedHudBorderStyle = GetSelectedHudBorderStyle

        -- Right cluster: Orientation Toggle (Horiz | Vert)
        local function GetSelectedHudOrientation()
            local primaryKey = ResolveHUDKeyAliases(DM.selectedHUDKey or "TargetBar")
            local oKey = (primaryKey == "FlareBar") and "flareBarOrientation" or "targetBarOrientation"
            return (DM:GetSetting(oKey) == "VERTICAL") and "VERTICAL" or "HORIZONTAL"
        end

        local function SetSelectedHudOrientation(val)
            if InCombatLockdown() then return end
            local primaryKey, _, _, _, defY = ResolveHUDKeyAliases(DM.selectedHUDKey or "TargetBar")
            local oKey = (primaryKey == "FlareBar") and "flareBarOrientation" or "targetBarOrientation"
            local bar = (primaryKey == "FlareBar") and DM.flareBar or DM.targetBar
            DM:SetSetting(oKey, (val == "VERTICAL") and "VERTICAL" or "HORIZONTAL")
            if primaryKey == "FlareBar" then
                DM:RefreshFlareBar()
            else
                DM:RefreshTargetBar()
            end
            if bar then
                DM:SyncBarScaleAndSizeToDB(bar, primaryKey)
                local pos = DM:GetStoredHUDPosition(primaryKey, defY)
                local cx, cy = DM:ClampHUDPositionToScreen(bar, primaryKey, "CENTER", "CENTER", pos.x or 0, pos.y or defY, { enableSnap = false })
                DM:WriteHUDCoordsToDB(primaryKey, "CENTER", "CENTER", cx, cy)
                DM:ApplyHUDPosition(bar, primaryKey, defY)
                if bar.editMover and bar.editMover.RefreshMoverVisual then
                    bar.editMover:RefreshMoverVisual()
                end
            end
            DM:RefreshEditModeInspector()
            DM:RefreshAll()
        end

        local orientVertBtn = DM:CreateButton(inspRow3, "Vert", 34, 22, function() SetSelectedHudOrientation("VERTICAL") end, false)
        TightenLabel(orientVertBtn, 2, 34)
        if orientVertBtn.Text then DM:StyleFont(orientVertBtn.Text, 10, "", COLORS.TextPrimary) end
        AttachToggleStyle(orientVertBtn, false)
        orientVertBtn:SetPoint("RIGHT", inspRow3, "RIGHT", -6, 0)

        local orientHorizBtn = DM:CreateButton(inspRow3, "Horiz", 38, 22, function() SetSelectedHudOrientation("HORIZONTAL") end, false)
        TightenLabel(orientHorizBtn, 2, 38)
        if orientHorizBtn.Text then DM:StyleFont(orientHorizBtn.Text, 10, "", COLORS.TextPrimary) end
        AttachToggleStyle(orientHorizBtn, false)
        orientHorizBtn:SetPoint("RIGHT", orientVertBtn, "LEFT", -2, 0)

        local orientLbl = inspRow3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        orientLbl:SetPoint("RIGHT", orientHorizBtn, "LEFT", -3, 0)
        DM:StyleFont(orientLbl, 10, "", COLORS.TextMuted)
        orientLbl:SetText("Orient:")

        insp.orientBtns = {
            HORIZONTAL = orientHorizBtn,
            VERTICAL   = orientVertBtn,
        }
        insp.GetSelectedHudOrientation = GetSelectedHudOrientation
    end

    local foundSpecial = false
    for i = 1, #UISpecialFrames do
        if UISpecialFrames[i] == "DynamicMarkerEditModeInspector" then
            foundSpecial = true
            break
        end
    end
    if not foundSpecial then
        table.insert(UISpecialFrames, "DynamicMarkerEditModeInspector")
    end

    insp:SetScript("OnHide", function()
        if insp.selectorPopup and insp.selectorPopup:IsShown() then
            insp.selectorPopup:Hide()
        end
        if not self._isExitingEditMode and self.isEditMode then
            self:SetEditMode(false, { fromEsc = true })
        end
    end)

    insp:Hide()
    self.editInspector = insp
    return insp
end

function DM:RefreshEditModeInspector()
    if self:IsRunningInSuite() then
        if self.editInspector and self.editInspector.Hide then self.editInspector:Hide() end
        return
    end
    local insp = self.editInspector
    if not insp or not insp:IsShown() then return end

    local key = ResolveHUDKeyAliases(self.selectedHUDKey or "TargetBar")
    local entry = Suite.hudElements[key] or Suite.hudElements["TargetBar"]
    local pos = self:GetStoredHUDPosition(key, entry and entry.defaultY or -140)
    local ar, ag, ab = self:GetAccentColor()

    self:ApplyBackdrop(insp, COLORS.BgVoid, self:GetAccentColorTable(0.95), 1)
    if insp.mHdr and insp.mHdr.hdrDiv then
        insp.mHdr.hdrDiv:SetColorTexture(ar, ag, ab, 0.35)
    end
    if insp.mLogo then
        self:ApplyBackdrop(insp.mLogo, COLORS.BgVoid, { r = ar, g = ag, b = ab, a = 0.85 }, 1)
    end
    if insp.backBtn and insp.backBtn.RefreshStyle then
        insp.backBtn:RefreshStyle(false)
    end

    local isShown = self:IsBarNormallyShown(key)
    if insp.selectorBtn then
        if insp.selectorBtn.Text then
            insp.selectorBtn.Text:SetText((key == "FlareBar") and "World Flare Bar" or "Focus Icons")
        end
        if insp.selectorBtn.visDot then
            insp.selectorBtn.visDot:SetColorTexture(isShown and 0.133 or 0.937, isShown and 0.773 or 0.267, isShown and 0.369 or 0.267, 1.0)
        end
        if insp.selectorBtn.chevron then
            insp.selectorBtn.chevron:SetVertexColor(1, 1, 1, 0.78)
        end
    end
    if insp.visShownBtn then insp.visShownBtn:SetSelected(isShown) end
    if insp.visHiddenBtn then insp.visHiddenBtn:SetSelected(not isShown) end
    if insp.btnGrid then insp.btnGrid:SetSelected(self:IsHudGridEnabled()) end

    if insp.arrowBtns then
        for _, abtn in ipairs(insp.arrowBtns) do
            if abtn.arrowTex then abtn.arrowTex:SetVertexColor(ar, ag, ab, 1.0) end
        end
    end
    if insp.UpdateScaleVisual and insp.GetSelectedHudScale then
        insp.UpdateScaleVisual(insp.GetSelectedHudScale())
    end
    if insp.UpdateOpacityVisual and insp.GetSelectedHudOpacity then
        insp.UpdateOpacityVisual(insp.GetSelectedHudOpacity())
    end
    if insp.borderBtns and insp.GetSelectedHudBorderStyle then
        local activeBorder = insp.GetSelectedHudBorderStyle()
        for styleKey, bBtn in pairs(insp.borderBtns) do
            bBtn:SetSelected(styleKey == activeBorder)
        end
    end
    if insp.orientBtns and insp.GetSelectedHudOrientation then
        local activeOrient = insp.GetSelectedHudOrientation()
        for oKey, oBtn in pairs(insp.orientBtns) do
            oBtn:SetSelected(oKey == activeOrient)
        end
    end
    if insp.EditX and not insp.EditX:HasFocus() then
        insp.EditX:SetText(tostring(pos.x or 0))
    end
    if insp.EditY and not insp.EditY:HasFocus() then
        insp.EditY:SetText(tostring(pos.y or 0))
    end
end

function DM:IsSuiteHudInspectorActive()
    if self:IsRunningInSuite() then
        return true
    end
    local ds = _G.DynamicSuite
    if type(ds) == "table" and type(ds.IsHudEditModeActive) == "function" then
        local ok, active = pcall(ds.IsHudEditModeActive)
        if ok and active then return true end
    end
    local dl = _G.DynamicLoad
    if type(dl) == "table" and type(dl.IsHudEditModeActive) == "function" then
        local ok, active = pcall(dl.IsHudEditModeActive)
        if ok and active then return true end
    end
    if _G.DynamicSuiteEditModeModal and _G.DynamicSuiteEditModeModal:IsShown() then
        return true
    end
    return false
end

function DM:HasExternalEditModeController()
    return self:IsSuiteHudInspectorActive()
end

function DM:EnsureHudEscCatcher()
    if self.hudEscCatcher then return self.hudEscCatcher end
    local esc = _G.DynamicMarkerHudEscFrame or CreateFrame("Frame", "DynamicMarkerHudEscFrame", UIParent)
    esc:SetSize(1, 1)
    esc:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
    esc:EnableMouse(false)
    esc:Hide()

    local found = false
    for i = 1, #UISpecialFrames do
        if UISpecialFrames[i] == "DynamicMarkerHudEscFrame" then
            found = true
            break
        end
    end
    if not found then
        table.insert(UISpecialFrames, "DynamicMarkerHudEscFrame")
    end

    esc:SetScript("OnHide", function()
        if not self._isExitingEditMode and self.isEditMode then
            self:SetEditMode(false, { fromEsc = true })
        end
    end)

    if _G.GameMenuFrame and _G.GameMenuFrame.HookScript and not self._hookedGameMenuHudEsc then
        self._hookedGameMenuHudEsc = true
        _G.GameMenuFrame:HookScript("OnShow", function()
            if self.isEditMode then
                self:SetEditMode(false, { fromEsc = true })
            end
        end)
    end

    self.hudEscCatcher = esc
    return esc
end

function DM:RefreshHudEditToggleButtons()
    if type(self.hudEditToggleButtons) ~= "table" then return end
    local active = (self.isEditMode == true)
    for _, btn in ipairs(self.hudEditToggleButtons) do
        if btn then
            if not btn.isEditHudButton then
                btn.isAccent = true
            end
            if btn.SetLabel then
                btn:SetLabel(active and "Lock HUD" or "Edit HUD")
            elseif btn.Text then
                btn.Text:SetText(active and "Lock HUD" or "Edit HUD")
            end
            if btn.RefreshStyle then
                btn.RefreshStyle(false)
            end
        end
    end
end

function DM:SyncEditBarStates()
    local inCombat = InCombatLockdown and InCombatLockdown()
    local suiteInspectorActive = self:IsRunningInSuite() or self:IsSuiteHudInspectorActive()
    local function SyncOne(bar, isTarget)
        if not bar then return end
        local hudKey = isTarget and "TargetBar" or "FlareBar"
        local showMover = self.isEditMode and self:IsEditMoverVisible(hudKey)
        if not self.isEditMode then
            bar._dsEditModeActive = false
            bar._dmDragging = false
        else
            bar._dsEditModeActive = showMover and suiteInspectorActive or false
        end
        if bar.headerPill then bar.headerPill:Hide() end
        if bar.editMover then
            bar.editMover:SetScript("OnUpdate", nil)
            if bar.editMover.headerPill then bar.editMover.headerPill:Hide() end
            bar.editMover:EnableMouse(showMover)
            if showMover then
                bar.editMover:SetFrameStrata("HIGH")
                bar.editMover:SetFrameLevel(math.max((bar:GetFrameLevel() or 10) + 50, 80))
                bar.editMover:Show()
                if bar.editMover.RefreshMoverVisual then
                    bar.editMover:RefreshMoverVisual()
                elseif bar.editMover.UpdateCoordLabel then
                    bar.editMover:UpdateCoordLabel()
                end
            else
                bar.editMover:Hide()
            end
        end
        if not inCombat then
            bar:SetMovable(true)
            bar:SetClampedToScreen(false)
            if bar.SetClampRectInsets then bar:SetClampRectInsets(0, 0, 0, 0) end
            self:SetBarChildButtonsMouseEnabled(bar, not showMover)
            if showMover then
                local isNorm = self:IsBarNormallyShown(hudKey)
                local barOpa = isTarget and (self.db and self.db.targetBarOpacity or 0.95) or (self.db and self.db.flareBarOpacity or 0.95)
                bar:SetAlpha(isNorm and barOpa or math.min(0.65, barOpa))
                bar:Show()
            else
                if isTarget then
                    self:UpdateTargetBarVisibility()
                else
                    self:UpdateFlareBarVisibility()
                end
            end
        else
            if isTarget then
                self.pendingTargetBarSync = true
            else
                self.pendingFlareBarSync = true
            end
            self.pendingBarVisibilityUpdate = true
        end
    end
    SyncOne(self.targetBar, true)
    SyncOne(self.flareBar, false)
end

function DM:SetEditMode(enabled, opts)
    self:CloseDropdownMenu()
    local inCombat = (InCombatLockdown and InCombatLockdown()) or (opts and opts.fromCombat == true)
    if enabled and inCombat then
        print("|cFF38BDF8DynamicMarker|r: HUD Edit Mode cannot be activated during combat.")
        return false
    end
    opts = opts or {}
    if opts.selectedHUDKey then
        local primaryKey = ResolveHUDKeyAliases(opts.selectedHUDKey)
        self.selectedHUDKey = primaryKey
    end
    self.selectedHUDKey = self.selectedHUDKey or "TargetBar"
    if opts.snapMode ~= nil then
        self.externalSnapMode = opts.snapMode
    end
    if opts.suitePreviewState ~= nil then
        self._suitePreviewState = opts.suitePreviewState
    end
    if enabled and not opts.fromSuite then
        self._suitePreviewState = nil
        if opts.explicitFromCard then
            local primaryKey = ResolveHUDKeyAliases(self.selectedHUDKey)
            self._previewHiddenMoverKey = (not self:IsBarNormallyShown(primaryKey)) and primaryKey or nil
        else
            self._previewHiddenMoverKey = nil
            if not self:IsBarNormallyShown(self.selectedHUDKey) then
                if self:IsBarNormallyShown("TargetBar") then
                    self.selectedHUDKey = "TargetBar"
                elseif self:IsBarNormallyShown("FlareBar") then
                    self.selectedHUDKey = "FlareBar"
                end
            end
        end
    elseif not enabled then
        self._previewHiddenMoverKey = nil
        self._suitePreviewState = nil
    end

    if enabled then
        if not self.targetBar then self:InitTargetBar() end
        if not self.flareBar then self:InitFlareBar() end
    end

    if enabled and not opts.fromSuite and not self._dispatchingExternalEdit and not self._inExternalSetEditMode then
        local enterFn = (_G.DynamicSuite and _G.DynamicSuite.EnterHudEditMode) or (_G.DynamicLoad and _G.DynamicLoad.EnterHudEditMode)
        if type(enterFn) == "function" then
            if self.targetBar and not inCombat then self:SetBarChildButtonsMouseEnabled(self.targetBar, false) end
            if self.flareBar and not inCombat then self:SetBarChildButtonsMouseEnabled(self.flareBar, false) end
            self._dispatchingExternalEdit = true
            local suiteArg = opts.explicitFromCard and ((self.selectedHUDKey == "FlareBar") and "FLARE" or "TARGET") or "ALL"
            pcall(enterFn, suiteArg)
            self._dispatchingExternalEdit = false
        end
    elseif not enabled and not opts.fromSuite and not self._dispatchingExternalEdit and not self._inExternalSetEditMode then
        if self:IsSuiteHudInspectorActive() then
            local exitFn = (_G.DynamicSuite and _G.DynamicSuite.ExitHudEditMode) or (_G.DynamicLoad and _G.DynamicLoad.ExitHudEditMode)
            if type(exitFn) == "function" then
                self._dispatchingExternalEdit = true
                pcall(exitFn, false)
                self._dispatchingExternalEdit = false
            end
        end
    end

    local wasEdit = self.isEditMode
    self.isEditMode = not not enabled
    if not self.isEditMode then
        self.externalSnapMode = nil
        self.isDraggingHUD = false
        if self.targetBar then
            self.targetBar._dmDragging = false
            self.targetBar._dsDragging = false
        end
        if self.flareBar then
            self.flareBar._dmDragging = false
            self.flareBar._dsDragging = false
        end
    end

    if wasEdit and not self.isEditMode and not inCombat and not opts.skipSave then
        if self.targetBar then
            local tPos = self:GetStoredHUDPosition("TargetBar", -140)
            self:SaveHUDPosition(self.targetBar, "TargetBar", true, "CENTER", "CENTER", tPos and tPos.x or 0, tPos and tPos.y or -140)
        end
        if self.flareBar then
            local fPos = self:GetStoredHUDPosition("FlareBar", -182)
            self:SaveHUDPosition(self.flareBar, "FlareBar", true, "CENTER", "CENTER", fPos and fPos.x or 0, fPos and fPos.y or -182)
        end
    end

    local suiteInspectorActive = self:IsRunningInSuite() or self:IsSuiteHudInspectorActive()
    local grid = (not suiteInspectorActive) and self:EnsureGridOverlay() or nil
    local escCatcher = self:EnsureHudEscCatcher()

    self._isExitingEditMode = true
    if self.isEditMode then
        escCatcher:Show()
        if not suiteInspectorActive then
            if grid and grid.SetShown then grid:SetShown(self:IsHudGridEnabled()) end
            local insp = self:EnsureEditModeInspector()
            if insp then
                if insp.selectorPopup and insp.selectorPopup.Hide then insp.selectorPopup:Hide() end
                if insp.RestoreSavedPosition then insp:RestoreSavedPosition() end
                if insp.Show then insp:Show() end
            end
            self:RefreshEditModeInspector()
        else
            if grid and grid.Hide then grid:Hide() end
            if self.gridOverlay and self.gridOverlay.Hide then self.gridOverlay:Hide() end
            if _G.DynamicMarkerGridOverlay and _G.DynamicMarkerGridOverlay.Hide then _G.DynamicMarkerGridOverlay:Hide() end
            if self.editInspector and self.editInspector:IsShown() then
                self.editInspector:Hide()
            end
            if _G.DynamicMarkerEditModeInspector and _G.DynamicMarkerEditModeInspector:IsShown() then
                _G.DynamicMarkerEditModeInspector:Hide()
            end
        end
    else
        escCatcher:Hide()
        if grid and grid.Hide then grid:Hide() end
        if self.gridOverlay and self.gridOverlay.Hide then self.gridOverlay:Hide() end
        if _G.DynamicMarkerGridOverlay and _G.DynamicMarkerGridOverlay.Hide then _G.DynamicMarkerGridOverlay:Hide() end
        if self.editInspector and self.editInspector:IsShown() then
            self.editInspector:Hide()
        end
        if _G.DynamicMarkerEditModeInspector and _G.DynamicMarkerEditModeInspector:IsShown() then
            _G.DynamicMarkerEditModeInspector:Hide()
        end
    end
    self._isExitingEditMode = false

    if not self.isEditMode then
        self.isDraggingHUD = false
        HideSnapGuides()
    end

    if not inCombat then
        self:RefreshTargetBar()
        self:RefreshFlareBar()
        self:UpdateTargetBarVisibility()
        self:UpdateFlareBarVisibility()
    end
    self:SyncEditBarStates()

    self:RefreshHudEditToggleButtons()
    self:RefreshAll()
    return true
end

function DM:ToggleHudEditMode(preferredHudKey)
    self:CloseDropdownMenu()
    local explicitFromCard = (preferredHudKey ~= nil and preferredHudKey ~= "")
    if explicitFromCard then
        local primaryKey = ResolveHUDKeyAliases(preferredHudKey)
        self.selectedHUDKey = primaryKey
        self._previewHiddenMoverKey = (not self:IsBarNormallyShown(primaryKey)) and primaryKey or nil
    else
        self._previewHiddenMoverKey = nil
    end
    if self:IsRunningInSuite() and _G.DynamicSuite then
        local ds = _G.DynamicSuite
        local targetKey = explicitFromCard and ((self.selectedHUDKey == "FlareBar") and "FLARE" or "TARGET") or "ALL"
        local isDsActive = (type(ds.IsHudEditModeActive) == "function" and ds.IsHudEditModeActive()) or false
        if isDsActive and type(ds.ExitHudEditMode) == "function" then
            pcall(ds.ExitHudEditMode, false)
            return
        elseif not isDsActive and type(ds.EnterHudEditMode) == "function" then
            pcall(ds.EnterHudEditMode, targetKey)
            return
        end
    end
    if self.isEditMode then
        self:SetEditMode(false)
    else
        self:SetEditMode(true, {
            selectedHUDKey = self.selectedHUDKey,
            explicitFromCard = explicitFromCard,
        })
    end
end

function DM:RegisterWithSuiteHudEditMode()
    if self._registeredSuiteHudCallback then return true end
    local ds = _G.DynamicSuite
    if type(ds) == "table" and type(ds.RegisterHudEditCallback) == "function" then
        local ok = pcall(ds.RegisterHudEditCallback, ds, "DynamicMarker", function(active, selectedSuiteTarget, snapMode, suitePreviewOpts)
            if self._dispatchingExternalEdit then
                self.externalSnapMode = snapMode
                self._suitePreviewState = suitePreviewOpts
                if selectedSuiteTarget == "FLARE" then
                    self.selectedHUDKey = "FlareBar"
                elseif selectedSuiteTarget == "TARGET" then
                    self.selectedHUDKey = "TargetBar"
                end
                if self.SyncEditBarStates then
                    self:SyncEditBarStates()
                end
                if self.targetBar and self.targetBar.editMover and self.targetBar.editMover.RefreshMoverVisual then
                    self.targetBar.editMover:RefreshMoverVisual()
                end
                if self.flareBar and self.flareBar.editMover and self.flareBar.editMover.RefreshMoverVisual then
                    self.flareBar.editMover:RefreshMoverVisual()
                end
                return
            end
            local nextHudKey = self.selectedHUDKey or "TargetBar"
            if selectedSuiteTarget == "FLARE" then
                nextHudKey = "FlareBar"
            elseif selectedSuiteTarget == "TARGET" then
                nextHudKey = "TargetBar"
            end
            self:SetEditMode(active, {
                fromSuite = true,
                selectedHUDKey = nextHudKey,
                snapMode = snapMode,
                suitePreviewState = suitePreviewOpts,
                fromCombat = InCombatLockdown and InCombatLockdown(),
            })
        end)
        if ok then
            self._registeredSuiteHudCallback = true
            return true
        end
    end
    return false
end

-- ============================================================================
-- 13. INTERACTIVE KEYBIND CAPTURE BUTTON WIDGET
-- ============================================================================

function DM:CreateKeybindButton(parent, width, getter, setter, defaultKey)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 204, 26)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self:ApplyBackdrop(btn, COLORS.BgElevated, COLORS.BorderStrong)

    btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.Text:SetPoint("LEFT", btn, "LEFT", 6, 0)
    btn.Text:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    btn.Text:SetJustifyH("CENTER")
    btn.Text:SetWordWrap(false)
    self:StyleFont(btn.Text, 11.5, "", COLORS.TextPrimary)

    function btn:RefreshValue()
        local k = getter()
        local _, _, _, hex = DM:GetAccentColor()
        local isBound = (type(k) == "string" and k ~= "" and k ~= "NONE")
        if not isBound then
            self.Text:SetText("|cFF94A3B8Unbound (Click to Bind)|r")
        else
            self.Text:SetText("|cFF" .. (hex or "CBD5E1") .. "[" .. k .. "]|r  |cFF94A3B8(Click Rebind)|r")
        end
    end
    btn.RefreshKey = btn.RefreshValue

    function btn:StopCapture(commitKey)
        self.isCapturing = false
        self:EnableKeyboard(false)
        self:SetScript("OnKeyDown", nil)
        self:SetScript("OnMouseDown", nil)
        DM:ApplyBackdrop(self, COLORS.BgElevated, COLORS.BorderStrong)
        if commitKey ~= nil then
            setter(commitKey)
        end
        self:RefreshValue()
        DM:RefreshKeybindTelemetryAndTabTitle()
    end

    btn:SetScript("OnClick", function(s, mouseBtn)
        if mouseBtn == "RightButton" then
            s:StopCapture("")
            return
        end
        if s.isCapturing then
            s:StopCapture(nil)
            return
        end

        s.isCapturing = true
        s.Text:SetText("|cFFF59E0BPress key (Esc cancel, Del unbind)|r")
        DM:ApplyBackdrop(s, COLORS.BgHover, COLORS.Amber)
        s:EnableKeyboard(true)
        if s.SetPropagateKeyboardInput then
            s:SetPropagateKeyboardInput(false)
        end

        s:SetScript("OnKeyDown", function(capBtn, key)
            if key == "ESCAPE" then
                capBtn:StopCapture(nil)
                return
            end
            if key == "BACKSPACE" or key == "DELETE" then
                capBtn:StopCapture("")
                return
            end
            if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
                return
            end
            local prefix = ""
            if IsAltKeyDown() then prefix = prefix .. "ALT-" end
            if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
            if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
            capBtn:StopCapture(prefix .. key)
        end)

        s:SetScript("OnMouseDown", function(capBtn, mBtn)
            local hasMod = IsAltKeyDown() or IsControlKeyDown() or IsShiftKeyDown()
            if (mBtn == "LeftButton" or mBtn == "RightButton") and not hasMod then return end
            local prefix = ""
            if IsAltKeyDown() then prefix = prefix .. "ALT-" end
            if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
            if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
            local mapped = mBtn
            if mBtn == "LeftButton" then mapped = "BUTTON1"
            elseif mBtn == "RightButton" then mapped = "BUTTON2"
            elseif mBtn == "MiddleButton" then mapped = "BUTTON3"
            elseif type(mBtn) == "string" then mapped = string.upper(mBtn)
            end
            capBtn:StopCapture(prefix .. mapped)
        end)
    end)

    btn:SetScript("OnEnter", function(s)
        if not s.isCapturing then
            local ar, ag, ab = DM:GetAccentColor()
            DM:ApplyBackdrop(s, COLORS.BgHover, { r = ar, g = ag, b = ab, a = 0.8 })
        end
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText("Interactive Keybind Capture", 1, 1, 1)
        GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Press any key, modifier combo, or mouse button (MB3/MB4/MB5). Press Esc to cancel, or Backspace/Delete to unbind.|r", 1, 1, 1, true)
        GameTooltip:AddLine("|cFFF87171Right-Click:|r |cFFE2E8F0Clear Keybind (Unbind)|r", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(s)
        if not s.isCapturing then
            DM:ApplyBackdrop(s, COLORS.BgElevated, COLORS.BorderStrong)
        end
        if GameTooltip:IsOwned(s) then GameTooltip:Hide() end
    end)

    btn:RefreshValue()
    return btn
end

-- ============================================================================
-- 14. DYNAMICMARKER WORKSPACE (CONFLICT BANNER + 3 SUB-TABS)
-- ============================================================================

function DM:BuildWorkspace(parentContainer)
    RegisterMarkerPopupCloser()
    if self.workspaceFrame then
        self.workspaceFrame:SetParent(parentContainer)
        self.workspaceFrame:ClearAllPoints()
        self.workspaceFrame:SetPoint("TOPLEFT", parentContainer, "TOPLEFT", 0, 0)
        self.workspaceFrame:SetPoint("BOTTOMRIGHT", parentContainer, "BOTTOMRIGHT", 0, 0)
        self.workspaceFrame:Show()
        self:RefreshAll()
        return self.workspaceFrame
    end

    local ws = CreateFrame("Frame", "DynamicMarkerWorkspaceFrame", parentContainer)
    ws:SetPoint("TOPLEFT", parentContainer, "TOPLEFT", 0, 0)
    ws:SetPoint("BOTTOMRIGHT", parentContainer, "BOTTOMRIGHT", 0, 0)
    ws:SetScript("OnShow", function() self:RefreshTargetBar(); self:RefreshFlareBar() end)
    ws:SetScript("OnHide", function() self:CloseDropdownMenu(); self:RefreshTargetBar(); self:RefreshFlareBar() end)
    self.workspaceFrame = ws
    self.refreshables = {}
    self.hudEditToggleButtons = {}
    table.insert(self.refreshables, function() self:RefreshHudEditToggleButtons() end)

    -- ------------------------------------------------------------------------
    -- A. Inline Active Addon Conflict Banner (Top of Workspace)
    -- ------------------------------------------------------------------------
    local banner = CreateFrame("Frame", nil, ws, "BackdropTemplate")
    banner:SetHeight(58)
    banner:SetPoint("TOPLEFT", ws, "TOPLEFT", 14, -10)
    banner:SetPoint("TOPRIGHT", ws, "TOPRIGHT", -16, -10)
    self:ApplyBackdrop(banner, { r = 0.20, g = 0.14, b = 0.05, a = 0.96 }, COLORS.Amber, 1)

    banner.BtnKeepOther = self:CreateButton(banner, "Keep FocusMarker", 145, 26, function()
        if banner._mode == "ADVISORY" then
            self:DismissAdvisoryConflict(banner._addonName or "DecorVendor")
        else
            local c = banner._addonName or (self.activeConflicts and self.activeConflicts[1] and self.activeConflicts[1].name) or "FocusMarker"
            self:ResolveConflictKeepOther(c)
        end
    end)
    banner.BtnKeepOther:SetPoint("RIGHT", banner, "RIGHT", -12, 0)

    banner.BtnUseDynamic = self:CreateButton(banner, "Import & Use DynamicMarker", 195, 26, function()
        if banner._mode == "ADVISORY" then
            self:ResolveAdvisoryDisable(banner._addonName or "DecorVendor")
        else
            local c = banner._addonName or (self.activeConflicts and self.activeConflicts[1] and self.activeConflicts[1].name) or "FocusMarker"
            self:ResolveConflictUseDynamic(c)
        end
    end, true)
    banner.BtnUseDynamic:SetPoint("RIGHT", banner.BtnKeepOther, "LEFT", -8, 0)

    banner.BtnReload = self:CreateButton(banner, "Reload UI", 120, 26, function()
        ReloadUI()
    end, true)
    banner.BtnReload:SetPoint("RIGHT", banner, "RIGHT", -12, 0)
    banner.BtnReload:Hide()

    banner.Title = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    banner.Title:SetPoint("TOPLEFT", banner, "TOPLEFT", 14, -10)
    banner.Title:SetPoint("RIGHT", banner.BtnUseDynamic, "LEFT", -16, 0)
    banner.Title:SetJustifyH("LEFT")
    banner.Title:SetWordWrap(false)
    self:StyleFont(banner.Title, 12, "", COLORS.Amber)

    banner.Sub = banner:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    banner.Sub:SetPoint("TOPLEFT", banner.Title, "BOTTOMLEFT", 0, -4)
    banner.Sub:SetPoint("RIGHT", banner.BtnUseDynamic, "LEFT", -16, 0)
    banner.Sub:SetJustifyH("LEFT")
    banner.Sub:SetWordWrap(true)
    self:StyleFont(banner.Sub, 11, "", COLORS.TextPrimary)

    ws.conflictBanner = banner

    -- ------------------------------------------------------------------------
    -- B. 3-Tab Sub-Navigation Strip (Gold Standard Bevel Geometry)
    -- ------------------------------------------------------------------------
    local tabBar = CreateFrame("Frame", nil, ws, "BackdropTemplate")
    tabBar:SetHeight(34)
    tabBar:SetPoint("TOPLEFT", ws, "TOPLEFT", 14, -10)
    tabBar:SetPoint("TOPRIGHT", ws, "TOPRIGHT", -16, -10)
    self:ApplyBackdrop(tabBar, { r = 0.043, g = 0.051, b = 0.071, a = 0.98 }, { r = 1, g = 1, b = 1, a = 0.08 }, 1)
    ws.tabBar = tabBar
    ws.tabStrip = tabBar

    ws.subTabBtns = {}
    ws.subTabPages = {}

    local function SelectSubTab(idx)
        self:CloseDropdownMenu()
        self.db.activeSubTab = idx
        local ar, ag, ab = self:GetAccentColor()
        for i, tBtn in ipairs(ws.subTabBtns) do
            local active = (i == idx)
            if active then
                self:ApplyBackdrop(tBtn, { r = ar * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), g = ag * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), b = ab * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), a = 0.98 }, { r = ar, g = ag, b = ab, a = 0.95 }, 1)
                self:StyleFont(tBtn.Text, 12, "", { r = 1, g = 1, b = 1, a = 1 })
                if tBtn.BottomBar then
                    tBtn.BottomBar:SetColorTexture(ar, ag, ab, 1.0)
                    tBtn.BottomBar:Show()
                end
            else
                self:ApplyBackdrop(tBtn, { r = 0.063, g = 0.075, b = 0.102, a = 0.96 }, { r = 0.145, g = 0.165, b = 0.212, a = 0.95 }, 1)
                self:StyleFont(tBtn.Text, 12, "", { r = 0.68, g = 0.74, b = 0.82, a = 1 })
                if tBtn.BottomBar then
                    tBtn.BottomBar:Hide()
                end
            end
        end
        for i, page in ipairs(ws.subTabPages) do
            page:SetShown(i == idx)
            if i == idx and page.UpdateScrollLayout then
                page.UpdateScrollLayout()
            end
        end
    end
    self.SelectSubTab = function(_, idx, expandDrawers)
        if expandDrawers and self.db then
            self.db.tuneChatExpanded = true
            self.db.tuneTargetBarExpanded = true
            self.db.tuneFlareBarExpanded = true
            if self.RefreshAll then self:RefreshAll() end
        end
        SelectSubTab(idx)
    end; self.SelectTab = self.SelectSubTab; self.SetActiveTab = self.SelectSubTab

    local tabDefs = {
        [1] = "Focus Icons",
        [2] = self:GetSubTab2Title(),
        [3] = "Macro Setup",
    }

    local tabContentHeights = {
        [1] = 610,
        [2] = 640,
        [3] = 680,
    }

    for i = 1, 3 do
        local btn = CreateFrame("Button", nil, tabBar, "BackdropTemplate")
        btn:SetHeight(26)
        if i == 1 then
            btn:SetPoint("LEFT", tabBar, "LEFT", 4, 0)
        else
            btn:SetPoint("LEFT", ws.subTabBtns[i - 1], "RIGHT", 6, 0)
        end
        btn:SetWidth(182)

        btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.Text:SetPoint("LEFT", btn, "LEFT", 8, 0)
        btn.Text:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
        btn.Text:SetJustifyH("CENTER")
        btn.Text:SetWordWrap(false)
        btn.Text:SetText(tabDefs[i])

        btn.BottomBar = btn:CreateTexture(nil, "OVERLAY")
        btn.BottomBar:SetHeight(2)
        btn.BottomBar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
        btn.BottomBar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        btn.BottomBar:Hide()

        btn:SetScript("OnClick", function() SelectSubTab(i) end)
        ws.subTabBtns[i] = btn

        local page = self:CreateObsidianScrollPage(ws, tabBar, tabContentHeights[i])
        ws.subTabPages[i] = page
    end
    local function ReflowSubTabBar()
        local w = tabBar:GetWidth()
        if not w or w <= 60 then return end
        local usable = w - 20
        local defaultW = math.floor(usable / 3)
        local b2 = ws.subTabBtns[2]
        local tab2TextW = 0
        if b2 and b2.Text then
            tab2TextW = (b2.Text.GetUnboundedStringWidth and b2.Text:GetUnboundedStringWidth()) or b2.Text:GetStringWidth() or 0
        end
        local w2 = math.min(math.floor(usable * 0.50), math.max(defaultW, math.ceil(tab2TextW + 24)))
        local rem = usable - w2
        local w1 = math.max(120, math.floor(rem * 0.5))
        local widths = { w1, w2 }
        for i, b in ipairs(ws.subTabBtns) do
            b:ClearAllPoints()
            if i == 1 then
                b:SetPoint("LEFT", tabBar, "LEFT", 4, 0)
                b:SetWidth(widths[1])
            elseif i == 2 then
                b:SetPoint("LEFT", ws.subTabBtns[1], "RIGHT", 6, 0)
                b:SetWidth(widths[2])
            else
                b:SetPoint("LEFT", ws.subTabBtns[2], "RIGHT", 6, 0)
                b:SetPoint("RIGHT", tabBar, "RIGHT", -4, 0)
            end
        end
    end
    ws.ReflowSubTabBar = ReflowSubTabBar
    tabBar:SetScript("OnSizeChanged", ReflowSubTabBar)
    tabBar:HookScript("OnShow", function() C_Timer.After(0, ReflowSubTabBar) end)
    C_Timer.After(0, ReflowSubTabBar)

    -- ========================================================================
    -- SUB-TAB 1: Raid Target Icons
    -- ========================================================================
    local p1 = ws.subTabPages[1].content
    local p1Sec1 = self:CreateSectionBox(p1, 0, 310)
    local p1Hdr1 = self:CreateSectionHeader(p1Sec1, -10, "FOCUS TARGET MARKING & CHAT ANNOUNCEMENTS", "Select your preferred raid target icon, active group scope, and automatic party/raid chat announcements.")

    local p1Sec2 = self:CreateSectionBox(p1, nil, 356)
    p1Sec2:SetPoint("TOPLEFT", p1Sec1, "BOTTOMLEFT", 0, -14)
    p1Sec2:SetPoint("TOPRIGHT", p1Sec1, "BOTTOMRIGHT", 0, -14)
    local p1Hdr2 = self:CreateSectionHeader(p1Sec2, -10, "ON-SCREEN FOCUS BAR HUD", "Configure visibility, orientation, border style, scale, and opacity for the floating 8-icon Focus Bar.")
    local p1HudBtn = self:CreateEditHudButton(p1Hdr2, function()
        self:ToggleHudEditMode("TargetBar")
    end)
    if self.isEditMode and p1HudBtn.SetLabel then p1HudBtn:SetLabel("Lock HUD") end
    p1HudBtn:SetPoint("RIGHT", p1Hdr2, "RIGHT", 0, 2)
    if p1Hdr2.subtitle then
        p1Hdr2.subtitle:SetPoint("RIGHT", p1HudBtn, "LEFT", -10, 0)
    end
    table.insert(self.hudEditToggleButtons, p1HudBtn)

    -- Row 1: Preferred Focus Icon (FocusMarker-Style Right-Aligned 30x30 Square Icon Picker Row)
    local r1 = self:CreateSpaciousRow(p1Sec1, -54, 58,
        "Preferred Focus Icon",
        "Select your preferred focus icon. Automatically updates your [DynamicMark] macro and On-Screen Focus Bar.")

    local iconBtnSize = 30
    local iconGap = 4
    local iconContainer = CreateFrame("Frame", nil, r1)
    iconContainer:SetSize((8 * iconBtnSize) + (7 * iconGap), iconBtnSize)
    iconContainer:SetPoint("RIGHT", r1, "RIGHT", -14, 0)
    r1:BindControl(iconContainer)

    r1.iconBtns = {}
    for i = 1, 8 do
        local info = RAID_ICONS[i]
        local ib = CreateFrame("Button", nil, iconContainer, "BackdropTemplate")
        ib:SetSize(iconBtnSize, iconBtnSize)
        if i == 1 then
            ib:SetPoint("LEFT", iconContainer, "LEFT", 0, 0)
        else
            ib:SetPoint("LEFT", r1.iconBtns[i - 1], "RIGHT", iconGap, 0)
        end

        local tex = ib:CreateTexture(nil, "ARTWORK")
        tex:SetSize(20, 20)
        tex:SetPoint("CENTER", ib, "CENTER", 0, 0)
        tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        tex:SetTexCoord(unpack(info.coords))
        DisableTexturePixelSnap(tex)
        ib.IconTex = tex

        local activeBar = ib:CreateTexture(nil, "OVERLAY")
        activeBar:SetHeight(2)
        activeBar:SetPoint("BOTTOMLEFT", ib, "BOTTOMLEFT", 1, 1)
        activeBar:SetPoint("BOTTOMRIGHT", ib, "BOTTOMRIGHT", -1, 1)
        activeBar:Hide()
        ib.ActiveBar = activeBar

        ib:SetScript("OnEnter", function(s)
            local ar, ag, ab = self:GetAccentColor()
            if (self.db.focusIcon or 8) ~= i then
                self:ApplyBackdrop(s, COLORS.BgHover, { r = 1, g = 1, b = 1, a = 0.40 })
            end
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText(info.label, ar, ag, ab)
            GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Set as your Preferred Focus Icon|r", 1, 1, 1)
            GameTooltip:Show()
        end)
        ib:SetScript("OnLeave", function()
            GameTooltip:Hide()
            self:RefreshAll()
        end)
        ib:SetScript("OnClick", function()
            self:SetFocusIcon(i, true)
        end)
        r1.iconBtns[i] = ib
    end

    -- Row 2: Active Group Scope (Direction A 4-Pill Segmented Control)
    local r2 = self:CreateSpaciousRow(p1Sec1, -118, 58,
        "Active Group Scope",
        "Choose whether focus raid target marking activates in Party & Raid, Party, Raid, or All (Solo + Group).")
    local pillsScope = self:CreateSegmentedPills(r2, GROUP_SCOPE_OPTIONS,
        function()
            local _, canon = self:NormalizeGroupScope(self.db.groupScope)
            return canon
        end,
        function(v)
            local _, canon = self:NormalizeGroupScope(v)
            self.db.groupScope = canon
            self:CreateOrUpdateFocusMarkerMacro("SETTING")
            self:UpdateTargetBarVisibility()
            self:UpdateFlareBarVisibility()
            self:RefreshTargetBar()
            self:RefreshFlareBar()
            self:RefreshAll()
        end, 286)
    pillsScope:SetPoint("RIGHT", r2, "RIGHT", -14, 0)
    r2:BindControl(pillsScope)

    -- Row 3: Announce Marks in Chat (Direction A 2-Pill Binary Switch + Full-Width Horizontal Chevron Toggle Bar)
    local r3 = self:CreateSpaciousRow(p1Sec1, -182, 58,
        "Announce Marks in Chat",
        "Announce your focus icon to Party, Raid, or Instance chat on selection and Ready Check.")
    local pillsChat = self:CreateSegmentedPills(r3, CHAT_ANNOUNCE_OPTIONS,
        function() return self.db.chatAnnounce end,
        function(v)
            local wasMuted = (self.db.chatAnnounce == "MUTED")
            self.db.chatAnnounce = v
            if v == "ACTIVE" and (wasMuted or self.db.tuneChatExpanded == nil) then
                self.db.tuneChatExpanded = true
            end
            self:RefreshAll()
        end, 168)
    pillsChat:SetPoint("TOPRIGHT", r3, "TOPRIGHT", -14, -16)
    r3:BindControl(pillsChat)

    local tuneChatBtn = self:AttachHorizontalChevronBar(r3, 1,
        function() return self.db.chatAnnounce ~= "MUTED" end,
        function() return self.db.tuneChatExpanded ~= false end,
        function()
            self.db.tuneChatExpanded = not (self.db.tuneChatExpanded ~= false)
            self:RefreshAll()
        end)

    local r3SubChannel = self:CreateSpaciousRow(r3, -82, 54,
        "Chat Channel",
        "Choose which chat channel receives your Focus Icon announcement when enabled.", true)
    local pillsChatChannel = self:CreateSegmentedPills(r3SubChannel, CHAT_CHANNEL_OPTIONS,
        function() return self.db.chatChannel or "PARTY_INSTANCE" end,
        function(v)
            self.db.chatChannel = v
            self:RefreshAll()
        end, 260)
    pillsChatChannel:SetPoint("RIGHT", r3SubChannel, "RIGHT", -14, 0)
    r3SubChannel:BindControl(pillsChatChannel)

    -- Row 4: Show On-Screen Target Icon Bar (Direction A 3-Pill Segmented Control + Full-Width Horizontal Chevron Toggle Bar)
    local r4 = self:CreateSpaciousRow(p1Sec2, -54, 58,
        "Show On-Screen Target Icon Bar",
        "Control when the floating 8-icon Target Icon Bar is displayed on screen.")
    local pillsTargetVis = self:CreateSegmentedPills(r4, BAR_VISIBILITY_OPTIONS,
        function()
            local _, canon = self:NormalizeBarVisibility(self.db.targetBarVisibility)
            return canon
        end,
        function(v)
            local oldMode = self:NormalizeBarVisibility(self.db.targetBarVisibility)
            local newMode, canon = self:NormalizeBarVisibility(v)
            self.db.targetBarVisibility = canon
            if newMode ~= "off" and (oldMode == "off" or self.db.tuneTargetBarExpanded == nil) then
                self.db.tuneTargetBarExpanded = true
            end
            self:UpdateTargetBarVisibility()
            self:RefreshTargetBar()
            self:RefreshAll()
        end, 220)
    pillsTargetVis:SetPoint("TOPRIGHT", r4, "TOPRIGHT", -14, -16)
    r4:BindControl(pillsTargetVis)

    local tuneTargetBtn = self:AttachHorizontalChevronBar(r4, 4,
        function() return self:NormalizeBarVisibility(self.db.targetBarVisibility) ~= "off" end,
        function() return self.db.tuneTargetBarExpanded ~= false end,
        function()
            self.db.tuneTargetBarExpanded = not (self.db.tuneTargetBarExpanded ~= false)
            self:RefreshAll()
        end)

    -- Nested Sub-Setting Cards inside r4 (Collapsible Sub-Drawer Group per DESIGN_SYSTEM.md Section 2.6)
    local r4SubOrient = self:CreateSpaciousRow(r4, -82, 54,
        "Bar Orientation",
        "Arrange the Raid Target Bar horizontally or vertically on screen.", true)
    local pillsTargetOrient = self:CreateSegmentedPills(r4SubOrient, BAR_ORIENTATION_OPTIONS,
        function() return self.db.targetBarOrientation end,
        function(v)
            self.db.targetBarOrientation = v
            self:RefreshTargetBar()
            self:RefreshAll()
        end, 210)
    pillsTargetOrient:SetPoint("RIGHT", r4SubOrient, "RIGHT", -14, 0)
    r4SubOrient:BindControl(pillsTargetOrient)

    local r4SubBorder = self:CreateSpaciousRow(r4, -140, 54,
        "HUD Border Style",
        "Sync floating HUD bar borders to your active Suite Accent colour, Subtle Dark, or Borderless.", true)
    local pillsTargetBorder = self:CreateSegmentedPills(r4SubBorder, HUD_BORDER_STYLE_OPTIONS,
        function()
            local raw = self.db.targetBarBorderStyle or self.db.hudBorderStyle or "ACCENT"
            if raw == "SUBTLE" then raw = "DARK" end
            return raw
        end,
        function(v)
            self.db.targetBarBorderStyle = v
            self.db.hudBorderStyle = v
            self:RefreshTargetBar()
            self:RefreshFlareBar()
            self:RefreshAll()
        end, 276)
    pillsTargetBorder:SetPoint("RIGHT", r4SubBorder, "RIGHT", -14, 0)
    r4SubBorder:BindControl(pillsTargetBorder)

    local r5 = self:CreateSpaciousRow(r4, -198, 54,
        "Raid Target Bar Scale",
        "Adjust the size of the floating On-Screen Raid Target Bar (60% to 150%, independent of Opacity).", true)
    local slTargetScale = self:CreateSliderControl(r5, 0.60, 1.50, 0.05,
        function() return self.db.targetBarScale end,
        function(v)
            self.db.targetBarScale = v
            self:RefreshTargetBar()
        end)
    slTargetScale:SetPoint("RIGHT", r5, "RIGHT", -14, 0)
    r5:BindControl(slTargetScale)

    local r6 = self:CreateSpaciousRow(r4, -256, 54,
        "Raid Target Bar Opacity",
        "Adjust the transparency of the floating On-Screen Raid Target Bar (20% to 100%, independent of Scale).", true)
    local slTargetAlpha = self:CreateSliderControl(r6, 0.20, 1.00, 0.05,
        function() return self.db.targetBarOpacity end,
        function(v)
            self.db.targetBarOpacity = v
            self:RefreshTargetBar()
        end)
    slTargetAlpha:SetPoint("RIGHT", r6, "RIGHT", -14, 0)
    r6:BindControl(slTargetAlpha)

    table.insert(self.refreshables, function()
        local sel = self.db.focusIcon or 8
        local ar, ag, ab = self:GetAccentColor()
        for i, ib in ipairs(r1.iconBtns) do
            if i == sel then
                self:ApplyBackdrop(ib, { r = ar * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), g = ag * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), b = ab * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), a = 0.88 }, { r = ar, g = ag, b = ab, a = 0.95 })
                if ib.ActiveBar then
                    ib.ActiveBar:SetColorTexture(ar, ag, ab, 1.0)
                    ib.ActiveBar:Show()
                end
            else
                self:ApplyBackdrop(ib, COLORS.BgElevated, COLORS.BorderDim)
                if ib.ActiveBar then ib.ActiveBar:Hide() end
            end
        end

        pillsScope:RefreshValue()
        pillsChat:RefreshValue()
        pillsChatChannel:RefreshValue()
        pillsTargetVis:RefreshValue()
        pillsTargetOrient:RefreshValue()
        pillsTargetBorder:RefreshValue()
        slTargetScale:RefreshValue()
        slTargetAlpha:RefreshValue()

        local chatOn = (self.db.chatAnnounce ~= "MUTED")
        local showChatDrawer = chatOn and (self.db.tuneChatExpanded ~= false)
        tuneChatBtn:RefreshState(tuneChatBtn:IsMouseOver())
        r3:BindControl(pillsChat)
        r3SubChannel:SetShown(showChatDrawer)

        local r3H = 58
        if showChatDrawer then
            r3SubChannel:SetVerticalOffset(-82)
            r3H = 144
        elseif chatOn then
            r3H = 84
        end
        r3:SetHeight(r3H)
        local sec1H = 182 + r3H + 12
        p1Sec1:SetHeight(sec1H)
        if p1Hdr1 then p1Hdr1:RefreshAccent() end
        if p1Hdr2 then p1Hdr2:RefreshAccent() end
        r4:SetVerticalOffset(-54)

        local targetBarOn = (self.db.targetBarVisibility ~= "HIDDEN")
        local showTargetDrawer = targetBarOn and (self.db.tuneTargetBarExpanded ~= false)
        tuneTargetBtn:RefreshState(tuneTargetBtn:IsMouseOver())
        r4:BindControl(pillsTargetVis)

        local yCursor = -82
        local targetSubRows = { r4SubOrient, r4SubBorder, r5, r6 }
        for _, sr in ipairs(targetSubRows) do
            sr:SetShown(showTargetDrawer)
            if showTargetDrawer then
                sr:SetVerticalOffset(yCursor)
                yCursor = yCursor - 58
            end
            if sr.SubAccentBar then sr.SubAccentBar:SetColorTexture(ar, ag, ab, 0.85) end
            if sr.SubPip then sr.SubPip:SetColorTexture(ar, ag, ab, 0.95) end
        end
        if r3SubChannel.SubAccentBar then r3SubChannel.SubAccentBar:SetColorTexture(ar, ag, ab, 0.85) end
        if r3SubChannel.SubPip then r3SubChannel.SubPip:SetColorTexture(ar, ag, ab, 0.95) end

        local r4H = 58
        if showTargetDrawer then
            r4H = 318
        elseif targetBarOn then
            r4H = 84
        end
        r4:SetHeight(r4H)
        local sec2H = 54 + r4H + 12
        p1Sec2:SetHeight(sec2H)

        if ws.subTabPages[1] and ws.subTabPages[1].SetContentHeight then
            ws.subTabPages[1]:SetContentHeight(sec1H + 14 + sec2H + 14 + 72 + 12)
        end
    end)

    local p1Sec3 = self:CreateSectionBox(p1, nil, 72)
    p1Sec3:SetPoint("TOPLEFT", p1Sec2, "BOTTOMLEFT", 0, -14)
    p1Sec3:SetPoint("TOPRIGHT", p1Sec2, "BOTTOMRIGHT", 0, -14)

    local rImport = self:CreateSpaciousRow(p1Sec3, -7, 58,
        "FocusMarker Settings Migration",
        "Import keybinds, marker order, visibility, scale, and HUD position from FocusMarkerDB.")
    local importFMBtn = self:CreateButton(rImport, "Import from FocusMarker", 178, 28, function()
        if type(_G.FocusMarkerDB) ~= "table" then return end
        local okM, applied = self:MigrateFromFocusMarker(true)
        if okM then
            print("|cFF38BDF8DynamicMarker|r: Imported settings from FocusMarker.")
            self:RefreshAll()
        else
            print("|cFF38BDF8DynamicMarker|r: " .. tostring(applied or "FocusMarker import failed."))
        end
    end, true)
    importFMBtn:SetPoint("RIGHT", rImport, "RIGHT", -14, 0)
    rImport:BindControl(importFMBtn)

    table.insert(self.refreshables, function()
        local hasFM = (type(_G.FocusMarkerDB) == "table")
        if hasFM then
            importFMBtn:Enable()
            importFMBtn:SetAlpha(1.0)
        else
            importFMBtn:Disable()
            importFMBtn:SetAlpha(0.45)
        end
    end)

    -- ========================================================================
    -- SUB-TAB 2: World Flare Keys
    -- ========================================================================
    local p2 = ws.subTabPages[2].content
    local p2Sec1 = self:CreateSectionBox(p2, 0, 252)
    local p2Hdr1 = self:CreateSectionHeader(p2Sec1, -10, "WORLD FLARE SEQUENCE & HARDWARE KEYBINDS", "World Flare hotkeys start Unbound so they never overwrite existing F4/F5 bindings unless you assign them here or in Guided Setup.")

    local p2Sec2 = self:CreateSectionBox(p2, nil, 356)
    p2Sec2:SetPoint("TOPLEFT", p2Sec1, "BOTTOMLEFT", 0, -14)
    p2Sec2:SetPoint("TOPRIGHT", p2Sec1, "BOTTOMRIGHT", 0, -14)
    local p2Hdr2 = self:CreateSectionHeader(p2Sec2, -10, "ON-SCREEN WORLD FLARE BAR HUD", "Configure visibility, orientation, border style, scale, and opacity for the floating World Flare Bar.")
    local p2HudBtn = self:CreateEditHudButton(p2Hdr2, function()
        self:ToggleHudEditMode("FlareBar")
    end)
    if self.isEditMode and p2HudBtn.SetLabel then p2HudBtn:SetLabel("Lock HUD") end
    p2HudBtn:SetPoint("RIGHT", p2Hdr2, "RIGHT", 0, 2)
    if p2Hdr2.subtitle then
        p2Hdr2.subtitle:SetPoint("RIGHT", p2HudBtn, "LEFT", -10, 0)
    end
    table.insert(self.hudEditToggleButtons, p2HudBtn)

    -- Row 1: Cycle World Flare Keybind (Optional, Unbound by Default)
    local fRow1 = self:CreateSpaciousRow(p2Sec1, -118, 58,
        "Cycle World Flare Keybind",
        "Press repeatedly to place active ground flares at your cursor in sequence. Click to bind, Right-click to unbind.")
    local kbCycle = self:CreateKeybindButton(fRow1, 204,
        function() return self.db.flareCycleKey end,
        function(newKey)
            self.db.flareCycleKey = newKey
            self:ApplyFlareKeybinds()
            self:RefreshKeybindTelemetryAndTabTitle()
            self:RefreshAll()
        end, "")
    kbCycle:SetPoint("RIGHT", fRow1, "RIGHT", -14, 0)
    fRow1:BindControl(kbCycle)
    table.insert(self.refreshables, function() kbCycle:RefreshValue() end)

    -- Row 2: Clear All Flares Keybind (Optional, Unbound by Default)
    local fRow2 = self:CreateSpaciousRow(p2Sec1, -182, 58,
        "Clear All Flares Keybind",
        "Clear all active ground flares from the battlefield in one press. Click to bind, Right-click to unbind.")
    local kbClear = self:CreateKeybindButton(fRow2, 204,
        function() return self.db.flareClearKey end,
        function(newKey)
            self.db.flareClearKey = newKey
            self:ApplyFlareKeybinds()
            self:RefreshKeybindTelemetryAndTabTitle()
            self:RefreshAll()
        end, "")
    kbClear:SetPoint("RIGHT", fRow2, "RIGHT", -14, 0)
    fRow2:BindControl(kbClear)
    table.insert(self.refreshables, function() kbClear:RefreshValue() end)

    -- Row 3: World Flare Cycle Sequence (Right-Aligned 30x30 Square Icon Strip on a 58px Row)
    local fRow3 = self:CreateSpaciousRow(p2Sec1, -54, 58,
        "World Flare Cycle Sequence",
        "Left-Click to toggle flare on/off. Drag left/right (or Right-Click) to reorder sequence.")
    fRow3.SeqReadout = fRow3.Desc

    local flareBtnSize = 30
    local flareGap = 4
    local flareContainer = CreateFrame("Frame", nil, fRow3)
    flareContainer:SetSize((8 * flareBtnSize) + (7 * flareGap), flareBtnSize)
    flareContainer:SetPoint("RIGHT", fRow3, "RIGHT", -14, 0)
    local resetFlareSeqBtn = self:CreateButton(fRow3, "Reset", 58, 26, function()
        self.db.flareOrder = { 1, 2, 3, 4, 5, 6, 7, 8 }
        self.db.flareEnabled = {
            [1] = true, [2] = true, [3] = true, [4] = true,
            [5] = true, [6] = true, [7] = true, [8] = true,
        }
        self:SyncSecureFlareEngine()
        self:RefreshFlareBar()
        self:RefreshAll()
    end)
    resetFlareSeqBtn:SetPoint("RIGHT", flareContainer, "LEFT", -8, 0)
    fRow3:BindControl(flareContainer, resetFlareSeqBtn)

    local dragGhost = CreateFrame("Frame", "DynamicMarkerFlareDragGhost", UIParent, "BackdropTemplate")
    dragGhost:SetSize(flareBtnSize, flareBtnSize)
    dragGhost:SetScale(1.08)
    dragGhost:SetFrameStrata("TOOLTIP")
    dragGhost:SetFrameLevel(260)
    dragGhost:Hide()
    dragGhost.Icon = dragGhost:CreateTexture(nil, "ARTWORK")
    dragGhost.Icon:SetSize(20, 20)
    dragGhost.Icon:SetPoint("CENTER", dragGhost, "CENTER", 0, 0)
    dragGhost.Icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    dragGhost.NameText = dragGhost:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dragGhost.NameText:Hide()

    fRow3.cards = {}
    fRow3.currentCardW = flareBtnSize
    local draggedIndex = nil
    local isDraggingFlare = false
    local startCursorX = 0

    local function SwapFlareOrder(posA, posB)
        if posB < 1 then posB = 8 elseif posB > 8 then posB = 1 end
        local ord = self.db.flareOrder
        ord[posA], ord[posB] = ord[posB], ord[posA]
        self:SyncSecureFlareEngine()
        self:RefreshFlareBar()
        self:RefreshAll()
    end

    local function MoveFlareOrder(fromIdx, toIdx)
        if fromIdx == toIdx or fromIdx < 1 or fromIdx > 8 or toIdx < 1 or toIdx > 8 then return end
        local ord = self.db.flareOrder
        local item = table.remove(ord, fromIdx)
        if item then
            table.insert(ord, toIdx, item)
            self:SyncSecureFlareEngine()
            self:RefreshFlareBar()
            self:RefreshAll()
        end
    end

    for slotIdx = 1, 8 do
        local card = CreateFrame("Button", nil, flareContainer, "BackdropTemplate")
        card:SetSize(flareBtnSize, flareBtnSize)
        if slotIdx == 1 then
            card:SetPoint("LEFT", flareContainer, "LEFT", 0, 0)
        else
            card:SetPoint("LEFT", fRow3.cards[slotIdx - 1], "RIGHT", flareGap, 0)
        end
        card:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        card.Icon = card:CreateTexture(nil, "ARTWORK")
        card.Icon:SetSize(20, 20)
        card.Icon:SetPoint("CENTER", card, "CENTER", 0, 0)
        card.Icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        DisableTexturePixelSnap(card.Icon)

        card.NameText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        card.NameText:Hide()

        local colorBar = card:CreateTexture(nil, "OVERLAY")
        colorBar:SetHeight(2)
        colorBar:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 1, 1)
        colorBar:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -1, 1)
        card.ColorBar = colorBar

        card:SetScript("OnEnter", function(s)
            local fID = self.db.flareOrder[slotIdx] or slotIdx
            local fInfo = WORLD_FLARES[fID]
            local isOn = not not self.db.flareEnabled[fID]
            if fInfo then
                local _, _, _, accHex = self:GetAccentColor()
                accHex = accHex or "38BDF8"
                self:ApplyBackdrop(s, COLORS.BgHover, { r = fInfo.color.r, g = fInfo.color.g, b = fInfo.color.b, a = 1.0 })
                GameTooltip:SetOwner(s, "ANCHOR_TOP")
                GameTooltip:SetText(string.format("#%d: %s World Flare (%s)", slotIdx, fInfo.short, isOn and "|cFF22C55EActive|r" or "|cFF94A3B8Disabled|r"), 1, 1, 1)
                GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Toggle On/Off in Cycle Sequence|r", 1, 1, 1)
                GameTooltip:AddLine("|cFF" .. accHex .. "Drag Left/Right:|r |cFFE2E8F0Reorder Flare Position|r", 1, 1, 1)
                GameTooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Nudge Left|r  (|cFF" .. accHex .. "Shift+Right-Click:|r |cFFE2E8F0Nudge Right|r)", 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        card:SetScript("OnLeave", function()
            GameTooltip:Hide()
            self:RefreshAll()
        end)

        card:SetScript("OnMouseDown", function(_, mBtn)
            if mBtn ~= "LeftButton" then return end
            local scale = flareContainer:GetEffectiveScale() or 1
            startCursorX = (select(1, GetCursorPosition())) / scale
            draggedIndex = slotIdx
            isDraggingFlare = false

            flareContainer:SetScript("OnUpdate", function(contFrame)
                if not IsMouseButtonDown("LeftButton") then
                    contFrame:SetScript("OnUpdate", nil)
                    dragGhost:Hide()
                    if isDraggingFlare then
                        isDraggingFlare = false
                        draggedIndex = nil
                        self:RefreshAll()
                    else
                        draggedIndex = nil
                    end
                    return
                end
                local curScale = contFrame:GetEffectiveScale() or 1
                local rawX, rawY = GetCursorPosition()
                local cursorX = rawX / curScale
                if not isDraggingFlare and math.abs(cursorX - startCursorX) > 4 then
                    isDraggingFlare = true
                    local fID = self.db.flareOrder[draggedIndex] or draggedIndex
                    local fInfo = WORLD_FLARES[fID]
                    local rInfo = RAID_ICONS[fInfo.raidIcon]
                    local ar, ag, ab = self:GetAccentColor()
                    self:ApplyBackdrop(dragGhost, { r = ar * 0.26, g = ag * 0.26, b = ab * 0.26, a = 1 }, { r = ar, g = ag, b = ab, a = 1.0 }, 2)
                    dragGhost.Icon:SetTexCoord(unpack(rInfo.coords))
                    dragGhost:Show()
                    self:RefreshAll()
                end
                if isDraggingFlare and draggedIndex then
                    local gScale = dragGhost:GetEffectiveScale() or 1
                    dragGhost:ClearAllPoints()
                    dragGhost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", rawX / gScale, (rawY / gScale) + 6)

                    local cLeft = contFrame:GetLeft() or 0
                    local step = flareBtnSize + flareGap
                    local targetIdx = math.floor((cursorX - cLeft) / step) + 1
                    targetIdx = math.max(1, math.min(8, targetIdx))
                    if targetIdx ~= draggedIndex then
                        MoveFlareOrder(draggedIndex, targetIdx)
                        draggedIndex = targetIdx
                    end
                end
            end)
        end)

        card:SetScript("OnMouseUp", function(_, mBtn)
            if mBtn == "RightButton" then
                SwapFlareOrder(slotIdx, IsShiftKeyDown() and (slotIdx + 1) or (slotIdx - 1))
                return
            end
            if mBtn ~= "LeftButton" then return end
            flareContainer:SetScript("OnUpdate", nil)
            dragGhost:Hide()
            local wasDragging = isDraggingFlare
            isDraggingFlare = false
            draggedIndex = nil
            if not wasDragging then
                local flareID = self.db.flareOrder[slotIdx]
                self.db.flareEnabled[flareID] = not self.db.flareEnabled[flareID]
                self:SyncSecureFlareEngine()
                self:RefreshFlareBar()
            end
            self:RefreshAll()
        end)

        fRow3.cards[slotIdx] = card
    end

    -- Row 4: Show On-Screen World Flare Bar (Direction A 3-Pill Segmented Control + Full-Width Horizontal Chevron Toggle Bar)
    local fRow4 = self:CreateSpaciousRow(p2Sec2, -54, 58,
        "Show On-Screen World Flare Bar",
        "Control when the floating 8-flare World Marker Bar is displayed on screen.")
    local pillsFlareVis = self:CreateSegmentedPills(fRow4, BAR_VISIBILITY_OPTIONS,
        function()
            local _, canon = self:NormalizeBarVisibility(self.db.flareBarVisibility)
            return canon
        end,
        function(v)
            local oldMode = self:NormalizeBarVisibility(self.db.flareBarVisibility)
            local newMode, canon = self:NormalizeBarVisibility(v)
            self.db.flareBarVisibility = canon
            if newMode ~= "off" and (oldMode == "off" or self.db.tuneFlareBarExpanded == nil) then
                self.db.tuneFlareBarExpanded = true
            end
            self:UpdateFlareBarVisibility()
            self:RefreshFlareBar()
            self:RefreshAll()
        end, 220)
    pillsFlareVis:SetPoint("TOPRIGHT", fRow4, "TOPRIGHT", -14, -16)
    fRow4:BindControl(pillsFlareVis)

    local tuneFlareBtn = self:AttachHorizontalChevronBar(fRow4, 4,
        function() return self:NormalizeBarVisibility(self.db.flareBarVisibility) ~= "off" end,
        function() return self.db.tuneFlareBarExpanded ~= false end,
        function()
            self.db.tuneFlareBarExpanded = not (self.db.tuneFlareBarExpanded ~= false)
            self:RefreshAll()
        end)

    -- Nested Sub-Setting Cards inside fRow4 (Collapsible Sub-Drawer Group per DESIGN_SYSTEM.md Section 2.6)
    local fRow4SubOrient = self:CreateSpaciousRow(fRow4, -82, 54,
        "Bar Orientation",
        "Arrange the World Flare Bar horizontally or vertically on screen.", true)
    local pillsFlareOrient = self:CreateSegmentedPills(fRow4SubOrient, BAR_ORIENTATION_OPTIONS,
        function() return self.db.flareBarOrientation end,
        function(v)
            self.db.flareBarOrientation = v
            self:RefreshFlareBar()
            self:RefreshAll()
        end, 210)
    pillsFlareOrient:SetPoint("RIGHT", fRow4SubOrient, "RIGHT", -14, 0)
    fRow4SubOrient:BindControl(pillsFlareOrient)

    local fRow4SubBorder = self:CreateSpaciousRow(fRow4, -140, 54,
        "HUD Border Style",
        "Sync floating HUD bar borders to your active Suite Accent colour, Subtle Dark, or Borderless.", true)
    local pillsFlareBorder = self:CreateSegmentedPills(fRow4SubBorder, HUD_BORDER_STYLE_OPTIONS,
        function()
            local raw = self.db.flareBarBorderStyle or self.db.hudBorderStyle or "ACCENT"
            if raw == "SUBTLE" then raw = "DARK" end
            return raw
        end,
        function(v)
            self.db.flareBarBorderStyle = v
            self.db.hudBorderStyle = v
            self:RefreshTargetBar()
            self:RefreshFlareBar()
            self:RefreshAll()
        end, 276)
    pillsFlareBorder:SetPoint("RIGHT", fRow4SubBorder, "RIGHT", -14, 0)
    fRow4SubBorder:BindControl(pillsFlareBorder)

    local fRow5 = self:CreateSpaciousRow(fRow4, -198, 54,
        "World Flare Bar Scale",
        "Adjust the size of the floating On-Screen World Flare Bar (60% to 150%, independent of Opacity).", true)
    local slFlareScale = self:CreateSliderControl(fRow5, 0.60, 1.50, 0.05,
        function() return self.db.flareBarScale end,
        function(v)
            self.db.flareBarScale = v
            self:RefreshFlareBar()
        end)
    slFlareScale:SetPoint("RIGHT", fRow5, "RIGHT", -14, 0)
    fRow5:BindControl(slFlareScale)

    local fRow6 = self:CreateSpaciousRow(fRow4, -256, 54,
        "World Flare Bar Opacity",
        "Adjust the transparency of the floating On-Screen World Flare Bar (20% to 100%, independent of Scale).", true)
    local slFlareAlpha = self:CreateSliderControl(fRow6, 0.20, 1.00, 0.05,
        function() return self.db.flareBarOpacity end,
        function(v)
            self.db.flareBarOpacity = v
            self:RefreshFlareBar()
        end)
    slFlareAlpha:SetPoint("RIGHT", fRow6, "RIGHT", -14, 0)
    fRow6:BindControl(slFlareAlpha)

    table.insert(self.refreshables, function()
        fRow3.SeqReadout:SetText("Left-Click to toggle flare on/off. Drag left/right (or Right-Click) to reorder sequence.")
        local ar, ag, ab = self:GetAccentColor()
        for slotIdx = 1, 8 do
            local card = fRow3.cards[slotIdx]
            local flareID = self.db.flareOrder[slotIdx] or slotIdx
            local fInfo = WORLD_FLARES[flareID]
            local rInfo = RAID_ICONS[fInfo.raidIcon]
            local isOn = not not self.db.flareEnabled[flareID]
            local isBeingDragged = (isDraggingFlare and draggedIndex == slotIdx)

            card.Icon:SetTexCoord(unpack(rInfo.coords))
            card.NameText:SetText(fInfo.name)

            if isOn then
                self:ApplyBackdrop(card,
                    isBeingDragged and COLORS.BgVoid or { r = ar * 0.22, g = ag * 0.22, b = ab * 0.22, a = 0.88 },
                    { r = ar, g = ag, b = ab, a = 0.95 })
                card.Icon:SetAlpha(1.0)
                card:SetAlpha(isBeingDragged and 0.35 or 1.0)
                if card.ColorBar then
                    card.ColorBar:SetColorTexture(fInfo.color.r, fInfo.color.g, fInfo.color.b, 0.98)
                    card.ColorBar:Show()
                end
            else
                self:ApplyBackdrop(card,
                    COLORS.BgVoid,
                    isBeingDragged and { r = ar, g = ag, b = ab, a = 0.85 } or COLORS.BorderDim)
                card.Icon:SetAlpha(0.32)
                card:SetAlpha(isBeingDragged and 0.35 or 1.0)
                if card.ColorBar then card.ColorBar:Hide() end
            end
        end

        pillsFlareVis:RefreshValue()
        pillsFlareOrient:RefreshValue()
        pillsFlareBorder:RefreshValue()
        slFlareScale:RefreshValue()
        slFlareAlpha:RefreshValue()

        local flareBarOn = (self.db.flareBarVisibility ~= "HIDDEN")
        local showFlareDrawer = flareBarOn and (self.db.tuneFlareBarExpanded ~= false)
        tuneFlareBtn:RefreshState(tuneFlareBtn:IsMouseOver())
        fRow4:BindControl(pillsFlareVis)

        if p2Hdr1 then p2Hdr1:RefreshAccent() end
        if p2Hdr2 then p2Hdr2:RefreshAccent() end
        local fY = -82
        for _, sr in ipairs({ fRow4SubOrient, fRow4SubBorder, fRow5, fRow6 }) do
            sr:SetShown(showFlareDrawer)
            if showFlareDrawer then
                sr:SetVerticalOffset(fY)
                fY = fY - 58
            end
            if sr.SubAccentBar then sr.SubAccentBar:SetColorTexture(ar, ag, ab, 0.85) end
            if sr.SubPip then sr.SubPip:SetColorTexture(ar, ag, ab, 0.95) end
        end

        local fRow4H = 58
        if showFlareDrawer then
            fRow4H = 318
        elseif flareBarOn then
            fRow4H = 84
        end
        fRow4:SetHeight(fRow4H)
        local sec2H = 54 + fRow4H + 12
        p2Sec2:SetHeight(sec2H)

        if ws.subTabPages[2] and ws.subTabPages[2].SetContentHeight then
            ws.subTabPages[2]:SetContentHeight(252 + 14 + sec2H + 12)
        end
    end)

    -- ========================================================================
    -- SUB-TAB 3: Macro Setup ([DynamicMark] + [DynamicKick])
    -- ========================================================================
    local p3 = ws.subTabPages[3].content
    if ws.subTabPages[3].SetContentHeight then
        ws.subTabPages[3]:SetContentHeight(752)
    end

    -- Section 1: [DynamicMark] (General Macro - All Characters)
    local p3Sec1 = self:CreateSectionBox(p3, 0, 338)
    if p3Sec1.SetClipsChildren then p3Sec1:SetClipsChildren(true) end
    local p3Hdr1 = self:CreateSectionHeader(p3Sec1, -10, "[DYNAMICMARK] - FOCUS & RAID TARGET MARKER (GENERAL MACRO)", "One-button modifier-free macro that sets focus and applies your preferred raid target icon.")

    local focusStatusPill = CreateFrame("Frame", nil, p3Hdr1, "BackdropTemplate")
    focusStatusPill:SetSize(176, 18)
    focusStatusPill:SetPoint("TOPRIGHT", p3Hdr1, "TOPRIGHT", -4, -1)
    focusStatusPill.Text = focusStatusPill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    focusStatusPill.Text:SetPoint("RIGHT", focusStatusPill, "RIGHT", 0, 0)
    self:StyleFont(focusStatusPill.Text, 11, "", COLORS.TextMuted)
    p3Hdr1.title:SetPoint("RIGHT", focusStatusPill, "LEFT", -12, 0)
    p3Hdr1.title:SetJustifyH("LEFT")
    p3Hdr1.title:SetWordWrap(false)

    local mRowMod = self:CreateSpaciousRow(p3Sec1, -54, 58,
        "Clear Focus Modifier",
        "Defaults to 'None' so keybinds with pre-existing modifiers (Shift+F, Alt+4) never collide.")

    local pillsClearMod = self:CreateSegmentedPills(mRowMod, CLEAR_MODIFIER_OPTIONS,
        function() return self.db.focusClearModifier end,
        function(v)
            self.db.focusClearModifier = v
            self:CreateOrUpdateFocusMarkerMacro("SETTING")
            self:RefreshAll()
        end, 250)
    pillsClearMod:SetPoint("RIGHT", mRowMod, "RIGHT", -14, 0)
    mRowMod:BindControl(pillsClearMod)

    local mRowTargetMode = self:CreateSpaciousRow(p3Sec1, -118, 58,
        "Focus Target Mode",
        "Choose whether [DynamicMark] checks mouseover first, uses your current target only, or keeps custom macro lines.")

    local pillsTargetMode = self:CreateSegmentedPills(mRowTargetMode, FOCUS_TARGET_MODE_OPTIONS,
        function() return self.db.focusTargetMode or "MOUSEOVER_TARGET" end,
        function(v)
            self.db.focusTargetMode = v
            self:CreateOrUpdateFocusMarkerMacro("SETTING")
            self:RefreshAll()
        end, 340)
    pillsTargetMode:SetPoint("RIGHT", mRowTargetMode, "RIGHT", -14, 0)
    mRowTargetMode:BindControl(pillsTargetMode)

    local mPreviewCard1 = CreateFrame("Frame", nil, p3Sec1, "BackdropTemplate")
    mPreviewCard1:SetHeight(144)
    mPreviewCard1:SetPoint("TOPLEFT", p3Sec1, "TOPLEFT", 14, -182)
    mPreviewCard1:SetPoint("TOPRIGHT", p3Sec1, "TOPRIGHT", -14, -182)
    if mPreviewCard1.SetClipsChildren then mPreviewCard1:SetClipsChildren(true) end
    self:ApplyBackdrop(mPreviewCard1, COLORS.BgSurface, COLORS.BorderDim)

    local mPreview1 = CreateFrame("Frame", nil, mPreviewCard1, "BackdropTemplate")
    mPreview1:SetHeight(80)
    mPreview1:SetPoint("TOPLEFT", mPreviewCard1, "TOPLEFT", 12, -10)
    mPreview1:SetPoint("TOPRIGHT", mPreviewCard1, "TOPRIGHT", -12, -10)
    if mPreview1.SetClipsChildren then mPreview1:SetClipsChildren(true) end
    self:ApplyBackdrop(mPreview1, COLORS.BgVoid, COLORS.BorderDim)

    mPreview1.Code = mPreview1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mPreview1.Code:SetPoint("TOPLEFT", mPreview1, "TOPLEFT", 12, -8)
    mPreview1.Code:SetPoint("BOTTOMRIGHT", mPreview1, "BOTTOMRIGHT", -12, 8)
    mPreview1.Code:SetJustifyH("LEFT")
    mPreview1.Code:SetJustifyV("TOP")
    mPreview1.Code:SetWordWrap(true)
    mPreview1.Code:SetSpacing(2)
    self:StyleFont(mPreview1.Code, 11, "", COLORS.TextSilver)

    local editBox = CreateFrame("EditBox", nil, mPreview1)
    editBox:SetPoint("TOPLEFT", mPreview1, "TOPLEFT", 12, -8)
    editBox:SetPoint("BOTTOMRIGHT", mPreview1, "BOTTOMRIGHT", -12, 18)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(255)
    editBox:SetJustifyH("LEFT")
    if editBox.SetJustifyV then editBox:SetJustifyV("TOP") end
    self:StyleFont(editBox, 11, "", COLORS.TextSilver)
    editBox:SetScript("OnEscapePressed", function(eb) eb:ClearFocus() end)
    editBox:SetScript("OnTextChanged", function(eb, userInput)
        local txt = eb:GetText() or ""
        if mPreview1.CharCount then
            mPreview1.CharCount:SetText(string.format("%d / 255", #txt))
        end
        if userInput then
            mPreview1._dirtyManualEdit = true
        end
    end)
    editBox:Hide()
    mPreview1.EditBox = editBox

    local charCount = mPreview1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    charCount:SetPoint("BOTTOMRIGHT", mPreview1, "BOTTOMRIGHT", -10, 4)
    self:StyleFont(charCount, 10, "", COLORS.TextMuted)
    charCount:SetText("0 / 255")
    charCount:Hide()
    mPreview1.CharCount = charCount

    mPreview1:EnableMouse(true)
    mPreview1:SetScript("OnMouseDown", function()
        if mPreview1.EditBox and mPreview1.EditBox:IsShown() then
            mPreview1.EditBox:SetFocus()
        end
    end)

    local btnStep2Focus = self:CreateButton(mPreviewCard1, "Step 2: Drag to Action Bar", 176, 26, function()
        if InCombatLockdown() then return end
        local idx = self:FindFocusMacroIndex()
        if not idx then
            self:CreateOrUpdateFocusMarkerMacro(true)
            idx = self:FindFocusMacroIndex()
        end
        if idx and idx > 0 then PickupMacro(idx) end
    end)
    btnStep2Focus:RegisterForDrag("LeftButton")
    btnStep2Focus:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        local idx = self:FindFocusMacroIndex()
        if not idx then
            self:CreateOrUpdateFocusMarkerMacro(true)
            idx = self:FindFocusMacroIndex()
        end
        if idx and idx > 0 then PickupMacro(idx) end
    end)
    btnStep2Focus:SetPoint("BOTTOMRIGHT", mPreviewCard1, "BOTTOMRIGHT", -12, 10)

    local btnStep1Focus = self:CreateButton(mPreviewCard1, "Step 1: Create / Update [DynamicMark]", 236, 26, function()
        local mode = (self.db and self.db.focusTargetMode) or "MOUSEOVER_TARGET"
        if mode == "MANUAL" and mPreview1.EditBox then
            mPreview1._dirtyManualEdit = false
            mPreview1.EditBox:ClearFocus()
            self:CreateOrUpdateFocusMarkerMacro("USER", mPreview1.EditBox:GetText() or "")
        else
            self:CreateOrUpdateFocusMarkerMacro(true)
        end
        self:RefreshAll()
    end, true)
    btnStep1Focus:SetPoint("RIGHT", btnStep2Focus, "LEFT", -8, 0)

    local focusMacroNote = mPreviewCard1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    focusMacroNote:SetPoint("LEFT", mPreviewCard1, "BOTTOMLEFT", 14, 27)
    focusMacroNote:SetPoint("RIGHT", btnStep1Focus, "LEFT", -10, 0)
    focusMacroNote:SetJustifyH("LEFT")
    focusMacroNote:SetWordWrap(true)
    self:StyleFont(focusMacroNote, 10, "", COLORS.TextMuted)
    focusMacroNote:SetText("Note: /tm needs Raid Lead or Assistant in raids. Third-party addons that hook chat or slash commands (such as DecorVendor) can block /tm; if Blizzard locks out SetRaidTarget(), disable the addon and completely restart the game (/reload alone will not clear it).")

    -- Section 2: [DynamicKick] (Character Macro - Per-Character)
    local p3Sec2 = self:CreateSectionBox(p3, nil, 388)
    if p3Sec2.SetClipsChildren then p3Sec2:SetClipsChildren(true) end
    p3Sec2:SetPoint("TOPLEFT", p3Sec1, "BOTTOMLEFT", 0, -14)
    p3Sec2:SetPoint("TOPRIGHT", p3Sec1, "BOTTOMRIGHT", 0, -14)
    local p3Hdr2 = self:CreateSectionHeader(p3Sec2, -10, "[DYNAMICKICK] - MULTI-SPEC INTERRUPT", "Smart character macro that automatically updates to your active specialisation's interrupt spell.")

    local kickStatusPill = CreateFrame("Frame", nil, p3Hdr2, "BackdropTemplate")
    kickStatusPill:SetSize(176, 18)
    kickStatusPill:SetPoint("TOPRIGHT", p3Hdr2, "TOPRIGHT", -4, -1)
    kickStatusPill.Text = kickStatusPill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    kickStatusPill.Text:SetPoint("RIGHT", kickStatusPill, "RIGHT", 0, 0)
    self:StyleFont(kickStatusPill.Text, 11, "", COLORS.TextMuted)
    p3Hdr2.title:SetPoint("RIGHT", kickStatusPill, "LEFT", -12, 0)
    p3Hdr2.title:SetJustifyH("LEFT")
    p3Hdr2.title:SetWordWrap(false)

    local mRowPrio = self:CreateSpaciousRow(p3Sec2, -54, 58,
        "Interrupt Target Priority",
        "Choose target evaluation order when pressing your interrupt macro.")

    local ddKickPrio = self:CreateDropdown(mRowPrio, 360, KICK_PRIORITY_OPTIONS,
        function() return self.db.kickPriority end,
        function(v)
            self.db.kickPriority = v
            self:CreateOrUpdateDynamicKickMacro(false)
            self:RefreshAll()
        end)
    ddKickPrio:SetPoint("RIGHT", mRowPrio, "RIGHT", -14, 0)
    mRowPrio:BindControl(ddKickPrio)

    local mRowSpec = self:CreateSpaciousRow(p3Sec2, -118, 58,
        "Multi-Spec & Alt Handling",
        "Auto-swaps interrupt spell on specialisation change out of combat (Druid Skull Bash <-> Solar Beam, Hunter Counter Shot <-> Muzzle).")

    local pillsKickSpec = self:CreateSegmentedPills(mRowSpec, KICK_SPEC_MODE_OPTIONS,
        function() return self.db.kickSpecMode end,
        function(v)
            self.db.kickSpecMode = v
            self:CreateOrUpdateDynamicKickMacro(false)
            self:RefreshAll()
        end, 250)
    pillsKickSpec:SetPoint("RIGHT", mRowSpec, "RIGHT", -14, 0)
    mRowSpec:BindControl(pillsKickSpec)

    local mPreviewCard2 = CreateFrame("Frame", nil, p3Sec2, "BackdropTemplate")
    mPreviewCard2:SetHeight(194)
    mPreviewCard2:SetPoint("TOPLEFT", p3Sec2, "TOPLEFT", 14, -182)
    mPreviewCard2:SetPoint("TOPRIGHT", p3Sec2, "TOPRIGHT", -14, -182)
    if mPreviewCard2.SetClipsChildren then mPreviewCard2:SetClipsChildren(true) end
    self:ApplyBackdrop(mPreviewCard2, COLORS.BgSurface, COLORS.BorderDim)

    local mPreview2 = CreateFrame("Frame", nil, mPreviewCard2, "BackdropTemplate")
    mPreview2:SetHeight(140)
    mPreview2:SetPoint("TOPLEFT", mPreviewCard2, "TOPLEFT", 12, -10)
    mPreview2:SetPoint("TOPRIGHT", mPreviewCard2, "TOPRIGHT", -12, -10)
    if mPreview2.SetClipsChildren then mPreview2:SetClipsChildren(true) end
    self:ApplyBackdrop(mPreview2, COLORS.BgVoid, COLORS.BorderDim)

    mPreview2.Code = mPreview2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mPreview2.Code:SetPoint("TOPLEFT", mPreview2, "TOPLEFT", 12, -8)
    mPreview2.Code:SetPoint("BOTTOMRIGHT", mPreview2, "BOTTOMRIGHT", -12, 8)
    mPreview2.Code:SetJustifyH("LEFT")
    mPreview2.Code:SetJustifyV("TOP")
    mPreview2.Code:SetWordWrap(true)
    mPreview2.Code:SetSpacing(2)
    self:StyleFont(mPreview2.Code, 11, "", COLORS.TextSilver)

    local btnStep2Kick = self:CreateButton(mPreviewCard2, "Step 2: Drag to Action Bar", 176, 26, function()
        if InCombatLockdown() then return end
        self:CreateOrUpdateDynamicKickMacro(true)
        local idx = self:FindActiveKickMacroIndex()
        if idx and idx > 0 then PickupMacro(idx) end
    end)
    btnStep2Kick:RegisterForDrag("LeftButton")
    btnStep2Kick:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        self:CreateOrUpdateDynamicKickMacro(true)
        local idx = self:FindActiveKickMacroIndex()
        if idx and idx > 0 then PickupMacro(idx) end
    end)
    btnStep2Kick:SetPoint("BOTTOMRIGHT", mPreviewCard2, "BOTTOMRIGHT", -12, 10)

    local btnStep1Kick = self:CreateButton(mPreviewCard2, "Step 1: Create / Update [DynamicKick]", 236, 26, function()
        self:CreateOrUpdateDynamicKickMacro(true)
        self:RefreshAll()
    end, true)
    btnStep1Kick:SetPoint("RIGHT", btnStep2Kick, "LEFT", -8, 0)

    local function UpdateMacroStatusPill(pill, macroName, isFocusMacro, step1Btn, step2Btn)
        local onBar = self:IsMacroOnActionBar(macroName)
        local mIdx = isFocusMacro and self:FindFocusMacroIndex() or self:FindActiveKickMacroIndex()
        local exists = (mIdx and mIdx > 0)
        self:ApplyBackdrop(pill, { r = 0, g = 0, b = 0, a = 0 }, { r = 0, g = 0, b = 0, a = 0 }, 1)
        pill.Text:ClearAllPoints()
        pill.Text:SetPoint("RIGHT", pill, "RIGHT", 0, 0)
        pill.Text:SetJustifyH("RIGHT")
        if onBar then
            pill.Text:SetText("|cFF94A3B8Status:|r |cFF22C55E" .. READY_CHECK_TEX .. " On Action Bar|r")
        elseif exists then
            pill.Text:SetText("|cFF94A3B8Status:|r |cFFF59E0BCreated (Not on Bar)|r")
        else
            pill.Text:SetText("|cFF94A3B8Status:|r |cFF64748BNot Created|r")
        end
        if step1Btn then
            step1Btn.isAccent = not exists
            if step1Btn.RefreshStyle then step1Btn.RefreshStyle(false) end
        end
        if step2Btn then
            step2Btn.isAccent = exists and not onBar
            if step2Btn.RefreshStyle then step2Btn.RefreshStyle(false) end
        end
    end

    table.insert(self.refreshables, function()
        pillsClearMod:RefreshValue()
        pillsTargetMode:RefreshValue()
        ddKickPrio:RefreshValue()
        pillsKickSpec:RefreshValue()

        local isManual = ((self.db and self.db.focusTargetMode) == "MANUAL")
        local previewText = self:BuildFocusMarkerMacroBody()
        if isManual then
            local idx = self:FindFocusMacroIndex()
            if idx and idx > 0 then
                local _, _, liveBody = GetMacroInfo(idx)
                if type(liveBody) == "string" and liveBody ~= "" then
                    previewText = liveBody
                end
            end
            mPreview1.Code:Hide()
            if mPreview1.EditBox then
                mPreview1.EditBox:Show()
                if not (mPreview1.EditBox:HasFocus() and mPreview1._dirtyManualEdit) then
                    mPreview1.EditBox:SetText(previewText)
                    mPreview1._dirtyManualEdit = false
                end
                if mPreview1.CharCount then
                    mPreview1.CharCount:Show()
                    mPreview1.CharCount:SetText(string.format("%d / 255", #(mPreview1.EditBox:GetText() or "")))
                end
            end
        else
            mPreview1._dirtyManualEdit = false
            if mPreview1.EditBox then
                mPreview1.EditBox:ClearFocus()
                mPreview1.EditBox:Hide()
            end
            if mPreview1.CharCount then
                mPreview1.CharCount:Hide()
            end
            mPreview1.Code:Show()
            mPreview1.Code:SetText(previewText)
        end

        local sp, _, hasActiveKick, specName, offSpecDisplay = self:ResolveActiveInterruptSpell()
        local ar, ag, ab, accHex = self:GetAccentColor()
        accHex = accHex or "CBD5E1"
        if p3Hdr1 then p3Hdr1:RefreshAccent() end
        if p3Hdr2 then
            p3Hdr2:RefreshAccent()
            if hasActiveKick == false then
                local offLabel = (offSpecDisplay and offSpecDisplay:find("/")) and "Off-Specs" or "Off-Spec"
                p3Hdr2.title:SetText(string.format("[DYNAMICKICK] - |cFFF59E0BNO KICK IN %s|r (%s: |cFF%s%s|r)", string.upper(specName or "Healer"), string.upper(offLabel), accHex, string.upper(offSpecDisplay or sp)))
            else
                p3Hdr2.title:SetText(string.format("[DYNAMICKICK] - MULTI-SPEC INTERRUPT (ACTIVE: |cFF%s%s|r)", accHex, string.upper(sp)))
            end
        end
        mPreview2.Code:SetText(self:BuildDynamicKickMacroBody(sp))

        UpdateMacroStatusPill(focusStatusPill, FOCUS_MACRO_NAME, true, btnStep1Focus, btnStep2Focus)
        UpdateMacroStatusPill(kickStatusPill, KICK_MACRO_NAME, false, btnStep1Kick, btnStep2Kick)
    end)

    SelectSubTab(self.db.activeSubTab or 1)
    self:RefreshAll()
    return ws
end

-- ============================================================================
-- 15. SUITE STUDIO & TOOLS MODALS (THEME, GUIDED SETUP, CHANGELOG, SUPPORT)
-- ============================================================================

function DM:CloseStudioModal()
    self:CloseDropdownMenu()
    if self.modalFrame then
        if not (InCombatLockdown and InCombatLockdown()) and self.modalFrame.EnableKeyboard then
            pcall(self.modalFrame.EnableKeyboard, self.modalFrame, false)
        end
        if self.modalFrame:IsShown() then
            self.modalFrame:Hide()
        end
    end
    if self.modalBackdrop and self.modalBackdrop:IsShown() then
        self.modalBackdrop:Hide()
    end
end

function DM:ShowStudioModal(mode)
    self:CloseDropdownMenu()
    local anchorTarget = (self.shellFrame and self.shellFrame:IsShown() and self.shellFrame) or UIParent
    local surf, surfKey = GetStandaloneSurfaceColors(self)
    local solidPanel = { r = surf.panel.r, g = surf.panel.g, b = surf.panel.b, a = 1.00 }

    if not self.modalBackdrop then
        local bd = CreateFrame("Button", "DynamicMarkerStudioBackdrop", UIParent)
        bd:SetFrameStrata("FULLSCREEN_DIALOG")
        bd:SetFrameLevel(290)
        bd:EnableMouse(true)
        local bdTex = bd:CreateTexture(nil, "BACKGROUND")
        bdTex:SetAllPoints()
        bdTex:SetColorTexture(0.01, 0.015, 0.025, 0.82)
        bd.Bg = bdTex
        bd:SetScript("OnClick", function()
            self:CloseStudioModal()
        end)
        bd:Hide()
        self.modalBackdrop = bd
    end
    local bd = self.modalBackdrop
    bd:SetParent(UIParent)
    bd:ClearAllPoints()
    if anchorTarget == self.shellFrame then
        bd:SetPoint("TOPLEFT", self.shellFrame, "TOPLEFT", 1, -1)
        bd:SetPoint("BOTTOMRIGHT", self.shellFrame, "BOTTOMRIGHT", -1, 1)
    else
        bd:SetAllPoints(UIParent)
    end
    bd:SetFrameStrata("FULLSCREEN_DIALOG")
    bd:SetFrameLevel(290)
    bd:Show()

    if not self.modalFrame then
        local m = CreateFrame("Frame", "DynamicMarkerStudioModal", UIParent, "BackdropTemplate")
        m:SetSize(560, 368)
        m:SetPoint("CENTER", anchorTarget, "CENTER", 0, 0)
        m:SetFrameStrata("FULLSCREEN_DIALOG")
        m:SetFrameLevel(300)
        m:SetToplevel(true)
        m:SetClampedToScreen(true)
        m:EnableMouse(true)
        if m.SetClipsChildren then m:SetClipsChildren(true) end

        local solidBg = m:CreateTexture(nil, "BACKGROUND", nil, -8)
        solidBg:SetAllPoints()
        solidBg:SetColorTexture(solidPanel.r, solidPanel.g, solidPanel.b, 1.00)
        m.SolidBg = solidBg

        self:ApplyBackdrop(m, solidPanel, self:GetAccentColorTable(0.95), 1)

        m.Title = m:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        m.Title:SetPoint("TOPLEFT", m, "TOPLEFT", 16, -14)
        self:StyleFont(m.Title, 14, "", COLORS.TextPrimary)

        m.CloseBtn = self:CreateButton(m, "X", 26, 24, function() self:CloseStudioModal() end)
        m.CloseBtn:SetPoint("TOPRIGHT", m, "TOPRIGHT", -12, -10)
        m.CloseBtn:SetFrameLevel(305)

        m.Body = CreateFrame("Frame", nil, m)
        m.Body:SetPoint("TOPLEFT", m, "TOPLEFT", 16, -46)
        m.Body:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -16, 16)
        m.Body:SetFrameLevel(302)
        m.Body._modeWidgets = {}
        if m.Body.SetClipsChildren then m.Body:SetClipsChildren(true) end

        m:SetScript("OnKeyDown", function(s, key)
            if key == "ESCAPE" then
                if not (InCombatLockdown and InCombatLockdown()) and s.SetPropagateKeyboardInput then
                    pcall(s.SetPropagateKeyboardInput, s, false)
                end
                self:CloseStudioModal()
            elseif not (InCombatLockdown and InCombatLockdown()) and s.SetPropagateKeyboardInput then
                pcall(s.SetPropagateKeyboardInput, s, true)
            end
        end)
        m:SetScript("OnHide", function()
            if not (InCombatLockdown and InCombatLockdown()) and m.EnableKeyboard then
                pcall(m.EnableKeyboard, m, false)
            end
            if self.modalBackdrop and self.modalBackdrop:IsShown() then
                self.modalBackdrop:Hide()
            end
        end)

        self.modalFrame = m
    end

    local m = self.modalFrame
    m:SetParent(UIParent)
    m:ClearAllPoints()
    m:SetPoint("CENTER", anchorTarget, "CENTER", 0, 0)
    m:SetFrameStrata("FULLSCREEN_DIALOG")
    m:SetFrameLevel(300)
    m.CloseBtn:SetFrameLevel(305)
    m.Body:SetFrameLevel(302)
    if m.SolidBg then
        m.SolidBg:SetColorTexture(solidPanel.r, solidPanel.g, solidPanel.b, 1.00)
    end
    self:ApplyBackdrop(m, solidPanel, self:GetAccentColorTable(0.95), 1)
    if type(m.Body._modeWidgets) == "table" then
        for _, w in ipairs(m.Body._modeWidgets) do
            if w and w.Hide then w:Hide() end
            if w and w.ClearAllPoints then w:ClearAllPoints() end
        end
        wipe(m.Body._modeWidgets)
    else
        m.Body._modeWidgets = {}
    end
    for _, child in ipairs({ m.Body:GetChildren() }) do child:Hide() end
    if m.Body.textBlock then m.Body.textBlock:Hide() end

    m:SetSize(560, 368)
    if mode == "THEME" then
        m:SetSize(560, 408)
        m.Title:SetText("Theme & Font Studio (Account-Wide)")
        self:StyleFont(m.Title, 14, "", COLORS.TextPrimary)
        local orderedKeys = { "GOLD", "CLASS", "CYAN", "CRIMSON", "OBSIDIAN" }
        local y = -6
        local themeBtns = {}
        local surfBtns = {}
        local fontDd
        local fontLbl
        local function RefreshThemeModalButtons()
            local curSurf, curSurfKey = GetStandaloneSurfaceColors(self)
            local curPanel = { r = curSurf.panel.r, g = curSurf.panel.g, b = curSurf.panel.b, a = 1.00 }
            for _, tb in ipairs(themeBtns) do
                tb.btn.isAccent = (self.suiteGlobal.theme == tb.key)
                if tb.btn.RefreshStyle then tb.btn.RefreshStyle(false) end
            end
            for _, sb in ipairs(surfBtns) do
                sb.btn.isAccent = (curSurfKey == sb.key)
                if sb.btn.RefreshStyle then sb.btn.RefreshStyle(false) end
            end
            if m.SolidBg then
                m.SolidBg:SetColorTexture(curPanel.r, curPanel.g, curPanel.b, 1.00)
            end
            self:ApplyBackdrop(m, curPanel, self:GetAccentColorTable(0.95), 1)
            self:ApplyAllStandaloneFonts()
            if m.Title then self:StyleFont(m.Title, 14, "", COLORS.TextPrimary) end
            if fontLbl then self:StyleFont(fontLbl, 11, "", COLORS.TextSilver) end
            if fontDd and fontDd.RefreshValue then
                fontDd:RefreshValue()
            end
        end
        for _, key in ipairs(orderedKeys) do
            local preset = THEME_PRESETS[key]
            if preset then
                local b = self:CreateButton(m.Body, "Accent: " .. preset.name, 220, 28, function()
                    self.suiteGlobal.theme = key
                    self.suiteGlobal.accentKey = nil
                    RefreshThemeModalButtons()
                    self:RefreshAll()
                    self:RefreshTargetBar()
                    self:RefreshFlareBar()
                end, self.suiteGlobal.theme == key)
                b:SetPoint("TOPLEFT", m.Body, "TOPLEFT", 0, y)
                b:SetFrameLevel(303)
                table.insert(themeBtns, { key = key, btn = b })
                table.insert(m.Body._modeWidgets, b)
                y = y - 34
            end
        end

        local surfOrder = { "OBSIDIAN_DARK", "SLATE_STEEL", "MIDNIGHT_BLACK", "SMOKED_GLASS" }
        local sy = -6
        for _, sKey in ipairs(surfOrder) do
            local sPreset = SURFACE_THEMES[sKey]
            if sPreset then
                local sb = self:CreateButton(m.Body, "Surface: " .. sPreset.name, 250, 28, function()
                    self.suiteGlobal.surfaceTheme = sKey
                    RefreshThemeModalButtons()
                    self:RefreshAll()
                end, surfKey == sKey)
                sb:SetPoint("TOPLEFT", m.Body, "TOPLEFT", 250, sy)
                sb:SetFrameLevel(303)
                table.insert(surfBtns, { key = sKey, btn = sb })
                table.insert(m.Body._modeWidgets, sb)
                sy = sy - 34
            end
        end

        local fSmall = self:CreateButton(m.Body, "Font Scale: 95%", 140, 28, function()
            self.suiteGlobal.fontScale = 0.95
            self:ApplyAllStandaloneFonts()
            self:RefreshAll()
        end)
        fSmall:SetPoint("TOPLEFT", m.Body, "TOPLEFT", 250, -154)
        fSmall:SetFrameLevel(303)
        table.insert(m.Body._modeWidgets, fSmall)

        local fNorm = self:CreateButton(m.Body, "Font Scale: 100%", 140, 28, function()
            self.suiteGlobal.fontScale = 1.00
            self:ApplyAllStandaloneFonts()
            self:RefreshAll()
        end)
        fNorm:SetPoint("TOPLEFT", m.Body, "TOPLEFT", 250, -188)
        fNorm:SetFrameLevel(303)
        table.insert(m.Body._modeWidgets, fNorm)

        local fLarge = self:CreateButton(m.Body, "Font Scale: 110%", 140, 28, function()
            self.suiteGlobal.fontScale = 1.10
            self:ApplyAllStandaloneFonts()
            self:RefreshAll()
        end)
        fLarge:SetPoint("TOPLEFT", m.Body, "TOPLEFT", 250, -222)
        fLarge:SetFrameLevel(303)
        table.insert(m.Body._modeWidgets, fLarge)

        fontLbl = m.Body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fontLbl:SetPoint("TOPLEFT", m.Body, "TOPLEFT", 250, -260)
        self:StyleFont(fontLbl, 11, "", COLORS.TextSilver)
        fontLbl:SetText("Font Family (Built-in, Blizzard & SharedMedia)")
        table.insert(m.Body._modeWidgets, fontLbl)

        fontDd = self:CreateDropdown(
            m.Body,
            250,
            self:GetAvailableFonts(true),
            function() return self:GetActiveFontKeySafe() end,
            function(val)
                self.suiteGlobal.fontKey = val
                self.suiteGlobal.fontFamily = val
                self:ApplyAllStandaloneFonts()
                RefreshThemeModalButtons()
                self:RefreshAll()
            end,
            function() return self:GetAvailableFonts(true) end
        )
        fontDd:SetPoint("TOPLEFT", m.Body, "TOPLEFT", 250, -278)
        fontDd:SetFrameLevel(303)
        table.insert(m.Body._modeWidgets, fontDd)

    elseif mode == "SETUP" then
        local conflicts = self:ScanConflicts()
        local advisories = (#conflicts == 0) and self:ScanAdvisoryConflicts() or {}
        m:SetSize(560, (#conflicts > 0 or #advisories > 0) and 402 or 368)
        m.Title:SetText("DynamicMarker Guided Setup")
        local txt = m.Body.textBlock or m.Body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        m.Body.textBlock = txt
        txt:ClearAllPoints()
        txt:SetPoint("TOPLEFT", m.Body, "TOPLEFT", 0, -4)
        txt:SetPoint("RIGHT", m.Body, "RIGHT", 0, 0)
        txt:SetJustifyH("LEFT")
        txt:SetWordWrap(true)
        self:StyleFont(txt, 12, "", COLORS.TextPrimary)

        local conflictStatus
        if #conflicts > 0 then
            if conflicts[1].name == "DecorVendor" then
                conflictStatus = "Detected Active Conflict: DecorVendor taints Blizzard's /tm command (Disable & restart game)"
            else
                conflictStatus = "Detected Active Conflict: " .. conflicts[1].name .. " (Click button below to import & disable)"
            end
        elseif #advisories > 0 then
            conflictStatus = "Compatibility Notice: " .. advisories[1].name .. " can taint Blizzard's /tm command in dungeons & raids."
        else
            conflictStatus = READY_CHECK_TEX .. " No conflicting marker addons detected."
        end

        txt:SetText(
            "1. Conflict Check: " .. conflictStatus .. "\n\n" ..
            "2. Focus Icon & World Flares: Default Focus Icon is " .. RAID_ICONS[8].label .. ". World Flare hotkeys start Unbound so they never overwrite your existing F4/F5 bindings unless assigned below or in /dm flares.\n\n" ..
            "3. Optional World Flare Keybinds & Smart Macros ([DynamicMark] / [DynamicKick]):"
        )
        txt:Show()

        local yCursor = -94
        if #conflicts > 0 then
            local isDV = (conflicts[1].name == "DecorVendor")
            local btnLbl = isDV and "Disable DecorVendor (Set to Never)" or "Import & Use DynamicMarker"
            local btnW   = isDV and 254 or 220
            local cBtn = self:CreateButton(m.Body, btnLbl, btnW, 28, function()
                self:ResolveConflictUseDynamic(conflicts[1].name)
                self:ShowStudioModal("SETUP")
            end, true)
            cBtn:SetPoint("TOPLEFT", m.Body, "TOPLEFT", 0, yCursor)
            cBtn:SetFrameLevel(303)
            table.insert(m.Body._modeWidgets, cBtn)
            yCursor = yCursor - 38
        elseif #advisories > 0 then
            local advAddon = advisories[1].name
            local disBtn = self:CreateButton(m.Body, "Disable " .. advAddon, 180, 28, function()
                self:ResolveAdvisoryDisable(advAddon)
                self:ShowStudioModal("SETUP")
            end, true)
            disBtn:SetPoint("TOPLEFT", m.Body, "TOPLEFT", 0, yCursor)
            disBtn:SetFrameLevel(303)
            table.insert(m.Body._modeWidgets, disBtn)

            local dimBtn = self:CreateButton(m.Body, "Dismiss", 104, 28, function()
                self:DismissAdvisoryConflict(advAddon)
                self:ShowStudioModal("SETUP")
            end)
            dimBtn:SetPoint("LEFT", disBtn, "RIGHT", 10, 0)
            dimBtn:SetFrameLevel(303)
            table.insert(m.Body._modeWidgets, dimBtn)
            yCursor = yCursor - 38
        end

        local function AddSetupKeyRow(yOff, labelStr, getterFn, setterFn)
            local rowLbl = m.Body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rowLbl:SetPoint("TOPLEFT", m.Body, "TOPLEFT", 0, yOff - 6)
            rowLbl:SetWidth(310)
            rowLbl:SetJustifyH("LEFT")
            rowLbl:SetWordWrap(false)
            self:StyleFont(rowLbl, 11.5, "", COLORS.TextPrimary)
            rowLbl:SetText(labelStr)
            table.insert(m.Body._modeWidgets, rowLbl)

            local kb = self:CreateKeybindButton(m.Body, 204, getterFn, function(newKey)
                setterFn(newKey)
                self:ApplyFlareKeybinds()
                self:RefreshKeybindTelemetryAndTabTitle()
                self:RefreshAll()
            end, "")
            kb:SetFrameLevel(303)
            kb:SetPoint("TOPRIGHT", m.Body, "TOPRIGHT", 0, yOff)
            table.insert(m.Body._modeWidgets, kb)
        end

        AddSetupKeyRow(yCursor, "Cycle World Flare Keybind (Optional)",
            function() return (self.db and self.db.flareCycleKey) or "" end,
            function(newKey) if self.db then self.db.flareCycleKey = newKey end end)

        AddSetupKeyRow(yCursor - 34, "Clear All Flares Keybind (Optional)",
            function() return (self.db and self.db.flareClearKey) or "" end,
            function(newKey) if self.db then self.db.flareClearKey = newKey end end)

        local kbNote = m.Body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        kbNote:SetPoint("TOPLEFT", m.Body, "TOPLEFT", 0, yCursor - 68)
        kbNote:SetPoint("RIGHT", m.Body, "RIGHT", 0, 0)
        kbNote:SetJustifyH("LEFT")
        kbNote:SetWordWrap(true)
        self:StyleFont(kbNote, 10.5, "", COLORS.TextMuted)
        kbNote:SetText("Click to bind, Right-click to unbind. (Esc cancels capture; Backspace or Delete also unbinds.)")
        table.insert(m.Body._modeWidgets, kbNote)

        local macroY = yCursor - 102
        local mBtn1 = self:CreateButton(m.Body, RAID_ICONS[8].emoji .. " Create [DynamicMark]", 252, 28, function()
            self:CreateOrUpdateFocusMarkerMacro(true)
            self:RefreshAll()
        end, true)
        mBtn1:SetPoint("TOPLEFT", m.Body, "TOPLEFT", 0, macroY)
        mBtn1:SetFrameLevel(303)
        table.insert(m.Body._modeWidgets, mBtn1)

        local mBtn2 = self:CreateButton(m.Body, "Create [DynamicKick] (Character)", 252, 28, function()
            self:CreateOrUpdateDynamicKickMacro(true)
            self:RefreshAll()
        end, true)
        mBtn2:SetPoint("LEFT", mBtn1, "RIGHT", 10, 0)
        mBtn2:SetFrameLevel(303)
        table.insert(m.Body._modeWidgets, mBtn2)

        local doneBtn = self:CreateButton(m.Body, READY_CHECK_TEX .. " Complete Guided Setup", 210, 28, function()
            self.suiteGlobal.guidedSetupDone = true
            self:CloseStudioModal()
        end)
        doneBtn:SetPoint("BOTTOMRIGHT", m.Body, "BOTTOMRIGHT", 0, 0)
        doneBtn:SetFrameLevel(303)
        table.insert(m.Body._modeWidgets, doneBtn)

    elseif mode == "CHANGELOG" then
        m.Title:SetText("DynamicMarker v" .. (self.version or VERSION) .. " Changelog")
        local clBox = m.Body._changelogBox
        if not clBox then
            clBox = CreateFrame("Frame", nil, m.Body)
            clBox:SetAllPoints(m.Body)
            clBox:SetFrameLevel(303)

            local sf = CreateFrame("ScrollFrame", nil, clBox)
            sf:SetPoint("TOPLEFT", clBox, "TOPLEFT", 0, -2)
            sf:SetPoint("BOTTOMRIGHT", clBox, "BOTTOMRIGHT", -10, 2)
            sf:EnableMouseWheel(true)

            local child = CreateFrame("Frame", nil, sf)
            child:SetSize(512, 300)
            sf:SetScrollChild(child)

            local txt = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            txt:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -2)
            txt:SetWidth(504)
            txt:SetJustifyH("LEFT")
            txt:SetWordWrap(true)
            self:StyleFont(txt, 12, "", COLORS.TextSilver)
            txt:SetSpacing(2)

            local track = CreateFrame("Frame", nil, clBox)
            track:SetWidth(4)
            track:SetPoint("TOPRIGHT", clBox, "TOPRIGHT", 0, -2)
            track:SetPoint("BOTTOMRIGHT", clBox, "BOTTOMRIGHT", 0, 2)
            track:EnableMouse(true)
            track.bg = track:CreateTexture(nil, "BACKGROUND")
            track.bg:SetAllPoints(track)
            track.bg:SetColorTexture(1, 1, 1, 0.06)
            track:Hide()

            local thumb = CreateFrame("Button", nil, track)
            thumb:SetWidth(4)
            thumb:SetHeight(48)
            thumb:SetPoint("TOP", track, "TOP", 0, 0)
            thumb:EnableMouse(true)
            thumb.bg = thumb:CreateTexture(nil, "ARTWORK")
            thumb.bg:SetAllPoints(thumb)
            thumb.bg:SetColorTexture(0.38, 0.45, 0.56, 0.85)

            local function RefreshClThumbColor()
                if thumb.isDragging then
                    local ar, ag, ab = self:GetAccentColor()
                    thumb.bg:SetColorTexture(ar, ag, ab, 0.95)
                elseif thumb:IsMouseOver() then
                    thumb.bg:SetColorTexture(0.52, 0.60, 0.72, 0.95)
                else
                    thumb.bg:SetColorTexture(0.38, 0.45, 0.56, 0.85)
                end
            end

            local function UpdateClScroll()
                local viewH = math.max(100, sf:GetHeight() or 300)
                local viewW = math.max(200, sf:GetWidth() or 512)
                child:SetWidth(viewW)
                txt:SetWidth(math.max(180, viewW - 8))
                local contentH = math.max(viewH, (txt:GetStringHeight() or 260) + 14)
                child:SetHeight(contentH)
                local maxScroll = math.max(0, contentH - viewH)
                if maxScroll > 2 then
                    track:Show()
                    local cur = math.min(maxScroll, math.max(0, sf:GetVerticalScroll() or 0))
                    sf:SetVerticalScroll(cur)
                    local trackH = track:GetHeight() or viewH
                    local thumbH = math.max(26, math.floor(trackH * (viewH / contentH)))
                    thumb:SetHeight(thumbH)
                    local travel = math.max(1, trackH - thumbH)
                    thumb:ClearAllPoints()
                    thumb:SetPoint("TOP", track, "TOP", 0, -(cur / maxScroll) * travel)
                    RefreshClThumbColor()
                else
                    track:Hide()
                    sf:SetVerticalScroll(0)
                end
            end

            sf:SetScript("OnMouseWheel", function(_, delta)
                local viewH = sf:GetHeight() or 300
                local maxScroll = math.max(0, (child:GetHeight() or 300) - viewH)
                if maxScroll <= 0 then return end
                local nextScroll = math.min(maxScroll, math.max(0, (sf:GetVerticalScroll() or 0) - delta * 36))
                sf:SetVerticalScroll(nextScroll)
                UpdateClScroll()
            end)

            track:SetScript("OnMouseDown", function(selfTrack, btn)
                if btn ~= "LeftButton" then return end
                local viewH = sf:GetHeight() or 300
                local maxScroll = math.max(0, (child:GetHeight() or 300) - viewH)
                if maxScroll <= 0 then return end
                local scale = selfTrack:GetEffectiveScale() or 1
                local _, cy = GetCursorPosition()
                cy = cy / scale
                local top, bottom = selfTrack:GetTop(), selfTrack:GetBottom()
                if top and bottom and top > bottom then
                    local trackH = top - bottom
                    local thumbH = thumb:GetHeight() or 26
                    local travel = math.max(1, trackH - thumbH)
                    local ratio = math.max(0, math.min(1, ((top - cy) - (thumbH * 0.5)) / travel))
                    sf:SetVerticalScroll(ratio * maxScroll)
                    UpdateClScroll()
                end
            end)

            thumb:SetScript("OnEnter", function() RefreshClThumbColor() end)
            thumb:SetScript("OnLeave", function() RefreshClThumbColor() end)
            thumb:SetScript("OnMouseDown", function(s, btn)
                if btn ~= "LeftButton" then return end
                s.isDragging = true
                RefreshClThumbColor()
                local _, startCursorY = GetCursorPosition()
                startCursorY = startCursorY / (s:GetEffectiveScale() or 1)
                local startScroll = sf:GetVerticalScroll() or 0
                s:SetScript("OnUpdate", function()
                    if not IsMouseButtonDown("LeftButton") then
                        s.isDragging = false
                        s:SetScript("OnUpdate", nil)
                        RefreshClThumbColor()
                        return
                    end
                    local viewH = sf:GetHeight() or 300
                    local maxScroll = math.max(0, (child:GetHeight() or 300) - viewH)
                    if maxScroll <= 0 then return end
                    local trackH = track:GetHeight() or viewH
                    local thumbH = thumb:GetHeight() or 26
                    local travel = math.max(1, trackH - thumbH)
                    local _, curY = GetCursorPosition()
                    curY = curY / (s:GetEffectiveScale() or 1)
                    local dy = startCursorY - curY
                    sf:SetVerticalScroll(math.min(maxScroll, math.max(0, startScroll + (dy / travel) * maxScroll)))
                    UpdateClScroll()
                end)
            end)
            thumb:SetScript("OnMouseUp", function(s)
                s.isDragging = false
                s:SetScript("OnUpdate", nil)
                RefreshClThumbColor()
            end)
            thumb:SetScript("OnHide", function(s)
                s.isDragging = false
                s:SetScript("OnUpdate", nil)
                RefreshClThumbColor()
            end)

            clBox.sf = sf
            clBox.txt = txt
            clBox.UpdateScroll = UpdateClScroll
            m.Body._changelogBox = clBox
        end

        local badgeColors = {
            FEATURE = "|cFF22C55E[FEATURE]|r",
            FIX     = "|cFFEAB308[FIX]|r",
            UI      = "|cFF38BDF8[UI]|r",
        }
        local lines = {}
        local clData = DynamicMarker.CHANGELOG and DynamicMarker.CHANGELOG.entries or {}
        for _, entry in ipairs(clData) do
            if type(entry) == "table" and type(entry.text) == "string" and entry.text ~= "" then
                local badge = badgeColors[entry.type] or "|cFF94A3B8[INFO]|r"
                lines[#lines + 1] = badge .. " " .. entry.text
            end
        end
        self:StyleFont(clBox.txt, 12, "", COLORS.TextSilver)
        clBox.txt:SetText(#lines > 0 and table.concat(lines, "\n\n") or "No changelog entries recorded.")
        clBox:Show()
        clBox.sf:SetVerticalScroll(0)
        clBox.UpdateScroll()
        C_Timer.After(0, function()
            if clBox:IsShown() then clBox.UpdateScroll() end
        end)
        table.insert(m.Body._modeWidgets, clBox)

    elseif mode == "SUPPORT" then
        m.Title:SetText("Support DynamicMarker & Dentee")
        local txt = m.Body.textBlock or m.Body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        m.Body.textBlock = txt
        txt:ClearAllPoints()
        txt:SetPoint("TOPLEFT", m.Body, "TOPLEFT", 0, -4)
        txt:SetPoint("RIGHT", m.Body, "RIGHT", 0, 0)
        txt:SetJustifyH("LEFT")
        self:StyleFont(txt, 12, "", COLORS.TextSilver)
        txt:SetText("Thank you for using DynamicMarker v" .. (self.version or VERSION) .. "!\n\nIf you enjoy the module, you can support ongoing development or share feedback via the links below (click any box and press Ctrl+C):")
        txt:Show()

        local function CreateSupportCopyRow(yOff, labelTxt, urlTxt)
            local lbl = m.Body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            lbl:SetPoint("TOPLEFT", m.Body, "TOPLEFT", 0, yOff)
            lbl:SetJustifyH("LEFT")
            self:StyleFont(lbl, 11, "", { r = 0.72, g = 0.76, b = 0.84, a = 1.0 })
            lbl:SetText(labelTxt)
            table.insert(m.Body._modeWidgets, lbl)

            local ebWrap = CreateFrame("Frame", nil, m.Body, "BackdropTemplate")
            ebWrap:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -4)
            ebWrap:SetPoint("RIGHT", m.Body, "RIGHT", 0, 0)
            ebWrap:SetHeight(26)
            ebWrap:SetFrameLevel(303)
            self:ApplyBackdrop(ebWrap, { r = 0.035, g = 0.042, b = 0.058, a = 0.98 }, { r = 1, g = 1, b = 1, a = 0.14 }, 1)
            table.insert(m.Body._modeWidgets, ebWrap)

            local eb = CreateFrame("EditBox", nil, ebWrap)
            eb:SetPoint("LEFT", ebWrap, "LEFT", 10, 0)
            eb:SetPoint("RIGHT", ebWrap, "RIGHT", -10, 0)
            eb:SetHeight(22)
            eb:SetFrameLevel(304)
            eb:SetAutoFocus(false)
            self:StyleFont(eb, 11, "", { r = 1, g = 1, b = 1, a = 0.96 })
            eb:SetText(urlTxt)
            eb:SetScript("OnEditFocusGained", function(s) s:HighlightText() end)
            eb:SetScript("OnMouseUp", function(s) s:SetFocus(); s:HighlightText() end)
            eb:SetScript("OnEscapePressed", function(s) s:ClearFocus(); self:CloseStudioModal() end)
            eb:SetScript("OnChar", function(s) s:SetText(urlTxt); s:HighlightText() end)
            eb:SetScript("OnTextChanged", function(s, userInput)
                if userInput then
                    s:SetText(urlTxt)
                    s:HighlightText()
                end
            end)
            table.insert(m.Body._modeWidgets, eb)
        end

        CreateSupportCopyRow(-74,  "Buy the Developer a Coffee (Ko-fi):", "https://ko-fi.com/dentee")
        CreateSupportCopyRow(-126, "CurseForge Project Page & Feedback:", "https://www.curseforge.com/wow/addons/dynamicmarker")
        CreateSupportCopyRow(-178, "Full Addon Suite (DynamicSuite):", "https://www.curseforge.com/wow/addons/dynamicsuite")
        CreateSupportCopyRow(-230, "Direct Contact & Feedback (Email):", "denteedev@gmail.com")
    end

    m:SetHeight((mode == "SUPPORT" and 428) or (mode == "SETUP" and 466) or 368)
    m:Show()
    if not (InCombatLockdown and InCombatLockdown()) and m.EnableKeyboard then
        pcall(m.EnableKeyboard, m, true)
    end
end

-- ============================================================================
-- 16. RESIZABLE 980x680 _G.DYNAMICSUITE SHELL & DOCKING ROUTER
-- ============================================================================

function DM:ResetSingleHUDPosition(hudKey, silent)
    if InCombatLockdown and InCombatLockdown() then
        self.pendingHUDPositionReset = true
        if not silent then
            print("|cFF22C55EDynamicMarker|r: |cFFF87171Cannot reset HUD position during combat lockdown.|r Position will reset safely after combat ends.")
        end
        return false
    end
    if not self.db then self:InitDB() end
    local primaryKey, _, _, dbPrefix, defY, upperKey = ResolveHUDKeyAliases(hudKey)
    local targetFrame = (primaryKey == "FlareBar") and self.flareBar or self.targetBar
    local isFlare = (primaryKey == "FlareBar")

    self:SetSetting(dbPrefix .. "Scale", 1.00)
    self:SetSetting(dbPrefix .. "Opacity", 0.95)
    self:SetSetting(dbPrefix .. "BorderStyle", "ACCENT")
    self:SetSetting("hudBorderStyle", "ACCENT")
    self:SetSetting(dbPrefix .. "Orientation", "HORIZONTAL")
    if not isFlare then
        self:SetSetting("barScale", 1.00)
    end
    if type(_G.DynamicSuiteDB) == "table" and type(_G.DynamicSuiteDB.global) == "table" then
        _G.DynamicSuiteDB.global.hudScales = _G.DynamicSuiteDB.global.hudScales or {}
        _G.DynamicSuiteDB.global.hudScales[upperKey] = 1.00
    end
    local activeScope = (_G.DynamicSuite and type(_G.DynamicSuite.GetSuiteGlobal) == "function") and _G.DynamicSuite.GetSuiteGlobal() or nil
    if type(activeScope) == "table" then
        activeScope.hudScales = activeScope.hudScales or {}
        activeScope.hudScales[upperKey] = 1.00
    end

    if targetFrame then
        if isFlare then self:RefreshFlareBar() else self:RefreshTargetBar() end
        self:SyncBarScaleAndSizeToDB(targetFrame, primaryKey)
    end

    local rx, ry = self:ClampHUDPositionToScreen(targetFrame, primaryKey, "CENTER", "CENTER", 0, defY, { enableSnap = false })
    self:WriteHUDCoordsToDB(primaryKey, "CENTER", "CENTER", rx, ry)
    if targetFrame then
        self:ApplyHUDPosition(targetFrame, primaryKey, defY)
        if isFlare then self:RefreshFlareBar() else self:RefreshTargetBar() end
        if targetFrame.editMover and targetFrame.editMover.RefreshMoverVisual then
            targetFrame.editMover:RefreshMoverVisual()
        end
    end
    self:RefreshEditModeInspector()
    self:RefreshAll()
    if not self._suppressSuiteNotify and _G.DynamicSuite and type(_G.DynamicSuite.NotifyExternalHudChanged) == "function" then
        pcall(_G.DynamicSuite.NotifyExternalHudChanged, upperKey)
    end
    if not silent then
        print(string.format("|cFF22C55EDynamicMarker|r: %s position, orientation, and scale reset to default (%d, %d).", primaryKey, rx, ry))
    end
    return true
end

function DM:ResetHUDPositions(silent)
    if InCombatLockdown and InCombatLockdown() then
        self.pendingHUDPositionReset = true
        if not silent then
            print("|cFF22C55EDynamicMarker|r: |cFFF87171Cannot reset HUD positions during combat lockdown.|r Positions will reset safely after combat ends.")
        end
        return false
    end
    self.pendingHUDPositionReset = false
    self:ResetSingleHUDPosition("TargetBar", true)
    self:ResetSingleHUDPosition("FlareBar", true)
    if not silent then
        print("|cFF22C55EDynamicMarker|r: HUD positions, orientation, and scales reset to safe defaults.")
    end
    return true
end
DM.ResetHUDPosition = DM.ResetHUDPositions

function DM:ResetDefaults()
    local prevMigrated = self.db and self.db.migratedFromFocusMarker
    local prevBridgeVer = self.db and self.db.focusMarkerBridgeVersion
    local prevLegacy = self.db and SafeDeepCopyValue(self.db.legacyFocusMarker)
    local prevHint = self.db and self.db.focusMarkerHintShown
    _G.DynamicMarkerDB = DeepCopyDefaults(DB_DEFAULTS, {})
    self.db = _G.DynamicMarkerDB
    if prevMigrated ~= nil then self.db.migratedFromFocusMarker = prevMigrated end
    if prevBridgeVer ~= nil then self.db.focusMarkerBridgeVersion = prevBridgeVer end
    if type(prevLegacy) == "table" then self.db.legacyFocusMarker = prevLegacy end
    if prevHint ~= nil then self.db.focusMarkerHintShown = prevHint end
    self.db.iconOrder = { 1, 2, 3, 4, 5, 6, 7, 8 }
    self.db.flareOrder = { 1, 2, 3, 4, 5, 6, 7, 8 }
    self.db.flareEnabled = {
        [1] = true, [2] = true, [3] = true, [4] = true,
        [5] = true, [6] = true, [7] = true, [8] = true,
    }
    self.db.flareEnabledAll8MigratedV2 = true
    self.db.targetBarPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = -140 }
    self.db.flareBarPos  = { point = "CENTER", relPoint = "CENTER", x = 0, y = -182 }
    if self.suiteGlobal and self.suiteGlobal.hudPositions then
        local defT = { point = "CENTER", relPoint = "CENTER", x = 0, y = -140 }
        local defF = { point = "CENTER", relPoint = "CENTER", x = 0, y = -182 }
        self.suiteGlobal.hudPositions.TARGET                 = defT
        self.suiteGlobal.hudPositions.TargetBar              = defT
        self.suiteGlobal.hudPositions.target                 = defT
        self.suiteGlobal.hudPositions.DynamicMarkerTargetBar = defT
        self.suiteGlobal.hudPositions.FLARE                  = defF
        self.suiteGlobal.hudPositions.FlareBar               = defF
        self.suiteGlobal.hudPositions.flare                  = defF
        self.suiteGlobal.hudPositions.DynamicMarkerFlareBar  = defF
    end
    self:ApplyHUDPosition(self.targetBar, "TargetBar", -140)
    self:ApplyHUDPosition(self.flareBar, "FlareBar", -182)
    self:SyncSecureFlareEngine()
    self:ApplyFlareKeybinds()
    self:RefreshKeybindTelemetryAndTabTitle()
    self:RefreshTargetBar()
    self:RefreshFlareBar()
    self:RefreshAll()
    print("|cFF22C55EDynamicMarker|r: Restored DynamicMarker defaults and HUD positions.")
end

function DM:EnsureStandaloneShell()
    if self.shellFrame then return self.shellFrame end

    local winCfg = self.suiteGlobal.window
    local surf = GetStandaloneSurfaceColors(self)
    local RAIL_W = 204
    local HDR_H  = 46
    local DOCK_H = 38
    local cardBg = { r = surf.card.r, g = surf.card.g, b = surf.card.b, a = 0.96 }
    local cardBd = { r = 0.175, g = 0.200, b = 0.258, a = 0.95 }
    local cardHoverBg = { r = 0.145, g = 0.168, b = 0.215, a = 1.00 }
    local dividerCol = { r = 1.00, g = 1.00, b = 1.00, a = 0.08 }

    local f = CreateFrame("Frame", "DynamicMarkerSuiteWindow", UIParent, "BackdropTemplate")
    f:SetSize(winCfg.width or 980, winCfg.height or 680)
    if type(UISpecialFrames) == "table" then
        local foundSpecial = false
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == "DynamicMarkerSuiteWindow" then
                foundSpecial = true
                break
            end
        end
        if not foundSpecial then
            table.insert(UISpecialFrames, "DynamicMarkerSuiteWindow")
        end
    end
    f:SetPoint(winCfg.point or "CENTER", UIParent, winCfg.relPoint or "CENTER", winCfg.x or 0, winCfg.y or 0)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then
        f:SetResizeBounds(800, 520, 1380, 900)
    end
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local pt, _, rpt, x, y = s:GetPoint(1)
        if pt then
            winCfg.point, winCfg.relPoint, winCfg.x, winCfg.y = pt, rpt, math.floor(x + 0.5), math.floor(y + 0.5)
        end
    end)
    f:HookScript("OnHide", function()
        self:CloseDropdownMenu()
        self:CloseStudioModal()
    end)
    function f:Minimize()
        DM:CloseDropdownMenu()
        DM:CloseStudioModal()
        self:Hide()
    end
    f:HookScript("OnShow", function(s)
        if s.Raise then s:Raise() end
        if not s._postLayoutPending and C_Timer and C_Timer.After then
            s._postLayoutPending = true
            C_Timer.After(0, function()
                s._postLayoutPending = nil
                if not s:IsShown() then return end
                if self.ApplyThemeToUI then self:ApplyThemeToUI() end
                if self.RefreshAll then self:RefreshAll() end
                if s.Raise then s:Raise() end
            end)
        end
    end)
    f:Hide()
    self:ApplyBackdrop(f, surf.panel, COLORS.BorderStrong, 1)

    -- ------------------------------------------------------------------------
    -- Clean 3-Zone Top Header (46px height + 2px top accent bar)
    -- Zone 1: [Logo + Module Name + Clickable Version]
    -- Zone 2: [Spacious 1-Line Status Bar]
    -- Zone 3: [All Characters + X]
    -- ------------------------------------------------------------------------
    local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
    header:SetHeight(HDR_H)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    self:ApplyBackdrop(header, { r = surf.header.r, g = surf.header.g, b = surf.header.b, a = 1.0 }, { r = 0, g = 0, b = 0, a = 0 }, 0)
    f.Header = header

    local initR, initG, initB, initHex = self:GetAccentColor()

    local headerAccentTop = header:CreateTexture(nil, "OVERLAY")
    headerAccentTop:SetHeight(2)
    headerAccentTop:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    headerAccentTop:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
    headerAccentTop:SetColorTexture(initR, initG, initB, 1.0)
    header.AccentTop = headerAccentTop

    local headerDivider = header:CreateTexture(nil, "OVERLAY")
    headerDivider:SetHeight(1)
    headerDivider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    headerDivider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    headerDivider:SetColorTexture(dividerCol.r, dividerCol.g, dividerCol.b, dividerCol.a)
    header.Divider = headerDivider

    local logo = header:CreateTexture(nil, "ARTWORK", nil, 0)
    logo:SetSize(24, 24)
    logo:SetPoint("LEFT", header, "LEFT", 14, 0)
    logo:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_white.tga")
    logo:SetVertexColor(0.96, 0.97, 0.99, 1.0)
    header.LogoWhite = logo

    local logoAccent = header:CreateTexture(nil, "ARTWORK", nil, 1)
    logoAccent:SetAllPoints(logo)
    logoAccent:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_accent.tga")
    logoAccent:SetVertexColor(initR, initG, initB, 1.0)
    header.LogoAccent = logoAccent

    header.ModTitle = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    header.ModTitle:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    self:StyleFont(header.ModTitle, 15, "", COLORS.TextPrimary)
    header.ModTitle:SetText(string.format("|cFF%sDynamic|r|cFFFFFFFFMarker|r", initHex))

    header.VerBtn = self:CreateButton(header, "v" .. self.version, 72, 22, function()
        self:ShowStudioModal("CHANGELOG")
    end)
    header.VerBtn:SetPoint("LEFT", header.ModTitle, "RIGHT", 10, 0)

    -- Zone 3 (Right): [All Characters] + [X]
    local closeBtn = self:CreateButton(header, "X", 28, 24, function() f:Hide() end)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -12, 0)

    local scopePill = self:CreateButton(header, "|T" .. ICON_CHECK_PATH .. ":10:10:0:0|t All Characters", 128, 24, function()
        print("|cFF38BDF8DynamicSuite|r: Account-Wide settings sync is active across all characters.")
    end)
    scopePill:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)

    -- Zone 2 (Center): Spacious 1-Line Status Capsule
    local statusBox = CreateFrame("Frame", nil, header, "BackdropTemplate")
    statusBox:SetHeight(26)
    statusBox:SetPoint("LEFT", header.VerBtn, "RIGHT", 14, 0)
    statusBox:SetPoint("RIGHT", scopePill, "LEFT", -14, 0)
    self:ApplyBackdrop(statusBox, cardBg, cardBd)

    statusBox.Text = statusBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusBox.Text:SetPoint("LEFT", statusBox, "LEFT", 10, 0)
    statusBox.Text:SetPoint("RIGHT", statusBox, "RIGHT", -10, 0)
    statusBox.Text:SetJustifyH("CENTER")
    statusBox.Text:SetWordWrap(false)
    self:StyleFont(statusBox.Text, 11, "", COLORS.TextSilver)
    f.StatusText = statusBox.Text

    -- ------------------------------------------------------------------------
    -- Bottom Bar & Standardized Bottom-Left Reset Dock + Bottom-Right Grip (38px)
    -- ------------------------------------------------------------------------
    local footer = CreateFrame("Frame", nil, f, "BackdropTemplate")
    footer:SetHeight(DOCK_H)
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
    footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    self:ApplyBackdrop(footer, { r = surf.header.r, g = surf.header.g, b = surf.header.b, a = 1.0 }, { r = 0, g = 0, b = 0, a = 0 }, 0)
    f.Footer = footer

    local footerDivider = footer:CreateTexture(nil, "OVERLAY")
    footerDivider:SetHeight(1)
    footerDivider:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 0)
    footerDivider:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, 0)
    footerDivider:SetColorTexture(dividerCol.r, dividerCol.g, dividerCol.b, dividerCol.a)
    footer.Divider = footerDivider

    -- ------------------------------------------------------------------------
    -- Left Suite Rail (204px width): DYNAMIC MODULES + SUITE STUDIO & TOOLS
    -- ------------------------------------------------------------------------
    local rail = CreateFrame("Frame", nil, f, "BackdropTemplate")
    rail:SetWidth(RAIL_W)
    rail:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    rail:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 0)
    self:ApplyBackdrop(rail, surf.rail, { r = 0, g = 0, b = 0, a = 0 }, 0)
    f.Rail = rail

    local railDivider = rail:CreateTexture(nil, "OVERLAY")
    railDivider:SetWidth(1)
    railDivider:SetPoint("TOPRIGHT", rail, "TOPRIGHT", 0, 0)
    railDivider:SetPoint("BOTTOMRIGHT", rail, "BOTTOMRIGHT", 0, 0)
    railDivider:SetColorTexture(dividerCol.r, dividerCol.g, dividerCol.b, dividerCol.a)
    rail.Divider = railDivider

    local modHeader = rail:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    modHeader:SetPoint("TOPLEFT", rail, "TOPLEFT", 14, -12)
    self:StyleFont(modHeader, 10, "", COLORS.TextMuted)
    modHeader:SetText("DYNAMIC MODULES")

    rail.modBtns = {}
    local loadedModules = {}
    for _, mInfo in ipairs(SUITE_MODULE_LIST) do
        local isModLoaded = (mInfo.key == "marker")
            or (Suite.modules and (Suite.modules[mInfo.key] ~= nil or Suite.modules[mInfo.addon] ~= nil))
            or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(mInfo.addon))
        if isModLoaded then
            table.insert(loadedModules, mInfo)
        end
    end

    for i, mInfo in ipairs(loadedModules) do
        local mBtn = CreateFrame("Button", nil, rail, "BackdropTemplate")
        mBtn:SetHeight(40)
        mBtn:SetPoint("TOPLEFT", rail, "TOPLEFT", 10, -26 - (i - 1) * 44)
        mBtn:SetPoint("TOPRIGHT", rail, "TOPRIGHT", -10, -26 - (i - 1) * 44)
        mBtn.modKey = mInfo.key
        mBtn.modTitle = mInfo.title

        mBtn.LeftBar = mBtn:CreateTexture(nil, "OVERLAY")
        mBtn.LeftBar:SetWidth(3)
        mBtn.LeftBar:SetPoint("TOPLEFT", mBtn, "TOPLEFT", 0, 0)
        mBtn.LeftBar:SetPoint("BOTTOMLEFT", mBtn, "BOTTOMLEFT", 0, 0)
        mBtn.LeftBar:SetColorTexture(initR, initG, initB, 1.0)

        mBtn.Icon = mBtn:CreateTexture(nil, "ARTWORK")
        mBtn.Icon:SetSize(16, 16)
        mBtn.Icon:SetPoint("LEFT", mBtn, "LEFT", 10, 0)
        mBtn.Icon:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_" .. mInfo.key .. ".tga")
        mBtn.Icon:SetVertexColor(initR, initG, initB, 1.0)

        mBtn.Title = mBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        mBtn.Title:SetPoint("TOPLEFT", mBtn, "TOPLEFT", 32, -6)
        mBtn.Title:SetWordWrap(false)
        self:StyleFont(mBtn.Title, 11, "", COLORS.TextPrimary)
        mBtn.Title:SetText(mInfo.title)

        mBtn.Sub = mBtn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        mBtn.Sub:SetPoint("TOPLEFT", mBtn.Title, "BOTTOMLEFT", 0, -2)
        mBtn.Sub:SetWordWrap(false)
        self:StyleFont(mBtn.Sub, 9, "", COLORS.TextMuted)
        mBtn.Sub:SetText(mInfo.sub)

        if mInfo.key == "marker" then
            self:ApplyBackdrop(mBtn, { r = initR * 0.16, g = initG * 0.16, b = initB * 0.16, a = 0.96 }, { r = initR, g = initG, b = initB, a = 0.85 })
        else
            mBtn.LeftBar:Hide()
            mBtn.Icon:SetVertexColor(0.72, 0.76, 0.84, 0.95)
            self:ApplyBackdrop(mBtn, COLORS.BgSurface, COLORS.BorderDim)
        end

        mBtn:SetScript("OnClick", function()
            if mInfo.key == "marker" then
                self:SelectActiveModuleInShell("marker")
            else
                local regMod = Suite.modules[mInfo.key] or Suite.modules[mInfo.addon]
                if regMod then
                    local renderFn = regMod.RenderEmbedded or regMod.Render or regMod.BuildUI or regMod.Build or regMod.CreatePanel
                    if type(renderFn) == "function" then
                        self:SelectActiveModuleInShell(mInfo.key, regMod)
                    elseif type(regMod.ToggleUI) == "function" then
                        f:Hide()
                        pcall(regMod.ToggleUI, true)
                    elseif type(regMod.Open) == "function" then
                        f:Hide()
                        pcall(regMod.Open, regMod)
                    else
                        self:SelectActiveModuleInShell(mInfo.key, regMod)
                    end
                elseif C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(mInfo.addon) and SlashCmdList then
                    f:Hide()
                    if mInfo.key == "load" and SlashCmdList["DYNAMICLOAD"] then
                        SlashCmdList["DYNAMICLOAD"]("")
                    elseif mInfo.key == "prep" and SlashCmdList["DYNAMICPREP"] then
                        SlashCmdList["DYNAMICPREP"]("")
                    elseif mInfo.key == "zoom" and SlashCmdList["DYNAMICZOOM"] then
                        SlashCmdList["DYNAMICZOOM"]("")
                    elseif mInfo.key == "fps" and SlashCmdList["DYNAMICFPS"] then
                        SlashCmdList["DYNAMICFPS"]("")
                    elseif mInfo.key == "group" and SlashCmdList["DYNAMICGROUP"] then
                        SlashCmdList["DYNAMICGROUP"]("")
                    elseif mInfo.key == "bags" and SlashCmdList["DYNAMICBAGS"] then
                        SlashCmdList["DYNAMICBAGS"]("")
                    elseif mInfo.key == "chat" and SlashCmdList["DYNAMICCHAT"] then
                        SlashCmdList["DYNAMICCHAT"]("")
                    end
                else
                    print(string.format("|cFF38BDF8DynamicSuite|r: |cFFFFFFFF%s|r is not currently loaded.", mInfo.title))
                end
            end
        end)

        rail.modBtns[i] = mBtn
    end

    -- Subtle standalone status pill above SUITE STUDIO & TOOLS (never clips inside 204px rail)
    local standaloneBadge = CreateFrame("Frame", nil, rail, "BackdropTemplate")
    standaloneBadge:SetHeight(20)
    standaloneBadge:SetPoint("BOTTOMLEFT", rail, "BOTTOMLEFT", 10, 158)
    standaloneBadge:SetPoint("BOTTOMRIGHT", rail, "BOTTOMRIGHT", -10, 158)
    self:ApplyBackdrop(standaloneBadge, cardBg, cardBd, 1)
    rail.StandaloneBadge = standaloneBadge

    local sbDot = standaloneBadge:CreateTexture(nil, "OVERLAY")
    sbDot:SetSize(6, 6)
    sbDot:SetPoint("LEFT", standaloneBadge, "LEFT", 8, 0)
    sbDot:SetColorTexture(0.133, 0.773, 0.369, 1.0)

    local sbLeft = standaloneBadge:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sbLeft:SetPoint("LEFT", sbDot, "RIGHT", 6, 0)
    sbLeft:SetJustifyH("LEFT")
    sbLeft:SetWordWrap(false)
    self:StyleFont(sbLeft, 9, "", COLORS.TextSilver)
    sbLeft:SetText("Standalone Mode")

    local sbRight = standaloneBadge:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sbRight:SetPoint("RIGHT", standaloneBadge, "RIGHT", -8, 0)
    sbRight:SetJustifyH("RIGHT")
    sbRight:SetWordWrap(false)
    self:StyleFont(sbRight, 9, "", COLORS.Green)
    sbRight:SetText("Ready")

    -- Bottom Section of Left Suite Rail: SUITE STUDIO & TOOLS (1:1 DynamicSuite_UI Compact Cards)
    local toolsHeader = rail:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    toolsHeader:SetPoint("BOTTOMLEFT", rail, "BOTTOMLEFT", 14, 138)
    self:StyleFont(toolsHeader, 10, "", { r = 0.62, g = 0.68, b = 0.76, a = 0.92 })
    toolsHeader:SetText("SUITE STUDIO & TOOLS")

    local studioCardItems = {
        {
            key = "THEME_STUDIO",
            label = "Theme & Font",
            sub = "Colours, Surface & Fonts",
            slash = "/dm",
            icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_palette.tga",
            yBottom = 102,
            fn = function()
                local openFn = (_G.DynamicSuite and _G.DynamicSuite.OpenWorkspaceView) or (_G.DynamicLoad and _G.DynamicLoad.OpenWorkspaceView)
                if openFn then
                    openFn("THEME_STUDIO")
                else
                    self:ShowStudioModal("THEME")
                end
            end,
        },
        {
            key = "GUIDED_SETUP",
            label = "Guided Setup",
            sub = "60s Setup & Conflict Check",
            icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_spark.tga",
            yBottom = 68,
            hasConflictBadge = true,
            fn = function() self:ShowStudioModal("SETUP") end,
        },
        {
            key = "EDIT_MODE",
            label = "Edit Mode (HUDs)",
            sub = "Drag Icon & Flare Bars",
            slash = "/dm hud",
            icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_grid.tga",
            yBottom = 34,
            fn = function() self:ToggleHudEditMode() end,
        },
    }

    rail.studioBtns = {}
    for _, sItem in ipairs(studioCardItems) do
        local sBtn = CreateFrame("Button", nil, rail, "BackdropTemplate")
        sBtn:SetHeight(31)
        sBtn:SetPoint("BOTTOMLEFT", rail, "BOTTOMLEFT", 10, sItem.yBottom)
        sBtn:SetPoint("BOTTOMRIGHT", rail, "BOTTOMRIGHT", -10, sItem.yBottom)
        sBtn.studioKey = sItem.key
        self:ApplyBackdrop(sBtn, cardBg, cardBd, 1)

        local iconTex = sBtn:CreateTexture(nil, "ARTWORK")
        iconTex:SetSize(14, 14)
        iconTex:SetPoint("LEFT", sBtn, "LEFT", 8, 0)
        iconTex:SetTexture(sItem.icon)
        iconTex:SetVertexColor(0.76, 0.80, 0.88, 0.98)
        sBtn.iconTex = iconTex

        local sTitle = sBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sTitle:SetPoint("TOPLEFT", sBtn, "TOPLEFT", 26, -4)
        sTitle:SetPoint("RIGHT", sBtn, "RIGHT", sItem.hasConflictBadge and -48 or -8, 0)
        sTitle:SetJustifyH("LEFT")
        sTitle:SetWordWrap(false)
        self:StyleFont(sTitle, 11, "", { r = 0.94, g = 0.96, b = 0.99, a = 1 })
        sTitle:SetText(sItem.label)
        sBtn.Title = sTitle

        local subRightOffset = -8
        if sItem.slash then
            subRightOffset = (#sItem.slash > 4) and -54 or -36
        end
        local sSub = sBtn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        sSub:SetPoint("BOTTOMLEFT", sBtn, "BOTTOMLEFT", 26, 3)
        sSub:SetPoint("RIGHT", sBtn, "RIGHT", subRightOffset, 0)
        sSub:SetJustifyH("LEFT")
        sSub:SetWordWrap(false)
        self:StyleFont(sSub, 9, "", { r = 0.62, g = 0.68, b = 0.76, a = 0.90 })
        sSub:SetText(sItem.sub)
        sBtn.Sub = sSub

        if sItem.slash then
            local sSlash = sBtn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            sSlash:SetPoint("BOTTOMRIGHT", sBtn, "BOTTOMRIGHT", -8, 3)
            self:StyleFont(sSlash, 9, "", { r = 0.52, g = 0.58, b = 0.66, a = 0.92 })
            sSlash:SetText(sItem.slash)
        end

        if sItem.hasConflictBadge then
            local okPip = sBtn:CreateTexture(nil, "OVERLAY")
            okPip:SetSize(6, 6)
            okPip:SetPoint("TOPRIGHT", sBtn, "TOPRIGHT", -10, -7)
            okPip:SetColorTexture(0.133, 0.773, 0.369, 1.0)
            okPip:Hide()
            sBtn.okPip = okPip

            local badgePill = CreateFrame("Frame", nil, sBtn, "BackdropTemplate")
            badgePill:SetSize(34, 14)
            badgePill:SetPoint("TOPRIGHT", sBtn, "TOPRIGHT", -8, -4)
            self:ApplyBackdrop(badgePill, { r = COLORS.Amber.r, g = COLORS.Amber.g, b = COLORS.Amber.b, a = 0.20 }, { r = COLORS.Amber.r, g = COLORS.Amber.g, b = COLORS.Amber.b, a = 0.75 }, 1)
            badgePill:Hide()

            local cBadge = badgePill:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            cBadge:SetPoint("CENTER", badgePill, "CENTER", 0, 0)
            self:StyleFont(cBadge, 9, "", COLORS.Amber)
            cBadge:SetText("! 1")
            sBtn.conflictBadge = cBadge
            sBtn.conflictPill = badgePill
        end

        sBtn:SetScript("OnEnter", function(s)
            local ar, ag, ab = self:GetAccentColor()
            self:ApplyBackdrop(s, cardHoverBg, { r = ar, g = ag, b = ab, a = 0.80 }, 1)
            if s.iconTex then s.iconTex:SetVertexColor(ar, ag, ab, 1.0) end
        end)
        sBtn:SetScript("OnLeave", function(s)
            local curSurf = GetStandaloneSurfaceColors(self)
            local curCardBg = { r = curSurf.card.r, g = curSurf.card.g, b = curSurf.card.b, a = 0.96 }
            local isActiveEdit = (s.studioKey == "EDIT_MODE" and self.isEditMode)
            if isActiveEdit then
                local ar, ag, ab = self:GetAccentColor()
                self:ApplyBackdrop(s, { r = ar * 0.18, g = ag * 0.18, b = ab * 0.18, a = 0.96 }, { r = ar, g = ag, b = ab, a = 0.90 }, 1)
                if s.iconTex then s.iconTex:SetVertexColor(ar, ag, ab, 1.0) end
            else
                self:ApplyBackdrop(s, curCardBg, cardBd, 1)
                if s.iconTex then s.iconTex:SetVertexColor(0.76, 0.80, 0.88, 0.98) end
            end
        end)
        sBtn:SetScript("OnClick", sItem.fn)
        table.insert(rail.studioBtns, sBtn)
    end

    -- Bottom Utility Row in Left Rail: [Changelog] (90px) + [Support] (88px)
    local function CreateRailUtilBtn(labelText, btnWidth, iconFile, iconPadLeft, anchorPt, xOff, onClick)
        local uBtn = CreateFrame("Button", nil, rail, "BackdropTemplate")
        uBtn:SetSize(btnWidth, 22)
        uBtn:SetPoint(anchorPt, rail, anchorPt, xOff, 7)
        self:ApplyBackdrop(uBtn, cardBg, cardBd, 1)

        local uIcon = uBtn:CreateTexture(nil, "OVERLAY")
        uIcon:SetSize(12, 12)
        uIcon:SetPoint("LEFT", uBtn, "LEFT", iconPadLeft, 0)
        uIcon:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\" .. iconFile)
        uIcon:SetVertexColor(0.76, 0.80, 0.88, 0.98)
        uBtn.iconTex = uIcon

        local uLbl = uBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        uLbl:SetPoint("LEFT", uIcon, "RIGHT", 4, 0)
        uLbl:SetPoint("RIGHT", uBtn, "RIGHT", -4, 0)
        uLbl:SetJustifyH("CENTER")
        uLbl:SetWordWrap(false)
        self:StyleFont(uLbl, 10, "", { r = 0.88, g = 0.91, b = 0.96, a = 1 })
        uLbl:SetText(labelText)
        uBtn.Text = uLbl

        uBtn:SetScript("OnEnter", function(s)
            local ar, ag, ab = self:GetAccentColor()
            self:ApplyBackdrop(s, cardHoverBg, { r = ar, g = ag, b = ab, a = 0.75 }, 1)
            if s.iconTex then s.iconTex:SetVertexColor(ar, ag, ab, 1.0) end
            if s.Text then s.Text:SetTextColor(1, 1, 1, 1) end
        end)
        uBtn:SetScript("OnLeave", function(s)
            local curSurf = GetStandaloneSurfaceColors(self)
            local curCardBg = { r = curSurf.card.r, g = curSurf.card.g, b = curSurf.card.b, a = 0.96 }
            self:ApplyBackdrop(s, curCardBg, cardBd, 1)
            if s.iconTex then s.iconTex:SetVertexColor(0.76, 0.80, 0.88, 0.98) end
            if s.Text then s.Text:SetTextColor(0.88, 0.91, 0.96, 1) end
        end)
        uBtn:SetScript("OnClick", onClick)
        return uBtn
    end

    rail.utilBtns = {
        CreateRailUtilBtn("Changelog", 90, "icon_changelog.tga", 6,  "BOTTOMLEFT",  10,  function() self:ShowStudioModal("CHANGELOG") end),
        CreateRailUtilBtn("Support",   88, "icon_support.tga",   10, "BOTTOMRIGHT", -10, function() self:ShowStudioModal("SUPPORT") end),
    }

    local resetBtn = CreateFrame("Button", nil, footer, "BackdropTemplate")
    resetBtn:SetSize(182, 24)
    resetBtn:SetPoint("LEFT", footer, "LEFT", 14, 0)
    self:ApplyBackdrop(resetBtn, cardBg, cardBd, 1)
    resetBtn.Text = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resetBtn.Text:SetPoint("CENTER")
    resetBtn.Text:SetWordWrap(false)
    self:StyleFont(resetBtn.Text, 11, "", { r = 0.88, g = 0.91, b = 0.96, a = 1 })
    resetBtn.Text:SetText("Reset DynamicMarker")
    function resetBtn:SetLabel(txt) self.Text:SetText(txt) end
    resetBtn:SetScript("OnEnter", function(s)
        local ar, ag, ab = self:GetAccentColor()
        self:ApplyBackdrop(s, cardHoverBg, { r = ar, g = ag, b = ab, a = 0.70 }, 1)
        s.Text:SetTextColor(1, 1, 1, 1)
    end)
    resetBtn:SetScript("OnLeave", function(s)
        local curSurf = GetStandaloneSurfaceColors(self)
        local curCardBg = { r = curSurf.card.r, g = curSurf.card.g, b = curSurf.card.b, a = 0.96 }
        self:ApplyBackdrop(s, curCardBg, cardBd, 1)
        s.Text:SetTextColor(0.88, 0.91, 0.96, 1)
    end)
    resetBtn:SetScript("OnClick", function(s)
        if IsAltKeyDown() then
            self:ResetDefaults()
            return
        end
        if s.confirmPending then
            s.confirmPending = false
            s:SetLabel("Reset DynamicMarker")
            self:ResetDefaults()
        else
            s.confirmPending = true
            s:SetLabel("|cFFFF4444Click again to confirm|r")
            C_Timer.After(3.0, function()
                if s.confirmPending then
                    s.confirmPending = false
                    s:SetLabel("Reset DynamicMarker")
                end
            end)
        end
    end)
    f.ResetBtn = resetBtn

    -- Bottom-Right Dock Controls: [Opacity Slider] + [Scale Slider 100%] + [Reload UI] (left of // resize grip)
    local savedScale = tonumber(self.db and self.db.standaloneWindowScale) or 1.0
    savedScale = math.max(0.80, math.min(1.20, math.floor((savedScale * 20) + 0.5) / 20))
    f:SetScale(savedScale)

    local savedAlpha = tonumber(self.db and self.db.standaloneWindowAlpha) or 0.98
    savedAlpha = math.max(0.50, math.min(1.00, savedAlpha))
    f:SetAlpha(savedAlpha)

    local reloadUIBtn = CreateFrame("Button", nil, footer, "BackdropTemplate")
    reloadUIBtn:SetSize(78, 24)
    reloadUIBtn:SetPoint("RIGHT", footer, "RIGHT", -32, 0)
    self:ApplyBackdrop(reloadUIBtn, cardBg, cardBd, 1)
    reloadUIBtn.Text = reloadUIBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    reloadUIBtn.Text:SetPoint("CENTER")
    reloadUIBtn.Text:SetWordWrap(false)
    self:StyleFont(reloadUIBtn.Text, 11, "", { r = 0.88, g = 0.91, b = 0.96, a = 1 })
    reloadUIBtn.Text:SetText("Reload UI")
    reloadUIBtn:SetScript("OnEnter", function(s)
        local ar, ag, ab = self:GetAccentColor()
        self:ApplyBackdrop(s, cardHoverBg, { r = ar, g = ag, b = ab, a = 0.70 }, 1)
        s.Text:SetTextColor(1, 1, 1, 1)
    end)
    reloadUIBtn:SetScript("OnLeave", function(s)
        local curSurf = GetStandaloneSurfaceColors(self)
        local curCardBg = { r = curSurf.card.r, g = curSurf.card.g, b = curSurf.card.b, a = 0.96 }
        self:ApplyBackdrop(s, curCardBg, cardBd, 1)
        s.Text:SetTextColor(0.88, 0.91, 0.96, 1)
    end)
    reloadUIBtn:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION or 856)
        ReloadUI()
    end)
    f.ReloadUIBtn = reloadUIBtn

    local SCALE_MIN, SCALE_MAX, SCALE_STEP, SCALE_W = 0.80, 1.20, 0.05, 64
    local scaleValText = footer:CreateFontString(nil, "OVERLAY")
    scaleValText:SetPoint("RIGHT", reloadUIBtn, "LEFT", -16, 0)
    scaleValText:SetWidth(38)
    scaleValText:SetJustifyH("LEFT")
    self:StyleFont(scaleValText, 10, "", { r = 1, g = 1, b = 1, a = 0.85 })

    local scaleHit = CreateFrame("Frame", nil, footer)
    scaleHit:SetSize(SCALE_W + 8, 20)
    scaleHit:SetPoint("RIGHT", scaleValText, "LEFT", -8, 0)
    scaleHit:EnableMouse(true)
    scaleHit:EnableMouseWheel(true)

    local scaleTrack = scaleHit:CreateTexture(nil, "ARTWORK", nil, 1)
    scaleTrack:SetSize(SCALE_W, 4)
    scaleTrack:SetPoint("CENTER", scaleHit, "CENTER", 0, 0)
    scaleTrack:SetColorTexture(0.035, 0.039, 0.051, 0.98)

    local scaleFill = scaleHit:CreateTexture(nil, "ARTWORK", nil, 2)
    scaleFill:SetPoint("TOPLEFT", scaleTrack, "TOPLEFT", 0, 0)
    scaleFill:SetPoint("BOTTOMLEFT", scaleTrack, "BOTTOMLEFT", 0, 0)
    scaleFill:SetWidth(1)
    scaleFill:SetColorTexture(initR, initG, initB, 0.85)
    f.ScaleFill = scaleFill

    local scaleThumb = scaleHit:CreateTexture(nil, "OVERLAY", nil, 4)
    scaleThumb:SetSize(6, 14)
    scaleThumb:SetColorTexture(0.97, 0.98, 1.00, 1.0)
    if scaleThumb.SetSnapToPixelGrid then
        scaleThumb:SetSnapToPixelGrid(false)
        scaleThumb:SetTexelSnappingBias(0)
    end

    local scaleLbl = footer:CreateFontString(nil, "OVERLAY")
    scaleLbl:SetPoint("RIGHT", scaleHit, "LEFT", -4, 0)
    self:StyleFont(scaleLbl, 10, "", { r = 0.58, g = 0.64, b = 0.72, a = 0.85 })
    scaleLbl:SetText("Scale")

    local pendingScale = savedScale

    local function UpdateScaleVisual(val)
        val = math.max(SCALE_MIN, math.min(SCALE_MAX, val or 1.0))
        local pct = (val - SCALE_MIN) / (SCALE_MAX - SCALE_MIN)
        local xOff = pct * SCALE_W
        scaleFill:SetWidth(math.max(1, xOff))
        scaleThumb:ClearAllPoints()
        scaleThumb:SetPoint("CENTER", scaleTrack, "LEFT", xOff, 0)
        scaleValText:SetText(string.format("%d%%", math.floor(val * 100 + 0.5)))
    end
    UpdateScaleVisual(savedScale)

    local function CommitWindowScale(val)
        val = math.floor((val or 1.0) * 20 + 0.5) / 20
        val = math.max(SCALE_MIN, math.min(SCALE_MAX, val))
        pendingScale = val
        UpdateScaleVisual(val)
        if self.db then self.db.standaloneWindowScale = val end
        local oldScale = f:GetScale() or 1.0
        if math.abs(val - oldScale) >= 0.0005 then
            local cx, cy = f:GetCenter()
            f:SetScale(val)
            if cx and cy then
                local ratio = oldScale / val
                f:ClearAllPoints()
                f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx * ratio, cy * ratio)
            end
        end
    end

    scaleHit:SetScript("OnMouseDown", function(s, button)
        if button == "LeftButton" then
            s:SetScript("OnUpdate", function(up)
                if not IsMouseButtonDown("LeftButton") then
                    up:SetScript("OnUpdate", nil)
                    CommitWindowScale(pendingScale)
                    return
                end
                local eff = scaleTrack:GetEffectiveScale()
                local cx = GetCursorPosition() / eff
                local left = scaleTrack:GetLeft()
                if left then
                    local pct = math.max(0, math.min(1, (cx - left) / SCALE_W))
                    local raw = SCALE_MIN + pct * (SCALE_MAX - SCALE_MIN)
                    local snapped = math.floor(raw * 20 + 0.5) / 20
                    snapped = math.max(SCALE_MIN, math.min(SCALE_MAX, snapped))
                    if math.abs(snapped - pendingScale) >= 0.001 then
                        pendingScale = snapped
                        UpdateScaleVisual(pendingScale)
                    end
                end
            end)
        elseif button == "RightButton" then
            CommitWindowScale(1.0)
        end
    end)
    scaleHit:SetScript("OnMouseUp", function(s, button)
        if button == "LeftButton" then
            s:SetScript("OnUpdate", nil)
            CommitWindowScale(pendingScale)
        end
    end)
    scaleHit:SetScript("OnHide", function(s) s:SetScript("OnUpdate", nil) end)
    scaleHit:SetScript("OnMouseWheel", function(_, delta)
        CommitWindowScale(pendingScale + (delta > 0 and SCALE_STEP or -SCALE_STEP))
    end)

    local OPA_MIN, OPA_MAX, OPA_W = 0.50, 1.00, 64
    local opaHit = CreateFrame("Frame", nil, footer)
    opaHit:SetSize(OPA_W + 8, 20)
    opaHit:SetPoint("RIGHT", scaleLbl, "LEFT", -12, 0)
    opaHit:EnableMouse(true)
    opaHit:EnableMouseWheel(true)

    local opaTrack = opaHit:CreateTexture(nil, "ARTWORK", nil, 1)
    opaTrack:SetSize(OPA_W, 4)
    opaTrack:SetPoint("CENTER", opaHit, "CENTER", 0, 0)
    opaTrack:SetColorTexture(0.035, 0.039, 0.051, 0.98)

    local opaFill = opaHit:CreateTexture(nil, "ARTWORK", nil, 2)
    opaFill:SetPoint("TOPLEFT", opaTrack, "TOPLEFT", 0, 0)
    opaFill:SetPoint("BOTTOMLEFT", opaTrack, "BOTTOMLEFT", 0, 0)
    opaFill:SetWidth(1)
    opaFill:SetColorTexture(initR, initG, initB, 0.85)
    f.OpaFill = opaFill

    local opaThumb = opaHit:CreateTexture(nil, "OVERLAY", nil, 4)
    opaThumb:SetSize(6, 14)
    opaThumb:SetColorTexture(0.97, 0.98, 1.00, 1.0)
    if opaThumb.SetSnapToPixelGrid then
        opaThumb:SetSnapToPixelGrid(false)
        opaThumb:SetTexelSnappingBias(0)
    end

    local opaLabel = footer:CreateFontString(nil, "OVERLAY")
    opaLabel:SetPoint("RIGHT", opaHit, "LEFT", -4, 0)
    self:StyleFont(opaLabel, 10, "", { r = 0.58, g = 0.64, b = 0.72, a = 0.85 })
    opaLabel:SetText("Opacity")

    local function ApplyWindowOpacity(val)
        val = math.max(OPA_MIN, math.min(OPA_MAX, val or 0.98))
        f:SetAlpha(val)
        if self.db then self.db.standaloneWindowAlpha = val end
        local pct = (val - OPA_MIN) / (OPA_MAX - OPA_MIN)
        local xOff = pct * OPA_W
        opaFill:SetWidth(math.max(1, xOff))
        opaThumb:ClearAllPoints()
        opaThumb:SetPoint("CENTER", opaTrack, "LEFT", xOff, 0)
    end
    ApplyWindowOpacity(savedAlpha)

    opaHit:SetScript("OnMouseDown", function(s, button)
        if button == "LeftButton" then
            s:SetScript("OnUpdate", function(up)
                if not IsMouseButtonDown("LeftButton") then
                    up:SetScript("OnUpdate", nil)
                    return
                end
                local eff = opaTrack:GetEffectiveScale()
                local cx = GetCursorPosition() / eff
                local left = opaTrack:GetLeft()
                if left then
                    local pct = math.max(0, math.min(1, (cx - left) / OPA_W))
                    local raw = OPA_MIN + pct * (OPA_MAX - OPA_MIN)
                    local snapped = math.floor(raw * 50 + 0.5) / 50
                    if math.abs(snapped - (up._lastOpa or -1)) >= 0.001 then
                        up._lastOpa = snapped
                        ApplyWindowOpacity(snapped)
                    end
                end
            end)
        elseif button == "RightButton" then
            ApplyWindowOpacity(0.98)
        end
    end)
    opaHit:SetScript("OnMouseUp", function(s) s:SetScript("OnUpdate", nil) end)
    opaHit:SetScript("OnHide", function(s) s:SetScript("OnUpdate", nil) end)
    opaHit:SetScript("OnMouseWheel", function(_, delta)
        local cur = (self.db and self.db.standaloneWindowAlpha) or 0.98
        ApplyWindowOpacity(cur + (delta > 0 and 0.05 or -0.05))
    end)

    -- Zero-FPS-Drop Bottom-Right Resize Grip
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    grip:SetFrameLevel(footer:GetFrameLevel() + 4)

    local gripTex = grip:CreateTexture(nil, "OVERLAY", nil, 5)
    gripTex:SetAllPoints()
    gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    gripTex:SetDesaturated(true)
    gripTex:SetVertexColor(0.55, 0.58, 0.65, 0.75)

    grip:SetScript("OnEnter", function()
        gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        gripTex:SetDesaturated(false)
        gripTex:SetVertexColor(0.976, 0.451, 0.086, 0.95)
    end)
    grip:SetScript("OnLeave", function()
        gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        gripTex:SetDesaturated(true)
        gripTex:SetVertexColor(0.55, 0.58, 0.65, 0.75)
    end)

    grip:SetScript("OnMouseDown", function(_, mBtn)
        if mBtn == "LeftButton" then
            f:StartSizing("BOTTOMRIGHT")
        end
    end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        winCfg.width  = math.floor(f:GetWidth() + 0.5)
        winCfg.height = math.floor(f:GetHeight() + 0.5)
    end)

    -- ------------------------------------------------------------------------
    -- Right Content Canvas (Two-Point C++ Anchored to Stretch on Resize)
    -- ------------------------------------------------------------------------
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", header, "BOTTOMRIGHT", 0, 0)
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", rail, "TOPRIGHT", 0, 0)
    content:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
    f.Content = content

    self.shellFrame = f

    -- Publish shared shell references onto _G.DynamicSuite if not already owned
    if not Suite.mainFrame then
        Suite.mainFrame = f
        Suite.contentFrame = content
    end
    if not Suite.MainFrame then
        Suite.MainFrame = f
    end

    self:BuildWorkspace(content)
    return f
end

function DM:SelectActiveModuleInShell(modKey, externalMod)
    self:CloseDropdownMenu()
    self:CloseStudioModal()
    local f = self:EnsureStandaloneShell()
    for _, child in ipairs({ f.Content:GetChildren() }) do
        child:Hide()
    end

    if modKey == "marker" or not externalMod then
        local _, _, _, accentHex = self:GetAccentColor()
        f.Header.ModTitle:SetText(string.format("|cFF%sDynamic|r|cFFFFFFFFMarker|r", accentHex))
        f.Header.VerBtn:SetLabel("v" .. self.version)
        f.StatusText:SetText(self:GetStatusText())
        self:BuildWorkspace(f.Content)
    else
        local renderFn = externalMod.Render or externalMod.BuildUI or externalMod.Build or externalMod.CreatePanel or externalMod.Show
        if type(renderFn) == "function" then
            local _, _, _, accentHex = self:GetAccentColor()
            f.Header.ModTitle:SetText(string.format("|cFF%sDynamic|r|cFFFFFFFFMarker|r", accentHex))
            f.Header.VerBtn:SetLabel("v" .. (externalMod.version or VERSION))
            if externalMod.GetStatusText then
                f.StatusText:SetText(externalMod:GetStatusText())
            elseif externalMod.statusText then
                f.StatusText:SetText(externalMod.statusText)
            end
            pcall(renderFn, externalMod, f.Content)
        elseif type(externalMod.ToggleUI) == "function" then
            f:Hide()
            pcall(externalMod.ToggleUI, true)
        elseif type(externalMod.Open) == "function" then
            f:Hide()
            pcall(externalMod.Open, externalMod)
        end
    end
end

-- ============================================================================
-- 17. REFRESH & EXTERNAL _G.DYNAMICSUITE HOST SYNCHRONIZATION
-- ============================================================================

function DM:RefreshAll()
    if not self.db then return end

    local statusStr = self:GetStatusText()
    if self.moduleEntry then
        self.moduleEntry.statusText = statusStr
        self.moduleEntry.status = statusStr
    end

    if self.workspaceFrame then
        local ws = self.workspaceFrame
        local ar, ag, ab = self:GetAccentColor()
        local activeTab = self.db.activeSubTab or 1

        -- Update Sub-Tab 2 Dynamic Keybind Label (Clean Typography without icons)
        if ws.subTabBtns and ws.subTabBtns[2] and ws.subTabBtns[2].Text then
            ws.subTabBtns[2].Text:SetText(self:GetSubTab2Title())
            if ws.ReflowSubTabBar then ws.ReflowSubTabBar() end
        end
        if ws.subTabBtns then
            for i, tBtn in ipairs(ws.subTabBtns) do
                if i == activeTab then
                    self:ApplyBackdrop(tBtn, { r = ar * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), g = ag * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), b = ab * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), a = 0.98 }, { r = ar, g = ag, b = ab, a = 0.95 }, 1)
                    self:StyleFont(tBtn.Text, 12, "", { r = 1, g = 1, b = 1, a = 1 })
                    if tBtn.BottomBar then
                        tBtn.BottomBar:SetColorTexture(ar, ag, ab, 1.0)
                        tBtn.BottomBar:Show()
                    end
                else
                    self:ApplyBackdrop(tBtn, { r = 0.063, g = 0.075, b = 0.102, a = 0.96 }, { r = 0.145, g = 0.165, b = 0.212, a = 0.95 }, 1)
                    self:StyleFont(tBtn.Text, 12, "", { r = 0.68, g = 0.74, b = 0.82, a = 1 })
                    if tBtn.BottomBar then
                        tBtn.BottomBar:Hide()
                    end
                end
            end
        end

        -- Update Conflict Banner Visibility & Position
        local hostedInSuite = (_G.DynamicSuite and _G.DynamicSuite.HasUnifiedModuleConflictBanner and _G.DynamicSuiteMainFrame and ws:GetParent() ~= UIParent)
        local conflicts = hostedInSuite and {} or self:ScanConflicts()
        local advisories = hostedInSuite and {} or self:ScanAdvisoryConflicts()
        if not hostedInSuite and (#conflicts > 0 or #advisories > 0 or self.pendingConflictReload) and ws.conflictBanner then
            local cName = (conflicts[1] and conflicts[1].name) or (advisories[1] and advisories[1].name) or self.pendingConflictReload or "FocusMarker"
            ws.conflictBanner:Show()
            if self.pendingConflictReload then
                ws.conflictBanner._mode = "RELOAD"
                ws.conflictBanner._addonName = self.pendingConflictReload
                self:ApplyBackdrop(ws.conflictBanner, { r = 0.035, g = 0.075, b = 0.055, a = 0.96 }, COLORS.Green, 1)
                self:StyleFont(ws.conflictBanner.Title, 12, "", COLORS.Green)
                if self.pendingConflictReload == "DecorVendor" then
                    ws.conflictBanner.Title:SetText(READY_CHECK_TEX .. " DecorVendor Disabled (Set to Never) - Exit & Restart Required")
                    ws.conflictBanner.Sub:SetText("Please completely Exit & Restart World of Warcraft now (/reload alone will not clear SetRaidTarget taint).")
                    ws.conflictBanner.Title:ClearAllPoints()
                    ws.conflictBanner.Title:SetPoint("TOPLEFT", ws.conflictBanner, "TOPLEFT", 14, -10)
                    ws.conflictBanner.Title:SetPoint("RIGHT", ws.conflictBanner, "RIGHT", -14, 0)
                    ws.conflictBanner.Sub:ClearAllPoints()
                    ws.conflictBanner.Sub:SetPoint("TOPLEFT", ws.conflictBanner.Title, "BOTTOMLEFT", 0, -4)
                    ws.conflictBanner.Sub:SetPoint("RIGHT", ws.conflictBanner, "RIGHT", -14, 0)
                    ws.conflictBanner.BtnUseDynamic:Hide()
                    ws.conflictBanner.BtnKeepOther:Hide()
                    ws.conflictBanner.BtnReload:Hide()
                else
                    ws.conflictBanner.Title:SetText(READY_CHECK_TEX .. " Conflict Resolution Staged for " .. cName)
                    ws.conflictBanner.Sub:SetText("Settings imported and " .. cName .. " is locked off across all zone profiles. Click [Reload UI] to finish.")
                    ws.conflictBanner.Title:ClearAllPoints()
                    ws.conflictBanner.Title:SetPoint("TOPLEFT", ws.conflictBanner, "TOPLEFT", 14, -10)
                    ws.conflictBanner.Title:SetPoint("RIGHT", ws.conflictBanner.BtnReload, "LEFT", -16, 0)
                    ws.conflictBanner.Sub:ClearAllPoints()
                    ws.conflictBanner.Sub:SetPoint("TOPLEFT", ws.conflictBanner.Title, "BOTTOMLEFT", 0, -4)
                    ws.conflictBanner.Sub:SetPoint("RIGHT", ws.conflictBanner.BtnReload, "LEFT", -16, 0)
                    ws.conflictBanner.BtnUseDynamic:Hide()
                    ws.conflictBanner.BtnKeepOther:Hide()
                    ws.conflictBanner.BtnReload:Show()
                end
            elseif #conflicts > 0 then
                ws.conflictBanner._mode = "HARD"
                ws.conflictBanner._addonName = cName
                self:ApplyBackdrop(ws.conflictBanner, { r = 0.20, g = 0.14, b = 0.05, a = 0.96 }, COLORS.Amber, 1)
                self:StyleFont(ws.conflictBanner.Title, 12, "", COLORS.Amber)
                local isDV = (cName == "DecorVendor")
                ws.conflictBanner.BtnKeepOther:SetWidth(isDV and 148 or 145)
                ws.conflictBanner.BtnUseDynamic:SetWidth(isDV and 216 or 195)
                ws.conflictBanner.Title:ClearAllPoints()
                ws.conflictBanner.Title:SetPoint("TOPLEFT", ws.conflictBanner, "TOPLEFT", 14, -10)
                ws.conflictBanner.Title:SetPoint("RIGHT", ws.conflictBanner.BtnUseDynamic, "LEFT", -16, 0)
                ws.conflictBanner.Sub:ClearAllPoints()
                ws.conflictBanner.Sub:SetPoint("TOPLEFT", ws.conflictBanner.Title, "BOTTOMLEFT", 0, -4)
                ws.conflictBanner.Sub:SetPoint("RIGHT", ws.conflictBanner.BtnUseDynamic, "LEFT", -16, 0)
                if isDV then
                    ws.conflictBanner.Title:SetText("Raid Marker Blocked: Decor Vendor taints Blizzard's /tm command (SetRaidTarget).")
                    ws.conflictBanner.Sub:SetText("Disable DecorVendor (Set to Never) and completely Exit & Restart World of Warcraft (/reload will not clear it).")
                    ws.conflictBanner.BtnUseDynamic:SetLabel("Disable DecorVendor (Never)")
                else
                    ws.conflictBanner.Title:SetText("Conflict Detected: " .. cName .. " is currently active and may cause UI errors or blocked actions.")
                    ws.conflictBanner.Sub:SetText("Running duplicate marker addons causes macro and raid icon collisions. Choose 1-click resolution:")
                    ws.conflictBanner.BtnUseDynamic:SetLabel(cName == "FocusMarker"
                        and "Import & Use DynamicMarker"
                        or ("Use DynamicMarker"))
                end
                ws.conflictBanner.BtnKeepOther:SetLabel("Keep " .. cName)
                ws.conflictBanner.BtnUseDynamic:Show()
                ws.conflictBanner.BtnKeepOther:Show()
                ws.conflictBanner.BtnReload:Hide()
            else
                local adv = advisories[1]
                local advName = adv.name
                ws.conflictBanner._mode = "ADVISORY"
                ws.conflictBanner._addonName = advName
                self:ApplyBackdrop(ws.conflictBanner, COLORS.BgVoid, COLORS.Cyan, 1)
                self:StyleFont(ws.conflictBanner.Title, 12, "", COLORS.Cyan)
                ws.conflictBanner.BtnKeepOther:SetWidth(94)
                ws.conflictBanner.BtnUseDynamic:SetWidth(168)
                ws.conflictBanner.Title:ClearAllPoints()
                ws.conflictBanner.Title:SetPoint("TOPLEFT", ws.conflictBanner, "TOPLEFT", 14, -10)
                ws.conflictBanner.Title:SetPoint("RIGHT", ws.conflictBanner.BtnUseDynamic, "LEFT", -16, 0)
                ws.conflictBanner.Sub:ClearAllPoints()
                ws.conflictBanner.Sub:SetPoint("TOPLEFT", ws.conflictBanner.Title, "BOTTOMLEFT", 0, -4)
                ws.conflictBanner.Sub:SetPoint("RIGHT", ws.conflictBanner.BtnUseDynamic, "LEFT", -16, 0)
                ws.conflictBanner.Title:SetText("Compatibility Notice: " .. (adv.label or advName) .. " (" .. advName .. ") is active")
                ws.conflictBanner.Sub:SetText("DecorVendor can taint Blizzard's /tm raid marker command in dungeons and raids (not a DynamicMarker bug).")
                ws.conflictBanner.BtnUseDynamic:SetLabel("Disable " .. advName)
                ws.conflictBanner.BtnKeepOther:SetLabel("Dismiss")
                ws.conflictBanner.BtnUseDynamic:Show()
                ws.conflictBanner.BtnKeepOther:Show()
                ws.conflictBanner.BtnReload:Hide()
            end
            ws.tabBar:ClearAllPoints()
            ws.tabBar:SetPoint("TOPLEFT", ws.conflictBanner, "BOTTOMLEFT", 0, -8)
            ws.tabBar:SetPoint("TOPRIGHT", ws.conflictBanner, "BOTTOMRIGHT", 0, -8)
        elseif ws.conflictBanner then
            ws.conflictBanner:Hide()
            ws.tabBar:ClearAllPoints()
            ws.tabBar:SetPoint("TOPLEFT", ws, "TOPLEFT", 14, -10)
            ws.tabBar:SetPoint("TOPRIGHT", ws, "TOPRIGHT", -16, -10)
        end

        if self.sectionHeaders then
            for _, hdr in ipairs(self.sectionHeaders) do
                if hdr and hdr.RefreshAccent then pcall(hdr.RefreshAccent, hdr) end
            end
        end
        self:RefreshHudEditToggleButtons()

        if self.refreshables then
            for _, fn in ipairs(self.refreshables) do
                pcall(fn)
            end
        end
    end

    if self.shellFrame and self.shellFrame:IsShown() then
        self.shellFrame.StatusText:SetText(statusStr)
        local ar, ag, ab, accentHex = self:GetAccentColor()
        local surf = GetStandaloneSurfaceColors(self)
        local cardBg = { r = surf.card.r, g = surf.card.g, b = surf.card.b, a = 0.96 }
        local cardBd = { r = 0.175, g = 0.200, b = 0.258, a = 0.95 }
        self:ApplyBackdrop(self.shellFrame, surf.panel, COLORS.BorderStrong, 1)
        if self.shellFrame.Header then
            self:ApplyBackdrop(self.shellFrame.Header, { r = surf.header.r, g = surf.header.g, b = surf.header.b, a = 1.0 }, { r = 0, g = 0, b = 0, a = 0 }, 0)
            if self.shellFrame.Header.AccentTop then
                self.shellFrame.Header.AccentTop:SetColorTexture(ar, ag, ab, 1.0)
            end
            if self.shellFrame.Header.LogoAccent then
                self.shellFrame.Header.LogoAccent:SetVertexColor(ar, ag, ab, 1.0)
            end
            if self.shellFrame.Header.ModTitle then
                self.shellFrame.Header.ModTitle:SetText(string.format("|cFF%sDynamic|r|cFFFFFFFFMarker|r", accentHex))
            end
        end
        if self.shellFrame.Footer then
            self:ApplyBackdrop(self.shellFrame.Footer, { r = surf.header.r, g = surf.header.g, b = surf.header.b, a = 1.0 }, { r = 0, g = 0, b = 0, a = 0 }, 0)
        end
        if self.shellFrame.Rail then
            self:ApplyBackdrop(self.shellFrame.Rail, surf.rail, { r = 0, g = 0, b = 0, a = 0 }, 0)
            if self.shellFrame.Rail.StandaloneBadge then
                self:ApplyBackdrop(self.shellFrame.Rail.StandaloneBadge, cardBg, cardBd, 1)
            end
            if self.shellFrame.Rail.utilBtns then
                for _, uBtn in ipairs(self.shellFrame.Rail.utilBtns) do
                    self:ApplyBackdrop(uBtn, cardBg, cardBd, 1)
                end
            end
        end
        if self.shellFrame.ResetBtn then
            self:ApplyBackdrop(self.shellFrame.ResetBtn, cardBg, cardBd, 1)
        end
        if self.shellFrame.ReloadUIBtn then
            self:ApplyBackdrop(self.shellFrame.ReloadUIBtn, cardBg, cardBd, 1)
        end
        if self.shellFrame.ScaleFill then
            self.shellFrame.ScaleFill:SetColorTexture(ar, ag, ab, 0.85)
        end
        if self.shellFrame.OpaFill then
            self.shellFrame.OpaFill:SetColorTexture(ar, ag, ab, 0.85)
        end
        for _, mBtn in ipairs(self.shellFrame.Rail.modBtns) do
            local isMarker = (mBtn.modKey == "marker" or mBtn.Title:GetText() == "DynamicMarker")
            if isMarker then
                self:ApplyBackdrop(mBtn, { r = ar * 0.16, g = ag * 0.16, b = ab * 0.16, a = 0.96 }, { r = ar, g = ag, b = ab, a = 0.85 })
                if mBtn.LeftBar then
                    mBtn.LeftBar:SetColorTexture(ar, ag, ab, 1.0)
                    mBtn.LeftBar:Show()
                end
                if mBtn.Icon then
                    mBtn.Icon:SetVertexColor(ar, ag, ab, 1.0)
                end
            else
                self:ApplyBackdrop(mBtn, COLORS.BgSurface, COLORS.BorderDim)
                if mBtn.LeftBar then mBtn.LeftBar:Hide() end
                if mBtn.Icon then mBtn.Icon:SetVertexColor(0.72, 0.76, 0.84, 0.95) end
            end
        end
        if self.shellFrame.Rail and self.shellFrame.Rail.studioBtns then
            local conflicts = self:ScanConflicts()
            local advisories = self:ScanAdvisoryConflicts()
            local totalNotices = #conflicts + #advisories
            for _, sBtn in ipairs(self.shellFrame.Rail.studioBtns) do
                if sBtn.studioKey == "GUIDED_SETUP" and sBtn.okPip and sBtn.conflictPill then
                    self:ApplyBackdrop(sBtn, cardBg, cardBd, 1)
                    if totalNotices > 0 then
                        sBtn.okPip:Hide()
                        sBtn.conflictBadge:SetText("! " .. tostring(totalNotices))
                        sBtn.conflictPill:Show()
                    else
                        sBtn.conflictPill:Hide()
                        sBtn.okPip:Hide()
                    end
                elseif sBtn.studioKey == "EDIT_MODE" then
                    if self.isEditMode then
                        self:ApplyBackdrop(sBtn, { r = ar * 0.18, g = ag * 0.18, b = ab * 0.18, a = 0.96 }, { r = ar, g = ag, b = ab, a = 0.90 }, 1)
                        if sBtn.iconTex then sBtn.iconTex:SetVertexColor(ar, ag, ab, 1.0) end
                    else
                        self:ApplyBackdrop(sBtn, cardBg, cardBd, 1)
                        if sBtn.iconTex then sBtn.iconTex:SetVertexColor(0.76, 0.80, 0.88, 0.98) end
                    end
                else
                    self:ApplyBackdrop(sBtn, cardBg, cardBd, 1)
                end
            end
        end
    end

    -- Synchronise standalone status pill, Sub-Tab 2 label, and _G.DynamicSuite top header telemetry bar
    self:RefreshKeybindTelemetryAndTabTitle()
end

function DM:OpenWindow(subTabIndex)
    if subTabIndex and self.db then
        self.db.activeSubTab = subTabIndex
    end

    local extMain = Suite.mainFrame or Suite.MainFrame
    -- Route through _G.DynamicSuite:OpenModule("DynamicMarker") when available
    if type(Suite.OpenModule) == "function" and (not self.shellFrame or extMain ~= self.shellFrame) then
        local ok = pcall(Suite.OpenModule, Suite, "DynamicMarker")
        if not ok then
            ok = pcall(Suite.OpenModule, Suite, "marker")
        end
        if ok and (Suite.mainFrame or Suite.MainFrame) and (Suite.mainFrame ~= self.shellFrame) then
            if subTabIndex and self.SelectSubTab then self:SelectSubTab(subTabIndex) end
            return
        end
    elseif Suite.SelectModule and extMain and extMain ~= self.shellFrame then
        local ok = pcall(Suite.SelectModule, Suite, "marker")
        if ok then
            if extMain.Show then extMain:Show() end
            if subTabIndex and self.SelectSubTab then self:SelectSubTab(subTabIndex) end
            return
        end
    elseif Suite.OpenSuiteWindow and extMain and extMain ~= self.shellFrame then
        local ok = pcall(Suite.OpenSuiteWindow, Suite, "marker")
        if ok then
            if subTabIndex and self.SelectSubTab then self:SelectSubTab(subTabIndex) end
            return
        end
    end

    local f = self:EnsureStandaloneShell()
    self:SelectActiveModuleInShell("marker")
    if subTabIndex and self.SelectSubTab then
        self:SelectSubTab(subTabIndex)
    end
    f:Show()
    if f.Raise then f:Raise() end
    self:RefreshAll()
end

function DM:ToggleUI(forceShow, tabIndex)
    if forceShow == false then
        if self.shellFrame and self.shellFrame:IsShown() then
            self.shellFrame:Hide()
        end
        if self.workspaceFrame and self.workspaceFrame:IsShown() then
            self.workspaceFrame:Hide()
        end
        return
    end
    if forceShow == nil and self.shellFrame and self.shellFrame:IsShown() and not tabIndex then
        self.shellFrame:Hide()
        return
    end
    self:OpenWindow(tabIndex)
end

-- ============================================================================
-- 18. MODULE DESCRIPTOR IN _G.DYNAMICSUITE
-- ============================================================================

local function RenderIntoContainer(firstArg, secondArg)
    local container = (type(firstArg) == "table" and firstArg.GetObjectType) and firstArg or secondArg
    if not container or not container.GetObjectType then
        DM:OpenWindow()
        return DM.workspaceFrame
    end
    return DM:BuildWorkspace(container)
end

local MarkerModuleDescriptor = {
    id            = "marker",
    key           = "marker",
    name          = "DynamicMarker",
    title         = "DynamicMarker",
    sub           = "Targets, Flares, Macros",
    subtitle      = "Targets, Flares, Macros",
    desc          = "One-button focus target marking, optional ground flare hotkeys (unbound by default), and an auto-swapping interrupt macro across all 13 classes.",
    version       = DM.version,
    slash         = "/dm",
    icon          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_marker.tga",
    fallbackIcon  = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_marker.tga",
    isInstalled   = true,
    enabled       = true,
    ref           = DM,
    GetStatusText = function() return DM:GetStatusText() end,
    GetStatus     = function() return DM:GetStatusText() end,
    Render        = RenderIntoContainer,
    RenderEmbedded = RenderIntoContainer,
    BuildUI       = RenderIntoContainer,
    Build         = RenderIntoContainer,
    CreatePanel   = RenderIntoContainer,
    OnSelect      = RenderIntoContainer,
    Show          = RenderIntoContainer,
    Hide          = function()
        if DM.workspaceFrame then DM.workspaceFrame:Hide() end
    end,
    SetEditMode   = function(firstArg, secondArg)
        local state = (firstArg == MarkerModuleDescriptor or firstArg == DM) and secondArg or firstArg
        DM._inExternalSetEditMode = true
        DM:SetEditMode(state, { fromSuite = DM:IsRunningInSuite() })
        DM._inExternalSetEditMode = nil
    end,
    Open          = function(_, tabIdx) DM:OpenWindow(tabIdx) end,
    ToggleUI      = function(forceShow, tabIndex)
        if DynamicMarker and DynamicMarker.ToggleUI then
            if forceShow == DynamicMarker.moduleEntry or forceShow == DynamicMarker then
                DynamicMarker:ToggleUI(tabIndex, nil)
            else
                DynamicMarker:ToggleUI(forceShow, tabIndex)
            end
        end
    end,
    Reset         = function() DM:ResetDefaults() end,
    ApplyTheme    = function() DM:ApplyThemeToUI() end,
    ApplyThemeToUI = function() DM:ApplyThemeToUI() end,
    RefreshTheme  = function() DM:ApplyThemeToUI() end,
    SelectTab = function(a1, a2, a3) local idx = (type(a1) == "number") and a1 or a2; local exp = (type(a1) == "number") and a2 or a3; if DM.SelectSubTab then DM:SelectSubTab(idx or 1, exp) end end,
    SelectSubTab = function(a1, a2, a3) local idx = (type(a1) == "number") and a1 or a2; local exp = (type(a1) == "number") and a2 or a3; if DM.SelectSubTab then DM:SelectSubTab(idx or 1, exp) end end,
    SetActiveTab = function(a1, a2, a3) local idx = (type(a1) == "number") and a1 or a2; local exp = (type(a1) == "number") and a2 or a3; if DM.SelectSubTab then DM:SelectSubTab(idx or 1, exp) end end,
    ResetDefaults = function() DM:ResetDefaults() end,
    ResetHUDPositions = function(_, silent) return DM:ResetHUDPositions(silent) end,
    OnDisableInSuite = function()
        if DM.targetBar and not (InCombatLockdown and InCombatLockdown()) then DM.targetBar:Hide() end
        if DM.flareBar and not (InCombatLockdown and InCombatLockdown()) then DM.flareBar:Hide() end
        DM:ApplyFlareKeybinds()
    end,
    OnEnableInSuite = function()
        DM:InitSecureFlareButtons()
        DM:SyncSecureFlareEngine()
        DM:ApplyFlareKeybinds()
        DM:UpdateTargetBarVisibility()
        DM:UpdateFlareBarVisibility()
        DM:RefreshTargetBar()
        DM:RefreshFlareBar()
    end,
}

function DM:ApplyThemeToUI()
    if self.RefreshAll then self:RefreshAll() end
    if self.RefreshTargetBar then self:RefreshTargetBar() end
    if self.RefreshFlareBar then self:RefreshFlareBar() end
end
DM.ApplyTheme = DM.ApplyThemeToUI
DM.RefreshTheme = DM.ApplyThemeToUI

DM.moduleEntry = MarkerModuleDescriptor
Suite.modules["marker"] = MarkerModuleDescriptor
Suite.modules["DynamicMarker"] = MarkerModuleDescriptor

if type(Suite.RegisterModule) == "function" then
    pcall(Suite.RegisterModule, Suite, "marker", MarkerModuleDescriptor, "/dm", "Targets, Flares, Macros")
end

DynamicMarker.CHANGELOG = {
    version = DM.version or VERSION,
    date    = "18/11/2026",
    entries = {
        { type = "IMPROVED", text = "Release v2.4.0 - Version & Coexistence Lockstep Parity (18/11/2026): Synchronised standalone DynamicMarker metadata and version-aware coexistence checks cleanly to v2.4.0 for Retail 12.1.5 (Interface 120105, Midnight Season 2)." },
        { type = "FIX",      text = "Release v2.3.2 - Proactive DecorVendor /tm Quarantine & Obsidian Modal (18/11/2026): Promoted DecorVendor ('Decor Vendor') to a Tier-1 HARD conflict across Guided Setup and the Conflict Banner, and added a Midnight Pitch Black (#06070A-#090A0D) Obsidian warning modal ('Raid Marker Blocked by Addon Conflict', safely deferred until out of combat) across bundled and standalone modes whenever DecorVendor is active on login/reload or whenever World of Warcraft blocks SetRaidTarget() / SetRaidTargetIcon(). Includes 1-click 'Disable <Addon> (Set to Never)', session-throttled Dismiss, plain-English Exit & Restart instructions, and v2.3.2 lockstep parity." },
        { type = "FIX",      text = "Release v2.3.1 - Runtime /tm Taint Listener, DecorVendor Compatibility Guard & Lockstep Parity (18/11/2026): Registered ADDON_ACTION_FORBIDDEN on DynamicMarker's event frame for SetRaidTarget/SetRaidTarget() in both DynamicSuite and standalone modes to print a rate-limited (once per 30 seconds per offending addon) plain-English chat alert naming the offending addon and advising disabling it and completely restarting the game client (/reload alone will not clear Blizzard's raid-marker lockout); added DecorVendor ('Decor Vendor') to DynamicMarker's conflict registries (CONFLICT_ADDONS and ADVISORY_CONFLICT_ADDONS) with 1-click Disable (setting it to Never in DynamicLoadDB) and persistent Dismiss; updated Macro Setup's [DynamicMark] troubleshooting note; and synchronised standalone DynamicMarker metadata and version-aware coexistence checks to v2.3.1." },
        { type = "FIX",      text = "Runtime /tm Taint Listener & DecorVendor Compatibility Guard (18/11/2026): Registered ADDON_ACTION_FORBIDDEN on DynamicMarker's event frame for SetRaidTarget/SetRaidTarget() to print a rate-limited (once per 30 seconds per offending addon) plain-English chat alert naming the third-party addon that tainted Blizzard's /tm slash command and advising Outdoor Only mode or disabling + reloading UI; added DecorVendor soft-conflict detection across Guided Setup and standalone DynamicMarker's advisory banner with 1-click Disable DecorVendor and persistent Dismiss; and updated Macro Setup's [DynamicMark] troubleshooting note." },
        { type = "IMPROVED", text = "[DynamicMark] Macro Template Streamlining & Raid Marker Note (17/11/2026): Removed the redundant /stopmacro [@focus,noexists] line from generated [DynamicMark] macros (since /tm already gates on @focus,exists across all group scopes) and added a concise troubleshooting note in Macro Setup explaining that /tm requires Raid Leader or Assistant in raids and that a full game restart (not /reload) clears Blizzard's intermittent raid-marker lockout bug." },
        { type = "UI",       text = "3-Way Interactive Obsidian Scrollbars & Automatic Popover Dismissal (16/11/2026): Upgraded all scrollbars across the settings tabs, dropdown menus, and the Changelog viewer to support full 3-way interaction (mousewheel scrolling, Left-Click & Drag on the scrollbar thumb with hover highlights, and Left-Click on the scrollbar track to jump directly to that position), added an unclipped 1px accent border overlay and Escape-key dismissal to dropdown menus, and ensured open dropdowns and HUD selector popovers close automatically when switching tabs, entering HUD Edit Mode, or closing the window." },
        { type = "IMPROVED", text = "Release v2.3.0 - HUD Edit Mode 'Apply All' Appearance Action & Lockstep Parity (16/11/2026): Added a compact 'Apply All' Opacity & Border Style button to Row 3 of DynamicMarkerEditModeInspector so you can copy the active bar's opacity and border style across both bars in one click, and synchronised standalone DynamicMarker metadata and version-aware coexistence checks to v2.3.0 for Retail 12.1.5 (Interface 120105, Midnight Season 2)." },
        { type = "FEATURE", text = "SharedMedia, AddOn & Blizzard Font Discovery in Theme Studio (15/11/2026): Added runtime scanning for LibSharedMedia-3.0, DBM, WeakAuras, and ElvUI fonts alongside Blizzard standard fonts and bundled Expressway fonts inside Theme & Font Studio. Grouped dropdown options under Built-in Fonts, Blizzard, and SharedMedia / AddOns with live search, scroll support, per-font preview rendering, and safe fallback to the default font if an external addon is disabled." },
        { type = "IMPROVED", text = "Unbound-by-Default World Flare Keybinds & Guided Setup Assignment (15/11/2026): Removed the hardcoded F4 and F5 World Flare default keybinds so fresh installs and Resets start with both keys 'Unbound' (leaving your own Blizzard and action bar bindings untouched while preserving any existing saved DynamicMarkerDB hotkeys), added optional single-button Cycle World Flare and Clear All Flares keybind capture rows to both Guided Setup and the World Flare Keys (/dm flares) tab ('Click to bind, Right-click to unbind'), and refined capture behaviour so Escape cancels without losing the current key while Backspace/Delete or Right-Click clears to Unbound." },
        { type = "FEATURE", text = "Release v2.1.1 - 3-Row HUD Edit Appearance Dock (560x110) & First-Click Mover Parity (15/11/2026): Upgraded standalone DynamicMarkerEditModeInspector into a unified 560x110 3-row draggable inspector dock adding Row 3 live Appearance controls: Opacity slider (20%-100%, step 5%, with SetIgnoreParentAlpha mover legibility), Accent | Dark | None Border Style pills synced 1:1 with Target Icon Bar and World Flare Bar sub-settings, Horiz | Vert Orientation toggle with instant screen-bounds re-clamping, and full Position/Scale/Opacity/Border/Orientation [Reset]. Ensured the HUD selector dropdown defaults to closed on entry and Target Icon / World Flare movers appear reliably on first HUD Edit activation." },
        { type = "FIX",     text = "HUD Edit Mode Mover Visibility & Drag Shield Layering (15/11/2026): Promoted the Target Icon Bar and World Flare Bar mover overlays (editMover) to HIGH frame strata (FrameLevel + 50) with SetIgnoreParentAlpha(true) and ordered SyncEditBarStates() after bar refreshes in SetEditMode, ensuring any bar set to Shown (Group or Always) immediately displays its live preview and interactive drag shield in HUD Edit Mode (even while solo), while explicitly selecting a Hidden (Off) bar from the HUD dropdown or clicking [Edit HUD] previews it with the 'HIDDEN (Click Shown to Enable)' badge." },
        { type = "FIX",     text = "Release v2.1.0 - World Flare Keybind Dispatch & Instant Telemetry Refresh (15/11/2026): Anchored secure World Flare cycle/clear buttons on-screen (1x1, alpha 0, non-mouse-blocking), removed the SecureHandlerWrapScript button-name override so LeftButton dispatches /wm [@cursor] and /cwm all reliably in and out of combat across key-down and key-up CVars, added Right-Click unbind, and wired instant status telemetry bar and proportional 'World Flare Keys (...)' sub-tab updates whenever bindings are captured, cleared, or reset." },
        { type = "UI",      text = "Compact Draggable HUD Edit Dock & Hidden-By-Default Movers (15/11/2026): Redesigned standalone HUD Edit Mode into a compact 560x74 2-row draggable inspector with a HUD Selector Dropdown, non-truncated Hidden/Shown toggles, Grid, Reset, Back to Suite, X/Y steppers, Center X/Y, and Scale slider (60%-150%), keeping at least 60px on-screen near screen edges while clamping bars inside screen bounds, hiding disabled movers by default, temporarily previewing explicitly selected hidden bars with 'HIDDEN (Click Shown to Enable)', and standardising Obsidian/Blaze-Orange [Edit HUD] buttons." },
        { type = "FIX", text = "World Flare Hardware Keybinds & Custom Sequence Order (15/11/2026): Fixed Cycle Ground Flare (F4) and Clear All Flares (F5) hardware keybinds so they fire reliably in and out of combat, walk your saved and enabled World Flare Cycle Sequence in exact custom order via SecureHandlerWrapScript, and update the floating World Flare Bar to match your custom sequence order and enabled flares." },
        { type = "FIX", text = "Target Only Focus Macro Clear (15/11/2026): Updated the Target Only [DynamicMark] macro template to /focus [@target,exists,nodead][] so pressing it with a target sets focus and marks it, while pressing it with no target clears your existing focus target." },
        { type = "FEATURE", text = "Inline Manual Macro Editor & Custom Icon Preservation (15/11/2026): In Manual (Custom) mode, Sub-Tab 3's [DynamicMark] preview becomes an editable dark-obsidian multi-line EditBox (255-char limit with live character counter and Escape to unfocus) so you can write or paste custom macro lines directly inside DynamicMarker and save immediately with Step 1. Updating an existing [DynamicMark] macro now preserves any custom in-game macro icon you assigned." },
        { type = "FEATURE", text = "Focus Target Mode & Surgical Manual Macro Patching (15/11/2026): Added a 'Focus Target Mode' 3-pill selector in Sub-Tab 3 (Mouseover + Target, Target Only, Manual (Custom)). In Manual (Custom) mode, logins/reloads keep your custom [DynamicMark] macro untouched, changing Focus Icon, Group Scope, or Clear Focus Modifier surgically updates only the /tm and /clearfocus lines (within 255 characters), the preview box displays your live custom macro, and Step 1 uses a 2-click confirmation before resetting custom lines." },
        { type = "FIX",     text = "Release v1.9.9 - Canonical UIParent-Local HUD Coordinates Across /reload, Dark-Obsidian Coexistence Modal & Unified HUD Edit Mode (14/11/2026): Enforced one canonical UIParent-local coordinate contract for TargetBar and FlareBar (storing unscaled UIParent CENTER offsets and dividing by barScale strictly inside DM:SetBarCenterPoint after applying SetScale/SetSize and before SetClampedToScreen(true), removing destructive early-load DB writes in ApplyHUDPosition, and guaranteeing 100% round-trip symmetry across HUD Edit drag, Quick Align, Reset HUD, and /reload at scales 0.70, 1.00, and 1.30); replaced Blizzard's StaticPopup with a custom dark-obsidian coexistence reload modal (ShowMarkerConflictReloadModal / DynamicSuiteMarkerConflictModal with #0B0D12 0.96 alpha backdrop, 1px dark slate border, Blaze Orange #F97316 accent bar, flat Reload UI / Later buttons, ESC dismissal, and combat deferral); and suppressed DynamicMarkerEditModeInspector inside DynamicSuite so only the unified HUD Edit dock displays." },
        { type = "FIX",     text = "HUD Edit Bar Edge-Drag & Reload Persistence Fix (14/11/2026): Fixed Target Icon Bar and World Flare Bar jumping inward on /reload or mouse release when scaled below 100% by syncing bar scale and orientation size via SyncBarScaleAndSizeToDB before clamping, removing premature scale=1.0 ApplyHUDPosition calls at initialisation/login/UI_SCALE_CHANGED, canonicalising TargetBar/FlareBar coordinates to CENTER with full mirror key writes, guarding against re-entrant selection callbacks mid-drag, and disabling native C++ SetClampedToScreen interference so edge-snapped bars stay flush after mouse release and /reload." },
        { type = "FEATURE", text = "Release v1.9.7 - Live CurseForge DynamicSuite Link & Hardened Coexistence (14/11/2026): Updated Support modal and CurseForge storefront links cleanly to https://www.curseforge.com/wow/addons/dynamicsuite (replacing legacy URL placeholder labels), connected full DynamicSuite (Project 1804382) alongside standalone DynamicMarker (Project 1331651) in our dual-artifact release pipeline, and hardened ShouldYieldToOtherInstall semantic version yielding regardless of addon load order." },
        { type = "FIX",     text = "HUD Edit Scale-Aware Clamping, Magnetic Edge/Bar Snapping & Reset HUD Positions Failsafe (14/11/2026): Fixed 1:1 uScale drag math at non-100% scales, added magnetic screen-edge/centre (11px) and bar-to-bar (9px) snapping with live DynamicSuiteSnapGuideOverlay guide lines, Shift-to-bypass snapping, and Shift+Click 10px nudges, enforced strict screen-boundary clamping across drags/nudges/coordinates/orientation/scale/login/UI_SCALE_CHANGED, and added Reset HUD Positions in ESC -> Options -> AddOns plus /dm resethud (/fm resethud) and /ds resethud with combat-lockdown deferral." },
        { type = "UI",      text = "Standalone Scrollable Changelog Modal Parity & v1.9.6 Sync (14/11/2026): Replaced the legacy static 5-bullet standalone Changelog text with a live scrollable viewer reading directly from DynamicMarker.CHANGELOG.entries so standalone and full-suite users always see full release notes with colour-coded [FEATURE], [FIX], and [UI] badges." },
        { type = "UI",      text = "Standalone Bottom-Right Dock Parity & Copyable Support Modal Links (14/11/2026): Added the [Reload UI] button and persisted Opacity (50%-100%) and Scale (80%-120%) sliders to the standalone footer dock (positioned left of the // resize grip and stored in DynamicMarkerDB), and replaced static Support modal text with read-only click-to-highlight Ctrl+C EditBoxes for Ko-fi, CurseForge (/addons/dynamicmarker), and Email with Escape-to-close." },
        { type = "FIX",     text = "First-Open ESC > Options > AddOns Standalone Shell & Settings Yield (14/11/2026): Added initial f:Hide(), OnShow post-layout C_Timer.After(0, ...) theme/workspace refresh + Raise() on DynamicMarkerSuiteWindow, Settings canvas OnShow accent/surface sync, and hardened HideSettingsPanelSafe() so opening standalone DynamicMarker via ESC > Options > AddOns > DynamicMarker renders cleanly on the very first open without SettingsPanel obscuring it." },
        { type = "FIX",     text = "Standalone Guided Setup Modal Layering (14/11/2026): Promoted DynamicMarkerStudioBackdrop and DynamicMarkerStudioModal to FULLSCREEN_DIALOG strata (levels 290/300) parented to UIParent with SetToplevel(true), 100% opaque solid panel backing, and clean mode-widget recycling so underlying window controls, borders, and text never bleed through or overlap." },
        { type = "UI",      text = "Standalone Bottom-Left Sidebar & Brighter Theme Parity (14/11/2026): Aligned standalone shell dimensions (204px rail, 46px header with 2px top accent bar, 38px footer), SUITE STUDIO & TOOLS card spacing, 90px/88px [Changelog] & [Support] buttons, and brighter OBSIDIAN_DARK / SLATE_STEEL surface palette with full DynamicSuite." },
        { type = "FEATURE", text = "Encapsulated HUD Edit Mode & Standalone Mover Parity (14/11/2026): Moved HUD Edit Mode state, crisp pixel-bordered movers ('DynamicMarker: Icon Bar' and 'DynamicMarker: Flare Bar'), drag-and-snap persistence directly into DynamicMarkerDB, mousewheel scaling, ESC-key closing, and combat-lockdown failsafe cleanly inside DynamicMarker. Registers with DynamicSuite's [+ HUD] toolbar toggle when bundled and provides standalone controls in Focus/Flare Settings headers, left rail, and /dm hud." },
        { type = "FEATURE", text = "One-Time FocusMarkerDB -> DynamicMarkerDB Migration Bridge (14/11/2026): Checks _G.FocusMarkerDB on ADDON_LOADED before applying fresh defaults, safely maps bar positions, scales, visibility rules (Solo/Group/Always), orientation, and custom icon/flare sequences while guarding against nil or malformed SavedVariables, and sets migratedFromFocusMarker = true so legacy settings are preserved untouched without overwriting later edits." },
        { type = "FEATURE", text = "FocusMarker Settings Bridge (13/11/2026): DynamicMarker now saves a permanent copy of your FocusMarker settings whenever FocusMarker is enabled, so they can still be imported after FocusMarker is disabled or removed. Supports both old (v1.4) and new (v2.0) FocusMarker layouts. Type /dm import to re-import, or /dm import status to see what was copied." },
        { type = "FIX",     text = "FocusMarker bar position now imports correctly (13/11/2026): the imported Focus Bar position was previously ignored because an older saved position took priority. It now updates every saved copy of the position together." },
        { type = "FIX",     text = "On-Screen Target Icon Bar & World Flare Bar Solo Visibility Fix (12/11/2026): Centralised visibility evaluation in DM:UpdateTargetBarVisibility() and DM:UpdateFlareBarVisibility() with case-insensitive DB mode normalisation, state-driver registration ('[group] show; hide' / scope-aware variants), and immediate SetShown() evaluation; removed the workspace-open force-show override so selecting 'Group' while solo immediately hides the floating 8-icon bar even when the DynamicSuite settings panel is open." },
        { type = "FEATURE", text = "External Addon Conflict Detector & Yield Engine (12/11/2026): Added TargetCharms and legacy FocusMarker to the curated HARD conflict registry with unified DynamicSuite top-of-module warning banner and 1-click resolution." },
        { type = "FIX",     text = "Hardened DM:SetEditMode(false), bar.SetEditMode, and PLAYER_REGEN_DISABLED against combat-lockdown calls on protected TargetBar and FlareBar frames (deferring SetMovable, SetClampedToScreen, and Show/Hide syncs to PLAYER_REGEN_ENABLED while immediately aborting active HUD drags and closing dropdown popovers on combat entry)." },
        { type = "FIX",     text = "Fixed pressing Esc in HUD Edit Mode leaving the alignment grid and HUD movers stuck on screen: registered DynamicMarkerEditModeInspector in UISpecialFrames with an OnHide cleanup hook, suppressed duplicate grid overlay display when DynamicLoad's external HUD controller is active, and wired DM:SetEditMode(false) to exit external HUD Edit Mode cleanly." },
        { type = "UI",      text = "Expanded [DynamicMark] macro preview container height (80px code box / 134px preview card / 264px section) to prevent 4-line macro code clipping, and added reactive Step 1 / Step 2 active button highlights." },
        { type = "UI",      text = "Standardized all sliders to the Sleek Precision Track (4px track, Suite Accent fill bar, 6x14px blade thumb) and applied Option 3 semantic styling for negative/disabled pill states." },
        { type = "UI",      text = "Standardized all mouseover command tooltips (Target Bar, World Flare Bar, Keybind Capture, and World Flare Sequence cards) to highlight only the input command prefix while keeping action descriptions Silver-White (#E2E8F0)." },
        { type = "FIX",     text = "Fixed World Flare Cycle Sequence [Reset] button and SavedVariables defaults to re-enable all 8 flares (1..8) and restore default sequence order." },
        { type = "FIX",     text = "Fixed 8-digit ARGB hex color code corruption leaking literal '0a' text into headers and keybind button text by adding SanitizeHex6 to DM:GetAccentColor()." },
        { type = "FIX",     text = "Replaced legacy small square chevron buttons on Announce Marks in Chat, Show On-Screen Focus Bar, and Show On-Screen World Flare Bar with full-width 24px horizontal chevron toggle bars (Sub-Settings (N)) and unified outer group borders per DESIGN_SYSTEM.md Section 2.6." },
        { type = "FIX",     text = "Parented nested sub-setting cards directly inside their outer group card (10px inset, PANEL_BG #090A0D, 1px CELL_BORDER, 2px vertical Suite Accent left bar, and 5x5px Suite Accent square pip) with automatic expand-on-enable and persistent state." },
        { type = "UI",      text = "Enclosed each L-bracket section header and its subsection setting cards inside an outer backdrop border frame with dynamic sub-drawer reflow." },
        { type = "UI",      text = "Standardised all setting cards into individual row cards with bold uppercase Suite Accent headers and removed redundant live preview and position-on-screen bars." },
        { type = "FIX",     text = "Resolved Lua syntax error near line 3302 in DynamicMarker.lua." },
        { type = "FEATURE", text = "30x30 square target icon and world flare pickers with 2px bottom active indicator bars and local-space cursor tracking." },
        { type = "FEATURE", text = "Modifier-free [DynamicMark] general macro and auto-swapping multi-spec [DynamicKick] character macro." },
    },
}
Suite.Changelogs["DynamicMarker"] = DynamicMarker.CHANGELOG
Suite.Changelogs["marker"] = DynamicMarker.CHANGELOG

-- ============================================================================
-- 19. SLASH COMMANDS (/dm, /dynamicmarker, /fm, /focusmarker) & EVENT DISPATCHER
-- ============================================================================

local function PrintSlashUsage()
    print("|cFF38BDF8DynamicMarker|r: Commands (/dm, /dynamicmarker, /fm, /focusmarker):")
    print("  |cFFF5B82E/dm|r - Open DynamicMarker settings")
    print("  |cFFF5B82E/dm lock|r | |cFFF5B82E/dm hud|r - Toggle icon & flare bar lock (HUD Edit Mode)")
    print("  |cFFF5B82E/dm unlock|r - Unlock icon & flare bars")
    print("  |cFFF5B82E/dm show|r | |cFFF5B82E/dm hide|r - Show or hide the on-screen icon bar")
    print("  |cFFF5B82E/dm mute|r | |cFFF5B82E/dm silent|r - Toggle silent announcement mode")
    print("  |cFFF5B82E/dm flare|r | |cFFF5B82E/dm macro|r - Open Flares or Macro Setup tab")
    print("  |cFFF5B82E/dm import [status]|r - Import legacy FocusMarker settings")
    print("  |cFFF5B82E/dm resethud|r - Reset HUD bar positions to screen-safe defaults")
    print("  |cFFF5B82E/dm reset|r - Reset defaults, positions, size, and mute state")
end

local function HandleSlashCommand(msg)
    local trimmed = (msg or ""):match("^%s*(.-)%s*$") or ""
    local cmd = (trimmed:match("^(%S*)") or ""):lower()
    if cmd == "" or cmd == "config" or cmd == "ui" or cmd == "options" then
        if type(Suite.OpenModule) == "function" and Suite.mainFrame and Suite.mainFrame ~= DM.shellFrame then
            local ok = pcall(Suite.OpenModule, Suite, "DynamicMarker")
            if ok then return end
        end
        DM:OpenWindow()
    elseif cmd == "edit" or cmd == "hud" or cmd == "move" or cmd == "movers" or cmd == "lock" then
        DM:ToggleHudEditMode()
    elseif cmd == "unlock" then
        DM:SetEditMode(true)
    elseif cmd == "resethud" or cmd == "resethuds" or cmd == "hudreset" then
        DM:ResetHUDPositions(false)
    elseif cmd == "reset" then
        DM:ResetDefaults()
    elseif cmd == "mute" or cmd == "silent" then
        DM.db.chatAnnounce = (DM.db.chatAnnounce == "MUTED") and "ACTIVE" or "MUTED"
        DM:RefreshAll()
        print("|cFF38BDF8DynamicMarker|r: Chat announcements " .. ((DM.db.chatAnnounce == "MUTED") and "|cFFF59E0BMuted (Silent Mode)|r" or "|cFF22C55EEnabled|r"))
    elseif cmd == "show" then
        DM.db.targetBarVisibility = "ALWAYS"
        DM:RefreshTargetBar()
        DM:RefreshAll()
        print("|cFF38BDF8DynamicMarker|r: On-Screen Focus Bar set to |cFF22C55EAlways Shown|r.")
    elseif cmd == "hide" then
        DM.db.targetBarVisibility = "HIDDEN"
        DM:RefreshTargetBar()
        DM:RefreshAll()
        print("|cFF38BDF8DynamicMarker|r: On-Screen Focus Bar |cFFF59E0BHidden|r.")
    elseif cmd == "macro" or cmd == "macros" then
        DM:OpenWindow(3)
    elseif cmd == "flare" or cmd == "flares" then
        DM:OpenWindow(2)
    elseif cmd == "import" or cmd == "migrate" then
        local sub = (trimmed:match("^%S+%s+(%S+)") or ""):lower()
        if sub == "status" then
            DM:PrintFocusMarkerImportStatus()
        elseif InCombatLockdown and InCombatLockdown() then
            print("|cFF38BDF8DynamicMarker|r: Import is unavailable in combat. Try again after combat ends.")
        else
            local ok, res = DM:MigrateFromFocusMarker(true)
            if ok then
                print("|cFF38BDF8DynamicMarker|r: FocusMarker import complete: " .. ((type(res) == "table" and #res > 0) and table.concat(res, ", ") or "nothing to change") .. ".")
                DM:InitTargetBar()
                DM:InitFlareBar()
                DM:RefreshTargetBar()
                DM:RefreshFlareBar()
                DM:CreateOrUpdateFocusMarkerMacro(false)
                DM:RefreshAll()
            else
                print("|cFF38BDF8DynamicMarker|r: " .. tostring(res or "FocusMarker import failed."))
            end
        end
    elseif cmd == "help" or cmd == "?" then
        PrintSlashUsage()
    else
        print("|cFF38BDF8DynamicMarker|r: Unknown subcommand '" .. cmd .. "'.")
        PrintSlashUsage()
    end
end

SLASH_DYNAMICMARKER1 = "/dm"
SLASH_DYNAMICMARKER2 = "/dynamicmarker"
SLASH_DYNAMICMARKER3 = "/fm"
SLASH_DYNAMICMARKER4 = "/focusmarker"
SlashCmdList["DYNAMICMARKER"] = HandleSlashCommand

if not SlashCmdList["DYNAMICSUITE"] then
    SLASH_DYNAMICSUITE1 = "/ds"
    SLASH_DYNAMICSUITE2 = "/dynamicsuite"
    SlashCmdList["DYNAMICSUITE"] = function(msg)
        HandleSlashCommand(msg)
    end
end

local standaloneMarkerWasEnabledAtBoot = (_G.DynamicSuite_StandaloneMarkerWasEnabledAtBoot == true)
local shownMarkerConflictModalThisSession = false
local hasEnteredWorld = false

function DM:ShowMarkerConflictReloadModal()
    if shownMarkerConflictModalThisSession or DM._shownMarkerConflictModalThisSession
        or (_G.DynamicSuite and _G.DynamicSuite._shownMarkerConflictModalThisSession) then
        return
    end
    local existingModal = _G.DynamicSuiteMarkerConflictModal
    if existingModal and existingModal._dismissedByUser then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        self._pendingMarkerConflictModal = true
        local deferFrame = _G.DynamicMarkerConflictDeferFrame
        if not deferFrame then
            deferFrame = CreateFrame("Frame", "DynamicMarkerConflictDeferFrame", UIParent)
            deferFrame:SetScript("OnEvent", function(frame)
                frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
                if DM._pendingMarkerConflictModal then
                    DM:ShowMarkerConflictReloadModal()
                end
            end)
        end
        deferFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    self._pendingMarkerConflictModal = false

    if _G.DynamicSuite and type(_G.DynamicSuite.ShowMarkerConflictReloadModal) == "function" then
        pcall(_G.DynamicSuite.ShowMarkerConflictReloadModal)
        return
    end

    local modal = _G.DynamicSuiteMarkerConflictModal
    if not modal then
        modal = CreateFrame("Frame", "DynamicSuiteMarkerConflictModal", UIParent, "BackdropTemplate")
        modal:SetSize(432, 184)
        modal:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        modal:SetFrameStrata("DIALOG")
        modal:SetFrameLevel(260)
        modal:SetToplevel(true)
        modal:SetClampedToScreen(true)
        modal:SetMovable(true)
        modal:EnableMouse(true)
        modal:RegisterForDrag("LeftButton")
        modal:SetScript("OnDragStart", modal.StartMoving)
        modal:SetScript("OnDragStop", modal.StopMovingOrSizing)
        modal:HookScript("OnHide", function(self)
            self._dismissedByUser = true
        end)
        if modal.SetBackdrop then
            modal:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            -- Dark Obsidian (#0B0D12 / alpha 0.96) + 1px dark slate border (#333D4F)
            modal:SetBackdropColor(0.043, 0.051, 0.071, 0.96)
            modal:SetBackdropBorderColor(0.200, 0.240, 0.310, 0.95)
        end

        modal.TopAccent = modal:CreateTexture(nil, "OVERLAY")
        modal.TopAccent:SetHeight(2)
        modal.TopAccent:SetPoint("TOPLEFT", modal, "TOPLEFT", 1, -1)
        modal.TopAccent:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -1, -1)
        -- Blaze Orange (#F97316)
        modal.TopAccent:SetColorTexture(0.976, 0.451, 0.086, 1.0)

        modal.Title = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        modal.Title:SetPoint("TOPLEFT", modal, "TOPLEFT", 18, -16)
        modal.Title:SetText("|cFFF97316DynamicSuite|r  |cFF94A3B8-- Coexistence Guard|r")

        modal.HeaderSep = modal:CreateTexture(nil, "ARTWORK")
        modal.HeaderSep:SetHeight(1)
        modal.HeaderSep:SetPoint("TOPLEFT", modal, "TOPLEFT", 18, -40)
        modal.HeaderSep:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -18, -40)
        modal.HeaderSep:SetColorTexture(0.200, 0.240, 0.310, 0.65)

        modal.Body = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        modal.Body:SetPoint("TOPLEFT", modal, "TOPLEFT", 18, -52)
        modal.Body:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -18, -52)
        modal.Body:SetJustifyH("LEFT")
        modal.Body:SetJustifyV("TOP")
        modal.Body:SetSpacing(3)
        modal.Body:SetTextColor(0.886, 0.910, 0.941, 1.0)
        modal.Body:SetText("DynamicSuite already includes DynamicMarker.\n\nStandalone DynamicMarker has been automatically disabled to prevent duplicate bars and settings. Reload UI now?")

        local function CreateModalButton(parent, label, width, height, isPrimary, onClick)
            local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
            btn:SetSize(width, height)
            if btn.SetBackdrop then
                btn:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 1,
                })
            end
            btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btn.Text:SetPoint("CENTER", btn, "CENTER", 0, 0)
            btn.Text:SetText(label)

            local function ApplyState(hover)
                if not btn.SetBackdropColor then return end
                if isPrimary then
                    if hover then
                        btn:SetBackdropColor(0.350, 0.160, 0.035, 1.0)
                        btn:SetBackdropBorderColor(0.976, 0.451, 0.086, 1.0)
                        btn.Text:SetTextColor(1.0, 1.0, 1.0, 1.0)
                    else
                        btn:SetBackdropColor(0.220, 0.100, 0.022, 0.96)
                        btn:SetBackdropBorderColor(0.976, 0.451, 0.086, 0.95)
                        btn.Text:SetTextColor(0.976, 0.451, 0.086, 1.0)
                    end
                else
                    if hover then
                        btn:SetBackdropColor(0.150, 0.180, 0.240, 1.0)
                        btn:SetBackdropBorderColor(0.320, 0.380, 0.480, 1.0)
                        btn.Text:SetTextColor(1.0, 1.0, 1.0, 1.0)
                    else
                        btn:SetBackdropColor(0.090, 0.110, 0.150, 0.96)
                        btn:SetBackdropBorderColor(0.200, 0.240, 0.310, 0.95)
                        btn.Text:SetTextColor(0.796, 0.835, 0.882, 1.0)
                    end
                end
            end
            ApplyState(false)
            btn:SetScript("OnEnter", function() ApplyState(true) end)
            btn:SetScript("OnLeave", function() ApplyState(false) end)
            btn:SetScript("OnClick", onClick)
            return btn
        end

        modal.ReloadBtn = CreateModalButton(modal, "Reload UI", 138, 28, true, function()
            modal._dismissedByUser = true
            shownMarkerConflictModalThisSession = true
            DM._shownMarkerConflictModalThisSession = true
            if _G.DynamicSuite then
                _G.DynamicSuite._shownMarkerConflictModalThisSession = true
            end
            modal:Hide()
            if type(_G.ReloadUI) == "function" then
                _G.ReloadUI()
            end
        end)
        modal.ReloadBtn:SetPoint("BOTTOMRIGHT", modal, "BOTTOM", -6, 16)

        modal.LaterBtn = CreateModalButton(modal, "Reload Later", 138, 28, false, function()
            modal._dismissedByUser = true
            shownMarkerConflictModalThisSession = true
            DM._shownMarkerConflictModalThisSession = true
            if _G.DynamicSuite then
                _G.DynamicSuite._shownMarkerConflictModalThisSession = true
            end
            modal:Hide()
        end)
        modal.LaterBtn:SetPoint("BOTTOMLEFT", modal, "BOTTOM", 6, 16)

        if type(_G.UISpecialFrames) == "table" then
            local found = false
            for i = 1, #_G.UISpecialFrames do
                if _G.UISpecialFrames[i] == "DynamicSuiteMarkerConflictModal" then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(_G.UISpecialFrames, "DynamicSuiteMarkerConflictModal")
            end
        end
    end

    shownMarkerConflictModalThisSession = true
    DM._shownMarkerConflictModalThisSession = true
    if _G.DynamicSuite then
        _G.DynamicSuite._shownMarkerConflictModalThisSession = true
    end
    modal:Show()
    modal:Raise()
end

local function GetSharedRaidTaintSession()
    _G.DynamicSuite_RaidTaintModalSession = type(_G.DynamicSuite_RaidTaintModalSession) == "table"
        and _G.DynamicSuite_RaidTaintModalSession
        or {}
    local s = _G.DynamicSuite_RaidTaintModalSession
    s.dismissed = type(s.dismissed) == "table" and s.dismissed or {}
    s.quarantined = type(s.quarantined) == "table" and s.quarantined or {}
    return s
end

local function IsSetRaidTargetBlockedName(fnName)
    if type(fnName) ~= "string" or fnName == "" then return false end
    return fnName == "SetRaidTarget"
        or fnName == "SetRaidTarget()"
        or fnName == "SetRaidTargetIcon"
        or fnName == "SetRaidTargetIcon()"
        or fnName:find("SetRaidTarget", 1, true) ~= nil
end

local function IsDecorVendorActiveForStandaloneModal()
    local session = GetSharedRaidTaintSession()
    if session.quarantined["DecorVendor"] or session.dismissed["DecorVendor"] then
        return false
    end
    local loaded = (C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" and C_AddOns.IsAddOnLoaded("DecorVendor"))
        or (type(_G.IsAddOnLoaded) == "function" and _G.IsAddOnLoaded("DecorVendor"))
    if loaded then
        return true
    end
    return DM:IsAddonEnabled("DecorVendor")
end

function DM:ShowRaidMarkerTaintModal(offendingAddon, reason)
    if IsModuleDisabledInSuite("DynamicMarker") or MarkerModuleDescriptor._disabledAtStartup then
        return
    end
    offendingAddon = SafeReadableString(offendingAddon)
    if not offendingAddon or offendingAddon == "" then
        local dvLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("DecorVendor"))
        offendingAddon = dvLoaded and "DecorVendor" or "Unknown Addon"
    end

    if _G.DynamicSuite and type(_G.DynamicSuite.ShowRaidMarkerTaintModal) == "function" then
        pcall(_G.DynamicSuite.ShowRaidMarkerTaintModal, _G.DynamicSuite, offendingAddon, reason)
        return
    end

    local session = GetSharedRaidTaintSession()
    if session.dismissed[offendingAddon] then
        return
    end
    if session.quarantined[offendingAddon] and reason == "PROACTIVE" then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        self._pendingRaidTaintModal = { addon = offendingAddon, reason = reason or "FORBIDDEN" }
        return
    end
    self._pendingRaidTaintModal = nil

    local modal = _G.DynamicSuiteRaidTaintModal
    if not modal then
        modal = CreateFrame("Frame", "DynamicSuiteRaidTaintModal", UIParent, "BackdropTemplate")
        modal:SetSize(484, 226)
        modal:SetPoint("CENTER", UIParent, "CENTER", 0, 70)
        modal:SetFrameStrata("DIALOG")
        modal:SetFrameLevel(275)
        modal:SetToplevel(true)
        modal:SetClampedToScreen(true)
        modal:SetMovable(true)
        modal:EnableMouse(true)
        modal:RegisterForDrag("LeftButton")
        modal:SetScript("OnDragStart", modal.StartMoving)
        modal:SetScript("OnDragStop", modal.StopMovingOrSizing)
        if modal.SetBackdrop then
            modal:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            -- Midnight Pitch Black (#06070A / alpha 0.98) + 1px dark slate border (#333D4F)
            modal:SetBackdropColor(0.024, 0.027, 0.039, 0.98)
            modal:SetBackdropBorderColor(0.200, 0.240, 0.310, 0.96)
        end

        modal.InnerSurface = CreateFrame("Frame", nil, modal, "BackdropTemplate")
        modal.InnerSurface:SetPoint("TOPLEFT", modal, "TOPLEFT", 14, -44)
        modal.InnerSurface:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -14, 54)
        if modal.InnerSurface.SetBackdrop then
            modal.InnerSurface:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            -- Obsidian Core inner card (#090A0D)
            modal.InnerSurface:SetBackdropColor(0.035, 0.039, 0.051, 0.96)
            modal.InnerSurface:SetBackdropBorderColor(0.145, 0.169, 0.216, 0.85)
        end

        modal.TopAccent = modal:CreateTexture(nil, "OVERLAY")
        modal.TopAccent:SetHeight(2)
        modal.TopAccent:SetPoint("TOPLEFT", modal, "TOPLEFT", 1, -1)
        modal.TopAccent:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -1, -1)
        modal.TopAccent:SetColorTexture(0.976, 0.451, 0.086, 1.0)

        modal.Title = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        modal.Title:SetPoint("TOPLEFT", modal, "TOPLEFT", 16, -15)
        modal.Title:SetText("|cFFF97316Raid Marker Blocked by Addon Conflict|r")

        modal.Body = modal.InnerSurface:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        modal.Body:SetPoint("TOPLEFT", modal.InnerSurface, "TOPLEFT", 12, -11)
        modal.Body:SetPoint("TOPRIGHT", modal.InnerSurface, "TOPRIGHT", -12, -11)
        modal.Body:SetJustifyH("LEFT")
        modal.Body:SetJustifyV("TOP")
        modal.Body:SetSpacing(3)
        modal.Body:SetTextColor(0.886, 0.910, 0.941, 1.0)

        local function CreateTaintModalButton(parent, label, width, height, styleMode)
            local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
            btn:SetSize(width, height)
            if btn.SetBackdrop then
                btn:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 1,
                })
            end
            btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btn.Text:SetPoint("CENTER", btn, "CENTER", 0, 0)
            btn.Text:SetText(label)
            btn._styleMode = styleMode or "PRIMARY"

            function btn:ApplyVisualState(hover)
                if not self.SetBackdropColor then return end
                if self._styleMode == "EMERALD" then
                    if hover then
                        self:SetBackdropColor(0.055, 0.260, 0.180, 1.0)
                        self:SetBackdropBorderColor(0.063, 0.725, 0.506, 1.0)
                        self.Text:SetTextColor(1.0, 1.0, 1.0, 1.0)
                    else
                        self:SetBackdropColor(0.035, 0.165, 0.115, 0.98)
                        self:SetBackdropBorderColor(0.063, 0.725, 0.506, 0.95)
                        self.Text:SetTextColor(0.204, 0.827, 0.600, 1.0)
                    end
                elseif self._styleMode == "PRIMARY" then
                    if hover then
                        self:SetBackdropColor(0.350, 0.160, 0.035, 1.0)
                        self:SetBackdropBorderColor(0.976, 0.451, 0.086, 1.0)
                        self.Text:SetTextColor(1.0, 1.0, 1.0, 1.0)
                    else
                        self:SetBackdropColor(0.220, 0.100, 0.022, 0.98)
                        self:SetBackdropBorderColor(0.976, 0.451, 0.086, 0.95)
                        self.Text:SetTextColor(0.976, 0.451, 0.086, 1.0)
                    end
                else
                    if hover then
                        self:SetBackdropColor(0.120, 0.145, 0.195, 1.0)
                        self:SetBackdropBorderColor(0.320, 0.380, 0.480, 1.0)
                        self.Text:SetTextColor(1.0, 1.0, 1.0, 1.0)
                    else
                        self:SetBackdropColor(0.055, 0.067, 0.094, 0.98)
                        self:SetBackdropBorderColor(0.200, 0.240, 0.310, 0.95)
                        self.Text:SetTextColor(0.796, 0.835, 0.882, 1.0)
                    end
                end
            end
            btn:ApplyVisualState(false)
            btn:SetScript("OnEnter", function(s) s:ApplyVisualState(true) end)
            btn:SetScript("OnLeave", function(s) s:ApplyVisualState(false) end)
            return btn
        end

        modal.PrimaryBtn = CreateTaintModalButton(modal, "Disable DecorVendor (Set to Never)", 260, 28, "PRIMARY")
        modal.DismissBtn = CreateTaintModalButton(modal, "Dismiss", 108, 28, "SECONDARY")

        modal:HookScript("OnHide", function(selfModal)
            if selfModal._activeAddon then
                local s = GetSharedRaidTaintSession()
                s.dismissed[selfModal._activeAddon] = true
            end
        end)

        if type(_G.UISpecialFrames) == "table" then
            local found = false
            for i = 1, #_G.UISpecialFrames do
                if _G.UISpecialFrames[i] == "DynamicSuiteRaidTaintModal" then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(_G.UISpecialFrames, "DynamicSuiteRaidTaintModal")
            end
        end
    end

    modal._activeAddon = offendingAddon
    local canQuarantine = (offendingAddon ~= "Unknown Addon")
    local alreadyQuarantined = (session.quarantined[offendingAddon] == true)

    if alreadyQuarantined then
        modal.TopAccent:SetColorTexture(0.063, 0.725, 0.506, 1.0)
        modal.Title:SetText("|cFF34D399Raid Marker Blocked by Addon Conflict|r")
        modal.Body:SetText(string.format(
            "|cFFFFFFFF%s|r is already set to Never for your next session, however Blizzard's raid-marker security lockout remains active until World of Warcraft restarts.\n\nPlease completely |cFFF97316Exit & Restart|r the game client now (a |cFFFFFFFF/reload|r alone will not clear the lockout).",
            offendingAddon
        ))
        modal.DismissBtn:Hide()
        modal.PrimaryBtn._styleMode = "EMERALD"
        modal.PrimaryBtn.Text:SetText("Understood (Close)")
        modal.PrimaryBtn:SetWidth(176)
        modal.PrimaryBtn:ClearAllPoints()
        modal.PrimaryBtn:SetPoint("BOTTOM", modal, "BOTTOM", 0, 14)
        modal.PrimaryBtn:ApplyVisualState(false)
        modal.PrimaryBtn:Show()
        modal.PrimaryBtn:SetScript("OnClick", function()
            session.dismissed[offendingAddon] = true
            modal:Hide()
        end)
    else
        modal.TopAccent:SetColorTexture(0.976, 0.451, 0.086, 1.0)
        modal.Title:SetText("|cFFF97316Raid Marker Blocked by Addon Conflict|r")
        local displayLabel = (offendingAddon == "DecorVendor") and "Decor Vendor (DecorVendor)" or offendingAddon
        modal.Body:SetText(string.format(
            "|cFFFFFFFF%s|r taints Blizzard's |cFFFFFFFF/tm|r raid marker command (|cFFFFFFFFSetRaidTarget()|r), causing action-bar focus markers to be blocked.\n\nBecause of how World of Warcraft's security engine works, you must disable |cFFFFFFFF%s|r and |cFFF97316fully Exit & Restart the game client|r (a |cFFFFFFFF/reload|r alone will not clear the lockout).",
            displayLabel, offendingAddon
        ))

        modal.DismissBtn:ClearAllPoints()
        modal.DismissBtn:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -14, 14)
        modal.DismissBtn:Show()
        modal.DismissBtn:SetScript("OnClick", function()
            session.dismissed[offendingAddon] = true
            modal:Hide()
        end)

        if canQuarantine then
            local pLabel = string.format("Disable %s (Set to Never)", offendingAddon)
            modal.PrimaryBtn._styleMode = "PRIMARY"
            modal.PrimaryBtn.Text:SetText(pLabel)
            local tw = (modal.PrimaryBtn.Text.GetStringWidth and modal.PrimaryBtn.Text:GetStringWidth()) or 230
            modal.PrimaryBtn:SetWidth(math.max(236, math.min(336, math.ceil(tw + 26))))
            modal.PrimaryBtn:ClearAllPoints()
            modal.PrimaryBtn:SetPoint("RIGHT", modal.DismissBtn, "LEFT", -8, 0)
            modal.PrimaryBtn:ApplyVisualState(false)
            modal.PrimaryBtn:Show()
            modal.PrimaryBtn:SetScript("OnClick", function()
                local pName = UnitName and UnitName("player") or nil
                if C_AddOns and C_AddOns.DisableAddOn then
                    if pName then pcall(C_AddOns.DisableAddOn, offendingAddon, pName) end
                    pcall(C_AddOns.DisableAddOn, offendingAddon)
                end
                if Suite and type(Suite.SetAddonFrozen) == "function" then
                    pcall(Suite.SetAddonFrozen, offendingAddon, true)
                end
                if type(FreezeAddonInLoadDB) == "function" then
                    FreezeAddonInLoadDB(offendingAddon)
                end
                if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.global) == "table" then
                    _G.DynamicSuiteDB.global.acknowledgedConflicts = _G.DynamicSuiteDB.global.acknowledgedConflicts or {}
                    _G.DynamicSuiteDB.global.acknowledgedConflicts[tostring(offendingAddon) .. "_DynamicMarker"] = "USE_DYNAMIC"
                end
                session.quarantined[offendingAddon] = true
                DM.pendingConflictReload = offendingAddon
                DM:ScanConflicts()
                DM:RefreshAll()
                modal.TopAccent:SetColorTexture(0.063, 0.725, 0.506, 1.0)
                modal.Title:SetText("|cFF34D399" .. offendingAddon .. " Disabled (Set to Never)|r")
                modal.Body:SetText(string.format(
                    "|cFFFFFFFF%s|r has been disabled and set to |cFF34D399Never|r across all zone profiles.\n\nPlease |cFFF97316completely Exit & Restart World of Warcraft|r now to clear Blizzard's raid-marker lockout (a |cFFFFFFFF/reload|r alone will not clear it).",
                    offendingAddon
                ))
                modal.DismissBtn:Hide()
                modal.PrimaryBtn._styleMode = "EMERALD"
                modal.PrimaryBtn.Text:SetText("Understood (Close)")
                modal.PrimaryBtn:SetWidth(176)
                modal.PrimaryBtn:ClearAllPoints()
                modal.PrimaryBtn:SetPoint("BOTTOM", modal, "BOTTOM", 0, 14)
                modal.PrimaryBtn:ApplyVisualState(false)
                modal.PrimaryBtn:SetScript("OnClick", function()
                    session.dismissed[offendingAddon] = true
                    modal:Hide()
                end)
                print(string.format(
                    "|cFF38BDF8DynamicMarker|r: Disabled |cFFFFFFFF%s|r and set it to |cFF34D399Never|r across all zone profiles. Please completely Exit & Restart World of Warcraft now (/reload alone will not clear SetRaidTarget taint).",
                    offendingAddon
                ))
            end)
        else
            modal.PrimaryBtn:Hide()
        end
    end

    modal:Show()
    modal:Raise()
end

local function EnforceSuiteDuplicateExclusion(showPopupIfLoaded)
    if ADDON_FOLDER == "DynamicSuite" then return false end
    local isSuiteActive = (C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" and C_AddOns.IsAddOnLoaded("DynamicSuite"))
        or (type(_G.IsAddOnLoaded) == "function" and _G.IsAddOnLoaded("DynamicSuite"))
        or (_G.DynamicSuite and _G.DynamicSuite._isHubLoaded == true)
    if not isSuiteActive then return false end
    standaloneMarkerWasEnabledAtBoot = true
    _G.DynamicSuite_StandaloneMarkerWasEnabledAtBoot = true
    if _G.DynamicSuite then
        _G.DynamicSuite.standaloneMarkerWasEnabledAtBoot = true
        _G.DynamicSuite._standaloneMarkerConflictDetected = true
    end
    if C_AddOns and type(C_AddOns.DisableAddOn) == "function" then
        local pName = type(_G.UnitName) == "function" and _G.UnitName("player") or nil
        if type(pName) == "string" and pName ~= "" and pName ~= "Unknown" and pName ~= _G.UNKNOWNOBJECT then
            pcall(C_AddOns.DisableAddOn, ADDON_FOLDER, pName)
        end
        pcall(C_AddOns.DisableAddOn, ADDON_FOLDER)
    end
    if not (InCombatLockdown and InCombatLockdown()) then
        if DM.targetBar and DM.targetBar.Hide then DM.targetBar:Hide() end
        if DM.flareBar and DM.flareBar.Hide then DM.flareBar:Hide() end
        if DM.editInspector and DM.editInspector.Hide then DM.editInspector:Hide() end
        if DM.gridOverlay and DM.gridOverlay.Hide then DM.gridOverlay:Hide() end
    end
    if showPopupIfLoaded and (isInitialized or standaloneMarkerWasEnabledAtBoot) then
        DM:ShowMarkerConflictReloadModal()
    end
    return true
end

local taintAlertCooldowns = {}

local function SafeReadableString(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    if type(canaccessvalue) == "function" then
        local okAcc, canAcc = pcall(canaccessvalue, v)
        if okAcc and not canAcc then return nil end
    end
    local okStr, s = pcall(tostring, v)
    if not okStr then return nil end
    return s
end

local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("ADDON_LOADED")
evtFrame:RegisterEvent("PLAYER_LOGIN")
evtFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
evtFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
evtFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
evtFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
evtFrame:RegisterEvent("READY_CHECK")
evtFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
evtFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
evtFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
evtFrame:RegisterEvent("UPDATE_MACROS")
evtFrame:RegisterEvent("UPDATE_BINDINGS")
evtFrame:RegisterEvent("CVAR_UPDATE")
evtFrame:RegisterEvent("UI_SCALE_CHANGED")
evtFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
evtFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")

evtFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if ADDON_FOLDER ~= "DynamicSuite" then
        local isSuiteActive = (event == "ADDON_LOADED" and arg1 == "DynamicSuite")
            or (C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" and C_AddOns.IsAddOnLoaded("DynamicSuite"))
            or (type(_G.IsAddOnLoaded) == "function" and _G.IsAddOnLoaded("DynamicSuite"))
            or (_G.DynamicSuite and _G.DynamicSuite._isHubLoaded == true)
        if isSuiteActive then
            if event == "PLAYER_ENTERING_WORLD" then
                hasEnteredWorld = true
            end
            EnforceSuiteDuplicateExclusion(hasEnteredWorld or event == "PLAYER_ENTERING_WORLD")
            if hasEnteredWorld or event == "PLAYER_ENTERING_WORLD" then
                evtFrame:UnregisterAllEvents()
            end
            return
        end
    end
    if event == "ADDON_ACTION_FORBIDDEN" then
        if IsModuleDisabledInSuite("DynamicMarker") or MarkerModuleDescriptor._disabledAtStartup then
            return
        end
        local blockedFn = SafeReadableString(arg2)
        if IsSetRaidTargetBlockedName(blockedFn) then
            local offender = SafeReadableString(arg1)
            if not offender or offender == "" then
                local dvLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("DecorVendor"))
                offender = dvLoaded and "DecorVendor" or "Unknown Addon"
            end
            local now = (type(GetTime) == "function" and GetTime()) or 0
            local lastAlert = taintAlertCooldowns[offender]
            if not lastAlert or (now - lastAlert) >= 30 then
                taintAlertCooldowns[offender] = now
                print(string.format(
                    "|cFF38BDF8DynamicMarker|r: |cFFF5B82EBlocked Action:|r |cFFFFFFFF%s|r tainted Blizzard's |cFFFFFFFF/tm|r raid marker command (SetRaidTarget) -- this is caused by |cFFFFFFFF%s|r, not DynamicMarker. Disable |cFFFFFFFF%s|r (Set to Never) and completely exit and restart the game client (/reload alone will not clear Blizzard's raid-marker lockout).",
                    offender, offender, offender
                ))
            end
            DM:ShowRaidMarkerTaintModal(offender, "FORBIDDEN")
        end
        return
    end
    if event == "ADDON_LOADED" then
        if (arg1 == ADDON_FOLDER or arg1 == "DynamicMarker") and not isInitialized then
            isInitialized = true
            DM:InitDB()
            Suite.modules["marker"] = MarkerModuleDescriptor
            Suite.modules["DynamicMarker"] = MarkerModuleDescriptor
            if IsModuleDisabledInSuite("DynamicMarker") then
                MarkerModuleDescriptor._disabledAtStartup = true
                evtFrame:UnregisterAllEvents()
                return
            end
            DM:InitTargetBar()
            DM:InitFlareBar()
            DM:RegisterWithSuiteHudEditMode()
            if type(_G.FocusMarkerDB) == "table" then
                DM:CaptureFocusMarkerSnapshot()
                if not DM.db.migratedFromFocusMarker then
                    local okM = DM:MigrateFromFocusMarker(false)
                    if okM then
                        print("|cFF38BDF8DynamicMarker|r: Imported settings from FocusMarker.")
                    end
                end
            end
        elseif arg1 == "FocusMarker" and isInitialized and DM.db and not MarkerModuleDescriptor._disabledAtStartup then
            if type(_G.FocusMarkerDB) == "table" then
                DM:CaptureFocusMarkerSnapshot()
                if not DM.db.migratedFromFocusMarker then
                    local okM = DM:MigrateFromFocusMarker(false)
                    if okM then
                        DM:RefreshTargetBar()
                        DM:RefreshFlareBar()
                        DM:RefreshAll()
                        print("|cFF38BDF8DynamicMarker|r: Imported settings from FocusMarker.")
                    end
                end
            end
        elseif _G.DynamicSuite and type(_G.DynamicSuite.RegisterHudEditCallback) == "function" and not DM._registeredSuiteHudCallback and isInitialized and not MarkerModuleDescriptor._disabledAtStartup then
            DM:RegisterWithSuiteHudEditMode()
        end

    elseif event == "PLAYER_LOGIN" then
        DM:InitDB()
        Suite.modules["marker"] = MarkerModuleDescriptor
        Suite.modules["DynamicMarker"] = MarkerModuleDescriptor
        if IsModuleDisabledInSuite("DynamicMarker") then
            MarkerModuleDescriptor._disabledAtStartup = true
            evtFrame:UnregisterAllEvents()
            if DM.targetBar and not (InCombatLockdown and InCombatLockdown()) then DM.targetBar:Hide() end
            if DM.flareBar and not (InCombatLockdown and InCombatLockdown()) then DM.flareBar:Hide() end
            return
        end

        -- 1. FocusMarker -> DynamicMarker SavedVariables Bridge
        --    Capture a persistent snapshot whenever FocusMarkerDB is loaded, then auto-import once.
        if type(_G.FocusMarkerDB) == "table" then
            DM:CaptureFocusMarkerSnapshot()
            if not DM.db.migratedFromFocusMarker then
                local okM = DM:MigrateFromFocusMarker(false)
                if okM then
                    print("|cFF38BDF8DynamicMarker|r: Imported settings from FocusMarker.")
                end
            end
        elseif not DM.db.migratedFromFocusMarker and type(DM.db.legacyFocusMarker) ~= "table"
            and not DM.db.focusMarkerHintShown and DM:IsFocusMarkerInstalled() then
            DM.db.focusMarkerHintShown = true
            print("|cFF38BDF8DynamicMarker|r: FocusMarker is installed but disabled, so its settings cannot be read. Enable it for one /reload to import them automatically (or ignore to keep DynamicMarker defaults).")
        end

        -- 2. Scan for Active Conflicting Addons (FocusMarker, DejaMark, EasyMarker)
        DM:ScanConflicts()

        -- 3. Initialize Secure World Flare Keybinds & Floating HUD Bars
        -- (Controlled via encapsulated DynamicMarker HUD Edit Mode and registered with DynamicSuite when present)
        DM:InitSecureFlareButtons()
        DM:InitTargetBar()
        DM:InitFlareBar()
        DM:RefreshTargetBar()
        DM:RefreshFlareBar()
        DM:RegisterWithSuiteHudEditMode()

        -- 4. Sync existing macros out of combat (including seamless FocusMarker -> DynamicMark in-place migration)
        DM:CreateOrUpdateFocusMarkerMacro(false)
        if DM.db.kickSpecMode == "SMART_SWAP" then
            DM:CreateOrUpdateDynamicKickMacro(false)
        end

        DM:RefreshAll()
        DM:RegisterSettingsCategory()
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(1.5, function()
                if not DM.db then return end
                DM:ScanStandaloneFonts(true)
                DM:ApplyAllStandaloneFonts()
            end)
        end

    elseif event == "CVAR_UPDATE" then
        if arg1 == "ActionButtonUseKeyDown" then
            DM:RefreshAllSecureButtonClicks()
        end

    elseif event == "UPDATE_BINDINGS" then
        if not DM.db then return end
        DM:ApplyFlareKeybinds()

    elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_MACROS" then
        if DM.workspaceFrame and DM.workspaceFrame:IsShown() then
            DM:RefreshAll()
        end

    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        if not DM.db then return end
        if InCombatLockdown() then
            DM.pendingHUDPositionSync = true
        else
            DM:RefreshTargetBar()
            DM:RefreshFlareBar()
            DM:RefreshEditModeInspector()
        end

    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then
        if event == "PLAYER_ENTERING_WORLD" then
            hasEnteredWorld = true
        end
        if not DM.db then return end
        if event == "PLAYER_ENTERING_WORLD" then
            DM:InitSecureFlareButtons()
            DM:RefreshAllSecureButtonClicks()
            DM:SyncSecureFlareEngine()
            DM:ApplyFlareKeybinds()
            if IsDecorVendorActiveForStandaloneModal() then
                DM:ShowRaidMarkerTaintModal("DecorVendor", "PROACTIVE")
            end
        end
        if DM.db.kickSpecMode == "SMART_SWAP" then
            DM:CreateOrUpdateDynamicKickMacro(false)
        end
        DM:UpdateTargetBarVisibility()
        DM:UpdateFlareBarVisibility()
        DM:RefreshTargetBar()
        DM:RefreshFlareBar()
        DM:RefreshAll()
        if event == "PLAYER_ENTERING_WORLD" and C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0, function()
                if not DM.db then return end
                if InCombatLockdown and InCombatLockdown() then
                    DM.pendingHUDPositionSync = true
                else
                    DM:RefreshTargetBar()
                    DM:RefreshFlareBar()
                end
            end)
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        DM:UpdateTargetBarVisibility()
        DM:UpdateFlareBarVisibility()
        DM:RefreshTargetBar()
        DM:RefreshFlareBar()

    elseif event == "READY_CHECK" then
        DM:AnnounceFocusIcon(true)

    elseif event == "PLAYER_REGEN_DISABLED" then
        DM:CloseDropdownMenu()
        HideSnapGuides()
        if DM.targetBar then
            if DM.targetBar.editMover then
                DM.targetBar.editMover:SetScript("OnUpdate", nil)
            end
            DM.targetBar._dmDragging = false
            pcall(DM.targetBar.StopMovingOrSizing, DM.targetBar)
        end
        if DM.flareBar then
            if DM.flareBar.editMover then
                DM.flareBar.editMover:SetScript("OnUpdate", nil)
            end
            DM.flareBar._dmDragging = false
            pcall(DM.flareBar.StopMovingOrSizing, DM.flareBar)
        end
        if DM.editInspector then
            pcall(DM.editInspector.StopMovingOrSizing, DM.editInspector)
        end
        DM.isDraggingHUD = false
        if DM.isEditMode then
            DM:SetEditMode(false, { fromCombat = true })
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if DM._pendingMarkerConflictModal then
            DM:ShowMarkerConflictReloadModal()
        end
        if DM._pendingRaidTaintModal then
            local pend = DM._pendingRaidTaintModal
            DM._pendingRaidTaintModal = nil
            DM:ShowRaidMarkerTaintModal(pend.addon, pend.reason)
        end
        if DM.pendingSecureClickSync then
            DM:RefreshAllSecureButtonClicks()
        end
        if DM.pendingHUDPositionReset then
            DM:ResetHUDPositions(false)
        end
        if DM.pendingHUDPositionSync then
            DM.pendingHUDPositionSync = false
            DM:ApplyHUDPosition(DM.targetBar, "TargetBar", -140)
            DM:ApplyHUDPosition(DM.flareBar, "FlareBar", -182)
        end
        if DM.pendingFlareEngineSync then
            DM:SyncSecureFlareEngine()
        end
        if DM.pendingKeybindSync then
            DM:ApplyFlareKeybinds()
        end
        if DM.pendingBarVisibilityUpdate then
            DM.pendingBarVisibilityUpdate = false
            DM:UpdateTargetBarVisibility()
            DM:UpdateFlareBarVisibility()
        end
        if DM.pendingTargetBarSync then
            DM:RefreshTargetBar()
        end
        if DM.pendingFlareBarSync then
            DM:RefreshFlareBar()
        end
        if DM.pendingFocusMacroSync then
            DM:CreateOrUpdateFocusMarkerMacro(false)
        end
        if DM.pendingKickMacroSync then
            DM:CreateOrUpdateDynamicKickMacro(false)
        end
    end
end)

function DM:RegisterSettingsCategory()
    if ADDON_FOLDER == "DynamicSuite" or self._loadedBySuite then return end
    if _G.DynamicSuite and (_G.DynamicSuite.UI or _G.DynamicSuiteSettingsRegistered) then return end
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("DynamicSuite") then return end
    if _G.DynamicMarkerSettingsRegistered then return end
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end

    _G.DynamicMarkerSettingsRegistered = true
    local panel = CreateFrame("Frame", "DynamicMarkerSettingsCanvas", UIParent)
    panel.name = "DynamicMarker"

    local ar, ag, ab, accentHex = self:GetAccentColor()
    local card = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    card:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    card:SetSize(560, 210)
    self:ApplyBackdrop(card, COLORS.BgCanvas, { r = ar, g = ag, b = ab, a = 0.75 }, 1)

    local logoWhite = card:CreateTexture(nil, "ARTWORK", nil, 0)
    logoWhite:SetSize(28, 28)
    logoWhite:SetPoint("TOPLEFT", card, "TOPLEFT", 18, -18)
    logoWhite:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_white.tga")
    logoWhite:SetVertexColor(0.96, 0.97, 0.99, 1.0)

    local logoAccent = card:CreateTexture(nil, "ARTWORK", nil, 1)
    logoAccent:SetAllPoints(logoWhite)
    logoAccent:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_accent.tga")
    logoAccent:SetVertexColor(ar, ag, ab, 1.0)

    local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", logoWhite, "RIGHT", 10, 0)
    self:StyleFont(title, 16, "", COLORS.TextPrimary)
    title:SetText(string.format("|cFF%sDynamic|r|cFFFFFFFFMarker|r  |cff94a3b8v%s|r", accentHex, self.version or VERSION))

    local desc = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", logoWhite, "BOTTOMLEFT", 0, -14)
    desc:SetWidth(520)
    desc:SetJustifyH("LEFT")
    self:StyleFont(desc, 12, "", COLORS.TextSilver)
    desc:SetText("Raid target icons, world flare keybinds, floating HUD bars, and smart focus/interrupt macro engine.")

    local slashSummary = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    slashSummary:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    slashSummary:SetWidth(520)
    slashSummary:SetJustifyH("LEFT")
    self:StyleFont(slashSummary, 11, "", COLORS.TextMuted)
    slashSummary:SetText("Slash Commands:  /dm (Open)   |   /dm hud (HUD Edit)   |   /dm resethud (Reset HUDs)")

    local function HideSettingsPanelSafe()
        if InCombatLockdown and InCombatLockdown() then return end
        if SettingsPanel and SettingsPanel:IsShown() then
            if type(_G.HideUIPanel) == "function" then
                pcall(_G.HideUIPanel, SettingsPanel)
            end
            if SettingsPanel:IsShown() and SettingsPanel.Hide then
                pcall(SettingsPanel.Hide, SettingsPanel)
            end
        end
        if GameMenuFrame and GameMenuFrame:IsShown() and GameMenuFrame.Hide then
            pcall(GameMenuFrame.Hide, GameMenuFrame)
        end
    end

    local openBtn = self:CreateButton(card, "Open DynamicMarker", 162, 32, function()
        HideSettingsPanelSafe()
        self:OpenWindow()
        if self.shellFrame and self.shellFrame.Raise then
            self.shellFrame:Raise()
        end
    end, true)
    openBtn:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 18, 18)

    local hudBtn = self:CreateButton(card, "HUD Edit Mode (/dm hud)", 174, 32, function()
        HideSettingsPanelSafe()
        self:ToggleHudEditMode()
    end, false)
    hudBtn:SetPoint("LEFT", openBtn, "RIGHT", 10, 0)

    local resetHudBtn = self:CreateButton(card, "Reset HUD Positions", 168, 32, function()
        self:ResetHUDPositions(false)
    end, false)
    resetHudBtn:SetPoint("LEFT", hudBtn, "RIGHT", 10, 0)

    panel:SetScript("OnShow", function()
        local cr, cg, cb, cHex = self:GetAccentColor()
        local surf = GetStandaloneSurfaceColors(self)
        self:ApplyBackdrop(card, surf.panel, { r = cr, g = cg, b = cb, a = 0.75 }, 1)
        logoAccent:SetVertexColor(cr, cg, cb, 1.0)
        title:SetText(string.format("|cFF%sDynamic|r|cFFFFFFFFMarker|r  |cff94a3b8v%s|r", cHex, self.version or VERSION))
    end)

    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "DynamicMarker")
    if ok and category then
        pcall(Settings.RegisterAddOnCategory, category)
        _G.DynamicMarkerSettingsCategoryID = category.GetID and category:GetID() or nil
    end
end

function _G.DynamicMarker_OnAddonCompartmentClick(_, buttonName)
    if buttonName == "RightButton" then
        DM:ToggleHudEditMode()
    elseif _G.DynamicSuite and type(_G.DynamicSuite.OpenModule) == "function" then
        _G.DynamicSuite:OpenModule("DynamicMarker")
    else
        DM:OpenWindow()
    end
end
