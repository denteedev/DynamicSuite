-- ============================================================================
-- Headless Lua 5.1 Regression Suite: ChatFrame1 Size Persistence Across /reload
-- Verifies DynamicChat.lua & DynamicSuite_UI.lua:
--   1. HUD Edit Mode ("CHAT") resize grip commits new width/height across release paths
--      and stores them in DynamicChatDB.chatFramePos & DynamicSuiteDB.global.hudPositions["CHAT"]
--   2. Simulated /reload restores resized ChatFrame1 dimensions + embedded EditBox & FontStringContainer
--   3. ClampAllSuiteHudsToScreen & Blizzard Edit Mode / FCF_RestorePositionAndDimensions passes preserve size
--   4. Early-boot unsettled UIParent dimensions never shrink saved ChatFrame1 width/height
-- Pure ASCII Only.
-- ============================================================================

local CORE_PATH = "DynamicSuite/DynamicSuite_Core.lua"
local CHAT_PATH = "DynamicSuite/Modules/DynamicChat.lua"
local UI_PATH   = "DynamicSuite/DynamicSuite_UI.lua"

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

local function RunTest(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("[PASS] " .. name)
    else
        failed = failed + 1
        print("[FAIL] " .. name .. " -> " .. tostring(err))
    end
end

local function CreateHarness(savedChatDB, savedSuiteDB, opts)
    opts = opts or {}
    local env = {}
    setmetatable(env, { __index = _G })
    env._G = env

    local state = {
        now = 100.0,
        inCombat = false,
        cursorX = 500,
        cursorY = 400,
        lmbDown = true,
        editModeActive = false,
        tooltipSetText = nil,
        eventFrames = {},
        allFrames = {},
        timers = {},
        registryListeners = {},
    }

    if savedChatDB ~= nil then env.DynamicChatDB = savedChatDB end
    if savedSuiteDB ~= nil then env.DynamicSuiteDB = savedSuiteDB end

    env.tinsert = table.insert
    env.tremove = table.remove
    env.wipe = function(t)
        if type(t) ~= "table" then return t end
        for k in pairs(t) do t[k] = nil end
        return t
    end
    env.CopyTable = function(src)
        if type(src) ~= "table" then return src end
        local dst = {}
        for k, v in pairs(src) do
            dst[k] = (type(v) == "table") and env.CopyTable(v) or v
        end
        return dst
    end
    env.strsplit = function(delim, str)
        local out = {}
        for part in string.gmatch(tostring(str or ""), "([^" .. tostring(delim) .. "]+)") do
            out[#out + 1] = part
        end
        return unpack(out)
    end
    env.GetTime = function() return state.now end
    env.time = function() return math.floor(1700000000 + state.now) end
    env.UnitName = function() return "Dentee" end
    env.UnitClass = function() return "Mage", "MAGE", 8 end
    env.UnitGUID = function() return "Player-1234-0001" end
    env.GetRealmName = function() return "Frostmourne" end
    env.InCombatLockdown = function() return state.inCombat end
    env.IsShiftKeyDown = function() return false end
    env.IsControlKeyDown = function() return false end
    env.IsAltKeyDown = function() return false end
    env.IsMouseButtonDown = function(btn)
        if btn == "LeftButton" then return state.lmbDown end
        return false
    end
    env.GetCursorPosition = function() return state.cursorX, state.cursorY end
    env.GetScreenWidth = function() return (env.UIParent and env.UIParent:GetWidth()) or 1920 end
    env.GetScreenHeight = function() return (env.UIParent and env.UIParent:GetHeight()) or 1080 end
    env.GetPhysicalScreenSize = function() return 1920, 1080 end
    env.GetLocale = function() return "enUS" end
    env.GetMouseFoci = function() return {} end
    env.PlaySound = function() end
    env.PlaySoundFile = function() end
    env.ReloadUI = function() end
    env.CreateColor = function(r, g, b, a)
        return { r = r or 1, g = g or 1, b = b or 1, a = a or 1, GetRGBA = function(self) return self.r, self.g, self.b, self.a end }
    end
    env.UISpecialFrames = {}
    env.SlashCmdList = {}
    env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    env.SOUNDKIT = { UI_BNET_TOAST = 18019, IG_CHARACTER_INFO_TAB = 841, IG_MAINMENU_OPTION_CHECKBOX_ON = 856 }
    env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    env.UNKNOWNOBJECT = "Unknown"
    env.MAX_WOW_CHAT_CHANNELS = 10
    env.NUM_CHAT_WINDOWS = 10
    env.CHAT_FRAME_TAB_SELECTED_MOUSEOVER_ALPHA = 1.0
    env.CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA = 0.8
    env.CHAT_FRAME_TAB_NORMAL_MOUSEOVER_ALPHA = 0.9
    env.CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA = 0.4
    env.issecretvalue = function() return false end
    env.canaccessvalue = function() return true end
    env.canaccessallvalues = function(...) return true end

    env.hooksecurefunc = function(a, b, c)
        local tbl, fnName, hookFn
        if type(a) == "table" then tbl = a; fnName = b; hookFn = c
        else tbl = env; fnName = a; hookFn = b end
        if type(tbl) == "table" and type(tbl[fnName]) == "function" then
            local orig = tbl[fnName]
            tbl[fnName] = function(...)
                local r1, r2, r3, r4 = orig(...)
                hookFn(...)
                return r1, r2, r3, r4
            end
        end
    end

    env.C_Timer = {
        After = function(delay, fn) table.insert(state.timers, { delay = delay, fn = fn }) end,
        NewTimer = function(delay, fn)
            local entry = { delay = delay, fn = fn }
            table.insert(state.timers, entry)
            return { Cancel = function() entry.cancelled = true end }
        end,
    }
    env.C_EventUtils = { IsEventValid = function() return true end }
    env.C_CVar = {
        GetCVar = function() return "1" end,
        GetCVarBool = function() return false end,
        SetCVar = function() end,
        GetCVarDefault = function() return "1" end,
    }
    env.C_AddOns = {
        GetAddOnMetadata = function() return "2.11.2" end,
        IsAddOnLoaded = function(n) return n == "DynamicSuite" end,
        GetAddOnInfo = function(n) return n, n, "", (n == "DynamicSuite"), (n == "DynamicSuite") and "INSECURE" or "MISSING", false end,
        GetAddOnEnableState = function(n) return (n == "DynamicSuite") and 2 or 0 end,
        GetNumAddOns = function() return 0 end,
    }
    env.GetNumAddOns = function() return 0 end
    env.C_Map = { GetMapInfo = function() return { name = "Dornogal" } end }
    env.C_PetBattles = { IsInBattle = function() return false end }
    env.DEFAULT_CHAT_FRAME = { AddMessage = function() end }

    env.EventRegistry = {
        RegisterCallback = function(_, ev, fn, owner)
            state.registryListeners[ev] = state.registryListeners[ev] or {}
            table.insert(state.registryListeners[ev], { fn = fn, owner = owner })
        end,
        TriggerEvent = function(_, ev, ...)
            for _, entry in ipairs(state.registryListeners[ev] or {}) do
                if entry.owner ~= nil then entry.fn(entry.owner, ...) else entry.fn(...) end
            end
        end,
    }

    local function MakeWidget(wType, name, parent)
        local w = {
            _type = wType or "Frame",
            _name = name,
            _parent = parent,
            _shown = false,
            _alpha = 1.0,
            _scale = 1.0,
            _width = 430,
            _height = 200,
            _level = 5,
            _strata = "MEDIUM",
            _points = {},
            _scripts = {},
            _events = {},
            _attrs = {},
            _children = {},
            _regions = {},
            _text = "",
            _messages = {},
            _hasFocus = false,
        }
        if type(parent) == "table" and type(parent._children) == "table" then
            table.insert(parent._children, w)
        end
        function w:GetName() return self._name end
        function w:GetObjectType() return self._type end
        function w:SetParent(p) self._parent = p end
        function w:GetParent() return self._parent or env.UIParent end
        function w:GetChildren() return unpack(self._children) end
        function w:GetRegions() return unpack(self._regions) end
        function w:Show() self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end
        function w:Hide() self._shown = false; if self._scripts.OnHide then self._scripts.OnHide(self) end end
        function w:SetShown(b) if b then self:Show() else self:Hide() end end
        function w:IsShown() return self._shown == true end
        function w:IsVisible() return self._shown == true end
        function w:IsForbidden() return false end
        function w:SetAlpha(a) self._alpha = a or 1.0 end
        function w:GetAlpha() return self._alpha end
        function w:SetScale(s) self._scale = s or 1.0 end
        function w:GetScale() return self._scale end
        function w:GetEffectiveScale() return self._scale end
        function w:SetSize(ww, hh) self._width = ww; self._height = hh end
        function w:SetWidth(ww) self._width = ww end
        function w:SetHeight(hh) self._height = hh end
        function w:GetWidth() return self._width end
        function w:GetHeight() return self._height end
        function w:GetLeft()
            local p = self._points[1]
            if p and p[1] == "BOTTOMLEFT" then return tonumber(p[4]) or 0 end
            return 50
        end
        function w:GetBottom()
            local p = self._points[1]
            if p and p[1] == "BOTTOMLEFT" then return tonumber(p[5]) or 0 end
            return 50
        end
        function w:GetRight() return (self:GetLeft() or 0) + (self._width or 0) end
        function w:GetTop() return (self:GetBottom() or 0) + (self._height or 0) end
        function w:GetCenter() return (self:GetLeft() or 0) + (self._width or 0) * 0.5, (self:GetBottom() or 0) + (self._height or 0) * 0.5 end
        function w:SetFrameStrata(s) self._strata = s end
        function w:GetFrameStrata() return self._strata end
        function w:SetFrameLevel(l) self._level = l end
        function w:GetFrameLevel() return self._level end
        function w:ClearAllPoints() self._points = {} end
        function w:SetPoint(pt, relTo, relPt, x, y)
            if type(relTo) == "number" then y = relPt; x = relTo; relPt = pt; relTo = env.UIParent end
            table.insert(self._points, { pt, relTo or env.UIParent, relPt or pt, tonumber(x) or 0, tonumber(y) or 0 })
        end
        function w:SetAllPoints() end
        function w:GetPoint(i)
            local p = self._points[i or 1]
            if p then return p[1], p[2], p[3], p[4], p[5] end
            return "BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 0, 0
        end
        function w:GetNumPoints() return #self._points end
        function w:EnableMouse() end
        function w:EnableMouseWheel() end
        function w:EnableKeyboard() end
        function w:SetPropagateKeyboardInput() end
        function w:SetMovable() end
        function w:SetResizable() end
        function w:SetResizeBounds() end
        function w:SetToplevel() end
        function w:SetUserPlaced() end
        function w:SetClampedToScreen() end
        function w:SetClampRectInsets() end
        function w:SetClipsChildren() end
        function w:SetIgnoreParentAlpha() end
        function w:SetHitRectInsets() end
        function w:RegisterForDrag() end
        function w:RegisterForClicks() end
        function w:StartMoving() end
        function w:StopMovingOrSizing() end
        function w:Raise() end
        function w:Enable() end
        function w:Disable() end
        function w:SetEnabled() end
        function w:IsEnabled() return true end
        function w:IsMouseOver() return false end
        function w:SetBackdrop() end
        function w:SetBackdropColor() end
        function w:SetBackdropBorderColor() end
        function w:GetBackdropColor() return 0, 0, 0, 1 end
        function w:GetBackdropBorderColor() return 1, 1, 1, 1 end
        function w:SetAttribute(k, v) self._attrs[k] = v end
        function w:GetAttribute(k) return self._attrs[k] end
        function w:SetFocus() self._hasFocus = true end
        function w:ClearFocus() self._hasFocus = false end
        function w:HasFocus() return self._hasFocus == true end
        function w:SetAutoFocus() end
        function w:SetMultiLine() end
        function w:SetMaxLetters() end
        function w:SetNumeric() end
        function w:SetTextInsets() end
        function w:SetCursorPosition() end
        function w:HighlightText() end
        function w:SetAltArrowKeyMode() end
        function w:SetFontObject() end
        function w:SetFont() return true end
        function w:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
        function w:SetText(t) self._text = tostring(t or "") end
        function w:GetText() return self._text or "" end
        function w:SetTextColor() end
        function w:SetShadowColor() end
        function w:SetShadowOffset() end
        function w:SetJustifyH() end
        function w:SetJustifyV() end
        function w:SetWordWrap() end
        function w:SetNonSpaceWrap() end
        function w:SetIndentedWordWrap() end
        function w:SetSpacing() end
        function w:SetMaxLines() end
        function w:GetStringWidth() return #(self._text or "") * 6 end
        function w:GetUnboundedStringWidth() return #(self._text or "") * 6 end
        function w:GetStringHeight() return 14 end
        function w:SetColorTexture() end
        function w:SetTexture(t) self._tex = t end
        function w:GetTexture() return self._tex end
        function w:SetAtlas() end
        function w:SetBlendMode() end
        function w:SetDesaturated() end
        function w:SetRotation() end
        function w:SetTexCoord() end
        function w:SetSnapToPixelGrid() end
        function w:SetTexelSnappingBias() end
        function w:SetVertexColor() end
        function w:SetNormalTexture() end
        function w:SetPushedTexture() end
        function w:SetHighlightTexture() end
        function w:GetNormalTexture() return self:CreateTexture() end
        function w:GetHighlightTexture() return self:CreateTexture() end
        function w:SetNormalFontObject() end
        function w:GetFontString() return nil end
        function w:SetOrientation() end
        function w:SetMinMaxValues() end
        function w:GetMinMaxValues() return 0, 0 end
        function w:SetValueStep() end
        function w:SetObeyStepOnDrag() end
        function w:SetValue() end
        function w:GetValue() return 0 end
        function w:SetThumbTexture(t) self._thumb = t end
        function w:GetThumbTexture() return self._thumb or self:CreateTexture() end
        function w:SetScrollChild(c) self._scrollChild = c end
        function w:GetScrollChild() return self._scrollChild end
        function w:SetVerticalScroll() end
        function w:GetVerticalScroll() return 0 end
        function w:GetVerticalScrollRange() return 0 end
        function w:UpdateScrollChildRect() end
        function w:SetScrollOffset() end
        function w:GetScrollOffset() return 0 end
        function w:GetMaxScrollRange() return 0 end
        function w:ScrollUp() end
        function w:ScrollDown() end
        function w:ScrollToBottom() end
        function w:AtBottom() return true end
        function w:GetNumMessages() return 0 end
        function w:GetMessageInfo() return nil end
        function w:AddMessage() end
        function w:Clear() end
        function w:RegisterEvent(ev) self._events[ev] = true end
        function w:RegisterUnitEvent(ev) self._events[ev] = true end
        function w:UnregisterEvent(ev) self._events[ev] = nil end
        function w:UnregisterAllEvents() self._events = {} end
        function w:SetScript(ev, fn) self._scripts[ev] = fn end
        function w:GetScript(ev) return self._scripts[ev] end
        function w:HookScript(ev, fn)
            local prev = self._scripts[ev]
            self._scripts[ev] = function(...) if prev then prev(...) end; fn(...) end
        end
        function w:CreateTexture()
            local t = MakeWidget("Texture", nil, self)
            table.insert(self._regions, t)
            return t
        end
        function w:CreateFontString()
            local fs = MakeWidget("FontString", nil, self)
            table.insert(self._regions, fs)
            return fs
        end
        function w:CreateAnimationGroup()
            return {
                CreateAnimation = function() return { SetDuration = function() end, SetOrder = function() end, SetFromAlpha = function() end, SetToAlpha = function() end } end,
                SetScript = function() end, Play = function() end, Pause = function() end, Stop = function() end,
            }
        end
        table.insert(state.allFrames, w)
        if name then env[name] = w end
        return w
    end

    env.UIParent = MakeWidget("Frame", "UIParent", nil)
    env.UIParent:SetSize(opts.uipW or 1920, opts.uipH or 1080)
    env.UIParent._shown = true

    env.CreateFrame = function(wType, name, parent)
        local fr = MakeWidget(wType, name, parent)
        table.insert(state.eventFrames, fr)
        return fr
    end

    local gt = MakeWidget("GameTooltip", "GameTooltip", env.UIParent)
    gt.SetOwner = function() state.tooltipSetText = nil end
    gt.SetText = function(_, txt) state.tooltipSetText = txt end
    gt.AddLine = function() end
    gt.AddDoubleLine = function() end

    env.GeneralDockManager = MakeWidget("Frame", "GeneralDockManager", env.UIParent)
    env.GeneralDockManager._shown = true
    env.GeneralDockManagerScrollFrame = MakeWidget("ScrollFrame", "GeneralDockManagerScrollFrame", env.GeneralDockManager)
    env.GeneralDockManagerScrollFrameChild = MakeWidget("Frame", "GeneralDockManagerScrollFrameChild", env.GeneralDockManagerScrollFrame)
    env.DOCKED_CHAT_FRAMES = {}

    local cf1 = MakeWidget("ScrollingMessageFrame", "ChatFrame1", env.UIParent)
    cf1._shown = true
    cf1:SetSize(430, 200)
    cf1:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 0, 0)
    cf1.name = "General"
    cf1.isDocked = 1
    cf1.FontStringContainer = MakeWidget("Frame", "ChatFrame1FontStringContainer", cf1)
    cf1.ScrollBar = MakeWidget("Slider", "ChatFrame1ScrollBar", cf1)
    cf1.ScrollToBottomButton = MakeWidget("Button", "ChatFrame1ScrollToBottomButton", cf1)
    cf1.Background = MakeWidget("Texture", "ChatFrame1Background", cf1)
    cf1.buttonFrame = MakeWidget("Frame", "ChatFrame1ButtonFrame", cf1)
    cf1.ResizeButton = MakeWidget("Button", "ChatFrame1ResizeButton", cf1)
    local tab1 = MakeWidget("Button", "ChatFrame1Tab", env.GeneralDockManager)
    tab1._shown = true
    tab1:SetText("General")
    tab1.Text = tab1:CreateFontString()
    tab1.Text:SetText("General")
    tab1.GetFontString = function() return tab1.Text end
    cf1.tab = tab1

    local eb1 = MakeWidget("EditBox", "ChatFrame1EditBox", env.UIParent)
    eb1._shown = true
    eb1._hasFocus = false
    eb1._attrs.chatType = "SAY"
    eb1.header = eb1:CreateFontString()
    eb1.header:SetText("Say: ")
    eb1.FocusLeft = MakeWidget("Texture", "ChatFrame1EditBoxFocusLeft", eb1)
    eb1.FocusMid = MakeWidget("Texture", "ChatFrame1EditBoxFocusMid", eb1)
    eb1.FocusRight = MakeWidget("Texture", "ChatFrame1EditBoxFocusRight", eb1)
    cf1.editBox = eb1
    env.GeneralDockManager.primary = cf1
    env.GeneralDockManager.selected = cf1
    table.insert(env.DOCKED_CHAT_FRAMES, cf1)

    env.ChatEdit_GetActiveWindow = function() return nil end
    env.ChatEdit_ActivateChat = function() end
    env.ChatEdit_UpdateHeader = function() end
    env.ChatEdit_OnTextChanged = function() end
    env.ChatEdit_OnSpacePressed = function() end
    env.ChatFrameEditBoxMixin = { OnTextChanged = function() end, OnSpacePressed = function() end }
    env.FCF_SelectDockFrame = function() end
    env.FCF_OpenTemporaryWindow = function() return nil end
    env.FCF_Close = function() end
    env.FCF_GetCurrentChatFrame = function() return cf1 end
    env.FCFDock_UpdateTabs = function() end
    env.FCF_SetTabPosition = function() end
    env.UIFrameIsFading = function() return false end
    env.UIFrameFadeOut = function() end
    env.UIFrameFadeIn = function() end
    env.UIFrameFlash = function() end
    env.UIFrameFlashStop = function() end
    env.FCF_RestorePositionAndDimensions = function(chatFrame)
        if chatFrame == cf1 then
            cf1:SetSize(430, 200)
            cf1:ClearAllPoints()
            cf1:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 32, 95)
        end
    end
    env.FCF_SavePositionAndDimensions = function() end
    env.EditModeManagerFrame = MakeWidget("Frame", "EditModeManagerFrame", env.UIParent)
    env.EditModeManagerFrame.IsEditModeActive = function() return state.editModeActive == true end
    env.EditModeChatFrameSystemMixin = {
        ApplySystemAnchor = function() end,
        UpdateSystem = function(_, frame)
            if frame == cf1 then
                cf1:SetSize(430, 200)
                cf1:ClearAllPoints()
                cf1:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 32, 95)
            end
        end,
        UpdateSystemSettingWidth = function(_, frame)
            if frame == cf1 then cf1:SetWidth(430) end
        end,
        UpdateSystemSettingHeight = function(_, frame)
            if frame == cf1 then cf1:SetHeight(200) end
        end,
        UpdateSystemSetting = function() end,
    }

    local sharedTbl = {}
    for _, path in ipairs({ CORE_PATH, CHAT_PATH, UI_PATH }) do
        local chunk, err = loadfile(path)
        assertTrue(chunk ~= nil, "Failed to load " .. path .. ": " .. tostring(err))
        setfenv(chunk, env)
        chunk("DynamicSuite", sharedTbl)
    end

    local function FireEvent(ev, ...)
        for _, ef in ipairs(state.eventFrames) do
            if ef._events[ev] and ef._scripts.OnEvent then
                ef._scripts.OnEvent(ef, ev, ...)
            end
        end
    end

    local function FlushTimers()
        local batch = state.timers
        state.timers = {}
        for _, entry in ipairs(batch) do
            if not entry.cancelled and type(entry.fn) == "function" then
                entry.fn()
            end
        end
    end

    FireEvent("ADDON_LOADED", "DynamicSuite")
    FireEvent("PLAYER_LOGIN")
    FireEvent("PLAYER_ENTERING_WORLD", true, false)
    FlushTimers()

    return {
        env = env,
        state = state,
        sharedTbl = sharedTbl,
        cf1 = cf1,
        eb1 = eb1,
        FireEvent = FireEvent,
        FlushTimers = FlushTimers,
    }
