-- ============================================================================
-- DynamicFPS v1.4.2 (/dfps)
-- Zero-Reload Zone Graphics Guard, Combat FPS Governor, SpellQueue Tuner & UI Declutter
-- World of Warcraft Retail (12.1.5, Interface 120105)
-- Author: Dentee | Category: DynamicSuite
-- Strict Pure ASCII (NonASCII: 0, HasBOM: False)
-- ============================================================================

local addonName = ...
local ADDON_FOLDER = (type(addonName) == "string" and addonName ~= "") and addonName or "DynamicSuite"

local function ResolveAddonVersion(folderName, fallback)
    local fb = fallback or "1.9.9"
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
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
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
        end
        return false
    end
    if addonFolder ~= "DynamicSuite" then
        if type(globalTbl) == "table" and globalTbl._loadedBySuite then
            local suiteVer = globalTbl._loadedVersion or globalTbl.version or (_G.DynamicSuite and _G.DynamicSuite.version) or "1.9.9"
            if CompareSemVer(thisVersion, suiteVer) <= 0 then
                return true
            end
        end
        if isOtherEnabled("DynamicSuite") and type(getMeta) == "function" then
            local okS, sVer = pcall(getMeta, "DynamicSuite", "Version")
            if okS and type(sVer) == "string" and sVer ~= "" and not sVer:find("@") then
                if CompareSemVer(thisVersion, sVer) <= 0 then
                    return true
                end
            end
        end
    else
        if type(globalTbl) == "table" and globalTbl._loadedBySuite == false then
            local stLoadedVer = globalTbl._loadedVersion or globalTbl.version or "0.0.0"
            if CompareSemVer(stLoadedVer, thisVersion) >= 0 then
                return true
            end
        end
        if isOtherEnabled(standaloneName) and type(getMeta) == "function" then
            local okV, stVer = pcall(getMeta, standaloneName, "Version")
            if okV and type(stVer) == "string" and stVer ~= "" and not stVer:find("@") then
                if CompareSemVer(stVer, thisVersion) > 0 then
                    return true
                end
            end
        end
    end
    return false
end

local ADDON_VERSION = ResolveAddonVersion(ADDON_FOLDER, "1.9.9")
if ShouldYieldToOtherInstall(ADDON_FOLDER, "DynamicFPS", ADDON_VERSION, _G.DynamicFPS) then
    return
end
local DFPS_NS = {}
local DynamicFPS = _G.DynamicFPS or DFPS_NS
_G.DynamicFPS = DynamicFPS
DynamicFPS._loadedBySuite = (ADDON_FOLDER == "DynamicSuite")
DynamicFPS._loadedVersion = ADDON_VERSION
DynamicFPS.version = ADDON_VERSION
local isInitialized = false

local function IsModuleDisabledInSuite(modName)
    local key = modName or "DynamicFPS"
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

