-- ============================================================================
-- Headless Lua 5.1 Regression Suite: Guild & Communities Window Anchor Stability
-- Verifies DesktopWindows in DynamicSuite_Core.lua:
--   (a) sideBySide enabled, unsaved CommunitiesFrame stays centred on UpdateUIPanelPositions()
--   (b) sideBySide enabled, saved custom offset + scale restored on UpdateUIPanelPositions()
--   (c) OnSizeChanged (ClampAndReanchorFrame) never locks Blizzard's temporary TOPLEFT coords
--   (d) Combat, masterDisabled, yielding, maximised WorldMapFrame, and sideBySide == false guards
-- Pure ASCII Only.
-- ============================================================================

local CORE_PATH = "DynamicSuite/DynamicSuite_Core.lua"

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

local function assertNear(actual, expected, msg)
    if type(actual) ~= "number" or math.abs(actual - expected) > 0.01 then
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

local function CreateHarness()
    local env = {}
    setmetatable(env, { __index = _G })
    env._G = env

    local state = {
        inCombat = false,
        loadedAddons = { DynamicSuite = true, Blizzard_Communities = true, Blizzard_WorldMap = true },
        eventFrames = {},
        timers = {},
    }

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
    env.GetTime = function() return 100.0 end
    env.time = function() return 1700000000 end
    env.UnitName = function() return "Dentee" end
    env.UnitClass = function() return "Mage", "MAGE", 8 end
    env.GetRealmName = function() return "Frostmourne" end
    env.InCombatLockdown = function() return state.inCombat end
    env.GetScreenWidth = function() return 1920 end
    env.GetScreenHeight = function() return 1080 end
    env.GetPhysicalScreenSize = function() return 1920, 1080 end
    env.IsShiftKeyDown = function() return false end
    env.IsControlKeyDown = function() return false end
    env.IsAltKeyDown = function() return false end
    env.IsMouseButtonDown = function() return false end
    env.GetCursorPosition = function() return 960, 540 end
    env.CreateColor = function(r, g, b, a)
        return { r = r or 1, g = g or 1, b = b or 1, a = a or 1, GetRGBA = function(self) return self.r, self.g, self.b, self.a end }
    end
    env.UISpecialFrames = {}
    env.SlashCmdList = {}
    env.UIPanelWindows = {}
    env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    env.UNKNOWNOBJECT = "Unknown"
    env.issecretvalue = function() return false end
    env.canaccessvalue = function() return true end

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
        After = function(_, fn) table.insert(state.timers, fn) end,
        NewTimer = function(_, fn) table.insert(state.timers, fn); return { Cancel = function() end } end,
    }
    env.C_EventUtils = { IsEventValid = function() return true end }
    env.C_AddOns = {
        GetAddOnMetadata = function() return "2.11.2" end,
        IsAddOnLoaded = function(n) return state.loadedAddons[n] == true end,
        GetAddOnInfo = function(n) return n, n, "", true, "INSECURE", false end,
        GetAddOnEnableState = function() return 2 end,
        GetNumAddOns = function() return 0 end,
    }
    env.GetNumAddOns = function() return 0 end
    env.DEFAULT_CHAT_FRAME = { AddMessage = function() end }

    local function MakeFrame(ftype, name, parent)
        local w = {
            _type = ftype or "Frame",
            _name = name,
            _parent = parent,
            _shown = false,
            _scale = 1.0,
            _width = 800,
            _height = 550,
            _points = { { "CENTER", nil, "CENTER", 0, 0 } },
            _scripts = {},
            _events = {},
            _attrs = {},
            _clamped = true,
            _strata = "MEDIUM",
            _toplevel = false,
            _cx = 960,
            _cy = 540,
        }
        function w:GetName() return self._name end
        function w:GetObjectType() return self._type end
        function w:SetParent(p) self._parent = p end
        function w:GetParent() return self._parent or env.UIParent end
        function w:Show() self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end
        function w:Hide() self._shown = false; if self._scripts.OnHide then self._scripts.OnHide(self) end end
        function w:SetShown(v) if v then self:Show() else self:Hide() end end
        function w:IsShown() return self._shown == true end
        function w:IsVisible() return self._shown == true end
        function w:IsForbidden() return false end
        function w:SetScale(s) self._scale = s or 1.0 end
        function w:GetScale() return self._scale end
        function w:GetEffectiveScale() return self._scale end
        function w:SetSize(ww, hh) self._width = ww; self._height = hh end
        function w:SetWidth(ww) self._width = ww end
        function w:SetHeight(hh) self._height = hh end
        function w:GetWidth() return self._width end
        function w:GetHeight() return self._height end
        function w:GetCenter()
            local p = self._points[1]
            if not p then return 960, 540 end
            if p[1] == "TOPLEFT" then
                return 420 / self._scale, 700 / self._scale
            end
            return (960 + ((p[4] or 0) * self._scale)) / self._scale, (540 + ((p[5] or 0) * self._scale)) / self._scale
        end
        function w:ClearAllPoints() self._points = {} end
        function w:SetPoint(pt, relTo, relPt, x, y)
            if type(relTo) == "number" then
                y = relPt; x = relTo; relPt = pt; relTo = env.UIParent
            end
            table.insert(self._points, { pt, relTo or env.UIParent, relPt or pt, tonumber(x) or 0, tonumber(y) or 0 })
        end
        function w:SetAllPoints() end
        function w:GetNumPoints() return #self._points end
        function w:GetPoint(idx)
            local p = self._points[idx or 1]
            if p then return p[1], p[2], p[3], p[4], p[5] end
            return nil
        end
        function w:SetClampedToScreen(v) self._clamped = (v == true) end
        function w:IsClampedToScreen() return self._clamped end
        function w:SetClampRectInsets() end
        function w:SetFrameStrata(s) self._strata = s end
        function w:GetFrameStrata() return self._strata end
        function w:SetFrameLevel(l) self._level = l end
        function w:GetFrameLevel() return self._level or 5 end
        function w:SetToplevel(v) self._toplevel = (v == true) end
        function w:IsToplevel() return self._toplevel end
        function w:EnableMouse() end
        function w:EnableMouseWheel() end
        function w:SetMovable() end
        function w:SetUserPlaced() end
        function w:RegisterForDrag() end
        function w:StartMoving() end
        function w:StopMovingOrSizing() end
        function w:Raise() end
        function w:SetBackdrop() end
        function w:SetBackdropColor() end
        function w:SetBackdropBorderColor() end
        function w:SetAttribute(k, v) self._attrs[k] = v end
        function w:GetAttribute(k) return self._attrs[k] end
        function w:RegisterEvent(ev) self._events[ev] = true end
        function w:UnregisterEvent(ev) self._events[ev] = nil end
        function w:SetScript(ev, fn) self._scripts[ev] = fn end
        function w:GetScript(ev) return self._scripts[ev] end
        function w:HookScript(ev, fn)
            local prev = self._scripts[ev]
            self._scripts[ev] = function(...)
                if prev then prev(...) end
                fn(...)
            end
        end
        function w:CreateTexture() return MakeFrame("Texture", nil, self) end
        function w:CreateFontString() return MakeFrame("FontString", nil, self) end
        function w:SetColorTexture() end
        function w:SetPointRaw(...) return self:SetPoint(...) end
        function w:SetFont() return true end
        function w:SetJustifyH() end
        function w:SetWordWrap() end
        function w:SetText(t) self._text = t end
        function w:GetText() return self._text end
        function w:SetTextColor() end
        function w:SetAlpha(a) self._alpha = a end
        function w:GetAlpha() return self._alpha or 1 end
        function w:GetStringWidth() return 100 end
        if name then env[name] = w end
        return w
    end

    env.MakeFrame = MakeFrame
    env.UIParent = MakeFrame("Frame", "UIParent", nil)
    env.UIParent:SetSize(1920, 1080)
    env.UIParent._shown = true

    env.CreateFrame = function(ftype, name, parent)
        local fr = MakeFrame(ftype, name, parent)
        table.insert(state.eventFrames, fr)
        return fr
    end

    -- Simulated Blizzard frames & UIPanel layout manager
    local comm = MakeFrame("Frame", "CommunitiesFrame", env.UIParent)
    comm:SetSize(820, 560)
    env.UIPanelWindows["CommunitiesFrame"] = { area = "left", pushable = 0 }

    local worldMap = MakeFrame("Frame", "WorldMapFrame", env.UIParent)
    worldMap:SetSize(980, 660)
    worldMap._maximized = false
    worldMap.IsMaximized = function(self) return self._maximized == true end
    env.UIPanelWindows["WorldMapFrame"] = { area = "left", pushable = 0 }

    local charFrame = MakeFrame("Frame", "CharacterFrame", env.UIParent)
    charFrame:SetSize(340, 424)
    env.UIPanelWindows["CharacterFrame"] = { area = "left", pushable = 3 }

    env.ShowUIPanel = function(frame)
        if frame and not frame._shown then frame:Show() end
    end
    env.HideUIPanel = function(frame)
        if frame and frame._shown then frame:Hide() end
    end
    env.UpdateUIPanelPositions = function()
        -- Mimics Blizzard snapping shown UIPanelWindows to TOPLEFT ("left" panel slot) on tab switch
        if comm:IsShown() then
            comm:ClearAllPoints()
            comm:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 16, -116)
        end
        if worldMap:IsShown() and not worldMap:IsMaximized() then
            worldMap:ClearAllPoints()
            worldMap:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 16, -116)
        end
    end

    local sharedTbl = {}
    local chunk, err = loadfile(CORE_PATH)
    assertTrue(chunk ~= nil, "Failed to load DynamicSuite_Core.lua: " .. tostring(err))
    setfenv(chunk, env)
    chunk("DynamicSuite", sharedTbl)

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
        for _, fn in ipairs(batch) do
            if type(fn) == "function" then fn() end
        end
    end

    FireEvent("ADDON_LOADED", "DynamicSuite")
    FireEvent("PLAYER_LOGIN")
    FlushTimers()

    return {
        env = env,
        state = state,
        comm = comm,
        worldMap = worldMap,
        charFrame = charFrame,
        FireEvent = FireEvent,
        FlushTimers = FlushTimers,
    }
