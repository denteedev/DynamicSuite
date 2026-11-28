# DynamicSuite -- 13-Module QoL, Utility & Performance Hub

**Version:** v2.11.3 (29/11/2026) | **Target Client:** World of Warcraft Retail Midnight 12.1.5 / 12.1.7 (Interface 120105, 120107) | **Author:** Dentee-Frostmourne

**DynamicSuite** (`/ds`, `/dynamicsuite`) is a lightweight all-in-one Quality-of-Life, Mythic+, Raid, talent loadouts, cursor overlays, inventory, mailbox, Great Vault, quest dialogue, chat, and performance hub for World of Warcraft Retail. All 13 modules run inside one unified control panel on https://www.curseforge.com/wow/addons/dynamicsuite, or you can grab target marking on its own with standalone **[DynamicMarker on CurseForge](https://www.curseforge.com/wow/addons/dynamicmarker)**.

---

## Smart Coexistence

* **Automatic Standalone Handoff:** If you have both **DynamicSuite** and standalone **DynamicMarker** installed, DynamicSuite automatically disables the standalone copy and shows a clean reload prompt so you never get duplicate bars, overlapping commands, or conflicting settings.
* **Instant Load Protection:** Even before you reload your UI, standalone DynamicMarker steps aside whenever DynamicSuite is active so you never see duplicate HUD Edit Mode windows.
* **Third-Party Conflict Scanner:** Built-in detection checks for overlapping bag, chat, quest, mail, camera, error-filter, and QoL addons (such as ElvUI, EnhanceQoL, Leatrix Plus, BetterBags, Baganator, Prat-3.0, Postal, ErrorFilter, and DialogueUI) and lets you choose which addon handles each feature in one click.

---

## Core Suite Features

* **Unified Control Panel (`/ds`):** Resizable dark-obsidian window with a 13-module sidebar, individual On/Off switches, reorderable module cards, Window Opacity (50%-100%), Window Scale (80%-120%), and a quick Reload UI button.
* **Shared Alert Toast HUD:** Centralised Toast Scale, Opacity, Border Style, two-tier Auto-Fade Durations (Actionable & Info/Mention), and Alert Sound inside Suite Studio, DynamicLoad, and HUD Edit Mode, shared cleanly across Zone Load Alerts, DynamicPrep Reminders, DynamicTalent Swaps, DynamicGroup Teleport Toasts, and DynamicChat Mention Alerts with universal hover-to-pause, clean vertical stacking, and Right-Click dismissal.
* **Global Smart Search (`/ds search <query>`):** Type what you are looking for in plain English (like "auto repair", "flare", "mail", "quest", or "whisper") and jump straight to the exact setting with a visual highlight.
* **Unified HUD Edit Mode, Direct 6-HUD Shift-Drag & Pet Battle Auto-Hide (`/ds hud`, `/ds resethud`):** Drag, resize (60%-150%), and align all 6 suite HUDs (Alert Toast, Prep Bar, Raid Buffs, Focus Icons, World Flares, and Chat Frame) in `/ds hud`, or **Shift + Left-Drag** any HUD directly in the world out of combat with scale-aware magnetic snapping, live alignment guides, `Alt` fine-tuning, strict `0 px` screen clamping, and **Right-Click** / **Shift + Right-Click** quick-jump into HUD Edit Mode. All 5 non-chat HUDs also hide automatically during Pet Battles (keeping **DynamicChat** visible for guild and whisper chat) and restore cleanly afterward.
* **3-Step Quick Start & `?` Module Quick Guides (`/ds setup`, `/ds conflicts`):** Pick your Theme, Accent & Font in Step 1, resolve addon conflicts in Step 2, and choose starter presets or toggle individual modules in Step 3 -- plus a compact `?` Quick Guide button in the top header of every module.
* **Theme & Font Studio, Windows & `!DS1!` Import / Export (`/ds studio`, `/ds theme`, `/ds windows`, `/ds export`, `/ds import`):** Customise your UI in Tab 1 with 17 accent colours (including all 13 WoW Class Colours and a custom colour picker), 4 dark surface themes, 21+ built-in fonts, LibSharedMedia-3.0 / DBM / EXBOSS / BigWigs / WeakAuras / ElvUI font discovery, and Shared Alert Toast controls; manage Blizzard Desktop Windows in Tab 2; and share or back up all 13 modules plus Theme Studio via **Tab 3 (`Import & Export`)** using compact `!DS1!` profile strings (with live preview, `Replace Selected` vs `Merge` modes, persistent `Undo Last Import` rollback, strict private cache safety, and full compatibility with standalone DynamicMarker).

---

## Included Modules

