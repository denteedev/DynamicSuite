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
        inPetBattle = false,
        inGroup = false,
        inRaid = false,
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
    env.IsInRaid = function() return state.inRaid end
    env.IsInGroup = function() return state.inGroup or state.inRaid end
    env.GetNumGroupMembers = function() return state.inRaid and 10 or (state.inGroup and 5 or 0) end
    env.GetNumSubgroupMembers = function() return state.inGroup and 4 or 0 end
    env.UnitIsGroupLeader = function() return false end
    env.UnitIsGroupAssistant = function() return false end
    env.InCombatLockdown = function() return state.inCombat end
    env.C_PetBattles = {
        IsInBattle = function() return state.inPetBattle end,
    }
    env.C_EventUtils = {
        IsEventValid = function() return true end,
    }
    env.RegisterStateDriver = function(fr, attr, cond)
        if type(fr) == "table" then
            fr._stateDrivers = fr._stateDrivers or {}
            fr._stateDrivers[attr] = cond
        end
    end
    env.UnregisterStateDriver = function(fr, attr)
        if type(fr) == "table" and fr._stateDrivers then
            fr._stateDrivers[attr] = nil
        end
    end
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
        GetAddOnMetadata = function() return "2.11.0" end,
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
                local relScale = (self._scale or 1.0)
                if relScale <= 0 then relScale = 1.0 end
                self._cx = ((rfx * uiW) / relScale) + ox + (0.5 - pfx) * (self._w or 100)
                self._cy = ((rfy * uiH) / relScale) + oy + (0.5 - pfy) * (self._h or 30)
            elseif type(relTo) == "table" and relTo.GetLeft and relTo.GetBottom then
                local p = tostring(pt or "CENTER"):upper()
                local rp = tostring(relPt or pt or "CENTER"):upper()
                local ox = tonumber(x) or 0
                local oy = tonumber(y) or 0
                if p == "TOPLEFT" and rp == "TOPLEFT" then
                    self._anchorL = relTo:GetLeft() + ox
                    self._anchorT = relTo:GetTop() + oy
                elseif p == "BOTTOMRIGHT" and rp == "BOTTOMRIGHT" then
                    self._anchorR = relTo:GetRight() + ox
                    self._anchorB = relTo:GetBottom() + oy
                end
                if self._anchorL and self._anchorR and self._anchorT and self._anchorB then
                    self._w = math.max(1, self._anchorR - self._anchorL)
                    self._h = math.max(1, self._anchorT - self._anchorB)
                    self._cx = (self._anchorL + self._anchorR) * 0.5
                    self._cy = (self._anchorB + self._anchorT) * 0.5
                end
            end
        end
        function f:SetAllPoints() end
        function f:GetPoint(idx)
            local p = self._points[idx or 1]
            if p then return p[1], p[2], p[3], p[4], p[5] end
            return "CENTER", env.UIParent, "CENTER", 0, 0
        end
        function f:ClearAllPoints()
            self._points = {}
            self._anchorL, self._anchorR, self._anchorT, self._anchorB = nil, nil, nil, nil
        end
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
        function f:GetEffectiveScale()
            if self == env.UIParent then return self._scale end
            local pEff = (self._parent and self._parent.GetEffectiveScale and self._parent:GetEffectiveScale())
                or (env.UIParent and env.UIParent._scale) or 1.0
            return pEff * (self._scale or 1.0)
        end
        function f:SetAlpha(a) self._alpha = a or 1.0 end
        function f:GetAlpha() return self._alpha end
        function f:SetFrameStrata(s) self._strata = s end
        function f:GetFrameStrata() return self._strata or "MEDIUM" end
        function f:GetName() return self._name end
        function f:GetNumPoints() return #self._points end
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
            function tex:SetTexture(t) self._tex = t end
            function tex:GetTexture() return self._tex end
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
            function tex:SetShown(b) self._shown = (b == true) end
            function tex:IsShown() return self._shown == true end
            function tex:SetAlpha(a) self._alpha = a or 1 end
            function tex:GetAlpha() return self._alpha or 1 end
            function tex:SetDrawLayer() end
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
            function fs:SetAlpha(a) self._alpha = a or 1 end
            function fs:GetAlpha() return self._alpha or 1 end
            function fs:SetJustifyH() end
            function fs:SetJustifyV() end
            function fs:SetWordWrap() end
            function fs:SetSpacing() end
            function fs:SetNonSpaceWrap() end
            function fs:SetMaxLines() end
            function fs:SetText(t) self._text = tostring(t or "") end
            function fs:GetText() return self._text end
            function fs:GetStringWidth()
                local plain = self._text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "XX")
                return #plain * 6
            end
            function fs:GetUnboundedStringWidth() return self:GetStringWidth() end
            function fs:GetStringHeight() return 14 end
            function fs:Show() self._shown = true end
            function fs:Hide() self._shown = false end
            function fs:SetShown(b) self._shown = (b == true) end
            function fs:IsShown() return self._shown == true end
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