local function _IsSecret(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return true end
    if canaccessvalue and not canaccessvalue(v) then return true end
    return false
end

local function _SafeNum(val, fallback)
    if val == nil or _IsSecret(val) then return fallback or 0 end
    if type(val) == "number" then
        local okArith = pcall(function() return val + 0 end)
        return okArith and val or (fallback or 0)
    end
    local ok, num = pcall(tonumber, val)
    if ok and type(num) == "number" and not _IsSecret(num) then
        local okArith = pcall(function() return num + 0 end)
        if okArith then return num end
    end
    return fallback or 0
end

local function _SafeNumber(v, fallback)
    return _SafeNum(v, fallback)
end

local _dfpsCachedHaste = 0
local _dfpsCachedPing  = 28

local ADDON_TITLE_COLORED = "|cFFCBD5E1Dynamic|r|cFFFFFFFFFPS|r"

_G.DynamicSuite = _G.DynamicSuite or {
    version = ADDON_VERSION,
    modules = {},
    Changelogs = {},
}
_G.DynamicSuite.modules = _G.DynamicSuite.modules or {}
_G.DynamicSuite.Changelogs = _G.DynamicSuite.Changelogs or {}

-- Media Icon Paths (Arty's Studio Vector Icons)
local ICON_CHECK        = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_check.tga"
local ICON_CHEVRON_DOWN = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga"
local ICON_CHEVRON_UP   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga"
local ICON_COG          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_cog.tga"
local CHECK_INLINE_TAG  = "|T" .. ICON_CHECK .. ":11:11:0:0|t "

-- ============================================================================
-- 1. ZONE DEFINITIONS, STARTER PRESETS & DEFAULT SAVEDVARIABLES
-- ============================================================================
local LEFT_ZONE_TABS = {
    { id = "OUTDOOR",  label = "Outdoor",  fullLabel = "Outdoor (Open World)" },
    { id = "CITIES",   label = "Cities",   fullLabel = "Capital Cities (Dornogal / Hubs)" },
    { id = "DELVES",   label = "Delves",   fullLabel = "Delves & Scenarios" },
    { id = "DUNGEONS", label = "Dungeons", fullLabel = "Mythic+ & 5-Man Dungeons" },
    { id = "RAID",     label = "Raid",     fullLabel = "20-30 Man Raid Instances" },
    { id = "PVP",      label = "PvP",      fullLabel = "Arenas & Battlegrounds" },
}

local ZONE_NAMES = {
    OUTDOOR  = "Outdoor",
    CITIES   = "Cities",
    DELVES   = "Delves",
    DUNGEONS = "Dungeons",
    RAID     = "Raid",
    PVP      = "PvP",
}

-- Capital City MapIDs for Urban Draw-Call Protection
local CAPITAL_CITY_MAP_IDS = {
    [2339] = true, -- Dornogal
    [110]  = true, -- Silvermoon City
    [2112] = true, -- Valdrakken
    [1670] = true, -- Oribos
    [84]   = true, -- Stormwind City
    [85]   = true, -- Orgrimmar
    [86]   = true, -- Thunder Bluff
    [87]   = true, -- Ironforge
    [88]   = true, -- Darnassus
    [89]   = true, -- Undercity
    [103]  = true, -- The Exodar
    [1161] = true, -- Boralus
    [1165] = true, -- Dazar'alor
    [125]  = true, -- Dalaran (Broken Isles)
    [627]  = true, -- Dalaran (Northrend)
    [70]   = true, -- Shattrath City
}

-- 4 Starter Preset Templates ("LOW", "BALANCED", "COMPETITIVE", "ULTRA")
-- Mirrors Blizzard's Retail 12.1.5 Base Game Quality Menu 1:1
-- CRITICAL INVARIANT: projectedTextures = 1 is HARD-LOCKED in every preset
local STARTER_PRESETS = {
    LOW = {
        key = "LOW",
        label = "Low-End PC",
        overallQuality = 1,
        shadowQuality = 0,          -- Low
        liquidDetail = 0,           -- Low
        particleDensity = 1,        -- Low (never Disabled so swirlies remain visible)
        ssao = 0,                   -- Disabled
        depthEffects = 0,           -- Disabled
        computeEffects = 0,         -- Disabled
        outlineMode = 1,            -- Good
        textureResolution = 0,      -- Low
        spellDensity = "ESSENTIAL", -- Essential
        viewDistance = 2,           -- 2 / 10
        environmentDetail = 2,      -- 2 / 10
        groundClutter = 1,          -- 1 / 10
        friendlyNameplatesPvE = false,
        targetSilhouette = true,
        projectedTexturesLocked = true,
    },
    BALANCED = {
        key = "BALANCED",
        label = "Balanced",
        overallQuality = 5,
        shadowQuality = 1,          -- Fair
        liquidDetail = 1,           -- Fair
        particleDensity = 3,        -- Good
        ssao = 1,                   -- Low
        depthEffects = 1,           -- Low
        computeEffects = 1,         -- Low
        outlineMode = 2,            -- High
        textureResolution = 2,      -- High
        spellDensity = "REDUCED",   -- Reduced (Blizzard Recommended)
        viewDistance = 6,           -- 6 / 10
        environmentDetail = 6,      -- 6 / 10
        groundClutter = 5,          -- 5 / 10
        friendlyNameplatesPvE = false,
        targetSilhouette = true,
        projectedTexturesLocked = true,
    },
    COMPETITIVE = {
        key = "COMPETITIVE",
        label = "Competitive FPS",
        overallQuality = 3,
        shadowQuality = 0,          -- Low
        liquidDetail = 0,           -- Low
        particleDensity = 3,        -- Good
        ssao = 0,                   -- Disabled
        depthEffects = 0,           -- Disabled
        computeEffects = 0,         -- Disabled
        outlineMode = 2,            -- High
        textureResolution = 2,      -- High
        spellDensity = "ESSENTIAL", -- Essential in Raid/Cities/PvP, Reduced in Dungeons/Delves
        viewDistance = 5,           -- 5 / 10
        environmentDetail = 5,      -- 5 / 10
        groundClutter = 3,          -- 3 / 10
        friendlyNameplatesPvE = false,
        targetSilhouette = true,
        projectedTexturesLocked = true,
    },
    ULTRA = {
        key = "ULTRA",
        label = "High-End Ultra",
        overallQuality = 10,
        shadowQuality = 4,          -- Ultra
        liquidDetail = 3,           -- High
        particleDensity = 5,        -- Ultra
        ssao = 4,                   -- Ultra
        depthEffects = 3,           -- High
        computeEffects = 4,         -- Ultra
        outlineMode = 2,            -- High
        textureResolution = 2,      -- High
        spellDensity = "EVERYTHING",-- Everything
        viewDistance = 10,          -- 10 / 10
        environmentDetail = 10,     -- 10 / 10
        groundClutter = 10,         -- 10 / 10
        friendlyNameplatesPvE = true,
        targetSilhouette = true,
        projectedTexturesLocked = true,
    },
}

local DEFAULT_DB = {
    version = ADDON_VERSION,
    enabled = true,
    activeTab = "RAID",

    -- Item #13: Per-Zone Active Preset Tracker ("LOW", "BALANCED", "COMPETITIVE", "ULTRA", "SAVED_BASE", "CUSTOM")
    activePresets = {
        OUTDOOR  = "ULTRA",
        CITIES   = "COMPETITIVE",
        DELVES   = "BALANCED",
        DUNGEONS = "COMPETITIVE",
        RAID     = "COMPETITIVE",
        PVP      = "COMPETITIVE",
    },

    -- Per-Zone 6-Context Graphics Matrix (1:1 Blizzard Base Game Quality Menu)
    zones = {
        OUTDOOR = {
            overallQuality = 10,
            shadowQuality = 4,
            liquidDetail = 3,
            particleDensity = 5,
            ssao = 4,
            depthEffects = 3,
            computeEffects = 4,
            outlineMode = 2,
            textureResolution = 2,
            spellDensity = "EVERYTHING",
            viewDistance = 10,
            environmentDetail = 10,
            groundClutter = 10,
            friendlyNameplatesPvE = true,
            targetSilhouette = true,
            projectedTexturesLocked = true,
        },
        CITIES = {
            overallQuality = 3,
            shadowQuality = 0,
            liquidDetail = 0,
            particleDensity = 3,
            ssao = 0,
            depthEffects = 0,
            computeEffects = 0,
            outlineMode = 2,
            textureResolution = 2,
            spellDensity = "ESSENTIAL",
            viewDistance = 5,
            environmentDetail = 5,
            groundClutter = 3,
            friendlyNameplatesPvE = false,
            targetSilhouette = true,
            projectedTexturesLocked = true,
        },
        DELVES = {
            overallQuality = 5,
            shadowQuality = 1,
            liquidDetail = 1,
            particleDensity = 3,
            ssao = 1,
            depthEffects = 1,
            computeEffects = 1,
            outlineMode = 2,
            textureResolution = 2,
            spellDensity = "REDUCED",
            viewDistance = 6,
            environmentDetail = 6,
            groundClutter = 5,
            friendlyNameplatesPvE = false,
            targetSilhouette = true,
            projectedTexturesLocked = true,
        },
        DUNGEONS = {
            overallQuality = 3,
            shadowQuality = 0,
            liquidDetail = 0,
            particleDensity = 3,
            ssao = 0,
            depthEffects = 0,
            computeEffects = 0,
            outlineMode = 2,
            textureResolution = 2,
            spellDensity = "REDUCED",
            viewDistance = 5,
            environmentDetail = 5,
            groundClutter = 3,
            friendlyNameplatesPvE = false,
            targetSilhouette = true,
            projectedTexturesLocked = true,
        },
        RAID = {
            overallQuality = 3,
            shadowQuality = 0,
            liquidDetail = 0,
            particleDensity = 3,
            ssao = 0,
            depthEffects = 0,
            computeEffects = 0,
            outlineMode = 2,
            textureResolution = 2,
            spellDensity = "ESSENTIAL",
            viewDistance = 5,
            environmentDetail = 5,
            groundClutter = 3,
            friendlyNameplatesPvE = false,
            targetSilhouette = true,
            projectedTexturesLocked = true,
        },
        PVP = {
            overallQuality = 3,
            shadowQuality = 0,
            liquidDetail = 0,
            particleDensity = 3,
            ssao = 0,
            depthEffects = 0,
            computeEffects = 0,
            outlineMode = 2,
            textureResolution = 2,
            spellDensity = "ESSENTIAL",
            viewDistance = 5,
            environmentDetail = 5,
            groundClutter = 3,
            friendlyNameplatesPvE = false,
            targetSilhouette = true,
            projectedTexturesLocked = true,
        },
    },

    -- FPS Guard & Queue Tab Settings (Direction A + Hybrid Inline Sub-Drawers)
    autoZoneSwitch = true,                  -- Binary Switch: Enable DynamicFPS Zone Engine
    fpsGuardEnabled = true,                 -- Binary Switch: Dynamic Emergency FPS Guard
    fpsGuardDrawerOpen = true,              -- Sub-Drawer Tune Toggle: Dynamic Emergency FPS Guard
    targetFPSFloor = 60,                    -- 4-Pill Segmented: 60, 90, 120, 144 FPS
    autoTuneSpellQueue = true,              -- Legacy Binary Switch: Auto-Tune SpellQueueWindow
    spellQueueMode = "SMART_AUTO",          -- 3-Pill Segmented: "SMART_AUTO", "CUSTOM_MANUAL", "BLIZZARD_DEFAULT"
    spellQueueManualMS = 180,               -- Custom Manual Slider: 50..400 ms (step 5)
    spellQueueDrawerOpen = true,            -- Sub-Drawer Tune Toggle: Auto-Tune SpellQueueWindow
    spellQueueOffset = 100,                 -- Legacy Sub-drawer Slider: Ping Padding (+ms) 50..200

    maxForegroundFPS = 0,                   -- 5+ Option Dropdown: 0 (Uncapped), 60, 120, 144, 165, 240
    maxBackgroundFPS = 30,                  -- 5+ Option Dropdown: 0, 15, 30, 60, 90
    combatLogAutoPurge = "RAID_AND_MPLUS",  -- 5+ Option Dropdown
    questTrackerMode = "COLLAPSE_MPLUS_RAID", -- 5+ Option Dropdown
    declutterAudioMode = "MUTE_SPEECH_ONLY", -- 3-Pill Segmented: "DEFAULT", "MUTE_SPEECH_ONLY", "MUTE_ALL"

    savedBaselineCVars = nil,
    conflictResolutions = {},
}

local DEFAULT_SUITE_GLOBAL = {
    width = 980,
    height = 680,
    scale = 1.0,
    opacity = 0.98,
    accentMode = "CLASS",
    surfacePreset = "OBSIDIAN",
    fontKey = "FRIZQT",
}

-- ============================================================================
-- 2. DIRECTION A OPTIONS CATALOG (1:1 BLIZZARD BASE GAME QUALITY LABELS)
-- ============================================================================

-- Blizzard Shadow Quality: Low (0), Fair (1), Good (2), High (3), Ultra (4)
local SHADOW_PILL_OPTIONS = {
    { value = 0, label = "Low" },
    { value = 1, label = "Fair" },
    { value = 2, label = "Good" },
    { value = 3, label = "High" },
    { value = 4, label = "Ultra" },
}

-- Blizzard Liquid Detail: Low (0), Fair (1), Good (2), High (3)
local LIQUID_PILL_OPTIONS = {
    { value = 0, label = "Low" },
    { value = 1, label = "Fair" },
    { value = 2, label = "Good" },
    { value = 3, label = "High" },
}

-- Blizzard Particle Density: Low (1), Fair (2), Good (3), High (4), Ultra (5)
local PARTICLE_PILL_OPTIONS = {
    { value = 1, label = "Low" },
    { value = 2, label = "Fair" },
    { value = 3, label = "Good" },
    { value = 4, label = "High" },
    { value = 5, label = "Ultra" },
}

-- Blizzard SSAO: Disabled (0), Low (1), Good (2), High (3), Ultra (4)
local SSAO_PILL_OPTIONS = {
    { value = 0, label = "Disabled" },
    { value = 1, label = "Low" },
    { value = 2, label = "Good" },
    { value = 3, label = "High" },
    { value = 4, label = "Ultra" },
}

-- Blizzard Depth Effects: Disabled (0), Low (1), Good (2), High (3)
local DEPTH_PILL_OPTIONS = {
    { value = 0, label = "Disabled" },
    { value = 1, label = "Low" },
    { value = 2, label = "Good" },
    { value = 3, label = "High" },
}

-- Blizzard Compute Effects: Disabled (0), Low (1), Good (2), High (3), Ultra (4)
local COMPUTE_PILL_OPTIONS = {
    { value = 0, label = "Disabled" },
    { value = 1, label = "Low" },
    { value = 2, label = "Good" },
    { value = 3, label = "High" },
    { value = 4, label = "Ultra" },
}

-- Blizzard Outline Mode: Disabled (0), Good (1), High (2)
local OUTLINE_PILL_OPTIONS = {
    { value = 0, label = "Disabled" },
    { value = 1, label = "Good" },
    { value = 2, label = "High" },
}

-- Blizzard Texture Resolution: Low (0), Fair (1), High (2)
local TEXTURE_RES_PILL_OPTIONS = {
    { value = 0, label = "Low" },
    { value = 1, label = "Fair" },
    { value = 2, label = "High" },
}

-- Blizzard Spell Density: Essential (CVar 0), Reduced (CVar 2), Everything (CVar 5)
local SPELL_DENSITY_PILL_OPTIONS = {
    { value = "ESSENTIAL",  label = "Essential" },
    { value = "REDUCED",    label = "Reduced" },
    { value = "EVERYTHING", label = "Everything" },
}

local TARGET_FPS_FLOOR_PILLS = {
    { value = 0,   label = "Off" },
    { value = 60,  label = "60" },
    { value = 90,  label = "90" },
    { value = 120, label = "120" },
    { value = 144, label = "144 FPS" },
}

local SPELL_QUEUE_MODE_PILLS = {
    { value = "SMART_AUTO",       label = "Smart Auto" },
    { value = "CUSTOM_MANUAL",    label = "Custom Manual" },
    { value = "BLIZZARD_DEFAULT", label = "Blizzard Default" },
}

local MAX_FG_FPS_DROPDOWN = {
    { value = 0,   label = "Uncapped (Max FPS)" },
    { value = 60,  label = "60 FPS Foreground Cap" },
    { value = 120, label = "120 FPS Foreground Cap" },
    { value = 144, label = "144 FPS Foreground Cap" },
    { value = 165, label = "165 FPS Foreground Cap" },
    { value = 240, label = "240 FPS Foreground Cap" },
}

local MAX_BG_FPS_DROPDOWN = {
    { value = 0,  label = "Uncapped (No Limit)" },
    { value = 15, label = "15 FPS (Max GPU Saver)" },
    { value = 30, label = "30 FPS (Alt-Tab Saver)" },
    { value = 60, label = "60 FPS (Smooth Background)" },
    { value = 90, label = "90 FPS (High Multitasking)" },
}

local COMBAT_LOG_PURGE_DROPDOWN = {
    { value = "OFF",                 label = "Manual Combat Logging Only" },
    { value = "RAID_AND_MPLUS",      label = "Raid & Mythic+ (Auto-Stop)" },
    { value = "MPLUS_ONLY",          label = "Mythic+ Only (Auto-Stop)" },
    { value = "RAID_ONLY",           label = "Raid Bosses Only (Auto-Stop)" },
    { value = "ALWAYS_STOP_OUTDOOR", label = "Auto-Stop in Outdoor & Cities" },
}

local QUEST_TRACKER_DROPDOWN = {
    { value = "ALWAYS_SHOW",         label = "Always Show Objective Tracker" },
    { value = "COLLAPSE_MPLUS_RAID", label = "Auto-Collapse in M+ & Raids" },
    { value = "COLLAPSE_BOSS",       label = "Auto-Collapse on Bosses Only" },
    { value = "HIDE_IN_COMBAT",      label = "Auto-Collapse During Combat" },
    { value = "COLLAPSE_INSTANCES",  label = "Auto-Collapse in All Instances" },
}

local DECLUTTER_AUDIO_PILLS = {
    { value = "DEFAULT",          label = "Off" },
    { value = "MUTE_SPEECH_ONLY", label = "Mute Error Speech" },
    { value = "MUTE_ALL",         label = "Speech & Loot Banner" },
}

-- 36-CVar Baseline Snapshot Keys
local BASELINE_CVAR_KEYS = {
    "graphicsQuality",
    "RAIDgraphicsQuality",
    "graphicsShadowQuality",
    "RAIDgraphicsShadowQuality",
    "RAIDshadowMode",
    "graphicsLiquidDetail",
    "RAIDgraphicsLiquidDetail",
    "RAIDWaterDetail",
    "waterDetail",
    "graphicsParticleDensity",
    "RAIDgraphicsParticleDensity",
    "particleDensity",
    "graphicsSSAO",
    "RAIDgraphicsSSAO",
    "graphicsDepthEffects",
    "RAIDgraphicsDepthEffects",
    "graphicsComputeEffects",
    "RAIDgraphicsComputeEffects",
    "graphicsSpellDensity",
    "RAIDgraphicsSpellDensity",
    "spellClutter",
    "graphicsViewDistance",
    "RAIDgraphicsViewDistance",
    "graphicsGroundClutter",
    "RAIDgraphicsGroundClutter",
    "RAIDgroundEffectDensity",
    "graphicsEnvironmentDetail",
    "RAIDgraphicsEnvironmentDetail",
    "graphicsTextureResolution",
    "RAIDgraphicsTextureResolution",
    "graphicsOutlineMode",
    "RAIDsettingsEnabled",
    "farclip",
    "RAIDfarclip",
    "horizonClip",
    "nameplateShowFriends",
    "findYourselfMode",
    "maxFPS",
    "useMaxFPS",
    "maxFPSBk",
    "useMaxFPSBk",
    "SpellQueueWindow",
    "Sound_EnableErrorSpeech",
}

-- ============================================================================
-- 3. SAFE CVar HELPERS & TELEGRAPH SAFETY LOCK INVARIANT
-- ============================================================================
local function DeepCopyTable(src)
    if type(src) ~= "table" then return src end
    local dest = {}
    for k, v in pairs(src) do
        dest[k] = DeepCopyTable(v)
    end
    return dest
end

local COMBAT_PROTECTED_CVARS = {
    nameplateShowFriends = true,
    findYourselfMode     = true,
}

local function SafeSetCVar(cvarName, value)
    if not cvarName or value == nil or _IsSecret(value) then return false end
    if COMBAT_PROTECTED_CVARS[cvarName] and InCombatLockdown and InCombatLockdown() then
        return false
    end
    local strVal = tostring(value)
    local curVal = nil
    if C_CVar and C_CVar.GetCVar then
        local okCur, v = pcall(C_CVar.GetCVar, cvarName)
        if okCur and not _IsSecret(v) then curVal = v end
    elseif GetCVar then
        local okCur, v = pcall(GetCVar, cvarName)
        if okCur and not _IsSecret(v) then curVal = v end
    end
    if curVal ~= nil and not _IsSecret(curVal) then
        local numCur = _SafeNumber(curVal, nil)
        local numNew = _SafeNumber(strVal, nil)
        if tostring(curVal) == strVal or (numCur ~= nil and numNew ~= nil and numCur == numNew) then
            return false -- Value already matches; skip redundant C++ engine/DX12 rebuild
        end
    end
    if _G.DynamicSuite and _G.DynamicSuite.SnapshotCVar then
        _G.DynamicSuite.SnapshotCVar(cvarName)
    end
    if C_CVar and C_CVar.SetCVar then
        local okSet = pcall(C_CVar.SetCVar, cvarName, strVal)
        return okSet
    elseif SetCVar then
        local okSet = pcall(SetCVar, cvarName, strVal)
        return okSet
    end
    return false
end

local function SafeGetCVar(cvarName, fallback)
    if not cvarName then return fallback end
    if C_CVar and C_CVar.GetCVar then
        local ok, val = pcall(C_CVar.GetCVar, cvarName)
        if ok and val ~= nil and not _IsSecret(val) then
            return val
        end
    end
    if GetCVar then
        local ok, val = pcall(GetCVar, cvarName)
        if ok and val ~= nil and not _IsSecret(val) then
            return val
        end
    end
    return fallback
end

local isApplyingGraphicsCVars = false

local function StripColorTags(str)
    if type(str) ~= "string" then return "" end
    return str:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$") or ""
end

local function ResolveSettingOptionValue(cvarName, fallbackVal, preferredLabel)
    if not preferredLabel or not (_G.Settings and type(_G.Settings.GetSetting) == "function") then
        return fallbackVal
    end
    local ok, resolved = pcall(function()
        local setting = _G.Settings.GetSetting(cvarName)
        if not setting then return nil end
        local opts = nil
        if type(setting.GetOptions) == "function" then
            opts = setting:GetOptions()
        elseif setting.data and type(setting.data.options) == "function" then
            opts = setting.data.options()
        elseif setting.data and type(setting.data.options) == "table" then
            opts = setting.data.options
        end
        if type(opts) ~= "table" then return nil end
        local target = string.lower(StripColorTags(preferredLabel))
        for _, opt in ipairs(opts) do
            if type(opt) == "table" and opt.value ~= nil then
                local lbl = StripColorTags(opt.label or opt.text or opt.name or "")
                if lbl ~= "" and string.lower(lbl) == target then
                    return tonumber(opt.value) or opt.value
                end
            end
        end
        return nil
    end)
    if ok and resolved ~= nil then
        return resolved
    end
    return fallbackVal
end

local function ResolveSettingLabelFromValue(cvarName, rawVal)
    if rawVal == nil or not (_G.Settings and type(_G.Settings.GetSetting) == "function") then
        return nil
    end
    local ok, label = pcall(function()
        local setting = _G.Settings.GetSetting(cvarName)
        if not setting then return nil end
        local opts = nil
        if type(setting.GetOptions) == "function" then
            opts = setting:GetOptions()
        elseif setting.data and type(setting.data.options) == "function" then
            opts = setting.data.options()
        elseif setting.data and type(setting.data.options) == "table" then
            opts = setting.data.options
        end
        if type(opts) ~= "table" then return nil end
        local numRaw = tonumber(rawVal)
        for _, opt in ipairs(opts) do
            if type(opt) == "table" and opt.value ~= nil then
                if opt.value == rawVal or (numRaw ~= nil and tonumber(opt.value) == numRaw) then
                    local lbl = StripColorTags(opt.label or opt.text or opt.name or "")
                    if lbl ~= "" then return lbl end
                end
            end
        end
        return nil
    end)
    if ok and type(label) == "string" and label ~= "" then
        return label
    end
    return nil
end

local function ApplyGraphicsCVar(cvarName, value, preferredLabel)
    if not cvarName or value == nil or _IsSecret(value) then return false end
    local finalVal = preferredLabel and ResolveSettingOptionValue(cvarName, value, preferredLabel) or value
    local numVal = tonumber(finalVal)
    if not (InCombatLockdown and InCombatLockdown()) and _G.Settings then
        if type(_G.Settings.GetSetting) == "function" then
            local okS, setting = pcall(_G.Settings.GetSetting, cvarName)
            if okS and setting and type(setting.SetValue) == "function" then
                pcall(setting.SetValue, setting, numVal ~= nil and numVal or finalVal)
            elseif type(_G.Settings.SetValue) == "function" then
                pcall(_G.Settings.SetValue, cvarName, numVal ~= nil and numVal or finalVal)
            end
        elseif type(_G.Settings.SetValue) == "function" then
            pcall(_G.Settings.SetValue, cvarName, numVal ~= nil and numVal or finalVal)
        end
    end
    return SafeSetCVar(cvarName, finalVal)
end

-- HARD LOCK INVARIANT: Boss ground swirlies & telegraphs are NEVER hidden
local function EnforceProjectedTexturesLock()
    ApplyGraphicsCVar("graphicsProjectedTextures", 1, "Enabled")
    ApplyGraphicsCVar("RAIDgraphicsProjectedTextures", 1, "Enabled")
    SafeSetCVar("projectedTextures", 1)
    SafeSetCVar("RAIDprojectedTextures", 1)
end

local function NormalizeSpellDensityToken(val)
    if type(val) == "string" then
        local up = string.upper(val)
        if up == "ESSENTIAL" or up == "MINIMAL" or up == "0" or up == "1" then
            return "ESSENTIAL"
        elseif up == "REDUCED" or up == "HALF" or up == "2" or up == "15" or up == "25" or up == "50" then
            return "REDUCED"
        elseif up == "EVERYTHING" or up == "ALL" or up == "4" or up == "5" or up == "100" then
            return "EVERYTHING"
        end
    end
    local n = _SafeNum(val, 25)
    if n <= 1 then return "ESSENTIAL" end
    if n <= 50 then return "REDUCED" end
    return "EVERYTHING"
end

local EXTERNAL_COMBAT_LOGGERS = {
    "!ArchonLogger",
    "ArchonLogger",
    "LoggerHead",
    "AutoCombatLogger",
    "RaiderIO_AutoCombatLog",
}

local function HasExternalCombatLogger()
    if not (_G.C_AddOns and type(_G.C_AddOns.IsAddOnLoaded) == "function") then
        return false, nil
    end
    for _, addonKey in ipairs(EXTERNAL_COMBAT_LOGGERS) do
        local ok, loaded = pcall(_G.C_AddOns.IsAddOnLoaded, addonKey)
        if ok and loaded == true then
            return true, addonKey
        end
    end
    return false, nil
end
DynamicFPS.HasExternalCombatLogger = HasExternalCombatLogger

local function EnsureDBInitialized()
    local isFreshDB = (type(_G.DynamicFPSDB) ~= "table")
    if isFreshDB then
        _G.DynamicFPSDB = DeepCopyTable(DEFAULT_DB)
        if HasExternalCombatLogger() then
            _G.DynamicFPSDB.combatLogAutoPurge = "OFF"
            _G.DynamicFPSDB.archonYieldMigrated = true
        end
    else
        for k, v in pairs(DEFAULT_DB) do
            if _G.DynamicFPSDB[k] == nil then
                _G.DynamicFPSDB[k] = DeepCopyTable(v)
            end
        end
        if not _G.DynamicFPSDB.archonYieldMigrated and HasExternalCombatLogger() then
            _G.DynamicFPSDB.combatLogAutoPurge = "OFF"
            _G.DynamicFPSDB.archonYieldMigrated = true
        end
        if _G.DynamicFPSDB.declutterAudioMode == "HIDE_TH_MUTE_SPEECH" then
            _G.DynamicFPSDB.declutterAudioMode = "MUTE_SPEECH_ONLY"
        elseif _G.DynamicFPSDB.declutterAudioMode == "HIDE_TH_ONLY" then
            _G.DynamicFPSDB.declutterAudioMode = "DEFAULT"
        end
        if type(_G.DynamicFPSDB.activePresets) ~= "table" then
            _G.DynamicFPSDB.activePresets = DeepCopyTable(DEFAULT_DB.activePresets)
        else
            for zKey, defPreset in pairs(DEFAULT_DB.activePresets) do
                if _G.DynamicFPSDB.activePresets[zKey] == nil then
                    _G.DynamicFPSDB.activePresets[zKey] = defPreset
                end
            end
        end
        if type(_G.DynamicFPSDB.zones) ~= "table" then
            _G.DynamicFPSDB.zones = DeepCopyTable(DEFAULT_DB.zones)
        else
            for zKey, zDefaults in pairs(DEFAULT_DB.zones) do
                if type(_G.DynamicFPSDB.zones[zKey]) ~= "table" then
                    _G.DynamicFPSDB.zones[zKey] = DeepCopyTable(zDefaults)
                else
                    local zTbl = _G.DynamicFPSDB.zones[zKey]
                    for propK, propV in pairs(zDefaults) do
                        if zTbl[propK] == nil then
                            zTbl[propK] = propV
                        end
                    end
                    zTbl.spellDensity = NormalizeSpellDensityToken(zTbl.spellDensity)
                    zTbl.shadowQuality = math.max(0, math.min(4, _SafeNum(zTbl.shadowQuality, zDefaults.shadowQuality)))
                    zTbl.liquidDetail = math.max(0, math.min(3, _SafeNum(zTbl.liquidDetail, zDefaults.liquidDetail)))
                    zTbl.particleDensity = math.max(1, math.min(5, _SafeNum(zTbl.particleDensity, zDefaults.particleDensity)))
                    zTbl.ssao = math.max(0, math.min(4, _SafeNum(zTbl.ssao, zDefaults.ssao)))
                    zTbl.depthEffects = math.max(0, math.min(3, _SafeNum(zTbl.depthEffects, zDefaults.depthEffects)))
                    zTbl.computeEffects = math.max(0, math.min(4, _SafeNum(zTbl.computeEffects, zDefaults.computeEffects)))
                    zTbl.outlineMode = math.max(0, math.min(2, _SafeNum(zTbl.outlineMode, zDefaults.outlineMode)))
                    if not _G.DynamicFPSDB._cvarIndexMigratedV2 and zTbl.textureResolution ~= nil then
                        local rawTex = _SafeNum(zTbl.textureResolution, 3)
                        if rawTex >= 1 and rawTex <= 3 then
                            zTbl.textureResolution = rawTex - 1
                        end
                    end
                    zTbl.textureResolution = math.max(0, math.min(2, _SafeNum(zTbl.textureResolution, zDefaults.textureResolution)))
                    zTbl.viewDistance = math.max(1, math.min(10, _SafeNum(zTbl.viewDistance, zDefaults.viewDistance)))
                    zTbl.environmentDetail = math.max(1, math.min(10, _SafeNum(zTbl.environmentDetail, zDefaults.environmentDetail)))
                    zTbl.groundClutter = math.max(1, math.min(10, _SafeNum(zTbl.groundClutter, zDefaults.groundClutter)))
                    zTbl.projectedTexturesLocked = true
                end
            end
        end
    end
    _G.DynamicFPSDB._cvarIndexMigratedV2 = true
    _G.DynamicFPSDB.version = ADDON_VERSION

    if type(_G.DynamicSuiteDB) ~= "table" then
        _G.DynamicSuiteDB = { global = DeepCopyTable(DEFAULT_SUITE_GLOBAL), disabledModules = {} }
    else
        _G.DynamicSuiteDB.global = _G.DynamicSuiteDB.global or DeepCopyTable(DEFAULT_SUITE_GLOBAL)
        for k, v in pairs(DEFAULT_SUITE_GLOBAL) do
            if _G.DynamicSuiteDB.global[k] == nil then
                _G.DynamicSuiteDB.global[k] = v
            end
        end
        _G.DynamicSuiteDB.disabledModules = _G.DynamicSuiteDB.disabledModules or {}
    end
end

-- ============================================================================
-- 4. ENGINE 1: ZERO-RELOAD 6-ZONE GRAPHICS MATRIX & BASELINE SNAPSHOT
-- ============================================================================
local currentZoneContext = "OUTDOOR"
local pendingOutOfCombatGraphics = false

local function GetCurrentZoneContext()
    local inInstance, instanceType = false, "none"
    if IsInInstance then
        inInstance, instanceType = IsInInstance()
    end

    if inInstance then
        if instanceType == "raid" then
            return "RAID"
        elseif instanceType == "party" then
            return "DUNGEONS"
        elseif instanceType == "pvp" or instanceType == "arena" then
            return "PVP"
        elseif instanceType == "scenario" then
            return "DELVES"
        end
    end

    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
        return "DUNGEONS"
    end

    if C_DelvesUI and C_DelvesUI.HasActiveDelve and C_DelvesUI.HasActiveDelve() then
        return "DELVES"
    end

    local uiMapID = nil
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        if ok then uiMapID = mapID end
    end

    if (uiMapID and CAPITAL_CITY_MAP_IDS[uiMapID]) or (IsResting and IsResting() and not inInstance) then
        return "CITIES"
    end

    return "OUTDOOR"
end
DynamicFPS.GetCurrentZoneContext = GetCurrentZoneContext

local function CaptureBaselineCVars()
    EnsureDBInitialized()
    local existing = DynamicFPSDB.savedBaselineCVars
    local needsRecapture = (type(existing) ~= "table") or (next(existing) == nil) or (existing["graphicsQuality"] == nil)
    if not needsRecapture then
        for _, key in ipairs(BASELINE_CVAR_KEYS) do
            if existing[key] == nil then
                local val = SafeGetCVar(key, nil)
                if val ~= nil then
                    existing[key] = tostring(val)
                end
            end
        end
        return
    end
    local snap = type(existing) == "table" and existing or {}
    for _, key in ipairs(BASELINE_CVAR_KEYS) do
        local val = SafeGetCVar(key, nil)
        if val ~= nil then
            snap[key] = tostring(val)
        end
    end
    snap["projectedTextures"] = "1"
    snap["RAIDprojectedTextures"] = "1"
    DynamicFPSDB.savedBaselineCVars = snap
end
DynamicFPS.CaptureBaselineCVars = CaptureBaselineCVars

local function MapSpellDensityToCVars(spellDensityVal)
    local token = NormalizeSpellDensityToken(spellDensityVal)
    if token == "ESSENTIAL" then
        return 0, 1
    elseif token == "REDUCED" then
        return 2, 25
    else
        return 5, 100
    end
end

local function DetectMatchingPresetKey(zTbl, zKey, storedKey)
    if storedKey == "SAVED_BASE" then return "SAVED_BASE" end
    if type(zTbl) ~= "table" then return storedKey or "CUSTOM" end
    local checkOrder = { "LOW", "BALANCED", "COMPETITIVE", "ULTRA" }
    for _, pKey in ipairs(checkOrder) do
        local tpl = STARTER_PRESETS[pKey]
        if tpl then
            local expectedSpell = tpl.spellDensity
            if pKey == "COMPETITIVE" and (zKey == "DUNGEONS" or zKey == "DELVES") then
                expectedSpell = "REDUCED"
            end
            if _SafeNum(zTbl.shadowQuality, 0) == tpl.shadowQuality
                and _SafeNum(zTbl.liquidDetail, 0) == tpl.liquidDetail
                and _SafeNum(zTbl.particleDensity, 1) == tpl.particleDensity
                and _SafeNum(zTbl.ssao, 0) == tpl.ssao
                and _SafeNum(zTbl.depthEffects, 0) == tpl.depthEffects
                and _SafeNum(zTbl.computeEffects, 0) == tpl.computeEffects
                and _SafeNum(zTbl.outlineMode, 2) == tpl.outlineMode
                and _SafeNum(zTbl.textureResolution, 2) == tpl.textureResolution
                and (NormalizeSpellDensityToken(zTbl.spellDensity) == expectedSpell or NormalizeSpellDensityToken(zTbl.spellDensity) == tpl.spellDensity)
                and _SafeNum(zTbl.viewDistance, 5) == tpl.viewDistance
                and _SafeNum(zTbl.environmentDetail, 5) == tpl.environmentDetail
                and _SafeNum(zTbl.groundClutter, 3) == tpl.groundClutter
            then
                return pKey
            end
        end
    end
    return storedKey or "CUSTOM"
end

local function MapViewDistanceToFarclip(viewDist)
    local v = math.max(1, math.min(10, _SafeNum(viewDist, 5)))
    return 600 + ((v - 1) * 155)
end

local function ApplyFrameRateCaps()
    EnsureDBInitialized()
    local fgCap = _SafeNum(DynamicFPSDB.maxForegroundFPS, 0)
    if fgCap > 0 then
        SafeSetCVar("useMaxFPS", 1)
        SafeSetCVar("maxFPS", fgCap)
    else
        SafeSetCVar("useMaxFPS", 0)
    end

    local bgCap = _SafeNum(DynamicFPSDB.maxBackgroundFPS, 30)
    if bgCap > 0 then
        SafeSetCVar("useMaxFPSBk", 1)
        SafeSetCVar("maxFPSBk", bgCap)
    else
        SafeSetCVar("useMaxFPSBk", 0)
    end
end
DynamicFPS.ApplyFrameRateCaps = ApplyFrameRateCaps

local function IsYieldingSharedHooks()
    if not _G.DynamicFPSDB then return false end
    local yh = _G.DynamicFPSDB.yieldHooks
    if yh == true then return true end
    if type(yh) == "table" and next(yh) ~= nil then return true end
    return false
end
DynamicFPS.IsYieldingSharedHooks = IsYieldingSharedHooks

local function RestoreBaselineCVarsOnly()
    local snap = _G.DynamicFPSDB and _G.DynamicFPSDB.savedBaselineCVars
    if type(snap) == "table" and next(snap) ~= nil then
        for k, v in pairs(snap) do
            SafeSetCVar(k, v)
        end
    end
    EnforceProjectedTexturesLock()
end
DynamicFPS.RestoreBaselineCVarsOnly = RestoreBaselineCVarsOnly

local SHADOW_LABELS   = { [0] = "Low", [1] = "Fair", [2] = "Good", [3] = "High", [4] = "Ultra" }
local LIQUID_LABELS   = { [0] = "Low", [1] = "Fair", [2] = "Good", [3] = "High" }
local PARTICLE_LABELS = { [1] = "Low", [2] = "Fair", [3] = "Good", [4] = "High", [5] = "Ultra" }
local SSAO_LABELS     = { [0] = "Disabled", [1] = "Low", [2] = "Good", [3] = "High", [4] = "Ultra" }
local DEPTH_LABELS    = { [0] = "Disabled", [1] = "Low", [2] = "Good", [3] = "High" }
local COMPUTE_LABELS  = { [0] = "Disabled", [1] = "Low", [2] = "Good", [3] = "High", [4] = "Ultra" }
local OUTLINE_LABELS  = { [0] = "Disabled", [1] = "Good", [2] = "High" }
local TEXRES_LABELS   = { [0] = "Low", [1] = "Fair", [2] = "High" }
local SPELL_LABELS    = { ESSENTIAL = "Essential", REDUCED = "Reduced", EVERYTHING = "Everything" }

local function ApplyZoneGraphicsConfig(zoneKey, force)
    EnsureDBInitialized()
    EnforceProjectedTexturesLock()

    if not DynamicFPSDB.enabled or IsYieldingSharedHooks() then return end
    if not DynamicFPSDB.autoZoneSwitch and not force then return end

    if InCombatLockdown and InCombatLockdown() and not force then
        pendingOutOfCombatGraphics = true
        return
    end

    currentZoneContext = GetCurrentZoneContext()
    local targetZone = zoneKey or currentZoneContext
    local cfg = (DynamicFPSDB.zones and DynamicFPSDB.zones[targetZone]) or DEFAULT_DB.zones.RAID

    local isInstance   = (targetZone == "RAID" or targetZone == "DUNGEONS" or targetZone == "PVP" or targetZone == "DELVES")
    local shadowQ      = math.max(0, math.min(4, _SafeNum(cfg.shadowQuality, 0)))
    local spellToken   = NormalizeSpellDensityToken(cfg.spellDensity)
    local spellDensityCVar = MapSpellDensityToCVars(spellToken)
    local particleQ    = math.max(1, math.min(5, _SafeNum(cfg.particleDensity, 3)))
    local liquidQ      = math.max(0, math.min(3, _SafeNum(cfg.liquidDetail, 0)))
    local ssaoQ        = math.max(0, math.min(4, _SafeNum(cfg.ssao, 0)))
    local depthQ       = math.max(0, math.min(3, _SafeNum(cfg.depthEffects, 0)))
    local computeQ     = math.max(0, math.min(4, _SafeNum(cfg.computeEffects, 0)))
    local texRes       = math.max(0, math.min(2, _SafeNum(cfg.textureResolution, 2)))
    local viewDistCVar = math.max(0, math.min(9, _SafeNum(cfg.viewDistance, 5) - 1))
    local envDetCVar   = math.max(0, math.min(9, _SafeNum(cfg.environmentDetail, 5) - 1))
    local clutterCVar  = math.max(0, math.min(9, _SafeNum(cfg.groundClutter, 3) - 1))
    local outlineMode  = math.max(0, math.min(2, _SafeNum(cfg.outlineMode, 2)))

    isApplyingGraphicsCVars = true
    pcall(function()
        -- 1. Disable Blizzard's internal Raid/BG split override so DynamicFPS controls all zones uniformly
        ApplyGraphicsCVar("RAIDsettingsEnabled", 0)

        -- 2. Apply Primary & Raid Wrapper Graphics CVars identically via Settings + C_CVar (0-based indices)
        ApplyGraphicsCVar("graphicsShadowQuality", shadowQ, SHADOW_LABELS[shadowQ])
        ApplyGraphicsCVar("RAIDgraphicsShadowQuality", shadowQ, SHADOW_LABELS[shadowQ])

        ApplyGraphicsCVar("graphicsSpellDensity", spellDensityCVar, SPELL_LABELS[spellToken])
        ApplyGraphicsCVar("RAIDgraphicsSpellDensity", spellDensityCVar, SPELL_LABELS[spellToken])

        ApplyGraphicsCVar("graphicsParticleDensity", particleQ - 1, PARTICLE_LABELS[particleQ])
        ApplyGraphicsCVar("RAIDgraphicsParticleDensity", particleQ - 1, PARTICLE_LABELS[particleQ])

        ApplyGraphicsCVar("graphicsLiquidDetail", liquidQ, LIQUID_LABELS[liquidQ])
        ApplyGraphicsCVar("RAIDgraphicsLiquidDetail", liquidQ, LIQUID_LABELS[liquidQ])

        ApplyGraphicsCVar("graphicsSSAO", ssaoQ, SSAO_LABELS[ssaoQ])
        ApplyGraphicsCVar("RAIDgraphicsSSAO", ssaoQ, SSAO_LABELS[ssaoQ])

        ApplyGraphicsCVar("graphicsDepthEffects", depthQ, DEPTH_LABELS[depthQ])
        ApplyGraphicsCVar("RAIDgraphicsDepthEffects", depthQ, DEPTH_LABELS[depthQ])

        ApplyGraphicsCVar("graphicsComputeEffects", computeQ, COMPUTE_LABELS[computeQ])
        ApplyGraphicsCVar("RAIDgraphicsComputeEffects", computeQ, COMPUTE_LABELS[computeQ])

        ApplyGraphicsCVar("graphicsTextureResolution", texRes, TEXRES_LABELS[texRes])
        ApplyGraphicsCVar("RAIDgraphicsTextureResolution", texRes, TEXRES_LABELS[texRes])

        ApplyGraphicsCVar("graphicsViewDistance", viewDistCVar)
        ApplyGraphicsCVar("RAIDgraphicsViewDistance", viewDistCVar)

        ApplyGraphicsCVar("graphicsEnvironmentDetail", envDetCVar)
        ApplyGraphicsCVar("RAIDgraphicsEnvironmentDetail", envDetCVar)

        ApplyGraphicsCVar("graphicsGroundClutter", clutterCVar)
        ApplyGraphicsCVar("RAIDgraphicsGroundClutter", clutterCVar)

        ApplyGraphicsCVar("graphicsOutlineMode", outlineMode, OUTLINE_LABELS[outlineMode])
        ApplyGraphicsCVar("RAIDgraphicsOutlineMode", outlineMode, OUTLINE_LABELS[outlineMode])
    end)
    isApplyingGraphicsCVars = false

    if not (InCombatLockdown and InCombatLockdown()) then
        if isInstance then
            if DynamicFPSDB._savedOutdoorFriendlyNameplates == nil then
                local curNP = SafeGetCVar("nameplateShowFriends", nil)
                if curNP ~= nil then
                    DynamicFPSDB._savedOutdoorFriendlyNameplates = tostring(curNP)
                end
            end
            SafeSetCVar("nameplateShowFriends", cfg.friendlyNameplatesPvE and 1 or 0)
        elseif DynamicFPSDB._savedOutdoorFriendlyNameplates ~= nil then
            SafeSetCVar("nameplateShowFriends", DynamicFPSDB._savedOutdoorFriendlyNameplates)
            DynamicFPSDB._savedOutdoorFriendlyNameplates = nil
        elseif DynamicFPSDB.savedBaselineCVars and DynamicFPSDB.savedBaselineCVars["nameplateShowFriends"] ~= nil then
            SafeSetCVar("nameplateShowFriends", DynamicFPSDB.savedBaselineCVars["nameplateShowFriends"])
        end
        SafeSetCVar("findYourselfMode", cfg.targetSilhouette and 1 or 0)
    end

    -- 3. Apply Foreground & Background FPS Caps
    ApplyFrameRateCaps()

    -- 4. Hard-Lock Projected Textures (Boss Swirlies & Ground Telegraphs)
    cfg.projectedTexturesLocked = true
    EnforceProjectedTexturesLock()

    if _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
        pcall(_G.DynamicSuite.RefreshHeaderStatus)
    end
end
DynamicFPS.ApplyGraphicsPipeline = function(force)
    ApplyZoneGraphicsConfig(GetCurrentZoneContext(), force)
end

-- Item #13: Apply Starter Preset and update DynamicFPSDB.activePresets[zoneKey]
local function ApplyStarterPresetToZone(zoneKey, presetKey)
    EnsureDBInitialized()
    local template = STARTER_PRESETS[presetKey]
    if not template or not zoneKey or not DynamicFPSDB.zones[zoneKey] then return end

    DynamicFPSDB.activePresets[zoneKey] = presetKey

    local z = DynamicFPSDB.zones[zoneKey]
    z.overallQuality        = template.overallQuality
    z.shadowQuality         = template.shadowQuality
    z.liquidDetail          = template.liquidDetail
    z.particleDensity       = template.particleDensity
    z.ssao                  = template.ssao
    z.depthEffects          = template.depthEffects
    z.computeEffects        = template.computeEffects
    z.outlineMode           = template.outlineMode
    z.textureResolution     = template.textureResolution
    if presetKey == "COMPETITIVE" and (zoneKey == "DUNGEONS" or zoneKey == "DELVES") then
        z.spellDensity      = "REDUCED"
    else
        z.spellDensity      = template.spellDensity
    end
    z.viewDistance          = template.viewDistance
    z.environmentDetail     = template.environmentDetail
    z.groundClutter         = template.groundClutter
    z.friendlyNameplatesPvE = template.friendlyNameplatesPvE
    z.targetSilhouette      = template.targetSilhouette
    z.projectedTexturesLocked = true

    if zoneKey == GetCurrentZoneContext() then
        ApplyZoneGraphicsConfig(zoneKey, true)
    elseif _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
        pcall(_G.DynamicSuite.RefreshHeaderStatus)
    end
    if DynamicFPS.RefreshWorkspaceUI then
        DynamicFPS.RefreshWorkspaceUI()
    end
end
DynamicFPS.ApplyStarterPresetToZone = ApplyStarterPresetToZone

local function CopyZoneSettings(srcZoneKey, dstZoneKey)
    EnsureDBInitialized()
    if not srcZoneKey or not dstZoneKey then return false end
    local src = DynamicFPSDB.zones and DynamicFPSDB.zones[srcZoneKey]
    if not src then return false end
    DynamicFPSDB.zones[dstZoneKey] = DynamicFPSDB.zones[dstZoneKey] or {}
    local dst = DynamicFPSDB.zones[dstZoneKey]
    for k, v in pairs(src) do
        dst[k] = v
    end
    dst.projectedTexturesLocked = true

    local srcPreset = (DynamicFPSDB.activePresets and DynamicFPSDB.activePresets[srcZoneKey]) or "CUSTOM"
    DynamicFPSDB.activePresets = DynamicFPSDB.activePresets or {}
    DynamicFPSDB.activePresets[dstZoneKey] = DetectMatchingPresetKey(dst, dstZoneKey, srcPreset)

    if dstZoneKey == GetCurrentZoneContext() then
        ApplyZoneGraphicsConfig(dstZoneKey, true)
    elseif _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
        pcall(_G.DynamicSuite.RefreshHeaderStatus)
    end
    if DynamicFPS.RefreshWorkspaceUI then
        DynamicFPS.RefreshWorkspaceUI()
    end
    local srcName = ZONE_NAMES[srcZoneKey] or srcZoneKey
    local dstName = ZONE_NAMES[dstZoneKey] or dstZoneKey
    print(string.format("%s: Copied |cFF10B981%s|r graphics profile into |cFFFFFFFF%s|r.", ADDON_TITLE_COLORED, srcName, dstName))
    return true
end
DynamicFPS.CopyZoneSettings = CopyZoneSettings

local function ApplyZoneToAllZones(srcZoneKey)
    EnsureDBInitialized()
    if not srcZoneKey or not (DynamicFPSDB.zones and DynamicFPSDB.zones[srcZoneKey]) then return false end
    local src = DynamicFPSDB.zones[srcZoneKey]
    local srcPreset = (DynamicFPSDB.activePresets and DynamicFPSDB.activePresets[srcZoneKey]) or "CUSTOM"
    DynamicFPSDB.activePresets = DynamicFPSDB.activePresets or {}

    for _, tInfo in ipairs(LEFT_ZONE_TABS) do
        local zKey = tInfo.id
        if zKey ~= srcZoneKey then
            DynamicFPSDB.zones[zKey] = DynamicFPSDB.zones[zKey] or {}
            local dst = DynamicFPSDB.zones[zKey]
            for k, v in pairs(src) do
                dst[k] = v
            end
            dst.projectedTexturesLocked = true
            DynamicFPSDB.activePresets[zKey] = DetectMatchingPresetKey(dst, zKey, srcPreset)
        end
    end

    ApplyZoneGraphicsConfig(GetCurrentZoneContext(), true)
    if DynamicFPS.RefreshWorkspaceUI then
        DynamicFPS.RefreshWorkspaceUI()
    end
    local srcName = ZONE_NAMES[srcZoneKey] or srcZoneKey
    print(string.format("%s: Replicated |cFF10B981%s|r graphics settings across |cFFFFFFFFall 6 zones|r.", ADDON_TITLE_COLORED, srcName))
    return true
end
DynamicFPS.ApplyZoneToAllZones = ApplyZoneToAllZones

local function RestoreBaselineGraphics(targetZoneKey)
    EnsureDBInitialized()
    local snap = DynamicFPSDB.savedBaselineCVars
    local zKey = targetZoneKey or (DynamicFPSDB and DynamicFPSDB.activeTab ~= "GUARD_QUEUE" and DynamicFPSDB.activeTab) or GetCurrentZoneContext()
    if zKey and DynamicFPSDB.zones and DynamicFPSDB.zones[zKey] and type(snap) == "table" then
        local z = DynamicFPSDB.zones[zKey]
        z.shadowQuality     = math.max(0, math.min(4, _SafeNum(snap["graphicsShadowQuality"], z.shadowQuality)))
        z.liquidDetail      = math.max(0, math.min(3, _SafeNum(snap["graphicsLiquidDetail"], z.liquidDetail)))
        z.particleDensity   = math.max(1, math.min(5, _SafeNum(snap["graphicsParticleDensity"], z.particleDensity)))
        z.ssao              = math.max(0, math.min(4, _SafeNum(snap["graphicsSSAO"], z.ssao)))
        z.depthEffects      = math.max(0, math.min(3, _SafeNum(snap["graphicsDepthEffects"], z.depthEffects)))
        z.computeEffects    = math.max(0, math.min(4, _SafeNum(snap["graphicsComputeEffects"], z.computeEffects)))
        z.outlineMode       = math.max(0, math.min(2, _SafeNum(snap["graphicsOutlineMode"], z.outlineMode)))
        z.textureResolution = math.max(0, math.min(2, _SafeNum(snap["graphicsTextureResolution"], z.textureResolution)))
        z.spellDensity      = NormalizeSpellDensityToken(snap["graphicsSpellDensity"] or snap["spellClutter"] or z.spellDensity)
        z.viewDistance      = math.max(1, math.min(10, _SafeNum(snap["graphicsViewDistance"], (z.viewDistance or 5) - 1) + 1))
        z.environmentDetail = math.max(1, math.min(10, _SafeNum(snap["graphicsEnvironmentDetail"], (z.environmentDetail or 5) - 1) + 1))
        z.groundClutter     = math.max(1, math.min(10, _SafeNum(snap["graphicsGroundClutter"], (z.groundClutter or 3) - 1) + 1))
        z.projectedTexturesLocked = true
        DynamicFPSDB.activePresets[zKey] = "SAVED_BASE"
    end
    if type(snap) == "table" and next(snap) ~= nil and (not targetZoneKey or targetZoneKey == GetCurrentZoneContext()) then
        for k, v in pairs(snap) do
            SafeSetCVar(k, v)
        end
    end
    EnforceProjectedTexturesLock()
    print(ADDON_TITLE_COLORED .. ": Restored saved baseline graphics (Boss Telegraph Safety Lock remains ON).")
    if DynamicFPS.RefreshWorkspaceUI then
        DynamicFPS.RefreshWorkspaceUI()
    end
end
DynamicFPS.RestoreBaselineGraphics = RestoreBaselineGraphics

-- ============================================================================
-- 5. ENGINE 2: DYNAMIC EMERGENCY FPS GUARD (COMBAT-ONLY TICKER)
-- ============================================================================
local combatGovernorTicker = nil
local currentGovernorStep = 0

local function ApplyGovernorStepDown(step)
    if DynamicFPSDB then
        DynamicFPSDB._governorDirty = true
    end
    EnforceProjectedTexturesLock()
    if step >= 1 then
        SafeSetCVar("graphicsSpellDensity", 0)
        SafeSetCVar("RAIDgraphicsSpellDensity", 0)
        SafeSetCVar("spellClutter", 1)
        SafeSetCVar("graphicsGroundClutter", 1)
        SafeSetCVar("RAIDgroundEffectDensity", 1)
        SafeSetCVar("graphicsParticleDensity", 1)
        SafeSetCVar("RAIDgraphicsParticleDensity", 1)
    end
    if step >= 2 then
        SafeSetCVar("farclip", 700)
        SafeSetCVar("RAIDfarclip", 700)
        SafeSetCVar("horizonClip", 700)
        SafeSetCVar("graphicsViewDistance", 2)
        SafeSetCVar("RAIDgraphicsViewDistance", 2)
    end
    EnforceProjectedTexturesLock()
end

local function StartCombatFPSGovernor()
    if combatGovernorTicker then
        combatGovernorTicker:Cancel()
        combatGovernorTicker = nil
    end

    EnsureDBInitialized()
    if not DynamicFPSDB.enabled or not DynamicFPSDB.fpsGuardEnabled then
        currentGovernorStep = 0
        return
    end

    local targetFloor = _SafeNum(DynamicFPSDB.targetFPSFloor, 60)
    if targetFloor <= 0 or not C_Timer or not C_Timer.NewTicker then
        currentGovernorStep = 0
        return
    end

    combatGovernorTicker = C_Timer.NewTicker(1.5, function()
        if not (InCombatLockdown and InCombatLockdown()) or not (DynamicFPSDB and DynamicFPSDB.fpsGuardEnabled) then
            if combatGovernorTicker then
                combatGovernorTicker:Cancel()
                combatGovernorTicker = nil
            end
            return
        end

        local floorFPS = _SafeNum(DynamicFPSDB.targetFPSFloor, 60)
        if floorFPS <= 0 then
            if currentGovernorStep > 0 then
                currentGovernorStep = 0
                if DynamicFPSDB then DynamicFPSDB._governorDirty = false end
                ApplyZoneGraphicsConfig(GetCurrentZoneContext(), true)
            end
            return
        end
        local rawFPS = (GetFramerate and GetFramerate()) or 60
        local currentFPS = _SafeNum(rawFPS, 60)
        if currentFPS < floorFPS then
            if currentGovernorStep < 2 then
                currentGovernorStep = currentGovernorStep + 1
                ApplyGovernorStepDown(currentGovernorStep)
            end
        elseif currentFPS >= (floorFPS + 15) and currentGovernorStep > 0 then
            currentGovernorStep = currentGovernorStep - 1
            if currentGovernorStep == 0 then
                if DynamicFPSDB then DynamicFPSDB._governorDirty = false end
                ApplyZoneGraphicsConfig(GetCurrentZoneContext(), true)
            else
                ApplyGovernorStepDown(currentGovernorStep)
            end
        end
    end)
end

local function StopCombatFPSGovernor()
    if combatGovernorTicker then
        combatGovernorTicker:Cancel()
        combatGovernorTicker = nil
    end
    if currentGovernorStep > 0 or (DynamicFPSDB and DynamicFPSDB._governorDirty) then
        currentGovernorStep = 0
        if DynamicFPSDB then DynamicFPSDB._governorDirty = false end
        ApplyZoneGraphicsConfig(GetCurrentZoneContext(), true)
    end
end

-- ============================================================================
-- 6. ENGINE 3: SPELLQUEUE TUNER, COMBAT LOG AUTO-PURGE & UI DECLUTTER
-- ============================================================================
local FAST_GCD_SPECS = {
    [105] = true, [103] = true, [104] = true, -- Resto, Feral, Guardian Druid
    [260] = true, [259] = true, [261] = true, -- Outlaw, Assassination, Subtlety Rogue
    [72]  = true,                             -- Fury Warrior
    [577] = true, [581] = true,               -- Havoc, Vengeance DH
    [263] = true,                             -- Enhancement Shaman
    [269] = true, [268] = true, [270] = true, -- Windwalker, Brewmaster, Mistweaver Monk
    [63]  = true,                             -- Fire Mage
    [70]  = true, [66]  = true, [65]  = true, -- Retribution, Protection, Holy Paladin
    [256] = true,                             -- Discipline Priest
}

local cachedSafeSpecID       = 0
local cachedSafeSpecName     = "General"
local cachedSafeHastePct     = 0
local cachedSafeHomeMS       = 28
local cachedSafeWorldMS      = 28
local cachedSafeTargetSQMS   = 150

local function IsInRestrictedCombatOrKey()
    if InCombatLockdown and InCombatLockdown() then
        return true
    end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
        return true
    end
    if IsEncounterInProgress and IsEncounterInProgress() then
        return true
    end
    return false
end

local function GetActiveSpecQueueProfile()
    local inRestricted = IsInRestrictedCombatOrKey()

    local specID = cachedSafeSpecID
    local specName = cachedSafeSpecName
    local getSpecFn = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local getSpecInfoFn = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    if not inRestricted and getSpecFn and getSpecInfoFn then
        local okIdx, specIdx = pcall(getSpecFn)
        if okIdx and specIdx and not _IsSecret(specIdx) then
            local numIdx = _SafeNum(specIdx, 0)
            if numIdx > 0 then
                local okInfo, id, name = pcall(getSpecInfoFn, numIdx)
                if okInfo and id and not _IsSecret(id) then
                    local safeID = _SafeNum(id, 0)
                    if safeID > 0 then
                        specID = safeID
                        cachedSafeSpecID = safeID
                    end
                    if type(name) == "string" and not _IsSecret(name) and name ~= "" then
                        specName = name
                        cachedSafeSpecName = name
                    end
                end
            end
        end
    end

    local hastePct = cachedSafeHastePct
    if not inRestricted and GetHaste then
        local okHaste, h = pcall(GetHaste)
        if okHaste and h ~= nil and not _IsSecret(h) then
            local safeH = _SafeNum(h, nil)
            if safeH ~= nil then
                hastePct = math.max(0, safeH)
                cachedSafeHastePct = hastePct
                _dfpsCachedHaste = hastePct
            end
        end
    else
        hastePct = _SafeNum(_dfpsCachedHaste, cachedSafeHastePct)
    end

    local isFastGCD = FAST_GCD_SPECS[specID] and true or false
    local profileLabel = isFastGCD and "Fast-GCD" or "Caster"
    return specID, specName, isFastGCD, profileLabel, hastePct
end
DynamicFPS.GetActiveSpecQueueProfile = GetActiveSpecQueueProfile

local function GetSpellQueueMode()
    EnsureDBInitialized()
    local mode = DynamicFPSDB.spellQueueMode
    if mode ~= "SMART_AUTO" and mode ~= "CUSTOM_MANUAL" and mode ~= "BLIZZARD_DEFAULT" then
        mode = (DynamicFPSDB.autoTuneSpellQueue == false) and "BLIZZARD_DEFAULT" or "SMART_AUTO"
        DynamicFPSDB.spellQueueMode = mode
    end
    return mode
end

local function CalculateTargetSpellQueueMS()
    EnsureDBInitialized()
    local worldMS = cachedSafeWorldMS
    local homeMS = cachedSafeHomeMS

    if not IsInRestrictedCombatOrKey() and GetNetStats then
        local okNet, _, _, lagHome, lagWorld = pcall(GetNetStats)
        if okNet then
            local safeHome = _SafeNum(lagHome, nil)
            local safeWorld = _SafeNum(lagWorld, nil)
            if safeHome ~= nil then
                homeMS = math.max(0, safeHome)
                cachedSafeHomeMS = homeMS
            end
            if safeWorld ~= nil and safeWorld > 0 then
                worldMS = safeWorld
                cachedSafeWorldMS = worldMS
            else
                worldMS = (homeMS > 0 and homeMS) or 28
                cachedSafeWorldMS = worldMS
            end
            _dfpsCachedPing = math.max(worldMS or 0, homeMS or 0)
        end
    end

    local effectivePing = _SafeNum(math.max(worldMS or 0, homeMS or 0), _dfpsCachedPing)
    local _, specName, isFastGCD, profileLabel, rawHaste = GetActiveSpecQueueProfile()
    local hastePct = _SafeNum(rawHaste, _dfpsCachedHaste)
    local mode = GetSpellQueueMode()

    local calc = 400
    if mode == "SMART_AUTO" then
        if isFastGCD then
            -- Profile A: Fast GCD / High-APM & Reactive Healers/Melee (+95ms base buffer)
            calc = math.max(90, math.min(260, math.floor(effectivePing + 95 - math.min(20, hastePct * 0.4) + 0.5)))
        else
            -- Profile B: Standard Hard-Cast / Caster Specs (+130ms base buffer)
            calc = math.max(110, math.min(300, math.floor(effectivePing + 130 - math.min(20, hastePct * 0.3) + 0.5)))
        end
    elseif mode == "CUSTOM_MANUAL" then
        local manual = _SafeNum(DynamicFPSDB.spellQueueManualMS, 180)
        calc = math.max(50, math.min(400, math.floor((manual / 5) + 0.5) * 5))
    else
        -- "BLIZZARD_DEFAULT"
        calc = 400
    end

    cachedSafeTargetSQMS = calc
    return calc, worldMS, homeMS, specName, profileLabel, hastePct, mode
end
DynamicFPS.CalculateTargetSpellQueueMS = CalculateTargetSpellQueueMS

local lastAppliedSpellQueueMode = nil

local function ApplySpellQueueWindow(force)
    EnsureDBInitialized()
    if not DynamicFPSDB.enabled or IsYieldingSharedHooks() then return end
    if IsInRestrictedCombatOrKey() and not force then
        local mode = GetSpellQueueMode()
        local _, specName, _, profileLabel, hastePct = GetActiveSpecQueueProfile()
        return cachedSafeTargetSQMS, cachedSafeWorldMS, cachedSafeHomeMS, specName, profileLabel, hastePct, mode
    end
    local targetMS, worldMS, homeMS, specName, profileLabel, hastePct, mode = CalculateTargetSpellQueueMS()
    DynamicFPSDB.autoTuneSpellQueue = (mode ~= "BLIZZARD_DEFAULT")

    local currentCVar = _SafeNum(SafeGetCVar("SpellQueueWindow", 400), 400)
    local modeChanged = (lastAppliedSpellQueueMode ~= mode)
    if force or modeChanged or math.abs(currentCVar - targetMS) >= 5 then
        SafeSetCVar("SpellQueueWindow", targetMS)
        lastAppliedSpellQueueMode = mode
    end

    if _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
        pcall(_G.DynamicSuite.RefreshHeaderStatus)
    end
    return targetMS, worldMS, homeMS, specName, profileLabel, hastePct, mode
end
DynamicFPS.ApplySpellQueueWindow = ApplySpellQueueWindow

-- Combat Log Auto-Purge / Instance Auto-Logger
local function EvaluateCombatLogAutoPurge()
    EnsureDBInitialized()
    if not DynamicFPSDB.enabled or IsYieldingSharedHooks() or not LoggingCombat then return end
    -- Auto-yield 100% of combat log control when !ArchonLogger, LoggerHead, or RaiderIO_AutoCombatLog is active
    if HasExternalCombatLogger() then
        return
    end
    local mode = DynamicFPSDB.combatLogAutoPurge or "OFF"
    if mode == "OFF" then return end

    local ctx = GetCurrentZoneContext()
    local isMPlus = (C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()) or false
    local isRaid = (ctx == "RAID")
    local isDungeon = (ctx == "DUNGEONS") or isMPlus

    if mode == "ALWAYS_STOP_OUTDOOR" then
        if (ctx == "OUTDOOR" or ctx == "CITIES") and LoggingCombat() then
            LoggingCombat(false)
            print(ADDON_TITLE_COLORED .. ": Combat Logging stopped in Outdoor/City to prevent log bloat.")
        end
        return
    end

    local shouldLog = false
    if mode == "RAID_AND_MPLUS" then
        shouldLog = isRaid or isDungeon
    elseif mode == "MPLUS_ONLY" then
        shouldLog = isDungeon
    elseif mode == "RAID_ONLY" then
        shouldLog = isRaid
    end

    local active = LoggingCombat()
    if shouldLog and not active then
        LoggingCombat(true)
        print(ADDON_TITLE_COLORED .. ": Combat Logging |cFF10B981STARTED|r automatically.")
    elseif not shouldLog and active then
        LoggingCombat(false)
        print(ADDON_TITLE_COLORED .. ": Combat Logging |cFFF59E0BSTOPPED|r automatically (Left instance).")
    end
end
DynamicFPS.EvaluateCombatLogAutoPurge = EvaluateCombatLogAutoPurge

-- Quest Objective Tracker Declutter
local trackerAutoCollapsed = false

local function SetQuestTrackerCollapsed(collapse)
    if not ObjectiveTrackerFrame then return end
    -- Use C-level SetAlpha instead of ObjectiveTrackerFrame:SetCollapsed() or MinimizeButton:Click().
    -- Calling SetCollapsed() from addon code taints ObjectiveTrackerFrame.isCollapsed and child module state,
    -- which causes Blizzard_ScenarioObjectiveTracker -> ShouldShowMawBuffs -> GetAuraDataByIndex() to error
    -- when auras are secret during combat/encounters/Mythic+.
    if ObjectiveTrackerFrame.SetAlpha then
        ObjectiveTrackerFrame:SetAlpha(collapse and 0 or 1)
    end
end

local function EvaluateQuestTrackerDeclutter(inEncounter, inCombat)
    EnsureDBInitialized()
    if not DynamicFPSDB.enabled or IsYieldingSharedHooks() then
        if trackerAutoCollapsed then
            SetQuestTrackerCollapsed(false)
            trackerAutoCollapsed = false
        end
        return
    end
    local mode = DynamicFPSDB.questTrackerMode or "COLLAPSE_MPLUS_RAID"
    if mode == "ALWAYS_SHOW" then
        if trackerAutoCollapsed then
            SetQuestTrackerCollapsed(false)
            trackerAutoCollapsed = false
        end
        return
    end

    local ctx = GetCurrentZoneContext()
    local isInstance = (ctx == "RAID" or ctx == "DUNGEONS" or ctx == "DELVES" or ctx == "PVP")
    local inMPlus = (C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()) or false

    local shouldCollapse = false
    if mode == "HIDE_IN_COMBAT" then
        shouldCollapse = inCombat and true or false
    elseif mode == "COLLAPSE_BOSS" then
        shouldCollapse = inEncounter and true or false
    elseif mode == "COLLAPSE_INSTANCES" then
        shouldCollapse = isInstance
    elseif mode == "COLLAPSE_MPLUS_RAID" then
        shouldCollapse = inMPlus or (inEncounter and (ctx == "RAID" or ctx == "DUNGEONS"))
    end

    if shouldCollapse then
        if not trackerAutoCollapsed then
            SetQuestTrackerCollapsed(true)
            trackerAutoCollapsed = true
        end
    elseif trackerAutoCollapsed then
        SetQuestTrackerCollapsed(false)
        trackerAutoCollapsed = false
    end
end

-- Talking Head, Loot Banner & Vocal Error Speech Declutter
local SPAM_ERROR_SUBSTRINGS = {
    "not ready yet",
    "spell is not ready",
    "ability is not ready",
    "item is not ready",
    "not enough",
    "out of range",
    "another action is in progress",
    "can't do that while moving",
}

local function IsSpamCombatError(msg)
    if _IsSecret(msg) or type(msg) ~= "string" or msg == "" then return false end
    local ok, lower = pcall(string.lower, msg)
    if not ok or type(lower) ~= "string" then return false end
    for i = 1, #SPAM_ERROR_SUBSTRINGS do
        if lower:find(SPAM_ERROR_SUBSTRINGS[i], 1, true) then
            return true
        end
    end
    return false
end

local errorFilterFrame = CreateFrame("Frame")
local errorFilterHooked = false
local bossBannerHooked = false

local function ApplyDeclutterAudioSetting()
    EnsureDBInitialized()
    if not DynamicFPSDB.enabled or IsYieldingSharedHooks() then
        SafeSetCVar("Sound_EnableErrorSpeech", 1)
        if UIErrorsFrame and errorFilterHooked then
            errorFilterHooked = false
            errorFilterFrame:UnregisterEvent("UI_ERROR_MESSAGE")
            UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
        end
        return
    end
    local mode = DynamicFPSDB.declutterAudioMode or "MUTE_SPEECH_ONLY"
    local muteSpeech = (mode == "MUTE_ALL" or mode == "MUTE_SPEECH_ONLY")

    if muteSpeech then
        SafeSetCVar("Sound_EnableErrorSpeech", 0)
        if UIErrorsFrame and not errorFilterHooked then
            errorFilterHooked = true
            UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
            errorFilterFrame:RegisterEvent("UI_ERROR_MESSAGE")
            errorFilterFrame:SetScript("OnEvent", function(_, _, errorType, message)
                local curMode = DynamicFPSDB and DynamicFPSDB.declutterAudioMode or "MUTE_SPEECH_ONLY"
                local curMute = (curMode == "MUTE_ALL" or curMode == "MUTE_SPEECH_ONLY")
                if not curMute or not IsSpamCombatError(message) then
                    if UIErrorsFrame and UIErrorsFrame.AddMessage and message then
                        local r, g, b = 1.0, 0.1, 0.1
                        if GetGameMessageInfo and errorType and not _IsSecret(errorType) then
                            local okG, _, _, _, cr, cg, cb = pcall(GetGameMessageInfo, errorType)
                            if okG and cr and cg and cb and not _IsSecret(cr) then
                                r, g, b = cr, cg, cb
                            end
                        end
                        UIErrorsFrame:AddMessage(message, r, g, b, 1.0)
                    end
                end
            end)
        end
    else
        SafeSetCVar("Sound_EnableErrorSpeech", 1)
        if UIErrorsFrame and errorFilterHooked then
            errorFilterHooked = false
            errorFilterFrame:UnregisterEvent("UI_ERROR_MESSAGE")
            UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
        end
    end

    if BossBanner and not bossBannerHooked then
        bossBannerHooked = true
        BossBanner:HookScript("OnShow", function(self)
            if DynamicFPSDB and DynamicFPSDB.declutterAudioMode == "MUTE_ALL" then
                self:Hide()
                if type(TopBannerManager_BannerFinished) == "function" then
                    pcall(TopBannerManager_BannerFinished, self)
                end
            end
        end)
    end
end
DynamicFPS.ApplyDeclutterAudioSetting = ApplyDeclutterAudioSetting

-- ============================================================================
-- 7. STATUS TEXT & 90/8/2 SINGLE-ACCENT PALETTE BRIDGE (Items #17, #29)
-- ============================================================================
local function GetStatusText()
    EnsureDBInitialized()
    local zCtx = GetCurrentZoneContext()
    local zLabel = ZONE_NAMES[zCtx] or "Outdoor"
    local zTbl = (DynamicFPSDB.zones and DynamicFPSDB.zones[zCtx]) or DEFAULT_DB.zones[zCtx]
    local pKey = DetectMatchingPresetKey(zTbl, zCtx, DynamicFPSDB.activePresets and DynamicFPSDB.activePresets[zCtx])
    local pName = (pKey == "SAVED_BASE" and "Saved Base") or (STARTER_PRESETS[pKey] and STARTER_PRESETS[pKey].label) or "Custom"
    local sqMS, _, _, _, profileLabel, _, sqMode = CalculateTargetSpellQueueMS()
    local sqTag = (sqMode == "SMART_AUTO" and ("Auto-" .. (profileLabel or "Spec"))) or (sqMode == "CUSTOM_MANUAL" and "Manual") or "Default"
    return string.format("* %s: %s | SpellQueue: %dms (%s) | Telegraph Lock: ON", zLabel, pName, sqMS, sqTag)
end
DynamicFPS.GetStatusText = GetStatusText

local function GetActiveFontPath()
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.GetFont) == "function" then local okF, pF = pcall(_G.DynamicSuite.UI.GetFont); if okF and type(pF) == "string" and pF ~= "" then return pF end end
    if _G.DynamicSuite and type(_G.DynamicSuite.GetActiveFontPath) == "function" then
        local ok, p = pcall(_G.DynamicSuite.GetActiveFontPath, _G.DynamicSuite)
        if ok and type(p) == "string" and p ~= "" then return p end
    end
    if _G.DynamicLoadUI and type(_G.DynamicLoadUI.GetActiveFontPath) == "function" then
        local ok, path = pcall(_G.DynamicLoadUI.GetActiveFontPath)
        if ok and type(path) == "string" and path ~= "" then
            return path
        end
    end
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function SetStyledFont(fontString, size, flags, r, g, b, a)
    if not fontString then return end
    local fontPath = GetActiveFontPath()
    local ok = fontString:SetFont(fontPath, size or 12, flags or "")
    if not ok then
        fontString:SetFont("Fonts\\FRIZQT__.TTF", size or 12, flags or "")
    end
    fontString:SetShadowColor(0, 0, 0, 0.55)
    fontString:SetShadowOffset(1, -1)
    if r then
        fontString:SetTextColor(r, g or 1, b or 1, a or 1)
    end
end

-- Item #29: Always query _G.DynamicSuite:GetSuiteAccent() for active highlights
local function GetSuiteAccentColor()
    if _G.DynamicSuite and type(_G.DynamicSuite.GetSuiteAccent) == "function" then
        local ok, r, g, b = pcall(_G.DynamicSuite.GetSuiteAccent, _G.DynamicSuite)
        if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return r, g, b, 1.0
        end
        if ok and type(r) == "table" and r.r and r.g and r.b then
            return r.r, r.g, r.b, 1.0
        end
    end
    if _G.DynamicLoadUI and type(_G.DynamicLoadUI.GetAccentColor) == "function" then
        local ok, r, g, b = pcall(_G.DynamicLoadUI.GetAccentColor)
        if ok and r and g and b then
            return r, g, b, 1.0
        end
    end
    EnsureDBInitialized()
    local mode = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.accentMode) or "CLASS"
    if mode == "CLASS" and UnitClass and RAID_CLASS_COLORS then
        local _, classToken = UnitClass("player")
        local c = classToken and RAID_CLASS_COLORS[classToken]
        if c then
            return c.r, c.g, c.b, 1.0
        end
    end
    return 0.796, 0.835, 0.882, 1.0
end

local PALETTE = {
    VOID         = { r = 0.035, g = 0.039, b = 0.051, a = 0.98 }, -- #090A0D
    SUB_DRAWER   = { r = 0.059, g = 0.071, b = 0.094, a = 1.00 }, -- #0F1218 (Recessed Sub-Drawer)
    SURFACE_BASE = { r = 0.067, g = 0.075, b = 0.094, a = 1.00 }, -- #111318
    CELL_NEUTRAL = { r = 0.078, g = 0.090, b = 0.122, a = 1.00 }, -- #14171F (Neutral Cell / Inactive Tab & Pill)
    SURFACE_CARD = { r = 0.102, g = 0.118, b = 0.153, a = 1.00 }, -- #1A1E27
    BORDER_CELL  = { r = 0.145, g = 0.165, b = 0.212, a = 1.00 }, -- #252A36 (Crisp 1px Cell Border)
    EMERALD      = { r = 0.063, g = 0.725, b = 0.506, a = 1.00 }, -- #10B981
    AMBER        = { r = 0.961, g = 0.620, b = 0.043, a = 1.00 }, -- #F59E0B
    ROSE         = { r = 0.957, g = 0.247, b = 0.369, a = 1.00 }, -- #F43F5E
    TEXT_PRI     = { r = 0.945, g = 0.961, b = 0.976, a = 1.00 }, -- #F1F5F9
    TEXT_SEC     = { r = 0.580, g = 0.639, b = 0.722, a = 0.92 }, -- #94A3B8
    TEXT_MUTED   = { r = 0.392, g = 0.455, b = 0.545, a = 0.85 }, -- #64748B
}

local function CreateSolidTex(parent, layer, sublevel, r, g, b, a)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    tex:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
    return tex
end

local function Create1PxBorder(frame, r, g, b, a)
    local br = r or PALETTE.BORDER_CELL.r
    local bg = g or PALETTE.BORDER_CELL.g
    local bb = b or PALETTE.BORDER_CELL.b
    local ba = a or PALETTE.BORDER_CELL.a

    local top = CreateSolidTex(frame, "OVERLAY", 2, br, bg, bb, ba)
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    top:SetHeight(1)

    local bottom = CreateSolidTex(frame, "OVERLAY", 2, br, bg, bb, ba)
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(1)

    local left = CreateSolidTex(frame, "OVERLAY", 2, br, bg, bb, ba)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -1)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 1)
    left:SetWidth(1)

    local right = CreateSolidTex(frame, "OVERLAY", 2, br, bg, bb, ba)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -1)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 1)
    right:SetWidth(1)

    frame.borderParts = { top = top, bottom = bottom, left = left, right = right }
    function frame:SetBorderColor(nr, ng, nb, na)
        top:SetColorTexture(nr, ng, nb, na or 1)
        bottom:SetColorTexture(nr, ng, nb, na or 1)
        left:SetColorTexture(nr, ng, nb, na or 1)
        right:SetColorTexture(nr, ng, nb, na or 1)
    end
    return frame.borderParts
