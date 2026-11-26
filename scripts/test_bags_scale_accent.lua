-- ============================================================================
-- Headless Lua 5.1 Regression Suite: DynamicBags Header Hover & Scale Toast
-- Verifies (Suite + Standalone parity):
--   1. DynamicBags & DynamicBank header OnEnter tooltips run with 0 nil errors
--   2. Ctrl+Scroll (session scale), Ctrl+Shift+Scroll (saved scale), and
--      Right-Click (reset 100%) invoke ShowBagScaleToast cleanly via GetAccent()
-- Pure ASCII Only.
-- ============================================================================

local BAGS_PATH = "DynamicSuite/Modules/DynamicBags.lua"

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

local function assertNear(actual, expected, msg)
    if type(actual) ~= "number" or math.abs(actual - expected) > 0.001 then
        failed = failed + 1
        error(string.format("ASSERTION FAILED: %s (expected=%s, actual=%s)",
            tostring(msg), tostring(expected), tostring(actual)), 2)
    end
end

local function CreateHarness(opts)
    opts = opts or {}
    local env = {}
    setmetatable(env, { __index = _G })
    env._G = env

    local state = {
        ctrlDown = false,
        shiftDown = false,
        inCombat = false,
    }
    local tooltipLines = {}

    env.InCombatLockdown = function() return state.inCombat end
    env.IsControlKeyDown = function() return state.ctrlDown end
    env.IsShiftKeyDown = function() return state.shiftDown end
    env.IsAltKeyDown = function() return false end
    env.GetCursorInfo = function() return nil end
    env.GetMoney = function() return 0 end
    env.GetTime = function() return 100 end
    env.GetScreenWidth = function() return 1920 end
    env.GetScreenHeight = function() return 1080 end
    env.UnitName = function() return "Dentee" end
    env.UnitClass = function() return "Mage", "MAGE", 8 end
    env.GetRealmName = function() return "Frostmourne" end
    env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    env.UISpecialFrames = {}
    env.SlashCmdList = {}
    env.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
    env.C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerNumFreeSlots = function() return 0, 0 end }
    env.C_CurrencyInfo = { GetBackpackCurrencyInfo = function() return nil end, GetCurrencyListSize = function() return 0 end }
    env.C_Bank = { FetchDepositedMoney = function() return 0 end, CanUseBank = function() return false end }
    env.GetGuildBankMoney = function() return 0 end
    env.GetGuildBankWithdrawMoney = function() return 0 end
    env.CanWithdrawGuildBankMoney = function() return false end
    env.IsInGuild = function() return false end
    env.tinsert = table.insert
    env.tremove = table.remove
    env.wipe = function(t)
        if type(t) ~= "table" then return t end
        for k in pairs(t) do t[k] = nil end
        return t
    end
    env.hooksecurefunc = function() end
    env.C_AddOns = {
        GetAddOnMetadata = function() return "2.11.2" end,
        IsAddOnLoaded = function() return false end,
        GetAddOnEnableState = function() return 0 end,
    }
    env.C_Timer = {
        After = function(_, fn) if fn then fn() end end,
        NewTimer = function() return { Cancel = function() end } end,
    }
    env.C_EventUtils = { IsEventValid = function() return true end }

    local function NewWidget(wType, name, parent)
        local w = {
            _type = wType,
            _name = name,
            _parent = parent,
            _shown = true,
            _alpha = 1,
            _scale = 1,
            _width = 520,
            _height = 420,
            _scripts = {},
            _events = {},
            _points = {},
            _text = "",
            _textColor = nil,
            _borderColor = nil,
        }
        function w:GetName() return self._name end
        function w:GetObjectType() return self._type end
        function w:SetParent(p) self._parent = p end
        function w:GetParent() return self._parent end
        function w:Show() self._shown = true end
        function w:Hide() self._shown = false end
        function w:SetShown(v) self._shown = (v == true) end
        function w:IsShown() return self._shown == true end
        function w:SetAlpha(a) self._alpha = a end
        function w:GetAlpha() return self._alpha end
        function w:EnableMouse() end
        function w:EnableMouseWheel() end
        function w:EnableKeyboard() end
        function w:SetPropagateKeyboardInput() end
        function w:SetMovable() end
        function w:SetResizable() end
        function w:SetResizeBounds() end
        function w:SetToplevel() end
        function w:SetUserPlaced() end
        function w:RegisterForDrag() end
        function w:RegisterForClicks() end
        function w:StartMoving() end
        function w:StopMovingOrSizing() end
        function w:SetClipsChildren() end
        function w:SetClampedToScreen() end
        function w:SetClampRectInsets() end
        function w:SetHitRectInsets() end
        function w:SetFrameStrata() end
        function w:SetFrameLevel() end
        function w:GetFrameLevel() return 10 end
        function w:GetFrameStrata() return "MEDIUM" end
        function w:SetAutoFocus() end
        function w:SetMaxLetters() end
        function w:SetNumeric() end
        function w:SetTextInsets() end
        function w:SetFontObject() end
        function w:SetFocus() end
        function w:ClearFocus() end
        function w:HasFocus() return false end
        function w:HighlightText() end
        function w:SetCursorPosition() end
        function w:SetScrollChild(c) self._scrollChild = c end
        function w:GetScrollChild() return self._scrollChild end
        function w:SetVerticalScroll(v) self._vScroll = v end
        function w:GetVerticalScroll() return self._vScroll or 0 end
        function w:GetVerticalScrollRange() return 0 end
        function w:SetColorTexture() end
        function w:SetTexture() end
        function w:SetVertexColor() end
        function w:SetTexCoord() end
        function w:SetRotation() end
        function w:SetDesaturated() end
        function w:SetSnapToPixelGrid() end
        function w:SetTexelSnappingBias() end
        function w:SetNormalTexture() end
        function w:SetPushedTexture() end
        function w:SetHighlightTexture() end
        function w:GetStringWidth() return 60 end
        function w:GetUnboundedStringWidth() return 60 end
        function w:GetStringHeight() return 14 end
        function w:SetEnabled() end
        function w:IsEnabled() return true end
        function w:IsMouseOver() return false end
        function w:Raise() end
        function w:SetSize(ww, hh) self._width = ww; self._height = hh end
        function w:SetWidth(ww) self._width = ww end
        function w:SetHeight(hh) self._height = hh end
        function w:GetWidth() return self._width end
        function w:GetHeight() return self._height end
        function w:GetLeft() return 200 end
        function w:GetRight() return 200 + self._width end
        function w:GetTop() return 620 end
        function w:GetBottom() return 620 - self._height end
        function w:SetScale(s) self._scale = s end
        function w:GetScale() return self._scale end
        function w:GetEffectiveScale() return self._scale end
        function w:ClearAllPoints() self._points = {} end
        function w:SetPoint(pt, relTo, relPt, x, y) table.insert(self._points, { pt, relTo, relPt, x, y }) end
        function w:SetAllPoints() end
        function w:SetBackdrop() end
        function w:SetBackdropColor() end
        function w:SetBackdropBorderColor(r, g, b, a) self._borderColor = { r, g, b, a } end
        function w:SetText(t) self._text = t end
        function w:GetText() return self._text end
        function w:SetTextColor(r, g, b, a) self._textColor = { r, g, b, a } end
        function w:SetFont() return true end
        function w:SetShadowColor() end
        function w:SetShadowOffset() end
        function w:SetJustifyH() end
        function w:SetJustifyV() end
        function w:SetWordWrap() end
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
        function w:CreateFontString() return NewWidget("FontString", nil, self) end
        function w:CreateTexture() return NewWidget("Texture", nil, self) end
        if name then env[name] = w end
        return w
    end

    env.UIParent = NewWidget("Frame", "UIParent", nil)
    env.UIParent._width = 1920
    env.UIParent._height = 1080
    env.CreateFrame = function(wType, name, parent)
        return NewWidget(wType, name, parent)
    end

    env.GameTooltip = NewWidget("GameTooltip", "GameTooltip", env.UIParent)
    env.GameTooltip.SetOwner = function(self, owner, anchor)
        self._owner = owner
        self._anchor = anchor
        tooltipLines = {}
    end
    env.GameTooltip.AddLine = function(_, text, r, g, b)
        table.insert(tooltipLines, { text = text, r = r, g = g, b = b })
    end

    if opts.withSuite then
        env.DynamicSuite = {
            version = "2.11.2",
            modules = {},
            Changelogs = {},
            RegisterModule = function() end,
            GetSuiteAccent = function() return 0.22, 0.74, 0.97 end,
        }
        env.DynamicSuiteDB = { global = { disabledModules = {} } }
    end

    local chunk, err = loadfile(BAGS_PATH)
    if not chunk then error("Failed to load " .. BAGS_PATH .. ": " .. tostring(err)) end
    setfenv(chunk, env)
    chunk(opts.withSuite and "DynamicSuite" or "DynamicBags")

    return {
        env = env,
        state = state,
        NewWidget = NewWidget,
        GetTooltipLines = function() return tooltipLines end,
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

local function VerifyBagsScaleAndHeader(modeLabel, withSuite, expR, expG, expB)
    RunTest(modeLabel .. ": Header OnEnter Tooltip & Scale Toast Use GetAccent()", function()
        local h = CreateHarness({ withSuite = withSuite })
        local dbag = h.env.DynamicBags
        assertTrue(dbag and dbag.U, "DynamicBags.U must exist")
        dbag.InitDB()

        local capturedHeads = {}
        local origAttach = dbag.U.AttachWindowScaleHandlers
        dbag.U.AttachWindowScaleHandlers = function(targetKind, headFrame, fullFrames)
            capturedHeads[targetKind] = headFrame
            return origAttach(targetKind, headFrame, fullFrames)
        end

        local bagWin = dbag.U.EnsureWindow()
        local bankWin = dbag.U.EnsureCompanionBankWindow()
        local bagHead = capturedHeads["bag"]
        local bankHead = capturedHeads["bank"]
        assertTrue(bagWin and bagHead, "DynamicBags window and header must build cleanly")
        assertTrue(bankWin and bankHead, "DynamicBank window and header must build cleanly")

        -- 1. Hover DynamicBags header -> OnEnter tooltip must succeed with accent colour
        bagHead:GetScript("OnEnter")(bagHead)
        local lines = h.GetTooltipLines()
        assertTrue(#lines >= 4, "DynamicBags header tooltip must add control lines")
        assertEqual(lines[1].text, "DynamicBags Window Controls", "Bag header tooltip title")
        assertNear(lines[1].r, expR, "Bag header tooltip accent R")
        assertNear(lines[1].g, expG, "Bag header tooltip accent G")
        assertNear(lines[1].b, expB, "Bag header tooltip accent B")

        -- 2. Hover DynamicBank header -> OnEnter tooltip must succeed with accent colour
        bankHead:GetScript("OnEnter")(bankHead)
        lines = h.GetTooltipLines()
        assertTrue(#lines >= 4, "DynamicBank header tooltip must add control lines")
        assertEqual(lines[1].text, "DynamicBank Window Controls", "Bank header tooltip title")
        assertNear(lines[1].r, expR, "Bank header tooltip accent R")

        -- 3. Ctrl+Scroll on bag header -> session scale step + ShowBagScaleToast
        h.state.ctrlDown = true
        h.state.shiftDown = false
        bagHead:GetScript("OnMouseWheel")(bagHead, 1)
        assertNear(bagWin:GetScale(), 1.05, "Bag window stepped to 1.05")
        local toast = h.env.DynamicBagsWindowScaleToast
        assertTrue(toast ~= nil and toast:IsShown(), "Scale toast must be created and shown")
        assertEqual(toast.text:GetText(), "Session Scale: 105%", "Session scale toast text")
        assertNear(toast.text._textColor[1], expR, "Toast accent R")
        assertNear(toast.text._textColor[2], expG, "Toast accent G")
        assertNear(toast.text._textColor[3], expB, "Toast accent B")

        -- 4. Ctrl+Shift+Scroll on bank window -> permanent scale step + ShowBagScaleToast
        h.state.ctrlDown = true
        h.state.shiftDown = true
        bankWin:GetScript("OnMouseWheel")(bankWin, -1)
        assertNear(bankWin:GetScale(), 0.95, "Bank window stepped to 0.95")
        assertNear(h.env.DynamicBagsDB.bankScale, 0.95, "Bank permanent scale saved to DB")
        assertEqual(toast.text:GetText(), "Saved Scale: 95%", "Saved scale toast text")

        -- 5. Right-Click on bag & bank headers -> reset to 100% + ShowBagScaleToast
        h.state.ctrlDown = false
        h.state.shiftDown = false
        bagHead:GetScript("OnMouseUp")(bagHead, "RightButton")
        assertNear(bagWin:GetScale(), 1.0, "Bag window scale reset to 1.0")
        assertEqual(toast.text:GetText(), "Scale Reset: 100%", "Bag reset toast text")

        bankHead:GetScript("OnMouseUp")(bankHead, "RightButton")
        assertNear(bankWin:GetScale(), 1.0, "Bank window scale reset to 1.0")
        assertEqual(toast.text:GetText(), "Scale Reset: 100%", "Bank reset toast text")
    end)
end

VerifyBagsScaleAndHeader("Suite Mode", true, 0.22, 0.74, 0.97)
VerifyBagsScaleAndHeader("Standalone Mode", false, 0.376, 0.647, 0.980)

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