-- ----------------------------------------------------------------------------
-- Test 13: Zero-jump Shift-Drag at bottom/top/left/right screen edges
-- ----------------------------------------------------------------------------
RunTest("13. Zero-jump Shift-Drag from bottom, top, left, and right screen edges", function()
    for _, uScale in ipairs({ 1.0, 0.7111 }) do
        for _, bScale in ipairs({ 0.60, 1.00, 1.50 }) do
            local env, state = BootStandaloneMarkerEnv()
            env.UIParent:SetScale(uScale)
            local dm = env.DynamicMarker
            dm:InitTargetBar()
            dm:InitFlareBar()

            for _, barSpec in ipairs({
                { key = "TargetBar", bar = dm.targetBar, oriKey = "targetBarOrientation", scaleKey = "targetBarScale" },
                { key = "FlareBar",  bar = dm.flareBar,  oriKey = "flareBarOrientation",  scaleKey = "flareBarScale" },
            }) do
                local bar = barSpec.bar
                dm.db[barSpec.scaleKey] = bScale
                dm.db[barSpec.oriKey] = "HORIZONTAL"
                dm:SyncBarScaleAndSizeToDB(bar, barSpec.key)

                local halfW = (bar:GetWidth() * bScale) * 0.5
                local halfH = (bar:GetHeight() * bScale) * 0.5
                local edgeCases = {
                    { name = "BOTTOM", x = 0,               y = -(540 - halfH) },
                    { name = "TOP",    x = 0,               y = (540 - halfH) },
                    { name = "LEFT",   x = -(960 - halfW),  y = 0 },
                    { name = "RIGHT",  x = (960 - halfW),   y = 0 },
                    { name = "BTM_L",  x = -(960 - halfW),  y = -(540 - halfH) },
                }

                for _, ec in ipairs(edgeCases) do
                    local cx0 = math.floor(ec.x + 0.5)
                    local cy0 = math.floor(ec.y + 0.5)
                    dm:SaveHUDPosition(bar, barSpec.key, true, "CENTER", "CENTER", cx0, cy0)
                    dm:ApplyHUDPosition(bar, barSpec.key, 0)
                    bar:Show()

                    local startCx, startCy = bar:GetCenter()
                    assertTrue(startCx ~= nil and startCy ~= nil, "GetCenter returns both X and Y")
                    local startVisCx = startCx * bScale
                    local startVisCy = startCy * bScale

                    -- Cursor clicks directly on the bar's visual centre (in WoW GetCursorPosition() raw coords)
                    state.shiftDown = true
                    state.altDown = false
                    state.lmbDown = true
                    state.cursorX = startVisCx * uScale
                    state.cursorY = startVisCy * uScale

                    bar:FireScript("OnDragStart")
                    assertTrue(bar._dmDirectDragActive == true, barSpec.key .. " Shift-Drag started at " .. ec.name)

                    -- First OnUpdate tick WITHOUT moving cursor must NOT jump to vertical center (Y = 0)
                    bar:FireScript("OnUpdate", 0.016)
                    local tickCx, tickCy = bar:GetCenter()
                    local tickVisCx = tickCx * bScale
                    local tickVisCy = tickCy * bScale
                    local dx = math.abs(tickVisCx - startVisCx)
                    local dy = math.abs(tickVisCy - startVisCy)
                    assertTrue(dx <= 1.0, string.format("%s %s uScale=%.2f bScale=%.2f zero X jump (dx=%.2f)", barSpec.key, ec.name, uScale, bScale, dx))
                    assertTrue(dy <= 1.0, string.format("%s %s uScale=%.2f bScale=%.2f zero Y jump (dy=%.2f, start=%.1f, tick=%.1f)", barSpec.key, ec.name, uScale, bScale, dy, startVisCy, tickVisCy))

                    -- Nudging outward stays strictly 0px clamped; Alt bypass stays unjumped
                    state.cursorX = (startVisCx * uScale) - (200 * uScale)
                    state.cursorY = (startVisCy * uScale) - (200 * uScale)
                    bar:FireScript("OnUpdate", 0.016)
                    local outCx, outCy = bar:GetCenter()
                    assertTrue((outCx * bScale) - halfW >= -1.0, "Outward drag keeps left >= 0")
                    assertTrue((outCy * bScale) - halfH >= -1.0, "Outward drag keeps bottom >= 0")

                    bar:FireScript("OnDragStop")
                end
            end
        end
    end

    -- Also confirm Shared Alert Toast parked flush at bottom edge starts with 0px jump
    local envS, stateS = BootFullSuiteEnv()
    local toast = envS.DynamicSuite.EnsureSharedToastFrame("UnitTestEdgeToast", { toastKind = "ACTION" })
    envS.DynamicSuite.SaveSharedToastPosition("TOP", "TOP", -120, -1006, toast)
    toast:Show()
    local tCx0, tCy0 = toast:GetCenter()
    stateS.shiftDown = true
    stateS.lmbDown = true
    stateS.cursorX, stateS.cursorY = tCx0, tCy0
    toast:FireScript("OnDragStart")
    toast:FireScript("OnUpdate", 0.016)
    local tCx1, tCy1 = toast:GetCenter()
    assertTrue(math.abs(tCx1 - tCx0) <= 1.0 and math.abs(tCy1 - tCy0) <= 1.0, "Shared Toast bottom edge starts with zero jump")
    toast:FireScript("OnDragStop")
end)