end

-- ============================================================================
-- 8. DIRECTION A CONTROL TAXONOMY & EUI-STYLE DROPDOWNS
-- ============================================================================
local activeDropdownPopup = nil
local dropdownClickCatcher = nil

local function CloseActiveDropdownMenu()
    if activeDropdownPopup then
        if activeDropdownPopup.ownerBtn and activeDropdownPopup.ownerBtn.chevronTex then
            activeDropdownPopup.ownerBtn.chevronTex:SetTexture(ICON_CHEVRON_DOWN)
        end
        activeDropdownPopup:Hide()
    end
    if dropdownClickCatcher then
        dropdownClickCatcher:Hide()
    end
end

-- 8A. 2-Pill Binary Segmented Switch: [ Off | Enabled ]
local function CreateBinarySegmentedSwitch(parent, getValFn, setValFn, offText, onText)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(172, 26)

    local minPillW = 68
    local gap = 4

    local btnOff = CreateFrame("Button", nil, container)
    btnOff:SetSize(minPillW, 26)
    btnOff.bg = CreateSolidTex(btnOff, "BACKGROUND", 1, PALETTE.CELL_NEUTRAL.r, PALETTE.CELL_NEUTRAL.g, PALETTE.CELL_NEUTRAL.b, 1.0)
    btnOff.bg:SetAllPoints()
    Create1PxBorder(btnOff, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)

    btnOff.checkTex = btnOff:CreateTexture(nil, "OVERLAY")
    btnOff.checkTex:SetSize(6, 6)
    btnOff.checkTex:SetPoint("LEFT", btnOff, "LEFT", 8, 0)
    btnOff.checkTex:SetColorTexture(1, 1, 1, 0.98)
    btnOff.checkTex:Hide()

    btnOff.OffBar = btnOff:CreateTexture(nil, "OVERLAY")
    btnOff.OffBar:SetHeight(1.5)
    btnOff.OffBar:SetPoint("BOTTOMLEFT", btnOff, "BOTTOMLEFT", 1, 1)
    btnOff.OffBar:SetPoint("BOTTOMRIGHT", btnOff, "BOTTOMRIGHT", -1, 1)
    btnOff.OffBar:SetColorTexture(0.973, 0.443, 0.443, 0.85)
    btnOff.OffBar:Hide()

    btnOff.lbl = btnOff:CreateFontString(nil, "OVERLAY")
    btnOff.lbl:SetPoint("CENTER", btnOff, "CENTER", 0, 0)
    btnOff.lbl:SetWordWrap(false)
    SetStyledFont(btnOff.lbl, 11, "", PALETTE.TEXT_SEC.r, PALETTE.TEXT_SEC.g, PALETTE.TEXT_SEC.b, 0.9)

    local btnOn = CreateFrame("Button", nil, container)
    btnOn:SetSize(minPillW, 26)
    btnOn.bg = CreateSolidTex(btnOn, "BACKGROUND", 1, PALETTE.CELL_NEUTRAL.r, PALETTE.CELL_NEUTRAL.g, PALETTE.CELL_NEUTRAL.b, 1.0)
    btnOn.bg:SetAllPoints()
    Create1PxBorder(btnOn, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)

    btnOn.checkTex = btnOn:CreateTexture(nil, "OVERLAY")
    btnOn.checkTex:SetSize(6, 6)
    btnOn.checkTex:SetPoint("LEFT", btnOn, "LEFT", 8, 0)
    btnOn.checkTex:SetColorTexture(1, 1, 1, 0.98)
    btnOn.checkTex:Hide()

    btnOn.lbl = btnOn:CreateFontString(nil, "OVERLAY")
    btnOn.lbl:SetPoint("CENTER", btnOn, "CENTER", 0, 0)
    btnOn.lbl:SetWordWrap(false)
    SetStyledFont(btnOn.lbl, 11, "", PALETTE.TEXT_SEC.r, PALETTE.TEXT_SEC.g, PALETTE.TEXT_SEC.b, 0.9)

    function container:RefreshValue()
        local isEnabled = getValFn() and true or false
        local ar, ag, ab = GetSuiteAccentColor()
        btnOff.lbl:SetText(offText or "Off")
        btnOn.lbl:SetText(onText or "Enabled")

        if isEnabled then
            btnOff.OffBar:Hide()
            btnOff.bg:SetColorTexture(PALETTE.CELL_NEUTRAL.r, PALETTE.CELL_NEUTRAL.g, PALETTE.CELL_NEUTRAL.b, 1.0)
            btnOff:SetBorderColor(PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)
            SetStyledFont(btnOff.lbl, 11, "", PALETTE.TEXT_SEC.r, PALETTE.TEXT_SEC.g, PALETTE.TEXT_SEC.b, 0.85)
            btnOff.checkTex:Hide()
            btnOff.lbl:ClearAllPoints()
            btnOff.lbl:SetPoint("CENTER", btnOff, "CENTER", 0, 0)

            local fillAlpha = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42
            btnOn.bg:SetColorTexture(ar * fillAlpha, ag * fillAlpha, ab * fillAlpha, 1.0)
            btnOn:SetBorderColor(ar, ag, ab, 0.95)
            SetStyledFont(btnOn.lbl, 11, "", PALETTE.TEXT_PRI.r, PALETTE.TEXT_PRI.g, PALETTE.TEXT_PRI.b, 1.0)
            btnOn.checkTex:SetColorTexture(1, 1, 1, 0.98)
            btnOn.checkTex:Hide()
            btnOn.lbl:ClearAllPoints()
            btnOn.lbl:SetPoint("CENTER", btnOn, "CENTER", 0, 0)
        else
            btnOff.OffBar:Show()
            btnOff.bg:SetColorTexture(0.118, 0.141, 0.188, 0.98)
            btnOff:SetBorderColor(0.392, 0.455, 0.545, 0.90)
            SetStyledFont(btnOff.lbl, 11, "", 0.886, 0.910, 0.941, 1.0)
            btnOff.checkTex:SetColorTexture(1, 1, 1, 0.98)
            btnOff.checkTex:Hide()
            btnOff.lbl:ClearAllPoints()
            btnOff.lbl:SetPoint("CENTER", btnOff, "CENTER", 0, 0)

            btnOn.bg:SetColorTexture(PALETTE.CELL_NEUTRAL.r, PALETTE.CELL_NEUTRAL.g, PALETTE.CELL_NEUTRAL.b, 1.0)
            btnOn:SetBorderColor(PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)
            SetStyledFont(btnOn.lbl, 11, "", PALETTE.TEXT_SEC.r, PALETTE.TEXT_SEC.g, PALETTE.TEXT_SEC.b, 0.85)
            btnOn.checkTex:Hide()
            btnOn.lbl:ClearAllPoints()
            btnOn.lbl:SetPoint("CENTER", btnOn, "CENTER", 0, 0)
        end

        local rawOff = (btnOff.lbl.GetUnboundedStringWidth and btnOff.lbl:GetUnboundedStringWidth()) or btnOff.lbl:GetStringWidth() or 0; local offW = math.max(minPillW, math.ceil(math.max(rawOff, 24) + 28))
        local rawOn = (btnOn.lbl.GetUnboundedStringWidth and btnOn.lbl:GetUnboundedStringWidth()) or btnOn.lbl:GetStringWidth() or 0; local onW = math.max(minPillW, math.ceil(math.max(rawOn, 46) + 32))
        btnOff:SetWidth(offW)
        btnOn:SetWidth(onW)

        btnOff:ClearAllPoints()
        btnOff:SetPoint("LEFT", container, "LEFT", 0, 0)
        btnOn:ClearAllPoints()
        btnOn:SetPoint("LEFT", btnOff, "RIGHT", gap, 0)
        container:SetWidth(offW + gap + onW)
    end

    btnOff:SetScript("OnClick", function()
        CloseActiveDropdownMenu()
        if getValFn() then
            setValFn(false)
            container:RefreshValue()
        end
    end)

    btnOn:SetScript("OnClick", function()
        CloseActiveDropdownMenu()
        if not getValFn() then
            setValFn(true)
            container:RefreshValue()
        end
    end)

    container:HookScript("OnShow", function(s) s:RefreshValue() end)
    container:RefreshValue()
    return container
