-- ============================================================================
-- Headless Lua 5.1 Regression Suite: DynamicChat Whisper Tabs & Reload Persistence
-- Covers (Suite + Standalone parity):
--   T1. Layering, scale sync & clickability (headerDragStrip BACKGROUND, tabs LOW 22, nav LOW 25, dock scale)
--   T2. Reparenting from GeneralDockManagerScrollFrameChild, combat-deferred & re-entrant open + auto-viewport
--   T3. Whisper snapshot capping (maxSavedWhisperTabs / maxSavedWhisperLines), 24h pruning & secret-value skipping
--   T4. Zero-taint restore (FCF_OpenTemporaryWindow, 0 AddMessage calls, combat deferral, multi-reload retention)
--   T5. Closing whisper tabs (Middle-Click + Blizzard FCF_Close) & Clear History cleanup
--   T6. Copy Chat modal rendering ("--- Saved From Previous Session ---"), Tab 4 UI & Standalone parity
-- Pure ASCII Only.
-- ============================================================================

local CHAT_PATH = "DynamicSuite/Modules/DynamicChat.lua"

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

local function MakeSecret(tag)
    return setmetatable({ __testSecret = true, tag = tag or "secret" }, {
        __lt = function() error("Attempt to compare secret value") end,
        __le = function() error("Attempt to compare secret value") end,
        __concat = function() error("Attempt to concat secret value") end,
        __len = function() error("Attempt to measure secret value") end,
    })
end

