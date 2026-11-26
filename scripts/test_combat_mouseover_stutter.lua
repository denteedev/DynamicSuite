-- ============================================================================
-- Headless Lua 5.1 Regression Suite: In-Combat Raid-Frame Mouseover Stutter Fix
-- Verifies:
--   (a) DynamicCursor OnCursorUpdate executes 0 GetInstanceInfo / IsInInstance
--       / SpellIsTargeting calls per frame and skips ClearAllPoints / SetPoint
--       when the cursor has not moved.
--   (b) DynamicCursor's GameTooltip_SetDefaultAnchor hook never calls
--       tooltip:SetOwner recursively and skips forbidden/secret tooltips cleanly.
--   (c) DynamicPrep:RefreshCombatBuffAlert() skips ScanCombatRaidBuffStatus()
--       when disabled, out of scope, trackCombatBrez is off, or out of combat.
--   (d) Closing DynamicSuiteMainFrame after a Search jump immediately hides
--       DynamicSuiteSearchHighlightFrame, clears _targetCard and OnUpdate, and
--       clears focus on railSearchBox.
-- Pure ASCII Only.
-- ============================================================================

local CORE_PATH   = "DynamicSuite/DynamicSuite_Core.lua"
local UI_PATH     = "DynamicSuite/DynamicSuite_UI.lua"
local CURSOR_PATH = "DynamicSuite/Modules/DynamicCursor.lua"
local PREP_PATH   = "DynamicSuite/Modules/DynamicPrep.lua"

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

