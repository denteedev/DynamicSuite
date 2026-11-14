# DynamicMarker -- CurseForge Storefront Copy & Release Changelog (v1.9.6)

> **Target Game Version:** World of Warcraft Retail Midnight `12.1.5` (Interface `120105`)  
> **Version:** `v1.9.6` (`14/11/2026`)  
> **Author:** Dentee-Frostmourne  
> **CurseForge Project Page:** https://www.curseforge.com/wow/addons/dynamicmarker

---

## Section 1: CurseForge Project Description (Copy & Paste Markdown)

```markdown
# DynamicMarker -- Raid Target Icons, World Flares & Smart Interrupt Macros

[![Support Me on Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/dentee)

**World of Warcraft Retail Midnight `12.1.5` (Interface `120105`) | Author: Dentee-Frostmourne**

**DynamicMarker** (`/dm`) is a fast, zero-taint Mythic+ and Raid utility suite for target marking, `@cursor` world flares, floating HUD icon/flare bars, and automated focus/interrupt macros across all 13 classes. Built for Midnight `12.1.5`, it preserves full standalone functionality while seamlessly integrating with the 8-module **[DynamicSuite](https://www.curseforge.com/wow/addons/dynamicsuite)** ecosystem.

---

## Upgrading from FocusMarker? (Automatic `FocusMarkerDB` Migration)

**DynamicMarker is the official continuation and full Midnight `12.1.5` rebuild of FocusMarker.**

* **Automatic One-Time Migration:** On `ADDON_LOADED` / `PLAYER_LOGIN`, DynamicMarker detects any existing `FocusMarkerDB` SavedVariables, archives a read-only snapshot (`legacyFocusMarker`), and automatically migrates your bar positions, scales, opacity, visibility rules (`Always` / `Group` / `Off`), orientation (`Horizontal` / `Vertical`), and custom icon/flare cycle orders into `DynamicMarkerDB` (`migratedFromFocusMarker = true`) without overwriting future edits.
* **In-Place Macro Upgrade:** Any existing `[FocusMarker]` or `[FocusMark]` general macro on your action bars is seamlessly upgraded in-place to `[DynamicMark]`.
* **Conflict Resolution & Re-Import:** If `FocusMarker` is still enabled, DynamicMarker's inline conflict banner and **Guided Setup** modal let you import your settings and disable `FocusMarker` in one click. You can also run `/dm import` (or `/dm import status`) at any time out of combat.

---

## 30-Second Quick Start (`[DynamicMark]` & `[DynamicKick]`)

Open **`/dm`** and switch to the **Macro Setup** tab (or click **Guided Setup** in the left rail):

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

Type **`/dm hud`** (or click **Edit Mode (HUDs)** in the left rail / **Unlock HUD Movers** inside the HUD settings) to position your floating bars with pixel precision:

* **Pixel-Bordered Movers & Alignment Grid:** Highlights `DynamicMarker: Icon Bar` and `DynamicMarker: Flare Bar` with live coordinate badges (`X` / `Y` / `Scale%`).
* **Smooth Drag & Magnetic Centre Snap:** Left-drag any mover smoothly (`Hold Ctrl` while dragging to bypass magnetic centre snapping).
* **Mousewheel Scaling:** Scroll up or down directly over a mover to scale the bar from **`60%` to `150%`** in `5%` increments.
* **Precision Inspector:** Use `1px` directional nudge buttons, type exact `X` / `Y` coordinates, snap with **Center Horizontal**, **Center Vertical**, **Top Stack**, or **Bottom Dock**, or `Shift + Right-Click` any mover to reset its position and scale.
* **Zero-Taint Failsafe:** Pressing **`ESC`** or entering combat immediately locks movers cleanly with zero taint.

---

## Obsidian Theme & Font Studio

DynamicMarker features a full dark-obsidian control shell matching the DynamicSuite design language:

* **Theme & Font Studio Modal:** Switch account-wide Accent Colours (**Royal Amber** `#F5B82E`, **Midnight Cyan** `#38BDF8`, **Crimson Core** `#F87171`, **Obsidian Silver** `#CBD5E1`, or **Player Class Colour**), 4 Surface Palettes (**Obsidian Dark**, **Slate Steel**, **Midnight Pitch Black**, **Smoked Glass**), and **Font Scale** (`95%` / `100%` / `110%`).
* **Bottom-Right Footer Dock:** Adjust standalone window **Opacity** (`50%`-`100%`), **Scale** (`80%`-`120%`), trigger **Reload UI**, or resize cleanly via Blizzard's native bottom-right corner grabber.

---

## Part of DynamicSuite (Dual-Mode Architecture)

**Want 7 more lightweight Retail Midnight modules in one unified hub?**