local function CreateHarness(opts)
    opts = opts or {}
    local env = {}
    setmetatable(env, { __index = _G })
    env._G = env

    local now = 100.0
    local epochNow = opts.epochNow or 1700000000
    local timers = {}
    local eventFrames = {}
    local createdWidgets = {}
    local calls = {
        AddMessage = {},
        OpenTemporaryWindow = {},
        FCF_Close = {},
        ReloadUI = 0,
        chatLog = {},
    }

    local state = {
        inCombat = false,
        inPetBattle = false,
        keystoneActive = false,
        encounterInProgress = false,
        nextTempIdx = 11,
        clearTargetOnClose = false,
    }

    env.time = function() return epochNow end
    env.date = function() return "21:15" end
    env.GetTime = function() return now end
    env.GetScreenWidth = function() return 1920 end
    env.GetScreenHeight = function() return 1080 end
    env.InCombatLockdown = function() return state.inCombat end
    env.UnitAffectingCombat = function() return state.inCombat end
    env.IsEncounterInProgress = function() return state.encounterInProgress end
    env.IsShiftKeyDown = function() return false end
    env.IsControlKeyDown = function() return false end
    env.IsAltKeyDown = function() return false end
    env.IsModifierKeyDown = function() return false end
    env.IsMouseButtonDown = function() return false end
    env.GetCursorPosition = function() return 400, 300 end
    env.PlaySound = function() end
    env.PlaySoundFile = function() end
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
    env.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
        table.insert(calls.chatLog, table.concat(parts, " "))
    end
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
    }

    local function NewWidget(wType, name, parent)
        local w = {
            _type = wType,
            _name = name,
            _parent = parent,
            _shown = true,
            _alpha = 1,
            _mouse = true,
            _scale = 1,
            _width = 430,
            _height = 200,
            _level = 2,
            _strata = "LOW",
            _clipsChildren = false,
            _points = { { "BOTTOMLEFT", nil, "BOTTOMLEFT", 40, 60 } },
            _scripts = {},
            _events = {},
            _attrs = {},
            _text = "",
            _messages = {},
            _setParentCalls = 0,
            _hideCalls = 0,
            _showCalls = 0,
        }
        function w:GetName() return self._name end
        function w:GetObjectType() return self._type end
        function w:SetParent(p) self._setParentCalls = self._setParentCalls + 1; self._parent = p end
        function w:GetParent() return self._parent end
        function w:Show() self._showCalls = self._showCalls + 1; self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end
        function w:Hide() self._hideCalls = self._hideCalls + 1; self._shown = false; if self._scripts.OnHide then self._scripts.OnHide(self) end end
        function w:SetShown(v) if v then self:Show() else self:Hide() end end
        function w:IsShown() return self._shown == true end
        function w:IsVisible() return self._shown == true end
        function w:IsForbidden() return false end
        function w:SetAlpha(a) self._alpha = a end
        function w:GetAlpha() return self._alpha end
        function w:EnableMouse(v) self._mouse = (v ~= false) end
        function w:IsMouseEnabled() return self._mouse == true end
        function w:EnableMouseWheel() end
        function w:EnableKeyboard() end
        function w:SetPropagateKeyboardInput() end
        function w:SetClampedToScreen() end
        function w:SetClampRectInsets() end
        function w:SetClipsChildren(v) self._clipsChildren = (v == true) end
        function w:GetClipsChildren() return self._clipsChildren end
        function w:SetMovable() end
        function w:SetResizable() end
        function w:SetResizeBounds() end
        function w:SetToplevel() end
        function w:SetUserPlaced() end
        function w:RegisterForDrag() end
        function w:RegisterForClicks() end
        function w:StartMoving() end
        function w:StopMovingOrSizing() end
        function w:Raise() end
        function w:SetFocus() end
        function w:ClearFocus() end
        function w:HasFocus() return false end
        function w:HighlightText() end
        function w:SetMultiLine() end
        function w:SetMaxLetters() end
        function w:SetAutoFocus() end
        function w:SetFontObject() end
        function w:SetSize(ww, hh) self._width = ww; self._height = hh end
        function w:SetWidth(ww) self._width = ww end
        function w:SetHeight(hh) self._height = hh end
        function w:GetWidth() return self._width end
        function w:GetHeight() return self._height end
        function w:GetCenter() return 255, 160 end
        function w:GetLeft() return 40 end
        function w:GetRight() return 40 + self._width end
        function w:GetTop() return 60 + self._height end
        function w:GetBottom() return 60 end
        function w:SetScale(s) self._scale = s end
        function w:GetScale() return self._scale end
        function w:GetEffectiveScale() return self._scale end
        function w:SetFrameStrata(s) self._strata = s end
        function w:GetFrameStrata() return self._strata end
        function w:SetFrameLevel(l) self._level = l end
        function w:GetFrameLevel() return self._level end
        function w:SetHitRectInsets() end
        function w:IsMouseOver() return false end
        function w:ClearAllPoints() self._points = {} end
        function w:SetPoint(pt, relTo, relPt, x, y) table.insert(self._points, { pt, relTo, relPt, x, y }) end
        function w:SetAllPoints(p) self._points = { { "ALL", p, "ALL", 0, 0 } } end
        function w:GetNumPoints() return #self._points end
        function w:GetPoint(i) local p = self._points[i]; if not p then return nil end; return p[1], p[2], p[3], p[4], p[5] end
        function w:SetAttribute(k, v) self._attrs[k] = v end
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
        function w:SetCursorPosition() end
        function w:SetAltArrowKeyMode() end
        function w:SetFont() return true end
        function w:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
        function w:SetShadowColor() end
        function w:SetShadowOffset() end
        function w:SetTextColor() end
        function w:SetJustifyH() end
        function w:SetJustifyV() end
        function w:SetWordWrap() end
        function w:SetSpacing() end
        function w:SetMaxLines() end
        function w:GetStringHeight() return 18 end
        function w:GetStringWidth() return 56 end
        function w:GetUnboundedStringWidth() return 56 end
        function w:GetFontString() return w._fs end
        function w:GetHighlightTexture() return nil end
        function w:GetNormalTexture() return nil end
        function w:GetPushedTexture() return nil end
        function w:SetEnabled() end
        function w:IsEnabled() return true end
        function w:GetScrollOffset() return 0 end
        function w:SetScrollOffset() end
        function w:SetVerticalScroll() end
        function w:GetVerticalScroll() return 0 end
        function w:SetScrollChild(c) self._scrollChild = c end
        function w:GetNumMessages() return #self._messages end
        function w:GetMessageInfo(i)
            local m = self._messages[i]
            if type(m) == "table" and m.__testSecret then return m end
            if type(m) == "table" and m.text ~= nil then return m.text, m.r or 1, m.g or 1, m.b or 1 end
            return m, 1, 1, 1
        end
        function w:AddMessage(m)
            table.insert(calls.AddMessage, { frame = self._name or tostring(self), msg = m })
            table.insert(self._messages, m)
        end
        function w:Clear() self._messages = {} end
        function w:SetColorTexture() end
        function w:SetTexture() end
        function w:GetTexture() return nil end
        function w:SetTexCoord() end
        function w:SetRotation() end
        function w:SetHorizTile() end
        function w:SetVertTile() end
        function w:SetVertexColor() end
        function w:SetDesaturated() end
        function w:SetSnapToPixelGrid() end
        function w:SetTexelSnappingBias() end
        function w:SetBackdrop() end
        function w:SetBackdropColor() end
        function w:SetBackdropBorderColor() end
        function w:SetOrientation() end
        function w:SetMinMaxValues() end
        function w:SetValue(v) self._sliderVal = v end
        function w:GetValue() return self._sliderVal or 0 end
        function w:SetValueStep() end
        function w:SetObeyStepOnDrag() end
        function w:SetThumbTexture() end
        function w:SetStepsPerPage() end
        function w:SetOwner() end
        function w:ClearLines() end
        function w:AddLine() end
        function w:CreateTexture() return NewWidget("Texture", nil, self) end
        function w:CreateFontString() local fs = NewWidget("FontString", nil, self); self._fs = fs; return fs end
        table.insert(createdWidgets, w)
        if name then env[name] = w end
        return w
    end

    env.UIParent = NewWidget("Frame", "UIParent", nil)
    env.UIParent._width = 1920
    env.UIParent._height = 1080
    env.DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, m) table.insert(calls.chatLog, tostring(m)) end,
    }
    env.GameTooltip = NewWidget("GameTooltip", "GameTooltip", env.UIParent)
    env.UISpecialFrames = {}
    env.SlashCmdList = {}
    env.hash_SlashCmdList = {}
    env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    env.SOUNDKIT = { READY_CHECK = 8960, IG_PLAYER_INVITE = 880, IG_MAINMENU_OPTION = 1 }
    env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    env.UNKNOWNOBJECT = "Unknown"
    env.NUM_CHAT_WINDOWS = 10
    env.CHAT_FRAMES = { "ChatFrame1", "ChatFrame2" }

    env.GeneralDockManager = NewWidget("Frame", "GeneralDockManager", env.UIParent)
    env.GeneralDockManagerOverflowButton = NewWidget("Button", "GeneralDockManagerOverflowButton", env.GeneralDockManager)
    env.GeneralDockManagerScrollFrame = NewWidget("ScrollFrame", "GeneralDockManagerScrollFrame", env.GeneralDockManager)
    env.GeneralDockManagerScrollFrameChild = NewWidget("Frame", "GeneralDockManagerScrollFrameChild", env.GeneralDockManagerScrollFrame)
    env.ChatFrameChannelButton = NewWidget("Button", "ChatFrameChannelButton", env.UIParent)
    env.ChatFrameMenuButton = NewWidget("Button", "ChatFrameMenuButton", env.UIParent)
    env.ChatFrameToggleVoiceDeafenButton = NewWidget("Button", "ChatFrameToggleVoiceDeafenButton", env.UIParent)
    env.ChatFrameToggleVoiceMuteButton = NewWidget("Button", "ChatFrameToggleVoiceMuteButton", env.UIParent)
    env.QuickJoinToastButton = NewWidget("Button", "QuickJoinToastButton", env.UIParent)

    local dockedFrames = {}
    for i = 1, 10 do
        local name = "ChatFrame" .. i
        local cf = NewWidget("ScrollingMessageFrame", name, env.UIParent)
        cf.FontStringContainer = NewWidget("Frame", nil, cf)
        cf.Background = NewWidget("Texture", name .. "Background", cf)
        cf.isDocked = (i <= 2)
        if i > 2 then cf._shown = false end
        local tab = NewWidget("Button", name .. "Tab", env.GeneralDockManager)
        tab.Text = tab:CreateFontString()
        tab.Text:SetText(i == 1 and "General" or (i == 2 and "Combat Log" or ("Tab" .. i)))
        if i > 2 then tab._shown = false end
        local eb = NewWidget("EditBox", name .. "EditBox", cf)
        eb.header = eb:CreateFontString()
        eb.headerSuffix = eb:CreateFontString()
        eb:SetAttribute("chatType", "SAY")
        NewWidget("Frame", name .. "ButtonFrame", cf)
        NewWidget("Button", name .. "MinimizeButton", cf)
        if i <= 2 then
            table.insert(dockedFrames, cf)
        end
    end
    env.GeneralDockManager.DOCKED_CHAT_FRAMES = dockedFrames
    env.SELECTED_DOCK_FRAME = env.ChatFrame1
    env.DEFAULT_CHAT_FRAME.editBox = env.ChatFrame1EditBox

    local function CreateTempWhisperWindow(chatType, chatTarget, optsTemp)
        optsTemp = optsTemp or {}
        local idx = state.nextTempIdx
        state.nextTempIdx = idx + 1
        local name = "ChatFrame" .. idx
        local cf = NewWidget("ScrollingMessageFrame", name, env.UIParent)
        cf.FontStringContainer = NewWidget("Frame", nil, cf)
        cf.Background = NewWidget("Texture", name .. "Background", cf)
        cf.isTemporary = true
        cf.isDocked = true
        cf.chatType = chatType
        cf.chatTarget = chatTarget
        cf.name = (type(chatTarget) == "string") and chatTarget or name

        local tabParent = optsTemp.parent or env.GeneralDockManagerScrollFrameChild
        local tab = NewWidget("Button", name .. "Tab", tabParent)
        tab.Text = tab:CreateFontString()
        tab.Text:SetText(cf.name)
        tab.conversationIcon = tab:CreateTexture()
        tab._shown = true
        if optsTemp.textWidth then
            tab.Text.GetUnboundedStringWidth = function() return optsTemp.textWidth end
            tab.Text.GetStringWidth = function() return optsTemp.textWidth end
        end

        local eb = NewWidget("EditBox", name .. "EditBox", cf)
        eb.header = eb:CreateFontString()
        eb.headerSuffix = eb:CreateFontString()
        eb:SetAttribute("chatType", chatType)
        eb:SetAttribute("tellTarget", chatTarget)
        NewWidget("Frame", name .. "ButtonFrame", cf)
        NewWidget("Button", name .. "MinimizeButton", cf)

        table.insert(env.CHAT_FRAMES, name)
        table.insert(env.GeneralDockManager.DOCKED_CHAT_FRAMES, cf)
        env.SELECTED_DOCK_FRAME = cf
        return cf, tab
    end

    env.FCF_SelectDockFrame = function(cf)
        env.SELECTED_DOCK_FRAME = cf
    end
    env.FCF_OpenTemporaryWindow = function(chatType, chatTarget)
        table.insert(calls.OpenTemporaryWindow, { chatType = chatType, chatTarget = chatTarget })
        -- Check if already open (non-secret)
        for _, cf in ipairs(env.GeneralDockManager.DOCKED_CHAT_FRAMES) do
            if cf.isTemporary and cf.chatType == chatType and cf.chatTarget == chatTarget then
                env.SELECTED_DOCK_FRAME = cf
                return cf
            end
        end
        local cf = CreateTempWhisperWindow(chatType, chatTarget)
        return cf
    end
    env.FCF_Close = function(cf)
        table.insert(calls.FCF_Close, cf)
        if not cf then return end
        local name = cf:GetName()
        cf.isDocked = false
        cf:Hide()
        if name and env[name .. "Tab"] then
            env[name .. "Tab"]:Hide()
        end
        for idx = #env.GeneralDockManager.DOCKED_CHAT_FRAMES, 1, -1 do
            if env.GeneralDockManager.DOCKED_CHAT_FRAMES[idx] == cf then
                table.remove(env.GeneralDockManager.DOCKED_CHAT_FRAMES, idx)
            end
        end
        if state.clearTargetOnClose then
            cf.chatTarget = nil
        end
        if env.SELECTED_DOCK_FRAME == cf then
            env.SELECTED_DOCK_FRAME = env.ChatFrame1
        end
    end
    env.FCF_SetTemporaryWindowType = function() end
    env.FCFDock_UpdateTabs = function() end
    env.FCF_DockUpdate = function() end
    env.ReloadUI = function() calls.ReloadUI = calls.ReloadUI + 1 end
    env.C_UI = { Reload = function() calls.ReloadUI = calls.ReloadUI + 1 end }

    env.ChatEdit_GetActiveWindow = function() return env.ChatFrame1EditBox end
    env.ChatEdit_ChooseBoxForSend = function() return env.ChatFrame1EditBox end
    env.ChatEdit_ActivateChat = function() end
    env.ChatEdit_UpdateHeader = function() end
    env.ChatFrame_SendTell = function() end

    env.C_AddOns = {
        GetAddOnMetadata = function() return "2.11.2" end,
        IsAddOnLoaded = function() return false end,
        GetAddOnEnableState = function() return 0 end,
        LoadAddOn = function() end,
    }
    env.C_EventUtils = { IsEventValid = function() return true end }
    env.C_PetBattles = { IsInBattle = function() return state.inPetBattle end }
    env.C_ChallengeMode = { IsChallengeModeActive = function() return state.keystoneActive end }
    env.C_InstanceEncounter = { IsEncounterInProgress = function() return state.encounterInProgress end }
    env.C_ChatInfo = {
        InChatMessagingLockdown = function() return false end,
        SendChatMessage = function() end,
    }
    env.SendChatMessage = env.C_ChatInfo.SendChatMessage
    env.UnitName = function() return "Dentee" end
    env.UnitClass = function() return "Mage", "MAGE", 8 end
    env.GetRealmName = function() return "Frostmourne" end
    env.GetNormalizedRealmName = function() return "Frostmourne" end
    env.UnitGUID = function() return "Player-3725-00000001" end
    env.GetNumFriends = function() return 0 end
    env.BNGetNumFriends = function() return 0 end
    env.GetNumGuildMembers = function() return 0, 0 end
    env.GetInventoryItemDurability = function() return 100, 100 end
    env.LoggingCombat = function() return false end
    env.C_FriendList = { GetNumFriends = function() return 0 end }
    env.C_WeeklyRewards = { GetActivities = function() return {} end }
    env.C_MythicPlus = { GetOwnedKeystoneLevel = function() return nil end }

    env.CreateFrame = function(wType, name, parent)
        local f = NewWidget(wType, name, parent)
        table.insert(eventFrames, f)
        return f
    end

    if opts.withSuite ~= false then
        env.DynamicSuite = {
            version = "2.11.2",
            modules = {},
            Changelogs = {},
            RegisterModule = function(self, key, reg)
                if type(key) == "table" and reg == nil then
                    reg = key
                    key = reg.key
                end
                self.modules[key] = reg
            end,
            GetSuiteAccent = function() return 0.22, 0.74, 0.97 end,
        }
        env.DynamicSuiteDB = { global = { disabledModules = {} } }
    end

    if opts.initialDB then
        env.DynamicChatDB = env.CopyTable(opts.initialDB)
    end

    local function LoadModule(addonFolder)
        local chunk, err = loadfile(CHAT_PATH)
        if not chunk then error("Failed to load " .. CHAT_PATH .. ": " .. tostring(err)) end
        setfenv(chunk, env)
        chunk(addonFolder or (opts.withSuite ~= false and "DynamicSuite" or "DynamicChat"))
    end

    local function FireEvent(event, a1, a2, a3, a4)
        for i = 1, #eventFrames do
            local f = eventFrames[i]
            if f._events[event] and f._scripts.OnEvent then
                f._scripts.OnEvent(f, event, a1, a2, a3, a4)
            end
        end
    end

    local function AdvanceTime(dt)
        local target = now + (dt or 0)
        local guard = 0
        while guard < 100 do
            guard = guard + 1
            local nextIdx, nextAt = nil, nil
            for i = 1, #timers do
                local t = timers[i]
                if not t.cancelled and t.at <= target then
                    if not nextAt or t.at < nextAt then
                        nextAt = t.at
                        nextIdx = i
                    end
                end
            end
            if not nextIdx then break end
            local t = table.remove(timers, nextIdx)
            now = math.max(now, t.at)
            t.fn()
        end
        now = target
    end

    return {
        env = env,
        state = state,
        calls = calls,
        createdWidgets = createdWidgets,
        CreateTempWhisperWindow = CreateTempWhisperWindow,
        LoadModule = LoadModule,
        FireEvent = FireEvent,
        AdvanceTime = AdvanceTime,
        SetEpoch = function(v) epochNow = v end,
    }
