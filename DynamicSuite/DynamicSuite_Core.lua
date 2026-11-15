--[[
    DynamicSuite - DynamicSuite_Core.lua
    Central Obsidian Hub, Theme & Font Studio, Conflict Scanner & Module Registry for World of Warcraft (Retail 12.1.5+)
    Zero external dependencies. High-performance, GC-lean event orchestration.
]]

local addonName, rawAddonTable = ...
local ADDON_FOLDER = (type(addonName) == "string" and addonName ~= "") and addonName or "DynamicSuite"

-- Global DynamicSuite Hub Namespace & Shared Bridge Table
_G.DynamicSuite = _G.DynamicSuite or {}
local DynamicSuite = _G.DynamicSuite
DynamicSuite._sharedAddonTable = DynamicSuite._sharedAddonTable or rawAddonTable or {}
local addonTable = DynamicSuite._sharedAddonTable
DynamicSuite._isHubLoaded = true

local ADDON_TITLE = "|cFFCBD5E1DynamicSuite|r"

local function ResolveAddonVersion(folderName, fallback)
    local fb = fallback or "2.1.1"
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

local ADDON_VERSION = ResolveAddonVersion(ADDON_FOLDER, "2.1.1")
addonTable.ADDON_VERSION = ADDON_VERSION
addonTable.ResolveAddonVersion = ResolveAddonVersion
addonTable.CompareSemVer = CompareSemVer
DynamicSuite.version = ADDON_VERSION
DynamicSuite.ResolveAddonVersion = ResolveAddonVersion
DynamicSuite.CompareSemVer = CompareSemVer
DynamicSuite.modules = DynamicSuite.modules or {}
DynamicSuite.Changelogs = DynamicSuite.Changelogs or {}

DynamicSuite.Changelogs["DynamicSuite"] = {
    version = ADDON_VERSION,
    date = "15/11/2026",
    entries = {
        { type = "FIX",     text = "Release v2.1.1 - HUD Edit Mode Mover Visibility, Prep Bar Drag Shield & First-Open Left Rail Fix (15/11/2026): Fixed isHudEditModeActive lexical scoping in DynamicSuite_UI.lua so all Shown HUDs (Alert Toast, Prep Bar, Focus Icons, World Flares, Raid Buffs, and Chat Frame) immediately render their live preview and interactive mover overlay upon entering HUD Edit Mode (ignoring solo/event conditions while keeping Off/Hidden HUDs hidden until selected or opened via [Edit HUD]); split DynamicPrep's SetBarEditMode and SetBuffsEditMode states and disabled child segment/button mouse capture during HUD Edit Mode so Prep Bar and Raid Buffs drag smoothly across their entire width; and replaced the Left Suite Rail's 0x0 hidden ScrollFrame clip rect with a direct-sized frame container so the Left Suite Rail renders immediately on the very first /ds open." },
        { type = "FIX",     text = "Release v2.1.0 - World Flare Hardware Keybinds & Unified Compact HUD Edit Mode (15/11/2026): Fixed World Flare cycle/clear hardware keybinds (F4/F5) in and out of combat, wired instant header telemetry and sub-tab title updates on keybind changes, redesigned the HUD Edit Mode dock into a compact 560x74 draggable inspector with 60px off-screen fail-safe clamping, hid disabled HUD movers by default, and standardised dark-obsidian [Edit HUD] buttons across all modules." },
        { type = "FIX",     text = "Release v1.9.9 - Canonical UIParent-Local HUD Coordinate Contract, Custom Dark-Obsidian Coexistence Modal & Unified HUD Edit Mode (14/11/2026): Enforced a single canonical UIParent-local coordinate contract for TargetBar and FlareBar (storing unscaled UIParent CENTER offsets and dividing by barScale strictly inside DM:SetBarCenterPoint after applying SetScale/SetSize and before SetClampedToScreen(true), removing destructive early-load DB writes in ApplyHUDPosition, and preserving 100% top/bottom/corner edge parity across /reload at 0.70, 1.00, and 1.30 scales); replaced Blizzard's StaticPopup with a custom dark-obsidian coexistence reload modal (DynamicSuiteMarkerConflictModal / ShowMarkerConflictReloadModal with #0B0D12 0.96 alpha backdrop, 1px dark slate border, Blaze Orange #F97316 accent bar, flat Reload UI / Later buttons, ESC dismissal, and combat deferral) across DynamicSuite and standalone DynamicMarker; suppressed DynamicMarker's standalone HUD Edit Mode window inside DynamicSuite; and fixed Reset HUD Positions bounds across Suite and standalone modes." },
        { type = "FIX",     text = "Release v1.9.8 - HUD Edit Edge-Drag Persistence & Flush (0, 0) DynamicChat Clamping (14/11/2026): Fixed Target Icon Bar and World Flare Bar snapping back after dragging to any screen edge (including 70%/75% scaled bars) by syncing bar scale and vertical/horizontal dimensions prior to clamping, canonicalising anchors to CENTER, clearing drag flags before final Edit Mode saves, and enforcing SetClampedToScreen(false) across Suite and standalone DynamicMarker; and fixed DynamicChat's ~30px bottom gap by setting ChatFrame1:SetClampedToScreen(false) whenever managed, measuring only the visible chat container via GetVisibleContainerExtents(), and canonicalising CHAT to BOTTOMLEFT outer-container coordinates so X = 0, Y = 0 sits flush bottom-left across Edit Mode toggles, UI scale events, and /reload." },
        { type = "FEATURE", text = "Release v1.9.7 - Official CurseForge Dual-Release Pipeline (DynamicSuite Project 1804382 + DynamicMarker 1331651) & Hardened Coexistence (14/11/2026): Connected full DynamicSuite (CurseForge Project ID 1804382) alongside standalone DynamicMarker (Project ID 1331651) in our automated release workflow, replaced legacy URL placeholder labels on Support panels and public docs with the live CurseForge links, authored code-accurate CurseForge storefront docs, and hardened ShouldYieldToOtherInstall dual-mode version yielding across all 8 modules regardless of load order." },
        { type = "FIX",     text = "HUD Edit Scale-Aware Clamping, Magnetic Edge/Bar Snapping & Reset HUD Positions Failsafe (14/11/2026): Unified uScale/UIParent drag math for 1:1 cursor tracking at all scales (60%-150%), added magnetic screen-edge/centre (11px) and cross-HUD bar-to-bar (9px) snapping with live visual alignment guide lines and Shift-to-bypass micro-adjustments, enforced screen-boundary clamping across all saves/scales/orientations/login/UI_SCALE_CHANGED, and added Reset HUD Positions in ESC -> Options -> AddOns plus /ds resethud and /dm resethud (/fm resethud) with combat-lockdown deferral." },
        { type = "FIX",     text = "Release v1.9.6 - DynamicBags Bank/Guild Bank & Merge Hardening + Suite/Standalone Changelog Parity (14/11/2026): Eliminated post-/reload Bank/Guild Bank panel flashes with SetScale suppression and GUILDBANKFRAME_OPENED handling, preserved unqueried Guild Bank tab snapshots across sessions while reflecting live withdrawals down to 0 items, fixed strict weak ordering in Sort: A-Z when uncached items appear, verified compatible bag/bank slot placement across Reagent bags and Guild Bank tab permissions, synchronised Tab 3 Auto-Repair/Auto-Sell keys, guarded fast auto-loot bursts, updated DynamicBags Smart Search entries, and upgraded standalone DynamicMarker's Changelog modal to stream live entries dynamically." },
        { type = "UI",      text = "Standalone DynamicMarker Dock Parity, Copyable Support Links & DynamicSuite CurseForge URL (14/11/2026): Added the [Reload UI] button and persisted Opacity (50%-100%) and Scale (80%-120%) sliders to standalone DynamicMarker's bottom-right dock (left of the // resize grip, stored in DynamicMarkerDB without touching DynamicSuiteDB), upgraded standalone DynamicMarker's Support modal to read-only click-to-highlight Ctrl+C EditBoxes (Ko-fi, CurseForge /addons/dynamicmarker, and Email) with Escape-to-close, and updated DynamicSuite's Support view CurseForge link to https://www.curseforge.com/wow/addons/dynamicsuite." },
        { type = "FIX",     text = "First-Open ESC > Options > AddOns Blank Shell & Left-Rail Fix (14/11/2026): Called RefreshLeftRailLayout() on initial CreateMainConfigUI() construction, routed ApplySuiteThemeAndGeometry() through RefreshLeftRailLayout() and all active workspace view refreshes, added a guarded C_Timer.After(0, ...) post-layout refresh + Raise() in DynamicSuiteMainFrame:OnShow and standalone DynamicMarkerSuiteWindow:OnShow (with initial f:Hide() so the first Show() always fires OnShow), and hardened HideSettingsPanelSafe() in both DynamicSuite_UI.lua and DynamicMarker.lua (alongside ShowConfigUI() and Settings canvas OnShow theme sync) so Blizzard's SettingsPanel and GameMenuFrame cleanly close and yield behind the addon window on the very first open." },
        { type = "FEATURE", text = "Encapsulated DynamicMarker HUD Edit Mode, FocusMarkerDB Migration Bridge & Automated CurseForge Packaging (14/11/2026): Moved DynamicMarker's Icon Bar and Flare Bar movers strictly inside DynamicMarker (with Suite '+ HUD' callback registration and clean removal of legacy FocusMarker/DynamicMarker mover lookups in DynamicSuite_UI), added the idempotent one-time FocusMarkerDB -> DynamicMarkerDB migration bridge, upgraded standalone DynamicMarker with Signature Amber/Gold (#F5B82E) theming, unloaded-module left-rail cleanup, 1:1 bottom-left SUITE STUDIO & TOOLS sidebar parity, DIALOG-dimmed Guided Setup modal with ESC isolation, [Off] dimmed rail rows in full DynamicSuite mode, and combat-safe ESC > Options > AddOns launcher cards, added -StageStandalone / -KeepStandalone QA deployment flags, and initialised Git source control plus BigWigsMods/packager GitHub Actions automation (.pkgmeta for DynamicSuite and .pkgmeta-dynamicmarker scoped strictly to standalone CurseForge Project ID 1331651)." },
        { type = "FIX",     text = "Removed Auto-Yield ('Keep Both') & Enforced Mutual-Exclusion Conflict Scanner (13/11/2026): Permanently removed all Auto-Yield / Keep Both logic, saved flags, and UI buttons across the suite. Every conflict card now presents strictly two mutually exclusive buttons ('Use Dynamic[Module] Only' and 'Use [Addon] Only') and shows [! Conflict Active] until resolved and reloaded. Added EllesmereUIBags / EllesmereUI_Bags detection for DynamicBags, prevented stale DynamicSuiteDB flags from hiding active conflicts, disabled ElvUI Bags/Chat sub-modules via E.private when choosing DynamicSuite, and prevented DynamicChat from ever yielding to EllesmereUI Chat or ElvUI Chat." },
        { type = "FIX",     text = "Universal 'Never' ('FROZEN') Persistence Across All Addons & Registry-Driven Conflict Resolution (12/11/2026): Normalised all security and zone assignment operations to canonical folder names (C_AddOns.GetAddOnInfo); made SetAddonFrozen(name, true) atomically persist 'FROZEN' across DynamicLoadDB/globalData/charData, wipe all 5 zone tables, and call C_AddOns.DisableAddOn; merged DynamicLoadDB root and globalData security tables in SyncScopeBindings() and replaced table re-allocation in RestoreStash() with in-place wipe(); retired RecoverEllesmereUIState(); protected individual child 'FROZEN' / 'LOCKED' states from parent cascades; added EnforceFrozenAddonsDisabled() + a C_AddOns.EnableAddOn runtime guard; made Auto-Yield 100% read-only; treated unloaded or 'FROZEN' external addons as inactive so DynamicChat and peer modules run their full feature set once a conflicting addon is set to Never; and added a 1-click [Use Dynamic] -> [Reload UI Now] button on soft Auto-Yield banners." },
        { type = "FEATURE", text = "External Addon Conflict Detector & 2-Tier Auto-Yield Engine (12/11/2026): Added a central curated conflict registry across all 8 DynamicSuite modules (DynamicBags, DynamicChat, DynamicPrep, DynamicGroup, DynamicMarker, DynamicZoom, DynamicFPS, DynamicLoad), pcall-protected Smart Sub-Module Detection for ElvUI (ElvUI[1].private.bags.enable / ElvUI[1].private.chat.enable) and Leatrix_Plus (_G.LeaPlusDB), 2-tier HARD warning banners and SOFT auto-yield info notes ('Auto-Yield Active: Handing gossip/camera control to DialogueUI') at the top of each module workspace, one-time non-spam login alerts, and the '/ds conflicts' diagnostic command indexed in Global Smart Search." },
        { type = "FEATURE", text = "Unified v1.3.0 Master Workspace, Single-Source .toc Metadata & Version-Aware Duplicate-Install Guard (11/11/2026): Consolidated the master editable workspace into D:\\DriveSync\\DynamicSuite with 1:1 deployment to WoW Retail and Google Drive sync, replaced hardcoded version strings across DynamicSuite and all 8 feature modules with live C_AddOns.GetAddOnMetadata(ADDON_FOLDER, 'Version') resolution so all Top Headers, Standalone headers, and in-game Changelog tabs stay in lockstep automatically, and upgraded the dual-mode duplicate-install guard with semantic version comparison (CompareSemVer) so the newer version always takes priority." },
        { type = "FEATURE", text = "Single-Entry Suite Consolidation & Dual-Mode Module Architecture: Consolidated DynamicSuite and all 8 feature modules (DynamicLoad, DynamicPrep, DynamicMarker, DynamicZoom, DynamicFPS, DynamicGroup, DynamicBags, DynamicChat) into a single WoW AddOn List entry (DynamicSuite.toc + Modules\\Dynamic*.lua) with all 9 SavedVariables preserved, unified superset Media\\Icons\\ and Fonts\\ assets, private per-module namespaces, dynamic ADDON_FOLDER asset paths, dual ADDON_LOADED guards, and soft Left-Rail module enable/disable via DynamicSuiteDB.global.disabledModules." },
        { type = "FIX",     text = "Isolated HUD Edit Mode state carrier for ChatFrame1 (GetHudStateCarrier in DynamicSuite_UI.lua stores _dsEditModeActive, _dsDragging, and _dsDragShield on DynamicChat instead of ChatFrame1 for 0.00% ChatFrame1 table taint) and synchronised selectedTabKey with DynamicLoadDB.stagedProfile." },
        { type = "FIX",     text = "Hardened DynamicSuite / DynamicLoad namespace coexistence, peer module reset host routing, HUD Edit Mode Toast state cleanup, and zero-allocation NormalizeEmbeddedSubDrawers regions iteration." },
        { type = "FIX",     text = "Labyrinth Delve Toast Anti-Spam Gate (DynamicLoad - 11/11/2026): Restricted automatic DynamicLoadToastFrame popups strictly to real post-loading-screen transitions (LOADING_SCREEN_ENABLED / LOADING_SCREEN_DISABLED + PLAYER_ENTERING_WORLD with a deduplicated 0.65s settle timer and per-load session latch), preventing seamless chamber crossings (ZONE_CHANGED_NEW_AREA, ZONE_CHANGED, ZONE_CHANGED_INDOORS, SCENARIO_UPDATE) or post-combat PLAYER_REGEN_ENABLED flushes from re-popping dismissed Toasts inside Labyrinth Delves." },
        { type = "FIX",     text = "Smart Search Stabilisation, Core/UI Field Alignment & Shared Bridge Hardening (11/11/2026): Resolved the DynamicSuite_UI.lua:10191 nil crash on /ds (replacing non-existent CreateCardContainer and Create1PxBorder calls with UI.CreatePixelBorder and fixing UI.SolidTex factory calls across EnsureSearchHighlightFrame, resultsTrack, resultsThumb, and GetOrCreateResultCard), aligned NormalizeSearchEntry and ScoreSearchEntry fields (_kwLower, _tabLower, _catLower, seedOrder, categoryLabel, breadcrumb, viewKey, targetTitle, and MODULE_ADDON_MAP), wired Enter-key TriggerTopResult and collapsed sub-drawer auto-expansion, protected addonTable.GetSuiteGlobal and addonTable.PopulateBrandLogo in DynamicLoad_Core.lua, and verified all 9 suite addons in a headless Lua 5.1 WoW runtime harness." },
        { type = "FEATURE", text = "Global Smart Search, Synonym/Intent Index & 1-Click Jump-and-Highlight Router (Pass 2): Added the Left Rail 'Search all features...' bar (/ds search <query> or /ds find <query>) and Global Feature Finder workspace across DynamicSuite and all 8 peer modules (198 indexed settings with plain-English problem/intent synonyms, 6 live-counted category filter pills, installation-aware filtering for standalone installs, auto-enable for disabled modules, sub-drawer auto-expansion, auto-scroll, and a 2.2s Suite Accent highlight pulse)." },
        { type = "FIX",     text = "Cross-TOC Namespace Bridge & Lua 5.1 AST Hardening (DynamicSuite / DynamicLoad): Fixed syntax errors in DynamicLoad_Core.lua:2178 and DynamicSuite_UI.lua:8748, forward-declared ApplyEnvironmentContext in DynamicLoad_Core.lua, added DynamicSuite to SUITE_MODULES auto-enable protection, updated all DynamicSuite font/icon paths to Interface\\AddOns\\DynamicSuite\\..., and verified all 11 Lua files with a strict Lua 5.1 AST & scope compiler." },
        { type = "FEATURE", text = "Decoupled DynamicSuite Hub & Standalone Module Architecture: Split DynamicSuite (Hub Shell, Theme & Font Studio, Guided Setup, Conflict Scanner, Changelog Hub, HUD Edit Mode) from DynamicLoad (Zone Addon Profile Manager), added extensible DynamicSuite:RegisterModule(key, descriptor) support for 9+ future modules with a scrollable Left Suite Rail, and enforced Dynamic*.lua naming across all 9 suite folders." },
        { type = "FEATURE", text = "Game Menu & Blizzard Options Shortcuts + Scrollable Theme & Font Studio: Added 'DynamicSuite' and 'DynamicSuite HUD' shortcut buttons to the Esc Game Menu positioned cleanly above Log Out / Return to Game, added 'Open DynamicSuite HUD (/ds hud)' to Blizzard Options -> AddOns -> DynamicSuite, wrapped Theme & Font Studio in a smooth Obsidian ScrollFrame with bordered 'SURFACE, TYPOGRAPHY & VISUAL SYNC' and 'GAME MENU & OPTIONS SHORTCUTS' L-bracket sections, and added live toggles for Game Menu buttons and Blizzard AddOn List replacement." },
        { type = "FIX",     text = "Failsafe Esc = [X] Exit for [+ HUD] Edit Mode: Replaced conditional f._minimizedForHudDrag check in DynamicSuiteEditModeModal:OnHide with unconditional isHudEditModeActive + isExitingHudEditMode state tracking, added an OnKeyDown ESCAPE listener and a GameMenuFrame:OnShow failsafe hook, and explicitly cleared all grid overlays and HUD drag shields so pressing Esc always exits HUD Edit Mode cleanly." },
        { type = "FEATURE", text = "Tactile Drag-and-Drop & Horizontal Side-by-Side Up/Down Arrows on Left Suite Rail: Added 13x14px side-by-side chevron buttons (icon_chevron_up.tga / icon_chevron_down.tga) and live drag-and-drop reordering with a floating ghost card and [Reset Sort] button while keeping DynamicLoad permanently anchored at index 1." },
        { type = "FIX",     text = "Composite Screen Clamping for 'Chat Frame' ('CHAT') in [+ HUD] Edit Mode: Updated ComputeSnappedAndClampedHudCoords, AttachOrUpdateDragShield, and the bottom-right resize grip to enforce composite screen margins (-38, 10, 40/68, -40/-10) so the 34px Left Utility Rail, 24px Top Tab Bar, and Top/Bottom EditBox never clip off-screen." },
        { type = "FIX",     text = "Protected DynamicChat as a [Suite Core] module across all 5 zone profiles (EnforceProtectedSuiteModules), auto-enabling it on load unless explicitly disabled via the Left Suite Rail switch." },
        { type = "FEATURE", text = "Registered DynamicChat's 2-Tier Chat Conflict Scanner (Chattynator, Prat-3.0, BasicChatMods, Chatter, LS: Glass, Glass, PhanxChat, DejaChat + WIM, Leatrix Plus, ElvUI, WindTools shared-hook auto-yield) into Guided Setup & Left Rail conflict badge." },
        { type = "UI",      text = "Unified load-state terminology to 'By Zone', 'Always', and 'Never' across all rows, suffix tags, popovers, filter pills, legends, and tooltips (with [Suite Core] / [Suite Protected] for DynamicSuite modules)." },
        { type = "UI",      text = "Styled Top Filter Bar pills (All, Pending, Always, Never) with clash-proof semantic text coloring on dark #14171F backgrounds when unselected, and filled semantic backgrounds with white text when selected." },
        { type = "FIX",     text = "Removed stray 'Left-Click Row / [-]: Expand or Collapse Group' instruction from individual addon mouseover tooltips so it only displays on collapsible parent category headers." },
        { type = "FIX",     text = "Disentangled physical zone location from loaded addon profile (DynamicLoadDB.loadedProfile and DynamicLoadDB.manualOverride), protecting manual profile activations across reloads." },
        { type = "FIX",     text = "Resolved /ds and /dl client freeze by eliminating mutual recursion in ApplySuiteThemeAndGeometry, caching font path resolution, removing redundant SetText reflow loops, and fixing unescaped Lua pattern matching in BuildAddonHierarchy." },
        { type = "FIX",     text = "Hardened UI.CreatePixelBorder with a CreateTexture safety guard and converted legendStrip swatch samples to Frame containers so CreateMainConfigUI never aborts mid-construction." },
        { type = "UI",      text = "Design System standardisation (DESIGN_SYSTEM.md): AUTO_CLASS accent, MIDNIGHT_BLACK surface, 0.42 pill fill alpha, UI.CreateSquareCheckbox, UI.CreateSectionHeader L-brackets, 3-button inline load mode pills, 5-zone full-width top bevel, and geometric close buttons." },
        { type = "FEATURE", text = "Native Suite Changelog & Master Registry covering all suite modules with colour-coded badges, unread alert tracking, and 1-click workspace navigation." },
        { type = "FEATURE", text = "7-Step Interactive Guided Setup Wizard with 1-click conflict resolution, Smart Addon Scan, and hardware/spec preset cards." },
        { type = "FEATURE", text = "Unified Top-Right Scope Switcher & [+ HUD] Header Parity matched 1:1 with floating bar and HUD Edit Mode." },
        { type = "FIX",     text = "Theme & Font Studio dropdowns, swatches, elevated dropdown borders, and EUI sync hardening." },
    },
}
DynamicSuite.Changelogs["suite"] = DynamicSuite.Changelogs["DynamicSuite"]
if DynamicSuite.Changelogs["DynamicLoad"] then
    DynamicSuite.Changelogs["load"] = DynamicSuite.Changelogs["DynamicLoad"]
end
addonTable.CHANGELOG = DynamicSuite.Changelogs["DynamicSuite"].entries
local isDynamicLoadOnDisk = false
if C_AddOns and C_AddOns.GetAddOnInfo then
    local dlName, _, _, _, dlReason = C_AddOns.GetAddOnInfo("DynamicLoad")
    isDynamicLoadOnDisk = (dlName ~= nil and dlReason ~= "MISSING")
end
if isDynamicLoadOnDisk or addonTable.IsDynamicLoadModuleLoaded then
    _G.DynamicLoad = _G.DynamicLoad or addonTable
end

-- Mandatory core protected addons (cannot be unloaded by zone profiles unless Core Override is enabled)
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
addonTable.PROTECTED_ADDONS    = PROTECTED_ADDONS
addonTable.CORE_SUITE_ADDONS   = CORE_SUITE_ADDONS
addonTable.SUITE_MODULES       = SUITE_MODULES
DynamicSuite.PROTECTED_ADDONS  = PROTECTED_ADDONS
DynamicSuite.CORE_SUITE_ADDONS = CORE_SUITE_ADDONS
DynamicSuite.SUITE_MODULES     = SUITE_MODULES

-- Retired legacy addon names permanently ignored by new-addon ingestion
local RETIRED_IGNORED_ADDONS = {
    ["DynamicFrame"] = true,
}
addonTable.RETIRED_IGNORED_ADDONS = RETIRED_IGNORED_ADDONS

-- Peer DynamicSuite Modules Metadata (Extensible DYNAMIC MODULES Rail)
local SUITE_MODULE_LIST = addonTable.SUITE_MODULE_LIST or {
    {
        key = "load",
        id = "load",
        order = 10,
        name = "DynamicLoad",
        title = "DynamicLoad",
        addonName = "DynamicLoad",
        slash = "/dl",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_load.tga",
        subtitle = "Zone Addon Profiles",
        category = "Context-Aware Addon Profile Manager",
        desc = "Automatically stages addon loadouts across Outdoor, Delves, Dungeons, Raid, and PvP using By Zone, Always, and Never rules.",
    },
    {
        key = "marker",
        id = "marker",
        order = 20,
        name = "DynamicMarker",
        title = "DynamicMarker",
        addonName = "DynamicMarker",
        slash = "/dm",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_marker.tga",
        subtitle = "Targets, Flares, Macros",
        category = "Target Marking, World Flares & Multi-Spec Kick Macro",
        desc = "One-button focus target marking, F4/F5 ground flare keybinds, and an auto-swapping interrupt macro across all 13 classes.",
    },
    {
        key = "zoom",
        id = "zoom",
        order = 30,
        name = "DynamicZoom",
        title = "DynamicZoom",
        addonName = "DynamicZoom",
        slash = "/dz",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_zoom.tga",
        subtitle = "Max Zoom & Camera",
        category = "Zero-Lag C++ Camera Stepping & Occlusion Shield",
        desc = "Unlocks 39-yard max camera distance, fast scroll wheel boost, see-through trees and pillars, and automatic zone zoom.",
    },
    {
        key = "fps",
        id = "fps",
        order = 40,
        name = "DynamicFPS",
        title = "DynamicFPS",
        addonName = "DynamicFPS",
        slash = "/dfps",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_fps.tga",
        subtitle = "Zone Graphics & FPS",
        category = "Instant Zone Graphics & Frame Time Governor",
        desc = "Switches graphics settings per zone without reloading, protects combat FPS, tunes spell queue, and keeps boss swirlies visible.",
    },
    {
        key = "prep",
        id = "prep",
        order = 50,
        name = "DynamicPrep",
        title = "DynamicPrep",
        addonName = "DynamicPrep",
        slash = "/dprep",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_prep.tga",
        subtitle = "Stats, Buffs & QoL",
        category = "Live Stat Omni-Bar, Seasonal Folio & Fast QoL",
        desc = "Live stat and readiness top bar, clickable raid buffs and consumables, Omni Folio tracking, quest/cutscene skipping, and survival macros.",
    },
    {
        key = "group",
        id = "group",
        order = 60,
        name = "DynamicGroup",
        title = "DynamicGroup",
        addonName = "DynamicGroup",
        slash = "/dgroup",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_group.tga",
        subtitle = "LFG Filter & Invites",
        category = "LFG Region Filtering, Roster & Auto-Invite",
        desc = "Filters Premade Groups by datacentre region, M+ score, and Lust/CR utility, with 1-click sign-up, auto-invite, and M+ keystone slotting.",
    },
    {
        key = "bags",
        id = "bags",
        order = 70,
        name = "DynamicBags",
        title = "DynamicBags",
        addonName = "DynamicBags",
        slash = "/dbag",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_bags.tga",
        subtitle = "Bags & Alt Vault",
        category = "Zero-Lag Category Bags & Alt Inventory Vault",
        desc = "Zero-lag category bags, companion Bank/Warband/Guild Bank window, alt item vault, auto-repair, auto-sell junk, and fast auto-loot.",
    },
    {
        key = "chat",
        id = "chat",
        order = 80,
        name = "DynamicChat",
        title = "DynamicChat",
        addonName = "DynamicChat",
        slash = "/dchat",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_chat.tga",
        subtitle = "Target /ww & Chat QoL",
        category = "Target Whisper (/ww), Channel Tags & Performance",
        desc = "Instant /ww target whispers, smoked-glass chat skin with left shortcut bar, clickable links, and saved chat history across reloads.",
    },
}
addonTable.SUITE_MODULE_LIST = SUITE_MODULE_LIST
DynamicSuite.MODULE_LIST = SUITE_MODULE_LIST

