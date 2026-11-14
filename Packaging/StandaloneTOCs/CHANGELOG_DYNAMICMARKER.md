# DynamicMarker Changelog
*Author: Dentee-Frostmourne  |  Release: v2.0.8 (15/11/2026 - Retail 12.1.5 / Interface 120105)*

---

## DynamicMarker v2.0.8 (15/11/2026)

### Fixed
* **Target Only Focus Macro Clear:** Updated the Target Only `[DynamicMark]` macro template to `/focus [@target,exists,nodead][]` so pressing it with a target sets focus and marks it, while pressing it with no target clears your existing focus target.

---

## DynamicMarker v2.0.7 (15/11/2026)

### Added
* **Inline Manual Macro Editor & Custom Icon Preservation:** In `Manual (Custom)` mode, Sub-Tab 3's `[DynamicMark]` preview becomes a dark-obsidian multi-line EditBox (255-character limit, live character counter, Escape to unfocus) so you can edit `[DynamicMark]` directly inside DynamicMarker and save immediately with `Step 1: Create / Update [DynamicMark]`. Updating an existing `[DynamicMark]` macro now preserves any custom in-game macro icon you assigned.

---

## DynamicMarker v2.0.6 (15/11/2026)

### Improved
* **Smart Sync & Surgical `/tm` Patching for `[DynamicMark]`:** Added 3-way sync handling for `Manual (Custom)` mode -- passive logins and reloads keep custom macros untouched, changing Focus Icon, Group Scope, or Clear Focus Modifier surgically patches only the `/tm` and `/clearfocus` lines (respecting WoW's 255-character macro limit), the Sub-Tab 3 preview displays your live `[DynamicMark]` body, and `Step 1: Create / Update [DynamicMark]` requires a 2-click confirmation before resetting custom lines.

---

## DynamicMarker v2.0.5 (15/11/2026)

### Added
* **Focus Target Mode for `[DynamicMark]`:** Added a **Focus Target Mode** segmented pill control (`Mouseover + Target`, `Target Only`, `Manual (Custom)`) in Sub-Tab 3 so you can restrict `[DynamicMark]` to current target only or preserve custom manual macro edits across logins and reloads.

---

## DynamicMarker v1.9.9 (14/11/2026)

### Fixed
* **Top & Bottom Screen-Edge Bar Drift:** Focus Icons and World Flare bars parked flush against the top edge, bottom edge, or corners now stay in their exact saved positions after reloading the UI at every bar scale (70%, 100%, and 130%).
* **Duplicate HUD Edit Windows:** Standalone DynamicMarker's extra HUD Edit popup no longer appears when DynamicSuite is active, while keeping standalone HUD Edit Mode intact when run solo.
* **Reset Bounds:** Resetting HUD positions (`/dm resethud` or from Options) now resets scale to 100%, restores horizontal layout, and keeps bars cleanly inside your screen bounds.
* **Automatic Standalone Handoff:** Running both DynamicSuite and standalone DynamicMarker together cleanly hands off control on launch to prevent duplicate bars or settings conflicts.

### Improved
* **Reliable Dark-Obsidian Coexistence Reload Prompt:** Replaced Blizzard's default popup with a matching dark-obsidian reload modal whenever DynamicSuite and standalone DynamicMarker were enabled together at launch.
* **Plain-English UI & Reset Prompt Polish:** Rewrote reset confirmation dialogs and tooltips in clear, jargon-free Australian English that fits cleanly without truncation.

---

## DynamicMarker v1.9.8 (14/11/2026)

### Improved
* **Release Channel Packaging:** Streamlined automated CurseForge release packaging for standalone DynamicMarker.

---

## DynamicMarker v1.9.7 (14/11/2026)

### Improved
* **Cross-Link Support Panel:** Updated Support links with direct CurseForge links for both standalone DynamicMarker and the full DynamicSuite bundle.

---

## DynamicMarker v1.9.6 (14/11/2026)

### Improved
* **Standalone Changelog Viewer:** Standalone DynamicMarker's Changelog modal now scrolls through full release notes with colour-coded badges.

---

## DynamicMarker v1.9.5 (14/11/2026)

### Added
* **Standalone Window Controls & Copyable Support Links:** Added Window Opacity (50%-100%), Scale (80%-120%), a Reload UI button, and click-to-copy support links to standalone DynamicMarker.
* **Marker Slash Aliases:** Added `/fm` and `/focusmarker` aliases alongside `/dm`, plus `/dm help` and bar lock toggling via `/dm lock`.

---

## DynamicMarker v1.9.4 (14/11/2026)

### Fixed
* **First-Open Options Launcher:** Opening standalone DynamicMarker from ESC > Options > AddOns now renders the full sidebar, workspace, and theme cleanly on the very first open.

---

## DynamicMarker v1.9.3 (14/11/2026)

### Fixed
* **Guided Setup Modal Layering:** Fixed underlying window controls bleeding through the Guided Setup modal in standalone DynamicMarker.
* **Standalone Theme & Sidebar Parity:** Added all 4 dark surface themes and matching sidebar card spacing.

---

## DynamicMarker v1.9.2 (13/11/2026)

### Added
* **HUD Edit Mode:** Added Target Icon Bar and World Flare Bar Edit Mode movers, magnetic snapping, mousewheel scaling (60%-150%), Shift+Right-Click per-bar reset, and combat/Escape exit protection (`/dm hud`).
* **One-Time FocusMarker Settings Import:** Automatically detects existing FocusMarker settings at launch and imports bar positions, scales, visibility rules, and icon/flare order without altering your original FocusMarker data.
* **Standalone Shell & Options Launcher:** Added ESC > Options > AddOns quick-launch card with Amber/Gold dark-obsidian styling, Guided Setup modal, changelog viewer, and support panel.

---

## DynamicMarker v1.9.0 (12/11/2026)

### Added
* **FocusMarker Snapshot & Re-Import Commands:** Added `/dm import` and `/dm import status` so you can re-import captured FocusMarker settings anytime out of combat, even after FocusMarker is disabled.

---

## DynamicMarker v1.3.0 (11/11/2026)

### Added
* **Modifier-Free `[DynamicMark]` & Multi-Spec `[DynamicKick]`:** 1-click focus and raid marking plus automatic interrupt spell detection for every class and specialisation across all 13 classes.
* **Floating Icon & World Flare Bars:** Interactive Raid Target Icon bar and cursor-placed World Flare bar with customisable order, orientation, and visibility rules.
