# DynamicMarker (formerly FocusMarker) -- Raid Target Icons, World Flares & Smart Interrupt Macros

[![Support Me on Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/dentee)

**Version:** `v1.9.5` (`14/11/2026`) | **Target Client:** World of Warcraft Retail Midnight `12.1.5` (Interface `120105`) | **Author:** Dentee-Frostmourne

**DynamicMarker** (`/dm`, `/fm`) is a fast, zero-taint Mythic+ and Raid utility addon for raid target marking, `@cursor` world flares, floating HUD icon/flare bars, and automated focus/interrupt macros across all 13 classes. Built for Midnight `12.1.5`, it runs cleanly as a standalone addon and integrates seamlessly with the 8-module **[DynamicSuite](https://www.curseforge.com/wow/addons/dynamicsuite)** ecosystem.

---

## Upgrading from FocusMarker? (Automatic `FocusMarkerDB` Migration)

**DynamicMarker is the official continuation and full Midnight `12.1.5` rebuild of FocusMarker.**

* **Automatic One-Time Migration:** On `ADDON_LOADED` / `PLAYER_LOGIN`, DynamicMarker detects any existing `FocusMarkerDB` SavedVariables, archives a read-only snapshot (`legacyFocusMarker`), and automatically imports your bar positions, scales, opacity, visibility rules (`Always` / `Group` / `Off`), orientation (`Horizontal` / `Vertical`), and custom icon/flare cycle orders into `DynamicMarkerDB` (`migratedFromFocusMarker = true`) without overwriting future edits.
* **In-Place Macro Upgrade:** Any existing `[FocusMarker]` or `[FocusMark]` general macro on your action bars is automatically upgraded in-place to `[DynamicMark]`.
* **Backwards-Compatible Aliases:** Both `/fm` and `/focusmarker` work out of the box alongside `/dm` and `/dynamicmarker`.
* **Conflict Resolution & Re-Import:** If legacy `FocusMarker` is still enabled, DynamicMarker's inline conflict banner and **Guided Setup** modal let you import your settings and disable `FocusMarker` in one click. You can also run `/dm import` (or `/dm import status`) at any time out of combat.

---

## Automated Macro Setup (`[DynamicMark]` & `[DynamicKick]`)

No manual macro editing required. Open **`/dm`** and switch to the **Macro Setup** tab (or click **Guided Setup** in the left rail):

1. **`[DynamicMark]` (General Macro -- Account-Wide):**
   * Click **Step 1: Create / Update `[DynamicMark]`**, then drag **Step 2: Drag to Action Bar** onto any action bar slot.
   * **Modifier-Free Design:** Sets `@focus` on your mouseover or current target and applies your chosen Raid Target Icon (Skull by default) with zero modifier collisions (`Shift`/`Alt`/`Ctrl` clear-focus modifier is optional and defaults to `None`).
   * **Optional Chat & Ready Check Alerts:** Announce your focus mark to Party/Raid or Say (`/dm mute` toggles Silent Mode instantly) and trigger automatic Ready Check mark reminders.
2. **`[DynamicKick]` (Character Macro -- Multi-Spec Auto-Swap):**
   * Click **Step 1: Create / Update `[DynamicKick]`**, then drag **Step 2: Drag to Action Bar**.
   * **Automatic Class & Specialisation Swapping:** Dynamically updates out of combat whenever you change specialisations or talents (`PLAYER_SPECIALIZATION_CHANGED` / `TRAIT_CONFIG_UPDATED`) across all 13 classes (including Druid `Skull Bash` <-> `Solar Beam`, Hunter `Counter Shot` <-> `Muzzle`, and Warlock `Command Demon`).
   * **Configurable Interrupt Priority:**
     * `Smart Auto-Target (Mouseover > Focus > Nearest)` *(Default)*
     * `Standard: Mouseover > Focus > Target`
     * `Standard: Focus > Mouseover > Target`
     * `Strict Focus Only (@focus)`

---

## `F4` / `F5` World Flares & On-Screen HUD Bars

* **One-Key Ground Flares (`F4` / `F5`):** Press **`F4`** (customisable) to place `@cursor` World Markers in sequence through your enabled flares (`1`-`8`), and press **`F5`** (customisable) to clear all active flares (`/cwm all`).
* **Customisable Flare Cycle:** Drag and reorder any of the 8 world markers in the **World Flare Keys (F4 / F5)** tab and toggle individual flares on or off.
* **On-Screen Focus Bar & World Flare Bar HUDs:**
  * Toggle each floating bar independently between **Always**, **Group**, or **Off** (combat-safe visibility drivers update automatically when joining or leaving parties and raids).
  * Choose **Horizontal** or **Vertical** layout, adjust HUD border style (**Suite Accent**, **Subtle Dark**, or **Borderless**), and tune bar **Scale** and **Opacity**.

---

## Encapsulated HUD Edit Mode (`/dm hud`)

Type **`/dm hud`** or **`/dm lock`** (or click **Edit Mode (HUDs)** in the left rail / **Unlock HUD Movers** inside the HUD settings) to position your floating bars with pixel precision:

* **Pixel-Bordered Movers & Alignment Grid:** Highlights `DynamicMarker: Icon Bar` and `DynamicMarker: Flare Bar` with live coordinate badges (`X` / `Y` / `Scale%`).
* **Smooth Drag & Magnetic Centre Snap:** Left-drag any mover smoothly (`Hold Ctrl` while dragging to bypass magnetic centre snapping).
* **Mousewheel Scaling:** Scroll up or down directly over a mover to scale the bar from **`60%` to `150%`** in `5%` increments.
* **Precision Inspector:** Use `1px` directional nudge buttons, type exact `X` / `Y` coordinates, snap with **Center Horizontal**, **Center Vertical**, **Top Stack**, or **Bottom Dock**, or `Shift + Right-Click` any mover to reset its position and scale.
* **Zero-Taint Failsafe:** Pressing **`ESC`** or entering combat immediately locks movers cleanly with zero taint.

---

## Obsidian Theme & Font Studio

DynamicMarker includes the full dark-obsidian control shell matching the DynamicSuite design language:

* **Theme & Font Studio Modal:** Switch account-wide Accent Colours (**Royal Amber** `#F5B82E`, **Midnight Cyan** `#38BDF8`, **Crimson Core** `#F87171`, **Obsidian Silver** `#CBD5E1`, or **Player Class Colour**), 4 Surface Palettes (**Obsidian Dark**, **Slate Steel**, **Midnight Pitch Black**, **Smoked Glass**), and **Font Scale** (`95%` / `100%` / `110%`).
* **Bottom-Right Footer Dock:** Adjust standalone window **Opacity** (`50%`-`100%`), **Scale** (`80%`-`120%`), trigger **Reload UI**, or resize cleanly via Blizzard's native bottom-right corner grabber.

---

## Part of DynamicSuite (Dual-Mode Architecture)

**Want 7 more lightweight Retail Midnight modules in one unified hub?**

Check out the full **[DynamicSuite on CurseForge](https://www.curseforge.com/wow/addons/dynamicsuite)** (`https://www.curseforge.com/wow/addons/dynamicsuite`), which bundles:

* **DynamicLoad** (`/dl`) -- Context-aware 5-zone addon profile manager (`Outdoor`, `Delves`, `Dungeons`, `Raid`, `PvP`), 6-target `[+ HUD]` Edit Mode, Guided Setup & Conflict Scanner
* **DynamicPrep** (`/dprep`) -- Telemetry top bar, clickable raid buffs & consumables HUD, Midnight Omni Folio, `[DynamicHeal]` survival macro, and smart quest/gossip QoL
* **DynamicMarker** (`/dm`, `/fm`) -- Raid target icons, world flares, and smart interrupt macros (this addon)
* **DynamicZoom** (`/dz`) -- Max camera zoom unlock (`2.6x` / `39 yds`), reactive scroll acceleration, foliage/pillar occlusion fade, zone zoom profiles, and ActionCam pitch/offset
* **DynamicFPS** (`/dfps`) -- Per-zone Blizzard Base Game Quality profiles, hardware tier presets, Minimum Combat FPS guard, and adaptive Haste + Ping `SpellQueueWindow`
* **DynamicGroup** (`/dgroup`, `/dgrp`) -- Live party gear/enchant/consumable ledger, LFG Mini-Bar with Datacentre Region & Party Utility filters, 1-click sign-up, and M+ keystone auto-insert
* **DynamicBags** (`/dbag`) -- Zero-lag virtual category bags, Character/Warband/Guild Bank companion, drop-anywhere stack splitting, Alt Vault, and auto-repair/sell/loot
* **DynamicChat** (`/dchat`, `/dc`) -- Zero-taint `/ww` & `/qq` target whispers, smoked-glass chat skin, Left Utility Rail, per-channel sound alerts, and reload history restore

DynamicMarker uses a **Dual-Mode Consolidated Architecture** with a semantic version guard (`CompareSemVer`): you can run it completely standalone, or install it alongside `DynamicSuite` and the newer version automatically takes priority with zero duplicate frames or double-loading.

---

## Slash Commands (`/dm`, `/dynamicmarker`, `/fm`, `/focusmarker`)

| Command | Action |
| :--- | :--- |
| `/dm` (or `/dm config`, `/dm ui`, `/dm options`) | Open or toggle the DynamicMarker configuration window |
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
| `/dm help` / `/dm ?` | Print all available commands in chat |

---

## Support & Contact

* **Buy the Developer a Coffee (Ko-fi):** `https://ko-fi.com/dentee`
* **Standalone CurseForge:** `https://www.curseforge.com/wow/addons/dynamicmarker`
* **Full Suite CurseForge:** `https://www.curseforge.com/wow/addons/dynamicsuite`
* **Direct Contact & Feedback:** `denteedev@gmail.com`