end

-- (a) Unsaved CommunitiesFrame stays anchored at CENTER (0, 0) when UpdateUIPanelPositions() fires
RunTest("(a) sideBySide enabled, unsaved CommunitiesFrame stays at CENTER (0, 0) across UpdateUIPanelPositions()", function()
    local h = CreateHarness()
    local dw = h.env.DynamicSuite.DesktopWindows
    assertTrue(dw ~= nil, "DesktopWindows namespace initialized")
    local db = dw:GetDB()
    db.masterEnabled = true
    db.sideBySide = true
    db.positions = {}

    h.comm:Show()
    local pt0, rel0, rpt0, x0, y0 = h.comm:GetPoint(1)
    assertEqual(pt0, "CENTER", "Initial unsaved CommunitiesFrame centered")
    assertEqual(rel0, h.env.UIParent, "Anchored to UIParent")
    assertEqual(rpt0, "CENTER", "Relative point CENTER")
    assertNear(x0, 0, "Initial X is 0")
    assertNear(y0, 0, "Initial Y is 0")

    -- Simulate switching Guild / Community tabs triggering UpdateUIPanelPositions()
    h.env.UpdateUIPanelPositions()

    local pt1, rel1, rpt1, x1, y1 = h.comm:GetPoint(1)
    assertEqual(pt1, "CENTER", "CommunitiesFrame restored to CENTER instead of TOPLEFT")
    assertEqual(rel1, h.env.UIParent, "CommunitiesFrame stays anchored to UIParent")
    assertEqual(rpt1, "CENTER", "CommunitiesFrame relative point stays CENTER")
    assertNear(x1, 0, "Restored X stays 0")
    assertNear(y1, 0, "Restored Y stays 0")
end)

