-- ============================================================================
-- Headless Lua 5.1 Regression Suite: DynamicTalent Mouseover Tooltip Perf
-- Verifies:
--   (a) UPDATE_MOUSEOVER_UNIT on a player unit (and while resting in cities)
--       exits immediately without calling DynamicPrep:RefreshBar(),
--       C_Traits.GenerateImportString, or Encounter Journal APIs.
--   (b) UPDATE_MOUSEOVER_UNIT / NAME_PLATE_UNIT_ADDED / PLAYER_SOFT_ENEMY_CHANGED
--       on non-boss NPCs (and nameplate/softenemy players) do not trigger
--       DynamicPrep:RefreshBar() or scan unrelated nameplates.
--   (c) UPDATE_MOUSEOVER_UNIT on a bound raid boss detects the boss, triggers
--       the mismatch toast, and refreshes DynamicPrep:RefreshBar() once without
--       spamming RefreshBar on repeated hover ticks.
--   (d) GetSeason2Raids() attempts TryEnrichWithEJ() at most once when EJ
--       returns no match instead of re-scanning on every hover, resetting only
--       when Blizzard_EncounterJournal loads or forceRefresh is true.
--   (e) Cached active talent string invalidates cleanly on TRAIT_CONFIG_UPDATED,
--       PLAYER_SPECIALIZATION_CHANGED, and PLAYER_ENTERING_WORLD.
-- Pure ASCII Only.
-- ============================================================================

local TALENT_PATH = "DynamicSuite/Modules/DynamicTalent.lua"

local passed = 0
local failed = 0

local function assertTrue(cond, msg)
    if not cond then
        error("ASSERTION FAILED: " .. tostring(msg), 2)
    end
end

local function assertEqual(actual, expected, msg)
    if actual ~= expected then
        error(string.format("ASSERTION FAILED: %s (expected=%s, actual=%s)",
            tostring(msg), tostring(expected), tostring(actual)), 2)
    end
end