local function CreateBaseEnv()
    local env = {}
    setmetatable(env, { __index = _G })
    env._G = env

    local state = {
        now = 500.0,
        inCombat = false,
        inPetBattle = false,
        inInstance = false,
        instType = "none",
        diffID = 0,
        cursorX = 800,
        cursorY = 500,
        spellTargeting = false,
        eventFrames = {},
        hooks = {},
        calls = {
            getInstanceInfo = 0,
            isInInstance = 0,
            spellIsTargeting = 0,
            tooltipSetOwner = 0,
            tooltipSetPoint = 0,
            tooltipClearAllPoints = 0,
        },
    }

    env.wipe = function(t) if type(t) == "table" then for k in pairs(t) do t[k] = nil end end; return t end
    env.tinsert = table.insert
    env.tremove = table.remove
    env.strtrim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
    env.strsplit = function(sep, str)
        local res = {}
        for part in string.gmatch(tostring(str or ""), "([^" .. sep .. "]+)") do table.insert(res, part) end
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
        for k, v in pairs(src) do dst[k] = env.CopyTable(v) end
        return dst
    end
    env.time = os.time
    env.date = os.date
    env.GetTime = function() return state.now end
    env.GetLocale = function() return "enUS" end
    env.GetScreenWidth = function() return 1920 end
    env.GetScreenHeight = function() return 1080 end
    env.GetCursorPosition = function() return state.cursorX, state.cursorY end
    env.InCombatLockdown = function() return state.inCombat end
    env.UnitAffectingCombat = function() return state.inCombat end
    env.IsShiftKeyDown = function() return false end
    env.IsControlKeyDown = function() return false end
    env.IsAltKeyDown = function() return false end
    env.IsMouseButtonDown = function() return false end
    env.UnitName = function() return "Dentee" end
    env.UnitGUID = function() return "Player-3725-00000001" end
    env.UnitClass = function() return "Mage", "MAGE", 8 end
    env.UnitLevel = function() return 80 end
    env.UnitExists = function(u) return u == "player" end
    env.UnitIsConnected = function() return true end
    env.UnitIsDeadOrGhost = function() return false end
    env.UnitIsGhost = function() return false end
    env.UnitInVehicle = function() return false end
    env.GetRealmName = function() return "Frostmourne" end
    env.GetInstanceInfo = function()
        state.calls.getInstanceInfo = state.calls.getInstanceInfo + 1
        return "", state.instType, state.diffID
    end
    env.IsInInstance = function()
        state.calls.isInInstance = state.calls.isInInstance + 1
        return state.inInstance, state.instType
    end
    env.SpellIsTargeting = function()
        state.calls.spellIsTargeting = state.calls.spellIsTargeting + 1
        return state.spellTargeting
    end
    env.IsInRaid = function() return false end
    env.IsInGroup = function() return false end
    env.GetNumGroupMembers = function() return 0 end
    env.GetNumSubgroupMembers = function() return 0 end
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
    env.C_Spell = { GetSpellName = function() return "Arcane Intellect" end, IsSpellUsable = function() return true, false end }
    env.GetSpellInfo = function() return "Arcane Intellect", nil, 135932 end
    env.C_Item = { GetItemCount = function() return 0 end, GetItemInfo = function() return nil end }
    env.GetItemCount = function() return 0 end
    env.C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemID = function() return nil end }
    env.C_Texture = { GetAtlasInfo = function() return nil end }
    env.C_UnitAuras = { GetAuraDataByIndex = function() return nil end }
    env.C_PetBattles = { IsInBattle = function() return state.inPetBattle end }
    env.C_EventUtils = { IsEventValid = function() return true end }
    env.C_CVar = { GetCVar = function() return "1" end, GetCVarBool = function() return false end, SetCVar = function() end, GetCVarDefault = function() return "1" end }
    env.C_AddOns = {
        GetAddOnMetadata = function() return "2.11.1" end,
        IsAddOnLoaded = function(name) return name == "DynamicSuite" or name == "DynamicCursor" or name == "DynamicPrep" end,
        GetAddOnInfo = function(name) return name, name, "", true, "INSECURE", false end,
        GetAddOnEnableState = function() return 2 end,
        GetNumAddOns = function() return 0 end,
    }
    env.GetNumAddOns = env.C_AddOns.GetNumAddOns
    env.C_Map = { GetMapInfo = function() return { name = "Dornogal" } end }
    env.C_Timer = {
        After = function() end,
        NewTimer = function() return { Cancel = function() end } end,
        NewTicker = function() return { Cancel = function() end } end,
    }
    env.RegisterStateDriver = function() end
    env.UnregisterStateDriver = function() end
    env.print = function() end

    env.GameTooltip_SetDefaultAnchor = function(tooltip, parent)
        if state.hooks["GameTooltip_SetDefaultAnchor"] then
            for _, fn in ipairs(state.hooks["GameTooltip_SetDefaultAnchor"]) do
                fn(tooltip, parent)
            end
        end
    end
    env.hooksecurefunc = function(tblOrName, nameOrFn, maybeFn)
        if type(tblOrName) == "string" and type(nameOrFn) == "function" then
            state.hooks[tblOrName] = state.hooks[tblOrName] or {}
            table.insert(state.hooks[tblOrName], nameOrFn)
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

    local function MakeMockFrame(ftype, name, parent)
        local f = {
            _type = ftype,
            _name = name,
            _parent = parent,
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
            _level = 5,
            _setPointCalls = 0,
            _clearAllPointsCalls = 0,
            _focused = false,
            _clearFocusCalls = 0,
            _forbidden = false,
        }
        if type(parent) == "table" and type(parent._children) == "table" then
            table.insert(parent._children, f)
        end
        function f:GetName() return self._name end
        function f:SetScript(ev, fn) self._scripts[ev] = fn end
        function f:HookScript(ev, fn)
            local prev = self._scripts[ev]
            self._scripts[ev] = function(...) if prev then prev(...) end; fn(...) end
        end
        function f:GetScript(ev) return self._scripts[ev] end
        function f:FireScript(ev, ...)
            if type(self._scripts[ev]) == "function" then return self._scripts[ev](self, ...) end
        end
        function f:RegisterEvent(ev) self._events[ev] = true end
        function f:RegisterUnitEvent(ev) self._events[ev] = true end
        function f:UnregisterEvent(ev) self._events[ev] = nil end
        function f:UnregisterAllEvents() self._events = {} end
        function f:Show() self._shown = true; self:FireScript("OnShow") end
        function f:Hide() self._shown = false; self:FireScript("OnHide") end
        function f:SetShown(b) if b then self:Show() else self:Hide() end end
        function f:IsShown() return self._shown == true end
        function f:IsVisible() return self._shown == true end
        function f:IsForbidden() return self._forbidden == true end
        function f:Raise() end
        function f:SetPoint(pt, relTo, relPt, x, y)
            self._setPointCalls = self._setPointCalls + 1
            table.insert(self._points, { pt, relTo, relPt, x, y })
        end
        function f:SetAllPoints() end
        function f:GetPoint(i) local p = self._points[i or 1]; if p then return unpack(p) end; return "CENTER", env.UIParent, "CENTER", 0, 0 end
        function f:ClearAllPoints()
            self._clearAllPointsCalls = self._clearAllPointsCalls + 1
            self._points = {}
        end
        function f:SetSize(w, h) self._w = w; self._h = h end
        function f:SetWidth(w) self._w = w end
        function f:SetHeight(h) self._h = h end
        function f:GetWidth() return self._w end
        function f:GetHeight() return self._h end
        function f:GetCenter() return 960, 540 end
        function f:SetScale(s) self._scale = s or 1.0 end
        function f:GetScale() return self._scale end
        function f:GetEffectiveScale() return self._scale end
        function f:SetAlpha(a) self._alpha = a or 1.0 end
        function f:GetAlpha() return self._alpha end
        function f:SetFrameStrata() end
        function f:SetFrameLevel(l) self._level = l end
        function f:GetFrameLevel() return self._level end
        function f:SetToplevel() end
        function f:SetClampedToScreen() end
        function f:SetClampRectInsets() end
        function f:SetClipsChildren() end
        function f:SetIgnoreParentAlpha() end
        function f:SetParent(p) self._parent = p end
        function f:GetParent() return self._parent or env.UIParent end
        function f:GetChildren() return unpack(self._children) end
        function f:EnableMouse() end
        function f:EnableMouseWheel() end
        function f:EnableKeyboard() end
        function f:SetMovable() end
        function f:SetResizable() end
        function f:SetResizeBounds() end
        function f:RegisterForDrag() end
        function f:RegisterForClicks() end
        function f:SetBackdrop() end
        function f:SetBackdropColor() end
        function f:SetBackdropBorderColor() end
        function f:SetAttribute(k, v) self._attrs[k] = v end
        function f:GetAttribute(k) return self._attrs[k] end
        function f:SetFocus() self._focused = true end
        function f:ClearFocus() self._focused = false; self._clearFocusCalls = self._clearFocusCalls + 1 end
        function f:HasFocus() return self._focused == true end
        function f:SetAutoFocus() end
        function f:SetMultiLine() end
        function f:SetTextInsets() end
        function f:SetMaxLetters() end
        function f:SetText(t) self._text = tostring(t or "") end
        function f:GetText() return self._text or "" end
        function f:SetFont() return true end
        function f:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
        function f:SetShadowColor() end
        function f:SetShadowOffset() end
        function f:SetTextColor() end
        function f:SetJustifyH() end
        function f:SetJustifyV() end
        function f:SetWordWrap() end
        function f:SetDrawEdge() end
        function f:SetDrawBling() end
        function f:SetDrawSwipe() end
        function f:SetHideCountdownNumbers() end
        function f:SetSwipeTexture() end
        function f:SetSwipeColor() end
        function f:SetReverse() end
        function f:SetCooldown() end
        function f:Clear() end
        function f:SetEnabled() end
        function f:IsEnabled() return true end
        function f:Enable() end
        function f:Disable() end
        function f:SetScrollChild() end
        function f:SetVerticalScroll() end
        function f:GetVerticalScroll() return 0 end
        function f:GetVerticalScrollRange() return 0 end
        function f:UpdateScrollChildRect() end
        function f:SetOrientation() end
        function f:SetMinMaxValues() end
        function f:SetValueStep() end
        function f:SetObeyStepOnDrag() end
        function f:SetValue(v) self._val = v end
        function f:GetValue() return self._val or 1 end
        function f:SetThumbTexture(t) self._thumb = t end
        function f:GetThumbTexture() return self._thumb or self:CreateTexture() end
        function f:SetNormalFontObject() end
        function f:SetHighlightTexture() end
        function f:SetNormalTexture() end
        function f:SetPushedTexture() end
        function f:SetSpacing() end
        function f:SetMaxLines() end
        function f:SetNonSpaceWrap() end
        function f:GetStringHeight() return 14 end
        function f:GetUnboundedStringWidth() return #(self._text or "") * 6 end
        function f:GetRegions() return end
        function f:IsMouseOver() return false end
        function f:GetObjectType() return self._type or "Frame" end
        function f:GetLeft() return 200 end
        function f:GetRight() return 200 + (self._w or 100) end
        function f:GetTop() return 100 + (self._h or 30) end
        function f:GetBottom() return 100 end
        function f:SetPropagateKeyboardInput() end
        function f:GetBackdropColor() return 0, 0, 0, 1 end
        function f:GetBackdropBorderColor() return 1, 1, 1, 1 end
        function f:GetFontString() return nil end
        function f:StartMoving() end
        function f:StopMovingOrSizing() end
        function f:StartSizing() end
        function f:SetMinResize() end
        function f:SetMaxResize() end
        function f:SetHitRectInsets() end
        function f:SetCursorPosition() end
        function f:HighlightText() end
        function f:SetFontObject() end
        function f:CreateAnimationGroup()
            return {
                CreateAnimation = function()
                    return { SetDuration = function() end, SetOrder = function() end, SetFromAlpha = function() end, SetToAlpha = function() end }
                end,
                SetScript = function() end,
                Play = function() end,
                Pause = function() end,
                Stop = function() end,
            }
        end
        function f:CreateTexture()
            local tex = MakeMockFrame("Texture", nil, self)
            function tex:SetColorTexture() end
            function tex:SetTexture(t) self._tex = t end
            function tex:GetTexture() return self._tex end
            function tex:SetVertexColor() end
            function tex:SetTexCoord() end
            function tex:SetBlendMode() end
            function tex:SetDesaturated() end
            function tex:SetAtlas() end
            function tex:SetRotation() end
            function tex:SetSnapToPixelGrid() end
            function tex:SetTexelSnappingBias() end
            return tex
        end
        function f:CreateFontString()
            local fs = MakeMockFrame("FontString", nil, self)
            function fs:GetStringWidth() return #(self._text or "") * 6 end
            return fs
        end
        if name then env[name] = f end
        return f
    end

    env.UIParent = MakeMockFrame("Frame", "UIParent", nil)
    env.UIParent:SetSize(1920, 1080)
    env.DEFAULT_CHAT_FRAME = { AddMessage = function() end }

    local gt = MakeMockFrame("GameTooltip", "GameTooltip", env.UIParent)
    function gt:SetOwner()
        state.calls.tooltipSetOwner = state.calls.tooltipSetOwner + 1
    end
    local origGTSetPoint = gt.SetPoint
    function gt:SetPoint(...)
        state.calls.tooltipSetPoint = state.calls.tooltipSetPoint + 1
        return origGTSetPoint(self, ...)
    end
    local origGTClear = gt.ClearAllPoints
    function gt:ClearAllPoints()
        state.calls.tooltipClearAllPoints = state.calls.tooltipClearAllPoints + 1
        return origGTClear(self)
    end
    env.GameTooltip = gt

    env.CreateFrame = function(ftype, name, parent)
        local fr = MakeMockFrame(ftype, name, parent)
        table.insert(state.eventFrames, fr)
        return fr
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

