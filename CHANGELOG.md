# DynamicSuite Changelog
*Author: Dentee-Frostmourne  |  Release: v2.6.0 (20/11/2026 - Retail 12.1.5 / Interface 120105)*

---

## DynamicSuite & All 11 Modules v2.6.0 (20/11/2026)

### DynamicDialogue (New 11th Module `/dd`, `/ddlg`, `/dynamicdialogue`)
- **Obsidian Quest & Gossip Reader:** Launched `DynamicDialogue` as DynamicSuite's 11th dual-mode module, presenting Quest (`QUEST_GREETING`, `QUEST_DETAIL`, `QUEST_PROGRESS`, `QUEST_COMPLETE`) and NPC Gossip (`GOSSIP_SHOW`) interactions in a crisp, high-contrast Midnight Obsidian window synced live to your Suite Accent, surface theme, and font.
- **1-9 Option Hotkeys, Space Confirm & Interactive Reward Cards:** Press `1`-`9` out of combat to pick gossip or quest options immediately, `Space` to Accept/Continue/Complete, `Escape` to close cleanly, or hold `Shift` while talking to any NPC to bypass to the native Blizzard frame. Displays guaranteed rewards, clickable choice reward cards with rarity borders and full hover tooltips, gold/XP summary, draggable reader positioning, live Preview mode (`/dd preview`), and optional Quest Complete Bloom chime.
- **Zero-Taint Dynamic Auto-Yield:** Automatically yields to `DialogueUI`, `DialogUI`, `Immersion`, `Storyline`, `EllesmereUIQoL` (when its dialogue feature is enabled), and any unknown dialogue replacement addon detected via read-only Blizzard frame/event probing (`QuestFrame` / `GossipFrame`).

### Suite-Wide EllesmereUI, EnhanceQoL & Zero-Taint Auto-Yield Audit (`v2.6.0`, 20/11/2026)
- **Zero-Taint Read-Only Runtime Frame/Event Prober (`DynamicSuite:ProbeBlizzardFrameConflict`):** Added a 100% read-only runtime frame and event ownership prober across `DIALOGUE`, `CHAT`, `BAGS`, `WINDOWS`, and `TALENTS` domains (zero global hooks, zero `debugstack()` wrapping, zero taint).
- **Feature-Level Smart Sub-Module Detection (`EllesmereUI`, `EllesmereUIQoL`, `EnhanceQoL`):** Upgraded `InspectSmartSubModuleConflict` so installing base `EllesmereUI`, `EllesmereUIQoL`, or `EnhanceQoL` no longer triggers false-positive hard conflicts unless the specific overlapping sub-module or SavedVariables feature flag is actually enabled.
- **`DynamicChat` Clean Auto-Yield for `EllesmereUIChat` & Global Hook Fix:** Enabled clean automatic yielding in `DynamicChat` when `EllesmereUIChat` / `EllesmereUI_Chat` is active, and removed the legacy `EnsureDB()` wipe on `DynamicSuiteDB.global.yieldHooks` so other modules' yield states are never disturbed.
- **Suite-Wide Conflict Registry Parity (`DynamicPrep`, `DynamicChat`, `DynamicBags`):** Stopped module-level `CONFLICT_REGISTRY` blocks from overwriting `DynamicSuite_Core.lua` entries or misclassifying soft/partial QoL overlaps (`EnhanceQoL`, `Leatrix_Plus`, `Scrap`, `WindTools`) as hard conflicts, preserving `EllesmereUIAuraBuffReminders` and Talent Loadout Manager (`TLM` / `BtWLoadouts`) detection.

### DynamicSuite Core & Lockstep Metadata (`v2.6.0`)
- **11-Module Suite Integration:** Added `DynamicDialogueDB` and `Modules\DynamicDialogue.lua` to `DynamicSuite.toc`, wired `dialogue` / `DynamicDialogue` into the `/ds` Left Suite Rail, custom `32x32` RGBA vector icon `icon_mod_dialogue.tga`, standalone `Packaging\StandaloneTOCs\DynamicDialogue.toc`, and synchronised all 12 `.toc` manifests and version fallbacks to `2.6.0`.

---

## DynamicSuite & All 10 Modules v2.5.0 (19/11/2026)

### DynamicVault (New 10th Module `/dv`, `/dynamicvault`)
- **Great Vault Top Dock (Flush Width + `EllesmereUI` / `ElvUI` Auto-Match) & Optional On-Screen Overlay:** Automatically docks a sleek Account Vault bar flush to the inner bounds of Blizzard's Great Vault (`WeeklyRewardsFrame`, zero minimap buttons) with `Auto-Match` / `Suite Obsidian` skinning, Weekly Reset timer, Delve Keys/Shards, Catalyst, seasonal Crests with weekly caps, and live class-coloured alt chips (`R / M+ / D` slots + `REWARD!` badges + hover tooltips showing Next-Slot progress, Raid Lockouts, and Today's Bountiful Delves). Also includes an optional `/dv overlay` strip (`Shift+Drag` to move).
- **Account-Wide Great Vault Matrix, Raid Lockouts & Account Totals:** Added a clean dark-obsidian cross-character dashboard in `/ds` -> **DynamicVault** (and standalone `/dv`) with Account Totals (Total Gold across alts + Warband Bank, Total Keys, Unclaimed Vaults), 3 Great Vault tracks (**Raid**, **Mythic+**, **World / Delves**) with 3 visual slot pips + unlocked reward iLvls, per-character Raid Boss Lockout badges (`LFR`/`N`/`H`/`M`), automatic weekly rollover, Favourite `*` pinning, Max-Level filtering, and sorting by Vault Slots, iLvl, M+ Rating, or Name.
- **Live Bountiful Delves Scanner, Crests & Auto-Resetting Weekly Checklists:** Automatically discovers today's active Bountiful Delves via `C_AreaPoiInfo` (displayed in `/dv` Tab 1 and Great Vault dock tooltips), maps Midnight Season 2 crest tiers cleanly with weekly cap telemetry, tracks owned Mythic+ Keystones and Restored Coffer Keys, includes auto-checked weekly milestones plus custom Character/Account weekly tasks, and integrates directly into `/ds` Global Smart Search and `/ds changelog`.

### DynamicPrep, DynamicBags & DynamicGroup Refinements (`v2.5.0`, 19/11/2026)
- **Top Info Bar 1-Click Talent Loadout Switcher, Per-Boss Reminder & WCL/NS Importer (`DynamicPrep`):** Added a native **Talent Loadout** capsule right beside **Spec/Loot** on `DynamicPrep`'s Top Info Bar (Left-Click opens a sleek 1-click Obsidian switcher dropdown for all saved Blizzard Talent Loadouts and imported library builds; Right-Click opens the **Boss & Import Manager**), alongside preferred zone loadouts (`Delves`, `M+`, `Raid`, `PvP`), Warcraft Logs / Northern Sky string importing (`C_ClassTalents.ImportLoadout`), per-boss targeting bindings (`PLAYER_TARGET_CHANGED`), and a 1-click Obsidian Swap Toast on mismatch.
- **Safe Auto-Accept Group Summons (`DynamicPrep`):** Added an opt-in **Auto-Accept Group Summons** toggle (Off by default) that accepts Warlock / Meeting Stone summons after a `1.5s` out-of-combat countdown (skipped if dead or in combat; hold Shift to cancel).
- **Merchant Quick-Stack Bulk Buy & Smart Auto-Restock (`DynamicBags`):** Added `Alt + Right-Click` full-stack merchant purchasing (`BuyMerchantItem` max stack) and a Smart Vendor Auto-Restock list (`/dbag restock <itemID or link> <qty>`, `list`, `clear`) that automatically tops up configured vendor supplies on `MERCHANT_SHOW`.
- **Automatic `!keys` Keystone Chat Responder (`DynamicGroup`):** Added zero-taint Party / Raid / Instance and Guild chat listeners (guarded with `issecretvalue()` and a `10s` per-channel cooldown) that automatically link your owned Mythic+ Keystone when someone types `!keys` or `!key`.

### DynamicSuite Core & Lockstep Metadata (`v2.5.0`)
- **10-Module Suite Integration:** Added `DynamicVaultDB` to `DynamicSuite.toc`, wired `vault` / `DynamicVault` into the `/ds` Left Suite Rail, custom `32x32` monochrome vector icon `icon_mod_vault.tga`, standalone `Packaging\StandaloneTOCs\DynamicVault.toc`, and synchronised all 11 `.toc` manifests and version fallbacks to `2.5.0`.

---

## DynamicSuite & All 9 Modules v2.4.0 (18/11/2026)

### DynamicMail (New Module `/dmail`, `/dynamicmail`)
- **Smart 1-Click Inbox Collection & Empty Letter Cleanup (`DynamicMailInboxBar`):** Docked an Obsidian action strip cleanly above Blizzard's `MailFrame` header (auto-flipping below the bottom tabs only if near the top of your screen) with **Open All**, **AH Gold**, **Items**, **Clear Empty**, and **Stop** buttons plus live unread/mail count, Expiring (`<3d`) mail alerts, and gold-in-inbox Coin telemetry. Includes an **Auto-Delete Empty Letters on Open All** setting (enabled by default) and dedicated 1-click **Clear Empty** pass to delete empty NPC notices (Lost Currency, Postmaster), Auction receipts, and zero-gold/zero-item letters without opening each one manually while always protecting COD, items, gold, and GM mail; supports optional `Shift + Left-Click` inbox row quick-loot, respects configurable free general bag-slot reserves (`0-8` slots, default `1`), continues collecting Auction House gold when bags are full (configurable), and prints a clean Coin summary when finished.
- **4-Tab Obsidian Recipient Picker (`Alts` / `Recent` / `Guild` / `Friends`) & Pending Alt Mail Badges:** Docks cleanly beside `SendMailFrame` (automatically dodging `EllesmereUIMailAltList` when active or viewport edges), reading `DynamicBagsDB.vault.characters` and `DynamicMailDB.knownChars` so all account alts appear automatically with class colours, cross-realm normalisation, cached gold balances, `Sent` mail-waiting badges (cleared automatically once that alt opens any mailbox), search filtering, and `*` Favourite pinning. Also includes a **Mailbox Overlay Skin** option (`Auto-Match` adapts to `EllesmereUIBlizzardSkin` / `ElvUI`; `Suite Obsidian` keeps DynamicSuite dark chrome).
- **Smart Bulk-Attach Presets, Quick Gold & Express Multi-Attach (`Alt + Left-Click`):** Added 1-click Quick-Attach buttons (`+ Mats`, `+ BoE`, `+ Warband`, `+ Same`) in the Send Mail drawer (and `/dmail mats`, `boe`, `warband`, `same`) guarded against Soulbound items, refundable purchases, Quest items, and Blizzard Equipment Manager sets; Quick Gold increment pills (`+1k g`, `+10k g`, `+100k`, `Clear G`) with postage safety cap; `Alt + Left-Click` bag-item attaching across both `DynamicBags` and Blizzard bag slots regardless of `ActionButtonUseKeyDown`; optional empty Subject auto-fill; a 1-click `Clear` queue button; lifetime gold/item telemetry; Suite-matched 3-tab bevel workspace chrome (`#0B0D12` top bar, `#14171F`/`#252A36` bordered tabs, `4px` scrollbar); and full `Guided Setup` (10 steps) + `Global Smart Search` + `Postal` / `EasyMail` / `TradeSkillMaster` conflict integration.

### DynamicSuite Core, `DynamicPrep`, `DynamicFPS`, `DynamicLoad` & `DynamicBags`
- **Delves Difficulty Picker Fix, Delve Zone-In Lag Elimination & Desktop Window Manager Master Switch (19/11/2026):**
  - **Restored `ProfessionsFrame` Flyouts, Specialization Tabs & Quality Meter Indicator:** Stopped Core `DesktopWindows` from elevating Blizzard windows to `DIALOG` strata (capped at `HIGH` focused / `MEDIUM` unfocused) and added `NATIVE_LAYER_FRAMES` protection for `ProfessionsFrame`, `ProfessionsCustomerOrdersFrame`, and `ProfessionsBookFrame` so Blizzard's native `FrameStrata` & `FrameLevel` hierarchy stays untouched -- restoring `+` Finishing Reagent / Salvage item flyouts, Specialization tree tabs, and the Crafting Quality / Concentration vertical bar indicator.
  - **Restored `DelvesDifficultyPickerFrame`:** Removed `DelvesDifficultyPickerFrame` from Core `DesktopWindows` management (added to `EXCLUDED_BLIZZ_FRAMES`) so it is never detached from `UIPanelWindows` or re-leveled/re-layered, and hardened `DynamicPrep`'s `GOSSIP_SHOW` handler to immediately skip custom gossip UIs (`textureKit` string payloads such as `"delves-difficulty-picker"` and active Delve frames).
  - **Eliminated Delve Zone-In Stalls:** Coalesced and deferred `DynamicFPS` zone-change graphics CVar writes (`0.45s` single pass per zone context) so back-to-back `PLAYER_ENTERING_WORLD` + `ZONE_CHANGED_NEW_AREA` events no longer trigger duplicate synchronous DirectX pipeline rebuilds during loading screens, and gated `DynamicSuite_Core` full-addon conflict scans / `DynamicLoad` frozen-addon enforcement to initial login/reload (`isInitialLogin` / `isReloadingUi`) instead of running on every Delve zone-in.
  - **1-Click Desktop Window Manager Master Switch:** Added an **Enable Blizzard Desktop Window Manager** master toggle (`Off` / `Enabled`) at the top of `/ds` -> **Suite Studio** -> **Desktop Windows & Menus** so users can turn off Side-by-Side, Drag Anywhere, and Ctrl+Scroll Scaling in one click (leaving Blizzard frames 100% unhooked after `/reload`).