local function CreateHarness(opts)
    opts = opts or {}
    local env = {}
    setmetatable(env, { __index = _G })
    env._G = env

    local state = {
        now = 100.0,
        inCombat = false,
        resting = false,
        inInstance = false,
        instName = "",
        instType = "none",
        diffID = 0,
        inGroup = false,
        inRaid = false,
        specID = 62,
        activeConfigID = 1001,
        activeTalentStr = "EXPORT_BUILD_DEFAULT",
        ejTiers = 11,
        ejMatch = false,
        units = {},
        eventFrames = {},
        timers = {},
        calls = {
            refreshBar = 0,
            genImportString = 0,
            ejNumTiers = 0,
            ejSelectTier = 0,
            getNamePlates = 0,
            showToast = {},
        },
    }

    env.wipe = function(t) if type(t) == "table" then for k in pairs(t) do t[k] = nil end end; return t end
    env.tinsert = table.insert
    env.tremove = table.remove
    env.strtrim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
    env.strsplit = function(sep, str)
        local res = {}
        for part in string.gmatch(tostring(str or ""), "([^" .. sep .. "]+)") do table.insert(res, part) end
        return unpack(res)
    end
    env.CopyTable = function(src)
        if type(src) ~= "table" then return src end
        local dst = {}
        for k, v in pairs(src) do dst[k] = env.CopyTable(v) end
        return dst
    end
    env.GetTime = function() return state.now end
    env.GetScreenWidth = function() return 1920 end
    env.GetScreenHeight = function() return 1080 end
    env.InCombatLockdown = function() return state.inCombat end
    env.UnitAffectingCombat = function() return state.inCombat end
    env.IsEncounterInProgress = function() return false end
    env.IsResting = function() return state.resting end
    env.IsShiftKeyDown = function() return false end
    env.IsControlKeyDown = function() return false end
    env.IsAltKeyDown = function() return false end
    env.IsModifierKeyDown = function() return false end
    env.IsMouseButtonDown = function() return false end
    env.GetCursorPosition = function() return 500, 400 end
    env.PlaySound = function() end
    env.PlaySoundFile = function() end
    env.ReloadUI = function() end
    env.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
    env.print = function() end
    env.issecretvalue = function() return false end
    env.canaccessvalue = function() return true end
    env.hooksecurefunc = function() end

    env.C_Timer = {
        After = function(delay, fn) table.insert(state.timers, { at = state.now + (tonumber(delay) or 0), fn = fn }) end,
        NewTimer = function(delay, fn)
            local e = { at = state.now + (tonumber(delay) or 0), fn = fn }
            table.insert(state.timers, e)
            return { Cancel = function() e.cancelled = true end }
        end,
    }

    local function NewWidget(wType, name, parent)
        local w = {
            _type = wType,
            _name = name,
            _parent = parent,
            _shown = false,
            _alpha = 1,
            _width = 300,
            _height = 60,
            _level = 2,
            _points = {},
            _scripts = {},
            _events = {},
            _attrs = {},
            _text = "",
            _children = {},
        }
        if type(parent) == "table" and type(parent._children) == "table" then
            table.insert(parent._children, w)
        end
        function w:GetName() return self._name end
        function w:SetParent(p) self._parent = p end
        function w:GetParent() return self._parent end
        function w:GetChildren() return unpack(self._children or {}) end
        function w:Show() self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end
        function w:Hide() self._shown = false; if self._scripts.OnHide then self._scripts.OnHide(self) end end
        function w:SetShown(v) if v then self:Show() else self:Hide() end end
        function w:IsShown() return self._shown == true end
        function w:IsVisible() return self._shown == true end
        function w:SetAlpha(a) self._alpha = a end
        function w:GetAlpha() return self._alpha end
        function w:EnableMouse() end
        function w:EnableMouseWheel() end
        function w:EnableKeyboard() end
        function w:SetClampedToScreen() end
        function w:SetClampRectInsets() end
        function w:SetClipsChildren() end
        function w:SetMovable() end
        function w:SetResizable() end
        function w:SetResizeBounds() end
        function w:SetToplevel() end
        function w:RegisterForDrag() end
        function w:RegisterForClicks() end
        function w:SetSize(ww, hh) self._width = ww; self._height = hh end
        function w:SetWidth(ww) self._width = ww end
        function w:SetHeight(hh) self._height = hh end
        function w:GetWidth() return self._width end
        function w:GetHeight() return self._height end
        function w:GetCenter() return 960, 540 end
        function w:SetScale(s) self._scale = s end
        function w:GetScale() return self._scale or 1 end
        function w:GetEffectiveScale() return self._scale or 1 end
        function w:SetFrameStrata() end
        function w:SetFrameLevel(l) self._level = l end
        function w:GetFrameLevel() return self._level end
        function w:ClearAllPoints() self._points = {} end
        function w:SetPoint(pt, relTo, relPt, x, y) table.insert(self._points, { pt, relTo, relPt, x, y }) end
        function w:SetAllPoints(p) self._points = { { "ALL", p, "ALL", 0, 0 } } end
        function w:GetPoint(i) local p = self._points[i]; if not p then return nil end; return p[1], p[2], p[3], p[4], p[5] end
        function w:SetAttribute(k, v) self._attrs[k] = v end
        function w:GetAttribute(k) return self._attrs[k] end
        function w:SetScript(ev, fn) self._scripts[ev] = fn end
        function w:GetScript(ev) return self._scripts[ev] end
        function w:HookScript(ev, fn)
            local prev = self._scripts[ev]
            self._scripts[ev] = function(...) if prev then prev(...) end; fn(...) end
        end
        function w:RegisterEvent(ev) self._events[ev] = true end
        function w:RegisterUnitEvent(ev) self._events[ev] = true end
        function w:UnregisterEvent(ev) self._events[ev] = nil end
        function w:UnregisterAllEvents() self._events = {} end
        function w:SetText(t) self._text = t end
        function w:GetText() return self._text end
        function w:SetFont() end
        function w:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
        function w:SetShadowColor() end
        function w:SetShadowOffset() end
        function w:SetTextColor() end
        function w:SetJustifyH() end
        function w:SetJustifyV() end
        function w:SetWordWrap() end
        function w:SetBackdrop() end
        function w:SetBackdropColor() end
        function w:SetBackdropBorderColor() end
        function w:SetEnabledState() end
        function w:CreateAnimationGroup()
            return {
                CreateAnimation = function()
                    return { SetDuration = function() end, SetOrder = function() end, SetFromAlpha = function() end, SetToAlpha = function() end }
                end,
                SetScript = function() end,
                Play = function() end,
                Stop = function() end,
                IsPlaying = function() return false end,
            }
        end
        function w:CreateTexture()
            local tex = NewWidget("Texture", nil, self)
            function tex:SetColorTexture() end
            function tex:SetTexture() end
            function tex:SetTexCoord() end
            function tex:SetVertexColor() end
            function tex:SetBlendMode() end
            return tex
        end
        function w:CreateFontString()
            local fs = NewWidget("FontString", nil, self)
            function fs:GetStringWidth() return 80 end
            return fs
        end
        if name then env[name] = w end
        return w
    end

    env.UIParent = NewWidget("Frame", "UIParent", nil)
    env.UIParent._width = 1920
    env.UIParent._height = 1080
    env.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
    env.GameTooltip = NewWidget("GameTooltip", "GameTooltip", env.UIParent)
    env.UISpecialFrames = {}
    env.SlashCmdList = {}
    env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    env.SOUNDKIT = { IG_MAINMENU_OPTION = 1, IG_MAINMENU_OPTION_CHECKBOX_ON = 856, IG_CHARACTER_INFO_TAB = 841 }
    env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    env.UNKNOWNOBJECT = "Unknown"
    env.LE_PARTY_CATEGORY_INSTANCE = 2
    env.LE_PARTY_CATEGORY_HOME = 1

    env.CreateFrame = function(wType, name, parent)
        local f = NewWidget(wType, name, parent)
        table.insert(state.eventFrames, f)
        return f
    end

    env.UnitExists = function(u)
        if u == "player" then return true end
        local info = state.units[u]
        return info ~= nil and info.exists ~= false
    end
    env.UnitIsPlayer = function(u)
        if u == "player" then return true end
        local info = state.units[u]
        return info ~= nil and info.isPlayer == true
    end
    env.UnitIsDeadOrGhost = function(u)
        local info = state.units[u]
        return info ~= nil and info.dead == true
    end
    env.UnitName = function(u)
        if u == "player" then return "Dentee" end
        local info = state.units[u]
        return info and info.name or nil
    end
    env.UnitGUID = function(u)
        if u == "player" then return "Player-3725-00000001" end
        local info = state.units[u]
        return info and info.guid or nil
    end
    env.UnitClass = function() return "Mage", "MAGE", 8 end
    env.UnitLevel = function() return 80 end
    env.GetRealmName = function() return "Frostmourne" end
    env.GetInstanceInfo = function() return state.instName, state.instType, state.diffID end
    env.IsInInstance = function() return state.inInstance, state.instType end
    env.IsInGroup = function() return state.inGroup end
    env.IsInRaid = function() return state.inRaid end
    env.GetNumGroupMembers = function() return state.inRaid and 20 or 0 end
    env.GetNumSubgroupMembers = function() return 0 end
    env.GetSubZoneText = function() return "" end

    env.C_AddOns = {
        GetAddOnMetadata = function() return "2.11.0" end,
        IsAddOnLoaded = function(n) return n == "DynamicSuite" or n == "DynamicTalent" end,
        GetAddOnEnableState = function() return 2 end,
        GetNumAddOns = function() return 0 end,
    }
    env.GetNumAddOns = env.C_AddOns.GetNumAddOns
    env.C_EventUtils = { IsEventValid = function() return true end }
    env.C_ChallengeMode = { IsChallengeModeActive = function() return false end }
    env.C_InstanceEncounter = { IsEncounterInProgress = function() return false end }
    env.C_PvP = { IsWarModeDesired = function() return false end, IsWarModeActive = function() return false end }
    env.C_SpecializationInfo = {
        GetSpecialization = function() return 1 end,
        GetSpecializationInfo = function() return state.specID, "Arcane", "", 135932, "DAMAGER" end,
        GetNumSpecializations = function() return 3 end,
    }
    env.GetSpecialization = env.C_SpecializationInfo.GetSpecialization
    env.GetSpecializationInfo = env.C_SpecializationInfo.GetSpecializationInfo
    env.GetNumSpecializations = env.C_SpecializationInfo.GetNumSpecializations

    env.C_ClassTalents = {
        GetActiveConfigID = function() return state.activeConfigID end,
        GetLastSelectedSavedConfigID = function() return state.activeConfigID end,
        GetConfigIDsBySpecID = function() return { state.activeConfigID } end,
        GetActiveHeroTalentSpec = function() return nil end,
    }
    env.C_Traits = {
        GenerateImportString = function()
            state.calls.genImportString = state.calls.genImportString + 1
            return state.activeTalentStr
        end,
    }
    env.C_NamePlate = {
        GetNamePlates = function()
            state.calls.getNamePlates = state.calls.getNamePlates + 1
            return {}
        end,
    }

    env.EJ_GetNumTiers = function()
        state.calls.ejNumTiers = state.calls.ejNumTiers + 1
        return state.ejTiers
    end
    env.EJ_GetCurrentTier = function() return state.ejTiers end
    env.EJ_SelectTier = function()
        state.calls.ejSelectTier = state.calls.ejSelectTier + 1
    end
    env.EJ_GetInstanceByIndex = function(i)
        if state.ejMatch and i == 1 then
            return 9001, "The Venomous Abyss"
        end
        return nil
    end
    env.EJ_SelectInstance = function() end
    env.EJ_GetEncounterInfoByIndex = function(j)
        if state.ejMatch and j == 4 then
            return "Vashnik the Malignant", nil, 5004
        end
        return nil
    end

    env.DynamicSuite = {
        version = "2.11.0",
        modules = {},
        Changelogs = {},
        RegisterModule = function(self, reg) self.modules[reg.key] = reg end,
        GetSuiteAccent = function() return 0.22, 0.74, 0.97 end,
    }
    env.DynamicPrep = {
        RefreshBar = function()
            state.calls.refreshBar = state.calls.refreshBar + 1
        end,
    }

    local chunk, err = loadfile(TALENT_PATH)
    assertTrue(chunk ~= nil, "Failed to load DynamicTalent.lua: " .. tostring(err))
    setfenv(chunk, env)
    chunk("DynamicSuite", {})

    local function FireEvent(ev, ...)
        for _, f in ipairs(state.eventFrames) do
            if f._events and f._events[ev] and f._scripts and f._scripts.OnEvent then
                f._scripts.OnEvent(f, ev, ...)
            end
        end
    end

    FireEvent("ADDON_LOADED", "DynamicSuite")
    local dt = env.DynamicTalent
    assertTrue(dt ~= nil, "DynamicTalent global initialised")
    dt.db.talentReminderEnabled = true
    dt.db.talentReminderToastEnabled = true
    dt.db.talentBossMap = dt.db.talentBossMap or {}
    dt.db.talentBossMap[62] = {
        ["vashnik the malignant"] = {
            bossName = "Vashnik the Malignant",
            raidName = "The Venomous Abyss",
            loadoutID = "loadout_vashnik",
            loadoutName = "Vashnik Single Target",
            importString = "EXPORT_BUILD_VASHNIK",
        },
    }
    dt.db.talentStringLibrary = dt.db.talentStringLibrary or {}
    dt.db.talentStringLibrary[62] = {
        { id = "loadout_default", name = "Outdoor Build", group = "Custom", importString = "EXPORT_BUILD_DEFAULT" },
        { id = "loadout_vashnik", name = "Vashnik Single Target", group = "Raid", importString = "EXPORT_BUILD_VASHNIK" },
    }

    local origToast = dt.ShowTalentReminderToast
    dt.ShowTalentReminderToast = function(selfObj, mID, mName, mLabel, isPreview, mKey)
        table.insert(state.calls.showToast, { mID = mID, mName = mName, mLabel = mLabel, mKey = mKey })
        return origToast(selfObj, mID, mName, mLabel, isPreview, mKey)
    end

    return env, state, dt, FireEvent
