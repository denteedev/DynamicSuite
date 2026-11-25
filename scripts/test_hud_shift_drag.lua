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
        ctrlDown = false,
        altDown = false,
        lmbDown = true,
        now = 100.0,
        cursorX = 500,
        cursorY = 400,
        enterHudCalls = {},
        printLog = {},
        eventFrames = {},
        hooks = {},
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
    env.IsControlKeyDown = function() return state.ctrlDown end
    env.IsAltKeyDown = function() return state.altDown end
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
                local uScale = (env.UIParent and env.UIParent._scale) or 1.0
                local relScale = (self._scale or 1.0) / uScale
                if relScale <= 0 then relScale = 1.0 end
                self._cx = ((rfx * uiW) / relScale) + ox + (0.5 - pfx) * (self._w or 100)
                self._cy = ((rfy * uiH) / relScale) + oy + (0.5 - pfy) * (self._h or 30)
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
            function tex:IsShown() return self._shown == true end
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
    env.ToggleGameMenu = function()
        if state.hooks["ToggleGameMenu"] then
            for _, fn in ipairs(state.hooks["ToggleGameMenu"]) do
                fn()
            end
        end
    end
    env.hooksecurefunc = function(tblOrName, nameOrFn, maybeFn)
        if type(tblOrName) == "string" and type(nameOrFn) == "function" then
            state.hooks[tblOrName] = state.hooks[tblOrName] or {}
            state.hooks[tblOrName][#state.hooks[tblOrName] + 1] = nameOrFn
        elseif type(tblOrName) == "table" and type(nameOrFn) == "string" and type(maybeFn) == "function" then
            local prev = tblOrName[nameOrFn]
            tblOrName[nameOrFn] = function(...)
                local res = nil
                if type(prev) == "function" then res = prev(...) end
                maybeFn(...)
                return res
            end
        end
    end

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

    -- Shift + Left-Drag off-screen clamps strictly 0px inside UIParent mid-drag and saves to both DBs
    state.shiftDown = true
    state.lmbDown = true
    state.cursorX, state.cursorY = 960, 940
    toast:FireScript("OnDragStart")
    assertTrue(not toast._moving, "Toast Shift-Drag uses cursor loop instead of StartMoving()")
    state.cursorX, state.cursorY = 4000, 2000 -- extreme off right & top edges
    toast:FireScript("OnUpdate", 0.016)
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

    -- Shift + Left-Drag on TargetBar button moves & clamps strictly inside UIParent via cursor loop
    state.shiftDown = true
    state.lmbDown = true
    state.cursorX, state.cursorY = 960, 540
    dm.targetBar.buttons[3]:FireScript("OnDragStart")
    assertTrue(dm.targetBar._dmDirectDragActive == true, "TargetBar direct Shift-Drag activated via button")
    assertTrue(not dm.targetBar._moving, "TargetBar direct Shift-Drag does not use StartMoving()")
    state.cursorX, state.cursorY = 5000, -5000
    dm.targetBar:FireScript("OnUpdate", 0.016)
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

-- ----------------------------------------------------------------------------
-- Test 8: Live mid-drag 0px clamping across all 4 edges at 60%, 100%, 150% scales
-- ----------------------------------------------------------------------------
RunTest("8. Live mid-drag 0px clamping at 60%, 100%, 150% scales & Chat insets", function()
    local function CheckVisualBoundsWithinUIParent(fr, extraIns, label)
        local relScale = fr:GetScale() / 1.0
        local fCx, fCy = fr:GetCenter()
        local visCx = fCx * relScale
        local visCy = fCy * relScale
        local halfW = fr:GetWidth() * relScale * 0.5
        local halfH = fr:GetHeight() * relScale * 0.5
        local ins = extraIns or {}
        local leftEdge = visCx - halfW - ((ins.left or 0) * relScale)
        local rightEdge = visCx + halfW + ((ins.right or 0) * relScale)
        local bottomEdge = visCy - halfH - ((ins.bottom or 0) * relScale)
        local topEdge = visCy + halfH + ((ins.top or 0) * relScale)
        assertTrue(leftEdge >= -1.0, label .. " leftEdge >= 0 (" .. tostring(leftEdge) .. ")")
        assertTrue(rightEdge <= 1921.0, label .. " rightEdge <= 1920 (" .. tostring(rightEdge) .. ")")
        assertTrue(bottomEdge >= -1.0, label .. " bottomEdge >= 0 (" .. tostring(bottomEdge) .. ")")
        assertTrue(topEdge <= 1081.0, label .. " topEdge <= 1080 (" .. tostring(topEdge) .. ")")
    end

    for _, sc in ipairs({ 0.60, 1.00, 1.50 }) do
        local env, state = BootFullSuiteEnv()
        local bar = env.CreateFrame("Frame", "TestScaledHud_" .. tostring(sc), env.UIParent)
        bar:SetSize(300, 44)
        bar:SetScale(sc)
        bar:ClearAllPoints()
        bar:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
        bar:Show()

        env.DynamicSuite.AttachDirectHudShiftDrag({
            frame = bar,
            targetKey = "PREP",
            enableSnap = false,
        })

        state.shiftDown = true
        state.lmbDown = true
        state.cursorX, state.cursorY = 960, 540
        bar:FireScript("OnDragStart")
        assertTrue(not bar._moving, "Scaled drag must not call StartMoving() at scale " .. tostring(sc))

        -- Push hard past Left+Bottom and Right+Top mid-drag on OnUpdate
        state.cursorX, state.cursorY = -2000, -2000
        bar:FireScript("OnUpdate", 0.016)
        CheckVisualBoundsWithinUIParent(bar, nil, "Scale " .. tostring(sc) .. " min-edge")

        state.cursorX, state.cursorY = 4000, 3000
        bar:FireScript("OnUpdate", 0.016)
        CheckVisualBoundsWithinUIParent(bar, nil, "Scale " .. tostring(sc) .. " max-edge")

        state.lmbDown = false
        bar:FireScript("OnUpdate", 0.016)
        assertTrue(not bar._dsDragging, "Drag stops when LMB released")
    end

    -- Chat Frame BOTTOMLEFT with extra insets { left=36, right=8, top=28, bottom=6 } at 120% scale
    local envC, stateC = BootFullSuiteEnv()
    local chatFr = envC.CreateFrame("Frame", "TestChatInsetsHud", envC.UIParent)
    chatFr:SetSize(430, 200)
    chatFr:SetScale(1.20)
    chatFr:ClearAllPoints()
    chatFr:SetPoint("BOTTOMLEFT", envC.UIParent, "BOTTOMLEFT", 100, 100)
    chatFr:Show()
    local chatInsets = { left = 36, right = 8, top = 28, bottom = 6 }
    envC.DynamicSuite.AttachDirectHudShiftDrag({
        frame = chatFr,
        targetKey = "CHAT",
        point = "BOTTOMLEFT",
        relPoint = "BOTTOMLEFT",
        extraInsets = chatInsets,
        enableSnap = false,
    })
    stateC.shiftDown = true
    stateC.lmbDown = true
    stateC.cursorX, stateC.cursorY = 300, 300
    chatFr:FireScript("OnDragStart")
    stateC.cursorX, stateC.cursorY = -900, -900
    chatFr:FireScript("OnUpdate", 0.016)
    CheckVisualBoundsWithinUIParent(chatFr, chatInsets, "Chat extraInsets min-edge")
    stateC.cursorX, stateC.cursorY = 4000, 4000
    chatFr:FireScript("OnUpdate", 0.016)
    CheckVisualBoundsWithinUIParent(chatFr, chatInsets, "Chat extraInsets max-edge")
    chatFr:FireScript("OnDragStop")
end)

-- ----------------------------------------------------------------------------
-- Test 9: Magnetic snapping & live guide overlay with Shift held + Alt bypass
-- ----------------------------------------------------------------------------
RunTest("9. Magnetic snapping & live guides while Shift held, plus Alt bypass", function()
    local env, state = BootFullSuiteEnv()
    local bar = env.CreateFrame("Frame", "TestSnapHud", env.UIParent)
    bar:SetSize(200, 40)
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", env.UIParent, "CENTER", 200, 200)
    bar:Show()

    local peer = env.CreateFrame("Frame", "TestPeerHud", env.UIParent)
    peer:SetSize(200, 40)
    peer:ClearAllPoints()
    peer:SetPoint("CENTER", env.UIParent, "CENTER", -300, -200)
    peer:Show()
    env.DynamicSuite.hudFrames = env.DynamicSuite.hudFrames or {}
    env.DynamicSuite.hudFrames["TEST_PEER"] = peer

    env.DynamicSuite.AttachDirectHudShiftDrag({
        frame = bar,
        targetKey = "PREP",
    })

    state.shiftDown = true
    state.altDown = false
    state.lmbDown = true
    state.cursorX, state.cursorY = 960 + 200, 540 + 200
    bar:FireScript("OnDragStart")

    -- Move within 7px of screen centre X (0) & Y (0) while Shift is held -> MUST snap to (0, 0) & show guides
    state.cursorX, state.cursorY = 960 + 7, 540 - 6
    bar:FireScript("OnUpdate", 0.016)
    local bCx, bCy = bar:GetCenter()
    assertEqual(bCx, 960, "Snaps exact to screen centre X even with Shift held")
    assertEqual(bCy, 540, "Snaps exact to screen centre Y even with Shift held")
    local ov = env.DynamicSuiteSnapGuideOverlay
    assertTrue(ov ~= nil and ov.vLine:IsShown() and ov.hLine:IsShown(), "Vertical & horizontal guide lines shown on centre snap")

    -- Move within 6px of peer's right edge (peer cx = 660, right = 760 -> dragged left=760 => cx=860) and peer's bottom (320 -> top=320 => cy=300)
    state.cursorX, state.cursorY = 860 + 5, 300 - 4
    bar:FireScript("OnUpdate", 0.016)
    bCx, bCy = bar:GetCenter()
    assertEqual(bCx, 860, "Snaps flush to peer HUD right edge (BAR_SNAP_THRESHOLD = 9)")
    assertEqual(bCy, 300, "Snaps flush below peer HUD bottom edge")
    assertTrue(ov.vLine:IsShown() and ov.hLine:IsShown(), "Guides shown for peer HUD snap")

    -- Move within 8px of left screen edge (left = 8 -> cx = 108) -> snaps to 0px left edge (cx = 100)
    state.cursorX, state.cursorY = 108, 700
    bar:FireScript("OnUpdate", 0.016)
    bCx, bCy = bar:GetCenter()
    assertEqual(bCx, 100, "Snaps flush to left screen edge (EDGE_SNAP_THRESHOLD = 11)")
    assertEqual(bCy, 700, "Free Y when outside edge threshold")
    assertTrue(ov.vLine:IsShown() and not ov.hLine:IsShown(), "Only vertical guide shown for left edge snap")

    -- Holding Alt disables magnetic snapping for fine-tuning and hides guides
    state.altDown = true
    state.cursorX, state.cursorY = 966, 545
    bar:FireScript("OnUpdate", 0.016)
    bCx, bCy = bar:GetCenter()
    assertEqual(bCx, 966, "Alt bypass disables magnetic X snap")
    assertEqual(bCy, 545, "Alt bypass disables magnetic Y snap")
    assertTrue(not ov.vLine:IsShown() and not ov.hLine:IsShown(), "Alt bypass hides alignment guide lines")

    state.altDown = false
    bar:FireScript("OnDragStop")
    assertTrue(not ov.vLine:IsShown() and not ov.hLine:IsShown(), "Mouse release hides alignment guide lines")
end)

-- ----------------------------------------------------------------------------
-- Test 10: Post-snap 0px clamping never lets a peer snap exceed UIParent bounds
-- ----------------------------------------------------------------------------
RunTest("10. Post-snap 0px clamping beats out-of-bounds peer snap", function()
    local env = BootFullSuiteEnv()
    -- Peer sits slightly off right edge / flush near right edge so peer.left + barWidth overshoots?
    -- Example: peer has right = 1916 (peer at [1716, 1916]); candidate dragged width=200 sits at candL = 1910 (candR = 2110!).
    -- Without post-snap clamp, snapping candL to peer.right (1916) would place candR = 2116 (off-screen!).
    -- With mandatory post-snap clamp, candCx clamps back to 1820 (candR = 1920) and clears non-edge guideX!
    local ox, oy, _, gx, gy = env.DynamicSuite.SnapAndClampPointOffsetToUIParent(
        200, 40, 1.0, 1920, 1080, 1.0,
        "CENTER", "CENTER", 945, 0,
        {
            enableSnap = true,
            directShiftDrag = true,
            peers = {
                { left = 1716, right = 1916, bottom = 520, top = 560, cx = 1816, cy = 540 },
            },
        }
    )
    assertEqual(ox, 860, "Right edge clamped strictly to 1920 (cx = 960 + 860 = 1820, right = 1920)")
    assertTrue(gx == nil or gx == 1920, "Non-edge peer guide suppressed when hard clamp overrides")
    assertEqual(oy, 0, "Centre Y snapped cleanly inside bounds")
    assertEqual(gy, 540, "Centre Y guide preserved")
end)

-- ----------------------------------------------------------------------------
-- Test 11: Standalone DynamicMarker live cursor-loop parity & Alt bypass
-- ----------------------------------------------------------------------------
RunTest("11. Standalone DynamicMarker cursor-loop drag, Shift snap, Alt bypass & /dm hud mode", function()
    local env, state = BootStandaloneMarkerEnv()
    local dm = env.DynamicMarker
    dm:InitTargetBar()
    dm:InitFlareBar()

    -- Place FlareBar at (X=-200, Y=-150) as a visible peer
    dm.flareBar:Show()
    dm:SaveHUDPosition(dm.flareBar, "FlareBar", true, "CENTER", "CENTER", -200, -150)
    dm.targetBar:Show()

    for _, sc in ipairs({ 0.60, 1.00, 1.50 }) do
        dm.db.targetBarScale = sc
        dm:ApplyHUDPosition(dm.targetBar, "TargetBar", 0)
        dm.targetBar:ClearAllPoints()
        dm.targetBar:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)

        state.shiftDown = true
        state.altDown = false
        state.lmbDown = true
        local tCx, tCy = dm.targetBar:GetCenter()
        local relScale = dm.targetBar:GetScale() / 1.0
        state.cursorX, state.cursorY = tCx * relScale, tCy * relScale
        dm.targetBar:FireScript("OnDragStart")
        assertTrue(not dm.targetBar._moving, "Standalone TargetBar does not call StartMoving at scale " .. tostring(sc))

        -- Clamp mid-drag past all 4 edges
        state.cursorX, state.cursorY = -3000, 3000
        dm.targetBar:FireScript("OnUpdate", 0.016)
        local lCx, lCy = dm.targetBar:GetCenter()
        local visHalfW = dm.targetBar:GetWidth() * relScale * 0.5
        local visHalfH = dm.targetBar:GetHeight() * relScale * 0.5
        assertTrue((lCx * relScale) - visHalfW >= -1.0, "Standalone left >= 0 at scale " .. tostring(sc))
        assertTrue((lCy * relScale) + visHalfH <= 1081.0, "Standalone top <= 1080 at scale " .. tostring(sc))

        dm.targetBar:FireScript("OnDragStop")
    end

    -- Verify Shift held keeps snapping enabled & Alt bypass disables it in Standalone DynamicMarker
    dm.db.targetBarScale = 1.0
    dm:SaveHUDPosition(dm.targetBar, "TargetBar", true, "CENTER", "CENTER", 0, 0)
    state.shiftDown = true
    state.altDown = false
    state.lmbDown = true
    state.cursorX, state.cursorY = 960, 540
    dm.targetBar:FireScript("OnDragStart")
    state.cursorX, state.cursorY = 960 - 6, 540 + 7 -- within 11px of screen center
    dm.targetBar:FireScript("OnUpdate", 0.016)
    local mCx, mCy = dm.targetBar:GetCenter()
    assertEqual(mCx, 960, "Standalone Shift-Drag snaps to screen centre X while Shift is held")
    assertEqual(mCy, 540, "Standalone Shift-Drag snaps to screen centre Y while Shift is held")
    local ov = env.DynamicSuiteSnapGuideOverlay
    assertTrue(ov ~= nil and ov.vLine:IsShown() and ov.hLine:IsShown(), "Standalone shows snap guide lines")

    -- Alt bypass disables snapping during direct Shift-Drag
    state.altDown = true
    state.cursorX, state.cursorY = 966, 545
    dm.targetBar:FireScript("OnUpdate", 0.016)
    mCx, mCy = dm.targetBar:GetCenter()
    assertEqual(mCx, 966, "Standalone Alt bypass frees X")
    assertEqual(mCy, 545, "Standalone Alt bypass frees Y")
    assertTrue(not ov.vLine:IsShown() and not ov.hLine:IsShown(), "Standalone Alt bypass hides guide lines")
    dm.targetBar:FireScript("OnDragStop")

    -- Verify /dm hud Edit Mode ClampHUDPositionToScreen (without directShiftDrag) still uses Shift to bypass
    state.shiftDown = true
    state.altDown = false
    local editX, editY = dm:ClampHUDPositionToScreen(dm.targetBar, "TargetBar", "CENTER", "CENTER", 6, 6, { enableSnap = true })
    assertEqual(editX, 6, "/dm hud Edit Mode still allows Shift to bypass X snap")
    assertEqual(editY, 6, "/dm hud Edit Mode still allows Shift to bypass Y snap")
end)