- **9-Module Architecture, Left Suite Rail & Stuck Bag-Lock Fix (`v2.4.0`):** Added `mail` to `DynamicSuite_UI.lua`'s `DEFAULT_MODULE_KEYS` Left Suite Rail order (with automatic fallback appending any newly registered suite modules), `DynamicMailDB` SavedVariables, `Modules\DynamicMail.lua`, standalone `Packaging\StandaloneTOCs\DynamicMail.toc`, custom `32x32` monochrome vector icon `icon_mod_mail.tga`, `Alt + Left-Click` slot hook and `MAIL_CLOSED` / `ShowWindow()` `RefreshAllSlotLocks()` fix in `DynamicBags.lua` so dragged or attached bag icons never remain greyed out after closing the mailbox, and synchronised all 10 `.toc` manifests and version fallbacks to `2.4.0`.

---

## DynamicSuite & All 8 Modules v2.3.2 (18/11/2026)

### DynamicSuite Hub & Core (`DesktopWindows`)
- **Proactive `DecorVendor` `/tm` Taint Quarantine & Obsidian Modal (18/11/2026):** Promoted `DecorVendor` (`Decor Vendor`) to a Tier-1 `HARD` conflict under `DynamicMarker` across `DynamicSuite` and standalone `DynamicMarker`, and added a Midnight Pitch Black (`#06070A`-`#090A0D`) Obsidian warning modal (`Raid Marker Blocked by Addon Conflict`, safely deferred until out of combat) whenever `DecorVendor` is active on login/reload or whenever World of Warcraft blocks `SetRaidTarget()` / `SetRaidTargetIcon()`. Includes a 1-click `Disable <Addon> (Set to Never)` button (disabling the addon and locking it to `Never` across all `DynamicLoad` zone profiles), a session-throttled `Dismiss` button, and clear plain-English guidance to completely Exit & Restart World of Warcraft (`/reload` alone does not clear Blizzard's raid-marker lockout).
- **Post-Combat `MacroFrame` Protection & Automatic Icon Grid Refresh (18/11/2026):** Marked the Blizzard Macros window (`MacroFrame`) as combat-protected in `DesktopWindows` so opening or viewing Macros during combat never detaches, moves, rescales, or hides the window, and automatically refreshes the macro selector list and icon grid when combat ends (`PLAYER_REGEN_ENABLED`) so all General and Character-Specific macro icons reappear cleanly across `DIALOG`/`HIGH` focus transitions and ElvUI Blizzard skinning without switching tabs or reopening the window.
- **Universal Mousewheel Scrolling Across All 32 Managed Blizzard Desktop Windows (18/11/2026):** Restored smooth normal mousewheel scrolling across Collections, Achievements, Professions, Macros, Character/Reputation, Adventure Guide, Talents & Spellbook, and all 32 managed Blizzard panels by restricting `Ctrl+Scroll` session scaling to the `28px` top title bar and activating the window-wide `Ctrl+Shift+Scroll` permanent scale overlay strictly while `Ctrl+Shift` is held.

### DynamicMarker
- **Proactive `DecorVendor` `/tm` Quarantine Modal & Tier-1 Conflict Protection (18/11/2026):** Promoted `DecorVendor` (`Decor Vendor`) to a Tier-1 `HARD` conflict across Guided Setup, module conflict banners, and standalone `DynamicMarker`, and mirrored the Midnight Pitch Black (`#06070A`-`#090A0D`) `Raid Marker Blocked by Addon Conflict` Obsidian modal across bundled and standalone modes on login/reload and `ADDON_ACTION_FORBIDDEN` (`SetRaidTarget()` / `SetRaidTargetIcon()`) with 1-click `Disable <Addon> (Set to Never)`, combat deferral, session `Dismiss` throttling, and full game-restart instructions.

### DynamicBags
- **1-Click Housing Decor Non-Tradeable Confirmation Handling (18/11/2026):** Clicking `Open (N)` or scrolling `Alt+MouseWheel` now uses and confirms refundable/trade-timer Housing Decor items in a single click out of combat (supporting Retail 12.1.5 pooled `StaticPopup` dialogs, `END_BOUND_TRADEABLE`, and `USE_NO_REFUND_CONFIRM` while keeping `Open (N)` ready whenever a background auto-open requires a hardware click and strictly ignoring manual bag clicks, dungeon/raid loot rolls, and non-Decor items).
- **Mousewheel Scrolling Fix in `DynamicBags` & `DynamicBank` (18/11/2026):** Restored smooth mousewheel scrolling across `DynamicBags`, `DynamicBank` (Personal, Warband, and Guild Bank), and settings scroll areas whenever `Ctrl+Shift` is not held while keeping `Ctrl+Shift+Scroll` permanent window scaling and `Ctrl+Scroll` header session scaling intact.

---

## DynamicSuite & All 8 Modules v2.3.1 (18/11/2026)

### DynamicSuite Hub & Core (`DesktopWindows`)
- **`DIALOG`-vs-`HIGH` Strata Focus (Zero Cooldown Manager Bleed-Through), Item Socketing `ESC` Close & Adventure Guide Mousewheel Fix:** Placed the active focused panel on `DIALOG` strata and unfocused panels on `HIGH` strata (with `SetToplevel` disabled, zero C++ `Raise()` calls, and root `FrameLevel` clamped to `1`) so Cooldown Manager icons never bleed through; marked session-bound interaction panels (`ItemSocketingFrame`, `TradeFrame`, `GossipFrame`, `QuestFrame`, `ItemUpgradeFrame`, `ItemInteractionFrame`) as non-restorable so `ESC` closes them cleanly without ghost shells; and fixed `EncounterJournal` (Adventure Guide) mousewheel scrolling while preserving `Ctrl+Scroll` / `Ctrl+Shift+Scroll` scaling.

### DynamicMarker
- **Runtime `/tm` Taint Listener, `DecorVendor` Conflict Registry Coverage & `[DynamicMark]` Macro Note (18/11/2026):** Registered `ADDON_ACTION_FORBIDDEN` for `SetRaidTarget` calls in both bundled `DynamicSuite` and standalone `DynamicMarker` with 30-second per-addon rate-limited plain-English chat alerts naming the offending addon and instructing the user to disable it (or keep for Outdoor Housing only) and completely exit and restart the game client (`/reload` alone will not clear Blizzard's raid-marker lockout); registered `DecorVendor` (`Decor Vendor`) across `CONFLICT_REGISTRY.DynamicMarker`, `FRIENDLY_CONFLICT_NAMES`, `CONFLICT_ADDONS`, and `ADVISORY_CONFLICT_ADDONS` with 1-click `Outdoor Housing Only` and `Disable DecorVendor` (`Never` in `DynamicLoadDB`) resolutions across Guided Setup, `/ds conflicts`, the `DynamicMarker` conflict banner, and standalone `DynamicMarker` (with persistent `Dismiss`); and updated the `[DynamicMark]` `Macro Setup` troubleshooting note in plain Australian English.

### DynamicBags
- **Clean `ESC` & `B` Keybind Window Closing & Escape-First Search Clear:** Removed raw `EnableKeyboard(true)` / `OnKeyDown` capture and the conflicting `GameMenuFrame:HookScript("OnShow", ...)` hack from `U.EnsureWindow()`, compacted `nil` holes/duplicates out of `UISpecialFrames` across `DynamicBags.lua` and `DynamicSuite_Core.lua`, coordinated strict top-most one-window-at-a-time Escape priority (`DynamicBagsBankFrame` -> `DynamicBagsFrame` -> `DynamicBagsStandaloneFrame` -> `DesktopWindows` Blizzard panels -> `GameMenuFrame`), preserved Escape-first search clearing, and added a `CloseSpecialWindows` + `ToggleGameMenu` failsafe while keeping two-way `B` toggling working before and after `ESC`.

---

## DynamicSuite & All 8 Modules v2.3.0 (16/11/2026)

### DynamicSuite Hub, Suite Studio & HUD Edit Mode
- **2-Tab `Suite Studio` (`Theme & Typography` + `Desktop Windows & Menus`) & `/ds windows`:** Upgraded the Left Suite Rail `Suite Studio` workspace (`/ds studio`) into a 2-tab studio with `Tab 1: Theme & Typography` (`/ds theme`) and `Tab 2: Desktop Windows & Menus` (`/ds windows` or `/ds win`), housing the Core Blizzard Desktop Window Manager alongside Game Menu & Options Shortcuts and a calm status banner when yielding to external frame-mover addons.
- **Core MS-Windows-Style Blizzard Desktop Window Manager (32 Panels & Windowed Quest Log `L`):** Promoted the Blizzard Desktop Window Manager into `DynamicSuite` Core (`_G.DynamicSuite.DesktopWindows`, saved in `DynamicSuiteDB.global.desktopWindows` with automatic one-time migration from `DynamicPrepDB`) so side-by-side Blizzard windows work even when `DynamicPrep` is disabled. Expanded support to 32 Blizzard panels including the windowed Quest Log / `WorldMapFrame` (`L`) out of combat (skipping overrides when the map is maximised), added modifier-free Left-Click dragging from any empty window background or title bar without needing `Alt` (guarded via `GetMouseFoci()` so buttons, talent nodes, sliders, and inputs are never hijacked), enforced scale-aware `ClampDesktopWindowOffset` on-screen boundary clamping across `OnShow`, `OnSizeChanged`, scaling, and `UI_SCALE_CHANGED` so no panel can ever spawn or get stuck off-screen, and added `GLOBAL_MOUSE_DOWN` click-to-raise z-order (`Raise()`) with top-most `UISpecialFrames` sorting so pressing `Escape` always closes the front-most window one at a time.
- **Item Socketing Esc Close, `DIALOG`-vs-`HIGH` Click-to-Front Strata Focus (Zero Cooldown Manager Bleed-Through), and Adventure Guide Mousewheel Scrolling Fixes (18/11/2026):** Marked session-bound interaction panels (`ItemSocketingFrame`, `TradeFrame`, `GossipFrame`, `QuestFrame`, `ItemUpgradeFrame`, and `ItemInteractionFrame`) as non-restorable in the Blizzard Desktop Window Manager so closing them immediately clears them from the open-panel snapshot and focus stack without ever re-showing an empty ghost window during `Escape` or coexistence passes (pressing `Escape` once while socketing from Character Info cleanly closes Item Socketing, and pressing `Escape` a second time closes Character Info, with an empty-session guard keeping Item Socketing hidden if `GetSocketItemInfo()` is nil); placed the active focused panel on `DIALOG` strata and all unfocused open panels on `HIGH` strata (with `SetToplevel` disabled, zero C++ `Raise()` calls, and root `FrameLevel` clamped to `1`) so whichever window you click or open always sits completely on top of every other panel -- preventing `CharacterFrame` gear slots (`101`), `EllesmereUI` stats panes (`50`), `TalentLoadoutManager` overlays, or `PlayerSpellsFrame` children from interleaving across windows while keeping `MEDIUM`-strata Cooldown Manager icons strictly underneath both focused and unfocused panels; and stopped root `EncounterJournal` (Adventure Guide) and passive border chrome from capturing unmodified mousewheel events while ensuring its active scroll containers stay wheel-enabled out of combat (when not yielding) and preserving `Ctrl+Scroll` / `Ctrl+Shift+Scroll` scaling via a modifier-only overlay whenever `Ctrl` is held.
- **Desktop Window Coexistence, Strata-Based Focus, Character Sheet Pane Visibility, Spellbook Tab Memory & Free Dragging (18/11/2026):** Eliminated client freezes, buried Character Info left/right panes (both stock Blizzard gear slots/model at `FrameLevel 101` and `EllesmereUIBlizzardSkin` right-side Character Stats at `FrameLevel 50`), and talent tree/sidebar blanking by disabling `SetToplevel` and removing C++ `Raise()` calls that jumped root window backgrounds to `FrameLevel 5020` above third-party `5000`-level frames, clamping any stray `FrameLevel > 15` back to `1`, and managing z-order cleanly via strata focus (`HIGH` for the active window, `MEDIUM` for background windows) without synthetic frame-level inflation, `SecureHandler` wrapper overhead, or `UpdateUIPanelPositions` re-anchor loops; ensured Character Info (`C`) keeps its right-side stats pane expanded and refreshed on open whenever not collapsed by the user; detached side-by-side panels cleanly without ever hiding already-open frames; fixed Spellbook tab selection getting forced back to Talents when opening `C`, `I`, or `L`; stopped `C` from getting pushed next to Group Finder (`I`) or locked in place and fixed dragging across stats and background panes; kept Adventure Guide boss loot lists intact, Guild & Communities and Group Finder taint-free, and fullscreen World Map untouched; added one-window-at-a-time reverse-order `Escape` closing both in and out of combat; routed `Ctrl+Scroll` (session 5% scaling) and `Ctrl+Shift+Scroll` (permanent 5% scaling); and ensured Right-Click header resets and `Reset Window Defaults` persist cleanly across `/reload`.
- **Central Popover Auto-Close Registry & Suite-Wide 3-Way Interactive Obsidian Scrollbars:** Added `UI.RegisterPopupCloser(key, closeFn)` in `DynamicSuite_UI.lua` and hooked `OnHide` across every dropdown and popover owner button in all 8 modules so closing, minimising, switching tabs or modules, or entering HUD Edit Mode cleanly dismisses any open dropdown or popover. Upgraded all scrollbars across `Suite Studio`, `Global Smart Search`, `Guided Setup`, dropdown popovers, and all 8 modules (`DynamicLoad`, `DynamicPrep`, `DynamicMarker`, `DynamicZoom`, `DynamicFPS`, `DynamicGroup`, `DynamicBags`, and `DynamicChat`) to full 3-way `4px` Obsidian interaction: Mousewheel scrolling, Left-Click & Drag on the `Button` thumb (with `IsMouseButtonDown("LeftButton")` release guard, `OnHide` cleanup, and Suite Accent hover/drag highlight), and Left-Click on the track to jump directly to the cursor position.
- **HUD Edit Mode `Apply All` Appearance Action:** Added a compact `#0B0D12` / `#F97316` `Apply All` button on Row 3 of the HUD Edit Mode Inspector dock (with 1:1 parity in standalone `DynamicMarker`) that copies the active HUD's Opacity and Border Style across all 6 suite HUDs (`Alert Toast`, `Prep Bar`, `Raid Buffs`, `Focus Icons`, `World Flares`, and `Chat Frame`), updates SavedVariables, and refreshes all HUD frames live.

### DynamicMarker
- **Runtime `/tm` Taint Listener & `DecorVendor` Compatibility Guard (18/11/2026):** Registered `ADDON_ACTION_FORBIDDEN` on `DynamicMarker` for `SetRaidTarget()` / `SetRaidTarget` (ignored when `DynamicMarker` is disabled in `DynamicSuite`, zero `StaticPopup` or frame mutations) to print a 30-second per-addon rate-limited plain-English chat alert naming the offending third-party addon (such as `DecorVendor`) and advising setting it to Outdoor Only in `DynamicLoad` (`/dl`) or disabling it and reloading the UI; added `DecorVendor` (`Decor Vendor`) to `CONFLICT_REGISTRY.DynamicMarker.softConflicts` / `partialConflicts` with one-click `Outdoor Housing Only` (enabled in Outdoor; disabled in Delves, Dungeons, Raid, and PvP via `DynamicLoadDB`) and `Disable Decor Vendor` + Reload UI actions across Guided Setup and the `DynamicMarker` module banner (plus standalone `DynamicMarker`'s Midnight Pitch Black advisory banner and Guided Setup with `Disable DecorVendor` and persistent `Dismiss`); and updated the `[DynamicMark]` `Macro Setup` troubleshooting note to explain that addons hooking chat or slash commands can block `/tm` until disabled for group content or reloaded.
- **`[DynamicMark]` Macro Template Streamlining & Raid Marker Note:** Removed the redundant `/stopmacro [@focus,noexists]` line from `DM:BuildFocusMarkerMacroBody()` (since `/tm` already gates on `@focus,exists` across all group scopes) and added a concise troubleshooting note in `Macro Setup` explaining that `/tm` requires Raid Leader or Assistant in raids and that a full game restart (not `/reload`) clears Blizzard's intermittent raid-marker lockout bug.

### DynamicLoad
- **One-Click `Copy From...` Zone Profile Action:** Added a compact `Copy From...` button on the `DynamicLoad` toolbar (Dark-Obsidian `#0B0D12` / Blaze Orange `#F97316`) so you can copy another zone's `By Zone` addon selections into the active zone tab in one click while preserving universal `Always` / `Never` locks and protected Suite Core rules.
- **Persistent Parent Addon Tree Collapse State:** Normalised canonical parent collapse keys and preserved collapsed parent addon groups (such as `DBM`, `WeakAuras`, and `Details`) across `/reload` and logins with clear expand/collapse tooltips.
- **980px Toolbar Search Box Clearance:** Tightened `DynamicLoad` action toolbar button widths, padding, and gaps so the `Filter addons...` search EditBox always retains at least `125px` of clean input width at the default `980x680` window size without clipping.

### DynamicBags
- **Auto-Confirm Non-Tradeable Popup for Housing Decor (18/11/2026):** Added a short, scoped Housing Decor confirmation window whenever `DynamicBags` opens or learns a `DECOR` item via `U.RunNextAutoOpenContainer()` or `DynamicBagsQuickOpenBtn` (`Open (N)` click, `Alt+Scroll`, and batch macros), hooking `StaticPopup_Show`, `StaticPopupDialogs["NON_TRADEABLE_ITEM"]`, and visible `StaticPopup1-4` frames out of combat to accept `button1` / `StaticPopup_OnClick` automatically and clear the flag immediately afterwards while strictly ignoring manual bag clicks, dungeon/raid loot rolls, and non-Decor items.
- **`ESC` / `B` Keybind Closure, Top-Most Window Escape Priority & `GameMenuFrame` Failsafe Guard (18/11/2026):** Removed the conflicting `GameMenuFrame:HookScript("OnShow", ...)` hack from `U.EnsureWindow()` and compacted `nil` holes/duplicates out of `UISpecialFrames` across both `DynamicBags.lua` and `DynamicSuite_Core.lua` (`W.CompactUISpecialFrames`); coordinated strict one-window-at-a-time top-most Escape priority (`DynamicBagsBankFrame` -> `DynamicBagsFrame` -> `DynamicBagsStandaloneFrame` -> `DesktopWindows` Blizzard panels -> `GameMenuFrame`); and added a `CloseSpecialWindows` + `ToggleGameMenu` failsafe hook so pressing `ESC` after opening bags with `B` always clears active search first or closes the top-most open bag/bank window cleanly without opening the Options / Game Menu while keeping two-way `B` toggling working before and after `ESC`.
- **Reliable `ESC` / `B` Keybind Closing, `CloseAllBags` & Unfocused Escape-First Search Clear (18/11/2026):** Removed raw `EnableKeyboard(true)` / `OnKeyDown` capture from `DynamicBagsFrame` and `DynamicBagsBankFrame` so `ESC`, `B`, and player keybindings are never swallowed; preserved Escape-first search clearing when focused (`OnEscapePressed`) or when search text is active while unfocused via a combat-guarded `CloseSpecialWindows` post-hook (restoring open bag/bank windows once, clearing both search boxes, and letting the second `ESC` close cleanly via `UISpecialFrames`); and updated `ToggleWindow()` plus hooked `CloseAllBags()` so pressing `B` (`ToggleAllBags` / `ToggleBackpack` / `ToggleBag`) or `CloseAllBags` toggles and closes `DynamicBagsFrame` alongside `DynamicBagsBankFrame` reliably out of combat.
- **Inline Search Clear Button & Escape-First Handling:** Added a compact inline `x` clear button inside both the `DynamicBags` and Unified `DynamicBank` search boxes whenever search text is active, and hooked `Escape` so pressing `Escape` clears the active search filter first (pressing `Escape` again when search is empty closes the window normally).
- **Collapsible Category Section Headers & Shift+Click Collapse/Expand All:** Left-Clicking any virtual category header (such as `Crafting & Reagents`, `Equipment Sets`, or `Miscellaneous`) collapses or expands that section out of combat with a subtle chevron indicator and collapsed item-count summary persisted across reloads in `DynamicBagsDB` (`Alt + Left-Click` opens the category reorder menu). Holding `Shift + Left-Click` on any category header now collapses all expanded categories or expands all collapsed categories at once out of combat.
- **Interactive Bag Space & Junk Value Breakdown Tooltip:** Hovering the bottom-left footer slot readout (`Bags: X/Y | Reagents: X/Y`) displays a per-bag free/total slot breakdown (`Backpack`, `Bag 1`..`Bag 4`, `Reagent Bag`) plus the total vendor sell value of grey/poor-quality items currently in your bags formatted with coin icons.

### DynamicGroup
- **Declined Premade LFG Group Dimming & Badge:** Records `searchResultID` entries whose application status transitions to `declined` or `invitedeclined` for the current search session (cleared on new searches or category changes), dims declined rows to `0.35` alpha, and adds a compact crimson `Declined` indicator inside the top-right status pill so you never accidentally re-apply to a group that already declined you.
- **LFG Search Freshness Tooltip Telemetry:** Records the search timestamp whenever `LFGListSearchPanel_DoSearch` fires and displays `Last Refreshed: Xs ago` inside the LFG Mini-Bar region, M+ score, and group filter tooltips.
- **LFG Application Status Overlays, Top-Right Obsidian `CancelButton` & `/dg testapply` Cycle:** Reskinned `entry.CancelButton` out of combat into a compact `16x16` Dark-Obsidian (`#0B0D12`) / Crimson-Bordered (`#F87171`) `x` pill anchored at `TOPRIGHT (-6, -3)` with `ov.topPill` anchored cleanly to its left (`-4, 0`) so line 1 reads `[REGION / SCORE / 4:59] [x]` and the entire 5-role-icon `Enumerate` row stays 100% untouched; removed `enumFrame:ClearAllPoints()` to preserve Blizzard's dual-anchor `Enumerate` layout via `_dgOrigPoints` with `3px` inter-icon spacing so all 5 role icons render reliably; suppressed Blizzard's inline `PendingLabel` and `ResultLabel` overlays and routed live pending timers (Warm Amber-Gold) and terminal statuses (Crimson `Canceled` / `Declined` / `Expired` / `Timed Out` with `0.35` row dimming) into the top-right status pill; and updated `/dg testapply` (`/dgroup testapply`) to cycle through Pending, Canceled, and Off previews.

### DynamicPrep
- **Paperdoll Missing-Enchant & Empty-Socket Slot Highlights & `/dprep testaudit`:** Extended `ScanEquippedGearEnchantsAndGems()` to track exact equipped slot IDs missing Midnight Season 2 enchants or containing empty gem sockets, hooked `CharacterFrame` / `PaperDollFrame` `OnShow`, `PLAYER_EQUIPMENT_CHANGED`, and `SOCKET_INFO_UPDATE` out of combat to draw a crisp 1px Warm Amber-Gold (`#FBBF24`) border overlay on the matching Blizzard paperdoll slot buttons, and added `/dprep testaudit` (`/dp testaudit`) to preview missing-enchant and empty-socket highlights on Head and Ring 1.
- **Blizzard Desktop Window Manager Relocation & Tab 3 Streamlining:** Relocated the Blizzard Desktop Window Manager (`Keep Blizzard Windows Open Side-by-Side`, modifier-free dragging, `Ctrl+Scroll` scaling, and `[Reset All Windows]`) from `DynamicPrep` Tab 3 into `Suite Studio -> Desktop Windows & Menus` (`/ds windows`) with automatic `DynamicPrepDB` migration and backward-compatible bridge stubs so `DynamicPrep` Tab 3 focuses purely on World, Instance & Survival Automation.

### DynamicChat
- **Low-Glare Obsidian EditBox Dock & Channel-Tinted Focus Bar:** Removed bright white `1 px` outer borders and bright white left bars on `ChatFrame1EditBox` / `ebBar` (`Always Shaded` idle mode now inherits the borderless smoked backdrop cleanly with a subtle `rgba(255, 255, 255, 0.08)` `p.footerDiv` separator hairline and a `2 px` Suite Accent / Slate `#64748B` left indicator bar, while focused typing renders a `#090A0D` (`0.94` alpha) fill with a subtle `1 px` `0.40` alpha channel-tinted border and `2 px` channel-tinted left bar).
- **Embedded `ChatFrame1` EditBox Dock & Zero Position Shift:** Embedded `ebBar` and `ChatFrame1EditBox` directly inside `ChatFrame1`'s own `26px` bottom (or top) bounds and padded `ChatFrame1.FontStringContainer` by `28px` so the newest chat line never overlaps the EditBox; locked `GetCompositeChatInsets()` and `GetVisibleContainerExtents()` to constant (`-leftExt`, `8`, `28`, `-6`) insets regardless of `Always Shaded` vs `Only When Typing` so toggling EditBox shading never shifts `ChatFrame1`'s screen position.
- **10-Chime DynamicSuite Sound Pack & Shared Registry:** Added 10 original 44.1 kHz Stereo Vorbis `.ogg` crystalline bell-pluck chimes (`Spark`, `Pulse`, `Duo`, `Cascade`, `Echo`, `Chime`, `Bloom`, `Dewdrop`, `Ripple`, `Prism`) registered in both `DynamicSuite_Core.lua` and `DynamicChat` Tab 3 dropdowns, and fixed `EnsureDB()` dropdown label persistence across tab switches and `/reload`.
- **Name & Keyword Mention Alerts:** Added Tab 3 controls for automatic character-name detection, comma-separated custom keywords, dedicated Name/Keyword sound pickers, zero-taint accent-highlighted chat callouts, and an optional floating Alert Toast banner (all guarded against Retail 12.1.5 secret strings).
- **Custom Sound File Manager & `/dc mute`:** Added a Tab 3 Custom Sound Files manager for registering `.ogg` and `.mp3` files (blocking `.wav` for Retail 12.1.5 compatibility) under a `CUSTOM SOUNDS` dropdown header, plus `/dc mute` (`/dchat mute`) to toggle chat notification sounds without losing saved chime selections.
- **Chat Typography & Readability (Tab 2) & Precision Sliders:** Added a dedicated `CHAT TYPOGRAPHY & READABILITY` section in `DynamicChat` Tab 2 (`Chat Look & Sidebar`) with live Font Family (defaulting to active Suite Theme Font or any built-in, Blizzard, or SharedMedia/AddOn font), Font Size (`10 px` to `22 px`), Font Outline (`None`, `Thin Outline`, `Thick Outline`), Text Drop Shadow, Line Spacing (`0 px` to `8 px`), and Auto-Fade Old Messages (`2 minutes` vs permanent) controls applied across `ChatFrame1..10`, temporary whisper tabs, and `ChatFrame1EditBox` with `FCF_SetChatWindowFontSize` and `FCF_OpenTemporaryWindow` protection hooks, `/ds search` indexing, and Obsidian Suite `256x26` Sleek Precision Track sliders (`4 px` `#090A0D` track, `6x14 px` blade thumb, mousewheel fine-tuning, and command-prefix tooltips).
- **Font Dropdown Popover, 3-Way Scrollbars, `PrintMsg` & Custom Reload Modal Fixes:** Fixed `OpenFontDropdownMenu` to track `activeDropdownMenu` cleanly with click-catcher dismissal, `TOOLTIP` strata, a `1px` Suite Accent border overlay, `Escape` closing, owner-button `OnHide` auto-close, chevron state sync, and a 3-way interactive `4px` Obsidian scrollbar (matching `DynamicChatSoundDropdownPopover` and `DynamicChatHistoryModal`). Replaced undefined `PrintChat` calls in keyword saving, custom sound actions, and `/dc mute` with `PrintMsg`, and replaced `StaticPopupDialogs["DYNAMICCHAT_RELOAD_PROMPT"]` in `RestoreBlizzardDefaults()` with a custom Dark-Obsidian (`#0B0D12`) / Blaze Orange (`#F97316`) confirmation modal for 100% `StaticPopup`-free parity.

---

## DynamicSuite & All 8 Modules v2.2.1 (16/11/2026)

### DynamicGroup
- **Midnight Season 2 Dungeon Pool & Teleport Spell Fix:** Updated `MIDNIGHT_S2_FALLBACK_SLOTS` and `KNOWN_DUNGEON_BY_MAP_ID` to the live Midnight Season 2 8-dungeon pool (`Altar of Fangs`, `Murder Row`, `Den of Nalorakk`, `The Blinding Vale`, `Voidscar Arena`, `Kings' Rest`, `Temple of Sethraliss`, and `Ruby Life Pools`), removing stale Season 1 / beta names and incorrect BFA teleport IDs (`467553` / `424167`). Prioritised live spellbook `"Path of ..."` name matching before fallback spell IDs so Portal Deck and Owned Keystone Right-Click teleports always cast the correct dungeon teleport.

### DynamicPrep
- **Reliable Auto-Skip Cinematics & Movies:** Replaced the zone-fingerprint cinematic check with immediate `CinematicFrame_CancelCinematic()` + `StopCinematic()` (for `CINEMATIC_START`) and `MovieFrame_StopMovie` (for `PLAY_MOVIE`), each backed by a `0.1s` `C_Timer.After` safety check. Holding any modifier key (`Shift`, `Ctrl`, or `Alt`) lets the cutscene or movie play without skipping.

---

## DynamicSuite & All 8 Modules v2.2.0 (15/11/2026)

### DynamicSuite Hub & Theme Studio
- **SharedMedia-3.0, DBM, EXBOSS, BigWigs, WeakAuras & ElvUI Font and Sound Discovery:** Added a central zero-dependency Shared Media Discovery Hub (`DynamicSuite_Core.lua`) that scans `LibSharedMedia-3.0`, `DBM`, `EXBOSS`, `BigWigs`, `WeakAuras`, and `ElvUI` on `PLAYER_LOGIN`, `1.5s` post-login for late-loading media packs, and whenever opening font/sound selectors. Upgraded `UI.CreateDropdown` and Theme & Font Studio with live substring search filters (shown automatically when lists exceed 12 items), non-clickable grouped headers (`Built-in Suite Fonts`, `Blizzard`, `SharedMedia / AddOns`), `pcall`-guarded per-font preview rendering, and safe runtime fallback to `Expressway` / `Friz Quadrata` if an external font pack is disabled.

### DynamicChat
- **Curated Blizzard Chat Notification Sounds, External Sound Packs & Self-Whisper Alerts:** Replaced the temporary `.wav` sound files and removed `.wav` registration in `LibSharedMedia-3.0` in favour of 7 curated native Blizzard `SOUNDKIT` alerts (`Blizzard Raid Warning`, `Blizzard Whisper`, `Blizzard Battle.net`, `Blizzard Ready Check`, `Blizzard Map Ping`, `Blizzard Auction Bell`, and `Blizzard Quest Complete`) played via `PlaySound` / `PlaySoundFile` on `Master`, `SFX`, or `Dialogue`. Configured Tab 3's `CHAT NOTIFICATION SOUNDS` card (`#0B0D12` / `#F97316`) with `Chat Notification Sounds` (`Enabled`), `Mute Sounds in Combat` (`Off`), and 5 grouped channel rows (`Whisper & Battle.net Whisper` = `Blizzard Whisper`, `Guild & Officer Chat` = `Blizzard Battle.net`, `Party & Instance Chat` = `Blizzard Map Ping`, `Raid & Raid Warning` = `Blizzard Raid Warning`, and `Say & Yell` = `None (Muted)` by default) with automatic migration from legacy `ds_*` / `ex_*` keys. Added runtime `LibSharedMedia-3.0`, `DBM`, `EXBOSS`, `BigWigs`, `WeakAuras`, and `ElvUI` sound discovery with automatic fallback to `Blizzard Raid Warning`, searchable grouped channel sound dropdowns with inline `[>]` preview buttons plus compact `[Play]` buttons, `1.5s` per-channel anti-spam cooldowns, and restored self-whisper alert playback on incoming `CHAT_MSG_WHISPER` / `CHAT_MSG_BN_WHISPER` events while keeping secret-value-guarded self-message suppression active for group and public channels.

### DynamicBags
- **Dual-Mode Ctrl+Scroll Window Scaling, Header Controls Tooltip & Scale-Aware Docked Bank Alignment:** Added matching Blizzard-window scroll scaling (`70%` to `140%` in `5%` steps, guarded out of combat) across `DynamicBagsFrame` and `DynamicBank` (`DynamicBagsBankFrame`, covering Personal Bank, Warband Bank, and Guild Bank). `Ctrl + Mouse Wheel` across the full header bar scales temporarily for the current open session (resetting back to saved scale on close), `Ctrl + Shift + Mouse Wheel` anywhere over the window (header, item grid `ScrollFrame`, or footer) saves the scale permanently (`bagScale` / `bankScale` in `DynamicBagsDB`) across reloads without interrupting normal grid scrolling or `Ctrl + Click` item previews, and `Right-Click` anywhere on the empty header bar (or `Reset DynamicBags`) resets scale to `100%`. Added matching Blaze-Orange (`#F97316`) `DynamicBags Window Controls` / `DynamicBank Window Controls` header mouseover tooltips (auto-hiding on `OnLeave` and `OnDragStart`), displays an auto-fading Dark-Obsidian (`#0B0D12`) / Blaze-Orange (`#F97316`) readout pill (`"Session Scale: N%"` / `"Saved Scale: N%"`), and makes `SaveTopAlignedPos`, `MakeFrameDraggable`, and `ApplyCompanionAnchor` scale-aware so a docked `DynamicBank` stays flush alongside `DynamicBags` at any scale combination.

### DynamicMarker
- **Unbound-by-Default World Flare Keybinds & Guided Setup Assignment:** Removed hardcoded `F4` and `F5` defaults from `DB_DEFAULTS`, `GetStatusText()`, `GetSubTab2Title()`, and `ResetDefaults()` so fresh installs and Resets start with both Cycle World Flare and Clear All Flares keys `"Unbound"` (`""`) -- never overriding a player's own Blizzard or action bar bindings -- while preserving any custom hotkeys already saved in an existing `DynamicMarkerDB` (or imported from FocusMarker). Added clean single-button `Cycle World Flare Keybind` and `Clear All Flares Keybind` capture controls (`"Unbound (Click to Bind)"` / `"[KEY] (Click Rebind)"`) across both Guided Setup flows (DynamicSuite Step 3 & standalone Guided Setup modal) and the World Flare Keys tab (`/dm flares`), where Left-Click captures, `Escape` cancels without losing the current binding, and `Right-Click` (or `Backspace`/`Delete` while capturing) clears to `"Unbound"`.

### DynamicPrep
- **Colour-Coded Food Stat Benefits on Clickable Raid Buffs HUD & Readiness Strip:** Added `FormatColoredFoodBenefit` to colour-code parsed food stats (Mint Teal Primary/Intellect/Agility/Strength, Sky Cyan Haste, Royal Amethyst Mastery, Warm Amber-Gold Critical Strike, Emerald Green Versatility, Blaze Orange Highest Secondary Stat, and Slate-Silver Stamina) across Clickable Raid Buffs food tooltip titles, dedicated `Food Benefit:` summary lines, expiring `Current Buff:` lines, Readiness Strip Slot 3, and capsule tooltips.
- **Secure Blizzard Window Probe Attribute Fix:** Renamed the Blizzard window secure handler probe attribute from `_ds_probe` to `ds_probe` inside `EnsureSecureHandler()` so Blizzard's `RestrictedFrames.lua` attribute name validation passes cleanly on login and `/reload` with zero `Invalid attribute name` Lua errors.
- **Multi-Panel Blizzard Windows ("No Auto-Close" Without Trapping Escape) & Pinned Escape Protection:** Added a Tab 3 toggle (`Keep Blizzard Windows Open Side-by-Side`, enabled by default) covering 31 standard Retail 12.1.5 Blizzard panels (`CharacterFrame`, `InspectFrame`, `DressUpFrame`, `PlayerSpellsFrame`, `PVEFrame`, `WeeklyRewardsFrame`, `CommunitiesFrame`, `FriendsFrame`, `CollectionsJournal`, `WardrobeFrame`, `EncounterJournal`, `ProfessionsFrame`, `ProfessionsBookFrame`, `ProfessionsCustomerOrdersFrame`, `AchievementFrame`, `ItemUpgradeFrame`, `ItemSocketingFrame`, `ItemInteractionFrame`, `MajorFactionRenownFrame`, `DelvesDifficultyPickerFrame`, `ClassTrainerFrame`, `CalendarFrame`, `MacroFrame`, `GossipFrame`, `QuestFrame`, `TradeFrame`, `MerchantFrame`, `MailFrame`, `BankFrame`, `AuctionHouseFrame`, and `AddonList`, with `ADDON_LOADED` and `EventUtil.ContinueOnAddOnLoaded` hooks for all on-demand Blizzard panels). Runs Blizzard's normal `ShowUIPanel` panel/tab initialisation first and then restores any previously open supported windows while freezing their current screen positions in place so opening a new window never shifts or pairs up already-open windows. Each open, unpinned window is registered individually in `UISpecialFrames` and protected across `HideUIPanel`, `CloseWindows`, `CloseAllWindows`, `CloseSpecialWindows`, and `ToggleGameMenu` so pressing `Escape` closes strictly one unpinned window at a time while leaving `Pinned` windows open (whereas clicking `[X]` or pressing the window's keybind toggle still closes them cleanly). Clicking any open window brings it to the front (`Raise()`). Strictly excludes `WorldMapFrame` and `GameMenuFrame` and guards all panel/positioning hooks out of combat (`InCombatLockdown()`) for zero combat taint.
- **Unclamped Native Draggable Blizzard Windows (`TitleContainer`-Cleared Overlay, Header or Alt+Drag Anywhere) & Dual-Mode Header Scroll Scaling:** Added `Draggable Blizzard Windows (Save Position)` and `Window Ctrl+Scroll Scaling` toggles in Tab 3 (both enabled by default) plus a `[Reset All Windows]` button. Elevates the header overlay `+50` frame levels above `TitleContainer` (inset to `(-58, -2)` so Maximize/Minimize buttons remain completely unobstructed on `ProfessionsBookFrame`, `ProfessionsFrame`, `CollectionsJournal`, `EncounterJournal`, and `AuctionHouseFrame`). Dragging a supported header or holding `Alt + Left-Drag` anywhere on a supported window out of combat uses native `StartMoving()` / `StopMovingOrSizing()` with `SetClampedToScreen(false)` so windows can move freely anywhere on or past screen edges without snapping back (restoring default clamping if dragging is turned Off or `[Reset All Windows]` is clicked), persists exact scale-aware unscaled `UIParent` `CENTER` offsets (`ux = (fcX * scale) - ucX`, `uy = (fcY * scale) - ucY`) across reloads, and post-hooks `SetPoint` with a re-entrancy guard so internal Blizzard tab switches never snap moved windows back to default `TOPLEFT` coordinates. `Ctrl + Mouse Wheel` on the header scales temporarily (`70%-140%`, `5%` steps) for the current session only (resetting when closed), `Ctrl + Shift + Mouse Wheel` anywhere on a supported window saves the scale permanently across reloads without chasing the moving header, Right-Clicking a header resets that window back to default position and `100%` scale, and an auto-fading Dark-Obsidian (`#0B0D12`) / Blaze Orange (`#F97316`) pill shows temporary vs saved scale feedback without hijacking window-body scrolling. Also hardened `C_Item.GetItemInfoInstant` and `TooltipDataProcessor` owner lookups across `DynamicPrep` and `DynamicBags` for clean Retail 12.1.5 coexistence alongside third-party addons such as Auctionator.
- **Zero-Config Silent External Frame-Management Coexistence:** Automatically detects at startup, `ADDON_LOADED`, and runtime toggle whether any overlapping Blizzard frame-mover, scaler, or no-auto-close addon (`NoAutoClose`, `BlizzMove`, `DeModal`, `MoveAny`, `EllesmereUI` / `EllesmereUIQoL`, `Leatrix Plus`, or `ElvUI`) is active, silently yielding DynamicPrep's Blizzard window mover, scaler, and no-auto-close hooks out of the box with zero banners inside Tab 3 and surfacing `[Auto-Yield Active]` and override controls exclusively in Guided Setup Step 1 and `/ds conflicts`.
- **Food Item Stat Benefit Tooltips on Clickable Raid Buffs HUD:** Expanded `ParseFoodBenefitFromTooltipText` to support Midnight tooltip phrasing (`gain`, `gaining`, `well fed`, `become well fed`), comma-formatted numbers (`+1,250 Haste`), and `Highest Secondary Stat` (`+445 Highest Sec`). Bag food scanning (`InspectFoodTooltip` / `ScanOwnedFoods`) now caches `statShort` and `statFullLine` from `C_TooltipInfo.GetBagItem` (with `GetItemByID` / `GetSpellByID` fallbacks) and displays the food's exact stat benefit in both the HUD button title (e.g. `Royal Roast (+445 Highest Sec)`) and tooltip body above `"Click to eat..."`.

---

## DynamicSuite & All 8 Modules v2.1.2 (15/11/2026)

### DynamicPrep
- **Midnight Season 2 Enchantable Slot List Fix:** Updated the Durability capsule's equipped gear enchant scanner to remove false-positive missing-enchant alerts on Cloak and Wrist (which do not have enchants in Midnight) and added Head and Shoulder to the Midnight Season 2 enchantable slot list (`Head`, `Shoulder`, `Chest`, `Legs`, `Feet`, `Ring 1`, `Ring 2`, `Main Hand`, and `Off-Hand` weapons excluding shields and held-in-off-hand items), while keeping all `1..18` empty gem socket checks, combat/secret-value guards, and Durability tooltip formatting intact.

---

## DynamicSuite & All 8 Modules v2.1.1 (15/11/2026)

### DynamicSuite Hub & All HUD Modules
- **3-Row `560x110` HUD Edit Inspector & Live Appearance Bar (Row 3):** Upgraded `DynamicSuiteEditModeModal` and standalone `DynamicMarkerEditModeInspector` into a unified `560x110` 3-row draggable inspector dock with live Row 3 appearance controls across all 6 HUDs (`Alert Toast`, `Prep Bar`, `Focus Icons`, `World Flares`, `Raid Buffs`, and `Chat Frame`): an `Opacity` slider (`20%-100%`, step `5%`) that previews opacity live while keeping mover borders sharp via `SetIgnoreParentAlpha(true)`, `Accent` | `Dark` | `None` Border Style pills synced 1:1 with each module's sub-settings, and a `Horiz` | `Vert` Orientation toggle with instant screen-bounds re-clamping for Target Icon Bar, World Flare Bar, and Raid Buffs (cleanly dimmed with a fixed-horizontal tooltip for fixed-layout HUDs). Clicking `[Reset]` now restores default Position, Scale (`100%`), Opacity (`95%` / `25%` for Chat), Border Style (`Accent`), and Orientation (`Horizontal`).
- **First-Open `/ds` Left Rail, Right Workspace Two-Point Anchoring & First-Click `[+ HUD]` Initialisation Fix:** Anchored `leftRail` and `workspace` directly to `DynamicSuiteMainFrame` with explicit `SetSize` fallbacks (`SyncWorkspaceGeometry`), `SetClipsChildren(false)` on outer wrapper containers (`workspace`, `dlView`, `peerModuleHostFrame`), and elevated `FrameLevel` hierarchy so both the Left Suite Rail and Right Workspace (`DynamicLoad` 5-zone tab bar, addon tree, and all peer module pages) always render cleanly on the very first `/ds` open after login or `/reload`. Clicking `[+ HUD]` before `[Back to Suite]` now sets active Edit Mode flags up front, eagerly initialises all 6 HUD frames (`EnsureAllEditModeHudFramesInitialized`), keeps the HUD selector dropdown closed on entry so Row 2 is never obscured, invokes Edit Mode callbacks cleanly, and suppresses construction-time `OnHide` cancellation so all active movers appear on the very first click.
- **HUD Edit Mode Mover Visibility & Independent Drag Shields:** Fixed `isHudEditModeActive` lexical scoping in `DynamicSuite_UI.lua`, split `DynamicPrep`'s `SetBarEditMode` and `SetBuffsEditMode` states, elevated drag shields to `HIGH` strata (`FrameLevel + 50`), and disabled child mouse capture during HUD Edit Mode so every bar drags smoothly across its full width.
- **DynamicChat Vertical Scrollbar & Unified Bottom-Right Corner Resize Grip:** Updated `GetChatScrollMetrics(cf)` to read live wrapped-line scroll range via `cf:GetMaxScrollRange()`, `cf:GetNumVisibleLines()`, and `cf:GetScrollOffset()` (with message/height estimation fallback and `visibleLines / (visibleLines + maxScroll)` thumb sizing) so wrapped chat messages size the scrollbar thumb proportionally and scroll cleanly across the full buffer on drag, track click, and mousewheel; anchored the scrollbar from `TOPRIGHT (6, -2)` to `BOTTOMRIGHT (6, 2)`, promoted it to `ChatFrame` strata (`FrameLevel + 12`), synced `cf.ScrollBar` percentage, and hid inactive docked-tab scrollbars on `FCF_SelectDockFrame`. Unified all bottom-right corner resize grips across `DynamicSuiteMainFrame`, HUD Edit Mode `"CHAT"`, `DynamicChatStandaloneFrame`, `DynamicMarkerSuiteWindow`, `DynamicPrep`, and `DynamicZoom` to `14x14` (`BOTTOMRIGHT -4, 4`) using `UI-ChatIM-SizeGrabber-Up` / `UI-ChatIM-SizeGrabber-Highlight` with `#F97316` Blaze Orange hover styling.

---

## DynamicSuite & All 8 Modules v2.1.0 (15/11/2026)

### DynamicBags
- **Dual-Mode Ctrl+Scroll Window Scaling, Header Controls Tooltip & Scale-Aware Docked Bank Alignment:** Added matching Blizzard-window scroll scaling (`70%` to `140%` in `5%` steps, guarded out of combat) across `DynamicBagsFrame` and `DynamicBank` (`DynamicBagsBankFrame`, covering Personal Bank, Warband Bank, and Guild Bank). `Ctrl + Mouse Wheel` across the full header bar scales temporarily for the current open session (resetting back to saved scale on close), `Ctrl + Shift + Mouse Wheel` anywhere over the window (header, item grid `ScrollFrame`, or footer) saves the scale permanently (`bagScale` / `bankScale` in `DynamicBagsDB`) across reloads without interrupting normal grid scrolling or `Ctrl + Click` item previews, and `Right-Click` anywhere on the empty header bar (or `Reset DynamicBags`) resets scale to `100%`. Added matching Blaze-Orange (`#F97316`) `DynamicBags Window Controls` / `DynamicBank Window Controls` header mouseover tooltips (auto-hiding on `OnLeave` and `OnDragStart`), displays an auto-fading Dark-Obsidian (`#0B0D12`) / Blaze-Orange (`#F97316`) readout pill (`"Session Scale: N%"` / `"Saved Scale: N%"`), and makes `SaveTopAlignedPos`, `MakeFrameDraggable`, and `ApplyCompanionAnchor` scale-aware so a docked `DynamicBank` stays flush alongside `DynamicBags` at any scale combination.

### DynamicMarker
- **World Flare Hardware Keybinds Fix:** Anchored the secure World Flare cycle and clear click buttons (`DynamicMarkerFlareCycleBtn` / `DynamicMarkerFlareClearBtn`) on-screen at `CENTER` (`1x1`, alpha `0`, `EnableMouse(false)`), removed the `"flare" .. m` button override return inside `SecureHandlerWrapScript` so `"LeftButton"` passes cleanly to `SecureActionButton_OnClick` for `/wm [@cursor] <m>` and `/cwm all`, and ensured key-down / key-up CVar parity in and out of combat.
- **Live Keybind Telemetry & Dynamic Sub-Tab Label:** Rebinding, unbinding (Escape or Right-Click), or resetting `Cycle Ground Flare Key` or `Clear All Flares Key` now immediately refreshes the `[Key]` button text, `World Flare Keys (...)` tab label with proportional width reflow, standalone status bar, and DynamicSuite's top telemetry bar (`UpdateHeaderTelemetry()`).

### DynamicSuite Hub & All HUD Modules
- **Compact Draggable `560x74` HUD Edit Inspector & `60px` Off-Screen Fail-Safe:** Redesigned both `DynamicSuiteEditModeModal` and standalone `DynamicMarkerEditModeInspector` into a compact `560x74px` 2-row draggable dock with a HUD Selector Dropdown (green/red status dots), full-padding `Hidden` / `Shown` toggles (fixing `"Hidd..."` clipping), `Grid`, `Reset`, `Back to Suite`, `X`, X/Y coordinates & nudges, `Center X` / `Center Y`, and Scale slider (`60%-150%`). Both Edit docks allow dragging near screen edges while keeping a minimum `60px` grab margin visible, while HUD bars remain strictly clamped inside screen bounds (`0px`).
- **Hidden-By-Default HUD Mover Lifecycle:** Opening HUD Edit Mode (`/ds hud`, `/dm hud`, or top-bar `HUD`) no longer clutters the screen with `Off` / `Hidden` movers or disabled modules; selecting a hidden HUD from the dropdown or clicking a card's `Edit HUD` button temporarily previews only that mover with a clear `HIDDEN (Click Shown to Enable)` badge.
- **Unified HUD Configuration Cards & Standardised `[Edit HUD]` Buttons:** Added consistent Dark-Obsidian (`#0B0D12`) + Blaze Orange (`#F97316`) `Edit HUD` header buttons and aligned shared `ON-SCREEN ALERT & TELEPORT TOAST HUD` controls (Visibility, Border Style, Scale `60%-150%`, Opacity `20%-100%`, `[Test Toast]`, and `[Edit HUD]`) across `DynamicLoad`, Theme & Font Studio, `DynamicGroup`, `DynamicPrep` (`Top Info Bar` & `Raid Buffs`), `DynamicMarker`, and `DynamicChat`.

---

## DynamicSuite & All 8 Modules v2.0.9 (15/11/2026)

### DynamicBags
- **Dual-Mode Ctrl+Scroll Window Scaling, Header Controls Tooltip & Scale-Aware Docked Bank Alignment:** Added matching Blizzard-window scroll scaling (`70%` to `140%` in `5%` steps, guarded out of combat) across `DynamicBagsFrame` and `DynamicBank` (`DynamicBagsBankFrame`, covering Personal Bank, Warband Bank, and Guild Bank). `Ctrl + Mouse Wheel` across the full header bar scales temporarily for the current open session (resetting back to saved scale on close), `Ctrl + Shift + Mouse Wheel` anywhere over the window (header, item grid `ScrollFrame`, or footer) saves the scale permanently (`bagScale` / `bankScale` in `DynamicBagsDB`) across reloads without interrupting normal grid scrolling or `Ctrl + Click` item previews, and `Right-Click` anywhere on the empty header bar (or `Reset DynamicBags`) resets scale to `100%`. Added matching Blaze-Orange (`#F97316`) `DynamicBags Window Controls` / `DynamicBank Window Controls` header mouseover tooltips (auto-hiding on `OnLeave` and `OnDragStart`), displays an auto-fading Dark-Obsidian (`#0B0D12`) / Blaze-Orange (`#F97316`) readout pill (`"Session Scale: N%"` / `"Saved Scale: N%"`), and makes `SaveTopAlignedPos`, `MakeFrameDraggable`, and `ApplyCompanionAnchor` scale-aware so a docked `DynamicBank` stays flush alongside `DynamicBags` at any scale combination.

### DynamicMarker
- **World Flare Hardware Keybinds & Custom Sequence Order:** Fixed Cycle Ground Flare (`F4`) and Clear All Flares (`F5`) hardware keybinds so they fire reliably in and out of combat, walk your saved and enabled World Flare Cycle Sequence in exact custom order via `SecureHandlerWrapScript`, and update the floating World Flare Bar to match your custom sequence order and enabled flares.

---

## DynamicSuite & All 8 Modules v2.0.8 (15/11/2026)

### DynamicGroup
- **Portal Deck Owned Keystone Telemetry & Right-Click Teleport:** Upgraded the Portal Deck's Owned Keystone pill with out-of-combat Right-Click Dungeon Teleport casting, a synced cooldown swipe overlay, and Season Best timed/over-time level and score plus teleport cooldown status in its tooltip while keeping Left-Click exclusive dungeon filtering.
- **Dungeon Joined & Group Full Teleport Toast:** Added an Alert Toast-matched banner with a one-click Dungeon Teleport button, Right-Click dismissal, join chimes, 5/5 group highlight, shared HUD Edit slot with automatic vertical stacking, preview buttons, and `/dg testtoast`.
- **Season Dungeon Portals & 1-Click Dungeon Filter Deck:** Docked portal bar above Premade Groups with your keystone pill and all 8 Midnight Season 2 dungeon tiles, supporting Left-Click / Shift+Left-Click filtering and Right-Click teleport casting.
- **Integrated Multi-Toggle Premade Group Filters:** Added Tank/Healer/DPS role toggles with icons, No Duplicate Class, Has Tank, Has Healer, Bloodlust/Heroism, and Battle Rez in two-way sync with Blizzard's native filter.

### DynamicBags
- **Dual-Mode Ctrl+Scroll Window Scaling, Header Controls Tooltip & Scale-Aware Docked Bank Alignment:** Added matching Blizzard-window scroll scaling (`70%` to `140%` in `5%` steps, guarded out of combat) across `DynamicBagsFrame` and `DynamicBank` (`DynamicBagsBankFrame`, covering Personal Bank, Warband Bank, and Guild Bank). `Ctrl + Mouse Wheel` across the full header bar scales temporarily for the current open session (resetting back to saved scale on close), `Ctrl + Shift + Mouse Wheel` anywhere over the window (header, item grid `ScrollFrame`, or footer) saves the scale permanently (`bagScale` / `bankScale` in `DynamicBagsDB`) across reloads without interrupting normal grid scrolling or `Ctrl + Click` item previews, and `Right-Click` anywhere on the empty header bar (or `Reset DynamicBags`) resets scale to `100%`. Added matching Blaze-Orange (`#F97316`) `DynamicBags Window Controls` / `DynamicBank Window Controls` header mouseover tooltips (auto-hiding on `OnLeave` and `OnDragStart`), displays an auto-fading Dark-Obsidian (`#0B0D12`) / Blaze-Orange (`#F97316`) readout pill (`"Session Scale: N%"` / `"Saved Scale: N%"`), and makes `SaveTopAlignedPos`, `MakeFrameDraggable`, and `ApplyCompanionAnchor` scale-aware so a docked `DynamicBank` stays flush alongside `DynamicBags` at any scale combination.

### DynamicMarker
- **Target Only Focus Macro Clear:** Updated the Target Only `[DynamicMark]` macro template to `/focus [@target,exists,nodead][]` so pressing it with a target sets focus and marks it, while pressing it with no target clears your existing focus target (alongside `Mouseover + Target` and the inline `Manual (Custom)` editor with custom icon preservation).

### DynamicBags & DynamicPrep
- **DynamicBags Auto-Open Expansion:** Automatically opens/learns Soulbound or Warband-bound Gold Pouches, Housing Decor, and Profession Knowledge items out of combat with a clean hardware-click fallback into `Open (N)`.
- **DynamicPrep Midnight Season 2 Updates:** Added Great Vault Mythic+ tooltip telemetry, Right-Click Group Finder access on the Keystone capsule, and out-of-combat equipped gear missing-enchant and empty-gem-socket detection on the Durability capsule.

---

## DynamicSuite & All 8 Modules v2.0.7 (15/11/2026)

### Added
* **Inline Manual Macro Editor & Custom Icon Preservation (DynamicMarker):** In `Manual (Custom)` mode, Sub-Tab 3's `[DynamicMark]` preview becomes a dark-obsidian multi-line EditBox (255-character limit, live character counter, Escape to unfocus) so players can edit `[DynamicMark]` directly inside DynamicMarker and save immediately with `Step 1: Create / Update [DynamicMark]`. Updating an existing `[DynamicMark]` macro now preserves any custom in-game macro icon assigned by the player.

---

## DynamicSuite & All 8 Modules v2.0.6 (15/11/2026)

### Improved
* **Smart Sync & Surgical `/tm` Patching for `[DynamicMark]` (DynamicMarker):** Added 3-way sync handling in `DM:CreateOrUpdateFocusMarkerMacro` for `Manual (Custom)` mode -- passive logins/reloads keep custom macros untouched, changing Focus Icon, Group Scope, or Clear Focus Modifier surgically patches only the `/tm` and `/clearfocus` lines (respecting WoW's 255-character macro limit), the Sub-Tab 3 preview displays your live `[DynamicMark]` body, and `Step 1: Create / Update [DynamicMark]` requires a 2-click confirmation before resetting custom lines.

---

## DynamicSuite & All 8 Modules v2.0.5 (15/11/2026)

### Added
* **Focus Target Mode for `[DynamicMark]` (DynamicMarker):** Added a **Focus Target Mode** segmented pill control (`Mouseover + Target`, `Target Only`, `Manual (Custom)`) in Sub-Tab 3 so players can restrict `[DynamicMark]` to `/focus [@target,exists,nodead]` or preserve custom manual macro edits across logins and reloads.

---

## DynamicSuite & All 8 Modules v2.0.4 (15/11/2026)

### Added
* **Portal Deck Owned Keystone Teleport & Season Best Tooltip (DynamicGroup):** Upgraded the Portal Deck's Owned Keystone pill (`pbar.keyBtn`) with secure Right-Click Dungeon Teleport casting out of combat, a synced cooldown swipe overlay, and Season Best (`+Level (Timed/Over Time) Score`) plus Dungeon Teleport readiness/cooldown telemetry in its tooltip while preserving Left-Click exclusive dungeon filtering.

---

## DynamicSuite & All 8 Modules v2.0.3 (15/11/2026)

### Added
* **Equipped Gear Missing-Enchant & Empty-Socket Detection (DynamicPrep):** Added an out-of-combat gear audit scanner (`ScanEquippedGearEnchantsAndGems`, cached on `PLAYER_ENTERING_WORLD`, `PLAYER_EQUIPMENT_CHANGED`, `SOCKET_INFO_UPDATE`, and `PLAYER_REGEN_ENABLED`) that checks Midnight Season 2 enchantable slots (Chest, Legs, Feet, Wrist, Rings, Cloak, Main Hand, and Off-Hand weapons excluding shields/holdables, skipping levelling and grey/white/heirloom gear) and empty gem sockets across equipped slots 1..18.
* **Durability Capsule Warning Badge & Character Frame Shortcut (DynamicPrep):** Appends a compact amber `!` badge to the `Dur` capsule when missing enchants or empty gem sockets are detected, shows `Enchants:` and `Gems:` status lines in the Durability tooltip, and opens the Character Frame on Left-Click out of combat.

---

## DynamicSuite & All 8 Modules v2.0.2 (15/11/2026)

### Added
* **Great Vault Mythic+ Telemetry & Group Finder Shortcut (DynamicPrep):** Added weekly Mythic+ Great Vault run counts, 1/4/8 run threshold levels, and a green `Reward Ready to Claim!` line to the Top Info Bar Keystone capsule tooltip (guarded with `pcall` and `_IsSecret`), plus Right-Click Group Finder toggling out of combat.

### Improved
* **Aligned Dungeon Abbreviations & Midnight Season 2 Consumables (DynamicPrep):** Aligned `DUNGEON_ABBREVIATIONS` with DynamicGroup's Midnight Season 1/2 dungeon codes (`DON`, `AOF`, `MR`, `VSA`, `FG`, `AK`, `PSF`) and updated Midnight Season 2 consumable item IDs and Rank 2 Gold / Rank 1 Silver mappings while preserving tooltip-scan fallbacks.

---

## DynamicSuite & All 8 Modules v2.0.1 (15/11/2026)

### Improved
* **Unified Auto-Open for Gold Pouches, Housing Decor & Profession Knowledge (DynamicBags):** Expanded the automatic container opener to use/open Soulbound and Warband-bound gold pouches and coin/loot satchels out of combat regardless of `<Right Click to Open>` or `Use:` wording (strictly excluding consumables, potions, flasks, toys, mounts, recipes, and tradeable BoE items).
* **Hardware-Safe Housing Decor & Profession Knowledge Auto-Open (DynamicBags):** Added default-enabled **Auto-Open Soulbound Housing Decor** and **Auto-Open Soulbound Profession Knowledge** toggles under Tab 3 (`AUTO-OPEN & QUICK-OPEN QUEUE`) to automatically learn Soulbound and Warband-bound Housing Decor and Profession Knowledge items (Treatises, Shards, Notes, Curios matching your character's known professions) when bank, vendor, mail, trade, guild bank, and auction house windows are closed. Items requiring a protected spell cast (`C_Item.GetItemSpell` or `ADDON_ACTION_BLOCKED`) stay safely queued in the 1-click `Open (N)` header button, backed by a per-item retry cooldown and session blacklist guard.

---

## DynamicSuite & All 8 Modules v2.0.0 (15/11/2026)

### Added
* **Midnight Season 2 Portal & Keystone Deck (DynamicGroup):** Added a top-docked portal bar above Premade Groups showing your current Mythic+ keystone pill and all 8 active season dungeons with your best timed key levels, dynamically resolving learned Midnight Season 2 teleports from the Mythic+ tab and spellbook. Left-Click toggles the dungeon filter (Shift + Left-Click to solo filter), and Right-Click casts the dungeon teleport out of combat.
* **Integrated Multi-Toggle Premade Group Filters (DynamicGroup):** Upgraded the Group Finder filter menu with Tank, Healer, and DPS role availability toggles (with role icons), No Duplicate Class, Has Tank, Has Healer, Bloodlust/Heroism, and Battle Rez, kept in two-way sync with Blizzard's native Filter menu without altering difficulty checkboxes.
* **Dungeon Joined & Group Full Teleport Toast (DynamicGroup):** Integrated a 410x74 dark-obsidian quick-teleport banner into DynamicSuite's shared Alert Toast HUD Edit slot with mutual toast stacking, join chimes as members enter, an emerald 5/5 ready alert, Right-Click dismissal, **Test Join (3/5)** / **Test Full (5/5)** / **Edit HUD** buttons, and `/dg testtoast`.

### Improved
* **Sleek Premade Group Rows & Tooltips (DynamicGroup):** Replaced separate row badges with a borderless `Region / Leader IO` pill (`OCE`, `USE`, `USW`, `USC`, `LA`, `BR`), added a simplified **Show Region & Leader IO Badge** toggle, aligned uniform desaturated greyscale Tank/Healer/DPS icons with 4px slot spacing over empty group slots, and added personal best key levels plus same-class warnings to group tooltips.

---

## DynamicSuite & All 8 Modules v1.9.9 (14/11/2026)

### Fixed
* **Top & Bottom Screen-Edge Bar Drift:** Focus Icons and World Flare bars parked flush against the top edge, bottom edge, or corners now stay in their exact saved positions after reloading the UI at every bar scale (70%, 100%, and 130%).
* **DynamicLoad Profile Switching & Standalone Scrubbing:** Fixed a Lua error when staging zone profiles (such as Outdoor) in DynamicLoad and ensured saved zone profiles never re-enable standalone DynamicMarker while DynamicSuite is active.
* **Duplicate HUD Edit Windows:** Standalone DynamicMarker's extra HUD Edit popup no longer appears when running DynamicSuite, leaving only the unified bottom HUD Edit dock while keeping standalone HUD Edit Mode intact when run solo.
* **DynamicMarker Reset Bounds:** Resetting HUD positions (`/ds resethud`, `/dm resethud`, or from Options) now resets scale to 100%, restores horizontal layout, and keeps bars cleanly inside your screen bounds.
* **Automatic Standalone Handoff:** Running both DynamicSuite and standalone DynamicMarker together now cleanly disables the standalone copy on launch and prevents duplicate bars or settings conflicts.

### Improved
* **Reliable Dark-Obsidian Coexistence Reload Prompt:** Replaced Blizzard's default popup with a matching dark-obsidian reload modal that reliably appears on entering the world (or right after combat ends) whenever both DynamicSuite and standalone DynamicMarker were enabled at launch.
* **Storefront, Slash Command & Documentation Audit:** Verified all 24 slash commands across modules, removed retired aliases from public documentation and in-game changelogs, and aligned the README, CurseForge pages, and release notes with live behaviour.
* **Plain-English UI & Reset Prompt Polish:** Rewrote the Restore Blizzard Defaults card, reset confirmation dialogs, and module tooltips across DynamicSuite and standalone DynamicMarker in clear, jargon-free Australian English that fits cleanly without truncation.

---

## DynamicSuite & All 8 Modules v1.9.8 (14/11/2026)

### Fixed
* **Edge-Dragged Marker & Flare Bars:** Target Icon and World Flare bars dragged to screen edges at smaller scales (such as 70% or 75%) no longer jump inward on mouse release or after reloading the UI.
* **Flush Bottom-Left Chat Positioning:** DynamicChat now sits completely flush against the bottom-left corner at X = 0, Y = 0 with no ~30px gap across Edit Mode toggles, scale changes, and reloads.

### Improved
* **Release Channel Packaging:** Streamlined automated CurseForge release packaging across both DynamicSuite and standalone DynamicMarker.

---

## DynamicSuite & All 8 Modules v1.9.7 (14/11/2026)

### Added
* **Official Dual CurseForge Support:** Full DynamicSuite is now live on CurseForge alongside standalone DynamicMarker, with direct cross-links in both Support panels.

### Fixed
* **Load-Order Coexistence:** All 8 modules cleanly defer to the newer version if standalone and suite installs are present at the same time, regardless of load order.

---

## DynamicSuite & All 8 Modules v1.9.6 (14/11/2026)

### Added
* **Magnetic HUD Snapping & Alignment Guides:** Bars now snap cleanly to screen edges, screen centres, and neighbouring HUD bars with live alignment lines (hold Shift to fine-tune freely).
* **HUD Reset Failsafe:** Added Reset HUD Positions in Blizzard Options alongside `/ds resethud` and `/dm resethud` (safely deferred if used in combat).
* **More Bag Commands:** Added `/dbag` shortcuts for merge, clear, bank, warband, guild, and help.

### Fixed
* **Zero-Flash Bank & Guild Bank:** Blizzard's default Bank and Guild Bank frames no longer flash briefly when opening DynamicBank after a reload.
* **Guild Bank Tab Snapshots & Sorting:** Unqueried Guild Bank tabs keep their saved item snapshots across reloads while queried tabs update live down to 0 items, A-Z sorting handles uncached items cleanly, and stack splitting works smoothly across specialised bags.
* **Auto-Repair, Auto-Sell & Fast Loot:** Synchronised Tab 3 merchant automation toggles, guarded fast auto-loot bursts, and updated delete-confirmation auto-fill for Retail 12.1.5.

### Improved
* **Standalone Changelog Viewer:** Standalone DynamicMarker's Changelog modal now scrolls through full release notes with colour-coded badges matching DynamicSuite.

---

## DynamicSuite & All 8 Modules v1.9.5 (14/11/2026)

### Added
* **Standalone Window Controls & Copyable Support Links:** Added Window Opacity (50%-100%), Scale (80%-120%), a Reload UI button, and click-to-copy support links to standalone DynamicMarker.
* **Marker Slash Aliases:** Added `/fm` and `/focusmarker` aliases alongside `/dm`, plus `/dm help` and bar lock toggling via `/dm lock`.

### Improved
* **Cleaner Footer Resize Grip:** Replaced the text resize grip with Blizzard's native corner resize icon and added clean spacing next to the Reload UI button.

---

## DynamicSuite & All 8 Modules v1.9.4 (14/11/2026)

### Fixed
* **First-Open Options Launcher:** Opening DynamicSuite or standalone DynamicMarker from ESC > Options > AddOns now renders the full sidebar, workspace, and theme cleanly on the very first open.

---

## DynamicSuite & All 8 Modules v1.9.3 (14/11/2026)

### Fixed
* **Guided Setup Modal Layering:** Fixed underlying window controls bleeding through the Guided Setup modal in standalone DynamicMarker.

### Improved
* **Standalone Theme & Sidebar Parity:** Added all 4 dark surface themes and matching sidebar card spacing to standalone DynamicMarker.

---

## DynamicSuite & All 8 Modules v1.9.2 (13/11/2026)

### Added
* **Standalone & Bundled DynamicMarker HUD Edit Mode Parity:** Unified Target Icon Bar and World Flare Bar Edit Mode movers, magnetic snapping, mousewheel scaling (60%-150%), Shift+Right-Click per-bar reset, and combat/Escape exit protection across both DynamicSuite and standalone DynamicMarker (`/dm hud`).
* **One-Time FocusMarker Settings Import:** Automatically detects existing FocusMarker settings at launch (covering both older and newer layouts) and imports bar positions, scales, visibility rules, and icon/flare order without altering your original FocusMarker data.
* **Automatic CurseForge Release Packaging:** Added automated build and release configuration separating full 8-module DynamicSuite from standalone DynamicMarker.

### Improved
* **Standalone DynamicMarker Shell & Options Launcher:** Hid unused module slots when running standalone, added ESC > Options > AddOns quick-launch cards with Amber/Gold dark-obsidian styling, fixed Guided Setup backdrop dimming and text clipping, and matched sidebar tools, changelog, and support views 1:1 with DynamicSuite.

---

## DynamicSuite & All 8 Modules v1.9.1 (13/11/2026)

### Added
* **Two-Tier Conflict Resolution Engine:** Upgraded the Guided Setup Conflict Scanner (Step 1) with a scrollable card list, accurate sidebar ! badge counts, Hard Exclusivity choices ("Use Dynamic[Module] Only" vs "Use [Addon] Only") for full-replacement bag, chat, LFG, camera, and marker addons, and Granular Overlap choices for narrative, tooltip, and QoL companions.
* **Uninstall Prep & Restore Blizzard Defaults:** Added a two-option Reset menu at the bottom-left of DynamicSuite (Reset Settings Only vs Restore Blizzard Defaults) plus matching per-module restore controls in DynamicFPS, DynamicZoom, DynamicChat, and DynamicBags.

### Fixed
* **Graphics Settings 1:1 Sync in DynamicFPS:** Synchronised Texture Resolution, View Distance, Environment Detail, Ground Clutter, Particle Density, and Spell Density sliders and pills with Blizzard's Graphics menu across both normal and raid profiles.
* **DynamicLoad Core Protection & Disable Confirmation:** Simplified the DynamicSuite and standalone DynamicLoad rows to clear Always / Never buttons, added a theme-matched "Disable & Reload UI" confirmation prompt, fixed tree-list startup errors, and restored draggable changelog scrollbars.
* **Auto-Hiding Chat Scrollbars & Responsive Auto-Gossip:** Skinned chat scrollbars now stay hidden when idle and fade in cleanly on hover or scrolling, while single-option Auto-Gossip now works reliably on interactive world objects (hold Shift to bypass).
* **Unified Target Whisper Shortcut:** Streamlined target whispering onto `/ww` across all chat and whisper tabs (including self-whisper testing), with `/lg` dedicated to leaving your group quickly.

---

## DynamicSuite & All 8 Modules v1.9.0 (12/11/2026)

### Added
* **FocusMarker Snapshot & Re-Import Commands:** Added `/dm import` and `/dm import status` so you can re-import captured FocusMarker settings anytime out of combat, even after FocusMarker is disabled.
* **Guild Bank Daily Withdrawal Counters:** Each Guild Bank tab now shows a colour-coded badge with your remaining item withdrawals for the day while at the bank.

### Fixed
* **Single-Option Auto-Gossip & Dialogue Chains:** Fixed single-option Auto-Gossip not triggering on everyday NPCs and multi-step quest/dungeon dialogues, while preventing repeated double-clicks in the same conversation.

---

## DynamicSuite & All 8 Modules v1.8.0 (12/11/2026)

### Added
* **Flexible Window Dragging & Combat Collapse Pill (`/ds`, `/ds reset`):** Drag the DynamicSuite window partially off-screen while keeping the top title bar reachable; entering combat cleanly collapses an open settings window into a small clickable combat pill and restores it afterwards.

### Fixed
* **Guild Bank Uncached Items & Permission Badges:** Prevented errors when opening Guild Bank tabs whose items are still loading from the server, and added clear view-only protection badges and tooltips.

### Improved
* **Plain-English UI Clarity Across All 8 Modules:** Replaced technical wording across settings cards, tooltips, and status bars with clear, everyday player terminology.

---

## DynamicSuite & All 8 Modules v1.7.3 (12/11/2026)

### Fixed
* **Flush Bottom-Left Chat Anchoring:** Stopped WoW's default screen-clamping margins from pushing DynamicChat ~18px inward from the bottom-left corner after UI reloads, and migrated legacy saved chat positions to exact (0, 0) bottom-left alignment while keeping your saved size.

---

## DynamicSuite & All 8 Modules v1.7.2 (12/11/2026)

### Fixed
* **Container-First Chat Positioning & Edit Mode Recovery:** Anchored the outer smoked-glass chat container first at (0, 0) bottom-left so tab headers, borders, and input boxes never drift apart after reloads or Blizzard Edit Mode changes.
* **Open-World & Instance Object Auto-Gossip:** Expanded single-option Auto-Gossip to interact smoothly with standard speech-bubble NPCs and world objects (hold Shift to bypass).

---

## DynamicSuite & All 8 Modules v1.7.1 (12/11/2026)

### Fixed
* **Raid Buff Scanner Error Fix:** Fixed a script ordering issue during raid buff scanning in DynamicPrep and hardened group buff checks for Midnight 12.1.5 combat restrictions.

---

## DynamicSuite & All 8 Modules v1.7.0 (12/11/2026)

### Added
* **Off-Screen Hub Dragging & Combat-Safe View:** Added flexible screen-edge dragging with `/ds reset` to recentre the hub, combat auto-collapse pills, and a safe read-only combat view when opening `/ds` mid-fight.
* **FocusMarker Settings Import in Standalone & Suite:** Connected legacy FocusMarker saved settings to DynamicMarker's setup and manual Import from FocusMarker button.
* **Restore Blizzard Defaults Tool:** Added pre-addon graphics/camera/chat/bag snapshots so you can cleanly revert game settings before uninstalling.
* **Sleek Dark Scrollbars for Chat & History:** Added custom mouseover-friendly dark scrollbars to skinned chat frames and the full Chat History modal.

### Fixed
* **Simplified Target Whisper Commands:** Dedicated `/ww` strictly to instant target whispering (with `/lg` for quick group leave and `/rl` for quick UI reload), updating all labels, Smart Search entries, and Guided Setup copy accordingly.
* **Conflict Toast, Sidebar Performance & Left-Rail Fixes:** Restored the login conflict notification with a 1-click Resolve shortcut, cached conflict badges so switching sidebar modules is instantaneous, cleaned up `/reload` first-click errors, and listed only real installed addon folders in DynamicLoad.

---

## DynamicSuite & All 8 Modules v1.6.3 (12/11/2026)

### Fixed
* **Midnight 12.1.5 Catalyst & Event Cleanup:** Removed an outdated interaction event warning on login and ensured One-Click Catalyst hooks attach cleanly the first time the Catalyst frame opens.
* **Bottom-Left Chat Flush Anchor Migration:** Defaulted chat placement strictly to bottom-left (0, 0) across reloads, sidebar toggles, whisper boxes, and HUD resizing.

---

## DynamicSuite & All 8 Modules v1.6.2 (12/11/2026)

### Fixed
* **Exact 0px Chat Alignment:** Synchronised chat container bounds with HUD Edit Mode drag shields so parking chat at the bottom-left corner stays locked at (0, 0).
* **Removed Stray Duplicate Module Files:** Cleaned up leftover duplicate script files so only the 8 canonical modules exist.

---

## DynamicSuite & All 8 Modules v1.6.1 (12/11/2026)

### Improved
* **Smoother Raid Combat Performance in DynamicPrep:** Throttled in-combat aura scans to brief coalesced intervals and skipped redundant player-aura stat-bar redraws mid-fight.

---

## DynamicSuite & All 8 Modules v1.6.0 (12/11/2026)

### Added
* **Read-Only Conflict Auto-Yield Option:** Guided Setup and module banners respect frozen/disabled competing addons automatically and give a 1-click switch + Reload UI button when taking over chat or bag skinning.

### Fixed
* **Reliable "Never" Lock Persistence Across Sub-Addons:** Setting any addon or sub-module to Never in DynamicLoad now locks cleanly across character, global, and zone tables so parent UI suites cannot quietly re-enable them at login.

---

## DynamicSuite & All 8 Modules v1.5.0 (12/11/2026)

### Added
* **One-Click Revival Catalyst Conversion:** Enabled by default in DynamicPrep Tab 3 so clicking Transform immediately converts your item without a second confirmation wait (hold Shift for the normal confirmation popup).
* **In-Combat Raid Performance & Modifier-Free Healing Macro:** Upgraded DynamicPrep combat buff scanning with zero-waste aura lookups, suppressed out-of-combat consumable checks mid-pull, improved [DynamicHeal] Healthstone -> Potion priority switching, reinforced Hold CTRL to Release Spirit protection, and hardened in-combat `/ww` whispers.

### Fixed
* **Chat HUD Mover Alignment & Translucent Dragging:** Fixed separator text glitches on HUD movers, hid the Chat mover automatically when DynamicChat is turned off or yielding, and made the drag overlay translucent so live chat text stays visible while moving.

---

## DynamicSuite & All 8 Modules v1.4.7 (12/11/2026)

### Fixed
* **HUD Mover Display & Chat Frame Sizing Sync:** Fixed separator pipe formatting in mover headers, synchronised chat window scale and position 1:1 with its Edit Mode mover, and ensured the Chat mover hides completely when DynamicChat is disabled.

---

## DynamicSuite & All 8 Modules v1.4.6 (12/11/2026)

### Fixed
* **Combat-Ready `/ww` Whisper & Hold CTRL Release Protection:** Hardened `/ww` target whispering during combat (and in Battle.net whisper contexts), reinforced per-frame button locking on the Death popup until CTRL is held, and upgraded [DynamicHeal] to reset cleanly to Healthstone first after combat ends.

---

## DynamicSuite & All 8 Modules v1.4.5 (12/11/2026)

### Fixed
* **DynamicLoad Suite Tree Startup Fix:** Fixed a scoping error when evaluating bundled module statuses inside the DynamicLoad addon list.

---

## DynamicSuite & All 8 Modules v1.4.4 (12/11/2026)

### Added
* **Unified In-Combat Missing Raid Buff Icon:** Replaced the separate floating combat text alert with a clean icon on your Readiness Tracker Strip (showing counts such as 16/17 with a clear MISSING badge) that disappears automatically once everyone is buffed, while hiding non-combat consumables mid-pull.

---

## DynamicSuite & All 8 Modules v1.4.3 (12/11/2026)

### Fixed
* **Clean DynamicChat Toggle Off & Instant Teardown:** Turning DynamicChat Off in the sidebar now disables all chat skinning, custom tabs, side rails, and `/ww` hooks cleanly (with live frame teardown and a Reload UI prompt), and synchronises module checkmarks 1:1 with DynamicLoad.

---

## DynamicSuite & All 8 Modules v1.4.2 (12/11/2026)

### Fixed
* **Safe Conflict Handling for UI Suites:** Ensured competing addons are only disabled when you explicitly click to switch, recovered accidentally locked UI suite components on login, and enabled clean coexistence when chat skinning yields to external suites.

---

## DynamicSuite & All 8 Modules v1.4.1 (12/11/2026)

### Fixed
* **DynamicPrep Readiness Strip & Info Bar Layout Labels:** Resolved an error during raid buff scanning that could interrupt Tab 1 pill labels, and widened Guided Setup / banner conflict buttons so text never clips.

---

## DynamicSuite & All 8 Modules v1.4.0 (12/11/2026)

### Added
* **Symbiotic Relationship, Exact Food Stats & Combat Resurrection Buff Tracker:** Automatically detects Symbiotic Relationship links on allies, reads exact stat amounts from Well Fed food buffs, and highlights recently battle-rezzed allies needing class raid buffs.
* **Suite-Wide Conflict Detector & `/ds conflicts`:** Scans all 8 modules for competing bag, chat, quest, camera, nameplate, LFG, and combat logger addons with clear in-banner resolution choices.

### Fixed
* **On-Screen Marker & Flare Bar Solo Visibility:** Switching Focus Icons or World Flares between Off, Group Only, and Always now updates live immediately (even while Settings are open) without forcing bars visible when solo.
* **Battle.net Whisper Stability & Compact Setup Tabs:** Prevented secret-value errors when using Battle.net whispers alongside `/ww`, deduplicated Guided Setup Step 1 conflict cards, and shortened the 9 Guided Setup tab labels so nothing truncates.

---

## DynamicSuite & DynamicLoad v1.3.0 (11/11/2026)

### Added
* **Unified Single-Entry Architecture:** Consolidated all 8 modules (DynamicLoad, DynamicPrep, DynamicMarker, DynamicZoom, DynamicFPS, DynamicGroup, DynamicBags, DynamicChat) cleanly under one DynamicSuite entry in Blizzard's AddOns list while keeping every module runnable standalone from the same codebase.
* **Global Smart Search (`/ds search <query>`):** Added plain-English feature search in the top-left sidebar across nearly 200 settings with category filter pills (All, Combat & Raid, FPS & Camera, HUD & Look, Bags & QoL, Group & Chat) and 1-click jump-and-highlight navigation.
* **Drag-and-Drop Sidebar Reordering & HUD Edit Esc Failsafe:** Drag module cards or click stacked up/down arrows to reorder the sidebar (keeping DynamicLoad first), and exit HUD Edit Mode cleanly anytime with Escape or closing the Game Menu.

### Fixed
* **Labyrinth Delve Toast Anti-Spam & Chat Flush Docking:** Stopped DynamicLoad profile change toasts from re-appearing between seamless Delve chambers, fused the smoked-glass chat frame cleanly with its tab strip and input bar, and locked canonical sidebar module icons across all 8 modules.

---

## DynamicSuite & DynamicLoad v1.2.0 (11/11/2026)

### Added
* **6-Target HUD Edit Mode (`/ds hud`):** Unified dragging, scaling (60%-150%), nudging, grid/magnet snapping, and bottom-right resizing across Alert Toast, Prep Bar, Focus Icons, World Flares, Raid Buffs, and Chat Frame.
* **7-Step Guided Setup, Unread Changelog Highlight & Account/Character Scope:** Added the interactive setup wizard, [Global] vs [Character] top-bar scope toggle, unread Alert-Gold highlighting on Changelog, and semantic By Zone / Always / Never badges.
* **Two-Badge Header Status Capsule:** Split DynamicLoad's status capsule into Loaded Profile (Green) and Current Zone (Cyan) with 1-click Auto-Switch resume when an instance overrides a manual outdoor profile.

### Improved
* **Standardised Dark-Obsidian Design System:** Unified 2-line L-bracket section headers, sleek precision track sliders, muted Slate-Charcoal "Off" pills (so negative options never glow in accent colour), consistent bottom footer hints, and command-prefix-only tooltip highlighting across every module.

### Fixed
* **UI Responsiveness & Visual Polish:** Eliminated settings-open client stalls, preserved scroll position when toggling addon load rules, and protected manual profile picks across reloads.

---

## DynamicMarker v1.3.0 (`/dm`, `/dynamicmarker`, `/fm`, `/focusmarker`)

### Added
* **30x30 Icon & Flare Pickers + Party-Only Raid Silence:** Crisp square pickers for all 8 raid target markers and world flares, automatic raid chat silencing in Party Only mode, and solo target-dummy macro support.

### Improved
* **Modifier-Free [DynamicMark] & Multi-Spec [DynamicKick]:** 1-click focus and raid marking plus automatic interrupt spell detection for every class and specialisation across all 13 classes.
* **Reactive Macro Step Buttons & Sleek Controls:** Highlights Step 1 (Create Macro) or Step 2 (Pick Up for Bar) automatically until placed on your action bar, alongside L-bracket section borders and full-width Sub-Settings drawers.

### Fixed
* **Combat-Safe HUD Exit & Full-Screen Bar Dragging:** Safely queues HUD changes during combat, protects mouseover kicks when no focus is set, cleans up Escape-key grid overlays, and fixes flare reset defaults and bar edge alignment.

---

## DynamicZoom v1.3.0 (`/dz`, `/dynamiczoom`)

### Added
* **Reactive Scroll-Wheel Accelerator:** Smoothly glides to 39 yards on fast mousewheel flicks while keeping slow adjustments crisp and exact.

### Improved
* **Smart Occlusion Shield & Situational Profiles:** Fades obstructing trees and dungeon pillars instead of snapping your camera forward, and separates Delves/Scenarios from PvP Arenas/Battlegrounds zoom sliders.

### Fixed
* **Portal ActionCam Persistence & Safe Defaults Recovery:** Preserves over-the-shoulder ActionCam offsets through portals and loading screens, prevents unwanted experimental setting warning popups, defers protected camera changes until after combat, and snapshots pre-addon camera defaults for clean recovery.

---

## DynamicFPS v1.3.0 (`/dfps`, `/dynamicfps`)

### Added
* **1:1 Blizzard Graphics Menu Parity & Smart SpellQueueWindow Engine:** Mirrors Blizzard's exact quality tiers, Spell Density (Essential / Reduced / Everything), SSAO, Depth Effects, and CPU Distance/Clutter sliders (1-10) across 6 zone profiles, plus automatic SpellQueueWindow tuning from your live ping, spec, and haste with a live telemetry readout.
* **1-Click Hardware Presets & Boss Telegraph Safety Lock:** Instant Low-End PC, Balanced, Competitive FPS, and High-End Ultra presets per zone with projected boss floor mechanics locked visible in Dungeons and Raids.

### Improved
* **Clearer Controls & Zone Toolbar:** Combined zone status, copy-from-zone buttons, and hardware presets into one compact toolbar, clarified Revert to Base and Minimum Combat FPS descriptions, and added external combat logger auto-yield detection.

### Fixed
* **Combat Protection & Objective Tracker Stability:** Protected combat-restricted settings during active Mythic+ keys and boss pulls, fixed Objective Tracker combat taint, suppressed BossBanner overlap cleanly when muted, and preserved scroll positions when adjusting bottom cards.

---

## DynamicPrep v1.3.0 (`/dprep`, `/dp`)

### Added
* **Midnight Telemetry Omni-Bar & Clickable Raid Buffs HUD:** Customisable 12-segment top info bar (Stats, Spec/Loot, Keystone, Dur, FPS, Ping, Ready Check, Pull Timer) paired with a clickable bar for class raid buffs, single-target partner buffs (Symbiotic Relationship, Source of Magic, Blistering Scales, Earth Shield, Beacons) with smart role targeting, Midnight food/flask/oil/augment rune checks, and live [DynamicHeal] action-bar status badges.

### Improved
* **Streamlined 3-Tab Workspace:** Focused Tab 1 on Top Info Bar Layout Builder, Tab 2 on Raid Buffs & Omni Folio, and Tab 3 on World, Instance & Survival Automation while keeping Merchant, Loot, and Keystone automation in their dedicated modules.

### Fixed
* **Zero-Delay Banker Gossip, Secret Aura Guards & Auto-Gossip Fixes:** Opens DynamicBank instantly at Banker NPCs without DialogueUI window flicker, synchronises Omni Folio clicks across key-down/key-up settings, supports Midnight's 40th spec (Devourer Demon Hunter), prevents secret-aura errors mid-combat, and resolves world object, Delve lever, and quest-book Auto-Gossip edge cases.

---

## DynamicGroup v1.3.0 (`/dgroup`, `/dg`)

### Added
* **Premade Groups Mini-Bar & 1-Click Sign-Up:** Filter Premade Groups live by Datacentre Region (OCE, US-W, US-C, US-E, LATAM, BR), Minimum M+ Score, and Party Utility (Bloodlust / Battle Rez), with compact region/score row badges, tooltip utility breakdowns, and 1-click sign-up.
* **Live Roster Audit & Dedicated Keystone Auto-Slotting:** Inspect party gear, enchants, and consumables at a glance, auto-invite friends/guildies by whisper keyword, and automatically slot your Mythic+ keystone when opening the Font of Power.

### Fixed
* **Locked Row Order, Async Region Filtering & Zero-Taint LFG Hooks:** Prevents listings from jumping under your cursor during updates, fixes tooltip errors when a listed group fills or expires mid-hover, supports raid conversion cleanly on 6th+ auto-invites, and yields safely to other LFG addons when configured.

---

## DynamicBags v1.3.0 (`/dbag`, `/dbags`)

### Added
* **Zero-Lag Virtual Category Bags, Bank Vault & Quick-Open Queue:** Instant category sorting (Keystones, Consumables, Gear Sets, BoE/WuE, Reagents, Junk), unified Personal, Reagent, Warband, and Guild Bank viewer, worldwide Alt Inventory browser, persistent per-mode Bank sub-tab memory, drop-anywhere split stacks, Midnight consumable tier badges, and a 1-spot Quick-Open queue button (Open N) for Soulbound caches/pouches alongside safe auto-open.
* **Unified Merchant, Loot & Delete Automation (Tab 3):** Consolidated Auto-Repair Equipment (with Guild Bank First vs Personal Gold toggle), Auto-Sell Grey Junk, Faster Auto-Loot, and Auto-Fill DELETE confirmations in one home.

### Fixed
* **Instant Mid-Combat Bag Toggle, Zero-Flash Bank Opening & Multi-Pass Stack Merging:** Lets you open and close bags anytime in combat, stops Blizzard's Bank and Guild Bank frames from flashing on first visit, merges split crafting/consumable stacks reliably across multiple passes without slot-lock collisions, and protects Warband Until Equipped and Equipment Set badges across snapshots.

---

## DynamicChat v1.3.0 (`/dchat`, `/dc`, `/dynamicchat`)

### Added
* **Scrollable Top Chat Tabs, Smoked-Glass Container & Per-Channel Sound Alerts:** Keeps every open chat and whisper tab at full readable width with mousewheel and < / > tab scrolling, wraps chat in a unified smoked-glass container with a compact monochrome icon Left Utility Rail (Social, Durability, 1-Click Great Vault, Copy History, Combat Log, Lock/HUD, Settings, Jump to Bottom), and supports custom alerts across 11 channels with 12 built-in sounds and LibSharedMedia support.
* **Chat History Across Reloads, Clickable URLs & Instant `/ww` Whisper Engine:** Saves recent messages across UI reloads (up to 500 lines), captures recent web/Discord/Wago links into the Copy History modal, turns `/ww` cleanly into a native target whisper (including in combat and M+ keys), and adds `/rl` (Reload UI) and `/lg` (Leave Group) shortcuts.

### Fixed
* **Zero-Taint Retail 12.1.5 Chat Compliance & Smooth Combat Log Switching:** Keeps protected raid, party, instance, and whisper channels free of secret-string errors, prevents invisible Blizzard side buttons from stealing rail clicks, caps Combat Log backlog lag when switching tabs, fixes overflow whisper tab clipping, and ensures Blizzard default backgrounds stay hidden on hover.
