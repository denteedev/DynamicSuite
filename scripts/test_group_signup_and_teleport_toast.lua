-- ============================================================================
-- Headless Lua 5.1 Regression Suite:
--   DynamicGroup True 1-Click Sign-Up & Bulletproof Dungeon Teleport Toast
-- Covers:
--   T1. True 1-Click Sign-Up: synchronous SignUpButton:Click() on row click,
--       Shift/Alt bypass, manual Blizzard Sign Up button click, oneClickSignUp=false,
--       cursor-snap fallback when SignUpButton is disabled, & combat guard
--   T2. 5th-member auto-delist race: pre-delist caching (ApplyToGroup, InviteDialog_Show,
--       AcceptInvite, applied/invited), GetSearchResultInfo() == nil + secret groupName,
--       full dungeon name formatting (known & unknown portal), inviteaccepted -> GROUP_ROSTER_UPDATE
--       5/5 upgrade, early-event grace window, & combat deferral
--   T3. Host / group starter & mid-listing joiners: CreateListing & UpdateListing hooks,
--       5/5 auto-delist preservation, relisting a new dungeon resetting dismissal,
--       friend/guild mid-listing join, & finished-dungeon vs same-dungeon vs active keystone gating
--   T4. Deduplication between LFG_LIST_JOINED_GROUP and LFG_LIST_APPLICATION_STATUS_UPDATED
--       (both orderings, dismissal persistence, and member-count upgrade)
-- Pure ASCII Only.
-- ============================================================================

local GROUP_PATH = "DynamicSuite/Modules/DynamicGroup.lua"

local passed = 0
local failed = 0

local function assertTrue(cond, msg)
    if not cond then
        failed = failed + 1
        error("ASSERTION FAILED: " .. tostring(msg), 2)
    end
end

local function assertEqual(actual, expected, msg)
    if actual ~= expected then
        failed = failed + 1
        error(string.format("ASSERTION FAILED: %s (expected=%s, actual=%s)",
            tostring(msg), tostring(expected), tostring(actual)), 2)
    end
end

