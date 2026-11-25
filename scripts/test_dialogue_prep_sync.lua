-- ============================================================================
-- Headless Lua 5.1 Regression Suite: DynamicDialogue <-> DynamicPrep Sync
-- Tests both Suite load order (Prep -> Dialogue) and Standalone load order
-- (Dialogue -> Prep, without DynamicSuite) on multi-quest NPC workflows.
-- Pure ASCII Only.
-- ============================================================================

local DIALOGUE_PATH = "DynamicSuite/Modules/DynamicDialogue.lua"
local PREP_PATH     = "DynamicSuite/Modules/DynamicPrep.lua"

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

-- Minimal, faithful WoW Retail Midnight 12.1.5 headless harness
local function CreateHarness(opts)
    opts = opts or {}
    local env = {}
    setmetatable(env, { __index = _G })
    env._G = env

    local now = 100.0
    local timers = {}
    local eventFrames = {}
    local calls = {
        SelectAvailableQuestGossip = {},
        SelectActiveQuestGossip = {},
        SelectOptionGossip = {},
        SelectAvailableQuestGreeting = {},
        SelectActiveQuestGreeting = {},
        AcceptQuest = 0,
        AcknowledgeAutoAcceptQuest = 0,
        DeclineQuest = 0,
        CompleteQuest = 0,
        GetQuestReward = 0,
        CloseGossip = 0,
        CloseQuest = 0,
        ClearInteraction = {},
    }

    local state = {
        inCombat = false,
        shiftDown = false,
        interactingGossip = false,
        interactingQuest = false,
        hasNpcUnit = true,
        npcName = "Archmage Khadgar",
        gossipText = "Greetings, champion.",
        greetingText = "Choose a quest.",
        gossipActive = {},
        gossipAvail = {},
        gossipOpts = {},
        greetingActive = {},
        greetingAvail = {},
        questID = 0,
        questTitle = "",
        questText = "",
        objectiveText = "",
        progressText = "",
        rewardText = "",
        questAutoAccept = false,
        questFromArea = false,
        questPVP = false,
        questCompletable = false,
        questChoices = 0,
        onQuest = {},
        completedQuest = {},
        readyForTurnIn = {},
        staticPopups = {},
    }

    -- Utility functions expected by WoW addons
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
    env.InCombatLockdown = function() return state.inCombat end
    env.IsShiftKeyDown = function() return state.shiftDown end
    env.IsControlKeyDown = function() return false end
    env.IsAltKeyDown = function() return false end
    env.IsMouseButtonDown = function() return false end
    env.GetCursorPosition = function() return 0, 0 end
    env.issecretvalue = function() return false end
    env.canaccessvalue = function() return true end
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
            table.insert(timers, { at = now + (tonumber(delay) or 0), fn = fn, cancelled = false })
        end,
        NewTimer = function(delay, fn)
            local entry = { at = now + (tonumber(delay) or 0), fn = fn, cancelled = false }
            table.insert(timers, entry)
            return {
                Cancel = function() entry.cancelled = true end,
            }
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
            _clamped = true,
            _enabled = true,
            _scale = 1,
            _width = 560,
            _height = 420,
            _level = 1,
            _strata = "MEDIUM",
            _points = {},
            _scripts = {},
            _events = {},
            _text = "",
            _texture = nil,
            _attrs = {},
        }
        function w:GetName() return self._name end
        function w:Show()
            local was = self._shown
            self._shown = true
            if not was and self._scripts.OnShow then self._scripts.OnShow(self) end
        end
        function w:Hide()
            local was = self._shown
            self._shown = false
            if was and self._scripts.OnHide then self._scripts.OnHide(self) end
        end
        function w:SetShown(v) if v then self:Show() else self:Hide() end end
        function w:IsShown() return self._shown == true end
        function w:IsVisible() return self._shown == true end
        function w:IsForbidden() return false end
        function w:SetAlpha(a) self._alpha = a end
        function w:GetAlpha() return self._alpha end
        function w:EnableMouse(v) self._mouse = v and true or false end
        function w:IsMouseEnabled() return self._mouse end
        function w:EnableMouseWheel() end
        function w:EnableKeyboard() end
        function w:SetPropagateKeyboardInput() end
        function w:SetClampedToScreen(v) self._clamped = v and true or false end
        function w:IsClampedToScreen() return self._clamped end
        function w:SetMovable() end
        function w:SetResizable() end
        function w:SetResizeBounds() end
        function w:RegisterForDrag() end
        function w:RegisterForClicks() end
        function w:StartMoving() end
        function w:StartSizing() end
        function w:StopMovingOrSizing() end
        function w:Raise() end
        function w:SetSize(ww, hh) self._width = ww; self._height = hh end
        function w:SetWidth(ww) self._width = ww end
        function w:SetHeight(hh) self._height = hh end
        function w:GetWidth() return self._width end
        function w:GetHeight() return self._height end
        function w:GetTop() return 500 end
        function w:GetLeft() return 100 end
        function w:SetScale(s) self._scale = s end
        function w:GetScale() return self._scale end
        function w:GetEffectiveScale() return self._scale end
        function w:SetFrameStrata(s) self._strata = s end
        function w:SetFrameLevel(l) self._level = l end
        function w:GetFrameLevel() return self._level end
        function w:SetClipsChildren() end
        function w:SetHitRectInsets() end
        function w:SetOrientation() end
        function w:SetMinMaxValues() end
        function w:SetValueStep() end
        function w:SetObeyStepOnDrag() end
        function w:SetValue(v) self._val = v end
        function w:GetValue() return self._val or 0 end
        function w:SetThumbTexture() end
        function w:IsMouseOver() return false end
        function w:ClearAllPoints() self._points = {} end
        function w:SetPoint(pt, relTo, relPt, x, y)
            if type(relTo) == "number" then x, y = relTo, relPt; relTo = nil; relPt = pt end
            table.insert(self._points, { pt, relTo, relPt or pt, x or 0, y or 0 })
        end
        function w:SetAllPoints(p) self._points = { { "ALL", p, "ALL", 0, 0 } } end
        function w:GetNumPoints() return #self._points end
        function w:GetPoint(i)
            local p = self._points[i]
            if not p then return nil end
            return p[1], p[2], p[3], p[4], p[5]
        end
        function w:Enable() self._enabled = true end
        function w:Disable() self._enabled = false end
        function w:IsEnabled() return self._enabled end
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
        function w:Click()
            if self._scripts.OnClick then self._scripts.OnClick(self, "LeftButton") end
        end
        function w:RegisterEvent(ev)
            self._events[ev] = true
        end
        function w:UnregisterEvent(ev)
            self._events[ev] = nil
        end
        function w:UnregisterAllEvents()
            self._events = {}
        end
        function w:SetScrollChild(c) self._scrollChild = c end
        function w:SetVerticalScroll(v) self._scroll = v end
        function w:GetVerticalScroll() return self._scroll or 0 end
        function w:GetVerticalScrollRange() return 0 end
        function w:UpdateScrollChildRect() end
        function w:SetText(t) self._text = tostring(t or "") end
        function w:GetText() return self._text end
        function w:SetFont(p, s, fl) self._font = p; self._fontSize = s; self._fontFlags = fl end
        function w:GetFont() return self._font or "Fonts\\FRIZQT__.TTF", self._fontSize or 12, self._fontFlags or "" end
        function w:SetShadowColor() end
        function w:SetShadowOffset() end
        function w:SetTextColor() end
        function w:SetJustifyH() end
        function w:SetJustifyV() end
        function w:SetWordWrap() end
        function w:SetSpacing() end
        function w:SetMaxLines() end
        function w:GetStringHeight() return 24 end
        function w:GetStringWidth() return 120 end
        function w:SetColorTexture() end
        function w:SetTexture(tex) self._texture = tex end
        function w:GetTexture() return self._texture end
        function w:SetTexCoord() end
        function w:SetVertexColor() end
        function w:SetDesaturated(d) self._desat = d and true or false end
        function w:SetSnapToPixelGrid() end
        function w:SetTexelSnappingBias() end
        function w:SetBackdrop() end
        function w:SetBackdropColor() end
        function w:SetBackdropBorderColor() end
        function w:SetOwner() end
        function w:ClearLines() end
        function w:AddLine() end
        function w:SetQuestItem() end
        function w:SetQuestCurrency() end
        function w:SetCurrencyByID() end
        function w:CreateTexture()
            return NewWidget("Texture", nil, self)
        end
        function w:CreateFontString()
            return NewWidget("FontString", nil, self)
        end
        if name then env[name] = w end
        return w
    end

    env.UIParent = NewWidget("Frame", "UIParent", nil)
    env.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
    env.GameTooltip = NewWidget("GameTooltip", "GameTooltip", env.UIParent)
    env.UISpecialFrames = {}
    env.SlashCmdList = {}
    env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    env.SOUNDKIT = { IG_MAINMENU_OPTION = 1 }
    env.C_AddOns = {
        GetAddOnMetadata = function() return "2.10.1" end,
        IsAddOnLoaded = function() return false end,
        GetAddOnEnableState = function() return 0 end,
    }
    env.CreateFrame = function(wType, name, parent)
        local f = NewWidget(wType, name, parent)
        table.insert(eventFrames, f)
        return f
    end

    -- Native Blizzard GossipFrame & QuestFrame stubs
    env.GossipFrame = NewWidget("Frame", "GossipFrame", env.UIParent)
    env.GossipFrame:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 16, -116)
    env.GossipFrame._shown = false

    env.QuestFrame = NewWidget("Frame", "QuestFrame", env.UIParent)
    env.QuestFrame:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 16, -116)
    env.QuestFrame._shown = false
    env.QuestFrameDetailPanel = NewWidget("Frame", "QuestFrameDetailPanel", env.QuestFrame)
    env.QuestFrameDetailPanel._shown = false
    env.QuestFrameProgressPanel = NewWidget("Frame", "QuestFrameProgressPanel", env.QuestFrame)
    env.QuestFrameProgressPanel._shown = false
    env.QuestFrameRewardPanel = NewWidget("Frame", "QuestFrameRewardPanel", env.QuestFrame)
    env.QuestFrameRewardPanel._shown = false

    env.HideUIPanel = function(f)
        if f and f.Hide then f:Hide() end
    end

    env.Enum = {
        PlayerInteractionType = {
            Gossip = 3,
            QuestGiver = 4,
            Binder = 10,
            Banker = 8,
            AccountBanker = 68,
            GuildBanker = 11,
        },
        GossipOptionStatus = {
            Available = 0,
            Unavailable = 1,
            Locked = 2,
        },
        GossipOptionRecFlags = {
            QuestLabelPrepend = 1,
        },
    }

    env.C_PlayerInteractionManager = {
        IsInteractingNpcOfType = function(iType)
            if iType == env.Enum.PlayerInteractionType.Gossip then
                return state.interactingGossip
            elseif iType == env.Enum.PlayerInteractionType.QuestGiver then
                return state.interactingQuest
            end
            return false
        end,
        ClearInteraction = function(iType)
            table.insert(calls.ClearInteraction, iType)
            if iType == env.Enum.PlayerInteractionType.Gossip then
                state.interactingGossip = false
            elseif iType == env.Enum.PlayerInteractionType.QuestGiver then
                state.interactingQuest = false
            end
        end,
    }

    env.C_QuestLog = {
        IsOnQuest = function(qID) return state.onQuest[qID] == true end,
        IsQuestFlaggedCompleted = function(qID) return state.completedQuest[qID] == true end,
        IsComplete = function(qID) return state.readyForTurnIn[qID] == true end,
        ReadyForTurnIn = function(qID) return state.readyForTurnIn[qID] == true end,
    }

    env.C_GossipInfo = {
        GetText = function() return state.gossipText end,
        GetActiveQuests = function() return state.gossipActive end,
        GetAvailableQuests = function() return state.gossipAvail end,
        GetOptions = function() return state.gossipOpts end,
        GetNumOptions = function() return #state.gossipOpts end,
        SelectActiveQuest = function(qID)
            table.insert(calls.SelectActiveQuestGossip, qID)
            if state.onSelectActiveGossip then state.onSelectActiveGossip(qID) end
        end,
        SelectAvailableQuest = function(qID)
            table.insert(calls.SelectAvailableQuestGossip, qID)
            if state.onSelectAvailableGossip then state.onSelectAvailableGossip(qID) end
        end,
        SelectOption = function(optID)
            table.insert(calls.SelectOptionGossip, optID)
        end,
        SelectOptionByIndex = function(idx)
            table.insert(calls.SelectOptionGossip, "idx:" .. tostring(idx))
        end,
        CloseGossip = function()
            calls.CloseGossip = calls.CloseGossip + 1
            state.interactingGossip = false
        end,
    }

    env.UnitName = function(unit)
        if unit == "npc" then return state.hasNpcUnit and state.npcName or nil end
        if unit == "player" then return "Dentee" end
        return nil
    end
    env.UnitExists = function(unit)
        if unit == "npc" then return state.hasNpcUnit end
        return false
    end
    env.UnitClass = function() return "Mage", "MAGE", 8 end
    env.GetRealmName = function() return "Frostmourne" end
    env.IsInInstance = function() return false, "none" end
    env.GetGreetingText = function() return state.greetingText end
    env.GetNumActiveQuests = function() return #state.greetingActive end
    env.GetActiveTitle = function(i)
        local q = state.greetingActive[i]
        return q and q.title or nil, q and q.isComplete or false
    end
    env.GetActiveQuestID = function(i)
        local q = state.greetingActive[i]
        return q and q.questID or nil
    end
    env.GetNumAvailableQuests = function() return #state.greetingAvail end
    env.GetAvailableTitle = function(i)
        local q = state.greetingAvail[i]
        return q and q.title or nil
    end
    env.GetAvailableQuestInfo = function(i)
        local q = state.greetingAvail[i]
        if not q then return nil end
        return q.isTrivial or false, q.frequency or 0, q.isRepeatable or false, q.isLegendary or false, q.questID
    end
    env.IsAvailableQuestTrivial = function(i)
        local q = state.greetingAvail[i]
        return q and q.isTrivial or false
    end
    env.SelectActiveQuest = function(i)
        table.insert(calls.SelectActiveQuestGreeting, i)
        if state.onSelectActiveGreeting then state.onSelectActiveGreeting(i) end
    end
    env.SelectAvailableQuest = function(i)
        table.insert(calls.SelectAvailableQuestGreeting, i)
        if state.onSelectAvailableGreeting then state.onSelectAvailableGreeting(i) end
    end
    env.GetQuestID = function() return state.questID end
    env.GetTitleText = function() return state.questTitle end
    env.GetQuestText = function() return state.questText end
    env.GetObjectiveText = function() return state.objectiveText end
    env.GetProgressText = function() return state.progressText end
    env.GetRewardText = function() return state.rewardText end
    env.QuestGetAutoAccept = function() return state.questAutoAccept end
    env.QuestIsFromAreaTrigger = function() return state.questFromArea end
    env.QuestFlagsPVP = function() return state.questPVP end
    env.IsQuestCompletable = function() return state.questCompletable end
    env.GetNumQuestChoices = function() return state.questChoices end
    env.GetNumQuestRewards = function() return 0 end
    env.GetNumQuestItems = function() return 0 end
    env.GetRewardMoney = function() return 0 end
    env.GetRewardXP = function() return 0 end
    env.GetQuestMoneyToGet = function() return 0 end
    env.AcceptQuest = function()
        calls.AcceptQuest = calls.AcceptQuest + 1
        if state.onAcceptQuest then state.onAcceptQuest() end
    end
    env.AcknowledgeAutoAcceptQuest = function()
        calls.AcknowledgeAutoAcceptQuest = calls.AcknowledgeAutoAcceptQuest + 1
    end
    env.DeclineQuest = function()
        calls.DeclineQuest = calls.DeclineQuest + 1
    end
    env.CompleteQuest = function()
        calls.CompleteQuest = calls.CompleteQuest + 1
    end
    env.GetQuestReward = function()
        calls.GetQuestReward = calls.GetQuestReward + 1
    end
    env.CloseQuest = function()
        calls.CloseQuest = calls.CloseQuest + 1
        state.interactingQuest = false
    end
    env.StaticPopup_Visible = function(which) return state.staticPopups[which] end
    env.StaticPopup_Hide = function(which) state.staticPopups[which] = nil end
    env.PlaySoundFile = function() end
    env.PlaySound = function() end
    env.GetCVarBool = function() return false end
    env.GetCVar = function() return "0" end
    env.SetCVar = function() end
    env.GetSpecialization = function() return 1 end
    env.GetSpecializationInfo = function() return 62, "Arcane", "", 135932, "DAMAGER" end
    env.C_SpecializationInfo = {
        GetSpecialization = env.GetSpecialization,
        GetSpecializationInfo = env.GetSpecializationInfo,
    }
    env.GetLootSpecialization = function() return 0 end
    env.GetFramerate = function() return 120 end
    env.GetNetStats = function() return 0, 0, 20, 25 end
    env.GetInventoryItemDurability = function() return 100, 100 end
    env.GetInventoryItemLink = function() return nil end
    env.GetInventoryItemID = function() return nil end
    env.GetNumGroupMembers = function() return 0 end
    env.IsInGroup = function() return false end
    env.IsInRaid = function() return false end
    env.UnitIsDeadOrGhost = function() return false end
    env.UnitIsGhost = function() return false end
    env.UnitLevel = function() return 80 end
    env.UnitGUID = function() return "Player-3725-00000001" end
    env.C_Container = {
        GetContainerNumSlots = function() return 0 end,
        GetContainerItemID = function() return nil end,
    }
    env.C_Spell = { GetSpellName = function() return "Spell" end }
    env.C_Item = { GetItemCount = function() return 0 end }
    env.bit = {
        band = function(a, b)
            local res, bitval = 0, 1
            while a > 0 and b > 0 do
                if (a % 2 == 1) and (b % 2 == 1) then res = res + bitval end
                a = math.floor(a / 2)
                b = math.floor(b / 2)
                bitval = bitval * 2
            end
            return res
        end,
    }

    if opts.withSuite then
        env.DynamicSuite = {
            version = "2.10.1",
            modules = {},
            Changelogs = {},
            RegisterModule = function(self, reg) self.modules[reg.key] = reg end,
            GetSuiteAccent = function() return 0.796, 0.835, 0.882 end,
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

    local function AdvanceTime(dt)
        local target = now + (dt or 0)
        local guard = 0
        while guard < 100 do
            guard = guard + 1
            local nextIdx = nil
            local nextAt = nil
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

    local function VisibleOptions()
        local rf = env.DynamicDialogueReaderFrame
        local out = {}
        if not rf or not rf:IsShown() then return out end
        for i, btn in ipairs(rf.optionButtons or {}) do
            if btn:IsShown() then
                table.insert(out, {
                    index = i,
                    btn = btn,
                    label = btn.label:GetText(),
                    tag = btn.tagText:GetText(),
                    icon = btn.icon:GetTexture(),
                })
            end
        end
        return out
    end

    return {
        env = env,
        state = state,
        calls = calls,
        LoadModule = LoadModule,
        FireEvent = FireEvent,
        AdvanceTime = AdvanceTime,
        VisibleOptions = VisibleOptions,
    }
end

local function RunTest(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("[PASS] " .. name)
    else
        failed = failed + 1
        print("[FAIL] " .. name .. "\n       " .. tostring(err))
    end
end

-- ============================================================================
-- TEST 1: Server interaction state prioritized over off-screen Alpha(0) frames
-- ============================================================================
RunTest("T1: Server Interaction State Prioritised Over Stranded Blizzard Frames", function()
    local h = CreateHarness({ withSuite = false })
    h.LoadModule(DIALOGUE_PATH, "DynamicDialogue")
    h.FireEvent("ADDON_LOADED", "DynamicDialogue")

    local dd = h.env.DynamicDialogue
    -- Stranded GossipFrame shown off-screen while server says NOT interacting
    h.env.GossipFrame._shown = true
    h.state.interactingGossip = false
    assertEqual(dd:IsGossipInteractionActive(), false, "Gossip must be inactive when server says false even if GossipFrame:IsShown()")

    -- Server says active
    h.state.interactingGossip = true
    assertEqual(dd:IsGossipInteractionActive(), true, "Gossip must be active when server says true")

    -- Stranded QuestFrame shown after NPC session ended
    h.state.interactingQuest = true
    h.env.QuestFrame._shown = true
    h.state.questID = 1001
    h.FireEvent("QUEST_DETAIL")
    h.AdvanceTime(0)
    assertEqual(dd:IsQuestInteractionActive(), true, "Quest must be active while NPC QuestGiver is true")

    h.state.interactingQuest = false
    assertEqual(dd:IsQuestInteractionActive(), false, "Quest must immediately become inactive when server flips QuestGiver false even if QuestFrame:IsShown()")

    -- Non-NPC bag-item QUEST_DETAIL (no NPC unit, QuestGiver false, GetQuestID > 0)
    h.FireEvent("QUEST_FINISHED")
    h.AdvanceTime(0)
    h.state.hasNpcUnit = false
    h.state.interactingQuest = false
    h.state.questID = 5001
    h.state.questTitle = "Torn Parchment"
    h.env.QuestFrame._shown = true
    h.FireEvent("QUEST_DETAIL")
    h.AdvanceTime(0)
    assertEqual(dd:IsQuestInteractionActive(), true, "Bag-item QUEST_DETAIL without NPC unit must remain active")
    assertEqual(h.env.DynamicDialogueReaderFrame:IsShown(), true, "Reader must open for bag-item QUEST_DETAIL")

    h.FireEvent("QUEST_FINISHED")
    h.AdvanceTime(0)
    assertEqual(dd:IsQuestInteractionActive(), false, "Bag-item QUEST_DETAIL must become inactive after QUEST_FINISHED")
    assertEqual(h.env.DynamicDialogueReaderFrame:IsShown(), false, "Reader must close after bag-item QUEST_FINISHED")
end)

-- ============================================================================
-- TEST 2: Multi-Quest Gossip NPC Manual Accept + Stale Cache + Live Refresh
-- ============================================================================
RunTest("T2: Multi-Quest Gossip NPC Manual Accept, Stale Filter & QUEST_LOG_UPDATE Live Refresh", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule(PREP_PATH, "DynamicSuite")
    h.LoadModule(DIALOGUE_PATH, "DynamicSuite")
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.env.DynamicPrep.db.autoQuestGossip = false -- manual mode

    -- Open multi-quest NPC with Quest 1001 and Quest 1002
    h.state.interactingGossip = true
    h.env.GossipFrame._shown = true
    h.state.gossipAvail = {
        { questID = 1001, title = "First Bounty", frequency = 0 },
        { questID = 1002, title = "Second Bounty", frequency = 0 },
    }
    h.FireEvent("GOSSIP_SHOW")
    h.AdvanceTime(0)

    local opts = h.VisibleOptions()
    assertEqual(#opts, 2, "Initial gossip must show 2 available quests")
    assertEqual(opts[1].label, "First Bounty", "Option 1 must be Quest 1")
    assertEqual(opts[2].label, "Second Bounty", "Option 2 must be Quest 2")

    -- Click Quest 1 -> transition to QUEST_DETAIL
    opts[1].btn:Click()
    assertEqual(h.calls.SelectAvailableQuestGossip[1], 1001, "Clicking Option 1 must call SelectAvailableQuest(1001)")

    h.state.interactingGossip = false
    h.state.interactingQuest = true
    h.env.QuestFrame._shown = true
    h.state.questID = 1001
    h.state.questTitle = "First Bounty"
    h.FireEvent("GOSSIP_CLOSED")
    h.FireEvent("QUEST_DETAIL")
    h.AdvanceTime(0)

    local rf = h.env.DynamicDialogueReaderFrame
    assertEqual(rf:IsShown(), true, "Reader must stay open in DETAIL mode")
    assertEqual(rf.typeBadge.text:GetText(), "QUEST", "Badge must be QUEST")

    -- Accept Quest 1 -> server marks Quest 1 onQuest, fires QUEST_ACCEPTED + QUEST_FINISHED + GOSSIP_SHOW
    -- Intentionally keep Quest 1001 STALE inside gossipAvail!
    rf.priBtn:Click()
    assertEqual(h.calls.AcceptQuest, 1, "Clicking Accept must call AcceptQuest()")

    h.state.onQuest[1001] = true
    h.state.interactingQuest = false
    h.state.interactingGossip = true
    h.env.GossipFrame._shown = true
    h.FireEvent("QUEST_ACCEPTED", 1001)
    h.FireEvent("QUEST_FINISHED")
    h.FireEvent("GOSSIP_SHOW")
    h.AdvanceTime(0)

    opts = h.VisibleOptions()
    assertEqual(#opts, 1, "Stale Quest 1001 must be filtered out; only Quest 1002 should render")
    assertEqual(opts[1].label, "Second Bounty", "Remaining option must be Second Bounty")
    assertEqual(opts[1].tag, "[QUEST]", "Remaining option must have [QUEST] tag")

    -- Now simulate QUEST_LOG_UPDATE arriving when NPC adds Quest 1001 to activeQuests as incomplete
    h.state.gossipActive = {
        { questID = 1001, title = "First Bounty", isComplete = false },
    }
    h.state.gossipAvail = {
        { questID = 1002, title = "Second Bounty", frequency = 0 },
    }
    h.FireEvent("QUEST_LOG_UPDATE")
    h.AdvanceTime(0)

    opts = h.VisibleOptions()
    assertEqual(#opts, 2, "Live refresh must show active Quest 1001 + available Quest 1002")
    assertEqual(opts[1].label, "First Bounty", "Active quest renders first")
    assertEqual(opts[1].tag, "[IN PROGRESS]", "Accepted quest must show [IN PROGRESS] tag")
    assertEqual(opts[1].icon, "Interface\\GossipFrame\\IncompleteQuestIcon", "Accepted quest must use IncompleteQuestIcon")
    assertEqual(opts[2].label, "Second Bounty", "Second quest still available")
    assertEqual(opts[2].tag, "[QUEST]", "Second quest must show [QUEST] tag")

    -- Click Quest 2 immediately without walking away!
    opts[2].btn:Click()
    assertEqual(h.calls.SelectAvailableQuestGossip[2], 1002, "Clicking Quest 2 must immediately call SelectAvailableQuest(1002)")
end)

-- ============================================================================
-- TEST 3: Multi-Quest QUEST_GREETING NPC Manual Accept + Stale Filter + Live Refresh
-- ============================================================================
RunTest("T3: Multi-Quest QUEST_GREETING NPC Stale Filter & QUEST_LOG_UPDATE Refresh", function()
    local h = CreateHarness({ withSuite = false })
    h.LoadModule(DIALOGUE_PATH, "DynamicDialogue")
    h.FireEvent("ADDON_LOADED", "DynamicDialogue")

    h.state.interactingQuest = true
    h.env.QuestFrame._shown = true
    h.state.greetingAvail = {
        { questID = 2001, title = "Greeting Quest A", frequency = 0 },
        { questID = 2002, title = "Greeting Quest B", frequency = 1, isRepeatable = true },
    }
    h.FireEvent("QUEST_GREETING")
    h.AdvanceTime(0)

    local opts = h.VisibleOptions()
    assertEqual(#opts, 2, "Greeting must display 2 quests")

    -- Accept Quest 2001, server transitions back to QUEST_GREETING with stale Quest 2001 still at index 1
    h.state.onQuest[2001] = true
    h.FireEvent("QUEST_ACCEPTED", 2001)
    h.FireEvent("QUEST_GREETING")
    h.AdvanceTime(0)

    opts = h.VisibleOptions()
    assertEqual(#opts, 1, "Stale Quest 2001 must be filtered out of QUEST_GREETING")
    assertEqual(opts[1].label, "Greeting Quest B", "Only Quest B should appear")
    assertEqual(opts[1].icon, "Interface\\GossipFrame\\DailyQuestIcon", "Daily quest must use DailyQuestIcon")

    -- Clicking Quest B must select index 2 (its true Blizzard index!)
    opts[1].btn:Click()
    assertEqual(h.calls.SelectAvailableQuestGreeting[1], 2, "Clicking Quest B must pass original Blizzard index 2")

    -- QUEST_LOG_UPDATE adds Quest 2001 as active incomplete
    h.state.greetingActive = {
        { questID = 2001, title = "Greeting Quest A", isComplete = false },
    }
    h.FireEvent("QUEST_LOG_UPDATE")
    h.AdvanceTime(0)

    opts = h.VisibleOptions()
    assertEqual(#opts, 2, "Live refresh must update greeting with active Quest A + available Quest B")
    assertEqual(opts[1].tag, "[IN PROGRESS]", "Quest A must show [IN PROGRESS]")
end)

-- ============================================================================
-- TEST 4: Dead-Session Click Recovery & Stranded Blizzard Frame Reset
-- ============================================================================
RunTest("T4: Dead-Session Click Recovery Closes Reader & Resets Stranded Blizzard Frames", function()
    local h = CreateHarness({ withSuite = false })
    h.LoadModule(DIALOGUE_PATH, "DynamicDialogue")
    h.FireEvent("ADDON_LOADED", "DynamicDialogue")

    h.state.interactingGossip = true
    h.env.GossipFrame._shown = true
    h.state.gossipAvail = {
        { questID = 4001, title = "Ghost Quest", frequency = 0 },
    }
    h.FireEvent("GOSSIP_SHOW")
    h.AdvanceTime(0)

    local rf = h.env.DynamicDialogueReaderFrame
    assertEqual(rf:IsShown(), true, "Reader must be open")
    assertEqual(h.env.GossipFrame:GetAlpha(), 0, "GossipFrame must be suppressed at alpha 0")

    -- Server silently drops the gossip interaction while GossipFrame stays stranded Shown!
    h.state.interactingGossip = false
    local opts = h.VisibleOptions()
    opts[1].btn:Click()

    assertEqual(#h.calls.SelectAvailableQuestGossip, 0, "Dead session click must NOT call SelectAvailableQuest")
    assertEqual(rf:IsShown(), false, "Dead session click must close DynamicDialogue reader")
    assertEqual(h.env.GossipFrame:IsShown(), false, "Stranded GossipFrame must be hidden cleanly")
    assertEqual(h.env.GossipFrame:GetAlpha(), 1, "GossipFrame alpha must be restored to 1")
    assertTrue(#h.calls.ClearInteraction >= 1, "ClearInteraction must be invoked for dead session")
end)

-- ============================================================================
-- TEST 5: Clean End-of-Interaction Cleanup on QUEST_FINISHED & PIM_FRAME_HIDE
-- ============================================================================
RunTest("T5: QUEST_FINISHED & PLAYER_INTERACTION_MANAGER_FRAME_HIDE Clean Up Stranded Frames", function()
    local h = CreateHarness({ withSuite = false })
    h.LoadModule(DIALOGUE_PATH, "DynamicDialogue")
    h.FireEvent("ADDON_LOADED", "DynamicDialogue")

    h.state.interactingQuest = true
    h.env.QuestFrame._shown = true
    h.state.questID = 4100
    h.state.questTitle = "Final Quest"
    h.FireEvent("QUEST_DETAIL")
    h.AdvanceTime(0)

    local rf = h.env.DynamicDialogueReaderFrame
    assertEqual(rf:IsShown(), true, "Reader open in QUEST_DETAIL")

    -- Server ends interaction, leaving QuestFrame stranded IsShown() == true
    h.state.interactingQuest = false
    h.FireEvent("QUEST_FINISHED")
    h.FireEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", h.env.Enum.PlayerInteractionType.QuestGiver)
    h.AdvanceTime(0)

    assertEqual(rf:IsShown(), false, "Reader must close on QUEST_FINISHED")
    assertEqual(h.env.QuestFrame:IsShown(), false, "Stranded QuestFrame must be hidden")
    assertEqual(h.env.QuestFrame:GetAlpha(), 1, "QuestFrame alpha must be restored to 1")
end)

-- ============================================================================
-- TEST 6 & 7: DynamicPrep <-> DynamicDialogue Multi-Quest Handoff
-- Runs IDENTICAL verification in BOTH Suite order (Prep -> Dialogue)
-- AND Standalone order (Dialogue -> Prep, no DynamicSuite)!
-- ============================================================================
local function RunPrepDialogueHandoffTest(modeLabel, withSuite, dialogueFirst)
    RunTest(modeLabel .. ": Multi-Quest Auto-Accept, Stale-Quest Skip, PvP Handover & Fallback", function()
        local h = CreateHarness({ withSuite = withSuite })
        if dialogueFirst then
            h.LoadModule(DIALOGUE_PATH, withSuite and "DynamicSuite" or "DynamicDialogue")
            h.LoadModule(PREP_PATH, withSuite and "DynamicSuite" or "DynamicPrep")
            h.FireEvent("ADDON_LOADED", withSuite and "DynamicSuite" or "DynamicDialogue")
            if not withSuite then h.FireEvent("ADDON_LOADED", "DynamicPrep") end
        else
            h.LoadModule(PREP_PATH, withSuite and "DynamicSuite" or "DynamicPrep")
            h.LoadModule(DIALOGUE_PATH, withSuite and "DynamicSuite" or "DynamicDialogue")
            h.FireEvent("ADDON_LOADED", withSuite and "DynamicSuite" or "DynamicPrep")
            if not withSuite then h.FireEvent("ADDON_LOADED", "DynamicDialogue") end
        end

        h.env.DynamicPrep.db.autoQuestGossip = true

        -- Step 1: Talk to multi-quest NPC (Quest 3001 normal, Quest 3002 PvP)
        h.state.interactingGossip = true
        h.env.GossipFrame._shown = true
        h.state.gossipAvail = {
            { questID = 3001, title = "Auto Quest One", frequency = 0 },
            { questID = 3002, title = "Manual PvP Quest Two", frequency = 0 },
        }
        h.FireEvent("GOSSIP_SHOW")

        -- DynamicPrep should have selected Quest 3001 synchronously!
        assertEqual(h.calls.SelectAvailableQuestGossip[1], 3001, "DynamicPrep must select Quest 3001 on GOSSIP_SHOW")

        -- Flush frame-0 timer BEFORE server responds: DynamicDialogue must NOT flash stale gossip!
        h.AdvanceTime(0)
        local rf = h.env.DynamicDialogueReaderFrame
        assertTrue(not (rf and rf:IsShown()), "DynamicDialogue must NOT render stale frame-0 gossip snapshot after Prep auto-selected")
        assertEqual(h.env.GossipFrame:GetAlpha(), 0, "GossipFrame must stay suppressed at Alpha 0 during transition")

        -- Step 2: Server transitions to QUEST_DETAIL for Quest 3001
        h.state.interactingGossip = false
        h.state.interactingQuest = true
        h.env.QuestFrame._shown = true
        h.env.QuestFrameDetailPanel._shown = true
        h.state.questID = 3001
        h.state.questTitle = "Auto Quest One"
        h.state.questPVP = false
        h.FireEvent("GOSSIP_CLOSED")
        h.FireEvent("QUEST_DETAIL")

        assertEqual(h.calls.AcceptQuest, 1, "DynamicPrep must auto-accept Quest 3001")
        h.AdvanceTime(0)
        rf = h.env.DynamicDialogueReaderFrame
        assertTrue(not (rf and rf:IsShown()), "DynamicDialogue must NOT flash Quest 3001 detail after Prep auto-accepted")

        -- Step 3: Server accepts Quest 3001 -> fires QUEST_ACCEPTED + QUEST_FINISHED + GOSSIP_SHOW
        -- with STALE Quest 3001 still in gossipAvail!
        h.state.onQuest[3001] = true
        h.state.interactingQuest = false
        h.state.interactingGossip = true
        h.env.GossipFrame._shown = true
        h.FireEvent("QUEST_ACCEPTED", 3001)
        h.FireEvent("QUEST_FINISHED")
        h.FireEvent("GOSSIP_SHOW")

        -- DynamicPrep must skip stale Quest 3001 and immediately select Quest 3002!
        assertEqual(#h.calls.SelectAvailableQuestGossip, 2, "DynamicPrep must select second quest")
        assertEqual(h.calls.SelectAvailableQuestGossip[2], 3002, "DynamicPrep must skip stale 3001 and select 3002")

        -- Step 4: Server sends QUEST_DETAIL for Quest 3002 (PvP quest -> DynamicPrep MUST skip!)
        h.state.interactingGossip = false
        h.state.interactingQuest = true
        h.env.QuestFrame._shown = true
        h.state.questID = 3002
        h.state.questTitle = "Manual PvP Quest Two"
        h.state.questPVP = true
        h.FireEvent("GOSSIP_CLOSED")
        h.FireEvent("QUEST_DETAIL")
        h.AdvanceTime(0)

        -- DynamicPrep must NOT accept PvP quest, and DynamicDialogue must IMMEDIATELY render it!
        assertEqual(h.calls.AcceptQuest, 1, "DynamicPrep must NOT auto-accept PvP quest 3002")
        rf = h.env.DynamicDialogueReaderFrame
        assertTrue(rf and rf:IsShown(), "DynamicDialogue MUST open immediately for PvP Quest 3002")
        assertEqual(rf.subTitle:GetText(), "Manual PvP Quest Two", "Reader must show Quest 3002 title")

        -- Advance past 0.05s retry timers: must STILL NOT double-accept Quest 3001 or accept PvP Quest 3002
        h.AdvanceTime(0.10)
        assertEqual(h.calls.AcceptQuest, 1, "0.05s retry must NOT double-accept or accept PvP quest")

        -- Player manually accepts Quest 3002 -> server ends interaction
        rf.priBtn:Click()
        assertEqual(h.calls.AcceptQuest, 2, "Manual click must accept Quest 3002")
        h.state.onQuest[3002] = true
        h.state.interactingQuest = false
        h.FireEvent("QUEST_ACCEPTED", 3002)
        h.FireEvent("QUEST_FINISHED")
        h.AdvanceTime(0.30)

        assertEqual(rf:IsShown(), false, "Reader must close cleanly after final quest accepted")
        assertEqual(h.env.QuestFrame:IsShown(), false, "Stranded QuestFrame must be hidden after interaction ends")
        assertEqual(h.env.GossipFrame:IsShown(), false, "Stranded GossipFrame must be hidden after interaction ends")
        assertEqual(h.env.QuestFrame:GetAlpha(), 1, "QuestFrame alpha must be restored")
        assertEqual(h.env.GossipFrame:GetAlpha(), 1, "GossipFrame alpha must be restored")

        -- Step 5: Safety fallback test (Quest log full: Prep tries AcceptQuest, server keeps detail open)
        h.state.interactingQuest = true
        h.env.QuestFrame._shown = true
        h.state.questID = 3003
        h.state.questTitle = "Quest Log Full Test"
        h.state.questPVP = false
        h.FireEvent("QUEST_DETAIL")
        h.AdvanceTime(0)
        assertEqual(rf:IsShown(), false, "Frame 0 stays suppressed while awaiting server accept")
        h.AdvanceTime(0.30)
        assertEqual(rf:IsShown(), true, "0.25s fallback MUST open reader if server kept Quest Detail open")
        assertEqual(rf.subTitle:GetText(), "Quest Log Full Test", "Fallback must display live Quest 3003 detail")
    end)
end

RunPrepDialogueHandoffTest("T6 (Suite Order: Prep -> Dialogue)", true, false)
RunPrepDialogueHandoffTest("T7 (Standalone Order: Dialogue -> Prep)", false, true)

-- ============================================================================
-- TEST 8: QUEST_LOG_UPDATE Closes Dead Reader & Respects Combat Guard
-- ============================================================================
RunTest("T8: Live Refresh Closes Dead Reader on QUEST_LOG_UPDATE & Guards Combat", function()
    local h = CreateHarness({ withSuite = false })
    h.LoadModule(DIALOGUE_PATH, "DynamicDialogue")
    h.FireEvent("ADDON_LOADED", "DynamicDialogue")

    h.state.interactingGossip = true
    h.env.GossipFrame._shown = true
    h.state.gossipAvail = {
        { questID = 5001, title = "Combat Guard Quest", frequency = 0 },
    }
    h.FireEvent("GOSSIP_SHOW")
    h.AdvanceTime(0)
    local rf = h.env.DynamicDialogueReaderFrame
    assertEqual(rf:IsShown(), true, "Reader must be shown")

    -- In combat: QUEST_LOG_UPDATE must be ignored
    h.state.inCombat = true
    h.state.interactingGossip = false
    h.FireEvent("QUEST_LOG_UPDATE")
    h.AdvanceTime(0)
    assertEqual(rf:IsShown(), true, "QUEST_LOG_UPDATE must not mutate reader during combat lockdown")

    -- Out of combat: QUEST_LOG_UPDATE detects dead session and cleanly closes reader
    h.state.inCombat = false
    h.FireEvent("QUEST_LOG_UPDATE")
    h.AdvanceTime(0)
    assertEqual(rf:IsShown(), false, "QUEST_LOG_UPDATE out of combat must close dead gossip reader")
    assertEqual(h.env.GossipFrame:IsShown(), false, "Dead GossipFrame must be hidden on live refresh teardown")
end)

-- ============================================================================
-- TEST 9: Multi-Quest QUEST_GREETING NPC with DynamicPrep Auto-Accept ON
-- ============================================================================
RunTest("T9: Multi-Quest QUEST_GREETING Auto-Accept Skips Stale Quest #1 & Picks Quest #2", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule(PREP_PATH, "DynamicSuite")
    h.LoadModule(DIALOGUE_PATH, "DynamicSuite")
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.env.DynamicPrep.db.autoQuestGossip = true

    h.state.interactingQuest = true
    h.env.QuestFrame._shown = true
    h.state.greetingAvail = {
        { questID = 6001, title = "Greeting Auto 1", frequency = 0 },
        { questID = 6002, title = "Greeting Auto 2", frequency = 0 },
    }
    h.FireEvent("QUEST_GREETING")
    assertEqual(h.calls.SelectAvailableQuestGreeting[1], 1, "Prep must select index 1 first")

    -- Frame 0 must not flash stale greeting while transitioning
    h.AdvanceTime(0)
    local rf = h.env.DynamicDialogueReaderFrame
    assertTrue(not (rf and rf:IsShown()), "DynamicDialogue must not flash stale frame-0 QUEST_GREETING")

    -- Quest 6001 accepted, NPC returns to QUEST_GREETING with STALE Quest 6001 still at index 1!
    h.state.onQuest[6001] = true
    h.FireEvent("QUEST_ACCEPTED", 6001)
    h.FireEvent("QUEST_GREETING")
    assertEqual(h.calls.SelectAvailableQuestGreeting[2], 2, "Prep must skip stale Quest 6001 at index 1 and select index 2")
end)

-- ============================================================================
-- TEST 10: Dead-Session Clicks in GREETING/DETAIL, QUEST_REMOVED & Repeatable Quests
-- ============================================================================
RunTest("T10: Dead-Session GREETING/DETAIL Clicks, QUEST_REMOVED & Repeatable vs Completed Quests", function()
    local h = CreateHarness({ withSuite = false })
    h.LoadModule(DIALOGUE_PATH, "DynamicDialogue")
    h.FireEvent("ADDON_LOADED", "DynamicDialogue")

    -- Completed one-time quest (7001) must be hidden; completed repeatable quest (7002) must still show
    h.state.interactingGossip = true
    h.env.GossipFrame._shown = true
    h.state.completedQuest[7001] = true
    h.state.completedQuest[7002] = true
    h.state.gossipAvail = {
        { questID = 7001, title = "Done One-Time Quest", frequency = 0, repeatable = false },
        { questID = 7002, title = "Repeatable Daily Quest", frequency = 1, repeatable = true },
        { questID = 7003, title = "Abandonable Quest", frequency = 0, repeatable = false },
    }
    h.FireEvent("GOSSIP_SHOW")
    h.AdvanceTime(0)
    local opts = h.VisibleOptions()
    assertEqual(#opts, 2, "Completed one-time quest filtered, repeatable + normal shown")
    assertEqual(opts[1].label, "Repeatable Daily Quest", "Repeatable quest must remain visible")
    assertEqual(opts[2].label, "Abandonable Quest", "Normal quest must remain visible")

    -- Accept 7003 -> disappears -> Abandon 7003 (QUEST_REMOVED) -> immediately reappears
    h.state.onQuest[7003] = true
    h.FireEvent("QUEST_ACCEPTED", 7003)
    h.AdvanceTime(0)
    opts = h.VisibleOptions()
    assertEqual(#opts, 1, "Accepted Quest 7003 must disappear on live refresh")

    h.state.onQuest[7003] = false
    h.FireEvent("QUEST_REMOVED", 7003)
    h.AdvanceTime(0)
    opts = h.VisibleOptions()
    assertEqual(#opts, 2, "Abandoned Quest 7003 must reappear on QUEST_REMOVED live refresh")

    -- Dead-session click in QUEST_GREETING
    h.state.interactingGossip = false
    h.state.interactingQuest = true
    h.env.QuestFrame._shown = true
    h.state.greetingAvail = { { questID = 7010, title = "Dead Greeting Quest", frequency = 0 } }
    h.FireEvent("QUEST_GREETING")
    h.AdvanceTime(0)
    opts = h.VisibleOptions()
    assertEqual(#opts, 1, "Greeting quest visible")
    h.state.interactingQuest = false
    opts[1].btn:Click()
    assertEqual(#h.calls.SelectAvailableQuestGreeting, 0, "Dead greeting click must not call SelectAvailableQuest")
    assertEqual(h.env.DynamicDialogueReaderFrame:IsShown(), false, "Dead greeting click must close reader")
    assertEqual(h.env.QuestFrame:IsShown(), false, "Dead greeting click must hide stranded QuestFrame")

    -- Dead-session click in QUEST_DETAIL primary Accept button
    h.state.interactingQuest = true
    h.env.QuestFrame._shown = true
    h.state.questID = 7011
    h.state.questTitle = "Dead Detail Quest"
    h.FireEvent("QUEST_DETAIL")
    h.AdvanceTime(0)
    assertEqual(h.env.DynamicDialogueReaderFrame:IsShown(), true, "Detail reader open")
    h.state.interactingQuest = false
    h.env.DynamicDialogueReaderFrame.priBtn:Click()
    assertEqual(h.calls.AcceptQuest, 0, "Dead detail click must not call AcceptQuest")
    assertEqual(h.env.DynamicDialogueReaderFrame:IsShown(), false, "Dead detail click must close reader")
    assertEqual(h.env.QuestFrame:IsShown(), false, "Dead detail click must hide stranded QuestFrame")
end)

-- ============================================================================
-- TEST 11: Field Auto-Complete Quest (QUEST_AUTOCOMPLETE -> QUEST_COMPLETE)
-- ============================================================================
RunTest("T11: Field Auto-Complete QUEST_COMPLETE Without NPC Remains Active", function()
    local h = CreateHarness({ withSuite = false })
    h.LoadModule(DIALOGUE_PATH, "DynamicDialogue")
    h.FireEvent("ADDON_LOADED", "DynamicDialogue")

    local dd = h.env.DynamicDialogue
    h.state.hasNpcUnit = false
    h.state.interactingQuest = false
    h.state.questID = 8001
    h.state.questTitle = "Field Bonus Completion"
    h.state.rewardText = "Well done in the field!"
    h.state.questChoices = 0
    h.env.QuestFrame._shown = true
    h.FireEvent("QUEST_COMPLETE")
    h.AdvanceTime(0)

    local rf = h.env.DynamicDialogueReaderFrame
    assertEqual(dd:IsQuestInteractionActive(), true, "Field QUEST_COMPLETE without NPC must remain active")
    assertEqual(rf:IsShown(), true, "Reader must open for field QUEST_COMPLETE")
    assertEqual(rf.typeBadge.text:GetText(), "TURN-IN", "Badge must be TURN-IN")

    rf.priBtn:Click()
    assertEqual(h.calls.GetQuestReward, 1, "Clicking Complete must call GetQuestReward()")

    h.FireEvent("QUEST_FINISHED")
    h.AdvanceTime(0)
    assertEqual(dd:IsQuestInteractionActive(), false, "Field QUEST_COMPLETE must become inactive after QUEST_FINISHED")
    assertEqual(rf:IsShown(), false, "Reader must close after field QUEST_FINISHED")
end)

-- ============================================================================
-- TEST 12: Manual COMPLETE -> Prep Auto-Handled GOSSIP_SHOW -> GOSSIP_CLOSED
-- ============================================================================
RunTest("T12: Manual Quest Complete Transitioning Into Prep Auto-Gossip Never Strands Reader", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule(PREP_PATH, "DynamicSuite")
    h.LoadModule(DIALOGUE_PATH, "DynamicSuite")
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.env.DynamicPrep.db.autoQuestGossip = true

    -- Quest #1 has 2 reward choices -> Prep cannot auto-complete, so Dialogue opens in COMPLETE mode
    h.state.interactingQuest = true
    h.env.QuestFrame._shown = true
    h.state.questID = 8101
    h.state.questTitle = "Two Choice Turn-In"
    h.state.questChoices = 2
    h.FireEvent("QUEST_COMPLETE")
    h.AdvanceTime(0)

    local rf = h.env.DynamicDialogueReaderFrame
    assertEqual(rf:IsShown(), true, "Reader must open for 2-choice QUEST_COMPLETE")
    assertEqual(rf.typeBadge.text:GetText(), "TURN-IN", "Reader must be in TURN-IN mode")

    -- Player completes Quest #1 -> server fires QUEST_FINISHED + GOSSIP_SHOW with 1 vendor gossip option
    h.state.interactingQuest = false
    h.state.interactingGossip = true
    h.env.QuestFrame._shown = false
    h.env.GossipFrame._shown = true
    h.state.gossipAvail = {}
    h.state.gossipActive = {}
    h.state.gossipOpts = {
        { gossipOptionID = 55001, name = "Browse your goods", flags = 0, status = 0, orderIndex = 0 },
    }
    h.FireEvent("QUEST_FINISHED")
    h.FireEvent("GOSSIP_SHOW")
    h.AdvanceTime(0)

    -- Prep auto-selected the single gossip option; Dialogue MUST hide the old TURN-IN reader immediately!
    assertEqual(h.calls.SelectOptionGossip[1], 55001, "Prep must auto-select single vendor gossip option")
    assertEqual(rf:IsShown(), false, "Old TURN-IN reader must hide immediately when Prep auto-handles GOSSIP_SHOW")

    -- Gossip closes as Merchant opens -> reader must stay closed and GossipFrame must be hidden/restored
    h.state.interactingGossip = false
    h.FireEvent("GOSSIP_CLOSED")
    h.AdvanceTime(0)
    assertEqual(rf:IsShown(), false, "Reader must remain closed after GOSSIP_CLOSED (never permanently stuck)")
    assertEqual(h.env.GossipFrame:IsShown(), false, "Stranded GossipFrame must be hidden")
    assertEqual(h.env.GossipFrame:GetAlpha(), 1, "GossipFrame alpha must be restored")
end)

-- ============================================================================
-- TEST 13: Back-to-Back Same-Phase GOSSIP_SHOW #1 (Prep Acts) -> #2 (Manual)
-- ============================================================================
local function RunBackToBackGossipTest(modeLabel, withSuite, dialogueFirst)
    RunTest(modeLabel .. ": Back-to-Back GOSSIP_SHOW #1 (Prep) -> #2 (Manual) Renders Immediately", function()
        local h = CreateHarness({ withSuite = withSuite })
        if dialogueFirst then
            h.LoadModule(DIALOGUE_PATH, withSuite and "DynamicSuite" or "DynamicDialogue")
            h.LoadModule(PREP_PATH, withSuite and "DynamicSuite" or "DynamicPrep")
            h.FireEvent("ADDON_LOADED", withSuite and "DynamicSuite" or "DynamicDialogue")
            if not withSuite then h.FireEvent("ADDON_LOADED", "DynamicPrep") end
        else
            h.LoadModule(PREP_PATH, withSuite and "DynamicSuite" or "DynamicPrep")
            h.LoadModule(DIALOGUE_PATH, withSuite and "DynamicSuite" or "DynamicDialogue")
            h.FireEvent("ADDON_LOADED", withSuite and "DynamicSuite" or "DynamicPrep")
            if not withSuite then h.FireEvent("ADDON_LOADED", "DynamicDialogue") end
        end
        h.env.DynamicPrep.db.autoQuestGossip = true

        -- Page 1: 1 auto-selectable gossip option
        h.state.interactingGossip = true
        h.env.GossipFrame._shown = true
        h.state.gossipOpts = {
            { gossipOptionID = 61001, name = "Report for duty (Quest)", flags = 1, status = 0, orderIndex = 0 },
        }
        h.FireEvent("GOSSIP_SHOW")
        assertEqual(h.calls.SelectOptionGossip[1], 61001, "Prep must select Page 1 quest gossip option")

        -- Server responds rapidly BEFORE frame 0 with Page 2 (2 manual options -> Prep must NOT act)
        h.state.gossipOpts = {
            { gossipOptionID = 61002, name = "Choice Alpha", flags = 0, status = 0, orderIndex = 0 },
            { gossipOptionID = 61003, name = "Choice Beta", flags = 0, status = 0, orderIndex = 1 },
        }
        h.FireEvent("GOSSIP_SHOW")
        h.AdvanceTime(0)

        local rf = h.env.DynamicDialogueReaderFrame
        assertTrue(rf and rf:IsShown(), "Page 2 manual gossip MUST render immediately on frame 0 without 250ms delay")
        local opts = h.VisibleOptions()
        assertEqual(#opts, 2, "Page 2 must show both manual choices")
        assertEqual(opts[1].label, "Choice Alpha", "First choice must be Choice Alpha")
    end)
end

RunBackToBackGossipTest("T13a (Suite Order)", true, false)
RunBackToBackGossipTest("T13b (Standalone Order)", false, true)

-- ============================================================================
-- TEST 14: High Latency (>50ms RTT) Does Not Double-Call Accept/Complete/Reward
-- ============================================================================
RunTest("T14: Latency >50ms Does Not Double-Call AcceptQuest / CompleteQuest / GetQuestReward", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule(PREP_PATH, "DynamicSuite")
    h.LoadModule(DIALOGUE_PATH, "DynamicSuite")
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.env.DynamicPrep.db.autoQuestGossip = true

    -- QUEST_DETAIL with 100ms network delay
    h.state.interactingQuest = true
    h.env.QuestFrame._shown = true
    h.env.QuestFrameDetailPanel._shown = true
    h.state.questID = 8401
    h.state.questTitle = "Latency Test Quest"
    h.state.questPVP = false
    h.FireEvent("QUEST_DETAIL")
    h.AdvanceTime(0.10)
    assertEqual(h.calls.AcceptQuest, 1, "AcceptQuest must be called only ONCE during >50ms server RTT")

    -- QUEST_PROGRESS with 100ms network delay
    h.env.QuestFrameProgressPanel._shown = true
    h.state.questCompletable = true
    h.FireEvent("QUEST_PROGRESS")
    h.AdvanceTime(0.10)
    assertEqual(h.calls.CompleteQuest, 1, "CompleteQuest must be called only ONCE during >50ms server RTT")

    -- QUEST_COMPLETE with 100ms network delay
    h.env.QuestFrameRewardPanel._shown = true
    h.state.questChoices = 0
    h.FireEvent("QUEST_COMPLETE")
    h.AdvanceTime(0.10)
    assertEqual(h.calls.GetQuestReward, 1, "GetQuestReward must be called only ONCE during >50ms server RTT")
end)

-- ============================================================================
-- TEST 15: QUEST_TURNED_IN Clears Recently Accepted & Filters Stale Active Turn-In
-- ============================================================================
RunTest("T15: QUEST_TURNED_IN Filters Instant Turn-In (<1.5s) & Repeatable Active Turn-Ins", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule(PREP_PATH, "DynamicSuite")
    h.LoadModule(DIALOGUE_PATH, "DynamicSuite")
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.env.DynamicPrep.db.autoQuestGossip = true

    -- Scenario A: Accept Quest 9001, then turn it in 0.2s later; server leaves stale 9001 in gossipActive
    h.state.onQuest[9001] = true
    h.FireEvent("QUEST_ACCEPTED", 9001)
    h.AdvanceTime(0.20)

    h.state.onQuest[9001] = false
    h.state.completedQuest[9001] = true
    h.FireEvent("QUEST_TURNED_IN", 9001, 0, 0)

    -- Scenario B: Turn in repeatable Quest 9002 (completedQuest stays false!)
    h.state.onQuest[9002] = false
    h.state.completedQuest[9002] = false
    h.FireEvent("QUEST_TURNED_IN", 9002, 0, 0)

    -- Multi-quest NPC returns GOSSIP_SHOW with stale 9001 & 9002 in gossipActive, plus valid 9003 in gossipAvail
    h.state.interactingGossip = true
    h.env.GossipFrame._shown = true
    h.state.gossipActive = {
        { questID = 9001, title = "Instant Turn-In Quest", isComplete = true },
        { questID = 9002, title = "Repeatable Turn-In Quest", isComplete = true, repeatable = true },
    }
    h.state.gossipAvail = {
        { questID = 9002, title = "Repeatable Turn-In Quest", frequency = 1, repeatable = true },
        { questID = 9003, title = "Fresh Next Quest", frequency = 0 },
    }
    h.env.DynamicPrep.db.autoQuestGossip = false
    h.FireEvent("GOSSIP_SHOW")
    h.AdvanceTime(0)

    local opts = h.VisibleOptions()
    assertEqual(#opts, 2, "Stale active turn-ins 9001 & 9002 must be hidden, leaving available 9002 & 9003")
    assertEqual(opts[1].label, "Repeatable Turn-In Quest", "Repeatable 9002 remains available as [QUEST]")
    assertEqual(opts[1].tag, "[QUEST]", "Repeatable 9002 must have [QUEST] tag, not stale [TURN-IN]")
    assertEqual(opts[2].label, "Fresh Next Quest", "Quest 9003 must render cleanly")

    -- Verify DynamicPrep also skips stale 9001 & 9002 in gossipActive and selects available instead
    h.env.DynamicPrep.db.autoQuestGossip = true
    h.FireEvent("GOSSIP_SHOW")
    assertEqual(#h.calls.SelectActiveQuestGossip, 0, "Prep must NOT re-select stale turned-in active quests 9001/9002")
    assertEqual(h.calls.SelectAvailableQuestGossip[1], 9002, "Prep must advance to available quest instead")
end)

-- ============================================================================
-- TEST 16: No Blizzard Frame Flash on Transition, Shift Bypass & Order 5B Race
-- ============================================================================
RunTest("T16: No Outgoing Frame Flash, Shift Bypass Cancels Fallback & Order 5B Race", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule(PREP_PATH, "DynamicSuite")
    h.LoadModule(DIALOGUE_PATH, "DynamicSuite")
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.env.DynamicPrep.db.autoQuestGossip = true

    -- Scenario A: GossipFrame is still Shown when QUEST_DETAIL fires -> must NOT flash to Alpha 1!
    h.state.interactingGossip = true
    h.env.GossipFrame._shown = true
    h.state.gossipAvail = {
        { questID = 9101, title = "Race Quest One", frequency = 0 },
        { questID = 9102, title = "Race Quest Two", frequency = 0 },
    }
    h.FireEvent("GOSSIP_SHOW")
    assertEqual(h.env.GossipFrame:GetAlpha(), 0, "GossipFrame suppressed at Alpha 0")

    -- Transition to QUEST_DETAIL while GossipFrame._shown is still true for 1 frame
    h.state.interactingGossip = false
    h.state.interactingQuest = true
    h.env.QuestFrame._shown = true
    h.state.questID = 9101
    h.state.questTitle = "Race Quest One"
    h.state.questPVP = false
    h.FireEvent("QUEST_DETAIL")
    assertEqual(h.env.GossipFrame:GetAlpha(), 0, "Still-shown GossipFrame must NOT flash back to Alpha 1 on QUEST_DETAIL")

    -- Scenario B (Order 5B): QUEST_FINISHED + GOSSIP_SHOW arrive BEFORE QUEST_ACCEPTED(9101)!
    h.state.interactingQuest = false
    h.state.interactingGossip = true
    h.env.QuestFrame._shown = false
    h.env.GossipFrame._shown = true
    h.FireEvent("QUEST_FINISHED")
    h.FireEvent("GOSSIP_SHOW")
    assertEqual(h.calls.SelectAvailableQuestGossip[2], 9102, "Prep must skip just-accepted 9101 and pick 9102 even before QUEST_ACCEPTED arrives")

    -- Scenario C: Shift held on next QUEST_DETAIL cancels pending fallback and restores QuestFrame to Alpha 1
    h.state.interactingGossip = false
    h.state.interactingQuest = true
    h.env.GossipFrame._shown = false
    h.env.QuestFrame._shown = true
    h.state.questID = 9102
    h.state.questTitle = "Race Quest Two"
    h.state.shiftDown = true
    h.FireEvent("QUEST_DETAIL")
    h.AdvanceTime(0.30)
    local rf = h.env.DynamicDialogueReaderFrame
    assertTrue(not (rf and rf:IsShown()), "Reader must NOT open when Shift bypasses to native Blizzard frame")
    assertEqual(h.env.QuestFrame:GetAlpha(), 1, "QuestFrame alpha must be 1 on Shift bypass")
end)

-- ============================================================================
-- TEST 17: Delayed 0.05s Prep Gossip Retry, Nil-QuestID Greeting & Soft-Disable
-- ============================================================================
RunTest("T17: Delayed 0.05s Prep Retry Hides Reader, Nil-ID Greeting Fallback & Soft-Disable", function()
    local h = CreateHarness({ withSuite = true })
    h.LoadModule(PREP_PATH, "DynamicSuite")
    h.LoadModule(DIALOGUE_PATH, "DynamicSuite")
    h.FireEvent("ADDON_LOADED", "DynamicSuite")
    h.env.DynamicPrep.db.autoQuestGossip = true

    -- Scenario A: World object fires GOSSIP_SHOW with 0 options initially; Dialogue opens at frame 0;
    -- options populate before 0.05s; Prep's 0.05s retry selects the option and hides Dialogue's stale reader!
    h.state.interactingGossip = true
    h.env.GossipFrame._shown = true
    h.state.gossipOpts = {}
    h.state.gossipAvail = {}
    h.state.gossipActive = {}
    h.FireEvent("GOSSIP_SHOW")
    h.AdvanceTime(0)
    local rf = h.env.DynamicDialogueReaderFrame
    assertTrue(rf and rf:IsShown(), "Dialogue opens at frame 0 when initial gossip had 0 options")

    h.state.gossipOpts = {
        { gossipOptionID = 77001, name = "Open the sealed chest", flags = 0, status = 0, orderIndex = 0 },
    }
    h.AdvanceTime(0.06)
    assertEqual(h.calls.SelectOptionGossip[1], 77001, "Prep 0.05s retry must select late-populated single option")
    assertEqual(rf:IsShown(), false, "NotifyExternalAutoAction must immediately hide stale open reader on 0.05s Prep retry")

    -- Clean close
    h.state.interactingGossip = false
    h.FireEvent("GOSSIP_CLOSED")
    h.AdvanceTime(0.30)
    assertEqual(rf:IsShown(), false, "Reader remains closed after gossip ends")

    -- Scenario B: QUEST_GREETING nil-questID fallback filters duplicate title already in active quests
    h.env.DynamicPrep.db.autoQuestGossip = false
    h.state.interactingQuest = true
    h.env.QuestFrame._shown = true
    h.state.greetingActive = {
        { questID = nil, title = "Legacy Title Quest", isComplete = false },
    }
    h.state.greetingAvail = {
        { questID = nil, title = "Legacy Title Quest", frequency = 0 },
        { questID = nil, title = "Second Legacy Quest", frequency = 0 },
    }
    h.FireEvent("QUEST_GREETING")
    h.AdvanceTime(0)
    local opts = h.VisibleOptions()
    assertEqual(#opts, 2, "Duplicate nil-ID available quest matching active title must be filtered")
    assertEqual(opts[1].label, "Legacy Title Quest", "Active quest renders first")
    assertEqual(opts[1].tag, "[IN PROGRESS]", "Active quest shows [IN PROGRESS]")
    assertEqual(opts[2].label, "Second Legacy Quest", "Second available quest renders cleanly")

    -- Scenario C: Mid-session soft-disable of DynamicPrep stops auto-accept immediately
    h.env.DynamicPrep.db.autoQuestGossip = true
    h.env.DynamicSuiteDB.global.disabledModules.DynamicPrep = true
    h.state.questID = 77002
    h.state.questTitle = "Soft-Disabled Prep Test"
    h.state.questPVP = false
    h.FireEvent("QUEST_DETAIL")
    h.AdvanceTime(0)
    assertEqual(h.calls.AcceptQuest, 0, "Soft-disabled DynamicPrep must NOT auto-accept quests")
    assertEqual(rf:IsShown(), true, "DynamicDialogue must render QUEST_DETAIL immediately when Prep is soft-disabled")
end)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
