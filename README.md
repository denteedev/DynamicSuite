# DynamicSuite -- 8-Module Retail Midnight QoL, Utility & Performance Hub

[![Support Me on Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/dentee)

**Version:** `v1.9.9` (`14/11/2026`) | **Target Client:** World of Warcraft Retail Midnight `12.1.5` (Interface `120105`) | **Author:** Dentee-Frostmourne

**DynamicSuite** (`/ds`, `/dynamicsuite`) is a lightweight, zero-taint 8-module World of Warcraft Retail Quality-of-Life, Mythic+/Raid utility, inventory, chat, and performance hub built around a **Single-Entry Consolidated Dual-Mode Architecture**. Every feature module runs seamlessly inside the unified **`DynamicSuite`** Obsidian Studio window (`https://www.curseforge.com/wow/addons/dynamicsuite`) or as a standalone addon from the exact same source file (including standalone **[DynamicMarker on CurseForge](https://www.curseforge.com/wow/addons/dynamicmarker)**).

---

## Smart Coexistence (`DynamicSuite` <-> Standalone `DynamicMarker` & Peer Modules)

* **Unconditional Internal Guard:** Internal Suite <-> standalone coexistence runs **unconditionally** at addon load and login regardless of any third-party addon conflict resolution settings.
* **Automatic Standalone Exclusion:** Whenever `DynamicSuite` is enabled, `EnforceStandaloneDynamicMarkerExclusion` actively disables standalone `DynamicMarker` via `C_AddOns.DisableAddOn("DynamicMarker")` (and prompts a reload if standalone `DynamicMarker` was already loaded in the current session) so bundled `DynamicMarker` inside `DynamicSuite` owns all target marking, world flares, macros, and HUD bars.
* **Immediate Pre-Reload Entry Guard:** Standalone `DynamicMarker` (`## OptionalDeps: DynamicSuite`) runs an immediate top-of-file and `ADDON_LOADED` early-exit check whenever `C_AddOns.IsAddOnLoaded("DynamicSuite")` or `C_AddOns.GetAddOnEnableState("DynamicSuite")` is true, preventing double-initialisation, slash command hijacking, SavedVariables collisions, or duplicate HUD Edit Mode windows even before `/reload`.
* **Dual-Mode Version Priority (`CompareSemVer`):** All 8 feature modules (`DynamicLoad`, `DynamicPrep`, `DynamicMarker`, `DynamicZoom`, `DynamicFPS`, `DynamicGroup`, `DynamicBags`, `DynamicChat`) include `ShouldYieldToOtherInstall` semantic version checks so standalone installs cleanly defer without duplicate frames or double-loaded events.

---

## Core Suite Features

* **Unified Studio Hub (`/ds`):** Clean resizable Obsidian window with a persistent 3-zone header, 8-module Left Suite Rail (`[On]`/`[Off]` toggles and reorderable cards), bottom-right **Opacity** (`50%`-`100%`), **Scale** (`80%`-`120%`), and **Reload UI** footer dock, plus **Game Menu** and `ESC -> Options -> AddOns` launcher buttons.
* **Global Smart Search (`/ds search <query>`):** Instant fuzzy search across **202 indexed settings** with 6 live-counted category pills and 1-click Jump-and-Highlight navigation.
* **Unified `[+ HUD]` Edit Mode (`/ds hud`, `/ds resethud`):** Scale-aware `1:1` dragging across `6` HUD targets (`Alert Toast`, `Prep Bar`, `Raid Buffs`, `Focus Icons`, `World Flares`, `Chat Frame`) from `60%`-`150%` scale, magnetic screen-edge/centre (`11px`) and bar-to-bar (`9px`) snapping with live visual guide lines, dynamic `UIParent` screen-edge clamping & reset bounds, `1px` / `Shift+10px` nudges, and `Reset HUD Positions` in `ESC -> Options -> AddOns`.
* **9-Step Guided Setup & 2-Tier Conflict Scanner (`/ds setup`, `/ds conflicts`):** Detects overlapping external addons (including sub-module checks for `ElvUI`, `Leatrix_Plus`, and `EllesmereUI`) and resolves conflicts cleanly with 1-click switching or persistent `Never` (`FROZEN`) rules.
* **Obsidian Theme & Font Studio (`/ds theme`):** Switch account-wide Accent Colours (**Alert Gold**, **Astral Cobalt**, **Emerald Mint**, **Obsidian Slate**, custom picker, or all **13 Class Colours**), 4 Surface Palettes (**Midnight Pitch Black**, **Obsidian Dark**, **Slate Steel**, **Smoked Glass**), 21+ curated fonts, and **Font Scale** (`95%` / `100%` / `110%`).
* **Zero-Taint Midnight `12.1.5` Architecture:** Guards secret values via `issecretvalue()` / `canaccessvalue()`, avoids tainted hooks on secret channels, and respects `InCombatLockdown()` across all secure frames and macros.

---

## Included Modules

| Module | Slash | Key Features |
| :--- | :--- | :--- |
| **DynamicLoad** | `/dl` | Context-aware 5-zone addon profile manager (`Outdoor`, `Delves`, `Dungeons`, `Raid`, `PvP`), `Alert Toast`, universal `By Zone` / `Always` / `Never` (`FROZEN`) load rules, Theme & Font Studio |
| **DynamicPrep** | `/dprep`, `/dp` | Zero-`OnUpdate` top telemetry bar, clickable Raid Buffs & Consumables HUD (including single-target partner buffs), Midnight Omni Folio, `[DynamicHeal]` survival macro, smart quest/gossip QoL |
| **DynamicMarker** | `/dm`, `/fm` | Raid target icons, `F4`/`F5` `@cursor` world flare cycle, floating Focus & Flare HUD bars, automated `[DynamicMark]` & multi-spec `[DynamicKick]` macros, `FocusMarkerDB` migration |
| **DynamicZoom** | `/dz` | Max camera distance unlock (`2.6x` / `39 yds`), reactive scroll-wheel acceleration, foliage/pillar occlusion fade, zone zoom profiles, ActionCam pitch & shoulder offset |
| **DynamicFPS** | `/dfps` | Per-zone Blizzard Base Game Quality profiles, hardware starter presets, Minimum Combat FPS guard, adaptive Haste + Ping `SpellQueueWindow` engine, external combat-logger auto-yield |
| **DynamicGroup** | `/dgroup`, `/dg` | Live party gear/enchant/consumable ledger, LFG Mini-Bar with Datacentre Region & Party Utility filters, 1-click sign-up, ready check telemetry, Mythic+ keystone auto-insert |
| **DynamicBags** | `/dbag` | Zero-lag virtual category bags & companion Character/Warband/Guild Bank, drop-anywhere stack splitting, `/dbag merge`, Alt & Warband vault, auto-repair/sell/loot |
| **DynamicChat** | `/dchat`, `/dc` | Zero-taint `/ww` & `/qq` target whisper conversion, borderless Smoked-Glass chat skin, scrollable tab bar, Left Utility Rail, per-channel sound alerts, reload history restore |

---

## Slash Commands Reference

| Command | Action |
| :--- | :--- |
| `/ds` or `/dynamicsuite` | Open or toggle the unified **DynamicSuite Studio** window |
| `/ds hud` / `/ds edit` / `/ds move` | Toggle unified **HUD Edit Mode** across all movable suite frames |
| `/ds resethud` | Reset all suite HUDs (including Focus Icons & World Flares) to dynamic screen-clamped defaults |
| `/ds search <query>` | Jump directly to **Global Smart Search** with `<query>` pre-filled |
| `/ds setup` / `/ds guided` | Open the **9-Step Guided Setup Wizard** |
| `/ds conflicts` | Run the **External Addon Conflict Diagnostic** and print chat summary |
| `/ds theme` / `/ds studio` | Open the **Obsidian Theme & Font Studio** |
| `/ds changelog` | Toggle the full **DynamicSuite Release Notes** viewer |
| `/ds reset` | Reset the DynamicSuite hub window size and position |
| `/ds reload` | Reload the user interface (`ReloadUI()`) |
| `/dl` or `/dynamicload` | Jump to **DynamicLoad** (`auto`, `status`, `lock`, `unlock`, `freeze`, `profile`, `toast`) |
| `/dprep` or `/dp` | Jump to **DynamicPrep** (`edit`, `buffs`, `qol`, `reset`) |
| `/dm`, `/dynamicmarker`, `/fm`, `/focusmarker` | Jump to **DynamicMarker** (`hud`, `resethud`, `lock`, `unlock`, `flares`, `macros`, `mute`, `show`, `hide`, `import`, `reset`) |
| `/dz` or `/dynamiczoom` | Jump to **DynamicZoom** (`max` / `39`, `reset`) |
| `/dfps` or `/dynamicfps` | Jump to **DynamicFPS** (`status`, `apply`, `restore`, `reset`) |
| `/dgroup` or `/dg` | Jump to **DynamicGroup** (`rc`, `pull`, `reset`) |
| `/dbag` or `/dbags` | Jump to **DynamicBags** (`bag`, `bank`, `warband`, `guild`, `merge`, `clear`, `vault clear`, `reset`) |
| `/dchat` or `/dc` | Jump to **DynamicChat** (`history`, `copy`, `reset`; plus `/ww`, `/qq`, `/rl`, `/lg`) |

---

## Support & Contact

* **Buy the Developer a Coffee (Ko-fi):** `https://ko-fi.com/dentee`
* **Full Suite CurseForge (`DynamicSuite`):** `https://www.curseforge.com/wow/addons/dynamicsuite`
* **Standalone CurseForge (`DynamicMarker`):** `https://www.curseforge.com/wow/addons/dynamicmarker`
* **Direct Contact & Feedback (Email):** `denteedev@gmail.com`

---

## License & Changelog

See [CHANGELOG.md](CHANGELOG.md) for the complete release history across all 8 modules.
