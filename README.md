# DynamicSuite -- 11-Module QoL, Utility & Performance Hub

**Version:** v2.6.0 (20/11/2026) | **Target Client:** World of Warcraft Retail Midnight 12.1.5 (Interface 120105) | **Author:** Dentee-Frostmourne

**DynamicSuite** (`/ds`, `/dynamicsuite`) is a lightweight all-in-one Quality-of-Life, Mythic+, Raid, inventory, mailbox, Great Vault, quest dialogue, chat, and performance hub for World of Warcraft Retail. All 11 modules run inside one unified control panel on https://www.curseforge.com/wow/addons/dynamicsuite, or you can grab target marking on its own with standalone **[DynamicMarker on CurseForge](https://www.curseforge.com/wow/addons/dynamicmarker)**.

---

## Smart Coexistence

* **Automatic Standalone Handoff:** If you have both **DynamicSuite** and standalone **DynamicMarker** installed, DynamicSuite automatically disables the standalone copy and shows a clean reload prompt so you never get duplicate bars, overlapping commands, or conflicting settings.
* **Instant Load Protection:** Even before you reload your UI, standalone DynamicMarker steps aside whenever DynamicSuite is active so you never see duplicate HUD Edit Mode windows.
* **Third-Party Conflict Scanner:** Built-in detection checks for overlapping bag, chat, quest, and camera addons (such as ElvUI, Leatrix Plus, BetterBags, Baganator, Prat-3.0, and DialogueUI) and lets you choose which addon handles each feature in one click.

---

## Core Suite Features

* **Unified Control Panel (`/ds`):** Resizable dark-obsidian window with a 10-module sidebar, individual On/Off switches, reorderable module cards, Window Opacity (50%-100%), Window Scale (80%-120%), and a quick Reload UI button.
* **Global Smart Search (`/ds search <query>`):** Type what you are looking for in plain English (like "auto repair", "flare", "mail", or "whisper") and jump straight to the exact setting with a visual highlight.
* **Unified HUD Edit Mode (`/ds hud`, `/ds resethud`):** Drag, resize (60%-150%), and align all 6 suite HUD bars (Alert Toast, Prep Bar, Raid Buffs, Focus Icons, World Flares, and Chat Frame) with magnetic screen-edge and bar-to-bar snapping, live alignment guides, and one-click reset recovery.
* **10-Step Guided Setup (`/ds setup`, `/ds conflicts`):** Walks you through resolving addon conflicts and configuring each module in minutes.
* **Theme & Font Studio (`/ds theme`):** Customise your UI with 17 accent colours (including all 13 WoW Class Colours and a custom colour picker), 4 dark surface themes, 21+ built-in fonts, automatic font discovery from LibSharedMedia-3.0, DBM, EXBOSS, BigWigs, WeakAuras, and ElvUI with searchable grouped dropdowns, and adjustable text scaling.

---

## Included Modules

| Module | Slash | What It Does |
| :--- | :--- | :--- |
| **DynamicLoad** | `/dl` | Automatically switches addon profiles for Outdoor, Delves, Dungeons, Raid, and PvP with Always and Never load locks |
| **DynamicPrep** | `/dprep`, `/dp` | Top stat/durability/FPS bar, clickable Raid Buff & Consumable reminders, survival healing macro, quest/gossip QoL, and side-by-side draggable/scalable Blizzard windows |
| **DynamicMarker** | `/dm`, `/fm` | Instant focus & raid target marking, optional world flare cycling & clear hotkeys (unbound by default), floating Focus & Flare bars, and smart interrupt macro |
| **DynamicZoom** | `/dz` | Unlocks 39-yard max camera zoom, speeds up scroll zooming, and fades trees/pillars instead of snapping your camera |
| **DynamicFPS** | `/dfps` | Switches graphics settings automatically per zone, protects combat FPS, and tunes SpellQueueWindow from live ping + haste |
| **DynamicGroup** | `/dgroup`, `/dg` | Adds region tags, M+ scores, and Lust/B-Res icons to Premade Groups, 1-click sign-up, party audit, and auto-keystone |
| **DynamicBags** | `/dbag` | Fast category-sorted bags, unified Personal/Warband/Guild Bank viewer with header `Ctrl+Scroll` scaling (70%-140%), Alt Inventory Vault, auto-repair, and auto-sell junk |
| **DynamicMail** | `/dmail`, `/dynamicmail` | 1-click Inbox Open All, AH Gold, and Items Only collection with bag-reserve safety, class-coloured Alt Vault recipient picker, and `Alt+Left-Click` bag attach |
| **DynamicChat** | `/dchat`, `/dc`, `/dynamicchat` | Smoked-glass chat frame, `/ww` target whispers, `/rl` reload, `/lg` group leave, 7 built-in & external sound pack alerts with preview buttons, whisper chimes, clickable URLs, and reload history |
| **DynamicVault** | `/dv`, `/dynamicvault` | Account-wide Great Vault matrix (Raid, Mythic+, Delves), Restored Coffer Keys, Catalyst, seasonal Crests, owned Keystones, Weekly Reset countdown, and auto-resetting Weekly Checklists |

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
| `/ds theme` or `/ds studio` | Open the Theme & Font Studio |
| `/ds changelog` | View the DynamicSuite release notes |
| `/ds reset` | Reset the DynamicSuite window size and position |
| `/ds reload` | Reload your user interface |
| `/dl` or `/dynamicload` | Open DynamicLoad (supports auto, status, lock, unlock, freeze, profile, toast) |
| `/dprep` or `/dp` | Open DynamicPrep (supports edit, buffs, qol, reset) |
| `/dm`, `/dynamicmarker`, `/fm`, `/focusmarker` | Open DynamicMarker (supports hud, resethud, lock, unlock, flares, macros, mute, show, hide, import, reset) |
| `/dz` or `/dynamiczoom` | Open DynamicZoom (supports max, 39, reset) |
| `/dfps` or `/dynamicfps` | Open DynamicFPS (supports status, apply, restore, reset) |
| `/dgroup` or `/dg` | Open DynamicGroup (supports rc, pull, testtoast, reset) |
| `/dbag` or `/dbags` | Open DynamicBags (supports bag, bank, warband, guild, merge, clear, vault clear, reset) |
| `/dmail` or `/dynamicmail` | Open DynamicMail (supports all, gold, items, mats, boe, warband, same, stop, reset) |
| `/dv` or `/dynamicvault` | Open DynamicVault (supports open, overlay, scan, reset) |
| `/dd`, `/ddlg`, or `/dynamicdialogue` | Open DynamicDialogue Obsidian Quest & Gossip Reader (supports preview, status, reset) |
| `/dchat`, `/dc`, or `/dynamicchat` | Open DynamicChat (supports history, copy, reset; plus `/ww` target whisper, `/rl` reload UI, and `/lg` leave group) |

---

## Support & Contact

* **Full Suite CurseForge (DynamicSuite):** https://www.curseforge.com/wow/addons/dynamicsuite
* **Standalone CurseForge (DynamicMarker):** https://www.curseforge.com/wow/addons/dynamicmarker
* **Direct Contact & Feedback (Email):** denteedev@gmail.com
* **Optional Tip Jar (Ko-fi -- all features are 100% free):** https://ko-fi.com/dentee

[![Support Me on Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/dentee)

---

## License & Changelog

See [CHANGELOG.md](CHANGELOG.md) for the complete release history across all 11 modules.