-- ----------------------------------------------------------------------------
-- Test 12: Guide & drag cleanup on Hide, Esc (ToggleGameMenu), and Combat
-- ----------------------------------------------------------------------------
RunTest("12. Guide and drag cleanup on Hide, Esc, and combat entry", function()
    -- Core controller: Hide, Esc, and Combat
    local env, state = BootFullSuiteEnv()
    local fr = env.CreateFrame("Button", "TestCleanupFrame", env.UIParent)
    fr:SetSize(200, 40)
    fr:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
    fr:Show()
    local ctrl = env.DynamicSuite.AttachDirectHudShiftDrag({
        frame = fr,
        targetKey = "PREP",
    })
    local ov = env.DynamicSuite.EnsureSnapGuideOverlay()

    -- Start drag & snap to centre so guides show, then Hide -> must abort & hide guides
    state.shiftDown = true
    state.altDown = false
    state.lmbDown = true
    state.cursorX, state.cursorY = 960, 540
    ctrl.BeginDrag()
    state.cursorX, state.cursorY = 963, 543
    fr:FireScript("OnUpdate", 0.016)
    assertTrue(ov.vLine:IsShown() and ov.hLine:IsShown(), "Guides shown mid-drag before Hide")
    fr:Hide()
    assertTrue(not ctrl.IsDragging(), "Hide() aborts drag")
    assertTrue(not ov.vLine:IsShown() and not ov.hLine:IsShown(), "Hide() dismisses alignment guides")

    -- Re-show, start drag -> Esc (ToggleGameMenu) must abort & hide guides
    fr:Show()
    state.cursorX, state.cursorY = 960, 540
    ctrl.BeginDrag()
    state.cursorX, state.cursorY = 962, 542
    fr:FireScript("OnUpdate", 0.016)
    assertTrue(ov.vLine:IsShown(), "Guide shown before Esc")
    env.ToggleGameMenu()
    assertTrue(not ctrl.IsDragging(), "Esc (ToggleGameMenu) aborts drag")
    assertTrue(not ov.vLine:IsShown() and not ov.hLine:IsShown(), "Esc dismisses alignment guides")

    -- Standalone DynamicMarker: Combat entry aborts drag & hides guides
    local envM, stateM = BootStandaloneMarkerEnv()
    local dm = envM.DynamicMarker
    dm:InitTargetBar()
    dm.targetBar:Show()
    dm.targetBar:SetPoint("CENTER", envM.UIParent, "CENTER", 0, 0)
    stateM.shiftDown = true
    stateM.altDown = false
    stateM.lmbDown = true
    stateM.cursorX, stateM.cursorY = 960, 540
    dm.targetBar:FireScript("OnDragStart")
    stateM.cursorX, stateM.cursorY = 963, 543
    dm.targetBar:FireScript("OnUpdate", 0.016)
    local ovM = envM.DynamicSuiteSnapGuideOverlay
    assertTrue(ovM ~= nil and ovM.vLine:IsShown(), "Standalone guide shown before combat")
    stateM.inCombat = true
    stateM.FireEvent("PLAYER_REGEN_DISABLED")
    assertTrue(not dm.targetBar._dmDirectDragActive, "Combat entry aborts standalone drag")
    assertTrue(not ovM.vLine:IsShown() and not ovM.hLine:IsShown(), "Combat entry dismisses standalone guides")
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