end

-- 8A-2. Full-Width Horizontal Chevron Toggle Bar (24px tall, Sub-Settings (N)) per DESIGN_SYSTEM.md Section 2.6
local function CreateSubDrawerButton(groupCard, getOpenFn, toggleOpenFn, subCount, isEnabledFn)
    local bar = CreateFrame("Button", nil, groupCard, "BackdropTemplate")
    bar:SetHeight(24)
    bar:SetPoint("TOPLEFT", groupCard, "TOPLEFT", 10, -52)
    bar:SetPoint("TOPRIGHT", groupCard, "TOPRIGHT", -10, -52)
    bar:EnableMouse(true)
    bar:RegisterForClicks("AnyUp")

    bar.bg = CreateSolidTex(bar, "BACKGROUND", 2, PALETTE.CELL_NEUTRAL.r, PALETTE.CELL_NEUTRAL.g, PALETTE.CELL_NEUTRAL.b, 0.96)
    bar.bg:SetAllPoints()
    Create1PxBorder(bar, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 0.95)

    local count = _SafeNum(subCount, 1)
    local label = bar:CreateFontString(nil, "OVERLAY")
    SetStyledFont(label, 11, "", PALETTE.TEXT_PRI.r, PALETTE.TEXT_PRI.g, PALETTE.TEXT_PRI.b, 1.0)
    label:SetPoint("CENTER", bar, "CENTER", 8, 0)
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    label:SetText(string.format("Sub-Settings (%d)", count))
    bar.label = label

    local chevTex = bar:CreateTexture(nil, "ARTWORK")
    chevTex:SetSize(11, 11)
    chevTex:SetPoint("RIGHT", label, "LEFT", -6, 0)
    chevTex:SetTexture(ICON_CHEVRON_DOWN)
    chevTex:SetTexCoord(0, 1, 0, 1)
    if chevTex.SetSnapToPixelGrid then chevTex:SetSnapToPixelGrid(false) end
    if chevTex.SetTexelSnappingBias then chevTex:SetTexelSnappingBias(0) end
    bar.chevTex = chevTex
    bar.chevron = chevTex

    function bar:RefreshValue(hovered)
        local isEnabled = (not isEnabledFn) or (isEnabledFn() and true or false)
        local isOpen = isEnabled and (getOpenFn() ~= false)
        local ar, ag, ab = GetSuiteAccentColor()
        local fillAlpha = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42

        local count = _SafeNum(self.subCount, _SafeNum(subCount, 1))
        self:SetShown(isEnabled)
        SetStyledFont(self.label, 11, "")
        self.label:SetText(string.format("Sub-Settings (%d)", count))
        self.chevTex:SetTexture(isOpen and ICON_CHEVRON_UP or ICON_CHEVRON_DOWN)
        if self.chevTex.SetSnapToPixelGrid then self.chevTex:SetSnapToPixelGrid(false) end
        if self.chevTex.SetTexelSnappingBias then self.chevTex:SetTexelSnappingBias(0) end

        if hovered then
            local hovA = math.min(0.65, fillAlpha + 0.10)
            self.bg:SetColorTexture(ar * hovA, ag * hovA, ab * hovA, 0.98)
            self:SetBorderColor(ar, ag, ab, 1.0)
            self.chevTex:SetVertexColor(1.0, 1.0, 1.0, 1.0)
            self.label:SetTextColor(1.0, 1.0, 1.0, 1.0)
        elseif isOpen then
            local expA = fillAlpha * 0.60
            self.bg:SetColorTexture(ar * expA, ag * expA, ab * expA, 0.96)
            self:SetBorderColor(ar, ag, ab, 0.95)
            self.chevTex:SetVertexColor(1.0, 1.0, 1.0, 1.0)
            self.label:SetTextColor(1.0, 1.0, 1.0, 1.0)
        else
            self.bg:SetColorTexture(0.078, 0.090, 0.122, 0.96)
            self:SetBorderColor(0.145, 0.165, 0.212, 0.95)
            self.chevTex:SetVertexColor(ar, ag, ab, 0.95)
            self.label:SetTextColor(0.84, 0.89, 0.96, 1.0)
        end

        if groupCard and groupCard.SetBorderColor then
            if not isEnabled then
                groupCard:SetBorderColor(PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 0.95)
            elseif isOpen then
                groupCard:SetBorderColor(ar, ag, ab, 0.85)
            else
                groupCard:SetBorderColor(ar * 0.65, ag * 0.65, ab * 0.65, 0.80)
            end
        end
    end

    bar:SetScript("OnEnter", function(self)
        self:RefreshValue(true)
    end)
    bar:SetScript("OnLeave", function(self)
        self:RefreshValue(false)
    end)

    bar:SetScript("OnClick", function(self)
        CloseActiveDropdownMenu()
        toggleOpenFn()
        self:RefreshValue(self:IsMouseOver())
    end)

    groupCard.tuneBar = bar
    groupCard.horizontalChevronBar = bar
    bar:RefreshValue(false)
    return bar
end

-- 8B. 2-to-5 Short Options: Inline Segmented Pills (Auto-Sized with Option 3 Negative Pill Styling & 6-Tier Semantic Underline)
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

local function CreateSegmentedPills(parent, totalWidth, options, getValFn, setValFn, tooltipFn)
    local container = CreateFrame("Frame", nil, parent)
    local w = totalWidth or 248
    container:SetSize(w, 26)

    local count = math.max(1, #options)
    local gap = 4
    local minPillW = (count >= 5) and 44 or math.max(52, math.floor((w - ((count - 1) * gap)) / count))
    local pills = {}

    for i, opt in ipairs(options) do
        local p = CreateFrame("Button", nil, container)
        p:SetSize(minPillW, 26)
        p.bg = CreateSolidTex(p, "BACKGROUND", 1, PALETTE.CELL_NEUTRAL.r, PALETTE.CELL_NEUTRAL.g, PALETTE.CELL_NEUTRAL.b, 1.0)
        p.bg:SetAllPoints()
        Create1PxBorder(p, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)

        p.checkTex = p:CreateTexture(nil, "OVERLAY")
        p.checkTex:SetSize(6, 6)
        p.checkTex:SetPoint("LEFT", p, "LEFT", 8, 0)
        p.checkTex:SetColorTexture(1, 1, 1, 0.98)
        p.checkTex:Hide()

        p.OffBar = p:CreateTexture(nil, "OVERLAY")
        p.OffBar:SetHeight(1.5)
        p.OffBar:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 1, 1)
        p.OffBar:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -1, 1)
        p.OffBar:SetColorTexture(0.973, 0.443, 0.443, 0.90)
        p.OffBar:Hide()
        p.TierBar = p.OffBar

        p.lbl = p:CreateFontString(nil, "OVERLAY")
        p.lbl:SetPoint("CENTER", p, "CENTER", 0, 0)
        p.lbl:SetJustifyH("CENTER")
        p.lbl:SetWordWrap(false)
        SetStyledFont(p.lbl, 10.5, "", PALETTE.TEXT_SEC.r, PALETTE.TEXT_SEC.g, PALETTE.TEXT_SEC.b, 0.9)
        p.lbl:SetText(opt.label)
        p.optValue = opt.value
        p.optLabel = opt.label
        p.isNegativeOpt = IsNegativePillOption(opt.value, opt.label)

        p:SetScript("OnEnter", function(self)
            if self.isNegativeOpt then
                self:SetBorderColor(0.392, 0.455, 0.545, 0.95)
            else
                local ar, ag, ab = GetSuiteAccentColor()
                self:SetBorderColor(ar, ag, ab, 0.95)
            end
            if type(tooltipFn) == "function" then
                tooltipFn(self, opt)
            end
        end)
        p:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
            container:RefreshValue()
        end)

        p:SetScript("OnClick", function()
            CloseActiveDropdownMenu()
            setValFn(opt.value)
            container:RefreshValue()
        end)

        pills[i] = p
    end

    function container:RefreshValue()
        local cur = getValFn()
        local ar, ag, ab = GetSuiteAccentColor()
        local xCursor = 0

        for idx, p in ipairs(pills) do
            local isSelected = (p.optValue == cur)
            if isSelected then
                local tr, tg, tb, ta, isNeg = GetPillTierUnderlineColor(p.optValue, p.optLabel)
                if isNeg or p.isNegativeOpt then
                    p.bg:SetColorTexture(0.118, 0.141, 0.188, 0.98)
                    p:SetBorderColor(0.392, 0.455, 0.545, 0.90)
                    SetStyledFont(p.lbl, 10.5, "", 0.886, 0.910, 0.941, 1.0)
                    p.OffBar:SetColorTexture(tr or 0.973, tg or 0.443, tb or 0.443, ta or 0.90)
                    p.OffBar:Show()
                else
                    local fillAlpha = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42
                    p.bg:SetColorTexture(ar * fillAlpha, ag * fillAlpha, ab * fillAlpha, 1.0)
                    p:SetBorderColor(ar, ag, ab, 0.95)
                    SetStyledFont(p.lbl, 10.5, "", PALETTE.TEXT_PRI.r, PALETTE.TEXT_PRI.g, PALETTE.TEXT_PRI.b, 1.0)
                    if tr then
                        p.OffBar:SetColorTexture(tr, tg, tb, ta)
                        p.OffBar:Show()
                    else
                        p.OffBar:Hide()
                    end
                end
                p.checkTex:SetColorTexture(1, 1, 1, 0.98)
                p.checkTex:Hide()
                p.lbl:ClearAllPoints()
                p.lbl:SetPoint("CENTER", p, "CENTER", 0, 0)
                p.lbl:SetJustifyH("CENTER")
            else
                p.OffBar:Hide()
                p.bg:SetColorTexture(PALETTE.CELL_NEUTRAL.r, PALETTE.CELL_NEUTRAL.g, PALETTE.CELL_NEUTRAL.b, 1.0)
                p:SetBorderColor(PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)
                SetStyledFont(p.lbl, 10.5, "", PALETTE.TEXT_SEC.r, PALETTE.TEXT_SEC.g, PALETTE.TEXT_SEC.b, 0.88)
                p.checkTex:Hide()
                p.lbl:ClearAllPoints()
                p.lbl:SetPoint("CENTER", p, "CENTER", 0, 0)
                p.lbl:SetJustifyH("CENTER")
            end

            local rawW = (p.lbl.GetUnboundedStringWidth and p.lbl:GetUnboundedStringWidth()) or p.lbl:GetStringWidth() or 0
            local strW = math.max(rawW, #(tostring(p.lbl:GetText() or "")) * 6.5)
            local padW = (count >= 5) and 14 or 20
            local pillW = math.max(minPillW, math.ceil(strW + padW))
            p:SetWidth(pillW)
            p:ClearAllPoints()
            p:SetPoint("LEFT", container, "LEFT", xCursor, 0)
            xCursor = xCursor + pillW + (idx < #pills and gap or 0)
        end

        container:SetWidth(math.max(w, xCursor))
    end

    container:HookScript("OnShow", function(s) s:RefreshValue() end)
    container:RefreshValue()
    return container
end

-- 8C. 5+ Options: EUI-Style Auto-Expanding Obsidian Dropdown (Items #24, #28, #30, #34)
local function CreateObsidianDropdown(parent, width, options, getValueFn, setValueFn)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(math.max(width or 268, 268), 26)

    btn.bg = CreateSolidTex(btn, "BACKGROUND", 1, PALETTE.CELL_NEUTRAL.r, PALETTE.CELL_NEUTRAL.g, PALETTE.CELL_NEUTRAL.b, 1.0)
    btn.bg:SetAllPoints()
    Create1PxBorder(btn, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)

    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", btn, "LEFT", 10, 0)
    text:SetPoint("RIGHT", btn, "RIGHT", -26, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    SetStyledFont(text, 11, "", PALETTE.TEXT_PRI.r, PALETTE.TEXT_PRI.g, PALETTE.TEXT_PRI.b, 1.0)
    btn.text = text

    local chevronTex = btn:CreateTexture(nil, "OVERLAY")
    chevronTex:SetSize(12, 12)
    chevronTex:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    chevronTex:SetTexture(ICON_CHEVRON_DOWN)
    btn.chevronTex = chevronTex

    function btn:RefreshValue()
        local cur = getValueFn()
        local foundLabel = tostring(cur or "")
        for _, opt in ipairs(options) do
            if opt.value == cur then
                foundLabel = opt.label
                break
            end
        end
        text:SetText(foundLabel)
        local ar, ag, ab = GetSuiteAccentColor()
        chevronTex:SetVertexColor(ar, ag, ab, 0.95)
    end

    -- Item #24: Auto-close popup if dropdown button hides (zero ghost menus)
    btn:HookScript("OnHide", function(self)
        if activeDropdownPopup and activeDropdownPopup.ownerBtn == self then
            CloseActiveDropdownMenu()
        end
    end)

    btn:SetScript("OnEnter", function(self)
        local ar, ag, ab = GetSuiteAccentColor()
        self:SetBorderColor(ar, ag, ab, 0.9)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBorderColor(PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)
    end)

    btn:SetScript("OnClick", function(self)
        if activeDropdownPopup and activeDropdownPopup.ownerBtn == self and activeDropdownPopup:IsShown() then
            CloseActiveDropdownMenu()
            return
        end
        CloseActiveDropdownMenu()

        if not dropdownClickCatcher then
            dropdownClickCatcher = CreateFrame("Button", "DynamicFPSDropdownClickCatcher", UIParent)
            dropdownClickCatcher:SetAllPoints(UIParent)
            dropdownClickCatcher:SetFrameStrata("DIALOG")
            dropdownClickCatcher:EnableMouse(true)
            dropdownClickCatcher:SetScript("OnClick", function()
                CloseActiveDropdownMenu()
            end)
        end

        if not activeDropdownPopup then
            local popup = CreateFrame("Frame", "DynamicFPSDropdownPopup", UIParent)
            popup:SetFrameStrata("TOOLTIP")
            popup:SetToplevel(true)
            popup:EnableMouse(true)
            popup.bg = CreateSolidTex(popup, "BACKGROUND", 0, PALETTE.VOID.r, PALETTE.VOID.g, PALETTE.VOID.b, 0.99)
            popup.bg:SetAllPoints()
            Create1PxBorder(popup, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)
            popup.measureFS = popup:CreateFontString(nil, "OVERLAY")
            popup.rows = {}
            activeDropdownPopup = popup
        end

        local popup = activeDropdownPopup
        popup.ownerBtn = self
        self.chevronTex:SetTexture(ICON_CHEVRON_UP)

        -- Calculate auto-expanding popup width so zero option text is truncated
        SetStyledFont(popup.measureFS, 11, "")
        local maxOptionWidth = 0
        for _, opt in ipairs(options) do
            popup.measureFS:SetText(opt.label or "")
            local w = (popup.measureFS.GetUnboundedStringWidth and popup.measureFS:GetUnboundedStringWidth()) or popup.measureFS:GetStringWidth() or 0
            if w > maxOptionWidth then
                maxOptionWidth = w
            end
        end
        local popupW = math.max(self:GetWidth(), math.ceil(maxOptionWidth + 44))

        for _, r in ipairs(popup.rows) do
            r:Hide()
        end

        local curVal = getValueFn()
        local ar, ag, ab = GetSuiteAccentColor()
        local rowH = 26

        for i, opt in ipairs(options) do
            local row = popup.rows[i]
            if not row then
                row = CreateFrame("Button", nil, popup)
                row:SetHeight(rowH)
                row.bg = CreateSolidTex(row, "BACKGROUND", 1, 0, 0, 0, 0)
                row.bg:SetAllPoints()

                row.checkIcon = row:CreateTexture(nil, "OVERLAY")
                row.checkIcon:SetSize(12, 12)
                row.checkIcon:SetPoint("LEFT", row, "LEFT", 8, 0)
                row.checkIcon:SetTexture(ICON_CHECK)

                row.lbl = row:CreateFontString(nil, "OVERLAY")
                row.lbl:SetPoint("LEFT", row, "LEFT", 26, 0)
                row.lbl:SetPoint("RIGHT", row, "RIGHT", -10, 0)
                row.lbl:SetJustifyH("LEFT")
                row.lbl:SetWordWrap(false)
                popup.rows[i] = row
            end

            row:SetPoint("TOPLEFT", popup, "TOPLEFT", 1, -((i - 1) * rowH) - 1)
            row:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -1, -((i - 1) * rowH) - 1)

            local isSelected = (opt.value == curVal)
            if isSelected then
                row.bg:SetColorTexture(ar * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), ag * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), ab * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), 0.96)
                row.checkIcon:SetVertexColor(ar, ag, ab, 1.0)
                row.checkIcon:Show()
                SetStyledFont(row.lbl, 11, "", PALETTE.TEXT_PRI.r, PALETTE.TEXT_PRI.g, PALETTE.TEXT_PRI.b, 1.0)
            else
                row.bg:SetColorTexture(0, 0, 0, 0)
                row.checkIcon:Hide()
                SetStyledFont(row.lbl, 11, "", PALETTE.TEXT_SEC.r, PALETTE.TEXT_SEC.g, PALETTE.TEXT_SEC.b, 0.95)
            end
            row.lbl:SetText(opt.label)

            row:SetScript("OnEnter", function(rSelf)
                rSelf.bg:SetColorTexture(ar * 0.32, ag * 0.32, ab * 0.32, 0.96)
            end)
            row:SetScript("OnLeave", function(rSelf)
                if opt.value == getValueFn() then
                    rSelf.bg:SetColorTexture(ar * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), ag * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), ab * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), 0.96)
                else
                    rSelf.bg:SetColorTexture(0, 0, 0, 0)
                end
            end)
            row:SetScript("OnClick", function()
                setValueFn(opt.value)
                self:RefreshValue()
                CloseActiveDropdownMenu()
            end)
            row:Show()
        end

        popup:ClearAllPoints()
        popup:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -2)
        popup:SetSize(popupW, (#options * rowH) + 2)
        dropdownClickCatcher:Show()
        popup:Show()
    end)

    btn:RefreshValue()
    return btn
end

-- 8D. Sleek Precision Track Slider Control
local function CreateInlineSliderControl(parent, width, minVal, maxVal, stepVal, getValFn, setValFn, formatFn)
    local wrap = CreateFrame("Frame", nil, parent)
    wrap:SetSize(256, 26)
    stepVal = stepVal or 1

    local valTxt = wrap:CreateFontString(nil, "OVERLAY")
    valTxt:SetPoint("RIGHT", wrap, "RIGHT", 0, 0)
    valTxt:SetWidth(52)
    valTxt:SetJustifyH("RIGHT")
    valTxt:SetWordWrap(false)
    local ar0, ag0, ab0 = GetSuiteAccentColor()
    SetStyledFont(valTxt, 11, "", ar0, ag0, ab0, 1.0)

    local slider = CreateFrame("Slider", nil, wrap)
    slider:SetPoint("LEFT", wrap, "LEFT", 0, 0)
    slider:SetPoint("RIGHT", valTxt, "LEFT", -10, 0)
    slider:SetHeight(4)
    slider:SetHitRectInsets(0, 0, -10, -10)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(stepVal)
    slider:EnableMouse(true)
    slider:EnableMouseWheel(true)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(false)
    end

    slider.track = CreateSolidTex(slider, "BACKGROUND", 1, 0.035, 0.039, 0.051, 0.98)
    slider.track:SetAllPoints()
    Create1PxBorder(slider, 1, 1, 1, 0.14)

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

    local suppressCallback = false
    local isDragging = false
    local lastCommittedValue = nil

    local function SnapValue(v)
        local safeV = _SafeNum(v, minVal)
        safeV = math.max(minVal, math.min(maxVal, safeV))
        local st = stepVal or 1
        local snapped = math.floor(((safeV - minVal) / st) + 0.5) * st + minVal
        return math.max(minVal, math.min(maxVal, snapped))
    end

    local function UpdateFillAndThumb(rawVal)
        local cr, cg, cb = GetSuiteAccentColor()
        fill:SetColorTexture(cr, cg, cb, 0.85)
        SetStyledFont(valTxt, 11, "", cr, cg, cb, 1.0)
        if isDragging or slider:IsMouseOver() then
            thumb:SetColorTexture(cr, cg, cb, 1.0)
        else
            thumb:SetColorTexture(0.97, 0.98, 1.00, 1.0)
        end
        local v = _SafeNum(rawVal, _SafeNum(slider:GetValue(), minVal))
        local pct = (maxVal > minVal) and ((v - minVal) / (maxVal - minVal)) or 0
        pct = math.max(0, math.min(1, pct))
        local tw = slider:GetWidth()
        if not tw or tw <= 0 then tw = 194 end
        fill:SetWidth(math.max(1, pct * math.max(1, tw - 2)))
    end

    function wrap:RefreshValue()
        suppressCallback = true
        local cur = SnapValue(getValFn())
        lastCommittedValue = cur
        slider:SetValue(cur)
        valTxt:SetText(formatFn and formatFn(cur) or tostring(cur))
        UpdateFillAndThumb(cur)
        suppressCallback = false
    end

    slider:SetScript("OnValueChanged", function(_, rawVal)
        if suppressCallback then return end
        local snapped = SnapValue(rawVal)
        valTxt:SetText(formatFn and formatFn(snapped) or tostring(snapped))
        UpdateFillAndThumb(rawVal)
        if snapped ~= lastCommittedValue then
            lastCommittedValue = snapped
            setValFn(snapped)
        end
    end)

    local function UpdateSliderFromCursor()
        if isDragging and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            isDragging = false
            slider:SetScript("OnUpdate", nil)
            wrap:RefreshValue()
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
            CloseActiveDropdownMenu()
            isDragging = true
            UpdateSliderFromCursor()
            self:SetScript("OnUpdate", UpdateSliderFromCursor)
        end
    end)
    slider:SetScript("OnMouseUp", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
        wrap:RefreshValue()
    end)
    slider:SetScript("OnEnter", function(self)
        UpdateFillAndThumb()
        if GameTooltip then
            local cr, cg, cb = GetSuiteAccentColor()
            local hex = string.format("%02X%02X%02X", math.floor(cr * 255 + 0.5), math.floor(cg * 255 + 0.5), math.floor(cb * 255 + 0.5))
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
        CloseActiveDropdownMenu()
        local cur = _SafeNum(getValFn(), minVal)
        local newVal = SnapValue(cur + (delta > 0 and stepVal or -stepVal))
        lastCommittedValue = newVal
        setValFn(newVal)
        wrap:RefreshValue()
    end)
    slider:SetScript("OnSizeChanged", function()
        UpdateFillAndThumb()
    end)

    wrap:HookScript("OnShow", function(s) C_Timer.After(0, function() s:RefreshValue() end) end)
    wrap:RefreshValue()
    return wrap