-- Active Addon Conflict Registry (Scanned on PLAYER_LOGIN and inside Guided Setup)
local CONFLICT_REGISTRY = addonTable.CONFLICT_REGISTRY or {
    DynamicLoad = {
        "ACP", "SimpleAddonManager", "BetterAddonList", "AddonControlPanel", "AddonUsage",
        addons = { "ACP", "SimpleAddonManager", "BetterAddonList", "AddonControlPanel", "AddonUsage" },
        conflicts = { "ACP", "SimpleAddonManager", "BetterAddonList", "AddonControlPanel", "AddonUsage" },
        hardConflicts = { "ACP", "SimpleAddonManager", "BetterAddonList", "AddonControlPanel", "AddonUsage" },
        partialConflicts = {},
        softConflicts = {},
        category = "Addon Managers",
    },
    DynamicMarker = {
        "FocusMarker", "EllesmereUIQuickdraw", "EllesmereUI_Quickdraw", "MRT", "TargetCharms", "DejaMark", "EasyMarker", "WorldMarkers",
        addons = { "FocusMarker", "EllesmereUIQuickdraw", "EllesmereUI_Quickdraw", "MRT", "TargetCharms", "DejaMark", "EasyMarker", "WorldMarkers" },
        conflicts = { "FocusMarker", "EllesmereUIQuickdraw", "EllesmereUI_Quickdraw", "MRT", "TargetCharms", "DejaMark", "EasyMarker", "WorldMarkers" },
        hardConflicts = { "FocusMarker", "EllesmereUIQuickdraw", "EllesmereUI_Quickdraw", "MRT", "TargetCharms", "DejaMark", "EasyMarker", "WorldMarkers" },
        partialConflicts = {},
        softConflicts = {},
        category = "Target & Ground Markers",
        hasLegacyMigration = { FocusMarker = true },
    },
    DynamicZoom = {
        "DynamicCam", "MaxCam", "ActionCamPlus", "FasterCamera", "AdvancedInterfaceOptions",
        addons = { "DynamicCam", "MaxCam", "ActionCamPlus", "FasterCamera", "AdvancedInterfaceOptions", "EnhanceQoL", "Leatrix_Plus" },
        conflicts = { "DynamicCam", "MaxCam", "ActionCamPlus", "FasterCamera", "AdvancedInterfaceOptions" },
        hardConflicts = { "DynamicCam", "MaxCam", "ActionCamPlus", "FasterCamera", "AdvancedInterfaceOptions" },
        partialConflicts = { "EnhanceQoL", "Leatrix_Plus" },
        softConflicts = { "EnhanceQoL", "Leatrix_Plus" },
        category = "Camera Zoom & Optics",
    },
    DynamicFPS = {
        "Hyperframe", "AutoCombatLogger", "LoggerHead", "RaiderIO_AutoCombatLog", "!ArchonLogger", "ArchonLogger",
        addons = { "Hyperframe", "AutoCombatLogger", "LoggerHead", "RaiderIO_AutoCombatLog", "EnhanceQoL", "Leatrix_Plus", "!ArchonLogger", "ArchonLogger" },
        conflicts = { "Hyperframe", "AutoCombatLogger", "LoggerHead", "RaiderIO_AutoCombatLog" },
        hardConflicts = { "Hyperframe", "AutoCombatLogger", "LoggerHead", "RaiderIO_AutoCombatLog" },
        partialConflicts = { "EnhanceQoL", "Leatrix_Plus", "!ArchonLogger", "ArchonLogger" },
        softConflicts = { "EnhanceQoL", "Leatrix_Plus", "!ArchonLogger", "ArchonLogger" },
        category = "Graphics & Combat Logging",
    },
    DynamicPrep = {
        "EllesmereUIAuraBuffReminders", "EllesmereUI_AuraBuffReminders", "ClickableRaidBuffs",
        "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL", "EllesmereUIMythicTimer", "EllesmereUI_MythicPlus",
        "DialogUI", "DialogueUI", "Plumber", "Immersion", "Storyline", "AutoTurnIn", "BeQuiet", "TalkLess", "ElvUI", "WindTools",
        addons = {
            "EllesmereUIAuraBuffReminders", "EllesmereUI_AuraBuffReminders", "ClickableRaidBuffs",
            "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL", "EllesmereUIMythicTimer", "EllesmereUI_MythicPlus",
            "DialogUI", "DialogueUI", "Plumber", "Immersion", "Storyline", "AutoTurnIn", "BeQuiet", "TalkLess", "ElvUI", "WindTools",
        },
        conflicts = { "EllesmereUIAuraBuffReminders", "EllesmereUI_AuraBuffReminders", "ClickableRaidBuffs" },
        hardConflicts = { "EllesmereUIAuraBuffReminders", "EllesmereUI_AuraBuffReminders", "ClickableRaidBuffs" },
        partialConflicts = { "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL", "EllesmereUIMythicTimer", "EllesmereUI_MythicPlus", "DialogUI", "DialogueUI", "Plumber", "Immersion", "Storyline", "AutoTurnIn", "BeQuiet", "TalkLess", "ElvUI", "WindTools" },
        softConflicts = { "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL", "EllesmereUIMythicTimer", "EllesmereUI_MythicPlus", "DialogUI", "DialogueUI", "Plumber", "Immersion", "Storyline", "AutoTurnIn", "BeQuiet", "TalkLess", "ElvUI", "WindTools" },
        category = "Readiness & Automation",
    },
    DynamicGroup = {
        "EllesmereUIGroupFinder", "EllesmereUI_GroupFinder", "PremadeGroupsFilter", "PremadeRegionFilter", "LFGListFilter", "PremadeGroupFinder", "WorldQuestGroupFinder",
        addons = { "EllesmereUIGroupFinder", "EllesmereUI_GroupFinder", "PremadeGroupsFilter", "PremadeRegionFilter", "LFGListFilter", "PremadeGroupFinder", "WorldQuestGroupFinder" },
        conflicts = { "EllesmereUIGroupFinder", "EllesmereUI_GroupFinder", "PremadeGroupsFilter", "PremadeRegionFilter", "LFGListFilter", "PremadeGroupFinder", "WorldQuestGroupFinder" },
        hardConflicts = { "EllesmereUIGroupFinder", "EllesmereUI_GroupFinder", "PremadeGroupsFilter", "PremadeRegionFilter", "LFGListFilter", "PremadeGroupFinder", "WorldQuestGroupFinder" },
        partialConflicts = {},
        softConflicts = {},
        category = "LFG & Premade Search",
    },
    DynamicBags = {
        "EllesmereUIBags", "EllesmereUI_Bags", "EllesmereUI", "Baganator", "BetterBags", "AdiBags", "ArkInventory", "Bagnon", "Sorted", "LiteBag", "Syndicator", "BaudBag", "Combuctor", "Inventorian", "ElvUI_Bags", "ElvUI",
        addons = { "EllesmereUIBags", "EllesmereUI_Bags", "EllesmereUI", "Baganator", "BetterBags", "AdiBags", "ArkInventory", "Bagnon", "Sorted", "LiteBag", "Syndicator", "BaudBag", "Combuctor", "Inventorian", "ElvUI_Bags", "ElvUI", "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL", "Scrap", "Dejunk", "SellJunk", "AutoSeller", "SpeedyAutoLoot", "AutoLootPlus", "WindTools" },
        conflicts = { "EllesmereUIBags", "EllesmereUI_Bags", "EllesmereUI", "Baganator", "BetterBags", "AdiBags", "ArkInventory", "Bagnon", "Sorted", "LiteBag", "Syndicator", "BaudBag", "Combuctor", "Inventorian", "ElvUI_Bags", "ElvUI" },
        hardConflicts = { "EllesmereUIBags", "EllesmereUI_Bags", "EllesmereUI", "Baganator", "BetterBags", "AdiBags", "ArkInventory", "Bagnon", "Sorted", "LiteBag", "Syndicator", "BaudBag", "Combuctor", "Inventorian", "ElvUI_Bags", "ElvUI" },
        partialConflicts = { "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL", "Scrap", "Dejunk", "SellJunk", "AutoSeller", "SpeedyAutoLoot", "AutoLootPlus", "WindTools" },
        softConflicts = { "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL", "Scrap", "Dejunk", "SellJunk", "AutoSeller", "SpeedyAutoLoot", "AutoLootPlus", "WindTools" },
        category = "Inventory & Bags",
    },
    DynamicChat = {
        "Prat-3.0", "Chattynator", "ls_Glass", "BasicChatMods", "Chatter", "WIM", "EllesmereUI", "EllesmereUIChat", "EllesmereUI_Chat", "LS_Glass", "Glass", "PhanxChat", "DejaChat", "ElvUI",
        addons = { "Prat-3.0", "Chattynator", "ls_Glass", "BasicChatMods", "Chatter", "WIM", "EllesmereUI", "EllesmereUIChat", "EllesmereUI_Chat", "LS_Glass", "Glass", "PhanxChat", "DejaChat", "ElvUI", "EnhanceQoL", "EnhanceQoLChatSocial", "Leatrix_Plus", "WindTools" },
        conflicts = { "EllesmereUIChat", "EllesmereUI_Chat", "EllesmereUI", "Chattynator", "Prat-3.0", "ls_Glass", "LS_Glass", "Glass", "BasicChatMods", "Chatter", "PhanxChat", "DejaChat", "WIM", "ElvUI" },
        hardConflicts = { "EllesmereUIChat", "EllesmereUI_Chat", "EllesmereUI", "Chattynator", "Prat-3.0", "ls_Glass", "LS_Glass", "Glass", "BasicChatMods", "Chatter", "PhanxChat", "DejaChat", "WIM", "ElvUI" },
        partialConflicts = { "EnhanceQoL", "EnhanceQoLChatSocial", "Leatrix_Plus", "WindTools" },
        softConflicts = { "EnhanceQoL", "EnhanceQoLChatSocial", "Leatrix_Plus", "WindTools" },
        category = "Chat & Communications",
    },
}
CONFLICT_REGISTRY.load   = CONFLICT_REGISTRY.DynamicLoad
CONFLICT_REGISTRY.marker = CONFLICT_REGISTRY.DynamicMarker
CONFLICT_REGISTRY.zoom   = CONFLICT_REGISTRY.DynamicZoom
CONFLICT_REGISTRY.fps    = CONFLICT_REGISTRY.DynamicFPS
CONFLICT_REGISTRY.prep   = CONFLICT_REGISTRY.DynamicPrep
CONFLICT_REGISTRY.group  = CONFLICT_REGISTRY.DynamicGroup
CONFLICT_REGISTRY.bags   = CONFLICT_REGISTRY.DynamicBags
CONFLICT_REGISTRY.chat   = CONFLICT_REGISTRY.DynamicChat
addonTable.CONFLICT_REGISTRY = CONFLICT_REGISTRY
DynamicSuite.CONFLICT_REGISTRY = CONFLICT_REGISTRY

local FRIENDLY_CONFLICT_NAMES = addonTable.FRIENDLY_CONFLICT_NAMES or {
    ["SimpleAddonManager"]       = "Simple Addon Manager",
    ["ACP"]                      = "ACP",
    ["AddonControlPanel"]        = "Addon Control Panel",
    ["BetterAddonList"]          = "BetterAddonList",
    ["FocusMarker"]              = "FocusMarker",
    ["TargetCharms"]             = "TargetCharms",
    ["WorldMarkers"]             = "WorldMarkers",
    ["DejaMark"]                 = "DejaMark",
    ["EasyMarker"]               = "EasyMarker",
    ["DynamicCam"]               = "DynamicCam",
    ["MaxCam"]                   = "MaxCam",
    ["ActionCamPlus"]            = "ActionCamPlus",
    ["FasterCamera"]             = "FasterCamera",
    ["AdvancedInterfaceOptions"] = "Advanced Interface Options",
    ["Hyperframe"]               = "Hyperframe",
    ["AutoCombatLogger"]         = "AutoCombatLogger",
    ["LoggerHead"]               = "LoggerHead",
    ["RaiderIO_AutoCombatLog"]   = "RaiderIO AutoCombatLog",
    ["!ArchonLogger"]            = "Archon Logger",
    ["ArchonLogger"]             = "Archon Logger",
    ["DialogueUI"]               = "DialogueUI",
    ["Immersion"]                = "Immersion",
    ["Storyline"]                = "Storyline",
    ["AutoTurnIn"]               = "AutoTurnIn",
    ["EnhanceQoL"]               = "EnhanceQoL",
    ["EnhanceQoLChatSocial"]     = "EnhanceQoL (Chat & Social)",
    ["ClickableRaidBuffs"]       = "Clickable Raid Buffs",
    ["BeQuiet"]                  = "BeQuiet",
    ["TalkLess"]                 = "TalkLess",
    ["Scrap"]                    = "Scrap",
    ["Dejunk"]                   = "Dejunk",
    ["SellJunk"]                 = "SellJunk",
    ["AutoSeller"]               = "AutoSeller",
    ["SpeedyAutoLoot"]           = "SpeedyAutoLoot",
    ["AutoLootPlus"]             = "AutoLootPlus",
    ["Leatrix_Plus"]             = "Leatrix Plus",
    ["ElvUI"]                    = "ElvUI",
    ["ElvUI_Bags"]               = "ElvUI Bags",
    ["WindTools"]                = "ElvUI WindTools",
    ["EllesmereUI"]              = "EllesmereUI",
    ["EllesmereUIGroupFinder"]   = "EllesmereUI Group Finder",
    ["EllesmereUI_GroupFinder"]  = "EllesmereUI Group Finder",
    ["EllesmereUIBags"]          = "EllesmereUI Bags",
    ["EllesmereUI_Bags"]         = "EllesmereUI Bags",
    ["EllesmereUIChat"]          = "EllesmereUI Chat",
    ["EllesmereUI_Chat"]         = "EllesmereUI Chat",
    ["EllesmereUIAuraBuffReminders"]  = "EllesmereUI AuraBuff Reminders",
    ["EllesmereUI_AuraBuffReminders"] = "EllesmereUI AuraBuff Reminders",
    ["EllesmereUIQuickdraw"]     = "EllesmereUI Quickdraw",
    ["EllesmereUI_Quickdraw"]    = "EllesmereUI Quickdraw",
    ["EllesmereUIQoL"]           = "EllesmereUI Quality of Life",
    ["EllesmereUI_QoL"]          = "EllesmereUI Quality of Life",
    ["EllesmereUIMythicTimer"]   = "EllesmereUI Mythic+ Tools",
    ["EllesmereUI_MythicPlus"]   = "EllesmereUI Mythic+ Tools",
    ["MRT"]                      = "Method Raid Tools (MRT)",
    ["DialogUI"]                 = "DialogUI",
    ["Plumber"]                  = "Plumber",
    ["PremadeGroupsFilter"]      = "PremadeGroupsFilter",
    ["PremadeRegionFilter"]      = "PremadeRegionFilter",
    ["LFGListFilter"]            = "LFG List Filter",
    ["Baganator"]                = "Baganator",
    ["Syndicator"]               = "Syndicator (Baganator Alt Cache)",
    ["BetterBags"]               = "BetterBags",
    ["AdiBags"]                  = "AdiBags",
    ["Bagnon"]                   = "Bagnon",
    ["ArkInventory"]             = "ArkInventory",
    ["Sorted"]                   = "Sorted",
    ["LiteBag"]                  = "LiteBag",
    ["BaudBag"]                  = "BaudBag",
    ["Combuctor"]                = "Combuctor",
    ["Inventorian"]              = "Inventorian",
    ["Chattynator"]              = "Chattynator",
    ["Prat-3.0"]                 = "Prat-3.0",
    ["BasicChatMods"]            = "BasicChatMods",
    ["Chatter"]                  = "Chatter",
    ["ls_Glass"]                 = "ls_Glass",
    ["LS_Glass"]                 = "LS: Glass",
    ["Glass"]                    = "Glass",
    ["PhanxChat"]                = "PhanxChat",
    ["DejaChat"]                 = "DejaChat",
    ["WIM"]                      = "WIM",
}
addonTable.FRIENDLY_CONFLICT_NAMES = FRIENDLY_CONFLICT_NAMES
DynamicSuite.FRIENDLY_CONFLICT_NAMES = FRIENDLY_CONFLICT_NAMES

local CONFLICT_YIELD_FEATURES = {
    ["DialogueUI"]           = "gossip/camera control",
    ["Immersion"]            = "gossip/camera control",
    ["Storyline"]            = "gossip/camera control",
    ["AutoTurnIn"]           = "quest/gossip control",
    ["BeQuiet"]              = "Talking Head control",
    ["TalkLess"]             = "Talking Head control",
    ["WIM"]                  = "whisper window control",
    ["EnhanceQoLChatSocial"] = "shared chat features",
    ["!ArchonLogger"]        = "combat log control",
    ["ArchonLogger"]         = "combat log control",
    ["Scrap"]                = "vendor junk selling",
    ["Dejunk"]               = "vendor junk selling",
    ["SellJunk"]             = "vendor junk selling",
    ["AutoSeller"]           = "vendor junk selling",
    ["SpeedyAutoLoot"]       = "auto-loot control",
    ["AutoLootPlus"]         = "auto-loot control",
    ["Leatrix_Plus"]             = "overlapping QoL features",
    ["ElvUI"]                    = "overlapping UI features",
    ["WindTools"]                = "overlapping UI features",
    ["EllesmereUI"]              = "chat/editbox skinning",
    ["EllesmereUIChat"]          = "chat/editbox skinning",
    ["EllesmereUI_Chat"]         = "chat/editbox skinning",
    ["EllesmereUIGroupFinder"]   = "shared Group Finder features",
}
addonTable.CONFLICT_YIELD_FEATURES = CONFLICT_YIELD_FEATURES
DynamicSuite.CONFLICT_YIELD_FEATURES = CONFLICT_YIELD_FEATURES

-- Environment Profiles
local CONTEXT_OUTDOOR = "outdoor"
local CONTEXT_DELVE   = "delve"
local CONTEXT_DUNGEON = "dungeon"
local CONTEXT_RAID    = "raid"
local CONTEXT_PVP     = "pvp"

local CONTEXT_LABELS = {
    [CONTEXT_OUTDOOR] = "Outdoor",
    [CONTEXT_DELVE]   = "Delves",
    [CONTEXT_DUNGEON] = "Dungeons",
    [CONTEXT_RAID]    = "Raid",
    [CONTEXT_PVP]     = "PvP",
}
addonTable.CONTEXT_LABELS = CONTEXT_LABELS

-- Default Account-Wide Suite Settings (DynamicSuiteDB.global)
local DEFAULT_SUITE_GLOBAL = {
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
    toastEnabled     = true,
    toastMode        = "ON",
    toastBorderStyle = "ACCENT",
    toastDisplayMode = "DETAILED", -- "DETAILED", "COMPACT", "EXCEPTIONS_ONLY"
    toastScale       = 1.0,
    toastAlpha       = 0.96,
    toastOpacity     = 0.96,
    toastDuration    = 8,
    hudSnapMode      = "MAGNET",
    minimizedBarPos  = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
    editModeModalPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
    disabledModules  = {},
    yieldHooks       = {},
    acknowledgedConflicts = {},
    seenHardConflicts = {},
    guidedSetupDone  = false,
    showGameMenuSuiteBtn     = true,
    showGameMenuHudBtn       = true,
    replaceBlizzardAddonList = true,
    v120_windowWidth1040 = false,
}
addonTable.DEFAULT_SUITE_GLOBAL = DEFAULT_SUITE_GLOBAL

local playerName = nil

local function GetPlayer()
    if not playerName then
        local uName = UnitName("player")
        if uName and uName ~= "" and uName ~= "Unknown" and uName ~= _G.UNKNOWNOBJECT then
            playerName = uName
        end
    end
    return playerName or "player"
end
addonTable.GetPlayer = GetPlayer

local function GetCurrentCharKey()
    local pName = GetPlayer()
    local realm = GetRealmName() or "Realm"
    return pName .. "-" .. realm
end
addonTable.GetCurrentCharKey = GetCurrentCharKey

local function GetCharScopeMode()
    if _G.DynamicLoadDB and _G.DynamicLoadDB.charScopeMode then
        local charKey = GetCurrentCharKey()
        return (_G.DynamicLoadDB.charScopeMode[charKey] == "CHARACTER") and "CHARACTER" or "GLOBAL"
    end
    if _G.DynamicSuiteDB and _G.DynamicSuiteDB.charScopeMode then
        local charKey = GetCurrentCharKey()
        return (_G.DynamicSuiteDB.charScopeMode[charKey] == "CHARACTER") and "CHARACTER" or "GLOBAL"
    end
    return "GLOBAL"
end
addonTable.GetCharScopeMode = addonTable.GetCharScopeMode or GetCharScopeMode

local function EnsureSuiteGlobal()
    if not _G.DynamicSuiteDB then
        _G.DynamicSuiteDB = {}
    end
    if not _G.DynamicSuiteDB.global then
        _G.DynamicSuiteDB.global = CopyTable(DEFAULT_SUITE_GLOBAL)
        -- Seamless migration from legacy DynamicLoadDB theme/window keys if present
        if type(_G.DynamicLoadDB) == "table" then
            for _, k in ipairs({ "windowWidth", "windowHeight", "windowScale", "windowAlpha", "surfaceTheme", "accentKey", "customAccent", "fontKey", "fontFamily", "pillFillAlpha", "recentColors", "toastPos", "toastDisplayMode", "toastScale", "toastAlpha", "toastDuration", "moduleOrder" }) do
                if _G.DynamicLoadDB[k] ~= nil then
                    if type(_G.DynamicLoadDB[k]) == "table" then
                        _G.DynamicSuiteDB.global[k] = CopyTable(_G.DynamicLoadDB[k])
                    else
                        _G.DynamicSuiteDB.global[k] = _G.DynamicLoadDB[k]
                    end
                end
            end
        end
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
    if GetCharScopeMode() == "CHARACTER" and _G.DynamicLoadDB and _G.DynamicLoadDB.charData then
        local charKey = GetCurrentCharKey()
        local cd = _G.DynamicLoadDB.charData[charKey]
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
addonTable.GetSuiteGlobal = EnsureSuiteGlobal
DynamicSuite.GetSuiteGlobal = EnsureSuiteGlobal

local function IsAddonProtected(name)
    if not name then return false end
    if _G.DynamicLoadDB and _G.DynamicLoadDB.allowCoreOverride == true then
        return false
    end
    return (PROTECTED_ADDONS[name] == true) and not RETIRED_IGNORED_ADDONS[name]
end
addonTable.IsAddonProtected = IsAddonProtected

local function NormalizeSuiteModuleId(modKeyOrName)
    local s = tostring(modKeyOrName or "")
    local low = s:gsub("^Dynamic", ""):lower()
    if low == "load" then return "DynamicLoad", "load"
    elseif low == "marker" then return "DynamicMarker", "marker"
    elseif low == "zoom" then return "DynamicZoom", "zoom"
    elseif low == "fps" then return "DynamicFPS", "fps"
    elseif low == "prep" then return "DynamicPrep", "prep"
    elseif low == "group" then return "DynamicGroup", "group"
    elseif low == "bags" then return "DynamicBags", "bags"
    elseif low == "chat" then return "DynamicChat", "chat"
    end
    return s, low
end
addonTable.NormalizeSuiteModuleId = NormalizeSuiteModuleId

local function IsSuiteModuleExplicitlyDisabled(modName)
    if not modName or modName == "DynamicSuite" or modName == "DynamicLoad" or modName == "load" then return false end
    local canonMod, shortKey = NormalizeSuiteModuleId(modName)
    if canonMod == "DynamicSuite" or canonMod == "DynamicLoad" then return false end
    if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.disabledModules) == "table" then
        if _G.DynamicSuiteDB.disabledModules[canonMod] == true
            or _G.DynamicSuiteDB.disabledModules[shortKey] == true
            or _G.DynamicSuiteDB.disabledModules[modName] == true then
            return true
        end
    end
    if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.global) == "table" and type(_G.DynamicSuiteDB.global.disabledModules) == "table" then
        if _G.DynamicSuiteDB.global.disabledModules[canonMod] == true
            or _G.DynamicSuiteDB.global.disabledModules[shortKey] == true
            or _G.DynamicSuiteDB.global.disabledModules[modName] == true then
            return true
        end
    end
    return false
end
addonTable.IsSuiteModuleExplicitlyDisabled = IsSuiteModuleExplicitlyDisabled
DynamicSuite.IsSuiteModuleExplicitlyDisabled = IsSuiteModuleExplicitlyDisabled

local function SetSuiteModuleEnabled(modName, isEnabled, skipUIRefresh)
    if not modName then return end
    local canonMod, shortKey = NormalizeSuiteModuleId(modName)
    if canonMod == "DynamicSuite" or canonMod == "DynamicLoad" then return end

    local pName = GetPlayer()
    local g = EnsureSuiteGlobal()
    g.disabledModules = type(g.disabledModules) == "table" and g.disabledModules or {}

    local hasAddon = (C_AddOns and C_AddOns.GetAddOnInfo and C_AddOns.GetAddOnInfo(canonMod) ~= nil)
    local regMod = (DynamicSuite and DynamicSuite.modules and (DynamicSuite.modules[canonMod] or DynamicSuite.modules[shortKey])) or _G[canonMod]

    if isEnabled then
        g.disabledModules[canonMod] = nil
        g.disabledModules[shortKey] = nil
        if _G.DynamicSuiteDB then
            if type(_G.DynamicSuiteDB.global) == "table" and type(_G.DynamicSuiteDB.global.disabledModules) == "table" then
                _G.DynamicSuiteDB.global.disabledModules[canonMod] = nil
                _G.DynamicSuiteDB.global.disabledModules[shortKey] = nil
            end
            if type(_G.DynamicSuiteDB.disabledModules) == "table" then
                _G.DynamicSuiteDB.disabledModules[canonMod] = nil
                _G.DynamicSuiteDB.disabledModules[shortKey] = nil
            end
        end
        if hasAddon then
            if canonMod == "DynamicMarker" then
                if C_AddOns.DisableAddOn then
                    pcall(C_AddOns.DisableAddOn, canonMod, pName)
                    pcall(C_AddOns.DisableAddOn, canonMod)
                end
            elseif C_AddOns.EnableAddOn then
                pcall(C_AddOns.EnableAddOn, canonMod, pName)
                pcall(C_AddOns.EnableAddOn, canonMod)
            end
        end
        if regMod and type(regMod.OnEnableInSuite) == "function" then
            pcall(regMod.OnEnableInSuite, regMod)
        end
    else
        g.disabledModules[canonMod] = true
        g.disabledModules[shortKey] = true
        if _G.DynamicSuiteDB then
            _G.DynamicSuiteDB.global = type(_G.DynamicSuiteDB.global) == "table" and _G.DynamicSuiteDB.global or {}
            _G.DynamicSuiteDB.global.disabledModules = type(_G.DynamicSuiteDB.global.disabledModules) == "table" and _G.DynamicSuiteDB.global.disabledModules or {}
            _G.DynamicSuiteDB.global.disabledModules[canonMod] = true
            _G.DynamicSuiteDB.global.disabledModules[shortKey] = true
            _G.DynamicSuiteDB.disabledModules = type(_G.DynamicSuiteDB.disabledModules) == "table" and _G.DynamicSuiteDB.disabledModules or {}
            _G.DynamicSuiteDB.disabledModules[canonMod] = true
            _G.DynamicSuiteDB.disabledModules[shortKey] = true
        end
        if hasAddon and C_AddOns.DisableAddOn then
            pcall(C_AddOns.DisableAddOn, canonMod, pName)
            pcall(C_AddOns.DisableAddOn, canonMod)
        end
        if regMod and type(regMod.OnDisableInSuite) == "function" then
            pcall(regMod.OnDisableInSuite, regMod)
        end
        if canonMod == "DynamicChat" and _G.DynamicChat and type(_G.DynamicChat.TeardownDisabledState) == "function" then
            pcall(_G.DynamicChat.TeardownDisabledState, _G.DynamicChat, true)
        end
    end

    if canonMod == "DynamicChat" or (regMod and regMod._disabledAtStartup) then
        addonTable._pendingSuiteModuleReload = true
    end

    if addonTable.InvalidateConflictCache then
        addonTable.InvalidateConflictCache()
    end

    if not skipUIRefresh and addonTable.mainFrame then
        local mf = addonTable.mainFrame
        if mf.RefreshLeftRailVisuals then pcall(mf.RefreshLeftRailVisuals) end
        if mf.scrollChild and mf.scrollChild.Refresh then pcall(mf.scrollChild.Refresh, mf.scrollChild) end
        if mf.UpdateStatusBar then pcall(mf.UpdateStatusBar) end
        if mf.peerView and mf.peerView:IsShown() and mf.peerView.Refresh then pcall(mf.peerView.Refresh) end
    end
