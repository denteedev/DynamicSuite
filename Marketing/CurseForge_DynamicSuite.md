# DynamicSuite -- CurseForge Storefront Copy & Release Changelog (v1.9.9)

> **Target Game Version:** World of Warcraft Retail Midnight 12.1.5 (Interface 120105)  
> **Version:** v1.9.9 (14/11/2026)  
> **CurseForge Project ID:** 1804382  
> **Author:** Dentee-Frostmourne  
> **CurseForge Project Page:** https://www.curseforge.com/wow/addons/dynamicsuite

---

## Section 1: CurseForge Project Description (Copy & Paste Markdown)

```markdown
# DynamicSuite -- 8-Module QoL, Utility & Performance Hub

[![Support Me on Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/dentee)

**Version:** v1.9.9 (14/11/2026) | **Target Client:** World of Warcraft Retail Midnight 12.1.5 (Interface 120105) | **Author:** Dentee-Frostmourne

**DynamicSuite** (`/ds`, `/dynamicsuite`) is a lightweight all-in-one Quality-of-Life, Mythic+, Raid, inventory, chat, and performance hub for **World of Warcraft Retail Midnight 12.1.5**. It brings **8 integrated modules** together inside one clean dark-obsidian control panel (`/ds`) with shared themes, plain-English Smart Search, a unified HUD Edit Mode, and a 9-step Guided Setup.

Only want target marking, world flares, and smart interrupt macros? Check out standalone **[DynamicMarker on CurseForge](https://www.curseforge.com/wow/addons/dynamicmarker)**.

---

## Core Suite Features

* **Unified Control Panel (`/ds`):** Resizable dark-obsidian window with an 8-module sidebar, individual On/Off switches, reorderable module cards, Game Menu shortcuts, and bottom-right Window Opacity (50%-100%), Scale (80%-120%), and Reload UI controls.
* **Global Smart Search (`/ds search <query>`):** Search any setting in plain English (like "auto repair", "flare", or "whisper") and jump straight to the exact option with a visual highlight.
* **Unified HUD Edit Mode (`/ds hud`, `/ds resethud`):** Drag, scale (60%-150%), and align all 6 movable suite bars (Alert Toast, Prep Bar, Raid Buffs, Focus Icons, World Flares, and Chat Frame) with magnetic screen-edge and bar-to-bar snapping, live alignment guides, and one-click reset recovery.
* **9-Step Guided Setup & Conflict Scanner (`/ds setup`, `/ds conflicts`):** Detects overlapping addons (such as ElvUI, Leatrix Plus, BetterBags, Baganator, Prat-3.0, DialogueUI, and FocusMarker) and lets you pick which addon handles each feature in one click.
* **Theme & Font Studio (`/ds theme`):** Customise your UI with 17 accent colours (including all 13 WoW Class Colours and a custom picker), 4 dark surface themes, 21+ fonts, and adjustable text scaling.
* **Automatic Standalone Coexistence:** If standalone DynamicMarker is also installed, DynamicSuite disables the standalone copy automatically and prompts a clean UI reload so you never get duplicate bars or conflicting HUD Edit windows.

---

## All 8 Integrated Modules

### 1. DynamicLoad (`/dl`) -- Zone Addon Profile Manager
* **5 Zone Profiles:** Automatically prepares tailored addon sets for Outdoor, Delves, Dungeons, Raid, and PvP, with a clean reload prompt after loading screens (never mid-fight).
* **Load Lock Rules:** Pin any addon to By Zone, Always, or Never so zone switches never turn off essentials or re-enable addons you froze.

### 2. DynamicPrep (`/dprep`, `/dp`) -- Telemetry Bar, Raid Buffs & QoL
* **Top Info Bar:** Customisable bar showing Primary Stat, Secondary Stats, Spec & Loot Spec, M+ Keystone, Durability, FPS/Ping, plus Ready Check and Pull Countdown buttons for leaders.
* **Clickable Raid Buffs & Survival Macro:** One-click reminders for missing class raid buffs and consumables, plus a smart `[DynamicHeal]` macro (Healthstone into Healing Potion), quest/gossip automation, cinematic auto-skip, and Hold CTRL to Release Spirit protection.

### 3. DynamicMarker (`/dm`, `/fm`) -- Target Marking, World Flares & Macros
* **Smart Macros:** One-click `[DynamicMark]` focus/raid marker macro and `[DynamicKick]` interrupt macro that automatically updates your interrupt spell when you swap specs across all 13 classes.
* **World Flares & Floating HUD Bars:** Press F4 to cycle ground flares at your cursor and F5 to clear all flares, with customisable horizontal or vertical Focus Icon and World Flare bars and automatic FocusMarker settings import (`/dm import`).

### 4. DynamicBags (`/dbag`, `/dbags`) -- Category Bags & Bank Viewer
* **Fast Category Bags:** Sorts your items into clean categories (Keystones, Consumables, Gear Sets, BoE/WuE, Reagents, Junk) with A-Z sorting, live search, and upgrade/binding badges without server-sort lag.
* **Unified Bank & Alt Vault:** View your Personal, Reagent, Warband, and Guild Bank in one window, track items across all your alts, split/merge stacks (`/dbag merge`), and automate repairs, grey junk selling, and fast looting.

### 5. DynamicChat (`/dchat`, `/dc`) -- Whispers, Chat Skin & History
* **Quick Chat Shortcuts:** Type `/ww` to whisper your friendly target (even in combat), `/qq` to leave group fast, `/rl` to reload, and `/lg` to leave group.
* **Clean Smoked-Glass Chat:** Borderless chat frame with compact channel tags, clickable URLs (`/dc copy`), per-channel sound alerts, and chat history saved across UI reloads.

### 6. DynamicFPS (`/dfps`) -- Zone Graphics & Responsiveness
* **Zero-Reload Zone Graphics:** Automatically adjusts view distance, shadows, clutter, and spell density between Cities, Outdoor, Delves, Dungeons, Raid, and PvP while keeping boss floor mechanics clearly visible.
* **Combat FPS Guard & Spell Queue:** Protects your frame rate during heavy combat and tunes SpellQueueWindow automatically from your live ping and haste.

### 7. DynamicGroup (`/dgroup`, `/dg`) -- Premade Groups & Roster Audit
* **Upgraded Premade Group Finder:** Shows Datacentre Region tags (OCE, US-W, US-C, US-E, LATAM, BR), Leader M+ Score, Bloodlust/Combat-Res badges, and 5-slot class/role dots directly in Blizzard's group list.
* **1-Click Sign-Up & Party Tools:** Sign up in one click, inspect party gear/enchants/consumables at a glance, auto-invite friends/guildies by whisper keyword, and auto-insert Mythic+ keystones.

### 8. DynamicZoom (`/dz`) -- 39-Yard Camera & Smooth Zoom
* **Max Camera Distance:** Unlocks full 39-yard camera zoom (`/dz max`) with smooth scroll-wheel acceleration.
* **Smart Occlusion & Auto-Zoom:** Fades blocking trees and dungeon pillars instead of snapping your camera forward, with optional zoom presets for combat, mounting, and indoors.

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/ds` or `/dynamicsuite` | Open or close the DynamicSuite window |
| `/ds hud`, `/ds edit`, `/ds move` | Toggle HUD Edit Mode across all movable suite bars |
| `/ds resethud` | Reset all suite HUD bars to safe screen-clamped default positions |
| `/ds search <query>` | Open Global Smart Search with your query pre-filled |
| `/ds setup` or `/ds guided` | Open the 9-Step Guided Setup Wizard |
| `/ds conflicts` | Check for conflicting addons and print a summary in chat |
| `/ds theme` or `/ds studio` | Open the Theme & Font Studio |
| `/ds changelog` | View the DynamicSuite release notes |
| `/ds reset` | Reset the DynamicSuite window size and position |
| `/ds reload` | Reload your user interface |
| `/dl` or `/dynamicload` | Open DynamicLoad (supports auto, status, lock, unlock, freeze, profile, toast) |
| `/dprep` or `/dp` | Open DynamicPrep (supports edit, buffs, qol, reset) |
| `/dm`, `/dynamicmarker`, `/fm`, `/focusmarker` | Open DynamicMarker (supports hud, resethud, lock, unlock, flares, macros, mute, show, hide, import, reset) |
| `/dbag` or `/dbags` | Open DynamicBags (supports bag, bank, warband, guild, merge, clear, vault clear, reset) |
| `/dchat` or `/dc` | Open DynamicChat (supports history, copy, reset; plus `/ww`, `/qq`, `/rl`, `/lg`) |
| `/dfps` or `/dynamicfps` | Open DynamicFPS (supports status, apply, restore, reset) |
| `/dgroup` or `/dg` | Open DynamicGroup (supports rc, pull, reset) |
| `/dz` or `/dynamiczoom` | Open DynamicZoom (supports max, 39, reset) |

