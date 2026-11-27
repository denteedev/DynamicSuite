-- ============================================================================
-- Headless Lua 5.1 Regression Suite: DynamicChat Whisper Tabs & Reload Persistence
-- Covers (Suite + Standalone parity):
--   T1. Layering, scale sync & clickability (headerDragStrip BACKGROUND, tabs LOW 22, nav LOW 25, dock scale)
--   T2. Reparenting from GeneralDockManagerScrollFrameChild, combat-deferred & re-entrant open + auto-viewport
--   T3. Whisper snapshot capping (maxSavedWhisperTabs / maxSavedWhisperLines), 24h pruning & secret-value skipping
--   T4. Zero-taint restore (FCF_OpenTemporaryWindow, 0 AddMessage calls, combat deferral, multi-reload retention)
--   T5. Closing whisper tabs (Middle-Click + Blizzard FCF_Close) & Clear History cleanup
--   T6. Copy Chat modal rendering ("--- Saved From Previous Session ---"), Tab 4 UI & Standalone parity
--   T7. Zero direct HookScript("OnTextChanged") on ChatFrameEditBox frames & post-hook /ww conversion
--   T8. BN_WHISPER secret tellTarget/header guards (ApplyToEditBox, SetPoint, /ww, promptHint hide/restore)
--   T9. StyleSingleChatTab skips tab:SetAlpha when tab.fadeInfo / secret alpha / UIFrameIsFading is active
--   T10. Temp BN_WHISPER zero background/button mutation, multi-EditBox focus race, fail-closed secret probes & UIFrameIsFlashing guard
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
            _hookScriptCalls = {},
            _setAlphaCalls = {},
            _setFontCalls = {},
            _setPointCalls = {},
            _clearAllPointsCalls = 0,
            _setTextCalls = {},
            _setAttrCalls = {},
            _altArrowCalls = {},
            _backdropBorderColor = nil,
            _hasFocus = false,
            _isFading = false,
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
        function w:SetAlpha(a) table.insert(self._setAlphaCalls, a); self._alpha = a end
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
        function w:SetFocus() self._hasFocus = true end
        function w:ClearFocus() self._hasFocus = false end
        function w:HasFocus() return self._hasFocus == true end
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
        function w:ClearAllPoints() self._clearAllPointsCalls = self._clearAllPointsCalls + 1; self._points = {} end
        function w:SetPoint(pt, relTo, relPt, x, y) table.insert(self._setPointCalls, { pt, relTo, relPt, x, y }); table.insert(self._points, { pt, relTo, relPt, x, y }) end
        function w:SetAllPoints(p) self._points = { { "ALL", p, "ALL", 0, 0 } } end
        function w:GetNumPoints() return #self._points end
        function w:GetPoint(i) local p = self._points[i]; if not p then return nil end; return p[1], p[2], p[3], p[4], p[5] end
        function w:SetAttribute(k, v) table.insert(self._setAttrCalls, { k = k, v = v }); self._attrs[k] = v end
        function w:GetAttribute(k) return self._attrs[k] end
        function w:SetScript(ev, fn) self._scripts[ev] = fn end
        function w:GetScript(ev) return self._scripts[ev] end
        function w:HookScript(ev, fn)
            table.insert(self._hookScriptCalls, ev)
            local prev = self._scripts[ev]
            self._scripts[ev] = function(...)
                if prev then prev(...) end
                fn(...)
            end
        end
        function w:RegisterEvent(ev) self._events[ev] = true end
        function w:UnregisterEvent(ev) self._events[ev] = nil end
        function w:UnregisterAllEvents() self._events = {} end
        function w:SetText(t) table.insert(self._setTextCalls, t); self._text = t end
        function w:GetText() return self._text end
        function w:SetCursorPosition() end
        function w:SetAltArrowKeyMode(v) table.insert(self._altArrowCalls, v) end
        function w:SetFont(p, s, fl) table.insert(self._setFontCalls, { p, s, fl }); return true end
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
        function w:SetBackdropBorderColor(r, g, b, a) self._backdropBorderColor = { r, g, b, a } end
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
        cf.NineSlice = NewWidget("Frame", name .. "NineSlice", cf)
        cf.ResizeButton = NewWidget("Button", name .. "ResizeButton", cf)
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
        tab.glow = tab:CreateTexture()
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
        cf.buttonFrame = NewWidget("Frame", name .. "ButtonFrame", cf)
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
    env.FCFTab_UpdateAlpha = function() end
    env.FCFTab_UpdateColors = function() end
    env.FCF_SetWindowAlpha = function() end
    env.FCF_SetWindowColor = function() end
    env.FCF_FadeInChatFrame = function() end
    env.FCF_FadeOutChatFrame = function() end
    env.FloatingChatFrame_UpdateBackgroundAnchors = function() end
    env.UIFrameIsFading = function(f) return (f and f._isFading == true) or false end
    env.UIFrameIsFlashing = function(f) return (f and f._isFlashing) or false end
    env.ReloadUI = function() calls.ReloadUI = calls.ReloadUI + 1 end
    env.C_UI = { Reload = function() calls.ReloadUI = calls.ReloadUI + 1 end }

    local regCallbacks = {}
    env.EventRegistry = {
        RegisterCallback = function(_, eventName, fn, owner)
            regCallbacks[eventName] = regCallbacks[eventName] or {}
            table.insert(regCallbacks[eventName], { fn = fn, owner = owner })
        end,
        TriggerEvent = function(_, eventName, ...)
            local list = regCallbacks[eventName]
            if not list then return end
            for _, entry in ipairs(list) do
                entry.fn(entry.owner, ...)
            end
        end,
    }

    if opts.idleEditBox == true then
        state.activeEditBox = nil
    else
        state.activeEditBox = env.ChatFrame1EditBox
    end
    env.ChatEdit_GetActiveWindow = function() return state.activeEditBox end
    env.ChatEdit_ChooseBoxForSend = function() return env.ChatFrame1EditBox end
    env.ChatEdit_ActivateChat = function() end
    env.ChatEdit_UpdateHeader = function() end
    env.ChatEdit_OnTextChanged = function() end
    env.ChatEdit_OnSpacePressed = function() end
    env.ChatFrameEditBoxMixin = {
        OnTextChanged = function() end,
        OnSpacePressed = function() end,
    }
    env.ChatFrame_SendTell = function() end
    env.UnitExists = function(u) return u == "target" and state.targetName ~= nil end
    env.UnitIsPlayer = function(u) return u == "target" and state.targetName ~= nil end
    env.UnitIsUnit = function() return false end
    env.UnitIsFriend = function(a, b) return b == "target" and state.targetName ~= nil end
    env.UnitInParty = function() return false end
    env.UnitInRaid = function() return false end
    env.GetUnitName = function(u) return (u == "target") and state.targetName or nil end

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

