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

local function CreateHarness(opts)
    opts = opts or {}
    local env = {}
    setmetatable(env, { __index = _G })
    env._G = env

    local state = {
        inCombat = false,
        loadedAddons = { DynamicSuite = true, Blizzard_Communities = true, Blizzard_WorldMap = true, Blizzard_GroupFinder = true },
        eventFrames = {},
        timers = {},
        cursorX = 960,
        cursorY = 540,
        leftMouseDown = false,
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
    env.IsMouseButtonDown = function(btn)
        if btn == "LeftButton" then return state.leftMouseDown == true end
        return false
    end
    env.GetCursorPosition = function() return state.cursorX, state.cursorY end
    env.MouseIsOver = function() return true end
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
        function w:StartMoving() self._startMovingCount = (self._startMovingCount or 0) + 1 end
        function w:StopMovingOrSizing() self._stopMovingCount = (self._stopMovingCount or 0) + 1 end
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
    local function AttachTrackedTitleContainer(parentFrame, callStartMovingOnDrag)
        local tc = MakeFrame("Frame", nil, parentFrame)
        tc._setScriptCalls = {}
        tc._registerForDragCount = 0
        tc._nativeDragStartCount = 0
        tc._nativeDragStopCount = 0
        local origRegDrag = tc.RegisterForDrag
        function tc:RegisterForDrag(...)
            self._registerForDragCount = self._registerForDragCount + 1
            return origRegDrag(self, ...)
        end
        -- Pre-seed Blizzard's own drag handlers before DesktopWindows loads
        tc._scripts.OnDragStart = function()
            tc._nativeDragStartCount = tc._nativeDragStartCount + 1
            if callStartMovingOnDrag and parentFrame.StartMoving then
                parentFrame:StartMoving()
            end
        end
        tc._scripts.OnDragStop = function()
            tc._nativeDragStopCount = tc._nativeDragStopCount + 1
        end
        local origSetScript = tc.SetScript
        function tc:SetScript(ev, fn)
            table.insert(self._setScriptCalls, ev)
            return origSetScript(self, ev, fn)
        end
        parentFrame.TitleContainer = tc
        return tc
    end

    local comm = MakeFrame("Frame", "CommunitiesFrame", env.UIParent)
    comm:SetSize(820, 560)
    AttachTrackedTitleContainer(comm, false)
    env.UIPanelWindows["CommunitiesFrame"] = { area = "left", pushable = 0 }

    local pve = MakeFrame("Frame", "PVEFrame", env.UIParent)
    pve:SetSize(563, 428)
    AttachTrackedTitleContainer(pve, true)
    env.UIPanelWindows["PVEFrame"] = { area = "left", pushable = 1 }

    local spells = MakeFrame("Frame", "PlayerSpellsFrame", env.UIParent)
    spells:SetSize(1618, 898)
    local spellsTab1 = MakeFrame("Button", nil, spells)
    spellsTab1.tabID = 1
    spells.TabSystem = {
        tabs = { spellsTab1 },
        GetSelectedTabID = function() return 1 end,
        SetTab = function() end,
    }
    env.UIPanelWindows["PlayerSpellsFrame"] = { area = "center", pushable = 0 }

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

    if opts.onBeforeLoad then
        opts.onBeforeLoad(env, spells)
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

    if opts.initialDragAnywhere ~= nil or opts.initialScrollScale ~= nil then
        env.DynamicSuiteDB = {
            global = {
                desktopWindows = {
                    masterEnabled = true,
                    sideBySide = true,
                    dragAnywhere = opts.initialDragAnywhere,
                    scrollScale = opts.initialScrollScale,
                    positions = {},
                    scales = {},
                },
            },
        }
    end

    FireEvent("ADDON_LOADED", "DynamicSuite")
    FireEvent("PLAYER_LOGIN")
    FlushTimers()

    return {
        env = env,
        state = state,
        comm = comm,
        pve = pve,
        spells = spells,
        spellsTab1 = spellsTab1,
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
    assertEqual(src:find("._dsCloseHooked", 1, true), nil, "Direct Blizzard closeBtn._dsCloseHooked field write must be removed")
    assertEqual(src:find("._dsPassiveChrome", 1, true), nil, "Direct Blizzard frame._dsPassiveChrome field write must be removed")
    assertEqual(src:find("._dsDragHooked", 1, true), nil, "Direct Blizzard tc._dsDragHooked field write must be removed")
    assertEqual(src:find("._dsWheelHooked", 1, true), nil, "Direct Blizzard targetRegion._dsWheelHooked field write must be removed")
    assertEqual(src:find("._dsTabBtnHooked", 1, true), nil, "Direct Blizzard PlayerSpellsFrame tab button _dsTabBtnHooked field write must be removed")
    h.spells:Show()
    assertEqual(h.spellsTab1._dsTabBtnHooked, nil, "PlayerSpellsFrame TabSystem button receives zero custom _dsTabBtnHooked fields")

    -- Verify secret frame name / secret RegisterUIPanel arg / secret debugstack / secret GLOBAL_MOUSE_DOWN never throws
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
    env.GetRealmName = function() return secretMarker end

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
    local mouseFrame = env.DynamicSuiteDesktopWindowsMouseFrame
    if mouseFrame and mouseFrame:GetScript("OnEvent") then
        mouseFrame:GetScript("OnEvent")(mouseFrame, "GLOBAL_MOUSE_DOWN", secretMarker)
    end
    assertEqual(true, true, "DesktopWindows hooks handled secret frame names, debugstack, and GLOBAL_MOUSE_DOWN with zero errors")
end)

-- (f) DesktopWindows never calls SetScript on CommunitiesFrame.TitleContainer or PVEFrame.TitleContainer,
--     and header dragging + right-click reset remain fully functional on both overlay and TitleContainer
RunTest("(f) Zero SetScript on Blizzard TitleContainer (CommunitiesFrame & PVEFrame) with working drag & right-click reset", function()
    local h = CreateHarness()
    local env = h.env
    local dw = env.DynamicSuite.DesktopWindows
    local db = dw:GetDB()
    db.masterEnabled = true
    db.sideBySide = true
    db.dragAnywhere = true
    db.positions = {}
    db.scales = {}

    -- Static source check: DesktopWindows must never call SetScript on TitleContainer
    local fh = assert(io.open("DynamicSuite/DynamicSuite_Core.lua", "rb"))
    local src = fh:read("*a")
    fh:close()
    assertEqual(src:find("tc.SetScript", 1, true), nil, "Direct tc.SetScript call must be removed from DesktopWindows")
    assertEqual(src:find("TitleContainer:SetScript", 1, true), nil, "Direct TitleContainer:SetScript call must not exist")

    local function FindHeaderOverlay(parentFrame)
        for _, f in ipairs(h.state.eventFrames) do
            if f._parent == parentFrame and f._scripts.OnDragStart and f._scripts.OnMouseUp then
                return f
            end
        end
        return nil
    end

    -- Show both taint-sensitive frames and trigger UIPanel updates
    h.comm:Show()
    h.pve:Show()
    env.UpdateUIPanelPositions()

    -- Verify zero SetScript calls occurred on either TitleContainer
    assertEqual(#h.comm.TitleContainer._setScriptCalls, 0, "DesktopWindows must never call SetScript on CommunitiesFrame.TitleContainer")
    assertEqual(#h.pve.TitleContainer._setScriptCalls, 0, "DesktopWindows must never call SetScript on PVEFrame.TitleContainer")

    -- 1. Drag CommunitiesFrame via its addon-owned header overlay and verify saved offset
    local commOv = FindHeaderOverlay(h.comm)
    assertTrue(commOv ~= nil, "CommunitiesFrame addon-owned header overlay created")
    h.state.cursorX, h.state.cursorY = 960, 540
    h.state.leftMouseDown = true
    commOv._scripts.OnDragStart(commOv, "LeftButton")
    h.state.cursorX, h.state.cursorY = 1080, 490
    local driver = env.DynamicSuiteDesktopWindowsDragDriver
    assertTrue(driver ~= nil and type(driver._scripts.OnUpdate) == "function", "Drag driver OnUpdate active during overlay drag")
    driver._scripts.OnUpdate(driver, 0.016)
    h.state.leftMouseDown = false
    commOv._scripts.OnDragStop(commOv)

    assertTrue(type(db.positions.CommunitiesFrame) == "table", "CommunitiesFrame overlay drag saved position")
    assertNear(db.positions.CommunitiesFrame.x, 120, "CommunitiesFrame overlay drag X persisted")
    assertNear(db.positions.CommunitiesFrame.y, -50, "CommunitiesFrame overlay drag Y persisted")

    -- Right-click reset on CommunitiesFrame overlay clears saved position & scale
    db.scales.CommunitiesFrame = 1.15
    commOv._scripts.OnMouseUp(commOv, "RightButton")
    assertEqual(db.positions.CommunitiesFrame, nil, "CommunitiesFrame right-click reset clears saved position")
    assertEqual(db.scales.CommunitiesFrame, nil, "CommunitiesFrame right-click reset clears saved scale")
    local ptComm, _, _, cxComm, cyComm = h.comm:GetPoint(1)
    assertEqual(ptComm, "CENTER", "CommunitiesFrame reset restores CENTER anchor")
    assertNear(cxComm, 0, "CommunitiesFrame reset X is 0")
    assertNear(cyComm, 0, "CommunitiesFrame reset Y is 0")

    -- 2. Drag PVEFrame directly via TitleContainer HookScript (preserving Blizzard native handler)
    local pveTC = h.pve.TitleContainer
    assertTrue(type(pveTC._scripts.OnDragStart) == "function", "PVEFrame.TitleContainer OnDragStart hook active")
    assertTrue(type(pveTC._scripts.OnDragStop) == "function", "PVEFrame.TitleContainer OnDragStop hook active")
    assertTrue(type(pveTC._scripts.OnMouseUp) == "function", "PVEFrame.TitleContainer OnMouseUp hook active")

    h.state.cursorX, h.state.cursorY = 960, 540
    h.state.leftMouseDown = true
    pveTC._scripts.OnDragStart(pveTC, "LeftButton")
    assertEqual(pveTC._nativeDragStartCount, 1, "Blizzard native TitleContainer OnDragStart preserved via HookScript")
    h.state.cursorX, h.state.cursorY = 860, 620
    driver._scripts.OnUpdate(driver, 0.016)
    h.state.leftMouseDown = false
    pveTC._scripts.OnDragStop(pveTC)
    assertEqual(pveTC._nativeDragStopCount, 1, "Blizzard native TitleContainer OnDragStop preserved via HookScript")

    -- PVEFrame defaults to TOPLEFT (mock center 420, 700 -> offset -540, +160), so dragging (-100, +80) saves (-640, +240)
    assertTrue(type(db.positions.PVEFrame) == "table", "PVEFrame TitleContainer drag saved position")
    assertNear(db.positions.PVEFrame.x, -640, "PVEFrame TitleContainer drag X persisted")
    assertNear(db.positions.PVEFrame.y, 240, "PVEFrame TitleContainer drag Y persisted")

    -- Right-click reset on PVEFrame.TitleContainer clears saved position & scale and restores canonical TOPLEFT default
    db.scales.PVEFrame = 1.10
    pveTC._scripts.OnMouseUp(pveTC, "RightButton")
    assertEqual(db.positions.PVEFrame, nil, "PVEFrame TitleContainer right-click reset clears saved position")
    assertEqual(db.scales.PVEFrame, nil, "PVEFrame TitleContainer right-click reset clears saved scale")
    local ptPve, _, _, cxPve, cyPve = h.pve:GetPoint(1)
    assertEqual(ptPve, "TOPLEFT", "PVEFrame reset restores canonical TOPLEFT anchor")
    assertNear(cxPve, 16, "PVEFrame reset X is 16")
    assertNear(cyPve, -116, "PVEFrame reset Y is -116")

    -- 3. Disabling dragAnywhere keeps Blizzard's native TitleContainer handler working without cancelling StartMoving or saving drag
    db.dragAnywhere = false
    local stopCountBeforeOff = h.pve._stopMovingCount or 0
    h.state.cursorX, h.state.cursorY = 960, 540
    h.state.leftMouseDown = true
    pveTC._scripts.OnDragStart(pveTC, "LeftButton")
    h.state.leftMouseDown = false
    pveTC._scripts.OnDragStop(pveTC)
    assertEqual(pveTC._nativeDragStartCount, 2, "Blizzard native TitleContainer OnDragStart still runs when dragAnywhere is false")
    assertEqual(h.pve._stopMovingCount or 0, stopCountBeforeOff, "DesktopWindows must NOT call StopMovingOrSizing when dragAnywhere is false")
    assertEqual(db.positions.PVEFrame, nil, "DesktopWindows does not drag or save position when dragAnywhere is false")

    -- 3b. Yielding to BlizzMove must NEVER cancel Blizzard/BlizzMove drags via StopMovingOrSizing
    db.dragAnywhere = true
    h.state.loadedAddons.BlizzMove = true
    local stopCountBeforeYield = h.pve._stopMovingCount or 0
    pveTC._scripts.OnDragStart(pveTC, "LeftButton")
    if h.pve._scripts.OnDragStart then h.pve._scripts.OnDragStart(h.pve, "LeftButton") end
    pveTC._scripts.OnDragStop(pveTC)
    if h.pve._scripts.OnDragStop then h.pve._scripts.OnDragStop(h.pve) end
    assertEqual(h.pve._stopMovingCount or 0, stopCountBeforeYield, "Yielding to BlizzMove never calls StopMovingOrSizing on Blizzard frames")
    h.state.loadedAddons.BlizzMove = nil

    -- 3c. Fresh harness booted with dragAnywhere == false and scrollScale == true still supports TitleContainer right-click reset,
    --     and toggling dragAnywhere ON later registers drag and drags cleanly
    do
        local h2 = CreateHarness({ initialDragAnywhere = false, initialScrollScale = true })
        local db2 = h2.env.DynamicSuite.DesktopWindows:GetDB()
        db2.scales = { PVEFrame = 1.20 }
        h2.pve:Show()
        local tc2 = h2.pve.TitleContainer
        assertEqual(#tc2._setScriptCalls, 0, "Zero SetScript on TitleContainer when opened with dragAnywhere == false")
        assertEqual(tc2._registerForDragCount, 0, "TitleContainer skips RegisterForDrag while dragAnywhere == false")
        assertTrue(type(tc2._scripts.OnMouseUp) == "function", "TitleContainer right-click reset hooked even when dragAnywhere == false")
        tc2._scripts.OnMouseUp(tc2, "RightButton")
        assertEqual(db2.scales.PVEFrame, nil, "TitleContainer right-click reset clears scale when dragAnywhere == false")

        db2.dragAnywhere = true
        h2.pve:Show()
        assertEqual(tc2._registerForDragCount, 1, "Enabling dragAnywhere registers TitleContainer for drag once")
        h2.state.cursorX, h2.state.cursorY = 960, 540
        h2.state.leftMouseDown = true
        tc2._scripts.OnDragStart(tc2, "LeftButton")
        h2.state.cursorX, h2.state.cursorY = 1040, 580
        local drv2 = h2.env.DynamicSuiteDesktopWindowsDragDriver
        drv2._scripts.OnUpdate(drv2, 0.016)
        h2.state.leftMouseDown = false
        tc2._scripts.OnDragStop(tc2)
        assertTrue(type(db2.positions.PVEFrame) == "table", "Enabling dragAnywhere later makes TitleContainer dragging save position")
    end

    -- 4. Secret button & wheel delta arguments passed to TitleContainer, overlay, and frame hooks are safely ignored
    local secretBtn = setmetatable({}, {
        __tostring = function() error("secret string conversion", 2) end,
    })
    env.issecretvalue = function(v) return v == secretBtn end
    env.canaccessvalue = function(v) return v ~= secretBtn end
    db.dragAnywhere = true
    pveTC._scripts.OnDragStart(pveTC, secretBtn)
    pveTC._scripts.OnMouseUp(pveTC, secretBtn)
    commOv._scripts.OnDragStart(commOv, secretBtn)
    commOv._scripts.OnMouseUp(commOv, secretBtn)
    if commOv._scripts.OnMouseWheel then commOv._scripts.OnMouseWheel(commOv, secretBtn) end
    if h.pve._scripts.OnDragStart then h.pve._scripts.OnDragStart(h.pve, secretBtn) end
    assertEqual(db.positions.PVEFrame, nil, "Secret button arg does not trigger drag or reset")

    -- Final assertion: zero SetScript calls throughout the entire lifecycle
    assertEqual(#h.comm.TitleContainer._setScriptCalls, 0, "Zero SetScript calls on CommunitiesFrame.TitleContainer after drag/reset")
    assertEqual(#h.pve.TitleContainer._setScriptCalls, 0, "Zero SetScript calls on PVEFrame.TitleContainer after drag/reset")
end)

-- ============================================================================
-- Test (g): Zero direct method overwrites on PlayerSpellsFrame & MaximizeMinimizeFrame
--           and zero global overwrites on UpdateScaleForFit / UIPanelUpdateScaleForFit / FrameUtil.UpdateScaleForFit
-- ============================================================================
RunTest("(g) Zero global or PlayerSpellsFrame/MaximizeMinimizeFrame method overwrites (hooksecurefunc-only)", function()
    local hookedTargets = {}
    local origTrySetMin = function() end
    local origSetMin = function() end
    local origMax = function() end
    local origMin = function() end
    local origUpdateScale = function() end
    local origUIPanelScale = function() end
    local origFrameUtilScale = function() end

    local h = CreateHarness({
        onBeforeLoad = function(env, spells)
            spells.TrySetMinimized = origTrySetMin
            spells.SetMinimized = origSetMin
            spells.MaximizeMinimizeFrame = {
                IsMinimized = function() return false end,
                Maximize = origMax,
                Minimize = origMin,
            }
            env.UpdateScaleForFit = origUpdateScale
            env.UIPanelUpdateScaleForFit = origUIPanelScale
            env.FrameUtil = { UpdateScaleForFit = origFrameUtilScale }
            -- Spy hooksecurefunc WITHOUT mutating target tables so any direct overwrite is caught immediately
            env.hooksecurefunc = function(a, b, c)
                if type(a) == "string" then
                    hookedTargets[a] = true
                elseif type(a) == "table" and type(b) == "string" then
                    if a == env.FrameUtil then
                        hookedTargets["FrameUtil." .. b] = true
                    elseif a == spells.MaximizeMinimizeFrame then
                        hookedTargets["MaximizeMinimizeFrame." .. b] = true
                    elseif a == spells then
                        hookedTargets["PlayerSpellsFrame." .. b] = true
                    else
                        hookedTargets[b] = true
                    end
                end
            end
        end,
    })

    h.spells:Show()

    -- Exact reference identity preserved (zero direct overwrites)
    assertEqual(h.env.UpdateScaleForFit, origUpdateScale, "_G.UpdateScaleForFit must NEVER be directly overwritten")
    assertEqual(h.env.UIPanelUpdateScaleForFit, origUIPanelScale, "_G.UIPanelUpdateScaleForFit must NEVER be directly overwritten")
    assertEqual(h.env.FrameUtil.UpdateScaleForFit, origFrameUtilScale, "_G.FrameUtil.UpdateScaleForFit must NEVER be directly overwritten")
    assertEqual(h.spells.TrySetMinimized, origTrySetMin, "PlayerSpellsFrame.TrySetMinimized must NEVER be directly overwritten")
    assertEqual(h.spells.SetMinimized, origSetMin, "PlayerSpellsFrame.SetMinimized must NEVER be directly overwritten")
    assertEqual(h.spells.MaximizeMinimizeFrame.Maximize, origMax, "MaximizeMinimizeFrame.Maximize must NEVER be directly overwritten")
    assertEqual(h.spells.MaximizeMinimizeFrame.Minimize, origMin, "MaximizeMinimizeFrame.Minimize must NEVER be directly overwritten")

    -- All 7 hooks registered strictly through hooksecurefunc
    assertTrue(hookedTargets["UpdateScaleForFit"] == true, "UpdateScaleForFit hooked via hooksecurefunc")
    assertTrue(hookedTargets["UIPanelUpdateScaleForFit"] == true, "UIPanelUpdateScaleForFit hooked via hooksecurefunc")
    assertTrue(hookedTargets["FrameUtil.UpdateScaleForFit"] == true, "FrameUtil.UpdateScaleForFit hooked via hooksecurefunc")
    assertTrue(hookedTargets["PlayerSpellsFrame.TrySetMinimized"] == true, "PlayerSpellsFrame.TrySetMinimized hooked via hooksecurefunc")
    assertTrue(hookedTargets["PlayerSpellsFrame.SetMinimized"] == true, "PlayerSpellsFrame.SetMinimized hooked via hooksecurefunc")
    assertTrue(hookedTargets["MaximizeMinimizeFrame.Maximize"] == true, "MaximizeMinimizeFrame.Maximize hooked via hooksecurefunc")
    assertTrue(hookedTargets["MaximizeMinimizeFrame.Minimize"] == true, "MaximizeMinimizeFrame.Minimize hooked via hooksecurefunc")
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