-- (b) Saved custom position & scale restored when UpdateUIPanelPositions() fires
RunTest("(b) sideBySide enabled, saved custom position & scale preserved across UpdateUIPanelPositions()", function()
    local h = CreateHarness()
    local dw = h.env.DynamicSuite.DesktopWindows
    local db = dw:GetDB()
    db.masterEnabled = true
    db.sideBySide = true
    db.dragAnywhere = true
    db.positions = { CommunitiesFrame = { x = 220, y = -80 } }
    db.scales = { CommunitiesFrame = 1.10 }

    h.comm:Show()
    -- Simulate Blizzard resetting point to TOPLEFT AND resetting scale to 1.0 during panel update
    local origUpdate = h.env.UpdateUIPanelPositions
    h.comm:SetScale(1.0)
    origUpdate()

    assertNear(h.comm:GetScale(), 1.10, "Saved CommunitiesFrame scale 1.10 restored")
    local pt, rel, rpt, x, y = h.comm:GetPoint(1)
    assertEqual(pt, "CENTER", "Saved CommunitiesFrame point restored to CENTER")
    assertEqual(rel, h.env.UIParent, "Anchored to UIParent")
    assertEqual(rpt, "CENTER", "Relative point CENTER")
    assertNear(x, 220 / 1.10, "Saved X restored accurately in scaled coords")
    assertNear(y, -80 / 1.10, "Saved Y restored accurately in scaled coords")
end)

