-- ============================================================================
-- Headless Lua 5.1 Regression Suite:
--   T1: DynamicChat idle always-shown ChatFrame1EditBox vs active focus & BN_WHISPER
--   T2: DynamicSuite_UI footer & HUD Edit Mode Chat resize grip OnEnter accent (no nil call)
--   T3: DynamicTalent / DynamicBags / DynamicCursor / DynamicChat mouseover & hover perf
-- Pure ASCII Only.
-- ============================================================================

local CORE_PATH   = "DynamicSuite/DynamicSuite_Core.lua"
local UI_PATH     = "DynamicSuite/DynamicSuite_UI.lua"
local CHAT_PATH   = "DynamicSuite/Modules/DynamicChat.lua"
local TALENT_PATH = "DynamicSuite/Modules/DynamicTalent.lua"
local BAGS_PATH   = "DynamicSuite/Modules/DynamicBags.lua"
local CURSOR_PATH = "DynamicSuite/Modules/DynamicCursor.lua"

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

-- ============================================================================
-- Shared WoW Harness Factory
-- ============================================================================
local function CreateHarness(opts)
    opts = opts or {}
    local env = {}
    setmetatable(env, { __index = _G })
    env._G = env

    local state = {
        now = 100.0,
        inCombat = false,
        inRaid = false,
        resting = false,
        activeEditBox = nil,
        tooltipOwner = nil,
        tooltipSetText = nil,
        tooltipLines = {},
        tooltipDoubleLines = {},
        tooltipPostCalls = {},
        eventFrames = {},
        allFrames = {},
        timers = {},
        secretValues = {},
        calls = {
            ejNumTiers = 0,
            getNamePlates = 0,
            setPoint = 0,
            clearAllPoints = 0,
        },
        registryListeners = {},
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
    env.strsplit = function(delim, str)
        local out = {}
        for part in string.gmatch(tostring(str or ""), "([^" .. tostring(delim) .. "]+)") do
            out[#out + 1] = part
        end
        return unpack(out)
    end
    env.GetTime = function() return state.now end
    env.time = function() return math.floor(1700000000 + state.now) end
    env.UnitName = function(u)
        if u == "player" then return "Dentee" end
        if u == "mouseover" then return "Training Dummy" end
        if u == "target" then return "Training Dummy" end
        return "Mob"
    end
    env.UnitClass = function() return "Mage", "MAGE", 8 end
    env.UnitLevel = function() return 80 end
    env.UnitIsPlayer = function() return false end
    env.UnitIsDeadOrGhost = function() return false end
    env.UnitExists = function(u) return u == "player" or u == "mouseover" or u == "target" end
    env.UnitGUID = function() return "Player-1234-0001" end
    env.GetRealmName = function() return "Frostmourne" end
    env.GetSpecialization = function() return 1 end
    env.GetSpecializationInfo = function() return 64, "Frost", "", 135846 end
    env.IsInRaid = function() return state.inRaid end
    env.IsInGroup = function() return state.inRaid end
    env.IsInInstance = function()
        if state.inRaid then return true, "raid" end
        return false, "none"
    end
    env.GetInstanceInfo = function()
        if state.inRaid then return "Manaforge Omega", "raid", 16, "Mythic", 20, 0, false, 2810 end
        return "Eastern Kingdoms", "none", 0, "", 0, 0, false, 0
    end
    env.IsResting = function() return state.resting end
    env.InCombatLockdown = function() return state.inCombat end
    env.IsShiftKeyDown = function() return false end
    env.IsControlKeyDown = function() return false end
    env.IsAltKeyDown = function() return false end
    env.IsMouseButtonDown = function() return false end
    env.GetCursorPosition = function() return 500, 400 end
    env.GetScreenWidth = function() return 1920 end
    env.GetScreenHeight = function() return 1080 end
    env.GetPhysicalScreenSize = function() return 1920, 1080 end
    env.GetLocale = function() return "enUS" end
    env.GetMouseFoci = function() return {} end
    env.GetCursorInfo = function() return nil end
    env.GetMoney = function() return 0 end
    env.GetGuildBankMoney = function() return 0 end
    env.GetGuildBankWithdrawMoney = function() return 0 end
    env.CanWithdrawGuildBankMoney = function() return false end
    env.IsInGuild = function() return false end
    env.GetCurrentCombatTextEventInfo = function() return end
    env.SpellIsTargeting = function() return false end
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

    env.issecretvalue = function(v) return state.secretValues[v] == true end
    env.canaccessvalue = function(v) return state.secretValues[v] ~= true end
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
        After = function(delay, fn)
            table.insert(state.timers, { delay = delay, fn = fn })
        end,
        NewTimer = function(delay, fn)
            local entry = { delay = delay, fn = fn }
            table.insert(state.timers, entry)
            return { Cancel = function() entry.cancelled = true end }
        end,
        NewTicker = function(delay, fn)
            return { Cancel = function() end, fn = fn }
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
        GetAddOnInfo = function(n) return n, n, "", true, "INSECURE", false end,
        GetAddOnEnableState = function() return 2 end,
        GetNumAddOns = function() return 0 end,
    }
    env.GetNumAddOns = function() return 0 end
    env.C_Map = { GetMapInfo = function() return { name = "Dornogal" } end, GetBestMapForUnit = function() return 2339 end }
    env.C_NamePlate = {
        GetNamePlates = function()
            state.calls.getNamePlates = state.calls.getNamePlates + 1
            return {}
        end,
    }
    env.EJ_GetNumTiers = function()
        state.calls.ejNumTiers = state.calls.ejNumTiers + 1
        return 1
    end
    env.EJ_GetCurrentTier = function() return 1 end
    env.EJ_SelectTier = function() end
    env.EJ_GetInstanceByIndex = function(i)
        if i == 1 then return 9001, "Manaforge Omega" end
        return nil
    end
    env.EJ_SelectInstance = function() end
    env.EJ_GetEncounterInfoByIndex = function(j)
        if j == 1 then return "Plexus Sentinel", nil, 5001 end
        return nil
    end
    env.C_Container = {
        GetContainerNumSlots = function() return 0 end,
        GetContainerNumFreeSlots = function() return 0, 0 end,
        GetContainerItemInfo = function() return nil end,
    }
    env.C_CurrencyInfo = { GetBackpackCurrencyInfo = function() return nil end, GetCurrencyListSize = function() return 0 end }
    env.C_Bank = { FetchDepositedMoney = function() return 0 end, CanUseBank = function() return false end }
    env.C_Item = {
        GetItemInfo = function(id)
            return "Item " .. tostring(id), "|cffffffff|Hitem:" .. tostring(id) .. "|h[Item]|h|r", 1, 1, 1, "Miscellaneous", "Junk", 20, "", 134400
        end,
        GetItemCount = function() return 1 end,
    }
    env.C_ClassTalents = {
        GetActiveConfigID = function() return 1 end,
        GetConfigIDsBySpecID = function() return { 1 } end,
        GetLastSelectedSavedConfigID = function() return 1 end,
    }
    env.C_Traits = {
        GetConfigInfo = function() return { ID = 1, name = "Raid Build" } end,
        GenerateImportString = function() return "EXPORT_ABC" end,
    }
    env.C_MythicPlus = { GetOwnedKeystoneLevel = function() return 0 end }
    env.C_ChallengeMode = { IsChallengeModeActive = function() return false end }
    env.C_PetBattles = { IsInBattle = function() return false end }
    env.TooltipDataProcessor = {
        AddTooltipPostCall = function(dataType, fn)
            table.insert(state.tooltipPostCalls, { dataType = dataType, fn = fn })
        end,
    }
    env.EventRegistry = {
        RegisterCallback = function(_, ev, fn, owner)
            state.registryListeners[ev] = state.registryListeners[ev] or {}
            table.insert(state.registryListeners[ev], { fn = fn, owner = owner })
        end,
        TriggerEvent = function(_, ev, ...)
            for _, entry in ipairs(state.registryListeners[ev] or {}) do
                if entry.owner ~= nil then
                    entry.fn(entry.owner, ...)
                else
                    entry.fn(...)
                end
            end
        end,
    }

    env.ChatEdit_GetActiveWindow = function() return state.activeEditBox end
    env.ChatEdit_ActivateChat = function(eb) state.activeEditBox = eb end
    env.ChatEdit_UpdateHeader = function() end
    env.ChatEdit_OnTextChanged = function() end
    env.ChatEdit_OnSpacePressed = function() end
    env.ChatFrameEditBoxMixin = { OnTextChanged = function() end, OnSpacePressed = function() end }
    env.FCF_SelectDockFrame = function() end
    env.FCF_OpenTemporaryWindow = function() return nil end
    env.FCF_Close = function() end
    env.FCF_GetCurrentChatFrame = function() return env.ChatFrame1 end
    env.FCFDock_UpdateTabs = function() end
    env.FCF_SetTabPosition = function() end
    env.UIFrameIsFading = function(fr) return fr and fr._isFading == true end
    env.UIFrameFadeOut = function() end
    env.UIFrameFadeIn = function() end
    env.UIFrameFlash = function() end
    env.UIFrameFlashStop = function() end
    env.ChatFrameUtil = {}
    env.GameTooltip_SetDefaultAnchor = function(tip, owner)
        tip:ClearAllPoints()
        tip:SetPoint("BOTTOMRIGHT", owner or env.UIParent, "BOTTOMRIGHT", -13, 13)
    end

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
            _minVal = 0,
            _maxVal = 0,
            _val = 0,
            _hasFocus = false,
            _setFontCalls = {},
            _vertexColor = nil,
            _mouseOver = false,
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
        function w:Show()
            self._shown = true
            if self._scripts.OnShow then self._scripts.OnShow(self) end
        end
        function w:Hide()
            self._shown = false
            if self._scripts.OnHide then self._scripts.OnHide(self) end
        end
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
        function w:GetCenter() return 500, 400 end
        function w:GetLeft() return 200 end
        function w:GetRight() return 200 + self._width end
        function w:GetTop() return 400 + self._height end
        function w:GetBottom() return 400 end
        function w:SetFrameStrata(s) self._strata = s end
        function w:GetFrameStrata() return self._strata end
        function w:SetFrameLevel(l) self._level = l end
        function w:GetFrameLevel() return self._level end
        function w:ClearAllPoints()
            state.calls.clearAllPoints = state.calls.clearAllPoints + 1
            self._points = {}
        end
        function w:SetPoint(pt, relTo, relPt, x, y)
            state.calls.setPoint = state.calls.setPoint + 1
            table.insert(self._points, { pt, relTo, relPt, x, y })
        end
        function w:SetAllPoints() end
        function w:GetPoint(i)
            local p = self._points[i or 1]
            if p then return p[1], p[2], p[3], p[4], p[5] end
            return "CENTER", env.UIParent, "CENTER", 0, 0
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
        function w:StartSizing() end
        function w:StopMovingOrSizing() end
        function w:Raise() end
        function w:Enable() end
        function w:Disable() end
        function w:SetEnabled() end
        function w:IsEnabled() return true end
        function w:IsMouseOver() return self._mouseOver == true end
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
        function w:SetFont(p, sz, fl)
            table.insert(self._setFontCalls, { p, sz, fl })
            self._font = p; self._fontSize = sz; self._fontFlags = fl
            return true
        end
        function w:GetFont() return self._font or "Fonts\\FRIZQT__.TTF", self._fontSize or 12, self._fontFlags or "" end
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
        function w:SetVertexColor(r, g, b, a) self._vertexColor = { r, g, b, a } end
        function w:SetNormalTexture() end
        function w:SetPushedTexture() end
        function w:SetHighlightTexture() end
        function w:GetNormalTexture() return self:CreateTexture() end
        function w:GetHighlightTexture() return self:CreateTexture() end
        function w:SetNormalFontObject() end
        function w:GetFontString() return nil end
        function w:SetOrientation() end
        function w:SetMinMaxValues(mn, mx) self._minVal = mn or 0; self._maxVal = mx or 0 end
        function w:GetMinMaxValues() return self._minVal or 0, self._maxVal or 0 end
        function w:SetValueStep() end
        function w:SetObeyStepOnDrag() end
        function w:SetValue(v) self._val = v or 0 end
        function w:GetValue() return self._val or 0 end
        function w:SetThumbTexture(t) self._thumb = t end
        function w:GetThumbTexture() return self._thumb or self:CreateTexture() end
        function w:SetScrollChild(c) self._scrollChild = c end
        function w:GetScrollChild() return self._scrollChild end
        function w:SetVerticalScroll(v) self._vScroll = v or 0 end
        function w:GetVerticalScroll() return self._vScroll or 0 end
        function w:GetVerticalScrollRange() return 0 end
        function w:UpdateScrollChildRect() end
        function w:SetScrollOffset(v) self._scrollOffset = v or 0 end
        function w:GetScrollOffset() return self._scrollOffset or 0 end
        function w:GetMaxScrollRange() return self._maxScroll or 0 end
        function w:ScrollUp() end
        function w:ScrollDown() end
        function w:ScrollToBottom() end
        function w:AtBottom() return true end
        function w:GetNumMessages() return #self._messages end
        function w:GetMessageInfo(idx)
            local m = self._messages[idx]
            if not m then return nil end
            return m[1], m[2], m[3], m[4], m[5]
        end
        function w:AddMessage(txt) table.insert(self._messages, { txt, 1, 1, 1, 1 }) end
        function w:Clear() self._messages = {} end
        function w:RegisterEvent(ev) self._events[ev] = true end
        function w:RegisterUnitEvent(ev) self._events[ev] = true end
        function w:UnregisterEvent(ev) self._events[ev] = nil end
        function w:UnregisterAllEvents() self._events = {} end
        function w:SetScript(ev, fn) self._scripts[ev] = fn end
        function w:GetScript(ev) return self._scripts[ev] end
        function w:HookScript(ev, fn)
            local prev = self._scripts[ev]
            self._scripts[ev] = function(...)
                if prev then prev(...) end
                fn(...)
            end
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
                CreateAnimation = function()
                    return { SetDuration = function() end, SetOrder = function() end, SetFromAlpha = function() end, SetToAlpha = function() end }
                end,
                SetScript = function() end,
                Play = function() end,
                Pause = function() end,
                Stop = function() end,
            }
        end
        table.insert(state.allFrames, w)
        if name then env[name] = w end
        return w
    end

    env.MakeWidget = MakeWidget
    env.UIParent = MakeWidget("Frame", "UIParent", nil)
    env.UIParent:SetSize(1920, 1080)
    env.UIParent._shown = true

    env.CreateFrame = function(wType, name, parent)
        local fr = MakeWidget(wType, name, parent)
        table.insert(state.eventFrames, fr)
        return fr
    end

    env.DEFAULT_CHAT_FRAME = { AddMessage = function() end }

    local gt = MakeWidget("GameTooltip", "GameTooltip", env.UIParent)
    gt.SetOwner = function(self, owner, anchor)
        state.tooltipOwner = owner
        state.tooltipSetText = nil
        state.tooltipLines = {}
        state.tooltipDoubleLines = {}
    end
    gt.SetText = function(_, text)
        state.tooltipSetText = text
    end
    gt.AddLine = function(_, text, r, g, b)
        table.insert(state.tooltipLines, { text = text, r = r, g = g, b = b })
    end
    gt.AddDoubleLine = function(_, left, right)
        table.insert(state.tooltipDoubleLines, { left = left, right = right })
    end
    gt.GetItem = function()
        if state.tooltipItemLink then
            return "Test Item", state.tooltipItemLink, state.tooltipItemID
        end
        return nil
    end

    local function FireEvent(ev, ...)
        for _, ef in ipairs(state.eventFrames) do
            if ef._events[ev] and ef._scripts and ef._scripts.OnEvent then
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

    return {
        env = env,
        state = state,
        MakeWidget = MakeWidget,
        FireEvent = FireEvent,
        FlushTimers = FlushTimers,
    }
