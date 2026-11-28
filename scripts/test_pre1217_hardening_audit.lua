-- ============================================================================
-- Headless Lua 5.1 Regression Suite: Pre-12.1.7 Hardening Audit
-- Verifies every defect & guard tightened across:
--   T1. DynamicSuite_Core: fail-closed secret probes & forbidden GameTooltip guards
--   T2. DynamicCursor: zero per-frame Show/Hide churn when stationary, secret
--       UNIT_SPELLCAST_* unit tokens, and secret screen/forbidden tooltip safety
--   T3. DynamicBags: TooltipDataProcessor disabled/forbidden-owner/secret guards,
--       zero sync Show(), and C_TooltipInfo secret lines/quality guards
--   T4. DynamicTalent: AppendHeroSwapTooltipHint forbidden & owner-match guards,
--       secret OnMouseUp args, and O(1) empty-bind PLAYER_TARGET_CHANGED exit
--   T5. DynamicChat: secret GetNumMessages/messageTypeList/isLocked/isDocked,
--       idempotent EditBox chrome re-stripping, 2-point EditBox offset drift fix,
--       combat _pendingEditBoxSkinFlush on PLAYER_REGEN_ENABLED, OnEditBoxFocusLost
--       re-anchoring & EllesmereUI hide guard, BN_WHISPER Middle-Click protection,
--       and zero alteration of Blizzard clubFinder/clubTicket guild/community links
-- Pure ASCII Only.
-- ============================================================================

local CORE_PATH   = "DynamicSuite/DynamicSuite_Core.lua"
local CURSOR_PATH = "DynamicSuite/Modules/DynamicCursor.lua"
local BAGS_PATH   = "DynamicSuite/Modules/DynamicBags.lua"
local TALENT_PATH = "DynamicSuite/Modules/DynamicTalent.lua"
local CHAT_PATH   = "DynamicSuite/Modules/DynamicChat.lua"

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

local function MakeSecret(tag)
    return setmetatable({ __testSecret = true, tag = tag or "secret" }, {
        __lt = function() error("Attempt to compare secret value") end,
        __le = function() error("Attempt to compare secret value") end,
        __add = function() error("Attempt to do arithmetic on secret value") end,
        __sub = function() error("Attempt to do arithmetic on secret value") end,
        __mul = function() error("Attempt to do arithmetic on secret value") end,
        __concat = function() error("Attempt to concat secret value") end,
        __len = function() error("Attempt to measure secret value") end,
        __index = function() error("Attempt to index secret value") end,
    })
end