-- ----------------------------------------------------------------------------
-- Test 14: Pet Battle auto-hide across DynamicMarker, Shared Toast & Chat
-- ----------------------------------------------------------------------------
RunTest("14. Pet Battle auto-hide on DynamicMarker, Shared Alert Toast & Chat preserved", function()
    -- Standalone DynamicMarker: ALWAYS + GROUP + OFF + active drag/Edit Mode abort
    local envM, stateM = BootStandaloneMarkerEnv()
    local dm = envM.DynamicMarker
    dm:InitTargetBar()
    dm:InitFlareBar()
    dm.db.targetBarVisibility = "ALWAYS"
    dm.db.flareBarVisibility = "GROUP"
    stateM.inGroup = true
    dm:UpdateTargetBarVisibility()
    dm:UpdateFlareBarVisibility()
    assertTrue(dm.targetBar:IsShown(), "TargetBar visible when ALWAYS before Pet Battle")
    assertTrue(dm.flareBar:IsShown(), "FlareBar visible when GROUP & inGroup before Pet Battle")
    assertTrue(dm:GetGroupVisibilityStateDriver():find("[petbattle] hide;", 1, true) ~= nil, "Group state driver includes [petbattle] hide")

    -- Start a Shift-Drag on TargetBar -> Pet Battle start aborts drag, hides guides & bars
    stateM.shiftDown = true
    stateM.lmbDown = true
    stateM.cursorX, stateM.cursorY = 960, 400
    dm.targetBar:FireScript("OnDragStart")
    assertTrue(dm.targetBar._dmDirectDragActive == true, "TargetBar Shift-Drag active before Pet Battle")

    stateM.inPetBattle = true
    stateM.FireEvent("PET_BATTLE_OPENING_START")
    assertTrue(not dm.targetBar._dmDirectDragActive, "Pet Battle aborts active TargetBar Shift-Drag")
    assertTrue(not dm.targetBar:IsShown(), "Standalone TargetBar hides during Pet Battle")
    assertTrue(not dm.flareBar:IsShown(), "Standalone FlareBar hides during Pet Battle")

    -- Simulating mid-battle /reload / RefreshTargetBar / RefreshFlareBar keeps both hidden
    dm:RefreshTargetBar()
    dm:RefreshFlareBar()
    assertTrue(not dm.targetBar:IsShown(), "TargetBar stays hidden on mid-battle RefreshTargetBar")
    assertTrue(not dm.flareBar:IsShown(), "FlareBar stays hidden on mid-battle RefreshFlareBar")
    assertEqual(dm:ShouldShowBar("ALWAYS", dm.targetBar), false, "ShouldShowBar returns false during Pet Battle")

    -- Ending Pet Battle restores exact prior visibility (ALWAYS + GROUP-in-group)
    stateM.inPetBattle = false
    stateM.FireEvent("PET_BATTLE_OVER")
    assertTrue(dm.targetBar:IsShown(), "TargetBar restores ALWAYS after PET_BATTLE_OVER")
    assertTrue(dm.flareBar:IsShown(), "FlareBar restores GROUP (in group) after PET_BATTLE_OVER")

    -- Verify OFF mode stays hidden after Pet Battle ends
    dm.db.targetBarVisibility = "HIDDEN"
    dm:UpdateTargetBarVisibility()
    assertTrue(not dm.targetBar:IsShown(), "TargetBar stays hidden when configured OFF")
    stateM.inPetBattle = true
    stateM.FireEvent("PET_BATTLE_OPENING_START")
    stateM.inPetBattle = false
    stateM.FireEvent("PET_BATTLE_CLOSE")
    assertTrue(not dm.targetBar:IsShown(), "TargetBar stays OFF after PET_BATTLE_CLOSE")

    -- Full Suite: Shared Alert Toast hides + suppresses during Pet Battle; ChatFrame1 stays visible
    local envS, stateS = BootFullSuiteEnv()
    assertEqual(envS.DynamicSuite.IsInPetBattle(), false, "Core IsInPetBattle false initially")
    local chatFr = envS.CreateFrame("Frame", "ChatFrame1", envS.UIParent)
    chatFr:Show()
    local toast = envS.DynamicSuite.EnsureSharedToastFrame("DynamicLoadToastFrame", { toastKind = "ACTION" })
    assertTrue(envS.DynamicSuite.ShowSharedToast(toast, { title = "Ready", body = "Check" }), "Shared Toast shows out of Pet Battle")
    assertTrue(toast:IsShown(), "Shared Toast shown before Pet Battle")

    stateS.inPetBattle = true
    assertEqual(envS.DynamicSuite.IsInPetBattle(), true, "Core IsInPetBattle reflects C_PetBattles.IsInBattle()")
    stateS.FireEvent("PET_BATTLE_OPENING_START")
    assertTrue(not toast:IsShown(), "Shared Toast hides on PET_BATTLE_OPENING_START")
    assertEqual(envS.DynamicSuite.ShowSharedToast(toast, { title = "Suppressed", body = "Battle" }), false, "New Shared Toasts suppressed during Pet Battle")
    assertTrue(not toast:IsShown(), "Shared Toast stays hidden mid-battle")
    assertTrue(chatFr:IsShown(), "ChatFrame1 remains visible during Pet Battle")

    stateS.inPetBattle = false
    stateS.FireEvent("PET_BATTLE_OVER")
    assertTrue(envS.DynamicSuite.ShowSharedToast(toast, { title = "Restored", body = "Done" }), "Shared Toasts work again after PET_BATTLE_OVER")
    assertTrue(toast:IsShown(), "Shared Toast visible again post-battle")
end)

