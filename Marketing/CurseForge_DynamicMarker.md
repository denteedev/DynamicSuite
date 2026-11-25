# DynamicMarker -- CurseForge Storefront Copy

> **Target Game Version:** World of Warcraft Retail Midnight 12.1.5 / 12.1.7 (Interface 120105, 120107)  
> **Author:** Dentee-Frostmourne  
> **CurseForge Project Page:** https://www.curseforge.com/wow/addons/dynamicmarker

---

## CurseForge Project Description (Copy & Paste Markdown)

```markdown
# DynamicMarker -- Raid Target Icons, World Flares & Smart Interrupt Macros

**Target Client:** World of Warcraft Retail Midnight 12.1.5 / 12.1.7 (Interface 120105, 120107) | **Author:** Dentee-Frostmourne

**DynamicMarker** (`/dm`, `/fm`) is a fast Mythic+ and Raid utility addon for instant target marking, cursor-placed world flares, floating icon and flare bars, and smart focus/interrupt macros across all 13 classes. Use it standalone or as part of the full 13-module **[DynamicSuite](https://www.curseforge.com/wow/addons/dynamicsuite)** bundle.

---

## Upgrading from FocusMarker?

**DynamicMarker is the official Midnight 12.1.5 / 12.1.7 successor to FocusMarker.**

* **Automatic Settings Import:** On first login, DynamicMarker safely imports your saved FocusMarker bar positions, scale, opacity, visibility rules (Always, Group, or Off), orientation, and custom icon/flare orders without touching your original backup.
* **Automatic Macro Upgrade:** Any existing [FocusMarker] or [FocusMark] macro on your action bars is upgraded in-place to [DynamicMark].
* **One-Click Cleanup & Re-Import:** If FocusMarker is still enabled, Guided Setup lets you import and disable it in one click. You can also run `/dm migrate`, `/dm import focusmarker`, or `/dm import status` out of combat anytime (`/dm export`, `/dm import`, and `/dm profiles` handle `!DS1!` profile sharing).
* **Built-In `/tm` Taint Diagnostics:** Automatically alerts you in chat if a third-party addon (such as DecorVendor) blocks Blizzard's `/tm` raid marker command, with an optional one-click disable or dismiss banner.

---

## 30-Second Quick Start ([DynamicMark] & [DynamicKick])

Open `/dm` and go to the **Macro Setup** tab (or click **Guided Setup** in the sidebar):

1. **[DynamicMark] (Account-Wide Target & Focus Macro):**
   * **One-Key Focus & Mark:** Click **Create / Update** and drag the macro onto any action bar slot.
   * **Modifier-Free Marking:** Sets your focus on mouseover or current target and applies your chosen Raid Target Icon (Skull by default) with no modifier keys required.
   * **Chat & Ready Check Alerts:** Optionally announce marks to Party, Raid, or Say (`/dm mute` toggles Silent Mode instantly) and get Ready Check mark reminders.
2. **[DynamicKick] (Per-Character Auto-Swapping Interrupt Macro):**
   * **Auto-Swaps Across All 13 Classes:** Automatically updates your interrupt spell whenever you switch specialisations or talents out of combat.
   * **4 Interrupt Priority Modes:** Choose between Smart Auto-Target (Mouseover > Focus > Nearest), Mouseover > Focus > Target, Focus > Mouseover > Target, or Strict Focus Only.

---

## World Flares & On-Screen HUD Bars

* **Optional One-Key Ground Flares:** Bind custom hotkeys (Unbound by default so your existing action bar bindings stay untouched) to cycle world markers at your cursor or clear all active flares in Guided Setup or **World Flare Keys** (`/dm flares`), with Right-click to unbind.
* **Customisable Flare Cycle:** Drag and reorder any of the 8 world markers in the **World Flare Keys** tab and toggle individual markers on or off.
* **Floating Focus & Flare Bars:** Show each bar Always, in Group only, or Off; switch between Horizontal and Vertical layouts; and customise border styles, Scale, and Opacity. Both bars also auto-hide cleanly during Pet Battles (aborting any active drag safely) and restore their configured visibility when the battle ends.

---

## HUD Edit Mode & Direct Shift-Drag (`/dm hud`)

Move either bar directly in the world or open `/dm hud` (or **Edit Mode (HUDs)** in the sidebar) for precision layout:

* **Direct In-World Shift + Left-Drag:** Out of combat, hold **Shift + Left-Drag** on either bar (even directly across icon buttons) to snap-move it smoothly anywhere on screen with magnetic edge and bar snapping, live alignment guides, `Alt` to bypass snapping for fine-tuning, and strict `0 px` screen clamping. Right-Click empty bar space or **Shift + Right-Click** any icon/flare to jump straight into `/dm hud`.
* **Smooth Scale-Aware Dragging:** Drag the Icon Bar and Flare Bar cleanly at any bar scale (60%-150%) with live X, Y, and Scale readouts.
* **Magnetic Edge & Bar Snapping:** In `/dm hud` Edit Mode, bars snap cleanly to screen edges, screen centres, and neighbouring bars with alignment guides (hold Shift to fine-tune freely), and stay clamped inside your screen bounds.
* **Mousewheel Scaling & Precision Controls:** Scroll over a bar in Edit Mode to scale it (60%-150% in 5% steps), nudge by 1px or 10px, type exact X/Y coordinates, or reset anytime with `/dm resethud`.

---

## Obsidian Theme Studio, `?` Quick Guide & `!DS1!` Profile Sharing

* **Custom Colours, Surfaces & Fonts:** Pick from 5 built-in accent themes (including Player Class Colour), 4 dark surface palettes, automatic font discovery from LibSharedMedia-3.0, DBM, EXBOSS, BigWigs, WeakAuras, and ElvUI, and adjustable font scaling.
* **`!DS1!` Profile Import & Export (`/dm export`, `/dm import`, `/dm profiles`):** Share or back up your DynamicMarker profile, HUD bar positions, and Theme & Font settings with full bidirectional **DynamicSuite** compatibility, `Replace Selected` vs `Merge` import modes, and persistent 1-slot `Undo Last Import` rollback across `/reload`.
* **Quick Window Controls & `?` Quick Guide:** Adjust standalone window Opacity (50%-100%) and Scale (80%-120%), trigger Reload UI from the bottom-right dock, or click **`?`** in the header for starter tips and keybind reminders.

---

## Part of DynamicSuite

Want 12 more lightweight QoL and performance modules in one unified window? Check out **[DynamicSuite on CurseForge](https://www.curseforge.com/wow/addons/dynamicsuite)** (https://www.curseforge.com/wow/addons/dynamicsuite), which includes DynamicLoad, DynamicPrep, DynamicTalent, DynamicMarker, DynamicCursor, DynamicZoom, DynamicFPS, DynamicGroup, DynamicBags, DynamicChat, DynamicVault, DynamicDialogue, and DynamicMail.

* **Automatic Coexistence:** If you install DynamicSuite later, DynamicSuite automatically disables standalone DynamicMarker and prompts a clean UI reload so you never lose settings or see duplicate bars.

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/dm` or `/dynamicmarker` | Open or close the DynamicMarker window (also `/fm` or `/focusmarker`) |
| `/dm hud`, `/dm edit`, `/dm move` | Toggle HUD Edit Mode |
| `/dm unlock` | Unlock HUD Edit Mode movers |
| `/dm lock` | Lock HUD Edit Mode movers and save positions |
| `/dm flares` | Open directly to the World Flare Keys tab |
| `/dm macros` | Open directly to the Macro Setup tab |
| `/dm mute` or `/dm silent` | Toggle Focus Mark chat announcements On or Muted |
| `/dm show` | Set the On-Screen Focus Bar HUD to Always Shown |
| `/dm hide` | Hide the On-Screen Focus Bar HUD |
| `/dm export`, `/dm import`, `/dm profiles` | Open Profile Import & Export (`!DS1!` sharing, `Replace` / `Merge`, and `Undo Last Import`) |
| `/dm migrate` or `/dm import focusmarker` | Import legacy settings from FocusMarker out of combat |
| `/dm import status` | Print FocusMarker import status in chat |
| `/dm reset` | Reset DynamicMarker settings to defaults |
| `/dm resethud` | Reset Icon Bar and Flare Bar positions to safe screen defaults |
| `/dm help` | Print slash command help in chat |

---

## Support & Contact

* **Standalone CurseForge:** https://www.curseforge.com/wow/addons/dynamicmarker
* **Full Suite CurseForge:** https://www.curseforge.com/wow/addons/dynamicsuite
* **Direct Contact & Feedback:** denteedev@gmail.com
* **Optional Tip Jar (Ko-fi -- all features are 100% free):** https://ko-fi.com/dentee

[![Support Me on Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/dentee)
```
