-- ============================================================================
-- Headless Lua 5.1 Regression Suite: Load-Time Optimisation & Debloat
-- Verifies:
--   T1. DynamicBags defers EnsureWindow/EnsureButtons/ApplyLive out of PLAYER_LOGIN,
--       pre-warms on idle timer (and cancels timer on early open), and opens in combat.
--   T2. DynamicChat defers ScanExternalSounds out of PLAYER_LOGIN until needed and
--       coalesces redundant ApplySleekChatSkin / ApplySavedChatFramePosition calls.
--   T3. Disabled modules (DynamicBags, DynamicChat, DynamicCursor, DynamicDialogue,
--       DynamicTalent, DynamicVault) unregister all events and schedule 0 timers.
--   T4. All inline CHANGELOG tables (Suite Core, UI DS_CHANGELOG_MODULES, and all
--       13 modules) contain between 1 and 5 entries.
-- Pure ASCII Only.
-- ============================================================================

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

local function BuildMockEnv(opts)
    opts = opts or {}
    local env = {}
    setmetatable(env, { __index = _G })
    env._G = env

    local state = {
        inCombat = false,
        now = 100.0,
        epoch = 1700000000,
    }
    local queuedTimers = {}
    local allFrames = {}
    local lsmCalls = { hash = 0, list = 0 }

    env.time = function() return state.epoch end
    env.date = function() return "21:30" end
    env.GetTime = function() return state.now end
    env.GetScreenWidth = function() return 1920 end
    env.GetScreenHeight = function() return 1080 end
    env.InCombatLockdown = function() return state.inCombat end
    env.UnitAffectingCombat = function() return state.inCombat end
    env.IsEncounterInProgress = function() return false end
    env.IsShiftKeyDown = function() return false end
    env.IsControlKeyDown = function() return false end
    env.IsAltKeyDown = function() return false end
    env.IsModifierKeyDown = function() return false end
    env.IsMouseButtonDown = function() return false end
    env.GetCursorPosition = function() return 500, 500 end
    env.GetCursorInfo = function() return nil end
    env.GetMoney = function() return 123456 end
    env.GetRealmName = function() return "Frostmourne" end
    env.UnitName = function(u) return (u == "player") and "Dentee" or "Ally" end
    env.UnitClass = function() return "Mage", "MAGE", 8 end
    env.UnitGUID = function() return "Player-3725-00000001" end
    env.UnitFactionGroup = function() return "Alliance", "Alliance" end
    env.UnitIsDeadOrGhost = function() return false end
    env.UnitIsConnected = function() return true end
    env.UnitExists = function() return false end
    env.UnitIsPlayer = function() return false end
    env.IsInGroup = function() return false end
    env.IsInRaid = function() return false end
    env.IsInInstance = function() return false, "none" end
    env.GetInstanceInfo = function() return "Azeroth", "none", 0, "", 0, 0, false, 0, 0 end
    env.IsResting = function() return false end
    env.GetBindLocation = function() return "Silvermoon" end
    env.GetNumGroupMembers = function() return 0 end
    env.GetNumSubgroupMembers = function() return 0 end
    env.IsInGuild = function() return false end
    env.PlaySound = function() end
    env.PlaySoundFile = function() end
    env.MuteSoundFile = function() end
    env.UnmuteSoundFile = function() end
    env.strtrim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
    env.strlenutf8 = function(s) return #tostring(s or "") end
    env.issecretvalue = function() return false end
    env.canaccessvalue = function() return true end
    env.wipe = function(t)
        if type(t) ~= "table" then return t end
        for k in pairs(t) do t[k] = nil end
        return t
    end
    env.tinsert = table.insert
    env.tremove = table.remove
    env.CopyTable = function(src)
        if type(src) ~= "table" then return src end
        local dst = {}
        for k, v in pairs(src) do dst[k] = env.CopyTable(v) end
        return dst
    end
    env.print = function() end
    env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    env.UISpecialFrames = {}
    env.SlashCmdList = {}
    env.CHAT_FRAMES = { "ChatFrame1", "ChatFrame2" }
    env.NUM_CHAT_WINDOWS = 10
    env.SOUNDKIT = {
        RAID_WARNING = 8959,
        TELL_MESSAGE = 3081,
        IG_PLAYER_INVITE = 880,
        READY_CHECK = 8960,
        MAP_PING = 3175,
        AUCTION_WINDOW_OPEN = 5274,
        IG_QUEST_LIST_COMPLETE = 878,
    }
    env.Enum = {
        BankType = { Character = 0, Guild = 1, Account = 2 },
        BagIndex = { Backpack = 0, Bank = -1 },
        ChatChannelRuleset = { None = 0 },
    }
    env.ToggleAllBags = function() end
    env.OpenAllBags = function() end
    env.CloseAllBags = function() end
    env.ToggleBackpack = function() end
    env.OpenBackpack = function() end
    env.ToggleBag = function() end
    env.CloseSpecialWindows = function() end
    env.FCF_OpenTemporaryWindow = function() end
    env.FCF_Close = function() end
    env.FCF_SelectDockFrame = function() end
    env.FCF_DockUpdate = function() end
    env.FCFDock_UpdateTabs = function() end
    env.FCFDock_SelectWindow = function() end
    env.FCF_SetWindowName = function() end
    env.FCF_CopyChatSettings = function() end
    env.FCFTab_UpdateAlpha = function() end
    env.FCFTab_UpdateColors = function() end
    env.FCF_StartAlertFlash = function() end
    env.FCF_StopAlertFlash = function() end
    env.FCF_SavePositionAndDimensions = function() end
    env.FCF_RestorePositionAndDimensions = function() end
    env.FloatingChatFrame_UpdateBackgroundAnchors = function() end
    env.ChatEdit_UpdateHeader = function() end
    env.ChatEdit_ActivateChat = function() end
    env.ChatEdit_SendText = function() end
    env.UIFrameIsFading = function() return false end
    env.UIFrameIsFlashing = function() return false end

    env.hooksecurefunc = function(tbl, fnName, hookFn)
        if type(tbl) == "string" then
            hookFn = fnName
            fnName = tbl
            tbl = env
        end
        if type(tbl) == "table" and type(tbl[fnName]) == "function" then
            local orig = tbl[fnName]
            tbl[fnName] = function(...)
                local r1, r2, r3, r4 = orig(...)
                hookFn(...)
                return r1, r2, r3, r4
            end
        end
    end

    env.C_AddOns = {
        GetAddOnMetadata = function() return "2.11.2" end,
        IsAddOnLoaded = function() return false end,
        GetAddOnEnableState = function() return 0 end,
        GetNumAddOns = function() return 0 end,
        GetAddOnInfo = function() return nil end,
    }
    env.C_EventUtils = { IsEventValid = function() return true end }
    env.C_Container = {
        GetContainerNumSlots = function() return 0 end,
        GetContainerNumFreeSlots = function() return 0, 0 end,
        GetContainerItemInfo = function() return nil end,
    }
    env.C_CurrencyInfo = {
        GetBackpackCurrencyInfo = function() return nil end,
        GetCurrencyListSize = function() return 0 end,
        GetCurrencyInfo = function() return nil end,
    }
    env.C_Bank = {
        FetchDepositedMoney = function() return 0 end,
        CanUseBank = function() return false end,
        FetchNumPurchasedBankTabs = function() return 0 end,
    }
    env.C_ChatInfo = {
        InChatMessagingLockdown = function() return false end,
    }
    env.C_ClassTalents = {
        GetActiveConfigID = function() return nil end,
        GetLastSelectedSavedConfigID = function() return nil end,
    }
    env.C_SpecializationInfo = {
        GetSpecialization = function() return 1 end,
        GetSpecializationInfo = function() return 64, "Frost" end,
        GetLootSpecialization = function() return 0 end,
    }
    env.C_WeeklyRewards = {
        HasAvailableRewards = function() return false end,
        GetActivities = function() return {} end,
    }
    env.C_Timer = {
        After = function(delay, fn)
            local rec = { delay = delay or 0, fn = fn, cancelled = false, kind = "After" }
            queuedTimers[#queuedTimers + 1] = rec
            return rec
        end,
        NewTimer = function(delay, fn)
            local rec = { delay = delay or 0, fn = fn, cancelled = false, kind = "NewTimer" }
            function rec:Cancel() self.cancelled = true end
            queuedTimers[#queuedTimers + 1] = rec
            return rec
        end,
    }
    env.LibStub = function(name, silent)
        if name == "LibSharedMedia-3.0" then
            return {
                HashTable = function()
                    lsmCalls.hash = lsmCalls.hash + 1
                    return { ["TestSound"] = "Interface\\AddOns\\Fake\\sound.ogg" }
                end,
                List = function()
                    lsmCalls.list = lsmCalls.list + 1
                    return { "TestSound" }
                end,
                Fetch = function() return "Interface\\AddOns\\Fake\\sound.ogg" end,
            }
        end
        if silent then return nil end
        return nil
    end

    local function NewWidget(wType, name, parent)
        local w = {
            _type = wType or "Frame",
            _name = name,
            _parent = parent,
            _shown = (wType == "Frame" and (name == "ChatFrame1" or name == "ChatFrame1Tab" or name == "GeneralDockManager")) or false,
            _alpha = 1,
            _scale = 1,
            _width = 430,
            _height = 200,
            _left = 0,
            _bottom = 0,
            _level = 10,
            _strata = "MEDIUM",
            _scripts = {},
            _events = {},
            _points = { { "BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 0, 0 } },
            _children = {},
            _regions = {},
            _attributes = {},
            _text = "",
        }
        function w:GetName() return self._name end
        function w:GetObjectType() return self._type end
        function w:SetParent(p) self._parent = p end
        function w:GetParent() return self._parent end
        function w:Show()
            local wasShown = self._shown
            self._shown = true
            if not wasShown and type(self._scripts["OnShow"]) == "function" then
                self._scripts["OnShow"](self)
            end
        end
        function w:Hide()
            local wasShown = self._shown
            self._shown = false
            if wasShown and type(self._scripts["OnHide"]) == "function" then
                self._scripts["OnHide"](self)
            end
        end
        function w:SetShown(v)
            if v then self:Show() else self:Hide() end
        end
        function w:IsShown() return self._shown == true end
        function w:IsVisible() return self._shown == true end
        function w:IsForbidden() return false end
        function w:IsProtected() return false end
        function w:SetAlpha(a) self._alpha = a end
        function w:GetAlpha() return self._alpha end
        function w:SetScale(s) self._scale = s end
        function w:GetScale() return self._scale end
        function w:GetEffectiveScale() return self._scale end
        function w:SetFrameStrata(s) self._strata = s end
        function w:GetFrameStrata() return self._strata end
        function w:SetFrameLevel(l) self._level = l end
        function w:GetFrameLevel() return self._level end
        function w:SetSize(ww, hh) self._width = ww; self._height = hh end
        function w:SetWidth(ww) self._width = ww end
        function w:SetHeight(hh) self._height = hh end
        function w:GetWidth() return self._width end
        function w:GetHeight() return self._height end
        function w:GetSize() return self._width, self._height end
        function w:GetLeft() return self._left end
        function w:GetRight() return self._left + self._width end
        function w:GetBottom() return self._bottom end
        function w:GetTop() return self._bottom + self._height end
        function w:GetRect() return self._left, self._bottom, self._width, self._height end
        function w:GetCenter() return self._left + self._width * 0.5, self._bottom + self._height * 0.5 end
        function w:ClearAllPoints() self._points = {} end
        function w:SetPoint(pt, relTo, relPt, x, y) table.insert(self._points, { pt, relTo, relPt, x, y }) end
        function w:GetNumPoints() return #self._points end
        function w:GetPoint(idx)
            local p = self._points[idx or 1]
            if not p then return "BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 0, 0 end
            return p[1], p[2], p[3], p[4], p[5]
        end
        function w:SetAllPoints() end
        function w:SetClipsChildren() end
        function w:SetClampedToScreen() end
        function w:SetClampRectInsets() end
        function w:SetHitRectInsets() end
        function w:SetMovable() end
        function w:SetResizable() end
        function w:SetResizeBounds() end
        function w:SetToplevel() end
        function w:SetUserPlaced() end
        function w:EnableMouse() end
        function w:EnableMouseWheel() end
        function w:EnableKeyboard() end
        function w:SetPropagateKeyboardInput() end
        function w:RegisterForDrag() end
        function w:RegisterForClicks() end
        function w:StartMoving() end
        function w:StopMovingOrSizing() end
        function w:Raise() end
        function w:SetBackdrop() end
        function w:SetBackdropColor() end
        function w:SetBackdropBorderColor() end
        function w:SetText(t) self._text = tostring(t or "") end
        function w:GetText() return self._text end
        function w:SetTextColor() end
        function w:SetFont() return true end
        function w:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
        function w:SetShadowColor() end
        function w:SetShadowOffset() end
        function w:SetJustifyH() end
        function w:SetJustifyV() end
        function w:SetWordWrap() end
        function w:SetSpacing() end
        function w:GetStringWidth() return 60 end
        function w:GetUnboundedStringWidth() return 60 end
        function w:GetStringHeight() return 14 end
        function w:SetAutoFocus() end
        function w:SetMaxLetters() end
        function w:SetNumeric() end
        function w:SetTextInsets() end
        function w:SetAltArrowKeyMode() end
        function w:SetFontObject() end
        function w:SetFocus() end
        function w:ClearFocus() end
        function w:HasFocus() return false end
        function w:HighlightText() end
        function w:SetCursorPosition() end
        function w:SetAttribute(k, v) self._attributes[k] = v end
        function w:GetAttribute(k) return self._attributes[k] end
        function w:SetScrollChild(c) self._scrollChild = c end
        function w:GetScrollChild() return self._scrollChild end
        function w:SetVerticalScroll(v) self._vScroll = v end
        function w:GetVerticalScroll() return self._vScroll or 0 end
        function w:GetVerticalScrollRange() return 0 end
        function w:UpdateScrollChildRect() end
        function w:SetColorTexture() end
        function w:SetTexture() end
        function w:SetVertexColor() end
        function w:SetTexCoord() end
        function w:SetRotation() end
        function w:SetDesaturated() end
        function w:SetSnapToPixelGrid() end
        function w:SetTexelSnappingBias() end
        function w:SetID(id) self._id = id end
        function w:GetID() return self._id or 0 end
        function w:SetNormalTexture() end
        function w:SetPushedTexture() end
        function w:SetHighlightTexture() end
        function w:SetEnabled() end
        function w:IsEnabled() return true end
        function w:IsMouseOver() return false end
        function w:GetChildren() return unpack(self._children) end
        function w:GetNumChildren() return #self._children end
        function w:GetRegions() return unpack(self._regions) end
        function w:GetNumRegions() return #self._regions end
        function w:SetFontString(fs) self._fontString = fs end
        function w:GetFontString() return self._fontString end
        function w:CreateFontString()
            local fs = NewWidget("FontString", nil, self)
            table.insert(self._regions, fs)
            return fs
        end
        function w:CreateTexture()
            local tex = NewWidget("Texture", nil, self)
            table.insert(self._regions, tex)
            return tex
        end
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
        function w:RegisterUnitEvent(ev) self._events[ev] = true end
        function w:UnregisterEvent(ev) self._events[ev] = nil end
        function w:UnregisterAllEvents()
            for k in pairs(self._events) do self._events[k] = nil end
        end
        function w:IsEventRegistered(ev) return self._events[ev] == true end
        function w:GetNumMessages() return 0 end
        function w:SetMaxLines() end
        function w:AddMessage() end
        function w:ScrollToBottom() end
        function w:CreateAnimationGroup()
            return {
                CreateAnimation = function() return { SetDuration = function() end, SetFromAlpha = function() end, SetToAlpha = function() end, SetSmoothing = function() end } end,
                SetLooping = function() end,
                Play = function() end,
                Stop = function() end,
            }
        end
        if parent and type(parent._children) == "table" then
            table.insert(parent._children, w)
        end
        if name then env[name] = w end
        table.insert(allFrames, w)
        return w
    end

    env.UIParent = NewWidget("Frame", "UIParent", nil)
    env.UIParent._width = 1920
    env.UIParent._height = 1080
    env.CreateFrame = function(wType, name, parent)
        return NewWidget(wType, name, parent)
    end
    env.GameTooltip = NewWidget("GameTooltip", "GameTooltip", env.UIParent)
    env.GameTooltip.SetOwner = function() end
    env.GameTooltip.AddLine = function() end
    env.GameTooltip.AddDoubleLine = function() end

    -- Minimal ChatFrame mocks for DynamicChat
    env.GeneralDockManager = NewWidget("Frame", "GeneralDockManager", env.UIParent)
    env.GeneralDockManagerScrollFrame = NewWidget("ScrollFrame", "GeneralDockManagerScrollFrame", env.GeneralDockManager)
    env.GeneralDockManagerScrollFrameChild = NewWidget("Frame", "GeneralDockManagerScrollFrameChild", env.GeneralDockManagerScrollFrame)
    for i = 1, 10 do
        local cf = NewWidget("ScrollingMessageFrame", "ChatFrame" .. i, env.UIParent)
        cf.FontStringContainer = NewWidget("Frame", nil, cf)
        local tab = NewWidget("Button", "ChatFrame" .. i .. "Tab", env.GeneralDockManager)
        tab:SetFontString(tab:CreateFontString())
        local eb = NewWidget("EditBox", "ChatFrame" .. i .. "EditBox", cf)
        eb.header = NewWidget("FontString", nil, eb)
        eb.headerSuffix = NewWidget("FontString", nil, eb)
        eb.focusLeft = NewWidget("Texture", nil, eb)
        eb.focusMid = NewWidget("Texture", nil, eb)
        eb.focusRight = NewWidget("Texture", nil, eb)
        cf.editBox = eb
    end
    env.ChatFrame1.ScrollBar = NewWidget("Slider", nil, env.ChatFrame1)

    if opts.withSuite then
        env.DynamicSuite = {
            version = "2.11.2",
            modules = {},
            Changelogs = {},
            RegisterModule = function() end,
            UI = {
                GetActiveAccentColor = function() return 0.96, 0.72, 0.18 end,
                GetFont = function() return "Fonts\\FRIZQT__.TTF", { path = "Fonts\\FRIZQT__.TTF" } end,
            },
            GetSharedSounds = function()
                return { builtin = {}, blizzard = {}, external = {}, byKey = {} }
            end,
        }
        env.DynamicSuiteDB = {
            global = {
                disabledModules = opts.disabledModules or {},
            },
        }
    end

    local function LoadChunk(relPath, addonName)
        local chunk, err = loadfile(relPath)
        assertTrue(chunk ~= nil, "Failed to load " .. relPath .. ": " .. tostring(err))
        setfenv(chunk, env)
        local ok, runErr = pcall(chunk, addonName or "DynamicSuite", {})
        assertTrue(ok, "Failed to execute " .. relPath .. ": " .. tostring(runErr))
    end

    local function FireEvent(event, a1, a2, a3, a4)
        for _, f in ipairs(allFrames) do
            if f:IsEventRegistered(event) and type(f._scripts["OnEvent"]) == "function" then
                f._scripts["OnEvent"](f, event, a1, a2, a3, a4)
            end
        end
    end

    local function FlushTimers(limit)
        local loops = 0
        while #queuedTimers > 0 and loops < (limit or 30) do
            loops = loops + 1
            local batch = queuedTimers
            queuedTimers = {}
            for _, rec in ipairs(batch) do
                if not rec.cancelled and type(rec.fn) == "function" then
                    rec.fn()
                end
            end
        end
    end

    return {
        env = env,
        state = state,
        allFrames = allFrames,
        getTimers = function() return queuedTimers end,
        clearTimers = function() queuedTimers = {} end,
        lsmCalls = lsmCalls,
        LoadChunk = LoadChunk,
        FireEvent = FireEvent,
        FlushTimers = FlushTimers,
    }
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

-- ============================================================================
-- T1: DynamicBags Deferred Pre-Warm & Combat-Safe Open
-- ============================================================================
RunTest("T1: DynamicBags Deferred Login Pre-Warm & Combat-Safe Open", function()
    -- Case A: Delayed timer pre-warms cleanly out of combat, then B opens in combat
    local h = BuildMockEnv({ withSuite = false })
    h.LoadChunk("DynamicSuite/Modules/DynamicBags.lua", "DynamicBags")
    h.FireEvent("ADDON_LOADED", "DynamicBags")
    h.FireEvent("PLAYER_LOGIN")

    assertEqual(h.env.DynamicBagsFrame, nil, "DynamicBagsFrame must NOT be built synchronously in PLAYER_LOGIN")
    local hasSpecial = false
    for _, name in ipairs(h.env.UISpecialFrames) do
        if name == "DynamicBagsFrame" then hasSpecial = true end
    end
    assertTrue(hasSpecial, "DynamicBagsFrame must be pre-registered in UISpecialFrames on login")

    local preWarmScheduled = false
    for _, t in ipairs(h.getTimers()) do
        if not t.cancelled and math.abs((t.delay or 0) - 1.8) < 0.01 then
            preWarmScheduled = true
        end
    end
    assertTrue(preWarmScheduled, "Deferred 1.8s pre-warm timer must be scheduled on login")

    h.FlushTimers()
    assertTrue(h.env.DynamicBagsFrame ~= nil, "Pre-warm timer builds DynamicBagsFrame out of combat")
    assertEqual(h.env.DynamicBagsFrame:IsShown(), false, "Pre-warmed bag window stays hidden")

    h.state.inCombat = true
    h.env.ToggleAllBags()
    assertEqual(h.env.DynamicBagsFrame:IsShown(), true, "Pressing B in combat opens pre-warmed DynamicBagsFrame cleanly")

    -- Case B: Early open before timer fires builds lazily and cancels pending pre-warm timer
    local h2 = BuildMockEnv({ withSuite = false })
    h2.LoadChunk("DynamicSuite/Modules/DynamicBags.lua", "DynamicBags")
    h2.FireEvent("ADDON_LOADED", "DynamicBags")
    h2.FireEvent("PLAYER_LOGIN")
    assertEqual(h2.env.DynamicBagsFrame, nil, "Frame still nil before early open")

    local preWarmRef = nil
    for _, t in ipairs(h2.getTimers()) do
        if math.abs((t.delay or 0) - 1.8) < 0.01 then preWarmRef = t end
    end
    assertTrue(preWarmRef ~= nil, "Pre-warm timer exists before early open")

    h2.env.ToggleAllBags()
    assertTrue(h2.env.DynamicBagsFrame ~= nil, "Early ToggleAllBags builds DynamicBagsFrame lazily")
    assertEqual(h2.env.DynamicBagsFrame:IsShown(), true, "Early ToggleAllBags shows bag window immediately")
    assertEqual(preWarmRef.cancelled, true, "Early ToggleAllBags cancels pending deferred pre-warm timer")

    -- Case C: Combat entry BEFORE 1.8s pre-warm completes defers cleanly to PLAYER_REGEN_ENABLED,
    -- and alt/warband tooltip count seeding works with zero nil errors both before & after pre-warm
    local h3 = BuildMockEnv({ withSuite = false })
    local tipHookCb = nil
    h3.env.Enum.TooltipDataType = { Item = 0 }
    h3.env.TooltipDataProcessor = {
        AddTooltipPostCall = function(kind, cb)
            if kind == 0 then tipHookCb = cb end
        end,
    }
    h3.env.DynamicBagsDB = {
        tooltipCounts = true,
        vault = {
            characters = {
                ["AltMage-Frostmourne"] = {
                    name = "AltMage",
                    class = "MAGE",
                    bags = { { 19019, 1, 2 } },
                    bank = { { 19019, 1, 3 } },
                },
            },
            warbandBank = {
                items = { { 19019, 1, 4 } },
            },
        },
    }
    h3.LoadChunk("DynamicSuite/Modules/DynamicBags.lua", "DynamicBags")
    h3.FireEvent("ADDON_LOADED", "DynamicBags")
    h3.FireEvent("PLAYER_LOGIN")

    -- Hover tooltip BEFORE 1.8s pre-warm completes: must lazily seed countIndex with 0 nil errors
    assertTrue(type(tipHookCb) == "function", "DynamicBags registered Item tooltip post-call on login")
    local tipLines = {}
    h3.env.GameTooltip.AddDoubleLine = function(_, l, r) tipLines[#tipLines + 1] = tostring(l) .. "=" .. tostring(r) end
    h3.env.GameTooltip.AddLine = function() end
    h3.env.GameTooltip.GetOwner = function() return nil end
    tipHookCb(h3.env.GameTooltip, { id = 19019 })
    assertTrue(#tipLines >= 2, "Alt & Warband tooltip counts populated cleanly before 1.8s pre-warm")

    -- Enter combat BEFORE 1.8s pre-warm fires -> timer defers to pendingPreWarmAfterCombat
    h3.state.inCombat = true
    h3.FlushTimers()
    assertEqual(h3.env.DynamicBagsFrame, nil, "Pre-warm must NOT create frame during combat lockdown")

    -- Leave combat -> PLAYER_REGEN_ENABLED schedules deferred 0.25s pre-warm and builds frame cleanly
    h3.state.inCombat = false
    h3.FireEvent("PLAYER_REGEN_ENABLED")
    h3.FlushTimers()
    assertTrue(h3.env.DynamicBagsFrame ~= nil, "PLAYER_REGEN_ENABLED completes deferred pre-warm cleanly")
    assertEqual(h3.env.DynamicBagsFrame:IsShown(), false, "Post-combat pre-warmed bag window stays hidden")
end)

-- ============================================================================
-- T2: DynamicChat Lazy Sound Scan & Coalesced Reload Layout
-- ============================================================================
RunTest("T2: DynamicChat Deferred Sound Scan & Coalesced Login/Reload Layout", function()
    local h = BuildMockEnv({ withSuite = false })
    h.LoadChunk("DynamicSuite/Modules/DynamicChat.lua", "DynamicChat")
    local dc = h.env.DynamicChat
    assertTrue(dc ~= nil, "DynamicChat global loaded")

    local counts = { scan = 0, skin = 0, pos = 0 }
    local origScan = dc.ScanExternalSounds
    local origSkin = dc.ApplySleekChatSkin
    local origPos = dc.ApplySavedChatFramePosition
    dc.ScanExternalSounds = function(self, ...)
        counts.scan = counts.scan + 1
        return origScan(self, ...)
    end
    dc.ApplySleekChatSkin = function(self, ...)
        counts.skin = counts.skin + 1
        return origSkin(self, ...)
    end
    dc.ApplySavedChatFramePosition = function(self, ...)
        counts.pos = counts.pos + 1
        return origPos(self, ...)
    end

    h.FireEvent("ADDON_LOADED", "DynamicChat")
    h.FireEvent("PLAYER_LOGIN")
    h.FireEvent("PLAYER_ENTERING_WORLD", true, true)
    h.FireEvent("UPDATE_CHAT_WINDOWS")
    h.FireEvent("UI_SCALE_CHANGED")
    h.FlushTimers()

    assertEqual(counts.scan, 0, "ScanExternalSounds must NOT run during PLAYER_LOGIN/reload")
    assertEqual(h.lsmCalls.hash + h.lsmCalls.list, 0, "LibSharedMedia sound tables must NOT be scanned at login")
    assertTrue(counts.skin <= 3, "ApplySleekChatSkin must coalesce across login+PEW+UI events (got " .. tostring(counts.skin) .. ")")
    assertTrue(counts.pos <= 3, "ApplySavedChatFramePosition must coalesce across login+PEW+UI events (got " .. tostring(counts.pos) .. ")")

    local reg = dc:ScanExternalSounds(true)
    assertEqual(counts.scan, 1, "Explicit/dropdown demand triggers lazy ScanExternalSounds")
    assertTrue(h.lsmCalls.hash > 0 and reg.scanned == true, "Lazy ScanExternalSounds populates standalone LSM cache")

    -- Late post-reload Blizzard Edit Mode layout pass must restore saved width/height and passive EditBox skin
    h.env.DynamicChatDB.chatFramePos = {
        point = "BOTTOMLEFT",
        relativePoint = "BOTTOMLEFT",
        relPoint = "BOTTOMLEFT",
        x = 24,
        y = 32,
        width = 640,
        height = 320,
    }
    -- Simulate Blizzard Edit Mode resetting ChatFrame1 back to small default size & re-anchoring EditBox
    h.env.ChatFrame1:SetSize(430, 200)
    h.env.ChatFrame1EditBox:ClearAllPoints()
    h.env.ChatFrame1EditBox:SetPoint("BOTTOMLEFT", h.env.UIParent, "BOTTOMLEFT", 0, 0)
    h.FireEvent("EDIT_MODE_LAYOUTS_UPDATED")
    h.FlushTimers()
    assertEqual(h.env.ChatFrame1:GetWidth(), 640, "Late EDIT_MODE_LAYOUTS_UPDATED preserves saved 640px chat width")
    assertEqual(h.env.ChatFrame1:GetHeight(), 320, "Late EDIT_MODE_LAYOUTS_UPDATED preserves saved 320px chat height")
    local ebPt, ebRel, ebRelPt = h.env.ChatFrame1EditBox:GetPoint(1)
    assertEqual(ebRel, h.env.ChatFrame1, "Late EDIT_MODE_LAYOUTS_UPDATED restores passive EditBox anchor on ChatFrame1")
    assertEqual(ebPt, "BOTTOMLEFT", "Late EDIT_MODE_LAYOUTS_UPDATED embeds EditBox at BOTTOMLEFT")
    assertEqual(ebRelPt, "BOTTOMLEFT", "Late EDIT_MODE_LAYOUTS_UPDATED embeds EditBox relative to BOTTOMLEFT")

    -- Simulate Blizzard moving EditBox to native TOPLEFT->BOTTOMLEFT below ChatFrame1 while keeping 640x320 dimensions
    -- (anchorKey unchanged & relTo still ChatFrame1): passive anchor check must STILL re-embed EditBox inside ChatFrame1!
    h.env.ChatFrame1EditBox:ClearAllPoints()
    h.env.ChatFrame1EditBox:SetPoint("TOPLEFT", h.env.ChatFrame1, "BOTTOMLEFT", -5, -2)
    h.FireEvent("EDIT_MODE_LAYOUTS_UPDATED")
    h.FlushTimers()
    local ebPt2, ebRel2, ebRelPt2 = h.env.ChatFrame1EditBox:GetPoint(1)
    assertEqual(ebRel2, h.env.ChatFrame1, "Same-size native EditBox reset still anchors to ChatFrame1")
    assertEqual(ebPt2, "BOTTOMLEFT", "Same-size native EditBox reset restores BOTTOMLEFT point")
    assertEqual(ebRelPt2, "BOTTOMLEFT", "Same-size native EditBox reset restores BOTTOMLEFT relativePoint")
end)

-- ============================================================================
-- T3: Disabled Modules Exit Cleanly With 0 Registered Events & 0 Timers
-- ============================================================================
RunTest("T3: Disabled Modules Have Zero Registered Events and Zero Login Timers", function()
    local targets = {
        { name = "DynamicBags",     path = "DynamicSuite/Modules/DynamicBags.lua" },
        { name = "DynamicChat",     path = "DynamicSuite/Modules/DynamicChat.lua" },
        { name = "DynamicCursor",   path = "DynamicSuite/Modules/DynamicCursor.lua" },
        { name = "DynamicDialogue", path = "DynamicSuite/Modules/DynamicDialogue.lua" },
        { name = "DynamicTalent",   path = "DynamicSuite/Modules/DynamicTalent.lua" },
        { name = "DynamicVault",    path = "DynamicSuite/Modules/DynamicVault.lua" },
    }
    for _, spec in ipairs(targets) do
        local h = BuildMockEnv({
            withSuite = true,
            disabledModules = { [spec.name] = true },
        })
        h.LoadChunk(spec.path, "DynamicSuite")
        h.clearTimers()

        h.FireEvent("ADDON_LOADED", "DynamicSuite")
        h.FireEvent("PLAYER_LOGIN")
        h.FireEvent("PLAYER_ENTERING_WORLD", true, true)

        local regCount = 0
        for _, f in ipairs(h.allFrames) do
            for _ in pairs(f._events or {}) do
                regCount = regCount + 1
            end
        end
        assertEqual(regCount, 0, spec.name .. " must have 0 registered events when disabled")
        assertEqual(#h.getTimers(), 0, spec.name .. " must schedule 0 timers when disabled")
    end
end)

-- ============================================================================
-- T4: Inline CHANGELOG Tables Trimmed to <= 5 Entries Per Module
-- ============================================================================
RunTest("T4: Inline CHANGELOG Tables Have 1..5 Entries Across All 15 Lua Files", function()
    local function readAll(p)
        local fh = assert(io.open(p, "rb"), "Unable to open " .. p)
        local txt = fh:read("*a")
        fh:close()
        return txt
    end

    -- Check DynamicSuite_Core.lua
    local coreTxt = readAll("DynamicSuite/DynamicSuite_Core.lua")
    local coreEntriesBlock = coreTxt:match('DynamicSuite%.Changelogs%["DynamicSuite"%]%s*=%s*.-entries%s*=%s*(%b{})')
    assertTrue(coreEntriesBlock ~= nil, "DynamicSuite_Core.lua changelog block missing")
    local coreCount = 0
    for _ in coreEntriesBlock:gmatch('type%s*=') do coreCount = coreCount + 1 end
    assertTrue(coreCount >= 1 and coreCount <= 5, "DynamicSuite_Core entries=" .. coreCount .. " (expected 1..5)")

    -- Check DynamicSuite_UI.lua DS_CHANGELOG_MODULES
    local uiTxt = readAll("DynamicSuite/DynamicSuite_UI.lua")
    local clBlock = uiTxt:match("local%s+DS_CHANGELOG_MODULES%s*=%s*(%b{})")
    assertTrue(clBlock ~= nil, "DynamicSuite_UI.lua DS_CHANGELOG_MODULES block missing")
    local uiModCount = 0
    for keyName, itemsTbl in clBlock:gmatch('key%s*=%s*"([^"]+)".-items%s*=%s*(%b{})') do
        uiModCount = uiModCount + 1
        local n = 0
        for _ in itemsTbl:gmatch('badge%s*=') do n = n + 1 end
        assertTrue(n >= 1 and n <= 5, "DynamicSuite_UI DS_CHANGELOG_MODULES[" .. keyName .. "] items=" .. n .. " (expected 1..5)")
    end
    assertEqual(uiModCount, 13, "DS_CHANGELOG_MODULES must cover all 13 modules")

    -- Check all 13 modules
    local modFiles = {
        "DynamicBags.lua", "DynamicChat.lua", "DynamicCursor.lua", "DynamicDialogue.lua",
        "DynamicFPS.lua", "DynamicGroup.lua", "DynamicLoad.lua", "DynamicMail.lua",
        "DynamicMarker.lua", "DynamicPrep.lua", "DynamicTalent.lua", "DynamicVault.lua",
        "DynamicZoom.lua",
    }
    for _, fname in ipairs(modFiles) do
        local txt = readAll("DynamicSuite/Modules/" .. fname)
        local entriesTbl = txt:match('%.CHANGELOG%s*=%s*.-entries%s*=%s*(%b{})')
            or txt:match('DynamicSuite%.Changelogs%["DynamicLoad"%]%s*=%s*.-entries%s*=%s*(%b{})')
        assertTrue(entriesTbl ~= nil, fname .. " inline CHANGELOG entries block missing")
        local n = 0
        for _ in entriesTbl:gmatch('{%s*type%s*=') do n = n + 1 end
        if n == 0 then
            for _ in entriesTbl:gmatch('ver%s*=') do n = n + 1 end
        end
        if n == 0 then
            for _ in entriesTbl:gmatch('version%s*=') do n = n + 1 end
        end
        assertTrue(n >= 1 and n <= 5, fname .. " inline CHANGELOG entries=" .. n .. " (expected 1..5)")
    end
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