-- ----------------------------------------------------------------------------
-- Test 15: Pet Battle auto-hide on real DynamicPrep (Top Info Bar + Clickable
-- Raid Buffs) & DynamicLoad (Alert Toast)
-- ----------------------------------------------------------------------------
RunTest("15. Pet Battle auto-hide on real DynamicPrep HUDs & DynamicLoad Alert Toast", function()
    local env, state = CreateEnv()
    -- Additional WoW API stubs needed by DynamicLoad.lua & DynamicPrep.lua
    env.strtrim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
    env.strsplit = function(sep, str)
        local res = {}
        for part in string.gmatch(tostring(str or ""), "([^" .. sep .. "]+)") do res[#res + 1] = part end
        return unpack(res)
    end
    env.bit = {
        band = function(a, b)
            local res, bitval = 0, 1
            while a > 0 and b > 0 do
                if (a % 2 == 1) and (b % 2 == 1) then res = res + bitval end
                a = math.floor(a / 2); b = math.floor(b / 2); bitval = bitval * 2
            end
            return res
        end,
    }
    env.time = os.time
    env.date = os.date
    env.GetLocale = function() return "enUS" end
    env.GetAddOnMemoryUsage = function() return 0 end
    env.UpdateAddOnMemoryUsage = function() end
    env.GetCVar = function() return "1" end
    env.GetCVarBool = function() return false end
    env.SetCVar = function() end
    env.GetSpecialization = function() return 1 end
    env.GetSpecializationInfo = function() return 62, "Arcane", "", 135932, "DAMAGER" end
    env.C_SpecializationInfo = { GetSpecialization = env.GetSpecialization, GetSpecializationInfo = env.GetSpecializationInfo }
    env.GetLootSpecialization = function() return 0 end
    env.GetFramerate = function() return 120 end
    env.GetNetStats = function() return 0, 0, 20, 25 end
    env.GetInventoryItemDurability = function() return 100, 100 end
    env.GetInventoryItemLink = function() return nil end
    env.GetInventoryItemID = function() return nil end
    env.IsInInstance = function() return false, "none" end
    env.UnitIsDeadOrGhost = function() return false end
    env.UnitIsGhost = function() return false end
    env.UnitLevel = function() return 80 end
    env.UnitIsConnected = function() return true end
    env.UnitExists = function(u) return u == "player" end
    env.C_UnitAuras = { GetAuraDataByIndex = function() return nil end }
    env.UnitAffectedByControl = nil
    env.C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemID = function() return nil end }
    env.C_Spell = { GetSpellName = function() return "Arcane Intellect" end, IsSpellUsable = function() return true, false end }
    env.C_Item = { GetItemCount = function() return 0 end, GetItemInfo = function() return nil end }
    env.C_Texture = { GetAtlasInfo = function() return nil end }
    env.C_Timer.NewTicker = function(_, fn) return { Cancel = function() end, fn = fn } end
    env.GetSpellInfo = function() return "Arcane Intellect", nil, 135932 end
    env.GetItemCount = function() return 0 end
    env.IsSpellKnown = function() return true end
    env.C_SpellBook = { IsSpellKnown = function() return true end }

    local sharedTbl = {}
    LoadChunkIntoEnv(CORE_PATH, env, "DynamicSuite", sharedTbl)
    env.C_AddOns.IsAddOnLoaded = function(name)
        return name == "DynamicSuite" or name == "DynamicLoad" or name == "DynamicPrep"
    end
    local dlTbl = LoadChunkIntoEnv("DynamicSuite/Modules/DynamicLoad.lua", env, "DynamicSuite", sharedTbl)
    LoadChunkIntoEnv("DynamicSuite/Modules/DynamicPrep.lua", env, "DynamicSuite", sharedTbl)

    state.FireEvent("ADDON_LOADED", "DynamicSuite")
    state.FireEvent("ADDON_LOADED", "DynamicLoad")
    state.FireEvent("ADDON_LOADED", "DynamicPrep")

    -- 1. Verify DynamicLoad Alert Toast auto-hides & suppresses in Pet Battles
    local showToastFn = (type(dlTbl) == "table" and dlTbl.ShowToast) or sharedTbl.ShowToast
    assertTrue(type(showToastFn) == "function", "DynamicLoad ShowToast exposed")
    showToastFn("outdoor", 3, true)
    assertTrue(env.DynamicLoadToastFrame ~= nil and env.DynamicLoadToastFrame:IsShown(), "DynamicLoad toast shown out of Pet Battle")

    -- 2. Verify DynamicPrep Top Info Bar & Clickable Raid Buffs show out of Pet Battle
    local dp = env.DynamicPrep
    assertTrue(dp ~= nil, "DynamicPrep initialized")
    dp.db = dp.db or {}
    dp.db.displayMode = "ALWAYS"
    dp.db.raidBuffs = dp.db.raidBuffs or { enabled = true }
    dp.db.raidBuffs.enabled = true
    dp:RefreshBar()
    dp:RefreshClickableBuffs(true)
    assertTrue(dp.prepBarFrame ~= nil and dp.prepBarFrame:IsShown(), "Prep Top Info Bar visible before Pet Battle")
    assertTrue(dp.clickableBuffBar ~= nil and dp.clickableBuffBar:IsShown(), "Clickable Raid Buffs visible before Pet Battle")
    assertEqual(dp:ShouldShowPrepBar(), true, "ShouldShowPrepBar true before Pet Battle")

    -- Enter Pet Battle -> all 3 hide & new DynamicLoad toasts suppressed
    state.inPetBattle = true
    state.FireEvent("PET_BATTLE_OPENING_START")
    assertTrue(not env.DynamicLoadToastFrame:IsShown(), "DynamicLoad toast hides on PET_BATTLE_OPENING_START")
    showToastFn("outdoor", 2, true)
    assertTrue(not env.DynamicLoadToastFrame:IsShown(), "DynamicLoad toast stays suppressed during Pet Battle")
    assertTrue(not dp.prepBarFrame:IsShown(), "Prep Top Info Bar hides during Pet Battle")
    assertTrue(not dp.clickableBuffBar:IsShown(), "Clickable Raid Buffs hides during Pet Battle")
    assertEqual(dp:ShouldShowPrepBar(), false, "ShouldShowPrepBar false during Pet Battle")

    -- Mid-battle refresh (simulating /reload while in Pet Battle) keeps them hidden
    dp:RefreshBar()
    dp:RefreshClickableBuffs(true)
    assertTrue(not dp.prepBarFrame:IsShown(), "Prep Top Info Bar stays hidden on mid-battle RefreshBar")
    assertTrue(not dp.clickableBuffBar:IsShown(), "Clickable Raid Buffs stays hidden on mid-battle RefreshClickableBuffs")

    -- Exit Pet Battle -> bars restore cleanly & toasts work again
    state.inPetBattle = false
    state.FireEvent("PET_BATTLE_OVER")
    assertTrue(dp.prepBarFrame:IsShown(), "Prep Top Info Bar restores after PET_BATTLE_OVER")
    assertTrue(dp.clickableBuffBar:IsShown(), "Clickable Raid Buffs restores after PET_BATTLE_OVER")
    showToastFn("outdoor", 3, true)
    assertTrue(env.DynamicLoadToastFrame:IsShown(), "DynamicLoad toast shows again after PET_BATTLE_OVER")
end)