end
addonTable.SetSuiteModuleEnabled = SetSuiteModuleEnabled
DynamicSuite.SetSuiteModuleEnabled = SetSuiteModuleEnabled

local ELLESMERE_PROTECTED_LIST = {
    "EllesmereUI",
    "EllesmereUIChat",
    "EllesmereUI_Chat",
    "EllesmereUIGroupFinder",
}

local function RecoverEllesmereUIState()
    -- Intentionally no-op in v1.6.1+: Never/FROZEN user choices are strictly respected
    -- across all addon families (including EllesmereUI and its sub-addons).
end
addonTable.RecoverEllesmereUIState = RecoverEllesmereUIState
DynamicSuite.RecoverEllesmereUIState = RecoverEllesmereUIState

local standaloneMarkerWasEnabledAtBoot = (_G.DynamicSuite_StandaloneMarkerWasEnabledAtBoot == true)
local shownMarkerConflictModalThisSession = false
local _notifiedStandaloneMarkerReload = false
local function ShowMarkerConflictReloadModal()
    if shownMarkerConflictModalThisSession or DynamicSuite._shownMarkerConflictModalThisSession then
        return
    end
    local existingModal = _G.DynamicSuiteMarkerConflictModal
    if existingModal and existingModal._dismissedByUser then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        addonTable._pendingMarkerConflictModal = true
        local deferFrame = _G.DynamicSuiteMarkerConflictDeferFrame
        if not deferFrame then
            deferFrame = CreateFrame("Frame", "DynamicSuiteMarkerConflictDeferFrame", UIParent)
            deferFrame:SetScript("OnEvent", function(self)
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                if addonTable._pendingMarkerConflictModal then
                    ShowMarkerConflictReloadModal()
                end
            end)
        end
        deferFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    addonTable._pendingMarkerConflictModal = false

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
            DynamicSuite._shownMarkerConflictModalThisSession = true
            modal:Hide()
            if type(_G.ReloadUI) == "function" then
                _G.ReloadUI()
            end
        end)
        modal.ReloadBtn:SetPoint("BOTTOMRIGHT", modal, "BOTTOM", -6, 16)

        modal.LaterBtn = CreateModalButton(modal, "Reload Later", 138, 28, false, function()
            modal._dismissedByUser = true
            shownMarkerConflictModalThisSession = true
            DynamicSuite._shownMarkerConflictModalThisSession = true
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
    DynamicSuite._shownMarkerConflictModalThisSession = true
    modal:Show()
    modal:Raise()
end
addonTable.ShowMarkerConflictReloadModal = ShowMarkerConflictReloadModal
DynamicSuite.ShowMarkerConflictReloadModal = ShowMarkerConflictReloadModal

local function ScrubStandaloneDynamicMarkerFromLoadDB(tbl)
    if type(tbl) ~= "table" then return end
    if type(tbl.lockedAddons) == "table" then tbl.lockedAddons["DynamicMarker"] = nil end
    if type(tbl.addonStates) == "table" and tbl.addonStates["DynamicMarker"] == "LOCKED" then
        tbl.addonStates["DynamicMarker"] = nil
    end
    if type(tbl.sessionBaseline) == "table" then tbl.sessionBaseline["DynamicMarker"] = false end
    if type(tbl.lastAddonSnapshot) == "table" then tbl.lastAddonSnapshot["DynamicMarker"] = false end
    if type(tbl.profiles) == "table" then
        for _, prof in pairs(tbl.profiles) do
            if type(prof) == "table" and type(prof.addons) == "table" then
                prof.addons["DynamicMarker"] = false
            end
        end
    end
end

local function EnforceStandaloneDynamicMarkerExclusion(showPopupIfLoaded)
    if not (C_AddOns and C_AddOns.GetAddOnInfo) then return false end
    local okInfo, infoName = pcall(C_AddOns.GetAddOnInfo, "DynamicMarker")
    if not okInfo or not infoName then return false end

    local pName = GetPlayer()
    local uName = type(_G.UnitName) == "function" and _G.UnitName("player") or nil
    local uGuid = type(_G.UnitGUID) == "function" and _G.UnitGUID("player") or nil
    local isEnabled = false
    if C_AddOns.GetAddOnEnableState then
        if type(uName) == "string" and uName ~= "" and uName ~= "Unknown" and uName ~= _G.UNKNOWNOBJECT then
            local okSt, st = pcall(C_AddOns.GetAddOnEnableState, "DynamicMarker", uName)
            if okSt and type(st) == "number" and st > 0 then
                isEnabled = true
            end
        end
        if not isEnabled then
            local okSt2, st2 = pcall(C_AddOns.GetAddOnEnableState, "DynamicMarker")
            if okSt2 and type(st2) == "number" and st2 > 0 then
                isEnabled = true
            end
        end
        if not isEnabled and type(uGuid) == "string" and uGuid ~= "" then
            local okSt3, st3 = pcall(C_AddOns.GetAddOnEnableState, "DynamicMarker", uGuid)
            if okSt3 and type(st3) == "number" and st3 > 0 then
                isEnabled = true
            end
        end
    end
    local isLoaded = ((C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("DynamicMarker"))
        or (type(_G.IsAddOnLoaded) == "function" and _G.IsAddOnLoaded("DynamicMarker"))) and true or false
    local hasStandaloneRuntime = ((_G.DynamicMarker and _G.DynamicMarker._loadedBySuite == false)
        or (_G.DynamicSuite and _G.DynamicSuite.standaloneMarkerWasEnabledAtBoot == true)
        or (_G.DynamicSuite_StandaloneMarkerWasEnabledAtBoot == true)) and true or false

    if isEnabled or isLoaded or hasStandaloneRuntime then
        standaloneMarkerWasEnabledAtBoot = true
        _G.DynamicSuite_StandaloneMarkerWasEnabledAtBoot = true
        addonTable.standaloneMarkerWasEnabledAtBoot = true
        DynamicSuite.standaloneMarkerWasEnabledAtBoot = true
        DynamicSuite._standaloneMarkerConflictDetected = true
        addonTable._pendingSuiteModuleReload = true
    end

    if not isEnabled and not isLoaded and not hasStandaloneRuntime and not standaloneMarkerWasEnabledAtBoot then
        return false
    end

    if isEnabled and C_AddOns.DisableAddOn then
        if type(uName) == "string" and uName ~= "" and uName ~= "Unknown" and uName ~= _G.UNKNOWNOBJECT then
            pcall(C_AddOns.DisableAddOn, "DynamicMarker", uName)
        end
        pcall(C_AddOns.DisableAddOn, "DynamicMarker", pName)
        pcall(C_AddOns.DisableAddOn, "DynamicMarker")
    end
    if _G.DynamicLoadDB then
        ScrubStandaloneDynamicMarkerFromLoadDB(_G.DynamicLoadDB)
        ScrubStandaloneDynamicMarkerFromLoadDB(_G.DynamicLoadDB.globalData)
        if type(_G.DynamicLoadDB.charData) == "table" then
            for _, cd in pairs(_G.DynamicLoadDB.charData) do
                ScrubStandaloneDynamicMarkerFromLoadDB(cd)
            end
        end
    end
    if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.global) == "table" and type(_G.DynamicSuiteDB.global.dynamicLoad) == "table" then
        ScrubStandaloneDynamicMarkerFromLoadDB(_G.DynamicSuiteDB.global.dynamicLoad)
    end

    if standaloneMarkerWasEnabledAtBoot or isLoaded or hasStandaloneRuntime or isEnabled or DynamicSuite._standaloneMarkerConflictDetected then
        addonTable._pendingSuiteModuleReload = true
        if showPopupIfLoaded then
            if not _notifiedStandaloneMarkerReload then
                _notifiedStandaloneMarkerReload = true
                print(string.format("%s: Standalone DynamicMarker was active alongside DynamicSuite and has been disabled. Please /reload to complete cleanup.", ADDON_TITLE))
            end
            ShowMarkerConflictReloadModal()
        end
    end
    return true
end
addonTable.EnforceStandaloneDynamicMarkerExclusion = EnforceStandaloneDynamicMarkerExclusion
DynamicSuite.EnforceStandaloneDynamicMarkerExclusion = EnforceStandaloneDynamicMarkerExclusion

local function EnforceProtectedSuiteModules()
    EnforceStandaloneDynamicMarkerExclusion(false)
    if _G.DynamicLoadDB and _G.DynamicLoadDB.allowCoreOverride == true then
        return
    end
    local pName = GetPlayer()
    for modName, isCore in pairs(PROTECTED_ADDONS) do
        if isCore and not RETIRED_IGNORED_ADDONS[modName] and modName ~= "DynamicMarker" then
            if _G.DynamicLoadDB then
                if _G.DynamicLoadDB.frozenAddons then _G.DynamicLoadDB.frozenAddons[modName] = nil end
                if _G.DynamicLoadDB.lockedAddons then _G.DynamicLoadDB.lockedAddons[modName] = true end
                if _G.DynamicLoadDB.addonStates then _G.DynamicLoadDB.addonStates[modName] = "LOCKED" end
                if _G.DynamicLoadDB.profiles then
                    for _, ctx in ipairs({ CONTEXT_OUTDOOR, CONTEXT_DELVE, CONTEXT_DUNGEON, CONTEXT_RAID, CONTEXT_PVP }) do
                        local prof = _G.DynamicLoadDB.profiles[ctx]
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
EnforceStandaloneDynamicMarkerExclusion(false)

local SUITE_MODIFIED_CVARS = {
    -- DynamicFPS
    "projectedTextures", "RAIDprojectedTextures",
    "useMaxFPS", "maxFPS", "useMaxFPSBk", "maxFPSBk",
    "nameplateShowFriends", "findYourselfMode",
    "graphicsSpellDensity", "RAIDgraphicsSpellDensity", "spellClutter",
    "graphicsGroundClutter", "RAIDgroundEffectDensity",
    "graphicsParticleDensity", "RAIDgraphicsParticleDensity",
    "farclip", "RAIDfarclip", "horizonClip",
    "graphicsViewDistance", "RAIDgraphicsViewDistance",
    "SpellQueueWindow", "Sound_EnableErrorSpeech",
    -- DynamicZoom
    "cameraDistanceMaxZoomFactor", "cameraIndirectVisibility", "cameraIndirectOffset",
    "cameraWaterCollision", "CameraKeepCharacterCentered", "CameraReduceUnexpectedMovement",
    "cameraZSmooth", "cameraZoomSpeed",
    "test_cameraDynamicPitch", "test_cameraDynamicPitchBaseFovPad",
    "test_cameraDynamicPitchBaseFovPadDownScale", "test_cameraDynamicPitchBaseFovPadFlying",
    "test_cameraDynamicPitchSmartPivotCutoffDist", "cameraPitchMoveSpeed",
    "test_cameraOverShoulder",
    -- DynamicChat
    "chatClassColorOverride", "showTimestamps",
    -- DynamicBags
    "autoLootDefault",
}
addonTable.SUITE_MODIFIED_CVARS = SUITE_MODIFIED_CVARS

local function SnapshotCVar(cvarName)
    if type(cvarName) ~= "string" or cvarName == "" then return end
    local g = EnsureSuiteGlobal()
    g.cvarSnapshots = type(g.cvarSnapshots) == "table" and g.cvarSnapshots or {}
    if g.cvarSnapshots[cvarName] ~= nil then return end
    if _G.DynamicFPSDB and type(_G.DynamicFPSDB.savedBaselineCVars) == "table" and _G.DynamicFPSDB.savedBaselineCVars[cvarName] ~= nil then
        g.cvarSnapshots[cvarName] = tostring(_G.DynamicFPSDB.savedBaselineCVars[cvarName])
        return
    end
    if C_CVar and type(C_CVar.GetCVar) == "function" then
        local ok, cur = pcall(C_CVar.GetCVar, cvarName)
        if ok and cur ~= nil then
            g.cvarSnapshots[cvarName] = tostring(cur)
        end
    end
end
addonTable.SnapshotCVar = SnapshotCVar
DynamicSuite.SnapshotCVar = SnapshotCVar

local function SnapshotAllSuiteCVars()
    for _, cvarName in ipairs(SUITE_MODIFIED_CVARS) do
        SnapshotCVar(cvarName)
    end
end
addonTable.SnapshotAllSuiteCVars = SnapshotAllSuiteCVars

local function RestoreBlizzardDefaults(disableSuiteAddons)
    if type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() then
        print(string.format("%s: Cannot restore Blizzard defaults or change addon states during combat. Please leave combat and try again.", ADDON_TITLE))
        return false, "COMBAT"
    end

    local g = EnsureSuiteGlobal()
    local snaps = type(g.cvarSnapshots) == "table" and g.cvarSnapshots or {}
    local fpsBaselines = (_G.DynamicFPSDB and type(_G.DynamicFPSDB.savedBaselineCVars) == "table") and _G.DynamicFPSDB.savedBaselineCVars or {}

    local seenCVars = {}
    local cvarQueue = {}
    for _, cvarName in ipairs(SUITE_MODIFIED_CVARS) do
        if not seenCVars[cvarName] then
            seenCVars[cvarName] = true
            table.insert(cvarQueue, cvarName)
        end
    end
    for cvarName in pairs(snaps) do
        if not seenCVars[cvarName] then
            seenCVars[cvarName] = true
            table.insert(cvarQueue, cvarName)
        end
    end
    for cvarName in pairs(fpsBaselines) do
        if not seenCVars[cvarName] then
            seenCVars[cvarName] = true
            table.insert(cvarQueue, cvarName)
        end
    end

    if C_CVar and type(C_CVar.SetCVar) == "function" then
        for _, cvarName in ipairs(cvarQueue) do
            local targetVal = snaps[cvarName]
            if targetVal == nil then
                targetVal = fpsBaselines[cvarName]
            end
            if targetVal == nil and type(C_CVar.GetCVarDefault) == "function" then
                local okDef, defVal = pcall(C_CVar.GetCVarDefault, cvarName)
                if okDef and defVal ~= nil then
                    targetVal = defVal
                end
            end
            if targetVal ~= nil then
                pcall(C_CVar.SetCVar, cvarName, tostring(targetVal))
            end
        end
    end

    if type(_G.FCF_ResetChatWindows) == "function" then
        pcall(_G.FCF_ResetChatWindows)
    end

    g.windowPoint = nil
    g.windowX = nil
    g.windowY = nil
    g.windowWidth = 1040
    g.windowHeight = 680
    g.toastPos = nil
    if type(_G.DynamicMarkerDB) == "table" then
        _G.DynamicMarkerDB.targetBarPoint = nil
        _G.DynamicMarkerDB.targetBarRelPoint = nil
        _G.DynamicMarkerDB.targetBarX = nil
        _G.DynamicMarkerDB.targetBarY = nil
        _G.DynamicMarkerDB.targetBarPos = nil
        _G.DynamicMarkerDB.flareBarPoint = nil
        _G.DynamicMarkerDB.flareBarRelPoint = nil
        _G.DynamicMarkerDB.flareBarX = nil
        _G.DynamicMarkerDB.flareBarY = nil
        _G.DynamicMarkerDB.flareBarPos = nil
        _G.DynamicMarkerDB.pos = nil
        _G.DynamicMarkerDB.point = nil
        _G.DynamicMarkerDB.x = nil
        _G.DynamicMarkerDB.y = nil
    end
    if type(_G.DynamicPrepDB) == "table" then
        _G.DynamicPrepDB.barPos = nil
        _G.DynamicPrepDB.pos = nil
    end
    if type(_G.DynamicChatDB) == "table" then
        _G.DynamicChatDB.chatFramePos = nil
    end

    if disableSuiteAddons == true and C_AddOns and type(C_AddOns.DisableAddOn) == "function" then
        if _G.DynamicLoadDB then
            _G.DynamicLoadDB.allowCoreOverride = true
        end
        local pName = GetPlayer()
        for _, modName in ipairs(SUITE_MODULES) do
            pcall(C_AddOns.DisableAddOn, modName, pName)
            pcall(C_AddOns.DisableAddOn, modName)
        end
    end

    print(string.format("%s: Restored Blizzard defaults (game settings, chat windows, and bar positions). Reloading UI...", ADDON_TITLE))
    if type(_G.ReloadUI) == "function" then
        _G.ReloadUI()
    end
    return true
end
addonTable.RestoreBlizzardDefaults = RestoreBlizzardDefaults
DynamicSuite.RestoreBlizzardDefaults = RestoreBlizzardDefaults

--------------------------------------------------------------------------------
-- Active Addon Conflict Scanner, Smart Sub-Module Detector & Auto-Yield Engine
--------------------------------------------------------------------------------
local simulatedConflictPreview = false
local activeSoftYieldCache = {}
local newlyDetectedHardConflictsCache = {}

function addonTable.SetSimulatedConflictPreview(enabled)
    simulatedConflictPreview = (enabled == true)
    if addonTable.InvalidateConflictCache then
        addonTable.InvalidateConflictCache()
    end
end

function addonTable.GetSimulatedConflictPreview()
    return simulatedConflictPreview
end

local function SafeIsAddOnLoaded(addonFolder)
    if not addonFolder or type(addonFolder) ~= "string" then return false end
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, addonFolder)
        if ok and loaded == true then
            return true
        end
    end
    return false
end
addonTable.SafeIsAddOnLoaded = SafeIsAddOnLoaded
DynamicSuite.SafeIsAddOnLoaded = SafeIsAddOnLoaded

-- Checks if an addon is enabled in the WoW client (by folder name or stripped Title).
local function SafeIsAddOnEnabledInClient(addonKey, pName)
    if not addonKey or type(addonKey) ~= "string" or not C_AddOns then return false end
    if type(C_AddOns.GetAddOnEnableState) == "function" then
        local ok, st = pcall(C_AddOns.GetAddOnEnableState, addonKey, pName)
        if ok and type(st) == "number" and st > 0 then
            return true
        end
    end
    if type(C_AddOns.GetNumAddOns) == "function" and type(C_AddOns.GetAddOnInfo) == "function" and type(C_AddOns.GetAddOnEnableState) == "function" then
        local target = addonKey:gsub("_", " "):lower()
        local num = C_AddOns.GetNumAddOns() or 0
        for i = 1, num do
            local name, title = C_AddOns.GetAddOnInfo(i)
            if name then
                local cleanTitle = type(title) == "string" and title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("_", " "):lower() or ""
                if name:lower() == addonKey:lower() or cleanTitle == target then
                    local ok, st = pcall(C_AddOns.GetAddOnEnableState, name, pName)
                    if ok and type(st) == "number" and st > 0 then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function IsExternalAddonFrozen(addonFolder)
    if not addonFolder or type(addonFolder) ~= "string" then return false end
    if addonTable.IsAddonFrozen and addonTable.IsAddonFrozen(addonFolder) then
        return true
    end
    if _G.DynamicSuite and _G.DynamicSuite.IsAddonFrozen and _G.DynamicSuite.IsAddonFrozen(addonFolder) then
        return true
    end
    if _G.DynamicLoadDB then
        if _G.DynamicLoadDB.addonStates and _G.DynamicLoadDB.addonStates[addonFolder] == "FROZEN" then
            return true
        end
        if _G.DynamicLoadDB.frozenAddons and _G.DynamicLoadDB.frozenAddons[addonFolder] == true then
            return true
        end
        if _G.DynamicLoadDB.globalData then
            if _G.DynamicLoadDB.globalData.addonStates and _G.DynamicLoadDB.globalData.addonStates[addonFolder] == "FROZEN" then
                return true
            end
            if _G.DynamicLoadDB.globalData.frozenAddons and _G.DynamicLoadDB.globalData.frozenAddons[addonFolder] == true then
                return true
            end
        end
    end
    return false
end
addonTable.IsExternalAddonFrozen = IsExternalAddonFrozen
DynamicSuite.IsExternalAddonFrozen = IsExternalAddonFrozen

-- Smart Sub-Module Detection for ElvUI, Leatrix_Plus, and EllesmereUI (wrapped in pcall for zero Lua errors)
local function InspectSmartSubModuleConflict(dynamicModule, otherAddon)
    if IsExternalAddonFrozen(otherAddon) then
        return false, nil, nil
    end
    local shortKey = tostring(dynamicModule or ""):gsub("^Dynamic", ""):lower()
    if otherAddon == "ElvUI" then
        if not SafeIsAddOnLoaded("ElvUI") then
            return false, nil, nil
        end
        local ok, isSubActive, subTier, subFeature = pcall(function()
            local E = type(_G.ElvUI) == "table" and _G.ElvUI[1] or nil
            if type(E) ~= "table" then return false end
            if shortKey == "bags" or dynamicModule == "DynamicBags" then
                if E.private and E.private.bags and E.private.bags.enable == true then
                    return true, "HARD", "bag frame replacement"
                end
                return false
            elseif shortKey == "chat" or dynamicModule == "DynamicChat" then
                if E.private and E.private.chat and E.private.chat.enable == true then
                    return true, "HARD", "chat skin/frame control"
                end
                return false
            elseif shortKey == "prep" or dynamicModule == "DynamicPrep" then
                if E.db and E.db.general then
                    if (E.db.general.autoRepair and E.db.general.autoRepair ~= "NONE")
                        or E.db.general.vendorGrays == true
                        or E.db.general.autoAcceptInvite == true then
                        return true, "SOFT", "shared automation features"
                    end
                end
                return false
            end
            return false
        end)
        if ok and isSubActive == true then
            return true, subTier or "SOFT", subFeature
        end
        return false, nil, nil

    elseif otherAddon == "Leatrix_Plus" then
        if not SafeIsAddOnLoaded("Leatrix_Plus") then
            return false, nil, nil
        end
        local ok, isSubActive, subTier, subFeature = pcall(function()
            local ldb = _G.LeaPlusDB
            if type(ldb) ~= "table" then return false end
            if shortKey == "bags" or dynamicModule == "DynamicBags" then
                if ldb["AutoSellJunk"] == "On" or ldb["AutoRepairGear"] == "On" or ldb["FasterLooting"] == "On" then
                    return true, "SOFT", "vendor/loot automation"
                end
                return false
            elseif shortKey == "chat" or dynamicModule == "DynamicChat" then
                if ldb["HideChatButtons"] == "On" or ldb["RecentChatWindow"] == "On" or ldb["ClassColPlayer"] == "On" or ldb["NoChatFade"] == "On" then
                    return true, "SOFT", "shared chat features"
                end
                return false
            elseif shortKey == "prep" or dynamicModule == "DynamicPrep" then
                if ldb["AutomateQuests"] == "On" or ldb["AutomateGossip"] == "On" or ldb["FasterMovieSkip"] == "On" or ldb["AcceptResurrect"] == "On" then
                    return true, "SOFT", "quest/gossip control"
                end
                return false
            elseif shortKey == "zoom" or dynamicModule == "DynamicZoom" then
                if ldb["MaxCameraZoom"] == "On" then
                    return true, "SOFT", "camera zoom control"
                end
                return false
            end
            return false
        end)
        if ok and isSubActive == true then
            return true, subTier or "SOFT", subFeature
        end
        return false, nil, nil

    elseif otherAddon == "EllesmereUI" then
        if not SafeIsAddOnLoaded("EllesmereUI") then
            return false, nil, nil
        end
        local ok, isSubActive, subTier, subFeature = pcall(function()
            if shortKey == "chat" or dynamicModule == "DynamicChat" then
                -- If EllesmereUIChat is installed as a separate sub-addon on disk, conflict detection
                -- belongs strictly to the EllesmereUIChat sub-addon entry.
                if C_AddOns and C_AddOns.GetAddOnInfo then
                    if C_AddOns.GetAddOnInfo("EllesmereUIChat") ~= nil or C_AddOns.GetAddOnInfo("EllesmereUI_Chat") ~= nil then
                        return false
                    end
                end
                if IsExternalAddonFrozen("EllesmereUIChat") or IsExternalAddonFrozen("EllesmereUI_Chat") then
                    return false
                end
                local edb = _G.EllesmereUIDB
                if type(edb) == "table" then
                    if type(edb.chat) == "table" and edb.chat.enable == false then
                        return false
                    end
                    if type(edb.modules) == "table" and edb.modules.chat == false then
                        return false
                    end
                end
                return true, "HARD", "chat/editbox skinning"
            elseif shortKey == "bags" or dynamicModule == "DynamicBags" then
                -- If EllesmereUIBags is installed as a separate sub-addon on disk, conflict detection
                -- belongs strictly to the EllesmereUIBags sub-addon entry.
                if C_AddOns and C_AddOns.GetAddOnInfo then
                    if C_AddOns.GetAddOnInfo("EllesmereUIBags") ~= nil or C_AddOns.GetAddOnInfo("EllesmereUI_Bags") ~= nil then
                        return false
                    end
                end
                if IsExternalAddonFrozen("EllesmereUIBags") or IsExternalAddonFrozen("EllesmereUI_Bags") then
                    return false
                end
                local edb = _G.EllesmereUIDB
                if type(edb) == "table" then
                    if type(edb.bags) == "table" and edb.bags.enable == false then
                        return false
                    end
                    if type(edb.modules) == "table" and edb.modules.bags == false then
                        return false
                    end
                end
                return true, "HARD", "bag/bank frame replacement"
            end
            return false
        end)
        if ok and isSubActive == true then
            return true, subTier or "HARD", subFeature
        end
        return false, nil, nil
    end
    return nil, nil, nil
end
addonTable.InspectSmartSubModuleConflict = InspectSmartSubModuleConflict
DynamicSuite.InspectSmartSubModuleConflict = InspectSmartSubModuleConflict

local function IsQueuedInDynamicLoad(addonFolder)
    if not addonFolder or type(addonFolder) ~= "string" then return false end
    if IsExternalAddonFrozen(addonFolder) then return false end
    if C_AddOns and C_AddOns.GetAddOnInfo and C_AddOns.GetAddOnInfo(addonFolder) == nil then
        return false
    end
    local dl = _G.DynamicLoadDB
    if type(dl) ~= "table" then return false end
    local states = (dl.globalData and dl.globalData.addonStates) or dl.addonStates
    if type(states) == "table" and states[addonFolder] == "LOCKED" then
        return true
    end
    local locked = (dl.globalData and dl.globalData.lockedAddons) or dl.lockedAddons
    if type(locked) == "table" and locked[addonFolder] == true then
        return true
    end
    local zData = (dl.globalData and dl.globalData.zoneData) or dl.zoneData
    if type(zData) == "table" then
        for _, zKey in ipairs({ "GLOBAL", "RAID", "MYTHIC_PLUS", "DELVES", "PVP", "OPEN_WORLD" }) do
            if type(zData[zKey]) == "table" and zData[zKey][addonFolder] == true then
                return true
            end
        end
    end
    return false