local function RunTest(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("[PASS] " .. name)
    else
        failed = failed + 1
        print("[FAIL] " .. name .. "\n       " .. tostring(err))
    end
end

local function MakeStrictSecret(tag)
    return setmetatable({ __testSecret = true, tag = tag or "secret" }, {
        __tostring = function()
            error("attempt to perform string conversion on a secret string value (" .. tostring(tag) .. ")", 2)
        end,
        __concat = function()
            error("attempt to concat secret string value (" .. tostring(tag) .. ")", 2)
        end,
        __lt = function() error("attempt to compare secret value", 2) end,
        __le = function() error("attempt to compare secret value", 2) end,
        __len = function() error("attempt to measure secret value", 2) end,
    })
end

local function CreateHarness(opts)
    opts = opts or {}
    local env = {}
    setmetatable(env, { __index = _G })
    env._G = env

    local now = 100.0
    local timers = {}
    local eventFrames = {}
    local sounds = {}
    local applyCalls = {}
    local acceptInviteCalls = {}
    local createListingCalls = {}
    local updateListingCalls = {}

    local state = {
        inCombat = false,
        keystoneActive = false,
        inGroup = false,
        numGroupMembers = 0,
        inInstance = false,
        instanceType = "none",
        instanceName = "",
        activeChallengeMapID = nil,
        shiftDown = false,
        altDown = false,
        ctrlDown = false,
        knownSpells = {
            [393256]  = true, -- Ruby Life Pools: Path of the Clutch Defender
            [1286809] = true, -- Murder Row: Path of the Devious Smuggler
            [1286807] = true, -- Den of Nalorakk: Path of the Worthy Aspirant
        },
        spellNames = {
            [393256]  = "Path of the Clutch Defender",
            [1286809] = "Path of the Devious Smuggler",
            [1286807] = "Path of the Worthy Aspirant",
        },
        activities = {
            [1170] = {
                categoryID = 2,
                mapChallengeModeID = 399,
                fullName = "Ruby Life Pools (Mythic Keystone)",
                shortName = "Mythic Keystone",
                isMythicPlusActivity = true,
            },
            [1171] = {
                categoryID = 2,
                mapChallengeModeID = 541,
                fullName = "Murder Row (Mythic Keystone)",
                shortName = "Mythic Keystone",
                isMythicPlusActivity = true,
            },
            [1172] = {
                categoryID = 2,
                mapChallengeModeID = 540,
                fullName = "Den of Nalorakk (Mythic Keystone)",
                shortName = "Mythic Keystone",
                isMythicPlusActivity = true,
            },
            [9001] = {
                categoryID = 3,
                fullName = "Liberation of Undermine (Heroic)",
                shortName = "Heroic",
                isMythicPlusActivity = false,
            },
            [9002] = {
                categoryID = 2,
                fullName = "The Stonevault (Heroic)",
                shortName = "Heroic",
                isMythicPlusActivity = false,
            },
        },
        searchResults = {},
        appStatusByID = {},
        hasActiveEntry = false,
        activeEntryInfo = nil,
    }

    env.wipe = function(t)
        if type(t) ~= "table" then return t end
        for k in pairs(t) do t[k] = nil end
        return t
    end
    env.tinsert = table.insert
    env.tremove = table.remove
    env.strtrim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
    env.CopyTable = function(src)
        if type(src) ~= "table" then return src end
        local dst = {}
        for k, v in pairs(src) do dst[k] = env.CopyTable(v) end
        return dst
    end
    env.GetTime = function() return now end
    env.GetScreenWidth = function() return 1920 end
    env.GetScreenHeight = function() return 1080 end
    env.InCombatLockdown = function() return state.inCombat end
    env.UnitAffectingCombat = function() return state.inCombat end
    env.IsEncounterInProgress = function() return false end
    env.IsShiftKeyDown = function() return state.shiftDown end
    env.IsAltKeyDown = function() return state.altDown end
    env.IsControlKeyDown = function() return state.ctrlDown end
    env.IsModifierKeyDown = function() return state.shiftDown or state.altDown or state.ctrlDown end
    env.GetCursorPosition = function() return 960, 540 end
    env.PlaySound = function(kit, channel)
        table.insert(sounds, { kit = kit, channel = channel, at = now })
    end
    env.PlaySoundFile = function() end
    env.print = function() end
    env.issecretvalue = function(v)
        return type(v) == "table" and v.__testSecret == true
    end
    env.canaccessvalue = function(v)
        return not (type(v) == "table" and v.__testSecret == true)
    end
    env.hooksecurefunc = function(tbl, fnName, hookFn)
        if type(tbl) == "string" then
            hookFn = fnName
            fnName = tbl
            tbl = env
        end
        if type(tbl) == "table" and type(tbl[fnName]) == "function" then
            local orig = tbl[fnName]
            tbl[fnName] = function(...)
                local a, b, c, d = orig(...)
                hookFn(...)
                return a, b, c, d
            end
        end
    end

    env.C_Timer = {
        After = function(delay, fn)
            table.insert(timers, { at = now + (tonumber(delay) or 0), fn = fn })
        end,
        NewTimer = function(delay, fn)
            local e = { at = now + (tonumber(delay) or 0), fn = fn }
            table.insert(timers, e)
            return { Cancel = function() e.cancelled = true end }
        end,
        NewTicker = function()
            return { Cancel = function() end }
        end,
    }

    local function NewWidget(wType, name, parent)
        local w = {
            _type = wType,
            _name = name,
            _parent = parent,
            _shown = false,
            _alpha = 1,
            _scale = 1,
            _width = 306,
            _height = 210,
            _level = 5,
            _strata = "MEDIUM",
            _points = { { "CENTER", nil, "CENTER", 0, 100 } },
            _scripts = {},
            _events = {},
            _attrs = {},
            _attrWritesInCombat = 0,
            _showCalls = 0,
            _hideCalls = 0,
            _text = "",
            _borderColor = nil,
            _bgColor = nil,
            _enabled = true,
            _checked = false,
            _raised = 0,
        }
        function w:GetName() return self._name end
        function w:SetParent(p) self._parent = p end
        function w:GetParent() return self._parent end
        function w:Show()
            self._showCalls = self._showCalls + 1
            self._shown = true
            if self._scripts.OnShow then self._scripts.OnShow(self) end
        end
        function w:Hide()
            self._hideCalls = self._hideCalls + 1
            self._shown = false
            if self._scripts.OnHide then self._scripts.OnHide(self) end
        end
        function w:SetShown(v) if v then self:Show() else self:Hide() end end
        function w:IsShown() return self._shown == true end
        function w:IsVisible() return self._shown == true end
        function w:IsForbidden() return false end
        function w:SetAlpha(a) self._alpha = a end
        function w:GetAlpha() return self._alpha end
        function w:EnableMouse() end
        function w:EnableMouseWheel() end
        function w:EnableKeyboard() end
        function w:SetPropagateKeyboardInput() end
        function w:SetClampedToScreen() end
        function w:SetClipsChildren() end
        function w:SetMovable() end
        function w:SetResizable() end
        function w:SetResizeBounds() end
        function w:SetToplevel() end
        function w:SetUserPlaced() end
        function w:RegisterForDrag() end
        function w:RegisterForClicks() end
        function w:SetSize(ww, hh) self._width = ww; self._height = hh end
        function w:SetWidth(ww) self._width = ww end
        function w:SetHeight(hh) self._height = hh end
        function w:GetWidth() return self._width end
        function w:GetHeight() return self._height end
        function w:GetCenter() return 500, 500 end
        function w:SetScale(s) self._scale = s end
        function w:GetScale() return self._scale end
        function w:GetEffectiveScale() return self._scale end
        function w:SetFrameStrata(s) self._strata = s end
        function w:GetFrameStrata() return self._strata end
        function w:SetFrameLevel(l) self._level = l end
        function w:GetFrameLevel() return self._level end
        function w:Raise() self._raised = self._raised + 1 end
        function w:IsMouseOver() return false end
        function w:ClearAllPoints() self._points = {} end
        function w:SetPoint(pt, relTo, relPt, x, y) table.insert(self._points, { pt, relTo, relPt, x, y }) end
        function w:SetAllPoints(p) self._points = { { "ALL", p, "ALL", 0, 0 } } end
        function w:GetNumPoints() return #self._points end
        function w:GetPoint(i) local p = self._points[i]; if not p then return nil end; return p[1], p[2], p[3], p[4], p[5] end
        function w:SetAttribute(k, v)
            if state.inCombat then
                self._attrWritesInCombat = self._attrWritesInCombat + 1
            end
            self._attrs[k] = v
        end
        function w:GetAttribute(k) return self._attrs[k] end
        function w:SetScript(ev, fn) self._scripts[ev] = fn end
        function w:GetScript(ev) return self._scripts[ev] end
        function w:HookScript(ev, fn)
            local prev = self._scripts[ev]
            self._scripts[ev] = function(...)
                if prev then prev(...) end
                fn(...)
            end
        end
        function w:RegisterEvent(ev) self._events[ev] = true end
        function w:UnregisterEvent(ev) self._events[ev] = nil end
        function w:UnregisterAllEvents() self._events = {} end
        function w:SetText(t) self._text = t end
        function w:GetText() return self._text end
        function w:SetFont() end
        function w:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
        function w:SetTextColor() end
        function w:SetJustifyH() end
        function w:SetJustifyV() end
        function w:SetWordWrap() end
        function w:SetSpacing() end
        function w:SetMaxLines() end
        function w:GetStringWidth() return 60 end
        function w:SetEnabled(b) self._enabled = (b == true) end
        function w:IsEnabled() return self._enabled == true end
        function w:SetChecked(b) self._checked = (b == true) end
        function w:GetChecked() return self._checked == true end
        function w:SetColorTexture() end
        function w:SetTexture(tex) self._texture = tex end
        function w:GetTexture() return self._texture end
        function w:SetTexCoord() end
        function w:SetVertexColor() end
        function w:SetSnapToPixelGrid() end
        function w:SetTexelSnappingBias() end
        function w:SetBackdrop() end
        function w:SetBackdropColor(r, g, b, a) self._bgColor = { r, g, b, a } end
        function w:SetBackdropBorderColor(r, g, b, a) self._borderColor = { r, g, b, a } end
        function w:CreateTexture() return NewWidget("Texture", nil, self) end
        function w:CreateFontString() return NewWidget("FontString", nil, self) end
        function w:CreateAnimationGroup()
            local ag = { _scripts = {}, _playing = false }
            function ag:CreateAnimation()
                return { SetDuration = function() end, SetOrder = function() end, SetFromAlpha = function() end, SetToAlpha = function() end }
            end
            function ag:SetScript(ev, fn) self._scripts[ev] = fn end
            function ag:Play() self._playing = true end
            function ag:Pause() self._playing = false end
            function ag:Stop() self._playing = false end
            return ag
        end
        if name then env[name] = w end
        return w
    end

    env.CreateFrame = function(wType, name, parent)
        local f = NewWidget(wType, name, parent)
        table.insert(eventFrames, f)
        return f
    end

    env.UIParent = NewWidget("Frame", "UIParent", nil)
    env.UIParent._shown = true
    env.UIParent._width = 1920
    env.UIParent._height = 1080
    env.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
    env.GameTooltip = NewWidget("GameTooltip", "GameTooltip", env.UIParent)
    env.GameTooltip.SetOwner = function() end
    env.GameTooltip.ClearLines = function() end
    env.GameTooltip.AddLine = function() end
    env.GameTooltip.AddDoubleLine = function() end
    env.UISpecialFrames = {}
    env.SlashCmdList = {}
    env.SOUNDKIT = { READY_CHECK = 8960, IG_PLAYER_INVITE = 880, IG_MAINMENU_OPTION = 1 }
    env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    env.UNKNOWNOBJECT = "Unknown"

    env.UnitName = function() return "Dentee" end
    env.UnitClass = function() return "Mage", "MAGE", 8 end
    env.UnitGUID = function() return "Player-3725-00000001" end
    env.GetRealmName = function() return "Frostmourne" end
    env.GetNormalizedRealmName = function() return "Frostmourne" end
    env.GetAverageItemLevel = function() return 645, 642 end
    env.IsInGroup = function() return state.inGroup end
    env.IsInRaid = function() return false end
    env.GetNumGroupMembers = function() return state.numGroupMembers end
    env.UnitIsGroupLeader = function() return true end
    env.UnitIsGroupAssistant = function() return false end
    env.IsInGuild = function() return true end
    env.IsInInstance = function() return state.inInstance, state.instanceType end
    env.GetInstanceInfo = function() return state.instanceName, state.instanceType end
    env.GetRealZoneText = function() return state.instanceName end
    env.GetCVarBool = function() return false end

    env.C_AddOns = {
        GetAddOnMetadata = function() return "2.11.2" end,
        IsAddOnLoaded = function() return false end,
        GetAddOnEnableState = function() return 0 end,
    }
    env.C_EventUtils = { IsEventValid = function() return true end }
    env.C_PetBattles = { IsInBattle = function() return false end }
    env.C_InstanceEncounter = { IsEncounterInProgress = function() return false end }
    env.C_CVar = { GetCVarBool = function() return false end }
    env.C_ChallengeMode = {
        IsChallengeModeActive = function() return state.keystoneActive end,
        GetActiveChallengeMapID = function() return state.activeChallengeMapID end,
        GetMapTable = function() return { 399, 541, 540 } end,
        GetMapUIInfo = function(mID)
            if mID == 399 then return "Ruby Life Pools", 0, 1800, 4511698 end
            if mID == 541 then return "Murder Row", 0, 1800, 135764 end
            if mID == 540 then return "Den of Nalorakk", 0, 1800, 136095 end
            return nil
        end,
    }
    env.C_MythicPlus = {
        RequestMapInfo = function() end,
        GetMapTable = function() return { 399, 541, 540 } end,
    }
    env.C_SpellBook = {
        IsSpellKnown = function(spellID) return state.knownSpells[spellID] == true end,
        IsSpellInSpellBook = function(spellID) return state.knownSpells[spellID] == true end,
    }
    env.IsSpellKnown = env.C_SpellBook.IsSpellKnown
    env.C_Spell = {
        GetSpellName = function(spellID) return state.spellNames[spellID] end,
        GetSpellInfo = function(spellID)
            local nm = state.spellNames[spellID]
            return nm and { name = nm, iconID = 136095 } or nil
        end,
        GetSpellCooldown = function() return { startTime = 0, duration = 0, isEnabled = true } end,
    }
    env.C_SpecializationInfo = {
        GetSpecialization = function() return 1 end,
        GetSpecializationRole = function() return "DAMAGER" end,
        GetSpecializationInfo = function() return 62, "Arcane", "", 135932, "DAMAGER" end,
    }
    env.GetSpecialization = env.C_SpecializationInfo.GetSpecialization
    env.GetSpecializationRole = env.C_SpecializationInfo.GetSpecializationRole
    env.GetSpecializationInfo = env.C_SpecializationInfo.GetSpecializationInfo

    env.C_LFGList = {
        GetActivityInfoTable = function(id) return state.activities[id] end,
        HasSearchResultInfo = function(id) return state.searchResults[id] ~= nil end,
        GetSearchResultInfo = function(id) return state.searchResults[id] end,
        GetApplicationInfo = function(id) return id, state.appStatusByID[id] or "none" end,
        HasActiveEntryInfo = function() return state.hasActiveEntry end,
        GetActiveEntryInfo = function() return state.activeEntryInfo end,
        ApplyToGroup = function(resultID, tank, healer, dps)
            table.insert(applyCalls, { resultID = resultID, tank = tank, healer = healer, dps = dps, at = now })
        end,
        AcceptInvite = function(resultID)
            table.insert(acceptInviteCalls, { resultID = resultID, at = now })
        end,
        CreateListing = function(createData)
            table.insert(createListingCalls, { data = createData, at = now })
            return true
        end,
        UpdateListing = function(createData)
            table.insert(updateListingCalls, { data = createData, at = now })
            return true
        end,
    }

    -- PVEFrame & LFGList UI stubs
    env.PVEFrame = NewWidget("Frame", "PVEFrame", env.UIParent)
    env.PVEFrame._strata = "HIGH"
    env.PVEFrame._level = 10

    env.LFGListFrame = NewWidget("Frame", "LFGListFrame", env.PVEFrame)
    env.LFGListFrame.EntryCreation = NewWidget("Frame", nil, env.LFGListFrame)
    env.LFGListFrame.EntryCreation.Name = NewWidget("EditBox", nil, env.LFGListFrame.EntryCreation)
    env.LFGListFrame.SearchPanel = NewWidget("Frame", nil, env.LFGListFrame)
    env.LFGListFrame.SearchPanel.RefreshButton = NewWidget("Button", nil, env.LFGListFrame.SearchPanel)
    env.LFGListFrame.SearchPanel.ScrollBox = NewWidget("Frame", nil, env.LFGListFrame.SearchPanel)
    env.LFGListFrame.SearchPanel.SearchBox = NewWidget("EditBox", nil, env.LFGListFrame.SearchPanel)
    env.LFGListFrame.SearchPanel.SignUpButton = NewWidget("Button", nil, env.LFGListFrame.SearchPanel)

    local dlg = NewWidget("Frame", "LFGListApplicationDialog", env.UIParent)
    dlg._shown = false
    dlg._strata = "MEDIUM"
    dlg._width = 306
    dlg._height = 210
    dlg.Description = NewWidget("Frame", nil, dlg)
    dlg.Description.EditBox = NewWidget("EditBox", nil, dlg.Description)
    dlg.DamagerButton = NewWidget("Frame", nil, dlg)
    dlg.DamagerButton._shown = true
    dlg.DamagerButton.CheckButton = NewWidget("CheckButton", nil, dlg.DamagerButton)
    dlg.DamagerButton.CheckButton._checked = false
    dlg.SignUpButton = NewWidget("Button", "LFGListApplicationDialogSignUpButton", dlg)
    dlg.SignUpButton._enabled = false
    dlg.SignUpButton.GetCenter = function() return 450, 430 end
    dlg.SignUpButton._clickCount = 0
    dlg.SignUpButton._clickHidesDialog = true
    dlg.SignUpButton.Click = function(self)
        self._clickCount = self._clickCount + 1
        if dlg._lastResultID then
            env.C_LFGList.ApplyToGroup(dlg._lastResultID, false, false, true)
        end
        if self._clickHidesDialog then
            dlg:Hide()
        end
    end

    env.LFGListSearchPanel_UpdateButtonStatus = function() end
    env.LFGListApplicationDialog_UpdateValidState = function(d)
        if d.DamagerButton.CheckButton:GetChecked() and not d._forceSignUpDisabled then
            d.SignUpButton:SetEnabled(true)
        else
            d.SignUpButton:SetEnabled(false)
        end
    end
    env.LFGListApplicationDialog_UpdateRoles = function() end
    env.LFGListApplicationDialog_Show = function(d, rID)
        d._lastResultID = rID
        d.DamagerButton.CheckButton:SetChecked(false)
        d.SignUpButton:SetEnabled(false)
        d:Show()
    end
    env.LFGListSearchPanel_SignUp = function(sp)
        env.LFGListApplicationDialog_Show(dlg, sp.selectedResult)
    end
    env.LFGListSearchEntry_Update = function() end
    env.LFGListSearchPanel_UpdateResultList = function() end
    env.LFGListSearchEntry_OnClick = function() end
    env.LFGListSearchEntryMixin = { OnClick = function() end }
    env.LFGListInviteDialog = NewWidget("Frame", "LFGListInviteDialog", env.UIParent)
    env.LFGListInviteDialog.GroupName = env.LFGListInviteDialog:CreateFontString()
    env.LFGListInviteDialog.ActivityName = env.LFGListInviteDialog:CreateFontString()
    env.LFGListInviteDialog_Show = function(d, rID)
        d.resultID = rID
        d:Show()
    end

    if opts.withSuite then
        env.DynamicSuite = {
            version = "2.11.2",
            modules = {},
            Changelogs = {},
            RegisterModule = function(self, key, reg) self.modules[key] = reg end,
            GetSuiteAccent = function() return 0.22, 0.74, 0.97 end,
        }
        env.DynamicSuiteDB = { global = { disabledModules = {} } }
    end

    local function LoadModule(addonFolder)
        local chunk, err = loadfile(GROUP_PATH)
        if not chunk then error("Failed to load " .. GROUP_PATH .. ": " .. tostring(err)) end
        setfenv(chunk, env)
        chunk(addonFolder)
    end

    local function FireEvent(event, a1, a2, a3, a4, a5)
        for i = 1, #eventFrames do
            local f = eventFrames[i]
            if f._events[event] and f._scripts.OnEvent then
                f._scripts.OnEvent(f, event, a1, a2, a3, a4, a5)
            end
        end
    end

    local function AdvanceTime(dt)
        now = now + (dt or 0)
        for i = 1, #timers do
            local t = timers[i]
            if not t.cancelled and not t.ran and t.at <= now then
                t.ran = true
                t.fn()
            end
        end
    end

    return {
        env = env,
        state = state,
        sounds = sounds,
        timers = timers,
        applyCalls = applyCalls,
        acceptInviteCalls = acceptInviteCalls,
        createListingCalls = createListingCalls,
        updateListingCalls = updateListingCalls,
        LoadModule = LoadModule,
        FireEvent = FireEvent,
        AdvanceTime = AdvanceTime,
    }
end

-- ============================================================================
-- T1 (a): True 1-Click Sign-Up Synchronous Auto-Submit, Modifiers, Manual Click & Cursor-Snap Fallback
-- ============================================================================
RunTest("T1: True 1-Click Sign-Up (Sync Click, Shift/Alt Bypass, Manual Sign Up, oneClick=false & Disabled Fallback)", function()
    local function VerifyMode(withSuite, addonFolder)
        local h = CreateHarness({ withSuite = withSuite })
        local env = h.env
        env.DynamicGroupDB = {
            oneClickSignUp = true,
            doubleClickSignUp = true,
            autoSelectRole = true,
            autoFillNote = true,
            persistentNote = "chill",
            appendIlvlToNote = false,
            showGroupTeleportToast = true,
        }
        h.state.searchResults[101] = { searchResultID = 101, activityIDs = { 1170 }, name = "+12 chill", isDelisted = false }
        h.state.searchResults[102] = { searchResultID = 102, activityIDs = { 1171 }, name = "+14 blast", isDelisted = false }
        h.state.searchResults[103] = { searchResultID = 103, activityIDs = { 1172 }, name = "+10 weekly", isDelisted = false }

        h.LoadModule(addonFolder)
        h.FireEvent("ADDON_LOADED", addonFolder)
        h.FireEvent("PLAYER_LOGIN")

        local dlg = env.LFGListApplicationDialog

        -- (1a) Single-click synchronously invokes SignUpButton:Click() inside same hardware event (zero timers needed)
        local timersBefore = #h.timers
        env.LFGListSearchEntry_OnClick({ resultID = 101 }, "LeftButton")
        assertEqual(dlg.SignUpButton._clickCount, 1, addonFolder .. ": SignUpButton:Click() invoked synchronously on 1-click")
        assertEqual(#h.applyCalls, 1, addonFolder .. ": C_LFGList.ApplyToGroup submitted in 1 click")
        assertEqual(h.applyCalls[1].resultID, 101, addonFolder .. ": Applied to exact clicked resultID 101")
        assertEqual(dlg:IsShown(), false, addonFolder .. ": Dialog closed after synchronous SignUpButton:Click()")
        assertEqual(dlg.Description.EditBox:GetText(), "chill", addonFolder .. ": Persistent note filled before auto-submit")
        assertEqual(#h.timers, timersBefore, addonFolder .. ": No C_Timer.After scheduled when synchronous click closed dialog")

        -- (1b) Holding Shift or Alt on row single-click opens dialog centred WITHOUT auto-clicking Sign Up or cursor-snapping
        h.AdvanceTime(0.5)
        timersBefore = #h.timers
        h.state.shiftDown = true
        env.LFGListSearchEntry_OnClick({ resultID = 102 }, "LeftButton")
        assertEqual(dlg:IsShown(), true, addonFolder .. ": Shift+SingleClick opens dialog for manual role/note editing")
        assertEqual(dlg.SignUpButton._clickCount, 1, addonFolder .. ": Shift+SingleClick never auto-submits")
        assertEqual(dlg.DamagerButton.CheckButton:GetChecked(), true, addonFolder .. ": Shift+SingleClick still auto-selects role")
        local sPt, _, sRelPt = dlg:GetPoint(1)
        assertEqual(sPt, "CENTER", addonFolder .. ": Shift+SingleClick keeps dialog CENTER anchored")
        assertEqual(sRelPt, "CENTER", addonFolder .. ": Shift+SingleClick does not cursor-snap dialog")
        assertEqual(#h.timers, timersBefore, addonFolder .. ": Shift+SingleClick schedules no fallback snap timer")
        h.state.shiftDown = false
        dlg:Hide()

        h.AdvanceTime(0.5)
        h.state.altDown = true
        env.LFGListSearchEntry_OnClick({ resultID = 102 }, "LeftButton")
        assertEqual(dlg:IsShown(), true, addonFolder .. ": Alt+SingleClick opens dialog for manual role/note editing")
        assertEqual(dlg.SignUpButton._clickCount, 1, addonFolder .. ": Alt+SingleClick never auto-submits")
        local aPt, _, aRelPt = dlg:GetPoint(1)
        assertEqual(aPt, "CENTER", addonFolder .. ": Alt+SingleClick keeps dialog CENTER anchored")
        assertEqual(aRelPt, "CENTER", addonFolder .. ": Alt+SingleClick does not cursor-snap dialog")
        h.state.altDown = false
        dlg:Hide()

        -- (1c) Holding Alt on double-click opens dialog centred WITHOUT auto-clicking SignUpButton
        local entry2 = env.CreateFrame("Button", nil, env.LFGListFrame.SearchPanel)
        entry2.resultID = 102
        env.LFGListSearchEntry_Update(entry2)
        h.AdvanceTime(0.5)
        h.state.altDown = true
        entry2:GetScript("OnDoubleClick")(entry2, "LeftButton")
        assertEqual(dlg:IsShown(), true, addonFolder .. ": Alt+DoubleClick opens dialog for manual editing")
        assertEqual(dlg.SignUpButton._clickCount, 1, addonFolder .. ": Alt+DoubleClick does NOT auto-click SignUpButton")
        local pt, relTo, relPt = dlg:GetPoint(1)
        assertEqual(pt, "CENTER", addonFolder .. ": Dialog stays centred on Alt bypass")
        assertEqual(relPt, "CENTER", addonFolder .. ": Dialog not snapped to BOTTOMLEFT cursor coordinates on Alt bypass")
        h.state.altDown = false
        dlg:Hide()

        -- (1d) Manual click of Blizzard's bottom-right Sign Up button leaves dialog open (never auto-submits in OnShow)
        h.AdvanceTime(0.5)
        env.LFGListFrame.SearchPanel.selectedResult = 102
        env.LFGListSearchPanel_SignUp(env.LFGListFrame.SearchPanel)
        assertEqual(dlg:IsShown(), true, addonFolder .. ": Manual Blizzard Sign Up leaves dialog open")
        assertEqual(dlg.SignUpButton._clickCount, 1, addonFolder .. ": Generic OnShow NEVER auto-clicks SignUpButton")
        assertEqual(dlg.DamagerButton.CheckButton:GetChecked(), true, addonFolder .. ": Manual open still auto-selects role")
        dlg:Hide()

        -- (1e) oneClickSignUp = false disables single-click auto-submit and keeps double-click manual
        h.AdvanceTime(0.5)
        env.DynamicGroupDB.oneClickSignUp = false
        env.LFGListSearchEntry_OnClick({ resultID = 102 }, "LeftButton")
        assertEqual(dlg:IsShown(), false, addonFolder .. ": oneClickSignUp=false ignores single-click")
        assertEqual(dlg.SignUpButton._clickCount, 1, addonFolder .. ": oneClickSignUp=false never auto-clicks")
        entry2:GetScript("OnDoubleClick")(entry2, "LeftButton")
        assertEqual(dlg:IsShown(), true, addonFolder .. ": Double-click still opens dialog when oneClickSignUp=false")
        assertEqual(dlg.SignUpButton._clickCount, 1, addonFolder .. ": Double-click does NOT auto-submit when oneClickSignUp=false")
        dlg:Hide()
        env.DynamicGroupDB.oneClickSignUp = true

        -- (1f) Fallback to SnapDialogSignUpUnderCursor when SignUpButton is disabled
        h.AdvanceTime(0.5)
        dlg._forceSignUpDisabled = true
        env.LFGListSearchEntry_OnClick({ resultID = 103 }, "LeftButton")
        assertEqual(dlg.SignUpButton._clickCount, 1, addonFolder .. ": Disabled SignUpButton is not clicked")
        assertEqual(dlg:IsShown(), true, addonFolder .. ": Dialog stays open when SignUpButton is disabled")
        local fPt, fRelTo, fRelPt = dlg:GetPoint(1)
        assertEqual(fPt, "CENTER", addonFolder .. ": Fallback snaps dialog CENTER")
        assertEqual(fRelPt, "BOTTOMLEFT", addonFolder .. ": Fallback snaps SignUpButton under cursor (BOTTOMLEFT offset)")
        dlg._forceSignUpDisabled = false
        dlg:Hide()

        -- Shift+SingleClick after a prior cursor-snap restores standard centred position,
        -- AND any pending 0-delay fallback snap timer must NOT re-snap the dialog!
        h.AdvanceTime(0.5)
        dlg._forceSignUpDisabled = true
        env.LFGListSearchEntry_OnClick({ resultID = 103 }, "LeftButton")
        dlg._forceSignUpDisabled = false
        dlg:Hide()
        h.AdvanceTime(0.5)
        h.state.shiftDown = true
        env.LFGListSearchEntry_OnClick({ resultID = 103 }, "LeftButton")
        h.AdvanceTime(0.05)
        assertEqual(dlg:IsShown(), true, addonFolder .. ": Shift+SingleClick after fallback opens dialog for manual editing")
        assertEqual(dlg.SignUpButton._clickCount, 1, addonFolder .. ": Shift+SingleClick after fallback never auto-clicks SignUpButton")
        local srPt, _, srRelPt = dlg:GetPoint(1)
        assertEqual(srPt, "CENTER", addonFolder .. ": Shift+SingleClick after fallback restores CENTER")
        assertEqual(srRelPt, "CENTER", addonFolder .. ": Shift+SingleClick after fallback clears cursor snap and resists stale timer")
        h.state.shiftDown = false
        dlg:Hide()

        -- Manual open after a prior cursor-snap restores standard centred position,
        -- AND any pending 0-delay fallback snap timer must NOT re-snap the manually opened dialog!
        h.AdvanceTime(0.5)
        dlg._forceSignUpDisabled = true
        env.LFGListSearchEntry_OnClick({ resultID = 103 }, "LeftButton")
        dlg._forceSignUpDisabled = false
        dlg:Hide()
        env.LFGListApplicationDialog_Show(dlg, 103)
        h.AdvanceTime(0.05)
        local rPt, _, rRelPt = dlg:GetPoint(1)
        assertEqual(rPt, "CENTER", addonFolder .. ": Manual open after fallback restores CENTER")
        assertEqual(rRelPt, "CENTER", addonFolder .. ": Manual open after fallback clears cursor snap and resists stale timer")
        dlg:Hide()
    end

    VerifyMode(true, "DynamicSuite")
    VerifyMode(false, "DynamicGroup")
end)

-- ============================================================================
-- T2 (b): 5th-Member Auto-Delist Race, Secret groupName & inviteaccepted -> GROUP_ROSTER_UPDATE Upgrade
-- ============================================================================
RunTest("T2: 5th-Member Auto-Delist Race (Nil SearchResultInfo, Secret groupName, Full Title, 5/5 Upgrade & Combat Deferral)", function()
    local secretName = MakeStrictSecret("groupName")

    -- (2a) Pre-delist cache via ApplyToGroup / InviteDialog_Show / AcceptInvite with filters & 1-click OFF
    do
        local h = CreateHarness({ withSuite = true })
        local env = h.env
        env.DynamicGroupDB = {
            lfgFilterEnabled = false,
            oneClickSignUp = false,
            showGroupTeleportToast = true,
        }
        h.LoadModule("DynamicSuite")
        h.FireEvent("ADDON_LOADED", "DynamicSuite")
        h.FireEvent("PLAYER_LOGIN")

        local rID = 505
        h.state.searchResults[rID] = { searchResultID = rID, activityIDs = { 1170 }, name = "+12 chill", isDelisted = false }

        -- Player applies, gets invited, and clicks Accept BEFORE server auto-delists
        env.C_LFGList.ApplyToGroup(rID, false, false, true)
        env.LFGListInviteDialog_Show(env.LFGListInviteDialog, rID)
        env.C_LFGList.AcceptInvite(rID)

        -- 5th member causes instant server auto-delist: GetSearchResultInfo now returns nil!
        h.state.searchResults[rID] = nil
        h.state.hasActiveEntry = false
        h.state.activeEntryInfo = nil

        -- Timing race: inviteaccepted fires while IsInGroup() is still false / GetNumGroupMembers() == 1
        h.state.inGroup = false
        h.state.numGroupMembers = 1
        h.FireEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", rID, "inviteaccepted", "invited", secretName)

        local dg = env.DynamicGroup
        assertTrue(dg.teleportToast and dg.teleportToast:IsShown(), "Teleport toast fires even after 5th-member auto-delist + secret groupName")
        assertEqual(dg.teleportToast.titleText:GetText(), "Ruby Life Pools (+12 chill)", "Full dungeon name + listing note clearly shown")
        assertEqual(dg.teleportToast.rosterText:GetText(), "Members: 1/5", "Shows 1/5 initially during pre-roster timing race")
        assertEqual(dg.teleportToast.teleportBtn:GetAttribute("type1"), "spell", "SecureActionButton type1 bound to spell")
        assertEqual(dg.teleportToast.teleportBtn:GetAttribute("spell1"), "Path of the Clutch Defender", "SecureActionButton spell1 bound to teleport spell name")
        assertEqual(#h.sounds, 1, "Initial join chime played once")
        assertEqual(h.sounds[1].kit, env.SOUNDKIT.IG_PLAYER_INVITE, "Initial sound is invite chime")

        -- Early LFG_LIST_ACTIVE_ENTRY_UPDATE while still in pre-join grace window must NOT hide toast
        h.AdvanceTime(0.1)
        h.FireEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
        assertTrue(dg.teleportToast:IsShown(), "Early LFG_LIST_ACTIVE_ENTRY_UPDATE does not hide freshly-triggered joiner toast")

        -- Subsequent GROUP_ROSTER_UPDATE arrives with 5/5 party
        h.state.inGroup = true
        h.state.numGroupMembers = 5
        h.FireEvent("GROUP_ROSTER_UPDATE")

        assertTrue(dg.teleportToast:IsShown(), "Toast stays shown on 5/5 roster update")
        assertTrue(dg.teleportToast.rosterText:GetText():find("Group Full %(5/5%) %- Ready to Teleport!") ~= nil, "Upgrades cleanly to Group Full (5/5) - Ready to Teleport!")
        assertEqual(dg.teleportToast._borderColor[1], 0.133, "Border upgrades to emerald R")
        assertEqual(dg.teleportToast._borderColor[2], 0.773, "Border upgrades to emerald G")
        assertEqual(#h.sounds, 2, "Ready chime plays on upgrade to 5/5")
        assertEqual(h.sounds[2].kit, env.SOUNDKIT.READY_CHECK, "5/5 upgrade plays READY_CHECK chime")
    end

    -- (2b) Pending-invite fallback when LFG_LIST_JOINED_GROUP arrives with nil/secret resultID + unknown teleport spell
    do
        local h = CreateHarness({ withSuite = false })
        local env = h.env
        h.state.knownSpells[393256] = false -- Portal NOT unlocked!
        env.DynamicGroupDB = { showGroupTeleportToast = true }
        h.LoadModule("DynamicGroup")
        h.FireEvent("ADDON_LOADED", "DynamicGroup")
        h.FireEvent("PLAYER_LOGIN")

        local rID = 606
        h.state.searchResults[rID] = { searchResultID = rID, activityIDs = { 1170 }, name = "weekly vault", isDelisted = false }
        h.FireEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", rID, "invited", "applied", "weekly vault")
        env.C_LFGList.AcceptInvite(rID)

        -- Auto-delist + secret searchResultID + secret groupName on LFG_LIST_JOINED_GROUP
        h.state.searchResults[rID] = nil
        h.state.inGroup = true
        h.state.numGroupMembers = 5
        h.FireEvent("LFG_LIST_JOINED_GROUP", MakeStrictSecret("resultID"), secretName)

        local dg = env.DynamicGroup
        assertTrue(dg.teleportToast and dg.teleportToast:IsShown(), "Standalone pending-invite fallback shows toast with secret resultID + secret groupName")
        assertEqual(dg.teleportToast.titleText:GetText(), "Ruby Life Pools (weekly vault)", "Full dungeon name shown even without unlocked portal")
        assertEqual(dg.teleportToast.teleportBtn:GetAttribute("type1"), nil, "No Portal clears secure spell attribute")
        assertEqual(dg.teleportToast.teleportBtn.label:GetText(), "No Portal", "Button indicates No Portal cleanly")
    end

    -- (2c) Joining in combat defers SecureActionButton creation/updates cleanly until PLAYER_REGEN_ENABLED
    do
        local h = CreateHarness({ withSuite = true })
        local env = h.env
        env.DynamicGroupDB = { showGroupTeleportToast = true }
        h.LoadModule("DynamicSuite")
        h.FireEvent("ADDON_LOADED", "DynamicSuite")
        h.FireEvent("PLAYER_LOGIN")

        local rID = 707
        h.state.searchResults[rID] = { searchResultID = rID, activityIDs = { 1171 }, name = "+15 push", isDelisted = false }
        env.C_LFGList.AcceptInvite(rID)
        h.state.searchResults[rID] = nil

        h.state.inCombat = true
        h.state.inGroup = true
        h.state.numGroupMembers = 5
        h.FireEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", rID, "inviteaccepted", "invited", secretName)

        local dg = env.DynamicGroup
        assertEqual(dg.pendingTeleportToastUpdate, true, "Combat join sets pendingTeleportToastUpdate")
        assertEqual(dg.teleportToast, nil, "No secure toast frame created during combat lockdown")

        h.state.inCombat = false
        h.FireEvent("PLAYER_REGEN_ENABLED")
        assertEqual(dg.pendingTeleportToastUpdate, false, "PLAYER_REGEN_ENABLED flushes pendingTeleportToastUpdate")
        assertTrue(dg.teleportToast and dg.teleportToast:IsShown(), "Toast appears immediately upon leaving combat")
        assertEqual(dg.teleportToast.titleText:GetText(), "Murder Row (+15 push)", "Deferred toast shows full dungeon name")
        assertEqual(dg.teleportToast.teleportBtn:GetAttribute("type1"), "spell", "Secure spell attribute bound safely out of combat")
        assertEqual(dg.teleportToast.teleportBtn._attrWritesInCombat, 0, "Zero SetAttribute writes occurred in combat")
    end

    -- (2d) LFGListInviteDialog_Show when GetSearchResultInfo is ALREADY nil and GroupName is a custom title
    --      (no dungeon name in GroupName) -> ActivityName resolves the dungeon while preserving GroupName!
    do
        local h = CreateHarness({ withSuite = true })
        local env = h.env
        env.DynamicGroupDB = { showGroupTeleportToast = true }
        h.LoadModule("DynamicSuite")
        h.FireEvent("ADDON_LOADED", "DynamicSuite")
        h.FireEvent("PLAYER_LOGIN")

        local rID = 708
        -- Search result already expired/delisted BEFORE invite dialog shows (never cached earlier)
        h.state.searchResults[rID] = nil
        env.LFGListInviteDialog.GroupName:SetText("+12 chill")
        env.LFGListInviteDialog.ActivityName:SetText("Ruby Life Pools (Mythic Keystone)")
        env.LFGListInviteDialog_Show(env.LFGListInviteDialog, rID)
        env.C_LFGList.AcceptInvite(rID)

        h.state.inGroup = true
        h.state.numGroupMembers = 5
        h.FireEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", rID, "inviteaccepted", "invited", secretName)

        local dg = env.DynamicGroup
        assertTrue(dg.teleportToast and dg.teleportToast:IsShown(), "InviteDialog ActivityName resolves dungeon even when GetSearchResultInfo is nil and GroupName is custom")
        assertEqual(dg.teleportToast.titleText:GetText(), "Ruby Life Pools (+12 chill)", "ActivityName resolves dungeon while preserving custom GroupName listing title")
        assertEqual(dg.teleportToast.teleportBtn:GetAttribute("type1"), "spell", "ActivityName fallback binds secure teleport type1")
        assertEqual(dg.teleportToast.teleportBtn:GetAttribute("spell1"), "Path of the Clutch Defender", "ActivityName fallback binds correct dungeon teleport spell")
    end

    -- (2e) LFGListInviteDialog_Show with secret resultID & secret GroupName, plain ActivityName ->
    --      populates pending fallback with clean dungeon name and allows plain title upgrade on LFG_LIST_JOINED_GROUP
    do
        local h = CreateHarness({ withSuite = true })
        local env = h.env
        env.DynamicGroupDB = { showGroupTeleportToast = true }
        h.LoadModule("DynamicSuite")
        h.FireEvent("ADDON_LOADED", "DynamicSuite")
        h.FireEvent("PLAYER_LOGIN")

        env.LFGListInviteDialog.GroupName:SetText(MakeStrictSecret("invGroupName"))
        env.LFGListInviteDialog.ActivityName:SetText("Murder Row (Mythic Keystone)")
        env.LFGListInviteDialog_Show(env.LFGListInviteDialog, MakeStrictSecret("invResultID"))

        h.state.inGroup = true
        h.state.numGroupMembers = 4
        h.FireEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", MakeStrictSecret("r1"), "inviteaccepted", "invited", secretName)

        local dg = env.DynamicGroup
        assertTrue(dg.teleportToast and dg.teleportToast:IsShown(), "Secret resultID + secret GroupName still resolves via ActivityName pending fallback")
        assertEqual(dg.teleportToast.titleText:GetText(), "Murder Row", "Secret GroupName uses clean dungeonName instead of raw ActivityName suffix")
        assertEqual(dg.teleportToast.teleportBtn:GetAttribute("spell1"), "Path of the Devious Smuggler", "Binds Murder Row teleport spell")
        assertEqual(#h.sounds, 1, "Single join chime played")

        h.AdvanceTime(0.05)
        h.FireEvent("LFG_LIST_JOINED_GROUP", MakeStrictSecret("r2"), "+14 vault")
        assertEqual(dg.teleportToast.titleText:GetText(), "Murder Row (+14 vault)", "Follow-up event upgrades title cleanly with real listing name")
        assertEqual(#h.sounds, 1, "Title upgrade plays zero duplicate sounds")
    end
end)

-- ============================================================================
-- T3 (c): Hosting / Starting a Group, 5/5 Auto-Delist, Relisting & Finished-Dungeon Rules
-- ============================================================================
RunTest("T3: Host CreateListing/UpdateListing, 5/5 Auto-Delist, Relist Reset, Friend Join & Finished-Dungeon Rules", function()
    local h = CreateHarness({ withSuite = true })
    local env = h.env
    env.DynamicGroupDB = { showGroupTeleportToast = true }
    h.LoadModule("DynamicSuite")
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")

    local dg = env.DynamicGroup

    -- (3a) Solo host creates listing (before server acks HasActiveEntryInfo)
    h.state.inGroup = false
    h.state.numGroupMembers = 1
    h.state.hasActiveEntry = false
    env.C_LFGList.CreateListing({ activityIDs = { 1170 }, name = "+12 chill" })
    assertTrue(dg.lastHostedDungeonMeta ~= nil, "CreateListing eagerly caches lastHostedDungeonMeta")
    assertEqual(dg.lastHostedDungeonMeta.dungeonName, "Ruby Life Pools", "Cached hosted dungeon is Ruby Life Pools")

    -- 2nd member joins -> toast fires even if HasActiveEntryInfo wasn't checked before
    h.state.hasActiveEntry = true
    h.state.activeEntryInfo = { activityIDs = { 1170 }, name = "+12 chill" }
    h.state.inGroup = true
    h.state.numGroupMembers = 2
    h.FireEvent("GROUP_ROSTER_UPDATE")
    assertTrue(dg.teleportToast and dg.teleportToast:IsShown(), "Host sees teleport toast when 2nd member joins")
    assertEqual(dg.teleportToast.titleText:GetText(), "Ruby Life Pools (+12 chill)", "Host toast shows full dungeon name")
    assertEqual(dg.teleportToast.rosterText:GetText(), "Members: 2/5", "Host toast shows Members: 2/5")

    -- 5th member joins AND listing auto-delists immediately (HasActiveEntryInfo == false)
    h.state.hasActiveEntry = false
    h.state.activeEntryInfo = nil
    h.state.numGroupMembers = 5
    h.FireEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
    h.FireEvent("GROUP_ROSTER_UPDATE")
    assertTrue(dg.lastHostedDungeonMeta ~= nil, "5/5 auto-delist preserves lastHostedDungeonMeta while in group")
    assertTrue(dg.teleportToast:IsShown(), "Toast stays visible on 5/5 auto-delist")
    assertTrue(dg.teleportToast.rosterText:GetText():find("Group Full %(5/5%)") ~= nil, "Host toast upgrades to Group Full (5/5)")

    -- (3b) Host dismisses toast, 1 person leaves (4/5), then host relists a NEW dungeon (Murder Row) while still in group
    dg:HideTeleportToast(true)
    assertEqual(dg.teleportToastDismissedForGroup, true, "Dismissing toast marks teleportToastDismissedForGroup")
    h.state.numGroupMembers = 4
    h.FireEvent("GROUP_ROSTER_UPDATE")
    assertEqual(dg.teleportToast:IsShown(), false, "Toast stays dismissed for old listing")

    h.AdvanceTime(2.0)
    h.state.hasActiveEntry = true
    h.state.activeEntryInfo = { activityIDs = { 1171 }, name = "+14 fast" }
    env.C_LFGList.CreateListing({ activityIDs = { 1171 }, name = "+14 fast" })
    assertEqual(dg.teleportToastDismissedForGroup, false, "Starting a new dungeon listing resets teleportToastDismissedForGroup")
    assertTrue(dg.teleportToast:IsShown(), "Relisting new dungeon shows toast immediately")
    assertEqual(dg.teleportToast.titleText:GetText(), "Murder Row (+14 fast)", "Toast switches cleanly to Murder Row (+14 fast)")

    -- Realistic async UpdateListing: changes dungeon from Murder Row (1171) to Den of Nalorakk (1172)
    -- BEFORE server updates GetActiveEntryInfo (activeEntryInfo still holds stale Murder Row 1171 + "+14 fast"!)
    h.AdvanceTime(1.0)
    env.LFGListFrame.EntryCreation.Name:SetText("+15 nalorakk")
    env.C_LFGList.UpdateListing({ activityIDs = { 1172 } })
    assertEqual(dg.teleportToast.titleText:GetText(), "Den of Nalorakk (+15 nalorakk)", "Async UpdateListing reads EntryCreation.Name and resists stale pre-ack GetActiveEntryInfo")

    -- Mid-flight GROUP_ROSTER_UPDATE before server ack must NOT revert toast back to stale Murder Row
    h.AdvanceTime(0.2)
    h.FireEvent("GROUP_ROSTER_UPDATE")
    assertEqual(dg.teleportToast.titleText:GetText(), "Den of Nalorakk (+15 nalorakk)", "Mid-flight roster update preserves updated dungeon before server ack")

    -- Server ack arrives with secret entryInfo.name -> MUST preserve "+15 nalorakk" instead of clobbering it
    h.state.activeEntryInfo = { activityIDs = { 1172 }, name = MakeStrictSecret("entryName") }
    h.FireEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
    assertEqual(dg.teleportToast.titleText:GetText(), "Den of Nalorakk (+15 nalorakk)", "Secret entryInfo.name preserves known listing title")

    -- Server updates title explicitly to exact dungeon name -> no duplication
    h.state.activeEntryInfo = { activityIDs = { 1172 }, name = "Den of Nalorakk" }
    env.LFGListFrame.EntryCreation.Name:SetText("Den of Nalorakk")
    env.C_LFGList.UpdateListing({ activityIDs = { 1172 }, name = "Den of Nalorakk" })
    assertEqual(dg.teleportToast.titleText:GetText(), "Den of Nalorakk", "UpdateListing updates toast cleanly without duplicating dungeon name")

    -- Creating a non-dungeon (Raid) listing clears stale lastHostedDungeonMeta AND hides the stale dungeon toast
    h.AdvanceTime(1.0)
    env.C_LFGList.CreateListing({ activityIDs = { 9001 }, name = "Heroic Raid" })
    assertEqual(dg.lastHostedDungeonMeta, nil, "Non-dungeon Raid CreateListing clears stale lastHostedDungeonMeta")
    assertEqual(dg.teleportToast:IsShown(), false, "Switching to a Raid listing hides stale dungeon teleport toast")

    -- Non-season Heroic dungeon title avoids duplicate parenthetical when listingName matches base dungeon name
    h.AdvanceTime(1.0)
    h.state.activeEntryInfo = { activityIDs = { 9002 }, name = "The Stonevault" }
    env.C_LFGList.CreateListing({ activityIDs = { 9002 }, name = "The Stonevault" })
    assertTrue(dg.teleportToast:IsShown(), "Non-season Heroic dungeon listing shows teleport toast")
    assertEqual(dg.teleportToast.titleText:GetText(), "The Stonevault (Heroic)", "Heroic dungeon title omits redundant base-name parenthetical")

    -- Auto-faded toast must NOT resurrect on no-op GROUP_ROSTER_UPDATE or member drop, but MUST re-show on member increase
    dg.teleportToast:Hide()
    local showsAfterFade = dg.teleportToast._showCalls
    h.FireEvent("GROUP_ROSTER_UPDATE")
    assertEqual(dg.teleportToast:IsShown(), false, "No-op GROUP_ROSTER_UPDATE does not resurrect faded toast")
    h.state.numGroupMembers = 3
    h.FireEvent("GROUP_ROSTER_UPDATE")
    assertEqual(dg.teleportToast:IsShown(), false, "Member drop while faded does not resurrect toast")
    h.state.numGroupMembers = 5
    h.FireEvent("GROUP_ROSTER_UPDATE")
    assertTrue(dg.teleportToast:IsShown(), "Member increase to 5/5 re-shows faded toast cleanly")
    assertTrue(dg.teleportToast._showCalls > showsAfterFade, "5/5 jump triggered fresh show")

    -- Solo host with active listing >5s + solo GROUP_ROSTER_UPDATE + instant 5/5 auto-delist
    h.state.inGroup = false
    h.state.numGroupMembers = 0
    h.state.hasActiveEntry = false
    h.state.activeEntryInfo = nil
    h.FireEvent("GROUP_ROSTER_UPDATE")
    h.AdvanceTime(1.0)
    env.LFGListFrame.EntryCreation.Name:SetText("+12 chill")
    env.C_LFGList.CreateListing({ activityIDs = { 1170 } })
    h.state.hasActiveEntry = true
    h.state.activeEntryInfo = { activityIDs = { 1170 }, name = "+12 chill" }
    h.FireEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
    h.AdvanceTime(10.0) -- well past 5s create grace window!
    h.FireEvent("GROUP_ROSTER_UPDATE") -- solo roster event while listing is still active
    assertTrue(dg.lastHostedDungeonMeta ~= nil, "Solo GROUP_ROSTER_UPDATE preserves lastHostedDungeonMeta while HasActiveEntryInfo() is true")
    -- 4-man premade joins and auto-delists immediately
    h.state.hasActiveEntry = false
    h.state.activeEntryInfo = nil
    h.state.inGroup = true
    h.state.numGroupMembers = 5
    h.FireEvent("GROUP_ROSTER_UPDATE")
    assertTrue(dg.teleportToast:IsShown(), "Host toast fires on instant 5/5 auto-delist even >5s after CreateListing")
    assertEqual(dg.teleportToast.titleText:GetText(), "Ruby Life Pools (+12 chill)", "Preserved full title on delayed 5/5 auto-delist")

    -- (3c) Standing inside a FINISHED dungeon (Ruby Life Pools, keystoneActive=false):
    --      joining/listing a DIFFERENT dungeon (Murder Row) MUST show toast;
    --      /reload (PLAYER_ENTERING_WORLD) inside finished dungeon MUST also show toast;
    --      joining/listing the SAME dungeon (Ruby Life Pools) MUST skip;
    --      active keystone MUST skip.
    dg:HideTeleportToast(false)
    dg.teleportToastDismissedForGroup = false
    dg.lastHostedDungeonMeta = nil
    dg.wasHostingListing = false
    h.state.inInstance = true
    h.state.instanceType = "party"
    h.state.instanceName = "Ruby Life Pools"
    h.state.keystoneActive = false

    -- Different target dungeon (Murder Row) while inside finished Ruby Life Pools -> SHOWS on GROUP_ROSTER_UPDATE
    h.state.hasActiveEntry = true
    h.state.activeEntryInfo = { activityIDs = { 1171 }, name = "+13 go" }
    h.state.inGroup = true
    h.state.numGroupMembers = 3
    h.FireEvent("GROUP_ROSTER_UPDATE")
    assertTrue(dg.teleportToast:IsShown(), "Joining/listing different dungeon from inside finished dungeon shows toast")
    assertEqual(dg.teleportToast.titleText:GetText(), "Murder Row (+13 go)", "Shows new target dungeon title from inside finished dungeon")

    -- PLAYER_ENTERING_WORLD (/reload) while inside finished Ruby Life Pools with Murder Row group -> SHOWS
    dg:HideTeleportToast(false)
    dg.teleportToastDismissedForGroup = false
    h.FireEvent("PLAYER_ENTERING_WORLD")
    assertTrue(dg.teleportToast:IsShown(), "PLAYER_ENTERING_WORLD inside finished dungeon shows toast for a different target dungeon")

    -- Same target dungeon (Ruby Life Pools) while already inside Ruby Life Pools -> SKIPPED
    dg:HideTeleportToast(false)
    dg.teleportToastDismissedForGroup = false
    dg.lastHostedDungeonMeta = nil
    dg.wasHostingListing = false
    h.state.activeEntryInfo = { activityIDs = { 1170 }, name = "+12 chill" }
    h.FireEvent("GROUP_ROSTER_UPDATE")
    assertEqual(dg.teleportToast:IsShown(), false, "Skips toast when already inside the same target dungeon")

    -- Active keystone -> SKIPPED even for a different dungeon
    h.state.keystoneActive = true
    h.state.activeEntryInfo = { activityIDs = { 1171 }, name = "+13 go" }
    h.FireEvent("GROUP_ROSTER_UPDATE")
    assertEqual(dg.teleportToast:IsShown(), false, "Skips toast when IsKeystoneActive() is true")
end)

-- ============================================================================
-- T4 (d): Deduplication Between LFG_LIST_JOINED_GROUP & LFG_LIST_APPLICATION_STATUS_UPDATED
-- ============================================================================
RunTest("T4: LFG_LIST_JOINED_GROUP & LFG_LIST_APPLICATION_STATUS_UPDATED Deduplication", function()
    -- (4a) inviteaccepted followed immediately by LFG_LIST_JOINED_GROUP at same member count -> 1 sound, 1 show
    do
        local h = CreateHarness({ withSuite = true })
        local env = h.env
        env.DynamicGroupDB = { showGroupTeleportToast = true }
        h.LoadModule("DynamicSuite")
        h.FireEvent("ADDON_LOADED", "DynamicSuite")
        h.FireEvent("PLAYER_LOGIN")

        local rID = 801
        h.state.searchResults[rID] = { searchResultID = rID, activityIDs = { 1170 }, name = "weekly", isDelisted = false }
        env.C_LFGList.AcceptInvite(rID)
        h.state.searchResults[rID] = nil
        h.state.inGroup = true
        h.state.numGroupMembers = 3

        h.FireEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", rID, "inviteaccepted", "invited", "weekly")
        local showCountAfterFirst = env.DynamicGroup.teleportToast._showCalls
        h.AdvanceTime(0.05)
        h.FireEvent("LFG_LIST_JOINED_GROUP", rID, "weekly")

        assertEqual(#h.sounds, 1, "Back-to-back inviteaccepted + LFG_LIST_JOINED_GROUP plays sound only ONCE")
        assertEqual(env.DynamicGroup.teleportToast._showCalls, showCountAfterFirst, "Toast does not double-trigger")
    end

    -- (4b) Reverse ordering: LFG_LIST_JOINED_GROUP first, then inviteaccepted -> 1 sound, 1 show
    do
        local h = CreateHarness({ withSuite = true })
        local env = h.env
        env.DynamicGroupDB = { showGroupTeleportToast = true }
        h.LoadModule("DynamicSuite")
        h.FireEvent("ADDON_LOADED", "DynamicSuite")
        h.FireEvent("PLAYER_LOGIN")

        local rID = 802
        h.state.searchResults[rID] = { searchResultID = rID, activityIDs = { 1171 }, name = "+11 chill", isDelisted = false }
        env.C_LFGList.AcceptInvite(rID)
        h.state.searchResults[rID] = nil
        h.state.inGroup = true
        h.state.numGroupMembers = 4

        h.FireEvent("LFG_LIST_JOINED_GROUP", rID, "+11 chill")
        local showCountAfterFirst = env.DynamicGroup.teleportToast._showCalls
        h.AdvanceTime(0.05)
        h.FireEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", rID, "inviteaccepted", "invited", "+11 chill")

        assertEqual(#h.sounds, 1, "Reverse-order LFG_LIST_JOINED_GROUP + inviteaccepted plays sound only ONCE")
        assertEqual(env.DynamicGroup.teleportToast._showCalls, showCountAfterFirst, "Reverse-order toast does not double-trigger")
    end

    -- (4c) Member count jumps from 1/5 (inviteaccepted) to 5/5 (LFG_LIST_JOINED_GROUP) -> upgrades cleanly once
    do
        local h = CreateHarness({ withSuite = true })
        local env = h.env
        env.DynamicGroupDB = { showGroupTeleportToast = true }
        h.LoadModule("DynamicSuite")
        h.FireEvent("ADDON_LOADED", "DynamicSuite")
        h.FireEvent("PLAYER_LOGIN")

        local rID = 803
        h.state.searchResults[rID] = { searchResultID = rID, activityIDs = { 1170 }, name = "+12 go", isDelisted = false }
        env.C_LFGList.AcceptInvite(rID)
        h.state.searchResults[rID] = nil

        h.state.inGroup = false
        h.state.numGroupMembers = 1
        h.FireEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", rID, "inviteaccepted", "invited", MakeStrictSecret("gn"))
        assertEqual(#h.sounds, 1, "Initial inviteaccepted plays join chime")

        h.state.inGroup = true
        h.state.numGroupMembers = 5
        h.AdvanceTime(0.1)
        h.FireEvent("LFG_LIST_JOINED_GROUP", rID, MakeStrictSecret("gn"))
        assertTrue(env.DynamicGroup.teleportToast.rosterText:GetText():find("Group Full %(5/5%)") ~= nil, "Second event upgrades 1/5 -> 5/5 cleanly")
        assertEqual(#h.sounds, 2, "Plays READY_CHECK chime on 1/5 -> 5/5 upgrade (never double-join)")
        assertEqual(h.sounds[2].kit, env.SOUNDKIT.READY_CHECK, "Second sound is READY_CHECK chime")
    end

    -- (4d) Dismissing toast between inviteaccepted (plain rID) and LFG_LIST_JOINED_GROUP (secret rID!)
    --      does NOT resurrect toast or double-play sound
    do
        local h = CreateHarness({ withSuite = true })
        local env = h.env
        env.DynamicGroupDB = { showGroupTeleportToast = true }
        h.LoadModule("DynamicSuite")
        h.FireEvent("ADDON_LOADED", "DynamicSuite")
        h.FireEvent("PLAYER_LOGIN")

        local rID = 804
        h.state.searchResults[rID] = { searchResultID = rID, activityIDs = { 1172 }, name = "+10 chill", isDelisted = false }
        env.C_LFGList.AcceptInvite(rID)
        h.state.searchResults[rID] = nil
        h.state.inGroup = true
        h.state.numGroupMembers = 3

        h.FireEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", rID, "inviteaccepted", "invited", "+10 chill")
        env.DynamicGroup:HideTeleportToast(true)
        h.AdvanceTime(0.1)
        h.FireEvent("LFG_LIST_JOINED_GROUP", MakeStrictSecret("rid"), MakeStrictSecret("gn"))

        assertEqual(env.DynamicGroup.teleportToast:IsShown(), false, "Second event with secret resultID does not resurrect a dismissed toast")
        assertEqual(#h.sounds, 1, "No duplicate sound after dismissal even when second event has secret resultID")
    end

    -- (4e) Event 1 has secret groupName (generic dungeon title) and Event 2 brings plain groupName at same member count
    --      -> refreshes displayed toast title cleanly with ZERO duplicate sound
    do
        local h = CreateHarness({ withSuite = true })
        local env = h.env
        env.DynamicGroupDB = { showGroupTeleportToast = true }
        h.LoadModule("DynamicSuite")
        h.FireEvent("ADDON_LOADED", "DynamicSuite")
        h.FireEvent("PLAYER_LOGIN")

        local rID = 805
        h.state.searchResults[rID] = { searchResultID = rID, activityIDs = { 1170 }, name = MakeStrictSecret("sn"), isDelisted = false }
        env.C_LFGList.AcceptInvite(rID)
        h.state.searchResults[rID] = nil
        h.state.inGroup = true
        h.state.numGroupMembers = 4

        h.FireEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", rID, "inviteaccepted", "invited", MakeStrictSecret("gn"))
        assertEqual(env.DynamicGroup.teleportToast.titleText:GetText(), "Ruby Life Pools", "Event 1 shows full dungeon name with secret listing name")
        assertEqual(#h.sounds, 1, "Event 1 plays single join sound")

        h.AdvanceTime(0.05)
        h.FireEvent("LFG_LIST_JOINED_GROUP", rID, "+12 blast")
        assertEqual(env.DynamicGroup.teleportToast.titleText:GetText(), "Ruby Life Pools (+12 blast)", "Event 2 upgrades displayed toast title cleanly")
        assertEqual(#h.sounds, 1, "Title-only upgrade plays ZERO duplicate sounds")
    end
end)

-- ============================================================================
-- T5: Hardened Edge Cases (Raid/PvP False Positives, Pending Invite Clobber/Leak,
--     Pre-Resolved Priority, Off-Season ActivityName, Combat Auto-Fade 5/5 & Fallback Centre)
-- ============================================================================
RunTest("T5: Raid/PvP False-Positive Guards, Pending-Invite Preservation/Isolation, Combat Auto-Fade 5/5 & Fallback Centre", function()
    local secretName = MakeStrictSecret("groupName")

    -- (5a) Known Raid activityID (9001) & short/PvP/substring fragments must NEVER fire a dungeon toast
    do
        local h = CreateHarness({ withSuite = true })
        local env = h.env
        env.DynamicGroupDB = { showGroupTeleportToast = true }
        h.LoadModule("DynamicSuite")
        h.FireEvent("ADDON_LOADED", "DynamicSuite")
        h.FireEvent("PLAYER_LOGIN")

        local dg = env.DynamicGroup
        assertEqual(dg:ResolveDungeonTeleportMetadata(9001, "of", false), nil, "Known Raid activityID with short word 'of' returns nil")
        assertEqual(dg:ResolveDungeonTeleportMetadata(9001, "Need mage, Ruby Life Pools after", false), nil, "Known Raid activityID mentioning dungeon in title returns nil")
        assertEqual(dg:ResolveDungeonTeleportMetadata(nil, "of", false), nil, "Short fragment 'of' never false-matches Den of Nalorakk")
        assertEqual(dg:ResolveDungeonTeleportMetadata(nil, "in", false), nil, "Short fragment 'in' never false-matches dungeon")
        assertEqual(dg:ResolveDungeonTeleportMetadata(nil, "2v2 Arena", false), nil, "PvP '2v2 Arena' never false-matches Voidscar Arena")
        assertEqual(dg:ResolveDungeonTeleportMetadata(nil, "no throw", false), nil, "Substring 'row' in 'throw' never false-matches Murder Row")

        -- End-to-end join of a Raid listing whose title mentions a dungeon
        local rRaid = 910
        h.state.searchResults[rRaid] = { searchResultID = rRaid, activityIDs = { 9001 }, name = "Need mage, Ruby Life Pools after", isDelisted = false }
        env.C_LFGList.ApplyToGroup(rRaid, false, false, true)
        env.C_LFGList.AcceptInvite(rRaid)
        h.state.searchResults[rRaid] = nil
        h.state.inGroup = true
        h.state.numGroupMembers = 5
        h.FireEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", rRaid, "inviteaccepted", "invited", "Need mage, Ruby Life Pools after")
        assertEqual(dg.teleportToast, nil, "Joining Raid listing never creates or shows Dungeon Teleport Toast")
    end

    -- (5b) LFG_LIST_APPLICATION_STATUS_UPDATED('invited') with nil GetSearchResultInfo must NOT clobber
    --      fresh resolved pending invite from LFGListInviteDialog_Show ActivityName
    do
        local h = CreateHarness({ withSuite = true })
        local env = h.env
        env.DynamicGroupDB = { showGroupTeleportToast = true }
        h.LoadModule("DynamicSuite")
        h.FireEvent("ADDON_LOADED", "DynamicSuite")
        h.FireEvent("PLAYER_LOGIN")

        env.LFGListInviteDialog.GroupName:SetText("+12 chill")
        env.LFGListInviteDialog.ActivityName:SetText("Ruby Life Pools (Mythic Keystone)")
        env.LFGListInviteDialog_Show(env.LFGListInviteDialog, MakeStrictSecret("secID"))

        -- Follow-up 'invited' event arrives with numeric rID=710 after GetSearchResultInfo(710) is already nil
        h.state.searchResults[710] = nil
        h.FireEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", 710, "invited", "applied", "+12 chill")

        h.state.inGroup = true
        h.state.numGroupMembers = 5
        h.FireEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", 710, "inviteaccepted", "invited", secretName)

        local dg = env.DynamicGroup
        assertTrue(dg.teleportToast and dg.teleportToast:IsShown(), "Invited event after InviteDialog_Show preserves resolved dungeon metadata")
        assertEqual(dg.teleportToast.titleText:GetText(), "Ruby Life Pools (+12 chill)", "Toast retains Ruby Life Pools (+12 chill)")
    end

    -- (5c) Stale dungeon pending invite (rID=505) must NOT leak to a different delisted listing (rID=900)
    --      or after a Raid InviteDialog_Show or declined status
    do
        local h = CreateHarness({ withSuite = true })
        local env = h.env
        env.DynamicGroupDB = { showGroupTeleportToast = true }
        h.LoadModule("DynamicSuite")
        h.FireEvent("ADDON_LOADED", "DynamicSuite")
        h.FireEvent("PLAYER_LOGIN")

        h.state.searchResults[505] = { searchResultID = 505, activityIDs = { 1170 }, name = "+12 chill", isDelisted = false }
        env.LFGListInviteDialog_Show(env.LFGListInviteDialog, 505)
        h.AdvanceTime(20)

        -- Player joins a completely different delisted non-cached listing (rID=900)
        h.state.inGroup = true
        h.state.numGroupMembers = 5
        h.FireEvent("LFG_LIST_JOINED_GROUP", 900, secretName)
        assertEqual(env.DynamicGroup.teleportToast, nil, "Mismatched resultID 900 never inherits stale pending invite from resultID 505")

        -- Raid InviteDialog_Show clears stale dungeon pending invite even when subsequent event has secret resultID
        env.LFGListInviteDialog.GroupName:SetText("Fresh Heroic")
        env.LFGListInviteDialog.ActivityName:SetText("Liberation of Undermine (Heroic)")
        env.LFGListInviteDialog_Show(env.LFGListInviteDialog, MakeStrictSecret("raidID"))
        h.FireEvent("LFG_LIST_JOINED_GROUP", MakeStrictSecret("raidID2"), secretName)
        assertEqual(env.DynamicGroup.teleportToast, nil, "Raid InviteDialog_Show clears prior dungeon pending invite")
    end

    -- (5d) Pre-resolved cached.dungeonName from ActivityName takes priority over another dungeon mentioned in GroupName
    do
        local h = CreateHarness({ withSuite = true })
        local env = h.env
        env.DynamicGroupDB = { showGroupTeleportToast = true }
        h.LoadModule("DynamicSuite")
        h.FireEvent("ADDON_LOADED", "DynamicSuite")
        h.FireEvent("PLAYER_LOGIN")

        local rID = 711
        h.state.searchResults[rID] = nil
        env.LFGListInviteDialog.GroupName:SetText("after Den of Nalorakk")
        env.LFGListInviteDialog.ActivityName:SetText("Ruby Life Pools (Mythic Keystone)")
        env.LFGListInviteDialog_Show(env.LFGListInviteDialog, rID)
        env.C_LFGList.AcceptInvite(rID)

        h.state.inGroup = true
        h.state.numGroupMembers = 5
        h.FireEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", rID, "inviteaccepted", "invited", "after Den of Nalorakk")

        local dg = env.DynamicGroup
        assertTrue(dg.teleportToast and dg.teleportToast:IsShown(), "Pre-resolved ActivityName dungeon shows toast")
        assertEqual(dg.teleportToast.titleText:GetText(), "Ruby Life Pools (after Den of Nalorakk)", "Authoritative ActivityName dungeon is not overridden by another dungeon in listing title")
        assertEqual(dg.teleportToast.teleportBtn:GetAttribute("spell1"), "Path of the Clutch Defender", "Binds Ruby Life Pools teleport, not Den of Nalorakk")
    end

    -- (5e) Off-season known dungeon ActivityName resolves cleanly when GetSearchResultInfo is nil
    do
        local h = CreateHarness({ withSuite = true })
        local env = h.env
        env.DynamicGroupDB = { showGroupTeleportToast = true }
        h.LoadModule("DynamicSuite")
        h.FireEvent("ADDON_LOADED", "DynamicSuite")
        h.FireEvent("PLAYER_LOGIN")

        local rID = 712
        h.state.searchResults[rID] = nil
        env.LFGListInviteDialog.GroupName:SetText("+0 chill")
        env.LFGListInviteDialog.ActivityName:SetText("The Stonevault (Heroic)")
        env.LFGListInviteDialog_Show(env.LFGListInviteDialog, rID)
        env.C_LFGList.AcceptInvite(rID)

        h.state.inGroup = true
        h.state.numGroupMembers = 4
        h.FireEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", rID, "inviteaccepted", "invited", secretName)

        local dg = env.DynamicGroup
        assertTrue(dg.teleportToast and dg.teleportToast:IsShown(), "Off-season known dungeon resolves from ActivityName when GetSearchResultInfo is nil")
        assertEqual(dg.teleportToast.titleText:GetText(), "The Stonevault (+0 chill)", "Shows full off-season dungeon name + listing title")
    end

    -- (5f) Standalone combat auto-fade OnFinished followed by 5/5 GROUP_ROSTER_UPDATE in combat
    --      must NOT wipe activeTeleportToastData or suppress the 5/5 Ready to Teleport! toast on PLAYER_REGEN_ENABLED
    do
        local h = CreateHarness({ withSuite = false })
        local env = h.env
        env.DynamicGroupDB = { showGroupTeleportToast = true }
        h.LoadModule("DynamicGroup")
        h.FireEvent("ADDON_LOADED", "DynamicGroup")
        h.FireEvent("PLAYER_LOGIN")

        local rID = 713
        h.state.searchResults[rID] = { searchResultID = rID, activityIDs = { 1170 }, name = "+12 chill", isDelisted = false }
        env.C_LFGList.AcceptInvite(rID)
        h.state.searchResults[rID] = nil
        h.state.inGroup = true
        h.state.numGroupMembers = 3
        h.FireEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", rID, "inviteaccepted", "invited", "+12 chill")

        local dg = env.DynamicGroup
        assertTrue(dg.teleportToast and dg.teleportToast:IsShown(), "Initial 3/5 toast shown in standalone mode")

        -- Enter combat -> 12s auto-fade finishes in combat -> 5th member joins in combat -> leave combat
        h.state.inCombat = true
        dg.teleportToast.animGroup._scripts.OnFinished()
        h.state.numGroupMembers = 5
        h.FireEvent("GROUP_ROSTER_UPDATE")
        h.state.inCombat = false
        h.FireEvent("PLAYER_REGEN_ENABLED")

        assertTrue(dg.activeTeleportToastData ~= nil, "Combat auto-fade never wipes activeTeleportToastData when 5/5 upgrade arrives")
        assertTrue(dg.teleportToast:IsShown(), "5/5 Ready to Teleport! toast shows cleanly upon leaving combat")
        assertTrue(dg.teleportToast.rosterText:GetText():find("Group Full %(5/5%)") ~= nil, "Upgraded to Group Full (5/5) after combat auto-fade")
    end

    -- (5g) Shift+SingleClick fallback when LFGListApplicationDialog_Show is nil and snapped dialog is already shown
    do
        local h = CreateHarness({ withSuite = true })
        local env = h.env
        env.DynamicGroupDB = { oneClickSignUp = true, autoSelectRole = true }
        h.state.searchResults[104] = { searchResultID = 104, activityIDs = { 1170 }, name = "+12 chill", isDelisted = false }
        h.state.searchResults[105] = { searchResultID = 105, activityIDs = { 1171 }, name = "+14 fast", isDelisted = false }
        h.LoadModule("DynamicSuite")
        h.FireEvent("ADDON_LOADED", "DynamicSuite")
        h.FireEvent("PLAYER_LOGIN")

        local dlg = env.LFGListApplicationDialog
        dlg._forceSignUpDisabled = true
        env.LFGListSearchEntry_OnClick({ resultID = 104 }, "LeftButton")
        local _, _, snapRel = dlg:GetPoint(1)
        assertEqual(snapRel, "BOTTOMLEFT", "Sanity: disabled button fallback snapped dialog under cursor")
        dlg._forceSignUpDisabled = false

        -- Remove LFGListApplicationDialog_Show while dialog stays open, then Shift+SingleClick another row
        env.LFGListApplicationDialog_Show = nil
        h.AdvanceTime(0.5)
        h.state.shiftDown = true
        env.LFGListSearchEntry_OnClick({ resultID = 105 }, "LeftButton")
        h.state.shiftDown = false

        local rPt, _, rRel = dlg:GetPoint(1)
        assertEqual(rPt, "CENTER", "Fallback Shift+SingleClick restores CENTER anchor")
        assertEqual(rRel, "CENTER", "Fallback Shift+SingleClick clears cursor-snap even without LFGListApplicationDialog_Show")
    end
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
