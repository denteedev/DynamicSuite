--[[
    DynamicSuite - DynamicSuite_Core.lua
    Central Obsidian Hub, Theme & Font Studio, Conflict Scanner & Module Registry for World of Warcraft (Retail 12.1.5 / 12.1.7, Interface 120105, 120107)
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
    local fb = fallback or "2.10.1"
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

local ADDON_VERSION = ResolveAddonVersion(ADDON_FOLDER, "2.10.1")
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
    date = "25/11/2026",
    entries = {
        { type = "FIX",     text = "Release v2.10.1 - DynamicBank Single-Action Bank & Guild Bank Closing (25/11/2026): Fixed a lingering invisible Blizzard bank interaction left open when closing DynamicBank (via Close button, Esc, or bag toggle) at a Personal Bank, Warband Bank, or Guild Bank; closing DynamicBank now cleanly ends active banker interactions, detaches and hides suppressed BankFrame/GuildBankFrame panels out of combat, yields them across Desktop Windows, isolates child modals and popovers on Esc without killing the live banker session, keeps tab switching uninterrupted, and skips close calls on remote snapshots (/dbag bank)." },
        { type = "FEATURE", text = "Release v2.10.1 - DynamicPrep Top Info Bar Shift-Drag & DynamicBank Gold Transfer Modal (25/11/2026): Added direct Shift + Left-Drag moving across the DynamicPrep Top Info Bar (plus Right-Click on empty bar space for /ds hud, bar-hover hint, segment tooltip footer, and updated '?' Quick Guide); and added a 2-row DynamicBank footer with live Warband, Guild (with daily rank limit), and Personal Bank (Character Gold + [Deposit to Warband]) controls backed by a shared Obsidian Core Gold Transfer modal with numeric G/S/C inputs, quick-fill pills, inline validation, and live money event updates." },
        { type = "UI",      text = "Release v2.10.0 - Pass 3-5 UI Refinement Across DynamicPrep, DynamicBags & DynamicFPS (25/11/2026): Added full-width Quick Presets and persisted Sub-Settings drawers across DynamicPrep and DynamicBags; restyled DynamicBags Tab 1's Category Order & Visibility grid with live Suite Accent < and > reorder arrows, isolated Bank Window Scale, and added an in-panel Smart Vendor Auto-Restock drawer with Ctrl + Alt + Right-Click vendor shortcuts; and completed DynamicFPS's 800x520 layout sweep with a responsive Zone Profile toolbar, proportional 6-zone tab clamping, a 14x14 standalone corner resize grip, and plain Australian English Spell Queue Timing copy." },
        { type = "FEATURE", text = "Release v2.10.0 - Suite-Wide HUD Accent Single Source of Truth & Zero-Truncation Actionable Toasts (25/11/2026): Enforced live Suite Accent across all 13 modules' in-world HUDs and overlays whenever external UI sync is off (with immediate live repainting including DynamicCursor, Clickable Raid Buffs, Mailbox bar, Teleport Toast, and DynamicBank); and widened actionable Alert Toasts to 460-540 px with tightened copy across DynamicPrep, DynamicLoad, DynamicTalent, and DynamicGroup so titles, status lines, and hints fit with zero truncation." },
        { type = "FEATURE", text = "Release v2.9.1 - Two-Tier Alert Toast Timers, Contextual HUD Edit Mode Timers & Universal Hover-to-Pause (24/11/2026): Split the shared Alert Toast fade timer into Actionable Toast Duration (12s default: 5s, 8s, 12s, 20s, Stay) for clickable prompt toasts and Info & Mention Toast Duration (5s default: 3s, 5s, 8s, 12s, Stay) for glanceable alerts with automatic one-time migration; added contextual Action, Info, and [Test Toast] controls inside HUD Edit Mode (/ds hud) whenever Alert Toast is selected; and enabled universal hover-to-pause across toast banners and their buttons alongside Right-Click dismissal everywhere." },
        { type = "UI",      text = "Release v2.9.1 - DynamicChat & DynamicZoom UI Refinement, 12 px Chat Default, Copy Chat Overhaul & Suite-Wide Stability Fixes (24/11/2026): Added 4 Quick Presets with live Suite Accent highlighting, 6 persisted Sub-Settings drawers, a 12 px default chat font (13 px High-Readability), dynamic top typing box clearance, and an overhauled Copy Chat & Copy Link window in DynamicChat; fixed Tab 2 dropdowns and Tab 3 rendering, folded DynamicZoom's 5 zone distance sliders into a persisted Sub-Settings drawer with a configurable NPC Dialogue Distance slider (15-25 yds), synced Suite Studio surfaces, and fixed Quick Guide header and internal module scoping across the suite." },
        { type = "FEATURE", text = "Release v2.9.0 - Patch 12.1.7 Dual-Interface Support, 3-Step Quick Start, Shared '?' Quick Guides & Feature Spotlight Modal (24/11/2026): Added dual-interface Retail 12.1.5 / 12.1.7 (120105, 120107) support across all 13 modules and standalone DynamicMarker; refactored Guided Setup into a fast 3-Step Quick Start (1. Style, 2. Conflicts, 3. Modules with 3 starter presets and 13-module grid); added the shared '?' Quick Guide header button and Obsidian modal across all 13 modules; and added the hybrid Feature Spotlight modal (/ds spotlight) plus quiet auto-clearing NEW left-rail badges with zero-nag combat/instance/Mythic+/cinematic guards." },
        { type = "FIX",     text = "Release v2.9.0 - DynamicMarker First-Open Fix, Omnium Folio Controls & Movable GenericTraitFrame, Sync-with-UI Auto-Clear & 12.1.7 Safety Guards (24/11/2026): Fixed DynamicMarker's first-open blank Tab 1 and conflict banner overlap (hoisted DisableTexturePixelSnap and SafeReadableString and expanded deploy.ps1 GETGLOBAL checks to all 15 Lua files); wired DynamicPrep's Omnium Folio capsule to Left-Click (Target Stat dropdown with Open Omnium Folio shortcut) and Right-Click (open/toggle GenericTraitFrame with ExpansionLandingPage fallback); added GenericTraitFrame and ExpansionLandingPage to Desktop Windows (now 33 managed panels); auto-cleared Sync Font & Palette with Installed UI on manual accent or font picks; and hardened Lorewalking/destructive confirmation and secret-value guards." },
        { type = "FEATURE", text = "Release v2.8.2 - New 13th Dual-Mode Module: DynamicCursor (/dcur, /dynamiccursor) (24/11/2026): Launched DynamicCursor with a 4-tab Obsidian workspace (enclosing Section Containers, individual setting cards, collapsible Sub-Settings drawers with 2px Suite Accent rail and 5x5px pip, 4px 3-way scrollbar, and 4 Quick Presets), Main Cursor Ring with Extra Ring Contrast, Inner GCD Ring (6 px default gap), Outer Cast/Channel/Empower Arc (4 px default gap) with Mini Spell Icon & Interrupt Flash Colour, modular Character Crosshair, Find My Cursor locator, Pooled Cursor Trail, Active Zones, built-in pointer size, and Smart Cursor Tooltips." },
        { type = "UI",      text = "Release v2.8.2 - Suite-Wide Standard 12x12 Accent Dropdown Chevrons, DynamicBags Auto-Unwrap & Granular EllesmereUI Conflict Detection (24/11/2026): Standardised every dropdown chevron across all 13 modules to crisp 4x-supersampled 12x12 live Suite Accent icons; added opt-in Auto-Unwrap & Open Wrapped Items in DynamicBags Tab 3; and added profile-aware EllesmereUI sub-module conflict detection with /ds conflicts eui and feature-level auto-yielding." },
        { type = "FEATURE", text = "Release v2.8.1 - Auto-Accept Role Check, Red Error Text & Sound Filter, and Granular Conflict Auto-Yield (22/11/2026): Added opt-in Auto-Accept Role Check in DynamicGroup (Off by default, 0.45s out-of-combat delay, Shift to skip, never auto-accepts queue pops), opt-in Red Error Text & Sound Filter in DynamicPrep Tab 3 (Combat & Cooldown Spam, Movement & Mount Errors, and Mute Error Voice Lines with original CVar restore), and feature-level auto-yielding to EnhanceQoL, Leatrix Plus, ErrorFilter, and ErrorMonster (overridable in /ds conflicts)." },
        { type = "FEATURE", text = "Release v2.8.1 - Low Durability Alert Toast, Healer Mage Food Restock & Role-Smart [DynamicDrink] (22/11/2026): Added DynamicPrep's Low Durability Alert Toast (1-click Repair Mount outdoors or Open Gear indoors), Follower Dungeon Mage Food restock/leave and group Ask for Table toasts, and the [nocombat] Role-Smart [DynamicDrink] recovery macro." },
        { type = "FEATURE", text = "Release v2.8.1 - DynamicTalent Raid Boss Binder, Multi-Source Boss Detection & Right-Click Toast Silence (22/11/2026): Promoted All Raids to Row 1 with a full-width boss grid and Clear button, added multi-source raid boss detection (target, softenemy, mouseover, focus, boss1-5, nameplates, raid targets) with sticky boss caching and /dt why diagnostics, added Prep Bar and quick-switcher bind badges, and enabled Right-Click silencing on Talent Reminder Toasts." },
        { type = "FIX",     text = "Release v2.8.1 - DynamicChat Focus Error Fix (22/11/2026): Fixed a Retail 12.1.5 secret-value focus error when action bars shifted or Blizzard refreshed the chat layout by tracking focus via ChatFrame focus events and guarding focus/visibility checks cleanly." },
        { type = "UI",      text = "Release v2.8.0 - DynamicTalent Header Subtitles & Truncation Hover Safety Net (22/11/2026): Shortened Talent Loadouts Manager subtitles to fit on one line at 800px and added a hover tooltip that shows the full text only when a subtitle, status strip line, or Active Reminders row is actually cut off." },
        { type = "FIXED",   text = "Release v2.8.0 - DynamicTalent Delve Zone Priority & Backdrop Studio Option 1 Redesign (22/11/2026): Fixed GetActiveTalentMismatch() and GetActiveContentGroup() reading difficultyID == 208 alongside C_DelvesUI.HasActiveDelve(), C_PartyInfo.IsDelveInProgress(), and C_PartyInfo.IsDelveComplete() so Delves never misclassify as Mythic+ and always prioritise [Zone: Delves] (keeping [Zone: Outdoor] outside resting cities and refreshing dock/Prep Bar after zoning); and redesigned Talent Tree Backdrop Studio into independent Base Background ('Blizzard Spec Art' | 'Solid Obsidian') and Ambient Mist ('Off' | 'Hero-Synced' | 'Class Glow') controls with context-aware muting on Background Dimmer (0%-85%) and new Mist Intensity slider (15%-100%, default 60%) plus seamless migration." },
        { type = "FIXED",   text = "Release v2.8.0 - DynamicTalent Backdrop Studio Layering, Dimmer Order & Mist Opacity (22/11/2026): Moved DynamicTalentTreeBackdrop onto positive BACKGROUND sublevels (1-6) with taint-free TalentsFrame.Background alpha suppression in non-Blizzard modes and UpdateSpecBackground post-hooking (restoring alpha 1 cleanly in Blizzard Default or when disabled), positioned dimmerWash strictly behind the mist and vignette layers so up to 85% Background Dimmer never smothers Hero-Synced Mist or Class Glow, and fixed animation double-alpha multiplication so mist glows cleanly at 0.28-0.48 / 0.20-0.36 / 0.24-0.40 animated (or 0.38 / 0.28 / 0.32 static)." },
        { type = "FIXED",   text = "Release v2.8.0 - DynamicTalent Same-Name Bind Isolation, Single Manager Flow, Drag-and-Drop Group Order & True-4px Sliders (22/11/2026): Isolated same-name talent loadouts via persistent unique loadoutID matching across all bind rules and conflict detection; streamlined /ds -> DynamicTalent to a clean Action & Status strip ('Open Talents (N)' + 'Open Loadout Manager') with a bidirectional 'Settings' header shortcut inside DynamicTalentManagerModal; upgraded Custom Loadout Group Order rows with Left-Click & Drag ghost-pill reordering; and standardised all horizontal sliders across all 12 modules and footer docks (including DynamicVault and DynamicDialogue) to true 4px flush fill tracks with 1px exterior hairlines and Suite Accent hover/drag blade thumbs." },
        { type = "FEATURE", text = "Release v2.8.0 - DynamicTalent Right-Click Hero Spec Swap & Talent Tree Backdrop Studio (21/11/2026): Added out-of-combat Right-Click Hero Talent medallion swapping on Blizzard's TalentsFrame (without opening the picker popup, safely disabled during combat, active Mythic+ keystones, and inspection, with 'Right-Click: Switch to [Other Hero Tree]' hover hint) plus the Talent Tree Backdrop Studio in Tab 2 featuring 4 Backdrop Modes (Blizzard Default, Obsidian Clean, Hero-Synced Mist shifting automatically across all 40 Hero Talent trees using one 64 KB procedural .tga, and Class Glow), a 0%-85% Background Dimmer precision slider (default 35%), and a Subtle Backdrop Animation toggle." },
        { type = "FEATURE", text = "Release v2.8.0 - New DynamicTalent Module (/dt, /dynamictalent), Dedicated PvP Binder & Custom Group Ordering (21/11/2026): Extracted Talent Loadouts & Talent Binds out of DynamicPrep into DynamicTalent as DynamicSuite's 12th dual-mode module with one-time zero-loss DynamicPrepDB -> DynamicTalentDB migration, a clean Top Info Bar capsule hook, 4-tab Raid/M+/PvP/Zone binder (All PvP, Arena, Battlegrounds, War Mode) with 3-tier mismatch priority, Prioritise Current Zone First sorting, and custom 5-group ordering across Talent Dock and switchers." },
        { type = "FEATURE", text = "Release v2.7.1 - Standardised Spec/Loot Clicks, Multi-Select M+ & 'All M+' Talent Binds, LFR / Normal Raid Merge, 'Talent Binds' Rename & Dropdown Scrollbar (21/11/2026): Standardised Left-Click (Switch Active Specialisation out of combat) and Right-Click (Loot Specialisation) across both DynamicPrep's Top Info Bar and Left-Hand Talent Loadouts Dock with 1:1 plain Australian English tooltips; upgraded Tab 2's Pre-Keystone M+ Binder with an 'All' toggle pill and multi-select season dungeon tiles so you can batch-bind selected dungeons or save a single 'All M+ Dungeons' rule in one click (with specific per-dungeon binds taking priority); merged LFR (difficulty 17) and Normal (difficulty 14) into a single 'LFR / Normal' Raid difficulty option alongside Heroic and Mythic; renamed 'Boss Binds' to 'Talent Binds' across the Talent Dock, context menus, settings, and Global Smart Search; and added a 4px interactive 3-way Obsidian scrollbar to Talent Loadouts Manager dropdowns." },
        { type = "UI",      text = "Release v2.7.0 - Unified Shared Alert Toast System, Live Suite Accent Across All Buttons/Grips/Modals, 800x520 Uniform Widget Geometry & 11-Module Documentation Parity (21/11/2026): Centralised all Toast appearance and sound controls (Scale, Opacity, Border Style, Auto-Fade Duration, and Alert Sound) inside Suite Studio and DynamicLoad under one Alert Toast HUD target; updated DynamicPrep Talent Reminder Toasts, DynamicGroup Teleport Toasts, and DynamicChat Mention Alert Toasts to share one consistent Obsidian appearance, live Suite Accent, Right-Click dismissal, and clean non-overlapping vertical stacking; removed stray Edit HUD buttons from toast-consumer panels and kept inline Edit HUD buttons strictly on the 6 true movable HUD owner cards with non-overlapping title/subtitle anchors; replaced all remaining hardcoded Blaze Orange buttons, modal borders, focus boxes, portal highlights, Apply All buttons, window scale toasts, and corner resize grips with the live Suite Accent colour; upgraded DynamicDialogue to the universal 34px 2-tab header bar, dedicated 44px Action & Status strip, clean non-outlined card fonts, 156x26px binary switches, and 2-line wrapped descriptions; standardised relative text clamping and control sizing across DynamicVault, DynamicMail, DynamicBags, DynamicFPS, and DynamicSuite_UI so all panels fit cleanly down to 800x520; and updated README and CurseForge storefront docs for all 11 modules." },
        { type = "FIX",     text = "Release v2.6.9 - DynamicDialogue Panel & Retail Yield Probe Fix, DynamicVault Multi-Alt Dock Crash & Escape Close, and DynamicMail Parity (21/11/2026): Assigned fonts before calling SetText and ran ApplySubTab() on initial RenderDialogueEmbedded setup so DynamicDialogue's sub-tabs never throw a Font not set error or overlap on first open, added the standard 4px 3-way Obsidian settings scrollbar, matched standalone title colours, updated DynamicDialogue.CHANGELOG to use VERSION, and fixed the Retail 12.1.5 Blizzard Quest/Gossip probe in both DynamicSuite_Core and DynamicDialogue so clean installs show Active reliably; fixed an undefined width variable crash in RefreshGreatVaultDock when 2 or more alts are tracked, registered DynamicVaultStandaloneFrame in UISpecialFrames for Escape closing, updated /dv overlay and /dv hud to point to DynamicPrep's Top Info Bar, and registered DynamicVault's changelog with DynamicSuite; and guarded DynamicMail workspace opening when disabled in the suite, synced its standalone resize handle to the active Suite Accent, updated Quick Action Bar search copy, and standardised its changelog format." },
        { type = "UI",      text = "Release v2.6.8 - Great Vault Dock Alignment, Standalone Vault Overlay Removal, DynamicPrep 13-Capsule Grid Fix, DynamicDialogue 2-Tab Redesign & Macro Note Cleanup (21/11/2026): Fixed DynamicVaultBlizzDock overhanging WeeklyRewardsFrame by anchoring directly to WeeklyRewardsFrame with the exact 10px horizontal inset and 6px vertical panel clearance; removed the redundant standalone On-Screen Vault Overlay (and VAULT HUD Edit Mode target) since Great Vault status lives cleanly inside DynamicPrep's Prep Bar; removed per-module Auto-Match External UI skin toggles from DynamicVault and DynamicMail so every module strictly follows Suite Studio's active Obsidian and Suite Accent settings; fixed DynamicPrep's Bar Layout & Style 13-capsule grid overflowing onto HUD Border Style by sizing the grid container dynamically to 5 rows (200px) and shifting lower rows cleanly; redesigned DynamicDialogue into 2 clean sub-tabs (Reader & Controls | Appearance & Sound) with exact section heights (zero bottom dead space) and removed the redundant Auto-Yield toggle (managed centrally in Guided Setup); and trimmed DynamicMarker's Macro Setup DecorVendor note to a crisp 1-line summary." },
        { type = "UI",      text = "Release v2.6.7 - Suite-Wide Accent Unification, Unified Talent Reminder Toast, Quick Spec Dropdown, Vault Dock Width & LFG Cancel Fix (21/11/2026): Unified the active Suite Accent colour across every module, toast, dropdown, Edit HUD button, window scale toast, and resize grip (eliminating hardcoded Blaze Orange fallbacks and migrating DynamicMail & DynamicVault top docks from AUTO to OBSIDIAN by default so all overlays share DynamicSuite's colour scheme); rebuilt DynamicPrep's Talent Reminder Toast to match DynamicLoad's Alert Toast 1:1 (removed Dismiss button in favour of Right-Click anywhere to dismiss, matched surface/border/opacity/scale/duration, and stacked cleanly below DynamicLoadToastFrame); upgraded DynamicPrep's Talent Loadouts Manager dropdowns with directional chevrons, active square pip, screen-bottom flip, scrolling, and Escape/click-outside dismissal; replaced Prep Bar Right-Click blind spec cycling with an Obsidian Switch Active Specialisation dropdown (Left-Click remains Loot Spec selector); fixed DynamicVault's Great Vault top dock overhanging Blizzard's WeeklyRewardsFrame width and collapsed it to a sleek single-row 34px bar when only 1 character is tracked (showing Row 2 'Alts:' chips only when 2+ characters are tracked); and fixed duplicate cross ('x') textures on DynamicGroup's LFG search entry cancel buttons." },
        { type = "FEATURE", text = "Release v2.6.6 - DynamicVault Master HUD Edit Mode Integration, Obsidian Vault Overlay Redesign, Weekly Checklist Polish & Talent Duplicate Loadout (21/11/2026): Integrated DynamicVault's standalone On-Screen Vault Overlay ('VAULT') into DynamicSuite's Master HUD Edit Mode (selector dropdown, drag/nudge/centre, 60%-150% scale, 20%-100% opacity, Accent/Dark/None borders, Hidden/Shown toggle, Apply All, and Reset) and redesigned the overlay bar to match the Prep Bar Obsidian HUD aesthetic (#090A0D backdrop, 2px Suite Accent left bar, tinted Vault icon, slate dividers, and auto-fit width); replaced misleading green checkboxes on read-only Auto-Tracked Weekly Progress rows in DynamicVault with clean 3px vertical status bars so only clickable Custom Weekly Tasks show checkboxes; renamed the ambiguous 'Scan' button in Account Matrix to 'Refresh' with an explanatory tooltip; added 1-click 'Duplicate Loadout' to DynamicPrep's Left-Hand Talent Dock right-click menu; and ensured current-season Mythic+ dungeons auto-hydrate via RequestMapInfo() on fresh login." },
        { type = "UI",      text = "Release v2.6.5 - 4-Category Left-Rail Layout, Suite-Wide Design Audit & Plain-English Copy Sweep (20/11/2026): Grouped all 11 modules in the Left Suite Rail under 4 clean category sub-headers -- COMBAT & GROUP (Marker, Group, Prep), PROGRESSION & QUESTS (Vault, Dialogue), INVENTORY & SOCIAL (Bags, Mail, Chat), and PERFORMANCE & SYSTEM (Load, FPS, Zoom) -- with a clipped scrollable rail and 3-way 4px Obsidian scrollbar that auto-hides when all modules fit, full 11-module drag/arrow/right-click custom reordering, and an updated Reset Sort button; registered DynamicDialogue across Suite Core protection, slash routing, and Global Smart Search; aligned DynamicVault's Off pill Coral-Rose indicator bar to 1.5px (#F87171) and wired live Suite Accent ApplyTheme syncing into both DynamicVault and DynamicDialogue; and rewrote technical jargon across module titles, tooltips, and Guided Setup into plain Australian English." },
        { type = "FEATURE", text = "Release v2.4.0 - New DynamicMail Module (/dmail), Smart Bulk-Attach Presets, Alt Vault Picker & Quick Gold (18/11/2026): Added DynamicMail as DynamicSuite's 9th dual-mode module (both bundled and standalone) with 1-click Inbox Open All, AH Gold, and Items Only collection; Shift+Left-Click inbox quick-loot and Expiring (<3d) alerts; automatic COD protection and configurable free bag-slot reserve; a 4-tab Recipient Picker docked beside Send Mail (Alts synced automatically from DynamicBags Vault with class colours, gold balances & Pending Sent Mail badges, Recent, Guild, and Friends with Favourite pinning); 1-click Quick-Attach preset pills ([+ Mats], [+ BoE], [+ Warband], [+ Same]) with Equipment Manager & Soulbound safety checks plus [+1k g] / [+10k g] / [+100k] Quick Gold buttons; Alt + Left-Click Express Multi-Attach from bags; auto-subject fill; lifetime gold & item telemetry; and full Guided Setup + Global Smart Search integration." },
        { type = "FIX",     text = "Release v2.3.2 - Proactive DecorVendor /tm Quarantine Modal, Post-Combat MacroFrame Refresh, 1-Click Housing Decor Open & Universal Mousewheel Fixes (18/11/2026): Promoted DecorVendor ('Decor Vendor') to a Tier-1 HARD conflict under DynamicMarker across DynamicSuite and standalone DynamicMarker, and added a Midnight Pitch Black (#06070A-#090A0D) Obsidian warning modal ('Raid Marker Blocked by Addon Conflict', safely deferred until out of combat) whenever DecorVendor is active on login/reload or whenever World of Warcraft blocks SetRaidTarget() / SetRaidTargetIcon(), with 1-click 'Disable <Addon> (Set to Never)' across all DynamicLoad zone profiles, session-throttled Dismiss, and plain-English Exit & Restart guidance; protected the Blizzard Macros window (MacroFrame) during combat and automatically refreshed its macro selector list and icon grid on leaving combat across DIALOG/HIGH focus transitions and ElvUI Blizzard skinning; enabled 1-click Housing Decor non-tradeable confirmation handling in DynamicBags Open (N) / Alt+MouseWheel (with Retail 12.1.5 pooled StaticPopup, END_BOUND_TRADEABLE, and USE_NO_REFUND_CONFIRM support out of combat while ignoring manual bag clicks, loot rolls, and non-Decor items); and restored smooth mousewheel scrolling across DynamicBags, DynamicBank, and all 32 managed Blizzard Desktop Windows." },
        { type = "FIX",     text = "DynamicBags ESC / B Keybind Closure, Top-Most Window Escape Priority & GameMenu Failsafe Guard (18/11/2026): Removed the conflicting GameMenuFrame OnShow hide hack from DynamicBagsFrame and compacted nil holes/duplicates out of UISpecialFrames in both DynamicSuite_Core.lua and DynamicBags.lua; coordinated top-most one-window-at-a-time Escape ordering across DynamicBagsBankFrame, DynamicBagsFrame, DynamicBagsStandaloneFrame, and DesktopWindows SUPPORTED_BLIZZ_FRAMES (closing bank -> bags -> Blizzard panels sequentially before GameMenuFrame can open); and added a ToggleGameMenu/CloseSpecialWindows failsafe in DynamicBags.lua so even if DynamicBagsFrame or DynamicBagsBankFrame is protected by slot children or missed by CloseSpecialWindows, ESC reliably clears search first or closes the top-most bag/bank window without opening Options / Game Menu while keeping B keybind two-way toggling spotless before and after ESC." },
        { type = "FIX",     text = "DynamicBags ESC & B Keybind Closing, CloseAllBags & Escape-First Search Clear (18/11/2026): Removed raw EnableKeyboard(true) / OnKeyDown capture from DynamicBagsFrame and DynamicBagsBankFrame so B and ESC never get swallowed; preserved Escape-first search clearing when focused (OnEscapePressed) or unfocused via a combat-guarded CloseSpecialWindows post-hook (restoring open bag/bank windows once while clearing search, then closing cleanly on the second ESC via UISpecialFrames); and updated ToggleWindow() and hooked CloseAllBags() so B and CloseAllBags hide both DynamicBagsFrame and DynamicBagsBankFrame reliably out of combat." },
        { type = "FIX",     text = "DecorVendor /tm Taint Guard & Conflict Scanner Support (18/11/2026): Added runtime ADDON_ACTION_FORBIDDEN listening in DynamicMarker (bundled and standalone) for SetRaidTarget calls with 30-second per-addon rate-limited chat alerts naming the offending addon and instructing users to disable it and completely restart the game client (/reload alone will not clear Blizzard's raid-marker lockout); registered DecorVendor ('Decor Vendor') in CONFLICT_REGISTRY.DynamicMarker, FRIENDLY_CONFLICT_NAMES, and DynamicMarker's CONFLICT_ADDONS / ADVISORY_CONFLICT_ADDONS with 1-click Outdoor Housing Only and Disable (Never in DynamicLoadDB) resolutions across Guided Setup, /ds conflicts, and standalone DynamicMarker; and updated DynamicMarker's [DynamicMark] Macro Setup troubleshooting note." },
        { type = "FIX",     text = "Item Socketing Esc Close, DIALOG-vs-HIGH Click-to-Front Strata Focus (Zero Cooldown Manager Bleed-Through), and Adventure Guide Mousewheel Scrolling Fixes (18/11/2026): Marked session-bound interaction panels (Item Socketing, Trade, Gossip, Quest, Item Upgrade, and Revival Catalyst) as non-restorable so closing them clears their state immediately without ever re-showing an empty ghost shell on Esc (pressing Esc once cleanly closes Item Socketing and pressing Esc again closes Character Info); placed the top-focused managed window on DIALOG strata and all unfocused open panels on HIGH strata (with SetToplevel disabled, zero C++ Raise calls, and root FrameLevel clamped to 1) so Cooldown Manager icons never bleed through either focused or unfocused panels while whichever window you click or open always sits cleanly on top of all other windows with Character gear slots, EllesmereUI stats panes, and TalentLoadoutManager overlays properly layered; and stopped the Adventure Guide root frame and passive border chrome from swallowing mousewheel input so scrolling boss overviews, abilities, loot lists, and lore works smoothly again while preserving Ctrl+Scroll and Ctrl+Shift+Scroll window scaling when Ctrl is held." },
        { type = "FIX",     text = "Desktop Window Coexistence, Strata-Based Focus, Character Sheet Pane Visibility, Spellbook Tab Memory & Free Dragging (18/11/2026): Eliminated client freezes, buried Character Info left/right panes (both stock Blizzard gear slots/model at FrameLevel 101 and EllesmereUIBlizzardSkin right-side Character Stats at FrameLevel 50), and talent tree/sidebar blanking by disabling SetToplevel and removing C++ Raise() calls that jumped root window backgrounds to FrameLevel 5020 above third-party 5000-level frames, clamping any stray FrameLevel > 15 back to 1, and managing z-order cleanly via strata focus (HIGH for the active window, MEDIUM for background windows) without synthetic frame-level inflation, SecureHandler wrapper overhead, or UpdateUIPanelPositions re-anchor loops; ensured Character Info (C) keeps its right-side stats pane expanded and refreshed on open whenever not collapsed by the user; detached side-by-side panels cleanly without ever hiding already-open frames; fixed Spellbook tab selection getting forced back to Talents when opening C, I, or L; stopped C from getting pushed next to Group Finder (I) or locked in place and fixed dragging across stats and background panes; kept Adventure Guide boss loot lists intact, Guild & Communities and Group Finder taint-free, and fullscreen World Map untouched; added one-window-at-a-time reverse-order Escape closing both in and out of combat; routed Ctrl+Scroll (session 5% scaling) and Ctrl+Shift+Scroll (permanent 5% scaling); and ensured Right-Click header resets and Reset Window Defaults persist cleanly across /reload." },
        { type = "FEATURE", text = "Release v2.3.0 - 2-Tab Suite Studio, Core MS-Windows Desktop Window Manager & 32-Panel Quest Log Coexistence (16/11/2026): Upgraded Suite Studio into a 2-tab workspace (Tab 1 'Theme & Typography' via /ds studio or /ds theme; Tab 2 'Desktop Windows & Menus' via /ds windows or /ds win) and migrated the Blizzard Desktop Window Manager into DynamicSuite Core (_G.DynamicSuite.DesktopWindows & DynamicSuiteDB.global.desktopWindows with automatic one-time migration from DynamicPrepDB so window management works even when DynamicPrep is disabled). Expanded side-by-side coexistence to 32 Blizzard panels by bringing the windowed/docked WorldMapFrame (Quest Log 'L') into full coexistence alongside PlayerSpellsFrame, CharacterFrame, PVEFrame, CollectionsJournal, ProfessionsFrame, and all standard panels while keeping fullscreen WorldMapFrame and GameMenuFrame untouched; replaced unclamped free-floating movement with mandatory scale-aware ClampDesktopWindowOffset boundary clamping across drag ticks, drag stop, OnShow, OnSizeChanged (Talent/Spec/Spellbook switches), UI_SCALE_CHANGED, and DISPLAY_SIZE_CHANGED so no panel or [X] close button can ever spawn or get stuck off-screen; enabled modifier-free Left-Click dragging from any empty window background or passive chrome (guarded via GetMouseFoci() so interactive child controls are never hijacked); added a zero-taint GLOBAL_MOUSE_DOWN click-to-raise z-order listener and UISpecialFrames sorter so clicking any open window brings it to the front and pressing Escape always closes the top-most window first; and preserved silent external mover coexistence (NoAutoClose, BlizzMove, DeModal, MoveAny, EllesmereUI, Leatrix Plus, ElvUI) with a live status banner on Tab 2." },
        { type = "UI",      text = "Central Popover Auto-Close Registry, Suite-Wide 3-Way Interactive 4px Obsidian Scrollbars & DynamicChat Polish (16/11/2026): Added UI.RegisterPopupCloser(key, closeFn) and owner-button OnHide hooks across DynamicSuite and all 8 modules so closing the main window, minimising, switching tabs/modules, or entering HUD Edit Mode cleanly dismisses all active dropdowns and popovers; upgraded every scrollbar across Suite Studio, Global Smart Search, Guided Setup, dropdown popovers, and module workspaces to full 3-way interaction (Mousewheel, Left-Click & Drag on the Button thumb with IsMouseButtonDown release guard and OnHide cleanup, and Left-Click on the track to jump to cursor position); and fixed DynamicChat's Font Dropdown popover/scrollbar, PrintMsg routing, and StaticPopup-free dark-obsidian reload confirmation modal." },
        { type = "FEATURE", text = "Shared Media Discovery (LibSharedMedia-3.0, DBM, EXBOSS, BigWigs, WeakAuras, ElvUI), Curated Blizzard Chat Sounds & Self-Whisper Alerts (15/11/2026): Added runtime LibSharedMedia-3.0, DBM, EXBOSS, BigWigs, WeakAuras, and ElvUI discovery for both Sounds and Fonts across Theme & Font Studio (and standalone DynamicMarker) plus DynamicChat Tab 3 with PLAYER_LOGIN delayed scanning and searchable grouped dropdowns; removed temporary .wav sound files and LibSharedMedia .wav registration in favour of 7 curated native Blizzard SOUNDKIT alerts (Blizzard Raid Warning, Blizzard Whisper, Blizzard Battle.net, Blizzard Ready Check, Blizzard Map Ping, Blizzard Auction Bell, and Blizzard Quest Complete) with dual PlaySound / PlaySoundFile routing; restored self-whisper notification alerts on incoming WHISPER / BN_WHISPER events; and added automatic runtime fallback (to Blizzard Raid Warning for sounds or Expressway for fonts) when an external media pack is disabled." },
        { type = "IMPROVED", text = "DynamicMarker Unbound-by-Default World Flare Hotkeys & Guided Setup Assignment (15/11/2026): Removed the hardcoded F4 and F5 World Flare defaults so fresh installs and Resets start with both keys 'Unbound' (leaving your own Blizzard and action bar bindings untouched while preserving any existing saved DynamicMarkerDB hotkeys), added optional single-button Cycle World Flare and Clear All Flares keybind capture rows to both Suite/Standalone Guided Setup and the World Flare Keys (/dm flares) tab ('Click to bind, Right-click to unbind'), and refined capture behaviour so Escape cancels without losing the current key while Backspace/Delete or Right-Click clears to Unbound." },
        { type = "FIX",     text = "Release v2.1.2 - DynamicPrep Midnight Season 2 Enchantable Slot List Fix (15/11/2026): Updated DynamicPrep's equipped gear enchant scanner to remove false-positive missing-enchant alerts on Cloak and Wrist (which do not have enchants in Midnight) and added Head and Shoulder to the Midnight Season 2 enchantable slot list (Head, Shoulder, Chest, Legs, Feet, Ring 1, Ring 2, Main Hand, and Off-Hand weapons)." },
        { type = "FEATURE", text = "Release v2.1.1 - Live 3-Row HUD Appearance Bar (560x110) & First-Open /ds + First-Click [+ HUD] Fixes (15/11/2026): Expanded DynamicSuiteEditModeModal into a unified 560x110 3-row draggable dock by adding Row 3 (Live Appearance Bar) with a 20%-100% Opacity slider (step 5%, keeping mover borders/labels readable via SetIgnoreParentAlpha), Accent | Dark | None Border Style segmented pills synced 1:1 with module sub-settings, Horiz | Vert Orientation toggle for Target Icon Bar, World Flare Bar, and Raid Buffs (with automatic screen-bounds re-clamping and dimmed fixed-layout state for Alert Toast, Prep Bar, and Chat Frame), and full Position/Scale/Opacity/Border/Orientation [Reset]. Fixed first-open /ds empty Left Suite Rail (unconditional explicit Left Rail dimensions, child population, and OnShow visibility plus guarded lazy wrappers), eliminated first-click [+ HUD] missing movers via EnsureAllEditModeHudFramesInitialized() and callback-first SyncAllEditModeHuds ordering, guarded modal construction against premature OnHide cancellation, and kept the HUD Selector popup closed on entry." },
        { type = "FIX",     text = "HUD Edit Mode Mover Visibility & Prep Bar Drag Shield Layering (15/11/2026): Fixed isHudEditModeActive lexical scoping in DynamicSuite_UI.lua so Shown HUDs render live previews and mover overlays immediately when entering HUD Edit Mode, split DynamicPrep's SetBarEditMode and SetBuffsEditMode states, and disabled child mouse capture during HUD Edit Mode so bars drag smoothly across their full width." },
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
    ["DynamicSuite"]    = true,
    ["DynamicLoad"]     = true,
    ["DynamicMarker"]   = true,
    ["DynamicCursor"]   = true,
    ["DynamicZoom"]     = true,
    ["DynamicFPS"]      = true,
    ["DynamicTalent"]   = true,
    ["DynamicPrep"]     = true,
    ["DynamicGroup"]    = true,
    ["DynamicBags"]     = true,
    ["DynamicChat"]     = true,
    ["DynamicMail"]     = true,
    ["DynamicVault"]    = true,
    ["DynamicDialogue"] = true,
}
local SUITE_MODULES = addonTable.SUITE_MODULES or {
    "DynamicSuite",
    "DynamicMarker",
    "DynamicGroup",
    "DynamicPrep",
    "DynamicTalent",
    "DynamicCursor",
    "DynamicVault",
    "DynamicDialogue",
    "DynamicBags",
    "DynamicMail",
    "DynamicChat",
    "DynamicLoad",
    "DynamicFPS",
    "DynamicZoom",
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

-- Canonical 4-Category Left-Rail Grouping (v2.6.6+)
local SUITE_RAIL_CATEGORIES = {
    { key = "COMBAT_GROUP",       label = "COMBAT & GROUP",       modules = { "marker", "group", "prep", "talent", "cursor" } },
    { key = "PROGRESSION_QUESTS", label = "PROGRESSION & QUESTS", modules = { "vault", "dialogue" } },
    { key = "INVENTORY_SOCIAL",   label = "INVENTORY & SOCIAL",   modules = { "bags", "mail", "chat" } },
    { key = "PERFORMANCE_SYSTEM", label = "PERFORMANCE & SYSTEM", modules = { "load", "fps", "zoom" } },
}
addonTable.SUITE_RAIL_CATEGORIES = SUITE_RAIL_CATEGORIES
DynamicSuite.RAIL_CATEGORIES = SUITE_RAIL_CATEGORIES

-- Peer DynamicSuite Modules Metadata (Extensible DYNAMIC MODULES Rail)
local SUITE_MODULE_LIST = addonTable.SUITE_MODULE_LIST or {
    -- COMBAT & GROUP
    {
        key = "marker",
        id = "marker",
        order = 10,
        railGroup = "COMBAT_GROUP",
        name = "DynamicMarker",
        title = "DynamicMarker",
        addonName = "DynamicMarker",
        slash = "/dm",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_marker.tga",
        subtitle = "Targets, Flares & Kick",
        category = "Combat & Group -- Target Marking, World Flares & Kick Macro",
        desc = "One-button focus target marking, optional ground flare hotkeys (unbound by default), and a single interrupt macro that swaps spells automatically for every class and spec.",
    },
    {
        key = "group",
        id = "group",
        order = 20,
        railGroup = "COMBAT_GROUP",
        name = "DynamicGroup",
        title = "DynamicGroup",
        addonName = "DynamicGroup",
        slash = "/dgroup",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_group.tga",
        subtitle = "Group Finder & Invites",
        category = "Combat & Group -- Premade Group Filter, Roster & Auto-Invite",
        desc = "Filters Premade Groups by region, Mythic+ rating, and Lust or Battle Res, with 1-click sign-up, auto-invite, and automatic keystone slotting.",
    },
    {
        key = "prep",
        id = "prep",
        order = 30,
        railGroup = "COMBAT_GROUP",
        name = "DynamicPrep",
        title = "DynamicPrep",
        addonName = "DynamicPrep",
        slash = "/dprep",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_prep.tga",
        subtitle = "Prep Bar & Raid Buffs",
        category = "Combat & Group -- Readiness Bar, Raid Buffs & Quick QoL",
        desc = "Live readiness top bar with Great Vault and Talent Loadout capsules, clickable raid buffs, consumables, and fast quest/cutscene skipping.",
    },
    {
        key = "talent",
        id = "talent",
        order = 35,
        railGroup = "COMBAT_GROUP",
        name = "DynamicTalent",
        title = "DynamicTalent",
        addonName = "DynamicTalent",
        slash = "/dt",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_talent.tga",
        subtitle = "Talent Loadouts & Binds",
        category = "Combat & Group -- Talent Loadouts, Zone/Boss/PvP Binds & Swap Alerts",
        desc = "Unlimited per-spec talent loadout library, WCL/Northern Sky/Blizzard importer, PlayerSpellsFrame dock, Raid/M+/PvP/Zone talent binds, custom group ordering, and 1-click swap reminder toasts.",
    },
    {
        key = "cursor",
        id = "cursor",
        order = 38,
        railGroup = "COMBAT_GROUP",
        name = "DynamicCursor",
        title = "DynamicCursor",
        addonName = "DynamicCursor",
        slash = "/dcur",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_cursor.tga",
        subtitle = "Cursor Ring, Crosshair & Trail",
        category = "Combat & Group -- Cursor Ring, GCD/Cast Arc, Crosshair & Trail",
        desc = "Customisable cursor ring with radial GCD and cast/channel/empower arcs, character crosshair, Find My Cursor locator, pooled cursor trail, and smart cursor tooltips.",
    },
    -- PROGRESSION & QUESTS
    {
        key = "vault",
        id = "vault",
        order = 40,
        railGroup = "PROGRESSION_QUESTS",
        name = "DynamicVault",
        title = "DynamicVault",
        addonName = "DynamicVault",
        slash = "/dv",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_vault.tga",
        subtitle = "Great Vault & Weeklies",
        category = "Progression & Quests -- Great Vault, Crests & Weekly Checklist",
        desc = "Account-wide Great Vault tracker for Raid, Mythic+, and Delves, plus Restored Coffer Keys, Catalyst charges, Crests, owned Keystones, and auto-resetting weekly checklists.",
    },
    {
        key = "dialogue",
        id = "dialogue",
        order = 50,
        railGroup = "PROGRESSION_QUESTS",
        name = "DynamicDialogue",
        title = "DynamicDialogue",
        addonName = "DynamicDialogue",
        slash = "/dd",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_dialogue.tga",
        subtitle = "Quest & Gossip Reader",
        category = "Progression & Quests -- Clean Quest & Gossip Dialogue Reader",
        desc = "Clean, easy-to-read Quest and Gossip reader with 1-9 option hotkeys, Spacebar accept and turn-in, clear reward cards, and automatic yielding to other dialogue addons.",
    },
    -- INVENTORY & SOCIAL
    {
        key = "bags",
        id = "bags",
        order = 60,
        railGroup = "INVENTORY_SOCIAL",
        name = "DynamicBags",
        title = "DynamicBags",
        addonName = "DynamicBags",
        slash = "/dbag",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_bags.tga",
        subtitle = "Bags, Bank & Alt Vault",
        category = "Inventory & Social -- Category Bags, Bank & Alt Item Vault",
        desc = "Fast category bags, matching Bank, Warband, and Guild Bank window, alt item lookup, automatic repair, junk selling, and instant auto-loot.",
    },
    {
        key = "mail",
        id = "mail",
        order = 70,
        railGroup = "INVENTORY_SOCIAL",
        name = "DynamicMail",
        title = "DynamicMail",
        addonName = "DynamicMail",
        slash = "/dmail",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_mail.tga",
        subtitle = "Inbox, Alts & Gold Mail",
        category = "Inventory & Social -- Mailbox Collection, Alt Picker & Quick Attach",
        desc = "One-click inbox collection (Open All, AH Gold, Items Only), alt recipient picker synced with DynamicBags, and Alt+Left-Click quick bag attaching.",
    },
    {
        key = "chat",
        id = "chat",
        order = 80,
        railGroup = "INVENTORY_SOCIAL",
        name = "DynamicChat",
        title = "DynamicChat",
        addonName = "DynamicChat",
        slash = "/dchat",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_chat.tga",
        subtitle = "Whisper /ww & Chat Skin",
        category = "Inventory & Social -- Target Whisper (/ww), Chat Skin & History",
        desc = "Instant /ww target whispers, smoked-glass chat frame with left shortcut rail, clickable web links, sound alerts, and chat history saved across reloads.",
    },
    -- PERFORMANCE & SYSTEM
    {
        key = "load",
        id = "load",
        order = 90,
        railGroup = "PERFORMANCE_SYSTEM",
        name = "DynamicLoad",
        title = "DynamicLoad",
        addonName = "DynamicLoad",
        slash = "/dl",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_load.tga",
        subtitle = "Zone Addon Profiles",
        category = "Performance & System -- Automatic Per-Zone Addon Manager",
        desc = "Automatically switches your active addons between Outdoor, Delves, Dungeons, Raid, and PvP using simple By Zone, Always, and Never rules.",
    },
    {
        key = "fps",
        id = "fps",
        order = 100,
        railGroup = "PERFORMANCE_SYSTEM",
        name = "DynamicFPS",
        title = "DynamicFPS",
        addonName = "DynamicFPS",
        slash = "/dfps",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_fps.tga",
        subtitle = "Zone Graphics & FPS",
        category = "Performance & System -- Per-Zone Graphics & Smooth Combat FPS",
        desc = "Switches graphics quality per zone without reloading, keeps combat framerates smooth, tunes spell queue timing, and protects boss ground effects.",
    },
    {
        key = "zoom",
        id = "zoom",
        order = 110,
        railGroup = "PERFORMANCE_SYSTEM",
        name = "DynamicZoom",
        title = "DynamicZoom",
        addonName = "DynamicZoom",
        slash = "/dz",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_zoom.tga",
        subtitle = "Max Zoom & Camera",
        category = "Performance & System -- Max Camera Distance & Smart Framing",
        desc = "Unlocks maximum 39-yard camera distance, smooth fast scroll-wheel zoom, see-through foliage and pillars, and automatic per-zone camera framing.",
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
        "FocusMarker", "EllesmereUIQuickdraw", "EllesmereUI_Quickdraw", "MRT", "TargetCharms", "DejaMark", "EasyMarker", "WorldMarkers", "DecorVendor",
        addons = { "FocusMarker", "EllesmereUIQuickdraw", "EllesmereUI_Quickdraw", "MRT", "TargetCharms", "DejaMark", "EasyMarker", "WorldMarkers", "DecorVendor" },
        conflicts = { "FocusMarker", "EllesmereUIQuickdraw", "EllesmereUI_Quickdraw", "MRT", "TargetCharms", "DejaMark", "EasyMarker", "WorldMarkers", "DecorVendor" },
        hardConflicts = { "FocusMarker", "EllesmereUIQuickdraw", "EllesmereUI_Quickdraw", "MRT", "TargetCharms", "DejaMark", "EasyMarker", "WorldMarkers", "DecorVendor" },
        partialConflicts = {},
        softConflicts = {},
        category = "Target & Ground Markers",
        hasLegacyMigration = { FocusMarker = true },
    },
    DynamicCursor = {
        "CursorTrail", "UltimateMouseCursor", "CursorRing", "SparkPoint", "Crosshairs", "EllesmereUICursor", "EllesmereUI_Cursor",
        addons = { "CursorTrail", "UltimateMouseCursor", "CursorRing", "SparkPoint", "Crosshairs", "EllesmereUICursor", "EllesmereUI_Cursor", "EllesmereUIQoL", "EllesmereUI_QoL" },
        conflicts = { "CursorTrail", "UltimateMouseCursor", "CursorRing", "SparkPoint", "Crosshairs", "EllesmereUICursor", "EllesmereUI_Cursor" },
        hardConflicts = { "CursorTrail", "UltimateMouseCursor", "CursorRing", "SparkPoint", "Crosshairs", "EllesmereUICursor", "EllesmereUI_Cursor" },
        partialConflicts = { "EllesmereUIQoL", "EllesmereUI_QoL" },
        softConflicts = { "EllesmereUIQoL", "EllesmereUI_QoL" },
        category = "Cursor Ring, Crosshair & Trail",
    },
    DynamicZoom = {
        "DynamicCam", "MaxCam", "ActionCamPlus", "FasterCamera", "AdvancedInterfaceOptions",
        addons = { "DynamicCam", "MaxCam", "ActionCamPlus", "FasterCamera", "AdvancedInterfaceOptions", "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL" },
        conflicts = { "DynamicCam", "MaxCam", "ActionCamPlus", "FasterCamera", "AdvancedInterfaceOptions" },
        hardConflicts = { "DynamicCam", "MaxCam", "ActionCamPlus", "FasterCamera", "AdvancedInterfaceOptions" },
        partialConflicts = { "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL" },
        softConflicts = { "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL" },
        category = "Camera Zoom & Optics",
    },
    DynamicFPS = {
        "Hyperframe", "AutoCombatLogger", "LoggerHead", "RaiderIO_AutoCombatLog", "!ArchonLogger", "ArchonLogger",
        addons = { "Hyperframe", "AutoCombatLogger", "LoggerHead", "RaiderIO_AutoCombatLog", "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL", "!ArchonLogger", "ArchonLogger" },
        conflicts = { "Hyperframe", "AutoCombatLogger", "LoggerHead", "RaiderIO_AutoCombatLog" },
        hardConflicts = { "Hyperframe", "AutoCombatLogger", "LoggerHead", "RaiderIO_AutoCombatLog" },
        partialConflicts = { "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL", "!ArchonLogger", "ArchonLogger" },
        softConflicts = { "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL", "!ArchonLogger", "ArchonLogger" },
        category = "Graphics & Combat Logging",
    },
    DynamicPrep = {
        "EllesmereUIAuraBuffReminders", "EllesmereUI_AuraBuffReminders", "ClickableRaidBuffs",
        "EnhanceQoL", "Leatrix_Plus", "EllesmereUI", "EllesmereUIQoL", "EllesmereUI_QoL", "EllesmereUIBlizzardSkin", "EllesmereUIMythicTimer", "EllesmereUI_MythicPlus",
        "NoAutoClose", "BlizzMove", "DeModal", "MoveAny",
        "DialogUI", "DialogueUI", "Plumber", "Immersion", "Storyline", "AutoTurnIn", "BeQuiet", "TalkLess", "ElvUI", "WindTools",
        "ErrorFilter", "ErrorMonster",
        addons = {
            "EllesmereUIAuraBuffReminders", "EllesmereUI_AuraBuffReminders", "ClickableRaidBuffs",
            "EnhanceQoL", "Leatrix_Plus", "EllesmereUI", "EllesmereUIQoL", "EllesmereUI_QoL", "EllesmereUIBlizzardSkin", "EllesmereUIMythicTimer", "EllesmereUI_MythicPlus",
            "NoAutoClose", "BlizzMove", "DeModal", "MoveAny",
            "DialogUI", "DialogueUI", "Plumber", "Immersion", "Storyline", "AutoTurnIn", "BeQuiet", "TalkLess", "ElvUI", "WindTools",
            "ErrorFilter", "ErrorMonster",
        },
        conflicts = { "EllesmereUIAuraBuffReminders", "EllesmereUI_AuraBuffReminders", "ClickableRaidBuffs" },
        hardConflicts = { "EllesmereUIAuraBuffReminders", "EllesmereUI_AuraBuffReminders", "ClickableRaidBuffs" },
        partialConflicts = { "EnhanceQoL", "Leatrix_Plus", "EllesmereUI", "EllesmereUIQoL", "EllesmereUI_QoL", "EllesmereUIBlizzardSkin", "EllesmereUIMythicTimer", "EllesmereUI_MythicPlus", "NoAutoClose", "BlizzMove", "DeModal", "MoveAny", "DialogUI", "DialogueUI", "Plumber", "Immersion", "Storyline", "AutoTurnIn", "BeQuiet", "TalkLess", "ElvUI", "WindTools", "ErrorFilter", "ErrorMonster" },
        softConflicts = { "EnhanceQoL", "Leatrix_Plus", "EllesmereUI", "EllesmereUIQoL", "EllesmereUI_QoL", "EllesmereUIBlizzardSkin", "EllesmereUIMythicTimer", "EllesmereUI_MythicPlus", "NoAutoClose", "BlizzMove", "DeModal", "MoveAny", "DialogUI", "DialogueUI", "Plumber", "Immersion", "Storyline", "AutoTurnIn", "BeQuiet", "TalkLess", "ElvUI", "WindTools", "ErrorFilter", "ErrorMonster" },
        category = "Readiness & Automation",
    },
    DynamicTalent = {
        "TalentLoadoutManager", "TalentLoadoutsEx", "BtWLoadouts", "ImprovedTalentLoadouts",
        addons = { "TalentLoadoutManager", "TalentLoadoutsEx", "BtWLoadouts", "ImprovedTalentLoadouts" },
        conflicts = {},
        hardConflicts = {},
        partialConflicts = { "TalentLoadoutManager", "TalentLoadoutsEx", "BtWLoadouts", "ImprovedTalentLoadouts" },
        softConflicts = { "TalentLoadoutManager", "TalentLoadoutsEx", "BtWLoadouts", "ImprovedTalentLoadouts" },
        category = "Talent Loadouts & Binds",
    },
    DynamicGroup = {
        "EllesmereUIGroupFinder", "EllesmereUI_GroupFinder", "PremadeGroupsFilter", "PremadeRegionFilter", "LFGListFilter", "PremadeGroupFinder", "WorldQuestGroupFinder",
        addons = { "EllesmereUIGroupFinder", "EllesmereUI_GroupFinder", "PremadeGroupsFilter", "PremadeRegionFilter", "LFGListFilter", "PremadeGroupFinder", "WorldQuestGroupFinder", "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL", "EllesmereUIMythicTimer", "EllesmereUI_MythicPlus" },
        conflicts = { "EllesmereUIGroupFinder", "EllesmereUI_GroupFinder", "PremadeGroupsFilter", "PremadeRegionFilter", "LFGListFilter", "PremadeGroupFinder", "WorldQuestGroupFinder" },
        hardConflicts = { "EllesmereUIGroupFinder", "EllesmereUI_GroupFinder", "PremadeGroupsFilter", "PremadeRegionFilter", "LFGListFilter", "PremadeGroupFinder", "WorldQuestGroupFinder" },
        partialConflicts = { "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL", "EllesmereUIMythicTimer", "EllesmereUI_MythicPlus" },
        softConflicts = { "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL", "EllesmereUIMythicTimer", "EllesmereUI_MythicPlus" },
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
    DynamicMail = {
        "Postal", "EasyMail", "CT_MailMod", "InboxMailBag", "MailCommander",
        addons = { "Postal", "EasyMail", "CT_MailMod", "InboxMailBag", "MailCommander", "TradeSkillMaster", "Leatrix_Plus", "EnhanceQoL", "ElvUI" },
        conflicts = { "Postal", "EasyMail", "CT_MailMod", "InboxMailBag", "MailCommander" },
        hardConflicts = { "Postal", "EasyMail", "CT_MailMod", "InboxMailBag", "MailCommander" },
        partialConflicts = { "TradeSkillMaster", "Leatrix_Plus", "EnhanceQoL", "ElvUI" },
        softConflicts = { "TradeSkillMaster", "Leatrix_Plus", "EnhanceQoL", "ElvUI" },
        category = "Mailbox & Auction Gold",
    },
    DynamicVault = {
        addons = { "SavedInstances", "Altoholic", "ChoreTracker", "WeeklyKnowledge", "PermoksAccountManager" },
        conflicts = {},
        hardConflicts = {},
        partialConflicts = { "SavedInstances", "Altoholic", "ChoreTracker", "WeeklyKnowledge", "PermoksAccountManager" },
        softConflicts = { "SavedInstances", "Altoholic", "ChoreTracker", "WeeklyKnowledge", "PermoksAccountManager" },
        category = "Account Vault & Weekly Tracking",
    },
    DynamicDialogue = {
        "DialogueUI", "DialogUI", "Immersion", "Storyline",
        addons = { "DialogueUI", "DialogUI", "Immersion", "Storyline", "EllesmereUIQoL", "EllesmereUI_QoL", "EnhanceQoL", "AutoTurnIn", "Leatrix_Plus" },
        conflicts = { "DialogueUI", "DialogUI", "Immersion", "Storyline" },
        hardConflicts = { "DialogueUI", "DialogUI", "Immersion", "Storyline" },
        partialConflicts = { "EllesmereUIQoL", "EllesmereUI_QoL", "EnhanceQoL", "AutoTurnIn", "Leatrix_Plus" },
        softConflicts = { "EllesmereUIQoL", "EllesmereUI_QoL", "EnhanceQoL", "AutoTurnIn", "Leatrix_Plus" },
        category = "Quest & Gossip Dialogue Reader",
    },
}
CONFLICT_REGISTRY.load     = CONFLICT_REGISTRY.DynamicLoad
CONFLICT_REGISTRY.marker   = CONFLICT_REGISTRY.DynamicMarker
CONFLICT_REGISTRY.cursor   = CONFLICT_REGISTRY.DynamicCursor
CONFLICT_REGISTRY.zoom     = CONFLICT_REGISTRY.DynamicZoom
CONFLICT_REGISTRY.fps      = CONFLICT_REGISTRY.DynamicFPS
CONFLICT_REGISTRY.prep     = CONFLICT_REGISTRY.DynamicPrep
CONFLICT_REGISTRY.talent   = CONFLICT_REGISTRY.DynamicTalent
CONFLICT_REGISTRY.group    = CONFLICT_REGISTRY.DynamicGroup
CONFLICT_REGISTRY.bags     = CONFLICT_REGISTRY.DynamicBags
CONFLICT_REGISTRY.chat     = CONFLICT_REGISTRY.DynamicChat
CONFLICT_REGISTRY.mail     = CONFLICT_REGISTRY.DynamicMail
CONFLICT_REGISTRY.vault    = CONFLICT_REGISTRY.DynamicVault
CONFLICT_REGISTRY.dialogue = CONFLICT_REGISTRY.DynamicDialogue
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
    ["DecorVendor"]              = "Decor Vendor",
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
    ["EllesmereUIBlizzardSkin"]  = "EllesmereUI Blizzard Skins+",
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
    ["NoAutoClose"]              = "NoAutoClose",
    ["BlizzMove"]                = "BlizzMove",
    ["DeModal"]                  = "DeModal",
    ["MoveAny"]                  = "MoveAny",
    ["Postal"]                   = "Postal",
    ["EasyMail"]                 = "EasyMail",
    ["CT_MailMod"]               = "CT_MailMod",
    ["InboxMailBag"]             = "InboxMailBag",
    ["MailCommander"]            = "MailCommander",
    ["TradeSkillMaster"]         = "TradeSkillMaster (TSM)",
    ["TalentLoadoutManager"]     = "Talent Loadout Manager (TLM)",
    ["TalentLoadoutsEx"]         = "Talent Loadouts Ex",
    ["BtWLoadouts"]              = "BtWLoadouts",
    ["ImprovedTalentLoadouts"]   = "Improved Talent Loadouts",
    ["ErrorFilter"]              = "ErrorFilter",
    ["ErrorMonster"]             = "ErrorMonster",
    ["CursorTrail"]              = "CursorTrail",
    ["UltimateMouseCursor"]      = "UltimateMouseCursor",
    ["CursorRing"]               = "CursorRing",
    ["SparkPoint"]               = "SparkPoint",
    ["Crosshairs"]               = "Crosshairs",
    ["EllesmereUICursor"]        = "EllesmereUI Cursor",
    ["EllesmereUI_Cursor"]       = "EllesmereUI Cursor",
}
addonTable.FRIENDLY_CONFLICT_NAMES = FRIENDLY_CONFLICT_NAMES
DynamicSuite.FRIENDLY_CONFLICT_NAMES = FRIENDLY_CONFLICT_NAMES

local CONFLICT_YIELD_FEATURES = {
    ["DialogueUI"]               = "gossip/camera control",
    ["TalentLoadoutManager"]     = "Talent Loadouts rail (auto-yields & offers 1-click import)",
    ["TalentLoadoutsEx"]         = "Talent Loadouts rail",
    ["BtWLoadouts"]              = "Talent Loadouts rail",
    ["ImprovedTalentLoadouts"]   = "Talent Loadouts rail",
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
    ["EllesmereUIQoL"]           = "overlapping QoL features",
    ["EllesmereUI_QoL"]          = "overlapping QoL features",
    ["EllesmereUIBlizzardSkin"]  = "Blizzard Window Mover (Shifter)",
    ["EllesmereUIMythicTimer"]   = "Mythic+ Keystone & Timer tools",
    ["EllesmereUI_MythicPlus"]   = "Mythic+ Keystone & Timer tools",
    ["NoAutoClose"]              = "Suite Studio -> Desktop Windows & Menus (Side-by-Side Panels, Drag & Scroll Scale)",
    ["BlizzMove"]                = "Suite Studio -> Desktop Windows & Menus (Side-by-Side Panels, Drag & Scroll Scale)",
    ["DeModal"]                  = "Suite Studio -> Desktop Windows & Menus (Side-by-Side Panels, Drag & Scroll Scale)",
    ["MoveAny"]                  = "Suite Studio -> Desktop Windows & Menus (Side-by-Side Panels, Drag & Scroll Scale)",
    ["DecorVendor"]              = "raid target marker (/tm) taint in dungeons & raids",
    ["TradeSkillMaster"]         = "mailbox / sending overlap (DynamicMail)",
    ["EnhanceQoL"]               = "overlapping QoL features",
    ["ErrorFilter"]              = "red error text filtering",
    ["ErrorMonster"]             = "red error text filtering",
    ["CursorTrail"]              = "cursor ring / trail overlay",
    ["UltimateMouseCursor"]      = "cursor ring / trail overlay",
    ["CursorRing"]               = "cursor ring / GCD arc",
    ["SparkPoint"]               = "cursor ring / trail overlay",
    ["Crosshairs"]               = "character crosshair overlay",
    ["EllesmereUICursor"]        = "cursor ring, GCD arc & trail",
    ["EllesmereUI_Cursor"]       = "cursor ring, GCD arc & trail",
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
addonTable.DEFAULT_DESKTOP_WINDOWS = {
    masterEnabled    = true,
    enabled          = true,
    sideBySide       = true,
    dragAnywhere     = true,
    draggable        = true,
    scrollScale      = true,
    positions        = {},
    scales           = {},
    migratedFromPrep = false,
}

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
    toastScale          = 1.0,
    toastAlpha          = 0.96,
    toastOpacity        = 0.96,
    toastDuration       = 12,
    toastActionDuration = 12,
    toastInfoDuration   = 5,
    toastSoundEnabled   = false,
    hudSnapMode      = "MAGNET",
    minimizedBarPos  = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
    editModeModalPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
    disabledModules  = {},
    yieldHooks       = {},
    acknowledgedConflicts = {},
    seenHardConflicts = {},
    guidedSetupDone          = false,
    showFeatureSpotlights    = true,
    seenSpotlights           = {},
    seenNewBadges            = {},
    showGameMenuSuiteBtn     = true,
    showGameMenuHudBtn       = true,
    replaceBlizzardAddonList = true,
    desktopWindows           = CopyTable(addonTable.DEFAULT_DESKTOP_WINDOWS),
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

function DynamicSuite.ClampToastActionDuration(v)
    v = tonumber(v)
    if v == 0 then return 0 end
    if not v or v < 0 then return 12 end
    if v <= 6 then return 5
    elseif v <= 10 then return 8
    elseif v <= 16 then return 12
    else return 20 end
end
addonTable.ClampToastActionDuration = DynamicSuite.ClampToastActionDuration

function DynamicSuite.ClampToastInfoDuration(v)
    v = tonumber(v)
    if v == 0 then return 0 end
    if not v or v < 0 then return 5 end
    if v <= 4 then return 3
    elseif v <= 6 then return 5
    elseif v <= 10 then return 8
    else return 12 end
end
addonTable.ClampToastInfoDuration = DynamicSuite.ClampToastInfoDuration

function DynamicSuite._MigrateTwoTierToastDurations(targetTbl, legacyFallbackTbl)
    if type(targetTbl) ~= "table" then return end
    if targetTbl.toastActionDuration == nil and targetTbl.toastInfoDuration == nil then
        local legacyDur = tonumber(targetTbl.toastDuration)
        if legacyDur == nil and type(legacyFallbackTbl) == "table" then
            legacyDur = tonumber(legacyFallbackTbl.toastDuration)
        end
        if legacyDur ~= nil then
            if legacyDur == 0 then
                targetTbl.toastActionDuration = 0
                targetTbl.toastInfoDuration = 0
            else
                targetTbl.toastInfoDuration = DynamicSuite.ClampToastInfoDuration(legacyDur)
                targetTbl.toastActionDuration = math.max(12, DynamicSuite.ClampToastActionDuration(legacyDur))
            end
        else
            targetTbl.toastActionDuration = 12
            targetTbl.toastInfoDuration = 5
        end
    else
        if targetTbl.toastActionDuration ~= nil then
            targetTbl.toastActionDuration = DynamicSuite.ClampToastActionDuration(targetTbl.toastActionDuration)
        else
            targetTbl.toastActionDuration = 12
        end
        if targetTbl.toastInfoDuration ~= nil then
            targetTbl.toastInfoDuration = DynamicSuite.ClampToastInfoDuration(targetTbl.toastInfoDuration)
        else
            targetTbl.toastInfoDuration = 5
        end
    end
end

local function EnsureSuiteGlobal()
    if addonTable._isFreshBrandNewInstall == nil then
        addonTable._isFreshBrandNewInstall = (_G.DynamicSuiteDB == nil and _G.DynamicLoadDB == nil)
    end
    if not _G.DynamicSuiteDB then
        _G.DynamicSuiteDB = {}
    end
    if not _G.DynamicSuiteDB.global then
        _G.DynamicSuiteDB.global = CopyTable(DEFAULT_SUITE_GLOBAL)
        -- Seamless migration from legacy DynamicLoadDB theme/window keys if present
        if type(_G.DynamicLoadDB) == "table" then
            for _, k in ipairs({ "windowWidth", "windowHeight", "windowScale", "windowAlpha", "surfaceTheme", "accentKey", "customAccent", "fontKey", "fontFamily", "pillFillAlpha", "recentColors", "toastPos", "toastDisplayMode", "toastScale", "toastAlpha", "toastDuration", "toastActionDuration", "toastInfoDuration", "toastSoundEnabled", "moduleOrder" }) do
                if _G.DynamicLoadDB[k] ~= nil then
                    if type(_G.DynamicLoadDB[k]) == "table" then
                        _G.DynamicSuiteDB.global[k] = CopyTable(_G.DynamicLoadDB[k])
                    else
                        _G.DynamicSuiteDB.global[k] = _G.DynamicLoadDB[k]
                    end
                end
            end
            if _G.DynamicLoadDB.toastActionDuration == nil and _G.DynamicLoadDB.toastInfoDuration == nil and _G.DynamicLoadDB.toastDuration ~= nil then
                _G.DynamicSuiteDB.global.toastActionDuration = nil
                _G.DynamicSuiteDB.global.toastInfoDuration = nil
                DynamicSuite._MigrateTwoTierToastDurations(_G.DynamicSuiteDB.global, _G.DynamicLoadDB)
            end
        end
    else
        DynamicSuite._MigrateTwoTierToastDurations(_G.DynamicSuiteDB.global, _G.DynamicLoadDB)
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
    if type(_G.DynamicLoadDB) == "table" then
        if _G.DynamicLoadDB.toastActionDuration == nil then
            _G.DynamicLoadDB.toastActionDuration = _G.DynamicSuiteDB.global.toastActionDuration
        end
        if _G.DynamicLoadDB.toastInfoDuration == nil then
            _G.DynamicLoadDB.toastInfoDuration = _G.DynamicSuiteDB.global.toastInfoDuration
        end
    end
    if GetCharScopeMode() == "CHARACTER" and _G.DynamicLoadDB and _G.DynamicLoadDB.charData then
        local charKey = GetCurrentCharKey()
        local cd = _G.DynamicLoadDB.charData[charKey]
        if cd and cd.theme then
            DynamicSuite._MigrateTwoTierToastDurations(cd.theme, _G.DynamicSuiteDB.global)
            for k, v in pairs(DEFAULT_SUITE_GLOBAL) do
                if cd.theme[k] == nil then
                    if type(v) == "table" then
                        cd.theme[k] = CopyTable(v)
                    else
                        cd.theme[k] = v
                    end
                end
            end
            if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.global) == "table" and type(_G.DynamicSuiteDB.global.desktopWindows) == "table" then
                cd.theme.desktopWindows = _G.DynamicSuiteDB.global.desktopWindows
            end
            return cd.theme
        end
    end
    return _G.DynamicSuiteDB.global
end
addonTable.GetSuiteGlobal = EnsureSuiteGlobal
DynamicSuite.GetSuiteGlobal = EnsureSuiteGlobal

function addonTable.GetCoreAccentRGB()
    if addonTable.UI and type(addonTable.UI.GetActiveAccentColor) == "function" then
        local ok, r, g, b = pcall(addonTable.UI.GetActiveAccentColor)
        if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return r, g, b
        end
    end
    return 0.220, 0.741, 0.973
end

function addonTable.GetCoreAccentHex()
    local r, g, b = addonTable.GetCoreAccentRGB()
    return string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

do
local SHARED_TOAST_STRATA = "TOOLTIP"
local SHARED_TOAST_LEVEL = 20
local lastSharedToastSoundAt = -999
local isRestackingToasts = false

local function ApplySharedToastFont(fs, size)
    if not fs or type(fs.SetFont) ~= "function" then return end
    local fontPath = nil
    if type(DynamicSuite.UI) == "table" and type(DynamicSuite.UI.GetFont) == "function" then
        local ok, p = pcall(DynamicSuite.UI.GetFont)
        if ok and type(p) == "string" and p ~= "" then fontPath = p end
    end
    if not fontPath and type(DynamicSuite.ResolveFontChoice) == "function" then
        local g = EnsureSuiteGlobal()
        local fk = g and (g.fontKey or g.fontFamily) or nil
        local ok, p = pcall(DynamicSuite.ResolveFontChoice, DynamicSuite, fk)
        if ok and type(p) == "string" and p ~= "" then fontPath = p end
    end
    if not fontPath then
        fontPath = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.TTF"
    end
    local okSet = pcall(fs.SetFont, fs, fontPath, size or 12, "")
    if not okSet then
        pcall(fs.SetFont, fs, _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 12, "")
    end
end

function DynamicSuite.GetSharedToastStyle(toastKind)
    local g = EnsureSuiteGlobal()
    local dl = (type(_G.DynamicLoadDB) == "table") and _G.DynamicLoadDB or nil
    local kind = (type(toastKind) == "string" and toastKind:upper() == "INFO") and "INFO" or "ACTION"

    local ar, ag, ab = 0.220, 0.741, 0.973
    local bgR, bgG, bgB = 0.035, 0.039, 0.051
    if addonTable.UI then
        if type(addonTable.UI.GetActiveAccentColor) == "function" then
            local ok, r, g2, b = pcall(addonTable.UI.GetActiveAccentColor)
            if ok and type(r) == "number" then ar, ag, ab = r, g2, b end
        end
        if type(addonTable.UI.GetActiveSurfaceColors) == "function" then
            local okS, surf = pcall(addonTable.UI.GetActiveSurfaceColors)
            if okS and type(surf) == "table" and type(surf.panel) == "table" then
                bgR = surf.panel.r or bgR
                bgG = surf.panel.g or bgG
                bgB = surf.panel.b or bgB
            end
        end
    end

    local enabled = true
    if g and g.toastEnabled ~= nil then
        enabled = (g.toastEnabled == true)
    elseif dl and dl.toastEnabled ~= nil then
        enabled = (dl.toastEnabled == true)
    end
    local dMode = (g and g.toastDisplayMode) or (dl and dl.toastDisplayMode)
    if dMode == "OFF" then enabled = false end

    local scale = tonumber((g and g.toastScale) or (dl and dl.toastScale)) or 1.0
    scale = math.max(0.60, math.min(1.50, scale))

    local opacity = tonumber((g and (g.toastOpacity or g.toastAlpha)) or (dl and (dl.toastOpacity or dl.toastAlpha))) or 0.96
    opacity = math.max(0.20, math.min(1.00, opacity))

    local bStyle = tostring((g and g.toastBorderStyle) or (dl and dl.toastBorderStyle) or "ACCENT"):upper()
    if bStyle == "DARK" then bStyle = "SUBTLE" end

    local actionDur = tonumber(g and g.toastActionDuration)
    if actionDur == nil and dl then actionDur = tonumber(dl.toastActionDuration) end
    if actionDur == nil then
        local leg = tonumber((g and g.toastDuration) or (dl and dl.toastDuration))
        if leg == 0 then
            actionDur = 0
        elseif leg ~= nil then
            actionDur = math.max(12, DynamicSuite.ClampToastActionDuration(leg))
        else
            actionDur = 12
        end
    else
        actionDur = DynamicSuite.ClampToastActionDuration(actionDur)
    end

    local infoDur = tonumber(g and g.toastInfoDuration)
    if infoDur == nil and dl then infoDur = tonumber(dl.toastInfoDuration) end
    if infoDur == nil then
        local leg = tonumber((g and g.toastDuration) or (dl and dl.toastDuration))
        if leg == 0 then
            infoDur = 0
        elseif leg ~= nil then
            infoDur = DynamicSuite.ClampToastInfoDuration(leg)
        else
            infoDur = 5
        end
    else
        infoDur = DynamicSuite.ClampToastInfoDuration(infoDur)
    end

    local duration = (kind == "INFO") and infoDur or actionDur

    local soundEnabled = (g and g.toastSoundEnabled == true) or (dl and dl.toastSoundEnabled == true) or false
    local pos = (g and type(g.toastPos) == "table" and g.toastPos)
        or (dl and type(dl.toastPos) == "table" and dl.toastPos)
        or { point = "TOP", relPoint = "TOP", x = 0, y = -140 }

    return {
        enabled        = enabled,
        scale          = scale,
        opacity        = opacity,
        borderStyle    = bStyle,
        duration       = duration,
        actionDuration = actionDur,
        infoDuration   = infoDur,
        toastKind      = kind,
        soundEnabled   = soundEnabled,
        pos            = pos,
        bgR            = bgR,
        bgG            = bgG,
        bgB            = bgB,
        ar             = ar,
        ag             = ag,
        ab             = ab,
    }
end
addonTable.GetSharedToastStyle = DynamicSuite.GetSharedToastStyle

function DynamicSuite.PlaySharedToastSound()
    local st = DynamicSuite.GetSharedToastStyle()
    if not st.soundEnabled then return end
    local now = (type(_G.GetTime) == "function") and _G.GetTime() or 0
    if (now - lastSharedToastSoundAt) < 0.5 then return end
    lastSharedToastSoundAt = now
    if type(_G.PlaySound) == "function" then
        local sk = _G.SOUNDKIT
        local kitID = (sk and sk.UI_BNET_TOAST) or 18019
        pcall(_G.PlaySound, kitID, "Master")
    end
end
addonTable.PlaySharedToastSound = DynamicSuite.PlaySharedToastSound

function DynamicSuite.RestackAllToasts()
    if isRestackingToasts then return end
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end
    isRestackingToasts = true
    local okErr, errMsg = pcall(function()
        local st = DynamicSuite.GetSharedToastStyle()
        local pos = st.pos or { point = "TOP", relPoint = "TOP", x = 0, y = -140 }
        local candidateNames = {
            "DynamicLoadToastFrame",
            "DynamicSuitePreviewToast",
            "DynamicGroupTeleportToast",
            "DynamicTalentReminderToast",
            "DynamicPrepMageFoodToast",
            "DynamicPrepDurabilityToast",
            "DynamicChatMentionToast",
        }
        local prev = nil
        for _, frameName in ipairs(candidateNames) do
            local f = _G[frameName]
            if f and type(f) == "table" and f.IsShown and f:IsShown() then
                local isDragging = (f.isEditingMode == true) or (f.isDraggingMode == true) or (f._dsDragging == true)
                if not isDragging then
                    if f._dsSharedToast == true then
                        if f.SetFrameStrata then f:SetFrameStrata(SHARED_TOAST_STRATA) end
                        if f.SetFrameLevel then f:SetFrameLevel(SHARED_TOAST_LEVEL) end
                    end
                    if frameName == "DynamicLoadToastFrame" then
                        prev = f
                    else
                        f:ClearAllPoints()
                        if prev then
                            f:SetPoint("TOP", prev, "BOTTOM", 0, -8)
                        else
                            local pt = pos.point or "TOP"
                            local rp = pos.relPoint or pt
                            f:SetPoint(pt, _G.UIParent, rp, tonumber(pos.x) or 0, tonumber(pos.y) or -140)
                        end
                        prev = f
                    end
                end
            end
        end
    end)
    isRestackingToasts = false
    if not okErr and errMsg then
        -- Silent resilience if a frame is mid-teardown
    end
end
addonTable.RestackAllToasts = DynamicSuite.RestackAllToasts

function DynamicSuite.EnsureSharedToastFrame(frameName, opts)
    if type(frameName) ~= "string" or frameName == "" then return nil end
    opts = type(opts) == "table" and opts or {}

    local existing = _G[frameName]
    if existing and existing._dsSharedToast then
        if opts.toastKind ~= nil then
            existing._dsToastKind = (type(opts.toastKind) == "string" and opts.toastKind:upper() == "INFO") and "INFO" or "ACTION"
        end
        if opts.autoFade ~= nil then
            existing._dsAutoFade = (opts.autoFade == true)
        end
        if opts.onRightClickDismiss ~= nil then
            existing._dsOnRightClickDismiss = opts.onRightClickDismiss
        end
        if opts.onHide ~= nil then
            existing._dsOnHide = opts.onHide
        end
        return existing
    end

    if _G.InCombatLockdown and _G.InCombatLockdown() then return nil end
    if not _G.UIParent then return nil end

    local f = existing or _G.CreateFrame("Button", frameName, _G.UIParent, "BackdropTemplate")
    f._dsSharedToast = true
    f._dsAutoFade = (opts.autoFade ~= false)
    f._dsToastKind = (type(opts.toastKind) == "string" and opts.toastKind:upper() == "INFO") and "INFO" or "ACTION"
    f._dsIconMode = (opts.iconMode == "FULL") and "FULL" or "TINTED"
    f._dsOnRightClickDismiss = opts.onRightClickDismiss
    f._dsOnHide = opts.onHide
    f._dsHoverButtons = {}

    local actionW = tonumber(opts.rightActionWidth) or 0
    local actionGap = tonumber(opts.rightActionGap) or 10
    local defaultW = (actionW > 0 or f._dsToastKind == "ACTION") and 460 or 410
    f._dsBaseWidth = tonumber(opts.width) or defaultW
    f._dsBaseHeight = tonumber(opts.height) or 74
    f._dsRightActionWidth = actionW
    f._dsRightActionGap = actionGap

    f:SetSize(f._dsBaseWidth, f._dsBaseHeight)
    f:SetFrameStrata(SHARED_TOAST_STRATA)
    f:SetFrameLevel(SHARED_TOAST_LEVEL)
    f:SetToplevel(false)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    local clickBtns = opts.clickButtons or { "RightButtonUp" }
    f:RegisterForClicks(unpack(clickBtns))
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1.5,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    local iconBorder = _G.CreateFrame("Frame", nil, f, "BackdropTemplate")
    iconBorder:SetSize(44, 44)
    iconBorder:SetPoint("LEFT", f, "LEFT", 14, 0)
    iconBorder:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    iconBorder:SetBackdropColor(0.04, 0.05, 0.07, 1)
    local ic = iconBorder:CreateTexture(nil, "ARTWORK")
    if f._dsIconMode == "FULL" then
        ic:SetSize(40, 40)
        ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if ic.SetSnapToPixelGrid then ic:SetSnapToPixelGrid(false) end
        if ic.SetTexelSnappingBias then ic:SetTexelSnappingBias(0) end
    else
        ic:SetSize(30, 30)
    end
    ic:SetPoint("CENTER", iconBorder, "CENTER", 0, 0)
    if type(opts.iconTexture) == "string" or type(opts.iconTexture) == "number" then
        ic:SetTexture(opts.iconTexture)
    end
    f.iconBorder = iconBorder
    f.iconTex = ic
    f.icon = ic

    local rightPad = (actionW > 0) and (12 + actionW + actionGap) or 14

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ApplySharedToastFont(title, 13)
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -11)
    title:SetPoint("RIGHT", f, "RIGHT", -rightPad, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetTextColor(0.96, 0.98, 1.00, 1)
    f.title = title

    local badge = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ApplySharedToastFont(badge, 11)
    badge:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    badge:SetPoint("RIGHT", f, "RIGHT", -rightPad, 0)
    badge:SetJustifyH("LEFT")
    badge:SetWordWrap(false)
    badge:SetTextColor(0.886, 0.910, 0.941, 1)
    f.badge = badge
    f.body = badge

    local subtext = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ApplySharedToastFont(subtext, 10)
    subtext:SetPoint("TOPLEFT", badge, "BOTTOMLEFT", 0, -5)
    subtext:SetPoint("RIGHT", f, "RIGHT", -rightPad, 0)
    subtext:SetJustifyH("LEFT")
    subtext:SetWordWrap(false)
    subtext:SetTextColor(0.58, 0.64, 0.72, 1)
    f.subtext = subtext

    local function IsAnyToastHoverActive(selfT)
        if not selfT then return false end
        if selfT.IsMouseOver and selfT:IsMouseOver() then
            return true
        end
        if selfT._dsActionBtn and selfT._dsActionBtn.IsShown and selfT._dsActionBtn:IsShown()
            and selfT._dsActionBtn.IsMouseOver and selfT._dsActionBtn:IsMouseOver() then
            return true
        end
        for _, hb in ipairs(selfT._dsHoverButtons or {}) do
            if hb and hb.IsShown and hb:IsShown() and hb.IsMouseOver and hb:IsMouseOver() then
                return true
            end
        end
        return false
    end

    function f.BindHoverPauseButton(btn)
        if not btn or btn._dsHoverPauseBound then return end
        btn._dsHoverPauseBound = true
        f._dsHoverButtons[#f._dsHoverButtons + 1] = btn
        if btn.HookScript then
            btn:HookScript("OnEnter", function()
                if f._dsAutoFade and f.animGroup then
                    f.animGroup:Pause()
                    f:SetAlpha(1)
                end
            end)
            btn:HookScript("OnLeave", function()
                if IsAnyToastHoverActive(f) then return end
                if f._dsAutoFade and f.animGroup then
                    local stLeave = DynamicSuite.GetSharedToastStyle(f._dsToastKind)
                    local leaveDur = tonumber(stLeave and stLeave.duration) or 0
                    if leaveDur > 0 and f:IsShown() then
                        f.animGroup:Play()
                    end
                end
            end)
        end
    end

    function f.SetRightTextAnchor(anchorFrame, gap)
        f._dsActionBtn = anchorFrame
        f._dsRightActionGap = tonumber(gap) or f._dsRightActionGap or 10
        if anchorFrame then
            f.BindHoverPauseButton(anchorFrame)
            if anchorFrame.GetWidth then
                local aw = tonumber(anchorFrame:GetWidth()) or 0
                if aw > 0 then f._dsRightActionWidth = aw end
            end
        end
        local gVal = -f._dsRightActionGap
        local function AnchorFS(fs, anchorTo)
            if not fs then return end
            fs:ClearAllPoints()
            if anchorTo then
                fs:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -5)
            else
                fs:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -11)
            end
            if anchorFrame then
                fs:SetPoint("RIGHT", anchorFrame, "LEFT", gVal, 0)
            else
                fs:SetPoint("RIGHT", f, "RIGHT", -14, 0)
            end
        end
        AnchorFS(f.title, nil)
        AnchorFS(f.badge, f.title)
        AnchorFS(f.subtext, f.badge)
    end

    function f.AutoFitWidth()
        if _G.InCombatLockdown and _G.InCombatLockdown() then return end
        local baseW = tonumber(f._dsBaseWidth) or ((f._dsToastKind == "ACTION") and 460 or 410)
        local baseH = tonumber(f._dsBaseHeight) or 74
        local maxTextW = 0
        for _, fs in ipairs({ f.title, f.badge, f.subtext }) do
            if fs and (not fs.IsShown or fs:IsShown()) then
                local w = 0
                if fs.GetUnboundedStringWidth then
                    local okW, uw = pcall(fs.GetUnboundedStringWidth, fs)
                    if okW and type(uw) == "number" then w = uw end
                elseif fs.GetStringWidth then
                    local okW, sw = pcall(fs.GetStringWidth, fs)
                    if okW and type(sw) == "number" then w = sw end
                end
                if w > maxTextW then maxTextW = w end
            end
        end
        local btnW = 0
        if f._dsActionBtn and (not f._dsActionBtn.IsShown or f._dsActionBtn:IsShown()) then
            btnW = (f._dsActionBtn.GetWidth and tonumber(f._dsActionBtn:GetWidth())) or tonumber(f._dsRightActionWidth) or 0
        elseif (tonumber(f._dsRightActionWidth) or 0) > 0 then
            btnW = tonumber(f._dsRightActionWidth) or 0
        end
        local gap = tonumber(f._dsRightActionGap) or 10
        local rightReserve = (btnW > 0) and (12 + btnW + gap) or 14
        local neededW = math.ceil(70 + maxTextW + rightReserve + 12)
        local targetW = math.max(baseW, math.min(540, neededW))
        if f.GetWidth and math.abs((f:GetWidth() or baseW) - targetW) > 0.5 then
            f:SetSize(targetW, baseH)
        end
    end

    local animGroup = f:CreateAnimationGroup()
    local holdAnim = animGroup:CreateAnimation("Animation")
    holdAnim:SetDuration((f._dsToastKind == "INFO") and 5 or 12)
    holdAnim:SetOrder(1)
    local fadeAnim = animGroup:CreateAnimation("Alpha")
    fadeAnim:SetFromAlpha(1)
    fadeAnim:SetToAlpha(0)
    fadeAnim:SetDuration(1.2)
    fadeAnim:SetOrder(2)
    animGroup:SetScript("OnFinished", function()
        if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
            f:Hide()
            f:SetAlpha(1)
        end
    end)
    f.animGroup = animGroup
    f.holdAnim = holdAnim

    f:SetScript("OnClick", function(selfT, button)
        if button == "RightButton" then
            if selfT.animGroup then selfT.animGroup:Stop() end
            selfT:SetAlpha(1)
            if type(selfT._dsOnRightClickDismiss) == "function" then
                pcall(selfT._dsOnRightClickDismiss, selfT)
            elseif not (_G.InCombatLockdown and _G.InCombatLockdown()) then
                selfT:Hide()
            end
        end
    end)
    f:SetScript("OnEnter", function(selfT)
        if selfT._dsAutoFade and selfT.animGroup then
            selfT.animGroup:Pause()
            selfT:SetAlpha(1)
        end
    end)
    f:SetScript("OnLeave", function(selfT)
        if IsAnyToastHoverActive(selfT) then
            return
        end
        if selfT._dsAutoFade and selfT.animGroup then
            local stLeave = DynamicSuite.GetSharedToastStyle(selfT._dsToastKind)
            local leaveDur = tonumber(stLeave and stLeave.duration) or 0
            if leaveDur > 0 and selfT:IsShown() then
                selfT.animGroup:Play()
            end
        end
    end)
    f:HookScript("OnHide", function(selfT)
        DynamicSuite.RestackAllToasts()
        if type(selfT._dsOnHide) == "function" then
            pcall(selfT._dsOnHide, selfT)
        end
    end)

    f:Hide()
    return f
end
addonTable.EnsureSharedToastFrame = DynamicSuite.EnsureSharedToastFrame

function DynamicSuite.ApplySharedToastLayout(frame, styleOpts)
    if not frame then return false, nil end
    if _G.InCombatLockdown and _G.InCombatLockdown() then return false, nil end

    styleOpts = type(styleOpts) == "table" and styleOpts or {}
    local toastKind = styleOpts.toastKind or frame._dsToastKind or "ACTION"
    toastKind = (type(toastKind) == "string" and toastKind:upper() == "INFO") and "INFO" or "ACTION"
    frame._dsToastKind = toastKind
    local st = DynamicSuite.GetSharedToastStyle(toastKind)
    local ar, ag, ab = st.ar, st.ag, st.ab
    local bStyle = tostring(st.borderStyle or "ACCENT"):upper()

    if frame.SetFrameStrata then frame:SetFrameStrata(SHARED_TOAST_STRATA) end
    if frame.SetFrameLevel then frame:SetFrameLevel(SHARED_TOAST_LEVEL) end
    if frame.SetScale then frame:SetScale(st.scale or 1.0) end
    if frame.SetBackdropColor then
        frame:SetBackdropColor(st.bgR or 0.035, st.bgG or 0.039, st.bgB or 0.051, st.opacity or 0.96)
    end

    if frame.SetBackdropBorderColor then
        if bStyle == "NONE" or bStyle == "BORDERLESS" then
            frame:SetBackdropBorderColor(0, 0, 0, 0)
        elseif type(styleOpts.borderOverrideRGB) == "table" then
            local br, bg2, bb, ba = unpack(styleOpts.borderOverrideRGB)
            frame:SetBackdropBorderColor(br or ar, bg2 or ag, bb or ab, ba or 0.95)
        elseif bStyle == "DARK" or bStyle == "SUBTLE" then
            frame:SetBackdropBorderColor(0.20, 0.24, 0.32, 0.95)
        else
            frame:SetBackdropBorderColor(ar, ag, ab, 0.92)
        end
    end

    if frame.iconBorder and frame.iconBorder.SetBackdropBorderColor then
        if type(styleOpts.iconBorderOverrideRGB) == "table" then
            local ir, ig, ib, ia = unpack(styleOpts.iconBorderOverrideRGB)
            frame.iconBorder:SetBackdropBorderColor(ir or ar, ig or ag, ib or ab, ia or 0.95)
        else
            frame.iconBorder:SetBackdropBorderColor(ar, ag, ab, 0.85)
        end
    end

    local shouldTint
    if styleOpts.tintIcon ~= nil then
        shouldTint = (styleOpts.tintIcon == true)
    else
        shouldTint = (frame._dsIconMode ~= "FULL")
    end
    if frame.iconTex and frame.iconTex.SetVertexColor then
        if shouldTint then
            frame.iconTex:SetVertexColor(ar, ag, ab, 1.0)
        else
            frame.iconTex:SetVertexColor(1.0, 1.0, 1.0, 1.0)
        end
    end

    ApplySharedToastFont(frame.title, 13)
    ApplySharedToastFont(frame.badge, 11)
    ApplySharedToastFont(frame.subtext, 10)

    if frame.AutoFitWidth then
        frame.AutoFitWidth()
    end

    if styleOpts.restack ~= false and frame.IsShown and frame:IsShown() then
        DynamicSuite.RestackAllToasts()
    end
    return true, st
end
addonTable.ApplySharedToastLayout = DynamicSuite.ApplySharedToastLayout

function DynamicSuite.ShowSharedToast(frame, showOpts)
    if not frame then return false end
    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end

    showOpts = type(showOpts) == "table" and showOpts or {}
    if showOpts.title ~= nil and frame.title then
        frame.title:SetText(showOpts.title)
    end
    local badgeText = (showOpts.badge ~= nil) and showOpts.badge or showOpts.body
    if badgeText ~= nil and frame.badge then
        frame.badge:SetText(badgeText)
    end
    if showOpts.subtext ~= nil and frame.subtext then
        frame.subtext:SetText(showOpts.subtext)
    end
    if showOpts.icon ~= nil and frame.iconTex then
        frame.iconTex:SetTexture(showOpts.icon)
    end

    local _, st = DynamicSuite.ApplySharedToastLayout(frame, {
        toastKind = showOpts.toastKind or frame._dsToastKind,
        borderOverrideRGB = showOpts.borderOverrideRGB,
        iconBorderOverrideRGB = showOpts.iconBorderOverrideRGB,
        tintIcon = showOpts.tintIcon,
        restack = false,
    })

    if frame.animGroup then frame.animGroup:Stop() end
    frame:SetAlpha(1)
    frame:Show()
    DynamicSuite.RestackAllToasts()

    if showOpts.playSound == true then
        DynamicSuite.PlaySharedToastSound()
    end

    local useFade
    if showOpts.autoFade ~= nil then
        useFade = (showOpts.autoFade == true)
    else
        useFade = (frame._dsAutoFade == true)
    end
    if useFade and frame.animGroup then
        local dur = tonumber(showOpts.duration)
        if dur == nil then
            dur = st and tonumber(st.duration)
        end
        if dur == nil then
            dur = (frame._dsToastKind == "INFO") and 5 or 12
        end
        if dur > 0 and frame.holdAnim then
            frame.holdAnim:SetDuration(dur)
            frame.animGroup:Play()
        end
    end
    return true
end
addonTable.ShowSharedToast = DynamicSuite.ShowSharedToast

function DynamicSuite.HideSharedToast(frame)
    if not frame then return true end
    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
    if frame.animGroup then frame.animGroup:Stop() end
    frame:SetAlpha(1)
    frame:Hide()
    return true
end
addonTable.HideSharedToast = DynamicSuite.HideSharedToast
end

local desktopWindowsSyncCache = setmetatable({}, { __mode = "k" })

local function SyncDesktopWindowsDBFlags(db)
    if type(db) ~= "table" then return end
    local cache = desktopWindowsSyncCache[db]
    if not cache then
        cache = {}
        desktopWindowsSyncCache[db] = cache
    end

    if cache.sideBySide ~= nil and cache.enabled ~= nil then
        if db.sideBySide ~= cache.sideBySide and db.enabled == cache.enabled then
            db.enabled = (db.sideBySide ~= false)
        elseif db.enabled ~= cache.enabled and db.sideBySide == cache.sideBySide then
            db.sideBySide = (db.enabled ~= false)
        end
    end
    if db.sideBySide == nil and db.enabled ~= nil then
        db.sideBySide = (db.enabled ~= false)
    elseif db.enabled == nil and db.sideBySide ~= nil then
        db.enabled = (db.sideBySide ~= false)
    else
        db.sideBySide = (db.sideBySide ~= false)
        db.enabled = db.sideBySide
    end

    if cache.dragAnywhere ~= nil and cache.draggable ~= nil then
        if db.dragAnywhere ~= cache.dragAnywhere and db.draggable == cache.draggable then
            db.draggable = (db.dragAnywhere ~= false)
        elseif db.draggable ~= cache.draggable and db.dragAnywhere == cache.dragAnywhere then
            db.dragAnywhere = (db.draggable ~= false)
        end
    end
    if db.dragAnywhere == nil and db.draggable ~= nil then
        db.dragAnywhere = (db.draggable ~= false)
    elseif db.draggable == nil and db.dragAnywhere ~= nil then
        db.draggable = (db.dragAnywhere ~= false)
    else
        db.dragAnywhere = (db.dragAnywhere ~= false)
        db.draggable = db.dragAnywhere
    end

    if db.scrollScale == nil then
        db.scrollScale = true
    else
        db.scrollScale = (db.scrollScale ~= false)
    end
    if type(db.positions) ~= "table" then db.positions = {} end
    if type(db.scales) ~= "table" then db.scales = {} end

    cache.sideBySide   = db.sideBySide
    cache.enabled      = db.enabled
    cache.dragAnywhere = db.dragAnywhere
    cache.draggable    = db.draggable
end

local function MigrateDesktopWindowsFromPrep(db, markCompletedIfNoPrepDB)
    if type(db) ~= "table" then return db end
    if db.migratedFromPrep == true then
        SyncDesktopWindowsDBFlags(db)
        return db
    end
    local prepDB = _G.DynamicPrepDB
    if type(prepDB) == "table" then
        if prepDB.blizzWinNoAutoClose ~= nil then
            local v = (prepDB.blizzWinNoAutoClose ~= false)
            db.sideBySide = v
            db.enabled = v
        end
        if prepDB.blizzWinDraggable ~= nil then
            local v = (prepDB.blizzWinDraggable ~= false)
            db.dragAnywhere = v
            db.draggable = v
        end
        if prepDB.blizzWinScrollScale ~= nil then
            db.scrollScale = (prepDB.blizzWinScrollScale ~= false)
        end
        if type(prepDB.windowPositions) == "table" then
            db.positions = type(db.positions) == "table" and db.positions or {}
            for frameName, pos in pairs(prepDB.windowPositions) do
                if db.positions[frameName] == nil and type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number" then
                    db.positions[frameName] = {
                        point    = pos.point or "CENTER",
                        relPoint = pos.relPoint or "CENTER",
                        x        = pos.x,
                        y        = pos.y,
                    }
                end
            end
        end
        if type(prepDB.windowScales) == "table" then
            db.scales = type(db.scales) == "table" and db.scales or {}
            for frameName, s in pairs(prepDB.windowScales) do
                if db.scales[frameName] == nil and type(s) == "number" and s > 0 then
                    db.scales[frameName] = s
                end
            end
        end
        db.migratedFromPrep = true
    elseif markCompletedIfNoPrepDB == true then
        db.migratedFromPrep = true
    end
    SyncDesktopWindowsDBFlags(db)
    return db
end

local function GetDesktopWindowsDB()
    EnsureSuiteGlobal()
    local rootGlobal = _G.DynamicSuiteDB and _G.DynamicSuiteDB.global
    if not rootGlobal then
        rootGlobal = EnsureSuiteGlobal()
    end
    if type(rootGlobal.desktopWindows) ~= "table" then
        rootGlobal.desktopWindows = CopyTable(addonTable.DEFAULT_DESKTOP_WINDOWS)
    end
    local db = rootGlobal.desktopWindows
    MigrateDesktopWindowsFromPrep(db, false)
    local activeScope = EnsureSuiteGlobal()
    if activeScope and activeScope ~= rootGlobal then
        activeScope.desktopWindows = db
    end
    if type(_G.DynamicLoadDB) == "table" and type(_G.DynamicLoadDB.charData) == "table" then
        for _, cData in pairs(_G.DynamicLoadDB.charData) do
            if type(cData) == "table" and type(cData.theme) == "table" then
                cData.theme.desktopWindows = db
            end
        end
    end
    return db
end
addonTable.GetDesktopWindowsDB = GetDesktopWindowsDB
DynamicSuite.GetDesktopWindowsDB = GetDesktopWindowsDB
addonTable.MigrateDesktopWindowsFromPrep = MigrateDesktopWindowsFromPrep

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
    local low = s:lower():gsub("^dynamic", "")
    if low == "load" then return "DynamicLoad", "load"
    elseif low == "marker" then return "DynamicMarker", "marker"
    elseif low == "cursor" then return "DynamicCursor", "cursor"
    elseif low == "zoom" then return "DynamicZoom", "zoom"
    elseif low == "fps" then return "DynamicFPS", "fps"
    elseif low == "prep" then return "DynamicPrep", "prep"
    elseif low == "talent" then return "DynamicTalent", "talent"
    elseif low == "group" then return "DynamicGroup", "group"
    elseif low == "bags" then return "DynamicBags", "bags"
    elseif low == "chat" then return "DynamicChat", "chat"
    elseif low == "mail" then return "DynamicMail", "mail"
    elseif low == "vault" then return "DynamicVault", "vault"
    elseif low == "dialogue" then return "DynamicDialogue", "dialogue"
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
        if canonMod == "DynamicMail" and _G.DynamicMail and type(_G.DynamicMail.TeardownDisabledState) == "function" then
            pcall(_G.DynamicMail.TeardownDisabledState, _G.DynamicMail)
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

addonTable.RecoverEllesmereUIState = function()
    -- Intentionally no-op in v1.6.1+: Never/FROZEN user choices are strictly respected
    -- across all addon families (including EllesmereUI and its sub-addons).
end
DynamicSuite.RecoverEllesmereUIState = addonTable.RecoverEllesmereUIState

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
        local ar0, ag0, ab0 = addonTable.GetCoreAccentRGB()
        modal.TopAccent:SetColorTexture(ar0, ag0, ab0, 1.0)

        modal.Title = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        modal.Title:SetPoint("TOPLEFT", modal, "TOPLEFT", 18, -16)
        modal.Title:SetText(string.format("|cFF%sDynamicSuite|r  |cFF94A3B8-- Coexistence Guard|r", addonTable.GetCoreAccentHex()))

        modal.HeaderSep = modal:CreateTexture(nil, "ARTWORK")
        modal.HeaderSep:SetHeight(1)
        modal.HeaderSep:SetPoint("TOPLEFT", modal, "TOPLEFT", 18, -40)
        modal.HeaderSep:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -18, -40)
        modal.HeaderSep:SetColorTexture(0.200, 0.240, 0.310, 0.65)

        modal.Body = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        modal.Body:SetPoint("TOPLEFT", modal.InnerSurface or modal, "TOPLEFT", 18, -52)
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
                    local ar, ag, ab = addonTable.GetCoreAccentRGB()
                    if hover then
                        btn:SetBackdropColor(ar * 0.36, ag * 0.36, ab * 0.36, 1.0)
                        btn:SetBackdropBorderColor(ar, ag, ab, 1.0)
                        btn.Text:SetTextColor(1.0, 1.0, 1.0, 1.0)
                    else
                        btn:SetBackdropColor(ar * 0.24, ag * 0.24, ab * 0.24, 0.96)
                        btn:SetBackdropBorderColor(ar, ag, ab, 0.95)
                        btn.Text:SetTextColor(1.0, 1.0, 1.0, 0.98)
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
            btn.RefreshStyle = ApplyState
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

    local arShow, agShow, abShow = addonTable.GetCoreAccentRGB()
    if modal.TopAccent then modal.TopAccent:SetColorTexture(arShow, agShow, abShow, 1.0) end
    if modal.Title then modal.Title:SetText(string.format("|cFF%sDynamicSuite|r  |cFF94A3B8-- Coexistence Guard|r", addonTable.GetCoreAccentHex())) end
    if modal.ReloadBtn and modal.ReloadBtn.RefreshStyle then modal.ReloadBtn.RefreshStyle(false) end
    if modal.LaterBtn and modal.LaterBtn.RefreshStyle then modal.LaterBtn.RefreshStyle(false) end

    shownMarkerConflictModalThisSession = true
    DynamicSuite._shownMarkerConflictModalThisSession = true
    modal:Show()
    modal:Raise()
end
addonTable.ShowMarkerConflictReloadModal = ShowMarkerConflictReloadModal
DynamicSuite.ShowMarkerConflictReloadModal = ShowMarkerConflictReloadModal

local function GetRaidTaintModalSession()
    _G.DynamicSuite_RaidTaintModalSession = type(_G.DynamicSuite_RaidTaintModalSession) == "table"
        and _G.DynamicSuite_RaidTaintModalSession
        or {}
    local s = _G.DynamicSuite_RaidTaintModalSession
    s.dismissed = type(s.dismissed) == "table" and s.dismissed or {}
    s.quarantined = type(s.quarantined) == "table" and s.quarantined or {}
    return s
end

local function SafeReadableTaintString(val)
    if val == nil then return nil end
    if issecretvalue and issecretvalue(val) then return nil end
    if type(canaccessvalue) == "function" then
        local okA, canA = pcall(canaccessvalue, val)
        if okA and not canA then return nil end
    end
    if type(val) ~= "string" then return nil end
    return val
end

local function IsSetRaidTargetFunctionName(fnName)
    if type(fnName) ~= "string" or fnName == "" then return false end
    return fnName == "SetRaidTarget"
        or fnName == "SetRaidTarget()"
        or fnName == "SetRaidTargetIcon"
        or fnName == "SetRaidTargetIcon()"
        or fnName:find("SetRaidTarget", 1, true) ~= nil
end

local function ForceFreezeAddonAcrossDynamicLoadDB(addonFolder)
    if type(addonFolder) ~= "string" or addonFolder == "" then return end
    if type(_G.DynamicLoadDB) ~= "table" then return end
    local function ApplyNeverToScope(tbl)
        if type(tbl) ~= "table" then return end
        tbl.addonStates = type(tbl.addonStates) == "table" and tbl.addonStates or {}
        tbl.frozenAddons = type(tbl.frozenAddons) == "table" and tbl.frozenAddons or {}
        tbl.lockedAddons = type(tbl.lockedAddons) == "table" and tbl.lockedAddons or {}
        tbl.addonStates[addonFolder] = "FROZEN"
        tbl.frozenAddons[addonFolder] = true
        tbl.lockedAddons[addonFolder] = nil
        if type(tbl.profiles) == "table" then
            for _, prof in pairs(tbl.profiles) do
                if type(prof) == "table" and type(prof.addons) == "table" then
                    prof.addons[addonFolder] = nil
                end
            end
        end
        if type(tbl.zones) == "table" then
            for _, zTbl in pairs(tbl.zones) do
                if type(zTbl) == "table" then
                    zTbl[addonFolder] = nil
                end
            end
        end
        for _, zKey in ipairs({ "outdoor", "delves", "dungeons", "raid", "pvp" }) do
            if type(tbl[zKey]) == "table" then
                tbl[zKey][addonFolder] = nil
            end
        end
    end
    ApplyNeverToScope(_G.DynamicLoadDB)
    ApplyNeverToScope(_G.DynamicLoadDB.globalData)
    if type(_G.DynamicLoadDB.charData) == "table" then
        for _, cd in pairs(_G.DynamicLoadDB.charData) do
            ApplyNeverToScope(cd)
        end
    end
end

local function QuarantineRaidTaintAddon(offendingAddon)
    if type(offendingAddon) ~= "string" or offendingAddon == "" or offendingAddon == "Unknown Addon" then
        return false
    end
    local pName = UnitName and UnitName("player") or nil
    if C_AddOns and C_AddOns.DisableAddOn then
        if pName then pcall(C_AddOns.DisableAddOn, offendingAddon, pName) end
        pcall(C_AddOns.DisableAddOn, offendingAddon)
    elseif type(_G.DisableAddOn) == "function" then
        pcall(_G.DisableAddOn, offendingAddon)
    end
    if addonTable.SetAddonFrozen then
        pcall(addonTable.SetAddonFrozen, offendingAddon, true)
    end
    ForceFreezeAddonAcrossDynamicLoadDB(offendingAddon)
    if addonTable.ResolveConflict then
        pcall(addonTable.ResolveConflict, "DynamicMarker", offendingAddon, "USE_DYNAMIC")
    end
    local session = GetRaidTaintModalSession()
    session.quarantined[offendingAddon] = true
    if _G.DynamicMarker and type(_G.DynamicMarker.ScanConflicts) == "function" then
        pcall(_G.DynamicMarker.ScanConflicts, _G.DynamicMarker)
        if type(_G.DynamicMarker.RefreshAll) == "function" then
            pcall(_G.DynamicMarker.RefreshAll, _G.DynamicMarker)
        end
    end
    if addonTable.mainFrame then
        if addonTable.mainFrame.UpdateModuleConflictBanner then
            pcall(addonTable.mainFrame.UpdateModuleConflictBanner)
        end
        if addonTable.mainFrame.RefreshLeftRailVisuals then
            pcall(addonTable.mainFrame.RefreshLeftRailVisuals)
        end
    end
    return true
end
addonTable.QuarantineRaidTaintAddon = QuarantineRaidTaintAddon
DynamicSuite.QuarantineRaidTaintAddon = QuarantineRaidTaintAddon

local function IsDynamicMarkerDisabledInSuiteCore()
    local g = _G.DynamicSuiteDB and _G.DynamicSuiteDB.global
    if type(g) == "table" and type(g.disabledModules) == "table" then
        if g.disabledModules["DynamicMarker"] == true or g.disabledModules["marker"] == true then
            return true
        end
    end
    if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.disabledModules) == "table" then
        if _G.DynamicSuiteDB.disabledModules["DynamicMarker"] == true or _G.DynamicSuiteDB.disabledModules["marker"] == true then
            return true
        end
    end
    return false
end

local function IsDecorVendorActiveForQuarantine()
    if IsDynamicMarkerDisabledInSuiteCore() then return false end
    local session = GetRaidTaintModalSession()
    if session.quarantined["DecorVendor"] or session.dismissed["DecorVendor"] then
        return false
    end
    local loaded = (C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" and C_AddOns.IsAddOnLoaded("DecorVendor"))
        or (type(_G.IsAddOnLoaded) == "function" and _G.IsAddOnLoaded("DecorVendor"))
    if loaded then
        return true
    end
    if C_AddOns and type(C_AddOns.GetAddOnEnableState) == "function" then
        local pName = UnitName and UnitName("player") or nil
        local okE, st = pcall(C_AddOns.GetAddOnEnableState, "DecorVendor", pName)
        if okE and type(st) == "number" and st > 0 then
            return true
        end
        local okE2, st2 = pcall(C_AddOns.GetAddOnEnableState, pName, "DecorVendor")
        if okE2 and type(st2) == "number" and st2 > 0 then
            return true
        end
    end
    return false
end

local function ShowRaidMarkerTaintModal(selfOrAddon, maybeAddon, maybeReason)
    local offendingAddon, reason
    if selfOrAddon == DynamicSuite or selfOrAddon == addonTable then
        offendingAddon, reason = maybeAddon, maybeReason
    else
        offendingAddon, reason = selfOrAddon, maybeAddon
    end
    offendingAddon = SafeReadableTaintString(offendingAddon)
    if not offendingAddon or offendingAddon == "" then
        local dvLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("DecorVendor"))
        offendingAddon = dvLoaded and "DecorVendor" or "Unknown Addon"
    end
    if IsDynamicMarkerDisabledInSuiteCore() then return end

    local session = GetRaidTaintModalSession()
    if session.dismissed[offendingAddon] then
        return
    end
    if session.quarantined[offendingAddon] and reason == "PROACTIVE" then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        addonTable._pendingRaidTaintModal = { addon = offendingAddon, reason = reason or "FORBIDDEN" }
        return
    end
    addonTable._pendingRaidTaintModal = nil

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
        local ar0, ag0, ab0 = addonTable.GetCoreAccentRGB()
        modal.TopAccent:SetColorTexture(ar0, ag0, ab0, 1.0)

        modal.Title = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        modal.Title:SetPoint("TOPLEFT", modal, "TOPLEFT", 16, -15)
        modal.Title:SetText(string.format("|cFF%sRaid Marker Blocked by Addon Conflict|r", addonTable.GetCoreAccentHex()))

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
                    local ar, ag, ab = addonTable.GetCoreAccentRGB()
                    if hover then
                        self:SetBackdropColor(ar * 0.36, ag * 0.36, ab * 0.36, 1.0)
                        self:SetBackdropBorderColor(ar, ag, ab, 1.0)
                        self.Text:SetTextColor(1.0, 1.0, 1.0, 1.0)
                    else
                        self:SetBackdropColor(ar * 0.24, ag * 0.24, ab * 0.24, 0.98)
                        self:SetBackdropBorderColor(ar, ag, ab, 0.95)
                        self.Text:SetTextColor(1.0, 1.0, 1.0, 0.98)
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
                local s = GetRaidTaintModalSession()
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
    local arShow, agShow, abShow = addonTable.GetCoreAccentRGB()
    local accHex = addonTable.GetCoreAccentHex()

    if alreadyQuarantined then
        modal.TopAccent:SetColorTexture(0.063, 0.725, 0.506, 1.0)
        modal.Title:SetText("|cFF34D399Raid Marker Blocked by Addon Conflict|r")
        modal.Body:SetText(string.format(
            "|cFFFFFFFF%s|r is already set to Never for your next session, however Blizzard's raid-marker security lockout remains active until World of Warcraft restarts.\n\nPlease completely |cFF%sExit & Restart|r the game client now (a |cFFFFFFFF/reload|r alone will not clear the lockout).",
            offendingAddon, accHex
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
        modal.TopAccent:SetColorTexture(arShow, agShow, abShow, 1.0)
        modal.Title:SetText(string.format("|cFF%sRaid Marker Blocked by Addon Conflict|r", accHex))
        local friendly = FRIENDLY_CONFLICT_NAMES[offendingAddon] or offendingAddon
        local displayLabel = (friendly ~= offendingAddon) and string.format("%s (%s)", friendly, offendingAddon) or offendingAddon
        modal.Body:SetText(string.format(
            "|cFFFFFFFF%s|r taints Blizzard's |cFFFFFFFF/tm|r raid marker command (|cFFFFFFFFSetRaidTarget()|r), causing action-bar focus markers to be blocked.\n\nBecause of how World of Warcraft's security engine works, you must disable |cFFFFFFFF%s|r and |cFF%sfully Exit & Restart the game client|r (a |cFFFFFFFF/reload|r alone will not clear the lockout).",
            displayLabel, offendingAddon, accHex
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
                QuarantineRaidTaintAddon(offendingAddon)
                modal.TopAccent:SetColorTexture(0.063, 0.725, 0.506, 1.0)
                modal.Title:SetText("|cFF34D399" .. offendingAddon .. " Disabled (Set to Never)|r")
                modal.Body:SetText(string.format(
                    "|cFFFFFFFF%s|r has been disabled and set to |cFF34D399Never|r across DynamicLoad so zone changes will never re-enable it.\n\nPlease |cFF%scompletely Exit & Restart World of Warcraft|r now to clear Blizzard's raid-marker lockout (a |cFFFFFFFF/reload|r alone will not clear it).",
                    offendingAddon, addonTable.GetCoreAccentHex()
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
                    "|cFF38BDF8DynamicSuite|r: Disabled |cFFFFFFFF%s|r and set it to |cFF34D399Never|r in DynamicLoad. Please completely Exit & Restart World of Warcraft now (/reload alone will not clear SetRaidTarget taint).",
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
addonTable.ShowRaidMarkerTaintModal = ShowRaidMarkerTaintModal
DynamicSuite.ShowRaidMarkerTaintModal = ShowRaidMarkerTaintModal

--------------------------------------------------------------------------------
-- Feature Spotlights & Quiet NEW Left-Rail Badge Registry
--------------------------------------------------------------------------------
do
local FEATURE_SPOTLIGHTS = {
    {
        id                       = "cursor_v282",
        moduleKey                = "cursor",
        addonName                = "DynamicCursor",
        icon                     = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_cursor.tga",
        kicker                   = "NEW IN DYNAMICSUITE",
        title                    = "DynamicCursor",
        subtitle                 = "A lightweight cursor ring, GCD and cast arc, crosshair, and pointer locator built right into DynamicSuite (/dcur).",
        bullets                  = {
            "Customisable cursor ring with inner GCD ring and outer cast, channel, and empower arc.",
            "Optional character crosshair and Find My Cursor locator when you lose track of your pointer.",
            "Pooled cursor trail, zone visibility rules, and smart cursor tooltips.",
        },
        primaryLabelWhenDisabled = "Turn It On & Open",
        primaryLabelWhenEnabled  = "Open DynamicCursor",
        secondaryLabel           = "Maybe Later",
        footerNote               = "Takes effect right away. You can adjust it anytime under DynamicCursor in /ds.",
    },
}
addonTable.FEATURE_SPOTLIGHTS = FEATURE_SPOTLIGHTS
DynamicSuite.FEATURE_SPOTLIGHTS = FEATURE_SPOTLIGHTS

local NEW_MODULE_BADGES = {
    cursor = "cursor_v282",
}
addonTable.NEW_MODULE_BADGES = NEW_MODULE_BADGES
DynamicSuite.NEW_MODULE_BADGES = NEW_MODULE_BADGES

local function GetAccountSuiteGlobal()
    EnsureSuiteGlobal()
    local g = _G.DynamicSuiteDB and _G.DynamicSuiteDB.global
    if type(g) ~= "table" then
        g = {}
        if _G.DynamicSuiteDB then
            _G.DynamicSuiteDB.global = g
        end
    end
    if g.showFeatureSpotlights == nil then g.showFeatureSpotlights = true end
    if type(g.seenSpotlights) ~= "table" then g.seenSpotlights = {} end
    if type(g.seenNewBadges) ~= "table" then g.seenNewBadges = {} end
    return g
end

local function NormalizeSpotlightModuleKey(moduleKeyOrAddon)
    local canonMod, shortKey = NormalizeSuiteModuleId(moduleKeyOrAddon)
    if shortKey and shortKey ~= "" then
        return shortKey, canonMod
    end
    local s = tostring(moduleKeyOrAddon or ""):lower():gsub("^dynamic", "")
    return s, canonMod or tostring(moduleKeyOrAddon or "")
end

function addonTable.IsFeatureSpotlightsEnabled()
    local g = GetAccountSuiteGlobal()
    return g.showFeatureSpotlights ~= false
end
DynamicSuite.IsFeatureSpotlightsEnabled = addonTable.IsFeatureSpotlightsEnabled

function addonTable.GetLatestFeatureSpotlight()
    return FEATURE_SPOTLIGHTS[#FEATURE_SPOTLIGHTS]
end
DynamicSuite.GetLatestFeatureSpotlight = addonTable.GetLatestFeatureSpotlight

function addonTable.GetFirstUnseenFeatureSpotlight()
    local g = GetAccountSuiteGlobal()
    local seen = g.seenSpotlights
    for i = #FEATURE_SPOTLIGHTS, 1, -1 do
        local entry = FEATURE_SPOTLIGHTS[i]
        if entry and entry.id and seen[entry.id] ~= true then
            return entry
        end
    end
    return nil
end
DynamicSuite.GetFirstUnseenFeatureSpotlight = addonTable.GetFirstUnseenFeatureSpotlight

function addonTable.MarkFeatureSpotlightSeen(spotlightId)
    if not spotlightId or spotlightId == "" then return end
    local g = GetAccountSuiteGlobal()
    g.seenSpotlights[spotlightId] = true
end
DynamicSuite.MarkFeatureSpotlightSeen = addonTable.MarkFeatureSpotlightSeen

function addonTable.HasUnseenModuleNewBadge(moduleKeyOrAddon)
    local shortKey = NormalizeSpotlightModuleKey(moduleKeyOrAddon)
    local badgeId = NEW_MODULE_BADGES[shortKey]
    if not badgeId then return false end
    local g = GetAccountSuiteGlobal()
    return g.seenNewBadges[badgeId] ~= true
end
DynamicSuite.HasUnseenModuleNewBadge = addonTable.HasUnseenModuleNewBadge

function addonTable.MarkModuleNewBadgeSeen(moduleKeyOrAddon)
    local shortKey = NormalizeSpotlightModuleKey(moduleKeyOrAddon)
    local badgeId = NEW_MODULE_BADGES[shortKey]
    if not badgeId then return end
    local g = GetAccountSuiteGlobal()
    if g.seenNewBadges[badgeId] == true then return end
    g.seenNewBadges[badgeId] = true
    if addonTable.mainFrame and addonTable.mainFrame.RefreshLeftRailVisuals then
        pcall(addonTable.mainFrame.RefreshLeftRailVisuals)
    end
end
DynamicSuite.MarkModuleNewBadgeSeen = addonTable.MarkModuleNewBadgeSeen

function addonTable.IsSuiteModuleCurrentlyDisabled(moduleKeyOrAddon)
    local shortKey, canonMod = NormalizeSpotlightModuleKey(moduleKeyOrAddon)
    if IsSuiteModuleExplicitlyDisabled(canonMod) or IsSuiteModuleExplicitlyDisabled(shortKey) then
        return true
    end
    local g = EnsureSuiteGlobal()
    if type(g.disabledModules) == "table" and (g.disabledModules[canonMod] == true or g.disabledModules[shortKey] == true) then
        return true
    end
    return false
end
DynamicSuite.IsSuiteModuleCurrentlyDisabled = addonTable.IsSuiteModuleCurrentlyDisabled

function addonTable.EnableSuiteModuleImmediate(moduleKeyOrAddon)
    local shortKey, canonMod = NormalizeSpotlightModuleKey(moduleKeyOrAddon)
    local target = canonMod ~= "" and canonMod or moduleKeyOrAddon
    SetSuiteModuleEnabled(target, true, false)
    local regMod = (DynamicSuite and DynamicSuite.modules and (DynamicSuite.modules[target] or DynamicSuite.modules[shortKey])) or _G[target]
    if regMod and regMod._disabledAtStartup and DynamicSuite and type(DynamicSuite.Print) == "function" then
        DynamicSuite.Print(string.format("%s enabled. Type /reload to finish activating it.", target))
    end
end
DynamicSuite.EnableSuiteModuleImmediate = addonTable.EnableSuiteModuleImmediate

function addonTable.ResetFeatureSpotlightsAndBadges()
    local g = GetAccountSuiteGlobal()
    wipe(g.seenSpotlights)
    wipe(g.seenNewBadges)
    local activeScope = EnsureSuiteGlobal()
    if type(activeScope) == "table" then
        if type(activeScope.seenSpotlights) == "table" then wipe(activeScope.seenSpotlights) end
        if type(activeScope.seenNewBadges) == "table" then wipe(activeScope.seenNewBadges) end
    end
    if addonTable._spotlightTimer and addonTable._spotlightTimer.Cancel then
        addonTable._spotlightTimer:Cancel()
    end
    addonTable._spotlightTimer = nil
    addonTable._spotlightShownThisSession = false
    addonTable._deferredFeatureSpotlight = false
    if addonTable.mainFrame and addonTable.mainFrame.RefreshLeftRailVisuals then
        pcall(addonTable.mainFrame.RefreshLeftRailVisuals)
    end
    print(string.format("|cFF%sDynamicSuite:|r Cleared seen feature spotlights and NEW rail badges. Use /ds spotlight to preview now or /reload to test login auto-trigger.", addonTable.GetCoreAccentHex()))
end
DynamicSuite.ResetFeatureSpotlightsAndBadges = addonTable.ResetFeatureSpotlightsAndBadges

function addonTable.IsSafeToShowFeatureSpotlight()
    if not addonTable.IsFeatureSpotlightsEnabled() then
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        return false
    end
    if _G.C_ChallengeMode and type(_G.C_ChallengeMode.IsChallengeModeActive) == "function" then
        local okCm, activeCm = pcall(_G.C_ChallengeMode.IsChallengeModeActive)
        if okCm and activeCm == true then
            return false
        end
    end
    if type(_G.IsEncounterInProgress) == "function" then
        local okEnc, inEnc = pcall(_G.IsEncounterInProgress)
        if okEnc and inEnc == true then
            return false
        end
    end
    if type(_G.IsInInstance) == "function" then
        local okInst, inInst, instType = pcall(_G.IsInInstance)
        if okInst and inInst and instType and instType ~= "none" then
            return false
        end
    end
    if _G.C_Scenario and type(_G.C_Scenario.IsInScenario) == "function" then
        local okScen, inScen = pcall(_G.C_Scenario.IsInScenario)
        if okScen and inScen == true then
            return false
        end
    end
    if _G.C_Lorewalking and type(_G.C_Lorewalking.IsInLorewalking) == "function" then
        local okLore, inLore = pcall(_G.C_Lorewalking.IsInLorewalking)
        if okLore and inLore == true then
            return false
        end
    end
    if (type(_G.InCinematic) == "function" and _G.InCinematic())
        or (type(_G.IsInCinematicScene) == "function" and _G.IsInCinematicScene())
        or (_G.CinematicFrame and _G.CinematicFrame.IsShown and _G.CinematicFrame:IsShown())
        or (_G.MovieFrame and _G.MovieFrame.IsShown and _G.MovieFrame:IsShown()) then
        return false
    end
    if addonTable.mainFrame and addonTable.mainFrame:IsShown() and addonTable.mainFrame.setupView and addonTable.mainFrame.setupView:IsShown() then
        return false
    end
    local g = GetAccountSuiteGlobal()
    if addonTable._isFreshBrandNewInstall and g.guidedSetupDone ~= true then
        return false
    end
    if standaloneMarkerWasEnabledAtBoot or addonTable.standaloneMarkerWasEnabledAtBoot or (DynamicSuite and DynamicSuite.standaloneMarkerWasEnabledAtBoot) or (_G.DynamicSuite_StandaloneMarkerWasEnabledAtBoot == true) then
        return false
    end
    if addonTable._pendingMarkerConflictModal or (_G.DynamicSuiteMarkerConflictModal and _G.DynamicSuiteMarkerConflictModal.IsShown and _G.DynamicSuiteMarkerConflictModal:IsShown()) then
        return false
    end
    if addonTable._pendingRaidTaintModal or (_G.DynamicSuiteRaidTaintModal and _G.DynamicSuiteRaidTaintModal.IsShown and _G.DynamicSuiteRaidTaintModal:IsShown()) then
        return false
    end
    return true
end
DynamicSuite.IsSafeToShowFeatureSpotlight = addonTable.IsSafeToShowFeatureSpotlight

function addonTable.ScheduleFeatureSpotlightCheck(delaySec)
    if addonTable._spotlightTimer and addonTable._spotlightTimer.Cancel then
        addonTable._spotlightTimer:Cancel()
    end
    addonTable._spotlightTimer = nil
    if addonTable._spotlightShownThisSession then
        return
    end
    if not addonTable.IsFeatureSpotlightsEnabled() then
        return
    end
    if not addonTable.GetFirstUnseenFeatureSpotlight() then
        return
    end
    local waitSec = tonumber(delaySec) or 2.5
    addonTable._spotlightTimer = C_Timer.NewTimer(waitSec, function()
        addonTable._spotlightTimer = nil
        if addonTable._spotlightShownThisSession then
            return
        end
        local entry = addonTable.GetFirstUnseenFeatureSpotlight()
        if not entry then
            addonTable._deferredFeatureSpotlight = false
            return
        end
        if not addonTable.IsSafeToShowFeatureSpotlight() then
            addonTable._deferredFeatureSpotlight = true
            return
        end
        if addonTable.ShowFeatureSpotlight then
            addonTable._deferredFeatureSpotlight = false
            addonTable._spotlightShownThisSession = true
            pcall(addonTable.ShowFeatureSpotlight, entry, false)
        end
    end)
end
end

--------------------------------------------------------------------------------
-- Shared Data-Driven Quick Guide Registry (? Modal Across All 13 Modules)
--------------------------------------------------------------------------------
do
local ICON_DIR = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\"
local MODULE_QUICK_GUIDES = {
    load = {
        key       = "load",
        addonName = "DynamicLoad",
        title     = "DynamicLoad",
        icon      = ICON_DIR .. "icon_mod_load.tga",
        slash     = "/dl, /dynamicload",
        summary   = "Automatically switches addon profiles between Outdoor, Delves, Dungeons, Raid, and PvP.",
        tips      = {
            "Pin essential addons to Always and economy/collection addons to By Zone or Never.",
            "Right-click the zone tabs or use /dl status to check which addons are staged for next reload.",
            "New addons default safely to By Zone (Outdoor) so dungeons and raids stay lean.",
        },
    },
    prep = {
        key       = "prep",
        addonName = "DynamicPrep",
        title     = "DynamicPrep",
        icon      = ICON_DIR .. "icon_mod_prep.tga",
        slash     = "/dprep, /dp",
        summary   = "Displays a live Top Info Bar for stats, Omni Folio, consumables, and clickable Raid Buffs.",
        tips      = {
            "Left-click the Folio capsule to pick your zone target stat, or Right-click to open the Omnium Folio.",
            "Shift + Left-Drag the Top Info Bar to move it directly, or Right-Click empty bar space / use /ds hud for grid & scale.",
            "Create the [DynamicHeal] and [DynamicDrink] macros in Tab 3 for smart recovery buttons.",
        },
    },
    talent = {
        key       = "talent",
        addonName = "DynamicTalent",
        title     = "DynamicTalent",
        icon      = ICON_DIR .. "icon_mod_talent.tga",
        slash     = "/dt, /dynamictalent",
        summary   = "Stores unlimited per-spec talent builds and reminds you to swap for Raid, M+, Delves, or PvP.",
        tips      = {
            "Bind saved loadouts to specific raids, M+ dungeons, PvP, or zones in Tab 2.",
            "Use the Left-Hand Talent Dock next to Blizzard's Talents & Spellbook window to swap fast.",
            "Right-click your Hero Talent medallion (out of combat) to flip directly to the other Hero tree.",
        },
    },
    marker = {
        key       = "marker",
        addonName = "DynamicMarker",
        title     = "DynamicMarker",
        icon      = ICON_DIR .. "icon_mod_marker.tga",
        slash     = "/dm, /fm",
        summary   = "Provides floating Focus Icon and World Flare bars alongside [DynamicMark] and [DynamicKick] macros.",
        tips      = {
            "Generate [DynamicMark] and [DynamicKick] in Tab 3 so your interrupt swaps automatically by spec.",
            "Right-click a marker button or use /ds hud to drag and resize your Focus and Flare bars.",
            "Bind optional World Flare keys in Tab 2 (World Flares) to place or clear ground markers at cursor.",
        },
    },
    cursor = {
        key       = "cursor",
        addonName = "DynamicCursor",
        title     = "DynamicCursor",
        icon      = ICON_DIR .. "icon_mod_cursor.tga",
        slash     = "/dcur, /dynamiccursor",
        summary   = "Adds a customisable Cursor Ring with inner GCD/cast arcs, Crosshair, Find My Cursor locator, and Trail.",
        tips      = {
            "Pick one of the 4 Quick Presets (Clean Raid, High-Visibility, Minimalist, Full Telemetry) first.",
            "Turn on Shake-to-Find or Hold Modifier Key in Tab 3 so you never lose your pointer in raid clutter.",
            "Set Active Zones in Tab 4 if you only want cursor rings or trails inside combat instances.",
        },
    },
    zoom = {
        key       = "zoom",
        addonName = "DynamicZoom",
        title     = "DynamicZoom",
        icon      = ICON_DIR .. "icon_mod_zoom.tga",
        slash     = "/dz, /dynamiczoom",
        summary   = "Unlocks full 39-yard camera distance with smooth scroll acceleration and foliage occlusion fade.",
        tips      = {
            "Type /dz max anytime (or enable Auto Max Zoom) to snap straight out to 39 yards.",
            "Enable See-Through Obstructions to fade trees and dungeon pillars instead of snapping forward.",
            "Set optional Indoors, Combat, or Mounted target distances for automatic camera framing.",
        },
    },
    fps = {
        key       = "fps",
        addonName = "DynamicFPS",
        title     = "DynamicFPS",
        icon      = ICON_DIR .. "icon_mod_fps.tga",
        slash     = "/dfps, /dynamicfps",
        summary   = "Adjusts graphics settings per zone without reloading, protects combat FPS, and tunes Spell Queue Timing.",
        tips      = {
            "Start with a Recommended Zone Preset while keeping boss floor mechanics at maximum clarity.",
            "Enable Automatic Spell Queue Tuning so your queue timing automatically follows live ping and haste.",
            "Click Apply Now or use /dfps status to compare live Outdoor, Dungeon, and Raid graphics settings.",
        },
    },
    group = {
        key       = "group",
        addonName = "DynamicGroup",
        title     = "DynamicGroup",
        icon      = ICON_DIR .. "icon_mod_group.tga",
        slash     = "/dgroup, /dg",
        summary   = "Upgrades Premade Groups with region tags, M+ ratings, Season 2 portal deck, and party readiness.",
        tips      = {
            "Right-click any dungeon tile in the Portal Deck above Premade Groups (out of combat) to teleport.",
            "Left-click a tile or your Owned Keystone pill to filter Group Finder to that exact dungeon.",
            "Turn on whisper auto-invite keywords and !keys chat replies in Tabs 2 and 3.",
        },
    },
    bags = {
        key       = "bags",
        addonName = "DynamicBags",
        title     = "DynamicBags",
        icon      = ICON_DIR .. "icon_mod_bags.tga",
        slash     = "/dbag, /dbags",
        summary   = "Replaces Blizzard bags and bank with fast category-sorted bags, Alt Vault search, and vendor automation.",
        tips      = {
            "Hold Ctrl + Mousewheel over the Bag or Unified Bank header to scale cleanly from 70% to 140%.",
            "Use the Alt Vault tab to check items, currencies, and gold across every character on your account.",
            "Turn on Auto Repair, Sell Grey Junk, and Alt + Right-Click bulk stack buying in Tab 2.",
        },
    },
    mail = {
        key       = "mail",
        addonName = "DynamicMail",
        title     = "DynamicMail",
        icon      = ICON_DIR .. "icon_mod_mail.tga",
        slash     = "/dmail, /dynamicmail",
        summary   = "Docks 1-click Open All, AH Gold, Alt recipient picker, and bulk item attach controls onto your Mailbox.",
        tips      = {
            "Click Open All, AH Gold, or Items Only above Blizzard's Mailbox header to clear mail fast.",
            "Use + Mats, + BoE, or + Warband pills in Send Mail (or Alt + Left-Click items) to attach quickly.",
            "Keep at least 1-2 Free Bag Slots reserved so gold collection keeps going when bags fill up.",
        },
    },
    chat = {
        key       = "chat",
        addonName = "DynamicChat",
        title     = "DynamicChat",
        icon      = ICON_DIR .. "icon_mod_chat.tga",
        slash     = "/dchat, /dc",
        summary   = "Styles your chat window with a compact shortcut rail, clickable links, /ww whispers, and mention alerts.",
        tips      = {
            "Type /ww to whisper your friendly target quickly, /rl to reload UI, or /lg to leave group.",
            "Drag or resize your Chat Frame smoothly using /ds hud to align it alongside your HUD bars.",
            "Add your character names or keywords to Mention Alert Toasts with your choice of chime.",
        },
    },
    vault = {
        key       = "vault",
        addonName = "DynamicVault",
        title     = "DynamicVault",
        icon      = ICON_DIR .. "icon_mod_vault.tga",
        slash     = "/dv, /dynamicvault",
        summary   = "Tracks Great Vault slots, Raid lockouts, Crests, Bountiful Delves, and weekly checklists across alts.",
        tips      = {
            "Click Open Great Vault (/dv open) or Left-click the Prep Bar Vault capsule to check rewards anytime.",
            "Use the Bountiful Delves and Weekly Checklist tabs to track reset tasks per character or account.",
            "Switch alt chips at the top of Blizzard's Great Vault window to compare reward tiers at a glance.",
        },
    },
    dialogue = {
        key       = "dialogue",
        addonName = "DynamicDialogue",
        title     = "DynamicDialogue",
        icon      = ICON_DIR .. "icon_mod_dialogue.tga",
        slash     = "/dd, /ddlg",
        summary   = "Presents Quest and NPC Gossip frames in a readable Obsidian layout with 1-9 and Spacebar controls.",
        tips      = {
            "Press keys 1-9 to choose gossip options and Spacebar to accept, continue, or turn in quests.",
            "Hold Shift when talking to an NPC if you temporarily want Blizzard's default quest window.",
            "Use /dd preview anytime to tune text size, reader scale, and backdrop opacity live.",
        },
    },
}
addonTable.MODULE_QUICK_GUIDES = MODULE_QUICK_GUIDES
DynamicSuite.MODULE_QUICK_GUIDES = MODULE_QUICK_GUIDES

function addonTable.GetModuleQuickGuide(moduleKeyOrAddon)
    if not moduleKeyOrAddon or moduleKeyOrAddon == "" then
        return nil
    end
    local _, shortKey = NormalizeSuiteModuleId(moduleKeyOrAddon)
    local lookup = (shortKey and shortKey ~= "" and shortKey) or tostring(moduleKeyOrAddon):lower():gsub("^dynamic", "")
    return MODULE_QUICK_GUIDES[lookup]
end
DynamicSuite.GetModuleQuickGuide = addonTable.GetModuleQuickGuide
end

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

    local function isSafeStr(v)
        if type(_G.issecretvalue) == "function" then
            local okS, s = pcall(_G.issecretvalue, v)
            if okS and s then return false end
        end
        if type(_G.canaccessvalue) == "function" then
            local okA, a = pcall(_G.canaccessvalue, v)
            if okA and not a then return false end
        end
        return type(v) == "string" and v ~= ""
    end

    local pName = GetPlayer()
    local okUN, rawUName = (type(_G.UnitName) == "function") and pcall(_G.UnitName, "player") or false, nil
    local uName = (okUN and isSafeStr(rawUName)) and rawUName or nil
    local okUG, rawUGuid = (type(_G.UnitGUID) == "function") and pcall(_G.UnitGUID, "player") or false, nil
    local uGuid = (okUG and isSafeStr(rawUGuid)) and rawUGuid or nil
    local isEnabled = false
    if C_AddOns.GetAddOnEnableState then
        if uName and uName ~= "Unknown" and uName ~= _G.UNKNOWNOBJECT then
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
        if not isEnabled and uGuid then
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
    -- DynamicCursor
    "cursorSizePreferred",
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
        _G.DynamicPrepDB.windowPositions = {}
        _G.DynamicPrepDB.windowScales = {}
        _G.DynamicPrepDB.blizzWinNoAutoClose = true
        _G.DynamicPrepDB.blizzWinDraggable = true
        _G.DynamicPrepDB.blizzWinScrollScale = true
    end
    if type(_G.DynamicChatDB) == "table" then
        _G.DynamicChatDB.chatFramePos = nil
    end
    if addonTable.DesktopWindows and type(addonTable.DesktopWindows.ResetAllWindows) == "function" then
        pcall(addonTable.DesktopWindows.ResetAllWindows, addonTable.DesktopWindows, true)
    end
    g.desktopWindows = CopyTable(addonTable.DEFAULT_DESKTOP_WINDOWS)
    g.desktopWindows.migratedFromPrep = true
    if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.global) == "table" then
        _G.DynamicSuiteDB.global.desktopWindows = g.desktopWindows
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

local function IsEllesmereSubAddonInstalled(folderA, folderB)
    if C_AddOns and type(C_AddOns.GetAddOnInfo) == "function" then
        for _, f in ipairs({ folderA, folderB }) do
            if type(f) == "string" and f ~= "" then
                local ok, name, title, _, _, reason = pcall(C_AddOns.GetAddOnInfo, f)
                if ok and (name or title) and reason ~= "MISSING" then
                    return true
                end
            end
        end
    end
    return false
end
addonTable.IsEllesmereSubAddonInstalled = IsEllesmereSubAddonInstalled
DynamicSuite.IsEllesmereSubAddonInstalled = IsEllesmereSubAddonInstalled

local function ResolveEllesmereProfile(subFolder)
    local edb = _G.EllesmereUIDB
    if type(edb) ~= "table" then
        local legacy = (type(subFolder) == "string" and type(_G[subFolder .. "DB"]) == "table") and _G[subFolder .. "DB"] or nil
        local legProf = (legacy and type(legacy.profile) == "table") and legacy.profile or legacy
        return nil, legProf, nil, "Default"
    end
    local profileName = edb.activeProfile
    if type(profileName) ~= "string" or profileName == "" then
        if type(edb.profileKeys) == "table" then
            local pName = GetPlayer()
            local realm = (type(GetRealmName) == "function" and GetRealmName()) or ""
            profileName = edb.profileKeys[pName .. " - " .. realm] or edb.profileKeys[pName .. "-" .. realm]
        end
    end
    if type(profileName) ~= "string" or profileName == "" then
        profileName = "Default"
    end
    local rootProf = nil
    if type(edb.profiles) == "table" and type(edb.profiles[profileName]) == "table" then
        rootProf = edb.profiles[profileName]
    elseif type(edb.profile) == "table" then
        rootProf = edb.profile
    end
    local subProf = nil
    if type(subFolder) == "string" and subFolder ~= "" then
        if type(rootProf) == "table" and type(rootProf.addons) == "table" and type(rootProf.addons[subFolder]) == "table" then
            subProf = rootProf.addons[subFolder]
        elseif type(_G[subFolder .. "DB"]) == "table" then
            local sdb = _G[subFolder .. "DB"]
            subProf = (type(sdb.profile) == "table") and sdb.profile or sdb
        end
    end
    return edb, subProf, rootProf, profileName
end
addonTable.ResolveEllesmereProfile = ResolveEllesmereProfile
DynamicSuite.ResolveEllesmereProfile = ResolveEllesmereProfile

-- Smart Sub-Module Detection for ElvUI, Leatrix_Plus, and EllesmereUI (wrapped in pcall for zero Lua errors)
local function InspectSmartSubModuleConflict(dynamicModule, otherAddon)
    if IsExternalAddonFrozen(otherAddon) then
        return false, nil, nil
    end
    local shortKey = tostring(dynamicModule or ""):lower():gsub("^dynamic", "")
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
            elseif shortKey == "prep" or dynamicModule == "DynamicPrep" or shortKey == "suite" or dynamicModule == "DynamicSuite" then
                if E.private and E.private.skins and E.private.skins.blizzard and E.private.skins.blizzard.enable == true then
                    return true, "SOFT", "Suite Studio -> Desktop Windows & Menus (Side-by-Side Panels, Drag & Scroll Scale)"
                end
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
            elseif shortKey == "prep" or dynamicModule == "DynamicPrep" or shortKey == "suite" or dynamicModule == "DynamicSuite" then
                if ldb["UseEasyFrameResizing"] == "On" or ldb["MoveBlizzFrames"] == "On" or ldb["NoAutoClose"] == "On" or ldb["ManageFrames"] == "On" then
                    return true, "SOFT", "Suite Studio -> Desktop Windows & Menus (Side-by-Side Panels, Drag & Scroll Scale)"
                end
                if ldb["HideErrorMessages"] == "On" or ldb["NoErrorFrame"] == "On" or ldb["MuteErrorSpeech"] == "On" then
                    return true, "SOFT", "Red Error Text & Sound Filter"
                end
                if ldb["AutomateQuests"] == "On" or ldb["AutomateGossip"] == "On" or ldb["FasterMovieSkip"] == "On" or ldb["AcceptResurrect"] == "On" then
                    return true, "SOFT", "quest/gossip control"
                end
                return false
            elseif shortKey == "group" or dynamicModule == "DynamicGroup" then
                if ldb["AcceptRoleCheck"] == "On" or ldb["AutoAcceptRoleCheck"] == "On" or ldb["AutomateRoleCheck"] == "On" or ldb["AutoConfirmRole"] == "On" then
                    return true, "SOFT", "Auto-Accept Role Check"
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
            local edb, _, rootProf = ResolveEllesmereProfile(nil)
            if type(edb) ~= "table" then return false end
            if shortKey == "prep" or dynamicModule == "DynamicPrep" or shortKey == "suite" or dynamicModule == "DynamicSuite" then
                if IsEllesmereSubAddonInstalled("EllesmereUIQoL", "EllesmereUI_QoL") then
                    return false
                end
                local hasShifter = (edb.shifterEnabled == true or edb.moveBlizzardFrames == true or edb.blizzFrameMover == true or edb.noAutoClose == true)
                if not hasShifter and type(rootProf) == "table" then
                    hasShifter = (rootProf.shifterEnabled == true or rootProf.moveBlizzardFrames == true or rootProf.blizzFrameMover == true or rootProf.noAutoClose == true)
                end
                if hasShifter then
                    return true, "SOFT", "Blizzard Window Mover (Shifter)"
                end
                return false
            elseif shortKey == "chat" or dynamicModule == "DynamicChat" then
                if IsEllesmereSubAddonInstalled("EllesmereUIChat", "EllesmereUI_Chat") then
                    return false
                end
                if IsExternalAddonFrozen("EllesmereUIChat") or IsExternalAddonFrozen("EllesmereUI_Chat") then
                    return false
                end
                if (type(edb.chat) == "table" and edb.chat.enable == true)
                    or (type(edb.modules) == "table" and edb.modules.chat == true)
                    or (type(rootProf) == "table" and type(rootProf.chat) == "table" and rootProf.chat.enable == true) then
                    return true, "HARD", "chat/editbox skinning"
                end
                return false
            elseif shortKey == "bags" or dynamicModule == "DynamicBags" then
                if IsEllesmereSubAddonInstalled("EllesmereUIBags", "EllesmereUI_Bags") then
                    return false
                end
                if IsExternalAddonFrozen("EllesmereUIBags") or IsExternalAddonFrozen("EllesmereUI_Bags") then
                    return false
                end
                if (type(edb.bags) == "table" and edb.bags.enable == true)
                    or (type(edb.modules) == "table" and edb.modules.bags == true)
                    or (type(rootProf) == "table" and type(rootProf.bags) == "table" and rootProf.bags.enable == true) then
                    return true, "HARD", "bag/bank frame replacement"
                end
                return false
            end
            return false
        end)
        if ok and isSubActive == true then
            return true, subTier or "HARD", subFeature
        end
        return false, nil, nil

    elseif otherAddon == "EllesmereUIQoL" or otherAddon == "EllesmereUI_QoL" then
        if not SafeIsAddOnLoaded(otherAddon) then
            return false, nil, nil
        end
        local ok, isSubActive, subTier, subFeature = pcall(function()
            local edb, subProf, rootProf = ResolveEllesmereProfile("EllesmereUIQoL")
            local qdb = _G.EllesmereUIQoLDB
            local function GetFlag(key, defaultOn)
                local v
                if type(edb) == "table" and edb[key] ~= nil then v = edb[key]
                elseif type(subProf) == "table" and subProf[key] ~= nil then v = subProf[key]
                elseif type(rootProf) == "table" and rootProf[key] ~= nil then v = rootProf[key]
                elseif type(qdb) == "table" and qdb[key] ~= nil then v = qdb[key] end
                if defaultOn then return v ~= false end
                return v == true
            end
            local features = {}
            if shortKey == "dialogue" or dynamicModule == "DynamicDialogue" then
                if GetFlag("dialogKeys", false) then table.insert(features, "Dialog Keys (1-9 Hotkeys)") end
                if GetFlag("autoGossip", false) then table.insert(features, "Auto-Select Single Gossip") end
                if GetFlag("dialogueUI", false) or GetFlag("dialogUI", false) or GetFlag("questDialogue", false) then
                    table.insert(features, "Quest & Gossip Reader")
                end
            elseif shortKey == "bags" or dynamicModule == "DynamicBags" then
                if GetFlag("autoSellJunk", true) or GetFlag("autoSell", false) then table.insert(features, "Auto-Sell Grey Junk") end
                if GetFlag("autoRepair", true) then table.insert(features, "Auto-Repair Gear") end
                if GetFlag("quickLoot", false) or GetFlag("fastLoot", false) then table.insert(features, "Faster Auto-Loot") end
            elseif shortKey == "prep" or dynamicModule == "DynamicPrep" or shortKey == "suite" or dynamicModule == "DynamicSuite" then
                if GetFlag("shifterEnabled", false) or GetFlag("moveBlizzardFrames", false) or GetFlag("blizzFrameMover", false) or GetFlag("noAutoClose", false) then
                    table.insert(features, "Blizzard Window Mover (Shifter)")
                end
                if GetFlag("hideErrorMessages", false) or GetFlag("hideErrorText", false) then
                    table.insert(features, "Red Error Text Filter")
                end
                if GetFlag("autoGossip", false) then table.insert(features, "Auto-Select Single Gossip") end
                if GetFlag("hideTalkingHead", false) or GetFlag("muteTalkingHead", false) then table.insert(features, "Hide/Mute Talking Head") end
                if GetFlag("skipCinematics", false) then table.insert(features, "Skip Cutscenes") end
                if GetFlag("autoAcceptRes", false) then table.insert(features, "Auto-Accept Resurrection") end
            elseif shortKey == "group" or dynamicModule == "DynamicGroup" then
                if GetFlag("quickSignup", false) or GetFlag("autoAcceptRoleCheck", false) then
                    table.insert(features, "Auto-Accept Role Check & Quick Sign-Up")
                end
                if GetFlag("persistSignupNote", false) then table.insert(features, "Persistent Sign-Up Note") end
                if GetFlag("autoInsertKeystone", false) then table.insert(features, "Auto-Insert Mythic+ Keystone") end
                if type(edb) == "table" and type(edb.teleportPrompt) == "table" and edb.teleportPrompt.enabled ~= false then
                    table.insert(features, "Dungeon Teleport Prompt")
                end
                if type(edb) == "table" and type(edb.keystonePopup) == "table" and edb.keystonePopup.enabled == true then
                    table.insert(features, "!keys Responder")
                end
            elseif shortKey == "fps" or dynamicModule == "DynamicFPS" then
                if type(edb) == "table" and type(edb.autoLogging) == "table" and edb.autoLogging.enabled == true then
                    table.insert(features, "Auto Combat Logging")
                end
            elseif shortKey == "zoom" or dynamicModule == "DynamicZoom" then
                if GetFlag("maxCameraZoom", false) or GetFlag("cameraZoom", false) then
                    table.insert(features, "Max Camera Zoom")
                end
            elseif shortKey == "cursor" or dynamicModule == "DynamicCursor" then
                if GetFlag("cursorCircle", false) or GetFlag("cursorEnabled", false) or (type(edb.cursor) == "table" and edb.cursor.enabled == true) then
                    table.insert(features, "Cursor Ring")
                end
                if GetFlag("crosshair", false) or GetFlag("crosshairEnabled", false) or (type(edb.crosshair) == "table" and edb.crosshair.enabled == true) then
                    table.insert(features, "Character Crosshair")
                end
                if GetFlag("trail", false) or GetFlag("cursorTrail", false) then
                    table.insert(features, "Cursor Trail")
                end
                if type(edb.gcd) == "table" and edb.gcd.enabled == true then
                    table.insert(features, "Cursor GCD Ring")
                end
                if type(edb.castCircle) == "table" and edb.castCircle.enabled == true then
                    table.insert(features, "Cursor Cast Ring")
                end
            end
            if #features > 0 then
                return true, "SOFT", table.concat(features, ", ")
            end
            return false
        end)
        if ok and isSubActive == true then
            return true, subTier or "SOFT", subFeature
        end
        return false, nil, nil

    elseif otherAddon == "EllesmereUIBlizzardSkin" then
        if not SafeIsAddOnLoaded("EllesmereUIBlizzardSkin") then
            return false, nil, nil
        end
        if IsEllesmereSubAddonInstalled("EllesmereUIQoL", "EllesmereUI_QoL") then
            return false, nil, nil
        end
        local ok, isSubActive, subTier, subFeature = pcall(function()
            if shortKey == "prep" or dynamicModule == "DynamicPrep" or shortKey == "suite" or dynamicModule == "DynamicSuite" then
                local edb, subProf, rootProf = ResolveEllesmereProfile("EllesmereUIBlizzardSkin")
                if (type(edb) == "table" and edb.shifterEnabled == true)
                    or (type(subProf) == "table" and subProf.shifterEnabled == true)
                    or (type(rootProf) == "table" and rootProf.shifterEnabled == true) then
                    return true, "SOFT", "Blizzard Window Mover (Shifter)"
                end
            end
            return false
        end)
        if ok and isSubActive == true then
            return true, subTier or "SOFT", subFeature
        end
        return false, nil, nil

    elseif otherAddon == "EllesmereUIMythicTimer" or otherAddon == "EllesmereUI_MythicPlus" then
        if not SafeIsAddOnLoaded(otherAddon) then
            return false, nil, nil
        end
        local ok, isSubActive, subTier, subFeature = pcall(function()
            if shortKey == "group" or dynamicModule == "DynamicGroup" or shortKey == "prep" or dynamicModule == "DynamicPrep" then
                local edb, subProf = ResolveEllesmereProfile("EllesmereUIMythicTimer")
                local hasKey = (type(edb) == "table" and edb.autoInsertKeystone == true)
                    or (type(subProf) == "table" and (subProf.autoInsertKeystone == true or subProf.autoSlotKeystone == true))
                if hasKey then
                    return true, "SOFT", "Auto-Insert Mythic+ Keystone"
                elseif shortKey == "group" or dynamicModule == "DynamicGroup" then
                    return true, "SOFT", "Mythic+ Timer & Keystone Tools"
                end
            end
            return false
        end)
        if ok and isSubActive == true then
            return true, subTier or "SOFT", subFeature
        end
        return false, nil, nil

    elseif otherAddon == "EnhanceQoL" then
        if not SafeIsAddOnLoaded("EnhanceQoL") then
            return false, nil, nil
        end
        local ok, isSubActive, subTier, subFeature = pcall(function()
            local edb = _G.EnhanceQoLDB
            local prof = (type(edb) == "table" and type(edb.profile) == "table") and edb.profile or edb
            if type(prof) ~= "table" then return false end
            if shortKey == "chat" or dynamicModule == "DynamicChat" then
                if SafeIsAddOnLoaded("EnhanceQoLChatSocial") or prof.enableChat == true or prof.chatCopy == true then
                    return true, "SOFT", "shared chat features"
                end
                return false
            elseif shortKey == "bags" or dynamicModule == "DynamicBags" then
                if prof.autoSellJunk == true or prof.fastAutoLoot == true or prof.autoRepair == true then
                    return true, "SOFT", "vendor/loot automation"
                end
                return false
            elseif shortKey == "dialogue" or dynamicModule == "DynamicDialogue" then
                if prof.questDialogue == true or prof.autoAcceptQuest == true or prof.autoTurnInQuest == true then
                    return true, "SOFT", "quest/dialogue automation"
                end
                return false
            elseif shortKey == "prep" or dynamicModule == "DynamicPrep" then
                if prof.hideErrorText == true or prof.hideErrors == true or prof.hideUIErrors == true or prof.errorFilter == true or prof.muteErrorSpeech == true or prof.hideErrorFrame == true then
                    return true, "SOFT", "Red Error Text & Sound Filter"
                end
                if prof.autoAcceptQuest == true or prof.autoGossip == true or prof.skipCinematics == true or prof.hideTalkingHead == true then
                    return true, "SOFT", "quest/gossip automation"
                end
                return false
            elseif shortKey == "group" or dynamicModule == "DynamicGroup" then
                if prof.autoAcceptRoleCheck == true or prof.autoRoleCheck == true or prof.acceptRoleCheck == true or prof.autoConfirmRole == true then
                    return true, "SOFT", "Auto-Accept Role Check"
                end
                if type(prof.group) == "table" and (prof.group.autoAcceptRoleCheck == true or prof.group.autoRoleCheck == true or prof.group.acceptRoleCheck == true) then
                    return true, "SOFT", "Auto-Accept Role Check"
                end
                return false
            elseif shortKey == "zoom" or dynamicModule == "DynamicZoom" then
                if prof.maxCameraZoom == true or prof.cameraZoom == true then
                    return true, "SOFT", "camera zoom control"
                end
                return false
            elseif shortKey == "mail" or dynamicModule == "DynamicMail" then
                if prof.mailAutomation == true or prof.openAllMail == true then
                    return true, "SOFT", "mailbox automation"
                end
                return false
            end
            return false
        end)
        if ok and isSubActive == true then
            return true, subTier or "SOFT", subFeature
        end
        return false, nil, nil

    elseif otherAddon == "ErrorFilter" or otherAddon == "ErrorMonster" then
        if not SafeIsAddOnLoaded(otherAddon) then
            return false, nil, nil
        end
        if shortKey == "prep" or dynamicModule == "DynamicPrep" then
            return true, "SOFT", "Red Error Text & Sound Filter"
        end
        return false, nil, nil
    end
    return nil, nil, nil
end
addonTable.InspectSmartSubModuleConflict = InspectSmartSubModuleConflict
DynamicSuite.InspectSmartSubModuleConflict = InspectSmartSubModuleConflict

-- Zero-Taint Read-Only Runtime Blizzard Frame & Event Ownership Prober
-- Detects both known and unknown competing addons on the fly without hooking globals or causing taint.
function DynamicSuite:ProbeBlizzardFrameConflict(domain)
    local d = tostring(domain or ""):upper()
    if d == "DIALOGUE" then
        for _, name in ipairs({ "DialogueUI", "DialogUI", "Immersion", "Storyline" }) do
            if SafeIsAddOnLoaded(name) then
                local friendly = FRIENDLY_CONFLICT_NAMES[name] or name
                return true, friendly, friendly .. " is loaded"
            end
        end
        if SafeIsAddOnLoaded("EllesmereUIQoL") or SafeIsAddOnLoaded("EllesmereUI_QoL") then
            local qdb = _G.EllesmereUIQoLDB or (_G.EllesmereUIDB and _G.EllesmereUIDB.qol)
            if type(qdb) == "table" and (
                qdb.dialogueUI == true
                or qdb.dialogUI == true
                or qdb.questDialogue == true
                or qdb.gossipReplacement == true
            ) then
                return true, "EllesmereUI Quality of Life", "EllesmereUI QoL dialogue replacement is enabled"
            end
        end
        return false, nil, nil
    elseif d == "CHAT" then
        for _, name in ipairs({ "EllesmereUIChat", "EllesmereUI_Chat", "Chattynator", "Prat-3.0", "ls_Glass", "LS_Glass", "Glass" }) do
            if SafeIsAddOnLoaded(name) then
                return true, FRIENDLY_CONFLICT_NAMES[name] or name, "Dedicated chat replacement addon loaded"
            end
        end
        local elvActive, _, elvFeat = InspectSmartSubModuleConflict("DynamicChat", "ElvUI")
        if elvActive then
            return true, "ElvUI", elvFeat or "ElvUI chat module enabled"
        end
        local euiActive, _, euiFeat = InspectSmartSubModuleConflict("DynamicChat", "EllesmereUI")
        if euiActive then
            return true, "EllesmereUI", euiFeat or "EllesmereUI chat module enabled"
        end
        return false, nil, nil
    elseif d == "BAGS" then
        for _, name in ipairs({ "EllesmereUIBags", "EllesmereUI_Bags", "Baganator", "BetterBags", "AdiBags", "ArkInventory", "Bagnon", "Sorted", "LiteBag" }) do
            if SafeIsAddOnLoaded(name) then
                return true, FRIENDLY_CONFLICT_NAMES[name] or name, "Dedicated bag replacement addon loaded"
            end
        end
        local elvActive = InspectSmartSubModuleConflict("DynamicBags", "ElvUI")
        if elvActive then return true, "ElvUI", "ElvUI bags module enabled" end
        local euiActive = InspectSmartSubModuleConflict("DynamicBags", "EllesmereUI")
        if euiActive then return true, "EllesmereUI", "EllesmereUI bags module enabled" end
        return false, nil, nil
    elseif d == "WINDOWS" then
        if addonTable.DesktopWindows and type(addonTable.DesktopWindows.GetYieldAddon) == "function" then
            local ok, yAddon = pcall(addonTable.DesktopWindows.GetYieldAddon, addonTable.DesktopWindows)
            if ok and yAddon then
                return true, FRIENDLY_CONFLICT_NAMES[yAddon] or yAddon, "External Blizzard window mover active"
            end
        end
        return false, nil, nil
    elseif d == "TALENTS" then
        for _, name in ipairs({ "TalentLoadoutManager", "TalentLoadoutsEx", "BtWLoadouts", "ImprovedTalentLoadouts" }) do
            if SafeIsAddOnLoaded(name) then
                return true, FRIENDLY_CONFLICT_NAMES[name] or name, "External talent loadout manager loaded"
            end
        end
        return false, nil, nil
    end
    return false, nil, nil
end
addonTable.ProbeBlizzardFrameConflict = function(domain)
    return DynamicSuite:ProbeBlizzardFrameConflict(domain)
end

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

local function IsAddonLockedInDynamicLoad(addonFolder)
    if not addonFolder or type(addonFolder) ~= "string" then return false end
    if addonTable.IsAddonLocked and addonTable.IsAddonLocked(addonFolder) then
        return true
    end
    local dl = _G.DynamicLoadDB
    if type(dl) ~= "table" then return false end
    if (dl.addonStates and dl.addonStates[addonFolder] == "LOCKED")
        or (dl.lockedAddons and dl.lockedAddons[addonFolder] == true) then
        return true
    end
    if GetCharScopeMode() ~= "CHARACTER" and type(dl.globalData) == "table" then
        if (dl.globalData.addonStates and dl.globalData.addonStates[addonFolder] == "LOCKED")
            or (dl.globalData.lockedAddons and dl.globalData.lockedAddons[addonFolder] == true) then
            return true
        end
    end
    return false
end

local function GetActiveDynamicLoadProfilesTable()
    local dl = _G.DynamicLoadDB
    if type(dl) ~= "table" then return nil end
    if GetCharScopeMode() == "CHARACTER" and type(dl.charData) == "table" then
        local cd = dl.charData[GetCurrentCharKey()]
        if type(cd) == "table" and type(cd.profiles) == "table" then
            return cd.profiles
        end
    elseif type(dl.globalData) == "table" and type(dl.globalData.profiles) == "table" then
        return dl.globalData.profiles
    end
    return dl.profiles
end

local function IsAddonConfiguredOutdoorOnly(addonFolder)
    if not addonFolder or type(addonFolder) ~= "string" then return false end
    if IsExternalAddonFrozen(addonFolder) or IsAddonLockedInDynamicLoad(addonFolder) then
        return false
    end
    local profiles = GetActiveDynamicLoadProfilesTable()
    if type(profiles) ~= "table" then return false end
    local outProf = profiles[CONTEXT_OUTDOOR]
    if type(outProf) ~= "table" or type(outProf.addons) ~= "table" or outProf.addons[addonFolder] ~= true then
        return false
    end
    for _, ctx in ipairs({ CONTEXT_DELVE, CONTEXT_DUNGEON, CONTEXT_RAID, CONTEXT_PVP }) do
        local p = profiles[ctx]
        if type(p) ~= "table" or type(p.addons) ~= "table" or p.addons[addonFolder] ~= false then
            return false
        end
    end
    return true
end
addonTable.IsAddonConfiguredOutdoorOnly = IsAddonConfiguredOutdoorOnly
DynamicSuite.IsAddonConfiguredOutdoorOnly = IsAddonConfiguredOutdoorOnly

local function SetAddonOutdoorOnlyInDynamicLoad(addonFolder)
    if not addonFolder or type(addonFolder) ~= "string" then return false end
    local pName = GetPlayer()
    if type(addonTable.SetAddonFrozen) == "function" then
        pcall(addonTable.SetAddonFrozen, addonFolder, false)
    end
    if type(addonTable.SetAddonLocked) == "function" then
        pcall(addonTable.SetAddonLocked, addonFolder, false)
    end

    _G.DynamicLoadDB = type(_G.DynamicLoadDB) == "table" and _G.DynamicLoadDB or {}
    local dl = _G.DynamicLoadDB
    dl.knownAddons = type(dl.knownAddons) == "table" and dl.knownAddons or {}
    dl.knownAddons[addonFolder] = true

    local function ClearStateFlags(tbl)
        if type(tbl) ~= "table" then return end
        tbl.frozenAddons = type(tbl.frozenAddons) == "table" and tbl.frozenAddons or {}
        tbl.lockedAddons = type(tbl.lockedAddons) == "table" and tbl.lockedAddons or {}
        tbl.addonStates = type(tbl.addonStates) == "table" and tbl.addonStates or {}
        tbl.frozenAddons[addonFolder] = nil
        tbl.lockedAddons[addonFolder] = nil
        tbl.addonStates[addonFolder] = "NORMAL"
    end

    local function ApplyOutdoorProfiles(profilesTbl)
        if type(profilesTbl) ~= "table" then return end
        for _, ctx in ipairs({ CONTEXT_OUTDOOR, CONTEXT_DELVE, CONTEXT_DUNGEON, CONTEXT_RAID, CONTEXT_PVP }) do
            profilesTbl[ctx] = type(profilesTbl[ctx]) == "table" and profilesTbl[ctx] or { name = CONTEXT_LABELS[ctx] or ctx, addons = {} }
            profilesTbl[ctx].addons = type(profilesTbl[ctx].addons) == "table" and profilesTbl[ctx].addons or {}
            profilesTbl[ctx].addons[addonFolder] = (ctx == CONTEXT_OUTDOOR)
        end
    end

    ClearStateFlags(dl)
    dl.profiles = type(dl.profiles) == "table" and dl.profiles or {}
    ApplyOutdoorProfiles(dl.profiles)

    if GetCharScopeMode() == "CHARACTER" then
        dl.charData = type(dl.charData) == "table" and dl.charData or {}
        local charKey = GetCurrentCharKey()
        dl.charData[charKey] = type(dl.charData[charKey]) == "table" and dl.charData[charKey] or {}
        ClearStateFlags(dl.charData[charKey])
        dl.charData[charKey].profiles = type(dl.charData[charKey].profiles) == "table" and dl.charData[charKey].profiles or {}
        ApplyOutdoorProfiles(dl.charData[charKey].profiles)
    else
        dl.globalData = type(dl.globalData) == "table" and dl.globalData or {}
        ClearStateFlags(dl.globalData)
        dl.globalData.profiles = type(dl.globalData.profiles) == "table" and dl.globalData.profiles or {}
        ApplyOutdoorProfiles(dl.globalData.profiles)
    end

    local activeCtx = (type(addonTable.DetectEnvironment) == "function" and addonTable.DetectEnvironment())
        or dl.activeProfile
        or CONTEXT_OUTDOOR

    if type(addonTable.StageAddonProfile) == "function" then
        pcall(addonTable.StageAddonProfile, activeCtx, false)
    elseif C_AddOns then
        if activeCtx == CONTEXT_OUTDOOR then
            if C_AddOns.EnableAddOn then
                pcall(C_AddOns.EnableAddOn, addonFolder, pName)
                pcall(C_AddOns.EnableAddOn, addonFolder)
            end
        elseif C_AddOns.DisableAddOn then
            pcall(C_AddOns.DisableAddOn, addonFolder, pName)
            pcall(C_AddOns.DisableAddOn, addonFolder)
        end
    end

    local needsReload = (activeCtx ~= CONTEXT_OUTDOOR) and SafeIsAddOnLoaded(addonFolder)
    return needsReload
end
addonTable.SetAddonOutdoorOnlyInDynamicLoad = SetAddonOutdoorOnlyInDynamicLoad
DynamicSuite.SetAddonOutdoorOnlyInDynamicLoad = SetAddonOutdoorOnlyInDynamicLoad

local function IsThirdPartyConflictActive(dynamicModule, otherAddon, pName)
    if otherAddon == "ElvUI" or otherAddon == "Leatrix_Plus" or otherAddon == "EllesmereUI"
        or otherAddon == "EllesmereUIQoL" or otherAddon == "EllesmereUI_QoL" or otherAddon == "EllesmereUIBlizzardSkin"
        or otherAddon == "EllesmereUIMythicTimer" or otherAddon == "EllesmereUI_MythicPlus" or otherAddon == "EnhanceQoL"
        or otherAddon == "ErrorFilter" or otherAddon == "ErrorMonster" then
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
    local low = s:lower():gsub("^dynamic", "")
    if low == "load" then return "DynamicLoad", "load"
    elseif low == "marker" then return "DynamicMarker", "marker"
    elseif low == "cursor" then return "DynamicCursor", "cursor"
    elseif low == "zoom" then return "DynamicZoom", "zoom"
    elseif low == "fps" then return "DynamicFPS", "fps"
    elseif low == "prep" then return "DynamicPrep", "prep"
    elseif low == "talent" then return "DynamicTalent", "talent"
    elseif low == "group" then return "DynamicGroup", "group"
    elseif low == "bags" then return "DynamicBags", "bags"
    elseif low == "chat" then return "DynamicChat", "chat"
    elseif low == "mail" then return "DynamicMail", "mail"
    elseif low == "vault" then return "DynamicVault", "vault"
    elseif low == "dialogue" then return "DynamicDialogue", "dialogue"
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
    for _, dbTbl in ipairs({ _G.DynamicPrepDB, _G.DynamicZoomDB, _G.DynamicChatDB, _G.DynamicFPSDB, _G.DynamicBagsDB, _G.DynamicMailDB }) do
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

    local isBlizzWinAutoYield = false
    local isBlizzWinOverlap = (otherAddon == "NoAutoClose" or otherAddon == "BlizzMove" or otherAddon == "DeModal" or otherAddon == "MoveAny")
        or (type(smartFeature) == "string" and smartFeature:find("Desktop Windows", 1, true) ~= nil)
    if tier == 2 and (addonNameKey == "DynamicPrep" or addonNameKey == "DynamicSuite") and (isBlizzWinOverlap or otherAddon == "EllesmereUI" or otherAddon == "EllesmereUIQoL" or otherAddon == "EllesmereUI_QoL" or otherAddon == "Leatrix_Plus" or otherAddon == "ElvUI") then
        local suiteKey = tostring(otherAddon) .. "_DynamicSuite"
        if ackAction == nil then
            local altAck = g.acknowledgedConflicts[suiteKey] or g.granularModes[suiteKey]
            if altAck == "PRIORITISE_DYNAMIC" or altAck == "USE_DYNAMIC" or altAck == "PREFER_DYNAMIC" then
                ackAction = "PRIORITISE_DYNAMIC"
            end
        end
        if ackAction == nil then
            ackAction = "YIELD_TO_EXTERNAL"
            isBlizzWinAutoYield = true
        elseif ackAction == "YIELD_TO_EXTERNAL" then
            isBlizzWinAutoYield = true
        end
        smartFeature = smartFeature or "Suite Studio -> Desktop Windows & Menus (Side-by-Side Panels, Drag & Scroll Scale)"
    elseif tier == 2 and ((addonNameKey == "DynamicGroup" and (smartFeature == "Auto-Accept Role Check" or (type(smartFeature) == "string" and smartFeature:find("Auto-Accept Role Check", 1, true) ~= nil))) or (addonNameKey == "DynamicPrep" and ((type(smartFeature) == "string" and smartFeature:find("Red Error Text", 1, true) ~= nil) or otherAddon == "ErrorFilter" or otherAddon == "ErrorMonster"))) then
        if ackAction == nil then
            ackAction = "YIELD_TO_EXTERNAL"
            isBlizzWinAutoYield = true
        elseif ackAction == "YIELD_TO_EXTERNAL" then
            isBlizzWinAutoYield = true
        end
    end

    local friendly = FRIENDLY_CONFLICT_NAMES[otherAddon] or otherAddon
    local displayTarget = (otherAddon == "DialogueUI" or otherAddon == "DialogUI" or otherAddon == "Plumber" or otherAddon == "Baganator" or otherAddon == "Immersion" or otherAddon == "Storyline" or otherAddon == "AutoTurnIn" or otherAddon == "WIM" or otherAddon == "EllesmereUI")
        and otherAddon or friendly
    local ownerLabel = isBlizzWinOverlap and "Suite Studio -> Desktop Windows & Menus" or addonNameKey
    local bannerText
    if otherAddon == "DecorVendor" then
        bannerText = "Conflict Detected: DecorVendor taints Blizzard's /tm raid marker command (SetRaidTarget). Disable it (Set to Never) and exit & restart the game client (/reload will not clear the lockout)."
    elseif tier == 2 then
        bannerText = string.format("QoL Overlap: %s shares sub-features with %s. Choose which addon owns the shared triggers.", displayTarget, ownerLabel)
    else
        bannerText = string.format("Conflict Detected: %s is currently active and may cause UI errors or duplicate frames.", displayTarget)
    end
    return {
        conflictKey    = conflictKey,
        dynamicModule  = addonNameKey,
        moduleKey      = modKey,
        conflictAddon  = otherAddon,
        friendlyName   = friendly,
        category       = isBlizzWinOverlap and "Suite Studio -> Desktop Windows & Menus" or (reg and reg.category or modInfo.category or addonNameKey),
        tier           = tier,
        severity       = (tier == 2) and "GRANULAR" or "HARD",
        isPartial      = (tier == 2),
        isGranular     = (tier == 2),
        isAutoYielded  = isBlizzWinAutoYield,
        isAcknowledged = (ackAction ~= nil),
        resolvedAction = ackAction,
        yieldFeature   = smartFeature or CONFLICT_YIELD_FEATURES[otherAddon],
        bannerText     = bannerText,
        hasMigration   = (reg and reg.hasLegacyMigration and reg.hasLegacyMigration[otherAddon]) or false,
        isSimulated    = (isSim == true),
    }
end
addonTable.BuildConflictEntry = BuildConflictItem
addonTable.BuildConflictItem = BuildConflictItem

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

            local itemShort = tostring(item.moduleKey or item.dynamicModule or ""):lower():gsub("^dynamic", "")
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
    local shortKey = tostring(modKeyOrName):lower():gsub("^dynamic", "")
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
    local shortKey = tostring(modKeyOrName):lower():gsub("^dynamic", "")
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

function DynamicSuite:GetFeatureAutoYield(moduleName, featureKey)
    local canonMod = NormalizeSuiteModuleName(moduleName)
    local fKey = tostring(featureKey or ""):upper()
    local g = EnsureSuiteGlobal()
    g.granularModes = type(g.granularModes) == "table" and g.granularModes or {}
    g.acknowledgedConflicts = type(g.acknowledgedConflicts) == "table" and g.acknowledgedConflicts or {}

    local function IsOverridden(otherAddon)
        local cKey = tostring(otherAddon) .. "_" .. tostring(canonMod)
        local gm = g.granularModes[cKey] or g.acknowledgedConflicts[cKey]
        return (gm == "PRIORITISE_DYNAMIC" or gm == "USE_DYNAMIC" or gm == "PREFER_DYNAMIC")
    end

    if fKey == "ROLE_CHECK" and canonMod == "DynamicGroup" then
        for _, other in ipairs({ "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL", "EllesmereUIGroupFinder", "EllesmereUI_GroupFinder", "EllesmereUI" }) do
            if not IsExternalAddonFrozen(other) and SafeIsAddOnLoaded(other) and not IsOverridden(other) then
                local active = false
                pcall(function()
                    if other == "EnhanceQoL" then
                        local edb = _G.EnhanceQoLDB
                        local prof = (type(edb) == "table" and type(edb.profile) == "table") and edb.profile or edb
                        if type(prof) == "table" then
                            if prof.autoAcceptRoleCheck == true or prof.autoRoleCheck == true or prof.acceptRoleCheck == true or prof.autoConfirmRole == true then
                                active = true
                            elseif type(prof.group) == "table" and (prof.group.autoAcceptRoleCheck == true or prof.group.autoRoleCheck == true or prof.group.acceptRoleCheck == true) then
                                active = true
                            end
                        end
                    elseif other == "Leatrix_Plus" then
                        local ldb = _G.LeaPlusDB
                        if type(ldb) == "table" and (ldb["AcceptRoleCheck"] == "On" or ldb["AutoAcceptRoleCheck"] == "On" or ldb["AutomateRoleCheck"] == "On" or ldb["AutoConfirmRole"] == "On") then
                            active = true
                        end
                    else
                        local edb, subProf, rootProf = ResolveEllesmereProfile(other)
                        if (type(edb) == "table" and (edb.quickSignup == true or edb.autoAcceptRoleCheck == true))
                            or (type(subProf) == "table" and (subProf.quickSignup == true or subProf.autoAcceptRoleCheck == true))
                            or (type(rootProf) == "table" and (rootProf.quickSignup == true or rootProf.autoAcceptRoleCheck == true)) then
                            active = true
                        end
                    end
                end)
                if active then
                    return true, other, FRIENDLY_CONFLICT_NAMES[other] or other
                end
            end
        end
    elseif fKey == "ERROR_FILTER" and canonMod == "DynamicPrep" then
        for _, other in ipairs({ "ErrorFilter", "ErrorMonster", "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL", "EllesmereUI" }) do
            if not IsExternalAddonFrozen(other) and SafeIsAddOnLoaded(other) and not IsOverridden(other) then
                local active = false
                pcall(function()
                    if other == "ErrorFilter" then
                        local efdb = _G.ErrorFilterDB
                        if type(efdb) == "table" and type(efdb.profile) == "table" and efdb.profile.mode == 0 then
                            active = false
                        else
                            active = true
                        end
                    elseif other == "ErrorMonster" then
                        active = true
                    elseif other == "EnhanceQoL" then
                        local edb = _G.EnhanceQoLDB
                        local prof = (type(edb) == "table" and type(edb.profile) == "table") and edb.profile or edb
                        if type(prof) == "table" and (prof.hideErrorText == true or prof.hideErrors == true or prof.hideUIErrors == true or prof.errorFilter == true or prof.muteErrorSpeech == true or prof.hideErrorFrame == true) then
                            active = true
                        end
                    elseif other == "Leatrix_Plus" then
                        local ldb = _G.LeaPlusDB
                        if type(ldb) == "table" and (ldb["HideErrorMessages"] == "On" or ldb["NoErrorFrame"] == "On" or ldb["MuteErrorSpeech"] == "On") then
                            active = true
                        end
                    else
                        local edb, subProf, rootProf = ResolveEllesmereProfile(other)
                        if (type(edb) == "table" and (edb.hideErrorMessages == true or edb.hideErrorText == true))
                            or (type(subProf) == "table" and (subProf.hideErrorMessages == true or subProf.hideErrorText == true))
                            or (type(rootProf) == "table" and (rootProf.hideErrorMessages == true or rootProf.hideErrorText == true)) then
                            active = true
                        end
                    end
                end)
                if active then
                    return true, other, FRIENDLY_CONFLICT_NAMES[other] or other
                end
            end
        end
    end

    return false, nil, nil
end
addonTable.GetFeatureAutoYield = function(moduleName, featureKey)
    return DynamicSuite:GetFeatureAutoYield(moduleName, featureKey)
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
        print(string.format("%s |cFF22C55E[Conflict Diagnostic]|r: Zero active third-party addon conflicts or overlaps detected across all 12 DynamicSuite modules.", ADDON_TITLE))
        return all
    end

    print(string.format("%s |cFFF5B82E[Conflict Diagnostic Summary]|r: %d Tier-1 HARD conflict(s), %d Tier-2 QoL overlap(s) active:", ADDON_TITLE, #hardList, #softList))
    for _, item in ipairs(hardList) do
        local st = (item.resolvedAction == "USE_DYNAMIC") and "Prioritising DynamicSuite" or ((item.resolvedAction == "KEEP_OTHER") and "Keeping External" or "Active")
        local feat = (type(item.yieldFeature) == "string" and item.yieldFeature ~= "") and (" |cFF94A3B8[" .. item.yieldFeature .. "]|r") or ""
        print(string.format("  |cFFEF4444[HARD - %s]|r |cFFFFFFFF%s|r <-> |cFFFFFFFF%s|r%s", st, item.dynamicModule, item.friendlyName or item.conflictAddon, feat))
    end
    for _, item in ipairs(softList) do
        local st = (item.resolvedAction == "PRIORITISE_DYNAMIC") and "Prioritising DynamicSuite" or ((item.resolvedAction == "YIELD_TO_EXTERNAL") and (item.isAutoYielded and "Auto-Yielded" or "Yielding") or "Active")
        local feat = (type(item.yieldFeature) == "string" and item.yieldFeature ~= "") and (" |cFF94A3B8[" .. item.yieldFeature .. "]|r") or ""
        print(string.format("  |cFF38BDF8[QoL - %s]|r |cFFFFFFFF%s|r <-> |cFFFFFFFF%s|r%s", st, item.dynamicModule, item.friendlyName or item.conflictAddon, feat))
    end
    return all
end
addonTable.PrintConflictSummary = PrintConflictSummary
DynamicSuite.PrintConflictSummary = PrintConflictSummary

function addonTable.PrintEllesmereConflictBreakdown()
    local subAddons = {
        { folder = "EllesmereUI",                mods = { "DynamicPrep", "DynamicChat", "DynamicBags" } },
        { folder = "EllesmereUIChat",            mods = { "DynamicChat" } },
        { folder = "EllesmereUIBags",            mods = { "DynamicBags" } },
        { folder = "EllesmereUIGroupFinder",     mods = { "DynamicGroup" } },
        { folder = "EllesmereUIQuickdraw",       mods = { "DynamicMarker" } },
        { folder = "EllesmereUIAuraBuffReminders", mods = { "DynamicPrep" } },
        { folder = "EllesmereUIMythicTimer",     mods = { "DynamicGroup", "DynamicPrep" } },
        { folder = "EllesmereUIQoL",             mods = { "DynamicBags", "DynamicPrep", "DynamicGroup", "DynamicDialogue", "DynamicFPS", "DynamicZoom", "DynamicCursor" } },
        { folder = "EllesmereUIBlizzardSkin",    mods = { "DynamicPrep" } },
    }
    local pName = GetPlayer()
    local _, _, _, profName = ResolveEllesmereProfile(nil)
    print(string.format("%s |cFF38BDF8[EllesmereUI Sub-Module Diagnostic]|r (Active Profile: |cFFFFFFFF%s|r):", ADDON_TITLE, tostring(profName or "Default")))
    local foundAny = false
    for _, entry in ipairs(subAddons) do
        local fName = entry.folder
        if IsEllesmereSubAddonInstalled(fName) then
            foundAny = true
            local stateLabel = "|cFF94A3B8Disabled|r"
            if IsExternalAddonFrozen(fName) then
                stateLabel = "|cFF38BDF8Frozen [Never]|r"
            elseif SafeIsAddOnLoaded(fName) then
                stateLabel = "|cFF22C55ELoaded|r"
            elseif SafeIsAddOnEnabledInClient(fName, pName) then
                stateLabel = "|cFFF5B82EEnabled (Pending Reload)|r"
            end
            local overlaps = {}
            for _, modName in ipairs(entry.mods) do
                local isAct, _, feat = InspectSmartSubModuleConflict(modName, fName)
                if isAct and type(feat) == "string" and feat ~= "" then
                    table.insert(overlaps, modName .. ": " .. feat)
                end
            end
            local overlapText = (#overlaps > 0) and table.concat(overlaps, " | ") or "No overlapping features active"
            print(string.format("  |cFFFFFFFF%s|r [%s] -> %s", fName, stateLabel, overlapText))
        end
    end
    if not foundAny then
        print("  |cFF94A3B8No EllesmereUI sub-addons are installed.|r")
    end
end
DynamicSuite.PrintEllesmereConflictBreakdown = addonTable.PrintEllesmereConflictBreakdown

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
        local suiteKey = tostring(conflictAddon) .. "_DynamicSuite"
        local prepKey  = tostring(conflictAddon) .. "_DynamicPrep"
        g.granularModes = type(g.granularModes) == "table" and g.granularModes or {}
        g.granularModes[conflictKey] = "PRIORITISE_DYNAMIC"
        if canonMod == "DynamicPrep" or canonMod == "DynamicSuite" then
            g.granularModes[suiteKey] = "PRIORITISE_DYNAMIC"
            g.granularModes[prepKey]  = "PRIORITISE_DYNAMIC"
            g.acknowledgedConflicts[suiteKey] = "PRIORITISE_DYNAMIC"
            g.acknowledgedConflicts[prepKey]  = "PRIORITISE_DYNAMIC"
        end
        if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.global) == "table" then
            _G.DynamicSuiteDB.global.granularModes = type(_G.DynamicSuiteDB.global.granularModes) == "table" and _G.DynamicSuiteDB.global.granularModes or {}
            _G.DynamicSuiteDB.global.granularModes[conflictKey] = "PRIORITISE_DYNAMIC"
            if canonMod == "DynamicPrep" or canonMod == "DynamicSuite" then
                _G.DynamicSuiteDB.global.granularModes[suiteKey] = "PRIORITISE_DYNAMIC"
                _G.DynamicSuiteDB.global.granularModes[prepKey]  = "PRIORITISE_DYNAMIC"
                _G.DynamicSuiteDB.global.acknowledgedConflicts[suiteKey] = "PRIORITISE_DYNAMIC"
                _G.DynamicSuiteDB.global.acknowledgedConflicts[prepKey]  = "PRIORITISE_DYNAMIC"
            end
        end
        SetSuiteModuleEnabled(canonMod, true, true)
        -- Safely suppress overlapping sub-toggles in Leatrix_Plus / EllesmereUI if accessible
        pcall(function()
            if conflictAddon == "Leatrix_Plus" and type(_G.LeaPlusDB) == "table" then
                if shortKey == "prep" or shortKey == "bags" then
                    _G.LeaPlusDB["AutoRepairGear"] = "Off"
                    _G.LeaPlusDB["AutoSellJunk"] = "Off"
                end
                if shortKey == "prep" or shortKey == "suite" then
                    _G.LeaPlusDB["AutomateGossip"] = "Off"
                elseif shortKey == "zoom" then
                    _G.LeaPlusDB["MaxCameraZoom"] = "Off"
                end
            elseif (conflictAddon == "EllesmereUIQoL" or conflictAddon == "EllesmereUI_QoL") and type(_G.EllesmereUIDB) == "table" then
                if shortKey == "bags" then
                    _G.EllesmereUIDB.autoRepair = false
                    _G.EllesmereUIDB.autoSellJunk = false
                elseif shortKey == "prep" or shortKey == "suite" then
                    _G.EllesmereUIDB.hideErrorMessages = false
                    _G.EllesmereUIDB.autoGossip = false
                elseif shortKey == "group" then
                    _G.EllesmereUIDB.quickSignup = false
                    _G.EllesmereUIDB.autoInsertKeystone = false
                elseif shortKey == "dialogue" then
                    _G.EllesmereUIDB.dialogKeys = false
                end
            end
        end)
        if (shortKey == "prep" or shortKey == "suite") and addonTable.DesktopWindows and type(addonTable.DesktopWindows.ApplyAllWindowStates) == "function" then
            pcall(addonTable.DesktopWindows.ApplyAllWindowStates, addonTable.DesktopWindows)
        elseif shortKey == "zoom" and _G.DynamicZoom and _G.DynamicZoom.ApplyAllSettings then
            pcall(_G.DynamicZoom.ApplyAllSettings, _G.DynamicZoom)
        elseif shortKey == "fps" and _G.DynamicFPS and _G.DynamicFPS.ApplyGraphicsPipeline then
            pcall(_G.DynamicFPS.ApplyGraphicsPipeline, true)
        elseif shortKey == "bags" and type(_G.DynamicBagsDB) == "table" then
            _G.DynamicBagsDB.autoRepair = true
            _G.DynamicBagsDB.autoRepairEnabled = true
            _G.DynamicBagsDB.autoSellJunk = true
            _G.DynamicBagsDB.autoSellGrey = true
        end
        if shortKey == "prep" and _G.DynamicPrep then
            if type(_G.DynamicPrep.SyncErrorFilterState) == "function" then
                pcall(_G.DynamicPrep.SyncErrorFilterState, _G.DynamicPrep, false)
            end
            if type(_G.DynamicPrep.RefreshWorkspaceView) == "function" then
                pcall(_G.DynamicPrep.RefreshWorkspaceView, _G.DynamicPrep)
            end
        elseif shortKey == "group" and _G.DynamicGroup and type(_G.DynamicGroup.RefreshSettingsUI) == "function" then
            pcall(_G.DynamicGroup.RefreshSettingsUI, _G.DynamicGroup)
        end
        print(string.format("%s: Prioritising %s features while keeping %s enabled.", ADDON_TITLE, canonMod, conflictAddon))

    elseif action == "YIELD_TO_EXTERNAL" then
        local suiteKey = tostring(conflictAddon) .. "_DynamicSuite"
        local prepKey  = tostring(conflictAddon) .. "_DynamicPrep"
        g.granularModes = type(g.granularModes) == "table" and g.granularModes or {}
        g.granularModes[conflictKey] = "YIELD_TO_EXTERNAL"
        if canonMod == "DynamicPrep" or canonMod == "DynamicSuite" then
            g.granularModes[suiteKey] = "YIELD_TO_EXTERNAL"
            g.granularModes[prepKey]  = "YIELD_TO_EXTERNAL"
            g.acknowledgedConflicts[suiteKey] = "YIELD_TO_EXTERNAL"
            g.acknowledgedConflicts[prepKey]  = "YIELD_TO_EXTERNAL"
        end
        if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.global) == "table" then
            _G.DynamicSuiteDB.global.granularModes = type(_G.DynamicSuiteDB.global.granularModes) == "table" and _G.DynamicSuiteDB.global.granularModes or {}
            _G.DynamicSuiteDB.global.granularModes[conflictKey] = "YIELD_TO_EXTERNAL"
            if canonMod == "DynamicPrep" or canonMod == "DynamicSuite" then
                _G.DynamicSuiteDB.global.granularModes[suiteKey] = "YIELD_TO_EXTERNAL"
                _G.DynamicSuiteDB.global.granularModes[prepKey]  = "YIELD_TO_EXTERNAL"
                _G.DynamicSuiteDB.global.acknowledgedConflicts[suiteKey] = "YIELD_TO_EXTERNAL"
                _G.DynamicSuiteDB.global.acknowledgedConflicts[prepKey]  = "YIELD_TO_EXTERNAL"
            end
        end
        -- Turn off ONLY overlapping micro-toggles inside DynamicSuite, leaving the rest of the module active
        pcall(function()
            if (shortKey == "prep" or shortKey == "suite") and addonTable.DesktopWindows and type(addonTable.DesktopWindows.ApplyAllWindowStates) == "function" then
                addonTable.DesktopWindows:ApplyAllWindowStates()
            end
            if shortKey == "prep" and type(_G.DynamicPrepDB) == "table" then
                if conflictAddon == "DialogUI" or conflictAddon == "DialogueUI" or conflictAddon == "Plumber" or conflictAddon == "Immersion" or conflictAddon == "Storyline" or conflictAddon == "AutoTurnIn" then
                    _G.DynamicPrepDB.autoGossip = false
                elseif conflictAddon == "EllesmereUIMythicTimer" or conflictAddon == "EllesmereUI_MythicPlus" then
                    _G.DynamicPrepDB.autoKeystone = false
                elseif conflictAddon == "BeQuiet" or conflictAddon == "TalkLess" then
                    _G.DynamicPrepDB.hideTalkingHead = false
                elseif conflictAddon == "ErrorFilter" or conflictAddon == "ErrorMonster" or conflictAddon == "EllesmereUIQoL" or conflictAddon == "EllesmereUI_QoL" then
                    -- Feature-level auto-yield handles error filter / QoL overlaps without touching unrelated toggles
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
        if shortKey == "prep" and _G.DynamicPrep then
            if type(_G.DynamicPrep.SyncErrorFilterState) == "function" then
                pcall(_G.DynamicPrep.SyncErrorFilterState, _G.DynamicPrep, false)
            end
            if type(_G.DynamicPrep.RefreshWorkspaceView) == "function" then
                pcall(_G.DynamicPrep.RefreshWorkspaceView, _G.DynamicPrep)
            end
        elseif shortKey == "group" and _G.DynamicGroup and type(_G.DynamicGroup.RefreshSettingsUI) == "function" then
            pcall(_G.DynamicGroup.RefreshSettingsUI, _G.DynamicGroup)
        end
        print(string.format("%s: Yielded overlapping %s sub-features to %s (other %s features remain active).", ADDON_TITLE, canonMod, conflictAddon, canonMod))

    elseif action == "OUTDOOR_ONLY" then
        local needsReload = SetAddonOutdoorOnlyInDynamicLoad(conflictAddon)
        SetSuiteModuleEnabled(canonMod, true, true)
        InvalidateConflictCache()
        if needsReload then
            addonTable._conflictPendingReload = true
            print(string.format("%s: Configured '%s' for Outdoor Housing only via DynamicLoad (reload UI to unload in this instance).", ADDON_TITLE, conflictAddon))
        else
            print(string.format("%s: Configured '%s' for Outdoor Housing only via DynamicLoad (enabled in Outdoor; disabled in Delves, Dungeons, Raid, and PvP).", ADDON_TITLE, conflictAddon))
        end
    end

    InvalidateConflictCache()

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
-- Shared Media Discovery Hub (LibSharedMedia-3.0, DBM, BigWigs, WeakAuras, ElvUI)
--------------------------------------------------------------------------------
local function IsSafeMediaVal(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return false end
    if type(canaccessvalue) == "function" then
        local ok, canAcc = pcall(canaccessvalue, v)
        if ok and not canAcc then return false end
    end
    return true
end

local function StripWowColorTags(text)
    if not IsSafeMediaVal(text) then return "" end
    local s = tostring(text or "")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    s = s:match("^%s*(.-)%s*$") or ""
    return s
end

local function LooksLikeMediaPath(val)
    if type(val) == "number" then
        return IsSafeMediaVal(val) and val > 0
    end
    if type(val) ~= "string" or not IsSafeMediaVal(val) or val == "" then
        return false
    end
    if val:find("[\\/]") then return true end
    local low = val:lower()
    if low:match("%.wav$") or low:match("%.ogg$") or low:match("%.mp3$") or low:match("%.ttf$") or low:match("%.otf$") then
        return true
    end
    return false
end

local function BuildBlizzardSoundsTable()
    local sk = _G.SOUNDKIT
    return {
        { value = "BLIZZ_RAID_WARNING",   label = "Blizzard Raid Warning",   soundKit = (sk and sk.RAID_WARNING) or 8959,          fileDataID = 567397, group = "BLIZZARD", source = "Blizzard" },
        { value = "BLIZZ_WHISPER",        label = "Blizzard Whisper",        soundKit = (sk and sk.TELL_MESSAGE) or 3081,          fileDataID = 567482, group = "BLIZZARD", source = "Blizzard" },
        { value = "BLIZZ_BNET_TOAST",     label = "Blizzard Battle.net",     soundKit = (sk and sk.UI_BNET_TOAST) or 18019,        fileDataID = 567421, group = "BLIZZARD", source = "Blizzard" },
        { value = "BLIZZ_READY_CHECK",    label = "Blizzard Ready Check",    soundKit = (sk and sk.READY_CHECK) or 8960,           fileDataID = 567478, group = "BLIZZARD", source = "Blizzard" },
        { value = "BLIZZ_MAP_PING",       label = "Blizzard Map Ping",       soundKit = (sk and sk.MAP_PING) or 3175,              fileDataID = 567416, group = "BLIZZARD", source = "Blizzard" },
        { value = "BLIZZ_AUCTION_BELL",   label = "Blizzard Auction Bell",   soundKit = (sk and sk.AUCTION_WINDOW_OPEN) or 5274,   fileDataID = 567499, group = "BLIZZARD", source = "Blizzard" },
        { value = "BLIZZ_QUEST_COMPLETE", label = "Blizzard Quest Complete", soundKit = (sk and sk.IG_QUEST_LIST_COMPLETE) or 878, fileDataID = 567439, group = "BLIZZARD", source = "Blizzard" },
    }
end

local mediaRegistry = {
    scannedOnce = false,
    sounds = { builtin = {}, blizzard = {}, external = {}, byKey = {} },
    fonts  = { external = {}, byKey = {} },
}

local function GetLSMInstance()
    if type(_G.LibStub) == "function" or (type(_G.LibStub) == "table") then
        local ok, lsm = pcall(_G.LibStub, "LibSharedMedia-3.0", true)
        if ok and type(lsm) == "table" then
            return lsm
        end
    end
    if type(_G.ElvUI) == "table" and type(_G.ElvUI[1]) == "table" then
        local E = _G.ElvUI[1]
        if type(E.Libs) == "table" and type(E.Libs.LSM) == "table" then
            return E.Libs.LSM
        end
    end
    return nil
end

local function FormatExternalLabel(cleanName, sourceTag)
    if sourceTag and sourceTag ~= "" and sourceTag ~= "SharedMedia" then
        local lowName = cleanName:lower()
        local lowTag = sourceTag:lower()
        if not lowName:find(lowTag, 1, true) then
            return sourceTag .. ": " .. cleanName
        end
    end
    return cleanName
end

local function ScanMediaKind(kind, skipNames, skipPaths)
    local outList = {}
    local seenKeys = {}
    local seenPaths = {}
    local seenLabels = {}

    if type(skipPaths) == "table" then
        for p, v in pairs(skipPaths) do
            seenPaths[p] = v
        end
    end

    local function AddCandidate(prefix, rawName, rawPath, sourceTag)
        local cleanName = StripWowColorTags(rawName)
        if cleanName == "" or cleanName:lower() == "none" or cleanName:lower() == "custom" then
            return
        end
        if type(skipNames) == "table" and skipNames[cleanName:lower()] then
            return
        end
        if not IsSafeMediaVal(rawPath) or rawPath == "" then
            return
        end
        local normPathKey = (type(rawPath) == "number") and ("fid:" .. tostring(rawPath)) or tostring(rawPath):lower():gsub("/", "\\")
        if normPathKey == "interface\\quiet.ogg" then
            return
        end
        if seenPaths[normPathKey] then
            return
        end
        local key = prefix .. ":" .. cleanName
        if seenKeys[key] then
            return
        end
        local displayLabel = FormatExternalLabel(cleanName, sourceTag)
        local lowLbl = displayLabel:lower()
        if seenLabels[lowLbl] then
            return
        end

        seenKeys[key] = true
        seenPaths[normPathKey] = true
        seenLabels[lowLbl] = true

        local entry = {
            value  = key,
            name   = cleanName,
            label  = displayLabel,
            path   = rawPath,
            source = sourceTag or "SharedMedia",
            group  = "EXTERNAL",
        }
        if type(rawPath) == "number" then
            entry.fileDataID = rawPath
        end
        table.insert(outList, entry)
    end

    -- 1. LibSharedMedia-3.0 (covers SharedMedia packs, BigWigs, DBM-LSM, WeakAuras-LSM, ElvUI-LSM)
    local lsm = GetLSMInstance()
    if lsm then
        if type(lsm.HashTable) == "function" then
            local okH, hTbl = pcall(lsm.HashTable, lsm, kind)
            if okH and type(hTbl) == "table" then
                for kName, kPath in pairs(hTbl) do
                    if type(kName) == "string" then
                        AddCandidate("LSM", kName, kPath, "SharedMedia")
                    end
                end
            end
        end
        if type(lsm.List) == "function" and type(lsm.Fetch) == "function" then
            local okL, lNames = pcall(lsm.List, lsm, kind)
            if okL and type(lNames) == "table" then
                for _, lName in ipairs(lNames) do
                    if type(lName) == "string" then
                        local okF, fPath = pcall(lsm.Fetch, lsm, kind, lName, true)
                        if okF and fPath then
                            AddCandidate("LSM", lName, fPath, "SharedMedia")
                        end
                    end
                end
            end
        end
    end

    -- 2. Deadly Boss Mods (DBM)
    local dbm = _G.DBM
    if type(dbm) == "table" then
        local dbmTables = {}
        if kind == "sound" then
            if type(dbm.Sounds) == "table" then table.insert(dbmTables, dbm.Sounds) end
            if type(dbm.Sound) == "table" then table.insert(dbmTables, dbm.Sound) end
            if type(dbm.GetSoundList) == "function" then
                local okD, dList = pcall(dbm.GetSoundList, dbm)
                if okD and type(dList) == "table" then table.insert(dbmTables, dList) end
            end
        elseif kind == "font" then
            if type(dbm.Fonts) == "table" then table.insert(dbmTables, dbm.Fonts) end
            if type(dbm.Font) == "table" then table.insert(dbmTables, dbm.Font) end
        end
        for _, tbl in ipairs(dbmTables) do
            for k, v in pairs(tbl) do
                if type(v) == "table" then
                    local nm = v.text or v.name or v.label or (type(k) == "string" and k) or nil
                    local p = v.value or v.path or v.sound or v.font
                    if nm and p and LooksLikeMediaPath(p) then
                        AddCandidate("DBM", tostring(nm), p, "DBM")
                    end
                elseif IsSafeMediaVal(k) and IsSafeMediaVal(v) then
                    if type(k) == "string" and LooksLikeMediaPath(v) then
                        AddCandidate("DBM", k, v, "DBM")
                    elseif type(v) == "string" and LooksLikeMediaPath(k) then
                        AddCandidate("DBM", v, k, "DBM")
                    end
                end
            end
        end
    end

    -- 3. BigWigs
    if kind == "sound" then
        local bwTables = {}
        if type(_G.BigWigs) == "table" and type(_G.BigWigs.Sounds) == "table" then table.insert(bwTables, _G.BigWigs.Sounds) end
        if type(_G.BigWigsLoader) == "table" and type(_G.BigWigsLoader.Sounds) == "table" then table.insert(bwTables, _G.BigWigsLoader.Sounds) end
        if type(_G.BigWigsAPI) == "table" then
            if type(_G.BigWigsAPI.GetCountdownList) == "function" then
                local okC, cTbl = pcall(_G.BigWigsAPI.GetCountdownList, _G.BigWigsAPI)
                if okC and type(cTbl) == "table" then
                    for k, v in pairs(cTbl) do
                        if type(k) == "string" and LooksLikeMediaPath(v) then
                            AddCandidate("BW", k, v, "BigWigs")
                        end
                    end
                end
            end
        end
        for _, tbl in ipairs(bwTables) do
            for k, v in pairs(tbl) do
                if type(k) == "string" and LooksLikeMediaPath(v) then
                    AddCandidate("BW", k, v, "BigWigs")
                elseif type(v) == "string" and LooksLikeMediaPath(k) then
                    AddCandidate("BW", v, k, "BigWigs")
                end
            end
        end
    end

    -- 4. WeakAuras
    local wa = _G.WeakAuras
    if type(wa) == "table" then
        local waTbl = (kind == "sound" and wa.sound_types) or (kind == "font" and wa.font_types) or nil
        if type(waTbl) == "table" then
            for k, v in pairs(waTbl) do
                if IsSafeMediaVal(k) and IsSafeMediaVal(v) then
                    if LooksLikeMediaPath(k) and type(v) == "string" then
                        AddCandidate("WA", v, k, "WeakAuras")
                    elseif type(k) == "string" and LooksLikeMediaPath(v) then
                        AddCandidate("WA", k, v, "WeakAuras")
                    end
                end
            end
        end
    end

    -- 5. ElvUI
    if type(_G.ElvUI) == "table" and type(_G.ElvUI[1]) == "table" and type(_G.ElvUI[1].media) == "table" then
        local mediaTbl = _G.ElvUI[1].media
        for k, v in pairs(mediaTbl) do
            if type(k) == "string" and LooksLikeMediaPath(v) and type(v) == "string" then
                local vLow = v:lower()
                if kind == "sound" and (k:lower():find("sound", 1, true) or vLow:match("%.ogg$") or vLow:match("%.mp3$") or vLow:match("%.wav$")) then
                    AddCandidate("ELV", k, v, "ElvUI")
                elseif kind == "font" and (k:lower():find("font", 1, true) or vLow:match("%.ttf$") or vLow:match("%.otf$")) and not k:lower():find("blank", 1, true) then
                    AddCandidate("ELV", k, v, "ElvUI")
                end
            end
        end
    end

    -- 6. EXBOSS / EX_Boss standalone tables (in addition to LibSharedMedia-3.0)
    for _, globalKey in ipairs({ "EXBOSS", "EX_Boss", "ExBoss" }) do
        local ex = _G[globalKey]
        if type(ex) == "table" then
            local sub = (kind == "sound" and (ex.Sounds or ex.sounds or ex.Sound)) or (kind == "font" and (ex.Fonts or ex.fonts or ex.Font)) or nil
            if type(sub) == "table" then
                for k, v in pairs(sub) do
                    if IsSafeMediaVal(k) and IsSafeMediaVal(v) then
                        if type(k) == "string" and LooksLikeMediaPath(v) then
                            AddCandidate("EXBOSS", k, v, "EXBOSS")
                        elseif type(v) == "string" and LooksLikeMediaPath(k) then
                            AddCandidate("EXBOSS", v, k, "EXBOSS")
                        end
                    end
                end
            end
        end
    end

    table.sort(outList, function(a, b)
        return tostring(a.label):lower() < tostring(b.label):lower()
    end)
    return outList
end

local function BuildSuiteChimesTable()
    local base = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Sounds\\"
    local defs = {
        { value = "DC_CHIME_SPARK",   name = "Spark",   label = "DynamicSuite: Spark (High Pluck)",     file = "DynamicChat_ChimeSpark.ogg" },
        { value = "DC_KEYWORD_PULSE", name = "Pulse",   label = "DynamicSuite: Pulse (Warm Bell)",      file = "DynamicChat_KeywordPulse.ogg" },
        { value = "DC_CHIME_DUO",     name = "Duo",     label = "DynamicSuite: Duo (Rising Fifth)",     file = "DynamicChat_ChimeDuo.ogg" },
        { value = "DC_CHIME_CASCADE", name = "Cascade", label = "DynamicSuite: Cascade (Crystal Harp)", file = "DynamicChat_MentionWarm.ogg" },
        { value = "DC_CHIME_ECHO",    name = "Echo",    label = "DynamicSuite: Echo (Glass Ping)",      file = "DynamicChat_ChimeEcho.ogg" },
        { value = "DC_CHIME_FOURTH",  name = "Chime",   label = "DynamicSuite: Chime (Rising Fourth)",  file = "DynamicChat_ChimeFourth.ogg" },
        { value = "DC_CHIME_BLOOM",   name = "Bloom",   label = "DynamicSuite: Bloom (Major Ninth)",    file = "DynamicChat_ChimeBloom.ogg" },
        { value = "DC_CHIME_DEWDROP", name = "Dewdrop", label = "DynamicSuite: Dewdrop (Low Bell)",     file = "DynamicChat_ChimeDewdrop.ogg" },
        { value = "DC_CHIME_RIPPLE",  name = "Ripple",  label = "DynamicSuite: Ripple (Grace Flick)",   file = "DynamicChat_ChimeRipple.ogg" },
        { value = "DC_CHIME_PRISM",   name = "Prism",   label = "DynamicSuite: Prism (Falling Triad)",  file = "DynamicChat_ChimePrism.ogg" },
    }
    local out = {}
    for _, d in ipairs(defs) do
        out[#out + 1] = {
            value  = d.value,
            name   = d.name,
            label  = d.label,
            path   = base .. d.file,
            source = "DynamicSuite",
            group  = "BUILTIN",
        }
    end
    return out
end

function DynamicSuite:ScanExternalMedia(force)
    if mediaRegistry.scannedOnce and not force then
        return mediaRegistry
    end

    -- Sounds (never register .wav files with LibSharedMedia-3.0; Blizzard built-ins + external LSM/DBM/EXBOSS/BigWigs/WeakAuras/ElvUI)
    local sReg = { builtin = {}, blizzard = {}, external = {}, byKey = {} }
    local skipSoundNames = {}
    local skipSoundPaths = {}

    for _, cDef in ipairs(BuildSuiteChimesTable()) do
        table.insert(sReg.builtin, cDef)
        sReg.byKey[cDef.value] = cDef
    end

    for _, bDef in ipairs(BuildBlizzardSoundsTable()) do
        table.insert(sReg.blizzard, bDef)
        sReg.byKey[bDef.value] = bDef
    end

    sReg.external = ScanMediaKind("sound", skipSoundNames, skipSoundPaths)
    for _, ext in ipairs(sReg.external) do
        sReg.byKey[ext.value] = ext
        if ext.name and not sReg.byKey[ext.name] then
            sReg.byKey[ext.name] = ext
        end
    end
    mediaRegistry.sounds = sReg

    -- Fonts
    local fReg = { external = {}, byKey = {} }
    local skipFontPaths = {}
    skipFontPaths["fonts\\frizqt__.ttf"] = true
    skipFontPaths["fonts\\2002.ttf"] = true
    skipFontPaths["fonts\\2002b.ttf"] = true
    skipFontPaths["fonts\\morpheus.ttf"] = true
    skipFontPaths["fonts\\skurri.ttf"] = true
    skipFontPaths["fonts\\arialn.ttf"] = true

    fReg.external = ScanMediaKind("font", nil, skipFontPaths)
    for _, ext in ipairs(fReg.external) do
        fReg.byKey[ext.value] = ext
        if ext.name and not fReg.byKey[ext.name] then
            fReg.byKey[ext.name] = ext
        end
    end
    mediaRegistry.fonts = fReg
    mediaRegistry.scannedOnce = true
    return mediaRegistry
end

function DynamicSuite:GetSharedSounds(force)
    if force or not mediaRegistry.scannedOnce then
        self:ScanExternalMedia(force)
    end
    return mediaRegistry.sounds
end

function DynamicSuite:GetSharedFonts(force)
    if force or not mediaRegistry.scannedOnce then
        self:ScanExternalMedia(force)
    end
    return mediaRegistry.fonts
end

function DynamicSuite:ResolveSoundChoice(soundKey, fallbackKey)
    if not soundKey or soundKey == "" or soundKey == "NONE" then
        return nil, false
    end
    local sReg = self:GetSharedSounds(false)
    local hit = sReg.byKey[soundKey]
    if not hit then
        -- Try one fresh scan in case an addon loaded on demand
        sReg = self:GetSharedSounds(true)
        hit = sReg.byKey[soundKey]
    end
    if not hit and type(soundKey) == "string" then
        local stripped = soundKey:gsub("^LSM:", ""):gsub("^DBM:", ""):gsub("^BW:", ""):gsub("^WA:", ""):gsub("^ELV:", ""):gsub("^EXBOSS:", "")
        hit = sReg.byKey[stripped]
    end
    if not hit and LooksLikeMediaPath(soundKey) then
        -- Check whether the direct path is from a known loaded external source or still registered
        for _, ext in ipairs(sReg.external) do
            if ext.path == soundKey then
                hit = ext
                break
            end
        end
    end
    if hit then
        return hit, false
    end
    -- Safe Fallback to Blizzard Raid Warning when a saved external sound is unavailable
    local fb = sReg.byKey[fallbackKey or "BLIZZ_RAID_WARNING"] or sReg.blizzard[1]
    return fb, true
end

function DynamicSuite:ResolveFontChoice(fontKey)
    if type(self.UI) == "table" and type(self.UI.GetFont) == "function" then
        local ok, p, entry = pcall(self.UI.GetFont, fontKey)
        if ok and type(p) == "string" and p ~= "" then
            return p, entry, false
        end
    end
    local fReg = self:GetSharedFonts(false)
    if fontKey and fReg.byKey[fontKey] then
        return fReg.byKey[fontKey].path, fReg.byKey[fontKey], false
    end
    return "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.TTF", nil, true
end

addonTable.ScanExternalMedia = function(force) return DynamicSuite:ScanExternalMedia(force) end
addonTable.GetSharedSounds   = function(force) return DynamicSuite:GetSharedSounds(force) end
addonTable.GetSharedFonts    = function(force) return DynamicSuite:GetSharedFonts(force) end
addonTable.ResolveSoundChoice = function(key, fb) return DynamicSuite:ResolveSoundChoice(key, fb) end
addonTable.ResolveFontChoice  = function(key) return DynamicSuite:ResolveFontChoice(key) end

--------------------------------------------------------------------------------
-- Extensible Module Registration & Suite Reset Engine
--------------------------------------------------------------------------------
function addonTable.ResetDynamicSuite()
    if addonTable.DesktopWindows and type(addonTable.DesktopWindows.ResetAllWindows) == "function" then
        pcall(addonTable.DesktopWindows.ResetAllWindows, addonTable.DesktopWindows, true)
    end
    local preservedSnapshots = (_G.DynamicSuiteDB and type(_G.DynamicSuiteDB.global) == "table" and type(_G.DynamicSuiteDB.global.cvarSnapshots) == "table")
        and _G.DynamicSuiteDB.global.cvarSnapshots or nil
    _G.DynamicSuiteDB = {
        global = CopyTable(DEFAULT_SUITE_GLOBAL)
    }
    _G.DynamicSuiteDB.global.desktopWindows = CopyTable(addonTable.DEFAULT_DESKTOP_WINDOWS)
    _G.DynamicSuiteDB.global.desktopWindows.migratedFromPrep = true
    if type(_G.DynamicPrepDB) == "table" then
        _G.DynamicPrepDB.windowPositions = {}
        _G.DynamicPrepDB.windowScales = {}
        _G.DynamicPrepDB.blizzWinNoAutoClose = true
        _G.DynamicPrepDB.blizzWinDraggable = true
        _G.DynamicPrepDB.blizzWinScrollScale = true
    end
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
    if addonTable.DesktopWindows and type(addonTable.DesktopWindows.ApplyAllWindowStates) == "function" then
        pcall(addonTable.DesktopWindows.ApplyAllWindowStates, addonTable.DesktopWindows)
    end
    if addonTable.ApplySuiteThemeAndGeometry then
        addonTable.ApplySuiteThemeAndGeometry()
    end
    print(string.format("%s: Entire DynamicSuite configuration (Theme, Desktop Windows, Window Geometry, HUDs, and Profiles) reset to factory defaults.", ADDON_TITLE))
end
addonTable.ResetAllSuiteDefaults = addonTable.ResetDynamicSuite
DynamicSuite.ResetAllSuiteDefaults = addonTable.ResetDynamicSuite

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
    local shortKey = tostring(modKey):lower():gsub("^dynamic", "")
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
    cursor        = "DynamicCursor",
    DynamicCursor = "DynamicCursor",
    zoom          = "DynamicZoom",
    DynamicZoom   = "DynamicZoom",
    fps           = "DynamicFPS",
    DynamicFPS    = "DynamicFPS",
    prep          = "DynamicPrep",
    DynamicPrep   = "DynamicPrep",
    talent        = "DynamicTalent",
    DynamicTalent = "DynamicTalent",
    group         = "DynamicGroup",
    DynamicGroup  = "DynamicGroup",
    bags          = "DynamicBags",
    DynamicBags   = "DynamicBags",
    chat          = "DynamicChat",
    DynamicChat   = "DynamicChat",
    mail            = "DynamicMail",
    DynamicMail     = "DynamicMail",
    vault           = "DynamicVault",
    DynamicVault    = "DynamicVault",
    dialogue        = "DynamicDialogue",
    DynamicDialogue = "DynamicDialogue",
    STUDIO          = "DynamicSuite",
    SETUP         = "DynamicSuite",
    HUD           = "DynamicSuite",
    DynamicSuite  = "DynamicSuite",
}
addonTable.MODULE_ADDON_MAP = MODULE_ADDON_MAP
DynamicSuite.MODULE_ADDON_MAP = MODULE_ADDON_MAP

local MODULE_META_BY_KEY = {
    load   = { addonName = "DynamicLoad",   moduleTitle = "DynamicLoad",   slash = "/dl",     icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_load.tga" },
    marker = { addonName = "DynamicMarker", moduleTitle = "DynamicMarker", slash = "/dm",     icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_marker.tga" },
    cursor = { addonName = "DynamicCursor", moduleTitle = "DynamicCursor", slash = "/dcur",   icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_cursor.tga" },
    zoom   = { addonName = "DynamicZoom",   moduleTitle = "DynamicZoom",   slash = "/dz",     icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_zoom.tga" },
    fps    = { addonName = "DynamicFPS",    moduleTitle = "DynamicFPS",    slash = "/dfps",   icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_fps.tga" },
    prep   = { addonName = "DynamicPrep",   moduleTitle = "DynamicPrep",   slash = "/dprep",  icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_prep.tga" },
    talent = { addonName = "DynamicTalent", moduleTitle = "DynamicTalent", slash = "/dt",     icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_talent.tga" },
    group  = { addonName = "DynamicGroup",  moduleTitle = "DynamicGroup",  slash = "/dgroup", icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_group.tga" },
    bags   = { addonName = "DynamicBags",   moduleTitle = "DynamicBags",   slash = "/dbag",   icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_bags.tga" },
    chat   = { addonName = "DynamicChat",   moduleTitle = "DynamicChat",   slash = "/dchat",  icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_chat.tga" },
    mail     = { addonName = "DynamicMail",     moduleTitle = "DynamicMail",     slash = "/dmail",  icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_mail.tga" },
    vault    = { addonName = "DynamicVault",    moduleTitle = "DynamicVault",    slash = "/dv",     icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_vault.tga" },
    dialogue = { addonName = "DynamicDialogue", moduleTitle = "DynamicDialogue", slash = "/dd",     icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_dialogue.tga" },
    STUDIO   = { addonName = "DynamicSuite",    moduleTitle = "Suite Studio",    slash = "/ds studio", icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_palette.tga" },
    SETUP  = { addonName = "DynamicSuite",  moduleTitle = "Guided Setup",  slash = "/ds",     icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_spark.tga" },
    HUD    = { addonName = "DynamicSuite",  moduleTitle = "HUD Edit Mode", slash = "/ds hud", icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_grid.tga" },
}
addonTable.MODULE_META_BY_KEY = MODULE_META_BY_KEY

local searchSeedOrderCounter = 0

local function NormalizeSearchEntry(moduleKey, rawEntry)
    if type(rawEntry) ~= "table" or not rawEntry.title or rawEntry.title == "" then return nil end
    local mKey = rawEntry.moduleKey or moduleKey or "STUDIO"
    local rawKeyStr = tostring(mKey)
    local upperKey = rawKeyStr:upper()
    if upperKey == "STUDIO" or upperKey == "SETUP" or upperKey == "HUD" then
        mKey = upperKey
    end
    local meta = MODULE_META_BY_KEY[mKey]
    if not meta then
        local shortKey = rawKeyStr:lower():gsub("^dynamic", "")
        if MODULE_META_BY_KEY[shortKey] then
            mKey = shortKey
            meta = MODULE_META_BY_KEY[shortKey]
        else
            meta = {
                addonName   = rawEntry.addonName or ("Dynamic" .. shortKey:sub(1, 1):upper() .. shortKey:sub(2)),
                moduleTitle = rawEntry.moduleTitle or rawKeyStr,
                slash       = rawEntry.slash or ("/" .. shortKey),
                icon        = rawEntry.icon or ("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_load.tga"),
            }
        end
    end

    local addonNameKey = rawEntry.addonName or meta.addonName or "DynamicSuite"
    local modTitle     = rawEntry.moduleTitle or meta.moduleTitle or addonNameKey
    local tabIdx       = rawEntry.tabIndex or 1
    local tabLbl       = rawEntry.tabLabel or rawEntry.tabName or rawEntry.breadcrumb or "General"
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
        tabName         = tabLbl,
        tabLabel        = tabLbl,
        breadcrumb      = tabLbl,
        viewKey         = resolvedView,
        title           = titleStr,
        highlightTitle  = targetStr,
        targetTitle     = targetStr,
        desc            = descStr,
        keywords        = kwStr,
        isSubDrawer     = rawEntry.isSubDrawer == true,
        drawerKey       = rawEntry.drawerKey,
        hudTarget       = rawEntry.hudTarget,
        subMode         = rawEntry.subMode,
        openManager     = rawEntry.openManager == true or nil,
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
                local existing = SEARCH_REGISTRY[existingIdx]
                if not raw.category and existing.category then
                    norm.category = existing.category
                    norm.categoryLabel = existing.categoryLabel
                    norm._catLower = existing._catLower
                end
                if not raw.tabLabel and not raw.tabName and not raw.breadcrumb and existing.tabLabel then
                    norm.tabLabel = existing.tabLabel
                    norm.tabName = existing.tabName
                    norm.breadcrumb = existing.breadcrumb
                    norm._tabLower = existing._tabLower
                    norm._crumbLower = existing._crumbLower
                end
                if not raw.highlightTitle and not raw.targetTitle then
                    if existing.highlightTitle and existing.highlightTitle ~= "" then
                        norm.highlightTitle = existing.highlightTitle
                    end
                    if existing.targetTitle and existing.targetTitle ~= "" then
                        norm.targetTitle = existing.targetTitle
                    end
                end
                if existing.keywords and existing.keywords ~= "" then
                    local mergedList = {}
                    local seenTok = {}
                    local function addKwTokens(str)
                        if type(str) ~= "string" or str == "" then return end
                        for tok in str:gmatch("%S+") do
                            local tokL = tok:lower()
                            if not seenTok[tokL] then
                                seenTok[tokL] = true
                                mergedList[#mergedList + 1] = tok
                            end
                        end
                    end
                    addKwTokens(existing.keywords)
                    addKwTokens(norm.keywords)
                    if #mergedList > 0 then
                        local mergedKw = table.concat(mergedList, " ")
                        norm.keywords = mergedKw
                        norm._kwLower = mergedKw:lower()
                        norm._keywordsLower = norm._kwLower
                    end
                end
                if existing.seedOrder then
                    norm.seedOrder = existing.seedOrder
                end
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
    if not addonNameKey or addonNameKey == "DynamicSuite" or tostring(addonNameKey):lower() == "dynamicsuite" then
        return true
    end
    local canonMod, shortKey = NormalizeSuiteModuleId(addonNameKey)
    if _G.DynamicSuite and _G.DynamicSuite.modules and (
        _G.DynamicSuite.modules[addonNameKey] ~= nil
        or _G.DynamicSuite.modules[canonMod] ~= nil
        or _G.DynamicSuite.modules[shortKey] ~= nil
    ) then
        return true
    end
    if canonMod == "DynamicLoad" then
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
    if _G[canonMod] ~= nil or _G[addonNameKey] ~= nil then
        return true
    end
    if C_AddOns and C_AddOns.GetAddOnInfo then
        local aName, _, _, _, aReason = C_AddOns.GetAddOnInfo(canonMod)
        if aName ~= nil and aReason ~= "MISSING" then
            return true
        end
        if canonMod ~= addonNameKey then
            local fName, _, _, _, fReason = C_AddOns.GetAddOnInfo(addonNameKey)
            if fName ~= nil and fReason ~= "MISSING" then
                return true
            end
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
    local shortKey = tostring(addonNameKey):lower():gsub("^dynamic", "")
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

-- Seed comprehensive built-in search metadata covering DynamicSuite & all 12 peer modules
local BUILTIN_SEARCH_SEED = {
    -- ========================================================================
    -- DYNAMICSUITE: SUITE STUDIO ("STUDIO" Tab 1 & Tab 2), GUIDED SETUP ("SETUP"), HUD ("HUD")
    -- ========================================================================
    { moduleKey = "STUDIO", category = "HUD_LOOK", viewKey = "THEME_STUDIO", tabIndex = 1, tabName = "Theme & Typography", tabLabel = "Theme & Typography", slash = "/ds theme",
      title = "ACCENT COLOUR PRESETS & CUSTOM PALETTE", highlightTitle = "ACCENT COLOUR PRESETS & CUSTOM PALETTE",
      desc = "Choose from 17 curated accent swatches, auto-match your class colour, or pick a custom hex colour.",
      keywords = "accent colour color theme palette swatch class colour hex custom picker tint border" },
    { moduleKey = "STUDIO", category = "HUD_LOOK", viewKey = "THEME_STUDIO", tabIndex = 1, tabName = "Theme & Typography", tabLabel = "Theme & Typography", slash = "/ds theme",
      title = "Window Surface Theme",
      desc = "Select the Obsidian backdrop palette across all DynamicSuite windows (Midnight Pitch Black, Obsidian Dark, Slate Steel, Smoked Glass).",
      keywords = "surface theme dark mode background midnight black obsidian slate steel smoked glass translucent backdrop" },
    { moduleKey = "STUDIO", category = "HUD_LOOK", viewKey = "THEME_STUDIO", tabIndex = 1, tabName = "Theme & Typography", tabLabel = "Theme & Typography", slash = "/ds theme",
      title = "Suite Font Family",
      desc = "Select the typography family applied across headers, lists, and HUD readouts (Built-in, Blizzard, LibSharedMedia, DBM, ElvUI, WeakAuras).",
      keywords = "font family typeface text typography expressway friz quadrata arialn morpheus skurri sharedmedia dbm elvui weakauras addons search" },
    { moduleKey = "STUDIO", category = "HUD_LOOK", viewKey = "THEME_STUDIO", tabIndex = 1, tabName = "Theme & Typography", tabLabel = "Theme & Typography", slash = "/ds theme",
      title = "Sync Font & Palette with Installed UI",
      desc = "Automatically inherit typography and accent colours from EllesmereUI, ElvUI, or LibSharedMedia.",
      keywords = "sync external ui ellesmereui eui elvui sharedmedia match theme font" },
    { moduleKey = "STUDIO", category = "HUD_LOOK", viewKey = "THEME_STUDIO", tabIndex = 1, tabName = "Theme & Typography", tabLabel = "Theme & Typography", slash = "/ds theme",
      title = "Sync Theme & Font to On-Screen HUD Bars",
      desc = "Automatically apply the active Suite Accent Colour, Surface Theme, and Font Family to all HUD bars.",
      keywords = "sync hud bars toast prep bar focus bar flare bar theme colour font" },
    { moduleKey = "STUDIO", category = "HUD_LOOK", viewKey = "THEME_STUDIO", tabIndex = 1, tabName = "Theme & Typography", tabLabel = "Theme & Typography", slash = "/ds theme",
      title = "Preserve Window Size, Scale & Layout Across All Characters",
      desc = "Share your custom window dimensions, UI scale, and HUD bar coordinates across every character.",
      keywords = "account wide alt sync window size scale layout position coordinates share" },
    { moduleKey = "STUDIO", category = "HUD_LOOK", viewKey = "THEME_STUDIO", tabIndex = 1, tabName = "Theme & Typography", tabLabel = "Theme & Typography", slash = "/ds theme",
      title = "Active Control Fill Intensity",
      desc = "Adjust the colour fill strength of selected tabs, pills, and switches (24% Subtle, 32% Balanced, 42% Bold).",
      keywords = "fill intensity alpha pill button brightness subtle balanced bold contrast" },
    { moduleKey = "STUDIO", category = "HUD_LOOK", viewKey = "DESKTOP_WINDOWS", tabIndex = 2, tabName = "Desktop Windows & Menus", tabLabel = "Desktop Windows & Menus", slash = "/ds windows",
      title = "Keep Blizzard Windows Open Side-by-Side", highlightTitle = "Keep Blizzard Windows Open Side-by-Side",
      desc = "Keep all 33 standard Blizzard panels (including Character, Talents & Spells, Professions, Collections, Omnium Folio, Auction House, and windowed Quest Log / World Map 'L') open side-by-side without auto-closing, with click-to-raise z-order and top-most Escape dismissal.",
      keywords = "blizzard desktop window manager multi panel no auto close side by side quest log worldmapframe world map l talents playerspellsframe character pve merchant mail auction omnium folio generictraitframe expansionlandingpage escape click to raise z-order /ds windows /ds win" },
    { moduleKey = "STUDIO", category = "HUD_LOOK", viewKey = "DESKTOP_WINDOWS", tabIndex = 2, tabName = "Desktop Windows & Menus", tabLabel = "Desktop Windows & Menus", slash = "/ds windows",
      title = "Drag Blizzard Windows Anywhere (Save Position)", highlightTitle = "Drag Blizzard Windows Anywhere (Save Position)",
      desc = "Left-Click and drag any managed Blizzard window from its title bar or any empty background space (no Alt key needed), automatically clamped on-screen and saved across sessions (Right-Click title bar to reset).",
      keywords = "drag blizzard windows anywhere move save position empty space no alt left drag clamped on screen clamp right click header reset omnium folio generictraitframe expansionlandingpage /ds windows /ds win" },
    { moduleKey = "STUDIO", category = "HUD_LOOK", viewKey = "DESKTOP_WINDOWS", tabIndex = 2, tabName = "Desktop Windows & Menus", tabLabel = "Desktop Windows & Menus", slash = "/ds windows",
      title = "Window Ctrl+Scroll Scaling", highlightTitle = "Window Ctrl+Scroll Scaling",
      desc = "Hold Ctrl + Mousewheel on a Blizzard window header for temporary session scaling (70% to 140% in 5% steps), or Ctrl + Shift + Mousewheel anywhere on a window to save permanent scale.",
      keywords = "window ctrl scroll scaling wheel resize zoom 70% 140% session permanent scale blizzard panel /ds windows /ds win" },
    { moduleKey = "STUDIO", category = "HUD_LOOK", viewKey = "DESKTOP_WINDOWS", tabIndex = 2, tabName = "Desktop Windows & Menus", tabLabel = "Desktop Windows & Menus", slash = "/ds windows",
      title = "Reset Blizzard Window Layout", highlightTitle = "Reset Blizzard Window Layout",
      desc = "Restore all 33 managed Blizzard windows (including Omnium Folio and windowed Quest Log / World Map) to their default 100% scale and centred positions, with automatic silent yield when BlizzMove, NoAutoClose, DeModal, MoveAny, or EllesmereUI is active.",
      keywords = "reset blizzard window layout reset all windows default 100% scale position blizzmove noautoclose demodal moveany ellesmereui shifter leatrix elvui coexistence /ds windows /ds win" },
    { moduleKey = "STUDIO", category = "BAGS_QOL", viewKey = "DESKTOP_WINDOWS", tabIndex = 2, tabName = "Desktop Windows & Menus", tabLabel = "Desktop Windows & Menus", slash = "/ds windows",
      title = "Game Menu: DynamicSuite Button",
      desc = "Show or hide the 'DynamicSuite' shortcut button inside the Esc Game Menu.",
      keywords = "game menu esc escape button shortcut dynamicsuite hide show" },
    { moduleKey = "STUDIO", category = "HUD_LOOK", viewKey = "DESKTOP_WINDOWS", tabIndex = 2, tabName = "Desktop Windows & Menus", tabLabel = "Desktop Windows & Menus", slash = "/ds windows",
      title = "Game Menu: DynamicSuite HUD Button",
      desc = "Show or hide the 'DynamicSuite HUD' button in the Esc Game Menu to unlock and move suite bars.",
      keywords = "game menu esc escape hud edit mode button shortcut move bars" },
    { moduleKey = "STUDIO", category = "BAGS_QOL", viewKey = "DESKTOP_WINDOWS", tabIndex = 2, tabName = "Desktop Windows & Menus", tabLabel = "Desktop Windows & Menus", slash = "/ds windows",
      title = "Replace Blizzard AddOns Button",
      desc = "Open DynamicSuite instead of Blizzard's default AddOn list when clicking 'AddOns' in the Esc menu.",
      keywords = "replace blizzard addons list esc menu button intercept default addon list" },
    { moduleKey = "STUDIO", category = "BAGS_QOL", viewKey = "DESKTOP_WINDOWS", tabIndex = 2, tabName = "Desktop Windows & Menus", tabLabel = "Desktop Windows & Menus", slash = "/ds spotlight",
      title = "Show Major Feature Spotlights",
      desc = "Show a one-time summary modal after login when DynamicSuite adds a major new module or feature.",
      keywords = "show major feature spotlights new module modal login preview reset /ds spotlight" },

    -- Guided Setup & Conflict Scanner + Quick Guide
    { moduleKey = "SETUP", category = "BAGS_QOL", viewKey = "GUIDED_SETUP", tabIndex = 1, tabName = "1. Style", tabLabel = "3-Step Quick Start (/ds setup)",
      title = "3-Step Quick Start: Theme, Conflicts & Active Modules",
      desc = "Customise your Surface Theme, Accent Colour, and Font in Step 1, scan and resolve overlapping addons in Step 2, and choose starter presets or individual modules in Step 3.",
      keywords = "quick start guided setup 3 step style theme conflicts modules presets full suite mythic+ raid lightweight qol /ds setup" },
    { moduleKey = "SETUP", category = "BAGS_QOL", viewKey = "GUIDED_SETUP", tabIndex = 2, tabName = "2. Conflicts", tabLabel = "Conflict Diagnostic (/ds conflicts)",
      title = "External Addon Conflict Detector & Auto-Yield Diagnostic (/ds conflicts)",
      desc = "Scan for overlapping third-party addons (Baganator, Prat-3.0, DialogueUI, SimpleAddonManager, ElvUI, Leatrix Plus, DecorVendor) and resolve HARD conflicts or SOFT Auto-Yield overlaps in 1 click.",
      keywords = "conflict conflicts scanner compatibility error taint diagnostic /ds conflicts auto-yield yield third-party overlap baganator betterbags adibags arkinventory bagnon sorted litebag prat-3.0 chattynator ls_glass basicchatmods chatter wim dialogueui immersion storyline autoturnin premadegroupsfilter premaderegionfilter focusmarker targetcharms dynamiccam maxcam actioncamplus acp simpleaddonmanager betteraddonlist leatrix elvui decorvendor" },
    { moduleKey = "STUDIO", category = "BAGS_QOL", viewKey = "DYNAMICLOAD", tabIndex = 1, tabLabel = "Module Quick Guide (?)",
      title = "Module Quick Guide (? Header Button)",
      desc = "Click the compact ? button in the top-right header while viewing any of the 13 modules to see its slash commands, 1-sentence summary, and 3 starter tips.",
      keywords = "quick guide help tips ? header button overview tutorial shortcut how to use module" },

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
      title = "Zone Addon Checklist (Outdoor, Delves, Dungeons, Raid, PvP)", highlightTitle = "Copy From...",
      desc = "Manage your installed addons across 5 zone profiles with By Zone, Always, and Never rules, persistent group collapse, and one-click Copy From... cloning.",
      keywords = "addon manager profiles outdoor delves dungeons raid pvp enable disable always never by zone copy from clone zone profile collapse expand parent tree cpu memory usage load out of date backup state sort" },
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
      title = "Actionable Toast Duration",
      desc = "Choose how long actionable alert toasts (Reload, Mage Food, Durability, Talent Swap, Group Teleport) stay on screen before fading out (5s, 8s, 12s, 20s, or Stay Until Clicked).",
      keywords = "actionable toast duration timer fade hide stay until clicked seconds follower dungeon reload swap teleport durability" },
    { moduleKey = "load", category = "HUD_LOOK", tabIndex = "toast_ui", tabLabel = "Alert Toast Style",
      title = "Info & Mention Toast Duration",
      desc = "Choose how long info and chat mention alert toasts stay on screen before fading out (3s, 5s, 8s, 12s, or Stay Until Clicked).",
      keywords = "info mention toast duration timer fade hide stay until clicked seconds chat notification" },
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
    { moduleKey = "marker", category = "COMBAT", tabIndex = 2, tabLabel = "World Flare Keys",
      title = "World Flare Cycle Sequence",
      desc = "Left-click ground flare icons to toggle them in your cycle sequence; right-click to reorder priority.",
      keywords = "world flare cycle sequence ground markers pillar smoke beacon order" },
    { moduleKey = "marker", category = "COMBAT", tabIndex = 2, tabLabel = "World Flare Keys",
      title = "Cycle World Flare Keybind",
      desc = "Optionally bind a key (Unbound by default) to drop the next World Flare at your cursor. Click to bind, Right-click to unbind.",
      keywords = "cycle ground flare keybind unbound clear unbind cursor world marker" },
    { moduleKey = "marker", category = "COMBAT", tabIndex = 2, tabLabel = "World Flare Keys",
      title = "Clear All Flares Keybind",
      desc = "Optionally bind a key (Unbound by default) to clear all active World Flares on the ground. Click to bind, Right-click to unbind.",
      keywords = "clear all flares keybind unbound unbind remove world markers ground" },
    { moduleKey = "marker", category = "HUD_LOOK", tabIndex = 2, tabLabel = "World Flare Keys",
      title = "Show On-Screen World Flare Bar",
      desc = "Display the floating 9-button World Flare bar on screen (Always, In Group Only, or Hidden).",
      keywords = "show on-screen world flare bar hud ground markers visibility" },
    { moduleKey = "marker", category = "HUD_LOOK", tabIndex = 2, tabLabel = "World Flare Keys", isSubDrawer = true,
      title = "World Flare Bar Scale",
      desc = "Scale the On-Screen World Flare Bar from 50% to 200%.",
      keywords = "world flare bar scale size ground markers" },
    { moduleKey = "marker", category = "HUD_LOOK", tabIndex = 2, tabLabel = "World Flare Keys", isSubDrawer = true,
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
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 2, tabLabel = "Context Auto-Zoom", isSubDrawer = true,
      title = "Raid & Boss Combat Target Distance",
      desc = "Set the automatic camera distance for Raid instances and boss encounters (default 39 yd).",
      keywords = "raid boss combat target distance auto zoom yards" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 2, tabLabel = "Context Auto-Zoom", isSubDrawer = true,
      title = "Mythic+ & 5-Player Dungeon Target Distance",
      desc = "Set the automatic camera distance for Mythic+ keys and 5-player dungeons (default 39 yd).",
      keywords = "mythic+ m+ 5-player dungeon target distance auto zoom" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 2, tabLabel = "Context Auto-Zoom", isSubDrawer = true,
      title = "Delves & Scenarios Target Distance",
      desc = "Set the automatic camera distance for Delves and Scenarios (default 39 yd).",
      keywords = "delves scenarios target distance auto zoom" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 2, tabLabel = "Context Auto-Zoom", isSubDrawer = true,
      title = "PvP Arenas & Battlegrounds Target Distance",
      desc = "Set the automatic camera distance for Arenas and Battlegrounds (default 39 yd).",
      keywords = "pvp arena bg battleground target distance auto zoom" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 2, tabLabel = "Context Auto-Zoom", isSubDrawer = true,
      title = "Open World Target Distance",
      desc = "Set the automatic camera distance when exploring the outdoor world (default 39 yd).",
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
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 2, tabLabel = "Context Auto-Zoom", isSubDrawer = true,
      title = "NPC Dialogue Distance",
      desc = "Set the target camera distance (15 to 25 yards) when speaking with quest or gossip NPCs out of combat.",
      keywords = "npc dialogue distance quest gossip framing zoom yards" },
    { moduleKey = "zoom", category = "FPS_CAM", tabIndex = 3, tabLabel = "Speed, Pitch & Framing",
      title = "Base Mousewheel Zoom Glide Speed",
      desc = "Fine-tune the baseline mousewheel camera zoom glide speed across all zones.",
      keywords = "base mousewheel zoom glide speed camera move speed smooth" },
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
      title = "Automatic Spell Queue Tuning",
      desc = "Automatically tune Spell Queue Timing based on your live World Ping, Specialisation, and Haste GCD.",
      keywords = "automatic spell queue tuning spellqueuewindow latency ping ms gcd haste lag input delay" },
    { moduleKey = "fps", category = "COMBAT", tabIndex = "GUARD_QUEUE", tabLabel = "FPS Guard & Queue", isSubDrawer = true,
      title = "Custom Spell Queue Delay (ms)",
      desc = "Set an exact manual Spell Queue Timing delay in milliseconds (50 ms to 400 ms).",
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
      title = "QUICK PRESETS",
      desc = "Apply a ready-made Top Info Bar preset (Raider / M+ Full, Minimalist Stats, Keystone Focus, or System Only) in one click.",
      keywords = "quick presets raider full minimalist stats keystone focus system only top info bar prep" },
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
      desc = "Sort secondary stats on the Top Info Bar by Highest Value or Custom Order (Crit / Haste / Mastery / Vers).",
      keywords = "secondary stat order crit haste mastery versatility sort top bar" },
    { moduleKey = "prep", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Bar Layout & Style",
      title = "Ping Display Format",
      desc = "Display World Ping, Home Ping, or Both on the Top Info Bar.",
      keywords = "ping display format latency ms world home top bar" },
    { moduleKey = "prep", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Bar Layout & Style",
      title = "Top Info Bar Display Mode",
      desc = "Show the Top Info Bar Always, Out of Combat Only, in Instances Only, or Hide.",
      keywords = "top info bar display mode visibility hide combat" },
    { moduleKey = "prep", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Bar Layout & Style",
      title = "Bar Density",
      desc = "Switch the Top Info Bar between Standard height (30 px) and Compact mode (24 px) with tighter capsule padding.",
      keywords = "bar density compact mode slim height padding top info bar prep" },
    { moduleKey = "prep", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Bar Layout & Style",
      title = "Bar Mouseover Fade",
      desc = "Keep the Top Info Bar at full brightness or dim it until hovered (or strictly during combat).",
      keywords = "bar mouseover fade hover dim alpha opacity combat fade top info bar prep" },
    { moduleKey = "prep", category = "FPS_CAM", tabIndex = 1, tabLabel = "Bar Layout & Style",
      title = "Combat Stat Refresh Rate",
      desc = "Control how frequently live secondary stats update during combat.",
      keywords = "combat stat refresh rate throttle cpu performance" },
    { moduleKey = "prep", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Bar Layout & Style",
      title = "Bar Scale",
      desc = "Scale the Top Info Bar from 60% to 150%.",
      keywords = "bar scale size top info bar prep" },
    { moduleKey = "prep", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Bar Layout & Style",
      title = "Bar Opacity",
      desc = "Adjust the transparency of the Top Info Bar (20% to 100%).",
      keywords = "bar opacity alpha background transparency top info bar" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio",
      title = "Enable Clickable Raid Buffs HUD",
      desc = "Show missing class raid buffs, partner buffs, flasks, food, weapon oils, and augment runes as 1-click cast buttons.",
      keywords = "enable clickable raid buffs hud consumables missing buff reminder cast button" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio", isSubDrawer = true, drawerKey = "raidBuffs",
      title = "Active Content Scope",
      desc = "Choose where Clickable Raid Buffs appear (Always, Group / Inst, or Instances).",
      keywords = "active content scope raid buffs dungeon delve solo" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio", isSubDrawer = true, drawerKey = "raidBuffs",
      title = "Class Raid Buffs",
      desc = "Track missing Arcane Intellect, Power Word: Fortitude, Mark of the Wild, Battle Shout, Skyfury, and Blessing of the Bronze.",
      keywords = "class raid buffs intellect fortitude mark of the wild battle shout skyfury bronze" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio", isSubDrawer = true, drawerKey = "raidBuffs",
      title = "Partner Buffs (Symbiotic, Source of Magic, Earth Shield, Beacons)",
      desc = "Track missing single-target partner buffs (Symbiotic Relationship, Source of Magic, Blistering Scales, Earth Shield, and Beacons) with smart role targeting.",
      keywords = "partner buffs symbiotic relationship source of magic blistering scales earth shield beacon of light faith" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio", isSubDrawer = true, drawerKey = "raidBuffs",
      title = "In-Combat Brez & Missing Raid Buff Tracker",
      desc = "Show your missing Class Raid Buff icon during combat after a battle-rez while keeping personal consumables hidden.",
      keywords = "in-combat brez battle rez missing raid buff tracker motw" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio", isSubDrawer = true, drawerKey = "raidBuffs",
      title = "Weapon Oils & Stones (1-Click Auto-Apply)",
      desc = "Show missing Midnight weapon oils and sharpening/weightstones with 1-click application to Main-Hand and Off-Hand.",
      keywords = "weapon oils stones sharpening weightstone mana oil enchant 1-click apply" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio", isSubDrawer = true, drawerKey = "raidBuffs",
      title = "Flasks & Phials (Fleeting & Quality Badges)",
      desc = "Track active Flasks and Phials with Rank 1 / Rank 2 quality badges and Fleeting flask support.",
      keywords = "flasks phials fleeting quality rank badge consumable" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio", isSubDrawer = true, drawerKey = "raidBuffs",
      title = "Well Fed & Hearty Food Reminder",
      desc = "Remind you when Well Fed is missing or expiring, prioritising Hearty food in your bags.",
      keywords = "well fed hearty food buff reminder feast roast consumable" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio", isSubDrawer = true, drawerKey = "raidBuffs",
      title = "Augment Rune Reminder",
      desc = "Track missing Augment Runes in Raids or Mythic+ with support for reusable Infinite Runes.",
      keywords = "augment rune reminder infinite rune raid mythic+" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio", isSubDrawer = true, drawerKey = "raidBuffs",
      title = "Expiring Warning Threshold",
      desc = "Show the Clickable Buff reminder early when buffs have fewer than your chosen minutes remaining.",
      keywords = "expiring warning threshold minutes remaining buff reminder" },
    { moduleKey = "prep", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio", isSubDrawer = true, drawerKey = "raidBuffs",
      title = "Clickable Icon Size",
      desc = "Adjust the pixel size of Clickable Raid Buff icons (32 px to 64 px).",
      keywords = "clickable icon size raid buffs hud scale" },
    { moduleKey = "prep", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio", isSubDrawer = true, drawerKey = "raidBuffs",
      title = "Clickable Icon Spacing",
      desc = "Adjust the spacing gap between Clickable Raid Buff icons (2 px to 24 px).",
      keywords = "clickable icon spacing gap padding raid buffs hud" },
    { moduleKey = "prep", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio", isSubDrawer = true, drawerKey = "raidBuffs",
      title = "Hide \"MISSING\" Text Label",
      desc = "Hide the red MISSING text beneath Clickable Raid Buff icons for a cleaner icon-only bar.",
      keywords = "hide missing text label raid buffs clean icon only" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio",
      title = "Omni Folio Tracking",
      desc = "Track your Midnight Seasonal Omni Folio secondary stat buff and highlight it in gold when it disagrees with your target stat.",
      keywords = "omni folio omnium tracking midnight seasonal stat buff" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio", isSubDrawer = true, drawerKey = "omniFolio",
      title = "Specialisation Preset",
      desc = "Automatically load Wowhead recommended secondary stat targets for all 40 specialisations or customise per content type.",
      keywords = "specialisation preset wowhead stat priority omni folio" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio", isSubDrawer = true, drawerKey = "omniFolio",
      title = "Mythic+ Dungeons Target Stat",
      desc = "Choose the target Omni Folio secondary stat (Crit, Haste, Mastery, or Versatility) for Mythic+ Dungeons.",
      keywords = "mythic+ dungeons target stat omni folio crit haste mastery versatility" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio", isSubDrawer = true, drawerKey = "omniFolio",
      title = "Raid Encounters Target Stat",
      desc = "Choose the target Omni Folio secondary stat for Raid instances.",
      keywords = "raid encounters target stat omni folio crit haste mastery versatility" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio", isSubDrawer = true, drawerKey = "omniFolio",
      title = "Delves & Open World Target Stat",
      desc = "Choose the target Omni Folio secondary stat for Delves and Open World.",
      keywords = "delves open world target stat omni folio" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio", isSubDrawer = true, drawerKey = "omniFolio",
      title = "Rated & Casual PvP Target Stat",
      desc = "Choose the target Omni Folio secondary stat for Arenas and Battlegrounds.",
      keywords = "rated casual pvp target stat omni folio" },
    { moduleKey = "prep", category = "COMBAT", tabIndex = 2, tabLabel = "Raid Buffs & Omni Folio",
      title = "Highlight Missing Enchants & Empty Sockets",
      desc = "Draw gold borders around equipped Character panel slots that are missing a Midnight enchant or contain an empty gem socket.",
      keywords = "paperdoll gear audit highlight missing enchants empty sockets gems character panel testaudit" },
    { moduleKey = "prep", category = "BAGS_QOL", tabIndex = 3, tabLabel = "World & Survival QoL",
      title = "Auto-Skip Gossip & Quest Turn-In",
      desc = "Automatically select single-option NPC gossip dialogues and accept/complete quests (hold Shift to pause).",
      keywords = "auto-skip gossip quest turn-in accept dialogue npc talk delve interact" },
    { moduleKey = "prep", category = "BAGS_QOL", tabIndex = 3, tabLabel = "World & Survival QoL",
      title = "Hide Talking Head & Skip Cutscenes",
      desc = "Automatically skip movies and cinematics and suppress the Talking Head popup. Hold Shift to watch a cutscene without skipping.",
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
    { moduleKey = "prep", category = "BAGS_QOL", tabIndex = 3, tabLabel = "World & Survival QoL",
      title = "Automated Drink & Recovery Macro ([DynamicDrink])",
      desc = "Out-of-combat drink and food macro with Role-Smart priority, Recuperate fallback, and strict Well Fed exclusion.",
      keywords = "automated drink macro dynamicdrink water mana food recuperate nocombat well fed healer" },
    { moduleKey = "prep", category = "BAGS_QOL", tabIndex = 3, tabLabel = "World & Survival QoL",
      title = "Healer Mage Food Restock (Follower Dungeon)",
      desc = "Prompts solo players to queue a Follower Dungeon when low on Conjured Mana Buns, prompts to leave once restocked, and offers a 1-click Ask for Table toast in groups with a Mage.",
      keywords = "healer mage food restock conjured mana bun follower dungeon queue leave ask for table mage table toast" },
    { moduleKey = "prep", category = "BAGS_QOL", tabIndex = 3, tabLabel = "World & Survival QoL",
      title = "Low Durability Alert Toast",
      desc = "Shows a 1-click alert toast when any equipped gear slot drops to or below your durability threshold (summons a repair mount outdoors or opens your gear).",
      keywords = "low durability alert toast repair mount yak mammoth packmaster gear broken" },
    { moduleKey = "prep", category = "BAGS_QOL", tabIndex = 3, tabLabel = "World & Survival QoL",
      title = "Red Error Text & Sound Filter",
      desc = "Hides repetitive red combat and movement errors and optionally mutes error voice lines. Quest, encounter, and system messages are never hidden.",
      keywords = "red error text sound filter spam hide mute speech" },
    { moduleKey = "prep", category = "BAGS_QOL", tabIndex = 3, tabLabel = "World & Survival QoL", isSubDrawer = true, drawerKey = "errorFilter",
      title = "Hide Combat & Cooldown Spam",
      desc = "Suppresses repetitive combat red text such as 'Ability is not ready yet', 'Another action is in progress', 'Not enough mana/energy/rage/focus', and 'Out of range'.",
      keywords = "hide combat cooldown spam ability not ready mana energy rage focus runic power fury insanity out of range" },
    { moduleKey = "prep", category = "BAGS_QOL", tabIndex = 3, tabLabel = "World & Survival QoL", isSubDrawer = true, drawerKey = "errorFilter",
      title = "Hide Movement & Mount Errors",
      desc = "Suppresses movement and mount red text such as 'Can't do that while moving' and 'You are mounted'.",
      keywords = "hide movement mount errors cant do that while moving you are mounted" },
    { moduleKey = "prep", category = "BAGS_QOL", tabIndex = 3, tabLabel = "World & Survival QoL", isSubDrawer = true, drawerKey = "errorFilter",
      title = "Mute Error Voice Lines",
      desc = "Silences character error voice lines (such as 'I can't cast that yet') and restores your original sound setting when turned off or disabled.",
      keywords = "mute error voice lines speech sound" },

    -- ========================================================================
    -- DYNAMICTALENT ("talent") - Talent Loadouts, Raid/M+/PvP/Zone Binds & Group Order
    -- ========================================================================
    { moduleKey = "talent", category = "COMBAT", tabIndex = 1, tabLabel = "Settings & Binds",
      title = "Talent Loadouts & Binds", highlightTitle = "Open Loadout Manager", openManager = true,
      desc = "Manage per-spec talent strings, Hero Talent badges, and Raid/M+/PvP/Zone swap rules in the Pop-Out Manager.",
      keywords = "talent loadout bind boss raid mythic+ lfr normal heroic mythic delves outdoor import wcl northern sky blizzard string hero /dt" },
    { moduleKey = "talent", category = "COMBAT", tabIndex = 1, tabLabel = "Settings & Binds",
      title = "Talent Export String", highlightTitle = "Open Loadout Manager", openManager = true,
      desc = "Paste Warcraft Logs, Northern Sky, or Blizzard strings, or capture your active talent tree.",
      keywords = "talent string export import paste copy wcl warcraft logs northern sky ns blizzard /dt" },
    { moduleKey = "talent", category = "COMBAT", tabIndex = 1, tabLabel = "Settings & Binds",
      title = "PvP Talent Binds", highlightTitle = "Open Loadout Manager", subMode = "PVP", openManager = true,
      desc = "Bind builds to All PvP, Arena, Battlegrounds, or War Mode.",
      keywords = "pvp arena battlegrounds bg blitz solo shuffle war mode outdoor pvp talent binds /dt" },
    { moduleKey = "talent", category = "COMBAT", tabIndex = 1, tabLabel = "Settings & Binds",
      title = "Enable DynamicTalent Module", highlightTitle = "Enable DynamicTalent Module",
      desc = "Toggle the Talent Loadouts Dock, Prep Bar switcher, and swap reminders.",
      keywords = "enable disable dynamictalent module talent dock switcher /dt" },
    { moduleKey = "talent", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Settings & Binds",
      title = "Show Talent Capsule on Prep Bar", highlightTitle = "Show Talent Capsule on Prep Bar",
      desc = "Toggle the Talent Loadout capsule inside DynamicPrep's Top Info Bar.",
      keywords = "prep bar capsule segment talents top info bar dynamicprep /dt" },
    { moduleKey = "talent", category = "COMBAT", tabIndex = 1, tabLabel = "Settings & Binds",
      title = "Zone-Aware Talent Loadout Reminders", highlightTitle = "Zone-Aware Talent Loadout Reminders",
      desc = "Show a 1-click alert toast when entering Raid, M+, Delve, or PvP content with a different build.",
      keywords = "talent reminder toast alert swap mismatch zone boss raid dungeon pvp /dt" },
    { moduleKey = "talent", category = "COMBAT", tabIndex = 1, tabLabel = "Settings & Binds",
      title = "Prioritise Current Zone First", highlightTitle = "Prioritise Current Zone First",
      desc = "Float loadouts matching your current zone to the top of quick-switchers.",
      keywords = "prioritise zone first sort quick switch talent dock prep bar /dt" },
    { moduleKey = "talent", category = "COMBAT", tabIndex = 1, tabLabel = "Settings & Binds",
      title = "Right-Click Hero Spec Swap", highlightTitle = "Right-Click Hero Spec Swap",
      desc = "Right-click Blizzard's Hero Talent medallion out of combat to switch Hero trees cleanly.",
      keywords = "hero spec swap medallion right click tree toggle /dt" },
    { moduleKey = "talent", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Settings & Binds",
      title = "Talent Tree Backdrop Studio", highlightTitle = "Base Background",
      desc = "Choose Blizzard Spec Art or Solid Obsidian with optional Hero-Synced or Class Glow mist.",
      keywords = "backdrop background mist obsidian blizzard spec art hero glow class tree art /dt" },
    { moduleKey = "talent", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Settings & Binds",
      title = "Background Dimmer", highlightTitle = "Background Dimmer",
      desc = "Darken Blizzard Spec Art (0%-85%) behind talent nodes for sharper readability.",
      keywords = "dimmer dark opacity spec art readability /dt" },
    { moduleKey = "talent", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Settings & Binds",
      title = "Ambient Mist & Mist Intensity", highlightTitle = "Ambient Mist",
      desc = "Layer Hero-Synced or Class Glow mist (15%-100% intensity) over either Base Background.",
      keywords = "ambient mist intensity opacity hero glow animation pulse /dt" },
    { moduleKey = "talent", category = "COMBAT", tabIndex = 1, tabLabel = "Settings & Binds",
      title = "Custom Loadout Group Order", highlightTitle = "CUSTOM LOADOUT GROUP ORDER",
      desc = "Drag and drop or use arrows to reorder Raid, M+, Delves, PvP, and Custom groups across Talent Dock and switchers.",
      keywords = "group order sort custom reorder drag drop arrows raid m+ delves pvp custom talent dock /dt" },

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
      desc = "Automatically confirms your current specialisation role out of combat after a short delay (hold Shift to skip; never auto-accepts queue pops).",
      keywords = "auto-accept role check confirm tank healer dps shift bypass lfg_role_check_show" },
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
      title = "QUICK PRESETS",
      desc = "Apply 1-click category presets (Mythic+ & Raid, Collector, Minimalist, or Custom) or Right-Click to save your current setup.",
      keywords = "quick presets category layout preset mythic+ raid collector minimalist custom bags" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Bag Layout Style",
      desc = "Choose between Grouped Categories (Keystones, Consumables, Gear Sets, BoE/WUE, Junk) or a Single Combined Grid.",
      keywords = "bag layout style grouped categories single grid virtual bags inventory" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Item Sorting",
      desc = "Order items by Quality (Rarity & Level), Alphabetical (A-Z), or Manual physical slot positions.",
      keywords = "item sorting quality alphabetical a-z manual slot order sort bags" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Auto-Merge Stacks on Close",
      desc = "Automatically combine partial item stacks (such as 8x + 5x) whenever you close your Bags or Bank.",
      keywords = "auto-merge stacks on close merge restack partial stack bags bank" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Category Order, Collapse & Visibility",
      desc = "Reorder, collapse by clicking section headers, or hide individual bag categories, plus quick search clearing with Esc or the inline clear button.",
      keywords = "category order collapse expand visibility pinned new items keystones gear sets boe wue consumables trade goods junk clear search escape x button" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Split Categories Into Sub-Groups",
      desc = "Sub-split Equipment by Armour/Weapon slot or Trade Goods by expansion.",
      keywords = "split categories into sub-groups armour armor weapon expansion" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Bag Columns",
      desc = "Set the number of item slot columns in your main Backpack window (8 to 20 columns).",
      keywords = "bag columns width backpack grid size" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Bank Columns",
      desc = "Set the number of item slot columns in your Bank, Warband Bank, and Guild Bank window (10 to 24 columns).",
      keywords = "bank columns width warband guild bank grid size" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Slot Icon Size",
      desc = "Adjust the pixel size of item slot buttons in your Bags and Bank (28px to 48px).",
      keywords = "slot icon size button scale bags bank" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Layout & Categories",
      title = "Category Spacing",
      desc = "Adjust the vertical padding between category groups inside DynamicBags.",
      keywords = "category spacing gap padding bags" },
    { moduleKey = "bags", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Appearance, Badges & Glow",
      title = "Bag Window Scale",
      desc = "Scale your main DynamicBags window from 70% to 140%.",
      keywords = "bag window scale size resize zoom bags" },
    { moduleKey = "bags", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Appearance, Badges & Glow",
      title = "Bank Window Scale",
      desc = "Scale your Personal, Warband, and Guild Bank window from 70% to 140%.",
      keywords = "bank window scale size resize zoom warband guild" },
    { moduleKey = "bags", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Appearance, Badges & Glow",
      title = "Window Background Opacity",
      desc = "Adjust the backdrop opacity of your DynamicBags and DynamicBank windows (50% to 100%).",
      keywords = "window background opacity transparency alpha bags bank" },
    { moduleKey = "bags", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Appearance, Badges & Glow",
      title = "Reset Window Positions",
      desc = "Restore DynamicBags and DynamicBank to their default screen corner and dock alignment.",
      keywords = "reset window positions dock alignment default corner bags bank" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 2, tabLabel = "Appearance, Badges & Glow",
      title = "Item Slot Badges",
      desc = "Toggle Item Level numbers, BoE/WUE bind tags, Equipment Set icons, Upgrade arrows, and Consumable Tier badges.",
      keywords = "item slot badges ilvl item level boe wue warband equipment set upgrade arrow quality tier" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 2, tabLabel = "Appearance, Badges & Glow",
      title = "Item Slot Highlights",
      desc = "Toggle Rarity Border Glows, New Item pulse highlights, and Unusable Red tinting on bag slots.",
      keywords = "item slot highlights rarity border glow new item unusable red tint" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 2, tabLabel = "Appearance, Badges & Glow",
      title = "Icon Font Size",
      desc = "Adjust the font size of Item Level and corner badge text on bag slots (10px to 16px).",
      keywords = "icon font size ilvl text badge bags" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault",
      title = "Auto-Open Triggers",
      desc = "Automatically open DynamicBags when visiting Bankers, Merchants, Mailboxes, Auction House, Scrappers, or Item Upgrade NPCs.",
      keywords = "auto-open triggers bank merchant vendor mailbox auction house catalyst upgrade" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault",
      title = "Remember Last Opened Bank & Sub-Tab",
      desc = "Reopen DynamicBank on whichever Personal or Warband tab you used most recently.",
      keywords = "remember last opened bank sub-tab personal warband guild persistence" },
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
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault", isSubDrawer = true, drawerKey = "autoRepair",
      title = "Funding Priority",
      desc = "Choose between Guild Bank First or Personal Gold Only for automatic gear repairs.",
      keywords = "funding priority guild bank personal gold auto repair" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault",
      title = "Auto-Sell Grey Junk",
      desc = "Automatically sell all poor-quality (grey) junk items when opening any merchant window.",
      keywords = "auto-sell grey junk vendor merchant poor items gold scrap" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault",
      title = "Merchant Quick-Stack Bulk Buy (Alt + Right-Click)",
      desc = "Hold Alt and Right-Click any stackable vendor item to purchase a full stack immediately without opening the split-stack popup.",
      keywords = "merchant quick-stack bulk buy alt right-click vendor full stack" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault",
      title = "Smart Vendor Auto-Restock",
      desc = "Automatically top up tracked vendor items to your target stock whenever you visit a merchant selling them.",
      keywords = "smart vendor auto-restock merchant buy restock reagents consumables list" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault", isSubDrawer = true, drawerKey = "autoRestock",
      title = "Auto-Restock Item List",
      desc = "Drag-and-drop items from your bags, Shift-Click links, or Ctrl + Alt + Right-Click vendor items to manage restock targets.",
      keywords = "auto-restock item list add remove clear all target quantity vendor drag drop" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault",
      title = "Faster Auto-Loot",
      desc = "Instantly collect all loot items on corpse open without waiting for the default loot window animation.",
      keywords = "faster auto-loot speedy loot corpse instant pickup" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault",
      title = 'Auto-Fill "DELETE" Item Confirmation',
      desc = 'Automatically type "DELETE" into the confirmation box when destroying a good-quality item.',
      keywords = "auto-fill delete item confirmation destroy type delete" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault",
      title = "Auto-Open Soulbound Loot & Gold Pouches",
      desc = "Automatically open Soulbound loot pouches, Housing Decor, Profession Knowledge, and wrapped items out of combat.",
      keywords = "auto-open containers pouches housing decor knowledge gold bags" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault", isSubDrawer = true, drawerKey = "autoOpenItems",
      title = "Auto-Open Soulbound Housing Decor",
      desc = "Automatically open or learn Soulbound and Warband-bound Housing Decor items out of combat.",
      keywords = "auto-open housing decor furniture chest bags" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault", isSubDrawer = true, drawerKey = "autoOpenItems",
      title = "Auto-Open Soulbound Profession Knowledge",
      desc = "Automatically use Soulbound and Warband-bound Profession Knowledge items when your character knows that profession.",
      keywords = "auto-open profession knowledge treatise shard notes curio" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault", isSubDrawer = true, drawerKey = "autoOpenItems",
      title = "Auto-Unwrap & Open Wrapped Items",
      desc = "Automatically unwrap wrapped gifts and parcels out of combat; vendor-locked or non-refundable items stay queued in Open (N) only.",
      keywords = "auto-unwrap wrapped items gift parcel package open bags" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault",
      title = "Show Open (N) Quick-Open Button",
      desc = "Display a 1-click button in the DynamicBags header to open queued Housing Decor, Profession Knowledge, and Use: caches.",
      keywords = "show open quick-open button header caches housing decor knowledge" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault", isSubDrawer = true, drawerKey = "quickOpenQueue",
      title = "Include Housing Decor in Open (N)",
      desc = "Queue Housing Decor, Room Decor, and House Chest items into the 1-spot Open (N) header button.",
      keywords = "include housing decor quick-open queue open button" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault", isSubDrawer = true, drawerKey = "quickOpenQueue",
      title = "Include Profession Knowledge in Open (N)",
      desc = "Queue Profession Knowledge items into Open (N) when your character knows that profession.",
      keywords = "include profession knowledge quick-open queue open button" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Automation & Alt Vault", isSubDrawer = true, drawerKey = "quickOpenQueue",
      title = "Soulbound Items Only (Protect BoE Items)",
      desc = "Require queued items to be Soulbound or Account-Bound so tradeable BoE / Auction House items are never consumed accidentally.",
      keywords = "soulbound items only protect boe safety quick-open queue" },

    -- ========================================================================
    -- 13. DYNAMICCURSOR ("cursor") - 4-Tab Cursor Ring, GCD/Cast Arc, Crosshair & Trail
    -- ========================================================================
    { moduleKey = "cursor", category = "COMBAT", tabIndex = 1, tabLabel = "Ring & Trail",
      title = "Main Cursor Ring, Thickness & Out-of-Combat Idle Fade",
      desc = "Show a customisable ring around your mouse cursor with 3 styles (Solid Ring, Soft Glow, High-Contrast Dual), 5 thickness levels, compact radius, fine X/Y offset, OOC Idle Fade (Off / 2s / 5s), Obsidian colour picker, and Mouse-Look ghost ring.",
      keywords = "cursor ring mouse circle style solid soft glow dual thickness radius opacity idle fade 2s 5s colour color picker custom hex mouselook click pulse offset /dcur" },
    { moduleKey = "cursor", category = "COMBAT", tabIndex = 1, tabLabel = "Ring & Trail",
      title = "Extra Ring Contrast (Dark Outline Backing)",
      desc = "Add a crisp dark outline behind the main cursor ring, inner GCD ring, and outer cast arc so they stand out over bright spell effects.",
      keywords = "extra ring contrast dark outline backing shadow visibility bright spell effects gcd cast arc cursor ring" },
    { moduleKey = "cursor", category = "COMBAT", tabIndex = 1, tabLabel = "Ring & Trail",
      title = "Cursor Presets (Clean Raid / High-Vis / Minimalist / Full Telemetry)",
      desc = "Apply one-click compact modern DynamicCursor presets from the Quick Presets strip at the top of Tab 1.",
      keywords = "cursor preset clean raid high visibility minimalist full telemetry reset /dcur" },
    { moduleKey = "cursor", category = "COMBAT", tabIndex = 1, tabLabel = "Ring & Trail",
      title = "Cursor Centre Dot, Mouse-Look Ghost & Click-Pulse Customisation",
      desc = "Configure Centre Dot size and colour mode, Mouse-Look ghost opacity (10%-100%), and Click-Pulse ripple scale (125%-250%) and colour mode inside collapsible Sub-Settings drawers.",
      keywords = "cursor centre center dot colour color mouselook mouse look ghost opacity click pulse ripple scale size sub settings" },
    { moduleKey = "cursor", category = "COMBAT", tabIndex = 1, tabLabel = "Ring & Trail",
      title = "Ground-Target AoE Highlight & +20% Size Boost",
      desc = "Boost the cursor ring to 100% opacity, +20% size, and a highlight colour (High-Vis Green, Bright Gold, or Custom) while aiming ground-targeted spells.",
      keywords = "ground target aoe highlight size boost reticle efflorescence heroic leap vortex cursor ring spell targeting" },
    { moduleKey = "cursor", category = "HUD_LOOK", tabIndex = 1, tabLabel = "Ring & Trail",
      title = "Pooled Cursor Trail & Colour Picker",
      desc = "Add a zero-idle-CPU cursor trail in 4 styles (Smooth Dots, Soft Mist, Class Sparks, Arcane Motes) with length, size, density, opacity, and custom colour picker.",
      keywords = "cursor trail smooth dots soft mist class sparks arcane motes length fade density colour color picker" },
    { moduleKey = "cursor", category = "COMBAT", tabIndex = 2, tabLabel = "GCD & Cast Arc",
      title = "Radial GCD Ring (Gap, Thickness, Colour & Opacity)",
      desc = "Show a secret-safe inner Global Cooldown swipe ring with configurable inward gap (0-20 px), Thin/Crisp/Thick thickness, independent colour, and opacity.",
      keywords = "gcd global cooldown ring swipe cursor arc radial gap spacing thickness thin crisp thick colour color opacity" },
    { moduleKey = "cursor", category = "COMBAT", tabIndex = 2, tabLabel = "GCD & Cast Arc",
      title = "Radial Cast, Channel & Empower Arc (Gap, Thickness, Colour, Opacity & Interrupt Flash)",
      desc = "Show an outer cast, channel, and empower progress ring with configurable outward gap (0-24 px), Thin/Crisp/Thick thickness, independent colour, opacity, and customisable interrupt flash colour.",
      keywords = "cast bar channel empower arc ring gap spacing thickness interrupt flash colour color opacity" },
    { moduleKey = "cursor", category = "COMBAT", tabIndex = 2, tabLabel = "GCD & Cast Arc",
      title = "Mini Spell Icon & Instant-Cast Flash",
      desc = "Show a 1px Obsidian-bordered spell icon beside your cast arc with configurable size (14-32 px), position (Top/Bottom/Left/Right/Centre), gap, and optional instant-cast flash.",
      keywords = "mini spell icon cast icon size position gap instant cast flash cursor border" },
    { moduleKey = "cursor", category = "COMBAT", tabIndex = 3, tabLabel = "Crosshair & Locator",
      title = "Modular Character Crosshair Elements & Colour Picker",
      desc = "Mix and match Crosshair, Brackets, Circle, and Centre Dot pills with per-element span, thickness, centre gap, circle radius/thickness, dot size, outline, X/Y offset, and custom colour picker.",
      keywords = "character crosshair elements pills dot brackets circle radius thickness centre gap outline offset x y colour color picker" },
    { moduleKey = "cursor", category = "COMBAT", tabIndex = 3, tabLabel = "Crosshair & Locator",
      title = "Find My Cursor (Shake Sensitivity, Ping Duration, Locator Scale & Colour)",
      desc = "Locate your cursor with framerate-independent Shake-to-Find (Low / Medium / High sensitivity), Ping After Mouse-Look with adjustable duration (0.30s-1.50s), Modifier Key Locator, Locator Highlight Scale (60%-160%), and independent Locator Colour Mode.",
      keywords = "find my cursor shake to find sensitivity low medium high ping after mouselook mouse look duration modifier key shift ctrl alt locator scale size colour color" },
    { moduleKey = "cursor", category = "COMBAT", tabIndex = 4, tabLabel = "Visibility & Tooltips",
      title = "Activity Visibility Zone Pills (All Zones, Open World, Delves, Dungeons, Raids, PvP)",
      desc = "Toggle active content types using multi-select Zone Pills (including All Zones) and auto-hide during Pet Battles, Vehicles, and Cutscenes.",
      keywords = "cursor visibility active zones all zones pills open world delves dungeons raids pvp pet battle vehicle cutscene" },
    { moduleKey = "cursor", category = "COMBAT", tabIndex = 4, tabLabel = "Visibility & Tooltips",
      title = "Hardware Cursor Size & Frame Strata (Native WoW CVar)",
      desc = "Adjust Blizzard's native cursorSizePreferred CVar (Auto / System DPI, 32x32 to 128x128) and cursor overlay frame strata cleanly from Tab 4.",
      keywords = "hardware cursor size native cvar cursorSizePreferred 32 48 64 96 128 dpi pointer scale strata layer" },
    { moduleKey = "cursor", category = "HUD_LOOK", tabIndex = 4, tabLabel = "Visibility & Tooltips",
      title = "Smart Cursor Tooltips",
      desc = "Anchor mouseover tooltips neatly near your cursor with X/Y offset, edge flipping, and combat corner or Shift-to-show modes.",
      keywords = "smart cursor tooltips anchor offset edge flip combat hide shift" },

    -- ========================================================================
    -- 8. DYNAMICCHAT ("chat") - Whisper (/ww), Skin, Sounds & History
    -- ========================================================================
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "Whisper & Input",
      title = "Instant Target Whisper (/ww)",
      desc = "Type '/ww ' in chat to immediately whisper your current friendly player target.",
      keywords = "instant target whisper /ww tell friendly target shortcut" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "Whisper & Input",
      title = "Clear '/ww' If You Have No Friendly Target",
      desc = "Safely clear the chat box if you press '/ww ' without a valid friendly player targeted so you never send '/ww' to public chat.",
      keywords = "clear /ww no friendly target prevent public chat" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "Whisper & Input",
      title = "Protect Whispers During Boss Fights & Mythic+",
      desc = "Keep whisper tabs protected during boss encounters and Mythic+ runs so incoming whispers never error.",
      keywords = "protect whispers during boss fights mythic+ secret value taint" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "Whisper & Input",
      title = "Use Up & Down Arrows to Repeat Sent Messages",
      desc = "Cycle through your previously sent chat lines using the Up and Down arrow keys without holding Alt.",
      keywords = "use up down arrows repeat sent messages history alt key" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "Whisper & Input",
      title = "Remember Whisper Channel After Sending",
      desc = "Choose whether pressing Enter returns to Party/Raid/Guild chat or stays locked on your last Whisper target.",
      keywords = "remember whisper channel after sending sticky whisper reset" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 1, tabLabel = "Whisper & Input",
      title = "Remember Party, Raid, Instance & Guild Channels",
      desc = "Keep Party, Raid, Instance, Guild, and Officer channels sticky between messages.",
      keywords = "remember party raid instance guild channels sticky chat" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Skin & Layout",
      title = "Quick Presets (Smoked-Glass, Minimalist Raid, High-Readability, Quiet Alerts)",
      desc = "Apply a 1-click DynamicChat setup for Smoked-Glass, Minimalist Raid, High-Readability, or Quiet Alerts.",
      keywords = "quick presets clean smoked glass minimalist raid high readability quiet alerts one click" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Skin & Layout",
      title = "Smoked-Glass Chat Window & Top Tab Bar",
      desc = "Style the chat frame with an Obsidian smoked-glass backdrop, scrollable top tab bar, and unread badges.",
      keywords = "smoked-glass chat window top tab bar skin glass theme" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Skin & Layout", isSubDrawer = true, drawerKey = "skinCore",
      title = "Chat Window Background Opacity",
      desc = "Adjust the backdrop darkness of the Smoked-Glass chat window (0% clear to 95% dark).",
      keywords = "chat window background opacity alpha transparency dark slider" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Skin & Layout", isSubDrawer = true, drawerKey = "skinCore",
      title = "Chat Window Border Style",
      desc = "Choose a live Suite Accent border, a subtle dark border, or borderless framing around your chat window.",
      keywords = "chat window border style accent dark borderless none" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Skin & Layout", isSubDrawer = true, drawerKey = "skinCore",
      title = "Chat Typing Box Position",
      desc = "Anchor the chat typing box cleanly below the chat window or above the top tab bar.",
      keywords = "chat typing box position editbox bottom top above" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Skin & Layout", isSubDrawer = true, drawerKey = "skinCore",
      title = "Chat Typing Box Shading",
      desc = "Tint the chat typing box border and glow with the active channel colour (Pink for Whisper, Blue for Party, Orange for Raid).",
      keywords = "chat typing box shading editbox channel colour border" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Skin & Layout", isSubDrawer = true, drawerKey = "skinCore",
      title = "Hide Default Blizzard Side Buttons",
      desc = "Hide Blizzard's default Social, Voice, and Channel side buttons for a clean chat edge.",
      keywords = "hide default blizzard side buttons social voice channel clutter" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Skin & Layout", isSubDrawer = true, drawerKey = "skinCore",
      title = "Auto-Fade Old Messages & Fade Duration",
      desc = "Toggle fading old chat lines and choose the visible duration (30s, 60s, 2m, or 5m).",
      keywords = "auto fade old messages fade duration 30s 60s 2m 5m readability" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Skin & Layout",
      title = "Left Shortcut Bar Visibility",
      desc = "Show the vertical Left Shortcut Bar Always, On Mouseover, Combat Hide, or Off.",
      keywords = "left shortcut bar visibility rail mouseover combat hide chat" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Skin & Layout", isSubDrawer = true, drawerKey = "leftRail",
      title = "Left Shortcut Bar Buttons",
      desc = "Choose which quick-action icons appear on the Left Shortcut Bar (Social, Durability, Vault, Copy, Combat Log, Lock, Settings, Scroll Down).",
      keywords = "left shortcut bar buttons copy chat durability vault combat log lock settings" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Skin & Layout",
      title = "Chat Font Family & Size",
      desc = "Choose your Suite theme font or any built-in, Blizzard, or SharedMedia font and adjust text size from 10 px to 22 px.",
      keywords = "chat font family size typography sharedmedia blizz expressway suite match" },
    { moduleKey = "chat", category = "HUD_LOOK", tabIndex = 2, tabLabel = "Chat Skin & Layout",
      title = "Font Outline, Drop Shadow & Line Spacing",
      desc = "Set None, Thin Outline, or Thick Outline, toggle crisp (1, -1) drop shadows, and adjust line spacing (0 px to 8 px).",
      keywords = "chat font outline thickoutline shadow drop shadow line spacing readability" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 2, tabLabel = "Chat Skin & Layout",
      title = "Safe Channel Names in Raids & Mythic+",
      desc = "Keep Blizzard's built-in channel labels protected so Raid and Mythic+ messages never cause UI errors.",
      keywords = "safe channel names raids mythic+ compact tags protected" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 2, tabLabel = "Chat Skin & Layout",
      title = "Show Player Class Colours in Chat",
      desc = "Enable class-coloured player names across all chat channels and whisper tabs.",
      keywords = "show player class colours in chat names" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 2, tabLabel = "Chat Skin & Layout",
      title = "Chat Message Timestamps",
      desc = "Add clean 24-hour or 12-hour timestamps (e.g. 20:45 or 20:45:12) to chat messages.",
      keywords = "chat message timestamps clock time hour minute" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts",
      title = "Chat Notification Sounds",
      desc = "Master switch for per-channel chat sound alerts across Whispers (including self-whispers), Guild, Party, Raid, and Say/Yell using Blizzard built-in sounds and SharedMedia/DBM/EXBOSS/BigWigs/WeakAuras/ElvUI.",
      keywords = "chat notification sounds sound alerts audio cue ping chime bell whisper self whisper guild party raid say mute blizzard raid warning ready check map ping auction bell quest complete sharedmedia dbm bigwigs weakauras elvui exboss" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts", isSubDrawer = true, drawerKey = "notifSounds",
      title = "Mute Sounds in Combat",
      desc = "Silence incoming chat notification sounds during boss encounters and combat lockdown.",
      keywords = "mute sounds in combat boss encounter lockdown silence chat notification" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts", isSubDrawer = true, drawerKey = "notifSounds",
      title = "Whisper & Battle.net Whisper",
      desc = "Select and preview the notification sound for incoming character and Battle.net whispers including self-whispers (Blizzard Whisper by default).",
      keywords = "whisper battle.net bnet realid tell self whisper chat notification sound blizzard whisper raid warning play" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts", isSubDrawer = true, drawerKey = "notifSounds",
      title = "Guild & Officer Chat",
      desc = "Select and preview the notification sound for incoming Guild and Officer chat messages (Blizzard Battle.net by default).",
      keywords = "guild officer chat notification sound blizzard battle.net toast play" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts", isSubDrawer = true, drawerKey = "notifSounds",
      title = "Party & Instance Chat",
      desc = "Select and preview the notification sound for Party, Party Leader, and LFD/LFR/Battleground Instance chat (Blizzard Map Ping by default).",
      keywords = "party leader instance dungeon battleground chat notification sound map ping play" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts", isSubDrawer = true, drawerKey = "notifSounds",
      title = "Raid & Raid Warning",
      desc = "Select and preview the notification sound for Raid, Raid Leader, and Raid Warning alerts (Blizzard Raid Warning by default).",
      keywords = "raid leader warning chat notification sound blizzard raid warning play" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts", isSubDrawer = true, drawerKey = "notifSounds",
      title = "Say & Yell",
      desc = "Select and preview an optional notification sound for nearby Say and Yell chat (None by default to prevent city spam).",
      keywords = "say yell spatial chat notification sound mute none play" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts", isSubDrawer = true, drawerKey = "notifSounds",
      title = "Audio Output Channel",
      desc = "Route chat notification sounds through Master (plays even with Effects muted), SFX, or Dialogue.",
      keywords = "audio output channel master sfx dialog dialogue sound volume" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts", isSubDrawer = true, drawerKey = "notifSounds",
      title = "Anti-Spam Cooldown",
      desc = "Set a per-channel anti-spam sound cooldown (Off, 1.5s, 3s, or 5s) so rapid messages never overlap.",
      keywords = "anti-spam cooldown throttle sound alert seconds" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts",
      title = "Enable Mention & Keyword Alerts",
      desc = "Detect your active character name and custom keywords in incoming chat.",
      keywords = "enable mention keyword alerts name highlight chime" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts", isSubDrawer = true, drawerKey = "mentions",
      title = "Custom Keywords",
      desc = "Watch for comma-separated words in chat (whole-word, case-insensitive).",
      keywords = "custom keywords mention alert watch list" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts", isSubDrawer = true, drawerKey = "mentions",
      title = "Name & Keyword Mention Sounds",
      desc = "Choose separate chimes for direct character name mentions and custom keyword triggers.",
      keywords = "name mention sound keyword trigger sound chime" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts", isSubDrawer = true, drawerKey = "mentions",
      title = "Highlight Mention in Chat & Mention Alert Toast",
      desc = "Highlight mentions in chat and show or test-preview the shared Mention Alert Toast banner.",
      keywords = "highlight mention alert toast test preview banner" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Sound Alerts", isSubDrawer = true, drawerKey = "customSounds",
      title = "Custom Sound Files (.ogg / .mp3)",
      desc = "Add, preview, and manage up to 6 custom .ogg or .mp3 audio files for chat and mention alerts.",
      keywords = "custom sound files ogg mp3 add delete test play" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 4, tabLabel = "Links & History",
      title = "Clickable Web Links (Discord, Wago, CurseForge)",
      desc = "Turn URLs in chat (Discord, Wago, Wowhead, Raider.IO, YouTube) into clickable links that open a Ctrl+C copy box.",
      keywords = "clickable web links url copy discord wago wowhead raider.io curseforge youtube" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 4, tabLabel = "Links & History",
      title = "Fast Mousewheel Scrolling (Shift & Ctrl)",
      desc = "Hold Shift to scroll 5 lines per tick or hold Ctrl to jump straight to the top or bottom of chat.",
      keywords = "fast mousewheel scrolling shift ctrl jump top bottom chat" },
    { moduleKey = "chat", category = "BAGS_QOL", tabIndex = 4, tabLabel = "Links & History",
      title = "Enable '/rl' (Reload UI) & '/lg' (Leave Group)",
      desc = "Register quick '/rl' (reload interface) and '/lg' (leave current party or instance group) slash commands.",
      keywords = "enable /rl reload ui /lg leave group party slash command shortcut" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 4, tabLabel = "Links & History",
      title = "Save Chat History Across Reloads & Logins",
      desc = "Restore your recent Party, Raid, Guild, and Whisper messages after a /reload or relog.",
      keywords = "save chat history across reloads logins restore messages" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 4, tabLabel = "Links & History", isSubDrawer = true, drawerKey = "chatHistory",
      title = "Saved Chat History Limit",
      desc = "Choose how many recent lines are saved across reloads (50, 100, 250, or 500 lines).",
      keywords = "saved chat history limit max lines memory" },
    { moduleKey = "chat", category = "GROUP_CHAT", tabIndex = 4, tabLabel = "Links & History", isSubDrawer = true, drawerKey = "chatHistory",
      title = "Copy & Clear Chat History",
      desc = "Open the Copy Chat window or clear the active chat window and saved reload history.",
      keywords = "copy clear chat history modal" },
    { moduleKey = "chat", category = "COMBAT", tabIndex = 4, tabLabel = "Links & History",
      title = "Instant Combat Log Tab (Prevent Freeze)",
      desc = "Stop Blizzard's Combat Log tab from freezing the client when clicked after a long Raid or Mythic+ session.",
      keywords = "instant combat log tab prevent freeze lag hang click" },

    -- DynamicVault (/dv)
    { moduleKey = "vault", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Account Matrix",
      title = "Account-Wide Great Vault Matrix & Raid Lockouts",
      desc = "View Raid, Mythic+, and World/Delves Great Vault slots, target reward iLvls, Raid boss lockouts, owned Keystones, and Account Gold across all alts.",
      keywords = "great vault matrix raid lockout boss kills mythic+ delves slots ilvl keystone alts account gold /dv" },
    { moduleKey = "vault", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Account Matrix",
      title = "Today's Bountiful Delves, Delve Keys & Seasonal Crests",
      desc = "Live scan of today's active Bountiful Delves alongside Restored Coffer Keys, Shards, Catalyst charges, and seasonal Crests with weekly caps.",
      keywords = "bountiful delves coffer keys shards catalyst crests weekly cap midnight" },
    { moduleKey = "vault", category = "BAGS_QOL", tabIndex = 2, tabLabel = "Weekly Checklist",
      title = "Auto-Tracked & Custom Weekly Checklist",
      desc = "Track weekly Great Vault milestones and add custom character or account-wide chores that reset automatically every weekly maintenance.",
      keywords = "weekly checklist chores tasks reset rollover maintenance" },
    { moduleKey = "vault", category = "BAGS_QOL", tabIndex = 3, tabLabel = "Settings & Maintenance",
      title = "Great Vault Top Dock, Auto-Match Skin & On-Screen Overlay",
      desc = "Automatically dock your Account Vault bar flush on top of Blizzard's Great Vault with EllesmereUI/ElvUI Auto-Match skinning, plus optional /dv overlay.",
      keywords = "great vault top dock auto-match ellesmere elvui skin overlay hud /dv" },
    { moduleKey = "prep", category = "BAGS_QOL", tabIndex = 3, tabLabel = "World & Survival QoL",
      title = "Auto-Accept Group Summons (1.5s Safety Delay)",
      desc = "Automatically accept Warlock and Meeting Stone summons out of combat after a 1.5s safety countdown (hold Shift to cancel).",
      keywords = "auto accept summon warlock meeting stone confirm summon teleport /dprep" },
    { moduleKey = "bags", category = "BAGS_QOL", tabIndex = 2, tabLabel = "Automation & Merchant",
      title = "Merchant Quick-Stack Bulk Buy & Smart Auto-Restock",
      desc = "Hold Alt + Right-Click at merchants to buy full stacks instantly, and configure '/dbag restock <item> <qty>' to top up vendor supplies automatically.",
      keywords = "merchant bulk buy full stack alt right click auto restock vendor supplies /dbag" },
    { moduleKey = "group", category = "GROUP_CHAT", tabIndex = 3, tabLabel = "Party & Keystone Automation",
      title = "Auto-Respond to '!keys' in Party, Raid & Guild Chat",
      desc = "Automatically link your owned Mythic+ Keystone when someone types !keys or !key in Party, Raid, or Guild chat (10s anti-spam cooldown).",
      keywords = "!keys !key keystone auto responder party raid guild chat mythic+ /dg" },
}
addonTable.SEARCH_INDEX_DATA = BUILTIN_SEARCH_SEED
DynamicSuite.SEARCH_INDEX_DATA = BUILTIN_SEARCH_SEED
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

--------------------------------------------------------------------------------
-- Core Blizzard Desktop Window Manager (33 Managed Panels, True MS-Windows Behaviour)
--------------------------------------------------------------------------------
local function SafeRegisterSuiteEvent(frame, eventName)
    if not frame or not eventName then return end
    if _G.C_EventUtils and type(_G.C_EventUtils.IsEventValid) == "function" then
        if not _G.C_EventUtils.IsEventValid(eventName) then
            return
        end
    end
    frame:RegisterEvent(eventName)
end

local DesktopWindows = {}
addonTable.DesktopWindows = DesktopWindows
DynamicSuite.DesktopWindows = DesktopWindows

do
    local SUPPORTED_BLIZZ_FRAMES = {
        { name = "CharacterFrame",                 label = "Character" },
        { name = "InspectFrame",                   label = "Inspect",            addon = "Blizzard_InspectUI" },
        { name = "DressUpFrame",                   label = "Dressing Room" },
        { name = "PlayerSpellsFrame",              label = "Talents & Spells",   addon = "Blizzard_PlayerSpells",              protected = true },
        { name = "PVEFrame",                       label = "Group Finder",       addon = "Blizzard_GroupFinder",               protected = true },
        { name = "WeeklyRewardsFrame",             label = "Great Vault",        addon = "Blizzard_WeeklyRewards" },
        { name = "CommunitiesFrame",               label = "Guild & Communities", addon = "Blizzard_Communities" },
        { name = "FriendsFrame",                   label = "Social & Friends" },
        { name = "CollectionsJournal",             label = "Collections",        addon = "Blizzard_Collections" },
        { name = "EncounterJournal",               label = "Adventure Guide",    addon = "Blizzard_EncounterJournal" },
        { name = "ProfessionsFrame",               label = "Professions",        addon = "Blizzard_Professions",               protected = true },
        { name = "ProfessionsBookFrame",           label = "Professions Book",   addon = "Blizzard_ProfessionsBook",           protected = true },
        { name = "AchievementFrame",               label = "Achievements",       addon = "Blizzard_AchievementUI" },
        { name = "ItemUpgradeFrame",               label = "Item Upgrade",       addon = "Blizzard_ItemUpgradeUI" },
        { name = "CalendarFrame",                  label = "Calendar",           addon = "Blizzard_Calendar" },
        { name = "MacroFrame",                     label = "Macros",             addon = "Blizzard_MacroUI",                   protected = true },
        { name = "MerchantFrame",                  label = "Merchant" },
        { name = "MailFrame",                      label = "Mail" },
        { name = "AuctionHouseFrame",              label = "Auction House",      addon = "Blizzard_AuctionHouseUI" },
        { name = "TradeFrame",                     label = "Trade" },
        { name = "ItemSocketingFrame",             label = "Item Socketing",     addon = "Blizzard_ItemSocketingUI" },
        { name = "ItemInteractionFrame",           label = "Revival Catalyst",   addon = "Blizzard_ItemInteractionUI" },
        { name = "WardrobeFrame",                  label = "Transmogrify",       addon = "Blizzard_Collections" },
        { name = "ProfessionsCustomerOrdersFrame", label = "Crafting Orders",    addon = "Blizzard_ProfessionsCustomerOrders", protected = true },
        { name = "MajorFactionRenownFrame",        label = "Renown",                    addon = "Blizzard_MajorFactions" },
        { name = "GenericTraitFrame",              label = "Omnium Folio / Trait Tree", addon = "Blizzard_GenericTraitUI" },
        { name = "ExpansionLandingPage",           label = "Expansion Summary",         addon = "Blizzard_ExpansionLandingPage" },
        { name = "ClassTrainerFrame",              label = "Trainer",            addon = "Blizzard_TrainerUI" },
        { name = "GossipFrame",                    label = "NPC Gossip" },
        { name = "QuestFrame",                     label = "Quest" },
        { name = "BankFrame",                      label = "Bank" },
        { name = "AddonList",                      label = "AddOn List" },
        { name = "WorldMapFrame",                  label = "Map & Quest Log",    addon = "Blizzard_WorldMap",                  protected = true, windowedOnly = true },
    }

    local SUPPORTED_BY_NAME = {}
    local SUPPORTED_ADDON_TRIGGER = {
        NoAutoClose = true,
        BlizzMove = true,
        DeModal = true,
        MoveAny = true,
        EllesmereUI = true,
        EllesmereUIQoL = true,
        EllesmereUI_QoL = true,
        Leatrix_Plus = true,
        ElvUI = true,
    }
    for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
        SUPPORTED_BY_NAME[spec.name] = spec
        if spec.addon then
            SUPPORTED_ADDON_TRIGGER[spec.addon] = true
        end
    end

    local EXCLUDED_BLIZZ_FRAMES = {
        GameMenuFrame = true,
        DelvesDifficultyPickerFrame = true,
    }

    local SCALE_MIN  = 0.70
    local SCALE_MAX  = 1.40
    local SCALE_STEP = 0.05

    local W = {
        KEEP_UIPANEL_LAYOUT = {
            WorldMapFrame    = true,
            CommunitiesFrame = true,
        },
        ROOT_WHEEL_EXEMPT = {
            EncounterJournal = true,
        },
        NON_RESTORABLE_PANELS = {
            ItemSocketingFrame   = true,
            TradeFrame           = true,
            GossipFrame          = true,
            QuestFrame           = true,
            ItemUpgradeFrame     = true,
            ItemInteractionFrame = true,
            BankFrame            = true,
            GuildBankFrame       = true,
        },
        HEADER_OVERLAY_OFFSET         = 25,
        blizzWinState                 = setmetatable({}, { __mode = "k" }),
        rawFrameMethods               = setmetatable({}, { __mode = "k" }),
        hookedFrameNames              = {},
        origUIPanelInfo               = {},
        detachedPanels                = {},
        pendingSlotEviction           = {},
        sessionScales                 = {},
        sessionPositions              = {},
        openPanelsSnapshot            = {},
        zOrderStack                   = {},
        lastTopFocusedWindow          = nil,
        combatEscHandlers             = setmetatable({}, { __mode = "k" }),
        combatEscCounter              = 0,
        lastShownAt                   = {},
        lastAutoHiddenAt              = {},
        lastExplicitCloseAt           = {},
        showSeqCounter                = 0,
        restoringPanels               = false,
        escapeProtectedReShow         = {},
        escapeClosedCount             = 0,
        escapeClosedFrame             = nil,
        inShowUIPanelPostHook         = false,
        inCloseSpecialWindowsPostHook = false,
        inEscapeRestorePostHook       = false,
        explicitCloseFrame            = nil,
        showUIPanelHooked             = false,
        hideUIPanelHooked             = false,
        updateUIPanelHooked           = false,
        registerUIPanelHooked         = false,
        scaleFitPreGuarded            = false,
        closeSpecialHooked            = false,
        closeWindowsHooked            = false,
        closeAllHooked                = false,
        toggleGameMenuHooked          = false,
        toggleProfBookHooked          = false,
        toggleFriendsHooked           = false,
        toggleWorldMapHooked          = false,
        toggleExtraHooksDone          = false,
        globalMouseHooked             = false,
        interactionEventsHooked       = false,
        addonContinueRegistered       = {},
        ellesmereHooksInstalled       = false,
        userOpeningPlayerSpells       = false,
        deferredRestorePending        = false,
        pendingCombatWindowSetup      = {},
        pendingDragWatch              = nil,
        dragDriverFrame               = nil,
        ctrlWheelOverlay              = nil,
        scaleToast                    = nil,
    }

    DesktopWindows.SUPPORTED_BLIZZ_FRAMES  = SUPPORTED_BLIZZ_FRAMES
    DesktopWindows.SUPPORTED_BY_NAME       = SUPPORTED_BY_NAME
    DesktopWindows.SUPPORTED_ADDON_TRIGGER = SUPPORTED_ADDON_TRIGGER

    function W.SafeRemoveTableKey(tbl, key)
        if type(tbl) ~= "table" or key == nil then return end
        if _G.TextureLoadingGroupMixin and type(_G.TextureLoadingGroupMixin.RemoveTexture) == "function" then
            pcall(_G.TextureLoadingGroupMixin.RemoveTexture, { textures = tbl }, key)
        end
        if tbl[key] ~= nil then
            tbl[key] = nil
        end
    end

    function W.GetRawFrameMethod(frame, methodName)
        if not frame then return nil end
        local mt = getmetatable(frame)
        local idx = (type(mt) == "table") and mt.__index or nil
        if type(idx) == "table" then
            local cache = W.rawFrameMethods[idx]
            if cache and cache[methodName] ~= nil then
                return cache[methodName] or nil
            end
            if type(idx[methodName]) == "function" then
                if not cache then
                    cache = {}
                    W.rawFrameMethods[idx] = cache
                end
                cache[methodName] = idx[methodName]
                return idx[methodName]
            end
        end
        if type(frame[methodName]) == "function" then
            return frame[methodName]
        end
        return nil
    end

    function W.RawClearAndSetPoint(frame, point, relTo, relPoint, x, y)
        if not frame then return false end
        local clearFn = W.GetRawFrameMethod(frame, "ClearAllPoints")
        local setPtFn = (type(frame.SetPointBase) == "function" and frame.SetPointBase)
            or W.GetRawFrameMethod(frame, "SetPoint")
        if type(clearFn) ~= "function" or type(setPtFn) ~= "function" then
            return false
        end
        return pcall(function()
            clearFn(frame)
            setPtFn(frame, point, relTo, relPoint, x, y)
        end)
    end

    function W.RawSetScale(frame, s)
        if not frame then return false end
        local fn = W.GetRawFrameMethod(frame, "SetScale")
        if type(fn) ~= "function" then return false end
        return pcall(fn, frame, s)
    end

    function W.RawSetFrameStrata(frame, strata)
        if not frame then return false end
        local fn = W.GetRawFrameMethod(frame, "SetFrameStrata")
        if type(fn) ~= "function" then return false end
        return pcall(fn, frame, strata)
    end

    function W.RawSetFrameLevel(frame, level)
        if not frame then return false end
        local fn = W.GetRawFrameMethod(frame, "SetFrameLevel")
        if type(fn) ~= "function" then return false end
        return pcall(fn, frame, level)
    end

    function W.RawSetToplevel(frame, top)
        if not frame then return false end
        local fn = W.GetRawFrameMethod(frame, "SetToplevel")
        if type(fn) ~= "function" then return false end
        return pcall(fn, frame, top)
    end

    function W.RawRaise(frame)
        if not frame then return false end
        local fn = W.GetRawFrameMethod(frame, "Raise")
        if type(fn) ~= "function" then return false end
        return pcall(fn, frame)
    end

    local function IsCombatProtectedPanel(frameName)
        local spec = frameName and SUPPORTED_BY_NAME[frameName]
        return (spec and spec.protected == true) and true or false
    end

    function W.IsTaintSensitiveFrame(frame, frameName)
        if frameName == "CommunitiesFrame" or frameName == "PVEFrame" then
            return true
        end
        if frame ~= nil and type(frame.IsProtected) == "function" then
            local ok, prot = pcall(frame.IsProtected, frame)
            if ok and prot == true then
                return true
            end
        end
        return false
    end

    local function InCombat()
        return (type(_G.InCombatLockdown) == "function") and (_G.InCombatLockdown() == true)
    end

    local function SafeNum(val, fallback)
        if val == nil then return fallback end
        if issecretvalue and issecretvalue(val) then return fallback end
        if type(canaccessvalue) == "function" then
            local ok, canAcc = pcall(canaccessvalue, val)
            if ok and not canAcc then return fallback end
        end
        local n = tonumber(val)
        if type(n) == "number" then return n end
        return fallback
    end

    local function GetFrameState(frame)
        if not frame then return nil end
        local st = W.blizzWinState[frame]
        if not st then
            st = {}
            W.blizzWinState[frame] = st
        end
        return st
    end

    local function ClampNumber(v, minV, maxV)
        if v < minV then return minV end
        if v > maxV then return maxV end
        return v
    end

    local function RoundScale(s)
        local rounded = math.floor(SafeNum(s, 1.0) * 100 + 0.5) / 100
        return ClampNumber(rounded, SCALE_MIN, SCALE_MAX)
    end

    local function IsWorldMapMaximized(frame, frameName)
        if frameName ~= "WorldMapFrame" and frame ~= _G.WorldMapFrame then
            return false
        end
        local wmf = frame or _G.WorldMapFrame
        if not wmf then return false end
        if type(wmf.IsMaximized) == "function" then
            local ok, isMax = pcall(wmf.IsMaximized, wmf)
            if ok and isMax == true then
                return true
            end
        end
        return false
    end

    local function ClampDesktopWindowOffset(arg1, arg2, arg3, arg4, arg5)
        local frame, ux, uy, scale
        if arg1 == DesktopWindows then
            frame, ux, uy, scale = arg2, arg3, arg4, arg5
        else
            frame, ux, uy, scale = arg1, arg2, arg3, arg4
        end
        ux = SafeNum(ux, 0)
        uy = SafeNum(uy, 0)
        local s = SafeNum(scale, 1.0)
        if s <= 0 then s = 1.0 end
        local uip = _G.UIParent
        if not uip or not frame then return ux, uy end
        local okW, rawUipW = pcall(uip.GetWidth, uip)
        local okH, rawUipH = pcall(uip.GetHeight, uip)
        local okFW, rawFW = pcall(frame.GetWidth, frame)
        local okFH, rawFH = pcall(frame.GetHeight, frame)
        local uipW = okW and SafeNum(rawUipW, 0) or 0
        local uipH = okH and SafeNum(rawUipH, 0) or 0
        local fw   = (okFW and SafeNum(rawFW, 0) or 0) * s
        local fh   = (okFH and SafeNum(rawFH, 0) or 0) * s
        if uipW <= 0 or uipH <= 0 or fw <= 0 or fh <= 0 then
            return ux, uy
        end
        local halfUipW = uipW * 0.5
        local halfUipH = uipH * 0.5
        local halfFW   = fw * 0.5
        local halfFH   = fh * 0.5

        local minUX = -halfUipW + halfFW
        local maxUX = halfUipW - halfFW
        if minUX <= maxUX then
            ux = ClampNumber(ux, minUX, maxUX)
        else
            -- Oversized scaled width: pin right edge and [X] Close button inside visible right bound of UIParent
            ux = maxUX
        end

        local minUY = -halfUipH + halfFH
        local maxUY = halfUipH - halfFH
        if minUY <= maxUY then
            uy = ClampNumber(uy, minUY, maxUY)
        else
            -- Oversized scaled height: pin top title bar and [X] Close button inside visible top bound of UIParent
            uy = maxUY
        end
        return ux, uy
    end
    DesktopWindows.ClampWindowOffset        = ClampDesktopWindowOffset
    DesktopWindows.ClampDesktopWindowOffset = ClampDesktopWindowOffset
    addonTable.ClampDesktopWindowOffset     = ClampDesktopWindowOffset
    DynamicSuite.ClampDesktopWindowOffset   = ClampDesktopWindowOffset

    local function GetTopMouseFocus()
        if type(_G.GetMouseFoci) == "function" then
            local ok, foci = pcall(_G.GetMouseFoci)
            if ok and type(foci) == "table" and foci[1] then
                return foci[1]
            end
        end
        if type(_G.GetMouseFocus) == "function" then
            local ok, focus = pcall(_G.GetMouseFocus)
            if ok and focus then
                return focus
            end
        end
        return nil
    end

    local INTERACTIVE_WIDGET_TYPES = {
        Button                  = true,
        ItemButton              = true,
        CheckButton             = true,
        EditBox                 = true,
        Slider                  = true,
        ScrollFrame             = true,
        EventScrollFrame        = true,
        Cooldown                = true,
        ColorSelect             = true,
        DropDownToggleButton    = true,
        EventButton             = true,
        ModelScene              = true,
        PlayerModel             = true,
        DressUpModel            = true,
        TabardModel             = true,
        CinematicModel          = true,
        Browser                 = true,
        MovieFrame              = true,
        ArchaeologyDigSiteFrame = true,
        QuestPOIFrame           = true,
        ScenarioPOIFrame        = true,
        Minimap                 = true,
    }

    local function IsPassiveWindowDragTarget(focusRegion, rootFrame)
        if not rootFrame then return false end
        if not focusRegion then return true end
        if focusRegion == rootFrame then return true end
        local st = W.blizzWinState[rootFrame]
        if st and focusRegion == st.overlay then return true end
        if rootFrame.TitleContainer and focusRegion == rootFrame.TitleContainer then return true end
        if focusRegion == _G.UIParent or focusRegion == _G.WorldFrame then return false end

        local cur = focusRegion
        local foundRoot = false
        for _ = 1, 18 do
            if not cur then break end
            if cur == rootFrame then
                foundRoot = true
                break
            end
            if st and cur == st.overlay then
                return true
            end
            if not cur._dsPassiveChrome then
                if type(cur.GetObjectType) == "function" then
                    local okT, objType = pcall(cur.GetObjectType, cur)
                    if okT and objType and INTERACTIVE_WIDGET_TYPES[objType] then
                        return false
                    end
                end
                if cur.GetNodeInfo ~= nil or cur.nodeInfo ~= nil or cur.definitionID ~= nil or cur.entryID ~= nil
                    or cur.talentID ~= nil or cur.GetElementData ~= nil or cur.elementData ~= nil
                    or cur.spellBookItemInfo ~= nil or cur.spellBookItemSlotIndex ~= nil
                    or cur.tabID ~= nil or cur.GetTabID ~= nil or cur.isTab ~= nil
                    or cur.scrollPercentage ~= nil or cur.Thumb ~= nil or cur.Track ~= nil or cur.panExtent ~= nil then
                    return false
                end
                if type(cur.GetScript) == "function" then
                    local ok1, sClick = pcall(cur.GetScript, cur, "OnClick")
                    if ok1 and sClick then return false end
                    local ok2, sDbl = pcall(cur.GetScript, cur, "OnDoubleClick")
                    if ok2 and sDbl then return false end
                    local ok3, sDrag = pcall(cur.GetScript, cur, "OnDragStart")
                    if ok3 and sDrag then return false end
                    local okR, sRecv = pcall(cur.GetScript, cur, "OnReceiveDrag")
                    if okR and sRecv then return false end
                end
            end
            if rootFrame.TitleContainer and cur == rootFrame.TitleContainer then
                return true
            end
            if type(cur.GetParent) ~= "function" then break end
            local okP, parent = pcall(cur.GetParent, cur)
            if not okP then break end
            cur = parent
        end
        return foundRoot
    end

    local function IsFunctionOnStack(fnRef, fnName, altName)
        if type(_G.debug) == "table" and type(_G.debug.getinfo) == "function" then
            for level = 2, 18 do
                local ok, info = pcall(_G.debug.getinfo, level, "nf")
                if not ok or not info then break end
                if (fnRef and info.func == fnRef)
                    or (fnName and info.name == fnName)
                    or (altName and info.name == altName) then
                    return true
                end
            end
        end
        if type(_G.debugstack) == "function" then
            local ok, stack = pcall(_G.debugstack, 2, 14, 0)
            if ok and type(stack) == "string" then
                if (fnName and stack:find(fnName, 1, true))
                    or (altName and stack:find(altName, 1, true)) then
                    return true
                end
            end
        end
        return false
    end

    local function IsShowUIPanelOnStack()
        if W.inShowUIPanelPostHook then return true end
        if IsFunctionOnStack(_G.ShowUIPanel, "ShowUIPanel", "SetUIPanel") then return true end
        if IsFunctionOnStack(_G.ToggleQuestLog, "ToggleQuestLog", "OpenWorldMap") then return true end
        if IsFunctionOnStack(_G.ToggleWorldMap, "ToggleWorldMap", "OpenWorldMap") then return true end
        if IsFunctionOnStack(nil, "FramePositionDelegate", "ShowUIPanel") then return true end
        return false
    end

    local function IsEscapeCloseOnStack()
        if W.inEscapeRestorePostHook or W.inCloseSpecialWindowsPostHook then return false end
        if IsFunctionOnStack(_G.ToggleGameMenu, "ToggleGameMenu", "CloseWindows") then return true end
        if IsFunctionOnStack(_G.CloseWindows, "CloseWindows", "CloseAllWindows") then return true end
        if IsFunctionOnStack(_G.CloseAllWindows, "CloseAllWindows", "CloseSpecialWindows") then return true end
        if IsFunctionOnStack(_G.CloseSpecialWindows, "CloseSpecialWindows", "CloseWindows") then return true end
        return false
    end

    local CANONICAL_CENTER_PANELS = {
        PlayerSpellsFrame              = true,
        ProfessionsFrame               = true,
        ProfessionsCustomerOrdersFrame = true,
        AchievementFrame               = true,
        CommunitiesFrame               = true,
        AuctionHouseFrame              = true,
        WeeklyRewardsFrame             = true,
        MajorFactionRenownFrame        = true,
        AddonList                      = true,
    }

    local function GetFrameLiveScale(frame)
        if frame and type(frame.GetScale) == "function" then
            local ok, s = pcall(frame.GetScale, frame)
            s = ok and SafeNum(s, nil) or nil
            if s and s > 0 then
                return s
            end
        end
        return 1.0
    end

    local function GetPlayerSpellsActiveTab(psf)
        if not psf then return nil end
        if psf.TabSystem and type(psf.TabSystem.GetSelectedTabID) == "function" then
            local ok, t = pcall(psf.TabSystem.GetSelectedTabID, psf.TabSystem)
            if ok and type(t) == "number" and t > 0 then
                return t
            end
        end
        if psf.tabSystem and type(psf.tabSystem.GetSelectedTabID) == "function" then
            local ok, t = pcall(psf.tabSystem.GetSelectedTabID, psf.tabSystem)
            if ok and type(t) == "number" and t > 0 then
                return t
            end
        end
        if type(psf.GetTab) == "function" then
            local ok, t = pcall(psf.GetTab, psf)
            if ok and type(t) == "number" and t > 0 then
                return t
            end
        end
        if psf.SpellBookFrame and psf.SpellBookFrame.IsShown and psf.SpellBookFrame:IsShown() then
            return psf.spellBookTabID or 3
        end
        if psf.TalentsFrame and psf.TalentsFrame.IsShown and psf.TalentsFrame:IsShown() then
            return psf.talentsTabID or 2
        end
        if psf.SpecFrame and psf.SpecFrame.IsShown and psf.SpecFrame:IsShown() then
            return psf.specTabID or 1
        end
        if type(psf.selectedTab) == "number" and psf.selectedTab > 0 then
            return psf.selectedTab
        end
        return nil
    end

    local function GetPlayerSpellsIsMinimized(psf)
        if not psf then return false end
        if type(psf.IsMinimized) == "function" then
            local ok, m = pcall(psf.IsMinimized, psf)
            if ok and type(m) == "boolean" then
                return m
            end
        end
        if type(psf.isMinimized) == "boolean" then
            return psf.isMinimized
        end
        if psf.MaximizeMinimizeFrame and type(psf.MaximizeMinimizeFrame.IsMinimized) == "function" then
            local ok, m = pcall(psf.MaximizeMinimizeFrame.IsMinimized, psf.MaximizeMinimizeFrame)
            if ok and type(m) == "boolean" then
                return m
            end
        end
        return false
    end

    function W.RecordPlayerSpellsUserTab(psf, explicitTabID)
        if not psf or InCombat() or DesktopWindows:IsYielding() then return end
        local fState = GetFrameState(psf)
        if not fState or fState.restoringPlayerSpellsState then return end
        local resolvedTab = (type(explicitTabID) == "number" and explicitTabID > 0 and explicitTabID)
            or GetPlayerSpellsActiveTab(psf)
        if resolvedTab then
            fState.userSelectedTabID = resolvedTab
            fState.savedTabID = resolvedTab
        end
        if not GetPlayerSpellsIsMinimized(psf) then
            fState.userIsMinimized = false
            fState.savedIsMinimized = false
        end
    end

    function W.AttachPlayerSpellsTabHooks(psf)
        if not psf then return end
        local st = GetFrameState(psf)
        if not st then return end
        local tabSys = psf.TabSystem or psf.tabSystem
        if type(tabSys) ~= "table" then return end
        if type(tabSys.SetTab) == "function" and not st.tabSysSetTabHooked and type(_G.hooksecurefunc) == "function" then
            st.tabSysSetTabHooked = true
            _G.hooksecurefunc(tabSys, "SetTab", function(_, tabID)
                if InCombat() or DesktopWindows:IsYielding() then return end
                local fState = GetFrameState(psf)
                if not fState or fState.restoringPlayerSpellsState then return end
                local overTabBar = (type(_G.MouseIsOver) == "function" and _G.MouseIsOver(tabSys)) and true or false
                local inAutoRestore = W.restoringPanels or fState.restoringFromAutoClose or W.inShowUIPanelPostHook or IsShowUIPanelOnStack()
                if W.userOpeningPlayerSpells or fState.userSelectedTabID == nil or overTabBar
                    or ((psf.IsShown and psf:IsShown()) and not inAutoRestore) then
                    W.RecordPlayerSpellsUserTab(psf, tabID)
                end
            end)
        end
        local function HookTabBtn(btn, btnTabID)
            if type(btn) ~= "table" or btn._dsTabBtnHooked or type(btn.HookScript) ~= "function" then return end
            btn._dsTabBtnHooked = true
            local resolvedBtnID = (type(btnTabID) == "number" and btnTabID)
                or btn.tabID
                or (type(btn.GetID) == "function" and btn:GetID())
                or nil
            pcall(btn.HookScript, btn, "OnClick", function()
                W.RecordPlayerSpellsUserTab(psf, resolvedBtnID)
            end)
        end
        if type(tabSys.GetTabSet) == "function" and type(tabSys.GetTabButton) == "function" then
            local okSet, tabSet = pcall(tabSys.GetTabSet, tabSys)
            if okSet and type(tabSet) == "table" then
                for _, tID in ipairs(tabSet) do
                    local okBtn, btn = pcall(tabSys.GetTabButton, tabSys, tID)
                    if okBtn and btn then
                        HookTabBtn(btn, tID)
                    end
                end
            end
        end
        if type(tabSys.tabs) == "table" then
            for idx, btn in ipairs(tabSys.tabs) do
                HookTabBtn(btn, (type(btn) == "table" and btn.tabID) or idx)
            end
        end
    end

    local function ComputePlayerSpellsNativeScale(psf)
        psf = psf or _G.PlayerSpellsFrame
        if not psf then return 0.80 end
        local st = GetFrameState(psf)
        if st and type(st.nativeScale) == "number" and st.nativeScale >= 0.50 and st.nativeScale <= 1.0 then
            return st.nativeScale
        end
        local orig = W.origUIPanelInfo["PlayerSpellsFrame"]
        local uipWin = _G.UIPanelWindows and _G.UIPanelWindows["PlayerSpellsFrame"]
        local extraW = (orig and SafeNum(orig.checkFitExtraWidth, nil))
            or (uipWin and SafeNum(uipWin.checkFitExtraWidth, nil)) or 200
        local extraH = (orig and SafeNum(orig.checkFitExtraHeight, nil))
            or (uipWin and SafeNum(uipWin.checkFitExtraHeight, nil)) or 140
        local uip = _G.UIParent
        local okUW, rawUW = uip and type(uip.GetWidth) == "function" and pcall(uip.GetWidth, uip)
        local okUH, rawUH = uip and type(uip.GetHeight) == "function" and pcall(uip.GetHeight, uip)
        local uipW = okUW and SafeNum(rawUW, 0) or 0
        local uipH = okUH and SafeNum(rawUH, 0) or 0
        local okFW, rawFW = type(psf.GetWidth) == "function" and pcall(psf.GetWidth, psf)
        local okFH, rawFH = type(psf.GetHeight) == "function" and pcall(psf.GetHeight, psf)
        local liveFW = okFW and SafeNum(rawFW, 0) or 0
        local liveFH = okFH and SafeNum(rawFH, 0) or 0
        local isMin = GetPlayerSpellsIsMinimized(psf)
        local canCache = (not isMin) and liveFW >= 1000 and liveFH >= 500
        local psfW = canCache and liveFW or 1618
        local psfH = canCache and liveFH or 898
        if uipW > 0 and uipH > 0 then
            local fit = ClampNumber(math.min(uipW / (psfW + extraW), uipH / (psfH + extraH), 1.0), 0.50, 1.0)
            local rounded = math.floor(fit * 100 + 0.5) / 100
            if st and canCache then
                st.nativeScale = rounded
            end
            return rounded
        end
        return 0.80
    end

    local function GetDefaultFrameScale(frameName, frame)
        if frameName == "PlayerSpellsFrame" or frame == _G.PlayerSpellsFrame then
            return ComputePlayerSpellsNativeScale(frame or _G.PlayerSpellsFrame)
        end
        local orig = W.origUIPanelInfo[frameName]
        return (orig and orig.defaultScale) or 1.0
    end

    local function GetCanonicalPanelDefault(frameName, frame)
        local defScale = GetDefaultFrameScale(frameName, frame)
        if CANONICAL_CENTER_PANELS[frameName] then
            return "CENTER", "CENTER", 0, 0, defScale
        end
        return "TOPLEFT", "TOPLEFT", 16, -116, defScale
    end

    local function WipeDesktopWindowEntryFromAllDBs(frameName)
        local function WipePosAndScale(dwTbl)
            if type(dwTbl) ~= "table" then return end
            if frameName then
                if type(dwTbl.positions) == "table" then dwTbl.positions[frameName] = nil end
                if type(dwTbl.scales) == "table" then dwTbl.scales[frameName] = nil end
            else
                if type(dwTbl.positions) == "table" then wipe(dwTbl.positions) else dwTbl.positions = {} end
                if type(dwTbl.scales) == "table" then wipe(dwTbl.scales) else dwTbl.scales = {} end
            end
            dwTbl.migratedFromPrep = true
        end

        local db = GetDesktopWindowsDB()
        WipePosAndScale(db)
        if _G.DynamicSuiteDB then
            WipePosAndScale(_G.DynamicSuiteDB.desktopWindows)
            if type(_G.DynamicSuiteDB.global) == "table" then
                WipePosAndScale(_G.DynamicSuiteDB.global.desktopWindows)
            end
        end
        local activeGlobal = EnsureSuiteGlobal()
        if type(activeGlobal) == "table" then
            WipePosAndScale(activeGlobal.desktopWindows)
        end
        if type(_G.DynamicLoadDB) == "table" then
            WipePosAndScale(_G.DynamicLoadDB.desktopWindows)
            if type(_G.DynamicLoadDB.globalData) == "table" and type(_G.DynamicLoadDB.globalData.theme) == "table" then
                WipePosAndScale(_G.DynamicLoadDB.globalData.theme.desktopWindows)
            end
            if type(_G.DynamicLoadDB.charData) == "table" then
                for _, cData in pairs(_G.DynamicLoadDB.charData) do
                    if type(cData) == "table" then
                        WipePosAndScale(cData.desktopWindows)
                        if type(cData.theme) == "table" then
                            WipePosAndScale(cData.theme.desktopWindows)
                            cData.theme.desktopWindows = db
                        end
                    end
                end
            end
        end

        local function WipePrepTbl(pTbl)
            if type(pTbl) ~= "table" then return end
            if frameName then
                if type(pTbl.windowPositions) == "table" then pTbl.windowPositions[frameName] = nil end
                if type(pTbl.windowScales) == "table" then pTbl.windowScales[frameName] = nil end
            else
                if type(pTbl.windowPositions) == "table" then wipe(pTbl.windowPositions) else pTbl.windowPositions = {} end
                if type(pTbl.windowScales) == "table" then wipe(pTbl.windowScales) else pTbl.windowScales = {} end
                pTbl.windowPinned = nil
            end
        end
        if type(_G.DynamicPrepDB) == "table" then
            WipePrepTbl(_G.DynamicPrepDB)
            WipePrepTbl(_G.DynamicPrepDB.global)
            WipePrepTbl(_G.DynamicPrepDB.profile)
            if type(_G.DynamicPrepDB.profiles) == "table" then
                for _, p in pairs(_G.DynamicPrepDB.profiles) do WipePrepTbl(p) end
            end
            if type(_G.DynamicPrepDB.char) == "table" then
                for _, c in pairs(_G.DynamicPrepDB.char) do WipePrepTbl(c) end
            end
        end
        if type(_G.DynamicPrep) == "table" and type(_G.DynamicPrep.db) == "table" then
            WipePrepTbl(_G.DynamicPrep.db)
        end
    end

    local function SnapshotPlayerSpellsState(psf, forceAccept)
        psf = psf or _G.PlayerSpellsFrame
        if not psf then return end
        local st = GetFrameState(psf)
        if not st or st.restoringPlayerSpellsState then return end
        local curTab = GetPlayerSpellsActiveTab(psf)
        if curTab and (forceAccept or st.userSelectedTabID == nil) then
            st.userSelectedTabID = curTab
            st.savedTabID = curTab
        end
        if forceAccept or st.userIsMinimized == nil then
            local isMin = GetPlayerSpellsIsMinimized(psf)
            st.userIsMinimized = isMin
            st.savedIsMinimized = isMin
        end
        ComputePlayerSpellsNativeScale(psf)
    end

    local function GetSuiteAccentRGB()
        if addonTable.UI and type(addonTable.UI.GetActiveAccentColor) == "function" then
            local ok, r, g, b = pcall(addonTable.UI.GetActiveAccentColor)
            if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
                return r, g, b
            end
        end
        return 0.220, 0.741, 0.973
    end

    local function GetSuiteAccentHex()
        local r, g, b = GetSuiteAccentRGB()
        return string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
    end

    local function EnsureScaleToast()
        local ar, ag, ab = GetSuiteAccentRGB()
        if W.scaleToast then
            if W.scaleToast.SetBackdropBorderColor then
                W.scaleToast:SetBackdropBorderColor(ar, ag, ab, 0.95)
            end
            if W.scaleToast.accentBar then
                W.scaleToast.accentBar:SetColorTexture(ar, ag, ab, 1.0)
            end
            return W.scaleToast
        end
        local parent = _G.UIParent
        if not parent then return nil end
        local f = CreateFrame("Frame", "DynamicSuiteWindowScaleToast", parent, "BackdropTemplate")
        f:SetSize(210, 26)
        f:SetFrameStrata("TOOLTIP")
        f:SetFrameLevel(200)
        if f.SetBackdrop then
            f:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            f:SetBackdropColor(0.043, 0.051, 0.071, 0.96)
            f:SetBackdropBorderColor(ar, ag, ab, 0.95)
        end

        local bar = f:CreateTexture(nil, "ARTWORK")
        bar:SetSize(3, 24)
        bar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
        bar:SetColorTexture(ar, ag, ab, 1.0)
        f.accentBar = bar

        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        local fontPath = (addonTable.ResolveFontChoice and addonTable.ResolveFontChoice()) or ("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.TTF")
        pcall(lbl.SetFont, lbl, fontPath, 11, "")
        lbl:SetPoint("CENTER", f, "CENTER", 2, 0)
        lbl:SetJustifyH("CENTER")
        lbl:SetWordWrap(false)
        f.label = lbl

        f.expireAt = 0
        f:SetScript("OnUpdate", function(selfToast)
            if not selfToast:IsShown() then return end
            local now = (type(_G.GetTime) == "function") and _G.GetTime() or 0
            local rem = (selfToast.expireAt or 0) - now
            if rem <= 0 then
                selfToast:SetAlpha(1)
                selfToast:Hide()
            elseif rem < 0.35 then
                selfToast:SetAlpha(ClampNumber(rem / 0.35, 0, 1))
            else
                selfToast:SetAlpha(1)
            end
        end)
        f:Hide()
        W.scaleToast = f
        return f
    end

    local function ShowWindowToast(anchorFrame, text, isSaved)
        local toast = EnsureScaleToast()
        if not toast or not text then return end
        local accHex = GetSuiteAccentHex()
        local badge = isSaved and ("|cFF" .. accHex .. "Saved|r") or "|cFFCBD5E1Session|r"
        if text:find("^Reset") then
            toast.label:SetText("|cFF" .. accHex .. text .. "|r")
        else
            toast.label:SetText(string.format("%s  |cFFFFFFFF%s|r", badge, text))
        end
        local tw = (toast.label.GetStringWidth and toast.label:GetStringWidth()) or 140
        toast:SetWidth(math.max(156, SafeNum(tw, 140) + 26))
        toast:ClearAllPoints()
        if anchorFrame and _G.UIParent then
            toast:SetPoint("BOTTOM", anchorFrame, "TOP", 0, 8)
            toast:SetClampedToScreen(true)
        elseif _G.UIParent then
            toast:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 180)
        end
        local now = (type(_G.GetTime) == "function") and _G.GetTime() or 0
        toast.expireAt = now + 1.35
        toast:SetAlpha(1)
        toast:Show()
    end

    function W.ApplyUIParentPoint(frame, pt, relPt, argX, argY)
        if InCombat() or not frame or not _G.UIParent then return false end
        return W.RawClearAndSetPoint(frame, pt, _G.UIParent, relPt, argX, argY)
    end

    local function SecureApplyPoint(frame, ux, uy, scale)
        if InCombat() or not frame or not _G.UIParent then return false, ux, uy end
        local fName = frame.GetName and frame:GetName()
        if IsWorldMapMaximized(frame, fName) then return false, ux, uy end
        local st = GetFrameState(frame)
        if st.applyingPoint then return false, ux, uy end
        local liveScale = GetFrameLiveScale(frame)
        local s = (type(liveScale) == "number" and liveScale > 0) and liveScale or ((type(scale) == "number" and scale > 0) and scale or 1.0)
        local clampedUX, clampedUY = ClampDesktopWindowOffset(frame, ux, uy, s)
        local argX = clampedUX / s
        local argY = clampedUY / s
        if not st.isDragging and type(frame.GetNumPoints) == "function" and type(frame.GetPoint) == "function" then
            local okN, numPts = pcall(frame.GetNumPoints, frame)
            if okN and numPts == 1 then
                local okP, pt, relTo, relPt, curX, curY = pcall(frame.GetPoint, frame, 1)
                if okP and pt == "CENTER" and relTo == _G.UIParent and relPt == "CENTER" then
                    curX = SafeNum(curX, nil)
                    curY = SafeNum(curY, nil)
                    if curX and curY and math.abs(curX - argX) <= 0.25 and math.abs(curY - argY) <= 0.25 then
                        return true, clampedUX, clampedUY
                    end
                end
            end
        end
        st.applyingPoint = true
        local applied = W.ApplyUIParentPoint(frame, "CENTER", "CENTER", argX, argY)
        st.applyingPoint = false
        return applied, clampedUX, clampedUY
    end

    local function SecureApplyScale(frame, scale)
        if InCombat() or not frame then return false end
        local fName = frame.GetName and frame:GetName()
        if IsWorldMapMaximized(frame, fName) then return false end
        local st = GetFrameState(frame)
        if st and st.applyingScale then return false end
        local s = ClampNumber(SafeNum(scale, 1.0), 0.50, SCALE_MAX)
        if math.abs(GetFrameLiveScale(frame) - s) <= 0.002 then
            return true
        end
        if st then st.applyingScale = true end
        local ok = W.RawSetScale(frame, s)
        if st then st.applyingScale = false end
        return ok
    end

    local function SnapshotOrigUIPanelInfo(frame, frameName)
        if W.origUIPanelInfo[frameName] then return W.origUIPanelInfo[frameName] end
        local uipInfo = (_G.UIPanelWindows and _G.UIPanelWindows[frameName]) or nil
        local attrDefined = frame.GetAttribute and frame:GetAttribute("UIPanelLayout-defined")
        local attrEnabled = frame.GetAttribute and frame:GetAttribute("UIPanelLayout-enabled")
        local attrArea = frame.GetAttribute and frame:GetAttribute("UIPanelLayout-area")
        local attrPushable = frame.GetAttribute and frame:GetAttribute("UIPanelLayout-pushable")
        local attrWhileDead = frame.GetAttribute and frame:GetAttribute("UIPanelLayout-whileDead")
        local attrCheckFit = frame.GetAttribute and frame:GetAttribute("UIPanelLayout-checkFit")
        local attrCheckFitExtraW = frame.GetAttribute and frame:GetAttribute("UIPanelLayout-checkFitExtraWidth")
        local attrCheckFitExtraH = frame.GetAttribute and frame:GetAttribute("UIPanelLayout-checkFitExtraHeight")
        local whileDead = (uipInfo and uipInfo.whileDead) or attrWhileDead
        local clamped = true
        if type(frame.IsClampedToScreen) == "function" then
            local okC, valC = pcall(frame.IsClampedToScreen, frame)
            if okC and type(valC) == "boolean" then
                clamped = valC
            end
        end
        local origStrata = (type(frame.GetFrameStrata) == "function" and frame:GetFrameStrata()) or "MEDIUM"
        local origTopLvl = (type(frame.IsToplevel) == "function" and frame:IsToplevel()) or false
        local snap = {
            uipWindowEntry      = uipInfo,
            defined             = attrDefined,
            enabled             = attrEnabled,
            area                = attrArea or (uipInfo and uipInfo.area) or (CANONICAL_CENTER_PANELS[frameName] and "center") or "left",
            pushable            = (attrPushable ~= nil and attrPushable) or (uipInfo and uipInfo.pushable),
            whileDead           = whileDead and true or false,
            rawWhileDead        = (attrWhileDead ~= nil and attrWhileDead) or (uipInfo and uipInfo.whileDead),
            checkFit            = (attrCheckFit ~= nil and attrCheckFit) or (uipInfo and uipInfo.checkFit),
            checkFitExtraWidth  = SafeNum(attrCheckFitExtraW, nil) or SafeNum(uipInfo and uipInfo.checkFitExtraWidth, nil) or 200,
            checkFitExtraHeight = SafeNum(attrCheckFitExtraH, nil) or SafeNum(uipInfo and uipInfo.checkFitExtraHeight, nil) or 140,
            clampedToScreen     = clamped,
            strata              = origStrata,
            toplevel            = origTopLvl,
            relTo               = _G.UIParent,
        }
        W.origUIPanelInfo[frameName] = snap
        local defPt, defRelPt, defX, defY, defScale = GetCanonicalPanelDefault(frameName, frame)
        snap.defaultScale = defScale or 1.0
        snap.point = defPt
        snap.relPoint = defRelPt
        snap.x = defX
        snap.y = defY
        return snap
    end

    local function CaptureFrameCenterOffset(frame, frameName)
        local uip = _G.UIParent
        if not uip or not frame or type(frame.GetCenter) ~= "function" or type(uip.GetCenter) ~= "function" then
            return nil, nil
        end
        local okF, fcX, fcY = pcall(frame.GetCenter, frame)
        local okU, ucX, ucY = pcall(uip.GetCenter, uip)
        fcX, fcY = okF and SafeNum(fcX, nil) or nil, okF and SafeNum(fcY, nil) or nil
        ucX, ucY = okU and SafeNum(ucX, nil) or nil, okU and SafeNum(ucY, nil) or nil
        if not fcX or not fcY or not ucX or not ucY then
            return nil, nil
        end
        local scale = GetFrameLiveScale(frame)
        return (fcX * scale) - ucX, (fcY * scale) - ucY
    end

    local function ApplyCanonicalDefaultPoint(frame, frameName, scale)
        if InCombat() or not frame or not _G.UIParent then return false end
        if IsWorldMapMaximized(frame, frameName) then return false end
        local st = GetFrameState(frame)
        if st and st.applyingPoint then return false end
        local orig = SnapshotOrigUIPanelInfo(frame, frameName)
        local defPt = (orig and orig.point) or "TOPLEFT"
        local defRelPt = (orig and orig.relPoint) or defPt
        local defX = (orig and orig.x) or 16
        local defY = (orig and orig.y) or -116
        local liveScale = GetFrameLiveScale(frame)
        local s = (type(liveScale) == "number" and liveScale > 0) and liveScale or ((type(scale) == "number" and scale > 0) and scale or 1.0)
        local argX = defX / s
        local argY = defY / s
        local alreadyAtCanonical = false
        if type(frame.GetNumPoints) == "function" and type(frame.GetPoint) == "function" then
            local okN, numPts = pcall(frame.GetNumPoints, frame)
            if okN and numPts == 1 then
                local okP, pt, relTo, relPt, curX, curY = pcall(frame.GetPoint, frame, 1)
                if okP and pt == defPt and relTo == _G.UIParent and relPt == defRelPt then
                    curX = SafeNum(curX, nil)
                    curY = SafeNum(curY, nil)
                    if curX and curY and math.abs(curX - argX) <= 0.25 and math.abs(curY - argY) <= 0.25 then
                        alreadyAtCanonical = true
                    end
                end
            end
        end
        local applied = true
        if not alreadyAtCanonical then
            if st then
                st.anchoredAtDefaultCenter = false
                st.applyingPoint = true
            end
            applied = W.ApplyUIParentPoint(frame, defPt, defRelPt, argX, argY)
            if st then st.applyingPoint = false end
        elseif st then
            st.anchoredAtDefaultCenter = false
        end
        return applied
    end

    function W.GetActiveWindowCustomOffset(frameName, db)
        local canDrag = (db and db.dragAnywhere ~= false)
        if canDrag and db and type(db.positions) == "table" then
            local savedPos = db.positions[frameName]
            if type(savedPos) == "table" and type(savedPos.x) == "number" and type(savedPos.y) == "number" then
                return savedPos.x, savedPos.y, true
            end
        end
        local sessPos = W.sessionPositions[frameName]
        if type(sessPos) == "table" and type(sessPos.x) == "number" and type(sessPos.y) == "number" then
            return sessPos.x, sessPos.y, false
        end
        return nil, nil, false
    end

    local function GetActiveFrameScale(frameName, frame)
        if W.sessionScales[frameName] then
            return RoundScale(W.sessionScales[frameName])
        end
        local db = GetDesktopWindowsDB()
        local saved = db and db.scales and db.scales[frameName]
        if type(saved) == "number" and saved > 0 then
            return RoundScale(saved)
        end
        return GetDefaultFrameScale(frameName, frame or (frameName and _G[frameName]))
    end

    local function IsDynamicBagsModalBlockingEscape()
        for _, name in ipairs({ "DynamicBagsDropdownMenu", "DynamicBagsGoldTransferModal", "DynamicBagsStandaloneFrame", "DynamicBagsBankFrame", "DynamicBagsFrame" }) do
            local bf = _G[name]
            if bf and bf.IsShown and bf:IsShown() then
                return true
            end
        end
        return false
    end

    local function IsHandledBySuiteReplacement(frameName)
        if frameName == "GossipFrame" or frameName == "QuestFrame" then
            local dd = _G.DynamicDialogue
            if type(dd) == "table" and type(dd.IsHandlingBlizzardFrame) == "function" then
                local ok, handled = pcall(dd.IsHandlingBlizzardFrame, dd, frameName)
                if ok and handled == true then
                    return true
                end
            end
            return false
        elseif frameName == "BankFrame" or frameName == "GuildBankFrame" then
            local dbag = _G.DynamicBags
            if type(dbag) == "table" and type(dbag.IsHandlingBlizzardFrame) == "function" then
                local ok, handled = pcall(dbag.IsHandlingBlizzardFrame, dbag, frameName)
                if ok and handled == true then
                    return true
                end
            end
            return false
        end
        return false
    end

    function W.SyncPanelLayoutDetachment(frame, frameName)
        if InCombat() or not frame or not frameName or EXCLUDED_BLIZZ_FRAMES[frameName] then return end
        if IsHandledBySuiteReplacement(frameName) then
            W.detachedPanels[frameName] = nil
            W.pendingSlotEviction[frameName] = nil
            return
        end
        local orig = SnapshotOrigUIPanelInfo(frame, frameName)
        local db = GetDesktopWindowsDB()
        local yielding = DesktopWindows:IsYielding() or DesktopWindows:IsMasterDisabled()
        local sideBySide = (not yielding) and (db and db.sideBySide ~= false)

        if W.KEEP_UIPANEL_LAYOUT[frameName] then
            if frameName == "WorldMapFrame" and type(frame.SetAttribute) == "function" then
                local curDef = frame.GetAttribute and frame:GetAttribute("UIPanelLayout-defined")
                local curMaxPt = frame.GetAttribute and frame:GetAttribute("UIPanelLayout-maximizePoint")
                if not curDef then
                    pcall(frame.SetAttribute, frame, "UIPanelLayout-defined", "1")
                end
                if not curMaxPt then
                    pcall(frame.SetAttribute, frame, "UIPanelLayout-maximizePoint", "TOP")
                end
            end
            return
        end

        if sideBySide then
            local st = GetFrameState(frame)
            local function ClearDetachedLayoutAttributes(target)
                if type(_G.UIPanelWindows) == "table" and _G.UIPanelWindows[frameName] ~= nil then
                    W.SafeRemoveTableKey(_G.UIPanelWindows, frameName)
                end
                if type(target.SetAttribute) == "function" then
                    for _, attrKey in ipairs({
                        "UIPanelLayout-defined",
                        "UIPanelLayout-enabled",
                        "UIPanelLayout-area",
                        "UIPanelLayout-pushable",
                        "UIPanelLayout-whileDead",
                        "UIPanelLayout-checkFit",
                    }) do
                        if target.GetAttribute == nil or target:GetAttribute(attrKey) ~= nil then
                            pcall(target.SetAttribute, target, attrKey, nil)
                        end
                    end
                end
            end

            ClearDetachedLayoutAttributes(frame)
            local inSlot = false
            if type(_G.GetUIPanel) == "function" then
                for _, slotName in ipairs({ "left", "center", "right", "doublewide", "fullscreen" }) do
                    local okG, slotFrame = pcall(_G.GetUIPanel, slotName)
                    if okG and slotFrame == frame then
                        inSlot = true
                        break
                    end
                end
            end
            if inSlot then
                local isShownNow = (frame.IsShown and frame:IsShown()) and true or false
                if isShownNow then
                    -- Never HideUIPanel an already-visible frame (it runs OnHide and releases Blizzard pools);
                    -- mark it for slot cleanup once the user hides it naturally.
                    W.pendingSlotEviction[frameName] = true
                elseif type(_G.HideUIPanel) == "function" and not IsShowUIPanelOnStack() and not W.inShowUIPanelPostHook then
                    if st then st.detachingFromUIPanel = true end
                    pcall(_G.HideUIPanel, frame)
                    ClearDetachedLayoutAttributes(frame)
                    if st then st.detachingFromUIPanel = false end
                    W.pendingSlotEviction[frameName] = nil
                end
            else
                W.pendingSlotEviction[frameName] = nil
            end
            W.detachedPanels[frameName] = true
            if type(frame.GetPoint) == "function" then
                local okPt, p = pcall(frame.GetPoint, frame, 1)
                if not okPt or not p then
                    local customX, customY = W.GetActiveWindowCustomOffset(frameName, db)
                    local s = GetActiveFrameScale(frameName, frame)
                    if customX and customY then
                        SecureApplyPoint(frame, customX, customY, s)
                    else
                        ApplyCanonicalDefaultPoint(frame, frameName, s)
                    end
                end
            end
        else
            if W.detachedPanels[frameName] then
                W.detachedPanels[frameName] = nil
                W.pendingSlotEviction[frameName] = nil
                if orig and orig.uipWindowEntry and type(_G.UIPanelWindows) == "table" then
                    _G.UIPanelWindows[frameName] = orig.uipWindowEntry
                end
                if orig and type(frame.SetAttribute) == "function" then
                    pcall(frame.SetAttribute, frame, "UIPanelLayout-defined", orig.defined)
                    pcall(frame.SetAttribute, frame, "UIPanelLayout-enabled", orig.enabled)
                    pcall(frame.SetAttribute, frame, "UIPanelLayout-area", orig.area)
                    pcall(frame.SetAttribute, frame, "UIPanelLayout-pushable", orig.pushable)
                    pcall(frame.SetAttribute, frame, "UIPanelLayout-whileDead", orig.rawWhileDead)
                    pcall(frame.SetAttribute, frame, "UIPanelLayout-checkFit", orig.checkFit)
                end
            end
        end
    end

    local function IsDynamicDialogueModalBlockingEscape()
        local rf = _G.DynamicDialogueReaderFrame
        return (rf and rf.IsShown and rf:IsShown()) and true or false
    end

    function W.CompactUISpecialFrames()
        local t = _G.UISpecialFrames
        if type(t) ~= "table" then return end
        local keys = {}
        for k, v in pairs(t) do
            if type(k) == "number" and k >= 1 and math.floor(k) == k then
                keys[#keys + 1] = k
            end
        end
        table.sort(keys)
        local clean = {}
        local seen = {}
        for _, k in ipairs(keys) do
            local name = t[k]
            if type(name) == "string" and name ~= "" and not seen[name] then
                seen[name] = true
                clean[#clean + 1] = name
            end
        end
        for _, k in ipairs(keys) do
            t[k] = nil
        end
        for i = 1, #clean do
            t[i] = clean[i]
        end
    end

    function W.IsInUISpecialFrames(frameName)
        if type(_G.UISpecialFrames) ~= "table" or not frameName then return false, nil end
        W.CompactUISpecialFrames()
        for i = 1, #_G.UISpecialFrames do
            if _G.UISpecialFrames[i] == frameName then
                return true, i
            end
        end
        return false, nil
    end

    function W.AddToUISpecialFrames(frameName)
        if type(_G.UISpecialFrames) ~= "table" or not frameName or EXCLUDED_BLIZZ_FRAMES[frameName] then return end
        if not W.IsInUISpecialFrames(frameName) then
            table.insert(_G.UISpecialFrames, frameName)
        end
    end

    function W.RemoveFromUISpecialFrames(frameName)
        if type(_G.UISpecialFrames) ~= "table" or not frameName then return end
        W.CompactUISpecialFrames()
        for i = #_G.UISpecialFrames, 1, -1 do
            if _G.UISpecialFrames[i] == frameName then
                table.remove(_G.UISpecialFrames, i)
            end
        end
    end

    function W.PruneZOrderStack()
        for i = #W.zOrderStack, 1, -1 do
            local name = W.zOrderStack[i]
            local bf = name and _G[name]
            if not bf or not (bf.IsShown and bf:IsShown()) or IsWorldMapMaximized(bf, name) then
                table.remove(W.zOrderStack, i)
            end
        end
        if #W.zOrderStack == 0 then
            W.lastTopFocusedWindow = nil
        end
    end

    function W.SyncHeaderOverlayLevel(frame, st)
        if not frame or not st or not st.overlay then return end
        if type(frame.GetFrameStrata) == "function" then
            local okS, curStrata = pcall(frame.GetFrameStrata, frame)
            if okS and type(curStrata) == "string" and curStrata ~= "" then
                W.RawSetFrameStrata(st.overlay, curStrata)
            end
        end
        local titleLvl = (frame.TitleContainer and frame.TitleContainer.GetFrameLevel and SafeNum(frame.TitleContainer:GetFrameLevel(), 0)) or 0
        local nineLvl = (frame.NineSlice and frame.NineSlice.GetFrameLevel and SafeNum(frame.NineSlice:GetFrameLevel(), 0)) or 0
        local frameLvl = (frame.GetFrameLevel and SafeNum(frame:GetFrameLevel(), 1)) or 1
        local baseLvl = math.max(frameLvl, titleLvl, nineLvl)
        W.RawSetFrameLevel(st.overlay, math.min(baseLvl + W.HEADER_OVERLAY_OFFSET, 65000))
    end

    local function EnsureMacroFrameChildLayering(mf, targetStrata, rootLvl)
        if InCombat() or not mf then return end
        local strata = targetStrata
        if not strata and type(mf.GetFrameStrata) == "function" then
            local okS, s = pcall(mf.GetFrameStrata, mf)
            if okS and type(s) == "string" then strata = s end
        end
        strata = strata or "HIGH"
        local baseLvl = SafeNum(rootLvl, 1) or 1
        local function PlaceChildLayer(region, minLvl, exactLvl)
            if type(region) ~= "table" or (region.IsForbidden and region:IsForbidden()) then return end
            if type(region.GetFrameStrata) == "function" then
                local okS, curS = pcall(region.GetFrameStrata, region)
                if okS and curS ~= strata then
                    W.RawSetFrameStrata(region, strata)
                end
            else
                W.RawSetFrameStrata(region, strata)
            end
            if exactLvl then
                W.RawSetFrameLevel(region, exactLvl)
            elseif minLvl then
                local curL = (type(region.GetFrameLevel) == "function") and SafeNum(region:GetFrameLevel(), 0) or 0
                if curL < minLvl then
                    W.RawSetFrameLevel(region, minLvl)
                end
            end
        end

        if mf.backdrop then
            PlaceChildLayer(mf.backdrop, nil, math.max(1, baseLvl))
        end
        local inset = mf.Inset or _G.MacroFrameInset
        if inset then
            PlaceChildLayer(inset, baseLvl + 1)
            local insetLvl = (type(inset.GetFrameLevel) == "function") and SafeNum(inset:GetFrameLevel(), baseLvl + 1) or (baseLvl + 1)
            if inset.backdrop then
                PlaceChildLayer(inset.backdrop, nil, math.max(1, insetLvl))
            end
        end

        local selector = mf.MacroSelector or _G.MacroButtonContainer
        if selector then
            PlaceChildLayer(selector, baseLvl + 5)
            local selLvl = (type(selector.GetFrameLevel) == "function") and SafeNum(selector:GetFrameLevel(), baseLvl + 5) or (baseLvl + 5)
            if selector.backdrop then
                PlaceChildLayer(selector.backdrop, nil, math.max(baseLvl + 2, selLvl - 1))
            end
            local sb = selector.ScrollBox
            if sb then
                PlaceChildLayer(sb, selLvl + 1)
                local sbLvl = (type(sb.GetFrameLevel) == "function") and SafeNum(sb:GetFrameLevel(), selLvl + 1) or (selLvl + 1)
                if type(sb.ForEachFrame) == "function" then
                    pcall(sb.ForEachFrame, sb, function(btnFrame)
                        PlaceChildLayer(btnFrame, sbLvl + 1)
                    end)
                end
            end
            if selector.ScrollBar then
                PlaceChildLayer(selector.ScrollBar, selLvl + 2)
            end
            if selector == _G.MacroButtonContainer and type(selector.GetChildren) == "function" then
                local okC, children = pcall(function() return { selector:GetChildren() } end)
                if okC and type(children) == "table" then
                    for _, child in ipairs(children) do
                        PlaceChildLayer(child, selLvl + 1)
                    end
                end
            end
        end

        local textBg = _G.MacroFrameTextBackground
        if textBg then
            PlaceChildLayer(textBg, baseLvl + 4)
            local tbLvl = (type(textBg.GetFrameLevel) == "function") and SafeNum(textBg:GetFrameLevel(), baseLvl + 4) or (baseLvl + 4)
            if textBg.backdrop then
                PlaceChildLayer(textBg.backdrop, nil, math.max(1, tbLvl))
            end
        end
        if _G.MacroFrameScrollFrame then
            PlaceChildLayer(_G.MacroFrameScrollFrame, baseLvl + 6)
        end
        if _G.MacroFrameSelectedMacroButton then
            PlaceChildLayer(_G.MacroFrameSelectedMacroButton, baseLvl + 6)
        end
    end

    local function RefreshMacroFrameAfterCombat(mf)
        mf = mf or _G.MacroFrame
        if not mf or InCombat() or not (mf.IsShown and mf:IsShown()) then return end
        local sel = mf.MacroSelector
        if sel and sel.ScrollBox and type(sel.ScrollBox.HasDataProvider) == "function" then
            local okDP, hasDP = pcall(sel.ScrollBox.HasDataProvider, sel.ScrollBox)
            local emptyGrid = (not okDP or not hasDP)
            if not emptyGrid and type(sel.ScrollBox.GetDataProviderSize) == "function" then
                local okSz, sz = pcall(sel.ScrollBox.GetDataProviderSize, sel.ScrollBox)
                if okSz and SafeNum(sz, 0) == 0 then
                    emptyGrid = true
                end
            end
            if emptyGrid then
                if (mf.macroBase or 0) > 0 and type(_G.MacroFrame_SetCharacterMacros) == "function" then
                    pcall(_G.MacroFrame_SetCharacterMacros)
                elseif type(_G.MacroFrame_SetAccountMacros) == "function" then
                    pcall(_G.MacroFrame_SetAccountMacros)
                end
            end
        end
        if type(mf.Update) == "function" then
            pcall(mf.Update, mf)
        end
        if type(_G.MacroFrame_Update) == "function" then
            pcall(_G.MacroFrame_Update)
        end
        if sel then
            if type(sel.Update) == "function" then
                pcall(sel.Update, sel)
            end
            if type(sel.UpdateSelections) == "function" then
                pcall(sel.UpdateSelections, sel)
            end
            if type(sel.UpdateAllSelected) == "function" then
                pcall(sel.UpdateAllSelected, sel)
            end
            if sel.ScrollBox and type(sel.ScrollBox.FullUpdate) == "function" then
                pcall(sel.ScrollBox.FullUpdate, sel.ScrollBox, true)
            end
        end
        if not DesktopWindows:IsYielding() then
            EnsureMacroFrameChildLayering(mf)
        end
        if _G.C_Timer and _G.C_Timer.After then
            _G.C_Timer.After(0, function()
                if InCombat() or not (_G.MacroFrame and _G.MacroFrame.IsShown and _G.MacroFrame:IsShown()) then return end
                if not DesktopWindows:IsYielding() then
                    EnsureMacroFrameChildLayering(_G.MacroFrame)
                end
            end)
        end
    end

    local NATIVE_LAYER_FRAMES = {
        ProfessionsFrame               = true,
        ProfessionsCustomerOrdersFrame = true,
        ProfessionsBookFrame           = true,
    }

    function W.NormalizeDesktopWindowLayer(frame, frameName)
        if InCombat() or not frame or EXCLUDED_BLIZZ_FRAMES[frameName] or IsWorldMapMaximized(frame, frameName) or IsHandledBySuiteReplacement(frameName) then return end
        if DesktopWindows:IsYielding() or DesktopWindows:IsMasterDisabled() then return end
        local db = GetDesktopWindowsDB()
        if not (db and db.sideBySide ~= false) then return end
        -- Complex Blizzard frames with native HIGH-strata flyouts, Spec tabs, and QualityMeter
        -- indicators (e.g. ProfessionsFrame) must keep Blizzard's native strata & FrameLevel tree.
        if NATIVE_LAYER_FRAMES[frameName] then
            local st = W.blizzWinState[frame]
            if st then
                W.SyncHeaderOverlayLevel(frame, st)
            end
            return
        end
        -- Disable C++ toplevel FrameLevel inflation so Raise() never jumps root Bg/Inset above fixed-level children (e.g. PaperDollFrame / EUI stats at level 50).
        W.RawSetToplevel(frame, false)
        -- Use HIGH strata for the top focused window and MEDIUM strata for unfocused windows.
        -- Never force Blizzard windows up to DIALOG strata, which would bury HIGH-strata Blizzard
        -- flyouts (Reagent/Salvage/Equipment flyouts), Specialization tabs, dropdowns, and popups.
        local topName = W.zOrderStack[#W.zOrderStack]
        local isFocused = (topName == nil or topName == frameName)
        local targetStrata = isFocused and "HIGH" or "MEDIUM"
        if type(frame.GetFrameStrata) == "function" then
            local okS, curStrata = pcall(frame.GetFrameStrata, frame)
            if okS and curStrata ~= targetStrata then
                W.RawSetFrameStrata(frame, targetStrata)
            end
        else
            W.RawSetFrameStrata(frame, targetStrata)
        end
        if frameName == "InspectFrame" and type(frame.TitleContainer) == "table" and type(frame.TitleContainer.GetFrameStrata) == "function" then
            local okTS, tcStrata = pcall(frame.TitleContainer.GetFrameStrata, frame.TitleContainer)
            if okTS and tcStrata ~= targetStrata then
                W.RawSetFrameStrata(frame.TitleContainer, targetStrata)
            end
        end
        -- Clamp any stray high root FrameLevel (e.g. > 15) back to 1 so fixed-level children (CharacterHeadSlot at 101, EUI_CharSheet_StatsPanel at 50, TalentLoadoutManager overlays) stay cleanly above their parent's root background.
        if type(frame.GetFrameLevel) == "function" then
            local okL, curLvl = pcall(frame.GetFrameLevel, frame)
            if not okL or type(curLvl) ~= "number" or curLvl > 15 or curLvl < 1 then
                W.RawSetFrameLevel(frame, 1)
            end
        else
            W.RawSetFrameLevel(frame, 1)
        end
        local st = W.blizzWinState[frame]
        if st then
            W.SyncHeaderOverlayLevel(frame, st)
        end
        if frameName == "MacroFrame" then
            EnsureMacroFrameChildLayering(frame, targetStrata, 1)
        end
    end

    function W.SyncAllDesktopWindowLayers()
        if InCombat() or DesktopWindows:IsYielding() or DesktopWindows:IsMasterDisabled() then return end
        local db = GetDesktopWindowsDB()
        if not (db and db.sideBySide ~= false) then return end
        for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
            if not IsHandledBySuiteReplacement(spec.name) then
                local bf = _G[spec.name]
                if bf and bf.IsShown and bf:IsShown() and not IsWorldMapMaximized(bf, spec.name) then
                    W.NormalizeDesktopWindowLayer(bf, spec.name)
                    local bSt = W.blizzWinState[bf]
                    if bSt then
                        W.SyncHeaderOverlayLevel(bf, bSt)
                    end
                end
            end
        end
    end

    function W.RemoveFromZOrderStack(frameName)
        if not frameName then return end
        for i = #W.zOrderStack, 1, -1 do
            if W.zOrderStack[i] == frameName then
                table.remove(W.zOrderStack, i)
            end
        end
        W.PruneZOrderStack()
        W.lastTopFocusedWindow = W.zOrderStack[#W.zOrderStack]
        W.SyncAllDesktopWindowLayers()
    end

    function W.GetTopMostShownWindowName(unprotectedOnly)
        W.PruneZOrderStack()
        for i = #W.zOrderStack, 1, -1 do
            local name = W.zOrderStack[i]
            local bf = _G[name]
            if bf and bf.IsShown and bf:IsShown() and not IsHandledBySuiteReplacement(name) and not IsWorldMapMaximized(bf, name) then
                if not unprotectedOnly or not (bf.IsProtected and bf:IsProtected()) then
                    return name
                end
            end
        end
        local bestName, bestSeq = nil, -1
        for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
            local bf = _G[spec.name]
            if bf and bf.IsShown and bf:IsShown() and not IsHandledBySuiteReplacement(spec.name) and not IsWorldMapMaximized(bf, spec.name) then
                if not unprotectedOnly or not (bf.IsProtected and bf:IsProtected()) then
                    local seq = W.lastShownAt[spec.name] or 0
                    if seq > bestSeq then
                        bestSeq = seq
                        bestName = spec.name
                    end
                end
            end
        end
        return bestName
    end

    function W.SyncAllUISpecialFrames(forCombat)
        if type(_G.UISpecialFrames) ~= "table" or InCombat() then return end
        W.CompactUISpecialFrames()
        for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
            if not (spec.name == "WorldMapFrame" and IsWorldMapMaximized(_G.WorldMapFrame, "WorldMapFrame")) then
                W.RemoveFromUISpecialFrames(spec.name)
            end
        end
        if DesktopWindows:IsYielding() then
            return
        end
        -- When any DynamicBags or DynamicDialogue modal window is shown, keep Blizzard desktop frames out of
        -- UISpecialFrames so ESC closes modals before Blizzard panels one at a time.
        if forCombat ~= true and (IsDynamicBagsModalBlockingEscape() or IsDynamicDialogueModalBlockingEscape()) then
            return
        end
        local db = GetDesktopWindowsDB()
        if forCombat == true then
            local topUnprot = W.GetTopMostShownWindowName(true)
            if topUnprot then
                W.AddToUISpecialFrames(topUnprot)
            end
            return
        end
        if db and db.sideBySide ~= false then
            local topName = W.GetTopMostShownWindowName(false)
            if topName then
                W.AddToUISpecialFrames(topName)
            end
        else
            for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
                if W.detachedPanels[spec.name] and not IsHandledBySuiteReplacement(spec.name) then
                    local bf = _G[spec.name]
                    if bf and bf.IsShown and bf:IsShown() and not IsWorldMapMaximized(bf, spec.name) then
                        W.AddToUISpecialFrames(spec.name)
                    end
                end
            end
        end
    end
    DesktopWindows.CompactUISpecialFrames = W.CompactUISpecialFrames
    DesktopWindows.SyncAllUISpecialFrames = W.SyncAllUISpecialFrames

    function W.FocusAndRaiseDesktopWindow(frame, frameName)
        if InCombat() or not frame or not frameName or EXCLUDED_BLIZZ_FRAMES[frameName] or IsWorldMapMaximized(frame, frameName) or IsHandledBySuiteReplacement(frameName) then return end
        if DesktopWindows:IsYielding() then return end
        local db = GetDesktopWindowsDB()
        if not (db and db.sideBySide ~= false) then return end
        W.PruneZOrderStack()
        local curTop = W.zOrderStack[#W.zOrderStack]
        if curTop == frameName and W.lastTopFocusedWindow == frameName then
            if (W.lastShownAt[frameName] or 0) < W.showSeqCounter then
                W.showSeqCounter = W.showSeqCounter + 1
                W.lastShownAt[frameName] = W.showSeqCounter
            end
            W.NormalizeDesktopWindowLayer(frame, frameName)
            W.SyncAllUISpecialFrames()
            return
        end
        for i = #W.zOrderStack, 1, -1 do
            if W.zOrderStack[i] == frameName then
                table.remove(W.zOrderStack, i)
            end
        end
        W.zOrderStack[#W.zOrderStack + 1] = frameName
        W.showSeqCounter = W.showSeqCounter + 1
        W.lastShownAt[frameName] = W.showSeqCounter
        W.SyncAllDesktopWindowLayers()
        W.NormalizeDesktopWindowLayer(frame, frameName)
        local st = W.blizzWinState[frame]
        if st then
            W.SyncHeaderOverlayLevel(frame, st)
        end
        W.lastTopFocusedWindow = frameName
        W.SyncAllUISpecialFrames()
    end

    function W.HasNewerShownPanel(targetName)
        W.PruneZOrderStack()
        local targetIdx = nil
        for i = 1, #W.zOrderStack do
            if W.zOrderStack[i] == targetName then
                targetIdx = i
                break
            end
        end
        if targetIdx and targetIdx < #W.zOrderStack then
            return true
        end
        local targetSeq = W.lastShownAt[targetName] or 0
        for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
            if spec.name ~= targetName and not IsHandledBySuiteReplacement(spec.name) then
                local bf = _G[spec.name]
                if bf and bf.IsShown and bf:IsShown() and not IsWorldMapMaximized(bf, spec.name) and (W.lastShownAt[spec.name] or 0) > targetSeq then
                    return true
                end
            end
        end
        return false
    end

    W.combatEscList = W.combatEscList or {}

    function W.RebuildCombatEscapeRing()
        if InCombat() then return end
        local list = W.combatEscList
        local n = #list
        for i = 1, n do
            local b = list[i]
            local nxt = list[(i % n) + 1]
            if b and type(b.SetFrameRef) == "function" then
                pcall(b.SetFrameRef, b, "ringNext", (nxt ~= b) and nxt or nil)
            end
        end
    end

    function W.EnsureCombatEscapeButton(frame, frameName)
        if InCombat() or not frame or not frameName then return nil end
        if W.combatEscHandlers[frame] then return W.combatEscHandlers[frame] end
        W.combatEscCounter = W.combatEscCounter + 1
        local btnName = "DynamicSuiteDesktopEscBtn" .. tostring(W.combatEscCounter)
        local ok, btn = pcall(CreateFrame, "Button", btnName, frame, "SecureHandlerShowHideTemplate,SecureHandlerClickTemplate,SecureHandlerStateTemplate")
        if not ok or not btn then return nil end
        W.combatEscHandlers[frame] = btn
        table.insert(W.combatEscList, btn)
        if type(btn.SetSize) == "function" then btn:SetSize(1, 1) end
        if type(btn.SetPoint) == "function" then btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0) end
        if type(btn.EnableMouse) == "function" then btn:EnableMouse(false) end
        if type(btn.SetFrameRef) == "function" then
            pcall(btn.SetFrameRef, btn, "panel", frame)
        end
        if type(btn.SetAttribute) == "function" then
            pcall(btn.SetAttribute, btn, "dsCombatEscReady", false)
            pcall(btn.SetAttribute, btn, "_onclick", [[
                self:ClearBindings()
                local p = self:GetFrameRef("panel")
                if p and p:IsShown() then
                    p:Hide()
                end
            ]])
            pcall(btn.SetAttribute, btn, "_onstate-combat", [[
                if newstate == 1 then
                    if self:GetAttribute("dsCombatEscReady") and self:IsVisible() then
                        self:SetBindingClick(true, "ESCAPE", self)
                    end
                else
                    self:ClearBindings()
                end
            ]])
            pcall(btn.SetAttribute, btn, "_onshow", [[
                if PlayerInCombat() and self:GetAttribute("dsCombatEscReady") then
                    self:SetBindingClick(true, "ESCAPE", self)
                end
            ]])
            pcall(btn.SetAttribute, btn, "_onhide", [[
                self:ClearBindings()
                if PlayerInCombat() then
                    local nxt = self:GetFrameRef("ringNext")
                    local guard = 0
                    while nxt and nxt ~= self and guard < 48 do
                        guard = guard + 1
                        if nxt:GetAttribute("dsCombatEscReady") and nxt:IsVisible() then
                            nxt:SetBindingClick(true, "ESCAPE", nxt)
                            break
                        end
                        nxt = nxt:GetFrameRef("ringNext")
                    end
                end
            ]])
        end
        if type(_G.RegisterStateDriver) == "function" then
            pcall(_G.RegisterStateDriver, btn, "combat", "[combat] 1; 0")
        end
        W.RebuildCombatEscapeRing()
        return btn
    end

    function W.SyncCombatEscapeHandlers(enteringCombat)
        if InCombat() then return end
        for _, btn in pairs(W.combatEscHandlers) do
            if type(_G.ClearOverrideBindings) == "function" then
                pcall(_G.ClearOverrideBindings, btn)
            end
        end
        if enteringCombat ~= true then
            W.RebuildCombatEscapeRing()
        end
    end

    local function RestorePlayerSpellsFrameState(psf)
        psf = psf or _G.PlayerSpellsFrame
        if not psf or InCombat() or DesktopWindows:IsYielding() then return end
        local db = GetDesktopWindowsDB()
        if not (db and db.sideBySide ~= false) then return end
        if not (psf.IsShown and psf:IsShown()) then return end
        local st = GetFrameState(psf)
        if not st or st.restoringPlayerSpellsState then return end
        st.restoringPlayerSpellsState = true

        local wantMin = (st.userIsMinimized == true)
        local curMin = GetPlayerSpellsIsMinimized(psf)
        if curMin ~= wantMin then
            if not wantMin then
                if type(psf.SetMinimized) == "function" then
                    pcall(psf.SetMinimized, psf, false)
                end
                if psf.MaximizeMinimizeFrame and type(psf.MaximizeMinimizeFrame.Maximize) == "function" and GetPlayerSpellsIsMinimized(psf) then
                    pcall(psf.MaximizeMinimizeFrame.Maximize, psf.MaximizeMinimizeFrame)
                end
            else
                if type(psf.SetMinimized) == "function" then
                    pcall(psf.SetMinimized, psf, true)
                end
                if psf.MaximizeMinimizeFrame and type(psf.MaximizeMinimizeFrame.Minimize) == "function" and not GetPlayerSpellsIsMinimized(psf) then
                    pcall(psf.MaximizeMinimizeFrame.Minimize, psf.MaximizeMinimizeFrame)
                end
            end
        end

        local wantTab = st.userSelectedTabID or st.savedTabID
        if wantTab ~= nil and type(psf.SetTab) == "function" then
            local curTab = GetPlayerSpellsActiveTab(psf)
            if curTab ~= wantTab then
                pcall(psf.SetTab, psf, wantTab)
            end
        end

        local targetScale = GetActiveFrameScale("PlayerSpellsFrame", psf)
        local liveScale = GetFrameLiveScale(psf)
        if math.abs(liveScale - targetScale) > 0.005 then
            SecureApplyScale(psf, targetScale)
        end

        st.restoringPlayerSpellsState = false
    end

    function W.SyncFrameClamping(frame, frameName)
        if InCombat() or not frame or IsWorldMapMaximized(frame, frameName) or IsHandledBySuiteReplacement(frameName) then return end
        if W.IsTaintSensitiveFrame(frame, frameName) then return end
        if type(frame.SetClampedToScreen) == "function" then
            pcall(frame.SetClampedToScreen, frame, true)
        end
        if type(frame.SetClampRectInsets) == "function" then
            pcall(frame.SetClampRectInsets, frame, 0, 0, 0, 0)
        end
    end

    local function ClampAndReanchorFrame(frame, frameName)
        if InCombat() or not frame or not frameName or EXCLUDED_BLIZZ_FRAMES[frameName] or IsWorldMapMaximized(frame, frameName) or IsHandledBySuiteReplacement(frameName) then return end
        if DesktopWindows:IsYielding() then return end
        local st = GetFrameState(frame)
        if st and st.isDragging then return end
        W.SyncFrameClamping(frame, frameName)
        local db = GetDesktopWindowsDB()
        if not db then return end
        local scale = GetActiveFrameScale(frameName, frame)
        local customX, customY = W.GetActiveWindowCustomOffset(frameName, db)
        if customX and customY then
            local cx, cy = ClampDesktopWindowOffset(frame, customX, customY, scale)
            SecureApplyPoint(frame, cx, cy, scale)
        elseif frame.IsShown and frame:IsShown() then
            local fx, fy = CaptureFrameCenterOffset(frame, frameName)
            if fx and fy then
                local cx, cy = ClampDesktopWindowOffset(frame, fx, fy, scale)
                if math.abs(cx - fx) > 0.5 or math.abs(cy - fy) > 0.5 then
                    SecureApplyPoint(frame, cx, cy, scale)
                end
            end
        end
    end

    local function StepBlizzardFrameScale(frame, frameName, delta, savePermanent)
        if not frame or not frameName or InCombat() or IsWorldMapMaximized(frame, frameName) then return false end
        if DesktopWindows:IsYielding() then return false end
        local db = GetDesktopWindowsDB()
        if not (db and db.scrollScale ~= false) then return false end
        if type(delta) ~= "number" or delta == 0 then return false end

        local step = (delta > 0) and SCALE_STEP or -SCALE_STEP
        local curScale = GetActiveFrameScale(frameName, frame)
        local newScale = RoundScale(curScale + step)
        local persist = (savePermanent == true)

        local preFX, preFY = CaptureFrameCenterOffset(frame, frameName)

        if persist then
            db.scales = type(db.scales) == "table" and db.scales or {}
            db.scales[frameName] = newScale
            W.sessionScales[frameName] = nil
        else
            W.sessionScales[frameName] = newScale
        end

        if frameName == "PlayerSpellsFrame" then
            W.SyncPanelLayoutDetachment(frame, frameName)
        end
        SecureApplyScale(frame, newScale)
        local savedPos = db.positions and db.positions[frameName]
        if savedPos and type(savedPos.x) == "number" and type(savedPos.y) == "number" then
            local _, cx, cy = SecureApplyPoint(frame, savedPos.x, savedPos.y, newScale)
            if persist and cx and cy then
                savedPos.x = math.floor(cx * 100 + 0.5) / 100
                savedPos.y = math.floor(cy * 100 + 0.5) / 100
            end
        else
            local sessPos = W.sessionPositions[frameName]
            local fx, fy = (sessPos and sessPos.x) or preFX, (sessPos and sessPos.y) or preFY
            if not fx or not fy then
                fx, fy = CaptureFrameCenterOffset(frame, frameName)
            end
            if fx and fy then
                local _, cx, cy = SecureApplyPoint(frame, fx, fy, newScale)
                if cx and cy then
                    W.sessionPositions[frameName] = { x = cx, y = cy }
                end
            end
        end
        ShowWindowToast(frame, string.format("Scale: %d%%", math.floor(newScale * 100 + 0.5)), persist)
        return true
    end

    local function HandleManagedWindowMouseWheel(rootFrame, frameName, delta)
        if not rootFrame or not frameName then return end
        if InCombat() or DesktopWindows:IsYielding() or IsWorldMapMaximized(rootFrame, frameName) then return end
        local db = GetDesktopWindowsDB()
        if not (db and db.scrollScale ~= false) then return end
        if not (_G.IsControlKeyDown and _G.IsControlKeyDown()) then return end
        local st = GetFrameState(rootFrame)
        local now = (type(_G.GetTime) == "function") and _G.GetTime() or 0
        if st and st.lastWheelAt and (now - st.lastWheelAt) < 0.015 then
            return
        end
        if st then
            st.lastWheelAt = now
        end
        local savePermanent = (_G.IsShiftKeyDown and _G.IsShiftKeyDown()) and true or false
        StepBlizzardFrameScale(rootFrame, frameName, delta, savePermanent)
    end

    local function HookMouseWheelTarget(targetRegion, rootFrame, frameName)
        if type(targetRegion) ~= "table" or targetRegion._dsWheelHooked then return end
        if type(targetRegion.HookScript) ~= "function" then return end
        targetRegion._dsWheelHooked = true
        if not InCombat() and type(targetRegion.EnableMouseWheel) == "function" then
            pcall(targetRegion.EnableMouseWheel, targetRegion, true)
        end
        pcall(targetRegion.HookScript, targetRegion, "OnMouseWheel", function(_, delta)
            HandleManagedWindowMouseWheel(rootFrame, frameName, delta)
        end)
    end

    local function AttachPlayerSpellsSubCanvasWheelHooks()
        -- Intentionally no-op: never capture mousewheel on TalentsFrame, SpellBookFrame, or SpecFrame.
        -- Ctrl+Shift+Scroll scaling is handled on modifier hold via SyncCtrlWheelOverlay.
    end

    local function EnsureScrollRegionWheelEnabled(region)
        if type(region) ~= "table" then return end
        if region.IsForbidden and region:IsForbidden() then return end
        if type(region.EnableMouseWheel) == "function" then
            local isEnabled = true
            if type(region.IsMouseWheelEnabled) == "function" then
                local okE, val = pcall(region.IsMouseWheelEnabled, region)
                if okE then isEnabled = (val == true) end
            end
            if not isEnabled then
                pcall(region.EnableMouseWheel, region, true)
            end
        end
    end

    local function DisableRootWheelCapture(region)
        if type(region) ~= "table" then return end
        if region.IsForbidden and region:IsForbidden() then return end
        if type(region.EnableMouseWheel) == "function" then
            local isEnabled = false
            if type(region.IsMouseWheelEnabled) == "function" then
                local okE, val = pcall(region.IsMouseWheelEnabled, region)
                if okE then isEnabled = (val == true) end
            end
            if isEnabled then
                pcall(region.EnableMouseWheel, region, false)
            end
        end
    end

    local function EnsureEncounterJournalScrollBoxesWheelEnabled(ej)
        if InCombat() or DesktopWindows:IsYielding() then return end
        ej = ej or _G.EncounterJournal
        if type(ej) ~= "table" or (ej.IsForbidden and ej:IsForbidden()) then return end

        -- Keep root EncounterJournal and full-frame passive chrome from swallowing wheel input
        -- intended for child scroll containers (Overview, Abilities, Loot, Lore/Boss lists).
        DisableRootWheelCapture(ej)
        for _, chromeKey in ipairs({ "NineSlice", "Bg", "Inset", "inset", "LeftInset", "RightInset", "BottomInset", "BorderFrame" }) do
            if type(ej[chromeKey]) == "table" then
                DisableRootWheelCapture(ej[chromeKey])
            end
        end

        EnsureScrollRegionWheelEnabled(ej.instanceSelect and ej.instanceSelect.ScrollBox)
        EnsureScrollRegionWheelEnabled(ej.MonthlyActivitiesFrame and ej.MonthlyActivitiesFrame.ScrollBox)
        EnsureScrollRegionWheelEnabled(ej.JourneysFrame and ej.JourneysFrame.ScrollBox)
        EnsureScrollRegionWheelEnabled(ej.JourneysFrame and ej.JourneysFrame.JourneysList)
        EnsureScrollRegionWheelEnabled(ej.TutorialsFrame and ej.TutorialsFrame.ScrollBox)
        EnsureScrollRegionWheelEnabled(ej.LootJournal and ej.LootJournal.ScrollBox)
        EnsureScrollRegionWheelEnabled(ej.LootJournal and ej.LootJournal.PowersFrame and ej.LootJournal.PowersFrame.ScrollBox)
        EnsureScrollRegionWheelEnabled(ej.LootJournalItems and ej.LootJournalItems.ItemSetsFrame and ej.LootJournalItems.ItemSetsFrame.ScrollBox)

        local enc = ej.encounter
        if type(enc) == "table" then
            local info = enc.info
            if type(info) == "table" then
                EnsureScrollRegionWheelEnabled(info.BossesScrollBox)
                EnsureScrollRegionWheelEnabled(info.overviewScroll)
                EnsureScrollRegionWheelEnabled(info.detailsScroll)
                EnsureScrollRegionWheelEnabled(info.LootContainer and info.LootContainer.ScrollBox)
            end
            local inst = enc.instance
            if type(inst) == "table" then
                EnsureScrollRegionWheelEnabled(inst.loreScroll)
            end
        end

        EnsureScrollRegionWheelEnabled(_G.EncounterJournalEncounterFrameInfoOverviewScrollFrame)
        EnsureScrollRegionWheelEnabled(_G.EncounterJournalEncounterFrameInfoDetailsScrollFrame)
        EnsureScrollRegionWheelEnabled(_G.EncounterJournalEncounterFrameInstanceLoreScrollFrame)
        EnsureScrollRegionWheelEnabled(_G.EncounterJournalEncounterFrameInfoLootContainerScrollBox)
        EnsureScrollRegionWheelEnabled(_G.EncounterJournalSearchResults and _G.EncounterJournalSearchResults.ScrollBox)
    end

    local function IsPointOverFrame(f)
        if not f or not (f.IsShown and f:IsShown()) then return false end
        if type(_G.MouseIsOver) == "function" then
            local ok, over = pcall(_G.MouseIsOver, f)
            if ok and over == true then return true end
        end
        return false
    end

    local function FindTopHoveredManagedWindow()
        if InCombat() or DesktopWindows:IsYielding() then return nil, nil end
        local db = GetDesktopWindowsDB()
        if not (db and db.scrollScale ~= false) then return nil, nil end
        if not (_G.IsControlKeyDown and _G.IsControlKeyDown() and _G.IsShiftKeyDown and _G.IsShiftKeyDown()) then
            return nil, nil
        end
        W.PruneZOrderStack()
        for i = #W.zOrderStack, 1, -1 do
            local name = W.zOrderStack[i]
            local bf = name and _G[name]
            if bf and IsPointOverFrame(bf) and not IsHandledBySuiteReplacement(name) and not IsWorldMapMaximized(bf, name) then
                return bf, name
            end
        end
        for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
            local name = spec.name
            local bf = _G[name]
            if bf and IsPointOverFrame(bf) and not IsHandledBySuiteReplacement(name) and not IsWorldMapMaximized(bf, name) then
                return bf, name
            end
        end
        return nil, nil
    end

    local function EnsureCtrlWheelOverlay()
        if W.ctrlWheelOverlay then return W.ctrlWheelOverlay end
        local uip = _G.UIParent
        if not uip then return nil end
        local cov = CreateFrame("Frame", "DynamicSuiteDesktopWindowsCtrlWheelOverlay", uip)
        cov:SetFrameStrata("TOOLTIP")
        cov:EnableMouse(false)
        cov:EnableMouseWheel(false)
        cov:SetScript("OnMouseWheel", function(selfCov, delta)
            if selfCov.targetFrame and selfCov.targetName then
                HandleManagedWindowMouseWheel(selfCov.targetFrame, selfCov.targetName, delta)
            end
        end)
        cov:Hide()
        W.ctrlWheelOverlay = cov
        return cov
    end

    local function SyncCtrlWheelOverlay()
        local anyShown = false
        for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
            local bf = _G[spec.name]
            if bf and bf.IsShown and bf:IsShown() and not IsHandledBySuiteReplacement(spec.name) and not IsWorldMapMaximized(bf, spec.name) then
                anyShown = true
                break
            end
        end
        local db = GetDesktopWindowsDB()
        local ctrlShiftHeld = (_G.IsControlKeyDown and _G.IsControlKeyDown() and _G.IsShiftKeyDown and _G.IsShiftKeyDown()) and true or false
        if not anyShown or InCombat() or DesktopWindows:IsYielding() or not (db and db.scrollScale ~= false) or not ctrlShiftHeld then
            local cov = W.ctrlWheelOverlay
            if cov then
                cov.targetFrame = nil
                cov.targetName = nil
                cov:SetScript("OnUpdate", nil)
                cov:EnableMouseWheel(false)
                cov:Hide()
            end
            return
        end
        local cov = EnsureCtrlWheelOverlay()
        if not cov then return end
        local targetFrame, targetName = FindTopHoveredManagedWindow()
        cov:ClearAllPoints()
        if targetFrame then
            cov.targetFrame = targetFrame
            cov.targetName = targetName
            cov:SetAllPoints(targetFrame)
            cov:EnableMouseWheel(true)
        else
            cov.targetFrame = nil
            cov.targetName = nil
            cov:SetSize(1, 1)
            cov:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", -20, -20)
            cov:EnableMouseWheel(false)
        end
        cov:Show()
        if not cov:GetScript("OnUpdate") then
            local acc = 0
            cov:SetScript("OnUpdate", function(_, elapsed)
                acc = acc + (elapsed or 0)
                if acc < 0.05 then return end
                acc = 0
                SyncCtrlWheelOverlay()
            end)
        end
    end

    local function EnsureDragDriverFrame()
        if W.dragDriverFrame then return W.dragDriverFrame end
        local f = CreateFrame("Frame", "DynamicSuiteDesktopWindowsDragDriver", _G.UIParent)
        f:SetSize(1, 1)
        f:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 0, 0)
        f:Show()
        W.dragDriverFrame = f
        return f
    end

    local function EnsureHeaderOverlay(frame, frameName)
        local st = GetFrameState(frame)
        if st.overlay then return st end

        local ov = CreateFrame("Frame", nil, frame)
        ov._dsPassiveChrome = true
        ov:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -2)
        ov:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -58, -2)
        ov:SetHeight(28)
        st.overlay = ov
        W.SyncHeaderOverlayLevel(frame, st)

        local function BeginBlizzFrameDrag(frameObj, fName, state, initCurX, initCurY)
            if InCombat() or DesktopWindows:IsYielding() or IsWorldMapMaximized(frameObj, fName) then return end
            local db = GetDesktopWindowsDB()
            if not (db and db.dragAnywhere ~= false) then return end
            local uip = _G.UIParent
            if not uip or not frameObj then return end
            if state.isDragging then return end

            W.pendingDragWatch = nil
            state.isDragging = true
            if type(frameObj.StopMovingOrSizing) == "function" then
                pcall(frameObj.StopMovingOrSizing, frameObj)
            end
            W.FocusAndRaiseDesktopWindow(frameObj, fName)
            if not W.IsTaintSensitiveFrame(frameObj, fName) and type(frameObj.SetMovable) == "function" then
                pcall(frameObj.SetMovable, frameObj, true)
            end
            W.SyncFrameClamping(frameObj, fName)

            local s = GetActiveFrameScale(fName, frameObj)
            local startUX, startUY = CaptureFrameCenterOffset(frameObj, fName)
            if not startUX or not startUY then
                local customX, customY = W.GetActiveWindowCustomOffset(fName, db)
                startUX = customX or 0
                startUY = customY or 0
            end
            startUX, startUY = ClampDesktopWindowOffset(frameObj, startUX, startUY, s)

            local curX, curY = SafeNum(initCurX, nil), SafeNum(initCurY, nil)
            if (not curX or not curY) and type(_G.GetCursorPosition) == "function" then
                local cx, cy = _G.GetCursorPosition()
                curX, curY = SafeNum(cx, 0), SafeNum(cy, 0)
            end
            curX, curY = curX or 0, curY or 0
            local uipEff = SafeNum(uip.GetEffectiveScale and uip:GetEffectiveScale(), 1)
            if uipEff <= 0 then uipEff = 1 end

            state.dragScale       = s
            state.dragStartCurX   = curX
            state.dragStartCurY   = curY
            state.dragStartUX     = startUX
            state.dragStartUY     = startUY
            state.grabOffsetX     = startUX - (curX / uipEff)
            state.grabOffsetY     = startUY - (curY / uipEff)
            state.lastAppliedUX   = startUX
            state.lastAppliedUY   = startUY
            state.usingNativeMove = false

            SecureApplyPoint(frameObj, startUX, startUY, s)

            local driver = EnsureDragDriverFrame()
            if driver and driver.SetScript then
                driver:Show()
                driver:SetScript("OnUpdate", function(selfDrv)
                    if not state.isDragging or InCombat() or DesktopWindows:IsYielding() or IsWorldMapMaximized(frameObj, fName) then
                        selfDrv:SetScript("OnUpdate", nil)
                        if state.isDragging and state.finishDrag then
                            state.finishDrag()
                        end
                        return
                    end
                    if type(_G.IsMouseButtonDown) == "function" and not _G.IsMouseButtonDown("LeftButton") then
                        selfDrv:SetScript("OnUpdate", nil)
                        if state.finishDrag then
                            state.finishDrag()
                        end
                        return
                    end
                    if type(_G.GetCursorPosition) ~= "function" then return end
                    local nx, ny = _G.GetCursorPosition()
                    nx, ny = SafeNum(nx, nil), SafeNum(ny, nil)
                    if not nx or not ny then return end
                    local eff = SafeNum(uip.GetEffectiveScale and uip:GetEffectiveScale(), 1)
                    if eff <= 0 then eff = 1 end
                    local rawUX = (nx / eff) + (state.grabOffsetX or 0)
                    local rawUY = (ny / eff) + (state.grabOffsetY or 0)
                    local dragScale = state.dragScale or s
                    local targetUX, targetUY = ClampDesktopWindowOffset(frameObj, rawUX, rawUY, dragScale)
                    if math.abs(targetUX - (state.lastAppliedUX or targetUX)) >= 0.20 or math.abs(targetUY - (state.lastAppliedUY or targetUY)) >= 0.20 then
                        state.lastAppliedUX = targetUX
                        state.lastAppliedUY = targetUY
                        SecureApplyPoint(frameObj, targetUX, targetUY, dragScale)
                    end
                end)
            end
        end

        local function FinishBlizzFrameDrag(frameObj, fName, state)
            W.pendingDragWatch = nil
            if W.dragDriverFrame and W.dragDriverFrame.SetScript then
                W.dragDriverFrame:SetScript("OnUpdate", nil)
            end
            if state and state.overlay and state.overlay.SetScript then
                state.overlay:SetScript("OnUpdate", nil)
            end
            if not InCombat() and frameObj and type(frameObj.StopMovingOrSizing) == "function" then
                pcall(frameObj.StopMovingOrSizing, frameObj)
            end
            if not state or not state.isDragging then return end
            state.isDragging = false
            state.usingNativeMove = nil
    if InCombat() then return end
            local db = GetDesktopWindowsDB()
            local uip = _G.UIParent
            if not db or not uip or not frameObj or IsWorldMapMaximized(frameObj, fName) then return end
            local scale = GetActiveFrameScale(fName, frameObj)
            local ux = state.lastAppliedUX
            local uy = state.lastAppliedUY
            if type(ux) ~= "number" or type(uy) ~= "number" then
                local fx, fy = CaptureFrameCenterOffset(frameObj, fName)
                if fx and fy then
                    ux, uy = fx, fy
                else
                    ux = state.dragStartUX or 0
                    uy = state.dragStartUY or 0
                end
            end
            ux, uy = ClampDesktopWindowOffset(frameObj, ux, uy, scale)
            local finalUX = math.floor(ux * 100 + 0.5) / 100
            local finalUY = math.floor(uy * 100 + 0.5) / 100
            state.grabOffsetX = nil
            state.grabOffsetY = nil
            state.lastAppliedUX = nil
            state.lastAppliedUY = nil
            W.sessionPositions[fName] = nil
            db.positions = type(db.positions) == "table" and db.positions or {}
            db.positions[fName] = {
                point    = "CENTER",
                relPoint = "CENTER",
                x        = finalUX,
                y        = finalUY,
            }
            SecureApplyPoint(frameObj, finalUX, finalUY, scale)
        end

        st.beginDrag = function(initX, initY) BeginBlizzFrameDrag(frame, frameName, st, initX, initY) end
        st.finishDrag = function() FinishBlizzFrameDrag(frame, frameName, st) end

        ov:RegisterForDrag("LeftButton")
        ov:SetScript("OnMouseDown", function()
            if InCombat() or DesktopWindows:IsYielding() then return end
            W.FocusAndRaiseDesktopWindow(frame, frameName)
        end)
        ov:SetScript("OnDragStart", function(_, button)
            if button and button ~= "LeftButton" then return end
            BeginBlizzFrameDrag(frame, frameName, st)
        end)
        ov:SetScript("OnDragStop", function()
            FinishBlizzFrameDrag(frame, frameName, st)
        end)
        ov:SetScript("OnHide", function()
            FinishBlizzFrameDrag(frame, frameName, st)
        end)
        ov:SetScript("OnMouseUp", function(selfOv, button)
            if button ~= "RightButton" then return end
            if InCombat() or DesktopWindows:IsYielding() then return end
            if type(_G.MouseIsOver) == "function" and not _G.MouseIsOver(selfOv) then return end
            DesktopWindows:ResetSingleWindow(frameName, true)
        end)
        ov:SetScript("OnMouseWheel", function(_, delta)
            HandleManagedWindowMouseWheel(frame, frameName, delta)
        end)
        ov:SetScript("OnEnter", function(selfOv)
            if InCombat() or DesktopWindows:IsYielding() then return end
            if not _G.GameTooltip then return end
            local db = GetDesktopWindowsDB()
            local canDrag = db and (db.dragAnywhere ~= false)
            local canScale = db and (db.scrollScale ~= false)
            if not canDrag and not canScale then return end
            local ar, ag, ab = GetSuiteAccentRGB()
            _G.GameTooltip:SetOwner(selfOv, "ANCHOR_TOP")
            _G.GameTooltip:AddLine("DynamicSuite Window Controls", ar, ag, ab)
            if canDrag then
                _G.GameTooltip:AddLine("Left-Drag Header or Empty Space: Move and save position", 0.90, 0.93, 0.96)
            end
            if canScale then
                _G.GameTooltip:AddLine("Ctrl + Scroll Header: Scale this session (70%-140%)", 0.90, 0.93, 0.96)
                _G.GameTooltip:AddLine("Ctrl + Shift + Scroll Anywhere: Save permanent scale", 0.90, 0.93, 0.96)
            end
            _G.GameTooltip:AddLine("Right-Click Header: Reset position & scale", 0.65, 0.72, 0.80)
            _G.GameTooltip:Show()
        end)
        ov:SetScript("OnLeave", function()
            if _G.GameTooltip then _G.GameTooltip:Hide() end
        end)

        return st
    end

    local function NeutraliseTitleContainerDrag(frame, frameName, st)
        if not frame or not frame.TitleContainer or InCombat() or IsWorldMapMaximized(frame, frameName) then return end
        if DesktopWindows:IsYielding() then return end
        local db = GetDesktopWindowsDB()
        if not (db and db.dragAnywhere ~= false) then return end
        local tc = frame.TitleContainer
        tc._dsPassiveChrome = true
        if tc._dsDragHooked then return end
        tc._dsDragHooked = true
        if type(tc.RegisterForDrag) == "function" then
            pcall(tc.RegisterForDrag, tc, "LeftButton")
        end
        if type(tc.SetScript) == "function" then
            pcall(tc.SetScript, tc, "OnDragStart", function(_, button)
                if button and button ~= "LeftButton" then return end
                if st and st.beginDrag then st.beginDrag() end
            end)
            pcall(tc.SetScript, tc, "OnDragStop", function()
                if st and st.finishDrag then st.finishDrag() end
            end)
        end
        if type(tc.HookScript) == "function" then
            pcall(tc.HookScript, tc, "OnMouseUp", function(selfTC, button)
                if button ~= "RightButton" then return end
                if InCombat() or DesktopWindows:IsYielding() then return end
                if type(_G.MouseIsOver) == "function" and not _G.MouseIsOver(selfTC) then return end
                DesktopWindows:ResetSingleWindow(frameName, true)
            end)
        end
        HookMouseWheelTarget(tc, frame, frameName)
    end

    local function AttachPassiveChromeDragHooks(frame, frameName, st)
        if not frame or not st then return end
        local chromeKeys = { "NineSlice", "Bg", "Inset", "LeftInset", "RightInset", "BottomInset", "TitleContainer", "BorderFrame" }
        for _, key in ipairs(chromeKeys) do
            local child = frame[key]
            if type(child) == "table" and not child._dsPassiveChromeHooked then
                child._dsPassiveChrome = true
                child._dsPassiveChromeHooked = true
                if key == "TitleContainer" then
                    NeutraliseTitleContainerDrag(frame, frameName, st)
                else
                    if type(child.HookScript) == "function" and type(child.RegisterForDrag) == "function" then
                        pcall(child.RegisterForDrag, child, "LeftButton")
                        pcall(child.HookScript, child, "OnDragStart", function(_, button)
                            if button and button ~= "LeftButton" then return end
                            if InCombat() or DesktopWindows:IsYielding() or IsWorldMapMaximized(frame, frameName) then return end
                            local db = GetDesktopWindowsDB()
                            if not (db and db.dragAnywhere ~= false) then return end
                            if st.beginDrag then st.beginDrag() end
                        end)
                        pcall(child.HookScript, child, "OnDragStop", function()
                            if st.finishDrag then st.finishDrag() end
                        end)
                    end
                end
            end
        end
    end

    function W.SyncOverlayMode(frame, frameName)
        local st = W.blizzWinState[frame]
        if not st or not st.overlay then return end
        local ov = st.overlay
        if InCombat() or DesktopWindows:IsYielding() or IsWorldMapMaximized(frame, frameName) or IsHandledBySuiteReplacement(frameName) then
            st.isDragging = false
            st.usingNativeMove = nil
            ov:SetScript("OnUpdate", nil)
            ov:EnableMouse(false)
            ov:EnableMouseWheel(false)
            ov:Hide()
            return
        end
        local db = GetDesktopWindowsDB()
        local canDrag = (db and db.dragAnywhere ~= false) and true or false
        if canDrag then
            NeutraliseTitleContainerDrag(frame, frameName, st)
        end
        local canScale = (db and db.scrollScale ~= false) and true or false
        ov:EnableMouse(canDrag or canScale)
        ov:EnableMouseWheel(canScale)
        if canDrag or canScale then
            W.SyncHeaderOverlayLevel(frame, st)
            ov:Show()
        else
            ov:Hide()
        end
    end

    local function ApplyBlizzardFrameTransform(frame, frameName)
        if not frame or InCombat() then return end
        if DesktopWindows:IsYielding() or IsHandledBySuiteReplacement(frameName) then return end
        local st = EnsureHeaderOverlay(frame, frameName)
        AttachPassiveChromeDragHooks(frame, frameName, st)
        W.SyncOverlayMode(frame, frameName)
        W.SyncPanelLayoutDetachment(frame, frameName)
        if IsWorldMapMaximized(frame, frameName) then
            return
        end

        if not W.IsTaintSensitiveFrame(frame, frameName) and type(frame.SetMovable) == "function" then
            pcall(frame.SetMovable, frame, true)
        end
        W.SyncFrameClamping(frame, frameName)
        W.NormalizeDesktopWindowLayer(frame, frameName)
        if frameName == "EncounterJournal" then
            EnsureEncounterJournalScrollBoxesWheelEnabled(frame)
        end
        if frame.IsProtected and frame:IsProtected() and W.detachedPanels[frameName] then
            W.EnsureCombatEscapeButton(frame, frameName)
        end

        local db = GetDesktopWindowsDB()
        local targetScale = GetActiveFrameScale(frameName, frame)
        local liveScale = GetFrameLiveScale(frame)
        if math.abs(liveScale - targetScale) > 0.005 or (db and db.scales and db.scales[frameName]) or W.sessionScales[frameName] then
            SecureApplyScale(frame, targetScale)
        end

        local noAutoClose = (db and db.sideBySide ~= false)
        local customX, customY = W.GetActiveWindowCustomOffset(frameName, db)
        if customX and customY then
            SecureApplyPoint(frame, customX, customY, targetScale)
        elseif noAutoClose and frame.IsShown and frame:IsShown() then
            ApplyCanonicalDefaultPoint(frame, frameName, targetScale)
        end
    end

    local EnsureGlobalPanelHooks
    local AttachFrameHooks

    local function IsNonRestorablePanel(frameName)
        return (frameName and W.NON_RESTORABLE_PANELS[frameName]) and true or false
    end

    local function HasActiveSocketSession()
        local getInfo = (_G.C_ItemSocketInfo and _G.C_ItemSocketInfo.GetSocketItemInfo) or _G.GetSocketItemInfo
        if type(getInfo) == "function" then
            local ok, itemName = pcall(getInfo)
            return (ok and itemName ~= nil) and true or false
        end
        return true
    end

    local function GuardEmptyItemSocketingFrame()
        if InCombat() or DesktopWindows:IsYielding() then return end
        local isf = _G.ItemSocketingFrame
        if isf and isf.IsShown and isf:IsShown() and not HasActiveSocketSession() then
            W.openPanelsSnapshot["ItemSocketingFrame"] = nil
            W.escapeProtectedReShow["ItemSocketingFrame"] = nil
            W.lastAutoHiddenAt["ItemSocketingFrame"] = nil
            W.RemoveFromZOrderStack("ItemSocketingFrame")
            W.RemoveFromUISpecialFrames("ItemSocketingFrame")
            local prevEx = W.explicitCloseFrame
            W.explicitCloseFrame = "ItemSocketingFrame"
            pcall(isf.Hide, isf)
            W.explicitCloseFrame = prevEx
        end
    end

    local function ClearNonRestorablePanelState(frameName, now)
        if not frameName then return end
        W.openPanelsSnapshot[frameName] = nil
        W.escapeProtectedReShow[frameName] = nil
        W.lastAutoHiddenAt[frameName] = nil
        if now then
            W.lastExplicitCloseAt[frameName] = now
        end
        W.RemoveFromZOrderStack(frameName)
        W.RemoveFromUISpecialFrames(frameName)
    end

    local function RestoreCoexistingPanels(newlyShownName)
        if W.restoringPanels or InCombat() then return end
        if DesktopWindows:IsYielding() then return end
        local db = GetDesktopWindowsDB()
        local noAutoClose = (db and db.sideBySide ~= false)
        if not noAutoClose then return end
        if newlyShownName == "WorldMapFrame" and IsWorldMapMaximized(_G.WorldMapFrame, "WorldMapFrame") then
            return
        end

        local now = (type(_G.GetTime) == "function") and _G.GetTime() or 0
        W.restoringPanels = true
        for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
            local otherName = spec.name
            if otherName ~= newlyShownName and not IsHandledBySuiteReplacement(otherName) then
                local autoHiddenRecent = (W.lastAutoHiddenAt[otherName] ~= nil and (now - W.lastAutoHiddenAt[otherName]) < 0.30)
                local explicitRecent = (W.lastExplicitCloseAt[otherName] ~= nil and (now - W.lastExplicitCloseAt[otherName]) <= 0.25)
                if (W.openPanelsSnapshot[otherName] or autoHiddenRecent) and not explicitRecent then
                    local otherFrame = _G[otherName]
                    if otherFrame and not IsWorldMapMaximized(otherFrame, otherName) then
                        local otherSt = GetFrameState(otherFrame)
                        local wasShown = (otherFrame.IsShown and otherFrame:IsShown()) and true or false
                        if not wasShown then
                            if IsNonRestorablePanel(otherName) then
                                ClearNonRestorablePanelState(otherName, nil)
                            else
                                if otherSt then otherSt.restoringFromAutoClose = true end
                                pcall(otherFrame.Show, otherFrame)
                                if otherSt then otherSt.restoringFromAutoClose = false end
                                if otherFrame.IsShown and otherFrame:IsShown() then
                                    W.openPanelsSnapshot[otherName] = true
                                    W.lastAutoHiddenAt[otherName] = nil
                                    W.lastExplicitCloseAt[otherName] = nil
                                    if otherName == "PlayerSpellsFrame" then
                                        RestorePlayerSpellsFrameState(otherFrame)
                                    end
                                    ApplyBlizzardFrameTransform(otherFrame, otherName)
                                    W.NormalizeDesktopWindowLayer(otherFrame, otherName)
                                    if otherSt then otherSt.wasOpenConfirmed = true end
                                end
                            end
                        elseif otherName == "ItemSocketingFrame" and not HasActiveSocketSession() then
                            ClearNonRestorablePanelState(otherName, now)
                            local prevEx = W.explicitCloseFrame
                            W.explicitCloseFrame = otherName
                            pcall(otherFrame.Hide, otherFrame)
                            W.explicitCloseFrame = prevEx
                        else
                            W.openPanelsSnapshot[otherName] = true
                            W.lastAutoHiddenAt[otherName] = nil
                            W.lastExplicitCloseAt[otherName] = nil
                            local targetScale = GetActiveFrameScale(otherName, otherFrame)
                            local drifted = math.abs(GetFrameLiveScale(otherFrame) - targetScale) > 0.005
                            if not drifted and _G.UIParent
                                and type(otherFrame.GetNumPoints) == "function" and type(otherFrame.GetPoint) == "function" then
                                local customX, customY = W.GetActiveWindowCustomOffset(otherName, db)
                                local okN, numPts = pcall(otherFrame.GetNumPoints, otherFrame)
                                if okN and numPts == 1 then
                                    local okP, pt, relTo, relPt, curX, curY = pcall(otherFrame.GetPoint, otherFrame, 1)
                                    curX = okP and SafeNum(curX, nil) or nil
                                    curY = okP and SafeNum(curY, nil) or nil
                                    if customX and customY then
                                        local cUX, cUY = ClampDesktopWindowOffset(otherFrame, customX, customY, targetScale)
                                        local argX, argY = cUX / targetScale, cUY / targetScale
                                        if not (okP and pt == "CENTER" and relTo == _G.UIParent and relPt == "CENTER"
                                            and curX and curY and math.abs(curX - argX) <= 0.25 and math.abs(curY - argY) <= 0.25) then
                                            drifted = true
                                        end
                                    else
                                        local orig = SnapshotOrigUIPanelInfo(otherFrame, otherName)
                                        local defPt = (orig and orig.point) or "TOPLEFT"
                                        local defRelPt = (orig and orig.relPoint) or defPt
                                        local okDefaultAnchor = okP and relTo == _G.UIParent
                                            and ((pt == defPt and relPt == defRelPt)
                                                or (otherSt and otherSt.anchoredAtDefaultCenter and pt == "CENTER" and relPt == "CENTER"))
                                        if not okDefaultAnchor then
                                            drifted = true
                                        end
                                    end
                                else
                                    drifted = true
                                end
                            end
                            if drifted then
                                ApplyBlizzardFrameTransform(otherFrame, otherName)
                            end
                            if otherSt then otherSt.wasOpenConfirmed = true end
                        end
                    end
                end
            end
        end
        local topFrame = newlyShownName and _G[newlyShownName]
        if topFrame and topFrame.IsShown and topFrame:IsShown() and not IsWorldMapMaximized(topFrame, newlyShownName) then
            W.restoringPanels = false
            W.FocusAndRaiseDesktopWindow(topFrame, newlyShownName)
        else
            W.restoringPanels = false
        end
    end

    local function ScheduleDeferredCoexistencePass(frameName)
        if W.deferredRestorePending then return end
        if not (_G.C_Timer and _G.C_Timer.After) then return end
        W.deferredRestorePending = true
        _G.C_Timer.After(0, function()
            W.deferredRestorePending = false
            W.userOpeningPlayerSpells = false
            if InCombat() or DesktopWindows:IsYielding() then return end
            if frameName then
                local df = _G[frameName]
                if df and not IsWorldMapMaximized(df, frameName) then
                    AttachFrameHooks(frameName)
                    if df.IsShown and df:IsShown() then
                        ApplyBlizzardFrameTransform(df, frameName)
                        RestoreCoexistingPanels(frameName)
                        W.FocusAndRaiseDesktopWindow(df, frameName)
                    end
                end
            end
            W.SyncAllUISpecialFrames()
        end)
    end

    AttachFrameHooks = function(frameName)
        if W.hookedFrameNames[frameName] or EXCLUDED_BLIZZ_FRAMES[frameName] then return false end
        if InCombat() and IsCombatProtectedPanel(frameName) then
            W.pendingCombatWindowSetup[frameName] = true
            return false
        end
        local frame = _G[frameName]
        if not frame then return false end
        W.hookedFrameNames[frameName] = true
        W.pendingCombatWindowSetup[frameName] = nil
        SnapshotOrigUIPanelInfo(frame, frameName)
        W.SyncPanelLayoutDetachment(frame, frameName)
        local st = EnsureHeaderOverlay(frame, frameName)
        AttachPassiveChromeDragHooks(frame, frameName, st)
        W.SyncOverlayMode(frame, frameName)
        if EnsureGlobalPanelHooks then
            EnsureGlobalPanelHooks()
        end

        if not InCombat() and not IsWorldMapMaximized(frame, frameName) then
            if not W.IsTaintSensitiveFrame(frame, frameName) and type(frame.SetMovable) == "function" then
                pcall(frame.SetMovable, frame, true)
            end
            W.SyncFrameClamping(frame, frameName)
            W.NormalizeDesktopWindowLayer(frame, frameName)
            if frameName == "EncounterJournal" then
                EnsureEncounterJournalScrollBoxesWheelEnabled(frame)
            end
            local db = GetDesktopWindowsDB()
            if W.detachedPanels[frameName] then
                local escBtn = W.EnsureCombatEscapeButton(frame, frameName)
                if escBtn and type(escBtn.SetAttribute) == "function" then
                    local ready = (not DesktopWindows:IsYielding()) and (db and db.sideBySide ~= false) and true or false
                    pcall(escBtn.SetAttribute, escBtn, "dsCombatEscReady", ready)
                end
            end
        end

        if type(frame.RegisterForDrag) == "function" then
            pcall(frame.RegisterForDrag, frame, "LeftButton")
        end

        if type(_G.hooksecurefunc) == "function" and type(frame.StartMoving) == "function" and not st.startMovingHooked then
            st.startMovingHooked = true
            _G.hooksecurefunc(frame, "StartMoving", function(movingFrame)
                if InCombat() or DesktopWindows:IsYielding() or IsWorldMapMaximized(movingFrame, frameName) then
                    return
                end
                if type(movingFrame.StopMovingOrSizing) == "function" then
                    pcall(movingFrame.StopMovingOrSizing, movingFrame)
                end
                local db = GetDesktopWindowsDB()
                if not (db and db.dragAnywhere ~= false) then return end
                local fState = GetFrameState(movingFrame)
                if fState and not fState.isDragging and fState.beginDrag then
                    fState.beginDrag()
                end
            end)
        end

        if frameName == "MacroFrame" and type(_G.hooksecurefunc) == "function" and not st.macroLayerHooksDone then
            st.macroLayerHooksDone = true
            local function RefreshMacroLayersDeferred()
                if InCombat() or DesktopWindows:IsYielding() then return end
                local mf = _G.MacroFrame
                if mf and mf.IsShown and mf:IsShown() then
                    EnsureMacroFrameChildLayering(mf)
                    if _G.C_Timer and _G.C_Timer.After then
                        _G.C_Timer.After(0, function()
                            if not InCombat() and not DesktopWindows:IsYielding() and _G.MacroFrame and _G.MacroFrame.IsShown and _G.MacroFrame:IsShown() then
                                EnsureMacroFrameChildLayering(_G.MacroFrame)
                            end
                        end)
                    end
                end
            end
            for _, macroFn in ipairs({ "MacroFrame_SetAccountMacros", "MacroFrame_SetCharacterMacros", "MacroFrame_Update" }) do
                if type(_G[macroFn]) == "function" then
                    _G.hooksecurefunc(macroFn, RefreshMacroLayersDeferred)
                end
            end
            if type(frame.Update) == "function" then
                _G.hooksecurefunc(frame, "Update", RefreshMacroLayersDeferred)
            end
        end

        if frameName == "EncounterJournal" and type(_G.hooksecurefunc) == "function" and not st.ejScrollHooksDone then
            st.ejScrollHooksDone = true
            local function RefreshEJScrollWheel()
                if InCombat() or DesktopWindows:IsYielding() then return end
                EnsureEncounterJournalScrollBoxesWheelEnabled(_G.EncounterJournal)
            end
            for _, ejFn in ipairs({ "EncounterJournal_DisplayInstance", "EncounterJournal_DisplayEncounter", "EncounterJournal_SetTab", "EJ_ContentTab_Select" }) do
                if type(_G[ejFn]) == "function" then
                    _G.hooksecurefunc(ejFn, RefreshEJScrollWheel)
                end
            end
        end

        if frameName == "PlayerSpellsFrame" and type(_G.hooksecurefunc) == "function" and not st.playerSpellsHooksDone then
            st.playerSpellsHooksDone = true
            SnapshotPlayerSpellsState(frame, false)
            AttachPlayerSpellsSubCanvasWheelHooks(frame)

            if not st.playerSpellsPreGuardsDone then
                st.playerSpellsPreGuardsDone = true
                for _, methodName in ipairs({ "TrySetMinimized", "UpdateFrameMinimizeState", "CheckAndUpdateMinimizedState" }) do
                    if type(frame[methodName]) == "function" then
                        local origFn = frame[methodName]
                        frame[methodName] = function(self, ...)
                            if not InCombat() and not DesktopWindows:IsYielding() then
                                local db = GetDesktopWindowsDB()
                                local fState = GetFrameState(self)
                                if db and db.sideBySide ~= false and fState and not fState.allowUserMinimizeChange and not fState.restoringPlayerSpellsState then
                                    return
                                end
                            end
                            return origFn(self, ...)
                        end
                    end
                end
                if type(frame.SetMinimized) == "function" then
                    local origSetMin = frame.SetMinimized
                    frame.SetMinimized = function(self, isMinimized, ...)
                        if not InCombat() and not DesktopWindows:IsYielding() then
                            local db = GetDesktopWindowsDB()
                            local fState = GetFrameState(self)
                            if db and db.sideBySide ~= false and fState and not fState.allowUserMinimizeChange and not fState.restoringPlayerSpellsState then
                                if (isMinimized == true) ~= (fState.userIsMinimized == true) then
                                    return
                                end
                            end
                        end
                        return origSetMin(self, isMinimized, ...)
                    end
                end
            end

            if type(frame.SetScale) == "function" then
                _G.hooksecurefunc(frame, "SetScale", function(psf, newScale)
                    local fState = GetFrameState(psf)
                    if not fState or fState.applyingScale or fState.restoringPlayerSpellsState then return end
                    if InCombat() or DesktopWindows:IsYielding() then return end
                    local db = GetDesktopWindowsDB()
                    local sNum = SafeNum(newScale, nil)
                    if db and (db.sideBySide ~= false or db.scrollScale ~= false) then
                        local targetScale = GetActiveFrameScale("PlayerSpellsFrame", psf)
                        if sNum and math.abs(sNum - targetScale) > 0.005 then
                            SecureApplyScale(psf, targetScale)
                            local customX, customY = W.GetActiveWindowCustomOffset("PlayerSpellsFrame", db)
                            if customX and customY then
                                SecureApplyPoint(psf, customX, customY, targetScale)
                            elseif db.sideBySide ~= false and psf.IsShown and psf:IsShown() then
                                ApplyCanonicalDefaultPoint(psf, "PlayerSpellsFrame", targetScale)
                            end
                        end
                    end
                end)
            end

            W.AttachPlayerSpellsTabHooks(frame)
            if type(frame.SetTab) == "function" then
                _G.hooksecurefunc(frame, "SetTab", function(psf, tabID)
                    if InCombat() or DesktopWindows:IsYielding() then return end
                    AttachPlayerSpellsSubCanvasWheelHooks(psf)
                    W.AttachPlayerSpellsTabHooks(psf)
                    W.NormalizeDesktopWindowLayer(psf, "PlayerSpellsFrame")
                    local fState = GetFrameState(psf)
                    if not fState or fState.restoringPlayerSpellsState then return end
                    local db = GetDesktopWindowsDB()
                    local tabSys = psf.TabSystem or psf.tabSystem
                    local overTabBar = (tabSys and type(_G.MouseIsOver) == "function" and _G.MouseIsOver(tabSys)) and true or false
                    local inAutoRestore = W.restoringPanels or fState.restoringFromAutoClose or W.inShowUIPanelPostHook or IsShowUIPanelOnStack()
                    local isShownUserChange = (psf.IsShown and psf:IsShown() and not inAutoRestore) and true or false
                    local isUserTabSelect = W.userOpeningPlayerSpells
                        or (fState.userSelectedTabID == nil)
                        or overTabBar
                        or isShownUserChange
                    if isUserTabSelect then
                        local resolvedTab = (type(tabID) == "number" and tabID > 0 and tabID)
                            or GetPlayerSpellsActiveTab(psf)
                        if resolvedTab then
                            fState.userSelectedTabID = resolvedTab
                            fState.savedTabID = resolvedTab
                        end
                        if (overTabBar or isShownUserChange) and not GetPlayerSpellsIsMinimized(psf) then
                            fState.userIsMinimized = false
                            fState.savedIsMinimized = false
                        end
                    elseif db and db.sideBySide ~= false and fState.userSelectedTabID ~= nil and tabID ~= fState.userSelectedTabID then
                        RestorePlayerSpellsFrameState(psf)
                        if _G.C_Timer and _G.C_Timer.After then
                            _G.C_Timer.After(0, function()
                                RestorePlayerSpellsFrameState(psf)
                            end)
                        end
                    end
                end)
            end

            local mmf = frame.MaximizeMinimizeFrame
            if type(mmf) == "table" then
                if mmf.MaximizeButton and type(mmf.MaximizeButton.HookScript) == "function" then
                    mmf.MaximizeButton:HookScript("OnMouseDown", function(_, mouseBtn)
                        if mouseBtn ~= "LeftButton" then return end
                        local fState = GetFrameState(frame)
                        if fState then fState.allowUserMinimizeChange = true end
                    end)
                    mmf.MaximizeButton:HookScript("OnMouseUp", function()
                        local fState = GetFrameState(frame)
                        if fState and _G.C_Timer and _G.C_Timer.After then
                            _G.C_Timer.After(0, function()
                                if fState then fState.allowUserMinimizeChange = false end
                            end)
                        end
                    end)
                    mmf.MaximizeButton:HookScript("OnClick", function()
                        local fState = GetFrameState(frame)
                        if fState then
                            fState.allowUserMinimizeChange = true
                            fState.userIsMinimized = false
                            fState.savedIsMinimized = false
                            fState.allowUserMinimizeChange = false
                        end
                    end)
                end
                if mmf.MinimizeButton and type(mmf.MinimizeButton.HookScript) == "function" then
                    mmf.MinimizeButton:HookScript("OnMouseDown", function(_, mouseBtn)
                        if mouseBtn ~= "LeftButton" then return end
                        local fState = GetFrameState(frame)
                        if fState then fState.allowUserMinimizeChange = true end
                    end)
                    mmf.MinimizeButton:HookScript("OnMouseUp", function()
                        local fState = GetFrameState(frame)
                        if fState and _G.C_Timer and _G.C_Timer.After then
                            _G.C_Timer.After(0, function()
                                if fState then fState.allowUserMinimizeChange = false end
                            end)
                        end
                    end)
                    mmf.MinimizeButton:HookScript("OnClick", function()
                        local fState = GetFrameState(frame)
                        if fState then
                            fState.allowUserMinimizeChange = true
                            fState.userIsMinimized = true
                            fState.savedIsMinimized = true
                            local curT = GetPlayerSpellsActiveTab(frame)
                            if curT then
                                fState.userSelectedTabID = curT
                                fState.savedTabID = curT
                            end
                            fState.allowUserMinimizeChange = false
                        end
                    end)
                end
                if type(mmf.Maximize) == "function" and not mmf._dsMaxPreGuarded then
                    mmf._dsMaxPreGuarded = true
                    local origMax = mmf.Maximize
                    mmf.Maximize = function(selfMmf, ...)
                        if not InCombat() and not DesktopWindows:IsYielding() then
                            local fState = GetFrameState(frame)
                            local db = GetDesktopWindowsDB()
                            if fState and not fState.restoringPlayerSpellsState then
                                local userClicked = fState.allowUserMinimizeChange
                                    or ((_G.IsMouseButtonDown and _G.IsMouseButtonDown("LeftButton")) and (type(_G.MouseIsOver) == "function" and _G.MouseIsOver(mmf)))
                                if userClicked then
                                    fState.userIsMinimized = false
                                    fState.savedIsMinimized = false
                                elseif db and db.sideBySide ~= false and fState.userIsMinimized == true then
                                    return
                                end
                            end
                        end
                        return origMax(selfMmf, ...)
                    end
                end
                if type(mmf.Minimize) == "function" and not mmf._dsMinPreGuarded then
                    mmf._dsMinPreGuarded = true
                    local origMin = mmf.Minimize
                    mmf.Minimize = function(selfMmf, ...)
                        if not InCombat() and not DesktopWindows:IsYielding() then
                            local fState = GetFrameState(frame)
                            local db = GetDesktopWindowsDB()
                            if fState and not fState.restoringPlayerSpellsState then
                                local userClicked = fState.allowUserMinimizeChange
                                    or ((_G.IsMouseButtonDown and _G.IsMouseButtonDown("LeftButton")) and (type(_G.MouseIsOver) == "function" and _G.MouseIsOver(mmf)))
                                if userClicked then
                                    fState.userIsMinimized = true
                                    fState.savedIsMinimized = true
                                    local curT = GetPlayerSpellsActiveTab(frame)
                                    if curT then
                                        fState.userSelectedTabID = curT
                                        fState.savedTabID = curT
                                    end
                                elseif db and db.sideBySide ~= false and fState.userIsMinimized ~= true then
                                    return
                                end
                            end
                        end
                        return origMin(selfMmf, ...)
                    end
                end
            end
        end

        if frameName == "WorldMapFrame" and type(_G.hooksecurefunc) == "function" and type(frame.SynchronizeDisplayState) == "function" and not st.syncDisplayHooked then
            st.syncDisplayHooked = true
            _G.hooksecurefunc(frame, "SynchronizeDisplayState", function(wmf)
                if InCombat() or DesktopWindows:IsYielding() then return end
                W.SyncOverlayMode(wmf, "WorldMapFrame")
                if IsWorldMapMaximized(wmf, "WorldMapFrame") then
                    W.RemoveFromZOrderStack("WorldMapFrame")
                    SecureApplyScale(wmf, 1.0)
                elseif wmf.IsShown and wmf:IsShown() then
                    ApplyBlizzardFrameTransform(wmf, "WorldMapFrame")
                    RestoreCoexistingPanels("WorldMapFrame")
                    W.FocusAndRaiseDesktopWindow(wmf, "WorldMapFrame")
                    W.SyncAllUISpecialFrames()
                end
            end)
        end

        if type(frame.HookScript) == "function" then
            frame:HookScript("OnMouseDown", function(clickedFrame)
                if InCombat() or DesktopWindows:IsYielding() or IsWorldMapMaximized(clickedFrame, frameName) then return end
                W.FocusAndRaiseDesktopWindow(clickedFrame, frameName)
            end)
            frame:HookScript("OnDragStart", function(dragFrame, button)
                if button and button ~= "LeftButton" then return end
                local fState = GetFrameState(dragFrame)
                if InCombat() or DesktopWindows:IsYielding() or IsWorldMapMaximized(dragFrame, frameName) then
                    if not (fState and fState.isDragging) and not InCombat() and type(dragFrame.StopMovingOrSizing) == "function" then
                        pcall(dragFrame.StopMovingOrSizing, dragFrame)
                    end
                    return
                end
                local db = GetDesktopWindowsDB()
                if not (db and db.dragAnywhere ~= false) then
                    if not (fState and fState.isDragging) and type(dragFrame.StopMovingOrSizing) == "function" then
                        pcall(dragFrame.StopMovingOrSizing, dragFrame)
                    end
                    return
                end
                local altHeld = (_G.IsAltKeyDown and _G.IsAltKeyDown()) and true or false
                if not altHeld and not IsPassiveWindowDragTarget(GetTopMouseFocus(), dragFrame) then
                    if not (fState and fState.isDragging) and type(dragFrame.StopMovingOrSizing) == "function" then
                        pcall(dragFrame.StopMovingOrSizing, dragFrame)
                    end
                    return
                end
                if fState and fState.beginDrag then
                    fState.beginDrag()
                end
            end)
            frame:HookScript("OnDragStop", function(dragFrame)
                if not InCombat() and type(dragFrame.StopMovingOrSizing) == "function" then
                    pcall(dragFrame.StopMovingOrSizing, dragFrame)
                end
                local fState = W.blizzWinState[dragFrame]
                if fState and fState.finishDrag then
                    fState.finishDrag()
                end
            end)
            frame:HookScript("OnSizeChanged", function(sizedFrame)
                if InCombat() or DesktopWindows:IsYielding() then return end
                if not (sizedFrame.IsShown and sizedFrame:IsShown()) then return end
                if IsWorldMapMaximized(sizedFrame, frameName) then
                    W.SyncOverlayMode(sizedFrame, frameName)
                    return
                end
                ClampAndReanchorFrame(sizedFrame, frameName)
            end)
            frame:HookScript("OnShow", function(shownFrame)
                if EnsureGlobalPanelHooks then
                    EnsureGlobalPanelHooks()
                end
                local fState = GetFrameState(shownFrame)
                if fState and fState.detachingFromUIPanel then return end
                if InCombat() then
                    if IsCombatProtectedPanel(frameName) then
                        W.pendingCombatWindowSetup[frameName] = true
                        W.openPanelsSnapshot[frameName] = true
                        W.showSeqCounter = W.showSeqCounter + 1
                        W.lastShownAt[frameName] = W.showSeqCounter
                    end
                    return
                end
                if DesktopWindows:IsYielding() or IsWorldMapMaximized(shownFrame, frameName) then
                    W.SyncOverlayMode(shownFrame, frameName)
                    return
                end
                if IsHandledBySuiteReplacement(frameName) then
                    W.openPanelsSnapshot[frameName] = nil
                    W.RemoveFromZOrderStack(frameName)
                    W.RemoveFromUISpecialFrames(frameName)
                    W.SyncOverlayMode(shownFrame, frameName)
                    return
                end
                if not (fState and fState.restoringFromAutoClose) then
                    W.showSeqCounter = W.showSeqCounter + 1
                    W.lastShownAt[frameName] = W.showSeqCounter
                end
                W.openPanelsSnapshot[frameName] = true
                W.lastAutoHiddenAt[frameName] = nil
                W.lastExplicitCloseAt[frameName] = nil
                if not W.restoringPanels and not (fState and fState.restoringFromAutoClose) and W.detachedPanels[frameName] then
                    local siblingName = (frameName == "GossipFrame" and "QuestFrame") or (frameName == "QuestFrame" and "GossipFrame") or nil
                    local sibling = siblingName and _G[siblingName]
                    if sibling and sibling.IsShown and sibling:IsShown() then
                        local prevEx = W.explicitCloseFrame
                        W.explicitCloseFrame = siblingName
                        pcall(sibling.Hide, sibling)
                        W.explicitCloseFrame = prevEx
                    end
                end
                if frameName == "PlayerSpellsFrame" then
                    AttachPlayerSpellsSubCanvasWheelHooks(shownFrame)
                    W.AttachPlayerSpellsTabHooks(shownFrame)
                    if W.restoringPanels or (fState and fState.restoringFromAutoClose) then
                        RestorePlayerSpellsFrameState(shownFrame)
                        if _G.C_Timer and _G.C_Timer.After then
                            _G.C_Timer.After(0, function()
                                RestorePlayerSpellsFrameState(shownFrame)
                            end)
                        end
                    else
                        SnapshotPlayerSpellsState(shownFrame, W.userOpeningPlayerSpells)
                        RestorePlayerSpellsFrameState(shownFrame)
                    end
                elseif frameName == "CharacterFrame" then
                    local onPaperDoll = ((shownFrame.selectedTab or 1) == 1)
                        or (_G.PaperDollFrame and _G.PaperDollFrame.IsShown and _G.PaperDollFrame:IsShown())
                    local userCollapsed = (_G.GetCVarBool and _G.GetCVarBool("characterFrameCollapsed")) and true or false
                    if onPaperDoll then
                        if _G.PaperDollFrame and not (_G.PaperDollFrame.IsShown and _G.PaperDollFrame:IsShown()) then
                            if type(_G.CharacterFrame_ShowSubFrame) == "function" then
                                pcall(_G.CharacterFrame_ShowSubFrame, "PaperDollFrame")
                            elseif type(_G.PaperDollFrame.Show) == "function" then
                                pcall(_G.PaperDollFrame.Show, _G.PaperDollFrame)
                            end
                        end
                    end
                    if onPaperDoll and not userCollapsed then
                        if shownFrame.Expanded == false then
                            if type(shownFrame.Expand) == "function" then
                                pcall(shownFrame.Expand, shownFrame)
                            elseif type(_G.CharacterFrame_Expand) == "function" then
                                pcall(_G.CharacterFrame_Expand, shownFrame)
                            end
                        end
                        if type(shownFrame.IsRightPaneCollapsed) == "function" and type(shownFrame.SetRightPaneCollapsed) == "function" then
                            local okC, isCol = pcall(shownFrame.IsRightPaneCollapsed, shownFrame)
                            if okC and isCol then
                                pcall(shownFrame.SetRightPaneCollapsed, shownFrame, false)
                            end
                        end
                        local statsPane = _G.CharacterStatsPane
                        if statsPane and not (statsPane.IsShown and statsPane:IsShown()) and type(statsPane.SetShown) == "function" then
                            pcall(statsPane.SetShown, statsPane, true)
                        end
                        if type(_G.PaperDollFrame_UpdateStats) == "function" then
                            pcall(_G.PaperDollFrame_UpdateStats)
                        end
                        local euiStats = _G.EUI_CharSheet_StatsPanel
                        if euiStats and (statsPane == nil or (statsPane.IsShown and statsPane:IsShown()))
                            and type(euiStats.SetShown) == "function" then
                            pcall(euiStats.SetShown, euiStats, true)
                        end
                    end
                end
                ApplyBlizzardFrameTransform(shownFrame, frameName)
                if frameName == "EncounterJournal" then
                    EnsureEncounterJournalScrollBoxesWheelEnabled(shownFrame)
                end
                SyncCtrlWheelOverlay()
                if fState then fState.wasOpenConfirmed = true end
                if fState and fState.restoringFromAutoClose then
                    W.PruneZOrderStack()
                elseif not W.restoringPanels then
                    RestoreCoexistingPanels(frameName)
                    W.FocusAndRaiseDesktopWindow(shownFrame, frameName)
                    ScheduleDeferredCoexistencePass(frameName)
                end
                W.SyncAllUISpecialFrames()
            end)
            frame:HookScript("OnHide", function(hiddenFrame)
                if not InCombat() and type(hiddenFrame.StopMovingOrSizing) == "function" then
                    pcall(hiddenFrame.StopMovingOrSizing, hiddenFrame)
                end
                local fState = W.blizzWinState[hiddenFrame]
                if fState and fState.isDragging and fState.finishDrag then
                    fState.finishDrag()
                end
                if fState and fState.detachingFromUIPanel then
                    return
                end
                if IsHandledBySuiteReplacement(frameName) then
                    W.openPanelsSnapshot[frameName] = nil
                    W.escapeProtectedReShow[frameName] = nil
                    W.lastAutoHiddenAt[frameName] = nil
                    W.RemoveFromZOrderStack(frameName)
                    W.RemoveFromUISpecialFrames(frameName)
                    return
                end
                local now = (type(_G.GetTime) == "function") and _G.GetTime() or 0
                if frameName == "PlayerSpellsFrame" and fState and fState.userSelectedTabID == nil then
                    SnapshotPlayerSpellsState(hiddenFrame, false)
                end
                if IsShowUIPanelOnStack() or W.inShowUIPanelPostHook or W.restoringPanels then
                    if IsNonRestorablePanel(frameName) then
                        ClearNonRestorablePanelState(frameName, now)
                    else
                        W.openPanelsSnapshot[frameName] = true
                        W.lastAutoHiddenAt[frameName] = now
                    end
                    return
                end
                local db = GetDesktopWindowsDB()
                local isEscapeClose = (W.explicitCloseFrame ~= frameName and IsEscapeCloseOnStack() and not InCombat() and not DesktopWindows:IsYielding())
                if isEscapeClose then
                    local noAutoClose = (db and db.sideBySide ~= false)
                    if noAutoClose then
                        if W.escapeClosedCount == 0 and not W.HasNewerShownPanel(frameName) then
                            W.escapeClosedCount = 1
                            W.escapeClosedFrame = frameName
                            W.lastExplicitCloseAt[frameName] = now
                            W.openPanelsSnapshot[frameName] = nil
                            W.lastAutoHiddenAt[frameName] = nil
                            for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
                                W.RemoveFromUISpecialFrames(spec.name)
                            end
                        elseif not IsNonRestorablePanel(frameName) then
                            W.escapeProtectedReShow[frameName] = hiddenFrame
                            W.openPanelsSnapshot[frameName] = true
                            return
                        end
                    end
                end
                if W.explicitCloseFrame == frameName or isEscapeClose then
                    W.lastExplicitCloseAt[frameName] = now
                    W.lastAutoHiddenAt[frameName] = nil
                    W.openPanelsSnapshot[frameName] = nil
                else
                    W.lastAutoHiddenAt[frameName] = now
                    W.openPanelsSnapshot[frameName] = nil
                end
                if fState then
                    fState.wasOpenConfirmed = false
                    if frameName == "PlayerSpellsFrame" and (W.explicitCloseFrame == frameName or isEscapeClose) then
                        fState.userSelectedTabID = nil
                        fState.savedTabID = nil
                    end
                end
                W.RemoveFromZOrderStack(frameName)
                SyncCtrlWheelOverlay()
                W.sessionPositions[frameName] = nil
                local hadSession = (W.sessionScales[frameName] ~= nil)
                W.sessionScales[frameName] = nil
        if InCombat() then return end
                if W.pendingSlotEviction[frameName] and not (hiddenFrame.IsShown and hiddenFrame:IsShown())
                    and type(_G.HideUIPanel) == "function" then
                    W.pendingSlotEviction[frameName] = nil
                    if fState then fState.detachingFromUIPanel = true end
                    pcall(_G.HideUIPanel, hiddenFrame)
                    if fState then fState.detachingFromUIPanel = false end
                end
                if hadSession and not DesktopWindows:IsYielding() then
                    local savedOrOrig = (db and db.scales and db.scales[frameName])
                        or GetDefaultFrameScale(frameName, hiddenFrame)
                    SecureApplyScale(hiddenFrame, savedOrOrig)
                end
                W.RemoveFromUISpecialFrames(frameName)
                if not isEscapeClose then
                    W.SyncAllUISpecialFrames()
                end
            end)
        end

        local closeBtn = frame.CloseButton or _G[frameName .. "CloseButton"]
        if not closeBtn and frame.BorderFrame and frame.BorderFrame.CloseButton then
            closeBtn = frame.BorderFrame.CloseButton
        end
        if closeBtn and type(closeBtn.HookScript) == "function" and not closeBtn._dsCloseHooked then
            closeBtn._dsCloseHooked = true
            closeBtn:HookScript("OnMouseDown", function(_, mouseBtn)
                if mouseBtn == "LeftButton" and not InCombat() and not DesktopWindows:IsYielding() then
                    local now = (type(_G.GetTime) == "function") and _G.GetTime() or 0
                    W.lastExplicitCloseAt[frameName] = now
                    W.lastAutoHiddenAt[frameName] = nil
                    W.openPanelsSnapshot[frameName] = nil
                end
            end)
            closeBtn:HookScript("OnClick", function()
                if InCombat() or not frame or DesktopWindows:IsYielding() then return end
                local now = (type(_G.GetTime) == "function") and _G.GetTime() or 0
                W.lastExplicitCloseAt[frameName] = now
                W.lastAutoHiddenAt[frameName] = nil
                W.openPanelsSnapshot[frameName] = nil
                W.sessionPositions[frameName] = nil
                if st then
                    st.wasOpenConfirmed = false
                    if frameName == "PlayerSpellsFrame" then
                        st.userSelectedTabID = nil
                        st.savedTabID = nil
                    end
                end
                W.RemoveFromZOrderStack(frameName)
                if frame.IsShown and frame:IsShown() then
                    local prevExplicit = W.explicitCloseFrame
                    W.explicitCloseFrame = frameName
                    pcall(frame.Hide, frame)
                    W.explicitCloseFrame = prevExplicit
                end
                W.SyncAllUISpecialFrames()
            end)
        end

        if frame.IsShown and frame:IsShown() and not IsWorldMapMaximized(frame, frameName) and not IsHandledBySuiteReplacement(frameName) then
            W.openPanelsSnapshot[frameName] = true
            if not W.lastShownAt[frameName] then
                W.showSeqCounter = W.showSeqCounter + 1
                W.lastShownAt[frameName] = W.showSeqCounter
            end
            st.wasOpenConfirmed = true
            local inStack = false
            for i = 1, #W.zOrderStack do
                if W.zOrderStack[i] == frameName then
                    inStack = true
                    break
                end
            end
            if not inStack then
                W.FocusAndRaiseDesktopWindow(frame, frameName)
            end
        end
        return true
    end

    EnsureGlobalPanelHooks = function()
        if type(_G.hooksecurefunc) ~= "function" then return end

        if not W.scaleFitPreGuarded then
            W.scaleFitPreGuarded = true
            local function GuardFitScaleFn(tbl, key)
                if type(tbl) == "table" and type(tbl[key]) == "function" then
                    local origFitFn = tbl[key]
                    tbl[key] = function(fitFrame, ...)
                        if fitFrame and fitFrame == _G.PlayerSpellsFrame and not InCombat() and not DesktopWindows:IsYielding() then
                            local db = GetDesktopWindowsDB()
                            if db and (db.sideBySide ~= false or db.scrollScale ~= false) then
                                return
                            end
                        end
                        return origFitFn(fitFrame, ...)
                    end
                end
            end
            GuardFitScaleFn(_G, "UpdateScaleForFit")
            GuardFitScaleFn(_G, "UIPanelUpdateScaleForFit")
            if type(_G.FrameUtil) == "table" then
                GuardFitScaleFn(_G.FrameUtil, "UpdateScaleForFit")
            end
        end

        if not W.globalMouseHooked then
            W.globalMouseHooked = true
            local mouseFrame = CreateFrame("Frame", "DynamicSuiteDesktopWindowsMouseFrame", _G.UIParent)
            mouseFrame:SetSize(1, 1)
            mouseFrame:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 0, 0)
            mouseFrame:Show()
            SafeRegisterSuiteEvent(mouseFrame, "GLOBAL_MOUSE_DOWN")
            SafeRegisterSuiteEvent(mouseFrame, "MODIFIER_STATE_CHANGED")
            SafeRegisterSuiteEvent(mouseFrame, "SOCKET_INFO_UPDATE")
            SafeRegisterSuiteEvent(mouseFrame, "SOCKET_INFO_CLOSE")
            SafeRegisterSuiteEvent(mouseFrame, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
            mouseFrame:SetScript("OnEvent", function(selfMF, event, arg1)
                if event == "MODIFIER_STATE_CHANGED" then
                    SyncCtrlWheelOverlay()
                    return
                end
                if event == "SOCKET_INFO_UPDATE" then
                    if InCombat() or DesktopWindows:IsYielding() then return end
                    local function FocusSocketPanelIfReady()
                        if InCombat() or DesktopWindows:IsYielding() then return end
                        local isf = _G.ItemSocketingFrame
                        if isf then
                            AttachFrameHooks("ItemSocketingFrame")
                            if isf.IsShown and isf:IsShown() and HasActiveSocketSession() then
                                local db = GetDesktopWindowsDB()
                                W.openPanelsSnapshot["ItemSocketingFrame"] = true
                                if db and db.sideBySide ~= false then
                                    W.FocusAndRaiseDesktopWindow(isf, "ItemSocketingFrame")
                                else
                                    W.SyncAllUISpecialFrames()
                                end
                            end
                        end
                    end
                    FocusSocketPanelIfReady()
                    if _G.C_Timer and _G.C_Timer.After then
                        _G.C_Timer.After(0, FocusSocketPanelIfReady)
                    end
                    return
                end
                if event == "SOCKET_INFO_CLOSE" then
                    if InCombat() or DesktopWindows:IsYielding() then return end
                    GuardEmptyItemSocketingFrame()
                    if _G.C_Timer and _G.C_Timer.After then
                        _G.C_Timer.After(0, function()
                            GuardEmptyItemSocketingFrame()
                            W.SyncAllUISpecialFrames()
                        end)
                    end
                    return
                end
                if event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
                    if InCombat() or DesktopWindows:IsYielding() then return end
                    local iEnum = _G.Enum and _G.Enum.PlayerInteractionType
                    if not iEnum then return end
                    local targetName = (arg1 == iEnum.Gossip and "GossipFrame")
                        or (arg1 == iEnum.QuestGiver and "QuestFrame") or nil
                    if targetName and W.detachedPanels[targetName] then
                        local tf = _G[targetName]
                        if tf and tf.IsShown and tf:IsShown() then
                            local prevEx = W.explicitCloseFrame
                            W.explicitCloseFrame = targetName
                            pcall(tf.Hide, tf)
                            W.explicitCloseFrame = prevEx
                        end
                    end
                    return
                end
                if event ~= "GLOBAL_MOUSE_DOWN" then return end
                local button = arg1
                if button ~= "LeftButton" and button ~= "RightButton" then return end
                if InCombat() or DesktopWindows:IsYielding() then return end
                local db = GetDesktopWindowsDB()
                if not db then return end
                local focusRegion = GetTopMouseFocus()
                local cur = focusRegion
                local rootFrame, rootName = nil, nil
                for _ = 1, 18 do
                    if not cur or cur == _G.UIParent or cur == _G.WorldFrame then break end
                    local cName = (type(cur.GetName) == "function") and cur:GetName() or nil
                    if cName and SUPPORTED_BY_NAME[cName] and _G[cName] == cur then
                        if not EXCLUDED_BLIZZ_FRAMES[cName] and not IsWorldMapMaximized(cur, cName) then
                            rootFrame = cur
                            rootName = cName
                        end
                        break
                    end
                    if type(cur.GetParent) ~= "function" then break end
                    local okP, p = pcall(cur.GetParent, cur)
                    if not okP then break end
                    cur = p
                end
                if not rootFrame or not rootName then return end
                AttachFrameHooks(rootName)
                if db.sideBySide ~= false then
                    W.FocusAndRaiseDesktopWindow(rootFrame, rootName)
                end
                if button == "LeftButton" and db.dragAnywhere ~= false then
                    local altHeld = (_G.IsAltKeyDown and _G.IsAltKeyDown()) and true or false
                    if altHeld or IsPassiveWindowDragTarget(focusRegion, rootFrame) then
                        local startX, startY = 0, 0
                        if type(_G.GetCursorPosition) == "function" then
                            local cx, cy = _G.GetCursorPosition()
                            startX, startY = SafeNum(cx, 0), SafeNum(cy, 0)
                        end
                        W.pendingDragWatch = {
                            frame     = rootFrame,
                            frameName = rootName,
                            startX    = startX,
                            startY    = startY,
                        }
                        selfMF:SetScript("OnUpdate", function(watcherFrame)
                            local watch = W.pendingDragWatch
                            if not watch or InCombat() or DesktopWindows:IsYielding() then
                                W.pendingDragWatch = nil
                                watcherFrame:SetScript("OnUpdate", nil)
                                return
                            end
                            if type(_G.IsMouseButtonDown) == "function" and not _G.IsMouseButtonDown("LeftButton") then
                                W.pendingDragWatch = nil
                                watcherFrame:SetScript("OnUpdate", nil)
                                return
                            end
                            if not (watch.frame and watch.frame.IsShown and watch.frame:IsShown()) or IsWorldMapMaximized(watch.frame, watch.frameName) then
                                W.pendingDragWatch = nil
                                watcherFrame:SetScript("OnUpdate", nil)
                                return
                            end
                            local st = GetFrameState(watch.frame)
                            if st and st.isDragging then
                                W.pendingDragWatch = nil
                                watcherFrame:SetScript("OnUpdate", nil)
                                return
                            end
                            if type(_G.GetCursorPosition) ~= "function" then return end
                            local nx, ny = _G.GetCursorPosition()
                            nx, ny = SafeNum(nx, nil), SafeNum(ny, nil)
                            if not nx or not ny then return end
                            local dx = nx - (watch.startX or nx)
                            local dy = ny - (watch.startY or ny)
                            if (dx * dx + dy * dy) >= 16 then
                                W.pendingDragWatch = nil
                                watcherFrame:SetScript("OnUpdate", nil)
                                if st and st.beginDrag then
                                    st.beginDrag(watch.startX, watch.startY)
                                end
                            end
                        end)
                    end
                end
            end)
        end

        if not W.registerUIPanelHooked and type(_G.RegisterUIPanel) == "function" then
            W.registerUIPanelHooked = true
            _G.hooksecurefunc("RegisterUIPanel", function(name)
                if type(name) ~= "string" or not SUPPORTED_BY_NAME[name] or EXCLUDED_BLIZZ_FRAMES[name] then return end
        if InCombat() then return end
                AttachFrameHooks(name)
                local bf = _G[name]
                if bf then
                    W.SyncPanelLayoutDetachment(bf, name)
                end
            end)
        end

        if not W.showUIPanelHooked and type(_G.ShowUIPanel) == "function" then
            W.showUIPanelHooked = true
            _G.hooksecurefunc("ShowUIPanel", function(frame)
                if not frame or InCombat() then return end
                if DesktopWindows:IsYielding() then return end
                local fName = frame.GetName and frame:GetName()
                if not fName then return end
                if EXCLUDED_BLIZZ_FRAMES[fName] or IsWorldMapMaximized(frame, fName) then
                    for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
                        local bf = _G[spec.name]
                        if not (bf and bf.IsShown and bf:IsShown()) then
                            W.openPanelsSnapshot[spec.name] = nil
                            W.sessionPositions[spec.name] = nil
                            local bst = bf and W.blizzWinState[bf]
                            if bst then
                                bst.wasOpenConfirmed = false
                            end
                            W.RemoveFromZOrderStack(spec.name)
                            W.RemoveFromUISpecialFrames(spec.name)
                        end
                    end
                    return
                end
                if not SUPPORTED_BY_NAME[fName] then return end
                if IsHandledBySuiteReplacement(fName) then
                    W.openPanelsSnapshot[fName] = nil
                    W.RemoveFromZOrderStack(fName)
                    W.RemoveFromUISpecialFrames(fName)
                    W.SyncOverlayMode(frame, fName)
                    return
                end

                W.inShowUIPanelPostHook = true
                AttachFrameHooks(fName)
                local st = GetFrameState(frame)
                if st and st.detachingFromUIPanel then
                    W.inShowUIPanelPostHook = false
                    return
                end
                local db = GetDesktopWindowsDB()
                local noAutoClose = (db and db.sideBySide ~= false)

                if not (frame.IsShown and frame:IsShown()) then
                    local info = W.origUIPanelInfo[fName]
                    local dead = (_G.UnitIsDeadOrGhost and _G.UnitIsDeadOrGhost("player"))
                    if not dead or (info and info.whileDead) then
                        pcall(frame.Show, frame)
                    end
                end

                if noAutoClose then
                    RestoreCoexistingPanels(fName)
                    ScheduleDeferredCoexistencePass(fName)
                else
                    for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
                        local otherName = spec.name
                        if otherName ~= fName then
                            local otherFrame = _G[otherName]
                            local otherSt = otherFrame and W.blizzWinState[otherFrame]
                            W.openPanelsSnapshot[otherName] = nil
                            W.lastAutoHiddenAt[otherName] = nil
                            W.sessionPositions[otherName] = nil
                            if otherSt then
                                otherSt.wasOpenConfirmed = false
                            end
                            W.RemoveFromZOrderStack(otherName)
                            if W.sessionScales[otherName] ~= nil and otherFrame then
                                W.sessionScales[otherName] = nil
                                local savedOrOrig = (db and db.scales and db.scales[otherName])
                                    or GetDefaultFrameScale(otherName, otherFrame)
                                SecureApplyScale(otherFrame, savedOrOrig)
                            end
                            W.RemoveFromUISpecialFrames(otherName)
                        end
                    end
                end

                if frame.IsShown and frame:IsShown() then
                    W.openPanelsSnapshot[fName] = true
                    W.lastAutoHiddenAt[fName] = nil
                    W.lastExplicitCloseAt[fName] = nil
                    ApplyBlizzardFrameTransform(frame, fName)
                    if st then st.wasOpenConfirmed = true end
                    W.FocusAndRaiseDesktopWindow(frame, fName)
                end

                W.SyncAllUISpecialFrames()
                W.inShowUIPanelPostHook = false
            end)
        end

        local function FlushEscapeProtectedWindows()
            if InCombat() or DesktopWindows:IsYielding() then
                W.escapeClosedCount = 0
                W.escapeClosedFrame = nil
                for k in pairs(W.escapeProtectedReShow) do W.escapeProtectedReShow[k] = nil end
                return
            end
            W.inEscapeRestorePostHook = true
            W.inCloseSpecialWindowsPostHook = true
            if W.escapeClosedCount == 0 then
                local newestName, newestFrame, newestSeq = nil, nil, -1
                for fName, fObj in pairs(W.escapeProtectedReShow) do
                    local seq = W.lastShownAt[fName] or 0
                    if seq > newestSeq then
                        newestSeq = seq
                        newestName = fName
                        newestFrame = fObj
                    end
                end
                if newestName and newestFrame then
                    W.escapeProtectedReShow[newestName] = nil
                    W.openPanelsSnapshot[newestName] = nil
                    W.sessionPositions[newestName] = nil
                    W.lastExplicitCloseAt[newestName] = (type(_G.GetTime) == "function") and _G.GetTime() or 0
                    local nst = W.blizzWinState[newestFrame]
                    if nst then
                        nst.wasOpenConfirmed = false
                    end
                    W.RemoveFromZOrderStack(newestName)
                    local prevEx = W.explicitCloseFrame
                    W.explicitCloseFrame = newestName
                    if newestFrame.Hide then pcall(newestFrame.Hide, newestFrame) end
                    W.explicitCloseFrame = prevEx
                end
            end
            W.escapeClosedCount = 0
            W.escapeClosedFrame = nil
            for fName, fObj in pairs(W.escapeProtectedReShow) do
                W.escapeProtectedReShow[fName] = nil
                if fObj and not IsNonRestorablePanel(fName) and not IsHandledBySuiteReplacement(fName) and not IsWorldMapMaximized(fObj, fName) then
                    W.openPanelsSnapshot[fName] = true
                    local st = GetFrameState(fObj)
                    if not (fObj.IsShown and fObj:IsShown()) then
                        if st then st.restoringFromAutoClose = true end
                        pcall(fObj.Show, fObj)
                        if st then st.restoringFromAutoClose = false end
                    end
                    ApplyBlizzardFrameTransform(fObj, fName)
                    if st then
                        st.wasOpenConfirmed = true
                    end
                end
            end
            GuardEmptyItemSocketingFrame()
            W.PruneZOrderStack()
            W.SyncAllUISpecialFrames()
            W.inCloseSpecialWindowsPostHook = false
            W.inEscapeRestorePostHook = false
        end

        if not W.hideUIPanelHooked and type(_G.HideUIPanel) == "function" then
            W.hideUIPanelHooked = true
            _G.hooksecurefunc("HideUIPanel", function(frame)
                if not frame or InCombat() then return end
                if DesktopWindows:IsYielding() then return end
                local fName = frame.GetName and frame:GetName()
                if not fName or EXCLUDED_BLIZZ_FRAMES[fName] or not SUPPORTED_BY_NAME[fName] or IsWorldMapMaximized(frame, fName) then return end
                if IsHandledBySuiteReplacement(fName) then
                    W.openPanelsSnapshot[fName] = nil
                    W.escapeProtectedReShow[fName] = nil
                    W.lastAutoHiddenAt[fName] = nil
                    W.RemoveFromZOrderStack(fName)
                    W.RemoveFromUISpecialFrames(fName)
                    return
                end
                local st = W.blizzWinState[frame]
                if st and st.detachingFromUIPanel then return end
                if fName == "PlayerSpellsFrame" and st and st.userSelectedTabID == nil then
                    SnapshotPlayerSpellsState(frame, false)
                end
                local now = (type(_G.GetTime) == "function") and _G.GetTime() or 0
                if IsShowUIPanelOnStack() or W.inShowUIPanelPostHook or W.restoringPanels then
                    if IsNonRestorablePanel(fName) then
                        ClearNonRestorablePanelState(fName, now)
                    else
                        W.openPanelsSnapshot[fName] = true
                        W.lastAutoHiddenAt[fName] = now
                    end
                    return
                end
                local db = GetDesktopWindowsDB()
                local noAutoClose = (db and db.sideBySide ~= false)
                local isEscapeClose = (W.explicitCloseFrame ~= fName and IsEscapeCloseOnStack())
                if isEscapeClose and W.escapeClosedFrame ~= fName then
                    if not IsNonRestorablePanel(fName) and noAutoClose and (W.escapeProtectedReShow[fName] ~= nil or W.escapeClosedCount >= 1 or W.HasNewerShownPanel(fName)) then
                        W.openPanelsSnapshot[fName] = true
                        W.escapeProtectedReShow[fName] = nil
                        W.RemoveFromUISpecialFrames(fName)
                        W.inEscapeRestorePostHook = true
                        if not (frame.IsShown and frame:IsShown()) then
                            if st then st.restoringFromAutoClose = true end
                            pcall(frame.Show, frame)
                            if st then st.restoringFromAutoClose = false end
                        end
                        ApplyBlizzardFrameTransform(frame, fName)
                        if st then
                            st.wasOpenConfirmed = true
                        end
                        W.PruneZOrderStack()
                        W.SyncAllUISpecialFrames()
                        W.inEscapeRestorePostHook = false
                        return
                    end
                    if noAutoClose and (W.escapeClosedCount == 0 and not W.HasNewerShownPanel(fName)) then
                        W.escapeClosedCount = 1
                        W.escapeClosedFrame = fName
                        W.lastExplicitCloseAt[fName] = now
                        for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
                            W.RemoveFromUISpecialFrames(spec.name)
                        end
                    end
                end
                -- Reaching here means HideUIPanel ran directly outside ShowUIPanel/RestoreCoexistingPanels, so treat as an explicit close.
                local isExplicit = true
                W.openPanelsSnapshot[fName] = nil
                W.escapeProtectedReShow[fName] = nil
                W.sessionPositions[fName] = nil
                W.lastExplicitCloseAt[fName] = now
                W.lastAutoHiddenAt[fName] = nil
                if st then
                    st.wasOpenConfirmed = false
                    if fName == "PlayerSpellsFrame" and isExplicit then
                        st.userSelectedTabID = nil
                        st.savedTabID = nil
                    end
                end
                W.RemoveFromZOrderStack(fName)
                W.RemoveFromUISpecialFrames(fName)
                if frame.IsShown and frame:IsShown() then
                    pcall(frame.Hide, frame)
                end
                if fName == "ItemSocketingFrame" or isEscapeClose then
                    GuardEmptyItemSocketingFrame()
                end
                if not isEscapeClose then
                    W.SyncAllUISpecialFrames()
                end
            end)
        end

        if not W.closeSpecialHooked and type(_G.CloseSpecialWindows) == "function" then
            W.closeSpecialHooked = true
            _G.hooksecurefunc("CloseSpecialWindows", FlushEscapeProtectedWindows)
        end

        if not W.closeWindowsHooked and type(_G.CloseWindows) == "function" then
            W.closeWindowsHooked = true
            _G.hooksecurefunc("CloseWindows", FlushEscapeProtectedWindows)
        end

        if not W.closeAllHooked and type(_G.CloseAllWindows) == "function" then
            W.closeAllHooked = true
            _G.hooksecurefunc("CloseAllWindows", FlushEscapeProtectedWindows)
        end

        if not W.toggleGameMenuHooked and type(_G.ToggleGameMenu) == "function" then
            W.toggleGameMenuHooked = true
            _G.hooksecurefunc("ToggleGameMenu", FlushEscapeProtectedWindows)
        end

        local function HandlePostToggle(targetName)
            if InCombat() or DesktopWindows:IsYielding() then return end
            local tf = _G[targetName]
            local now = (type(_G.GetTime) == "function") and _G.GetTime() or 0
            if tf then
                AttachFrameHooks(targetName)
                if IsWorldMapMaximized(tf, targetName) then
                    W.RemoveFromZOrderStack(targetName)
                    W.SyncOverlayMode(tf, targetName)
                    return
                end
                local st = GetFrameState(tf)
                if tf.IsShown and tf:IsShown() then
                    W.openPanelsSnapshot[targetName] = true
                    W.lastAutoHiddenAt[targetName] = nil
                    W.lastExplicitCloseAt[targetName] = nil
                    if targetName == "PlayerSpellsFrame" and st then
                        local curT = GetPlayerSpellsActiveTab(tf)
                        if curT then
                            st.userSelectedTabID = curT
                            st.savedTabID = curT
                        end
                    end
                    ApplyBlizzardFrameTransform(tf, targetName)
                    if st then st.wasOpenConfirmed = true end
                    RestoreCoexistingPanels(targetName)
                    W.FocusAndRaiseDesktopWindow(tf, targetName)
                else
                    W.lastExplicitCloseAt[targetName] = now
                    W.lastAutoHiddenAt[targetName] = nil
                    W.openPanelsSnapshot[targetName] = nil
                    W.sessionPositions[targetName] = nil
                    if st then
                        st.wasOpenConfirmed = false
                    end
                    W.RemoveFromZOrderStack(targetName)
                end
                W.SyncAllUISpecialFrames()
            end
            ScheduleDeferredCoexistencePass(targetName)
        end

        if not W.toggleProfBookHooked and type(_G.ToggleProfessionsBook) == "function" then
            W.toggleProfBookHooked = true
            _G.hooksecurefunc("ToggleProfessionsBook", function()
                HandlePostToggle("ProfessionsBookFrame")
            end)
        end

        if not W.toggleFriendsHooked and type(_G.ToggleFriendsFrame) == "function" then
            W.toggleFriendsHooked = true
            _G.hooksecurefunc("ToggleFriendsFrame", function()
                HandlePostToggle("FriendsFrame")
            end)
        end

        if not W.toggleWorldMapHooked then
            W.toggleWorldMapHooked = true
            if type(_G.ToggleQuestLog) == "function" then
                _G.hooksecurefunc("ToggleQuestLog", function()
            if InCombat() then return end
                    HandlePostToggle("WorldMapFrame")
                end)
            end
            if type(_G.ToggleWorldMap) == "function" then
                _G.hooksecurefunc("ToggleWorldMap", function()
            if InCombat() then return end
                    HandlePostToggle("WorldMapFrame")
                end)
            end
            if type(_G.OpenWorldMap) == "function" then
                _G.hooksecurefunc("OpenWorldMap", function()
            if InCombat() then return end
                    HandlePostToggle("WorldMapFrame")
                end)
            end
        end

        if not W.toggleExtraHooksDone then
            W.toggleExtraHooksDone = true
            local toggleGlobals = {
                { fn = "ToggleCharacter",          frame = "CharacterFrame" },
                { fn = "ToggleTalentFrame",        frame = "PlayerSpellsFrame", isSpells = true },
                { fn = "ToggleSpellBook",          frame = "PlayerSpellsFrame", isSpells = true },
                { fn = "ToggleGuildFrame",         frame = "CommunitiesFrame" },
                { fn = "ToggleAchievementFrame",   frame = "AchievementFrame" },
                { fn = "ToggleCollectionsJournal", frame = "CollectionsJournal" },
                { fn = "PVEFrame_ToggleFrame",     frame = "PVEFrame" },
                { fn = "ToggleEncounterJournal",   frame = "EncounterJournal" },
            }
            for _, spec in ipairs(toggleGlobals) do
                if type(_G[spec.fn]) == "function" then
                    _G.hooksecurefunc(spec.fn, function()
                        if spec.isSpells then
                            W.userOpeningPlayerSpells = true
                        end
                        HandlePostToggle(spec.frame)
                    end)
                end
            end
            if type(_G.PlayerSpellsUtil) == "table" then
                local utilFns = {
                    "TogglePlayerSpellsFrame",
                    "OpenToClassTalentsTab",
                    "OpenToSpellBookTab",
                    "OpenToClassSpecializationsTab",
                }
                for _, uFn in ipairs(utilFns) do
                    if type(_G.PlayerSpellsUtil[uFn]) == "function" then
                        _G.hooksecurefunc(_G.PlayerSpellsUtil, uFn, function()
                            W.userOpeningPlayerSpells = true
                            HandlePostToggle("PlayerSpellsFrame")
                        end)
                    end
                end
            end
        end

        if not W.updateUIPanelHooked and type(_G.UpdateUIPanelPositions) == "function" then
            W.updateUIPanelHooked = true
            _G.hooksecurefunc("UpdateUIPanelPositions", function()
                if InCombat() or DesktopWindows:IsYielding() then return end
                local db = GetDesktopWindowsDB()
                if not db or db.sideBySide ~= false then return end
                for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
                    local f = _G[spec.name]
                    if f and f.IsShown and f:IsShown() and not IsWorldMapMaximized(f, spec.name) then
                        local s = GetActiveFrameScale(spec.name, f)
                        if math.abs(GetFrameLiveScale(f) - s) > 0.005 then
                            SecureApplyScale(f, s)
                        end
                        local customX, customY = W.GetActiveWindowCustomOffset(spec.name, db)
                        if customX and customY then
                            SecureApplyPoint(f, customX, customY, s)
                        end
                    end
                end
            end)
        end
    end

    function DesktopWindows:GetDB()
        return GetDesktopWindowsDB()
    end

    function DesktopWindows:GetYieldAddon()
        local isLoadedFn = (_G.C_AddOns and _G.C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
        local getInfoFn  = (_G.C_AddOns and _G.C_AddOns.GetAddOnInfo) or _G.GetAddOnInfo
        local function isAddonLoaded(name)
            if IsExternalAddonFrozen(name) then return false end
            return type(isLoadedFn) == "function" and (isLoadedFn(name) == true)
        end
        local function hasSeparateQoLAddon()
            if type(getInfoFn) ~= "function" then return false end
            for _, qolName in ipairs({ "EllesmereUIQoL", "EllesmereUI_QoL" }) do
                local ok, name, title, _, _, reason = pcall(getInfoFn, qolName)
                if ok and (name or title) and reason ~= "MISSING" then
                    return true
                end
            end
            return false
        end
        local function isOverriddenToDynamic(...)
            local g = _G.DynamicSuiteDB and _G.DynamicSuiteDB.global
            local gm = g and g.granularModes
            local ack = g and g.acknowledgedConflicts
            local choices = g and g.conflictChoices
            local overrides = g and g.conflictOverrides
            for i = 1, select("#", ...) do
                local addonKey = select(i, ...)
                if addonKey then
                    if GetGranularConflictMode("DynamicSuite", addonKey) == "PRIORITISE_DYNAMIC"
                        or GetGranularConflictMode("DynamicPrep", addonKey) == "PRIORITISE_DYNAMIC"
                        or GetGranularConflictMode("DynamicLoad", addonKey) == "PRIORITISE_DYNAMIC" then
                        return true
                    end
                    for _, suffix in ipairs({ "_DynamicSuite", "_DynamicPrep", "_DynamicLoad", "" }) do
                        local k = tostring(addonKey) .. suffix
                        for _, tbl in ipairs({ gm, ack, choices, overrides }) do
                            if type(tbl) == "table" then
                                local v = tbl[k]
                                if v == "PRIORITISE_DYNAMIC" or v == "USE_DYNAMIC" or v == "PREFER_DYNAMIC" then
                                    return true
                                end
                            end
                        end
                    end
                end
            end
            return false
        end

        if isAddonLoaded("NoAutoClose") and not isOverriddenToDynamic("NoAutoClose") then
            return "NoAutoClose", "NoAutoClose"
        end

        if isAddonLoaded("BlizzMove") and not isOverriddenToDynamic("BlizzMove") then
            return "BlizzMove", "BlizzMove"
        end

        if isAddonLoaded("DeModal") and not isOverriddenToDynamic("DeModal") then
            return "DeModal", "DeModal"
        end

        if isAddonLoaded("MoveAny") and not isOverriddenToDynamic("MoveAny") then
            local maDisabled = false
            local maTab = _G.MATAB
            if type(maTab) == "table" and maTab["ENABLED"] == false then
                maDisabled = true
            end
            local maDB = _G.MoveAnyDB
            if type(maDB) == "table" and maDB.disabled == true then
                maDisabled = true
            end
            if not maDisabled then
                return "MoveAny", "MoveAny"
            end
        end

        local euiQoLLoaded = isAddonLoaded("EllesmereUIQoL") or isAddonLoaded("EllesmereUI_QoL")
        local euiActive = isAddonLoaded("EllesmereUI") and (not hasSeparateQoLAddon() or euiQoLLoaded)
        if euiActive and not isOverriddenToDynamic("EllesmereUI", "EllesmereUIQoL", "EllesmereUI_QoL") then
            local edb, subProf, rootProf = ResolveEllesmereProfile("EllesmereUIQoL")
            local function HasShifter(tbl)
                return type(tbl) == "table" and (tbl.shifterEnabled == true or tbl.moveBlizzardFrames == true or tbl.blizzFrameMover == true or tbl.noAutoClose == true)
            end
            if HasShifter(edb) or HasShifter(subProf) or HasShifter(rootProf) then
                if euiQoLLoaded then
                    return "EllesmereUIQoL", "EllesmereUI Quality of Life (Shifter)"
                end
                return "EllesmereUI", "EllesmereUI"
            end
        end

        if isAddonLoaded("Leatrix_Plus") and not isOverriddenToDynamic("Leatrix_Plus") then
            local ldb = _G.LeaPlusDB
            if type(ldb) == "table" and (
                ldb["UseEasyFrameResizing"] == "On"
                or ldb["MoveBlizzFrames"] == "On"
                or ldb["NoAutoClose"] == "On"
                or ldb["ManageFrames"] == "On"
            ) then
                return "Leatrix Plus", "Leatrix Plus"
            end
        end

        if isAddonLoaded("ElvUI") and not isOverriddenToDynamic("ElvUI") then
            local e = _G.ElvUI
            local e1 = type(e) == "table" and e[1] or nil
            if type(e1) == "table"
               and type(e1.private) == "table"
               and type(e1.private.skins) == "table"
               and type(e1.private.skins.blizzard) == "table"
               and e1.private.skins.blizzard.enable == true then
                return "ElvUI", "ElvUI"
            end
        end

        return nil, nil
    end
    DesktopWindows.GetBlizzardWindowYieldAddon = DesktopWindows.GetYieldAddon

    function DesktopWindows:IsMasterDisabled()
        local db = GetDesktopWindowsDB()
        return (db and db.masterEnabled == false) and true or false
    end

    function DesktopWindows:IsYielding()
        local yieldAddon = DesktopWindows:GetYieldAddon()
        return (yieldAddon ~= nil and yieldAddon ~= false)
    end
    DesktopWindows.IsYieldingBlizzardWindowsToEllesmereUI = DesktopWindows.IsYielding

    function W.HookEllesmereUICoexistence()
        if W.ellesmereHooksInstalled then return end
        local eui = _G.EllesmereUI
        if type(eui) ~= "table" or type(_G.hooksecurefunc) ~= "function" then return end
        W.ellesmereHooksInstalled = true
        local function onShifterChange()
            DesktopWindows:ApplyAllWindowStates()
            if addonTable.mainFrame and addonTable.mainFrame.themeView and addonTable.mainFrame.themeView:IsShown() and addonTable.mainFrame.themeView.Refresh then
                pcall(addonTable.mainFrame.themeView.Refresh)
            end
        end
        if type(eui._InitShifter) == "function" then
            _G.hooksecurefunc(eui, "_InitShifter", onShifterChange)
        end
        if type(eui._ShutdownShifter) == "function" then
            _G.hooksecurefunc(eui, "_ShutdownShifter", onShifterChange)
        end
    end

    function DesktopWindows:InvalidateNativeScales()
        local psf = _G.PlayerSpellsFrame
        local st = psf and W.blizzWinState[psf]
        if st then
            st.nativeScale = nil
        end
    end

    function DesktopWindows:ApplyAllWindowStates()
        if InCombat() then return end
        local db = GetDesktopWindowsDB()
        local masterOff = DesktopWindows:IsMasterDisabled()
        if not masterOff then
            W.HookEllesmereUICoexistence()
            EnsureGlobalPanelHooks()
        end
        local yielding = DesktopWindows:IsYielding() or masterOff
        local sideBySide = (not yielding) and (db and db.sideBySide ~= false)
        for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
            local frame = _G[spec.name]
            if frame then
                if not masterOff then
                    AttachFrameHooks(spec.name)
                end
                W.SyncPanelLayoutDetachment(frame, spec.name)
                if frame.IsProtected and frame:IsProtected() then
                    local escBtn = W.combatEscHandlers[frame]
                    local handledByReplacement = IsHandledBySuiteReplacement(spec.name)
                    if not escBtn and W.detachedPanels[spec.name] and not handledByReplacement then
                        escBtn = W.EnsureCombatEscapeButton(frame, spec.name)
                    end
                    if escBtn and type(escBtn.SetAttribute) == "function" then
                        pcall(escBtn.SetAttribute, escBtn, "dsCombatEscReady", (sideBySide and W.detachedPanels[spec.name] and not handledByReplacement) and true or false)
                    end
                end
                if yielding or IsWorldMapMaximized(frame, spec.name) then
                    W.SyncOverlayMode(frame, spec.name)
                    if spec.name == "MacroFrame" and W.pendingCombatWindowSetup["MacroFrame"] then
                        W.pendingCombatWindowSetup["MacroFrame"] = nil
                        if frame.IsShown and frame:IsShown() then
                            RefreshMacroFrameAfterCombat(frame)
                        end
                    end
                else
                    local wasPendingCombat = W.pendingCombatWindowSetup[spec.name]
                    W.pendingCombatWindowSetup[spec.name] = nil
                    W.SyncFrameClamping(frame, spec.name)
                    W.SyncOverlayMode(frame, spec.name)
                    if frame.IsShown and frame:IsShown() and not IsHandledBySuiteReplacement(spec.name) then
                        W.openPanelsSnapshot[spec.name] = true
                        local st = GetFrameState(frame)
                        ApplyBlizzardFrameTransform(frame, spec.name)
                        if st then st.wasOpenConfirmed = true end
                        if wasPendingCombat then
                            W.FocusAndRaiseDesktopWindow(frame, spec.name)
                        end
                        if spec.name == "MacroFrame" then
                            RefreshMacroFrameAfterCombat(frame)
                        end
                    end
                end
            end
        end
        W.SyncAllUISpecialFrames()
        SyncCtrlWheelOverlay()
    end
    DesktopWindows.ApplyAllBlizzardWindowStates = DesktopWindows.ApplyAllWindowStates

    function DesktopWindows:ResetSingleWindow(arg1, arg2, arg3)
        local frameName, showToast
        if arg1 == DesktopWindows then
            frameName, showToast = arg2, arg3
        else
            frameName, showToast = arg1, arg2
        end
        if type(frameName) ~= "string" or frameName == "" or InCombat() then return end
        WipeDesktopWindowEntryFromAllDBs(frameName)
        GetDesktopWindowsDB()
        W.sessionScales[frameName] = nil
        W.sessionPositions[frameName] = nil
        local frame = _G[frameName]
        local st = frame and GetFrameState(frame)
        if st then
            st.anchoredAtDefaultCenter = false
            st.lastAppliedUX = nil
            st.lastAppliedUY = nil
        end
        if frame and not DesktopWindows:IsYielding() and not IsWorldMapMaximized(frame, frameName) then
            if frameName == "PlayerSpellsFrame" and st then
                st.nativeScale = nil
                st.userIsMinimized = false
                st.savedIsMinimized = false
                if GetPlayerSpellsIsMinimized(frame) then
                    st.restoringPlayerSpellsState = true
                    if type(frame.SetMinimized) == "function" then
                        pcall(frame.SetMinimized, frame, false)
                    end
                    if frame.MaximizeMinimizeFrame and type(frame.MaximizeMinimizeFrame.Maximize) == "function" and GetPlayerSpellsIsMinimized(frame) then
                        pcall(frame.MaximizeMinimizeFrame.Maximize, frame.MaximizeMinimizeFrame)
                    end
                    st.restoringPlayerSpellsState = false
                end
            end

            local defPt, defRelPt, defX, defY, defScale = GetCanonicalPanelDefault(frameName, frame)
            W.origUIPanelInfo[frameName] = W.origUIPanelInfo[frameName] or {}
            W.origUIPanelInfo[frameName].point = defPt
            W.origUIPanelInfo[frameName].relTo = _G.UIParent
            W.origUIPanelInfo[frameName].relPoint = defRelPt
            W.origUIPanelInfo[frameName].x = defX
            W.origUIPanelInfo[frameName].y = defY
            W.origUIPanelInfo[frameName].defaultScale = defScale

            W.SyncPanelLayoutDetachment(frame, frameName)
            W.SyncFrameClamping(frame, frameName)
            SecureApplyScale(frame, defScale)
            ApplyCanonicalDefaultPoint(frame, frameName, defScale)
            W.SyncOverlayMode(frame, frameName)
            W.SyncAllUISpecialFrames()
            if showToast and frame.IsShown and frame:IsShown() then
                ShowWindowToast(frame, string.format("Reset to Default (%d%%)", math.floor(defScale * 100 + 0.5)), false)
            end
        end
    end
    DesktopWindows.ResetSingleBlizzardWindow = DesktopWindows.ResetSingleWindow

    function DesktopWindows:ResetAllWindows(arg1, arg2)
        local silent = (arg1 == DesktopWindows) and (arg2 == true) or (arg1 == true)
        WipeDesktopWindowEntryFromAllDBs(nil)
        for k in pairs(W.sessionScales) do
            W.sessionScales[k] = nil
        end
        for k in pairs(W.sessionPositions) do
            W.sessionPositions[k] = nil
        end
if InCombat() then return end
        if DesktopWindows:IsYielding() then return end
        for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
            DesktopWindows:ResetSingleWindow(spec.name, false)
        end
        W.SyncAllUISpecialFrames()
        if not silent then
            print(string.format("|cFF%sDynamicSuite:|r Reset all %d Blizzard window positions and scales to defaults.", GetSuiteAccentHex(), #SUPPORTED_BLIZZ_FRAMES))
        end
    end
    DesktopWindows.ResetAllBlizzardWindows = DesktopWindows.ResetAllWindows

    function DesktopWindows:Init(arg1, arg2)
        local loadedAddonName = (arg1 == DesktopWindows) and arg2 or arg1
        GetDesktopWindowsDB()
        if DesktopWindows:IsMasterDisabled() then
            return
        end
        W.HookEllesmereUICoexistence()
        EnsureGlobalPanelHooks()
        if _G.EventUtil and type(_G.EventUtil.ContinueOnAddOnLoaded) == "function" then
            for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
                local aName = spec.addon
                if aName and not W.addonContinueRegistered[aName] then
                    W.addonContinueRegistered[aName] = true
                    _G.EventUtil.ContinueOnAddOnLoaded(aName, function()
                        DesktopWindows:Init(aName)
                    end)
                end
            end
        end
        if InCombat() then
            for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
                if spec.protected and (loadedAddonName == nil or spec.addon == loadedAddonName) and _G[spec.name] then
                    W.pendingCombatWindowSetup[spec.name] = true
                end
            end
            return
        end
        if loadedAddonName then
            for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
                if spec.addon == loadedAddonName then
                    AttachFrameHooks(spec.name)
                end
            end
        end
        DesktopWindows:ApplyAllWindowStates()
    end
    DesktopWindows.InitBlizzardWindowQoL = DesktopWindows.Init

    function DesktopWindows:HandleCombatChange(arg1, arg2)
        local inCombat = (arg1 == DesktopWindows) and (arg2 == true) or (arg1 == true)
        if inCombat then
            for _, spec in ipairs(SUPPORTED_BLIZZ_FRAMES) do
                local f = _G[spec.name]
                if f then
                    if IsCombatProtectedPanel(spec.name) then
                        if W.blizzWinState[f] and W.blizzWinState[f].overlay then
                            W.SyncOverlayMode(f, spec.name)
                        elseif f.IsShown and f:IsShown() then
                            W.pendingCombatWindowSetup[spec.name] = true
                        end
                    else
                        W.SyncOverlayMode(f, spec.name)
                    end
                end
            end
            W.SyncCombatEscapeHandlers(true)
            SyncCtrlWheelOverlay()
            if W.scaleToast then W.scaleToast:Hide() end
        else
            W.SyncCombatEscapeHandlers(false)
            DesktopWindows:ApplyAllWindowStates()
        end
    end
    DesktopWindows.HandleBlizzardWindowCombatChange = DesktopWindows.HandleCombatChange

    addonTable.ApplyAllBlizzardWindowStates         = function() return DesktopWindows:ApplyAllWindowStates() end
    addonTable.ApplyAllWindowStates                 = function() return DesktopWindows:ApplyAllWindowStates() end
    addonTable.ResetSingleBlizzardWindow            = function(fName, toast) return DesktopWindows:ResetSingleWindow(fName, toast) end
    addonTable.ResetAllBlizzardWindows              = function(silent) return DesktopWindows:ResetAllWindows(silent) end
    addonTable.GetBlizzardWindowYieldAddon          = function() return DesktopWindows:GetYieldAddon() end
    addonTable.IsYieldingBlizzardWindowsToEllesmereUI = function() return DesktopWindows:IsYielding() end
    DynamicSuite.ApplyAllBlizzardWindowStates       = addonTable.ApplyAllBlizzardWindowStates
    DynamicSuite.ApplyAllWindowStates               = addonTable.ApplyAllWindowStates
    DynamicSuite.ResetSingleBlizzardWindow          = addonTable.ResetSingleBlizzardWindow
    DynamicSuite.ResetAllBlizzardWindows            = addonTable.ResetAllBlizzardWindows
    DynamicSuite.GetBlizzardWindowYieldAddon        = addonTable.GetBlizzardWindowYieldAddon
    DynamicSuite.IsYieldingBlizzardWindowsToEllesmereUI = addonTable.IsYieldingBlizzardWindowsToEllesmereUI
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
        local sub = (arg or ""):lower():match("^(%S*)") or ""
        if sub == "ellesmere" or sub == "eui" then
            if addonTable.PrintEllesmereConflictBreakdown then
                addonTable.PrintEllesmereConflictBreakdown()
            end
            return
        end
        if addonTable.PrintConflictSummary then
            addonTable.PrintConflictSummary()
        end
        if addonTable.OpenWorkspaceView then
            addonTable.OpenWorkspaceView("GUIDED_SETUP", 2)
        else
            OpenMainSuiteWindowFallback()
        end

    elseif cmd == "setup" or cmd == "guided" then
        if addonTable.OpenWorkspaceView then
            addonTable.OpenWorkspaceView("GUIDED_SETUP", 1)
        else
            OpenMainSuiteWindowFallback()
        end

    elseif cmd == "theme" then
        if addonTable.OpenWorkspaceView then
            addonTable.OpenWorkspaceView("THEME_STUDIO", 1)
            if addonTable.OpenSuiteStudioTab then
                pcall(addonTable.OpenSuiteStudioTab, 1)
            end
        elseif addonTable.OpenSuiteStudioTab then
            addonTable.OpenSuiteStudioTab(1)
        else
            OpenMainSuiteWindowFallback()
        end

    elseif cmd == "studio" then
        if addonTable.OpenWorkspaceView then
            addonTable.OpenWorkspaceView("THEME_STUDIO")
        else
            OpenMainSuiteWindowFallback()
        end

    elseif cmd == "windows" or cmd == "win" or cmd == "window" or cmd == "desktop" then
        if addonTable.OpenWorkspaceView then
            addonTable.OpenWorkspaceView("DESKTOP_WINDOWS", 2)
            if addonTable.OpenSuiteStudioTab then
                pcall(addonTable.OpenSuiteStudioTab, 2)
            end
        elseif addonTable.OpenSuiteStudioTab then
            addonTable.OpenSuiteStudioTab(2)
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

    elseif cmd == "spotlight" or cmd == "spotlights" then
        local sub = (arg or ""):lower():match("^(%S*)") or ""
        if sub == "reset" or sub == "clear" then
            if addonTable.ResetFeatureSpotlightsAndBadges then
                addonTable.ResetFeatureSpotlightsAndBadges()
            end
        else
            local entry = addonTable.GetLatestFeatureSpotlight and addonTable.GetLatestFeatureSpotlight()
            if entry and addonTable.ShowFeatureSpotlight then
                addonTable.ShowFeatureSpotlight(entry, true)
            else
                print(string.format("|cFF%sDynamicSuite:|r No feature spotlights are registered right now.", addonTable.GetCoreAccentHex()))
            end
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
    _G.DynamicSuite.DesktopWindows       = DesktopWindows
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
        ["DYNAMICCURSOR"] = "DynamicCursor",
        ["DYNAMICPREP"]   = "DynamicPrep",
        ["DYNAMICTALENT"] = "DynamicTalent",
        ["DYNAMICGROUP"]  = "DynamicGroup",
        ["DYNAMICBAGS"]   = "DynamicBags",
        ["DYNAMICCHAT"]   = "DynamicChat",
        ["DYNAMICMAIL"]     = "DynamicMail",
        ["DYNAMICVAULT"]    = "DynamicVault",
        ["DYNAMICDIALOGUE"] = "DynamicDialogue",
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
SafeRegisterSuiteEvent(suiteEventFrame, "ADDON_ACTION_FORBIDDEN")
SafeRegisterSuiteEvent(suiteEventFrame, "CINEMATIC_STOP")
suiteEventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_ACTION_FORBIDDEN" then
        if IsDynamicMarkerDisabledInSuiteCore() then return end
        local blockedFn = SafeReadableTaintString(arg2)
        if IsSetRaidTargetFunctionName(blockedFn) then
            local offender = SafeReadableTaintString(arg1)
            if not offender or offender == "" then
                local dvLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("DecorVendor"))
                offender = dvLoaded and "DecorVendor" or "Unknown Addon"
            end
            ShowRaidMarkerTaintModal(offender, "FORBIDDEN")
        end
        return
    elseif event == "PLAYER_REGEN_DISABLED" then
        DesktopWindows:HandleCombatChange(true)
        if addonTable.IsHudEditModeActive and addonTable.IsHudEditModeActive() and addonTable.ExitHudEditMode then
            addonTable.ExitHudEditMode()
        end
        if addonTable.OnSuiteEnterCombat then
            addonTable.OnSuiteEnterCombat()
        end
        addonTable.CollapseHubForCombat()
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        DesktopWindows:HandleCombatChange(false)
        if addonTable.OnSuiteLeaveCombat then
            addonTable.OnSuiteLeaveCombat()
        end
        addonTable.RestoreHubAfterCombat()
        if addonTable._pendingMarkerConflictModal then
            ShowMarkerConflictReloadModal()
        end
        if addonTable._pendingRaidTaintModal then
            local pend = addonTable._pendingRaidTaintModal
            addonTable._pendingRaidTaintModal = nil
            ShowRaidMarkerTaintModal(pend.addon, pend.reason)
        end
        if addonTable._pendingHudPositionReset and addonTable.ResetAllHudPositions then
            addonTable._pendingHudPositionReset = false
            addonTable._pendingHudClamp = false
            addonTable.ResetAllHudPositions(false)
        elseif addonTable._pendingHudClamp and addonTable.ClampAllSuiteHudsToScreen then
            addonTable._pendingHudClamp = false
            addonTable.ClampAllSuiteHudsToScreen()
        end
        if addonTable._deferredFeatureSpotlight and addonTable.ScheduleFeatureSpotlightCheck then
            addonTable.ScheduleFeatureSpotlightCheck(2.5)
        end
        return
    elseif event == "CINEMATIC_STOP" then
        if addonTable._deferredFeatureSpotlight and addonTable.ScheduleFeatureSpotlightCheck then
            addonTable.ScheduleFeatureSpotlightCheck(2.5)
        end
        return
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        if addonTable.ReclampMainWindowToScreen then
            addonTable.ReclampMainWindowToScreen()
        end
        ApplyHubClampInsets()
        if not InCombatLockdown() then
            DesktopWindows:InvalidateNativeScales()
            DesktopWindows:ApplyAllWindowStates()
        end
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
            GetDesktopWindowsDB()
            EnforceProtectedSuiteModules()
            SnapshotAllSuiteCVars()
            if addonTable.EnforceFrozenAddonsDisabled then
                addonTable.EnforceFrozenAddonsDisabled()
            end
            if addonTable.HookGameMenu then
                addonTable.HookGameMenu()
            end
            DesktopWindows:Init()
        elseif arg1 == "DynamicPrep" then
            GetDesktopWindowsDB()
            if isSuiteCoreInitialized then
                DesktopWindows:ApplyAllWindowStates()
            end
        elseif isSuiteCoreInitialized and DesktopWindows.SUPPORTED_ADDON_TRIGGER and DesktopWindows.SUPPORTED_ADDON_TRIGGER[arg1] then
            DesktopWindows:Init(arg1)
            if addonTable.mainFrame and addonTable.mainFrame.themeView and addonTable.mainFrame.themeView:IsShown() and addonTable.mainFrame.themeView.Refresh then
                pcall(addonTable.mainFrame.themeView.Refresh)
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        hasEnteredWorld = true
        local isLoginOrReload = (arg1 == true or arg2 == true)
        if isLoginOrReload then
            InvalidateConflictCache()
            EnsureConflictCache()
            EnforceStandaloneDynamicMarkerExclusion(true)
            DesktopWindows:ApplyAllWindowStates()
        end
        if standaloneMarkerWasEnabledAtBoot or addonTable.standaloneMarkerWasEnabledAtBoot or (DynamicSuite and DynamicSuite.standaloneMarkerWasEnabledAtBoot) or (_G.DynamicSuite_StandaloneMarkerWasEnabledAtBoot == true) then
            ShowMarkerConflictReloadModal()
        end
        if IsDecorVendorActiveForQuarantine() then
            ShowRaidMarkerTaintModal("DecorVendor", "PROACTIVE")
        end
        if (isLoginOrReload or addonTable._deferredFeatureSpotlight) and addonTable.ScheduleFeatureSpotlightCheck then
            addonTable.ScheduleFeatureSpotlightCheck(2.5)
        end
    elseif event == "PLAYER_LOGIN" then
        InvalidateConflictCache()
        EnsureSuiteGlobal()
        local dwDB = GetDesktopWindowsDB()
        MigrateDesktopWindowsFromPrep(dwDB, true)
        DesktopWindows:Init()
        DynamicSuite:ScanExternalMedia(true)
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
        C_Timer.After(1.5, function()
            DynamicSuite:ScanExternalMedia(true)
            if addonTable.UI and type(addonTable.UI.RefreshAllFonts) == "function" then
                pcall(addonTable.UI.RefreshAllFonts, true)
            end
            if _G.DynamicChat and type(_G.DynamicChat.ApplySleekChatSkin) == "function" then
                pcall(_G.DynamicChat.ApplySleekChatSkin, _G.DynamicChat)
            end
        end)
    end
end)