end

-- 8E. Section Header & Individual Setting Card Builders
local function CreateSectionBox(parent, yTop, height)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box.innerPadX = 14
    if yTop ~= nil then
        box:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yTop)
        box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yTop)
    end
    box:SetHeight(height or 200)
    box.bg = CreateSolidTex(box, "BACKGROUND", 0, PALETTE.SURFACE_BASE.r, PALETTE.SURFACE_BASE.g, PALETTE.SURFACE_BASE.b, 0.96)
    box.bg:SetAllPoints()
    Create1PxBorder(box, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 0.95)
    return box
end

local function CreateSectionHeader(parent, arg2, arg3, subtitleText, padOverride)
    local titleText, yOffset
    if type(arg2) == "number" then
        yOffset = arg2
        titleText = arg3
    else
        titleText = arg2
        yOffset = arg3
    end

    local padX = padOverride or parent.innerPadX or 0
    local hasSub = (subtitleText and subtitleText ~= "")
    local hdr = CreateFrame("Frame", nil, parent)
    local y = yOffset or 0
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
    hdr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -padX, y)
    hdr:SetHeight(hasSub and 36 or 20)
    hdr.hasSub = hasSub

    local ar, ag, ab = GetSuiteAccentColor()
    local leftBar = CreateSolidTex(hdr, "ARTWORK", 1, ar, ag, ab, 1.0)
    leftBar:SetSize(3, hasSub and 34 or 16)
    leftBar:SetPoint("TOPLEFT", hdr, "TOPLEFT", 0, -1)
    hdr.leftBar = leftBar

    local botLine = CreateSolidTex(hdr, "ARTWORK", 1, ar, ag, ab, 0.35)
    botLine:SetHeight(1)
    botLine:SetPoint("TOPLEFT", leftBar, "BOTTOMLEFT", 0, 0)
    botLine:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
    hdr.botLine = botLine

    local txt = hdr:CreateFontString(nil, "OVERLAY")
    if hasSub then
        txt:SetPoint("TOPLEFT", leftBar, "TOPRIGHT", 8, 0)
    else
        txt:SetPoint("LEFT", leftBar, "RIGHT", 8, 0)
    end
    SetStyledFont(txt, 11, "", ar, ag, ab, 1.0)
    txt:SetText(string.upper(titleText or ""))
    hdr.txt = txt
    hdr.title = txt

    if hasSub then
        local sub = hdr:CreateFontString(nil, "OVERLAY")
        sub:SetPoint("TOPLEFT", txt, "BOTTOMLEFT", 0, -3)
        sub:SetPoint("RIGHT", hdr, "RIGHT", -12, 0)
        sub:SetJustifyH("LEFT")
        sub:SetWordWrap(false)
        SetStyledFont(sub, 10, "", 0.64, 0.70, 0.78, 1.0)
        sub:SetText(subtitleText)
        hdr.subtitle = sub
    end

    function hdr:SetText(newText)
        if self.title then
            self.title:SetText(string.upper(newText or ""))
        end
    end

    function hdr:RefreshAccent()
        local r, g, b = GetSuiteAccentColor()
        if self.leftBar then self.leftBar:SetColorTexture(r, g, b, 1.0) end
        if self.botLine then self.botLine:SetColorTexture(r, g, b, 0.35) end
        if self.title then self.title:SetTextColor(r, g, b, 1.0) end
        if self.subtitle then self.subtitle:SetTextColor(0.64, 0.70, 0.78, 1.0) end
    end

    return hdr
end
DynamicFPS.CreateSectionHeader = CreateSectionHeader

local function CreateCardRow(parent, yTop, rowHeight, titleText, descText, isRecessedSubDrawer)
    local h = rowHeight or (isRecessedSubDrawer and 50 or 56)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    local padX = parent.innerPadX or 0
    local leftInset = isRecessedSubDrawer and 10 or padX
    local rightInset = isRecessedSubDrawer and 10 or padX
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", leftInset, yTop)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rightInset, yTop)
    row:SetHeight(h)

    local ar, ag, ab = GetSuiteAccentColor()
    if isRecessedSubDrawer then
        row.bg = CreateSolidTex(row, "BACKGROUND", 2, PALETTE.VOID.r, PALETTE.VOID.g, PALETTE.VOID.b, 0.99)
        row.bg:SetAllPoints()
        Create1PxBorder(row, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 0.95)
        row.accentLeft = CreateSolidTex(row, "OVERLAY", 3, ar, ag, ab, 0.95)
        row.accentLeft:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
        row.accentLeft:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
        row.accentLeft:SetWidth(2)
    else
        row.bg = CreateSolidTex(row, "BACKGROUND", 1, PALETTE.SURFACE_CARD.r, PALETTE.SURFACE_CARD.g, PALETTE.SURFACE_CARD.b, 0.96)
        row.bg:SetAllPoints()
        Create1PxBorder(row, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 0.95)
    end

    local leftPad = isRecessedSubDrawer and 22 or 14
    local title = row:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", row, "TOPLEFT", leftPad, -8)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    if isRecessedSubDrawer then
        SetStyledFont(title, 11, "", PALETTE.TEXT_PRI.r, PALETTE.TEXT_PRI.g, PALETTE.TEXT_PRI.b, 1.0)
        title:SetText(titleText or "")
        row.accentPip = CreateSolidTex(row, "OVERLAY", 4, ar, ag, ab, 0.95)
        row.accentPip:SetSize(5, 5)
        row.accentPip:SetPoint("RIGHT", title, "LEFT", -6, 0)
    else
        SetStyledFont(title, 11, "", PALETTE.TEXT_PRI.r, PALETTE.TEXT_PRI.g, PALETTE.TEXT_PRI.b, 1.0)
        title:SetText(titleText or "")
    end
    row.title = title

    local desc = row:CreateFontString(nil, "OVERLAY")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    desc:SetPoint("RIGHT", row, "RIGHT", -265, 0)
    desc:SetJustifyH("LEFT")
    desc:SetJustifyV("TOP")
    desc:SetWordWrap(true)
    if desc.SetNonSpaceWrap then desc:SetNonSpaceWrap(false) end
    if desc.SetMaxLines then desc:SetMaxLines(2) end
    SetStyledFont(desc, 10.5, "", PALETTE.TEXT_SEC.r, PALETTE.TEXT_SEC.g, PALETTE.TEXT_SEC.b, 0.90)
    desc:SetText(descText or "")
    row.desc = desc

    function row:ClampDescToControl(ctrl)
        if not ctrl then return end
        desc:ClearAllPoints()
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
        desc:SetPoint("RIGHT", ctrl, "LEFT", -16, 0)
    end

    return row
end

-- ============================================================================
-- 9. EMBEDDED WORKSPACE (RenderFPSEmbedded) - OVERNIGHT MASTER BUILD PASS
-- ============================================================================
local standaloneWindow = nil