end

local function IsThirdPartyConflictActive(dynamicModule, otherAddon, pName)
    if otherAddon == "ElvUI" or otherAddon == "Leatrix_Plus" or otherAddon == "EllesmereUI" then
        if IsExternalAddonFrozen(otherAddon) then
            return false, nil, nil
        end
        return InspectSmartSubModuleConflict(dynamicModule, otherAddon)
    end
    if SafeIsAddOnLoaded(otherAddon) then
        return true, "HARD", nil
    end
    if IsExternalAddonFrozen(otherAddon) then
        return false, nil, nil
    end
    if SafeIsAddOnEnabledInClient(otherAddon, pName) or IsQueuedInDynamicLoad(otherAddon) then
        return true, "HARD", nil
    end
    return false, nil, nil
end

local function NormalizeSuiteModuleName(modKeyOrName)
    local s = tostring(modKeyOrName or "")
    local low = s:gsub("^Dynamic", ""):lower()
    if low == "load" then return "DynamicLoad", "load"
    elseif low == "marker" then return "DynamicMarker", "marker"
    elseif low == "zoom" then return "DynamicZoom", "zoom"
    elseif low == "fps" then return "DynamicFPS", "fps"
    elseif low == "prep" then return "DynamicPrep", "prep"
    elseif low == "group" then return "DynamicGroup", "group"
    elseif low == "bags" then return "DynamicBags", "bags"
    elseif low == "chat" then return "DynamicChat", "chat"
    end
    return s, low
end

local function ClearAllLegacyYieldState()
    local g = EnsureSuiteGlobal()
    if type(g.yieldHooks) == "table" then wipe(g.yieldHooks) end
    if type(g.acknowledgedConflicts) == "table" then
        for k, v in pairs(g.acknowledgedConflicts) do
            if v == true or v == "AUTO_YIELD" or v == "RUN_BOTH" then
                g.acknowledgedConflicts[k] = nil
            end
        end
    end
    for _, dbTbl in ipairs({ _G.DynamicPrepDB, _G.DynamicZoomDB, _G.DynamicChatDB, _G.DynamicFPSDB, _G.DynamicBagsDB }) do
        if type(dbTbl) == "table" then
            if type(dbTbl.yieldHooks) == "table" then wipe(dbTbl.yieldHooks) end
            if dbTbl.yieldSharedHooks ~= nil then dbTbl.yieldSharedHooks = false end
        end
    end
end

local function ClearAutoYieldFromModuleDB(modKey, addonNameKey, otherAddon)
    ClearAllLegacyYieldState()
end

local function BuildConflictItem(modInfo, reg, otherAddon, isGranular, smartFeature, isSim)
    local addonNameKey, modKey = NormalizeSuiteModuleName(modInfo.addonName or modInfo.name or modInfo.key)
    local conflictKey = tostring(otherAddon) .. "_" .. tostring(addonNameKey)
    local g = EnsureSuiteGlobal()
    g.acknowledgedConflicts = type(g.acknowledgedConflicts) == "table" and g.acknowledgedConflicts or {}
    g.granularModes = type(g.granularModes) == "table" and g.granularModes or {}
    local tier = (isGranular == true) and 2 or 1
    local ackAction = g.acknowledgedConflicts[conflictKey]

    if tier == 1 then
        if ackAction == "PREFER_DYNAMIC" then
            ackAction = "USE_DYNAMIC"
        elseif ackAction == "PREFER_EXTERNAL" then
            ackAction = "KEEP_OTHER"
        elseif ackAction ~= "USE_DYNAMIC" and ackAction ~= "KEEP_OTHER" then
            ackAction = nil
            g.acknowledgedConflicts[conflictKey] = nil
        end

        -- Never let a stale resolution flag hide an active Tier 1 conflict when both sides are still enabled.
        local isModDisabled = IsSuiteModuleExplicitlyDisabled(addonNameKey)
        local isOtherFrozen = IsExternalAddonFrozen(otherAddon)
        if not isSim then
            if ackAction == "USE_DYNAMIC" and not isOtherFrozen then
                if otherAddon ~= "ElvUI" then
                    ackAction = nil
                else
                    local stillEnabled = false
                    pcall(function()
                        local E = type(_G.ElvUI) == "table" and _G.ElvUI[1] or nil
                        if E and E.private then
                            if modKey == "bags" and E.private.bags and E.private.bags.enable == true then stillEnabled = true end
                            if modKey == "chat" and E.private.chat and E.private.chat.enable == true then stillEnabled = true end
                        end
                    end)
                    if stillEnabled then ackAction = nil end
                end
            elseif ackAction == "KEEP_OTHER" and not isModDisabled then
                ackAction = nil
            end
        end
    else
        if ackAction == "PREFER_DYNAMIC" or ackAction == "USE_DYNAMIC" then
            ackAction = "PRIORITISE_DYNAMIC"
        elseif ackAction == "PREFER_EXTERNAL" or ackAction == "KEEP_OTHER" then
            ackAction = "YIELD_TO_EXTERNAL"
        elseif ackAction ~= "PRIORITISE_DYNAMIC" and ackAction ~= "YIELD_TO_EXTERNAL" then
            ackAction = g.granularModes[conflictKey]
            if ackAction ~= "PRIORITISE_DYNAMIC" and ackAction ~= "YIELD_TO_EXTERNAL" then
                ackAction = nil
                g.acknowledgedConflicts[conflictKey] = nil
            end
        end
    end

    local friendly = FRIENDLY_CONFLICT_NAMES[otherAddon] or otherAddon
    local displayTarget = (otherAddon == "DialogueUI" or otherAddon == "DialogUI" or otherAddon == "Plumber" or otherAddon == "Baganator" or otherAddon == "Immersion" or otherAddon == "Storyline" or otherAddon == "AutoTurnIn" or otherAddon == "WIM" or otherAddon == "EllesmereUI")
        and otherAddon or friendly
    local bannerText = (tier == 2)
        and string.format("QoL Overlap: %s shares sub-features with %s. Choose which addon owns the shared triggers.", displayTarget, addonNameKey)
        or string.format("Conflict Detected: %s is currently active and may cause UI errors or duplicate frames.", displayTarget)
    return {
        conflictKey    = conflictKey,
        dynamicModule  = addonNameKey,
        moduleKey      = modKey,
        conflictAddon  = otherAddon,
        friendlyName   = friendly,
        category       = reg and reg.category or modInfo.category or addonNameKey,
        tier           = tier,
        severity       = (tier == 2) and "GRANULAR" or "HARD",
        isPartial      = (tier == 2),
        isGranular     = (tier == 2),
        isAutoYielded  = false,
        isAcknowledged = (ackAction ~= nil),
        resolvedAction = ackAction,
        yieldFeature   = smartFeature or CONFLICT_YIELD_FEATURES[otherAddon],
        bannerText     = bannerText,
        hasMigration   = (reg and reg.hasLegacyMigration and reg.hasLegacyMigration[otherAddon]) or false,
        isSimulated    = (isSim == true),
    }
end

local function ScanAllConflicts(includeGranular, includeAcknowledgedDisabled)
    local results = {}
    local seen = {}
    local pName = GetPlayer()
    ClearAllLegacyYieldState()
    local g = EnsureSuiteGlobal()
    g.acknowledgedConflicts = type(g.acknowledgedConflicts) == "table" and g.acknowledgedConflicts or {}
    wipe(activeSoftYieldCache)

    for _, modInfo in ipairs(SUITE_MODULE_LIST) do
        local addonNameKey, modKey = NormalizeSuiteModuleName(modInfo.addonName or modInfo.name or modInfo.key)
        local reg = (_G.DynamicSuite and _G.DynamicSuite.CONFLICT_REGISTRY and (_G.DynamicSuite.CONFLICT_REGISTRY[addonNameKey] or _G.DynamicSuite.CONFLICT_REGISTRY[modKey]))
            or CONFLICT_REGISTRY[addonNameKey]
            or CONFLICT_REGISTRY[modKey]
        local isModDisabled = IsSuiteModuleExplicitlyDisabled(addonNameKey)
        if reg and (not isModDisabled or includeAcknowledgedDisabled == true) then
            local targetSpecs = {}
            for _, a in ipairs(reg.hardConflicts or reg.conflicts or {}) do
                table.insert(targetSpecs, { addon = a, isGranular = false })
            end
            if includeGranular ~= false then
                for _, a in ipairs(reg.softConflicts or reg.partialConflicts or {}) do
                    table.insert(targetSpecs, { addon = a, isGranular = true })
                end
            end
            for _, spec in ipairs(targetSpecs) do
                local otherAddon = spec.addon
                local conflictKey = tostring(otherAddon) .. "_" .. tostring(addonNameKey)
                local rawAck = g.acknowledgedConflicts[conflictKey]
                if (not isModDisabled) or (rawAck == "KEEP_OTHER" or rawAck == "PREFER_EXTERNAL") then
                    local isActive, subTier, smartFeature = IsThirdPartyConflictActive(addonNameKey, otherAddon, pName)
                    if isActive then
                        local itemGranular = spec.isGranular or (subTier == "SOFT" or subTier == "GRANULAR")
                        local friendly = FRIENDLY_CONFLICT_NAMES[otherAddon] or otherAddon
                        local legacyKey = modKey .. ":" .. friendly
                        if not seen[conflictKey] and not seen[legacyKey] then
                            seen[conflictKey] = true
                            seen[legacyKey] = true
                            local item = BuildConflictItem(modInfo, reg, otherAddon, itemGranular, smartFeature, false)
                            table.insert(results, item)
                        end
                    end
                end
            end
        end
    end

    table.sort(results, function(a, b)
        if (a.tier or 1) ~= (b.tier or 1) then
            return (a.tier or 1) < (b.tier or 1)
        end
        local aRes = (a.resolvedAction ~= nil) and 1 or 0
        local bRes = (b.resolvedAction ~= nil) and 1 or 0
        if aRes ~= bRes then
            return aRes < bRes
        end
        return tostring(a.conflictKey) < tostring(b.conflictKey)
    end)

    if simulatedConflictPreview and #results == 0 then
        table.insert(results, BuildConflictItem(
            { key = "bags", addonName = "DynamicBags", category = "Inventory & Bags" },
            CONFLICT_REGISTRY.DynamicBags,
            "EllesmereUIBags",
            false,
            nil,
            true
        ))
        table.insert(results, BuildConflictItem(
            { key = "chat", addonName = "DynamicChat", category = "Chat & Communications" },
            CONFLICT_REGISTRY.DynamicChat,
            "EllesmereUIChat",
            false,
            nil,
            true
        ))
    end

    return results
end
addonTable.ScanAllConflicts = ScanAllConflicts
DynamicSuite.ScanConflicts = ScanAllConflicts
DynamicSuite.ScanAllConflicts = ScanAllConflicts

local conflictCacheDirty = true
local cachedConflictSummary = {
    byModule = {},
    totalUnresolved = 0,
    tier1Unresolved = 0,
    tier2Unresolved = 0,
}
local emptyConflictList = {}

local function InvalidateConflictCache()
    conflictCacheDirty = true
end
addonTable.InvalidateConflictCache = InvalidateConflictCache
DynamicSuite.InvalidateConflictCache = InvalidateConflictCache

local function EnsureConflictCache()
    if not conflictCacheDirty then
        return cachedConflictSummary
    end
    conflictCacheDirty = false
    wipe(cachedConflictSummary.byModule)
    cachedConflictSummary.totalUnresolved = 0
    cachedConflictSummary.tier1Unresolved = 0
    cachedConflictSummary.tier2Unresolved = 0

    local raw = ScanAllConflicts(true, true)
    local seen = {}
    for _, item in ipairs(raw) do
        local dKey = item.conflictKey or (tostring(item.conflictAddon or "") .. "_" .. tostring(item.dynamicModule or ""))
        if not seen[dKey] then
            seen[dKey] = true
            local isTier2 = (item.tier == 2 or item.isGranular)
            if not item.isAcknowledged then
                cachedConflictSummary.totalUnresolved = cachedConflictSummary.totalUnresolved + 1
                if isTier2 then
                    cachedConflictSummary.tier2Unresolved = cachedConflictSummary.tier2Unresolved + 1
                else
                    cachedConflictSummary.tier1Unresolved = cachedConflictSummary.tier1Unresolved + 1
                end
            end

            local itemShort = tostring(item.moduleKey or item.dynamicModule or ""):gsub("^Dynamic", ""):lower()
            local modDisabled = IsSuiteModuleExplicitlyDisabled(item.dynamicModule or itemShort)
            if not (modDisabled and item.isAcknowledged) then
                local bucket = cachedConflictSummary.byModule[itemShort]
                if not bucket then
                    bucket = { all = {}, hard = {}, soft = {}, hasUnackHard = false, hasUnackSoft = false }
                    cachedConflictSummary.byModule[itemShort] = bucket
                end
                table.insert(bucket.all, item)
                if isTier2 then
                    table.insert(bucket.soft, item)
                    if not item.isAcknowledged then
                        bucket.hasUnackSoft = true
                    end
                else
                    table.insert(bucket.hard, item)
                    if not item.isAcknowledged then
                        bucket.hasUnackHard = true
                    end
                end
            end
        end
    end
    return cachedConflictSummary
end

local function GetUnresolvedConflictCount()
    local cache = EnsureConflictCache()
    return cache.totalUnresolved, cache.tier1Unresolved, cache.tier2Unresolved
end
addonTable.GetUnresolvedConflictCount = GetUnresolvedConflictCount
DynamicSuite.GetUnresolvedConflictCount = GetUnresolvedConflictCount

local function GetUnresolvedActionRequiredConflicts()
    local raw = ScanAllConflicts(false, true)
    local seen = {}
    local unresolved = {}
    for _, item in ipairs(raw) do
        local dKey = item.conflictKey or (tostring(item.conflictAddon or "") .. "_" .. tostring(item.dynamicModule or ""))
        if not seen[dKey] then
            seen[dKey] = true
            if not item.isSimulated and not (item.tier == 2 or item.isGranular) and not item.isAcknowledged then
                table.insert(unresolved, item)
            end
        end
    end
    return unresolved
end
addonTable.GetUnresolvedActionRequiredConflicts = GetUnresolvedActionRequiredConflicts
DynamicSuite.GetUnresolvedActionRequiredConflicts = GetUnresolvedActionRequiredConflicts

local function GetModuleConflicts(modKeyOrName)
    if not modKeyOrName then return emptyConflictList, emptyConflictList, emptyConflictList end
    local shortKey = tostring(modKeyOrName):gsub("^Dynamic", ""):lower()
    local cache = EnsureConflictCache()
    local bucket = cache.byModule[shortKey]
    if not bucket then
        return emptyConflictList, emptyConflictList, emptyConflictList
    end
    return bucket.all, bucket.hard, bucket.soft
end
addonTable.GetModuleConflicts = GetModuleConflicts
DynamicSuite.GetModuleConflicts = GetModuleConflicts

local function GetCachedModuleConflictFlags(modKeyOrName)
    if not modKeyOrName then return false, false end
    local shortKey = tostring(modKeyOrName):gsub("^Dynamic", ""):lower()
    local cache = EnsureConflictCache()
    local bucket = cache.byModule[shortKey]
    if not bucket then
        return false, false
    end
    return bucket.hasUnackHard, bucket.hasUnackSoft
end
addonTable.GetCachedModuleConflictFlags = GetCachedModuleConflictFlags
DynamicSuite.GetCachedModuleConflictFlags = GetCachedModuleConflictFlags

local function GetGranularConflictMode(dynamicModule, conflictAddon)
    local canonMod = NormalizeSuiteModuleName(dynamicModule)
    local g = EnsureSuiteGlobal()
    g.granularModes = type(g.granularModes) == "table" and g.granularModes or {}
    if conflictAddon then
        local cKey = tostring(conflictAddon) .. "_" .. tostring(canonMod)
        return g.granularModes[cKey]
    end
    return nil
end
addonTable.GetGranularConflictMode = GetGranularConflictMode
DynamicSuite.GetGranularConflictMode = GetGranularConflictMode

local function HasPrioritisedQoLOverlap(dynamicModule)
    local canonMod = NormalizeSuiteModuleName(dynamicModule)
    local _, _, modGranular = GetModuleConflicts(canonMod)
    for _, item in ipairs(modGranular) do
        if item.resolvedAction ~= "YIELD_TO_EXTERNAL" then
            return true, item.conflictAddon
        end
    end
    return false, nil
end
addonTable.HasPrioritisedQoLOverlap = HasPrioritisedQoLOverlap
DynamicSuite.HasPrioritisedQoLOverlap = HasPrioritisedQoLOverlap

function DynamicSuite:IsAutoYielding(modKeyOrName, specificAddon)
    return false, nil, nil, nil
end
addonTable.IsAutoYielding = function(modKeyOrName, specificAddon)
    return false, nil, nil, nil
end

local function CheckConflictingManagers()
    local conflicts = {}
    local _, hardList = GetModuleConflicts("DynamicLoad")
    for _, item in ipairs(hardList) do
        if not item.isSimulated then
            table.insert(conflicts, item.friendlyName)
        end
    end
    return conflicts
end
addonTable.CheckConflictingManagers = CheckConflictingManagers

