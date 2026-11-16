# DynamicMarker Changelog
*Author: Dentee-Frostmourne  |  Release: v2.3.0 (16/11/2026 - Retail 12.1.5 / Interface 120105)*

---

## DynamicMarker v2.3.0 (16/11/2026)

### Improved
* **HUD Edit Mode `Apply All` Appearance Action:** Added a compact Dark-Obsidian (`#0B0D12`) / Blaze Orange (`#F97316`) `Apply All` button to Row 3 of `DynamicMarkerEditModeInspector` to copy the active bar's Opacity and Border Style across both Focus Icons and World Flare Bar in one click.
* **Version & Coexistence Lockstep Parity:** Synchronised standalone DynamicMarker metadata and version-aware coexistence checks to `v2.3.0` for Retail 12.1.5 (Interface 120105, Midnight Season 2).

---

## DynamicMarker v2.2.1 (16/11/2026)

### Improved
* **Version & Coexistence Lockstep Parity:** Synchronised standalone DynamicMarker metadata and version-aware coexistence checks to `v2.2.1` for Retail 12.1.5 (Interface 120105, Midnight Season 2).

---

## DynamicMarker v2.2.0 (15/11/2026)

### Added
* **SharedMedia, AddOn & Blizzard Font Discovery in Theme Studio:** Added runtime scanning for `LibSharedMedia-3.0`, `DBM`, `WeakAuras`, and `ElvUI` fonts alongside Blizzard standard fonts and bundled Expressway fonts inside Theme & Font Studio. Grouped the `Font Family` selector under `Built-in Fonts`, `Blizzard`, and `SharedMedia / AddOns` section headers with scrolling, live search filtering, `pcall`-guarded per-font preview rendering, and safe automatic fallback if an external addon is disabled.

### Improved
* **Unbound-by-Default World Flare Keybinds & Guided Setup Assignment:** Removed hardcoded `F4` and `F5` default World Flare bindings so fresh installs and Resets leave both keys `"Unbound"` (`""`) without overriding existing Blizzard or action bar keybinds (while preserving any already-saved `DynamicMarkerDB` bindings). Added clean single-button `Cycle World Flare Keybind` and `Clear All Flares Keybind` capture controls (`"Unbound (Click to Bind)"` / `"[KEY] (Click Rebind)"`) in both Guided Setup and the World Flare Keys (`/dm flares`) tab, where Left-Click captures, `Escape` cancels without losing your existing binding, and `Right-Click` (or `Backspace`/`Delete` while capturing) clears to `"Unbound"`.
* **Version & Coexistence Lockstep Parity:** Synchronised standalone DynamicMarker metadata and version-aware coexistence checks to `v2.2.0` for Retail 12.1.5 (Interface 120105, Midnight Season 2).

---

## DynamicMarker v2.1.2 (15/11/2026)

### Fixed
* **Version & Coexistence Lockstep Parity:** Synchronised standalone DynamicMarker metadata and version-aware coexistence checks to `v2.1.2` for Retail 12.1.5 (Interface 120105).

---

## DynamicMarker v2.1.1 (15/11/2026)

### Added
* **3-Row `560x110` HUD Edit Appearance Bar (Row 3):** Upgraded standalone `DynamicMarkerEditModeInspector` into a compact `560x110` 3-row draggable inspector dock with live Row 3 controls: an `Opacity` slider (`20%-100%`, step `5%`) that previews opacity cleanly while keeping mover overlays sharp via `SetIgnoreParentAlpha(true)`, `Accent` | `Dark` | `None` Border Style pills synchronised 1:1 with Target Icon Bar and World Flare Bar sub-settings, and a `Horiz` | `Vert` Orientation toggle that flips layout direction and re-clamps to screen bounds immediately. Clicking `[Reset]` restores Position, Scale (`100%`), Opacity (`95%`), Border Style (`Accent`), and Orientation (`Horizontal`).

### Fixed
* **First-Click HUD Edit Dropdown & Mover Initialisation:** Closed the HUD selector dropdown cleanly when entering HUD Edit Mode so Row 2 and Row 3 controls are never covered on entry, promoted Target Icon Bar and World Flare Bar mover overlays (`editMover`) to `HIGH` frame strata (`FrameLevel + 50`) with `SetIgnoreParentAlpha(true)`, and ordered `SyncEditBarStates()` after bar refreshes in `SetEditMode` so shown movers appear reliably on the very first open.
* **Unified `14x14` Blaze Orange Resize Grip:** Updated the standalone window bottom-right corner resize handle (`BOTTOMRIGHT -4, 4`) to use the unified `#F97316` Blaze Orange hover highlight.

---

## DynamicMarker v2.1.0 (15/11/2026)

### Fixed
* **World Flare Hardware Keybinds:** Anchored the secure World Flare cycle and clear action buttons on-screen (`1x1`, zero alpha, non-mouse-blocking), removed the `"flare"` button-name override in `SecureHandlerWrapScript` so `"LeftButton"` dispatches `/wm [@cursor]` cleanly across key-down and key-up CVars, and ensured `/cwm all` clears all ground flares reliably in and out of combat.
* **Live Keybind Status Bar & Sub-Tab Label:** Rebinding, Escape/Right-Click clearing, or resetting Cycle/Clear flare keys now immediately updates the button labels, the `World Flare Keys (...)` tab label, and the top telemetry status readout without needing to switch tabs.

### Improved
* **Compact Draggable HUD Edit Dock & Off-Screen Fail-Safe:** Redesigned standalone HUD Edit Mode into a compact `560x74` 2-row draggable inspector with a HUD Selector Dropdown, non-truncated `Hidden` / `Shown` toggles, `Grid`, `Reset`, `Back to Suite`, X/Y steppers, `Center X` / `Center Y`, and a Scale slider (`60%-150%`), preserving at least `60px` on-screen when tucked near screen edges while keeping Target Icon and World Flare bars strictly inside screen edges.
* **Hidden-By-Default HUD Movers & Standardised `[Edit HUD]` Buttons:** Entering HUD Edit Mode (`/dm hud` or standalone sidebar) now hides `Off`/`Hidden` bars by default; selecting a hidden bar in the HUD dropdown or clicking a section's Obsidian/Blaze-Orange `Edit HUD` button temporarily previews that bar with a clear `HIDDEN (Click Shown to Enable)` badge.

---

## DynamicMarker v2.0.9 (15/11/2026)

### Fixed
* **World Flare Hardware Keybinds & Custom Sequence Order:** Fixed Cycle Ground Flare (`F4`) and Clear All Flares (`F5`) hardware keybinds so they fire reliably in and out of combat, walk your saved and enabled World Flare Cycle Sequence in exact custom order via `SecureHandlerWrapScript`, and update the floating World Flare Bar to match your custom sequence order and enabled flares.

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