local function BuildZonePageView(scrollChild, RegisterRefresh, GetSelectedZoneKey, GetSelectedZoneTable, MarkZonePresetCustom, setPresetHighlightFn)
    local zonePage = CreateFrame("Frame", nil, scrollChild)
    zonePage:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
    zonePage:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, 0)
    zonePage:SetHeight(1038)

    local zoneTitleLbl
    local RefreshStarterPresetHighlight
    do
        -- 1. Unified 66px Zone Profile & 1-Click Copy Toolbar Card (2 Rows separated by 1px divider)
        local zoneToolbar = CreateFrame("Frame", nil, zonePage)
        zoneToolbar:SetPoint("TOPLEFT", zonePage, "TOPLEFT", 0, 0)
        zoneToolbar:SetPoint("TOPRIGHT", zonePage, "TOPRIGHT", 0, 0)
        zoneToolbar:SetHeight(66)
        zoneToolbar.bg = CreateSolidTex(zoneToolbar, "BACKGROUND", 1, PALETTE.SURFACE_BASE.r, PALETTE.SURFACE_BASE.g, PALETTE.SURFACE_BASE.b, 0.96)
        zoneToolbar.bg:SetAllPoints()
        Create1PxBorder(zoneToolbar, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 0.95)

        -- 1px horizontal divider separating Row 1 and Row 2
        local toolbarDivider = CreateSolidTex(zoneToolbar, "ARTWORK", 2, 1, 1, 1, 0.06)
        toolbarDivider:SetHeight(1)
        toolbarDivider:SetPoint("TOPLEFT", zoneToolbar, "TOPLEFT", 1, -33)
        toolbarDivider:SetPoint("TOPRIGHT", zoneToolbar, "TOPRIGHT", -1, -33)

        -- Row 1 (Top half: Zone Status & Hardware Presets)
        zoneTitleLbl = zoneToolbar:CreateFontString(nil, "OVERLAY")
        zoneTitleLbl:SetPoint("TOPLEFT", zoneToolbar, "TOPLEFT", 12, -11)
        SetStyledFont(zoneTitleLbl, 11.5, "", PALETTE.TEXT_PRI.r, PALETTE.TEXT_PRI.g, PALETTE.TEXT_PRI.b, 1.0)

        local presetButtons = {}
        local PRESET_BTN_ORDER = {
            { key = "LOW",         label = "Low-End PC",      width = 80 },
            { key = "BALANCED",    label = "Balanced",        width = 70 },
            { key = "COMPETITIVE", label = "Competitive FPS", width = 104 },
            { key = "ULTRA",       label = "High-End Ultra",  width = 94 },
        }

        local btnRestoreBase = CreateFrame("Button", nil, zoneToolbar)
        btnRestoreBase:SetSize(98, 24)
        btnRestoreBase:SetPoint("TOPRIGHT", zoneToolbar, "TOPRIGHT", -8, -5)
        btnRestoreBase.bg = CreateSolidTex(btnRestoreBase, "BACKGROUND", 1, PALETTE.CELL_NEUTRAL.r, PALETTE.CELL_NEUTRAL.g, PALETTE.CELL_NEUTRAL.b, 1.0)
        btnRestoreBase.bg:SetAllPoints()
        Create1PxBorder(btnRestoreBase, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)
        btnRestoreBase.lbl = btnRestoreBase:CreateFontString(nil, "OVERLAY")
        btnRestoreBase.lbl:SetPoint("CENTER", btnRestoreBase, "CENTER", 0, 0)
        btnRestoreBase.lbl:SetWordWrap(false)
        SetStyledFont(btnRestoreBase.lbl, 10.5, "", PALETTE.TEXT_SEC.r, PALETTE.TEXT_SEC.g, PALETTE.TEXT_SEC.b, 0.95)
        btnRestoreBase.lbl:SetText("Revert to Base")
        btnRestoreBase.presetKey = "SAVED_BASE"
        btnRestoreBase:SetScript("OnEnter", function(self)
            local ar, ag, ab = GetSuiteAccentColor()
            self:SetBorderColor(ar, ag, ab, 0.95)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine("Revert to Your Saved Base Graphics", 1.0, 1.0, 1.0)
                GameTooltip:AddLine("Restores this zone to the personal WoW System Graphics settings you had configured before DynamicFPS applied a zone override.", 0.78, 0.84, 0.92, true)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Restore saved pre-addon baseline graphics.|r", 0.886, 0.910, 0.941)
                GameTooltip:Show()
            end
        end)
        btnRestoreBase:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
            if RefreshStarterPresetHighlight then RefreshStarterPresetHighlight() end
        end)
        btnRestoreBase:SetScript("OnClick", function()
            CloseActiveDropdownMenu()
            RestoreBaselineGraphics(GetSelectedZoneKey())
        end)
        presetButtons["SAVED_BASE"] = btnRestoreBase

        local prevAnchor = btnRestoreBase
        for i = #PRESET_BTN_ORDER, 1, -1 do
            local pInfo = PRESET_BTN_ORDER[i]
            local b = CreateFrame("Button", nil, zoneToolbar)
            b:SetSize(pInfo.width, 24)
            b:SetPoint("RIGHT", prevAnchor, "LEFT", -4, 0)
            b.bg = CreateSolidTex(b, "BACKGROUND", 1, PALETTE.CELL_NEUTRAL.r, PALETTE.CELL_NEUTRAL.g, PALETTE.CELL_NEUTRAL.b, 1.0)
            b.bg:SetAllPoints()
            Create1PxBorder(b, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)

            b.lbl = b:CreateFontString(nil, "OVERLAY")
            b.lbl:SetPoint("CENTER", b, "CENTER", 0, 0)
            b.lbl:SetWordWrap(false)
            SetStyledFont(b.lbl, 10.5, "", PALETTE.TEXT_SEC.r, PALETTE.TEXT_SEC.g, PALETTE.TEXT_SEC.b, 0.92)
            b.lbl:SetText(pInfo.label)
            b.presetKey = pInfo.key

            b:SetScript("OnEnter", function(self)
                local ar, ag, ab = GetSuiteAccentColor()
                self:SetBorderColor(ar, ag, ab, 0.95)
            end)
            b:SetScript("OnLeave", function()
                if RefreshStarterPresetHighlight then RefreshStarterPresetHighlight() end
            end)
            b:SetScript("OnClick", function()
                CloseActiveDropdownMenu()
                ApplyStarterPresetToZone(GetSelectedZoneKey(), pInfo.key)
            end)

            presetButtons[pInfo.key] = b
            prevAnchor = b
        end

        zoneTitleLbl:ClearAllPoints()
        zoneTitleLbl:SetPoint("LEFT", zoneToolbar, "TOPLEFT", 12, -17)
        zoneTitleLbl:SetPoint("RIGHT", prevAnchor, "LEFT", -10, 0)
        zoneTitleLbl:SetJustifyH("LEFT")
        zoneTitleLbl:SetWordWrap(false)

        -- Row 2 (Bottom half: 1-Click Direct Zone Copy Pills & 2-Tap Apply to All)
        local copyHintLbl = zoneToolbar:CreateFontString(nil, "OVERLAY")
        copyHintLbl:SetPoint("LEFT", zoneToolbar, "BOTTOMLEFT", 12, 17)
        copyHintLbl:SetJustifyH("LEFT")
        copyHintLbl:SetWordWrap(false)
        SetStyledFont(copyHintLbl, 10.5, "", PALETTE.TEXT_SEC.r, PALETTE.TEXT_SEC.g, PALETTE.TEXT_SEC.b, 0.95)

        local confirmApplyAllZoneKey = nil
        local confirmApplyAllToken = 0

        local btnApplyAllZones = CreateFrame("Button", nil, zoneToolbar)
        btnApplyAllZones:SetSize(148, 22)
        btnApplyAllZones:SetPoint("BOTTOMRIGHT", zoneToolbar, "BOTTOMRIGHT", -8, 6)
        btnApplyAllZones.bg = CreateSolidTex(btnApplyAllZones, "BACKGROUND", 1, PALETTE.CELL_NEUTRAL.r, PALETTE.CELL_NEUTRAL.g, PALETTE.CELL_NEUTRAL.b, 1.0)
        btnApplyAllZones.bg:SetAllPoints()
        Create1PxBorder(btnApplyAllZones, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)
        btnApplyAllZones.lbl = btnApplyAllZones:CreateFontString(nil, "OVERLAY")
        btnApplyAllZones.lbl:SetPoint("CENTER", btnApplyAllZones, "CENTER", 0, 0)
        btnApplyAllZones.lbl:SetWordWrap(false)
        SetStyledFont(btnApplyAllZones.lbl, 10.5, "", PALETTE.TEXT_PRI.r, PALETTE.TEXT_PRI.g, PALETTE.TEXT_PRI.b, 0.95)

        local function UpdateApplyAllButtonVisual(isHover)
            local _, zKey = GetSelectedZoneTable()
            local zName = ZONE_NAMES[zKey] or zKey
            if confirmApplyAllZoneKey and confirmApplyAllZoneKey ~= zKey then
                confirmApplyAllZoneKey = nil
            end
            if confirmApplyAllZoneKey == zKey then
                btnApplyAllZones.bg:SetColorTexture(0.28, 0.08, 0.10, 0.96)
                btnApplyAllZones:SetBorderColor(1.0, 0.27, 0.27, 0.95)
                btnApplyAllZones.lbl:SetText("|cFFFF4444Click to Confirm All|r")
            else
                btnApplyAllZones.bg:SetColorTexture(PALETTE.CELL_NEUTRAL.r, PALETTE.CELL_NEUTRAL.g, PALETTE.CELL_NEUTRAL.b, 1.0)
                if isHover then
                    local ar, ag, ab = GetSuiteAccentColor()
                    btnApplyAllZones:SetBorderColor(ar, ag, ab, 0.95)
                else
                    btnApplyAllZones:SetBorderColor(PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)
                end
                btnApplyAllZones.lbl:SetText(string.format("Apply %s to All", zName))
            end
        end

        btnApplyAllZones:SetScript("OnEnter", function(self)
            UpdateApplyAllButtonVisual(true)
            if GameTooltip then
                local _, zKey = GetSelectedZoneTable()
                local zName = ZONE_NAMES[zKey] or zKey
                local ar, ag, ab = GetSuiteAccentColor()
                local accentHex = string.format("%02X%02X%02X", math.floor(ar * 255 + 0.5), math.floor(ag * 255 + 0.5), math.floor(ab * 255 + 0.5))
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(string.format("Apply %s to All Zones", zName), 1.0, 1.0, 1.0)
                GameTooltip:AddLine("Copies this zone's exact graphics settings across Outdoor, Cities, Delves, Dungeons, Raid, and PvP.", 0.78, 0.84, 0.92, true)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(string.format("|cFF34D399Left-Click:|r |cFFE2E8F0Copy|r |cFF%s%s|r |cFFE2E8F0graphics settings to all 6 zone profiles.|r", accentHex, zName), 0.886, 0.910, 0.941)
                GameTooltip:Show()
            end
        end)
        btnApplyAllZones:SetScript("OnLeave", function()
            UpdateApplyAllButtonVisual(false)
            if GameTooltip then GameTooltip:Hide() end
        end)
        btnApplyAllZones:SetScript("OnClick", function(self)
            CloseActiveDropdownMenu()
            local _, zKey = GetSelectedZoneTable()
            if confirmApplyAllZoneKey == zKey then
                confirmApplyAllZoneKey = nil
                confirmApplyAllToken = confirmApplyAllToken + 1
                ApplyZoneToAllZones(zKey)
                UpdateApplyAllButtonVisual(self:IsMouseOver())
            else
                confirmApplyAllZoneKey = zKey
                confirmApplyAllToken = confirmApplyAllToken + 1
                local myToken = confirmApplyAllToken
                UpdateApplyAllButtonVisual(self:IsMouseOver())
                if C_Timer and C_Timer.After then
                    C_Timer.After(3.0, function()
                        if confirmApplyAllToken == myToken then
                            confirmApplyAllZoneKey = nil
                            UpdateApplyAllButtonVisual(btnApplyAllZones:IsMouseOver())
                        end
                    end)
                end
            end
        end)

        -- 5 Source Zone 1-Click Copy Pills
        local sourceZonePills = {}
        local flashedSourceKey = nil
        local flashedSourceToken = 0

        for i = 1, 5 do
            local pill = CreateFrame("Button", nil, zoneToolbar)
            pill:SetSize(74, 22)
            pill.bg = CreateSolidTex(pill, "BACKGROUND", 1, PALETTE.CELL_NEUTRAL.r, PALETTE.CELL_NEUTRAL.g, PALETTE.CELL_NEUTRAL.b, 1.0)
            pill.bg:SetAllPoints()
            Create1PxBorder(pill, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)

            pill.lbl = pill:CreateFontString(nil, "OVERLAY")
            pill.lbl:SetPoint("CENTER", pill, "CENTER", 0, 0)
            pill.lbl:SetWordWrap(false)
            SetStyledFont(pill.lbl, 10.5, "", PALETTE.TEXT_SEC.r, PALETTE.TEXT_SEC.g, PALETTE.TEXT_SEC.b, 0.94)

            pill:SetScript("OnEnter", function(self)
                if flashedSourceKey ~= self.srcZoneKey then
                    local ar, ag, ab = GetSuiteAccentColor()
                    self:SetBorderColor(ar, ag, ab, 0.95)
                end
                if GameTooltip and self.srcZoneKey then
                    local srcName = ZONE_NAMES[self.srcZoneKey] or self.srcZoneKey
                    local _, dstKey = GetSelectedZoneTable()
                    local dstName = ZONE_NAMES[dstKey] or dstKey
                    local ar, ag, ab = GetSuiteAccentColor()
                    local accentHex = string.format("%02X%02X%02X", math.floor(ar * 255 + 0.5), math.floor(ag * 255 + 0.5), math.floor(ab * 255 + 0.5))
                    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
                    GameTooltip:ClearLines()
                    GameTooltip:AddLine(string.format("Copy From %s", srcName), 1.0, 1.0, 1.0)
                    GameTooltip:AddLine(string.format("|cFF34D399Left-Click:|r |cFFE2E8F0Copy all graphics settings from|r |cFF%s%s|r |cFFE2E8F0into|r |cFFFFFFFF%s|r", accentHex, srcName, dstName), 0.886, 0.910, 0.941)
                    GameTooltip:Show()
                end
            end)
            pill:SetScript("OnLeave", function(self)
                if flashedSourceKey ~= self.srcZoneKey then
                    self:SetBorderColor(PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)
                end
                if GameTooltip then GameTooltip:Hide() end
            end)
            pill:SetScript("OnClick", function(self)
                CloseActiveDropdownMenu()
                if not self.srcZoneKey then return end
                local srcKey = self.srcZoneKey
                local _, dstKey = GetSelectedZoneTable()
                flashedSourceKey = srcKey
                flashedSourceToken = flashedSourceToken + 1
                local myFlash = flashedSourceToken
                CopyZoneSettings(srcKey, dstKey)
                if C_Timer and C_Timer.After then
                    C_Timer.After(1.4, function()
                        if flashedSourceToken == myFlash then
                            flashedSourceKey = nil
                            if RefreshStarterPresetHighlight then RefreshStarterPresetHighlight() end
                        end
                    end)
                end
            end)

            sourceZonePills[i] = pill
        end

        RefreshStarterPresetHighlight = function()
            local zTbl, zKey = GetSelectedZoneTable()
            local zName = ZONE_NAMES[zKey] or zKey
            local activePresetKey = DetectMatchingPresetKey(zTbl, zKey, DynamicFPSDB.activePresets and DynamicFPSDB.activePresets[zKey])
            DynamicFPSDB.activePresets[zKey] = activePresetKey
            local curAr, curAg, curAb = GetSuiteAccentColor()
            local fillAlpha = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42

            for pKey, btn in pairs(presetButtons) do
                if pKey == activePresetKey then
                    btn.bg:SetColorTexture(curAr * fillAlpha, curAg * fillAlpha, curAb * fillAlpha, 1.0)
                    btn:SetBorderColor(curAr, curAg, curAb, 0.95)
                    SetStyledFont(btn.lbl, 10.5, "", PALETTE.TEXT_PRI.r, PALETTE.TEXT_PRI.g, PALETTE.TEXT_PRI.b, 1.0)
                else
                    btn.bg:SetColorTexture(PALETTE.CELL_NEUTRAL.r, PALETTE.CELL_NEUTRAL.g, PALETTE.CELL_NEUTRAL.b, 1.0)
                    btn:SetBorderColor(PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)
                    SetStyledFont(btn.lbl, 10.5, "", PALETTE.TEXT_SEC.r, PALETTE.TEXT_SEC.g, PALETTE.TEXT_SEC.b, 0.90)
                end
            end

            copyHintLbl:SetText(string.format("Copy Into |cFFFFFFFF%s|r From:", zName))
            local hintW = (copyHintLbl.GetUnboundedStringWidth and copyHintLbl:GetUnboundedStringWidth()) or copyHintLbl:GetStringWidth() or 140
            local xCursor = 12 + math.max(134, math.ceil(hintW + 10))

            local pillIdx = 0
            for _, tInfo in ipairs(LEFT_ZONE_TABS) do
                if tInfo.id ~= zKey then
                    pillIdx = pillIdx + 1
                    local pill = sourceZonePills[pillIdx]
                    if pill then
                        pill.srcZoneKey = tInfo.id
                        local isFlashed = (flashedSourceKey == tInfo.id)
                        local labelText = isFlashed and string.format("|cFF34D399Copied %s!|r", tInfo.label) or tInfo.label
                        pill.lbl:SetText(labelText)
                        local rawW = (pill.lbl.GetUnboundedStringWidth and pill.lbl:GetUnboundedStringWidth()) or pill.lbl:GetStringWidth() or 48
                        local pillW = math.max(58, math.ceil(rawW + 18))
                        pill:SetSize(pillW, 22)
                        pill:ClearAllPoints()
                        pill:SetPoint("BOTTOMLEFT", zoneToolbar, "BOTTOMLEFT", xCursor, 6)
                        xCursor = xCursor + pillW + 4

                        if isFlashed then
                            pill.bg:SetColorTexture(0.06, 0.32, 0.22, 0.96)
                            pill:SetBorderColor(0.20, 0.83, 0.60, 0.98)
                            SetStyledFont(pill.lbl, 10.5, "", 0.20, 0.83, 0.60, 1.0)
                        else
                            pill.bg:SetColorTexture(PALETTE.CELL_NEUTRAL.r, PALETTE.CELL_NEUTRAL.g, PALETTE.CELL_NEUTRAL.b, 1.0)
                            pill:SetBorderColor(PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)
                            SetStyledFont(pill.lbl, 10.5, "", PALETTE.TEXT_SEC.r, PALETTE.TEXT_SEC.g, PALETTE.TEXT_SEC.b, 0.94)
                        end
                        pill:Show()
                    end
                end
            end

            UpdateApplyAllButtonVisual(btnApplyAllZones:IsMouseOver())
        end
        if setPresetHighlightFn then
            setPresetHighlightFn(RefreshStarterPresetHighlight)
        end
    end

    -- 2. Section 1 - CORE SHADER, SHADOW & SPELL QUALITY (Mirrors Blizzard's Base Game Quality Menu 1:1)
    local zSec1 = CreateSectionBox(zonePage, -76, 616)
    local zHdr1 = CreateSectionHeader(zSec1, -10, "CORE SHADER, SHADOW & SPELL QUALITY", "Mirrors WoW's in-game graphics menu. Lowering SSAO, Depth, and Compute Effects saves GPU power with zero gameplay loss.")

    local pillsShadow, pillsLiquid, pillsParticle, pillsSSAO, pillsDepth, pillsCompute, pillsOutline, pillsTexRes, pillsSpellDensity
    do
        local z1r1 = CreateCardRow(zSec1, -54, 56, "Shadow Quality", "Controls dynamic shadow map resolution. 'Low' or 'Fair' saves 15-25% CPU/GPU time in raids with zero gameplay loss.")
        pillsShadow = CreateSegmentedPills(z1r1, 248, SHADOW_PILL_OPTIONS, function()
            local z = GetSelectedZoneTable()
            return math.max(0, math.min(4, _SafeNum(z.shadowQuality, 1)))
        end, function(val)
            local z, zKey = GetSelectedZoneTable()
            z.shadowQuality = val
            MarkZonePresetCustom(zKey)
        end)
        pillsShadow:SetPoint("RIGHT", z1r1, "RIGHT", -14, 0)
        z1r1:ClampDescToControl(pillsShadow)

        local z1r2 = CreateCardRow(zSec1, -116, 56, "Liquid Detail", "Controls water reflections and ripples. 'Low' or 'Fair' prevents heavy FPS drops in water boss rooms.")
        pillsLiquid = CreateSegmentedPills(z1r2, 248, LIQUID_PILL_OPTIONS, function()
            local z = GetSelectedZoneTable()
            return math.max(0, math.min(3, _SafeNum(z.liquidDetail, 1)))
        end, function(val)
            local z, zKey = GetSelectedZoneTable()
            z.liquidDetail = val
            MarkZonePresetCustom(zKey)
        end)
        pillsLiquid:SetPoint("RIGHT", z1r2, "RIGHT", -14, 0)
        z1r2:ClampDescToControl(pillsLiquid)

        local z1r3 = CreateCardRow(zSec1, -178, 56, "Particle Density", "Controls weather, fire, and spell particles. Keep at 'Fair' or 'Good' so boss ground swirlies remain clear.")
        pillsParticle = CreateSegmentedPills(z1r3, 248, PARTICLE_PILL_OPTIONS, function()
            local z = GetSelectedZoneTable()
            return math.max(1, math.min(5, _SafeNum(z.particleDensity, 3)))
        end, function(val)
            local z, zKey = GetSelectedZoneTable()
            z.particleDensity = val
            MarkZonePresetCustom(zKey)
        end)
        pillsParticle:SetPoint("RIGHT", z1r3, "RIGHT", -14, 0)
        z1r3:ClampDescToControl(pillsParticle)

        local z1r4 = CreateCardRow(zSec1, -240, 56, "SSAO", "Cosmetic wall/corner shading with ZERO gameplay impact. Set to 'Disabled' or 'Low' in instances for free GPU FPS.")
        pillsSSAO = CreateSegmentedPills(z1r4, 248, SSAO_PILL_OPTIONS, function()
            local z = GetSelectedZoneTable()
            return math.max(0, math.min(4, _SafeNum(z.ssao, 1)))
        end, function(val)
            local z, zKey = GetSelectedZoneTable()
            z.ssao = val
            MarkZonePresetCustom(zKey)
        end)
        pillsSSAO:SetPoint("RIGHT", z1r4, "RIGHT", -14, 0)
        z1r4:ClampDescToControl(pillsSSAO)

        local z1r5 = CreateCardRow(zSec1, -302, 56, "Depth Effects", "Cosmetic depth-of-field blur with ZERO gameplay impact. 'Disabled' or 'Low' frees GPU resources and keeps visuals sharp.")
        pillsDepth = CreateSegmentedPills(z1r5, 248, DEPTH_PILL_OPTIONS, function()
            local z = GetSelectedZoneTable()
            return math.max(0, math.min(3, _SafeNum(z.depthEffects, 0)))
        end, function(val)
            local z, zKey = GetSelectedZoneTable()
            z.depthEffects = val
            MarkZonePresetCustom(zKey)
        end)
        pillsDepth:SetPoint("RIGHT", z1r5, "RIGHT", -14, 0)
        z1r5:ClampDescToControl(pillsDepth)

        local z1r6 = CreateCardRow(zSec1, -364, 56, "Compute Effects", "Volumetric fog and lighting rays with ZERO gameplay impact. 'Disabled' or 'Low' prevents heavy GPU lag in foggy rooms.")
        pillsCompute = CreateSegmentedPills(z1r6, 248, COMPUTE_PILL_OPTIONS, function()
            local z = GetSelectedZoneTable()
            return math.max(0, math.min(4, _SafeNum(z.computeEffects, 0)))
        end, function(val)
            local z, zKey = GetSelectedZoneTable()
            z.computeEffects = val
            MarkZonePresetCustom(zKey)
        end)
        pillsCompute:SetPoint("RIGHT", z1r6, "RIGHT", -14, 0)
        z1r6:ClampDescToControl(pillsCompute)

        local z1r7 = CreateCardRow(zSec1, -426, 56, "Outline Mode", "Highlights quest objects and dungeon interactables. Keep on 'Good' or 'High' for gameplay visibility.")
        pillsOutline = CreateSegmentedPills(z1r7, 248, OUTLINE_PILL_OPTIONS, function()
            local z = GetSelectedZoneTable()
            return math.max(0, math.min(2, _SafeNum(z.outlineMode, 2)))
        end, function(val)
            local z, zKey = GetSelectedZoneTable()
            z.outlineMode = val
            MarkZonePresetCustom(zKey)
        end)
        pillsOutline:SetPoint("RIGHT", z1r7, "RIGHT", -14, 0)
        z1r7:ClampDescToControl(pillsOutline)

        local z1r8 = CreateCardRow(zSec1, -488, 56, "Texture Resolution", "Controls surface texture sharpness. Uses VRAM only - 'High' has near-zero FPS cost on modern GPUs.")
        pillsTexRes = CreateSegmentedPills(z1r8, 248, TEXTURE_RES_PILL_OPTIONS, function()
            local z = GetSelectedZoneTable()
            return math.max(0, math.min(2, _SafeNum(z.textureResolution, 2)))
        end, function(val)
            local z, zKey = GetSelectedZoneTable()
            z.textureResolution = val
            MarkZonePresetCustom(zKey)
        end)
        pillsTexRes:SetPoint("RIGHT", z1r8, "RIGHT", -14, 0)
        z1r8:ClampDescToControl(pillsTexRes)

        local z1r9 = CreateCardRow(zSec1, -550, 56, "Spell Density", "Controls visibility of non-essential allied spells. Your own spells and boss mechanics are always shown.")
        pillsSpellDensity = CreateSegmentedPills(z1r9, 248, SPELL_DENSITY_PILL_OPTIONS, function()
            local z = GetSelectedZoneTable()
            return NormalizeSpellDensityToken(z.spellDensity)
        end, function(val)
            local z, zKey = GetSelectedZoneTable()
            z.spellDensity = NormalizeSpellDensityToken(val)
            MarkZonePresetCustom(zKey)
        end, function(pillBtn)
            if not GameTooltip then return end
            local _, zKey = GetSelectedZoneTable()
            local recText = (zKey == "RAID") and "Essential" or "Reduced"
            GameTooltip:SetOwner(pillBtn, "ANCHOR_BOTTOMRIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Spell Density", 1.0, 1.0, 1.0)
            GameTooltip:AddLine("Controls visibility of non-essential spells. Your own spells and boss mechanics are always shown.", 0.78, 0.84, 0.92, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cFFFFD100Essential:|r |cFFE2E8F0Only show essential spells. (Best Raid/M+ FPS)|r", 0.886, 0.910, 0.941, true)
            GameTooltip:AddLine("|cFFFFD100Reduced:|r |cFFE2E8F0Reduces non-essential allied spells shown. (Blizzard Recommended)|r", 0.886, 0.910, 0.941, true)
            GameTooltip:AddLine("|cFFFFD100Everything:|r |cFFE2E8F0Always show all player and allied spells.|r", 0.886, 0.910, 0.941, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(string.format("|cFF34D399Recommended:|r |cFFFFFFFF%s|r", recText), 0.886, 0.910, 0.941)
            GameTooltip:Show()
        end)
        pillsSpellDensity:SetPoint("RIGHT", z1r9, "RIGHT", -14, 0)
        z1r9:ClampDescToControl(pillsSpellDensity)
    end

    -- 3. Section 2 - VIEW DISTANCE & ENVIRONMENT CLUTTER (CPU SLIDERS 1-10)
    local zSec2 = CreateSectionBox(zonePage, -704, 320)
    local zHdr2 = CreateSectionHeader(zSec2, -10, "VIEW DISTANCE & ENVIRONMENT CLUTTER (CPU SLIDERS 1-10)", "The #1 CPU bottleneck in Capital Cities and Raids. Lowering these sliders in Cities/Raids boosts CPU-bound FPS by up to 35%.")

    local slViewDist, slEnvDetail, slGroundClutter, swFriendlyNP, swSilhouette
    do
        local z2r1 = CreateCardRow(zSec2, -54, 50, "View Distance", "Controls how far terrain and buildings render in the distance (1 = Short, 10 = Far).")
        slViewDist = CreateInlineSliderControl(z2r1, 248, 1, 10, 1, function()
            local z = GetSelectedZoneTable()
            return math.max(1, math.min(10, _SafeNum(z.viewDistance, 5)))
        end, function(val)
            local z, zKey = GetSelectedZoneTable()
            z.viewDistance = val
            MarkZonePresetCustom(zKey)
        end, function(v)
            return string.format("%d / 10", v)
        end)
        slViewDist:SetPoint("RIGHT", z2r1, "RIGHT", -14, 0)
        z2r1:ClampDescToControl(slViewDist)

        local z2r2 = CreateCardRow(zSec2, -110, 50, "Environment Detail", "Controls distance and detail of decorative world structures and props.")
        slEnvDetail = CreateInlineSliderControl(z2r2, 248, 1, 10, 1, function()
            local z = GetSelectedZoneTable()
            return math.max(1, math.min(10, _SafeNum(z.environmentDetail, _SafeNum(z.viewDistance, 5))))
        end, function(val)
            local z, zKey = GetSelectedZoneTable()
            z.environmentDetail = val
            MarkZonePresetCustom(zKey)
        end, function(v)
            return string.format("%d / 10", v)
        end)
        slEnvDetail:SetPoint("RIGHT", z2r2, "RIGHT", -14, 0)
        z2r2:ClampDescToControl(slEnvDetail)

        local z2r3 = CreateCardRow(zSec2, -166, 50, "Ground Clutter", "Controls grass, foliage, and ground debris density. Lower in Dungeons/Raids for clearer ground swirlies.")
        slGroundClutter = CreateInlineSliderControl(z2r3, 248, 1, 10, 1, function()
            local z = GetSelectedZoneTable()
            return math.max(1, math.min(10, _SafeNum(z.groundClutter, 3)))
        end, function(val)
            local z, zKey = GetSelectedZoneTable()
            z.groundClutter = val
            MarkZonePresetCustom(zKey)
        end, function(v)
            return string.format("%d / 10", v)
        end)
        slGroundClutter:SetPoint("RIGHT", z2r3, "RIGHT", -14, 0)
        z2r3:ClampDescToControl(slGroundClutter)

        local z2r4 = CreateCardRow(zSec2, -222, 46, "Friendly Player Nameplates in PvE", "Disables allied player nameplates inside PvE instances to eliminate raid frame stutter.")
        swFriendlyNP = CreateBinarySegmentedSwitch(z2r4, function()
            local z = GetSelectedZoneTable()
            return z.friendlyNameplatesPvE and true or false
        end, function(val)
            local z, zKey = GetSelectedZoneTable()
            z.friendlyNameplatesPvE = val
            MarkZonePresetCustom(zKey)
        end, "Off", "Enabled")
        swFriendlyNP:SetPoint("RIGHT", z2r4, "RIGHT", -14, 0)
        z2r4:ClampDescToControl(swFriendlyNP)

        local z2r5 = CreateCardRow(zSec2, -268, 46, "Character Outline When Blocked", "Highlights your character outline when blocked by walls or models while locking Boss Ground Swirlies ON.")
        swSilhouette = CreateBinarySegmentedSwitch(z2r5, function()
            local z = GetSelectedZoneTable()
            return (z.targetSilhouette ~= false)
        end, function(val)
            local z, zKey = GetSelectedZoneTable()
            z.targetSilhouette = val
            z.projectedTexturesLocked = true
            EnforceProjectedTexturesLock()
            MarkZonePresetCustom(zKey)
        end, "Off", "Enabled")
        swSilhouette:SetPoint("RIGHT", z2r5, "RIGHT", -14, 0)
        z2r5:ClampDescToControl(swSilhouette)
    end

    zonePage:SetHeight(1038)

    RegisterRefresh(function()
        local _, zKey = GetSelectedZoneTable()
        local zName = ZONE_NAMES[zKey] or zKey
        local activeCtx = GetCurrentZoneContext()
        local activeCtxName = ZONE_NAMES[activeCtx] or activeCtx
        local ar, ag, ab = GetSuiteAccentColor()
        local accentHex = string.format("%02X%02X%02X", math.floor(ar * 255 + 0.5), math.floor(ag * 255 + 0.5), math.floor(ab * 255 + 0.5))

        if activeCtx == zKey then
            zoneTitleLbl:SetText(string.format("Editing Profile: |cFF%s%s|r  |cFF34D399(Active Now)|r", accentHex, zName))
        else
            zoneTitleLbl:SetText(string.format("Editing Profile: |cFF%s%s|r  |cFF94A3B8(Live Zone: %s)|r", accentHex, zName, activeCtxName))
        end

        if zHdr1 then zHdr1:RefreshAccent() end
        if zHdr2 then zHdr2:RefreshAccent() end
        if RefreshStarterPresetHighlight then RefreshStarterPresetHighlight() end
        pillsShadow:RefreshValue()
        pillsLiquid:RefreshValue()
        pillsParticle:RefreshValue()
        pillsSSAO:RefreshValue()
        pillsDepth:RefreshValue()
        pillsCompute:RefreshValue()
        pillsOutline:RefreshValue()
        pillsTexRes:RefreshValue()
        pillsSpellDensity:RefreshValue()
        slViewDist:RefreshValue()
        slEnvDetail:RefreshValue()
        slGroundClutter:RefreshValue()
        swFriendlyNP:RefreshValue()
        swSilhouette:RefreshValue()
    end)

    return zonePage, zHdr1, zHdr2
end

local function RenderFPSEmbedded(parent)
    if not parent then return end
    EnsureDBInitialized()
    CloseActiveDropdownMenu()

    if standaloneWindow and standaloneWindow:IsShown() and parent ~= standaloneWindow.contentHost then
        standaloneWindow:Hide()
    end

    if parent.dfpsEmbeddedFrame then
        parent.dfpsEmbeddedFrame:Show()
        if DynamicFPS.RefreshWorkspaceUI then
            DynamicFPS.RefreshWorkspaceUI()
        end
        return parent.dfpsEmbeddedFrame
    end

    local root = CreateFrame("Frame", nil, parent)
    root:SetAllPoints(parent)
    parent.dfpsEmbeddedFrame = root

    local refreshCallbacks = {}
    local function RegisterRefresh(fn)
        table.insert(refreshCallbacks, fn)
    end

    local function GetSelectedZoneKey()
        local t = DynamicFPSDB.activeTab or "RAID"
        if t == "GUARD_QUEUE" then return "RAID" end
        return t
    end

    local function GetSelectedZoneTable()
        local zKey = GetSelectedZoneKey()
        DynamicFPSDB.zones[zKey] = DynamicFPSDB.zones[zKey] or DeepCopyTable(DEFAULT_DB.zones[zKey] or DEFAULT_DB.zones.RAID)
        return DynamicFPSDB.zones[zKey], zKey
    end

    -- Helper called when user manually modifies any row in a zone -> sets activePresets[zoneKey] = "CUSTOM" and applies immediately (Item #13)
    local RefreshStarterPresetHighlight = nil
    local function MarkZonePresetCustom(zKey)
        EnsureDBInitialized()
        DynamicFPSDB.activePresets[zKey] = "CUSTOM"
        if RefreshStarterPresetHighlight then
            RefreshStarterPresetHighlight()
        end
        if zKey == GetCurrentZoneContext() then
            ApplyZoneGraphicsConfig(zKey, true)
        elseif _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
            pcall(_G.DynamicSuite.RefreshHeaderStatus)
        end
    end

    -- ------------------------------------------------------------------------
    -- A. SPLIT TOP NAVIGATION BAR (Items #1 & #32 - 34px Bevel at 14 / -16):
    -- Left 6-Zone Track vs. Far-Right [ FPS Guard & Queue ] Pill (26px height)
    -- ------------------------------------------------------------------------
    local topNavRow = CreateFrame("Frame", nil, root)
    topNavRow:SetPoint("TOPLEFT", root, "TOPLEFT", 14, -10)
    topNavRow:SetPoint("TOPRIGHT", root, "TOPRIGHT", -16, -10)
    topNavRow:SetHeight(34)
    topNavRow.bg = CreateSolidTex(topNavRow, "BACKGROUND", 0, 0.043, 0.051, 0.071, 0.98)
    topNavRow.bg:SetAllPoints()
    Create1PxBorder(topNavRow, 1, 1, 1, 0.08)

    local tabButtons = {}
    local ar, ag, ab = GetSuiteAccentColor()

    -- Far-Right Standalone Utility Pill: [ FPS Guard & Queue ] (26px height at RIGHT -4, 0)
    local guardPillBtn = CreateFrame("Button", nil, topNavRow)
    guardPillBtn:SetSize(156, 26)
    guardPillBtn:SetPoint("RIGHT", topNavRow, "RIGHT", -4, 0)
    guardPillBtn.bg = CreateSolidTex(guardPillBtn, "BACKGROUND", 1, 0.078, 0.090, 0.122, 0.85)
    guardPillBtn.bg:SetAllPoints()
    Create1PxBorder(guardPillBtn, 1, 1, 1, 0.07)

    guardPillBtn.label = guardPillBtn:CreateFontString(nil, "OVERLAY")
    guardPillBtn.label:SetPoint("CENTER", guardPillBtn, "CENTER", 0, 0)
    guardPillBtn.label:SetWordWrap(false)
    SetStyledFont(guardPillBtn.label, 11, "", PALETTE.TEXT_PRI.r, PALETTE.TEXT_PRI.g, PALETTE.TEXT_PRI.b, 0.95)
    guardPillBtn.label:SetText("FPS Guard & Queue")
    tabButtons["GUARD_QUEUE"] = guardPillBtn

    -- Left 6-Zone Track Container (LEFT 4, 0 to guardPillBtn LEFT -4, 0)
    local leftZoneTrack = CreateFrame("Frame", nil, topNavRow)
    leftZoneTrack:SetHeight(26)
    leftZoneTrack:SetPoint("LEFT", topNavRow, "LEFT", 4, 0)
    leftZoneTrack:SetPoint("RIGHT", guardPillBtn, "LEFT", -4, 0)

    for _, tInfo in ipairs(LEFT_ZONE_TABS) do
        local btn = CreateFrame("Button", nil, leftZoneTrack)
        btn:SetHeight(26)
        btn.bg = CreateSolidTex(btn, "BACKGROUND", 1, 0.078, 0.090, 0.122, 0.85)
        btn.bg:SetAllPoints()
        Create1PxBorder(btn, 1, 1, 1, 0.07)

        btn.label = btn:CreateFontString(nil, "OVERLAY")
        btn.label:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.label:SetWordWrap(false)
        SetStyledFont(btn.label, 11, "", PALETTE.TEXT_SEC.r, PALETTE.TEXT_SEC.g, PALETTE.TEXT_SEC.b, 0.92)
        btn.label:SetText(tInfo.label)

        btn.activeDot = CreateSolidTex(btn, "OVERLAY", 5, 0.133, 0.773, 0.369, 1.0)
        btn.activeDot:SetSize(6, 6)
        btn.activeDot:SetPoint("LEFT", btn.label, "RIGHT", 5, 0)
        btn.activeDot:Hide()

        tabButtons[tInfo.id] = btn
    end

    local function LayoutLeftZoneTrack()
        local trackW = leftZoneTrack:GetWidth() or 540
        if trackW <= 0 then return end
        local gap = 4
        local count = #LEFT_ZONE_TABS
        local cellW = math.floor((trackW - ((count - 1) * gap)) / count)
        for idx, tInfo in ipairs(LEFT_ZONE_TABS) do
            local b = tabButtons[tInfo.id]
            if b then
                b:ClearAllPoints()
                b:SetHeight(26)
                if idx == count then
                    local prevB = tabButtons[LEFT_ZONE_TABS[idx - 1].id]
                    b:SetPoint("LEFT", prevB, "RIGHT", gap, 0)
                    b:SetPoint("RIGHT", leftZoneTrack, "RIGHT", 0, 0)
                else
                    b:SetPoint("LEFT", leftZoneTrack, "LEFT", (idx - 1) * (cellW + gap), 0)
                    b:SetWidth(cellW)
                end
            end
        end
    end
    leftZoneTrack:SetScript("OnSizeChanged", LayoutLeftZoneTrack)

    -- ------------------------------------------------------------------------
    -- B. SCROLLABLE WORKSPACE (14 / -16 Aligned 1:1 with topNavRow) + 4PX SLATE SCROLLBAR AT -6
    -- ------------------------------------------------------------------------
    local scrollContainer = CreateFrame("Frame", nil, root)
    scrollContainer:SetPoint("TOPLEFT", topNavRow, "BOTTOMLEFT", 0, -8)
    scrollContainer:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -16, 8)

    local scrollFrame = CreateFrame("ScrollFrame", nil, scrollContainer)
    scrollFrame:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", 0, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() > 50 and scrollFrame:GetWidth() or 720)
    scrollChild:SetHeight(640)
    scrollFrame:SetScrollChild(scrollChild)

    local scrollTrack = CreateFrame("Frame", nil, root)
    scrollTrack:SetPoint("TOP", scrollContainer, "TOP", 0, 0)
    scrollTrack:SetPoint("BOTTOM", scrollContainer, "BOTTOM", 0, 0)
    scrollTrack:SetPoint("RIGHT", root, "RIGHT", -6, 0)
    scrollTrack:SetWidth(4)
    scrollTrack.bg = CreateSolidTex(scrollTrack, "BACKGROUND", 1, PALETTE.SURFACE_BASE.r, PALETTE.SURFACE_BASE.g, PALETTE.SURFACE_BASE.b, 0.85)
    scrollTrack.bg:SetAllPoints()

    local scrollThumb = CreateFrame("Button", nil, scrollTrack)
    scrollThumb:SetWidth(4)
    scrollThumb:SetHeight(64)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb.tex = CreateSolidTex(scrollThumb, "OVERLAY", 2, 0.38, 0.45, 0.56, 0.85)
    scrollThumb.tex:SetAllPoints()

    local function UpdateScrollbarVisual()
        local viewH = scrollFrame:GetHeight() or 1
        local contentH = scrollChild:GetHeight() or 1
        local maxScroll = math.max(0, contentH - viewH)

        if maxScroll <= 2 then
            scrollTrack:Hide()
            if viewH > 40 then
                scrollFrame:SetVerticalScroll(0)
            end
            return
        end

        scrollTrack:Show()
        local trackH = scrollTrack:GetHeight() or viewH
        local thumbH = math.max(28, math.min(trackH, (viewH / contentH) * trackH))
        scrollThumb:SetHeight(thumbH)

        local rawScroll = scrollFrame:GetVerticalScroll() or 0
        local curScroll = math.max(0, math.min(maxScroll, rawScroll))
        if math.abs(curScroll - rawScroll) > 0.5 then
            scrollFrame:SetVerticalScroll(curScroll)
        end
        local ratio = curScroll / maxScroll
        local maxOffset = math.max(0, trackH - thumbH)
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -(ratio * maxOffset))
    end

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        CloseActiveDropdownMenu()
        local viewH = self:GetHeight() or 1
        local contentH = scrollChild:GetHeight() or 1
        local maxScroll = math.max(0, contentH - viewH)
        local cur = self:GetVerticalScroll() or 0
        local nextVal = math.max(0, math.min(maxScroll, cur - (delta * 36)))
        self:SetVerticalScroll(nextVal)
        UpdateScrollbarVisual()
    end)

    local isDraggingThumb = false
    local dragStartY = 0
    local dragStartScroll = 0

    local function OnScrollThumbDragUpdate(self)
        if not isDraggingThumb or not IsMouseButtonDown("LeftButton") then
            isDraggingThumb = false
            self:SetScript("OnUpdate", nil)
            return
        end
        local _, cursorY = GetCursorPosition()
        local scale = self:GetEffectiveScale() or 1
        local curY = cursorY / scale
        local deltaY = dragStartY - curY

        local viewH = scrollFrame:GetHeight() or 1
        local contentH = scrollChild:GetHeight() or 1
        local maxScroll = math.max(0, contentH - viewH)
        local trackH = scrollTrack:GetHeight() or viewH
        local thumbH = scrollThumb:GetHeight() or 40
        local travel = math.max(1, trackH - thumbH)

        local nextScroll = math.max(0, math.min(maxScroll, dragStartScroll + (deltaY / travel) * maxScroll))
        scrollFrame:SetVerticalScroll(nextScroll)
        UpdateScrollbarVisual()
    end

    scrollThumb:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        isDraggingThumb = true
        local _, cursorY = GetCursorPosition()
        local scale = self:GetEffectiveScale() or 1
        dragStartY = cursorY / scale
        dragStartScroll = scrollFrame:GetVerticalScroll() or 0
        self:SetScript("OnUpdate", OnScrollThumbDragUpdate)
    end)
    scrollThumb:SetScript("OnMouseUp", function(self)
        isDraggingThumb = false
        self:SetScript("OnUpdate", nil)
    end)
    scrollThumb:SetScript("OnHide", function(self)
        isDraggingThumb = false
        self:SetScript("OnUpdate", nil)
    end)

    scrollFrame:SetScript("OnSizeChanged", function(self, w)
        if w and w > 40 then
            scrollChild:SetWidth(w)
        end
        UpdateScrollbarVisual()
    end)

    -- ========================================================================
    -- PAGE A: 6 ZONE TABS VIEW (Outdoor, Cities, Delves, Dungeons, Raid, PvP)
    -- ========================================================================
    local zonePage, zHdr1, zHdr2 = BuildZonePageView(
        scrollChild,
        RegisterRefresh,
        GetSelectedZoneKey,
        GetSelectedZoneTable,
        MarkZonePresetCustom,
        function(fn) RefreshStarterPresetHighlight = fn end
    )

    -- ========================================================================
    -- PAGE B: FAR-RIGHT PILL VIEW - [ FPS Guard & Queue ] (Item #37 Sub-Drawers)
    -- ========================================================================
    local guardPage = CreateFrame("Frame", nil, scrollChild)
    guardPage:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
    guardPage:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, 0)
    guardPage:SetHeight(600)

    -- Section 1 - DYNAMIC FPS GUARD, SPELLQUEUE & ENGINE AUTOMATION (Individual Setting Cards)
    local gSec1 = CreateSectionBox(guardPage, 0, 356)
    local gHdr1 = CreateSectionHeader(gSec1, -10, "DYNAMIC FPS GUARD, SPELLQUEUE & ENGINE AUTOMATION", "Real-time combat framerate protection and automatic World Ping spell queue tuning.")

    local g1RowZoneEngine = CreateCardRow(gSec1, -54, 56, "Automatic Zone Graphics Switching", "Automatically switches graphics profiles on zone entry without requiring a UI reload.")
    local swZoneEngine = CreateBinarySegmentedSwitch(g1RowZoneEngine, function()
        return DynamicFPSDB.autoZoneSwitch and true or false
    end, function(val)
        DynamicFPSDB.autoZoneSwitch = val
        if val then
            ApplyZoneGraphicsConfig(GetCurrentZoneContext(), true)
        else
            RestoreBaselineCVarsOnly()
        end
    end, "Off", "Enabled")
    swZoneEngine:SetPoint("RIGHT", g1RowZoneEngine, "RIGHT", -14, 0)
    g1RowZoneEngine:ClampDescToControl(swZoneEngine)

    local g1RowFPSGuard = CreateCardRow(gSec1, -116, 56, "Combat FPS Drop Protection", "Monitors framerate during active combat and steps down clutter if FPS dips below floor.")
    local g1SubFPSFloor = CreateCardRow(g1RowFPSGuard, -82, 56, "Minimum Combat FPS", "Temporarily lowers minor visual effects during heavy combat pulls if your FPS drops below this target.", true)
    local pillsFPSFloor = CreateSegmentedPills(g1SubFPSFloor, 248, TARGET_FPS_FLOOR_PILLS, function()
        if DynamicFPSDB.targetFPSFloor == nil then return 60 end
        return _SafeNum(DynamicFPSDB.targetFPSFloor, 0)
    end, function(val)
        DynamicFPSDB.targetFPSFloor = val
        if val == 0 and currentGovernorStep > 0 then
            StopCombatFPSGovernor()
        end
    end)
    pillsFPSFloor:SetPoint("RIGHT", g1SubFPSFloor, "RIGHT", -14, 0)
    g1SubFPSFloor.desc:ClearAllPoints()
    g1SubFPSFloor.desc:SetPoint("TOPLEFT", g1SubFPSFloor.title, "BOTTOMLEFT", 0, -3)
    g1SubFPSFloor.desc:SetPoint("RIGHT", pillsFPSFloor, "LEFT", -12, 0)

    local g1SubFPSTelemetry = CreateFrame("Frame", nil, g1RowFPSGuard, "BackdropTemplate")
    g1SubFPSTelemetry:SetHeight(28)
    g1SubFPSTelemetry.bg = CreateSolidTex(g1SubFPSTelemetry, "BACKGROUND", 2, PALETTE.VOID.r, PALETTE.VOID.g, PALETTE.VOID.b, 0.99)
    g1SubFPSTelemetry.bg:SetAllPoints()
    Create1PxBorder(g1SubFPSTelemetry, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 0.95)
    g1SubFPSTelemetry.accentLeft = CreateSolidTex(g1SubFPSTelemetry, "OVERLAY", 3, ar, ag, ab, 0.95)
    g1SubFPSTelemetry.accentLeft:SetPoint("TOPLEFT", g1SubFPSTelemetry, "TOPLEFT", 0, -1)
    g1SubFPSTelemetry.accentLeft:SetPoint("BOTTOMLEFT", g1SubFPSTelemetry, "BOTTOMLEFT", 0, 1)
    g1SubFPSTelemetry.accentLeft:SetWidth(2)
    g1SubFPSTelemetry.txt = g1SubFPSTelemetry:CreateFontString(nil, "OVERLAY")
    g1SubFPSTelemetry.txt:SetPoint("LEFT", g1SubFPSTelemetry, "LEFT", 12, 0)
    g1SubFPSTelemetry.txt:SetPoint("RIGHT", g1SubFPSTelemetry, "RIGHT", -12, 0)
    g1SubFPSTelemetry.txt:SetJustifyH("LEFT")
    g1SubFPSTelemetry.txt:SetWordWrap(false)
    SetStyledFont(g1SubFPSTelemetry.txt, 10.5, "", PALETTE.TEXT_PRI.r, PALETTE.TEXT_PRI.g, PALETTE.TEXT_PRI.b, 0.98)

    local g1RowAutoSQ = CreateCardRow(gSec1, -228, 56, "Automatic Spell Queue Tuning (Ping & Spec)", "Synchronises your spell queue delay to your live World/Home Ping and active Spec / Haste GCD profile.")

    local g1SubSQTelemetry = CreateFrame("Frame", nil, g1RowAutoSQ, "BackdropTemplate")
    g1SubSQTelemetry:SetHeight(28)
    g1SubSQTelemetry.bg = CreateSolidTex(g1SubSQTelemetry, "BACKGROUND", 2, PALETTE.VOID.r, PALETTE.VOID.g, PALETTE.VOID.b, 0.99)
    g1SubSQTelemetry.bg:SetAllPoints()
    Create1PxBorder(g1SubSQTelemetry, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 0.95)
    g1SubSQTelemetry.accentLeft = CreateSolidTex(g1SubSQTelemetry, "OVERLAY", 3, ar, ag, ab, 0.95)
    g1SubSQTelemetry.accentLeft:SetPoint("TOPLEFT", g1SubSQTelemetry, "TOPLEFT", 0, -1)
    g1SubSQTelemetry.accentLeft:SetPoint("BOTTOMLEFT", g1SubSQTelemetry, "BOTTOMLEFT", 0, 1)
    g1SubSQTelemetry.accentLeft:SetWidth(2)
    g1SubSQTelemetry.txt = g1SubSQTelemetry:CreateFontString(nil, "OVERLAY")
    g1SubSQTelemetry.txt:SetPoint("LEFT", g1SubSQTelemetry, "LEFT", 12, 0)
    g1SubSQTelemetry.txt:SetPoint("RIGHT", g1SubSQTelemetry, "RIGHT", -12, 0)
    g1SubSQTelemetry.txt:SetJustifyH("LEFT")
    g1SubSQTelemetry.txt:SetWordWrap(false)
    SetStyledFont(g1SubSQTelemetry.txt, 10.5, "", PALETTE.TEXT_PRI.r, PALETTE.TEXT_PRI.g, PALETTE.TEXT_PRI.b, 0.98)

    local g1SubSQPadding = CreateCardRow(g1RowAutoSQ, -114, 52, "Custom Manual Spell Queue Delay (ms)", "Manually set how early WoW queues your next spell press before the global cooldown finishes (50 ms to 400 ms).", true)
    local slSQPadding = CreateInlineSliderControl(g1SubSQPadding, 248, 50, 400, 5, function()
        return _SafeNum(DynamicFPSDB.spellQueueManualMS, 180)
    end, function(val)
        DynamicFPSDB.spellQueueManualMS = val
        DynamicFPSDB.spellQueueMode = "CUSTOM_MANUAL"
        ApplySpellQueueWindow(true)
        if DynamicFPS.RefreshGuardTelemetry then
            DynamicFPS.RefreshGuardTelemetry()
        end
    end, function(v) return string.format("%d ms", v) end)
    slSQPadding:SetPoint("RIGHT", g1SubSQPadding, "RIGHT", -14, 0)
    g1SubSQPadding:ClampDescToControl(slSQPadding)

    local function RefreshGuardTelemetry()
        local rawFPS = (GetFramerate and GetFramerate()) or 60
        local liveFPS = math.floor(_SafeNum(rawFPS, 60) + 0.5)
        local floorVal = _SafeNum(DynamicFPSDB.targetFPSFloor, 60)
        local floorStr = (floorVal > 0) and string.format("%d FPS", floorVal) or "Off"
        local guardStatus = "|cFF94A3B8Disabled|r"
        if DynamicFPSDB.fpsGuardEnabled and floorVal > 0 then
            if currentGovernorStep > 0 then
                guardStatus = string.format("|cFFF59E0BActively Boosting (Step %d/2)|r", currentGovernorStep)
            else
                guardStatus = "|cFF10B981Standby|r"
            end
        end
        local fpsColor = (floorVal > 0 and liveFPS < floorVal) and "|cFFF59E0B" or "|cFF10B981"
        g1SubFPSTelemetry.txt:SetText(string.format("Live FPS: %s%d|r   |cFF475569|||r   Protected Floor: |cFFFFFFFF%s|r   |cFF475569|||r   Guard Status: %s", fpsColor, liveFPS, floorStr, guardStatus))

        local calcMS, wMS, hMS, specName, profileLabel, hastePct, sqMode = CalculateTargetSpellQueueMS()
        local liveCVar = _SafeNum(SafeGetCVar("SpellQueueWindow", calcMS), calcMS)
        local syncBadge = (math.abs(liveCVar - calcMS) <= 5) and "|cFF10B981[Synced]|r" or string.format("|cFFF59E0B[Target: %dms]|r", calcMS)
        local profileSummary = string.format("%s (%s, %.0f%% Haste)", specName or "General", profileLabel or "Caster", _SafeNum(hastePct, _dfpsCachedHaste))
        if sqMode == "CUSTOM_MANUAL" then
            profileSummary = string.format("Custom Manual (%d ms)", calcMS)
        elseif sqMode == "BLIZZARD_DEFAULT" then
            profileSummary = "Blizzard Default (400 ms)"
        end
        g1SubSQTelemetry.txt:SetText(string.format("Ping: |cFFFFFFFF%dms|r (World) / |cFFFFFFFF%dms|r (Home)   |cFF475569|||r   Spec Profile: |cFFFFFFFF%s|r   |cFF475569|||r   Live Queue Delay: |cFF10B981%dms|r %s", _SafeNum(wMS, _dfpsCachedPing), _SafeNum(hMS, _dfpsCachedPing), profileSummary, liveCVar, syncBadge))
    end
    DynamicFPS.RefreshGuardTelemetry = RefreshGuardTelemetry

    -- Section 2 - FRAME RATE CAPS, COMBAT LOGS & CONTEXT DECLUTTER (Individual Setting Cards)
    local gSec2 = CreateSectionBox(guardPage, nil, 370)
    gSec2:SetPoint("TOPLEFT", gSec1, "BOTTOMLEFT", 0, -14)
    gSec2:SetPoint("TOPRIGHT", gSec1, "BOTTOMRIGHT", 0, -14)
    local gHdr2 = CreateSectionHeader(gSec2, -10, "FRAME RATE CAPS, COMBAT LOGS & CONTEXT DECLUTTER", "Foreground/background FPS limits, automatic WarcraftLogs management, and instance UI decluttering.")

    local g2r1 = CreateCardRow(gSec2, -54, 56, "Max Foreground FPS", "Caps active in-game framerate to stabilise frame pacing and prevent GPU coil whine.")
    local ddMaxFG = CreateObsidianDropdown(g2r1, 248, MAX_FG_FPS_DROPDOWN, function()
        return _SafeNum(DynamicFPSDB.maxForegroundFPS, 0)
    end, function(val)
        DynamicFPSDB.maxForegroundFPS = val
        ApplyFrameRateCaps()
    end)
    ddMaxFG:SetPoint("RIGHT", g2r1, "RIGHT", -14, 0)
    g2r1:ClampDescToControl(ddMaxFG)

    local g2r2 = CreateCardRow(gSec2, -116, 56, "Max Background FPS", "Caps background framerate when Alt-Tabbed to eliminate GPU heat and power draw.")
    local ddMaxBG = CreateObsidianDropdown(g2r2, 248, MAX_BG_FPS_DROPDOWN, function()
        return _SafeNum(DynamicFPSDB.maxBackgroundFPS, 30)
    end, function(val)
        DynamicFPSDB.maxBackgroundFPS = val
        ApplyFrameRateCaps()
    end)
    ddMaxBG:SetPoint("RIGHT", g2r2, "RIGHT", -14, 0)
    g2r2:ClampDescToControl(ddMaxBG)

    local g2r3 = CreateCardRow(gSec2, -178, 56, "Combat Log Auto-Purge", "Automatically starts WarcraftLogs in instances and stops on exit (auto-yields when !ArchonLogger or LoggerHead is active).")
    local ddCombatLog = CreateObsidianDropdown(g2r3, 248, COMBAT_LOG_PURGE_DROPDOWN, function()
        return DynamicFPSDB.combatLogAutoPurge or "RAID_AND_MPLUS"
    end, function(val)
        DynamicFPSDB.combatLogAutoPurge = val
        EvaluateCombatLogAutoPurge()
    end)
    ddCombatLog:SetPoint("RIGHT", g2r3, "RIGHT", -14, 0)
    g2r3:ClampDescToControl(ddCombatLog)

    local g2r4 = CreateCardRow(gSec2, -240, 56, "Quest Objective Tracker", "Automatically collapses the right-side Objective Tracker during boss encounters or Mythic+.")
    local ddQuestTracker = CreateObsidianDropdown(g2r4, 248, QUEST_TRACKER_DROPDOWN, function()
        return DynamicFPSDB.questTrackerMode or "COLLAPSE_MPLUS_RAID"
    end, function(val)
        DynamicFPSDB.questTrackerMode = val
        EvaluateQuestTrackerDeclutter(false, InCombatLockdown and InCombatLockdown())
    end)
    ddQuestTracker:SetPoint("RIGHT", g2r4, "RIGHT", -14, 0)
    g2r4:ClampDescToControl(ddQuestTracker)

    local g2r5 = CreateCardRow(gSec2, -302, 56, "Error Speech & Boss Loot Banner", "Silences repetitive 'not ready yet' vocal and red error spam in combat, and optionally hides boss loot banners.")
    local ddDeclutterAudio = CreateSegmentedPills(g2r5, 326, DECLUTTER_AUDIO_PILLS, function()
        return DynamicFPSDB.declutterAudioMode or "MUTE_SPEECH_ONLY"
    end, function(val)
        DynamicFPSDB.declutterAudioMode = val
        ApplyDeclutterAudioSetting()
    end)
    ddDeclutterAudio:SetPoint("RIGHT", g2r5, "RIGHT", -14, 0)
    g2r5:ClampDescToControl(ddDeclutterAudio)

    local btnTuneFPSGuard = nil
    local btnTuneAutoSQ = nil
    local swFPSGuard = nil
    local swAutoSQ = nil

    -- Item #37: Dynamic Sub-Drawer Layout Reflow per DESIGN_SYSTEM.md Section 2.6
    local function ReflowGuardSubDrawers()
        local curAr, curAg, curAb = GetSuiteAccentColor()
        if gHdr1 then gHdr1:RefreshAccent() end
        if gHdr2 then gHdr2:RefreshAccent() end
        local yCursor = -54

        -- Row 1: Enable DynamicFPS Zone Engine
        g1RowZoneEngine:ClearAllPoints()
        g1RowZoneEngine:SetPoint("TOPLEFT", gSec1, "TOPLEFT", 14, yCursor)
        g1RowZoneEngine:SetPoint("TOPRIGHT", gSec1, "TOPRIGHT", -14, yCursor)
        yCursor = yCursor - 62

        -- Row 2: Dynamic Emergency FPS Guard (Unified Outer Group Card + 24px Horizontal Chevron Bar + Nested Sub-Card)
        g1RowFPSGuard:ClearAllPoints()
        g1RowFPSGuard:SetPoint("TOPLEFT", gSec1, "TOPLEFT", 14, yCursor)
        g1RowFPSGuard:SetPoint("TOPRIGHT", gSec1, "TOPRIGHT", -14, yCursor)
        if swFPSGuard then
            g1RowFPSGuard:ClampDescToControl(swFPSGuard)
        end

        if DynamicFPSDB.fpsGuardEnabled then
            if DynamicFPSDB.fpsGuardDrawerOpen ~= false then
                g1SubFPSFloor:ClearAllPoints()
                g1SubFPSFloor:SetPoint("TOPLEFT", g1RowFPSGuard, "TOPLEFT", 10, -82)
                g1SubFPSFloor:SetPoint("TOPRIGHT", g1RowFPSGuard, "TOPRIGHT", -10, -82)
                if g1SubFPSFloor.accentLeft then
                    g1SubFPSFloor.accentLeft:SetColorTexture(curAr, curAg, curAb, 1.0)
                end
                if g1SubFPSFloor.accentPip then
                    g1SubFPSFloor.accentPip:SetColorTexture(curAr, curAg, curAb, 1.0)
                end
                g1SubFPSFloor:Show()

                g1SubFPSTelemetry:ClearAllPoints()
                g1SubFPSTelemetry:SetPoint("TOPLEFT", g1RowFPSGuard, "TOPLEFT", 10, -146)
                g1SubFPSTelemetry:SetPoint("TOPRIGHT", g1RowFPSGuard, "TOPRIGHT", -10, -146)
                if g1SubFPSTelemetry.accentLeft then
                    g1SubFPSTelemetry.accentLeft:SetColorTexture(curAr, curAg, curAb, 1.0)
                end
                g1SubFPSTelemetry:Show()

                g1RowFPSGuard:SetHeight(184)
                yCursor = yCursor - 190
            else
                g1SubFPSFloor:Hide()
                g1SubFPSTelemetry:Hide()
                g1RowFPSGuard:SetHeight(84)
                yCursor = yCursor - 90
            end
            if btnTuneFPSGuard then
                btnTuneFPSGuard:Show()
                btnTuneFPSGuard:RefreshValue(btnTuneFPSGuard:IsMouseOver())
            end
        else
            if btnTuneFPSGuard then
                btnTuneFPSGuard:Hide()
            end
            g1SubFPSFloor:Hide()
            g1SubFPSTelemetry:Hide()
            g1RowFPSGuard:SetHeight(56)
            g1RowFPSGuard:SetBorderColor(PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 0.95)
            yCursor = yCursor - 62
        end

        -- Row 3: Dynamic SpellQueueWindow Engine (Unified Outer Group Card + 24px Horizontal Chevron Bar + Telemetry + Manual Slider)
        g1RowAutoSQ:ClearAllPoints()
        g1RowAutoSQ:SetPoint("TOPLEFT", gSec1, "TOPLEFT", 14, yCursor)
        g1RowAutoSQ:SetPoint("TOPRIGHT", gSec1, "TOPRIGHT", -14, yCursor)
        if swAutoSQ then
            g1RowAutoSQ:ClampDescToControl(swAutoSQ)
        end

        local curSQMode = GetSpellQueueMode()
        if btnTuneAutoSQ and btnTuneAutoSQ.label then
            btnTuneAutoSQ.subCount = (curSQMode == "CUSTOM_MANUAL") and 2 or 1
        end

        if DynamicFPSDB.spellQueueDrawerOpen ~= false then
            g1SubSQTelemetry:ClearAllPoints()
            g1SubSQTelemetry:SetPoint("TOPLEFT", g1RowAutoSQ, "TOPLEFT", 10, -82)
            g1SubSQTelemetry:SetPoint("TOPRIGHT", g1RowAutoSQ, "TOPRIGHT", -10, -82)
            if g1SubSQTelemetry.accentLeft then
                g1SubSQTelemetry.accentLeft:SetColorTexture(curAr, curAg, curAb, 1.0)
            end
            g1SubSQTelemetry:Show()

            if curSQMode == "CUSTOM_MANUAL" then
                g1SubSQPadding:ClearAllPoints()
                g1SubSQPadding:SetPoint("TOPLEFT", g1RowAutoSQ, "TOPLEFT", 10, -116)
                g1SubSQPadding:SetPoint("TOPRIGHT", g1RowAutoSQ, "TOPRIGHT", -10, -116)
                if g1SubSQPadding.accentLeft then
                    g1SubSQPadding.accentLeft:SetColorTexture(curAr, curAg, curAb, 1.0)
                end
                if g1SubSQPadding.accentPip then
                    g1SubSQPadding.accentPip:SetColorTexture(curAr, curAg, curAb, 1.0)
                end
                g1SubSQPadding:Show()
                g1RowAutoSQ:SetHeight(178)
                yCursor = yCursor - 184
            else
                g1SubSQPadding:Hide()
                g1RowAutoSQ:SetHeight(120)
                yCursor = yCursor - 126
            end
        else
            g1SubSQTelemetry:Hide()
            g1SubSQPadding:Hide()
            g1RowAutoSQ:SetHeight(84)
            yCursor = yCursor - 90
        end
        if btnTuneAutoSQ then
            btnTuneAutoSQ:Show()
            btnTuneAutoSQ:RefreshValue(btnTuneAutoSQ:IsMouseOver())
        end

        RefreshGuardTelemetry()

        local gSec1H = (math.abs(yCursor) - 6) + 12
        gSec1:SetHeight(gSec1H)
        gSec2:SetHeight(370)

        local totalGuardH = gSec1H + 14 + 370 + 14
        guardPage:SetHeight(totalGuardH)
        if DynamicFPSDB.activeTab == "GUARD_QUEUE" then
            scrollChild:SetHeight(totalGuardH)
            UpdateScrollbarVisual()
        end
    end

    swFPSGuard = CreateBinarySegmentedSwitch(g1RowFPSGuard, function()
        return DynamicFPSDB.fpsGuardEnabled and true or false
    end, function(val)
        DynamicFPSDB.fpsGuardEnabled = val
        if val then
            DynamicFPSDB.fpsGuardDrawerOpen = true
        end
        ReflowGuardSubDrawers()
    end, "Off", "Enabled")
    swFPSGuard:SetPoint("TOPRIGHT", g1RowFPSGuard, "TOPRIGHT", -14, -15)
    g1RowFPSGuard:ClampDescToControl(swFPSGuard)

    btnTuneFPSGuard = CreateSubDrawerButton(g1RowFPSGuard, function()
        return DynamicFPSDB.fpsGuardDrawerOpen ~= false
    end, function()
        DynamicFPSDB.fpsGuardDrawerOpen = (DynamicFPSDB.fpsGuardDrawerOpen == false)
        ReflowGuardSubDrawers()
    end, 1, function()
        return DynamicFPSDB.fpsGuardEnabled and true or false
    end)

    swAutoSQ = CreateSegmentedPills(g1RowAutoSQ, 290, SPELL_QUEUE_MODE_PILLS, function()
        return GetSpellQueueMode()
    end, function(val)
        DynamicFPSDB.spellQueueMode = val
        DynamicFPSDB.autoTuneSpellQueue = (val ~= "BLIZZARD_DEFAULT")
        DynamicFPSDB.spellQueueDrawerOpen = true
        ApplySpellQueueWindow(true)
        ReflowGuardSubDrawers()
    end)
    swAutoSQ:SetPoint("TOPRIGHT", g1RowAutoSQ, "TOPRIGHT", -14, -15)
    g1RowAutoSQ:ClampDescToControl(swAutoSQ)

    btnTuneAutoSQ = CreateSubDrawerButton(g1RowAutoSQ, function()
        return DynamicFPSDB.spellQueueDrawerOpen ~= false
    end, function()
        DynamicFPSDB.spellQueueDrawerOpen = (DynamicFPSDB.spellQueueDrawerOpen == false)
        ReflowGuardSubDrawers()
    end, 1, function()
        return true
    end)

    local telemetryElapsed = 0
    guardPage:SetScript("OnUpdate", function(_, elapsed)
        telemetryElapsed = telemetryElapsed + (elapsed or 0)
        if telemetryElapsed >= 0.5 then
            telemetryElapsed = 0
            RefreshGuardTelemetry()
        end
    end)

    RegisterRefresh(function()
        swZoneEngine:RefreshValue()
        swFPSGuard:RefreshValue()
        btnTuneFPSGuard:RefreshValue()
        pillsFPSFloor:RefreshValue()
        swAutoSQ:RefreshValue()
        btnTuneAutoSQ:RefreshValue()
        slSQPadding:RefreshValue()
        RefreshGuardTelemetry()
        ddMaxFG:RefreshValue()
        ddMaxBG:RefreshValue()
        ddCombatLog:RefreshValue()
        ddQuestTracker:RefreshValue()
        ddDeclutterAudio:RefreshValue()
        ReflowGuardSubDrawers()
    end)

    -- ========================================================================
    -- TOP NAVIGATION CONTROLLER (6 Left Zone Cells + Far-Right Guard Pill)
    -- ========================================================================
    local function SelectTab(tabId, resetScroll)
        CloseActiveDropdownMenu()
        local prevTab = DynamicFPSDB.activeTab
        DynamicFPSDB.activeTab = tabId
        local curAr, curAg, curAb = GetSuiteAccentColor()

        if tabId == "GUARD_QUEUE" then
            zonePage:Hide()
            guardPage:Show()
            ReflowGuardSubDrawers()
            scrollChild:SetHeight(guardPage:GetHeight() + 14)
        else
            guardPage:Hide()
            zonePage:Show()
            scrollChild:SetHeight(zonePage:GetHeight() + 14)
        end

        local activeZoneKey = GetCurrentZoneContext()
        for id, btn in pairs(tabButtons) do
            if btn.activeDot then
                btn.activeDot:SetShown(id == activeZoneKey)
            end
            if id == tabId then
                btn.bg:SetColorTexture(curAr * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), curAg * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), curAb * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), 0.95)
                btn:SetBorderColor(curAr, curAg, curAb, 0.90)
                SetStyledFont(btn.label, 11, "", 1.0, 1.0, 1.0, 1.0)
            else
                btn.bg:SetColorTexture(0.078, 0.090, 0.122, 0.85)
                btn:SetBorderColor(1, 1, 1, 0.07)
                SetStyledFont(btn.label, 11, "", PALETTE.TEXT_SEC.r, PALETTE.TEXT_SEC.g, PALETTE.TEXT_SEC.b, 0.92)
            end
        end

        for _, fn in ipairs(refreshCallbacks) do
            pcall(fn)
        end

        if resetScroll or (prevTab ~= tabId) then
            scrollFrame:SetVerticalScroll(0)
        end
        UpdateScrollbarVisual()
    end

    for id, btn in pairs(tabButtons) do
        btn:SetScript("OnClick", function()
            SelectTab(id, id ~= DynamicFPSDB.activeTab)
        end)
    end

    function DynamicFPS.SelectSubTab(selfOrTab, maybeTab, maybeExpand)
        local raw = (type(selfOrTab) == "table") and maybeTab or selfOrTab
        local expandDrawers = (type(selfOrTab) == "table") and maybeExpand or maybeTab
        if expandDrawers and DynamicFPSDB then
            DynamicFPSDB.fpsGuardDrawerOpen = true
            DynamicFPSDB.spellQueueDrawerOpen = true
        end
        local tabId = "RAID"
        if raw == "GUARD_QUEUE" or raw == 7 or raw == 2 then
            tabId = "GUARD_QUEUE"
        elseif type(raw) == "string" and tabButtons[raw] then
            tabId = raw
        else
            tabId = (DynamicFPSDB and DynamicFPSDB.activeTab ~= "GUARD_QUEUE" and DynamicFPSDB.activeTab) or "RAID"
        end
        SelectTab(tabId, true)
    end
    DynamicFPS.SelectTab = DynamicFPS.SelectSubTab

    function DynamicFPS.RefreshWorkspaceUI()
        local curAr, curAg, curAb = GetSuiteAccentColor()
        scrollThumb.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
        if zHdr1 and zHdr1.txt then zHdr1.txt:SetTextColor(curAr, curAg, curAb, 1.0) end
        if zHdr2 and zHdr2.txt then zHdr2.txt:SetTextColor(curAr, curAg, curAb, 1.0) end
        if gHdr1 and gHdr1.txt then gHdr1.txt:SetTextColor(curAr, curAg, curAb, 1.0) end
        if gHdr2 and gHdr2.txt then gHdr2.txt:SetTextColor(curAr, curAg, curAb, 1.0) end
        LayoutLeftZoneTrack()
        SelectTab(DynamicFPSDB.activeTab or "RAID", false)
    end

    C_Timer.After(0, function()
        LayoutLeftZoneTrack()
        if scrollFrame:GetWidth() and scrollFrame:GetWidth() > 40 then
            scrollChild:SetWidth(scrollFrame:GetWidth())
        end
        DynamicFPS.RefreshWorkspaceUI()
    end)

    return root