local function RunLoginConflictScan()
    local g = EnsureSuiteGlobal()
    g.seenHardConflicts = type(g.seenHardConflicts) == "table" and g.seenHardConflicts or {}
    local all = ScanAllConflicts(true)
    local activeHardKeys = {}
    wipe(newlyDetectedHardConflictsCache)

    for _, item in ipairs(all) do
        if not item.isSimulated and (item.severity == "HARD" or not item.isPartial) then
            local cKey = tostring(item.dynamicModule) .. ":" .. tostring(item.conflictAddon)
            activeHardKeys[cKey] = true
            if not g.seenHardConflicts[cKey] then
                g.seenHardConflicts[cKey] = true
                table.insert(newlyDetectedHardConflictsCache, item)
            end
        end
    end

    for oldKey in pairs(g.seenHardConflicts) do
        if not activeHardKeys[oldKey] then
            g.seenHardConflicts[oldKey] = nil
        end
    end

    if #newlyDetectedHardConflictsCache > 0 then
        local first = newlyDetectedHardConflictsCache[1]
        if #newlyDetectedHardConflictsCache == 1 then
            print(string.format("%s: |cFFF5B82EConflict Detected:|r |cFFFFFFFF%s|r is currently active alongside |cFFFFFFFF%s|r and may cause UI errors or blocked actions. Type |cFF38BDF8/ds conflicts|r to resolve.", ADDON_TITLE, first.conflictAddon, first.dynamicModule))
        else
            print(string.format("%s: |cFFF5B82E%d Addon Conflicts Detected|r (including |cFFFFFFFF%s|r + |cFFFFFFFF%s|r). Type |cFF38BDF8/ds conflicts|r to inspect or resolve.", ADDON_TITLE, #newlyDetectedHardConflictsCache, first.conflictAddon, first.dynamicModule))
        end
    end

    return all, newlyDetectedHardConflictsCache
end
addonTable.RunLoginConflictScan = RunLoginConflictScan
DynamicSuite.RunLoginConflictScan = RunLoginConflictScan

function addonTable.GetNewlyDetectedHardConflicts()
    return newlyDetectedHardConflictsCache
end

local function PrintConflictSummary()
    local all = ScanAllConflicts(true)
    local hardList, softList = {}, {}
    for _, item in ipairs(all) do
        if item.severity == "HARD" or not item.isPartial then
            table.insert(hardList, item)
        else
            table.insert(softList, item)
        end
    end

    if #hardList == 0 and #softList == 0 then
        print(string.format("%s |cFF22C55E[Conflict Diagnostic]|r: Zero active third-party addon conflicts or overlaps detected across all 8 DynamicSuite modules.", ADDON_TITLE))
        return all
    end

    print(string.format("%s |cFFF5B82E[Conflict Diagnostic Summary]|r: %d Tier-1 HARD conflict(s), %d Tier-2 QoL overlap(s) active:", ADDON_TITLE, #hardList, #softList))
    for _, item in ipairs(hardList) do
        print(string.format("  |cFFEF4444[HARD]|r |cFFFFFFFF%s|r <-> |cFFFFFFFF%s|r: %s", item.dynamicModule, item.conflictAddon, item.bannerText))
    end
    for _, item in ipairs(softList) do
        print(string.format("  |cFF38BDF8[QoL]|r |cFFFFFFFF%s|r <-> |cFFFFFFFF%s|r: %s", item.dynamicModule, item.conflictAddon, item.bannerText))
    end
    return all
end
addonTable.PrintConflictSummary = PrintConflictSummary
DynamicSuite.PrintConflictSummary = PrintConflictSummary

local function ResolveConflict(dynamicModule, conflictAddon, action, isSimulated)
    local pName = GetPlayer()
    local g = EnsureSuiteGlobal()
    local canonMod, shortKey = NormalizeSuiteModuleName(dynamicModule)
    local conflictKey = tostring(conflictAddon) .. "_" .. tostring(canonMod)

    if action == "PREFER_DYNAMIC" then
        action = "USE_DYNAMIC"
    elseif action == "PREFER_EXTERNAL" then
        action = "KEEP_OTHER"
    end

    g.acknowledgedConflicts = type(g.acknowledgedConflicts) == "table" and g.acknowledgedConflicts or {}
    local prevAck = g.acknowledgedConflicts[conflictKey]
    g.acknowledgedConflicts[conflictKey] = action
    if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.global) == "table" then
        _G.DynamicSuiteDB.global.acknowledgedConflicts = type(_G.DynamicSuiteDB.global.acknowledgedConflicts) == "table" and _G.DynamicSuiteDB.global.acknowledgedConflicts or {}
        if prevAck == nil then
            prevAck = _G.DynamicSuiteDB.global.acknowledgedConflicts[conflictKey]
        end
        _G.DynamicSuiteDB.global.acknowledgedConflicts[conflictKey] = action
    end

    if action == "USE_DYNAMIC" or action == "KEEP_OTHER" then
        addonTable._conflictPendingReload = true
    end
    InvalidateConflictCache()

    if isSimulated then
        if addonTable.mainFrame and addonTable.mainFrame.UpdateModuleConflictBanner then
            pcall(addonTable.mainFrame.UpdateModuleConflictBanner)
        end
        if addonTable.mainFrame and addonTable.mainFrame.RefreshLeftRailVisuals then
            pcall(addonTable.mainFrame.RefreshLeftRailVisuals)
        end
        return
    end

    if action == "USE_DYNAMIC" then
        if conflictAddon == "FocusMarker" and _G.FocusMarkerDB then
            if _G.DynamicMarker and type(_G.DynamicMarker.MigrateFromFocusMarker) == "function" then
                local okM, migrated = pcall(_G.DynamicMarker.MigrateFromFocusMarker, _G.DynamicMarker, true)
                if okM and migrated then
                    print(string.format("%s: Migrated FocusMarker settings into DynamicMarkerDB.", ADDON_TITLE))
                end
            else
                _G.DynamicMarkerDB = _G.DynamicMarkerDB or {}
                if type(_G.FocusMarkerDB) == "table" and not _G.DynamicMarkerDB.migratedFromFocusMarker then
                    for k, v in pairs(_G.FocusMarkerDB) do
                        if _G.DynamicMarkerDB[k] == nil then
                            if type(v) == "table" then
                                _G.DynamicMarkerDB[k] = CopyTable(v)
                            else
                                _G.DynamicMarkerDB[k] = v
                            end
                        end
                    end
                    _G.DynamicMarkerDB.migratedFromFocusMarker = true
                    print(string.format("%s: Migrated FocusMarker settings into DynamicMarkerDB.", ADDON_TITLE))
                end
            end
        end

        ClearAutoYieldFromModuleDB(shortKey, canonMod, conflictAddon)

        -- If resolving an EllesmereUI overlap for DynamicChat, DynamicBags, or DynamicGroup and a dedicated
        -- sub-addon exists on disk, target the sub-addon rather than the parent core suite.
        local freezeTargets = {}
        local function AddFreezeTarget(t)
            if t and t ~= "" then
                for _, existing in ipairs(freezeTargets) do
                    if existing == t then return end
                end
                table.insert(freezeTargets, t)
            end
        end

        if conflictAddon == "ElvUI" and (canonMod == "DynamicBags" or shortKey == "bags" or canonMod == "DynamicChat" or shortKey == "chat") then
            pcall(function()
                local E = type(_G.ElvUI) == "table" and _G.ElvUI[1] or nil
                if type(E) == "table" and type(E.private) == "table" then
                    if (canonMod == "DynamicBags" or shortKey == "bags") and type(E.private.bags) == "table" then
                        E.private.bags.enable = false
                    elseif (canonMod == "DynamicChat" or shortKey == "chat") and type(E.private.chat) == "table" then
                        E.private.chat.enable = false
                    end
                end
            end)
            print(string.format("%s: Disabled ElvUI %s module in E.private. Using %s only (reload UI to apply).", ADDON_TITLE, (shortKey == "bags") and "Bags" or "Chat", canonMod))
        else
            if conflictAddon == "EllesmereUI" and C_AddOns and C_AddOns.GetAddOnInfo then
                if canonMod == "DynamicChat" or shortKey == "chat" then
                    if C_AddOns.GetAddOnInfo("EllesmereUIChat") ~= nil then AddFreezeTarget("EllesmereUIChat") end
                    if C_AddOns.GetAddOnInfo("EllesmereUI_Chat") ~= nil then AddFreezeTarget("EllesmereUI_Chat") end
                elseif canonMod == "DynamicBags" or shortKey == "bags" then
                    if C_AddOns.GetAddOnInfo("EllesmereUIBags") ~= nil then AddFreezeTarget("EllesmereUIBags") end
                    if C_AddOns.GetAddOnInfo("EllesmereUI_Bags") ~= nil then AddFreezeTarget("EllesmereUI_Bags") end
                elseif canonMod == "DynamicGroup" or shortKey == "group" then
                    if C_AddOns.GetAddOnInfo("EllesmereUIGroupFinder") ~= nil then AddFreezeTarget("EllesmereUIGroupFinder") end
                end
            end
            if #freezeTargets == 0 then
                AddFreezeTarget(conflictAddon)
                if conflictAddon == "EllesmereUIChat" then AddFreezeTarget("EllesmereUI_Chat")
                elseif conflictAddon == "EllesmereUI_Chat" then AddFreezeTarget("EllesmereUIChat")
                elseif conflictAddon == "EllesmereUIBags" then AddFreezeTarget("EllesmereUI_Bags")
                elseif conflictAddon == "EllesmereUI_Bags" then AddFreezeTarget("EllesmereUIBags")
                elseif conflictAddon == "ls_Glass" then AddFreezeTarget("LS_Glass")
                elseif conflictAddon == "LS_Glass" then AddFreezeTarget("ls_Glass") end
            end

            for _, ft in ipairs(freezeTargets) do
                if addonTable.SetAddonFrozen then
                    addonTable.SetAddonFrozen(ft, true)
                end
                if C_AddOns and C_AddOns.DisableAddOn then
                    pcall(C_AddOns.DisableAddOn, ft, pName)
                    pcall(C_AddOns.DisableAddOn, ft)
                end
            end
            print(string.format("%s: Disabled & set '%s' to [Never] across all zone profiles. Using %s only (reload UI to apply).", ADDON_TITLE, freezeTargets[1], canonMod))
        end

        SetSuiteModuleEnabled(canonMod, true, true)
        if (canonMod == "DynamicChat" or shortKey == "chat")
            and not IsSuiteModuleExplicitlyDisabled("DynamicChat")
            and _G.DynamicChat and _G.DynamicChat.ApplyAllEngineSettings then
            pcall(_G.DynamicChat.ApplyAllEngineSettings, _G.DynamicChat)
        end

    elseif action == "KEEP_OTHER" then
        SetSuiteModuleEnabled(canonMod, false, true)
        if addonTable.SetAddonFrozen and C_AddOns and C_AddOns.GetAddOnInfo and C_AddOns.GetAddOnInfo(canonMod) ~= nil then
            addonTable.SetAddonFrozen(canonMod, true)
        end
        if addonTable.SetAddonFrozen then
            addonTable.SetAddonFrozen(conflictAddon, false)
        end
        if C_AddOns and C_AddOns.GetAddOnInfo and C_AddOns.GetAddOnInfo(conflictAddon) ~= nil and C_AddOns.EnableAddOn then
            pcall(C_AddOns.EnableAddOn, conflictAddon, pName)
            pcall(C_AddOns.EnableAddOn, conflictAddon)
        end
        print(string.format("%s: Disabled %s and kept '%s' active (reload UI to apply).", ADDON_TITLE, canonMod, conflictAddon))

    elseif action == "PRIORITISE_DYNAMIC" then
        g.granularModes = type(g.granularModes) == "table" and g.granularModes or {}
        g.granularModes[conflictKey] = "PRIORITISE_DYNAMIC"
        if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.global) == "table" then
            _G.DynamicSuiteDB.global.granularModes = type(_G.DynamicSuiteDB.global.granularModes) == "table" and _G.DynamicSuiteDB.global.granularModes or {}
            _G.DynamicSuiteDB.global.granularModes[conflictKey] = "PRIORITISE_DYNAMIC"
        end
        SetSuiteModuleEnabled(canonMod, true, true)
        -- Safely suppress overlapping sub-toggles in Leatrix_Plus / EllesmereUI if accessible
        pcall(function()
            if conflictAddon == "Leatrix_Plus" and type(_G.LeaPlusDB) == "table" then
                if shortKey == "prep" or shortKey == "bags" then
                    _G.LeaPlusDB["AutoRepairGear"] = "Off"
                    _G.LeaPlusDB["AutoSellJunk"] = "Off"
                end
                if shortKey == "prep" then
                    _G.LeaPlusDB["AutomateGossip"] = "Off"
                elseif shortKey == "zoom" then
                    _G.LeaPlusDB["MaxCameraZoom"] = "Off"
                end
            elseif (conflictAddon == "EllesmereUIQoL" or conflictAddon == "EllesmereUI_QoL") and type(_G.EllesmereUIDB) == "table" and type(_G.EllesmereUIDB.qol) == "table" then
                if shortKey == "prep" or shortKey == "bags" then
                    _G.EllesmereUIDB.qol.autoRepair = false
                    _G.EllesmereUIDB.qol.autoSellJunk = false
                end
            end
        end)
        if shortKey == "zoom" and _G.DynamicZoom and _G.DynamicZoom.ApplyAllSettings then
            pcall(_G.DynamicZoom.ApplyAllSettings, _G.DynamicZoom)
        elseif shortKey == "fps" and _G.DynamicFPS and _G.DynamicFPS.ApplyGraphicsPipeline then
            pcall(_G.DynamicFPS.ApplyGraphicsPipeline, true)
        elseif shortKey == "bags" and type(_G.DynamicBagsDB) == "table" then
            _G.DynamicBagsDB.autoRepair = true
            _G.DynamicBagsDB.autoRepairEnabled = true
            _G.DynamicBagsDB.autoSellJunk = true
            _G.DynamicBagsDB.autoSellGrey = true
        end
        print(string.format("%s: Prioritising %s features while keeping %s enabled.", ADDON_TITLE, canonMod, conflictAddon))

    elseif action == "YIELD_TO_EXTERNAL" then
        g.granularModes = type(g.granularModes) == "table" and g.granularModes or {}
        g.granularModes[conflictKey] = "YIELD_TO_EXTERNAL"
        if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.global) == "table" then
            _G.DynamicSuiteDB.global.granularModes = type(_G.DynamicSuiteDB.global.granularModes) == "table" and _G.DynamicSuiteDB.global.granularModes or {}
            _G.DynamicSuiteDB.global.granularModes[conflictKey] = "YIELD_TO_EXTERNAL"
        end
        -- Turn off ONLY overlapping micro-toggles inside DynamicSuite, leaving the rest of the module active
        pcall(function()
            if shortKey == "prep" and type(_G.DynamicPrepDB) == "table" then
                if conflictAddon == "DialogUI" or conflictAddon == "DialogueUI" or conflictAddon == "Plumber" or conflictAddon == "Immersion" or conflictAddon == "Storyline" or conflictAddon == "AutoTurnIn" then
                    _G.DynamicPrepDB.autoGossip = false
                elseif conflictAddon == "EllesmereUIMythicTimer" or conflictAddon == "EllesmereUI_MythicPlus" then
                    _G.DynamicPrepDB.autoKeystone = false
                elseif conflictAddon == "BeQuiet" or conflictAddon == "TalkLess" then
                    _G.DynamicPrepDB.hideTalkingHead = false
                else
                    _G.DynamicPrepDB.autoRepair = false
                    _G.DynamicPrepDB.autoSellJunk = false
                    _G.DynamicPrepDB.autoGossip = false
                end
            elseif shortKey == "bags" and type(_G.DynamicBagsDB) == "table" then
                _G.DynamicBagsDB.autoRepair = false
                _G.DynamicBagsDB.autoRepairEnabled = false
                _G.DynamicBagsDB.autoSellJunk = false
                _G.DynamicBagsDB.autoSellGrey = false
            elseif shortKey == "zoom" and type(_G.DynamicZoomDB) == "table" then
                _G.DynamicZoomDB.yieldCameraMaxZoom = true
            elseif shortKey == "fps" and type(_G.DynamicFPSDB) == "table" then
                _G.DynamicFPSDB.spellQueueMode = "BLIZZARD_DEFAULT"
            end
        end)
        print(string.format("%s: Yielded overlapping %s sub-features to %s (other %s features remain active).", ADDON_TITLE, canonMod, conflictAddon, canonMod))
    end

    if addonTable.mainFrame and addonTable.mainFrame.UpdateModuleConflictBanner then
        pcall(addonTable.mainFrame.UpdateModuleConflictBanner)
    end
    if addonTable.mainFrame and addonTable.mainFrame.RefreshLeftRailVisuals then
        pcall(addonTable.mainFrame.RefreshLeftRailVisuals)
    end
    if addonTable.mainFrame and addonTable.mainFrame.scrollChild and addonTable.mainFrame.scrollChild.Refresh then
        pcall(addonTable.mainFrame.scrollChild.Refresh, addonTable.mainFrame.scrollChild)
    end
    if addonTable.mainFrame and addonTable.mainFrame.UpdateStatusBar then
        pcall(addonTable.mainFrame.UpdateStatusBar)
    end
end
addonTable.ResolveConflict = ResolveConflict
DynamicSuite.ResolveConflict = ResolveConflict

-- L10-B Two-Tone Colinear Speed-Cut "D" Brand Logo Builder
function addonTable.PopulateBrandLogo(badge, size)
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
    tgaWhite:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_white.tga")
    if not tgaWhite:GetTexture() then
        tgaWhite:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\logo_stem_white.tga")
    end
    tgaWhite:SetVertexColor(0.96, 0.97, 0.99, 1)
    badge.tgaWhite = tgaWhite

    local tgaAccent = badge.tgaAccent or badge:CreateTexture(nil, "ARTWORK", nil, 5)
    tgaAccent:ClearAllPoints()
    tgaAccent:SetPoint("TOPLEFT", badge, "TOPLEFT", pad, -pad)
    tgaAccent:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", -pad, pad)
    tgaAccent:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_accent.tga")
    if not tgaAccent:GetTexture() then
        tgaAccent:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\logo_loop_mask.tga")
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
    end
    badge:SetAccentColor(ar, ag, ab, 1)
    return badge
end

--------------------------------------------------------------------------------
-- Extensible Module Registration & Suite Reset Engine
--------------------------------------------------------------------------------
function addonTable.ResetDynamicSuite()
    local preservedSnapshots = (_G.DynamicSuiteDB and type(_G.DynamicSuiteDB.global) == "table" and type(_G.DynamicSuiteDB.global.cvarSnapshots) == "table")
        and _G.DynamicSuiteDB.global.cvarSnapshots or nil
    _G.DynamicSuiteDB = {
        global = CopyTable(DEFAULT_SUITE_GLOBAL)
    }
    if preservedSnapshots then
        _G.DynamicSuiteDB.global.cvarSnapshots = preservedSnapshots
    end
    _G.DynamicSuiteDB.global.v120_windowWidth1040 = true
    if type(_G.DynamicLoadDB) == "table" and type(_G.DynamicLoadDB.charData) == "table" then
        local charKey = GetCurrentCharKey()
        if _G.DynamicLoadDB.charData[charKey] then
            _G.DynamicLoadDB.charData[charKey].theme = nil
        end
        for _, cData in pairs(_G.DynamicLoadDB.charData) do
            if type(cData) == "table" then
                cData.theme = nil
            end
        end
    end
    if addonTable.ResetDynamicLoad then
        addonTable.ResetDynamicLoad()
    end
    local seenMods = {}
    for _, m in pairs(DynamicSuite.modules) do
        if type(m) == "table" and not seenMods[m] then
            seenMods[m] = true
            local rFn = m.ResetModule or m.ResetDefaults or m.ResetModuleDefaults or m.Reset
            if type(rFn) == "function" then
                pcall(rFn, m)
            end
        end
    end
    if addonTable.ApplySuiteThemeAndGeometry then
        addonTable.ApplySuiteThemeAndGeometry()
    end
    print(string.format("%s: Entire DynamicSuite configuration (Theme, Window Geometry, HUDs, and Profiles) reset to factory defaults.", ADDON_TITLE))
end

DynamicSuite.ResetModule = function(arg1, arg2)
    local modKey = (arg1 == DynamicSuite or type(arg1) == "table") and arg2 or arg1
    if not modKey or modKey == "DynamicLoad" or modKey == "load" then
        if addonTable.ResetDynamicLoad then
            addonTable.ResetDynamicLoad()
        end
    elseif DynamicSuite.modules[modKey] then
        local m = DynamicSuite.modules[modKey]
        local rFn = m.ResetModule or m.ResetDefaults or m.ResetModuleDefaults or m.Reset
        if type(rFn) == "function" then
            pcall(rFn, m)
        end
    end
end

DynamicSuite.ResetAllSuite = function()
    addonTable.ResetDynamicSuite()
end

DynamicSuite.RegisterModule = function(arg1, arg2, arg3)
    local modKey, modTable
    if arg1 == DynamicSuite or (type(arg1) == "table" and type(arg2) == "string") then
        modKey, modTable = arg2, arg3
    else
        modKey, modTable = arg1, arg2
    end
    if not modKey or type(modTable) ~= "table" then return end
    local shortKey = tostring(modKey):gsub("^Dynamic", ""):lower()
    local addonNameKey = modTable.addonName or modTable.name or (shortKey == modKey and ("Dynamic" .. shortKey:sub(1, 1):upper() .. shortKey:sub(2)) or tostring(modKey))

    DynamicSuite.modules[modKey] = modTable
    DynamicSuite.modules[shortKey] = modTable
    DynamicSuite.modules[addonNameKey] = modTable

    CORE_SUITE_ADDONS[addonNameKey] = true

    if type(modTable.conflictRegistry) == "table" then
        local cr = modTable.conflictRegistry
        local existing = CONFLICT_REGISTRY[addonNameKey] or CONFLICT_REGISTRY[shortKey] or {
            addons = {},
            conflicts = {},
            hardConflicts = {},
            partialConflicts = {},
            softConflicts = {},
            category = modTable.title or addonNameKey,
        }
        local function MergeUniqueStrings(dst, src)
            if type(dst) ~= "table" or type(src) ~= "table" then return end
            local seenMap = {}
            for _, v in ipairs(dst) do seenMap[v] = true end
            for _, v in ipairs(src) do
                if type(v) == "string" and v ~= "" and not seenMap[v] then
                    seenMap[v] = true
                    table.insert(dst, v)
                end
            end
        end
        existing.conflicts = existing.conflicts or {}
        existing.hardConflicts = existing.hardConflicts or existing.conflicts
        existing.partialConflicts = existing.partialConflicts or {}
        existing.softConflicts = existing.softConflicts or existing.partialConflicts
        existing.addons = existing.addons or {}
        if type(cr.conflicts) == "table" or type(cr.partialConflicts) == "table" then
            MergeUniqueStrings(existing.conflicts, cr.conflicts or {})
            MergeUniqueStrings(existing.hardConflicts, cr.hardConflicts or cr.conflicts or {})
            MergeUniqueStrings(existing.partialConflicts, cr.partialConflicts or {})
            MergeUniqueStrings(existing.softConflicts, cr.softConflicts or cr.partialConflicts or {})
            MergeUniqueStrings(existing.addons, existing.conflicts)
            MergeUniqueStrings(existing.addons, existing.partialConflicts)
            MergeUniqueStrings(existing, existing.addons)
            if cr.category and not existing.category then
                existing.category = cr.category
            end
        elseif #cr > 0 and type(cr[1]) == "string" then
            MergeUniqueStrings(existing.conflicts, cr)
            MergeUniqueStrings(existing.hardConflicts, cr)
            MergeUniqueStrings(existing.addons, cr)
            MergeUniqueStrings(existing, cr)
        end
        CONFLICT_REGISTRY[addonNameKey] = existing
        CONFLICT_REGISTRY[shortKey] = existing
    end

    if modTable.CHANGELOG or modTable.changelog then
        local entries = modTable.CHANGELOG or modTable.changelog
        if type(entries) == "table" then
            DynamicSuite.Changelogs[addonNameKey] = DynamicSuite.Changelogs[addonNameKey] or {
                version = modTable.version or ADDON_VERSION,
                date = modTable.date or "2026-11-10",
                entries = entries.entries or entries,
            }
            DynamicSuite.Changelogs[shortKey] = DynamicSuite.Changelogs[addonNameKey]
        end
    end

    local foundInList = false
    for _, existing in ipairs(SUITE_MODULE_LIST) do
        if existing.key == shortKey or existing.id == shortKey or existing.addonName == addonNameKey then
            foundInList = true
            if modTable.title then existing.title = modTable.title end
            if modTable.subtitle then existing.subtitle = modTable.subtitle end
            if modTable.slash then existing.slash = modTable.slash end
            local builtInMeta = addonTable.MODULE_META_BY_KEY and addonTable.MODULE_META_BY_KEY[shortKey]
            if builtInMeta and builtInMeta.icon then
                existing.icon = builtInMeta.icon
            elseif modTable.icon then
                existing.icon = modTable.icon
            end
            if modTable.category then existing.category = modTable.category end
            if modTable.desc or modTable.description then existing.desc = modTable.desc or modTable.description end
            break
        end
    end

    if not foundInList then
        local newEntry = {
            key = shortKey,
            id = shortKey,
            order = modTable.order or (100 + (#SUITE_MODULE_LIST * 10)),
            name = addonNameKey,
            title = modTable.title or addonNameKey,
            addonName = addonNameKey,
            slash = modTable.slash or ("/" .. shortKey),
            icon = modTable.icon or (addonTable.MODULE_META_BY_KEY and addonTable.MODULE_META_BY_KEY[shortKey] and addonTable.MODULE_META_BY_KEY[shortKey].icon) or ("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_load.tga"),
            subtitle = modTable.subtitle or "DynamicSuite Module",
            category = modTable.category or (modTable.title or addonNameKey),
            desc = modTable.desc or modTable.description or "",
        }
        table.insert(SUITE_MODULE_LIST, newEntry)
        table.insert(SUITE_MODULES, addonNameKey)
    end

    local dynamicSearchEntries = modTable.searchEntries or modTable.SEARCH_ENTRIES
    if type(dynamicSearchEntries) == "table" and DynamicSuite.RegisterSearchEntries then
        pcall(DynamicSuite.RegisterSearchEntries, DynamicSuite, shortKey, dynamicSearchEntries)
    end

    if addonTable.mainFrame and addonTable.mainFrame.RefreshLeftRailLayout then
        pcall(addonTable.mainFrame.RefreshLeftRailLayout)
    end
end

--------------------------------------------------------------------------------
-- Scalable Hybrid Search Registry & Intent/Synonym Index (Pass 2)
--------------------------------------------------------------------------------
local SEARCH_REGISTRY = {}
local SEARCH_KEY_DEDUP = {}

local SEARCH_CATEGORIES = {
    { key = "ALL",        label = "All",           shortLabel = "All" },
    { key = "COMBAT",     label = "Combat & Raid", shortLabel = "Combat & Raid" },
    { key = "FPS_CAM",    label = "FPS & Camera",  shortLabel = "FPS & Camera" },
    { key = "HUD_LOOK",   label = "HUD & Look",    shortLabel = "HUD & Look" },
    { key = "BAGS_QOL",   label = "Bags & QoL",    shortLabel = "Bags & QoL" },
    { key = "GROUP_CHAT", label = "Group & Chat",  shortLabel = "Group & Chat" },
}
addonTable.SEARCH_CATEGORIES = SEARCH_CATEGORIES
DynamicSuite.SEARCH_CATEGORIES = SEARCH_CATEGORIES

local SEARCH_CATEGORY_LABELS = {
    ALL        = "All",
    COMBAT     = "Combat & Raid",
    FPS_CAM    = "FPS & Camera",
    HUD_LOOK   = "HUD & Look",
    BAGS_QOL   = "Bags & QoL",
    GROUP_CHAT = "Group & Chat",
}
addonTable.SEARCH_CATEGORY_LABELS = SEARCH_CATEGORY_LABELS
DynamicSuite.SEARCH_CATEGORY_LABELS = SEARCH_CATEGORY_LABELS

local MODULE_ADDON_MAP = {
    load          = "DynamicLoad",
    DynamicLoad   = "DynamicLoad",
    marker        = "DynamicMarker",
    DynamicMarker = "DynamicMarker",
    zoom          = "DynamicZoom",
    DynamicZoom   = "DynamicZoom",
    fps           = "DynamicFPS",
    DynamicFPS    = "DynamicFPS",
    prep          = "DynamicPrep",
    DynamicPrep   = "DynamicPrep",
    group         = "DynamicGroup",
    DynamicGroup  = "DynamicGroup",
    bags          = "DynamicBags",
    DynamicBags   = "DynamicBags",
    chat          = "DynamicChat",
    DynamicChat   = "DynamicChat",
    STUDIO        = "DynamicSuite",
    SETUP         = "DynamicSuite",
    HUD           = "DynamicSuite",
    DynamicSuite  = "DynamicSuite",
}
addonTable.MODULE_ADDON_MAP = MODULE_ADDON_MAP
DynamicSuite.MODULE_ADDON_MAP = MODULE_ADDON_MAP

local MODULE_META_BY_KEY = {
    load   = { addonName = "DynamicLoad",   moduleTitle = "DynamicLoad",   slash = "/dl",     icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_load.tga" },
    marker = { addonName = "DynamicMarker", moduleTitle = "DynamicMarker", slash = "/dm",     icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_marker.tga" },
    zoom   = { addonName = "DynamicZoom",   moduleTitle = "DynamicZoom",   slash = "/dz",     icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_zoom.tga" },
    fps    = { addonName = "DynamicFPS",    moduleTitle = "DynamicFPS",    slash = "/dfps",   icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_fps.tga" },
    prep   = { addonName = "DynamicPrep",   moduleTitle = "DynamicPrep",   slash = "/dprep",  icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_prep.tga" },
    group  = { addonName = "DynamicGroup",  moduleTitle = "DynamicGroup",  slash = "/dgroup", icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_group.tga" },
    bags   = { addonName = "DynamicBags",   moduleTitle = "DynamicBags",   slash = "/dbag",   icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_bags.tga" },
    chat   = { addonName = "DynamicChat",   moduleTitle = "DynamicChat",   slash = "/dchat",  icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_chat.tga" },
    STUDIO = { addonName = "DynamicSuite",  moduleTitle = "Theme & Font",  slash = "/ds",     icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_palette.tga" },
    SETUP  = { addonName = "DynamicSuite",  moduleTitle = "Guided Setup",  slash = "/ds",     icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_spark.tga" },
    HUD    = { addonName = "DynamicSuite",  moduleTitle = "HUD Edit Mode", slash = "/ds hud", icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_grid.tga" },
}
addonTable.MODULE_META_BY_KEY = MODULE_META_BY_KEY

local searchSeedOrderCounter = 0

local function NormalizeSearchEntry(moduleKey, rawEntry)
    if type(rawEntry) ~= "table" or not rawEntry.title or rawEntry.title == "" then return nil end
    local mKey = rawEntry.moduleKey or moduleKey or "STUDIO"
    local meta = MODULE_META_BY_KEY[mKey]
    if not meta then
        local shortKey = tostring(mKey):gsub("^Dynamic", ""):lower()
        meta = MODULE_META_BY_KEY[shortKey] or {
            addonName   = rawEntry.addonName or ("Dynamic" .. shortKey:sub(1, 1):upper() .. shortKey:sub(2)),
            moduleTitle = rawEntry.moduleTitle or tostring(mKey),
            slash       = rawEntry.slash or ("/" .. shortKey),
            icon        = rawEntry.icon or ("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_load.tga"),
        }
    end

    local addonNameKey = rawEntry.addonName or meta.addonName or "DynamicSuite"
    local modTitle     = rawEntry.moduleTitle or meta.moduleTitle or addonNameKey
    local tabIdx       = rawEntry.tabIndex or 1
    local tabLbl       = rawEntry.tabLabel or rawEntry.breadcrumb or "General"
    local titleStr     = tostring(rawEntry.title)
    local descStr      = tostring(rawEntry.desc or "")
    local kwStr        = tostring(rawEntry.keywords or "")
    local catKey       = rawEntry.category or "BAGS_QOL"
    local catLabel     = SEARCH_CATEGORY_LABELS[catKey] or catKey
    local iconPath     = rawEntry.icon or rawEntry.moduleIcon or meta.icon or ("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_palette.tga")
    local targetStr    = rawEntry.highlightTitle or rawEntry.targetTitle or titleStr
    local resolvedView = rawEntry.viewKey or ((mKey == "STUDIO" or mKey == "SETUP") and type(tabIdx) == "string" and tabIdx or nil)

    searchSeedOrderCounter = searchSeedOrderCounter + 1
    local entry = {
        seedOrder       = rawEntry.seedOrder or searchSeedOrderCounter,
        moduleKey       = mKey,
        addonName       = addonNameKey,
        moduleTitle     = modTitle,
        slash           = rawEntry.slash or meta.slash or "/ds",
        icon            = iconPath,
        moduleIcon      = iconPath,
        category        = catKey,
        categoryLabel   = catLabel,
        tabIndex        = tabIdx,
        tabLabel        = tabLbl,
        breadcrumb      = tabLbl,
        viewKey         = resolvedView,
        title           = titleStr,
        highlightTitle  = targetStr,
        targetTitle     = targetStr,
        desc            = descStr,
        keywords        = kwStr,
        isSubDrawer     = rawEntry.isSubDrawer == true,
        hudTarget       = rawEntry.hudTarget,
        _titleLower     = titleStr:lower(),
        _kwLower        = kwStr:lower(),
        _keywordsLower  = kwStr:lower(),
        _modLower       = (modTitle .. " " .. addonNameKey .. " " .. tostring(rawEntry.slash or meta.slash or "")):lower(),
        _tabLower       = tabLbl:lower(),
        _crumbLower     = tabLbl:lower(),
        _descLower      = descStr:lower(),
        _catLower       = (catKey .. " " .. catLabel):lower(),
    }
    return entry
end

function DynamicSuite:RegisterSearchEntries(moduleKey, entries)
    if type(moduleKey) == "table" and entries == nil then
        entries = moduleKey
        moduleKey = nil
    end
    if type(entries) ~= "table" then return end
    for _, raw in ipairs(entries) do
        local norm = NormalizeSearchEntry(moduleKey, raw)
        if norm then
            local dedupKey = string.format("%s|%s|%s", tostring(norm.moduleKey), tostring(norm.tabIndex), norm._titleLower)
            local existingIdx = SEARCH_KEY_DEDUP[dedupKey]
            if existingIdx and SEARCH_REGISTRY[existingIdx] then
                SEARCH_REGISTRY[existingIdx] = norm
            else
                table.insert(SEARCH_REGISTRY, norm)
                SEARCH_KEY_DEDUP[dedupKey] = #SEARCH_REGISTRY
            end
        end
    end
end
addonTable.RegisterSearchEntries = function(moduleKey, entries)
    return DynamicSuite:RegisterSearchEntries(moduleKey, entries)
end

local function IsAddonInstalledOnDisk(addonNameKey)
    if not addonNameKey or addonNameKey == "DynamicSuite" then
        return true
    end
    local shortKey = tostring(addonNameKey):gsub("^Dynamic", ""):lower()
    if _G.DynamicSuite and _G.DynamicSuite.modules and (_G.DynamicSuite.modules[addonNameKey] ~= nil or _G.DynamicSuite.modules[shortKey] ~= nil) then
        return true
    end
    if addonNameKey == "DynamicLoad" then
        if addonTable.IsDynamicLoadModuleLoaded then
            return true
        end
        if C_AddOns and C_AddOns.GetAddOnInfo then
            local aName, _, _, _, aReason = C_AddOns.GetAddOnInfo("DynamicLoad")
            if aName ~= nil and aReason ~= "MISSING" then
                return true
            end
        end
        return false
    end
    if _G[addonNameKey] ~= nil then
        return true
    end
    if C_AddOns and C_AddOns.GetAddOnInfo then
        local aName, _, _, _, aReason = C_AddOns.GetAddOnInfo(addonNameKey)
        if aName ~= nil and aReason ~= "MISSING" then
            return true
        end
    end
    return false
end
addonTable.IsAddonInstalledOnDisk = IsAddonInstalledOnDisk

local function IsSearchModuleDisabled(entry)
    if not entry then return false end
    local addonNameKey = entry.addonName
    if not addonNameKey or addonNameKey == "DynamicSuite" or addonNameKey == "DynamicLoad" then
        return false
    end
    if IsSuiteModuleExplicitlyDisabled(addonNameKey) then
        return true
    end
    local shortKey = tostring(addonNameKey):gsub("^Dynamic", ""):lower()
    local pName = GetPlayer()
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addonNameKey))
        or (_G[addonNameKey] ~= nil)
        or (_G.DynamicSuite and _G.DynamicSuite.modules and (_G.DynamicSuite.modules[addonNameKey] ~= nil or _G.DynamicSuite.modules[shortKey] ~= nil))
    local enableState = (C_AddOns and C_AddOns.GetAddOnEnableState and C_AddOns.GetAddOnEnableState(addonNameKey, pName)) or 0
    return (not isLoaded) and (enableState == 0)
end
addonTable.IsSearchModuleDisabled = IsSearchModuleDisabled
DynamicSuite.IsSearchModuleDisabled = IsSearchModuleDisabled

function DynamicSuite:GetInstalledSearchEntries()
    local out = {}
    for _, entry in ipairs(SEARCH_REGISTRY) do
        local ownerInstalled = IsAddonInstalledOnDisk(entry.addonName)
        if ownerInstalled and entry.hudTarget and entry.ownerAddon then
            ownerInstalled = IsAddonInstalledOnDisk(entry.ownerAddon)
        end
        if ownerInstalled then
            table.insert(out, entry)
        end
    end
    return out
end
addonTable.GetInstalledSearchEntries = function()
    return DynamicSuite:GetInstalledSearchEntries()
end

-- Seed comprehensive built-in search metadata covering DynamicSuite & all 8 peer modules
local BUILTIN_SEARCH_SEED = {
    -- ========================================================================
    -- DYNAMICSUITE: THEME & FONT STUDIO ("STUDIO"), GUIDED SETUP ("SETUP"), HUD ("HUD")
    -- ========================================================================
    { moduleKey = "STUDIO", category = "HUD_LOOK", tabIndex = "THEME_STUDIO", tabLabel = "Theme & Font Studio",
      title = "ACCENT COLOUR PRESETS & CUSTOM PALETTE", highlightTitle = "ACCENT COLOUR PRESETS & CUSTOM PALETTE",
      desc = "Choose from 17 curated accent swatches, auto-match your class colour, or pick a custom hex colour.",
      keywords = "accent colour color theme palette swatch class colour hex custom picker tint border" },
    { moduleKey = "STUDIO", category = "HUD_LOOK", tabIndex = "THEME_STUDIO", tabLabel = "Theme & Font Studio",
      title = "Window Surface Theme",
      desc = "Select the Obsidian backdrop palette across all DynamicSuite windows (Midnight Pitch Black, Obsidian Dark, Slate Steel, Smoked Glass).",
      keywords = "surface theme dark mode background midnight black obsidian slate steel smoked glass translucent backdrop" },
    { moduleKey = "STUDIO", category = "HUD_LOOK", tabIndex = "THEME_STUDIO", tabLabel = "Theme & Font Studio",
      title = "Suite Font Family",
      desc = "Select the typography family applied across headers, lists, and HUD readouts (Expressway, Friz Quadrata, SharedMedia).",
      keywords = "font family typeface text typography expressway friz quadrata arialn morpheus skurri sharedmedia" },
    { moduleKey = "STUDIO", category = "HUD_LOOK", tabIndex = "THEME_STUDIO", tabLabel = "Theme & Font Studio",
      title = "Sync Font & Palette with Installed UI",
      desc = "Automatically inherit typography and accent colours from EllesmereUI, ElvUI, or LibSharedMedia.",
      keywords = "sync external ui ellesmereui eui elvui sharedmedia match theme font" },
    { moduleKey = "STUDIO", category = "HUD_LOOK", tabIndex = "THEME_STUDIO", tabLabel = "Theme & Font Studio",
      title = "Sync Theme & Font to On-Screen HUD Bars",
      desc = "Automatically apply the active Suite Accent Colour, Surface Theme, and Font Family to all HUD bars.",
      keywords = "sync hud bars toast prep bar focus bar flare bar theme colour font" },
    { moduleKey = "STUDIO", category = "HUD_LOOK", tabIndex = "THEME_STUDIO", tabLabel = "Theme & Font Studio",
      title = "Preserve Window Size, Scale & Layout Across All Characters",
      desc = "Share your custom window dimensions, UI scale, and HUD bar coordinates across every character.",
      keywords = "account wide alt sync window size scale layout position coordinates share" },
    { moduleKey = "STUDIO", category = "HUD_LOOK", tabIndex = "THEME_STUDIO", tabLabel = "Theme & Font Studio",
      title = "Active Control Fill Intensity",
      desc = "Adjust the colour fill strength of selected tabs, pills, and switches (24% Subtle, 32% Balanced, 42% Bold).",
      keywords = "fill intensity alpha pill button brightness subtle balanced bold contrast" },
    { moduleKey = "STUDIO", category = "BAGS_QOL", tabIndex = "THEME_STUDIO", tabLabel = "Game Menu & Shortcuts",
      title = "Game Menu: DynamicSuite Button",
      desc = "Show or hide the 'DynamicSuite' shortcut button inside the Esc Game Menu.",
      keywords = "game menu esc escape button shortcut dynamicsuite hide show" },
    { moduleKey = "STUDIO", category = "HUD_LOOK", tabIndex = "THEME_STUDIO", tabLabel = "Game Menu & Shortcuts",
      title = "Game Menu: DynamicSuite HUD Button",
      desc = "Show or hide the 'DynamicSuite HUD' button in the Esc Game Menu to unlock and move suite bars.",
      keywords = "game menu esc escape hud edit mode button shortcut move bars" },
    { moduleKey = "STUDIO", category = "BAGS_QOL", tabIndex = "THEME_STUDIO", tabLabel = "Game Menu & Shortcuts",
      title = "Replace Blizzard AddOns Button",
      desc = "Open DynamicSuite instead of Blizzard's default AddOn list when clicking 'AddOns' in the Esc menu.",
      keywords = "replace blizzard addons list esc menu button intercept default addon list" },

    -- Guided Setup & Conflict Scanner
    { moduleKey = "SETUP", category = "BAGS_QOL", tabIndex = "GUIDED_SETUP", tabLabel = "Guided Setup & Conflicts",
      title = "STEP 1: CONFLICT SCANNER, VISUAL THEME & ACCOUNT-WIDE ALT SYNC",
      desc = "Scan for overlapping third-party addons (Baganator, Prat-3.0, DialogueUI, SimpleAddonManager, ElvUI, Leatrix Plus) and resolve HARD conflicts or inspect SOFT Auto-Yield overlaps in 1 click.",
      keywords = "conflict conflicts scanner compatibility error taint guided setup wizard duplicate overlapping addons /ds conflicts baganator betterbags adibags arkinventory bagnon sorted litebag prat-3.0 chattynator ls_glass basicchatmods chatter wim dialogueui immersion storyline autoturnin premadegroupsfilter premaderegionfilter focusmarker targetcharms dynamiccam maxcam actioncamplus acp simpleaddonmanager betteraddonlist leatrix elvui auto yield" },
    { moduleKey = "SETUP", category = "BAGS_QOL", tabIndex = "GUIDED_SETUP", tabLabel = "Conflict Diagnostic (/ds conflicts)",
      title = "External Addon Conflict Detector & Auto-Yield Diagnostic (/ds conflicts)",
      highlightTitle = "STEP 1: CONFLICT SCANNER, VISUAL THEME & ACCOUNT-WIDE ALT SYNC",
      desc = "Run /ds conflicts to print and display a clean diagnostic summary of active HARD addon collisions and SOFT Auto-Yield overlaps across all 8 DynamicSuite modules.",
      keywords = "conflict conflicts compatibility error taint diagnostic /ds conflicts auto-yield yield third-party overlap baganator dialogueui elvui leatrix prat chattynator" },

    -- HUD Edit Mode Positioning Targets
    { moduleKey = "HUD", category = "HUD_LOOK", tabIndex = "PREP", hudTarget = "PREP", ownerAddon = "DynamicPrep", tabLabel = "HUD Positioning (/ds hud)",
      title = "Position Top Info Bar (Readiness Omni-Bar)",
      desc = "Unlock the screen alignment grid to drag, nudge, centre, or scale the DynamicPrep Top Info Bar.",
      keywords = "move drag position hud edit mode grid top info bar prep bar readiness omnibar coordinates x y" },
    { moduleKey = "HUD", category = "HUD_LOOK", tabIndex = "prepBuffs", hudTarget = "prepBuffs", ownerAddon = "DynamicPrep", tabLabel = "HUD Positioning (/ds hud)",
      title = "Position Clickable Raid Buffs HUD",
      desc = "Unlock the screen alignment grid to drag, nudge, or scale the Clickable Raid Buffs & Consumables HUD.",
      keywords = "move drag position hud edit mode grid clickable raid buffs consumables bar flask food oil" },
    { moduleKey = "HUD", category = "HUD_LOOK", tabIndex = "TARGET", hudTarget = "TARGET", ownerAddon = "DynamicMarker", tabLabel = "HUD Positioning (/ds hud)",
      title = "Position On-Screen Focus Icons Bar",
      desc = "Unlock the screen alignment grid to drag, nudge, or scale the 8-icon Raid Target Focus Bar.",
      keywords = "move drag position hud edit mode grid focus icons bar target marker skull bar" },
    { moduleKey = "HUD", category = "HUD_LOOK", tabIndex = "FLARE", hudTarget = "FLARE", ownerAddon = "DynamicMarker", tabLabel = "HUD Positioning (/ds hud)",
      title = "Position On-Screen World Flare Bar",
      desc = "Unlock the screen alignment grid to drag, nudge, or scale the 9-button World Ground Flare Bar.",
      keywords = "move drag position hud edit mode grid world flare bar ground markers" },
    { moduleKey = "HUD", category = "HUD_LOOK", tabIndex = "CHAT", hudTarget = "CHAT", ownerAddon = "DynamicChat", tabLabel = "HUD Positioning (/ds hud)",
      title = "Position & Resize Chat Frame",
      desc = "Unlock the screen alignment grid to position and resize the primary Chat Window with composite margin clamping.",
      keywords = "move drag resize position hud edit mode grid chat frame window box" },
    { moduleKey = "HUD", category = "HUD_LOOK", tabIndex = "TOAST", hudTarget = "TOAST", ownerAddon = "DynamicLoad", tabLabel = "HUD Positioning (/ds hud)",
      title = "Position DynamicLoad Alert Toast",
      desc = "Unlock the screen alignment grid to drag, nudge, or scale the Zone Profile Reload Alert Toast.",
      keywords = "move drag position hud edit mode grid alert toast banner reload notification" },

    -- ========================================================================
    -- 1. DYNAMICLOAD ("load") - Zone Addon Profiles & Alert Toast
    -- ========================================================================
    { moduleKey = "load", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Zone Addon Profiles",
      title = "Zone Addon Checklist (Outdoor, Delves, Dungeons, Raid, PvP)", highlightTitle = "Backup State",
      desc = "Manage your installed addons across 5 automatic zone profiles using By Zone, Always, and Never rules.",
      keywords = "addon manager profiles outdoor delves dungeons raid pvp enable disable always never by zone cpu memory usage load out of date backup state sort" },
    { moduleKey = "load", category = "HUD_LOOK", tabIndex = "toast_ui", tabLabel = "Alert Toast Style",
      title = "Toast Display Mode",
      desc = "Select 3-line detailed cards, 1-line compact pills, or exception-only reload alerts.",
      keywords = "toast display mode alert banner compact detailed exceptions only reload notification" },
    { moduleKey = "load", category = "HUD_LOOK", tabIndex = "toast_ui", tabLabel = "Alert Toast Style",
      title = "Toast Scale",
      desc = "Adjust the visual size of the Alert Toast banner across all zones (70% to 140%).",
      keywords = "toast scale size zoom alert banner notification" },
    { moduleKey = "load", category = "HUD_LOOK", tabIndex = "toast_ui", tabLabel = "Alert Toast Style",
      title = "Toast Background Opacity",
      desc = "Control the backdrop transparency of the Alert Toast banner (50% to 100%).",
      keywords = "toast opacity alpha transparency background alert banner" },
    { moduleKey = "load", category = "HUD_LOOK", tabIndex = "toast_ui", tabLabel = "Alert Toast Style",
      title = "Auto-Fade Duration",
      desc = "Choose how long the Alert Toast remains on screen before smoothly fading out (5s, 8s, 12s, or Stay Until Clicked).",
      keywords = "toast duration timer fade hide stay until clicked seconds" },
    { moduleKey = "load", category = "HUD_LOOK", tabIndex = "toast_ui", tabLabel = "Alert Toast Style",
      title = "Factory Toast Recovery",
      desc = "Restore Alert Toast display mode, scale, opacity, and screen coordinates to factory defaults.",
      keywords = "reset toast defaults factory recovery position" },

    -- ========================================================================
    -- 2. DYNAMICMARKER ("marker") - Target Marking, World Flares & Macros
    -- ========================================================================
    { moduleKey = "marker", category = "COMBAT", tabIndex = 1, tabLabel = "Focus Icons",
      title = "Preferred Focus Icon",
      desc = "Select your preferred raid target icon (Skull, Cross, Square, Moon, Triangle, Diamond, Circle, Star) for [DynamicMark].",
      keywords = "preferred focus icon raid target marker skull cross square moon triangle diamond circle star mark" },
    { moduleKey = "marker", category = "COMBAT", tabIndex = 1, tabLabel = "Focus Icons",
      title = "Active Group Scope",
      desc = "Choose whether focus raid target marking activates in Party & Raid, Party, Raid, or All (Solo + Group).",
      keywords = "active group scope party raid solo target mark enable" },
    { moduleKey = "marker", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "Focus Icons",
      title = "Announce Marks in Chat",
      desc = "Announce your focus icon to Party, Raid, or Instance chat on selection and Ready Check.",
      keywords = "announce marks in chat ready check party raid callout interrupt marker" },
    { moduleKey = "marker", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "Focus Icons", isSubDrawer = true,
      title = "Chat Channel",
      desc = "Select Smart Party-Only (stays quiet in Raid chat), Auto (Party/Raid/Instance), or Party Only.",
      keywords = "chat channel announce marks smart party only raid instance" },
    { moduleKey = "marker", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Focus Icons",
      title = "Show On-Screen Focus Bar",
      desc = "Display the floating 8-icon Raid Target bar on screen (Always, In Group Only, or Hidden).",
      keywords = "show on-screen focus bar hud raid target icons floating bar visibility" },
    { moduleKey = "marker", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Focus Icons", isSubDrawer = true,
      title = "Bar Orientation",
      desc = "Arrange the 8-icon On-Screen Focus Bar horizontally or vertically.",
      keywords = "bar orientation horizontal vertical focus bar layout" },
    { moduleKey = "marker", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Focus Icons", isSubDrawer = true,
      title = "HUD Border Style",
      desc = "Choose between a 1px crisp Obsidian border or a clean borderless Focus Bar.",
      keywords = "hud border style borderless obsidian focus bar" },
    { moduleKey = "marker", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Focus Icons", isSubDrawer = true,
      title = "Raid Target Bar Scale",
      desc = "Scale the On-Screen Focus Bar from 50% to 200%.",
      keywords = "raid target bar scale size focus icons" },
    { moduleKey = "marker", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Focus Icons", isSubDrawer = true,
      title = "Raid Target Bar Opacity",
      desc = "Adjust the overall transparency of the On-Screen Focus Bar (10% to 100%).",
      keywords = "raid target bar opacity alpha transparency focus icons" },
    { moduleKey = "marker", category = "COMBAT", tabIndex = 2, tabLabel = "World Flare Keys (F4 / F5)",
      title = "World Flare Cycle Sequence",
      desc = "Left-click ground flare icons to toggle them in your cycle sequence; right-click to reorder priority.",
      keywords = "world flare cycle sequence ground markers pillar smoke beacon order" },
    { moduleKey = "marker", category = "COMBAT", tabIndex = 2, tabLabel = "World Flare Keys (F4 / F5)",
      title = "Cycle Ground Flare Key",
      desc = "Bind a key (default F4) to drop the next World Flare directly at your cursor.",
      keywords = "cycle ground flare keybind f4 cursor world marker" },
    { moduleKey = "marker", category = "COMBAT", tabIndex = 2, tabLabel = "World Flare Keys (F4 / F5)",
      title = "Clear All Flares Key",
      desc = "Bind a key (default F5) to clear all active World Flares on the ground in 1 press.",
      keywords = "clear all flares keybind f5 remove world markers ground" },
    { moduleKey = "marker", category = "HUD_LOOK", tabIndex = 2, tabLabel = "World Flare Keys (F4 / F5)",
      title = "Show On-Screen World Flare Bar",
      desc = "Display the floating 9-button World Flare bar on screen (Always, In Group Only, or Hidden).",
      keywords = "show on-screen world flare bar hud ground markers visibility" },
    { moduleKey = "marker", category = "HUD_LOOK", tabIndex = 2, tabLabel = "World Flare Keys (F4 / F5)", isSubDrawer = true,
      title = "World Flare Bar Scale",
      desc = "Scale the On-Screen World Flare Bar from 50% to 200%.",
      keywords = "world flare bar scale size ground markers" },
    { moduleKey = "marker", category = "HUD_LOOK", tabIndex = 2, tabLabel = "World Flare Keys (F4 / F5)", isSubDrawer = true,
      title = "World Flare Bar Opacity",
      desc = "Adjust the overall transparency of the On-Screen World Flare Bar (10% to 100%).",
      keywords = "world flare bar opacity alpha transparency" },
    { moduleKey = "marker", category = "COMBAT", tabIndex = 3, tabLabel = "Macro Setup",
      title = "Clear Focus Modifier",
      desc = "Configure your [DynamicMark] macro modifier (Modifier-Free, Shift, Ctrl, or Alt) to focus and mark targets.",
      keywords = "clear focus modifier dynamicmark macro focus target mark" },
    { moduleKey = "marker", category = "COMBAT", tabIndex = 3, tabLabel = "Macro Setup",
      title = "Interrupt Target Priority",
      desc = "Configure [DynamicKick] interrupt targeting priority (Mouseover > Focus > Target, Focus > Target, or Target Only).",
      keywords = "interrupt target priority dynamickick kick macro mouseover focus target spell lock rebuke counterspell wind shear" },
    { moduleKey = "marker", category = "COMBAT", tabIndex = 3, tabLabel = "Macro Setup",
      title = "Multi-Spec & Alt Handling",
      desc = "Automatically update your [DynamicKick] interrupt spell whenever you change specialisations or log into alts.",
      keywords = "multi-spec alt handling dynamickick interrupt macro specialisation swap" },

    -- ========================================================================
    -- 3. DYNAMICZOOM ("zoom") - Max Zoom, Occlusion Shield & Auto-Zoom
    -- ========================================================================
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 1, tabLabel = "Max Zoom & Collision Shield",
      title = "Maximum Camera Distance Unlock",
      desc = "Unlock World of Warcraft's maximum 39-yard tactical camera distance (15 yd default to 39 yd max).",
      keywords = "maximum camera distance unlock 39 yards max zoom out fov" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 1, tabLabel = "Max Zoom & Collision Shield",
      title = "Fast Scroll Wheel Boost",
      desc = "Quadratically accelerate fast mousewheel flicks so you can glide from 0 to 39 yards in a single scroll.",
      keywords = "fast scroll wheel boost mousewheel zoom speed accelerator flick" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 1, tabLabel = "Max Zoom & Collision Shield", isSubDrawer = true,
      title = "Flick Boost Multiplier",
      desc = "Control how strongly fast mousewheel flicks accelerate camera zoom stepping (1.5x to 6.0x).",
      keywords = "flick boost multiplier scroll wheel speed acceleration" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 1, tabLabel = "Max Zoom & Collision Shield", isSubDrawer = true,
      title = "Base Zoom Glide Speed",
      desc = "Set the C++ camera interpolation glide speed (cameraDistanceMoveSpeed, 10 to 50).",
      keywords = "base zoom glide speed camera move speed smooth" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 1, tabLabel = "Max Zoom & Collision Shield",
      title = "See-Through Trees & Dungeon Pillars",
      desc = "Fade intersecting tree branches, banners, and dungeon pillars to translucent instead of snapping your camera inward.",
      keywords = "see-through trees dungeon pillars collision shield occlusion fade camera snap wall doorway" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 1, tabLabel = "Max Zoom & Collision Shield", isSubDrawer = true,
      title = "Pillar Fade Sensitivity",
      desc = "Adjust how quickly trees, archways, and pillars become see-through before touching the camera.",
      keywords = "pillar fade sensitivity occlusion trees transparency" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 1, tabLabel = "Max Zoom & Collision Shield",
      title = "Ignore Water Surface Collision",
      desc = "Prevent shallow puddles and water surfaces from jerking your camera above or below the waterline.",
      keywords = "ignore water surface collision puddle swim camera snap" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 1, tabLabel = "Max Zoom & Collision Shield",
      title = "Smooth Stairs & Uneven Ground",
      desc = "Dampen vertical camera bobbing when running up stairs, ramps, or uneven dungeon terrain.",
      keywords = "smooth stairs uneven ground vertical bobbing terrain camera" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 2, tabLabel = "Context Auto-Zoom",
      title = "Automatic Zone Zoom",
      desc = "Automatically glide your camera to tailored distances when entering Raids, Mythic+, Delves, Cities, or Indoors.",
      keywords = "automatic zone zoom context auto-zoom profile raid dungeon delve city" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 2, tabLabel = "Context Auto-Zoom",
      title = "Raid & Boss Combat Target Distance",
      desc = "Set the automatic camera distance for Raid instances and boss encounters (default 39 yd).",
      keywords = "raid boss combat target distance auto zoom yards" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 2, tabLabel = "Context Auto-Zoom",
      title = "Mythic+ & 5-Player Dungeon Target Distance",
      desc = "Set the automatic camera distance for Mythic+ keys and 5-player dungeons (default 34 yd).",
      keywords = "mythic+ m+ 5-player dungeon target distance auto zoom" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 2, tabLabel = "Context Auto-Zoom",
      title = "Delves, Scenarios & PvP Target Distance",
      desc = "Set the automatic camera distance for Delves, Arenas, and Battlegrounds.",
      keywords = "delves scenarios pvp arena bg target distance auto zoom" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 2, tabLabel = "Context Auto-Zoom",
      title = "Open World Target Distance",
      desc = "Set the automatic camera distance when exploring the outdoor world.",
      keywords = "open world outdoor target distance auto zoom" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 2, tabLabel = "Context Auto-Zoom",
      title = "Indoors & Tunnel Entrance Behaviour",
      desc = "Smartly pull the camera in inside tight indoor corridors and restore your outdoor zoom on exit.",
      keywords = "indoors tunnel entrance behaviour restore zoom corridor" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 2, tabLabel = "Context Auto-Zoom",
      title = "Capital Cities & Rested Areas Behaviour",
      desc = "Choose whether entering capital cities keeps your current zoom or glides to a comfortable city distance.",
      keywords = "capital cities rested areas behaviour silvermoon dornogal zoom" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 2, tabLabel = "Context Auto-Zoom",
      title = "Opt-In NPC Dialogue & Quest Framing",
      desc = "Optionally zoom in slightly when talking to quest givers and restore your previous zoom when closing dialogue.",
      keywords = "npc dialogue quest framing actioncam talk zoom in" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 3, tabLabel = "Speed, Pitch & Framing",
      title = "Base Mousewheel Zoom Glide Speed",
      desc = "Fine-tune the baseline mousewheel camera zoom glide speed across all zones.",
      keywords = "base mousewheel zoom glide speed camera" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 3, tabLabel = "Speed, Pitch & Framing",
      title = "Dynamic Horizon Pitch Tilt",
      desc = "Tilt the camera horizon upward slightly at long zoom distances so you see more of the boss arena and less floor.",
      keywords = "dynamic horizon pitch tilt angle floor boss arena actioncam" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 3, tabLabel = "Speed, Pitch & Framing",
      title = "Horizontal Shoulder Framing Offset",
      desc = "Apply a subtle over-the-shoulder horizontal camera offset (-1.5 to +1.5).",
      keywords = "horizontal shoulder framing offset actioncam over shoulder" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 3, tabLabel = "Speed, Pitch & Framing",
      title = "Skyriding Aerial Dive Pitch Padding",
      desc = "Keep your mount centred during high-speed Skyriding dives and ascents.",
      keywords = "skyriding dragonriding aerial dive pitch padding mount camera" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 3, tabLabel = "Speed, Pitch & Framing",
      title = "Anti-Motion-Sickness Guard & Factory Camera Recovery",
      desc = "Lock out head-bobbing camera effects and restore factory Blizzard camera settings at any time.",
      keywords = "anti-motion-sickness guard factory camera recovery head bob dizzy reset" },

    -- ========================================================================
    -- 4. DYNAMICFPS ("fps") - Zone Graphics Profiles & FPS Guard / SpellQueue
    -- ========================================================================
    { moduleKey = "fps", category = "FPS_CAM", tabIndex = "RAID", tabLabel = "Zone Graphics Profiles",
      title = "Shadow Quality",
      desc = "Configure per-zone dynamic shadow resolution without reloading the UI.",
      keywords = "shadow quality graphics cvar fps lag raid dungeon outdoor" },
    { moduleKey = "fps", category = "FPS_CAM", tabIndex = "RAID", tabLabel = "Zone Graphics Profiles",
      title = "Liquid Detail",
      desc = "Configure per-zone water reflection and ripple shader quality.",
      keywords = "liquid detail water reflections graphics fps" },
    { moduleKey = "fps", category = "FPS_CAM", tabIndex = "RAID", tabLabel = "Zone Graphics Profiles",
      title = "Particle Density",
      desc = "Control weather, ambient embers, and non-essential particle counts per zone.",
      keywords = "particle density effects weather graphics fps" },
    { moduleKey = "fps", category = "FPS_CAM", tabIndex = "RAID", tabLabel = "Zone Graphics Profiles",
      title = "SSAO",
      desc = "Configure Screen-Space Ambient Occlusion shading per zone.",
      keywords = "ssao ambient occlusion shading graphics fps" },
    { moduleKey = "fps", category = "FPS_CAM", tabIndex = "RAID", tabLabel = "Zone Graphics Profiles",
      title = "Depth Effects",
      desc = "Configure depth-of-field and atmospheric fog effects per zone.",
      keywords = "depth effects fog blur graphics fps" },
    { moduleKey = "fps", category = "FPS_CAM", tabIndex = "RAID", tabLabel = "Zone Graphics Profiles",
      title = "Compute Effects",
      desc = "Control heavy GPU compute shaders (volumetric fog and lighting) per zone.",
      keywords = "compute effects volumetric fog gpu shader lag fps" },
    { moduleKey = "fps", category = "FPS_CAM", tabIndex = "RAID", tabLabel = "Zone Graphics Profiles",
      title = "Outline Mode",
      desc = "Configure quest object and target highlight outlines per zone.",
      keywords = "outline mode highlight glow quest target graphics" },
    { moduleKey = "fps", category = "FPS_CAM", tabIndex = "RAID", tabLabel = "Zone Graphics Profiles",
      title = "Texture Resolution",
      desc = "Set surface texture resolution (Low or High) per zone.",
      keywords = "texture resolution high low vram graphics" },
    { moduleKey = "fps", category = "COMBAT", tabIndex = "RAID", tabLabel = "Zone Graphics Profiles",
      title = "Spell Density",
      desc = "Control allied spell visual clutter while keeping all deadly boss ground swirlies 100% visible.",
      keywords = "spell density visuals clutter swirlies projected textures raid boss mechanics fps" },
    { moduleKey = "fps", category = "FPS_CAM", tabIndex = "RAID", tabLabel = "Zone Graphics Profiles",
      title = "View Distance",
      desc = "Adjust far-clip horizon view distance (1 to 10) per zone without reloading.",
      keywords = "view distance horizon draw distance slider graphics fps" },
    { moduleKey = "fps", category = "FPS_CAM", tabIndex = "RAID", tabLabel = "Zone Graphics Profiles",
      title = "Environment Detail",
      desc = "Adjust distant building and terrain geometry detail (1 to 10) per zone.",
      keywords = "environment detail terrain buildings geometry graphics fps" },
    { moduleKey = "fps", category = "FPS_CAM", tabIndex = "RAID", tabLabel = "Zone Graphics Profiles",
      title = "Ground Clutter",
      desc = "Adjust grass, flowers, and small ground foliage density (1 to 10) per zone.",
      keywords = "ground clutter grass foliage plants graphics fps" },
    { moduleKey = "fps", category = "COMBAT", tabIndex = "RAID", tabLabel = "Zone Graphics Profiles",
      title = "Friendly Player Nameplates in PvE",
      desc = "Automatically hide heavy friendly player nameplates inside PvE Dungeons and Raids to boost combat FPS.",
      keywords = "friendly player nameplates pve raid dungeon hide cpu lag fps" },
    { moduleKey = "fps", category = "COMBAT", tabIndex = "RAID", tabLabel = "Zone Graphics Profiles",
      title = "Character Outline When Blocked",
      desc = "Show a silhouette outline around your character when obscured by large boss models or walls.",
      keywords = "character outline when blocked occluded silhouette boss wall" },
    { moduleKey = "fps", category = "FPS_CAM", tabIndex = "GUARD_QUEUE", tabLabel = "FPS Guard & Queue",
      title = "Automatic Zone Graphics Switching",
      desc = "Automatically apply each zone's graphics profile the instant you enter Outdoor, Cities, Delves, Dungeons, Raid, or PvP.",
      keywords = "automatic zone graphics switching zero reload profile" },
    { moduleKey = "fps", category = "FPS_CAM", tabIndex = "GUARD_QUEUE", tabLabel = "FPS Guard & Queue",
      title = "Combat FPS Drop Protection",
      desc = "Temporarily shed non-essential environment detail during heavy Bloodlust/boss pulls if your FPS drops below target.",
      keywords = "combat fps drop protection guard emergency lag spike bloodlust" },
    { moduleKey = "fps", category = "FPS_CAM", tabIndex = "GUARD_QUEUE", tabLabel = "FPS Guard & Queue", isSubDrawer = true,
      title = "Minimum Combat FPS",
      desc = "Set the protected FPS floor (30 to 120 FPS) that triggers temporary combat graphics shedding.",
      keywords = "minimum combat fps floor target threshold slider" },
    { moduleKey = "fps", category = "COMBAT", tabIndex = "GUARD_QUEUE", tabLabel = "FPS Guard & Queue",
      title = "Automatic Spell Queue Tuning (Ping & Spec)",
      desc = "Automatically tune SpellQueueWindow based on your live World Ping, Specialisation, and Haste GCD.",
      keywords = "automatic spell queue tuning spellqueuewindow latency ping ms gcd haste lag input delay" },
    { moduleKey = "fps", category = "COMBAT", tabIndex = "GUARD_QUEUE", tabLabel = "FPS Guard & Queue", isSubDrawer = true,
      title = "Custom Manual Spell Queue Delay (ms)",
      desc = "Set an exact manual SpellQueueWindow value in milliseconds (50 ms to 400 ms).",
      keywords = "custom manual spell queue delay ms spellqueuewindow slider" },
    { moduleKey = "fps", category = "FPS_CAM", tabIndex = "GUARD_QUEUE", tabLabel = "FPS Guard & Queue",
      title = "Max Foreground FPS",
      desc = "Cap maximum in-game frame rate (60, 120, 144, 165, 240 FPS, or Unlimited) to reduce GPU heat.",
      keywords = "max foreground fps cap limit frame rate 60 120 144 165 240 unlimited" },
    { moduleKey = "fps", category = "FPS_CAM", tabIndex = "GUARD_QUEUE", tabLabel = "FPS Guard & Queue",
      title = "Max Background FPS",
      desc = "Cap World of Warcraft's frame rate when Alt-Tabbed to save power and GPU usage.",
      keywords = "max background fps cap alt tab power save" },
    { moduleKey = "fps", category = "COMBAT", tabIndex = "GUARD_QUEUE", tabLabel = "FPS Guard & Queue",
      title = "Combat Log Auto-Purge",
      desc = "Periodically flush stale combat log memory buffers between boss pulls to prevent long-raid stutter.",
      keywords = "combat log auto-purge memory flush stutter raid lag" },
    { moduleKey = "fps", category = "COMBAT", tabIndex = "GUARD_QUEUE", tabLabel = "FPS Guard & Queue",
      title = "Quest Objective Tracker",
      desc = "Automatically collapse the Quest Objective Tracker during boss encounters or Mythic+ runs.",
      keywords = "quest objective tracker collapse hide boss combat mythic+" },
    { moduleKey = "fps", category = "COMBAT", tabIndex = "GUARD_QUEUE", tabLabel = "FPS Guard & Queue",
      title = "Error Speech & Boss Loot Banner",
      desc = "Mute repetitive 'Not enough energy / Spell is not ready' voice lines and hide the boss loot banner in combat.",
      keywords = "error speech voice mute red error text boss loot banner hide" },

    -- ========================================================================
    -- 5. DYNAMICPREP ("prep") - Readiness Omni-Bar, Raid Buffs, Omni Folio & QoL
    -- ========================================================================
    { moduleKey = "prep", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Bar Layout & Style",
      title = "TOP INFO BAR LAYOUT BUILDER",
      desc = "Toggle, reorder, and preview segments on the Top Info Bar (Stats, Spec/Loot, Keystone, Durability, FPS/Ping, Ready/Pull).",
      keywords = "top info bar layout builder readiness omnibar stats durability keystone fps ping ready check pull timer" },
    { moduleKey = "prep", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Bar Layout & Style",
      title = "HUD Border Style",
      desc = "Choose between a 1px crisp border or a clean borderless Top Info Bar.",
      keywords = "hud border style borderless top info bar prep" },
    { moduleKey = "prep", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Bar Layout & Style",
      title = "Bar Colour Theme",
      desc = "Tint the Top Info Bar with your Suite Accent, Class Colour, or neutral Obsidian.",
      keywords = "bar colour theme accent class colour top info bar" },
    { moduleKey = "prep", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Bar Layout & Style",
      title = "Secondary Stat Order",
      desc = "Sort secondary stats on the Top Info Bar by Highest Value or Fixed Order (Crit / Haste / Mastery / Vers).",
      keywords = "secondary stat order crit haste mastery versatility sort top bar" },
    { moduleKey = "prep", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Bar Layout & Style",
      title = "Ping Display Format",
      desc = "Display World Ping, Home Ping, Both, or Higher on the Top Info Bar.",
      keywords = "ping display format latency ms world home top bar" },
    { moduleKey = "prep", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Bar Layout & Style",
      title = "Top Info Bar Display Mode",
      desc = "Show the Top Info Bar Always, Out of Combat Only, in Instances Only, or Hide.",
      keywords = "top info bar display mode visibility hide combat" },
    { moduleKey = "prep", category = "FPS_CAM", tabIndex = 1, tabLabel = "Bar Layout & Style",
      title = "Combat Stat Refresh Rate",
      desc = "Control how frequently live secondary stats update during combat (Balanced 0.5s, Fast 0.2s, or Ultra-Saver 1.0s).",
      keywords = "combat stat refresh rate throttle cpu performance" },
    { moduleKey = "prep", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Bar Layout & Style",
      title = "Bar Scale",
      desc = "Scale the Top Info Bar from 70% to 150%.",
      keywords = "bar scale size top info bar prep" },
    { moduleKey = "prep", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Bar Layout & Style",
      title = "Bar Opacity",
      desc = "Adjust the background opacity of the Top Info Bar (0% transparent to 100% solid).",
      keywords = "bar opacity alpha background transparency top info bar" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio",
      title = "Enable Clickable Raid Buffs HUD",
      desc = "Show missing class raid buffs, flasks, food, weapon oils, and augment runes as 1-click cast buttons.",
      keywords = "enable clickable raid buffs hud consumables missing buff reminder cast button" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio",
      title = "Active Content Scope",
      desc = "Choose where Clickable Raid Buffs appear (Instanced & Group, Instances Only, or Everywhere).",
      keywords = "active content scope raid buffs dungeon delve solo" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio",
      title = "Class & Partner Raid Buffs (Smart Role Target)",
      desc = "Track missing Arcane Intellect, Fortitude, Mark of the Wild, Battle Shout, Skyfury, Blessing of the Bronze, and Source of Magic.",
      keywords = "class partner raid buffs intellect fortitude mark of the wild battle shout skyfury bronze source of magic" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio",
      title = "Weapon Oils & Stones (1-Click Auto-Apply)",
      desc = "Show missing Midnight weapon oils and sharpening/weightstones with 1-click application to Main-Hand and Off-Hand.",
      keywords = "weapon oils stones sharpening weightstone mana oil Enchant 1-click apply" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio",
      title = "Flasks & Phials (Fleeting & Quality Badges)",
      desc = "Track active Flasks and Phials with Rank 1 / Rank 2 quality badges and Fleeting flask support.",
      keywords = "flasks phials fleeting quality rank badge consumable" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio",
      title = "Well Fed & Hearty Food Reminder",
      desc = "Remind you when Well Fed is missing or expiring, prioritising Hearty food in your bags.",
      keywords = "well fed hearty food buff reminder feast roast consumable" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio",
      title = "Augment Rune Reminder",
      desc = "Track missing Augment Runes in Raids or Mythic+ with support for reusable Infinite Runes.",
      keywords = "augment rune reminder infinite rune raid mythic+" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio",
      title = "Expiring Warning Threshold",
      desc = "Show the Clickable Buff reminder early when buffs have fewer than 5, 10, or 15 minutes remaining.",
      keywords = "expiring warning threshold minutes remaining buff reminder" },
    { moduleKey = "prep", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio",
      title = "Clickable Icon Size",
      desc = "Adjust the pixel size of Clickable Raid Buff icons (32px to 64px).",
      keywords = "clickable icon size raid buffs hud scale" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio",
      title = "Omni Folio Tracking",
      desc = "Track your Midnight Seasonal Omni Folio secondary stat buff and show a 1-click button when it disagrees with your target stat.",
      keywords = "omni folio tracking midnight seasonal stat buff" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio",
      title = "Specialisation Preset",
      desc = "Automatically load Wowhead recommended secondary stat targets for all 39 specialisations or customise per content type.",
      keywords = "specialisation preset wowhead stat priority omni folio" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio",
      title = "Mythic+ Dungeons Target Stat",
      desc = "Choose the target Omni Folio secondary stat (Crit, Haste, Mastery, or Versatility) for Mythic+ Dungeons.",
      keywords = "mythic+ dungeons target stat omni folio crit haste mastery versatility" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio",
      title = "Raid Encounters Target Stat",
      desc = "Choose the target Omni Folio secondary stat for Raid instances.",
      keywords = "raid encounters target stat omni folio crit haste mastery versatility" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio",
      title = "Delves & Open World Target Stat",
      desc = "Choose the target Omni Folio secondary stat for Delves and Open World.",
      keywords = "delves open world target stat omni folio" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio",
      title = "Rated & Casual PvP Target Stat",
      desc = "Choose the target Omni Folio secondary stat for Arenas and Battlegrounds.",
      keywords = "rated casual pvp target stat omni folio" },
    { moduleKey = "prep", category = "BAGS_QOL", tabIndex = 3, tabLabel = "World & Survival QoL",
      title = "Auto-Skip Gossip & Quest Turn-In",
      desc = "Automatically select single-option NPC gossip dialogues and accept/complete quests (hold Shift to pause).",
      keywords = "auto-skip gossip quest turn-in accept dialogue npc talk Delve interact" },
    { moduleKey = "prep", category = "BAGS_QOL", tabIndex = 3, tabLabel = "World & Survival QoL",
      title = "Hide Talking Head & Skip Seen Cutscenes",
      desc = "Automatically skip movies and cinematics you have already watched on your account and suppress the Talking Head popup.",
      keywords = "hide talking head skip seen cutscenes movies cinematics video popup mute" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 3, tabLabel = "World & Survival QoL",
      title = "Smart Auto-Accept Resurrection",
      desc = "Automatically accept resurrections out of combat (or all non-hearthstone combat battle-rezzes).",
      keywords = "smart auto-accept resurrection rez battle rez br accept" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 3, tabLabel = "World & Survival QoL",
      title = "Smart Auto-Release Spirit",
      desc = "Automatically release spirit in PvP Battlegrounds, on full group wipes, or when holding Ctrl (never when Soulstone/Reincarnation is available).",
      keywords = "smart auto-release spirit death wipe pvp battleground release" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 3, tabLabel = "World & Survival QoL",
      title = "Automated Healing Macro ([DynamicHeal])",
      desc = "Maintain a 1-button [DynamicHeal] macro that prioritises Recuperate out of combat and Warlock Healthstones > Healing Potions in combat.",
      keywords = "automated healing macro dynamicheal healthstone potion silvermoon recuperate survival" },

    -- ========================================================================
    -- 6. DYNAMICGROUP ("group") - LFG Region Filter, Auto-Invite & Keystones
    -- ========================================================================
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "LFG Premade Filter & Regions",
      title = "Enable LFG Premade Filter",
      desc = "Upgrade Blizzard's Premade Groups window with Datacentre Region filtering, M+ Rating filter, and Lust/Battle Rez utility filtering.",
      keywords = "enable lfg premade filter group finder mythic+ raid" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "LFG Premade Filter & Regions",
      title = "Datacentre Region Filter Pills",
      desc = "Filter Premade LFG groups by Oceanic (OCE), US-West, US-Central, US-East, Latin America (LATAM), and Brazil (BR).",
      keywords = "datacentre datacenter region filter pills oce oceanic frostmourne barthilas us-west us-east latam br brazil ping" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "LFG Premade Filter & Regions",
      title = "Hide Full 5/5 Groups",
      desc = "Automatically hide 5/5 full party listings and delisted groups in the Premade Group Finder.",
      keywords = "hide full 5/5 groups delisted lfg premade" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "LFG Premade Filter & Regions",
      title = "Minimum M+ Rating Filter",
      desc = "Filter Premade Mythic+ groups by the group leader's minimum Mythic+ rating (IO score).",
      keywords = "minimum m+ rating filter io score leader mythic+ lfg" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "LFG Premade Filter & Regions",
      title = "Party Utility Filter (Lust & Battle Rez)",
      desc = "Filter Premade groups to show only parties that already have Bloodlust/Heroism, Battle Rez, or Both.",
      keywords = "party utility filter bloodlust heroism lust bl battle rez cr brezz lfg" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "LFG Premade Filter & Regions",
      title = "Sort LFG Results By",
      desc = "Sort filtered Premade LFG listings by Leader M+ Score (Highest First), Group Age, or Default.",
      keywords = "sort lfg results by m+ score rating age" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "LFG Premade Filter & Regions",
      title = "Premade Entry Overlay Badges",
      desc = "Display colour-coded [OCE]/[US-W] region badges, Leader M+ Score, and Lust/CR indicators on Premade LFG rows.",
      keywords = "premade entry overlay badges region score role icons lfg" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "LFG Premade Filter & Regions",
      title = "Remember Last Search Text",
      desc = "Preserve your last typed LFG search query and filter state when switching categories.",
      keywords = "remember last search text lfg query save" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "LFG Premade Filter & Regions",
      title = "One-Click Double-Click Sign Up",
      desc = "Sign up to Premade LFG groups with a single click or double-click.",
      keywords = "one-click double-click sign up apply lfg premade" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 2, tabLabel = "Whisper Auto-Invite & Roles",
      title = "Enable Whisper Auto-Invite",
      desc = "Automatically invite players who whisper you your trigger keyword (e.g. 'inv' or '123').",
      keywords = "enable whisper auto-invite keyword inv 123 party raid invite" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 2, tabLabel = "Whisper Auto-Invite & Roles", isSubDrawer = true,
      title = "Trigger Keywords",
      desc = "Set comma-separated whisper keywords (default: inv, invite, 123) that trigger an automatic group invite.",
      keywords = "trigger keywords whisper auto-invite inv 123" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 2, tabLabel = "Whisper Auto-Invite & Roles", isSubDrawer = true,
      title = "Accept Whispers From",
      desc = "Restrict whisper auto-invites to Everyone, Friends & Guild Only, or BNet Friends Only.",
      keywords = "accept whispers from friends guild bnet auto-invite" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 2, tabLabel = "Whisper Auto-Invite & Roles",
      title = "Auto-Convert Party to Raid Above 5 Players",
      desc = "Automatically convert your party into a raid group when a 6th whisper auto-invite arrives.",
      keywords = "auto-convert party to raid above 5 players invite" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 2, tabLabel = "Whisper Auto-Invite & Roles",
      title = "Auto-Promote Friends/Tanks",
      desc = "Automatically grant Raid Assist to tanks, healers, Battle.net friends, or guildmates in your raid.",
      keywords = "auto-promote friends tanks assist raid lead" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 2, tabLabel = "Whisper Auto-Invite & Roles",
      title = "Auto-Accept Role Check",
      desc = "Automatically confirm your active specialisation role when a Party or Raid Role Check pops up.",
      keywords = "auto-accept role check confirm tank healer dps" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Party & Keystone Automation",
      title = "Incoming Auto-Accept Party & Raid Invites",
      desc = "Automatically accept incoming group invites from Battle.net Friends and Guild Members.",
      keywords = "incoming auto-accept party raid invites friends guild" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Party & Keystone Automation",
      title = "Active LFG & Delve Queue Protection Shield",
      desc = "Block auto-accepting invites while you are queued in LFG/LFR/PvP or inside an active Delve.",
      keywords = "active lfg delve queue protection shield block invite" },
    { moduleKey = "group", category = "COMBAT", tabIndex = 3, tabLabel = "Party & Keystone Automation",
      title = "Auto-Insert Mythic+ Keystone",
      desc = "Automatically slot your Mythic+ Keystone from your bags the moment you open the Challenger's Pedestal.",
      keywords = "auto-insert mythic+ keystone slot pedestal font of power m+ key" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Party & Keystone Automation",
      title = "Instant One-Click Sign-Up",
      desc = "Skip the role-confirmation dialog when clicking a Premade LFG group (hold Shift/Alt to type a note).",
      keywords = "instant one-click sign-up dialog skip lfg apply" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Party & Keystone Automation",
      title = "Auto-Select Active Specialisation Role on Sign-Up",
      desc = "Automatically tick Tank, Healer, or Damage in the LFG Sign-Up dialog based on your current spec.",
      keywords = "auto-select active specialisation role on sign-up tank healer dps" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Party & Keystone Automation",
      title = "Persistent Sign-Up Note Pre-Fill",
      desc = "Pre-fill the Premade LFG application note box with your custom note, spec, and equipped item level.",
      keywords = "persistent sign-up note pre-fill application message ilvl spec" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Party & Keystone Automation", isSubDrawer = true,
      title = "Custom Sign-Up Note",
      desc = "Enter the default note text automatically inserted when applying to Premade LFG groups.",
      keywords = "custom sign-up note text lfg message" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Party & Keystone Automation", isSubDrawer = true,
      title = "Prepend Active Spec & Equipped Item Level",
      desc = "Automatically prepend your current specialisation and equipped item level (e.g. '285 Retribution - ') to your sign-up note.",
      keywords = "prepend active spec equipped item level ilvl note lfg" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Party & Keystone Automation",
      title = "Safe LFG Search Auto-Refresh Ticker",
      desc = "Automatically refresh Premade LFG search results every few seconds while idle.",
      keywords = "safe lfg search auto-refresh ticker premade update" },

    -- ========================================================================
    -- 7. DYNAMICBAGS ("bags") - Virtual Category Bags, Alt Vault & Vendor/Loot QoL
    -- ========================================================================
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Bag Layout Style",
      desc = "Choose between Grouped Categories (Keystones, Consumables, Gear Sets, BoE/WUE, Junk) or a Single Combined Grid.",
      keywords = "bag layout style grouped categories single grid virtual bags inventory" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Auto-Sort Items by Quality & Level",
      desc = "Automatically sort items inside each category by Rarity > Item Level > Name in memory with zero server lag.",
      keywords = "auto-sort items by quality level rarity ilvl sort bags" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Category Layout Preset",
      desc = "Apply 1-click category presets for Mythic+ & Raid, Collector & Crafting, or Minimal Compact.",
      keywords = "category layout preset mythic+ raid collector crafting compact" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Category Order & Visibility",
      desc = "Reorder or hide individual bag categories (Pinned, New Items, Keystones, Gear Sets, BoE/WUE, Consumables, Trade Goods, Junk).",
      keywords = "category order visibility pinned new items keystones gear sets boe wue consumables trade goods junk" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Split Categories Into Sub-Groups",
      desc = "Sub-split Equipment by Armor/Weapon slot or Trade Goods by expansion.",
      keywords = "split categories into sub-groups armour armor weapon expansion" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Bag Columns",
      desc = "Set the number of item slot columns in your main Backpack window (8 to 16 columns).",
      keywords = "bag columns width backpack grid size" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Bank Columns",
      desc = "Set the number of item slot columns in your Bank, Warband Bank, and Guild Bank window (10 to 20 columns).",
      keywords = "bank columns width warband guild bank grid size" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Slot Icon Size",
      desc = "Adjust the pixel size of item slot buttons in your Bags and Bank (32px to 48px).",
      keywords = "slot icon size button scale bags bank" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Category Spacing",
      desc = "Adjust the vertical padding between category groups inside DynamicBags.",
      keywords = "category spacing gap padding bags" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Remember Last Opened Bank & Sub-Tab",
      desc = "Reopen DynamicBank on whichever Personal or Warband tab you used most recently.",
      keywords = "remember last opened bank sub-tab personal warband guild persistence" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 2, tabLabel = "Item Badges & Glow",
      title = "Item Slot Badges",
      desc = "Toggle Item Level numbers, BoE/WUE bind tags, Equipment Set icons, Upgrade arrows, and Consumable Tier badges.",
      keywords = "item slot badges ilvl item level boe wue warband equipment set upgrade arrow quality tier" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 2, tabLabel = "Item Badges & Glow",
      title = "Item Slot Highlights",
      desc = "Toggle Rarity Border Glows, New Item pulse highlights, and Unusable Red tinting on bag slots.",
      keywords = "item slot highlights rarity border glow new item unusable red tint" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 2, tabLabel = "Item Badges & Glow",
      title = "Icon Font Size",
      desc = "Adjust the font size of Item Level and corner badge text on bag slots (9pt to 15pt).",
      keywords = "icon font size ilvl text badge bags" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault",
      title = "Auto-Open Triggers",
      desc = "Automatically open DynamicBags when visiting Bankers, Merchants, Mailboxes, Auction House, Scrappers, or Item Upgrade NPCs.",
      keywords = "auto-open triggers bank merchant vendor mailbox auction house catalyst upgrade" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault",
      title = "Alt & Warband Counts in Item Tooltips",
      desc = "Display how many of an item your alts and Warband Bank own directly inside item mouseover tooltips.",
      keywords = "alt warband counts in item tooltips inventory vault syndicator" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault",
      title = "Cached Characters",
      desc = "View and manage cached alt inventories and gold snapshots in the Alt Vault.",
      keywords = "cached characters alt vault delete character gold inventory" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault",
      title = "Auto-Repair Equipment",
      desc = "Automatically repair all damaged gear when opening a repair merchant (with Guild Bank First or Personal Gold funding).",
      keywords = "auto-repair equipment gear durability merchant vendor guild bank gold" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault",
      title = "Auto-Sell Grey Junk",
      desc = "Automatically sell all poor-quality (grey) junk items when opening any merchant window.",
      keywords = "auto-sell grey junk vendor merchant poor items gold scrap" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault",
      title = "Faster Auto-Loot",
      desc = "Instantly collect all loot items on corpse open without waiting for the default loot window animation.",
      keywords = "faster auto-loot speedy loot corpse instant pickup" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault",
      title = 'Auto-Fill "DELETE" Item Confirmation',
      desc = 'Automatically type "DELETE" into the confirmation box when destroying a good-quality item.',
      keywords = "auto-fill delete item confirmation destroy type delete" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault",
      title = "Auto-Open Pouches & Quick-Open Queue",
      desc = "Automatically open Soulbound loot pouches and queue Housing Decor, Profession Knowledge, and Use: caches in the 1-spot Open (N) header button.",
      keywords = "auto-open containers pouches quick-open queue housing decor knowledge gold bags" },

    -- ========================================================================
    -- 8. DYNAMICCHAT ("chat") - Target Whisper (/ww), Look, Sounds & History
    -- ========================================================================
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "Target Whisper & Input",
      title = "Instant Target Whisper (/ww)",
      desc = "Type '/ww ' in chat to immediately whisper your current friendly player target.",
      keywords = "instant target whisper /ww tell friendly target shortcut" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "Target Whisper & Input",
      title = "Clear '/ww' If You Have No Friendly Target",
      desc = "Safely clear the chat box if you press '/ww ' without a valid friendly player targeted so you never send '/ww' to public chat.",
      keywords = "clear /ww no friendly target prevent public chat" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "Target Whisper & Input",
      title = "Protect Whispers During Boss Fights & Mythic+",
      desc = "Keep whisper tabs protected during boss encounters and Mythic+ runs so incoming whispers never error.",
      keywords = "protect whispers during boss fights mythic+ secret value taint" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "Target Whisper & Input",
      title = "Use Up & Down Arrows to Repeat Sent Messages",
      desc = "Cycle through your previously sent chat lines using the Up and Down arrow keys without holding Alt.",
      keywords = "use up down arrows repeat sent messages history alt key" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "Target Whisper & Input",
      title = "Remember Whisper Channel After Sending",
      desc = "Choose whether pressing Enter returns to Party/Raid/Guild chat or stays locked on your last Whisper target.",
      keywords = "remember whisper channel after sending sticky whisper reset" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "Target Whisper & Input",
      title = "Remember Party, Raid, Instance & Guild Channels",
      desc = "Keep Party, Raid, Instance, Guild, and Officer channels sticky between messages.",
      keywords = "remember party raid instance guild channels sticky chat" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Look & Sidebar",
      title = "Smoked-Glass Chat Window & Top Tab Bar",
      desc = "Style the chat frame with an Obsidian smoked-glass backdrop, scrollable top tab bar, and unread badges.",
      keywords = "smoked-glass chat window top tab bar skin glass theme" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Look & Sidebar",
      title = "Chat Window Background Opacity",
      desc = "Adjust the backdrop darkness of the Smoked-Glass chat window (0% transparent to 95% dark).",
      keywords = "chat window background opacity alpha transparency dark" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Look & Sidebar",
      title = "Chat Typing Box Position",
      desc = "Anchor the chat typing box cleanly below the chat window or above the top tab bar.",
      keywords = "chat typing box position editbox bottom top above" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Look & Sidebar",
      title = "Chat Typing Box Shading",
      desc = "Tint the chat typing box border and glow with the active channel colour (Pink for Whisper, Blue for Party, Orange for Raid).",
      keywords = "chat typing box shading editbox channel colour border" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Look & Sidebar",
      title = "Hide Default Blizzard Side Buttons",
      desc = "Hide Blizzard's default Social, Voice, and Channel side buttons for a clean chat edge.",
      keywords = "hide default blizzard side buttons social voice channel clutter" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Look & Sidebar",
      title = "Match Chat Font with DynamicSuite",
      desc = "Apply your chosen DynamicSuite font family and crisp outline to all chat windows and tabs.",
      keywords = "match chat font dynamicsuite typography outline size" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Look & Sidebar",
      title = "Left Shortcut Bar Visibility",
      desc = "Show the vertical Left Shortcut Bar Always, On Mouseover Only, or Hide.",
      keywords = "left shortcut bar visibility rail mouseover hide chat" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Look & Sidebar",
      title = "Left Shortcut Bar Buttons",
      desc = "Choose which quick-action buttons appear on the Left Shortcut Bar (Copy Chat, Search, Roll, Ready Check, Pull, Channels).",
      keywords = "left shortcut bar buttons copy chat search roll dice ready check pull timer" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 2, tabLabel = "Chat Look & Sidebar",
      title = "Safe Channel Names in Raids & Mythic+",
      desc = "Shorten channel prefixes to compact [P], [R], [I], [G], [O] tags without touching secret combat strings.",
      keywords = "safe channel names raids mythic+ short tags [p] [r] [g] [i]" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 2, tabLabel = "Chat Look & Sidebar",
      title = "Show Player Class Colours in Chat",
      desc = "Enable class-coloured player names across all chat channels and whisper tabs.",
      keywords = "show player class colours colors in chat names" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 2, tabLabel = "Chat Look & Sidebar",
      title = "Chat Message Timestamps",
      desc = "Add clean 24-hour or 12-hour timestamps (e.g. 20:45 or 20:45:12) to chat messages.",
      keywords = "chat message timestamps clock time hour minute" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts",
      title = "Enable Chat Sound Alerts",
      desc = "Play custom audio cues when messages arrive in Whispers, BNet, Party, Raid, Guild, or Instance chat.",
      keywords = "enable chat sound alerts audio cue notification ping whisper" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts",
      title = "Audio Output Channel",
      desc = "Route chat sound alerts through Master (plays even with Effects muted), SFX, Dialog, or Ambience.",
      keywords = "audio output channel master sfx dialog sound volume" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts",
      title = "Combat & Boss Fight Sounds",
      desc = "Choose whether chat sound alerts play for all channels in combat, Whispers & Leaders Only, or Muted in Combat.",
      keywords = "combat boss fight sounds mute whispers leaders" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts",
      title = "Anti-Spam Cooldown",
      desc = "Set a per-channel anti-spam sound cooldown (None, 1s, 2s, 3s, 5s, or 10s) so rapid messages never spam audio.",
      keywords = "anti-spam cooldown throttle sound alert seconds" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts",
      title = "Whisper (Character)",
      desc = "Select the notification sound for incoming character whispers (Soft Chime, Crisp Ping, Blizzard Default, or Muted).",
      keywords = "whisper character sound alert chime ping bell tell" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts",
      title = "Battle.net Whisper",
      desc = "Select the notification sound for incoming Battle.net RealID friend whispers.",
      keywords = "battle.net bnet whisper sound alert friend toast" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts",
      title = "Party Chat",
      desc = "Select an optional notification sound for incoming Party chat messages.",
      keywords = "party chat sound alert notification" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts",
      title = "Party Leader & Guide",
      desc = "Select an optional notification sound for Party Leader and Dungeon Guide messages.",
      keywords = "party leader guide sound alert" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts",
      title = "Raid Chat",
      desc = "Select an optional notification sound for standard Raid chat messages.",
      keywords = "raid chat sound alert" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts",
      title = "Raid Leader & Raid Warning",
      desc = "Select a distinct alert sound for Raid Leader callouts and Raid Warnings.",
      keywords = "raid leader raid warning sound alert horn alarm" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts",
      title = "Instance Chat (LFD / LFR / BG)",
      desc = "Select an optional notification sound for Instance, LFR, and Battleground chat.",
      keywords = "instance chat lfd lfr bg battleground sound alert" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts",
      title = "Guild Chat",
      desc = "Select an optional notification sound for Guild chat messages.",
      keywords = "guild chat sound alert" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts",
      title = "Officer Chat",
      desc = "Select an optional notification sound for Guild Officer chat messages.",
      keywords = "officer chat guild sound alert" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts",
      title = "Say & Yell",
      desc = "Select an optional notification sound for nearby Say and Yell messages.",
      keywords = "say yell chat sound alert" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts",
      title = "Custom & Numbered Channels",
      desc = "Select an optional notification sound for numbered custom channels (Trade, General, Services).",
      keywords = "custom numbered channels trade general services sound alert" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 4, tabLabel = "Links, Scroll & History",
      title = "Clickable Web Links (Discord, Wago, CurseForge)",
      desc = "Turn URLs in chat (Discord, Wago, Wowhead, Raider.IO, YouTube) into clickable links that open a Ctrl+C copy box.",
      keywords = "clickable web links url copy discord wago wowhead raider.io curseforge youtube" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 4, tabLabel = "Links, Scroll & History",
      title = "Fast Mousewheel Scrolling (Shift & Ctrl)",
      desc = "Hold Shift to scroll 5 lines per tick or hold Ctrl to jump straight to the top or bottom of chat.",
      keywords = "fast mousewheel scrolling shift ctrl jump top bottom chat" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 4, tabLabel = "Links, Scroll & History",
      title = "Save Chat History Across Reloads & Logins",
      desc = "Restore your recent Party, Raid, Guild, and Whisper messages after a /reload or relog.",
      keywords = "save chat history across reloads logins restore messages" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 4, tabLabel = "Links, Scroll & History",
      title = "Saved Chat History Limit",
      desc = "Cap the maximum number of lines kept in chat memory (100 to 500 lines) to prevent GPU font-string lag.",
      keywords = "saved chat history limit max lines gpu buffer cap memory" },
    { moduleKey = "chat", category = "COMBAT", tabIndex = 4, tabLabel = "Links, Scroll & History",
      title = "Instant Combat Log Tab (Prevent Freeze)",
      desc = "Stop Blizzard's Combat Log tab from freezing the client when clicked after a long Raid or Mythic+ session.",
      keywords = "instant combat log tab prevent freeze lag hang click" },
    { moduleKey = "chat", category = "BAGS_QOL", tabIndex = 4, tabLabel = "Links, Scroll & History",
      title = "Enable '/rl' (Reload UI) & '/lg' (Leave Group)",
      desc = "Register quick '/rl' (ReloadUI) and '/lg' (C_PartyInfo.LeaveParty) slash commands.",
      keywords = "enable /rl reload ui /lg leave group party slash command shortcut" },
}
DynamicSuite:RegisterSearchEntries(nil, BUILTIN_SEARCH_SEED)

-- Safe Fallback Stubs when DynamicLoad is not installed
addonTable.IsAddonLocked          = addonTable.IsAddonLocked          or function(name) return PROTECTED_ADDONS[name] == true end
addonTable.IsAddonFrozen          = addonTable.IsAddonFrozen          or function() return false end
addonTable.SetAddonLocked         = addonTable.SetAddonLocked         or function() end
addonTable.SetAddonFrozen         = addonTable.SetAddonFrozen         or function() end
addonTable.GetAddonSecurityState  = addonTable.GetAddonSecurityState  or function(name) return PROTECTED_ADDONS[name] and "LOCKED" or "NORMAL" end
addonTable.CycleAddonSecurityState = addonTable.CycleAddonSecurityState or function() return "NORMAL" end
addonTable.ApplySmartAddonScan    = addonTable.ApplySmartAddonScan    or function()
    local g = EnsureSuiteGlobal()
    g.guidedSetupDone = true
    return { lockedCount = 0, outdoorCount = 0 }
end
addonTable.CalculateAddonDelta    = addonTable.CalculateAddonDelta    or function() return 0, {}, {} end
addonTable.StageAddonProfile      = addonTable.StageAddonProfile      or function() return 0 end
addonTable.ApplyProfile           = addonTable.ApplyProfile           or function(_, shouldReload) if shouldReload then ReloadUI() end return 0 end
addonTable.ResetDynamicLoad       = addonTable.ResetDynamicLoad       or function() end
addonTable.EvaluateCurrentEnvironment = addonTable.EvaluateCurrentEnvironment or function() return CONTEXT_OUTDOOR end
addonTable.GetLoadedProfile       = addonTable.GetLoadedProfile       or function() return CONTEXT_OUTDOOR end
addonTable.IsManualOverrideActive = addonTable.IsManualOverrideActive or function() return false end
addonTable.ResumeAutoSwitch       = addonTable.ResumeAutoSwitch       or function() end
addonTable.GetEnvironmentDetail   = addonTable.GetEnvironmentDetail   or function() return "Outdoor" end
addonTable.HasStash               = addonTable.HasStash               or function() return false end
addonTable.GetStashInfo           = addonTable.GetStashInfo           or function() return nil end
addonTable.ClearStash             = addonTable.ClearStash             or function() end
addonTable.StashCurrentState      = addonTable.StashCurrentState      or function() end
addonTable.RestoreStash           = addonTable.RestoreStash           or function() return 0, nil, 0 end
addonTable.ResetToastSettings     = addonTable.ResetToastSettings     or function() end
addonTable.SetToastEditMode       = addonTable.SetToastEditMode       or function() end
addonTable.SetToastPresetPosition = addonTable.SetToastPresetPosition or function() end
addonTable.NudgeToastPosition     = addonTable.NudgeToastPosition     or function() end

--------------------------------------------------------------------------------
-- Slash Commands (/ds, /dynamicsuite) & Suite Event Frame
--------------------------------------------------------------------------------
local function OpenMainSuiteWindowFallback()
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
        end
    end
    if _G.DynamicSuiteMainFrame then
        _G.DynamicSuiteMainFrame:SetShown(not _G.DynamicSuiteMainFrame:IsShown())
        return
    end
    if _G.DynamicLoadMainFrame then
        _G.DynamicLoadMainFrame:SetShown(not _G.DynamicLoadMainFrame:IsShown())
        return
    end
end
addonTable.OpenMainSuiteWindowFallback = OpenMainSuiteWindowFallback

--------------------------------------------------------------------------------
-- Hub Window: Off-Screen Drag Margins & Combat Auto-Collapse Pill
--------------------------------------------------------------------------------
local HUB_GRAB_MARGIN    = 48    -- px of the top title bar that must always stay on-screen
local HUB_OFFSCREEN_FRAC = 0.88  -- max fraction of the window allowed off the left/right edges

local hubCombat = { collapsed = false, pendingOpen = false, pill = nil }

local function GetMainHubFrame()
    local f = addonTable.mainFrame or _G.DynamicSuiteMainFrame
    if f and type(f.IsShown) == "function" then return f end
    return nil
end

local function IsHubFrameLockedDown(f)
    return f and f.IsProtected and f:IsProtected() and InCombatLockdown()
end

local function ApplyHubClampInsets(f)
    f = f or GetMainHubFrame()
    if not f or not f.SetClampRectInsets or IsHubFrameLockedDown(f) then return end
    local w, h = f:GetWidth() or 0, f:GetHeight() or 0
    if w <= 0 or h <= 0 then return end
    local keepW     = math.max(HUB_GRAB_MARGIN, w * (1 - HUB_OFFSCREEN_FRAC))
    local sideOff   = math.max(0, math.floor(w - keepW))
    local bottomOff = math.max(0, math.floor(h - HUB_GRAB_MARGIN))
    f:SetClampedToScreen(true)
    -- left/right: may slide ~88% off either side; top = 0 keeps the title bar below the screen top;
    -- bottom: may slide down until only the top 48px header strip remains visible.
    f:SetClampRectInsets(sideOff, -sideOff, 0, bottomOff)
end
addonTable.ApplyHubClampInsets = ApplyHubClampInsets

local function SaveHubPosition(f)
    f = f or GetMainHubFrame()
    if not f or not f.GetPoint then return end
    local point, _, relPoint, x, y = f:GetPoint(1)
    if not point then return end
    EnsureSuiteGlobal().hubWindowPos = {
        point = point, relPoint = relPoint or point,
        x = math.floor((x or 0) + 0.5), y = math.floor((y or 0) + 0.5),
    }
end

local function RestoreHubPosition(f)
    local pos = EnsureSuiteGlobal().hubWindowPos
    if not f or type(pos) ~= "table" or not pos.point or IsHubFrameLockedDown(f) then return end
    f:ClearAllPoints()
    f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, tonumber(pos.x) or 0, tonumber(pos.y) or 0)
end

local function EnsureHubWindowHooks()
    local f = GetMainHubFrame()
    if not f then return nil end
    if not f._dsHubHooksInstalled then
        f._dsHubHooksInstalled = true
        if f.HookScript then
            f:HookScript("OnShow", function(self)
                RestoreHubPosition(self)
                ApplyHubClampInsets(self)
            end)
            f:HookScript("OnSizeChanged", function(self) ApplyHubClampInsets(self) end)
        end
        if type(f.StopMovingOrSizing) == "function" then
            hooksecurefunc(f, "StopMovingOrSizing", function(self) SaveHubPosition(self) end)
        end
        if f:IsShown() then RestoreHubPosition(f) end
    end
    ApplyHubClampInsets(f)
    return f
end
addonTable.EnsureHubWindowHooks = EnsureHubWindowHooks

function addonTable.ResetHubWindowPosition()
    EnsureSuiteGlobal().hubWindowPos = nil
    if addonTable.ResetMainWindowPosition then
        addonTable.ResetMainWindowPosition()
    else
        local f = GetMainHubFrame()
        if f and not IsHubFrameLockedDown(f) then
            f:ClearAllPoints()
            f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end
    ApplyHubClampInsets()
end

local function EnsureCombatPill()
    if hubCombat.pill then return hubCombat.pill end
    local pill = CreateFrame("Button", "DynamicSuiteCombatPill", UIParent, "BackdropTemplate")
    pill:SetSize(214, 22)
    pill:SetFrameStrata("MEDIUM")
    pill:SetClampedToScreen(true)
    pill:SetMovable(true)
    pill:EnableMouse(true)
    pill:RegisterForDrag("LeftButton")
    pill:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    if pill.SetBackdrop then
        pill:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        pill:SetBackdropColor(0.06, 0.07, 0.09, 0.88)
        pill:SetBackdropBorderColor(0.96, 0.62, 0.04, 0.85)
    end
    local txt = pill:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt:SetPoint("CENTER")
    txt:SetText("[ DynamicSuite - In Combat ]")
    txt:SetTextColor(0.98, 0.75, 0.15)
    pill.text = txt

    local pp = EnsureSuiteGlobal().combatPillPos
    if type(pp) == "table" and pp.point then
        pill:SetPoint(pp.point, UIParent, pp.relPoint or pp.point, tonumber(pp.x) or 0, tonumber(pp.y) or 0)
    else
        pill:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end
    pill:SetScript("OnDragStart", function(self) self:StartMoving() end)
    pill:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint(1)
        if p then EnsureSuiteGlobal().combatPillPos = { point = p, relPoint = rp or p, x = x or 0, y = y or 0 } end
    end)
    pill:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            hubCombat.collapsed, hubCombat.pendingOpen = false, false
            self:Hide()
            print(string.format("%s: Window will stay closed after combat.", ADDON_TITLE))
            return
        end
        if InCombatLockdown() then
            hubCombat.pendingOpen = true
            print(string.format("%s: Settings will open automatically when combat ends.", ADDON_TITLE))
        elseif addonTable.RestoreHubAfterCombat then
            hubCombat.pendingOpen = true
            addonTable.RestoreHubAfterCombat()
        end
    end)
    pill:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("DynamicSuite", 1, 1, 1)
        GameTooltip:AddLine("Settings are paused during combat and reopen automatically afterwards.", 0.85, 0.88, 0.92, true)
        GameTooltip:AddLine("Left-Click: Reopen after combat   Right-Click: Stay closed   Drag: Move", 0.98, 0.75, 0.15, true)
        GameTooltip:Show()
    end)
    pill:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    pill:Hide()
    hubCombat.pill = pill
    return pill
end

function addonTable.CollapseHubForCombat()
    local f = GetMainHubFrame()
    if not f or not f:IsShown() then return end
    if f.IsProtected and f:IsProtected() then return end -- never Hide a protected frame in combat
    hubCombat.collapsed = true
    pcall(f.Hide, f) -- frame is only hidden, so its active tab and position are preserved as-is
    EnsureCombatPill():Show()
end

function addonTable.RequestHubOpenInCombat()
    hubCombat.pendingOpen = true
    EnsureCombatPill():Show()
    print(string.format("%s: Settings are locked during combat and will open automatically when combat ends.", ADDON_TITLE))
end

function addonTable.RestoreHubAfterCombat()
    if InCombatLockdown() then return end
    if hubCombat.pill then hubCombat.pill:Hide() end
    local wantOpen = hubCombat.collapsed or hubCombat.pendingOpen
    hubCombat.collapsed, hubCombat.pendingOpen = false, false
    if not wantOpen then return end
    local f = GetMainHubFrame()
    if f then
        if not f:IsShown() then f:Show() end
    else
        OpenMainSuiteWindowFallback()
    end
    EnsureHubWindowHooks()
end

-- Commands that only print / reload / defer in combat; everything else opens the config window.
local COMBAT_SAFE_SUITE_COMMANDS = {
    reload = true, auto = true, status = true, lock = true, unlock = true, freeze = true, profile = true,
    resethud = true, resethuds = true, hudreset = true,
}

local function HandleSuiteSlashCommandInner(msg)
    local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "conflicts" or cmd == "conflict" then
        if addonTable.PrintConflictSummary then
            addonTable.PrintConflictSummary()
        end
        if addonTable.OpenWorkspaceView then
            addonTable.OpenWorkspaceView("GUIDED_SETUP")
        else
            OpenMainSuiteWindowFallback()
        end

    elseif cmd == "setup" or cmd == "guided" then
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
        end

    elseif cmd == "search" or cmd == "find" then
        if addonTable.OpenSearchView then
            addonTable.OpenSearchView(arg or "")
        elseif addonTable.OpenWorkspaceView then
            addonTable.OpenWorkspaceView("SEARCH_VIEW")
        else
            OpenMainSuiteWindowFallback()
        end

    elseif cmd == "changelog" then
        if addonTable.ToggleChangelogModal then
            addonTable.ToggleChangelogModal()
        end

    elseif cmd == "reload" then
        ReloadUI()

    elseif cmd == "reset" then
        addonTable.ResetHubWindowPosition()

    elseif cmd == "resethud" or cmd == "resethuds" or cmd == "hudreset" then
        if addonTable.ResetAllHudPositions then
            addonTable.ResetAllHudPositions(false)
        elseif _G.DynamicSuite and type(_G.DynamicSuite.ResetAllHudPositions) == "function" then
            pcall(_G.DynamicSuite.ResetAllHudPositions, false)
        end

    elseif addonTable.HandleDynamicLoadSlashCommand and (cmd == "auto" or cmd == "status" or cmd == "lock" or cmd == "unlock" or cmd == "freeze" or cmd == "profile") then
        addonTable.HandleDynamicLoadSlashCommand(msg)

    else
        OpenMainSuiteWindowFallback()
    end
end

local function HandleSuiteSlashCommand(msg)
    local cmd = ((msg or ""):match("^(%S*)") or ""):lower()
    if InCombatLockdown() and not COMBAT_SAFE_SUITE_COMMANDS[cmd] then
        addonTable.RequestHubOpenInCombat()
        return
    end
    HandleSuiteSlashCommandInner(msg)
    EnsureHubWindowHooks()
end
addonTable.HandleSuiteSlashCommand = HandleSuiteSlashCommand

SLASH_DYNAMICSUITE1 = "/ds"
SLASH_DYNAMICSUITE2 = "/dynamicsuite"
SlashCmdList["DYNAMICSUITE"] = HandleSuiteSlashCommand

function addonTable.ReassertSuiteSlashRouting()
    _G.DynamicSuite = _G.DynamicSuite or {}
    _G.DynamicSuite.EnterHudEditMode     = addonTable.EnterHudEditMode
    _G.DynamicSuite.EnterEditMode        = addonTable.EnterHudEditMode
    _G.DynamicSuite.ResetAllHudPositions = addonTable.ResetAllHudPositions
    _G.DynamicSuite.ClampAllHudPositions = addonTable.ClampAllSuiteHudsToScreen
    if _G.DynamicLoad or addonTable.IsDynamicLoadModuleLoaded then
        _G.DynamicLoad = _G.DynamicLoad or {}
        _G.DynamicLoad.EnterHudEditMode  = addonTable.EnterHudEditMode
        _G.DynamicLoad.EnterEditMode     = addonTable.EnterHudEditMode
    end

    SLASH_DYNAMICSUITE1 = "/ds"
    SLASH_DYNAMICSUITE2 = "/dynamicsuite"
    SlashCmdList["DYNAMICSUITE"] = HandleSuiteSlashCommand

    if addonTable.HandleDynamicLoadSlashCommand then
        SLASH_DYNAMICLOAD1 = "/dl"
        SLASH_DYNAMICLOAD2 = "/dynamicload"
        SlashCmdList["DYNAMICLOAD"] = addonTable.HandleDynamicLoadSlashCommand
    end

    if hash_SlashCmdList then
        hash_SlashCmdList["/DS"] = nil
        hash_SlashCmdList["/DYNAMICSUITE"] = nil
        if addonTable.HandleDynamicLoadSlashCommand then
            hash_SlashCmdList["/DL"] = nil
            hash_SlashCmdList["/DYNAMICLOAD"] = nil
        end
    end

    local peerSlashMap = {
        ["DYNAMICLOAD"]   = "DynamicLoad",
        ["DYNAMICZOOM"]   = "DynamicZoom",
        ["DYNAMICFPS"]    = "DynamicFPS",
        ["DYNAMICMARKER"] = "DynamicMarker",
        ["DYNAMICPREP"]   = "DynamicPrep",
        ["DYNAMICGROUP"]  = "DynamicGroup",
        ["DYNAMICBAGS"]   = "DynamicBags",
        ["DYNAMICCHAT"]   = "DynamicChat",
    }
    for slashKey, modName in pairs(peerSlashMap) do
        local origHandler = SlashCmdList[slashKey]
        if type(origHandler) == "function" and not addonTable["_wrappedSlash_" .. slashKey] then
            addonTable["_wrappedSlash_" .. slashKey] = true
            SlashCmdList[slashKey] = function(msg)
                local cmd = (msg or ""):match("^%s*(%S*)")
                cmd = (cmd or ""):lower()
                if cmd == "" or cmd == "config" or cmd == "ui" or cmd == "options" then
                    if modName == "DynamicLoad" then
                        if addonTable.ShowConfigUI then
                            addonTable.ShowConfigUI(true)
                            return
                        end
                    elseif addonTable.OpenPeerModule then
                        addonTable.OpenPeerModule(modName)
                        return
                    end
                elseif slashKey ~= "DYNAMICMARKER" and (cmd == "edit" or cmd == "hud" or cmd == "move") then
                    if addonTable.EnterHudEditMode then
                        addonTable.EnterHudEditMode("ALL")
                        return
                    end
                end
                origHandler(msg)
            end
        end
    end
end

function _G.DynamicSuite_OnAddonCompartmentClick(_, buttonName)
    if buttonName == "RightButton" then
        if addonTable.EnterHudEditMode then
            addonTable.EnterHudEditMode("ALL")
        end
    else
        if InCombatLockdown() then
            addonTable.RequestHubOpenInCombat()
            return
        end
        if addonTable.ToggleMainWindow then
            addonTable.ToggleMainWindow()
        elseif SlashCmdList["DYNAMICSUITE"] then
            SlashCmdList["DYNAMICSUITE"]("")
        end
        EnsureHubWindowHooks()
    end
end

local function SafeRegisterSuiteEvent(frame, eventName)
    if not frame or not eventName then return end
    if _G.C_EventUtils and type(_G.C_EventUtils.IsEventValid) == "function" then
        if not _G.C_EventUtils.IsEventValid(eventName) then
            return
        end
    end
    frame:RegisterEvent(eventName)
end

local isSuiteCoreInitialized = false
local hasEnteredWorld = false
local suiteEventFrame = CreateFrame("Frame", "DynamicSuiteEventFrame", UIParent)
SafeRegisterSuiteEvent(suiteEventFrame, "ADDON_LOADED")
SafeRegisterSuiteEvent(suiteEventFrame, "PLAYER_LOGIN")
SafeRegisterSuiteEvent(suiteEventFrame, "PLAYER_ENTERING_WORLD")
SafeRegisterSuiteEvent(suiteEventFrame, "PLAYER_REGEN_DISABLED")
SafeRegisterSuiteEvent(suiteEventFrame, "PLAYER_REGEN_ENABLED")
SafeRegisterSuiteEvent(suiteEventFrame, "UI_SCALE_CHANGED")
SafeRegisterSuiteEvent(suiteEventFrame, "DISPLAY_SIZE_CHANGED")
suiteEventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_REGEN_DISABLED" then
        if addonTable.IsHudEditModeActive and addonTable.IsHudEditModeActive() and addonTable.ExitHudEditMode then
            addonTable.ExitHudEditMode()
        end
        if addonTable.OnSuiteEnterCombat then
            addonTable.OnSuiteEnterCombat()
        end
        addonTable.CollapseHubForCombat()
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        if addonTable.OnSuiteLeaveCombat then
            addonTable.OnSuiteLeaveCombat()
        end
        addonTable.RestoreHubAfterCombat()
        if addonTable._pendingMarkerConflictModal then
            ShowMarkerConflictReloadModal()
        end
        if addonTable._pendingHudPositionReset and addonTable.ResetAllHudPositions then
            addonTable._pendingHudPositionReset = false
            addonTable._pendingHudClamp = false
            addonTable.ResetAllHudPositions(false)
        elseif addonTable._pendingHudClamp and addonTable.ClampAllSuiteHudsToScreen then
            addonTable._pendingHudClamp = false
            addonTable.ClampAllSuiteHudsToScreen()
        end
        return
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        if addonTable.ReclampMainWindowToScreen then
            addonTable.ReclampMainWindowToScreen()
        end
        ApplyHubClampInsets()
        if addonTable.ClampAllSuiteHudsToScreen then
            if InCombatLockdown() then
                addonTable._pendingHudClamp = true
            else
                addonTable.ClampAllSuiteHudsToScreen()
            end
        end
        return
    elseif event == "ADDON_LOADED" then
        InvalidateConflictCache()
        if arg1 == "DynamicMarker" then
            standaloneMarkerWasEnabledAtBoot = true
            _G.DynamicSuite_StandaloneMarkerWasEnabledAtBoot = true
            addonTable.standaloneMarkerWasEnabledAtBoot = true
            DynamicSuite.standaloneMarkerWasEnabledAtBoot = true
            DynamicSuite._standaloneMarkerConflictDetected = true
            EnforceStandaloneDynamicMarkerExclusion(hasEnteredWorld)
        end
        if (arg1 == ADDON_FOLDER or arg1 == "DynamicSuite") and not isSuiteCoreInitialized then
            isSuiteCoreInitialized = true
            EnforceStandaloneDynamicMarkerExclusion(false)
            local g = EnsureSuiteGlobal()
            if not g.v120_windowWidth1040 then
                g.v120_windowWidth1040 = true
                if not g.windowWidth or g.windowWidth <= 980 then
                    g.windowWidth = 1040
                end
            end
            if not g.windowWidth or g.windowWidth < 980 then g.windowWidth = 1040 end
            if not g.windowHeight or g.windowHeight < 640 then g.windowHeight = 680 end
            EnforceProtectedSuiteModules()
            SnapshotAllSuiteCVars()
            if addonTable.EnforceFrozenAddonsDisabled then
                addonTable.EnforceFrozenAddonsDisabled()
            end
            if addonTable.HookGameMenu then
                addonTable.HookGameMenu()
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        hasEnteredWorld = true
        InvalidateConflictCache()
        EnsureConflictCache()
        EnforceStandaloneDynamicMarkerExclusion(true)
        if standaloneMarkerWasEnabledAtBoot or addonTable.standaloneMarkerWasEnabledAtBoot or (DynamicSuite and DynamicSuite.standaloneMarkerWasEnabledAtBoot) or (_G.DynamicSuite_StandaloneMarkerWasEnabledAtBoot == true) then
            ShowMarkerConflictReloadModal()
        end
    elseif event == "PLAYER_LOGIN" then
        InvalidateConflictCache()
        EnsureSuiteGlobal()
        SnapshotAllSuiteCVars()
        EnforceProtectedSuiteModules()
        EnforceStandaloneDynamicMarkerExclusion(false)
        if addonTable.EnforceFrozenAddonsDisabled then
            addonTable.EnforceFrozenAddonsDisabled()
        end
        if addonTable.RunLoginConflictScan then
            addonTable.RunLoginConflictScan()
        end
        if addonTable.HookGameMenu then
            addonTable.HookGameMenu()
        end
        C_Timer.After(0.15, function()
            if addonTable.ReassertSuiteSlashRouting then
                addonTable.ReassertSuiteSlashRouting()
            end
        end)
        C_Timer.After(0.25, function()
            if addonTable.ClampAllSuiteHudsToScreen then
                if InCombatLockdown() then
                    addonTable._pendingHudClamp = true
                else
                    addonTable.ClampAllSuiteHudsToScreen()
                end
            end
        end)
        C_Timer.After(1.0, EnsureHubWindowHooks)
    end
end)
