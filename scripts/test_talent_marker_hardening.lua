-- ============================================================================
-- Headless Lua 5.1 Regression Suite: DynamicTalent & DynamicMarker 12.1.7 Hardening
-- Covers:
--   1. DynamicTalent Backdrop Studio & Dock combat deferral + PLAYER_REGEN_ENABLED flush
--   2. DynamicTalent combat popup cleanup + deferred SaveConfig across combat
--   3. DynamicTalent secret-value guards (trait nodes, config IDs, TLM API, tooltip lines)
--   4. DynamicMarker keybind capture combat abort, Right-Click combat block, OnHide & modal safety
--   5. DynamicMarker combat-reload secure flare init, ResetDefaults notice, OnDragStop & secret guards
-- Pure ASCII Only.
-- ============================================================================

local TALENT_PATH = "DynamicSuite/Modules/DynamicTalent.lua"
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

local function MakeSecret(tag)
    return setmetatable({ __testSecret = true, tag = tag or "secret" }, {
        __lt = function() error("Attempt to compare secret value") end,
        __le = function() error("Attempt to compare secret value") end,
        __concat = function() error("Attempt to concat secret value") end,
        __len = function() error("Attempt to measure secret value") end,
    })
end

local function CreateHarness(opts)
    opts = opts or {}
    local env = {}
    setmetatable(env, { __index = _G })
    env._G = env

    local now = 100.0
    local timers = {}
    local eventFrames = {}
    local calls = {
        saveConfig = {},
        setSelection = {},
        printLog = {},
        setOverrideBinding = {},
        popupClosed = 0,
    }

    local state = {
        inCombat = false,
        keystoneActive = false,
        chatLockdown = false,
        encounterInProgress = false,
        instanceEncounterInProgress = false,
        inInstance = false,
        inGroup = false,
        inRaid = false,
        throwSecretApi = false,
        throwAccessApi = false,
        activeConfigID = 1001,
        specID = 62,
        heroNodeID = nil,
        configInfo = { name = "Raid Build", treeIDs = { 2001 } },
        treeNodes = { 3001 },
        nodeInfoByID = {},
        entryInfoByID = {},
        subTreeInfoByID = {},
        configIDsBySpec = { 1001 },
        configInfoByID = { [1001] = { name = "Raid Build" } },
        tlmActiveInfo = nil,
        setSelectionOk = true,
        setSelectionRet = true,
        tooltipNumLines = 1,
        tooltipLinesText = { "Header Line" },
        throwTooltipLines = false,
        truncText = "Long truncated text",
    }

    env.wipe = function(t) if type(t) ~= "table" then return t end; for k in pairs(t) do t[k] = nil end; return t end
    env.tinsert = table.insert
    env.tremove = table.remove
    env.strtrim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
    env.strsplit = function(sep, str)
        local res = {}
        for part in string.gmatch(tostring(str or ""), "([^" .. sep .. "]+)") do table.insert(res, part) end
        return unpack(res)
    end
    env.CopyTable = function(src)
        if type(src) ~= "table" then return src end
        local dst = {}
        for k, v in pairs(src) do dst[k] = env.CopyTable(v) end
        return dst
    end
    env.GetTime = function() return now end
    env.GetScreenWidth = function() return 1920 end
    env.GetScreenHeight = function() return 1080 end
    env.InCombatLockdown = function() return state.inCombat end
    env.UnitAffectingCombat = function() return state.inCombat end
    env.IsEncounterInProgress = function() return state.encounterInProgress end
    env.IsShiftKeyDown = function() return false end
    env.IsControlKeyDown = function() return false end
    env.IsAltKeyDown = function() return false end
    env.IsModifierKeyDown = function() return false end
    env.IsMouseButtonDown = function() return false end
    env.GetCursorPosition = function() return 500, 400 end
    env.PlaySound = function() end
    env.PlaySoundFile = function() end
    env.ReloadUI = function() end
    env.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
    env.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
        table.insert(calls.printLog, table.concat(parts, " "))
    end
    env.issecretvalue = function(v)
        if state.throwSecretApi then error("issecretvalue failed") end
        return type(v) == "table" and v.__testSecret == true
    end
    env.canaccessvalue = function(v)
        if state.throwAccessApi then error("canaccessvalue failed") end
        return not (type(v) == "table" and v.__testSecret == true)
    end
    env.hooksecurefunc = function(tbl, fnName, hookFn)
        if type(tbl) == "string" then hookFn = fnName; fnName = tbl; tbl = env end
        if type(tbl) == "table" and type(tbl[fnName]) == "function" then
            local orig = tbl[fnName]
            tbl[fnName] = function(...) local a, b, c, d = orig(...); hookFn(...); return a, b, c, d end
        end
    end

    env.C_Timer = {
        After = function(delay, fn) table.insert(timers, { at = now + (tonumber(delay) or 0), fn = fn }) end,
        NewTimer = function(delay, fn)
            local e = { at = now + (tonumber(delay) or 0), fn = fn }
            table.insert(timers, e)
            return { Cancel = function() e.cancelled = true end }
        end,
    }

    local function NewWidget(wType, name, parent)
        local w = {
            _type = wType,
            _name = name,
            _parent = parent,
            _shown = true,
            _alpha = 1,
            _mouse = true,
            _enabled = true,
            _scale = 1,
            _width = 1180,
            _height = 660,
            _level = 2,
            _strata = "MEDIUM",
            _points = {},
            _scripts = {},
            _events = {},
            _attrs = {},
            _text = "",
            _keyboardEnabled = false,
            _propagateKeyboard = true,
            _showCalls = 0,
            _hideCalls = 0,
            _enableKeyboardCalls = {},
            _sizeCalls = 0,
            _alphaCalls = {},
            _stateDrivers = {},
            _children = {},
            _trunc = false,
        }
        if type(parent) == "table" and type(parent._children) == "table" then
            table.insert(parent._children, w)
        end
        function w:GetName() return self._name end
        function w:SetParent(p) self._parent = p; if type(p) == "table" and type(p._children) == "table" then table.insert(p._children, self) end end
        function w:GetParent() return self._parent end
        function w:GetChildren() return unpack(self._children or {}) end
        function w:GetRegions() return end
        function w:Show() self._showCalls = self._showCalls + 1; self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end
        function w:Hide() self._hideCalls = self._hideCalls + 1; self._shown = false; if self._scripts.OnHide then self._scripts.OnHide(self) end end
        function w:SetShown(v) if v then self:Show() else self:Hide() end end
        function w:IsShown() return self._shown == true end
        function w:IsVisible() return self._shown == true end
        function w:IsForbidden() return false end
        function w:Enable() self._enabled = true end
        function w:Disable() self._enabled = false end
        function w:SetEnabled(v) self._enabled = v and true or false end
        function w:IsEnabled() return self._enabled == true end
        function w:SetAlpha(a) table.insert(self._alphaCalls, a); self._alpha = a end
        function w:GetAlpha() return self._alpha end
        function w:EnableMouse(v) self._mouse = v and true or false end
        function w:EnableMouseWheel() end
        function w:EnableKeyboard(v)
            table.insert(self._enableKeyboardCalls, v and true or false)
            self._keyboardEnabled = v and true or false
        end
        function w:SetPropagateKeyboardInput(v) self._propagateKeyboard = v and true or false end
        function w:SetClampedToScreen() end
        function w:SetClampRectInsets() end
        function w:SetClipsChildren() end
        function w:SetMovable() end
        function w:SetResizable() end
        function w:SetResizeBounds() end
        function w:SetToplevel() end
        function w:SetUserPlaced() end
        function w:RegisterForDrag() end
        function w:RegisterForClicks() end
        function w:StartMoving() end
        function w:StopMovingOrSizing() end
        function w:SetSize(ww, hh) self._sizeCalls = self._sizeCalls + 1; self._width = ww; self._height = hh end
        function w:SetWidth(ww) self._sizeCalls = self._sizeCalls + 1; self._width = ww end
        function w:SetHeight(hh) self._sizeCalls = self._sizeCalls + 1; self._height = hh end
        function w:GetWidth() return self._width end
        function w:GetHeight() return self._height end
        function w:GetCenter() return 960, 540 end
        function w:GetLeft() return 200 end
        function w:GetRight() return 200 + self._width end
        function w:GetTop() return 100 + self._height end
        function w:GetBottom() return 100 end
        function w:SetScale(s) self._scale = s end
        function w:GetScale() return self._scale end
        function w:GetEffectiveScale() return self._scale end
        function w:SetFrameStrata(s) self._strata = s end
        function w:GetFrameStrata() return self._strata end
        function w:SetFrameLevel(l) self._level = l end
        function w:GetFrameLevel() return self._level end
        function w:SetFixedFrameStrata() end
        function w:SetFixedFrameLevel() end
        function w:SetIgnoreParentAlpha() end
        function w:SetIgnoreParentScale() end
        function w:Raise() end
        function w:Lower() end
        function w:SetPassThroughButtons() end
        function w:SetHyperlinksEnabled() end
        function w:SetHitRectInsets() end
        function w:IsMouseOver() return false end
        function w:ClearAllPoints() self._points = {} end
        function w:SetPoint(pt, relTo, relPt, x, y) table.insert(self._points, { pt, relTo, relPt, x, y }) end
        function w:SetAllPoints(p) self._points = { { "ALL", p, "ALL", 0, 0 } } end
        function w:GetNumPoints() return #self._points end
        function w:GetPoint(i) local p = self._points[i]; if not p then return nil end; return p[1], p[2], p[3], p[4], p[5] end
        function w:SetAttribute(k, v) self._attrs[k] = v end
        function w:GetAttribute(k) return self._attrs[k] end
        function w:SetScript(ev, fn) self._scripts[ev] = fn end
        function w:GetScript(ev) return self._scripts[ev] end
        function w:HookScript(ev, fn)
            local prev = self._scripts[ev]
            self._scripts[ev] = function(...)
                if prev then prev(...) end
                fn(...)
            end
        end
        function w:RegisterEvent(ev) self._events[ev] = true end
        function w:UnregisterEvent(ev) self._events[ev] = nil end
        function w:UnregisterAllEvents() self._events = {} end
        function w:SetText(t) self._text = t end
        function w:GetText() return self._text end
        function w:ClearFocus() end
        function w:SetFocus() end
        function w:SetCursorPosition() end
        function w:SetMultiLine() end
        function w:SetAutoFocus() end
        function w:SetMaxLetters() end
        function w:SetTextInsets() end
        function w:SetNumeric() end
        function w:HighlightText() end
        function w:SetOrientation() end
        function w:SetMinMaxValues() end
        function w:SetValueStep() end
        function w:SetObeyStepOnDrag() end
        function w:SetValue(v) self._val = v end
        function w:GetValue() return self._val or 0 end
        function w:SetThumbTexture() end
        function w:SetScrollChild() end
        function w:UpdateScrollChildRect() end
        function w:SetVerticalScroll() end
        function w:GetVerticalScroll() return 0 end
        function w:GetVerticalScrollRange() return 0 end
        function w:SetFont() end
        function w:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
        function w:SetShadowColor() end
        function w:SetShadowOffset() end
        function w:SetTextColor() end
        function w:SetJustifyH() end
        function w:SetJustifyV() end
        function w:SetWordWrap() end
        function w:SetSpacing() end
        function w:SetMaxLines() end
        function w:GetStringHeight() return 18 end
        function w:GetStringWidth() return 80 end
        function w:IsTruncated() return self._trunc end
        function w:SetColorTexture() end
        function w:SetGradient() end
        function w:SetBlendMode() end
        function w:SetTexture() end
        function w:GetTexture() return nil end
        function w:SetTexCoord() end
        function w:SetVertexColor() end
        function w:SetDesaturated() end
        function w:SetSnapToPixelGrid() end
        function w:SetTexelSnappingBias() end
        function w:SetBackdrop() end
        function w:SetBackdropColor() end
        function w:SetBackdropBorderColor() end
        function w:SetOwner() end
        function w:ClearLines() end
        function w:AddLine() end
        function w:SetEnabledState() end
        function w:CreateAnimationGroup()
            local playing = false
            return {
                CreateAnimation = function()
                    return {
                        SetScaleFrom = function() end,
                        SetScaleTo = function() end,
                        SetFromScale = function() end,
                        SetToScale = function() end,
                        SetFromAlpha = function() end,
                        SetToAlpha = function() end,
                        SetDuration = function() end,
                        SetSmoothing = function() end,
                    }
                end,
                Play = function() playing = true end,
                Stop = function() playing = false end,
                IsPlaying = function() return playing end,
            }
        end
        function w:CreateTexture() return NewWidget("Texture", nil, self) end
        function w:CreateFontString() local fs = NewWidget("FontString", nil, self); self._fs = fs; return fs end
        if name then env[name] = w end
        return w
    end

    env.UIParent = NewWidget("Frame", "UIParent", nil)
    env.UIParent._width = 1920
    env.UIParent._height = 1080
    env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(calls.printLog, tostring(m)) end }
    env.GameTooltip = NewWidget("GameTooltip", "GameTooltip", env.UIParent)
    env.GameTooltip._shown = true
    env.GameTooltip.NumLines = function()
        if state.throwTooltipLines then error("tooltip error") end
        return state.tooltipNumLines
    end
    env.GameTooltipTextLeft1 = NewWidget("FontString", "GameTooltipTextLeft1", env.GameTooltip)
    env.GameTooltipTextLeft1.GetText = function() return state.tooltipLinesText[1] end

    env.UISpecialFrames = {}
    env.SlashCmdList = {}
    env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    env.SOUNDKIT = {
        IG_MAINMENU_OPTION = 1,
        IG_MAINMENU_OPTION_CHECKBOX_ON = 856,
        IG_CHARACTER_INFO_TAB = 841,
    }
    env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    env.UNKNOWNOBJECT = "Unknown"
    env.LE_PARTY_CATEGORY_INSTANCE = 2
    env.LE_PARTY_CATEGORY_HOME = 1
    env.Enum = {
        TraitNodeType = { SubTreeSelection = 3 },
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
    env.SetOverrideBindingClick = function(owner, isPrio, key, btnName)
        table.insert(calls.setOverrideBinding, { key = key, btn = btnName })
    end
    env.ClearOverrideBindings = function() end
    env.SecureHandlerWrapScript = function() end
    env.SecureHandlerSetFrameRef = function() end

    env.UnitName = function() return "Dentee" end
    env.UnitGUID = function() return "Player-3725-00000001" end
    env.UnitClass = function() return "Mage", "MAGE", 8 end
    env.UnitLevel = function() return 80 end
    env.GetRealmName = function() return "Frostmourne" end
    env.IsInInstance = function() return state.inInstance end
    env.IsInGroup = function() return state.inGroup end
    env.IsInRaid = function() return state.inRaid end
    env.C_AddOns = {
        GetAddOnMetadata = function() return "2.11.0" end,
        IsAddOnLoaded = function() return false end,
        GetAddOnEnableState = function() return 0 end,
        GetNumAddOns = function() return 0 end,
    }
    env.GetNumAddOns = env.C_AddOns.GetNumAddOns
    env.C_EventUtils = { IsEventValid = function() return true end }
    env.C_ChallengeMode = { IsChallengeModeActive = function() return state.keystoneActive end }
    env.C_MythicPlus = {
        GetOwnedKeystoneLevel = function() return nil end,
        GetSeasonBestForMap = function() return nil end,
    }
    env.C_ChatInfo = {
        InChatMessagingLockdown = function() return state.chatLockdown end,
        SendChatMessage = function(m, t) table.insert(calls.printLog, tostring(t) .. ":" .. tostring(m)) end,
    }
    env.SendChatMessage = env.C_ChatInfo.SendChatMessage
    env.C_InstanceEncounter = { IsEncounterInProgress = function() return state.instanceEncounterInProgress end }
    env.C_SpecializationInfo = {
        GetSpecialization = function() return 1 end,
        GetSpecializationInfo = function() return state.specID, "Arcane", "", 135932, "DAMAGER" end,
        GetNumSpecializations = function() return 3 end,
    }
    env.GetSpecialization = env.C_SpecializationInfo.GetSpecialization
    env.GetSpecializationInfo = env.C_SpecializationInfo.GetSpecializationInfo
    env.GetNumSpecializations = env.C_SpecializationInfo.GetNumSpecializations

    env.C_ClassTalents = {
        GetActiveConfigID = function() return state.activeConfigID end,
        GetLastSelectedSavedConfigID = function() return state.activeConfigID end,
        GetConfigIDsBySpecID = function() return state.configIDsBySpec end,
        GetActiveHeroTalentSpec = function() return nil end,
        GetHeroTalentSpecsForClassSpec = function() return { 1, 2 }, 71 end,
        SaveConfig = function(id) table.insert(calls.saveConfig, id); return true end,
    }
    env.C_Traits = {
        GetConfigInfo = function(cid)
            if cid == state.activeConfigID then return state.configInfo end
            return state.configInfoByID[cid]
        end,
        GetTreeNodes = function() return state.treeNodes end,
        GetNodeInfo = function(_, nid) return state.nodeInfoByID[nid] end,
        GetEntryInfo = function(_, eid) return state.entryInfoByID[eid] end,
        GetSubTreeInfo = function(_, sid) return state.subTreeInfoByID[sid] end,
        SetSelection = function(cfg, nid, eid)
            table.insert(calls.setSelection, { cfg = cfg, nid = nid, eid = eid })
            return state.setSelectionOk, state.setSelectionRet
        end,
    }
    env.TalentLoadoutManagerAPI = {
        CharacterAPI = {
            GetActiveLoadoutInfo = function() return state.tlmActiveInfo end,
        },
    }

    -- PlayerSpellsFrame.TalentsFrame stub for Backdrop Studio & Dock tests
    env.PlayerSpellsFrame = NewWidget("Frame", "PlayerSpellsFrame", env.UIParent)
    env.PlayerSpellsFrame.TalentsFrame = NewWidget("Frame", nil, env.PlayerSpellsFrame)
    env.PlayerSpellsFrame.TalentsFrame.Background = NewWidget("Texture", nil, env.PlayerSpellsFrame.TalentsFrame)
    env.PlayerSpellsFrame.TalentsFrame.ButtonsParent = NewWidget("Frame", nil, env.PlayerSpellsFrame.TalentsFrame)
    env.PlayerSpellsFrame.TalentsFrame.ButtonsParent:SetFrameLevel(5)
    env.PlayerSpellsFrame.TalentsFrame.UpdateSpecBackground = function() end
    env.PlayerSpellsFrame.TalentsFrame.HeroTalentsContainer = NewWidget("Frame", nil, env.PlayerSpellsFrame.TalentsFrame)
    env.PlayerSpellsFrame.TalentsFrame.HeroTalentsContainer.HeroSpecButton = NewWidget("Button", nil, env.PlayerSpellsFrame.TalentsFrame.HeroTalentsContainer)
    env.PlayerSpellsFrame.TalentsFrame.HeroTalentsContainer.GetSubTreeSelectionNodeID = function()
        return state.heroNodeID
    end

    env.CreateFrame = function(wType, name, parent)
        local f = NewWidget(wType, name, parent)
        table.insert(eventFrames, f)
        return f
    end

    if opts.withSuite then
        env.DynamicSuite = {
            version = "2.11.0",
            modules = {},
            Changelogs = {},
            RegisterModule = function(self, reg) self.modules[reg.key] = reg end,
            GetSuiteAccent = function() return 0.22, 0.74, 0.97 end,
            UI = {
                RegisterPopupCloser = function() end,
                CloseAllPopups = function() calls.popupClosed = calls.popupClosed + 1 end,
            },
        }
        env.DynamicSuiteDB = { global = { disabledModules = {} } }
    end

    local function LoadModule(path, addonFolder)
        local chunk, err = loadfile(path)
        if not chunk then error("Failed to load " .. path .. ": " .. tostring(err)) end
        setfenv(chunk, env)
        chunk(addonFolder)
    end

    local function FireEvent(event, a1, a2, a3, a4, a5)
        for i = 1, #eventFrames do
            local f = eventFrames[i]
            if f._events[event] and f._scripts.OnEvent then
                f._scripts.OnEvent(f, event, a1, a2, a3, a4, a5)
            end
        end
    end

    return {
        env = env,
        state = state,
        calls = calls,
        eventFrames = eventFrames,
        LoadModule = LoadModule,
        FireEvent = FireEvent,
    }
end

local function RunTest(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("[PASS] " .. name)
    else
        failed = failed + 1
        print("[FAIL] " .. name)
        print("       " .. tostring(err))
    end
end

-- ============================================================================
-- T1: DynamicTalent Backdrop Studio & Dock Combat Deferral
-- ============================================================================
RunTest("T1: DynamicTalent Backdrop Studio & Dock Combat Deferral", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule(TALENT_PATH, "DynamicSuite")
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")

    local dt = h.env.DynamicTalent
    -- Create backdrop and dock out of combat first
    dt:EnsureTalentDockHooks()
    dt:RefreshTalentDock()
    dt:UpdateTalentTreeBackdrop()
    local bd = h.env.DynamicTalentTreeBackdrop
    assertTrue(bd ~= nil and bd:IsShown(), "Backdrop must exist and show out of combat")

    local tfBg = h.env.PlayerSpellsFrame.TalentsFrame.Background
    bd._showCalls, bd._hideCalls, bd._sizeCalls = 0, 0, 0
    bd.mistPrimary._sizeCalls = 0
    tfBg._alphaCalls = {}

    -- Enter combat: UpdateTalentTreeBackdrop, HideTalentTreeBackdrop, ApplyTheme, TRAIT_CONFIG_UPDATED must all defer!
    h.state.inCombat = true
    dt:UpdateTalentTreeBackdrop()
    dt:ApplyTheme()
    dt:HideTalentTreeBackdrop()
    h.FireEvent("TRAIT_CONFIG_UPDATED")
    assertEqual(bd._hideCalls, 0, "HideTalentTreeBackdrop must NOT Hide backdrop in combat")
    assertEqual(bd._showCalls, 0, "UpdateTalentTreeBackdrop must NOT Show backdrop in combat")
    assertEqual(bd.mistPrimary._sizeCalls, 0, "LayoutBackdropLayers must NOT resize textures in combat")
    assertEqual(#tfBg._alphaCalls, 0, "Combat calls must NOT touch TalentsFrame.Background alpha")
    assertEqual(dt._pendingBackdropRefresh, true, "_pendingBackdropRefresh must stay queued in combat")

    -- Exit combat with TalentsFrame shown -> flushes cleanly
    h.state.inCombat = false
    h.FireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(dt._pendingBackdropRefresh, false, "PLAYER_REGEN_ENABLED flushes _pendingBackdropRefresh")
    assertTrue(bd.mistPrimary._sizeCalls > 0, "PLAYER_REGEN_ENABLED re-runs UpdateTalentTreeBackdrop when TalentsFrame is visible")

    -- OnDisableInSuite during combat defers dock Hide()
    h.state.inCombat = true
    local dock = h.env.DynamicTalentLoadoutsDock
    assertTrue(dock ~= nil, "Talent dock exists")
    dock._hideCalls = 0
    h.env.DynamicSuiteDB.global.disabledModules.DynamicTalent = true
    dt:OnDisableInSuite()
    assertEqual(dock._hideCalls, 0, "OnDisableInSuite must NOT call talentDockFrame:Hide() during combat")
    assertEqual(dt._pendingBackdropRefresh, true, "OnDisableInSuite during combat queues backdrop hide")

    h.state.inCombat = false
    h.FireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(bd:IsShown(), false, "PLAYER_REGEN_ENABLED hides backdrop once module is disabled")
end)

-- ============================================================================
-- T2: DynamicTalent Combat Popup Cleanup & Deferred SaveConfig
-- ============================================================================
RunTest("T2: DynamicTalent Combat Popup Cleanup & Deferred SaveConfig", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule(TALENT_PATH, "DynamicSuite")
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")

    local dt = h.env.DynamicTalent
    -- Open a row context menu popup, then enter combat -> PLAYER_REGEN_DISABLED closes it
    local anchorRow = h.env.CreateFrame("Button", nil, h.env.UIParent)
    dt:ShowTalentRowContextMenu(anchorRow, { id = 1, name = "Raid Build", code = "B1", group = "RAID" })
    local rowMenu = h.env.DynamicTalentRowContextMenu
    assertTrue(rowMenu and rowMenu:IsShown(), "Row context menu opens out of combat")

    -- Queue _pendingSaveConfigID during combat, fire TRAIT_CONFIG_UPDATED -> must keep it queued
    h.state.inCombat = true
    dt._pendingSaveConfigID = 4242
    h.FireEvent("PLAYER_REGEN_DISABLED")
    assertEqual(rowMenu:IsShown(), false, "PLAYER_REGEN_DISABLED closes DynamicTalent row context menu")

    h.FireEvent("TRAIT_CONFIG_UPDATED")
    assertEqual(#h.calls.saveConfig, 0, "TRAIT_CONFIG_UPDATED in combat must NOT call C_ClassTalents.SaveConfig")
    assertEqual(dt._pendingSaveConfigID, 4242, "_pendingSaveConfigID must remain queued during combat")

    -- Leave combat -> PLAYER_REGEN_ENABLED flushes SaveConfig(4242) once
    h.state.inCombat = false
    h.FireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(#h.calls.saveConfig, 1, "PLAYER_REGEN_ENABLED must flush queued SaveConfig")
    assertEqual(h.calls.saveConfig[1], 4242, "Flushed SaveConfig must receive queued config ID")
    assertEqual(dt._pendingSaveConfigID, nil, "_pendingSaveConfigID cleared after flush")
end)

-- ============================================================================
-- T3: DynamicTalent Secret-Value Guards
-- ============================================================================
RunTest("T3: DynamicTalent Secret-Value Guards Across Nodes, Loadouts & Tooltips", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule(TALENT_PATH, "DynamicSuite")
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")

    local dt = h.env.DynamicTalent
    local sec = MakeSecret("dt")

    -- 1. Secret treeID / nid / entry / node flags must fail safely with zero error
    h.state.heroNodeID = sec
    h.state.configInfo = { treeIDs = { sec, 2001 } }
    h.state.treeNodes = { sec, 3001 }
    h.state.nodeInfoByID[3001] = {
        type = sec,
        isVisible = sec,
        isAvailable = sec,
        meetsEdgeRequirements = sec,
        entryIDs = { sec },
    }
    local info1, reason1 = dt:GetHeroSwapInfo()
    assertEqual(info1, nil, "Secret node fields return nil safely in GetHeroSwapInfo")
    assertEqual(reason1, "LOCKED", "Secret node fields report LOCKED safely")

    -- 2. PerformHeroMedallionSwap handles secret C_Traits.SetSelection result cleanly
    h.state.heroNodeID = 3001
    h.state.nodeInfoByID[3001] = {
        type = 3,
        isVisible = true,
        isAvailable = true,
        meetsEdgeRequirements = true,
        entryIDs = { 401, 402 },
        activeEntry = { entryID = 401 },
    }
    h.state.entryInfoByID[401] = { subTreeID = 501 }
    h.state.entryInfoByID[402] = { subTreeID = 502 }
    h.state.subTreeInfoByID[501] = { name = "Spellslinger", isActive = sec }
    h.state.subTreeInfoByID[502] = { name = "Sunfury", isActive = false }
    h.state.setSelectionOk = true
    h.state.setSelectionRet = sec
    local okSwap = dt:PerformHeroMedallionSwap()
    assertEqual(okSwap, true, "Secret non-false SetSelection return succeeds safely")

    -- 3. Secret cid in GetSavedTalentLoadouts / HasLegacyTLMSlot & secret TLM info.name
    h.state.configIDsBySpec = { sec, 1002 }
    h.state.configInfoByID[1002] = { name = "Valid Build" }
    local saved = dt:GetSavedTalentLoadouts()
    assertEqual(#saved, 1, "GetSavedTalentLoadouts filters secret config ID cleanly")
    assertEqual(dt:HasLegacyTLMSlot(), false, "HasLegacyTLMSlot skips secret config ID safely")

    h.state.tlmActiveInfo = { name = sec }
    local _, barName = dt:GetTalentLoadoutBarData()
    assertTrue(type(barName) == "string", "GetTalentLoadoutBarData ignores secret TLM info.name")

    -- 4. AppendHeroSwapTooltipHint & AttachTruncationTooltip survive secret NumLines / GetText
    dt:EnsureHeroMedallionHooks()
    local medBtn = h.env.PlayerSpellsFrame.TalentsFrame.HeroTalentsContainer.HeroSpecButton
    h.state.tooltipNumLines = sec
    medBtn:GetScript("OnEnter")(medBtn)
    h.state.throwTooltipLines = true
    medBtn:GetScript("OnEnter")(medBtn)

    local fs = h.env.PlayerSpellsFrame:CreateFontString()
    fs._trunc = true
    fs:SetText(sec)
    dt.AttachTruncationTooltip(fs)
    fs._dtTruncHost:GetScript("OnEnter")(fs._dtTruncHost)
end)

-- ============================================================================
-- T4: DynamicMarker Keybind Capture Combat Abort, Right-Click Block & Modal Safety
-- ============================================================================
RunTest("T4: DynamicMarker Keybind Capture Combat Safety & Profiles Modal Refresh", function()
    local h = CreateHarness({ withSuite = false })
    h.LoadModule(MARKER_PATH, "DynamicMarker")
    h.FireEvent("ADDON_LOADED", "DynamicMarker")
    h.FireEvent("PLAYER_LOGIN")

    local dm = h.env.DynamicMarker
    local boundVal = "F4"
    local kbBtn = dm:CreateKeybindButton(h.env.UIParent, 200, function() return boundVal end, function(v) boundVal = v end, "")

    -- Right-Click during combat is blocked with notice
    h.state.inCombat = true
    local prevLogs = #h.calls.printLog
    kbBtn:GetScript("OnClick")(kbBtn, "RightButton")
    assertEqual(boundVal, "F4", "Right-Click unbind in combat must NOT clear keybind")
    assertTrue(#h.calls.printLog > prevLogs, "Right-Click unbind in combat prints chat notice")

    -- Start capture out of combat, then enter combat -> PLAYER_REGEN_DISABLED aborts and defers EnableKeyboard(false)
    h.state.inCombat = false
    kbBtn:GetScript("OnClick")(kbBtn, "LeftButton")
    assertEqual(kbBtn.isCapturing, true, "Keybind button enters capture state out of combat")
    assertEqual(kbBtn._keyboardEnabled, true, "Keyboard enabled during capture")

    kbBtn._enableKeyboardCalls = {}
    h.state.inCombat = true
    h.FireEvent("PLAYER_REGEN_DISABLED")
    assertEqual(kbBtn.isCapturing, false, "PLAYER_REGEN_DISABLED aborts active keybind capture")
    assertEqual(#kbBtn._enableKeyboardCalls, 0, "Mid-combat capture abort must defer EnableKeyboard(false) to PLAYER_REGEN_ENABLED")

    h.state.inCombat = false
    h.FireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(kbBtn._keyboardEnabled, false, "PLAYER_REGEN_ENABLED flushes deferred EnableKeyboard(false)")

    -- OnHide stops active capture cleanly
    kbBtn:GetScript("OnClick")(kbBtn, "LeftButton")
    assertEqual(kbBtn.isCapturing, true, "Re-entered capture")
    kbBtn:Hide()
    assertEqual(kbBtn.isCapturing, false, "OnHide stops active capture cleanly")

    -- CloseStudioModal during combat sets pendingModalKeyboardReset and PROFILES buttons update on combat transitions
    dm.db._lastImportBackup = { date = "25/11/2026", mode = "REPLACE", marker = { focusIcon = 8 } }
    dm:ShowStudioModal("PROFILES")
    local btnUndo = nil
    for _, fr in ipairs(h.eventFrames) do
        if fr.Text and fr.Text:GetText() == "Undo Last Import" then
            btnUndo = fr
        end
    end
    assertTrue(btnUndo ~= nil and btnUndo:IsEnabled() == true, "PROFILES Undo button starts enabled out of combat when backup exists")

    dm.modalFrame._keyboardEnabled = true
    dm.modalFrame._enableKeyboardCalls = {}
    h.state.inCombat = true
    h.FireEvent("PLAYER_REGEN_DISABLED")
    assertEqual(btnUndo:IsEnabled(), false, "PLAYER_REGEN_DISABLED disables open PROFILES Undo button")

    dm:CloseStudioModal()
    assertEqual(dm.pendingModalKeyboardReset, true, "CloseStudioModal in combat queues pendingModalKeyboardReset")
    assertEqual(#dm.modalFrame._enableKeyboardCalls, 0, "CloseStudioModal in combat does NOT call EnableKeyboard(false)")

    h.state.inCombat = false
    h.FireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(dm.pendingModalKeyboardReset, false, "PLAYER_REGEN_ENABLED clears pendingModalKeyboardReset")
    assertEqual(dm.modalFrame._keyboardEnabled, false, "PLAYER_REGEN_ENABLED disables modal keyboard after combat")
end)

-- ============================================================================
-- T5: DynamicMarker Combat-Reload Flare Init, ResetDefaults, OnDragStop & Secrets
-- ============================================================================
RunTest("T5: DynamicMarker Combat-Reload Flare Init, ResetDefaults & Secret Guards", function()
    local h = CreateHarness({ withSuite = false })
    h.LoadModule(MARKER_PATH, "DynamicMarker")
    h.FireEvent("ADDON_LOADED", "DynamicMarker")
    h.FireEvent("PLAYER_LOGIN")

    local dm = h.env.DynamicMarker

    -- Simulate combat /reload where flare buttons were NOT created yet and pending syncs are queued
    dm.flareCycleBtn = nil
    dm.flareClearBtn = nil
    dm.pendingFlareEngineSync = true
    dm.pendingKeybindSync = true
    dm.db.flareKeybind = "F6"
    h.state.inCombat = false
    h.FireEvent("PLAYER_REGEN_ENABLED")
    assertTrue(dm.flareCycleBtn ~= nil and dm.flareClearBtn ~= nil,
        "PLAYER_REGEN_ENABLED creates secure flare buttons before SyncSecureFlareEngine after combat /reload")

    -- ResetDefaults in combat prints queued notice
    h.state.inCombat = true
    dm:ResetDefaults()
    local lastMsg = h.calls.printLog[#h.calls.printLog] or ""
    assertTrue(lastMsg:find("queued until combat ends", 1, true) ~= nil,
        "ResetDefaults during combat explains HUD/keybind updates are queued until combat ends")

    -- Direct Shift-Drag OnDragStop survives throwing StopMovingOrSizing()
    h.state.inCombat = false
    dm:InitTargetBar()
    dm.targetBar.StopMovingOrSizing = function() error("protected in combat") end
    dm.targetBar:GetScript("OnDragStop")(dm.targetBar)

    -- AnnounceFocusIcon survives secret / throwing lockdown, encounter, instance, group, raid APIs
    local sec = MakeSecret("dm")
    h.env.C_ChatInfo.InChatMessagingLockdown = function() error("lock err") end
    h.env.IsEncounterInProgress = function() return sec end
    h.env.C_InstanceEncounter.IsEncounterInProgress = function() return sec end
    h.env.IsInInstance = function() return sec end
    h.env.IsInGroup = function() return sec end
    h.env.IsInRaid = function() return sec end
    dm.db.chatAnnounce = "ALL"
    dm:AnnounceFocusIcon(false)

    -- ADDON_ACTION_BLOCKED triggers SafeReadableString safely even when issecretvalue throws
    h.state.throwSecretApi = true
    h.FireEvent("ADDON_ACTION_BLOCKED", sec, sec)
    h.state.throwSecretApi = false
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