end

-- ============================================================================
-- T1: HUD Edit Mode resize grip commits & survives full simulated /reload
-- ============================================================================
RunTest("T1: HUD Edit Mode CHAT resize persists custom width & height across simulated /reload (BOTTOM & TOP editBox)", function()
    local h1 = CreateHarness()
    h1.sharedTbl.CreateMainConfigUI()
    h1.sharedTbl.EnterHudEditMode("CHAT")

    local resizeGrip = nil
    for _, fr in ipairs(h1.state.allFrames) do
        if fr._type == "Button" and type(fr._scripts.OnEnter) == "function" then
            h1.state.tooltipSetText = nil
            pcall(fr._scripts.OnEnter, fr)
            if h1.state.tooltipSetText == "Resize Chat Frame" then
                resizeGrip = fr
                break
            end
        end
    end
    assertTrue(resizeGrip ~= nil, "HUD Edit Mode CHAT resize grip located")

    -- Drag grip right +190, down -140 -> 430+190 = 620, 200+140 = 340
    h1.state.cursorX = 500
    h1.state.cursorY = 400
    h1.state.lmbDown = true
    resizeGrip:GetScript("OnDragStart")(resizeGrip)

    h1.state.cursorX = 690
    h1.state.cursorY = 260
    resizeGrip:GetScript("OnUpdate")(resizeGrip, 0.016)
    assertEqual(h1.cf1:GetWidth(), 620, "Live resize stepped ChatFrame1 width to 620")
    assertEqual(h1.cf1:GetHeight(), 340, "Live resize stepped ChatFrame1 height to 340")

    -- Release mouse button inside OnUpdate (WoW often drops mouse before OnDragStop fires cleanly)
    h1.state.lmbDown = false
    resizeGrip:GetScript("OnUpdate")(resizeGrip, 0.016)
    if resizeGrip:GetScript("OnMouseUp") then
        resizeGrip:GetScript("OnMouseUp")(resizeGrip, "LeftButton")
    end
    if resizeGrip:GetScript("OnDragStop") then
        resizeGrip:GetScript("OnDragStop")(resizeGrip)
    end
    h1.sharedTbl.ExitHudEditMode(false)

    assertEqual(h1.env.DynamicChatDB.chatFramePos.width, 620, "DynamicChatDB saved resized width 620")
    assertEqual(h1.env.DynamicChatDB.chatFramePos.height, 340, "DynamicChatDB saved resized height 340")
    local hudChat = h1.env.DynamicSuiteDB.global.hudPositions["CHAT"]
    assertTrue(type(hudChat) == "table", "hudPositions['CHAT'] saved")
    assertEqual(hudChat.width, 620, "hudPositions['CHAT'].width saved as 620")
    assertEqual(hudChat.height, 340, "hudPositions['CHAT'].height saved as 340")

    -- Simulate full /reload keeping ONLY SavedVariables tables (new ChatFrame1 starts at Blizzard 430x200)
    local persistedChatDB = h1.env.CopyTable(h1.env.DynamicChatDB)
    local persistedSuiteDB = h1.env.CopyTable(h1.env.DynamicSuiteDB)
    local h2 = CreateHarness(persistedChatDB, persistedSuiteDB)
    -- Flush any delayed 0.15s / 0.25s / 0.50s post-login timers (ClampAllSuiteHudsToScreen + RequestCoalescedChatLayout)
    h2.FlushTimers()

    assertEqual(h2.cf1:GetWidth(), 620, "Post-reload ChatFrame1 width restored to 620")
    assertEqual(h2.cf1:GetHeight(), 340, "Post-reload ChatFrame1 height restored to 340")
    assertEqual(h2.env.DynamicChatDB.chatFramePos.width, 620, "Post-reload DynamicChatDB width still 620")
    assertEqual(h2.env.DynamicChatDB.chatFramePos.height, 340, "Post-reload DynamicChatDB height still 340")

    -- Check embedded EditBox (BOTTOM) & FontStringContainer recalculated for 620x340
    local ebPt = h2.eb1:GetPoint(1)
    local fscPt1 = h2.cf1.FontStringContainer:GetPoint(1)
    assertEqual(ebPt, "BOTTOMLEFT", "BOTTOM EditBox anchored cleanly after reload")
    assertEqual(fscPt1, "TOPLEFT", "FontStringContainer recalculated cleanly for BOTTOM EditBox")

    -- Switch to TOP EditBox after reload -> recalculates TOPLEFT embed + FontStringContainer
    h2.env.DynamicChatDB.editBoxPosition = "TOP"
    h2.env.DynamicChat:ApplySavedChatFramePosition()
    local ebPtTop = h2.eb1:GetPoint(1)
    assertEqual(ebPtTop, "TOPLEFT", "TOP EditBox anchored cleanly at TOPLEFT for 620x340")
end)

