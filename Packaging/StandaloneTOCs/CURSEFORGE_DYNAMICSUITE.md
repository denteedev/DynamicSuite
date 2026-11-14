# DynamicSuite -- CurseForge Storefront Copy & Release Changelog (v1.9.7)

> **Target Game Version:** World of Warcraft Retail Midnight `12.1.5` (Interface `120105`)  
> **Version:** `v1.9.7` (`14/11/2026`)  
> **CurseForge Project ID:** `1804382`  
> **Author:** Dentee-Frostmourne  
> **CurseForge Project Page:** https://www.curseforge.com/wow/addons/dynamicsuite

---

## Section 1: CurseForge Project Description (Copy & Paste Markdown)

```markdown
# DynamicSuite -- 8-Module Retail Midnight QoL, Utility & Performance Hub

[![Support Me on Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/dentee)

**World of Warcraft Retail Midnight `12.1.5` (Interface `120105`) | Author: Dentee-Frostmourne**

**DynamicSuite** (`/ds`, `/dynamicsuite`) is a lightweight, zero-taint all-in-one Quality-of-Life, Mythic+/Raid utility, inventory, chat, and performance hub for **World of Warcraft Retail Midnight `12.1.5`**. Built on a **Single-Entry Consolidated Dual-Mode Architecture**, it bundles **8 tightly integrated modules** under one cohesive Obsidian Studio control panel (`/ds`) with shared theming, **202 indexed Smart Search settings**, a **6-target HUD Edit Mode**, and a **9-step Guided Setup & Conflict Scanner**.

Looking for just the target marking & interrupt macro module? Check out standalone **[DynamicMarker on CurseForge](https://www.curseforge.com/wow/addons/dynamicmarker)**.

---

## Key Suite Architecture & Core Tools

* **Unified Studio Hub (`/ds`):** Clean resizable Obsidian window with a persistent 3-zone header, 8-module Left Suite Rail (with live `[On]`/`[Off]` toggles and reorderable cards), plus Blizzard **Game Menu** (`DynamicSuite` / `DynamicSuite HUD`) and `ESC -> Options -> AddOns` launcher buttons.
* **Global Smart Search (`/ds search <query>`):** Instant fuzzy search across **202 indexed settings** powered by plain-English intent synonyms, **6 live-counted category filter pills** (`All`, `Combat & Raid`, `FPS & Camera`, `HUD & Look`, `Bags & QoL`, `Group & Chat`), and 1-click **Jump-and-Highlight** routing straight to the right module, sub-tab, or sub-drawer.
* **Unified `[+ HUD]` Edit Mode (`/ds hud`, `/ds edit`, `/ds resethud`):**
  * **6 Movable HUD Targets:** `Alert Toast` (`DynamicLoad`), `Prep Bar` (`DynamicPrep`), `Raid Buffs` (`DynamicPrep`), `Focus Icons` (`DynamicMarker`), `World Flares` (`DynamicMarker`), and `Chat Frame` (`DynamicChat`).
  * **1:1 Scale-Aware Dragging:** Accurately translates cursor movement, frame scale (`60%`-`150%`), and `UIParent` scale so bars track your cursor `1:1` at every UI scale (including `70%`).
  * **Magnetic Screen-Edge & Bar-to-Bar Snapping:** Magnetically snaps within `11px` of screen borders/centre axes and within `9px` of neighbouring visible HUD bars (flush stacking & alignment across mixed scales) with clean **visual alignment guide lines**. Hold **`Shift`** while dragging to bypass magnetic snapping for pixel micro-adjustments.
  * **Hard Screen-Boundary Clamping & Recovery Failsafe:** Every visual edge stays strictly inside visible screen bounds across drags, mousewheel scaling, `1px` / `Shift+10px` nudges, orientation switches, resolution changes, and `/reload`. Includes **`Reset HUD Positions`** in `ESC -> Options -> AddOns` and **`/ds resethud`** with combat-lockdown deferral protection.
* **9-Step Guided Setup & 2-Tier Conflict Scanner (`/ds setup`, `/ds conflicts`):**
  * **Steps:** `1. Conflicts`, `2. Load`, `3. Prep`, `4. Marker`, `5. Zoom`, `6. FPS`, `7. Group`, `8. Bags`, `9. Chat` plus **Restore Blizzard Defaults** uninstall prep.
  * **Smart Conflict Detection & Auto-Yield:** Detects overlapping addons (including sub-module inspection for `ElvUI`, `Leatrix_Plus`, and `EllesmereUI`, plus `BetterBags`, `Baganator`, `Prat-3.0`, `Chattynator`, `DialogueUI`, `ACP`, `FocusMarker`, `PremadeGroupsFilter`, and more). Automatically yields conflicting hooks softly where appropriate or offers 1-click **Use Dynamic Only** / **Use External Only** actions.
* **Obsidian Theme & Font Studio (`/ds theme`):** 17 customisable accent swatches (`Alert Gold`, `Astral Cobalt`, `Emerald Mint`, `Obsidian Slate`, and all 13 WoW Class Colours) plus custom colour picker, 4 surface palettes (`Midnight Pitch Black`, `Obsidian Dark`, `Slate Steel`, `Smoked Glass`), 21+ curated fonts, **Font Scale** (`95%` / `100%` / `110%`), and persisted bottom-right **Opacity** (`50%`-`100%`), **Scale** (`80%`-`120%`), and **Reload UI** footer dock.
* **Zero-Taint Smart Coexistence (`CompareSemVer`):** Every bundled module uses a semantic version guard (`ShouldYieldToOtherInstall`) so if any standalone `Dynamic*` addon is installed alongside `DynamicSuite`, the newer copy cleanly takes priority with zero duplicate frames or double-loaded events.
* **Retail `12.1.5` Zero-Taint Standard:** Guards secret values via `issecretvalue()` / `canaccessvalue()`, uses native Midnight event APIs cleanly, and respects `InCombatLockdown()` across all secure buttons and frames.

---

## All 8 Integrated Modules

### 1. DynamicLoad (`/dl`) -- Context-Aware Addon Profile Manager
* **5 Zone Profiles (`Outdoor`, `Delves`, `Dungeons`, `Raid`, `PvP`):** Automatically stages zone-tailored addon sets and pops a smart post-loading-screen **Alert Toast** (`RELOAD TO APPLY`, never mid-fight or across seamless Delve chambers).
* **Universal Load Security Rules:** Configure any addon as **`By Zone`**, **`Always`** (`LOCKED`), or persistent **`Never`** (`FROZEN` -- never re-enabled during zone switches).
* **Parent-Child Addon Tree & Telemetry:** Displays grouped sub-addons, `[Suite Core]` protection tags, CPU/Memory telemetry, and account/character profile switching.

### 2. DynamicPrep (`/dprep`, `/dp`) -- Telemetry Top Bar, Raid Buffs & Everyday QoL
* **Zero-`OnUpdate` Telemetry Omni-Bar:** Displays customisable capsules for Primary Stat, ranked Secondary Stats, Spec & Loot Spec, M+ Keystone, Durability, and FPS/Ping, plus Lead/Assist smart visibility for Ready Check (`+ RC`) and Pull Countdown (`> Pull`).
* **Clickable Raid Buffs & Consumables Strip (`X/Y + MISSING`):** Combat-safe clickable reminder icons with Midnight `12.x` in-combat missing class raid buff override (Mark of the Wild, Fortitude, Arcane Intellect, Skyfury, Battle Shout, Blessing of the Bronze) and single-target partner buffs.
* **Midnight Omni Folio & Survival Macros:** 39-spec Wowhead stat priority presets, seasonal Great Vault tracker, modifier-free **`[DynamicHeal]`** sequential macro (`Healthstone -> Healing Potion`), Smart Quest & Gossip automation, cinematic auto-skip, Talking Head suppression, and **Hold `CTRL` to Release Spirit** death protection.

### 3. DynamicMarker (`/dm`, `/fm`) -- Target Marking, World Flares & Smart Macros
* **`[DynamicMark]` (General Macro) & `[DynamicKick]` (Multi-Spec Character Macro):** One-click macro creation and action-bar drag cards. `[DynamicMark]` marks your mouseover or current target with native `~icon` overwrite protection; `[DynamicKick]` automatically swaps interrupt spells across all 13 classes and specialisations out of combat (supporting `Smart Auto-Target`, `Mouseover > Focus > Target`, `Focus > Mouseover > Target`, or `@focus` only).
* **`F4` / `F5` World Flare Cycle:** Press `F4` (customisable) to drop enabled `@cursor` world markers in your preferred sequence, and `F5` to clear all flares (`/cwm all`).
* **On-Screen Icon Bar & World Flare Bar HUDs:** Independent **Always / Group / Off** visibility drivers, **Horizontal / Vertical** layout toggle, scaling (`60%`-`150%`), and ready-check / healer mana drink reminders.
* **Official `FocusMarkerDB` Migration (`/dm import`):** Automatically imports legacy FocusMarker settings and upgrades `[FocusMarker]` / `[FocusMark]` macros to `[DynamicMark]` cleanly.

### 4. DynamicBags (`/dbag`, `/dbags`) -- Zero-Lag Virtual Category Bags & Bank Companion
* **Virtual Category Engine & Presets:** Pre-computes slots in memory (Keystones, Consumables, Gear Sets, BoE/WuE, Reagents, Junk) with `Sort: A-Z`, live search highlight, and item upgrade/tier/binding badges without server-sort lag.
* **Unified `DynamicBank` (Personal, Reagent, Warband & Guild Bank):** Suppresses Blizzard bank frame flashes, preserves unqueried Guild Bank tab snapshots across sessions while reflecting live withdrawals down to `0` items, and displays permission/quota badges with view-only dimming.
* **Drop-Anywhere Stack Splitting, `/dbag merge` & Alt Vault:** 1-click multi-pass stack merger (`/dbag merge`), Quick-Open Pouches queue, cross-character Alt & Warband Inventory Vault with aggregated tooltip counts, plus Auto-Repair, Auto-Sell Grey Junk, Fast Auto-Loot, and auto-fill `DELETE` confirmation.

### 5. DynamicChat (`/dchat`, `/dc`) -- Target Whisper `/ww`, Smoked-Glass Skin & History
* **In-Combat `/ww` & `/qq` Shortcuts:** Type **`/ww `** (instant space-trigger or `/ww <msg>`) to whisper your friendly player target, **`/qq`** to leave party immediately, plus `/rl` (reload) and `/lg` (leave group) fallbacks.
* **Zero-Taint Chat Skin & Left Utility Rail:** Borderless Smoked-Glass styling matching chat text contrast, scrollable tab bar, compact `[P]`/`[R]`/`[G]`/`[I]` channel tags, combat whisper protection, non-sticky whispers, clickable URLs (`/dc copy`), per-channel sound alerts, **GPU Buffer Optimiser** (`250`-line cap), and chat history restore across `/reload`.

### 6. DynamicFPS (`/dfps`) -- Zone Graphics Guard & `SpellQueueWindow` Tuner
* **6 Zero-Reload Zone Graphics Profiles (`Outdoor`, `Cities`, `Delves`, `Dungeons`, `Raid`, `PvP`):** Automatically switches view distance, shadows, ground clutter, and particle/spell density with zero loading screen while keeping boss ground telegraphs (`projectedTextures`) hard-locked ON.
* **Hardware Starter Presets (`Competitive`, `Balanced`, `Low`, `Ultra`) & Minimum Combat FPS Guard:** Maintains crisp combat frame rates automatically and tunes `SpellQueueWindow` adaptively from live World Ping + Haste.

### 7. DynamicGroup (`/dgroup`, `/dg`) -- Premade LFG Filters, Roster Ledger & Auto-Invite
* **In-Place Premade Groups Upgrade & LFG Mini-Bar:** Adds Datacentre Region tags (`OCE`, `US-W`, `US-C`, `US-E`, `LATAM`, `BR`), Leader M+ Score, Bloodlust/Combat-Res utility badges, and 5-slot class/role dots directly inside Blizzard's LFG list.
* **1-Click Sign-Up, Roster Ledger & Automation:** Instant role sign-up (hold Shift/Alt to edit note), live party gear/enchant/consumable audit, Guild/Friend/Whisper keyword Auto-Invite with Queue Protection Shield, and Mythic+ Keystone auto-insert.

### 8. DynamicZoom (`/dz`) -- 39-Yard Camera Unlock & Situational Auto-Zoom
* **Max 39-Yard Camera Distance (`2.6x` factor):** Unlocks the maximum camera overview with reactive scroll-wheel acceleration and smooth ease transitions (`/dz max`).
* **Collision Occlusion Shield & Situational Modes:** Fades intersecting tree canopies and dungeon pillars cleanly instead of snapping the camera forward, plus optional per-zone zoom distances (Combat, Mount/Skyriding, Indoors/Delves) and ActionCam pitch/shoulder framing.

---

## Slash Commands Reference

| Command | Action |
| :--- | :--- |
| `/ds` or `/dynamicsuite` | Open or toggle the unified **DynamicSuite Studio** window |
| `/ds hud` / `/ds edit` / `/ds move` | Toggle unified **HUD Edit Mode** across all movable suite frames |
| `/ds resethud` | Reset all suite HUDs (and DynamicMarker bars) to safe screen-clamped defaults |
| `/ds search <query>` | Jump directly to **Global Smart Search** with `<query>` pre-filled |
| `/ds setup` / `/ds guided` | Open the **9-Step Guided Setup Wizard** |
| `/ds conflicts` | Run the **External Addon Conflict Diagnostic** and print chat summary |
| `/ds theme` / `/ds studio` | Open the **Obsidian Theme & Font Studio** |
| `/ds changelog` | Toggle the full **DynamicSuite Release Notes** viewer |
| `/ds reset` | Reset the DynamicSuite hub window size and position |
| `/ds reload` | Reload the user interface (`ReloadUI()`) |
| `/dl` or `/dynamicload` | Jump to **DynamicLoad** (also supports `auto`, `status`, `lock`, `unlock`, `freeze`, `profile`, `toast`) |
| `/dprep` or `/dp` | Jump to **DynamicPrep** (also `/dp edit`, `/dp buffs`, `/dp qol`, `/dp reset`) |
| `/dm`, `/dynamicmarker`, `/fm`, `/focusmarker` | Jump to **DynamicMarker** (supports `hud`, `resethud`, `lock`, `unlock`, `flares`, `macros`, `mute`, `show`, `hide`, `import`, `reset`) |
| `/dbag` or `/dbags` | Jump to **DynamicBags** (also `bag`, `bank`, `warband`, `guild`, `merge`, `clear`, `vault clear`, `reset`) |
| `/dchat` or `/dc` | Jump to **DynamicChat** (also `history`, `copy`, `reset`; plus chat shortcuts `/ww`, `/qq`, `/rl`, `/lg`) |
| `/dfps` or `/dynamicfps` | Jump to **DynamicFPS** (also `status`, `apply`, `restore`, `reset`) |
| `/dgroup` or `/dg` | Jump to **DynamicGroup** (also `rc`, `pull`, `reset`) |
| `/dz` or `/dynamiczoom` | Jump to **DynamicZoom** (also `max` / `39`, `reset`) |

---

## Official Links & Support

* **Full Suite CurseForge (`DynamicSuite`):** `https://www.curseforge.com/wow/addons/dynamicsuite`
* **Standalone Module (`DynamicMarker`):** `https://www.curseforge.com/wow/addons/dynamicmarker`
* **Buy the Developer a Coffee (Ko-fi):** `https://ko-fi.com/dentee`
* **Direct Contact & Feedback:** `denteedev@gmail.com`
```

---

## Section 2: CurseForge File Changelog Block (`v1.9.7` -- `14/11/2026`)

```markdown
## DynamicSuite & Standalone DynamicMarker v1.9.7 (14/11/2026 -- Retail 12.1.5 / Interface 120105)