end

local function RunTest(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print(string.format("[PASS] %s", name))
    else
        failed = failed + 1
        print(string.format("[FAIL] %s -> %s", name, tostring(err)))
    end
end

-- (a) UPDATE_MOUSEOVER_UNIT on a player unit (and while resting) exits in O(1)
RunTest("(a) UPDATE_MOUSEOVER_UNIT on player or resting exits in O(1)", function()
    local _, state, _, FireEvent = CreateHarness()
    state.units.mouseover = { exists = true, isPlayer = true, name = "Friendlymage", guid = "Player-3725-9999" }

    FireEvent("UPDATE_MOUSEOVER_UNIT")
    assertEqual(state.calls.refreshBar, 0, "RefreshBar not called on player mouseover")
    assertEqual(state.calls.genImportString, 0, "GenerateImportString not called on player mouseover")
    assertEqual(state.calls.ejNumTiers, 0, "EJ APIs not called on player mouseover")

    -- Resting in a city on an NPC also exits before boss matching
    state.resting = true
    state.units.mouseover = { exists = true, isPlayer = false, name = "Vashnik the Malignant", guid = "Creature-0-1" }
    FireEvent("UPDATE_MOUSEOVER_UNIT")
    assertEqual(state.calls.refreshBar, 0, "RefreshBar not called while resting on mouseover")
    assertEqual(state.calls.genImportString, 0, "GenerateImportString not called while resting on mouseover")
    assertEqual(state.calls.ejNumTiers, 0, "EJ APIs not called while resting on mouseover")
end)

-- (b) Non-boss NPCs on mouseover / nameplate / softenemy do not trigger RefreshBar
RunTest("(b) Non-boss NPCs on mouseover, nameplate & softenemy never trigger RefreshBar", function()
    local _, state, _, FireEvent = CreateHarness()
    state.resting = false
    state.units.mouseover = { exists = true, isPlayer = false, name = "Innkeeper Allison", guid = "Creature-0-101" }
    state.units.nameplate1 = { exists = true, isPlayer = false, name = "Training Dummy", guid = "Creature-0-102" }
    state.units.softenemy = { exists = true, isPlayer = false, name = "Wild Boar", guid = "Creature-0-103" }

    FireEvent("UPDATE_MOUSEOVER_UNIT")
    FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
    FireEvent("PLAYER_SOFT_ENEMY_CHANGED")

    assertEqual(state.calls.refreshBar, 0, "RefreshBar not called for non-boss NPCs")
    assertEqual(state.calls.genImportString, 0, "GenerateImportString not called for non-boss NPCs")
    assertEqual(state.calls.getNamePlates, 0, "NAME_PLATE_UNIT_ADDED does not scan C_NamePlate.GetNamePlates()")
    assertEqual(#state.calls.showToast, 0, "No toast triggered for non-boss NPCs")
end)

-- (c) Bound raid boss on mouseover detects mismatch, alerts, and refreshes Prep Bar once
RunTest("(c) Bound raid boss mouseover alerts and refreshes Prep Bar once without hover spam", function()
    local _, state, _, FireEvent = CreateHarness()
    state.resting = false
    state.units.mouseover = { exists = true, isPlayer = false, name = "Vashnik the Malignant", guid = "Creature-0-555" }

    FireEvent("UPDATE_MOUSEOVER_UNIT")
    assertEqual(#state.calls.showToast, 1, "ShowTalentReminderToast triggered once for bound raid boss")
    assertEqual(state.calls.refreshBar, 1, "DynamicPrep:RefreshBar called once when mismatch appears")

    -- Immediate repeat within debounce window -> skipped
    state.now = state.now + 0.10
    FireEvent("UPDATE_MOUSEOVER_UNIT")
    assertEqual(state.calls.refreshBar, 1, "Debounced repeat hover does not call RefreshBar")

    -- Later repeat (> 0.35s) with unchanged mismatch state -> still skips RefreshBar and duplicate toast
    state.now = state.now + 1.00
    FireEvent("UPDATE_MOUSEOVER_UNIT")
    assertEqual(state.calls.refreshBar, 1, "Unchanged mismatch on passive MOUSEOVER does not re-call RefreshBar")
    assertEqual(#state.calls.showToast, 1, "Unchanged mismatch does not re-show toast")
end)

-- (d) GetSeason2Raids() tries EJ enrichment at most once until Blizzard_EncounterJournal loads or forceRefresh
RunTest("(d) GetSeason2Raids() runs TryEnrichWithEJ at most once on misses", function()
    local _, state, dt, FireEvent = CreateHarness()
    state.ejMatch = false

    for i = 1, 5 do
        dt:GetSeason2Raids()
        dt:MatchBossTargetName("Random Trash Mob " .. i)
    end
    assertEqual(state.calls.ejNumTiers, 1, "EJ scanned only once across repeated misses")

    -- Loading Blizzard_EncounterJournal resets _ejEnrichAttempted for one fresh attempt
    state.ejMatch = true
    FireEvent("ADDON_LOADED", "Blizzard_EncounterJournal")
    dt:GetSeason2Raids()
    assertEqual(state.calls.ejNumTiers, 2, "Blizzard_EncounterJournal load allows fresh EJ enrichment")

    -- Already enriched -> subsequent reads stay at 2 until forceRefresh = true
    dt:GetSeason2Raids()
    assertEqual(state.calls.ejNumTiers, 2, "Enriched cache stays cached on subsequent calls")
    dt:GetSeason2Raids(true)
    assertEqual(state.calls.ejNumTiers, 3, "forceRefresh = true refreshes EJ explicitly")
end)

-- (e) Cached active talent string invalidates cleanly on TRAIT_CONFIG_UPDATED, spec change, and world entry
RunTest("(e) GetActiveTalentString() caches OOC and invalidates on trait/spec/world events", function()
    local _, state, dt, FireEvent = CreateHarness()

    local s1 = dt:GetActiveTalentString()
    local s2 = dt:GetActiveTalentString()
    local s3 = dt:GetActiveTalentString()
    assertEqual(s1, "EXPORT_BUILD_DEFAULT", "Initial active talent string returned")
    assertEqual(s2, "EXPORT_BUILD_DEFAULT", "Cached read matches initial string")
    assertEqual(s3, "EXPORT_BUILD_DEFAULT", "Repeated cached read matches initial string")
    assertEqual(state.calls.genImportString, 1, "C_Traits.GenerateImportString called only once across cached reads")

    -- TRAIT_CONFIG_UPDATED invalidates cache
    state.activeTalentStr = "EXPORT_BUILD_UPDATED"
    FireEvent("TRAIT_CONFIG_UPDATED", 1001)
    assertEqual(dt:GetActiveTalentString(), "EXPORT_BUILD_UPDATED", "TRAIT_CONFIG_UPDATED refreshes talent string")
    assertEqual(state.calls.genImportString, 2, "GenerateImportString called once after TRAIT_CONFIG_UPDATED")

    -- Cached again until next invalidation
    assertEqual(dt:GetActiveTalentString(), "EXPORT_BUILD_UPDATED", "Updated talent string stays cached")
    assertEqual(state.calls.genImportString, 2, "Second read uses cache without re-serialising")

    -- PLAYER_SPECIALIZATION_CHANGED invalidates cache
    state.activeTalentStr = "EXPORT_BUILD_FIRE"
    FireEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    assertEqual(dt:GetActiveTalentString(), "EXPORT_BUILD_FIRE", "PLAYER_SPECIALIZATION_CHANGED refreshes talent string")
    assertEqual(state.calls.genImportString, 3, "GenerateImportString called once after PLAYER_SPECIALIZATION_CHANGED")

    -- PLAYER_ENTERING_WORLD invalidates cache
    state.activeTalentStr = "EXPORT_BUILD_WORLD"
    FireEvent("PLAYER_ENTERING_WORLD")
    assertEqual(dt:GetActiveTalentString(), "EXPORT_BUILD_WORLD", "PLAYER_ENTERING_WORLD refreshes talent string")
    assertEqual(state.calls.genImportString, 4, "GenerateImportString called once after PLAYER_ENTERING_WORLD")
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