-- ============================================================================
-- T7: Zero Direct HookScript("OnTextChanged") on ChatFrameEditBox & /ww Post-Hooks
-- ============================================================================
RunTest("T7: Zero Direct EditBox HookScript('OnTextChanged') & hooksecurefunc /ww Conversion", function()
    local function VerifyMode(withSuite, addonFolder)
        local h = CreateHarness({ withSuite = withSuite, idleEditBox = true })
        for i = 1, 10 do
            h.env["ChatFrame" .. i .. "EditBox"]._shown = false
        end
        h.LoadModule(addonFolder)
        h.FireEvent("ADDON_LOADED", addonFolder)
        h.FireEvent("PLAYER_LOGIN")
        h.env.DynamicChat:ApplySleekChatSkin()
        h.env.DynamicChat:HookAllChatFramesAndEditBoxes()
        h.env.DynamicChat:HookSingleEditBox(h.env.ChatFrame1EditBox)
        h.env.ChatEdit_ActivateChat(h.env.ChatFrame1EditBox)

        local cfW = h.env.FCF_OpenTemporaryWindow("WHISPER", "Alice-Frostmourne")
        local cfBN = h.env.FCF_OpenTemporaryWindow("BN_WHISPER", MakeSecret("bnet-target"))
        h.AdvanceTime(0.1)

        local ebW = h.env[cfW:GetName() .. "EditBox"]
        local ebBN = h.env[cfBN:GetName() .. "EditBox"]
        h.env.ChatEdit_ActivateChat(ebW)
        h.env.ChatEdit_ActivateChat(ebBN)

        local allEditBoxes = { ebW, ebBN }
        for i = 1, 10 do
            table.insert(allEditBoxes, h.env["ChatFrame" .. i .. "EditBox"])
        end
        for _, eb in ipairs(allEditBoxes) do
            assertEqual(#eb._hookScriptCalls, 0, addonFolder .. ": Zero direct HookScript calls on " .. tostring(eb:GetName()))
            for _, ev in ipairs(eb._hookScriptCalls) do
                assertTrue(ev ~= "OnTextChanged", addonFolder .. ": Must never HookScript('OnTextChanged') on " .. tostring(eb:GetName()))
            end
        end

        -- Verify /ww still converts on normal non-secret SAY EditBox via hooksecurefunc post-hooks
        h.state.targetName = "Friend-Frostmourne"
        local eb1 = h.env.ChatFrame1EditBox
        eb1:SetAttribute("chatType", "SAY")
        eb1:SetAttribute("tellTarget", nil)
        eb1:SetText("/ww ")
        h.env.ChatEdit_OnSpacePressed(eb1)
        assertEqual(eb1:GetAttribute("chatType"), "WHISPER", addonFolder .. ": /ww space post-hook must switch SAY to WHISPER")
        assertEqual(eb1:GetAttribute("tellTarget"), "Friend-Frostmourne", addonFolder .. ": /ww space post-hook must set friendly tellTarget")

        -- Verify ChatFrameEditBoxMixin.OnTextChanged post-hook also converts '/ww hi'
        eb1:SetAttribute("chatType", "SAY")
        eb1:SetAttribute("tellTarget", nil)
        eb1:SetText("/ww hello")
        h.env.ChatFrameEditBoxMixin.OnTextChanged(eb1)
        assertEqual(eb1:GetAttribute("chatType"), "WHISPER", addonFolder .. ": Mixin OnTextChanged post-hook must convert /ww")
        assertEqual(eb1:GetText(), "hello", addonFolder .. ": /ww conversion must preserve remainder text")
    end

    VerifyMode(true, "DynamicSuite")
    VerifyMode(false, "DynamicChat")
end)

-- ============================================================================
-- T8: BN_WHISPER Secret Target/Header Guards & External promptHint Focus Handling
-- ============================================================================
RunTest("T8: BN_WHISPER Secret Guards (Typography, SetPoint, /ww) & promptHint Hide/Restore", function()
    local function FindEditBoxSkin(h)
        for _, w in ipairs(h.createdWidgets) do
            if w.promptHint and w.leftBar then
                return w
            end
        end
        return nil
    end

    local function VerifyMode(withSuite, addonFolder)
        local h = CreateHarness({ withSuite = withSuite, idleEditBox = true })
        for i = 1, 10 do
            h.env["ChatFrame" .. i .. "EditBox"]._shown = false
        end
        h.LoadModule(addonFolder)
        h.FireEvent("ADDON_LOADED", addonFolder)
        h.FireEvent("PLAYER_LOGIN")
        h.env.DynamicChat:ApplySleekChatSkin()
        h.env.DynamicChat:ApplyChatFrameTypography()

        local eb1 = h.env.ChatFrame1EditBox
        local skinBar = FindEditBoxSkin(h)
        assertTrue(skinBar ~= nil, addonFolder .. ": External chatEditBoxSkin must exist")
        assertTrue(#eb1._setFontCalls > 0, addonFolder .. ": Idle non-secret ChatFrame1EditBox should receive initial font")
        assertTrue(#eb1._setPointCalls > 0, addonFolder .. ": Idle non-secret ChatFrame1EditBox should receive initial anchor")

        -- Open temporary BN_WHISPER tab with secret target
        local secretTarget = MakeSecret("bnet-target")
        local cfBN = h.env.FCF_OpenTemporaryWindow("BN_WHISPER", secretTarget)
        local ebBN = h.env[cfBN:GetName() .. "EditBox"]
        local secretHdrW = MakeSecret("hdr-width")
        ebBN.header.GetStringWidth = function() return secretHdrW end
        ebBN._shown = true
        ebBN._hasFocus = true

        -- Also configure ChatFrame1EditBox as actively replying in BN_WHISPER with secret tellTarget & header width
        eb1:SetAttribute("chatType", "BN_WHISPER")
        eb1:SetAttribute("stickyType", "BN_WHISPER")
        eb1:SetAttribute("tellTarget", MakeSecret("bnet-tell"))
        eb1.header.GetStringWidth = function() return secretHdrW end
        eb1._shown = true
        eb1._hasFocus = true
        h.state.activeEditBox = eb1
        h.state.targetName = "Friend-Frostmourne"

        -- Reset counters to verify ZERO mutations during active BN_WHISPER open/select/reply
        eb1._setFontCalls = {}
        eb1.header._setFontCalls = {}
        eb1._setPointCalls = {}
        eb1._clearAllPointsCalls = 0
        eb1._setTextCalls = {}
        eb1._setAttrCalls = {}
        eb1._altArrowCalls = {}
        eb1._hookScriptCalls = {}

        ebBN._setFontCalls = {}
        ebBN.header._setFontCalls = {}
        ebBN._setPointCalls = {}
        ebBN._clearAllPointsCalls = 0
        ebBN._setTextCalls = {}
        ebBN._setAttrCalls = {}
        ebBN._altArrowCalls = {}
        ebBN._hookScriptCalls = {}

        cfBN._setFontCalls = {}
        cfBN._hookScriptCalls = {}

        -- Trigger hooks & timers
        h.env.FCF_OpenTemporaryWindow("BN_WHISPER", MakeSecret("bnet-target-2"))
        h.AdvanceTime(0.1)
        h.env.FCF_SelectDockFrame(cfBN)
        h.env.DynamicChat:ApplyChatFrameTypography()
        h.env.DynamicChat:ApplySleekChatSkin()
        h.env.ChatEdit_ActivateChat(eb1)
        h.env.ChatEdit_ActivateChat(ebBN)
        h.env.ChatEdit_UpdateHeader(eb1)

        -- Simulate Blizzard calling eb1:SetPoint during BN_WHISPER reply
        eb1:SetPoint("BOTTOMLEFT", h.env.UIParent, "BOTTOMLEFT", 12, 12)

        -- Simulate typing '/ww ' inside BN_WHISPER editBox
        eb1._text = "/ww "
        h.env.ChatEdit_OnTextChanged(eb1)
        h.env.ChatEdit_OnSpacePressed(eb1)
        h.env.ChatFrameEditBoxMixin.OnTextChanged(eb1)
        h.env.ChatFrameEditBoxMixin.OnSpacePressed(eb1)

        assertEqual(#eb1._setFontCalls, 0, addonFolder .. ": ApplyToEditBox must skip eb1 during BN_WHISPER")
        assertEqual(#eb1.header._setFontCalls, 0, addonFolder .. ": ApplyToEditBox must skip eb1.header during BN_WHISPER")
        assertEqual(#ebBN._setFontCalls, 0, addonFolder .. ": ApplyToEditBox must skip temp BN_WHISPER editBox")
        assertEqual(#ebBN.header._setFontCalls, 0, addonFolder .. ": ApplyToEditBox must skip temp BN_WHISPER header")
        assertEqual(#cfBN._setFontCalls, 0, addonFolder .. ": ApplyToSingleFrame must skip temp BN_WHISPER chatFrame")
        assertEqual(#cfBN._hookScriptCalls, 0, addonFolder .. ": Must not attach HookScript to temp BN_WHISPER chatFrame")
        assertEqual(eb1._clearAllPointsCalls, 0, addonFolder .. ": SetPoint hook & ApplyEditBoxAnchorNow must skip eb1 during BN_WHISPER")
        assertEqual(#eb1._setPointCalls, 1, addonFolder .. ": Only Blizzard's own SetPoint call should exist on eb1 (zero re-anchoring)")
        assertEqual(#eb1._setTextCalls, 0, addonFolder .. ": /ww conversion must skip BN_WHISPER editBox")
        assertEqual(#eb1._setAttrCalls, 0, addonFolder .. ": Must never mutate chatType/tellTarget on BN_WHISPER editBox")
        assertEqual(#eb1._altArrowCalls, 0, addonFolder .. ": ChatEdit_ActivateChat must skip SetAltArrowKeyMode on BN_WHISPER editBox")
        assertEqual(#ebBN._altArrowCalls, 0, addonFolder .. ": ChatEdit_ActivateChat must skip SetAltArrowKeyMode on temp BN_WHISPER editBox")

        -- Also verify secret header:GetStringWidth() alone (even with chatType='SAY') blocks /ww conversion
        eb1._attrs.chatType = "SAY"
        eb1._attrs.stickyType = "SAY"
        eb1._attrs.tellTarget = nil
        eb1._text = "/ww "
        h.env.ChatEdit_OnSpacePressed(eb1)
        assertEqual(#eb1._setTextCalls, 0, addonFolder .. ": Secret header:GetStringWidth() must block /ww conversion")
        assertEqual(#eb1._setAttrCalls, 0, addonFolder .. ": Secret header:GetStringWidth() must block attribute writes")

        -- Restore BN_WHISPER attributes and verify EventRegistry focus gained hides promptHint + applies BNet cyan
        eb1._attrs.chatType = "BN_WHISPER"
        eb1._attrs.stickyType = "BN_WHISPER"
        eb1._attrs.tellTarget = MakeSecret("bnet-tell")
        skinBar.promptHint:Show()
        h.env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusGained", eb1)
        assertEqual(skinBar.promptHint:IsShown(), false, addonFolder .. ": Focus gained on BN_WHISPER must hide external chatEditBoxSkin.promptHint")
        assertTrue(skinBar._backdropBorderColor ~= nil, addonFolder .. ": Focus gained must update chatEditBoxSkin border")
        assertEqual(skinBar._backdropBorderColor[1], 0.22, addonFolder .. ": Focused BN_WHISPER dock border R must be BNet cyan (0.22)")
        assertEqual(skinBar._backdropBorderColor[2], 0.74, addonFolder .. ": Focused BN_WHISPER dock border G must be BNet cyan (0.74)")
        assertEqual(skinBar._backdropBorderColor[3], 0.97, addonFolder .. ": Focused BN_WHISPER dock border B must be BNet cyan (0.97)")
        assertEqual(#eb1._setAttrCalls, 0, addonFolder .. ": OnEditBoxFocusGained must not mutate BN_WHISPER editBox")
        assertEqual(eb1._clearAllPointsCalls, 0, addonFolder .. ": OnEditBoxFocusGained must not re-anchor BN_WHISPER editBox")

        -- Focus lost must restore idle promptHint even while stickyType/tellTarget remain BN_WHISPER/secret
        h.env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusLost")
        assertEqual(skinBar.promptHint:IsShown(), true, addonFolder .. ": Focus lost after BN_WHISPER must restore chatEditBoxSkin.promptHint")

        -- Verify idle always-shown non-secret EditBox IS styled, while focused & combat skip ApplyToEditBox
        eb1._attrs.chatType = "SAY"
        eb1._attrs.stickyType = "SAY"
        eb1._attrs.tellTarget = nil
        eb1.header.GetStringWidth = function() return 40 end
        eb1._shown = true
        eb1._hasFocus = false
        h.state.activeEditBox = nil
        eb1._setFontCalls = {}
        eb1.header._setFontCalls = {}
        h.env.DynamicChat:ApplyChatFrameTypography()
        assertTrue(#eb1._setFontCalls > 0, addonFolder .. ": ApplyToEditBox must still style idle always-shown editBox")

        eb1._hasFocus = true
        eb1._setFontCalls = {}
        eb1.header._setFontCalls = {}
        h.env.DynamicChat:ApplyChatFrameTypography()
        assertEqual(#eb1._setFontCalls, 0, addonFolder .. ": ApplyToEditBox must skip actively focused editBox")

        eb1._hasFocus = false
        eb1._shown = false
        h.state.inCombat = true
        h.env.DynamicChat:ApplyChatFrameTypography()
        assertEqual(#eb1._setFontCalls, 0, addonFolder .. ": ApplyToEditBox must skip editBox in combat")
        h.state.inCombat = false
    end

    VerifyMode(true, "DynamicSuite")
    VerifyMode(false, "DynamicChat")
end)

-- ============================================================================
-- T9: StyleSingleChatTab Skips tab:SetAlpha on Secret fadeInfo / UIFrameFade
-- ============================================================================
RunTest("T9: StyleSingleChatTab Skips tab:SetAlpha on Secret fadeInfo & Active UIFrameFade", function()
    local function VerifyMode(withSuite, addonFolder)
        local h = CreateHarness({ withSuite = withSuite, idleEditBox = true })
        for i = 1, 10 do
            h.env["ChatFrame" .. i .. "EditBox"]._shown = false
        end
        h.LoadModule(addonFolder)
        h.FireEvent("ADDON_LOADED", addonFolder)
        h.FireEvent("PLAYER_LOGIN")
        h.env.DynamicChat:ApplySleekChatSkin()

        local cfW = h.env.FCF_OpenTemporaryWindow("WHISPER", "Alice")
        local tabW = h.env[cfW:GetName() .. "Tab"]
        local cfBN = h.env.FCF_OpenTemporaryWindow("BN_WHISPER", MakeSecret("bnet-fade"))
        local tabBN = h.env[cfBN:GetName() .. "Tab"]
        local tab1 = h.env.ChatFrame1Tab
        local tab2 = h.env.ChatFrame2Tab

        -- Case A: ChatFrame2Tab has tab.fadeInfo with secret startAlpha/endAlpha
        tab2.fadeInfo = {
            startAlpha = MakeSecret("start-alpha"),
            endAlpha = MakeSecret("end-alpha"),
            timeToFade = 0.25,
        }
        tab2._setAlphaCalls = {}

        -- Case B: Whisper tab is actively fading via UIFrameIsFading(tab) == true (even without fadeInfo)
        tabW.fadeInfo = nil
        tabW._isFading = true
        tabW._setAlphaCalls = {}

        -- Case C: BN_WHISPER tab has non-secret tab.fadeInfo table
        tabBN.fadeInfo = { startAlpha = 0.4, endAlpha = 1.0, timeToFade = 0.2 }
        tabBN._setAlphaCalls = {}

        -- Case D: Normal ChatFrame1Tab has no fadeInfo and is not fading
        tab1.fadeInfo = nil
        tab1._isFading = false
        tab1._setAlphaCalls = {}

        h.env.FCFTab_UpdateAlpha(h.env.ChatFrame1)
        h.env.FCFTab_UpdateAlpha(h.env.ChatFrame2)
        h.env.FCFTab_UpdateAlpha(cfW)
        h.env.FCFTab_UpdateAlpha(cfBN)
        h.env.DynamicChat:ApplySleekChatSkin()

        assertEqual(#tab2._setAlphaCalls, 0, addonFolder .. ": Must skip tab:SetAlpha when tab.fadeInfo has secret alpha values")
        assertEqual(#tabW._setAlphaCalls, 0, addonFolder .. ": Must skip tab:SetAlpha when UIFrameIsFading(tab) is true")
        assertEqual(#tabBN._setAlphaCalls, 0, addonFolder .. ": Must skip tab:SetAlpha when tab.fadeInfo exists")
        assertTrue(#tab1._setAlphaCalls > 0, addonFolder .. ": Non-fading tab without fadeInfo should still enforce alpha 1.0")
        assertEqual(tab1:GetAlpha(), 1.0, addonFolder .. ": Non-fading tab alpha must be 1.0")
    end

    VerifyMode(true, "DynamicSuite")
    VerifyMode(false, "DynamicChat")
end)

-- ============================================================================
-- T10: Temp BN_WHISPER Zero Background/Button Mutation, Multi-EditBox Focus
--      Race, Fail-Closed Secret Probes & UIFrameIsFlashing Secret Guard
-- ============================================================================
RunTest("T10: Temp BN_WHISPER Zero Child Mutations, Focus Race, Fail-Closed Probes & Secret Flash", function()
    local function FindEditBoxSkin(h)
        for _, w in ipairs(h.createdWidgets) do
            if w.promptHint and w.leftBar then
                return w
            end
        end
        return nil
    end

    local function VerifyMode(withSuite, addonFolder)
        local h = CreateHarness({ withSuite = withSuite, idleEditBox = true })
        for i = 1, 10 do
            h.env["ChatFrame" .. i .. "EditBox"]._shown = false
        end
        h.LoadModule(addonFolder)
        h.FireEvent("ADDON_LOADED", addonFolder)
        h.FireEvent("PLAYER_LOGIN")
        h.env.DynamicChat:ApplySleekChatSkin()

        local eb1 = h.env.ChatFrame1EditBox
        local skinBar = FindEditBoxSkin(h)
        assertTrue(skinBar ~= nil, addonFolder .. ": chatEditBoxSkin must exist")

        -- 1. Open temporary BN_WHISPER frame and exercise fade/background/skin hooks
        local cfBN = h.env.FCF_OpenTemporaryWindow("BN_WHISPER", MakeSecret("bnet-bg"))
        local cfName = cfBN:GetName()
        local ebBN = h.env[cfName .. "EditBox"]
        local btnFrameBN = h.env[cfName .. "ButtonFrame"]
        local minBtnBN = h.env[cfName .. "MinimizeButton"]
        local tabBN = h.env[cfName .. "Tab"]

        h.AdvanceTime(0.1)
        h.env.DynamicChat:ApplySleekChatSkin()
        h.env.FCF_SetWindowAlpha(cfBN, 0.25)
        h.env.FCF_SetWindowColor(cfBN, 0, 0, 0)
        h.env.FCF_FadeInChatFrame(cfBN)
        h.env.FCF_FadeOutChatFrame(cfBN)
        h.env.FloatingChatFrame_UpdateBackgroundAnchors(cfBN)

        for _, child in ipairs({ cfBN.Background, cfBN.NineSlice, cfBN.ResizeButton, btnFrameBN, minBtnBN }) do
            assertEqual(child._hideCalls, 0, addonFolder .. ": Temp BN_WHISPER child must not be hidden (" .. tostring(child:GetName()) .. ")")
            assertEqual(#child._setAlphaCalls, 0, addonFolder .. ": Temp BN_WHISPER child must not have SetAlpha called (" .. tostring(child:GetName()) .. ")")
            assertEqual(#child._hookScriptCalls, 0, addonFolder .. ": Temp BN_WHISPER child must not have HookScript attached (" .. tostring(child:GetName()) .. ")")
        end

        -- 2. Stale OnEditBoxFocusLost(eb1) after OnEditBoxFocusGained(ebBN) + deferred ApplySleekChatSkin
        eb1._attrs.chatType = "SAY"
        eb1._attrs.stickyType = "SAY"
        eb1._attrs.tellTarget = nil
        eb1._hasFocus = false
        eb1._shown = false
        h.state.activeEditBox = nil

        h.env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusGained", eb1)
        h.env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusGained", ebBN)
        h.env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusLost", eb1)
        assertEqual(skinBar.promptHint:IsShown(), false, addonFolder .. ": Stale FocusLost(eb1) must not show promptHint over active ebBN")
        assertEqual(skinBar._backdropBorderColor[1], 0.22, addonFolder .. ": Active ebBN must keep BNet cyan border R after stale FocusLost(eb1)")
        assertEqual(skinBar._backdropBorderColor[2], 0.74, addonFolder .. ": Active ebBN must keep BNet cyan border G after stale FocusLost(eb1)")
        assertEqual(skinBar._backdropBorderColor[3], 0.97, addonFolder .. ": Active ebBN must keep BNet cyan border B after stale FocusLost(eb1)")

        -- Deferred ApplySleekChatSkin while ebBN is focused must preserve BNet cyan & hidden promptHint
        h.env.DynamicChat:ApplySleekChatSkin()
        assertEqual(skinBar.promptHint:IsShown(), false, addonFolder .. ": Deferred ApplySleekChatSkin must keep promptHint hidden while ebBN is focused")
        assertEqual(skinBar._backdropBorderColor[1], 0.22, addonFolder .. ": Deferred ApplySleekChatSkin must keep BNet cyan border R")
        assertEqual(skinBar._backdropBorderColor[2], 0.74, addonFolder .. ": Deferred ApplySleekChatSkin must keep BNet cyan border G")
        assertEqual(skinBar._backdropBorderColor[3], 0.97, addonFolder .. ": Deferred ApplySleekChatSkin must keep BNet cyan border B")

        -- Matching FocusLost(ebBN) restores idle promptHint
        h.env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusLost", ebBN)
        assertEqual(skinBar.promptHint:IsShown(), true, addonFolder .. ": FocusLost(ebBN) must restore promptHint")

        -- 3. ChatEdit_ActivateChat(eb1) while SELECTED_DOCK_FRAME == cfBN (before chatType switches) and in combat
        h.env.SELECTED_DOCK_FRAME = cfBN
        eb1._altArrowCalls = {}
        h.env.ChatEdit_ActivateChat(eb1)
        assertEqual(#eb1._altArrowCalls, 0, addonFolder .. ": ChatEdit_ActivateChat(eb1) must skip SetAltArrowKeyMode when SELECTED_DOCK_FRAME is BN_WHISPER")

        h.env.SELECTED_DOCK_FRAME = h.env.ChatFrame1
        h.state.inCombat = true
        h.env.ChatEdit_ActivateChat(eb1)
        h.env.DynamicChat:ApplyEditBoxSettings()
        assertEqual(#eb1._altArrowCalls, 0, addonFolder .. ": ChatEdit_ActivateChat & ApplyEditBoxSettings must skip SetAltArrowKeyMode in combat")
        h.state.inCombat = false

        -- 4. Fail-closed secret probes: secret header:GetText() (with non-secret width) & throwing GetAttribute
        h.state.targetName = "Friend-Frostmourne"
        eb1._attrs.chatType = "SAY"
        eb1._attrs.stickyType = "SAY"
        eb1._attrs.tellTarget = nil
        eb1.header.GetStringWidth = function() return 45 end
        eb1.header.GetText = function() return MakeSecret("bnet-header-text") end
        eb1._setTextCalls = {}
        eb1._setAttrCalls = {}
        eb1._text = "/ww "
        h.env.ChatEdit_OnSpacePressed(eb1)
        assertEqual(#eb1._setTextCalls, 0, addonFolder .. ": Secret header:GetText() must block /ww conversion")
        assertEqual(#eb1._setAttrCalls, 0, addonFolder .. ": Secret header:GetText() must block attribute writes")

        eb1.header.GetText = function() return "Say:" end
        local origGetAttr = eb1.GetAttribute
        eb1.GetAttribute = function() error("Forbidden attribute access") end
        h.env.ChatEdit_OnSpacePressed(eb1)
        assertEqual(#eb1._setTextCalls, 0, addonFolder .. ": Throwing GetAttribute must fail closed and block /ww conversion")
        eb1.GetAttribute = origGetAttr

        -- 5. Secret UIFrameIsFlashing return & fading tab.Text fontString must not error or mutate alpha
        tabBN.glow._isFlashing = MakeSecret("secret-flashing")
        tabBN.Text.fadeInfo = { startAlpha = MakeSecret("s"), endAlpha = MakeSecret("e") }
        tabBN.Text._setAlphaCalls = {}
        h.env.FCFTab_UpdateAlpha(cfBN)
        h.env.FCFTab_UpdateColors(tabBN)
        assertEqual(#tabBN.Text._setAlphaCalls, 0, addonFolder .. ": Must skip tab.Text:SetAlpha when fadeInfo exists")
    end

    VerifyMode(true, "DynamicSuite")
    VerifyMode(false, "DynamicChat")
end)

-- ============================================================================
-- T11: Zero-Taint Clickable Saved Whisper History Hint Overlay
-- ============================================================================
RunTest("T11: Clickable Saved Whisper History Hint (Empty Restored Tab, Copy Chat Click, Hide Triggers & BN_WHISPER Guard)", function()
    local epoch = 1700000000
    local function VerifyMode(withSuite, addonFolder)
        local seedDB = {
            preserveChatHistory = true,
            enableGPUBufferCap = true,
            preserveWhisperTabs = true,
            maxSavedWhisperTabs = 5,
            editBoxPosition = "BOTTOM",
            savedWhisperTabs = {
                { target = "Alice", chatType = "WHISPER", lastUpdated = epoch - 30, lines = { "[20:55] Alice: saved line 1", "[20:56] To Alice: saved line 2" } },
                { target = "Bob",   chatType = "WHISPER", lastUpdated = epoch - 60, lines = { "[20:50] Bob: solo saved line" } },
            },
        }
        local h = CreateHarness({ withSuite = withSuite, epochNow = epoch, initialDB = seedDB })
        h.LoadModule(addonFolder)
        h.FireEvent("ADDON_LOADED", addonFolder)
        h.FireEvent("PLAYER_LOGIN")
        h.FireEvent("PLAYER_ENTERING_WORLD")
        h.AdvanceTime(0.2)

        local cfAlice, cfBob = nil, nil
        for _, cf in ipairs(h.env.GeneralDockManager.DOCKED_CHAT_FRAMES) do
            if cf.chatTarget == "Alice" then cfAlice = cf
            elseif cf.chatTarget == "Bob" then cfBob = cf end
        end
        assertTrue(cfAlice ~= nil and cfBob ~= nil, addonFolder .. ": Restored Alice and Bob whisper frames must exist")

        -- Still on General tab (ChatFrame1) -> hint must not be shown
        local hint = h.env.DynamicChatWhisperHistoryHint
        assertTrue(hint == nil or not hint:IsShown(), addonFolder .. ": Hint must be hidden while General tab is selected")

        -- (a) Select restored empty character whisper tab (Alice, 2 saved lines) -> hint shows with plural count & UIParent parent
        h.env.FCF_SelectDockFrame(cfAlice)
        hint = h.env.DynamicChatWhisperHistoryHint
        assertTrue(hint ~= nil and hint:IsShown(), addonFolder .. ": Hint must show on empty restored character whisper tab")
        assertEqual(hint:GetParent(), h.env.UIParent, addonFolder .. ": Hint must be UIParent-hosted (never parented to Blizzard ChatFrame)")
        assertEqual(hint.label:GetText(), "Previous messages (2) saved in Copy Chat - Click to view", addonFolder .. ": Plural saved line count copy")

        -- Verify BOTTOM vs TOP anchoring respects editBoxPosition & ChatFrame1 scale
        local ptBot = hint._points[1] and hint._points[1][1]
        assertEqual(ptBot, "BOTTOMLEFT", addonFolder .. ": BOTTOM editBoxPosition anchors hint above bottom typing box")
        h.env.ChatFrame1:SetScale(1.15)
        h.env.DynamicChatDB.editBoxPosition = "TOP"
        h.env.DynamicChat:ApplySleekChatSkin()
        local ptTop = hint._points[1] and hint._points[1][1]
        assertEqual(ptTop, "TOPLEFT", addonFolder .. ": TOP editBoxPosition anchors hint below top typing box")
        assertEqual(hint:GetScale(), 1.15, addonFolder .. ": Hint scale must match ChatFrame1 scale")

        -- Hover OnEnter highlights border with Suite Accent and populates tooltip; OnLeave restores rest border
        if hint:GetScript("OnEnter") then hint:GetScript("OnEnter")(hint) end
        if hint:GetScript("OnLeave") then hint:GetScript("OnLeave")(hint) end

        -- Singular count copy on Bob (1 saved line)
        h.env.FCF_SelectDockFrame(cfBob)
        assertTrue(hint:IsShown(), addonFolder .. ": Hint must show on empty Bob whisper tab")
        assertEqual(hint.label:GetText(), "1 previous message saved in Copy Chat - Click to view", addonFolder .. ": Singular saved line count copy")

        -- (b) Clicking hint opens Copy Chat modal for that active whisper tab
        h.env.FCF_SelectDockFrame(cfAlice)
        assertTrue(hint:IsShown(), addonFolder .. ": Hint visible before click on Alice")
        hint:GetScript("OnClick")(hint, "LeftButton")
        local modal = h.env.DynamicChatHistoryModal
        assertTrue(modal ~= nil and modal:IsShown() and modal.editBox ~= nil, addonFolder .. ": Clicking hint must open Copy Chat modal")
        local modalTxt = modal.editBox:GetText()
        assertTrue(modalTxt:find("saved line 1", 1, true) ~= nil, addonFolder .. ": Copy Chat modal must include Alice's saved line 1")
        assertTrue(modalTxt:find("saved line 2", 1, true) ~= nil, addonFolder .. ": Copy Chat modal must include Alice's saved line 2")
        assertTrue(modalTxt:find("--- Saved From Previous Session ---", 1, true) ~= nil, addonFolder .. ": Copy Chat modal must include previous session divider")

        -- (c) Receiving a live message via AddMessage hides hint immediately
        cfAlice:AddMessage("[21:20] Alice: hello live!")
        assertEqual(hint:IsShown(), false, addonFolder .. ": Live AddMessage on selected whisper tab must hide hint immediately")

        -- Switching back to General hides hint on empty Bob tab
        h.env.FCF_SelectDockFrame(cfBob)
        assertTrue(hint:IsShown(), addonFolder .. ": Hint shown again on empty Bob tab")
        h.env.FCF_SelectDockFrame(h.env.ChatFrame1)
        assertEqual(hint:IsShown(), false, addonFolder .. ": Switching back to General must hide hint immediately")

        -- HUD Edit Mode active hides hint, exiting restores it
        h.env.FCF_SelectDockFrame(cfBob)
        assertTrue(hint:IsShown(), addonFolder .. ": Hint shown on Bob before Edit Mode")
        h.env.DynamicChat._dsEditModeActive = true
        h.env.DynamicChat:RefreshWhisperHistoryHint()
        assertEqual(hint:IsShown(), false, addonFolder .. ": HUD Edit Mode active must hide hint")
        h.env.DynamicChat:HideHudEditMover()
        assertTrue(hint:IsShown(), addonFolder .. ": HideHudEditMover restores hint on empty Bob tab")

        -- Closing Bob via FCF_Close hides hint
        h.env.FCF_Close(cfBob)
        assertEqual(hint:IsShown(), false, addonFolder .. ": FCF_Close must hide hint")

        -- (d) BN_WHISPER and secret tabs NEVER show the hint
        local cfBN = h.env.FCF_OpenTemporaryWindow("BN_WHISPER", MakeSecret("bnet-hint-guard"))
        h.env.FCF_SelectDockFrame(cfBN)
        assertEqual(hint:IsShown(), false, addonFolder .. ": BN_WHISPER tab must never show whisper history hint")

        local cfSecret = h.env.FCF_OpenTemporaryWindow("WHISPER", MakeSecret("secret-whisper-target"))
        h.env.FCF_SelectDockFrame(cfSecret)
        assertEqual(hint:IsShown(), false, addonFolder .. ": Secret whisper target tab must never show whisper history hint")

        -- TeardownDisabledState hides hint cleanly
        h.env.DynamicChat:TeardownDisabledState(true)
        assertEqual(hint:IsShown(), false, addonFolder .. ": TeardownDisabledState must hide whisper history hint")
    end

    VerifyMode(true, "DynamicSuite")
    VerifyMode(false, "DynamicChat")
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
