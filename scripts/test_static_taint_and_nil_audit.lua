-- ============================================================================
-- Permanent Static Taint, Nil-Call & Guard Audit for DynamicSuite (Lua 5.1)
-- Checks all 15 files (DynamicSuite_Core, DynamicSuite_UI, 13 Modules) for:
--   1. Undefined local namespace / helper / module table method calls
--      (plus cross-file addonTable and UI calls)
--   2. Unsafe direct HookScript / SetScript on Blizzard taint-sensitive frames
--      (ChatFrame*EditBox, BankFrame, GuildBankFrame, CompactRaidFrame*,
--       GameTooltip, ItemRefTooltip, StaticPopup*)
--   3. Missing secret-value / UIFrameFade guards on SetAlpha, UIFrameFade*,
--      Blizzard fontString GetStringWidth, and unit aura index reads
-- Plus self-tests proving each check detects real regressions.
-- Pure ASCII Only.
-- ============================================================================

local TARGET_FILES = {
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

local FRAME_WIDGET_METHODS = {
    RegisterEvent = true, UnregisterEvent = true, UnregisterAllEvents = true,
    SetScript = true, GetScript = true, HookScript = true,
    Show = true, Hide = true, SetShown = true, IsShown = true, IsVisible = true,
    GetName = true, SetParent = true, GetParent = true, SetAlpha = true, GetAlpha = true,
    SetScale = true, GetScale = true, GetEffectiveScale = true,
    SetSize = true, SetWidth = true, SetHeight = true, GetWidth = true, GetHeight = true,
    ClearAllPoints = true, SetPoint = true, SetAllPoints = true, GetPoint = true, GetNumPoints = true,
    SetFrameStrata = true, SetFrameLevel = true, GetFrameStrata = true, GetFrameLevel = true,
    EnableMouse = true, EnableMouseWheel = true, EnableKeyboard = true,
    SetAttribute = true, GetAttribute = true, RegisterUnitEvent = true,
    CreateTexture = true, CreateFontString = true,
    SetBackdrop = true, SetBackdropColor = true, SetBackdropBorderColor = true,
    SetMovable = true, SetResizable = true, SetResizeBounds = true,
    SetClampedToScreen = true, SetClampRectInsets = true, SetToplevel = true,
    StartMoving = true, StopMovingOrSizing = true, Raise = true, Lower = true,
    IsEventRegistered = true, IsForbidden = true, SetUserPlaced = true,
    RegisterForDrag = true, RegisterForClicks = true, SetHitRectInsets = true,
    SetClipsChildren = true, SetPropagateKeyboardInput = true,
    GetLeft = true, GetRight = true, GetTop = true, GetBottom = true, GetCenter = true,
    IsMouseOver = true, GetObjectType = true, SetText = true, GetText = true,
    SetColorTexture = true, SetTexture = true, SetVertexColor = true, SetTexCoord = true,
    SetFont = true, SetTextColor = true, SetJustifyH = true, SetJustifyV = true,
}

-- Explicit allowlist ONLY for verified dynamic/external keys with documented reasons.
local ALLOW_EXTERNAL_TABLE_CALLS = {
    -- Example: ["DynamicBags.lua:U.SomeExternalFn"] = "Reason",
}

local HELPER_NAMESPACE_TABLES = {
    addonTable = true, DynamicSuite = true, Suite = true,
    UI = true, U = true, DM = true, DC_NS = true, DP_NS = true,
    DT_NS = true, DG_NS = true, DL_NS = true,
    TypographyMgr = true, SoundMgr = true, DesktopWindows = true,
}

local WOW_STD_GLOBAL_ALLOW = {
    type = true, next = true, select = true, print = true, date = true, time = true,
    pairs = true, ipairs = true, tostring = true, tonumber = true, pcall = true, xpcall = true,
    unpack = true, error = true, assert = true, math = true, string = true, table = true,
    bit = true, wipe = true, tinsert = true, tremove = true,
    GetTime = true, CreateFrame = true, ReloadUI = true, CopyTable = true,
    GetRealmName = true, UnitName = true, UnitClass = true, UnitGUID = true,
    InCombatLockdown = true, IsShiftKeyDown = true, PlaySound = true, PlaySoundFile = true,
    UIParent = true, GameTooltip = true, C_Timer = true, C_AddOns = true, C_CVar = true, C_Map = true,
    SettingsPanel = true, GameMenuFrame = true, RAID_CLASS_COLORS = true, SOUNDKIT = true, Enum = true,
    Show = true, Hide = true, Clear = true, Reset = true, Open = true, Close = true,
    Refresh = true, Update = true, Init = true, Toggle = true, Print = true,
    GetText = true, SetText = true, GetWidth = true, GetHeight = true,
    SetAlpha = true, GetAlpha = true, SetScale = true, GetScale = true,
    IsShown = true, GetName = true, GetParent = true, SetParent = true,
}

local function ReadAll(path)
    local fh, err = io.open(path, "rb")
    if not fh then
        error("Unable to read " .. tostring(path) .. ": " .. tostring(err))
    end
    local data = fh:read("*a")
    fh:close()
    return data
end

-- Linear Lua 5.1 comment & string stripper that preserves exact line numbers.
-- Returns (codeOnly, noCommentsOnly).
local function StripCommentsAndStrings(src)
    local outCode = {}
    local outNoComments = {}
    local n = #src
    local i = 1

    local function pushSpacePreserveNL(dst, s, a, b)
        local seg = s:sub(a, b)
        dst[#dst + 1] = seg:gsub("[^\r\n]", " ")
    end

    local function matchLongBracket(s, pos)
        if s:sub(pos, pos) ~= "[" then return nil end
        local j = pos + 1
        while s:sub(j, j) == "=" do
            j = j + 1
        end
        if s:sub(j, j) == "[" then
            return j - pos - 1, j + 1
        end
        return nil
    end

    while i <= n do
        local c = src:sub(i, i)
        if c == "-" and src:sub(i + 1, i + 1) == "-" then
            local eqCount, bodyStart = matchLongBracket(src, i + 2)
            if eqCount then
                local closePat = "]" .. string.rep("=", eqCount) .. "]"
                local closeStart, closeEnd = src:find(closePat, bodyStart, true)
                local stopAt = closeEnd or n
                pushSpacePreserveNL(outCode, src, i, stopAt)
                pushSpacePreserveNL(outNoComments, src, i, stopAt)
                i = stopAt + 1
            else
                local nl = src:find("\n", i + 2, true)
                local stopAt = nl and (nl - 1) or n
                pushSpacePreserveNL(outCode, src, i, stopAt)
                pushSpacePreserveNL(outNoComments, src, i, stopAt)
                i = stopAt + 1
            end
        elseif c == "[" then
            local eqCount, bodyStart = matchLongBracket(src, i)
            if eqCount then
                local closePat = "]" .. string.rep("=", eqCount) .. "]"
                local closeStart, closeEnd = src:find(closePat, bodyStart, true)
                local stopAt = closeEnd or n
                pushSpacePreserveNL(outCode, src, i, stopAt)
                outNoComments[#outNoComments + 1] = src:sub(i, stopAt)
                i = stopAt + 1
            else
                outCode[#outCode + 1] = c
                outNoComments[#outNoComments + 1] = c
                i = i + 1
            end
        elseif c == '"' or c == "'" then
            local q = c
            local j = i + 1
            while j <= n do
                local ch = src:sub(j, j)
                if ch == "\\" then
                    j = j + 2
                elseif ch == q or ch == "\n" then
                    break
                else
                    j = j + 1
                end
            end
            local stopAt = (j <= n) and j or n
            pushSpacePreserveNL(outCode, src, i, stopAt)
            outNoComments[#outNoComments + 1] = src:sub(i, stopAt)
            i = stopAt + 1
        else
            outCode[#outCode + 1] = c
            outNoComments[#outNoComments + 1] = c
            i = i + 1
        end
    end

    return table.concat(outCode), table.concat(outNoComments)
end

local function SplitLines(s)
    local lines = {}
    local start = 1
    while true do
        local nl = s:find("\n", start, true)
        if not nl then
            local tail = s:sub(start):gsub("\r$", "")
            lines[#lines + 1] = tail
            break
        end
        lines[#lines + 1] = s:sub(start, nl - 1):gsub("\r$", "")
        start = nl + 1
    end
    return lines
end

local function EscapePattern(s)
    return (s:gsub("([^%w])", "%%%1"))
end

local function CollectTableDefs(codeOnly, noComments, tblName, defs)
    defs = defs or {}
    local esc = EscapePattern(tblName)
    for k in noComments:gmatch("function%s+" .. esc .. "[%.:]([%a_][%w_]*)%s*%(") do
        defs[k] = true
    end
    for k in noComments:gmatch(esc .. "%.([%a_][%w_]*)%s*=") do
        defs[k] = true
    end
    for k in noComments:gmatch(esc .. "%[%s*[\"']([%a_][%w_]*)[\"']%s*%]%s*=") do
        defs[k] = true
    end
    -- Detect inline literal keys in `local <tblName> = { ... }` or `<tblName> = { ... }`
    local lines = SplitLines(codeOnly)
    local rawLines = SplitLines(noComments)
    local inLiteral = false
    local depth = 0
    for idx = 1, #lines do
        local ln = lines[idx]
        if not inLiteral then
            local afterEq = ln:match("^%s*local%s+" .. esc .. "%s*=%s*(.*)$")
                or ln:match("^%s*" .. esc .. "%s*=%s*(.*)$")
            if afterEq and afterEq:find("{", 1, true) then
                inLiteral = true
                depth = 0
            end
        end
        if inLiteral then
            local rln = rawLines[idx]
            for cIdx = 1, #ln do
                local ch = ln:sub(cIdx, cIdx)
                if ch == "{" then
                    depth = depth + 1
                elseif ch == "}" then
                    depth = depth - 1
                    if depth <= 0 then
                        inLiteral = false
                        break
                    end
                end
            end
            if depth == 1 then
                for k in rln:gmatch("([%a_][%w_]*)%s*=") do
                    defs[k] = true
                end
            end
        end
    end
    return defs
end

local function DiscoverLocalTables(codeOnly)
    local tbls = {}
    local isFrameBacked = {}
    local lines = SplitLines(codeOnly)
    for _, ln in ipairs(lines) do
        local name, rhs = ln:match("^local%s+([%a_][%w_]*)%s*=%s*(.+)$")
        if name and rhs and name ~= "DynamicSuite" then
            if rhs:match("^%s*{") then
                tbls[name] = true
            elseif rhs:match("CreateFrame%s*%(") then
                tbls[name] = true
                isFrameBacked[name] = true
            elseif rhs:match("^_G%.DynamicSuite%.UI%b()") or rhs:match("^_G%.DynamicSuite%.UI%s*$") then
                tbls[name] = "SUITE_UI"
            end
        end
    end
    return tbls, isFrameBacked
end

local function IsGuardedCall(lines, lineIdx, escTbl, key)
    local line = lines[lineIdx] or ""
    local prev1 = lines[lineIdx - 1] or ""
    local prev2 = lines[lineIdx - 2] or ""
    local ctx = prev2 .. "\n" .. prev1 .. "\n" .. line
    if line:match("type%s*%(%s*" .. escTbl .. "%s*[%.%[]") then return true end
    if ctx:match("if%s+.-" .. escTbl .. "[%.:]" .. key .. "%s+then") then return true end
    if ctx:match("if%s+not%s+" .. escTbl .. "[%.:]" .. key) then return true end
    if ctx:match(escTbl .. "[%.:]" .. key .. "%s+and%s+" .. escTbl .. "[%.:]" .. key) then return true end
    if line:match("or%s+" .. escTbl .. "[%.:]" .. key .. "%s*%(") then return true end
    if ctx:match("type%s*%(%s*" .. escTbl .. "[%.:]" .. key .. "%s*%)%s*==%s*[\"']function[\"']") then return true end
    return false
end

local function AuditUndefinedTableMethods(fileSpecs)
    local violations = {}
    local sharedAddonTableDefs = {}
    local sharedUIDefs = {}
    local parsed = {}

    for _, spec in ipairs(fileSpecs) do
        local codeOnly, noComments = StripCommentsAndStrings(spec.src)
        parsed[#parsed + 1] = {
            name = spec.name,
            codeOnly = codeOnly,
            noComments = noComments,
            lines = SplitLines(codeOnly),
            rawLines = SplitLines(spec.src),
        }
        if spec.name == "DynamicSuite_Core.lua" or spec.name == "DynamicSuite_UI.lua" or spec.name == "DynamicLoad.lua" then
            CollectTableDefs(codeOnly, noComments, "addonTable", sharedAddonTableDefs)
        end
        if spec.name == "DynamicSuite_UI.lua" then
            CollectTableDefs(codeOnly, noComments, "UI", sharedUIDefs)
        end
    end

    for _, pf in ipairs(parsed) do
        local tbls, isFrameBacked = DiscoverLocalTables(pf.codeOnly)
        if pf.name == "DynamicSuite_Core.lua" or pf.name == "DynamicSuite_UI.lua" or pf.name == "DynamicLoad.lua" then
            tbls["addonTable"] = "ADDON_TABLE"
        end
        if pf.name == "DynamicVault.lua" or pf.name == "DynamicLoad.lua" then
            -- Both files bind local UI from _G.DynamicSuite.UI (conditional or direct)
            if pf.codeOnly:find("local%s+UI%s*=") then
                tbls["UI"] = "SUITE_UI"
            end
        end

        for tblName, kind in pairs(tbls) do
            local defs = {}
            if kind == "ADDON_TABLE" then
                defs = sharedAddonTableDefs
            elseif kind == "SUITE_UI" then
                defs = sharedUIDefs
                CollectTableDefs(pf.codeOnly, pf.noComments, tblName, defs)
            else
                CollectTableDefs(pf.codeOnly, pf.noComments, tblName, defs)
            end

            local esc = EscapePattern(tblName)
            for idx, ln in ipairs(pf.lines) do
                if not ln:match("^%s*local%s+function%s+" .. esc .. "[%.:]")
                    and not ln:match("^%s*function%s+" .. esc .. "[%.:]") then
                    local pos = 1
                    while true do
                        local sPos, ePos, op, key = ln:find(esc .. "([%.:])([%a_][%w_]*)%s*%(", pos)
                        if not sPos then break end
                        local prevCh = (sPos > 1) and ln:sub(sPos - 1, sPos - 1) or ""
                        if not prevCh:match("[%w_%.%:]") then
                            local isDefined = (defs[key] == true)
                            local isFrameCall = (isFrameBacked[tblName] and FRAME_WIDGET_METHODS[key] == true)
                            local allowKey = pf.name .. ":" .. tblName .. "." .. key
                            if not isDefined and not isFrameCall and not ALLOW_EXTERNAL_TABLE_CALLS[allowKey] then
                                if not IsGuardedCall(pf.lines, idx, esc, key) then
                                    violations[#violations + 1] = string.format(
                                        "[Check1 Undefined Method] %s:%d -> %s%s%s() is never defined/assigned",
                                        pf.name, idx, tblName, op, key
                                    )
                                end
                            end
                        end
                        pos = ePos + 1
                    end
                end
            end
        end
    end

    local tableHelperKeys = {}
    for _, pf in ipairs(parsed) do
        for tblName in pairs(HELPER_NAMESPACE_TABLES) do
            local esc = EscapePattern(tblName)
            for k in pf.noComments:gmatch("function%s+" .. esc .. "[%.:]([%a_][%w_]*)%s*%(") do
                if #k >= 4 and not WOW_STD_GLOBAL_ALLOW[k] then
                    tableHelperKeys[k] = true
                end
            end
            for k in pf.noComments:gmatch(esc .. "%.([%a_][%w_]*)%s*=%s*function%b()") do
                if #k >= 4 and not WOW_STD_GLOBAL_ALLOW[k] then
                    tableHelperKeys[k] = true
                end
            end
            for k in pf.noComments:gmatch(esc .. "%.([%a_][%w_]*)%s*=%s*function%s*%(") do
                if #k >= 4 and not WOW_STD_GLOBAL_ALLOW[k] then
                    tableHelperKeys[k] = true
                end
            end
        end
    end

    for _, pf in ipairs(parsed) do
        local sameFileDefined = {}
        for fn in pf.noComments:gmatch("local%s+function%s+([%a_][%w_]*)%s*%(") do
            sameFileDefined[fn] = true
        end
        for fn in pf.noComments:gmatch("%f[%a_]function%s+([%a_][%w_]*)%s*%(") do
            sameFileDefined[fn] = true
        end
        for fn in pf.noComments:gmatch("_G%.([%a_][%w_]*)%s*=") do
            sameFileDefined[fn] = true
        end
        for _, ln in ipairs(pf.lines) do
            for declList in ln:gmatch("local%s+([%a_][%w_%s,]*)%s*=") do
                for id in declList:gmatch("[%a_][%w_]*") do
                    sameFileDefined[id] = true
                end
            end
            local fwdList = ln:match("^%s*local%s+([%a_][%w_%s,]*)%s*$")
            if fwdList then
                for id in fwdList:gmatch("[%a_][%w_]*") do
                    sameFileDefined[id] = true
                end
            end
        end
        for idx, ln in ipairs(pf.lines) do
            if not ln:match("^%s*function%s+") and not ln:match("^%s*local%s+function%s+") then
                local pos = 1
                while true do
                    local sPos, ePos, fnName = ln:find("([%a_][%w_]*)%s*%(", pos)
                    if not sPos then break end
                    local prevCh = (sPos > 1) and ln:sub(sPos - 1, sPos - 1) or ""
                    if prevCh ~= "." and prevCh ~= ":" and not prevCh:match("[%w_]") then
                        if tableHelperKeys[fnName] and not sameFileDefined[fnName] then
                            violations[#violations + 1] = string.format(
                                "[Check1b Bare Table Helper] %s:%d -> %s() called without table prefix",
                                pf.name, idx, fnName
                            )
                        end
                    end
                    pos = ePos + 1
                end
            end
        end
    end

    return violations
end

local SENSITIVE_BLIZZ_PATTERNS = {
    { pat = "ChatFrame%d*EditBox", label = "ChatFrame*EditBox" },
    { pat = "BankFrame", label = "BankFrame" },
    { pat = "GuildBankFrame", label = "GuildBankFrame" },
    { pat = "CompactRaidFrame%d*", label = "CompactRaidFrame*" },
    { pat = "GameTooltip", label = "GameTooltip" },
    { pat = "ItemRefTooltip", label = "ItemRefTooltip" },
    { pat = "StaticPopup%d*", label = "StaticPopup*" },
}

local function MatchesSensitiveBlizzFrame(expr)
    if not expr or expr == "" then return nil end
    for _, spec in ipairs(SENSITIVE_BLIZZ_PATTERNS) do
        if expr:match("%f[%a_]" .. spec.pat .. "%f[^%w_]") then
            return spec.label
        end
    end
    if expr:match("EditBox") and expr:match("ChatFrame") then
        return "ChatFrame*EditBox"
    end
    if expr:match("StaticPopup") then
        return "StaticPopup*"
    end
    return nil
end

local function AuditBlizzardFrameHooks(fileSpecs)
    local violations = {}
    for _, spec in ipairs(fileSpecs) do
        local codeOnly, noComments = StripCommentsAndStrings(spec.src)
        local lines = SplitLines(codeOnly)
        local rawLines = SplitLines(noComments)
        local localBindings = {}
        local localCreated = {}

        for idx, ln in ipairs(lines) do
            local rln = rawLines[idx] or ln
            -- Track local variable bindings pointing to sensitive Blizzard frames (within recent scope)
            local varName, rhs = rln:match("local%s+([%a_][%w_]*)%s*=%s*(.+)$")
            if varName and rhs then
                if rhs:match("CreateFrame%s*%(") then
                    localCreated[varName] = idx
                    localBindings[varName] = nil
                else
                    localCreated[varName] = nil
                    local sens = MatchesSensitiveBlizzFrame(rhs)
                    if sens then
                        localBindings[varName] = { label = sens, line = idx }
                    else
                        localBindings[varName] = nil
                    end
                end
            end
            -- Also track function parameters named panel/popup/tooltip/eb when caller passes sensitive frame
            for _, fnWord in ipairs({ "HookScript", "SetScript" }) do
                local pos = 1
                while true do
                    local sPos, ePos, recv = ln:find("([%a_][%w_%.%[%]]*)%s*:%s*" .. fnWord .. "%s*%(", pos)
                    if not sPos then
                        sPos, ePos, recv = ln:find("([%a_][%w_%.%[%]]*)%s*%." .. fnWord .. "%s*%(", pos)
                    end
                    if not sPos then break end

                    local isAddonCreated = (localCreated[recv] ~= nil and (idx - localCreated[recv]) <= 60)
                    local sens = MatchesSensitiveBlizzFrame(recv)
                    if not sens and localBindings[recv] and (idx - localBindings[recv].line) <= 35 then
                        sens = localBindings[recv].label
                    end
                    -- Check for SuppressBankPanel(BankFrame, ...) style wrapper in surrounding 30 lines
                    if not sens and not isAddonCreated and (recv == "panel" or recv == "popup" or recv == "dialog" or recv == "eb" or recv == "editBox") then
                        local wStart = math.max(1, idx - 30)
                        local wEnd = math.min(#rawLines, idx + 35)
                        local window = table.concat(rawLines, "\n", wStart, wEnd)
                        local wSens = MatchesSensitiveBlizzFrame(window)
                        if wSens and not window:match("CreateFrame%s*%([^%)]*" .. EscapePattern(recv)) then
                            sens = wSens
                        end
                    end

                    if sens then
                        violations[#violations + 1] = string.format(
                            "[Check2 Blizzard Hook Hygiene] %s:%d -> direct %s:%s(...) on taint-sensitive %s",
                            spec.name, idx, recv, fnWord, sens
                        )
                    end
                    pos = ePos + 1
                end
            end
        end
    end
    return violations
end

local function GetLineWindow(lines, idx, back, fwd)
    local a = math.max(1, idx - (back or 15))
    local b = math.min(#lines, idx + (fwd or 2))
    return table.concat(lines, "\n", a, b)
end

local function AuditSecretAndFadeGuards(fileSpecs)
    local violations = {}
    for _, spec in ipairs(fileSpecs) do
        local codeOnly, noComments = StripCommentsAndStrings(spec.src)
        local lines = SplitLines(codeOnly)
        local rawLines = SplitLines(noComments)

        for idx, ln in ipairs(lines) do
            -- (3a) Blizzard-frame SetAlpha calls must have UIFrameFade / secret fadeInfo guard
            local alphaTarget = ln:match("([%a_][%w_%.]*)%s*:%s*SetAlpha%s*%(")
                or ln:match("pcall%s*%(%s*([%a_][%w_%.]*)%.SetAlpha%s*,")
            if alphaTarget then
                local isBlizzAlpha = false
                if alphaTarget:match("^_G%.ChatFrame%d*Tab")
                    or alphaTarget:match("^_G%.ChatFrame%d+$")
                    or alphaTarget == "BankFrame" or alphaTarget == "_G.BankFrame"
                    or alphaTarget == "GuildBankFrame" or alphaTarget == "_G.GuildBankFrame"
                    or alphaTarget == "GameTooltip" or alphaTarget == "_G.GameTooltip" then
                    isBlizzAlpha = true
                elseif spec.name == "DynamicChat.lua" and (alphaTarget == "tab" or alphaTarget == "fs" or alphaTarget == "selfTab") then
                    isBlizzAlpha = true
                end
                if isBlizzAlpha then
                    local win = GetLineWindow(lines, idx, 18, 2)
                    local hasFadeGuard = win:match("UIFrameIsFading")
                        or win:match("fadeInfo")
                        or win:match("CanSafelySetChatTabAlpha")
                        or win:match("SafeSetBlizzFrameAlpha")
                        or win:match("SetRegionAlphaSafe")
                    if not hasFadeGuard then
                        violations[#violations + 1] = string.format(
                            "[Check3a UIFrameFade Guard] %s:%d -> unguarded %s SetAlpha() without UIFrameIsFading/fadeInfo guard",
                            spec.name, idx, alphaTarget
                        )
                    end
                end
            end

            -- (3b) Direct UIFrameFade* calls on Blizzard frames must check secret/fadeInfo
            if ln:match("UIFrameFade%a*%s*%(") then
                local win = GetLineWindow(lines, idx, 12, 2)
                local hasGuard = win:match("issecretvalue") or win:match("IsSecret") or win:match("fadeInfo")
                if not hasGuard then
                    violations[#violations + 1] = string.format(
                        "[Check3b UIFrameFade Guard] %s:%d -> unguarded UIFrameFade* call",
                        spec.name, idx
                    )
                end
            end

            -- (3c) GetStringWidth on Blizzard chat/editbox/tooltip headers must use pcall + secret guard
            local swTarget = ln:match("([%a_][%w_%.]*)%s*:%s*GetStringWidth%s*%(")
                or ln:match("pcall%s*%(%s*([%a_][%w_%.]*)%.GetStringWidth")
            if swTarget then
                local isSensitiveHeader = swTarget:match("ChatFrame")
                    or swTarget:match("EditBox")
                    or swTarget:match("GameTooltip")
                    or swTarget == "hdr"
                    or swTarget == "hdrSuffix"
                    or swTarget == "eb.header"
                    or swTarget == "eb.headerSuffix"
                    or swTarget == "editBox.header"
                    or swTarget == "editBox.headerSuffix"
                if isSensitiveHeader then
                    local win = GetLineWindow(lines, idx, 12, 6)
                    local hasPcall = win:match("pcall")
                    local hasSecret = win:match("IsSecretValue") or win:match("issecretvalue") or win:match("_IsSecret") or win:match("SafeGetStringWidth")
                    if not (hasPcall and hasSecret) then
                        violations[#violations + 1] = string.format(
                            "[Check3c Secret GetStringWidth] %s:%d -> %s:GetStringWidth() missing pcall + secret guard",
                            spec.name, idx, swTarget
                        )
                    end
                end
            end

            -- (3d) Unit aura index/direct reads must guard secret values
            if ln:match("C_UnitAuras%.GetAuraDataByIndex")
                or ln:match("C_UnitAuras%.GetBuffDataByIndex")
                or ln:match("%f[%a_]UnitAura%s*%(") then
                local win = GetLineWindow(lines, idx, 8, 22)
                local hasSecret = win:match("_IsSecret")
                    or win:match("IsSecretValue")
                    or win:match("IsSecret")
                    or win:match("issecretvalue")
                    or win:match("canaccessvalue")
                if not hasSecret then
                    violations[#violations + 1] = string.format(
                        "[Check3d Secret Aura Guard] %s:%d -> aura read missing secret-value guard",
                        spec.name, idx
                    )
                end
            end
        end
    end
    return violations
end

-- ============================================================================
-- Run Self-Tests on Synthetic Bug Snippets
-- ============================================================================
local function RunSelfTests()
    local selfCases = {
        {
            name = "Catches undefined U.GetSuiteAccent()",
            fn = AuditUndefinedTableMethods,
            spec = {
                name = "SyntheticBags.lua",
                src = "local U = {}\nlocal function f()\n  local r, g, b = U.GetSuiteAccent()\nend\n",
            },
            expectSub = "U.GetSuiteAccent",
        },
        {
            name = "Catches bare GetActiveAccentColor() missing UI. prefix",
            fn = AuditUndefinedTableMethods,
            spec = {
                name = "SyntheticUI.lua",
                src = "local UI = {}\nfunction UI.GetActiveAccentColor() return 1, 1, 1 end\nlocal function f()\n  local r, g, b = GetActiveAccentColor()\nend\n",
            },
            expectSub = "Check1b Bare Table Helper",
        },
        {
            name = "Catches ChatFrame1EditBox:HookScript('OnTextChanged')",
            fn = AuditBlizzardFrameHooks,
            spec = {
                name = "SyntheticChat.lua",
                src = "local function h(eb)\n  ChatFrame1EditBox:HookScript(\"OnTextChanged\", function() end)\nend\n",
            },
            expectSub = "ChatFrame*EditBox",
        },
        {
            name = "Catches BankFrame:HookScript('OnShow')",
            fn = AuditBlizzardFrameHooks,
            spec = {
                name = "SyntheticBags.lua",
                src = "local function s()\n  BankFrame:HookScript(\"OnShow\", function() end)\nend\n",
            },
            expectSub = "BankFrame",
        },
        {
            name = "Catches StaticPopup1:HookScript('OnShow')",
            fn = AuditBlizzardFrameHooks,
            spec = {
                name = "SyntheticPrep.lua",
                src = "local popup = _G[\"StaticPopup1\"]\npopup:HookScript(\"OnShow\", function() end)\n",
            },
            expectSub = "StaticPopup*",
        },
        {
            name = "Catches GameTooltip:HookScript('OnShow') and CompactRaidFrame1:SetScript('OnEvent')",
            fn = AuditBlizzardFrameHooks,
            spec = {
                name = "SyntheticTooltip.lua",
                src = "GameTooltip:HookScript(\"OnShow\", function() end)\nCompactRaidFrame1:SetScript(\"OnEvent\", function() end)\n",
            },
            expectSub = "GameTooltip",
        },
        {
            name = "Catches unguarded _G.ChatFrame1:SetAlpha(1.0)",
            fn = AuditSecretAndFadeGuards,
            spec = {
                name = "SyntheticUI.lua",
                src = "local function f()\n  _G.ChatFrame1:SetAlpha(1.0)\nend\n",
            },
            expectSub = "Check3a UIFrameFade Guard",
        },
        {
            name = "Catches unguarded ChatFrame1EditBox.header:GetStringWidth()",
            fn = AuditSecretAndFadeGuards,
            spec = {
                name = "SyntheticChat.lua",
                src = "local function f()\n  local w = ChatFrame1EditBox.header:GetStringWidth()\nend\n",
            },
            expectSub = "Check3c Secret GetStringWidth",
        },
        {
            name = "Catches unguarded C_UnitAuras.GetBuffDataByIndex",
            fn = AuditSecretAndFadeGuards,
            spec = {
                name = "SyntheticAura.lua",
                src = "local function f()\n  local a = C_UnitAuras.GetBuffDataByIndex(\"player\", 1)\n  return a.name\nend\n",
            },
            expectSub = "Check3d Secret Aura Guard",
        },
    }

    for _, tc in ipairs(selfCases) do
        local hits = tc.fn({ tc.spec })
        local matched = false
        for _, h in ipairs(hits) do
            if h:find(tc.expectSub, 1, true) then
                matched = true
                break
            end
        end
        if not matched then
            error("SELF-TEST FAILED: " .. tc.name .. " (got " .. tostring(#hits) .. " hit(s))")
        end
    end
    print(string.format("[SELF-TEST OK] Verified %d synthetic taint/nil/fade audit detections", #selfCases))
end

-- ============================================================================
-- Execute Full Static Audit Across All 15 DynamicSuite Lua Files
-- ============================================================================
RunSelfTests()

local fileSpecs = {}
for _, relPath in ipairs(TARGET_FILES) do
    local baseName = relPath:match("([^/]+)$")
    fileSpecs[#fileSpecs + 1] = {
        name = baseName,
        path = relPath,
        src = ReadAll(relPath),
    }
end

local allViolations = {}
for _, v in ipairs(AuditUndefinedTableMethods(fileSpecs)) do allViolations[#allViolations + 1] = v end
for _, v in ipairs(AuditBlizzardFrameHooks(fileSpecs)) do allViolations[#allViolations + 1] = v end
for _, v in ipairs(AuditSecretAndFadeGuards(fileSpecs)) do allViolations[#allViolations + 1] = v end

if #allViolations > 0 then
    print(string.format("[STATIC AUDIT FAILED] Found %d violation(s):", #allViolations))
    for _, v in ipairs(allViolations) do
        print("  - " .. v)
    end
    os.exit(1)
end

print(string.format("[STATIC AUDIT PASS] 0 violations across %d DynamicSuite Lua file(s)", #fileSpecs))
