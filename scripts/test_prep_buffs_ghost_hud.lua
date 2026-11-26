-- ============================================================================
-- Headless Lua 5.1 Regression Suite: DynamicPrep Clickable Raid Buffs Ghost HUD
-- Verifies DynamicPrepClickableBuffBar stays hidden, mouse-disabled, and free
-- of visibility state drivers when no buffs should be shown (scope INST_ONLY
-- outdoors, HUD disabled, all buffs active), works normally when active, handles
-- HUD Edit Mode enter/exit cleanly, and ignores PLAYER_REGEN_ENABLED / zone
-- transitions while still invalid outdoors.
-- Pure ASCII Only.
-- ============================================================================

local CORE_PATH = "DynamicSuite/DynamicSuite_Core.lua"
local PREP_PATH = "DynamicSuite/Modules/DynamicPrep.lua"

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

local function CreatePrepEnv()
    local env = {}
    setmetatable(env, { __index = _G })
    env._G = env

    local state = {
        inCombat = false,
        inPetBattle = false,
        inInstance = false,
        instType = "none",
        inGroup = false,
        inRaid = false,
        hasArcaneIntellect = false,
        shiftDown = false,
        now = 200.0,
        timers = {},
        eventFrames = {},
        hooks = {},
        printLog = {},
        tooltipLines = {},
        tooltipOwner = nil,
    }

    env.wipe = function(t) if type(t) == "table" then for k in pairs(t) do t[k] = nil end end; return t end
    env.tinsert = table.insert
    env.tremove = table.remove
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
    env.CopyTable = function(src)
        if type(src) ~= "table" then return src end
        local dst = {}
        for k, v in pairs(src) do
            dst[k] = (type(v) == "table") and env.CopyTable(v) or v
        end
        return dst
    end
    env.time = os.time
    env.date = os.date
    env.GetTime = function() return state.now end
    env.GetLocale = function() return "enUS" end
    env.UnitName = function() return "Testmage" end
    env.UnitGUID = function() return "Player-1234-0001" end
    env.UnitClass = function() return "Mage", "MAGE", 8 end
    env.GetRealmName = function() return "Frostmourne" end
    env.IsInInstance = function() return state.inInstance, state.instType end
    env.IsInRaid = function() return state.inRaid end
    env.IsInGroup = function() return state.inGroup or state.inRaid end
    env.GetNumGroupMembers = function() return state.inRaid and 10 or (state.inGroup and 5 or 0) end
    env.GetNumSubgroupMembers = function() return state.inGroup and 4 or 0 end
    env.UnitIsGroupLeader = function() return false end
    env.UnitIsGroupAssistant = function() return false end
    env.UnitIsDeadOrGhost = function() return false end
    env.UnitIsGhost = function() return false end
    env.UnitIsConnected = function() return true end
    env.UnitExists = function(u) return u == "player" end
    env.UnitLevel = function() return 80 end
    env.InCombatLockdown = function() return state.inCombat end
    env.IsShiftKeyDown = function() return state.shiftDown end
    env.IsControlKeyDown = function() return false end
    env.IsAltKeyDown = function() return false end
    env.IsMouseButtonDown = function() return false end
    env.GetCursorPosition = function() return 960, 540 end
    env.GetSpecialization = function() return 1 end
    env.GetSpecializationInfo = function() return 62, "Arcane", "", 135932, "DAMAGER" end
    env.C_SpecializationInfo = { GetSpecialization = env.GetSpecialization, GetSpecializationInfo = env.GetSpecializationInfo }
    env.GetLootSpecialization = function() return 0 end
    env.GetFramerate = function() return 120 end
    env.GetNetStats = function() return 0, 0, 20, 25 end
    env.GetInventoryItemDurability = function() return 100, 100 end
    env.GetInventoryItemLink = function() return nil end
    env.GetInventoryItemID = function() return nil end
    env.GetAddOnMemoryUsage = function() return 0 end
    env.UpdateAddOnMemoryUsage = function() end
    env.GetCVar = function() return "1" end
    env.GetCVarBool = function() return false end
    env.SetCVar = function() end
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
    env.IsSpellKnown = function() return true end
    env.C_SpellBook = { IsSpellKnown = function() return true end }
    env.C_Spell = {
        GetSpellName = function() return "Arcane Intellect" end,
        GetSpellTexture = function() return 135932 end,
        IsSpellUsable = function() return true, false end,
    }
    env.GetSpellInfo = function() return "Arcane Intellect", nil, 135932 end
    env.C_Item = { GetItemCount = function() return 0 end, GetItemInfo = function() return nil end }
    env.GetItemCount = function() return 0 end
    env.C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemID = function() return nil end }
    env.C_Texture = { GetAtlasInfo = function() return nil end }
    env.C_PetBattles = { IsInBattle = function() return state.inPetBattle end }
    env.C_EventUtils = { IsEventValid = function() return true end }
    env.C_UnitAuras = {
        GetAuraDataByIndex = function(unit, idx, filter)
            if unit == "player" and idx == 1 and state.hasArcaneIntellect and (not filter or filter == "HELPFUL") then
                return {
                    spellId = 1459,
                    name = "Arcane Intellect",
                    icon = 135932,
                    expirationTime = state.now + 3600,
                    duration = 3600,
                    auraInstanceID = 1,
                }
            end
            return nil
        end,
    }
    env.C_Timer = {
        After = function(delay, fn)
            state.timers[#state.timers + 1] = { delay = delay, fn = fn, fired = false }
        end,
        NewTimer = function(delay, fn)
            local entry = { delay = delay, fn = fn, cancelled = false, Cancel = function(self) self.cancelled = true end }
            return entry
        end,
        NewTicker = function(_, fn)
            return { Cancel = function() end, fn = fn }
        end,
    }
    env.C_CVar = {
        GetCVar = function() return "1" end,
        GetCVarBool = function() return false end,
        SetCVar = function() end,
        GetCVarDefault = function() return "1" end,
    }
    env.C_AddOns = {
        GetAddOnMetadata = function() return "2.11.0" end,
        IsAddOnLoaded = function(name) return name == "DynamicSuite" or name == "DynamicPrep" end,
        GetAddOnInfo = function(name) return name, name, "", true, "INSECURE", false end,
        GetAddOnEnableState = function() return 2 end,
    }
    env.C_Map = { GetMapInfo = function() return { name = "Dornogal" } end }
    env.GetNumAddOns = function() return 0 end
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
    env.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
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
            _stateDrivers = {},
        }
        function f:SetScript(ev, fn) self._scripts[ev] = fn end
        function f:HookScript(ev, fn)
            local prev = self._scripts[ev]
            if prev then
                self._scripts[ev] = function(...) prev(...); fn(...) end
            else
                self._scripts[ev] = fn
            end
        end
        function f:GetScript(ev) return self._scripts[ev] end
        function f:FireScript(ev, ...)
            if type(self._scripts[ev]) == "function" then return self._scripts[ev](self, ...) end
        end
        function f:RegisterEvent(ev)
            self._events[ev] = true
            state.eventFrames[#state.eventFrames + 1] = self
        end
        function f:RegisterUnitEvent(ev)
            self:RegisterEvent(ev)
        end
        function f:UnregisterEvent(ev) self._events[ev] = nil end
        function f:UnregisterAllEvents() self._events = {} end
        function f:Show() self._shown = true; self:FireScript("OnShow") end
        function f:Hide() self._shown = false; self:FireScript("OnHide") end
        function f:SetShown(b) if b then self:Show() else self:Hide() end end
        function f:IsShown() return self._shown == true end
        function f:IsVisible() return self._shown == true end
        function f:Raise() end
        function f:SetPoint(pt, relTo, relPt, x, y)
            if type(relTo) == "number" then y = relPt; x = relTo; relPt = pt; relTo = env.UIParent end
            table.insert(self._points, { pt or "CENTER", relTo or env.UIParent, relPt or pt or "CENTER", tonumber(x) or 0, tonumber(y) or 0 })
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
        function f:GetEffectiveScale()
            if self == env.UIParent then return self._scale end
            return (env.UIParent and env.UIParent._scale or 1.0) * (self._scale or 1.0)
        end
        function f:SetAlpha(a) self._alpha = a or 1.0 end
        function f:GetAlpha() return self._alpha end
        function f:SetFrameStrata() end
        function f:SetFrameLevel(lvl) self._level = lvl end
        function f:GetFrameLevel() return self._level or 5 end
        function f:SetClampedToScreen() end
        function f:SetClampRectInsets() end
        function f:SetClipsChildren() end
        function f:SetIgnoreParentAlpha() end
        function f:SetParent(p) self._parent = p end
        function f:GetParent() return self._parent or env.UIParent end
        function f:EnableMouse(flag) self._mouseEnabled = (flag ~= false) end
        function f:IsMouseEnabled() return self._mouseEnabled == true end
        function f:EnableMouseWheel() end
        function f:EnableKeyboard() end
        function f:SetMovable() end
        function f:SetResizable() end
        function f:SetResizeBounds() end
        function f:RegisterForDrag() end
        function f:RegisterForClicks() end
        function f:SetAttribute(k, v) self._attrs[k] = v end
        function f:GetAttribute(k) return self._attrs[k] end
        function f:IsMouseOver() return self._mouseOver end
        function f:SetBackdrop() end
        function f:SetBackdropColor() end
        function f:SetBackdropBorderColor(r, g, b, a) self._borderColor = { r, g, b, a } end
        function f:GetBackdropBorderColor() return 1, 1, 1, 1 end
        function f:GetBackdropColor() return 0, 0, 0, 1 end
        function f:SetNormalTexture() end
        function f:SetPushedTexture() end
        function f:SetHighlightTexture() end
        function f:SetFont(p, sz, fl) self._font = p; self._size = sz; self._flags = fl; return true end
        function f:GetFont() return self._font or "Fonts\\FRIZQT__.TTF", self._size or 12, self._flags or "" end
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
            function tex:Show() self._shown = true end
            function tex:Hide() self._shown = false end
            function tex:IsShown() return self._shown == true end
            return tex
        end
        function f:CreateFontString()
            local fs = { _text = "", _shown = true }
            function fs:SetPoint() end
            function fs:ClearAllPoints() end
            function fs:SetFont() return true end
            function fs:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
            function fs:SetShadowColor() end
            function fs:SetShadowOffset() end
            function fs:SetTextColor() end
            function fs:SetWidth(w) self._w = w end
            function fs:SetHeight(h) self._h = h end
            function fs:SetSize(w, h) self._w = w; self._h = h end
            function fs:SetAlpha() end
            function fs:SetJustifyH() end
            function fs:SetJustifyV() end
            function fs:SetWordWrap() end
            function fs:SetText(t) self._text = tostring(t or "") end
            function fs:GetText() return self._text end
            function fs:GetStringWidth() return #self._text * 6 end
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
    function gt:AddLine(txt) state.tooltipLines[#state.tooltipLines + 1] = tostring(txt or "") end
    function gt:IsOwned(owner) return state.tooltipOwner == owner and self._shown end
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

    function state.FlushTimers()
        local i = 1
        while i <= #state.timers do
            local entry = state.timers[i]
            if not entry.fired then
                entry.fired = true
                state.now = state.now + (entry.delay or 0) + 0.05
                entry.fn()
            end
            i = i + 1
        end
    end

    local sharedTbl = {}
    local c1, err1 = loadfile(CORE_PATH)
    assertTrue(c1 ~= nil, "Failed to load Core: " .. tostring(err1))
    setfenv(c1, env); c1("DynamicSuite", sharedTbl)

    local c2, err2 = loadfile(PREP_PATH)
    assertTrue(c2 ~= nil, "Failed to load DynamicPrep: " .. tostring(err2))
    setfenv(c2, env); c2("DynamicSuite", sharedTbl)

    state.FireEvent("ADDON_LOADED", "DynamicSuite")
    state.FireEvent("ADDON_LOADED", "DynamicPrep")

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

-- (a) INST_ONLY outdoors stays hidden, state driver unregistered, mouse disabled, OnEnter suppressed
RunTest("1. (a) INST_ONLY outdoors stays hidden without ghost hit-box or state driver", function()
    local env, state = CreatePrepEnv()
    local dp = env.DynamicPrep
    dp.db.raidBuffs.enabled = true
    dp.db.raidBuffs.scope = "INST_ONLY"
    state.inInstance = false
    state.instType = "none"
    state.hasArcaneIntellect = false

    local bar = dp:CreateClickableBuffBar()
    assertTrue(not bar:IsShown(), "Newly created DynamicPrepClickableBuffBar starts hidden")
    assertTrue(not bar:IsMouseEnabled(), "Newly created DynamicPrepClickableBuffBar starts mouse-disabled")
    assertEqual(bar._stateDrivers.visibility, nil, "No premature visibility state driver on creation")

    state.now = state.now + 1.0
    dp:RefreshClickableBuffs(true)

    assertTrue(not bar:IsShown(), "Bar remains hidden outdoors under INST_ONLY")
    assertTrue(not bar:IsMouseEnabled(), "Mouse disabled outdoors under INST_ONLY")
    assertEqual(bar._stateDrivers.visibility, nil, "Visibility state driver unregistered outdoors under INST_ONLY")
    assertEqual(bar._activeBuffCount, 0, "_activeBuffCount is 0 when hidden")
    assertTrue(not bar.hudBg:IsShown(), "hudBg hidden when outdoors under INST_ONLY")
    assertTrue(not bar.mover:IsShown(), "mover hidden when outdoors under INST_ONLY")

    bar:FireScript("OnEnter")
    assertTrue(not bar.hudBg:IsShown(), "OnEnter does not show hover border on hidden empty bar")
    assertTrue(not env.GameTooltip:IsShown(), "OnEnter does not open tooltip on hidden empty bar")
end)

-- (b) raidBuffs.enabled = false stays hidden, state driver unregistered, mouse disabled
RunTest("2. (b) raidBuffs.enabled = false stays hidden without state driver or mouse", function()
    local env, state = CreatePrepEnv()
    local dp = env.DynamicPrep
    dp.db.raidBuffs.enabled = false
    dp.db.raidBuffs.scope = "ALWAYS"
    state.hasArcaneIntellect = false

    state.now = state.now + 1.0
    dp:RefreshClickableBuffs(true)
    local bar = dp.clickableBuffBar

    assertTrue(not bar:IsShown(), "Bar hidden when raidBuffs.enabled is false")
    assertTrue(not bar:IsMouseEnabled(), "Mouse disabled when raidBuffs.enabled is false")
    assertEqual(bar._stateDrivers.visibility, nil, "Visibility state driver unregistered when disabled")
    assertEqual(bar._activeBuffCount, 0, "_activeBuffCount is 0 when disabled")
end)

-- (c) count == 0 with all buffs active stays hidden, state driver unregistered, mouse disabled
RunTest("3. (c) count == 0 with all buffs active stays hidden without state driver or mouse", function()
    local env, state = CreatePrepEnv()
    local dp = env.DynamicPrep
    dp.db.raidBuffs.enabled = true
    dp.db.raidBuffs.scope = "ALWAYS"
    state.hasArcaneIntellect = true

    state.now = state.now + 1.0
    dp:RefreshClickableBuffs(true)
    local bar = dp.clickableBuffBar

    assertTrue(not bar:IsShown(), "Bar hidden when all buffs active (count == 0)")
    assertTrue(not bar:IsMouseEnabled(), "Mouse disabled when count == 0")
    assertEqual(bar._stateDrivers.visibility, nil, "Visibility state driver unregistered when count == 0")
    assertEqual(bar._activeBuffCount, 0, "_activeBuffCount is 0 when all buffs active")
end)

-- (d) count > 0 in valid scope + ZONE_CHANGED_NEW_AREA immediate evaluation
RunTest("4. (d) count > 0 in valid scope & ZONE_CHANGED_NEW_AREA transitions", function()
    local env, state = CreatePrepEnv()
    local dp = env.DynamicPrep
    dp.db.raidBuffs.enabled = true
    dp.db.raidBuffs.scope = "INST_ONLY"
    state.hasArcaneIntellect = false
    state.inInstance = false
    state.instType = "none"

    state.now = state.now + 1.0
    dp:RefreshClickableBuffs(true)
    local bar = dp.clickableBuffBar
    assertTrue(not bar:IsShown(), "Outdoors before zoning: bar hidden")

    -- Zone into dungeon via ZONE_CHANGED_NEW_AREA (even within 0.45s window) -> shows immediately
    state.inInstance = true
    state.instType = "party"
    state.FireEvent("ZONE_CHANGED_NEW_AREA")

    assertTrue(bar:IsShown(), "Bar shown inside dungeon when buff is missing")
    assertTrue(bar:IsMouseEnabled(), "Mouse enabled when buffs are visible")
    assertEqual(bar._stateDrivers.visibility, "[petbattle][vehicleui][combat] hide; show",
        "Visibility state driver active when buffs are visible")
    assertTrue((bar._activeBuffCount or 0) >= 1, "_activeBuffCount >= 1 when Arcane Intellect is missing")

    bar:FireScript("OnEnter")
    assertTrue(bar.hudBg:IsShown(), "OnEnter shows hover border when buffs are active")
    assertTrue(env.GameTooltip:IsShown(), "OnEnter shows tooltip when buffs are active")
    bar:FireScript("OnLeave")

    -- Zone back outdoors via ZONE_CHANGED_NEW_AREA (immediately) -> hides again
    state.inInstance = false
    state.instType = "none"
    state.FireEvent("ZONE_CHANGED_NEW_AREA")

    assertTrue(not bar:IsShown(), "Bar hides immediately on ZONE_CHANGED_NEW_AREA back outdoors")
    assertTrue(not bar:IsMouseEnabled(), "Mouse disables immediately on zoning outdoors")
    assertEqual(bar._stateDrivers.visibility, nil, "Visibility state driver unregistered on zoning outdoors")
end)

-- (e) Entering HUD Edit Mode outdoors shows the bar and exiting HUD Edit Mode hides it cleanly
RunTest("5. (e) HUD Edit Mode enter outdoors shows bar and exit hides it cleanly", function()
    local env, state = CreatePrepEnv()
    local dp = env.DynamicPrep
    dp.db.raidBuffs.enabled = true
    dp.db.raidBuffs.scope = "INST_ONLY"
    state.inInstance = false
    state.instType = "none"
    state.hasArcaneIntellect = true

    state.now = state.now + 1.0
    dp:RefreshClickableBuffs(true)
    local bar = dp.clickableBuffBar
    assertTrue(not bar:IsShown(), "Bar hidden outdoors before HUD Edit Mode")

    -- 1. Standalone Buffs Edit Mode entry -> shows bar + preview icons + built-in mover
    dp:SetBuffsEditMode(true)
    assertTrue(bar:IsShown(), "Bar shown when entering standalone Edit Mode outdoors")
    assertTrue(bar:IsMouseEnabled(), "Mouse enabled in standalone Edit Mode")
    assertEqual(bar._stateDrivers.visibility, nil, "Visibility state driver unregistered during standalone Edit Mode")
    assertTrue(bar.buttons[1]:IsShown(), "Preview buff icon shown in standalone Edit Mode")
    assertTrue(bar.mover:IsShown(), "Mover overlay shown in standalone Edit Mode")

    dp:SetBuffsEditMode(false)
    assertTrue(not bar:IsShown(), "Bar hides immediately on exiting standalone Edit Mode outdoors")
    assertTrue(not bar:IsMouseEnabled(), "Mouse disabled after exiting standalone Edit Mode")
    assertEqual(bar._stateDrivers.visibility, nil, "Visibility state driver stays unregistered after standalone Edit Mode exit")
    assertTrue(not bar.mover:IsShown(), "Mover hidden after standalone Edit Mode exit")

    -- 2. Suite HUD Edit Mode entry (_dsEditModeActive + SetEditMode(true))
    bar._dsEditModeActive = true
    bar:SetEditMode(true)
    assertTrue(bar:IsShown(), "Bar shown when entering Suite HUD Edit Mode outdoors")
    assertTrue(bar:IsMouseEnabled(), "Mouse enabled in Suite HUD Edit Mode")
    assertEqual(bar._stateDrivers.visibility, nil, "Visibility state driver unregistered during Suite HUD Edit Mode")
    assertTrue(bar.buttons[1]:IsShown(), "Preview buff icon shown in Suite HUD Edit Mode")
    assertTrue(not bar.mover:IsShown(), "Built-in mover suppressed while Suite carrier overlay owns Edit Mode")

    -- Simulate Suite HUD Edit Mode exit (_dsEditModeActive = false + SetEditMode(false))
    bar._dsEditModeActive = false
    bar:SetEditMode(false)
    assertTrue(not bar:IsShown(), "Bar hides immediately on exiting Suite HUD Edit Mode outdoors")
    assertTrue(not bar:IsMouseEnabled(), "Mouse disabled after exiting Suite HUD Edit Mode")
    assertEqual(bar._stateDrivers.visibility, nil, "Visibility state driver stays unregistered after exiting Suite HUD Edit Mode")
    assertTrue(not bar.hudBg:IsShown(), "hudBg hidden after exiting Suite HUD Edit Mode")
    assertTrue(not bar.mover:IsShown(), "mover hidden after exiting Suite HUD Edit Mode")
    assertTrue(not bar.buttons[1]:IsShown(), "Preview buff buttons hidden after exiting Suite HUD Edit Mode")
end)

-- (f) PLAYER_REGEN_ENABLED outdoors under INST_ONLY never re-shows the bar
RunTest("6. (f) PLAYER_REGEN_ENABLED (including 0.15s timer) outdoors under INST_ONLY never re-shows bar", function()
    local env, state = CreatePrepEnv()
    local dp = env.DynamicPrep
    dp.db.raidBuffs.enabled = true
    dp.db.raidBuffs.scope = "INST_ONLY"
    state.inInstance = false
    state.instType = "none"
    state.hasArcaneIntellect = false

    state.now = state.now + 1.0
    dp:RefreshClickableBuffs(true)
    local bar = dp.clickableBuffBar
    assertTrue(not bar:IsShown(), "Bar starts hidden outdoors under INST_ONLY")

    -- Enter and exit combat outdoors
    state.inCombat = true
    state.FireEvent("PLAYER_REGEN_DISABLED")
    state.inCombat = false
    state.FireEvent("PLAYER_REGEN_ENABLED")

    assertTrue(not bar:IsShown(), "Bar stays hidden right on PLAYER_REGEN_ENABLED")
    assertEqual(bar._stateDrivers.visibility, nil, "State driver remains nil right on PLAYER_REGEN_ENABLED")

    state.FlushTimers()
    assertTrue(not bar:IsShown(), "Bar stays hidden after 0.15s post-combat refresh outdoors under INST_ONLY")
    assertTrue(not bar:IsMouseEnabled(), "Mouse stays disabled after 0.15s post-combat refresh")
    assertEqual(bar._stateDrivers.visibility, nil, "State driver remains unregistered after 0.15s post-combat refresh")
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