end

local function RunTest(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("[PASS] " .. name)
    else
        failed = failed + 1
        print("[FAIL] " .. name)
        print("       " .. tostring(err))
    end
end

-- ============================================================================
-- T1: Whisper Tab Layering, Scale Sync & Nav Anchor Separation
-- ============================================================================
RunTest("T1: Layering, Dock Scale Sync & Clickability for Whisper / BNet Tabs", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule("DynamicSuite")
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")

    h.env.ChatFrame1:SetScale(0.85)
    local _, wTab = h.CreateTempWhisperWindow("WHISPER", "Alice-Frostmourne")
    local _, bTab = h.CreateTempWhisperWindow("BN_WHISPER", "BNetPal")

    h.env.DynamicChat:ApplySleekChatSkin()

    -- Find headerDragStrip (Frame attached to headerBg, created in ApplySleekChatSkin)
    local dragStrip = nil
    local navFrame = nil
    for _, w in ipairs(h.createdWidgets) do
        if w._scripts and w._scripts.OnDragStart and w._scripts.OnMouseWheel and w:GetParent() == h.env.UIParent and not w.socialBtn then
            dragStrip = w
        elseif w.leftBtn and w.rightBtn then
            navFrame = w
        end
    end

    assertTrue(dragStrip ~= nil, "headerDragStrip must exist")
    assertEqual(dragStrip:GetFrameStrata(), "BACKGROUND", "headerDragStrip must be on BACKGROUND strata so it never intercepts tab clicks")
    assertEqual(dragStrip:GetFrameLevel(), 2, "headerDragStrip frame level must be 2")

    assertEqual(h.env.ChatFrame1Tab:GetFrameStrata(), "LOW", "ChatFrame1Tab must be on LOW strata")
    assertEqual(h.env.ChatFrame1Tab:GetFrameLevel(), 22, "ChatFrame1Tab must be at frame level 22")
    assertEqual(wTab:GetFrameStrata(), "LOW", "Temporary Whisper tab must be on LOW strata")
    assertEqual(wTab:GetFrameLevel(), 22, "Temporary Whisper tab must be at frame level 22")
    assertEqual(wTab:IsMouseEnabled(), true, "Temporary Whisper tab must be mouse enabled")
    assertEqual(bTab:GetFrameStrata(), "LOW", "Temporary BNet Whisper tab must be on LOW strata")
    assertEqual(bTab:GetFrameLevel(), 22, "Temporary BNet Whisper tab must be at frame level 22")
    assertEqual(bTab:IsMouseEnabled(), true, "Temporary BNet Whisper tab must be mouse enabled")

    assertTrue(navFrame ~= nil, "tabNavFrame must exist")
    assertEqual(navFrame:GetFrameStrata(), "LOW", "tabNavFrame must be on LOW strata")
    assertEqual(navFrame:GetFrameLevel(), 25, "tabNavFrame must be at frame level 25")

    assertEqual(h.env.GeneralDockManager:GetScale(), 0.85, "GeneralDockManager scale must match ChatFrame1 scale 0.85")
    local dockPt, _, _, dockRightX = h.env.GeneralDockManager:GetPoint(2)
    local navPt, _, _, navRightX = navFrame:GetPoint(1)
    assertEqual(dockPt, "BOTTOMRIGHT", "dock anchored BOTTOMRIGHT")
    assertEqual(dockRightX, -30, "dock right edge stops 38px left of navFrame (+8 - 38 = -30)")
    assertEqual(navPt, "BOTTOMRIGHT", "navFrame anchored BOTTOMRIGHT")
    assertEqual(navRightX, 8, "navFrame sits strictly outside dock right edge")

    -- Re-test scale sync when ChatFrame1 changes scale to 1.20
    h.env.ChatFrame1:SetScale(1.20)
    h.env.DynamicChat:ApplySleekChatSkin()
    assertEqual(h.env.GeneralDockManager:GetScale(), 1.20, "GeneralDockManager scale must update to match ChatFrame1 scale 1.20")
end)

-- ============================================================================
-- T2: Reparenting from ScrollFrameChild, Combat Deferral, Re-Entrancy & Viewport
-- ============================================================================
RunTest("T2: Reparenting, Combat-Deferred Open, Re-Entrant Layout & Auto-Viewport", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule("DynamicSuite")
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")

    -- Make tabs wide enough so opening new whisper tabs requires viewport scrolling
    for i = 1, 4 do
        local cf = h.env["ChatFrame" .. i]
        local tab = h.env["ChatFrame" .. i .. "Tab"]
        cf.isDocked = true
        cf._shown = true
        tab._shown = true
        tab.Text.GetUnboundedStringWidth = function() return 110 end
        tab.Text.GetStringWidth = function() return 110 end
        if i > 2 then
            table.insert(h.env.GeneralDockManager.DOCKED_CHAT_FRAMES, cf)
            table.insert(h.env.CHAT_FRAMES, "ChatFrame" .. i)
        end
    end
    h.env.DynamicChat:ApplySleekChatSkin()

    -- Out of combat: FCF_OpenTemporaryWindow creates a tab parented to GeneralDockManagerScrollFrameChild
    local cfAlice = h.env.FCF_OpenTemporaryWindow("WHISPER", "Alice")
    local tabAlice = h.env[cfAlice:GetName() .. "Tab"]
    assertEqual(tabAlice:GetParent(), h.env.GeneralDockManager, "Alice tab must be reparented to GeneralDockManager")
    assertEqual(tabAlice:IsShown(), true, "Newly opened Alice whisper tab must be scrolled into visible viewport and shown")
    assertEqual(tabAlice:GetFrameLevel(), 22, "Newly opened Alice tab must be at level 22")

    -- During combat: FCF_OpenTemporaryWindow leaves tab on ScrollFrameChild until PLAYER_REGEN_ENABLED
    h.state.inCombat = true
    local cfBob = h.env.FCF_OpenTemporaryWindow("WHISPER", "Bob")
    local tabBob = h.env[cfBob:GetName() .. "Tab"]
    assertEqual(tabBob:GetParent(), h.env.GeneralDockManagerScrollFrameChild, "Must NOT call SetParent during combat lockdown")
    assertTrue(h.env.DynamicChat._pendingTabLayoutAfterCombat == true, "_pendingTabLayoutAfterCombat must be flagged in combat")
    assertEqual(h.env.DynamicChat._pendingVisibleTabAfterCombat, cfBob, "_pendingVisibleTabAfterCombat must track combat-opened whisper tab")

    h.state.inCombat = false
    h.FireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(tabBob:GetParent(), h.env.GeneralDockManager, "PLAYER_REGEN_ENABLED must reparent Bob tab to GeneralDockManager")
    assertEqual(tabBob:IsShown(), true, "PLAYER_REGEN_ENABLED must bring Bob tab into visible viewport")

    -- Re-entrant open while isLayingOutDockedTabs is active -> deferred next-frame reparent pass
    local triggeredReentrant = false
    local origEnsureHook = h.env.GeneralDockManager.SetClipsChildren
    h.env.GeneralDockManager.SetClipsChildren = function(selfDock, v)
        origEnsureHook(selfDock, v)
        if not triggeredReentrant then
            triggeredReentrant = true
            h.env.FCF_OpenTemporaryWindow("WHISPER", "Charlie")
        end
    end
    h.env.DynamicChat:ApplySleekChatSkin()
    h.AdvanceTime(0)
    local cfCharlie = h.env.SELECTED_DOCK_FRAME
    local tabCharlie = h.env[cfCharlie:GetName() .. "Tab"]
    assertEqual(tabCharlie:GetParent(), h.env.GeneralDockManager, "Deferred next-frame layout must reparent re-entrant Charlie tab")
    assertEqual(tabCharlie:IsShown(), true, "Deferred next-frame layout must show Charlie tab in visible viewport")
end)

-- ============================================================================
-- T3: Snapshot Capping, 24-Hour Pruning, Secret Skipping & Session Log Merge
-- ============================================================================
RunTest("T3: Snapshot Capping (Tabs & 50 Lines), 24h Pruning & Secret Skipping", function()
    local epoch = 1700000000
    local h = CreateHarness({
        withSuite = true,
        epochNow = epoch,
        initialDB = {
            preserveChatHistory = true,
            preserveWhisperTabs = true,
            maxSavedWhisperTabs = 5,
            maxSavedWhisperLines = 50,
            savedWhisperTabs = {
                { target = "ExpiredOld", chatType = "WHISPER", lastUpdated = epoch - (25 * 3600), lines = { "old msg" } },
            },
        },
    })
    h.LoadModule("DynamicSuite")
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")

    -- 1. Alice tab with 65 lines + 1 secret line + 1 out-of-combat session plain log line
    local cfAlice = h.CreateTempWhisperWindow("WHISPER", "Alice-Frostmourne", { parent = h.env.GeneralDockManager })
    for i = 1, 65 do
        table.insert(cfAlice._messages, "[21:00] Alice whispers: msg " .. i)
    end
    table.insert(cfAlice._messages, MakeSecret("secret-line"))

    -- 2. Secret-target tab (must be skipped completely)
    local cfSecret = h.CreateTempWhisperWindow("WHISPER", MakeSecret("secret-target"), { parent = h.env.GeneralDockManager })
    table.insert(cfSecret._messages, "should not save")

    -- 3. BN_WHISPER tab (character whisper only, must be skipped)
    local cfBNet = h.CreateTempWhisperWindow("BN_WHISPER", "RealIDFriend", { parent = h.env.GeneralDockManager })
    table.insert(cfBNet._messages, "bnet msg")

    -- 4. 6 additional valid character whisper tabs (total 7 valid -> capped to 5)
    for k = 1, 6 do
        local cfOther = h.CreateTempWhisperWindow("WHISPER", "Player" .. k, { parent = h.env.GeneralDockManager })
        table.insert(cfOther._messages, "hello from " .. k)
    end

    -- Inject out-of-combat session plain log entry for Alice that isn't in cfAlice._messages
    h.env.DynamicChat._sessionPlainLog = {
        {
            line = "[21:15] [W] Alice-Frostmourne: session buffered line",
            msg = "session buffered line",
            author = "Alice-Frostmourne",
            groupType = "WHISPER",
        },
    }

    h.FireEvent("PLAYER_LOGOUT")

    local saved = h.env.DynamicChatDB.savedWhisperTabs
    assertEqual(#saved, 5, "savedWhisperTabs must be capped to maxSavedWhisperTabs = 5")

    local foundAlice, foundExpired, foundBNet = nil, false, false
    for _, item in ipairs(saved) do
        if item.target == "Alice-Frostmourne" then foundAlice = item end
        if item.target == "ExpiredOld" then foundExpired = true end
        if item.target == "RealIDFriend" then foundBNet = true end
        assertEqual(item.chatType, "WHISPER", "Saved entries must have chatType WHISPER")
        assertTrue(#item.lines <= 50, "Each tab must be capped at 50 lines")
    end
    assertEqual(foundExpired, false, "Expired >24h entry must be pruned")
    assertEqual(foundBNet, false, "BN_WHISPER tab must not be persisted")

    -- Explicitly test Alice lines cap & session merge with maxSavedWhisperTabs=10
    h.env.DynamicChatDB.maxSavedWhisperTabs = 10
    h.FireEvent("PLAYER_LOGOUT")
    saved = h.env.DynamicChatDB.savedWhisperTabs
    for _, item in ipairs(saved) do
        if item.target == "Alice-Frostmourne" then foundAlice = item end
    end
    assertTrue(foundAlice ~= nil, "Alice-Frostmourne must be saved when within cap")
    assertEqual(#foundAlice.lines, 50, "Alice lines must be capped to 50")
    assertEqual(foundAlice.lines[50], "[21:15] [W] Alice-Frostmourne: session buffered line", "Session plain log line must be merged at tail")
    assertEqual(foundAlice.lines[1], "[21:00] Alice whispers: msg 17", "Oldest lines beyond 50 (plus secret skipped) trimmed cleanly")
end)

-- ============================================================================
-- T4: Zero-Taint Restore (Out of Combat & Combat-Deferred) + Multi-Reload Retention
-- ============================================================================
RunTest("T4: Zero-Taint Restore (0 AddMessage Calls), Combat Deferral & Multi-Reload Retention", function()
    local epoch = 1700000000
    local seedDB = {
        preserveChatHistory = true,
        preserveWhisperTabs = true,
        maxSavedWhisperTabs = 5,
        maxSavedWhisperLines = 50,
        savedWhisperTabs = {
            { target = "Alice", chatType = "WHISPER", lastUpdated = epoch - 60, lines = { "Alice line 1", "Alice line 2" } },
            { target = "Bob", chatType = "WHISPER", lastUpdated = epoch - 120, lines = { "Bob line 1" } },
            { target = "StaleOld", chatType = "WHISPER", lastUpdated = epoch - (26 * 3600), lines = { "expired" } },
        },
    }

    -- Out of combat restore
    local h1 = CreateHarness({ withSuite = true, epochNow = epoch, initialDB = seedDB })
    h1.LoadModule("DynamicSuite")
    h1.FireEvent("ADDON_LOADED", "DynamicSuite")
    h1.FireEvent("PLAYER_LOGIN")
    h1.FireEvent("PLAYER_ENTERING_WORLD")
    h1.AdvanceTime(0.2)

    assertEqual(#h1.calls.OpenTemporaryWindow, 2, "Exactly 2 valid saved whisper tabs reopened (expired skipped)")
    assertEqual(h1.calls.OpenTemporaryWindow[1].chatTarget, "Alice", "First restored whisper tab is Alice")
    assertEqual(h1.calls.OpenTemporaryWindow[2].chatTarget, "Bob", "Second restored whisper tab is Bob")
    assertEqual(#h1.calls.AddMessage, 0, "Zero-taint: must NEVER call AddMessage() on live Blizzard frames")
    assertEqual(h1.env.SELECTED_DOCK_FRAME, h1.env.ChatFrame1, "Selected dock frame must remain on ChatFrame1 after restore")

    -- Reload again with 0 new messages -> previously saved lines must be retained
    h1.env.ReloadUI()
    local retainedAlice = nil
    for _, item in ipairs(h1.env.DynamicChatDB.savedWhisperTabs) do
        if item.target == "Alice" then retainedAlice = item end
    end
    assertTrue(retainedAlice ~= nil, "Alice must remain in savedWhisperTabs across second reload")
    assertEqual(#retainedAlice.lines, 2, "Alice saved lines must be retained when no new messages arrived")

    -- Combat-deferred restore
    local h2 = CreateHarness({ withSuite = true, epochNow = epoch, initialDB = seedDB })
    h2.state.inCombat = true
    h2.LoadModule("DynamicSuite")
    h2.FireEvent("ADDON_LOADED", "DynamicSuite")
    h2.FireEvent("PLAYER_LOGIN")
    h2.FireEvent("PLAYER_ENTERING_WORLD")
    h2.AdvanceTime(0.2)

    assertEqual(#h2.calls.OpenTemporaryWindow, 0, "Must NOT call FCF_OpenTemporaryWindow during combat")
    assertTrue(h2.env.DynamicChat._pendingWhisperTabRestoreAfterCombat == true, "Must flag _pendingWhisperTabRestoreAfterCombat in combat")

    h2.state.inCombat = false
    h2.FireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(#h2.calls.OpenTemporaryWindow, 2, "PLAYER_REGEN_ENABLED must reopen saved whisper tabs")
    assertEqual(#h2.calls.AddMessage, 0, "Zero-taint: 0 AddMessage calls after combat-deferred restore")
end)

-- ============================================================================
-- T5: Closing Whisper Tabs (Middle-Click + Blizzard FCF_Close) & Clear History
-- ============================================================================
RunTest("T5: Middle-Click & Blizzard FCF_Close Remove Target from savedWhisperTabs", function()
    local epoch = 1700000000
    local h = CreateHarness({
        withSuite = true,
        epochNow = epoch,
        initialDB = {
            preserveChatHistory = true,
            preserveWhisperTabs = true,
            savedWhisperTabs = {
                { target = "Alice", chatType = "WHISPER", lastUpdated = epoch - 30, lines = { "hi alice" } },
                { target = "Bob", chatType = "WHISPER", lastUpdated = epoch - 60, lines = { "hi bob" } },
                { target = "Charlie", chatType = "WHISPER", lastUpdated = epoch - 90, lines = { "hi charlie" } },
            },
        },
    })
    h.state.clearTargetOnClose = true
    h.LoadModule("DynamicSuite")
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")
    h.FireEvent("PLAYER_ENTERING_WORLD")
    h.AdvanceTime(0.2)

    local cfAlice, cfBob = nil, nil
    for _, cf in ipairs(h.env.GeneralDockManager.DOCKED_CHAT_FRAMES) do
        if cf.chatTarget == "Alice" then cfAlice = cf end
        if cf.chatTarget == "Bob" then cfBob = cf end
    end
    assertTrue(cfAlice and cfBob, "Restored Alice and Bob frames must exist")

    -- Middle-Click Alice tab
    local tabAlice = h.env[cfAlice:GetName() .. "Tab"]
    tabAlice:GetScript("OnClick")(tabAlice, "MiddleButton")
    assertEqual(#h.env.DynamicChatDB.savedWhisperTabs, 2, "Middle-Click close must remove Alice from savedWhisperTabs")
    for _, item in ipairs(h.env.DynamicChatDB.savedWhisperTabs) do
        assertTrue(item.target ~= "Alice", "Alice must no longer be in savedWhisperTabs")
    end

    -- Blizzard FCF_Close(cfBob) (even when Blizzard clears cf.chatTarget inside FCF_Close)
    h.env.FCF_Close(cfBob)
    assertEqual(#h.env.DynamicChatDB.savedWhisperTabs, 1, "FCF_Close must remove Bob from savedWhisperTabs")
    assertEqual(h.env.DynamicChatDB.savedWhisperTabs[1].target, "Charlie", "Only Charlie should remain")
end)

-- ============================================================================
-- T6: History Modal Rendering, Tab 4 Settings UI & Standalone Parity
-- ============================================================================
RunTest("T6: Copy Chat Modal Divider, Tab 4 Settings & Standalone Mode Parity", function()
    local epoch = 1700000000
    local seedDB = {
        preserveChatHistory = true,
        preserveWhisperTabs = true,
        maxSavedWhisperTabs = 5,
        drawerExpanded = { chatHistory = true },
        savedWhisperTabs = {
            { target = "Alice", chatType = "WHISPER", lastUpdated = epoch - 30, lines = { "[20:55] Alice: saved line 1", "[20:56] To Alice: saved line 2" } },
        },
    }

    local function VerifyMode(withSuite, addonFolder)
        local h = CreateHarness({ withSuite = withSuite, epochNow = epoch, initialDB = seedDB })
        h.LoadModule(addonFolder)
        h.FireEvent("ADDON_LOADED", addonFolder)
        h.FireEvent("PLAYER_LOGIN")
        h.FireEvent("PLAYER_ENTERING_WORLD")
        h.AdvanceTime(0.2)

        local cfAlice = nil
        for _, cf in ipairs(h.env.GeneralDockManager.DOCKED_CHAT_FRAMES) do
            if cf.chatTarget == "Alice" then cfAlice = cf end
        end
        assertTrue(cfAlice ~= nil, addonFolder .. ": Restored Alice whisper frame must exist")

        -- Simulate 1 live message in current session
        table.insert(cfAlice._messages, "[21:15] Alice: current session line")
        h.env.DynamicChat:ShowFullChatHistoryModal(cfAlice)

        local modal = h.env.DynamicChatHistoryModal
        assertTrue(modal and modal.editBox, addonFolder .. ": History modal must open")
        local txt = modal.editBox:GetText()
        local p1 = txt:find("saved line 1", 1, true)
        local p2 = txt:find("saved line 2", 1, true)
        local pDiv = txt:find("--- Saved From Previous Session ---", 1, true)
        local pLive = txt:find("current session line", 1, true)
        assertTrue(p1 and p2 and pDiv and pLive, addonFolder .. ": Modal must contain saved lines, divider, and live line")
        assertTrue(p1 < p2 and p2 < pDiv and pDiv < pLive, addonFolder .. ": Saved lines must appear above divider and live line below")

        -- Verify Tab 4 controls exist (embed inside Suite or Standalone window)
        local parentFrame = h.env.CreateFrame("Frame", nil, h.env.UIParent)
        local root
        if withSuite then
            root = h.env.DynamicSuite.modules["chat"].RenderEmbedded(parentFrame)
            h.env.DynamicSuite.modules["chat"].SelectSubTab(4, true, { drawerKey = "chatHistory" })
        else
            local sf = h.env.DynamicChat._EnsureStandaloneWindow()
            h.env.DynamicChatDB.activeSubTab = 4
            h.env.DynamicChat:RefreshConfigUI()
            root = h.env.DynamicChat.embeddedRoot or sf
        end
        assertTrue(root ~= nil, addonFolder .. ": Config UI root must build")

        local keepCard, limitCard, clearBtn = nil, nil, nil
        for _, w in ipairs(h.createdWidgets) do
            if w.title and w.title:GetText() == "Keep Whisper Tabs After Reload" then
                keepCard = w
            elseif w.title and w.title:GetText() == "Whisper Tab Limit" then
                limitCard = w
            elseif w._fs and w._fs:GetText() == "Clear History" then
                clearBtn = w
            end
        end
        assertTrue(keepCard ~= nil, addonFolder .. ": Tab 4 must contain 'Keep Whisper Tabs After Reload' card")
        assertTrue(limitCard ~= nil, addonFolder .. ": Tab 4 must contain 'Whisper Tab Limit' card")
        assertEqual(limitCard:IsShown(), true, addonFolder .. ": Whisper Tab Limit must be shown when enabled")
        assertTrue(clearBtn ~= nil, addonFolder .. ": Clear History button must exist")

        -- Clear History wipes savedWhisperTabs
        clearBtn:GetScript("OnClick")(clearBtn, "LeftButton")
        assertEqual(#h.env.DynamicChatDB.savedWhisperTabs, 0, addonFolder .. ": Clear History must wipe savedWhisperTabs")

        -- Toggling 'Keep Whisper Tabs After Reload' Off hides 'Whisper Tab Limit'
        h.env.DynamicChatDB.preserveWhisperTabs = false
        h.env.DynamicChat:RefreshConfigUI()
        assertEqual(limitCard:IsShown(), false, addonFolder .. ": Whisper Tab Limit must hide when disabled")
    end

    VerifyMode(true, "DynamicSuite")
    VerifyMode(false, "DynamicChat")
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