-- ============================================================================
-- T2: ClampAllSuiteHudsToScreen + Blizzard Edit Mode / FCF_RestorePositionAndDimensions
-- ============================================================================
RunTest("T2: ClampAllSuiteHudsToScreen and Blizzard Edit Mode / FCF_RestorePositionAndDimensions preserve 620x340", function()
    local persistedChatDB = {
        chatAnchorVersion = 5,
        enableSleekChatSkin = true,
        editBoxPosition = "BOTTOM",
        chatFramePos = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 40, y = 25, width = 620, height = 340 },
    }
    local persistedSuiteDB = {
        global = {
            hudPositions = {
                CHAT = { point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 40, y = 25, width = 620, height = 340 },
            },
        },
    }
    local h = CreateHarness(persistedChatDB, persistedSuiteDB)
    h.FlushTimers()
    assertEqual(h.cf1:GetWidth(), 620, "Initial load restored width 620")
    assertEqual(h.cf1:GetHeight(), 340, "Initial load restored height 340")

    -- Trigger ClampAllSuiteHudsToScreen directly even if cf1 were shrunk before clamping
    h.sharedTbl.ClampAllSuiteHudsToScreen()
    assertEqual(h.cf1:GetWidth(), 620, "ClampAllSuiteHudsToScreen preserves width 620")
    assertEqual(h.cf1:GetHeight(), 340, "ClampAllSuiteHudsToScreen preserves height 340")

    -- Simulate Blizzard resetting size back to 430x200 via Edit Mode & FCF_RestorePositionAndDimensions
    h.env.FCF_RestorePositionAndDimensions(h.cf1)
    h.env.EditModeChatFrameSystemMixin:UpdateSystemSettingWidth(h.cf1)
    h.env.EditModeChatFrameSystemMixin:UpdateSystemSettingHeight(h.cf1)
    h.env.EditModeChatFrameSystemMixin:UpdateSystem(h.cf1)
    h.FlushTimers()

    assertEqual(h.cf1:GetWidth(), 620, "Post-EditMode/FCF pass restores width 620 instead of 430")
    assertEqual(h.cf1:GetHeight(), 340, "Post-EditMode/FCF pass restores height 340 instead of 200")
    assertEqual(h.env.DynamicChatDB.chatFramePos.width, 620, "Saved width remains 620")
    assertEqual(h.env.DynamicChatDB.chatFramePos.height, 340, "Saved height remains 340")
    assertEqual(h.env.DynamicSuiteDB.global.hudPositions["CHAT"].width, 620, "Suite hudPositions CHAT width remains 620")
    assertEqual(h.env.DynamicSuiteDB.global.hudPositions["CHAT"].height, 340, "Suite hudPositions CHAT height remains 340")