local function CreateBaseEnv()
    local env = {}
    setmetatable(env, { __index = _G })
    env._G = env

    local state = {
        now = 250.0,
        epoch = 1700000000,
        inCombat = false,
        inRaid = false,
        resting = false,
        throwSecretApi = false,
        eventFrames = {},
        allFrames = {},
        timers = {},
        hooks = {},
        registryListeners = {},
        tooltipPostCalls = {},
        calls = {
            unitExists = 0,
            unitIsPlayer = 0,
            getInstanceInfo = 0,
            fcfClose = 0,
            chatFilterRegs = 0,
            addMessage = 0,
        },
    }

    env.wipe = function(t)
        if type(t) ~= "table" then return t end
        for k in pairs(t) do t[k] = nil end
        return t
    end
    env.tinsert = table.insert
    env.tremove = table.remove
    env.strtrim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
    env.strsplit = function(sep, str)
        local out = {}
        for part in string.gmatch(tostring(str or ""), "([^" .. tostring(sep) .. "]+)") do
            out[#out + 1] = part
        end
        return unpack(out)
    end
    env.CopyTable = function(src)
        if type(src) ~= "table" then return src end
        local dst = {}
        for k, v in pairs(src) do dst[k] = env.CopyTable(v) end
        return dst
    end
    env.GetTime = function() return state.now end
    env.time = function() return state.epoch end
    env.date = function() return "23:40" end
    env.GetScreenWidth = function() return 1920 end
    env.GetScreenHeight = function() return 1080 end
    env.GetPhysicalScreenSize = function() return 1920, 1080 end
    env.GetCursorPosition = function() return 600, 400 end
    env.GetLocale = function() return "enUS" end
    env.InCombatLockdown = function() return state.inCombat end
    env.UnitAffectingCombat = function() return state.inCombat end
    env.IsResting = function() return state.resting end
    env.IsShiftKeyDown = function() return false end
    env.IsControlKeyDown = function() return false end
    env.IsAltKeyDown = function() return false end
    env.IsMouseButtonDown = function() return false end
    env.UnitName = function(u)
        if u == "player" then return "Dentee" end
        return "TargetMob"
    end
    env.UnitClass = function() return "Mage", "MAGE", 8 end
    env.UnitLevel = function() return 80 end
    env.UnitGUID = function() return "Player-3725-00000001" end
    env.UnitExists = function(u)
        state.calls.unitExists = state.calls.unitExists + 1
        return u == "player" or u == "target"
    end
    env.UnitIsPlayer = function()
        state.calls.unitIsPlayer = state.calls.unitIsPlayer + 1
        return false
    end
    env.UnitIsDeadOrGhost = function() return false end
    env.UnitInVehicle = function() return false end
    env.GetRealmName = function() return "Frostmourne" end
    env.GetSpecialization = function() return 1 end
    env.GetSpecializationInfo = function() return 64, "Frost", "", 135846, "DAMAGER" end
    env.C_SpecializationInfo = {
        GetSpecialization = env.GetSpecialization,
        GetSpecializationInfo = env.GetSpecializationInfo,
    }
    env.IsInRaid = function() return state.inRaid end
    env.IsInGroup = function() return state.inRaid end
    env.IsInInstance = function() return state.inRaid, state.inRaid and "raid" or "none" end
    env.GetInstanceInfo = function()
        state.calls.getInstanceInfo = state.calls.getInstanceInfo + 1
        return "", state.inRaid and "raid" or "none", state.inRaid and 16 or 0
    end
    env.SpellIsTargeting = function() return false end
    env.PlaySound = function() end
    env.PlaySoundFile = function() end
    env.ReloadUI = function() end
    env.print = function() end
    env.GetCursorInfo = function() return nil end
    env.GetMoney = function() return 0 end
    env.GetGuildBankMoney = function() return 0 end
    env.GetGuildBankWithdrawMoney = function() return 0 end
    env.CanWithdrawGuildBankMoney = function() return false end
    env.IsInGuild = function() return false end
    env.GetMouseFoci = function() return {} end
    env.CreateColor = function(r, g, b, a)
        return { r = r or 1, g = g or 1, b = b or 1, a = a or 1, GetRGBA = function(self) return self.r, self.g, self.b, self.a end }
    end
    env.UISpecialFrames = {}
    env.SlashCmdList = {}
    env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92, colorStr = "ff3fc7eb" } }
    env.SOUNDKIT = { UI_BNET_TOAST = 18019, IG_CHARACTER_INFO_TAB = 841, IG_MAINMENU_OPTION_CHECKBOX_ON = 856 }
    env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    env.UNKNOWNOBJECT = "Unknown"
    env.NUM_CHAT_WINDOWS = 10
    env.MAX_WOW_CHAT_CHANNELS = 10
    env.ITEM_SOULBOUND = "Soulbound"
    env.ITEM_BIND_ON_PICKUP = "Binds when picked up"
    env.ITEM_BIND_ON_EQUIP = "Binds when equipped"
    env.ITEM_QUALITY_COLORS = {
        [0] = { r = 0.6, g = 0.6, b = 0.6 },
        [1] = { r = 1, g = 1, b = 1 },
        [2] = { r = 0.1, g = 1, b = 0 },
        [3] = { r = 0, g = 0.4, b = 0.9 },
        [4] = { r = 0.6, g = 0.2, b = 0.9 },
    }
    env.Enum = {
        TooltipDataType = { Item = 0 },
        BagIndex = { Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5, Bank = -1, CharacterBankTab_1 = 6, AccountBankTab_1 = 13 },
    }

    env.issecretvalue = function(v)
        if state.throwSecretApi then error("issecretvalue failed") end
        return type(v) == "table" and rawget(v, "__testSecret") == true
    end
    env.canaccessvalue = function(v)
        if state.throwSecretApi then error("canaccessvalue failed") end
        return not (type(v) == "table" and rawget(v, "__testSecret") == true)
    end

    env.ChatFrame_AddMessageEventFilter = function()
        state.calls.chatFilterRegs = state.calls.chatFilterRegs + 1
    end

    env.TooltipDataProcessor = {
        AddTooltipPostCall = function(dataType, fn)
            state.tooltipPostCalls[dataType] = state.tooltipPostCalls[dataType] or {}
            table.insert(state.tooltipPostCalls[dataType], fn)
        end,
    }

    env.GameTooltip_SetDefaultAnchor = function(tooltip, parent)
        for _, fn in ipairs(state.hooks["GameTooltip_SetDefaultAnchor"] or {}) do
            fn(tooltip, parent)
        end
    end

    env.hooksecurefunc = function(a, b, c)
        if type(a) == "string" and type(b) == "function" then
            state.hooks[a] = state.hooks[a] or {}
            table.insert(state.hooks[a], b)
            if type(env[a]) == "function" and a ~= "GameTooltip_SetDefaultAnchor" then
                local orig = env[a]
                env[a] = function(...)
                    local r1, r2, r3, r4 = orig(...)
                    b(...)
                    return r1, r2, r3, r4
                end
            end
        elseif type(a) == "table" and type(b) == "string" and type(c) == "function" then
            local orig = a[b]
            a[b] = function(...)
                local r1, r2, r3, r4
                if type(orig) == "function" then r1, r2, r3, r4 = orig(...) end
                c(...)
                return r1, r2, r3, r4
            end
        end
    end

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

    env.C_Timer = {
        After = function(delay, fn) table.insert(state.timers, { delay = delay, fn = fn }) end,
        NewTimer = function(delay, fn)
            local e = { delay = delay, fn = fn }
            table.insert(state.timers, e)
            return { Cancel = function() e.cancelled = true end }
        end,
        NewTicker = function() return { Cancel = function() end } end,
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
    env.C_Map = { GetMapInfo = function() return { name = "Dornogal" } end, GetBestMapForUnit = function() return 2339 end }
    env.C_PetBattles = { IsInBattle = function() return false end }
    env.C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerNumFreeSlots = function() return 0, 0 end, GetContainerItemInfo = function() return nil end }
    env.C_Item = { GetItemInfo = function() return nil end, GetItemInfoInstant = function() return nil end, GetItemCount = function() return 0 end }
    env.C_Spell = { GetSpellCooldown = function() return { startTime = 0, duration = 0 } end, GetSpellTexture = function() return 134400 end }
    env.C_Texture = { GetAtlasInfo = function() return nil end }
    env.C_CurrencyInfo = { GetBackpackCurrencyInfo = function() return nil end, GetCurrencyListSize = function() return 0 end }
    env.C_Bank = { FetchDepositedMoney = function() return 0 end, CanUseBank = function() return false end }
    env.C_ChallengeMode = { IsChallengeModeActive = function() return false end }
    env.DEFAULT_CHAT_FRAME = { AddMessage = function() state.calls.addMessage = state.calls.addMessage + 1 end }

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
            _strata = "LOW",
            _points = {},
            _scripts = {},
            _events = {},
            _attrs = {},
            _children = {},
            _regions = {},
            _text = "",
            _forbidden = false,
            _hasFocus = false,
            _showCalls = 0,
            _hideCalls = 0,
            _setShownCalls = 0,
            _setAlphaCalls = 0,
            _setPointCalls = 0,
            _clearAllPointsCalls = 0,
            _clampedCalls = {},
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
        function w:Show() self._showCalls = self._showCalls + 1; self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end
        function w:Hide() self._hideCalls = self._hideCalls + 1; self._shown = false; if self._scripts.OnHide then self._scripts.OnHide(self) end end
        function w:SetShown(b) self._setShownCalls = self._setShownCalls + 1; if b then self:Show() else self:Hide() end end
        function w:IsShown() return self._shown == true end
        function w:IsVisible() return self._shown == true end
        function w:IsForbidden() return self._forbidden == true end
        function w:SetAlpha(a) self._setAlphaCalls = self._setAlphaCalls + 1; self._alpha = a or 1.0 end
        function w:GetAlpha() return self._alpha end
        function w:SetScale(s) self._scale = s or 1.0 end
        function w:GetScale() return self._scale end
        function w:GetEffectiveScale() return self._scale end
        function w:SetSize(ww, hh) self._width = ww; self._height = hh end
        function w:SetWidth(ww) self._width = ww end
        function w:SetHeight(hh) self._height = hh end
        function w:GetWidth() return self._width end
        function w:GetHeight() return self._height end
        function w:GetLeft() return 50 end
        function w:GetBottom() return 50 end
        function w:GetRight() return 50 + (self._width or 100) end
        function w:GetTop() return 50 + (self._height or 30) end
        function w:GetCenter() return 50 + (self._width or 100) * 0.5, 50 + (self._height or 30) * 0.5 end
        function w:SetFrameStrata(s) self._strata = s end
        function w:GetFrameStrata() return self._strata end
        function w:SetFrameLevel(l) self._level = l end
        function w:GetFrameLevel() return self._level end
        function w:ClearAllPoints() self._clearAllPointsCalls = self._clearAllPointsCalls + 1; self._points = {} end
        function w:SetPoint(pt, relTo, relPt, x, y)
            self._setPointCalls = self._setPointCalls + 1
            if type(relTo) == "number" then y = relPt; x = relTo; relPt = pt; relTo = env.UIParent end
            table.insert(self._points, { pt, relTo or env.UIParent, relPt or pt, tonumber(x) or 0, tonumber(y) or 0 })
        end
        function w:SetAllPoints(p) self._points = { { "ALL", p, "ALL", 0, 0 } } end
        function w:GetNumPoints() return #self._points end
        function w:GetPoint(i) local p = self._points[i or 1]; if not p then return nil end; return p[1], p[2], p[3], p[4], p[5] end
        function w:SetClampedToScreen(v) table.insert(self._clampedCalls, v and true or false) end
        function w:SetClampRectInsets() end
        function w:SetClipsChildren() end
        function w:SetToplevel() end
        function w:SetMovable() end
        function w:SetResizable() end
        function w:SetResizeBounds() end
        function w:SetUserPlaced() end
        function w:SetIgnoreParentAlpha() end
        function w:EnableMouse() end
        function w:EnableMouseWheel() end
        function w:EnableKeyboard() end
        function w:RegisterForDrag() end
        function w:RegisterForClicks() end
        function w:SetHitRectInsets() end
        function w:SetPropagateKeyboardInput() end
        function w:StartMoving() end
        function w:StopMovingOrSizing() end
        function w:Raise() end
        function w:Lower() end
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
        function w:SetTextInsets() end
        function w:SetCursorPosition() end
        function w:HighlightText() end
        function w:SetAltArrowKeyMode() end
        function w:GetAltArrowKeyMode() return true end
        function w:SetText(t) self._text = tostring(t or "") end
        function w:GetText() return self._text end
        function w:SetFont() return true end
        function w:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
        function w:SetFontObject() end
        function w:SetShadowColor() end
        function w:SetShadowOffset() end
        function w:SetTextColor() end
        function w:SetJustifyH() end
        function w:SetJustifyV() end
        function w:SetWordWrap() end
        function w:SetSpacing() end
        function w:SetFading() end
        function w:GetFading() return true end
        function w:SetTimeVisible() end
        function w:SetDrawEdge() end
        function w:SetDrawBling() end
        function w:SetDrawSwipe() end
        function w:SetHideCountdownNumbers() end
        function w:SetSwipeTexture() end
        function w:SetSwipeColor() end
        function w:SetReverse() end
        function w:SetCooldown() end
        function w:SetScrollChild() end
        function w:SetVerticalScroll() end
        function w:GetVerticalScroll() return 0 end
        function w:GetVerticalScrollRange() return 0 end
        function w:UpdateScrollChildRect() end
        function w:SetNormalFontObject() end
        function w:SetHighlightTexture() end
        function w:SetNormalTexture() end
        function w:SetPushedTexture() end
        function w:GetFontString() return nil end
        function w:GetStringWidth() return #(self._text or "") * 6 end
        function w:GetUnboundedStringWidth() return #(self._text or "") * 6 end
        function w:GetStringHeight() return 14 end
        function w:SetScript(ev, fn) self._scripts[ev] = fn end
        function w:GetScript(ev) return self._scripts[ev] end
        function w:HasScript(ev) return ev ~= "OnCooldownDone" end
        function w:HookScript(ev, fn)
            local prev = self._scripts[ev]
            self._scripts[ev] = function(...)
                if prev then prev(...) end
                fn(...)
            end
        end
        function w:RegisterEvent(ev) self._events[ev] = true end
        function w:RegisterUnitEvent(ev) self._events[ev] = true end
        function w:UnregisterEvent(ev) self._events[ev] = nil end
        function w:UnregisterAllEvents() self._events = {} end
        function w:CreateAnimationGroup()
            return {
                CreateAnimation = function()
                    return { SetDuration = function() end, SetOrder = function() end, SetFromAlpha = function() end, SetToAlpha = function() end, SetOffset = function() end, SetSmoothing = function() end }
                end,
                SetScript = function() end,
                SetLooping = function() end,
                Play = function() end,
                Pause = function() end,
                Stop = function() end,
            }
        end
        function w:CreateTexture()
            local tex = MakeWidget("Texture", nil, self)
            function tex:SetColorTexture() end
            function tex:SetTexture(t) self._tex = t end
            function tex:GetTexture() return self._tex end
            function tex:SetVertexColor() end
            function tex:SetTexCoord() end
            function tex:SetBlendMode() end
            function tex:SetDesaturated() end
            function tex:SetAtlas() end
            function tex:GetAtlas() return nil end
            function tex:SetRotation() end
            function tex:SetSnapToPixelGrid() end
            function tex:SetTexelSnappingBias() end
            table.insert(self._regions, tex)
            return tex
        end
        function w:CreateFontString()
            local fs = MakeWidget("FontString", nil, self)
            table.insert(self._regions, fs)
            return fs
        end
        if name then env[name] = w end
        table.insert(state.allFrames, w)
        return w
    end

    env.UIParent = MakeWidget("Frame", "UIParent", nil)
    env.UIParent:SetSize(1920, 1080)
    env.UIParent:Show()

    local gt = MakeWidget("GameTooltip", "GameTooltip", env.UIParent)
    gt._lines = {}
    gt._owner = nil
    function gt:SetOwner(o) self._owner = o end
    function gt:GetOwner() return self._owner end
    function gt:IsOwned(o) return self._owner == o end
    function gt:ClearLines() self._lines = {} end
    function gt:SetText(t) self._lines = { tostring(t or "") } end
    function gt:AddLine(t) table.insert(self._lines, tostring(t or "")) end
    function gt:AddDoubleLine(l, r) table.insert(self._lines, tostring(l or "") .. " | " .. tostring(r or "")) end
    function gt:NumLines() return #self._lines end
    function gt:SetHyperlink() end
    function gt:SetBagItem() end
    env.GameTooltip = gt

    local irt = MakeWidget("GameTooltip", "ItemRefTooltip", env.UIParent)
    env.ItemRefTooltip = irt

    env.CreateFrame = function(ftype, name, parent)
        local fr = MakeWidget(ftype, name, parent)
        table.insert(state.eventFrames, fr)
        return fr
    end

    function state.FireEvent(ev, ...)
        for _, ef in ipairs(state.eventFrames) do
            if ef._events[ev] and type(ef._scripts.OnEvent) == "function" then
                ef._scripts.OnEvent(ef, ev, ...)
            end
        end
    end

    return env, state, MakeWidget
