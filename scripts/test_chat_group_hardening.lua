-- ============================================================================
-- Headless Lua 5.1 Regression Suite: DynamicChat & DynamicGroup 12.1.7 Hardening
-- Covers:
--   1. DynamicChat IsSecretValue/HasAnySecretArg pcall & EditBox secret/BN_WHISPER safety
--   2. DynamicChat combat-deferred side-clutter/tab suppression & PLAYER_REGEN_ENABLED flush
--   3. DynamicChat Left Rail combat guards (socialBtn, durBtn, vaultBtn)
--   4. DynamicChat Pet Battle visibility parity (Smoked-Glass panel + Left Rail visible)
--   5. DynamicChat /ww chat/encounter lockdown fallback & incoming chat sound guard
--   6. DynamicGroup IsSecretValue pcall & LFG/Instance/Friend/Guild/Cooldown/Roster guards
--   7. DynamicGroup mid-keystone whisper auto-invite block, LFG dialog combat guard, C_CVar & /dg rc/pull
-- Pure ASCII Only.
-- ============================================================================

local CHAT_PATH  = "DynamicSuite/Modules/DynamicChat.lua"
local GROUP_PATH = "DynamicSuite/Modules/DynamicGroup.lua"

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
        SendChatMessage = {},
        InviteUnit = {},
        BNInviteFriend = {},
        AcceptGroup = 0,
        ConvertToRaid = 0,
        ToggleFriendsFrame = 0,
        ToggleGuildFrame = 0,
        ToggleCharacter = 0,
        ToggleAllBags = 0,
        PVEFrame_ToggleFrame = 0,
        DoReadyCheck = 0,
        DoCountdown = {},
        chatLog = {},
    }

    local state = {
        inCombat = false,
        inPetBattle = false,
        keystoneActive = false,
        encounterInProgress = false,
        instanceEncounterInProgress = false,
        chatLockdown = false,
        throwSecretApi = false,
        throwAccessApi = false,
        throwReadyCheck = false,
        throwCountdown = false,
        unitCombat = false,
        inGroup = false,
        inRaid = false,
        isLeader = true,
        isAssistant = false,
        numGroupMembers = 0,
        inGuild = false,
        inInstance = false,
        instanceType = "none",
        lfgMode = nil,
        isFriend = false,
        isGuildMember = false,
        unitInMyGuild = false,
        cvarActionKeyDown = false,
        targetName = "Friendlymate-Frostmourne",
        targetValid = true,
    }

    env.wipe = function(t)
        if type(t) ~= "table" then return t end
        for k in pairs(t) do t[k] = nil end
        return t
    end
    env.tinsert = table.insert
    env.tremove = table.remove
    env.strtrim = function(s)
        return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    end
    env.strsplit = function(sep, str)
        local res = {}
        for part in string.gmatch(tostring(str or ""), "([^" .. sep .. "]+)") do
            table.insert(res, part)
        end
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
    env.UnitAffectingCombat = function() return state.unitCombat end
    env.IsEncounterInProgress = function() return state.encounterInProgress end
    env.IsShiftKeyDown = function() return false end
    env.IsControlKeyDown = function() return false end
    env.IsAltKeyDown = function() return false end
    env.IsModifierKeyDown = function() return false end
    env.IsMouseButtonDown = function() return false end
    env.GetCursorPosition = function() return 400, 300 end
    env.PlaySound = function() end
    env.PlaySoundFile = function() end
    env.ReloadUI = function() end
    env.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
        table.insert(calls.chatLog, table.concat(parts, " "))
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
        if type(tbl) == "string" then
            hookFn = fnName
            fnName = tbl
            tbl = env
        end
        if type(tbl) == "table" and type(tbl[fnName]) == "function" then
            local orig = tbl[fnName]
            tbl[fnName] = function(...)
                local a, b, c, d = orig(...)
                hookFn(...)
                return a, b, c, d
            end
        end
    end

    env.C_Timer = {
        After = function(delay, fn)
            table.insert(timers, { at = now + (tonumber(delay) or 0), fn = fn })
        end,
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
            _scale = 1,
            _width = 430,
            _height = 200,
            _level = 2,
            _strata = "LOW",
            _points = { { "BOTTOMLEFT", nil, "BOTTOMLEFT", 40, 60 } },
            _scripts = {},
            _events = {},
            _attrs = {},
            _text = "",
            _hideCalls = 0,
            _showCalls = 0,
            _enableMouseCalls = {},
            _setTextCalls = {},
            _altArrowCalls = {},
            _clearPointsCalls = 0,
        }
        function w:GetName() return self._name end
        function w:SetParent(p) self._parent = p end
        function w:GetParent() return self._parent end
        function w:Show() self._showCalls = self._showCalls + 1; self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end
        function w:Hide() self._hideCalls = self._hideCalls + 1; self._shown = false; if self._scripts.OnHide then self._scripts.OnHide(self) end end
        function w:SetShown(v) if v then self:Show() else self:Hide() end end
        function w:IsShown() return self._shown == true end
        function w:IsVisible() return self._shown == true end
        function w:IsForbidden() return false end
        function w:SetAlpha(a) self._alpha = a end
        function w:GetAlpha() return self._alpha end
        function w:EnableMouse(v) table.insert(self._enableMouseCalls, v and true or false); self._mouse = v and true or false end
        function w:IsMouseEnabled() return self._mouse end
        function w:EnableMouseWheel() end
        function w:EnableKeyboard() end
        function w:SetPropagateKeyboardInput() end
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
        function w:SetSize(ww, hh) self._width = ww; self._height = hh end
        function w:SetWidth(ww) self._width = ww end
        function w:SetHeight(hh) self._height = hh end
        function w:GetWidth() return self._width end
        function w:GetHeight() return self._height end
        function w:GetCenter() return 255, 160 end
        function w:GetLeft() return 40 end
        function w:GetRight() return 40 + self._width end
        function w:GetTop() return 60 + self._height end
        function w:GetBottom() return 60 end
        function w:SetScale(s) self._scale = s end
        function w:GetScale() return self._scale end
        function w:GetEffectiveScale() return self._scale end
        function w:SetFrameStrata(s) self._strata = s end
        function w:GetFrameStrata() return self._strata end
        function w:SetFrameLevel(l) self._level = l end
        function w:GetFrameLevel() return self._level end
        function w:SetHitRectInsets() end
        function w:IsMouseOver() return false end
        function w:ClearAllPoints() self._clearPointsCalls = self._clearPointsCalls + 1; self._points = {} end
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
        function w:SetText(t) table.insert(self._setTextCalls, t); self._text = t end
        function w:GetText() return self._text end
        function w:SetCursorPosition() end
        function w:SetAltArrowKeyMode(v) table.insert(self._altArrowCalls, v and true or false) end
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
        function w:GetStringWidth() return 56 end
        function w:GetUnboundedStringWidth() return 56 end
        function w:GetFontString() return w._fs end
        function w:GetHighlightTexture() return nil end
        function w:GetNormalTexture() return nil end
        function w:GetPushedTexture() return nil end
        function w:SetEnabled() end
        function w:IsEnabled() return true end
        function w:GetScrollOffset() return 0 end
        function w:SetScrollOffset() end
        function w:GetNumMessages() return 0 end
        function w:SetColorTexture() end
        function w:SetTexture() end
        function w:GetTexture() return nil end
        function w:SetTexCoord() end
        function w:SetRotation() end
        function w:SetHorizTile() end
        function w:SetVertTile() end
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
        function w:CreateTexture() return NewWidget("Texture", nil, self) end
        function w:CreateFontString() local fs = NewWidget("FontString", nil, self); self._fs = fs; return fs end
        if name then env[name] = w end
        return w
    end

    env.UIParent = NewWidget("Frame", "UIParent", nil)
    env.UIParent._width = 1920
    env.UIParent._height = 1080
    env.DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, m) table.insert(calls.chatLog, tostring(m)) end,
    }
    env.GameTooltip = NewWidget("GameTooltip", "GameTooltip", env.UIParent)
    env.UISpecialFrames = {}
    env.SlashCmdList = {}
    env.hash_SlashCmdList = {}
    env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    env.SOUNDKIT = { READY_CHECK = 8960, IG_PLAYER_INVITE = 880, IG_MAINMENU_OPTION = 1 }
    env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    env.UNKNOWNOBJECT = "Unknown"
    env.MAX_WOW_CHAT_CHANNELS = 10
    env.CHAT_FRAMES = { "ChatFrame1", "ChatFrame2" }

    -- ChatFrames, Tabs, EditBoxes, Clutter Buttons & GeneralDockManager
    env.GeneralDockManager = NewWidget("Frame", "GeneralDockManager", env.UIParent)
    env.GeneralDockManagerOverflowButton = NewWidget("Button", "GeneralDockManagerOverflowButton", env.GeneralDockManager)
    env.GeneralDockManagerScrollFrame = NewWidget("ScrollFrame", "GeneralDockManagerScrollFrame", env.GeneralDockManager)
    env.ChatFrameChannelButton = NewWidget("Button", "ChatFrameChannelButton", env.UIParent)
    env.ChatFrameMenuButton = NewWidget("Button", "ChatFrameMenuButton", env.UIParent)
    env.ChatFrameToggleVoiceDeafenButton = NewWidget("Button", "ChatFrameToggleVoiceDeafenButton", env.UIParent)
    env.ChatFrameToggleVoiceMuteButton = NewWidget("Button", "ChatFrameToggleVoiceMuteButton", env.UIParent)
    env.QuickJoinToastButton = NewWidget("Button", "QuickJoinToastButton", env.UIParent)

    local dockedFrames = {}
    for i = 1, 10 do
        local name = "ChatFrame" .. i
        local cf = NewWidget("ScrollingMessageFrame", name, env.UIParent)
        cf.FontStringContainer = NewWidget("Frame", nil, cf)
        cf.Background = NewWidget("Texture", name .. "Background", cf)
        cf.isDocked = (i <= 2)
        if i > 2 then cf._shown = false end
        local tab = NewWidget("Button", name .. "Tab", env.GeneralDockManager)
        tab.Text = tab:CreateFontString()
        tab.Text:SetText("Tab" .. i)
        if i > 2 then tab._shown = false end
        local eb = NewWidget("EditBox", name .. "EditBox", cf)
        eb.header = eb:CreateFontString()
        eb.headerSuffix = eb:CreateFontString()
        eb:SetAttribute("chatType", "SAY")
        NewWidget("Frame", name .. "ButtonFrame", cf)
        NewWidget("Button", name .. "MinimizeButton", cf)
        if i <= 2 then
            table.insert(dockedFrames, cf)
        end
    end
    env.GeneralDockManager.DOCKED_CHAT_FRAMES = dockedFrames
    env.SELECTED_DOCK_FRAME = env.ChatFrame1
    env.DEFAULT_CHAT_FRAME.editBox = env.ChatFrame1EditBox

    env.ChatEdit_GetActiveWindow = function() return env.ChatFrame1EditBox end
    env.ChatEdit_ChooseBoxForSend = function() return env.ChatFrame1EditBox end
    env.ChatEdit_ActivateChat = function() end
    env.ChatEdit_UpdateHeader = function() end
    env.ChatFrame_SendTell = function() end

    -- Social, Durability, Vault & LFG stubs
    env.ToggleFriendsFrame = function() calls.ToggleFriendsFrame = calls.ToggleFriendsFrame + 1 end
    env.ToggleGuildFrame = function() calls.ToggleGuildFrame = calls.ToggleGuildFrame + 1 end
    env.ToggleCharacter = function() calls.ToggleCharacter = calls.ToggleCharacter + 1 end
    env.ToggleAllBags = function() calls.ToggleAllBags = calls.ToggleAllBags + 1 end
    env.PVEFrame_ToggleFrame = function() calls.PVEFrame_ToggleFrame = calls.PVEFrame_ToggleFrame + 1 end
    env.WeeklyRewardsFrame = NewWidget("Frame", "WeeklyRewardsFrame", env.UIParent)
    env.WeeklyRewardsFrame._shown = false
    env.GetNumFriends = function() return 0 end
    env.BNGetNumFriends = function() return 0 end
    env.GetNumGuildMembers = function() return 0, 0 end
    env.GetInventoryItemDurability = function() return 100, 100 end
    env.UnitName = function(u)
        if u == "target" then return state.targetName end
        return "Dentee"
    end
    env.GetUnitName = function(u)
        if u == "target" then return state.targetName end
        return "Dentee-Frostmourne"
    end
    env.UnitExists = function(u) return u == "target" and state.targetValid or (u == "player") end
    env.UnitIsPlayer = function(u) return u == "target" and state.targetValid or (u == "player") end
    env.UnitIsUnit = function(a, b) return a == b end
    env.UnitIsFriend = function() return state.targetValid end
    env.UnitInParty = function() return false end
    env.UnitInRaid = function() return false end
    env.UnitGUID = function() return "Player-3725-00000001" end
    env.UnitClass = function() return "Mage", "MAGE", 8 end
    env.GetRealmName = function() return "Frostmourne" end
    env.GetNormalizedRealmName = function() return "Frostmourne" end

    env.C_AddOns = {
        GetAddOnMetadata = function() return "2.11.0" end,
        IsAddOnLoaded = function() return false end,
        GetAddOnEnableState = function() return 0 end,
        LoadAddOn = function() end,
    }
    env.C_EventUtils = { IsEventValid = function() return true end }
    env.C_PetBattles = { IsInBattle = function() return state.inPetBattle end }
    env.C_ChallengeMode = { IsChallengeModeActive = function() return state.keystoneActive end }
    env.C_InstanceEncounter = { IsEncounterInProgress = function() return state.instanceEncounterInProgress end }
    env.C_ChatInfo = {
        InChatMessagingLockdown = function() return state.chatLockdown end,
        SendChatMessage = function(m, t, _, target)
            table.insert(calls.SendChatMessage, { msg = m, chatType = t, target = target })
        end,
    }
    env.SendChatMessage = env.C_ChatInfo.SendChatMessage
    env.C_CVar = {
        GetCVar = function() return "1" end,
        GetCVarBool = function(k)
            if k == "ActionButtonUseKeyDown" then return state.cvarActionKeyDown end
            return false
        end,
        SetCVar = function() end,
    }
    env.GetCVarBool = function(k)
        if k == "ActionButtonUseKeyDown" then return state.cvarActionKeyDown end
        return false
    end

    env.IsInGroup = function() return state.inGroup end
    env.IsInRaid = function() return state.inRaid end
    env.UnitIsGroupLeader = function() return state.isLeader end
    env.UnitIsGroupAssistant = function() return state.isAssistant end
    env.GetNumGroupMembers = function() return state.numGroupMembers end
    env.IsInGuild = function() return state.inGuild end
    env.IsInInstance = function() return state.inInstance, state.instanceType end
    env.GetLFGMode = function() return state.lfgMode end
    env.C_FriendList = {
        GetNumFriends = function() return 0 end,
        GetFriendInfoByIndex = function() return nil end,
        IsFriend = function() return state.isFriend end,
    }
    env.IsGuildMember = function() return state.isGuildMember end
    env.UnitIsInMyGuild = function() return state.unitInMyGuild end
    env.C_BattleNet = {
        GetAccountInfoByGUID = function() return nil end,
        GetFriendAccountInfo = function() return nil end,
        GetAccountInfoByID = function() return nil end,
    }
    env.C_PartyInfo = {
        InviteUnit = function(t) table.insert(calls.InviteUnit, t) end,
        ConvertToRaid = function() calls.ConvertToRaid = calls.ConvertToRaid + 1 end,
        DoCountdown = function(sec)
            if state.throwCountdown then error("countdown blocked") end
            table.insert(calls.DoCountdown, sec)
        end,
    }
    env.BNInviteFriend = function(id) table.insert(calls.BNInviteFriend, id) end
    env.AcceptGroup = function() calls.AcceptGroup = calls.AcceptGroup + 1 end
    env.DoReadyCheck = function()
        if state.throwReadyCheck then error("readycheck blocked") end
        calls.DoReadyCheck = calls.DoReadyCheck + 1
    end
    env.C_Spell = {
        GetSpellName = function(id) return "Spell" .. tostring(id) end,
        GetSpellInfo = function(id) return { name = "Spell" .. tostring(id), iconID = 136095 } end,
        GetSpellCooldown = function() return { startTime = 0, duration = 0, isEnabled = true } end,
    }
    env.C_LFGList = {
        GetApplications = function() return {} end,
        HasActiveEntryInfo = function() return false end,
    }
    env.C_MythicPlus = {
        GetCurrentAffixes = function() return {} end,
        GetSeasonBestForMap = function() return nil end,
        GetOwnedKeystoneMapID = function() return nil end,
        GetOwnedKeystoneLevel = function() return nil end,
    }
    env.C_WeeklyRewards = { GetActivities = function() return {} end }
    env.C_Container = { GetContainerNumSlots = function() return 0 end }
    env.C_Item = { GetItemCount = function() return 0 end }
    env.C_SpecializationInfo = {
        GetSpecialization = function() return 1 end,
        GetSpecializationInfo = function() return 62, "Arcane", "", 135932, "DAMAGER" end,
    }
    env.GetSpecialization = env.C_SpecializationInfo.GetSpecialization
    env.GetSpecializationInfo = env.C_SpecializationInfo.GetSpecializationInfo
    env.LFGListApplicationDialog = NewWidget("Frame", "LFGListApplicationDialog", env.UIParent)
    env.LFGListApplicationDialog.Description = NewWidget("Frame", nil, env.LFGListApplicationDialog)
    env.LFGListApplicationDialog.Description.EditBox = NewWidget("EditBox", nil, env.LFGListApplicationDialog.Description)
    env.LFGListApplicationDialog._shown = false
    env.LFGListFrame = NewWidget("Frame", "LFGListFrame", env.UIParent)
    env.LFGListFrame.SearchPanel = NewWidget("Frame", nil, env.LFGListFrame)
    env.LFGListFrame.SearchPanel.RefreshButton = NewWidget("Button", nil, env.LFGListFrame.SearchPanel)
    env.LFGListFrame.SearchPanel.ScrollBox = NewWidget("Frame", nil, env.LFGListFrame.SearchPanel)
    env.LFGListFrame.SearchPanel.FilterButton = NewWidget("Button", nil, env.LFGListFrame.SearchPanel)
    env.LFGListFrame.SearchPanel.SearchBox = NewWidget("EditBox", nil, env.LFGListFrame.SearchPanel)

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
        }
        env.DynamicSuiteDB = { global = { disabledModules = {} } }
    end

    local function LoadModule(path, addonFolder)
        local chunk, err = loadfile(path)
        if not chunk then error("Failed to load " .. path .. ": " .. tostring(err)) end
        setfenv(chunk, env)
        chunk(addonFolder)
    end

    local function FireEvent(event, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13)
        for i = 1, #eventFrames do
            local f = eventFrames[i]
            if f._events[event] and f._scripts.OnEvent then
                f._scripts.OnEvent(f, event, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13)
            end
        end
    end

    local function AdvanceTime(dt)
        local target = now + (dt or 0)
        local guard = 0
        while guard < 100 do
            guard = guard + 1
            local nextIdx, nextAt = nil, nil
            for i = 1, #timers do
                local t = timers[i]
                if not t.cancelled and t.at <= target then
                    if not nextAt or t.at < nextAt then
                        nextAt = t.at
                        nextIdx = i
                    end
                end
            end
            if not nextIdx then break end
            local t = table.remove(timers, nextIdx)
            now = math.max(now, t.at)
            t.fn()
        end
        now = target
    end

    return {
        env = env,
        state = state,
        calls = calls,
        eventFrames = eventFrames,
        LoadModule = LoadModule,
        FireEvent = FireEvent,
        AdvanceTime = AdvanceTime,
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
-- T1: DynamicChat Secret-Value pcall & EditBox / BN_WHISPER Guards
-- ============================================================================
RunTest("T1: DynamicChat Secret-Value pcall & EditBox Guards", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule(CHAT_PATH, "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")

    -- IsSecretValue and HasAnySecretArg survive throwing issecretvalue / canaccessvalue
    h.state.throwSecretApi = true
    h.state.throwAccessApi = true
    assertEqual(h.env.DynamicChat.IsSecretValue("normal"), false, "IsSecretValue must catch errors from secret APIs")
    h.state.throwSecretApi = false
    h.state.throwAccessApi = false

    local sec = MakeSecret("eb")
    local eb1 = h.env.ChatFrame1EditBox
    eb1:SetAttribute("chatType", "BN_WHISPER")
    eb1._altArrowCalls = {}
    h.env.DynamicChat:ApplyEditBoxSettings()
    assertEqual(#eb1._altArrowCalls, 0, "ApplyEditBoxSettings must skip BN_WHISPER EditBox")

    eb1:SetAttribute("chatType", sec)
    eb1._setTextCalls = {}
    h.env.SlashCmdList.DYNAMICCHATWW("hello world")
    assertEqual(#eb1._setTextCalls, 0, "SwitchEditBoxToTargetWhisper must skip EditBox with secret chatType")

    eb1:SetAttribute("chatType", "SAY")
    eb1:SetAttribute("tellTarget", sec)
    h.env.SlashCmdList.DYNAMICCHATWW("hello world")
    assertEqual(#eb1._setTextCalls, 0, "SwitchEditBoxToTargetWhisper must skip EditBox with secret tellTarget")
end)

local function FindLeftRail(h)
    for _, f in ipairs(h.eventFrames) do
        if f.socialBtn and f.durBtn and f.vaultBtn then
            return f
        end
    end
    return nil
end

-- ============================================================================
-- T2: DynamicChat Combat-Deferred Side-Clutter & Docked Tab Suppression
-- ============================================================================
RunTest("T2: DynamicChat Defers Protected Blizzard Hides During Combat", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule(CHAT_PATH, "DynamicSuite")
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")

    -- Add enough wide docked tabs (4 * 130px = 520px > ~394px avail) to force overflow scroll hiding
    local docked = { h.env.ChatFrame1, h.env.ChatFrame2 }
    for idx = 3, 4 do
        local cf = h.env["ChatFrame" .. idx]
        local tab = h.env["ChatFrame" .. idx .. "Tab"]
        cf.isDocked = true
        cf._shown = true
        tab._shown = true
        table.insert(docked, cf)
    end
    for idx = 1, 4 do
        local tab = h.env["ChatFrame" .. idx .. "Tab"]
        local fs = tab.Text
        fs.GetUnboundedStringWidth = function() return 130 end
        fs.GetStringWidth = function() return 130 end
    end
    h.env.GeneralDockManager.DOCKED_CHAT_FRAMES = docked
    h.env.CHAT_FRAMES = { "ChatFrame1", "ChatFrame2", "ChatFrame3", "ChatFrame4" }
    local tabExtra = h.env.ChatFrame4Tab

    -- Run initial skin out of combat so hooks install, then switch to combat before re-running
    h.env.DynamicChat:ApplySleekChatSkin()
    assertEqual(tabExtra:IsShown(), false, "Sanity: 4th tab overflows and hides out of combat")

    h.env.ChatFrameMenuButton._hideCalls = 0
    h.env.ChatFrameMenuButton._enableMouseCalls = {}
    tabExtra._shown = true
    tabExtra._hideCalls = 0
    tabExtra._clearPointsCalls = 0

    h.state.inCombat = true
    h.env.DynamicChat:ApplySleekChatSkin()
    assertEqual(h.env.ChatFrameMenuButton._hideCalls, 0, "SetSideClutterButtonSuppressed must NOT Hide() during InCombatLockdown")
    assertEqual(#h.env.ChatFrameMenuButton._enableMouseCalls, 0, "SetSideClutterButtonSuppressed must NOT EnableMouse() during InCombatLockdown")
    assertEqual(tabExtra._hideCalls, 0, "LayoutDockedChatTabs must NOT Hide() overflow tab during InCombatLockdown")
    assertEqual(tabExtra._clearPointsCalls, 0, "LayoutDockedChatTabs must NOT ClearAllPoints() overflow tab during InCombatLockdown")
    assertTrue(h.env.DynamicChat._pendingChatPosAfterCombat == true, "_pendingChatPosAfterCombat must be flagged in combat")
    assertTrue(h.env.DynamicChat._pendingTabLayoutAfterCombat == true, "_pendingTabLayoutAfterCombat must be flagged in combat")

    -- Trigger tab OnShow in combat -> still deferred, zero Hide()
    tabExtra:Show()
    assertEqual(tabExtra._hideCalls, 0, "Tab OnShow hook must NOT Hide() in combat")

    -- Leave combat -> PLAYER_REGEN_ENABLED flushes deferred suppression & tab layout
    h.state.inCombat = false
    h.FireEvent("PLAYER_REGEN_ENABLED")
    assertTrue(h.env.ChatFrameMenuButton._hideCalls > 0, "PLAYER_REGEN_ENABLED must flush deferred side-clutter suppression")
    assertTrue(tabExtra._hideCalls > 0, "PLAYER_REGEN_ENABLED must flush deferred overflow tab hide")
end)

-- ============================================================================
-- T3: DynamicChat Left Rail Combat Guards (socialBtn, durBtn, vaultBtn)
-- ============================================================================
RunTest("T3: DynamicChat Left Rail Combat Click Guards", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule(CHAT_PATH, "DynamicSuite")
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")
    h.env.DynamicChat:ApplySleekChatSkin()

    local rail = FindLeftRail(h)
    assertTrue(rail and rail.socialBtn and rail.durBtn and rail.vaultBtn, "Left Rail buttons must exist after skinning")

    h.state.inCombat = true
    rail.socialBtn:GetScript("OnClick")(rail.socialBtn, "LeftButton")
    rail.socialBtn:GetScript("OnClick")(rail.socialBtn, "RightButton")
    rail.durBtn:GetScript("OnClick")(rail.durBtn, "LeftButton")
    rail.durBtn:GetScript("OnClick")(rail.durBtn, "RightButton")
    rail.vaultBtn:GetScript("OnClick")(rail.vaultBtn, "LeftButton")
    rail.vaultBtn:GetScript("OnClick")(rail.vaultBtn, "RightButton")

    assertEqual(h.calls.ToggleFriendsFrame, 0, "socialBtn must NOT call ToggleFriendsFrame in combat")
    assertEqual(h.calls.ToggleGuildFrame, 0, "socialBtn must NOT call ToggleGuildFrame in combat")
    assertEqual(h.calls.ToggleCharacter, 0, "durBtn must NOT call ToggleCharacter in combat")
    assertEqual(h.calls.ToggleAllBags, 0, "durBtn must NOT call ToggleAllBags in combat")
    assertEqual(h.calls.PVEFrame_ToggleFrame, 0, "vaultBtn must NOT call PVEFrame_ToggleFrame in combat")
    assertEqual(h.env.WeeklyRewardsFrame._shown, false, "vaultBtn must NOT show WeeklyRewardsFrame in combat")
    assertTrue(#h.calls.chatLog >= 3, "Left Rail combat clicks should print plain-English notices")

    -- Out of combat clicks work normally
    h.state.inCombat = false
    rail.socialBtn:GetScript("OnClick")(rail.socialBtn, "LeftButton")
    rail.durBtn:GetScript("OnClick")(rail.durBtn, "LeftButton")
    rail.vaultBtn:GetScript("OnClick")(rail.vaultBtn, "LeftButton")
    assertEqual(h.calls.ToggleFriendsFrame, 1, "socialBtn toggles friends out of combat")
    assertEqual(h.calls.ToggleCharacter, 1, "durBtn toggles character sheet out of combat")
    assertEqual(h.env.WeeklyRewardsFrame._shown, true, "vaultBtn toggles WeeklyRewardsFrame out of combat")
end)

-- ============================================================================
-- T4: DynamicChat Pet Battle Visibility Parity
-- ============================================================================
RunTest("T4: DynamicChat Stays Visible During Pet Battles", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule(CHAT_PATH, "DynamicSuite")
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")

    h.state.inPetBattle = true
    h.env.DynamicChat:ApplySleekChatSkin()
    local rail = FindLeftRail(h)
    assertTrue(rail ~= nil, "Left Rail must be created during Pet Battles")
    assertEqual(rail:IsShown(), true, "DynamicChat Left Rail must stay visible during Pet Battles")
end)

-- ============================================================================
-- T5: DynamicChat /ww Chat-Lockdown Fallback & Sound Encounter Guard
-- ============================================================================
RunTest("T5: DynamicChat /ww Chat Lockdown Fallback & Sound Guard", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule(CHAT_PATH, "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")

    local eb1 = h.env.ChatFrame1EditBox
    h.state.chatLockdown = true
    h.env.SlashCmdList.DYNAMICCHATWW("pulling now")
    assertEqual(#h.calls.SendChatMessage, 0, "/ww must NOT call SendChatMessage under C_ChatInfo lockdown")
    assertEqual(eb1:GetText(), "pulling now", "/ww must fall back to populating EditBox under chat lockdown")

    h.state.chatLockdown = false
    h.state.instanceEncounterInProgress = true
    h.env.SlashCmdList.DYNAMICCHATWW("lust p2")
    assertEqual(#h.calls.SendChatMessage, 0, "/ww must fall back to EditBox during C_InstanceEncounter.IsEncounterInProgress")
    assertEqual(eb1:GetText(), "lust p2", "/ww EditBox receives message during instance encounter")

    -- Throwing InChatMessagingLockdown must not error
    h.state.instanceEncounterInProgress = false
    h.env.C_ChatInfo.InChatMessagingLockdown = function() error("secret lockdown") end
    h.env.SlashCmdList.DYNAMICCHATWW("safe whisper")
    assertEqual(#h.calls.SendChatMessage, 1, "/ww proceeds safely via pcall when lockdown query throws")

    -- HandleIncomingChatSoundEvent survives secret UnitAffectingCombat and honours C_InstanceEncounter
    local sec = MakeSecret("ac")
    h.env.UnitAffectingCombat = function() return sec end
    h.env.DynamicChatDB = h.env.DynamicChatDB or {}
    h.env.DynamicChat:HandleIncomingChatSoundEvent("CHAT_MSG_WHISPER", "Friend", "Player-2", "ping")
end)

-- ============================================================================
-- T6: DynamicGroup Secret-Value Guards (LFG, Instance, Friend/Guild, Roster)
-- ============================================================================
RunTest("T6: DynamicGroup Secret-Value LFG, Instance, Friend/Guild & Roster Guards", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule(GROUP_PATH, "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")

    -- IsSecretValue survives throwing secret probes
    h.state.throwSecretApi = true
    h.state.throwAccessApi = true
    assertEqual(h.env.DynamicGroup ~= nil, true, "DynamicGroup loaded cleanly")
    h.state.throwSecretApi = false
    h.state.throwAccessApi = false

    local sec = MakeSecret("dg")
    local dg = h.env.DynamicGroup

    -- Secret queue, instance, friend, guild, group & leader returns must not error or trigger false actions
    h.state.lfgMode = sec
    h.state.inInstance = sec
    h.state.instanceType = sec
    h.state.isFriend = sec
    h.state.isGuildMember = sec
    h.state.unitInMyGuild = sec
    h.state.inGroup = sec
    h.state.inRaid = sec
    h.state.isLeader = sec
    h.state.isAssistant = sec
    h.state.numGroupMembers = sec
    h.state.inGuild = sec
    h.env.C_Spell.GetSpellCooldown = function() return { startTime = 0, duration = 0, isEnabled = sec } end

    h.FireEvent("PLAYER_ENTERING_WORLD")
    h.FireEvent("GROUP_ROSTER_UPDATE")
    h.FireEvent("PARTY_INVITE_REQUEST", "Friend-Frostmourne", false, false, true, true, false, "Player-1234")
    dg:CheckHostedListingTeleportToast()

    assertEqual(h.calls.AcceptGroup, 0, "Secret LFG/Friend/Guild/Group values must never trigger AcceptGroup")

    -- C_InstanceEncounter blocks outgoing whisper auto-invites
    h.state.inGroup = false
    h.state.inInstance = false
    h.state.instanceEncounterInProgress = true
    h.env.DynamicGroupDB.enableWhisperInvite = true
    h.env.DynamicGroupDB.whisperInviteScope = "ANYONE"
    h.FireEvent("CHAT_MSG_WHISPER", "inv", "Buddy-Frostmourne", nil, nil, nil, nil, nil, nil, nil, nil, nil, "Player-999")
    assertEqual(#h.calls.InviteUnit, 0, "C_InstanceEncounter.IsEncounterInProgress must block whisper auto-invites")
end)

-- ============================================================================
-- T7: DynamicGroup Mid-Keystone Whisper Block, LFG Dialog Combat Guard, C_CVar & /dg rc/pull
-- ============================================================================
RunTest("T7: DynamicGroup Mid-Keystone Block, Dialog Combat Guard, C_CVar & /dg Commands", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule(GROUP_PATH, "DynamicSuite")
    h.FireEvent("PLAYER_LOGIN")

    h.env.DynamicGroupDB.enableWhisperInvite = true
    h.env.DynamicGroupDB.whisperInviteScope = "ANYONE"
    h.env.DynamicGroupDB.persistentNote = "4pc 639"

    -- Mid-keystone blocks both regular and Battle.net whisper auto-invites
    h.state.keystoneActive = true
    h.FireEvent("CHAT_MSG_WHISPER", "123", "Ally-Frostmourne", nil, nil, nil, nil, nil, nil, nil, nil, nil, "Player-555")
    h.FireEvent("CHAT_MSG_BN_WHISPER", "123", "BNetPal", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 77)
    assertEqual(#h.calls.InviteUnit, 0, "Mid-keystone must block CHAT_MSG_WHISPER auto-invites")
    assertEqual(#h.calls.BNInviteFriend, 0, "Mid-keystone must block CHAT_MSG_BN_WHISPER auto-invites")
    h.state.keystoneActive = false

    -- LFGListApplicationDialog OnShow must NOT call SetText in combat
    local dlg = h.env.LFGListApplicationDialog
    dlg.Description.EditBox._setTextCalls = {}
    h.state.inCombat = true
    dlg:Show()
    assertEqual(#dlg.Description.EditBox._setTextCalls, 0, "OnLFGListApplicationDialogOnShow must skip autoFillNote SetText in combat")

    -- Portal Bar PostClick uses C_CVar.GetCVarBool cleanly
    h.state.inCombat = false
    h.state.cvarActionKeyDown = true
    h.env.DynamicGroup:EnsureLFGMiniBar()
    local pbar = h.env.DynamicGroup:EnsurePortalBar()
    assertTrue(pbar and pbar.keyBtn, "Portal bar keyBtn must exist")
    pbar.keyBtn:GetScript("PostClick")(pbar.keyBtn, "LeftButton", true)

    -- /dg rc and /dg pull run safely via pcall even when DoReadyCheck/DoCountdown throw
    h.state.throwReadyCheck = true
    h.state.throwCountdown = true
    h.env.SlashCmdList.DYNAMICGROUP("rc")
    h.env.SlashCmdList.DYNAMICGROUP("pull")
    h.state.throwReadyCheck = false
    h.state.throwCountdown = false
    h.env.SlashCmdList.DYNAMICGROUP("rc")
    h.env.SlashCmdList.DYNAMICGROUP("pull")
    assertEqual(h.calls.DoReadyCheck, 1, "/dg rc calls DoReadyCheck via pcall")
    assertEqual(h.calls.DoCountdown[1], 10, "/dg pull calls C_PartyInfo.DoCountdown(10) via pcall")
end)

-- ============================================================================
-- T8: DynamicGroup 1-Click Premade Group Sign-Up, Mixin Hooks, Roles, Layering & Fallbacks
-- ============================================================================
RunTest("T8: DynamicGroup 1-Click Sign-Up (Global & Mixin Click, Mod Bypass, Role ValidState, DIALOG Strata & Fallback)", function()
    local function VerifyMode(withSuite, addonFolder)
        local h = CreateHarness({ withSuite = withSuite })
        local env = h.env
        local modDown = false
        env.IsModifierKeyDown = function() return modDown end
        env.GetCursorPosition = function() return 960, 540 end
        env.GetSpecializationRole = function() return "DAMAGER" end
        env.C_SpecializationInfo.GetSpecializationRole = env.GetSpecializationRole

        -- Seed stale yieldHooks from an unloaded addon BEFORE loading DynamicGroup
        env.DynamicGroupDB = {
            oneClickSignUp = true,
            autoSelectRole = true,
            autoFillNote = true,
            persistentNote = "4pc 639",
            yieldHooks = { UnloadedOldAddon = true, DisabledFlag = false },
        }

        -- Simulate Blizzard_GroupFinder NOT loaded yet during PLAYER_LOGIN (no click hooks yet)
        env.LFGListSearchEntry_Update = function() end
        env.LFGListSearchPanel_UpdateResultList = function() end
        env.LFGListSearchEntry_OnClick = nil
        env.LFGListSearchEntryMixin = nil

        h.LoadModule(GROUP_PATH, addonFolder)
        h.FireEvent("ADDON_LOADED", addonFolder)
        h.FireEvent("PLAYER_LOGIN")

        -- Verify lfgHooksInstalled is NOT prematurely locked before click hooks exist
        assertEqual(env.DynamicGroup.lfgHooksInstalled, nil, addonFolder .. ": Must not lock lfgHooksInstalled before click hooks exist")

        -- Now simulate Blizzard_GroupFinder loading after PLAYER_LOGIN
        local dialogShowCalls = 0
        local signUpFallbackCalls = 0
        local updateValidStateCalls = 0
        local dialogShowShouldOpen = true

        local dlg = env.LFGListApplicationDialog
        dlg._strata = "MEDIUM"
        dlg._raised = 0
        dlg._width = 306
        dlg._height = 210
        dlg.SetFrameStrata = function(self, s) self._strata = s end
        dlg.GetFrameStrata = function(self) return self._strata end
        dlg.Raise = function(self) self._raised = (self._raised or 0) + 1 end
        dlg.GetCenter = function() return 500, 500 end

        dlg.SignUpButton = env.CreateFrame("Button", "LFGListApplicationDialogSignUpButton", dlg)
        dlg.SignUpButton._enabled = false
        dlg.SignUpButton.SetEnabled = function(self, b) self._enabled = (b == true) end
        dlg.SignUpButton.IsEnabled = function(self) return self._enabled == true end
        dlg.SignUpButton.GetCenter = function() return 450, 430 end

        dlg.DamagerButton = env.CreateFrame("Frame", nil, dlg)
        dlg.DamagerButton._shown = true
        dlg.DamagerButton.CheckButton = env.CreateFrame("CheckButton", nil, dlg.DamagerButton)
        dlg.DamagerButton.CheckButton._checked = false
        dlg.DamagerButton.CheckButton.SetChecked = function(self, v) self._checked = (v == true) end
        dlg.DamagerButton.CheckButton.GetChecked = function(self) return self._checked == true end

        env.LFGListFrame.SearchPanel.SignUpButton = env.CreateFrame("Button", nil, env.LFGListFrame.SearchPanel)
        env.LFGListFrame.SearchPanel.SignUpButton.IsEnabled = function() return true end

        env.C_LFGList.HasSearchResultInfo = function(id) return id == 101 or id == 102 or id == 103 end
        env.C_LFGList.GetSearchResultInfo = function(id)
            if id == 101 or id == 102 or id == 103 then
                return { searchResultID = id, isDelisted = false, activityIDs = { 1 } }
            end
            return nil
        end

        env.LFGListSearchPanel_UpdateButtonStatus = function() end
        env.LFGListApplicationDialog_UpdateValidState = function(d)
            updateValidStateCalls = updateValidStateCalls + 1
            if d.DamagerButton.CheckButton:GetChecked() then
                d.SignUpButton:SetEnabled(true)
            end
        end
        env.LFGListApplicationDialog_UpdateRoles = function() end
        env.LFGListApplicationDialog_Show = function(d, rID)
            dialogShowCalls = dialogShowCalls + 1
            d._lastResultID = rID
            if dialogShowShouldOpen then
                d:Show()
            end
        end
        env.LFGListSearchPanel_SignUp = function(sp)
            signUpFallbackCalls = signUpFallbackCalls + 1
            dlg._lastResultID = sp.selectedResult
            dlg:Show()
        end
        env.LFGListSearchEntry_OnClick = function() end
        env.LFGListSearchEntryMixin = { OnClick = function() end }

        h.FireEvent("ADDON_LOADED", "Blizzard_GroupFinder")
        assertEqual(env.DynamicGroup.lfgHooksInstalled, true, addonFolder .. ": Blizzard_GroupFinder load completes InstallLFGHooks")

        -- (a1) Single-click via global LFGListSearchEntry_OnClick opens dialog, enables SignUpButton, raises to DIALOG strata
        local entry1 = { resultID = 101 }
        env.LFGListSearchEntry_OnClick(entry1, "LeftButton")
        assertEqual(dialogShowCalls, 1, addonFolder .. ": Global LFGListSearchEntry_OnClick triggers PerformLFGSignUp (even with stale yieldHooks)")
        assertEqual(dlg:IsShown(), true, addonFolder .. ": LFGListApplicationDialog opened on 1-click")
        assertEqual(dlg._lastResultID, 101, addonFolder .. ": Clicked resultID 101 passed to dialog")
        assertEqual(dlg:GetFrameStrata(), "DIALOG", addonFolder .. ": Dialog raised to DIALOG strata above PVEFrame HIGH")
        assertTrue(dlg._raised >= 1, addonFolder .. ": Dialog:Raise() called")
        assertEqual(dlg.DamagerButton.CheckButton:GetChecked(), true, addonFolder .. ": Active DAMAGER role auto-checked")
        assertTrue(updateValidStateCalls >= 1, addonFolder .. ": LFGListApplicationDialog_UpdateValidState called after SetChecked(true)")
        assertEqual(dlg.SignUpButton:IsEnabled(), true, addonFolder .. ": SignUpButton immediately enabled")

        -- Same-click mixin trigger within 400ms must debounce cleanly
        env.LFGListSearchEntryMixin.OnClick(entry1, "LeftButton")
        assertEqual(dialogShowCalls, 1, addonFolder .. ": 400ms debounce prevents double-trigger across global + mixin hooks")

        -- (a2) Single-click via LFGListSearchEntryMixin.OnClick on another listing triggers cleanly
        dlg:Hide()
        dlg.DamagerButton.CheckButton:SetChecked(false)
        dlg.SignUpButton:SetEnabled(false)
        h.AdvanceTime(0.5)
        local entry2 = { resultID = 102 }
        env.LFGListSearchEntryMixin.OnClick(entry2, "LeftButton")
        assertEqual(dialogShowCalls, 2, addonFolder .. ": LFGListSearchEntryMixin.OnClick triggers PerformLFGSignUp")
        assertEqual(dlg:IsShown(), true, addonFolder .. ": Dialog opened via Mixin OnClick")
        assertEqual(dlg._lastResultID, 102, addonFolder .. ": Mixin clicked resultID 102 passed to dialog")
        assertEqual(dlg.SignUpButton:IsEnabled(), true, addonFolder .. ": SignUpButton enabled after Mixin click")

        -- (b) Holding Shift/Alt bypasses 1-Click Sign-Up
        dlg:Hide()
        h.AdvanceTime(0.5)
        modDown = true
        local entry3 = { resultID = 103 }
        env.LFGListSearchEntry_OnClick(entry3, "LeftButton")
        env.LFGListSearchEntryMixin.OnClick(entry3, "LeftButton")
        assertEqual(dialogShowCalls, 2, addonFolder .. ": Holding Shift/Alt bypasses 1-Click Sign-Up")
        assertEqual(dlg:IsShown(), false, addonFolder .. ": Dialog stays closed when modifier key is held")
        modDown = false

        -- (c) Explicit LFGListApplicationDialog_UpdateRoles checks role & calls UpdateValidState
        dlg.DamagerButton.CheckButton:SetChecked(false)
        dlg.SignUpButton:SetEnabled(false)
        local prevValidCalls = updateValidStateCalls
        env.LFGListApplicationDialog_UpdateRoles(dlg)
        assertEqual(dlg.DamagerButton.CheckButton:GetChecked(), true, addonFolder .. ": UpdateRoles hook checks DAMAGER")
        assertEqual(updateValidStateCalls, prevValidCalls + 1, addonFolder .. ": UpdateRoles hook calls LFGListApplicationDialog_UpdateValidState")
        assertEqual(dlg.SignUpButton:IsEnabled(), true, addonFolder .. ": UpdateRoles hook enables SignUpButton")

        -- (d) Fallback to LFGListSearchPanel_SignUp when LFGListApplicationDialog_Show fails to open dialog (or is missing)
        dlg:Hide()
        h.AdvanceTime(0.5)
        dialogShowShouldOpen = false
        env.LFGListSearchEntry_OnClick(entry3, "LeftButton")
        assertEqual(signUpFallbackCalls, 1, addonFolder .. ": Falls back to LFGListSearchPanel_SignUp when LFGListApplicationDialog_Show leaves dialog hidden")
        assertEqual(dlg:IsShown(), true, addonFolder .. ": Fallback opened dialog cleanly")
        assertEqual(dlg._lastResultID, 103, addonFolder .. ": Fallback used synchronised sp.selectedResult 103")

        dlg:Hide()
        h.AdvanceTime(0.5)
        env.LFGListApplicationDialog_Show = nil
        env.LFGListSearchEntryMixin.OnClick(entry1, "LeftButton")
        assertEqual(signUpFallbackCalls, 2, addonFolder .. ": Gracefully falls back when LFGListApplicationDialog_Show is nil")
        assertEqual(dlg:IsShown(), true, addonFolder .. ": Nil-Show fallback opened dialog cleanly")
    end

    VerifyMode(true, "DynamicSuite")
    VerifyMode(false, "DynamicGroup")
end)

-- ============================================================================
-- T9: Midnight Secret-String Conversion Guards (LFG, Chat & Role/Layering Edge Cases)
-- ============================================================================
RunTest("T9: Midnight Secret-String Conversion Guards on LFG & Chat (Throws on Any Unguarded Conversion)", function()
    local secretMarker = setmetatable({}, {
        __tostring = function()
            error("attempt to perform string conversion on a secret string value (execution tainted by 'DynamicSuite')", 2)
        end,
        __concat = function()
            error("attempt to perform string conversion on a secret string value (execution tainted by 'DynamicSuite')", 2)
        end,
    })

    -- (a) DynamicGroup LFG secret strings, secret HasSearchResultInfo, PVEFrame DIALOG level, already-applied skip & zero panel.results mutation when filter OFF
    do
        local h = CreateHarness({ withSuite = true })
        local env = h.env
        env.issecretvalue = function(v) return v == secretMarker end
        env.canaccessvalue = function(v) return v ~= secretMarker end
        env.GetRealmName = function() return secretMarker end
        env.GetNormalizedRealmName = function() return secretMarker end
        env.GetCursorPosition = function() return 960, 540 end
        env.GetSpecializationRole = function() return "DAMAGER" end
        env.C_SpecializationInfo.GetSpecializationRole = env.GetSpecializationRole

        env.DynamicGroupDB = {
            oneClickSignUp = true,
            autoSelectRole = true,
            lfgFilterEnabled = false,
            showGroupTeleportToast = true,
        }

        local dlg = env.LFGListApplicationDialog
        dlg._strata = "MEDIUM"
        dlg._level = 5
        dlg._width = 306
        dlg._height = 210
        dlg.SetFrameStrata = function(self, s) self._strata = s end
        dlg.GetFrameStrata = function(self) return self._strata end
        dlg.SetFrameLevel = function(self, l) self._level = l end
        dlg.GetFrameLevel = function(self) return self._level end
        dlg.Raise = function(self) self._raised = (self._raised or 0) + 1 end
        dlg.GetCenter = function() return 500, 500 end
        dlg.SignUpButton = env.CreateFrame("Button", "LFGListApplicationDialogSignUpButtonT9", dlg)
        dlg.SignUpButton._enabled = false
        dlg.SignUpButton.SetEnabled = function(self, b) self._enabled = (b == true) end
        dlg.SignUpButton.IsEnabled = function(self) return self._enabled == true end
        dlg.SignUpButton.GetCenter = function() return 450, 430 end
        dlg.DamagerButton = env.CreateFrame("Frame", nil, dlg)
        dlg.DamagerButton._shown = true
        dlg.DamagerButton.CheckButton = env.CreateFrame("CheckButton", nil, dlg.DamagerButton)
        dlg.DamagerButton.CheckButton._checked = false
        dlg.DamagerButton.CheckButton.SetChecked = function(self, v) self._checked = (v == true) end
        dlg.DamagerButton.CheckButton.GetChecked = function(self) return self._checked == true end
        local mixinValidCalls = 0
        dlg.UpdateValidState = function(self)
            mixinValidCalls = mixinValidCalls + 1
            if self.DamagerButton.CheckButton:GetChecked() then
                self.SignUpButton:SetEnabled(true)
            end
        end

        -- Simulate PVEFrame elevated to DIALOG strata level 40
        env.PVEFrame = env.CreateFrame("Frame", "PVEFrame", env.UIParent)
        env.PVEFrame._strata = "DIALOG"
        env.PVEFrame._level = 40
        env.PVEFrame.GetFrameStrata = function(self) return self._strata end
        env.PVEFrame.GetFrameLevel = function(self) return self._level end

        local appStatusByID = {}
        local dialogShowCalls = 0
        env.C_LFGList.HasSearchResultInfo = function() return secretMarker end -- secret return must NOT drop valid GetSearchResultInfo!
        env.C_LFGList.GetSearchResultInfo = function(id)
            return {
                searchResultID = id,
                name = secretMarker,
                comment = secretMarker,
                leaderName = secretMarker,
                isDelisted = false,
                activityIDs = { 1 },
                numMembers = 2,
                maxMembers = 5,
            }
        end
        env.C_LFGList.GetApplicationInfo = function(id)
            return id, appStatusByID[id] or "none"
        end
        env.LFGListSearchEntry_Update = function() end
        env.LFGListSearchPanel_UpdateResultList = function() end
        env.LFGListSearchPanel_UpdateResults = function() end
        env.LFGListUtil_SetSearchEntryTooltip = function() end
        env.LFGListApplicationDialog_UpdateRoles = function() end
        env.LFGListApplicationDialog_UpdateValidState = nil -- force mixin dlg:UpdateValidState() fallback
        env.LFGListApplicationDialog_Show = function(d, rID)
            dialogShowCalls = dialogShowCalls + 1
            d._lastResultID = rID
            d:Show()
        end
        env.LFGListSearchEntry_OnClick = function() end
        env.LFGListSearchEntryMixin = { OnClick = function() end }

        h.LoadModule(GROUP_PATH, "DynamicSuite")
        h.FireEvent("ADDON_LOADED", "DynamicSuite")
        h.FireEvent("PLAYER_LOGIN")

        -- Secret button arg must safely no-op without throwing
        env.LFGListSearchEntry_OnClick({ resultID = 201 }, secretMarker)
        assertEqual(dialogShowCalls, 0, "Secret button arg safely ignored")

        -- Valid click with secret HasSearchResultInfo & secret listing fields must still open dialog and raise above PVEFrame DIALOG level
        env.LFGListSearchEntry_OnClick({ resultID = 201 }, "LeftButton")
        assertEqual(dialogShowCalls, 1, "Secret HasSearchResultInfo does not silently drop valid listing")
        assertEqual(dlg:IsShown(), true, "Dialog opened with secret listing strings without error")
        assertTrue(dlg:GetFrameLevel() > env.PVEFrame:GetFrameLevel(), "Dialog frame level raised above DIALOG-strata PVEFrame")
        assertTrue(mixinValidCalls >= 1, "Mixin dialog:UpdateValidState() fallback called")
        assertEqual(dlg.SignUpButton:IsEnabled(), true, "SignUpButton enabled via mixin UpdateValidState fallback")

        -- Already-applied listing must NOT reopen dialog
        dlg:Hide()
        h.AdvanceTime(0.5)
        appStatusByID[202] = "applied"
        env.LFGListSearchEntry_OnClick({ resultID = 202 }, "LeftButton")
        assertEqual(dialogShowCalls, 1, "Already-applied listing skips reopening Sign-Up dialog")

        -- Tooltip hook with secret leader/realm must never throw
        local mockTip = {
            AddDoubleLine = function() end,
            AddLine = function() end,
            Show = function() end,
        }
        env.DynamicGroupDB.lfgFilterEnabled = true
        env.LFGListUtil_SetSearchEntryTooltip(mockTip, 201)

        -- When lfgFilterEnabled == false, UpdateResultList AND async refilter must NOT overwrite panel.results
        env.DynamicGroupDB.lfgFilterEnabled = false
        local origResults = { 201, 202 }
        env.LFGListFrame.SearchPanel.results = origResults
        env.LFGListFrame.SearchPanel.totalResults = 2
        env.LFGListSearchPanel_UpdateResultList(env.LFGListFrame.SearchPanel)
        assertEqual(env.LFGListFrame.SearchPanel.results, origResults, "panel.results untouched when lfgFilterEnabled is false")

        -- Entry update with secret GetAlpha() and missing/invalid resultID must neither throw nor mutate panel.results when filter is OFF
        local secretEntry = env.CreateFrame("Button", nil, env.LFGListFrame.SearchPanel)
        secretEntry.resultID = 999999
        secretEntry.GetAlpha = function() return secretMarker end
        env.LFGListSearchEntry_Update(secretEntry)
        if secretEntry._scripts.OnMouseDown then secretEntry._scripts.OnMouseDown(secretEntry, secretMarker) end
        if secretEntry._scripts.OnDoubleClick then secretEntry._scripts.OnDoubleClick(secretEntry, secretMarker) end
        h.AdvanceTime(0.1)
        assertEqual(env.LFGListFrame.SearchPanel.results, origResults, "Async refilter leaves panel.results untouched when lfgFilterEnabled is false")

        -- Elevated PVEFrame at FULLSCREEN strata: dialog must match FULLSCREEN strata and raise frame level above PVEFrame
        dlg:Hide()
        h.AdvanceTime(0.5)
        env.PVEFrame._strata = "FULLSCREEN"
        env.PVEFrame._level = 30
        dlg._strata = "DIALOG"
        dlg._level = 10
        env.LFGListSearchEntry_OnClick({ resultID = 201 }, "LeftButton")
        assertEqual(dlg:GetFrameStrata(), "FULLSCREEN", "Dialog matches elevated FULLSCREEN PVEFrame strata")
        assertTrue(dlg:GetFrameLevel() > 30, "Dialog frame level raised above FULLSCREEN PVEFrame")

        -- Mixin-only LFGListApplicationDialogMixin.UpdateRoles (when global _UpdateRoles is absent)
        local hm = CreateHarness({ withSuite = true })
        local em = hm.env
        em.DynamicGroupDB = { oneClickSignUp = true, autoSelectRole = true }
        em.GetSpecializationRole = function() return "DAMAGER" end
        em.C_SpecializationInfo.GetSpecializationRole = em.GetSpecializationRole
        em.LFGListApplicationDialog_UpdateRoles = nil
        em.LFGListApplicationDialog_UpdateValidState = nil
        em.LFGListApplicationDialogMixin = { UpdateRoles = function() end }
        local mdlg = em.LFGListApplicationDialog
        mdlg.SignUpButton = em.CreateFrame("Button", nil, mdlg)
        mdlg.SignUpButton._enabled = false
        mdlg.SignUpButton.SetEnabled = function(self, b) self._enabled = (b == true) end
        mdlg.SignUpButton.IsEnabled = function(self) return self._enabled == true end
        mdlg.DamagerButton = em.CreateFrame("Frame", nil, mdlg)
        mdlg.DamagerButton._shown = true
        mdlg.DamagerButton.CheckButton = em.CreateFrame("CheckButton", nil, mdlg.DamagerButton)
        mdlg.DamagerButton.CheckButton._checked = false
        mdlg.DamagerButton.CheckButton.SetChecked = function(self, v) self._checked = (v == true) end
        mdlg.DamagerButton.CheckButton.GetChecked = function(self) return self._checked == true end
        mdlg.UpdateValidState = function(self)
            if self.DamagerButton.CheckButton:GetChecked() then self.SignUpButton:SetEnabled(true) end
        end
        hm.LoadModule(GROUP_PATH, "DynamicSuite")
        hm.FireEvent("ADDON_LOADED", "DynamicSuite")
        hm.FireEvent("PLAYER_LOGIN")
        em.LFGListApplicationDialogMixin.UpdateRoles(mdlg)
        assertEqual(mdlg.DamagerButton.CheckButton:GetChecked(), true, "Mixin UpdateRoles auto-selects player spec role")
        assertEqual(mdlg.SignUpButton:IsEnabled(), true, "Mixin UpdateRoles enables SignUpButton via UpdateValidState")
    end

    -- (b) DynamicChat secret frame name, secret mention snippet & secret tab label never throw string conversion errors
    do
        local h = CreateHarness({ withSuite = true })
        local env = h.env
        env.issecretvalue = function(v) return v == secretMarker end
        env.canaccessvalue = function(v) return v ~= secretMarker end
        env.FCFTab_UpdateAlpha = function() end
        env.FCFTab_UpdateColors = function() end

        h.LoadModule(CHAT_PATH, "DynamicSuite")
        h.FireEvent("ADDON_LOADED", "DynamicSuite")
        h.FireEvent("PLAYER_LOGIN")

        local secretCF = env.CreateFrame("ScrollingMessageFrame", nil, env.UIParent)
        secretCF.GetName = function() return secretMarker end
        secretCF.isTemporary = secretMarker
        secretCF.chatType = "WHISPER"
        secretCF.chatTarget = secretMarker
        secretCF.name = secretMarker
        secretCF:Show()

        -- Fire FCFTab_UpdateAlpha / FCFTab_UpdateColors / ApplySleekChatSkin / SaveChatHistorySnapshot / Incoming mention with secret values
        env.FCFTab_UpdateAlpha(secretCF)
        local secretTab = env.CreateFrame("Button", nil, env.GeneralDockManager)
        secretTab.GetName = function() return secretMarker end
        env.FCFTab_UpdateColors(secretTab)
        env.ChatFrame11 = secretCF
        env.ChatFrame11Tab = secretTab
        env.DynamicChat:ApplySleekChatSkin()
        env.DynamicChat:SaveChatHistorySnapshot()
        env.DynamicChat:HandleIncomingChatSoundEvent("CHAT_MSG_GUILD", secretMarker, secretMarker, secretMarker)
        assertTrue(true, "DynamicChat handled all secret frame names, tabs, isTemporary, and chat events with zero string conversion errors")
    end
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