---

## Support & Contact

* **Buy the Developer a Coffee (Ko-fi):** https://ko-fi.com/dentee
* **Full Suite CurseForge (DynamicSuite):** https://www.curseforge.com/wow/addons/dynamicsuite
* **Standalone CurseForge (DynamicMarker):** https://www.curseforge.com/wow/addons/dynamicmarker
* **Direct Contact & Feedback (Email):** denteedev@gmail.com
```

---

## Section 2: CurseForge File Changelog Block (v1.9.9 -- 14/11/2026)

```markdown
## DynamicSuite & Standalone DynamicMarker v1.9.9 (14/11/2026)

### Fixed
* **Top & Bottom Screen-Edge Bar Drift:** Focus Icons and World Flare bars parked flush against the top edge, bottom edge, or corners now stay in their exact saved positions after reloading the UI at every bar scale (70%, 100%, and 130%).
* **DynamicLoad Profile Switching & Standalone Scrubbing:** Fixed a Lua error when staging zone profiles (such as Outdoor) in DynamicLoad and ensured saved zone profiles never re-enable standalone DynamicMarker while DynamicSuite is active.
* **Duplicate HUD Edit Windows:** Standalone DynamicMarker's extra HUD Edit popup no longer appears inside DynamicSuite, leaving only the unified bottom HUD Edit dock.
* **DynamicMarker Reset Bounds:** Resetting HUD positions (`/ds resethud`, `/dm resethud`, or from Options) now resets scale to 100%, restores horizontal layout, and keeps bars cleanly inside your screen bounds.

### Improved
* **Reliable Dark-Obsidian Coexistence Reload Prompt:** Replaced Blizzard's default popup with a matching dark-obsidian reload modal that reliably appears on login whenever both DynamicSuite and standalone DynamicMarker were enabled at launch.
* **Storefront & Readme Clarity:** Updated descriptions, slash command tables, and support links across both DynamicSuite and standalone DynamicMarker.
```
