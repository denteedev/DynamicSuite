--[[
    DynamicSuite / DynamicLoad - DynamicLoad.lua
    Context-Aware Addon Profile Management Engine & Workspace for World of Warcraft (Retail 12.1.5+)
    Single-file dual-mode architecture: runs inside DynamicSuite\Modules\ or standalone DynamicLoad.
]]

local addonName, rawAddonTable = ...
local ADDON_FOLDER = (type(addonName) == "string" and addonName ~= "") and addonName or "DynamicSuite"

local function ResolveAddonVersion(folderName, fallback)
    local fb = fallback or "2.1.2"
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
            local suiteVer = globalTbl._loadedVersion or globalTbl.ADDON_VERSION or globalTbl.version or (_G.DynamicSuite and _G.DynamicSuite.version) or "2.1.2"
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
            local stLoadedVer = globalTbl._loadedVersion or globalTbl.ADDON_VERSION or globalTbl.version or "0.0.0"
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

local RESOLVED_ADDON_VERSION = ResolveAddonVersion(ADDON_FOLDER, "2.1.2")

-- Guard E: Version-aware duplicate-install guard if standalone DynamicLoad is installed alongside bundled DynamicSuite
if ShouldYieldToOtherInstall(ADDON_FOLDER, "DynamicLoad", RESOLVED_ADDON_VERSION, _G.DynamicLoad) then
    return
end

_G.DynamicSuite = _G.DynamicSuite or {}
local DynamicSuite = _G.DynamicSuite
DynamicSuite._sharedAddonTable = DynamicSuite._sharedAddonTable or rawAddonTable or {}
local sharedSuiteTable = DynamicSuite._sharedAddonTable

-- Guard A: Private per-module namespace bridged safely to DynamicSuite._sharedAddonTable without overwriting Hub keys
local HUB_OWNED_KEYS = {
    CHANGELOG = true,
    ADDON_VERSION = true,
    UI = true,
    ShowConfigUI = true,
    HideConfigUI = true,
    ToggleConfigUI = true,
    ToggleUI = true,
    CreateMainConfigUI = true,
    ResetDynamicSuite = true,
}

local DL_NS = setmetatable({}, {
    __index = sharedSuiteTable,
    __newindex = function(t, k, v)
        rawset(t, k, v)
        if not (DynamicSuite._isHubLoaded and HUB_OWNED_KEYS[k]) then
            sharedSuiteTable[k] = v
        end
    end,
})

_G.DynamicLoad = _G.DynamicLoad or DL_NS
_G.DynamicLoad._loadedBySuite = (ADDON_FOLDER == "DynamicSuite")
_G.DynamicLoad._loadedVersion = RESOLVED_ADDON_VERSION

local isInitialized = false

local function IsStandaloneMarkerExcludedBySuite(addonKey)
    if type(addonKey) ~= "string" then return false end
    if addonKey ~= "DynamicMarker" and addonKey:lower() ~= "dynamicmarker" then return false end
    if ADDON_FOLDER == "DynamicSuite" then return true end
    if DynamicSuite and DynamicSuite._isHubLoaded then return true end
    if _G.DynamicSuite and _G.DynamicSuite._isHubLoaded then return true end
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" and C_AddOns.IsAddOnLoaded("DynamicSuite") then return true end
    if C_AddOns and type(C_AddOns.GetAddOnEnableState) == "function" then
        local uName = type(_G.UnitName) == "function" and _G.UnitName("player") or nil
        if type(uName) == "string" and uName ~= "" and uName ~= "Unknown" and uName ~= _G.UNKNOWNOBJECT then
            local okSt, st = pcall(C_AddOns.GetAddOnEnableState, "DynamicSuite", uName)
            if okSt and type(st) == "number" and st > 0 then return true end
        end
        local okSt2, st2 = pcall(C_AddOns.GetAddOnEnableState, "DynamicSuite")
        if okSt2 and type(st2) == "number" and st2 > 0 then return true end
        local uGuid = type(_G.UnitGUID) == "function" and _G.UnitGUID("player") or nil
        if type(uGuid) == "string" and uGuid ~= "" then
            local okSt3, st3 = pcall(C_AddOns.GetAddOnEnableState, "DynamicSuite", uGuid)
            if okSt3 and type(st3) == "number" and st3 > 0 then return true end
        end
    end
    return false
end
DL_NS.IsStandaloneMarkerExcludedBySuite = IsStandaloneMarkerExcludedBySuite
DynamicSuite.IsStandaloneMarkerExcludedBySuite = IsStandaloneMarkerExcludedBySuite

--------------------------------------------------------------------------------
-- SECTION 1: CORE ENGINE (DynamicLoad Core)
--------------------------------------------------------------------------------
do
--[[
    DynamicLoad - DynamicLoad_Core.lua
    Context-Aware Addon Profile Management Engine for World of Warcraft (Retail 12.1.5+)
    Works 100% standalone or docked inside DynamicSuite Hub.
]]

local addonTable = DL_NS
addonTable.IsDynamicLoadModuleLoaded = true

local ADDON_TITLE = "|cFFCBD5E1DynamicLoad|r"
local ADDON_VERSION = RESOLVED_ADDON_VERSION
addonTable.ADDON_VERSION = ADDON_VERSION
DynamicSuite.version = DynamicSuite.version or ADDON_VERSION
DynamicSuite.modules = DynamicSuite.modules or {}
DynamicSuite.Changelogs = DynamicSuite.Changelogs or {}

DynamicSuite.Changelogs["DynamicLoad"] = {
    version = ADDON_VERSION,
    date = "12/11/2026",
    entries = {
        { type = "FIX",     text = "Universal 'Never' ('FROZEN') Persistence Across All Addons & Sub-Addons (12/11/2026): Normalised all security and zone assignment operations to canonical folder names (ResolveCanonicalAddonName); made SetAddonFrozen(name, true) atomically persist 'FROZEN' across DynamicLoadDB/globalData/charData, wipe all 5 zone tables, and call C_AddOns.DisableAddOn; merged DynamicLoadDB root and globalData security tables in SyncScopeBindings() and used in-place wipe() in RestoreStash() so SavedVariables deserialization never reverts 'FROZEN' states on /reload; prevented ReconcileStartupProfileBaseline from overwriting knownAddons; protected individual child 'FROZEN' / 'LOCKED' states from parent cascades; and added EnforceFrozenAddonsDisabled() + a hooksecurefunc(C_AddOns, 'EnableAddOn', ...) guard so external parent suites cannot re-enable 'FROZEN' sub-addons." },
        { type = "FIX",     text = "Fixed 'attempt to call a nil value' in EvaluateAddonItemEffectiveState (DynamicLoad.lua:4724) when evaluating the DynamicSuite parent hub item and child modules across scoped do ... end chunks by declaring a local IsSuiteModuleExplicitlyDisabled helper in the UI chunk with addonTable / DynamicSuiteDB fallbacks and defensive nil guards across GetParentSuiteStats and EvaluateAddonItemEffectiveState." },
        { type = "FEATURE", text = "External Addon Conflict Detector & Yield Engine (12/11/2026): Added curated conflict detection for ACP, SimpleAddonManager, and BetterAddonList, one-time non-spam login alerts for newly detected HARD conflicts, and /ds conflicts diagnostic reporting." },
        { type = "NEW",     text = "Unified v1.3.0 Single-Source .toc Metadata & Version-Aware Duplicate-Install Guard (11/11/2026): DynamicLoad now resolves its live version directly from .toc metadata (C_AddOns.GetAddOnMetadata) and compares semantic versions (CompareSemVer) when both DynamicSuite and standalone DynamicLoad are installed so the newer version always takes priority." },
        { type = "NEW",     text = "Consolidated DynamicLoad_Core.lua and DynamicLoad_UI.lua into a single dual-mode Modules\\DynamicLoad.lua with scoped do ... end chunks, private DL_NS namespace, dynamic ADDON_FOLDER asset paths, and [Suite Core] tree presentation for all 8 bundled DynamicSuite modules." },
        { type = "FIX",     text = "Separated DynamicLoadDB.loadedProfile (live loaded session profile) from DynamicLoadDB.stagedProfile (profile staged via EnableAddOn/DisableAddOn for the next /reload) so the Green Loaded dot stays on the active session profile (e.g. Raid) when zoning into a City Hub with unapplied addon changes, and updated CommitPendingProfileBeforeReload() to re-evaluate the physical zone profile before /reload so zoning out of a Raid into a City and typing /reload loads Outdoor addons cleanly." },
        { type = "FIX",     text = "Preserved DynamicSuite Hub functions and CHANGELOG when DynamicLoad_Core.lua loads after DynamicSuite_Core.lua, and guarded GetPlayer() against Unknown / UNKNOWNOBJECT before PLAYER_LOGIN." },
        { type = "FIX",     text = "Hardened loading-screen Toast state with a 15s safety timeout, cleared isInsideLoadingScreen across PLAYER_ENTERING_WORLD / ZONE_CHANGED* / PLAYER_REGEN_DISABLED, and replaced UIFrameFadeOut / UIFrameFadeIn with a taint-free AnimationGroup pulse." },
        { type = "PERF",    text = "Eliminated temporary table allocations in CalculateAddonDelta, ApplyFontRecursively, and OpenAltDropdown, and added OnHide / mouse-button guards to standalone scrollbars." },
        { type = "FIX",     text = "Labyrinth Delve Toast Anti-Spam Gate: Restricted automatic DynamicLoadToastFrame popups strictly to real post-loading-screen transitions (LOADING_SCREEN_ENABLED / LOADING_SCREEN_DISABLED + PLAYER_ENTERING_WORLD with a deduplicated 0.65s settle timer and per-load session latch), preventing seamless chamber crossings (ZONE_CHANGED_NEW_AREA, ZONE_CHANGED, ZONE_CHANGED_INDOORS, SCENARIO_UPDATE) or post-combat PLAYER_REGEN_ENABLED flushes from re-popping dismissed Toasts inside Labyrinth Delves." },
        { type = "FIX",     text = "Cross-TOC Namespace Bridge & Lua 5.1 AST Hardening: Fixed syntax error in DynamicLoad_Core.lua:2178, forward-declared ApplyEnvironmentContext above ResumeAutoSwitch, added DynamicSuite to SUITE_MODULES auto-enable protection, and hardened /dl standalone vs docked workspace routing." },
        { type = "FEATURE", text = "Decoupled DynamicLoad Peer Module: DynamicLoad now operates as an independent peer module (with its own DynamicLoad_Core.lua and DynamicLoad_UI.lua) that works 100% standalone via /dl or docked inside DynamicSuite (/ds)." },
        { type = "UI",      text = "Unified load-state terminology to 'By Zone', 'Always', and 'Never' across all rows, suffix tags, popovers, filter pills, legends, and tooltips (with [Suite Core] / [Suite Protected] for DynamicSuite modules)." },
        { type = "UI",      text = "Styled Top Filter Bar pills (All, Pending, Always, Never) with clash-proof semantic text coloring on dark #14171F backgrounds when unselected, and filled semantic backgrounds with white text when selected." },
        { type = "FIX",     text = "Disentangled physical zone location from loaded addon profile (DynamicLoadDB.loadedProfile and DynamicLoadDB.manualOverride), protecting manual profile activations across reloads." },
    },
}
DynamicSuite.Changelogs["load"] = DynamicSuite.Changelogs["DynamicLoad"]
if not DynamicSuite._isHubLoaded then
    addonTable.CHANGELOG = DynamicSuite.Changelogs["DynamicLoad"].entries
end
_G.DynamicLoad = _G.DynamicLoad or addonTable
_G.DynamicLoad.CHANGELOG = DynamicSuite.Changelogs["DynamicLoad"].entries

local PROTECTED_ADDONS = addonTable.PROTECTED_ADDONS or {
    ["DynamicSuite"]  = true,
    ["DynamicLoad"]   = true,
}
local CORE_SUITE_ADDONS = addonTable.CORE_SUITE_ADDONS or {
    ["DynamicSuite"]  = true,
    ["DynamicLoad"]   = true,
    ["DynamicMarker"] = true,
    ["DynamicZoom"]   = true,
    ["DynamicFPS"]    = true,
    ["DynamicPrep"]   = true,
    ["DynamicGroup"]  = true,
    ["DynamicBags"]   = true,
    ["DynamicChat"]   = true,
}
local SUITE_MODULES = addonTable.SUITE_MODULES or {
    "DynamicSuite",
    "DynamicLoad",
    "DynamicMarker",
    "DynamicZoom",
    "DynamicFPS",
    "DynamicPrep",
    "DynamicGroup",
    "DynamicBags",
    "DynamicChat",
}
addonTable.PROTECTED_ADDONS  = PROTECTED_ADDONS
addonTable.CORE_SUITE_ADDONS = CORE_SUITE_ADDONS
addonTable.SUITE_MODULES     = SUITE_MODULES

local RETIRED_IGNORED_ADDONS = addonTable.RETIRED_IGNORED_ADDONS or {
    ["DynamicFrame"] = true,
}

local CONTEXT_OUTDOOR = "outdoor"
local CONTEXT_DELVE   = "delve"
local CONTEXT_DUNGEON = "dungeon"
local CONTEXT_RAID    = "raid"
local CONTEXT_PVP     = "pvp"

local CONTEXT_LABELS = addonTable.CONTEXT_LABELS or {
    [CONTEXT_OUTDOOR] = "Outdoor",
    [CONTEXT_DELVE]   = "Delves",
    [CONTEXT_DUNGEON] = "Dungeons",
    [CONTEXT_RAID]    = "Raid",
    [CONTEXT_PVP]     = "PvP",
}
addonTable.CONTEXT_LABELS = CONTEXT_LABELS

local DEFAULT_SUITE_GLOBAL = addonTable.DEFAULT_SUITE_GLOBAL or {
    windowWidth      = 1040,
    windowHeight     = 680,
    windowScale      = 1.0,
    windowAlpha      = 0.98,
    accentKey        = "AUTO_CLASS",
    customAccent     = nil,
    surfaceTheme     = "MIDNIGHT_BLACK",
    fontKey          = "EXPRESSWAY",
    fontFamily       = "EXPRESSWAY",
    pillFillAlpha    = 0.42,
    syncThemeToToast = true,
    recentColors     = {},
    toastPos         = { point = "TOP", relPoint = "TOP", x = 0, y = -50 },
    toastDisplayMode = "DETAILED",
    toastScale       = 1.0,
    toastAlpha       = 0.96,
    toastDuration    = 8,
    hudSnapMode      = "MAGNET",
    minimizedBarPos  = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
    editModeModalPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
    disabledModules  = {},
    yieldHooks       = {},
    guidedSetupDone  = false,
    showGameMenuSuiteBtn     = true,
    showGameMenuHudBtn       = true,
    replaceBlizzardAddonList = true,
    v120_windowWidth1040 = true,
}
if not DynamicSuite._isHubLoaded or not addonTable.DEFAULT_SUITE_GLOBAL then
    addonTable.DEFAULT_SUITE_GLOBAL = DEFAULT_SUITE_GLOBAL
end
-- Default DynamicLoad SavedVariables
local DEFAULT_DB = {
    version = 4,
    firstRun = true,
    v120_windowWidth1040 = true,
    loadedProfile = CONTEXT_OUTDOOR,
    manualOverride = false,
    activeProfile = CONTEXT_OUTDOOR,
    autoSwitch = true,
    silentOnMatch = true,
    toastDuration = 8,
    toastScale = 1.0,
    toastAlpha = 0.96,
    toastDisplayMode = "DETAILED",
    toastPos = { point = "TOP", relPoint = "TOP", x = 0, y = -50 },
    windowWidth = 1040,
    windowHeight = 680,
    windowScale = 1.0,
    windowAlpha = 0.98,
    surfaceTheme = "MIDNIGHT_BLACK",
    accentKey = "AUTO_CLASS",
    customAccent = nil,
    fontKey = "EXPRESSWAY",
    fontFamily = "EXPRESSWAY",
    pillFillAlpha = 0.42,
    recentColors = {},
    lockedAddons = {}, -- [addonName] = true
    frozenAddons = {}, -- [addonName] = true (Never Load / Cold Storage)
    addonStates  = {}, -- [addonName] = "LOCKED" | "FROZEN" | "NORMAL"
    knownAddons  = {}, -- [addonName] = true (Tracks installed addons to detect new ones)
    characters   = {}, -- [charKey] = { name, realm, class, addons = {}, lastSeen }
    stash        = nil, -- 1-Click debug/troubleshoot stash
    parentCascaded = {},
    collapsedParents = {}, -- [parentKey] = true when collapsed
    profiles = {
        [CONTEXT_OUTDOOR] = { name = "Outdoor",  addons = {} },
        [CONTEXT_DELVE]   = { name = "Delves",   addons = {} },
        [CONTEXT_DUNGEON] = { name = "Dungeons", addons = {} },
        [CONTEXT_RAID]    = { name = "Raid",     addons = {} },
        [CONTEXT_PVP]     = { name = "PvP",      addons = {} },
    },
    rules = {
        ["outdoor"]  = CONTEXT_OUTDOOR,
        ["party"]    = CONTEXT_DUNGEON,
        ["raid"]     = CONTEXT_RAID,
        ["delve"]    = CONTEXT_DELVE,
        ["scenario"] = CONTEXT_DELVE,
        ["arena"]    = CONTEXT_PVP,
        ["pvp"]      = CONTEXT_PVP,
    }
}
addonTable.DEFAULT_DB = DEFAULT_DB

local eventFrame = CreateFrame("Frame", "DynamicLoadEventFrame", UIParent)
addonTable.eventFrame = eventFrame

local pendingProfile = nil
local pendingToastAfterCombat = false
local hasShownToastThisLoadSession = false
local isInsideLoadingScreen = false
local loadingScreenSafetyTimer = nil
local pendingPostLoadToast = false
local debounceTimer = nil
local playerName = nil

--------------------------------------------------------------------------------
-- Account-Wide Global Sync Helpers (DynamicSuiteDB.global)
--------------------------------------------------------------------------------
local function GetPlayer()
    if not playerName then
        local raw = UnitName and UnitName("player")
        if raw and raw ~= "" and raw ~= "Unknown" and raw ~= _G.UNKNOWNOBJECT then
            playerName = raw
        end
    end
    return playerName or "player"
end
if not DynamicSuite._isHubLoaded or not addonTable.GetPlayer then
    addonTable.GetPlayer = GetPlayer
end

local function GetCurrentCharKey()
    local pName = (addonTable.GetPlayer and addonTable.GetPlayer()) or GetPlayer()
    local realm = GetRealmName() or "Realm"
    return pName .. "-" .. realm
end
if not DynamicSuite._isHubLoaded or not addonTable.GetCurrentCharKey then
    addonTable.GetCurrentCharKey = GetCurrentCharKey
end

local function GetCharScopeMode()
    if not DynamicLoadDB or not DynamicLoadDB.charScopeMode then
        return "GLOBAL"
    end
    local charKey = (addonTable.GetCurrentCharKey and addonTable.GetCurrentCharKey()) or GetCurrentCharKey()
    return (DynamicLoadDB.charScopeMode[charKey] == "CHARACTER") and "CHARACTER" or "GLOBAL"
end
if not DynamicSuite._isHubLoaded or not addonTable.GetCharScopeMode then
    addonTable.GetCharScopeMode = GetCharScopeMode
end

local function EnsureSuiteGlobal()
    if not _G.DynamicSuiteDB then
        _G.DynamicSuiteDB = {}
    end
    if not _G.DynamicSuiteDB.global then
        _G.DynamicSuiteDB.global = CopyTable(DEFAULT_SUITE_GLOBAL)
    else
        for k, v in pairs(DEFAULT_SUITE_GLOBAL) do
            if _G.DynamicSuiteDB.global[k] == nil then
                if type(v) == "table" then
                    _G.DynamicSuiteDB.global[k] = CopyTable(v)
                else
                    _G.DynamicSuiteDB.global[k] = v
                end
            end
        end
    end
    if GetCharScopeMode() == "CHARACTER" and DynamicLoadDB and DynamicLoadDB.charData then
        local charKey = GetCurrentCharKey()
        local cd = DynamicLoadDB.charData[charKey]
        if cd and cd.theme then
            for k, v in pairs(DEFAULT_SUITE_GLOBAL) do
                if cd.theme[k] == nil then
                    if type(v) == "table" then
                        cd.theme[k] = CopyTable(v)
                    else
                        cd.theme[k] = v
                    end
                end
            end
            return cd.theme
        end
    end
    return _G.DynamicSuiteDB.global
end
if not (DynamicSuite and DynamicSuite._isHubLoaded) or not addonTable.GetSuiteGlobal then
    addonTable.GetSuiteGlobal = EnsureSuiteGlobal
end

local ALL_ZONE_CONTEXTS = { CONTEXT_OUTDOOR, CONTEXT_DELVE, CONTEXT_DUNGEON, CONTEXT_RAID, CONTEXT_PVP }

local function ResolveCanonicalAddonName(nameOrIndex)
    if not nameOrIndex then return nil end
    if C_AddOns and type(C_AddOns.GetAddOnInfo) == "function" then
        local ok, folderName = pcall(C_AddOns.GetAddOnInfo, nameOrIndex)
        if ok and type(folderName) == "string" and folderName ~= "" then
            return folderName
        end
    end
    if type(nameOrIndex) == "string" and nameOrIndex ~= "" then
        return nameOrIndex
    end
    return nil
end
addonTable.ResolveCanonicalAddonName = ResolveCanonicalAddonName
DynamicSuite.ResolveCanonicalAddonName = ResolveCanonicalAddonName

local function WipeAddonFromProfilesTable(profilesTbl, canonName)
    if type(profilesTbl) ~= "table" or not canonName then return end
    for _, ctx in ipairs(ALL_ZONE_CONTEXTS) do
        local prof = profilesTbl[ctx]
        if type(prof) == "table" and type(prof.addons) == "table" then
            prof.addons[canonName] = nil
        end
    end
    for _, prof in pairs(profilesTbl) do
        if type(prof) == "table" and type(prof.addons) == "table" then
            prof.addons[canonName] = nil
        end
    end
end

local function MergeSecurityTablesIntoTarget(srcStates, srcFrozen, srcLocked, dstStates, dstFrozen, dstLocked, dstProfiles)
    if type(dstStates) ~= "table" or type(dstFrozen) ~= "table" or type(dstLocked) ~= "table" then return end
    if type(srcStates) == "table" then
        for rawKey, st in pairs(srcStates) do
            local k = ResolveCanonicalAddonName(rawKey) or rawKey
            if st == "FROZEN" then
                dstStates[k]  = "FROZEN"
                dstFrozen[k]  = true
                dstLocked[k]  = nil
                WipeAddonFromProfilesTable(dstProfiles, k)
            elseif st == "LOCKED" then
                dstStates[k]  = "LOCKED"
                dstLocked[k]  = true
                dstFrozen[k]  = nil
            elseif st == "NORMAL" then
                dstStates[k]  = "NORMAL"
                dstFrozen[k]  = nil
                dstLocked[k]  = nil
            end
        end
    end
    if type(srcFrozen) == "table" then
        for rawKey, v in pairs(srcFrozen) do
            if v then
                local k = ResolveCanonicalAddonName(rawKey) or rawKey
                dstFrozen[k] = true
                dstLocked[k] = nil
                dstStates[k] = "FROZEN"
                WipeAddonFromProfilesTable(dstProfiles, k)
            end
        end
    end
    if type(srcLocked) == "table" then
        for rawKey, v in pairs(srcLocked) do
            local k = ResolveCanonicalAddonName(rawKey) or rawKey
            if v and not dstFrozen[k] then
                dstLocked[k] = true
                dstStates[k] = "LOCKED"
            end
        end
    end
end

local CORE_ALWAYS_ADDONS = { "DynamicSuite", "DynamicLoad" }
local function PurgeCoreSuiteStateFromTableSet(tbl)
    if type(tbl) ~= "table" then return end
    for _, coreName in ipairs(CORE_ALWAYS_ADDONS) do
        if type(tbl.frozenAddons) == "table" then tbl.frozenAddons[coreName] = nil end
        if type(tbl.lockedAddons) == "table" then tbl.lockedAddons[coreName] = nil end
        if type(tbl.addonStates) == "table" then tbl.addonStates[coreName] = nil end
        if type(tbl.profiles) == "table" then
            for _, ctx in ipairs(ALL_ZONE_CONTEXTS) do
                local prof = tbl.profiles[ctx]
                if type(prof) == "table" and type(prof.addons) == "table" then
                    prof.addons[coreName] = true
                end
            end
        end
    end
    if IsStandaloneMarkerExcludedBySuite("DynamicMarker") then
        if type(tbl.lockedAddons) == "table" then tbl.lockedAddons["DynamicMarker"] = nil end
        if type(tbl.addonStates) == "table" and tbl.addonStates["DynamicMarker"] == "LOCKED" then
            tbl.addonStates["DynamicMarker"] = nil
        end
        if type(tbl.profiles) == "table" then
            for _, ctx in ipairs(ALL_ZONE_CONTEXTS) do
                local prof = tbl.profiles[ctx]
                if type(prof) == "table" and type(prof.addons) == "table" then
                    prof.addons["DynamicMarker"] = false
                end
            end
            for _, prof in pairs(tbl.profiles) do
                if type(prof) == "table" and type(prof.addons) == "table" then
                    prof.addons["DynamicMarker"] = false
                end
            end
        end
    end
end

local function SyncScopeBindings()
    if not DynamicLoadDB then return end
    DynamicLoadDB.allowCoreOverride = nil
    DynamicLoadDB.charScopeMode = DynamicLoadDB.charScopeMode or {}
    DynamicLoadDB.charData = DynamicLoadDB.charData or {}

    if not DynamicLoadDB.globalData then
        DynamicLoadDB.globalData = {
            profiles     = DynamicLoadDB.profiles or CopyTable(DEFAULT_DB.profiles),
            lockedAddons = DynamicLoadDB.lockedAddons or {},
            frozenAddons = DynamicLoadDB.frozenAddons or {},
            addonStates  = DynamicLoadDB.addonStates or {},
        }
    else
        DynamicLoadDB.globalData.profiles     = DynamicLoadDB.globalData.profiles or DynamicLoadDB.profiles or CopyTable(DEFAULT_DB.profiles)
        DynamicLoadDB.globalData.lockedAddons = DynamicLoadDB.globalData.lockedAddons or {}
        DynamicLoadDB.globalData.frozenAddons = DynamicLoadDB.globalData.frozenAddons or {}
        DynamicLoadDB.globalData.addonStates  = DynamicLoadDB.globalData.addonStates or {}
    end

    local charKey = GetCurrentCharKey()
    if DynamicLoadDB.charScopeMode[charKey] == "CHARACTER" then
        if not DynamicLoadDB.charData[charKey] then
            DynamicLoadDB.charData[charKey] = {
                profiles     = CopyTable(DynamicLoadDB.globalData.profiles),
                lockedAddons = CopyTable(DynamicLoadDB.globalData.lockedAddons),
                frozenAddons = CopyTable(DynamicLoadDB.globalData.frozenAddons),
                addonStates  = CopyTable(DynamicLoadDB.globalData.addonStates),
                theme        = CopyTable(_G.DynamicSuiteDB and _G.DynamicSuiteDB.global or DEFAULT_SUITE_GLOBAL),
            }
        else
            DynamicLoadDB.charData[charKey].profiles     = DynamicLoadDB.charData[charKey].profiles or CopyTable(DynamicLoadDB.globalData.profiles)
            DynamicLoadDB.charData[charKey].lockedAddons = DynamicLoadDB.charData[charKey].lockedAddons or {}
            DynamicLoadDB.charData[charKey].frozenAddons = DynamicLoadDB.charData[charKey].frozenAddons or {}
            DynamicLoadDB.charData[charKey].addonStates  = DynamicLoadDB.charData[charKey].addonStates or {}
            if not DynamicLoadDB.charData[charKey].theme then
                DynamicLoadDB.charData[charKey].theme = CopyTable(_G.DynamicSuiteDB and _G.DynamicSuiteDB.global or DEFAULT_SUITE_GLOBAL)
            end
        end
        local cd = DynamicLoadDB.charData[charKey]
        if DynamicLoadDB.addonStates ~= cd.addonStates or DynamicLoadDB.frozenAddons ~= cd.frozenAddons or DynamicLoadDB.lockedAddons ~= cd.lockedAddons then
            if DynamicLoadDB.addonStates ~= DynamicLoadDB.globalData.addonStates then
                MergeSecurityTablesIntoTarget(DynamicLoadDB.addonStates, DynamicLoadDB.frozenAddons, DynamicLoadDB.lockedAddons, cd.addonStates, cd.frozenAddons, cd.lockedAddons, cd.profiles)
            end
        end
        DynamicLoadDB.profiles     = cd.profiles
        DynamicLoadDB.lockedAddons = cd.lockedAddons
        DynamicLoadDB.frozenAddons = cd.frozenAddons
        DynamicLoadDB.addonStates  = cd.addonStates
    else
        local gd = DynamicLoadDB.globalData
        if DynamicLoadDB.addonStates ~= gd.addonStates or DynamicLoadDB.frozenAddons ~= gd.frozenAddons or DynamicLoadDB.lockedAddons ~= gd.lockedAddons then
            MergeSecurityTablesIntoTarget(DynamicLoadDB.addonStates, DynamicLoadDB.frozenAddons, DynamicLoadDB.lockedAddons, gd.addonStates, gd.frozenAddons, gd.lockedAddons, gd.profiles)
        end
        DynamicLoadDB.profiles     = gd.profiles
        DynamicLoadDB.lockedAddons = gd.lockedAddons
        DynamicLoadDB.frozenAddons = gd.frozenAddons
        DynamicLoadDB.addonStates  = gd.addonStates
    end

    -- Self-Healing Startup Guard: unconditionally purge DynamicSuite & DynamicLoad
    -- from all frozen/locked/disabled tables so neither can ever get stuck in [Never].
    PurgeCoreSuiteStateFromTableSet(DynamicLoadDB)
    PurgeCoreSuiteStateFromTableSet(DynamicLoadDB.globalData)
    if type(DynamicLoadDB.charData) == "table" then
        for _, cd in pairs(DynamicLoadDB.charData) do
            PurgeCoreSuiteStateFromTableSet(cd)
        end
    end
    if _G.DynamicSuiteDB then
        for _, coreKey in ipairs({ "DynamicSuite", "DynamicLoad", "load" }) do
            if type(_G.DynamicSuiteDB.disabledModules) == "table" then
                _G.DynamicSuiteDB.disabledModules[coreKey] = nil
            end
            if type(_G.DynamicSuiteDB.global) == "table" and type(_G.DynamicSuiteDB.global.disabledModules) == "table" then
                _G.DynamicSuiteDB.global.disabledModules[coreKey] = nil
            end
        end
    end
end
addonTable.SyncScopeBindings = SyncScopeBindings

function addonTable.SetCharScopeMode(mode)
    if not DynamicLoadDB then return end
    DynamicLoadDB.charScopeMode = DynamicLoadDB.charScopeMode or {}
    local charKey = GetCurrentCharKey()
    DynamicLoadDB.charScopeMode[charKey] = (mode == "CHARACTER") and "CHARACTER" or "GLOBAL"
    SyncScopeBindings()
    if addonTable.SyncAddonStatesTable then addonTable.SyncAddonStatesTable() end
    local activeProf = DynamicLoadDB.activeProfile or CONTEXT_OUTDOOR
    if addonTable.StageAddonProfile then
        addonTable.StageAddonProfile(activeProf, false)
    end
end

local function IsAddonProtected(name)
    if not name then return false end
    local canon = ResolveCanonicalAddonName(name) or name
    if addonTable._pendingDisableCoreAddon == canon then
        return false
    end
    return (PROTECTED_ADDONS[canon] == true or PROTECTED_ADDONS[name] == true) and not RETIRED_IGNORED_ADDONS[canon]
end
addonTable.IsAddonProtected = IsAddonProtected

local function IsSuiteModuleExplicitlyDisabled(modName)
    if not modName or modName == "DynamicLoad" or modName == "DynamicSuite" or modName == "load" then return false end
    local shortKey = tostring(modName):gsub("^Dynamic", ""):lower()
    local canonMod = "Dynamic" .. shortKey:sub(1, 1):upper() .. shortKey:sub(2)
    if shortKey == "fps" then canonMod = "DynamicFPS" end
    if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.disabledModules) == "table" then
        if _G.DynamicSuiteDB.disabledModules[modName] == true
            or _G.DynamicSuiteDB.disabledModules[canonMod] == true
            or _G.DynamicSuiteDB.disabledModules[shortKey] == true then
            return true
        end
    end
    if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.global) == "table" and type(_G.DynamicSuiteDB.global.disabledModules) == "table" then
        if _G.DynamicSuiteDB.global.disabledModules[modName] == true
            or _G.DynamicSuiteDB.global.disabledModules[canonMod] == true
            or _G.DynamicSuiteDB.global.disabledModules[shortKey] == true then
            return true
        end
    end
    return false
end
addonTable.IsSuiteModuleExplicitlyDisabled = IsSuiteModuleExplicitlyDisabled

local function EnforceProtectedSuiteModules()
    if DynamicLoadDB and not DynamicLoadDB._v170_granularSuiteProtection then
        DynamicLoadDB._v170_granularSuiteProtection = true
        for _, modName in ipairs(SUITE_MODULES) do
            if not PROTECTED_ADDONS[modName] then
                if DynamicLoadDB.lockedAddons then DynamicLoadDB.lockedAddons[modName] = nil end
                if DynamicLoadDB.addonStates and DynamicLoadDB.addonStates[modName] == "LOCKED" then
                    DynamicLoadDB.addonStates[modName] = nil
                end
            end
        end
    end
    local pName = GetPlayer()
    if IsStandaloneMarkerExcludedBySuite("DynamicMarker") then
        local wasMarkerEnabled = false
        if C_AddOns and C_AddOns.GetAddOnEnableState then
            local okSt, st = pcall(C_AddOns.GetAddOnEnableState, "DynamicMarker", pName)
            if okSt and type(st) == "number" and st > 0 then
                wasMarkerEnabled = true
            else
                local okSt2, st2 = pcall(C_AddOns.GetAddOnEnableState, "DynamicMarker")
                if okSt2 and type(st2) == "number" and st2 > 0 then
                    wasMarkerEnabled = true
                end
            end
        end
        if wasMarkerEnabled then
            _G.DynamicSuite_StandaloneMarkerWasEnabledAtBoot = true
            if _G.DynamicSuite and type(_G.DynamicSuite.EnforceStandaloneDynamicMarkerExclusion) == "function" then
                pcall(_G.DynamicSuite.EnforceStandaloneDynamicMarkerExclusion, false)
            end
        end
        if DynamicLoadDB then
            PurgeCoreSuiteStateFromTableSet(DynamicLoadDB)
            PurgeCoreSuiteStateFromTableSet(DynamicLoadDB.globalData)
            if type(DynamicLoadDB.charData) == "table" then
                for _, cd in pairs(DynamicLoadDB.charData) do
                    PurgeCoreSuiteStateFromTableSet(cd)
                end
            end
        end
        if C_AddOns and C_AddOns.DisableAddOn then
            pcall(C_AddOns.DisableAddOn, "DynamicMarker", pName)
            pcall(C_AddOns.DisableAddOn, "DynamicMarker")
        end
    end
    for modName, isCore in pairs(PROTECTED_ADDONS) do
        if isCore and not RETIRED_IGNORED_ADDONS[modName] and addonTable._pendingDisableCoreAddon ~= modName then
            if DynamicLoadDB then
                if DynamicLoadDB.frozenAddons then DynamicLoadDB.frozenAddons[modName] = nil end
                if DynamicLoadDB.lockedAddons then DynamicLoadDB.lockedAddons[modName] = nil end
                if DynamicLoadDB.addonStates then DynamicLoadDB.addonStates[modName] = nil end
                if DynamicLoadDB.profiles then
                    for _, ctx in ipairs(ALL_ZONE_CONTEXTS) do
                        local prof = DynamicLoadDB.profiles[ctx]
                        if prof and prof.addons then
                            prof.addons[modName] = true
                        end
                    end
                end
            end
            if not IsSuiteModuleExplicitlyDisabled(modName) then
                if C_AddOns and C_AddOns.GetAddOnInfo and C_AddOns.GetAddOnInfo(modName) then
                    pcall(C_AddOns.EnableAddOn, modName, pName)
                    if (C_AddOns.GetAddOnEnableState(modName, pName) or 0) == 0 then
                        pcall(C_AddOns.EnableAddOn, modName)
                    end
                end
            end
        end
    end
end
addonTable.EnforceProtectedSuiteModules = EnforceProtectedSuiteModules

local function SyncAddonStatesTable()
    if not DynamicLoadDB then return end
    DynamicLoadDB.lockedAddons = DynamicLoadDB.lockedAddons or {}
    DynamicLoadDB.frozenAddons = DynamicLoadDB.frozenAddons or {}
    DynamicLoadDB.addonStates  = DynamicLoadDB.addonStates or {}

    local normalizedStates = {}
    for rawKey, st in pairs(DynamicLoadDB.addonStates) do
        local k = ResolveCanonicalAddonName(rawKey) or rawKey
        normalizedStates[k] = st
        if k ~= rawKey then
            DynamicLoadDB.addonStates[rawKey] = nil
        end
    end
    for k, st in pairs(normalizedStates) do
        DynamicLoadDB.addonStates[k] = st
        if st == "FROZEN" then
            DynamicLoadDB.frozenAddons[k] = true
            DynamicLoadDB.lockedAddons[k] = nil
            WipeAddonFromProfilesTable(DynamicLoadDB.profiles, k)
        elseif st == "LOCKED" then
            DynamicLoadDB.lockedAddons[k] = true
            DynamicLoadDB.frozenAddons[k] = nil
        elseif st == "NORMAL" then
            DynamicLoadDB.frozenAddons[k] = nil
            DynamicLoadDB.lockedAddons[k] = nil
        end
    end
    for rawKey, v in pairs(DynamicLoadDB.frozenAddons) do
        if v then
            local k = ResolveCanonicalAddonName(rawKey) or rawKey
            if k ~= rawKey then
                DynamicLoadDB.frozenAddons[rawKey] = nil
                DynamicLoadDB.frozenAddons[k] = true
            end
            DynamicLoadDB.lockedAddons[k] = nil
            DynamicLoadDB.addonStates[k] = "FROZEN"
            WipeAddonFromProfilesTable(DynamicLoadDB.profiles, k)
        end
    end
    for rawKey, v in pairs(DynamicLoadDB.lockedAddons) do
        local k = ResolveCanonicalAddonName(rawKey) or rawKey
        if v and not DynamicLoadDB.frozenAddons[k] then
            if k ~= rawKey then
                DynamicLoadDB.lockedAddons[rawKey] = nil
                DynamicLoadDB.lockedAddons[k] = true
            end
            DynamicLoadDB.addonStates[k] = "LOCKED"
        end
    end
end
addonTable.SyncAddonStatesTable = SyncAddonStatesTable

local function IsAddonLocked(name)
    local canon = ResolveCanonicalAddonName(name) or name
    if not canon then return false end
    if IsStandaloneMarkerExcludedBySuite(canon) then
        return false
    end
    if addonTable._pendingDisableCoreAddon == canon then
        return false
    end
    if PROTECTED_ADDONS[canon] and not RETIRED_IGNORED_ADDONS[canon] then
        return true
    end
    if not DynamicLoadDB then return false end
    if DynamicLoadDB.addonStates and (DynamicLoadDB.addonStates[canon] == "LOCKED" or DynamicLoadDB.addonStates[name] == "LOCKED") then
        return true
    end
    if DynamicLoadDB.lockedAddons and (DynamicLoadDB.lockedAddons[canon] == true or DynamicLoadDB.lockedAddons[name] == true) then
        return true
    end
    if GetCharScopeMode() ~= "CHARACTER" and DynamicLoadDB.globalData then
        if DynamicLoadDB.globalData.addonStates and (DynamicLoadDB.globalData.addonStates[canon] == "LOCKED" or DynamicLoadDB.globalData.addonStates[name] == "LOCKED") then
            return true
        end
        if DynamicLoadDB.globalData.lockedAddons and (DynamicLoadDB.globalData.lockedAddons[canon] == true or DynamicLoadDB.globalData.lockedAddons[name] == true) then
            return true
        end
    end
    return false
end
addonTable.IsAddonLocked = IsAddonLocked
DynamicSuite.IsAddonLocked = IsAddonLocked

local function IsAddonFrozen(name)
    local canon = ResolveCanonicalAddonName(name) or name
    if not canon or not DynamicLoadDB then return false end
    if addonTable._pendingDisableCoreAddon == canon then
        return true
    end
    if PROTECTED_ADDONS[canon] and not RETIRED_IGNORED_ADDONS[canon] then
        return false
    end
    if DynamicLoadDB.addonStates and (DynamicLoadDB.addonStates[canon] == "FROZEN" or DynamicLoadDB.addonStates[name] == "FROZEN") then
        return true
    end
    if DynamicLoadDB.frozenAddons and (DynamicLoadDB.frozenAddons[canon] == true or DynamicLoadDB.frozenAddons[name] == true) then
        return true
    end
    if GetCharScopeMode() ~= "CHARACTER" and DynamicLoadDB.globalData then
        if DynamicLoadDB.globalData.addonStates and (DynamicLoadDB.globalData.addonStates[canon] == "FROZEN" or DynamicLoadDB.globalData.addonStates[name] == "FROZEN") then
            return true
        end
        if DynamicLoadDB.globalData.frozenAddons and (DynamicLoadDB.globalData.frozenAddons[canon] == true or DynamicLoadDB.globalData.frozenAddons[name] == true) then
            return true
        end
    end
    return false
end
addonTable.IsAddonFrozen = IsAddonFrozen
DynamicSuite.IsAddonFrozen = IsAddonFrozen

local isEnforcingFrozenGuard = false

local function ApplySecurityStateToTableSet(tbl, canon, rawName, mode)
    if type(tbl) ~= "table" then return end
    tbl.lockedAddons = tbl.lockedAddons or {}
    tbl.frozenAddons = tbl.frozenAddons or {}
    tbl.addonStates  = tbl.addonStates or {}
    if rawName and rawName ~= canon then
        tbl.lockedAddons[rawName] = nil
        tbl.frozenAddons[rawName] = nil
        tbl.addonStates[rawName]  = nil
    end
    if mode == "FROZEN" then
        tbl.frozenAddons[canon] = true
        tbl.lockedAddons[canon] = nil
        tbl.addonStates[canon]  = "FROZEN"
        WipeAddonFromProfilesTable(tbl.profiles, canon)
        if rawName and rawName ~= canon then
            WipeAddonFromProfilesTable(tbl.profiles, rawName)
        end
    elseif mode == "LOCKED" then
        tbl.lockedAddons[canon] = true
        tbl.frozenAddons[canon] = nil
        tbl.addonStates[canon]  = "LOCKED"
    else
        tbl.lockedAddons[canon] = nil
        tbl.frozenAddons[canon] = nil
        tbl.addonStates[canon]  = "NORMAL"
    end
end
addonTable.ApplySecurityStateToTableSet = ApplySecurityStateToTableSet

local function SetAddonLocked(name, locked)
    local canon = ResolveCanonicalAddonName(name) or name
    if not canon or IsAddonProtected(canon) or not DynamicLoadDB then return end
    DynamicLoadDB.knownAddons = DynamicLoadDB.knownAddons or {}
    DynamicLoadDB.knownAddons[canon] = true

    local targetMode
    if locked then
        targetMode = "LOCKED"
    else
        targetMode = IsAddonFrozen(canon) and "FROZEN" or "NORMAL"
    end

    ApplySecurityStateToTableSet(DynamicLoadDB, canon, name, targetMode)
    if GetCharScopeMode() == "CHARACTER" then
        local charKey = GetCurrentCharKey()
        if DynamicLoadDB.charData and DynamicLoadDB.charData[charKey] then
            ApplySecurityStateToTableSet(DynamicLoadDB.charData[charKey], canon, name, targetMode)
        end
    elseif DynamicLoadDB.globalData then
        ApplySecurityStateToTableSet(DynamicLoadDB.globalData, canon, name, targetMode)
    end

    if locked and C_AddOns and C_AddOns.EnableAddOn then
        local pName = GetPlayer()
        if IsStandaloneMarkerExcludedBySuite(canon) then
            if C_AddOns.DisableAddOn then
                pcall(C_AddOns.DisableAddOn, canon, pName)
                pcall(C_AddOns.DisableAddOn, canon)
            end
        else
            pcall(C_AddOns.EnableAddOn, canon, pName)
            if (C_AddOns.GetAddOnEnableState(canon, pName) or 0) == 0 then
                pcall(C_AddOns.EnableAddOn, canon)
            end
        end
    end
end
addonTable.SetAddonLocked = SetAddonLocked
DynamicSuite.SetAddonLocked = SetAddonLocked

local function SetAddonFrozen(name, frozen)
    local canon = ResolveCanonicalAddonName(name) or name
    if not canon or IsAddonProtected(canon) or not DynamicLoadDB then return end
    DynamicLoadDB.knownAddons = DynamicLoadDB.knownAddons or {}
    DynamicLoadDB.knownAddons[canon] = true

    local targetMode
    if frozen then
        targetMode = "FROZEN"
    else
        targetMode = IsAddonLocked(canon) and "LOCKED" or "NORMAL"
    end

    ApplySecurityStateToTableSet(DynamicLoadDB, canon, name, targetMode)
    if GetCharScopeMode() == "CHARACTER" then
        local charKey = GetCurrentCharKey()
        if DynamicLoadDB.charData and DynamicLoadDB.charData[charKey] then
            ApplySecurityStateToTableSet(DynamicLoadDB.charData[charKey], canon, name, targetMode)
        end
    elseif DynamicLoadDB.globalData then
        ApplySecurityStateToTableSet(DynamicLoadDB.globalData, canon, name, targetMode)
        if frozen and DynamicLoadDB.charData then
            local charKey = GetCurrentCharKey()
            if DynamicLoadDB.charData[charKey] and DynamicLoadDB.charScopeMode and DynamicLoadDB.charScopeMode[charKey] ~= "CHARACTER" then
                ApplySecurityStateToTableSet(DynamicLoadDB.charData[charKey], canon, name, "FROZEN")
            end
        end
    end

    if frozen and C_AddOns and C_AddOns.DisableAddOn then
        local pName = GetPlayer()
        isEnforcingFrozenGuard = true
        pcall(C_AddOns.DisableAddOn, canon, pName)
        if (C_AddOns.GetAddOnEnableState(canon, pName) or 0) > 0 then
            pcall(C_AddOns.DisableAddOn, canon)
        end
        isEnforcingFrozenGuard = false
    end
end
addonTable.SetAddonFrozen = SetAddonFrozen
DynamicSuite.SetAddonFrozen = SetAddonFrozen

local function EnforceFrozenAddonsDisabled()
    if not DynamicLoadDB or isEnforcingFrozenGuard then return end
    isEnforcingFrozenGuard = true
    local pName = GetPlayer()
    local num = (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()) or 0
    for i = 1, num do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and name ~= "DynamicFrame" and not IsAddonProtected(name) and IsAddonFrozen(name) then
            WipeAddonFromProfilesTable(DynamicLoadDB.profiles, name)
            if DynamicLoadDB.globalData and DynamicLoadDB.globalData.profiles and GetCharScopeMode() ~= "CHARACTER" then
                WipeAddonFromProfilesTable(DynamicLoadDB.globalData.profiles, name)
            end
            if C_AddOns.DisableAddOn then
                pcall(C_AddOns.DisableAddOn, name, pName)
                if (C_AddOns.GetAddOnEnableState(name, pName) or 0) > 0 then
                    pcall(C_AddOns.DisableAddOn, name)
                end
            end
        end
    end
    if DynamicLoadDB.frozenAddons then
        for rawName, isFrz in pairs(DynamicLoadDB.frozenAddons) do
            if isFrz then
                local canon = ResolveCanonicalAddonName(rawName) or rawName
                if canon and not IsAddonProtected(canon) then
                    WipeAddonFromProfilesTable(DynamicLoadDB.profiles, canon)
                    if C_AddOns and C_AddOns.DisableAddOn then
                        pcall(C_AddOns.DisableAddOn, canon, pName)
                        pcall(C_AddOns.DisableAddOn, canon)
                    end
                end
            end
        end
    end
    isEnforcingFrozenGuard = false
end
addonTable.EnforceFrozenAddonsDisabled = EnforceFrozenAddonsDisabled
DynamicSuite.EnforceFrozenAddonsDisabled = EnforceFrozenAddonsDisabled

local function OnExternalEnableAddOnHook(addonKey)
    if isEnforcingFrozenGuard or not DynamicLoadDB then return end
    local canon = ResolveCanonicalAddonName(addonKey)
    if not canon then return end
    if IsStandaloneMarkerExcludedBySuite(canon) then
        isEnforcingFrozenGuard = true
        local pName = GetPlayer()
        if C_AddOns and C_AddOns.DisableAddOn then
            pcall(C_AddOns.DisableAddOn, canon, pName)
            if (C_AddOns.GetAddOnEnableState(canon, pName) or 0) > 0 then
                pcall(C_AddOns.DisableAddOn, canon)
            end
        end
        isEnforcingFrozenGuard = false
        return
    end
    if IsAddonProtected(canon) then return end
    if IsAddonFrozen(canon) then
        isEnforcingFrozenGuard = true
        local pName = GetPlayer()
        WipeAddonFromProfilesTable(DynamicLoadDB.profiles, canon)
        if C_AddOns and C_AddOns.DisableAddOn then
            pcall(C_AddOns.DisableAddOn, canon, pName)
            if (C_AddOns.GetAddOnEnableState(canon, pName) or 0) > 0 then
                pcall(C_AddOns.DisableAddOn, canon)
            end
        end
        isEnforcingFrozenGuard = false
    end
end

if hooksecurefunc then
    if C_AddOns and type(C_AddOns.EnableAddOn) == "function" then
        hooksecurefunc(C_AddOns, "EnableAddOn", OnExternalEnableAddOnHook)
    end
    if type(_G.EnableAddOn) == "function" then
        hooksecurefunc("EnableAddOn", OnExternalEnableAddOnHook)
    end
end

local function GetAddonSecurityState(name)
    local canon = ResolveCanonicalAddonName(name) or name
    if IsAddonFrozen(canon) then return "FROZEN" end
    if IsAddonLocked(canon) then return "LOCKED" end
    return "NORMAL"
end
addonTable.GetAddonSecurityState = GetAddonSecurityState
DynamicSuite.GetAddonSecurityState = GetAddonSecurityState

local function CycleAddonSecurityState(name)
    local canon = ResolveCanonicalAddonName(name) or name
    local cur = GetAddonSecurityState(canon)
    if cur == "NORMAL" then
        SetAddonLocked(canon, true)
        return "LOCKED"
    elseif cur == "LOCKED" then
        SetAddonFrozen(canon, true)
        return "FROZEN"
    else
        SetAddonLocked(canon, false)
        SetAddonFrozen(canon, false)
        return "NORMAL"
    end
end
addonTable.CycleAddonSecurityState = CycleAddonSecurityState


--------------------------------------------------------------------------------
-- Smart Addon Scanner & Safe Harbor Engine (Guided Setup Step 2 - Approach 12A)
--------------------------------------------------------------------------------
local SMART_CORE_PATTERNS = {
    "^DynamicLoad$", "^DynamicMarker$", "^DynamicZoom$", "^DynamicFPS$", "^DynamicPrep$", "^DynamicGroup$", "^DynamicBags$", "^DynamicChat$",
}

local SMART_OUTDOOR_HARBOR_PATTERNS = {
    "^TradeSkillMaster", "^Auctionator$", "^AllTheThings", "^RareScanner", "^SilverDragon",
    "^HandyNotes", "^TomTom$", "^WorldQuestTracker", "^PetTracker", "^Rematch",
    "^MountJournalEnhanced", "^Postal$", "^Routes", "^GatherMate", "^FarmHud",
    "^Loremaster", "^BTWQuests", "^BtWQuests", "^Archy", "^FishingBuddy",
}

local function MatchesAnyPattern(name, patterns)
    for _, pat in ipairs(patterns) do
        if name:find(pat) then
            return true
        end
    end
    return false
end

function addonTable.ApplySmartAddonScan()
    if not DynamicLoadDB then return { lockedCount = 0, outdoorCount = 0 } end
    local num = C_AddOns.GetNumAddOns()
    local pName = GetPlayer()
    local lockedCount = 0
    local outdoorCount = 0

    for _, k in ipairs({ CONTEXT_OUTDOOR, CONTEXT_DELVE, CONTEXT_DUNGEON, CONTEXT_RAID, CONTEXT_PVP }) do
        DynamicLoadDB.profiles[k] = DynamicLoadDB.profiles[k] or { name = CONTEXT_LABELS[k] or k, addons = {} }
        DynamicLoadDB.profiles[k].addons = DynamicLoadDB.profiles[k].addons or {}
    end

    for i = 1, num do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and not IsAddonProtected(name) and not IsAddonFrozen(name) then
            local isEnabledNow = (C_AddOns.GetAddOnEnableState(name, pName) or 0) > 0
            if IsStandaloneMarkerExcludedBySuite(name) then
                SetAddonLocked(name, false)
                for _, k in ipairs({ CONTEXT_OUTDOOR, CONTEXT_DELVE, CONTEXT_DUNGEON, CONTEXT_RAID, CONTEXT_PVP }) do
                    DynamicLoadDB.profiles[k].addons[name] = false
                end
                if C_AddOns and C_AddOns.DisableAddOn then
                    pcall(C_AddOns.DisableAddOn, name, pName)
                    pcall(C_AddOns.DisableAddOn, name)
                end
            elseif MatchesAnyPattern(name, SMART_CORE_PATTERNS) and isEnabledNow then
                SetAddonLocked(name, true)
                lockedCount = lockedCount + 1
                for _, k in ipairs({ CONTEXT_OUTDOOR, CONTEXT_DELVE, CONTEXT_DUNGEON, CONTEXT_RAID, CONTEXT_PVP }) do
                    DynamicLoadDB.profiles[k].addons[name] = true
                end
            elseif MatchesAnyPattern(name, SMART_OUTDOOR_HARBOR_PATTERNS) then
                SetAddonLocked(name, false)
                outdoorCount = outdoorCount + 1
                DynamicLoadDB.profiles[CONTEXT_OUTDOOR].addons[name] = true
                DynamicLoadDB.profiles[CONTEXT_DELVE].addons[name]   = false
                DynamicLoadDB.profiles[CONTEXT_DUNGEON].addons[name] = false
                DynamicLoadDB.profiles[CONTEXT_RAID].addons[name]    = false
                DynamicLoadDB.profiles[CONTEXT_PVP].addons[name]     = false
            elseif isEnabledNow then
                for _, k in ipairs({ CONTEXT_OUTDOOR, CONTEXT_DELVE, CONTEXT_DUNGEON, CONTEXT_RAID, CONTEXT_PVP }) do
                    if DynamicLoadDB.profiles[k].addons[name] == nil then
                        DynamicLoadDB.profiles[k].addons[name] = true
                    end
                end
            end
        end
    end

    local g = EnsureSuiteGlobal()
    g.guidedSetupDone = true

    local activeKey = DynamicLoadDB.activeProfile or CONTEXT_OUTDOOR
    addonTable.StageAddonProfile(activeKey)
    print(string.format("%s: Smart Addon Scan complete (%d Suite Core addons set to [Always], %d non-combat addons routed to Outdoor [By Zone]).", ADDON_TITLE, lockedCount, outdoorCount))
    return { lockedCount = lockedCount, outdoorCount = outdoorCount }
end

--------------------------------------------------------------------------------
-- Modern CPU Profiling Engine (Blizzard C_AddOnProfiler, Zero CVars, Zero Reloads)
--------------------------------------------------------------------------------
function addonTable.IsCpuProfilingEnabled()
    return C_AddOnProfiler and C_AddOnProfiler.IsEnabled and C_AddOnProfiler.IsEnabled()
end

function addonTable.SanitizeLegacyCVar()
    if GetCVar("scriptProfile") == "1" then
        if C_CVar and C_CVar.SetCVar then
            pcall(C_CVar.SetCVar, "scriptProfile", "0")
        end
        pcall(SetCVar, "scriptProfile", "0")
    end
end

--------------------------------------------------------------------------------
-- Toast Notification System (Supports Detailed, Compact & Exceptions-Only + HUD Edit Mode)
--------------------------------------------------------------------------------
local toastFrame = nil

local TOAST_COLOR_THEMES = {
    ["OBSIDIAN_SLATE"] = { r = 0.796, g = 0.835, b = 0.882, bgR = 0.035, bgG = 0.039, bgB = 0.051, bgA = 0.96, hex = "CBD5E1", name = "Obsidian Slate" },
    ["GOLD"]           = { r = 0.961, g = 0.722, b = 0.180, bgR = 0.055, bgG = 0.047, bgB = 0.035, bgA = 0.96, hex = "F5B82E", name = "Alert Gold" },
    ["CYAN"]           = { r = 0.220, g = 0.741, b = 0.973, bgR = 0.035, bgG = 0.051, bgB = 0.075, bgA = 0.96, hex = "38BDF8", name = "Cyber Cyan" },
    ["CRIMSON"]        = { r = 1.000, g = 0.300, b = 0.350, bgR = 0.075, bgG = 0.035, bgB = 0.045, bgA = 0.96, hex = "FF4D59", name = "Crimson Alert" },
    ["PURPLE"]         = { r = 0.720, g = 0.450, b = 1.000, bgR = 0.055, bgG = 0.035, bgB = 0.078, bgA = 0.96, hex = "B873FF", name = "Void Purple" },
}
addonTable.TOAST_COLOR_THEMES = TOAST_COLOR_THEMES

local function RGBToHex(r, g, b)
    r = math.max(0, math.min(1, r or 1))
    g = math.max(0, math.min(1, g or 1))
    b = math.max(0, math.min(1, b or 1))
    return string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function GetToastColors()
    local g = EnsureSuiteGlobal()
    local alpha = g.toastOpacity or g.toastAlpha or (DynamicLoadDB and (DynamicLoadDB.toastOpacity or DynamicLoadDB.toastAlpha)) or 0.96

    if g.syncThemeToToast and addonTable.UI and addonTable.UI.GetActiveAccentColor then
        local ar, ag, ab = addonTable.UI.GetActiveAccentColor()
        local sr, sg, sb = 0.035, 0.039, 0.051
        if addonTable.UI.GetActiveSurfaceColors then
            local surf = addonTable.UI.GetActiveSurfaceColors()
            if surf and surf.panel then
                sr, sg, sb = surf.panel.r, surf.panel.g, surf.panel.b
            end
        end
        local bdr = { r = ar, g = ag, b = ab, a = 0.95 }
        local bg  = { r = sr, g = sg, b = sb, a = alpha }
        local ttl = { r = ar, g = ag, b = ab }
        local bdg = { r = ar, g = ag, b = ab }
        return bdr, bg, ttl, bdg
    end

    local key = (DynamicLoadDB and DynamicLoadDB.toastColorKey) or "OBSIDIAN_SLATE"
    local preset = TOAST_COLOR_THEMES[key] or TOAST_COLOR_THEMES["OBSIDIAN_SLATE"]

    local bdr = (DynamicLoadDB and DynamicLoadDB.toastBorderColor) or { r = preset.r, g = preset.g, b = preset.b, a = 0.95 }
    local bg  = (DynamicLoadDB and DynamicLoadDB.toastBgColor)     or { r = preset.bgR, g = preset.bgG, b = preset.bgB, a = alpha }
    bg.a = alpha
    local ttl = (DynamicLoadDB and DynamicLoadDB.toastTitleColor)  or { r = preset.r, g = preset.g, b = preset.b }
    local bdg = (DynamicLoadDB and DynamicLoadDB.toastBadgeColor)  or { r = preset.r, g = preset.g, b = preset.b }

    return bdr, bg, ttl, bdg
end
addonTable.GetToastColors = GetToastColors

function addonTable.ApplyToastPreset(key)
    local preset = TOAST_COLOR_THEMES[key] or TOAST_COLOR_THEMES["OBSIDIAN_SLATE"]
    local g = EnsureSuiteGlobal()
    if DynamicLoadDB then
        DynamicLoadDB.toastColorKey = key
        DynamicLoadDB.toastBorderColor = { r = preset.r, g = preset.g, b = preset.b, a = 0.95 }
        DynamicLoadDB.toastBgColor     = { r = preset.bgR, g = preset.bgG, b = preset.bgB, a = g.toastAlpha or 0.96 }
        DynamicLoadDB.toastTitleColor  = { r = preset.r, g = preset.g, b = preset.b }
        DynamicLoadDB.toastBadgeColor  = { r = preset.r, g = preset.g, b = preset.b }
    end
end

local function GetToastTitlePrefix()
    local _, _, ttl = GetToastColors()
    local hex = RGBToHex(ttl.r, ttl.g, ttl.b)
    local customHdr = (DynamicLoadDB and DynamicLoadDB.toastHeaderText)
    if not customHdr or customHdr == "" or customHdr == "DynamicLoad" then
        return string.format("|cFFF3F5F8Dynamic|r|cFF%sLoad|r", hex)
    end
    return string.format("|cFF%s%s|r", hex, customHdr)
end

local function RefreshToastContent(f)
    if not f then return end
    local g = EnsureSuiteGlobal()
    local mode = g.toastDisplayMode or (DynamicLoadDB and DynamicLoadDB.toastDisplayMode) or "DETAILED"
    local _, _, _, bdg = GetToastColors()
    local bdgHex = RGBToHex(bdg.r, bdg.g, bdg.b)
    local profKey = f.previewProfileKey or (DynamicLoadDB and DynamicLoadDB.activeProfile) or "outdoor"
    local profileName = (DynamicLoadDB and DynamicLoadDB.profiles and DynamicLoadDB.profiles[profKey] and DynamicLoadDB.profiles[profKey].name) or "Outdoor"
    local deltaCount = f.previewDelta or 4

    local fontPath = (addonTable.UI and addonTable.UI.GetFont and addonTable.UI.GetFont()) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    f.title:SetFont(fontPath, 13, "")
    f.badge:SetFont(fontPath, 11, "")
    f.subtext:SetFont(fontPath, 10, "")

    if mode == "COMPACT" then
        f:SetSize(390, 44)
        f.iconBorder:SetSize(28, 28)
        f.iconBorder:ClearAllPoints()
        f.iconBorder:SetPoint("LEFT", f, "LEFT", 10, 0)
        f.title:ClearAllPoints()
        f.title:SetPoint("LEFT", f.iconBorder, "RIGHT", 10, 0)
        f.title:SetPoint("RIGHT", f.reloadBtn, "LEFT", -8, 0)
        f.title:SetText(string.format("%s: |cFFFFFFFF%s|r |cFF%s(%d staged)|r", GetToastTitlePrefix(), profileName, bdgHex, deltaCount))
        f.badge:Hide()
        f.subtext:Hide()
    else
        f:SetSize(410, 74)
        f.iconBorder:SetSize(44, 44)
        f.iconBorder:ClearAllPoints()
        f.iconBorder:SetPoint("LEFT", f, "LEFT", 14, 0)
        f.title:ClearAllPoints()
        f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -11)
        f.title:SetPoint("RIGHT", f.reloadBtn, "LEFT", -8, 0)
        f.badge:Show()
        f.subtext:Show()

        f.title:SetText(string.format("%s: |cFFFFFFFF%s|r", GetToastTitlePrefix(), profileName))
        f.badge:SetText(string.format("|cFF%s[ %d addons staged for reload ]|r", bdgHex, deltaCount))
        f.subtext:SetText("|cFFFFFFFFClick [Reload] to Apply|r    |cFF888888Right-Click: Dismiss|r")
    end
end

-- L10-B Two-Tone Colinear Speed-Cut "D" Brand Logo Builder
-- Renders Arty's dual-layer .tga masks (logo_stem_white.tga + logo_loop_mask.tga with icon_white/icon_accent fallback)
local function PopulateDynamicLoadBrandLogo(badge, size)
    if not badge then return end
    local sz = size or badge:GetWidth() or 28
    local pad = math.max(1, math.floor((sz / 28) * 1.5))

    badge.bgFill = badge.bgFill or badge:CreateTexture(nil, "BACKGROUND", nil, 1)
    badge.bgFill:SetAllPoints()
    badge.bgFill:SetColorTexture(0.04, 0.05, 0.07, 0.98)

    local tgaWhite = badge.tgaWhite or badge:CreateTexture(nil, "ARTWORK", nil, 4)
    tgaWhite:ClearAllPoints()
    tgaWhite:SetPoint("TOPLEFT", badge, "TOPLEFT", pad, -pad)
    tgaWhite:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", -pad, pad)
    tgaWhite:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\logo_stem_white.tga")
    if not tgaWhite:GetTexture() then
        tgaWhite:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_white.tga")
    end
    tgaWhite:SetVertexColor(0.96, 0.97, 0.99, 1)
    badge.tgaWhite = tgaWhite

    local tgaAccent = badge.tgaAccent or badge:CreateTexture(nil, "ARTWORK", nil, 5)
    tgaAccent:ClearAllPoints()
    tgaAccent:SetPoint("TOPLEFT", badge, "TOPLEFT", pad, -pad)
    tgaAccent:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", -pad, pad)
    tgaAccent:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\logo_loop_mask.tga")
    if not tgaAccent:GetTexture() then
        tgaAccent:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_accent.tga")
    end
    badge.tgaAccent = tgaAccent

    function badge:SetAccentColor(r, g, b, a)
        local ar, ag, ab = r or 0.80, g or 0.84, b or 0.88
        if self.tgaWhite then
            self.tgaWhite:SetVertexColor(0.96, 0.97, 0.99, a or 1)
        end
        if self.tgaAccent then
            self.tgaAccent:SetVertexColor(ar, ag, ab, a or 1)
        end
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(ar, ag, ab, 0.80)
        end
        if self.dsBorder and self.dsBorder.SetColor then
            self.dsBorder:SetColor(ar, ag, ab, 0.85)
        end
    end

    local ar, ag, ab = 0.80, 0.84, 0.88
    if addonTable.UI and addonTable.UI.GetActiveAccentColor then
        ar, ag, ab = addonTable.UI.GetActiveAccentColor()
    else
        local bdr = GetToastColors()
        if bdr then ar, ag, ab = bdr.r, bdr.g, bdr.b end
    end
    badge:SetAccentColor(ar, ag, ab, 1)
    return badge
end
if not (DynamicSuite and DynamicSuite._isHubLoaded) or not addonTable.PopulateBrandLogo then
    addonTable.PopulateBrandLogo = PopulateDynamicLoadBrandLogo
end

local function GetToastAnchorFraction(pointStr)
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

local function ClampToastCoordsToScreen(f, point, relPoint, rawX, rawY)
    local pt = point or "TOP"
    local rp = relPoint or pt
    local fScale = (f and f.GetEffectiveScale and f:GetEffectiveScale()) or 1
    local uScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if fScale <= 0 then fScale = 1 end
    if uScale <= 0 then uScale = 1 end
    local relScale = fScale / uScale
    if relScale <= 0 then relScale = 1 end

    local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
    local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
    local screenCx = screenW / 2
    local screenCy = screenH / 2

    local frameW = (f and f.GetWidth and f:GetWidth()) or 410
    local frameH = (f and f.GetHeight and f:GetHeight()) or 74
    local visW = math.max(1, frameW * relScale)
    local visH = math.max(1, frameH * relScale)
    local halfW = visW / 2
    local halfH = visH / 2

    local pfx, pfy = GetToastAnchorFraction(pt)
    local rfx, rfy = GetToastAnchorFraction(rp)
    local refX = rfx * screenW
    local refY = rfy * screenH

    local inX = tonumber(rawX) or 0
    local inY = tonumber(rawY) or -50
    local anchorVisX = refX + (inX * relScale)
    local anchorVisY = refY + (inY * relScale)
    local candCx = anchorVisX + (0.5 - pfx) * visW
    local candCy = anchorVisY + (0.5 - pfy) * visH

    local minCx = halfW
    local maxCx = screenW - halfW
    local minCy = halfH
    local maxCy = screenH - halfH
    if minCx > maxCx then
        candCx = screenCx
    else
        candCx = math.max(minCx, math.min(maxCx, candCx))
    end
    if minCy > maxCy then
        candCy = screenCy
    else
        candCy = math.max(minCy, math.min(maxCy, candCy))
    end

    local outX = math.floor((((candCx - (0.5 - pfx) * visW) - refX) / relScale) + 0.5)
    local outY = math.floor((((candCy - (0.5 - pfy) * visH) - refY) / relScale) + 0.5)

    local minLocalX = ((minCx - (0.5 - pfx) * visW) - refX) / relScale
    local maxLocalX = ((maxCx - (0.5 - pfx) * visW) - refX) / relScale
    local minLocalY = ((minCy - (0.5 - pfy) * visH) - refY) / relScale
    local maxLocalY = ((maxCy - (0.5 - pfy) * visH) - refY) / relScale

    if minLocalX <= maxLocalX then
        local loX = math.ceil(minLocalX - 1e-6)
        local hiX = math.floor(maxLocalX + 1e-6)
        if loX <= hiX then outX = math.max(loX, math.min(hiX, outX)) end
    else
        outX = math.floor((((screenCx - (0.5 - pfx) * visW) - refX) / relScale) + 0.5)
    end
    if minLocalY <= maxLocalY then
        local loY = math.ceil(minLocalY - 1e-6)
        local hiY = math.floor(maxLocalY + 1e-6)
        if loY <= hiY then outY = math.max(loY, math.min(hiY, outY)) end
    else
        outY = math.floor((((screenCy - (0.5 - pfy) * visH) - refY) / relScale) + 0.5)
    end

    local didClamp = (outX ~= math.floor(inX + 0.5)) or (outY ~= math.floor(inY + 0.5))
    return outX, outY, didClamp
end

local function ApplyToastPosition(f)
    if not f then return end
    f:ClearAllPoints()
    local g = EnsureSuiteGlobal()
    local scale = g.toastScale or (DynamicLoadDB and DynamicLoadDB.toastScale) or 1.0
    f:SetScale(scale)

    local bdr, bg = GetToastColors()
    local alpha = bg.a or 0.96
    local bStyle = g.toastBorderStyle or (DynamicLoadDB and DynamicLoadDB.toastBorderStyle) or "ACCENT"
    if f.SetBackdropColor then
        if addonTable._isHudEditModeActive or f.isEditingMode or f.isDraggingMode then
            f:SetBackdropColor(bg.r, bg.g, bg.b, 0.96)
            if f._dsDragShield and f._dsDragShield.SetIgnoreParentAlpha then
                f._dsDragShield:SetIgnoreParentAlpha(true)
            end
            local isNormalShown = true
            if addonTable.IsHudTargetShown then
                isNormalShown = addonTable.IsHudTargetShown("TOAST")
            elseif g then
                isNormalShown = (g.showToastWindow ~= false and g.enableAlertToast ~= false and (not DynamicLoadDB or DynamicLoadDB.enableAlertToast ~= false))
            end
            f:SetAlpha(isNormalShown and alpha or math.min(alpha, 0.65))
        else
            f:SetBackdropColor(bg.r, bg.g, bg.b, alpha)
        end
        if bStyle == "NONE" then
            f:SetBackdropBorderColor(0, 0, 0, 0)
        elseif bStyle == "SUBTLE" or bStyle == "DARK" then
            f:SetBackdropBorderColor(0.20, 0.24, 0.32, 0.95)
        else
            f:SetBackdropBorderColor(bdr.r, bdr.g, bdr.b, bdr.a or 0.95)
        end
    end
    if f.iconBorder then
        f.iconBorder:SetBackdropBorderColor(bdr.r, bdr.g, bdr.b, 0.7)
        if f.iconBorder.SetAccentColor then
            f.iconBorder:SetAccentColor(bdr.r, bdr.g, bdr.b, 1)
        end
    end
    if f.reloadBtn and f.reloadBtn.dsBorder then
        f.reloadBtn.dsBorder:SetColor(bdr.r, bdr.g, bdr.b, 0.85)
        f.reloadBtn.bg:SetColorTexture(bdr.r, bdr.g, bdr.b, 0.22)
    end
    if f.reloadBtn and f.reloadBtn.SetBackdropBorderColor and f.toastType ~= "CONFLICT_ALERT" then
        f.reloadBtn:SetBackdropColor(0.12, 0.16, 0.22, 0.95)
        f.reloadBtn:SetBackdropBorderColor(bdr.r, bdr.g, bdr.b, 0.85)
    end

    if f.toastType ~= "CONFLICT_ALERT" and f.toastType ~= "NEW_ADDON" then
        RefreshToastContent(f)
    end

    local pos = g.toastPos or (DynamicLoadDB and DynamicLoadDB.toastPos)
    local mf = _G.DynamicLoadMainFrame
    if mf and mf:IsShown() and not f.isEditingMode and not f.isDraggingMode then
        local fEff = (f.GetEffectiveScale and f:GetEffectiveScale()) or 1
        local mEff = (mf.GetEffectiveScale and mf:GetEffectiveScale()) or 1
        if fEff <= 0 then fEff = 1 end
        local mfTopPhys = (mf.GetTop and mf:GetTop() or 700) * mEff
        local mfCenterXPhys = (mf.GetCenter and select(1, mf:GetCenter()) or 960) * mEff
        local uEff = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local gapPhys = 10 * uEff

        f:SetClampedToScreen(true)
        f:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", mfCenterXPhys / fEff, (mfTopPhys + gapPhys) / fEff)
    elseif pos and pos.point and pos.x and pos.y then
        local rp = pos.relPoint or pos.point
        local cx, cy, didClamp = ClampToastCoordsToScreen(f, pos.point, rp, pos.x, pos.y)
        if didClamp then
            pos.x = cx
            pos.y = cy
            if type(g.toastPos) == "table" then
                g.toastPos.x = cx
                g.toastPos.y = cy
            end
            if DynamicLoadDB and type(DynamicLoadDB.toastPos) == "table" then
                DynamicLoadDB.toastPos.x = cx
                DynamicLoadDB.toastPos.y = cy
            end
        end
        f:SetPoint(pos.point, UIParent, rp, cx, cy)
    else
        local cx, cy = ClampToastCoordsToScreen(f, "TOP", "TOP", 0, -50)
        f:SetPoint("TOP", UIParent, "TOP", cx, cy)
    end

    local dgToast = _G.DynamicGroupTeleportToast
    if dgToast and dgToast:IsShown() and not dgToast._dsStackedUnderLoad and not f.isEditingMode and not f.isDraggingMode and not (mf and mf:IsShown()) then
        f._dsStackedUnderGroup = true
        f:ClearAllPoints()
        f:SetPoint("TOP", dgToast, "BOTTOM", 0, -8)
    else
        f._dsStackedUnderGroup = false
    end

    if f.toastType ~= "CONFLICT_ALERT" and f.toastType ~= "NEW_ADDON" then
        RefreshToastContent(f)
    end
end

addonTable.ApplyToastVisuals = function()
    if toastFrame then
        ApplyToastPosition(toastFrame)
    end
    if _G.DynamicGroup and type(_G.DynamicGroup.ApplyTeleportToastPosition) == "function" then
        pcall(_G.DynamicGroup.ApplyTeleportToastPosition, _G.DynamicGroup)
    end
end
_G.DynamicSuite = _G.DynamicSuite or {}
_G.DynamicSuite.ApplyToastVisuals = addonTable.ApplyToastVisuals

addonTable.ClampToastPosition = function()
    if toastFrame then
        ApplyToastPosition(toastFrame)
    end
end

local function CreateToastFrame()
    if toastFrame then return toastFrame end

    local f = CreateFrame("Button", "DynamicLoadToastFrame", UIParent, "BackdropTemplate")
    f:SetSize(410, 74)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:RegisterForDrag("LeftButton")
    f:Hide()

    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1.5,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })

    local iconBorder = CreateFrame("Frame", nil, f, "BackdropTemplate")
    iconBorder:SetSize(44, 44)
    iconBorder:SetPoint("LEFT", f, "LEFT", 14, 0)
    iconBorder:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    iconBorder:SetBackdropColor(0.04, 0.05, 0.07, 1)
    addonTable.PopulateBrandLogo(iconBorder, 44)
    f.iconBorder = iconBorder
    f.iconWrap = iconBorder
    addonTable.toastFrame = f

    -- Explicit [Reload] / [Resolve] Action Pill Button (Gate 13 Accidental Reload Defense)
    local reloadBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    reloadBtn:SetSize(68, 24)
    reloadBtn:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    reloadBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    reloadBtn:SetBackdropColor(0.12, 0.16, 0.22, 0.95)
    reloadBtn:SetBackdropBorderColor(0.79, 0.83, 0.88, 0.85)
    local reloadLbl = reloadBtn:CreateFontString(nil, "OVERLAY")
    reloadLbl:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
    reloadLbl:SetPoint("CENTER")
    reloadLbl:SetText("Reload")
    reloadLbl:SetTextColor(1, 1, 1, 0.95)
    reloadBtn.label = reloadLbl
    reloadBtn:SetScript("OnClick", function()
        if f.isEditingMode or f.isDraggingMode then return end
        if f.toastType == "CONFLICT_ALERT" then
            f.animGroup:Stop()
            f:Hide()
            f:SetAlpha(1)
            if addonTable.OpenWorkspaceViewSafe then
                addonTable.OpenWorkspaceViewSafe("GUIDED_SETUP")
            elseif addonTable.OpenWorkspaceView then
                addonTable.OpenWorkspaceView("GUIDED_SETUP")
            elseif addonTable.ToggleConfigUI then
                addonTable.ToggleConfigUI(true)
            end
            if addonTable.SelectGuidedSetupStep then
                addonTable.SelectGuidedSetupStep(1)
            end
        elseif f.toastType == "NEW_ADDON" then
            f.animGroup:Stop()
            f:Hide()
            if addonTable.ToggleConfigUI then
                addonTable.ToggleConfigUI(true)
            end
        else
            ReloadUI()
        end
    end)
    f.reloadBtn = reloadBtn

    -- Dismiss [X] Button (Shown on CONFLICT_ALERT Toasts)
    local closeBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    closeBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    closeBtn:SetBackdropColor(0.08, 0.09, 0.12, 0.96)
    closeBtn:SetBackdropBorderColor(0.35, 0.40, 0.48, 0.75)
    local closeLbl = closeBtn:CreateFontString(nil, "OVERLAY")
    closeLbl:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
    closeLbl:SetPoint("CENTER")
    closeLbl:SetText("X")
    closeLbl:SetTextColor(0.75, 0.80, 0.88, 0.95)
    closeBtn.label = closeLbl
    closeBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.961, 0.722, 0.180, 0.95)
        self.label:SetTextColor(1, 1, 1, 1)
    end)
    closeBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.35, 0.40, 0.48, 0.75)
        self.label:SetTextColor(0.75, 0.80, 0.88, 0.95)
    end)
    closeBtn:SetScript("OnClick", function()
        if f.isEditingMode or f.isDraggingMode then return end
        hasShownToastThisLoadSession = true
        pendingToastAfterCombat = false
        pendingPostLoadToast = false
        f.animGroup:Stop()
        f:Hide()
        f:SetAlpha(1)
    end)
    closeBtn:Hide()
    f.closeBtn = closeBtn

    -- Secondary [View Conflicts] Action Pill Button (Shown on CONFLICT_ALERT Toasts)
    local viewConflictsBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    viewConflictsBtn:SetSize(96, 24)
    viewConflictsBtn:SetPoint("RIGHT", reloadBtn, "LEFT", -6, 0)
    viewConflictsBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    viewConflictsBtn:SetBackdropColor(0.08, 0.09, 0.12, 0.96)
    viewConflictsBtn:SetBackdropBorderColor(0.961, 0.722, 0.180, 0.85)
    local viewConflictsLbl = viewConflictsBtn:CreateFontString(nil, "OVERLAY")
    viewConflictsLbl:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10.5, "")
    viewConflictsLbl:SetPoint("CENTER")
    viewConflictsLbl:SetText("View Conflicts")
    viewConflictsLbl:SetTextColor(0.961, 0.722, 0.180, 1)
    viewConflictsBtn.label = viewConflictsLbl
    viewConflictsBtn:SetScript("OnClick", function()
        if f.isEditingMode or f.isDraggingMode then return end
        f.animGroup:Stop()
        f:Hide()
        if addonTable.OpenWorkspaceViewSafe then
            addonTable.OpenWorkspaceViewSafe("GUIDED_SETUP")
        elseif addonTable.OpenWorkspaceView then
            addonTable.OpenWorkspaceView("GUIDED_SETUP")
        elseif addonTable.ShowConfigUI then
            addonTable.ShowConfigUI()
            if addonTable.OpenWorkspaceView then
                addonTable.OpenWorkspaceView("GUIDED_SETUP")
            end
        end
    end)
    viewConflictsBtn:Hide()
    f.viewConflictsBtn = viewConflictsBtn

    local fontPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(fontPath, 13, "")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -11)
    title:SetPoint("RIGHT", reloadBtn, "LEFT", -8, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    f.title = title

    local badge = f:CreateFontString(nil, "OVERLAY")
    badge:SetFont(fontPath, 11, "")
    badge:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    badge:SetPoint("RIGHT", reloadBtn, "LEFT", -8, 0)
    badge:SetJustifyH("LEFT")
    badge:SetWordWrap(false)
    f.badge = badge

    local subtext = f:CreateFontString(nil, "OVERLAY")
    subtext:SetFont(fontPath, 10, "")
    subtext:SetPoint("TOPLEFT", badge, "BOTTOMLEFT", 0, -5)
    subtext:SetPoint("RIGHT", reloadBtn, "LEFT", -8, 0)
    subtext:SetJustifyH("LEFT")
    subtext:SetWordWrap(false)
    f.subtext = subtext

    local animGroup = f:CreateAnimationGroup()
    f.animGroup = animGroup

    local holdAnim = animGroup:CreateAnimation("Animation")
    holdAnim:SetDuration(8)
    holdAnim:SetOrder(1)
    f.holdAnim = holdAnim

    local fadeAnim = animGroup:CreateAnimation("Alpha")
    fadeAnim:SetFromAlpha(1)
    fadeAnim:SetToAlpha(0)
    fadeAnim:SetDuration(1.2)
    fadeAnim:SetOrder(2)
    f.fadeAnim = fadeAnim

    animGroup:SetScript("OnFinished", function()
        f.isRealAlert = false
        if not f.isDraggingMode and not f.isEditingMode then
            f:Hide()
            f:SetAlpha(1)
        end
    end)

    f:SetScript("OnDragStart", function(self)
        if self.isDraggingMode or self.isEditingMode then
            if addonTable.OnHudTargetSelected then
                addonTable.OnHudTargetSelected("TOAST")
            end
            self:StartMoving()
        end
    end)

    f:SetScript("OnDragStop", function(self)
        if self.isDraggingMode or self.isEditingMode then
            self:StopMovingOrSizing()
            local g = EnsureSuiteGlobal()
            local prevPos = g.toastPos or (DynamicLoadDB and DynamicLoadDB.toastPos) or { point = "TOP", relPoint = "TOP", x = 0, y = -50 }
            local fScale = (self.GetEffectiveScale and self:GetEffectiveScale()) or 1
            local uScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
            local ratio = (uScale > 0) and (fScale / uScale) or 1
            local fCx, fCy = self:GetCenter()
            local fTop = self:GetTop()
            local uCx, uCy = UIParent:GetCenter()
            local uTop = UIParent:GetTop()

            local usePt = (prevPos.point == "CENTER") and "CENTER" or "TOP"
            local rx, ry = 0, -50
            if fCx and uCx then
                if ratio <= 0 then ratio = 1 end
                rx = math.floor((((fCx * ratio) - uCx) / ratio) + 0.5)
                local dyCenter = math.floor((((fCy * ratio) - uCy) / ratio) + 0.5)
                local dyTop = math.floor(((((fTop or fCy) * ratio) - (uTop or (uCy * 2))) / ratio) + 0.5)
                ry = (usePt == "CENTER") and dyCenter or dyTop

                local snapMode = g.hudSnapMode or "MAGNET"
                local bypassSnap = (IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown())
                if not bypassSnap then
                    if snapMode == "MAGNET" then
                        if math.abs(rx) <= 6 then rx = 0 end
                        if math.abs(dyCenter) <= 6 then
                            usePt = "CENTER"
                            ry = 0
                        elseif math.abs(ry) <= 6 then
                            ry = 0
                        end
                    elseif snapMode == 16 or snapMode == 32 then
                        local step = snapMode
                        if math.abs(rx) <= 6 then
                            rx = 0
                        else
                            rx = math.floor((rx / step) + 0.5) * step
                        end
                        if math.abs(dyCenter) <= 6 then
                            usePt = "CENTER"
                            ry = 0
                        else
                            ry = math.floor((ry / step) + 0.5) * step
                        end
                    end
                end
            else
                local point, _, relPoint, x, y = self:GetPoint()
                usePt = point or "TOP"
                rx = math.floor((x or 0) + 0.5)
                ry = math.floor((y or 0) + 0.5)
            end

            rx, ry = ClampToastCoordsToScreen(self, usePt, usePt, rx, ry)
            self:ClearAllPoints()
            self:SetPoint(usePt, UIParent, usePt, rx, ry)
            local newPos = { point = usePt, relPoint = usePt, x = rx, y = ry }
            g.toastPos = CopyTable(newPos)
            if DynamicLoadDB then
                DynamicLoadDB.toastPos = CopyTable(newPos)
            end
            RefreshToastContent(self)
            if addonTable.OnToastPositionChanged then
                addonTable.OnToastPositionChanged(newPos)
            end
        end
    end)

    f:SetScript("OnClick", function(self, button)
        if self.isEditingMode then
            if addonTable.OnHudTargetSelected then
                addonTable.OnHudTargetSelected("TOAST")
            end
            return
        end
        if self.isDraggingMode then
            addonTable.StopToastMove()
            return
        end

        if button == "RightButton" then
            hasShownToastThisLoadSession = true
            pendingToastAfterCombat = false
            pendingPostLoadToast = false
            self.animGroup:Stop()
            self:Hide()
            self:SetAlpha(1)
        elseif button == "LeftButton" and self.toastType == "CONFLICT_ALERT" then
            self.animGroup:Stop()
            self:Hide()
            self:SetAlpha(1)
            if addonTable.OpenWorkspaceViewSafe then
                addonTable.OpenWorkspaceViewSafe("GUIDED_SETUP")
            elseif addonTable.OpenWorkspaceView then
                addonTable.OpenWorkspaceView("GUIDED_SETUP")
            end
            if addonTable.SelectGuidedSetupStep then
                addonTable.SelectGuidedSetupStep(1)
            end
        elseif button == "LeftButton" and self.toastType == "NEW_ADDON" then
            self.animGroup:Stop()
            self:Hide()
            if addonTable.ToggleConfigUI then
                addonTable.ToggleConfigUI(true)
            end
        end
    end)

    f:SetScript("OnEnter", function(self)
        if not self.isDraggingMode and not self.isEditingMode then
            self.animGroup:Pause()
            self:SetAlpha(1)
        end
    end)

    f:SetScript("OnLeave", function(self)
        local g = EnsureSuiteGlobal()
        local dur = g.toastDuration or (DynamicLoadDB and DynamicLoadDB.toastDuration) or 8
        if not self.isDraggingMode and not self.isEditingMode and dur > 0 then
            self.animGroup:Play()
        end
    end)

    ApplyToastPosition(f)
    toastFrame = f
    f:HookScript("OnHide", function(selfToast)
        selfToast._dsStackedUnderGroup = false
        if _G.DynamicGroup and type(_G.DynamicGroup.OnAlertToastHidden) == "function" then
            pcall(_G.DynamicGroup.OnAlertToastHidden, _G.DynamicGroup)
        end
    end)
    return toastFrame
end
addonTable.CreateToastFrame = CreateToastFrame
addonTable.EnsureToastFrame = CreateToastFrame
if _G.DynamicLoad then
    _G.DynamicLoad.EnsureToastFrame = function()
        return CreateToastFrame()
    end
    _G.DynamicLoad.CreateToastFrame = _G.DynamicLoad.EnsureToastFrame
end

function addonTable.NudgeToastPosition(dx, dy)
    local g = EnsureSuiteGlobal()
    local prev = g.toastPos or (DynamicLoadDB and DynamicLoadDB.toastPos) or { point = "TOP", relPoint = "TOP", x = 0, y = -50 }
    local pt = prev.point or "TOP"
    local rp = prev.relPoint or pt
    local f = CreateToastFrame()
    local rawX = math.floor((prev.x or 0) + (dx or 0) + 0.5)
    local rawY = math.floor((prev.y or -50) + (dy or 0) + 0.5)
    local cx, cy = ClampToastCoordsToScreen(f, pt, rp, rawX, rawY)
    local pos = { point = pt, relPoint = rp, x = cx, y = cy }
    g.toastPos = CopyTable(pos)
    if DynamicLoadDB then
        DynamicLoadDB.toastPos = CopyTable(pos)
    end
    ApplyToastPosition(f)
    if addonTable.OnToastPositionChanged then
        addonTable.OnToastPositionChanged(pos)
    end
end

function addonTable.SetToastPresetPosition(point, relPoint, x, y)
    local pt = point or "TOP"
    local rp = relPoint or pt
    local f = CreateToastFrame()
    local cx, cy = ClampToastCoordsToScreen(f, pt, rp, x or 0, y or -50)
    local newPos = { point = pt, relPoint = rp, x = cx, y = cy }
    local g = EnsureSuiteGlobal()
    g.toastPos = CopyTable(newPos)
    if DynamicLoadDB then
        DynamicLoadDB.toastPos = CopyTable(newPos)
    end
    ApplyToastPosition(f)
    if addonTable.OnToastPositionChanged then
        addonTable.OnToastPositionChanged(newPos)
    end
end

function addonTable.SetToastEditMode(enabled, profileKey)
    local f = CreateToastFrame()
    f.animGroup:Stop()
    f.isEditingMode = (enabled == true)
    f.isDraggingMode = (enabled == true)
    f.previewProfileKey = profileKey or "outdoor"
    f.previewDelta = 4
    if f.SetClampedToScreen then
        f:SetClampedToScreen(not enabled)
    end
    if f.reloadBtn and f.reloadBtn.EnableMouse then f.reloadBtn:EnableMouse(not enabled) end
    if f.closeBtn and f.closeBtn.EnableMouse then f.closeBtn:EnableMouse(not enabled) end
    if f.viewConflictsBtn and f.viewConflictsBtn.EnableMouse then f.viewConflictsBtn:EnableMouse(not enabled) end

    if enabled then
        f.isRealAlert = false
        if not f._dsDragging then
            ApplyToastPosition(f)
        end
        RefreshToastContent(f)
        f:Show()
    else
        f.isRealAlert = false
        ApplyToastPosition(f)
        f:SetAlpha(1)
        f:Hide()
    end
end

local function ShowToast(profileKey, deltaCount, isTestPreview)
    local g = EnsureSuiteGlobal()
    local toastOn = g.toastEnabled
    if toastOn == nil and DynamicLoadDB then toastOn = DynamicLoadDB.toastEnabled end
    local tMode = g.toastMode or (DynamicLoadDB and DynamicLoadDB.toastMode)
    local mode = g.toastDisplayMode or (DynamicLoadDB and DynamicLoadDB.toastDisplayMode) or "DETAILED"
    if not isTestPreview and (toastOn == false or tMode == "OFF" or mode == "OFF") then
        return
    end
    if mode == "EXCEPTIONS_ONLY" and (deltaCount or 0) <= 0 and not isTestPreview then
        return
    end

    local f = CreateToastFrame()
    f.previewProfileKey = profileKey or (DynamicLoadDB and DynamicLoadDB.activeProfile) or "outdoor"
    f.previewDelta = deltaCount or 4
    f.toastType = "STAGE"
    if f.closeBtn then f.closeBtn:Hide() end
    if f.viewConflictsBtn then f.viewConflictsBtn:Hide() end
    if f.reloadBtn then
        f.reloadBtn:SetSize(68, 24)
        f.reloadBtn:ClearAllPoints()
        f.reloadBtn:SetPoint("RIGHT", f, "RIGHT", -12, 0)
        if f.reloadBtn.label then f.reloadBtn.label:SetText("Reload") end
    end
    if f.title then f.title:SetPoint("RIGHT", f.reloadBtn, "LEFT", -8, 0) end
    if f.badge then f.badge:SetPoint("RIGHT", f.reloadBtn, "LEFT", -8, 0) end
    if f.subtext then f.subtext:SetPoint("RIGHT", f.reloadBtn, "LEFT", -8, 0) end

    if f.isEditingMode or f.isDraggingMode then
        f.isRealAlert = false
        ApplyToastPosition(f)
        RefreshToastContent(f)
        f:Show()
        return
    end

    f.isRealAlert = not isTestPreview
    f.animGroup:Stop()
    f:SetAlpha(1)
    ApplyToastPosition(f)
    RefreshToastContent(f)

    local duration = g.toastDuration
    if duration == nil then
        duration = (DynamicLoadDB and DynamicLoadDB.toastDuration) or 8
    end

    f:Show()
    if duration and duration > 0 then
        f.holdAnim:SetDuration(duration)
        f.animGroup:Play()
    end
end
addonTable.ShowToast = ShowToast

local function ShowNewAddonsToast(newAddons)
    local f = CreateToastFrame()
    if f.isDraggingMode or f.isEditingMode then return end

    f.isRealAlert = true
    f.animGroup:Stop()
    f:SetAlpha(1)
    f.toastType = "NEW_ADDON"
    if f.closeBtn then f.closeBtn:Hide() end
    if f.viewConflictsBtn then f.viewConflictsBtn:Hide() end
    if f.reloadBtn then
        f.reloadBtn:SetSize(68, 24)
        f.reloadBtn:ClearAllPoints()
        f.reloadBtn:SetPoint("RIGHT", f, "RIGHT", -12, 0)
        if f.reloadBtn.label then f.reloadBtn.label:SetText("Open") end
    end
    ApplyToastPosition(f)
    if f.title then f.title:SetPoint("RIGHT", f.reloadBtn, "LEFT", -8, 0) end
    if f.badge then f.badge:SetPoint("RIGHT", f.reloadBtn, "LEFT", -8, 0) end
    if f.subtext then f.subtext:SetPoint("RIGHT", f.reloadBtn, "LEFT", -8, 0) end

    local _, _, _, bdg = GetToastColors()
    local bdgHex = RGBToHex(bdg.r, bdg.g, bdg.b)
    local count = #newAddons
    local firstName = newAddons[1]
    if count == 1 then
        f.title:SetText(string.format("%s: |cFF%sNew Addon Detected|r", GetToastTitlePrefix(), bdgHex))
        f.badge:SetText(string.format("|cFFFFFFFF%s|r assigned to |cFF%sOutdoor Safe Harbor|r", firstName, bdgHex))
    else
        f.title:SetText(string.format("%s: |cFF%s%d New Addons Detected|r", GetToastTitlePrefix(), bdgHex, count))
        f.badge:SetText(string.format("Assigned to |cFF%sOutdoor Safe Harbor|r to protect combat FPS", bdgHex))
    end
    f.subtext:SetText(string.format("|cFF%sClick [Open] to Configure|r    |cFF888888Right-Click: Dismiss|r", bdgHex))

    f.holdAnim:SetDuration(10)
    f:Show()
    f.animGroup:Play()
end
addonTable.ShowNewAddonsToast = ShowNewAddonsToast

local function ShowConflictToast(conflicts)
    if not conflicts or #conflicts == 0 then return end
    local f = CreateToastFrame()
    if f.isDraggingMode or f.isEditingMode then return end

    f.isRealAlert = true
    f.pendingConflicts = conflicts
    f.animGroup:Stop()
    f:SetAlpha(1)
    f.toastType = "CONFLICT_ALERT"
    ApplyToastPosition(f)

    if f.viewConflictsBtn then
        f.viewConflictsBtn:Hide()
    end
    if f.closeBtn then
        f.closeBtn:ClearAllPoints()
        f.closeBtn:SetPoint("RIGHT", f, "RIGHT", -10, 0)
        f.closeBtn:Show()
    end
    if f.reloadBtn then
        f.reloadBtn:SetSize(72, 24)
        f.reloadBtn:ClearAllPoints()
        if f.closeBtn then
            f.reloadBtn:SetPoint("RIGHT", f.closeBtn, "LEFT", -6, 0)
        else
            f.reloadBtn:SetPoint("RIGHT", f, "RIGHT", -10, 0)
        end
        f.reloadBtn:SetBackdropColor(0.961 * 0.28, 0.722 * 0.28, 0.180 * 0.12, 0.96)
        f.reloadBtn:SetBackdropBorderColor(0.961, 0.722, 0.180, 0.98)
        if f.reloadBtn.label then
            f.reloadBtn.label:SetText("Resolve")
            f.reloadBtn.label:SetTextColor(1, 1, 1, 1)
        end
    end

    local rightAnchor = f.reloadBtn
    if f.title then f.title:SetPoint("RIGHT", rightAnchor, "LEFT", -10, 0) end
    if f.badge then f.badge:SetPoint("RIGHT", rightAnchor, "LEFT", -10, 0) end
    if f.subtext then f.subtext:SetPoint("RIGHT", rightAnchor, "LEFT", -10, 0) end

    local goldHex = "F5B82E"
    local count = #conflicts
    local firstItem = conflicts[1]
    local firstFriendly = (firstItem and firstItem.friendlyName) or "Addon"
    local modName = (firstItem and firstItem.dynamicModule) or "DynamicSuite"
    if modName == "bags" then modName = "DynamicBags"
    elseif modName == "chat" then modName = "DynamicChat"
    elseif modName == "load" then modName = "DynamicLoad"
    elseif modName == "marker" then modName = "DynamicMarker"
    elseif modName == "zoom" then modName = "DynamicZoom"
    elseif modName == "fps" then modName = "DynamicFPS"
    elseif modName == "prep" then modName = "DynamicPrep"
    elseif modName == "group" then modName = "DynamicGroup" end

    if f.SetBackdropBorderColor then
        f:SetBackdropBorderColor(0.961, 0.722, 0.180, 0.95)
    end
    if count == 1 then
        f.title:SetText(string.format("%s: |cFF%sAddon Conflict Detected|r", GetToastTitlePrefix(), goldHex))
        f.badge:SetText(string.format("|cFFFFFFFF%s|r overlaps with |cFF%s%s|r", firstFriendly, goldHex, modName))
    else
        f.title:SetText(string.format("%s: |cFF%s%d Addon Conflicts Detected|r", GetToastTitlePrefix(), goldHex, count))
        f.badge:SetText(string.format("|cFFFFFFFF%s|r +%d more overlap with |cFF%s%s|r", firstFriendly, count - 1, goldHex, modName))
    end
    f.subtext:SetText(string.format("|cFF%sClick [Resolve] to Open Conflict Scanner|r  |cFF888888[X] or Right-Click: Dismiss|r", goldHex))
    f.badge:Show()
    f.subtext:Show()
    f:SetSize(486, 74)

    f.holdAnim:SetDuration(12)
    f:Show()
    f.animGroup:Play()
end
addonTable.ShowConflictToast = ShowConflictToast

local function ScanNewAddons()
    if not DynamicLoadDB then return end
    if not DynamicLoadDB.knownAddons then
        DynamicLoadDB.knownAddons = {}
    end
    DynamicLoadDB.knownAddons["DynamicFrame"] = true

    local num = C_AddOns.GetNumAddOns()
    local newAddons = {}

    local hasKnown = (next(DynamicLoadDB.knownAddons) ~= nil)
    if not hasKnown or DynamicLoadDB.firstRun then
        for i = 1, num do
            local name = C_AddOns.GetAddOnInfo(i)
            if name then
                DynamicLoadDB.knownAddons[name] = true
            end
        end
        DynamicLoadDB.firstRun = false
        return
    end

    for i = 1, num do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and not RETIRED_IGNORED_ADDONS[name] and not IsAddonProtected(name) and not IsStandaloneMarkerExcludedBySuite(name) then
            if not DynamicLoadDB.knownAddons[name] then
                DynamicLoadDB.knownAddons[name] = true
                table.insert(newAddons, name)

                if DynamicLoadDB.profiles and DynamicLoadDB.profiles[CONTEXT_OUTDOOR] then
                    if not DynamicLoadDB.profiles[CONTEXT_OUTDOOR].addons then
                        DynamicLoadDB.profiles[CONTEXT_OUTDOOR].addons = {}
                    end
                    DynamicLoadDB.profiles[CONTEXT_OUTDOOR].addons[name] = true
                end
            end
        end
    end

    if #newAddons > 0 then
        C_Timer.After(2.0, function()
            addonTable.ShowNewAddonsToast(newAddons)
        end)
    end
end
addonTable.ScanNewAddons = ScanNewAddons

function addonTable.IsToastMoving()
    return toastFrame and (toastFrame.isDraggingMode == true or toastFrame.isEditingMode == true)
end

function addonTable.StartToastMove()
    if InCombatLockdown and InCombatLockdown() then return end
    local f = CreateToastFrame()
    f.animGroup:Stop()
    f:SetAlpha(1)
    f.isDraggingMode = true
    ApplyToastPosition(f)
    RefreshToastContent(f)
    f:Show()
end

function addonTable.StopToastMove()
    local f = CreateToastFrame()
    f:StopMovingOrSizing()
    f.isDraggingMode = false
    if not f.isEditingMode then
        f:Hide()
    end
    f:SetAlpha(1)
    print(string.format("%s: Alert Toast position saved.", ADDON_TITLE))
end

function addonTable.ResetToastPosition()
    addonTable.SetToastPresetPosition("TOP", "TOP", 0, -50)
    print(string.format("%s: Alert Toast position reset to Top Center.", ADDON_TITLE))
end

function addonTable.ResetToastSettings()
    local g = EnsureSuiteGlobal()
    g.toastPos         = { point = "TOP", relPoint = "TOP", x = 0, y = -50 }
    g.toastScale       = 1.0
    g.toastAlpha       = 0.96
    g.toastDuration    = 8
    g.toastDisplayMode = "DETAILED"
    if DynamicLoadDB then
        DynamicLoadDB.toastPos         = CopyTable(g.toastPos)
        DynamicLoadDB.toastScale       = 1.0
        DynamicLoadDB.toastAlpha       = 0.96
        DynamicLoadDB.toastDuration    = 8
        DynamicLoadDB.toastDisplayMode = "DETAILED"
        DynamicLoadDB.toastHeaderText  = "DynamicLoad"
        addonTable.ApplyToastPreset("OBSIDIAN_SLATE")
    end
    local f = CreateToastFrame()
    ApplyToastPosition(f)
    print(string.format("%s: Alert Toast settings reset to defaults.", ADDON_TITLE))
end

--------------------------------------------------------------------------------
-- Snapshot & Addon Management API Precision
--------------------------------------------------------------------------------
local function SnapshotActiveAddons(targetProfileKey)
    local target = targetProfileKey or (DynamicLoadDB and DynamicLoadDB.activeProfile) or CONTEXT_OUTDOOR
    if not DynamicLoadDB.profiles[target] then
        DynamicLoadDB.profiles[target] = { name = CONTEXT_LABELS[target] or target, addons = {} }
    end

    local profile = DynamicLoadDB.profiles[target]
    profile.addons = {}

    local num = C_AddOns.GetNumAddOns()
    local pName = GetPlayer()

    for i = 1, num do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and not IsAddonProtected(name) and not IsAddonFrozen(name) then
            if IsStandaloneMarkerExcludedBySuite(name) then
                profile.addons[name] = false
            else
                local state = C_AddOns.GetAddOnEnableState(name, pName)
                profile.addons[name] = (state and state > 0) or false
            end
        end
    end
end
addonTable.SnapshotActiveAddons = SnapshotActiveAddons

--------------------------------------------------------------------------------
-- Character Auto-Ingestion & Alt Cloning Engine
--------------------------------------------------------------------------------
local function RecordCurrentCharacter()
    if not DynamicLoadDB then return end
    if not DynamicLoadDB.characters then DynamicLoadDB.characters = {} end

    local pName = UnitName("player")
    local realm = GetRealmName() or "Unknown"
    if not pName or pName == "" then return end
    local charKey = pName .. "-" .. realm
    local _, classFile = UnitClass("player")

    local addons = {}
    local num = C_AddOns.GetNumAddOns()
    for i = 1, num do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and not IsAddonProtected(name) and not IsStandaloneMarkerExcludedBySuite(name) then
            local state = C_AddOns.GetAddOnEnableState(name, pName)
            if state and state > 0 then
                addons[name] = true
            end
        end
    end

    DynamicLoadDB.characters[charKey] = {
        name = pName,
        realm = realm,
        class = classFile or "WARRIOR",
        addons = addons,
        lastSeen = time()
    }
end
addonTable.RecordCurrentCharacter = RecordCurrentCharacter

function addonTable.GetKnownCharacters()
    RecordCurrentCharacter()
    return DynamicLoadDB and DynamicLoadDB.characters or {}
end

function addonTable.CloneCharacterAddons(charKey, targetProfileKey)
    if not DynamicLoadDB or not DynamicLoadDB.characters or not DynamicLoadDB.characters[charKey] then
        return 0
    end
    local charData = DynamicLoadDB.characters[charKey]
    local profile = DynamicLoadDB.profiles and DynamicLoadDB.profiles[targetProfileKey]
    if not profile then return 0 end

    profile.addons = {}
    local count = 0
    for name, enabled in pairs(charData.addons or {}) do
        if enabled and not IsAddonFrozen(name) and not IsStandaloneMarkerExcludedBySuite(name) then
            profile.addons[name] = true
            count = count + 1
        end
    end
    return count
end

--------------------------------------------------------------------------------
-- 1-Click Stash & Restore Engine
--------------------------------------------------------------------------------
function addonTable.StashCurrentState()
    if not DynamicLoadDB then return end
    local pName = GetPlayer()
    local activeProfile = DynamicLoadDB.activeProfile or CONTEXT_OUTDOOR
    local currentProfile = DynamicLoadDB.profiles and DynamicLoadDB.profiles[activeProfile]
    local profileAddons = (currentProfile and currentProfile.addons) or {}

    local lockedCopy = {}
    for k, v in pairs(DynamicLoadDB.lockedAddons or {}) do lockedCopy[k] = v end

    local frozenCopy = {}
    for k, v in pairs(DynamicLoadDB.frozenAddons or {}) do frozenCopy[k] = v end

    local addonsCopy = {}
    for k, v in pairs(profileAddons) do addonsCopy[k] = v end

    local activeCount, lockedCount, frozenCount = 0, 0, 0
    for _, v in pairs(addonsCopy) do if v then activeCount = activeCount + 1 end end
    for _, v in pairs(lockedCopy) do if v then lockedCount = lockedCount + 1 end end
    for _, v in pairs(frozenCopy) do if v then frozenCount = frozenCount + 1 end end

    DynamicLoadDB.stash = {
        timestamp = time(),
        charKey = pName .. "-" .. (GetRealmName() or ""),
        activeProfile = activeProfile,
        locked = lockedCopy,
        frozen = frozenCopy,
        addons = addonsCopy,
        counts = {
            active = activeCount,
            locked = lockedCount,
            frozen = frozenCount,
        }
    }

    print(string.format("%s: State backed up (%d active, %d locked, %d frozen).", ADDON_TITLE, activeCount, lockedCount, frozenCount))
    return DynamicLoadDB.stash
end

function addonTable.HasStash()
    return DynamicLoadDB and DynamicLoadDB.stash ~= nil
end

function addonTable.GetStashInfo()
    return DynamicLoadDB and DynamicLoadDB.stash
end

function addonTable.ClearStash()
    if DynamicLoadDB then
        DynamicLoadDB.stash = nil
        DynamicLoadDB.stashedAddons = nil
        DynamicLoadDB.stashedCount = nil
        print(string.format("%s: Debug concluded: kept current addon selections and cleared backup snapshot.", ADDON_TITLE))
    end
end

function addonTable.RestoreStash()
    if not DynamicLoadDB or not DynamicLoadDB.stash then return 0, nil, 0 end
    local stash = DynamicLoadDB.stash
    local activeRestoredCount = (stash.counts and stash.counts.active) or 0

    DynamicLoadDB.lockedAddons = DynamicLoadDB.lockedAddons or {}
    DynamicLoadDB.frozenAddons = DynamicLoadDB.frozenAddons or {}
    DynamicLoadDB.addonStates  = DynamicLoadDB.addonStates or {}
    wipe(DynamicLoadDB.lockedAddons)
    wipe(DynamicLoadDB.frozenAddons)
    wipe(DynamicLoadDB.addonStates)
    if DynamicLoadDB.globalData and GetCharScopeMode() ~= "CHARACTER" then
        if DynamicLoadDB.globalData.lockedAddons then wipe(DynamicLoadDB.globalData.lockedAddons) end
        if DynamicLoadDB.globalData.frozenAddons then wipe(DynamicLoadDB.globalData.frozenAddons) end
        if DynamicLoadDB.globalData.addonStates then wipe(DynamicLoadDB.globalData.addonStates) end
    end

    for k, v in pairs(stash.locked or {}) do
        if v then SetAddonLocked(k, true) end
    end
    for k, v in pairs(stash.frozen or {}) do
        if v then SetAddonFrozen(k, true) end
    end

    local targetKey = stash.activeProfile or (DynamicLoadDB.activeProfile or CONTEXT_OUTDOOR)
    if not DynamicLoadDB.profiles then DynamicLoadDB.profiles = {} end
    if not DynamicLoadDB.profiles[targetKey] then
        DynamicLoadDB.profiles[targetKey] = { name = CONTEXT_LABELS[targetKey] or targetKey, addons = {} }
    end
    DynamicLoadDB.profiles[targetKey].addons = DynamicLoadDB.profiles[targetKey].addons or {}
    wipe(DynamicLoadDB.profiles[targetKey].addons)
    for k, v in pairs(stash.addons or {}) do
        local canon = ResolveCanonicalAddonName(k) or k
        if IsStandaloneMarkerExcludedBySuite(canon) then
            DynamicLoadDB.profiles[targetKey].addons[canon] = false
        elseif not IsAddonFrozen(canon) then
            DynamicLoadDB.profiles[targetKey].addons[canon] = v
        end
    end

    -- Clear the saved backup snapshot so debug mode is concluded and the button returns to 'Backup State'
    DynamicLoadDB.stash = nil
    DynamicLoadDB.stashedAddons = nil
    DynamicLoadDB.stashedCount = nil

    local delta = addonTable.StageAddonProfile(targetKey)
    print(string.format("%s: Restored %d backed-up addons and concluded debug snapshot (Click Reload UI to apply).", ADDON_TITLE, activeRestoredCount))
    return delta, stash, activeRestoredCount
end

--------------------------------------------------------------------------------
-- Addon Delta & Profile Staging Engine
--------------------------------------------------------------------------------
local liveSessionEnabled = {}

local function CaptureLiveSessionBaseline()
    liveSessionEnabled = {}
    local pName = GetPlayer()
    local num = C_AddOns.GetNumAddOns()
    for i = 1, num do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and name ~= "DynamicFrame" and not IsAddonProtected(name) then
            if IsStandaloneMarkerExcludedBySuite(name) then
                liveSessionEnabled[name] = false
            else
                local isEnabled = ((C_AddOns.GetAddOnEnableState(name, pName) or 0) > 0) or C_AddOns.IsAddOnLoaded(name)
                liveSessionEnabled[name] = (isEnabled == true)
            end
        end
    end
end
addonTable.CaptureLiveSessionBaseline = CaptureLiveSessionBaseline

local function CalculateAddonDelta(targetProfileKey)
    local profile = DynamicLoadDB and DynamicLoadDB.profiles and DynamicLoadDB.profiles[targetProfileKey]
    if not profile or not profile.addons then return 0, {}, {} end

    local deltaCount = 0
    local changes = {}
    local desiredMap = {}
    local pName = GetPlayer()
    local num = C_AddOns.GetNumAddOns()

    -- Pass 1: Evaluate individual addon intent (Frozen always wins OFF, Locked always wins ON)
    for i = 1, num do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and name ~= "DynamicFrame" and not IsAddonProtected(name) then
            local desiredState = profile.addons[name]
            if IsStandaloneMarkerExcludedBySuite(name) then
                desiredState = false
                profile.addons[name] = false
            elseif IsAddonFrozen(name) then
                desiredState = false
                profile.addons[name] = nil
            elseif IsAddonLocked(name) then
                desiredState = true
            else
                desiredState = (desiredState == true)
            end
            desiredMap[name] = desiredState
        end
    end

    -- Pass 2: Deterministic Fixed-Point Upward Auto-Core & Dependency Engine
    for _ = 1, 4 do
        local changed = false
        for name, isDesired in pairs(desiredMap) do
            if isDesired then
                local parent = addonTable.GetAddonParent and addonTable.GetAddonParent(name)
                if parent and desiredMap[parent] == false and not IsAddonFrozen(parent) and not IsStandaloneMarkerExcludedBySuite(parent) then
                    desiredMap[parent] = true
                    changed = true
                end
                if C_AddOns.GetAddOnDependencies then
                    for dIdx = 1, select("#", C_AddOns.GetAddOnDependencies(name)) do
                        local depName = select(dIdx, C_AddOns.GetAddOnDependencies(name))
                        if depName and desiredMap[depName] == false and not IsAddonFrozen(depName) and not IsStandaloneMarkerExcludedBySuite(depName) then
                            desiredMap[depName] = true
                            changed = true
                        end
                    end
                end
            end
        end
        if not changed then break end
    end

    if IsStandaloneMarkerExcludedBySuite("DynamicMarker") then
        desiredMap["DynamicMarker"] = false
        profile.addons["DynamicMarker"] = false
    end

    -- Pass 3: Compute delta against current live UI session baseline
    for i = 1, num do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and name ~= "DynamicFrame" and not IsAddonProtected(name) then
            local currentState = liveSessionEnabled[name]
            if currentState == nil then
                currentState = ((C_AddOns.GetAddOnEnableState(name, pName) or 0) > 0)
            end
            local desiredState = (desiredMap[name] == true)
            if currentState ~= desiredState then
                deltaCount = deltaCount + 1
                changes[name] = desiredState
            end
        end
    end

    return deltaCount, changes, desiredMap
end
addonTable.CalculateAddonDelta = CalculateAddonDelta

local function ReconcileStartupProfileBaseline(profileKey)
    if not DynamicLoadDB or not DynamicLoadDB.profiles then return end
    local key = profileKey or DynamicLoadDB.activeProfile or CONTEXT_OUTDOOR
    local profile = DynamicLoadDB.profiles[key]
    if not profile then return end
    profile.addons = profile.addons or {}

    EnforceFrozenAddonsDisabled()
    CaptureLiveSessionBaseline()
    local num = C_AddOns.GetNumAddOns()
    local known = DynamicLoadDB.knownAddons
    for i = 1, num do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and name ~= "DynamicFrame" and not IsAddonProtected(name) then
            if IsStandaloneMarkerExcludedBySuite(name) then
                profile.addons[name] = false
                liveSessionEnabled[name] = false
            elseif IsAddonFrozen(name) then
                profile.addons[name] = nil
                liveSessionEnabled[name] = false
            elseif not IsAddonLocked(name) then
                local isAlreadyKnown = (known and known[name] == true)
                local hasSavedMode = (DynamicLoadDB.addonStates and DynamicLoadDB.addonStates[name] ~= nil)
                if not isAlreadyKnown and not hasSavedMode and profile.addons[name] == nil then
                    profile.addons[name] = (liveSessionEnabled[name] == true)
                end
            end
        end
    end

    local _, _, desiredMap = CalculateAddonDelta(key)
    if desiredMap then
        for name, desiredState in pairs(desiredMap) do
            liveSessionEnabled[name] = (desiredState == true)
        end
    end
end
addonTable.ReconcileStartupProfileBaseline = ReconcileStartupProfileBaseline

local lastStagedProfile = nil

local function StageAddonProfile(targetProfileKey, setAsActive)
    EnforceProtectedSuiteModules()
    EnforceFrozenAddonsDisabled()
    local deltaCount, _, desiredMap = CalculateAddonDelta(targetProfileKey)
    if not desiredMap then return 0 end
    if IsStandaloneMarkerExcludedBySuite("DynamicMarker") then
        desiredMap["DynamicMarker"] = false
        if DynamicLoadDB and DynamicLoadDB.profiles and DynamicLoadDB.profiles[targetProfileKey] and DynamicLoadDB.profiles[targetProfileKey].addons then
            DynamicLoadDB.profiles[targetProfileKey].addons["DynamicMarker"] = false
        end
    end

    local pName = GetPlayer()
    local num = C_AddOns.GetNumAddOns()

    for i = 1, num do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and name ~= "DynamicFrame" and not IsAddonProtected(name) then
            local shouldEnable = (desiredMap[name] == true) and not IsAddonFrozen(name) and not IsStandaloneMarkerExcludedBySuite(name)
            if shouldEnable then
                C_AddOns.EnableAddOn(name, pName)
                if (C_AddOns.GetAddOnEnableState(name, pName) or 0) == 0 then
                    C_AddOns.EnableAddOn(name)
                end
            else
                if IsStandaloneMarkerExcludedBySuite(name) and DynamicLoadDB and DynamicLoadDB.profiles and DynamicLoadDB.profiles[targetProfileKey] and DynamicLoadDB.profiles[targetProfileKey].addons then
                    DynamicLoadDB.profiles[targetProfileKey].addons[name] = false
                end
                C_AddOns.DisableAddOn(name, pName)
                if (C_AddOns.GetAddOnEnableState(name, pName) or 0) > 0 then
                    C_AddOns.DisableAddOn(name)
                end
            end
        end
    end

    EnforceFrozenAddonsDisabled()
    lastStagedProfile = targetProfileKey

    if DynamicLoadDB then
        if deltaCount == 0 then
            DynamicLoadDB.stagedProfile = nil
            if setAsActive ~= false then
                DynamicLoadDB.loadedProfile = targetProfileKey
                DynamicLoadDB.activeProfile = targetProfileKey
            end
        else
            DynamicLoadDB.stagedProfile = targetProfileKey
        end
    end
    return deltaCount
end
addonTable.StageAddonProfile = StageAddonProfile

function addonTable.ApplyProfile(arg1, arg2, arg3)
    local profileKey, shouldReload
    if arg1 == addonTable then
        profileKey, shouldReload = arg2, arg3
    else
        profileKey, shouldReload = arg1, arg2
    end
    if not profileKey or not DynamicLoadDB then return 0 end
    hasShownToastThisLoadSession = false
    pendingToastAfterCombat = false
    local physicalEnv = addonTable.EvaluateCurrentEnvironment and addonTable.EvaluateCurrentEnvironment() or CONTEXT_OUTDOOR
    if profileKey ~= physicalEnv then
        DynamicLoadDB.manualOverride = true
    else
        DynamicLoadDB.manualOverride = false
    end
    local deltaCount = StageAddonProfile(profileKey, false)
    if deltaCount == 0 then
        DynamicLoadDB.loadedProfile = profileKey
        DynamicLoadDB.activeProfile = profileKey
        DynamicLoadDB.stagedProfile = nil
    else
        DynamicLoadDB.stagedProfile = profileKey
    end
    if addonTable.SetSelectedTabKey then
        addonTable.SetSelectedTabKey(profileKey)
    end
    if shouldReload then
        DynamicLoadDB.stagedProfile = profileKey
        ReloadUI()
    end
    return deltaCount
end

--------------------------------------------------------------------------------
-- Dual-Scope Reset Architecture (Gate 17 / Gate 20)
--------------------------------------------------------------------------------
function addonTable.ResetDynamicLoad()
    DynamicLoadDB = CopyTable(DEFAULT_DB)
    DynamicLoadDB.firstRun = false
    DynamicLoadDB.loadedProfile = CONTEXT_OUTDOOR
    DynamicLoadDB.manualOverride = false
    DynamicLoadDB.activeProfile = CONTEXT_OUTDOOR
    local num = C_AddOns.GetNumAddOns()
    for i = 1, num do
        local name = C_AddOns.GetAddOnInfo(i)
        if name then
            DynamicLoadDB.knownAddons[name] = true
        end
    end
    SnapshotActiveAddons(CONTEXT_OUTDOOR)
    RecordCurrentCharacter()
    addonTable.ResetToastPosition()
    print(string.format("%s: DynamicLoad profiles, locks, and freezes reset to clean defaults.", ADDON_TITLE))
end


--------------------------------------------------------------------------------
-- Environment Detection Logic
--------------------------------------------------------------------------------
local function EvaluateCurrentEnvironment()
    local inInstance, instanceType = IsInInstance()

    if inInstance then
        if instanceType == "arena" or instanceType == "pvp" then
            return CONTEXT_PVP
        elseif instanceType == "raid" then
            return CONTEXT_RAID
        elseif instanceType == "party" then
            return CONTEXT_DUNGEON
        elseif instanceType == "scenario" then
            return CONTEXT_DELVE
        end
    end

    if C_DelvesUI and C_DelvesUI.HasActiveDelve and C_DelvesUI.HasActiveDelve() then
        return CONTEXT_DELVE
    end

    return CONTEXT_OUTDOOR
end
addonTable.EvaluateCurrentEnvironment = EvaluateCurrentEnvironment
addonTable.GetCurrentContext = EvaluateCurrentEnvironment
addonTable.GetPhysicalLocation = EvaluateCurrentEnvironment

function addonTable.GetLoadedProfile()
    return (DynamicLoadDB and DynamicLoadDB.loadedProfile) or (DynamicLoadDB and DynamicLoadDB.activeProfile) or CONTEXT_OUTDOOR
end

function addonTable.IsManualOverrideActive()
    return (DynamicLoadDB and DynamicLoadDB.manualOverride == true) or false
end

local ApplyEnvironmentContext

function addonTable.ResumeAutoSwitch()
    if not DynamicLoadDB then return end
    DynamicLoadDB.manualOverride = false
    hasShownToastThisLoadSession = false
    pendingToastAfterCombat = false
    local physicalEnv = EvaluateCurrentEnvironment()
    local naturalProfile = (DynamicLoadDB.rules and DynamicLoadDB.rules[physicalEnv]) or physicalEnv
    if not DynamicLoadDB.profiles or not DynamicLoadDB.profiles[naturalProfile] then
        naturalProfile = CONTEXT_OUTDOOR
    end
    ApplyEnvironmentContext(true)
    local deltaCount = StageAddonProfile(naturalProfile, false)
    if deltaCount == 0 then
        DynamicLoadDB.loadedProfile = naturalProfile
        DynamicLoadDB.activeProfile = naturalProfile
        DynamicLoadDB.stagedProfile = nil
    else
        DynamicLoadDB.stagedProfile = naturalProfile
    end
    if addonTable.SetSelectedTabKey then
        addonTable.SetSelectedTabKey(naturalProfile)
    end
    if addonTable.UpdateAllTabVisuals then
        addonTable.UpdateAllTabVisuals()
    end
    if addonTable.mainFrame and addonTable.mainFrame.UpdateStatusBar then
        addonTable.mainFrame.UpdateStatusBar()
    end
end

local function GetEnvironmentDetail()
    local env = EvaluateCurrentEnvironment()
    local label = CONTEXT_LABELS[env] or env
    if env == CONTEXT_OUTDOOR then
        if IsResting and IsResting() then
            return label .. " (City Hub)"
        else
            return label .. " (Wilderness)"
        end
    end
    return label
end
addonTable.GetEnvironmentDetail = GetEnvironmentDetail

local function RefreshAllStatusAndTabs()
    if addonTable.UpdateAllTabVisuals then
        addonTable.UpdateAllTabVisuals()
    end
    if addonTable.mainFrame and addonTable.mainFrame.UpdateStatusBar then
        addonTable.mainFrame.UpdateStatusBar()
    end
end

ApplyEnvironmentContext = function(allowToast)
    if not DynamicLoadDB then return end

    local isPostLoadingScreen = (allowToast == true)
    local physicalEnv = EvaluateCurrentEnvironment()
    local naturalProfile = (DynamicLoadDB.rules and DynamicLoadDB.rules[physicalEnv]) or physicalEnv
    if not DynamicLoadDB.profiles or not DynamicLoadDB.profiles[naturalProfile] then
        naturalProfile = CONTEXT_OUTDOOR
    end

    if DynamicLoadDB.manualOverride == true then
        if physicalEnv == "dungeon" or physicalEnv == "raid" or physicalEnv == "pvp" or physicalEnv == "delve" then
            DynamicLoadDB.manualOverride = false
        else
            local manualProf = DynamicLoadDB.stagedProfile or DynamicLoadDB.loadedProfile or DynamicLoadDB.activeProfile or CONTEXT_OUTDOOR
            local deltaCount = StageAddonProfile(manualProf, false)
            if deltaCount == 0 then
                DynamicLoadDB.loadedProfile = manualProf
                DynamicLoadDB.activeProfile = manualProf
                DynamicLoadDB.stagedProfile = nil
            else
                DynamicLoadDB.stagedProfile = manualProf
            end
            RefreshAllStatusAndTabs()
            return
        end
    end

    if not DynamicLoadDB.autoSwitch then
        RefreshAllStatusAndTabs()
        return
    end

    local targetProfile = naturalProfile
    local currentActive = DynamicLoadDB.loadedProfile or DynamicLoadDB.activeProfile or CONTEXT_OUTDOOR

    if DynamicLoadDB.silentOnMatch and currentActive == targetProfile then
        local deltaCount = CalculateAddonDelta(targetProfile)
        if deltaCount == 0 then
            DynamicLoadDB.loadedProfile = targetProfile
            DynamicLoadDB.activeProfile = targetProfile
            DynamicLoadDB.stagedProfile = nil
            RefreshAllStatusAndTabs()
            return
        end
    end

    if InCombatLockdown() then
        pendingProfile = targetProfile
        DynamicLoadDB.stagedProfile = targetProfile
        if isPostLoadingScreen and not hasShownToastThisLoadSession then
            pendingToastAfterCombat = true
        end
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        RefreshAllStatusAndTabs()
        return
    end

    local deltaCount = StageAddonProfile(targetProfile, false)
    if deltaCount == 0 then
        DynamicLoadDB.loadedProfile = targetProfile
        DynamicLoadDB.activeProfile = targetProfile
        DynamicLoadDB.stagedProfile = nil
    else
        DynamicLoadDB.stagedProfile = targetProfile
    end
    if addonTable.SetSelectedTabKey then
        addonTable.SetSelectedTabKey(targetProfile)
    end
    RefreshAllStatusAndTabs()
    if deltaCount > 0 and isPostLoadingScreen and not hasShownToastThisLoadSession then
        hasShownToastThisLoadSession = true
        pendingToastAfterCombat = false
        ShowToast(targetProfile, deltaCount)
    end
end
addonTable.ApplyEnvironmentContext = ApplyEnvironmentContext

local isCommittingBeforeReload = false
local function CommitPendingProfileBeforeReload()
    if isCommittingBeforeReload or not DynamicLoadDB then return end
    isCommittingBeforeReload = true
    EnforceFrozenAddonsDisabled()
    local targetKey = nil
    if addonTable.GetSelectedTabForReload then
        targetKey = addonTable.GetSelectedTabForReload()
    end
    if not targetKey and DynamicLoadDB.autoSwitch == true and DynamicLoadDB.manualOverride ~= true then
        local physicalEnv = EvaluateCurrentEnvironment()
        local naturalProfile = (DynamicLoadDB.rules and DynamicLoadDB.rules[physicalEnv]) or physicalEnv
        if DynamicLoadDB.profiles and DynamicLoadDB.profiles[naturalProfile] then
            targetKey = naturalProfile
        end
    end
    if not targetKey and DynamicLoadDB.stagedProfile and DynamicLoadDB.profiles and DynamicLoadDB.profiles[DynamicLoadDB.stagedProfile] then
        targetKey = DynamicLoadDB.stagedProfile
    end
    if not targetKey and lastStagedProfile and DynamicLoadDB.profiles and DynamicLoadDB.profiles[lastStagedProfile] then
        targetKey = lastStagedProfile
    end
    if targetKey and DynamicLoadDB.profiles and DynamicLoadDB.profiles[targetKey] then
        local physicalEnv = EvaluateCurrentEnvironment()
        local naturalProfile = (DynamicLoadDB.rules and DynamicLoadDB.rules[physicalEnv]) or physicalEnv
        DynamicLoadDB.manualOverride = (targetKey ~= physicalEnv and targetKey ~= naturalProfile)
        DynamicLoadDB.stagedProfile = targetKey
        StageAddonProfile(targetKey, false)
        DynamicLoadDB.stagedProfile = targetKey
    end
    EnforceFrozenAddonsDisabled()
    if addonTable._pendingDisableCoreAddon and C_AddOns and C_AddOns.DisableAddOn then
        local pName = GetPlayer()
        pcall(C_AddOns.DisableAddOn, addonTable._pendingDisableCoreAddon, pName)
        pcall(C_AddOns.DisableAddOn, addonTable._pendingDisableCoreAddon)
    end
    isCommittingBeforeReload = false
end
addonTable.CommitPendingProfileBeforeReload = CommitPendingProfileBeforeReload

if hooksecurefunc then
    if type(ReloadUI) == "function" then
        hooksecurefunc("ReloadUI", CommitPendingProfileBeforeReload)
    end
    if C_UI and type(C_UI.Reload) == "function" then
        hooksecurefunc(C_UI, "Reload", CommitPendingProfileBeforeReload)
    end
end

local function ScheduleEnvironmentCheck(isPostLoadingScreen)
    if isPostLoadingScreen == true then
        pendingPostLoadToast = true
    end
    if debounceTimer then
        debounceTimer:Cancel()
    end
    local settleDelay = pendingPostLoadToast and 0.65 or 0.5
    debounceTimer = C_Timer.NewTimer(settleDelay, function()
        debounceTimer = nil
        if isInsideLoadingScreen then
            return
        end
        local allowToast = (pendingPostLoadToast == true)
        pendingPostLoadToast = false
        ApplyEnvironmentContext(allowToast)
    end)
end
addonTable.ScheduleEnvironmentCheck = ScheduleEnvironmentCheck

--------------------------------------------------------------------------------
-- Event Routing & Startup Initialization
--------------------------------------------------------------------------------
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("LOADING_SCREEN_ENABLED")
eventFrame:RegisterEvent("LOADING_SCREEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SCENARIO_UPDATE")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

local function PurgeRetiredAddons()
    local pName = GetPlayer()
    if C_AddOns and C_AddOns.DisableAddOn then
        pcall(C_AddOns.DisableAddOn, "DynamicFrame", pName)
        pcall(C_AddOns.DisableAddOn, "DynamicFrame")
    end
    if DynamicLoadDB then
        if DynamicLoadDB.profiles then
            for _, prof in pairs(DynamicLoadDB.profiles) do
                if prof.addons then
                    prof.addons["DynamicFrame"] = nil
                end
            end
        end
        DynamicLoadDB.knownAddons = DynamicLoadDB.knownAddons or {}
        DynamicLoadDB.knownAddons["DynamicFrame"] = true
        DynamicLoadDB.addonStates = DynamicLoadDB.addonStates or {}
        DynamicLoadDB.addonStates["DynamicFrame"] = "FROZEN"
        DynamicLoadDB.frozenAddons = DynamicLoadDB.frozenAddons or {}
        DynamicLoadDB.frozenAddons["DynamicFrame"] = true
        if DynamicLoadDB.lockedAddons then
            DynamicLoadDB.lockedAddons["DynamicFrame"] = nil
        end
    end
end
addonTable.PurgeRetiredAddons = PurgeRetiredAddons

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and (arg1 == ADDON_FOLDER or arg1 == "DynamicLoad") and not isInitialized then
        isInitialized = true
        if not DynamicLoadDB then
            DynamicLoadDB = CopyTable(DEFAULT_DB)
        else
            if DynamicLoadDB.loadedProfile == nil and DynamicLoadDB.activeProfile ~= nil then
                DynamicLoadDB.loadedProfile = DynamicLoadDB.activeProfile
            end
            if DynamicLoadDB.manualOverride == nil and DynamicLoadDB.manualOverrideContext ~= nil then
                DynamicLoadDB.manualOverride = (DynamicLoadDB.loadedProfile ~= DynamicLoadDB.manualOverrideContext)
            end
            DynamicLoadDB.manualOverrideContext = nil

            for k, v in pairs(DEFAULT_DB) do
                if DynamicLoadDB[k] == nil then
                    if type(v) == "table" then
                        DynamicLoadDB[k] = CopyTable(v)
                    else
                        DynamicLoadDB[k] = v
                    end
                end
            end
        end

        if DynamicLoadDB.loadedProfile == nil then
            DynamicLoadDB.loadedProfile = DynamicLoadDB.activeProfile or CONTEXT_OUTDOOR
        end
        if DynamicLoadDB.manualOverride == nil then
            DynamicLoadDB.manualOverride = false
        end

        local g = EnsureSuiteGlobal()

        -- Expand Default Window Width to 1040x680 (+60px Content Area) & Enforce Minimum Bounds (980x640 to 1440x920)
        if not g.v120_windowWidth1040 then
            g.v120_windowWidth1040 = true
            if not g.windowWidth or g.windowWidth <= 980 then
                g.windowWidth = 1040
            end
        end
        if not DynamicLoadDB.v120_windowWidth1040 then
            DynamicLoadDB.v120_windowWidth1040 = true
            if not DynamicLoadDB.windowWidth or DynamicLoadDB.windowWidth <= 980 then
                DynamicLoadDB.windowWidth = 1040
            end
        end
        if not g.windowWidth or g.windowWidth < 980 then g.windowWidth = 1040 end
        if not g.windowHeight or g.windowHeight < 640 then g.windowHeight = 680 end
        if not DynamicLoadDB.windowWidth or DynamicLoadDB.windowWidth < 980 then DynamicLoadDB.windowWidth = 1040 end
        if not DynamicLoadDB.windowHeight or DynamicLoadDB.windowHeight < 640 then DynamicLoadDB.windowHeight = 680 end

        -- Approach 12A Migration: Clear auto-locked third-party addons so only DynamicSuite modules default to CORE
        if not DynamicLoadDB.v120_approach12ACleanLocks then
            DynamicLoadDB.v120_approach12ACleanLocks = true
            if DynamicLoadDB.lockedAddons then wipe(DynamicLoadDB.lockedAddons) end
            if DynamicLoadDB.addonStates then
                for k, v in pairs(DynamicLoadDB.addonStates) do
                    if v == "LOCKED" and not PROTECTED_ADDONS[k] then
                        DynamicLoadDB.addonStates[k] = "NORMAL"
                    end
                end
            end
            if DynamicLoadDB.globalData then
                if DynamicLoadDB.globalData.lockedAddons then wipe(DynamicLoadDB.globalData.lockedAddons) end
                if DynamicLoadDB.globalData.addonStates then
                    for k, v in pairs(DynamicLoadDB.globalData.addonStates) do
                        if v == "LOCKED" and not PROTECTED_ADDONS[k] then
                            DynamicLoadDB.globalData.addonStates[k] = "NORMAL"
                        end
                    end
                end
            end
        end

        local hasExistingData = false
        if DynamicLoadDB.profiles then
            for _, prof in pairs(DynamicLoadDB.profiles) do
                if prof.addons and next(prof.addons) ~= nil then
                    hasExistingData = true
                    break
                end
            end
        end

        if hasExistingData or (DynamicLoadDB.version and DynamicLoadDB.version >= 2) then
            DynamicLoadDB.firstRun = false
        end

        if not DynamicLoadDB.knownAddons or next(DynamicLoadDB.knownAddons) == nil then
            DynamicLoadDB.knownAddons = {}
            local num = C_AddOns.GetNumAddOns()
            for i = 1, num do
                local name = C_AddOns.GetAddOnInfo(i)
                if name then
                    DynamicLoadDB.knownAddons[name] = true
                end
            end
        end

        DynamicLoadDB.version = 4
        if DynamicLoadDB.profiles and DynamicLoadDB.profiles[CONTEXT_DUNGEON] then
            DynamicLoadDB.profiles[CONTEXT_DUNGEON].name = "Dungeons"
        end
        DynamicLoadDB.recentColors = DynamicLoadDB.recentColors or {}
        DynamicLoadDB.collapsedParents = DynamicLoadDB.collapsedParents or {}
        DynamicLoadDB.moduleOrder = DynamicLoadDB.moduleOrder or nil

        SyncScopeBindings()
        PurgeRetiredAddons()
        SyncAddonStatesTable()
        if not DynamicLoadDB.v120_enableDynamicChatCore then
            DynamicLoadDB.v120_enableDynamicChatCore = true
            if g.disabledModules then
                g.disabledModules["DynamicChat"] = nil
                g.disabledModules["chat"] = nil
            end
            if _G.DynamicSuiteDB and _G.DynamicSuiteDB.disabledModules then
                _G.DynamicSuiteDB.disabledModules["DynamicChat"] = nil
                _G.DynamicSuiteDB.disabledModules["chat"] = nil
            end
        end
        EnforceProtectedSuiteModules()
        EnforceFrozenAddonsDisabled()
        SyncScopeBindings()
        SyncAddonStatesTable()
        CaptureLiveSessionBaseline()
        addonTable.SanitizeLegacyCVar()
        RecordCurrentCharacter()
        if addonTable.HookGameMenu then
            addonTable.HookGameMenu()
        end

        if DynamicLoadDB.firstRun then
            SnapshotActiveAddons(CONTEXT_OUTDOOR)
            DynamicLoadDB.firstRun = false
        end

    elseif event == "PLAYER_LOGIN" then
        EnsureSuiteGlobal()
        SyncScopeBindings()
        PurgeRetiredAddons()
        EnforceProtectedSuiteModules()
        EnforceFrozenAddonsDisabled()
        SyncScopeBindings()
        SyncAddonStatesTable()
        CaptureLiveSessionBaseline()
        addonTable.SanitizeLegacyCVar()
        RecordCurrentCharacter()
        SyncAddonStatesTable()
        local startupProf = (DynamicLoadDB and DynamicLoadDB.stagedProfile) or (DynamicLoadDB and DynamicLoadDB.loadedProfile) or (DynamicLoadDB and DynamicLoadDB.activeProfile) or CONTEXT_OUTDOOR
        if DynamicLoadDB then
            if not DynamicLoadDB.profiles or not DynamicLoadDB.profiles[startupProf] then
                startupProf = CONTEXT_OUTDOOR
            end
            DynamicLoadDB.stagedProfile = nil
            DynamicLoadDB.loadedProfile = startupProf
            DynamicLoadDB.activeProfile = startupProf
            if CalculateAddonDelta(startupProf) == 0 then
                ReconcileStartupProfileBaseline(startupProf)
            end
            StageAddonProfile(startupProf, true)
        end
        EnforceFrozenAddonsDisabled()
        if addonTable.HookGameMenu then
            addonTable.HookGameMenu()
        end
        C_Timer.After(0.15, function()
            EnforceFrozenAddonsDisabled()
            if addonTable.ReassertSuiteSlashRouting then
                addonTable.ReassertSuiteSlashRouting()
            end
        end)
        C_Timer.After(2.0, function()
            EnforceFrozenAddonsDisabled()
            addonTable.ScanNewAddons()
        end)

    elseif event == "LOADING_SCREEN_ENABLED" then
        isInsideLoadingScreen = true
        hasShownToastThisLoadSession = false
        pendingToastAfterCombat = false
        pendingPostLoadToast = true
        if debounceTimer then
            debounceTimer:Cancel()
            debounceTimer = nil
        end
        if loadingScreenSafetyTimer then
            loadingScreenSafetyTimer:Cancel()
            loadingScreenSafetyTimer = nil
        end
        loadingScreenSafetyTimer = C_Timer.NewTimer(15.0, function()
            loadingScreenSafetyTimer = nil
            isInsideLoadingScreen = false
        end)

    elseif event == "LOADING_SCREEN_DISABLED" then
        isInsideLoadingScreen = false
        if loadingScreenSafetyTimer then
            loadingScreenSafetyTimer:Cancel()
            loadingScreenSafetyTimer = nil
        end
        EnforceFrozenAddonsDisabled()
        ScheduleEnvironmentCheck(true)

    elseif event == "PLAYER_ENTERING_WORLD" then
        isInsideLoadingScreen = false
        if loadingScreenSafetyTimer then
            loadingScreenSafetyTimer:Cancel()
            loadingScreenSafetyTimer = nil
        end
        if arg1 == true or arg2 == true then
            hasShownToastThisLoadSession = false
            pendingToastAfterCombat = false
            C_Timer.After(2.5, function()
                if addonTable.GetUnresolvedActionRequiredConflicts and addonTable.ShowConflictToast then
                    local unresolved = addonTable.GetUnresolvedActionRequiredConflicts()
                    if type(unresolved) == "table" and #unresolved > 0 then
                        addonTable.ShowConflictToast(unresolved)
                    end
                end
            end)
        end
        EnforceFrozenAddonsDisabled()
        ScheduleEnvironmentCheck(true)

    elseif event == "SCENARIO_UPDATE" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        isInsideLoadingScreen = false
        if loadingScreenSafetyTimer then
            loadingScreenSafetyTimer:Cancel()
            loadingScreenSafetyTimer = nil
        end
        ScheduleEnvironmentCheck(false)

    elseif event == "PLAYER_REGEN_DISABLED" then
        isInsideLoadingScreen = false
        if loadingScreenSafetyTimer then
            loadingScreenSafetyTimer:Cancel()
            loadingScreenSafetyTimer = nil
        end
        if toastFrame and (toastFrame.isDraggingMode or toastFrame.isEditingMode) then
            toastFrame:StopMovingOrSizing()
            toastFrame.isDraggingMode = false
            toastFrame.isEditingMode = false
            if toastFrame.SetClampedToScreen then
                toastFrame:SetClampedToScreen(true)
            end
            toastFrame:Hide()
            toastFrame:SetAlpha(1)
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        local shouldToast = (pendingToastAfterCombat == true) and not hasShownToastThisLoadSession
        pendingToastAfterCombat = false
        if pendingProfile then
            local target = pendingProfile
            pendingProfile = nil
            local deltaCount = StageAddonProfile(target, false)
            if deltaCount == 0 then
                DynamicLoadDB.loadedProfile = target
                DynamicLoadDB.activeProfile = target
                DynamicLoadDB.stagedProfile = nil
            else
                DynamicLoadDB.stagedProfile = target
            end
            if addonTable.SetSelectedTabKey then
                addonTable.SetSelectedTabKey(target)
            end
            RefreshAllStatusAndTabs()
            if deltaCount > 0 and shouldToast then
                hasShownToastThisLoadSession = true
                ShowToast(target, deltaCount)
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- Slash Commands (/dl, /dynamicload, /ds, /dynamicsuite)
--------------------------------------------------------------------------------
local function OpenMainSuiteWindowFallback()
    if DynamicSuite._isHubLoaded and addonTable.ShowConfigUI then
        if _G.DynamicSuiteMainFrame and _G.DynamicSuiteMainFrame:IsShown() and addonTable.GetActiveWorkspaceView and addonTable.GetActiveWorkspaceView() == "DYNAMICLOAD" and addonTable.HideConfigUI then
            pcall(addonTable.HideConfigUI)
        else
            pcall(addonTable.ShowConfigUI, true)
        end
        return
    end
    if addonTable.ToggleConfigUI then
        local ok, err = pcall(addonTable.ToggleConfigUI)
        if not ok then
            print(string.format("%s: UI Error: %s", ADDON_TITLE, tostring(err)))
        end
        return
    end
    if addonTable.CreateMainConfigUI then
        local ok, frame = pcall(addonTable.CreateMainConfigUI)
        if ok and frame then
            frame:SetShown(not frame:IsShown())
            return
        elseif not ok then
            print(string.format("%s: CreateMainConfigUI Error: %s", ADDON_TITLE, tostring(frame)))
        end
    end
    if _G.DynamicLoadMainFrame then
        _G.DynamicLoadMainFrame:SetShown(not _G.DynamicLoadMainFrame:IsShown())
        return
    end
    if _G.DynamicSuite and type(_G.DynamicSuite.OpenModule) == "function" then
        pcall(_G.DynamicSuite.OpenModule, _G.DynamicSuite, "DynamicLoad")
        return
    end
    print(string.format("%s: UI.lua did not finish loading. Check DynamicLoad.toc!", ADDON_TITLE))
end

local function HandleSuiteSlashCommand(msg)
    local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "auto" then
        DynamicLoadDB.autoSwitch = not DynamicLoadDB.autoSwitch
        if DynamicLoadDB.autoSwitch and addonTable.ResumeAutoSwitch then
            addonTable.ResumeAutoSwitch()
        end
        local status = DynamicLoadDB.autoSwitch and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        print(string.format("%s: Automatic context switching is now %s.", ADDON_TITLE, status))

    elseif cmd == "status" then
        local env = EvaluateCurrentEnvironment()
        local active = (addonTable.GetLoadedProfile and addonTable.GetLoadedProfile()) or (DynamicLoadDB and DynamicLoadDB.loadedProfile) or "None"
        local delta = CalculateAddonDelta(active)
        local conflicts = (addonTable.ScanAllConflicts and addonTable.ScanAllConflicts() or {})
        local conflictStr = (#conflicts > 0) and string.format(" |cFFFFB82E[%d Active Conflict(s)]|r", #conflicts) or " |cFF22C55E[Zero Conflicts]|r"
        local modeStr = (addonTable.IsManualOverrideActive and addonTable.IsManualOverrideActive()) and " |cFFF5B82E[Manual]|r" or " |cFF22C55E[Auto]|r"
        print(string.format("%s v%s Status: Profile: |cFFFFFFFF%s|r%s | Zone: |cFF38BDF8%s|r | Staged Delta: %d%s", ADDON_TITLE, ADDON_VERSION, active, modeStr, env, delta, conflictStr))

    elseif cmd == "lock" and arg and arg ~= "" then
        SetAddonLocked(arg, true)
        print(string.format("%s: Set '|cFFFFFFFF%s|r' to |cFFFACC15[Always]|r across all zone profiles.", ADDON_TITLE, arg))

    elseif cmd == "unlock" and arg and arg ~= "" then
        SetAddonLocked(arg, false)
        print(string.format("%s: Reset '|cFFFFFFFF%s|r' to |cFF34D399[By Zone]|r.", ADDON_TITLE, arg))

    elseif cmd == "freeze" and arg and arg ~= "" then
        SetAddonFrozen(arg, true)
        print(string.format("%s: Set '|cFFFFFFFF%s|r' to |cFF38BDF8[Never]|r across all zone profiles.", ADDON_TITLE, arg))

    elseif cmd == "profile" and arg and arg ~= "" then
        local target = arg:lower()
        if DynamicLoadDB.profiles[target] then
            local delta = 0
            if addonTable.ApplyProfile then
                delta = addonTable.ApplyProfile(target, false)
            else
                DynamicLoadDB.loadedProfile = target
                DynamicLoadDB.activeProfile = target
                local physical = EvaluateCurrentEnvironment()
                DynamicLoadDB.manualOverride = (target ~= physical)
                delta = StageAddonProfile(target, true)
            end
            if delta > 0 then
                ShowToast(target, delta)
            else
                print(string.format("%s: Profile '%s' matches current state. No reload required.", ADDON_TITLE, target))
            end
        else
            print(string.format("%s: Unknown profile '%s'.", ADDON_TITLE, arg))
        end

    elseif cmd == "setup" or cmd == "guided" or cmd == "conflicts" or cmd == "conflict" then
        if (cmd == "conflicts" or cmd == "conflict") and addonTable.PrintConflictSummary then
            addonTable.PrintConflictSummary()
        end
        if addonTable.OpenWorkspaceView then
            addonTable.OpenWorkspaceView("GUIDED_SETUP")
        else
            OpenMainSuiteWindowFallback()
        end

    elseif cmd == "theme" or cmd == "studio" then
        if addonTable.OpenWorkspaceView then
            addonTable.OpenWorkspaceView("THEME_STUDIO")
        else
            OpenMainSuiteWindowFallback()
        end

    elseif cmd == "edit" or cmd == "hud" or cmd == "move" or cmd == "toast" then
        if addonTable.EnterHudEditMode then
            addonTable.EnterHudEditMode("ALL")
        elseif addonTable.OpenWorkspaceView then
            addonTable.OpenWorkspaceView("EDIT_MODE")
        else
            addonTable.StartToastMove()
        end

    elseif cmd == "changelog" then
        if addonTable.ToggleChangelogModal then
            addonTable.ToggleChangelogModal()
        end

    elseif cmd == "reload" then
        ReloadUI()

    else
        OpenMainSuiteWindowFallback()
    end
end

SLASH_DYNAMICLOAD1 = "/dl"
SLASH_DYNAMICLOAD2 = "/dynamicload"
SlashCmdList["DYNAMICLOAD"] = HandleSuiteSlashCommand


addonTable.HandleDynamicLoadSlashCommand = HandleSuiteSlashCommand

function _G.DynamicLoad_OnAddonCompartmentClick(_, buttonName)
    if buttonName == "RightButton" and addonTable.EnterHudEditMode then
        addonTable.EnterHudEditMode("TOAST")
    else
        HandleSuiteSlashCommand("")
    end
end

if not DynamicSuite._isHubLoaded then
    function addonTable.ResetDynamicSuite()
        _G.DynamicSuiteDB = {
            global = CopyTable(DEFAULT_SUITE_GLOBAL)
        }
        addonTable.ResetDynamicLoad()
        if addonTable.ApplySuiteThemeAndGeometry then
            addonTable.ApplySuiteThemeAndGeometry()
        end
        print(string.format("%s: Entire DynamicSuite configuration (Theme, Window Geometry, HUDs, and Profiles) reset to factory defaults.", ADDON_TITLE))
    end
    DynamicSuite.ResetModule = function(_, modKey)
        if not modKey or modKey == "DynamicLoad" then
            addonTable.ResetDynamicLoad()
        elseif DynamicSuite.modules[modKey] and DynamicSuite.modules[modKey].ResetModule then
            DynamicSuite.modules[modKey]:ResetModule()
        end
    end
    DynamicSuite.ResetAllSuite = function()
        addonTable.ResetDynamicSuite()
    end
    DynamicSuite.RegisterModule = function(_, modKey, modTable)
        if not modKey or not modTable then return end
        DynamicSuite.modules[modKey] = modTable
    end
    SLASH_DYNAMICSUITE1 = "/ds"
    SLASH_DYNAMICSUITE2 = "/dynamicsuite"
    SlashCmdList["DYNAMICSUITE"] = HandleSuiteSlashCommand
end
end

--------------------------------------------------------------------------------
-- SECTION 2: WORKSPACE & STANDALONE UI (DynamicLoad UI)
--------------------------------------------------------------------------------
do
--[[
    DynamicLoad - DynamicLoad_UI.lua
    Zone Addon Profile Workspace, Parent-Child Addon Tree, CPU/Memory Telemetry & Alert Toast Studio
    Works 100% standalone (/dl) or docked inside DynamicSuite Hub (/ds).
]]

local addonTable = DL_NS

local CONTEXT_TABS = {
    { key = "outdoor", label = "Outdoor" },
    { key = "delve",   label = "Delves" },
    { key = "dungeon", label = "Dungeons" },
    { key = "raid",    label = "Raid" },
    { key = "pvp",     label = "PvP" },
}

local selectedTabKey = "outdoor"
local selectedAltKey = nil
local searchFilter = ""
local securityFilter = "ALL" -- "ALL", "PENDING", "CORE", "FROZEN"
local isToastSubTabActive = false

local contextMenuFrame = nil
local altDropdownFrame = nil
local clickCatcher = nil
local collapsedParents = {}

local function SyncStateToSuite()
    if addonTable._syncSuiteStateFromDL then
        addonTable._syncSuiteStateFromDL(selectedTabKey, securityFilter, isToastSubTabActive)
    end
end

addonTable._syncDLStateFromSuite = function(tabK, secF, toastSub)
    if tabK ~= nil then selectedTabKey = tabK end
    if secF ~= nil then securityFilter = secF end
    if toastSub ~= nil then isToastSubTabActive = toastSub end
end

local UI = addonTable.UI or DynamicSuite.UI
if not UI then
--------------------------------------------------------------------------------
-- OBSIDIAN CORE THEME, SURFACE & FONT ENGINE
--------------------------------------------------------------------------------
UI = {}
addonTable.UI = UI

function UI.FormatTooltipCommand(cmdText, actionText, cmdHex)
    local hex = (type(cmdHex) == "string" and cmdHex:gsub("^|cFF", ""):gsub("^|c", ""):gsub("^#", "")) or "34D399"
    if #hex == 8 then hex = hex:sub(3, 8) end
    if #hex ~= 6 then hex = "34D399" end
    local cmd = tostring(cmdText or "")
    if cmd ~= "" and not cmd:match(":$") then
        cmd = cmd .. ":"
    end
    return string.format("|cFF%s%s|r |cFFE2E8F0%s|r", hex:upper(), cmd, tostring(actionText or ""))
end
_G.DynamicSuite = _G.DynamicSuite or {}
_G.DynamicSuite.FormatTooltipCommand = UI.FormatTooltipCommand

-- 17 Unique Non-Repeating Accent Swatches (4 Secondary Brand Presets + 13 WoW Class Colors per DESIGN_SYSTEM.md Section 1.2)
local ACCENT_PRESETS = {
    { key = "ALERT_GOLD",     name = "Alert Gold",               r = 0.961, g = 0.722, b = 0.180, hex = "F5B82E" },
    { key = "ASTRAL_COBALT",  name = "Astral Cobalt",            r = 0.376, g = 0.647, b = 0.980, hex = "60A5FA" },
    { key = "EMERALD_MINT",   name = "Emerald Mint",             r = 0.063, g = 0.725, b = 0.506, hex = "10B981" },
    { key = "OBSIDIAN_SLATE", name = "Obsidian Slate",           r = 0.796, g = 0.835, b = 0.882, hex = "CBD5E1" },
    { key = "DEATHKNIGHT",    name = "Death Knight Red",         r = 0.77,  g = 0.12,  b = 0.23,  hex = "C41E3A" },
    { key = "DEMONHUNTER",    name = "Demon Hunter Magenta",     r = 0.64,  g = 0.19,  b = 0.79,  hex = "A330C9" },
    { key = "DRUID",          name = "Druid Orange",             r = 1.00,  g = 0.49,  b = 0.04,  hex = "FF7C0A" },
    { key = "EVOKER",         name = "Evoker Emerald",           r = 0.20,  g = 0.58,  b = 0.50,  hex = "33937F" },
    { key = "HUNTER",         name = "Hunter Green",             r = 0.67,  g = 0.83,  b = 0.45,  hex = "ABD473" },
    { key = "MAGE",           name = "Mage Light Blue",          r = 0.25,  g = 0.78,  b = 0.92,  hex = "3FC7EB" },
    { key = "MONK",           name = "Monk Jade",                r = 0.00,  g = 1.00,  b = 0.60,  hex = "00FF98" },
    { key = "PALADIN",        name = "Paladin Pink",             r = 0.96,  g = 0.55,  b = 0.73,  hex = "F58CBA" },
    { key = "PRIEST",         name = "Priest White",             r = 1.00,  g = 1.00,  b = 1.00,  hex = "FFFFFF" },
    { key = "ROGUE",          name = "Rogue Yellow",             r = 1.00,  g = 0.96,  b = 0.41,  hex = "FFF569" },
    { key = "SHAMAN",         name = "Shaman Blue",              r = 0.00,  g = 0.44,  b = 0.87,  hex = "0070DE" },
    { key = "WARLOCK",        name = "Warlock Purple",           r = 0.53,  g = 0.53,  b = 0.93,  hex = "8788EE" },
    { key = "WARRIOR",        name = "Warrior Tan",              r = 0.78,  g = 0.61,  b = 0.43,  hex = "C79C6E" },
}
UI.ACCENT_PRESETS = ACCENT_PRESETS

local SURFACE_THEMES = {
    ["MIDNIGHT_BLACK"] = {
        name   = "Midnight Pitch Black (Default)",
        header = { r = 0.015, g = 0.018, b = 0.024, a = 1.00 }, -- #040506
        rail   = { r = 0.024, g = 0.027, b = 0.035, a = 1.00 }, -- #060709
        panel  = { r = 0.035, g = 0.039, b = 0.051, a = 0.99 }, -- #090A0D
        card   = { r = 0.055, g = 0.063, b = 0.082, a = 0.96 }, -- #0E1015
    },
    ["OBSIDIAN_DARK"] = {
        name   = "Obsidian Dark",
        header = { r = 0.035, g = 0.039, b = 0.051, a = 1.00 }, -- #090A0D
        rail   = { r = 0.047, g = 0.055, b = 0.071, a = 0.99 }, -- #0C0E12
        panel  = { r = 0.067, g = 0.075, b = 0.094, a = 0.98 }, -- #111318
        card   = { r = 0.090, g = 0.102, b = 0.129, a = 0.95 }, -- #171A21
    },
    ["SLATE_STEEL"] = {
        name   = "Slate Steel",
        header = { r = 0.055, g = 0.067, b = 0.090, a = 1.00 },
        rail   = { r = 0.071, g = 0.086, b = 0.114, a = 0.99 },
        panel  = { r = 0.090, g = 0.106, b = 0.141, a = 0.98 },
        card   = { r = 0.118, g = 0.137, b = 0.180, a = 0.96 },
    },
    ["SMOKED_GLASS"] = {
        name   = "Smoked Glass",
        header = { r = 0.045, g = 0.055, b = 0.075, a = 0.92 },
        rail   = { r = 0.055, g = 0.067, b = 0.090, a = 0.88 },
        panel  = { r = 0.075, g = 0.090, b = 0.118, a = 0.86 },
        card   = { r = 0.102, g = 0.122, b = 0.157, a = 0.84 },
    },
}
UI.SURFACE_THEMES = SURFACE_THEMES

local FONT_FAMILY_ORDER = {
    { key = "EXPRESSWAY",       label = "Expressway" },
    { key = "EXPRESSWAY_BOLD",  label = "Expressway Bold" },
    { key = "EXPRESSWAY_CAPS",  label = "Expressway CAPS" },
    { key = "POPPINS",          label = "Poppins" },
    { key = "AVANT_GARDE",      label = "Avant Garde" },
    { key = "FIRA_SANS",        label = "Fira Sans" },
    { key = "FIRA_SANS_BOLD",   label = "Fira Sans Bold" },
    { key = "FIRA_SANS_LIGHT",  label = "Fira Sans Light" },
    { key = "UBUNTU",           label = "Ubuntu" },
    { key = "BARLOW_CONDENSED", label = "Barlow Condensed" },
    { key = "CHANGA",           label = "Changa" },
    { key = "RUSSO_ONE",        label = "Russo One" },
    { key = "CINZEL",           label = "Cinzel Decorative" },
    { key = "HWT_ARTZ",         label = "HWT Artz" },
    { key = "KMT_NINJA_NARUTO", label = "KMT Ninja Naruto" },
    { key = "ARIAL_NARROW",     label = "Arial Narrow" },
    { key = "ARIAL_BOLD",       label = "Arial Bold" },
    { key = "HOMESPUN",         label = "Homespun" },
    { key = "FRIZ_QUADRATA",    label = "Friz Quadrata" },
    { key = "MODERN_SANS",      label = "2002" },
    { key = "RPG_SERIF",        label = "Morpheus" },
}
UI.FONT_FAMILY_ORDER = FONT_FAMILY_ORDER

-- Complete 26-Font EllesmereUI Library (1:1 Name Matching & File Resolution)
local EUI_COMPLETE_FONT_LIBRARY = {
    { key = "EXPRESSWAY",          name = "Expressway",          file = "Expressway.ttf",          bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.TTF" },
    { key = "EXPRESSWAY_BOLD",     name = "Expressway Bold",     file = "Expressway Bold.ttf",     bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway Bold.ttf" },
    { key = "EXPRESSWAY_CAPS",     name = "Expressway CAPS",     file = "Expressway CAPS.ttf",     bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway CAPS.ttf" },
    { key = "POPPINS",             name = "Poppins",             file = "Poppins.ttf",             bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Poppins.ttf" },
    { key = "AVANT_GARDE",         name = "Avant Garde",         file = "Avant Garde.ttf",         bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Avant Garde Naowh.ttf" },
    { key = "EXO",                 name = "Exo",                 file = "Exo.ttf" },
    { key = "FIRA_SANS",           name = "Fira Sans",           file = "FiraSans Medium.ttf",     bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Medium.ttf" },
    { key = "FIRA_SANS_BOLD",      name = "Fira Sans Bold",      file = "FiraSans Bold.ttf",       bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Bold.ttf" },
    { key = "FIRA_SANS_LIGHT",     name = "Fira Sans Light",     file = "FiraSans Light.ttf",      bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Light.ttf" },
    { key = "UBUNTU",              name = "Ubuntu",              file = "Ubuntu.ttf",              bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Ubuntu.ttf" },
    { key = "BARLOW_CONDENSED",    name = "Barlow Condensed",    file = "Barlow Condensed.ttf",    bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Barlow Condensed.ttf" },
    { key = "CHANGA",              name = "Changa",              file = "Changa.ttf",              bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Changa.ttf" },
    { key = "RUSSO_ONE",           name = "Russo One",           file = "Russo One.ttf",           bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Russo One.ttf" },
    { key = "CINZEL",              name = "Cinzel Decorative",   file = "Cinzel Decorative.ttf",   bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Cinzel Decorative.ttf" },
    { key = "FUTURE_X_BLACK",      name = "Future X Black",      file = "Future X Black.ttf" },
    { key = "GOTHAM_NARROW_ULTRA", name = "Gotham Narrow Ultra", file = "Gotham Narrow Ultra.ttf" },
    { key = "GOTHAM_NARROW",       name = "Gotham Narrow",       file = "Gotham Narrow.ttf" },
    { key = "HWT_ARTZ",            name = "HWT Artz",            file = "HWT Artz.ttf",            bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\HWT Artz.ttf" },
    { key = "KMT_KIMBERLEY",       name = "KMT Kimberley",       file = "KMT Kimberley.ttf" },
    { key = "KMT_NINJA_NARUTO",    name = "KMT Ninja Naruto",    file = "KMT Ninja Naruto.ttf",    bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\KMT Ninja Naruto.ttf" },
    { key = "ARIAL_NARROW",        name = "Arial Narrow",        file = "Arial Narrow.ttf",        bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Arial Narrow.ttf" },
    { key = "ARIAL_BOLD",          name = "Arial Bold",          file = "Arial Bold.ttf",          bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Arial Bold.TTF" },
    { key = "HOMESPUN",            name = "Homespun",            file = "Homespun.ttf",            bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Homespun.ttf", flags = "MONOCHROME,OUTLINE", scale = 0.92 },
    { key = "FRIZ_QUADRATA",       name = "Friz Quadrata",       file = "FRIZQT__.TTF",            bundled = "Fonts\\FRIZQT__.TTF" },
    { key = "MODERN_SANS",         name = "2002",                file = "2002.TTF",                bundled = "Fonts\\2002.TTF" },
    { key = "RPG_SERIF",           name = "Morpheus",            file = "MORPHEUS.TTF",            bundled = "Fonts\\MORPHEUS.TTF", scale = 1.06 },
}

local FONT_FAMILIES = {
    ["EXPRESSWAY"] = {
        name = "Expressway",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.TTF",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.TTF", "Fonts\\2002.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.00, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.55,
    },
    ["EXPRESSWAY_BOLD"] = {
        name = "Expressway Bold",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway Bold.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway Bold.ttf", "Fonts\\2002B.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 0.98, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.60,
    },
    ["EXPRESSWAY_CAPS"] = {
        name = "Expressway CAPS",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway CAPS.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway CAPS.ttf", "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 0.98, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.55,
    },
    ["POPPINS"] = {
        name = "Poppins",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Poppins.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Poppins.ttf", "Fonts\\2002.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 0.98, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.50,
    },
    ["AVANT_GARDE"] = {
        name = "Avant Garde",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Avant Garde Naowh.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Avant Garde Naowh.ttf", "Fonts\\2002.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 0.98, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.55,
    },
    ["FIRA_SANS"] = {
        name = "Fira Sans",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Medium.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Medium.ttf", "Fonts\\2002.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.00, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.50,
    },
    ["FIRA_SANS_BOLD"] = {
        name = "Fira Sans Bold",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Bold.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Bold.ttf", "Fonts\\2002B.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 0.98, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.60,
    },
    ["FIRA_SANS_LIGHT"] = {
        name = "Fira Sans Light",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Light.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Light.ttf", "Fonts\\2002.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.02, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.45,
    },
    ["UBUNTU"] = {
        name = "Ubuntu",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Ubuntu.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Ubuntu.ttf", "Fonts\\2002.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.00, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.50,
    },
    ["BARLOW_CONDENSED"] = {
        name = "Barlow Condensed",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Barlow Condensed.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Barlow Condensed.ttf", "Fonts\\ARIALN.TTF", "Fonts\\2002.TTF" },
        sizeScale = 1.06, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.45,
    },
    ["CHANGA"] = {
        name = "Changa",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Changa.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Changa.ttf", "Fonts\\2002.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.00, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.50,
    },
    ["RUSSO_ONE"] = {
        name = "Russo One",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Russo One.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Russo One.ttf", "Fonts\\2002B.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 0.95, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.60,
    },
    ["CINZEL"] = {
        name = "Cinzel Decorative",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Cinzel Decorative.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Cinzel Decorative.ttf", "Fonts\\MORPHEUS.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.02, defaultFlags = "", shadowOff = 1.3, shadowAlpha = 0.80,
    },
    ["HWT_ARTZ"] = {
        name = "HWT Artz",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\HWT Artz.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\HWT Artz.ttf", "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway Bold.ttf", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.02, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.55,
    },
    ["KMT_NINJA_NARUTO"] = {
        name = "KMT Ninja Naruto",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\KMT Ninja Naruto.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\KMT Ninja Naruto.ttf", "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway Bold.ttf", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 0.96, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.55,
    },
    ["ARIAL_NARROW"] = {
        name = "Arial Narrow",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Arial Narrow.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Arial Narrow.ttf", "Fonts\\ARIALN.TTF", "Fonts\\2002.TTF" },
        sizeScale = 1.02, defaultFlags = "", shadowOff = 0.9, shadowAlpha = 0.45,
    },
    ["ARIAL_BOLD"] = {
        name = "Arial Bold",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Arial Bold.TTF",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Arial Bold.TTF", "Fonts\\2002B.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 0.96, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.55,
    },
    ["HOMESPUN"] = {
        name = "Homespun",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Homespun.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Homespun.ttf", "Fonts\\ARIALN.TTF", "Fonts\\2002.TTF" },
        sizeScale = 0.92, defaultFlags = "MONOCHROME,OUTLINE", shadowOff = 0, shadowAlpha = 0,
    },
    ["FRIZ_QUADRATA"] = {
        name = "Friz Quadrata",
        path = "Fonts\\FRIZQT__.TTF",
        candidates = { "Fonts\\FRIZQT__.TTF", "Fonts\\2002.TTF" },
        sizeScale = 1.00, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.55,
    },
    ["MODERN_SANS"] = {
        name = "2002",
        path = "Fonts\\2002.TTF",
        candidates = { "Fonts\\2002.TTF", "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.00, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.45,
    },
    ["RPG_SERIF"] = {
        name = "Morpheus",
        path = "Fonts\\MORPHEUS.TTF",
        candidates = { "Fonts\\MORPHEUS.TTF", "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Cinzel Decorative.ttf", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.06, defaultFlags = "", shadowOff = 1.4, shadowAlpha = 0.85,
    },
    ["COMPACT_NARROW"] = {
        name = "Arial Narrow",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Arial Narrow.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Arial Narrow.ttf", "Fonts\\ARIALN.TTF", "Fonts\\2002.TTF" },
        sizeScale = 1.00, defaultFlags = "", shadowOff = 0.8, shadowAlpha = 0.35,
    },
    ["CLEAN_TECHNICAL"] = {
        name = "Russo One",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Russo One.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Russo One.ttf", "Fonts\\2002B.TTF", "Fonts\\ARHei.TTF" },
        sizeScale = 0.95, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.55,
    },
}
UI.FONT_FAMILIES = FONT_FAMILIES

-- Register bundled DynamicSuite fonts with LibSharedMedia-3.0 if present
do
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM.Register then
        for _, item in ipairs(FONT_FAMILY_ORDER) do
            local entry = FONT_FAMILIES[item.key]
            if entry and entry.path then
                pcall(LSM.Register, LSM, "font", item.label, entry.path)
            end
        end
    end
end

UI.COLORS = {
    HEADER_BG    = { r = 0.015, g = 0.018, b = 0.024, a = 1.00 }, -- #040506 (MIDNIGHT_BLACK default)
    RAIL_BG      = { r = 0.024, g = 0.027, b = 0.035, a = 1.00 }, -- #060709
    PANEL_BG     = { r = 0.035, g = 0.039, b = 0.051, a = 0.99 }, -- #090A0D
    CARD_BG      = { r = 0.055, g = 0.063, b = 0.082, a = 0.96 }, -- #0E1015
    CELL_BG      = { r = 0.078, g = 0.090, b = 0.122, a = 0.96 }, -- #14171F Neutral Interactive Cell
    CELL_BORDER  = { r = 0.145, g = 0.165, b = 0.212, a = 0.95 }, -- #252A36 Neutral Cell Border
    BORDER       = { r = 1.00,  g = 1.00,  b = 1.00,  a = 0.07 },
    BORDER_OUTER = { r = 1.00,  g = 1.00,  b = 1.00,  a = 0.15 },
    ACCENT       = { r = 0.796, g = 0.835, b = 0.882, a = 1.00 }, -- Updated dynamically
    GOLD         = { r = 0.961, g = 0.722, b = 0.180, a = 1.00 }, -- #F5B82E (ALWAYS ON / CORE / WARNING)
    CYAN         = { r = 0.220, g = 0.741, b = 0.973, a = 1.00 }, -- #38BDF8 (NEVER LOAD / FROZEN)
    EMERALD      = { r = 0.133, g = 0.773, b = 0.369, a = 1.00 }, -- #22C55E (LIVE / READY / ZERO CONFLICTS)
    CRIMSON      = { r = 0.937, g = 0.267, b = 0.267, a = 1.00 }, -- #EF4444 (DISABLED / HIDDEN / DANGER)
    ROW_ODD      = { r = 1.00,  g = 1.00,  b = 1.00,  a = 0.025 },
    ROW_EVEN     = { r = 0.00,  g = 0.00,  b = 0.00,  a = 0.18 },
    ROW_HOVER    = { r = 1.00,  g = 1.00,  b = 1.00,  a = 0.065 },
    TEXT_TITLE   = { r = 0.97,  g = 0.98,  b = 1.00,  a = 0.98 },
    TEXT_DIM     = { r = 0.58,  g = 0.64,  b = 0.72,  a = 1.00 },
    BTN_BG       = { r = 0.078, g = 0.090, b = 0.122, a = 0.96 }, -- Matches CELL_BG (#14171F)
    BTN_HOVER    = { r = 0.135, g = 0.153, b = 0.192, a = 1.00 },
    BTN_BORDER   = { r = 0.145, g = 0.165, b = 0.212, a = 0.95 }, -- Matches CELL_BORDER (#252A36)
}
if _G.DynamicSuite then
    _G.DynamicSuite.UI = _G.DynamicSuite.UI or {}
    _G.DynamicSuite.UI.COLORS = UI.COLORS
end

function UI.GetActiveAccentColor()
    local g = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
    local key = g.accentKey or "AUTO_CLASS"
    if key == "CUSTOM" and g.customAccent then
        local r = g.customAccent.r or 0.796
        local gCol = g.customAccent.g or 0.835
        local b = g.customAccent.b or 0.882
        local hex = string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(gCol * 255 + 0.5), math.floor(b * 255 + 0.5))
        return r, gCol, b, hex
    elseif key == "AUTO_CLASS" then
        local _, classFile = UnitClass("player")
        local cc = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
        if cc then
            local hex = cc.colorStr or string.format("%02X%02X%02X", math.floor(cc.r * 255 + 0.5), math.floor(cc.g * 255 + 0.5), math.floor(cc.b * 255 + 0.5))
            hex = hex:gsub("^|c", ""):gsub("^#", "")
            if #hex == 8 then hex = hex:sub(3, 8) end
            return cc.r, cc.g, cc.b, hex:upper()
        end
    end
    for _, p in ipairs(ACCENT_PRESETS) do
        if p.key == key then
            return p.r, p.g, p.b, p.hex
        end
    end
    local _, classFile = UnitClass("player")
    local cc = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
    if cc then
        local hex = cc.colorStr or string.format("%02X%02X%02X", math.floor(cc.r * 255 + 0.5), math.floor(cc.g * 255 + 0.5), math.floor(cc.b * 255 + 0.5))
        hex = hex:gsub("^|c", ""):gsub("^#", "")
        if #hex == 8 then hex = hex:sub(3, 8) end
        return cc.r, cc.g, cc.b, hex:upper()
    end
    return 0.796, 0.835, 0.882, "CBD5E1"
end

function UI.GetActiveSurfaceKey()
    local g = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
    local key = g.surfaceTheme
    if not key or not SURFACE_THEMES[key] then
        key = "MIDNIGHT_BLACK"
        g.surfaceTheme = key
    end
    return key
end

function UI.GetActiveSurfaceColors()
    local key = UI.GetActiveSurfaceKey()
    return SURFACE_THEMES[key] or SURFACE_THEMES["MIDNIGHT_BLACK"]
end

function UI.RefreshPaletteCache()
    local ar, ag, ab = UI.GetActiveAccentColor()
    UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b = ar, ag, ab

    local surf = UI.GetActiveSurfaceColors()
    UI.COLORS.HEADER_BG = surf.header
    UI.COLORS.RAIL_BG   = surf.rail
    UI.COLORS.PANEL_BG  = surf.panel
    UI.COLORS.CARD_BG   = surf.card
end

local fontProbeFS = nil
local resolvedFontPaths = {}

local fontProbeCache = {}
local function CanSetFontPath(path)
    if not path or type(path) ~= "string" or path == "" then return false end
    if fontProbeCache[path] ~= nil then return fontProbeCache[path] end
    if not fontProbeFS then
        fontProbeFS = UIParent:CreateFontString(nil, "BACKGROUND")
        fontProbeFS:Hide()
    end
    local ok, applied = pcall(fontProbeFS.SetFont, fontProbeFS, path, 12, "")
    local fetched = ok and fontProbeFS:GetFont() or nil
    local valid = (ok and applied ~= false and fetched ~= nil)
    fontProbeCache[path] = valid
    return valid
end

local function NormalizeFontKey(rawName)
    return tostring(rawName or "EXPRESSWAY"):upper():gsub("[^A-Z0-9]+", "_"):gsub("^_+", ""):gsub("_+$", "")
end

function UI.SyncEllesmereUIFontLibrary()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local eui = _G.EllesmereUI
    local hasEUI = (type(eui) == "table") or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("EllesmereUI"))
    local euiMediaBase = (eui and type(eui.MEDIA_PATH) == "string" and eui.MEDIA_PATH ~= "" and eui.MEDIA_PATH) or "Interface\\AddOns\\EllesmereUI\\media\\"
    if not euiMediaBase:match("[\\/]$") then
        euiMediaBase = euiMediaBase .. "\\"
    end

    local euiKnownByKey = {}
    local euiKnownByName = {}
    for _, def in ipairs(EUI_COMPLETE_FONT_LIBRARY) do
        euiKnownByKey[def.key] = def
        euiKnownByName[def.name:lower()] = def
    end

    local activeOrder = {}
    local seenKeys = {}

    local function RegisterOrUpdateFontEntry(fKey, fName, fFile, bundledPath, scale, flags)
        local cands = {}
        if LSM and LSM.Fetch then
            local ok, lsmPath = pcall(LSM.Fetch, LSM, "font", fName, true)
            if ok and type(lsmPath) == "string" and lsmPath ~= "" then
                table.insert(cands, lsmPath)
            end
        end
        if eui then
            if type(eui.FONTS) == "table" and eui.FONTS[fName] then
                local eVal = eui.FONTS[fName]
                local fileOrPath = (type(eVal) == "table" and (eVal.path or eVal.file)) or (type(eVal) == "string" and eVal) or nil
                if fileOrPath then
                    if fileOrPath:find("[\\/]") then
                        table.insert(cands, fileOrPath)
                    else
                        table.insert(cands, euiMediaBase .. "fonts\\" .. fileOrPath)
                    end
                end
            end
            if type(eui.FONT_PATHS) == "table" and type(eui.FONT_PATHS[fName]) == "string" then
                table.insert(cands, eui.FONT_PATHS[fName])
            end
        end
        if fFile then
            if fFile:find("[\\/]") then
                table.insert(cands, fFile)
            else
                table.insert(cands, euiMediaBase .. "fonts\\" .. fFile)
                table.insert(cands, "Interface\\AddOns\\EllesmereUI\\media\\fonts\\" .. fFile)
                table.insert(cands, "Interface\\AddOns\\EllesmereUI\\Media\\Fonts\\" .. fFile)
                table.insert(cands, "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\" .. fFile)
            end
        end
        if bundledPath then
            table.insert(cands, bundledPath)
        end
        table.insert(cands, "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.TTF")
        table.insert(cands, "Fonts\\FRIZQT__.TTF")

        local existing = FONT_FAMILIES[fKey]
        local primaryPath = cands[1] or (existing and existing.path) or bundledPath or "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.TTF"
        FONT_FAMILIES[fKey] = {
            name = fName,
            path = primaryPath,
            candidates = cands,
            sizeScale = scale or (existing and existing.sizeScale) or 1.00,
            defaultFlags = flags or (existing and existing.defaultFlags) or "",
            shadowOff = (existing and existing.shadowOff) or 1,
            shadowAlpha = (existing and existing.shadowAlpha) or 0.55,
        }

        local chosen = nil
        for _, cand in ipairs(cands) do
            if CanSetFontPath(cand) then
                chosen = cand
                break
            end
        end
        chosen = chosen or primaryPath
        resolvedFontPaths[fKey] = chosen
        FONT_FAMILIES[fKey].resolvedPath = chosen
        return chosen
    end

    if hasEUI and eui and type(eui.FONT_ORDER) == "table" and #eui.FONT_ORDER > 0 then
        for _, rawItem in ipairs(eui.FONT_ORDER) do
            local fName = (type(rawItem) == "table" and (rawItem.name or rawItem.label or rawItem[1])) or (type(rawItem) == "string" and rawItem) or nil
            local fFile = (type(rawItem) == "table" and (rawItem.file or rawItem.path or rawItem[2])) or nil
            if fName and fName ~= "" then
                local known = euiKnownByName[fName:lower()]
                local fKey = (known and known.key) or NormalizeFontKey(fName)
                if not seenKeys[fKey] then
                    seenKeys[fKey] = true
                    RegisterOrUpdateFontEntry(
                        fKey,
                        fName,
                        fFile or (known and known.file),
                        known and known.bundled,
                        known and known.scale,
                        known and known.flags
                    )
                    table.insert(activeOrder, { key = fKey, label = fName })
                end
            end
        end
    end

    for _, def in ipairs(EUI_COMPLETE_FONT_LIBRARY) do
        if not seenKeys[def.key] then
            local canInclude = hasEUI or (def.bundled ~= nil)
            if not canInclude and LSM and LSM.Fetch then
                local ok, fetched = pcall(LSM.Fetch, LSM, "font", def.name, true)
                if ok and type(fetched) == "string" and fetched ~= "" and CanSetFontPath(fetched) then
                    canInclude = true
                end
            end
            if canInclude then
                seenKeys[def.key] = true
                RegisterOrUpdateFontEntry(def.key, def.name, def.file, def.bundled, def.scale, def.flags)
                table.insert(activeOrder, { key = def.key, label = def.name })
            end
        end
    end

    if #activeOrder > 0 then
        FONT_FAMILY_ORDER = activeOrder
        UI.FONT_FAMILY_ORDER = activeOrder
    end
    return FONT_FAMILY_ORDER
end

function UI.BuildFontDropdownOptions()
    local order = UI.SyncEllesmereUIFontLibrary()
    local opts = {}
    for _, fItem in ipairs(order) do
        table.insert(opts, { value = fItem.key, label = fItem.label, fontKey = fItem.key })
    end
    return opts
end

function UI.GetActiveFontKey()
    local g = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
    local key = g.fontKey or g.fontFamily
    if key and not FONT_FAMILIES[key] then
        UI.SyncEllesmereUIFontLibrary()
        local lowerKey = tostring(key):lower()
        for fKey, fDef in pairs(FONT_FAMILIES) do
            if fDef.name == key or fKey == key or fDef.name:lower() == lowerKey then
                key = fKey
                break
            end
        end
        if not FONT_FAMILIES[key] then
            for fKey, fDef in pairs(FONT_FAMILIES) do
                if string.find(string.lower(fDef.name), lowerKey, 1, true) then
                    key = fKey
                    break
                end
            end
        end
    end
    if not key or not FONT_FAMILIES[key] then
        key = "EXPRESSWAY"
        g.fontFamily = key
        g.fontKey = key
    end
    return key
end

local fontLibraryResolved = false
local lastAppliedFontKey = nil

local function ResolveAllFontFamilyPaths(forceSync)
    if fontLibraryResolved and not forceSync then return end
    UI.SyncEllesmereUIFontLibrary()
    for key, entry in pairs(FONT_FAMILIES) do
        local chosen = nil
        if entry.candidates then
            for _, cand in ipairs(entry.candidates) do
                if CanSetFontPath(cand) then
                    chosen = cand
                    break
                end
            end
        end
        chosen = chosen or entry.path or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        resolvedFontPaths[key] = chosen
        entry.resolvedPath = chosen
    end
    fontLibraryResolved = true
end

function UI.GetFont(fontKeyOverride)
    local key = fontKeyOverride or UI.GetActiveFontKey()
    if not FONT_FAMILIES[key] then
        UI.SyncEllesmereUIFontLibrary()
    end
    if not FONT_FAMILIES[key] then key = "EXPRESSWAY" end
    if not resolvedFontPaths[key] then
        ResolveAllFontFamilyPaths()
    end
    local entry = FONT_FAMILIES[key] or FONT_FAMILIES["EXPRESSWAY"]
    return resolvedFontPaths[key] or entry.path or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", entry
end

local registeredFontStrings = {}

local function ApplyFontToWidget(fs, forceReflow)
    if not fs or not fs.SetFont or fs.ignoreSuiteFont then return end
    local key = fs._fixedFontKey or UI.GetActiveFontKey()
    local fontPath, entry = UI.GetFont(key)

    if not fs._dsBaseFontSize then
        local _, existingSize, existingFlags = fs:GetFont()
        fs._dsBaseFontSize = fs._dsFontSize or existingSize or 11
        fs._dsBaseFontFlags = fs._dsFontFlags or existingFlags or ""
    end

    local baseSize = fs._dsFontSize or fs._dsBaseFontSize or 11
    local scale = (entry and entry.sizeScale) or 1.0
    local finalSize = math.max(8, math.floor((baseSize * scale) + 0.5))

    local baseFlags = fs._dsFontFlags or fs._dsBaseFontFlags or ""
    local finalFlags = baseFlags
    if entry and entry.defaultFlags and entry.defaultFlags ~= "" then
        if finalFlags == "" then
            finalFlags = entry.defaultFlags
        end
    end

    if not forceReflow and fs._appliedFontPath == fontPath and fs._appliedFontSize == finalSize and fs._appliedFontFlags == finalFlags then
        return
    end
    fs._appliedFontPath = fontPath
    fs._appliedFontSize = finalSize
    fs._appliedFontFlags = finalFlags

    local ok = pcall(fs.SetFont, fs, fontPath, finalSize, finalFlags)
    if not ok or (fs.GetFont and not fs:GetFont()) then
        local fallback = (GameFontNormal and GameFontNormal:GetFont()) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        pcall(fs.SetFont, fs, fallback, finalSize, finalFlags)
    end

    if fs.SetShadowColor and fs.SetShadowOffset then
        local sAlpha = (entry and entry.shadowAlpha) or 0
        local sOff = (entry and entry.shadowOff) or 0
        if sAlpha > 0 and sOff > 0 then
            fs:SetShadowColor(0, 0, 0, sAlpha)
            fs:SetShadowOffset(sOff, -sOff)
        else
            fs:SetShadowColor(0, 0, 0, 0)
            fs:SetShadowOffset(0, 0)
        end
    end
end

function UI.SetFont(fs, size, flags, r, g, b, a)
    if not fs then return end
    fs._dsFontSize = size or 12
    fs._dsBaseFontSize = size or 12
    fs._dsFontFlags = flags or ""
    fs._dsBaseFontFlags = flags or ""
    registeredFontStrings[fs] = true

    ApplyFontToWidget(fs, false)
    if r and fs.SetTextColor then
        fs:SetTextColor(r, g or 1, b or 1, a or 1)
    end
end

function UI.ApplyFontRecursively(frame)
    if not frame then return end
    if frame.GetObjectType and frame:GetObjectType() == "EditBox" and frame.SetFont then
        registeredFontStrings[frame] = true
        ApplyFontToWidget(frame, false)
    end
    if frame.GetRegions then
        for i = 1, select("#", frame:GetRegions()) do
            local reg = select(i, frame:GetRegions())
            if reg and reg.GetObjectType and reg:GetObjectType() == "FontString" then
                registeredFontStrings[reg] = true
                ApplyFontToWidget(reg, false)
            end
        end
    end
    if frame.GetChildren then
        for i = 1, select("#", frame:GetChildren()) do
            local child = select(i, frame:GetChildren())
            if child then
                UI.ApplyFontRecursively(child)
            end
        end
    end
end

function UI.RefreshAllFonts(forceAll)
    ResolveAllFontFamilyPaths(forceAll)
    local curKey = UI.GetActiveFontKey()
    if not forceAll and lastAppliedFontKey == curKey then
        return
    end
    lastAppliedFontKey = curKey
    for fs in pairs(registeredFontStrings) do
        ApplyFontToWidget(fs, true)
    end
    local g = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
    if g.syncThemeToToast ~= false then
        if _G.DynamicLoadToastFrame then UI.ApplyFontRecursively(_G.DynamicLoadToastFrame) end
        if _G.DynamicPrepBarFrame then UI.ApplyFontRecursively(_G.DynamicPrepBarFrame) end
        if _G.DynamicMarkerTargetBar then UI.ApplyFontRecursively(_G.DynamicMarkerTargetBar) end
        if _G.FocusMarkerButtonFrame then UI.ApplyFontRecursively(_G.FocusMarkerButtonFrame) end
        if _G.DynamicMarkerBarFrame then UI.ApplyFontRecursively(_G.DynamicMarkerBarFrame) end
        if _G.FocusMarkerBar then UI.ApplyFontRecursively(_G.FocusMarkerBar) end
        if _G.DynamicMarkerFlareBar then UI.ApplyFontRecursively(_G.DynamicMarkerFlareBar) end
        if _G.FocusMarkerFlareFrame then UI.ApplyFontRecursively(_G.FocusMarkerFlareFrame) end
        if _G.FocusMarkerFlareBar then UI.ApplyFontRecursively(_G.FocusMarkerFlareBar) end
    end
end

function UI.DisablePixelSnap(tex)
    if not tex then return end
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
end

function UI.SolidTex(parent, layer, sublevel, r, g, b, a)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    tex:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
    UI.DisablePixelSnap(tex)
    return tex
end

function UI.CreateChevronDown(parent, point, relTo, relPoint, xOff, yOff, r, g, b, a)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(12, 12)
    holder:SetPoint(point or "RIGHT", relTo or parent, relPoint or "RIGHT", xOff or -8, yOff or 0)

    local cr, cg, cb, ca = r or 1, g or 1, b or 1, a or 0.72

    local tex = holder:CreateTexture(nil, "OVERLAY", nil, 3)
    tex:SetAllPoints()
    tex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga")
    tex:SetVertexColor(cr, cg, cb, ca)

    holder.tex = tex
    if parent then
        parent.chevronTex = tex
    end
    holder.SetColor = function(_, nr, ng, nb, na)
        tex:SetVertexColor(nr, ng, nb, na or 1)
    end
    holder.SetOpen = function(_, isOpen)
        if isOpen then
            local ar, ag, ab = UI.GetActiveAccentColor()
            tex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga")
            tex:SetVertexColor(ar, ag, ab, 1.0)
        else
            tex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga")
            tex:SetVertexColor(cr, cg, cb, ca)
        end
    end
    return holder
end

function UI.SetChevronState(btn, isOpen)
    if not btn then return end
    if btn.chevron and btn.chevron.SetOpen then
        btn.chevron:SetOpen(isOpen)
    elseif btn.chevronTex then
        if isOpen then
            local ar, ag, ab = UI.GetActiveAccentColor()
            btn.chevronTex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga")
            btn.chevronTex:SetVertexColor(ar, ag, ab, 1.0)
        else
            btn.chevronTex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga")
            btn.chevronTex:SetVertexColor(0.75, 0.80, 0.88, 0.85)
        end
    end
end

function UI.GetActiveAccentHex()
    local ar, ag, ab = UI.GetActiveAccentColor()
    local ri = math.floor(math.max(0, math.min(1, ar or 0.80)) * 255 + 0.5)
    local gi = math.floor(math.max(0, math.min(1, ag or 0.84)) * 255 + 0.5)
    local bi = math.floor(math.max(0, math.min(1, ab or 0.88)) * 255 + 0.5)
    return string.format("%02X%02X%02X", ri, gi, bi)
end

function UI.FormatTwoToneBrand(secondWord)
    local suffix = tostring(secondWord or "Suite"):gsub("^Dynamic", "")
    if suffix == "" then suffix = "Suite" end
    return string.format("|cFFF3F5F8Dynamic|r|cFF%s%s|r", UI.GetActiveAccentHex(), suffix)
end

local MODULE_ICON_PATHS = {
    ["DynamicLoad"]   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_load.tga",
    ["load"]          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_load.tga",
    ["DynamicMarker"] = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_marker.tga",
    ["marker"]        = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_marker.tga",
    ["DynamicZoom"]   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_zoom.tga",
    ["zoom"]          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_zoom.tga",
    ["DynamicFPS"]    = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_fps.tga",
    ["fps"]           = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_fps.tga",
    ["DynamicPrep"]   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_prep.tga",
    ["prep"]          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_prep.tga",
    ["DynamicGroup"]  = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_group.tga",
    ["group"]         = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_group.tga",
    ["DynamicBags"]   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_bags.tga",
    ["bags"]          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_bags.tga",
    ["DynamicChat"]   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_chat.tga",
    ["chat"]          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_chat.tga",
}

function UI.GetModuleIconPath(modKey)
    return MODULE_ICON_PATHS[tostring(modKey or "")] or "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_load.tga"
end

function UI.DrawBrandEmblem(parentFrame, size)
    if not parentFrame then return end
    if addonTable.PopulateBrandLogo then
        addonTable.PopulateBrandLogo(parentFrame, size or 22)
    else
        local tgaW = parentFrame:CreateTexture(nil, "ARTWORK", nil, 4)
        tgaW:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 1, -1)
        tgaW:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -1, 1)
        tgaW:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\logo_stem_white.tga")
        if not tgaW:GetTexture() then
            tgaW:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_white.tga")
        end
        tgaW:SetVertexColor(0.96, 0.97, 0.99, 1)
        local tgaA = parentFrame:CreateTexture(nil, "ARTWORK", nil, 5)
        tgaA:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 1, -1)
        tgaA:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -1, 1)
        tgaA:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\logo_loop_mask.tga")
        if not tgaA:GetTexture() then
            tgaA:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_accent.tga")
        end
        local ar, ag, ab = UI.GetActiveAccentColor()
        tgaA:SetVertexColor(ar, ag, ab, 1)
        function parentFrame:SetAccentColor(r, g, b, a)
            tgaW:SetVertexColor(0.96, 0.97, 0.99, a or 1)
            tgaA:SetVertexColor(r or 0.80, g or 0.84, b or 0.88, a or 1)
        end
    end
end

function UI.GetOnePixel(frame)
    local _, physHeight = GetPhysicalScreenSize()
    if not physHeight or physHeight <= 0 then physHeight = 1080 end
    local scale = (frame and frame.GetEffectiveScale and frame:GetEffectiveScale()) or UIParent:GetEffectiveScale() or 1
    if scale <= 0 then scale = 1 end
    return (768 / physHeight) / scale
end

function UI.CreatePixelBorder(frame, r, g, b, a, sublevel)
    if not frame or not frame.CreateTexture then return nil end
    local px = UI.GetOnePixel(frame)
    local lvl = sublevel or 2
    local border = {
        top    = UI.SolidTex(frame, "OVERLAY", lvl, r, g, b, a),
        bottom = UI.SolidTex(frame, "OVERLAY", lvl, r, g, b, a),
        left   = UI.SolidTex(frame, "OVERLAY", lvl, r, g, b, a),
        right  = UI.SolidTex(frame, "OVERLAY", lvl, r, g, b, a),
    }

    border.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    border.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    border.top:SetHeight(px)

    border.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    border.bottom:SetHeight(px)

    border.left:SetPoint("TOPLEFT", border.top, "BOTTOMLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", border.bottom, "TOPLEFT", 0, 0)
    border.left:SetWidth(px)

    border.right:SetPoint("TOPRIGHT", border.top, "BOTTOMRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", border.bottom, "TOPRIGHT", 0, 0)
    border.right:SetWidth(px)

    frame.dsBorder = {
        SetColor = function(_, cr, cg, cb, ca)
            border.top:SetColorTexture(cr, cg, cb, ca)
            border.bottom:SetColorTexture(cr, cg, cb, ca)
            border.left:SetColorTexture(cr, cg, cb, ca)
            border.right:SetColorTexture(cr, cg, cb, ca)
        end,
        SetThickness = function(_, mult)
            local p = UI.GetOnePixel(frame) * (mult or 1)
            border.top:SetHeight(p)
            border.bottom:SetHeight(p)
            border.left:SetWidth(p)
            border.right:SetWidth(p)
        end,
        Hide = function()
            border.top:Hide(); border.bottom:Hide(); border.left:Hide(); border.right:Hide()
        end,
        Show = function()
            border.top:Show(); border.bottom:Show(); border.left:Show(); border.right:Show()
        end,
    }
    return border
end

--------------------------------------------------------------------------------
-- Global Square Dot Checkbox Factory (Section 2.2 / Design System)
--------------------------------------------------------------------------------
function UI.CreateSquareCheckbox(parent, size)
    local sz = size or 14
    local cb = CreateFrame("Button", nil, parent)
    cb:SetSize(sz, sz)

    cb.bg = UI.SolidTex(cb, "BACKGROUND", 2, 0.024, 0.028, 0.039, 0.98)
    cb.bg:SetAllPoints()
    UI.CreatePixelBorder(cb, 0.165, 0.192, 0.259, 0.95, 3)

    local innerDot = UI.SolidTex(cb, "OVERLAY", 3, 1, 1, 1, 1.0)
    innerDot:SetPoint("CENTER", cb, "CENTER", 0, 0)
    innerDot:Hide()
    cb.innerDot = innerDot

    function cb:SetVisualState(stateKey)
        self.visualState = stateKey or "UNCHECKED"
        local ar, ag, ab = UI.GetActiveAccentColor()
        if stateKey == "CHECKED" then
            self.innerDot:SetSize(8, 8)
            self.innerDot:SetColorTexture(ar, ag, ab, 1.0)
            self.innerDot:Show()
            self.dsBorder:SetColor(ar, ag, ab, 0.95)
        elseif stateKey == "LOCKED" then
            self.innerDot:SetSize(8, 8)
            self.innerDot:SetColorTexture(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1.0)
            self.innerDot:Show()
            self.dsBorder:SetColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.95)
        elseif stateKey == "FROZEN" then
            self.innerDot:SetSize(8, 2)
            self.innerDot:SetColorTexture(UI.COLORS.CYAN.r, UI.COLORS.CYAN.g, UI.COLORS.CYAN.b, 1.0)
            self.innerDot:Show()
            self.dsBorder:SetColor(UI.COLORS.CYAN.r, UI.COLORS.CYAN.g, UI.COLORS.CYAN.b, 0.85)
        else -- UNCHECKED
            self.innerDot:Hide()
            self.dsBorder:SetColor(0.165, 0.192, 0.259, 0.95)
        end
    end

    function cb:GetVisualState()
        return self.visualState or "UNCHECKED"
    end

    cb:SetVisualState("UNCHECKED")
    return cb
end

_G.DynamicSuite = _G.DynamicSuite or {}
_G.DynamicSuite.UI = _G.DynamicSuite.UI or {}
_G.DynamicSuite.UI.CreateSquareCheckbox = UI.CreateSquareCheckbox

--------------------------------------------------------------------------------
-- Hybrid L-Bracket Section Header Factory (Section 2.4 / Design System)
--------------------------------------------------------------------------------
function UI.CreateSectionHeader(parent, arg2, arg3, subtitleText, padOverride)
    local text, yOffset
    if type(arg2) == "number" then
        yOffset = arg2
        text = arg3
    else
        text = arg2
        yOffset = arg3
    end

    local padX = padOverride or (parent and parent.innerPadX) or 0
    local hasSub = (subtitleText and subtitleText ~= "")
    local hdr = CreateFrame("Frame", nil, parent)
    hdr:SetHeight(hasSub and 36 or 20)
    hdr.hasSub = hasSub
    local y = yOffset or 0
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
    hdr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -padX, y)

    local ar, ag, ab = UI.GetActiveAccentColor()

    -- Vertical Pill: 3px wide x 34px tall (when subtitle present) solid texture in 100% Suite Accent at TOPLEFT (0, -1)
    local leftBar = UI.SolidTex(hdr, "ARTWORK", 1, ar, ag, ab, 1.0)
    leftBar:SetSize(3, hasSub and 34 or 16)
    leftBar:SetPoint("TOPLEFT", hdr, "TOPLEFT", 0, -1)
    hdr.leftBar = leftBar

    -- Bottom Underline: 1px tall solid texture in Suite Accent (alpha = 0.35) anchored from TOPLEFT, leftBar, BOTTOMLEFT, 0, 0 across to BOTTOMRIGHT, hdr, BOTTOMRIGHT, 0, 0
    local bottomLine = UI.SolidTex(hdr, "ARTWORK", 1, ar, ag, ab, 0.35)
    bottomLine:SetHeight(1)
    bottomLine:SetPoint("TOPLEFT", leftBar, "BOTTOMLEFT", 0, 0)
    bottomLine:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
    hdr.bottomLine = bottomLine
    hdr.botLine = bottomLine

    -- Line 1: 11pt Bold Uppercase Suite Accent font string
    local title = hdr:CreateFontString(nil, "OVERLAY")
    if hasSub then
        title:SetPoint("TOPLEFT", leftBar, "TOPRIGHT", 8, 0)
    else
        title:SetPoint("LEFT", leftBar, "RIGHT", 8, 0)
    end
    UI.SetFont(title, 11, "", ar, ag, ab, 1.0)
    if text then
        title:SetText(string.upper(text))
    end
    hdr.title = title

    if hasSub then
        local sub = hdr:CreateFontString(nil, "OVERLAY")
        sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
        sub:SetPoint("RIGHT", hdr, "RIGHT", -12, 0)
        sub:SetJustifyH("LEFT")
        sub:SetWordWrap(false)
        UI.SetFont(sub, 10, "", 0.64, 0.70, 0.78, 1.0)
        sub:SetText(subtitleText)
        hdr.subtitle = sub
    end

    function hdr:SetText(newText)
        if self.title then
            self.title:SetText(string.upper(newText or ""))
        end
    end

    function hdr:RefreshAccent()
        local r, g, b = UI.GetActiveAccentColor()
        if self.leftBar then self.leftBar:SetColorTexture(r, g, b, 1.0) end
        if self.bottomLine then self.bottomLine:SetColorTexture(r, g, b, 0.35) end
        if self.title then self.title:SetTextColor(r, g, b, 1.0) end
        if self.subtitle then self.subtitle:SetTextColor(0.64, 0.70, 0.78, 1.0) end
    end

    return hdr
end

_G.DynamicSuite.UI.CreateSectionHeader = UI.CreateSectionHeader

function UI.IsNegativePillOption(val, label)
    if val == false or val == 0 or val == "0" then return true end
    local s = string.upper(tostring(val or label or ""))
    local lbl = string.upper(tostring(label or ""))
    if s == "OFF" or s == "DISABLED" or s == "NONE" or s == "MUTED" or s == "HIDDEN" or s == "NEVER" or s == "BLIZZARD_DEFAULT" then
        return true
    end
    if lbl == "OFF" or lbl == "DISABLED" or lbl == "NONE" or lbl == "MUTED" or lbl == "HIDDEN" or lbl == "NEVER" or lbl == "RESET TO PREVIOUS" then
        return true
    end
    return false
end
_G.DynamicSuite.UI.IsNegativePillOption = UI.IsNegativePillOption

local function ApplyFlatButtonVisual(btn, isHovered)
    if not btn or not btn.bg or not btn.dsBorder then return end
    local ar, ag, ab = UI.GetActiveAccentColor()
    local isActive = btn.isSelected
    if isActive == nil then
        isActive = btn.isPrimary
    end
    local col = btn.selectedColor
    local cr = (col and col.r) or ar
    local cg = (col and col.g) or ag
    local cb = (col and col.b) or ab

    if isActive and btn.isNegativeOpt then
        if not btn.OffBar then
            local offBar = UI.SolidTex(btn, "OVERLAY", 4, 0.973, 0.443, 0.443, 0.85)
            offBar:SetHeight(1.5)
            offBar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
            offBar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
            btn.OffBar = offBar
        end
        btn.OffBar:SetColorTexture(0.973, 0.443, 0.443, 0.85)
        btn.OffBar:Show()
        if isHovered then
            btn.bg:SetColorTexture(0.141, 0.169, 0.224, 0.98)
            btn.dsBorder:SetColor(0.471, 0.545, 0.651, 0.95)
        else
            btn.bg:SetColorTexture(0.118, 0.141, 0.188, 0.98)
            btn.dsBorder:SetColor(0.392, 0.455, 0.545, 0.90)
        end
        if btn.label then btn.label:SetTextColor(0.886, 0.910, 0.941, 1.0) end
        return
    end

    if btn.OffBar then btn.OffBar:Hide() end

    if isActive then
        local g = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local fillAlpha = (g and g.pillFillAlpha) or 0.42
        local hoverAlpha = math.min(0.65, fillAlpha + 0.10)
        if isHovered then
            btn.bg:SetColorTexture(cr, cg, cb, hoverAlpha)
            btn.dsBorder:SetColor(cr, cg, cb, 1.0)
            if btn.label then btn.label:SetTextColor(1, 1, 1, 1) end
        else
            btn.bg:SetColorTexture(cr, cg, cb, fillAlpha)
            btn.dsBorder:SetColor(cr, cg, cb, 0.95)
            if btn.label then
                if btn.keepColoredLabelWhenSelected then
                    btn.label:SetTextColor(cr, cg, cb, 1)
                else
                    btn.label:SetTextColor(1, 1, 1, 1)
                end
            end
        end
    else
        if isHovered then
            btn.bg:SetColorTexture(UI.COLORS.BTN_HOVER.r, UI.COLORS.BTN_HOVER.g, UI.COLORS.BTN_HOVER.b, 1.0)
            if btn.isNegativeOpt then
                btn.dsBorder:SetColor(0.392, 0.455, 0.545, 0.85)
            else
                btn.dsBorder:SetColor(cr, cg, cb, 0.75)
            end
            if btn.label then btn.label:SetTextColor(1, 1, 1, 1) end
        else
            if btn.idleBgColor then
                btn.bg:SetColorTexture(btn.idleBgColor.r, btn.idleBgColor.g, btn.idleBgColor.b, btn.idleBgColor.a or 0.96)
            else
                local idleBgAlpha = btn.idleBgAlpha or 0.94
                btn.bg:SetColorTexture(UI.COLORS.BTN_BG.r, UI.COLORS.BTN_BG.g, UI.COLORS.BTN_BG.b, idleBgAlpha)
            end
            if btn.idleBorderColor then
                btn.dsBorder:SetColor(btn.idleBorderColor.r, btn.idleBorderColor.g, btn.idleBorderColor.b, btn.idleBorderColor.a or 0.35)
            else
                btn.dsBorder:SetColor(UI.COLORS.BTN_BORDER.r, UI.COLORS.BTN_BORDER.g, UI.COLORS.BTN_BORDER.b, UI.COLORS.BTN_BORDER.a)
            end
            if btn.label then
                if btn.idleTextColor then
                    btn.label:SetTextColor(btn.idleTextColor.r, btn.idleTextColor.g, btn.idleTextColor.b, btn.idleTextColor.a or 1)
                else
                    btn.label:SetTextColor(0.86, 0.88, 0.92, 0.95)
                end
            end
        end
    end
end

local function CreateFlatButton(parent, width, height, text, isPrimary)
    UI.RefreshPaletteCache()
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width or 100, height or 24)
    btn.isPrimary = isPrimary
    btn.isSelected = (isPrimary == true)

    local bgCol = isPrimary and UI.COLORS.ACCENT or UI.COLORS.BTN_BG
    local bgAlpha = isPrimary and 0.28 or 0.94
    btn.bg = UI.SolidTex(btn, "BACKGROUND", 1, bgCol.r, bgCol.g, bgCol.b, bgAlpha)
    btn.bg:SetAllPoints()

    local bColor = isPrimary and UI.COLORS.ACCENT or UI.COLORS.BTN_BORDER
    local bAlpha = isPrimary and 0.95 or UI.COLORS.BTN_BORDER.a
    UI.CreatePixelBorder(btn, bColor.r, bColor.g, bColor.b, bAlpha, 2)

    btn._minWidth = width or 100
    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", btn, "LEFT", 6, 0)
    label:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    if label.SetMaxLines then label:SetMaxLines(1) end
    UI.SetFont(label, 11, "", 1, 1, 1, 0.94)
    btn.label = label

    local rawSetText = label.SetText
    function btn:UpdateAutoWidth()
        if not self._autoExpandWidth then return end
        local rawTxt = (label.GetText and label:GetText()) or ""
        local cleanTxt = tostring(rawTxt):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
        local ok, uw = pcall(function()
            return (label.GetUnboundedStringWidth and label:GetUnboundedStringWidth()) or label:GetStringWidth() or 0
        end)
        local measuredW = (ok and type(uw) == "number" and uw > 0) and uw or (#cleanTxt * 6.8)
        local targetW = math.max(self._minWidth or 66, math.ceil(measuredW + 20))
        if math.abs((self:GetWidth() or 0) - targetW) > 1 then
            self:SetWidth(targetW)
        end
    end
    label.SetText = function(selfFs, newTxt)
        rawSetText(selfFs, newTxt or "")
        btn:UpdateAutoWidth()
    end
    label:SetText(text or "")
    btn:HookScript("OnShow", function(self) self:UpdateAutoWidth() end)

    function btn:SetSelected(isSel, customCol)
        self.isSelected = (isSel == true)
        if customCol ~= nil then
            self.selectedColor = customCol
        end
        ApplyFlatButtonVisual(self, self:IsMouseOver())
    end

    function btn:RefreshVisual()
        ApplyFlatButtonVisual(self, self:IsMouseOver())
    end

    btn:SetScript("OnEnter", function(self)
        ApplyFlatButtonVisual(self, true)
        if self.OnCustomEnter then self:OnCustomEnter() end
    end)

    btn:SetScript("OnLeave", function(self)
        ApplyFlatButtonVisual(self, false)
        if self.OnCustomLeave then self:OnCustomLeave() end
    end)

    ApplyFlatButtonVisual(btn, false)
    return btn
end

local function CreateDSOptionSlider(parent, width, minVal, maxVal, stepVal, formatFunc, getValFunc, setValFunc)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width or 256, 26)
    holder:EnableMouse(true)
    holder:EnableMouseWheel(true)

    local ar0, ag0, ab0 = UI.GetActiveAccentColor()
    local valText = holder:CreateFontString(nil, "OVERLAY")
    valText:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
    valText:SetWidth(52)
    valText:SetJustifyH("RIGHT")
    UI.SetFont(valText, 11, "", ar0, ag0, ab0, 1.0)
    holder.valText = valText

    local track = CreateFrame("Frame", nil, holder)
    track:SetPoint("LEFT", holder, "LEFT", 0, 0)
    track:SetPoint("RIGHT", valText, "LEFT", -10, 0)
    track:SetHeight(4)
    track.bg = UI.SolidTex(track, "BACKGROUND", 0, 0.035, 0.039, 0.051, 0.98)
    track.bg:SetAllPoints()
    track.border = UI.CreatePixelBorder(track, 1, 1, 1, 0.14, 1)

    local fill = UI.SolidTex(track, "ARTWORK", 1, ar0, ag0, ab0, 0.85)
    fill:SetPoint("TOPLEFT", track, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 1, 1)
    fill:SetWidth(1)
    track.FillBar = fill

    local thumb = UI.SolidTex(track, "OVERLAY", 3, 0.97, 0.98, 1.00, 1.0)
    thumb:SetSize(6, 14)
    if thumb.SetSnapToPixelGrid then
        thumb:SetSnapToPixelGrid(false)
        thumb:SetTexelSnappingBias(0)
    end
    holder.thumb = thumb

    local isDragging = false
    local lastCommittedValue = nil

    local function SnapValue(v)
        v = math.max(minVal, math.min(maxVal, v))
        if stepVal and stepVal > 0 then
            v = math.floor((v - minVal) / stepVal + 0.5) * stepVal + minVal
        end
        return math.max(minVal, math.min(maxVal, v))
    end

    local function RefreshSliderVisual(v, rawPct)
        local ar, ag, ab = UI.GetActiveAccentColor()
        fill:SetColorTexture(ar, ag, ab, 0.85)
        valText:SetTextColor(ar, ag, ab, 1.0)
        if isDragging or holder:IsMouseOver() then
            thumb:SetColorTexture(ar, ag, ab, 1.0)
        else
            thumb:SetColorTexture(0.97, 0.98, 1.00, 1.0)
        end
        local cur = SnapValue(v or getValFunc() or minVal)
        local pct = rawPct
        if pct == nil then
            pct = (maxVal > minVal) and ((cur - minVal) / (maxVal - minVal)) or 0
        end
        pct = math.max(0, math.min(1, pct))
        local tw = track:GetWidth()
        if not tw or tw <= 0 then tw = (width or 256) - 62 end
        fill:SetWidth(math.max(1, pct * math.max(1, tw - 2)))
        thumb:ClearAllPoints()
        thumb:SetPoint("CENTER", track, "LEFT", pct * tw, 0)
        valText:SetText(formatFunc and formatFunc(cur) or tostring(cur))
    end
    holder.RefreshVisual = RefreshSliderVisual
    holder.RefreshValue = RefreshSliderVisual

    local function UpdateFromCursor()
        if isDragging and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            isDragging = false
            holder:SetScript("OnUpdate", nil)
            RefreshSliderVisual()
            return
        end
        local scale = track:GetEffectiveScale()
        local cx = GetCursorPosition() / scale
        local left, tw = track:GetLeft(), track:GetWidth()
        if left and tw and tw > 0 then
            local pct = math.max(0, math.min(1, (cx - left) / tw))
            local stepped = SnapValue(minVal + pct * (maxVal - minVal))
            if stepped ~= lastCommittedValue then
                lastCommittedValue = stepped
                setValFunc(stepped)
            end
            RefreshSliderVisual(stepped, pct)
        end
    end

    holder:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            isDragging = true
            UpdateFromCursor()
            self:SetScript("OnUpdate", UpdateFromCursor)
        end
    end)
    holder:SetScript("OnMouseUp", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
        RefreshSliderVisual()
    end)
    holder:SetScript("OnHide", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
    end)
    holder:SetScript("OnEnter", function(self)
        RefreshSliderVisual()
        if GameTooltip then
            local ar, ag, ab = UI.GetActiveAccentColor()
            local hex = string.format("%02X%02X%02X", math.floor(ar * 255 + 0.5), math.floor(ag * 255 + 0.5), math.floor(ab * 255 + 0.5))
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(string.format("|cFF%sLeft-Click / Drag:|r |cFFE2E8F0Adjust value|r", hex))
            GameTooltip:AddLine(string.format("|cFF%sMousewheel:|r |cFFE2E8F0Fine-tune by 1 step|r", hex))
            GameTooltip:Show()
        end
    end)
    holder:SetScript("OnLeave", function()
        RefreshSliderVisual()
        if GameTooltip then GameTooltip:Hide() end
    end)
    holder:SetScript("OnMouseWheel", function(_, delta)
        local cur = getValFunc() or minVal
        local step = stepVal or ((maxVal - minVal) / 20)
        local newVal = SnapValue(cur + (delta > 0 and step or -step))
        lastCommittedValue = newVal
        setValFunc(newVal)
        RefreshSliderVisual(newVal)
    end)
    holder:SetScript("OnShow", function()
        C_Timer.After(0, function() RefreshSliderVisual() end)
    end)

    return holder
end
_G.DynamicSuite.UI.CreateSliderControl = CreateDSOptionSlider
    function UI.CreateSegmentedPills(parent, optionsList, getValFn, setValFn)
        local container = CreateFrame("Frame", nil, parent)
        container:SetHeight(26)
        local pills = {}
        local totalW = 0
        for idx, opt in ipairs(optionsList or {}) do
            local lbl = tostring(opt.label or opt.value or ""):gsub("^|cff%x%x%x%x%x%x", ""):gsub("|r$", "")
            local minW = opt.width or 66
            local pBtn = CreateFlatButton(container, minW, 24, lbl, false)
            pBtn._explicitWidth = opt.width
            local strW = pBtn.label and pBtn.label:GetStringWidth() or (#lbl * 7)
            local pillW = math.max(minW, math.ceil(strW + 32))
            pBtn:SetWidth(pillW)
            pBtn.optVal = opt.value
            pBtn.baseLabel = lbl
            pBtn.isNegativeOpt = UI.IsNegativePillOption(opt.value, lbl)
            pBtn.idleBgColor = { r = 0.078, g = 0.090, b = 0.122, a = 0.95 }
            pBtn.idleBorderColor = { r = 0.145, g = 0.165, b = 0.212, a = 0.95 }
            pBtn.idleTextColor = { r = 0.68, g = 0.72, b = 0.80, a = 1 }

            local offBar = UI.SolidTex(pBtn, "OVERLAY", 4, 0.973, 0.443, 0.443, 0.85)
            offBar:SetHeight(1.5)
            offBar:SetPoint("BOTTOMLEFT", pBtn, "BOTTOMLEFT", 1, 1)
            offBar:SetPoint("BOTTOMRIGHT", pBtn, "BOTTOMRIGHT", -1, 1)
            offBar:Hide()
            pBtn.OffBar = offBar

            local checkTex = UI.SolidTex(pBtn, "OVERLAY", 3, 1, 1, 1, 0.98)
            checkTex:SetSize(6, 6)
            checkTex:SetPoint("LEFT", pBtn, "LEFT", 8, 0)
            checkTex:Hide()
            pBtn.checkTex = checkTex

            if idx == 1 then
                pBtn:SetPoint("LEFT", container, "LEFT", 0, 0)
            else
                pBtn:SetPoint("LEFT", pills[idx - 1], "RIGHT", 4, 0)
                totalW = totalW + 4
            end
            totalW = totalW + pillW
            pBtn:SetScript("OnClick", function()
                if setValFn then setValFn(opt.value) end
                container:RefreshValue()
            end)
            pills[idx] = pBtn
        end
        container:SetWidth(math.max(80, totalW))

        function container:RefreshValue()
            local curVal = getValFn and getValFn()
            local ar, ag, ab = UI.GetActiveAccentColor()
            local accentCol = { r = ar, g = ag, b = ab }
            local recomputedW = 0
            for idx, pBtn in ipairs(pills) do
                local isSel = (pBtn.optVal == curVal)
                pBtn:SetSelected(isSel, accentCol)
                local rawW = pBtn.label and ((pBtn.label.GetUnboundedStringWidth and pBtn.label:GetUnboundedStringWidth()) or pBtn.label:GetStringWidth()) or 0
                local strW = math.max(rawW or 0, #(pBtn.baseLabel or "") * 6.8)
                local pillW = math.max(pBtn._explicitWidth or 66, pBtn._minWidth or 66, math.ceil(strW + 20))
                pBtn:SetWidth(pillW)
                if idx > 1 then recomputedW = recomputedW + 4 end
                recomputedW = recomputedW + pillW
                if pBtn.checkTex then
                    pBtn.checkTex:Hide()
                    pBtn.checkTex:SetColorTexture(1, 1, 1, 0.98)
                end
                if pBtn.label then
                    pBtn.label:ClearAllPoints()
                    if isSel then
                        pBtn.label:SetPoint("LEFT", pBtn, "LEFT", 6, 0)
                        pBtn.label:SetPoint("RIGHT", pBtn, "RIGHT", -6, 0)
                    else
                        pBtn.label:SetPoint("LEFT", pBtn, "LEFT", 6, 0)
                        pBtn.label:SetPoint("RIGHT", pBtn, "RIGHT", -6, 0)
                    end
                    pBtn.label:SetJustifyH("CENTER")
                end
            end
            container:SetWidth(math.max(80, recomputedW))
        end

        container:HookScript("OnShow", function(self) self:RefreshValue() end)
        container:RefreshValue()
        return container
    end
    local function CreateSpaciousOptionRow(parentFrame, rowIndex, rowTitle, rowDesc)
        local row = CreateFrame("Frame", nil, parentFrame)
        local yPos = -52 - ((rowIndex - 1) * 58)
        row:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, yPos)
        row:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", 0, yPos)
        row:SetHeight(52)
        row._titleTopY = -10
        row._subGapY = -3

        row.bg = UI.SolidTex(row, "BACKGROUND", 0, UI.COLORS.CARD_BG.r, UI.COLORS.CARD_BG.g, UI.COLORS.CARD_BG.b, 0.92)
        row.bg:SetAllPoints()
        UI.CreatePixelBorder(row, 1, 1, 1, 0.08, 2)

        local t = row:CreateFontString(nil, "OVERLAY")
        t:SetPoint("TOPLEFT", row, "TOPLEFT", 16, row._titleTopY)
        t:SetPoint("RIGHT", row, "RIGHT", -420, 0)
        t:SetJustifyH("LEFT")
        t:SetWordWrap(false)
        UI.SetFont(t, 12, "", 1, 1, 1, 0.96)
        t:SetText(rowTitle)
        row.titleText = t
        row.title = t

        local d = row:CreateFontString(nil, "OVERLAY")
        d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, row._subGapY)
        d:SetPoint("RIGHT", row, "RIGHT", -420, 0)
        d:SetJustifyH("LEFT")
        d:SetWordWrap(true); if d.SetMaxLines then d:SetMaxLines(2) end
        UI.SetFont(d, 10, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 0.92)
        d:SetText(rowDesc)
        row.descText = d
        row.sub = d

        function row:BindRightControl(ctrl)
            if not ctrl then return end
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", row, "TOPLEFT", 16, row._titleTopY or -10)
            t:SetPoint("RIGHT", ctrl, "LEFT", -16, 0)
            d:ClearAllPoints()
            d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, row._subGapY or -3)
            d:SetPoint("RIGHT", ctrl, "LEFT", -16, 0)
        end

        return row
    end
    UI.CreateFlatButton = CreateFlatButton
    UI.ApplyFlatButtonVisual = ApplyFlatButtonVisual
    UI.CreateDSOptionSlider = CreateDSOptionSlider
    UI.CreateSpaciousOptionRow = CreateSpaciousOptionRow

end

local CreateFlatButton        = UI.CreateFlatButton
local ApplyFlatButtonVisual   = UI.ApplyFlatButtonVisual
local CreateDSOptionSlider    = UI.CreateDSOptionSlider or UI.CreateSliderControl
local CreateSpaciousOptionRow = UI.CreateSpaciousOptionRow

--------------------------------------------------------------------------------
-- Hierarchy & Tree Classification + CPU Metrics
--------------------------------------------------------------------------------
local parentMap = {}
local sortMode = "NAME" -- "NAME", "CPU_CUR", "CPU_AVG", "CPU_PEAK"
local lastMemorySampleTime = 0
local cachedTotalMemoryMB = 0

local function RefreshMemoryCacheIfNeeded()
    local now = GetTime and GetTime() or 0
    if now - lastMemorySampleTime > 4.0 then
        lastMemorySampleTime = now
        if UpdateAddOnMemoryUsage then
            pcall(UpdateAddOnMemoryUsage)
        end
        local totalKB = 0
        local num = C_AddOns.GetNumAddOns()
        for i = 1, num do
            if C_AddOns.IsAddOnLoaded(i) and GetAddOnMemoryUsage then
                totalKB = totalKB + (GetAddOnMemoryUsage(i) or 0)
            end
        end
        cachedTotalMemoryMB = totalKB / 1024
    end
    return cachedTotalMemoryMB
end

local function GetAddonCpuRaw(name, explicitMode)
    if not (C_AddOnProfiler and C_AddOnProfiler.IsEnabled and C_AddOnProfiler.IsEnabled()) then
        return 0
    end
    local mEnum = Enum and Enum.AddOnProfilerMetric
    if not mEnum then return 0 end
    local mode = explicitMode or sortMode
    local metric = mEnum.RecentAverageTime
    if mode == "CPU_AVG" and mEnum.SessionAverageTime then
        metric = mEnum.SessionAverageTime
    elseif mode == "CPU_PEAK" and mEnum.PeakTime then
        metric = mEnum.PeakTime
    end
    if not metric or not C_AddOns.GetAddOnInfo(name) then return 0 end
    return C_AddOnProfiler.GetAddOnMetric(name, metric) or 0
end

local function GetItemTotalCpu(item)
    local total = GetAddonCpuRaw(item.name)
    if type(item.children) == "table" then
        for _, c in ipairs(item.children or {}) do
            total = total + GetAddonCpuRaw(c.name)
        end
    end
    return total
end

local function StripFormatting(str)
    if not str then return "" end
    local s = str:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    s = s:gsub("^[<>%s%-_!]+", "")
    s = s:gsub("([%w])>%s+", "%1 - "):gsub("[<>]+", "")
    return s
end

local function ExtractFamilyPrefix(name, cleanTitle)
    local bracketPrefix = cleanTitle and cleanTitle:match("^([%w]+)%s")
    if name:find("^DBM%-") or (cleanTitle and cleanTitle:find("^DBM%s")) then
        return "DBM"
    end
    local folderBase = name:match("^([^_]+)_") or name:match("^([^-]+)%-")
    if folderBase and #folderBase >= 2 then
        return folderBase
    end
    if bracketPrefix and #bracketPrefix >= 4 then
        return bracketPrefix
    end
    return nil
end

local SUITE_HUB_ADDONS = {
    ["DynamicLoad"]   = true,
    ["DynamicMarker"] = true,
    ["DynamicZoom"]   = true,
    ["DynamicFPS"]    = true,
    ["DynamicPrep"]   = true,
    ["DynamicGroup"]  = true,
    ["DynamicBags"]   = true,
    ["DynamicChat"]   = true,
}

local function BuildAddonHierarchy()
    parentMap = {}
    local rawList = {}
    local byName = {}
    local dsHubItem = nil
    local num = C_AddOns.GetNumAddOns()

    for i = 1, num do
        local name, title = C_AddOns.GetAddOnInfo(i)
        if name then
            local rawTitle = title or name
            local iconTex = C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(name, "IconTexture") or nil
            local iconAtlas = C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(name, "IconAtlas") or nil
            if name == "DynamicSuite" then
                dsHubItem = {
                    name = "DynamicSuite",
                    title = "DynamicSuite",
                    sortKey = "000_dynamicsuite",
                    parent = nil,
                    children = {},
                    isParent = false,
                    isDynamicSuiteHub = true,
                    iconTex = iconTex,
                    iconAtlas = iconAtlas,
                }
                byName["DynamicSuite"] = dsHubItem
            elseif name ~= "DynamicFrame" then
                local item = {
                    name = name,
                    title = rawTitle,
                    sortKey = StripFormatting(rawTitle):lower(),
                    parent = nil,
                    children = {},
                    isParent = false,
                    isStandaloneSuiteFolder = (SUITE_HUB_ADDONS[name] == true),
                    iconTex = iconTex,
                    iconAtlas = iconAtlas,
                }
                table.insert(rawList, item)
                byName[name] = item
            end
        end
    end

    local unparentedByPrefix = {}
    for _, item in ipairs(rawList) do
        local name = item.name
        local base = name:match("^([^_]+)_") or name:match("^([^-]+)%-")
        if not base then
            for otherName, _ in pairs(byName) do
                if otherName ~= name and #name > #otherName and name:sub(1, #otherName) == otherName then
                    base = otherName
                    break
                end
            end
        end

        if base and byName[base] and base ~= name then
            item.parent = base
            parentMap[name] = base
            table.insert(byName[base].children, item)
            byName[base].isParent = true
        else
            local prefix = ExtractFamilyPrefix(name, StripFormatting(item.title))
            if prefix then
                unparentedByPrefix[prefix] = unparentedByPrefix[prefix] or {}
                table.insert(unparentedByPrefix[prefix], item)
            end
        end
    end

    for prefix, group in pairs(unparentedByPrefix) do
        if #group >= 2 then
            local hubItem = byName[prefix]
            if not hubItem then
                local bestScore = -1
                for _, candidate in ipairs(group) do
                    if not candidate.parent then
                        local n = candidate.name:lower()
                        local t = candidate.sortKey
                        local score = 0
                        if n == (prefix:lower() .. "-core") or n == (prefix:lower() .. "_core") or n == (prefix:lower() .. "core") then
                            score = 100
                        elseif t:find("main core", 1, true) or t:find("core", 1, true) then
                            score = 90
                        elseif n:find("data", 1, true) or (t:find("data", 1, true) and not t:find("locale", 1, true)) then
                            score = 80
                        elseif n:find("base", 1, true) or n:find("main", 1, true) or n:find("options", 1, true) then
                            score = 70
                        else
                            score = math.max(1, 50 - #n)
                        end
                        if score > bestScore then
                            bestScore = score
                            hubItem = candidate
                        end
                    end
                end
            end

            if hubItem then
                for _, member in ipairs(group) do
                    if member ~= hubItem and not member.parent then
                        member.parent = hubItem.name
                        parentMap[member.name] = hubItem.name
                        table.insert(hubItem.children, member)
                        hubItem.isParent = true
                    end
                end
            end
        end
    end

    local topLevel = {}
    for _, item in ipairs(rawList) do
        if not item.parent then
            table.insert(topLevel, item)
        end
    end

    if sortMode ~= "NAME" then
        table.sort(topLevel, function(a, b)
            local cpuA = GetItemTotalCpu(a)
            local cpuB = GetItemTotalCpu(b)
            if math.abs(cpuA - cpuB) > 0.0001 then
                return cpuA > cpuB
            end
            return a.sortKey < b.sortKey
        end)
        for _, item in ipairs(topLevel) do
            if item.children and #item.children > 1 then
                table.sort(item.children, function(a, b)
                    local cpuA = GetAddonCpuRaw(a.name)
                    local cpuB = GetAddonCpuRaw(b.name)
                    if math.abs(cpuA - cpuB) > 0.0001 then
                        return cpuA > cpuB
                    end
                    return a.sortKey < b.sortKey
                end)
            end
        end
    else
        table.sort(topLevel, function(a, b)
            return a.sortKey < b.sortKey
        end)
        for _, item in ipairs(topLevel) do
            if item.children and #item.children > 1 then
                table.sort(item.children, function(a, b)
                    return a.sortKey < b.sortKey
                end)
            end
        end
    end

    if dsHubItem then
        table.insert(topLevel, 1, dsHubItem)
    end

    return topLevel, byName
end

function addonTable.GetAddonParent(name)
    if not name then return nil end
    if not next(parentMap) then
        BuildAddonHierarchy()
    end
    return parentMap[name]
end

local function GetCollapsedParents()
    if DynamicLoadDB then
        DynamicLoadDB.collapsedParents = DynamicLoadDB.collapsedParents or collapsedParents
        collapsedParents = DynamicLoadDB.collapsedParents
        return DynamicLoadDB.collapsedParents
    end
    return collapsedParents
end

local function IsParentCollapsed(parentName)
    local cp = GetCollapsedParents()
    return cp[parentName] == true
end

local function SetParentCollapsed(parentName, isCollapsed)
    local cp = GetCollapsedParents()
    if isCollapsed then
        cp[parentName] = true
    else
        cp[parentName] = nil
    end
end

local function AreAnyParentsExpanded(topLevel)
    local list = topLevel or BuildAddonHierarchy()
    local cp = GetCollapsedParents()
    for _, item in ipairs(list) do
        if item.isParent and item.children and #item.children > 0 then
            if not cp[item.name] then
                return true
            end
        end
    end
    return false
end

local function ToggleAllParentsCollapsed(forceCollapse)
    local list = BuildAddonHierarchy()
    local shouldCollapse = forceCollapse
    if shouldCollapse == nil then
        shouldCollapse = AreAnyParentsExpanded(list)
    end
    local cp = GetCollapsedParents()
    for _, item in ipairs(list) do
        if item.isParent and item.children and #item.children > 0 then
            if shouldCollapse then
                cp[item.name] = true
            else
                cp[item.name] = nil
            end
        end
    end
    return shouldCollapse
end

local function FormatCpuValueAsPct(msVal, forceColorHex)
    if not (C_AddOnProfiler and C_AddOnProfiler.IsEnabled and C_AddOnProfiler.IsEnabled()) then
        return "|cFF888888--|r"
    end
    local fps = GetFramerate() or 60
    if fps <= 0 then fps = 60 end
    local pct = ((msVal or 0) / (1000 / fps)) * 100

    if pct <= 0.001 then
        return "|cFF7A8392<0.01%|r"
    elseif forceColorHex then
        return string.format("|cFF%s%.2f%%|r", forceColorHex, pct)
    elseif pct > 5.0 then
        return string.format("|cFFFF5555%.2f%%|r", pct)
    elseif pct > 1.0 then
        return string.format("|cFFF5B82E%.2f%%|r", pct)
    else
        return string.format("|cFFD2D7E0%.2f%%|r", pct)
    end
end

local function FormatCpuUsage(name)
    if not (C_AddOnProfiler and C_AddOnProfiler.IsEnabled and C_AddOnProfiler.IsEnabled()) then
        return "|cFF888888--|r"
    end
    local val = GetAddonCpuRaw(name, sortMode)
    return FormatCpuValueAsPct(val)
end

local function GetOverallTelemetryStats()
    local curPct, avgPct, peakPct = 0, 0, 0
    local fps = GetFramerate() or 60
    if fps <= 0 then fps = 60 end
    local frameBudgetMs = 1000 / fps
    if C_AddOnProfiler and C_AddOnProfiler.IsEnabled and C_AddOnProfiler.IsEnabled() and C_AddOnProfiler.GetOverallMetric and Enum and Enum.AddOnProfilerMetric then
        local mEnum = Enum.AddOnProfilerMetric
        local curMs = mEnum.RecentAverageTime and C_AddOnProfiler.GetOverallMetric(mEnum.RecentAverageTime) or 0
        local avgMs = mEnum.SessionAverageTime and C_AddOnProfiler.GetOverallMetric(mEnum.SessionAverageTime) or 0
        local encMs = mEnum.EncounterAverageTime and C_AddOnProfiler.GetOverallMetric(mEnum.EncounterAverageTime) or 0
        local lastMs = mEnum.LastTime and C_AddOnProfiler.GetOverallMetric(mEnum.LastTime) or 0
        local rawPeakMs = mEnum.PeakTime and C_AddOnProfiler.GetOverallMetric(mEnum.PeakTime) or 0
        local sanePeakMs = (rawPeakMs > 100) and math.max(encMs, lastMs, curMs * 1.5, avgMs * 1.5) or math.max(rawPeakMs, encMs, curMs)
        curPct = (curMs / frameBudgetMs) * 100
        avgPct = (avgMs / frameBudgetMs) * 100
        peakPct = math.min(999.9, (sanePeakMs / frameBudgetMs) * 100)
    end
    local memMB = RefreshMemoryCacheIfNeeded()
    return curPct, avgPct, peakPct, memMB
end

--------------------------------------------------------------------------------
-- Smart Suite Engine: Parent Cascade vs. Individually Pinned Child Protection
--------------------------------------------------------------------------------
local function ResolveCanonKey(name)
    if addonTable and addonTable.ResolveCanonicalAddonName then
        return addonTable.ResolveCanonicalAddonName(name) or name
    end
    return name
end

local function SetParentCascaded(childName, state)
    if not DynamicLoadDB or not childName then return end
    local canon = ResolveCanonKey(childName)
    DynamicLoadDB.parentCascaded = DynamicLoadDB.parentCascaded or {}
    DynamicLoadDB.parentCascaded[canon] = state
    if canon ~= childName then
        DynamicLoadDB.parentCascaded[childName] = nil
    end
end

local function GetParentCascaded(childName)
    if DynamicLoadDB and DynamicLoadDB.parentCascaded and childName then
        local canon = ResolveCanonKey(childName)
        return DynamicLoadDB.parentCascaded[canon] or DynamicLoadDB.parentCascaded[childName]
    end
    return nil
end

local function IsSuiteModuleExplicitlyDisabled(modName)
    if not modName or modName == "DynamicLoad" or modName == "DynamicSuite" or modName == "load" then
        return false
    end
    if addonTable and type(addonTable.IsSuiteModuleExplicitlyDisabled) == "function" then
        return addonTable.IsSuiteModuleExplicitlyDisabled(modName) == true
    end
    local sharedTbl = _G.DynamicSuite and _G.DynamicSuite._sharedAddonTable
    if sharedTbl and type(sharedTbl.IsSuiteModuleExplicitlyDisabled) == "function" then
        return sharedTbl.IsSuiteModuleExplicitlyDisabled(modName) == true
    end
    local shortKey = tostring(modName):gsub("^Dynamic", ""):lower()
    local canonMod = "Dynamic" .. shortKey:sub(1, 1):upper() .. shortKey:sub(2)
    if shortKey == "fps" then canonMod = "DynamicFPS" end
    if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.disabledModules) == "table" then
        if _G.DynamicSuiteDB.disabledModules[modName] == true
            or _G.DynamicSuiteDB.disabledModules[canonMod] == true
            or _G.DynamicSuiteDB.disabledModules[shortKey] == true then
            return true
        end
    end
    if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.global) == "table" and type(_G.DynamicSuiteDB.global.disabledModules) == "table" then
        if _G.DynamicSuiteDB.global.disabledModules[modName] == true
            or _G.DynamicSuiteDB.global.disabledModules[canonMod] == true
            or _G.DynamicSuiteDB.global.disabledModules[shortKey] == true then
            return true
        end
    end
    return false
end

local function IsIndividuallyPinnedChild(childName)
    local canon = ResolveCanonKey(childName)
    local sec = (addonTable and addonTable.GetAddonSecurityState and addonTable.GetAddonSecurityState(canon)) or "NORMAL"
    if sec == "NORMAL" then
        return false
    end
    return GetParentCascaded(canon) == nil
end

local function GetParentSuiteStats(parentItem, desired)
    if not parentItem then return 0, 0, 0, 0, 0, 0, 0 end
    local total = (parentItem.children and #parentItem.children) or 0
    local activeCount = 0
    local lockedCount = 0
    local frozenCount = 0
    local govTotal = 0
    local govLockedCount = 0
    local govFrozenCount = 0

    local fnIsLocked = addonTable and addonTable.IsAddonLocked
    local fnIsFrozen = addonTable and addonTable.IsAddonFrozen

    if type(parentItem.children) == "table" then
        for _, child in ipairs(parentItem.children or {}) do
            local cName = child and ResolveCanonKey(child.name)
            if cName then
                local isCoreMod = (cName == "DynamicLoad")
                local isSuiteMod = (child.isSuiteModule == true)
                local isSuiteDis = isSuiteMod and IsSuiteModuleExplicitlyDisabled(cName)
                local cLocked = isCoreMod or ((fnIsLocked and fnIsLocked(cName)) or false)
                local cFrozen = (not cLocked) and (isSuiteDis or (fnIsFrozen and fnIsFrozen(cName) or false))
                if cLocked then
                    lockedCount = lockedCount + 1
                    activeCount = activeCount + 1
                elseif cFrozen then
                    frozenCount = frozenCount + 1
                elseif desired and desired[cName] == true then
                    activeCount = activeCount + 1
                end
            end
        end

        for _, child in ipairs(parentItem.children or {}) do
            local cName = child and ResolveCanonKey(child.name)
            if cName and not IsIndividuallyPinnedChild(cName) then
                govTotal = govTotal + 1
                local isCoreMod = (cName == "DynamicLoad")
                local isSuiteMod = (child.isSuiteModule == true)
                local isSuiteDis = isSuiteMod and IsSuiteModuleExplicitlyDisabled(cName)
                if isCoreMod or ((fnIsLocked and fnIsLocked(cName)) or false) then
                    govLockedCount = govLockedCount + 1
                elseif isSuiteDis or (fnIsFrozen and fnIsFrozen(cName) or false) then
                    govFrozenCount = govFrozenCount + 1
                end
            end
        end
    end
    return total, activeCount, lockedCount, frozenCount, govTotal, govLockedCount, govFrozenCount
end

function UI.EvaluateAddonItemEffectiveState(item, desired)
    if not item then
        return false, false, false, false, false, false, 0, 0, 0, 0, 0, 0, 0
    end
    local name = ResolveCanonKey(item.name)
    local isParent = item.isParent == true
    local isSuiteHub = item.isDynamicSuiteHub == true
    local isSuiteMod = item.isSuiteModule == true
    local isCoreProtected = (isSuiteHub or name == "DynamicLoad")
    local secState = isCoreProtected and "LOCKED" or ((addonTable and addonTable.GetAddonSecurityState and addonTable.GetAddonSecurityState(name)) or "NORMAL")
    local isLocked = (secState == "LOCKED")
    local isFrozen = (secState == "FROZEN")

    local totalChildren, activeChildren, lockedChildren, frozenChildren, govTotal, govLockedCount, govFrozenCount = 0, 0, 0, 0, 0, 0, 0
    local isAutoCore = false
    local isAutoEnabled = false
    local isEffectiveFrozen = isFrozen
    local isEffectiveLocked = (not isFrozen) and isLocked

    if isSuiteHub then
        totalChildren = 0
        activeChildren = 0
        frozenChildren = 0
        local suiteList = (type(SUITE_MODULES) == "table" and SUITE_MODULES)
            or (addonTable and type(addonTable.SUITE_MODULES) == "table" and addonTable.SUITE_MODULES)
            or {}
        for _, mName in ipairs(suiteList) do
            if mName ~= "DynamicSuite" then
                totalChildren = totalChildren + 1
                if not IsSuiteModuleExplicitlyDisabled(mName) then
                    activeChildren = activeChildren + 1
                else
                    frozenChildren = frozenChildren + 1
                end
            end
        end
        lockedChildren = activeChildren
        govTotal = totalChildren
        govLockedCount = lockedChildren
        govFrozenCount = frozenChildren
        isEffectiveFrozen = false
        isEffectiveLocked = true
    elseif name == "DynamicLoad" then
        isEffectiveFrozen = false
        isEffectiveLocked = true
        isLocked = true
        isFrozen = false
    elseif isParent then
        totalChildren, activeChildren, lockedChildren, frozenChildren, govTotal, govLockedCount, govFrozenCount = GetParentSuiteStats(item, desired)
        if lockedChildren > 0 then
            isEffectiveFrozen = false
            isEffectiveLocked = true
            isAutoCore = (not isLocked) and (lockedChildren < totalChildren)
        elseif activeChildren > 0 then
            isEffectiveFrozen = false
            isAutoEnabled = true
        elseif totalChildren > 0 and frozenChildren == totalChildren then
            isEffectiveFrozen = true
            isEffectiveLocked = false
        end
    elseif isSuiteMod then
        local isModDis = IsSuiteModuleExplicitlyDisabled(name)
        if isModDis then
            isEffectiveFrozen = true
            isEffectiveLocked = false
            isFrozen = true
            isLocked = false
        end
    end

    return isEffectiveLocked, isEffectiveFrozen, isAutoCore, isAutoEnabled, isLocked, isFrozen, totalChildren, activeChildren, lockedChildren, frozenChildren, govTotal, govLockedCount, govFrozenCount
end

local function CascadeParentSecurity(parentItem, newSecurityState)
    local parentName = ResolveCanonKey(parentItem.name)

    if newSecurityState == "LOCKED" then
        addonTable.SetAddonLocked(parentName, true)
        if type(parentItem.children) == "table" then
            for _, child in ipairs(parentItem.children or {}) do
                local cName = ResolveCanonKey(child.name)
                if not IsIndividuallyPinnedChild(cName) then
                    local wasAlreadyLocked = addonTable.IsAddonLocked(cName)
                    addonTable.SetAddonLocked(cName, true)
                    if not wasAlreadyLocked then
                        SetParentCascaded(cName, "LOCKED")
                    end
                end
            end
        end
    elseif newSecurityState == "FROZEN" then
        local anyPinnedLocked = false
        if type(parentItem.children) == "table" then
            for _, child in ipairs(parentItem.children or {}) do
                local cName = ResolveCanonKey(child.name)
                if not IsIndividuallyPinnedChild(cName) then
                    local wasAlreadyFrozen = addonTable.IsAddonFrozen(cName)
                    addonTable.SetAddonFrozen(cName, true)
                    if not wasAlreadyFrozen then
                        SetParentCascaded(cName, "FROZEN")
                    end
                elseif addonTable.IsAddonLocked(cName) then
                    anyPinnedLocked = true
                end
            end
        end
        if anyPinnedLocked then
            addonTable.SetAddonLocked(parentName, false)
            addonTable.SetAddonFrozen(parentName, false)
        else
            addonTable.SetAddonFrozen(parentName, true)
        end
    else
        addonTable.SetAddonLocked(parentName, false)
        addonTable.SetAddonFrozen(parentName, false)
        if type(parentItem.children) == "table" then
            for _, child in ipairs(parentItem.children or {}) do
                local cName = ResolveCanonKey(child.name)
                if not IsIndividuallyPinnedChild(cName) then
                    addonTable.SetAddonLocked(cName, false)
                    addonTable.SetAddonFrozen(cName, false)
                    SetParentCascaded(cName, nil)
                end
            end
        end
    end
    addonTable.StageAddonProfile(selectedTabKey)
end

--------------------------------------------------------------------------------
-- Right-Click Context Menu (ASSIGN TO ZONES + 3-State Security Pills)
--------------------------------------------------------------------------------
local function CloseAltDropdown()
    if altDropdownFrame then altDropdownFrame:Hide() end
end

local function CloseContextMenu()
    if contextMenuFrame then contextMenuFrame:Hide() end
    if altDropdownFrame then altDropdownFrame:Hide() end
    if addonTable.mainFrame and addonTable.mainFrame.zoneTabMenu then
        addonTable.mainFrame.zoneTabMenu:Hide()
    end
    if clickCatcher and (not UI.IsDropdownPopupShown or not UI.IsDropdownPopupShown()) then
        clickCatcher:Hide()
    end
end

local function GetClickCatcher()
    if not clickCatcher then
        clickCatcher = CreateFrame("Button", "DynamicLoadClickCatcher", UIParent)
        clickCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
        clickCatcher:SetFrameLevel(100)
        clickCatcher:SetAllPoints(UIParent)
        clickCatcher:EnableMouse(true)
        clickCatcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        clickCatcher:SetScript("OnClick", function()
            if UI.CloseAllPopups then
                UI.CloseAllPopups()
            else
                CloseContextMenu()
            end
        end)
        clickCatcher:Hide()
    end
    return clickCatcher
end

local function OpenContextMenu(anchorFrame, item)
    if not item or item.isDynamicSuiteHub or item.isSuiteModule then return end
    UI.RefreshPaletteCache()
    if not contextMenuFrame then
        local menu = CreateFrame("Frame", "DynamicLoadContextMenu", UIParent)
        menu:SetSize(264, 215)
        menu:SetFrameStrata("TOOLTIP")
        menu:SetClampedToScreen(true)

        menu.bg = UI.SolidTex(menu, "BACKGROUND", 0, UI.COLORS.PANEL_BG.r, UI.COLORS.PANEL_BG.g, UI.COLORS.PANEL_BG.b, 0.98)
        menu.bg:SetAllPoints()
        UI.CreatePixelBorder(menu, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.9, 3)

        local title = menu:CreateFontString(nil, "OVERLAY")
        title:SetPoint("TOPLEFT", menu, "TOPLEFT", 12, -10)
        title:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -26, -10)
        title:SetJustifyH("LEFT")
        title:SetWordWrap(false)
        UI.SetFont(title, 11, "", UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 1)
        menu.title = title

        local closeBtn = CreateFrame("Button", nil, menu)
        closeBtn:SetSize(16, 16)
        closeBtn:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -6, -8)
        local closeText = closeBtn:CreateFontString(nil, "OVERLAY")
        closeText:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
        UI.SetFont(closeText, 11, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 1)
        closeText:SetText("X")
        closeBtn:SetScript("OnClick", CloseContextMenu)

        local divider = UI.SolidTex(menu, "OVERLAY", 1, 1, 1, 1, UI.COLORS.BORDER.a)
        divider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        divider:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -12, -26)
        divider:SetHeight(1)

        local secHeader = menu:CreateFontString(nil, "OVERLAY")
        secHeader:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -6)
        UI.SetFont(secHeader, 9, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 1)
        secHeader:SetText("LOAD MODE:")

        menu.btnNormal = CreateFlatButton(menu, 74, 20, "By Zone", false)
        menu.btnNormal:SetPoint("TOPLEFT", secHeader, "BOTTOMLEFT", 0, -4)

        menu.btnLock = CreateFlatButton(menu, 78, 20, "Always", false)
        menu.btnLock:SetPoint("LEFT", menu.btnNormal, "RIGHT", 6, 0)

        menu.btnFreeze = CreateFlatButton(menu, 76, 20, "Never", false)
        menu.btnFreeze:SetPoint("LEFT", menu.btnLock, "RIGHT", 6, 0)

        local function HookMenuHover(btn)
            btn:SetScript("OnEnter", function(self)
                self.isHovered = true
                if menu.RefreshMenuState then menu.RefreshMenuState() end
            end)
            btn:SetScript("OnLeave", function(self)
                self.isHovered = false
                if menu.RefreshMenuState then menu.RefreshMenuState() end
            end)
        end

        HookMenuHover(menu.btnNormal)
        HookMenuHover(menu.btnLock)
        HookMenuHover(menu.btnFreeze)

        menu.parentBatchFrame = CreateFrame("Frame", nil, menu)
        menu.parentBatchFrame:SetSize(240, 22)
        menu.parentBatchFrame:SetPoint("TOPLEFT", menu.btnNormal, "BOTTOMLEFT", 0, -6)

        menu.btnEnableAll = CreateFlatButton(menu.parentBatchFrame, 116, 20, "Enable All", false)
        menu.btnEnableAll:SetPoint("LEFT", menu.parentBatchFrame, "LEFT", 0, 0)

        menu.btnDisableAll = CreateFlatButton(menu.parentBatchFrame, 116, 20, "Disable All", false)
        menu.btnDisableAll:SetPoint("RIGHT", menu.parentBatchFrame, "RIGHT", 0, 0)

        local profHeader = menu:CreateFontString(nil, "OVERLAY")
        profHeader:SetPoint("TOPLEFT", menu.parentBatchFrame, "BOTTOMLEFT", 0, -6)
        UI.SetFont(profHeader, 9, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 1)
        profHeader:SetText("ASSIGN TO ZONES:")
        menu.profHeader = profHeader

        menu.zoneChips = {}
        local tabConfigs = {
            { key = "outdoor", label = "Outdoor",  w = 76 },
            { key = "delve",   label = "Delves",   w = 76 },
            { key = "dungeon", label = "Dungeons", w = 76 },
            { key = "raid",    label = "Raid",     w = 116 },
            { key = "pvp",     label = "PvP",      w = 116 },
        }

        for _, cfg in ipairs(tabConfigs) do
            local chip = CreateFlatButton(menu, cfg.w, 20, cfg.label, false)
            chip.tabKey = cfg.key
            HookMenuHover(chip)
            table.insert(menu.zoneChips, chip)
        end

        menu.zoneChips[1]:SetPoint("TOPLEFT", profHeader, "BOTTOMLEFT", 0, -4)
        menu.zoneChips[2]:SetPoint("LEFT", menu.zoneChips[1], "RIGHT", 6, 0)
        menu.zoneChips[3]:SetPoint("LEFT", menu.zoneChips[2], "RIGHT", 6, 0)
        menu.zoneChips[4]:SetPoint("TOPLEFT", menu.zoneChips[1], "BOTTOMLEFT", 0, -4)
        menu.zoneChips[5]:SetPoint("LEFT", menu.zoneChips[4], "RIGHT", 8, 0)

        tinsert(UISpecialFrames, "DynamicLoadContextMenu")
        contextMenuFrame = menu
    end

    local menu = contextMenuFrame
    local name = ResolveCanonKey(item.name)
    local isParent = item.isParent

    menu.title:SetText(item.title or name)
    menu.dsBorder:SetColor(UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.9)

    if isParent then
        menu.parentBatchFrame:Show()
        menu.profHeader:ClearAllPoints()
        menu.profHeader:SetPoint("TOPLEFT", menu.parentBatchFrame, "BOTTOMLEFT", 0, -6)
        menu:SetHeight(215)
    else
        menu.parentBatchFrame:Hide()
        menu.profHeader:ClearAllPoints()
        menu.profHeader:SetPoint("TOPLEFT", menu.btnNormal, "BOTTOMLEFT", 0, -6)
        menu:SetHeight(185)
    end

    local function RefreshMenuState()
        local secState = addonTable.GetAddonSecurityState(name)
        local isLocked = (secState == "LOCKED")
        local isFrozen = (secState == "FROZEN")
        local isNormal = (secState == "NORMAL")

        local function UpdateSecBtn(btn, isSel, col)
            local isHov = btn.isHovered
            if isSel then
                btn.bg:SetColorTexture(col.r, col.g, col.b, isHov and 0.55 or 0.35)
                btn.dsBorder:SetColor(col.r, col.g, col.b, isHov and 1.0 or 0.85)
                btn.label:SetTextColor(col.r, col.g, col.b, 1)
            else
                btn.bg:SetColorTexture(isHov and UI.COLORS.BTN_HOVER.r or 0.12,
                                       isHov and UI.COLORS.BTN_HOVER.g or 0.14,
                                       isHov and UI.COLORS.BTN_HOVER.b or 0.18,
                                       isHov and 0.95 or 1.0)
                btn.dsBorder:SetColor(UI.COLORS.BTN_BORDER.r, UI.COLORS.BTN_BORDER.g, UI.COLORS.BTN_BORDER.b, isHov and 0.8 or 0.4)
                btn.label:SetTextColor(isHov and 1 or 0.72, isHov and 1 or 0.75, isHov and 1 or 0.80, 1)
            end
        end

        UpdateSecBtn(menu.btnNormal, isNormal, UI.COLORS.ACCENT)
        UpdateSecBtn(menu.btnLock, isLocked, UI.COLORS.GOLD)
        UpdateSecBtn(menu.btnFreeze, isFrozen, UI.COLORS.CYAN)

        for _, chip in ipairs(menu.zoneChips) do
            local key = chip.tabKey
            local prof = DynamicLoadDB and DynamicLoadDB.profiles and DynamicLoadDB.profiles[key]
            local isAssigned = isLocked or (prof and prof.addons and prof.addons[name] == true)
            local isHov = chip.isHovered

            if isFrozen then
                chip.bg:SetColorTexture(0.08, 0.09, 0.12, 0.6)
                chip.dsBorder:SetColor(UI.COLORS.CYAN.r, UI.COLORS.CYAN.g, UI.COLORS.CYAN.b, isHov and 0.5 or 0.2)
                chip.label:SetTextColor(0.45, 0.48, 0.52, 1)
            elseif isLocked then
                chip.bg:SetColorTexture(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, isHov and 0.50 or 0.35)
                chip.dsBorder:SetColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, isHov and 1.0 or 0.80)
                chip.label:SetTextColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1)
            elseif isAssigned then
                chip.bg:SetColorTexture(UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, isHov and 0.50 or 0.32)
                chip.dsBorder:SetColor(UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, isHov and 1.0 or 0.80)
                chip.label:SetTextColor(UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 1)
            else
                chip.bg:SetColorTexture(isHov and UI.COLORS.BTN_HOVER.r or 0.12,
                                        isHov and UI.COLORS.BTN_HOVER.g or 0.14,
                                        isHov and UI.COLORS.BTN_HOVER.b or 0.18,
                                        isHov and 0.95 or 1.0)
                chip.dsBorder:SetColor(UI.COLORS.BTN_BORDER.r, UI.COLORS.BTN_BORDER.g, UI.COLORS.BTN_BORDER.b, isHov and 0.8 or 0.4)
                chip.label:SetTextColor(isHov and 1 or UI.COLORS.TEXT_DIM.r,
                                        isHov and 1 or UI.COLORS.TEXT_DIM.g,
                                        isHov and 1 or UI.COLORS.TEXT_DIM.b, 1)
            end
        end
    end
    menu.RefreshMenuState = RefreshMenuState

    menu.btnNormal:SetScript("OnClick", function()
        if not isParent and addonTable.GetAddonSecurityState(name) == "NORMAL" then return end
        if isParent then
            CascadeParentSecurity(item, "NORMAL")
        else
            SetParentCascaded(name, nil)
            addonTable.SetAddonLocked(name, false)
            addonTable.SetAddonFrozen(name, false)
            if item.parent and addonTable.IsAddonFrozen(item.parent) then
                addonTable.SetAddonFrozen(item.parent, false)
            end
        end
        addonTable.StageAddonProfile(selectedTabKey)
        RefreshMenuState()
        if addonTable.mainFrame and addonTable.mainFrame.scrollChild then addonTable.mainFrame.scrollChild:Refresh() end
        if addonTable.mainFrame and addonTable.mainFrame.UpdateStatusBar then addonTable.mainFrame.UpdateStatusBar() end
    end)

    menu.btnLock:SetScript("OnClick", function()
        if not isParent and addonTable.GetAddonSecurityState(name) == "LOCKED" then return end
        if isParent then
            CascadeParentSecurity(item, "LOCKED")
        else
            SetParentCascaded(name, nil)
            addonTable.SetAddonLocked(name, true)
            if item.parent and addonTable.IsAddonFrozen(item.parent) then
                addonTable.SetAddonFrozen(item.parent, false)
            end
        end
        addonTable.StageAddonProfile(selectedTabKey)
        RefreshMenuState()
        if addonTable.mainFrame and addonTable.mainFrame.scrollChild then addonTable.mainFrame.scrollChild:Refresh() end
        if addonTable.mainFrame and addonTable.mainFrame.UpdateStatusBar then addonTable.mainFrame.UpdateStatusBar() end
    end)

    menu.btnFreeze:SetScript("OnClick", function()
        if not isParent and addonTable.GetAddonSecurityState(name) == "FROZEN" then return end
        if isParent then
            CascadeParentSecurity(item, "FROZEN")
        else
            SetParentCascaded(name, nil)
            addonTable.SetAddonFrozen(name, true)
        end
        addonTable.StageAddonProfile(selectedTabKey)
        RefreshMenuState()
        if addonTable.mainFrame and addonTable.mainFrame.scrollChild then addonTable.mainFrame.scrollChild:Refresh() end
        if addonTable.mainFrame and addonTable.mainFrame.UpdateStatusBar then addonTable.mainFrame.UpdateStatusBar() end
    end)

    if isParent then
        menu.btnEnableAll:SetScript("OnClick", function()
            local profile = DynamicLoadDB and DynamicLoadDB.profiles and DynamicLoadDB.profiles[selectedTabKey]
            if not addonTable.IsAddonFrozen(name) then
                if profile and profile.addons then
                    profile.addons[name] = true
                end
            end
            if profile and profile.addons and type(item.children) == "table" then
                for _, c in ipairs(item.children or {}) do
                    local cName = ResolveCanonKey(c.name)
                    if not addonTable.IsAddonFrozen(cName) and not addonTable.IsAddonLocked(cName) then
                        profile.addons[cName] = true
                    elseif addonTable.IsAddonFrozen(cName) then
                        profile.addons[cName] = nil
                    end
                end
            end
            addonTable.StageAddonProfile(selectedTabKey)
            RefreshMenuState()
            if addonTable.mainFrame and addonTable.mainFrame.scrollChild then addonTable.mainFrame.scrollChild:Refresh() end
            if addonTable.mainFrame and addonTable.mainFrame.UpdateStatusBar then addonTable.mainFrame.UpdateStatusBar() end
        end)

        menu.btnDisableAll:SetScript("OnClick", function()
            local profile = DynamicLoadDB and DynamicLoadDB.profiles and DynamicLoadDB.profiles[selectedTabKey]
            if not addonTable.IsAddonLocked(name) then
                if profile and profile.addons then
                    profile.addons[name] = false
                end
            end
            if profile and profile.addons and type(item.children) == "table" then
                for _, c in ipairs(item.children or {}) do
                    local cName = ResolveCanonKey(c.name)
                    if not addonTable.IsAddonFrozen(cName) and not addonTable.IsAddonLocked(cName) then
                        profile.addons[cName] = false
                    elseif addonTable.IsAddonFrozen(cName) then
                        profile.addons[cName] = nil
                    end
                end
            end
            addonTable.StageAddonProfile(selectedTabKey)
            RefreshMenuState()
            if addonTable.mainFrame and addonTable.mainFrame.scrollChild then addonTable.mainFrame.scrollChild:Refresh() end
            if addonTable.mainFrame and addonTable.mainFrame.UpdateStatusBar then addonTable.mainFrame.UpdateStatusBar() end
        end)
    end

    for _, chip in ipairs(menu.zoneChips) do
        chip:SetScript("OnClick", function()
            local secState = addonTable.GetAddonSecurityState(name)
            if secState ~= "NORMAL" then return end
            local key = chip.tabKey
            local prof = DynamicLoadDB and DynamicLoadDB.profiles and DynamicLoadDB.profiles[key]
            if prof then
                if not prof.addons then prof.addons = {} end
                local newVal = not (prof.addons[name] == true)
                prof.addons[name] = newVal
                if isParent and type(item.children) == "table" then
                    for _, c in ipairs(item.children or {}) do
                        local cName = ResolveCanonKey(c.name)
                        if not addonTable.IsAddonFrozen(cName) and not addonTable.IsAddonLocked(cName) then
                            prof.addons[cName] = newVal
                        elseif addonTable.IsAddonFrozen(cName) then
                            prof.addons[cName] = nil
                        end
                    end
                elseif not isParent and newVal and item.parent then
                    local pNameKey = ResolveCanonKey(item.parent)
                    prof.addons[pNameKey] = true
                    if addonTable.IsAddonFrozen(pNameKey) then
                        addonTable.SetAddonFrozen(pNameKey, false)
                    end
                end
                if key == selectedTabKey then
                    addonTable.StageAddonProfile(selectedTabKey)
                end
                RefreshMenuState()
                if addonTable.mainFrame and addonTable.mainFrame.scrollChild then addonTable.mainFrame.scrollChild:Refresh() end
                if addonTable.mainFrame and addonTable.mainFrame.UpdateStatusBar then addonTable.mainFrame.UpdateStatusBar() end
            end
        end)
    end

    RefreshMenuState()
    GetClickCatcher():Show()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 10, -2)
    menu:Show()
end

--------------------------------------------------------------------------------
-- Addon Row Frame Pool (Two-Point C++ Anchors: TOPLEFT + TOPRIGHT)
--------------------------------------------------------------------------------
local function GetPlayerSafe()
    return (addonTable.GetPlayer and addonTable.GetPlayer())
        or (type(_G.UnitName) == "function" and _G.UnitName("player"))
        or "Character"
end

local disableCoreAddonModal = nil
local function ShowDisableCoreAddonModal(targetAddonName)
    local addonToDisable = (targetAddonName == "DynamicLoad") and "DynamicLoad" or "DynamicSuite"
    if type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() then
        print(string.format("%s: Cannot disable %s during combat. Please leave combat and try again.", tostring(ADDON_TITLE or "|cFFCBD5E1DynamicLoad|r"), addonToDisable))
        return
    end
    if not disableCoreAddonModal then
        local m = CreateFrame("Frame", "DynamicLoadDisableCoreConfirmModal", UIParent)
        m:SetSize(450, 152)
        m:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        m:SetFrameStrata("FULLSCREEN_DIALOG")
        m:SetFrameLevel(320)
        m:EnableMouse(true)
        m:Hide()
        m.bg = UI.SolidTex(m, "BACKGROUND", 0, 0.043, 0.051, 0.071, 0.98)
        m.bg:SetAllPoints()
        local initAr, initAg, initAb = UI.GetActiveAccentColor()
        UI.CreatePixelBorder(m, initAr, initAg, initAb, 0.85, 4)

        if type(_G.UISpecialFrames) == "table" then
            local found = false
            for _, fn in ipairs(_G.UISpecialFrames) do
                if fn == "DynamicLoadDisableCoreConfirmModal" then found = true break end
            end
            if not found then table.insert(_G.UISpecialFrames, "DynamicLoadDisableCoreConfirmModal") end
        end

        local titleFS = m:CreateFontString(nil, "OVERLAY")
        titleFS:SetPoint("TOPLEFT", m, "TOPLEFT", 18, -16)
        UI.SetFont(titleFS, 13, "", 0.980, 0.800, 0.082, 1)
        m.titleFS = titleFS

        local descFS = m:CreateFontString(nil, "OVERLAY")
        descFS:SetPoint("TOPLEFT", m, "TOPLEFT", 18, -42)
        descFS:SetPoint("TOPRIGHT", m, "TOPRIGHT", -18, -42)
        descFS:SetJustifyH("LEFT")
        descFS:SetWordWrap(true)
        UI.SetFont(descFS, 10.5, "", 0.886, 0.910, 0.941, 0.96)
        m.descFS = descFS

        local btnCancel = CreateFlatButton(m, 88, 26, "Cancel", false)
        btnCancel:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -16, 14)
        btnCancel:SetScript("OnClick", function() m:Hide() end)
        m.btnCancel = btnCancel

        local btnConfirm = CreateFlatButton(m, 156, 26, "Disable & Reload UI", true)
        btnConfirm:SetPoint("RIGHT", btnCancel, "LEFT", -8, 0)
        btnConfirm:SetSelected(true)
        m.btnConfirm = btnConfirm

        local function RefreshModalTheme()
            UI.RefreshPaletteCache()
            local ar, ag, ab = UI.GetActiveAccentColor()
            if m.dsBorder and m.dsBorder.SetColor then
                m.dsBorder:SetColor(ar, ag, ab, 0.85)
            end
            if m.btnConfirm then
                m.btnConfirm.selectedColor = nil
                m.btnConfirm:SetSelected(true)
            end
            if m.btnCancel then
                m.btnCancel:SetSelected(false)
            end
        end
        m.RefreshTheme = RefreshModalTheme
        m:HookScript("OnShow", RefreshModalTheme)
        addonTable.RefreshDisableCoreModalTheme = RefreshModalTheme
        btnConfirm:SetScript("OnClick", function()
            local target = m._targetAddon or "DynamicSuite"
            if type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() then
                print(string.format("%s: Cannot disable %s during combat. Please leave combat and try again.", tostring(ADDON_TITLE or "|cFFCBD5E1DynamicLoad|r"), target))
                m:Hide()
                return
            end
            m:Hide()
            -- Bypass Suite Core self-protection for this explicit user-confirmed disable + reload,
            -- and mark target as FROZEN ("Never") across all DynamicLoadDB scopes/profiles so
            -- CommitPendingProfileBeforeReload / StageAddonProfile does not re-enable it.
            -- On next load (if re-enabled via Blizzard's AddOns menu), SyncScopeBindings()
            -- purges this state and restores it cleanly to [Always].
            addonTable._pendingDisableCoreAddon = target
            if DynamicLoadDB and addonTable.ApplySecurityStateToTableSet then
                addonTable.ApplySecurityStateToTableSet(DynamicLoadDB, target, target, "FROZEN")
                if DynamicLoadDB.globalData then
                    addonTable.ApplySecurityStateToTableSet(DynamicLoadDB.globalData, target, target, "FROZEN")
                end
                if type(DynamicLoadDB.charData) == "table" then
                    for _, cd in pairs(DynamicLoadDB.charData) do
                        addonTable.ApplySecurityStateToTableSet(cd, target, target, "FROZEN")
                    end
                end
            end
            if C_AddOns and C_AddOns.DisableAddOn then
                local pName = GetPlayerSafe()
                pcall(C_AddOns.DisableAddOn, target, pName)
                pcall(C_AddOns.DisableAddOn, target)
            end
            if type(_G.ReloadUI) == "function" then
                _G.ReloadUI()
            end
        end)

        disableCoreAddonModal = m
    end

    disableCoreAddonModal._targetAddon = addonToDisable
    disableCoreAddonModal.titleFS:SetText(string.format("Disable %s?", addonToDisable))
    if addonToDisable == "DynamicSuite" then
        disableCoreAddonModal.descFS:SetText("Disable DynamicSuite and reload UI? Individual modules can be toggled in the left rail, or you can re-enable DynamicSuite anytime via the Blizzard AddOns menu.")
    else
        disableCoreAddonModal.descFS:SetText("Disable DynamicLoad and reload UI? You can re-enable DynamicLoad anytime via the Blizzard AddOns menu.")
    end
    if disableCoreAddonModal.RefreshTheme then
        disableCoreAddonModal.RefreshTheme()
    end
    disableCoreAddonModal:Show()
end

local rowPool = {}
local isRefreshing = false

local function AcquireAddonRow(scrollChild, index)
    if rowPool[index] then
        rowPool[index]:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        return rowPool[index]
    end

    local row = CreateFrame("Button", nil, scrollChild)
    row:SetHeight(24)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.bg = UI.SolidTex(row, "BACKGROUND", 0, 1, 1, 1, 1)
    row.bg:SetAllPoints()

    row.divider = UI.SolidTex(row, "OVERLAY", 1, 1, 1, 1, 0.04)
    row.divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.divider:SetHeight(1)

    local leftAccent = UI.SolidTex(row, "OVERLAY", 2, 1, 1, 1, 1)
    leftAccent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    leftAccent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    leftAccent:SetWidth(2)
    leftAccent:Hide()
    row.leftAccent = leftAccent

    local colBtn = CreateFrame("Button", nil, row)
    colBtn:SetSize(16, 16)
    local colIcon = colBtn:CreateTexture(nil, "ARTWORK", nil, 3)
    colIcon:SetSize(10, 10)
    colIcon:SetPoint("CENTER", colBtn, "CENTER", 0, 0)
    colIcon:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga")
    colIcon:SetVertexColor(0.72, 0.76, 0.84, 0.95)
    row.colBtn = colBtn
    row.colIcon = colIcon

    local cb = UI.CreateSquareCheckbox(row, 14)
    row.cb = cb

    local lockBtn = CreateFrame("Button", nil, row)
    lockBtn:SetSize(16, 16)
    lockBtn:Hide()
    row.lockBtn = lockBtn
    row.lockTex = lockBtn:CreateTexture(nil, "ARTWORK")

    local modIconTex = row:CreateTexture(nil, "ARTWORK", nil, 3)
    modIconTex:SetSize(14, 14)
    modIconTex:Hide()
    row.modIconTex = modIconTex

    local cpuBtn = CreateFrame("Button", nil, row)
    cpuBtn:SetSize(64, 20)
    local cpuText = cpuBtn:CreateFontString(nil, "OVERLAY")
    cpuText:SetPoint("RIGHT", cpuBtn, "RIGHT", 0, 0)
    row.cpuBtn = cpuBtn
    row.cpuText = cpuText

    -- 3-Button Inline Load Mode Pill Group (162x18px)
    local modeGroup = CreateFrame("Frame", nil, row)
    modeGroup:SetSize(162, 18)
    modeGroup:SetPoint("RIGHT", cpuBtn, "LEFT", -10, 0)
    row.modeGroup = modeGroup

    local btnZone = CreateFlatButton(modeGroup, 52, 18, "By Zone", false)
    btnZone:SetPoint("LEFT", modeGroup, "LEFT", 0, 0)
    btnZone.label:SetText("By Zone")
    UI.SetFont(btnZone.label, 9, "", 0.8, 0.8, 0.8, 1)

    local btnAlways = CreateFlatButton(modeGroup, 56, 18, "Always", false)
    btnAlways:SetPoint("LEFT", btnZone, "RIGHT", 2, 0)
    btnAlways.label:SetText("Always")
    UI.SetFont(btnAlways.label, 9, "", 0.8, 0.8, 0.8, 1)

    local btnNever = CreateFlatButton(modeGroup, 50, 18, "Never", false)
    btnNever:SetPoint("LEFT", btnAlways, "RIGHT", 2, 0)
    btnNever.label:SetText("Never")
    UI.SetFont(btnNever.label, 9, "", 0.8, 0.8, 0.8, 1)

    row.btnZone = btnZone
    row.btnAlways = btnAlways
    row.btnNever = btnNever

    local suiteTag = row:CreateFontString(nil, "OVERLAY")
    suiteTag:SetPoint("RIGHT", cpuBtn, "LEFT", -10, 0)
    UI.SetFont(suiteTag, 9.5, "", UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1)
    suiteTag:SetText("[Suite Protected]")
    suiteTag:Hide()
    row.suiteTag = suiteTag

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    row.label = label

    rowPool[index] = row
    return row
end

local function RenderAddonRow(scrollChild, item, desired, profile, indent, yOffset, rowIndex, pendingChanges)
    local row = AcquireAddonRow(scrollChild, rowIndex)
    row:ClearAllPoints()
    -- Two-Point C++ Anchor Stretching: zero Lua OnUpdate needed when resizing window!
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
    row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -yOffset)
    row:SetHeight(24)
    row:Show()

    local name = ResolveCanonKey(item.name)
    local title = item.title
    local isParent = item.isParent
    local isSuiteHub = item.isDynamicSuiteHub == true
    local isSuiteMod = item.isSuiteModule == true
    local isTwoStateCoreRow = (isSuiteHub or name == "DynamicLoad")
    local isEffectiveLocked, isEffectiveFrozen, isAutoCore, isAutoEnabled, isLocked, isFrozen, totalChildren, activeChildren, lockedChildren, frozenChildren, govTotal, govLockedCount, govFrozenCount = UI.EvaluateAddonItemEffectiveState(item, desired)

    local function ToggleDirectLock()
        if isSuiteHub or isSuiteMod then return end
        if isParent then
            local allGovLocked = isLocked or (govTotal > 0 and govLockedCount == govTotal) or (govTotal == 0 and lockedChildren > 0)
            if allGovLocked then
                CascadeParentSecurity(item, "NORMAL")
            else
                CascadeParentSecurity(item, "LOCKED")
            end
        else
            SetParentCascaded(name, nil)
            if isLocked then
                addonTable.SetAddonLocked(name, false)
                addonTable.SetAddonFrozen(name, false)
            else
                addonTable.SetAddonLocked(name, true)
                if item.parent and addonTable.IsAddonFrozen(item.parent) then
                    addonTable.SetAddonFrozen(item.parent, false)
                end
            end
            addonTable.StageAddonProfile(selectedTabKey)
        end
        if scrollChild.Refresh then scrollChild:Refresh() end
        if addonTable.mainFrame and addonTable.mainFrame.UpdateStatusBar then addonTable.mainFrame.UpdateStatusBar() end
    end

    local function ToggleDirectFreeze()
        if isSuiteHub or isSuiteMod then return end
        if isParent then
            local allGovFrozen = isFrozen or isEffectiveFrozen or (govTotal > 0 and govFrozenCount == govTotal) or (govTotal == 0 and frozenChildren > 0)
            if allGovFrozen then
                CascadeParentSecurity(item, "NORMAL")
            else
                CascadeParentSecurity(item, "FROZEN")
            end
        else
            SetParentCascaded(name, nil)
            if isFrozen then
                addonTable.SetAddonLocked(name, false)
                addonTable.SetAddonFrozen(name, false)
                if item.parent and addonTable.IsAddonFrozen(item.parent) then
                    addonTable.SetAddonFrozen(item.parent, false)
                end
            else
                addonTable.SetAddonFrozen(name, true)
            end
            addonTable.StageAddonProfile(selectedTabKey)
        end
        if scrollChild.Refresh then scrollChild:Refresh() end
        if addonTable.mainFrame and addonTable.mainFrame.UpdateStatusBar then addonTable.mainFrame.UpdateStatusBar() end
    end

    local rowCol = (rowIndex % 2 == 1) and UI.COLORS.ROW_ODD or UI.COLORS.ROW_EVEN
    row.bg:SetColorTexture(rowCol.r, rowCol.g, rowCol.b, rowCol.a)

    local rawDisplayName = title or name
    local cleanDisplayName = StripFormatting(rawDisplayName)
    if cleanDisplayName == "" then cleanDisplayName = name end
    local displayName = cleanDisplayName

    local function ShowFullRowTooltip()
        if not row or not row:IsVisible() then return end
        row.bg:SetColorTexture(UI.COLORS.ROW_HOVER.r, UI.COLORS.ROW_HOVER.g, UI.COLORS.ROW_HOVER.b, UI.COLORS.ROW_HOVER.a)
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetText(tostring(displayName or name or "Addon"), 1, 1, 1)
        if name ~= displayName and not isSuiteHub then
            GameTooltip:AddLine("Folder: " .. tostring(name or ""), 0.58, 0.64, 0.72)
        end

        local ar, ag, ab = UI.GetActiveAccentColor()
        local accentHex = tostring(UI.GetActiveAccentHex() or "CBD5E1")
        if isTwoStateCoreRow then
            if isSuiteHub then
                GameTooltip:AddDoubleLine("Load Mode:", string.format("|cFF%s[Always] (Suite Core)|r", accentHex), 0.75, 0.78, 0.82, ar, ag, ab)
                GameTooltip:AddLine("DynamicSuite stays active across all 5 zone profiles.", 0.82, 0.85, 0.90)
                GameTooltip:AddLine("Individual DynamicSuite modules are toggled via the Left Rail switches.", 0.70, 0.76, 0.84, true)
                GameTooltip:AddLine("Use [Never] on the right to disable DynamicSuite and reload UI.", 0.70, 0.76, 0.84, true)
            else
                GameTooltip:AddDoubleLine("Load Mode:", "|cFFFACC15[Always] (Core)|r", 0.75, 0.78, 0.82, 0.980, 0.800, 0.082)
                GameTooltip:AddLine("DynamicLoad stays active across all 5 zone profiles so it cannot unload itself by zone.", 0.82, 0.85, 0.90, true)
                GameTooltip:AddLine("Use [Never] on the right to disable DynamicLoad and reload UI.", 0.70, 0.76, 0.84, true)
            end
        elseif isSuiteMod and IsSuiteModuleExplicitlyDisabled(name) then
            GameTooltip:AddDoubleLine("Load Mode:", "|cFF94A3B8[Suite Core] Disabled on Left Rail|r", 0.75, 0.78, 0.82, 0.58, 0.64, 0.72)
            GameTooltip:AddLine("This DynamicSuite module is currently toggled OFF.", 0.82, 0.85, 0.90)
            if name ~= "DynamicLoad" then
                GameTooltip:AddLine("|cFF" .. accentHex .. "Left-Click Row / Checkbox:|r |cFFE2E8F0Toggle Module On/Off (Synced with Left Rail)|r", 1, 1, 1)
            end
        elseif isEffectiveFrozen then
            GameTooltip:AddDoubleLine("Load Mode:", "|cFF38BDF8[Never]|r", 0.75, 0.78, 0.82, 0.220, 0.741, 0.973)
            GameTooltip:AddLine("Forced OFF across all 5 zone profiles.", 0.82, 0.85, 0.90)
            if isParent and item.children and #item.children > 0 then
                GameTooltip:AddLine("|cFF" .. accentHex .. "Left-Click [-]:|r |cFFE2E8F0Expand or Collapse Group|r  (|cFF" .. accentHex .. "Shift-Click:|r |cFFE2E8F0Collapse/Expand All|r)", 1, 1, 1)
            end
            GameTooltip:AddLine("|cFF34D399Right-Click Row:|r |cFFE2E8F0Reset to|r |cFF34D399[By Zone]|r   |cFF475569|||r   |cFFFACC15Left-Click Row:|r |cFFE2E8F0Set to|r |cFFFACC15[Always]|r", 1, 1, 1)
            GameTooltip:AddLine("|cFF" .. accentHex .. "Ctrl + Right-Click:|r |cFFE2E8F0Open Zone Assignment Menu|r", 1, 1, 1)
        elseif isParent and isAutoCore then
            GameTooltip:AddDoubleLine("Load Mode:", "|cFFFACC15[Always]|r", 0.75, 0.78, 0.82, 0.980, 0.800, 0.082)
            GameTooltip:AddLine(string.format("Forced ON across all 5 zone profiles (%d of %d child modules set to [Always]).", lockedChildren, totalChildren), 0.82, 0.85, 0.90)
            if item.children and #item.children > 0 then
                GameTooltip:AddLine("|cFF" .. accentHex .. "Left-Click [-]:|r |cFFE2E8F0Expand or Collapse Group|r  (|cFF" .. accentHex .. "Shift-Click:|r |cFFE2E8F0Collapse/Expand All|r)", 1, 1, 1)
            end
            GameTooltip:AddLine("|cFF34D399Left-Click Row:|r |cFFE2E8F0Reset to|r |cFF34D399[By Zone]|r   |cFF475569|||r   |cFF38BDF8Right-Click Row:|r |cFFE2E8F0Set to|r |cFF38BDF8[Never]|r", 1, 1, 1)
            GameTooltip:AddLine("|cFF" .. accentHex .. "Ctrl + Right-Click:|r |cFFE2E8F0Open Zone Assignment Menu|r", 1, 1, 1)
        elseif isEffectiveLocked then
            GameTooltip:AddDoubleLine("Load Mode:", "|cFFFACC15[Always]|r", 0.75, 0.78, 0.82, 0.980, 0.800, 0.082)
            GameTooltip:AddLine("Forced ON across all 5 zone profiles.", 0.82, 0.85, 0.90)
            if isParent and item.children and #item.children > 0 then
                GameTooltip:AddLine("|cFF" .. accentHex .. "Left-Click [-]:|r |cFFE2E8F0Expand or Collapse Group|r  (|cFF" .. accentHex .. "Shift-Click:|r |cFFE2E8F0Collapse/Expand All|r)", 1, 1, 1)
            end
            GameTooltip:AddLine("|cFF34D399Left-Click Row:|r |cFFE2E8F0Reset to|r |cFF34D399[By Zone]|r   |cFF475569|||r   |cFF38BDF8Right-Click Row:|r |cFFE2E8F0Set to|r |cFF38BDF8[Never]|r", 1, 1, 1)
            GameTooltip:AddLine("|cFF" .. accentHex .. "Ctrl + Right-Click:|r |cFFE2E8F0Open Zone Assignment Menu|r", 1, 1, 1)
        else
            local zoneLabel = (addonTable.CONTEXT_LABELS and addonTable.CONTEXT_LABELS[selectedTabKey]) or selectedTabKey
            local inZone = (desired[name] == true) or isAutoEnabled
            GameTooltip:AddDoubleLine("Load Mode:", "|cFF" .. accentHex .. "[By Zone]|r", 0.75, 0.78, 0.82, ar, ag, ab)
            GameTooltip:AddLine("Managed per zone profile (Outdoor, Delves, Dungeons, Raid, PvP).", 0.82, 0.85, 0.90)
            GameTooltip:AddDoubleLine(zoneLabel .. " Profile:", inZone and "|cFF22C55EEnabled|r" or "|cFF8892A0Disabled|r", 0.75, 0.78, 0.82, 1, 1, 1)
            if isParent and item.children and #item.children > 0 then
                GameTooltip:AddLine("|cFF" .. accentHex .. "Left-Click [-]:|r |cFFE2E8F0Expand or Collapse Group|r  (|cFF" .. accentHex .. "Shift-Click:|r |cFFE2E8F0Collapse/Expand All|r)", 1, 1, 1)
            end
            GameTooltip:AddLine("|cFFFACC15Left-Click Row:|r |cFFE2E8F0Set to|r |cFFFACC15[Always]|r   |cFF475569|||r   |cFF38BDF8Right-Click Row:|r |cFFE2E8F0Set to|r |cFF38BDF8[Never]|r", 1, 1, 1)
            GameTooltip:AddLine("|cFF" .. accentHex .. "Ctrl + Right-Click:|r |cFFE2E8F0Open Zone Assignment Menu|r", 1, 1, 1)
        end

        if not isSuiteHub and C_AddOns.GetAddOnInfo(name) and C_AddOnProfiler and C_AddOnProfiler.IsEnabled and C_AddOnProfiler.IsEnabled() then
            local recent = C_AddOnProfiler.GetAddOnMetric(name, Enum.AddOnProfilerMetric.RecentAverageTime) or 0
            local peak = C_AddOnProfiler.GetAddOnMetric(name, Enum.AddOnProfilerMetric.PeakTime) or 0
            local session = C_AddOnProfiler.GetAddOnMetric(name, Enum.AddOnProfilerMetric.SessionAverageTime) or 0
            local fps = GetFramerate() or 60
            if fps <= 0 then fps = 60 end
            local budget = 1000 / fps
            local curPct = (recent / budget) * 100
            local avgPct = (session / budget) * 100
            local enc = (Enum.AddOnProfilerMetric.EncounterAverageTime and C_AddOnProfiler.GetAddOnMetric(name, Enum.AddOnProfilerMetric.EncounterAverageTime)) or 0; local sanePeak = (peak > 100) and math.max(enc, recent * 1.5, session * 1.5) or peak; local peakPct = math.min(999.9, (sanePeak / budget) * 100)
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Current CPU:", string.format("%.2f%% (%.3f ms)", curPct, recent), 0.70, 0.74, 0.78, 0.95, 0.97, 1.0)
            GameTooltip:AddDoubleLine("Average / Peak CPU:", string.format("%.2f%% / %.2f%% (%.2f ms)", avgPct, peakPct, peak), 0.70, 0.74, 0.78, ar, ag, ab)
            if GetAddOnMemoryUsage and C_AddOns.IsAddOnLoaded(name) then
                local memKB = GetAddOnMemoryUsage(name) or 0
                if memKB > 0 then
                    local memStr = (memKB >= 1024) and string.format("%.2f MB", memKB / 1024) or string.format("%.0f KB", memKB)
                    GameTooltip:AddDoubleLine("Memory Usage:", memStr, 0.70, 0.74, 0.78, 0.82, 0.85, 0.90)
                end
            end
        end
        GameTooltip:Show()
    end

    local function HideFullRowTooltip()
        row.bg:SetColorTexture(rowCol.r, rowCol.g, rowCol.b, rowCol.a)
        GameTooltip:Hide()
    end

    row:SetScript("OnEnter", ShowFullRowTooltip)
    row:SetScript("OnLeave", HideFullRowTooltip)
    row.cb:SetScript("OnEnter", ShowFullRowTooltip)
    row.cb:SetScript("OnLeave", HideFullRowTooltip)
    row.colBtn:SetScript("OnEnter", ShowFullRowTooltip)
    row.colBtn:SetScript("OnLeave", HideFullRowTooltip)

    local function HandleParentCollapseClick()
        if IsShiftKeyDown() then
            ToggleAllParentsCollapsed()
        else
            SetParentCollapsed(name, not IsParentCollapsed(name))
        end
        if scrollChild.Refresh then scrollChild:Refresh() end
    end

    local function ToggleSuiteCoreModule()
        if not isSuiteMod or name == "DynamicLoad" then return end
        local targetEnable = not isEffectiveLocked
        if addonTable.SetSuiteModuleEnabled then
            addonTable.SetSuiteModuleEnabled(name, targetEnable)
        else
            local shortK = tostring(name):gsub("^Dynamic", ""):lower()
            _G.DynamicSuiteDB = _G.DynamicSuiteDB or {}
            _G.DynamicSuiteDB.disabledModules = _G.DynamicSuiteDB.disabledModules or {}
            _G.DynamicSuiteDB.global = _G.DynamicSuiteDB.global or {}
            _G.DynamicSuiteDB.global.disabledModules = _G.DynamicSuiteDB.global.disabledModules or {}
            if targetEnable then
                _G.DynamicSuiteDB.disabledModules[name] = nil
                _G.DynamicSuiteDB.disabledModules[shortK] = nil
                _G.DynamicSuiteDB.global.disabledModules[name] = nil
                _G.DynamicSuiteDB.global.disabledModules[shortK] = nil
            else
                _G.DynamicSuiteDB.disabledModules[name] = true
                _G.DynamicSuiteDB.disabledModules[shortK] = true
                _G.DynamicSuiteDB.global.disabledModules[name] = true
                _G.DynamicSuiteDB.global.disabledModules[shortK] = true
            end
            if scrollChild.Refresh then scrollChild:Refresh() end
            if addonTable.mainFrame and addonTable.mainFrame.RefreshLeftRailVisuals then addonTable.mainFrame.RefreshLeftRailVisuals() end
            if addonTable.mainFrame and addonTable.mainFrame.UpdateStatusBar then addonTable.mainFrame.UpdateStatusBar() end
        end
    end

    row:SetScript("OnClick", function(self, button)
        if isTwoStateCoreRow then
            return
        end
        if isSuiteMod then
            if button == "LeftButton" then
                ToggleSuiteCoreModule()
            end
            return
        end
        if button == "RightButton" then
            if IsControlKeyDown() then
                OpenContextMenu(self, item)
            else
                ToggleDirectFreeze()
            end
        elseif button == "LeftButton" then
            if isParent then
                HandleParentCollapseClick()
            else
                ToggleDirectLock()
            end
        end
    end)

    local xPos = indent

    local ar, ag, ab = UI.GetActiveAccentColor()

    if isParent then
        local isCurrentlyCollapsed = IsParentCollapsed(name) and not item._tempExpanded
        row.colBtn:ClearAllPoints()
        row.colBtn:SetPoint("LEFT", row, "LEFT", xPos, 0)
        row.colBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        if row.colIcon then
            if isCurrentlyCollapsed then
                if row.colIcon.SetRotation then row.colIcon:SetRotation(math.rad(-90)) end
                row.colIcon:SetVertexColor(0.60, 0.65, 0.75, 0.85)
            else
                if row.colIcon.SetRotation then row.colIcon:SetRotation(0) end
                row.colIcon:SetVertexColor(ar, ag, ab, 0.95)
            end
        end
        row.colBtn:SetScript("OnClick", function(_, button)
            if button == "RightButton" and not isSuiteHub then
                if IsControlKeyDown() then
                    OpenContextMenu(row, item)
                else
                    ToggleDirectFreeze()
                end
                return
            end
            HandleParentCollapseClick()
        end)
        row.colBtn:Show()
        xPos = xPos + 18
    else
        row.colBtn:Hide()
        xPos = xPos + 18
    end

    row.cb:ClearAllPoints()
    row.cb:SetPoint("LEFT", row, "LEFT", xPos, 0)
    row.cb:Enable()
    row.cb:EnableMouse(true)
    row.cb:RegisterForClicks("AnyUp")

    if isTwoStateCoreRow then
        row.cb:SetVisualState("LOCKED")
        row:SetAlpha(1.0)
    elseif isEffectiveFrozen then
        row.cb:SetVisualState("FROZEN")
        row:SetAlpha(0.55)
    elseif isEffectiveLocked then
        row.cb:SetVisualState("LOCKED")
        row:SetAlpha(1.0)
    else
        local isCheckedNow = (desired[name] == true) or isAutoEnabled
        row.cb:SetVisualState(isCheckedNow and "CHECKED" or "UNCHECKED")
        row:SetAlpha(1.0)
    end

    local function SyncPeerModuleSuiteState(modName, enabled)
        if not modName or modName == "DynamicSuite" or modName == "DynamicLoad" then return end
        if addonTable.SetSuiteModuleEnabled then
            addonTable.SetSuiteModuleEnabled(modName, enabled, true)
        end
    end

    row.cb:SetScript("OnClick", function(self, button)
        if isTwoStateCoreRow or isEffectiveFrozen or isEffectiveLocked then
            return
        end
        if button == "RightButton" then
            if IsControlKeyDown() then
                OpenContextMenu(row, item)
            else
                ToggleDirectFreeze()
            end
            return
        end
        local wasChecked = (desired[name] == true) or isAutoEnabled
        local isChecked = not wasChecked
        if not profile.addons then profile.addons = {} end
        profile.addons[name] = isChecked
        if isSuiteMod and name ~= "DynamicLoad" then
            SyncPeerModuleSuiteState(name, isChecked)
        end
        if (isParent or isSuiteHub) and type(item.children) == "table" then
            for _, c in ipairs(item.children or {}) do
                local cName = ResolveCanonKey(c.name)
                if addonTable.IsAddonFrozen(cName) then
                    profile.addons[cName] = nil
                elseif not addonTable.IsAddonLocked(cName) then
                    profile.addons[cName] = isChecked
                    if c.isSuiteModule and cName ~= "DynamicLoad" then
                        SyncPeerModuleSuiteState(cName, isChecked)
                    end
                end
            end
        elseif not isParent and not isSuiteHub and item.parent then
            if isChecked then
                local pNameKey = ResolveCanonKey(item.parent)
                profile.addons[pNameKey] = true
                if addonTable.IsAddonFrozen(pNameKey) then
                    addonTable.SetAddonFrozen(pNameKey, false)
                end
            end
        end
        addonTable.StageAddonProfile(selectedTabKey)
        if scrollChild.Refresh then scrollChild:Refresh() end
        if addonTable.mainFrame and addonTable.mainFrame.RefreshLeftRailVisuals then addonTable.mainFrame.RefreshLeftRailVisuals() end
        if addonTable.mainFrame and addonTable.mainFrame.UpdateStatusBar then addonTable.mainFrame.UpdateStatusBar() end
    end)
    xPos = xPos + 20

    row.lockBtn:Hide()

    -- Wire Inline Load Mode Pill Group (Design System Section 2.3)
    -- DynamicSuite & standalone DynamicLoad use a dedicated 2-state [Always] / [Never] bar
    -- (leaving the By Zone column blank so they can never unload themselves by zone).
    row.suiteTag:Hide()
    row.modeGroup:Show()
    if isTwoStateCoreRow then
        row.btnZone:Hide()
        row.btnZone:SetScript("OnClick", nil)
        row.btnAlways:Show()
        row.btnNever:Show()
        row.btnAlways:SetSelected(true, UI.COLORS.GOLD)
        row.btnNever:SetSelected(false, UI.COLORS.CYAN)

        row.btnAlways:SetScript("OnClick", function()
            if type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() then
                print(string.format("%s: Cannot change addon load states during combat. Please leave combat and try again.", tostring(ADDON_TITLE or "|cFFCBD5E1DynamicLoad|r")))
                return
            end
            local targetAddon = isSuiteHub and "DynamicSuite" or "DynamicLoad"
            if C_AddOns and C_AddOns.EnableAddOn then
                pcall(C_AddOns.EnableAddOn, targetAddon, GetPlayerSafe())
                pcall(C_AddOns.EnableAddOn, targetAddon)
            end
            if scrollChild and type(scrollChild.Refresh) == "function" then scrollChild:Refresh() end
            if addonTable.mainFrame and addonTable.mainFrame.RefreshLeftRailVisuals then addonTable.mainFrame.RefreshLeftRailVisuals() end
            if addonTable.mainFrame and addonTable.mainFrame.UpdateStatusBar then addonTable.mainFrame.UpdateStatusBar() end
        end)

        row.btnNever:SetScript("OnClick", function()
            local targetAddon = isSuiteHub and "DynamicSuite" or "DynamicLoad"
            if type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() then
                print(string.format("%s: Cannot disable %s during combat. Please leave combat and try again.", tostring(ADDON_TITLE or "|cFFCBD5E1DynamicLoad|r"), targetAddon))
                return
            end
            ShowDisableCoreAddonModal(targetAddon)
        end)
    else
        row.btnZone:Show()
        row.btnAlways:Show()
        row.btnNever:Show()

        local isNormal = (not isEffectiveLocked and not isLocked and not isEffectiveFrozen and not isFrozen and not (isParent and isAutoCore))
        local isLock = (isEffectiveLocked or isLocked or (isParent and isAutoCore))
        local isFrz = (isEffectiveFrozen or isFrozen)

        row.btnZone:SetSelected(isNormal, { r = ar, g = ag, b = ab })
        row.btnAlways:SetSelected(isLock and not isFrz, UI.COLORS.GOLD)
        row.btnNever:SetSelected(isFrz, UI.COLORS.CYAN)

        row.btnZone:SetScript("OnClick", function()
            if type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() then
                print(string.format("%s: Cannot change addon load states during combat. Please leave combat and try again.", tostring(ADDON_TITLE or "|cFFCBD5E1DynamicLoad|r")))
                return
            end
            if isParent then
                if type(CascadeParentSecurity) == "function" then
                    CascadeParentSecurity(item, "NORMAL")
                end
            else
                if type(SetParentCascaded) == "function" then SetParentCascaded(name, nil) end
                if addonTable.SetAddonLocked then addonTable.SetAddonLocked(name, false) end
                if addonTable.SetAddonFrozen then addonTable.SetAddonFrozen(name, false) end
                if isSuiteMod and name ~= "DynamicLoad" then
                    SyncPeerModuleSuiteState(name, true)
                end
                if addonTable.StageAddonProfile then addonTable.StageAddonProfile(selectedTabKey) end
            end
            if scrollChild and type(scrollChild.Refresh) == "function" then scrollChild:Refresh() end
            if addonTable.mainFrame and addonTable.mainFrame.RefreshLeftRailVisuals then addonTable.mainFrame.RefreshLeftRailVisuals() end
            if addonTable.mainFrame and addonTable.mainFrame.UpdateStatusBar then addonTable.mainFrame.UpdateStatusBar() end
        end)

        row.btnAlways:SetScript("OnClick", function()
            if type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() then
                print(string.format("%s: Cannot change addon load states during combat. Please leave combat and try again.", tostring(ADDON_TITLE or "|cFFCBD5E1DynamicLoad|r")))
                return
            end
            if isParent then
                if type(CascadeParentSecurity) == "function" then
                    CascadeParentSecurity(item, "LOCKED")
                end
            else
                if type(SetParentCascaded) == "function" then SetParentCascaded(name, nil) end
                if addonTable.SetAddonLocked then addonTable.SetAddonLocked(name, true) end
                if addonTable.SetAddonFrozen then addonTable.SetAddonFrozen(name, false) end
                if isSuiteMod and name ~= "DynamicLoad" then
                    SyncPeerModuleSuiteState(name, true)
                end
                if item.parent and addonTable.IsAddonFrozen and addonTable.IsAddonFrozen(item.parent) and addonTable.SetAddonFrozen then
                    addonTable.SetAddonFrozen(item.parent, false)
                end
                if addonTable.StageAddonProfile then addonTable.StageAddonProfile(selectedTabKey) end
            end
            if scrollChild and type(scrollChild.Refresh) == "function" then scrollChild:Refresh() end
            if addonTable.mainFrame and addonTable.mainFrame.RefreshLeftRailVisuals then addonTable.mainFrame.RefreshLeftRailVisuals() end
            if addonTable.mainFrame and addonTable.mainFrame.UpdateStatusBar then addonTable.mainFrame.UpdateStatusBar() end
        end)

        row.btnNever:SetScript("OnClick", function()
            if type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() then
                print(string.format("%s: Cannot change addon load states during combat. Please leave combat and try again.", tostring(ADDON_TITLE or "|cFFCBD5E1DynamicLoad|r")))
                return
            end
            if isParent then
                if type(CascadeParentSecurity) == "function" then
                    CascadeParentSecurity(item, "FROZEN")
                end
            else
                if type(SetParentCascaded) == "function" then SetParentCascaded(name, nil) end
                if addonTable.SetAddonLocked then addonTable.SetAddonLocked(name, false) end
                if addonTable.SetAddonFrozen then addonTable.SetAddonFrozen(name, true) end
                if isSuiteMod and name ~= "DynamicLoad" then
                    SyncPeerModuleSuiteState(name, false)
                end
                if addonTable.StageAddonProfile then addonTable.StageAddonProfile(selectedTabKey) end
            end
            if scrollChild and type(scrollChild.Refresh) == "function" then scrollChild:Refresh() end
            if addonTable.mainFrame and addonTable.mainFrame.RefreshLeftRailVisuals then addonTable.mainFrame.RefreshLeftRailVisuals() end
            if addonTable.mainFrame and addonTable.mainFrame.UpdateStatusBar then addonTable.mainFrame.UpdateStatusBar() end
        end)
    end

    local decoratedTitle = displayName
    if isSuiteHub then
        if row.modIconTex then row.modIconTex:Hide() end
        if not row.suiteEmblem then
            local suiteEmblem = CreateFrame("Frame", nil, row)
            suiteEmblem:SetSize(16, 16)
            UI.CreatePixelBorder(suiteEmblem, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.85, 3)
            UI.DrawBrandEmblem(suiteEmblem, 16)
            row.suiteEmblem = suiteEmblem
        end
        row.suiteEmblem:ClearAllPoints()
        row.suiteEmblem:SetPoint("LEFT", row, "LEFT", xPos, 0)
        if row.suiteEmblem.SetAccentColor then
            row.suiteEmblem:SetAccentColor(ar, ag, ab, 1)
        end
        row.suiteEmblem:Show()
        if addonTable.mainFrame then
            addonTable.mainFrame.suiteHubRowEmblem = row.suiteEmblem
        end
        xPos = xPos + 20
        decoratedTitle = UI.FormatTwoToneBrand("Suite")
    elseif isSuiteMod then
        if row.suiteEmblem then row.suiteEmblem:Hide() end
        if row.modIconTex then
            row.modIconTex:ClearAllPoints()
            row.modIconTex:SetPoint("LEFT", row, "LEFT", xPos, 0)
            row.modIconTex:SetTexture(UI.GetModuleIconPath(name))
            row.modIconTex:SetTexCoord(0, 1, 0, 1)
            row.modIconTex:SetVertexColor(ar, ag, ab, 0.95)
            row.modIconTex:Show()
            xPos = xPos + 18
        end
        decoratedTitle = UI.FormatTwoToneBrand(name)
    else
        if row.suiteEmblem then row.suiteEmblem:Hide() end
        if row.modIconTex then
            row.modIconTex:ClearAllPoints()
            row.modIconTex:SetPoint("LEFT", row, "LEFT", xPos, 0)
            if item.iconAtlas and item.iconAtlas ~= "" and row.modIconTex.SetAtlas then
                row.modIconTex:SetAtlas(item.iconAtlas, false)
                row.modIconTex:SetTexCoord(0, 1, 0, 1)
                row.modIconTex:SetVertexColor(1, 1, 1, 0.95)
                row.modIconTex:Show()
                xPos = xPos + 18
            elseif item.iconTex and item.iconTex ~= "" then
                row.modIconTex:SetTexture(item.iconTex)
                row.modIconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                row.modIconTex:SetVertexColor(1, 1, 1, 0.95)
                row.modIconTex:Show()
                xPos = xPos + 18
            else
                row.modIconTex:SetTexture("Interface\\Icons\\Trade_Engineering")
                row.modIconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                row.modIconTex:SetVertexColor(0.40, 0.45, 0.52, 0.60)
                row.modIconTex:Show()
                xPos = xPos + 18
            end
        end
    end

    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row, "LEFT", xPos, 0)
    row.label:SetPoint("RIGHT", row.modeGroup, "LEFT", -10, 0)

    if isEffectiveFrozen then
        row.leftAccent:SetColorTexture(0.32, 0.35, 0.40, 0.75)
        row.leftAccent:Show()
    elseif isEffectiveLocked then
        row.leftAccent:SetColorTexture(ar, ag, ab, 0.85)
        row.leftAccent:Show()
    else
        row.leftAccent:Hide()
    end

    local pendingState = pendingChanges and pendingChanges[name]
    local pendingTag = ""
    if pendingState == true then
        pendingTag = "  |cFF22C55E[+ Will Load]|r"
    elseif pendingState == false then
        pendingTag = "  |cFFF59E0B[- Will Unload]|r"
    end

    local coreBadge = (isSuiteHub or isSuiteMod) and string.format("|cFF%s[Suite Core]|r", tostring(UI.GetActiveAccentHex() or "CBD5E1")) or "|cFFFACC15[Always]|r"
    local standaloneTag = ""
    if item.isStandaloneSuiteFolder and not isSuiteHub then
        local hasBundle = (C_AddOns and C_AddOns.GetAddOnInfo and C_AddOns.GetAddOnInfo("DynamicSuite") ~= nil)
        if hasBundle then
            if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name) then
                standaloneTag = "  |cFF22C55E[Standalone Active]|r"
            else
                standaloneTag = "  |cFF94A3B8[Standalone Folder - Yielding to Suite]|r"
            end
        else
            standaloneTag = "  |cFF38BDF8[Standalone Module]|r"
        end
    end

    if isSuiteHub then
        UI.SetFont(row.label, 12, "", 0.953, 0.961, 0.973, 1)
        row.label:SetText(string.format("%s  %s |cFF7A8392(%d/%d Modules Active)|r%s", tostring(decoratedTitle or ""), coreBadge, tonumber(activeChildren) or 0, tonumber(totalChildren) or 8, tostring(pendingTag or "")))
    elseif isEffectiveFrozen then
        UI.SetFont(row.label, 11, "", 0.322, 0.345, 0.400, 0.90)
        if isParent and totalChildren > 0 then
            row.label:SetText(string.format("%s  |cFF38BDF8[Never]|r |cFF525866(0/%d active)|r%s%s", tostring(decoratedTitle or ""), tonumber(totalChildren) or 0, standaloneTag, tostring(pendingTag or "")))
        else
            row.label:SetText(tostring(decoratedTitle or "") .. "  |cFF38BDF8[Never]|r" .. standaloneTag .. tostring(pendingTag or ""))
        end
    elseif isParent and isAutoCore then
        UI.SetFont(row.label, 12, "", 0.953, 0.961, 0.973, 1)
        if frozenChildren > 0 then
            row.label:SetText(string.format("%s  %s |cFF7A8392(%d/%d active, %d never)|r%s", tostring(decoratedTitle or ""), coreBadge, tonumber(activeChildren) or 0, tonumber(totalChildren) or 0, tonumber(frozenChildren) or 0, tostring(pendingTag or "")))
        else
            row.label:SetText(string.format("%s  %s |cFF7A8392(%d/%d active)|r%s", tostring(decoratedTitle or ""), coreBadge, tonumber(activeChildren) or 0, tonumber(totalChildren) or 0, tostring(pendingTag or "")))
        end
    elseif isEffectiveLocked then
        UI.SetFont(row.label, 11, "", 0.953, 0.961, 0.973, 0.98)
        if isParent and totalChildren > 0 then
            row.label:SetText(string.format("%s  %s |cFF7A8392(%d/%d active)|r%s", tostring(decoratedTitle or ""), coreBadge, tonumber(activeChildren) or 0, tonumber(totalChildren) or 0, tostring(pendingTag or "")))
        else
            row.label:SetText(tostring(decoratedTitle or "") .. "  " .. coreBadge .. standaloneTag .. tostring(pendingTag or ""))
        end
    elseif isParent then
        UI.SetFont(row.label, 12, "", 0.953, 0.961, 0.973, 1)
        if frozenChildren > 0 then
            row.label:SetText(string.format("%s  |cFF7A8392(%d/%d active, %d never)|r%s", tostring(decoratedTitle or ""), tonumber(activeChildren) or 0, tonumber(totalChildren) or 0, tonumber(frozenChildren) or 0, tostring(pendingTag or "")))
        else
            row.label:SetText(string.format("%s  |cFF7A8392(%d/%d modules)|r%s", tostring(decoratedTitle or ""), tonumber(activeChildren) or 0, tonumber(totalChildren) or 0, tostring(pendingTag or "")))
        end
    else
        local isRowActive = (desired[name] == true) or isAutoEnabled
        if isRowActive then
            UI.SetFont(row.label, 11, "", 0.953, 0.961, 0.973, 0.96)
        else
            UI.SetFont(row.label, 11, "", 0.580, 0.639, 0.722, 0.88)
        end
        row.label:SetText(tostring(decoratedTitle or "") .. standaloneTag .. tostring(pendingTag or ""))
    end

    row.cpuBtn:ClearAllPoints()
    row.cpuBtn:SetPoint("RIGHT", row, "RIGHT", -12, 0)
    UI.SetFont(row.cpuText, 11, "", 1, 1, 1, 0.9)
    if isSuiteHub then
        local totalSuiteCpu = GetAddonCpuRaw("DynamicSuite", sortMode)
        for _, sc in ipairs(item.children or {}) do
            if sc.name ~= "DynamicSuite" then
                totalSuiteCpu = totalSuiteCpu + GetAddonCpuRaw(sc.name, sortMode)
            end
        end
        row.cpuText:SetText(FormatCpuValueAsPct(totalSuiteCpu, "22C55E"))
    else
        row.cpuText:SetText(FormatCpuUsage(name))
    end

    row.cpuBtn:SetScript("OnEnter", ShowFullRowTooltip)
    row.cpuBtn:SetScript("OnLeave", HideFullRowTooltip)
    row.cpuBtn:Show()

    return 24
end

local function RefreshAddonTree(scrollChild, resetScrollToTop)
    if isRefreshing or not scrollChild then return end
    isRefreshing = true
    UI.RefreshPaletteCache()

    local sf = (addonTable.mainFrame and addonTable.mainFrame.scrollFrame) or (scrollChild and scrollChild:GetParent())
    if sf and sf.GetWidth then
        local sfw = sf:GetWidth()
        if sfw and sfw > 50 then
            scrollChild:SetWidth(sfw)
        end
    end
    local keepScroll = 0
    if resetScrollToTop then
        keepScroll = 0
        if sf then
            sf._lastUserScroll = 0
            if sf.SetVerticalScroll then sf:SetVerticalScroll(0) end
        end
    elseif sf then
        local liveScroll = (sf.GetVerticalScroll and sf:GetVerticalScroll()) or 0
        if liveScroll > 0 then
            keepScroll = liveScroll
            sf._lastUserScroll = liveScroll
        else
            keepScroll = sf._lastUserScroll or 0
        end
    end

    local topLevel = BuildAddonHierarchy()
    local profile = DynamicLoadDB and DynamicLoadDB.profiles and DynamicLoadDB.profiles[selectedTabKey]
    local desired = (profile and profile.addons) or {}
    local filter = searchFilter:lower():trim()

    local yOffset = 0
    local rowIndex = 0
    local coreCount = 0
    local frozenCount = 0
    local deltaCount, pendingChanges = 0, {}
    if addonTable.CalculateAddonDelta then
        deltaCount, pendingChanges = addonTable.CalculateAddonDelta(selectedTabKey)
    end
    pendingChanges = pendingChanges or {}
    local pendingCount = deltaCount or 0

    for _, item in ipairs(topLevel or {}) do
        local isEffLocked, isEffFrozen = UI.EvaluateAddonItemEffectiveState(item, desired)
        if isEffLocked then
            coreCount = coreCount + 1
        elseif isEffFrozen then
            frozenCount = frozenCount + 1
        end
        if type(item.children) == "table" then
            for _, c in ipairs(item.children or {}) do
                local cEffLocked, cEffFrozen = UI.EvaluateAddonItemEffectiveState(c, desired)
                if cEffLocked then
                    coreCount = coreCount + 1
                elseif cEffFrozen then
                    frozenCount = frozenCount + 1
                end
            end
        end
    end

    if addonTable.mainFrame and addonTable.mainFrame.UpdateFilterChips then
        addonTable.mainFrame.UpdateFilterChips(coreCount, frozenCount, pendingCount)
    end
    if addonTable.mainFrame and addonTable.mainFrame.UpdateCollapseAllButton then
        addonTable.mainFrame.UpdateCollapseAllButton(topLevel)
    end
    if addonTable.mainFrame and addonTable.mainFrame.RefreshTelemetryStrip then
        addonTable.mainFrame.RefreshTelemetryStrip()
    end

    for _, item in ipairs(topLevel or {}) do
        local isLocked, isFrozen = UI.EvaluateAddonItemEffectiveState(item, desired)
        local isPending = (pendingChanges[item.name] ~= nil)
        local hasLockedChild = false
        local hasFrozenChild = false
        local hasPendingChild = false
        if type(item.children) == "table" then
            for _, c in ipairs(item.children or {}) do
                local cLocked, cFrozen = UI.EvaluateAddonItemEffectiveState(c, desired)
                if cLocked then hasLockedChild = true end
                if cFrozen then hasFrozenChild = true end
                if pendingChanges[c.name] ~= nil then hasPendingChild = true end
            end
        end

        local matchesSecurity = true
        if securityFilter == "PENDING" then
            matchesSecurity = isPending or hasPendingChild
        elseif securityFilter == "CORE" then
            matchesSecurity = isLocked or hasLockedChild
        elseif securityFilter == "FROZEN" then
            matchesSecurity = isFrozen or hasFrozenChild
        end

        local matchesText = (filter == "") or item.name:lower():find(filter, 1, true) or item.title:lower():find(filter, 1, true)
        local childMatch = false

        if filter ~= "" and type(item.children) == "table" then
            for _, c in ipairs(item.children or {}) do
                if c.name:lower():find(filter, 1, true) or c.title:lower():find(filter, 1, true) then
                    childMatch = true
                    break
                end
            end
        end

        if matchesSecurity and (matchesText or childMatch) then
            local autoExpandParent = (filter ~= "" and childMatch)
                or (securityFilter == "PENDING" and hasPendingChild)
                or (securityFilter == "CORE" and hasLockedChild)
                or (securityFilter == "FROZEN" and hasFrozenChild)
            item._tempExpanded = autoExpandParent
            rowIndex = rowIndex + 1
            local rowHeight = RenderAddonRow(scrollChild, item, desired, profile, 6, yOffset, rowIndex, pendingChanges)
            yOffset = yOffset + rowHeight

            if item.isParent and type(item.children) == "table" and (not IsParentCollapsed(item.name) or autoExpandParent) then
                for _, child in ipairs(item.children or {}) do
                    local cLocked, cFrozen = UI.EvaluateAddonItemEffectiveState(child, desired)
                    local cPending = (pendingChanges[child.name] ~= nil)
                    local cSecMatch = true
                    if securityFilter == "PENDING" then
                        cSecMatch = cPending or isPending
                    elseif securityFilter == "CORE" then
                        cSecMatch = cLocked
                    elseif securityFilter == "FROZEN" then
                        cSecMatch = cFrozen
                    end

                    local cTextMatch = (filter == "") or child.name:lower():find(filter, 1, true) or child.title:lower():find(filter, 1, true)
                    if cSecMatch and (cTextMatch or matchesText) then
                        rowIndex = rowIndex + 1
                        local cHeight = RenderAddonRow(scrollChild, child, desired, profile, 28, yOffset, rowIndex, pendingChanges)
                        yOffset = yOffset + cHeight
                    end
                end
            end
        end
    end

    for i = rowIndex + 1, #rowPool do
        rowPool[i]:Hide()
    end

    local totalHeight = math.max(yOffset + 12, 1)
    scrollChild:SetHeight(totalHeight)
    if sf and sf.UpdateScrollChildRect then
        pcall(sf.UpdateScrollChildRect, sf)
    end
    local function ApplyPreservedScroll()
        if not sf or not sf.SetVerticalScroll then return end
        local visH = (sf.GetHeight and sf:GetHeight()) or 0
        local maxScroll = (visH > 0) and math.max(0, totalHeight - visH) or keepScroll
        local targetScroll = resetScrollToTop and 0 or math.max(0, math.min(keepScroll, maxScroll))
        sf._lastUserScroll = targetScroll
        sf:SetVerticalScroll(targetScroll)
        if addonTable.mainFrame and addonTable.mainFrame.UpdateThinScrollBar then
            addonTable.mainFrame.UpdateThinScrollBar()
        end
    end
    ApplyPreservedScroll()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, ApplyPreservedScroll)
    end
    isRefreshing = false
end

--------------------------------------------------------------------------------
-- Scope Switcher & Alt Cloner Dropdown Menu ([All Characters v] <-> [<Player> (Char) v])
--------------------------------------------------------------------------------
local function OpenAltDropdown(anchorFrame, f)
    UI.RefreshPaletteCache()
    if not altDropdownFrame then
        local menu = CreateFrame("Frame", "DynamicLoadAltDropdown", UIParent)
        menu:SetSize(244, 150)
        menu:SetFrameStrata("TOOLTIP")
        menu:SetClampedToScreen(true)
        menu.bg = UI.SolidTex(menu, "BACKGROUND", 0, UI.COLORS.PANEL_BG.r, UI.COLORS.PANEL_BG.g, UI.COLORS.PANEL_BG.b, 0.98)
        menu.bg:SetAllPoints()
        UI.CreatePixelBorder(menu, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.9, 3)
        menu.rowPool = {}
        tinsert(UISpecialFrames, "DynamicLoadAltDropdown")
        altDropdownFrame = menu
    end

    local menu = altDropdownFrame
    menu.rowPool = menu.rowPool or {}
    menu.dsBorder:SetColor(UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.9)
    for i = 1, #menu.rowPool do
        menu.rowPool[i]:Hide()
    end

    local poolIdx = 0
    local function AcquireAltMenuRow(rowWidth, rowHeight, label, isSelected)
        poolIdx = poolIdx + 1
        local btn = menu.rowPool[poolIdx]
        if not btn then
            btn = CreateFlatButton(menu, rowWidth, rowHeight, label, isSelected)
            menu.rowPool[poolIdx] = btn
        else
            btn:SetSize(rowWidth, rowHeight)
            if btn.label then btn.label:SetText(label) end
            if btn.SetSelected then btn:SetSelected(isSelected) end
        end
        btn:ClearAllPoints()
        btn:Show()
        return btn
    end

    local curScope = (addonTable.GetCharScopeMode and addonTable.GetCharScopeMode()) or "GLOBAL"
    local curCharKey = (addonTable.GetCurrentCharKey and addonTable.GetCurrentCharKey()) or ""
    local pName = (addonTable.GetPlayer and addonTable.GetPlayer()) or (UnitName("player") or "Character")
    local _, pClass = UnitClass("player")
    local pColor = (RAID_CLASS_COLORS and pClass and RAID_CLASS_COLORS[pClass]) or UI.COLORS.ACCENT

    local yOffset = 8
    local rowWidth = 228

    -- Option 1: All Characters (Account-Wide Scope)
    local allBtn = AcquireAltMenuRow(rowWidth, 22, "All Characters (Account-Wide)", curScope == "GLOBAL" and selectedAltKey == nil)
    allBtn:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -yOffset)
    allBtn:SetScript("OnClick", function()
        selectedAltKey = nil
        if addonTable.SetCharScopeMode then
            addonTable.SetCharScopeMode("GLOBAL")
        end
        if f.RefreshScopePillLabel then
            f.RefreshScopePillLabel()
        else
            anchorFrame.label:SetText("Global")
        end
        if f.altBanner then
            f.altBanner:Hide()
            f.scrollFrame:SetPoint("TOPLEFT", f.toolbar, "BOTTOMLEFT", 0, -8)
        end
        if addonTable.ApplySuiteThemeAndGeometry then addonTable.ApplySuiteThemeAndGeometry() end
        if f.themeView and f.themeView.Refresh then f.themeView.Refresh() end
        if f.scrollChild then RefreshAddonTree(f.scrollChild) end
        if f.UpdateStatusBar then f.UpdateStatusBar() end
        CloseContextMenu()
    end)
    yOffset = yOffset + 26

    -- Option 2: Current Character Specific Scope (<PlayerName> (Character Specific))
    local charScopeLabel = string.format("|cFF%02x%02x%02x%s|r (Character Specific)", pColor.r * 255, pColor.g * 255, pColor.b * 255, pName)
    local charScopeBtn = AcquireAltMenuRow(rowWidth, 22, charScopeLabel, curScope == "CHARACTER" and selectedAltKey == nil)
    charScopeBtn:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -yOffset)
    charScopeBtn:SetScript("OnClick", function()
        selectedAltKey = nil
        if addonTable.SetCharScopeMode then
            addonTable.SetCharScopeMode("CHARACTER")
        end
        if f.RefreshScopePillLabel then
            f.RefreshScopePillLabel()
        else
            anchorFrame.label:SetText(string.format("|cFF%02x%02x%02x%s|r (Char)", pColor.r * 255, pColor.g * 255, pColor.b * 255, pName))
        end
        if f.altBanner then
            f.altBanner:Hide()
            f.scrollFrame:SetPoint("TOPLEFT", f.toolbar, "BOTTOMLEFT", 0, -8)
        end
        if addonTable.ApplySuiteThemeAndGeometry then addonTable.ApplySuiteThemeAndGeometry() end
        if f.themeView and f.themeView.Refresh then f.themeView.Refresh() end
        if f.scrollChild then RefreshAddonTree(f.scrollChild) end
        if f.UpdateStatusBar then f.UpdateStatusBar() end
        CloseContextMenu()
    end)
    yOffset = yOffset + 26

    -- Option 3+: Copy / Inspect Other Alts on Account
    local chars = addonTable.GetKnownCharacters and addonTable.GetKnownCharacters() or {}
    for charKey, charData in pairs(chars) do
        if charKey ~= curCharKey then
            local cName = charData.name or charKey
            local cClass = charData.class or "WARRIOR"
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[cClass] or UI.COLORS.ACCENT
            local addonCount = 0
            for _, en in pairs(charData.addons or {}) do if en then addonCount = addonCount + 1 end end

            local label = string.format("Copy from |cFF%02x%02x%02x%s|r (%d)", color.r * 255, color.g * 255, color.b * 255, cName, addonCount)
            local btn = AcquireAltMenuRow(rowWidth, 20, label, selectedAltKey == charKey)
            btn:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -yOffset)
            btn:SetScript("OnClick", function()
                selectedAltKey = charKey
                if f.altBanner then
                    f.altBanner.text:SetText(string.format("Inspecting loadout: |cFF%02x%02x%02x%s|r (%d active addons)", color.r * 255, color.g * 255, color.b * 255, cName, addonCount))
                    if ((not addonTable.GetActiveWorkspaceView) or addonTable.GetActiveWorkspaceView() == "DYNAMICLOAD") and not isToastSubTabActive then
                        f.altBanner:Show()
                        f.scrollFrame:SetPoint("TOPLEFT", f.altBanner, "BOTTOMLEFT", 0, -6)
                    end
                end
                CloseContextMenu()
            end)
            yOffset = yOffset + 24
        end
    end

    menu:SetHeight(math.max(yOffset + 8, 60))
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, -2)
    menu:Show()
    GetClickCatcher():Show()
end

addonTable.RefreshAddonTree     = RefreshAddonTree
addonTable.OpenAltDropdown      = OpenAltDropdown
addonTable._closeDLContextMenu  = CloseContextMenu
addonTable._closeDLAltDropdown  = CloseAltDropdown

function addonTable.MountDynamicLoadWorkspace(f, workspace)
    if not f or not workspace then return end
    local UpdateAllTabVisuals
    local UpdateAutoToggleVisual
    -- VIEW A: DYNAMICLOAD WORKSPACE (6 Segmented Sub-Tabs + Toolbar + Addon Tree)
    ----------------------------------------------------------------------------
    local dlView = CreateFrame("Frame", nil, workspace)
    dlView:SetPoint("TOPLEFT", workspace, "TOPLEFT", 0, 0)
    dlView:SetPoint("BOTTOMRIGHT", workspace, "BOTTOMRIGHT", 0, 0)
    dlView:SetFrameLevel((workspace:GetFrameLevel() or 6) + 2)
    if dlView.SetClipsChildren then dlView:SetClipsChildren(false) end
    if (dlView:GetWidth() or 0) <= 0 or (dlView:GetHeight() or 0) <= 0 then
        local ww = (workspace:GetWidth() or 0) > 0 and workspace:GetWidth() or (((f:GetWidth() or 1040) - 204) - 2)
        local wh = (workspace:GetHeight() or 0) > 0 and workspace:GetHeight() or ((f:GetHeight() or 680) - 82)
        dlView:SetSize(math.max(500, ww), math.max(300, wh))
    end
    dlView:Show()
    f.dlView = dlView

    local navBar = CreateFrame("Frame", nil, dlView)
    navBar:SetPoint("TOPLEFT", dlView, "TOPLEFT", 0, 0)
    navBar:SetPoint("TOPRIGHT", dlView, "TOPRIGHT", 0, 0)
    navBar:SetHeight(42)
    navBar:SetFrameLevel((dlView:GetFrameLevel() or 8) + 2)
    navBar.bg = UI.SolidTex(navBar, "BACKGROUND", 0, 0, 0, 0, 0); navBar.bg:Hide()
    navBar.bg:SetAllPoints()
    navBar.divider = UI.SolidTex(navBar, "OVERLAY", 2, 0, 0, 0, 0); navBar.divider:Hide()
    navBar.divider:SetPoint("BOTTOMLEFT", navBar, "BOTTOMLEFT", 0, 0)
    navBar.divider:SetPoint("BOTTOMRIGHT", navBar, "BOTTOMRIGHT", 0, 0)
    navBar.divider:SetHeight(1)
    navBar:Show()
    f.navBar = navBar

    do
    -- Full-Width Recessed Segmented Track Container (#0B0D12 background, 1px border, 34px tall) matching all 6 modules
    local segTrack = CreateFrame("Frame", nil, navBar)
    segTrack:SetPoint("TOPLEFT", dlView, "TOPLEFT", 14, -10)
    segTrack:SetPoint("TOPRIGHT", dlView, "TOPRIGHT", -16, -10)
    segTrack:SetHeight(34)
    segTrack:SetFrameLevel((navBar:GetFrameLevel() or 10) + 1)
    segTrack.bg = UI.SolidTex(segTrack, "BACKGROUND", 1, 0.043, 0.051, 0.071, 0.98)
    segTrack.bg:SetAllPoints()
    UI.CreatePixelBorder(segTrack, 1, 1, 1, 0.08, 2)
    segTrack:Show()
    f.segTrack = segTrack

    local tabButtons = {}
    local xOffset = 4

    UpdateAllTabVisuals = function()
        local ar, ag, ab = UI.GetActiveAccentColor()
        local loadedProf = (addonTable.GetLoadedProfile and addonTable.GetLoadedProfile()) or (DynamicLoadDB and DynamicLoadDB.loadedProfile) or (DynamicLoadDB and DynamicLoadDB.activeProfile) or "outdoor"
        local physicalLoc = (addonTable.GetPhysicalLocation and addonTable.GetPhysicalLocation()) or (addonTable.EvaluateCurrentEnvironment and addonTable.EvaluateCurrentEnvironment()) or "outdoor"
        for _, b in ipairs(tabButtons) do
            local isSelected = (not isToastSubTabActive and b.tabKey == selectedTabKey) or (isToastSubTabActive and b.tabKey == "toast_ui")
            if isSelected then
                local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}; local fa = gTbl.pillFillAlpha or 0.42; b.bg:SetColorTexture(ar * fa, ag * fa, ab * fa, 0.98)
                b.dsBorder:SetColor(ar, ag, ab, 0.95)
                b.dsBorder:Show()
                b.label:SetTextColor(1, 1, 1, 1)
                if b.iconTex then
                    b.iconTex:SetVertexColor(ar, ag, ab, 1.0)
                end
            else
                -- Distinct cell surface (#14171F) + 1px crisp border (#252A36) for every tab cell
                b.bg:SetColorTexture(0.078, 0.090, 0.122, 0.95)
                b.dsBorder:SetColor(0.145, 0.165, 0.212, 0.95)
                b.dsBorder:Show()
                b.label:SetTextColor(0.68, 0.72, 0.80, 1)
                if b.iconTex then
                    b.iconTex:SetVertexColor(0.72, 0.76, 0.84, 0.95)
                end
            end

            -- 1. Loaded Profile Dot: Clean 6x6 green square (0.133, 0.773, 0.369, 1.0) positioned at LEFT, btn.label, RIGHT, 5, 0
            -- Shown ONLY when btn.tabKey == addonTable.GetLoadedProfile()
            if b.loadedDot then
                b.loadedDot:SetShown(b.tabKey == loadedProf)
            end
            if b.liveDot and b.liveDot ~= b.loadedDot then
                b.liveDot:SetShown(b.tabKey == loadedProf)
            end

            -- 2. Current Physical Location Pin: Compact 8x8 cyan/sky-blue square (0.220, 0.741, 0.973, 1.0) positioned at RIGHT, btn.label, LEFT, -5, 0
            -- Shown ONLY when btn.tabKey == addonTable.GetPhysicalLocation()
            if b.locationPin then
                b.locationPin:SetShown(b.tabKey == physicalLoc)
            end

            b.label:ClearAllPoints()
            b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
        end
    end
    f.UpdateAllTabVisuals = UpdateAllTabVisuals
    addonTable.UpdateAllTabVisuals = UpdateAllTabVisuals

    for _, tabInfo in ipairs(CONTEXT_TABS) do
        local btn = CreateFrame("Button", nil, segTrack)
        btn:SetSize(112, 26)
        btn:SetPoint("LEFT", segTrack, "LEFT", xOffset, 0)
        btn.tabKey = tabInfo.key
        btn.baseLabel = tabInfo.label
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        btn.bg = UI.SolidTex(btn, "BACKGROUND", 2, 0.078, 0.090, 0.122, 0.95)
        btn.bg:SetAllPoints()
        UI.CreatePixelBorder(btn, 0.145, 0.165, 0.212, 0.95, 3)

        local label = btn:CreateFontString(nil, "OVERLAY")
        label:SetPoint("CENTER", btn, "CENTER", 0, 0)
        UI.SetFont(label, 11, "", 1, 1, 1, 0.92)
        label:SetText(tabInfo.label)
        btn.label = label

        -- Clean 6x6 solid square Green Dot for Loaded Profile
        local loadedDot = UI.SolidTex(btn, "OVERLAY", 4, 0.133, 0.773, 0.369, 1.0)
        loadedDot:SetSize(6, 6)
        if loadedDot.SetSnapToPixelGrid then loadedDot:SetSnapToPixelGrid(false) end
        if loadedDot.SetTexelSnappingBias then loadedDot:SetTexelSnappingBias(0) end
        loadedDot:SetPoint("LEFT", label, "RIGHT", 5, 0)
        loadedDot:Hide()
        btn.loadedDot = loadedDot
        btn.liveDot = loadedDot

        -- Clean 6x6 solid square Cyan/Sky-Blue Pin for Current Physical Location (matches loadedDot 6x6 size 1:1)
        local locationPin = UI.SolidTex(btn, "OVERLAY", 4, 0.220, 0.741, 0.973, 1.0)
        locationPin:SetSize(6, 6)
        if locationPin.SetSnapToPixelGrid then locationPin:SetSnapToPixelGrid(false) end
        if locationPin.SetTexelSnappingBias then locationPin:SetTexelSnappingBias(0) end
        locationPin:SetPoint("RIGHT", label, "LEFT", -5, 0)
        locationPin:Hide()
        btn.locationPin = locationPin

        btn:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                if IsControlKeyDown() then
                    if f.OpenZoneTabMenu then
                        f.OpenZoneTabMenu(self, self.tabKey, self.baseLabel)
                    end
                    return
                end
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION or 856)
                isToastSubTabActive = false; SyncStateToSuite()
                selectedTabKey = self.tabKey; SyncStateToSuite()
                if addonTable.ApplyProfile then
                    addonTable.ApplyProfile(self.tabKey, true)
                else
                    addonTable.StageAddonProfile(self.tabKey, true)
                    ReloadUI()
                end
                return
            end

            isToastSubTabActive = false; SyncStateToSuite()
            selectedTabKey = self.tabKey; SyncStateToSuite()
            if addonTable.SetToastEditMode then addonTable.SetToastEditMode(false) end
            if _G.DynamicLoadColorPicker then _G.DynamicLoadColorPicker:Hide() end
            UpdateAllTabVisuals()
            CloseContextMenu()
            if f.toastConfigPanel then f.toastConfigPanel:Hide() end
            if f.toolbar then f.toolbar:Show() end
            if f.telemetryStrip then f.telemetryStrip:Show() end
            if f.scrollFrame then f.scrollFrame:Show() end
            if f.scrollTrack then f.scrollTrack:Show() end
            if selectedAltKey and f.altBanner then f.altBanner:Show() end
            if f.scrollChild then RefreshAddonTree(f.scrollChild) end
            if f.UpdateStatusBar then f.UpdateStatusBar() end
        end)

        btn:SetScript("OnEnter", function(self)
            local isActive = (not isToastSubTabActive and self.tabKey == selectedTabKey)
            if not isActive then
                self.bg:SetColorTexture(0.110, 0.125, 0.161, 0.98)
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tabInfo.label .. " Zone Profile", 1, 1, 1)
            local accentHex = UI.GetActiveAccentHex()
            local loadedProf = (addonTable.GetLoadedProfile and addonTable.GetLoadedProfile()) or (DynamicLoadDB and DynamicLoadDB.loadedProfile) or "outdoor"
            local physicalLoc = (addonTable.GetPhysicalLocation and addonTable.GetPhysicalLocation()) or (addonTable.EvaluateCurrentEnvironment and addonTable.EvaluateCurrentEnvironment()) or "outdoor"
            if self.tabKey == loadedProf then
                GameTooltip:AddLine("|cFF22C55E|TInterface\\Buttons\\WHITE8X8:6:6:0:0:8:8:0:8:0:8:34:197:94|t Loaded:|r |cFFE2E8F0Currently Loaded Profile in this session|r", 1, 1, 1)
            end
            if self.tabKey == physicalLoc then
                GameTooltip:AddLine("|cFF38BDF8|TInterface\\Buttons\\WHITE8X8:6:6:0:0:8:8:0:8:0:8:56:189:248|t Location:|r |cFFE2E8F0Current Physical In-Game Location|r", 1, 1, 1)
            end
            GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0View & Edit " .. tabInfo.label .. " Profile|r", 1, 1, 1)
            GameTooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Activate " .. tabInfo.label .. " Profile & Reload UI|r", 1, 1, 1)
            GameTooltip:AddLine("|cFF" .. accentHex .. "Ctrl + Right-Click:|r |cFFE2E8F0Copy Addons From Another Zone...|r", 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            UpdateAllTabVisuals()
            GameTooltip:Hide()
        end)

        table.insert(tabButtons, btn)
        xOffset = xOffset + 116
    end

    -- 6th Tab inside segTrack: "[ Alert Toast Style ]" (Hidden in 5-zone full-width layout)
    local toastTabBtn = CreateFrame("Button", nil, segTrack)
    toastTabBtn:SetSize(146, 26)
    toastTabBtn:SetHeight(26)
    toastTabBtn:SetPoint("RIGHT", segTrack, "RIGHT", -4, 0)
    toastTabBtn:Hide()
    f.tabButtons = tabButtons
    local function ReflowDlTopTrack()
        local w = segTrack:GetWidth()
        if not w or w < 200 then
            local dw = (dlView and dlView.GetWidth and dlView:GetWidth()) or 0
            if dw < 200 then
                dw = (workspace and workspace.GetWidth and workspace:GetWidth()) or 0
            end
            if dw < 200 then
                dw = ((f and f.GetWidth and f:GetWidth()) or 1040) - 206
            end
            w = math.max(500, dw - 30)
        end
        local gap = 4
        local avail = w - 8
        local eachW = math.floor((avail - (gap * 4)) / 5)
        local btns = f.tabButtons or tabButtons
        for i = 1, 5 do
            local zb = btns[i]
            if zb then
                zb:ClearAllPoints()
                zb:SetHeight(26)
                if i == 1 then
                    zb:SetPoint("LEFT", segTrack, "LEFT", 4, 0)
                    zb:SetWidth(eachW)
                elseif i == 5 then
                    zb:SetPoint("LEFT", btns[4], "RIGHT", gap, 0)
                    zb:SetPoint("RIGHT", segTrack, "RIGHT", -4, 0)
                    if (zb:GetWidth() or 0) <= 0 then
                        zb:SetWidth(eachW)
                    end
                else
                    zb:SetPoint("LEFT", btns[i - 1], "RIGHT", gap, 0)
                    zb:SetWidth(eachW)
                end
                zb:Show()
            end
        end
    end
    f.ReflowDlTopTrack = ReflowDlTopTrack
    ReflowDlTopTrack()
    segTrack:SetScript("OnSizeChanged", ReflowDlTopTrack)
    segTrack:HookScript("OnShow", function() C_Timer.After(0, ReflowDlTopTrack) end)
    C_Timer.After(0, ReflowDlTopTrack)
    toastTabBtn.tabKey = "toast_ui"
    toastTabBtn.baseLabel = "Alert Toast Style"

    toastTabBtn.bg = UI.SolidTex(toastTabBtn, "BACKGROUND", 2, 0.078, 0.090, 0.122, 0.95)
    toastTabBtn.bg:SetAllPoints()
    UI.CreatePixelBorder(toastTabBtn, 0.145, 0.165, 0.212, 0.95, 3)

    local toastCogIcon = toastTabBtn:CreateTexture(nil, "OVERLAY", nil, 3)
    toastCogIcon:SetSize(14, 14)
    toastCogIcon:SetPoint("LEFT", toastTabBtn, "LEFT", 9, 0)
    toastCogIcon:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_cog.tga")
    toastCogIcon:SetTexCoord(0, 1, 0, 1)
    UI.DisablePixelSnap(toastCogIcon)
    toastCogIcon:SetVertexColor(0.72, 0.76, 0.84, 0.95)
    toastTabBtn.iconTex = toastCogIcon

    local toastTabLabel = toastTabBtn:CreateFontString(nil, "OVERLAY")
    toastTabLabel:SetPoint("LEFT", toastCogIcon, "RIGHT", 6, 0)
    UI.SetFont(toastTabLabel, 11, "", 0.68, 0.72, 0.80, 1)
    toastTabLabel:SetText("Alert Toast Style")
    toastTabBtn.label = toastTabLabel

    toastTabBtn:SetScript("OnEnter", function(self)
        if not isToastSubTabActive then
            self.bg:SetColorTexture(0.110, 0.125, 0.161, 0.98)
            self.label:SetTextColor(1, 1, 1, 1)
        end
    end)
    toastTabBtn:SetScript("OnLeave", function()
        UpdateAllTabVisuals()
    end)

    toastTabBtn:SetScript("OnClick", function()
        isToastSubTabActive = true; SyncStateToSuite()
        UpdateAllTabVisuals()
        CloseContextMenu()
        if addonTable.SetToastEditMode then addonTable.SetToastEditMode(false) end
        if f.toolbar then f.toolbar:Hide() end
        if f.telemetryStrip then f.telemetryStrip:Hide() end
        if f.altBanner then f.altBanner:Hide() end
        if f.scrollFrame then f.scrollFrame:Hide() end
        if f.scrollTrack then f.scrollTrack:Hide() end
        if f.toastConfigPanel then
            f.toastConfigPanel:Show()
            if f.toastConfigPanel.RefreshControls then
                f.toastConfigPanel.RefreshControls()
            end
        end
    end)
    table.insert(tabButtons, toastTabBtn)
    f.tabButtons = tabButtons

    f.SelectDynamicLoadSubTab = function(tabIdxOrKey)
        if tabIdxOrKey == "toast_ui" or tabIdxOrKey == "TOAST" or tabIdxOrKey == 6 then
            if toastTabBtn and toastTabBtn:GetScript("OnClick") then
                toastTabBtn:GetScript("OnClick")(toastTabBtn, "LeftButton")
            end
            return
        end
        if type(tabIdxOrKey) == "number" and tabButtons[tabIdxOrKey] then
            local btn = tabButtons[tabIdxOrKey]
            if btn:GetScript("OnClick") then
                btn:GetScript("OnClick")(btn, "LeftButton")
            end
            return
        end
        if type(tabIdxOrKey) == "string" then
            local lowerKey = tabIdxOrKey:lower()
            for _, btn in ipairs(tabButtons) do
                if btn.tabKey == lowerKey or (btn.baseLabel and btn.baseLabel:lower() == lowerKey) then
                    if btn:GetScript("OnClick") then
                        btn:GetScript("OnClick")(btn, "LeftButton")
                    end
                    return
                end
            end
        end
        if tabButtons[1] and tabButtons[1]:GetScript("OnClick") then
            tabButtons[1]:GetScript("OnClick")(tabButtons[1], "LeftButton")
        end
    end
    addonTable.SelectSubTab = function(selfOrIdx, maybeIdx)
        local target = (type(selfOrIdx) == "table") and maybeIdx or selfOrIdx
        if f and f.SelectDynamicLoadSubTab then
            f.SelectDynamicLoadSubTab(target or 1)
        end
    end

    UpdateAutoToggleVisual = function() end
    f.UpdateAutoToggleVisual = UpdateAutoToggleVisual

    local function UpdateTabActiveIndicators()
        UpdateAllTabVisuals()
    end
    f.UpdateTabActiveIndicators = UpdateTabActiveIndicators

    -- Zone Tab Ctrl+Right-Click Menu ("COPY ADDONS INTO <ZONE> FROM:")
    local zoneTabMenu = nil
    f.OpenZoneTabMenu = function(anchorBtn, targetKey, targetLabel)
        CloseContextMenu()
        if not zoneTabMenu then
            zoneTabMenu = CreateFrame("Frame", "DynamicLoadZoneTabMenu", UIParent)
            zoneTabMenu:SetSize(248, 202)
            zoneTabMenu:SetFrameStrata("TOOLTIP")
            zoneTabMenu:SetClampedToScreen(true)
            zoneTabMenu.bg = UI.SolidTex(zoneTabMenu, "BACKGROUND", 0, UI.COLORS.PANEL_BG.r, UI.COLORS.PANEL_BG.g, UI.COLORS.PANEL_BG.b, 0.98)
            zoneTabMenu.bg:SetAllPoints()
            UI.CreatePixelBorder(zoneTabMenu, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.9, 3)

            zoneTabMenu.title = zoneTabMenu:CreateFontString(nil, "OVERLAY")
            zoneTabMenu.title:SetPoint("TOPLEFT", zoneTabMenu, "TOPLEFT", 10, -8)
            UI.SetFont(zoneTabMenu.title, 10, "", UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 1)

            zoneTabMenu.rows = {}
            for i = 1, 8 do
                local rBtn = CreateFlatButton(zoneTabMenu, 228, 20, "", false)
                rBtn:SetPoint("TOPLEFT", zoneTabMenu, "TOPLEFT", 10, -28 - ((i - 1) * 23))
                zoneTabMenu.rows[i] = rBtn
            end
            f.zoneTabMenu = zoneTabMenu
        end

        local ar, ag, ab = UI.GetActiveAccentColor()
        zoneTabMenu.dsBorder:SetColor(ar, ag, ab, 0.9)
        zoneTabMenu.title:SetTextColor(ar, ag, ab, 1)
        zoneTabMenu.title:SetText("COPY ADDONS INTO " .. tostring(targetLabel or targetKey):upper() .. " FROM:")
        local rowIdx = 0
        for _, srcTab in ipairs(CONTEXT_TABS) do
            if srcTab.key ~= targetKey then
                rowIdx = rowIdx + 1
                local rBtn = zoneTabMenu.rows[rowIdx]
                rBtn.label:SetText("Copy from " .. srcTab.label .. " Profile")
                rBtn:SetScript("OnClick", function()
                    local srcProf = DynamicLoadDB and DynamicLoadDB.profiles and DynamicLoadDB.profiles[srcTab.key]
                    local dstProf = DynamicLoadDB and DynamicLoadDB.profiles and DynamicLoadDB.profiles[targetKey]
                    if srcProf and dstProf then
                        dstProf.addons = {}
                        for k, v in pairs(srcProf.addons or {}) do
                            if IsStandaloneMarkerExcludedBySuite(k) then
                                dstProf.addons[k] = false
                            else
                                dstProf.addons[k] = v
                            end
                        end
                        if IsStandaloneMarkerExcludedBySuite("DynamicMarker") then
                            dstProf.addons["DynamicMarker"] = false
                        end
                        if selectedTabKey == targetKey then
                            addonTable.StageAddonProfile(targetKey)
                            if f.scrollChild then RefreshAddonTree(f.scrollChild) end
                            if f.UpdateStatusBar then f.UpdateStatusBar() end
                        end
                        print(string.format("|cFF38BDF8DynamicLoad|r: Copied %s profile addons into %s.", srcTab.label, targetLabel))
                    end
                    zoneTabMenu:Hide()
                    if clickCatcher then clickCatcher:Hide() end
                end)
                rBtn:Show()
            end
        end

        rowIdx = rowIdx + 1
        local copyLiveBtn = zoneTabMenu.rows[rowIdx]
        copyLiveBtn.label:SetText("Currently Loaded In-Game Addons")
        copyLiveBtn:SetScript("OnClick", function()
            addonTable.SnapshotActiveAddons(targetKey)
            if selectedTabKey == targetKey then
                addonTable.StageAddonProfile(targetKey)
                if f.scrollChild then RefreshAddonTree(f.scrollChild) end
                if f.UpdateStatusBar then f.UpdateStatusBar() end
            end
            zoneTabMenu:Hide()
            if clickCatcher then clickCatcher:Hide() end
        end)
        copyLiveBtn:Show()

        rowIdx = rowIdx + 1
        local clearBtn = zoneTabMenu.rows[rowIdx]
        clearBtn.label:SetText("Uncheck All in " .. targetLabel)
        clearBtn:SetScript("OnClick", function()
            local dstProf = DynamicLoadDB and DynamicLoadDB.profiles and DynamicLoadDB.profiles[targetKey]
            if dstProf then
                dstProf.addons = {}
                if selectedTabKey == targetKey then
                    addonTable.StageAddonProfile(targetKey)
                    if f.scrollChild then RefreshAddonTree(f.scrollChild) end
                    if f.UpdateStatusBar then f.UpdateStatusBar() end
                end
            end
            zoneTabMenu:Hide()
            if clickCatcher then clickCatcher:Hide() end
        end)
        clearBtn:Show()

        for i = rowIdx + 1, 7 do zoneTabMenu.rows[i]:Hide() end
        zoneTabMenu:SetHeight(34 + (rowIdx * 23))

        GetClickCatcher():Show()

        zoneTabMenu:ClearAllPoints()
        zoneTabMenu:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -4)
        zoneTabMenu:Show()
    end

    ----------------------------------------------------------------------------
    -- ACTION TOOLBAR (Auto-Sizing Buttons + 4-Mode CPU Sort + Neutral Filter Chips + Search)
    ----------------------------------------------------------------------------
    local toolbar = CreateFrame("Frame", nil, dlView)
    toolbar:SetPoint("TOPLEFT", dlView, "TOPLEFT", 14, -50)
    toolbar:SetPoint("TOPRIGHT", dlView, "TOPRIGHT", -16, -50)
    toolbar:SetHeight(24)
    toolbar:SetFrameLevel((dlView:GetFrameLevel() or 8) + 2)
    toolbar:Show()
    f.toolbar = toolbar

    local stashBtn = CreateFlatButton(toolbar, 96, 22, "Backup State", false)
    stashBtn:SetPoint("LEFT", toolbar, "LEFT", 0, 0)
    stashBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local blizzAddonsBtn = CreateFlatButton(toolbar, 108, 22, "Blizzard AddOns", false)
    blizzAddonsBtn:SetPoint("LEFT", stashBtn, "RIGHT", 5, 0)
    blizzAddonsBtn:SetScript("OnClick", function()
        if addonTable.OpenBlizzardAddonList then
            addonTable.OpenBlizzardAddonList()
        elseif type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() then
            print(string.format("%s: Cannot open Blizzard's AddOn list during combat. Please leave combat and try again.", tostring(ADDON_TITLE or "|cFFCBD5E1DynamicLoad|r")))
        elseif _G.AddonList then
            addonTable._bypassAddonListHook = true
            if type(_G.ShowUIPanel) == "function" then _G.ShowUIPanel(_G.AddonList) else _G.AddonList:Show() end
        end
    end)
    blizzAddonsBtn:SetScript("OnEnter", function(self)
        if not self:IsVisible() then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Open Blizzard AddOns", 1, 1, 1)
        GameTooltip:AddLine("Opens Blizzard's native AddOn list directly (you can also Shift-Click AddOns in the Esc menu).", 0.82, 0.85, 0.90, true)
        GameTooltip:Show()
    end)
    blizzAddonsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local sortBtn = CreateFlatButton(toolbar, 82, 22, "Sort: A-Z", false)
    sortBtn:SetPoint("LEFT", blizzAddonsBtn, "RIGHT", 5, 0)

    local collapseAllBtn = CreateFlatButton(toolbar, 56, 22, "[-] All", false)
    collapseAllBtn:SetPoint("LEFT", sortBtn, "RIGHT", 5, 0)

    local toolbarSep = UI.SolidTex(toolbar, "OVERLAY", 2, 1, 1, 1, 0.14)
    toolbarSep:SetSize(1, 16)
    toolbarSep:SetPoint("LEFT", collapseAllBtn, "RIGHT", 6, 0)

    local chipAll = CreateFlatButton(toolbar, 40, 22, "All", securityFilter == "ALL")
    chipAll:SetPoint("LEFT", toolbarSep, "RIGHT", 6, 0)

    local chipPending = CreateFlatButton(toolbar, 84, 22, "Pending (0)", securityFilter == "PENDING")
    chipPending:SetPoint("LEFT", chipAll, "RIGHT", 5, 0)
    chipPending.OnCustomEnter = function(self)
        if f.PopulatePendingReloadTooltip then f.PopulatePendingReloadTooltip(self, "ANCHOR_TOP") end
    end
    chipPending.OnCustomLeave = function()
        GameTooltip:Hide()
    end

    local chipCore = CreateFlatButton(toolbar, 84, 22, "Always (0)", securityFilter == "CORE")
    chipCore:SetPoint("LEFT", chipPending, "RIGHT", 5, 0)

    local chipFrozen = CreateFlatButton(toolbar, 80, 22, "Never (0)", securityFilter == "FROZEN")
    chipFrozen:SetPoint("LEFT", chipCore, "RIGHT", 5, 0)

    local function AutoSizeToolbarButtons()
        local function FitBtn(b, minW, pad)
            local strW = (b.label and b.label.GetStringWidth and b.label:GetStringWidth()) or 0
            local newW = math.max(minW, math.ceil(strW + (pad or 18)))
            if math.abs((b:GetWidth() or 0) - newW) > 0.5 then
                b:SetWidth(newW)
            end
        end
        FitBtn(stashBtn, 86, 18)
        FitBtn(blizzAddonsBtn, 102, 18)
        FitBtn(sortBtn, 72, 18)
        FitBtn(collapseAllBtn, 52, 16)
        FitBtn(chipAll, 38, 16)
        FitBtn(chipPending, 76, 16)
        FitBtn(chipCore, 66, 16)
        FitBtn(chipFrozen, 74, 16)
    end
    f.AutoSizeToolbarButtons = AutoSizeToolbarButtons

    local function UpdateStashButton()
        if addonTable.HasStash() then
            local info = addonTable.GetStashInfo()
            local count = info and info.counts and info.counts.active or 0
            stashBtn.label:SetText(string.format("Restore (%d)", count))
            stashBtn.bg:SetColorTexture(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.30)
            stashBtn.dsBorder:SetColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.90)
            stashBtn.label:SetTextColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1)
        else
            stashBtn.label:SetText("Backup State")
            stashBtn.bg:SetColorTexture(0.078, 0.090, 0.122, 0.95)
            stashBtn.dsBorder:SetColor(0.141, 0.161, 0.212, 0.90)
            stashBtn.label:SetTextColor(0.84, 0.86, 0.90, 1)
        end
        AutoSizeToolbarButtons()
    end
    f.UpdateStashButton = UpdateStashButton

    local function ShowStashButtonTooltip(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if addonTable.HasStash() then
            local info = addonTable.GetStashInfo()
            local count = info and info.counts and info.counts.active or 0
            GameTooltip:SetText(string.format("Restore Backup Snapshot (%d Addons Saved)", count), UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b)
            GameTooltip:AddLine(string.format("You have an active troubleshooting backup of %d enabled addons.", count), 0.88, 0.90, 0.94, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(string.format("|cFF34D399Left-Click (Restore & Conclude):|r |cFFE2E8F0Restores all %d backed-up addons, clears this snapshot, and returns the button to 'Backup State'.|r", count), 1, 1, 1, true)
            GameTooltip:AddLine("|cFF38BDF8Right-Click (Keep Current & Conclude):|r |cFFE2E8F0Finishes debugging without reverting - keeps your current addon list and clears the backup snapshot.|r", 1, 1, 1, true)
        else
            GameTooltip:SetText("Backup State (Troubleshooting Snapshot)", 1, 1, 1)
            GameTooltip:AddLine("Saves a snapshot of your current addon selections before you start disabling or testing addons to debug an issue.", 0.82, 0.85, 0.90, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Save Backup Snapshot|r", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end

    stashBtn:SetScript("OnEnter", function(self)
        if addonTable.HasStash() then
            self.bg:SetColorTexture(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.40)
        else
            self.bg:SetColorTexture(UI.COLORS.BTN_HOVER.r, UI.COLORS.BTN_HOVER.g, UI.COLORS.BTN_HOVER.b, 1)
        end
        ShowStashButtonTooltip(self)
    end)
    stashBtn:SetScript("OnLeave", function()
        UpdateStashButton()
        GameTooltip:Hide()
    end)

    stashBtn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if addonTable.HasStash() then
                addonTable.ClearStash()
                UpdateStashButton()
                if f.UpdateStatusBar then f.UpdateStatusBar() end
                if GameTooltip:GetOwner() == self then ShowStashButtonTooltip(self) end
            end
            return
        end
        if not addonTable.HasStash() then
            addonTable.StashCurrentState()
            UpdateStashButton()
            if GameTooltip:GetOwner() == self then ShowStashButtonTooltip(self) end
        else
            local delta, _, restoredCount = addonTable.RestoreStash()
            UpdateStashButton()
            if f.scrollChild then RefreshAddonTree(f.scrollChild) end
            if f.UpdateStatusBar then f.UpdateStatusBar() end
            if f.statusText then
                f.statusText:SetText(string.format("Restored |cFFFFFFFF%d Addons|r (Debug Concluded)   |   |cFFF5B82EClick Reload UI|r", restoredCount or 0))
            end
            if delta > 0 then addonTable.ShowToast(selectedTabKey, delta) end
            if GameTooltip:GetOwner() == self then ShowStashButtonTooltip(self) end
        end
    end)

    local SORT_MODES = {
        { key = "NAME",     label = "Sort: A-Z" },
        { key = "CPU_CUR",  label = "Sort: Current CPU" },
        { key = "CPU_AVG",  label = "Sort: Avg CPU" },
        { key = "CPU_PEAK", label = "Sort: Peak CPU" },
    }
    local function UpdateSortBtnVisual()
        local lbl = "Sort: A-Z"
        for _, sm in ipairs(SORT_MODES) do
            if sm.key == sortMode then lbl = sm.label; break end
        end
        sortBtn.label:SetText(lbl)
        local ar, ag, ab = UI.GetActiveAccentColor()
        sortBtn.idleBgColor = { r = 0.078, g = 0.090, b = 0.122, a = 0.95 }
        sortBtn.idleBorderColor = { r = 0.141, g = 0.161, b = 0.212, a = 0.90 }
        sortBtn:SetSelected(sortMode ~= "NAME", { r = ar, g = ag, b = ab })
        AutoSizeToolbarButtons()
    end
    sortBtn:SetScript("OnClick", function()
        local nextIdx = 1
        for idx, sm in ipairs(SORT_MODES) do
            if sm.key == sortMode then
                nextIdx = (idx % #SORT_MODES) + 1
                break
            end
        end
        sortMode = SORT_MODES[nextIdx].key
        UpdateSortBtnVisual()
        if f.scrollFrame then
            f.scrollFrame._lastUserScroll = 0
            f.scrollFrame:SetVerticalScroll(0)
        end
        if f.scrollChild then RefreshAddonTree(f.scrollChild, true) end
    end)
    sortBtn.OnCustomEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Cycle AddOn Sort Order", 1, 1, 1)
        GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Cycle A-Z -> Current CPU % -> Average CPU % -> Peak CPU %|r", 1, 1, 1, true)
        GameTooltip:Show()
    end
    sortBtn.OnCustomLeave = function() GameTooltip:Hide() end
    UpdateSortBtnVisual()

    local function UpdateCollapseAllButton(topLevel)
        local anyExpanded = AreAnyParentsExpanded(topLevel)
        collapseAllBtn.anyExpanded = anyExpanded
        collapseAllBtn.label:SetText(anyExpanded and "[-] All" or "[+] All")
        AutoSizeToolbarButtons()
    end
    f.UpdateCollapseAllButton = UpdateCollapseAllButton

    local function ShowCollapseAllTooltip(self)
        local anyExpanded = AreAnyParentsExpanded()
        local accentHex = UI.GetActiveAccentHex()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if anyExpanded then
            GameTooltip:SetText("Collapse All Addon Families", 1, 1, 1)
            GameTooltip:AddLine("Collapses all multi-module addon groups (DBM, WeakAuras, DynamicSuite, etc.) into compact single rows.", 0.80, 0.84, 0.88, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cFF" .. accentHex .. "Shift-Click:|r |cFFE2E8F0Click any [-] button or parent title to expand/collapse.|r", 1, 1, 1, true)
        else
            GameTooltip:SetText("Expand All Addon Families", 1, 1, 1)
            GameTooltip:AddLine("Expands all multi-module addon groups to show their child modules.", 0.80, 0.84, 0.88, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cFF" .. accentHex .. "Shift-Click:|r |cFFE2E8F0Click any [+] button or parent title to expand/collapse.|r", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end

    collapseAllBtn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(UI.COLORS.BTN_HOVER.r, UI.COLORS.BTN_HOVER.g, UI.COLORS.BTN_HOVER.b, 0.95)
        self.dsBorder:SetColor(UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.75)
        self.label:SetTextColor(1, 1, 1, 1)
        ShowCollapseAllTooltip(self)
    end)
    collapseAllBtn:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.078, 0.090, 0.122, 0.95)
        self.dsBorder:SetColor(0.141, 0.161, 0.212, 0.90)
        self.label:SetTextColor(0.84, 0.86, 0.90, 1)
        GameTooltip:Hide()
    end)
    collapseAllBtn:SetScript("OnClick", function(self)
        ToggleAllParentsCollapsed()
        UpdateCollapseAllButton()
        if f.scrollChild then RefreshAddonTree(f.scrollChild) end
        if GameTooltip:GetOwner() == self then ShowCollapseAllTooltip(self) end
    end)

    -- Clash-Proof Semantic Accent Styling on the Top Filter Bar (All, Pending, Always, Never)
    local function UpdateFilterChipsDisplay(coreCount, frozenCount, pendingCount)
        if coreCount ~= nil then chipCore.lastCount = coreCount end
        if frozenCount ~= nil then chipFrozen.lastCount = frozenCount end
        if pendingCount ~= nil then chipPending.lastCount = pendingCount end
        local pCnt = chipPending.lastCount or 0
        local cCnt = chipCore.lastCount or 0
        local fCnt = chipFrozen.lastCount or 0

        local ar, ag, ab = UI.GetActiveAccentColor()
        local accentCol  = { r = ar, g = ag, b = ab }
        local emeraldCol = { r = 0.204, g = 0.827, b = 0.600 } -- #34D399
        local goldCol    = { r = 0.980, g = 0.800, b = 0.082 } -- #FACC15
        local cyanCol    = { r = 0.220, g = 0.741, b = 0.973 } -- #38BDF8
        local silverText = { r = 0.720, g = 0.780, b = 0.860, a = 1 }

        local isAllSel     = (securityFilter == "ALL")
        local isPendingSel = (securityFilter == "PENDING")
        local isCoreSel    = (securityFilter == "CORE")
        local isFrozenSel  = (securityFilter == "FROZEN")

        chipAll.label:SetText("All")
        if isPendingSel or pCnt == 0 then
            chipPending.label:SetText(string.format("Pending (%d)", pCnt))
        else
            chipPending.label:SetText(string.format("|cFF34D399Pending (%d)|r", pCnt))
        end
        if isCoreSel then
            chipCore.label:SetText(string.format("Always (%d)", cCnt))
        else
            chipCore.label:SetText(string.format("|cFFFACC15Always (%d)|r", cCnt))
        end
        if isFrozenSel then
            chipFrozen.label:SetText(string.format("Never (%d)", fCnt))
        else
            chipFrozen.label:SetText(string.format("|cFF38BDF8Never (%d)|r", fCnt))
        end

        local function ApplyChipVisual(chip, isSel, selCol, idleTxtCol)
            chip.isSelected = (isSel == true)
            chip.selectedColor = selCol
            chip.keepColoredLabelWhenSelected = false
            chip.idleBgColor = { r = 0.078, g = 0.090, b = 0.122, a = 0.96 } -- #14171F
            chip.idleBorderColor = { r = 0.145, g = 0.165, b = 0.212, a = 0.95 } -- #252A36
            chip.idleTextColor = idleTxtCol or silverText
            ApplyFlatButtonVisual(chip, chip:IsMouseOver())
        end

        ApplyChipVisual(chipAll, isAllSel, accentCol, silverText)
        ApplyChipVisual(chipPending, isPendingSel, emeraldCol, (pCnt > 0) and { r = 0.204, g = 0.827, b = 0.600, a = 1 } or silverText)
        ApplyChipVisual(chipCore, isCoreSel, goldCol, { r = 0.980, g = 0.800, b = 0.082, a = 1 })
        ApplyChipVisual(chipFrozen, isFrozenSel, cyanCol, { r = 0.220, g = 0.741, b = 0.973, a = 1 })
        UpdateSortBtnVisual()
        AutoSizeToolbarButtons()
    end
    f.UpdateFilterChips = UpdateFilterChipsDisplay

    chipAll:SetScript("OnClick", function()
        local changed = (securityFilter ~= "ALL")
        securityFilter = "ALL"; SyncStateToSuite(); UpdateFilterChipsDisplay()
        if changed and f.scrollFrame then
            f.scrollFrame._lastUserScroll = 0
            f.scrollFrame:SetVerticalScroll(0)
        end
        if f.scrollChild then RefreshAddonTree(f.scrollChild, changed) end
    end)
    chipPending:SetScript("OnClick", function()
        local changed = (securityFilter ~= "PENDING")
        securityFilter = "PENDING"; SyncStateToSuite(); UpdateFilterChipsDisplay()
        if changed and f.scrollFrame then
            f.scrollFrame._lastUserScroll = 0
            f.scrollFrame:SetVerticalScroll(0)
        end
        if f.scrollChild then RefreshAddonTree(f.scrollChild, changed) end
    end)
    chipCore:SetScript("OnClick", function()
        local changed = (securityFilter ~= "CORE")
        securityFilter = "CORE"; SyncStateToSuite(); UpdateFilterChipsDisplay()
        if changed and f.scrollFrame then
            f.scrollFrame._lastUserScroll = 0
            f.scrollFrame:SetVerticalScroll(0)
        end
        if f.scrollChild then RefreshAddonTree(f.scrollChild, changed) end
    end)
    chipFrozen:SetScript("OnClick", function()
        local changed = (securityFilter ~= "FROZEN")
        securityFilter = "FROZEN"; SyncStateToSuite(); UpdateFilterChipsDisplay()
        if changed and f.scrollFrame then
            f.scrollFrame._lastUserScroll = 0
            f.scrollFrame:SetVerticalScroll(0)
        end
        if f.scrollChild then RefreshAddonTree(f.scrollChild, changed) end
    end)

    -- Search Box with "Filter addons..." Placeholder & [X] Clear Button
    local searchBoxFrame = CreateFrame("Frame", nil, toolbar)
    searchBoxFrame:SetPoint("LEFT", chipFrozen, "RIGHT", 6, 0)
    searchBoxFrame:SetPoint("RIGHT", toolbar, "RIGHT", 0, 0)
    searchBoxFrame:SetHeight(22)
    searchBoxFrame.bg = UI.SolidTex(searchBoxFrame, "BACKGROUND", 0, 0.03, 0.035, 0.045, 0.95)
    searchBoxFrame.bg:SetAllPoints()
    UI.CreatePixelBorder(searchBoxFrame, 1, 1, 1, 0.14, 2)

    local searchBox = CreateFrame("EditBox", nil, searchBoxFrame)
    searchBox:SetPoint("LEFT", searchBoxFrame, "LEFT", 8, 0)
    searchBox:SetPoint("RIGHT", searchBoxFrame, "RIGHT", -18, 0)
    searchBox:SetHeight(20)
    searchBox:SetAutoFocus(false)
    UI.SetFont(searchBox, 11, "", 1, 1, 1, 0.95)
    searchBox:SetText("")

    local searchPlaceholder = searchBoxFrame:CreateFontString(nil, "OVERLAY")
    searchPlaceholder:SetPoint("LEFT", searchBoxFrame, "LEFT", 8, 0)
    UI.SetFont(searchPlaceholder, 11, "", 0.431, 0.463, 0.506, 1.0)
    searchPlaceholder:SetText("Filter addons...")

    local clearBtn = CreateFrame("Button", nil, searchBoxFrame)
    clearBtn:SetSize(14, 14)
    clearBtn:SetPoint("RIGHT", searchBoxFrame, "RIGHT", -3, 0)
    local clearTxt = clearBtn:CreateFontString(nil, "OVERLAY")
    clearTxt:SetPoint("CENTER")
    UI.SetFont(clearTxt, 11, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 1)
    clearTxt:SetText("X")
    clearBtn:Hide()

    local function UpdateSearchPlaceholder()
        local hasText = searchBox:GetText() and searchBox:GetText() ~= ""
        searchPlaceholder:SetShown(not hasText and not searchBox:HasFocus())
        clearBtn:SetShown(hasText)
    end

    clearBtn:SetScript("OnClick", function()
        local hadFilter = (searchFilter ~= "")
        searchBox:SetText("")
        searchFilter = ""
        searchBox:ClearFocus()
        UpdateSearchPlaceholder()
        if hadFilter then
            if f.scrollFrame then
                f.scrollFrame._lastUserScroll = 0
                f.scrollFrame:SetVerticalScroll(0)
            end
            if f.scrollChild then RefreshAddonTree(f.scrollChild, true) end
        end
    end)

    searchBox:SetScript("OnEditFocusGained", function()
        searchPlaceholder:Hide()
    end)
    searchBox:SetScript("OnEditFocusLost", function()
        UpdateSearchPlaceholder()
    end)
    searchBox:SetScript("OnTextChanged", function(self, userInput)
        local newText = self:GetText() or ""
        UpdateSearchPlaceholder()
        if not userInput then return end
        if newText == searchFilter then return end
        searchFilter = newText
        if f.scrollFrame then
            f.scrollFrame._lastUserScroll = 0
            f.scrollFrame:SetVerticalScroll(0)
        end
        if f.scrollChild then RefreshAddonTree(f.scrollChild, true) end
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        local hadFilter = (searchFilter ~= "")
        self:SetText("")
        searchFilter = ""
        self:ClearFocus()
        UpdateSearchPlaceholder()
        if hadFilter then
            if f.scrollFrame then
                f.scrollFrame._lastUserScroll = 0
                f.scrollFrame:SetVerticalScroll(0)
            end
            if f.scrollChild then RefreshAddonTree(f.scrollChild, true) end
        end
    end)

    ----------------------------------------------------------------------------
    -- LIVE TELEMETRY STRIP (Item #38: Current CPU %, Average CPU %, Peak CPU %, Memory MB + [Load Out of Date])
    ----------------------------------------------------------------------------
    local telemetryStrip = CreateFrame("Frame", nil, dlView)
    telemetryStrip:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -5)
    telemetryStrip:SetPoint("TOPRIGHT", toolbar, "BOTTOMRIGHT", 0, -5)
    telemetryStrip:SetHeight(22)
    telemetryStrip:SetFrameLevel((dlView:GetFrameLevel() or 8) + 2)
    telemetryStrip.bg = UI.SolidTex(telemetryStrip, "BACKGROUND", 0, 0.043, 0.051, 0.071, 0.92)
    telemetryStrip.bg:SetAllPoints()
    UI.CreatePixelBorder(telemetryStrip, 1, 1, 1, 0.07, 2)
    telemetryStrip:Show()
    f.telemetryStrip = telemetryStrip

    local telemetryText = telemetryStrip:CreateFontString(nil, "OVERLAY")
    telemetryText:SetPoint("LEFT", telemetryStrip, "LEFT", 10, 0)
    UI.SetFont(telemetryText, 10, "", 0.80, 0.84, 0.90, 1)
    telemetryStrip.text = telemetryText

    local outOfDateBtn = CreateFlatButton(telemetryStrip, 142, 18, "Load Out of Date: ON", false)
    outOfDateBtn:SetPoint("RIGHT", telemetryStrip, "RIGHT", -4, 0)
    outOfDateBtn.idleBgColor = { r = 0.078, g = 0.090, b = 0.122, a = 0.95 }
    outOfDateBtn.idleBorderColor = { r = 0.141, g = 0.161, b = 0.212, a = 0.90 }

    local function RefreshTelemetryStrip()
        local curPct, avgPct, peakPct, memMB = GetOverallTelemetryStats()
        local hex = UI.GetActiveAccentHex()
        telemetryText:SetText(string.format(
            "|cFF94A3B8AddOn Usage:|r   Current CPU: |cFF%s%.2f%%|r   *   Average CPU: |cFFF3F5F8%.2f%%|r   *   Peak CPU: |cFFF5B82E%.2f%%|r   *   Memory: |cFFF3F5F8%.1f MB|r",
            hex, curPct or 0, avgPct or 0, peakPct or 0, memMB or 0
        ))
        local checkEnabled = true
        if C_AddOns and C_AddOns.IsAddonVersionCheckEnabled then
            checkEnabled = C_AddOns.IsAddonVersionCheckEnabled()
        end
        local loadOOD = not checkEnabled
        outOfDateBtn.label:SetText(loadOOD and "Load Out of Date: ON" or "Load Out of Date: OFF")
        local ar, ag, ab = UI.GetActiveAccentColor()
        outOfDateBtn:SetSelected(loadOOD, { r = ar, g = ag, b = ab })
        local strW = (outOfDateBtn.label and outOfDateBtn.label.GetStringWidth and outOfDateBtn.label:GetStringWidth()) or 116
        outOfDateBtn:SetWidth(math.max(128, math.ceil(strW + 16)))
    end
    f.RefreshTelemetryStrip = RefreshTelemetryStrip

    outOfDateBtn:SetScript("OnClick", function()
        if C_AddOns and C_AddOns.IsAddonVersionCheckEnabled and C_AddOns.SetAddonVersionCheck then
            local curCheck = C_AddOns.IsAddonVersionCheckEnabled()
            C_AddOns.SetAddonVersionCheck(not curCheck)
        end
        RefreshTelemetryStrip()
    end)
    outOfDateBtn.OnCustomEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Load Out of Date AddOns", 1, 1, 1)
        GameTooltip:AddLine("Toggles Blizzard's 'Load out of date AddOns' setting across your account.", 0.82, 0.86, 0.92, true)
        GameTooltip:Show()
    end
    outOfDateBtn.OnCustomLeave = function() GameTooltip:Hide() end

    local telemetryElapsed = 0
    telemetryStrip:SetScript("OnUpdate", function(_, elapsed)
        telemetryElapsed = telemetryElapsed + (elapsed or 0)
        if telemetryElapsed >= 1.5 then
            telemetryElapsed = 0
            RefreshTelemetryStrip()
        end
    end)
    RefreshTelemetryStrip()

    -- Single-Line 3-Column Load Mode Legend Bar (Design System Section 2.3)
    local legendStrip = CreateFrame("Frame", nil, dlView)
    legendStrip:SetPoint("TOPLEFT", telemetryStrip, "BOTTOMLEFT", 0, -4)
    legendStrip:SetPoint("TOPRIGHT", telemetryStrip, "BOTTOMRIGHT", 0, -4)
    legendStrip:SetHeight(22)
    legendStrip:SetFrameLevel((dlView:GetFrameLevel() or 8) + 2)
    legendStrip.bg = UI.SolidTex(legendStrip, "BACKGROUND", 0, 0.024, 0.031, 0.047, 0.96)
    legendStrip.bg:SetAllPoints()
    UI.CreatePixelBorder(legendStrip, 1, 1, 1, 0.07, 2)
    legendStrip:Show()
    f.legendStrip = legendStrip

    do
    local legCol1 = CreateFrame("Frame", nil, legendStrip)
    local legBox1 = CreateFrame("Frame", nil, legCol1)
    legBox1:SetSize(10, 10)
    legBox1:SetPoint("LEFT", legCol1, "LEFT", 10, 0)
    local legBrd1 = UI.CreatePixelBorder(legBox1, 1, 1, 1, 0.95, 1)
    local legDot1 = UI.SolidTex(legBox1, "ARTWORK", 2, 1, 1, 1, 1.0)
    legDot1:SetSize(6, 6)
    legDot1:SetPoint("CENTER", legBox1, "CENTER", 0, 0)
    local legLbl1 = legCol1:CreateFontString(nil, "OVERLAY")
    legLbl1:SetPoint("LEFT", legBox1, "RIGHT", 7, 0)
    legLbl1:SetPoint("RIGHT", legCol1, "RIGHT", -4, 0)
    legLbl1:SetJustifyH("LEFT")
    legLbl1:SetWordWrap(false)
    UI.SetFont(legLbl1, 10, "", 0.82, 0.86, 0.92, 1)
    legLbl1:SetText("|cFFFFFFFFBy Zone (Click Box):|r Active in Zone")

    local legCol2 = CreateFrame("Frame", nil, legendStrip)
    local legBox2 = CreateFrame("Frame", nil, legCol2)
    legBox2:SetSize(10, 10)
    legBox2:SetPoint("LEFT", legCol2, "LEFT", 10, 0)
    UI.CreatePixelBorder(legBox2, UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.95, 1)
    local legDot2 = UI.SolidTex(legBox2, "ARTWORK", 2, UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1.0)
    legDot2:SetSize(6, 6)
    legDot2:SetPoint("CENTER", legBox2, "CENTER", 0, 0)
    local legLbl2 = legCol2:CreateFontString(nil, "OVERLAY")
    legLbl2:SetPoint("LEFT", legBox2, "RIGHT", 7, 0)
    legLbl2:SetPoint("RIGHT", legCol2, "RIGHT", -4, 0)
    legLbl2:SetJustifyH("LEFT")
    legLbl2:SetWordWrap(false)
    UI.SetFont(legLbl2, 10, "", 0.82, 0.86, 0.92, 1)
    legLbl2:SetText("|cFFFFFFFFAlways (L-Click Row):|r All 5 Zones")

    local legCol3 = CreateFrame("Frame", nil, legendStrip)
    local legBox3 = CreateFrame("Frame", nil, legCol3)
    legBox3:SetSize(10, 10)
    legBox3:SetPoint("LEFT", legCol3, "LEFT", 10, 0)
    UI.CreatePixelBorder(legBox3, UI.COLORS.CYAN.r, UI.COLORS.CYAN.g, UI.COLORS.CYAN.b, 0.85, 1)
    local legDash3 = UI.SolidTex(legBox3, "ARTWORK", 2, UI.COLORS.CYAN.r, UI.COLORS.CYAN.g, UI.COLORS.CYAN.b, 1.0)
    legDash3:SetSize(6, 2)
    legDash3:SetPoint("CENTER", legBox3, "CENTER", 0, 0)
    local legLbl3 = legCol3:CreateFontString(nil, "OVERLAY")
    legLbl3:SetPoint("LEFT", legBox3, "RIGHT", 7, 0)
    legLbl3:SetPoint("RIGHT", legCol3, "RIGHT", -4, 0)
    legLbl3:SetJustifyH("LEFT")
    legLbl3:SetWordWrap(false)
    UI.SetFont(legLbl3, 10, "", 0.82, 0.86, 0.92, 1)
    legLbl3:SetText("|cFFFFFFFFNever (R-Click Row):|r Ignores Parent")

    local function LayoutLegendCols()
        local w = legendStrip:GetWidth()
        if not w or w < 200 then
            local dw = (dlView and dlView.GetWidth and dlView:GetWidth()) or 0
            if dw < 200 then
                dw = ((f and f.GetWidth and f:GetWidth()) or 1040) - 206
            end
            w = math.max(500, dw - 30)
        end
        local colW = math.floor(w / 3)
        legCol1:SetPoint("TOPLEFT", legendStrip, "TOPLEFT", 0, 0)
        legCol1:SetSize(colW, 22)
        legCol2:SetPoint("TOPLEFT", legendStrip, "TOPLEFT", colW, 0)
        legCol2:SetSize(colW, 22)
        legCol3:SetPoint("TOPLEFT", legendStrip, "TOPLEFT", colW * 2, 0)
        legCol3:SetPoint("BOTTOMRIGHT", legendStrip, "BOTTOMRIGHT", 0, 0)

        local ar, ag, ab = UI.GetActiveAccentColor()
        legDot1:SetColorTexture(ar, ag, ab, 1.0)
        if legBox1 and legBox1.dsBorder then legBox1.dsBorder:SetColor(ar, ag, ab, 0.95) end
    end
    legendStrip:SetScript("OnSizeChanged", LayoutLegendCols)
    LayoutLegendCols()
    end

    -- Alt Banner + ScrollFrame & Interactive Draggable Vertical Scrollbar
    local altBanner = CreateFrame("Frame", nil, dlView)
    altBanner:SetPoint("TOPLEFT", legendStrip, "BOTTOMLEFT", 0, -4)
    altBanner:SetPoint("TOPRIGHT", legendStrip, "BOTTOMRIGHT", 0, -4)
    altBanner:SetHeight(26)
    altBanner.bg = UI.SolidTex(altBanner, "BACKGROUND", 0, 0.06, 0.10, 0.15, 0.95)
    altBanner.bg:SetAllPoints()
    UI.CreatePixelBorder(altBanner, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.6, 2)
    altBanner:Hide()
    f.altBanner = altBanner

    local altBannerText = altBanner:CreateFontString(nil, "OVERLAY")
    altBannerText:SetPoint("LEFT", altBanner, "LEFT", 10, 0)
    UI.SetFont(altBannerText, 11, "", 1, 1, 1, 1)
    altBanner.text = altBannerText

    local cloneBtn = CreateFlatButton(altBanner, 140, 20, "Clone into Zone", true)
    cloneBtn:SetPoint("RIGHT", altBanner, "RIGHT", -70, 0)

    local clearAltBtn = CreateFlatButton(altBanner, 60, 20, "Clear", false)
    clearAltBtn:SetPoint("RIGHT", altBanner, "RIGHT", -6, 0)

    local scrollFrame = CreateFrame("ScrollFrame", "DynamicLoadScrollFrame", dlView)
    scrollFrame:SetPoint("TOPLEFT", legendStrip, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", dlView, "BOTTOMRIGHT", -16, 8)
    scrollFrame:SetFrameLevel((dlView:GetFrameLevel() or 8) + 2)
    scrollFrame:SetClipsChildren(true)
    scrollFrame:EnableMouseWheel(true)
    if (scrollFrame:GetWidth() or 0) <= 0 or (scrollFrame:GetHeight() or 0) <= 0 then
        local dw = (dlView:GetWidth() or 0) > 200 and dlView:GetWidth() or (((f:GetWidth() or 1040) - 206))
        local dh = (dlView:GetHeight() or 0) > 200 and dlView:GetHeight() or (((f:GetHeight() or 680) - 82))
        scrollFrame:SetSize(math.max(500, dw - 30), math.max(300, dh - 140))
    end
    scrollFrame:Show()
    f.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", "DynamicLoadScrollChild", scrollFrame)
    scrollChild:SetSize(math.max(500, (f:GetWidth() or 1040) - 234), 400)
    scrollChild:SetFrameLevel((scrollFrame:GetFrameLevel() or 10) + 1)
    scrollChild:Show()
    scrollFrame:SetScrollChild(scrollChild)
    f.scrollChild = scrollChild
    scrollChild.Refresh = function() RefreshAddonTree(scrollChild) end

    local scrollTrack = CreateFrame("Frame", nil, dlView)
    scrollTrack:SetWidth(4)
    scrollTrack:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 10, 0)
    scrollTrack:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 10, 0)
    scrollTrack:EnableMouse(true)
    scrollTrack.bg = UI.SolidTex(scrollTrack, "BACKGROUND", 1, 1, 1, 1, 0.06)
    scrollTrack.bg:SetWidth(4)
    scrollTrack.bg:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollTrack.bg:SetPoint("BOTTOM", scrollTrack, "BOTTOM", 0, 0)
    f.scrollTrack = scrollTrack

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack)
    scrollThumb:SetWidth(4)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:EnableMouse(true)
    scrollThumb.tex = UI.SolidTex(scrollThumb, "ARTWORK", 2, 0.38, 0.45, 0.56, 0.85)
    scrollThumb.tex:SetWidth(4)
    scrollThumb.tex:SetPoint("TOP", scrollThumb, "TOP", 0, 0)
    scrollThumb.tex:SetPoint("BOTTOM", scrollThumb, "BOTTOM", 0, 0)
    scrollThumb:Hide()

    local function UpdateThinScrollBar()
        local contentH = scrollChild:GetHeight() or 0
        local visibleH = scrollFrame:GetHeight() or 1
        if visibleH <= 0 then visibleH = 1 end
        local maxScroll = math.max(0, contentH - visibleH)
        if maxScroll <= 1 then
            scrollThumb:Hide()
            return
        end
        scrollThumb:Show()
        scrollThumb.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
        local trackH = scrollTrack:GetHeight() or visibleH
        local ratio = visibleH / contentH
        local thumbH = math.max(28, math.floor(trackH * ratio + 0.5))
        scrollThumb:SetHeight(thumbH)

        local curScroll = scrollFrame:GetVerticalScroll()
        local scrollRatio = (maxScroll > 0) and (curScroll / maxScroll) or 0
        scrollRatio = math.max(0, math.min(1, scrollRatio))
        local maxOffset = trackH - thumbH
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -(scrollRatio * maxOffset))
    end
    f.UpdateThinScrollBar = UpdateThinScrollBar

    scrollFrame:SetScript("OnSizeChanged", function(self, w)
        if w and w > 50 then
            scrollChild:SetWidth(w)
        end
        UpdateThinScrollBar()
    end)

    local function ScrollFromCursor()
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            scrollThumb.isDragging = false
            scrollThumb:SetScript("OnUpdate", nil)
            scrollTrack:SetScript("OnUpdate", nil)
            scrollThumb.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
            return
        end
        local contentH = scrollChild:GetHeight() or 0
        local visibleH = scrollFrame:GetHeight() or 1
        local maxScroll = math.max(0, contentH - visibleH)
        if maxScroll <= 0 then return end

        local eff = scrollTrack:GetEffectiveScale()
        local _, cy = GetCursorPosition()
        cy = cy / eff
        local top = scrollTrack:GetTop()
        local bottom = scrollTrack:GetBottom()
        if top and bottom and top > bottom then
            local trackH = top - bottom
            local thumbH = scrollThumb:GetHeight() or 28
            local usableH = math.max(1, trackH - thumbH)
            local offsetFromTop = (top - cy) - (thumbH * 0.5)
            local ratio = math.max(0, math.min(1, offsetFromTop / usableH))
            local nextScroll = ratio * maxScroll
            scrollFrame._lastUserScroll = nextScroll
            scrollFrame:SetVerticalScroll(nextScroll)
            UpdateThinScrollBar()
        end
    end

    scrollThumb:SetScript("OnEnter", function(self)
        self.tex:SetColorTexture(0.48, 0.55, 0.66, 0.95)
    end)
    scrollThumb:SetScript("OnLeave", function(self)
        if not self.isDragging then
            self.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
        end
    end)
    scrollThumb:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.isDragging = true
            self.tex:SetColorTexture(0.52, 0.60, 0.72, 1.0)
            ScrollFromCursor()
            self:SetScript("OnUpdate", ScrollFromCursor)
        end
    end)
    scrollThumb:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.isDragging = false
            self:SetScript("OnUpdate", nil)
            self.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
        end
    end)
    scrollThumb:SetScript("OnHide", function(self)
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
        self.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
    end)

    scrollTrack:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            ScrollFromCursor()
            self:SetScript("OnUpdate", ScrollFromCursor)
        end
    end)
    scrollTrack:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self:SetScript("OnUpdate", nil)
        end
    end)
    scrollTrack:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        CloseContextMenu()
        local maxScroll = math.max(0, (scrollChild:GetHeight() or 0) - (self:GetHeight() or 0))
        local nextScroll = math.max(0, math.min(maxScroll, self:GetVerticalScroll() - (delta * 48)))
        self._lastUserScroll = nextScroll
        self:SetVerticalScroll(nextScroll)
        UpdateThinScrollBar()
    end)

    cloneBtn:SetScript("OnClick", function()
        if selectedAltKey then
            local count = addonTable.CloneCharacterAddons(selectedAltKey, selectedTabKey)
            if f.scrollChild then RefreshAddonTree(f.scrollChild) end
            local delta = addonTable.StageAddonProfile(selectedTabKey)
            if delta > 0 then addonTable.ShowToast(selectedTabKey, delta) end
        end
    end)

    clearAltBtn:SetScript("OnClick", function()
        selectedAltKey = nil
        if f.RefreshScopePillLabel then f.RefreshScopePillLabel() elseif f.altPillBtn and f.altPillBtn.label then f.altPillBtn.label:SetText("Global") end
        altBanner:Hide()
        scrollFrame:SetPoint("TOPLEFT", legendStrip, "BOTTOMLEFT", 0, -4)
    end)
    end


    local toastPanel = CreateFrame("Frame", nil, dlView)
    toastPanel:SetPoint("TOPLEFT", dlView, "TOPLEFT", 14, -50)
    toastPanel:SetPoint("BOTTOMRIGHT", dlView, "BOTTOMRIGHT", -16, 10)
    toastPanel:SetScript("OnHide", function() if _G.DynamicLoadToastFrame and not _G.DynamicLoadToastFrame.isRealAlert and not _G.DynamicLoadToastFrame.isEditingMode then _G.DynamicLoadToastFrame:Hide() end end)
    toastPanel:Hide()
    f.toastConfigPanel = toastPanel


    do
    -- Embedded Live Preview Stage Box (#080A0E recessed backdrop, 82px height)
    local stageBox = CreateFrame("Frame", nil, toastPanel)
    stageBox:SetPoint("TOPLEFT", toastPanel, "TOPLEFT", 0, 0)
    stageBox:SetPoint("TOPRIGHT", toastPanel, "TOPRIGHT", 0, 0)
    stageBox:SetHeight(42)
    stageBox.bg = UI.SolidTex(stageBox, "BACKGROUND", 0, 0.031, 0.039, 0.055, 0.96)
    stageBox.bg:SetAllPoints()
    UI.CreatePixelBorder(stageBox, 0.118, 0.137, 0.188, 0.95, 2)

    local stageEyeIcon = stageBox:CreateTexture(nil, "OVERLAY", nil, 3)
    stageEyeIcon:SetSize(14, 14)
    stageEyeIcon:SetPoint("LEFT", stageBox, "LEFT", 12, 0)
    stageEyeIcon:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_eye.tga")
    stageEyeIcon:SetVertexColor(UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 1.0)
    stageBox.eyeIcon = stageEyeIcon

    local stageBadge = stageBox:CreateFontString(nil, "OVERLAY")
    stageBadge:SetPoint("LEFT", stageEyeIcon, "RIGHT", 5, 0)
    UI.SetFont(stageBadge, 9, "", 0.65, 0.70, 0.78, 1)
    stageBadge:SetText("LIVE ON-SCREEN ALERT TOAST PREVIEW ACTIVE (SHOWN ABOVE)")

    -- Embedded Preview Toast inside stageBox (never disappears, updates live at 60 FPS)
    local dummyHiddenParent = CreateFrame("Frame"); dummyHiddenParent:Hide(); local stageToast = CreateFrame("Frame", nil, dummyHiddenParent, "BackdropTemplate")
    stageToast:SetSize(330, 56)
    stageToast:SetPoint("CENTER", stageBox, "CENTER", 0, -2)
    stageToast:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })

    local stAccentBar = stageToast:CreateTexture(nil, "OVERLAY")
    stAccentBar:SetPoint("TOPLEFT", stageToast, "TOPLEFT", 1, -1)
    stAccentBar:SetPoint("BOTTOMLEFT", stageToast, "BOTTOMLEFT", 1, 1)
    stAccentBar:SetWidth(3)

    local stIconWrap = CreateFrame("Frame", nil, stageToast)
    stIconWrap:SetSize(24, 24)
    stIconWrap:SetPoint("LEFT", stageToast, "LEFT", 11, 0)
    UI.DrawBrandEmblem(stIconWrap, 22)
    f.stageToastIconWrap = stIconWrap

    local stTitle = stageToast:CreateFontString(nil, "OVERLAY")
    stTitle:SetPoint("TOPLEFT", stIconWrap, "TOPRIGHT", 9, 4)
    stTitle:SetJustifyH("LEFT")
    UI.SetFont(stTitle, 11, "", 1, 1, 1, 1)

    local stSub = stageToast:CreateFontString(nil, "OVERLAY")
    stSub:SetPoint("TOPLEFT", stTitle, "BOTTOMLEFT", 0, -2)
    stSub:SetJustifyH("LEFT")
    UI.SetFont(stSub, 10, "", 0.92, 0.94, 0.97, 1)

    local stHint = stageToast:CreateFontString(nil, "OVERLAY")
    stHint:SetPoint("TOPLEFT", stSub, "BOTTOMLEFT", 0, -2)
    stHint:SetJustifyH("LEFT")
    UI.SetFont(stHint, 9, "", 0.64, 0.68, 0.76, 1)

    local stReloadPill = CreateFlatButton(stageToast, 68, 22, "Reload UI", true)
    stReloadPill:SetPoint("RIGHT", stageToast, "RIGHT", -10, 0)

    local function UpdateEmbeddedStageToast()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local curMode = gTbl.toastDisplayMode or (DynamicLoadDB and DynamicLoadDB.toastDisplayMode) or "DETAILED"
        local curScale = gTbl.toastScale or (DynamicLoadDB and DynamicLoadDB.toastScale) or 1.0
        local curAlpha = gTbl.toastAlpha or (DynamicLoadDB and DynamicLoadDB.toastAlpha) or 0.96
        local ar, ag, ab = UI.GetActiveAccentColor()
        local surf = UI.GetActiveSurfaceColors()
        local profName = (DynamicLoadDB and DynamicLoadDB.profiles and DynamicLoadDB.profiles[selectedTabKey] and DynamicLoadDB.profiles[selectedTabKey].name) or "Outdoor"

        -- Clamp visual scale inside stageBox so it stays neatly framed while showing live proportional scaling
        local visScale = math.max(0.75, math.min(1.18, curScale))
        stageToast:SetScale(visScale)
        stageToast:SetBackdropColor(surf.panel.r, surf.panel.g, surf.panel.b, curAlpha)
        stageToast:SetBackdropBorderColor(ar, ag, ab, 0.90)
        stAccentBar:SetColorTexture(ar, ag, ab, 1.0)
        if stageEyeIcon then
            stageEyeIcon:SetVertexColor(ar, ag, ab, 1.0)
        end
        if stIconWrap.SetAccentColor then
            stIconWrap:SetAccentColor(ar, ag, ab, 1.0)
        end
        stReloadPill:SetSelected(true, { r = ar, g = ag, b = ab })

        if curMode == "COMPACT" then
            stageToast:SetSize(330, 36)
            stTitle:ClearAllPoints()
            stTitle:SetPoint("LEFT", stIconWrap, "RIGHT", 9, 0)
            stTitle:SetText(UI.FormatTwoToneBrand("Load") .. string.format("  |cFFFFFFFF%s: 4 Addons Staged|r", profName))
            stSub:Hide()
            stHint:Hide()
        else
            stageToast:SetSize(340, 56)
            stTitle:ClearAllPoints()
            stTitle:SetPoint("TOPLEFT", stIconWrap, "TOPRIGHT", 9, 4)
            stTitle:SetText(UI.FormatTwoToneBrand("Load") .. string.format("  |cFF94A3B8- %s Profile|r", profName))
            stSub:SetText("|cFFF3F5F84 Addons Staged for Reload|r")
            stHint:SetText(curMode == "EXCEPTIONS_ONLY" and "Exceptions-Only Alert Mode Active" or "Click Reload UI to apply profile")
            stSub:Show()
            stHint:Show()
        end
    end

    -- Standardize stageBox (38px height) with right-aligned [Test Toast] + [Edit HUD] buttons
    stageBox:SetHeight(38)
    stageBadge:SetText("ON-SCREEN ALERT & TELEPORT TOAST HUD")

    local openHudEditBtn
    if UI and type(UI.CreateEditHudButton) == "function" then
        openHudEditBtn = UI.CreateEditHudButton(stageBox, "TOAST")
    elseif _G.DynamicSuite and type(_G.DynamicSuite.CreateEditHudButton) == "function" then
        openHudEditBtn = _G.DynamicSuite.CreateEditHudButton(stageBox, "TOAST")
    else
        openHudEditBtn = CreateFlatButton(stageBox, 86, 22, "Edit HUD", false)
        openHudEditBtn:SetScript("OnClick", function()
            if addonTable.EnterHudEditMode then
                addonTable.EnterHudEditMode("TOAST")
            elseif addonTable.OpenWorkspaceView then
                addonTable.OpenWorkspaceView("EDIT_MODE")
            elseif addonTable.StartToastMove then
                addonTable.StartToastMove()
            end
        end)
    end
    openHudEditBtn:SetPoint("RIGHT", stageBox, "RIGHT", -14, 0)

    local testToastBtn = CreateFlatButton(stageBox, 110, 22, "Test Toast", true)
    testToastBtn:SetPoint("RIGHT", openHudEditBtn, "LEFT", -6, 0)
    local testEyeIcon = testToastBtn:CreateTexture(nil, "OVERLAY", nil, 3)
    testEyeIcon:SetSize(13, 13)
    testEyeIcon:SetPoint("LEFT", testToastBtn, "LEFT", 9, 0)
    testEyeIcon:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_eye.tga")
    testEyeIcon:SetVertexColor(UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 1.0)
    testToastBtn.iconTex = testEyeIcon
    testToastBtn.label:ClearAllPoints()
    testToastBtn.label:SetPoint("LEFT", testEyeIcon, "RIGHT", 5, 0)
    testToastBtn.label:SetPoint("RIGHT", testToastBtn, "RIGHT", -6, 0)
    testToastBtn.label:SetJustifyH("CENTER")
    testToastBtn:SetScript("OnClick", function()
        if addonTable.ShowToast then
            addonTable.ShowToast(selectedTabKey, 4, true)
        end
        local realToast = _G.DynamicLoadToastFrame
        if realToast and realToast:IsShown() then
            if not realToast.previewPulseGroup then
                local pg = realToast:CreateAnimationGroup()
                local fadeOut = pg:CreateAnimation("Alpha")
                fadeOut:SetOrder(1)
                fadeOut:SetDuration(0.18)
                fadeOut:SetFromAlpha(1.0)
                fadeOut:SetToAlpha(0.25)
                local fadeIn = pg:CreateAnimation("Alpha")
                fadeIn:SetOrder(2)
                fadeIn:SetDuration(0.26)
                fadeIn:SetFromAlpha(0.25)
                fadeIn:SetToAlpha(1.0)
                pg:SetScript("OnFinished", function()
                    local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
                    local curAlpha = gTbl.toastOpacity or gTbl.toastAlpha or (DynamicLoadDB and (DynamicLoadDB.toastOpacity or DynamicLoadDB.toastAlpha)) or 0.96
                    realToast:SetAlpha(curAlpha)
                end)
                realToast.previewPulseGroup = pg
            end
            realToast.previewPulseGroup:Stop()
            realToast.previewPulseGroup:Play()
        end
    end)

    -- Row 1: Shared Alert & Teleport Toast Visibility (Hidden / Shown)
    local rowToastVis = CreateSpaciousOptionRow(toastPanel, 1, "Alert & Teleport Toast Visibility", "Choose whether the floating Alert Toast and Dungeon Teleport banner are shown or hidden.")
    local visSegPills = UI.CreateSegmentedPills(rowToastVis, {
        { value = false, label = "Hidden", width = 104 },
        { value = true,  label = "Shown",  width = 104 },
    }, function()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        if gTbl.toastEnabled ~= nil then return gTbl.toastEnabled == true end
        if DynamicLoadDB and DynamicLoadDB.toastEnabled ~= nil then return DynamicLoadDB.toastEnabled == true end
        local tMode = gTbl.toastMode or (DynamicLoadDB and DynamicLoadDB.toastMode)
        if tMode ~= nil then return tMode ~= "OFF" end
        return (gTbl.toastDisplayMode or (DynamicLoadDB and DynamicLoadDB.toastDisplayMode)) ~= "OFF"
    end, function(val)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        local modeVal = val and "ALWAYS" or "OFF"
        local dispVal = val and "DETAILED" or "OFF"
        if gTbl then
            gTbl.toastEnabled = val and true or false
            gTbl.toastMode = modeVal
            if not val or gTbl.toastDisplayMode == "OFF" then gTbl.toastDisplayMode = dispVal end
            gTbl.hudVisibility = gTbl.hudVisibility or {}
            gTbl.hudVisibility["TOAST"] = val and "ALWAYS" or "HIDDEN"
        end
        if DynamicLoadDB then
            DynamicLoadDB.toastEnabled = val and true or false
            DynamicLoadDB.toastMode = modeVal
            if not val or DynamicLoadDB.toastDisplayMode == "OFF" then DynamicLoadDB.toastDisplayMode = dispVal end
        end
        if addonTable.ApplyToastVisuals then addonTable.ApplyToastVisuals() end
        if f.themeView and f.themeView.Refresh and f.themeView:IsShown() then f.themeView.Refresh() end
        if toastPanel.RefreshControls then toastPanel.RefreshControls() end
    end)
    visSegPills:SetPoint("RIGHT", rowToastVis, "RIGHT", -14, 0)
    rowToastVis:BindRightControl(visSegPills)

    -- Row 2: Shared Border Style
    local rowToastBorder = CreateSpaciousOptionRow(toastPanel, 2, "Toast Border Style", "Choose the outer border treatment shared by Alert and Teleport Toasts.")
    local borderSegPills = UI.CreateSegmentedPills(rowToastBorder, {
        { value = "ACCENT", label = "Suite Accent", width = 114 },
        { value = "SUBTLE", label = "Subtle Dark",  width = 114 },
        { value = "NONE",   label = "Borderless",   width = 114 },
    }, function()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local raw = gTbl.toastBorderStyle or (DynamicLoadDB and DynamicLoadDB.toastBorderStyle) or "ACCENT"
        if raw == "DARK" then raw = "SUBTLE" end
        return raw
    end, function(val)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        if gTbl then gTbl.toastBorderStyle = val end
        if DynamicLoadDB then DynamicLoadDB.toastBorderStyle = val end
        if addonTable.ApplyToastVisuals then addonTable.ApplyToastVisuals() end
        if _G.DynamicGroup and _G.DynamicGroup.UpdateTeleportToast then
            pcall(_G.DynamicGroup.UpdateTeleportToast, _G.DynamicGroup, false)
        end
        if toastPanel.RefreshControls then toastPanel.RefreshControls() end
    end)
    borderSegPills:SetPoint("RIGHT", rowToastBorder, "RIGHT", -14, 0)
    rowToastBorder:BindRightControl(borderSegPills)

    -- Row 3: Toast Display Mode (Using Suite-Standard Segmented Pills with Checkmark Icons!)
    local rowToastMode = CreateSpaciousOptionRow(toastPanel, 3, "Toast Display Mode", "Select 3-line detailed cards, 1-line compact pills, or exception-only alerts.")
    local modeSegPills
    modeSegPills = UI.CreateSegmentedPills(rowToastMode, {
        { value = "DETAILED",        label = "Detailed (3-Line)", width = 126 },
        { value = "COMPACT",         label = "Compact (1-Line)",  width = 124 },
        { value = "EXCEPTIONS_ONLY", label = "Exceptions Only",   width = 120 },
    }, function()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        return gTbl.toastDisplayMode or (DynamicLoadDB and DynamicLoadDB.toastDisplayMode) or "DETAILED"
    end, function(val)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        if gTbl then gTbl.toastDisplayMode = val end
        if DynamicLoadDB then DynamicLoadDB.toastDisplayMode = val end
        if addonTable.ApplyToastVisuals then addonTable.ApplyToastVisuals() end
        if toastPanel.RefreshControls then toastPanel.RefreshControls() end
    end)
    modeSegPills:SetPoint("RIGHT", rowToastMode, "RIGHT", -14, 0)
    rowToastMode:BindRightControl(modeSegPills)

    -- Row 4: Toast Scale Slider (60% - 150%)
    local rowToastScale = CreateSpaciousOptionRow(toastPanel, 4, "Toast Scale", "Adjust the visual size of Alert and Teleport Toast banners (60% to 150%).")
    local toastScaleSlider = CreateDSOptionSlider(rowToastScale, 256, 0.60, 1.50, 0.05,
        function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
        function()
            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
            return (gTbl and gTbl.toastScale) or (DynamicLoadDB and DynamicLoadDB.toastScale) or 1.0
        end,
        function(v)
            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
            if gTbl then gTbl.toastScale = v end
            if DynamicLoadDB then DynamicLoadDB.toastScale = v end
            if addonTable.ApplyToastVisuals then addonTable.ApplyToastVisuals() end
            UpdateEmbeddedStageToast()
        end
    )
    toastScaleSlider:SetPoint("RIGHT", rowToastScale, "RIGHT", -14, 0)
    rowToastScale:BindRightControl(toastScaleSlider)

    -- Row 5: Toast Opacity Slider (20% - 100%)
    local rowToastAlpha = CreateSpaciousOptionRow(toastPanel, 5, "Toast Background Opacity", "Control the backdrop transparency of Alert and Teleport Toast banners (20% to 100%).")
    local toastAlphaSlider = CreateDSOptionSlider(rowToastAlpha, 256, 0.20, 1.00, 0.05,
        function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
        function()
            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
            return (gTbl and (gTbl.toastOpacity or gTbl.toastAlpha)) or (DynamicLoadDB and (DynamicLoadDB.toastOpacity or DynamicLoadDB.toastAlpha)) or 0.96
        end,
        function(v)
            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
            if gTbl then
                gTbl.toastOpacity = v
                gTbl.toastAlpha = v
            end
            if DynamicLoadDB then
                DynamicLoadDB.toastOpacity = v
                DynamicLoadDB.toastAlpha = v
            end
            if addonTable.ApplyToastVisuals then addonTable.ApplyToastVisuals() end
            UpdateEmbeddedStageToast()
        end
    )
    toastAlphaSlider:SetPoint("RIGHT", rowToastAlpha, "RIGHT", -14, 0)
    rowToastAlpha:BindRightControl(toastAlphaSlider)

    -- Row 6: Auto-Fade Duration (Using Suite-Standard Segmented Pills with Checkmark Icons!)
    local rowToastDur = CreateSpaciousOptionRow(toastPanel, 6, "Auto-Fade Duration", "How long the Alert Toast remains on screen before smoothly fading out.")
    local durSegPills
    durSegPills = UI.CreateSegmentedPills(rowToastDur, {
        { value = 5,  label = "5s",                 width = 62 },
        { value = 8,  label = "8s (Default)",       width = 104 },
        { value = 12, label = "12s",                width = 62 },
        { value = 0,  label = "Stay Until Clicked", width = 142 },
    }, function()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local d = gTbl.toastDuration
        if d == nil then d = (DynamicLoadDB and DynamicLoadDB.toastDuration) or 8 end
        return d
    end, function(val)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        if gTbl then gTbl.toastDuration = val end
        if DynamicLoadDB then DynamicLoadDB.toastDuration = val end
        if toastPanel.RefreshControls then toastPanel.RefreshControls() end
    end)
    durSegPills:SetPoint("RIGHT", rowToastDur, "RIGHT", -14, 0)
    rowToastDur:BindRightControl(durSegPills)

    -- Row 7: Factory Toast Recovery (Clean 1-Button Row matching DynamicZoom & DynamicFPS)
    local rowToastActions = CreateSpaciousOptionRow(toastPanel, 7, "Factory Toast Recovery", "Restore Alert Toast visibility, border style, scale, opacity, and coordinates to defaults.")
    local resetToastAllBtn = CreateFlatButton(rowToastActions, 168, 26, "Reset Toast Defaults", false)
    resetToastAllBtn:SetPoint("RIGHT", rowToastActions, "RIGHT", -14, 0)
    resetToastAllBtn:SetScript("OnClick", function()
        addonTable.ResetToastSettings()
        if toastPanel.RefreshControls then toastPanel.RefreshControls() end
    end)
    rowToastActions:BindRightControl(resetToastAllBtn)

    toastPanel.RefreshControls = function()
        local ar, ag, ab = UI.GetActiveAccentColor()
        local accentCol = { r = ar, g = ag, b = ab }

        if visSegPills and visSegPills.RefreshValue then visSegPills:RefreshValue() end
        if borderSegPills and borderSegPills.RefreshValue then borderSegPills:RefreshValue() end
        if modeSegPills and modeSegPills.RefreshValue then modeSegPills:RefreshValue() end
        if durSegPills and durSegPills.RefreshValue then durSegPills:RefreshValue() end

        if openHudEditBtn and openHudEditBtn.iconTex then
            openHudEditBtn.iconTex:SetVertexColor(ar, ag, ab, 1.0)
        end
        if testToastBtn and testToastBtn.SetSelected then
            testToastBtn:SetSelected(true, accentCol)
            if testToastBtn.iconTex then
                testToastBtn.iconTex:SetVertexColor(ar, ag, ab, 1.0)
            end
        end
        if toastScaleSlider.RefreshVisual then toastScaleSlider.RefreshVisual() end
        if toastAlphaSlider.RefreshVisual then toastAlphaSlider.RefreshVisual() end
        UpdateEmbeddedStageToast()
        if addonTable.ShowToast then
            addonTable.ShowToast(selectedTabKey, 4, true)
        end
    end
    for _, tc in ipairs({ rowToastVis, rowToastBorder, rowToastMode, rowToastScale, rowToastAlpha, rowToastDur, rowToastActions }) do
        table.insert(f.themeCards, tc)
    end
    end
    if UpdateAllTabVisuals then UpdateAllTabVisuals() end
    if f.UpdateStashButton then f.UpdateStashButton() end
    if f.UpdateFilterChips then f.UpdateFilterChips() end
    if f.RefreshTelemetryStrip then f.RefreshTelemetryStrip() end
    if f.ReflowDlTopTrack then f.ReflowDlTopTrack() end
    if f.scrollChild and RefreshAddonTree then RefreshAddonTree(f.scrollChild) end
end

if addonTable.mainFrame and addonTable.mainFrame.EnsureDynamicLoadWorkspaceMounted then
    addonTable.mainFrame.EnsureDynamicLoadWorkspaceMounted()
end

--------------------------------------------------------------------------------
-- Standalone Fallback Shell (When DynamicLoad is installed WITHOUT DynamicSuite)
--------------------------------------------------------------------------------
if not DynamicSuite._isHubLoaded then
    local standaloneFrame = nil
    function addonTable.CreateMainConfigUI()
        if standaloneFrame then return standaloneFrame end
        UI.RefreshPaletteCache()
        local g = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local w = math.max(820, math.min(1440, g.windowWidth or 920))
        local h = math.max(600, math.min(920,  g.windowHeight or 660))
        local f = CreateFrame("Frame", "DynamicLoadStandaloneFrame", UIParent)
        _G.DynamicLoadMainFrame = _G.DynamicLoadMainFrame or f
        standaloneFrame = f
        addonTable.mainFrame = f
        f:SetSize(w, h)
        f:SetPoint("CENTER")
        f:SetFrameStrata("HIGH")
        f:SetToplevel(true)
        f:SetClampedToScreen(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f.bg = UI.SolidTex(f, "BACKGROUND", 0, UI.COLORS.PANEL_BG.r, UI.COLORS.PANEL_BG.g, UI.COLORS.PANEL_BG.b, 0.99)
        f.bg:SetAllPoints()
        UI.CreatePixelBorder(f, 1, 1, 1, 0.16, 4)
        f.themeCards = {}

        local header = CreateFrame("Frame", nil, f)
        header:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        header:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
        header:SetHeight(44)
        header.bg = UI.SolidTex(header, "BACKGROUND", 1, UI.COLORS.HEADER_BG.r, UI.COLORS.HEADER_BG.g, UI.COLORS.HEADER_BG.b, 1.0)
        header.bg:SetAllPoints()
        local ar, ag, ab = UI.GetActiveAccentColor()
        header.accentTop = UI.SolidTex(header, "OVERLAY", 5, ar, ag, ab, 1)
        header.accentTop:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
        header.accentTop:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
        header.accentTop:SetHeight(2)

        local title = header:CreateFontString(nil, "OVERLAY")
        title:SetPoint("LEFT", header, "LEFT", 16, 0)
        UI.SetFont(title, 15, "", 1, 1, 1, 0.98)
        title:SetText(UI.FormatTwoToneBrand("Load"))

        local closeBtn = CreateFlatButton(header, 26, 26, "X", false)
        closeBtn:SetPoint("RIGHT", header, "RIGHT", -12, 0)
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        local footer = CreateFrame("Frame", nil, f)
        footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        footer:SetHeight(38)
        footer.bg = UI.SolidTex(footer, "BACKGROUND", 1, UI.COLORS.HEADER_BG.r, UI.COLORS.HEADER_BG.g, UI.COLORS.HEADER_BG.b, 1.0)
        footer.bg:SetAllPoints()

        local resetBtn = CreateFlatButton(footer, 134, 24, "Reset DynamicLoad", false)
        resetBtn:SetPoint("LEFT", footer, "LEFT", 14, 0)
        resetBtn:SetScript("OnClick", function()
            addonTable.ResetDynamicLoad()
            if f.scrollChild then RefreshAddonTree(f.scrollChild) end
        end)

        local reloadBtn = CreateFlatButton(footer, 96, 24, "Reload UI", true)
        reloadBtn:SetPoint("RIGHT", footer, "RIGHT", -14, 0)
        reloadBtn:SetScript("OnClick", function()
            if addonTable.ApplyProfile then
                addonTable.ApplyProfile(selectedTabKey, true)
            else
                ReloadUI()
            end
        end)
        f.reloadUIBtn = reloadBtn

        f.UpdateStatusBar = function()
            local delta = addonTable.CalculateAddonDelta and addonTable.CalculateAddonDelta(selectedTabKey) or 0
            if delta > 0 then
                reloadBtn.label:SetText(string.format("Reload (%d)", delta))
            else
                reloadBtn.label:SetText("Reload UI")
            end
        end

        local workspace = CreateFrame("Frame", nil, f)
        workspace:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
        workspace:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
        f.workspace = workspace

        addonTable.MountDynamicLoadWorkspace(f, workspace)
        f:SetScript("OnShow", function()
            if f.UpdateAllTabVisuals then f.UpdateAllTabVisuals() end
            if f.UpdateStatusBar then f.UpdateStatusBar() end
            if f.UpdateStashButton then f.UpdateStashButton() end
            if f.UpdateFilterChips then f.UpdateFilterChips() end
            if f.RefreshTelemetryStrip then f.RefreshTelemetryStrip() end
            if f.scrollChild then RefreshAddonTree(f.scrollChild) end
        end)
        table.insert(UISpecialFrames, "DynamicLoadStandaloneFrame")
        f:Hide()
        return f
    end

    function addonTable.ShowConfigUI()
        if InCombatLockdown and InCombatLockdown() then
            print("|cFF38BDF8DynamicLoad|r: Cannot open configuration window while in combat.")
            return nil
        end
        local f = addonTable.CreateMainConfigUI()
        f:Show()
        return f
    end

    function addonTable.HideConfigUI()
        if standaloneFrame then standaloneFrame:Hide() end
    end

    function addonTable.ToggleConfigUI(forceShow)
        if InCombatLockdown and InCombatLockdown() then
            if forceShow ~= false and standaloneFrame and standaloneFrame:IsShown() then
                standaloneFrame:Hide()
                return
            end
            print("|cFF38BDF8DynamicLoad|r: Cannot open configuration window while in combat.")
            return
        end
        local f = addonTable.CreateMainConfigUI()
        if forceShow == true then f:Show()
        elseif forceShow == false then f:Hide()
        else f:SetShown(not f:IsShown()) end
    end
    addonTable.ToggleUI = addonTable.ToggleConfigUI
end

--------------------------------------------------------------------------------
-- Register DynamicLoad into DynamicSuite Module Registry
--------------------------------------------------------------------------------
do
    local dlModuleDescriptor = {
        name = "DynamicLoad",
        addonName = "DynamicLoad",
        title = "DynamicLoad",
        subtitle = "Zone Addon Profiles",
        slash = "/dl",
        order = 10,
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_load.tga",
        version = addonTable.ADDON_VERSION or "2.1.2",
        description = "Context-aware addon profile management with parent-child grouping & 3-state security matrix",
        CHANGELOG = DynamicSuite.Changelogs and DynamicSuite.Changelogs["DynamicLoad"] and DynamicSuite.Changelogs["DynamicLoad"].entries or addonTable.CHANGELOG,
        Open = function(...) if addonTable.ShowConfigUI then return addonTable.ShowConfigUI(...) end end,
        Show = function(...) if addonTable.ShowConfigUI then return addonTable.ShowConfigUI(...) end end,
        Hide = function(...) if addonTable.HideConfigUI then return addonTable.HideConfigUI(...) end end,
        ToggleUI = function(...) if addonTable.ToggleConfigUI then return addonTable.ToggleConfigUI(...) end end,
        ResetModule = function(...) if addonTable.ResetDynamicLoad then return addonTable.ResetDynamicLoad(...) end end,
        ResetModuleDefaults = function(...) if addonTable.ResetDynamicLoad then return addonTable.ResetDynamicLoad(...) end end,
        ResetDefaults = function(...) if addonTable.ResetDynamicLoad then return addonTable.ResetDynamicLoad(...) end end,
        Reset = function(...) if addonTable.ResetDynamicLoad then return addonTable.ResetDynamicLoad(...) end end,
        SelectSubTab = function(selfOrIdx, maybeIdx)
            local target = (type(selfOrIdx) == "table") and maybeIdx or selfOrIdx
            if addonTable.SelectSubTab then
                return addonTable.SelectSubTab(target or 1)
            elseif addonTable.mainFrame and addonTable.mainFrame.SelectDynamicLoadSubTab then
                return addonTable.mainFrame.SelectDynamicLoadSubTab(target or 1)
            end
        end,
        SelectTab = function(selfOrIdx, maybeIdx)
            local target = (type(selfOrIdx) == "table") and maybeIdx or selfOrIdx
            if addonTable.SelectSubTab then
                return addonTable.SelectSubTab(target or 1)
            elseif addonTable.mainFrame and addonTable.mainFrame.SelectDynamicLoadSubTab then
                return addonTable.mainFrame.SelectDynamicLoadSubTab(target or 1)
            end
        end,
        EvaluateEnvironment = addonTable.EvaluateCurrentEnvironment,
        RenderEmbedded = function(_, hostFrame)
            if addonTable.mainFrame and addonTable.mainFrame.EnsureDynamicLoadWorkspaceMounted then
                addonTable.mainFrame.EnsureDynamicLoadWorkspaceMounted()
            elseif hostFrame and not hostFrame._dlMounted then
                hostFrame._dlMounted = true
                addonTable.MountDynamicLoadWorkspace(addonTable.mainFrame or hostFrame, hostFrame)
            end
        end,
        ApplyTheme = function()
            if addonTable.RefreshDisableCoreModalTheme then addonTable.RefreshDisableCoreModalTheme() end
            if addonTable.ApplySuiteThemeAndGeometry then addonTable.ApplySuiteThemeAndGeometry() end
        end,
        ApplyThemeToUI = function()
            if addonTable.RefreshDisableCoreModalTheme then addonTable.RefreshDisableCoreModalTheme() end
            if addonTable.ApplySuiteThemeAndGeometry then addonTable.ApplySuiteThemeAndGeometry() end
        end,
        RefreshTheme = function()
            if addonTable.RefreshDisableCoreModalTheme then addonTable.RefreshDisableCoreModalTheme() end
            if addonTable.ApplySuiteThemeAndGeometry then addonTable.ApplySuiteThemeAndGeometry() end
        end,
        GetStatusText = function()
            local isOverride = (addonTable.IsManualOverrideActive and addonTable.IsManualOverrideActive()) or false
            local loadedProf = (addonTable.GetLoadedProfile and addonTable.GetLoadedProfile()) or (DynamicLoadDB and DynamicLoadDB.loadedProfile) or (DynamicLoadDB and DynamicLoadDB.activeProfile) or "outdoor"
            local envDetail = (addonTable.GetEnvironmentDetail and addonTable.GetEnvironmentDetail()) or "Outdoor"
            local deltaCount = (addonTable.CalculateAddonDelta and addonTable.CalculateAddonDelta(selectedTabKey)) or 0
            local profName = (DynamicLoadDB and DynamicLoadDB.profiles and DynamicLoadDB.profiles[loadedProf] and DynamicLoadDB.profiles[loadedProf].name) or loadedProf
            local stagedStr = (deltaCount > 0) and string.format("|cFFF5B82E%d Pending Reload|r", deltaCount) or "|cFF22C55EIn Sync|r"
            if isOverride then
                return string.format("|cFF22C55E|TInterface\\Buttons\\WHITE8X8:6:6:0:0:8:8:0:8:0:8:34:197:94|t Loaded:|r |cFFFFFFFF%s|r |cFFF5B82E[Manual]|r   |   |cFF38BDF8|TInterface\\Buttons\\WHITE8X8:6:6:0:0:8:8:0:8:0:8:56:189:248|t Location:|r |cFFFFFFFF%s|r   |   State: %s", profName, envDetail, stagedStr)
            else
                return string.format("|cFF22C55E|TInterface\\Buttons\\WHITE8X8:6:6:0:0:8:8:0:8:0:8:34:197:94|t Loaded:|r |cFFFFFFFF%s [Auto]|r   |   |cFF38BDF8|TInterface\\Buttons\\WHITE8X8:6:6:0:0:8:8:0:8:0:8:56:189:248|t Location:|r |cFFFFFFFF%s|r   |   State: %s", profName, envDetail, stagedStr)
            end
        end,
    }

    if DynamicSuite.RegisterModule then
        DynamicSuite:RegisterModule("load", dlModuleDescriptor)
        DynamicSuite:RegisterModule("DynamicLoad", dlModuleDescriptor)
    else
        DynamicSuite.modules = DynamicSuite.modules or {}
        DynamicSuite.modules["load"] = dlModuleDescriptor
        DynamicSuite.modules["DynamicLoad"] = dlModuleDescriptor
    end
end
end