local function LoadChunk(path, env, addonName, sharedTbl)
    local chunk, err = loadfile(path)
    assertTrue(chunk ~= nil, "Failed to load " .. path .. ": " .. tostring(err))
    setfenv(chunk, env)
    return chunk(addonName, sharedTbl)
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

-- (a) DynamicCursor OnCursorUpdate: 0 GetInstanceInfo/IsInInstance/SpellIsTargeting per frame & skips SetPoint when stationary
RunTest("(a) DynamicCursor OnCursorUpdate zero per-frame API spam & skips SetPoint when stationary", function()
    local env, state = CreateBaseEnv()
    local sharedTbl = {}
    LoadChunk(CORE_PATH, env, "DynamicSuite", sharedTbl)
    LoadChunk(CURSOR_PATH, env, "DynamicSuite", sharedTbl)

    state.FireEvent("ADDON_LOADED", "DynamicSuite")
    state.FireEvent("PLAYER_LOGIN")
    env.DynamicCursorDB.ringEnabled = true
    env.DynamicCursor.SyncAllEngines()

    local ring = env.DynamicCursorRingFrame
    assertTrue(ring ~= nil, "DynamicCursorRingFrame created")

    -- Find the activeUpdateFrame carrying OnCursorUpdate
    local updateFrame = nil
    for _, fr in ipairs(state.eventFrames) do
        if type(fr._scripts.OnUpdate) == "function" then
            updateFrame = fr
            break
        end
    end
    assertTrue(updateFrame ~= nil, "DynamicCursor OnCursorUpdate active after PLAYER_LOGIN")

    -- Reset counters after init, then run 10 frames at initial position (1st frame positions, frames 2-10 stationary)
    state.calls.getInstanceInfo = 0
    state.calls.isInInstance = 0
    state.calls.spellIsTargeting = 0
    ring._setPointCalls = 0
    ring._clearAllPointsCalls = 0

    updateFrame:FireScript("OnUpdate", 0.016)
    assertEqual(ring._setPointCalls, 1, "Initial frame positions ring once")
    for _ = 1, 9 do
        state.now = state.now + 0.016
        updateFrame:FireScript("OnUpdate", 0.016)
    end

    assertEqual(state.calls.getInstanceInfo, 0, "0 GetInstanceInfo calls inside OnCursorUpdate")
    assertEqual(state.calls.isInInstance, 0, "0 IsInInstance calls inside OnCursorUpdate")
    assertEqual(state.calls.spellIsTargeting, 0, "0 SpellIsTargeting calls inside OnCursorUpdate")
    assertEqual(ring._setPointCalls, 1, "No redundant SetPoint calls while cursor is stationary")
    assertEqual(ring._clearAllPointsCalls, 1, "No redundant ClearAllPoints calls while cursor is stationary")

    -- Moving cursor repositions ring once
    state.cursorX = 850
    updateFrame:FireScript("OnUpdate", 0.016)
    assertEqual(ring._setPointCalls, 2, "Moving cursor updates ring position once")

    -- CURRENT_SPELL_CAST_CHANGED updates ground targeting without OnUpdate polling
    state.spellTargeting = true
    state.FireEvent("CURRENT_SPELL_CAST_CHANGED")
    assertEqual(state.calls.spellIsTargeting, 1, "SpellIsTargeting queried only via CURRENT_SPELL_CAST_CHANGED")
end)