end

local function LoadChunk(path, env, addonName, sharedTbl)
    local chunk, err = loadfile(path)
    assertTrue(chunk ~= nil, "Failed to load " .. path .. ": " .. tostring(err))
    setfenv(chunk, env)
    return chunk(addonName, sharedTbl)
end

local function SetupChatGlobals(h)
    local env = h.env
    env.GeneralDockManager = h.MakeWidget("Frame", "GeneralDockManager", env.UIParent)
    env.GeneralDockManager._shown = true
    env.GeneralDockManagerScrollFrame = h.MakeWidget("ScrollFrame", "GeneralDockManagerScrollFrame", env.GeneralDockManager)
    env.GeneralDockManagerScrollFrameChild = h.MakeWidget("Frame", "GeneralDockManagerScrollFrameChild", env.GeneralDockManagerScrollFrame)
    env.GeneralDockManager.primary = nil
    env.GeneralDockManager.selected = nil
    env.DOCKED_CHAT_FRAMES = {}

    local cf1 = h.MakeWidget("ScrollingMessageFrame", "ChatFrame1", env.UIParent)
    cf1._shown = true
    cf1.name = "General"
    cf1.isDocked = 1
    cf1.FontStringContainer = h.MakeWidget("Frame", "ChatFrame1FontStringContainer", cf1)
    cf1.ScrollBar = h.MakeWidget("Slider", "ChatFrame1ScrollBar", cf1)
    cf1.ScrollToBottomButton = h.MakeWidget("Button", "ChatFrame1ScrollToBottomButton", cf1)
    cf1.Background = h.MakeWidget("Texture", "ChatFrame1Background", cf1)
    cf1.buttonFrame = h.MakeWidget("Frame", "ChatFrame1ButtonFrame", cf1)
    cf1.ResizeButton = h.MakeWidget("Button", "ChatFrame1ResizeButton", cf1)

    local tab1 = h.MakeWidget("Button", "ChatFrame1Tab", env.GeneralDockManager)
    tab1._shown = true
    tab1:SetText("General")
    tab1.Text = tab1:CreateFontString()
    tab1.Text:SetText("General")
    tab1.GetFontString = function() return tab1.Text end
    cf1.tab = tab1

    local eb1 = h.MakeWidget("EditBox", "ChatFrame1EditBox", env.UIParent)
    -- Critical Retail behaviour: ChatFrame1EditBox stays shown while idle!
    eb1._shown = true
    eb1._hasFocus = false
    eb1._attrs.chatType = "SAY"
    eb1.header = eb1:CreateFontString()
    eb1.header:SetText("Say: ")
    eb1.focusLeft = h.MakeWidget("Texture", "ChatFrame1EditBoxFocusLeft", eb1)
    eb1.focusMid = h.MakeWidget("Texture", "ChatFrame1EditBoxFocusMid", eb1)
    eb1.focusRight = h.MakeWidget("Texture", "ChatFrame1EditBoxFocusRight", eb1)
    eb1.FocusLeft = eb1.focusLeft
    eb1.FocusMid = eb1.focusMid
    eb1.FocusRight = eb1.focusRight
    cf1.editBox = eb1

    env.GeneralDockManager.primary = cf1
    env.GeneralDockManager.selected = cf1
    table.insert(env.DOCKED_CHAT_FRAMES, cf1)
    return cf1, eb1