### Highlights & Release Changes
* **Official CurseForge Release Pipeline for Full `DynamicSuite` (Project ID `1804382`):** Connected full `DynamicSuite` alongside standalone `DynamicMarker` (Project ID `1331651`) in our automated dual-artifact release workflow, producing clean runtime packages with full `CHANGELOG.md` and `README.md` documentation and zero development or internal clutter.
* **Live CurseForge URLs & Support Modal Parity (`DynamicSuite_UI.lua`, `DynamicMarker.lua`, Docs):** Updated all in-game Support panels (`ESC -> Options -> AddOns` & Support modals) and storefront documentation with the live `https://www.curseforge.com/wow/addons/dynamicsuite` link (replacing all legacy placeholder status labels across both full `DynamicSuite` and standalone `DynamicMarker`).
* **Hardened `ShouldYieldToOtherInstall` Dual-Mode Coexistence (All 8 Modules):** Improved semantic version coexistence across `DynamicBags`, `DynamicChat`, `DynamicFPS`, `DynamicGroup`, `DynamicLoad`, `DynamicMarker`, `DynamicPrep`, and `DynamicZoom` so standalone addons and bundled `DynamicSuite` modules cleanly defer to the newer installed copy regardless of load order.
* **Lockstep `v1.9.7` Version & Storefront Docs Sync:** Synchronised all `.toc` headers (`120105` / `1.9.7`), Lua fallback constants, in-game changelog views, and `CurseForge_DynamicSuite.md` + `CurseForge_DynamicMarker.md` documentation.
```
