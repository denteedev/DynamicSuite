# DynamicSuite Changelog
*Author: Dentee-Frostmourne  |  Release: v1.9.9 (14/11/2026 - Retail 12.1.5 / Interface 120105)*

---

## DynamicSuite & All 8 Modules v1.9.9 (14/11/2026)

### Added
* **Season Dungeon Portals & 1-Click Dungeon Filter Deck (DynamicGroup):** Added a compact portal bar above Premade Groups displaying your current Mythic+ keystone pill and the 8 active season dungeons with your best timed key levels, dynamically resolving learned Midnight Season 2 teleports from the Mythic+ tab and spellbook. Left-click a dungeon tile to toggle the LFG filter (Shift + Left-Click to solo filter), or Right-Click out of combat to cast its dungeon teleport once learned.
* **Dungeon Joined & Group Full Teleport Toast (DynamicGroup):** Added a 410x74 dark-obsidian quick-teleport banner matching DynamicSuite's Alert Toast style with a one-click Dungeon Teleport button and Right-Click dismissal when your Premade Group application is accepted, playing a join chime as members enter and alerting you when the group hits 5/5. Shares DynamicSuite's Alert Toast HUD Edit slot with smart mutual stacking, **Test Join (3/5)** / **Test Full (5/5)** / **Edit HUD** buttons, and `/dg testtoast`.
* **Integrated Multi-Toggle Group Filters & Open-Slot Role Icons (DynamicGroup):** Upgraded the Group Finder filter menu with Tank, Healer, and DPS role availability toggles (with role icons), No Duplicate Class, Has Tank, Has Healer, Bloodlust/Heroism, and Battle Rez (kept in two-way sync with Blizzard's native Filter button without altering difficulty checkboxes), alongside a cleaner borderless Region / Leader IO pill (`OCE`, `USE`, `USW`, `USC`, `LA`, `BR`), a simplified Show Region & Leader IO Badge toggle, desaturated greyscale Tank/Healer/DPS icons matched to Blizzard's slot size over empty group slots, and personal best key levels on tooltips.

### Fixed
* **Top & Bottom Screen-Edge Bar Drift:** Focus Icons and World Flare bars parked flush against the top edge, bottom edge, or corners now stay in their exact saved positions after reloading the UI at every bar scale (70%, 100%, and 130%).
* **DynamicLoad Profile Switching & Standalone Scrubbing:** Fixed a Lua error when staging zone profiles (such as Outdoor) in DynamicLoad and ensured saved zone profiles never re-enable standalone DynamicMarker while DynamicSuite is active.
* **Duplicate HUD Edit Windows:** Standalone DynamicMarker's extra HUD Edit popup no longer appears when running DynamicSuite, leaving only the unified bottom HUD Edit dock while keeping standalone HUD Edit Mode intact when run solo.
* **DynamicMarker Reset Bounds:** Resetting HUD positions (`/ds resethud`, `/dm resethud`, or from Options) now resets scale to 100%, restores horizontal layout, and keeps bars cleanly inside your screen bounds.
* **Automatic Standalone Handoff:** Running both DynamicSuite and standalone DynamicMarker together now cleanly disables the standalone copy on launch and prevents duplicate bars or settings conflicts.

### Improved
* **Reliable Dark-Obsidian Coexistence Reload Prompt:** Replaced Blizzard's default popup with a matching dark-obsidian reload modal that reliably appears on entering the world (or right after combat ends) whenever both DynamicSuite and standalone DynamicMarker were enabled at launch.
* **Storefront, Slash Command & Documentation Audit:** Verified all 24 slash commands across modules, removed retired aliases from public documentation and in-game changelogs, and aligned the README, CurseForge pages, and release notes with live behaviour.
* **Plain-English UI & Reset Prompt Polish:** Rewrote the Restore Blizzard Defaults card, reset confirmation dialogs, and module tooltips across DynamicSuite and standalone DynamicMarker in clear, jargon-free Australian English that fits cleanly without truncation.

---

## DynamicSuite & All 8 Modules v1.9.8 (14/11/2026)

### Fixed
* **Edge-Dragged Marker & Flare Bars:** Target Icon and World Flare bars dragged to screen edges at smaller scales (such as 70% or 75%) no longer jump inward on mouse release or after reloading the UI.
* **Flush Bottom-Left Chat Positioning:** DynamicChat now sits completely flush against the bottom-left corner at X = 0, Y = 0 with no ~30px gap across Edit Mode toggles, scale changes, and reloads.

### Improved
* **Release Channel Packaging:** Streamlined automated CurseForge release packaging across both DynamicSuite and standalone DynamicMarker.

---

## DynamicSuite & All 8 Modules v1.9.7 (14/11/2026)

### Added
* **Official Dual CurseForge Support:** Full DynamicSuite is now live on CurseForge alongside standalone DynamicMarker, with direct cross-links in both Support panels.

### Fixed
* **Load-Order Coexistence:** All 8 modules cleanly defer to the newer version if standalone and suite installs are present at the same time, regardless of load order.

---

## DynamicSuite & All 8 Modules v1.9.6 (14/11/2026)

### Added
* **Magnetic HUD Snapping & Alignment Guides:** Bars now snap cleanly to screen edges, screen centres, and neighbouring HUD bars with live alignment lines (hold Shift to fine-tune freely).
* **HUD Reset Failsafe:** Added Reset HUD Positions in Blizzard Options alongside `/ds resethud` and `/dm resethud` (safely deferred if used in combat).
* **More Bag Commands:** Added `/dbag` shortcuts for merge, clear, bank, warband, guild, and help.

### Fixed
* **Zero-Flash Bank & Guild Bank:** Blizzard's default Bank and Guild Bank frames no longer flash briefly when opening DynamicBank after a reload.
* **Guild Bank Tab Snapshots & Sorting:** Unqueried Guild Bank tabs keep their saved item snapshots across reloads while queried tabs update live down to 0 items, A-Z sorting handles uncached items cleanly, and stack splitting works smoothly across specialised bags.
* **Auto-Repair, Auto-Sell & Fast Loot:** Synchronised Tab 3 merchant automation toggles, guarded fast auto-loot bursts, and updated delete-confirmation auto-fill for Retail 12.1.5.

### Improved
* **Standalone Changelog Viewer:** Standalone DynamicMarker's Changelog modal now scrolls through full release notes with colour-coded badges matching DynamicSuite.

---

## DynamicSuite & All 8 Modules v1.9.5 (14/11/2026)

### Added
* **Standalone Window Controls & Copyable Support Links:** Added Window Opacity (50%-100%), Scale (80%-120%), a Reload UI button, and click-to-copy support links to standalone DynamicMarker.
* **Marker Slash Aliases:** Added `/fm` and `/focusmarker` aliases alongside `/dm`, plus `/dm help` and bar lock toggling via `/dm lock`.

### Improved
* **Cleaner Footer Resize Grip:** Replaced the text resize grip with Blizzard's native corner resize icon and added clean spacing next to the Reload UI button.

---

## DynamicSuite & All 8 Modules v1.9.4 (14/11/2026)

### Fixed
* **First-Open Options Launcher:** Opening DynamicSuite or standalone DynamicMarker from ESC > Options > AddOns now renders the full sidebar, workspace, and theme cleanly on the very first open.

---

## DynamicSuite & All 8 Modules v1.9.3 (14/11/2026)

### Fixed
* **Guided Setup Modal Layering:** Fixed underlying window controls bleeding through the Guided Setup modal in standalone DynamicMarker.

### Improved
* **Standalone Theme & Sidebar Parity:** Added all 4 dark surface themes and matching sidebar card spacing to standalone DynamicMarker.

---

## DynamicSuite & All 8 Modules v1.9.2 (13/11/2026)

### Added
* **Standalone & Bundled DynamicMarker HUD Edit Mode Parity:** Unified Target Icon Bar and World Flare Bar Edit Mode movers, magnetic snapping, mousewheel scaling (60%-150%), Shift+Right-Click per-bar reset, and combat/Escape exit protection across both DynamicSuite and standalone DynamicMarker (`/dm hud`).
* **One-Time FocusMarker Settings Import:** Automatically detects existing FocusMarker settings at launch (covering both older and newer layouts) and imports bar positions, scales, visibility rules, and icon/flare order without altering your original FocusMarker data.
* **Automatic CurseForge Release Packaging:** Added automated build and release configuration separating full 8-module DynamicSuite from standalone DynamicMarker.

### Improved
* **Standalone DynamicMarker Shell & Options Launcher:** Hid unused module slots when running standalone, added ESC > Options > AddOns quick-launch cards with Amber/Gold dark-obsidian styling, fixed Guided Setup backdrop dimming and text clipping, and matched sidebar tools, changelog, and support views 1:1 with DynamicSuite.

---

## DynamicSuite & All 8 Modules v1.9.1 (13/11/2026)

### Added
* **Two-Tier Conflict Resolution Engine:** Upgraded the Guided Setup Conflict Scanner (Step 1) with a scrollable card list, accurate sidebar ! badge counts, Hard Exclusivity choices ("Use Dynamic[Module] Only" vs "Use [Addon] Only") for full-replacement bag, chat, LFG, camera, and marker addons, and Granular Overlap choices for narrative, tooltip, and QoL companions.
* **Uninstall Prep & Restore Blizzard Defaults:** Added a two-option Reset menu at the bottom-left of DynamicSuite (Reset Settings Only vs Restore Blizzard Defaults) plus matching per-module restore controls in DynamicFPS, DynamicZoom, DynamicChat, and DynamicBags.

### Fixed
* **Graphics Settings 1:1 Sync in DynamicFPS:** Synchronised Texture Resolution, View Distance, Environment Detail, Ground Clutter, Particle Density, and Spell Density sliders and pills with Blizzard's Graphics menu across both normal and raid profiles.
* **DynamicLoad Core Protection & Disable Confirmation:** Simplified the DynamicSuite and standalone DynamicLoad rows to clear Always / Never buttons, added a theme-matched "Disable & Reload UI" confirmation prompt, fixed tree-list startup errors, and restored draggable changelog scrollbars.
* **Auto-Hiding Chat Scrollbars & Responsive Auto-Gossip:** Skinned chat scrollbars now stay hidden when idle and fade in cleanly on hover or scrolling, while single-option Auto-Gossip now works reliably on interactive world objects (hold Shift to bypass).
* **Unified Target Whisper Shortcut:** Streamlined target whispering onto `/ww` across all chat and whisper tabs (including self-whisper testing), with `/lg` dedicated to leaving your group quickly.

---

## DynamicSuite & All 8 Modules v1.9.0 (12/11/2026)

### Added
* **FocusMarker Snapshot & Re-Import Commands:** Added `/dm import` and `/dm import status` so you can re-import captured FocusMarker settings anytime out of combat, even after FocusMarker is disabled.
* **Guild Bank Daily Withdrawal Counters:** Each Guild Bank tab now shows a colour-coded badge with your remaining item withdrawals for the day while at the bank.

### Fixed
* **Single-Option Auto-Gossip & Dialogue Chains:** Fixed single-option Auto-Gossip not triggering on everyday NPCs and multi-step quest/dungeon dialogues, while preventing repeated double-clicks in the same conversation.

---

## DynamicSuite & All 8 Modules v1.8.0 (12/11/2026)

### Added
* **Flexible Window Dragging & Combat Collapse Pill (`/ds`, `/ds reset`):** Drag the DynamicSuite window partially off-screen while keeping the top title bar reachable; entering combat cleanly collapses an open settings window into a small clickable combat pill and restores it afterwards.

### Fixed
* **Guild Bank Uncached Items & Permission Badges:** Prevented errors when opening Guild Bank tabs whose items are still loading from the server, and added clear view-only protection badges and tooltips.

### Improved
* **Plain-English UI Clarity Across All 8 Modules:** Replaced technical wording across settings cards, tooltips, and status bars with clear, everyday player terminology.

---

## DynamicSuite & All 8 Modules v1.7.3 (12/11/2026)

### Fixed
* **Flush Bottom-Left Chat Anchoring:** Stopped WoW's default screen-clamping margins from pushing DynamicChat ~18px inward from the bottom-left corner after UI reloads, and migrated legacy saved chat positions to exact (0, 0) bottom-left alignment while keeping your saved size.

---

## DynamicSuite & All 8 Modules v1.7.2 (12/11/2026)

### Fixed
* **Container-First Chat Positioning & Edit Mode Recovery:** Anchored the outer smoked-glass chat container first at (0, 0) bottom-left so tab headers, borders, and input boxes never drift apart after reloads or Blizzard Edit Mode changes.
* **Open-World & Instance Object Auto-Gossip:** Expanded single-option Auto-Gossip to interact smoothly with standard speech-bubble NPCs and world objects (hold Shift to bypass).

---

## DynamicSuite & All 8 Modules v1.7.1 (12/11/2026)

### Fixed
* **Raid Buff Scanner Error Fix:** Fixed a script ordering issue during raid buff scanning in DynamicPrep and hardened group buff checks for Midnight 12.1.5 combat restrictions.

---

## DynamicSuite & All 8 Modules v1.7.0 (12/11/2026)

### Added
* **Off-Screen Hub Dragging & Combat-Safe View:** Added flexible screen-edge dragging with `/ds reset` to recentre the hub, combat auto-collapse pills, and a safe read-only combat view when opening `/ds` mid-fight.
* **FocusMarker Settings Import in Standalone & Suite:** Connected legacy FocusMarker saved settings to DynamicMarker's setup and manual Import from FocusMarker button.
* **Restore Blizzard Defaults Tool:** Added pre-addon graphics/camera/chat/bag snapshots so you can cleanly revert game settings before uninstalling.
* **Sleek Dark Scrollbars for Chat & History:** Added custom mouseover-friendly dark scrollbars to skinned chat frames and the full Chat History modal.

### Fixed
* **Simplified Target Whisper Commands:** Dedicated `/ww` strictly to instant target whispering (with `/lg` for quick group leave and `/rl` for quick UI reload), updating all labels, Smart Search entries, and Guided Setup copy accordingly.
* **Conflict Toast, Sidebar Performance & Left-Rail Fixes:** Restored the login conflict notification with a 1-click Resolve shortcut, cached conflict badges so switching sidebar modules is instantaneous, cleaned up `/reload` first-click errors, and listed only real installed addon folders in DynamicLoad.

---

## DynamicSuite & All 8 Modules v1.6.3 (12/11/2026)

### Fixed
* **Midnight 12.1.5 Catalyst & Event Cleanup:** Removed an outdated interaction event warning on login and ensured One-Click Catalyst hooks attach cleanly the first time the Catalyst frame opens.
* **Bottom-Left Chat Flush Anchor Migration:** Defaulted chat placement strictly to bottom-left (0, 0) across reloads, sidebar toggles, whisper boxes, and HUD resizing.

---

## DynamicSuite & All 8 Modules v1.6.2 (12/11/2026)

### Fixed
* **Exact 0px Chat Alignment:** Synchronised chat container bounds with HUD Edit Mode drag shields so parking chat at the bottom-left corner stays locked at (0, 0).
* **Removed Stray Duplicate Module Files:** Cleaned up leftover duplicate script files so only the 8 canonical modules exist.

---

## DynamicSuite & All 8 Modules v1.6.1 (12/11/2026)

### Improved
* **Smoother Raid Combat Performance in DynamicPrep:** Throttled in-combat aura scans to brief coalesced intervals and skipped redundant player-aura stat-bar redraws mid-fight.

---

## DynamicSuite & All 8 Modules v1.6.0 (12/11/2026)

### Added
* **Read-Only Conflict Auto-Yield Option:** Guided Setup and module banners respect frozen/disabled competing addons automatically and give a 1-click switch + Reload UI button when taking over chat or bag skinning.

### Fixed
* **Reliable "Never" Lock Persistence Across Sub-Addons:** Setting any addon or sub-module to Never in DynamicLoad now locks cleanly across character, global, and zone tables so parent UI suites cannot quietly re-enable them at login.

---

## DynamicSuite & All 8 Modules v1.5.0 (12/11/2026)

### Added
* **One-Click Revival Catalyst Conversion:** Enabled by default in DynamicPrep Tab 3 so clicking Transform immediately converts your item without a second confirmation wait (hold Shift for the normal confirmation popup).
* **In-Combat Raid Performance & Modifier-Free Healing Macro:** Upgraded DynamicPrep combat buff scanning with zero-waste aura lookups, suppressed out-of-combat consumable checks mid-pull, improved [DynamicHeal] Healthstone -> Potion priority switching, reinforced Hold CTRL to Release Spirit protection, and hardened in-combat `/ww` whispers.

### Fixed
* **Chat HUD Mover Alignment & Translucent Dragging:** Fixed separator text glitches on HUD movers, hid the Chat mover automatically when DynamicChat is turned off or yielding, and made the drag overlay translucent so live chat text stays visible while moving.

---

## DynamicSuite & All 8 Modules v1.4.7 (12/11/2026)

### Fixed
* **HUD Mover Display & Chat Frame Sizing Sync:** Fixed separator pipe formatting in mover headers, synchronised chat window scale and position 1:1 with its Edit Mode mover, and ensured the Chat mover hides completely when DynamicChat is disabled.

---

## DynamicSuite & All 8 Modules v1.4.6 (12/11/2026)

### Fixed
* **Combat-Ready `/ww` Whisper & Hold CTRL Release Protection:** Hardened `/ww` target whispering during combat (and in Battle.net whisper contexts), reinforced per-frame button locking on the Death popup until CTRL is held, and upgraded [DynamicHeal] to reset cleanly to Healthstone first after combat ends.

---

## DynamicSuite & All 8 Modules v1.4.5 (12/11/2026)

### Fixed
* **DynamicLoad Suite Tree Startup Fix:** Fixed a scoping error when evaluating bundled module statuses inside the DynamicLoad addon list.

---

## DynamicSuite & All 8 Modules v1.4.4 (12/11/2026)

### Added
* **Unified In-Combat Missing Raid Buff Icon:** Replaced the separate floating combat text alert with a clean icon on your Readiness Tracker Strip (showing counts such as 16/17 with a clear MISSING badge) that disappears automatically once everyone is buffed, while hiding non-combat consumables mid-pull.

---

## DynamicSuite & All 8 Modules v1.4.3 (12/11/2026)

### Fixed
* **Clean DynamicChat Toggle Off & Instant Teardown:** Turning DynamicChat Off in the sidebar now disables all chat skinning, custom tabs, side rails, and `/ww` hooks cleanly (with live frame teardown and a Reload UI prompt), and synchronises module checkmarks 1:1 with DynamicLoad.

---

## DynamicSuite & All 8 Modules v1.4.2 (12/11/2026)

### Fixed
* **Safe Conflict Handling for UI Suites:** Ensured competing addons are only disabled when you explicitly click to switch, recovered accidentally locked UI suite components on login, and enabled clean coexistence when chat skinning yields to external suites.

---

## DynamicSuite & All 8 Modules v1.4.1 (12/11/2026)

### Fixed
* **DynamicPrep Readiness Strip & Info Bar Layout Labels:** Resolved an error during raid buff scanning that could interrupt Tab 1 pill labels, and widened Guided Setup / banner conflict buttons so text never clips.

---

## DynamicSuite & All 8 Modules v1.4.0 (12/11/2026)

### Added
* **Symbiotic Relationship, Exact Food Stats & Combat Resurrection Buff Tracker:** Automatically detects Symbiotic Relationship links on allies, reads exact stat amounts from Well Fed food buffs, and highlights recently battle-rezzed allies needing class raid buffs.
* **Suite-Wide Conflict Detector & `/ds conflicts`:** Scans all 8 modules for competing bag, chat, quest, camera, nameplate, LFG, and combat logger addons with clear in-banner resolution choices.

### Fixed
* **On-Screen Marker & Flare Bar Solo Visibility:** Switching Focus Icons or World Flares between Off, Group Only, and Always now updates live immediately (even while Settings are open) without forcing bars visible when solo.
* **Battle.net Whisper Stability & Compact Setup Tabs:** Prevented secret-value errors when using Battle.net whispers alongside `/ww`, deduplicated Guided Setup Step 1 conflict cards, and shortened the 9 Guided Setup tab labels so nothing truncates.

---

## DynamicSuite & DynamicLoad v1.3.0 (11/11/2026)

### Added
* **Unified Single-Entry Architecture:** Consolidated all 8 modules (DynamicLoad, DynamicPrep, DynamicMarker, DynamicZoom, DynamicFPS, DynamicGroup, DynamicBags, DynamicChat) cleanly under one DynamicSuite entry in Blizzard's AddOns list while keeping every module runnable standalone from the same codebase.
* **Global Smart Search (`/ds search <query>`):** Added plain-English feature search in the top-left sidebar across nearly 200 settings with category filter pills (All, Combat & Raid, FPS & Camera, HUD & Look, Bags & QoL, Group & Chat) and 1-click jump-and-highlight navigation.
* **Drag-and-Drop Sidebar Reordering & HUD Edit Esc Failsafe:** Drag module cards or click stacked up/down arrows to reorder the sidebar (keeping DynamicLoad first), and exit HUD Edit Mode cleanly anytime with Escape or closing the Game Menu.

### Fixed
* **Labyrinth Delve Toast Anti-Spam & Chat Flush Docking:** Stopped DynamicLoad profile change toasts from re-appearing between seamless Delve chambers, fused the smoked-glass chat frame cleanly with its tab strip and input bar, and locked canonical sidebar module icons across all 8 modules.

---

## DynamicSuite & DynamicLoad v1.2.0 (11/11/2026)

### Added
* **6-Target HUD Edit Mode (`/ds hud`):** Unified dragging, scaling (60%-150%), nudging, grid/magnet snapping, and bottom-right resizing across Alert Toast, Prep Bar, Focus Icons, World Flares, Raid Buffs, and Chat Frame.
* **7-Step Guided Setup, Unread Changelog Highlight & Account/Character Scope:** Added the interactive setup wizard, [Global] vs [Character] top-bar scope toggle, unread Alert-Gold highlighting on Changelog, and semantic By Zone / Always / Never badges.
* **Two-Badge Header Status Capsule:** Split DynamicLoad's status capsule into Loaded Profile (Green) and Current Zone (Cyan) with 1-click Auto-Switch resume when an instance overrides a manual outdoor profile.

### Improved
* **Standardised Dark-Obsidian Design System:** Unified 2-line L-bracket section headers, sleek precision track sliders, muted Slate-Charcoal "Off" pills (so negative options never glow in accent colour), consistent bottom footer hints, and command-prefix-only tooltip highlighting across every module.

### Fixed
* **UI Responsiveness & Visual Polish:** Eliminated settings-open client stalls, preserved scroll position when toggling addon load rules, and protected manual profile picks across reloads.

---

## DynamicMarker v1.3.0 (`/dm`, `/dynamicmarker`, `/fm`, `/focusmarker`)

### Added
* **30x30 Icon & Flare Pickers + Party-Only Raid Silence:** Crisp square pickers for all 8 raid target markers and world flares, automatic raid chat silencing in Party Only mode, and solo target-dummy macro support.

### Improved
* **Modifier-Free [DynamicMark] & Multi-Spec [DynamicKick]:** 1-click focus and raid marking plus automatic interrupt spell detection for every class and specialisation across all 13 classes.
* **Reactive Macro Step Buttons & Sleek Controls:** Highlights Step 1 (Create Macro) or Step 2 (Pick Up for Bar) automatically until placed on your action bar, alongside L-bracket section borders and full-width Sub-Settings drawers.

### Fixed
* **Combat-Safe HUD Exit & Full-Screen Bar Dragging:** Safely queues HUD changes during combat, protects mouseover kicks when no focus is set, cleans up Escape-key grid overlays, and fixes flare reset defaults and bar edge alignment.

---

## DynamicZoom v1.3.0 (`/dz`, `/dynamiczoom`)

### Added
* **Reactive Scroll-Wheel Accelerator:** Smoothly glides to 39 yards on fast mousewheel flicks while keeping slow adjustments crisp and exact.

### Improved
* **Smart Occlusion Shield & Situational Profiles:** Fades obstructing trees and dungeon pillars instead of snapping your camera forward, and separates Delves/Scenarios from PvP Arenas/Battlegrounds zoom sliders.

### Fixed
* **Portal ActionCam Persistence & Safe Defaults Recovery:** Preserves over-the-shoulder ActionCam offsets through portals and loading screens, prevents unwanted experimental setting warning popups, defers protected camera changes until after combat, and snapshots pre-addon camera defaults for clean recovery.

---

## DynamicFPS v1.3.0 (`/dfps`, `/dynamicfps`)

### Added
* **1:1 Blizzard Graphics Menu Parity & Smart SpellQueueWindow Engine:** Mirrors Blizzard's exact quality tiers, Spell Density (Essential / Reduced / Everything), SSAO, Depth Effects, and CPU Distance/Clutter sliders (1-10) across 6 zone profiles, plus automatic SpellQueueWindow tuning from your live ping, spec, and haste with a live telemetry readout.
* **1-Click Hardware Presets & Boss Telegraph Safety Lock:** Instant Low-End PC, Balanced, Competitive FPS, and High-End Ultra presets per zone with projected boss floor mechanics locked visible in Dungeons and Raids.

### Improved
* **Clearer Controls & Zone Toolbar:** Combined zone status, copy-from-zone buttons, and hardware presets into one compact toolbar, clarified Revert to Base and Minimum Combat FPS descriptions, and added external combat logger auto-yield detection.

### Fixed
* **Combat Protection & Objective Tracker Stability:** Protected combat-restricted settings during active Mythic+ keys and boss pulls, fixed Objective Tracker combat taint, suppressed BossBanner overlap cleanly when muted, and preserved scroll positions when adjusting bottom cards.

---

## DynamicPrep v1.3.0 (`/dprep`, `/dp`)

### Added
* **Midnight Telemetry Omni-Bar & Clickable Raid Buffs HUD:** Customisable 12-segment top info bar (Stats, Spec/Loot, Keystone, Dur, FPS, Ping, Ready Check, Pull Timer) paired with a clickable bar for class raid buffs, single-target partner buffs (Symbiotic Relationship, Source of Magic, Blistering Scales, Earth Shield, Beacons) with smart role targeting, Midnight food/flask/oil/augment rune checks, and live [DynamicHeal] action-bar status badges.

### Improved
* **Streamlined 3-Tab Workspace:** Focused Tab 1 on Top Info Bar Layout Builder, Tab 2 on Raid Buffs & Omni Folio, and Tab 3 on World, Instance & Survival Automation while keeping Merchant, Loot, and Keystone automation in their dedicated modules.

### Fixed
* **Zero-Delay Banker Gossip, Secret Aura Guards & Auto-Gossip Fixes:** Opens DynamicBank instantly at Banker NPCs without DialogueUI window flicker, synchronises Omni Folio clicks across key-down/key-up settings, supports Midnight's 40th spec (Devourer Demon Hunter), prevents secret-aura errors mid-combat, and resolves world object, Delve lever, and quest-book Auto-Gossip edge cases.

---

## DynamicGroup v1.3.0 (`/dgroup`, `/dg`)

### Added
* **Premade Groups Mini-Bar & 1-Click Sign-Up:** Filter Premade Groups live by Datacentre Region (OCE, US-W, US-C, US-E, LATAM, BR), Minimum M+ Score, and Party Utility (Bloodlust / Battle Rez), with compact region/score row badges, tooltip utility breakdowns, and 1-click sign-up.
* **Live Roster Audit & Dedicated Keystone Auto-Slotting:** Inspect party gear, enchants, and consumables at a glance, auto-invite friends/guildies by whisper keyword, and automatically slot your Mythic+ keystone when opening the Font of Power.

### Fixed
* **Locked Row Order, Async Region Filtering & Zero-Taint LFG Hooks:** Prevents listings from jumping under your cursor during updates, fixes tooltip errors when a listed group fills or expires mid-hover, supports raid conversion cleanly on 6th+ auto-invites, and yields safely to other LFG addons when configured.

---

## DynamicBags v1.3.0 (`/dbag`, `/dbags`)

### Added
* **Zero-Lag Virtual Category Bags, Bank Vault & Quick-Open Queue:** Instant category sorting (Keystones, Consumables, Gear Sets, BoE/WuE, Reagents, Junk), unified Personal, Reagent, Warband, and Guild Bank viewer, worldwide Alt Inventory browser, persistent per-mode Bank sub-tab memory, drop-anywhere split stacks, Midnight consumable tier badges, and a 1-spot Quick-Open queue button (Open N) for Soulbound caches/pouches alongside safe auto-open.
* **Unified Merchant, Loot & Delete Automation (Tab 3):** Consolidated Auto-Repair Equipment (with Guild Bank First vs Personal Gold toggle), Auto-Sell Grey Junk, Faster Auto-Loot, and Auto-Fill DELETE confirmations in one home.

### Fixed
* **Instant Mid-Combat Bag Toggle, Zero-Flash Bank Opening & Multi-Pass Stack Merging:** Lets you open and close bags anytime in combat, stops Blizzard's Bank and Guild Bank frames from flashing on first visit, merges split crafting/consumable stacks reliably across multiple passes without slot-lock collisions, and protects Warband Until Equipped and Equipment Set badges across snapshots.

---

## DynamicChat v1.3.0 (`/dchat`, `/dc`, `/dynamicchat`)

### Added
* **Scrollable Top Chat Tabs, Smoked-Glass Container & Per-Channel Sound Alerts:** Keeps every open chat and whisper tab at full readable width with mousewheel and < / > tab scrolling, wraps chat in a unified smoked-glass container with a compact monochrome icon Left Utility Rail (Social, Durability, 1-Click Great Vault, Copy History, Combat Log, Lock/HUD, Settings, Jump to Bottom), and supports custom alerts across 11 channels with 12 built-in sounds and LibSharedMedia support.
* **Chat History Across Reloads, Clickable URLs & Instant `/ww` Whisper Engine:** Saves recent messages across UI reloads (up to 500 lines), captures recent web/Discord/Wago links into the Copy History modal, turns `/ww` cleanly into a native target whisper (including in combat and M+ keys), and adds `/rl` (Reload UI) and `/lg` (Leave Group) shortcuts.

### Fixed
* **Zero-Taint Retail 12.1.5 Chat Compliance & Smooth Combat Log Switching:** Keeps protected raid, party, instance, and whisper channels free of secret-string errors, prevents invisible Blizzard side buttons from stealing rail clicks, caps Combat Log backlog lag when switching tabs, fixes overflow whisper tab clipping, and ensures Blizzard default backgrounds stay hidden on hover.