end

-- ============================================================================
-- T1: DynamicChat Idle Always-Shown EditBox vs Active Typing Focus & BN_WHISPER
-- ============================================================================
RunTest("T1a: Idle always-shown ChatFrame1EditBox IS stripped, anchored & skinned; active focus defers & flushes cleanly", function()
    local h = CreateHarness()
    local sharedTbl = {}
    local cf1, eb1 = SetupChatGlobals(h)

    LoadChunk(CORE_PATH, h.env, "DynamicSuite", sharedTbl)
    LoadChunk(CHAT_PATH, h.env, "DynamicSuite", sharedTbl)

    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")
    h.FlushTimers()

    local dc = h.env.DynamicChat
    assertTrue(dc ~= nil, "DynamicChat must load")
    local db = h.env.DynamicChatDB
    db.editBoxPosition = "BOTTOM"
    dc:ApplySleekChatSkin()
    dc:ApplySavedChatFramePosition()

    -- Even though eb1:IsShown() == true (Retail idle state), it is NOT focused -> skin & chrome strip must apply!
    assertEqual(eb1._shown, true, "Retail idle ChatFrame1EditBox remains shown")
    assertEqual(eb1.FocusLeft:GetAlpha(), 0, "Idle FocusLeft Blizzard chrome stripped to 0")
    local pt, rel = eb1:GetPoint(1)
    assertEqual(pt, "BOTTOMLEFT", "BOTTOM position anchors eb1 BOTTOMLEFT inside ChatFrame1")
    assertEqual(rel, cf1, "eb1 anchored to ChatFrame1")

    -- Simulate user focusing eb1 for typing; then request TOP anchor + font change
    eb1._hasFocus = true
    h.state.activeEditBox = eb1
    h.env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusGained", eb1)

    local fontCallsBeforeFocus = #eb1._setFontCalls
    db.editBoxPosition = "TOP"
    dc:ApplySleekChatSkin()
    dc:ApplySavedChatFramePosition()

    -- Must NOT mutate focused editBox
    local ptWhileFocused = eb1:GetPoint(1)
    assertEqual(ptWhileFocused, "BOTTOMLEFT", "Focused eb1 must NOT be moved mid-typing")
    assertEqual(#eb1._setFontCalls, fontCallsBeforeFocus, "Focused eb1 must NOT receive SetFont calls")

    -- Losing focus (OOC, SAY) flushes deferred anchor + passive skin immediately
    eb1._hasFocus = false
    h.state.activeEditBox = nil
    h.env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusLost", eb1)

    local ptAfterBlur = eb1:GetPoint(1)
    assertEqual(ptAfterBlur, "TOPLEFT", "OnEditBoxFocusLost flushes pending TOP anchor immediately")
end)

RunTest("T1b: BN_WHISPER / secret editBox never mutated even across focus lost", function()
    local h = CreateHarness()
    local sharedTbl = {}
    local _, eb1 = SetupChatGlobals(h)

    LoadChunk(CORE_PATH, h.env, "DynamicSuite", sharedTbl)
    LoadChunk(CHAT_PATH, h.env, "DynamicSuite", sharedTbl)

    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")
    h.FlushTimers()

    local dc = h.env.DynamicChat
    local db = h.env.DynamicChatDB
    db.editBoxPosition = "BOTTOM"
    dc:ApplySleekChatSkin()
    dc:ApplySavedChatFramePosition()

    -- Switch editBox to BN_WHISPER + secret target
    eb1._attrs.chatType = "BN_WHISPER"
    local secretTarget = "SecretBNetFriend"
    h.state.secretValues[secretTarget] = true
    eb1._attrs.tellTarget = secretTarget
    h.env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusGained", eb1)

    local fontCallsBefore = #eb1._setFontCalls
    db.editBoxPosition = "TOP"
    dc:ApplySleekChatSkin()
    dc:ApplySavedChatFramePosition()

    -- End focus while still BN_WHISPER -> must stay completely untouched!
    eb1._hasFocus = false
    h.state.activeEditBox = nil
    h.env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusLost", eb1)

    local pt = eb1:GetPoint(1)
    assertEqual(pt, "BOTTOMLEFT", "BN_WHISPER eb1 anchor must NOT be touched even on FocusLost flush")
    assertEqual(#eb1._setFontCalls, fontCallsBefore, "BN_WHISPER eb1 must NOT receive SetFont calls")
end)

-- ============================================================================
-- T2: DynamicSuite_UI Main Footer & HUD Edit Mode Chat Resize Grip OnEnter
-- ============================================================================
RunTest("T2: DynamicSuite_UI footer and HUD Edit Mode Chat resize grips hover with zero nil-call crashes", function()
    local h = CreateHarness()
    local sharedTbl = {}
    SetupChatGlobals(h)

    LoadChunk(CORE_PATH, h.env, "DynamicSuite", sharedTbl)
    LoadChunk(CHAT_PATH, h.env, "DynamicSuite", sharedTbl)
    LoadChunk(UI_PATH, h.env, "DynamicSuite", sharedTbl)

    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")
    h.FlushTimers()

    assertTrue(type(sharedTbl.CreateMainConfigUI) == "function", "CreateMainConfigUI registered")
    sharedTbl.CreateMainConfigUI()

    local function FindButtonByTooltip(expectedTitle)
        for _, fr in ipairs(h.state.allFrames) do
            if fr._type == "Button" and type(fr._scripts.OnEnter) == "function" then
                h.state.tooltipSetText = nil
                local ok = pcall(fr._scripts.OnEnter, fr)
                if ok and h.state.tooltipSetText == expectedTitle then
                    return fr
                end
            end
        end
        return nil
    end

    local footerGrip = FindButtonByTooltip("Resize DynamicSuite")
    assertTrue(footerGrip ~= nil, "Footer resize grip found and hovered cleanly without nil crash")
    if footerGrip._scripts.OnLeave then
        footerGrip._scripts.OnLeave(footerGrip)
    end

    -- Enter HUD Edit Mode on CHAT and hover its resize grip
    assertTrue(type(sharedTbl.EnterHudEditMode) == "function", "EnterHudEditMode available")
    sharedTbl.EnterHudEditMode("CHAT")
    local chatGrip = FindButtonByTooltip("Resize Chat Frame")
    assertTrue(chatGrip ~= nil, "HUD Edit Mode Chat resize grip found and hovered cleanly without nil crash")
    if chatGrip._scripts.OnLeave then
        chatGrip._scripts.OnLeave(chatGrip)
    end
end)

-- ============================================================================
-- T3: Mouseover & Tooltip Hover Stutter Fixes
-- ============================================================================
RunTest("T3a: DynamicTalent skips non-raid / resting mouseover & target scans and gates TryEnrichWithEJ", function()
    local h = CreateHarness()
    local sharedTbl = {}
    LoadChunk(CORE_PATH, h.env, "DynamicSuite", sharedTbl)
    LoadChunk(TALENT_PATH, h.env, "DynamicSuite", sharedTbl)

    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")
    local dt = h.env.DynamicTalent
    assertTrue(dt ~= nil, "DynamicTalent loaded")

    -- Replace RefreshPrepBar with spy
    local refreshCalls = 0
    dt.RefreshPrepBar = function() refreshCalls = refreshCalls + 1 end

    -- Outdoors / not in raid, no custom non-raid boss binds
    h.state.inRaid = false
    h.state.resting = false
    h.state.calls.ejNumTiers = 0
    h.state.calls.getNamePlates = 0
    refreshCalls = 0

    for _ = 1, 20 do
        h.FireEvent("UPDATE_MOUSEOVER_UNIT")
        h.FireEvent("PLAYER_TARGET_CHANGED")
    end
    assertEqual(h.state.calls.ejNumTiers, 0, "Zero EJ scans during passive mouseover/target checks outdoors")
    assertEqual(h.state.calls.getNamePlates, 0, "Zero GetNamePlates scans outdoors without custom boss binds")
    assertEqual(refreshCalls, 0, "Zero Prep Bar refreshes outdoors without custom boss binds")

    -- Inside raid, passive events still never invoke EJ_GetNumTiers
    h.state.inRaid = true
    h.FireEvent("UPDATE_MOUSEOVER_UNIT")
    h.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
    h.FireEvent("PLAYER_SOFT_ENEMY_CHANGED")
    assertEqual(h.state.calls.ejNumTiers, 0, "Zero EJ scans on passive raid mouseover/nameplate/soft-enemy")

    -- Explicit EJ load triggers enrichment cleanly
    h.FireEvent("ADDON_LOADED", "Blizzard_EncounterJournal")
    assertTrue(h.state.calls.ejNumTiers >= 1, "Blizzard_EncounterJournal load allows TryEnrichWithEJ")
end)

RunTest("T3b: DynamicBags O(1) tooltip count lookup never rebuilds on SnapshotBags or per hover", function()
    local h = CreateHarness()
    local sharedTbl = {}
    LoadChunk(CORE_PATH, h.env, "DynamicSuite", sharedTbl)
    LoadChunk(BAGS_PATH, h.env, "DynamicSuite", sharedTbl)

    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    local dbag = h.env.DynamicBags
    assertTrue(dbag and dbag.U, "DynamicBags loaded")
    dbag.InitDB()

    -- Seed alt + warband inventory matching real vault schema BEFORE login pre-warm
    local testLink = "|cffffffff|Hitem:19019|h[Thunderfury]|h|r"
    h.env.DynamicBagsDB.vault = {
        characters = {
            ["Dentee-Frostmourne"] = {
                name = "Dentee",
                realm = "Frostmourne",
                class = "MAGE",
                bags = { { 19019, testLink, 1 } },
                bank = { { 19019, testLink, 2 } },
            },
            ["Altpal-Frostmourne"] = {
                name = "Altpal",
                realm = "Frostmourne",
                class = "PALADIN",
                bags = { { 19019, testLink, 3 } },
                bank = { { 19019, testLink, 1 } },
            },
        },
        warbandBank = {
            items = { { 19019, testLink, 4 } },
        },
    }

    local buildCount = 0
    local origBuild = dbag.U.BuildCountIndex
    dbag.U.BuildCountIndex = function(...)
        buildCount = buildCount + 1
        return origBuild(...)
    end

    h.FireEvent("PLAYER_LOGIN")
    h.FlushTimers()
    assertEqual(buildCount, 1, "Login pre-warm seeds count index once")
    buildCount = 0

    -- SnapshotBags must NOT invalidate cross-char tooltip index
    h.env.DynamicBagsDB.tooltipCounts = true
    dbag.U.SnapshotBags()
    assertTrue(#h.state.tooltipPostCalls >= 1, "TooltipDataProcessor post-call registered")
    local itemHook = h.state.tooltipPostCalls[1].fn
    local itemData = { id = 19019 }

    for _ = 1, 50 do
        h.state.tooltipDoubleLines = {}
        itemHook(h.env.GameTooltip, itemData)
    end
    assertEqual(buildCount, 0, "50 tooltip hovers after SnapshotBags trigger 0 BuildCountIndex rebuilds")
    assertTrue(#h.state.tooltipDoubleLines >= 2, "Pre-formatted alt & warband lines appended cleanly")

    -- In combat -> skipped cleanly
    h.state.inCombat = true
    h.state.tooltipDoubleLines = {}
    itemHook(h.env.GameTooltip, itemData)
    assertEqual(#h.state.tooltipDoubleLines, 0, "In-combat tooltip hover adds 0 lines")
end)

RunTest("T3c: DynamicCursor GameTooltip_SetDefaultAnchor caches disabled state with 0 per-hover pcall overhead", function()
    local h = CreateHarness()
    local sharedTbl = {}
    local disabledLookupCalls = 0

    LoadChunk(CORE_PATH, h.env, "DynamicSuite", sharedTbl)
    local suiteObj = h.env.DynamicSuite
    local origIsDisabled = suiteObj.IsModuleDisabled
    suiteObj.IsModuleDisabled = function(selfObj, key)
        disabledLookupCalls = disabledLookupCalls + 1
        return origIsDisabled and origIsDisabled(selfObj, key) or false
    end

    LoadChunk(CURSOR_PATH, h.env, "DynamicSuite", sharedTbl)
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")
    h.env.DynamicCursorDB.tooltipEnabled = true
    h.env.DynamicCursor.SyncAllEngines()

    disabledLookupCalls = 0
    h.state.calls.setPoint = 0
    for _ = 1, 50 do
        h.env.GameTooltip_SetDefaultAnchor(h.env.GameTooltip, h.env.UIParent)
    end
    assertEqual(disabledLookupCalls, 0, "0 IsModuleDisabled calls across 50 tooltip hovers")
    -- Base GameTooltip_SetDefaultAnchor + SmartTooltip hook each call SetPoint once per hover (2 * 50 = 100)
    assertEqual(h.state.calls.setPoint, 100, "Smart Tooltip anchored 50 times cleanly when enabled")

    -- Disable module in Suite -> updates cached flag immediately
    h.env.DynamicSuiteDB.global.disabledModules["DynamicCursor"] = true
    local mod = suiteObj.modules["DynamicCursor"] or suiteObj.modules["cursor"]
    assertTrue(mod and type(mod.OnDisableInSuite) == "function", "DynamicCursor OnDisableInSuite exists")
    mod.OnDisableInSuite()
    disabledLookupCalls = 0

    -- Hook still skips anchoring immediately (default hook calls SetPoint, SmartTooltip must NOT add a 2nd SetPoint)
    local ptBefore = h.state.calls.setPoint
    h.env.GameTooltip_SetDefaultAnchor(h.env.GameTooltip, h.env.UIParent)
    assertEqual(disabledLookupCalls, 0, "0 IsModuleDisabled calls inside GameTooltip_SetDefaultAnchor when disabled")
    assertEqual(h.state.calls.setPoint - ptBefore, 1, "Only base GameTooltip_SetDefaultAnchor SetPoint runs when disabled")
end)

RunTest("T3d: DynamicChat custom scrollbar attaches OnUpdate only while shown with overflow", function()
    local h = CreateHarness()
    local sharedTbl = {}
    local cf1 = SetupChatGlobals(h)

    LoadChunk(CORE_PATH, h.env, "DynamicSuite", sharedTbl)
    LoadChunk(CHAT_PATH, h.env, "DynamicSuite", sharedTbl)

    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")
    h.FlushTimers()

    local dc = h.env.DynamicChat
    local db = h.env.DynamicChatDB
    db.showChatScrollBar = true
    db.autoHideChatScrollBar = true
    dc:ApplySleekChatSkin()

    -- Locate custom scrollbar created by ReskinChatScrollBarAndBottomButton
    local scrollBar = nil
    for _, fr in ipairs(h.state.allFrames) do
        if type(fr.NotifyScrollActivity) == "function" and type(fr.UpdateState) == "function" then
            scrollBar = fr
            break
        end
    end
    assertTrue(scrollBar ~= nil, "DynamicChat custom scrollbar created on ChatFrame1")

    -- With maxScroll == 0, OnUpdate must be nil
    assertEqual(scrollBar:GetScript("OnUpdate"), nil, "OnUpdate detached when ChatFrame1 has no overflow")

    -- Give ChatFrame1 scrollable overflow and refresh skin -> OnUpdate attaches while shown
    cf1._maxScroll = 100
    dc:ApplySleekChatSkin()
    assertTrue(type(scrollBar:GetScript("OnUpdate")) == "function", "OnUpdate attached while shown with overflow and autoHide")

    -- Hiding ChatFrame1 / scrollbar clears OnUpdate cleanly
    scrollBar:Hide()
    assertEqual(scrollBar:GetScript("OnUpdate"), nil, "OnUpdate cleared immediately on OnHide")
end)

-- ============================================================================
-- T4: Chat tab hover (OnEnter / OnLeave) must never re-run the full EnsureDB() migration per hover
-- ============================================================================
RunTest("T4: DynamicChat chat tab OnEnter/OnLeave x100 never re-run EnsureDB / CopyDefaults per hover", function()
    local h = CreateHarness()
    local sharedTbl = {}
    local cf1 = SetupChatGlobals(h)
    LoadChunk(CORE_PATH, h.env, "DynamicSuite", sharedTbl)
    LoadChunk(CHAT_PATH, h.env, "DynamicSuite", sharedTbl)
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")
    h.FlushTimers()

    local dc = h.env.DynamicChat
    assertTrue(dc ~= nil, "DynamicChat must load")
    dc:ApplySleekChatSkin()
    h.FlushTimers()

    local tab1 = h.env.ChatFrame1Tab
    assertTrue(type(tab1._scripts.OnEnter) == "function", "Chat tab OnEnter hook installed")

    -- EnsureDB() always (re)writes whisperTriggerMode; a proxy DB counts those writes.
    local real = h.env.DynamicChatDB
    local ensureRuns = 0
    local proxy = setmetatable({}, {
        __index = real,
        __newindex = function(_, k, v)
            if k == "whisperTriggerMode" then ensureRuns = ensureRuns + 1 end
            real[k] = v
        end,
    })
    h.env.DynamicChatDB = proxy
    h.env.InCombatLockdown = function() return false end
    local gt = {}
    for _, m in ipairs({ "SetOwner", "ClearLines", "AddLine", "AddDoubleLine", "Show", "Hide" }) do
        gt[m] = function() end
    end
    gt.GetOwner = function() return nil end
    gt.IsForbidden = function() return false end
    h.env.GameTooltip = gt

    -- First hover may legitimately run EnsureDB once to bind the new table.
    tab1._scripts.OnEnter(tab1)
    tab1._scripts.OnLeave(tab1)
    ensureRuns = 0
    for _ = 1, 100 do
        tab1._scripts.OnEnter(tab1)
        tab1._scripts.OnLeave(tab1)
    end
    assertEqual(ensureRuns, 0, "100 chat tab hovers must run EnsureDB() zero extra times")
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