-- (c) OnSizeChanged (ClampAndReanchorFrame) during temporary Blizzard TOPLEFT state never saves/locks TOPLEFT
RunTest("(c) OnSizeChanged on unsaved CommunitiesFrame at TOPLEFT keeps CENTER (0, 0)", function()
    local h = CreateHarness()
    local dw = h.env.DynamicSuite.DesktopWindows
    local db = dw:GetDB()
    db.masterEnabled = true
    db.sideBySide = true
    db.positions = {}

    h.comm:Show()
    -- Simulate tab resize occurring right after Blizzard moved CommunitiesFrame to TOPLEFT
    h.comm:ClearAllPoints()
    h.comm:SetPoint("TOPLEFT", h.env.UIParent, "TOPLEFT", 16, -116)
    h.comm:SetSize(860, 600)
    if h.comm._scripts.OnSizeChanged then
        h.comm._scripts.OnSizeChanged(h.comm, 860, 600)
    end

    local pt, _, _, x, y = h.comm:GetPoint(1)
    assertEqual(pt, "CENTER", "OnSizeChanged restores unsaved CommunitiesFrame to CENTER")
    assertNear(x, 0, "OnSizeChanged keeps unsaved X at 0")
    assertNear(y, 0, "OnSizeChanged keeps unsaved Y at 0")
    assertEqual(db.positions.CommunitiesFrame, nil, "Unsaved TOPLEFT coords are not written to db.positions")
end)

-- (d) Combat, masterDisabled, yielding, maximised WorldMapFrame, and sideBySide == false guards
RunTest("(d) Guards hold for combat, masterDisabled, yielding, maximised WorldMapFrame, and sideBySide == false", function()
    local h = CreateHarness()
    local dw = h.env.DynamicSuite.DesktopWindows
    local db = dw:GetDB()
    db.masterEnabled = true
    db.sideBySide = true
    db.positions = {}

    h.comm:Show()
    h.worldMap:Show()

    -- 1. Combat lockdown skips mutation
    h.state.inCombat = true
    h.env.UpdateUIPanelPositions()
    local ptCombat = h.comm:GetPoint(1)
    assertEqual(ptCombat, "TOPLEFT", "InCombatLockdown prevents post-hook from mutating CommunitiesFrame")
    h.state.inCombat = false

    -- 2. masterDisabled skips mutation
    db.masterEnabled = false
    h.env.UpdateUIPanelPositions()
    local ptDisabled = h.comm:GetPoint(1)
    assertEqual(ptDisabled, "TOPLEFT", "masterEnabled = false leaves Blizzard UIPanel layout alone")
    db.masterEnabled = true

    -- 3. Yielding to BlizzMove skips mutation
    h.state.loadedAddons.BlizzMove = true
    h.env.UpdateUIPanelPositions()
    local ptYield = h.comm:GetPoint(1)
    assertEqual(ptYield, "TOPLEFT", "Yielding to BlizzMove skips DesktopWindows post-hook")
    h.state.loadedAddons.BlizzMove = nil

    -- 4. Maximised WorldMapFrame is skipped while CommunitiesFrame still restores cleanly
    h.worldMap._maximized = true
    h.worldMap:ClearAllPoints()
    h.worldMap:SetPoint("BOTTOMLEFT", h.env.UIParent, "BOTTOMLEFT", 50, 50)
    h.env.UpdateUIPanelPositions()
    local ptComm = h.comm:GetPoint(1)
    assertEqual(ptComm, "CENTER", "CommunitiesFrame restores to CENTER once guards clear")
    local ptMap = h.worldMap:GetPoint(1)
    assertEqual(ptMap, "BOTTOMLEFT", "Maximised WorldMapFrame point is untouched")
    h.worldMap._maximized = false

    -- 5. sideBySide == false still restores saved custom offsets & scale across managed frames without forcing CENTER on unsaved frames
    db.sideBySide = false
    db.dragAnywhere = true
    db.positions = { CharacterFrame = { x = 140, y = 40 } }
    h.charFrame:Show()
    h.charFrame:ClearAllPoints()
    h.charFrame:SetPoint("TOPLEFT", h.env.UIParent, "TOPLEFT", 16, -116)
    h.env.UpdateUIPanelPositions()
    local ptChar, _, _, cx, cy = h.charFrame:GetPoint(1)
    assertEqual(ptChar, "CENTER", "sideBySide == false still restores saved custom offset on shown managed frame")
    assertNear(cx, 140, "Custom X restored when sideBySide == false")
    assertNear(cy, 40, "Custom Y restored when sideBySide == false")
    local ptCommOff = h.comm:GetPoint(1)
    assertEqual(ptCommOff, "TOPLEFT", "sideBySide == false leaves unsaved CommunitiesFrame at Blizzard TOPLEFT")
end)

