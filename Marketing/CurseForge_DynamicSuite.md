# DynamicSuite -- CurseForge Storefront Copy

> **Target Game Version:** World of Warcraft Retail Midnight 12.1.5 (Interface 120105)  
> **CurseForge Project ID:** 1804382  
> **Author:** Dentee-Frostmourne  
> **CurseForge Project Page:** https://www.curseforge.com/wow/addons/dynamicsuite

---

## CurseForge Project Description (Copy & Paste Markdown)

```markdown
# DynamicSuite -- 9-Module QoL, Utility & Performance Hub

**Target Client:** World of Warcraft Retail Midnight 12.1.5 (Interface 120105) | **Author:** Dentee-Frostmourne

**DynamicSuite** (`/ds`, `/dynamicsuite`) is a lightweight all-in-one Quality-of-Life, Mythic+, Raid, inventory, mailbox, chat, and performance hub for **World of Warcraft Retail Midnight 12.1.5**. It brings **9 integrated modules** together inside one clean dark-obsidian control panel (`/ds`) with shared themes, plain-English Smart Search, a unified HUD Edit Mode, and a 10-step Guided Setup.

Only want target marking, world flares, and smart interrupt macros? Check out standalone **[DynamicMarker on CurseForge](https://www.curseforge.com/wow/addons/dynamicmarker)**.

---

## Core Suite Features

* **Unified Control Panel (`/ds`):** Resizable dark-obsidian window with a 9-module sidebar, individual On/Off switches, reorderable module cards, Game Menu shortcuts, and bottom-right Window Opacity (50%-100%), Scale (80%-120%), and Reload UI controls.
* **Global Smart Search (`/ds search <query>`):** Search any setting in plain English (like "auto repair", "flare", "mail", or "whisper") and jump straight to the exact option with a visual highlight.
* **Unified HUD Edit Mode (`/ds hud`, `/ds resethud`):** Drag, scale (60%-150%), and align all 6 movable suite bars (Alert Toast, Prep Bar, Raid Buffs, Focus Icons, World Flares, and Chat Frame) with magnetic screen-edge and bar-to-bar snapping, live alignment guides, and one-click reset recovery.
* **10-Step Guided Setup & Conflict Scanner (`/ds setup`, `/ds conflicts`):** Detects overlapping addons (such as ElvUI, Leatrix Plus, BetterBags, Baganator, Postal, Prat-3.0, DialogueUI, FocusMarker, and slash-command taint risks like DecorVendor) and lets you pick which addon handles each feature -- or route DecorVendor to Outdoor Housing only -- in one click.
* **Suite Studio -- Theme, Typography & Blizzard Desktop Window Manager (`/ds studio`, `/ds theme`, `/ds windows`):** Customise your UI in Tab 1 (`Theme & Typography`) with 17 accent colours (including all 13 WoW Class Colours and a custom picker), 4 dark surface themes, 21+ built-in fonts, automatic font discovery from LibSharedMedia-3.0, DBM, EXBOSS, BigWigs, WeakAuras, and ElvUI with searchable grouped dropdowns, and adjustable text scaling. In Tab 2 (`Desktop Windows & Menus`, `/ds windows`), keep 32 Blizzard panels (including Character, Talents & Spellbook, Professions, Collections, and the windowed Quest Log `L`) open side-by-side, drag any Blizzard window from its title bar or empty background space (clamped cleanly on-screen and saved across reloads), click any window to bring it to the front, scale panels with `Ctrl+Scroll` / `Ctrl+Shift+Scroll`, and access quick Game Menu shortcuts.
* **Automatic Standalone Coexistence:** If standalone DynamicMarker is also installed, DynamicSuite disables the standalone copy automatically and prompts a clean UI reload so you never get duplicate bars or conflicting HUD Edit windows.

---

## All 9 Integrated Modules

### 1. DynamicLoad (`/dl`) -- Zone Addon Profile Manager
* **5 Zone Profiles:** Automatically prepares tailored addon sets for Outdoor, Delves, Dungeons, Raid, and PvP, with a clean reload prompt after loading screens (never mid-fight).
* **Load Lock Rules:** Pin any addon to By Zone, Always, or Never so zone switches never turn off essentials or re-enable addons you froze.

### 2. DynamicPrep (`/dprep`, `/dp`) -- Telemetry Bar, Raid Buffs & QoL
* **Top Info Bar:** Customisable bar showing Primary Stat, Secondary Stats, Spec & Loot Spec, M+ Keystone, Durability, FPS/Ping, plus Ready Check and Pull Countdown buttons for leaders.
* **Clickable Raid Buffs, Gear Audit & World/Survival QoL:** One-click reminders for missing class raid buffs, single-target partner buffs, and consumables with colour-coded food stat benefits on the Raid Buffs HUD, paperdoll missing-enchant and empty-socket highlights, a smart `[DynamicHeal]` macro (Healthstone into Healing Potion), quest/gossip & One-Click Catalyst automation, seen-cinematic auto-skip, and Hold CTRL to Release Spirit protection.

### 3. DynamicMarker (`/dm`, `/fm`) -- Target Marking, World Flares & Macros
* **Smart Macros:** One-click `[DynamicMark]` focus/raid marker macro and `[DynamicKick]` interrupt macro that automatically updates your interrupt spell when you swap specs across all 13 classes.
* **World Flares & Floating HUD Bars:** Optionally bind keys (Unbound by default; click to bind, Right-click to unbind in Guided Setup and `/dm flares`) to cycle ground flares at your cursor and clear all flares, with customisable horizontal or vertical Focus Icon and World Flare bars and automatic FocusMarker settings import (`/dm import`).

### 4. DynamicBags (`/dbag`, `/dbags`) -- Category Bags & Bank Viewer
* **Fast Category Bags:** Sorts your items into clean categories (Keystones, Consumables, Gear Sets, BoE/WuE, Reagents, Junk) with A-Z sorting, live search, and upgrade/binding badges without server-sort lag.
* **Unified Bank, Scaling & Alt Vault:** View your Personal, Reagent, Warband, and Guild Bank in one window, scale Bags and Unified Bank smoothly (70%-140%) with header `Ctrl+Scroll`, track items across all your alts, split/merge stacks (`/dbag merge`), and automate repairs, grey junk selling, and fast looting.

### 5. DynamicChat (`/dchat`, `/dc`, `/dynamicchat`) -- Whispers, Chat Skin & History
* **Quick Chat Shortcuts:** Type `/ww` to whisper your friendly target (even in combat), `/rl` to reload your UI, and `/lg` to leave your party or raid quickly.
* **Clean Smoked-Glass Chat, Typography & Alert Sounds:** Borderless chat frame with an embedded EditBox dock, customisable chat font family/size/outline/line-spacing, compact channel tags, clickable URLs (`/dc copy`), 10 built-in DynamicSuite chimes + 7 Blizzard alert sounds, custom `.ogg`/`.mp3` sound registration, character name & keyword mention alerts, external SharedMedia/DBM/EXBOSS/BigWigs/WeakAuras/ElvUI sound pack support, `/dc mute`, and chat history saved across UI reloads.

### 6. DynamicFPS (`/dfps`) -- Zone Graphics & Responsiveness
* **Zero-Reload Zone Graphics:** Automatically adjusts view distance, shadows, clutter, and spell density between Cities, Outdoor, Delves, Dungeons, Raid, and PvP while keeping boss floor mechanics clearly visible.
* **Combat FPS Guard & Spell Queue:** Protects your frame rate during heavy combat and tunes SpellQueueWindow automatically from your live ping and haste.

### 7. DynamicGroup (`/dgroup`, `/dg`) -- Premade Groups, Portal Deck & Roster Audit
* **Upgraded Premade Group Finder & Multi-Toggle Filters:** Shows Datacentre Region tags (OCE, US-W, US-C, US-E, LATAM, BR), Leader M+ Score, Bloodlust/Combat-Res badges, and 5-slot class/role dots, plus Tank/Healer/DPS, No Duplicate Class, Has Tank, Has Healer, Bloodlust, and Battle Rez filter toggles synced with Blizzard's native filter.
* **Midnight Season 2 Portal Deck & Teleport Toasts:** Docked portal bar above Premade Groups with your Owned Keystone pill (Season Best telemetry + out-of-combat Right-Click teleport) and all 8 Midnight Season 2 dungeon tiles for 1-click filtering and Right-Click teleporting, plus a Dungeon Joined & Group Full Teleport Toast (`/dg testtoast`).
* **1-Click Sign-Up & Party Tools:** Sign up in one click, inspect party gear/enchants/consumables at a glance, auto-invite friends/guildies by whisper keyword, and auto-insert Mythic+ keystones.

### 8. DynamicZoom (`/dz`) -- 39-Yard Camera & Smooth Zoom
* **Max Camera Distance:** Unlocks full 39-yard camera zoom (`/dz max`) with smooth scroll-wheel acceleration.
* **Smart Occlusion & Auto-Zoom:** Fades blocking trees and dungeon pillars instead of snapping your camera forward, with optional zoom presets for combat, mounting, and indoors.

### 9. DynamicMail (`/dmail`, `/dynamicmail`) -- Smart Inbox, Alt Picker & Express Attach
* **1-Click Inbox Collection:** Adds clean Obsidian **Open All**, **AH Gold**, and **Items Only** buttons below the Mailbox window with automatic COD protection, configurable free bag-slot reserves (`0-8`), Auction House gold collection when bags are full, and Coin batch summaries.
* **Alt Vault Recipient Picker & Express Bag Attach:** Docks a 4-tab recipient panel (`Alts`, `Recent`, `Guild`, `Friends`) beside Send Mail that syncs class-coloured alts and gold balances straight from `DynamicBags` Alt Vault with `*` Favourite pinning and `Alt + Left-Click` item attaching from your bags.

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/ds` or `/dynamicsuite` | Open or close the DynamicSuite window |
| `/ds hud`, `/ds edit`, `/ds move` | Toggle HUD Edit Mode across all movable suite bars |
| `/ds resethud` | Reset all suite HUD bars to safe screen-clamped default positions |
| `/ds search <query>` | Open Global Smart Search with your query pre-filled |
| `/ds setup` or `/ds guided` | Open the 10-Step Guided Setup Wizard |
| `/ds conflicts` | Check for conflicting addons and print a summary in chat |
| `/ds studio` or `/ds theme` | Open Suite Studio (`Theme & Typography` and `Desktop Windows & Menus`) |
| `/ds windows` or `/ds win` | Open Suite Studio directly to the Blizzard Desktop Window Manager |
| `/ds changelog` | View the DynamicSuite release notes |
| `/ds reset` | Reset the DynamicSuite window size and position |
| `/ds reload` | Reload your user interface |
| `/dl` or `/dynamicload` | Open DynamicLoad (supports auto, status, lock, unlock, freeze, profile, toast) |
| `/dprep` or `/dp` | Open DynamicPrep (supports edit, buffs, qol, testaudit, reset) |
| `/dm`, `/dynamicmarker`, `/fm`, `/focusmarker` | Open DynamicMarker (supports hud, resethud, lock, unlock, flares, macros, mute, show, hide, import, reset) |
| `/dbag` or `/dbags` | Open DynamicBags (supports bag, bank, warband, guild, merge, clear, vault clear, reset) |
| `/dmail` or `/dynamicmail` | Open DynamicMail (supports all, gold, items, stop, reset) |
| `/dchat`, `/dc`, or `/dynamicchat` | Open DynamicChat (supports history, copy, mute, reset; plus `/ww` target whisper, `/rl` reload UI, and `/lg` leave group) |
| `/dfps` or `/dynamicfps` | Open DynamicFPS (supports status, apply, restore, reset) |
| `/dgroup` or `/dg` | Open DynamicGroup (supports rc, pull, testtoast, testapply, reset) |
| `/dz` or `/dynamiczoom` | Open DynamicZoom (supports max, 39, reset) |

---

## Support & Contact

* **Full Suite CurseForge (DynamicSuite):** https://www.curseforge.com/wow/addons/dynamicsuite
* **Standalone CurseForge (DynamicMarker):** https://www.curseforge.com/wow/addons/dynamicmarker
* **Direct Contact & Feedback (Email):** denteedev@gmail.com
* **Optional Tip Jar (Ko-fi -- all features are 100% free):** https://ko-fi.com/dentee

[![Support Me on Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/dentee)
```
