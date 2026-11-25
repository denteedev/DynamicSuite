-- ============================================================================
-- Headless Lua 5.1 Regression Suite: In-World HUD Shift-Drag & Discoverability
-- Exercises real DynamicSuite_Core.lua and real DynamicMarker.lua (both bundled
-- Suite and Standalone modes) across all 6 canonical HUDs, tooltip hints,
-- 0px UIParent clamping, combat lockdown guards, Quick Guides, and Search.
-- Pure ASCII Only.
-- ============================================================================

local CORE_PATH   = "DynamicSuite/DynamicSuite_Core.lua"
local MARKER_PATH = "DynamicSuite/Modules/DynamicMarker.lua"

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

local function CreateEnv()
    local env = {}
    setmetatable(env, { __index = _G })
    env._G = env

    local state = {
        inCombat = false,
        shiftDown = false,
        lmbDown = true,
        now = 100.0,
        cursorX = 500,
        cursorY = 400,
        enterHudCalls = {},
        printLog = {},
        eventFrames = {},
        tooltipLines = {},
        tooltipOwner = nil,
        tooltipAnchor = nil,
    }

    env.wipe = function(t) if type(t) == "table" then for k in pairs(t) do t[k] = nil end end; return t end
    env.tinsert = table.insert
    env.tremove = table.remove
    env.CopyTable = function(src)
        if type(src) ~= "table" then return src end
        local dst = {}
        for k, v in pairs(src) do
            dst[k] = (type(v) == "table") and env.CopyTable(v) or v
        end
        return dst
    end
    env.GetTime = function() return state.now end
    env.UnitName = function() return "Testchar" end
    env.UnitGUID = function() return "Player-1234-0001" end
    env.UnitClass = function() return "Mage", "MAGE", 8 end
    env.GetRealmName = function() return "Frostmourne" end
    env.IsInRaid = function() return false end
    env.IsInGroup = function() return false end
    env.GetNumGroupMembers = function() return 0 end
    env.GetNumSubgroupMembers = function() return 0 end
    env.UnitIsGroupLeader = function() return false end
    env.UnitIsGroupAssistant = function() return false end
    env.InCombatLockdown = function() return state.inCombat end
    env.IsShiftKeyDown = function() return state.shiftDown end
    env.IsControlKeyDown = function() return false end
    env.IsMouseButtonDown = function(btn)
        if btn == "LeftButton" then return state.lmbDown end
        return false
    end
    env.GetCursorPosition = function() return state.cursorX, state.cursorY end
    env.PlaySound = function() end
    env.PlaySoundFile = function() end
    env.ReloadUI = function() end
    env.UISpecialFrames = {}
    env.SlashCmdList = {}
    env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    env.SOUNDKIT = { UI_BNET_TOAST = 18019, IG_CHARACTER_INFO_TAB = 841, IG_MAINMENU_OPTION_CHECKBOX_ON = 856 }
    env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    env.UNKNOWNOBJECT = "Unknown"
    env.issecretvalue = function() return false end
    env.canaccessvalue = function() return true end
    env.C_Timer = {
        After = function(_, fn) end,
        NewTimer = function(_, fn) return { Cancel = function() end, fn = fn } end,
    }
    env.C_CVar = {
        GetCVar = function() return "1" end,
        GetCVarBool = function() return false end,
        SetCVar = function() end,
        GetCVarDefault = function() return "1" end,
    }
    env.C_AddOns = {
        GetAddOnMetadata = function() return "2.10.3" end,
        IsAddOnLoaded = function(name) return name == "DynamicSuite" end,
        GetAddOnInfo = function(name) return name, name, "", true, "INSECURE", false end,
        GetAddOnEnableState = function() return 2 end,
    }
    env.C_Map = { GetMapInfo = function() return { name = "Dornogal" } end }
    env.GetNumAddOns = function() return 0 end
    env.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[#parts + 1] = tostring(select(i, ...))
        end
        state.printLog[#state.printLog + 1] = table.concat(parts, " ")
    end

    local function MakeMockFrame(ftype, name)
        local f = {
            _type = ftype,
            _name = name,
            _shown = false,
            _scripts = {},
            _points = {},
            _attrs = {},
            _children = {},
            _events = {},
            _w = 100,
            _h = 30,
            _scale = 1.0,
            _alpha = 1.0,
            _cx = 960,
            _cy = 540,
            _mouseOver = false,
            _mouseEnabled = true,
            _moving = false,
        }
        function f:SetScript(ev, fn) self._scripts[ev] = fn end
        function f:HookScript(ev, fn)
            local prev = self._scripts[ev]
            if prev then
                self._scripts[ev] = function(...)
                    prev(...)
                    fn(...)
                end
            else
                self._scripts[ev] = fn
            end
        end
        function f:GetScript(ev) return self._scripts[ev] end
        function f:FireScript(ev, ...)
            if type(self._scripts[ev]) == "function" then
                return self._scripts[ev](self, ...)
            end
        end
        function f:RegisterEvent(ev)
            self._events[ev] = true
            state.eventFrames[#state.eventFrames + 1] = self
        end
        function f:UnregisterEvent(ev) self._events[ev] = nil end
        function f:Show()
            self._shown = true
            self:FireScript("OnShow")
        end
        function f:Hide()
            self._shown = false
            self:FireScript("OnHide")
        end
        function f:SetShown(b)
            if b then self:Show() else self:Hide() end
        end
        function f:IsShown() return self._shown end
        function f:IsVisible() return self._shown end
        function f:Raise() end
        function f:SetPoint(pt, relTo, relPt, x, y)
            if type(relTo) == "number" then
                y = relPt
                x = relTo
                relPt = pt
                relTo = env.UIParent
            end
            table.insert(self._points, { pt or "CENTER", relTo or env.UIParent, relPt or pt or "CENTER", tonumber(x) or 0, tonumber(y) or 0 })
            if relTo == env.UIParent or relTo == nil then
                local uiW = (env.UIParent and env.UIParent._w) or 1920
                local uiH = (env.UIParent and env.UIParent._h) or 1080
                local p = tostring(pt or "CENTER"):upper()
                local rp = tostring(relPt or pt or "CENTER"):upper()
                local function Frac(s)
                    local fx = s:find("LEFT", 1, true) and 0 or (s:find("RIGHT", 1, true) and 1 or 0.5)
                    local fy = s:find("BOTTOM", 1, true) and 0 or (s:find("TOP", 1, true) and 1 or 0.5)
                    return fx, fy
                end
                local pfx, pfy = Frac(p)
                local rfx, rfy = Frac(rp)
                local ox = tonumber(x) or 0
                local oy = tonumber(y) or 0
                self._cx = (rfx * uiW) + ox + (0.5 - pfx) * (self._w or 100)
                self._cy = (rfy * uiH) + oy + (0.5 - pfy) * (self._h or 30)
            end
        end
        function f:SetAllPoints() end
        function f:GetPoint(idx)
            local p = self._points[idx or 1]
            if p then return p[1], p[2], p[3], p[4], p[5] end
            return "CENTER", env.UIParent, "CENTER", 0, 0
        end
        function f:ClearAllPoints() self._points = {} end
        function f:SetSize(w, h) self._w = w; self._h = h end
        function f:SetWidth(w) self._w = w end
        function f:SetHeight(h) self._h = h end
        function f:GetWidth() return self._w end
        function f:GetHeight() return self._h end
        function f:GetCenter() return self._cx, self._cy end
        function f:GetTop() return self._cy + (self._h * 0.5) end
        function f:GetBottom() return self._cy - (self._h * 0.5) end
        function f:GetLeft() return self._cx - (self._w * 0.5) end
        function f:GetRight() return self._cx + (self._w * 0.5) end
        function f:SetScale(s) self._scale = s or 1.0 end
        function f:GetScale() return self._scale end
        function f:GetEffectiveScale() return self._scale end
        function f:SetAlpha(a) self._alpha = a or 1.0 end
        function f:GetAlpha() return self._alpha end
        function f:SetFrameStrata() end
        function f:SetFrameLevel(lvl) self._level = lvl end
        function f:GetFrameLevel() return self._level or 5 end
        function f:SetToplevel() end
        function f:SetClampedToScreen() end
        function f:SetClampRectInsets() end
        function f:SetClipsChildren() end
        function f:SetIgnoreParentAlpha() end
        function f:SetMinResize() end
        function f:SetMaxResize() end
        function f:GetFontString() return nil end
        function f:SetNormalFontObject() end
        function f:SetHighlightTexture() end
        function f:GetBackdropBorderColor() return 1, 1, 1, 1 end
        function f:GetBackdropColor() return 0, 0, 0, 1 end
        function f:SetParent(p) self._parent = p end
        function f:GetParent() return self._parent or env.UIParent end
        function f:EnableMouse(flag) self._mouseEnabled = (flag ~= false) end
        function f:EnableMouseWheel() end
        function f:EnableKeyboard() end
        function f:SetMovable() end
        function f:SetResizable() end
        function f:SetResizeBounds() end
        function f:RegisterForDrag() end
        function f:RegisterForClicks() end
        function f:StartMoving() self._moving = true end
        function f:StartSizing() self._sizing = true end
        function f:StopMovingOrSizing() self._moving = false; self._sizing = false end
        function f:GetVerticalScrollRange() return 0 end
        function f:UpdateScrollChildRect() end
        function f:SetOrientation() end
        function f:SetHitRectInsets() end
        function f:SetMinMaxValues() end
        function f:SetValueStep() end
        function f:SetObeyStepOnDrag() end
        function f:SetValue(v) self._val = v end
        function f:GetValue() return self._val or 1 end
        function f:SetThumbTexture(t) self._thumb = t end
        function f:GetThumbTexture() return self._thumb or self:CreateTexture() end
        function f:SetEnabled() end
        function f:IsEnabled() return true end
        function f:SetBackdrop() end
        function f:SetBackdropColor() end
        function f:SetBackdropBorderColor(r, g, b, a) self._borderColor = { r, g, b, a } end
        function f:SetAttribute(k, v) self._attrs[k] = v end
        function f:GetAttribute(k) return self._attrs[k] end
        function f:IsMouseOver() return self._mouseOver end
        function f:SetPropagateKeyboardInput() end
        function f:GetChildren() return unpack(self._children) end
        function f:HasFocus() return false end
        function f:SetAutoFocus() end
        function f:SetMultiLine() end
        function f:SetTextInsets() end
        function f:ClearFocus() end
        function f:SetFocus() end
        function f:HighlightText() end
        function f:SetMaxLetters() end
        function f:SetFont(p, sz, fl) self._font = p or "Fonts\\FRIZQT__.TTF"; self._size = sz or 12; self._flags = fl or ""; return true end
        function f:GetFont() return self._font or "Fonts\\FRIZQT__.TTF", self._size or 12, self._flags or "" end
        function f:SetShadowColor() end
        function f:SetShadowOffset() end
        function f:SetTextColor() end
        function f:SetJustifyV() end
        function f:SetWordWrap() end
        function f:SetJustifyH() end
        function f:SetFontObject() end
        function f:SetText() end
        function f:GetText() return "" end
        function f:SetVerticalScroll() end
        function f:GetVerticalScroll() return 0 end
        function f:SetScrollChild() end
        function f:CreateAnimationGroup()
            local ag = { _playing = false, _paused = false }
            function ag:CreateAnimation()
                local anim = {}
                function anim:SetDuration() end
                function anim:SetOrder() end
                function anim:SetFromAlpha() end
                function anim:SetToAlpha() end
                return anim
            end
            function ag:SetScript() end
            function ag:Play() self._playing = true; self._paused = false end
            function ag:Pause() self._paused = true end
            function ag:Stop() self._playing = false; self._paused = false end
            return ag
        end
        function f:CreateTexture()
            local tex = { _color = {}, _shown = true }
            function tex:SetAllPoints() end
            function tex:SetPoint() end
            function tex:ClearAllPoints() end
            function tex:SetSize() end
            function tex:SetWidth() end
            function tex:SetHeight() end
            function tex:SetColorTexture(r, g, b, a) self._color = { r, g, b, a } end
            function tex:SetTexture() end
            function tex:SetDesaturated() end
            function tex:SetBlendMode() end
            function tex:SetAtlas() end
            function tex:SetVertexColor() end
            function tex:SetTexCoord() end
            function tex:SetRotation() end
            function tex:SetSnapToPixelGrid() end
            function tex:SetTexelSnappingBias() end
            function tex:Show() self._shown = true end
            function tex:Hide() self._shown = false end
            return tex
        end
        function f:CreateFontString()
            local fs = { _text = "", _shown = true, _font = "Fonts\\FRIZQT__.TTF", _size = 12, _flags = "" }
            function fs:SetPoint() end
            function fs:ClearAllPoints() end
            function fs:SetFont(p, sz, fl)
                self._font = p or self._font
                self._size = sz or self._size
                self._flags = fl or self._flags
                return true
            end
            function fs:GetFont() return self._font, self._size, self._flags end
            function fs:SetShadowColor() end
            function fs:SetShadowOffset() end
            function fs:SetTextColor() end
            function fs:SetWidth(w) self._w = w end
            function fs:SetHeight(h) self._h = h end
            function fs:SetSize(w, h) self._w = w; self._h = h end
            function fs:GetWidth() return self._w or 100 end
            function fs:GetHeight() return self._h or 14 end
            function fs:SetAlpha() end
            function fs:SetJustifyH() end
            function fs:SetJustifyV() end
            function fs:SetWordWrap() end
            function fs:SetSpacing() end
            function fs:SetNonSpaceWrap() end
            function fs:SetMaxLines() end
            function fs:SetText(t) self._text = tostring(t or "") end
            function fs:GetText() return self._text end
            function fs:GetStringWidth() return #self._text * 6 end
            function fs:GetUnboundedStringWidth() return #self._text * 6 end
            function fs:GetStringHeight() return 14 end
            function fs:Show() self._shown = true end
            function fs:Hide() self._shown = false end
            return fs
        end
        if name then env[name] = f end
        return f
    end

    env.UIParent = MakeMockFrame("Frame", "UIParent")
    env.UIParent:SetSize(1920, 1080)
    env.UIParent._cx = 960
    env.UIParent._cy = 540

    local gt = MakeMockFrame("GameTooltip", "GameTooltip")
    function gt:SetOwner(owner, anchor)
        state.tooltipOwner = owner
        state.tooltipAnchor = anchor
        state.tooltipLines = {}
    end
    function gt:ClearLines() state.tooltipLines = {} end
    function gt:SetText(txt)
        state.tooltipLines = { tostring(txt or "") }
    end
    function gt:AddLine(txt)
        state.tooltipLines[#state.tooltipLines + 1] = tostring(txt or "")
    end
    function gt:IsOwned(owner)
        return state.tooltipOwner == owner and self._shown
    end
    env.GameTooltip = gt

    env.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
    env.CreateFrame = function(ftype, name, parent)
        local fr = MakeMockFrame(ftype, name)
        if parent and parent._children then
            parent._children[#parent._children + 1] = fr
        end
        return fr
    end
    env.hooksecurefunc = function() end

    function state.FireEvent(ev, ...)
        for _, ef in ipairs(state.eventFrames) do
            if ef._events[ev] and ef._scripts and ef._scripts.OnEvent then
                ef._scripts.OnEvent(ef, ev, ...)
            end
        end
    end

    return env, state
end

local function LoadChunkIntoEnv(path, env, addonName, sharedTbl)
    local chunk, err = loadfile(path)
    assertTrue(chunk ~= nil, "Failed to load " .. path .. ": " .. tostring(err))
    setfenv(chunk, env)
    return chunk(addonName, sharedTbl)
end

local function BootFullSuiteEnv()
    local env, state = CreateEnv()
    local sharedTbl = {}
    LoadChunkIntoEnv(CORE_PATH, env, "DynamicSuite", sharedTbl)
    env.DynamicSuite._isHubLoaded = true
    env.DynamicSuite.EnterHudEditMode = function(targetKey)
        state.enterHudCalls[#state.enterHudCalls + 1] = targetKey
    end
    LoadChunkIntoEnv(MARKER_PATH, env, "DynamicSuite", sharedTbl)
    env.DynamicMarker:InitDB()
    return env, state, sharedTbl
end

local function BootStandaloneMarkerEnv()
    local env, state = CreateEnv()
    local sharedTbl = {}
    env.C_AddOns.IsAddOnLoaded = function(name) return name == "DynamicMarker" end
    env.C_AddOns.GetAddOnEnableState = function(name) return (name == "DynamicMarker") and 2 or 0 end
    LoadChunkIntoEnv(MARKER_PATH, env, "DynamicMarker", sharedTbl)
    env.DynamicMarker:InitDB()
    return env, state
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

-- ----------------------------------------------------------------------------
-- Test 1: Tooltip formatting & AppendHudTooltipHints (/ds hud vs /dm hud)
-- ----------------------------------------------------------------------------
RunTest("1. FormatTooltipCommand and AppendHudTooltipHints", function()
    local env, state = BootFullSuiteEnv()
    local line = env.DynamicSuite.FormatTooltipCommand("Shift + Left-Drag", "Move bar", "34D399")
    assertEqual(line, "|cFF34D399Shift + Left-Drag:|r |cFFE2E8F0Move bar|r", "Formatted tooltip command")

    env.GameTooltip:SetOwner(env.UIParent, "ANCHOR_TOP")
    env.DynamicSuite.AppendHudTooltipHints(env.GameTooltip, {
        moveLabel = "Move Alert Toast",
        editModeTrigger = "Shift + Right-Click:",
        hudCmd = "/ds hud",
        includeDismiss = true,
        addSpacer = true,
    })
    assertEqual(#state.tooltipLines, 4, "Spacer + Dismiss + Shift+Left-Drag + Shift+Right-Click")
    assertTrue(state.tooltipLines[2]:find("Right%-Click:", 1) ~= nil, "Includes Right-Click dismiss line")
    assertTrue(state.tooltipLines[3]:find("Shift %+ Left%-Drag:", 1) ~= nil, "Includes Shift + Left-Drag line")
    assertTrue(state.tooltipLines[4]:find("/ds hud", 1, true) ~= nil, "Includes /ds hud")
end)

-- ----------------------------------------------------------------------------
-- Test 2: Strict 0px UIParent clamping across anchors, scales, and Chat insets
-- ----------------------------------------------------------------------------
RunTest("2. ClampPointOffsetToUIParent 0px strict bounds", function()
    local env = BootFullSuiteEnv()
    local clamp = env.DynamicSuite.ClampPointOffsetToUIParent

    -- TOP anchor: 460x74 at scale 1.0 in 1920x1080 -> x in [-730, 730], y in [-1006, 0]
    local ox1, oy1, c1 = clamp(460, 74, 1.0, 1920, 1080, 1.0, "TOP", "TOP", -1500, 120)
    assertTrue(c1 == true, "TOP extreme offscreen should clamp")
    assertEqual(ox1, -730, "TOP left edge clamped to 0px")
    assertEqual(oy1, 0, "TOP top edge clamped to 0px")

    local ox2, oy2 = clamp(460, 74, 1.0, 1920, 1080, 1.0, "TOP", "TOP", 1500, -1500)
    assertEqual(ox2, 730, "TOP right edge clamped to 0px")
    assertEqual(oy2, -1006, "TOP bottom edge clamped to 0px")

    -- CENTER anchor with 1.25 scale on 324x40 bar -> visW = 405, visH = 50 -> local center max
    local cx1, cy1 = clamp(324, 40, 1.25, 1920, 1080, 1.0, "CENTER", "CENTER", 2000, -2000)
    assertTrue(cx1 * 1.25 + (324 * 1.25 * 0.5) <= 960 + 1, "Scaled CENTER right edge inside 1920")
    assertTrue(cy1 * 1.25 - (40 * 1.25 * 0.5) >= -540 - 1, "Scaled CENTER bottom edge inside 1080")

    -- BOTTOMLEFT anchor with Chat Frame extra insets { left=36, right=8, top=28, bottom=6 }
    local chX, chY = clamp(430, 200, 1.0, 1920, 1080, 1.0, "BOTTOMLEFT", "BOTTOMLEFT", -200, -100, {
        extraInsets = { left = 36, right = 8, top = 28, bottom = 6 },
    })
    assertEqual(chX, 36, "Chat left inset keeps outer panel left >= 0")
    assertEqual(chY, 6, "Chat bottom inset keeps outer panel bottom >= 0")

    local chMaxX, chMaxY = clamp(430, 200, 1.0, 1920, 1080, 1.0, "BOTTOMLEFT", "BOTTOMLEFT", 3000, 3000, {
        extraInsets = { left = 36, right = 8, top = 28, bottom = 6 },
    })
    assertEqual(chMaxX, 1920 - 430 - 8, "Chat right edge clamped inside UIParent")
    assertEqual(chMaxY, 1080 - 200 - 28, "Chat top edge clamped inside UIParent")
end)

-- ----------------------------------------------------------------------------
-- Test 3: AttachDirectHudShiftDrag lifecycle, Shift requirement & combat abort
-- ----------------------------------------------------------------------------
RunTest("3. AttachDirectHudShiftDrag combat and Shift guards", function()
    local env, state = BootFullSuiteEnv()
    local fr = env.CreateFrame("Button", "TestDirectDragFrame", env.UIParent)
    fr:SetSize(200, 40)
    local started, ended, abortedFlags = 0, 0, {}

    local ctrl = env.DynamicSuite.AttachDirectHudShiftDrag({
        frame = fr,
        targetKey = "PREP",
        onDragStart = function() started = started + 1 end,
        onDragEnd = function(aborted)
            ended = ended + 1
            abortedFlags[#abortedFlags + 1] = (aborted == true)
        end,
    })

    -- Rejected without Shift
    state.shiftDown = false
    assertEqual(ctrl.BeginDrag(), false, "Reject drag when Shift is up")
    assertEqual(started, 0, "onDragStart not called")

    -- Rejected during combat
    state.shiftDown = true
    state.inCombat = true
    assertEqual(ctrl.BeginDrag(), false, "Reject drag in combat")
    assertEqual(started, 0, "onDragStart not called in combat")

    -- Allowed out of combat with Shift
    state.inCombat = false
    assertEqual(ctrl.BeginDrag(), true, "Begin drag with Shift out of combat")
    assertEqual(started, 1, "onDragStart fired")
    assertTrue(ctrl.IsDragging(), "Controller reports dragging")
    assertTrue(fr._dsDragging == true, "Frame flagged as dragging")

    -- Combat begins mid-drag -> PLAYER_REGEN_DISABLED aborts drag
    state.inCombat = true
    state.FireEvent("PLAYER_REGEN_DISABLED")
    assertEqual(ended, 1, "onDragEnd fired on combat abort")
    assertEqual(abortedFlags[1], true, "abortedByCombat is true")
    assertTrue(not ctrl.IsDragging(), "Controller no longer dragging after combat abort")
    assertTrue(not fr._dsDragging, "Frame _dsDragging cleared after combat abort")

    -- OpenHudEditForTarget blocked in combat, succeeds out of combat
    assertEqual(ctrl.OpenEditMode(), false, "OpenEditMode blocked in combat")
    state.inCombat = false
    assertEqual(ctrl.OpenEditMode(), true, "OpenEditMode succeeds out of combat")
    assertEqual(state.enterHudCalls[#state.enterHudCalls], "PREP", "Routed to EnterHudEditMode('PREP')")
end)

-- ----------------------------------------------------------------------------
-- Test 4: Shared Alert Toast Shift-Drag, Shift+Right-Click & unmodified dismiss
-- ----------------------------------------------------------------------------
RunTest("4. Shared Alert Toast Shift-Drag, Shift+Right-Click & dismiss", function()
    local env, state = BootFullSuiteEnv()
    local dismissedCount = 0
    local actionClicked = 0
    local toast = env.DynamicSuite.EnsureSharedToastFrame("UnitTestSharedToast", {
        toastKind = "ACTION",
        autoFade = true,
        onRightClickDismiss = function(selfT)
            dismissedCount = dismissedCount + 1
            selfT:Hide()
        end,
    })
    local btn = env.CreateFrame("Button", nil, toast)
    btn:SetScript("OnClick", function() actionClicked = actionClicked + 1 end)
    toast.BindHoverPauseButton(btn)
    toast:Show()

    -- Unmodified Right-Click still dismisses
    state.shiftDown = false
    toast:FireScript("OnClick", "RightButton")
    assertEqual(dismissedCount, 1, "Unmodified Right-Click dismisses toast")
    assertTrue(not toast:IsShown(), "Toast hides on unmodified Right-Click")

    -- Re-show and Shift + Right-Click opens HUD Edit Mode('TOAST') without dismissing
    toast:Show()
    state.shiftDown = true
    toast:FireScript("OnClick", "RightButton")
    assertEqual(dismissedCount, 1, "Shift + Right-Click does not dismiss")
    assertTrue(toast:IsShown(), "Toast remains shown on Shift + Right-Click")
    assertEqual(state.enterHudCalls[#state.enterHudCalls], "TOAST", "Shift + Right-Click opens /ds hud on TOAST")

    -- Shift + Right-Click on action button also opens HUD Edit Mode('TOAST')
    btn:FireScript("OnClick", "RightButton")
    assertEqual(state.enterHudCalls[#state.enterHudCalls], "TOAST", "Action button Shift + Right-Click opens TOAST")
    assertEqual(actionClicked, 0, "Action button unmodified click handler not run on Shift+Right-Click")

    -- Shift + Left-Drag off-screen clamps strictly 0px inside UIParent and saves to both DBs
    state.shiftDown = true
    toast:FireScript("OnDragStart")
    toast._cx = 4000 -- extreme off right edge
    toast._cy = 2000 -- extreme off top edge
    toast:FireScript("OnDragStop")
    local gPos = env.DynamicSuiteDB.global.toastPos
    assertTrue(gPos ~= nil, "toastPos saved in DynamicSuiteDB.global")
    assertTrue(gPos.x <= 730, "Toast X clamped inside UIParent right edge")
    assertTrue(gPos.y <= 0, "Toast Y clamped inside UIParent top edge")

    -- Unmodified Left-Click on action button still works after suppress window
    state.now = state.now + 1.0
    state.shiftDown = false
    btn:FireScript("OnClick", "LeftButton")
    assertEqual(actionClicked, 1, "Action button unmodified Left-Click works normally")
end)

-- ----------------------------------------------------------------------------
-- Test 5: Standalone DynamicMarker full parity (bars, Shift-Drag, tip, '?')
-- ----------------------------------------------------------------------------
RunTest("5. Standalone DynamicMarker Shift-Drag, tip, and Quick Guide parity", function()
    local env, state = BootStandaloneMarkerEnv()
    local dm = env.DynamicMarker
    dm:InitTargetBar()
    dm:InitFlareBar()

    -- Verify shift-type1 / shift-type2 = "none" on all 8 TargetBar + 8 FlareBar secure buttons
    for i = 1, 8 do
        local tb = dm.targetBar.buttons[i]
        local fb = dm.flareBar.buttons[i]
        assertEqual(tb:GetAttribute("shift-type1"), "none", "TargetBar btn shift-type1 is none")
        assertEqual(tb:GetAttribute("shift-type2"), "none", "TargetBar btn shift-type2 is none")
        assertEqual(fb:GetAttribute("shift-type1"), "none", "FlareBar btn shift-type1 is none")
        assertEqual(fb:GetAttribute("shift-type2"), "none", "FlareBar btn shift-type2 is none")
    end

    -- Unmodified Left-Click sets focusIcon; Shift + Left-Click does NOT
    dm.db.focusIcon = 8
    state.shiftDown = true
    dm.targetBar.buttons[3]:FireScript("PostClick", "LeftButton", false)
    assertEqual(dm.db.focusIcon, 8, "Shift + Left-Click does not alter focusIcon")

    state.shiftDown = false
    dm.targetBar.buttons[3]:FireScript("PostClick", "LeftButton", false)
    assertEqual(dm.db.focusIcon, 3, "Unmodified Left-Click updates focusIcon")

    -- Shift + Left-Drag on TargetBar button moves & clamps strictly inside UIParent
    state.shiftDown = true
    dm.targetBar.buttons[3]:FireScript("OnDragStart")
    assertTrue(dm.targetBar._dmDirectDragActive == true, "TargetBar direct Shift-Drag activated via button")
    dm.targetBar._cx = 5000
    dm.targetBar._cy = -5000
    dm.targetBar.buttons[3]:FireScript("OnDragStop")
    assertTrue(not dm.targetBar._dmDirectDragActive, "TargetBar direct drag ended")
    assertTrue(dm.db.targetBarX <= 960, "TargetBar X clamped inside UIParent")
    assertTrue(dm.db.targetBarY >= -540, "TargetBar Y clamped inside UIParent")

    -- Shift + Right-Click on FlareBar button opens standalone HUD Edit Mode pre-targeted to FlareBar
    dm.flareBar.buttons[1]:FireScript("PostClick", "RightButton", false)
    assertTrue(dm.isEditMode == true, "Standalone HUD Edit Mode opened via Shift+Right-Click")
    assertEqual(dm.selectedHUDKey, "FlareBar", "FlareBar pre-selected in standalone inspector")
    assertTrue(dm.editInspector ~= nil and dm.editInspector.tipBar ~= nil, "Standalone inspector includes tipBar")
    assertTrue(dm.editInspector.tipBar.text:GetText():find("Shift %+ Left%-Drag", 1) ~= nil, "Inspector tip mentions Shift + Left-Drag")
    dm:SetEditMode(false)

    -- Right-Click on empty TargetBar opens standalone HUD Edit Mode pre-targeted to TargetBar
    state.shiftDown = false
    dm.targetBar:FireScript("OnMouseUp", "RightButton")
    assertTrue(dm.isEditMode == true, "Empty bar Right-Click opens standalone HUD Edit Mode")
    assertEqual(dm.selectedHUDKey, "TargetBar", "TargetBar pre-selected on empty bar Right-Click")
    dm:SetEditMode(false)

    -- Combat blocks opening HUD Edit Mode
    state.inCombat = true
    assertEqual(dm:OpenHudEditForTarget("TargetBar"), false, "Combat blocks OpenHudEditForTarget")
    assertTrue(not dm.isEditMode, "Edit mode stays closed during combat")
    state.inCombat = false

    -- Standalone shell has '?' Quick Guide button & QUICK_GUIDE modal
    local shell = dm:EnsureStandaloneShell()
    assertTrue(shell.Header and shell.Header.QuickGuideBtn ~= nil, "Standalone shell has '?' Quick Guide button")
    shell.Header.QuickGuideBtn:FireScript("OnClick")
    assertTrue(dm.modalFrame ~= nil and dm.modalFrame:IsShown(), "Quick Guide modal opens")
    assertEqual(dm.modalFrame.Title:GetText(), "DynamicMarker Quick Guide", "Quick Guide title matches")

    -- Tooltip hints on TargetBar button include /dm hud in standalone
    dm.targetBar.buttons[1]:FireScript("OnEnter")
    local joined = table.concat(state.tooltipLines, "\n")
    assertTrue(joined:find("/dm hud", 1, true) ~= nil, "Standalone tooltip shows /dm hud")
    assertTrue(joined:find("Shift + Left-Drag", 1, true) ~= nil, "Standalone tooltip shows Shift + Left-Drag")
end)

-- ----------------------------------------------------------------------------
-- Test 6: Bundled DynamicMarker routes Shift+Right-Click & tooltips to Suite
-- ----------------------------------------------------------------------------
RunTest("6. Bundled DynamicMarker routes HUD Edit Mode & tooltips to /ds hud", function()
    local env, state = BootFullSuiteEnv()
    local dm = env.DynamicMarker
    dm:InitTargetBar()
    dm:InitFlareBar()

    state.shiftDown = true
    dm.flareBar.buttons[2]:FireScript("PostClick", "RightButton", false)
    assertEqual(state.enterHudCalls[#state.enterHudCalls], "FLARE", "Bundled FlareBar routes to EnterHudEditMode('FLARE')")

    state.shiftDown = false
    dm.targetBar:FireScript("OnMouseUp", "RightButton")
    assertEqual(state.enterHudCalls[#state.enterHudCalls], "TARGET", "Bundled TargetBar empty Right-Click routes to EnterHudEditMode('TARGET')")

    dm.targetBar.buttons[1]:FireScript("OnEnter")
    local joined = table.concat(state.tooltipLines, "\n")
    assertTrue(joined:find("/ds hud", 1, true) ~= nil, "Bundled tooltip shows /ds hud")
end)

-- ----------------------------------------------------------------------------
-- Test 7: Quick Guides & Global Smart Search cover all 6 canonical HUD targets
-- ----------------------------------------------------------------------------
RunTest("7. Quick Guides & Global Smart Search cover Shift-Drag & all 6 HUDs", function()
    local env = BootFullSuiteEnv()
    local guides = env.DynamicSuite.MODULE_QUICK_GUIDES
    for _, key in ipairs({ "suite", "load", "prep", "marker", "chat" }) do
        local g = guides[key]
        assertTrue(g ~= nil, "Quick Guide exists for " .. key)
        local allTips = table.concat(g.tips or {}, "\n")
        assertTrue(allTips:find("Shift + Left-Drag", 1, true) ~= nil, "Quick Guide tips mention Shift + Left-Drag for " .. key)
    end

    local cat = env.DynamicSuite.SEARCH_INDEX_DATA
    assertTrue(type(cat) == "table", "SEARCH_INDEX_DATA exposed")
    for _, q in ipairs({ "shift drag", "move bar", "unlock hud" }) do
        local foundTargets = {}
        local qWords = {}
        for w in q:gmatch("%S+") do qWords[#qWords + 1] = w:lower() end
        for _, entry in ipairs(cat) do
            if entry.moduleKey == "HUD" and entry.hudTarget then
                local hay = table.concat({
                    entry.title or "",
                    entry.desc or "",
                    entry.keywords or "",
                }, " "):lower()
                local matchAll = true
                for _, w in ipairs(qWords) do
                    if not hay:find(w, 1, true) then
                        matchAll = false
                        break
                    end
                end
                if matchAll then
                    foundTargets[entry.hudTarget] = true
                end
            end
        end
        for _, req in ipairs({ "PREP", "prepBuffs", "TARGET", "FLARE", "CHAT", "TOAST" }) do
            assertTrue(foundTargets[req] == true, string.format("Search '%s' matches HUD target '%s'", q, req))
        end
    end
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