end)

-- ============================================================================
-- T3: Early-Boot Unsettled UIParent Guard in ClampChatFrameCoords
-- ============================================================================
RunTest("T3: Early-boot unsettled UIParent (0x0 / 320x200) never shrinks saved 680x360 size", function()
    local persistedChatDB = {
        chatAnchorVersion = 5,
        enableSleekChatSkin = true,
        editBoxPosition = "BOTTOM",
        chatFramePos = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 60, y = 40, width = 680, height = 360 },
    }
    local h = CreateHarness(persistedChatDB, nil, { uipW = 0, uipH = 0 })

    local cx, cy, cw, ch, settled = h.env.DynamicChat:ClampChatFrameCoords(60, 40, 680, 360, "BOTTOMLEFT")
    assertEqual(settled, false, "0x0 UIParent flagged as unsettled")
    assertEqual(cw, 680, "ClampChatFrameCoords keeps saved width 680 while UIParent is 0x0")
    assertEqual(ch, 360, "ClampChatFrameCoords keeps saved height 360 while UIParent is 0x0")
    assertEqual(cx, 60, "ClampChatFrameCoords keeps saved X 60 while unsettled")
    assertEqual(cy, 40, "ClampChatFrameCoords keeps saved Y 40 while unsettled")

    -- Test tiny 320x200 UIParent during early boot
    h.env.UIParent:SetSize(320, 200)
    h.env.DynamicChat:ApplySavedChatFramePosition()
    assertEqual(h.env.DynamicChatDB.chatFramePos.width, 680, "Early boot 320x200 never overwrites saved width 680")
    assertEqual(h.env.DynamicChatDB.chatFramePos.height, 360, "Early boot 320x200 never overwrites saved height 360")

    -- Settle UIParent to 1920x1080 and apply -> restores cleanly to 680x360
    h.env.UIParent:SetSize(1920, 1080)
    h.env.DynamicChat:ApplySavedChatFramePosition()
    assertEqual(h.cf1:GetWidth(), 680, "Settled viewport applies width 680")
    assertEqual(h.cf1:GetHeight(), 360, "Settled viewport applies height 360")
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
