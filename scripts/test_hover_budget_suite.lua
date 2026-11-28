-- ============================================================================
-- Headless Lua 5.1 Regression Suite: Suite-Wide Mouseover / Tooltip Hover Budget
-- Permanent per-hover guard. Simulates 100+ rapid hovers over world units,
-- raid frames, nameplates, bag items and Premade Group Finder rows and asserts:
--   (A) DynamicGroup: LFGListUtil_SetSearchEntryTooltip, LFGListSearchEntry_OnEnter
--       and LFGListSearchEntryMixin.OnEnter make 0 C_LFGList / C_MythicPlus /
--       IsAddOnLoaded calls and 0 cache rebuilds on repeat hovers; the per-search
--       cache is invalidated only by LFG_LIST_SEARCH_RESULT_UPDATED,
--       LFG_LIST_SEARCH_RESULTS_RECEIVED, DoSearch and Clear; closed panel / combat = 0 work.
--   (B) DynamicTalent: UPDATE_MOUSEOVER_UNIT / NAME_PLATE_UNIT_ADDED /
--       PLAYER_SOFT_ENEMY_CHANGED exit before UnitName / UnitGUID / Encounter
--       Journal / loadout work in combat, while resting, on players, outdoors and
--       with no boss binds.
--   (C) DynamicBags: the Item TooltipDataProcessor post-call makes 0 C_Container
--       calls, builds the count index once and allocates (near) nothing per hover.
--   (D) DynamicCursor: GameTooltip_SetDefaultAnchor exits in O(1) when Smart
--       Cursor Tooltips is off or the module is disabled.
--   (E) Static inventory of every global tooltip / mouseover hook across all 15
--       Lua files so a new hook cannot slip in without an explicit audit.
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


-- ============================================================================
-- Shared hover-budget helpers
-- ============================================================================
local HOVERS = 100

local function NewCounters()
    return setmetatable({}, { __index = function() return 0 end })
end

local function SumCounters(c)
    local n = 0
    for _, v in pairs(c) do n = n + v end
    return n
end

local function ResetCounters(c)
    for k in pairs(c) do c[k] = nil end
end