end

DynamicFPS.RenderEmbedded = function(selfOrParent, maybeParent)
    local targetParent = (type(selfOrParent) == "table" and selfOrParent.GetObjectType) and selfOrParent or maybeParent
    return RenderFPSEmbedded(targetParent)
end

-- ============================================================================
-- 10. SUITE ROUTING (/dfps -> _G.DynamicSuite:OpenModule("DynamicFPS"), Item #42)
-- ============================================================================
local function IsDynamicLoadActive()
    if _G.DynamicLoadUI or _G.DynamicLoad or _G.DynamicLoadMainFrame then
        return true
    end
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "DynamicLoad")
        if ok and loaded then return true end
    end
    return false
end

local function ApplyFPSThemeToUI()
    if DynamicFPS.RefreshWorkspaceUI then
        DynamicFPS.RefreshWorkspaceUI()
    end
    if standaloneWindow and standaloneWindow.RefreshTheme then
        standaloneWindow:RefreshTheme()
    end
end

local function ResetFPSModuleDefaults()
    local savedBaseline = DynamicFPSDB and DynamicFPSDB.savedBaselineCVars
    _G.DynamicFPSDB = DeepCopyTable(DEFAULT_DB)
    _G.DynamicFPSDB.savedBaselineCVars = savedBaseline
    ApplyZoneGraphicsConfig(GetCurrentZoneContext(), true)
    ApplySpellQueueWindow()
    ApplyDeclutterAudioSetting()
    if DynamicFPS.RefreshWorkspaceUI then
        DynamicFPS.RefreshWorkspaceUI()
    end
    print(ADDON_TITLE_COLORED .. ": Module settings reset to factory defaults.")
end

local FPS_BLIZZARD_CVARS = {
    "projectedTextures", "RAIDprojectedTextures",
    "useMaxFPS", "maxFPS", "useMaxFPSBk", "maxFPSBk",
    "nameplateShowFriends", "findYourselfMode",
    "graphicsSpellDensity", "RAIDgraphicsSpellDensity", "spellClutter",
    "graphicsGroundClutter", "RAIDgroundEffectDensity",
    "graphicsParticleDensity", "RAIDgraphicsParticleDensity",
    "farclip", "RAIDfarclip", "horizonClip",
    "graphicsViewDistance", "RAIDgraphicsViewDistance",
    "SpellQueueWindow", "Sound_EnableErrorSpeech",
}

