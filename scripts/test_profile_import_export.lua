-- ============================================================================
-- Headless Lua 5.1 Regression Suite: Suite-Wide Profile Import & Export (!DS1!)
-- Exercises real DynamicSuite_Core.lua and real DynamicMarker.lua (both bundled
-- and standalone) with deterministic pure-Lua C_EncodingUtil (CBOR + Zlib + Base64).
-- Pure ASCII Only.
-- ============================================================================

local CORE_PATH   = "DynamicSuite/DynamicSuite_Core.lua"
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

-- ============================================================================
-- Pure-Lua 5.1 Base64 + Zlib (RFC 1950 + Adler32) + CBOR Mock for C_EncodingUtil
-- ============================================================================
local B64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_DEC = {}
for i = 1, #B64_ALPHABET do
    B64_DEC[B64_ALPHABET:sub(i, i)] = i - 1
end

local function Base64Encode(data)
    local out = {}
    local len = #data
    local i = 1
    while i <= len do
        local b1 = data:byte(i) or 0
        local b2 = data:byte(i + 1)
        local b3 = data:byte(i + 2)
        local n = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = B64_ALPHABET:sub(c1 + 1, c1 + 1)
        out[#out + 1] = B64_ALPHABET:sub(c2 + 1, c2 + 1)
        out[#out + 1] = b2 and B64_ALPHABET:sub(c3 + 1, c3 + 1) or "="
        out[#out + 1] = b3 and B64_ALPHABET:sub(c4 + 1, c4 + 1) or "="
        i = i + 3
    end
    return table.concat(out)
end

local function Base64Decode(str)
    if type(str) ~= "string" or (#str % 4) ~= 0 or #str == 0 then
        error("Invalid Base64 length")
    end
    local out = {}
    local i = 1
    local len = #str
    while i <= len do
        local s1 = str:sub(i, i)
        local s2 = str:sub(i + 1, i + 1)
        local s3 = str:sub(i + 2, i + 2)
        local s4 = str:sub(i + 3, i + 3)
        local v1, v2 = B64_DEC[s1], B64_DEC[s2]
        local v3 = (s3 == "=") and 0 or B64_DEC[s3]
        local v4 = (s4 == "=") and 0 or B64_DEC[s4]
        if not v1 or not v2 or not v3 or not v4 then
            error("Invalid Base64 character")
        end
        if (s3 == "=" and s4 ~= "=") or ((s3 == "=" or s4 == "=") and i + 3 < len) then
            error("Invalid Base64 padding")
        end
        local n = v1 * 262144 + v2 * 4096 + v3 * 64 + v4
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if s3 ~= "=" then
            out[#out + 1] = string.char(math.floor(n / 256) % 256)
        end
        if s4 ~= "=" then
            out[#out + 1] = string.char(n % 256)
        end
        i = i + 4
    end
    return table.concat(out)
end

local function Adler32(data)
    local a, b = 1, 0
    for i = 1, #data do
        a = (a + data:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end

local function ZlibCompress(raw)
    local out = { string.char(0x78, 0x9C) }
    local len = #raw
    local pos = 1
    repeat
        local chunkEnd = math.min(len, pos + 65534)
        local chunk = (len > 0) and raw:sub(pos, chunkEnd) or ""
        local isFinal = (chunkEnd >= len) and 1 or 0
        local clen = #chunk
        local nlen = 65535 - clen
        out[#out + 1] = string.char(isFinal, clen % 256, math.floor(clen / 256), nlen % 256, math.floor(nlen / 256))
        out[#out + 1] = chunk
        pos = chunkEnd + 1
    until pos > len
    local adler = Adler32(raw)
    out[#out + 1] = string.char(
        math.floor(adler / 16777216) % 256,
        math.floor(adler / 65536) % 256,
        math.floor(adler / 256) % 256,
        adler % 256
    )
    return table.concat(out)
end

local function ZlibDecompress(blob)
    if type(blob) ~= "string" or #blob < 11 then error("Truncated Zlib stream") end
    local cmf, flg = blob:byte(1, 2)
    if cmf ~= 0x78 or ((cmf * 256 + flg) % 31) ~= 0 then error("Bad Zlib header") end
    local pos = 3
    local parts = {}
    while true do
        if pos + 4 > #blob - 4 then error("Truncated DEFLATE block") end
        local bhdr = blob:byte(pos)
        local isFinal = (bhdr % 2) == 1
        local btype = math.floor(bhdr / 2) % 4
        if btype ~= 0 then error("Unsupported DEFLATE block type") end
        local l1, l2, n1, n2 = blob:byte(pos + 1, pos + 4)
        local clen = l1 + l2 * 256
        local nlen = n1 + n2 * 256
        if clen + nlen ~= 65535 then error("Corrupt DEFLATE block length") end
        pos = pos + 5
        if pos + clen - 1 > #blob - 4 then error("Truncated DEFLATE payload") end
        parts[#parts + 1] = blob:sub(pos, pos + clen - 1)
        pos = pos + clen
        if isFinal then break end
    end
    if pos + 3 ~= #blob then error("Trailing bytes after Zlib stream") end
    local raw = table.concat(parts)
    local a1, a2, a3, a4 = blob:byte(pos, pos + 3)
    local expected = a1 * 16777216 + a2 * 65536 + a3 * 256 + a4
    if Adler32(raw) ~= expected then error("Adler32 checksum mismatch") end
    return raw
end

local function EncodeUint(major, val)
    local base = major * 32
    if val < 24 then
        return string.char(base + val)
    elseif val < 256 then
        return string.char(base + 24, val)
    elseif val < 65536 then
        return string.char(base + 25, math.floor(val / 256) % 256, val % 256)
    else
        return string.char(base + 26,
            math.floor(val / 16777216) % 256,
            math.floor(val / 65536) % 256,
            math.floor(val / 256) % 256,
            val % 256)
    end
end

local function EncodeFloat64(val)
    if val == 0 then
        return string.char(0xFB, 0, 0, 0, 0, 0, 0, 0, 0)
    end
    local sign = 0
    if val < 0 then sign = 1; val = -val end
    local m, e = math.frexp(val)
    local exp = e + 1022
    local frac = (m * 2 - 1) * (2 ^ 52)
    local hi = sign * 2147483648 + exp * 1048576 + math.floor(frac / 4294967296)
    local lo = math.floor(frac % 4294967296)
    return string.char(
        0xFB,
        math.floor(hi / 16777216) % 256,
        math.floor(hi / 65536) % 256,
        math.floor(hi / 256) % 256,
        hi % 256,
        math.floor(lo / 16777216) % 256,
        math.floor(lo / 65536) % 256,
        math.floor(lo / 256) % 256,
        lo % 256
    )
end

local function CBOREncode(v)
    local tv = type(v)
    if tv == "boolean" then
        return string.char(v and 0xF5 or 0xF4)
    elseif tv == "number" then
        if v ~= v or v >= 1e308 or v <= -1e308 then error("Non-finite number") end
        if math.floor(v) == v and v >= -2147483648 and v <= 2147483647 then
            if v >= 0 then return EncodeUint(0, v) else return EncodeUint(1, -1 - v) end
        end
        return EncodeFloat64(v)
    elseif tv == "string" then
        return EncodeUint(3, #v) .. v
    elseif tv == "table" then
        local n = #v
        local count = 0
        local isArr = true
        for k in pairs(v) do
            count = count + 1
            if type(k) ~= "number" or k < 1 or k > n or math.floor(k) ~= k then
                isArr = false
            end
        end
        if count ~= n then isArr = false end
        if isArr then
            local out = { EncodeUint(4, n) }
            for i = 1, n do out[#out + 1] = CBOREncode(v[i]) end
            return table.concat(out)
        else
            local keys = {}
            for k in pairs(v) do
                if type(k) ~= "string" then error("CBOR map must use string keys (got " .. type(k) .. ")") end
                keys[#keys + 1] = k
            end
            table.sort(keys)
            local out = { EncodeUint(5, #keys) }
            for _, k in ipairs(keys) do
                out[#out + 1] = CBOREncode(k)
                out[#out + 1] = CBOREncode(v[k])
            end
            return table.concat(out)
        end
    else
        error("Unsupported CBOR type: " .. tv)
    end
end

local function CBORDecode(bin)
    local pos = 1
    local len = #bin
    local function ReadUint(ai)
        if ai < 24 then return ai end
        if ai == 24 then
            if pos > len then error("EOF") end
            local v = bin:byte(pos); pos = pos + 1; return v
        elseif ai == 25 then
            if pos + 1 > len then error("EOF") end
            local b1, b2 = bin:byte(pos, pos + 1); pos = pos + 2
            return b1 * 256 + b2
        elseif ai == 26 then
            if pos + 3 > len then error("EOF") end
            local b1, b2, b3, b4 = bin:byte(pos, pos + 3); pos = pos + 4
            return b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
        end
        error("Unsupported CBOR int length")
    end
    local function ReadItem()
        if pos > len then error("Unexpected EOF") end
        local b = bin:byte(pos); pos = pos + 1
        local major = math.floor(b / 32)
        local ai = b % 32
        if major == 0 then
            return ReadUint(ai)
        elseif major == 1 then
            return -1 - ReadUint(ai)
        elseif major == 3 then
            local slen = ReadUint(ai)
            if pos + slen - 1 > len then error("String EOF") end
            local s = bin:sub(pos, pos + slen - 1)
            pos = pos + slen
            return s
        elseif major == 4 then
            local n = ReadUint(ai)
            local t = {}
            for i = 1, n do t[i] = ReadItem() end
            return t
        elseif major == 5 then
            local n = ReadUint(ai)
            local t = {}
            for _ = 1, n do
                local k = ReadItem()
                local v = ReadItem()
                t[k] = v
            end
            return t
        elseif major == 7 then
            if ai == 20 then return false
            elseif ai == 21 then return true
            elseif ai == 22 then return nil
            elseif ai == 27 then
                if pos + 7 > len then error("Float EOF") end
                local b1, b2, b3, b4, b5, b6, b7, b8 = bin:byte(pos, pos + 7)
                pos = pos + 8
                local sign = (b1 >= 128) and -1 or 1
                local hi = (b1 % 128) * 16777216 + b2 * 65536 + b3 * 256 + b4
                local lo = b5 * 16777216 + b6 * 65536 + b7 * 256 + b8
                local exp = math.floor(hi / 1048576)
                local frac = (hi % 1048576) * 4294967296 + lo
                if exp == 0 and frac == 0 then return 0 end
                return sign * math.ldexp(1 + frac / (2 ^ 52), exp - 1023)
            end
        end
        error("Unsupported CBOR item")
    end
    local val = ReadItem()
    if pos ~= len + 1 then error("Trailing CBOR bytes") end
    return val
end

-- ============================================================================
-- Minimal WoW Midnight 12.1.5 / 12.1.7 Headless Environment
-- ============================================================================
local function CreateEnv(opts)
    opts = opts or {}
    local env = {}
    setmetatable(env, { __index = _G })
    env._G = env

    local state = {
        inCombat = false,
        hudClampCalls = 0,
        dlSlashCalls = 0,
        openedViews = {},
        openedStudioTabs = {},
        enabledAddons = {},
        disabledAddons = {},
        secretValues = {},
    }

    env.wipe = function(t) if type(t) == "table" then for k in pairs(t) do t[k] = nil end end; return t end
    env.tinsert = table.insert
    env.tremove = table.remove
    env.CopyTable = function(src)
        if type(src) ~= "table" then return src end
        local dst = {}
        for k, v in pairs(src) do
            dst[k] = (type(v) == "table") and env.CopyTable(v) or v
        end
        return dst
    end
    env.GetTime = function() return 100.0 end
    env.UnitName = function() return "Testchar" end
    env.UnitClass = function() return "Mage", "MAGE", 8 end
    env.GetRealmName = function() return "Frostmourne" end
    env.InCombatLockdown = function() return state.inCombat end
    env.IsShiftKeyDown = function() return false end
    env.PlaySound = function() end
    env.PlaySoundFile = function() end
    env.ReloadUI = function() end
    env.GetCursorPosition = function() return 500, 400 end
    env.UISpecialFrames = {}
    env.SlashCmdList = {}
    env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    env.SOUNDKIT = { UI_BNET_TOAST = 18019, IG_CHARACTER_INFO_TAB = 841 }
    env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    env.UNKNOWNOBJECT = "Unknown"
    env.Enum = { CompressionMethod = { Deflate = 0, Zlib = 1, Gzip = 2 } }
    env.C_EncodingUtil = {
        SerializeCBOR = CBOREncode,
        DeserializeCBOR = CBORDecode,
        CompressString = ZlibCompress,
        DecompressString = ZlibDecompress,
        EncodeBase64 = Base64Encode,
        DecodeBase64 = Base64Decode,
    }
    env.issecretvalue = function(v) return state.secretValues[v] == true end
    env.canaccessvalue = function(v) return state.secretValues[v] ~= true end
    env.C_Timer = {
        After = function(_, fn) if type(fn) == "function" then end end,
        NewTimer = function(_, fn) return { Cancel = function() end, fn = fn } end,
    }
    env.C_CVar = {
        GetCVar = function() return "1" end,
        SetCVar = function() end,
        GetCVarDefault = function() return "1" end,
    }
    env.C_AddOns = {
        GetAddOnMetadata = function() return "2.11.0" end,
        IsAddOnLoaded = function(name) return name == "DynamicSuite" end,
        GetAddOnInfo = function(name) return name, name, "", true, "INSECURE", false end,
        GetAddOnEnableState = function() return 2 end,
        EnableAddOn = function(name) state.enabledAddons[name] = true end,
        DisableAddOn = function(name) state.disabledAddons[name] = true end,
    }
    env.C_Map = { GetMapInfo = function() return { name = "Dornogal" } end }
    env.GetNumAddOns = function() return 0 end

    local function MakeMockFrame(ftype, name)
        local f = {
            _type = ftype,
            _name = name,
            _shown = false,
            _scripts = {},
            _points = {},
            _w = 100,
            _h = 30,
        }
        function f:SetScript(ev, fn) self._scripts[ev] = fn end
        function f:HookScript(ev, fn) self._scripts[ev] = fn end
        function f:GetScript(ev) return self._scripts[ev] end
        function f:RegisterEvent() end
        function f:UnregisterEvent() end
        function f:Show() self._shown = true end
        function f:Hide() self._shown = false end
        function f:SetShown(b) self._shown = (b == true) end
        function f:IsShown() return self._shown end
        function f:IsVisible() return self._shown end
        function f:Raise() end
        function f:SetPoint(...) table.insert(self._points, { ... }) end
        function f:GetPoint() return "CENTER", env.UIParent, "CENTER", 0, 0 end
        function f:ClearAllPoints() self._points = {} end
        function f:SetSize(w, h) self._w = w; self._h = h end
        function f:SetWidth(w) self._w = w end
        function f:SetHeight(h) self._h = h end
        function f:GetWidth() return self._w end
        function f:GetHeight() return self._h end
        function f:GetScale() return 1.0 end
        function f:GetEffectiveScale() return 1.0 end
        function f:SetScale() end
        function f:SetAlpha() end
        function f:SetFrameStrata() end
        function f:SetFrameLevel() end
        function f:GetFrameLevel() return 5 end
        function f:SetToplevel() end
        function f:SetClampedToScreen() end
        function f:SetClipsChildren() end
        function f:EnableMouse() end
        function f:EnableMouseWheel() end
        function f:EnableKeyboard() end
        function f:SetMovable() end
        function f:SetResizable() end
        function f:RegisterForDrag() end
        function f:RegisterForClicks() end
        function f:SetBackdrop() end
        function f:SetBackdropColor() end
        function f:SetBackdropBorderColor() end
        function f:GetChildren() return {} end
        function f:CreateTexture()
            local tex = { _color = {} }
            function tex:SetAllPoints() end
            function tex:SetPoint() end
            function tex:SetSize() end
            function tex:SetWidth() end
            function tex:SetHeight() end
            function tex:SetColorTexture(r, g, b, a) self._color = { r, g, b, a } end
            function tex:SetTexture() end
            function tex:SetVertexColor() end
            function tex:SetTexCoord() end
            function tex:SetRotation() end
            function tex:SetSnapToPixelGrid() end
            function tex:SetTexelSnappingBias() end
            function tex:Show() end
            function tex:Hide() end
            return tex
        end
        function f:CreateFontString()
            local fs = { _text = "" }
            function fs:SetPoint() end
            function fs:ClearAllPoints() end
            function fs:SetFont() end
            function fs:SetTextColor() end
            function fs:SetJustifyH() end
            function fs:SetWordWrap() end
            function fs:SetMaxLines() end
            function fs:SetText(t) self._text = tostring(t or "") end
            function fs:GetText() return self._text end
            function fs:GetStringWidth() return #self._text * 6 end
            function fs:GetStringHeight() return 14 end
            function fs:Show() end
            function fs:Hide() end
            return fs
        end
        if name then env[name] = f end
        return f
    end

    env.UIParent = MakeMockFrame("Frame", "UIParent")
    env.UIParent:SetSize(1920, 1080)
    env.GameTooltip = MakeMockFrame("GameTooltip", "GameTooltip")
    env.GameTooltip.SetOwner = function() end
    env.GameTooltip.AddLine = function() end
    env.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
    env.CreateFrame = function(ftype, name) return MakeMockFrame(ftype, name) end
    env.hooksecurefunc = function() end

    return env, state
end

local function LoadChunkIntoEnv(path, env, addonName, sharedTbl)
    local chunk, err = loadfile(path)
    assertTrue(chunk ~= nil, "Failed to load " .. path .. ": " .. tostring(err))
    setfenv(chunk, env)
    return chunk(addonName, sharedTbl)
end

local function BootFullSuiteEnv()
    local env, state = CreateEnv()
    local sharedTbl = {}
    LoadChunkIntoEnv(CORE_PATH, env, "DynamicSuite", sharedTbl)
    sharedTbl.ClampAllSuiteHudsToScreen = function()
        state.hudClampCalls = state.hudClampCalls + 1
    end
    sharedTbl.OpenWorkspaceView = function(vk, tabIdx)
        state.openedViews[#state.openedViews + 1] = { viewKey = vk, tab = tabIdx }
    end
    sharedTbl.OpenSuiteStudioTab = function(tabIdx)
        state.openedStudioTabs[#state.openedStudioTabs + 1] = tabIdx
    end
    sharedTbl.HandleDynamicLoadSlashCommand = function(msg)
        state.dlSlashCalls = state.dlSlashCalls + 1
        state.lastDlSlash = msg
    end
    LoadChunkIntoEnv(MARKER_PATH, env, "DynamicSuite", sharedTbl)
    return env, state, sharedTbl
end

local function BootStandaloneMarkerEnv()
    local env, state = CreateEnv()
    local sharedTbl = {}
    env.C_AddOns.IsAddOnLoaded = function(name) return name == "DynamicMarker" end
    env.C_AddOns.GetAddOnEnableState = function(name) return (name == "DynamicMarker") and 2 or 0 end
    LoadChunkIntoEnv(MARKER_PATH, env, "DynamicMarker", sharedTbl)
    env.DynamicMarker:InitDB()
    return env, state
end

local function PopulateAll14DBs(env)
    env.DynamicSuiteDB = {
        global = {
            accentKey = "ALERT_GOLD",
            surfaceTheme = "SLATE_STEEL",
            fontKey = "EXPRESSWAY_BOLD",
            fontFamily = "EXPRESSWAY_BOLD",
            pillFillAlpha = 0.32,
            toastScale = 1.25,
            toastPos = { point = "TOP", relPoint = "TOP", x = 42, y = -96 },
            desktopWindows = {
                masterEnabled = true, enabled = true, sideBySide = true,
                dragAnywhere = true, draggable = true, scrollScale = true,
                positions = { CharacterFrame = { point = "LEFT", relPoint = "LEFT", x = 80, y = 10 } },
                scales = { CharacterFrame = 1.15 },
                migratedFromPrep = true,
            },
            -- Stripped local keys:
            seenSpotlights = { s1 = true },
            seenNewBadges = { cursor = true },
            acknowledgedConflicts = { Baganator = true },
            guidedSetupDone = true,
            lastSeenChangelogVer = "2.11.0",
        },
    }
    env.DynamicMarkerDB = {
        focusIcon = 6,
        iconOrder = { 8, 7, 6, 5, 4, 3, 2, 1 },
        groupScope = "RAID",
        chatAnnounce = "MUTED",
        chatChannel = "SAY",
        targetBarVisibility = "ALWAYS",
        targetBarScale = 1.20,
        targetBarX = 110,
        targetBarY = -50,
        targetBarPos = { point = "CENTER", relPoint = "CENTER", x = 110, y = -50 },
        flareEnabled = { [1] = true, [2] = false, [3] = true, [4] = true, [5] = false, [6] = true, [7] = true, [8] = true },
        flareBarX = -90,
        flareBarY = -220,
        flareBarPos = { point = "CENTER", relPoint = "CENTER", x = -90, y = -220 },
        migratedFromFocusMarker = true,
        dismissedAdvisoryConflicts = { ExRT = true },
    }
    env.DynamicGroupDB = {
        minLeaderScore = 2500,
        whisperKeywords = "invme, keypls",
        autoAcceptRoleCheck = true,
        lastSearchText = "secret local search",
        persistentNote = "my private note",
    }
    env.DynamicPrepDB = {
        displayMode = "OOC",
        barScale = 1.15,
        barPoint = "TOP",
        barRelativePoint = "TOP",
        barX = 25,
        barY = -30,
        raidBuffs = { enabled = true, iconSize = 48, point = "CENTER", relPoint = "CENTER", x = 12, y = 200 },
        errorFilterSavedSpeechCVar = "0",
        activeFolioStat = "CRIT",
    }
    env.DynamicTalentDB = {
        talentBackdropBase = "BLIZZARD",
        talentBackdropDimmer = 50,
        talentStringLibrary = { { id = "dt_1_100", name = "M+ AoE", group = "M+", importString = "C4QAA..." } },
        talentBossMap = { [2902] = { loadoutID = "dt_1_100", loadoutName = "M+ AoE" } },
        lastAppliedTalentID = { [62] = "dt_1_100" },
        dismissedTalentQuickStart = true,
    }
    env.DynamicCursorDB = {
        ringEnabled = true,
        ringRadius = 36,
        crosshairEnabled = true,
        trailEnabled = true,
        crosshairElementsMigrated = true,
    }
    env.DynamicVaultDB = {
        minLevelFilter = 85,
        sortMode = "RATING",
        customTasks = {
            { id = "t1", title = "Weekly Sparks", scope = "ACCT", doneAcct = true, doneChars = { ["Testchar-Frostmourne"] = true }, resetEpoch = 999999 },
        },
        characters = { ["Alt-Frostmourne"] = { gold = 500000 } },
        favourites = { ["Alt-Frostmourne"] = true },
        bountifulDelves = { cached = true },
    }
    env.DynamicDialogueDB = {
        frameScale = 1.15,
        fontSize = 15,
        pos = { point = "CENTER", relPoint = "CENTER", x = 15, y = -120 },
        autoYield = false,
    }
    env.DynamicBagsDB = {
        replaceBlizzardBags = false,
        bagColumns = 12,
        autoRestockEnabled = true,
        autoRestockList = { [212241] = 20 },
        windowPos = { "BOTTOMRIGHT", "BOTTOMRIGHT", -120, 140 },
        vault = { warbandGold = 123456789, characters = { ["Alt-Frostmourne"] = { gold = 999 } } },
        collapsedSections = { junk = true },
    }
    env.DynamicMailDB = {
        keepFreeBagSlots = 3,
        openInterval = 0.25,
        lastRecipient = "Friend-Frostmourne",
        favourites = { ["MyAlt-Frostmourne"] = true },
        historyLog = { { item = "Ore", ts = 1234 } },
        stats = { totalCopperLooted = 999999 },
    }
    env.DynamicChatDB = {
        enableSleekChatSkin = false,
        chatFontSize = 14,
        mentionKeywords = "dentee, lust",
        chatFramePos = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 14, y = 22, width = 460, height = 230 },
        savedChatHistory = { ChatFrame1 = { "hello world secret chat" } },
        customSounds = { CustomPing = "Interface\\AddOns\\Custom\\ping.ogg" },
    }
    env.DynamicLoadDB = {
        autoSwitch = false,
        silentOnMatch = false,
        profiles = {
            OUTDOOR = { name = "Outdoor", addons = { Details = true, DynamicMarker = true } },
            RAID = { name = "Raid", addons = { BigWigs = true } },
        },
        lockedAddons = { WeakAuras = true },
        frozenAddons = { HandyNotes = true },
        characters = { ["Alt-Frostmourne"] = { name = "Alt" } },
        knownAddons = { Details = true },
        stash = { saved = true },
    }
    env.DynamicFPSDB = {
        targetFPSFloor = 120,
        spellQueueManualMS = 220,
        savedBaselineCVars = { shadowQuality = "3" },
        conflictResolutions = { LoggerHead = "YIELD" },
    }
    env.DynamicZoomDB = {
        maxZoomYards = 35,
        zoomOutdoor = 30,
        pitchTiltPct = 15,
        schemaVersion = 122,
    }
end

local tests = {}

function tests.T01_Full14SectionRoundTrip()
    local envA = BootFullSuiteEnv()
    PopulateAll14DBs(envA)

    local okExp, expRes = envA.DynamicSuite.ExportProfile({
        includeHud = true,
        includeTalents = true,
        includeLoadLists = true,
    })
    assertTrue(okExp, "Export failed: " .. tostring(expRes))
    assertEqual(expRes.encoded:sub(1, 5), "!DS1!", "Must start with !DS1! prefix")
    assertEqual(expRes.moduleCount, 14, "Must export all 14 sections (suite + 13 modules)")

    local envB, stateB = BootFullSuiteEnv()
    local okDec, preview = envB.DynamicSuite.DecodeProfile(expRes.encoded)
    assertTrue(okDec, "Decode failed: " .. tostring(preview))
    assertEqual(#preview.moduleKeys, 14, "Preview must list all 14 sections")
    assertEqual(preview.modules.marker.flareEnabled[2], false, "Sparse integer key [2]=false must survive CBOR")
    assertEqual(preview.modules.talent.talentBossMap[2902].loadoutID, "dt_1_100", "Boss integer ID 2902 must survive CBOR")

    local okApp, appRes = envB.DynamicSuite.ApplyProfileImport(preview, { mode = "REPLACE", includeHud = true })
    assertTrue(okApp, "Apply failed: " .. tostring(appRes))
    assertEqual(appRes.appliedCount, 14, "Must apply all 14 sections")
    assertEqual(envB.DynamicSuiteDB.global.accentKey, "ALERT_GOLD", "Suite accentKey imported")
    assertEqual(envB.DynamicMarkerDB.focusIcon, 6, "Marker focusIcon imported")
    assertEqual(envB.DynamicMarkerDB.flareEnabled[2], false, "Marker flareEnabled[2] imported")
    assertEqual(envB.DynamicGroupDB.minLeaderScore, 2500, "Group score imported")
    assertEqual(envB.DynamicPrepDB.barX, 25, "Prep barX imported")
    assertEqual(envB.DynamicTalentDB.talentBossMap[2902].loadoutName, "M+ AoE", "Talent boss map imported")
    assertEqual(envB.DynamicCursorDB.ringRadius, 36, "Cursor radius imported")
    assertEqual(envB.DynamicVaultDB.minLevelFilter, 85, "Vault minLevelFilter imported")
    assertEqual(envB.DynamicDialogueDB.fontSize, 15, "Dialogue fontSize imported")
    assertEqual(envB.DynamicBagsDB.bagColumns, 12, "Bags columns imported")
    assertEqual(envB.DynamicMailDB.keepFreeBagSlots, 3, "Mail free bag slots imported")
    assertEqual(envB.DynamicChatDB.mentionKeywords, "dentee, lust", "Chat mentionKeywords imported")
    assertEqual(envB.DynamicLoadDB.lockedAddons.WeakAuras, true, "Load lockedAddons imported")
    assertEqual(envB.DynamicFPSDB.targetFPSFloor, 120, "FPS targetFPSFloor imported")
    assertEqual(envB.DynamicZoomDB.maxZoomYards, 35, "Zoom maxZoomYards imported")
    assertTrue(stateB.hudClampCalls >= 1, "ClampAllSuiteHudsToScreen must run when HUD positions applied")
    assertEqual(envB.DynamicLoadDB.profiles.OUTDOOR.addons.DynamicMarker, false, "Standalone DynamicMarker scrubbed to false in imported DynamicLoadDB")
    assertEqual(envB.DynamicLoadDB.lockedAddons.DynamicSuite, true, "EnforceProtectedSuiteModules protects DynamicSuite")
end

function tests.T02_StrictDataHygieneExportAndReplace()
    local envA = BootFullSuiteEnv()
    PopulateAll14DBs(envA)
    local okExp, expRes = envA.DynamicSuite.ExportProfile({
        includeHud = true, includeTalents = true, includeLoadLists = true,
    })
    assertTrue(okExp, "Export failed")

    local envB = BootFullSuiteEnv()
    local okDec, preview = envB.DynamicSuite.DecodeProfile(expRes.encoded)
    assertTrue(okDec, "Decode failed")

    -- Verify stripped keys are absent from decoded payload
    assertEqual(preview.modules.suite.seenSpotlights, nil, "seenSpotlights stripped")
    assertEqual(preview.modules.suite.acknowledgedConflicts, nil, "acknowledgedConflicts stripped")
    assertEqual(preview.modules.bags.vault, nil, "DynamicBags.vault stripped")
    assertEqual(preview.modules.vault.characters, nil, "DynamicVault.characters stripped")
    assertEqual(preview.modules.vault.favourites, nil, "DynamicVault.favourites stripped")
    assertEqual(preview.modules.vault.bountifulDelves, nil, "DynamicVault.bountifulDelves stripped")
    assertEqual(preview.modules.vault.customTasks[1].doneAcct, false, "Vault customTasks doneAcct forced false")
    assertEqual(next(preview.modules.vault.customTasks[1].doneChars), nil, "Vault customTasks doneChars emptied")
    assertEqual(preview.modules.vault.customTasks[1].resetEpoch, 0, "Vault customTasks resetEpoch zeroed")
    assertEqual(preview.modules.chat.savedChatHistory, nil, "DynamicChat.savedChatHistory stripped")
    assertEqual(preview.modules.chat.customSounds, nil, "DynamicChat.customSounds stripped")
    assertEqual(preview.modules.mail.historyLog, nil, "DynamicMail.historyLog stripped")
    assertEqual(preview.modules.mail.favourites, nil, "DynamicMail.favourites stripped")
    assertEqual(preview.modules.mail.stats, nil, "DynamicMail.stats stripped")
    assertEqual(preview.modules.fps.savedBaselineCVars, nil, "DynamicFPS.savedBaselineCVars stripped")
    assertEqual(preview.modules.prep.errorFilterSavedSpeechCVar, nil, "DynamicPrep.errorFilterSavedSpeechCVar stripped")
    assertEqual(preview.modules.load.characters, nil, "DynamicLoad.characters stripped")
    assertEqual(preview.modules.load.knownAddons, nil, "DynamicLoad.knownAddons stripped")
    assertEqual(preview.modules.load.stash, nil, "DynamicLoad.stash stripped")
    assertEqual(preview.modules.talent.lastAppliedTalentID, nil, "DynamicTalent.lastAppliedTalentID stripped")
    assertEqual(preview.modules.marker.migratedFromFocusMarker, nil, "DynamicMarker.migratedFromFocusMarker stripped")

    -- Populate target B with existing local caches, then run REPLACE import and ensure caches survive 100%
    envB.DynamicSuiteDB = { global = { seenSpotlights = { localSpot = true }, acknowledgedConflicts = { ElvUI = true } } }
    envB.DynamicBagsDB = { vault = { warbandGold = 777777 } }
    envB.DynamicVaultDB = { characters = { ["Main-Frostmourne"] = { ilvl = 639 } }, favourites = { ["Main-Frostmourne"] = true } }
    envB.DynamicChatDB = { savedChatHistory = { ChatFrame1 = { "keep my chat" } } }
    envB.DynamicMailDB = { favourites = { ["KeepAlt"] = true }, stats = { totalCopperLooted = 555 } }
    envB.DynamicFPSDB = { savedBaselineCVars = { shadowQuality = "1" } }
    envB.DynamicLoadDB = { characters = { ["KeepChar"] = true }, knownAddons = { MyAddon = true }, stash = { foo = 1 } }

    local okApp = envB.DynamicSuite.ApplyProfileImport(preview, { mode = "REPLACE", includeHud = true })
    assertTrue(okApp, "Replace apply failed")
    assertEqual(envB.DynamicSuiteDB.global.seenSpotlights.localSpot, true, "Target seenSpotlights preserved")
    assertEqual(envB.DynamicBagsDB.vault.warbandGold, 777777, "Target DynamicBags.vault preserved")
    assertEqual(envB.DynamicVaultDB.characters["Main-Frostmourne"].ilvl, 639, "Target DynamicVault.characters preserved")
    assertEqual(envB.DynamicChatDB.savedChatHistory.ChatFrame1[1], "keep my chat", "Target savedChatHistory preserved")
    assertEqual(envB.DynamicMailDB.stats.totalCopperLooted, 555, "Target DynamicMail.stats preserved")
    assertEqual(envB.DynamicFPSDB.savedBaselineCVars.shadowQuality, "1", "Target savedBaselineCVars preserved")
    assertEqual(envB.DynamicLoadDB.stash.foo, 1, "Target DynamicLoad.stash preserved")
end

function tests.T03_OptOutHudAndOptInTalentsLoadLists()
    local envA = BootFullSuiteEnv()
    PopulateAll14DBs(envA)

    -- Default-style export: hud = false, talents = false, loadLists = false
    local okExp, expRes = envA.DynamicSuite.ExportProfile({
        includeHud = false,
        includeTalents = false,
        includeLoadLists = false,
    })
    assertTrue(okExp, "Export failed")

    local envB, stateB = BootFullSuiteEnv()
    envB.DynamicSuiteDB = { global = { toastPos = { point = "BOTTOM", relPoint = "BOTTOM", x = 5, y = 50 }, desktopWindows = { positions = { PVEFrame = { x = 10, y = 20 } } } } }
    envB.DynamicMarkerDB = { targetBarX = 333, targetBarY = 222, targetBarPos = { point = "CENTER", relPoint = "CENTER", x = 333, y = 222 } }
    envB.DynamicPrepDB = { barX = 99, barY = -99, raidBuffs = { point = "CENTER", relPoint = "CENTER", x = 77, y = 88 } }
    envB.DynamicTalentDB = { talentStringLibrary = { { id = "keep_1", name = "My Local Build" } } }
    envB.DynamicLoadDB = { profiles = { OUTDOOR = { name = "Outdoor", addons = { MyLocalAddon = true } } } }

    local okDec, preview = envB.DynamicSuite.DecodeProfile(expRes.encoded)
    assertTrue(okDec, "Decode failed")
    assertEqual(preview.modules.suite.toastPos, nil, "toastPos omitted when includeHud=false")
    assertEqual(preview.modules.suite.desktopWindows.positions, nil, "desktopWindows.positions omitted when includeHud=false")
    assertEqual(preview.modules.marker.targetBarPos, nil, "targetBarPos omitted when includeHud=false")
    assertEqual(preview.modules.prep.barX, nil, "prep.barX omitted when includeHud=false")
    assertEqual(preview.modules.prep.raidBuffs.x, nil, "prep.raidBuffs.x omitted when includeHud=false")
    assertEqual(preview.modules.talent.talentStringLibrary, nil, "talentStringLibrary omitted when includeTalents=false")
    assertEqual(preview.modules.load.profiles, nil, "load.profiles omitted when includeLoadLists=false")

    local okApp, appRes = envB.DynamicSuite.ApplyProfileImport(preview, { mode = "REPLACE", includeHud = false })
    assertTrue(okApp, "Apply failed")
    assertEqual(appRes.appliedHud, false, "appliedHud must be false")
    assertEqual(stateB.hudClampCalls, 0, "ClampAllSuiteHudsToScreen skipped when no HUD positions applied")
    assertEqual(envB.DynamicMarkerDB.targetBarX, 333, "Local targetBarX preserved when includeHud=false")
    assertEqual(envB.DynamicSuiteDB.global.toastPos.y, 50, "Local toastPos preserved when includeHud=false")
    assertEqual(envB.DynamicPrepDB.raidBuffs.x, 77, "Local raidBuffs.x preserved when includeHud=false")
    assertEqual(envB.DynamicTalentDB.talentStringLibrary[1].name, "My Local Build", "Local talent library preserved")
    assertEqual(envB.DynamicLoadDB.profiles.OUTDOOR.addons.MyLocalAddon, true, "Local DynamicLoad profile preserved")
end

function tests.T04_ReplaceVsMergeAndPersistentRollback()
    local envA = BootFullSuiteEnv()
    PopulateAll14DBs(envA)
    local okExp, expRes = envA.DynamicSuite.ExportProfile({
        modules = { "marker", "talent" },
        includeHud = true,
        includeTalents = true,
    })
    assertTrue(okExp, "Export failed")

    local envB = BootFullSuiteEnv()
    envB.DynamicMarkerDB = { focusIcon = 2, chatChannel = "PARTY", targetBarX = -55 }
    envB.DynamicTalentDB = {
        talentBackdropDimmer = 10,
        talentBossMap = { [9999] = { loadoutID = "local_keep", loadoutName = "Keep Me" } },
    }

    -- 1. MERGE keeps untouched custom boss bind 9999
    local okMerge = envB.DynamicSuite.ApplyProfileImport(expRes.encoded, { mode = "MERGE", includeHud = true })
    assertTrue(okMerge, "Merge apply failed")
    assertEqual(envB.DynamicMarkerDB.focusIcon, 6, "Merge updated focusIcon")
    assertEqual(envB.DynamicTalentDB.talentBossMap[2902].loadoutID, "dt_1_100", "Merge added imported boss 2902")
    assertEqual(envB.DynamicTalentDB.talentBossMap[9999].loadoutID, "local_keep", "Merge kept local boss 9999")

    -- Simulate /reload: fresh boot with saved _G tables carried over!
    local savedSuiteDB = envB.CopyTable(envB.DynamicSuiteDB)
    local savedMarkerDB = envB.CopyTable(envB.DynamicMarkerDB)
    local savedTalentDB = envB.CopyTable(envB.DynamicTalentDB)

    local envReloaded = BootFullSuiteEnv()
    envReloaded.DynamicSuiteDB = savedSuiteDB
    envReloaded.DynamicMarkerDB = savedMarkerDB
    envReloaded.DynamicTalentDB = savedTalentDB

    local bkInfo = envReloaded.DynamicSuite.GetLastImportBackupInfo()
    assertTrue(bkInfo ~= nil, "Backup must persist across /reload")
    assertEqual(bkInfo.moduleCount, 2, "Backup should cover 2 imported sections")

    local okRb, rbRes = envReloaded.DynamicSuite.RollbackLastImport()
    assertTrue(okRb, "Rollback failed: " .. tostring(rbRes))
    assertEqual(envReloaded.DynamicMarkerDB.focusIcon, 2, "Rollback restored focusIcon=2")
    assertEqual(envReloaded.DynamicMarkerDB.targetBarX, -55, "Rollback restored targetBarX=-55")
    assertEqual(envReloaded.DynamicTalentDB.talentBackdropDimmer, 10, "Rollback restored dimmer=10")
    assertEqual(envReloaded.DynamicTalentDB.talentBossMap[2902], nil, "Rollback removed imported boss 2902")
    assertEqual(envReloaded.DynamicTalentDB.talentBossMap[9999].loadoutID, "local_keep", "Rollback preserved original boss 9999")
    assertEqual(envReloaded.DynamicSuite.GetLastImportBackupInfo(), nil, "Backup cleared after rollback")
end

function tests.T05_CrossModeSuiteAndStandaloneDynamicMarker()
    -- A) Standalone DynamicMarker -> Full DynamicSuite
    local dmEnv = BootStandaloneMarkerEnv()
    dmEnv.DynamicMarkerDB.focusIcon = 4
    dmEnv.DynamicMarkerDB.flareCycleKey = "F6"
    dmEnv.DynamicMarkerDB.targetBarX = 88
    dmEnv.DynamicMarker.suiteGlobal.theme = "GOLD"
    dmEnv.DynamicMarker.suiteGlobal.surfaceTheme = "OBSIDIAN_DARK"

    local okDmExp, dmExp = dmEnv.DynamicMarker:ExportProfile({ includeHud = true, includeTheme = true })
    assertTrue(okDmExp, "Standalone DynamicMarker export failed: " .. tostring(dmExp))

    local suiteEnv = BootFullSuiteEnv()
    local okSuiteDec, suitePrev = suiteEnv.DynamicSuite.DecodeProfile(dmExp.encoded)
    assertTrue(okSuiteDec, "Suite decode of standalone DynamicMarker string failed")
    assertEqual(suitePrev.app, "DynamicMarker", "App source identified as DynamicMarker")
    local okSuiteApp = suiteEnv.DynamicSuite.ApplyProfileImport(suitePrev, { mode = "REPLACE", includeHud = true })
    assertTrue(okSuiteApp, "Suite apply of standalone DynamicMarker failed")
    assertEqual(suiteEnv.DynamicMarkerDB.focusIcon, 4, "Suite received Marker focusIcon=4")
    assertEqual(suiteEnv.DynamicMarkerDB.flareCycleKey, "F6", "Suite received Marker flareCycleKey=F6")
    assertEqual(suiteEnv.DynamicSuiteDB.global.accentKey, "ALERT_GOLD", "Suite received mapped accentKey")

    -- B) Full DynamicSuite (14 sections) -> Standalone DynamicMarker
    local fullEnv = BootFullSuiteEnv()
    PopulateAll14DBs(fullEnv)
    local okFullExp, fullExp = fullEnv.DynamicSuite.ExportProfile({
        includeHud = true, includeTalents = true, includeLoadLists = true,
    })
    assertTrue(okFullExp, "Full suite export failed")

    local dmTarget = BootStandaloneMarkerEnv()
    dmTarget.DynamicMarkerDB.migratedFromFocusMarker = true
    dmTarget.DynamicMarkerDB.dismissedAdvisoryConflicts = { HandyNotes = true }
    local okDmDec, dmPrev = dmTarget.DynamicMarker:DecodeProfile(fullExp.encoded)
    assertTrue(okDmDec, "Standalone decode of full suite failed: " .. tostring(dmPrev))
    assertEqual(dmPrev.ignoredCount, 12, "Standalone decode reports 12 non-marker/non-suite modules skipped")

    local okDmApp, dmAppRes = dmTarget.DynamicMarker:ApplyProfileImport(dmPrev, { mode = "REPLACE", includeHud = true, applyTheme = true })
    assertTrue(okDmApp, "Standalone apply failed")
    assertEqual(dmAppRes.needsReload, false, "Standalone DynamicMarker never requires reload")
    assertEqual(dmTarget.DynamicMarkerDB.focusIcon, 6, "Standalone received focusIcon=6")
    assertEqual(dmTarget.DynamicMarkerDB.flareEnabled[2], false, "Standalone received flareEnabled[2]=false")
    assertEqual(dmTarget.DynamicMarkerDB.migratedFromFocusMarker, true, "Standalone preserved migration flag")
    assertEqual(dmTarget.DynamicMarkerDB.dismissedAdvisoryConflicts.HandyNotes, true, "Standalone preserved dismissed conflicts")

    local okDmRb = dmTarget.DynamicMarker:RollbackLastImport()
    assertTrue(okDmRb, "Standalone rollback failed")
    assertEqual(dmTarget.DynamicMarkerDB.focusIcon, 8, "Standalone rollback restored default focusIcon=8")
end

function tests.T06_CombatLockdownAndHostileMalformedInputs()
    local env, state = BootFullSuiteEnv()
    PopulateAll14DBs(env)
    local okExp, expRes = env.DynamicSuite.ExportProfile({ includeHud = true })
    assertTrue(okExp, "Export must succeed")

    -- Combat blocks import & rollback, but allows export
    state.inCombat = true
    local okExpCombat = env.DynamicSuite.ExportProfile({ includeHud = true })
    assertTrue(okExpCombat, "Export works in combat")
    local okImpCombat, errImpCombat = env.DynamicSuite.ApplyProfileImport(expRes.encoded)
    assertEqual(okImpCombat, false, "Import blocked in combat")
    assertTrue(tostring(errImpCombat):find("combat") ~= nil, "Combat error mentions combat")
    env.DynamicSuiteDB.global._lastImportBackup = { date = "25/11/2026", modules = { marker = { focusIcon = 1 } } }
    local okRbCombat = env.DynamicSuite.RollbackLastImport()
    assertEqual(okRbCombat, false, "Rollback blocked in combat")
    state.inCombat = false

    -- Malformed / hostile / future / secret strings
    local badInputs = {
        "",
        "   ",
        "NOT_A_PROFILE",
        "!DS1!",
        "!DS1!***INVALID_BASE64***",
        "!DS1!" .. Base64Encode("not-zlib-bytes-at-all"),
        "!DS1!" .. Base64Encode(ZlibCompress("not-cbor-bytes")),
        "!DS2!" .. expRes.encoded:sub(6),
        string.rep("A", 262145),
    }
    for idx, bad in ipairs(badInputs) do
        local okBad, errBad = env.DynamicSuite.DecodeProfile(bad)
        assertEqual(okBad, false, "Bad input #" .. idx .. " must fail cleanly")
        assertTrue(type(errBad) == "string" and #errBad > 0, "Bad input #" .. idx .. " must return message")
    end

    -- Future schema version inside valid CBOR
    local futureBlob = "!DS1!" .. Base64Encode(ZlibCompress(CBOREncode({ v = 99, modules = { marker = { focusIcon = 1 } } })))
    local okFut, errFut = env.DynamicSuite.DecodeProfile(futureBlob)
    assertEqual(okFut, false, "Future v=99 must be rejected")
    assertTrue(tostring(errFut):find("newer version") ~= nil, "Future error instructs user to update")

    -- Secret value string (Midnight 12.1.7)
    local secStr = expRes.encoded
    state.secretValues[secStr] = true
    local okSec = env.DynamicSuite.DecodeProfile(secStr)
    assertEqual(okSec, false, "Secret string must be rejected safely")
    state.secretValues[secStr] = nil
end

function tests.T07_SmartReloadDetectionAndSlashRouting()
    local envA = BootFullSuiteEnv()
    PopulateAll14DBs(envA)

    -- Live-only modules: needsReload == false
    local okLiveExp, liveExp = envA.DynamicSuite.ExportProfile({
        modules = { "marker", "cursor", "zoom", "dialogue", "vault", "mail", "group", "fps", "prep", "talent" },
        includeHud = true,
    })
    assertTrue(okLiveExp, "Live-only export failed")
    local envB = BootFullSuiteEnv()
    local okLiveApp, liveRes = envB.DynamicSuite.ApplyProfileImport(liveExp.encoded)
    assertTrue(okLiveApp, "Live-only apply failed")
    assertEqual(liveRes.needsReload, false, "Live-only modules must NOT prompt reload")

    -- Reload-sensitive module changed: needsReload == true
    local okChatExp, chatExp = envA.DynamicSuite.ExportProfile({ modules = { "chat" } })
    assertTrue(okChatExp, "Chat export failed")
    local envC = BootFullSuiteEnv()
    envC.DynamicChatDB = { enableSleekChatSkin = true, hideChatButtons = true, showTimestamps = true }
    local okChatApp, chatRes = envC.DynamicSuite.ApplyProfileImport(chatExp.encoded)
    assertTrue(okChatApp, "Chat apply failed")
    assertEqual(chatRes.needsReload, true, "Changing DynamicChat.enableSleekChatSkin must prompt reload")
    assertTrue(#chatRes.reloadReasons >= 1, "Reload reasons populated")

    -- Re-importing identical chat settings: needsReload == false
    local okChatSame, chatSameRes = envC.DynamicSuite.ApplyProfileImport(chatExp.encoded)
    assertTrue(okChatSame, "Second chat apply failed")
    assertEqual(chatSameRes.needsReload, false, "Re-importing identical reloadKeys must NOT prompt reload")

    -- Slash routing: /ds export, /ds import, /ds profiles -> Tab 3; /ds profile -> DynamicLoad
    local envS, stateS = BootFullSuiteEnv()
    envS.SlashCmdList["DYNAMICSUITE"]("export")
    envS.SlashCmdList["DYNAMICSUITE"]("import")
    envS.SlashCmdList["DYNAMICSUITE"]("profiles")
    assertEqual(#stateS.openedStudioTabs, 3, "/ds export, import, profiles all open Suite Studio Tab 3")
    assertEqual(stateS.openedStudioTabs[1], 3, "export opens Tab 3")
    assertEqual(stateS.openedStudioTabs[2], 3, "import opens Tab 3")
    assertEqual(stateS.openedStudioTabs[3], 3, "profiles opens Tab 3")
    assertEqual(stateS.dlSlashCalls, 0, "export/import/profiles do not route to DynamicLoad")

    envS.SlashCmdList["DYNAMICSUITE"]("profile Raid")
    assertEqual(stateS.dlSlashCalls, 1, "/ds profile still routes to DynamicLoad")
    assertEqual(stateS.lastDlSlash, "profile Raid", "/ds profile passes args to DynamicLoad")
end

local orderedNames = {
    "T01_Full14SectionRoundTrip",
    "T02_StrictDataHygieneExportAndReplace",
    "T03_OptOutHudAndOptInTalentsLoadLists",
    "T04_ReplaceVsMergeAndPersistentRollback",
    "T05_CrossModeSuiteAndStandaloneDynamicMarker",
    "T06_CombatLockdownAndHostileMalformedInputs",
    "T07_SmartReloadDetectionAndSlashRouting",
}

for _, name in ipairs(orderedNames) do
    local ok, err = pcall(tests[name])
    if ok then
        passed = passed + 1
        print(string.format("[PASS] %s", name))
    else
        failed = failed + 1
        print(string.format("[FAIL] %s: %s", name, tostring(err)))
    end
end

print(string.format("\nSummary: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