-- Wrap env.<path> (dotted) with a call counter. Must run before the module under test loads.
local function Spy(env, counters, path)
    local parts = {}
    for p in path:gmatch("[^%.]+") do parts[#parts + 1] = p end
    local tbl = env
    for i = 1, #parts - 1 do
        tbl = tbl[parts[i]]
        if type(tbl) ~= "table" then return false end
    end
    local key = parts[#parts]
    local orig = tbl[key]
    if type(orig) ~= "function" then return false end
    tbl[key] = function(...)
        counters[path] = counters[path] + 1
        return orig(...)
    end
    return true
end

-- Bytes allocated by fn() with the collector stopped (a deterministic allocation probe).
local function MeasureAlloc(fn)
    collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    fn()
    local after = collectgarbage("count")
    collectgarbage("restart")
    return (after - before) * 1024
end

local function ReadFile(path)
    local fh = io.open(path, "rb")
    assertTrue(fh ~= nil, "Unable to open " .. path)
    local data = fh:read("*a")
    fh:close()
    return data
end

-- ============================================================================
-- (D) DynamicCursor GameTooltip_SetDefaultAnchor O(1) exits
-- ============================================================================
RunTest("(D) DynamicCursor GameTooltip_SetDefaultAnchor exits in O(1) when Smart Cursor Tooltips is off or the module is disabled", function()
    local env, state = CreateBaseEnv()
    local counters = NewCounters()
    local sharedTbl = {}
    Spy(env, counters, "GetCursorPosition")
    Spy(env, counters, "GetScreenWidth")
    Spy(env, counters, "GetScreenHeight")
    LoadChunk(CORE_PATH, env, "DynamicSuite", sharedTbl)
    LoadChunk(CURSOR_PATH, env, "DynamicSuite", sharedTbl)
    state.FireEvent("ADDON_LOADED", "DynamicSuite")
    state.FireEvent("PLAYER_LOGIN")

    local scaleCalls = 0
    local origScale = env.UIParent.GetEffectiveScale
    env.UIParent.GetEffectiveScale = function(self, ...)
        scaleCalls = scaleCalls + 1
        return origScale(self, ...)
    end

    -- Install the hook once, then turn the feature off again (hook stays installed in the real client).
    env.DynamicCursorDB.tooltipEnabled = true
    env.DynamicCursor.SyncAllEngines()
    env.DynamicCursorDB.tooltipEnabled = false

    local function ResetAll()
        ResetCounters(counters)
        scaleCalls = 0
        state.calls.tooltipSetOwner = 0
        state.calls.tooltipSetPoint = 0
        state.calls.tooltipClearAllPoints = 0
    end

    ResetAll()
    for _ = 1, HOVERS do env.GameTooltip_SetDefaultAnchor(env.GameTooltip, env.UIParent) end
    assertEqual(SumCounters(counters), 0, "tooltipEnabled=false: 0 cursor/screen queries across 100 hovers")
    assertEqual(scaleCalls, 0, "tooltipEnabled=false: 0 GetEffectiveScale queries")
    assertEqual(state.calls.tooltipSetPoint + state.calls.tooltipClearAllPoints + state.calls.tooltipSetOwner, 0,
        "tooltipEnabled=false: 0 tooltip layout calls")

    -- Module soft-disabled in the suite: still O(1) even though tooltipEnabled is true.
    env.DynamicCursorDB.tooltipEnabled = true
    env.DynamicSuiteDB = env.DynamicSuiteDB or { global = {} }
    env.DynamicSuiteDB.global = env.DynamicSuiteDB.global or {}
    env.DynamicSuiteDB.global.disabledModules = env.DynamicSuiteDB.global.disabledModules or {}
    env.DynamicSuiteDB.global.disabledModules.DynamicCursor = true
    env.DynamicSuiteDB.global.disabledModules.cursor = true
    env.DynamicCursor.SyncAllEngines()
    ResetAll()
    for _ = 1, HOVERS do env.GameTooltip_SetDefaultAnchor(env.GameTooltip, env.UIParent) end
    assertEqual(SumCounters(counters), 0, "module disabled: 0 cursor/screen queries across 100 hovers")
    assertEqual(scaleCalls, 0, "module disabled: 0 GetEffectiveScale queries")
    assertEqual(state.calls.tooltipSetPoint + state.calls.tooltipClearAllPoints, 0, "module disabled: 0 tooltip layout calls")

    -- Feature on: exactly one reposition per hover, never a recursive SetOwner.
    env.DynamicSuiteDB.global.disabledModules.DynamicCursor = nil
    env.DynamicSuiteDB.global.disabledModules.cursor = nil
    env.DynamicCursor.SyncAllEngines()
    ResetAll()
    for _ = 1, HOVERS do env.GameTooltip_SetDefaultAnchor(env.GameTooltip, env.UIParent) end
    assertEqual(state.calls.tooltipSetPoint, HOVERS, "enabled: exactly one SetPoint per hover")
    assertEqual(state.calls.tooltipClearAllPoints, HOVERS, "enabled: exactly one ClearAllPoints per hover")
    assertEqual(state.calls.tooltipSetOwner, 0, "enabled: never SetOwner")
    assertEqual(counters.GetCursorPosition, HOVERS, "enabled: one cursor read per hover")
end)

-- ============================================================================
-- (E) Static inventory of every global tooltip / mouseover hook in all 15 Lua files
-- ============================================================================
RunTest("(E) Global tooltip / mouseover hook inventory is exactly the audited set across all 15 Lua files", function()
    local files = {
        "DynamicSuite/DynamicSuite_Core.lua",
        "DynamicSuite/DynamicSuite_UI.lua",
        "DynamicSuite/Modules/DynamicBags.lua",
        "DynamicSuite/Modules/DynamicChat.lua",
        "DynamicSuite/Modules/DynamicCursor.lua",
        "DynamicSuite/Modules/DynamicDialogue.lua",
        "DynamicSuite/Modules/DynamicFPS.lua",
        "DynamicSuite/Modules/DynamicGroup.lua",
        "DynamicSuite/Modules/DynamicLoad.lua",
        "DynamicSuite/Modules/DynamicMail.lua",
        "DynamicSuite/Modules/DynamicMarker.lua",
        "DynamicSuite/Modules/DynamicPrep.lua",
        "DynamicSuite/Modules/DynamicTalent.lua",
        "DynamicSuite/Modules/DynamicVault.lua",
        "DynamicSuite/Modules/DynamicZoom.lua",
    }
    assertEqual(#files, 15, "15 Lua files audited")

    -- Plain-text patterns (no changelog prose can match: each needs call syntax).
    local patterns = {
        { key = "AddTooltipPostCall",       needle = "TooltipDataProcessor.AddTooltipPostCall(" },
        { key = "SetDefaultAnchor",         needle = 'hooksecurefunc("GameTooltip_SetDefaultAnchor"' },
        { key = "OnTooltipSet",             needle = 'HookScript("OnTooltipSet' },
        { key = "OnTooltipSetScript",       needle = 'SetScript("OnTooltipSet' },
        { key = "MouseoverEventRegister",   needle = '"UPDATE_MOUSEOVER_UNIT")' },
        { key = "SearchEntryTooltip",       needle = 'hooksecurefunc("LFGListUtil_SetSearchEntryTooltip"' },
        { key = "SearchEntryOnEnterGlobal", needle = 'hooksecurefunc("LFGListSearchEntry_OnEnter"' },
        { key = "SearchEntryOnEnterMixin",  needle = 'hooksecurefunc(_G.LFGListSearchEntryMixin, "OnEnter"' },
        { key = "GameTooltipHook",          needle = "hooksecurefunc(GameTooltip," },
        { key = "GameTooltipHookG",         needle = "hooksecurefunc(_G.GameTooltip," },
        { key = "GameTooltipHookScript",    needle = "GameTooltip:HookScript(" },
        { key = "GameTooltipSetScript",     needle = "GameTooltip:SetScript(" },
    }
    -- Audited, reviewed-for-cost set. Anything else is a NEW hover hook and must be budgeted + added here.
    local expected = {
        ["DynamicSuite/Modules/DynamicBags.lua"]   = { AddTooltipPostCall = 1 },
        ["DynamicSuite/Modules/DynamicCursor.lua"] = { SetDefaultAnchor = 1 },
        ["DynamicSuite/Modules/DynamicTalent.lua"] = { MouseoverEventRegister = 1 },
        ["DynamicSuite/Modules/DynamicGroup.lua"]  = { SearchEntryTooltip = 1, SearchEntryOnEnterGlobal = 1, SearchEntryOnEnterMixin = 1 },
    }

    for _, path in ipairs(files) do
        local src = ReadFile(path)
        local exp = expected[path] or {}
        for _, p in ipairs(patterns) do
            local count, from = 0, 1
            while true do
                local s, e = src:find(p.needle, from, true)
                if not s then break end
                count = count + 1
                from = e + 1
            end
            assertEqual(count, exp[p.key] or 0, string.format("%s: '%s' occurrence count (audited hover-hook inventory)", path, p.key))
        end
    end
end)

-- ============================================================================
-- (A) DynamicGroup: Premade Group Finder row hover budget
-- ============================================================================
local GROUP_PATH = "DynamicSuite/Modules/DynamicGroup.lua"

local function CreateGroupHover()
    local env, state = CreateBaseEnv()
    local counters = NewCounters()
    local sharedTbl = {}
    local results = {}
    local ROLE_BY_SLOT = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" }
    local CLASS_BY_SLOT = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "HUNTER" }

    env.C_LFGList = {
        HasSearchResultInfo = function(id) return results[id] ~= nil end,
        GetSearchResultInfo = function(id) return results[id] end,
        GetSearchResultPlayerInfo = function(id, i)
            local r = results[id]
            if not r or i > r.numMembers then return nil end
            return { assignedRole = ROLE_BY_SLOT[i], classFilename = CLASS_BY_SLOT[i], name = "Pl" .. i, isLeader = (i == 1) }
        end,
        GetSearchResultMemberInfo = function(id, i) return ROLE_BY_SLOT[i], CLASS_BY_SLOT[i] end,
        GetActivityInfoTable = function()
            return { categoryID = 2, mapChallengeModeID = 399, fullName = "Ruby Life Pools (Mythic Keystone)",
                shortName = "Mythic Keystone", isMythicPlusActivity = true }
        end,
        GetApplicationInfo = function(id) return id, "none" end,
        HasActiveEntryInfo = function() return false end,
        GetActiveEntryInfo = function() return nil end,
    }
    env.C_MythicPlus = {
        GetSeasonBestAffixScoreInfoForMap = function() return { { level = 12, overTime = false } }, 2000 end,
        GetSeasonBestForMap = function() return { level = 12, dungeonScore = 250 }, nil end,
        RequestMapInfo = function() end,
    }
    env.C_ChallengeMode = env.C_ChallengeMode or {}
    env.C_ChallengeMode.IsChallengeModeActive = env.C_ChallengeMode.IsChallengeModeActive or function() return false end
    for i = 1, 20 do
        results[i] = { searchResultID = i, activityIDs = { 1170 }, name = "+12 chill " .. i,
            leaderName = "Leader" .. i .. "-Frostmourne", numMembers = 3, maxMembers = 5,
            leaderOverallDungeonScore = 2500, isDelisted = false }
    end

    local lfg = env.CreateFrame("Frame", "LFGListFrame", env.UIParent)
    lfg.SearchPanel = env.CreateFrame("Frame", nil, lfg)
    lfg.SearchPanel:Show()
    lfg.EntryCreation = env.CreateFrame("Frame", nil, lfg)
    env.LFGListFrame = lfg
    env.LFGListSearchEntry_Update = function() end
    env.LFGListSearchPanel_UpdateResultList = function() end
    env.LFGListSearchPanel_DoSearch = function() end
    env.LFGListSearchPanel_Clear = function() end
    env.LFGListSearchPanel_SetCategory = function() end
    env.LFGListSearchEntry_OnEnter = function() end
    env.LFGListSearchEntry_OnClick = function() end
    env.LFGListUtil_SetSearchEntryTooltip = function() end
    env.LFGListSearchEntryMixin = { OnEnter = function() end, OnClick = function() end }

    Spy(env, counters, "C_LFGList.HasSearchResultInfo")
    Spy(env, counters, "C_LFGList.GetSearchResultInfo")
    Spy(env, counters, "C_LFGList.GetSearchResultPlayerInfo")
    Spy(env, counters, "C_LFGList.GetSearchResultMemberInfo")
    Spy(env, counters, "C_LFGList.GetActivityInfoTable")
    Spy(env, counters, "C_MythicPlus.GetSeasonBestAffixScoreInfoForMap")
    Spy(env, counters, "C_MythicPlus.GetSeasonBestForMap")
    Spy(env, counters, "C_AddOns.IsAddOnLoaded")

    env.DynamicGroupDB = { lfgFilterEnabled = true, oneClickSignUp = true }
    LoadChunk(CORE_PATH, env, "DynamicSuite", sharedTbl)
    LoadChunk(GROUP_PATH, env, "DynamicSuite", sharedTbl)
    state.FireEvent("ADDON_LOADED", "DynamicSuite")
    state.FireEvent("PLAYER_LOGIN")
    env.DynamicGroupDB.lfgFilterEnabled = true
    env.DynamicGroup:InstallLFGHooks()

    local tip = { lines = 0 }
    function tip.IsForbidden() return false end
    function tip.AddDoubleLine(self) self.lines = self.lines + 1 end
    function tip.Show() end

    local h = { env = env, state = state, counters = counters, results = results, tip = tip, lfg = lfg }
    function h.Hover(entry)
        for _, fn in ipairs(state.hooks["LFGListSearchEntry_OnEnter"] or {}) do fn(entry) end
        env.LFGListSearchEntryMixin.OnEnter(entry)
    end
    function h.Tip(id)
        for _, fn in ipairs(state.hooks["LFGListUtil_SetSearchEntryTooltip"] or {}) do fn(tip, id) end
    end
    function h.Builds() local b = env.DynamicGroup:GetSearchResultCacheStats(); return b end
    function h.Hook(name, ...)
        for _, fn in ipairs(state.hooks[name] or {}) do fn(...) end
    end
    return h
end

RunTest("(A1) DynamicGroup LFG row hover: 100 repeat hovers make 0 C_LFGList / C_MythicPlus calls and 0 cache rebuilds", function()
    local h = CreateGroupHover()
    assertTrue(#(h.state.hooks["LFGListUtil_SetSearchEntryTooltip"] or {}) == 1, "tooltip hook installed")
    assertTrue(#(h.state.hooks["LFGListSearchEntry_OnEnter"] or {}) == 1, "OnEnter global hook installed")

    -- Warm the per-search cache once per row (first hover legitimately queries C_LFGList).
    local b0 = h.Builds()
    for id = 1, 20 do h.Hover({ resultID = id }); h.Tip(id) end
    assertEqual(h.Builds() - b0, 20, "first hover over each of 20 rows builds exactly once")
    assertEqual(h.tip.lines, 20 * 4, "tooltip gets region/utility/best/class lines on first hover")

    ResetCounters(h.counters)
    h.tip.lines = 0
    local b1 = h.Builds()
    for i = 1, HOVERS do
        local id = ((i - 1) % 20) + 1
        h.Hover({ resultID = id })
        h.Tip(id)
    end
    assertEqual(SumCounters(h.counters), 0, "0 C_LFGList / C_MythicPlus / IsAddOnLoaded calls across 100 repeat hovers")
    assertEqual(h.Builds() - b1, 0, "0 cache rebuilds across 100 repeat hovers")
    assertEqual(h.tip.lines, HOVERS * 4, "cached tooltip still renders all four extra lines on every hover")

    -- Pre-built entry rows so the probe only sees allocations made by the hover hooks themselves.
    local entries = {}
    for id = 1, 20 do entries[id] = { resultID = id } end
    local bytes = MeasureAlloc(function()
        for i = 1, HOVERS do
            local id = ((i - 1) % 20) + 1
            h.Hover(entries[id])
            h.Tip(id)
        end
    end)
    assertTrue(bytes < 1024, string.format("100 cached hovers allocate < 1 KB (actual %.0f B)", bytes))
end)

RunTest("(A2) DynamicGroup search cache invalidates only on RESULT_UPDATED / RESULTS_RECEIVED / DoSearch / Clear", function()
    local h = CreateGroupHover()
    for id = 1, 20 do h.Tip(id) end
    local b0 = h.Builds()

    -- Unrelated traffic never invalidates.
    for _ = 1, 10 do h.Hover({ resultID = 3 }); h.Tip(3) end
    h.env.DynamicGroup:IsYieldingSharedHooks()
    h.state.FireEvent("GROUP_ROSTER_UPDATE")
    for id = 1, 20 do h.Tip(id) end
    assertEqual(h.Builds() - b0, 0, "hovers / roster events do not rebuild")

    -- LFG_LIST_SEARCH_RESULT_UPDATED drops exactly that row.
    h.results[7].numMembers = 5
    h.state.FireEvent("LFG_LIST_SEARCH_RESULT_UPDATED", 7)
    for id = 1, 20 do h.Tip(id) end
    assertEqual(h.Builds() - b0, 1, "RESULT_UPDATED(7) rebuilds only row 7 (once, even across 20 more hovers)")

    -- In combat the handler returns early but must still drop the stale row.
    local b1 = h.Builds()
    h.state.inCombat = true
    h.results[9].numMembers = 4
    h.state.FireEvent("LFG_LIST_SEARCH_RESULT_UPDATED", 9)
    h.state.inCombat = false
    h.Tip(9)
    assertEqual(h.Builds() - b1, 1, "RESULT_UPDATED during combat still invalidates the row")

    -- New result set: everything is dropped.
    local b2 = h.Builds()
    h.state.FireEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    for id = 1, 20 do h.Tip(id) end
    assertEqual(h.Builds() - b2, 20, "RESULTS_RECEIVED invalidates all 20 rows")

    -- DoSearch / Clear / SetCategory hooks drop everything too.
    local b3 = h.Builds()
    h.Hook("LFGListSearchPanel_DoSearch", h.lfg.SearchPanel)
    for id = 1, 20 do h.Tip(id) end
    assertEqual(h.Builds() - b3, 20, "LFGListSearchPanel_DoSearch invalidates all rows")
    local b4 = h.Builds()
    h.Hook("LFGListSearchPanel_Clear", h.lfg.SearchPanel)
    for id = 1, 20 do h.Tip(id) end
    assertEqual(h.Builds() - b4, 20, "LFGListSearchPanel_Clear invalidates all rows")
end)

RunTest("(A3) DynamicGroup LFGListSearchEntry_OnEnter does zero work outside an open SearchPanel, in combat, or on cached rows", function()
    local h = CreateGroupHover()

    -- Closed panel + uncached row IDs: no C-API traffic at all.
    h.lfg.SearchPanel:Hide()
    ResetCounters(h.counters)
    for i = 1, HOVERS do h.Hover({ resultID = ((i - 1) % 20) + 1 }) end
    assertEqual(SumCounters(h.counters), 0, "closed SearchPanel: 0 API calls across 100 hovers")

    -- Open panel but in combat: still zero.
    h.lfg.SearchPanel:Show()
    ResetCounters(h.counters) -- Show() fires Group's own OnShow refresh; only hovers are budgeted
    h.state.inCombat = true
    for i = 1, HOVERS do h.Hover({ resultID = ((i - 1) % 20) + 1 }) end
    assertEqual(SumCounters(h.counters), 0, "in combat: 0 API calls across 100 hovers")
    h.state.inCombat = false

    -- Open panel: first hover per row confirms the ID once, repeats are free.
    for id = 1, 20 do h.Hover({ resultID = id }) end
    local first = SumCounters(h.counters)
    assertTrue(first > 0 and first <= 20 * 2, "first hover validates each row at most once (HasSearchResultInfo + GetSearchResultInfo)")
    ResetCounters(h.counters)
    for i = 1, HOVERS do h.Hover({ resultID = ((i - 1) % 20) + 1 }) end
    assertEqual(SumCounters(h.counters), 0, "open panel, validated rows: 0 API calls across 100 hovers")

    -- A genuinely stale row still hides the tooltip (feature preserved).
    local hidden = 0
    h.env.GameTooltip.IsOwned = function() return true end
    h.env.GameTooltip.Hide = function() hidden = hidden + 1 end
    h.Hover({ resultID = 777 })
    assertTrue(hidden >= 1, "stale row hover still hides the owned GameTooltip")
end)

RunTest("(A4) DynamicGroup yield-hook check reads IsAddOnLoaded once, not per hover", function()
    local h = CreateGroupHover()
    h.Tip(1) -- settle the one-off EnsureDB() so the flag below is not pruned as 'unloaded' by it
    h.env.DynamicGroupDB.yieldHooks = { SomeOtherGroupFinder = true }
    for id = 1, 20 do h.Hover({ resultID = id }); h.Tip(id) end
    ResetCounters(h.counters)
    for i = 1, HOVERS do
        local id = ((i - 1) % 20) + 1
        h.Hover({ resultID = id })
        h.Tip(id)
    end
    assertEqual(h.counters["C_AddOns.IsAddOnLoaded"], 0, "0 IsAddOnLoaded calls across 100 hovers once cached")
    -- A newly loaded addon must be noticed (cache resets on ADDON_LOADED).
    h.env.C_AddOns.IsAddOnLoaded = function(n) return n == "SomeOtherGroupFinder" end
    h.state.FireEvent("ADDON_LOADED", "SomeOtherGroupFinder")
    assertTrue(h.env.DynamicGroup:IsYieldingSharedHooks() == true, "yield state refreshes after ADDON_LOADED")
end)

-- ============================================================================
-- (B) DynamicTalent: UPDATE_MOUSEOVER_UNIT / NAME_PLATE_UNIT_ADDED / PLAYER_SOFT_ENEMY_CHANGED
-- ============================================================================
local TALENT_PATH = "DynamicSuite/Modules/DynamicTalent.lua"

local function CreateTalentHover()
    local env, state = CreateBaseEnv()
    local counters = NewCounters()
    local sharedTbl = {}
    local units = {}
    state.resting = false
    state.inRaid = false

    env.UnitExists = function(u)
        if u == "player" then return true end
        return units[u] ~= nil
    end
    env.UnitIsPlayer = function(u)
        if u == "player" then return true end
        return units[u] ~= nil and units[u].isPlayer == true
    end
    env.UnitIsDeadOrGhost = function() return false end
    env.UnitName = function(u)
        if u == "player" then return "Dentee" end
        return units[u] and units[u].name or nil
    end
    env.UnitGUID = function(u)
        if u == "player" then return "Player-3725-00000001" end
        return units[u] and units[u].guid or nil
    end
    env.IsResting = function() return state.resting end
    env.GetInstanceInfo = function() return "", state.instType, state.diffID end
    env.EJ_GetNumTiers = function() return 11 end
    env.EJ_GetCurrentTier = function() return 11 end
    env.EJ_SelectTier = function() end
    env.EJ_GetInstanceByIndex = function() return nil end
    env.EJ_SelectInstance = function() end
    env.EJ_GetEncounterInfoByIndex = function() return nil end
    env.C_ClassTalents = {
        GetActiveConfigID = function() return 1001 end,
        GetLastSelectedSavedConfigID = function() return 1001 end,
        GetConfigIDsBySpecID = function() return { 1001 } end,
        GetActiveHeroTalentSpec = function() return nil end,
    }
    env.C_Traits = { GenerateImportString = function() return "EXPORT_BUILD_DEFAULT" end }
    env.C_NamePlate = { GetNamePlates = function() return {} end }
    env.C_ChallengeMode = { IsChallengeModeActive = function() return false end }
    env.C_InstanceEncounter = { IsEncounterInProgress = function() return false end }
    env.C_PvP = { IsWarModeDesired = function() return false end, IsWarModeActive = function() return false end }
    env.IsEncounterInProgress = function() return false end
    env.DynamicPrep = { RefreshBar = function() end }

    for _, path in ipairs({
        "UnitExists", "UnitIsPlayer", "UnitName", "UnitGUID", "GetInstanceInfo", "IsResting",
        "EJ_GetNumTiers", "EJ_SelectTier", "EJ_GetInstanceByIndex", "EJ_GetEncounterInfoByIndex",
        "C_Traits.GenerateImportString", "C_NamePlate.GetNamePlates", "DynamicPrep.RefreshBar",
    }) do Spy(env, counters, path) end

    LoadChunk(CORE_PATH, env, "DynamicSuite", sharedTbl)
    LoadChunk(TALENT_PATH, env, "DynamicSuite", sharedTbl)
    state.FireEvent("ADDON_LOADED", "DynamicSuite")
    local dt = env.DynamicTalent
    assertTrue(dt ~= nil and dt.db ~= nil, "DynamicTalent initialised")
    dt.db.enabled = true
    dt.db.talentReminderEnabled = true
    dt.db.talentBossMap = {
        [62] = {
            ["vashnik the malignant"] = {
                bossName = "Vashnik the Malignant", raidName = "The Venomous Abyss",
                loadoutID = "loadout_vashnik", loadoutName = "Vashnik Single Target",
                importString = "EXPORT_BUILD_VASHNIK",
            },
        },
    }
    return { env = env, state = state, counters = counters, units = units, dt = dt }
end

local function FireHovers(h, event, arg1)
    for _ = 1, HOVERS do h.state.FireEvent(event, arg1) end
end

local HEAVY = { "UnitName", "UnitGUID", "EJ_GetNumTiers", "EJ_SelectTier", "EJ_GetInstanceByIndex",
    "EJ_GetEncounterInfoByIndex", "C_Traits.GenerateImportString", "C_NamePlate.GetNamePlates", "DynamicPrep.RefreshBar" }

local function AssertNoHeavyWork(h, label)
    for _, key in ipairs(HEAVY) do
        assertEqual(h.counters[key], 0, label .. ": 0 calls to " .. key .. " across 100 events")
    end
end

RunTest("(B1) DynamicTalent mouseover / nameplate / soft-enemy exit before Unit name/GUID/EJ/loadout work (combat, resting, players, outdoors, no binds)", function()
    local h = CreateTalentHover()
    h.units.mouseover = { name = "Murloc Tidehunter", guid = "Creature-0-1-1-1-1-0000000001" }
    h.units.softenemy = { name = "Murloc Tidehunter", guid = "Creature-0-1-1-1-1-0000000001" }
    h.units.nameplate1 = { name = "Murloc Tidehunter", guid = "Creature-0-1-1-1-1-0000000001" }

    local function Burst()
        FireHovers(h, "UPDATE_MOUSEOVER_UNIT")
        FireHovers(h, "PLAYER_SOFT_ENEMY_CHANGED")
        FireHovers(h, "NAME_PLATE_UNIT_ADDED", "nameplate1")
    end

    -- In combat: O(1) exit before any unit query at all.
    h.state.inCombat = true
    ResetCounters(h.counters)
    Burst()
    AssertNoHeavyWork(h, "in combat")
    assertEqual(h.counters.UnitExists, 0, "in combat: 0 UnitExists calls")
    assertEqual(h.counters.GetInstanceInfo, 0, "in combat: 0 GetInstanceInfo calls")
    h.state.inCombat = false

    -- Hovering a friendly player (raid / party frame): never reaches name or GUID lookups.
    h.units.mouseover = { name = "Friendlymage", guid = "Player-3725-9999", isPlayer = true }
    h.units.softenemy = h.units.mouseover
    h.units.nameplate1 = h.units.mouseover
    ResetCounters(h.counters)
    Burst()
    AssertNoHeavyWork(h, "player unit")
    assertEqual(h.counters.GetInstanceInfo, 0, "player unit: 0 GetInstanceInfo calls")

    -- Resting (cities / inns): mouseover exits before UnitExists even runs.
    h.units.mouseover = { name = "Innkeeper", guid = "Creature-0-1-1-1-2-0000000001" }
    h.state.resting = true
    ResetCounters(h.counters)
    FireHovers(h, "UPDATE_MOUSEOVER_UNIT")
    AssertNoHeavyWork(h, "resting mouseover")
    assertEqual(h.counters.UnitExists, 0, "resting: 0 UnitExists calls")
    assertEqual(h.counters.GetInstanceInfo, 0, "resting: 0 GetInstanceInfo calls")
    h.state.resting = false

    -- Outdoors with a boss bind set but no raid / custom bind applying to this zone: no name, GUID, EJ or loadout work.
    h.units.mouseover = { name = "Murloc Tidehunter", guid = "Creature-0-1-1-1-1-0000000001" }
    h.units.softenemy = h.units.mouseover
    h.units.nameplate1 = h.units.mouseover
    ResetCounters(h.counters)
    Burst()
    AssertNoHeavyWork(h, "outdoors, no zone bind")
    assertTrue(h.counters.GetInstanceInfo <= 3 * HOVERS, "outdoors: at most one GetInstanceInfo per event")

    -- No boss binds at all: exits before every Unit* / instance query.
    h.dt.db.talentBossMap = {}
    ResetCounters(h.counters)
    Burst()
    AssertNoHeavyWork(h, "no binds")
    assertEqual(h.counters.UnitExists, 0, "no binds: 0 UnitExists calls")
    assertEqual(h.counters.GetInstanceInfo, 0, "no binds: 0 GetInstanceInfo calls")

    -- The O(1) exits must also be allocation-free.
    local bytes = MeasureAlloc(function() Burst() end)
    assertTrue(bytes < 1024, string.format("300 no-bind events allocate < 1 KB (actual %.0f B)", bytes))
end)

RunTest("(B2) DynamicTalent raid hovers of non-boss NPCs never touch the Encounter Journal, loadouts or RefreshBar and memoise boss-name matching", function()
    local h = CreateTalentHover()
    h.state.instType = "raid"
    h.state.diffID = 15
    h.units.mouseover = { name = "Void Sentinel", guid = "Creature-0-1-1-1-3-0000000001" }

    -- Warm once (first hover may build the baseline raid table).
    h.state.FireEvent("UPDATE_MOUSEOVER_UNIT")
    local raidsA = h.dt:GetSeason2Raids()
    ResetCounters(h.counters)
    FireHovers(h, "UPDATE_MOUSEOVER_UNIT")
    local raidsB = h.dt:GetSeason2Raids()
    assertTrue(raidsA == raidsB, "raid table is not rebuilt per hover")
    for _, key in ipairs({ "UnitGUID", "EJ_GetNumTiers", "EJ_SelectTier", "EJ_GetInstanceByIndex", "EJ_GetEncounterInfoByIndex", "C_Traits.GenerateImportString", "C_NamePlate.GetNamePlates", "DynamicPrep.RefreshBar" }) do
        assertTrue(h.counters[key] <= HOVERS and (key == "UnitGUID" or h.counters[key] == 0), "raid non-boss hover: budget for " .. key)
    end
    assertTrue(h.counters.UnitName <= HOVERS, "raid non-boss hover: at most one UnitName per hover")
    -- Boss-name matching is memoised per exact name against the live raid table.
    assertEqual(h.dt._matchMemo and h.dt._matchMemo["Void Sentinel"], false, "negative boss-name match is memoised")
    local firstBoss = raidsA[1] and raidsA[1].bosses and raidsA[1].bosses[1]
    if firstBoss and firstBoss.name then
        local a1, a2, a3, a4 = h.dt:MatchBossTargetName(firstBoss.name)
        local b1, b2, b3, b4 = h.dt:MatchBossTargetName(firstBoss.name)
        assertTrue(a1 ~= nil and a1 == b1 and a2 == b2 and a3 == b3 and a4 == b4 and a4 == firstBoss, "positive boss-name match is stable across the memo")
    end
    assertTrue(h.dt:MatchBossTargetName("Void Sentinel") == nil, "memoised miss still returns nil")end)

-- ============================================================================
-- (C) DynamicBags: Item TooltipDataProcessor post-call hover budget
-- ============================================================================
local BAGS_PATH = "DynamicSuite/Modules/DynamicBags.lua"

local function CreateBagsHover()
    local env, state = CreateBaseEnv()
    local counters = NewCounters()
    local sharedTbl = {}
    local postCall = nil
    env.Enum = { TooltipDataType = { Item = 0 } }
    env.TooltipDataProcessor = {
        AddTooltipPostCall = function(_, fn) postCall = fn end,
    }
    env.C_Container = {
        GetContainerNumSlots = function() return 0 end,
        GetContainerNumFreeSlots = function() return 0, 0 end,
        GetContainerItemID = function() return nil end,
        GetContainerItemInfo = function() return nil end,
        GetContainerItemLink = function() return nil end,
        GetContainerItemQuestInfo = function() return nil end,
    }
    env.C_Item = { GetItemCount = function() return 0 end, GetItemInfo = function() return nil end }
    env.GetItemCount = function() return 0 end
    env.C_CurrencyInfo = { GetBackpackCurrencyInfo = function() return nil end, GetCurrencyListSize = function() return 0 end }
    env.C_Bank = { FetchDepositedMoney = function() return 0 end, CanUseBank = function() return false end }
    env.GetMoney = function() return 0 end
    env.GetCursorInfo = function() return nil end
    env.IsInGuild = function() return false end

    for _, path in ipairs({
        "C_Container.GetContainerNumSlots", "C_Container.GetContainerNumFreeSlots", "C_Container.GetContainerItemID",
        "C_Container.GetContainerItemInfo", "C_Container.GetContainerItemLink", "C_Container.GetContainerItemQuestInfo",
        "C_Item.GetItemCount", "C_Item.GetItemInfo", "GetItemCount",
    }) do Spy(env, counters, path) end

    LoadChunk(CORE_PATH, env, "DynamicSuite", sharedTbl)
    LoadChunk(BAGS_PATH, env, "DynamicSuite", sharedTbl)
    state.FireEvent("ADDON_LOADED", "DynamicSuite")
    state.FireEvent("PLAYER_LOGIN")
    assertTrue(env.DynamicBags ~= nil and env.DynamicBags.U ~= nil, "DynamicBags loaded")
    local U = env.DynamicBags.U
    if not postCall then U.InstallTooltipHook() end
    assertTrue(type(postCall) == "function", "Item tooltip post-call registered")

    -- Static accent so the probe measures the hook, not the host Suite's accent resolver.
    env.DynamicSuite = env.DynamicSuite or {}
    env.DynamicSuite.GetSuiteAccent = function() return 0.22, 0.74, 0.97 end

    local db = env.DynamicBagsDB
    db.tooltipCounts = true
    db.vault = db.vault or {}
    db.vault.characters = {
        ["Alt-Frostmourne"] = { name = "Alt", class = "MAGE", bags = { { 12345, nil, 3 } }, bank = { { 12345, nil, 2 } } },
    }

    local lines = { add = 0, double = 0 }
    local gt = env.GameTooltip
    local owner = { dbBag = 0, dbSlot = 1, dbObj = { itemID = 12345, empty = false } }
    function owner.GetName() return "DynamicBagsSlot1" end
    function gt.GetOwner() return owner end
    function gt.AddLine() lines.add = lines.add + 1 end
    function gt.AddDoubleLine() lines.double = lines.double + 1 end

    local itemData = { id = 12345 }
    local buildCalls = 0
    local origBuild = U.BuildCountIndex
    U.BuildCountIndex = function(...) buildCalls = buildCalls + 1; return origBuild(...) end

    return {
        env = env, state = state, counters = counters, U = U, lines = lines, owner = owner, db = db,
        Hover = function() postCall(env.GameTooltip, itemData) end,
        Builds = function() return buildCalls end,
    }
end

RunTest("(C1) DynamicBags item tooltip post-call: 0 C_Container scans, one count-index build, ~0 allocations across 100 bag-item hovers", function()
    local h = CreateBagsHover()
    h.Hover()
    assertEqual(h.Builds(), 1, "first hover builds the count index once")
    assertTrue(h.lines.add + h.lines.double >= 3, "first hover appends the cross-character counts and the pin hint")

    ResetCounters(h.counters)
    h.lines.add, h.lines.double = 0, 0
    for _ = 1, HOVERS do h.Hover() end
    assertEqual(SumCounters(h.counters), 0, "0 C_Container / C_Item / GetItemCount calls across 100 hovers")
    assertEqual(h.Builds(), 1, "count index is never rebuilt on repeat hovers")
    assertTrue(h.lines.add + h.lines.double >= HOVERS * 3, "every hover still renders counts + pin hint")

    local bytes = MeasureAlloc(function() for _ = 1, HOVERS do h.Hover() end end)
    assertTrue(bytes < 1024, string.format("100 bag-item hovers allocate < 1 KB (actual %.0f B)", bytes))
end)

RunTest("(C2) DynamicBags item tooltip post-call skips instantly in combat and skips counts when tooltipCounts is off", function()
    local h = CreateBagsHover()
    h.Hover()

    -- In combat: nothing is added and nothing is queried.
    h.state.inCombat = true
    ResetCounters(h.counters)
    h.lines.add, h.lines.double = 0, 0
    local b0 = h.Builds()
    for _ = 1, HOVERS do h.Hover() end
    assertEqual(h.lines.add + h.lines.double, 0, "combat: 0 tooltip lines added across 100 hovers")
    assertEqual(SumCounters(h.counters), 0, "combat: 0 container API calls")
    assertEqual(h.Builds() - b0, 0, "combat: 0 count-index builds")
    h.state.inCombat = false

    -- tooltipCounts off: no count lines and no index work (the pin hint is a separate feature).
    h.db.tooltipCounts = false
    h.lines.add, h.lines.double = 0, 0
    for _ = 1, HOVERS do h.Hover() end
    assertEqual(h.lines.double, 0, "tooltipCounts=false: no count rows")
    assertEqual(h.Builds() - b0, 0, "tooltipCounts=false: 0 count-index builds")
    assertEqual(SumCounters(h.counters), 0, "tooltipCounts=false: 0 container API calls")
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end