-- (b) DynamicCursor GameTooltip_SetDefaultAnchor hook never calls tooltip:SetOwner recursively
RunTest("(b) DynamicCursor GameTooltip_SetDefaultAnchor never calls SetOwner and skips forbidden tooltips", function()
    local env, state = CreateBaseEnv()
    local sharedTbl = {}
    LoadChunk(CORE_PATH, env, "DynamicSuite", sharedTbl)
    LoadChunk(CURSOR_PATH, env, "DynamicSuite", sharedTbl)

    state.FireEvent("ADDON_LOADED", "DynamicSuite")
    state.FireEvent("PLAYER_LOGIN")
    env.DynamicCursorDB.tooltipEnabled = true
    env.DynamicCursor.SyncAllEngines()

    state.calls.tooltipSetOwner = 0
    state.calls.tooltipSetPoint = 0
    state.calls.tooltipClearAllPoints = 0
    state.inCombat = true

    env.GameTooltip_SetDefaultAnchor(env.GameTooltip, env.UIParent)
    assertEqual(state.calls.tooltipSetOwner, 0, "SmartTooltip hook never calls tooltip:SetOwner")
    assertEqual(state.calls.tooltipClearAllPoints, 1, "SmartTooltip hook clears points once")
    assertEqual(state.calls.tooltipSetPoint, 1, "SmartTooltip hook sets point once")

    -- Forbidden tooltip is skipped safely
    env.GameTooltip._forbidden = true
    env.GameTooltip_SetDefaultAnchor(env.GameTooltip, env.UIParent)
    assertEqual(state.calls.tooltipSetPoint, 1, "Forbidden tooltip is not repositioned")
end)