Check out the full **[DynamicSuite on CurseForge](https://www.curseforge.com/wow/addons/dynamicsuite)** (`https://www.curseforge.com/wow/addons/dynamicsuite`), which bundles:

* **DynamicLoad** (`/dl`) -- Context-aware 5-zone addon profile manager (`Outdoor`, `Delves`, `Dungeons`, `Raid`, `PvP`)
* **DynamicPrep** (`/dprep`) -- Telemetry top bar, clickable raid buffs & consumables HUD, Omni Folio, and smart quest/gossip QoL
* **DynamicMarker** (`/dm`) -- Targets, world flares, and smart interrupt macros (this addon!)
* **DynamicZoom** (`/dz`) -- Max camera zoom unlock (`39 yds`), reactive scroll boost, and occlusion fade
* **DynamicFPS** (`/dfps`) -- Zone-based graphics presets, combat FPS guard, and adaptive `SpellQueueWindow`
* **DynamicGroup** (`/dgroup`) -- Datacentre region & utility LFG filters, 1-click sign-up, and keystone slotting
* **DynamicBags** (`/dbag`) -- Zero-lag virtual category bags, Warband/Guild Bank companion, and Alt Vault
* **DynamicChat** (`/dchat`) -- Instant `/ww` & `/qq` target whispers, smoked-glass chat skin, and reload history restore

DynamicMarker uses a **Dual-Mode Architecture** with a semantic version guard (`CompareSemVer`): you can run it completely standalone, or install it alongside `DynamicSuite` and the newer version automatically takes priority with zero duplicate frames or double-loading.

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/dm` or `/dynamicmarker` | Open or toggle the DynamicMarker configuration window |
| `/dm hud` / `/dm edit` / `/dm move` | Toggle HUD Edit Mode (movers, alignment grid & precision inspector) |
| `/dm unlock` | Unlock HUD Edit Mode movers |
| `/dm lock` | Lock HUD Edit Mode movers and save positions |
| `/dm flares` | Open directly to the **World Flare Keys (F4 / F5)** tab |
| `/dm macros` | Open directly to the **Macro Setup** (`[DynamicMark]` & `[DynamicKick]`) tab |
| `/dm mute` / `/dm silent` | Toggle Focus Mark chat announcements On / Muted |
| `/dm show` | Set the On-Screen Focus Bar HUD to **Always Shown** |
| `/dm hide` | Hide the On-Screen Focus Bar HUD (**Off**) |
| `/dm import` | Re-import settings from `FocusMarkerDB` (out of combat) |
| `/dm import status` | Print current `FocusMarkerDB` migration/snapshot status in chat |
| `/dm reset` | Reset DynamicMarker settings to defaults (preserves migration snapshot) |

---

## Support & Contact

* **Author:** Dentee-Frostmourne
* **Standalone CurseForge:** https://www.curseforge.com/wow/addons/dynamicmarker
* **Full Suite (DynamicSuite):** https://www.curseforge.com/wow/addons/dynamicsuite
* **Support Development on Ko-fi:** https://ko-fi.com/dentee
* **Direct Contact & Feedback:** `denteedev@gmail.com`
```

---

## Section 2: CurseForge File Changelog Block (`v1.9.6` -- `14/11/2026`)

```markdown
## DynamicMarker v1.9.6 (14/11/2026 -- Retail 12.1.5 / Interface 120105)

### Highlights & New Features
* **Standalone Scrollable Changelog Modal Parity:** Replaced the legacy static standalone Changelog summary with a scrollable `ScrollFrame` modal reading live release notes directly from `DynamicMarker.CHANGELOG.entries` with colour-coded `[FEATURE]`, `[FIX]`, and `[UI]` badges matching the full DynamicSuite Changelog Hub.
* **Lockstep `v1.9.6` Sync with DynamicSuite:** Synchronised version metadata, fallback checks, and `/dm` + `/fm` alias parity cleanly across standalone and bundled builds.
* **Official FocusMarker -> DynamicMarker Migration (`FocusMarkerDB`):** Automatically detects legacy `FocusMarkerDB` SavedVariables on load, preserves a non-destructive read-only snapshot, imports bar positions, scales, opacity, visibility rules (`Always` / `Group` / `Off`), orientation, and custom icon/flare cycle sequences into `DynamicMarkerDB`, and migrates `[FocusMarker]` general macros in-place to `[DynamicMark]` (`/dm import` and `/dm import status` supported).
* **Encapsulated HUD Edit Mode (`/dm hud`):** Crisp pixel-bordered movers (`DynamicMarker: Icon Bar` and `DynamicMarker: Flare Bar`) with alignment grid, magnetic centre snap (`Ctrl` bypass), `60%`-`150%` mousewheel scaling, `Shift+Right-Click` bar reset, `1px` nudge & `X`/`Y` coordinate inspector, and zero-taint `ESC` / combat-lockdown failsafe.
* **Multi-Spec `[DynamicKick]` & Modifier-Free `[DynamicMark]` Macros:** One-click creation and drag-to-bar setup across all 13 classes with automatic specialisation/talent swapping out of combat.
* **Standalone Shell & Theme Parity with DynamicSuite:**
  * **Bottom-Right Footer Dock:** Added persisted **Opacity** (`50%`-`100%`) and **Scale** (`80%`-`120%`) sliders, **Reload UI** button, and Blizzard's native `14x14` corner resize grabber (`UI-ChatIM-SizeGrabber-Up` / `Highlight`).
  * **Theme & Font Studio (`FULLSCREEN_DIALOG`):** Live surface switching (`Obsidian Dark`, `Slate Steel`, `Midnight Pitch Black`, `Smoked Glass`), 5 accent themes, font scaling, and solid opaque modal backing with zero bleed-through.
  * **First-Open `ESC > Options > AddOns` Fix:** Hardened `SettingsPanel` dismissal and deferred post-layout refresh so opening DynamicMarker from Blizzard's AddOns menu renders cleanly on the first click.
  * **Copyable Support Modal Links:** Click-to-highlight `Ctrl+C` EditBoxes for Ko-fi (`https://ko-fi.com/dentee`), standalone CurseForge (`dynamicmarker`), full `DynamicSuite` (`dynamicsuite`), and `denteedev@gmail.com`.
  * **Dual-Mode Brand & Asset Parity:** Two-layer `icon_white.tga` + `icon_accent.tga` branding and `CompareSemVer` duplicate-install guard for seamless standalone or bundled `DynamicSuite` operation.
```