-- ----------------------------------------------------------------------------
-- Test 16: Direct Shift + Left-Drag persistence across simulated /reload and
-- post-reload clamping for ALL 6 canonical HUDs (Global + Character scope,
-- plus Standalone DynamicMarker parity & trailing OnDragStop guard)
-- ----------------------------------------------------------------------------
RunTest("16. Shift+Left-Drag reload persistence across all 6 canonical HUDs (Suite + Standalone)", function()
    local function DeepCopy(src)
        if type(src) ~= "table" then return src end
        local out = {}
        for k, v in pairs(src) do
            out[k] = DeepCopy(v)
        end
        return out
    end

    local function AugmentEnvForAllModules(env)
        env.strtrim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
        env.strsplit = function(sep, str)
            local res = {}
            for part in string.gmatch(tostring(str or ""), "([^" .. sep .. "]+)") do res[#res + 1] = part end
            return unpack(res)
        end
        env.bit = {
            band = function(a, b)
                local res, bitval = 0, 1
                while a > 0 and b > 0 do
                    if (a % 2 == 1) and (b % 2 == 1) then res = res + bitval end
                    a = math.floor(a / 2); b = math.floor(b / 2); bitval = bitval * 2
                end
                return res
            end,
        }
        env.time = os.time
        env.date = os.date
        env.GetLocale = function() return "enUS" end
        env.GetAddOnMemoryUsage = function() return 0 end
        env.UpdateAddOnMemoryUsage = function() end
        env.GetCVar = function() return "1" end
        env.GetCVarBool = function() return false end
        env.SetCVar = function() end
        env.GetSpecialization = function() return 1 end
        env.GetSpecializationInfo = function() return 62, "Arcane", "", 135932, "DAMAGER" end
        env.C_SpecializationInfo = { GetSpecialization = env.GetSpecialization, GetSpecializationInfo = env.GetSpecializationInfo }
        env.GetLootSpecialization = function() return 0 end
        env.GetFramerate = function() return 120 end
        env.GetNetStats = function() return 0, 0, 20, 25 end
        env.GetInventoryItemDurability = function() return 100, 100 end
        env.GetInventoryItemLink = function() return nil end
        env.GetInventoryItemID = function() return nil end
        env.IsInInstance = function() return false, "none" end
        env.UnitIsDeadOrGhost = function() return false end
        env.UnitIsGhost = function() return false end
        env.UnitLevel = function() return 80 end
        env.UnitIsConnected = function() return true end
        env.UnitExists = function(u) return u == "player" end
        env.C_UnitAuras = { GetAuraDataByIndex = function() return nil end }
        env.C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemID = function() return nil end }
        env.C_Spell = { GetSpellName = function() return "Arcane Intellect" end, IsSpellUsable = function() return true, false end }
        env.C_Item = { GetItemCount = function() return 0 end, GetItemInfo = function() return nil end }
        env.C_Texture = { GetAtlasInfo = function() return nil end }
        env.C_Timer.NewTicker = function(_, fn) return { Cancel = function() end, fn = fn } end
        env.GetSpellInfo = function() return "Arcane Intellect", nil, 135932 end
        env.GetItemCount = function() return 0 end
        env.IsSpellKnown = function() return true end
        env.C_SpellBook = { IsSpellKnown = function() return true end }
        env.NUM_CHAT_WINDOWS = 1
        env.ChatTypeInfo = {}
        local cf1 = env.CreateFrame("Frame", "ChatFrame1", env.UIParent)
        cf1:SetSize(560, 280)
        cf1:ClearAllPoints()
        cf1:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 60, 40)
        cf1:Show()
        cf1.SetUserPlaced = function() end
        cf1.IsUserPlaced = function() return true end
        local eb1 = env.CreateFrame("EditBox", "ChatFrame1EditBox", env.UIParent)
        eb1:SetSize(560, 28)
        eb1:Show()
        cf1.editBox = eb1
        local tab1 = env.CreateFrame("Button", "ChatFrame1Tab", env.UIParent)
        tab1:SetSize(70, 22)
        tab1:Show()
        env.GeneralDockManager = env.CreateFrame("Frame", "GeneralDockManager", env.UIParent)
        env.GeneralDockManager.selected = cf1
        env.C_AddOns.IsAddOnLoaded = function(name)
            return name == "DynamicSuite" or name == "DynamicLoad" or name == "DynamicPrep"
                or name == "DynamicMarker" or name == "DynamicChat"
        end
    end

    local function BootAll6Modules(savedVars, scopeMode)
        local env, state = CreateEnv()
        AugmentEnvForAllModules(env)
        if savedVars then
            if savedVars.DynamicSuiteDB then env.DynamicSuiteDB = DeepCopy(savedVars.DynamicSuiteDB) end
            if savedVars.DynamicLoadDB  then env.DynamicLoadDB  = DeepCopy(savedVars.DynamicLoadDB)  end
            if savedVars.DynamicPrepDB  then env.DynamicPrepDB  = DeepCopy(savedVars.DynamicPrepDB)  end
            if savedVars.DynamicMarkerDB then env.DynamicMarkerDB = DeepCopy(savedVars.DynamicMarkerDB) end
            if savedVars.DynamicChatDB  then env.DynamicChatDB  = DeepCopy(savedVars.DynamicChatDB)  end
        end
        if scopeMode == "CHARACTER" then
            env.DynamicLoadDB = env.DynamicLoadDB or {}
            env.DynamicLoadDB.charScopeMode = env.DynamicLoadDB.charScopeMode or {}
            env.DynamicLoadDB.charScopeMode["Testchar-Frostmourne"] = "CHARACTER"
            env.DynamicLoadDB.charData = env.DynamicLoadDB.charData or {}
            env.DynamicLoadDB.charData["Testchar-Frostmourne"] = env.DynamicLoadDB.charData["Testchar-Frostmourne"] or {}
            local cd = env.DynamicLoadDB.charData["Testchar-Frostmourne"]
            cd.theme = cd.theme or {}
        end

        local sharedTbl = {}
        LoadChunkIntoEnv(CORE_PATH, env, "DynamicSuite", sharedTbl)
        env.DynamicSuite._isHubLoaded = true
        local dlTbl = LoadChunkIntoEnv("DynamicSuite/Modules/DynamicLoad.lua", env, "DynamicSuite", sharedTbl)
        LoadChunkIntoEnv("DynamicSuite/Modules/DynamicPrep.lua", env, "DynamicSuite", sharedTbl)
        LoadChunkIntoEnv(MARKER_PATH, env, "DynamicSuite", sharedTbl)
        LoadChunkIntoEnv("DynamicSuite/Modules/DynamicChat.lua", env, "DynamicSuite", sharedTbl)

        state.FireEvent("ADDON_LOADED", "DynamicSuite")
        state.FireEvent("ADDON_LOADED", "DynamicLoad")
        state.FireEvent("ADDON_LOADED", "DynamicPrep")
        state.FireEvent("ADDON_LOADED", "DynamicMarker")
        state.FireEvent("ADDON_LOADED", "DynamicChat")

        env.DynamicMarker:InitDB()
        env.DynamicMarker:InitTargetBar()
        env.DynamicMarker:InitFlareBar()
        env.DynamicPrep.db.displayMode = "ALWAYS"
        env.DynamicPrep.db.raidBuffs = env.DynamicPrep.db.raidBuffs or {}
        env.DynamicPrep.db.raidBuffs.enabled = true
        env.DynamicPrep:RefreshBar()
        env.DynamicPrep:RefreshClickableBuffs(true)
        env.DynamicChat:ApplySavedChatFramePosition()
        return env, state, sharedTbl, dlTbl
    end

    for _, scopeMode in ipairs({ "GLOBAL", "CHARACTER" }) do
        local env1, state1, shared1, dl1 = BootAll6Modules(nil, scopeMode)
        local activeScope1 = env1.DynamicSuite.GetSuiteGlobal()
        if scopeMode == "CHARACTER" then
            assertTrue(activeScope1 ~= env1.DynamicSuiteDB.global, "CHARACTER scope uses distinct activeScope table")
        end

        -- 1. Top Info Bar (PREP): direct Shift + Left-Drag to new coords
        local prepBar = env1.DynamicPrep.prepBarFrame
        prepBar:Show()
        local pCx0, pCy0 = prepBar:GetCenter()
        state1.shiftDown = true; state1.altDown = true; state1.lmbDown = true
        state1.cursorX, state1.cursorY = pCx0, pCy0
        prepBar:FireScript("OnDragStart")
        assertTrue(prepBar._dpDirectDragActive == true, scopeMode .. ": PREP direct drag active")
        state1.cursorX, state1.cursorY = pCx0 + 235, pCy0 - 175
        prepBar:FireScript("OnUpdate", 0.016)
        state1.lmbDown = false
        prepBar:FireScript("OnUpdate", 0.016)
        prepBar:FireScript("OnDragStop")
        local prepSavedX, prepSavedY = env1.DynamicPrepDB.barX, env1.DynamicPrepDB.barY
        assertTrue(math.abs(prepSavedX - 235) <= 2, scopeMode .. ": PREP barX updated (" .. tostring(prepSavedX) .. ")")
        assertTrue(math.abs(prepSavedY - (-183)) <= 4, scopeMode .. ": PREP barY updated (" .. tostring(prepSavedY) .. ")")
        assertEqual(env1.DynamicSuiteDB.global.hudPositions["PREP"].x, prepSavedX, scopeMode .. ": PREP mirrored to DynamicSuiteDB.global.hudPositions.PREP.x")
        assertEqual(env1.DynamicSuiteDB.global.hudPositions["PREP"].y, prepSavedY, scopeMode .. ": PREP mirrored to DynamicSuiteDB.global.hudPositions.PREP.y")
        assertEqual(activeScope1.hudPositions["PREP"].x, prepSavedX, scopeMode .. ": PREP mirrored to activeScope.hudPositions.PREP.x")
        assertEqual(activeScope1.hudPositions["PREP"].y, prepSavedY, scopeMode .. ": PREP mirrored to activeScope.hudPositions.PREP.y")

        -- 2. Clickable Raid Buffs HUD (prepBuffs): direct Shift + Left-Drag at 1.25 scale
        local buffBar = env1.DynamicPrep.clickableBuffBar
        env1.DynamicPrep.db.raidBuffs.hudScale = 1.25
        env1.DynamicPrep:RefreshClickableBuffs(true)
        buffBar:Show()
        local bScale = buffBar:GetScale()
        local bCx0, bCy0 = buffBar:GetCenter()
        state1.shiftDown = true; state1.altDown = true; state1.lmbDown = true
        state1.cursorX, state1.cursorY = bCx0 * bScale, bCy0 * bScale
        buffBar:FireScript("OnDragStart")
        assertTrue(buffBar._dpBuffDirectDragActive == true, scopeMode .. ": prepBuffs direct drag active")
        state1.cursorX, state1.cursorY = (bCx0 * bScale) - 260, (bCy0 * bScale) - 220
        buffBar:FireScript("OnUpdate", 0.016)
        state1.lmbDown = false
        buffBar:FireScript("OnUpdate", 0.016)
        buffBar:FireScript("OnDragStop")
        local buffSavedX, buffSavedY = env1.DynamicPrepDB.raidBuffs.x, env1.DynamicPrepDB.raidBuffs.y
        assertTrue(buffSavedX < -150 and buffSavedY < 0, scopeMode .. ": prepBuffs raidBuffs.x/y moved (" .. tostring(buffSavedX) .. "," .. tostring(buffSavedY) .. ")")
        assertEqual(env1.DynamicSuiteDB.global.hudPositions["prepBuffs"].x, buffSavedX, scopeMode .. ": prepBuffs mirrored to DynamicSuiteDB.global.hudPositions")
        assertEqual(activeScope1.hudPositions["prepBuffs"].x, buffSavedX, scopeMode .. ": prepBuffs mirrored to activeScope.hudPositions")

        -- 3. Focus Icons Bar (TARGET): direct Shift + Left-Drag near centre with Alt bypass + trailing OnDragStop
        local tBar = env1.DynamicMarker.targetBar
        tBar:Show()
        local tCx0, tCy0 = tBar:GetCenter()
        state1.shiftDown = true; state1.altDown = true; state1.lmbDown = true
        state1.cursorX, state1.cursorY = tCx0, tCy0
        tBar:FireScript("OnDragStart")
        assertTrue(tBar._dmDirectDragActive == true, scopeMode .. ": TARGET direct drag active")
        -- Move to X=6, Y=5 (within snap threshold!) with Alt held -> trailing OnDragStop MUST NOT fall through & snap back to (0,0)!
        state1.cursorX, state1.cursorY = 960 + 6, 540 + 5
        tBar:FireScript("OnUpdate", 0.016)
        state1.lmbDown = false
        state1.altDown = false -- user releases Alt right before trailing OnDragStop fires
        tBar:FireScript("OnUpdate", 0.016)
        tBar:FireScript("OnDragStop")
        assertEqual(env1.DynamicMarkerDB.targetBarX, 6, scopeMode .. ": TARGET X preserved (trailing OnDragStop did not snap/revert)")
        assertEqual(env1.DynamicMarkerDB.targetBarY, 5, scopeMode .. ": TARGET Y preserved (trailing OnDragStop did not snap/revert)")
        assertEqual(env1.DynamicSuiteDB.global.hudPositions["TARGET"].x, 6, scopeMode .. ": TARGET mirrored to DynamicSuiteDB.global.hudPositions.TARGET.x")
        assertEqual(activeScope1.hudPositions["TARGET"].x, 6, scopeMode .. ": TARGET mirrored to activeScope.hudPositions.TARGET.x")

        -- 4. World Flare Bar (FLARE): direct Shift + Left-Drag + trailing OnDragStop
        local fBar = env1.DynamicMarker.flareBar
        fBar:Show()
        local fCx0, fCy0 = fBar:GetCenter()
        state1.shiftDown = true; state1.altDown = true; state1.lmbDown = true
        state1.cursorX, state1.cursorY = fCx0, fCy0
        fBar:FireScript("OnDragStart")
        state1.cursorX, state1.cursorY = 960 - 290, 540 + 185
        fBar:FireScript("OnUpdate", 0.016)
        state1.lmbDown = false
        fBar:FireScript("OnUpdate", 0.016)
        fBar:FireScript("OnDragStop")
        local flareSavedX, flareSavedY = env1.DynamicMarkerDB.flareBarX, env1.DynamicMarkerDB.flareBarY
        assertEqual(flareSavedX, -290, scopeMode .. ": FLARE X saved")
        assertEqual(flareSavedY, 185, scopeMode .. ": FLARE Y saved")
        assertEqual(env1.DynamicSuiteDB.global.hudPositions["FLARE"].x, flareSavedX, scopeMode .. ": FLARE mirrored to DynamicSuiteDB.global.hudPositions")
        assertEqual(activeScope1.hudPositions["FLARE"].x, flareSavedX, scopeMode .. ": FLARE mirrored to activeScope.hudPositions")

        -- 5. Chat Frame (CHAT): direct Shift + Left-Drag preserves new X/Y and custom 560x280 dimensions
        env1.DynamicChat:SaveChatFramePosition("BOTTOMLEFT", "BOTTOMLEFT", 60, 40, 560, 280)
        state1.shiftDown = true; state1.altDown = true; state1.lmbDown = true
        state1.cursorX, state1.cursorY = 200, 150
        assertTrue(env1.DynamicChat:BeginDirectChatDrag() == true, scopeMode .. ": CHAT direct drag started")
        state1.cursorX, state1.cursorY = 200 + 160, 150 + 95
        env1.DynamicChat._directChatDragDriver:FireScript("OnUpdate", 0.016)
        state1.lmbDown = false
        env1.DynamicChat._directChatDragDriver:FireScript("OnUpdate", 0.016)
        env1.DynamicChat:EndDirectChatDrag(false)
        local chatPos1 = env1.DynamicChatDB.chatFramePos
        assertEqual(chatPos1.x, 220, scopeMode .. ": CHAT X saved after Shift-Drag")
        assertEqual(chatPos1.y, 135, scopeMode .. ": CHAT Y saved after Shift-Drag")
        assertEqual(chatPos1.width, 560, scopeMode .. ": CHAT custom width preserved")
        assertEqual(chatPos1.height, 280, scopeMode .. ": CHAT custom height preserved")
        assertEqual(env1.DynamicSuiteDB.global.hudPositions["CHAT"].x, 220, scopeMode .. ": CHAT mirrored to DynamicSuiteDB.global.hudPositions")
        assertEqual(activeScope1.hudPositions["CHAT"].x, 220, scopeMode .. ": CHAT mirrored to activeScope.hudPositions")

        -- 6. Shared Alert Toast (TOAST): DynamicLoadToastFrame direct Shift + Left-Drag
        local showToastFn = (type(dl1) == "table" and dl1.ShowToast) or shared1.ShowToast
        showToastFn("outdoor", 3, true)
        local toastFr = env1.DynamicLoadToastFrame
        assertTrue(toastFr ~= nil and toastFr:IsShown(), scopeMode .. ": DynamicLoadToastFrame shown")
        local toCx0, toCy0 = toastFr:GetCenter()
        state1.shiftDown = true; state1.altDown = true; state1.lmbDown = true
        state1.cursorX, state1.cursorY = toCx0, toCy0
        toastFr:FireScript("OnDragStart")
        assertTrue(toastFr._dsDirectDragActive == true, scopeMode .. ": TOAST direct drag active")
        state1.cursorX, state1.cursorY = toCx0 + 210, toCy0 - 160
        toastFr:FireScript("OnUpdate", 0.016)
        state1.lmbDown = false
        toastFr:FireScript("OnUpdate", 0.016)
        toastFr:FireScript("OnDragStop")
        local toastSavedX = activeScope1.toastPos.x
        local toastSavedY = activeScope1.toastPos.y
        assertTrue(math.abs(toastSavedX - 210) <= 2, scopeMode .. ": TOAST X updated (" .. tostring(toastSavedX) .. ")")
        assertEqual(env1.DynamicSuiteDB.global.toastPos.x, toastSavedX, scopeMode .. ": TOAST mirrored to DynamicSuiteDB.global.toastPos.x")
        assertEqual(env1.DynamicSuiteDB.global.hudPositions["TOAST"].x, toastSavedX, scopeMode .. ": TOAST mirrored to DynamicSuiteDB.global.hudPositions.TOAST.x")
        assertEqual(activeScope1.hudPositions["TOAST"].x, toastSavedX, scopeMode .. ": TOAST mirrored to activeScope.hudPositions.TOAST.x")
        assertEqual(env1.DynamicLoadDB.toastPos.x, toastSavedX, scopeMode .. ": TOAST mirrored to DynamicLoadDB.toastPos.x")

        -- SIMULATE /reload: Brand new Lua environment receiving ONLY persisted SavedVariables!
        local persistedSV = {
            DynamicSuiteDB  = env1.DynamicSuiteDB,
            DynamicLoadDB   = env1.DynamicLoadDB,
            DynamicPrepDB   = env1.DynamicPrepDB,
            DynamicMarkerDB = env1.DynamicMarkerDB,
            DynamicChatDB   = env1.DynamicChatDB,
        }
        local env2, _, shared2 = BootAll6Modules(persistedSV, scopeMode)

        -- Exercise unsettled early-reload UIParent (300x200) followed by settled 1920x1080 + post-reload Clamp pass
        env2.UIParent:SetSize(300, 200)
        env2.DynamicPrep:ApplyBarGeometry()
        env2.DynamicPrep:RefreshClickableBuffs(true)
        env2.DynamicMarker:RefreshTargetBar()
        env2.DynamicMarker:RefreshFlareBar()
        env2.DynamicChat:ApplySavedChatFramePosition()
        if shared2.ClampToastPosition then shared2.ClampToastPosition() end

        env2.UIParent:SetSize(1920, 1080)
        env2.DynamicPrep:ApplyBarGeometry()
        env2.DynamicPrep:RefreshClickableBuffs(true)
        env2.DynamicMarker:RefreshTargetBar()
        env2.DynamicMarker:RefreshFlareBar()
        env2.DynamicChat:ApplySavedChatFramePosition()
        if shared2.ClampToastPosition then shared2.ClampToastPosition() end
        env2.DynamicSuite.RestackAllToasts()

        -- Assert ALL 6 HUDs preserved their exact Shift-Dragged coordinates after /reload!
        local _, _, rPrepX, rPrepY = env2.DynamicPrep:GetSavedBarPosition()
        assertEqual(rPrepX, prepSavedX, scopeMode .. ": PREP X survived /reload + clamp")
        assertEqual(rPrepY, prepSavedY, scopeMode .. ": PREP Y survived /reload + clamp")

        local _, _, rBuffX, rBuffY = env2.DynamicPrep:GetSavedBuffBarPosition()
        assertEqual(rBuffX, buffSavedX, scopeMode .. ": prepBuffs X survived /reload + clamp")
        assertEqual(rBuffY, buffSavedY, scopeMode .. ": prepBuffs Y survived /reload + clamp")

        local rTargetPos = env2.DynamicMarker:GetStoredHUDPosition("TargetBar")
        assertEqual(rTargetPos.x, 6, scopeMode .. ": TARGET X survived /reload + clamp")
        assertEqual(rTargetPos.y, 5, scopeMode .. ": TARGET Y survived /reload + clamp")

        local rFlarePos = env2.DynamicMarker:GetStoredHUDPosition("FlareBar")
        assertEqual(rFlarePos.x, flareSavedX, scopeMode .. ": FLARE X survived /reload + clamp")
        assertEqual(rFlarePos.y, flareSavedY, scopeMode .. ": FLARE Y survived /reload + clamp")

        assertEqual(env2.DynamicChatDB.chatFramePos.x, 220, scopeMode .. ": CHAT X survived /reload + clamp")
        assertEqual(env2.DynamicChatDB.chatFramePos.y, 135, scopeMode .. ": CHAT Y survived /reload + clamp")
        assertEqual(env2.DynamicChatDB.chatFramePos.width, 560, scopeMode .. ": CHAT width survived /reload + clamp")
        assertEqual(env2.DynamicChatDB.chatFramePos.height, 280, scopeMode .. ": CHAT height survived /reload + clamp")

        local rToastStyle = env2.DynamicSuite.GetSharedToastStyle("ACTION")
        assertEqual(rToastStyle.pos.x, toastSavedX, scopeMode .. ": TOAST X survived /reload + clamp")
        assertEqual(rToastStyle.pos.y, toastSavedY, scopeMode .. ": TOAST Y survived /reload + clamp")
    end

    -- Also verify Standalone DynamicMarker reload persistence + trailing OnDragStop guard
    local sEnv1, sState1 = BootStandaloneMarkerEnv()
    local sDm1 = sEnv1.DynamicMarker
    sDm1:InitTargetBar()
    sDm1:InitFlareBar()
    sDm1.targetBar:Show()
    sDm1.flareBar:Show()
    local stCx, stCy = sDm1.targetBar:GetCenter()
    sState1.shiftDown = true; sState1.altDown = true; sState1.lmbDown = true
    sState1.cursorX, sState1.cursorY = stCx, stCy
    sDm1.targetBar:FireScript("OnDragStart")
    sState1.cursorX, sState1.cursorY = 960 - 7, 540 + 6 -- within snap range!
    sDm1.targetBar:FireScript("OnUpdate", 0.016)
    sState1.lmbDown = false; sState1.altDown = false
    sDm1.targetBar:FireScript("OnUpdate", 0.016)
    sDm1.targetBar:FireScript("OnDragStop")
    assertEqual(sEnv1.DynamicMarkerDB.targetBarX, -7, "Standalone TARGET X not reverted by trailing OnDragStop")
    assertEqual(sEnv1.DynamicMarkerDB.targetBarY, 6, "Standalone TARGET Y not reverted by trailing OnDragStop")

    local sfCx, sfCy = sDm1.flareBar:GetCenter()
    sState1.shiftDown = true; sState1.altDown = true; sState1.lmbDown = true
    sState1.cursorX, sState1.cursorY = sfCx, sfCy
    sDm1.flareBar:FireScript("OnDragStart")
    sState1.cursorX, sState1.cursorY = 960 + 275, 540 - 165
    sDm1.flareBar:FireScript("OnUpdate", 0.016)
    sState1.lmbDown = false
    sDm1.flareBar:FireScript("OnUpdate", 0.016)
    sDm1.flareBar:FireScript("OnDragStop")

    -- Standalone simulated /reload
    local sEnv2 = CreateEnv()
    sEnv2.DynamicMarkerDB = DeepCopy(sEnv1.DynamicMarkerDB)
    sEnv2.C_AddOns.IsAddOnLoaded = function(name) return name == "DynamicMarker" end
    sEnv2.C_AddOns.GetAddOnEnableState = function(name) return (name == "DynamicMarker") and 2 or 0 end
    LoadChunkIntoEnv(MARKER_PATH, sEnv2, "DynamicMarker", {})
    sEnv2.DynamicMarker:InitDB()
    sEnv2.DynamicMarker:InitTargetBar()
    sEnv2.DynamicMarker:InitFlareBar()
    sEnv2.DynamicMarker:RefreshTargetBar()
    sEnv2.DynamicMarker:RefreshFlareBar()
    local sReloadT = sEnv2.DynamicMarker:GetStoredHUDPosition("TargetBar")
    local sReloadF = sEnv2.DynamicMarker:GetStoredHUDPosition("FlareBar")
    assertEqual(sReloadT.x, -7, "Standalone TARGET X survived /reload")
    assertEqual(sReloadT.y, 6, "Standalone TARGET Y survived /reload")
    assertEqual(sReloadF.x, 275, "Standalone FLARE X survived /reload")
    assertEqual(sReloadF.y, -165, "Standalone FLARE Y survived /reload")
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