-- (c) DynamicPrep:RefreshCombatBuffAlert() skips ScanCombatRaidBuffStatus() when disabled / out of scope / trackCombatBrez off / OOC
RunTest("(c) DynamicPrep:RefreshCombatBuffAlert() gates ScanCombatRaidBuffStatus() before scanning raid", function()
    local env, state = CreateBaseEnv()
    local sharedTbl = {}
    LoadChunk(CORE_PATH, env, "DynamicSuite", sharedTbl)
    LoadChunk(PREP_PATH, env, "DynamicSuite", sharedTbl)

    state.FireEvent("ADDON_LOADED", "DynamicSuite")
    state.FireEvent("ADDON_LOADED", "DynamicPrep")

    local dp = env.DynamicPrep
    assertTrue(dp ~= nil, "DynamicPrep loaded")
    local scanCalls = 0
    local origScan = dp.ScanCombatRaidBuffStatus
    dp.ScanCombatRaidBuffStatus = function(selfObj, exp)
        scanCalls = scanCalls + 1
        return origScan(selfObj, exp)
    end

    -- 1. Out of combat -> skipped
    state.inCombat = false
    dp.db.raidBuffs.enabled = true
    dp.db.raidBuffs.scope = "ALWAYS"
    dp.db.raidBuffs.trackClassBuffs = true
    dp.db.raidBuffs.trackCombatBrez = true
    dp:RefreshCombatBuffAlert()
    assertEqual(scanCalls, 0, "OOC skips ScanCombatRaidBuffStatus")

    -- 2. In combat, raidBuffs.enabled = false -> skipped
    state.inCombat = true
    dp.db.raidBuffs.enabled = false
    dp:RefreshCombatBuffAlert()
    assertEqual(scanCalls, 0, "raidBuffs.enabled=false skips ScanCombatRaidBuffStatus in combat")

    -- 3. In combat, out of scope (INST_ONLY outdoors) -> skipped
    dp.db.raidBuffs.enabled = true
    dp.db.raidBuffs.scope = "INST_ONLY"
    state.inInstance = false
    state.instType = "none"
    dp:RefreshCombatBuffAlert()
    assertEqual(scanCalls, 0, "INST_ONLY outdoors skips ScanCombatRaidBuffStatus in combat")

    -- 4. In combat, trackCombatBrez = false -> skipped
    dp.db.raidBuffs.scope = "ALWAYS"
    dp.db.raidBuffs.trackCombatBrez = false
    dp:RefreshCombatBuffAlert()
    assertEqual(scanCalls, 0, "trackCombatBrez=false skips ScanCombatRaidBuffStatus in combat")

    -- 5. In combat, trackClassBuffs = false -> skipped
    dp.db.raidBuffs.trackCombatBrez = true
    dp.db.raidBuffs.trackClassBuffs = false
    dp:RefreshCombatBuffAlert()
    assertEqual(scanCalls, 0, "trackClassBuffs=false skips ScanCombatRaidBuffStatus in combat")

    -- 6. In combat, enabled + valid scope + flags on -> scans once
    dp.db.raidBuffs.trackClassBuffs = true
    dp:RefreshCombatBuffAlert()
    assertEqual(scanCalls, 1, "Valid combat scope scans once")
end)