local function RestoreFPSBlizzardDefaults()
    if type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() then
        print(ADDON_TITLE_COLORED .. ": Cannot restore Blizzard defaults while in combat. Please leave combat and try again.")
        return
    end
    local snap = (_G.DynamicFPSDB and type(_G.DynamicFPSDB.savedBaselineCVars) == "table") and _G.DynamicFPSDB.savedBaselineCVars or {}
    local seen = {}
    local queue = {}
    for _, k in ipairs(FPS_BLIZZARD_CVARS) do
        if not seen[k] then seen[k] = true; table.insert(queue, k) end
    end
    for k in pairs(snap) do
        if not seen[k] then seen[k] = true; table.insert(queue, k) end
    end
    for _, cvarName in ipairs(queue) do
        local targetVal = snap[cvarName]
        if targetVal == nil and C_CVar and type(C_CVar.GetCVarDefault) == "function" then
            local okDef, defVal = pcall(C_CVar.GetCVarDefault, cvarName)
            if okDef and defVal ~= nil then
                targetVal = defVal
            end
        end
        if targetVal ~= nil then
            SafeSetCVar(cvarName, targetVal)
        end
    end
    print(ADDON_TITLE_COLORED .. ": Restored Blizzard default graphics & SpellQueue CVars. Reload UI to complete cleanup.")
    if type(_G.StaticPopupDialogs) == "table" and type(_G.StaticPopup_Show) == "function" then
        _G.StaticPopupDialogs["DYNAMICFPS_RELOAD_PROMPT"] = _G.StaticPopupDialogs["DYNAMICFPS_RELOAD_PROMPT"] or {
            text = "DynamicFPS has restored Blizzard default CVars. Reload UI now?",
            button1 = "Reload UI",
            button2 = "Later",
            OnAccept = function()
                if type(_G.ReloadUI) == "function" then _G.ReloadUI() end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        _G.StaticPopup_Show("DYNAMICFPS_RELOAD_PROMPT")
    end
end
DynamicFPS.RestoreBlizzardDefaults = RestoreFPSBlizzardDefaults

local isOpeningSuiteGuard = false

local function OpenFPSWorkspace()
    EnsureDBInitialized()

    -- Item #42: Route /dfps directly via _G.DynamicSuite:OpenModule("DynamicFPS")
    if isOpeningSuiteGuard then return end
    isOpeningSuiteGuard = true

    if _G.DynamicSuite and type(_G.DynamicSuite.OpenModule) == "function" then
        if standaloneWindow and standaloneWindow:IsShown() then
            standaloneWindow:Hide()
        end
        local ok = pcall(_G.DynamicSuite.OpenModule, _G.DynamicSuite, "DynamicFPS")
        if ok then
            isOpeningSuiteGuard = false
            return
        end
    end

    if IsDynamicLoadActive() and (_G.DynamicSuite and _G.DynamicSuite._isHubLoaded) then
        if standaloneWindow and standaloneWindow:IsShown() then
            standaloneWindow:Hide()
        end

        local opened = false
        if _G.DynamicLoadUI then
            local ui = _G.DynamicLoadUI
            if type(ui.OpenSuiteToModule) == "function" then
                opened = pcall(ui.OpenSuiteToModule, "DynamicFPS")
            elseif type(ui.OpenModule) == "function" then
                opened = pcall(ui.OpenModule, "DynamicFPS")
            elseif type(ui.SwitchModule) == "function" then
                if type(ui.Show) == "function" then pcall(ui.Show) end
                opened = pcall(ui.SwitchModule, "DynamicFPS")
            elseif type(ui.SelectModule) == "function" then
                if type(ui.Show) == "function" then pcall(ui.Show) end
                opened = pcall(ui.SelectModule, "DynamicFPS")
            elseif type(ui.ToggleUI) == "function" then
                opened = pcall(ui.ToggleUI, "DynamicFPS")
            end
        end

        if not opened and _G.DynamicLoad and type(_G.DynamicLoad.ToggleConfigUI) == "function" then
            pcall(_G.DynamicLoad.ToggleConfigUI, "DynamicFPS")
            opened = true
        end

        if not opened and SlashCmdList and SlashCmdList["DYNAMICLOAD"] then
            pcall(SlashCmdList["DYNAMICLOAD"], "fps")
        end

        isOpeningSuiteGuard = false
        return
    end

    isOpeningSuiteGuard = false

    -- Standalone fallback ONLY when DynamicFPS is installed completely solo without DynamicLoad
    if not standaloneWindow then
        local g = _G.DynamicSuiteDB.global
        local winW = math.max(800, math.min(1380, _SafeNum(g.width, 980)))
        local winH = math.max(520, math.min(900, _SafeNum(g.height, 680)))

        local f = CreateFrame("Frame", "DynamicFPSSoloFrame", UIParent)
        f:SetSize(winW, winH)
        f:SetPoint("CENTER")
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
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

        f.bg = CreateSolidTex(f, "BACKGROUND", 0, PALETTE.VOID.r, PALETTE.VOID.g, PALETTE.VOID.b, PALETTE.VOID.a)
        f.bg:SetAllPoints()
        Create1PxBorder(f, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 0.9)
        table.insert(UISpecialFrames, "DynamicFPSSoloFrame")

        local header = CreateFrame("Frame", nil, f)
        header:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
        header:SetHeight(46)
        header.bg = CreateSolidTex(header, "BACKGROUND", 1, PALETTE.SURFACE_BASE.r, PALETTE.SURFACE_BASE.g, PALETTE.SURFACE_BASE.b, 1.0)
        header.bg:SetAllPoints()

        local ar, ag, ab = GetSuiteAccentColor()
        header.topLine = CreateSolidTex(header, "OVERLAY", 4, ar, ag, ab, 1.0)
        header.topLine:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
        header.topLine:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
        header.topLine:SetHeight(2)

        local closeBtn = CreateFrame("Button", nil, header)
        closeBtn:SetSize(26, 24)
        closeBtn:SetPoint("RIGHT", header, "RIGHT", -12, 0)
        closeBtn.bg = CreateSolidTex(closeBtn, "BACKGROUND", 1, PALETTE.CELL_NEUTRAL.r, PALETTE.CELL_NEUTRAL.g, PALETTE.CELL_NEUTRAL.b, 1.0)
        closeBtn.bg:SetAllPoints()
        Create1PxBorder(closeBtn, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)
        closeBtn.lbl = closeBtn:CreateFontString(nil, "OVERLAY")
        closeBtn.lbl:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
        SetStyledFont(closeBtn.lbl, 11, "", PALETTE.TEXT_PRI.r, PALETTE.TEXT_PRI.g, PALETTE.TEXT_PRI.b, 0.9)
        closeBtn.lbl:SetText("X")
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        local titleTxt = header:CreateFontString(nil, "OVERLAY")
        titleTxt:SetPoint("LEFT", header, "LEFT", 16, 0)
        SetStyledFont(titleTxt, 14, "", PALETTE.TEXT_PRI.r, PALETTE.TEXT_PRI.g, PALETTE.TEXT_PRI.b, 1.0)
        titleTxt:SetText(ADDON_TITLE_COLORED .. "  |cFF94A3B8v" .. ADDON_VERSION .. "|r")

        local bottomDock = CreateFrame("Frame", nil, f)
        bottomDock:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
        bottomDock:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
        bottomDock:SetHeight(40)
        bottomDock.bg = CreateSolidTex(bottomDock, "BACKGROUND", 1, PALETTE.SURFACE_BASE.r, PALETTE.SURFACE_BASE.g, PALETTE.SURFACE_BASE.b, 1.0)
        bottomDock.bg:SetAllPoints()

        local resetBtn = CreateFrame("Button", nil, bottomDock)
        resetBtn:SetSize(140, 26)
        resetBtn:SetPoint("LEFT", bottomDock, "LEFT", 16, 0)
        resetBtn.bg = CreateSolidTex(resetBtn, "BACKGROUND", 1, PALETTE.CELL_NEUTRAL.r, PALETTE.CELL_NEUTRAL.g, PALETTE.CELL_NEUTRAL.b, 1.0)
        resetBtn.bg:SetAllPoints()
        Create1PxBorder(resetBtn, PALETTE.BORDER_CELL.r, PALETTE.BORDER_CELL.g, PALETTE.BORDER_CELL.b, 1.0)
        resetBtn.lbl = resetBtn:CreateFontString(nil, "OVERLAY")
        resetBtn.lbl:SetPoint("CENTER", resetBtn, "CENTER", 0, 0)
        SetStyledFont(resetBtn.lbl, 10.5, "", PALETTE.TEXT_PRI.r, PALETTE.TEXT_PRI.g, PALETTE.TEXT_PRI.b, 0.95)
        resetBtn.lbl:SetText("Reset DynamicFPS")
        resetBtn:SetScript("OnClick", function() ResetFPSModuleDefaults() end)

        local blizzResetBtn = CreateFrame("Button", nil, bottomDock)
        blizzResetBtn:SetSize(172, 26)
        blizzResetBtn:SetPoint("LEFT", resetBtn, "RIGHT", 8, 0)
        blizzResetBtn.bg = CreateSolidTex(blizzResetBtn, "BACKGROUND", 1, 0.09, 0.06, 0.07, 1.0)
        blizzResetBtn.bg:SetAllPoints()
        Create1PxBorder(blizzResetBtn, 0.937, 0.267, 0.267, 0.55)
        blizzResetBtn.lbl = blizzResetBtn:CreateFontString(nil, "OVERLAY")
        blizzResetBtn.lbl:SetPoint("CENTER", blizzResetBtn, "CENTER", 0, 0)
        SetStyledFont(blizzResetBtn.lbl, 10.5, "", 0.98, 0.72, 0.72, 0.96)
        blizzResetBtn.lbl:SetText("Restore Blizzard Defaults")
        blizzResetBtn:SetScript("OnClick", function() RestoreFPSBlizzardDefaults() end)

        local contentHost = CreateFrame("Frame", nil, f)
        contentHost:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
        contentHost:SetPoint("BOTTOMRIGHT", bottomDock, "TOPRIGHT", 0, 0)
        f.contentHost = contentHost

        RenderFPSEmbedded(contentHost)
        standaloneWindow = f
    end

    if standaloneWindow:IsShown() then
        standaloneWindow:Hide()
    else
        standaloneWindow:Show()
    end
end

DynamicFPS.Open = OpenFPSWorkspace
DynamicFPS.ToggleUI = OpenFPSWorkspace
DynamicFPS.ApplyTheme = ApplyFPSThemeToUI
DynamicFPS.ResetModuleDefaults = ResetFPSModuleDefaults

-- ============================================================================
-- 11. _G.DynamicSuite MODULE REGISTRATION
-- ============================================================================
DynamicFPS.CONFLICT_REGISTRY = {
    conflicts = { "Hyperframe" },
    hardConflicts = { "Hyperframe" },
    partialConflicts = { "AutoCombatLogger", "LoggerHead", "RaiderIO_AutoCombatLog", "!ArchonLogger", "ArchonLogger" },
    softConflicts = { "AutoCombatLogger", "LoggerHead", "RaiderIO_AutoCombatLog", "!ArchonLogger", "ArchonLogger" },
    yieldFeature = "combat log management",
    category = "Graphics & FPS Optimization",
}

local moduleEntry = {
    id = "fps",
    key = "fps",
    name = "DynamicFPS",
    title = "DynamicFPS",
    version = ADDON_VERSION,
    slash = "/dfps",
    subtitle = "Zone Graphics & FPS",
    desc = "Switches graphics settings per zone without reloading, protects combat FPS, tunes spell queue, and keeps boss swirlies visible.",
    icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_fps.tga",
    fallbackIcon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_fps.tga",
    iconWhite = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_white.tga",
    iconAccent = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_accent.tga",
    conflictRegistry = DynamicFPS.CONFLICT_REGISTRY,
    RenderEmbedded = function(selfOrParent, maybeParent)
        local targetParent = (type(selfOrParent) == "table" and selfOrParent.GetObjectType) and selfOrParent or maybeParent
        return RenderFPSEmbedded(targetParent)
    end,
    ApplyTheme = function()
        return ApplyFPSThemeToUI()
    end,
    Render = function(s, p) local tp = (type(s) == "table" and s.GetObjectType) and s or p; return RenderFPSEmbedded(tp) end, ResetModuleDefaults = ResetFPSModuleDefaults, ResetDefaults = ResetFPSModuleDefaults, ResetModule = ResetFPSModuleDefaults, Reset = ResetFPSModuleDefaults,
    Open = function()
        return OpenFPSWorkspace()
    end,
    OnDisableInSuite = function()
        if RestoreBaselineCVarsOnly then
            pcall(RestoreBaselineCVarsOnly)
        end
    end,
    GetStatusText = function()
        return GetStatusText()
    end,
    SelectSubTab = function(a1, a2, a3)
        if DynamicFPS.SelectSubTab then
            return DynamicFPS.SelectSubTab(a1, a2, a3)
        end
    end,
    SelectTab = function(a1, a2, a3)
        if DynamicFPS.SelectSubTab then
            return DynamicFPS.SelectSubTab(a1, a2, a3)
        end
    end,
}

_G.DynamicSuite.modules["fps"] = moduleEntry
_G.DynamicSuite.modules["DynamicFPS"] = moduleEntry

DynamicFPS.CHANGELOG = {
    version = ADDON_VERSION or "1.9.9",
    date = "13/11/2026",
    entries = {
        { type = "FIX",     text = "1:1 Blizzard Graphics CVar & SettingsPanel Synchronisation (13/11/2026): Fixed 0-based index offsets for Texture Resolution (0..2), View Distance / Environment Detail / Ground Clutter (0..9 CVars mapped to 1..10 UI sliders), and Particle Density; added runtime Settings.GetSetting label resolution + Settings.SetValue synchronisation alongside C_CVar.SetCVar; disabled RAIDsettingsEnabled split override and graphicsQuality cascade so every setting matches Blizzard's Graphics menu 1:1; and added CVAR_UPDATE two-way sync." },
        { type = "FEATURE", text = "External Addon Conflict Detector & Auto-Yield Engine (12/11/2026): Registered Hyperframe as a HARD graphics CVar conflict and AutoCombatLogger, LoggerHead, RaiderIO_AutoCombatLog, and !ArchonLogger as SOFT auto-yield overlaps in DynamicSuite." },
        { type = "FIX",     text = "Fixed RAIDsettingsEnabled CVar toggling (1 in instances, 0 in outdoor/cities), added PLAYER_LOGOUT and module-disable baseline CVar restoration without mutating saved zone tables, wired DynamicFPSDB.yieldHooks AUTO_YIELD checks across all CVar/declutter engines, and attached scrollThumb OnUpdate strictly during active mouse drag." },
        { type = "UI",      text = "Added the 6-Tier Quality & Performance Bottom Underline Bar (1.5px p.TierBar) across all multi-tier segmented pill controls (Tier 0 Off/Disabled Coral-Rose #F87171, Tier 1 Low/Essential Ice-Cyan #38BDF8, Tier 2 Fair/Reduced Emerald #34D399, Tier 3 Good Amber-Gold #FACC15, Tier 4 High/Everything Tangerine #FB923C, Tier 5 Ultra Amethyst #C084FC), and fixed 'Low' (val == 0 in Shadow Quality and Liquid Detail) falsely triggering negative 'Off' styling." },
        { type = "FIX",     text = "Combat Log Auto-Purge now automatically detects and yields to !ArchonLogger, LoggerHead, AutoCombatLogger, and RaiderIO_AutoCombatLog so external loggers never fight over LoggingCombat() state." },
        { type = "UI",      text = "Redesigned the top zone header into a unified 66px 2-Row Zone Profile & 1-Click Copy Toolbar Card: Row 1 shows Editing Profile + Live Zone status alongside 5 hardware preset pills (including active preset detection for 'Revert to Base'); Row 2 replaces the 2-click dropdown with 1-click source zone pills ('Copy Into <Zone> From:') with emerald flash feedback and a 2-tap 'Apply <Zone> to All' button." },
        { type = "FEATURE", text = "Aligned all Zone Graphics settings 1:1 with Blizzard's Retail 12.1.5 Base Game Quality menu: converted 'Essential Spell Visuals' (5-option dropdown) to 'Spell Density' 3-pill control (Essential, Reduced, Everything), added zero-gameplay GPU savers ('SSAO' and 'Depth Effects'), added 1-10 CPU bottleneck sliders ('View Distance', 'Environment Detail', 'Ground Clutter'), and aligned all tier labels (Low, Fair, Good, High, Ultra, Disabled)." },
        { type = "UI",      text = "Standardized action button and 1-click zone copy tooltips ('Revert to Base', 'Copy From <Zone>', and 'Apply <Zone> to All') to use Command-Prefix-Only Highlighting (Emerald Left-Click: prefix paired with Silver-White action description)." },
        { type = "FIX",     text = "Completed full secret-value sweep across DynamicFPS (_IsSecret, _SafeNum, _SafeNumber) to prevent numeric conversion errors on secret values (GetHaste, GetNetStats, GetFramerate, C_CVar) and guarded combat-protected CVars during active Mythic+ keys and boss encounters." },
        { type = "FEATURE", text = "Upgraded Dynamic SpellQueueWindow Engine to factor in both live World/Home latency and active Specialization + Haste GCD profile (Fast-GCD +95ms vs Caster +130ms) with a 3-mode selector and live CVar verification telemetry bar." },
        { type = "UI",      text = "Renamed 'Restore Baseline' to 'Revert to Base' with an explanatory tooltip, and simplified 'Minimum Combat FPS' with a concise 1-sentence description and live FPS vs Floor telemetry readout." },
        { type = "FIX",     text = "Resolved GetAuraDataByIndex secret aura taint by replacing ObjectiveTrackerFrame:SetCollapsed() with C-level ObjectiveTrackerFrame:SetAlpha() in SetQuestTrackerCollapsed." },
        { type = "FIX",     text = "Upgraded Dynamic Emergency FPS Guard and Dynamic SpellQueueWindow sub-drawers to full-width 24px horizontal chevron toggle bars inside unified outer bordered group cards per DESIGN_SYSTEM.md Section 2.6." },
        { type = "FIX",     text = "Fixed tab scroll jumping by preserving vertical scroll offset in SelectTab and updating controls in-place without full-tab resets." },
        { type = "UI",      text = "Enclosed all L-bracket section headers and subsection setting cards across Zone Graphics and FPS Guard tabs inside outer backdrop border frames with dynamic sub-drawer reflow." },
        { type = "FEATURE", text = "Unified 7-Tab Recessed Top Bevel Track enclosing all 6 Zone tabs (Outdoor, Cities, Delves, Dungeons, Raid, PvP) plus [FPS Guard & Queue]." },
        { type = "FEATURE", text = "1-Click Hardware Tier Presets per zone (Low-End PC, Balanced, Competitive FPS, High-End Ultra) with zero UI reload required." },
        { type = "FEATURE", text = "Boss Telegraph Safety Lock hard-locks projected textures and essential ground swirlies ON across all instance presets." },
    },
}
_G.DynamicSuite.Changelogs["DynamicFPS"] = DynamicFPS.CHANGELOG
_G.DynamicSuite.Changelogs["fps"] = DynamicFPS.CHANGELOG

-- ============================================================================
-- 12. EVENT DISPATCH PIPELINE & SLASH COMMANDS (/dfps, /dynamicfps)
-- ============================================================================
local evtFrame = CreateFrame("Frame", "DynamicFPSEventFrame", UIParent)
evtFrame:RegisterEvent("ADDON_LOADED")
evtFrame:RegisterEvent("PLAYER_LOGIN")
evtFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
evtFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
evtFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
evtFrame:RegisterEvent("CHALLENGE_MODE_START")
evtFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
evtFrame:RegisterEvent("CHALLENGE_MODE_RESET")
evtFrame:RegisterEvent("ENCOUNTER_START")
evtFrame:RegisterEvent("ENCOUNTER_END")
evtFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
evtFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
evtFrame:RegisterEvent("PLAYER_LOGOUT")
evtFrame:RegisterEvent("CVAR_UPDATE")

local CVAR_SYNC_MAP = {
    graphicsShadowQuality      = { field = "shadowQuality",     min = 0, max = 4 },
    graphicsLiquidDetail       = { field = "liquidDetail",      min = 0, max = 3 },
    graphicsParticleDensity    = { field = "particleDensity",   kind = "particle" },
    graphicsSSAO               = { field = "ssao",              min = 0, max = 4 },
    graphicsDepthEffects       = { field = "depthEffects",      min = 0, max = 3 },
    graphicsComputeEffects     = { field = "computeEffects",    min = 0, max = 4 },
    graphicsOutlineMode        = { field = "outlineMode",       min = 0, max = 2 },
    graphicsTextureResolution  = { field = "textureResolution", min = 0, max = 2 },
    graphicsSpellDensity       = { field = "spellDensity",      kind = "spell" },
    graphicsViewDistance       = { field = "viewDistance",      kind = "slider" },
    graphicsEnvironmentDetail  = { field = "environmentDetail", kind = "slider" },
    graphicsGroundClutter      = { field = "groundClutter",     kind = "slider" },
}

local function SyncActiveZoneFromExternalCVar(cvarName, cvarVal)
    if isApplyingGraphicsCVars or not (DynamicFPSDB and DynamicFPSDB.enabled) then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local spec = CVAR_SYNC_MAP[cvarName]
    if not spec then return end
    local activeZone = GetCurrentZoneContext()
    local z = DynamicFPSDB.zones and DynamicFPSDB.zones[activeZone]
    if type(z) ~= "table" then return end

    local raw = cvarVal ~= nil and not _IsSecret(cvarVal) and cvarVal or SafeGetCVar(cvarName, nil)
    if raw == nil or _IsSecret(raw) then return end

    if spec.kind == "slider" then
        local n = _SafeNumber(raw, nil)
        if n ~= nil then
            z[spec.field] = math.max(1, math.min(10, math.floor(n + 0.5) + 1))
        end
    elseif spec.kind == "particle" then
        local lbl = ResolveSettingLabelFromValue(cvarName, raw)
        local mapped = nil
        if lbl then
            local lowLbl = string.lower(lbl)
            for idx, name in pairs(PARTICLE_LABELS) do
                if string.lower(name) == lowLbl then mapped = idx break end
            end
        end
        if not mapped then
            local n = _SafeNumber(raw, nil)
            if n ~= nil then mapped = math.max(1, math.min(5, math.floor(n + 0.5) + 1)) end
        end
        if mapped then z[spec.field] = mapped end
    elseif spec.kind == "spell" then
        local lbl = ResolveSettingLabelFromValue(cvarName, raw)
        if lbl then
            z[spec.field] = NormalizeSpellDensityToken(lbl)
        else
            z[spec.field] = NormalizeSpellDensityToken(raw)
        end
    else
        local n = _SafeNumber(raw, nil)
        if n ~= nil then
            z[spec.field] = math.max(spec.min, math.min(spec.max, math.floor(n + 0.5)))
        end
    end

    if DynamicFPS.RefreshWorkspaceUI then
        DynamicFPS.RefreshWorkspaceUI()
    end
end

local sqPeriodicTicker = nil
local function EnsureSpellQueuePeriodicTicker()
    if sqPeriodicTicker or not C_Timer or not C_Timer.NewTicker then return end
    sqPeriodicTicker = C_Timer.NewTicker(15, function()
        if not IsInRestrictedCombatOrKey() then
            ApplySpellQueueWindow(false)
        end
    end)
end

evtFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "CVAR_UPDATE" then
        SyncActiveZoneFromExternalCVar(arg1, arg2)
        return
    end
    if event == "ADDON_LOADED" then
        if (arg1 == ADDON_FOLDER or arg1 == "DynamicFPS") and not isInitialized then
            isInitialized = true
            EnsureDBInitialized()
            _G.DynamicSuite.modules["fps"] = moduleEntry
            _G.DynamicSuite.modules["DynamicFPS"] = moduleEntry
            if _G.DynamicSuite and type(_G.DynamicSuite.RegisterModule) == "function" then
                pcall(_G.DynamicSuite.RegisterModule, _G.DynamicSuite, "fps", moduleEntry)
            end
            if IsModuleDisabledInSuite("DynamicFPS") then
                moduleEntry._disabledAtStartup = true
                evtFrame:UnregisterAllEvents()
                return
            end
        end

    elseif event == "PLAYER_LOGIN" then
        EnsureDBInitialized()
        _G.DynamicSuite = _G.DynamicSuite or {}
        _G.DynamicSuite.modules = _G.DynamicSuite.modules or {}
        _G.DynamicSuite.modules["fps"] = moduleEntry
        _G.DynamicSuite.modules["DynamicFPS"] = moduleEntry
        if _G.DynamicSuite and type(_G.DynamicSuite.RegisterModule) == "function" then
            pcall(_G.DynamicSuite.RegisterModule, _G.DynamicSuite, "fps", moduleEntry)
        end
        if IsModuleDisabledInSuite("DynamicFPS") then
            moduleEntry._disabledAtStartup = true
            evtFrame:UnregisterAllEvents()
            return
        end
        CaptureBaselineCVars()
        EnforceProjectedTexturesLock()
        if DynamicFPSDB._governorDirty then
            DynamicFPSDB._governorDirty = false
            ApplyZoneGraphicsConfig(GetCurrentZoneContext(), true)
        else
            ApplyZoneGraphicsConfig(GetCurrentZoneContext(), false)
        end
        ApplySpellQueueWindow(true)
        ApplyDeclutterAudioSetting()
        EvaluateCombatLogAutoPurge()
        EnsureSpellQueuePeriodicTicker()

    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        EnforceProjectedTexturesLock()
        currentZoneContext = GetCurrentZoneContext()
        ApplyZoneGraphicsConfig(currentZoneContext, false)
        ApplySpellQueueWindow(false)
        if event == "PLAYER_ENTERING_WORLD" and C_Timer and C_Timer.After then
            C_Timer.After(0.2, function()
                local getGranular = _G.DynamicSuite and _G.DynamicSuite.GetGranularConflictMode
                local yieldSQ = type(getGranular) == "function"
                    and (getGranular("DynamicFPS", "EnhanceQoL") == "YIELD_TO_EXTERNAL" or getGranular("DynamicFPS", "Leatrix_Plus") == "YIELD_TO_EXTERNAL")
                if not yieldSQ and not IsInRestrictedCombatOrKey() then
                    ApplySpellQueueWindow(false)
                end
            end)
        end
        EvaluateCombatLogAutoPurge()
        EvaluateQuestTrackerDeclutter(false, InCombatLockdown and InCombatLockdown())

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if not arg1 or arg1 == "player" then
            ApplySpellQueueWindow(false)
            if DynamicFPS.RefreshGuardTelemetry then
                pcall(DynamicFPS.RefreshGuardTelemetry)
            end
        end

    elseif event == "CHALLENGE_MODE_START" then
        EnforceProjectedTexturesLock()
        ApplyZoneGraphicsConfig("DUNGEONS", false)
        EvaluateCombatLogAutoPurge()
        EvaluateQuestTrackerDeclutter(true, InCombatLockdown and InCombatLockdown())

    elseif event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
        EvaluateCombatLogAutoPurge()
        EvaluateQuestTrackerDeclutter(false, InCombatLockdown and InCombatLockdown())
        ApplySpellQueueWindow(false)

    elseif event == "ENCOUNTER_START" then
        EvaluateQuestTrackerDeclutter(true, true)

    elseif event == "ENCOUNTER_END" then
        EvaluateQuestTrackerDeclutter(false, InCombatLockdown and InCombatLockdown())
        ApplySpellQueueWindow(false)

    elseif event == "PLAYER_REGEN_DISABLED" then
        StartCombatFPSGovernor()
        EvaluateQuestTrackerDeclutter(false, true)

    elseif event == "PLAYER_REGEN_ENABLED" then
        StopCombatFPSGovernor()
        if pendingOutOfCombatGraphics then
            pendingOutOfCombatGraphics = false
            ApplyZoneGraphicsConfig(GetCurrentZoneContext(), false)
        end
        EvaluateQuestTrackerDeclutter(false, false)
        ApplySpellQueueWindow(false)

    elseif event == "PLAYER_LOGOUT" then
        RestoreBaselineCVarsOnly()
    end
end)

SLASH_DYNAMICFPS1 = "/dfps"
SLASH_DYNAMICFPS2 = "/dynamicfps"

SlashCmdList["DYNAMICFPS"] = function(msg)
    EnsureDBInitialized()
    local cmd = (msg or ""):match("^%s*(%S*)")
    cmd = (cmd or ""):lower()

    if cmd == "status" then
        print(ADDON_TITLE_COLORED .. ": " .. GetStatusText())
    elseif cmd == "restore" then
        RestoreBaselineGraphics()
    elseif cmd == "reset" then
        ResetFPSModuleDefaults()
    elseif cmd == "apply" or cmd == "tune" then
        ApplyZoneGraphicsConfig(GetCurrentZoneContext(), true)
        local sqMS, wMS = ApplySpellQueueWindow()
        print(string.format("%s: Applied zone graphics and tuned SpellQueueWindow to %d ms (World Ping: %d ms).", ADDON_TITLE_COLORED, sqMS, wMS))
    else
        if _G.DynamicSuite and type(_G.DynamicSuite.OpenModule) == "function" then
            _G.DynamicSuite:OpenModule("DynamicFPS")
        else
            OpenFPSWorkspace()
        end
    end
end

function _G.DynamicFPS_OnAddonCompartmentClick()
    if _G.DynamicSuite and type(_G.DynamicSuite.OpenModule) == "function" then
        _G.DynamicSuite:OpenModule("DynamicFPS")
    else
        OpenFPSWorkspace()
    end
end
