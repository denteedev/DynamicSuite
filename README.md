# DynamicSuite -- 8-Module Retail Midnight QoL & Performance Hub

[![Support Me on Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/dentee)

**Version:** `v1.9.5` (`14/11/2026`)  
**Target Client:** World of Warcraft Retail Midnight (`12.1.5`, Interface `120105`)  
**Author:** Dentee-Frostmourne

DynamicSuite is an 8-module World of Warcraft Retail Quality-of-Life and performance suite built around a **Dual-Mode Consolidated Architecture**: every module runs inside the unified `DynamicSuite` hub or as a standalone addon from the exact same source file, with a version-aware duplicate-install guard (`CompareSemVer`) so the newer release automatically takes priority with zero duplicate frames or double-loading.

---

## Included Modules & Slash Commands

* **Suite Hub:** `/ds` or `/dynamicsuite` (opens the unified 8-module DynamicSuite configuration window)

| Module | Slash | Key Features |
| :--- | :--- | :--- |
| **DynamicLoad** | `/dl` | Context-aware 5-zone addon profile manager (`Outdoor`, `Delves`, `Dungeons`, `Raid`, `PvP`), 6-target `[+ HUD]` Edit Mode, 7-Step Guided Setup & Conflict Scanner, Theme & Font Studio |
| **DynamicPrep** | `/dprep` | Top telemetry info bar, clickable Raid Buffs & Consumable HUD (including single-target partner buffs), Midnight Omni Folio, `[DynamicHeal]` survival macro, smart gossip/quest QoL |
| **DynamicMarker** | `/dm`, `/fm` | Raid target icons, `F4`/`F5` `@cursor` world flare cycle, floating Focus & Flare HUD bars, automated `[DynamicMark]` & multi-spec `[DynamicKick]` macros, HUD Edit Mode, `FocusMarkerDB` migration |
| **DynamicZoom** | `/dz` | Max camera distance unlock (`2.6x` / `39 yds`), reactive scroll-wheel acceleration, foliage/pillar occlusion fade, zone zoom profiles, ActionCam pitch & shoulder offset |
| **DynamicFPS** | `/dfps` | Per-zone Blizzard Base Game Quality profiles, hardware tier presets, Minimum Combat FPS guard, adaptive Haste + Ping `SpellQueueWindow` engine, external combat-logger auto-yield |
| **DynamicGroup** | `/dgroup`, `/dgrp` | Live party gear/enchant/consumable ledger, LFG Mini-Bar with Datacentre Region & Party Utility filters, 1-click sign-up, ready check telemetry, Mythic+ keystone auto-insert |
| **DynamicBags** | `/dbag` | Zero-lag virtual category bags & companion Character/Warband/Guild Bank, drop-anywhere stack splitting, multi-pass stack merger, Alt & Warband vault, auto-repair/sell/loot |
| **DynamicChat** | `/dchat`, `/dc` | Zero-taint `/ww` & `/qq` target whisper conversion, borderless Smoked-Glass chat skin, scrollable tab bar, Left Utility Rail, per-channel sound alerts, reload history restore |

---

## Core Suite Features

* **Obsidian Theme & Font Studio:** Switch account-wide Accent Colours (**Royal Amber** `#F5B82E`, **Midnight Cyan** `#38BDF8`, **Crimson Core** `#F87171`, **Obsidian Silver** `#CBD5E1`, or **Player Class Colour**), 4 Surface Palettes (**Obsidian Dark**, **Slate Steel**, **Midnight Pitch Black**, **Smoked Glass**), and **Font Scale** (`95%` / `100%` / `110%`), plus bottom-right footer **Opacity** (`50%`-`100%`), **Scale** (`80%`-`120%`), and **Reload UI** controls.
* **Unified `[+ HUD]` Edit Mode:** Position and scale suite HUDs together with pixel-bordered movers, magnetic centre snapping, alignment grid, mousewheel scaling (`60%`-`150%`), `1px` directional nudges, and combat-lockdown / `ESC` zero-taint failsafes.
* **7-Step Guided Setup & Conflict Scanner:** Detects overlapping external addons (such as legacy `FocusMarker`, `TargetCharms`, or conflicting chat/bag/camera addons) and resolves conflicts cleanly in one click.
* **Zero-Taint Midnight `12.1.5` Architecture:** Guards secret values (`issecretvalue()` / `canaccessvalue()`), avoids tainted chat hooks on secret channels, and respects combat lockdown across all secure frames and macros.

---

## DynamicMarker Slash Commands (`/dm`, `/dynamicmarker`, `/fm`, `/focusmarker`)

| Command | Action |
| :--- | :--- |
| `/dm` (or `/dm config`, `/dm ui`, `/dm options`) | Jump to DynamicMarker inside DynamicSuite (or open standalone window) |
| `/dm lock` | Toggle icon & flare bar lock state (HUD Edit Mode) |
| `/dm unlock` | Unlock HUD Edit Mode movers |
| `/dm hud` / `/dm edit` / `/dm move` / `/dm movers` | Toggle HUD Edit Mode (movers, alignment grid & precision inspector) |
| `/dm show` | Set the On-Screen Focus Bar HUD to **Always Shown** |
| `/dm hide` | Hide the On-Screen Focus Bar HUD (**Off**) |
| `/dm mute` / `/dm silent` | Toggle Focus Mark chat announcements On / Muted |
| `/dm flare` / `/dm flares` | Open directly to the **World Flare Keys (F4 / F5)** tab |
| `/dm macro` / `/dm macros` | Open directly to the **Macro Setup** (`[DynamicMark]` & `[DynamicKick]`) tab |
| `/dm import` / `/dm migrate` | Re-import settings from `FocusMarkerDB` (out of combat) |
| `/dm import status` | Print current `FocusMarkerDB` migration/snapshot status in chat |
| `/dm reset` | Reset DynamicMarker defaults, HUD positions, icon size, marking mode, and mute state |
| `/dm help` / `/dm ?` | Print all available DynamicMarker commands in chat |

---

## Official Links & Support

* **Full Addon Suite (DynamicSuite - Coming Soon):** `https://www.curseforge.com/wow/addons/dynamicsuite`
* **Standalone DynamicMarker (CurseForge):** `https://www.curseforge.com/wow/addons/dynamicmarker`
* **Buy the Developer a Coffee (Ko-fi):** `https://ko-fi.com/dentee`
* **Direct Contact & Feedback (Email):** `denteedev@gmail.com`

---

## License & Changelog

See [CHANGELOG.md](CHANGELOG.md) for the complete release history across all 8 modules.