| Module | Slash | What It Does |
| :--- | :--- | :--- |
| **DynamicLoad** | `/dl` | Automatically switches addon profiles for Outdoor, Delves, Dungeons, Raid, and PvP with Always and Never load locks |
| **DynamicPrep** | `/dprep`, `/dp` | Top stat/durability/FPS bar, Midnight Omni Folio tracker, clickable Raid Buff & Consumable reminders, `[DynamicHeal]` & Role-Smart `[DynamicDrink]` macros, Mage Food restock & Low Durability alert toasts, Red Error Text & Sound Filter, and quest/gossip QoL |
| **DynamicTalent** | `/dt`, `/dynamictalent` | Unlimited per-spec talent loadout library, PlayerSpellsFrame dock, Raid/M+/PvP/Zone talent binds, custom group order, Prep Bar capsule hook, and Swap Reminder Toasts |
| **DynamicMarker** | `/dm`, `/fm` | Instant focus & raid target marking, optional world flare cycling & clear hotkeys (unbound by default), floating Focus & Flare bars, and smart interrupt macro |
| **DynamicCursor** | `/dcur`, `/dynamiccursor` | Customisable Cursor Ring (3 styles across 5 thickness levels, Extra Ring Contrast, Centre Dot, Ground-Target AoE Highlight, Mouse-Look ghost & Click-Pulse), concentric Inner GCD Ring & Outer Cast/Channel/Empower Arc with Mini Spell Icon, modular Character Crosshair, Find My Cursor locator, Pooled Cursor Trail, and Smart Cursor Tooltips |
| **DynamicZoom** | `/dz` | Unlocks 39-yard max camera zoom, speeds up scroll zooming, and fades trees/pillars instead of snapping your camera |
| **DynamicFPS** | `/dfps` | Switches graphics settings automatically per zone, protects combat FPS, and tunes Spell Queue Timing from live ping + haste |
| **DynamicGroup** | `/dgroup`, `/dg` | Adds region tags, M+ scores, and Lust/B-Res icons to Premade Groups, Season 2 portal deck, Dungeon Teleport Toasts, party audit, opt-in Auto-Accept Role Check, and auto-keystone |
| **DynamicBags** | `/dbag` | Fast category-sorted bags, unified Personal/Warband/Guild Bank viewer with header `Ctrl+Scroll` scaling (70%-140%), Alt Inventory Vault, auto-repair, auto-sell junk, and opt-in Auto-Unwrap |
| **DynamicMail** | `/dmail`, `/dynamicmail` | 1-click Inbox Open All, AH Gold, Items Only, and empty-letter cleanup with bag-reserve safety, Alt Vault recipient picker, and `Alt+Left-Click` bag attach |
| **DynamicChat** | `/dchat`, `/dc`, `/dynamicchat` | Smoked-glass chat frame, `/ww` target whispers, `/rl` reload, `/lg` group leave, 10 DynamicSuite chimes + 7 Blizzard alert sounds, Mention Alert Toasts, clickable URLs, and reload history |
| **DynamicVault** | `/dv`, `/dynamicvault` | Flush Great Vault top dock, account-wide Great Vault matrix (Raid, Mythic+, Delves), Restored Coffer Keys, Catalyst, Crests, owned Keystones, Weekly Reset timer, Bountiful Delves, and Weekly Checklists |
| **DynamicDialogue** | `/dd`, `/ddlg`, `/dynamicdialogue` | Obsidian Quest & Gossip reader with `1-9` hotkeys, Spacebar accept/complete, Shift bypass, typography controls, and automatic yielding to DialogueUI / Immersion / Storyline |

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/ds` or `/dynamicsuite` | Open or close the DynamicSuite window |
| `/ds hud`, `/ds edit`, `/ds move` | Toggle HUD Edit Mode across all movable suite bars |
| `/ds resethud` | Reset all suite HUD bars to safe screen-clamped default positions |
| `/ds search <query>` | Open Global Smart Search with your query pre-filled |
| `/ds setup` or `/ds guided` | Open the 3-Step Quick Start (`1. Style`, `2. Conflicts`, `3. Modules`) |
| `/ds conflicts` | Open the Conflict Scanner directly at Step 2 and print a summary in chat |
| `/ds spotlight` | Preview the latest Feature Spotlight modal (`/ds spotlight reset` clears seen flags) |
| `/ds theme` or `/ds studio` | Open Suite Studio (`Theme & Typography`, `Desktop Windows & Menus`, and `Import & Export`) |
| `/ds windows` or `/ds win` | Open Suite Studio directly to the Blizzard Desktop Window Manager |
| `/ds export`, `/ds import`, `/ds profiles` | Open Suite Studio Tab 3 to export, preview, import, or undo `!DS1!` profile strings |
| `/ds changelog` | View the DynamicSuite release notes |
| `/ds reset` | Reset the DynamicSuite window size and position |
| `/ds reload` | Reload your user interface |
| `/dl` or `/dynamicload` | Open DynamicLoad (supports auto, status, lock, unlock, freeze, profile, toast) |
| `/dprep` or `/dp` | Open DynamicPrep (supports edit, buffs, qol, reset) |
| `/dt` or `/dynamictalent` | Open DynamicTalent (supports binds, edit, hud, reset) |
| `/dm`, `/dynamicmarker`, `/fm`, `/focusmarker` | Open DynamicMarker (supports hud, resethud, lock, unlock, flares, macros, mute, show, hide, export, import, profiles, migrate, reset) |
| `/dcur` or `/dynamiccursor` | Open DynamicCursor (supports raid, highvis, minimal, full, reset) |
| `/dz` or `/dynamiczoom` | Open DynamicZoom (supports max, 39, reset) |
| `/dfps` or `/dynamicfps` | Open DynamicFPS (supports status, apply, restore, reset) |
| `/dgroup` or `/dg` | Open DynamicGroup (supports rc, pull, testtoast, reset) |
| `/dbag` or `/dbags` | Open DynamicBags (supports bag, bank, warband, guild, merge, clear, vault clear, reset) |
| `/dmail` or `/dynamicmail` | Open DynamicMail (supports all, gold, items, mats, boe, warband, same, stop, reset) |
| `/dv` or `/dynamicvault` | Open DynamicVault (supports open, scan, reset) |
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

See [CHANGELOG.md](CHANGELOG.md) for v2.0.0+ releases and [docs/CHANGELOG_ARCHIVE.md](docs/CHANGELOG_ARCHIVE.md) for pre-v2.0.0 history across all 13 modules.