-- (e) Zero direct global overwrites of UpdateScaleForFit & secret-string guards on ShowUIPanel/HideUIPanel/RegisterUIPanel
RunTest("(e) DesktopWindows uses hooksecurefunc (no raw UpdateScaleForFit overwrite) and guards secret frame names", function()
    local h = CreateHarness()
    local env = h.env
    local hookedNames = {}
    local origHook = env.hooksecurefunc
    env.hooksecurefunc = function(a, b, c)
        if type(a) == "string" then
            hookedNames[a] = true
        elseif type(b) == "string" then
            hookedNames[b] = true
        end
        return origHook(a, b, c)
    end

    local fitCalls = 0
    local origUpdateScaleForFit = function() fitCalls = fitCalls + 1 end
    env.UpdateScaleForFit = origUpdateScaleForFit
    env.UIPanelUpdateScaleForFit = origUpdateScaleForFit
    env.FrameUtil = { UpdateScaleForFit = origUpdateScaleForFit }

    -- Verify DynamicSuite_Core.lua source never directly overwrites UpdateScaleForFit or PlayerSpellsFrame.SetMinimized
    local fh = assert(io.open("DynamicSuite/DynamicSuite_Core.lua", "rb"))
    local src = fh:read("*a")
    fh:close()
    assertEqual(src:find("GuardFitScaleFn", 1, true), nil, "GuardFitScaleFn direct global overwrite must be removed")
    assertEqual(src:find("frame.SetMinimized = function", 1, true), nil, "Direct PlayerSpellsFrame.SetMinimized overwrite must be removed")
    assertEqual(src:find("mmf.Maximize = function", 1, true), nil, "Direct mmf.Maximize overwrite must be removed")
    assertEqual(src:find("mmf.Minimize = function", 1, true), nil, "Direct mmf.Minimize overwrite must be removed")

    -- Verify secret frame name / secret RegisterUIPanel arg / secret debugstack never throws string conversion errors
    local secretMarker = setmetatable({}, {
        __tostring = function()
            error("attempt to perform string conversion on a secret string value (execution tainted by 'DynamicSuite')", 2)
        end,
        __concat = function()
            error("attempt to perform string conversion on a secret string value (execution tainted by 'DynamicSuite')", 2)
        end,
    })
    env.issecretvalue = function(v) return v == secretMarker end
    env.canaccessvalue = function(v) return v ~= secretMarker end
    env.debugstack = function() return secretMarker end

    local secretFrame = {
        GetName = function() return secretMarker end,
        Show = function() end,
        Hide = function() end,
        IsShown = function() return true end,
        IsForbidden = function() return false end,
    }
    if type(env.ShowUIPanel) == "function" then env.ShowUIPanel(secretFrame) end
    if type(env.HideUIPanel) == "function" then env.HideUIPanel(secretFrame) end
    if type(env.RegisterUIPanel) == "function" then env.RegisterUIPanel(secretMarker) end
    if type(env.UpdateUIPanelPositions) == "function" then env.UpdateUIPanelPositions() end
    assertEqual(true, true, "DesktopWindows hooks handled secret frame names and debugstack with zero errors")
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