-- (d) Closing DynamicSuiteMainFrame after a Search jump immediately hides DynamicSuiteSearchHighlightFrame & clears OnUpdate/focus
RunTest("(d) DynamicSuiteMainFrame OnHide stops DynamicSuiteSearchHighlightFrame & clears railSearchBox focus", function()
    local env, state = CreateBaseEnv()
    -- Minimal additional stubs needed to instantiate DynamicSuiteMainFrame
    env.GetPhysicalScreenSize = function() return 1920, 1080 end
    env.GetAddOnMetadata = env.C_AddOns.GetAddOnMetadata
    env.GetAddOnInfo = env.C_AddOns.GetAddOnInfo
    env.C_AddOns.GetAddOnDependencies = function() return end
    env.C_AddOns.GetAddOnOptionalDependencies = function() return end
    env.Enum = { FontAlphabet = { Roman = 0 } }
    env.CreateFont = function(n)
        local fo = { _name = n }
        function fo:SetFont() return true end
        function fo:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
        function fo:SetTextColor() end
        function fo:SetShadowColor() end
        function fo:SetShadowOffset() end
        return fo
    end
    env.StaticPopupDialogs = {}

    local sharedTbl = {}
    LoadChunk(CORE_PATH, env, "DynamicSuite", sharedTbl)
    LoadChunk(UI_PATH, env, "DynamicSuite", sharedTbl)

    state.FireEvent("ADDON_LOADED", "DynamicSuite")

    -- Create the real main frame and simulate an active search highlight jump
    local mainFrame = env.DynamicSuite.CreateMainConfigUI and env.DynamicSuite.CreateMainConfigUI()
        or (sharedTbl.CreateMainConfigUI and sharedTbl.CreateMainConfigUI())
        or env.DynamicSuiteMainFrame
    assertTrue(mainFrame ~= nil, "DynamicSuiteMainFrame created")
    mainFrame:Show()

    -- Create a mock target card containing a matching FontString inside a shown root
    local card = env.CreateFrame("Frame", nil, mainFrame)
    card:Show()
    local label = card:CreateFontString()
    label:SetText("Cursor Ring Style")
    card.GetRegions = function() return label end

    assertTrue(type(sharedTbl.JumpAndHighlightCard) == "function", "JumpAndHighlightCard exposed")
    sharedTbl.JumpAndHighlightCard(mainFrame, "Cursor Ring Style")

    local hl = env.DynamicSuiteSearchHighlightFrame
    assertTrue(hl ~= nil and hl:IsShown(), "DynamicSuiteSearchHighlightFrame shown after Search jump")
    assertTrue(hl._targetCard ~= nil, "Highlight frame tracks _targetCard while shown")
    assertTrue(type(hl:GetScript("OnUpdate")) == "function", "Highlight OnUpdate active while shown")

    if mainFrame.railSearchBox then
        mainFrame.railSearchBox:SetFocus()
        assertTrue(mainFrame.railSearchBox:HasFocus(), "railSearchBox focused before close")
    end

    -- Close DynamicSuiteMainFrame -> highlight must immediately hide and clear OnUpdate/_targetCard + railSearchBox loses focus
    mainFrame:Hide()
    assertTrue(not hl:IsShown(), "DynamicSuiteSearchHighlightFrame hidden immediately on MainFrame OnHide")
    assertEqual(hl._targetCard, nil, "_targetCard cleared on MainFrame OnHide")
    assertEqual(hl:GetScript("OnUpdate"), nil, "Highlight OnUpdate cleared on MainFrame OnHide")
    if mainFrame.railSearchBox then
        assertTrue(not mainFrame.railSearchBox:HasFocus(), "railSearchBox focus cleared on MainFrame OnHide")
    end
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
