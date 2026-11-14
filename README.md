# DynamicSuite

**Version:** `v1.9.5` (14/11/2026)  
**Target Client:** World of Warcraft Retail Midnight (`12.1.5`, Interface `120105`)  
**Author:** Dentee-Frostmourne

DynamicSuite is an 8-module World of Warcraft Retail Quality-of-Life and performance suite built around a **Dual-Mode Consolidated Architecture**: every module runs inside the full `DynamicSuite` hub or as a standalone addon from the exact same source file, with a version-aware duplicate-install guard (`CompareSemVer`) so the newer release automatically takes priority.

---

## Included Modules & Slash Commands

* **Suite Hub:** `/ds` (opens the unified 8-module DynamicSuite configuration window)

| Module | Slash | Key Features |
| :--- | :--- | :--- |
| **DynamicLoad** | `/dl` | Context-aware 5-zone addon profile manager (`Outdoor`, `Delves`, `Dungeons`, `Raid`, `PvP`), 6-target `[+ HUD]` Edit Mode, Guided Setup & Conflict Scanner, Theme & Font Studio |
| **DynamicMarker** | `/dm` | Radial target & world marker wheel, priority M+ auto-marking, live interrupt cooldown bar, `[DynamicMark]` & multi-spec `[DynamicKick]` macros, FocusMarker bridge |
| **DynamicZoom** | `/dz` | Max camera distance unlock (`2.6x` / `39 yds`), reactive scroll-wheel acceleration, foliage/pillar occlusion fade, zone zoom profiles, ActionCam pitch & shoulder offset |
| **DynamicFPS** | `/dfps` | Per-zone Blizzard Base Game Quality profiles, hardware tier presets, Minimum Combat FPS guard, adaptive Haste + Ping `SpellQueueWindow` engine, external combat-logger auto-yield |
| **DynamicPrep** | `/dprep` | Top telemetry info bar, clickable Raid Buffs & Consumable HUD (including single-target partner buffs), Midnight Omni Folio, `[DynamicHeal]` survival macro, smart gossip/quest QoL |
| **DynamicGroup** | `/dgrp`, `/dgroup` | Live party gear/enchant/consumable ledger, LFG Mini-Bar with Datacenter Region & Party Utility filters, 1-click sign-up, ready check telemetry, Mythic+ keystone auto-insert |
| **DynamicBags** | `/dbag` | Zero-lag virtual category bags & companion Character/Warband/Guild Bank, drop-anywhere stack splitting, multi-pass stack merger, Alt & Warband vault, auto-repair/sell/loot |
| **DynamicChat** | `/dchat`, `/dc` | Zero-taint `/ww` & `/qq` target whisper conversion, borderless Smoked-Glass chat skin, scrollable tab bar, Left Utility Rail, per-channel sound alerts, reload history restore |

---

## Official Links & Support

* **Full Addon Suite (DynamicSuite - Coming Soon):** `https://www.curseforge.com/wow/addons/dynamicsuite`
* **Standalone DynamicMarker (CurseForge):** `https://www.curseforge.com/wow/addons/dynamicmarker`
* **Buy the Developer a Coffee (Ko-fi):** `https://ko-fi.com/dentee`
* **Direct Contact & Feedback (Email):** `denteedev@gmail.com`

---

## License & Changelog

See [CHANGELOG.md](CHANGELOG.md) for the complete release history across all 8 modules.