end

local function LoadChunk(path, env, addonName, sharedTbl)
    local chunk, err = loadfile(path)
    assertTrue(chunk ~= nil, "Failed to load " .. path .. ": " .. tostring(err))
    setfenv(chunk, env)
    return chunk(addonName, sharedTbl)
end

-- ============================================================================
-- T1. DynamicSuite_Core: Fail-closed secret probe & forbidden GameTooltip
-- ============================================================================
RunTest("T1: DynamicSuite_Core fail-closed secret probe and forbidden GameTooltip guards", function()
    local env, state = CreateBaseEnv()
    local shared = {}
    LoadChunk(CORE_PATH, env, "DynamicSuite", shared)
    state.FireEvent("ADDON_LOADED", "DynamicSuite")
    state.FireEvent("PLAYER_LOGIN")

    -- 1. DesktopWindows SafeIsSecretVal fails closed when issecretvalue throws
    local W = env.DynamicSuite and env.DynamicSuite.DesktopWindows and env.DynamicSuite.DesktopWindows._state
    if W and type(W.SafeIsSecretVal) == "function" then
        state.throwSecretApi = true
        assertEqual(W.SafeIsSecretVal("probe"), true, "SafeIsSecretVal must fail closed when issecretvalue throws")
        state.throwSecretApi = false
        assertEqual(W.SafeIsSecretVal("plain"), false, "SafeIsSecretVal returns false for normal strings")
    end

    -- 2. Forbidden GameTooltip never errors on OpenHudEditForTarget / Alert Toast hover / Combat Pill hover
    env.GameTooltip._forbidden = true
    env.GameTooltip.Hide = function() error("Forbidden GameTooltip:Hide called!") end
    env.GameTooltip.SetOwner = function() error("Forbidden GameTooltip:SetOwner called!") end
    env.GameTooltip.IsOwned = function() error("Forbidden GameTooltip:IsOwned called!") end

    local okOpen = pcall(env.DynamicSuite.OpenHudEditForTarget, "TOAST", nil, "DynamicSuite")
    assertTrue(okOpen, "OpenHudEditForTarget must not touch forbidden GameTooltip")

    if type(shared.EnsureCombatPausePill) == "function" then
        local pill = shared.EnsureCombatPausePill()
        assertTrue(pill ~= nil, "Combat pause pill created")
        local okEnter = pcall(pill:GetScript("OnEnter"), pill)
        local okLeave = pcall(pill:GetScript("OnLeave"), pill)
        assertTrue(okEnter and okLeave, "Combat pause pill OnEnter/OnLeave must skip forbidden GameTooltip")
    end
end)

-- ============================================================================
-- T2. DynamicCursor: Zero stationary Show/Hide churn, secret spellcast & tooltip
-- ============================================================================
RunTest("T2: DynamicCursor stationary OnUpdate churn, secret UNIT_SPELLCAST_*, and Smart Tooltip safety", function()
    local env, state = CreateBaseEnv()
    local shared = {}
    LoadChunk(CORE_PATH, env, "DynamicSuite", shared)
    LoadChunk(CURSOR_PATH, env, "DynamicSuite", shared)
    state.FireEvent("ADDON_LOADED", "DynamicSuite")
    state.FireEvent("PLAYER_LOGIN")

    env.DynamicCursorDB.ringEnabled = true
    env.DynamicCursorDB.tooltipEnabled = true
    env.DynamicCursor.SyncAllEngines()

    -- Find the active OnUpdate frame
    local updateFrame = nil
    for _, fr in ipairs(state.eventFrames) do
        if type(fr._scripts.OnUpdate) == "function" then
            updateFrame = fr
            break
        end
    end
    assertTrue(updateFrame ~= nil, "DynamicCursor OnUpdate frame active when ringEnabled=true")

    -- First tick establishes position & visible state
    updateFrame._scripts.OnUpdate(updateFrame, 0.016)

    local ringRoot = env.DynamicCursorRingFrame
    assertTrue(ringRoot ~= nil, "DynamicCursorRingFrame created")
    -- Reset Show/Hide/SetShown/SetPoint counters on ringRoot and its texture children
    local function ResetFrameCounters(f)
        f._showCalls = 0; f._hideCalls = 0; f._setShownCalls = 0; f._setPointCalls = 0
        for _, r in ipairs(f._regions or {}) do
            r._showCalls = 0; r._hideCalls = 0; r._setShownCalls = 0; r._setPointCalls = 0
        end
    end
    ResetFrameCounters(ringRoot)

    -- 60 stationary frames: 0 redundant Show/Hide/SetShown/SetPoint calls!
    for i = 1, 60 do
        state.now = state.now + 0.016
        updateFrame._scripts.OnUpdate(updateFrame, 0.016)
    end
    assertEqual(ringRoot._showCalls + ringRoot._hideCalls + ringRoot._setPointCalls, 0,
        "Stationary cursor makes 0 redundant ringRoot Show/Hide/SetPoint calls across 60 frames")
    local regionChurn = 0
    for _, r in ipairs(ringRoot._regions or {}) do
        regionChurn = regionChurn + r._showCalls + r._hideCalls + r._setShownCalls
    end
    assertEqual(regionChurn, 0, "Stationary cursor makes 0 redundant ring texture Show/Hide/SetShown calls across 60 frames")

    -- Secret UNIT_SPELLCAST_* unit token must not error
    local secretUnit = MakeSecret("unit-token")
    local okCast = pcall(state.FireEvent, "UNIT_SPELLCAST_START", secretUnit, nil, 12345)
    local okSucc = pcall(state.FireEvent, "UNIT_SPELLCAST_SUCCEEDED", secretUnit, nil, 12345)
    local okStop = pcall(state.FireEvent, "UNIT_SPELLCAST_STOP", secretUnit, nil, 12345)
    assertTrue(okCast and okSucc and okStop, "UNIT_SPELLCAST_* with secret arg1 must never error")

    -- GameTooltip_SetDefaultAnchor with secret screen dimensions must not error and never call Show()
    env.GetScreenWidth = function() return MakeSecret("sw") end
    env.GetScreenHeight = function() return MakeSecret("sh") end
    env.GameTooltip._showCalls = 0
    local okTip = pcall(env.GameTooltip_SetDefaultAnchor, env.GameTooltip, env.UIParent)
    assertTrue(okTip, "GameTooltip_SetDefaultAnchor handles secret screen width/height safely")
    assertEqual(env.GameTooltip._showCalls, 0, "GameTooltip_SetDefaultAnchor never calls tooltip:Show()")
end)

-- ============================================================================
-- T3. DynamicBags: TooltipDataProcessor & C_TooltipInfo 12.1.7 Secret Guards
-- ============================================================================
RunTest("T3: DynamicBags TooltipDataProcessor disabled/forbidden-owner/secret guards and C_TooltipInfo safety", function()
    local env, state, MakeWidget = CreateBaseEnv()
    local shared = {}
    LoadChunk(CORE_PATH, env, "DynamicSuite", shared)
    LoadChunk(BAGS_PATH, env, "DynamicSuite", shared)
    state.FireEvent("ADDON_LOADED", "DynamicSuite")
    state.FireEvent("PLAYER_LOGIN")

    local postCalls = state.tooltipPostCalls[env.Enum.TooltipDataType.Item]
    assertTrue(postCalls and #postCalls == 1, "DynamicBags registered 1 Item TooltipDataProcessor post-call")
    local cb = postCalls[1]

    -- 1. Forbidden owner must never be indexed for dbBag / GetName
    local forbiddenOwner = setmetatable({
        IsForbidden = function() return true end,
    }, {
        __index = function(_, k)
            error("Forbidden owner indexed for key: " .. tostring(k))
        end,
    })
    env.GameTooltip:SetOwner(forbiddenOwner)
    env.GameTooltip._showCalls = 0
    local okForbOwn = pcall(cb, env.GameTooltip, { id = 19019 })
    assertTrue(okForbOwn, "TooltipDataProcessor post-call must not index forbidden owner")
    assertEqual(env.GameTooltip._showCalls, 0, "TooltipDataProcessor post-call must never call tooltip:Show()")

    -- 2. Secret tooltip / secret data / secret itemID never error
    assertTrue(pcall(cb, MakeSecret("tt"), { id = 19019 }), "Secret tooltip safely skipped")
    assertTrue(pcall(cb, env.GameTooltip, MakeSecret("data")), "Secret tooltip data safely skipped")
    assertTrue(pcall(cb, env.GameTooltip, { id = MakeSecret("id") }), "Secret itemID safely skipped")

    -- 3. Soft-disabled DynamicBags skips TooltipDataProcessor post-call completely
    env.DynamicSuiteDB = env.DynamicSuiteDB or { global = { disabledModules = {} } }
    env.DynamicSuiteDB.global = env.DynamicSuiteDB.global or { disabledModules = {} }
    env.DynamicSuiteDB.global.disabledModules = env.DynamicSuiteDB.global.disabledModules or {}
    env.DynamicSuiteDB.global.disabledModules.DynamicBags = true
    local bagOwner = MakeWidget("Button", "BagSlot1", env.UIParent)
    bagOwner.dbBag = 0; bagOwner.dbSlot = 1; bagOwner.dbObj = { empty = false, itemID = 19019 }
    env.GameTooltip:SetOwner(bagOwner)
    env.GameTooltip:ClearLines()
    cb(env.GameTooltip, { id = 19019 })
    assertEqual(#env.GameTooltip._lines, 0, "Disabled DynamicBags adds 0 tooltip lines")
    env.DynamicSuiteDB.global.disabledModules.DynamicBags = nil

    -- 4. C_TooltipInfo & C_TradeSkillUI secret return values never crash DetectCraftQuality / ScanGearTooltip
    env.C_TradeSkillUI = {
        GetItemCraftedQualityByItemInfo = function() return MakeSecret("qual") end,
        GetItemReagentQualityByItemInfo = function() return MakeSecret("rqual") end,
    }
    env.C_TooltipInfo = {
        GetBagItem = function() return { lines = { MakeSecret("line"), { leftText = MakeSecret("txt"), leftColor = { r = MakeSecret("r"), g = 0, b = 0 } } } } end,
        GetHyperlink = function() return MakeSecret("tdata") end,
        GetItemByID = function() return { lines = MakeSecret("lines") } end,
    }
    local U = env.DynamicBags and env.DynamicBags.U
    if U and type(U.DetectCraftQuality) == "function" then
        local okDQ = pcall(U.DetectCraftQuality, "|Hitem:19019|h[Test]|h", 19019, 0, 1, 7, 10)
        assertTrue(okDQ, "DetectCraftQuality handles secret quality numbers and secret C_TooltipInfo data")
    end
    if U and type(U.ScanGearTooltip) == "function" then
        local okSG = pcall(U.ScanGearTooltip, { bag = 0, slot = 1, itemID = 19019, link = "|Hitem:19019|h[Test]|h", classID = 2, quality = 4 })
        assertTrue(okSG, "ScanGearTooltip handles secret C_TooltipInfo lines and colors")
    end
end)

-- ============================================================================
-- T4. DynamicTalent: Empty-bind PLAYER_TARGET_CHANGED & Hero Tooltip Guards
-- ============================================================================
RunTest("T4: DynamicTalent O(1) empty-bind PLAYER_TARGET_CHANGED exit & Hero medallion tooltip/click guards", function()
    local env, state, MakeWidget = CreateBaseEnv()
    local shared = {}
    LoadChunk(CORE_PATH, env, "DynamicSuite", shared)
    LoadChunk(TALENT_PATH, env, "DynamicSuite", shared)
    state.FireEvent("ADDON_LOADED", "DynamicSuite")
    state.FireEvent("PLAYER_LOGIN")

    -- Ensure talentBossMap is empty
    env.DynamicTalent.db.talentBossMap = {}
    state.calls.unitExists = 0
    state.calls.unitIsPlayer = 0
    state.calls.getInstanceInfo = 0
    for _ = 1, 50 do
        state.FireEvent("PLAYER_TARGET_CHANGED")
    end
    assertEqual(state.calls.unitExists, 0, "Empty talentBossMap: PLAYER_TARGET_CHANGED makes 0 UnitExists calls")
    assertEqual(state.calls.unitIsPlayer, 0, "Empty talentBossMap: PLAYER_TARGET_CHANGED makes 0 UnitIsPlayer calls")
    assertEqual(state.calls.getInstanceInfo, 0, "Empty talentBossMap: PLAYER_TARGET_CHANGED makes 0 GetInstanceInfo calls")

    -- Hero Medallion hooks: secret OnMouseUp & forbidden/unrelated GameTooltip
    local psf = MakeWidget("Frame", "PlayerSpellsFrame", env.UIParent)
    local tf = MakeWidget("Frame", nil, psf)
    local hc = MakeWidget("Frame", nil, tf)
    local heroBtn = MakeWidget("Button", nil, hc)
    hc.HeroSpecButton = heroBtn
    tf.HeroTalentsContainer = hc
    psf.TalentsFrame = tf
    env.DynamicTalent:EnsureHeroMedallionHooks()

    local okMouse = pcall(heroBtn:GetScript("OnMouseUp"), heroBtn, MakeSecret("btn"), MakeSecret("up"))
    assertTrue(okMouse, "Hero medallion OnMouseUp ignores secret button/upInside cleanly")

    -- Unrelated tooltip owner: AppendHeroSwapTooltipHint must not add lines
    local otherBtn = MakeWidget("Button", "OtherFrame", env.UIParent)
    env.GameTooltip:Show()
    env.GameTooltip:SetOwner(otherBtn)
    env.GameTooltip:ClearLines()
    env.GameTooltip:AddLine("Unrelated Tooltip")
    env.DynamicTalent.GetHeroSwapInfo = function() return { targetName = "Sunfury" } end
    heroBtn:GetScript("OnEnter")(heroBtn)
    assertEqual(#env.GameTooltip._lines, 1, "Hero medallion OnEnter does not append hint to unrelated tooltip owner")

    -- Forbidden GameTooltip: must not error
    env.GameTooltip._forbidden = true
    local okForb = pcall(heroBtn:GetScript("OnEnter"), heroBtn)
    assertTrue(okForb, "Hero medallion OnEnter skips forbidden GameTooltip cleanly")
end)

-- ============================================================================
-- T5. DynamicChat: 12.1.7 Hardening, EditBox Stability, Links & Invariant #1
-- ============================================================================
RunTest("T5: DynamicChat secret lists, EditBox chrome/anchor/combat-flush, BN_WHISPER middle-click, links & Invariant #1", function()
    local env, state, MakeWidget = CreateBaseEnv()
    local shared = {}

    -- Setup ChatFrame1 + EditBox + Tab + DockManager + Blizzard functions
    local gdm = MakeWidget("Frame", "GeneralDockManager", env.UIParent)
    gdm.DOCKED_CHAT_FRAMES = {}
    env.GeneralDockManager = gdm

    local cf1 = MakeWidget("ScrollingMessageFrame", "ChatFrame1", env.UIParent)
    cf1:Show()
    cf1.isDocked = true
    cf1.isLocked = true
    cf1.FontStringContainer = MakeWidget("Frame", nil, cf1)
    cf1.GetNumMessages = function() return 0 end
    cf1.GetMessageInfo = function() return nil end
    cf1.GetID = function() return 1 end
    table.insert(gdm.DOCKED_CHAT_FRAMES, cf1)
    env.SELECTED_DOCK_FRAME = cf1
    env.SELECTED_CHAT_FRAME = cf1

    local tab1 = MakeWidget("Button", "ChatFrame1Tab", gdm)
    tab1:Show()
    tab1.Text = tab1:CreateFontString()
    tab1.Text:SetText("General")

    local eb1 = MakeWidget("EditBox", "ChatFrame1EditBox", env.UIParent)
    eb1:Show()
    eb1.Left = eb1:CreateTexture()
    eb1.Mid = eb1:CreateTexture()
    eb1.Right = eb1:CreateTexture()
    eb1.NineSlice = MakeWidget("Frame", nil, eb1)
    eb1.header = eb1:CreateFontString()

    local eb2 = MakeWidget("EditBox", "ChatFrame3EditBox", env.UIParent)
    eb2:Show()

    env.FCF_Close = function() state.calls.fcfClose = state.calls.fcfClose + 1 end
    env.FCF_SetLocked = function(f, v) f.isLocked = v end
    env.FCF_SelectDockFrame = function(f) env.SELECTED_DOCK_FRAME = f end
    env.SetItemRef = function() end
    env.ChatEdit_UpdateHeader = function() end

    -- Saved custom chat position & dimensions
    env.DynamicChatDB = {
        enableSleekChatSkin = true,
        editBoxPosition = "BOTTOM",
        editBoxBackgroundMode = "ALWAYS",
        clickableURLs = true,
        chatFramePos = { point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 24, y = 18, width = 520, height = 260 },
    }

    LoadChunk(CORE_PATH, env, "DynamicSuite", shared)
    LoadChunk(CHAT_PATH, env, "DynamicSuite", shared)
    state.FireEvent("ADDON_LOADED", "DynamicSuite")
    state.FireEvent("PLAYER_LOGIN")

    -- (a) Invariant #1: 0 SetClampedToScreen(true) calls on ChatFrame1; isLocked preserved
    for _, v in ipairs(cf1._clampedCalls) do
        assertEqual(v, false, "ChatFrame1 must NEVER receive SetClampedToScreen(true)")
    end
    assertEqual(cf1.isLocked, true, "cf1.isLocked must remain untouched (true)")
    assertEqual(cf1:GetWidth(), 520, "Saved custom chat width preserved")
    assertEqual(cf1:GetHeight(), 260, "Saved custom chat height preserved")

    -- (b) Idempotent EditBox chrome re-strip: simulate Blizzard Edit Mode resetting alpha to 1.0
    assertEqual(eb1.Left:GetAlpha(), 0, "Initial EditBox Left texture stripped to 0")
    assertEqual(eb1.NineSlice:GetAlpha(), 0, "Initial EditBox NineSlice stripped to 0")
    eb1.Left:SetAlpha(1.0)
    eb1.NineSlice:SetAlpha(1.0)
    env.DynamicChat:ApplySleekChatSkin()
    assertEqual(eb1.Left:GetAlpha(), 0, "Re-shown EditBox Left texture must be re-stripped (no duplicate chrome)")
    assertEqual(eb1.NineSlice:GetAlpha(), 0, "Re-shown EditBox NineSlice must be re-stripped (no duplicate chrome)")

    -- (c) 2-point EditBox offset drift detected & fixed on idle pass
    eb1:ClearAllPoints()
    eb1:SetPoint("BOTTOMLEFT", cf1, "BOTTOMLEFT", -8, -4)
    eb1:SetPoint("TOPRIGHT", cf1, "BOTTOMRIGHT", 8, 40)
    env.DynamicChat:ApplySleekChatSkin()
    local p1, r1, rp1, x1, y1 = eb1:GetPoint(1)
    assertEqual(p1, "BOTTOMLEFT", "Drifted EditBox re-anchored point 1")
    assertEqual(r1, cf1, "Drifted EditBox anchored to ChatFrame1")
    assertEqual(x1, 0, "Drifted EditBox X offset corrected to 0")
    assertEqual(y1, 0, "Drifted EditBox Y offset corrected to 0")

    -- (d) Combat EditBox deferral flushes cleanly on PLAYER_REGEN_ENABLED
    state.inCombat = true
    eb1.Left:SetAlpha(1.0)
    eb1:ClearAllPoints()
    eb1:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 10, -10)
    env.DynamicChat:ApplySleekChatSkin()
    assertEqual(eb1.Left:GetAlpha(), 1.0, "In combat: EditBox chrome not mutated")
    state.inCombat = false
    state.FireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(eb1.Left:GetAlpha(), 0, "PLAYER_REGEN_ENABLED flushes deferred EditBox chrome strip")
    local fp1, fr1 = eb1:GetPoint(1)
    assertEqual(fp1, "BOTTOMLEFT", "PLAYER_REGEN_ENABLED flushes deferred EditBox anchor")
    assertEqual(fr1, cf1, "PLAYER_REGEN_ENABLED restores ChatFrame1 EditBox anchor")

    -- (e) OnEditBoxFocusGained on secondary EditBox -> OnEditBoxFocusLost re-anchors chatEditBoxSkin back to ChatFrame1
    env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusGained", eb2)
    env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusLost", eb2)
    -- Locate chatEditBoxSkin (frame with promptHint)
    local skinBar = nil
    for _, fr in ipairs(state.allFrames) do
        if fr.promptHint ~= nil and fr.leftBar ~= nil then
            skinBar = fr
            break
        end
    end
    assertTrue(skinBar ~= nil, "Found chatEditBoxSkin bar")
    local _, skinRel = skinBar:GetPoint(1)
    assertEqual(skinRel, cf1, "OnEditBoxFocusLost must re-anchor chatEditBoxSkin back to ChatFrame1 (no stranded bar)")

    -- (f) Secret GetNumMessages / secret messageTypeList / secret channelList in Copy Chat modal
    local secretCF = MakeWidget("ScrollingMessageFrame", "ChatFrame9", env.UIParent)
    secretCF.GetNumMessages = function() return MakeSecret("numMsgs") end
    secretCF.messageTypeList = MakeSecret("msgTypes")
    secretCF.channelList = MakeSecret("chanList")
    secretCF.GetID = function() return 9 end
    env.DynamicChat._sessionPlainLog = { { line = "Hello", msg = "Hello", author = "Pal", groupType = "SAY", msgType = "SAY" } }
    local okHist = pcall(env.DynamicChat.ShowFullChatHistoryModal, env.DynamicChat, secretCF)
    assertTrue(okHist, "ShowFullChatHistoryModal handles secret GetNumMessages & messageTypeList cleanly")

    -- (g) Middle-Click on temporary BN_WHISPER tab must NEVER call FCF_Close
    local cfBN = MakeWidget("ScrollingMessageFrame", "ChatFrame11", env.UIParent)
    cfBN:Show()
    cfBN.isTemporary = true
    cfBN.chatType = "BN_WHISPER"
    cfBN.chatTarget = MakeSecret("bnet-target")
    cfBN.isDocked = true
    table.insert(gdm.DOCKED_CHAT_FRAMES, cfBN)
    local tabBN = MakeWidget("Button", "ChatFrame11Tab", gdm)
    tabBN:Show()
    tabBN.Text = tabBN:CreateFontString()
    tabBN.Text:SetText(MakeSecret("bnet-label"))
    env.DynamicChat:ApplySleekChatSkin()
    state.calls.fcfClose = 0
    if type(tabBN:GetScript("OnClick")) == "function" then
        tabBN:GetScript("OnClick")(tabBN, "MiddleButton")
    end
    assertEqual(state.calls.fcfClose, 0, "Middle-Click on temporary BN_WHISPER tab must never call FCF_Close")

    -- (h) Blizzard Guild/Community Finder & Invite links are never filtered, altered, or intercepted
    assertEqual(state.calls.chatFilterRegs, 0, "DynamicChat registers 0 ChatFrame_AddMessageEventFilter hooks")
    local popupShown = false
    local origShowPopup = env.DynamicChat.ShowURLCopyPopup
    env.DynamicChat.ShowURLCopyPopup = function(...) popupShown = true; return origShowPopup(...) end
    env.SetItemRef("clubFinder:ClubFinder-1-987654", "|cffffd200|HclubFinder:ClubFinder-1-987654|h[Guild: Frostmourne Raiders]|h|r", "LeftButton")
    env.SetItemRef("clubTicket:AbCdEf123456", "|cffffd200|HclubTicket:AbCdEf123456|h[Join Community]|h|r", "LeftButton")
    assertEqual(popupShown, false, "SetItemRef hook never intercepts clubFinder or clubTicket links")

    -- Forbidden ItemRefTooltip on valid DynamicChat link must not error
    env.ItemRefTooltip._forbidden = true
    env.ItemRefTooltip.IsShown = function() error("Forbidden ItemRefTooltip:IsShown called!") end
    local okLink = pcall(env.SetItemRef, "addon:DynamicChat:https%3A//wago.io/test", "[https://wago.io/test]", "LeftButton")
    assertTrue(okLink, "HandleDynamicChatLinkClick skips forbidden ItemRefTooltip cleanly")
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
