-- ============================================================================
-- DynamicTalent v2.11.2 (/dt, /dynamictalent)
-- Talent Loadouts, Zone/Boss/M+/PvP Binds & Swap Alerts
-- World of Warcraft Retail (12.1.5 / 12.1.7, Interface 120105, 120107)
-- Pure ASCII Only (NonASCII: 0, HasBOM: False) | Zero-Taint Midnight Engine
-- ============================================================================

local addonName = ...
local ADDON_FOLDER = (type(addonName) == "string" and addonName ~= "") and addonName or "DynamicSuite"

local function ResolveAddonVersion(folderName, fallback)
    local fb = fallback or "2.11.2"
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    if type(getMeta) == "function" then
        local ok, ver = pcall(getMeta, folderName or ADDON_FOLDER, "Version")
        if ok and type(ver) == "string" and ver ~= "" and not ver:find("@") then
            return ver:gsub("^[vV]", "")
        end
        if folderName ~= "DynamicSuite" then
            local ok2, ver2 = pcall(getMeta, "DynamicSuite", "Version")
            if ok2 and type(ver2) == "string" and ver2 ~= "" and not ver2:find("@") then
                return ver2:gsub("^[vV]", "")
            end
        end
    end
    return fb
end

local function CompareSemVer(vA, vB)
    local a1, a2, a3 = tostring(vA or "0.0.0"):gsub("^[vV]", ""):match("^(%d+)%.?(%d*)%.?(%d*)")
    local b1, b2, b3 = tostring(vB or "0.0.0"):gsub("^[vV]", ""):match("^(%d+)%.?(%d*)%.?(%d*)")
    local nA1, nA2, nA3 = tonumber(a1) or 0, tonumber(a2) or 0, tonumber(a3) or 0
    local nB1, nB2, nB3 = tonumber(b1) or 0, tonumber(b2) or 0, tonumber(b3) or 0
    if nA1 ~= nB1 then return (nA1 > nB1) and 1 or -1 end
    if nA2 ~= nB2 then return (nA2 > nB2) and 1 or -1 end
    if nA3 ~= nB3 then return (nA3 > nB3) and 1 or -1 end
    return 0
end

local function _IsSecret(v)
    if type(issecretvalue) == "function" and issecretvalue(v) then
        return true
    end
    if type(canaccessvalue) == "function" and not canaccessvalue(v) then
        return true
    end
    return false
end

local function ShouldYieldToOtherInstall(addonFolder, standaloneName, thisVersion, globalTbl)
    local isAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
    local getAddOnEnableState = (C_AddOns and C_AddOns.GetAddOnEnableState) or _G.GetAddOnEnableState
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    local function isOtherEnabled(name)
        if type(isAddOnLoaded) == "function" then
            local okL, loaded = pcall(isAddOnLoaded, name)
            if okL and not _IsSecret(loaded) and loaded then
                return true
            end
        end
        if type(getAddOnEnableState) == "function" then
            local pName = nil
            if type(_G.UnitName) == "function" then
                local okU, uName = pcall(_G.UnitName, "player")
                if okU and not _IsSecret(uName) and type(uName) == "string" then
                    pName = uName
                end
            end
            if pName and pName ~= "" and pName ~= "Unknown" and pName ~= _G.UNKNOWNOBJECT then
                local ok, st = pcall(getAddOnEnableState, name, pName)
                if ok and not _IsSecret(st) and type(st) == "number" and st > 0 then return true end
            end
            local ok2, st2 = pcall(getAddOnEnableState, name)
            if ok2 and not _IsSecret(st2) and type(st2) == "number" and st2 > 0 then return true end
        end
        return false
    end
    if addonFolder ~= "DynamicSuite" then
        if type(globalTbl) == "table" and globalTbl._loadedBySuite then
            local suiteVer = globalTbl._loadedVersion or globalTbl.VERSION or globalTbl.version or (_G.DynamicSuite and _G.DynamicSuite.version) or "2.11.2"
            if CompareSemVer(thisVersion, suiteVer) <= 0 then
                return true
            end
        end
        if isOtherEnabled("DynamicSuite") and type(getMeta) == "function" then
            local okS, sVer = pcall(getMeta, "DynamicSuite", "Version")
            if okS and not _IsSecret(sVer) and type(sVer) == "string" and sVer ~= "" and not sVer:find("@") then
                if CompareSemVer(thisVersion, sVer) <= 0 then
                    return true
                end
            end
        end
    else
        if type(globalTbl) == "table" and globalTbl._loadedBySuite == false then
            local stLoadedVer = globalTbl._loadedVersion or globalTbl.VERSION or globalTbl.version or "0.0.0"
            if CompareSemVer(stLoadedVer, thisVersion) >= 0 then
                return true
            end
        end
        if isOtherEnabled(standaloneName) and type(getMeta) == "function" then
            local okV, stVer = pcall(getMeta, standaloneName, "Version")
            if okV and not _IsSecret(stVer) and type(stVer) == "string" and stVer ~= "" and not stVer:find("@") then
                if CompareSemVer(stVer, thisVersion) > 0 then
                    return true
                end
            end
        end
    end
    return false
end

local VERSION = ResolveAddonVersion(ADDON_FOLDER, "2.11.2")
if ShouldYieldToOtherInstall(ADDON_FOLDER, "DynamicTalent", VERSION, _G.DynamicTalent) then
    return
end

local DynamicTalent = _G.DynamicTalent or {}
_G.DynamicTalent = DynamicTalent
DynamicTalent.VERSION        = VERSION
DynamicTalent.version        = VERSION
DynamicTalent.addonName      = "DynamicTalent"
DynamicTalent._loadedBySuite = (ADDON_FOLDER == "DynamicSuite")
DynamicTalent._loadedVersion = VERSION

local function IsModuleDisabledInSuite(moduleName)
    local key = moduleName or "DynamicTalent"
    local shortK = key:gsub("^Dynamic", ""):lower()
    local dsDB = _G.DynamicSuiteDB
    if type(dsDB) == "table" then
        if type(dsDB.disabledModules) == "table" and (dsDB.disabledModules[key] == true or dsDB.disabledModules[shortK] == true or dsDB.disabledModules["talent"] == true or dsDB.disabledModules["DynamicTalent"] == true) then
            return true
        end
        if type(dsDB.global) == "table" and type(dsDB.global.disabledModules) == "table" and (dsDB.global.disabledModules[key] == true or dsDB.global.disabledModules[shortK] == true or dsDB.global.disabledModules["talent"] == true or dsDB.global.disabledModules["DynamicTalent"] == true) then
            return true
        end
    end
    return false
end

local MEDIA_BASE        = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\"
local ICON_COLOR        = MEDIA_BASE .. "Icons\\icon_mod_talent.tga"
local ICON_WHITE        = ICON_COLOR
local ICON_ACCENT       = ICON_COLOR
local ICON_CHEVRON_DOWN = MEDIA_BASE .. "Icons\\icon_chevron_down.tga"
local ICON_CHEVRON_UP   = MEDIA_BASE .. "Icons\\icon_chevron_up.tga"
local TEX_TALENT_MIST   = MEDIA_BASE .. "Textures\\talent_mist_cloud.tga"

-- ============================================================================
-- 1. SAFE RETAIL 12.1.5 HELPERS, THEME & UI PRIMITIVES
-- ============================================================================
local function IsPlayerInCombat()
    if type(InCombatLockdown) == "function" and InCombatLockdown() then return true end
    if type(UnitAffectingCombat) == "function" then
        local ok, ac = pcall(UnitAffectingCombat, "player")
        if ok and not _IsSecret(ac) and ac then return true end
    end
    return false
end

local function IsMythicPlusActive()
    if C_ChallengeMode and type(C_ChallengeMode.IsChallengeModeActive) == "function" then
        local ok, act = pcall(C_ChallengeMode.IsChallengeModeActive)
        if ok and not _IsSecret(act) and act then return true end
    end
    return false
end

local function SafeStr(v, fb)
    if _IsSecret(v) or type(v) ~= "string" then return fb or "" end
    return v
end

local function SafeTrim(v)
    local s = SafeStr(v, "")
    if type(strtrim) == "function" then return strtrim(s) end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function RGBToHex(r, g, b)
    r = math.max(0, math.min(1, tonumber(r) or 0.220))
    g = math.max(0, math.min(1, tonumber(g) or 0.741))
    b = math.max(0, math.min(1, tonumber(b) or 0.973))
    return string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function SanitizeHex6(hex, r, g, b)
    if type(hex) == "string" and hex ~= "" then
        local clean = hex:gsub("^|c", ""):gsub("^#", "")
        if #clean == 8 then clean = clean:sub(3, 8) end
        if #clean == 6 and clean:match("^%x%x%x%x%x%x$") then
            return clean:upper()
        end
    end
    return RGBToHex(r, g, b)
end

local function GetActiveAccentRGB()
    if _G.DynamicSuite and type(_G.DynamicSuite.GetSuiteAccent) == "function" then
        local ok, r, g, b, hex = pcall(_G.DynamicSuite.GetSuiteAccent, _G.DynamicSuite)
        if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return r, g, b, SanitizeHex6(hex, r, g, b)
        elseif ok and type(r) == "table" then
            local tr = r[1] or r.r or 0.220
            local tg = r[2] or r.g or 0.741
            local tb = r[3] or r.b or 0.973
            return tr, tg, tb, SanitizeHex6(r.hex, tr, tg, tb)
        end
    end
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.GetActiveAccentColor) == "function" then
        local ok, r, g, b, hex = pcall(_G.DynamicSuite.UI.GetActiveAccentColor)
        if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return r, g, b, SanitizeHex6(hex, r, g, b)
        end
    end
    return 0.220, 0.741, 0.973, "38BDF8"
end

local function GetAccentHex()
    local r, g, b, hex = GetActiveAccentRGB()
    return SanitizeHex6(hex, r, g, b)
end

local function GetTheme()
    local ar, ag, ab, ahex = GetActiveAccentRGB()
    local surf = {
        header = { 0.015, 0.018, 0.024, 1.00 },
        bg     = { 0.035, 0.039, 0.051, 0.99 },
        card   = { 0.055, 0.063, 0.082, 0.96 },
        cell   = { 0.078, 0.090, 0.122, 0.96 },
        border = { 0.145, 0.165, 0.212, 0.95 },
    }
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.GetThemeColors) == "function" then
        local ok, pal = pcall(_G.DynamicSuite.UI.GetThemeColors)
        if ok and type(pal) == "table" then
            if type(pal.bg) == "table" then surf.bg = pal.bg end
            if type(pal.card) == "table" then surf.card = pal.card end
            if type(pal.border) == "table" then surf.border = pal.border end
        end
    end
    return surf, { r = ar, g = ag, b = ab, hex = ahex }
end

local function GetActiveFontPath()
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.GetFont) == "function" then
        local okF, pF = pcall(_G.DynamicSuite.UI.GetFont)
        if okF and type(pF) == "string" and pF ~= "" then return pF end
    end
    if _G.DynamicLoadUI and _G.DynamicLoadUI.GetActiveFontPath then
        local ok, fontPath = pcall(_G.DynamicLoadUI.GetActiveFontPath)
        if ok and type(fontPath) == "string" and fontPath ~= "" then return fontPath end
    end
    if _G.DynamicSuite and type(_G.DynamicSuite.GetActiveFontPath) == "function" then
        local ok, fontPath = pcall(_G.DynamicSuite.GetActiveFontPath, _G.DynamicSuite)
        if ok and type(fontPath) == "string" and fontPath ~= "" then return fontPath end
    end
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local _backdropCache = {}
local function SetPixelBackdrop(frame, bgColor, borderColor, edgePixels)
    if not frame or not frame.SetBackdrop then return end
    local scale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
    local px = (PixelUtil and PixelUtil.GetNearestPixelSize) and PixelUtil.GetNearestPixelSize(edgePixels or 1, scale) or (edgePixels or 1)
    if px <= 0 then px = 1 end
    if frame._dtEdgePx ~= px then
        frame._dtEdgePx = px
        local bd = _backdropCache[px]
        if not bd then
            bd = {
                bgFile   = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = px,
                insets   = { left = px, right = px, top = px, bottom = px },
            }
            _backdropCache[px] = bd
        end
        frame:SetBackdrop(bd)
    end
    if bgColor then
        frame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    end
    if borderColor then
        frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
    end
end

local trackedFontStrings = {}
local function CreateText(parent, layer, template, customSize, customFlags)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontHighlightSmall")
    local _, defaultSize = fs:GetFont()
    local flags = (customFlags == "OUTLINE") and "" or (customFlags or "")
    fs._dtFontSize = customSize or defaultSize or 12
    fs._dtFontFlags = flags
    local activeFont = GetActiveFontPath()
    if activeFont and fs.SetFont then
        pcall(fs.SetFont, fs, activeFont, fs._dtFontSize, flags)
    end
    table.insert(trackedFontStrings, fs)
    return fs
end

local function SetFontSafe(fs, size, flags)
    if not fs then return end
    local cleanFlags = (flags == "OUTLINE") and "" or (flags or "")
    fs._dtFontSize = size or 11
    fs._dtFontFlags = cleanFlags
    local fontPath = GetActiveFontPath()
    if fontPath and fs.SetFont then
        pcall(fs.SetFont, fs, fontPath, fs._dtFontSize, cleanFlags)
    end
end

local function CreateSolidTex(parent, layer, subLevel, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, subLevel or 0)
    t:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
    return t
end

local function Print(msg)
    local _, _, _, hex = GetActiveAccentRGB()
    if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
        _G.DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFCBD5E1Dynamic|r|cFF%sTalent|r: %s", hex, tostring(msg or "")))
    else
        print(string.format("|cFFCBD5E1Dynamic|r|cFF%sTalent|r: %s", hex, tostring(msg or "")))
    end
end

local COLORS = {
    BgVoid        = { 0.035, 0.039, 0.051, 0.99 },
    BgBarSurface  = { 0.035, 0.043, 0.059, 0.96 },
    BgCanvas      = { 0.067, 0.075, 0.094, 0.96 },
    BgSurface     = { 0.090, 0.102, 0.129, 1.00 },
    BgElevated    = { 0.122, 0.141, 0.176, 1.00 },
    BgHover       = { 0.145, 0.169, 0.212, 1.00 },
    BorderSubtle  = { 1.000, 1.000, 1.000, 0.08 },
    BorderStrong  = { 1.000, 1.000, 1.000, 0.15 },
    Silver        = { 0.796, 0.835, 0.882, 1.00 },
    Gold          = { 0.984, 0.749, 0.141, 1.00 },
    Green         = { 0.204, 0.827, 0.600, 1.00 },
    Red           = { 0.973, 0.443, 0.443, 1.00 },
}

-- ============================================================================
-- 2. DATABASE SCHEMA, CANONICAL GROUPS & ZERO-LOSS MIGRATION (DynamicPrepDB)
-- ============================================================================
local DEFAULT_TALENT_GROUP_ORDER = { "Raid", "M+", "Delves", "PvP", "Custom" }
local TALENT_GROUP_ORDER         = { "Raid", "M+", "Delves", "PvP", "Custom" }
local TALENT_GROUP_HEX           = { Raid = "F87171", ["M+"] = "38BDF8", Delves = "FBBF24", PvP = "A855F7", Custom = "94A3B8" }

local function NormalizeTalentGroupKey(grp)
    local low = SafeTrim(tostring(grp or "")):lower()
    if low == "raid" or low == "raids" then return "Raid" end
    if low == "m+" or low == "mythic+" or low == "mythic +" or low == "dungeons" or low == "dungeon" then return "M+" end
    if low == "delve" or low == "delves" then return "Delves" end
    if low == "pvp" then return "PvP" end
    return "Custom"
end
DynamicTalent.NormalizeTalentGroupKey = NormalizeTalentGroupKey

local function CategoriseTalentGroup(name)
    local low = tostring(name or ""):lower()
    if low:find("raid", 1, true) or low:find("boss", 1, true) then return "Raid" end
    if low:find("m+", 1, true) or low:find("mythic", 1, true) or low:find("dungeon", 1, true) then return "M+" end
    if low:find("delve", 1, true) then return "Delves" end
    if low:find("arena", 1, true) or low:find("bg", 1, true) or low:find("blitz", 1, true) or low:find("pvp", 1, true) or low:find("shuffle", 1, true) or low:find("warmode", 1, true) or low:find("war mode", 1, true) then return "PvP" end
    return "Custom"
end

local DEFAULTS = {
    enabled                    = true,
    activeSubTab               = 1,
    migratedFromPrep           = false,
    nextLoadoutIDSeq           = 0,
    talentReminderEnabled      = true,
    talentReminderToastEnabled = true,
    prioritiseCurrentZone      = false,
    rightClickHeroSwap         = true,
    talentBackdropBase         = "OBSIDIAN",
    talentBackdropMist         = "HERO_MIST",
    talentBackdropDimmer       = 35,
    talentBackdropMistIntensity = 60,
    talentBackdropAnimate      = true,
    talentGroupOrder           = { "Raid", "M+", "Delves", "PvP", "Custom" },
    talentPreferredBySpec      = {},
    talentBossMap              = {},
    talentDungeonMap           = {},
    talentPvPMap               = {},
    talentZoneMap              = {},
    talentStringLibrary        = {},
    talentMgrModalSize         = { w = 880, h = 580 },
    dismissedTalentQuickStart  = false,
    lastAppliedTalentID        = {},
    lastAppliedTalentName      = {},
    lastAppliedTalentLiveStr   = {},
}

local function CopyDefaults(dst, src)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

local function DeepCopyValue(v, seen)
    local tv = type(v)
    if tv == "string" or tv == "number" or tv == "boolean" then
        return v
    end
    if tv ~= "table" then
        return nil
    end
    seen = seen or {}
    if seen[v] then
        return seen[v]
    end
    local out = {}
    seen[v] = out
    for k, val in pairs(v) do
        local tk = type(k)
        if tk == "string" or tk == "number" or tk == "boolean" then
            local c = DeepCopyValue(val, seen)
            if c ~= nil then
                out[k] = c
            end
        end
    end
    return out
end

local function SanitizeGroupOrder(rawOrder)
    local out, seen = {}, {}
    if type(rawOrder) == "table" then
        for _, g in ipairs(rawOrder) do
            if type(g) == "string" and g ~= "" then
                local canon = NormalizeTalentGroupKey(g)
                if not seen[canon] then
                    seen[canon] = true
                    table.insert(out, canon)
                end
            end
        end
    end
    for _, g in ipairs(DEFAULT_TALENT_GROUP_ORDER) do
        if not seen[g] then
            seen[g] = true
            table.insert(out, g)
        end
    end
    return out
end

local function GenerateLoadoutID(db)
    local d = (type(db) == "table") and db or _G.DynamicTalentDB or {}
    local seq = (tonumber(d.nextLoadoutIDSeq) or 0) + 1
    d.nextLoadoutIDSeq = seq
    local ts = (type(GetTime) == "function") and math.floor((GetTime() or 0) * 1000) or 0
    return string.format("dt_%d_%d", seq, ts)
end

local function EnsureEntryID(entry, db)
    if type(entry) ~= "table" then return nil end
    if type(entry.id) ~= "string" or entry.id == "" then
        entry.id = GenerateLoadoutID(db)
    end
    return entry.id
end

local function DoesRuleMatchEntry(rule, entry)
    if type(rule) ~= "table" or type(entry) ~= "table" then return false end
    if type(rule.loadoutID) == "string" and rule.loadoutID ~= "" then
        return (type(entry.id) == "string" and entry.id == rule.loadoutID)
    end
    local rStr = (type(rule.importString) == "string" and rule.importString ~= "") and rule.importString or nil
    local eStr = (type(entry.importString) == "string" and entry.importString ~= "") and entry.importString or nil
    local eHash = (type(entry.liveHash) == "string" and entry.liveHash ~= "") and entry.liveHash or nil
    if rStr and eStr then
        return (rStr == eStr) or (eHash ~= nil and rStr == eHash)
    end
    local rName = (type(rule.loadoutName) == "string" and rule.loadoutName ~= "") and rule.loadoutName:lower() or nil
    local eName = (type(entry.name) == "string" and entry.name ~= "") and entry.name:lower() or nil
    if rName and eName and rName == eName then
        if type(rule.group) == "string" and rule.group ~= "" then
            return NormalizeTalentGroupKey(rule.group) == NormalizeTalentGroupKey(entry.group or "Custom")
        end
        return true
    end
    return false
end
DynamicTalent.DoesRuleMatchEntry = DoesRuleMatchEntry

local function EnsureDB()
    if type(_G.DynamicTalentDB) == "table" then
        local oldMode = _G.DynamicTalentDB.talentBackdropMode
        if type(oldMode) == "string" and (_G.DynamicTalentDB.talentBackdropBase == nil or _G.DynamicTalentDB.talentBackdropMist == nil) then
            if oldMode == "BLIZZARD" then
                if _G.DynamicTalentDB.talentBackdropBase == nil then _G.DynamicTalentDB.talentBackdropBase = "BLIZZARD" end
                if _G.DynamicTalentDB.talentBackdropMist == nil then _G.DynamicTalentDB.talentBackdropMist = "OFF" end
            elseif oldMode == "OBSIDIAN" then
                if _G.DynamicTalentDB.talentBackdropBase == nil then _G.DynamicTalentDB.talentBackdropBase = "OBSIDIAN" end
                if _G.DynamicTalentDB.talentBackdropMist == nil then _G.DynamicTalentDB.talentBackdropMist = "OFF" end
            elseif oldMode == "HERO_MIST" then
                if _G.DynamicTalentDB.talentBackdropBase == nil then _G.DynamicTalentDB.talentBackdropBase = "OBSIDIAN" end
                if _G.DynamicTalentDB.talentBackdropMist == nil then _G.DynamicTalentDB.talentBackdropMist = "HERO_MIST" end
            elseif oldMode == "CLASS_GLOW" then
                if _G.DynamicTalentDB.talentBackdropBase == nil then _G.DynamicTalentDB.talentBackdropBase = "OBSIDIAN" end
                if _G.DynamicTalentDB.talentBackdropMist == nil then _G.DynamicTalentDB.talentBackdropMist = "CLASS_GLOW" end
            end
        end
    end
    _G.DynamicTalentDB = CopyDefaults(_G.DynamicTalentDB, DEFAULTS)
    local db = _G.DynamicTalentDB

    if db.migratedFromPrep ~= true then
        local src = _G.DynamicPrepDB
        if type(src) == "table" then
            if type(src.talentReminderEnabled) == "boolean" then
                db.talentReminderEnabled = src.talentReminderEnabled
            end
            if type(src.talentReminderToastEnabled) == "boolean" then
                db.talentReminderToastEnabled = src.talentReminderToastEnabled
            end
            if type(src.dismissedTalentQuickStart) == "boolean" then
                db.dismissedTalentQuickStart = src.dismissedTalentQuickStart
            end
            if type(src.talentMgrModalSize) == "table" then
                local w = tonumber(src.talentMgrModalSize.w)
                local h = tonumber(src.talentMgrModalSize.h)
                if w and w >= 800 then
                    db.talentMgrModalSize = {
                        w = math.max(800, math.min(1040, math.floor(w + 0.5))),
                        h = math.max(520, math.min(820, math.floor((h or 580) + 0.5))),
                    }
                else
                    db.talentMgrModalSize = { w = 880, h = 580 }
                end
            end
            local tblKeys = {
                "talentStringLibrary",
                "talentBossMap",
                "talentDungeonMap",
                "talentZoneMap",
                "talentPreferredBySpec",
                "lastAppliedTalentName",
                "lastAppliedTalentLiveStr",
            }
            for _, tk in ipairs(tblKeys) do
                if type(src[tk]) == "table" then
                    db[tk] = DeepCopyValue(src[tk]) or {}
                end
            end
            -- Sanitize migrated library entries
            if type(db.talentStringLibrary) == "table" then
                for specID, lib in pairs(db.talentStringLibrary) do
                    if type(lib) == "table" then
                        local cleanLib = {}
                        local numIndices = {}
                        for k in pairs(lib) do
                            if type(k) == "number" then
                                table.insert(numIndices, k)
                            end
                        end
                        table.sort(numIndices)
                        for _, idx in ipairs(numIndices) do
                            local entry = lib[idx]
                            if type(entry) == "table" and type(entry.name) == "string" and entry.name ~= "" and type(entry.importString) == "string" and entry.importString ~= "" then
                                local rawGrp = (type(entry.group) == "string" and entry.group ~= "") and entry.group or CategoriseTalentGroup(entry.name)
                                entry.group = NormalizeTalentGroupKey(rawGrp)
                                table.insert(cleanLib, entry)
                            end
                        end
                        db.talentStringLibrary[specID] = cleanLib
                    else
                        db.talentStringLibrary[specID] = nil
                    end
                end
            end
            -- Mirror talentZoneMap[specID].pvp -> talentPvPMap[specID].all & clear DynamicTalentDB copy
            db.talentPvPMap = type(db.talentPvPMap) == "table" and db.talentPvPMap or {}
            if type(db.talentZoneMap) == "table" then
                for specID, zMap in pairs(db.talentZoneMap) do
                    if type(zMap) == "table" and type(zMap.pvp) == "table" and type(zMap.pvp.importString) == "string" and zMap.pvp.importString ~= "" then
                        db.talentPvPMap[specID] = type(db.talentPvPMap[specID]) == "table" and db.talentPvPMap[specID] or {}
                        if type(db.talentPvPMap[specID].all) ~= "table" then
                            local mirrored = DeepCopyValue(zMap.pvp)
                            if type(mirrored) == "table" then
                                mirrored.group = NormalizeTalentGroupKey(mirrored.group or "PvP")
                                db.talentPvPMap[specID].all = mirrored
                            end
                        end
                        zMap.pvp = nil
                    end
                end
            end
        end
        db.migratedFromPrep = true
    end

    db.talentPvPMap = type(db.talentPvPMap) == "table" and db.talentPvPMap or {}
    db.talentZoneMap = type(db.talentZoneMap) == "table" and db.talentZoneMap or {}
    db.talentBossMap = type(db.talentBossMap) == "table" and db.talentBossMap or {}
    db.talentDungeonMap = type(db.talentDungeonMap) == "table" and db.talentDungeonMap or {}
    db.talentStringLibrary = type(db.talentStringLibrary) == "table" and db.talentStringLibrary or {}
    db.talentPreferredBySpec = type(db.talentPreferredBySpec) == "table" and db.talentPreferredBySpec or {}
    db.lastAppliedTalentID = type(db.lastAppliedTalentID) == "table" and db.lastAppliedTalentID or {}
    db.lastAppliedTalentName = type(db.lastAppliedTalentName) == "table" and db.lastAppliedTalentName or {}
    db.lastAppliedTalentLiveStr = type(db.lastAppliedTalentLiveStr) == "table" and db.lastAppliedTalentLiveStr or {}
    db.talentGroupOrder = SanitizeGroupOrder(db.talentGroupOrder)
    db.rightClickHeroSwap = (db.rightClickHeroSwap ~= false)
    db.talentBackdropAnimate = (db.talentBackdropAnimate ~= false)
    if db.talentBackdropBase ~= "BLIZZARD" and db.talentBackdropBase ~= "OBSIDIAN" then
        db.talentBackdropBase = "OBSIDIAN"
    end
    local validMists = { OFF = true, HERO_MIST = true, CLASS_GLOW = true }
    if type(db.talentBackdropMist) ~= "string" or not validMists[db.talentBackdropMist] then
        db.talentBackdropMist = "HERO_MIST"
    end
    local rawDim = tonumber(db.talentBackdropDimmer)
    if rawDim == nil then
        db.talentBackdropDimmer = 35
    else
        rawDim = math.max(0, math.min(85, rawDim))
        db.talentBackdropDimmer = math.floor((rawDim / 5) + 0.5) * 5
    end
    local rawInt = tonumber(db.talentBackdropMistIntensity)
    if rawInt == nil then
        db.talentBackdropMistIntensity = 60
    else
        rawInt = math.max(15, math.min(100, rawInt))
        db.talentBackdropMistIntensity = math.floor((rawInt / 5) + 0.5) * 5
    end

    -- Guarantee stable unique loadout IDs and backfill unambiguous legacy rule IDs
    local seenIDs = {}
    for _, lib in pairs(db.talentStringLibrary) do
        if type(lib) == "table" then
            for _, entry in ipairs(lib) do
                if type(entry) == "table" then
                    if type(entry.id) ~= "string" or entry.id == "" or seenIDs[entry.id] then
                        entry.id = GenerateLoadoutID(db)
                    end
                    seenIDs[entry.id] = true
                end
            end
        end
    end
    local function BackfillRuleTable(mapBySpec)
        if type(mapBySpec) ~= "table" then return end
        for specID, specMap in pairs(mapBySpec) do
            local lib = db.talentStringLibrary[specID]
            if type(specMap) == "table" and type(lib) == "table" and #lib > 0 then
                for _, rule in pairs(specMap) do
                    if type(rule) == "table" and (type(rule.loadoutID) ~= "string" or rule.loadoutID == "") then
                        local matchID, matchCount = nil, 0
                        for _, entry in ipairs(lib) do
                            if type(entry) == "table" and DoesRuleMatchEntry(rule, entry) then
                                matchID = entry.id
                                matchCount = matchCount + 1
                            end
                        end
                        if matchCount == 1 and matchID then
                            rule.loadoutID = matchID
                        end
                    end
                end
            end
        end
    end
    BackfillRuleTable(db.talentBossMap)
    BackfillRuleTable(db.talentDungeonMap)
    BackfillRuleTable(db.talentPvPMap)
    BackfillRuleTable(db.talentZoneMap)

    DynamicTalent.db = db
    return db
end

function DynamicTalent:InitDB()
    return EnsureDB()
end

-- ============================================================================
-- 3. TALENT ENGINE STATE, SPEC/CONTEXT HELPERS & 3-TIER MISMATCH PRIORITY
-- ============================================================================
local talentReminderToast = nil
local talentPopoverFrame = nil
local silencedTalentMismatches = {}
local lastAlertedBossMismatchKey = nil
local stickyRaidBoss = nil
local talentMgrModal = nil
local groupDragGhost = nil

local function GetWarModeFlags()
    local desired, active = false, false
    if C_PvP then
        if type(C_PvP.IsWarModeDesired) == "function" then
            local okD, d = pcall(C_PvP.IsWarModeDesired)
            if okD and not _IsSecret(d) and d == true then desired = true end
        end
        if type(C_PvP.IsWarModeActive) == "function" then
            local okA, a = pcall(C_PvP.IsWarModeActive)
            if okA and not _IsSecret(a) and a == true then active = true end
        end
    end
    return desired, active
end

function DynamicTalent:GetActiveSpecID()
    local getSpecFn = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or _G.GetSpecialization
    local getSpecInfoFn = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or _G.GetSpecializationInfo
    if type(getSpecFn) ~= "function" or type(getSpecInfoFn) ~= "function" then return nil end
    local okIdx, idx = pcall(getSpecFn)
    if not okIdx or _IsSecret(idx) or type(idx) ~= "number" or idx < 1 or idx > 4 then return nil end
    local okID, specID = pcall(getSpecInfoFn, idx)
    if not okID or _IsSecret(specID) then return nil end
    return (type(specID) == "number" and specID > 0) and specID or nil
end

function DynamicTalent:InvalidateActiveTalentStringCache()
    self._cachedActiveTalentStr = nil
    self._cachedActiveTalentConfigID = nil
    self._cachedActiveTalentSpecID = nil
end

function DynamicTalent:GetActiveTalentString(forceRefresh)
    if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits and C_Traits.GenerateImportString) then return nil end
    local okA, activeID = pcall(C_ClassTalents.GetActiveConfigID)
    if not okA or _IsSecret(activeID) or type(activeID) ~= "number" or activeID <= 0 then return nil end
    local specID = self:GetActiveSpecID()
    if not forceRefresh and not IsPlayerInCombat()
        and type(self._cachedActiveTalentStr) == "string" and self._cachedActiveTalentStr ~= ""
        and self._cachedActiveTalentConfigID == activeID
        and self._cachedActiveTalentSpecID == specID then
        return self._cachedActiveTalentStr
    end
    local okS, str = pcall(C_Traits.GenerateImportString, activeID)
    if okS and type(str) == "string" and str ~= "" and not _IsSecret(str) then
        if not IsPlayerInCombat() then
            self._cachedActiveTalentStr = str
            self._cachedActiveTalentConfigID = activeID
            self._cachedActiveTalentSpecID = specID
        end
        return str
    end
    return nil
end

local function DetectCurrentZoneContext()
    local instName, instType, diffID = "", "none", 0
    if type(GetInstanceInfo) == "function" then
        local okInst, iName, iType, iDiff = pcall(GetInstanceInfo)
        if okInst then
            if type(iName) == "string" and not _IsSecret(iName) then
                instName = iName
            end
            if type(iType) == "string" and not _IsSecret(iType) then
                instType = iType
            end
            if type(iDiff) == "number" and not _IsSecret(iDiff) then
                diffID = iDiff
            end
        end
    end

    local inInst = (instType ~= "none" and instType ~= "")
    local isDelveActive = (diffID == 208)
    if not isDelveActive and C_DelvesUI and type(C_DelvesUI.HasActiveDelve) == "function" then
        local okD, d = pcall(C_DelvesUI.HasActiveDelve)
        if okD and not _IsSecret(d) and d == true then isDelveActive = true end
    end
    if not isDelveActive and C_PartyInfo and type(C_PartyInfo.IsDelveInProgress) == "function" then
        local okP, p = pcall(C_PartyInfo.IsDelveInProgress)
        if okP and not _IsSecret(p) and p == true then isDelveActive = true end
    end
    if not isDelveActive and C_PartyInfo and type(C_PartyInfo.IsDelveComplete) == "function" then
        local okC, c = pcall(C_PartyInfo.IsDelveComplete)
        if okC and not _IsSecret(c) and c == true then isDelveActive = true end
    end

    local isRaid = (instType == "raid")
    local isParty = (instType == "party" and not isDelveActive and diffID ~= 208)
    local isArena = (instType == "arena")
    local isBG = (instType == "pvp")
    local isNonDelveScenario = (instType == "scenario" and not isDelveActive)
    local isUnknownInstance = (inInst and not isRaid and not isParty and not isArena and not isBG and not isDelveActive)
    local isOutdoor = (not inInst and not isDelveActive)
    local isResting = false
    if type(IsResting) == "function" then
        local okR, resting = pcall(IsResting)
        if okR and not _IsSecret(resting) and resting == true then
            isResting = true
        end
    end
    local wmDesired, wmActive = GetWarModeFlags()
    local isWarMode = isOutdoor and (not isResting) and (wmDesired or wmActive)
    local isAnyPvP = (isArena or isBG or isWarMode)

    return {
        instName           = instName,
        instType           = instType,
        diffID             = diffID,
        inInst             = inInst,
        isDelveActive      = isDelveActive,
        isRaid             = isRaid,
        isParty            = isParty,
        isArena            = isArena,
        isBG               = isBG,
        isNonDelveScenario = isNonDelveScenario,
        isUnknownInstance  = isUnknownInstance,
        isOutdoor          = isOutdoor,
        isResting          = isResting,
        isWarMode          = isWarMode,
        isAnyPvP           = isAnyPvP,
    }
end

function DynamicTalent:GetActiveContentGroup()
    local zc = DetectCurrentZoneContext()
    if zc.isRaid then return "Raid" end
    if zc.isDelveActive then return "Delves" end
    if zc.isParty then return "M+" end
    if zc.isAnyPvP then return "PvP" end
    return "Custom"
end

function DynamicTalent:SilenceTalentMismatch(mKey, label)
    if not mKey then return end
    silencedTalentMismatches[mKey] = true
    self._lastCheckedMismatchSig = nil
    self:HideTalentReminderToast()
    if _G.DynamicPrep and type(_G.DynamicPrep.RefreshBar) == "function" then
        pcall(_G.DynamicPrep.RefreshBar, _G.DynamicPrep)
    end
    Print(string.format("Silenced talent reminder for |cFFFBBF24%s|r for this session.", tostring(label or mKey)))
end

local function GetActiveRaidDifficultyKey()
    if type(GetInstanceInfo) ~= "function" then return nil end
    local ok, _, instType, diffID = pcall(GetInstanceInfo)
    if not ok or _IsSecret(instType) or instType ~= "raid" then return nil end
    if _IsSecret(diffID) or type(diffID) ~= "number" then return nil end
    if diffID == 14 or diffID == 17 then return "normal"
    elseif diffID == 15 then return "heroic"
    elseif diffID == 16 then return "mythic"
    end
    return nil
end

local function DoesRuleMatchDifficulty(entry, diffKey)
    if type(entry) ~= "table" then return false end
    local d = entry.difficulties
    if type(d) ~= "table" then return true end
    if not diffKey then
        return (d.normal or d.heroic or d.mythic) and true or false
    end
    return d[diffKey] == true
end

local function IsEntryAlreadyActive(selfObj, specID, ruleOrName, targetStr, liveStr)
    local activeLib = selfObj:GetActiveTalentLibraryEntry(specID)
    if type(ruleOrName) == "table" then
        if activeLib and DoesRuleMatchEntry(ruleOrName, activeLib) then return true end
        local rStr = ruleOrName.importString
        if liveStr and type(rStr) == "string" and rStr ~= "" and liveStr == rStr then return true end
        return false
    end
    if activeLib then
        if targetStr and (activeLib.importString == targetStr or activeLib.liveHash == targetStr) then return true end
        if ruleOrName and activeLib.name == ruleOrName then return true end
    end
    if liveStr and targetStr and liveStr == targetStr then return true end
    return false
end

local function HasSpecificBossBinds(bossMap)
    if type(bossMap) ~= "table" then return false end
    for _, entry in pairs(bossMap) do
        if type(entry) == "table" and entry.isAllRaid ~= true then
            return true
        end
    end
    return false
end

local function HasActiveSpecSpecificBossBinds(selfObj)
    if not selfObj or not selfObj.db or selfObj.db.enabled == false or selfObj.db.talentReminderEnabled == false then
        return false
    end
    if IsModuleDisabledInSuite("DynamicTalent") then return false end
    local specID = selfObj:GetActiveSpecID()
    if not specID then return false end
    local bossMap = selfObj.db.talentBossMap and selfObj.db.talentBossMap[specID]
    return HasSpecificBossBinds(bossMap)
end

local function ResolveLiveUnitName(unit, skipPlayers)
    if type(unit) ~= "string" or unit == "" then return nil end
    if type(UnitExists) ~= "function" or type(UnitName) ~= "function" then return nil end
    local okE, ex = pcall(UnitExists, unit)
    if not okE or _IsSecret(ex) or not ex then return nil end
    if type(UnitIsDeadOrGhost) == "function" then
        local okD, dead = pcall(UnitIsDeadOrGhost, unit)
        if not okD or _IsSecret(dead) or dead then return nil end
    end
    if skipPlayers then
        if type(UnitIsPlayer) == "function" then
            local okP, isPl = pcall(UnitIsPlayer, unit)
            if okP and not _IsSecret(isPl) and isPl then return nil end
        end
    end
    local okN, name = pcall(UnitName, unit)
    if not okN or type(name) ~= "string" or _IsSecret(name) then return nil end
    local trimmed = SafeTrim(name)
    return (trimmed ~= "") and trimmed or nil
end

local function MatchBoundBossByName(selfObj, bossMap, diffKey, unitName)
    if type(unitName) ~= "string" or unitName == "" or type(bossMap) ~= "table" then return nil end
    local lowTarget = SafeTrim(unitName):lower()
    if lowTarget == "" then return nil end
    local _, _, _, s2Boss = selfObj:MatchBossTargetName(unitName)
    local canonicalLow = s2Boss and tostring(s2Boss.name or ""):lower() or nil
    local matchEntry = nil
    for bKey, entry in pairs(bossMap) do
        if type(entry) == "table" and entry.isAllRaid ~= true then
            local bLow = tostring(entry.bossName or bKey):lower()
            local matchedName = false
            if canonicalLow then
                matchedName = (bLow == canonicalLow)
            else
                matchedName = (bLow == lowTarget or (#bLow >= 4 and lowTarget:find(bLow, 1, true))) and true or false
            end
            if matchedName and DoesRuleMatchDifficulty(entry, diffKey) then
                matchEntry = entry
                if bLow == lowTarget or (canonicalLow and bLow == canonicalLow) then break end
            end
        end
    end
    if matchEntry then
        return matchEntry, (canonicalLow or lowTarget), unitName
    end
    return nil
end

local function ResolveBoundBossFromSources(selfObj, bossMap, diffKey, zc)
    if IsPlayerInCombat() then return nil end
    if not HasSpecificBossBinds(bossMap) then return nil end

    local seen = {}
    local function TryUnit(unit, skipFriendlyAndPlayers)
        local n = ResolveLiveUnitName(unit, skipFriendlyAndPlayers)
        if not n then return nil end
        local low = n:lower()
        if seen[low] then return nil end
        seen[low] = true
        return MatchBoundBossByName(selfObj, bossMap, diffKey, n)
    end

    -- 1) Player's hard target
    local mEntry, bKey, rawName = TryUnit("target", false)
    if mEntry then return mEntry, bKey, rawName, "target" end

    -- 2) Player's Action Target (soft enemy target)
    mEntry, bKey, rawName = TryUnit("softenemy", true)
    if mEntry then return mEntry, bKey, rawName, "softenemy" end

    -- 3) Mouseover unit
    mEntry, bKey, rawName = TryUnit("mouseover", true)
    if mEntry then return mEntry, bKey, rawName, "mouseover" end

    -- 4) Focus unit
    mEntry, bKey, rawName = TryUnit("focus", false)
    if mEntry then return mEntry, bKey, rawName, "focus" end

    -- 5) Boss frames (boss1..boss5)
    for i = 1, 5 do
        local bUnit = "boss" .. i
        mEntry, bKey, rawName = TryUnit(bUnit, false)
        if mEntry then return mEntry, bKey, rawName, bUnit end
    end

    -- 4) Visible enemy nameplates
    if C_NamePlate and type(C_NamePlate.GetNamePlates) == "function" then
        local okP, plates = pcall(C_NamePlate.GetNamePlates)
        if okP and type(plates) == "table" then
            for i = 1, #plates do
                local plate = plates[i]
                if type(plate) == "table" then
                    local token = plate.namePlateUnitToken
                    if (type(token) ~= "string" or token == "") and type(plate.UnitFrame) == "table" then
                        token = plate.UnitFrame.unit
                    end
                    if type(token) == "string" and token ~= "" and not _IsSecret(token) then
                        mEntry, bKey, rawName = TryUnit(token, true)
                        if mEntry then return mEntry, bKey, rawName, "nameplate" end
                    end
                end
            end
        end
    end

    -- 5) Raid or party members' targets when inside a raid instance
    if zc and zc.isRaid then
        local inRaid = false
        if type(IsInRaid) == "function" then
            local okR, r = pcall(IsInRaid)
            if okR and not _IsSecret(r) and r then inRaid = true end
        end
        local count = 0
        if type(GetNumGroupMembers) == "function" then
            local okG, g = pcall(GetNumGroupMembers)
            if okG and type(g) == "number" and not _IsSecret(g) and g > 0 then count = g end
        end
        if inRaid then
            local limit = math.min((count > 0) and count or 40, 40)
            for i = 1, limit do
                mEntry, bKey, rawName = TryUnit("raid" .. i .. "target", true)
                if mEntry then return mEntry, bKey, rawName, "raidtarget" end
            end
        else
            local inGroup = false
            if type(IsInGroup) == "function" then
                local okGrp, grp = pcall(IsInGroup)
                if okGrp and not _IsSecret(grp) and grp then inGroup = true end
            end
            if inGroup or count > 1 then
                local limit = math.min((count > 0) and count or 4, 4)
                for i = 1, limit do
                    mEntry, bKey, rawName = TryUnit("party" .. i .. "target", true)
                    if mEntry then return mEntry, bKey, rawName, "partytarget" end
                end
            end
        end
    end

    return nil
end

local function FindLiveSeason2BossName(selfObj, zc)
    if IsPlayerInCombat() or not (zc and zc.isRaid) then return nil end
    local function CheckUnit(unit, skipPlayers)
        local n = ResolveLiveUnitName(unit, skipPlayers)
        if not n then return nil end
        local _, _, _, s2Boss = selfObj:MatchBossTargetName(n)
        if s2Boss and s2Boss.name then
            return s2Boss.name
        end
        return nil
    end

    for _, u in ipairs({ "target", "softenemy", "mouseover", "focus", "boss1", "boss2", "boss3", "boss4", "boss5" }) do
        local bn = CheckUnit(u, u == "mouseover" or u == "softenemy")
        if bn then return bn, u end
    end

    if C_NamePlate and type(C_NamePlate.GetNamePlates) == "function" then
        local okP, plates = pcall(C_NamePlate.GetNamePlates)
        if okP and type(plates) == "table" then
            for i = 1, #plates do
                local plate = plates[i]
                if type(plate) == "table" then
                    local token = plate.namePlateUnitToken
                    if (type(token) ~= "string" or token == "") and type(plate.UnitFrame) == "table" then
                        token = plate.UnitFrame.unit
                    end
                    if type(token) == "string" and token ~= "" and not _IsSecret(token) then
                        local bn = CheckUnit(token, true)
                        if bn then return bn, "nameplate" end
                    end
                end
            end
        end
    end

    local inRaid = false
    if type(IsInRaid) == "function" then
        local okR, r = pcall(IsInRaid)
        if okR and not _IsSecret(r) and r then inRaid = true end
    end
    local count = 0
    if type(GetNumGroupMembers) == "function" then
        local okG, g = pcall(GetNumGroupMembers)
        if okG and type(g) == "number" and not _IsSecret(g) and g > 0 then count = g end
    end
    if inRaid then
        local limit = math.min((count > 0) and count or 40, 40)
        for i = 1, limit do
            local bn = CheckUnit("raid" .. i .. "target", true)
            if bn then return bn, "raidtarget" end
        end
    elseif count > 1 then
        local limit = math.min(count, 4)
        for i = 1, limit do
            local bn = CheckUnit("party" .. i .. "target", true)
            if bn then return bn, "partytarget" end
        end
    end
    return nil
end

local function IsActiveBuildBoundToCurrentRaid(selfObj, specID, bossMap, instName, diffKey)
    if type(bossMap) ~= "table" then return false end
    local activeLib = selfObj:GetActiveTalentLibraryEntry(specID)
    if not activeLib then return false end

    local lowInst = type(instName) == "string" and instName:lower() or ""
    local raidBossSet = nil
    if lowInst ~= "" then
        for _, rObj in ipairs(selfObj:GetSeason2Raids()) do
            local rLow = tostring(rObj.name or ""):lower()
            local sLow = tostring(rObj.short or ""):lower()
            if lowInst == rLow or (sLow ~= "" and lowInst:find(sLow, 1, true)) then
                raidBossSet = {}
                for _, bObj in ipairs(rObj.bosses or {}) do
                    raidBossSet[tostring(bObj.name or ""):lower()] = true
                end
                break
            end
        end
    end

    for _, entry in pairs(bossMap) do
        if type(entry) == "table" and entry.isAllRaid ~= true
           and DoesRuleMatchEntry(entry, activeLib)
           and DoesRuleMatchDifficulty(entry, diffKey) then
            local eRaidLow = tostring(entry.raidName or ""):lower()
            local eShortLow = tostring(entry.raidShort or ""):lower()
            local eBossLow = tostring(entry.bossName or ""):lower()
            if lowInst == ""
               or (eRaidLow ~= "" and (lowInst == eRaidLow or lowInst:find(eRaidLow, 1, true)))
               or (eShortLow ~= "" and lowInst:find(eShortLow, 1, true))
               or (raidBossSet and raidBossSet[eBossLow] == true) then
                return true, activeLib
            end
        end
    end
    return false
end

local function SafeGetSubZoneText()
    if type(GetSubZoneText) ~= "function" then return "" end
    local ok, sz = pcall(GetSubZoneText)
    if ok and type(sz) == "string" and not _IsSecret(sz) then
        return SafeTrim(sz)
    end
    return ""
end

function DynamicTalent:ClearStickyRaidBoss()
    stickyRaidBoss = nil
end

function DynamicTalent:ResetBossAlertDedupe()
    lastAlertedBossMismatchKey = nil
    self._lastCheckedMismatchSig = nil
end

function DynamicTalent:GetActiveTalentMismatch()
    if not self.db or self.db.enabled == false or self.db.talentReminderEnabled == false or IsModuleDisabledInSuite("DynamicTalent") then
        return nil
    end
    local specID = self:GetActiveSpecID()
    if not specID or not (C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID) then return nil end
    if type(C_ClassTalents.GetActiveConfigID) == "function" then
        local okAct, activeCfgID = pcall(C_ClassTalents.GetActiveConfigID)
        if not okAct or _IsSecret(activeCfgID) or type(activeCfgID) ~= "number" or activeCfgID <= 0 then
            return nil
        end
    end
    local okCur, curID = pcall(C_ClassTalents.GetLastSelectedSavedConfigID, specID)
    if not okCur or _IsSecret(curID) then return nil end

    -- Never nag when an active Mythic+ keystone is running (talent swaps are locked)
    if IsMythicPlusActive() then return nil end

    local liveStr = self:GetActiveTalentString()
    local zc = DetectCurrentZoneContext()
    if zc.isNonDelveScenario or zc.isUnknownInstance then
        self._lastDiag = {
            specID = specID,
            zc = zc,
            source = "Scenario / Story",
            ruleDesc = "Suppressed in story or non-standard scenario",
            status = "Suppressed in story scenario",
        }
        return nil
    end
    local isDelveActive = zc.isDelveActive
    local instName      = zc.instName
    local isRaid        = zc.isRaid
    local isParty       = zc.isParty
    local isArena       = zc.isArena
    local isBG          = zc.isBG
    local isOutdoor     = zc.isOutdoor
    local isResting     = zc.isResting
    local isWarMode     = zc.isWarMode
    local isAnyPvP      = zc.isAnyPvP

    local diffKey = isRaid and GetActiveRaidDifficultyKey() or nil
    local diffLbl = (diffKey == "normal" and "LFR/N") or (diffKey == "heroic" and "H") or (diffKey == "mythic" and "M") or nil
    local diffTag = diffLbl and (" (" .. diffLbl .. ")") or ""

    -- =========================================================================
    -- PRIORITY 1 (Tier 1): Specific Raid Boss, Specific M+ Dungeon, or Specific PvP Mode
    -- =========================================================================
    local bossMap = self.db.talentBossMap and self.db.talentBossMap[specID]
    local subZone = isRaid and SafeGetSubZoneText() or ""
    local matchEntry, bossKey, tName, matchSource = ResolveBoundBossFromSources(self, bossMap, diffKey, zc)
    local unboundBossName = nil
    if not matchEntry and isRaid and type(bossMap) == "table" then
        unboundBossName = FindLiveSeason2BossName(self, zc)
        if unboundBossName then
            stickyRaidBoss = nil
        elseif instName ~= "" then
            local lowInst = instName:lower()
            for _, rObj in ipairs(self:GetSeason2Raids()) do
                local rLow = tostring(rObj.name or ""):lower()
                local sLow = tostring(rObj.short or ""):lower()
                if (lowInst == rLow or (sLow ~= "" and lowInst:find(sLow, 1, true))) and rObj.bosses and #rObj.bosses == 1 then
                    local mE, bK, rN = MatchBoundBossByName(self, bossMap, diffKey, rObj.bosses[1].name)
                    if mE then
                        matchEntry, bossKey, tName, matchSource = mE, bK, rN, "single-boss raid"
                    end
                    break
                end
            end
        end
    end
    if matchEntry then
        if isRaid then
            stickyRaidBoss = {
                specID   = specID,
                instName = instName,
                subZone  = subZone,
                diffKey  = diffKey,
                bossKey  = bossKey,
                bossName = tostring(matchEntry.bossName or tName),
                entry    = matchEntry,
                source   = matchSource,
            }
        end
    elseif isRaid and stickyRaidBoss and not unboundBossName then
        local validSticky = (stickyRaidBoss.specID == specID)
            and (stickyRaidBoss.instName == instName)
            and (stickyRaidBoss.subZone == subZone)
            and (stickyRaidBoss.diffKey == diffKey)
            and type(bossMap) == "table"
        if validSticky then
            local stillBound = nil
            for _, entry in pairs(bossMap) do
                if entry == stickyRaidBoss.entry and DoesRuleMatchDifficulty(entry, diffKey) then
                    stillBound = entry
                    break
                end
            end
            if not stillBound then
                for _, entry in pairs(bossMap) do
                    if type(entry) == "table" and entry.isAllRaid ~= true
                       and tostring(entry.bossName or ""):lower() == tostring(stickyRaidBoss.bossName or ""):lower()
                       and DoesRuleMatchDifficulty(entry, diffKey) then
                        stillBound = entry
                        break
                    end
                end
            end
            if stillBound then
                matchEntry = stillBound
                bossKey = stickyRaidBoss.bossKey
                tName = stickyRaidBoss.bossName
                matchSource = "sticky boss"
            else
                stickyRaidBoss = nil
            end
        else
            stickyRaidBoss = nil
        end
    elseif not isRaid then
        stickyRaidBoss = nil
    end

    self._lastDiag = {
        specID = specID,
        zc = zc,
        subZone = subZone,
        diffKey = diffKey,
        diffLbl = diffLbl,
        source = matchSource or "None",
        bossName = matchEntry and tostring(matchEntry.bossName or tName or "") or nil,
        ruleName = matchEntry and tostring(matchEntry.loadoutName or "Boss Loadout") or nil,
        ruleDesc = matchEntry and (tostring(matchEntry.bossName or tName or "") .. " -> " .. tostring(matchEntry.loadoutName or "Boss Loadout")) or "No matching rule",
        status = "No matching rule",
    }

    if matchEntry then
        local mKey = "boss:" .. bossKey .. ":" .. tostring(diffKey or "any")
        self._lastDiag.mKey = mKey
        if not silencedTalentMismatches[mKey] then
            if matchEntry.importString and matchEntry.importString ~= "" then
                if not IsEntryAlreadyActive(self, specID, matchEntry, matchEntry.importString, liveStr) then
                    local dispBoss = tostring(matchEntry.bossName or tName)
                    self._lastDiag.status = "Swap recommended"
                    return { id = matchEntry.loadoutID, name = matchEntry.loadoutName or "Boss Loadout", importString = matchEntry.importString, group = matchEntry.group or "Raid", heroAcronym = matchEntry.heroAcronym },
                        matchEntry.loadoutName or "Boss Loadout", "Boss: " .. dispBoss .. diffTag, mKey
                end
                self._lastDiag.status = "Already active"
            elseif matchEntry.configID and curID ~= matchEntry.configID then
                self._lastDiag.status = "Swap recommended"
                return matchEntry.configID, matchEntry.loadoutName or "Boss Loadout", "Boss: " .. tostring(tName or matchEntry.bossName or "Boss"), mKey
            else
                self._lastDiag.status = "Already active"
            end
        else
            self._lastDiag.status = "Silenced for session"
        end
        return nil
    end

    local dungMap = self.db.talentDungeonMap and self.db.talentDungeonMap[specID]
    local tierNow = nil
    if isParty and C_MythicPlus and type(C_MythicPlus.GetOwnedKeystoneLevel) == "function" then
        local okLvl, ownedLvl = pcall(C_MythicPlus.GetOwnedKeystoneLevel)
        if okLvl and not _IsSecret(ownedLvl) and type(ownedLvl) == "number" then
            tierNow = (ownedLvl >= 10) and "HIGH" or ((ownedLvl >= 2) and "LOW" or nil)
        end
    end
    if isParty and instName ~= "" and type(dungMap) == "table" and next(dungMap) ~= nil then
        local lowInst = instName:lower()
        local specExact, specAny = nil, nil
        for _, dEntry in pairs(dungMap) do
            if type(dEntry) == "table" and type(dEntry.dungeonName) == "string" then
                local dLow = dEntry.dungeonName:lower()
                if dEntry.isAllMPlus ~= true and dLow ~= "all m+ dungeons" then
                    if dLow == lowInst or lowInst:find(dLow, 1, true) or dLow:find(lowInst, 1, true) then
                        local kt = dEntry.keyTier or "ANY"
                        if tierNow and kt == tierNow then
                            specExact = dEntry
                        elseif kt == "ANY" then
                            specAny = dEntry
                        end
                    end
                end
            end
        end
        local dMatch = specExact or specAny
        if dMatch and dMatch.importString and dMatch.importString ~= "" then
            local mKey = "mplus:" .. lowInst .. ":" .. tostring(dMatch.keyTier or "ANY")
            local tLabel = (dMatch.keyTier == "HIGH" and " (+10+)") or (dMatch.keyTier == "LOW" and " (+2-9)") or ""
            self._lastDiag.source = "M+ Dungeon"
            self._lastDiag.ruleDesc = "M+: " .. instName .. tLabel .. " -> " .. tostring(dMatch.loadoutName or "M+ Loadout")
            if not silencedTalentMismatches[mKey] and not IsEntryAlreadyActive(self, specID, dMatch, dMatch.importString, liveStr) then
                self._lastDiag.status = "Swap recommended"
                return { id = dMatch.loadoutID, name = dMatch.loadoutName or "M+ Loadout", importString = dMatch.importString, group = dMatch.group or "M+", heroAcronym = dMatch.heroAcronym },
                    dMatch.loadoutName or "M+ Loadout", "M+: " .. instName .. tLabel, mKey
            end
            self._lastDiag.status = silencedTalentMismatches[mKey] and "Silenced for session" or "Already active"
            return nil
        end
    end

    local pvpMap = self.db.talentPvPMap and self.db.talentPvPMap[specID]
    if isAnyPvP and type(pvpMap) == "table" then
        local pvpKey, pvpLbl, pvpMKey = nil, nil, nil
        if isArena then
            pvpKey, pvpLbl, pvpMKey = "arena", "PvP: Arena", "pvp:arena"
        elseif isBG then
            pvpKey, pvpLbl, pvpMKey = "bg", "PvP: Battlegrounds", "pvp:bg"
        elseif isWarMode then
            pvpKey, pvpLbl, pvpMKey = "warmode", "PvP: War Mode", "pvp:warmode"
        end
        local pRule = pvpKey and pvpMap[pvpKey]
        if type(pRule) == "table" and type(pRule.importString) == "string" and pRule.importString ~= "" then
            self._lastDiag.source = pvpLbl
            self._lastDiag.ruleDesc = pvpLbl .. " -> " .. tostring(pRule.loadoutName or pvpLbl)
            if not silencedTalentMismatches[pvpMKey] and not IsEntryAlreadyActive(self, specID, pRule, pRule.importString, liveStr) then
                self._lastDiag.status = "Swap recommended"
                return { id = pRule.loadoutID, name = pRule.loadoutName or pvpLbl, importString = pRule.importString, group = pRule.group or "PvP", heroAcronym = pRule.heroAcronym },
                    pRule.loadoutName or pvpLbl, pvpLbl, pvpMKey
            end
            self._lastDiag.status = silencedTalentMismatches[pvpMKey] and "Silenced for session" or "Already active"
            return nil
        end
    end

    -- =========================================================================
    -- PRIORITY 2 (Tier 2): Content-Wide & Zone Defaults (Never Overrides T1)
    -- =========================================================================
    if isRaid and type(bossMap) == "table" then
        if not unboundBossName then
            local isBossBuild, activeLib = IsActiveBuildBoundToCurrentRaid(self, specID, bossMap, instName, diffKey)
            if isBossBuild and activeLib then
                self._lastDiag.source = "Boss Raid Build Active"
                self._lastDiag.ruleDesc = "Keeping " .. tostring(activeLib.name) .. " (bound in this raid) over All Raids"
                self._lastDiag.status = "Already active"
                return nil
            end
        end
        local allRaidBest, bestScore = nil, 99
        for _, entry in pairs(bossMap) do
            if type(entry) == "table" and entry.isAllRaid == true and DoesRuleMatchDifficulty(entry, diffKey) then
                local d = entry.difficulties
                local cnt = (type(d) == "table") and ((d.normal and 1 or 0) + (d.heroic and 1 or 0) + (d.mythic and 1 or 0)) or 3
                if cnt < bestScore then
                    bestScore = cnt
                    allRaidBest = entry
                end
            end
        end
        if allRaidBest and allRaidBest.importString and allRaidBest.importString ~= "" then
            local mKey = "allraid:" .. tostring(diffKey or "any")
            self._lastDiag.source = "All Raids"
            self._lastDiag.ruleDesc = "All Raids" .. diffTag .. " -> " .. tostring(allRaidBest.loadoutName or "Raid Loadout")
            if not silencedTalentMismatches[mKey] and not IsEntryAlreadyActive(self, specID, allRaidBest, allRaidBest.importString, liveStr) then
                self._lastDiag.status = "Swap recommended"
                return { id = allRaidBest.loadoutID, name = allRaidBest.loadoutName or "Raid Loadout", importString = allRaidBest.importString, group = allRaidBest.group or "Raid", heroAcronym = allRaidBest.heroAcronym },
                    allRaidBest.loadoutName or "Raid Loadout", "All Raids" .. diffTag, mKey
            end
            self._lastDiag.status = silencedTalentMismatches[mKey] and "Silenced for session" or "Already active"
            return nil
        end
    end

    if isParty and type(dungMap) == "table" then
        local allExact, allAny = nil, nil
        for _, dEntry in pairs(dungMap) do
            if type(dEntry) == "table" and type(dEntry.dungeonName) == "string" then
                local dLow = dEntry.dungeonName:lower()
                if dEntry.isAllMPlus == true or dLow == "all m+ dungeons" then
                    local kt = dEntry.keyTier or "ANY"
                    if tierNow and kt == tierNow then
                        allExact = dEntry
                    elseif kt == "ANY" then
                        allAny = dEntry
                    end
                end
            end
        end
        local allM = allExact or allAny
        if allM and allM.importString and allM.importString ~= "" then
            local mKey = "mplus:all:" .. tostring(allM.keyTier or "ANY")
            local tLabel = (allM.keyTier == "HIGH" and " (+10+)") or (allM.keyTier == "LOW" and " (+2-9)") or ""
            self._lastDiag.source = "All M+"
            self._lastDiag.ruleDesc = "All M+" .. tLabel .. " -> " .. tostring(allM.loadoutName or "M+ Loadout")
            if not silencedTalentMismatches[mKey] and not IsEntryAlreadyActive(self, specID, allM, allM.importString, liveStr) then
                self._lastDiag.status = "Swap recommended"
                return { id = allM.loadoutID, name = allM.loadoutName or "M+ Loadout", importString = allM.importString, group = allM.group or "M+", heroAcronym = allM.heroAcronym },
                    allM.loadoutName or "M+ Loadout", "All M+" .. tLabel, mKey
            end
            self._lastDiag.status = silencedTalentMismatches[mKey] and "Silenced for session" or "Already active"
            return nil
        end
    end

    local zoneMap = self.db.talentZoneMap and self.db.talentZoneMap[specID]
    if isAnyPvP then
        local allPvPRule = (type(pvpMap) == "table" and pvpMap.all) or (type(zoneMap) == "table" and zoneMap.pvp)
        if type(allPvPRule) == "table" and type(allPvPRule.importString) == "string" and allPvPRule.importString ~= "" then
            local mKey = "pvp:all"
            if not silencedTalentMismatches[mKey] and not silencedTalentMismatches["zone:pvp"]
                and not IsEntryAlreadyActive(self, specID, allPvPRule, allPvPRule.importString, liveStr) then
                local ctxTag = isArena and "Arena" or (isBG and "Battlegrounds" or "War Mode")
                return { id = allPvPRule.loadoutID, name = allPvPRule.loadoutName or "PvP Loadout", importString = allPvPRule.importString, group = allPvPRule.group or "PvP", heroAcronym = allPvPRule.heroAcronym },
                    allPvPRule.loadoutName or "PvP Loadout", "All PvP (" .. ctxTag .. ")", mKey
            end
            return nil
        end
    end

    -- Suppress Outdoor / All Content reminders while resting in a city
    if isOutdoor and isResting then
        self._lastDiag.source = "Resting City"
        self._lastDiag.status = "Suppressed while resting"
        return nil
    end

    if type(zoneMap) == "table" then
        local zRule, zLbl, zMKey = nil, nil, nil
        if isDelveActive and type(zoneMap.delves) == "table" then
            zRule, zLbl, zMKey = zoneMap.delves, "Delves", "zone:delves"
        elseif isOutdoor and type(zoneMap.outdoor) == "table" then
            zRule, zLbl, zMKey = zoneMap.outdoor, "Outdoor", "zone:outdoor"
        end
        if zRule and zRule.importString and zRule.importString ~= "" then
            self._lastDiag.source = "Zone (" .. zLbl .. ")"
            self._lastDiag.ruleDesc = zLbl .. " -> " .. tostring(zRule.loadoutName or (zLbl .. " Loadout"))
            if not silencedTalentMismatches[zMKey] and not IsEntryAlreadyActive(self, specID, zRule, zRule.importString, liveStr) then
                self._lastDiag.status = "Swap recommended"
                return { id = zRule.loadoutID, name = zRule.loadoutName or (zLbl .. " Loadout"), importString = zRule.importString, group = zRule.group or "Custom", heroAcronym = zRule.heroAcronym },
                    zRule.loadoutName or (zLbl .. " Loadout"), zLbl, zMKey
            end
            self._lastDiag.status = silencedTalentMismatches[zMKey] and "Silenced for session" or "Already active"
            return nil
        end

        -- =====================================================================
        -- PRIORITY 3 (Tier 3): Global All Content Default
        -- =====================================================================
        local allRule = zoneMap.all
        if type(allRule) == "table" and allRule.importString and allRule.importString ~= "" then
            local ctxLbl = (isRaid and "Raid")
                or (isParty and "M+")
                or (isDelveActive and "Delves")
                or (isAnyPvP and "PvP")
                or (isOutdoor and "Outdoor")
                or nil
            if ctxLbl then
                local mKey = "zone:all"
                self._lastDiag.source = "All Content"
                self._lastDiag.ruleDesc = ctxLbl .. " (All Content) -> " .. tostring(allRule.loadoutName or "Default Loadout")
                if not silencedTalentMismatches[mKey] and not IsEntryAlreadyActive(self, specID, allRule, allRule.importString, liveStr) then
                    self._lastDiag.status = "Swap recommended"
                    return { id = allRule.loadoutID, name = allRule.loadoutName or "Default Loadout", importString = allRule.importString, group = allRule.group or "Custom", heroAcronym = allRule.heroAcronym },
                        allRule.loadoutName or "Default Loadout", ctxLbl .. " (All Content)", mKey
                end
                self._lastDiag.status = silencedTalentMismatches[mKey] and "Silenced for session" or "Already active"
                return nil
            end
        end
    end

    -- Legacy Zone Default fallback (Blizzard config ID)
    local zKey, zLabel = nil, nil
    if isDelveActive then zKey, zLabel = "delve", "Delve"
    elseif isParty then zKey, zLabel = "dungeon", "M+"
    elseif isRaid then zKey, zLabel = "raid", "Raid"
    elseif isAnyPvP then zKey, zLabel = "pvp", "PvP"
    end
    if zKey then
        local prefID, prefName = self:GetPreferredTalentLoadout(zKey)
        local mKey = "zone:" .. zKey
        if prefID and prefName and not silencedTalentMismatches[mKey] and curID ~= prefID then
            return prefID, prefName, zLabel, mKey
        end
    end
    return nil
end

-- ============================================================================
-- 4. IMPORTERS, HERO TALENT ACRONYMS & SORTING
-- ============================================================================
function DynamicTalent:ImportFromTalentLoadoutManager()
    if not self.db then self:InitDB() end
    local api = _G.TalentLoadoutManagerAPI
    if type(api) ~= "table" or type(api.GlobalAPI) ~= "table" or type(api.GlobalAPI.GetLoadouts) ~= "function" then
        Print("TalentLoadoutManager is not currently loaded.")
        return 0
    end
    local specID = self:GetActiveSpecID()
    if not specID then return 0 end
    local okL, list = pcall(api.GlobalAPI.GetLoadouts, api.GlobalAPI, specID)
    if not okL or type(list) ~= "table" then return 0 end

    self.db.talentStringLibrary = self.db.talentStringLibrary or {}
    self.db.talentStringLibrary[specID] = self.db.talentStringLibrary[specID] or {}
    local lib = self.db.talentStringLibrary[specID]
    local imported = 0
    for _, lo in ipairs(list) do
        if type(lo) == "table" and lo.id and type(lo.name) == "string" and lo.name ~= "" and lo.name ~= "TalentLoadoutManager" then
            local expStr = nil
            if type(api.GlobalAPI.GetExportString) == "function" then
                local okE, s = pcall(api.GlobalAPI.GetExportString, api.GlobalAPI, lo.id)
                if okE and type(s) == "string" and s ~= "" then expStr = s end
            end
            if expStr then
                local newGrp = CategoriseTalentGroup(lo.name)
                local newHero = self:DetectHeroTreeFromString(expStr)
                local found = false
                for _, ex in ipairs(lib) do
                    local exGrp = NormalizeTalentGroupKey(ex.group or CategoriseTalentGroup(ex.name))
                    if ex.importString == expStr or (ex.name:lower() == lo.name:lower() and exGrp == newGrp and (ex.heroAcronym or "") == (newHero or "")) then
                        EnsureEntryID(ex, self.db)
                        ex.importString = expStr
                        ex.group = exGrp
                        ex._heroStrHash = nil
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(lib, {
                        id           = GenerateLoadoutID(self.db),
                        name         = lo.name,
                        group        = newGrp,
                        importString = expStr,
                    })
                end
                imported = imported + 1
            end
        end
    end
    for _, entry in ipairs(lib) do
        self:RefreshLoadoutHeroMeta(entry)
    end
    Print(string.format("Imported |cFF10B981%d|r Talent Loadout(s) from TalentLoadoutManager for your active specialisation.", imported))
    self:SyncTalentBindsUI()
    return imported
end

function DynamicTalent:GetSuggestedCurrentBuildName(specID)
    local sid = specID or self:GetActiveSpecID()
    if sid and C_ClassTalents and type(C_ClassTalents.GetLastSelectedSavedConfigID) == "function"
        and C_Traits and type(C_Traits.GetConfigInfo) == "function" then
        local okC, cid = pcall(C_ClassTalents.GetLastSelectedSavedConfigID, sid)
        if okC and not _IsSecret(cid) and type(cid) == "number" and cid > 0 then
            local okI, info = pcall(C_Traits.GetConfigInfo, cid)
            if okI and type(info) == "table" and not _IsSecret(info.name) and type(info.name) == "string" then
                local nm = SafeTrim(info.name)
                local low = nm:lower()
                if nm ~= "" and low ~= "dynamicprep" and low ~= "dynamictalent" and low ~= "talentloadoutmanager" then
                    return nm
                end
            end
        end
    end
    local getSpecFn = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or _G.GetSpecialization
    local getSpecInfoFn = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or _G.GetSpecializationInfo
    if type(getSpecFn) == "function" and type(getSpecInfoFn) == "function" then
        local okIdx, idx = pcall(getSpecFn)
        if okIdx and not _IsSecret(idx) and type(idx) == "number" and idx >= 1 and idx <= 4 then
            local okInfo, _, specName = pcall(getSpecInfoFn, idx)
            if okInfo and type(specName) == "string" and not _IsSecret(specName) then
                specName = SafeTrim(specName)
                if specName ~= "" then
                    return specName .. " Build"
                end
            end
        end
    end
    return "Current Build"
end

function DynamicTalent:ImportBlizzardLoadouts(specID)
    if not self.db then self:InitDB() end
    local sid = specID or self:GetActiveSpecID()
    if not sid then return 0, 0, nil end
    if not (C_ClassTalents and type(C_ClassTalents.GetConfigIDsBySpecID) == "function"
        and C_Traits and type(C_Traits.GetConfigInfo) == "function"
        and type(C_Traits.GenerateImportString) == "function") then
        return 0, 0, nil
    end
    local okIDs, ids = pcall(C_ClassTalents.GetConfigIDsBySpecID, sid)
    if not okIDs or type(ids) ~= "table" then return 0, 0, nil end

    self.db.talentStringLibrary = self.db.talentStringLibrary or {}
    self.db.talentStringLibrary[sid] = self.db.talentStringLibrary[sid] or {}
    local lib = self.db.talentStringLibrary[sid]

    local existingKeys, existingStrs = {}, {}
    for _, ex in ipairs(lib) do
        if type(ex) == "table" then
            EnsureEntryID(ex, self.db)
            if type(ex.name) == "string" and ex.name ~= "" then
                self:RefreshLoadoutHeroMeta(ex)
                local grp = NormalizeTalentGroupKey(ex.group or CategoriseTalentGroup(ex.name))
                existingKeys[ex.name:lower() .. "|" .. grp .. "|" .. tostring(ex.heroAcronym or "")] = true
            end
            if type(ex.importString) == "string" and ex.importString ~= "" then
                existingStrs[ex.importString] = true
            end
        end
    end

    local liveStr = self:GetActiveTalentString()
    local imported, skipped, firstImported = 0, 0, nil
    for _, cid in ipairs(ids) do
        if not _IsSecret(cid) and type(cid) == "number" then
        local okI, info = pcall(C_Traits.GetConfigInfo, cid)
        if okI and type(info) == "table" and not _IsSecret(info.name) and type(info.name) == "string" then
            local cleanName = SafeTrim(info.name)
            local low = cleanName:lower()
            if cleanName ~= "" and low ~= "dynamicprep" and low ~= "dynamictalent" and low ~= "talentloadoutmanager" then
                local okS, expStr = pcall(C_Traits.GenerateImportString, cid)
                if okS and type(expStr) == "string" and not _IsSecret(expStr) then
                    expStr = SafeTrim(expStr)
                    if expStr ~= "" and self:DecodeTalentImportString(expStr) then
                        local grp = CategoriseTalentGroup(cleanName)
                        local hAcr = self:DetectHeroTreeFromString(expStr, (liveStr and liveStr == expStr) and liveStr or nil)
                        local sig = low .. "|" .. grp .. "|" .. tostring(hAcr or "")
                        if existingStrs[expStr] or existingKeys[sig] then
                            skipped = skipped + 1
                        else
                            local entry = {
                                id           = GenerateLoadoutID(self.db),
                                name         = cleanName,
                                group        = grp,
                                importString = expStr,
                                liveHash     = (liveStr and liveStr == expStr) and liveStr or nil,
                            }
                            table.insert(lib, entry)
                            self:RefreshLoadoutHeroMeta(entry)
                            existingKeys[sig] = true
                            existingStrs[expStr] = true
                            if not firstImported then firstImported = entry end
                            imported = imported + 1
                        end
                    end
                end
            end
        end
        end
    end

    if imported > 0 then
        Print(string.format("Imported |cFF10B981%d|r Blizzard talent loadout(s) into your active specialisation library.", imported))
        self:SyncTalentBindsUI()
    end
    return imported, skipped, firstImported
end

do
    local HERO_TALENT_ACRONYMS = {
        ["deathbringer"]               = "DB",
        ["rider of the apocalypse"]    = "RA",
        ["san'layn"]                   = "SL",
        ["sanlayn"]                    = "SL",
        ["aldrachi reaver"]            = "AR",
        ["scarred"]                    = "SC",
        ["fel-scarred"]                = "SC",
        ["felscarred"]                 = "SC",
        ["void-scarred"]               = "SC",
        ["voidscarred"]                = "SC",
        ["annihilator"]                = "AN",
        ["druid of the claw"]          = "DC",
        ["elune's chosen"]             = "EC",
        ["elunes chosen"]              = "EC",
        ["keeper of the grove"]        = "KG",
        ["wildstalker"]                = "WS",
        ["chronowarden"]               = "CW",
        ["flameshaper"]                = "FS",
        ["scalecommander"]             = "SC",
        ["dark ranger"]                = "DR",
        ["pack leader"]                = "PL",
        ["sentinel"]                   = "SN",
        ["frostfire"]                  = "FF",
        ["spellslinger"]               = "SS",
        ["sunfury"]                    = "SF",
        ["conduit of the celestials"]  = "CC",
        ["master of harmony"]          = "MH",
        ["shado-pan"]                  = "SP",
        ["shadopan"]                   = "SP",
        ["herald of the sun"]          = "HS",
        ["lightsmith"]                 = "LS",
        ["templar"]                    = "TP",
        ["archon"]                     = "AR",
        ["oracle"]                     = "OR",
        ["voidweaver"]                 = "VW",
        ["deathstalker"]               = "DS",
        ["fatebound"]                  = "FB",
        ["trickster"]                  = "TR",
        ["farseer"]                    = "FS",
        ["stormbringer"]               = "SB",
        ["totemic"]                    = "TT",
        ["diabolist"]                  = "DB",
        ["hellcaller"]                 = "HC",
        ["soul harvester"]             = "SH",
        ["colossus"]                   = "CL",
        ["mountain thane"]             = "MT",
        ["slayer"]                     = "SL",
    }
    DynamicTalent.HERO_TALENT_ACRONYMS = HERO_TALENT_ACRONYMS

    local STOP_WORDS = { of = true, the = true, ["and"] = true, ["in"] = true, a = true, an = true }

    function DynamicTalent:MapHeroTreeAcronym(treeName)
        if type(treeName) ~= "string" or _IsSecret(treeName) then return nil end
        local low = SafeTrim(treeName):lower()
        if low == "" then return nil end
        local direct = HERO_TALENT_ACRONYMS[low] or HERO_TALENT_ACRONYMS[low:gsub("['`]", "")]
        if direct then return direct end
        local cleaned = low:gsub("['`]", ""):gsub("%-", " "):gsub("[^%a%s]", " ")
        local words = {}
        for w in cleaned:gmatch("%a+") do
            if not STOP_WORDS[w] then
                table.insert(words, w)
            end
        end
        if #words >= 2 then
            return (words[1]:sub(1, 1) .. words[2]:sub(1, 1)):upper()
        elseif #words == 1 and #words[1] >= 2 then
            return words[1]:sub(1, 2):upper()
        end
        local alphaOnly = cleaned:gsub("%s+", "")
        if #alphaOnly >= 2 then
            return alphaOnly:sub(1, 2):upper()
        end
        return nil
    end

    function DynamicTalent:GetLiveHeroTreeInfo()
        if not (C_ClassTalents and type(C_ClassTalents.GetActiveHeroTalentSpec) == "function") then
            return nil, nil
        end
        local okH, heroSubTreeID = pcall(C_ClassTalents.GetActiveHeroTalentSpec)
        if not okH or _IsSecret(heroSubTreeID) or type(heroSubTreeID) ~= "number" or heroSubTreeID <= 0 then
            return nil, nil
        end
        local cfgID = nil
        if type(C_ClassTalents.GetActiveConfigID) == "function" then
            local okCfg, rawCfg = pcall(C_ClassTalents.GetActiveConfigID)
            if okCfg and not _IsSecret(rawCfg) and type(rawCfg) == "number" and rawCfg > 0 then
                cfgID = rawCfg
            end
        end
        if not cfgID or not (C_Traits and type(C_Traits.GetSubTreeInfo) == "function") then
            return nil, nil
        end
        local okS, subInfo = pcall(C_Traits.GetSubTreeInfo, cfgID, heroSubTreeID)
        if okS and type(subInfo) == "table" and type(subInfo.name) == "string" and not _IsSecret(subInfo.name) and subInfo.name ~= "" then
            return self:MapHeroTreeAcronym(subInfo.name), subInfo.name
        end
        return nil, nil
    end

    function DynamicTalent:DetectHeroTreeFromString(importString, liveHashOpt)
        if type(importString) ~= "string" or importString == "" then return nil, nil end
        self._heroTreeCache = self._heroTreeCache or {}
        local cached = self._heroTreeCache[importString]
        if cached ~= nil then
            return cached.acr or nil, cached.name
        end

        local decoded = self:DecodeTalentImportString(importString)
        if decoded and type(decoded.entries) == "table" and C_Traits and type(C_Traits.GetNodeInfo) == "function" then
            local cfgID = decoded.configID
            local subTreeEnum = (_G.Enum and _G.Enum.TraitNodeType and _G.Enum.TraitNodeType.SubTreeSelection) or 3
            local detectedSubTreeID = nil

            for _, ne in ipairs(decoded.entries) do
                local okN, info = pcall(C_Traits.GetNodeInfo, cfgID, ne.nodeID)
                if okN and type(info) == "table" and not _IsSecret(info.type) and info.type == subTreeEnum then
                    local eID = info.entryIDs and (info.entryIDs[ne.choiceIdx] or info.entryIDs[1]) or nil
                    if eID and not _IsSecret(eID) and type(C_Traits.GetEntryInfo) == "function" then
                        local okE, eInfo = pcall(C_Traits.GetEntryInfo, cfgID, eID)
                        if okE and type(eInfo) == "table" and not _IsSecret(eInfo.subTreeID) and type(eInfo.subTreeID) == "number" and eInfo.subTreeID > 0 then
                            detectedSubTreeID = eInfo.subTreeID
                            break
                        end
                    end
                    if not _IsSecret(info.subTreeID) and type(info.subTreeID) == "number" and info.subTreeID > 0 then
                        detectedSubTreeID = info.subTreeID
                        break
                    end
                end
            end

            if not detectedSubTreeID then
                for _, ne in ipairs(decoded.entries) do
                    local okN, info = pcall(C_Traits.GetNodeInfo, cfgID, ne.nodeID)
                    if okN and type(info) == "table" and not _IsSecret(info.subTreeID) and type(info.subTreeID) == "number" and info.subTreeID > 0 then
                        detectedSubTreeID = info.subTreeID
                        break
                    end
                end
            end

            if detectedSubTreeID and type(C_Traits.GetSubTreeInfo) == "function" then
                local okS, subInfo = pcall(C_Traits.GetSubTreeInfo, cfgID, detectedSubTreeID)
                if okS and type(subInfo) == "table" and type(subInfo.name) == "string" and not _IsSecret(subInfo.name) and subInfo.name ~= "" then
                    local acr = self:MapHeroTreeAcronym(subInfo.name)
                    if acr then
                        self._heroTreeCache[importString] = { acr = acr, name = subInfo.name }
                        return acr, subInfo.name
                    end
                end
            end
        end

        local liveStr = self:GetActiveTalentString()
        if liveStr and (importString == liveStr or (liveHashOpt and liveHashOpt == liveStr)) then
            local liveAcr, liveName = self:GetLiveHeroTreeInfo()
            if liveAcr then
                self._heroTreeCache[importString] = { acr = liveAcr, name = liveName }
                return liveAcr, liveName
            end
        end

        if decoded then
            self._heroTreeCache[importString] = { acr = false, name = nil }
        end
        return nil, nil
    end

    function DynamicTalent:RefreshLoadoutHeroMeta(entry)
        if type(entry) ~= "table" or type(entry.importString) ~= "string" or entry.importString == "" then
            return nil, nil
        end
        if entry._heroStrHash == entry.importString and entry.heroAcronym then
            return entry.heroAcronym, entry.heroTreeName
        end
        local acr, treeName = self:DetectHeroTreeFromString(entry.importString, entry.liveHash)
        if acr then
            entry.heroAcronym = acr
            entry.heroTreeName = treeName
            entry._heroStrHash = entry.importString
        elseif entry._heroStrHash ~= entry.importString then
            entry.heroAcronym = nil
            entry.heroTreeName = nil
            entry._heroStrHash = nil
        end
        return acr, treeName
    end

    function DynamicTalent:GetLoadoutHeroAcronym(entry)
        if type(entry) ~= "table" then return nil, nil end
        return self:RefreshLoadoutHeroMeta(entry)
    end

    function DynamicTalent:FindLibraryEntryByID(loadoutID, specID)
        if type(loadoutID) ~= "string" or loadoutID == "" or not self.db then return nil end
        local sid = specID or self:GetActiveSpecID()
        local lib = sid and self.db.talentStringLibrary and self.db.talentStringLibrary[sid]
        if type(lib) ~= "table" then return nil end
        for _, it in ipairs(lib) do
            if type(it) == "table" and it.id == loadoutID then
                return it
            end
        end
        return nil
    end

    function DynamicTalent:FindLibraryEntryForRule(rule, specID)
        if type(rule) ~= "table" or not self.db then return nil end
        local sid = specID or self:GetActiveSpecID()
        local lib = sid and self.db.talentStringLibrary and self.db.talentStringLibrary[sid]
        if type(lib) ~= "table" then return nil end
        if type(rule.loadoutID) == "string" and rule.loadoutID ~= "" then
            local byId = self:FindLibraryEntryByID(rule.loadoutID, sid)
            if byId then return byId end
        end
        for _, it in ipairs(lib) do
            if type(it) == "table" and DoesRuleMatchEntry(rule, it) then
                return it
            end
        end
        return nil
    end

    function DynamicTalent:FindLibraryEntryByName(loadoutName, specID)
        if type(loadoutName) ~= "string" or loadoutName == "" or not self.db then return nil end
        local sid = specID or self:GetActiveSpecID()
        local lib = sid and self.db.talentStringLibrary and self.db.talentStringLibrary[sid]
        if type(lib) ~= "table" then return nil end
        local low = loadoutName:lower()
        for _, it in ipairs(lib) do
            if type(it) == "table" and type(it.name) == "string" and it.name:lower() == low then
                return it
            end
        end
        return nil
    end

    function DynamicTalent:FormatTalentBadge(entryOrGroup, heroAcronymOpt)
        local grp = "Custom"
        local hero = heroAcronymOpt
        if type(entryOrGroup) == "table" then
            grp = NormalizeTalentGroupKey(entryOrGroup.group or "Custom")
            if not hero or hero == "" then
                hero = self:GetLoadoutHeroAcronym(entryOrGroup)
            end
            if (not hero or hero == "") and (entryOrGroup.loadoutID or entryOrGroup.loadoutName) then
                local libEntry = self:FindLibraryEntryForRule(entryOrGroup)
                if not libEntry and entryOrGroup.loadoutName then
                    libEntry = self:FindLibraryEntryByName(entryOrGroup.loadoutName)
                end
                if libEntry then
                    hero = self:GetLoadoutHeroAcronym(libEntry)
                end
            end
        elseif type(entryOrGroup) == "string" and entryOrGroup ~= "" then
            grp = NormalizeTalentGroupKey(entryOrGroup)
        end
        local gHex = TALENT_GROUP_HEX[grp] or "94A3B8"
        if type(hero) == "string" and hero ~= "" then
            return string.format("|cFF%s[%s|r|cFF64748B-|r|cFFE2E8F0%s|r|cFF%s]|r", gHex, grp, hero, gHex)
        end
        return string.format("|cFF%s[%s]|r", gHex, grp)
    end
end

function DynamicTalent:GetSortedTalentProfiles(specID, useZoneFirst)
    if not self.db then self:InitDB() end
    local sid = specID or self:GetActiveSpecID()
    local lib = (sid and self.db and self.db.talentStringLibrary and self.db.talentStringLibrary[sid]) or {}
    local out = {}
    for _, entry in ipairs(lib) do
        if type(entry) == "table" and type(entry.name) == "string" and entry.name ~= "" then
            entry.group = NormalizeTalentGroupKey((type(entry.group) == "string" and entry.group ~= "") and entry.group or CategoriseTalentGroup(entry.name))
            self:RefreshLoadoutHeroMeta(entry)
            table.insert(out, entry)
        end
    end

    local orderList = SanitizeGroupOrder(self.db and self.db.talentGroupOrder)
    local groupRank = {}
    for idx, g in ipairs(orderList) do
        groupRank[g] = idx
    end

    local activeZoneGrp = nil
    if useZoneFirst == true and self.db and self.db.prioritiseCurrentZone == true then
        activeZoneGrp = self:GetActiveContentGroup()
    end

    table.sort(out, function(a, b)
        local ga = NormalizeTalentGroupKey(a.group or "Custom")
        local gb = NormalizeTalentGroupKey(b.group or "Custom")
        if activeZoneGrp then
            local aMatch = (ga == activeZoneGrp)
            local bMatch = (gb == activeZoneGrp)
            if aMatch ~= bMatch then return aMatch end
        end

        local ra = groupRank[ga] or 99
        local rb = groupRank[gb] or 99
        if ra ~= rb then return ra < rb end

        local ha = (type(a.heroAcronym) == "string" and a.heroAcronym ~= "") and a.heroAcronym or nil
        local hb = (type(b.heroAcronym) == "string" and b.heroAcronym ~= "") and b.heroAcronym or nil
        if ha ~= hb then
            if not ha then return false end
            if not hb then return true end
            local hal, hbl = ha:lower(), hb:lower()
            if hal ~= hbl then return hal < hbl end
        end

        local na = tostring(a.name or "")
        local nb = tostring(b.name or "")
        local nal, nbl = na:lower(), nb:lower()
        if nal ~= nbl then return nal < nbl end
        return na < nb
    end)
    return out
end

-- ============================================================================
-- 5. LIBRARY MUTATORS, PVP/ZONE/BOSS BINDERS & CONFLICT ENGINE
-- ============================================================================
function DynamicTalent:HasLegacyTLMSlot()
    local specID = self:GetActiveSpecID()
    if not specID or not (C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID and C_Traits and C_Traits.GetConfigInfo) then
        return false
    end
    local ok, ids = pcall(C_ClassTalents.GetConfigIDsBySpecID, specID)
    if not ok or type(ids) ~= "table" then return false end
    for _, cid in ipairs(ids) do
        if not _IsSecret(cid) and type(cid) == "number" and cid > 0 then
            local okI, info = pcall(C_Traits.GetConfigInfo, cid)
            if okI and not _IsSecret(info) and type(info) == "table" and not _IsSecret(info.name) and info.name == "TalentLoadoutManager" then
                return true
            end
        end
    end
    return false
end

function DynamicTalent:GetActiveTalentLibraryEntry(specID)
    local sid = specID or self:GetActiveSpecID()
    if not sid or not self.db then return nil end
    local lib = (self.db.talentStringLibrary and self.db.talentStringLibrary[sid]) or {}
    if #lib == 0 then return nil end

    if self._pendingAppliedEntry and self._pendingAppliedSpecID == sid then
        for _, entry in ipairs(lib) do
            if entry == self._pendingAppliedEntry then
                return entry
            end
        end
    end

    local liveStr = self:GetActiveTalentString()
    local lastAppliedID = self.db.lastAppliedTalentID and self.db.lastAppliedTalentID[sid]
    local lastApplied = self.db.lastAppliedTalentName and self.db.lastAppliedTalentName[sid]
    local lastLiveStr = self.db.lastAppliedTalentLiveStr and self.db.lastAppliedTalentLiveStr[sid]

    if type(lastAppliedID) == "string" and lastAppliedID ~= "" then
        for _, entry in ipairs(lib) do
            if entry.id == lastAppliedID then
                if not liveStr
                    or entry.importString == liveStr
                    or (entry.liveHash and entry.liveHash == liveStr)
                    or (lastLiveStr and lastLiveStr == liveStr) then
                    return entry
                end
            end
        end
    end

    if type(lastApplied) == "string" and lastApplied ~= "" then
        if liveStr then
            for _, entry in ipairs(lib) do
                if entry.name == lastApplied and (entry.importString == liveStr or (entry.liveHash and entry.liveHash == liveStr)) then
                    return entry
                end
            end
        end
        for _, entry in ipairs(lib) do
            if entry.name == lastApplied then
                if not liveStr or (lastLiveStr and lastLiveStr == liveStr) then
                    return entry
                end
            end
        end
    end

    if liveStr then
        for _, entry in ipairs(lib) do
            if entry.importString == liveStr or (entry.liveHash and entry.liveHash == liveStr) then
                return entry
            end
        end
    end

    return nil
end

local activeEmbeddedRoot = nil

function DynamicTalent:SyncTalentBindsUI(clearStickyBoss)
    if clearStickyBoss == true then
        stickyRaidBoss = nil
    end
    if _G.DynamicPrep then
        if type(_G.DynamicPrep.ResetStableCapsuleWidths) == "function" then
            pcall(_G.DynamicPrep.ResetStableCapsuleWidths, _G.DynamicPrep)
        end
        if type(_G.DynamicPrep.RefreshBar) == "function" then
            pcall(_G.DynamicPrep.RefreshBar, _G.DynamicPrep)
        end
    end
    if self.RefreshTalentDock then self:RefreshTalentDock() end
    if talentMgrModal and talentMgrModal:IsShown() and talentMgrModal.RefreshBossList then
        talentMgrModal:RefreshBossList()
    end
    if activeEmbeddedRoot and activeEmbeddedRoot:IsShown() and activeEmbeddedRoot.RefreshActionStrip then
        activeEmbeddedRoot:RefreshActionStrip()
    end
end

function DynamicTalent:UpdateTalentLibraryEntry(targetEntry, newName, newGroup, newImportString)
    if not self.db then self:InitDB() end
    local specID = self:GetActiveSpecID()
    if not specID or type(targetEntry) ~= "table" then
        return false, "No active loadout selected."
    end
    local cleanName = SafeTrim(tostring(newName or ""))
    local cleanStr = SafeTrim(tostring(newImportString or ""))
    if cleanName == "" or cleanStr == "" then
        return false, "Enter both a loadout name and a valid talent string."
    end
    local decoded, errMsg = self:DecodeTalentImportString(cleanStr)
    if not decoded then
        return false, errMsg or "Invalid talent export string."
    end

    local targetID = EnsureEntryID(targetEntry, self.db)
    local oldName = targetEntry.name
    local matchSnapshot = {
        id           = targetID,
        name         = oldName,
        group        = targetEntry.group,
        importString = targetEntry.importString,
        liveHash     = targetEntry.liveHash,
    }
    local grp = NormalizeTalentGroupKey((type(newGroup) == "string" and newGroup ~= "") and newGroup or (targetEntry.group or CategoriseTalentGroup(cleanName)))
    local strChanged = (targetEntry.importString ~= cleanStr)

    targetEntry.name = cleanName
    targetEntry.group = grp
    targetEntry.importString = cleanStr
    if strChanged then
        local liveStr = self:GetActiveTalentString()
        targetEntry.liveHash = (liveStr and liveStr == cleanStr) and liveStr or nil
        targetEntry._heroStrHash = nil
    end
    self:RefreshLoadoutHeroMeta(targetEntry)

    local isLastApplied = (self.db.lastAppliedTalentID and self.db.lastAppliedTalentID[specID] == targetID)
        or ((not self.db.lastAppliedTalentID or not self.db.lastAppliedTalentID[specID]) and self.db.lastAppliedTalentName and self.db.lastAppliedTalentName[specID] == oldName)
    if isLastApplied then
        self.db.lastAppliedTalentID = self.db.lastAppliedTalentID or {}
        self.db.lastAppliedTalentID[specID] = targetID
        self.db.lastAppliedTalentName = self.db.lastAppliedTalentName or {}
        self.db.lastAppliedTalentName[specID] = cleanName
    end
    local function UpdateMapRows(tbl)
        if type(tbl) ~= "table" then return end
        for _, row in pairs(tbl) do
            if type(row) == "table" and DoesRuleMatchEntry(row, matchSnapshot) then
                row.loadoutID = targetID
                row.loadoutName = cleanName
                row.importString = cleanStr
                row.group = grp
                row.heroAcronym = targetEntry.heroAcronym
            end
        end
    end
    UpdateMapRows(self.db.talentBossMap and self.db.talentBossMap[specID])
    UpdateMapRows(self.db.talentDungeonMap and self.db.talentDungeonMap[specID])
    UpdateMapRows(self.db.talentPvPMap and self.db.talentPvPMap[specID])
    UpdateMapRows(self.db.talentZoneMap and self.db.talentZoneMap[specID])

    Print(string.format("Updated loadout %s |cFFFFFFFF%s|r.", self:FormatTalentBadge(targetEntry), cleanName))
    self:SyncTalentBindsUI(true)
    return true, "Saved changes to '" .. cleanName .. "'."
end

function DynamicTalent:SaveCurrentTreeOverEntry(targetEntry)
    if not self.db then self:InitDB() end
    local specID = self:GetActiveSpecID()
    if not specID or type(targetEntry) ~= "table" then return false end
    self:InvalidateActiveTalentStringCache()
    local liveStr = self:GetActiveTalentString(true)
    if not liveStr or liveStr == "" then
        Print("Could not read your active talent tree.")
        return false
    end
    local targetID = EnsureEntryID(targetEntry, self.db)
    local matchSnapshot = {
        id           = targetID,
        name         = targetEntry.name,
        group        = targetEntry.group,
        importString = targetEntry.importString,
        liveHash     = targetEntry.liveHash,
    }
    targetEntry.importString = liveStr
    targetEntry.liveHash = liveStr
    targetEntry._heroStrHash = nil
    self:RefreshLoadoutHeroMeta(targetEntry)
    self.db.lastAppliedTalentID = self.db.lastAppliedTalentID or {}
    self.db.lastAppliedTalentID[specID] = targetID
    self.db.lastAppliedTalentName = self.db.lastAppliedTalentName or {}
    self.db.lastAppliedTalentName[specID] = targetEntry.name
    self.db.lastAppliedTalentLiveStr = self.db.lastAppliedTalentLiveStr or {}
    self.db.lastAppliedTalentLiveStr[specID] = liveStr

    local function UpdateTreeRows(tbl)
        if type(tbl) ~= "table" then return end
        for _, row in pairs(tbl) do
            if type(row) == "table" and DoesRuleMatchEntry(row, matchSnapshot) then
                row.loadoutID = targetID
                row.importString = liveStr
                row.heroAcronym = targetEntry.heroAcronym
            end
        end
    end
    UpdateTreeRows(self.db.talentBossMap and self.db.talentBossMap[specID])
    UpdateTreeRows(self.db.talentDungeonMap and self.db.talentDungeonMap[specID])
    UpdateTreeRows(self.db.talentPvPMap and self.db.talentPvPMap[specID])
    UpdateTreeRows(self.db.talentZoneMap and self.db.talentZoneMap[specID])

    Print(string.format("Saved current talents over %s |cFFFFFFFF%s|r.", self:FormatTalentBadge(targetEntry), tostring(targetEntry.name or "Loadout")))
    self:SyncTalentBindsUI(true)
    return true
end

function DynamicTalent:DeleteTalentLibraryEntry(targetEntry)
    local specID = self:GetActiveSpecID()
    if not specID or type(targetEntry) ~= "table" then return end
    local targetID = EnsureEntryID(targetEntry, self.db)
    local rawLib = (self.db and self.db.talentStringLibrary and self.db.talentStringLibrary[specID]) or {}
    for ri = #rawLib, 1, -1 do
        if rawLib[ri] == targetEntry then
            table.remove(rawLib, ri)
            break
        end
    end
    local wasLast = self.db and (
        (self.db.lastAppliedTalentID and self.db.lastAppliedTalentID[specID] == targetID)
        or ((not self.db.lastAppliedTalentID or not self.db.lastAppliedTalentID[specID])
            and self.db.lastAppliedTalentName and self.db.lastAppliedTalentName[specID] == targetEntry.name)
    )
    if wasLast then
        if self.db.lastAppliedTalentID then self.db.lastAppliedTalentID[specID] = nil end
        if self.db.lastAppliedTalentName then self.db.lastAppliedTalentName[specID] = nil end
    end
    local function ClearMapRows(tbl)
        if type(tbl) ~= "table" then return end
        for k, row in pairs(tbl) do
            if type(row) == "table" and DoesRuleMatchEntry(row, targetEntry) then
                tbl[k] = nil
            end
        end
    end
    ClearMapRows(self.db and self.db.talentBossMap and self.db.talentBossMap[specID])
    ClearMapRows(self.db and self.db.talentDungeonMap and self.db.talentDungeonMap[specID])
    ClearMapRows(self.db and self.db.talentPvPMap and self.db.talentPvPMap[specID])
    ClearMapRows(self.db and self.db.talentZoneMap and self.db.talentZoneMap[specID])

    Print("Deleted loadout |cFFF43F5E" .. tostring(targetEntry.name) .. "|r.")
    if talentMgrModal and talentMgrModal:IsShown() then
        if talentMgrModal.state and talentMgrModal.state.selectedEntry == targetEntry and talentMgrModal.SelectLoadout then
            talentMgrModal:SelectLoadout(nil, true)
        elseif talentMgrModal.editingEntry == targetEntry and talentMgrModal.LoadEditorEntry then
            talentMgrModal:LoadEditorEntry(nil, true)
        end
    end
    self:SyncTalentBindsUI(true)
end

function DynamicTalent:SetAllRaidDefault(entry, diffs, silent)
    if not self.db then self:InitDB() end
    local specID = self:GetActiveSpecID()
    if not specID or type(entry) ~= "table" then return false end
    self:RefreshLoadoutHeroMeta(entry)
    local d = type(diffs) == "table" and diffs or { normal = true, heroic = true, mythic = true }
    local useN = (d.normal == true)
    local useH = (d.heroic == true)
    local useM = (d.mythic == true)
    if not (useN or useH or useM) then
        useN, useH, useM = true, true, true
    end
    local mask = (useN and "N" or "") .. (useH and "H" or "") .. (useM and "M" or "")
    local mapKey = "__all_raid__|" .. mask
    self.db.talentBossMap = self.db.talentBossMap or {}
    self.db.talentBossMap[specID] = self.db.talentBossMap[specID] or {}
    local bMap = self.db.talentBossMap[specID]
    for exK, exV in pairs(bMap) do
        if type(exV) == "table" and exV.isAllRaid == true and exK ~= mapKey then
            if type(exV.difficulties) == "table" then
                if useN then exV.difficulties.normal = false end
                if useH then exV.difficulties.heroic = false end
                if useM then exV.difficulties.mythic = false end
                if not (exV.difficulties.normal or exV.difficulties.heroic or exV.difficulties.mythic) then
                    bMap[exK] = nil
                end
            else
                bMap[exK] = nil
            end
        end
    end
    local eid = EnsureEntryID(entry, self.db)
    bMap[mapKey] = {
        isAllRaid    = true,
        bossName     = "All Raids",
        raidName     = "All Raids",
        raidShort    = "All Raids",
        loadoutID    = eid,
        loadoutName  = entry.name,
        importString = entry.importString,
        group        = entry.group or "Raid",
        heroAcronym  = entry.heroAcronym,
        difficulties = { normal = useN, heroic = useH, mythic = useM },
    }
    if not silent then
        local dLabels = {}
        if useN then table.insert(dLabels, "LFR/N") end
        if useH then table.insert(dLabels, "H") end
        if useM then table.insert(dLabels, "M") end
        Print(string.format("Set |cFFFBBF24All Raids|r [%s] -> %s |cFFFFFFFF%s|r (specific boss binds take priority).", table.concat(dLabels, "/"), self:FormatTalentBadge(entry), tostring(entry.name)))
    end
    self:SyncTalentBindsUI(true)
    return true
end

function DynamicTalent:ClearRaidBinds(isAllRaid, bossNames, diffs)
    if not self.db then self:InitDB() end
    local specID = self:GetActiveSpecID()
    if not specID then return 0 end
    local bMap = self.db.talentBossMap and self.db.talentBossMap[specID]
    if type(bMap) ~= "table" then return 0 end
    local d = type(diffs) == "table" and diffs or { normal = true, heroic = true, mythic = true }
    local useN = (d.normal == true)
    local useH = (d.heroic == true)
    local useM = (d.mythic == true)
    if not (useN or useH or useM) then
        useN, useH, useM = true, true, true
    end
    local targetSet = {}
    if not isAllRaid then
        if type(bossNames) == "string" then
            targetSet[bossNames:lower()] = true
        elseif type(bossNames) == "table" then
            for _, bn in ipairs(bossNames) do
                if type(bn) == "string" and bn ~= "" then
                    targetSet[bn:lower()] = true
                end
            end
        end
    end
    local removed = 0
    for k, v in pairs(bMap) do
        if type(v) == "table" then
            local matches = false
            if isAllRaid then
                matches = (v.isAllRaid == true)
            else
                local bn = tostring(v.bossName or ""):lower()
                matches = (v.isAllRaid ~= true) and (targetSet[bn] == true)
            end
            if matches then
                if type(v.difficulties) == "table" then
                    local changed = false
                    if useN and v.difficulties.normal then v.difficulties.normal = false; changed = true end
                    if useH and v.difficulties.heroic then v.difficulties.heroic = false; changed = true end
                    if useM and v.difficulties.mythic then v.difficulties.mythic = false; changed = true end
                    if changed then
                        removed = removed + 1
                        if not (v.difficulties.normal or v.difficulties.heroic or v.difficulties.mythic) then
                            bMap[k] = nil
                        end
                    end
                else
                    bMap[k] = nil
                    removed = removed + 1
                end
            end
        end
    end
    if removed > 0 then
        self:SyncTalentBindsUI(true)
    end
    return removed
end

function DynamicTalent:SetAllMPlusDefault(entry, keyTier, silent)
    if not self.db then self:InitDB() end
    local specID = self:GetActiveSpecID()
    if not specID or type(entry) ~= "table" then return false end
    self:RefreshLoadoutHeroMeta(entry)
    local kt = keyTier or "ANY"
    self.db.talentDungeonMap = self.db.talentDungeonMap or {}
    self.db.talentDungeonMap[specID] = self.db.talentDungeonMap[specID] or {}
    local dMap = self.db.talentDungeonMap[specID]
    for exK, exV in pairs(dMap) do
        local exAll = type(exV) == "table" and (exV.isAllMPlus == true or tostring(exV.dungeonName or exK):lower() == "all m+ dungeons")
        if exAll and (exV.keyTier == kt or kt == "ANY" or exV.keyTier == "ANY") then
            dMap[exK] = nil
        end
    end
    local eid = EnsureEntryID(entry, self.db)
    dMap["__all__|" .. kt] = {
        isAllMPlus   = true,
        dungeonName  = "All M+ Dungeons",
        mapID        = 0,
        keyTier      = kt,
        loadoutID    = eid,
        loadoutName  = entry.name,
        importString = entry.importString,
        group        = entry.group or "M+",
        heroAcronym  = entry.heroAcronym,
    }
    if not silent then
        local tLbl = (kt == "HIGH" and "+10+") or (kt == "LOW" and "+2-9") or "Any Key"
        Print(string.format("Set |cFF38BDF8All M+ Dungeons|r [%s] -> %s |cFFFFFFFF%s|r (specific dungeons take priority).", tLbl, self:FormatTalentBadge(entry), tostring(entry.name)))
    end
    self:SyncTalentBindsUI(true)
    return true
end

local PVP_MODE_LABELS = {
    all     = "All PvP",
    arena   = "Arena",
    bg      = "Battlegrounds",
    warmode = "War Mode",
}

function DynamicTalent:SetPvPDefaults(entry, pvpSet, silent)
    if not self.db then self:InitDB() end
    local specID = self:GetActiveSpecID()
    if not specID or type(entry) ~= "table" or type(pvpSet) ~= "table" then return false end
    self:RefreshLoadoutHeroMeta(entry)
    self.db.talentPvPMap = self.db.talentPvPMap or {}
    self.db.talentPvPMap[specID] = self.db.talentPvPMap[specID] or {}
    local pMap = self.db.talentPvPMap[specID]
    local eid = EnsureEntryID(entry, self.db)
    local boundNames = {}
    for _, pk in ipairs({ "all", "arena", "bg", "warmode" }) do
        if pvpSet[pk] then
            pMap[pk] = {
                loadoutID    = eid,
                loadoutName  = entry.name,
                importString = entry.importString,
                group        = entry.group or "PvP",
                heroAcronym  = entry.heroAcronym,
            }
            if pk == "all" and self.db.talentZoneMap and self.db.talentZoneMap[specID] then
                self.db.talentZoneMap[specID].pvp = nil
            end
            table.insert(boundNames, PVP_MODE_LABELS[pk] or pk)
        end
    end
    if #boundNames == 0 then return false end
    if not silent then
        Print(string.format("Bound PvP (%s) -> %s |cFFFFFFFF%s|r.", table.concat(boundNames, ", "), self:FormatTalentBadge(entry), tostring(entry.name)))
    end
    self:SyncTalentBindsUI(true)
    return true
end

function DynamicTalent:ClearPvPDefaults(pvpSet, silent)
    if not self.db then self:InitDB() end
    local specID = self:GetActiveSpecID()
    if not specID or type(pvpSet) ~= "table" then return false end
    local pMap = self.db.talentPvPMap and self.db.talentPvPMap[specID]
    local zMap = self.db.talentZoneMap and self.db.talentZoneMap[specID]
    local cleared = {}
    for _, pk in ipairs({ "all", "arena", "bg", "warmode" }) do
        if pvpSet[pk] then
            local removed = false
            if type(pMap) == "table" and pMap[pk] ~= nil then
                pMap[pk] = nil
                removed = true
            end
            if pk == "all" and type(zMap) == "table" and zMap.pvp ~= nil then
                zMap.pvp = nil
                removed = true
            end
            if removed then
                table.insert(cleared, PVP_MODE_LABELS[pk] or pk)
            end
        end
    end
    if #cleared > 0 then
        if not silent then
            Print(string.format("Cleared PvP bind(s): %s.", table.concat(cleared, ", ")))
        end
        self:SyncTalentBindsUI(true)
        return true
    end
    return false
end

function DynamicTalent:SetAllContentDefault(entry)
    if not self.db then self:InitDB() end
    local specID = self:GetActiveSpecID()
    if not specID or type(entry) ~= "table" then return false end
    self:RefreshLoadoutHeroMeta(entry)
    local eid = EnsureEntryID(entry, self.db)
    self.db.talentZoneMap = self.db.talentZoneMap or {}
    self.db.talentZoneMap[specID] = {}
    self.db.talentZoneMap[specID].all = {
        loadoutID    = eid,
        loadoutName  = entry.name,
        importString = entry.importString,
        group        = entry.group or "Custom",
        heroAcronym  = entry.heroAcronym,
    }
    local bMap = self.db.talentBossMap and self.db.talentBossMap[specID]
    if type(bMap) == "table" then
        for k, v in pairs(bMap) do
            if type(v) == "table" and v.isAllRaid == true then
                bMap[k] = nil
            end
        end
    end
    local dMap = self.db.talentDungeonMap and self.db.talentDungeonMap[specID]
    if type(dMap) == "table" then
        for k, v in pairs(dMap) do
            local isAll = type(v) == "table" and (v.isAllMPlus == true or tostring(v.dungeonName or k):lower() == "all m+ dungeons")
            if isAll then
                dMap[k] = nil
            end
        end
    end
    local pMap = self.db.talentPvPMap and self.db.talentPvPMap[specID]
    if type(pMap) == "table" then
        pMap.all = nil
    end
    Print(string.format("Set |cFF10B981All Content Default|r -> %s |cFFFFFFFF%s|r (specific boss, dungeon, and PvP mode binds take priority).", self:FormatTalentBadge(entry), tostring(entry.name)))
    self:SyncTalentBindsUI(true)
    return true
end

function DynamicTalent:SetZoneDefaults(entry, zoneSet, isAll)
    if not self.db then self:InitDB() end
    local specID = self:GetActiveSpecID()
    if not specID or type(entry) ~= "table" then return false end
    self:RefreshLoadoutHeroMeta(entry)
    if isAll then
        return self:SetAllContentDefault(entry)
    end
    local eid = EnsureEntryID(entry, self.db)
    self.db.talentZoneMap = self.db.talentZoneMap or {}
    self.db.talentZoneMap[specID] = self.db.talentZoneMap[specID] or {}
    local zMap = self.db.talentZoneMap[specID]
    local names = {}
    if zoneSet.outdoor then
        zMap.outdoor = { loadoutID = eid, loadoutName = entry.name, importString = entry.importString, group = entry.group or "Custom", heroAcronym = entry.heroAcronym }
        table.insert(names, "Outdoor")
    end
    if zoneSet.delves then
        zMap.delves = { loadoutID = eid, loadoutName = entry.name, importString = entry.importString, group = entry.group or "Delves", heroAcronym = entry.heroAcronym }
        table.insert(names, "Delves")
    end
    if zoneSet.dungeons then
        self:SetAllMPlusDefault(entry, "ANY", true)
        table.insert(names, "Dungeons")
    end
    if zoneSet.raid then
        self:SetAllRaidDefault(entry, { normal = true, heroic = true, mythic = true }, true)
        table.insert(names, "Raid")
    end
    if zoneSet.pvp then
        self:SetPvPDefaults(entry, { all = true }, true)
        zMap.pvp = nil
        table.insert(names, "PvP")
    end
    if #names == 0 then return false end
    Print(string.format("Bound zones (%s) -> %s |cFFFFFFFF%s|r.", table.concat(names, ", "), self:FormatTalentBadge(entry), tostring(entry.name)))
    self:SyncTalentBindsUI(true)
    return true
end

function DynamicTalent:ClearZoneDefaults(zoneSet, isAll)
    if not self.db then self:InitDB() end
    local specID = self:GetActiveSpecID()
    if not specID then return false end
    local zMap = self.db.talentZoneMap and self.db.talentZoneMap[specID]
    local bMap = self.db.talentBossMap and self.db.talentBossMap[specID]
    local dMap = self.db.talentDungeonMap and self.db.talentDungeonMap[specID]
    local pMap = self.db.talentPvPMap and self.db.talentPvPMap[specID]
    local cleared = {}

    if isAll then
        if type(zMap) == "table" then wipe(zMap) end
        if type(bMap) == "table" then
            for k, v in pairs(bMap) do
                if type(v) == "table" and v.isAllRaid == true then bMap[k] = nil end
            end
        end
        if type(dMap) == "table" then
            for k, v in pairs(dMap) do
                local isAllM = type(v) == "table" and (v.isAllMPlus == true or tostring(v.dungeonName or k):lower() == "all m+ dungeons")
                if isAllM then dMap[k] = nil end
            end
        end
        if type(pMap) == "table" then
            pMap.all = nil
        end
        Print("Cleared all Zone & Content defaults (specific boss, dungeon, and PvP mode binds kept).")
        self:SyncTalentBindsUI(true)
        return true
    end

    if type(zMap) == "table" then
        if zoneSet.outdoor and zMap.outdoor then zMap.outdoor = nil; table.insert(cleared, "Outdoor") end
        if zoneSet.delves and zMap.delves then zMap.delves = nil; table.insert(cleared, "Delves") end
    end
    if zoneSet.pvp then
        local removedPvP = false
        if type(pMap) == "table" and pMap.all ~= nil then
            pMap.all = nil
            removedPvP = true
        end
        if type(zMap) == "table" and zMap.pvp ~= nil then
            zMap.pvp = nil
            removedPvP = true
        end
        if removedPvP then table.insert(cleared, "PvP") end
    end
    if zoneSet.raid and type(bMap) == "table" then
        local removedRaid = false
        for k, v in pairs(bMap) do
            if type(v) == "table" and v.isAllRaid == true then
                bMap[k] = nil
                removedRaid = true
            end
        end
        if removedRaid then table.insert(cleared, "Raid") end
    end
    if zoneSet.dungeons and type(dMap) == "table" then
        local removedM = false
        for k, v in pairs(dMap) do
            local isAllM = type(v) == "table" and (v.isAllMPlus == true or tostring(v.dungeonName or k):lower() == "all m+ dungeons")
            if isAllM then
                dMap[k] = nil
                removedM = true
            end
        end
        if removedM then table.insert(cleared, "Dungeons") end
    end
    if #cleared > 0 then
        Print(string.format("Cleared zone default(s): %s.", table.concat(cleared, ", ")))
        self:SyncTalentBindsUI(true)
        return true
    end
    return false
end

do
    function DynamicTalent:FormatDifficultySummary(d)
        if type(d) ~= "table" then return "LFR/N / H / M" end
        if d.normal and not d.heroic and not d.mythic then return "LFR/N" end
        if d.heroic and not d.normal and not d.mythic then return "Heroic" end
        if d.mythic and not d.normal and not d.heroic then return "Mythic" end
        local parts = {}
        if d.normal then table.insert(parts, "LFR/N") end
        if d.heroic then table.insert(parts, "H") end
        if d.mythic then table.insert(parts, "M") end
        return (#parts > 0) and table.concat(parts, " / ") or "LFR/N / H / M"
    end

    local function FormatTierMap(tiers)
        if type(tiers) ~= "table" then return "Any Key" end
        local parts = {}
        if tiers.ANY then table.insert(parts, "Any Key") end
        if tiers.LOW then table.insert(parts, "+2-9") end
        if tiers.HIGH then table.insert(parts, "+10+") end
        return (#parts > 0) and table.concat(parts, " / ") or "Any Key"
    end

    function DynamicTalent:GetLoadoutBindings(entry, specID)
        local out = {
            bosses         = {},
            raidsWithBinds = {},
            allRaid        = { active = false, diffs = { normal = false, heroic = false, mythic = false } },
            dungeons       = {},
            allMPlus       = { active = false, tiers = {} },
            pvp            = { all = false, arena = false, bg = false, warmode = false },
            zones          = { all = false, outdoor = false, delves = false, dungeons = false, raid = false, pvp = false },
            summaryTags    = {},
            detailLines    = {},
            scopeCount     = 0,
            singleBadge    = nil,
        }
        if type(entry) ~= "table" or type(entry.name) ~= "string" or entry.name == "" or not self.db then
            return out
        end
        local sid = specID or self:GetActiveSpecID()
        if not sid then return out end
        EnsureEntryID(entry, self.db)

        local bMap = self.db.talentBossMap and self.db.talentBossMap[sid]
        if type(bMap) == "table" then
            for _, rule in pairs(bMap) do
                if type(rule) == "table" and DoesRuleMatchEntry(rule, entry) then
                    local d = type(rule.difficulties) == "table" and rule.difficulties or { normal = true, heroic = true, mythic = true }
                    if rule.isAllRaid == true then
                        out.allRaid.active = true
                        out.zones.raid = true
                        if d.normal then out.allRaid.diffs.normal = true end
                        if d.heroic then out.allRaid.diffs.heroic = true end
                        if d.mythic then out.allRaid.diffs.mythic = true end
                    elseif rule.bossName then
                        local bLow = tostring(rule.bossName):lower()
                        local rec = out.bosses[bLow]
                        if not rec then
                            local rShort = rule.raidShort
                            local rName = rule.raidName
                            local bOrder = rule.bossOrder
                            local bShort = nil
                            if type(self.MatchBossTargetName) == "function" then
                                local _, _, rObj, bObj = self:MatchBossTargetName(rule.bossName)
                                if rObj then
                                    rShort = rShort or rObj.short or rObj.name
                                    rName = rName or rObj.name
                                end
                                if bObj then
                                    bOrder = bOrder or bObj.order
                                    bShort = bObj.short
                                end
                            end
                            local cleanShort = nil
                            if type(bShort) == "string" and bShort ~= "" then
                                cleanShort = bShort:gsub("^(%d+)%.%s*", "#%1 ")
                            end
                            rec = {
                                name       = tostring(rule.bossName),
                                short      = cleanShort,
                                order      = bOrder,
                                raidShort  = rShort,
                                raidName   = rName,
                                diffs      = { normal = false, heroic = false, mythic = false },
                            }
                            out.bosses[bLow] = rec
                        end
                        if d.normal then rec.diffs.normal = true end
                        if d.heroic then rec.diffs.heroic = true end
                        if d.mythic then rec.diffs.mythic = true end
                        if rec.raidName then out.raidsWithBinds[rec.raidName:lower()] = true end
                        if rec.raidShort then out.raidsWithBinds[rec.raidShort:lower()] = true end
                    end
                end
            end
        end

        local dMap = self.db.talentDungeonMap and self.db.talentDungeonMap[sid]
        if type(dMap) == "table" then
            for _, rule in pairs(dMap) do
                if type(rule) == "table" and DoesRuleMatchEntry(rule, entry) and rule.dungeonName then
                    local kt = rule.keyTier or "ANY"
                    local isAllRule = (rule.isAllMPlus == true) or (tostring(rule.dungeonName):lower() == "all m+ dungeons")
                    if isAllRule then
                        out.allMPlus.active = true
                        out.allMPlus.tiers[kt] = true
                        out.zones.dungeons = true
                    else
                        local dLow = tostring(rule.dungeonName):lower()
                        local rec = out.dungeons[dLow]
                        if not rec then
                            rec = { name = tostring(rule.dungeonName), tiers = {} }
                            out.dungeons[dLow] = rec
                        end
                        rec.tiers[kt] = true
                    end
                end
            end
        end

        local pMap = self.db.talentPvPMap and self.db.talentPvPMap[sid]
        if type(pMap) == "table" then
            for _, pk in ipairs({ "all", "arena", "bg", "warmode" }) do
                if type(pMap[pk]) == "table" and DoesRuleMatchEntry(pMap[pk], entry) then
                    out.pvp[pk] = true
                end
            end
        end

        local zMap = self.db.talentZoneMap and self.db.talentZoneMap[sid]
        if type(zMap) == "table" then
            if type(zMap.delves) == "table" and DoesRuleMatchEntry(zMap.delves, entry) then
                out.zones.delves = true
            end
            if not out.pvp.all and type(zMap.pvp) == "table" and DoesRuleMatchEntry(zMap.pvp, entry) then
                out.pvp.all = true
            end
            if type(zMap.outdoor) == "table" and DoesRuleMatchEntry(zMap.outdoor, entry) then
                out.zones.outdoor = true
            end
            if type(zMap.all) == "table" and DoesRuleMatchEntry(zMap.all, entry) then
                out.zones.all = true
            end
        end
        out.zones.pvp = out.pvp.all

        local lastSingle, lastShort = nil, nil
        local bossList = {}
        for _, rec in pairs(out.bosses) do table.insert(bossList, rec) end
        table.sort(bossList, function(a, b)
            local ra, rb = tostring(a.raidShort or ""), tostring(b.raidShort or "")
            if ra ~= rb then return ra < rb end
            local oa, ob = tonumber(a.order) or 99, tonumber(b.order) or 99
            if oa ~= ob then return oa < ob end
            return a.name:lower() < b.name:lower()
        end)
        for _, rec in ipairs(bossList) do
            local diffTxt = self:FormatDifficultySummary(rec.diffs)
            local numPfx = (tonumber(rec.order) and tonumber(rec.order) > 0) and ("#" .. tonumber(rec.order) .. " ") or ""
            local tag = numPfx .. rec.name
            local shortTag = rec.short or ((#tag > 15) and (tag:sub(1, 13) .. ".") or tag)
            local raidPfx = rec.raidShort and (rec.raidShort .. " ") or ""
            table.insert(out.summaryTags, tag .. " (" .. diffTxt .. ")")
            table.insert(out.detailLines, string.format("Raid Boss: %s%s [%s]", raidPfx, tag, diffTxt))
            out.scopeCount = out.scopeCount + 1
            lastSingle = tag
            lastShort = shortTag
        end

        local dungList = {}
        for _, rec in pairs(out.dungeons) do table.insert(dungList, rec) end
        table.sort(dungList, function(a, b) return a.name:lower() < b.name:lower() end)
        for _, rec in ipairs(dungList) do
            local tStr = FormatTierMap(rec.tiers)
            local dShort = rec.name
            if #dShort > 12 then
                local acr = ""
                for w in dShort:gmatch("%a+") do
                    if #acr < 4 then acr = acr .. w:sub(1, 1):upper() end
                end
                dShort = (#acr >= 2) and ("M+ " .. acr) or dShort:sub(1, 11)
            end
            table.insert(out.summaryTags, rec.name .. " (" .. tStr .. ")")
            table.insert(out.detailLines, string.format("M+ Dungeon: %s [%s]", rec.name, tStr))
            out.scopeCount = out.scopeCount + 1
            lastSingle = rec.name
            lastShort = dShort
        end

        if out.pvp.arena then
            table.insert(out.summaryTags, "PvP: Arena")
            table.insert(out.detailLines, "PvP: Arena")
            out.scopeCount = out.scopeCount + 1
            lastSingle = "Arena"
            lastShort = "Arena"
        end
        if out.pvp.bg then
            table.insert(out.summaryTags, "PvP: Battlegrounds")
            table.insert(out.detailLines, "PvP: Battlegrounds")
            out.scopeCount = out.scopeCount + 1
            lastSingle = "Battlegrounds"
            lastShort = "BGs"
        end
        if out.pvp.warmode then
            table.insert(out.summaryTags, "PvP: War Mode")
            table.insert(out.detailLines, "PvP: War Mode")
            out.scopeCount = out.scopeCount + 1
            lastSingle = "War Mode"
            lastShort = "War Mode"
        end

        if out.allRaid.active then
            local dStr = self:FormatDifficultySummary(out.allRaid.diffs)
            table.insert(out.summaryTags, "All Raids (" .. dStr .. ")")
            table.insert(out.detailLines, string.format("Raid Default: All Raids [%s]", dStr))
            out.scopeCount = out.scopeCount + 1
            lastSingle = "All Raids"
            lastShort = "All Raids"
        end
        if out.allMPlus.active then
            local tStr = FormatTierMap(out.allMPlus.tiers)
            table.insert(out.summaryTags, "All M+ (" .. tStr .. ")")
            table.insert(out.detailLines, string.format("M+ Default: All M+ [%s]", tStr))
            out.scopeCount = out.scopeCount + 1
            lastSingle = "All M+"
            lastShort = "All M+"
        end
        if out.pvp.all then
            table.insert(out.summaryTags, "All PvP")
            table.insert(out.detailLines, "PvP Default: All PvP")
            out.scopeCount = out.scopeCount + 1
            lastSingle = "All PvP"
            lastShort = "All PvP"
        end
        if out.zones.delves then
            table.insert(out.summaryTags, "Zone: Delves")
            table.insert(out.detailLines, "Zone Default: Delves")
            out.scopeCount = out.scopeCount + 1
            lastSingle = "Delves"
            lastShort = "Delves"
        end
        if out.zones.outdoor then
            table.insert(out.summaryTags, "Zone: Outdoor")
            table.insert(out.detailLines, "Zone Default: Outdoor")
            out.scopeCount = out.scopeCount + 1
            lastSingle = "Outdoor"
            lastShort = "Outdoor"
        end
        if out.zones.all then
            table.insert(out.summaryTags, "All Content")
            table.insert(out.detailLines, "Global Default: All Content")
            out.scopeCount = out.scopeCount + 1
            lastSingle = "All Content"
            lastShort = "All Content"
        end

        if out.scopeCount == 1 then
            out.singleBadge = lastSingle
            out.singleShortBadge = lastShort or lastSingle
        end
        return out
    end

    function DynamicTalent:GetLoadoutBindBadgeText(entry, specID)
        local bInfo = self:GetLoadoutBindings(entry, specID)
        if not bInfo then return nil, nil end
        if bInfo.scopeCount >= 2 then
            return "(Various)", bInfo
        elseif bInfo.scopeCount == 1 then
            return "(" .. tostring(bInfo.singleShortBadge or bInfo.singleBadge or "Bound") .. ")", bInfo
        end
        return nil, bInfo
    end

    function DynamicTalent:GetSlotOwnerSummary(kind, key, specID)
        if not self.db then return nil end
        local sid = specID or self:GetActiveSpecID()
        if not sid then return nil end
        local nameCounts = {}
        local rawLib = self.db.talentStringLibrary and self.db.talentStringLibrary[sid]
        if type(rawLib) == "table" then
            for _, le in ipairs(rawLib) do
                if type(le) == "table" and type(le.name) == "string" and le.name ~= "" then
                    local nl = le.name:lower()
                    nameCounts[nl] = (nameCounts[nl] or 0) + 1
                end
            end
        end
        local seen, owners = {}, {}
        local function PushOwner(rule, defGroup)
            if type(rule) ~= "table" then return end
            local name = rule.loadoutName
            if type(name) ~= "string" or name == "" then return end
            local libRef = self:FindLibraryEntryForRule(rule, sid)
            local grp = NormalizeTalentGroupKey((libRef and libRef.group) or rule.group or defGroup or "Custom")
            local hero = (libRef and self:GetLoadoutHeroAcronym(libRef)) or rule.heroAcronym
            local dedupeKey = tostring((libRef and libRef.id) or rule.loadoutID or rule.importString or (grp .. ":" .. tostring(hero or "") .. ":" .. name)):lower()
            if not seen[dedupeKey] then
                seen[dedupeKey] = true
                local label = name
                if (nameCounts[name:lower()] or 0) > 1 then
                    local tag = (type(hero) == "string" and hero ~= "") and (grp .. "-" .. hero) or grp
                    label = "[" .. tag .. "] " .. name
                end
                table.insert(owners, label)
            end
        end
        local lowKey = type(key) == "string" and key:lower() or ""
        if kind == "BOSS" and lowKey ~= "" then
            local bMap = self.db.talentBossMap and self.db.talentBossMap[sid]
            if type(bMap) == "table" then
                for _, v in pairs(bMap) do
                    if type(v) == "table" and v.isAllRaid ~= true and tostring(v.bossName or ""):lower() == lowKey then
                        PushOwner(v, "Raid")
                    end
                end
            end
        elseif kind == "ALL_RAID" then
            local bMap = self.db.talentBossMap and self.db.talentBossMap[sid]
            if type(bMap) == "table" then
                for _, v in pairs(bMap) do
                    if type(v) == "table" and v.isAllRaid == true then
                        PushOwner(v, "Raid")
                    end
                end
            end
        elseif kind == "DUNGEON" and lowKey ~= "" then
            local dMap = self.db.talentDungeonMap and self.db.talentDungeonMap[sid]
            if type(dMap) == "table" then
                for _, v in pairs(dMap) do
                    local isAllM = type(v) == "table" and (v.isAllMPlus == true or tostring(v.dungeonName or ""):lower() == "all m+ dungeons")
                    if type(v) == "table" and not isAllM and tostring(v.dungeonName or ""):lower() == lowKey then
                        PushOwner(v, "M+")
                    end
                end
            end
        elseif kind == "ALL_MPLUS" then
            local dMap = self.db.talentDungeonMap and self.db.talentDungeonMap[sid]
            if type(dMap) == "table" then
                for _, v in pairs(dMap) do
                    local isAllM = type(v) == "table" and (v.isAllMPlus == true or tostring(v.dungeonName or ""):lower() == "all m+ dungeons")
                    if isAllM then
                        PushOwner(v, "M+")
                    end
                end
            end
        elseif kind == "PVP" and lowKey ~= "" then
            local pMap = self.db.talentPvPMap and self.db.talentPvPMap[sid]
            if type(pMap) == "table" and type(pMap[lowKey]) == "table" then
                PushOwner(pMap[lowKey], "PvP")
            elseif lowKey == "all" then
                local zMap = self.db.talentZoneMap and self.db.talentZoneMap[sid]
                if type(zMap) == "table" and type(zMap.pvp) == "table" then
                    PushOwner(zMap.pvp, "PvP")
                end
            end
        elseif kind == "ZONE" and lowKey ~= "" then
            if lowKey == "pvp" then
                return self:GetSlotOwnerSummary("PVP", "all", sid)
            end
            local zMap = self.db.talentZoneMap and self.db.talentZoneMap[sid]
            if type(zMap) == "table" and type(zMap[lowKey]) == "table" then
                PushOwner(zMap[lowKey], lowKey == "delves" and "Delves" or "Custom")
            end
        end
        if #owners == 0 then return nil end
        return table.concat(owners, ", ")
    end

    function DynamicTalent:DetectBindConflicts(kind, payload, newEntry, specID)
        local conflicts = {}
        if not self.db or type(newEntry) ~= "table" or type(newEntry.name) ~= "string" then
            return conflicts
        end
        local sid = specID or self:GetActiveSpecID()
        if not sid then return conflicts end
        EnsureEntryID(newEntry, self.db)
        local bMap = self.db.talentBossMap and self.db.talentBossMap[sid] or {}
        local dMap = self.db.talentDungeonMap and self.db.talentDungeonMap[sid] or {}
        local pMap = self.db.talentPvPMap and self.db.talentPvPMap[sid] or {}
        local zMap = self.db.talentZoneMap and self.db.talentZoneMap[sid] or {}

        local function MakeConflict(scopeStr, ruleTbl, defGroup)
            local exName = type(ruleTbl) == "table" and tostring(ruleTbl.loadoutName or "") or ""
            local libRef = self:FindLibraryEntryForRule(ruleTbl, sid)
            local badge = self:FormatTalentBadge({
                loadoutID    = (libRef and libRef.id) or (type(ruleTbl) == "table" and ruleTbl.loadoutID) or nil,
                group        = (libRef and libRef.group) or (type(ruleTbl) == "table" and ruleTbl.group) or defGroup or "Custom",
                importString = (libRef and libRef.importString) or (type(ruleTbl) == "table" and ruleTbl.importString) or nil,
                loadoutName  = exName,
                heroAcronym  = (libRef and libRef.heroAcronym) or (type(ruleTbl) == "table" and ruleTbl.heroAcronym) or nil,
            })
            return {
                scope         = scopeStr,
                existingName  = exName,
                existingBadge = badge,
            }
        end

        local function TierLbl(kt)
            return (kt == "HIGH" and "+10+") or (kt == "LOW" and "+2-9") or "Any Key"
        end
        local function DiffOverlap(exD, newD)
            local exAll = (type(exD) ~= "table")
            local ov = {
                normal = ((newD.normal == true) and (exAll or exD.normal == true)),
                heroic = ((newD.heroic == true) and (exAll or exD.heroic == true)),
                mythic = ((newD.mythic == true) and (exAll or exD.mythic == true)),
            }
            if not (ov.normal or ov.heroic or ov.mythic) then return nil end
            return self:FormatDifficultySummary(ov)
        end

        if kind == "BOSS_LIST" then
            local ds = (payload and payload.diffState) or { normal = true, heroic = true, mythic = true }
            for _, tInfo in ipairs((payload and payload.targets) or {}) do
                local bName = tostring(tInfo.name or "")
                local bLow = bName:lower()
                if bLow ~= "" then
                    for _, exV in pairs(bMap) do
                        if type(exV) == "table" and exV.isAllRaid ~= true and tostring(exV.bossName or ""):lower() == bLow then
                            local exName = tostring(exV.loadoutName or "")
                            if exName ~= "" and not DoesRuleMatchEntry(exV, newEntry) then
                                local ovTxt = DiffOverlap(exV.difficulties, ds)
                                if ovTxt then
                                    local ordPfx = tInfo.order and ("#" .. tInfo.order .. " ") or ""
                                    table.insert(conflicts, MakeConflict(ordPfx .. bName .. " (" .. ovTxt .. ")", exV, "Raid"))
                                end
                            end
                        end
                    end
                end
            end
        elseif kind == "ALL_RAID" then
            local ds = (payload and payload.diffState) or { normal = true, heroic = true, mythic = true }
            for _, exV in pairs(bMap) do
                if type(exV) == "table" and exV.isAllRaid == true then
                    local exName = tostring(exV.loadoutName or "")
                    if exName ~= "" and not DoesRuleMatchEntry(exV, newEntry) then
                        local ovTxt = DiffOverlap(exV.difficulties, ds)
                        if ovTxt then
                            table.insert(conflicts, MakeConflict("All Raids (" .. ovTxt .. ")", exV, "Raid"))
                        end
                    end
                end
            end
        elseif kind == "MPLUS_LIST" then
            local kt = (payload and payload.keyTier) or "ANY"
            for _, dObj in ipairs((payload and payload.dungeons) or {}) do
                local dLow = tostring(dObj.name or ""):lower()
                if dLow ~= "" then
                    for _, exV in pairs(dMap) do
                        if type(exV) == "table" then
                            local isAllM = (exV.isAllMPlus == true) or (tostring(exV.dungeonName or ""):lower() == "all m+ dungeons")
                            local exKT = exV.keyTier or "ANY"
                            if not isAllM and tostring(exV.dungeonName or ""):lower() == dLow
                                and (exKT == kt or kt == "ANY" or exKT == "ANY") then
                                local exName = tostring(exV.loadoutName or "")
                                if exName ~= "" and not DoesRuleMatchEntry(exV, newEntry) then
                                    table.insert(conflicts, MakeConflict(dObj.name .. " (" .. TierLbl(exKT) .. ")", exV, "M+"))
                                end
                            end
                        end
                    end
                end
            end
        elseif kind == "ALL_MPLUS" then
            local kt = (payload and payload.keyTier) or "ANY"
            for _, exV in pairs(dMap) do
                if type(exV) == "table" then
                    local isAllM = (exV.isAllMPlus == true) or (tostring(exV.dungeonName or ""):lower() == "all m+ dungeons")
                    local exKT = exV.keyTier or "ANY"
                    if isAllM and (exKT == kt or kt == "ANY" or exKT == "ANY") then
                        local exName = tostring(exV.loadoutName or "")
                        if exName ~= "" and not DoesRuleMatchEntry(exV, newEntry) then
                            table.insert(conflicts, MakeConflict("All M+ (" .. TierLbl(exKT) .. ")", exV, "M+"))
                        end
                    end
                end
            end
        elseif kind == "PVP_LIST" then
            for _, pk in ipairs((payload and payload.pvpKeys) or {}) do
                local exV = pMap[pk]
                if not exV and pk == "all" then
                    exV = zMap.pvp
                end
                if type(exV) == "table" then
                    local exName = tostring(exV.loadoutName or "")
                    if exName ~= "" and not DoesRuleMatchEntry(exV, newEntry) then
                        table.insert(conflicts, MakeConflict(PVP_MODE_LABELS[pk] or pk, exV, "PvP"))
                    end
                end
            end
        elseif kind == "ALL_CONTENT" then
            if type(zMap.all) == "table" and tostring(zMap.all.loadoutName or "") ~= "" and not DoesRuleMatchEntry(zMap.all, newEntry) then
                table.insert(conflicts, MakeConflict("All Content Default", zMap.all, "Custom"))
            end
            for _, zItem in ipairs({ { key = "outdoor", label = "Zone: Outdoor", defGroup = "Custom" }, { key = "delves", label = "Zone: Delves", defGroup = "Delves" } }) do
                local zv = zMap[zItem.key]
                if type(zv) == "table" and tostring(zv.loadoutName or "") ~= "" and not DoesRuleMatchEntry(zv, newEntry) then
                    table.insert(conflicts, MakeConflict(zItem.label, zv, zItem.defGroup))
                end
            end
            for _, c in ipairs(self:DetectBindConflicts("PVP_LIST", { pvpKeys = { "all" } }, newEntry, sid)) do
                table.insert(conflicts, c)
            end
            for _, c in ipairs(self:DetectBindConflicts("ALL_RAID", { diffState = { normal = true, heroic = true, mythic = true } }, newEntry, sid)) do
                table.insert(conflicts, c)
            end
            for _, c in ipairs(self:DetectBindConflicts("ALL_MPLUS", { keyTier = "ANY" }, newEntry, sid)) do
                table.insert(conflicts, c)
            end
        elseif kind == "ZONES" then
            local zs = (payload and payload.zoneSet) or {}
            if payload and payload.isAll then
                return self:DetectBindConflicts("ALL_CONTENT", nil, newEntry, sid)
            end
            if zs.outdoor and type(zMap.outdoor) == "table" and tostring(zMap.outdoor.loadoutName or "") ~= "" and not DoesRuleMatchEntry(zMap.outdoor, newEntry) then
                table.insert(conflicts, MakeConflict("Zone: Outdoor", zMap.outdoor, "Custom"))
            end
            if zs.delves and type(zMap.delves) == "table" and tostring(zMap.delves.loadoutName or "") ~= "" and not DoesRuleMatchEntry(zMap.delves, newEntry) then
                table.insert(conflicts, MakeConflict("Zone: Delves", zMap.delves, "Delves"))
            end
            if zs.dungeons then
                for _, c in ipairs(self:DetectBindConflicts("ALL_MPLUS", { keyTier = "ANY" }, newEntry, sid)) do
                    table.insert(conflicts, c)
                end
            end
            if zs.raid then
                for _, c in ipairs(self:DetectBindConflicts("ALL_RAID", { diffState = { normal = true, heroic = true, mythic = true } }, newEntry, sid)) do
                    table.insert(conflicts, c)
                end
            end
            if zs.pvp then
                for _, c in ipairs(self:DetectBindConflicts("PVP_LIST", { pvpKeys = { "all" } }, newEntry, sid)) do
                    table.insert(conflicts, c)
                end
            end
        end
        return conflicts
    end

    function DynamicTalent:ConfirmBindOverwrite(conflicts, newEntry, onConfirm, opts)
        if type(conflicts) ~= "table" or #conflicts == 0 then
            if type(onConfirm) == "function" then onConfirm() end
            return
        end
        local ar, ag, ab = GetActiveAccentRGB()
        if not self._overwriteCatcher then
            local cat = CreateFrame("Button", "DynamicTalentOverwriteCatcher", UIParent)
            cat:SetAllPoints(UIParent)
            cat:SetFrameStrata("FULLSCREEN_DIALOG")
            cat:SetFrameLevel(80)
            cat:EnableMouse(true)
            cat.bg = cat:CreateTexture(nil, "BACKGROUND")
            cat.bg:SetAllPoints()
            cat.bg:SetColorTexture(0.01, 0.01, 0.02, 0.56)
            cat:Hide()
            self._overwriteCatcher = cat
        end
        if not self._overwriteModal then
            local f = CreateFrame("Frame", "DynamicTalentOverwriteModal", UIParent, "BackdropTemplate")
            f:SetSize(560, 220)
            f:SetPoint("CENTER")
            f:SetFrameStrata("FULLSCREEN_DIALOG")
            f:SetFrameLevel(90)
            f:SetClampedToScreen(true)
            f:EnableMouse(true)
            f:Hide()
            if _G.UISpecialFrames then
                table.insert(_G.UISpecialFrames, "DynamicTalentOverwriteModal")
            end

            do
                local hdr = CreateFrame("Frame", nil, f, "BackdropTemplate")
                hdr:SetHeight(34)
                hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
                hdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
                SetPixelBackdrop(hdr, { 0.016, 0.020, 0.024, 1.00 }, { 0, 0, 0, 0 }, 0)
                local div = hdr:CreateTexture(nil, "ARTWORK")
                div:SetHeight(1)
                div:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 0, 0)
                div:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
                div:SetColorTexture(1, 1, 1, 0.08)

                local ttl = CreateText(hdr, "OVERLAY", "GameFontHighlightSmall")
                ttl:SetPoint("LEFT", hdr, "LEFT", 12, 0)
                ttl:SetPoint("RIGHT", hdr, "RIGHT", -40, 0)
                ttl:SetJustifyH("LEFT")
                ttl:SetWordWrap(false)
                ttl:SetText("|cFFCBD5E1Dynamic|r|cFFFFFFFFTalent|r  |cFF475569|||r  |cFFFBBF24Confirm Overwrite|r")
                f.ttlFS = ttl

                local closeBtn = CreateFrame("Button", nil, hdr)
                closeBtn:SetSize(34, 33)
                closeBtn:SetPoint("TOPRIGHT", hdr, "TOPRIGHT", 0, 0)
                local cbg = closeBtn:CreateTexture(nil, "BACKGROUND")
                cbg:SetAllPoints()
                cbg:SetColorTexture(0.957, 0.247, 0.369, 0.00)
                local x1 = closeBtn:CreateTexture(nil, "OVERLAY")
                x1:SetSize(11, 1.6); x1:SetPoint("CENTER"); x1:SetColorTexture(0.75, 0.80, 0.88, 0.90); x1:SetRotation(math.rad(45))
                local x2 = closeBtn:CreateTexture(nil, "OVERLAY")
                x2:SetSize(11, 1.6); x2:SetPoint("CENTER"); x2:SetColorTexture(0.75, 0.80, 0.88, 0.90); x2:SetRotation(math.rad(-45))
                closeBtn:SetScript("OnEnter", function() cbg:SetColorTexture(0.957, 0.247, 0.369, 0.22); x1:SetColorTexture(1, 1, 1, 1); x2:SetColorTexture(1, 1, 1, 1) end)
                closeBtn:SetScript("OnLeave", function() cbg:SetColorTexture(0.957, 0.247, 0.369, 0.00); x1:SetColorTexture(0.75, 0.80, 0.88, 0.90); x2:SetColorTexture(0.75, 0.80, 0.88, 0.90) end)
                closeBtn:SetScript("OnClick", function() f:Hide() end)
            end

            f.promptFS = CreateText(f, "OVERLAY", "GameFontHighlightSmall")
            f.promptFS:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -44)
            f.promptFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -44)
            f.promptFS:SetJustifyH("LEFT")
            f.promptFS:SetWordWrap(true)

            f.box = CreateFrame("Frame", nil, f, "BackdropTemplate")
            f.box:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -86)
            f.box:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -86)
            SetPixelBackdrop(f.box, { 0.043, 0.051, 0.071, 1.00 }, { 1, 1, 1, 0.08 }, 1)
            f.rows = {}

            f.scroll = CreateFrame("ScrollFrame", nil, f.box)
            f.scroll:SetPoint("TOPLEFT", f.box, "TOPLEFT", 6, -6)
            f.scroll:SetPoint("BOTTOMRIGHT", f.box, "BOTTOMRIGHT", -6, 6)
            f.scroll:EnableMouseWheel(true)
            f.scrollChild = CreateFrame("Frame", nil, f.scroll)
            f.scrollChild:SetWidth(520)
            f.scrollChild:SetHeight(26)
            f.scroll:SetScrollChild(f.scrollChild)

            f.track = CreateFrame("Frame", nil, f.box, "BackdropTemplate")
            f.track:SetWidth(4)
            f.track:SetPoint("TOPRIGHT", f.box, "TOPRIGHT", -4, -6)
            f.track:SetPoint("BOTTOMRIGHT", f.box, "BOTTOMRIGHT", -4, 6)
            f.track:SetFrameLevel(95)
            f.track:EnableMouse(true)
            f.track:EnableMouseWheel(true)
            f.track:SetHitRectInsets(-5, -4, 0, 0)
            SetPixelBackdrop(f.track, { 0.031, 0.035, 0.047, 0.95 }, { 0, 0, 0, 0 }, 0)
            f.track:Hide()

            f.thumb = CreateFrame("Button", nil, f.track)
            f.thumb:SetWidth(4)
            f.thumb:SetHeight(24)
            f.thumb:SetPoint("TOP", f.track, "TOP", 0, 0)
            f.thumb:SetFrameLevel(96)
            f.thumb:EnableMouse(true)
            f.thumb:SetHitRectInsets(-5, -4, 0, 0)
            f.thumb.tex = f.thumb:CreateTexture(nil, "OVERLAY")
            f.thumb.tex:SetAllPoints()
            f.thumb.tex:SetColorTexture(ar, ag, ab, 0.78)
            f.thumb:Hide()

            f.UpdateScrollBar = function()
                local r, g, b = GetActiveAccentRGB()
                if f.thumb.isDragging then
                    f.thumb.tex:SetColorTexture(r, g, b, 1.0)
                elseif f.thumb.isHovered then
                    f.thumb.tex:SetColorTexture(r, g, b, 0.92)
                else
                    f.thumb.tex:SetColorTexture(r, g, b, 0.78)
                end
                local visH = f._visH or f.scroll:GetHeight() or 0
                local totalH = f.scrollChild:GetHeight() or 0
                local boxW = f.box:GetWidth() or 532
                local maxS = math.max(0, totalH - visH)
                f.scroll:ClearAllPoints()
                f.scroll:SetPoint("TOPLEFT", f.box, "TOPLEFT", 6, -6)
                if maxS <= 1 or visH <= 1 then
                    f.scroll:SetPoint("BOTTOMRIGHT", f.box, "BOTTOMRIGHT", -6, 6)
                    f.scrollChild:SetWidth(math.max(100, boxW - 12))
                    f.track:Hide()
                    f.thumb:Hide()
                    f.scroll:SetVerticalScroll(0)
                else
                    f.scroll:SetPoint("BOTTOMRIGHT", f.box, "BOTTOMRIGHT", -14, 6)
                    f.scrollChild:SetWidth(math.max(100, boxW - 20))
                    f.track:Show()
                    f.thumb:Show()
                    local trackH = f.track:GetHeight()
                    if not trackH or trackH <= 1 then trackH = visH end
                    local cur = math.max(0, math.min(maxS, f.scroll:GetVerticalScroll() or 0))
                    local thumbH = math.max(20, math.floor(trackH * math.min(1, visH / totalH) + 0.5))
                    local travel = math.max(1, trackH - thumbH)
                    f.thumb:SetHeight(thumbH)
                    f.thumb:ClearAllPoints()
                    f.thumb:SetPoint("TOP", f.track, "TOP", 0, -math.floor((cur / maxS) * travel + 0.5))
                end
                local cw = f.scrollChild:GetWidth()
                for _, rw in ipairs(f.rows) do
                    if rw:IsShown() then rw:SetWidth(cw) end
                end
            end

            f.ScrollFromCursor = function()
                if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                    f.thumb.isDragging = false
                    f.thumb:SetScript("OnUpdate", nil)
                    f.track:SetScript("OnUpdate", nil)
                    f.UpdateScrollBar()
                    return
                end
                local visH = f._visH or f.scroll:GetHeight() or 0
                local totalH = f.scrollChild:GetHeight() or 0
                local maxS = math.max(0, totalH - visH)
                local trackH = f.track:GetHeight()
                if not trackH or trackH <= 1 then trackH = visH end
                if maxS <= 1 or trackH <= 1 then return end
                local tTop = f.track:GetTop()
                local eff = f.track:GetEffectiveScale() or 1
                if not tTop or eff <= 0 or not GetCursorPosition then return end
                local _, cy = GetCursorPosition()
                local relY = math.max(0, math.min(trackH, tTop - (cy / eff)))
                local thumbH = f.thumb:GetHeight() or 20
                local travel = math.max(1, trackH - thumbH)
                local ratio = math.max(0, math.min(1, (relY - (thumbH * 0.5)) / travel))
                f.scroll:SetVerticalScroll(ratio * maxS)
                f.UpdateScrollBar()
            end

            f.thumb:SetScript("OnEnter", function(s) s.isHovered = true; f.UpdateScrollBar() end)
            f.thumb:SetScript("OnLeave", function(s) s.isHovered = false; f.UpdateScrollBar() end)
            f.thumb:SetScript("OnMouseDown", function(s, btn)
                if btn ~= "LeftButton" then return end
                s.isDragging = true
                s:SetScript("OnUpdate", f.ScrollFromCursor)
                f.ScrollFromCursor()
            end)
            f.thumb:SetScript("OnMouseUp", function(s)
                s.isDragging = false
                s:SetScript("OnUpdate", nil)
                f.UpdateScrollBar()
            end)
            f.track:SetScript("OnMouseDown", function(s, btn)
                if btn ~= "LeftButton" then return end
                f.thumb.isDragging = true
                s:SetScript("OnUpdate", f.ScrollFromCursor)
                f.ScrollFromCursor()
            end)
            f.track:SetScript("OnMouseUp", function(s)
                f.thumb.isDragging = false
                s:SetScript("OnUpdate", nil)
                f.UpdateScrollBar()
            end)

            local function HandleOverwriteWheel(delta)
                local visH = f._visH or f.scroll:GetHeight() or 0
                local maxS = math.max(0, (f.scrollChild:GetHeight() or 0) - visH)
                if maxS <= 1 then
                    f.scroll:SetVerticalScroll(0)
                else
                    f.scroll:SetVerticalScroll(math.max(0, math.min(maxS, (f.scroll:GetVerticalScroll() or 0) - (delta * 26))))
                end
                f.UpdateScrollBar()
            end
            f.scroll:SetScript("OnMouseWheel", function(_, delta) HandleOverwriteWheel(delta) end)
            f.track:SetScript("OnMouseWheel", function(_, delta) HandleOverwriteWheel(delta) end)

            f.cancelBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
            f.cancelBtn:SetSize(84, 26)
            f.cancelBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)
            SetPixelBackdrop(f.cancelBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
            f.cancelBtn.txt = CreateText(f.cancelBtn, "OVERLAY", "GameFontHighlightSmall")
            f.cancelBtn.txt:SetPoint("CENTER")
            f.cancelBtn.txt:SetText("Cancel")
            f.cancelBtn:SetScript("OnEnter", function(s) SetPixelBackdrop(s, { 0.14, 0.16, 0.21, 0.98 }, { 0.45, 0.52, 0.64, 0.95 }, 1) end)
            f.cancelBtn:SetScript("OnLeave", function(s) SetPixelBackdrop(s, COLORS.BgElevated, COLORS.BorderSubtle, 1) end)
            f.cancelBtn:SetScript("OnClick", function() f:Hide() end)

            f.unboundBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
            f.unboundBtn:SetSize(144, 26)
            f.unboundBtn:SetPoint("RIGHT", f.cancelBtn, "LEFT", -8, 0)
            SetPixelBackdrop(f.unboundBtn, { 0.063 * 0.34, 0.725 * 0.34, 0.506 * 0.34, 1.00 }, { 0.063, 0.725, 0.506, 0.90 }, 1)
            f.unboundBtn.txt = CreateText(f.unboundBtn, "OVERLAY", "GameFontHighlightSmall")
            f.unboundBtn.txt:SetPoint("CENTER")
            f.unboundBtn.txt:SetText("Bind Unbound Only")
            f.unboundBtn:SetScript("OnEnter", function(s) SetPixelBackdrop(s, { 0.063 * 0.50, 0.725 * 0.50, 0.506 * 0.50, 1.00 }, { 0.20, 0.85, 0.62, 1.00 }, 1) end)
            f.unboundBtn:SetScript("OnLeave", function(s) SetPixelBackdrop(s, { 0.063 * 0.34, 0.725 * 0.34, 0.506 * 0.34, 1.00 }, { 0.063, 0.725, 0.506, 0.90 }, 1) end)
            f.unboundBtn:Hide()

            f.confirmBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
            f.confirmBtn:SetSize(112, 26)
            f.confirmBtn:SetPoint("RIGHT", f.cancelBtn, "LEFT", -8, 0)
            f.confirmBtn.txt = CreateText(f.confirmBtn, "OVERLAY", "GameFontHighlightSmall")
            f.confirmBtn.txt:SetPoint("CENTER")
            f.confirmBtn.txt:SetText("Overwrite")
            f.confirmBtn:SetScript("OnEnter", function(s)
                local r, g, b = GetActiveAccentRGB()
                SetPixelBackdrop(s, { math.min(1, r * 0.55), math.min(1, g * 0.55), math.min(1, b * 0.55), 1.00 }, { r, g, b, 1.00 }, 1)
            end)
            f.confirmBtn:SetScript("OnLeave", function(s)
                local r, g, b = GetActiveAccentRGB()
                SetPixelBackdrop(s, { r * 0.42, g * 0.42, b * 0.42, 1.00 }, { r, g, b, 0.95 }, 1)
            end)

            f:SetScript("OnHide", function()
                f.thumb.isDragging = false
                f.thumb:SetScript("OnUpdate", nil)
                f.track:SetScript("OnUpdate", nil)
                if GameTooltip then GameTooltip:Hide() end
                if DynamicTalent._overwriteCatcher then DynamicTalent._overwriteCatcher:Hide() end
            end)
            self._overwriteCatcher:SetScript("OnClick", function() f:Hide() end)
            self._overwriteModal = f
        end

        local f = self._overwriteModal
        SetPixelBackdrop(f, { 0.035, 0.039, 0.051, 1.00 }, { ar, ag, ab, 0.92 }, 1)
        SetPixelBackdrop(f.confirmBtn, { ar * 0.42, ag * 0.42, ab * 0.42, 1.00 }, { ar, ag, ab, 0.95 }, 1)

        local nConflicts = #conflicts
        if f.ttlFS then
            f.ttlFS:SetText(string.format("|cFFCBD5E1Dynamic|r|cFFFFFFFFTalent|r  |cFF475569|||r  |cFFFBBF24Confirm Overwrite|r  |cFF94A3B8(%d %s)|r", nConflicts, (nConflicts == 1 and "conflict" or "conflicts")))
        end

        local newBadge = self:FormatTalentBadge(newEntry)
        local newNameStr = tostring(newEntry and newEntry.name or "this build")
        local hasUnbound = (type(opts) == "table" and type(opts.onBindUnboundOnly) == "function")
        local unboundCount = (hasUnbound and tonumber(opts.unboundCount)) or 0

        f.confirmBtn:ClearAllPoints()
        if hasUnbound then
            f.unboundBtn:Show()
            f.unboundBtn:SetScript("OnClick", function()
                f:Hide()
                opts.onBindUnboundOnly()
            end)
            f.confirmBtn:SetPoint("RIGHT", f.unboundBtn, "LEFT", -8, 0)
            f.confirmBtn.txt:SetText("Overwrite All")
            f.promptFS:SetText(string.format(
                "|cFFE2E8F0%d selected %s already bound to another loadout. Overwrite all with|r %s |cFFFFFFFF%s|r|cFFE2E8F0, or bind only the %d unbound %s?|r",
                nConflicts,
                (nConflicts == 1 and "slot is" or "slots are"),
                newBadge,
                newNameStr,
                math.max(1, unboundCount),
                (math.max(1, unboundCount) == 1 and "slot" or "slots")
            ))
        else
            f.unboundBtn:Hide()
            f.confirmBtn:SetPoint("RIGHT", f.cancelBtn, "LEFT", -8, 0)
            f.confirmBtn.txt:SetText("Overwrite")
            f.promptFS:SetText(string.format(
                "|cFFE2E8F0%d selected %s already bound to another loadout. Overwrite with|r %s |cFFFFFFFF%s|r|cFFE2E8F0?|r",
                nConflicts,
                (nConflicts == 1 and "bind is" or "binds are"),
                newBadge,
                newNameStr
            ))
        end

        for _, rw in ipairs(f.rows) do rw:Hide() end
        local stride = 26
        local rowW = (nConflicts >= 4) and 512 or 520
        for i, c in ipairs(conflicts) do
            local row = f.rows[i]
            if not row then
                row = CreateFrame("Frame", nil, f.scrollChild, "BackdropTemplate")
                row:SetHeight(24)
                row:EnableMouse(true)
                SetPixelBackdrop(row, COLORS.BgElevated, { 1, 1, 1, 0.05 }, 1)
                row.fs = CreateText(row, "OVERLAY", "GameFontHighlightSmall")
                row.fs:SetPoint("LEFT", row, "LEFT", 8, 0)
                row.fs:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                row.fs:SetJustifyH("LEFT")
                row.fs:SetWordWrap(false)
                row:SetScript("OnEnter", function(s)
                    local r, g, b = GetActiveAccentRGB()
                    SetPixelBackdrop(s, { r * 0.22, g * 0.22, b * 0.22, 0.96 }, { r, g, b, 0.75 }, 1)
                    if GameTooltip and s._cData then
                        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                        GameTooltip:AddLine("Conflict Details", 1, 1, 1)
                        GameTooltip:AddLine("|cFFFBBF24Scope:|r |cFFE2E8F0" .. tostring(s._cData.scope) .. "|r", 1, 1, 1)
                        GameTooltip:AddLine("|cFFF43F5ECurrent:|r " .. tostring(s._cData.existingBadge or "") .. " |cFFFFFFFF" .. tostring(s._cData.existingName or "") .. "|r", 1, 1, 1)
                        GameTooltip:AddLine("|cFF10B981New:|r " .. newBadge .. " |cFFFFFFFF" .. newNameStr .. "|r", 1, 1, 1)
                        GameTooltip:Show()
                    end
                end)
                row:SetScript("OnLeave", function(s)
                    SetPixelBackdrop(s, COLORS.BgElevated, { 1, 1, 1, 0.05 }, 1)
                    if GameTooltip then GameTooltip:Hide() end
                end)
                f.rows[i] = row
            end
            row._cData = c
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", f.scrollChild, "TOPLEFT", 0, -((i - 1) * stride))
            row:SetWidth(rowW)
            local exBdg = (c.existingBadge and c.existingBadge ~= "") and (tostring(c.existingBadge) .. " ") or ""
            row.fs:SetText(string.format(
                "|cFFFBBF24%s:|r  %s|cFFF43F5E%s|r  |cFF64748B->|r  %s |cFF10B981%s|r",
                tostring(c.scope),
                exBdg,
                tostring(c.existingName or ""),
                newBadge,
                newNameStr
            ))
            row:Show()
        end

        local totalH = math.max(stride, nConflicts * stride)
        local visH = (nConflicts >= 4) and 92 or math.max(stride, totalH)
        local boxH = visH + 12
        f._visH = visH
        f.scrollChild:SetHeight(totalH)
        f.scroll:SetVerticalScroll(0)
        f.box:SetHeight(boxH)
        f:SetHeight(148 + boxH)

        f.confirmBtn:SetScript("OnClick", function()
            f:Hide()
            if type(onConfirm) == "function" then onConfirm() end
        end)
        self._overwriteCatcher:Show()
        f:Show()
        f.UpdateScrollBar()
    end
end

function DynamicTalent:DuplicateTalentLibraryEntry(targetEntry)
    if not self.db then self:InitDB() end
    local specID = self:GetActiveSpecID()
    if not specID or type(targetEntry) ~= "table" then return nil end
    self.db.talentStringLibrary = self.db.talentStringLibrary or {}
    self.db.talentStringLibrary[specID] = self.db.talentStringLibrary[specID] or {}
    local rawLib = self.db.talentStringLibrary[specID]

    local baseName = tostring(targetEntry.name or "Loadout"):gsub("%s*%(Copy%s*%d*%)$", "")
    local existing = {}
    for _, it in ipairs(rawLib) do
        if type(it) == "table" and type(it.name) == "string" then
            existing[it.name:lower()] = true
        end
    end
    local copyName = baseName .. " (Copy)"
    local n = 2
    while existing[copyName:lower()] do
        copyName = string.format("%s (Copy %d)", baseName, n)
        n = n + 1
    end

    local clone = {
        id           = GenerateLoadoutID(self.db),
        name         = copyName,
        group        = NormalizeTalentGroupKey(targetEntry.group or "Custom"),
        importString = targetEntry.importString or "",
        liveHash     = targetEntry.liveHash or targetEntry.importString or "",
        heroAcronym  = targetEntry.heroAcronym,
        heroTreeName = targetEntry.heroTreeName,
        _heroStrHash = targetEntry._heroStrHash,
    }
    self:RefreshLoadoutHeroMeta(clone)
    table.insert(rawLib, clone)
    Print(string.format("Duplicated loadout as %s |cFFFFFFFF%s|r.", self:FormatTalentBadge(clone), copyName))
    self:SyncTalentBindsUI()
    return clone
end

function DynamicTalent:RenameLegacyTLMSlot()
    if IsPlayerInCombat() then
        Print("Cannot rename talent slots during combat.")
        return false
    end
    local specID = self:GetActiveSpecID()
    if not specID or not (C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID and C_ClassTalents.RenameConfig and C_Traits and C_Traits.GetConfigInfo) then
        return false
    end
    local ok, ids = pcall(C_ClassTalents.GetConfigIDsBySpecID, specID)
    if not ok or type(ids) ~= "table" then return false end
    for _, cid in ipairs(ids) do
        if not _IsSecret(cid) and type(cid) == "number" then
            local okI, info = pcall(C_Traits.GetConfigInfo, cid)
            if okI and type(info) == "table" and not _IsSecret(info.name) and info.name == "TalentLoadoutManager" then
                local okR = pcall(C_ClassTalents.RenameConfig, cid, "DynamicTalent")
                if okR then
                    Print("Renamed legacy Blizzard slot |cFFFBBF24TalentLoadoutManager|r -> |cFF10B981DynamicTalent|r.")
                    self:SyncTalentBindsUI()
                    return true
                end
            end
        end
    end
    return false
end

-- ============================================================================
-- 6. DECODE, APPLY, SHARE POPUP & PREP BAR CONTRACT
-- ============================================================================
function DynamicTalent:DecodeTalentImportString(importText)
    if type(importText) ~= "string" then return nil, "Empty talent string." end
    local clean = SafeTrim(importText)
    if clean == "" then return nil, "Empty talent string." end
    if not (_G.ExportUtil and type(_G.ExportUtil.MakeImportDataStream) == "function") then
        return nil, "Talent export tool is currently unavailable."
    end
    local activeCfg = nil
    if C_ClassTalents and type(C_ClassTalents.GetActiveConfigID) == "function" then
        local okCfg, rawCfg = pcall(C_ClassTalents.GetActiveConfigID)
        if okCfg and not _IsSecret(rawCfg) and type(rawCfg) == "number" and rawCfg > 0 then
            activeCfg = rawCfg
        end
    end
    if not activeCfg then return nil, "No active talent tree found." end

    local cfgInfo = nil
    if C_Traits and type(C_Traits.GetConfigInfo) == "function" then
        local okCI, rawInfo = pcall(C_Traits.GetConfigInfo, activeCfg)
        if okCI and type(rawInfo) == "table" then
            cfgInfo = rawInfo
        end
    end
    local treeID = cfgInfo and cfgInfo.treeIDs and cfgInfo.treeIDs[1]
    if _IsSecret(treeID) or type(treeID) ~= "number" or treeID <= 0 then
        return nil, "No active talent tree found."
    end

    local okStream, stream = pcall(_G.ExportUtil.MakeImportDataStream, clean)
    if not okStream or not stream or type(stream.ExtractValue) ~= "function" then
        return nil, "Invalid talent string format."
    end

    local function ReadBits(bits)
        local okV, val = pcall(stream.ExtractValue, stream, bits)
        if not okV or _IsSecret(val) or type(val) ~= "number" then return nil end
        return val
    end

    local expectedVer = 2
    if C_Traits and type(C_Traits.GetLoadoutSerializationVersion) == "function" then
        local okVer, rawVer = pcall(C_Traits.GetLoadoutSerializationVersion)
        if okVer and not _IsSecret(rawVer) and type(rawVer) == "number" then
            expectedVer = rawVer
        end
    end
    local ver = ReadBits(8)
    local strSpecID = ReadBits(16)
    if not ver or not strSpecID then return nil, "Invalid talent string format." end
    if ver ~= expectedVer then return nil, "This talent string is from an older game patch." end

    local activeSpecID = self:GetActiveSpecID()
    if not activeSpecID then
        return nil, "No active specialisation found."
    end
    if strSpecID ~= activeSpecID then
        return nil, "Wrong specialisation for this character."
    end

    for _ = 1, 16 do
        if ReadBits(8) == nil then
            return nil, "Incomplete talent string."
        end
    end

    local treeNodes = {}
    if C_Traits and type(C_Traits.GetTreeNodes) == "function" then
        local okTN, rawNodes = pcall(C_Traits.GetTreeNodes, treeID)
        if okTN and type(rawNodes) == "table" then
            treeNodes = rawNodes
        end
    end
    local entries = {}
    for _, nodeID in ipairs(treeNodes) do
        if not _IsSecret(nodeID) and type(nodeID) == "number" then
            local selVal = ReadBits(1)
            if selVal == 1 then
                local purVal = ReadBits(1)
                if purVal == 1 then
                    local partialVal = ReadBits(1)
                    local partialRanks = 0
                    if partialVal == 1 then
                        partialRanks = ReadBits(6) or 0
                    end
                    local choiceVal = ReadBits(1)
                    local choiceIdx = 1
                    if choiceVal == 1 then
                        choiceIdx = (ReadBits(2) or 0) + 1
                    end
                    table.insert(entries, {
                        nodeID       = nodeID,
                        isPartial    = (partialVal == 1),
                        partialRanks = partialRanks,
                        isChoice     = (choiceVal == 1),
                        choiceIdx    = choiceIdx,
                    })
                end
            end
        end
    end

    if #entries == 0 then
        return nil, "No talents found in this import string."
    end
    return {
        configID = activeCfg,
        treeID   = treeID,
        specID   = strSpecID,
        entries  = entries,
    }, nil
end

function DynamicTalent:ApplyTalentLibraryEntry(entry)
    if not entry or type(entry.importString) ~= "string" or entry.importString == "" then return end
    if IsPlayerInCombat() then
        Print("Cannot switch Talent Loadouts during combat.")
        return
    end
    if IsMythicPlusActive() then
        Print("Cannot switch Talent Loadouts during an active Mythic+ run.")
        return
    end
    local specID = self:GetActiveSpecID()
    if not specID then
        Print("No active specialisation found.")
        return
    end
    local targetEntry = nil
    if type(entry.id) == "string" and entry.id ~= "" then
        targetEntry = self:FindLibraryEntryByID(entry.id, specID)
    end
    if not targetEntry then
        targetEntry = self:FindLibraryEntryForRule(entry, specID)
    end
    targetEntry = targetEntry or entry

    local api = _G.TalentLoadoutManagerAPI
    if type(api) == "table" and type(api.GlobalAPI) == "table" and type(api.CharacterAPI) == "table" then
        local okL, list = pcall(api.GlobalAPI.GetLoadouts, api.GlobalAPI, specID)
        if okL and type(list) == "table" then
            for _, lo in ipairs(list) do
                if type(lo) == "table" and lo.id and lo.name == targetEntry.name then
                    pcall(api.CharacterAPI.LoadLoadout, api.CharacterAPI, lo.id, true)
                    self.db.lastAppliedTalentID = self.db.lastAppliedTalentID or {}
                    self.db.lastAppliedTalentID[specID] = EnsureEntryID(targetEntry, self.db)
                    self.db.lastAppliedTalentName = self.db.lastAppliedTalentName or {}
                    self.db.lastAppliedTalentName[specID] = targetEntry.name
                    self:SyncTalentBindsUI()
                    return
                end
            end
        end
    end

    local decoded, errMsg = self:DecodeTalentImportString(entry.importString)
    if not decoded then
        Print(string.format("Could not apply |cFFFBBF24%s|r (%s).", tostring(entry.name or "Loadout"), tostring(errMsg or "invalid string")))
        return
    end

    local configID = decoded.configID
    local treeID = decoded.treeID
    if not (C_Traits and C_Traits.ResetTree and C_Traits.GetNodeInfo and C_ClassTalents and C_ClassTalents.CommitConfig) then
        return
    end

    pcall(C_Traits.ResetTree, configID, treeID)

    local subTreeEnum = (_G.Enum and _G.Enum.TraitNodeType and _G.Enum.TraitNodeType.SubTreeSelection) or 3
    local selEnum     = (_G.Enum and _G.Enum.TraitNodeType and _G.Enum.TraitNodeType.Selection) or 2

    local remaining = {}
    for _, ne in ipairs(decoded.entries) do
        local okN, info = pcall(C_Traits.GetNodeInfo, configID, ne.nodeID)
        if okN and type(info) == "table" and not _IsSecret(info.type) and info.type == subTreeEnum then
            local eID = info.entryIDs and info.entryIDs[ne.choiceIdx] or (info.entryIDs and info.entryIDs[1])
            if eID and not _IsSecret(eID) and C_Traits.SetSelection then
                pcall(C_Traits.SetSelection, configID, ne.nodeID, eID)
            end
        else
            table.insert(remaining, ne)
        end
    end

    for _ = 1, 6 do
        if #remaining == 0 then break end
        local nextRem = {}
        local progress = false
        for _, ne in ipairs(remaining) do
            local okN, info = pcall(C_Traits.GetNodeInfo, configID, ne.nodeID)
            if okN and type(info) == "table" then
                local rawMax = (not _IsSecret(info.maxRanks) and type(info.maxRanks) == "number") and info.maxRanks or 1
                local targetRanks = ne.isPartial and math.max(1, ne.partialRanks) or math.max(1, rawMax)
                local curRanks = (not _IsSecret(info.ranksPurchased) and type(info.ranksPurchased) == "number") and info.ranksPurchased or 0
                if curRanks < targetRanks then
                    if (ne.isChoice or (not _IsSecret(info.type) and info.type == selEnum)) and info.entryIDs then
                        local eID = info.entryIDs[ne.choiceIdx] or info.entryIDs[1]
                        if eID and not _IsSecret(eID) and C_Traits.SetSelection then
                            local okS, resS = pcall(C_Traits.SetSelection, configID, ne.nodeID, eID)
                            if okS and not _IsSecret(resS) and resS then progress = true end
                        end
                    end
                    local okA, afterInfo = pcall(C_Traits.GetNodeInfo, configID, ne.nodeID)
                    local afterRanks = (okA and type(afterInfo) == "table" and not _IsSecret(afterInfo.ranksPurchased) and type(afterInfo.ranksPurchased) == "number")
                        and afterInfo.ranksPurchased or curRanks
                    while afterRanks < targetRanks do
                        local okP, resP = pcall(C_Traits.PurchaseRank, configID, ne.nodeID)
                        if okP and not _IsSecret(resP) and resP then
                            afterRanks = afterRanks + 1
                            progress = true
                        else
                            break
                        end
                    end
                    local okChk, checkInfo = pcall(C_Traits.GetNodeInfo, configID, ne.nodeID)
                    local chkRanks = (okChk and type(checkInfo) == "table" and not _IsSecret(checkInfo.ranksPurchased) and type(checkInfo.ranksPurchased) == "number")
                        and checkInfo.ranksPurchased or nil
                    if not chkRanks or chkRanks < targetRanks then
                        table.insert(nextRem, ne)
                    end
                end
            end
        end
        remaining = nextRem
        if not progress then break end
    end

    local okCommit, committed = pcall(C_ClassTalents.CommitConfig, configID)
    if okCommit and not _IsSecret(committed) and committed then
        self:InvalidateActiveTalentStringCache()
        self._pendingSaveConfigID = configID
        self._pendingAppliedEntry = targetEntry
        self._pendingAppliedSpecID = specID
        self.db.lastAppliedTalentID = self.db.lastAppliedTalentID or {}
        self.db.lastAppliedTalentID[specID] = EnsureEntryID(targetEntry, self.db)
        self.db.lastAppliedTalentName = self.db.lastAppliedTalentName or {}
        self.db.lastAppliedTalentName[specID] = targetEntry.name
        Print(string.format("Switching to %s |cFFFFFFFF%s|r...", self:FormatTalentBadge(targetEntry), tostring(targetEntry.name or "Loadout")))
        self:SyncTalentBindsUI()
    end
end

function DynamicTalent:ShowShareTalentPopup(title, exportStr)
    if not exportStr or exportStr == "" then
        Print("No active talent export string available.")
        return
    end
    if not self._sharePopup then
        local ar, ag, ab = GetActiveAccentRGB()
        local f = CreateFrame("Frame", "DynamicTalentSharePopup", UIParent, "BackdropTemplate")
        f:SetSize(420, 96)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        SetPixelBackdrop(f, { 0.031, 0.039, 0.055, 0.98 }, { ar, ag, ab, 0.92 }, 1)
        if _G.UISpecialFrames then
            table.insert(_G.UISpecialFrames, "DynamicTalentSharePopup")
        end
        f.hdr = CreateText(f, "OVERLAY", "GameFontHighlightSmall")
        f.hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
        f.eb = CreateFrame("EditBox", nil, f, "BackdropTemplate")
        f.eb:SetSize(396, 26)
        f.eb:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -34)
        f.eb:SetFontObject("GameFontHighlightSmall")
        f.eb:SetTextInsets(6, 6, 0, 0)
        SetPixelBackdrop(f.eb, { 0.043, 0.051, 0.071, 0.98 }, COLORS.BorderSubtle, 1)
        f.eb:SetScript("OnEscapePressed", function() f:Hide() end)
        local close = CreateFrame("Button", nil, f, "BackdropTemplate")
        close:SetSize(72, 22)
        close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 8)
        SetPixelBackdrop(close, COLORS.BgElevated, COLORS.BorderSubtle, 1)
        close.txt = CreateText(close, "OVERLAY", "GameFontHighlightSmall")
        close.txt:SetPoint("CENTER")
        close.txt:SetText("Close")
        close:SetScript("OnClick", function() f:Hide() end)
        self._sharePopup = f
    end
    local ar, ag, ab = GetActiveAccentRGB()
    SetPixelBackdrop(self._sharePopup, { 0.031, 0.039, 0.055, 0.98 }, { ar, ag, ab, 0.92 }, 1)
    self._sharePopup.hdr:SetText("|cFF38BDF8Share Loadout (Press Ctrl+C):|r  " .. tostring(title or "Active Build"))
    self._sharePopup.eb:SetText(exportStr)
    self._sharePopup:Show()
    self._sharePopup.eb:SetFocus()
    self._sharePopup.eb:HighlightText()
end

function DynamicTalent:GetTalentLoadoutBarData()
    local specID = self:GetActiveSpecID()
    local _, _, _, accentHex = GetActiveAccentRGB()
    local activeName = "Default"
    local activeID = nil

    local api = _G.TalentLoadoutManagerAPI
    if type(api) == "table" and type(api.CharacterAPI) == "table" and type(api.CharacterAPI.GetActiveLoadoutInfo) == "function" then
        local okT, info = pcall(api.CharacterAPI.GetActiveLoadoutInfo, api.CharacterAPI)
        if okT and not _IsSecret(info) and type(info) == "table" and not _IsSecret(info.name) and type(info.name) == "string" and info.name ~= "" then
            activeName = info.name
        end
    end

    if activeName == "Default" or activeName == "TalentLoadoutManager" or activeName == "DynamicPrep" or activeName == "DynamicTalent" then
        local activeLibEntry = self:GetActiveTalentLibraryEntry(specID)
        if activeLibEntry and type(activeLibEntry.name) == "string" and activeLibEntry.name ~= "" then
            activeName = activeLibEntry.name
        end
    end

    if activeName == "Default" and specID and C_ClassTalents and type(C_ClassTalents.GetLastSelectedSavedConfigID) == "function" then
        local ok, cid = pcall(C_ClassTalents.GetLastSelectedSavedConfigID, specID)
        if ok and not _IsSecret(cid) and type(cid) == "number" and cid > 0 then
            activeID = cid
            if C_Traits and type(C_Traits.GetConfigInfo) == "function" then
                local okI, info = pcall(C_Traits.GetConfigInfo, cid)
                if okI and type(info) == "table" and not _IsSecret(info.name) and type(info.name) == "string" and info.name ~= "" then
                    activeName = info.name
                end
            end
        end
    end
    local activeLibEntry = self:GetActiveTalentLibraryEntry(specID)
    local activeGrp = (activeLibEntry and activeLibEntry.group) or nil

    local mID, mName = self:GetActiveTalentMismatch()
    if mID and mName then
        local shortTgt = mName
        if #shortTgt > 16 then shortTgt = shortTgt:sub(1, 15) .. "." end
        if type(mID) == "table" and mID.group then
            local mEntry = self:FindLibraryEntryForRule(mID, specID) or mID
            local mBindTag = self:GetLoadoutBindBadgeText(mEntry, specID)
            if mBindTag and #mBindTag <= 14 then
                return string.format("|cFFFBBF24Swap ->|r %s |cFFFFFFFF%s|r |cFFFBBF24%s|r", self:FormatTalentBadge(mID), shortTgt, mBindTag), activeName, activeID, true
            end
            return string.format("|cFFFBBF24Swap ->|r %s |cFFFFFFFF%s|r", self:FormatTalentBadge(mID), shortTgt), activeName, activeID, true
        end
        return string.format("|cFFFBBF24Swap -> %s|r", shortTgt), activeName, activeID, true
    end
    local display = activeName
    if #display > 16 then display = display:sub(1, 15) .. "." end
    if activeLibEntry and activeGrp then
        local bindTag = self:GetLoadoutBindBadgeText(activeLibEntry, specID)
        if bindTag then
            return string.format("%s |cFFFFFFFF%s|r |cFFFBBF24%s|r", self:FormatTalentBadge(activeLibEntry), display, bindTag), activeName, activeID, false
        end
        return string.format("%s |cFFFFFFFF%s|r", self:FormatTalentBadge(activeLibEntry), display), activeName, activeID, false
    end
    local liveAcr = self:GetLiveHeroTreeInfo()
    if liveAcr then
        return string.format("|cFF94A3B8Talent|r |cFF64748B[%s]|r |cFF%s%s|r", liveAcr, accentHex, display), activeName, activeID, false
    end
    return string.format("|cFF94A3B8Talent|r |cFF%s%s|r", accentHex, display), activeName, activeID, false
end

function DynamicTalent:GetPrepBarCapsuleData()
    local db = EnsureDB()
    if db.enabled == false or IsModuleDisabledInSuite("DynamicTalent") then
        return "|cFF94A3B8Talents|r", false
    end
    local tText, _, _, isMismatch = self:GetTalentLoadoutBarData()
    return tText, (isMismatch == true)
end

function DynamicTalent:PopulatePrepBarTooltip(tooltip)
    if not tooltip then return end
    local ar, ag, ab, accentHex = GetActiveAccentRGB()
    local specID = self:GetActiveSpecID()
    local activeLibEntry = self:GetActiveTalentLibraryEntry(specID)
    local _, activeName = self:GetTalentLoadoutBarData()
    local mID, mName, mLabel = self:GetActiveTalentMismatch()
    local activeDisplay = activeLibEntry
        and string.format("%s %s", self:FormatTalentBadge(activeLibEntry), tostring(activeLibEntry.name or activeName or "Default"))
        or tostring(activeName or "Default")

    tooltip:AddLine("Talent Loadout Quick-Switcher", ar, ag, ab)
    tooltip:AddDoubleLine("Active Loadout:", activeDisplay, 0.8, 0.84, 0.88, 1, 1, 1)
    if activeLibEntry then
        local heroAcr, heroName = self:GetLoadoutHeroAcronym(activeLibEntry)
        if heroName and heroAcr then
            tooltip:AddLine(string.format("|cFF94A3B8Hero Tree:|r |cFFE2E8F0%s (%s)|r", tostring(heroName), tostring(heroAcr)), 1, 1, 1)
        end
        local bInfo = self:GetLoadoutBindings(activeLibEntry, specID)
        if bInfo and bInfo.detailLines and #bInfo.detailLines > 0 then
            for _, bl in ipairs(bInfo.detailLines) do
                tooltip:AddLine("|cFFFBBF24Bound:|r |cFFE2E8F0" .. bl .. "|r", 1, 1, 1)
            end
        else
            tooltip:AddLine("|cFF94A3B8Bound:|r |cFF64748BUnbound|r", 1, 1, 1)
        end
    end
    if mID then
        local recDisplay = (type(mID) == "table" and mID.group)
            and string.format("%s %s", self:FormatTalentBadge(mID), tostring(mName or "Loadout"))
            or tostring(mName or "Loadout")
        tooltip:AddDoubleLine("Recommended (" .. tostring(mLabel or "Zone") .. "):", recDisplay, 0.984, 0.749, 0.141, 0.984, 0.749, 0.141)
        tooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Swap Immediately to " .. tostring(mName or "Loadout") .. "|r", 1, 1, 1)
        tooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Silence This Reminder for Session|r", 1, 1, 1)
    else
        tooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Open 1-Click Talent Loadout Switcher|r", 1, 1, 1)
        tooltip:AddLine(string.format("|cFF%sRight-Click:|r |cFFE2E8F0Open Talent Binds & Loadout Manager|r", accentHex), 1, 1, 1)
    end
end

function DynamicTalent:HandlePrepBarClick(segButton, button)
    local mTarget, _, mLabel, mKey = self:GetActiveTalentMismatch()
    if mTarget then
        if button == "RightButton" then
            self:SilenceTalentMismatch(mKey, mLabel)
            if _G.DynamicPrep and type(_G.DynamicPrep.RefreshBar) == "function" then
                pcall(_G.DynamicPrep.RefreshBar, _G.DynamicPrep)
            end
        else
            if _G.DynamicPrep and type(_G.DynamicPrep.HideBarPopovers) == "function" then
                pcall(_G.DynamicPrep.HideBarPopovers, _G.DynamicPrep)
            end
            if type(mTarget) == "table" then
                self:ApplyTalentLibraryEntry(mTarget)
            elseif not IsPlayerInCombat() and not IsMythicPlusActive() and C_ClassTalents and C_ClassTalents.LoadConfig then
                pcall(C_ClassTalents.LoadConfig, mTarget, true)
                self:InvalidateActiveTalentStringCache()
            end
        end
    elseif button == "RightButton" then
        if _G.DynamicPrep and type(_G.DynamicPrep.HideBarPopovers) == "function" then
            pcall(_G.DynamicPrep.HideBarPopovers, _G.DynamicPrep)
        end
        self:OpenTalentManagerModal(2)
    else
        self:ToggleTalentPopover(segButton)
    end
end

function DynamicTalent:IsTalentPopoverShown()
    return (talentPopoverFrame and talentPopoverFrame:IsShown()) and true or false
end

function DynamicTalent:HideTalentPopover()
    if talentPopoverFrame then talentPopoverFrame:Hide() end
end

local function SyncPrepPopoverClickCatcherOnHide()
    local dp = _G.DynamicPrep
    if dp and dp.popoverClickCatcher then
        local anyShown = false
        if type(dp.AreAnyBarPopoversShown) == "function" then
            local okA, resA = pcall(dp.AreAnyBarPopoversShown, dp)
            anyShown = (okA and resA == true)
        end
        if not anyShown and type(dp.popoverClickCatcher.Hide) == "function" then
            dp.popoverClickCatcher:Hide()
        end
    end
end

function DynamicTalent:ToggleTalentPopover(anchor)
    if IsPlayerInCombat() then
        Print("Cannot switch Talent Loadouts during combat.")
        return
    end
    if talentPopoverFrame and talentPopoverFrame:IsShown() then
        talentPopoverFrame:Hide()
        SyncPrepPopoverClickCatcherOnHide()
        return
    end
    if anchor and type(anchor.HookScript) == "function" and not anchor._dtPopoverOnHideHooked then
        anchor._dtPopoverOnHideHooked = true
        anchor:HookScript("OnHide", function()
            if talentPopoverFrame and talentPopoverFrame:IsShown() then
                talentPopoverFrame:Hide()
            end
        end)
    end
    if _G.DynamicPrep and type(_G.DynamicPrep.HideBarPopovers) == "function" then
        pcall(_G.DynamicPrep.HideBarPopovers, _G.DynamicPrep)
    end
    local ar, ag, ab = GetActiveAccentRGB()
    if not talentPopoverFrame then
        local p = CreateFrame("Frame", "DynamicTalentPopover", UIParent, "BackdropTemplate")
        p:SetWidth(276)
        p:SetFrameStrata("TOOLTIP")
        p:SetFrameLevel(220)
        p:EnableMouse(true)
        p:SetClampedToScreen(true)
        if type(_G.UISpecialFrames) == "table" then
            local seen = false
            for _, n in ipairs(_G.UISpecialFrames) do
                if n == "DynamicTalentPopover" then seen = true; break end
            end
            if not seen then table.insert(_G.UISpecialFrames, "DynamicTalentPopover") end
        end
        p:SetScript("OnHide", SyncPrepPopoverClickCatcherOnHide)

        p.scroll = CreateFrame("ScrollFrame", nil, p)
        p.scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -8)
        p.scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -14, 38)
        p.scroll:EnableMouseWheel(true)

        p.content = CreateFrame("Frame", nil, p.scroll)
        p.content:SetWidth(254)
        p.scroll:SetScrollChild(p.content)

        p.track = CreateFrame("Frame", nil, p, "BackdropTemplate")
        p.track:SetWidth(4)
        p.track:SetPoint("TOPRIGHT", p, "TOPRIGHT", -5, -10)
        p.track:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -5, 40)
        SetPixelBackdrop(p.track, { 0.043, 0.051, 0.071, 0.90 }, { 0, 0, 0, 0 }, 0)
        p.thumb = p.track:CreateTexture(nil, "OVERLAY")
        p.thumb:SetWidth(4)
        p.thumb:SetPoint("TOP", p.track, "TOP", 0, 0)

        p.UpdateScroll = function()
            local vh = p.scroll:GetHeight() or 1
            local th = p.content:GetHeight() or 1
            local maxS = math.max(0, th - vh)
            if maxS <= 1 then p.track:Hide(); return end
            p.track:Show()
            local cur = math.max(0, math.min(maxS, p.scroll:GetVerticalScroll() or 0))
            local trH = p.track:GetHeight() or 1
            local tbH = math.max(20, math.floor(trH * (vh / th)))
            p.thumb:SetHeight(tbH)
            p.thumb:ClearAllPoints()
            p.thumb:SetPoint("TOP", p.track, "TOP", 0, -math.floor((cur / maxS) * math.max(1, trH - tbH)))
        end
        p.scroll:SetScript("OnMouseWheel", function(selfS, delta)
            local maxS = math.max(0, (p.content:GetHeight() or 1) - (selfS:GetHeight() or 1))
            selfS:SetVerticalScroll(math.max(0, math.min(maxS, (selfS:GetVerticalScroll() or 0) - (delta * 32))))
            p.UpdateScroll()
        end)

        p.footerBtn = CreateFrame("Button", nil, p, "BackdropTemplate")
        p.footerBtn:SetHeight(24)
        p.footerBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 8, 8)
        p.footerBtn:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -8, 8)
        p.footerBtn.txt = CreateText(p.footerBtn, "OVERLAY", "GameFontHighlightSmall")
        p.footerBtn.txt:SetPoint("CENTER")
        p.footerBtn.txt:SetText("Import / Talent Binds...")
        p.footerBtn:SetScript("OnClick", function()
            p:Hide()
            DynamicTalent:OpenTalentManagerModal(1)
        end)

        p.rows = {}
        talentPopoverFrame = p
    end

    local p = talentPopoverFrame
    SetPixelBackdrop(p, { 0.031, 0.039, 0.055, 0.98 }, { ar, ag, ab, 0.90 }, 1)
    p.thumb:SetColorTexture(ar, ag, ab, 0.85)
    SetPixelBackdrop(p.footerBtn, { ar * 0.38, ag * 0.38, ab * 0.38, 0.98 }, { ar, ag, ab, 0.95 }, 1)
    for _, r in ipairs(p.rows) do r:Hide() end

    local specID = self:GetActiveSpecID()
    local sortedLib = self:GetSortedTalentProfiles(specID, true)
    local activeLibEntry = self:GetActiveTalentLibraryEntry(specID)
    local _, activeBarName = self:GetTalentLoadoutBarData()

    local rowIdx = 0
    local function EnsureRow()
        rowIdx = rowIdx + 1
        local btn = p.rows[rowIdx]
        if not btn then
            btn = CreateFrame("Button", nil, p.content, "BackdropTemplate")
            btn:SetSize(250, 23)
            btn.dot = btn:CreateTexture(nil, "OVERLAY")
            btn.dot:SetSize(6, 6)
            btn.dot:SetPoint("LEFT", btn, "LEFT", 7, 0)
            btn.bindTag = CreateText(btn, "OVERLAY", "GameFontHighlightSmall")
            btn.bindTag:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
            btn.bindTag:SetJustifyH("RIGHT")
            btn.bindTag:SetWordWrap(false)
            btn.bindTag:Hide()
            btn.txt = CreateText(btn, "OVERLAY", "GameFontHighlightSmall")
            btn.txt:SetPoint("LEFT", btn.dot, "RIGHT", 6, 0)
            btn.txt:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
            btn.txt:SetJustifyH("LEFT")
            btn.txt:SetWordWrap(false)
            p.rows[rowIdx] = btn
        end
        btn.bindTag:Hide()
        btn.txt:ClearAllPoints()
        btn.txt:SetPoint("LEFT", btn.dot, "RIGHT", 6, 0)
        btn.txt:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
        btn:SetScript("OnEnter", nil)
        btn:SetScript("OnLeave", nil)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", p.content, "TOPLEFT", 0, -((rowIdx - 1) * 25))
        return btn
    end

    for _, entry in ipairs(sortedLib) do
        local btn = EnsureRow()
        local isAct = (activeLibEntry and activeLibEntry == entry) or (not activeLibEntry and activeBarName and activeBarName == entry.name)
        local tagText, bInfo = self:GetLoadoutBindBadgeText(entry, specID)
        local heroAcr, heroName = self:GetLoadoutHeroAcronym(entry)
        local badgePrefix = self:FormatTalentBadge(entry, heroAcr)

        btn.dot:SetColorTexture(isAct and 0.063 or 0.40, isAct and 0.725 or 0.46, isAct and 0.506 or 0.56, 1)
        if tagText then
            btn.bindTag:SetText("|cFFFBBF24" .. tagText .. "|r")
            btn.bindTag:Show()
            btn.txt:SetPoint("RIGHT", btn.bindTag, "LEFT", -4, 0)
        end
        btn.txt:SetText(string.format("%s %s", badgePrefix, tostring(entry.name)))
        btn.txt:SetTextColor(isAct and 1 or 0.88, isAct and 1 or 0.92, isAct and 1 or 0.96, 1)

        local idleBg = isAct and { 0.063 * 0.35, 0.725 * 0.35, 0.506 * 0.35, 0.96 } or COLORS.BgElevated
        local idleBdr = isAct and { 0.063, 0.725, 0.506, 0.95 } or COLORS.BorderSubtle
        SetPixelBackdrop(btn, idleBg, idleBdr, 1)

        btn:SetScript("OnEnter", function(s)
            SetPixelBackdrop(s, { ar * 0.24, ag * 0.24, ab * 0.24, 0.98 }, { ar, ag, ab, 0.95 }, 1)
            if GameTooltip then
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                GameTooltip:AddLine(string.format("%s %s", badgePrefix, tostring(entry.name or "Loadout")) .. (isAct and "  |cFF34D399(Active)|r" or ""), 1, 1, 1)
                if heroName and heroAcr then
                    GameTooltip:AddLine(string.format("|cFF94A3B8Hero Tree:|r |cFFE2E8F0%s (%s)|r", tostring(heroName), tostring(heroAcr)), 1, 1, 1)
                end
                if bInfo and bInfo.detailLines and #bInfo.detailLines > 0 then
                    for _, bl in ipairs(bInfo.detailLines) do
                        GameTooltip:AddLine("|cFFFBBF24Bound:|r |cFFE2E8F0" .. bl .. "|r", 1, 1, 1)
                    end
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Switch to this Talent Loadout|r", 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function(s)
            SetPixelBackdrop(s, idleBg, idleBdr, 1)
            if GameTooltip then GameTooltip:Hide() end
        end)
        btn:SetScript("OnClick", function()
            p:Hide()
            DynamicTalent:ApplyTalentLibraryEntry(entry)
        end)
        btn:Show()
    end

    if #sortedLib == 0 then
        local blizzList = self:GetSavedTalentLoadouts()
        local curID = nil
        if specID and C_ClassTalents and type(C_ClassTalents.GetLastSelectedSavedConfigID) == "function" then
            local okC, rawCid = pcall(C_ClassTalents.GetLastSelectedSavedConfigID, specID)
            if okC and not _IsSecret(rawCid) and type(rawCid) == "number" then
                curID = rawCid
            end
        end
        for _, item in ipairs(blizzList) do
            local btn = EnsureRow()
            local isAct = (curID == item.id)
            btn.dot:SetColorTexture(isAct and 0.063 or 0.35, isAct and 0.725 or 0.42, isAct and 0.506 or 0.52, 1)
            btn.txt:SetText(item.name)
            btn.txt:SetTextColor(isAct and 1 or 0.85, isAct and 1 or 0.89, isAct and 1 or 0.95, 1)
            local idleBg = isAct and { ar * 0.32, ag * 0.32, ab * 0.32, 0.96 } or COLORS.BgElevated
            local idleBdr = isAct and { ar, ag, ab, 0.90 } or COLORS.BorderSubtle
            SetPixelBackdrop(btn, idleBg, idleBdr, 1)
            btn:SetScript("OnEnter", function(s)
                SetPixelBackdrop(s, { ar * 0.24, ag * 0.24, ab * 0.24, 0.98 }, { ar, ag, ab, 0.95 }, 1)
            end)
            btn:SetScript("OnLeave", function(s)
                SetPixelBackdrop(s, idleBg, idleBdr, 1)
            end)
            btn:SetScript("OnClick", function()
                p:Hide()
                if not IsPlayerInCombat() and not IsMythicPlusActive() and C_ClassTalents and C_ClassTalents.LoadConfig then
                    pcall(C_ClassTalents.LoadConfig, item.id, true)
                    DynamicTalent:InvalidateActiveTalentStringCache()
                end
            end)
            btn:Show()
        end
    end

    if type(_G.TalentLoadoutManagerAPI) == "table" then
        local tlmRow = EnsureRow()
        tlmRow.dot:SetColorTexture(0.063, 0.725, 0.506, 1)
        tlmRow.txt:SetText("Import All from Talent Loadout Manager")
        tlmRow.txt:SetTextColor(0.55, 0.98, 0.78, 1)
        local tlmBg = { 0.063 * 0.25, 0.725 * 0.25, 0.506 * 0.25, 0.96 }
        local tlmBdr = { 0.063, 0.725, 0.506, 0.85 }
        SetPixelBackdrop(tlmRow, tlmBg, tlmBdr, 1)
        tlmRow:SetScript("OnEnter", function(s)
            SetPixelBackdrop(s, { 0.063 * 0.40, 0.725 * 0.40, 0.506 * 0.40, 0.98 }, { 0.063, 0.725, 0.506, 1.0 }, 1)
        end)
        tlmRow:SetScript("OnLeave", function(s)
            SetPixelBackdrop(s, tlmBg, tlmBdr, 1)
        end)
        tlmRow:SetScript("OnClick", function()
            p:Hide()
            DynamicTalent:ImportFromTalentLoadoutManager()
        end)
        tlmRow:Show()
    end

    local contentH = math.max(28, rowIdx * 25)
    p.content:SetHeight(contentH)
    p.scroll:SetVerticalScroll(0)
    local totalH = math.min(368, contentH + 48)
    p:SetHeight(totalH)
    p:ClearAllPoints()
    if anchor then
        local uiW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
        local aRight = (anchor.GetRight and anchor:GetRight()) or 0
        if aRight > (uiW * 0.65) then
            p:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
        else
            p:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
        end
    else
        p:SetPoint("CENTER")
    end
    if _G.DynamicPrep and type(_G.DynamicPrep.EnsurePopoverClickCatcher) == "function" then
        local okC, catcher = pcall(_G.DynamicPrep.EnsurePopoverClickCatcher, _G.DynamicPrep)
        if okC and catcher and type(catcher.Show) == "function" then
            catcher:Show()
        end
    end
    p:Show()
    if C_Timer and C_Timer.After then C_Timer.After(0, p.UpdateScroll) end
end

-- ============================================================================
-- 7. LEFT-DOCKED TALENT LOADOUTS PANEL ON BLIZZARD'S PlayerSpellsFrame
-- ============================================================================
local talentDockFrame = nil
local talentDockHooked = false
local pendingDockRefresh = false
local pendingBackdropRefresh = false
local talentRowMenuFrame = nil
local talentRowMenuCatcher = nil

function DynamicTalent:HideTalentRowContextMenu()
    if talentRowMenuFrame then talentRowMenuFrame:Hide() end
    if talentRowMenuCatcher then talentRowMenuCatcher:Hide() end
end

function DynamicTalent:ShowTalentRowContextMenu(anchorRow, entry)
    if not anchorRow or type(entry) ~= "table" then return end
    local ar, ag, ab = GetActiveAccentRGB()

    if not talentRowMenuCatcher then
        local c = CreateFrame("Button", "DynamicTalentRowMenuCatcher", UIParent)
        c:SetAllPoints(UIParent)
        c:SetFrameStrata("FULLSCREEN_DIALOG")
        c:SetFrameLevel(10)
        c:EnableMouse(true)
        c:RegisterForClicks("AnyDown")
        c:SetScript("OnClick", function() DynamicTalent:HideTalentRowContextMenu() end)
        c:Hide()
        talentRowMenuCatcher = c
    end

    if not talentRowMenuFrame then
        local m = CreateFrame("Frame", "DynamicTalentRowContextMenu", UIParent, "BackdropTemplate")
        m:SetWidth(232)
        m:SetFrameStrata("TOOLTIP")
        m:SetFrameLevel(50)
        m:EnableMouse(true)
        m:SetClampedToScreen(true)
        m.hdr = CreateText(m, "OVERLAY", "GameFontHighlightSmall")
        m.hdr:SetPoint("TOPLEFT", m, "TOPLEFT", 10, -8)
        m.hdr:SetPoint("TOPRIGHT", m, "TOPRIGHT", -10, -8)
        m.hdr:SetJustifyH("LEFT")
        m.hdr:SetWordWrap(false)
        m.div = m:CreateTexture(nil, "ARTWORK")
        m.div:SetHeight(1)
        m.div:SetPoint("TOPLEFT", m, "TOPLEFT", 8, -24)
        m.div:SetPoint("TOPRIGHT", m, "TOPRIGHT", -8, -24)
        m.div:SetColorTexture(1, 1, 1, 0.08)
        m.btns = {}
        m.secDivs = {}
        m:Hide()
        if _G.UISpecialFrames then
            table.insert(_G.UISpecialFrames, "DynamicTalentRowContextMenu")
        end
        m:SetScript("OnHide", function()
            if talentRowMenuCatcher then talentRowMenuCatcher:Hide() end
        end)
        if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.RegisterPopupCloser) == "function" then
            _G.DynamicSuite.UI.RegisterPopupCloser("DynamicTalentRowMenu", function()
                DynamicTalent:HideTalentRowContextMenu()
            end)
        end
        talentRowMenuFrame = m
    end

    local m = talentRowMenuFrame
    m:SetWidth(238)
    SetPixelBackdrop(m, { 0.031, 0.039, 0.055, 0.99 }, { ar, ag, ab, 0.92 }, 1)
    m.hdr:SetText(string.format("%s %s", DynamicTalent:FormatTalentBadge(entry), tostring(entry.name or "Loadout")))

    local actions = {
        {
            label = "Rename / Edit Build",
            color = { 0.94, 0.96, 1.00 },
            divAfter = true,
            fn = function()
                DynamicTalent:HideTalentRowContextMenu()
                DynamicTalent:OpenTalentManagerModal(1, entry)
            end,
        },
        {
            label = "Quick Assign: All Content Default",
            color = { 0.204, 0.827, 0.600 },
            fn = function()
                DynamicTalent:HideTalentRowContextMenu()
                local conflicts = DynamicTalent:DetectBindConflicts("ALL_CONTENT", nil, entry)
                DynamicTalent:ConfirmBindOverwrite(conflicts, entry, function()
                    DynamicTalent:SetAllContentDefault(entry)
                end)
            end,
        },
        {
            label = "Quick Assign: All Raid Default",
            color = { 0.973, 0.443, 0.443 },
            fn = function()
                DynamicTalent:HideTalentRowContextMenu()
                local conflicts = DynamicTalent:DetectBindConflicts("ALL_RAID", { diffState = { normal = true, heroic = true, mythic = true } }, entry)
                DynamicTalent:ConfirmBindOverwrite(conflicts, entry, function()
                    DynamicTalent:SetAllRaidDefault(entry)
                end)
            end,
        },
        {
            label = "Quick Assign: All M+ Default",
            color = { 0.220, 0.741, 0.973 },
            fn = function()
                DynamicTalent:HideTalentRowContextMenu()
                local conflicts = DynamicTalent:DetectBindConflicts("ALL_MPLUS", { keyTier = "ANY" }, entry)
                DynamicTalent:ConfirmBindOverwrite(conflicts, entry, function()
                    DynamicTalent:SetAllMPlusDefault(entry, "ANY")
                end)
            end,
        },
        {
            label = "Quick Assign: All PvP Default",
            color = { 0.659, 0.333, 0.969 },
            fn = function()
                DynamicTalent:HideTalentRowContextMenu()
                local conflicts = DynamicTalent:DetectBindConflicts("PVP_LIST", { pvpKeys = { "all" } }, entry)
                DynamicTalent:ConfirmBindOverwrite(conflicts, entry, function()
                    DynamicTalent:SetPvPDefaults(entry, { all = true }, false)
                end)
            end,
        },
        {
            label = "Bind to Specific Boss / M+ / PvP...",
            color = { 0.984, 0.749, 0.141 },
            divAfter = true,
            fn = function()
                DynamicTalent:HideTalentRowContextMenu()
                DynamicTalent:OpenTalentManagerModal(2, entry)
            end,
        },
        {
            label = "Save Current Tree Here",
            color = { 0.204, 0.827, 0.600 },
            fn = function()
                DynamicTalent:HideTalentRowContextMenu()
                DynamicTalent:SaveCurrentTreeOverEntry(entry)
            end,
        },
        {
            label = "Duplicate Loadout",
            color = { 0.659, 0.333, 0.969 },
            fn = function()
                DynamicTalent:HideTalentRowContextMenu()
                DynamicTalent:DuplicateTalentLibraryEntry(entry)
            end,
        },
        {
            label = "Share Export String",
            color = { 0.220, 0.741, 0.973 },
            fn = function()
                DynamicTalent:HideTalentRowContextMenu()
                DynamicTalent:ShowShareTalentPopup(entry.name, entry.importString)
            end,
        },
        {
            label = "Delete Loadout",
            color = { 0.973, 0.443, 0.443 },
            fn = function()
                DynamicTalent:HideTalentRowContextMenu()
                DynamicTalent:DeleteTalentLibraryEntry(entry)
            end,
        },
    }

    for _, oldB in ipairs(m.btns) do oldB:Hide() end
    for _, oldD in ipairs(m.secDivs) do oldD:Hide() end
    local yPos = -28
    local divIdx = 0
    for i, act in ipairs(actions) do
        local b = m.btns[i]
        if not b then
            b = CreateFrame("Button", nil, m, "BackdropTemplate")
            b:SetSize(216, 22)
            b.txt = CreateText(b, "OVERLAY", "GameFontHighlightSmall")
            b.txt:SetPoint("LEFT", b, "LEFT", 8, 0)
            b.txt:SetPoint("RIGHT", b, "RIGHT", -8, 0)
            b.txt:SetJustifyH("LEFT")
            b.txt:SetWordWrap(false)
            m.btns[i] = b
        end
        b:SetSize(216, 22)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", m, "TOPLEFT", 8, yPos)
        b.txt:SetText(act.label)
        b.txt:SetTextColor(act.color[1], act.color[2], act.color[3], 1)
        SetPixelBackdrop(b, COLORS.BgElevated, COLORS.BorderSubtle, 1)
        b:SetScript("OnEnter", function(s)
            SetPixelBackdrop(s, { ar * 0.34, ag * 0.34, ab * 0.34, 0.98 }, { ar, ag, ab, 0.95 }, 1)
        end)
        b:SetScript("OnLeave", function(s)
            SetPixelBackdrop(s, COLORS.BgElevated, COLORS.BorderSubtle, 1)
        end)
        b:SetScript("OnClick", act.fn)
        b:Show()
        yPos = yPos - 24
        if act.divAfter then
            divIdx = divIdx + 1
            local d = m.secDivs[divIdx]
            if not d then
                d = m:CreateTexture(nil, "ARTWORK")
                d:SetHeight(1)
                m.secDivs[divIdx] = d
            end
            d:ClearAllPoints()
            d:SetPoint("TOPLEFT", m, "TOPLEFT", 8, yPos - 2)
            d:SetPoint("TOPRIGHT", m, "TOPRIGHT", -8, yPos - 2)
            d:SetColorTexture(1, 1, 1, 0.08)
            d:Show()
            yPos = yPos - 6
        end
    end

    m:SetHeight(math.abs(yPos) + 6)
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", anchorRow, "TOPRIGHT", 6, 0)
    talentRowMenuCatcher:Show()
    m:Show()
end

function DynamicTalent:RefreshTalentDock()
    if IsPlayerInCombat() then
        pendingDockRefresh = true
        return
    end
    pendingDockRefresh = false
    local db = EnsureDB()
    if db.enabled == false or IsModuleDisabledInSuite("DynamicTalent") then
        if talentDockFrame then talentDockFrame:Hide() end
        self:HideTalentRowContextMenu()
        self:HideTalentTreeBackdrop()
        return
    end
    local psf = _G.PlayerSpellsFrame
    local tf = psf and psf.TalentsFrame
    if not (psf and psf.IsShown and psf:IsShown() and tf and tf.IsShown and tf:IsShown()) then
        if talentDockFrame then talentDockFrame:Hide() end
        self:HideTalentRowContextMenu()
        return
    end

    self:EnsureHeroMedallionHooks()
    self:UpdateTalentTreeBackdrop()

    local getGranular = _G.DynamicSuite and _G.DynamicSuite.GetGranularConflictMode
    if type(getGranular) == "function" then
        if getGranular("DynamicTalent", "TalentLoadoutManager") == "YIELD_TO_EXTERNAL"
            or getGranular("DynamicTalent", "TalentLoadoutsEx") == "YIELD_TO_EXTERNAL"
            or getGranular("DynamicTalent", "BtWLoadouts") == "YIELD_TO_EXTERNAL"
            or getGranular("DynamicTalent", "ImprovedTalentLoadouts") == "YIELD_TO_EXTERNAL" then
            if talentDockFrame then talentDockFrame:Hide() end
            self:HideTalentRowContextMenu()
            return
        end
    end

    local tlmLoaded = (type(_G.TalentLoadoutManagerAPI) == "table")
    local ar, ag, ab, accentHex = GetActiveAccentRGB()
    if not talentDockFrame then
        local f = CreateFrame("Frame", "DynamicTalentLoadoutsDock", psf, "BackdropTemplate")
        f:SetFrameStrata("HIGH")
        f:EnableMouse(true)
        f.rows = {}

        f.hdr = CreateText(f, "OVERLAY", "GameFontHighlightSmall")
        f.hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -9)
        f.hdr:SetJustifyH("LEFT")

        local function MkTopBtn(lbl, x, y, w, cb)
            local b = CreateFrame("Button", nil, f, "BackdropTemplate")
            b:SetSize(w, 22)
            b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
            b.txt = CreateText(b, "OVERLAY", "GameFontHighlightSmall")
            b.txt:SetPoint("CENTER")
            b.txt:SetText(lbl)
            b:SetScript("OnClick", cb)
            return b
        end

        f.btnNewImport = MkTopBtn("+ New / Import", 8, -28, 110, function()
            DynamicTalent:HideTalentRowContextMenu()
            DynamicTalent:OpenTalentManagerModal(1, nil)
        end)
        f.btnBoss = MkTopBtn("Talent Binds", 122, -28, 90, function()
            DynamicTalent:HideTalentRowContextMenu()
            DynamicTalent:OpenTalentManagerModal(2, nil)
        end)
        f.btnBoss:SetScript("OnEnter", function(s)
            if GameTooltip then
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Talent Binds", 1, 1, 1)
                GameTooltip:AddLine("Bind saved builds to Raid Bosses, Mythic+ Dungeons, PvP modes, or Zone Defaults.", 0.88, 0.91, 0.95, true)
                GameTooltip:Show()
            end
        end)
        f.btnBoss:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

        f.specBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
        f.specBar:SetHeight(30)
        f.specBar:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -56)
        f.specBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -56)
        SetPixelBackdrop(f.specBar, { 0.043, 0.051, 0.071, 0.96 }, COLORS.BorderSubtle, 1)
        f.specBtns = {}

        f.scroll = CreateFrame("ScrollFrame", nil, f)
        f.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -92)
        f.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 8)
        f.scroll:EnableMouseWheel(true)
        f.content = CreateFrame("Frame", nil, f.scroll)
        f.content:SetWidth(196)
        f.scroll:SetScrollChild(f.content)

        f.track = CreateFrame("Frame", nil, f, "BackdropTemplate")
        f.track:SetWidth(4)
        f.track:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -92)
        f.track:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 10)
        SetPixelBackdrop(f.track, { 0.043, 0.051, 0.071, 0.90 }, { 0, 0, 0, 0 }, 0)
        f.thumb = f.track:CreateTexture(nil, "OVERLAY")
        f.thumb:SetWidth(4)
        f.thumb:SetPoint("TOP", f.track, "TOP", 0, 0)
        f.UpdateScroll = function()
            local vh = f.scroll:GetHeight() or 1
            local th = f.content:GetHeight() or 1
            local maxS = math.max(0, th - vh)
            if maxS <= 1 then f.track:Hide(); return end
            f.track:Show()
            local cur = math.max(0, math.min(maxS, f.scroll:GetVerticalScroll() or 0))
            local trH = f.track:GetHeight() or 1
            local tbH = math.max(20, math.floor(trH * (vh / th)))
            f.thumb:SetHeight(tbH)
            f.thumb:ClearAllPoints()
            f.thumb:SetPoint("TOP", f.track, "TOP", 0, -math.floor((cur / maxS) * math.max(1, trH - tbH)))
        end
        f.scroll:SetScript("OnMouseWheel", function(selfS, delta)
            DynamicTalent:HideTalentRowContextMenu()
            local maxS = math.max(0, (f.content:GetHeight() or 1) - (selfS:GetHeight() or 1))
            selfS:SetVerticalScroll(math.max(0, math.min(maxS, (selfS:GetVerticalScroll() or 0) - (delta * 32))))
            f.UpdateScroll()
        end)

        f.tlmBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
        f.tlmBtn:SetSize(210, 24)
        f.tlmBtn:SetPoint("CENTER", f, "CENTER", 0, 0)
        f.tlmBtn.txt = CreateText(f.tlmBtn, "OVERLAY", "GameFontHighlightSmall")
        f.tlmBtn.txt:SetPoint("CENTER")
        f.tlmBtn.txt:SetText("Import All from Talent Loadout Manager")
        f.tlmBtn:SetScript("OnClick", function() DynamicTalent:ImportFromTalentLoadoutManager() end)

        talentDockFrame = f
    end

    local f = talentDockFrame
    f:SetParent(psf)
    SetPixelBackdrop(f, { 0.031, 0.039, 0.055, 0.96 }, { ar, ag, ab, 0.78 }, 1)

    if tlmLoaded then
        f:SetSize(224, 32)
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", psf, "TOPLEFT", 0, 6)
        f.hdr:Hide()
        f.btnNewImport:Hide(); f.btnBoss:Hide()
        if f.specBar then f.specBar:Hide() end
        if f.scroll then f.scroll:Hide() end
        if f.track then f.track:Hide() end
        for _, r in ipairs(f.rows) do r:Hide() end
        SetPixelBackdrop(f.tlmBtn, { 0.063 * 0.30, 0.725 * 0.30, 0.506 * 0.30, 0.98 }, { 0.063, 0.725, 0.506, 0.92 }, 1)
        f.tlmBtn:Show()
        f:Show()
        return
    end

    f.tlmBtn:Hide()
    f:SetWidth(220)
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", psf, "TOPLEFT", -6, 0)
    f:SetPoint("BOTTOMRIGHT", psf, "BOTTOMLEFT", -6, 0)
    f.hdr:SetText(string.format("|cFFCBD5E1Dynamic|r|cFFFFFFFFTalent|r  |  |cFF%sTalent Loadouts|r", accentHex))
    f.hdr:Show()
    f.thumb:SetColorTexture(ar, ag, ab, 0.85)
    if f.scroll then f.scroll:Show() end
    SetPixelBackdrop(f.btnNewImport, { ar * 0.36, ag * 0.36, ab * 0.36, 0.98 }, { ar, ag, ab, 0.92 }, 1)
    f.btnNewImport:Show()
    SetPixelBackdrop(f.btnBoss, COLORS.BgElevated, COLORS.BorderSubtle, 1)
    f.btnBoss:Show()

    if f.specBar then
        f.specBar:Show()
        local getNumSpecsFn = (C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializations) or _G.GetNumSpecializations
        local getSpecFn = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or _G.GetSpecialization
        local getSpecInfoFn = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or _G.GetSpecializationInfo
        local numSpecs = 0
        if type(getNumSpecsFn) == "function" then
            local okNS, rawNS = pcall(getNumSpecsFn)
            if okNS and not _IsSecret(rawNS) and type(rawNS) == "number" and rawNS > 0 then
                numSpecs = math.min(4, math.floor(rawNS))
            end
        end
        local curSpecIdx = 0
        if type(getSpecFn) == "function" then
            local okCS, rawCS = pcall(getSpecFn)
            if okCS and not _IsSecret(rawCS) and type(rawCS) == "number" and rawCS >= 1 and rawCS <= 4 then
                curSpecIdx = rawCS
            end
        end
        local curLootID = 0
        if type(GetLootSpecialization) == "function" then
            local okLS, rawLS = pcall(GetLootSpecialization)
            if okLS and not _IsSecret(rawLS) and type(rawLS) == "number" and rawLS >= 0 then
                curLootID = rawLS
            end
        end
        for _, sb in ipairs(f.specBtns) do sb:Hide() end
        if numSpecs > 0 and type(getSpecInfoFn) == "function" then
            local btnW = math.floor((200 - ((numSpecs - 1) * 4)) / numSpecs)
            for sIdx = 1, numSpecs do
                local okSI, sID, sName, _, sIcon = pcall(getSpecInfoFn, sIdx)
                if not okSI or _IsSecret(sID) or type(sID) ~= "number" then sID = nil end
                if not okSI or _IsSecret(sName) or type(sName) ~= "string" then sName = nil end
                if not okSI or _IsSecret(sIcon) then sIcon = nil end
                local sb = f.specBtns[sIdx]
                if not sb then
                    sb = CreateFrame("Button", nil, f.specBar, "BackdropTemplate")
                    sb:SetHeight(24)
                    sb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    sb.icon = sb:CreateTexture(nil, "ARTWORK")
                    sb.icon:SetSize(20, 20)
                    sb.icon:SetPoint("CENTER", sb, "CENTER", 0, 0)
                    sb.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    sb.lootPip = sb:CreateTexture(nil, "OVERLAY")
                    sb.lootPip:SetSize(5, 5)
                    sb.lootPip:SetPoint("TOPRIGHT", sb, "TOPRIGHT", -3, -3)
                    sb.lootPip:SetColorTexture(0.980, 0.800, 0.082, 1.0)
                    f.specBtns[sIdx] = sb
                end
                local isActiveSpec = (curSpecIdx > 0 and sIdx == curSpecIdx)
                local isLootTarget = (sID ~= nil) and ((curLootID == sID) or (curLootID == 0 and isActiveSpec))
                sb:SetWidth(btnW)
                sb:ClearAllPoints()
                sb:SetPoint("LEFT", f.specBar, "LEFT", 2 + ((sIdx - 1) * (btnW + 4)), 0)
                sb.icon:SetSize(20, 20)
                sb.icon:ClearAllPoints()
                sb.icon:SetPoint("CENTER", sb, "CENTER", 0, 0)
                sb.icon:SetTexture(sIcon or 134400)
                if sb.txt then sb.txt:Hide() end
                sb.lootPip:SetShown(isLootTarget)
                SetPixelBackdrop(sb, isActiveSpec and { ar * 0.42, ag * 0.42, ab * 0.42, 0.98 } or COLORS.BgElevated, isActiveSpec and { ar, ag, ab, 0.95 } or COLORS.BorderSubtle, 1)
                sb:SetScript("OnClick", function(_, btn)
                    if btn == "RightButton" then
                        if SetLootSpecialization and sID then
                            local nextLoot = (isActiveSpec and curLootID ~= 0) and 0 or sID
                            pcall(SetLootSpecialization, nextLoot)
                            Print(string.format("Loot Specialisation set to |cFFFBBF24%s|r.", (nextLoot == 0) and ("Current (" .. tostring(sName or "Active") .. ")") or tostring(sName or "Specialisation")))
                            if C_Timer and C_Timer.After then
                                C_Timer.After(0.15, function()
                                    DynamicTalent:RefreshTalentDock()
                                    if _G.DynamicPrep and type(_G.DynamicPrep.RefreshBar) == "function" then
                                        pcall(_G.DynamicPrep.RefreshBar, _G.DynamicPrep)
                                    end
                                end)
                            end
                        end
                    else
                        if IsPlayerInCombat() then
                            Print("Cannot switch active specialisation while in combat.")
                            return
                        end
                        if IsMythicPlusActive() then
                            Print("Cannot switch active specialisation during an active Mythic+ run.")
                            return
                        end
                        if not isActiveSpec then
                            if C_SpecializationInfo and C_SpecializationInfo.SetSpecialization then
                                pcall(C_SpecializationInfo.SetSpecialization, sIdx)
                            elseif SetSpecialization then
                                pcall(SetSpecialization, sIdx)
                            end
                        end
                    end
                end)
                sb:SetScript("OnEnter", function(s)
                    if GameTooltip then
                        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                        GameTooltip:AddLine(tostring(sName or "Specialisation") .. (isActiveSpec and "  |cFF34D399(Active)|r" or ""), 1, 1, 1)
                        if isLootTarget then
                            GameTooltip:AddLine("|cFFFBBF24Active Loot Specialisation|r", 0.98, 0.80, 0.08)
                        end
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Switch Active Specialisation (Out of Combat)|r", 1, 1, 1)
                        GameTooltip:AddLine(string.format("|cFF%sRight-Click:|r |cFFE2E8F0Set as Loot Specialisation|r", GetAccentHex()), 1, 1, 1)
                        GameTooltip:Show()
                    end
                end)
                sb:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
                sb:Show()
            end
        end
    end

    for _, r in ipairs(f.rows) do r:Hide() end
    local specID = self:GetActiveSpecID()
    local sortedLib = self:GetSortedTalentProfiles(specID, true)
    local activeLibEntry = self:GetActiveTalentLibraryEntry(specID)
    local _, activeBarName = self:GetTalentLoadoutBarData()

    for idx, entry in ipairs(sortedLib) do
        local row = f.rows[idx]
        if not row then
            row = CreateFrame("Button", nil, f.content, "BackdropTemplate")
            row:SetSize(196, 23)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row.dot = row:CreateTexture(nil, "OVERLAY")
            row.dot:SetSize(6, 6)
            row.dot:SetPoint("LEFT", row, "LEFT", 7, 0)
            row.editBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
            row.editBtn:SetSize(34, 17)
            row.editBtn:SetPoint("RIGHT", row, "RIGHT", -3, 0)
            row.editBtn.txt = CreateText(row.editBtn, "OVERLAY", "GameFontHighlightSmall")
            row.editBtn.txt:SetPoint("CENTER")
            row.editBtn.txt:SetText("Edit")
            row.editBtn:Hide()
            row.bindTag = CreateText(row, "OVERLAY", "GameFontHighlightSmall")
            row.bindTag:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            row.bindTag:SetJustifyH("RIGHT")
            row.bindTag:SetWordWrap(false)
            row.bindTag:Hide()
            row.txt = CreateText(row, "OVERLAY", "GameFontHighlightSmall")
            row.txt:SetPoint("LEFT", row.dot, "RIGHT", 6, 0)
            row.txt:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            row.txt:SetJustifyH("LEFT")
            row.txt:SetWordWrap(false)
            f.rows[idx] = row
        end
        local bInfo = self:GetLoadoutBindings(entry, specID)
        local heroAcr, heroName = self:GetLoadoutHeroAcronym(entry)
        local badgePrefix = self:FormatTalentBadge(entry, heroAcr)
        local isAct = (activeLibEntry and activeLibEntry == entry) or (not activeLibEntry and activeBarName and activeBarName == entry.name)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -((idx - 1) * 25))
        row.dot:SetColorTexture(isAct and 0.063 or 0.35, isAct and 0.725 or 0.42, isAct and 0.506 or 0.52, 1)
        row.editBtn:Hide()
        SetPixelBackdrop(row.editBtn, { 0.055, 0.063, 0.082, 0.96 }, { 0.25, 0.29, 0.38, 0.95 }, 1)
        row.editBtn.txt:SetTextColor(0.84, 0.88, 0.95, 1)

        local tagText = nil
        if bInfo.scopeCount >= 2 then
            tagText = "(Various)"
        elseif bInfo.scopeCount == 1 then
            tagText = "(" .. tostring(bInfo.singleShortBadge or bInfo.singleBadge or "Bound") .. ")"
        end
        row._hasBindTag = (tagText ~= nil)
        if row._hasBindTag then
            row.bindTag:SetText("|cFFFBBF24" .. tagText .. "|r")
            row.bindTag:Show()
        else
            row.bindTag:Hide()
        end

        local function ApplyIdleRowAnchors()
            row.txt:ClearAllPoints()
            row.txt:SetPoint("LEFT", row.dot, "RIGHT", 6, 0)
            if row._hasBindTag then
                row.bindTag:Show()
                row.txt:SetPoint("RIGHT", row.bindTag, "LEFT", -4, 0)
            else
                row.bindTag:Hide()
                row.txt:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            end
        end
        ApplyIdleRowAnchors()
        row.txt:SetText(string.format("%s %s", badgePrefix, tostring(entry.name or "Loadout")))
        row.txt:SetTextColor(isAct and 1 or 0.86, isAct and 1 or 0.90, isAct and 1 or 0.96, 1)
        SetPixelBackdrop(row, isAct and { 0.063 * 0.36, 0.725 * 0.36, 0.506 * 0.36, 0.98 } or COLORS.BgElevated, isAct and { 0.063, 0.725, 0.506, 0.98 } or COLORS.BorderSubtle, 1)

        local function ShowRowTooltip(anchorTarget)
            if GameTooltip then
                GameTooltip:SetOwner(anchorTarget, "ANCHOR_RIGHT")
                GameTooltip:AddLine(string.format("%s %s", badgePrefix, tostring(entry.name or "Loadout")) .. (isAct and "  |cFF34D399(Active)|r" or ""), 1, 1, 1)
                if heroName and heroAcr then
                    GameTooltip:AddLine(string.format("|cFF94A3B8Hero Tree:|r |cFFE2E8F0%s (%s)|r", tostring(heroName), tostring(heroAcr)), 1, 1, 1)
                end
                if #bInfo.detailLines > 0 then
                    for _, bl in ipairs(bInfo.detailLines) do
                        GameTooltip:AddLine("|cFFFBBF24Bound:|r |cFFE2E8F0" .. bl .. "|r", 1, 1, 1)
                    end
                end
                GameTooltip:AddLine(" ")
                local mgr = (talentMgrModal and talentMgrModal:IsShown() and talentMgrModal)
                local leftHint = mgr
                    and "Load in Talent Loadouts Manager to edit or bind"
                    or "Switch to this Talent Loadout"
                GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0" .. leftHint .. "|r", 1, 1, 1)
                GameTooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Rename, Quick Assign, Update or Delete|r", 1, 1, 1)
                GameTooltip:AddLine("|cFFFBBF24Shift + Right-Click:|r |cFFE2E8F0Quick Delete Loadout|r", 1, 1, 1)
                GameTooltip:Show()
            end
        end

        local function SyncRowHoverLeave()
            local overRow = MouseIsOver and MouseIsOver(row)
            local overEdit = MouseIsOver and MouseIsOver(row.editBtn)
            if not overRow and not overEdit then
                row.editBtn:Hide()
                ApplyIdleRowAnchors()
                if GameTooltip then GameTooltip:Hide() end
            end
        end

        row:SetScript("OnEnter", function(s)
            row.bindTag:Hide()
            row.editBtn:Show()
            row.txt:ClearAllPoints()
            row.txt:SetPoint("LEFT", row.dot, "RIGHT", 6, 0)
            row.txt:SetPoint("RIGHT", row.editBtn, "LEFT", -4, 0)
            ShowRowTooltip(s)
        end)
        row:SetScript("OnLeave", SyncRowHoverLeave)
        row.editBtn:SetScript("OnEnter", function(eb)
            local r, g, b = GetActiveAccentRGB()
            SetPixelBackdrop(eb, { r * 0.42, g * 0.42, b * 0.42, 0.98 }, { r, g, b, 0.95 }, 1)
            eb.txt:SetTextColor(1, 1, 1, 1)
            row.bindTag:Hide()
            eb:Show()
            row.txt:ClearAllPoints()
            row.txt:SetPoint("LEFT", row.dot, "RIGHT", 6, 0)
            row.txt:SetPoint("RIGHT", eb, "LEFT", -4, 0)
            if GameTooltip then
                GameTooltip:SetOwner(eb, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Rename / Edit Build", 1, 1, 1)
                GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Open editor pre-filled with " .. tostring(entry.name or "Loadout") .. "|r", 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        row.editBtn:SetScript("OnLeave", function(eb)
            SetPixelBackdrop(eb, { 0.055, 0.063, 0.082, 0.96 }, { 0.25, 0.29, 0.38, 0.95 }, 1)
            eb.txt:SetTextColor(0.84, 0.88, 0.95, 1)
            SyncRowHoverLeave()
        end)
        row.editBtn:SetScript("OnClick", function()
            DynamicTalent:HideTalentRowContextMenu()
            DynamicTalent:OpenTalentManagerModal(1, entry)
        end)
        row:SetScript("OnClick", function(s, btn)
            if btn == "RightButton" then
                if IsShiftKeyDown and IsShiftKeyDown() then
                    DynamicTalent:HideTalentRowContextMenu()
                    DynamicTalent:DeleteTalentLibraryEntry(entry)
                else
                    DynamicTalent:ShowTalentRowContextMenu(s, entry)
                end
            else
                DynamicTalent:HideTalentRowContextMenu()
                local mgr = (talentMgrModal and talentMgrModal:IsShown() and talentMgrModal)
                if mgr and mgr.SelectLoadout then
                    mgr:SelectLoadout(entry, true)
                    return
                end
                DynamicTalent:ApplyTalentLibraryEntry(entry)
            end
        end)
        row:Show()
    end
    f.content:SetHeight(math.max(25, #sortedLib * 25))
    f:Show()
    if C_Timer and C_Timer.After then C_Timer.After(0, f.UpdateScroll) end
end

function DynamicTalent:EnsureTalentDockHooks()
    if not talentDockHooked then
        local psf = _G.PlayerSpellsFrame
        if not psf or type(psf.HookScript) ~= "function" then return end
        talentDockHooked = true
        psf:HookScript("OnShow", function()
            if C_Timer and C_Timer.After then
                C_Timer.After(0.05, function()
                    DynamicTalent:RefreshTalentDock()
                    DynamicTalent:EnsureHeroMedallionHooks()
                    DynamicTalent:UpdateTalentTreeBackdrop()
                end)
            else
                DynamicTalent:RefreshTalentDock()
                DynamicTalent:EnsureHeroMedallionHooks()
                DynamicTalent:UpdateTalentTreeBackdrop()
            end
        end)
        psf:HookScript("OnHide", function()
            if talentDockFrame then talentDockFrame:Hide() end
            DynamicTalent:HideTalentRowContextMenu()
            DynamicTalent:PauseTalentTreeBackdropAnims()
        end)
        if psf.TalentsFrame and type(psf.TalentsFrame.HookScript) == "function" then
            psf.TalentsFrame:HookScript("OnShow", function()
                DynamicTalent:RefreshTalentDock()
                DynamicTalent:EnsureHeroMedallionHooks()
                DynamicTalent:UpdateTalentTreeBackdrop()
            end)
            psf.TalentsFrame:HookScript("OnHide", function()
                if talentDockFrame then talentDockFrame:Hide() end
                DynamicTalent:PauseTalentTreeBackdropAnims()
            end)
        end
    end
    self:EnsureHeroMedallionHooks()
    self:UpdateTalentTreeBackdrop()
end

-- ============================================================================
-- 7b. RIGHT-CLICK HERO SPEC SWAP & TALENT TREE BACKDROP STUDIO
-- ============================================================================
do
    local hookedHeroButtons    = setmetatable({}, { __mode = "k" })
    local hookedHeroContainers = setmetatable({}, { __mode = "k" })
    local hookedTalentFrames   = setmetatable({}, { __mode = "k" })
    local heroSelectionNodeCache = {}
    local talentBackdropFrame  = nil
    local suppressHeroDialogUntil = 0

    local HERO_MOOD_PALETTES = {
        -- Death Knight
        ["deathbringer"]              = { primary = { 0.42, 0.72, 0.96 }, secondary = { 0.58, 0.16, 0.28 }, glow = { 0.36, 0.62, 0.94 } },
        ["rider of the apocalypse"]   = { primary = { 0.24, 0.78, 0.68 }, secondary = { 0.30, 0.56, 0.86 }, glow = { 0.28, 0.86, 0.76 } },
        ["san'layn"]                  = { primary = { 0.84, 0.16, 0.26 }, secondary = { 0.46, 0.10, 0.24 }, glow = { 0.92, 0.24, 0.34 } },
        ["sanlayn"]                   = { primary = { 0.84, 0.16, 0.26 }, secondary = { 0.46, 0.10, 0.24 }, glow = { 0.92, 0.24, 0.34 } },
        -- Demon Hunter
        ["aldrachi reaver"]           = { primary = { 0.16, 0.84, 0.46 }, secondary = { 0.40, 0.22, 0.68 }, glow = { 0.22, 0.90, 0.54 } },
        ["fel-scarred"]               = { primary = { 0.22, 0.92, 0.32 }, secondary = { 0.76, 0.46, 0.12 }, glow = { 0.30, 0.96, 0.40 } },
        ["felscarred"]                = { primary = { 0.22, 0.92, 0.32 }, secondary = { 0.76, 0.46, 0.12 }, glow = { 0.30, 0.96, 0.40 } },
        ["scarred"]                   = { primary = { 0.22, 0.92, 0.32 }, secondary = { 0.76, 0.46, 0.12 }, glow = { 0.30, 0.96, 0.40 } },
        ["void-scarred"]              = { primary = { 0.58, 0.26, 0.92 }, secondary = { 0.24, 0.14, 0.62 }, glow = { 0.70, 0.34, 0.98 } },
        ["voidscarred"]               = { primary = { 0.58, 0.26, 0.92 }, secondary = { 0.24, 0.14, 0.62 }, glow = { 0.70, 0.34, 0.98 } },
        ["annihilator"]               = { primary = { 0.68, 0.24, 0.92 }, secondary = { 0.72, 0.18, 0.38 }, glow = { 0.78, 0.32, 0.96 } },
        -- Druid
        ["druid of the claw"]         = { primary = { 0.94, 0.52, 0.16 }, secondary = { 0.66, 0.24, 0.14 }, glow = { 0.96, 0.60, 0.22 } },
        ["elune's chosen"]            = { primary = { 0.38, 0.64, 0.98 }, secondary = { 0.68, 0.78, 0.98 }, glow = { 0.46, 0.74, 1.00 } },
        ["elunes chosen"]             = { primary = { 0.38, 0.64, 0.98 }, secondary = { 0.68, 0.78, 0.98 }, glow = { 0.46, 0.74, 1.00 } },
        ["keeper of the grove"]       = { primary = { 0.18, 0.82, 0.52 }, secondary = { 0.34, 0.68, 0.40 }, glow = { 0.24, 0.90, 0.60 } },
        ["wildstalker"]               = { primary = { 0.36, 0.84, 0.30 }, secondary = { 0.18, 0.62, 0.44 }, glow = { 0.44, 0.92, 0.38 } },
        -- Evoker
        ["chronowarden"]              = { primary = { 0.92, 0.74, 0.26 }, secondary = { 0.24, 0.72, 0.82 }, glow = { 0.96, 0.82, 0.36 } },
        ["flameshaper"]               = { primary = { 0.92, 0.30, 0.20 }, secondary = { 0.94, 0.60, 0.18 }, glow = { 0.98, 0.38, 0.24 } },
        ["scalecommander"]            = { primary = { 0.76, 0.58, 0.28 }, secondary = { 0.26, 0.54, 0.62 }, glow = { 0.86, 0.68, 0.36 } },
        -- Hunter
        ["dark ranger"]               = { primary = { 0.56, 0.28, 0.80 }, secondary = { 0.34, 0.44, 0.60 }, glow = { 0.66, 0.36, 0.88 } },
        ["pack leader"]               = { primary = { 0.82, 0.58, 0.24 }, secondary = { 0.32, 0.66, 0.42 }, glow = { 0.90, 0.66, 0.30 } },
        ["sentinel"]                  = { primary = { 0.32, 0.66, 0.94 }, secondary = { 0.54, 0.82, 0.96 }, glow = { 0.40, 0.76, 0.98 } },
        -- Mage
        ["frostfire"]                 = { primary = { 0.24, 0.74, 0.98 }, secondary = { 0.94, 0.42, 0.20 }, glow = { 0.44, 0.72, 0.96 } },
        ["spellslinger"]              = { primary = { 0.48, 0.44, 0.98 }, secondary = { 0.28, 0.74, 0.96 }, glow = { 0.58, 0.52, 1.00 } },
        ["sunfury"]                   = { primary = { 0.98, 0.62, 0.18 }, secondary = { 0.88, 0.24, 0.22 }, glow = { 1.00, 0.72, 0.24 } },
        -- Monk
        ["conduit of the celestials"] = { primary = { 0.18, 0.86, 0.64 }, secondary = { 0.34, 0.74, 0.92 }, glow = { 0.26, 0.92, 0.72 } },
        ["master of harmony"]         = { primary = { 0.20, 0.84, 0.68 }, secondary = { 0.88, 0.72, 0.28 }, glow = { 0.28, 0.92, 0.76 } },
        ["shado-pan"]                 = { primary = { 0.42, 0.48, 0.86 }, secondary = { 0.72, 0.24, 0.34 }, glow = { 0.50, 0.56, 0.92 } },
        ["shadopan"]                  = { primary = { 0.42, 0.48, 0.86 }, secondary = { 0.72, 0.24, 0.34 }, glow = { 0.50, 0.56, 0.92 } },
        -- Paladin
        ["herald of the sun"]         = { primary = { 0.98, 0.74, 0.22 }, secondary = { 0.94, 0.44, 0.18 }, glow = { 1.00, 0.82, 0.32 } },
        ["lightsmith"]                = { primary = { 0.94, 0.76, 0.34 }, secondary = { 0.46, 0.66, 0.92 }, glow = { 0.98, 0.84, 0.44 } },
        ["templar"]                   = { primary = { 0.96, 0.80, 0.30 }, secondary = { 0.42, 0.70, 0.96 }, glow = { 1.00, 0.86, 0.40 } },
        -- Priest
        ["archon"]                    = { primary = { 0.98, 0.84, 0.42 }, secondary = { 0.62, 0.82, 0.98 }, glow = { 1.00, 0.90, 0.54 } },
        ["oracle"]                    = { primary = { 0.46, 0.78, 0.98 }, secondary = { 0.82, 0.88, 0.98 }, glow = { 0.58, 0.86, 1.00 } },
        ["voidweaver"]                = { primary = { 0.52, 0.24, 0.92 }, secondary = { 0.24, 0.30, 0.76 }, glow = { 0.64, 0.34, 0.98 } },
        -- Rogue
        ["deathstalker"]              = { primary = { 0.26, 0.78, 0.52 }, secondary = { 0.44, 0.34, 0.68 }, glow = { 0.34, 0.86, 0.60 } },
        ["fatebound"]                 = { primary = { 0.92, 0.74, 0.26 }, secondary = { 0.46, 0.52, 0.68 }, glow = { 0.96, 0.82, 0.38 } },
        ["trickster"]                 = { primary = { 0.36, 0.62, 0.96 }, secondary = { 0.26, 0.82, 0.74 }, glow = { 0.46, 0.72, 0.98 } },
        -- Shaman
        ["farseer"]                   = { primary = { 0.24, 0.64, 0.96 }, secondary = { 0.32, 0.86, 0.82 }, glow = { 0.34, 0.76, 1.00 } },
        ["stormbringer"]              = { primary = { 0.22, 0.72, 1.00 }, secondary = { 0.44, 0.48, 0.98 }, glow = { 0.34, 0.84, 1.00 } },
        ["totemic"]                   = { primary = { 0.92, 0.48, 0.20 }, secondary = { 0.24, 0.76, 0.68 }, glow = { 0.96, 0.58, 0.28 } },
        -- Warlock
        ["diabolist"]                 = { primary = { 0.92, 0.26, 0.24 }, secondary = { 0.88, 0.52, 0.18 }, glow = { 0.98, 0.34, 0.28 } },
        ["hellcaller"]                = { primary = { 0.42, 0.86, 0.34 }, secondary = { 0.84, 0.24, 0.34 }, glow = { 0.50, 0.92, 0.40 } },
        ["soul harvester"]            = { primary = { 0.64, 0.34, 0.94 }, secondary = { 0.24, 0.78, 0.62 }, glow = { 0.74, 0.44, 0.98 } },
        -- Warrior
        ["colossus"]                  = { primary = { 0.86, 0.58, 0.28 }, secondary = { 0.44, 0.54, 0.68 }, glow = { 0.92, 0.66, 0.36 } },
        ["mountain thane"]            = { primary = { 0.30, 0.68, 0.98 }, secondary = { 0.48, 0.80, 0.98 }, glow = { 0.40, 0.78, 1.00 } },
        ["slayer"]                    = { primary = { 0.90, 0.28, 0.28 }, secondary = { 0.62, 0.44, 0.34 }, glow = { 0.96, 0.38, 0.34 } },
    }

    local function GetPlayerClassRGB()
        if type(UnitClass) == "function" then
            local ok, _, classFile = pcall(UnitClass, "player")
            if ok and not _IsSecret(classFile) and type(classFile) == "string" and classFile ~= "" then
                if C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
                    local okC, cc = pcall(C_ClassColor.GetClassColor, classFile)
                    if okC and cc and type(cc.GetRGB) == "function" then
                        local r, g, b = cc:GetRGB()
                        if type(r) == "number" and type(g) == "number" and type(b) == "number" then
                            return r, g, b
                        end
                    end
                end
                local rcc = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[classFile]
                if type(rcc) == "table" and type(rcc.r) == "number" then
                    return rcc.r, rcc.g, rcc.b
                end
            end
        end
        local ar, ag, ab = GetActiveAccentRGB()
        return ar, ag, ab
    end

    local function MakePaletteFromRGB(r, g, b)
        r = math.max(0.08, math.min(1, tonumber(r) or 0.220))
        g = math.max(0.08, math.min(1, tonumber(g) or 0.741))
        b = math.max(0.08, math.min(1, tonumber(b) or 0.973))
        local sr = math.max(0.08, math.min(1, r * 0.72 + 0.08))
        local sg = math.max(0.08, math.min(1, g * 0.72 + 0.08))
        local sb = math.max(0.08, math.min(1, b * 0.78 + 0.10))
        local gr = math.min(1, r * 1.08 + 0.06)
        local gg = math.min(1, g * 1.08 + 0.06)
        local gb = math.min(1, b * 1.08 + 0.06)
        return {
            primary   = { r, g, b },
            secondary = { sr, sg, sb },
            glow      = { gr, gg, gb },
        }
    end

    local function ResolveHeroSpecButtons(tf)
        local list, seen = {}, {}
        local function AddBtn(b)
            if b and type(b) == "table" and not seen[b] then
                seen[b] = true
                table.insert(list, b)
            end
        end
        local hc = tf and tf.HeroTalentsContainer
        if hc then
            AddBtn(hc.HeroSpecButton)
            if hc.ExpandedContainer then AddBtn(hc.ExpandedContainer.HeroSpecButton) end
            if hc.CollapsedContainer then AddBtn(hc.CollapsedContainer.HeroSpecButton) end
            AddBtn(hc.ChooseHeroSpecButton)
            AddBtn(hc.HeroSpecChoiceButton)
        end
        return list
    end

    local function FindSubTreeSelectionNodeID(configID, specID, tf)
        local subTreeEnum = (_G.Enum and _G.Enum.TraitNodeType and _G.Enum.TraitNodeType.SubTreeSelection) or 3
        local hc = tf and tf.HeroTalentsContainer
        if hc and type(hc.GetSubTreeSelectionNodeID) == "function" then
            local okN, nid = pcall(hc.GetSubTreeSelectionNodeID, hc)
            if okN and not _IsSecret(nid) and type(nid) == "number" and nid > 0 then
                if specID then heroSelectionNodeCache[specID] = nid end
                return nid
            end
        end
        if specID and heroSelectionNodeCache[specID] and C_Traits and type(C_Traits.GetNodeInfo) == "function" then
            local okI, cInfo = pcall(C_Traits.GetNodeInfo, configID, heroSelectionNodeCache[specID])
            if okI and not _IsSecret(cInfo) and type(cInfo) == "table"
                and not _IsSecret(cInfo.type) and cInfo.type == subTreeEnum
                and not _IsSecret(cInfo.entryIDs) and type(cInfo.entryIDs) == "table" and #cInfo.entryIDs >= 2 then
                return heroSelectionNodeCache[specID]
            end
        end
        if C_Traits and type(C_Traits.GetConfigInfo) == "function" and type(C_Traits.GetTreeNodes) == "function" and type(C_Traits.GetNodeInfo) == "function" then
            local okCfg, cfgInfo = pcall(C_Traits.GetConfigInfo, configID)
            if okCfg and not _IsSecret(cfgInfo) and type(cfgInfo) == "table"
                and not _IsSecret(cfgInfo.treeIDs) and type(cfgInfo.treeIDs) == "table" then
                for _, treeID in ipairs(cfgInfo.treeIDs) do
                    if not _IsSecret(treeID) and type(treeID) == "number" and treeID > 0 then
                        local okT, nodes = pcall(C_Traits.GetTreeNodes, treeID)
                        if okT and not _IsSecret(nodes) and type(nodes) == "table" then
                            for _, nid in ipairs(nodes) do
                                if not _IsSecret(nid) and type(nid) == "number" and nid > 0 then
                                    local okN, nInfo = pcall(C_Traits.GetNodeInfo, configID, nid)
                                    if okN and not _IsSecret(nInfo) and type(nInfo) == "table"
                                        and not _IsSecret(nInfo.type) and nInfo.type == subTreeEnum
                                        and not _IsSecret(nInfo.entryIDs) and type(nInfo.entryIDs) == "table" and #nInfo.entryIDs >= 2 then
                                        if not _IsSecret(nInfo.isVisible) and nInfo.isVisible ~= false then
                                            if specID then heroSelectionNodeCache[specID] = nid end
                                            return nid
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return nil
    end

    function DynamicTalent:GetHeroSwapInfo()
        if IsPlayerInCombat() then return nil, "COMBAT" end
        if IsMythicPlusActive() then return nil, "KEYSTONE" end
        local tf = _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.TalentsFrame
        if tf and type(tf.IsInspecting) == "function" then
            local okIns, isIns = pcall(tf.IsInspecting, tf)
            if okIns and not _IsSecret(isIns) and isIns then
                return nil, "INSPECT"
            end
        end
        if not (C_ClassTalents and C_Traits and type(C_ClassTalents.GetActiveConfigID) == "function" and type(C_Traits.GetNodeInfo) == "function") then
            return nil, "UNAVAILABLE"
        end
        local okC, configID = pcall(C_ClassTalents.GetActiveConfigID)
        if not okC or _IsSecret(configID) or type(configID) ~= "number" or configID <= 0 then
            return nil, "UNAVAILABLE"
        end
        local specID = self:GetActiveSpecID()
        if not specID then return nil, "LOCKED" end
        if type(C_ClassTalents.GetHeroTalentSpecsForClassSpec) == "function" then
            local okH, _, reqLevel = pcall(C_ClassTalents.GetHeroTalentSpecsForClassSpec, configID, specID)
            if okH and not _IsSecret(reqLevel) and type(reqLevel) == "number" and reqLevel > 0 and type(UnitLevel) == "function" then
                local okL, pLvl = pcall(UnitLevel, "player")
                if okL and not _IsSecret(pLvl) and type(pLvl) == "number" and pLvl < reqLevel then
                    return nil, "LOCKED"
                end
            end
        end

        local nodeID = FindSubTreeSelectionNodeID(configID, specID, tf)
        if not nodeID then return nil, "LOCKED" end

        local okN, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
        if not okN or _IsSecret(nodeInfo) or type(nodeInfo) ~= "table"
            or _IsSecret(nodeInfo.isVisible) or nodeInfo.isVisible == false
            or _IsSecret(nodeInfo.isAvailable) or nodeInfo.isAvailable == false
            or _IsSecret(nodeInfo.meetsEdgeRequirements) or nodeInfo.meetsEdgeRequirements == false
            or _IsSecret(nodeInfo.entryIDs) or type(nodeInfo.entryIDs) ~= "table" or #nodeInfo.entryIDs < 2 then
            return nil, "LOCKED"
        end

        local candidates = {}
        for _, eID in ipairs(nodeInfo.entryIDs) do
            if not _IsSecret(eID) and type(eID) == "number" and eID > 0 then
                local okE, eInfo = pcall(C_Traits.GetEntryInfo, configID, eID)
                if okE and not _IsSecret(eInfo) and type(eInfo) == "table" and not _IsSecret(eInfo.subTreeID) and type(eInfo.subTreeID) == "number" and eInfo.subTreeID > 0 and type(C_Traits.GetSubTreeInfo) == "function" then
                    local okS, sInfo = pcall(C_Traits.GetSubTreeInfo, configID, eInfo.subTreeID)
                    if okS and not _IsSecret(sInfo) and type(sInfo) == "table" and not _IsSecret(sInfo.name) and type(sInfo.name) == "string" then
                        local sName = SafeTrim(sInfo.name)
                        if sName ~= "" then
                            table.insert(candidates, {
                                entryID         = eID,
                                subTreeID       = eInfo.subTreeID,
                                name            = sName,
                                isSubTreeActive = (not _IsSecret(sInfo.isActive) and sInfo.isActive == true),
                            })
                        end
                    end
                end
            end
        end
        if #candidates < 2 then return nil, "LOCKED" end

        local stagedEntryID = (not _IsSecret(nodeInfo.activeEntry) and type(nodeInfo.activeEntry) == "table"
            and not _IsSecret(nodeInfo.activeEntry.entryID) and type(nodeInfo.activeEntry.entryID) == "number")
            and nodeInfo.activeEntry.entryID or nil
        local activeSubTreeID = nil
        if type(C_ClassTalents.GetActiveHeroTalentSpec) == "function" then
            local okA, stID = pcall(C_ClassTalents.GetActiveHeroTalentSpec)
            if okA and not _IsSecret(stID) and type(stID) == "number" and stID > 0 then
                activeSubTreeID = stID
            end
        end

        local activeIdx = nil
        if stagedEntryID then
            for i, c in ipairs(candidates) do
                if c.entryID == stagedEntryID then activeIdx = i; break end
            end
        end
        if not activeIdx and activeSubTreeID then
            for i, c in ipairs(candidates) do
                if c.subTreeID == activeSubTreeID then activeIdx = i; break end
            end
        end
        if not activeIdx then
            for i, c in ipairs(candidates) do
                if c.isSubTreeActive then activeIdx = i; break end
            end
        end

        local activeItem = activeIdx and candidates[activeIdx] or nil
        local targetIdx = activeIdx and ((activeIdx % #candidates) + 1) or 1
        local targetItem = candidates[targetIdx]
        if not targetItem then return nil, "LOCKED" end

        return {
            configID        = configID,
            nodeID          = nodeID,
            specID          = specID,
            activeEntryID   = activeItem and activeItem.entryID or nil,
            activeSubTreeID = activeItem and activeItem.subTreeID or nil,
            activeName      = activeItem and activeItem.name or nil,
            targetEntryID   = targetItem.entryID,
            targetSubTreeID = targetItem.subTreeID,
            targetName      = targetItem.name,
        }, nil
    end

    local function HideHeroSelectionDialogs()
        local dlg = _G.HeroTalentsSelectionDialog
        if dlg and type(dlg.IsShown) == "function" and dlg:IsShown() then
            pcall(dlg.Hide, dlg)
        end
        local tf = _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.TalentsFrame
        local hc = tf and tf.HeroTalentsContainer
        if hc then
            for _, k in ipairs({ "SelectionDialog", "ChoiceDialog", "HeroTalentsSelectionDialog" }) do
                local sub = hc[k]
                if sub and type(sub.IsShown) == "function" and sub:IsShown() then
                    pcall(sub.Hide, sub)
                end
            end
        end
    end

    local function AppendHeroSwapTooltipHint(owner)
        local db = EnsureDB()
        if IsModuleDisabledInSuite("DynamicTalent") or db.enabled == false or db.rightClickHeroSwap == false then
            return
        end
        if IsPlayerInCombat() or IsMythicPlusActive() then return end
        local tt = _G.GameTooltip
        if not tt or (type(tt.IsShown) == "function" and not tt:IsShown()) then return end
        local info = DynamicTalent:GetHeroSwapInfo()
        if not info or type(info.targetName) ~= "string" or info.targetName == "" then return end

        local numLines = 0
        if type(tt.NumLines) == "function" then
            local okNL, rawNL = pcall(tt.NumLines, tt)
            if okNL and not _IsSecret(rawNL) and type(rawNL) == "number" and rawNL > 0 then
                numLines = rawNL
            end
        end
        for i = 1, numLines do
            local fs = _G["GameTooltipTextLeft" .. i]
            if fs and type(fs.GetText) == "function" then
                local okT, rawTxt = pcall(fs.GetText, fs)
                local txt = okT and SafeStr(rawTxt, "") or ""
                if txt:find("Right-Click: Switch to", 1, true) or txt:find("Switch to " .. info.targetName, 1, true) then
                    return
                end
            end
        end

        if type(tt.AddLine) == "function" then
            tt:AddLine(" ")
            tt:AddLine(string.format("|cFF%sRight-Click:|r |cFFE2E8F0Switch to %s|r", GetAccentHex(), info.targetName))
            if type(tt.Show) == "function" then tt:Show() end
        end
    end

    function DynamicTalent:PerformHeroMedallionSwap()
        local db = EnsureDB()
        if IsModuleDisabledInSuite("DynamicTalent") or db.enabled == false or db.rightClickHeroSwap == false then
            return false, "DISABLED"
        end
        if IsPlayerInCombat() then return false, "COMBAT" end
        if IsMythicPlusActive() then return false, "KEYSTONE" end

        local info, reason = self:GetHeroSwapInfo()
        if not info then return false, reason end
        if not (C_Traits and type(C_Traits.SetSelection) == "function") then
            return false, "UNAVAILABLE"
        end

        local ok, res = pcall(C_Traits.SetSelection, info.configID, info.nodeID, info.targetEntryID, true)
        if not ok then
            ok, res = pcall(C_Traits.SetSelection, info.configID, info.nodeID, info.targetEntryID)
        end
        if not ok or (not _IsSecret(res) and res == false) then
            return false, "FAILED"
        end

        suppressHeroDialogUntil = ((type(GetTime) == "function" and GetTime()) or 0) + 0.30
        HideHeroSelectionDialogs()

        if type(PlaySound) == "function" and _G.SOUNDKIT and _G.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            pcall(PlaySound, _G.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end

        self._heroTreeCache = nil
        self:InvalidateActiveTalentStringCache()
        self:UpdateTalentTreeBackdrop()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.05, function()
                HideHeroSelectionDialogs()
                DynamicTalent:UpdateTalentTreeBackdrop()
            end)
        end
        return true, info.targetName
    end

    function DynamicTalent:EnsureHeroMedallionHooks()
        local tf = _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.TalentsFrame
        if not tf then return end
        if IsPlayerInCombat() then return end

        local dlg = _G.HeroTalentsSelectionDialog
        if dlg and not hookedHeroContainers[dlg] and type(dlg.HookScript) == "function" then
            hookedHeroContainers[dlg] = true
            dlg:HookScript("OnShow", function(s)
                if IsPlayerInCombat() then return end
                local now = (type(GetTime) == "function" and GetTime()) or 0
                if now <= suppressHeroDialogUntil then
                    pcall(s.Hide, s)
                end
            end)
        end

        local hc = tf.HeroTalentsContainer
        if hc and not hookedHeroContainers[hc] and type(hc.HookScript) == "function" then
            hookedHeroContainers[hc] = true
            hc:HookScript("OnShow", function()
                DynamicTalent:EnsureHeroMedallionHooks()
                DynamicTalent:UpdateTalentTreeBackdrop()
            end)
        end

        for _, btn in ipairs(ResolveHeroSpecButtons(tf)) do
            if not hookedHeroButtons[btn] and type(btn.HookScript) == "function" then
                hookedHeroButtons[btn] = true
                btn:HookScript("OnMouseUp", function(_, button, upInside)
                    if button == "RightButton" and upInside ~= false then
                        DynamicTalent:PerformHeroMedallionSwap()
                    end
                end)
                btn:HookScript("OnEnter", function(s)
                    AppendHeroSwapTooltipHint(s)
                end)
            end
        end
    end

    function DynamicTalent:GetHeroMoodPalette()
        local heroName = nil
        if not IsPlayerInCombat() and not IsMythicPlusActive() then
            local info = self:GetHeroSwapInfo()
            if info and type(info.activeName) == "string" and info.activeName ~= "" then
                heroName = info.activeName
            end
        end
        if not heroName then
            local _, liveName = self:GetLiveHeroTreeInfo()
            if type(liveName) == "string" and liveName ~= "" then
                heroName = liveName
            end
        end
        if type(heroName) == "string" and not _IsSecret(heroName) then
            local low = SafeTrim(heroName):lower()
            local pal = HERO_MOOD_PALETTES[low] or HERO_MOOD_PALETTES[low:gsub("['`]", "")]
            if pal then return pal end
        end
        local cr, cg, cb = GetPlayerClassRGB()
        return MakePaletteFromRGB(cr, cg, cb)
    end

    function DynamicTalent:GetClassGlowPalette()
        if _G.DynamicSuite and type(_G.DynamicSuite.GetSuiteAccent) == "function" then
            local ar, ag, ab = GetActiveAccentRGB()
            return MakePaletteFromRGB(ar, ag, ab)
        end
        local cr, cg, cb = GetPlayerClassRGB()
        return MakePaletteFromRGB(cr, cg, cb)
    end

    local function CreateMistAnimGroup(tex, dx, dy, duration, aFrom, aTo, scaleFrom, scaleTo)
        if type(tex.CreateAnimationGroup) ~= "function" then return nil end
        local ag = tex:CreateAnimationGroup()
        if ag.SetLooping then ag:SetLooping("BOUNCE") end
        if dx ~= 0 or dy ~= 0 then
            local tr = ag:CreateAnimation("Translation")
            if tr.SetOffset then tr:SetOffset(dx, dy) end
            if tr.SetDuration then tr:SetDuration(duration) end
            if tr.SetSmoothing then tr:SetSmoothing("IN_OUT") end
        end
        if scaleFrom and scaleTo then
            local sc = ag:CreateAnimation("Scale")
            if sc.SetScaleFrom then
                sc:SetScaleFrom(scaleFrom, scaleFrom)
                sc:SetScaleTo(scaleTo, scaleTo)
            elseif sc.SetFromScale then
                sc:SetFromScale(scaleFrom, scaleFrom)
                sc:SetToScale(scaleTo, scaleTo)
            end
            if sc.SetDuration then sc:SetDuration(duration) end
            if sc.SetSmoothing then sc:SetSmoothing("IN_OUT") end
        end
        if aFrom and aTo then
            local al = ag:CreateAnimation("Alpha")
            if al.SetFromAlpha then al:SetFromAlpha(aFrom) end
            if al.SetToAlpha then al:SetToAlpha(aTo) end
            if al.SetDuration then al:SetDuration(duration) end
            if al.SetSmoothing then al:SetSmoothing("IN_OUT") end
            ag._alphaAnim = al
        end
        return ag
    end

    local function ApplyGradientSafe(tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
        if type(_G.CreateColor) == "function" and type(tex.SetGradient) == "function" then
            tex:SetColorTexture(1, 1, 1, 1)
            tex:SetGradient(orientation, _G.CreateColor(r1, g1, b1, a1), _G.CreateColor(r2, g2, b2, a2))
        else
            tex:SetColorTexture(r1, g1, b1, math.max(a1, a2) * 0.45)
        end
    end

    local function LayoutBackdropLayers()
        if not talentBackdropFrame then return end
        if IsPlayerInCombat() then
            pendingBackdropRefresh = true
            DynamicTalent._pendingBackdropRefresh = true
            return
        end
        local tf = _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.TalentsFrame
        local w = (talentBackdropFrame.GetWidth and talentBackdropFrame:GetWidth()) or 0
        local h = (talentBackdropFrame.GetHeight and talentBackdropFrame:GetHeight()) or 0
        if (w <= 10 or h <= 10) and tf then
            w = (tf.GetWidth and tf:GetWidth()) or 1180
            h = (tf.GetHeight and tf:GetHeight()) or 660
        end
        if w <= 10 then w = 1180 end
        if h <= 10 then h = 660 end
        talentBackdropFrame.mistPrimary:SetSize(w * 1.32, h * 1.24)
        talentBackdropFrame.mistSecondary:SetSize(w * 1.28, h * 1.18)
        talentBackdropFrame.mistFocal:SetSize(w * 0.62, h * 0.88)
        local edgeH = math.max(54, math.floor(h * 0.18))
        local edgeW = math.max(80, math.floor(w * 0.14))
        talentBackdropFrame.vigTop:SetHeight(edgeH)
        talentBackdropFrame.vigBottom:SetHeight(edgeH)
        talentBackdropFrame.vigLeft:SetWidth(edgeW)
        talentBackdropFrame.vigRight:SetWidth(edgeW)
    end

    local function SyncBlizzardSpecBackground(tf, hideSpecArt)
        if not tf or not tf.Background then return end
        if type(tf.Background.SetAlpha) == "function" then
            tf.Background:SetAlpha(hideSpecArt and 0 or 1)
        end
    end

    function DynamicTalent:EnsureTalentTreeBackdrop()
        local tf = _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.TalentsFrame
        if not tf then return nil end
        if not hookedTalentFrames[tf] then
            hookedTalentFrames[tf] = true
            if type(_G.hooksecurefunc) == "function" and type(tf.UpdateSpecBackground) == "function" then
                _G.hooksecurefunc(tf, "UpdateSpecBackground", function()
                    DynamicTalent:UpdateTalentTreeBackdrop()
                end)
            end
        end
        if not talentBackdropFrame then
            if IsPlayerInCombat() then return nil end
            local bg = CreateFrame("Frame", "DynamicTalentTreeBackdrop", tf)
            bg:EnableMouse(false)
            if bg.SetClipsChildren then bg:SetClipsChildren(true) end
            if tf.Background then
                bg:SetAllPoints(tf.Background)
            else
                bg:SetAllPoints(tf)
            end

            bg.baseCanvas = bg:CreateTexture(nil, "BACKGROUND", nil, 1)
            bg.baseCanvas:SetAllPoints()
            bg.baseCanvas:SetColorTexture(0.035, 0.039, 0.051, 1.00)

            bg.dimmerWash = bg:CreateTexture(nil, "BACKGROUND", nil, 2)
            bg.dimmerWash:SetAllPoints()
            bg.dimmerWash:SetColorTexture(0.012, 0.015, 0.020, 0.35)

            bg.mistPrimary = bg:CreateTexture(nil, "BACKGROUND", nil, 3)
            bg.mistPrimary:SetTexture(TEX_TALENT_MIST)
            if bg.mistPrimary.SetBlendMode then bg.mistPrimary:SetBlendMode("ADD") end
            bg.mistPrimary:SetPoint("CENTER", bg, "CENTER", -90, 45)
            bg.mistPrimaryAnim = CreateMistAnimGroup(bg.mistPrimary, 34, -18, 15, 0.28, 0.48)

            bg.mistSecondary = bg:CreateTexture(nil, "BACKGROUND", nil, 4)
            bg.mistSecondary:SetTexture(TEX_TALENT_MIST)
            if bg.mistSecondary.SetBlendMode then bg.mistSecondary:SetBlendMode("ADD") end
            bg.mistSecondary:SetPoint("CENTER", bg, "CENTER", 95, -40)
            bg.mistSecondaryAnim = CreateMistAnimGroup(bg.mistSecondary, -30, 20, 19, 0.20, 0.36)

            bg.mistFocal = bg:CreateTexture(nil, "BACKGROUND", nil, 5)
            bg.mistFocal:SetTexture(TEX_TALENT_MIST)
            if bg.mistFocal.SetBlendMode then bg.mistFocal:SetBlendMode("ADD") end
            bg.mistFocal:SetPoint("CENTER", bg, "CENTER", 0, 12)
            bg.mistFocalAnim = CreateMistAnimGroup(bg.mistFocal, 0, 0, 11, 0.24, 0.40, 0.96, 1.06)

            bg.vigTop = bg:CreateTexture(nil, "BACKGROUND", nil, 6)
            bg.vigTop:SetPoint("TOPLEFT", bg, "TOPLEFT", 0, 0)
            bg.vigTop:SetPoint("TOPRIGHT", bg, "TOPRIGHT", 0, 0)
            ApplyGradientSafe(bg.vigTop, "VERTICAL", 0.015, 0.018, 0.024, 0.0, 0.015, 0.018, 0.024, 0.78)

            bg.vigBottom = bg:CreateTexture(nil, "BACKGROUND", nil, 6)
            bg.vigBottom:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT", 0, 0)
            bg.vigBottom:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", 0, 0)
            ApplyGradientSafe(bg.vigBottom, "VERTICAL", 0.015, 0.018, 0.024, 0.78, 0.015, 0.018, 0.024, 0.0)

            bg.vigLeft = bg:CreateTexture(nil, "BACKGROUND", nil, 6)
            bg.vigLeft:SetPoint("TOPLEFT", bg, "TOPLEFT", 0, 0)
            bg.vigLeft:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT", 0, 0)
            ApplyGradientSafe(bg.vigLeft, "HORIZONTAL", 0.015, 0.018, 0.024, 0.72, 0.015, 0.018, 0.024, 0.0)

            bg.vigRight = bg:CreateTexture(nil, "BACKGROUND", nil, 6)
            bg.vigRight:SetPoint("TOPRIGHT", bg, "TOPRIGHT", 0, 0)
            bg.vigRight:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", 0, 0)
            ApplyGradientSafe(bg.vigRight, "HORIZONTAL", 0.015, 0.018, 0.024, 0.0, 0.015, 0.018, 0.024, 0.72)

            bg.vignettes = { bg.vigTop, bg.vigBottom, bg.vigLeft, bg.vigRight }

            bg:SetScript("OnSizeChanged", LayoutBackdropLayers)
            bg:SetScript("OnShow", LayoutBackdropLayers)
            talentBackdropFrame = bg
            LayoutBackdropLayers()
        end

        if not IsPlayerInCombat() then
            local tfLvl = (tf.GetFrameLevel and tf:GetFrameLevel()) or 1
            local bpLvl = (tf.ButtonsParent and tf.ButtonsParent.GetFrameLevel and tf.ButtonsParent:GetFrameLevel()) or (tfLvl + 1)
            if bpLvl > tfLvl then
                talentBackdropFrame:SetFrameLevel(tfLvl)
            else
                talentBackdropFrame:SetFrameLevel(math.max(0, tfLvl))
            end
        end
        return talentBackdropFrame
    end

    function DynamicTalent:PauseTalentTreeBackdropAnims()
        if not talentBackdropFrame then return end
        for _, ag in ipairs({ talentBackdropFrame.mistPrimaryAnim, talentBackdropFrame.mistSecondaryAnim, talentBackdropFrame.mistFocalAnim }) do
            if ag and ag.Stop then
                if not ag.IsPlaying or ag:IsPlaying() then
                    ag:Stop()
                end
            end
        end
    end

    function DynamicTalent:HideTalentTreeBackdrop()
        self:PauseTalentTreeBackdropAnims()
        if IsPlayerInCombat() then
            pendingBackdropRefresh = true
            self._pendingBackdropRefresh = true
            return
        end
        if talentBackdropFrame then
            talentBackdropFrame:Hide()
        end
        local tf = _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.TalentsFrame
        SyncBlizzardSpecBackground(tf, false)
    end

    function DynamicTalent:UpdateTalentTreeBackdrop()
        if IsPlayerInCombat() then
            pendingBackdropRefresh = true
            self._pendingBackdropRefresh = true
            return
        end
        pendingBackdropRefresh = false
        self._pendingBackdropRefresh = false
        local db = EnsureDB()
        if IsModuleDisabledInSuite("DynamicTalent") or db.enabled == false then
            self:HideTalentTreeBackdrop()
            return
        end

        local tf = _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.TalentsFrame
        if not tf then return end
        local bg = self:EnsureTalentTreeBackdrop()
        if not bg then return end

        local base = (db.talentBackdropBase == "BLIZZARD") and "BLIZZARD" or "OBSIDIAN"
        local mist = (db.talentBackdropMist == "OFF" or db.talentBackdropMist == "CLASS_GLOW") and db.talentBackdropMist or "HERO_MIST"
        local dimmer = math.max(0, math.min(0.85, (tonumber(db.talentBackdropDimmer) or 35) / 100))
        local intensity = math.max(15, math.min(100, tonumber(db.talentBackdropMistIntensity) or 60))
        local animate = (db.talentBackdropAnimate ~= false)

        local function SetVignettesShown(show)
            for _, vt in ipairs(bg.vignettes) do
                if show then vt:Show() else vt:Hide() end
            end
        end

        -- 1. Base Background & Dimmer (Dimmer darkens Blizzard Spec Art strictly behind Ambient Mist)
        if base == "BLIZZARD" then
            SyncBlizzardSpecBackground(tf, false)
            bg.baseCanvas:Hide()
            SetVignettesShown(false)
            if dimmer > 0.001 then
                bg.dimmerWash:SetColorTexture(0.012, 0.015, 0.020, dimmer)
                bg.dimmerWash:Show()
            else
                bg.dimmerWash:Hide()
            end
        else
            SyncBlizzardSpecBackground(tf, true)
            bg.baseCanvas:Show()
            bg.dimmerWash:Hide()
            SetVignettesShown(true)
        end

        -- 2. Ambient Mist (layers independently over both Blizzard Spec Art and Solid Obsidian)
        if mist == "OFF" then
            self:PauseTalentTreeBackdropAnims()
            bg.mistPrimary:Hide()
            bg.mistSecondary:Hide()
            bg.mistFocal:Hide()
            if base == "BLIZZARD" and dimmer <= 0.001 then
                bg:Hide()
            else
                bg:Show()
                LayoutBackdropLayers()
            end
            return
        end

        local pal = (mist == "HERO_MIST") and self:GetHeroMoodPalette() or self:GetClassGlowPalette()
        local p = pal.primary
        local s = pal.secondary
        local g = pal.glow

        bg.mistPrimary:SetVertexColor(p[1], p[2], p[3], 1)
        bg.mistPrimary:Show()

        bg.mistSecondary:SetVertexColor(s[1], s[2], s[3], 1)
        bg.mistSecondary:Show()

        bg.mistFocal:SetVertexColor(g[1], g[2], g[3], 1)
        bg.mistFocal:Show()

        bg:Show()
        LayoutBackdropLayers()

        local intScale = intensity / 60
        local function ClampAlpha(v)
            return math.max(0.04, math.min(0.90, v))
        end

        local mistLayers = {
            {
                tex    = bg.mistPrimary,
                ag     = bg.mistPrimaryAnim,
                aFrom  = ClampAlpha(0.28 * intScale),
                aTo    = ClampAlpha(0.48 * intScale),
                aStat  = ClampAlpha(0.38 * intScale),
            },
            {
                tex    = bg.mistSecondary,
                ag     = bg.mistSecondaryAnim,
                aFrom  = ClampAlpha(0.20 * intScale),
                aTo    = ClampAlpha(0.36 * intScale),
                aStat  = ClampAlpha(0.28 * intScale),
            },
            {
                tex    = bg.mistFocal,
                ag     = bg.mistFocalAnim,
                aFrom  = ClampAlpha(0.24 * intScale),
                aTo    = ClampAlpha(0.40 * intScale),
                aStat  = ClampAlpha(0.32 * intScale),
            },
        }

        local tfShown = (type(tf.IsShown) ~= "function") or tf:IsShown()
        if animate and tfShown then
            for _, mp in ipairs(mistLayers) do
                if mp.ag and mp.ag.Play then
                    local boundsChanged = (mp.ag._lastAFrom ~= mp.aFrom or mp.ag._lastATo ~= mp.aTo)
                    if mp.ag._alphaAnim then
                        if mp.ag._alphaAnim.SetFromAlpha then mp.ag._alphaAnim:SetFromAlpha(mp.aFrom) end
                        if mp.ag._alphaAnim.SetToAlpha then mp.ag._alphaAnim:SetToAlpha(mp.aTo) end
                    end
                    mp.ag._lastAFrom = mp.aFrom
                    mp.ag._lastATo = mp.aTo
                    mp.tex:SetAlpha(1.0)
                    if boundsChanged and mp.ag.Stop and (not mp.ag.IsPlaying or mp.ag:IsPlaying()) then
                        mp.ag:Stop()
                    end
                    if not mp.ag.IsPlaying or not mp.ag:IsPlaying() then
                        mp.ag:Play()
                    end
                else
                    mp.tex:SetAlpha(mp.aStat)
                end
            end
        else
            self:PauseTalentTreeBackdropAnims()
            for _, mp in ipairs(mistLayers) do
                mp.tex:SetAlpha(mp.aStat)
            end
        end
    end
end

function DynamicTalent:GetSavedTalentLoadouts()
    local list = {}
    local specID = self:GetActiveSpecID()
    if not specID or not (C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID and C_Traits and C_Traits.GetConfigInfo) then
        return list
    end
    local ok, ids = pcall(C_ClassTalents.GetConfigIDsBySpecID, specID)
    if not ok or _IsSecret(ids) or type(ids) ~= "table" then return list end
    for _, cid in ipairs(ids) do
        if not _IsSecret(cid) and type(cid) == "number" and cid > 0 then
            local okI, info = pcall(C_Traits.GetConfigInfo, cid)
            if okI and not _IsSecret(info) and type(info) == "table" and not _IsSecret(info.name) and type(info.name) == "string" and info.name ~= "" then
                table.insert(list, { id = cid, name = info.name })
            end
        end
    end
    table.sort(list, function(a, b)
        local na = tostring(a.name or "")
        local nb = tostring(b.name or "")
        local nal, nbl = na:lower(), nb:lower()
        if nal ~= nbl then return nal < nbl end
        return na < nb
    end)
    return list
end

function DynamicTalent:GetPreferredTalentLoadout(zoneKey)
    if not self.db then return nil, nil end
    local specID = self:GetActiveSpecID()
    if not specID then return nil, nil end
    local bySpec = self.db.talentPreferredBySpec and self.db.talentPreferredBySpec[specID]
    local targetID = bySpec and bySpec[zoneKey]
    if not targetID then return nil, nil end
    for _, item in ipairs(self:GetSavedTalentLoadouts()) do
        if item.id == targetID then
            return item.id, item.name
        end
    end
    return nil, nil
end

function DynamicTalent:CyclePreferredTalentLoadout(zoneKey)
    if not self.db then self:InitDB() end
    local specID = self:GetActiveSpecID()
    if not specID then return end
    local loadouts = self:GetSavedTalentLoadouts()
    if #loadouts == 0 then
        Print("No saved Blizzard Talent Loadouts found for your active specialisation.")
        return
    end
    self.db.talentPreferredBySpec = self.db.talentPreferredBySpec or {}
    self.db.talentPreferredBySpec[specID] = self.db.talentPreferredBySpec[specID] or {}
    local curID = self.db.talentPreferredBySpec[specID][zoneKey]
    local nextID = nil
    if not curID then
        nextID = loadouts[1].id
    else
        for i, item in ipairs(loadouts) do
            if item.id == curID then
                if i < #loadouts then nextID = loadouts[i + 1].id else nextID = nil end
                break
            end
        end
    end
    self.db.talentPreferredBySpec[specID][zoneKey] = nextID
end

-- ============================================================================
-- 8. SHARED ALERT TOAST ENGINE (DynamicTalentReminderToast)
-- ============================================================================
local function GetTalentSharedToastStyle()
    if _G.DynamicSuite and type(_G.DynamicSuite.GetSharedToastStyle) == "function" then
        local ok, st = pcall(_G.DynamicSuite.GetSharedToastStyle, "ACTION")
        if ok and type(st) == "table" then return st end
    end
    local ar, ag, ab = GetActiveAccentRGB()
    local g = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global) or {}
    local dur = tonumber(g.toastActionDuration)
    if dur == nil then
        local leg = tonumber(g.toastDuration)
        if leg == 0 then
            dur = 0
        elseif leg ~= nil then
            dur = math.max(12, (leg <= 6 and 5 or (leg <= 10 and 8 or (leg <= 16 and 12 or 20))))
        else
            dur = 12
        end
    end
    return {
        scale          = math.max(0.60, math.min(1.50, tonumber(g.toastScale) or 1.0)),
        opacity        = math.max(0.20, math.min(1.00, tonumber(g.toastOpacity or g.toastAlpha) or 0.96)),
        borderStyle    = tostring(g.toastBorderStyle or "ACCENT"):upper(),
        duration       = dur,
        actionDuration = dur,
        toastKind      = "ACTION",
        pos            = g.toastPos or { point = "TOP", relPoint = "TOP", x = 0, y = -140 },
        bgR = 0.035, bgG = 0.039, bgB = 0.051,
        ar = ar, ag = ag, ab = ab,
    }
end

local function StyleToastSwapButton(swapBtn, st, isHover)
    if not swapBtn then return end
    st = st or GetTalentSharedToastStyle()
    local ar, ag, ab = st.ar, st.ag, st.ab
    local bgMult = isHover and 0.56 or 0.42
    local bdrAlpha = isHover and 1.00 or 0.95
    SetPixelBackdrop(swapBtn, { ar * bgMult, ag * bgMult, ab * bgMult, isHover and 1.00 or 0.98 }, { ar, ag, ab, bdrAlpha }, 1)
    if swapBtn.txt then swapBtn.txt:SetTextColor(1, 1, 1, 1) end
end

function DynamicTalent:ApplyTalentReminderToastVisuals()
    local f = talentReminderToast
    if not f then return end
    if IsPlayerInCombat() then return end
    local st = nil
    if _G.DynamicSuite and type(_G.DynamicSuite.ApplySharedToastLayout) == "function" then
        local ok, sharedSt = pcall(_G.DynamicSuite.ApplySharedToastLayout, f, { toastKind = "ACTION", tintIcon = true })
        if ok and type(sharedSt) == "table" then
            st = sharedSt
        end
    end
    if not st then
        st = GetTalentSharedToastStyle()
        local ar, ag, ab = st.ar, st.ag, st.ab
        local bStyle = tostring(st.borderStyle or "ACCENT"):upper()

        f:SetFrameStrata("TOOLTIP")
        f:SetFrameLevel(20)
        f:SetToplevel(false)
        f:SetScale(st.scale or 1.0)
        f:SetBackdropColor(st.bgR or 0.035, st.bgG or 0.039, st.bgB or 0.051, st.opacity or 0.96)
        if bStyle == "NONE" or bStyle == "BORDERLESS" then
            f:SetBackdropBorderColor(0, 0, 0, 0)
        elseif bStyle == "DARK" or bStyle == "SUBTLE" then
            f:SetBackdropBorderColor(0.20, 0.24, 0.32, 0.95)
        else
            f:SetBackdropBorderColor(ar, ag, ab, 0.92)
        end
        if f.iconBorder then
            f.iconBorder:SetBackdropBorderColor(ar, ag, ab, 0.85)
        end
        if f.iconTex then
            f.iconTex:SetVertexColor(ar, ag, ab, 1.0)
        end
        if f:IsShown() and _G.DynamicSuite and type(_G.DynamicSuite.RestackAllToasts) == "function" then
            pcall(_G.DynamicSuite.RestackAllToasts)
        end
    end
    if f.swapBtn then
        StyleToastSwapButton(f.swapBtn, st, f.swapBtn.IsMouseOver and f.swapBtn:IsMouseOver())
    end
end

function DynamicTalent:HideTalentReminderToast()
    if not talentReminderToast then return end
    if _G.DynamicSuite and type(_G.DynamicSuite.HideSharedToast) == "function" then
        pcall(_G.DynamicSuite.HideSharedToast, talentReminderToast)
    elseif not IsPlayerInCombat() then
        if talentReminderToast.animGroup then talentReminderToast.animGroup:Stop() end
        talentReminderToast:Hide()
        talentReminderToast:SetAlpha(1)
    end
end

local function HandleTalentToastRightClick(toastFrame)
    if toastFrame and not toastFrame._isPreview and toastFrame._mKey then
        DynamicTalent:SilenceTalentMismatch(toastFrame._mKey, toastFrame._zoneLabel)
    else
        DynamicTalent:HideTalentReminderToast()
    end
end

function DynamicTalent:ShowTalentReminderToast(targetID, targetName, zoneLabel, isPreview, mKey)
    if IsPlayerInCombat() then return end
    if not talentReminderToast then
        local f = nil
        if _G.DynamicSuite and type(_G.DynamicSuite.EnsureSharedToastFrame) == "function" then
            local ok, sharedFrame = pcall(_G.DynamicSuite.EnsureSharedToastFrame, "DynamicTalentReminderToast", {
                toastKind = "ACTION",
                clickButtons = { "LeftButtonUp", "RightButtonUp" },
                iconMode = "TINTED",
                iconTexture = ICON_COLOR,
                rightActionWidth = 74,
                rightActionGap = 10,
                autoFade = true,
                onRightClickDismiss = function(selfT)
                    HandleTalentToastRightClick(selfT or talentReminderToast)
                end,
            })
            if ok and sharedFrame then
                f = sharedFrame
            end
        end

        if not f then
            f = CreateFrame("Button", "DynamicTalentReminderToast", UIParent, "BackdropTemplate")
            f:SetSize(460, 74)
            f:SetFrameStrata("TOOLTIP")
            f:SetFrameLevel(20)
            f:SetToplevel(false)
            f:SetClampedToScreen(true)
            f:EnableMouse(true)
            f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            f:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = false, tileSize = 0, edgeSize = 1.5,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })

            local iconBorder = CreateFrame("Frame", nil, f, "BackdropTemplate")
            iconBorder:SetSize(44, 44)
            iconBorder:SetPoint("LEFT", f, "LEFT", 14, 0)
            iconBorder:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = false, tileSize = 0, edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            iconBorder:SetBackdropColor(0.04, 0.05, 0.07, 1)
            local ic = iconBorder:CreateTexture(nil, "ARTWORK")
            ic:SetSize(30, 30)
            ic:SetPoint("CENTER", iconBorder, "CENTER", 0, 0)
            ic:SetTexture(ICON_COLOR)
            f.iconBorder = iconBorder
            f.iconTex = ic

            local title = CreateText(f, "OVERLAY", "GameFontHighlight")
            title:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -11)
            title:SetPoint("RIGHT", f, "RIGHT", -96, 0)
            title:SetJustifyH("LEFT")
            title:SetWordWrap(false)
            f.title = title

            local badge = CreateText(f, "OVERLAY", "GameFontHighlightSmall")
            badge:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
            badge:SetPoint("RIGHT", f, "RIGHT", -96, 0)
            badge:SetJustifyH("LEFT")
            badge:SetWordWrap(false)
            f.badge = badge

            local subtext = CreateText(f, "OVERLAY", "GameFontHighlightSmall")
            subtext:SetPoint("TOPLEFT", badge, "BOTTOMLEFT", 0, -5)
            subtext:SetPoint("RIGHT", f, "RIGHT", -96, 0)
            subtext:SetJustifyH("LEFT")
            subtext:SetWordWrap(false)
            f.subtext = subtext

            local animGroup = f:CreateAnimationGroup()
            local holdAnim = animGroup:CreateAnimation("Animation")
            holdAnim:SetDuration(12)
            holdAnim:SetOrder(1)
            local fadeAnim = animGroup:CreateAnimation("Alpha")
            fadeAnim:SetFromAlpha(1)
            fadeAnim:SetToAlpha(0)
            fadeAnim:SetDuration(1.2)
            fadeAnim:SetOrder(2)
            animGroup:SetScript("OnFinished", function()
                f:Hide()
                f:SetAlpha(1)
            end)
            f.animGroup = animGroup
            f.holdAnim = holdAnim

            f:SetScript("OnClick", function(selfT, button)
                if button == "RightButton" then
                    HandleTalentToastRightClick(selfT)
                end
            end)
            f:SetScript("OnEnter", function(selfT)
                selfT.animGroup:Pause()
                selfT:SetAlpha(1)
            end)
            f:SetScript("OnLeave", function(selfT)
                if selfT.swapBtn and selfT.swapBtn.IsMouseOver and selfT.swapBtn:IsMouseOver() then return end
                local stLeave = GetTalentSharedToastStyle()
                local leaveDur = tonumber(stLeave.duration)
                if leaveDur == nil then leaveDur = 12 end
                if leaveDur > 0 then
                    selfT.animGroup:Play()
                end
            end)
            f:HookScript("OnHide", function()
                if _G.DynamicSuite and type(_G.DynamicSuite.RestackAllToasts) == "function" then
                    pcall(_G.DynamicSuite.RestackAllToasts)
                end
            end)
        end

        if not f.swapBtn then
            local swapBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
            swapBtn:SetSize(74, 26)
            swapBtn:SetPoint("RIGHT", f, "RIGHT", -12, 0)
            swapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            swapBtn.txt = CreateText(swapBtn, "OVERLAY", "GameFontHighlightSmall")
            swapBtn.txt:SetPoint("CENTER")
            swapBtn.txt:SetText("Swap")
            f.swapBtn = swapBtn
        end
        if f.SetRightTextAnchor then
            f.SetRightTextAnchor(f.swapBtn, 10)
        elseif f.title and f.badge and f.subtext then
            f.title:ClearAllPoints()
            f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -11)
            f.title:SetPoint("RIGHT", f.swapBtn, "LEFT", -10, 0)
            f.badge:ClearAllPoints()
            f.badge:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -5)
            f.badge:SetPoint("RIGHT", f.swapBtn, "LEFT", -10, 0)
            f.subtext:ClearAllPoints()
            f.subtext:SetPoint("TOPLEFT", f.badge, "BOTTOMLEFT", 0, -5)
            f.subtext:SetPoint("RIGHT", f.swapBtn, "LEFT", -10, 0)
        end

        talentReminderToast = f
    end

    local f = talentReminderToast
    f._mKey = mKey
    f._zoneLabel = zoneLabel
    f._isPreview = (isPreview == true)
    local st = GetTalentSharedToastStyle()
    local dur = tonumber(st.duration)
    if dur == nil then dur = 12 end

    f.swapBtn:SetScript("OnEnter", function(s)
        local curSt = GetTalentSharedToastStyle()
        if f.animGroup then f.animGroup:Pause() end
        f:SetAlpha(1)
        StyleToastSwapButton(s, curSt, true)
    end)
    f.swapBtn:SetScript("OnLeave", function(s)
        local curSt = GetTalentSharedToastStyle()
        StyleToastSwapButton(s, curSt, false)
        local leaveDur = tonumber(curSt.duration)
        if leaveDur == nil then leaveDur = 12 end
        if not (f.IsMouseOver and f:IsMouseOver()) and f.animGroup and leaveDur > 0 then
            f.animGroup:Play()
        end
    end)

    local dispTarget = tostring(targetName or "Loadout")
    if type(targetID) == "table" and targetID.group then
        dispTarget = string.format("%s |cFFFFFFFF%s|r", self:FormatTalentBadge(targetID), dispTarget)
    else
        dispTarget = "|cFFFFFFFF" .. dispTarget .. "|r"
    end
    local titleText = string.format("|cFFCBD5E1Dynamic|r|cFFFFFFFFTalent|r  |cFF475569|||r  |cFFFBBF24%s Talent Alert|r", zoneLabel or "Zone")
    local badgeText = "|cFF94A3B8Recommended:|r " .. dispTarget
    local subtextText = "|cFF34D399Click Swap|r |cFF94A3B8to switch|r  |cFF475569|||r  |cFF38BDF8Right-Click|r |cFF94A3B8to silence|r"

    f.swapBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            HandleTalentToastRightClick(f)
            return
        end
        if isPreview then
            DynamicTalent:HideTalentReminderToast()
            return
        end
        if IsPlayerInCombat() or IsMythicPlusActive() then return end
        if type(targetID) == "table" then
            DynamicTalent:ApplyTalentLibraryEntry(targetID)
        elseif targetID and C_ClassTalents and type(C_ClassTalents.LoadConfig) == "function" then
            pcall(C_ClassTalents.LoadConfig, targetID, true)
            DynamicTalent:InvalidateActiveTalentStringCache()
        end
        DynamicTalent:HideTalentReminderToast()
    end)

    if _G.DynamicSuite and type(_G.DynamicSuite.ShowSharedToast) == "function" then
        local okShown, resShown = pcall(_G.DynamicSuite.ShowSharedToast, f, {
            toastKind = "ACTION",
            title = titleText,
            badge = badgeText,
            subtext = subtextText,
            tintIcon = true,
            autoFade = true,
            playSound = true,
        })
        if okShown and resShown then
            StyleToastSwapButton(f.swapBtn, GetTalentSharedToastStyle(), false)
            return
        end
    end

    self:ApplyTalentReminderToastVisuals()
    f.title:SetText(titleText)
    f.badge:SetText(badgeText)
    f.subtext:SetText(subtextText)
    f.animGroup:Stop()
    f:SetAlpha(1)
    f:Show()
    if _G.DynamicSuite and type(_G.DynamicSuite.RestackAllToasts) == "function" then
        pcall(_G.DynamicSuite.RestackAllToasts)
    else
        f:ClearAllPoints()
        local dsToast = (_G.DynamicLoadToastFrame and _G.DynamicLoadToastFrame.IsShown and _G.DynamicLoadToastFrame:IsShown() and _G.DynamicLoadToastFrame)
        if dsToast then
            f:SetPoint("TOP", dsToast, "BOTTOM", 0, -8)
        elseif type(st.pos) == "table" and st.pos.point then
            f:SetPoint(st.pos.point, UIParent, st.pos.relPoint or st.pos.point, st.pos.x or 0, st.pos.y or -140)
        else
            f:SetPoint("TOP", UIParent, "TOP", 0, -140)
        end
    end
    if _G.DynamicSuite and type(_G.DynamicSuite.PlaySharedToastSound) == "function" then
        pcall(_G.DynamicSuite.PlaySharedToastSound)
    end
    if dur > 0 then
        f.holdAnim:SetDuration(dur)
        f.animGroup:Play()
    end
end

function DynamicTalent:CheckZoneTalentLoadout(reason)
    if not self.db or self.db.enabled == false or self.db.talentReminderEnabled == false or IsModuleDisabledInSuite("DynamicTalent") then
        return
    end
    if IsPlayerInCombat() then return end
    local mID, mName, mLabel, mKey = self:GetActiveTalentMismatch()
    local mTargetSig = (type(mID) == "table") and tostring(mID.id or mID.name or "") or tostring(mID or "")
    local curMismatchSig = tostring(mKey or "") .. "|" .. mTargetSig .. "|" .. tostring(mName or "")
    local mismatchChanged = (curMismatchSig ~= self._lastCheckedMismatchSig)
    self._lastCheckedMismatchSig = curMismatchSig

    local isPullCue = (reason == "READY_CHECK" or reason == "START_PLAYER_COUNTDOWN")
    local isPassiveBossTrigger = (reason == "TARGET" or reason == "SOFT_ENEMY" or reason == "MOUSEOVER" or reason == "NAMEPLATE")
    local isBossMismatch = (type(mKey) == "string" and mKey:sub(1, 5) == "boss:")

    if (not isPassiveBossTrigger or mismatchChanged)
        and _G.DynamicPrep and type(_G.DynamicPrep.RefreshBar) == "function" then
        pcall(_G.DynamicPrep.RefreshBar, _G.DynamicPrep)
    end

    if mID and self.db.talentReminderToastEnabled ~= false then
        if isBossMismatch then
            if not isPullCue and lastAlertedBossMismatchKey == mKey then
                return
            end
            lastAlertedBossMismatchKey = mKey
            self:ShowTalentReminderToast(mID, mName, mLabel, false, mKey)
        elseif not isPassiveBossTrigger then
            self:ShowTalentReminderToast(mID, mName, mLabel, false, mKey)
        end
    elseif not isPassiveBossTrigger then
        self:HideTalentReminderToast()
    end
end

function DynamicTalent:ImportTalentString(loadoutName, importString, groupName)
    if not self.db then self:InitDB() end
    local specID = self:GetActiveSpecID()
    if not specID then return false, "No active specialisation found." end
    local cleanName = SafeTrim(tostring(loadoutName or ""))
    local cleanStr = SafeTrim(tostring(importString or ""))
    if cleanName == "" or cleanStr == "" then
        return false, "Enter both a loadout name and a Warcraft Logs / Northern Sky / Blizzard export string."
    end
    local decoded, errMsg = self:DecodeTalentImportString(cleanStr)
    if not decoded then
        return false, errMsg or "Invalid talent export string."
    end
    self.db.talentStringLibrary = self.db.talentStringLibrary or {}
    self.db.talentStringLibrary[specID] = self.db.talentStringLibrary[specID] or {}
    local lib = self.db.talentStringLibrary[specID]
    local grp = NormalizeTalentGroupKey((type(groupName) == "string" and groupName ~= "") and groupName or CategoriseTalentGroup(cleanName))
    local newHero = self:DetectHeroTreeFromString(cleanStr) or ""
    local liveStr = self:GetActiveTalentString()
    local isLiveMatch = (liveStr and liveStr == cleanStr)
    local savedEntry = nil
    for _, entry in ipairs(lib) do
        if type(entry) == "table" and type(entry.name) == "string" and entry.name:lower() == cleanName:lower() then
            local exGrp = NormalizeTalentGroupKey(entry.group or CategoriseTalentGroup(entry.name))
            local exHero = self:GetLoadoutHeroAcronym(entry) or ""
            if exGrp == grp and (exHero == newHero or entry.importString == cleanStr) then
                EnsureEntryID(entry, self.db)
                entry.name = cleanName
                entry.group = grp
                entry.importString = cleanStr
                entry.liveHash = isLiveMatch and liveStr or nil
                entry._heroStrHash = nil
                savedEntry = entry
                break
            end
        end
    end
    if not savedEntry then
        savedEntry = {
            id           = GenerateLoadoutID(self.db),
            name         = cleanName,
            group        = grp,
            importString = cleanStr,
            liveHash     = isLiveMatch and liveStr or nil,
        }
        table.insert(lib, savedEntry)
    end
    self:RefreshLoadoutHeroMeta(savedEntry)
    if isLiveMatch then
        self.db.lastAppliedTalentID = self.db.lastAppliedTalentID or {}
        self.db.lastAppliedTalentID[specID] = EnsureEntryID(savedEntry, self.db)
        self.db.lastAppliedTalentName = self.db.lastAppliedTalentName or {}
        self.db.lastAppliedTalentName[specID] = cleanName
        self.db.lastAppliedTalentLiveStr = self.db.lastAppliedTalentLiveStr or {}
        self.db.lastAppliedTalentLiveStr[specID] = liveStr
    end
    self:InvalidateActiveTalentStringCache()
    Print(string.format("Saved %s |cFFFFFFFF%s|r to Talent Loadouts.", self:FormatTalentBadge(savedEntry), cleanName))
    self:SyncTalentBindsUI()
    return true, "Saved '" .. cleanName .. "' cleanly.", savedEntry
end

function DynamicTalent:CheckBossTalentLoadout(reason)
    self:CheckZoneTalentLoadout(reason or "TARGET")
end

-- ============================================================================
-- 9. SEASON 2 RAIDS, MYTHIC+ DUNGEONS & QUICK GUIDE POPOVER
-- ============================================================================
do
    DynamicTalent.MIDNIGHT_S2_RAIDS = {
        {
            id    = -1001,
            name  = "The Venomous Abyss",
            short = "Venomous Abyss",
            bosses = {
                { order = 1, id = -101, name = "Nek'zali the Soulcoiler", short = "1. Nek'zali",    aliases = { "nek'zali" } },
                { order = 2, id = -102, name = "Entombed Sentinels",      short = "2. Sentinels",   aliases = { "breath of ula'tek", "blood of ula'tek", "entombed sentinel" } },
                { order = 3, id = -103, name = "The Lost Explorers",      short = "3. Explorers",   aliases = { "gebbo", "trader gebbo", "iku", "epu", "scrollsage iku", "scrollsage epu", "nama", "nema", "first mate nama", "first mate nema", "mor'zahi", "lost explorer" } },
                { order = 4, id = -104, name = "Vashnik the Malignant",   short = "4. Vashnik",     aliases = { "vashnik" } },
                { order = 5, id = -105, name = "Sszorak",                 short = "5. Sszorak",     aliases = { "sszorak" } },
                { order = 6, id = -106, name = "The Twin Fangs",          short = "6. Twin Fangs",  aliases = { "vexhul", "ithraz", "twin fang" } },
                { order = 7, id = -107, name = "The Coiled Altar",        short = "7. Coiled Altar",aliases = { "coiled altar" } },
                { order = 8, id = -108, name = "Ula'tek",                 short = "8. Ula'tek",     aliases = { "ula'tek", "ulatek" } },
            },
        },
        {
            id    = -1002,
            name  = "The Unbinding of Kith'ix",
            short = "Kith'ix",
            bosses = {
                { order = 1, id = -201, name = "Kith'ix", short = "1. Kith'ix", aliases = { "kith'ix" } },
            },
        },
        {
            id    = -1003,
            name  = "The Tidebound Grotto",
            short = "Tidebound Grotto",
            bosses = {
                { order = 1, id = -301, name = "Nymrissa Wavecaller", short = "1. Nymrissa", aliases = { "nymrissa" } },
            },
        },
    }

    local function CloneSeason2Baseline()
        local out = {}
        for _, r in ipairs(DynamicTalent.MIDNIGHT_S2_RAIDS) do
            local rCopy = { id = r.id, name = r.name, short = r.short, bosses = {} }
            for _, b in ipairs(r.bosses) do
                local al = {}
                if type(b.aliases) == "table" then
                    for _, a in ipairs(b.aliases) do
                        table.insert(al, tostring(a):lower())
                    end
                end
                table.insert(rCopy.bosses, {
                    order   = b.order,
                    id      = b.id,
                    name    = b.name,
                    short   = b.short,
                    aliases = al,
                })
            end
            table.insert(out, rCopy)
        end
        return out
    end

    local function AddAliasUnique(bObj, aliasStr)
        if type(aliasStr) ~= "string" or _IsSecret(aliasStr) or aliasStr == "" then return end
        local low = SafeTrim(aliasStr):lower()
        if low == "" then return end
        bObj.aliases = bObj.aliases or {}
        for _, ex in ipairs(bObj.aliases) do
            if ex == low then return end
        end
        table.insert(bObj.aliases, low)
    end

    local function TryEnrichWithEJ(raids)
        if IsPlayerInCombat() then return false end
        if type(EJ_GetNumTiers) ~= "function" or type(EJ_SelectTier) ~= "function"
            or type(EJ_GetInstanceByIndex) ~= "function" or type(EJ_SelectInstance) ~= "function"
            or type(EJ_GetEncounterInfoByIndex) ~= "function" then
            return false
        end
        local prevTier = nil
        if type(EJ_GetCurrentTier) == "function" then
            local okPT, pt = pcall(EJ_GetCurrentTier)
            if okPT and not _IsSecret(pt) and type(pt) == "number" then prevTier = pt end
        end
        local numTiers = 0
        if type(EJ_GetNumTiers) == "function" then
            local okNT, nt = pcall(EJ_GetNumTiers)
            if okNT and not _IsSecret(nt) and type(nt) == "number" then numTiers = nt end
        end
        if numTiers <= 0 then return false end

        local function ScanTier(tierIdx)
            if not tierIdx or tierIdx < 1 then return false end
            local matchedAny = false
            pcall(EJ_SelectTier, tierIdx)
            for i = 1, 20 do
                local okI, instID, instName = pcall(EJ_GetInstanceByIndex, i, true)
                if not okI or _IsSecret(instID) or not instID then break end
                if type(instName) == "string" and not _IsSecret(instName) and instName ~= "" then
                    local instLow = instName:lower()
                    local targetRaid = nil
                    for _, rObj in ipairs(raids) do
                        local rLow = rObj.name:lower()
                        local sLow = (rObj.short or ""):lower()
                        if instLow == rLow or (sLow ~= "" and instLow:find(sLow, 1, true)) then
                            targetRaid = rObj
                            break
                        end
                    end
                    if targetRaid then
                        matchedAny = true
                        targetRaid.id = instID
                        pcall(EJ_SelectInstance, instID)
                        for j = 1, 30 do
                            local okB, bName, _, encID = pcall(EJ_GetEncounterInfoByIndex, j, instID)
                            if not okB or _IsSecret(bName) or not bName then break end
                            if type(bName) == "string" and bName ~= "" then
                                local bLow = bName:lower()
                                local targetBoss = nil
                                for _, bObj in ipairs(targetRaid.bosses) do
                                    if bObj.name:lower() == bLow then
                                        targetBoss = bObj
                                        break
                                    end
                                end
                                if not targetBoss and targetRaid.bosses[j] then
                                    targetBoss = targetRaid.bosses[j]
                                end
                                if targetBoss then
                                    local validEncID = (not _IsSecret(encID) and type(encID) == "number" and encID > 0) and encID or nil
                                    if validEncID then targetBoss.id = validEncID end
                                    AddAliasUnique(targetBoss, bName)
                                    if validEncID and type(_G.EJ_GetCreatureInfo) == "function" then
                                        for cIdx = 1, 6 do
                                            local okC, _, cName = pcall(_G.EJ_GetCreatureInfo, cIdx, validEncID)
                                            if not okC or _IsSecret(cName) or not cName then break end
                                            AddAliasUnique(targetBoss, cName)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            return matchedAny
        end

        local enriched = ScanTier(numTiers)
        if not enriched and numTiers > 1 then
            enriched = ScanTier(numTiers - 1)
        end
        if prevTier and prevTier >= 1 then
            pcall(EJ_SelectTier, prevTier)
        end
        return enriched
    end

    function DynamicTalent:GetSeason2Raids(forceRefresh)
        if not forceRefresh and type(self._cachedTierRaids) == "table" and #self._cachedTierRaids > 0 then
            if not self._ejEnriched and not self._ejEnrichAttempted and not IsPlayerInCombat() then
                self._ejEnrichAttempted = true
                if TryEnrichWithEJ(self._cachedTierRaids) then
                    self._ejEnriched = true
                end
            end
            return self._cachedTierRaids
        end
        local raids = CloneSeason2Baseline()
        if forceRefresh then
            self._ejEnrichAttempted = false
        end
        if not IsPlayerInCombat() then
            self._ejEnrichAttempted = true
            self._ejEnriched = TryEnrichWithEJ(raids) and true or false
        else
            self._ejEnriched = false
        end
        self._cachedTierRaids = raids
        return raids
    end

    function DynamicTalent:MatchBossTargetName(targetName, raidsList)
        if type(targetName) ~= "string" or _IsSecret(targetName) or targetName == "" then
            return nil
        end
        local lowT = SafeTrim(targetName):lower()
        if lowT == "" then return nil end
        local raids = raidsList or self:GetSeason2Raids()

        for rIdx, rObj in ipairs(raids) do
            for bIdx, bObj in ipairs(rObj.bosses or {}) do
                if tostring(bObj.name or ""):lower() == lowT then
                    return rIdx, bIdx, rObj, bObj
                end
            end
        end
        for rIdx, rObj in ipairs(raids) do
            for bIdx, bObj in ipairs(rObj.bosses or {}) do
                for _, alias in ipairs(bObj.aliases or {}) do
                    if alias == lowT then
                        return rIdx, bIdx, rObj, bObj
                    end
                end
            end
        end
        for rIdx, rObj in ipairs(raids) do
            for bIdx, bObj in ipairs(rObj.bosses or {}) do
                for _, alias in ipairs(bObj.aliases or {}) do
                    if #alias >= 4 and lowT:find(alias, 1, true) then
                        return rIdx, bIdx, rObj, bObj
                    end
                end
            end
        end
        for rIdx, rObj in ipairs(raids) do
            for bIdx, bObj in ipairs(rObj.bosses or {}) do
                local bLow = tostring(bObj.name or ""):lower()
                if #bLow >= 4 and lowT:find(bLow, 1, true) then
                    return rIdx, bIdx, rObj, bObj
                end
            end
        end
        return nil
    end
end

local function GetCurrentTierRaids()
    return DynamicTalent:GetSeason2Raids()
end

local function GetCurrentSeasonMythicPlusDungeons()
    local list = {}
    if not (C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo) then
        return list
    end
    local okT, mapIDs = pcall(C_ChallengeMode.GetMapTable)
    if (not okT or type(mapIDs) ~= "table" or #mapIDs == 0) and type(C_ChallengeMode.RequestMapInfo) == "function" then
        pcall(C_ChallengeMode.RequestMapInfo)
        okT, mapIDs = pcall(C_ChallengeMode.GetMapTable)
    end
    if not okT or type(mapIDs) ~= "table" then return list end
    local seen = {}
    for _, mapID in ipairs(mapIDs) do
        if not _IsSecret(mapID) and type(mapID) == "number" then
            local okN, name, _, _, texture = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
            if okN and not _IsSecret(name) and type(name) == "string" and name ~= "" and not seen[name] then
                seen[name] = true
                local safeTex = (not _IsSecret(texture) and texture) or 525134
                local shortTag = ""
                for w in name:gmatch("%a+") do
                    if #shortTag < 3 then shortTag = shortTag .. w:sub(1, 1):upper() end
                end
                if #shortTag < 2 then shortTag = name:sub(1, 3):upper() end
                table.insert(list, { id = mapID, name = name, icon = safeTex, short = shortTag })
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- Reusable truncation safety net: shows the full clean text on hover, but only when
-- the single-line FontString is actually cut off. Never replaces existing button/tile tooltips.
function DynamicTalent.AttachTruncationTooltip(fs, owner)
    if not fs or fs._dtTruncHooked or type(fs.GetText) ~= "function" then return end
    fs._dtTruncHooked = true
    local host = owner
    if not host then
        local parent = fs.GetParent and fs:GetParent()
        if not parent then return end
        host = CreateFrame("Frame", nil, parent)
        host:SetAllPoints(fs)
        host:EnableMouse(true)
        fs._dtTruncHost = host
    elseif host.EnableMouse then
        host:EnableMouse(true)
    end
    if type(host.HookScript) ~= "function" then return end
    host:HookScript("OnEnter", function(s)
        local isTrunc = false
        if type(fs.IsTruncated) == "function" then
            local okTr, tr = pcall(fs.IsTruncated, fs)
            isTrunc = okTr and not _IsSecret(tr) and tr == true
        end
        if not isTrunc then return end
        if not GameTooltip then return end
        local okT, rawTxt = pcall(fs.GetText, fs)
        local raw = okT and SafeStr(rawTxt, "") or ""
        local clean = raw:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        if clean == "" then return end
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(clean, 0.89, 0.91, 0.94, true)
        GameTooltip:Show()
        s._dtTruncShown = true
    end)
    host:HookScript("OnLeave", function(s)
        if s._dtTruncShown then
            s._dtTruncShown = nil
            if GameTooltip then GameTooltip:Hide() end
        end
    end)
end

local function CreateModalSectionHeader(parent, title, subtitle, yOff)
    local ar, ag, ab = GetActiveAccentRGB()
    local wrap = CreateFrame("Frame", nil, parent)
    wrap:SetHeight(34)
    wrap:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOff)
    wrap:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOff)

    local bar = wrap:CreateTexture(nil, "ARTWORK")
    bar:SetSize(3, 30)
    bar:SetPoint("TOPLEFT", wrap, "TOPLEFT", 0, -1)
    bar:SetColorTexture(ar, ag, ab, 0.95)
    wrap.bar = bar

    local textArea = CreateFrame("Frame", nil, wrap)
    textArea:SetPoint("TOPLEFT", wrap, "TOPLEFT", 11, -2)
    textArea:SetPoint("BOTTOMLEFT", wrap, "BOTTOMLEFT", 11, 2)
    textArea:SetPoint("RIGHT", wrap, "RIGHT", -4, 0)
    wrap.textArea = textArea

    local titleFS = CreateText(textArea, "OVERLAY", "GameFontHighlightSmall")
    titleFS:SetPoint("TOPLEFT", textArea, "TOPLEFT", 0, 0)
    titleFS:SetPoint("TOPRIGHT", textArea, "TOPRIGHT", 0, 0)
    titleFS:SetJustifyH("LEFT")
    titleFS:SetWordWrap(false)
    titleFS:SetText(title)
    wrap.titleFS = titleFS

    local subFS = CreateText(textArea, "OVERLAY", "GameFontHighlightSmall")
    subFS:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -2)
    subFS:SetPoint("TOPRIGHT", titleFS, "BOTTOMRIGHT", 0, -2)
    subFS:SetJustifyH("LEFT")
    subFS:SetWordWrap(false)
    subFS:SetText("|cFF94A3B8" .. tostring(subtitle or "") .. "|r")
    wrap.subFS = subFS
    DynamicTalent.AttachTruncationTooltip(subFS)

    local line = wrap:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", wrap, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", wrap, "BOTTOMRIGHT", 0, 0)
    line:SetColorTexture(ar, ag, ab, 0.35)
    wrap.line = line

    return wrap
end

function DynamicTalent:CloseTalentQuickGuide()
    if self._quickGuideOwner then
        local owner = self._quickGuideOwner
        owner._guideOpen = false
        SetPixelBackdrop(owner, COLORS.BgElevated, COLORS.BorderSubtle, 1)
        if owner.txt then owner.txt:SetTextColor(0.84, 0.90, 0.96, 1) end
        self._quickGuideOwner = nil
    end
    if GameTooltip then GameTooltip:Hide() end
    if self._quickGuidePopover then self._quickGuidePopover:Hide() end
    if self._quickGuideCatcher then self._quickGuideCatcher:Hide() end
end

function DynamicTalent:ToggleTalentQuickGuide(anchorBtn, mgrModal)
    if self._quickGuidePopover and self._quickGuidePopover:IsShown() then
        self:CloseTalentQuickGuide()
        return
    end
    if mgrModal and mgrModal.CloseModalDropdown then
        mgrModal.CloseModalDropdown()
    end
    if GameTooltip then GameTooltip:Hide() end

    local ar, ag, ab, accentHex = GetActiveAccentRGB()
    if not self._quickGuideCatcher then
        local cat = CreateFrame("Button", "DynamicTalentQuickGuideCatcher", UIParent)
        cat:SetAllPoints(UIParent)
        cat:SetFrameStrata("FULLSCREEN_DIALOG")
        cat:SetFrameLevel(70)
        cat:EnableMouse(true)
        cat:RegisterForClicks("AnyDown")
        cat:Hide()
        cat:SetScript("OnClick", function()
            DynamicTalent:CloseTalentQuickGuide()
        end)
        self._quickGuideCatcher = cat
    end

    if not self._quickGuidePopover then
        local g = CreateFrame("Frame", "DynamicTalentQuickGuidePopover", UIParent, "BackdropTemplate")
        g:SetSize(420, 302)
        g:SetFrameStrata("FULLSCREEN_DIALOG")
        g:SetFrameLevel(75)
        g:SetClampedToScreen(true)
        g:EnableMouse(true)
        g:Hide()
        if _G.UISpecialFrames then
            table.insert(_G.UISpecialFrames, "DynamicTalentQuickGuidePopover")
        end
        if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.RegisterPopupCloser) == "function" then
            _G.DynamicSuite.UI.RegisterPopupCloser("DynamicTalentQuickGuidePopover", function()
                DynamicTalent:CloseTalentQuickGuide()
            end)
        end

        do
            local hdr = CreateFrame("Frame", nil, g, "BackdropTemplate")
            hdr:SetHeight(32)
            hdr:SetPoint("TOPLEFT", g, "TOPLEFT", 1, -1)
            hdr:SetPoint("TOPRIGHT", g, "TOPRIGHT", -1, -1)
            SetPixelBackdrop(hdr, { 0.016, 0.020, 0.024, 1.00 }, { 0, 0, 0, 0 }, 0)
            local div = hdr:CreateTexture(nil, "ARTWORK")
            div:SetHeight(1)
            div:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 0, 0)
            div:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
            div:SetColorTexture(1, 1, 1, 0.08)

            local ttl = CreateText(hdr, "OVERLAY", "GameFontHighlightSmall")
            ttl:SetPoint("LEFT", hdr, "LEFT", 12, 0)
            ttl:SetPoint("RIGHT", hdr, "RIGHT", -36, 0)
            ttl:SetJustifyH("LEFT")
            ttl:SetWordWrap(false)
            ttl:SetText(string.format("|cFFCBD5E1Dynamic|r|cFFFFFFFFTalent|r  |cFF475569|||r  |cFF%sQuick Guide|r", accentHex))
            g.ttlFS = ttl

            local closeBtn = CreateFrame("Button", nil, hdr)
            closeBtn:SetSize(32, 31)
            closeBtn:SetPoint("TOPRIGHT", hdr, "TOPRIGHT", 0, 0)
            local cbg = closeBtn:CreateTexture(nil, "BACKGROUND")
            cbg:SetAllPoints()
            cbg:SetColorTexture(0.957, 0.247, 0.369, 0.00)
            local x1 = closeBtn:CreateTexture(nil, "OVERLAY")
            x1:SetSize(11, 1.6); x1:SetPoint("CENTER"); x1:SetColorTexture(0.75, 0.80, 0.88, 0.90); x1:SetRotation(math.rad(45))
            local x2 = closeBtn:CreateTexture(nil, "OVERLAY")
            x2:SetSize(11, 1.6); x2:SetPoint("CENTER"); x2:SetColorTexture(0.75, 0.80, 0.88, 0.90); x2:SetRotation(math.rad(-45))
            closeBtn:SetScript("OnEnter", function() cbg:SetColorTexture(0.957, 0.247, 0.369, 0.22); x1:SetColorTexture(1, 1, 1, 1); x2:SetColorTexture(1, 1, 1, 1) end)
            closeBtn:SetScript("OnLeave", function() cbg:SetColorTexture(0.957, 0.247, 0.369, 0.00); x1:SetColorTexture(0.75, 0.80, 0.88, 0.90); x2:SetColorTexture(0.75, 0.80, 0.88, 0.90) end)
            closeBtn:SetScript("OnClick", function() DynamicTalent:CloseTalentQuickGuide() end)
        end

        g.pips = {}
        local sections = {
            {
                title = "BUILD DETAILS (LEFT)",
                body  = "Save your active tree, paste a Wowhead or Warcraft Logs string, or use Save & New to queue builds cleanly.",
            },
            {
                title = "TALENT BINDS & AUTO-SAVE (RIGHT)",
                body  = "Specific Raid Boss / M+ Dungeon / PvP Mode -> All Raids / All M+ / All PvP / Zone Defaults -> All Content. Binding a new build auto-saves it.",
            },
            {
                title = "QUICK TIPS",
                body  = "Click any Left-Hand Talent Dock build to load it straight into this editor, or Right-Click any dock build for Quick Assign.",
            },
        }
        for i, sec in ipairs(sections) do
            local card = CreateFrame("Frame", nil, g, "BackdropTemplate")
            card:SetHeight(62)
            card:SetPoint("TOPLEFT", g, "TOPLEFT", 12, -42 - ((i - 1) * 69))
            card:SetPoint("TOPRIGHT", g, "TOPRIGHT", -12, -42 - ((i - 1) * 69))
            SetPixelBackdrop(card, { 0.055, 0.063, 0.082, 1.00 }, { 1, 1, 1, 0.08 }, 1)

            local pip = card:CreateTexture(nil, "ARTWORK")
            pip:SetWidth(3)
            pip:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)
            pip:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 8, 8)
            pip:SetColorTexture(ar, ag, ab, 0.95)
            table.insert(g.pips, pip)

            local tFS = CreateText(card, "OVERLAY", "GameFontHighlightSmall")
            tFS:SetPoint("TOPLEFT", pip, "TOPRIGHT", 8, 1)
            tFS:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -7)
            tFS:SetJustifyH("LEFT")
            tFS:SetWordWrap(false)
            tFS:SetText("|cFFFFFFFF" .. sec.title .. "|r")

            local bFS = CreateText(card, "OVERLAY", "GameFontHighlightSmall")
            bFS:SetPoint("TOPLEFT", tFS, "BOTTOMLEFT", 0, -3)
            bFS:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -10, 6)
            bFS:SetJustifyH("LEFT")
            bFS:SetWordWrap(true)
            bFS:SetText("|cFFCBD5E1" .. sec.body .. "|r")
        end

        local demoBtn = CreateFrame("Button", nil, g, "BackdropTemplate")
        demoBtn:SetSize(148, 24)
        demoBtn:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", -12, 12)
        SetPixelBackdrop(demoBtn, { ar * 0.42, ag * 0.42, ab * 0.42, 1.00 }, { ar, ag, ab, 0.95 }, 1)
        demoBtn.txt = CreateText(demoBtn, "OVERLAY", "GameFontHighlightSmall")
        demoBtn.txt:SetPoint("CENTER")
        demoBtn.txt:SetText("Preview Swap Alert")
        demoBtn:SetScript("OnEnter", function(s)
            local r, gb, b = GetActiveAccentRGB()
            SetPixelBackdrop(s, { math.min(1, r * 0.56), math.min(1, gb * 0.56), math.min(1, b * 0.56), 1.00 }, { r, gb, b, 1.00 }, 1)
        end)
        demoBtn:SetScript("OnLeave", function(s)
            local r, gb, b = GetActiveAccentRGB()
            SetPixelBackdrop(s, { r * 0.42, gb * 0.42, b * 0.42, 1.00 }, { r, gb, b, 0.95 }, 1)
        end)
        demoBtn:SetScript("OnClick", function()
            local ownerModal = DynamicTalent._quickGuideMgr or talentMgrModal
            local sample = (ownerModal and ownerModal.GetSelectedLoadout and ownerModal:GetSelectedLoadout())
                or { name = "Raid ST", group = "Raid", heroAcronym = "WS" }
            DynamicTalent:ShowTalentReminderToast(sample, sample.name, "Preview: #8 Ula'tek (Heroic)", true)
        end)
        g.demoBtn = demoBtn

        local footFS = CreateText(g, "OVERLAY", "GameFontHighlightSmall")
        footFS:SetPoint("LEFT", g, "BOTTOMLEFT", 12, 24)
        footFS:SetPoint("RIGHT", demoBtn, "LEFT", -10, 0)
        footFS:SetJustifyH("LEFT")
        footFS:SetWordWrap(false)
        footFS:SetText("|cFF94A3B8See how swap alerts look in-game:|r")

        g:SetScript("OnHide", function()
            if DynamicTalent._quickGuideOwner then
                local owner = DynamicTalent._quickGuideOwner
                owner._guideOpen = false
                SetPixelBackdrop(owner, COLORS.BgElevated, COLORS.BorderSubtle, 1)
                if owner.txt then owner.txt:SetTextColor(0.84, 0.90, 0.96, 1) end
                DynamicTalent._quickGuideOwner = nil
            end
            if DynamicTalent._quickGuideCatcher then DynamicTalent._quickGuideCatcher:Hide() end
        end)
        self._quickGuidePopover = g
    end

    local g = self._quickGuidePopover
    self._quickGuideMgr = mgrModal
    SetPixelBackdrop(g, { 0.035, 0.039, 0.051, 1.00 }, { ar, ag, ab, 0.92 }, 1)
    if g.ttlFS then
        g.ttlFS:SetText(string.format("|cFFCBD5E1Dynamic|r|cFFFFFFFFTalent|r  |cFF475569|||r  |cFF%sQuick Guide|r", accentHex))
    end
    for _, pip in ipairs(g.pips or {}) do
        pip:SetColorTexture(ar, ag, ab, 0.95)
    end
    if g.demoBtn then
        SetPixelBackdrop(g.demoBtn, { ar * 0.42, ag * 0.42, ab * 0.42, 1.00 }, { ar, ag, ab, 0.95 }, 1)
    end

    g:ClearAllPoints()
    if anchorBtn then
        if self._quickGuideOwner and self._quickGuideOwner ~= anchorBtn then
            local prev = self._quickGuideOwner
            prev._guideOpen = false
            SetPixelBackdrop(prev, COLORS.BgElevated, COLORS.BorderSubtle, 1)
            if prev.txt then prev.txt:SetTextColor(0.84, 0.90, 0.96, 1) end
        end
        self._quickGuideOwner = anchorBtn
        anchorBtn._guideOpen = true
        SetPixelBackdrop(anchorBtn, { ar * 0.38, ag * 0.38, ab * 0.38, 1.00 }, { ar, ag, ab, 0.95 }, 1)
        if anchorBtn.txt then anchorBtn.txt:SetTextColor(1, 1, 1, 1) end
        g:SetPoint("TOPRIGHT", anchorBtn, "BOTTOMRIGHT", 0, -6)
    else
        g:SetPoint("CENTER")
    end

    self._quickGuideCatcher:Show()
    g:Show()
end

-- ============================================================================
-- 10. SHARED TALENT WORKSPACE (EMBEDDED TAB 1 + POP-OUT MODAL)
-- ============================================================================
local function CloseAllDynamicTalentPopups()
    DynamicTalent:HideTalentPopover()
    DynamicTalent:HideTalentRowContextMenu()
    DynamicTalent:CloseTalentQuickGuide()
    if talentMgrModal and talentMgrModal.CloseModalDropdown then
        talentMgrModal.CloseModalDropdown()
    end
end

if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.RegisterPopupCloser) == "function" then
    _G.DynamicSuite.UI.RegisterPopupCloser("DynamicTalentPopups", CloseAllDynamicTalentPopups)
end

local function PopulateTalentManagerCore(host, isModal)
    local ar, ag, ab = GetActiveAccentRGB()
    local TAB_BG   = { 0.043, 0.051, 0.071, 1.00 }
    local CARD_BG  = { 0.055, 0.063, 0.082, 1.00 }
    local INPUT_BG = { 0.031, 0.035, 0.047, 1.00 }
    local CARD_BDR = { 1, 1, 1, 0.08 }

    local f = host
    f._isModal = (isModal == true)
    f._rightW = 500
    f._rightInnerW = 476

    f.state = {
        subMode          = "RAID",
        reminderFilter   = "BUILD",
        selectedEntry    = nil,
        selRaidIdx       = 1,
        selBossIdx       = 1,
        selAllRaidBosses = false,
        selBossSet       = {},
        customTargetBoss = nil,
        diffState        = { normal = true, heroic = true, mythic = true },
        selKeyTier       = "ANY",
        selAllDungeons   = false,
        selDungeonSet    = {},
        selPvPSet        = { all = true },
        selAllZones      = false,
        selZoneSet       = { delves = true },
        pickedIdx        = 1,
        ejRaids          = {},
        mplusDungeons    = {},
    }

    local function StyleDropdownTrigger(btn)
        SetPixelBackdrop(btn, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)
        local chev = btn:CreateTexture(nil, "OVERLAY")
        chev:SetSize(12, 12)
        chev:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
        chev:SetTexture(ICON_CHEVRON_DOWN)
        if chev.SetSnapToPixelGrid then chev:SetSnapToPixelGrid(false) end
        if chev.SetTexelSnappingBias then chev:SetTexelSnappingBias(0) end
        do
            local r0, g0, b0 = GetActiveAccentRGB()
            chev:SetVertexColor(r0, g0, b0, 0.90)
        end
        btn.chev = chev
        btn.txt = CreateText(btn, "OVERLAY", "GameFontHighlightSmall")
        btn.txt:SetPoint("LEFT", btn, "LEFT", 8, 0)
        btn.txt:SetPoint("RIGHT", chev, "LEFT", -6, 0)
        btn.txt:SetJustifyH("LEFT")
        btn.txt:SetWordWrap(false)
        btn:SetScript("OnEnter", function(s)
            local r, g, b = GetActiveAccentRGB()
            SetPixelBackdrop(s, { 0.105, 0.122, 0.160, 0.98 }, { r, g, b, 0.92 }, 1)
            if s.chev then s.chev:SetVertexColor(r, g, b, 1.0) end
        end)
        btn:SetScript("OnLeave", function(s)
            if not s._dropOpen then
                local r, g, b = GetActiveAccentRGB()
                SetPixelBackdrop(s, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)
                if s.chev then s.chev:SetVertexColor(r, g, b, 0.90) end
            end
        end)
    end

    -- Top Loadout Bar
    local padX = isModal and 14 or 0
    local topY = isModal and -44 or 0
    do
        local pickBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
        pickBar:SetHeight(36)
        pickBar:SetPoint("TOPLEFT", f, "TOPLEFT", padX, topY)
        pickBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -padX, topY)
        SetPixelBackdrop(pickBar, CARD_BG, CARD_BDR, 1)

        local pickLbl = CreateText(pickBar, "OVERLAY", "GameFontHighlightSmall")
        pickLbl:SetPoint("LEFT", pickBar, "LEFT", 12, 0)
        pickLbl:SetText("|cFF94A3B8Loadout:|r")

        local rightAnchor = pickBar
        local rightPoint = "RIGHT"
        local rightOff = -8

        if not isModal then
            local popBtn = CreateFrame("Button", nil, pickBar, "BackdropTemplate")
            popBtn:SetSize(78, 24)
            popBtn:SetPoint("RIGHT", pickBar, "RIGHT", -8, 0)
            SetPixelBackdrop(popBtn, { ar * 0.36, ag * 0.36, ab * 0.36, 0.96 }, { ar, ag, ab, 0.90 }, 1)
            popBtn.txt = CreateText(popBtn, "OVERLAY", "GameFontHighlightSmall")
            popBtn.txt:SetPoint("CENTER")
            popBtn.txt:SetText("Pop-Out")
            popBtn:SetScript("OnEnter", function(s)
                local r, g, b = GetActiveAccentRGB()
                SetPixelBackdrop(s, { math.min(1, r * 0.52), math.min(1, g * 0.52), math.min(1, b * 0.52), 1 }, { r, g, b, 1 }, 1)
            end)
            popBtn:SetScript("OnLeave", function(s)
                local r, g, b = GetActiveAccentRGB()
                SetPixelBackdrop(s, { r * 0.36, g * 0.36, b * 0.36, 0.96 }, { r, g, b, 0.90 }, 1)
            end)
            popBtn:SetScript("OnClick", function()
                DynamicTalent:OpenTalentManagerModal(1, f:GetSelectedLoadout())
            end)
            f.popOutBtn = popBtn

            local guideBtn = CreateFrame("Button", nil, pickBar, "BackdropTemplate")
            guideBtn:SetSize(24, 24)
            guideBtn:SetPoint("RIGHT", popBtn, "LEFT", -6, 0)
            SetPixelBackdrop(guideBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
            guideBtn.txt = CreateText(guideBtn, "OVERLAY", "GameFontHighlightSmall")
            guideBtn.txt:SetPoint("CENTER")
            guideBtn.txt:SetText("?")
            guideBtn.txt:SetTextColor(0.84, 0.90, 0.96, 1)
            guideBtn:SetScript("OnClick", function(s)
                DynamicTalent:ToggleTalentQuickGuide(s, f)
            end)
            f.guideBtn = guideBtn

            rightAnchor = guideBtn
            rightPoint = "LEFT"
            rightOff = -6
        end

        local newBtn = CreateFrame("Button", nil, pickBar, "BackdropTemplate")
        newBtn:SetSize(78, 24)
        newBtn:SetPoint("RIGHT", rightAnchor, rightPoint, rightOff, 0)
        SetPixelBackdrop(newBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
        newBtn.txt = CreateText(newBtn, "OVERLAY", "GameFontHighlightSmall")
        newBtn.txt:SetPoint("CENTER")
        newBtn.txt:SetText("|cFF10B981+ New|r")
        newBtn:SetScript("OnEnter", function(s)
            local r, g, b = GetActiveAccentRGB()
            SetPixelBackdrop(s, { r * 0.25, g * 0.25, b * 0.25, 0.98 }, { r, g, b, 0.92 }, 1)
        end)
        newBtn:SetScript("OnLeave", function(s)
            SetPixelBackdrop(s, COLORS.BgElevated, COLORS.BorderSubtle, 1)
        end)
        newBtn:SetScript("OnClick", function()
            if f.SelectLoadout then f:SelectLoadout(nil, false) else f:LoadEditorEntry(nil, false) end
            if f.nameEB then
                f.nameEB:SetFocus()
                f.nameEB:HighlightText()
            end
        end)

        local pickBtn = CreateFrame("Button", nil, pickBar, "BackdropTemplate")
        pickBtn:SetHeight(24)
        pickBtn:SetPoint("LEFT", pickLbl, "RIGHT", 8, 0)
        pickBtn:SetPoint("RIGHT", newBtn, "LEFT", -8, 0)
        pickBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        StyleDropdownTrigger(pickBtn)
        pickBtn.bindTag = CreateText(pickBtn, "OVERLAY", "GameFontHighlightSmall")
        pickBtn.bindTag:SetPoint("RIGHT", pickBtn.chev, "LEFT", -6, 0)
        pickBtn.bindTag:SetJustifyH("RIGHT")
        pickBtn.bindTag:SetWordWrap(false)
        pickBtn.bindTag:Hide()
        pickBtn.txt:SetText("|cFF10B981+ New / Import Loadout|r")
        pickBtn:HookScript("OnEnter", function(btnSelf)
            if f.tmDrop and f.tmDrop:IsShown() then return end
            local curSel = f.GetSelectedLoadout and f:GetSelectedLoadout() or nil
            if type(curSel) == "table" and GameTooltip then
                local _, bInfo = DynamicTalent:GetLoadoutBindBadgeText(curSel)
                local heroAcr, heroName = DynamicTalent:GetLoadoutHeroAcronym(curSel)
                GameTooltip:SetOwner(btnSelf, "ANCHOR_RIGHT")
                GameTooltip:AddLine(string.format("%s %s", DynamicTalent:FormatTalentBadge(curSel, heroAcr), tostring(curSel.name or "Loadout")), 1, 1, 1)
                if heroName and heroAcr then
                    GameTooltip:AddLine(string.format("|cFF94A3B8Hero Tree:|r |cFFE2E8F0%s (%s)|r", tostring(heroName), tostring(heroAcr)), 1, 1, 1)
                end
                if bInfo and #bInfo.detailLines > 0 then
                    for _, bl in ipairs(bInfo.detailLines) do
                        GameTooltip:AddLine("|cFFFBBF24Bound:|r |cFFE2E8F0" .. bl .. "|r", 1, 1, 1)
                    end
                else
                    GameTooltip:AddLine("|cFF94A3B8Unbound -- pick a Raid boss, M+ dungeon, PvP mode, or Zone to bind.|r", 1, 1, 1)
                end
                GameTooltip:Show()
            end
        end)
        pickBtn:HookScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
        pickBtn:SetScript("OnClick", function(btnSelf)
            if GameTooltip then GameTooltip:Hide() end
            if not f.ShowModalDropdown then return end
            local curSel = f.GetSelectedLoadout and f:GetSelectedLoadout() or nil
            local items = {
                {
                    label = "|cFF10B981+ New / Import Loadout|r",
                    selected = (curSel == nil),
                    onSelect = function()
                        if f.SelectLoadout then f:SelectLoadout(nil, false) end
                    end,
                },
            }
            local list = DynamicTalent:GetSortedTalentProfiles(nil, false)
            for _, it in ipairs(list) do
                local bTag, bInfo = DynamicTalent:GetLoadoutBindBadgeText(it)
                table.insert(items, {
                    label        = string.format("%s %s", DynamicTalent:FormatTalentBadge(it), tostring(it.name or "Loadout")),
                    bindTag      = bTag,
                    tooltipEntry = it,
                    tooltipBInfo = bInfo,
                    selected     = (curSel == it),
                    onSelect     = function()
                        if f.SelectLoadout then f:SelectLoadout(it, true) end
                    end,
                })
            end
            f.ShowModalDropdown(btnSelf, items, btnSelf:GetWidth())
        end)

        function f:UpdateTopLoadoutTriggerBadge()
            local btn = self.editPickBtn
            if not btn or not btn.txt or not btn.bindTag then return end
            local curSel = self.GetSelectedLoadout and self:GetSelectedLoadout() or nil
            local bTag = (type(curSel) == "table") and DynamicTalent:GetLoadoutBindBadgeText(curSel) or nil
            btn.txt:ClearAllPoints()
            btn.txt:SetPoint("LEFT", btn, "LEFT", 8, 0)
            if bTag and bTag ~= "" then
                btn.bindTag:SetText("|cFFFBBF24" .. tostring(bTag) .. "|r")
                btn.bindTag:Show()
                btn.txt:SetPoint("RIGHT", btn.bindTag, "LEFT", -8, 0)
            else
                btn.bindTag:Hide()
                if btn.chev then
                    btn.txt:SetPoint("RIGHT", btn.chev, "LEFT", -6, 0)
                else
                    btn.txt:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
                end
            end
        end

        f.topLoadoutBar = pickBar
        f.editPickBtn = pickBtn
        f.newBuildBtn = newBtn
    end

    f.activeTab = 1
    f.editingEntry = nil

    -- LEFT COLUMN: BUILD DETAILS
    local p1 = CreateFrame("Frame", nil, f)
    p1:SetPoint("TOPLEFT", f.topLoadoutBar, "BOTTOMLEFT", 0, -8)
    p1:SetWidth(320)
    p1:SetHeight(436)
    f.p1 = p1

    do
        local qsCard = CreateFrame("Frame", nil, p1, "BackdropTemplate")
        qsCard:SetHeight(80)
        qsCard:SetPoint("TOPLEFT", p1, "TOPLEFT", 0, 0)
        qsCard:SetPoint("TOPRIGHT", p1, "TOPRIGHT", 0, 0)
        SetPixelBackdrop(qsCard, CARD_BG, { ar, ag, ab, 0.55 }, 1)

        local accentBar = qsCard:CreateTexture(nil, "ARTWORK")
        accentBar:SetWidth(3)
        accentBar:SetPoint("TOPLEFT", qsCard, "TOPLEFT", 0, 0)
        accentBar:SetPoint("BOTTOMLEFT", qsCard, "BOTTOMLEFT", 0, 0)
        accentBar:SetColorTexture(ar, ag, ab, 0.95)
        qsCard.accentBar = accentBar

        local qsDismissBtn = CreateFrame("Button", nil, qsCard, "BackdropTemplate")
        qsDismissBtn:SetSize(20, 20)
        qsDismissBtn:SetPoint("TOPRIGHT", qsCard, "TOPRIGHT", -6, -6)
        SetPixelBackdrop(qsDismissBtn, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, 0)
        qsDismissBtn.txt = CreateText(qsDismissBtn, "OVERLAY", "GameFontHighlightSmall")
        qsDismissBtn.txt:SetPoint("CENTER")
        qsDismissBtn.txt:SetText("|cFF94A3B8x|r")
        qsDismissBtn:SetScript("OnEnter", function(s)
            SetPixelBackdrop(s, { 0.957, 0.247, 0.369, 0.22 }, { 0.957, 0.247, 0.369, 0.65 }, 1)
            s.txt:SetText("|cFFF43F5Ex|r")
            if GameTooltip then
                GameTooltip:SetOwner(s, "ANCHOR_TOPLEFT")
                GameTooltip:AddLine("Dismiss Quick Start", 1, 1, 1)
                GameTooltip:AddLine("Resettable anytime via Reset Defaults.", 0.88, 0.91, 0.95, true)
                GameTooltip:Show()
            end
        end)
        qsDismissBtn:SetScript("OnLeave", function(s)
            SetPixelBackdrop(s, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, 0)
            s.txt:SetText("|cFF94A3B8x|r")
            if GameTooltip then GameTooltip:Hide() end
        end)
        qsDismissBtn:SetScript("OnClick", function()
            local db = EnsureDB()
            db.dismissedTalentQuickStart = true
            if f.RefreshQuickStartStrip then f:RefreshQuickStartStrip() end
        end)

        local qsHdrFS = CreateText(qsCard, "OVERLAY", "GameFontHighlightSmall")
        qsHdrFS:SetPoint("TOPLEFT", qsCard, "TOPLEFT", 12, -7)
        qsHdrFS:SetPoint("RIGHT", qsDismissBtn, "LEFT", -6, 0)
        qsHdrFS:SetJustifyH("LEFT")
        qsHdrFS:SetWordWrap(false)
        qsHdrFS:SetText("|cFFFFFFFFQUICK START|r")

        local qsSubFS = CreateText(qsCard, "OVERLAY", "GameFontHighlightSmall")
        qsSubFS:SetPoint("TOPLEFT", qsHdrFS, "BOTTOMLEFT", 0, -2)
        qsSubFS:SetPoint("TOPRIGHT", qsHdrFS, "BOTTOMRIGHT", 0, -2)
        qsSubFS:SetJustifyH("LEFT")
        qsSubFS:SetWordWrap(true)
        if qsSubFS.SetMaxLines then qsSubFS:SetMaxLines(2) end
        qsSubFS:SetText("|cFF94A3B8Save your active tree or import Blizzard builds.|r")

        local qsSaveBtn = CreateFrame("Button", nil, qsCard, "BackdropTemplate")
        qsSaveBtn:SetSize(124, 24)
        qsSaveBtn:SetPoint("BOTTOMLEFT", qsCard, "BOTTOMLEFT", 12, 8)
        SetPixelBackdrop(qsSaveBtn, { ar * 0.42, ag * 0.42, ab * 0.42, 1.00 }, { ar, ag, ab, 0.95 }, 1)
        qsSaveBtn.txt = CreateText(qsSaveBtn, "OVERLAY", "GameFontHighlightSmall")
        qsSaveBtn.txt:SetPoint("CENTER")
        qsSaveBtn.txt:SetText("Save Current Tree")
        qsSaveBtn:SetScript("OnEnter", function(s)
            local r, g, b = GetActiveAccentRGB()
            SetPixelBackdrop(s, { math.min(1, r * 0.56), math.min(1, g * 0.56), math.min(1, b * 0.56), 1.00 }, { r, g, b, 1.00 }, 1)
        end)
        qsSaveBtn:SetScript("OnLeave", function(s)
            local r, g, b = GetActiveAccentRGB()
            SetPixelBackdrop(s, { r * 0.42, g * 0.42, b * 0.42, 1.00 }, { r, g, b, 0.95 }, 1)
        end)
        qsSaveBtn:SetScript("OnClick", function()
            local activeStr = DynamicTalent:GetActiveTalentString()
            if not activeStr or activeStr == "" then
                if f.valStatus then
                    f.valStatus:SetText("|cFFFBBF24No active Midnight talent tree found yet -- open Talents once or paste a string below.|r")
                end
                return
            end
            local specID = DynamicTalent:GetActiveSpecID()
            local bName = DynamicTalent:GetSuggestedCurrentBuildName(specID)
            local grp = CategoriseTalentGroup(bName)
            local ok, msg, savedEntry = DynamicTalent:ImportTalentString(bName, activeStr, grp)
            if ok then
                if f.SelectLoadout then f:SelectLoadout(savedEntry, true) else f:LoadEditorEntry(savedEntry, true) end
                if f.valStatus then
                    f.valStatus:SetText("|cFF10B981Saved '" .. tostring((savedEntry and savedEntry.name) or bName) .. "'! Rename anytime or set binds on the right.|r")
                end
            elseif f.valStatus then
                f.valStatus:SetText("|cFFF43F5E" .. tostring(msg) .. "|r")
            end
        end)

        local qsImportBtn = CreateFrame("Button", nil, qsCard, "BackdropTemplate")
        qsImportBtn:SetSize(164, 24)
        qsImportBtn:SetPoint("BOTTOMRIGHT", qsCard, "BOTTOMRIGHT", -12, 8)
        SetPixelBackdrop(qsImportBtn, { 0.063 * 0.30, 0.725 * 0.30, 0.506 * 0.30, 1.00 }, { 0.063, 0.725, 0.506, 0.85 }, 1)
        qsImportBtn.txt = CreateText(qsImportBtn, "OVERLAY", "GameFontHighlightSmall")
        qsImportBtn.txt:SetPoint("CENTER")
        qsImportBtn.txt:SetText("|cFF34D399Import Blizzard Loadouts|r")
        qsImportBtn:SetScript("OnEnter", function(s)
            SetPixelBackdrop(s, { 0.063 * 0.46, 0.725 * 0.46, 0.506 * 0.46, 1.00 }, { 0.20, 0.85, 0.62, 1.00 }, 1)
            if GameTooltip then
                GameTooltip:SetOwner(s, "ANCHOR_TOP")
                GameTooltip:AddLine("Import Blizzard Loadouts", 1, 1, 1)
                GameTooltip:AddLine("Imports saved Blizzard talent loadouts for your active specialisation.", 0.88, 0.91, 0.95, true)
                GameTooltip:Show()
            end
        end)
        qsImportBtn:SetScript("OnLeave", function(s)
            SetPixelBackdrop(s, { 0.063 * 0.30, 0.725 * 0.30, 0.506 * 0.30, 1.00 }, { 0.063, 0.725, 0.506, 0.85 }, 1)
            if GameTooltip then GameTooltip:Hide() end
        end)
        qsImportBtn:SetScript("OnClick", function()
            local specID = DynamicTalent:GetActiveSpecID()
            local imported, skipped, firstImported = DynamicTalent:ImportBlizzardLoadouts(specID)
            if imported > 0 then
                if f.SelectLoadout and firstImported then
                    f:SelectLoadout(firstImported, true)
                elseif f.RefreshQuickStartStrip then
                    f:RefreshQuickStartStrip()
                end
                if f.valStatus then
                    f.valStatus:SetText(string.format("|cFF10B981Imported %d Blizzard loadout(s) with Hero Talent badges!|r", imported))
                end
            elseif f.valStatus then
                if skipped > 0 then
                    f.valStatus:SetText("|cFF94A3B8All Blizzard loadouts are already saved -- pick one above or paste a string.|r")
                else
                    f.valStatus:SetText("|cFFFBBF24No saved Blizzard loadouts found for this spec -- use Save Current Tree or paste a string.|r")
                end
            end
        end)

        qsCard:Hide()
        f.quickStartCard = qsCard
        f.qsSaveBtn = qsSaveBtn
        f.qsImportBtn = qsImportBtn
    end

    local c1 = CreateFrame("Frame", nil, p1, "BackdropTemplate")
    c1:SetHeight(104)
    c1:SetPoint("TOPLEFT", p1, "TOPLEFT", 0, 0)
    c1:SetPoint("TOPRIGHT", p1, "TOPRIGHT", 0, 0)
    SetPixelBackdrop(c1, CARD_BG, CARD_BDR, 1)
    f.c1 = c1

    local c1Hdr = CreateModalSectionHeader(c1, "|cFFFFFFFFLOADOUT IDENTITY|r", "Name your build & pick a category", -6)

    local nameEB = CreateFrame("EditBox", nil, c1, "BackdropTemplate")
    nameEB:SetHeight(24)
    nameEB:SetPoint("TOPLEFT", c1, "TOPLEFT", 12, -43)
    nameEB:SetPoint("TOPRIGHT", c1, "TOPRIGHT", -12, -43)
    nameEB:SetAutoFocus(false)
    nameEB:SetFontObject("GameFontHighlightSmall")
    nameEB:SetTextInsets(8, 8, 0, 0)
    SetPixelBackdrop(nameEB, INPUT_BG, COLORS.BorderSubtle, 1)
    nameEB:SetText("New Raid Build")
    f.nameEB = nameEB

    local selGroup = "Raid"
    local grpBtns = {}
    local function StyleGrpBtns()
        local r, g, b = GetActiveAccentRGB()
        for _, gb in ipairs(grpBtns) do
            local on = (gb.grp == selGroup)
            SetPixelBackdrop(gb, on and { r * 0.40, g * 0.40, b * 0.40, 1.00 } or COLORS.BgElevated, on and { r, g, b, 0.95 } or COLORS.BorderSubtle, 1)
            gb.txt:SetTextColor(on and 1 or 0.72, on and 1 or 0.78, on and 1 or 0.86, 1)
        end
    end
    for gi, gName in ipairs(TALENT_GROUP_ORDER) do
        local gb = CreateFrame("Button", nil, c1, "BackdropTemplate")
        gb:SetSize(56, 24)
        gb:SetPoint("TOPLEFT", c1, "TOPLEFT", 12 + ((gi - 1) * 59), -73)
        gb.grp = gName
        gb.txt = CreateText(gb, "OVERLAY", "GameFontHighlightSmall")
        gb.txt:SetPoint("CENTER")
        gb.txt:SetText(gName)
        gb:SetScript("OnClick", function(s) selGroup = s.grp; StyleGrpBtns() end)
        table.insert(grpBtns, gb)
    end
    f.grpBtns = grpBtns
    StyleGrpBtns()

    local c2 = CreateFrame("Frame", nil, p1, "BackdropTemplate")
    c2:SetHeight(166)
    c2:SetPoint("TOPLEFT", c1, "BOTTOMLEFT", 0, -8)
    c2:SetPoint("TOPRIGHT", c1, "BOTTOMRIGHT", 0, -8)
    SetPixelBackdrop(c2, CARD_BG, CARD_BDR, 1)

    local c2Hdr = CreateModalSectionHeader(c2, "|cFFFFFFFFTALENT EXPORT STRING|r", "Paste a string or capture your active tree", -6)

    local strEB = CreateFrame("EditBox", nil, c2, "BackdropTemplate")
    strEB:SetHeight(26)
    strEB:SetPoint("TOPLEFT", c2, "TOPLEFT", 12, -43)
    strEB:SetPoint("TOPRIGHT", c2, "TOPRIGHT", -12, -43)
    strEB:SetAutoFocus(false)
    strEB:SetFontObject("GameFontHighlightSmall")
    strEB:SetTextInsets(8, 8, 0, 0)
    SetPixelBackdrop(strEB, INPUT_BG, COLORS.BorderSubtle, 1)
    f.strEB = strEB

    local valStatus = CreateText(c2, "OVERLAY", "GameFontHighlightSmall")
    valStatus:SetHeight(26)
    valStatus:SetPoint("TOPLEFT", strEB, "BOTTOMLEFT", 2, -4)
    valStatus:SetPoint("TOPRIGHT", strEB, "BOTTOMRIGHT", -2, -4)
    valStatus:SetJustifyH("LEFT")
    valStatus:SetJustifyV("TOP")
    valStatus:SetWordWrap(true)
    valStatus:SetText("|cFF64748BPaste an export string or click Use Current Tree.|r")
    f.valStatus = valStatus

    local function ValidateStringBox()
        local txt = SafeTrim(strEB:GetText() or "")
        if txt == "" then
            valStatus:SetText("|cFF64748BPaste an export string or click Use Current Tree.|r")
            return
        end
        local dec, err = DynamicTalent:DecodeTalentImportString(txt)
        if dec then
            valStatus:SetText(string.format("|cFF10B981Valid Midnight Talent String (%d nodes ready).|r", #dec.entries))
        else
            valStatus:SetText("|cFFF43F5EInvalid string: " .. tostring(err or "check format") .. "|r")
        end
    end
    strEB:SetScript("OnTextChanged", ValidateStringBox)

    local useCurBtn = CreateFrame("Button", nil, c2, "BackdropTemplate")
    useCurBtn:SetSize(152, 24)
    useCurBtn:SetPoint("BOTTOMLEFT", c2, "BOTTOMLEFT", 12, 38)
    SetPixelBackdrop(useCurBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
    useCurBtn.txt = CreateText(useCurBtn, "OVERLAY", "GameFontHighlightSmall")
    useCurBtn.txt:SetPoint("CENTER")
    useCurBtn.txt:SetText("Use Current Tree")
    useCurBtn:SetScript("OnClick", function()
        strEB:SetText(DynamicTalent:GetActiveTalentString() or "")
        ValidateStringBox()
    end)
    f.useCurBtn = useCurBtn

    local clearStrBtn = CreateFrame("Button", nil, c2, "BackdropTemplate")
    clearStrBtn:SetSize(54, 24)
    clearStrBtn:SetPoint("LEFT", useCurBtn, "RIGHT", 4, 0)
    SetPixelBackdrop(clearStrBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
    clearStrBtn.txt = CreateText(clearStrBtn, "OVERLAY", "GameFontHighlightSmall")
    clearStrBtn.txt:SetPoint("CENTER")
    clearStrBtn.txt:SetText("Clear")
    clearStrBtn:SetScript("OnClick", function()
        strEB:SetText("")
        strEB:SetFocus()
        ValidateStringBox()
    end)
    f.clearStrBtn = clearStrBtn

    local copyStrBtn = CreateFrame("Button", nil, c2, "BackdropTemplate")
    copyStrBtn:SetSize(82, 24)
    copyStrBtn:SetPoint("LEFT", clearStrBtn, "RIGHT", 4, 0)
    SetPixelBackdrop(copyStrBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
    copyStrBtn.txt = CreateText(copyStrBtn, "OVERLAY", "GameFontHighlightSmall")
    copyStrBtn.txt:SetPoint("CENTER")
    copyStrBtn.txt:SetText("Copy String")
    copyStrBtn:SetScript("OnClick", function()
        local txt = SafeTrim(strEB:GetText() or "")
        if txt == "" then
            txt = DynamicTalent:GetActiveTalentString() or ""
            strEB:SetText(txt)
        end
        strEB:SetFocus()
        strEB:HighlightText()
        valStatus:SetText("|cFF34D399Talent string selected -- press Ctrl+C to copy!|r")
    end)
    f.copyStrBtn = copyStrBtn

    local saveImpBtn = CreateFrame("Button", nil, c2, "BackdropTemplate")
    saveImpBtn:SetSize(164, 26)
    saveImpBtn:SetPoint("BOTTOMRIGHT", c2, "BOTTOMRIGHT", -12, 10)
    SetPixelBackdrop(saveImpBtn, { ar * 0.42, ag * 0.42, ab * 0.42, 1.00 }, { ar, ag, ab, 0.95 }, 1)
    saveImpBtn.txt = CreateText(saveImpBtn, "OVERLAY", "GameFontHighlightSmall")
    saveImpBtn.txt:SetPoint("CENTER")
    saveImpBtn.txt:SetText("Save Loadout")
    f.saveImpBtn = saveImpBtn

    local cancelEditBtn = CreateFrame("Button", nil, c2, "BackdropTemplate")
    cancelEditBtn:SetSize(98, 26)
    cancelEditBtn:SetPoint("BOTTOMLEFT", c2, "BOTTOMLEFT", 12, 10)
    SetPixelBackdrop(cancelEditBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
    cancelEditBtn.txt = CreateText(cancelEditBtn, "OVERLAY", "GameFontHighlightSmall")
    cancelEditBtn.txt:SetPoint("CENTER")
    cancelEditBtn.txt:SetText("Revert")
    cancelEditBtn:Hide()
    f.cancelEditBtn = cancelEditBtn

    do
        local saveAndNewBtn = CreateFrame("Button", nil, c2, "BackdropTemplate")
        saveAndNewBtn:SetSize(126, 26)
        saveAndNewBtn:SetPoint("BOTTOMLEFT", c2, "BOTTOMLEFT", 12, 10)
        SetPixelBackdrop(saveAndNewBtn, { 0.063 * 0.30, 0.725 * 0.30, 0.506 * 0.30, 1.00 }, { 0.063, 0.725, 0.506, 0.85 }, 1)
        saveAndNewBtn.txt = CreateText(saveAndNewBtn, "OVERLAY", "GameFontHighlightSmall")
        saveAndNewBtn.txt:SetPoint("CENTER")
        saveAndNewBtn.txt:SetText("|cFF34D399Save & New|r")
        saveAndNewBtn:SetScript("OnEnter", function(s)
            SetPixelBackdrop(s, { 0.063 * 0.46, 0.725 * 0.46, 0.506 * 0.46, 1.00 }, { 0.20, 0.85, 0.62, 1.00 }, 1)
        end)
        saveAndNewBtn:SetScript("OnLeave", function(s)
            SetPixelBackdrop(s, { 0.063 * 0.30, 0.725 * 0.30, 0.506 * 0.30, 1.00 }, { 0.063, 0.725, 0.506, 0.85 }, 1)
        end)
        f.saveAndNewBtn = saveAndNewBtn
    end

    function f:GetSelectedLoadout()
        local cand = self.state and self.state.selectedEntry
        if type(cand) ~= "table" then return nil end
        local specID = DynamicTalent:GetActiveSpecID()
        local lib = (specID and DynamicTalent.db and DynamicTalent.db.talentStringLibrary and DynamicTalent.db.talentStringLibrary[specID]) or {}
        for _, it in ipairs(lib) do
            if it == cand then return cand end
        end
        return nil
    end

    function f:LoadEditorEntry(entry, keepFocusQuiet)
        local r, g, b = GetActiveAccentRGB()
        SetPixelBackdrop(saveImpBtn, { r * 0.42, g * 0.42, b * 0.42, 1.00 }, { r, g, b, 0.95 }, 1)
        c1Hdr.bar:SetColorTexture(r, g, b, 0.95)
        c1Hdr.line:SetColorTexture(r, g, b, 0.35)
        c2Hdr.bar:SetColorTexture(r, g, b, 0.95)
        c2Hdr.line:SetColorTexture(r, g, b, 0.35)
        self.editingEntry = entry
        self.state.selectedEntry = entry
        if type(entry) == "table" then
            c1Hdr.titleFS:SetText("|cFFFBBF24EDITING:|r |cFFFFFFFF" .. tostring(entry.name or "Loadout") .. "|r")
            c1Hdr.subFS:SetText("|cFF94A3B8Loadout Identity: rename or update build|r")
            if self.editPickBtn and self.editPickBtn.txt then
                self.editPickBtn.txt:SetText(string.format("%s |cFFFFFFFF%s|r", DynamicTalent:FormatTalentBadge(entry), tostring(entry.name or "Loadout")))
            end
            nameEB:SetText(tostring(entry.name or "Loadout"))
            selGroup = NormalizeTalentGroupKey(entry.group or "Custom")
            StyleGrpBtns()
            strEB:SetText(tostring(entry.importString or ""))
            saveImpBtn.txt:SetText("Save Changes")
            cancelEditBtn.txt:SetText("Revert")
            cancelEditBtn:Show()
            if self.saveAndNewBtn then self.saveAndNewBtn:Hide() end
            if self:IsShown() and not keepFocusQuiet then
                nameEB:SetFocus()
                nameEB:HighlightText()
            end
        else
            c1Hdr.titleFS:SetText("|cFFFFFFFFNEW / IMPORT LOADOUT|r")
            c1Hdr.subFS:SetText("|cFF94A3B8Loadout Identity: name & pick category|r")
            if self.editPickBtn and self.editPickBtn.txt then
                self.editPickBtn.txt:SetText("|cFF10B981+ New / Import Loadout|r")
            end
            local specID = DynamicTalent:GetActiveSpecID()
            local lib = (specID and DynamicTalent.db and DynamicTalent.db.talentStringLibrary and DynamicTalent.db.talentStringLibrary[specID]) or {}
            nameEB:SetText("Loadout " .. tostring(#lib + 1))
            selGroup = "Raid"
            StyleGrpBtns()
            strEB:SetText(DynamicTalent:GetActiveTalentString() or "")
            saveImpBtn.txt:SetText("Save Loadout")
            cancelEditBtn:Hide()
            if self.saveAndNewBtn then self.saveAndNewBtn:Show() end
            if self:IsShown() and not keepFocusQuiet then
                nameEB:SetFocus()
                nameEB:HighlightText()
            end
        end
        if self.UpdateTopLoadoutTriggerBadge then self:UpdateTopLoadoutTriggerBadge() end
        if self.RefreshQuickStartStrip then self:RefreshQuickStartStrip() end
        if self.UpdateResponsiveLayout then self:UpdateResponsiveLayout() end
        ValidateStringBox()
    end

    function f:RefreshQuickStartStrip()
        if not self.quickStartCard or not self.c1 then return end
        local specID = DynamicTalent:GetActiveSpecID()
        local lib = (specID and DynamicTalent.db and DynamicTalent.db.talentStringLibrary and DynamicTalent.db.talentStringLibrary[specID]) or {}
        local dismissed = (DynamicTalent.db and DynamicTalent.db.dismissedTalentQuickStart == true)
        local showStrip = (#lib == 0) and (not dismissed)
        local r, g, b = GetActiveAccentRGB()
        self.c1:ClearAllPoints()
        if showStrip then
            SetPixelBackdrop(self.quickStartCard, CARD_BG, { r, g, b, 0.55 }, 1)
            if self.quickStartCard.accentBar then self.quickStartCard.accentBar:SetColorTexture(r, g, b, 0.95) end
            if self.qsSaveBtn then SetPixelBackdrop(self.qsSaveBtn, { r * 0.42, g * 0.42, b * 0.42, 1.00 }, { r, g, b, 0.95 }, 1) end
            self.quickStartCard:Show()
            self.c1:SetPoint("TOPLEFT", self.quickStartCard, "BOTTOMLEFT", 0, -8)
            self.c1:SetPoint("TOPRIGHT", self.quickStartCard, "BOTTOMRIGHT", 0, -8)
        else
            self.quickStartCard:Hide()
            self.c1:SetPoint("TOPLEFT", self.p1, "TOPLEFT", 0, 0)
            self.c1:SetPoint("TOPRIGHT", self.p1, "TOPRIGHT", 0, 0)
        end
    end

    local function CommitLoadoutEditor(saveAndNew)
        local curSel = f:GetSelectedLoadout()
        if curSel then
            local ok, msg = DynamicTalent:UpdateTalentLibraryEntry(curSel, nameEB:GetText(), selGroup, strEB:GetText())
            if ok then
                if f.SelectLoadout then f:SelectLoadout(curSel, true) else f:LoadEditorEntry(curSel, true) end
                valStatus:SetText("|cFF10B981" .. tostring(msg) .. "|r")
            else
                valStatus:SetText("|cFFF43F5E" .. tostring(msg) .. "|r")
            end
        else
            local ok, msg, savedEntry = DynamicTalent:ImportTalentString(nameEB:GetText(), strEB:GetText(), selGroup)
            if ok then
                if saveAndNew then
                    local savedName = tostring((savedEntry and savedEntry.name) or nameEB:GetText() or "Loadout")
                    if f.SelectLoadout then f:SelectLoadout(nil, false) else f:LoadEditorEntry(nil, false) end
                    strEB:SetText("")
                    valStatus:SetText("|cFF10B981Saved '" .. savedName .. "' -- paste or capture your next build.|r")
                    if nameEB then
                        nameEB:SetFocus()
                        nameEB:HighlightText()
                    end
                else
                    if f.SelectLoadout then f:SelectLoadout(savedEntry, true) else f:LoadEditorEntry(savedEntry, true) end
                    valStatus:SetText("|cFF10B981" .. tostring(msg) .. "|r")
                end
            else
                valStatus:SetText("|cFFF43F5E" .. tostring(msg) .. "|r")
            end
        end
    end

    local function CancelOrBlurEditor(box)
        if box and box.ClearFocus then box:ClearFocus() end
        local curSel = f:GetSelectedLoadout()
        if curSel then
            f:LoadEditorEntry(curSel, true)
            valStatus:SetText("|cFF94A3B8Reverted unsaved changes.|r")
        end
    end

    nameEB:SetScript("OnEnterPressed", function(s) s:ClearFocus(); CommitLoadoutEditor(false) end)
    nameEB:SetScript("OnEscapePressed", CancelOrBlurEditor)
    strEB:SetScript("OnEnterPressed", function(s) s:ClearFocus(); CommitLoadoutEditor(false) end)
    strEB:SetScript("OnEscapePressed", CancelOrBlurEditor)
    cancelEditBtn:SetScript("OnClick", function()
        local curSel = f:GetSelectedLoadout()
        if curSel then
            f:LoadEditorEntry(curSel, true)
            valStatus:SetText("|cFF94A3B8Reverted unsaved changes.|r")
        end
    end)
    saveImpBtn:SetScript("OnClick", function() CommitLoadoutEditor(false) end)
    if f.saveAndNewBtn then
        f.saveAndNewBtn:SetScript("OnClick", function() CommitLoadoutEditor(true) end)
    end

    local renameBtn = CreateFrame("Button", nil, p1, "BackdropTemplate")
    renameBtn:SetHeight(26)
    renameBtn:SetPoint("TOPLEFT", c2, "BOTTOMLEFT", 0, -8)
    renameBtn:SetPoint("TOPRIGHT", c2, "BOTTOMRIGHT", 0, -8)
    SetPixelBackdrop(renameBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
    renameBtn.txt = CreateText(renameBtn, "OVERLAY", "GameFontHighlightSmall")
    renameBtn.txt:SetPoint("LEFT", renameBtn, "LEFT", 8, 0)
    renameBtn.txt:SetPoint("RIGHT", renameBtn, "RIGHT", -8, 0)
    renameBtn.txt:SetJustifyH("CENTER")
    renameBtn.txt:SetWordWrap(false)
    renameBtn.txt:SetText('Rename "TalentLoadoutManager" -> DynamicTalent')
    renameBtn:SetScript("OnClick", function()
        if not DynamicTalent:RenameLegacyTLMSlot() then
            valStatus:SetText("|cFF94A3B8No legacy 'TalentLoadoutManager' Blizzard slot found for this spec.|r")
            renameBtn:Hide()
        else
            valStatus:SetText("|cFF10B981Renamed Blizzard slot to 'DynamicTalent' cleanly.|r")
            renameBtn:Hide()
        end
    end)
    f.renameLegacyBtn = renameBtn

    -- RIGHT COLUMN: 4-TAB TALENT BINDS & ACTIVE REMINDERS
    local p2 = CreateFrame("Frame", nil, f)
    p2:SetPoint("TOPLEFT", p1, "TOPRIGHT", 10, 0)
    p2:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -padX, isModal and 18 or 0)
    f.p2 = p2

    local subBar = CreateFrame("Frame", nil, p2, "BackdropTemplate")
    subBar:SetHeight(30)
    subBar:SetPoint("TOPLEFT", p2, "TOPLEFT", 0, 0)
    subBar:SetPoint("TOPRIGHT", p2, "TOPRIGHT", 0, 0)
    SetPixelBackdrop(subBar, TAB_BG, CARD_BDR, 1)
    f.subBar = subBar

    local function MkSubTabBtn(lbl, anchorTo)
        local b = CreateFrame("Button", nil, subBar, "BackdropTemplate")
        b:SetSize(118, 22)
        if anchorTo then
            b:SetPoint("LEFT", anchorTo, "RIGHT", 4, 0)
        else
            b:SetPoint("LEFT", subBar, "LEFT", 4, 0)
        end
        b.txt = CreateText(b, "OVERLAY", "GameFontHighlightSmall")
        b.txt:SetPoint("CENTER")
        b.txt:SetWordWrap(false)
        b.txt:SetText(lbl)
        return b
    end

    local modeRaidBtn  = MkSubTabBtn("Raid Bosses", nil)
    local modeMPlusBtn = MkSubTabBtn("M+ Dungeons", modeRaidBtn)
    local modePvPBtn   = MkSubTabBtn("PvP", modeMPlusBtn)
    local modeZoneBtn  = MkSubTabBtn("Zone Defaults", modePvPBtn)

    local bCard = CreateFrame("Frame", nil, p2, "BackdropTemplate")
    bCard:SetHeight(234)
    bCard:SetPoint("TOPLEFT", subBar, "BOTTOMLEFT", 0, -8)
    bCard:SetPoint("TOPRIGHT", subBar, "BOTTOMRIGHT", 0, -8)
    SetPixelBackdrop(bCard, CARD_BG, CARD_BDR, 1)
    f.bCard = bCard

    local bHdr = CreateModalSectionHeader(bCard, "|cFFFFFFFFRAID BOSS TALENT BINDS|r", "Pick a Season 2 raid, boss (or All Raids) and difficulties", -10)
    f.bHdr = bHdr

    local testToastBtn = CreateFrame("Button", nil, bCard, "BackdropTemplate")
    testToastBtn:SetSize(116, 20)
    testToastBtn:SetPoint("TOPRIGHT", bCard, "TOPRIGHT", -12, -14)
    SetPixelBackdrop(testToastBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
    testToastBtn.txt = CreateText(testToastBtn, "OVERLAY", "GameFontHighlightSmall")
    testToastBtn.txt:SetPoint("CENTER")
    testToastBtn.txt:SetText("Test Alert Toast")
    testToastBtn:SetScript("OnClick", function()
        local sample = f:GetSelectedLoadout() or { name = "Raid ST", group = "Raid" }
        DynamicTalent:ShowTalentReminderToast(sample, sample.name, "Preview Reminder", true)
    end)

    if bHdr.textArea then
        bHdr.textArea:ClearAllPoints()
        bHdr.textArea:SetPoint("TOPLEFT", bHdr, "TOPLEFT", 11, -2)
        bHdr.textArea:SetPoint("BOTTOMLEFT", bHdr, "BOTTOMLEFT", 11, 2)
        bHdr.textArea:SetPoint("RIGHT", testToastBtn, "LEFT", -10, 0)
    end

    -- 1) RAID MODE CONTROLS
    local raidGrp = CreateFrame("Frame", nil, bCard)
    raidGrp:SetPoint("TOPLEFT", bCard, "TOPLEFT", 12, -50)
    raidGrp:SetPoint("BOTTOMRIGHT", bCard, "BOTTOMRIGHT", -12, 8)
    raidGrp.raidPillBtns = {}
    raidGrp.bossGridBtns = {}
    f.raidGrp = raidGrp

    local tgtBtn = CreateFrame("Button", nil, raidGrp, "BackdropTemplate")
    tgtBtn:SetSize(76, 24)
    tgtBtn:SetPoint("TOPRIGHT", raidGrp, "TOPRIGHT", 0, 0)
    SetPixelBackdrop(tgtBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
    tgtBtn.txt = CreateText(tgtBtn, "OVERLAY", "GameFontHighlightSmall")
    tgtBtn.txt:SetPoint("CENTER")
    tgtBtn.txt:SetText("Target")
    tgtBtn:SetScript("OnEnter", function(s)
        local r, g, b = GetActiveAccentRGB()
        SetPixelBackdrop(s, { r * 0.24, g * 0.24, b * 0.24, 0.98 }, { r, g, b, 0.92 }, 1)
        if GameTooltip then
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:AddLine("Match Current Target", 1, 1, 1)
            GameTooltip:AddLine("|cFFE2E8F0Reads your current target (or Action Target) safely, matches Season 2 raids (including council bosses), or sets a dismissible custom target.|r", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    tgtBtn:SetScript("OnLeave", function(s)
        SetPixelBackdrop(s, COLORS.BgElevated, COLORS.BorderSubtle, 1)
        if GameTooltip then GameTooltip:Hide() end
    end)

    local allRaidBtn = CreateFrame("Button", nil, raidGrp, "BackdropTemplate")
    allRaidBtn:SetSize(74, 24)
    allRaidBtn:SetPoint("TOPLEFT", raidGrp, "TOPLEFT", 0, 0)
    allRaidBtn.txt = CreateText(allRaidBtn, "OVERLAY", "GameFontHighlightSmall")
    allRaidBtn.txt:SetPoint("CENTER")
    allRaidBtn.txt:SetWidth(68)
    allRaidBtn.txt:SetJustifyH("CENTER")
    allRaidBtn.txt:SetText("All Raids")
    raidGrp.allRaidBtn = allRaidBtn

    local allRaidBanner = CreateFrame("Frame", nil, raidGrp, "BackdropTemplate")
    allRaidBanner:SetPoint("TOPLEFT", raidGrp, "TOPLEFT", 0, -30)
    allRaidBanner:SetPoint("TOPRIGHT", raidGrp, "TOPRIGHT", 0, -30)
    allRaidBanner:SetHeight(56)
    SetPixelBackdrop(allRaidBanner, { 0.08, 0.11, 0.16, 0.92 }, { 0.24, 0.30, 0.40, 0.85 }, 1)
    allRaidBanner.txt = CreateText(allRaidBanner, "OVERLAY", "GameFontHighlightSmall")
    allRaidBanner.txt:SetPoint("LEFT", allRaidBanner, "LEFT", 12, 0)
    allRaidBanner.txt:SetPoint("RIGHT", allRaidBanner, "RIGHT", -12, 0)
    allRaidBanner.txt:SetJustifyH("LEFT")
    allRaidBanner.txt:SetWordWrap(true)
    allRaidBanner.txt:SetTextColor(0.84, 0.88, 0.94)
    allRaidBanner.txt:SetText("Raid-wide fallback across all Season 2 raids for the selected difficulties. Specific boss binds always take priority over All Raids.")
    allRaidBanner:Hide()
    raidGrp.allRaidBanner = allRaidBanner

    local customChip = CreateFrame("Frame", nil, raidGrp, "BackdropTemplate")
    customChip:SetHeight(20)
    customChip:SetPoint("TOPLEFT", raidGrp, "TOPLEFT", 0, -90)
    customChip:SetPoint("TOPRIGHT", raidGrp, "TOPRIGHT", 0, -90)
    SetPixelBackdrop(customChip, { 0.16, 0.12, 0.04, 0.92 }, { 0.984, 0.749, 0.141, 0.78 }, 1)
    customChip.txt = CreateText(customChip, "OVERLAY", "GameFontHighlightSmall")
    customChip.txt:SetPoint("LEFT", customChip, "LEFT", 8, 0)
    customChip.txt:SetPoint("RIGHT", customChip, "RIGHT", -28, 0)
    customChip.txt:SetJustifyH("LEFT")
    customChip.txt:SetWordWrap(false)
    customChip.clearBtn = CreateFrame("Button", nil, customChip)
    customChip.clearBtn:SetSize(22, 20)
    customChip.clearBtn:SetPoint("RIGHT", customChip, "RIGHT", -2, 0)
    customChip.clearBtn.txt = CreateText(customChip.clearBtn, "OVERLAY", "GameFontHighlightSmall")
    customChip.clearBtn.txt:SetPoint("CENTER")
    customChip.clearBtn.txt:SetText("|cFFF43F5Ex|r")
    customChip:Hide()
    raidGrp.customChip = customChip

    local diffDefs = {
        { key = "normal", label = "LFR / Normal", w = 88, x = 0,   r = 0.063, g = 0.725, b = 0.506 },
        { key = "heroic", label = "Heroic",       w = 64, x = 92,  r = 0.220, g = 0.741, b = 0.973 },
        { key = "mythic", label = "Mythic",       w = 64, x = 160, r = 0.957, g = 0.247, b = 0.369 },
    }
    local diffBtns = {}
    local function StyleDiffBtns()
        local ds = f.state.diffState
        for _, db in ipairs(diffBtns) do
            local on = (ds[db.dKey] == true)
            SetPixelBackdrop(db, on and { db.dr * 0.35, db.dg * 0.35, db.db * 0.35, 1.00 } or COLORS.BgElevated, on and { db.dr, db.dg, db.db, 0.95 } or COLORS.BorderSubtle, 1)
            db.txt:SetTextColor(on and 1 or 0.55, on and 1 or 0.62, on and 1 or 0.70, 1)
        end
    end
    for _, dd in ipairs(diffDefs) do
        local db = CreateFrame("Button", nil, raidGrp, "BackdropTemplate")
        db:SetSize(dd.w, 26)
        db:SetPoint("TOPLEFT", raidGrp, "TOPLEFT", dd.x, -114)
        db.dKey = dd.key; db.dLabel = dd.label; db.dr = dd.r; db.dg = dd.g; db.db = dd.b
        db.txt = CreateText(db, "OVERLAY", "GameFontHighlightSmall")
        db.txt:SetPoint("CENTER")
        db.txt:SetText(dd.label)
        db:SetScript("OnClick", function(s)
            local ds = f.state.diffState
            local nextVal = not ds[s.dKey]
            if not nextVal then
                local others = 0
                for k, v in pairs(ds) do if k ~= s.dKey and v then others = others + 1 end end
                if others == 0 then return end
            end
            ds[s.dKey] = nextVal
            StyleDiffBtns()
        end)
        table.insert(diffBtns, db)
    end
    raidGrp.diffBtns = diffBtns
    StyleDiffBtns()

    local raidClearBtn = CreateFrame("Button", nil, raidGrp, "BackdropTemplate")
    raidClearBtn:SetSize(70, 26)
    raidClearBtn:SetPoint("TOPRIGHT", raidGrp, "TOPRIGHT", 0, -114)
    SetPixelBackdrop(raidClearBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
    raidClearBtn.txt = CreateText(raidClearBtn, "OVERLAY", "GameFontHighlightSmall")
    raidClearBtn.txt:SetPoint("CENTER")
    raidClearBtn.txt:SetText("Clear")
    raidClearBtn:SetScript("OnEnter", function(s)
        SetPixelBackdrop(s, { 0.28, 0.08, 0.12, 0.98 }, { 0.957, 0.247, 0.369, 0.95 }, 1)
        if GameTooltip then
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:AddLine("Clear Raid Binds", 1, 1, 1)
            GameTooltip:AddLine("|cFFE2E8F0Removes active All Raids or selected boss binds for the toggled difficulties.|r", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    raidClearBtn:SetScript("OnLeave", function(s)
        SetPixelBackdrop(s, COLORS.BgElevated, COLORS.BorderSubtle, 1)
        if GameTooltip then GameTooltip:Hide() end
    end)
    raidClearBtn:SetScript("OnClick", function()
        local st = f.state
        if not st then return end
        local ds = {
            normal = st.diffState.normal and true or false,
            heroic = st.diffState.heroic and true or false,
            mythic = st.diffState.mythic and true or false,
        }
        if not (ds.normal or ds.heroic or ds.mythic) then
            ds.normal, ds.heroic, ds.mythic = true, true, true
        end
        if st.selAllRaidBosses then
            local removed = DynamicTalent:ClearRaidBinds(true, nil, ds)
            if removed > 0 then
                Print("Cleared |cFFFBBF24All Raids|r binds for the selected difficulties.")
            else
                Print("No |cFFFBBF24All Raids|r binds found for the selected difficulties.")
            end
        else
            local rObj = st.ejRaids and st.ejRaids[st.selRaidIdx]
            local bosses = (rObj and rObj.bosses) or {}
            local bossNames = {}
            if st.customTargetBoss and st.customTargetBoss ~= "" then
                table.insert(bossNames, st.customTargetBoss)
            else
                for bIdx = 1, #bosses do
                    if st.selBossSet[bIdx] and bosses[bIdx] then
                        table.insert(bossNames, bosses[bIdx].name)
                    end
                end
            end
            if #bossNames == 0 then
                Print("Select All Raids or at least one boss to clear.")
                return
            end
            local removed = DynamicTalent:ClearRaidBinds(false, bossNames, ds)
            if removed > 0 then
                wipe(st.selBossSet)
                st.selBossIdx = nil
                st.customTargetBoss = nil
                f:RefreshRaidGrid()
                Print(string.format("Cleared raid binds for %d selected boss(es).", #bossNames))
            else
                Print("No raid binds found for the selected boss(es) and difficulties.")
            end
        end
    end)
    raidGrp.raidClearBtn = raidClearBtn

    local raidBindBtn = CreateFrame("Button", nil, raidGrp, "BackdropTemplate")
    raidBindBtn:SetSize(116, 26)
    raidBindBtn:SetPoint("RIGHT", raidClearBtn, "LEFT", -6, 0)
    SetPixelBackdrop(raidBindBtn, { ar * 0.42, ag * 0.42, ab * 0.42, 1.00 }, { ar, ag, ab, 0.95 }, 1)
    raidBindBtn.txt = CreateText(raidBindBtn, "OVERLAY", "GameFontHighlightSmall")
    raidBindBtn.txt:SetPoint("CENTER")
    raidBindBtn.txt:SetText("+ Bind Raid")
    raidGrp.raidBindBtn = raidBindBtn

    local raidTip = CreateText(raidGrp, "OVERLAY", "GameFontHighlightSmall")
    raidTip:SetPoint("TOPLEFT", raidGrp, "TOPLEFT", 2, -146)
    raidTip:SetPoint("TOPRIGHT", raidGrp, "TOPRIGHT", -2, -146)
    raidTip:SetHeight(28)
    raidTip:SetJustifyH("LEFT")
    raidTip:SetWordWrap(true)
    raidTip:SetText("|cFF64748BSelect All Raids or toggle bosses, choose difficulties, then click + Bind Raid (or Clear). Specific boss binds override All Raids.|r")
    raidGrp.raidTip = raidTip

    -- 2) M+ MODE CONTROLS
    local mplusGrp = CreateFrame("Frame", nil, bCard)
    mplusGrp:SetPoint("TOPLEFT", bCard, "TOPLEFT", 12, -50)
    mplusGrp:SetPoint("BOTTOMRIGHT", bCard, "BOTTOMRIGHT", -12, 8)
    mplusGrp:Hide()
    f.mplusGrp = mplusGrp

    local tierDefs = {
        { key = "ANY",  label = "Any Key", w = 82, x = 0   },
        { key = "LOW",  label = "+2 - 9",  w = 74, x = 88  },
        { key = "HIGH", label = "+10+",    w = 70, x = 168 },
    }
    local tierBtns = {}
    local function StyleTierBtns()
        local r, g, b = GetActiveAccentRGB()
        for _, tb in ipairs(tierBtns) do
            local on = (f.state.selKeyTier == tb.tKey)
            SetPixelBackdrop(tb, on and { r * 0.40, g * 0.40, b * 0.40, 1.00 } or COLORS.BgElevated, on and { r, g, b, 0.95 } or COLORS.BorderSubtle, 1)
            tb.txt:SetTextColor(on and 1 or 0.72, on and 1 or 0.78, on and 1 or 0.86, 1)
        end
    end
    for _, td in ipairs(tierDefs) do
        local tb = CreateFrame("Button", nil, mplusGrp, "BackdropTemplate")
        tb:SetSize(td.w, 26)
        tb:SetPoint("TOPLEFT", mplusGrp, "TOPLEFT", td.x, -34)
        tb.tKey = td.key
        tb.txt = CreateText(tb, "OVERLAY", "GameFontHighlightSmall")
        tb.txt:SetPoint("CENTER")
        tb.txt:SetText(td.label)
        tb:SetScript("OnClick", function(s) f.state.selKeyTier = s.tKey; StyleTierBtns() end)
        table.insert(tierBtns, tb)
    end
    mplusGrp.tierBtns = tierBtns
    StyleTierBtns()

    local mplusBindBtn = CreateFrame("Button", nil, mplusGrp, "BackdropTemplate")
    mplusBindBtn:SetSize(124, 26)
    mplusBindBtn:SetPoint("TOPRIGHT", mplusGrp, "TOPRIGHT", 0, -34)
    SetPixelBackdrop(mplusBindBtn, { ar * 0.42, ag * 0.42, ab * 0.42, 1.00 }, { ar, ag, ab, 0.95 }, 1)
    mplusBindBtn.txt = CreateText(mplusBindBtn, "OVERLAY", "GameFontHighlightSmall")
    mplusBindBtn.txt:SetPoint("CENTER")
    mplusBindBtn.txt:SetText("+ Bind M+")
    mplusGrp.mplusBindBtn = mplusBindBtn

    local mplusTip = CreateText(mplusGrp, "OVERLAY", "GameFontHighlightSmall")
    mplusTip:SetPoint("TOPLEFT", mplusGrp, "TOPLEFT", 2, -66)
    mplusTip:SetPoint("TOPRIGHT", mplusGrp, "TOPRIGHT", -2, -66)
    mplusTip:SetHeight(28)
    mplusTip:SetJustifyH("LEFT")
    mplusTip:SetWordWrap(true)
    mplusTip:SetText("|cFF64748BSelect one or more dungeons (or All) & key tier, then click + Bind M+. Specific dungeons override All M+.|r")
    mplusGrp.mplusTip = mplusTip

    -- 3) PVP MODE CONTROLS (4th Binder Tab)
    local pvpGrp = CreateFrame("Frame", nil, bCard)
    pvpGrp:SetPoint("TOPLEFT", bCard, "TOPLEFT", 12, -50)
    pvpGrp:SetPoint("BOTTOMRIGHT", bCard, "BOTTOMRIGHT", -12, 8)
    pvpGrp.pvpBtns = {}
    pvpGrp:Hide()
    f.pvpGrp = pvpGrp

    local pvpDefs = {
        { key = "all",     label = "All PvP",       desc = "Fallback across all PvP modes (specific PvP mode binds take priority)." },
        { key = "arena",   label = "Arena",         desc = "Arenas, Solo Shuffle, and Skirmishes." },
        { key = "bg",      label = "Battlegrounds", desc = "Random and Rated Battlegrounds, Blitz, and Epic Battlegrounds." },
        { key = "warmode", label = "War Mode",      desc = "Outdoor PvP when War Mode is active or desired (skips resting cities)." },
    }
    for pi, pd in ipairs(pvpDefs) do
        local pb = CreateFrame("Button", nil, pvpGrp, "BackdropTemplate")
        pb:SetSize(112, 28)
        pb:SetPoint("TOPLEFT", pvpGrp, "TOPLEFT", (pi - 1) * 116, 0)
        pb.pKey = pd.key
        pb.pLabel = pd.label
        pb.pDesc = pd.desc
        pb.txt = CreateText(pb, "OVERLAY", "GameFontHighlightSmall")
        pb.txt:SetPoint("CENTER")
        pb.txt:SetText(pd.label)
        table.insert(pvpGrp.pvpBtns, pb)
    end

    local pvpClearBtn = CreateFrame("Button", nil, pvpGrp, "BackdropTemplate")
    pvpClearBtn:SetSize(76, 26)
    pvpClearBtn:SetPoint("TOPRIGHT", pvpGrp, "TOPRIGHT", 0, -34)
    SetPixelBackdrop(pvpClearBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
    pvpClearBtn.txt = CreateText(pvpClearBtn, "OVERLAY", "GameFontHighlightSmall")
    pvpClearBtn.txt:SetPoint("CENTER")
    pvpClearBtn.txt:SetText("Clear")
    pvpClearBtn:SetScript("OnEnter", function(s) SetPixelBackdrop(s, { 0.28, 0.08, 0.12, 0.98 }, { 0.957, 0.247, 0.369, 0.95 }, 1) end)
    pvpClearBtn:SetScript("OnLeave", function(s) SetPixelBackdrop(s, COLORS.BgElevated, COLORS.BorderSubtle, 1) end)

    local pvpBindBtn = CreateFrame("Button", nil, pvpGrp, "BackdropTemplate")
    pvpBindBtn:SetSize(122, 26)
    pvpBindBtn:SetPoint("RIGHT", pvpClearBtn, "LEFT", -6, 0)
    SetPixelBackdrop(pvpBindBtn, { ar * 0.42, ag * 0.42, ab * 0.42, 1.00 }, { ar, ag, ab, 0.95 }, 1)
    pvpBindBtn.txt = CreateText(pvpBindBtn, "OVERLAY", "GameFontHighlightSmall")
    pvpBindBtn.txt:SetPoint("CENTER")
    pvpBindBtn.txt:SetText("+ Bind PvP")

    local pvpBindNote = CreateText(pvpGrp, "OVERLAY", "GameFontHighlightSmall")
    pvpBindNote:SetHeight(24)
    pvpBindNote:SetPoint("LEFT", pvpGrp, "TOPLEFT", 2, -47)
    pvpBindNote:SetPoint("RIGHT", pvpBindBtn, "LEFT", -8, 0)
    pvpBindNote:SetJustifyH("LEFT")
    pvpBindNote:SetWordWrap(true)
    pvpBindNote:SetText("|cFF94A3B8Applies to top-bar loadout (auto-saves new builds).|r")

    local pvpTip = CreateText(pvpGrp, "OVERLAY", "GameFontHighlightSmall")
    pvpTip:SetPoint("TOPLEFT", pvpGrp, "TOPLEFT", 2, -66)
    pvpTip:SetPoint("TOPRIGHT", pvpGrp, "TOPRIGHT", -2, -66)
    pvpTip:SetHeight(28)
    pvpTip:SetJustifyH("LEFT")
    pvpTip:SetWordWrap(true)
    pvpTip:SetText("|cFF64748BSpecific PvP modes (Arena, Battlegrounds, War Mode) override All PvP. War Mode skips resting cities.|r")
    pvpGrp.pvpTip = pvpTip

    -- 4) ZONE DEFAULTS MODE CONTROLS
    local zoneGrp = CreateFrame("Frame", nil, bCard)
    zoneGrp:SetPoint("TOPLEFT", bCard, "TOPLEFT", 12, -50)
    zoneGrp:SetPoint("BOTTOMRIGHT", bCard, "BOTTOMRIGHT", -12, 8)
    zoneGrp.zoneBtns = {}
    zoneGrp:Hide()
    f.zoneGrp = zoneGrp

    zoneGrp.allZoneBtn = CreateFrame("Button", nil, zoneGrp, "BackdropTemplate")
    zoneGrp.allZoneBtn:SetSize(50, 28)
    zoneGrp.allZoneBtn:SetPoint("TOPLEFT", zoneGrp, "TOPLEFT", 0, 0)
    zoneGrp.allZoneBtn.txt = CreateText(zoneGrp.allZoneBtn, "OVERLAY", "GameFontHighlightSmall")
    zoneGrp.allZoneBtn.txt:SetPoint("CENTER")
    zoneGrp.allZoneBtn.txt:SetText("All")

    local zoneDefs = {
        { key = "outdoor",  label = "Outdoor",  desc = "Open world zones & questing (skips resting cities)" },
        { key = "delves",   label = "Delves",   desc = "Solo or group Delves" },
        { key = "dungeons", label = "Dungeons", desc = "Maps directly to All M+ Dungeons (Any Key)" },
        { key = "raid",     label = "Raid",     desc = "Maps directly to All Raids (LFR / Normal, Heroic, Mythic)" },
        { key = "pvp",      label = "PvP",      desc = "Maps directly to All PvP (Arena, Battlegrounds & War Mode)" },
    }
    for zi, zd in ipairs(zoneDefs) do
        local zb = CreateFrame("Button", nil, zoneGrp, "BackdropTemplate")
        zb:SetSize(97, 28)
        zb:SetPoint("TOPLEFT", zoneGrp, "TOPLEFT", 67 + ((zi - 1) * 101), 0)
        zb.zKey = zd.key
        zb.zLabel = zd.label
        zb.zDesc = zd.desc
        zb.txt = CreateText(zb, "OVERLAY", "GameFontHighlightSmall")
        zb.txt:SetPoint("CENTER")
        zb.txt:SetText(zd.label)
        table.insert(zoneGrp.zoneBtns, zb)
    end

    local zoneClearBtn = CreateFrame("Button", nil, zoneGrp, "BackdropTemplate")
    zoneClearBtn:SetSize(76, 26)
    zoneClearBtn:SetPoint("TOPRIGHT", zoneGrp, "TOPRIGHT", 0, -34)
    SetPixelBackdrop(zoneClearBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
    zoneClearBtn.txt = CreateText(zoneClearBtn, "OVERLAY", "GameFontHighlightSmall")
    zoneClearBtn.txt:SetPoint("CENTER")
    zoneClearBtn.txt:SetText("Clear")
    zoneClearBtn:SetScript("OnEnter", function(s) SetPixelBackdrop(s, { 0.28, 0.08, 0.12, 0.98 }, { 0.957, 0.247, 0.369, 0.95 }, 1) end)
    zoneClearBtn:SetScript("OnLeave", function(s) SetPixelBackdrop(s, COLORS.BgElevated, COLORS.BorderSubtle, 1) end)

    local zoneBindBtn = CreateFrame("Button", nil, zoneGrp, "BackdropTemplate")
    zoneBindBtn:SetSize(122, 26)
    zoneBindBtn:SetPoint("RIGHT", zoneClearBtn, "LEFT", -6, 0)
    SetPixelBackdrop(zoneBindBtn, { ar * 0.42, ag * 0.42, ab * 0.42, 1.00 }, { ar, ag, ab, 0.95 }, 1)
    zoneBindBtn.txt = CreateText(zoneBindBtn, "OVERLAY", "GameFontHighlightSmall")
    zoneBindBtn.txt:SetPoint("CENTER")
    zoneBindBtn.txt:SetText("+ Bind Zones")

    local zoneBindNote = CreateText(zoneGrp, "OVERLAY", "GameFontHighlightSmall")
    zoneBindNote:SetHeight(24)
    zoneBindNote:SetPoint("LEFT", zoneGrp, "TOPLEFT", 2, -47)
    zoneBindNote:SetPoint("RIGHT", zoneBindBtn, "LEFT", -8, 0)
    zoneBindNote:SetJustifyH("LEFT")
    zoneBindNote:SetWordWrap(true)
    zoneBindNote:SetText("|cFF94A3B8Applies to top-bar loadout (auto-saves new builds).|r")

    local zoneTip = CreateText(zoneGrp, "OVERLAY", "GameFontHighlightSmall")
    zoneTip:SetPoint("TOPLEFT", zoneGrp, "TOPLEFT", 2, -66)
    zoneTip:SetPoint("TOPRIGHT", zoneGrp, "TOPRIGHT", -2, -66)
    zoneTip:SetHeight(28)
    zoneTip:SetJustifyH("LEFT")
    zoneTip:SetWordWrap(true)
    zoneTip:SetText("|cFF64748BAll saves a single [All Content] rule. Specific Raid bosses, M+ dungeons & PvP modes override defaults.|r")
    zoneGrp.zoneTip = zoneTip

    -- Unified Selected-Loadout & Picker Helpers
    function f:UpdatePickBtns()
        local st = self.state
        if #st.ejRaids == 0 then st.ejRaids = GetCurrentTierRaids() end
        if #st.mplusDungeons == 0 then st.mplusDungeons = GetCurrentSeasonMythicPlusDungeons() end
        return self:GetSelectedLoadout()
    end

    function f:SelectLoadout(entry, keepFocusQuiet)
        local st = self.state
        wipe(st.selBossSet)
        st.selAllRaidBosses = false
        st.customTargetBoss = nil
        st.selBossIdx = nil
        wipe(st.selDungeonSet)
        st.selAllDungeons = false
        self:LoadEditorEntry(entry, keepFocusQuiet)
        local validEntry = self:GetSelectedLoadout()
        if type(validEntry) == "table" then
            local list = DynamicTalent:GetSortedTalentProfiles(nil, false)
            for idx, it in ipairs(list) do
                if it == validEntry then
                    st.pickedIdx = idx
                    break
                end
            end
            if st.subMode == "RAID" and #st.ejRaids > 0 then
                local bInfo = DynamicTalent:GetLoadoutBindings(validEntry)
                local curRaid = st.ejRaids[st.selRaidIdx]
                local curHas = curRaid and (bInfo.raidsWithBinds[curRaid.name:lower()] or (curRaid.short and bInfo.raidsWithBinds[curRaid.short:lower()]))
                if not curHas then
                    for rIdx, rObj in ipairs(st.ejRaids) do
                        if bInfo.raidsWithBinds[rObj.name:lower()] or (rObj.short and bInfo.raidsWithBinds[rObj.short:lower()]) then
                            st.selRaidIdx = rIdx
                            break
                        end
                    end
                end
            end
        end
        if self.RefreshTab2View then self:RefreshTab2View() end
    end

    function f:SelectBuildForTab2(entry, keepMode)
        if type(entry) ~= "table" then return end
        local st = self.state
        if keepMode == false then
            local grp = NormalizeTalentGroupKey(entry.group or "Custom")
            if grp == "M+" then
                st.subMode = "MPLUS"
            elseif grp == "Raid" then
                st.subMode = "RAID"
            elseif grp == "PvP" then
                st.subMode = "PVP"
            elseif grp == "Delves" then
                st.subMode = "ZONE"
            end
        end
        self:SelectLoadout(entry, true)
        if keepMode == false and self.SelectSubMode then
            self:SelectSubMode(st.subMode)
        end
    end

    function f:SelectBossPickEntry(entry)
        self:SelectBuildForTab2(entry, false)
    end

    -- Dropdown Popover (4px 3-way scrollbar)
    local tmDropCatcher = _G.DynamicTalentModalDropCatcher or CreateFrame("Button", "DynamicTalentModalDropCatcher", UIParent)
    tmDropCatcher:SetAllPoints(UIParent)
    tmDropCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
    tmDropCatcher:SetFrameLevel(40)
    tmDropCatcher:EnableMouse(true)
    tmDropCatcher:RegisterForClicks("AnyDown")
    tmDropCatcher:Hide()

    local tmDrop = _G.DynamicTalentModalDrop
    if not tmDrop then
        tmDrop = CreateFrame("Frame", "DynamicTalentModalDrop", UIParent, "BackdropTemplate")
        tmDrop:SetFrameStrata("TOOLTIP")
        tmDrop:SetFrameLevel(60)
        tmDrop:SetClampedToScreen(true)
        tmDrop:EnableMouse(true)
        tmDrop:Hide()
        tmDrop.borderOverlay = CreateFrame("Frame", nil, tmDrop, "BackdropTemplate")
        tmDrop.borderOverlay:SetAllPoints(tmDrop)
        tmDrop.borderOverlay:SetFrameLevel(70)
        tmDrop.scroll = CreateFrame("ScrollFrame", nil, tmDrop)
        tmDrop.scroll:SetPoint("TOPLEFT", tmDrop, "TOPLEFT", 4, -4)
        tmDrop.scroll:SetPoint("BOTTOMRIGHT", tmDrop, "BOTTOMRIGHT", -4, 4)
        tmDrop.scroll:EnableMouseWheel(true)
        tmDrop.content = CreateFrame("Frame", nil, tmDrop.scroll)
        tmDrop.scroll:SetScrollChild(tmDrop.content)
        tmDrop.rows = {}

        tmDrop.track = CreateFrame("Frame", nil, tmDrop, "BackdropTemplate")
        tmDrop.track:SetWidth(4)
        tmDrop.track:SetPoint("TOPRIGHT", tmDrop, "TOPRIGHT", -4, -4)
        tmDrop.track:SetPoint("BOTTOMRIGHT", tmDrop, "BOTTOMRIGHT", -4, 4)
        tmDrop.track:SetFrameLevel(65)
        tmDrop.track:EnableMouse(true)
        tmDrop.track:EnableMouseWheel(true)
        tmDrop.track:SetHitRectInsets(-5, -4, 0, 0)
        SetPixelBackdrop(tmDrop.track, { 0.043, 0.051, 0.071, 0.90 }, { 0, 0, 0, 0 }, 0)
        tmDrop.track:Hide()

        tmDrop.thumb = CreateFrame("Button", nil, tmDrop.track)
        tmDrop.thumb:SetWidth(4)
        tmDrop.thumb:SetHeight(32)
        tmDrop.thumb:SetPoint("TOP", tmDrop.track, "TOP", 0, 0)
        tmDrop.thumb:SetFrameLevel(66)
        tmDrop.thumb:EnableMouse(true)
        tmDrop.thumb:SetHitRectInsets(-5, -4, 0, 0)
        tmDrop.thumb.tex = tmDrop.thumb:CreateTexture(nil, "OVERLAY")
        tmDrop.thumb.tex:SetAllPoints()
        tmDrop.thumb.tex:SetColorTexture(ar, ag, ab, 0.78)
        tmDrop.thumb:Hide()

        tmDrop.UpdateScrollBar = function()
            local r, g, b = GetActiveAccentRGB()
            if tmDrop.thumb.isDragging then
                tmDrop.thumb.tex:SetColorTexture(r, g, b, 1.0)
            elseif tmDrop.thumb.isHovered then
                tmDrop.thumb.tex:SetColorTexture(r, g, b, 0.92)
            else
                tmDrop.thumb.tex:SetColorTexture(r, g, b, 0.78)
            end
            local visH = tmDrop._visH or tmDrop.scroll:GetHeight() or 0
            local totalH = tmDrop.content:GetHeight() or 0
            local dropW = tmDrop._dropWidth or tmDrop:GetWidth() or 220
            local maxS = math.max(0, totalH - visH)
            tmDrop.scroll:ClearAllPoints()
            tmDrop.scroll:SetPoint("TOPLEFT", tmDrop, "TOPLEFT", 4, -4)
            if maxS <= 1 or visH <= 1 then
                tmDrop.scroll:SetPoint("BOTTOMRIGHT", tmDrop, "BOTTOMRIGHT", -4, 4)
                tmDrop.content:SetWidth(math.max(40, dropW - 8))
                tmDrop.track:Hide()
                tmDrop.thumb:Hide()
                tmDrop.scroll:SetVerticalScroll(0)
                return
            end
            tmDrop.scroll:SetPoint("BOTTOMRIGHT", tmDrop, "BOTTOMRIGHT", -12, 4)
            tmDrop.content:SetWidth(math.max(40, dropW - 16))
            tmDrop.track:Show()
            tmDrop.thumb:Show()
            local trackH = tmDrop.track:GetHeight()
            if not trackH or trackH <= 1 then trackH = visH end
            local cur = math.max(0, math.min(maxS, tmDrop.scroll:GetVerticalScroll() or 0))
            local thumbH = math.max(22, math.floor(trackH * math.min(1, visH / totalH) + 0.5))
            local travel = math.max(1, trackH - thumbH)
            tmDrop.thumb:SetHeight(thumbH)
            tmDrop.thumb:ClearAllPoints()
            tmDrop.thumb:SetPoint("TOP", tmDrop.track, "TOP", 0, -math.floor((cur / maxS) * travel + 0.5))
        end

        tmDrop.ScrollFromCursor = function()
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                tmDrop.thumb.isDragging = false
                tmDrop.thumb:SetScript("OnUpdate", nil)
                tmDrop.track:SetScript("OnUpdate", nil)
                tmDrop.UpdateScrollBar()
                return
            end
            local visH = tmDrop._visH or tmDrop.scroll:GetHeight() or 0
            local totalH = tmDrop.content:GetHeight() or 0
            local maxS = math.max(0, totalH - visH)
            local trackH = tmDrop.track:GetHeight()
            if not trackH or trackH <= 1 then trackH = visH end
            if maxS <= 1 or trackH <= 1 then return end
            local tTop = tmDrop.track:GetTop()
            local eff = tmDrop.track:GetEffectiveScale() or 1
            if not tTop or eff <= 0 or not GetCursorPosition then return end
            local _, cy = GetCursorPosition()
            local relY = math.max(0, math.min(trackH, tTop - (cy / eff)))
            local thumbH = tmDrop.thumb:GetHeight() or 22
            local travel = math.max(1, trackH - thumbH)
            local ratio = math.max(0, math.min(1, (relY - (thumbH * 0.5)) / travel))
            tmDrop.scroll:SetVerticalScroll(ratio * maxS)
            tmDrop.UpdateScrollBar()
        end

        tmDrop.thumb:SetScript("OnEnter", function(s) s.isHovered = true; tmDrop.UpdateScrollBar() end)
        tmDrop.thumb:SetScript("OnLeave", function(s) s.isHovered = false; tmDrop.UpdateScrollBar() end)
        tmDrop.thumb:SetScript("OnMouseDown", function(s, btn)
            if btn ~= "LeftButton" then return end
            s.isDragging = true
            s:SetScript("OnUpdate", tmDrop.ScrollFromCursor)
            tmDrop.ScrollFromCursor()
        end)
        tmDrop.thumb:SetScript("OnMouseUp", function(s)
            s.isDragging = false
            s:SetScript("OnUpdate", nil)
            tmDrop.UpdateScrollBar()
        end)
        tmDrop.track:SetScript("OnMouseDown", function(s, btn)
            if btn ~= "LeftButton" then return end
            tmDrop.thumb.isDragging = true
            s:SetScript("OnUpdate", tmDrop.ScrollFromCursor)
            tmDrop.ScrollFromCursor()
        end)
        tmDrop.track:SetScript("OnMouseUp", function(s)
            tmDrop.thumb.isDragging = false
            s:SetScript("OnUpdate", nil)
            tmDrop.UpdateScrollBar()
        end)

        local function HandleDropMouseWheel(delta)
            local visH = tmDrop._visH or tmDrop.scroll:GetHeight() or 0
            local maxS = math.max(0, (tmDrop.content:GetHeight() or 0) - visH)
            if maxS <= 1 then
                tmDrop.scroll:SetVerticalScroll(0)
            else
                tmDrop.scroll:SetVerticalScroll(math.max(0, math.min(maxS, (tmDrop.scroll:GetVerticalScroll() or 0) - (delta * 26))))
            end
            tmDrop.UpdateScrollBar()
        end
        tmDrop.scroll:SetScript("OnMouseWheel", function(_, delta) HandleDropMouseWheel(delta) end)
        tmDrop.track:SetScript("OnMouseWheel", function(_, delta) HandleDropMouseWheel(delta) end)
        if _G.UISpecialFrames then
            table.insert(_G.UISpecialFrames, "DynamicTalentModalDrop")
        end
    end

    local function CloseModalDropdown()
        if tmDrop._owner then
            local prev = tmDrop._owner
            prev._dropOpen = false
            SetPixelBackdrop(prev, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)
            if prev.chev then
                prev.chev:SetTexture(ICON_CHEVRON_DOWN)
                local r0, g0, b0 = GetActiveAccentRGB()
                prev.chev:SetVertexColor(r0, g0, b0, 0.90)
            end
            tmDrop._owner = nil
        end
        tmDrop.thumb.isDragging = false
        tmDrop.thumb.isHovered = false
        tmDrop.thumb:SetScript("OnUpdate", nil)
        tmDrop.track:SetScript("OnUpdate", nil)
        if GameTooltip then GameTooltip:Hide() end
        tmDrop:Hide()
        tmDropCatcher:Hide()
    end
    f.CloseModalDropdown = CloseModalDropdown
    tmDropCatcher:SetScript("OnClick", CloseModalDropdown)
    tmDrop:SetScript("OnHide", CloseModalDropdown)
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.RegisterPopupCloser) == "function" then
        _G.DynamicSuite.UI.RegisterPopupCloser("DynamicTalentModalDrop", CloseModalDropdown)
    end

    local function ShowModalDropdown(anchorBtn, items, width)
        if tmDrop:IsShown() and tmDrop._owner == anchorBtn then
            CloseModalDropdown()
            return
        end
        CloseModalDropdown()
        if DynamicTalent.CloseTalentQuickGuide then DynamicTalent:CloseTalentQuickGuide() end
        if not anchorBtn._dtHideHooked then
            anchorBtn._dtHideHooked = true
            anchorBtn:HookScript("OnHide", function()
                if tmDrop._owner == anchorBtn then CloseModalDropdown() end
            end)
        end
        local r, g, b = GetActiveAccentRGB()
        SetPixelBackdrop(tmDrop, { 0.043, 0.051, 0.071, 0.99 }, { r, g, b, 0.95 }, 1)
        SetPixelBackdrop(tmDrop.borderOverlay, { 0, 0, 0, 0 }, { r, g, b, 0.95 }, 1)
        tmDrop._owner = anchorBtn
        anchorBtn._dropOpen = true
        SetPixelBackdrop(anchorBtn, { 0.105, 0.122, 0.160, 0.98 }, { r, g, b, 0.95 }, 1)
        if anchorBtn.chev then
            anchorBtn.chev:SetTexture(ICON_CHEVRON_UP)
            anchorBtn.chev:SetVertexColor(r, g, b, 1.0)
        end

        for _, rw in ipairs(tmDrop.rows) do rw:Hide() end
        local w = math.max(width or 240, anchorBtn:GetWidth() or 220)
        tmDrop._dropWidth = w
        tmDrop:SetWidth(w)
        local y = 0
        for idx, it in ipairs(items) do
            local rw = tmDrop.rows[idx]
            if not rw then
                rw = CreateFrame("Button", nil, tmDrop.content, "BackdropTemplate")
                rw:SetHeight(24)
                rw.pip = rw:CreateTexture(nil, "OVERLAY")
                rw.pip:SetSize(5, 5)
                rw.pip:SetPoint("LEFT", rw, "LEFT", 7, 0)
                rw.bindTag = CreateText(rw, "OVERLAY", "GameFontHighlightSmall")
                rw.bindTag:SetPoint("RIGHT", rw, "RIGHT", -8, 0)
                rw.bindTag:SetJustifyH("RIGHT")
                rw.bindTag:SetWordWrap(false)
                rw.bindTag:Hide()
                rw.txt = CreateText(rw, "OVERLAY", "GameFontHighlightSmall")
                rw.txt:SetPoint("LEFT", rw, "LEFT", 18, 0)
                rw.txt:SetPoint("RIGHT", rw, "RIGHT", -8, 0)
                rw.txt:SetJustifyH("LEFT")
                rw.txt:SetWordWrap(false)
                tmDrop.rows[idx] = rw
            end
            rw:ClearAllPoints()
            rw:SetPoint("TOPLEFT", tmDrop.content, "TOPLEFT", 0, y)
            rw:SetPoint("TOPRIGHT", tmDrop.content, "TOPRIGHT", 0, y)
            rw.txt:ClearAllPoints()
            rw.txt:SetPoint("LEFT", rw, "LEFT", 18, 0)
            if it.bindTag and it.bindTag ~= "" then
                rw.bindTag:SetText("|cFFFBBF24" .. tostring(it.bindTag) .. "|r")
                rw.bindTag:Show()
                rw.txt:SetPoint("RIGHT", rw.bindTag, "LEFT", -8, 0)
            else
                rw.bindTag:Hide()
                rw.txt:SetPoint("RIGHT", rw, "RIGHT", -8, 0)
            end
            rw.txt:SetText(it.label or "")
            rw.pip:SetColorTexture(r, g, b, 1.0)
            rw.pip:SetShown(it.selected == true)
            local idleBg = it.selected and { r * 0.42, g * 0.42, b * 0.42, 0.98 } or { 0.055, 0.063, 0.082, 0.90 }
            local idleBdr = it.selected and { r, g, b, 0.95 } or { 0, 0, 0, 0 }
            SetPixelBackdrop(rw, idleBg, idleBdr, 1)
            rw:SetScript("OnEnter", function(s)
                SetPixelBackdrop(s, { r * 0.30, g * 0.30, b * 0.30, 0.98 }, { r, g, b, 0.85 }, 1)
                if GameTooltip and it.tooltipEntry then
                    local e = it.tooltipEntry
                    local bInfo = it.tooltipBInfo
                    local heroAcr, heroName = DynamicTalent:GetLoadoutHeroAcronym(e)
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(string.format("%s %s", DynamicTalent:FormatTalentBadge(e, heroAcr), tostring(e.name or "Loadout")), 1, 1, 1)
                    if heroName and heroAcr then
                        GameTooltip:AddLine(string.format("|cFF94A3B8Hero Tree:|r |cFFE2E8F0%s (%s)|r", tostring(heroName), tostring(heroAcr)), 1, 1, 1)
                    end
                    if bInfo and #bInfo.detailLines > 0 then
                        for _, bl in ipairs(bInfo.detailLines) do
                            GameTooltip:AddLine("|cFFFBBF24Bound:|r |cFFE2E8F0" .. bl .. "|r", 1, 1, 1)
                        end
                    else
                        GameTooltip:AddLine("|cFF94A3B8Unbound -- click to edit or assign binds.|r", 1, 1, 1)
                    end
                    GameTooltip:Show()
                end
            end)
            rw:SetScript("OnLeave", function(s)
                SetPixelBackdrop(s, idleBg, idleBdr, 1)
                if GameTooltip then GameTooltip:Hide() end
            end)
            rw:SetScript("OnClick", function()
                CloseModalDropdown()
                if it.onSelect then it.onSelect() end
            end)
            rw:Show()
            y = y - 26
        end
        local totalH = math.max(26, math.abs(y))
        local visH = math.min(totalH, 234)
        tmDrop._visH = visH
        tmDrop.content:SetHeight(totalH)
        tmDrop.scroll:SetVerticalScroll(0)
        tmDrop:SetHeight(visH + 8)
        tmDrop:ClearAllPoints()
        local btnBot = (anchorBtn.GetBottom and anchorBtn:GetBottom()) or 300
        if btnBot < (visH + 24) then
            tmDrop:SetPoint("BOTTOMLEFT", anchorBtn, "TOPLEFT", 0, 2)
        else
            tmDrop:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -2)
        end
        tmDropCatcher:Show()
        tmDrop:Show()
        tmDrop.UpdateScrollBar()
    end
    f.ShowModalDropdown = ShowModalDropdown
    f.CloseModalDropdown = CloseModalDropdown
    f:HookScript("OnHide", CloseModalDropdown)

    function f:StyleBoundTile(btn, isSel, isBound, r, g, b)
        if not btn.boundPip then
            local pip = btn:CreateTexture(nil, "OVERLAY")
            pip:SetSize(5, 5)
            pip:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -3, -3)
            pip:SetColorTexture(0.063, 0.725, 0.506, 1.0)
            btn.boundPip = pip
        end
        btn.boundPip:SetShown(isBound == true)
        if isSel then
            SetPixelBackdrop(btn, { r * 0.42, g * 0.42, b * 0.42, 0.98 }, { r, g, b, 0.98 }, 1)
        elseif isBound then
            SetPixelBackdrop(btn, { 0.035, 0.145, 0.105, 0.96 }, { 0.063, 0.725, 0.506, 0.85 }, 1)
        else
            SetPixelBackdrop(btn, INPUT_BG, COLORS.BorderSubtle, 1)
        end
    end

    function f:RefreshRaidGrid()
        local st = self.state
        local r, g, b = GetActiveAccentRGB()
        if #st.ejRaids == 0 then st.ejRaids = GetCurrentTierRaids() end
        local raids = st.ejRaids
        local curBuild = self:GetSelectedLoadout()
        local bInfo = DynamicTalent:GetLoadoutBindings(curBuild)
        for _, rp in ipairs(raidGrp.raidPillBtns) do rp:Hide() end
        for _, bp in ipairs(raidGrp.bossGridBtns) do bp:Hide() end

        local rawW = raidGrp:GetWidth()
        local innerW = math.max(380, math.floor(((rawW and rawW > 100) and rawW or self._rightInnerW or 498) + 0.5))
        local allRaidW = 74
        local raidBarStart = allRaidW + 4
        local raidBarW = innerW - raidBarStart - 80
        local numRaids = math.max(1, #raids)
        local rPillW = math.floor((raidBarW - ((numRaids - 1) * 4)) / numRaids)
        if st.selRaidIdx > #raids then st.selRaidIdx = 1 end
        if st.selRaidIdx < 1 then st.selRaidIdx = 1 end

        for rIdx, rObj in ipairs(raids) do
            local rp = raidGrp.raidPillBtns[rIdx]
            if not rp then
                rp = CreateFrame("Button", nil, raidGrp, "BackdropTemplate")
                rp:SetHeight(24)
                rp.txt = CreateText(rp, "OVERLAY", "GameFontHighlightSmall")
                rp.txt:SetPoint("LEFT", rp, "LEFT", 6, 0)
                rp.txt:SetPoint("RIGHT", rp, "RIGHT", -6, 0)
                rp.txt:SetJustifyH("CENTER")
                rp.txt:SetWordWrap(false)
                raidGrp.raidPillBtns[rIdx] = rp
            end
            local isOn = (not st.selAllRaidBosses) and (rIdx == st.selRaidIdx)
            local hasBound = (bInfo.raidsWithBinds[tostring(rObj.name):lower()] == true)
                or (rObj.short and bInfo.raidsWithBinds[tostring(rObj.short):lower()] == true)
            rp:SetWidth(rPillW)
            rp:ClearAllPoints()
            rp:SetPoint("TOPLEFT", raidGrp, "TOPLEFT", raidBarStart + ((rIdx - 1) * (rPillW + 4)), 0)
            rp.txt:SetText(tostring(rObj.short or rObj.name))
            rp.txt:SetTextColor((isOn or hasBound) and 1 or 0.78, (isOn or hasBound) and 1 or 0.84, (isOn or hasBound) and 1 or 0.92, 1)
            self:StyleBoundTile(rp, isOn, hasBound, r, g, b)
            rp:SetScript("OnClick", function()
                st.selRaidIdx = rIdx
                st.selAllRaidBosses = false
                st.customTargetBoss = nil
                wipe(st.selBossSet)
                st.selBossIdx = nil
                self:RefreshRaidGrid()
            end)
            rp:SetScript("OnEnter", function(s)
                if GameTooltip then
                    GameTooltip:SetOwner(s, "ANCHOR_TOP")
                    GameTooltip:AddLine(tostring(rObj.name), 1, 1, 1)
                    GameTooltip:AddLine(string.format("|cFF94A3B8%d encounter(s) in Midnight Season 2|r", #(rObj.bosses or {})), 1, 1, 1)
                    if hasBound and curBuild then
                        GameTooltip:AddLine("|cFF10B981Contains bound boss(es) for:|r |cFFFFFFFF" .. tostring(curBuild.name) .. "|r", 1, 1, 1)
                    end
                    GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Show bosses for this raid.|r", 1, 1, 1)
                    GameTooltip:Show()
                end
            end)
            rp:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            rp:Show()
        end

        raidGrp.allRaidBtn:SetScript("OnClick", function()
            st.selAllRaidBosses = not st.selAllRaidBosses
            if st.selAllRaidBosses then
                st.customTargetBoss = nil
                wipe(st.selBossSet)
                st.selBossIdx = nil
            end
            self:RefreshRaidGrid()
        end)
        local allOn = (st.selAllRaidBosses == true)
        local allRaidBound = (bInfo.allRaid.active == true)
        raidGrp.allRaidBtn.txt:SetTextColor((allOn or allRaidBound) and 1 or 0.78, (allOn or allRaidBound) and 1 or 0.84, (allOn or allRaidBound) and 1 or 0.92, 1)
        self:StyleBoundTile(raidGrp.allRaidBtn, allOn, allRaidBound, r, g, b)
        raidGrp.allRaidBtn:SetScript("OnEnter", function(s)
            if GameTooltip then
                GameTooltip:SetOwner(s, "ANCHOR_TOP")
                GameTooltip:AddLine("All Midnight Season 2 Raids", 1, 1, 1)
                if allRaidBound then
                    GameTooltip:AddLine("|cFF10B981Currently bound to selected build (" .. DynamicTalent:FormatDifficultySummary(bInfo.allRaid.diffs) .. ")|r", 1, 1, 1)
                else
                    local owner = DynamicTalent:GetSlotOwnerSummary("ALL_RAID")
                    if owner then GameTooltip:AddLine("|cFFFBBF24Currently bound to:|r |cFFFFFFFF" .. owner .. "|r", 1, 1, 1) end
                end
                GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Toggle raid-wide fallback for the selected difficulties. Specific boss binds override All Raids.|r", 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        raidGrp.allRaidBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

        local rObj = raids[st.selRaidIdx]
        local bosses = (rObj and rObj.bosses) or {}
        local bCount = math.min(8, #bosses)
        if st.selAllRaidBosses then
            if raidGrp.allRaidBanner then raidGrp.allRaidBanner:Show() end
            for i = 1, 8 do
                if raidGrp.bossGridBtns[i] then raidGrp.bossGridBtns[i]:Hide() end
            end
        else
            if raidGrp.allRaidBanner then raidGrp.allRaidBanner:Hide() end
            if bCount > 0 then
                local bossAreaW = innerW
                local cols = (bCount == 1 and 1) or math.min(4, bCount)
                local cellW = (bCount == 1) and bossAreaW or math.floor((bossAreaW - ((cols - 1) * 4)) / cols)
            for bIdx = 1, bCount do
                local bObj = bosses[bIdx]
                local bp = raidGrp.bossGridBtns[bIdx]
                if not bp then
                    bp = CreateFrame("Button", nil, raidGrp, "BackdropTemplate")
                    bp:SetHeight(26)
                    bp.txt = CreateText(bp, "OVERLAY", "GameFontHighlightSmall")
                    bp.txt:SetPoint("LEFT", bp, "LEFT", 6, 0)
                    bp.txt:SetPoint("RIGHT", bp, "RIGHT", -6, 0)
                    bp.txt:SetJustifyH("LEFT")
                    bp.txt:SetWordWrap(false)
                    raidGrp.bossGridBtns[bIdx] = bp
                end
                local colIdx = (bIdx - 1) % cols
                local rowIdx = math.floor((bIdx - 1) / cols)
                local isSel = (not st.selAllRaidBosses) and (st.selBossSet[bIdx] == true)
                local boundRec = bInfo.bosses[tostring(bObj.name or ""):lower()]
                local isBound = (boundRec ~= nil)
                bp:SetWidth(cellW)
                bp:ClearAllPoints()
                bp:SetPoint("TOPLEFT", raidGrp, "TOPLEFT", colIdx * (cellW + 4), -30 - (rowIdx * 30))
                if bCount == 1 then
                    bp.txt:SetText(string.format("%d. %s", bObj.order or bIdx, tostring(bObj.name)))
                else
                    bp.txt:SetText(tostring(bObj.short or string.format("%d. %s", bObj.order or bIdx, tostring(bObj.name))))
                end
                bp.txt:SetTextColor((isSel or isBound) and 1 or 0.78, (isSel or isBound) and 1 or 0.84, (isSel or isBound) and 1 or 0.92, 1)
                self:StyleBoundTile(bp, isSel, isBound, r, g, b)
                bp:SetScript("OnClick", function()
                    st.selAllRaidBosses = false
                    st.customTargetBoss = nil
                    st.selBossIdx = bIdx
                    st.selBossSet[bIdx] = (not st.selBossSet[bIdx]) and true or nil
                    self:RefreshRaidGrid()
                end)
                bp:SetScript("OnEnter", function(s)
                    if GameTooltip then
                        GameTooltip:SetOwner(s, "ANCHOR_TOP")
                        GameTooltip:AddLine(string.format("#%d %s", bObj.order or bIdx, tostring(bObj.name)), 1, 0.82, 0.25)
                        GameTooltip:AddLine(tostring(rObj.name), 0.72, 0.78, 0.86)
                        if isBound then
                            GameTooltip:AddLine("|cFF10B981Currently bound to selected build (" .. DynamicTalent:FormatDifficultySummary(boundRec.diffs) .. ")|r", 1, 1, 1)
                        else
                            local owner = DynamicTalent:GetSlotOwnerSummary("BOSS", bObj.name)
                            if owner then GameTooltip:AddLine("|cFFFBBF24Currently bound to:|r |cFFFFFFFF" .. owner .. "|r", 1, 1, 1) end
                        end
                        if type(bObj.aliases) == "table" and #bObj.aliases > 1 then
                            GameTooltip:AddLine("Target matching includes council members.", 0.58, 0.64, 0.72, true)
                        end
                        GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Toggle this boss for batch raid binding.|r", 1, 1, 1)
                        GameTooltip:Show()
                    end
                end)
                bp:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
                bp:Show()
            end
            end
        end

        if st.customTargetBoss and st.customTargetBoss ~= "" then
            raidGrp.customChip.txt:SetText("|cFFFBBF24Custom Target:|r |cFFFFFFFF" .. tostring(st.customTargetBoss) .. "|r  |cFF94A3B8(click + Bind Raid to bind, or x to dismiss)|r")
            raidGrp.customChip.clearBtn:SetScript("OnClick", function()
                st.customTargetBoss = nil
            wipe(st.selBossSet)
            st.selBossIdx = nil
                raidGrp.raidTip:SetText("|cFF64748BPick a raid and toggle bosses (or All Raids), choose difficulties, and click + Bind Raid to assign the top loadout.|r")
                self:RefreshRaidGrid()
            end)
            raidGrp.customChip:Show()
        else
            raidGrp.customChip:Hide()
        end

        if raidGrp.diffBtns and #raidGrp.diffBtns > 0 then
            local clearW = (innerW < 420) and 58 or 70
            local bindW = (innerW < 420) and 98 or 116
            if raidGrp.raidClearBtn then raidGrp.raidClearBtn:SetWidth(clearW) end
            if raidGrp.raidBindBtn then raidGrp.raidBindBtn:SetWidth(bindW) end
            local diffAreaW = math.max(150, innerW - clearW - 6 - bindW - 8)
            local diffWeights = { 88, 64, 64 }
            local diffTotalWt = 216
            local dx = 0
            local diffGap = 4
            local availDiffW = diffAreaW - ((#raidGrp.diffBtns - 1) * diffGap)
            local usedDW = 0
            for di, dbBtn in ipairs(raidGrp.diffBtns) do
                local dw
                if di == #raidGrp.diffBtns then
                    dw = math.max(44, availDiffW - usedDW)
                else
                    dw = math.max(44, math.floor((availDiffW * (diffWeights[di] or 64) / diffTotalWt) + 0.5))
                    usedDW = usedDW + dw
                end
                dbBtn:SetWidth(dw)
                dbBtn:ClearAllPoints()
                dbBtn:SetPoint("TOPLEFT", raidGrp, "TOPLEFT", dx, -114)
                if dbBtn.txt and dbBtn.dLabel then
                    dbBtn.txt:SetText((dbBtn.dKey == "normal" and dw < 80) and "LFR / N" or dbBtn.dLabel)
                end
                dx = dx + dw + diffGap
            end
        end
    end

    mplusGrp.portalGridBtns = {}
    function f:RefreshPortalGrid()
        local st = self.state
        local r, g, b = GetActiveAccentRGB()
        for _, pb in ipairs(mplusGrp.portalGridBtns) do pb:Hide() end
        if #st.mplusDungeons == 0 then st.mplusDungeons = GetCurrentSeasonMythicPlusDungeons() end
        local count = math.min(8, #st.mplusDungeons)
        local curBuild = self:GetSelectedLoadout()
        local bInfo = DynamicTalent:GetLoadoutBindings(curBuild)

        if not mplusGrp.allBtn then
            local abBtn = CreateFrame("Button", nil, mplusGrp, "BackdropTemplate")
            abBtn:SetSize(44, 28)
            abBtn:SetPoint("TOPLEFT", mplusGrp, "TOPLEFT", 0, 0)
            abBtn.txt = CreateText(abBtn, "OVERLAY", "GameFontHighlightSmall")
            abBtn.txt:SetPoint("CENTER")
            abBtn.txt:SetText("All")
            mplusGrp.allBtn = abBtn
        end
        mplusGrp.allBtn:SetScript("OnClick", function()
            if #st.mplusDungeons == 0 then st.mplusDungeons = GetCurrentSeasonMythicPlusDungeons() end
            local cNow = math.min(8, #st.mplusDungeons)
            if st.selAllDungeons then
                st.selAllDungeons = false
                wipe(st.selDungeonSet)
            else
                st.selAllDungeons = true
                wipe(st.selDungeonSet)
                for i = 1, cNow do st.selDungeonSet[i] = true end
            end
            self:RefreshPortalGrid()
        end)
        local allMBound = (bInfo.allMPlus.active == true)
        mplusGrp.allBtn:SetScript("OnEnter", function(s)
            if GameTooltip then
                GameTooltip:SetOwner(s, "ANCHOR_TOP")
                GameTooltip:AddLine("All Season M+ Dungeons", 1, 1, 1)
                if allMBound then
                    GameTooltip:AddLine("|cFF10B981Currently bound to selected build.|r", 1, 1, 1)
                else
                    local owner = DynamicTalent:GetSlotOwnerSummary("ALL_MPLUS")
                    if owner then GameTooltip:AddLine("|cFFFBBF24Currently bound to:|r |cFFFFFFFF" .. owner .. "|r", 1, 1, 1) end
                end
                GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Select or clear all season dungeons (saves one All M+ rule).|r", 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        mplusGrp.allBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        mplusGrp.allBtn.txt:SetTextColor((st.selAllDungeons or allMBound) and 1 or 0.78, (st.selAllDungeons or allMBound) and 1 or 0.84, (st.selAllDungeons or allMBound) and 1 or 0.92, 1)
        self:StyleBoundTile(mplusGrp.allBtn, st.selAllDungeons, allMBound, r, g, b)
        mplusGrp.allBtn:Show()

        local rawW = mplusGrp:GetWidth()
        local innerW = math.max(360, math.floor(((rawW and rawW > 100) and rawW or self._rightInnerW or 498) + 0.5))
        local dungAreaW = innerW - 48
        local isTwoRow = (count > 4) and (dungAreaW < 480)
        mplusGrp.allBtn:SetHeight(isTwoRow and 60 or 28)

        local ctrlY = isTwoRow and -66 or -34
        local tipY = isTwoRow and -98 or -66
        if mplusGrp.tierBtns then
            local tx = 0
            for _, tb in ipairs(mplusGrp.tierBtns) do
                tb:ClearAllPoints()
                tb:SetPoint("TOPLEFT", mplusGrp, "TOPLEFT", tx, ctrlY)
                tx = tx + (tb:GetWidth() or 74) + 6
            end
        end
        if mplusGrp.mplusBindBtn then
            mplusGrp.mplusBindBtn:ClearAllPoints()
            mplusGrp.mplusBindBtn:SetPoint("TOPRIGHT", mplusGrp, "TOPRIGHT", 0, ctrlY)
        end
        if mplusGrp.mplusTip then
            mplusGrp.mplusTip:ClearAllPoints()
            mplusGrp.mplusTip:SetPoint("TOPLEFT", mplusGrp, "TOPLEFT", 2, tipY)
            mplusGrp.mplusTip:SetPoint("TOPRIGHT", mplusGrp, "TOPRIGHT", -2, tipY)
        end
        if st.subMode == "MPLUS" and self.bCard then
            self.bCard:SetHeight(isTwoRow and 184 or 152)
        end

        if count == 0 then return end
        local cols = isTwoRow and 4 or count
        local gapX = isTwoRow and 4 or 3
        local cellW = math.floor((dungAreaW - ((cols - 1) * gapX)) / cols)
        for idx = 1, count do
            local dObj = st.mplusDungeons[idx]
            local pb = mplusGrp.portalGridBtns[idx]
            if not pb then
                pb = CreateFrame("Button", nil, mplusGrp, "BackdropTemplate")
                pb:SetHeight(28)
                pb.icon = pb:CreateTexture(nil, "ARTWORK")
                pb.icon:SetSize(16, 16)
                pb.icon:SetPoint("LEFT", pb, "LEFT", 3, 0)
                pb.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                pb.txt = CreateText(pb, "OVERLAY", "GameFontHighlightSmall")
                pb.txt:SetPoint("LEFT", pb.icon, "RIGHT", 2, 0)
                pb.txt:SetPoint("RIGHT", pb, "RIGHT", -2, 0)
                pb.txt:SetJustifyH("LEFT")
                pb.txt:SetWordWrap(false)
                mplusGrp.portalGridBtns[idx] = pb
            end
            local colIdx = (idx - 1) % cols
            local rowIdx = math.floor((idx - 1) / cols)
            local isSel = (st.selDungeonSet[idx] == true)
            local isBound = (bInfo.dungeons[tostring(dObj.name or ""):lower()] ~= nil)
            pb:SetWidth(cellW)
            pb:ClearAllPoints()
            pb:SetPoint("TOPLEFT", mplusGrp, "TOPLEFT", 48 + (colIdx * (cellW + gapX)), -(rowIdx * 32))
            pb.icon:SetTexture(dObj.icon or 525134)
            pb.txt:SetText(dObj.short or ("M" .. idx))
            pb.txt:SetTextColor((isSel or isBound) and 1 or 0.78, (isSel or isBound) and 1 or 0.84, (isSel or isBound) and 1 or 0.92, 1)
            self:StyleBoundTile(pb, isSel, isBound, r, g, b)
            pb:SetScript("OnClick", function()
                st.selDungeonSet[idx] = (not st.selDungeonSet[idx]) and true or nil
                local allChecked = (count > 0)
                for j = 1, count do
                    if not st.selDungeonSet[j] then allChecked = false; break end
                end
                st.selAllDungeons = allChecked
                self:RefreshPortalGrid()
            end)
            pb:SetScript("OnEnter", function(s)
                if GameTooltip then
                    GameTooltip:SetOwner(s, "ANCHOR_TOP")
                    GameTooltip:AddLine(dObj.name or "Mythic+ Dungeon", 1, 1, 1)
                    if isBound then
                        GameTooltip:AddLine("|cFF10B981Currently bound to selected build.|r", 1, 1, 1)
                    else
                        local owner = DynamicTalent:GetSlotOwnerSummary("DUNGEON", dObj.name)
                        if owner then GameTooltip:AddLine("|cFFFBBF24Currently bound to:|r |cFFFFFFFF" .. owner .. "|r", 1, 1, 1) end
                    end
                    GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Toggle this dungeon for batch M+ talent binding.|r", 1, 1, 1)
                    GameTooltip:Show()
                end
            end)
            pb:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            pb:Show()
        end
    end

    function f:RefreshPvPTiles()
        local st = self.state
        local r, g, b = GetActiveAccentRGB()
        local curBuild = self:GetSelectedLoadout()
        local bInfo = DynamicTalent:GetLoadoutBindings(curBuild)

        local rawW = pvpGrp:GetWidth()
        local innerW = math.max(380, math.floor(((rawW and rawW > 100) and rawW or self._rightInnerW or 498) + 0.5))
        local numP = math.max(1, #pvpGrp.pvpBtns)
        local pCellW = math.floor((innerW - ((numP - 1) * 4)) / numP)
        for pi, pb in ipairs(pvpGrp.pvpBtns) do
            pb:SetWidth(pCellW)
            pb:ClearAllPoints()
            pb:SetPoint("TOPLEFT", pvpGrp, "TOPLEFT", (pi - 1) * (pCellW + 4), 0)
            local pOn = (st.selPvPSet[pb.pKey] == true)
            local pBound = (bInfo.pvp[pb.pKey] == true)
            pb.txt:SetTextColor((pOn or pBound) and 1 or 0.78, (pOn or pBound) and 1 or 0.84, (pOn or pBound) and 1 or 0.92, 1)
            self:StyleBoundTile(pb, pOn, pBound, r, g, b)
            pb:SetScript("OnClick", function()
                st.selPvPSet[pb.pKey] = (not st.selPvPSet[pb.pKey]) and true or nil
                self:RefreshPvPTiles()
            end)
            pb:SetScript("OnEnter", function(s)
                if GameTooltip then
                    GameTooltip:SetOwner(s, "ANCHOR_TOP")
                    GameTooltip:AddLine("PvP: " .. tostring(pb.pLabel), 1, 1, 1)
                    GameTooltip:AddLine("|cFFE2E8F0" .. tostring(pb.pDesc) .. "|r", 1, 1, 1, true)
                    if pBound then
                        GameTooltip:AddLine("|cFF10B981Currently bound to selected build.|r", 1, 1, 1)
                    else
                        local owner = DynamicTalent:GetSlotOwnerSummary("PVP", pb.pKey)
                        if owner then GameTooltip:AddLine("|cFFFBBF24Currently bound to:|r |cFFFFFFFF" .. owner .. "|r", 1, 1, 1) end
                    end
                    GameTooltip:Show()
                end
            end)
            pb:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        end
    end

    function f:RefreshZonePills()
        local st = self.state
        local r, g, b = GetActiveAccentRGB()
        local curBuild = self:GetSelectedLoadout()
        local bInfo = DynamicTalent:GetLoadoutBindings(curBuild)

        local allOn = (st.selAllZones == true)
        local allZBound = (bInfo.zones.all == true)
        zoneGrp.allZoneBtn.txt:SetTextColor((allOn or allZBound) and 1 or 0.78, (allOn or allZBound) and 1 or 0.84, (allOn or allZBound) and 1 or 0.92, 1)
        self:StyleBoundTile(zoneGrp.allZoneBtn, allOn, allZBound, r, g, b)
        zoneGrp.allZoneBtn:SetScript("OnClick", function()
            if st.selAllZones then
                st.selAllZones = false
                wipe(st.selZoneSet)
            else
                st.selAllZones = true
                for _, bBtn in ipairs(zoneGrp.zoneBtns) do
                    st.selZoneSet[bBtn.zKey] = true
                end
            end
            self:RefreshZonePills()
        end)
        zoneGrp.allZoneBtn:SetScript("OnEnter", function(s)
            if GameTooltip then
                GameTooltip:SetOwner(s, "ANCHOR_TOP")
                GameTooltip:AddLine("All Content Default", 1, 1, 1)
                if allZBound then
                    GameTooltip:AddLine("|cFF10B981Currently bound to selected build.|r", 1, 1, 1)
                else
                    local owner = DynamicTalent:GetSlotOwnerSummary("ZONE", "all")
                    if owner then GameTooltip:AddLine("|cFFFBBF24Currently bound to:|r |cFFFFFFFF" .. owner .. "|r", 1, 1, 1) end
                end
                GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Select or clear all 5 zones (saving All creates one [All Content] rule).|r", 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        zoneGrp.allZoneBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

        local rawW = zoneGrp:GetWidth()
        local innerW = math.max(380, math.floor(((rawW and rawW > 100) and rawW or self._rightInnerW or 498) + 0.5))
        local zAreaW = innerW - 54
        local numZ = math.max(1, #zoneGrp.zoneBtns)
        local zCellW = math.floor((zAreaW - ((numZ - 1) * 4)) / numZ)
        for zi, zb in ipairs(zoneGrp.zoneBtns) do
            zb:SetWidth(zCellW)
            zb:ClearAllPoints()
            zb:SetPoint("TOPLEFT", zoneGrp, "TOPLEFT", 54 + ((zi - 1) * (zCellW + 4)), 0)
            local zOn = (st.selZoneSet[zb.zKey] == true)
            local zBound = (bInfo.zones[zb.zKey] == true)
            zb.txt:SetTextColor((zOn or zBound) and 1 or 0.78, (zOn or zBound) and 1 or 0.84, (zOn or zBound) and 1 or 0.92, 1)
            self:StyleBoundTile(zb, zOn, zBound, r, g, b)
            zb:SetScript("OnClick", function()
                st.selZoneSet[zb.zKey] = (not st.selZoneSet[zb.zKey]) and true or nil
                local allChecked = true
                for _, cb in ipairs(zoneGrp.zoneBtns) do
                    if not st.selZoneSet[cb.zKey] then allChecked = false; break end
                end
                st.selAllZones = allChecked
                self:RefreshZonePills()
            end)
            zb:SetScript("OnEnter", function(s)
                if GameTooltip then
                    GameTooltip:SetOwner(s, "ANCHOR_TOP")
                    GameTooltip:AddLine("Zone: " .. tostring(zb.zLabel), 1, 1, 1)
                    GameTooltip:AddLine("|cFFE2E8F0" .. tostring(zb.zDesc) .. "|r", 1, 1, 1, true)
                    if zBound then
                        GameTooltip:AddLine("|cFF10B981Currently bound to selected build.|r", 1, 1, 1)
                    else
                        local oKind = (zb.zKey == "raid" and "ALL_RAID") or (zb.zKey == "dungeons" and "ALL_MPLUS") or (zb.zKey == "pvp" and "PVP") or "ZONE"
                        local oKey = (zb.zKey == "pvp") and "all" or zb.zKey
                        local owner = DynamicTalent:GetSlotOwnerSummary(oKind, oKey)
                        if owner then GameTooltip:AddLine("|cFFFBBF24Currently bound to:|r |cFFFFFFFF" .. owner .. "|r", 1, 1, 1) end
                    end
                    GameTooltip:Show()
                end
            end)
            zb:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        end
    end
    f:RefreshZonePills()

    tgtBtn:SetScript("OnClick", function()
        local st = f.state
        local tn = nil
        local function ReadUnitNameSafe(unit)
            if type(UnitExists) ~= "function" or type(UnitName) ~= "function" then return nil end
            local okEx, hasUnit = pcall(UnitExists, unit)
            if not okEx or _IsSecret(hasUnit) or not hasUnit then return nil end
            local okNm, nm = pcall(UnitName, unit)
            if not okNm or type(nm) ~= "string" or _IsSecret(nm) then return nil end
            local trimmed = SafeTrim(nm)
            return (trimmed ~= "") and trimmed or nil
        end
        tn = ReadUnitNameSafe("target") or ReadUnitNameSafe("softenemy")
        if not tn then
            Print("Select or face an NPC or boss target first before clicking Target.")
            raidTip:SetText("|cFFFBBF24No valid target selected -- target or face a raid boss or NPC, then click Target.|r")
            return
        end
        if #st.ejRaids == 0 then st.ejRaids = GetCurrentTierRaids() end
        local mR, mB, rObj, bObj = DynamicTalent:MatchBossTargetName(tn, st.ejRaids)
        if mR and mB and bObj then
            st.selRaidIdx = mR
            st.selBossIdx = mB
            st.selAllRaidBosses = false
            wipe(st.selBossSet)
            st.selBossSet[mB] = true
            st.customTargetBoss = nil
            f:RefreshRaidGrid()
            local ord = bObj.order or mB
            Print(string.format("Matched target |cFFFFFFFF%s|r -> |cFFFBBF24%s #%d %s|r.", tn, tostring(rObj.short or rObj.name), ord, tostring(bObj.name)))
            raidTip:SetText(string.format("|cFF10B981Matched %s -> %s #%d %s.|r Toggle difficulties and click + Bind Raid.", tn, tostring(rObj.short or rObj.name), ord, tostring(bObj.name)))
        else
            st.customTargetBoss = tn
            st.selAllRaidBosses = false
            wipe(st.selBossSet)
            f:RefreshRaidGrid()
            Print(string.format("Custom target set to |cFFFBBF24%s|r. Choose difficulties and click + Bind Raid.", tn))
            raidTip:SetText(string.format("|cFFFBBF24Custom target active: %s.|r Choose difficulties and click + Bind Raid (or click x to dismiss).", tn))
        end
    end)

    function f:EnsureBuildSavedForBind()
        local specID = DynamicTalent:GetActiveSpecID()
        if not specID then
            Print("No active specialisation found to save or bind loadouts.")
            return nil
        end
        local existing = self:GetSelectedLoadout()
        if type(existing) == "table" then
            return existing
        end
        local rawName = SafeTrim(nameEB:GetText() or "")
        if rawName == "" then
            local errTxt = "Enter a loadout name on the left before binding."
            if valStatus then valStatus:SetText("|cFFF43F5E" .. errTxt .. "|r") end
            if nameEB then nameEB:SetFocus(); nameEB:HighlightText() end
            Print(errTxt)
            return nil
        end
        local rawStr = SafeTrim(strEB:GetText() or "")
        if rawStr == "" then
            local errTxt = "Paste a talent string or click Use Current Tree before binding."
            if valStatus then valStatus:SetText("|cFFF43F5E" .. errTxt .. "|r") end
            if strEB then strEB:SetFocus() end
            Print(errTxt)
            return nil
        end
        local ok, msg, savedEntry = DynamicTalent:ImportTalentString(rawName, rawStr, selGroup)
        if not ok or type(savedEntry) ~= "table" then
            local errTxt = tostring(msg or "Enter a valid talent string before binding.")
            if valStatus then valStatus:SetText("|cFFF43F5E" .. errTxt .. "|r") end
            if strEB then strEB:SetFocus(); strEB:HighlightText() end
            Print(errTxt)
            return nil
        end
        self:SelectLoadout(savedEntry, true)
        if valStatus then
            valStatus:SetText("|cFF10B981Auto-saved '" .. tostring(savedEntry.name or rawName) .. "' -- ready to bind.|r")
        end
        return savedEntry
    end

    raidBindBtn:SetScript("OnClick", function()
        local st = f.state
        local sel = f:EnsureBuildSavedForBind()
        if not sel then return end
        local specID = DynamicTalent:GetActiveSpecID()
        if not specID then return end
        DynamicTalent:RefreshLoadoutHeroMeta(sel)
        local selID = EnsureEntryID(sel, DynamicTalent.db)
        local bMap = (DynamicTalent.db and DynamicTalent.db.talentBossMap and DynamicTalent.db.talentBossMap[specID]) or {}
        local dsSnap = {
            normal = st.diffState.normal and true or false,
            heroic = st.diffState.heroic and true or false,
            mythic = st.diffState.mythic and true or false,
        }
        if not (dsSnap.normal or dsSnap.heroic or dsSnap.mythic) then
            dsSnap.normal, dsSnap.heroic, dsSnap.mythic = true, true, true
        end

        if st.selAllRaidBosses then
            local conflicts = DynamicTalent:DetectBindConflicts("ALL_RAID", { diffState = dsSnap }, sel, specID)
            local opts = nil
            if #conflicts > 0 then
                local claimed = { normal = false, heroic = false, mythic = false }
                for _, exV in pairs(bMap) do
                    if type(exV) == "table" and exV.isAllRaid == true and type(exV.loadoutName) == "string" and exV.loadoutName ~= "" and not DoesRuleMatchEntry(exV, sel) then
                        local exAll = (type(exV.difficulties) ~= "table")
                        if exAll or exV.difficulties.normal then claimed.normal = true end
                        if exAll or exV.difficulties.heroic then claimed.heroic = true end
                        if exAll or exV.difficulties.mythic then claimed.mythic = true end
                    end
                end
                local unboundDiffs = {
                    normal = dsSnap.normal and (not claimed.normal) or false,
                    heroic = dsSnap.heroic and (not claimed.heroic) or false,
                    mythic = dsSnap.mythic and (not claimed.mythic) or false,
                }
                local unboundCount = (unboundDiffs.normal and 1 or 0) + (unboundDiffs.heroic and 1 or 0) + (unboundDiffs.mythic and 1 or 0)
                if unboundCount > 0 then
                    opts = {
                        unboundCount = unboundCount,
                        onBindUnboundOnly = function() DynamicTalent:SetAllRaidDefault(sel, unboundDiffs, false) end,
                    }
                end
            end
            DynamicTalent:ConfirmBindOverwrite(conflicts, sel, function() DynamicTalent:SetAllRaidDefault(sel, dsSnap, false) end, opts)
            return
        end

        local targets = {}
        if st.customTargetBoss and st.customTargetBoss ~= "" then
            table.insert(targets, { name = st.customTargetBoss, order = nil, raidName = nil, raidShort = nil })
        else
            local rObj = st.ejRaids[st.selRaidIdx]
            local bosses = (rObj and rObj.bosses) or {}
            for bIdx = 1, #bosses do
                if st.selBossSet[bIdx] and bosses[bIdx] then
                    table.insert(targets, {
                        name      = bosses[bIdx].name,
                        order     = bosses[bIdx].order or bIdx,
                        raidName  = rObj.name,
                        raidShort = rObj.short or rObj.name,
                    })
                end
            end
        end
        if #targets == 0 then
            Print("Select at least one boss (or All Raids / Target) before binding.")
            return
        end

        local function ApplyBossTargetSpecs(specList)
            DynamicTalent.db.talentBossMap = DynamicTalent.db.talentBossMap or {}
            DynamicTalent.db.talentBossMap[specID] = DynamicTalent.db.talentBossMap[specID] or {}
            local tMap = DynamicTalent.db.talentBossMap[specID]
            local boundNames = {}
            for _, item in ipairs(specList) do
                local tInfo = item.tInfo
                local dTbl = item.diffs or dsSnap
                local mask = (dTbl.normal and "N" or "") .. (dTbl.heroic and "H" or "") .. (dTbl.mythic and "M" or "")
                if mask == "" then mask = "NHM" end
                local bName = tInfo.name
                local bLow = bName:lower()
                local mapKey = bLow .. "|" .. mask
                for exK, exV in pairs(tMap) do
                    if type(exV) == "table" and not exV.isAllRaid and tostring(exV.bossName or exK):lower() == bLow and exK ~= mapKey then
                        if type(exV.difficulties) == "table" then
                            if dTbl.normal then exV.difficulties.normal = false end
                            if dTbl.heroic then exV.difficulties.heroic = false end
                            if dTbl.mythic then exV.difficulties.mythic = false end
                            if not (exV.difficulties.normal or exV.difficulties.heroic or exV.difficulties.mythic) then
                                tMap[exK] = nil
                            end
                        else
                            local keepN, keepH, keepM = (not dTbl.normal), (not dTbl.heroic), (not dTbl.mythic)
                            tMap[exK] = nil
                            if keepN or keepH or keepM then
                                local km = (keepN and "N" or "") .. (keepH and "H" or "") .. (keepM and "M" or "")
                                tMap[bLow .. "|" .. km] = {
                                    bossName = exV.bossName or bName, bossOrder = exV.bossOrder,
                                    raidName = exV.raidName, raidShort = exV.raidShort,
                                    loadoutID = exV.loadoutID,
                                    loadoutName = exV.loadoutName, importString = exV.importString,
                                    group = exV.group, heroAcronym = exV.heroAcronym,
                                    difficulties = { normal = keepN, heroic = keepH, mythic = keepM },
                                }
                            end
                        end
                    end
                end
                tMap[mapKey] = {
                    bossName = bName, bossOrder = tInfo.order, raidName = tInfo.raidName, raidShort = tInfo.raidShort,
                    loadoutID = selID, loadoutName = sel.name, importString = sel.importString,
                    group = sel.group or "Raid", heroAcronym = sel.heroAcronym,
                    difficulties = { normal = dTbl.normal and true or false, heroic = dTbl.heroic and true or false, mythic = dTbl.mythic and true or false },
                }
                table.insert(boundNames, ((tInfo.order and ("#" .. tInfo.order .. " ") or "") .. bName .. " [" .. DynamicTalent:FormatDifficultySummary(dTbl) .. "]"))
            end
            st.customTargetBoss = nil
            wipe(st.selBossSet)
            st.selBossIdx = nil
            if #boundNames == 1 then
                Print(string.format("Bound boss |cFFFBBF24%s|r -> %s |cFFFFFFFF%s|r.", boundNames[1], DynamicTalent:FormatTalentBadge(sel), sel.name))
            else
                Print(string.format("Bound %d bosses (%s) -> %s |cFFFFFFFF%s|r.", #boundNames, table.concat(boundNames, ", "), DynamicTalent:FormatTalentBadge(sel), sel.name))
            end
            DynamicTalent:SyncTalentBindsUI(true)
        end

        local fullSpecs = {}
        for _, tInfo in ipairs(targets) do table.insert(fullSpecs, { tInfo = tInfo, diffs = dsSnap }) end
        local conflicts = DynamicTalent:DetectBindConflicts("BOSS_LIST", { targets = targets, diffState = dsSnap }, sel, specID)
        local opts = nil
        if #conflicts > 0 then
            local unboundSpecs, unboundCount = {}, 0
            for _, tInfo in ipairs(targets) do
                local bLow = tostring(tInfo.name or ""):lower()
                local freeN, freeH, freeM = dsSnap.normal, dsSnap.heroic, dsSnap.mythic
                for _, exV in pairs(bMap) do
                    if type(exV) == "table" and exV.isAllRaid ~= true and tostring(exV.bossName or ""):lower() == bLow
                        and type(exV.loadoutName) == "string" and exV.loadoutName ~= "" and not DoesRuleMatchEntry(exV, sel) then
                        local exAll = (type(exV.difficulties) ~= "table")
                        if exAll or exV.difficulties.normal then freeN = false end
                        if exAll or exV.difficulties.heroic then freeH = false end
                        if exAll or exV.difficulties.mythic then freeM = false end
                    end
                end
                local rem = (freeN and 1 or 0) + (freeH and 1 or 0) + (freeM and 1 or 0)
                if rem > 0 then
                    table.insert(unboundSpecs, { tInfo = tInfo, diffs = { normal = freeN, heroic = freeH, mythic = freeM } })
                    unboundCount = unboundCount + rem
                end
            end
            if unboundCount > 0 then
                opts = { unboundCount = unboundCount, onBindUnboundOnly = function() ApplyBossTargetSpecs(unboundSpecs) end }
            end
        end
        DynamicTalent:ConfirmBindOverwrite(conflicts, sel, function() ApplyBossTargetSpecs(fullSpecs) end, opts)
    end)

    mplusBindBtn:SetScript("OnClick", function()
        local st = f.state
        local sel = f:EnsureBuildSavedForBind()
        if not sel then return end
        local specID = DynamicTalent:GetActiveSpecID()
        if not specID then return end
        DynamicTalent:RefreshLoadoutHeroMeta(sel)
        local kt = st.selKeyTier
        local tLbl = (kt == "HIGH" and "+10+") or (kt == "LOW" and "+2-9") or "Any Key"

        if st.selAllDungeons then
            local conflicts = DynamicTalent:DetectBindConflicts("ALL_MPLUS", { keyTier = kt }, sel, specID)
            local opts = nil
            if #conflicts > 0 and kt == "ANY" then
                local lowBusy = (#DynamicTalent:DetectBindConflicts("ALL_MPLUS", { keyTier = "LOW" }, sel, specID) > 0)
                local highBusy = (#DynamicTalent:DetectBindConflicts("ALL_MPLUS", { keyTier = "HIGH" }, sel, specID) > 0)
                local unboundTier = (not lowBusy and highBusy and "LOW") or (not highBusy and lowBusy and "HIGH") or nil
                if unboundTier then
                    opts = { unboundCount = 1, onBindUnboundOnly = function() DynamicTalent:SetAllMPlusDefault(sel, unboundTier, false) end }
                end
            end
            DynamicTalent:ConfirmBindOverwrite(conflicts, sel, function() DynamicTalent:SetAllMPlusDefault(sel, kt, false) end, opts)
            return
        end
        if #st.mplusDungeons == 0 then st.mplusDungeons = GetCurrentSeasonMythicPlusDungeons() end
        local chosen = {}
        local count = math.min(8, #st.mplusDungeons)
        for idx = 1, count do
            if st.selDungeonSet[idx] and st.mplusDungeons[idx] then
                table.insert(chosen, st.mplusDungeons[idx])
            end
        end
        if #chosen == 0 then
            Print("Select at least one dungeon (or click All) before binding.")
            return
        end

        local function ApplyMPlusList(listToBind)
            DynamicTalent.db.talentDungeonMap = DynamicTalent.db.talentDungeonMap or {}
            DynamicTalent.db.talentDungeonMap[specID] = DynamicTalent.db.talentDungeonMap[specID] or {}
            local dMap = DynamicTalent.db.talentDungeonMap[specID]
            local shortList = {}
            for _, dObj in ipairs(listToBind) do
                local dLow = dObj.name:lower()
                for exK, exV in pairs(dMap) do
                    local exAll = type(exV) == "table" and (exV.isAllMPlus == true or tostring(exV.dungeonName or exK):lower() == "all m+ dungeons")
                    if type(exV) == "table" and not exAll and tostring(exV.dungeonName or exK):lower() == dLow
                        and (exV.keyTier == kt or kt == "ANY" or exV.keyTier == "ANY") then
                        dMap[exK] = nil
                    end
                end
                dMap[dLow .. "|" .. kt] = {
                    dungeonName = dObj.name, mapID = dObj.id, keyTier = kt,
                    loadoutID = EnsureEntryID(sel, DynamicTalent.db),
                    loadoutName = sel.name, importString = sel.importString,
                    group = sel.group or "M+", heroAcronym = sel.heroAcronym,
                }
                table.insert(shortList, dObj.short or dObj.name)
            end
            if #listToBind == 1 then
                Print(string.format("Bound M+ |cFF38BDF8%s|r [%s] -> %s |cFFFFFFFF%s|r.", listToBind[1].name, tLbl, DynamicTalent:FormatTalentBadge(sel), sel.name))
            else
                Print(string.format("Bound %d M+ dungeons (%s) [%s] -> %s |cFFFFFFFF%s|r.", #listToBind, table.concat(shortList, ", "), tLbl, DynamicTalent:FormatTalentBadge(sel), sel.name))
            end
            DynamicTalent:SyncTalentBindsUI(true)
        end

        local conflicts = DynamicTalent:DetectBindConflicts("MPLUS_LIST", { dungeons = chosen, keyTier = kt }, sel, specID)
        local opts = nil
        if #conflicts > 0 then
            local unboundChosen = {}
            for _, dObj in ipairs(chosen) do
                if #DynamicTalent:DetectBindConflicts("MPLUS_LIST", { dungeons = { dObj }, keyTier = kt }, sel, specID) == 0 then
                    table.insert(unboundChosen, dObj)
                end
            end
            if #unboundChosen > 0 then
                opts = { unboundCount = #unboundChosen, onBindUnboundOnly = function() ApplyMPlusList(unboundChosen) end }
            end
        end
        DynamicTalent:ConfirmBindOverwrite(conflicts, sel, function() ApplyMPlusList(chosen) end, opts)
    end)

    pvpBindBtn:SetScript("OnClick", function()
        local st = f.state
        local sel = f:EnsureBuildSavedForBind()
        if not sel then return end
        local specID = DynamicTalent:GetActiveSpecID()
        if not specID then return end
        local chosenKeys, pvpSnap = {}, {}
        for _, pk in ipairs({ "all", "arena", "bg", "warmode" }) do
            if st.selPvPSet[pk] then
                table.insert(chosenKeys, pk)
                pvpSnap[pk] = true
            end
        end
        if #chosenKeys == 0 then
            Print("Select at least one PvP mode tile before binding.")
            pvpTip:SetText("|cFFFBBF24Select at least one PvP mode tile above, then click + Bind PvP.|r")
            return
        end
        local conflicts = DynamicTalent:DetectBindConflicts("PVP_LIST", { pvpKeys = chosenKeys }, sel, specID)
        local opts = nil
        if #conflicts > 0 then
            local unboundSnap, unboundCount = {}, 0
            for _, pk in ipairs(chosenKeys) do
                if #DynamicTalent:DetectBindConflicts("PVP_LIST", { pvpKeys = { pk } }, sel, specID) == 0 then
                    unboundSnap[pk] = true
                    unboundCount = unboundCount + 1
                end
            end
            if unboundCount > 0 then
                opts = {
                    unboundCount = unboundCount,
                    onBindUnboundOnly = function()
                        DynamicTalent:SetPvPDefaults(sel, unboundSnap, false)
                        pvpTip:SetText("|cFF10B981Unbound PvP mode(s) updated; existing binds left untouched.|r")
                    end,
                }
            end
        end
        DynamicTalent:ConfirmBindOverwrite(conflicts, sel, function()
            DynamicTalent:SetPvPDefaults(sel, pvpSnap, false)
            pvpTip:SetText("|cFF10B981PvP talent bind(s) updated! Specific modes (Arena, BGs, War Mode) override All PvP.|r")
        end, opts)
    end)

    pvpClearBtn:SetScript("OnClick", function()
        local st = f.state
        if not next(st.selPvPSet) then
            Print("Select one or more PvP mode tiles before clearing.")
            pvpTip:SetText("|cFFFBBF24Select one or more PvP mode tiles first, then click Clear.|r")
            return
        end
        if not DynamicTalent:ClearPvPDefaults(st.selPvPSet, false) then
            Print("No matching PvP binds were active to clear.")
            pvpTip:SetText("|cFF94A3B8No matching PvP binds were active for the selected tiles.|r")
        else
            pvpTip:SetText("|cFF10B981Cleared selected PvP bind(s); other PvP and boss/dungeon binds remain intact.|r")
        end
    end)

    zoneBindBtn:SetScript("OnClick", function()
        local st = f.state
        local sel = f:EnsureBuildSavedForBind()
        if not sel then return end
        if not st.selAllZones and not next(st.selZoneSet) then
            Print("Select at least one zone pill (or All) before binding.")
            zoneTip:SetText("|cFFFBBF24Select at least one zone pill (or All), then click + Bind Zones.|r")
            return
        end
        local zoneSnap = {}
        for k, v in pairs(st.selZoneSet) do if v then zoneSnap[k] = true end end
        local isAllSnap = (st.selAllZones == true)
        local conflicts = DynamicTalent:DetectBindConflicts("ZONES", { zoneSet = zoneSnap, isAll = isAllSnap }, sel)
        local opts = nil
        if not isAllSnap and #conflicts > 0 then
            local unboundZoneSnap, unboundCount = {}, 0
            for zk, enabled in pairs(zoneSnap) do
                if enabled then
                    if #DynamicTalent:DetectBindConflicts("ZONES", { zoneSet = { [zk] = true }, isAll = false }, sel) == 0 then
                        unboundZoneSnap[zk] = true
                        unboundCount = unboundCount + 1
                    end
                end
            end
            if unboundCount > 0 then
                opts = {
                    unboundCount = unboundCount,
                    onBindUnboundOnly = function()
                        DynamicTalent:SetZoneDefaults(sel, unboundZoneSnap, false)
                        zoneTip:SetText("|cFF10B981Unbound zone default(s) updated; existing binds left untouched.|r")
                    end,
                }
            end
        end
        DynamicTalent:ConfirmBindOverwrite(conflicts, sel, function()
            DynamicTalent:SetZoneDefaults(sel, zoneSnap, isAllSnap)
            zoneTip:SetText("|cFF10B981Zone default(s) updated! Specific Raid bosses, M+ dungeons & PvP modes override defaults.|r")
        end, opts)
    end)

    zoneClearBtn:SetScript("OnClick", function()
        local st = f.state
        if not st.selAllZones and not next(st.selZoneSet) then
            Print("Select one or more zone pills (or All) before clearing.")
            zoneTip:SetText("|cFFFBBF24Select one or more zone pills (or All) first, then click Clear.|r")
            return
        end
        if not DynamicTalent:ClearZoneDefaults(st.selZoneSet, st.selAllZones) then
            Print("No matching zone default rules were active to clear.")
            zoneTip:SetText("|cFF94A3B8No matching zone defaults were active for the selected pills.|r")
        else
            zoneTip:SetText("|cFF10B981Cleared selected zone default(s); specific boss, dungeon & PvP mode binds remain intact.|r")
        end
    end)

    -- Active Reminders List Card
    local listCard = CreateFrame("Frame", nil, p2, "BackdropTemplate")
    listCard:SetPoint("TOPLEFT", bCard, "BOTTOMLEFT", 0, -8)
    listCard:SetPoint("BOTTOMRIGHT", p2, "BOTTOMRIGHT", 0, 0)
    SetPixelBackdrop(listCard, CARD_BG, CARD_BDR, 1)
    f.listCard = listCard

    local listHdr = CreateModalSectionHeader(listCard, "|cFFFFFFFFACTIVE REMINDERS|r", "Priority order: Specific Boss / M+ / PvP Mode overrides defaults", -10)
    f.listHdr = listHdr

    do
        local listFilterBar = CreateFrame("Frame", nil, listCard, "BackdropTemplate")
        listFilterBar:SetSize(136, 22)
        listFilterBar:SetPoint("TOPRIGHT", listCard, "TOPRIGHT", -12, -12)
        SetPixelBackdrop(listFilterBar, COLORS.BgElevated, COLORS.BorderSubtle, 1)

        local filterBuildBtn = CreateFrame("Button", nil, listFilterBar, "BackdropTemplate")
        filterBuildBtn:SetSize(68, 18)
        filterBuildBtn:SetPoint("LEFT", listFilterBar, "LEFT", 2, 0)
        filterBuildBtn.txt = CreateText(filterBuildBtn, "OVERLAY", "GameFontHighlightSmall")
        filterBuildBtn.txt:SetPoint("CENTER")
        filterBuildBtn.txt:SetText("This Build")

        local filterAllBtn = CreateFrame("Button", nil, listFilterBar, "BackdropTemplate")
        filterAllBtn:SetSize(62, 18)
        filterAllBtn:SetPoint("RIGHT", listFilterBar, "RIGHT", -2, 0)
        filterAllBtn.txt = CreateText(filterAllBtn, "OVERLAY", "GameFontHighlightSmall")
        filterAllBtn.txt:SetPoint("CENTER")
        filterAllBtn.txt:SetText("All")

        if listHdr.textArea then
            listHdr.textArea:ClearAllPoints()
            listHdr.textArea:SetPoint("TOPLEFT", listHdr, "TOPLEFT", 11, -2)
            listHdr.textArea:SetPoint("BOTTOMLEFT", listHdr, "BOTTOMLEFT", 11, 2)
            listHdr.textArea:SetPoint("RIGHT", listFilterBar, "LEFT", -10, 0)
        end

        f.listFilterBar = listFilterBar
        f.filterBuildBtn = filterBuildBtn
        f.filterAllBtn = filterAllBtn
    end

    local emptyBossHint = CreateText(listCard, "OVERLAY", "GameFontHighlightSmall")
    emptyBossHint:SetPoint("TOPLEFT", listCard, "TOPLEFT", 14, -56)
    emptyBossHint:SetPoint("TOPRIGHT", listCard, "TOPRIGHT", -14, -56)
    emptyBossHint:SetJustifyH("LEFT")
    emptyBossHint:SetWordWrap(true)
    emptyBossHint:SetText("|cFF64748BNo binds set for this build yet. Binding is optional -- pick a Raid boss, M+ dungeon, PvP mode, or Zone above.|r")
    f.emptyBossHint = emptyBossHint

    local scrollF = CreateFrame("ScrollFrame", nil, listCard)
    scrollF:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, -50)
    scrollF:SetPoint("BOTTOMRIGHT", listCard, "BOTTOMRIGHT", -10, 10)
    scrollF:EnableMouseWheel(true)
    local scrollChild = CreateFrame("Frame", nil, scrollF)
    scrollChild:SetSize(560, 1)
    scrollF:SetScrollChild(scrollChild)

    listCard.track = CreateFrame("Frame", nil, listCard, "BackdropTemplate")
    listCard.track:SetWidth(4)
    listCard.track:SetPoint("TOPRIGHT", listCard, "TOPRIGHT", -10, -50)
    listCard.track:SetPoint("BOTTOMRIGHT", listCard, "BOTTOMRIGHT", -10, 10)
    listCard.track:EnableMouse(true)
    listCard.track:EnableMouseWheel(true)
    listCard.track:SetHitRectInsets(-5, -4, 0, 0)
    SetPixelBackdrop(listCard.track, { 0.043, 0.051, 0.071, 0.90 }, { 0, 0, 0, 0 }, 0)
    listCard.track:Hide()

    listCard.thumb = CreateFrame("Button", nil, listCard.track)
    listCard.thumb:SetWidth(4)
    listCard.thumb:SetHeight(32)
    listCard.thumb:SetPoint("TOP", listCard.track, "TOP", 0, 0)
    listCard.thumb:EnableMouse(true)
    listCard.thumb:SetHitRectInsets(-5, -4, 0, 0)
    listCard.thumb.tex = listCard.thumb:CreateTexture(nil, "OVERLAY")
    listCard.thumb.tex:SetAllPoints()
    listCard.thumb.tex:SetColorTexture(ar, ag, ab, 0.78)
    listCard.thumb:Hide()

    listCard.UpdateScrollBar = function()
        local r, g, b = GetActiveAccentRGB()
        if listCard.thumb.isDragging then
            listCard.thumb.tex:SetColorTexture(r, g, b, 1.0)
        elseif listCard.thumb.isHovered then
            listCard.thumb.tex:SetColorTexture(r, g, b, 0.92)
        else
            listCard.thumb.tex:SetColorTexture(r, g, b, 0.78)
        end
        local visH = scrollF:GetHeight() or 0
        local totalH = scrollChild:GetHeight() or 0
        local rawCardW = listCard:GetWidth()
        local cardW = (rawCardW and rawCardW > 100) and rawCardW or (f._rightW or 522)
        local maxS = math.max(0, totalH - visH)
        scrollF:ClearAllPoints()
        scrollF:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, -50)
        if maxS <= 1 or visH <= 1 then
            scrollF:SetPoint("BOTTOMRIGHT", listCard, "BOTTOMRIGHT", -10, 10)
            scrollChild:SetWidth(math.max(100, cardW - 22))
            listCard.track:Hide()
            listCard.thumb:Hide()
            scrollF:SetVerticalScroll(0)
        else
            scrollF:SetPoint("BOTTOMRIGHT", listCard, "BOTTOMRIGHT", -18, 10)
            scrollChild:SetWidth(math.max(100, cardW - 30))
            listCard.track:Show()
            listCard.thumb:Show()
            local trackH = listCard.track:GetHeight()
            if not trackH or trackH <= 1 then trackH = visH end
            local cur = math.max(0, math.min(maxS, scrollF:GetVerticalScroll() or 0))
            local thumbH = math.max(22, math.floor(trackH * math.min(1, visH / totalH) + 0.5))
            local travel = math.max(1, trackH - thumbH)
            listCard.thumb:SetHeight(thumbH)
            listCard.thumb:ClearAllPoints()
            listCard.thumb:SetPoint("TOP", listCard.track, "TOP", 0, -math.floor((cur / maxS) * travel + 0.5))
        end
        local cw = scrollChild:GetWidth()
        for _, rw in ipairs(f.bossRows or {}) do
            if rw:IsShown() then rw:SetWidth(cw) end
        end
    end

    listCard.ScrollFromCursor = function()
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            listCard.thumb.isDragging = false
            listCard.thumb:SetScript("OnUpdate", nil)
            listCard.track:SetScript("OnUpdate", nil)
            listCard.UpdateScrollBar()
            return
        end
        local visH = scrollF:GetHeight() or 0
        local totalH = scrollChild:GetHeight() or 0
        local maxS = math.max(0, totalH - visH)
        local trackH = listCard.track:GetHeight()
        if not trackH or trackH <= 1 then trackH = visH end
        if maxS <= 1 or trackH <= 1 then return end
        local tTop = listCard.track:GetTop()
        local eff = listCard.track:GetEffectiveScale() or 1
        if not tTop or eff <= 0 or not GetCursorPosition then return end
        local _, cy = GetCursorPosition()
        local relY = math.max(0, math.min(trackH, tTop - (cy / eff)))
        local thumbH = listCard.thumb:GetHeight() or 22
        local travel = math.max(1, trackH - thumbH)
        local ratio = math.max(0, math.min(1, (relY - (thumbH * 0.5)) / travel))
        scrollF:SetVerticalScroll(ratio * maxS)
        listCard.UpdateScrollBar()
    end

    listCard.thumb:SetScript("OnEnter", function(s) s.isHovered = true; listCard.UpdateScrollBar() end)
    listCard.thumb:SetScript("OnLeave", function(s) s.isHovered = false; listCard.UpdateScrollBar() end)
    listCard.thumb:SetScript("OnMouseDown", function(s, btn)
        if btn ~= "LeftButton" then return end
        s.isDragging = true
        s:SetScript("OnUpdate", listCard.ScrollFromCursor)
        listCard.ScrollFromCursor()
    end)
    listCard.thumb:SetScript("OnMouseUp", function(s)
        s.isDragging = false
        s:SetScript("OnUpdate", nil)
        listCard.UpdateScrollBar()
    end)
    listCard.track:SetScript("OnMouseDown", function(s, btn)
        if btn ~= "LeftButton" then return end
        listCard.thumb.isDragging = true
        s:SetScript("OnUpdate", listCard.ScrollFromCursor)
        listCard.ScrollFromCursor()
    end)
    listCard.track:SetScript("OnMouseUp", function(s)
        listCard.thumb.isDragging = false
        s:SetScript("OnUpdate", nil)
        listCard.UpdateScrollBar()
    end)

    local function HandleListWheel(delta)
        local visH = scrollF:GetHeight() or 0
        local maxS = math.max(0, (scrollChild:GetHeight() or 0) - visH)
        if maxS <= 1 then
            scrollF:SetVerticalScroll(0)
        else
            scrollF:SetVerticalScroll(math.max(0, math.min(maxS, (scrollF:GetVerticalScroll() or 0) - (delta * 27))))
        end
        listCard.UpdateScrollBar()
    end
    scrollF:SetScript("OnMouseWheel", function(_, delta) HandleListWheel(delta) end)
    listCard.track:SetScript("OnMouseWheel", function(_, delta) HandleListWheel(delta) end)
    scrollF:SetScript("OnSizeChanged", function() listCard.UpdateScrollBar() end)
    scrollF:HookScript("OnHide", function()
        listCard.thumb.isDragging = false
        listCard.thumb.isHovered = false
        listCard.thumb:SetScript("OnUpdate", nil)
        listCard.track:SetScript("OnUpdate", nil)
    end)

    if f.filterBuildBtn then
        f.filterBuildBtn:SetScript("OnClick", function()
            f.state.reminderFilter = "BUILD"
            f:RefreshBossList()
        end)
    end
    if f.filterAllBtn then
        f.filterAllBtn:SetScript("OnClick", function()
            f.state.reminderFilter = "ALL"
            f:RefreshBossList()
        end)
    end

    f.bossRows = {}
    function f:RefreshBossList()
        local st = self.state
        local curBuild = self:UpdatePickBtns()
        if self.UpdateTopLoadoutTriggerBadge then self:UpdateTopLoadoutTriggerBadge() end
        local filterMode = st.reminderFilter or "BUILD"
        local onBuild = (filterMode == "BUILD")
        local curBuildLow = (type(curBuild) == "table" and type(curBuild.name) == "string" and curBuild.name ~= "") and curBuild.name:lower() or nil
        local r, g, b = GetActiveAccentRGB()

        if self.filterBuildBtn then
            SetPixelBackdrop(self.filterBuildBtn, onBuild and { r * 0.42, g * 0.42, b * 0.42, 1.00 } or COLORS.BgElevated, onBuild and { r, g, b, 0.95 } or { 1, 1, 1, 0.05 }, 1)
            if self.filterBuildBtn.txt then self.filterBuildBtn.txt:SetTextColor(onBuild and 1 or 0.65, onBuild and 1 or 0.72, onBuild and 1 or 0.82, 1) end
        end
        if self.filterAllBtn then
            SetPixelBackdrop(self.filterAllBtn, (not onBuild) and { r * 0.42, g * 0.42, b * 0.42, 1.00 } or COLORS.BgElevated, (not onBuild) and { r, g, b, 0.95 } or { 1, 1, 1, 0.05 }, 1)
            if self.filterAllBtn.txt then self.filterAllBtn.txt:SetTextColor((not onBuild) and 1 or 0.65, (not onBuild) and 1 or 0.72, (not onBuild) and 1 or 0.82, 1) end
        end

        if self.listHdr and self.listFilterBar then
            if self.listHdr.textArea then
                self.listHdr.textArea:ClearAllPoints()
                self.listHdr.textArea:SetPoint("TOPLEFT", self.listHdr, "TOPLEFT", 11, -2)
                self.listHdr.textArea:SetPoint("BOTTOMLEFT", self.listHdr, "BOTTOMLEFT", 11, 2)
                self.listHdr.textArea:SetPoint("RIGHT", self.listFilterBar, "LEFT", -10, 0)
            end
            if self.listHdr.subFS then
                if onBuild then
                    if type(curBuild) == "table" then
                        self.listHdr.subFS:SetText("|cFF94A3B8Showing reminders for |r" .. DynamicTalent:FormatTalentBadge(curBuild) .. " |cFFFFFFFF" .. tostring(curBuild.name or "Loadout") .. "|r")
                    else
                        self.listHdr.subFS:SetText("|cFF94A3B8New build -- auto-saves on bind, or switch to All|r")
                    end
                else
                    self.listHdr.subFS:SetText("|cFF94A3B8Showing all builds (specific binds override defaults)|r")
                end
            end
        end

        for _, rFrame in ipairs(self.bossRows) do rFrame:Hide() end
        local specID = DynamicTalent:GetActiveSpecID()
        local items = {}

        local function RuleMatchesFilter(v)
            if type(v) ~= "table" then return false end
            if not onBuild then return true end
            if type(curBuild) ~= "table" then return false end
            return DoesRuleMatchEntry(v, curBuild)
        end

        local function FormatRuleTarget(v, defGroup)
            local badge = DynamicTalent:FormatTalentBadge({
                loadoutID    = v.loadoutID,
                group        = v.group or defGroup or "Custom",
                importString = v.importString,
                loadoutName  = v.loadoutName,
                heroAcronym  = v.heroAcronym,
            })
            return badge .. " |cFF10B981" .. tostring(v.loadoutName or "Loadout") .. "|r"
        end

        local bossMap = (specID and DynamicTalent.db and DynamicTalent.db.talentBossMap and DynamicTalent.db.talentBossMap[specID]) or {}
        for k, v in pairs(bossMap) do
            if RuleMatchesFilter(v) then
                local diffTxt = DynamicTalent:FormatDifficultySummary(v.difficulties)
                if v.isAllRaid == true then
                    table.insert(items, {
                        sortKey = "2:1:" .. tostring(k),
                        text = string.format("|cFFF87171[All Raids - %s]|r  ->  %s", diffTxt, FormatRuleTarget(v, "Raid")),
                        onDelete = function() bossMap[k] = nil; DynamicTalent:SyncTalentBindsUI() end,
                    })
                else
                    local rShort, bOrder = v.raidShort, v.bossOrder
                    if (not rShort or not bOrder) and #st.ejRaids > 0 then
                        local _, _, rObj, bObj = DynamicTalent:MatchBossTargetName(v.bossName, st.ejRaids)
                        if rObj then rShort = rShort or rObj.short or rObj.name end
                        if bObj then bOrder = bOrder or bObj.order end
                    end
                    local tagStr, sKey
                    if rShort and bOrder then
                        tagStr = string.format("[%s #%d %s - %s]", tostring(rShort), tonumber(bOrder), tostring(v.bossName or k), diffTxt)
                        sKey = string.format("1:1:%s:%02d:%s:%s", tostring(rShort):lower(), tonumber(bOrder) or 99, tostring(v.bossName or k):lower(), tostring(k))
                    else
                        tagStr = string.format("[Target: %s - %s]", tostring(v.bossName or k), diffTxt)
                        sKey = "1:2:" .. tostring(v.bossName or k):lower() .. ":" .. tostring(k)
                    end
                    table.insert(items, {
                        sortKey = sKey,
                        text = string.format("|cFFFBBF24%s|r  ->  %s", tagStr, FormatRuleTarget(v, "Raid")),
                        onDelete = function() bossMap[k] = nil; DynamicTalent:SyncTalentBindsUI() end,
                    })
                end
            end
        end

        local dungMap = (specID and DynamicTalent.db and DynamicTalent.db.talentDungeonMap and DynamicTalent.db.talentDungeonMap[specID]) or {}
        for k, v in pairs(dungMap) do
            if RuleMatchesFilter(v) then
                local kt = v.keyTier or "ANY"
                local tierTxt = (kt == "HIGH" and "+10+") or (kt == "LOW" and "+2-9") or "Any Key"
                local isAllRule = (v.isAllMPlus == true) or (tostring(v.dungeonName or ""):lower() == "all m+ dungeons")
                if isAllRule then
                    table.insert(items, {
                        sortKey = "2:2:" .. kt,
                        text = string.format("|cFF38BDF8[All M+ - %s]|r  ->  %s", tierTxt, FormatRuleTarget(v, "M+")),
                        onDelete = function() dungMap[k] = nil; DynamicTalent:SyncTalentBindsUI() end,
                    })
                else
                    table.insert(items, {
                        sortKey = string.format("1:3:%s:%s", tostring(v.dungeonName or k):lower(), kt),
                        text = string.format("|cFF38BDF8[%s - %s]|r  ->  %s", tostring(v.dungeonName or k), tierTxt, FormatRuleTarget(v, "M+")),
                        onDelete = function() dungMap[k] = nil; DynamicTalent:SyncTalentBindsUI() end,
                    })
                end
            end
        end

        local pvpMap = (specID and DynamicTalent.db and DynamicTalent.db.talentPvPMap and DynamicTalent.db.talentPvPMap[specID]) or {}
        local zoneMap = (specID and DynamicTalent.db and DynamicTalent.db.talentZoneMap and DynamicTalent.db.talentZoneMap[specID]) or {}
        for _, pk in ipairs({ "arena", "bg", "warmode" }) do
            local pv = pvpMap[pk]
            if RuleMatchesFilter(pv) then
                table.insert(items, {
                    sortKey = "1:4:" .. pk,
                    text = string.format("|cFFA855F7[PvP: %s]|r  ->  %s", PVP_MODE_LABELS[pk] or pk, FormatRuleTarget(pv, "PvP")),
                    onDelete = function() pvpMap[pk] = nil; DynamicTalent:SyncTalentBindsUI() end,
                })
            end
        end
        if RuleMatchesFilter(pvpMap.all) then
            table.insert(items, {
                sortKey = "2:4:pvp",
                text = string.format("|cFFF472B6[All PvP]|r  ->  %s", FormatRuleTarget(pvpMap.all, "PvP")),
                onDelete = function()
                    pvpMap.all = nil
                    if zoneMap then zoneMap.pvp = nil end
                    DynamicTalent:SyncTalentBindsUI()
                end,
            })
        elseif RuleMatchesFilter(zoneMap.pvp) then
            table.insert(items, {
                sortKey = "2:4:pvp",
                text = string.format("|cFFF472B6[All PvP]|r  ->  %s", FormatRuleTarget(zoneMap.pvp, "PvP")),
                onDelete = function() zoneMap.pvp = nil; DynamicTalent:SyncTalentBindsUI() end,
            })
        end

        if RuleMatchesFilter(zoneMap.delves) then
            table.insert(items, {
                sortKey = "2:3:delves",
                text = string.format("|cFFA78BFA[Zone: Delves]|r  ->  %s", FormatRuleTarget(zoneMap.delves, "Delves")),
                onDelete = function() zoneMap.delves = nil; DynamicTalent:SyncTalentBindsUI() end,
            })
        end
        if RuleMatchesFilter(zoneMap.outdoor) then
            table.insert(items, {
                sortKey = "2:5:outdoor",
                text = string.format("|cFF34D399[Zone: Outdoor]|r  ->  %s", FormatRuleTarget(zoneMap.outdoor, "Custom")),
                onDelete = function() zoneMap.outdoor = nil; DynamicTalent:SyncTalentBindsUI() end,
            })
        end
        if RuleMatchesFilter(zoneMap.all) then
            table.insert(items, {
                sortKey = "2:9:all",
                text = string.format("|cFF10B981[All Content]|r  ->  %s", FormatRuleTarget(zoneMap.all, "Custom")),
                onDelete = function() zoneMap.all = nil; DynamicTalent:SyncTalentBindsUI() end,
            })
        end

        table.sort(items, function(a, c) return a.sortKey < c.sortKey end)
        if self.emptyBossHint then
            if onBuild and type(curBuild) == "table" then
                self.emptyBossHint:SetText("|cFF64748BNo binds set for |r|cFFE2E8F0" .. tostring(curBuild.name or "this build") .. "|r|cFF64748B yet. Binding is optional -- pick a Raid boss, M+ dungeon, PvP mode, or Zone above.|r")
            elseif onBuild then
                self.emptyBossHint:SetText("|cFF64748BCreating a new build -- fill in Build Details on the left and click a + Bind button above to auto-save and bind, or switch to All to view every rule.|r")
            else
                self.emptyBossHint:SetText("|cFF64748BNo binds set yet. Binding is optional -- pick a loadout above and choose a Raid boss, M+ dungeon, PvP mode, or Zone.|r")
            end
            self.emptyBossHint:SetShown(#items == 0)
        end

        local rowWidth = math.max(100, scrollChild:GetWidth() or ((self._rightW or 522) - 22))
        for i, it in ipairs(items) do
            local row = self.bossRows[i]
            if not row then
                row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
                row:SetHeight(24)
                SetPixelBackdrop(row, COLORS.BgElevated, COLORS.BorderSubtle, 1)
                row.fs = CreateText(row, "OVERLAY", "GameFontHighlightSmall")
                row.fs:SetPoint("LEFT", row, "LEFT", 8, 0)
                row.fs:SetPoint("RIGHT", row, "RIGHT", -28, 0)
                row.fs:SetJustifyH("LEFT")
                row.fs:SetWordWrap(false)
                DynamicTalent.AttachTruncationTooltip(row.fs, row)
                row.del = CreateFrame("Button", nil, row)
                row.del:SetSize(20, 20)
                row.del:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                row.del.txt = CreateText(row.del, "OVERLAY", "GameFontHighlightSmall")
                row.del.txt:SetPoint("CENTER")
                row.del.txt:SetText("|cFFF43F5Ex|r")
                self.bossRows[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((i - 1) * 27))
            row:SetWidth(rowWidth)
            row.fs:SetText(it.text)
            row.del:SetScript("OnClick", it.onDelete)
            row:Show()
        end
        scrollChild:SetHeight(math.max(1, #items * 27))
        scrollF:SetVerticalScroll(0)
        listCard.UpdateScrollBar()
        if self.RefreshRaidGrid then self:RefreshRaidGrid() end
        if self.RefreshPortalGrid then self:RefreshPortalGrid() end
        if self.RefreshPvPTiles then self:RefreshPvPTiles() end
        if self.RefreshZonePills then self:RefreshZonePills() end
    end

    function f:UpdateResponsiveLayout()
        if self._inLayoutUpdate then return end
        self._inLayoutUpdate = true
        local rawW = self:GetWidth() or (self._isModal and 880 or 780)
        local isStacked = (not self._isModal) and (rawW < 720)
        local fw = self._isModal and math.max(800, math.min(1280, rawW)) or math.max(460, rawW)
        local cw = self._isModal and math.max(772, fw - 28) or fw
        local leftW, rightW
        if isStacked then
            leftW = cw
            rightW = cw
        else
            leftW = self._isModal
                and math.max(300, math.min(350, math.floor((cw * 0.375) + 0.5)))
                or math.max(256, math.min(336, math.floor((cw * 0.36) + 0.5)))
            rightW = math.max(400, cw - leftW - 10)
        end
        local leftInnerW = math.max(220, leftW - 24)
        local rightInnerW = math.max(360, rightW - 24)
        self._rightW = rightW
        self._rightInnerW = rightInnerW

        local qsH = (self.quickStartCard and self.quickStartCard:IsShown()) and (80 + 8) or 0
        local renH = (self.renameLegacyBtn and self.renameLegacyBtn:IsShown()) and (26 + 8) or 0
        local leftBottomY = qsH + 104 + 8 + 166 + renH
        p1:ClearAllPoints()
        p1:SetPoint("TOPLEFT", f.topLoadoutBar, "BOTTOMLEFT", 0, -8)
        p1:SetWidth(leftW)
        if not isStacked and not self._isModal then
            p1:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        elseif self._isModal then
            p1:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 18)
        else
            p1:SetHeight(leftBottomY)
        end

        p2:ClearAllPoints()
        if isStacked then
            p2:SetPoint("TOPLEFT", p1, "BOTTOMLEFT", 0, -10)
            p2:SetPoint("TOPRIGHT", f.topLoadoutBar, "BOTTOMRIGHT", 0, -(leftBottomY + 18))
            p2:SetHeight(420)
        else
            p2:SetPoint("TOPLEFT", p1, "TOPRIGHT", 10, 0)
            p2:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -padX, self._isModal and 18 or 0)
        end

        if self.qsSaveBtn and self.qsImportBtn then
            local qsSaveW = math.max(114, math.floor((leftInnerW - 6) * 0.42))
            local qsImpW = math.max(100, leftInnerW - 6 - qsSaveW)
            self.qsSaveBtn:SetWidth(qsSaveW)
            self.qsImportBtn:SetWidth(qsImpW)
            if self.qsImportBtn.txt then
                self.qsImportBtn.txt:SetText((qsImpW < 164) and "|cFF34D399Import Blizzard|r" or "|cFF34D399Import Blizzard Loadouts|r")
            end
        end

        if self.grpBtns and #self.grpBtns > 0 then
            local weights = { 46, 36, 62, 42, 64 }
            local totalWt = 250
            local availCatW = math.max(200, leftInnerW - ((#self.grpBtns - 1) * 3))
            local xOff = 0
            local usedW = 0
            for idx, gb in ipairs(self.grpBtns) do
                local bw
                if idx == #self.grpBtns then
                    bw = math.max(44, availCatW - usedW)
                else
                    bw = math.max(32, math.floor((availCatW * (weights[idx] or 48) / totalWt) + 0.5))
                    usedW = usedW + bw
                end
                gb:SetSize(bw, 24)
                gb:ClearAllPoints()
                gb:SetPoint("TOPLEFT", c1, "TOPLEFT", 12 + xOff, -73)
                xOff = xOff + bw + 3
            end
        end

        if self.useCurBtn and self.clearStrBtn and self.copyStrBtn then
            local clearW = 54
            local copyW = 82
            local useW = math.max(76, leftInnerW - 8 - clearW - copyW)
            self.useCurBtn:SetWidth(useW)
            self.clearStrBtn:SetWidth(clearW)
            self.copyStrBtn:SetWidth(copyW)
        end

        local isEdit = (type(self.editingEntry) == "table")
        if self.saveImpBtn then
            if isEdit and self.cancelEditBtn and self.cancelEditBtn:IsShown() then
                local revW = math.floor((leftInnerW - 6) * 0.34)
                self.cancelEditBtn:SetWidth(revW)
                self.saveImpBtn:SetWidth(math.max(110, leftInnerW - 6 - revW))
            elseif (not isEdit) and self.saveAndNewBtn and self.saveAndNewBtn:IsShown() then
                local snW = math.floor((leftInnerW - 6) * 0.44)
                self.saveAndNewBtn:SetWidth(snW)
                self.saveImpBtn:SetWidth(math.max(110, leftInnerW - 6 - snW))
            else
                self.saveImpBtn:SetWidth(leftInnerW)
            end
        end

        local sw = math.floor((rightW - 20) / 4)
        modeRaidBtn:SetWidth(sw)
        modeMPlusBtn:SetWidth(sw)
        modePvPBtn:SetWidth(sw)
        modeZoneBtn:SetWidth(math.max(96, rightW - 20 - (sw * 3)))

        local st = self.state
        if st and st.subMode == "RAID" and self.RefreshRaidGrid then
            self:RefreshRaidGrid()
        elseif st and st.subMode == "MPLUS" and self.RefreshPortalGrid then
            self:RefreshPortalGrid()
        elseif st and st.subMode == "PVP" and self.RefreshPvPTiles then
            self:RefreshPvPTiles()
        elseif st and st.subMode == "ZONE" and self.RefreshZonePills then
            self:RefreshZonePills()
        end
        if self.listCard and self.listCard.UpdateScrollBar then
            self.listCard.UpdateScrollBar()
        end
        if self._onResponsiveHeightChange then
            self._onResponsiveHeightChange(isStacked and (leftBottomY + 480) or 480)
        end
        self._inLayoutUpdate = false
    end

    function f:RefreshTab2View()
        local st = self.state
        local mode = (st and st.subMode) or "RAID"
        local r, g, b = GetActiveAccentRGB()
        local isRaid  = (mode == "RAID")
        local isMPlus = (mode == "MPLUS")
        local isPvP   = (mode == "PVP")
        local isZone  = (mode == "ZONE")
        SetPixelBackdrop(modeRaidBtn,  isRaid  and { r * 0.42, g * 0.42, b * 0.42, 1.00 } or COLORS.BgElevated, isRaid  and { r, g, b, 0.95 } or COLORS.BorderSubtle, 1)
        SetPixelBackdrop(modeMPlusBtn, isMPlus and { r * 0.42, g * 0.42, b * 0.42, 1.00 } or COLORS.BgElevated, isMPlus and { r, g, b, 0.95 } or COLORS.BorderSubtle, 1)
        SetPixelBackdrop(modePvPBtn,   isPvP   and { r * 0.42, g * 0.42, b * 0.42, 1.00 } or COLORS.BgElevated, isPvP   and { r, g, b, 0.95 } or COLORS.BorderSubtle, 1)
        SetPixelBackdrop(modeZoneBtn,  isZone  and { r * 0.42, g * 0.42, b * 0.42, 1.00 } or COLORS.BgElevated, isZone  and { r, g, b, 0.95 } or COLORS.BorderSubtle, 1)
        bHdr.bar:SetColorTexture(r, g, b, 0.95)
        bHdr.line:SetColorTexture(r, g, b, 0.35)
        listHdr.bar:SetColorTexture(r, g, b, 0.95)
        listHdr.line:SetColorTexture(r, g, b, 0.35)
        SetPixelBackdrop(raidBindBtn,  { r * 0.42, g * 0.42, b * 0.42, 1.00 }, { r, g, b, 0.95 }, 1)
        SetPixelBackdrop(mplusBindBtn, { r * 0.42, g * 0.42, b * 0.42, 1.00 }, { r, g, b, 0.95 }, 1)
        SetPixelBackdrop(pvpBindBtn,   { r * 0.42, g * 0.42, b * 0.42, 1.00 }, { r, g, b, 0.95 }, 1)
        SetPixelBackdrop(zoneBindBtn,  { r * 0.42, g * 0.42, b * 0.42, 1.00 }, { r, g, b, 0.95 }, 1)
        if isRaid then
            bHdr.titleFS:SetText("|cFFFFFFFFRAID BOSS TALENT BINDS|r")
            bHdr.subFS:SetText("|cFF94A3B8Pick a Season 2 raid, boss (or All Raids) and difficulties|r")
        elseif isMPlus then
            bHdr.titleFS:SetText("|cFFFFFFFFMYTHIC+ TALENT BINDS|r")
            bHdr.subFS:SetText("|cFF94A3B8Pick season dungeons (or All M+) and key tier|r")
        elseif isPvP then
            bHdr.titleFS:SetText("|cFFFFFFFFPVP TALENT BINDS|r")
            bHdr.subFS:SetText("|cFF94A3B8Bind builds to Arena, Battlegrounds, War Mode, or All PvP|r")
        else
            bHdr.titleFS:SetText("|cFFFFFFFFZONE & ALL CONTENT DEFAULTS|r")
            bHdr.subFS:SetText("|cFF94A3B8Set fallback builds when no specific bind matches|r")
        end

        bCard:SetHeight(isRaid and 234 or 152)
        raidGrp:SetShown(isRaid)
        mplusGrp:SetShown(isMPlus)
        pvpGrp:SetShown(isPvP)
        zoneGrp:SetShown(isZone)
        if isRaid then
            self:RefreshRaidGrid()
        elseif isMPlus then
            self:RefreshPortalGrid()
        elseif isPvP then
            self:RefreshPvPTiles()
        else
            self:RefreshZonePills()
        end
        self:RefreshBossList()
        if listCard and listCard.UpdateScrollBar then
            listCard.UpdateScrollBar()
        end
    end

    function f:SelectSubMode(mode)
        self.state.subMode = mode or "RAID"
        self:RefreshTab2View()
    end
    modeRaidBtn:SetScript("OnClick",  function() f:SelectSubMode("RAID") end)
    modeMPlusBtn:SetScript("OnClick", function() f:SelectSubMode("MPLUS") end)
    modePvPBtn:SetScript("OnClick",   function() f:SelectSubMode("PVP") end)
    modeZoneBtn:SetScript("OnClick",  function() f:SelectSubMode("ZONE") end)

    function f:SelectTab(tabNum)
        self.activeTab = tabNum or 1
        CloseModalDropdown()
        if self.renameLegacyBtn then
            self.renameLegacyBtn:SetShown(DynamicTalent:HasLegacyTLMSlot())
        end
        if self.editingEntry ~= self:GetSelectedLoadout() then
            self:LoadEditorEntry(self:GetSelectedLoadout(), (self.activeTab ~= 1))
        end
        if self.RefreshQuickStartStrip then self:RefreshQuickStartStrip() end
        self:RefreshTab2View()
        self:UpdateResponsiveLayout()
        if self:IsShown() and self.activeTab == 1 and self.nameEB and self._isModal then
            self.nameEB:SetFocus()
            self.nameEB:HighlightText()
        elseif self.nameEB and self.nameEB.ClearFocus then
            self.nameEB:ClearFocus()
        end
        if self:IsShown() and DynamicTalent.RefreshTalentDock and C_Timer and C_Timer.After then
            C_Timer.After(0, function() DynamicTalent:RefreshTalentDock() end)
        end
    end

    f:HookScript("OnSizeChanged", function(s)
        if s.UpdateResponsiveLayout then s:UpdateResponsiveLayout() end
    end)

    f.modeRaidBtn  = modeRaidBtn
    f.modeMPlusBtn = modeMPlusBtn
    f.modePvPBtn   = modePvPBtn
    f.modeZoneBtn  = modeZoneBtn
    f.raidBindBtn  = raidBindBtn
    f.mplusBindBtn = mplusBindBtn
    f.pvpBindBtn   = pvpBindBtn
    f.zoneBindBtn  = zoneBindBtn
    f.diffBtns     = diffBtns
    f.tmDrop       = tmDrop
    return f
end

function DynamicTalent:OpenTalentManagerModal(initialTab, targetEntry)
    if not self.db then self:InitDB() end
    local ar, ag, ab, accentHex = GetActiveAccentRGB()
    local MODAL_BG = { 0.035, 0.039, 0.051, 1.00 }
    local HDR_BG   = { 0.016, 0.020, 0.024, 1.00 }

    local function ResolveTalentMgrModalSize(db)
        local sz = (db and db.talentMgrModalSize) or {}
        local rawW = tonumber(sz.w)
        local rawH = tonumber(sz.h)
        local w, h
        if not rawW or rawW < 800 then
            w = 880
            h = math.max(580, math.min(860, rawH or 580))
            if db then db.talentMgrModalSize = { w = w, h = h } end
        else
            w = math.max(800, math.min(1280, math.floor(rawW + 0.5)))
            h = math.max(520, math.min(860, math.floor((rawH or 580) + 0.5)))
        end
        return w, h
    end

    if not talentMgrModal then
        local initW, initH = ResolveTalentMgrModalSize(self.db)
        local f = CreateFrame("Frame", "DynamicTalentManagerModal", UIParent, "BackdropTemplate")
        f:SetSize(initW, initH)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:SetResizable(true)
        if f.SetResizeBounds then
            f:SetResizeBounds(800, 520, 1280, 860)
        elseif f.SetMinResize then
            f:SetMinResize(800, 520)
            if f.SetMaxResize then f:SetMaxResize(1280, 860) end
        end
        f:EnableMouse(true)
        f:SetClampedToScreen(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        SetPixelBackdrop(f, MODAL_BG, { ar, ag, ab, 0.90 }, 1)
        if _G.UISpecialFrames then
            table.insert(_G.UISpecialFrames, "DynamicTalentManagerModal")
        end

        local hdrBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
        hdrBar:SetHeight(36)
        hdrBar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        hdrBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
        SetPixelBackdrop(hdrBar, HDR_BG, { 0, 0, 0, 0 }, 0)
        local hdrDiv = hdrBar:CreateTexture(nil, "ARTWORK")
        hdrDiv:SetHeight(1)
        hdrDiv:SetPoint("BOTTOMLEFT", hdrBar, "BOTTOMLEFT", 0, 0)
        hdrDiv:SetPoint("BOTTOMRIGHT", hdrBar, "BOTTOMRIGHT", 0, 0)
        hdrDiv:SetColorTexture(1, 1, 1, 0.08)

        local hdrTitle = CreateText(hdrBar, "OVERLAY", "GameFontHighlight")
        hdrTitle:SetPoint("LEFT", hdrBar, "LEFT", 14, 0)
        hdrTitle:SetJustifyH("LEFT")
        hdrTitle:SetWordWrap(false)
        hdrTitle:SetText(string.format("|cFFCBD5E1Dynamic|r|cFFFFFFFFTalent|r  |cFF475569|||r  |cFF%sTalent Loadouts Manager|r", accentHex))
        f.hdrTitle = hdrTitle

        local closeBtn = CreateFrame("Button", nil, hdrBar)
        closeBtn:SetSize(36, 35)
        closeBtn:SetPoint("TOPRIGHT", hdrBar, "TOPRIGHT", 0, 0)
        local closeBg = closeBtn:CreateTexture(nil, "BACKGROUND")
        closeBg:SetAllPoints()
        closeBg:SetColorTexture(0.957, 0.247, 0.369, 0.00)
        local xLine1 = closeBtn:CreateTexture(nil, "OVERLAY")
        xLine1:SetSize(12, 1.6); xLine1:SetPoint("CENTER"); xLine1:SetColorTexture(0.75, 0.80, 0.88, 0.90); xLine1:SetRotation(math.rad(45))
        local xLine2 = closeBtn:CreateTexture(nil, "OVERLAY")
        xLine2:SetSize(12, 1.6); xLine2:SetPoint("CENTER"); xLine2:SetColorTexture(0.75, 0.80, 0.88, 0.90); xLine2:SetRotation(math.rad(-45))
        closeBtn:SetScript("OnEnter", function() closeBg:SetColorTexture(0.957, 0.247, 0.369, 0.22); xLine1:SetColorTexture(1, 1, 1, 1); xLine2:SetColorTexture(1, 1, 1, 1) end)
        closeBtn:SetScript("OnLeave", function() closeBg:SetColorTexture(0.957, 0.247, 0.369, 0.00); xLine1:SetColorTexture(0.75, 0.80, 0.88, 0.90); xLine2:SetColorTexture(0.75, 0.80, 0.88, 0.90) end)
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        local helpBtn = CreateFrame("Button", nil, hdrBar, "BackdropTemplate")
        helpBtn:SetSize(24, 24)
        helpBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
        SetPixelBackdrop(helpBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
        helpBtn.txt = CreateText(helpBtn, "OVERLAY", "GameFontHighlightSmall")
        helpBtn.txt:SetPoint("CENTER")
        helpBtn.txt:SetText("?")
        helpBtn.txt:SetTextColor(0.84, 0.90, 0.96, 1)
        helpBtn:SetScript("OnEnter", function(s)
            local r, g, b = GetActiveAccentRGB()
            SetPixelBackdrop(s, { r * 0.34, g * 0.34, b * 0.34, 0.98 }, { r, g, b, 0.95 }, 1)
            s.txt:SetTextColor(1, 1, 1, 1)
            if GameTooltip and not (DynamicTalent._quickGuidePopover and DynamicTalent._quickGuidePopover:IsShown()) then
                GameTooltip:SetOwner(s, "ANCHOR_BOTTOMLEFT")
                GameTooltip:AddLine("Quick Guide & Swap Alert Demo", 1, 1, 1)
                GameTooltip:AddLine("View quick tips, priority rules, and test a live swap toast.", 0.88, 0.91, 0.95, true)
                GameTooltip:Show()
            end
        end)
        helpBtn:SetScript("OnLeave", function(s)
            if not s._guideOpen then
                SetPixelBackdrop(s, COLORS.BgElevated, COLORS.BorderSubtle, 1)
                s.txt:SetTextColor(0.84, 0.90, 0.96, 1)
            end
            if GameTooltip then GameTooltip:Hide() end
        end)
        helpBtn:SetScript("OnClick", function(s)
            DynamicTalent:ToggleTalentQuickGuide(s, f)
        end)
        f.helpBtn = helpBtn

        local settingsBtn = CreateFrame("Button", nil, hdrBar, "BackdropTemplate")
        settingsBtn:SetSize(68, 24)
        settingsBtn:SetPoint("RIGHT", helpBtn, "LEFT", -6, 0)
        SetPixelBackdrop(settingsBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
        settingsBtn.txt = CreateText(settingsBtn, "OVERLAY", "GameFontHighlightSmall")
        settingsBtn.txt:SetPoint("CENTER")
        settingsBtn.txt:SetText("Settings")
        settingsBtn.txt:SetTextColor(0.84, 0.90, 0.96, 1)
        settingsBtn:SetScript("OnEnter", function(s)
            local r, g, b = GetActiveAccentRGB()
            SetPixelBackdrop(s, { r * 0.34, g * 0.34, b * 0.34, 0.98 }, { r, g, b, 0.95 }, 1)
            s.txt:SetTextColor(1, 1, 1, 1)
            if GameTooltip then
                GameTooltip:SetOwner(s, "ANCHOR_BOTTOMLEFT")
                GameTooltip:AddLine("DynamicTalent Settings", 1, 1, 1)
                GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Open Display, Group Order, Backdrop and Reminder settings.|r", 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        settingsBtn:SetScript("OnLeave", function(s)
            SetPixelBackdrop(s, COLORS.BgElevated, COLORS.BorderSubtle, 1)
            s.txt:SetTextColor(0.84, 0.90, 0.96, 1)
            if GameTooltip then GameTooltip:Hide() end
        end)
        settingsBtn:SetScript("OnClick", function()
            DynamicTalent:CloseTalentQuickGuide()
            DynamicTalent:Open()
        end)
        f.settingsBtn = settingsBtn
        hdrTitle:SetPoint("RIGHT", settingsBtn, "LEFT", -10, 0)

        local resizeGrip = CreateFrame("Button", nil, f)
        resizeGrip:SetSize(14, 14)
        resizeGrip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
        resizeGrip:SetFrameLevel(f:GetFrameLevel() + 12)
        resizeGrip:EnableMouse(true)
        local gripTex = resizeGrip:CreateTexture(nil, "OVERLAY", nil, 5)
        gripTex:SetAllPoints()
        gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        gripTex:SetDesaturated(true)
        gripTex:SetVertexColor(0.55, 0.58, 0.65, 0.75)
        resizeGrip:SetScript("OnEnter", function(s)
            local r, g, b, hex = GetActiveAccentRGB()
            gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
            gripTex:SetDesaturated(false)
            gripTex:SetVertexColor(r, g, b, 0.95)
            if GameTooltip then
                GameTooltip:SetOwner(s, "ANCHOR_TOPLEFT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine("Resize Window", 1, 1, 1)
                GameTooltip:AddLine(string.format("|cFF%sLeft-Click & Drag:|r |cFFE2E8F0Resize Talent Loadouts Manager|r", hex))
                GameTooltip:AddLine(string.format("|cFF%sRight-Click:|r |cFFE2E8F0Reset size to 880x580|r", hex))
                GameTooltip:Show()
            end
        end)
        resizeGrip:SetScript("OnLeave", function()
            gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
            gripTex:SetDesaturated(true)
            gripTex:SetVertexColor(0.55, 0.58, 0.65, 0.75)
            if GameTooltip then GameTooltip:Hide() end
        end)
        resizeGrip:SetScript("OnMouseDown", function(_, mBtn)
            if mBtn == "LeftButton" then
                f:StartSizing("BOTTOMRIGHT")
            elseif mBtn == "RightButton" then
                f:SetSize(880, 580)
                if DynamicTalent.db then
                    DynamicTalent.db.talentMgrModalSize = { w = 880, h = 580 }
                end
                if f.UpdateResponsiveLayout then f:UpdateResponsiveLayout() end
            end
        end)
        resizeGrip:SetScript("OnMouseUp", function()
            f:StopMovingOrSizing()
            if DynamicTalent.db then
                DynamicTalent.db.talentMgrModalSize = {
                    w = math.max(800, math.min(1280, math.floor((f:GetWidth() or 880) + 0.5))),
                    h = math.max(520, math.min(860, math.floor((f:GetHeight() or 580) + 0.5))),
                }
            end
            if f.UpdateResponsiveLayout then f:UpdateResponsiveLayout() end
        end)
        f.resizeGrip = resizeGrip

        PopulateTalentManagerCore(f, true)

        f:HookScript("OnShow", function(s)
            if s.RefreshQuickStartStrip then s:RefreshQuickStartStrip() end
            if s.UpdateResponsiveLayout then s:UpdateResponsiveLayout() end
            if DynamicTalent.RefreshTalentDock and C_Timer and C_Timer.After then
                C_Timer.After(0, function() DynamicTalent:RefreshTalentDock() end)
            end
        end)
        f:HookScript("OnHide", function(s)
            if s.CloseModalDropdown then s.CloseModalDropdown() end
            DynamicTalent:CloseTalentQuickGuide()
            if s.nameEB and s.nameEB.ClearFocus then s.nameEB:ClearFocus() end
            if s.strEB and s.strEB.ClearFocus then s.strEB:ClearFocus() end
            if DynamicTalent.RefreshTalentDock and C_Timer and C_Timer.After then
                C_Timer.After(0, function() DynamicTalent:RefreshTalentDock() end)
            end
        end)

        talentMgrModal = f
        DynamicTalent._talentMgrModal = f
    end

    local openW, openH = ResolveTalentMgrModalSize(self.db)
    talentMgrModal:SetSize(openW, openH)
    SetPixelBackdrop(talentMgrModal, MODAL_BG, { ar, ag, ab, 0.90 }, 1)
    if talentMgrModal.hdrTitle then
        talentMgrModal.hdrTitle:SetText(string.format("|cFFCBD5E1Dynamic|r|cFFFFFFFFTalent|r  |cFF475569|||r  |cFF%sTalent Loadouts Manager|r", accentHex))
    end
    local tabToOpen = initialTab or 1
    if targetEntry ~= nil then
        talentMgrModal:SelectLoadout(targetEntry, (tabToOpen ~= 1))
    elseif tabToOpen == 1 then
        talentMgrModal:SelectLoadout(nil, false)
    else
        local curSel = talentMgrModal:GetSelectedLoadout() or DynamicTalent:GetActiveTalentLibraryEntry()
        talentMgrModal:SelectLoadout(curSel, true)
    end
    talentMgrModal:SelectTab(tabToOpen)
    talentMgrModal:Show()
    if talentMgrModal.UpdateResponsiveLayout then
        talentMgrModal:UpdateResponsiveLayout()
    end
    if tabToOpen == 1 and talentMgrModal.nameEB then
        talentMgrModal.nameEB:SetFocus()
        talentMgrModal.nameEB:HighlightText()
    end
end

-- ============================================================================
-- 11. EMBEDDED SUITE WORKSPACE (/ds -> DynamicTalent, Tab 1 & Tab 2)
-- ============================================================================
-- activeEmbeddedRoot is hoisted above SyncTalentBindsUI.
local standaloneWin = nil

local function CreateSectionBox(parent, yOffset)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    SetPixelBackdrop(box, { 0.055, 0.063, 0.082, 0.96 }, { 1, 1, 1, 0.08 }, 1)
    return box
end

local function CreateSectionHeader(parent, yOffset, title, subtitle, rightButton)
    local _, acc = GetTheme()
    local hdr = CreateFrame("Frame", nil, parent)
    hdr:SetHeight(36)
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    hdr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)

    local vBar = CreateSolidTex(hdr, "ARTWORK", 1, acc.r, acc.g, acc.b, 1.0)
    vBar:SetWidth(3)
    vBar:SetPoint("TOPLEFT", hdr, "TOPLEFT", 0, -1)
    vBar:SetSize(3, 34)

    local hRule = CreateSolidTex(hdr, "ARTWORK", 1, acc.r, acc.g, acc.b, 0.35)
    hRule:SetHeight(1)
    hRule:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 0, 0)
    hRule:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)

    local textWrap = CreateFrame("Frame", nil, hdr)
    textWrap:SetPoint("TOPLEFT", hdr, "TOPLEFT", 10, -3)
    textWrap:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 10, 3)
    if rightButton then
        textWrap:SetPoint("RIGHT", rightButton, "LEFT", -10, 0)
    else
        textWrap:SetPoint("RIGHT", hdr, "RIGHT", -4, 0)
    end

    local tFs = textWrap:CreateFontString(nil, "OVERLAY")
    SetFontSafe(tFs, 11, "")
    tFs:SetPoint("TOPLEFT", textWrap, "TOPLEFT", 0, 0)
    tFs:SetPoint("TOPRIGHT", textWrap, "TOPRIGHT", 0, 0)
    tFs:SetJustifyH("LEFT")
    tFs:SetWordWrap(false)
    tFs:SetTextColor(acc.r, acc.g, acc.b, 1.0)
    tFs:SetText(title)

    local sFs = textWrap:CreateFontString(nil, "OVERLAY")
    SetFontSafe(sFs, 10, "")
    sFs:SetPoint("TOPLEFT", tFs, "BOTTOMLEFT", 0, -2)
    sFs:SetPoint("TOPRIGHT", tFs, "BOTTOMRIGHT", 0, -2)
    sFs:SetJustifyH("LEFT")
    sFs:SetWordWrap(false)
    sFs:SetTextColor(0.639, 0.702, 0.780, 0.95)
    sFs:SetText(subtitle or "")
    DynamicTalent.AttachTruncationTooltip(sFs)

    return hdr, -44
end

local function CreateStyledButton(parent, label, width, height, primary, onClick)
    local surf, acc = GetTheme()
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 110, height or 24)
    local baseBg = primary and { acc.r * 0.42, acc.g * 0.42, acc.b * 0.42, 0.96 } or { 0.078, 0.090, 0.122, 0.96 }
    local baseBd = primary and { acc.r, acc.g, acc.b, 0.95 } or surf.border
    SetPixelBackdrop(btn, baseBg, baseBd, 1)

    local fs = btn:CreateFontString(nil, "OVERLAY")
    SetFontSafe(fs, 10.5, "")
    fs:SetPoint("CENTER")
    fs:SetTextColor(primary and 1 or 0.88, primary and 1 or 0.92, primary and 1 or 0.96, 1)
    fs:SetText(label)
    btn.label = fs

    btn:SetScript("OnEnter", function(s)
        local _, a = GetTheme()
        SetPixelBackdrop(s, { a.r * 0.50, a.g * 0.50, a.b * 0.50, 0.98 }, { a.r, a.g, a.b, 1.0 }, 1)
        fs:SetTextColor(1, 1, 1, 1)
    end)
    btn:SetScript("OnLeave", function(s)
        SetPixelBackdrop(s, baseBg, baseBd, 1)
        fs:SetTextColor(primary and 1 or 0.88, primary and 1 or 0.92, primary and 1 or 0.96, 1)
    end)
    btn:SetScript("OnClick", function()
        if type(onClick) == "function" then onClick(btn) end
    end)
    return btn
end

-- Option 3 Coral-Rose OffBar Segmented Switch Card (Off LEFT 68 / Enabled RIGHT 84 inside 156x26)
local function CreateSegmentedSwitchCard(parent, yOffset, title, desc, getter, setter, extraLeftBtn)
    local surf, _ = GetTheme()
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetHeight(60)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    SetPixelBackdrop(card, surf.card, { 1, 1, 1, 0.06 }, 1)

    local track = CreateFrame("Frame", nil, card, "BackdropTemplate")
    track:SetSize(156, 26)
    track:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    SetPixelBackdrop(track, { 0.043, 0.051, 0.071, 0.98 }, { 1, 1, 1, 0.08 }, 1)

    local leftLimit = track
    if extraLeftBtn then
        extraLeftBtn:SetParent(card)
        extraLeftBtn:ClearAllPoints()
        extraLeftBtn:SetPoint("RIGHT", track, "LEFT", -8, 0)
        leftLimit = extraLeftBtn
    end

    local titleFs = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(titleFs, 11.5, "")
    titleFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -9)
    titleFs:SetPoint("RIGHT", leftLimit, "LEFT", -14, 0)
    titleFs:SetJustifyH("LEFT")
    titleFs:SetWordWrap(false)
    titleFs:SetTextColor(0.95, 0.97, 1.0, 1.0)
    titleFs:SetText(title)

    local descFs = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(descFs, 9.5, "")
    descFs:SetPoint("TOPLEFT", titleFs, "BOTTOMLEFT", 0, -3)
    descFs:SetPoint("RIGHT", leftLimit, "LEFT", -14, 0)
    descFs:SetJustifyH("LEFT")
    descFs:SetJustifyV("TOP")
    descFs:SetWordWrap(true)
    if descFs.SetMaxLines then descFs:SetMaxLines(2) end
    descFs:SetTextColor(0.58, 0.65, 0.74, 0.95)
    descFs:SetText(desc or "")

    local btnOff = CreateFrame("Button", nil, track, "BackdropTemplate")
    btnOff:SetSize(68, 22)
    btnOff:SetPoint("LEFT", track, "LEFT", 1, 0)
    local offFs = btnOff:CreateFontString(nil, "OVERLAY")
    SetFontSafe(offFs, 10.5, "")
    offFs:SetPoint("CENTER")
    offFs:SetText("Off")
    local offBar = CreateSolidTex(btnOff, "OVERLAY", 2, 0.973, 0.443, 0.443, 0.85)
    offBar:SetHeight(1.5)
    offBar:SetPoint("BOTTOMLEFT", btnOff, "BOTTOMLEFT", 1, 1)
    offBar:SetPoint("BOTTOMRIGHT", btnOff, "BOTTOMRIGHT", -1, 1)

    local btnOn = CreateFrame("Button", nil, track, "BackdropTemplate")
    btnOn:SetSize(84, 22)
    btnOn:SetPoint("RIGHT", track, "RIGHT", -1, 0)
    local onFs = btnOn:CreateFontString(nil, "OVERLAY")
    SetFontSafe(onFs, 10.5, "")
    onFs:SetPoint("CENTER")
    onFs:SetText("Enabled")

    local function UpdateVisual()
        local isOn = getter() and true or false
        local _, a = GetTheme()
        if isOn then
            SetPixelBackdrop(btnOff, { 0.043, 0.051, 0.071, 0.0 }, { 0, 0, 0, 0 }, 1)
            offFs:SetTextColor(0.52, 0.58, 0.68, 0.90)
            offBar:Hide()
            SetPixelBackdrop(btnOn, { a.r * 0.42, a.g * 0.42, a.b * 0.42, 0.98 }, { a.r, a.g, a.b, 0.95 }, 1)
            onFs:SetTextColor(1, 1, 1, 1)
        else
            SetPixelBackdrop(btnOff, { 0.118, 0.141, 0.188, 0.98 }, { 0.392, 0.455, 0.545, 0.90 }, 1)
            offFs:SetTextColor(0.886, 0.910, 0.941, 1)
            offBar:Show()
            SetPixelBackdrop(btnOn, { 0.043, 0.051, 0.071, 0.0 }, { 0, 0, 0, 0 }, 1)
            onFs:SetTextColor(0.52, 0.58, 0.68, 0.90)
        end
    end

    btnOff:SetScript("OnClick", function() setter(false); UpdateVisual() end)
    btnOn:SetScript("OnClick", function() setter(true); UpdateVisual() end)
    UpdateVisual()
    return card, -66
end

local function CreatePrecisionSliderCard(parent, yOffset, title, desc, minVal, maxVal, stepVal, getter, setter, formatFunc, isEnabledFn, disabledNote)
    local surf, _ = GetTheme()
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetHeight(60)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    SetPixelBackdrop(card, surf.card, { 1, 1, 1, 0.06 }, 1)

    local holder = CreateFrame("Frame", nil, card)
    holder:SetSize(256, 26)
    holder:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    holder:EnableMouse(true)
    holder:EnableMouseWheel(true)
    holder:SetHitRectInsets(0, 0, -4, -4)

    local titleFs = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(titleFs, 11.5, "")
    titleFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -9)
    titleFs:SetPoint("RIGHT", holder, "LEFT", -14, 0)
    titleFs:SetJustifyH("LEFT")
    titleFs:SetWordWrap(false)
    titleFs:SetTextColor(0.95, 0.97, 1.0, 1.0)
    titleFs:SetText(title)

    local descText = desc or ""
    local disabledText = disabledNote or descText
    local descFs = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(descFs, 9.5, "")
    descFs:SetPoint("TOPLEFT", titleFs, "BOTTOMLEFT", 0, -3)
    descFs:SetPoint("RIGHT", holder, "LEFT", -14, 0)
    descFs:SetJustifyH("LEFT")
    descFs:SetJustifyV("TOP")
    descFs:SetWordWrap(true)
    if descFs.SetMaxLines then descFs:SetMaxLines(2) end
    descFs:SetTextColor(0.58, 0.65, 0.74, 0.95)
    descFs:SetText(descText)

    local valText = holder:CreateFontString(nil, "OVERLAY")
    SetFontSafe(valText, 11, "")
    valText:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
    valText:SetWidth(52)
    valText:SetJustifyH("RIGHT")

    local track = CreateFrame("Frame", nil, holder)
    track:SetPoint("LEFT", holder, "LEFT", 0, 0)
    track:SetPoint("RIGHT", valText, "LEFT", -10, 0)
    track:SetHeight(4)

    local hairline = CreateSolidTex(track, "BACKGROUND", -1, 1, 1, 1, 0.14)
    hairline:SetPoint("TOPLEFT", track, "TOPLEFT", -1, 1)
    hairline:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 1, -1)

    local trackBg = CreateSolidTex(track, "BACKGROUND", 0, 0.035, 0.039, 0.051, 0.98)
    trackBg:SetAllPoints()

    local fill = CreateSolidTex(track, "ARTWORK", 1, 0.220, 0.741, 0.973, 0.85)
    fill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
    fill:SetWidth(1)

    local thumb = CreateSolidTex(track, "OVERLAY", 3, 0.97, 0.98, 1.00, 1.0)
    thumb:SetSize(6, 14)
    if thumb.SetSnapToPixelGrid then
        thumb:SetSnapToPixelGrid(false)
        thumb:SetTexelSnappingBias(0)
    end

    local isDragging = false
    local lastCommittedValue = nil

    local function IsControlEnabled()
        return (type(isEnabledFn) ~= "function") or (isEnabledFn() == true)
    end

    local function SnapValue(v)
        v = math.max(minVal, math.min(maxVal, tonumber(v) or minVal))
        if stepVal and stepVal > 0 then
            v = math.floor((v - minVal) / stepVal + 0.5) * stepVal + minVal
        end
        return math.max(minVal, math.min(maxVal, v))
    end

    local function RefreshSliderVisual(v, rawPct)
        local _, a = GetTheme()
        local enabled = IsControlEnabled()
        if not enabled then isDragging = false end
        holder:SetAlpha(enabled and 1.0 or 0.38)
        titleFs:SetTextColor(enabled and 0.95 or 0.58, enabled and 0.97 or 0.64, enabled and 1.0 or 0.72, 1.0)
        descFs:SetText(enabled and descText or disabledText)
        descFs:SetTextColor(enabled and 0.58 or 0.52, enabled and 0.65 or 0.58, enabled and 0.74 or 0.68, 0.95)
        fill:SetColorTexture(a.r, a.g, a.b, enabled and 0.85 or 0.45)
        valText:SetTextColor(a.r, a.g, a.b, enabled and 1.0 or 0.65)
        if enabled and (isDragging or (holder.IsMouseOver and holder:IsMouseOver())) then
            thumb:SetColorTexture(a.r, a.g, a.b, 1.0)
        else
            thumb:SetColorTexture(0.97, 0.98, 1.00, enabled and 1.0 or 0.65)
        end
        local cur = SnapValue((type(v) == "number" and v) or getter() or minVal)
        local pct = rawPct
        if pct == nil then
            pct = (maxVal > minVal) and ((cur - minVal) / (maxVal - minVal)) or 0
        end
        pct = math.max(0, math.min(1, pct))
        local tw = track:GetWidth()
        if not tw or tw <= 0 then tw = 194 end
        fill:SetWidth(math.max(1, pct * tw))
        thumb:ClearAllPoints()
        thumb:SetPoint("CENTER", track, "LEFT", pct * tw, 0)
        valText:SetText(formatFunc and formatFunc(cur) or tostring(cur))
    end

    local function UpdateFromCursor()
        if not IsControlEnabled() or (isDragging and IsMouseButtonDown and not IsMouseButtonDown("LeftButton")) then
            isDragging = false
            holder:SetScript("OnUpdate", nil)
            RefreshSliderVisual()
            return
        end
        if not GetCursorPosition or not track.GetEffectiveScale then return end
        local scale = track:GetEffectiveScale() or 1
        local cx = GetCursorPosition() / scale
        local left, tw = track:GetLeft(), track:GetWidth()
        if left and tw and tw > 0 then
            local pct = math.max(0, math.min(1, (cx - left) / tw))
            local stepped = SnapValue(minVal + pct * (maxVal - minVal))
            if stepped ~= lastCommittedValue then
                lastCommittedValue = stepped
                setter(stepped)
            end
            RefreshSliderVisual(stepped, pct)
        end
    end

    holder:SetScript("OnMouseDown", function(self, button)
        if not IsControlEnabled() then return end
        if button == "LeftButton" then
            isDragging = true
            UpdateFromCursor()
            self:SetScript("OnUpdate", UpdateFromCursor)
        end
    end)
    holder:SetScript("OnMouseUp", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
        RefreshSliderVisual()
    end)
    holder:SetScript("OnHide", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
    end)
    holder:SetScript("OnEnter", function(self)
        RefreshSliderVisual()
        if GameTooltip then
            local hex = GetAccentHex()
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            if IsControlEnabled() then
                GameTooltip:AddLine(string.format("|cFF%sLeft-Click / Drag:|r |cFFE2E8F0Adjust value|r", hex))
                GameTooltip:AddLine(string.format("|cFF%sMousewheel:|r |cFFE2E8F0Fine-tune by 1 step|r", hex))
            else
                GameTooltip:AddLine(title, 0.72, 0.78, 0.88)
                GameTooltip:AddLine("|cFF94A3B8" .. disabledText .. "|r", 1, 1, 1, true)
            end
            GameTooltip:Show()
        end
    end)
    holder:SetScript("OnLeave", function()
        RefreshSliderVisual()
        if GameTooltip then GameTooltip:Hide() end
    end)
    holder:SetScript("OnMouseWheel", function(_, delta)
        if not IsControlEnabled() then return end
        local cur = getter() or minVal
        local step = stepVal or ((maxVal - minVal) / 10)
        local newVal = SnapValue(cur + (delta > 0 and step or -step))
        lastCommittedValue = newVal
        setter(newVal)
        RefreshSliderVisual(newVal)
    end)
    holder:SetScript("OnShow", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() RefreshSliderVisual() end)
        else
            RefreshSliderVisual()
        end
    end)
    card.RefreshEnabledState = RefreshSliderVisual
    RefreshSliderVisual()
    return card, -66
end

local function CreateBackdropModeCard(parent, yOffset, title, desc, options, getter, setter)
    local surf, _ = GetTheme()
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetHeight(90)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    SetPixelBackdrop(card, surf.card, { 1, 1, 1, 0.06 }, 1)

    local titleFs = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(titleFs, 11.5, "")
    titleFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -9)
    titleFs:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -9)
    titleFs:SetJustifyH("LEFT")
    titleFs:SetWordWrap(false)
    titleFs:SetTextColor(0.95, 0.97, 1.0, 1.0)
    titleFs:SetText(title)

    local descFs = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(descFs, 9.5, "")
    descFs:SetPoint("TOPLEFT", titleFs, "BOTTOMLEFT", 0, -3)
    descFs:SetPoint("TOPRIGHT", titleFs, "BOTTOMRIGHT", 0, -3)
    descFs:SetJustifyH("LEFT")
    descFs:SetJustifyV("TOP")
    descFs:SetWordWrap(true)
    if descFs.SetMaxLines then descFs:SetMaxLines(2) end
    descFs:SetTextColor(0.58, 0.65, 0.74, 0.95)
    descFs:SetText(desc or "")

    local track = CreateFrame("Frame", nil, card, "BackdropTemplate")
    track:SetHeight(26)
    track:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -50)
    track:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -50)
    SetPixelBackdrop(track, { 0.043, 0.051, 0.071, 0.98 }, { 1, 1, 1, 0.08 }, 1)

    local pills = {}
    local function UpdateVisual()
        local cur = getter()
        local _, a = GetTheme()
        for _, p in ipairs(pills) do
            local isAct = (p.opt.value == cur)
            local isHov = (p.isHovered == true)
            if isAct then
                SetPixelBackdrop(p, { a.r * 0.42, a.g * 0.42, a.b * 0.42, 0.98 }, { a.r, a.g, a.b, 0.95 }, 1)
                p.fs:SetTextColor(1, 1, 1, 1)
            elseif isHov then
                SetPixelBackdrop(p, { 0.11, 0.13, 0.17, 0.98 }, { a.r, a.g, a.b, 0.65 }, 1)
                p.fs:SetTextColor(0.92, 0.95, 0.98, 1)
            else
                SetPixelBackdrop(p, { 0.043, 0.051, 0.071, 0.0 }, { 0, 0, 0, 0 }, 1)
                p.fs:SetTextColor(0.64, 0.70, 0.80, 0.95)
            end
        end
    end

    local function ReflowPills()
        local n = #pills
        if n == 0 then return end
        local w = track:GetWidth() or 640
        local gap = 3
        local usable = math.max(120, w - 4 - (gap * (n - 1)))
        local pw = math.floor(usable / n)
        for i, p in ipairs(pills) do
            p:SetHeight(22)
            p:ClearAllPoints()
            if i == 1 then
                p:SetPoint("LEFT", track, "LEFT", 2, 0)
                p:SetWidth(pw)
            elseif i == n then
                p:SetPoint("LEFT", pills[i - 1], "RIGHT", gap, 0)
                p:SetPoint("RIGHT", track, "RIGHT", -2, 0)
            else
                p:SetPoint("LEFT", pills[i - 1], "RIGHT", gap, 0)
                p:SetWidth(pw)
            end
        end
    end

    for _, opt in ipairs(options or {}) do
        local p = CreateFrame("Button", nil, track, "BackdropTemplate")
        p.opt = opt
        p.fs = p:CreateFontString(nil, "OVERLAY")
        SetFontSafe(p.fs, 10.5, "")
        p.fs:SetPoint("CENTER")
        p.fs:SetWordWrap(false)
        p.fs:SetText(opt.label or opt.value)
        p:SetScript("OnEnter", function(s)
            s.isHovered = true
            UpdateVisual()
            if GameTooltip and opt.tip then
                GameTooltip:SetOwner(s, "ANCHOR_TOP")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(opt.label or opt.value, 1, 1, 1)
                GameTooltip:AddLine(opt.tip, 0.88, 0.91, 0.95, true)
                GameTooltip:Show()
            end
        end)
        p:SetScript("OnLeave", function(s)
            s.isHovered = false
            UpdateVisual()
            if GameTooltip then GameTooltip:Hide() end
        end)
        p:SetScript("OnClick", function()
            setter(opt.value)
            UpdateVisual()
        end)
        table.insert(pills, p)
    end
    track:SetScript("OnSizeChanged", ReflowPills)
    track:SetScript("OnShow", ReflowPills)
    ReflowPills()
    UpdateVisual()
    return card, -96
end

local function CreateThreeWayScrollPane(parent, topAnchor, topOffset, rightPad, bottomPad)
    local _, acc = GetTheme()
    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:SetPoint("TOPLEFT", topAnchor, "BOTTOMLEFT", 0, topOffset or -8)
    sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", rightPad or -16, bottomPad or 10)
    sf:EnableMouseWheel(true)

    local sc = CreateFrame("Frame", nil, sf)
    sc:SetSize(700, 100)
    sf:SetScrollChild(sc)

    local track = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    track:SetWidth(4)
    track:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 10, -2)
    track:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 10, 2)
    track:EnableMouse(true)
    track:EnableMouseWheel(true)
    track:SetHitRectInsets(-5, -5, 0, 0)
    SetPixelBackdrop(track, { 0.043, 0.051, 0.071, 0.92 }, { 0, 0, 0, 0 }, 0)
    track:Hide()

    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(4)
    thumb:SetHeight(24)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    thumb:EnableMouse(true)
    thumb:SetHitRectInsets(-5, -5, 0, 0)
    thumb.tex = thumb:CreateTexture(nil, "OVERLAY")
    thumb.tex:SetAllPoints()
    thumb.tex:SetColorTexture(acc.r, acc.g, acc.b, 0.78)
    thumb:Hide()

    local function UpdateScrollBar()
        local _, a = GetTheme()
        if thumb.isDragging then
            thumb.tex:SetColorTexture(a.r, a.g, a.b, 1.0)
        elseif thumb.isHovered then
            thumb.tex:SetColorTexture(a.r, a.g, a.b, 0.92)
        else
            thumb.tex:SetColorTexture(a.r, a.g, a.b, 0.78)
        end
        local visH = sf:GetHeight() or 0
        local totalH = sc:GetHeight() or 0
        local maxS = math.max(0, totalH - visH)
        if maxS <= 1 or visH <= 1 then
            track:Hide()
            thumb:Hide()
            sf:SetVerticalScroll(0)
            return
        end
        track:Show()
        thumb:Show()
        local trackH = track:GetHeight()
        if not trackH or trackH <= 1 then trackH = visH end
        local cur = math.max(0, math.min(maxS, sf:GetVerticalScroll() or 0))
        local thumbH = math.max(24, math.floor(trackH * math.min(1, visH / totalH) + 0.5))
        local travel = math.max(1, trackH - thumbH)
        thumb:SetHeight(thumbH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -math.floor((cur / maxS) * travel + 0.5))
    end

    local function ScrollFromCursor()
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            thumb.isDragging = false
            thumb:SetScript("OnUpdate", nil)
            track:SetScript("OnUpdate", nil)
            UpdateScrollBar()
            return
        end
        local visH = sf:GetHeight() or 0
        local totalH = sc:GetHeight() or 0
        local maxS = math.max(0, totalH - visH)
        local trackH = track:GetHeight()
        if not trackH or trackH <= 1 then trackH = visH end
        if maxS <= 1 or trackH <= 1 then return end
        local tTop = track:GetTop()
        local eff = track:GetEffectiveScale() or 1
        if not tTop or eff <= 0 or not GetCursorPosition then return end
        local _, cy = GetCursorPosition()
        local relY = math.max(0, math.min(trackH, tTop - (cy / eff)))
        local thumbH = thumb:GetHeight() or 24
        local travel = math.max(1, trackH - thumbH)
        local ratio = math.max(0, math.min(1, (relY - (thumbH * 0.5)) / travel))
        sf:SetVerticalScroll(ratio * maxS)
        UpdateScrollBar()
    end

    thumb:SetScript("OnEnter", function(s) s.isHovered = true; UpdateScrollBar() end)
    thumb:SetScript("OnLeave", function(s) s.isHovered = false; UpdateScrollBar() end)
    thumb:SetScript("OnMouseDown", function(s, btn)
        if btn ~= "LeftButton" then return end
        s.isDragging = true
        s:SetScript("OnUpdate", ScrollFromCursor)
        ScrollFromCursor()
    end)
    thumb:SetScript("OnMouseUp", function(s)
        s.isDragging = false
        s:SetScript("OnUpdate", nil)
        UpdateScrollBar()
    end)
    track:SetScript("OnMouseDown", function(s, btn)
        if btn ~= "LeftButton" then return end
        thumb.isDragging = true
        s:SetScript("OnUpdate", ScrollFromCursor)
        ScrollFromCursor()
    end)
    track:SetScript("OnMouseUp", function(s)
        thumb.isDragging = false
        s:SetScript("OnUpdate", nil)
        UpdateScrollBar()
    end)

    local function OnWheel(_, delta)
        local visH = sf:GetHeight() or 0
        local maxS = math.max(0, (sc:GetHeight() or 0) - visH)
        if maxS <= 1 then
            sf:SetVerticalScroll(0)
        else
            sf:SetVerticalScroll(math.max(0, math.min(maxS, (sf:GetVerticalScroll() or 0) - (delta * 34))))
        end
        UpdateScrollBar()
    end
    sf:SetScript("OnMouseWheel", OnWheel)
    track:SetScript("OnMouseWheel", OnWheel)
    thumb:SetScript("OnMouseWheel", OnWheel)
    sf:SetScript("OnSizeChanged", function(s, w)
        if w and w > 40 then sc:SetWidth(w) end
        UpdateScrollBar()
    end)
    sf:HookScript("OnHide", function()
        thumb.isDragging = false
        thumb.isHovered = false
        thumb:SetScript("OnUpdate", nil)
        track:SetScript("OnUpdate", nil)
    end)

    return sf, sc, UpdateScrollBar
end

local GROUP_ROW_META = {
    Raid   = { title = "Raid",          desc = "Raid bosses & All Raids default" },
    ["M+"] = { title = "Mythic+ (M+)",  desc = "Mythic+ dungeons & All M+ default" },
    Delves = { title = "Delves",        desc = "Solo & group Delves" },
    PvP    = { title = "PvP",           desc = "Arena, Battlegrounds & War Mode" },
    Custom = { title = "Custom",        desc = "Outdoor & general builds" },
}

local function EnsureGroupDragGhost()
    if groupDragGhost then return groupDragGhost end
    local ghost = CreateFrame("Frame", "DynamicTalentGroupDragGhost", UIParent, "BackdropTemplate")
    ghost:SetSize(230, 30)
    ghost:SetFrameStrata("TOOLTIP")
    ghost:SetFrameLevel(120)
    ghost:SetClampedToScreen(true)
    ghost:Hide()

    ghost.txt = ghost:CreateFontString(nil, "OVERLAY")
    SetFontSafe(ghost.txt, 10.5, "")
    ghost.txt:SetPoint("CENTER")
    ghost.txt:SetWordWrap(false)

    function ghost:SetGroupVisual(slotIdx, grpKey)
        local _, a = GetTheme()
        SetPixelBackdrop(self, { 0.043, 0.051, 0.071, 0.98 }, { a.r, a.g, a.b, 0.98 }, 1)
        local gHex = TALENT_GROUP_HEX[grpKey] or "94A3B8"
        local meta = GROUP_ROW_META[grpKey] or { title = grpKey }
        self.txt:SetText(string.format("#%d  |cFF%s[%s]|r  |cFFFFFFFF%s|r", tonumber(slotIdx) or 1, gHex, tostring(grpKey), tostring(meta.title or grpKey)))
        local tw = (self.txt.GetStringWidth and self.txt:GetStringWidth()) or 140
        self:SetWidth(math.max(180, math.min(340, tw + 28)))
    end

    groupDragGhost = ghost
    return ghost
end

local function RenderTalentEmbedded(parent)
    if not parent then return end
    if activeEmbeddedRoot and activeEmbeddedRoot:GetParent() == parent then
        activeEmbeddedRoot:Hide()
        activeEmbeddedRoot:SetParent(nil)
    end
    if groupDragGhost then groupDragGhost:Hide() end

    local db = EnsureDB()
    db.activeSubTab = 1
    local _, acc = GetTheme()
    local root = CreateFrame("Frame", nil, parent)
    root:SetAllPoints(parent)
    activeEmbeddedRoot = root

    -- Top Action & Status Strip (#0B0D12)
    local strip = CreateFrame("Frame", nil, root, "BackdropTemplate")
    strip:SetHeight(52)
    strip:SetPoint("TOPLEFT", root, "TOPLEFT", 14, -10)
    strip:SetPoint("TOPRIGHT", root, "TOPRIGHT", -16, -10)
    SetPixelBackdrop(strip, { 0.043, 0.051, 0.071, 0.98 }, { 0.145, 0.165, 0.212, 0.95 }, 1)

    local openMgrBtn = CreateStyledButton(strip, "Loadouts & Binds", 144, 28, true, function()
        DynamicTalent:OpenTalentManagerModal(1)
    end)
    openMgrBtn:SetPoint("RIGHT", strip, "RIGHT", -12, 0)
    openMgrBtn:HookScript("OnEnter", function(s)
        if GameTooltip then
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:AddLine("Open Loadouts & Binds Manager", 1, 1, 1)
            GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Open the Pop-Out Talent Loadouts Manager alongside Blizzard's Talents window.|r", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    openMgrBtn:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    local openTalentsBtn = CreateStyledButton(strip, "Talent Window", 116, 28, false, function()
        if IsPlayerInCombat() then
            Print("Cannot toggle Blizzard's Talents window during combat.")
            return
        end
        if _G.PlayerSpellsUtil and type(_G.PlayerSpellsUtil.TogglePlayerSpellsFrame) == "function" then
            pcall(_G.PlayerSpellsUtil.TogglePlayerSpellsFrame)
        elseif type(_G.ToggleTalentFrame) == "function" then
            pcall(_G.ToggleTalentFrame)
        end
    end)
    openTalentsBtn:SetPoint("RIGHT", openMgrBtn, "LEFT", -8, 0)
    openTalentsBtn:HookScript("OnEnter", function(s)
        if GameTooltip then
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:AddLine("Open Talent Window", 1, 1, 1)
            GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Toggle Blizzard's Talent Tree & Left-Hand Loadouts Dock (out of combat).|r", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    openTalentsBtn:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    local stripTitle = strip:CreateFontString(nil, "OVERLAY")
    SetFontSafe(stripTitle, 11.5, "")
    stripTitle:SetPoint("TOPLEFT", strip, "TOPLEFT", 12, -9)
    stripTitle:SetPoint("RIGHT", openTalentsBtn, "LEFT", -12, 0)
    stripTitle:SetJustifyH("LEFT")
    stripTitle:SetWordWrap(false)
    DynamicTalent.AttachTruncationTooltip(stripTitle)

    local stripSub = strip:CreateFontString(nil, "OVERLAY")
    SetFontSafe(stripSub, 9.5, "")
    stripSub:SetPoint("TOPLEFT", stripTitle, "BOTTOMLEFT", 0, -3)
    stripSub:SetPoint("RIGHT", openTalentsBtn, "LEFT", -12, 0)
    stripSub:SetJustifyH("LEFT")
    stripSub:SetWordWrap(false)
    stripSub:SetTextColor(0.58, 0.65, 0.74, 0.95)
    DynamicTalent.AttachTruncationTooltip(stripSub)

    local function RefreshActionStrip()
        local _, a = GetTheme()
        local specID = DynamicTalent:GetActiveSpecID()
        local lib = (specID and db.talentStringLibrary and db.talentStringLibrary[specID]) or {}
        local activeEntry = DynamicTalent:GetActiveTalentLibraryEntry(specID)
        local _, activeBarName = DynamicTalent:GetTalentLoadoutBarData()
        local activeBadge = activeEntry and DynamicTalent:FormatTalentBadge(activeEntry) or string.format("|cFF%s[Live]|r", a.hex)
        local activeName = tostring((activeEntry and activeEntry.name) or activeBarName or "Default")
        stripTitle:SetText(string.format("%s |cFFFFFFFF%s|r  |cFF64748B(Active)|r", activeBadge, activeName))
        stripSub:SetText(string.format("%d saved %s (active spec) |cFF475569-|r Docked on Talents", #lib, (#lib == 1 and "build" or "builds")))
    end
    RefreshActionStrip()
    root.RefreshActionStrip = RefreshActionStrip
    root.openTalentsBtn = openTalentsBtn
    root.openMgrBtn = openMgrBtn

    local sf, sc, UpdateScrollBar = CreateThreeWayScrollPane(root, strip, -10, -16, 10)
    local y = 0

    -- Section 1: Display & Reminders
    local sec1 = CreateSectionBox(sc, y)
    local sy = -10
    local _, dy1h = CreateSectionHeader(sec1, sy, "TALENT LOADOUT DISPLAY & REMINDERS",
        "Configure module availability, Top Info Bar capsule visibility, swap alerts, and zone sorting.")
    sy = sy + dy1h

    local _, dyEnable = CreateSegmentedSwitchCard(sec1, sy, "Enable DynamicTalent Module",
        "Enables the Talent Loadouts Dock beside the Talent window, Top Info Bar switcher, and swap reminders.",
        function() return db.enabled ~= false end,
        function(v)
            db.enabled = (v == true)
            DynamicTalent:RefreshTalentDock()
            if not v then
                DynamicTalent:HideTalentReminderToast()
                DynamicTalent:HideTalentPopover()
                DynamicTalent:HideTalentTreeBackdrop()
            else
                DynamicTalent:EnsureHeroMedallionHooks()
                DynamicTalent:UpdateTalentTreeBackdrop()
                DynamicTalent:CheckZoneTalentLoadout()
            end
            if _G.DynamicPrep and type(_G.DynamicPrep.RefreshBar) == "function" then
                pcall(_G.DynamicPrep.RefreshBar, _G.DynamicPrep)
            end
        end)
    sy = sy + dyEnable

    local _, dyPrepBar = CreateSegmentedSwitchCard(sec1, sy, "Show Talent Capsule on Prep Bar",
        "Shows your active build and 1-click swap button inside DynamicPrep's Top Info Bar.",
        function()
            return _G.DynamicPrepDB and _G.DynamicPrepDB.segments and _G.DynamicPrepDB.segments.talents == true
        end,
        function(v)
            _G.DynamicPrepDB = _G.DynamicPrepDB or {}
            _G.DynamicPrepDB.segments = _G.DynamicPrepDB.segments or {}
            _G.DynamicPrepDB.segments.talents = (v == true)
            if _G.DynamicPrep and type(_G.DynamicPrep.RefreshBar) == "function" then
                pcall(_G.DynamicPrep.RefreshBar, _G.DynamicPrep)
            end
        end)
    sy = sy + dyPrepBar

    local testToastBtn = CreateStyledButton(sec1, "Test", 76, 26, false, function()
        local list = DynamicTalent:GetSortedTalentProfiles(nil, false)
        local sample = list[1] or { name = "Raid Build", group = "Raid", heroAcronym = "WS" }
        DynamicTalent:ShowTalentReminderToast(sample, sample.name, "Preview Reminder", true)
    end)
    local _, dyRem = CreateSegmentedSwitchCard(sec1, sy, "Zone Talent Reminders",
        "Shows an alert toast when entering content with a different bound build.",
        function() return db.talentReminderEnabled ~= false and db.talentReminderToastEnabled ~= false end,
        function(v)
            db.talentReminderEnabled = (v == true)
            db.talentReminderToastEnabled = (v == true)
            if not v then DynamicTalent:HideTalentReminderToast() end
        end,
        testToastBtn)
    sy = sy + dyRem

    local _, dyZoneFirst = CreateSegmentedSwitchCard(sec1, sy, "Prioritise Current Zone First",
        "Floats builds matching your active zone to the top of quick-switchers.",
        function() return db.prioritiseCurrentZone == true end,
        function(v)
            db.prioritiseCurrentZone = (v == true)
            DynamicTalent:RefreshTalentDock()
        end)
    sy = sy + dyZoneFirst

    local _, dyHeroSwap = CreateSegmentedSwitchCard(sec1, sy, "Right-Click Hero Spec Swap",
        "Right-click the Hero Talent medallion out of combat to swap Hero trees.",
        function() return db.rightClickHeroSwap ~= false end,
        function(v)
            db.rightClickHeroSwap = (v == true)
            DynamicTalent:EnsureHeroMedallionHooks()
        end)
    sy = sy + dyHeroSwap

    local sec1H = math.abs(sy) + 8
    sec1:SetHeight(sec1H)
    y = y - (sec1H + 10)

    -- Section 2: Talent Tree Backdrop Studio
    local secBg = CreateSectionBox(sc, y)
    local syBg = -10
    local _, dyBgH = CreateSectionHeader(secBg, syBg, "TALENT TREE BACKDROP",
        "Customise Blizzard's talent background, dimmer strength, and optional Hero-synced or class-tinted ambient mist.")
    syBg = syBg + dyBgH

    local dimmerCard, mistIntCard
    local _, dyBgBase = CreateBackdropModeCard(secBg, syBg, "Base Background",
        "Choose Blizzard spec art or a solid Obsidian canvas.",
        {
            { value = "BLIZZARD", label = "Blizzard Spec Art", tip = "Keeps Blizzard's native specialisation artwork visible behind talent nodes (adjustable with Background Dimmer)." },
            { value = "OBSIDIAN", label = "Solid Obsidian",    tip = "Replaces Blizzard's spec artwork with a sleek Solid Obsidian canvas and subtle dark perimeter vignette." },
        },
        function() return (db.talentBackdropBase == "BLIZZARD") and "BLIZZARD" or "OBSIDIAN" end,
        function(val)
            db.talentBackdropBase = val
            if dimmerCard and dimmerCard.RefreshEnabledState then dimmerCard.RefreshEnabledState() end
            DynamicTalent:UpdateTalentTreeBackdrop()
        end)
    syBg = syBg + dyBgBase

    local dyDimmer
    dimmerCard, dyDimmer = CreatePrecisionSliderCard(secBg, syBg, "Background Dimmer",
        "Darkens Blizzard art so talent nodes stay crisp.",
        0, 85, 5,
        function() return db.talentBackdropDimmer ~= nil and db.talentBackdropDimmer or 35 end,
        function(val)
            db.talentBackdropDimmer = val
            DynamicTalent:UpdateTalentTreeBackdrop()
        end,
        function(v) return string.format("%d%%", v) end,
        function() return (db.talentBackdropBase == "BLIZZARD") end,
        "Only applies to Blizzard Spec Art.")
    syBg = syBg + dyDimmer

    local _, dyMistMode = CreateBackdropModeCard(secBg, syBg, "Ambient Mist",
        "Overlay soft Hero-synced or class-tinted mist.",
        {
            { value = "OFF",        label = "Off",         tip = "Turns off the drifting mist and focal glow overlay." },
            { value = "HERO_MIST",  label = "Hero-Synced", tip = "Layered Obsidian mist that shifts its colour mood automatically across all 40 Hero Talent trees." },
            { value = "CLASS_GLOW", label = "Class Glow",  tip = "Soft Obsidian mist tinted to your active Class Colour or Suite Accent." },
        },
        function() return db.talentBackdropMist or "HERO_MIST" end,
        function(val)
            db.talentBackdropMist = val
            if mistIntCard and mistIntCard.RefreshEnabledState then mistIntCard.RefreshEnabledState() end
            DynamicTalent:UpdateTalentTreeBackdrop()
        end)
    syBg = syBg + dyMistMode

    local dyMistInt
    mistIntCard, dyMistInt = CreatePrecisionSliderCard(secBg, syBg, "Mist Intensity",
        "Adjusts ambient mist and glow strength.",
        15, 100, 5,
        function() return db.talentBackdropMistIntensity ~= nil and db.talentBackdropMistIntensity or 60 end,
        function(val)
            db.talentBackdropMistIntensity = val
            DynamicTalent:UpdateTalentTreeBackdrop()
        end,
        function(v) return string.format("%d%%", v) end,
        function() return ((db.talentBackdropMist or "HERO_MIST") ~= "OFF") end,
        "Only applies when Ambient Mist is on.")
    syBg = syBg + dyMistInt

    local _, dyAnim = CreateSegmentedSwitchCard(secBg, syBg, "Subtle Backdrop Animation",
        "Gently drifts and pulses the ambient mist when Hero-Synced or Class Glow is active.",
        function() return db.talentBackdropAnimate ~= false end,
        function(v)
            db.talentBackdropAnimate = (v == true)
            DynamicTalent:UpdateTalentTreeBackdrop()
        end)
    syBg = syBg + dyAnim

    local secBgH = math.abs(syBg) + 8
    secBg:SetHeight(secBgH)
    y = y - (secBgH + 10)

    -- Section 3: Custom Loadout Group Order (Drag-and-Drop + Bordered Chevrons)
    local sec2 = CreateSectionBox(sc, y)
    local sy2 = -10
    local RefreshGroupOrderRows
    local resetOrderBtn = CreateStyledButton(sec2, "Reset Order", 96, 22, false, function()
        db.talentGroupOrder = { "Raid", "M+", "Delves", "PvP", "Custom" }
        Print("Restored default loadout group order.")
        DynamicTalent:RefreshTalentDock()
        if RefreshGroupOrderRows then RefreshGroupOrderRows() end
    end)
    resetOrderBtn:SetPoint("TOPRIGHT", sec2, "TOPRIGHT", -14, -14)
    local _, dy2h = CreateSectionHeader(sec2, sy2, "CUSTOM LOADOUT GROUP ORDER",
        "Drag and drop rows or use arrows to set the group order across the Talent Dock, quick-switcher, and dropdowns.", resetOrderBtn)
    sy2 = sy2 + dy2h

    db.talentGroupOrder = SanitizeGroupOrder(db.talentGroupOrder)
    local groupCount = #db.talentGroupOrder
    local groupListHost = CreateFrame("Frame", nil, sec2)
    groupListHost:SetHeight((groupCount * 36) + (math.max(0, groupCount - 1) * 4))
    groupListHost:SetPoint("TOPLEFT", sec2, "TOPLEFT", 12, sy2)
    groupListHost:SetPoint("TOPRIGHT", sec2, "TOPRIGHT", -12, sy2)

    local groupRows = {}
    local dragState = { active = false, lifted = false, slotIdx = nil, sx = 0, sy = 0 }

    local function FinishGroupDrag()
        if not dragState.active then return end
        dragState.active = false
        dragState.lifted = false
        dragState.slotIdx = nil
        groupListHost:SetScript("OnUpdate", nil)
        if groupDragGhost then groupDragGhost:Hide() end
        for _, rFrame in ipairs(groupRows) do
            rFrame:SetAlpha(1.0)
            if rFrame.UpdateGripTint then rFrame.UpdateGripTint(false) end
        end
        if RefreshGroupOrderRows then RefreshGroupOrderRows() end
    end

    local function OnGroupDragUpdate()
        if not dragState.active then return end
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            FinishGroupDrag()
            return
        end
        local cx, cy = GetCursorPosition()
        if not cx or not cy then return end
        if not dragState.lifted then
            local dx = cx - dragState.sx
            local dy = cy - dragState.sy
            if ((dx * dx) + (dy * dy)) > 36 then
                dragState.lifted = true
                if GameTooltip then GameTooltip:Hide() end
                local ghost = EnsureGroupDragGhost()
                local gKey = db.talentGroupOrder[dragState.slotIdx]
                ghost:SetGroupVisual(dragState.slotIdx, gKey)
                ghost:Show()
                if RefreshGroupOrderRows then RefreshGroupOrderRows() end
            else
                return
            end
        end

        local ghost = EnsureGroupDragGhost()
        local gEff = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        if gEff <= 0 then gEff = 1 end
        ghost:ClearAllPoints()
        ghost:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (cx / gEff) + 12, (cy / gEff) - 14)

        local hoverSlot = nil
        for j, rFrame in ipairs(groupRows) do
            local rEff = (rFrame.GetEffectiveScale and rFrame:GetEffectiveScale()) or gEff
            if rEff <= 0 then rEff = 1 end
            local ucy = cy / rEff
            local topY = rFrame.GetTop and rFrame:GetTop()
            local botY = rFrame.GetBottom and rFrame:GetBottom()
            if topY and botY and ucy <= (topY + 2) and ucy >= (botY - 2) then
                hoverSlot = j
                break
            end
        end
        if hoverSlot and dragState.slotIdx and hoverSlot ~= dragState.slotIdx then
            local ord = db.talentGroupOrder
            local moved = table.remove(ord, dragState.slotIdx)
            if moved then
                table.insert(ord, hoverSlot, moved)
                dragState.slotIdx = hoverSlot
                ghost:SetGroupVisual(hoverSlot, moved)
                RefreshGroupOrderRows()
                DynamicTalent:RefreshTalentDock()
            end
        end
    end

    RefreshGroupOrderRows = function()
        db.talentGroupOrder = SanitizeGroupOrder(db.talentGroupOrder)
        local _, a = GetTheme()
        for i, grpKey in ipairs(db.talentGroupOrder) do
            local row = groupRows[i]
            if row then
                row._slotIdx = i
                local isDragged = (dragState.lifted and dragState.slotIdx == i)
                row:SetAlpha(isDragged and 0.35 or 1.0)
                if isDragged then
                    SetPixelBackdrop(row, { a.r * 0.16, a.g * 0.16, a.b * 0.16, 0.96 }, { a.r, a.g, a.b, 0.85 }, 1)
                else
                    SetPixelBackdrop(row, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)
                end
                row.rankFs:SetTextColor(a.r, a.g, a.b, 1.0)
                row.rankFs:SetText("#" .. i)

                local meta = GROUP_ROW_META[grpKey] or { title = grpKey, desc = "" }
                local gHex = TALENT_GROUP_HEX[grpKey] or "94A3B8"
                row.lblFs:SetText(string.format("|cFF%s[%s]|r  |cFFFFFFFF%s|r  |cFF64748B- %s|r", gHex, grpKey, meta.title, meta.desc))

                local canUp = (i > 1)
                local canDown = (i < #db.talentGroupOrder)
                row.upBtn:SetEnabled(canUp)
                row.upTex:SetVertexColor(canUp and 0.85 or 0.32, canUp and 0.90 or 0.36, canUp and 0.96 or 0.42, canUp and 1 or 0.45)
                row.upBtn:SetScript("OnEnter", function(s)
                    if canUp then
                        local _, ac = GetTheme()
                        SetPixelBackdrop(s, { ac.r * 0.35, ac.g * 0.35, ac.b * 0.35, 0.98 }, { ac.r, ac.g, ac.b, 0.95 }, 1)
                    end
                end)
                row.upBtn:SetScript("OnLeave", function(s)
                    SetPixelBackdrop(s, COLORS.BgElevated, COLORS.BorderSubtle, 1)
                end)
                row.upBtn:SetScript("OnClick", function()
                    if not canUp then return end
                    local ord = db.talentGroupOrder
                    ord[i], ord[i - 1] = ord[i - 1], ord[i]
                    DynamicTalent:RefreshTalentDock()
                    RefreshGroupOrderRows()
                end)

                row.downBtn:SetEnabled(canDown)
                row.downTex:SetVertexColor(canDown and 0.85 or 0.32, canDown and 0.90 or 0.36, canDown and 0.96 or 0.42, canDown and 1 or 0.45)
                row.downBtn:SetScript("OnEnter", function(s)
                    if canDown then
                        local _, ac = GetTheme()
                        SetPixelBackdrop(s, { ac.r * 0.35, ac.g * 0.35, ac.b * 0.35, 0.98 }, { ac.r, ac.g, ac.b, 0.95 }, 1)
                    end
                end)
                row.downBtn:SetScript("OnLeave", function(s)
                    SetPixelBackdrop(s, COLORS.BgElevated, COLORS.BorderSubtle, 1)
                end)
                row.downBtn:SetScript("OnClick", function()
                    if not canDown then return end
                    local ord = db.talentGroupOrder
                    ord[i], ord[i + 1] = ord[i + 1], ord[i]
                    DynamicTalent:RefreshTalentDock()
                    RefreshGroupOrderRows()
                end)
            end
        end
    end

    for idx = 1, groupCount do
        local row = CreateFrame("Frame", nil, groupListHost, "BackdropTemplate")
        row:SetHeight(36)
        row:SetPoint("TOPLEFT", groupListHost, "TOPLEFT", 0, -((idx - 1) * 40))
        row:SetPoint("TOPRIGHT", groupListHost, "TOPRIGHT", 0, -((idx - 1) * 40))
        row:EnableMouse(true)
        row._slotIdx = idx
        SetPixelBackdrop(row, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)

        local grip = CreateFrame("Frame", nil, row)
        grip:SetSize(14, 16)
        grip:SetPoint("LEFT", row, "LEFT", 10, 0)
        grip.bars = {}
        for bi, by in ipairs({ 4, 0, -4 }) do
            local bTex = grip:CreateTexture(nil, "ARTWORK")
            bTex:SetSize(10, 2)
            bTex:SetPoint("CENTER", grip, "CENTER", 0, by)
            bTex:SetColorTexture(0.48, 0.54, 0.64, 0.72)
            grip.bars[bi] = bTex
        end
        function row.UpdateGripTint(hovered)
            local _, ac = GetTheme()
            for _, bTex in ipairs(grip.bars) do
                if hovered then
                    bTex:SetColorTexture(ac.r, ac.g, ac.b, 0.95)
                else
                    bTex:SetColorTexture(0.48, 0.54, 0.64, 0.72)
                end
            end
        end

        local downBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
        downBtn:SetSize(26, 22)
        downBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        SetPixelBackdrop(downBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
        local downTex = downBtn:CreateTexture(nil, "OVERLAY")
        downTex:SetSize(10, 10)
        downTex:SetPoint("CENTER")
        downTex:SetTexture(ICON_CHEVRON_DOWN)

        local upBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
        upBtn:SetSize(26, 22)
        upBtn:SetPoint("RIGHT", downBtn, "LEFT", -4, 0)
        SetPixelBackdrop(upBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
        local upTex = upBtn:CreateTexture(nil, "OVERLAY")
        upTex:SetSize(10, 10)
        upTex:SetPoint("CENTER")
        upTex:SetTexture(ICON_CHEVRON_UP)

        local rankFs = row:CreateFontString(nil, "OVERLAY")
        SetFontSafe(rankFs, 10.5, "")
        rankFs:SetPoint("LEFT", grip, "RIGHT", 6, 0)
        rankFs:SetWidth(24)
        rankFs:SetJustifyH("LEFT")
        rankFs:SetTextColor(acc.r, acc.g, acc.b, 1.0)

        local lblFs = row:CreateFontString(nil, "OVERLAY")
        SetFontSafe(lblFs, 11, "")
        lblFs:SetPoint("LEFT", rankFs, "RIGHT", 6, 0)
        lblFs:SetPoint("RIGHT", upBtn, "LEFT", -10, 0)
        lblFs:SetJustifyH("LEFT")
        lblFs:SetWordWrap(false)

        row.grip = grip
        row.rankFs = rankFs
        row.lblFs = lblFs
        row.upBtn = upBtn
        row.upTex = upTex
        row.downBtn = downBtn
        row.downTex = downTex

        row:SetScript("OnEnter", function(s)
            row.UpdateGripTint(true)
            if not dragState.lifted then
                local _, ac = GetTheme()
                SetPixelBackdrop(s, { 0.094, 0.110, 0.148, 0.98 }, { ac.r, ac.g, ac.b, 0.60 }, 1)
                if GameTooltip then
                    local gk = db.talentGroupOrder[s._slotIdx] or ""
                    local gm = GROUP_ROW_META[gk] or { title = gk }
                    GameTooltip:SetOwner(s, "ANCHOR_TOP")
                    GameTooltip:AddLine("Reorder Loadout Group: " .. tostring(gm.title), 1, 1, 1)
                    GameTooltip:AddLine("|cFF34D399Left-Click & Drag:|r |cFFE2E8F0Drag row up or down to reorder.|r", 1, 1, 1, true)
                    GameTooltip:AddLine("|cFF38BDF8Up / Down Chevrons:|r |cFFE2E8F0Move this group one step at a time.|r", 1, 1, 1, true)
                    GameTooltip:Show()
                end
            end
        end)
        row:SetScript("OnLeave", function(s)
            if MouseIsOver and MouseIsOver(s) then return end
            row.UpdateGripTint(false)
            if not dragState.lifted or dragState.slotIdx ~= s._slotIdx then
                SetPixelBackdrop(s, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)
            end
            if GameTooltip then GameTooltip:Hide() end
        end)
        row:SetScript("OnMouseDown", function(s, btn)
            if btn ~= "LeftButton" then return end
            local cx, cy = GetCursorPosition()
            dragState.active = true
            dragState.lifted = false
            dragState.slotIdx = s._slotIdx
            dragState.sx = cx or 0
            dragState.sy = cy or 0
            groupListHost:SetScript("OnUpdate", OnGroupDragUpdate)
        end)
        row:SetScript("OnMouseUp", function()
            FinishGroupDrag()
        end)

        groupRows[idx] = row
    end
    groupListHost:SetScript("OnHide", FinishGroupDrag)
    RefreshGroupOrderRows()
    root.groupListHost = groupListHost
    root.groupRows = groupRows
    root.RefreshGroupOrderRows = RefreshGroupOrderRows

    sy2 = sy2 - (groupCount * 40)
    local sec2H = math.abs(sy2) + 8
    sec2:SetHeight(sec2H)
    y = y - (sec2H + 10)

    -- Section 4: Maintenance & Defaults
    local sec3 = CreateSectionBox(sc, y)
    local sy3 = -10
    local _, dy3h = CreateSectionHeader(sec3, sy3, "MAINTENANCE & DEFAULTS",
        "Reset DynamicTalent display, reminder, and group-order settings while keeping all saved builds and binds.")
    sy3 = sy3 + dy3h

    local rstBtn = CreateStyledButton(sec3, "Reset DynamicTalent Defaults", 210, 26, false, function()
        DynamicTalent:ResetModuleDefaults()
    end)
    rstBtn:SetPoint("TOPLEFT", sec3, "TOPLEFT", 14, sy3)

    sy3 = sy3 - 36
    local sec3H = math.abs(sy3) + 8
    sec3:SetHeight(sec3H)
    y = y - (sec3H + 10)

    sc:SetHeight(math.max(120, math.abs(y) + 12))
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            local w = sf:GetWidth()
            if w and w > 40 then sc:SetWidth(w) end
            UpdateScrollBar()
        end)
    end

    return root
end

function DynamicTalent:SelectSubTab(idx, _, entryOrOpts)
    local db = EnsureDB()
    db.activeSubTab = 1
    if activeEmbeddedRoot and activeEmbeddedRoot:IsShown() and activeEmbeddedRoot:GetParent() then
        RenderTalentEmbedded(activeEmbeddedRoot:GetParent())
    end
    if type(entryOrOpts) == "table" and (entryOrOpts.openManager == true or entryOrOpts.subMode) then
        self:OpenTalentManagerModal(1)
        if entryOrOpts.subMode and talentMgrModal and talentMgrModal.SelectSubMode then
            talentMgrModal:SelectSubMode(entryOrOpts.subMode)
        end
    end
end

function DynamicTalent:ApplyTheme()
    local activeFont = GetActiveFontPath()
    for _, fs in ipairs(trackedFontStrings) do
        if fs and fs.SetFont then
            pcall(fs.SetFont, fs, activeFont, fs._dtFontSize or 11, fs._dtFontFlags or "")
        end
    end
    local surf, acc = GetTheme()
    if standaloneWin then
        SetPixelBackdrop(standaloneWin, surf.bg, { acc.r, acc.g, acc.b, 0.90 }, 1)
        if standaloneWin.topLine then
            standaloneWin.topLine:SetColorTexture(acc.r, acc.g, acc.b, 1.0)
        end
        if standaloneWin.titleText then
            standaloneWin.titleText:SetText(string.format("|cFF%sDynamic|r|cFFFFFFFFTalent|r  |cFF94A3B8v%s|r", acc.hex, VERSION))
        end
    end
    if talentMgrModal then
        SetPixelBackdrop(talentMgrModal, { 0.035, 0.039, 0.051, 1.00 }, { acc.r, acc.g, acc.b, 0.90 }, 1)
        if talentMgrModal.hdrTitle then
            talentMgrModal.hdrTitle:SetText(string.format("|cFFCBD5E1Dynamic|r|cFFFFFFFFTalent|r  |cFF475569|||r  |cFF%sTalent Loadouts Manager|r", acc.hex))
        end
        if talentMgrModal:IsShown() and talentMgrModal.RefreshTab2View then
            talentMgrModal:RefreshTab2View()
        end
    end
    if activeEmbeddedRoot and activeEmbeddedRoot:IsShown() and activeEmbeddedRoot:GetParent() then
        pcall(RenderTalentEmbedded, activeEmbeddedRoot:GetParent())
    end
    self:ApplyTalentReminderToastVisuals()
    self:RefreshTalentDock()
    self:UpdateTalentTreeBackdrop()
end

function DynamicTalent:ResetModuleDefaults()
    local db = EnsureDB()
    local keepMigrated = db.migratedFromPrep
    local keepNextSeq  = tonumber(db.nextLoadoutIDSeq) or 0
    local keepLib      = db.talentStringLibrary
    local keepBoss     = db.talentBossMap
    local keepDung     = db.talentDungeonMap
    local keepPvP      = db.talentPvPMap
    local keepZone     = db.talentZoneMap
    local keepPref     = db.talentPreferredBySpec
    local keepLastID   = db.lastAppliedTalentID
    local keepLastNm   = db.lastAppliedTalentName
    local keepLastStr  = db.lastAppliedTalentLiveStr

    wipe(db)
    CopyDefaults(db, DEFAULTS)
    db.migratedFromPrep         = keepMigrated
    db.nextLoadoutIDSeq         = keepNextSeq
    db.talentStringLibrary      = keepLib or {}
    db.talentBossMap            = keepBoss or {}
    db.talentDungeonMap         = keepDung or {}
    db.talentPvPMap             = keepPvP or {}
    db.talentZoneMap            = keepZone or {}
    db.talentPreferredBySpec    = keepPref or {}
    db.lastAppliedTalentID      = keepLastID or {}
    db.lastAppliedTalentName    = keepLastNm or {}
    db.lastAppliedTalentLiveStr = keepLastStr or {}
    db.talentGroupOrder         = SanitizeGroupOrder(DEFAULTS.talentGroupOrder)

    if talentMgrModal then
        talentMgrModal:SetSize(880, 580)
        if talentMgrModal.UpdateResponsiveLayout then talentMgrModal:UpdateResponsiveLayout() end
        if talentMgrModal.RefreshQuickStartStrip then talentMgrModal:RefreshQuickStartStrip() end
    end
    Print("Module settings restored to defaults (saved loadouts and binds preserved).")
    self:ApplyTheme()
    if _G.DynamicPrep and type(_G.DynamicPrep.RefreshBar) == "function" then
        pcall(_G.DynamicPrep.RefreshBar, _G.DynamicPrep)
    end
end

function DynamicTalent:OnDisableInSuite()
    CloseAllDynamicTalentPopups()
    self:HideTalentReminderToast()
    self:HideTalentTreeBackdrop()
    if talentDockFrame then
        if IsPlayerInCombat() then
            pendingDockRefresh = true
        else
            talentDockFrame:Hide()
        end
    end
    if talentMgrModal then talentMgrModal:Hide() end
    if standaloneWin then standaloneWin:Hide() end
    if _G.DynamicPrep and type(_G.DynamicPrep.RefreshBar) == "function" then
        pcall(_G.DynamicPrep.RefreshBar, _G.DynamicPrep)
    end
end

function DynamicTalent:OnEnableInSuite()
    EnsureDB()
    self:EnsureTalentDockHooks()
    self:EnsureHeroMedallionHooks()
    self:RefreshTalentDock()
    self:UpdateTalentTreeBackdrop()
    self:CheckZoneTalentLoadout()
    if _G.DynamicPrep and type(_G.DynamicPrep.RefreshBar) == "function" then
        pcall(_G.DynamicPrep.RefreshBar, _G.DynamicPrep)
    end
end

function DynamicTalent:GetStatusText()
    local db = EnsureDB()
    if IsModuleDisabledInSuite("DynamicTalent") or db.enabled == false then
        return "|cFFF43F5EDisabled|r"
    end
    local specID = self:GetActiveSpecID()
    local lib = (specID and db.talentStringLibrary and db.talentStringLibrary[specID]) or {}
    return string.format("|cFF10B981%d %s|r", #lib, (#lib == 1 and "Build" or "Builds"))
end

function DynamicTalent:Open(subTab)
    local db = EnsureDB()
    if type(subTab) == "number" then
        db.activeSubTab = (subTab == 2) and 2 or 1
    end
    if _G.DynamicSuite and type(_G.DynamicSuite.OpenModule) == "function" and not IsModuleDisabledInSuite("DynamicTalent") then
        _G.DynamicSuite:OpenModule("talent")
        return
    end
    if not standaloneWin then
        local surf, acc = GetTheme()
        local f = CreateFrame("Frame", "DynamicTalentStandaloneFrame", UIParent, "BackdropTemplate")
        f:SetSize(900, 600)
        f:SetPoint("CENTER")
        f:SetMovable(true)
        f:SetResizable(true)
        if f.SetResizeBounds then
            f:SetResizeBounds(760, 480, 1280, 860)
        elseif f.SetMinResize then
            f:SetMinResize(760, 480)
            if f.SetMaxResize then f:SetMaxResize(1280, 860) end
        end
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameStrata("DIALOG")
        SetPixelBackdrop(f, surf.bg, { acc.r, acc.g, acc.b, 0.90 }, 1)
        if type(_G.UISpecialFrames) == "table" then
            local seen = false
            for _, n in ipairs(_G.UISpecialFrames) do
                if n == "DynamicTalentStandaloneFrame" then seen = true; break end
            end
            if not seen then table.insert(_G.UISpecialFrames, "DynamicTalentStandaloneFrame") end
        end

        local hdr = CreateFrame("Frame", nil, f, "BackdropTemplate")
        hdr:SetHeight(38)
        hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        hdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
        SetPixelBackdrop(hdr, surf.header, { 0, 0, 0, 0 }, 0)

        local topLine = CreateSolidTex(hdr, "OVERLAY", 4, acc.r, acc.g, acc.b, 1.0)
        topLine:SetHeight(2)
        topLine:SetPoint("TOPLEFT", hdr, "TOPLEFT", 0, 0)
        topLine:SetPoint("TOPRIGHT", hdr, "TOPRIGHT", 0, 0)
        f.topLine = topLine

        local div = CreateSolidTex(hdr, "ARTWORK", 1, 1, 1, 1, 0.08)
        div:SetHeight(1)
        div:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 0, 0)
        div:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)

        local closeBtn = CreateStyledButton(hdr, "X", 24, 22, false, function() f:Hide() end)
        closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -10, 0)

        local title = hdr:CreateFontString(nil, "OVERLAY")
        SetFontSafe(title, 13, "")
        title:SetPoint("LEFT", hdr, "LEFT", 16, 0)
        title:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
        title:SetJustifyH("LEFT")
        title:SetWordWrap(false)
        title:SetText(string.format("|cFF%sDynamic|r|cFFFFFFFFTalent|r  |cFF94A3B8v%s|r", acc.hex, VERSION))
        f.titleText = title

        local footer = CreateFrame("Frame", nil, f, "BackdropTemplate")
        footer:SetHeight(36)
        footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
        footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
        SetPixelBackdrop(footer, surf.header, surf.border, 1)

        local resetBtn = CreateStyledButton(footer, "Reset DynamicTalent", 152, 24, false, function()
            DynamicTalent:ResetModuleDefaults()
        end)
        resetBtn:SetPoint("LEFT", footer, "LEFT", 14, 0)

        local reloadBtn = CreateStyledButton(footer, "Reload UI", 92, 24, false, function()
            if type(_G.ReloadUI) == "function" then _G.ReloadUI() end
        end)
        reloadBtn:SetPoint("RIGHT", footer, "RIGHT", -32, 0)

        local grip = CreateFrame("Button", nil, footer)
        grip:SetSize(14, 14)
        grip:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -4, 4)
        grip:SetFrameLevel(footer:GetFrameLevel() + 4)
        grip:EnableMouse(true)
        local gripTex = grip:CreateTexture(nil, "OVERLAY", nil, 5)
        gripTex:SetAllPoints()
        gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        gripTex:SetDesaturated(true)
        gripTex:SetVertexColor(0.55, 0.58, 0.65, 0.75)
        grip:SetScript("OnEnter", function(s)
            local _, a = GetTheme()
            gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
            gripTex:SetDesaturated(false)
            gripTex:SetVertexColor(a.r, a.g, a.b, 0.95)
            if GameTooltip then
                GameTooltip:SetOwner(s, "ANCHOR_TOPLEFT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine("Resize Window", 1, 1, 1)
                GameTooltip:AddLine(string.format("|cFF%sLeft-Click & Drag:|r |cFFE2E8F0Resize DynamicTalent window|r", a.hex))
                GameTooltip:AddLine(string.format("|cFF%sRight-Click:|r |cFFE2E8F0Reset size to 900x600|r", a.hex))
                GameTooltip:Show()
            end
        end)
        grip:SetScript("OnLeave", function()
            gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
            gripTex:SetDesaturated(true)
            gripTex:SetVertexColor(0.55, 0.58, 0.65, 0.75)
            if GameTooltip then GameTooltip:Hide() end
        end)
        grip:SetScript("OnMouseDown", function(_, btn)
            if btn == "LeftButton" then
                f:StartSizing("BOTTOMRIGHT")
            elseif btn == "RightButton" then
                f:SetSize(900, 600)
            end
        end)
        grip:SetScript("OnMouseUp", function()
            f:StopMovingOrSizing()
        end)

        local body = CreateFrame("Frame", nil, f)
        body:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, 0)
        body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
        f.body = body
        f:SetScript("OnHide", function()
            CloseAllDynamicTalentPopups()
        end)
        standaloneWin = f
    end
    local surf, acc = GetTheme()
    SetPixelBackdrop(standaloneWin, surf.bg, { acc.r, acc.g, acc.b, 0.90 }, 1)
    if standaloneWin.topLine then
        standaloneWin.topLine:SetColorTexture(acc.r, acc.g, acc.b, 1.0)
    end
    if standaloneWin.titleText then
        standaloneWin.titleText:SetText(string.format("|cFF%sDynamic|r|cFFFFFFFFTalent|r  |cFF94A3B8v%s|r", acc.hex, VERSION))
    end
    RenderTalentEmbedded(standaloneWin.body)
    standaloneWin:Show()
end

DynamicTalent.RenderEmbedded      = function(a, b)
    local parent = (type(a) == "table" and a.CreateFrame == nil and b) and b or a
    return RenderTalentEmbedded(parent)
end
DynamicTalent.SelectTab           = function(a1, a2, a3, a4)
    local idx = (type(a1) == "number") and a1 or a2 or 1
    local entryOrOpts = (type(a1) == "number") and a3 or ((type(a4) == "table") and a4 or ((type(a3) == "table") and a3 or nil))
    return DynamicTalent:SelectSubTab(idx, nil, entryOrOpts)
end
DynamicTalent.ApplyThemeToUI      = function() return DynamicTalent:ApplyTheme() end
DynamicTalent.RefreshTheme        = function() return DynamicTalent:ApplyTheme() end
DynamicTalent.ResetDefaults       = function() return DynamicTalent:ResetModuleDefaults() end
DynamicTalent.ResetModule         = function() return DynamicTalent:ResetModuleDefaults() end
DynamicTalent.Reset               = function() return DynamicTalent:ResetModuleDefaults() end

-- ============================================================================
-- 12. CHANGELOG, SEARCH ENTRIES & DYNAMICSUITE REGISTRATION
-- ============================================================================
DynamicTalent.CHANGELOG = {
    {
        version = VERSION,
        date = "25/11/2026",
        entries = {
            { type = "FIXED", text = "Release v2.10.3 - Patch 12.1.7 Combat, Secret-Value & Unspecialised Hardening (25/11/2026): Guarded talent dock refreshes on Blizzard's Talent window during combat (deferring updates until combat ends), protected import string decoding and loadout switching against secret values, active Mythic+ runs, and unspecialised or Lorewalking characters, and tightened Encounter Journal, Mythic+ dungeon list, raid difficulty, Hero medallion, and specialisation-change checks." },
            { type = "UI",    text = "Release v2.10.3 - Standalone Window, Pop-Out Manager Parity & 800x520 Layout Reflow (25/11/2026): Made the standalone DynamicTalent window resizable (760x480 to 1280x860) with a live Suite Accent top bar, Reset/Reload footer, and corner resize grip with Right-Click reset; widened the Pop-Out Manager bounds to 1280x860 with resize grip tooltip and Right-Click reset; fixed the Talent Dock scrollbar overlap with the specialisation bar; fixed vertical skew on section headers and Backdrop Studio descriptions; compacted left-column cards, Action Strip buttons, and Raid difficulty rows for clean 800x520 framing; and reflowed Mythic+ dungeon tiles into a 2x4 grid on narrower layouts." },
            { type = "UI",    text = "Release v2.8.1 - Raid Bosses Binder Redesign (22/11/2026): Promoted All Raids to Row 1 alongside the Season 2 raid pills with an Obsidian Core explanation banner; expanded the boss grid to use the full card width underneath; added a red-hover Clear button beside + Bind Raid to remove All Raids or selected boss binds for the toggled difficulties; and fixed multi-select and unselect behaviour on boss tiles." },
            { type = "FIXED", text = "Release v2.8.1 - Raid Boss Selection & Boss-Specific Build Priority Over All Raids (22/11/2026): Removed forced Boss #1 pre-highlighting in Raid Boss Talent Binds (and cleared pending tile selections when switching loadouts or after binding) so bosses can be freely selected and unselected; added automatic single-boss raid matching (Kith'ix, Tidebound Grotto); cleared cached boss memory when targeting an unbound Season 2 raid boss; and protected active boss-specific raid builds from being overridden by All Raids when no unbound boss is targeted." },
            { type = "UI",    text = "Release v2.8.1 - Right-Click Toast Silences Mismatch (22/11/2026): Right-clicking the talent reminder toast or its Swap button now silences that reminder for the session, refreshes DynamicPrep's Top Info Bar capsule immediately, updates the toast subtext to 'Right-Click to silence', and clears silenced reminders on specialisation change or reload." },
            { type = "FIXED", text = "Release v2.8.1 - Sticky Raid Boss Preservation, Real Library Resolution, Focus/Boss Scanning & /dt why (22/11/2026): Preserved the cached raid boss across talent swaps while still clearing it on bind edits or deletes; resolved Prep Bar and Alert Toast payloads back to their saved library entry so live match tracking persists onto the actual loadout; added focus and boss1-5 scanning to boss matching; and upgraded /dt why to report winning rules across all 3 tiers plus live unit names and cached boss state." },
            { type = "UI",    text = "Release v2.8.1 - Prep Bar Capsule, Tooltip & Quick-Switcher Popover Bind-Badge Parity (22/11/2026): Added right-aligned amber-gold bind tags ((Various), (All M+), (#8 Ula'tek)) and dynamic text anchoring to the quick-switcher popover (widened to 276px) with hover highlights and full Talent Dock tooltips (Hero Tree and Bound lines); added bind tags and group badge prefixes to the Prep Bar capsule and tooltip; and refreshed capsule widths automatically when binds change." },
            { type = "FIXED", text = "Release v2.8.1 - Raid Boss Matching Accuracy, Sticky Boss Cache & /dt why (22/11/2026): Removed inverted substring checks in raid boss matching and added Ula'tek aliases so standing at boss #8 never matches boss #2 Entombed Sentinels; allowed pre-pull friendly bosses on nameplates and raid or party targets to be detected cleanly while still skipping player units; added a subzone-scoped boss cache cleared on encounter victory, zone change, spec change, or bind edits to prevent All Raids fallback flicker; and added /dt why (/dt debug) for plain-English diagnostics." },
            { type = "UI",    text = "Tighter Header Subtitles & Truncation Hover Safety Net (22/11/2026): Shortened the Raid Bosses, M+ Dungeons, PvP, Zone Defaults, and Active Reminders subtitles so they fit cleanly on one line at the minimum 800px Talent Loadouts Manager width, and added a reusable hover helper that shows full plain text in a tooltip only when a single-line subtitle or reminder row is cut off." },
            { type = "FIXED", text = "Delve vs Mythic+ Zone Priority Detection (22/11/2026): Updated zone and instance detection to check active Delve status alongside instance difficulty so Delves and non-dungeon scenarios never misclassify as Mythic+; Delves binds always take priority inside Delves, Outdoor binds win in open world zones outside resting cities, and the Talent Dock and Prep Bar refresh cleanly after zoning." },
            { type = "UI",    text = "Option 1 Talent Tree Backdrop Studio Redesign (22/11/2026): Split Backdrop Studio into independent Base Background ('Blizzard Spec Art' or 'Solid Obsidian') and Ambient Mist ('Off', 'Hero-Synced', or 'Class Glow') controls with a muted-when-inactive Background Dimmer (0%-85% for Blizzard Spec Art) and a live Mist Intensity slider (15%-100%, default 60%) so mist layers cleanly over either base, migrating older backdrop settings automatically." },
            { type = "FIXED", text = "Talent Tree Backdrop Studio Layering, Dimmer Order & Mist Opacity (22/11/2026): Layered the custom backdrop textures cleanly above Blizzard's spec background (restored automatically in Blizzard mode or when disabled) and strictly below all talent nodes, links, and buttons; placed the dimmer layer behind the mist and vignette layers so up to 85% dimming never smothers Hero-Synced Mist or Class Glow; and tuned atmospheric mist opacity bounds for crisp readability." },
            { type = "FIXED", text = "Same-Name Loadout Bind Isolation (22/11/2026): Gave every saved build a stable unique identifier across Raid, M+, PvP, and Zone bind rules so builds sharing names never collide or overwrite each other's binds, badges, conflict prompts, or Active Reminders rows." },
            { type = "UI",    text = "Single Pop-Out Manager, Bidirectional Links & Drag-and-Drop Group Order (22/11/2026): Replaced the duplicate embedded manager under /ds -> DynamicTalent with a clean Action & Status strip ('Talent Window' and 'Loadouts & Binds'), added a 'Settings' header button in the Pop-Out Manager, upgraded the 5 Custom Loadout Group Order rows with Left-Click & Drag reordering plus bordered Up/Down chevrons, and standardised sliders to 4px precision tracks." },
            { type = "NEW",   text = "Right-Click Hero Spec Swap (21/11/2026): Added an enabled-by-default 'Right-Click Hero Spec Swap' option (out of combat, skipped during active Mythic+ keystones and inspection) on Blizzard's central Hero Talent medallion with a clean 'Right-Click: Switch to [Other Hero Tree]' hover hint; immediately stages the alternate Hero tree without opening the picker popup." },
            { type = "NEW",   text = "Talent Tree Backdrop Studio & Background Dimmer (21/11/2026): Added a non-interactive background studio behind the Talent tree with Blizzard Spec Art and Solid Obsidian bases, Hero-Synced Mist across all 40 Hero trees, Class Glow, a 0%-85% Background Dimmer slider (default 35%), and a Subtle Backdrop Animation toggle." },
            { type = "NEW",   text = "Extracted DynamicTalent Module (/dt, /dynamictalent) (21/11/2026): Moved the unlimited per-spec Talent Loadout library, Hero Talent acronym badges, WCL/Northern Sky/Blizzard importer, Left-Hand Talent Dock, Talent Loadouts Manager, and Shared Alert Toast reminders out of DynamicPrep into a dedicated 12th dual-mode module with zero-loss settings migration and a clean Top Info Bar capsule hook." },
            { type = "NEW",   text = "Dedicated PvP Binder Tab & 3-Tier Mismatch Priority (21/11/2026): Added a 4th 'PvP' binder tab (All PvP, Arena, Battlegrounds, War Mode) alongside Raid Bosses, M+ Dungeons, and Zone Defaults; specific PvP mode binds now take priority over All PvP, while resting in cities suppresses Outdoor and War Mode alerts cleanly." },
            { type = "NEW",   text = "Custom Loadout Group Ordering & Prioritise Current Zone First (21/11/2026): Added controls to reorder the 5 loadout groups (Raid, M+, Delves, PvP, Custom) and optionally float loadouts matching your active content zone to the top of the Talent Dock and Prep Bar quick-switcher." },
        },
    },
}

DynamicTalent.SEARCH_ENTRIES = {
    { title = "Talent Loadouts & Binds",               desc = "Manage per-spec talent strings, Hero Talent badges, and Raid/M+/PvP/Zone swap rules.",             keywords = "talent loadout import wcl blizzard string hero", tabIndex = 1, openManager = true, targetTitle = "Loadouts & Binds" },
    { title = "Talent Export String",                  desc = "Paste Warcraft Logs, Northern Sky, or Blizzard strings, or capture your active talent tree.",      keywords = "talent string export import paste copy",         tabIndex = 1, openManager = true, targetTitle = "Loadouts & Binds" },
    { title = "PvP Talent Binds",                      desc = "Bind builds to All PvP, Arena, Battlegrounds, or War Mode.",                                       keywords = "pvp arena battlegrounds bg blitz war mode",      tabIndex = 1, subMode = "PVP", openManager = true, targetTitle = "Loadouts & Binds" },
    { title = "Enable DynamicTalent Module",           desc = "Toggle the Talent Loadouts Dock, Prep Bar switcher, and swap reminders.",                          keywords = "enable disable dynamictalent module",            tabIndex = 1, targetTitle = "Enable DynamicTalent Module" },
    { title = "Show Talent Capsule on Prep Bar",       desc = "Toggle the Talent Loadout capsule inside DynamicPrep's Top Info Bar.",                             keywords = "prep bar capsule segment talents",               tabIndex = 1, targetTitle = "Show Talent Capsule on Prep Bar" },
    { title = "Zone Talent Reminders",                 desc = "Show a 1-click alert toast when entering Raid, M+, Delve, or PvP content with a different build.", keywords = "talent reminder toast alert swap",               tabIndex = 1, targetTitle = "Zone Talent Reminders" },
    { title = "Prioritise Current Zone First",         desc = "Float loadouts matching your current zone to the top of quick-switchers.",                         keywords = "prioritise zone first sort quick switch",        tabIndex = 1, targetTitle = "Prioritise Current Zone First" },
    { title = "Right-Click Hero Spec Swap",            desc = "Right-click Blizzard's Hero Talent medallion out of combat to switch Hero trees cleanly.",          keywords = "hero spec swap medallion right click tree",      tabIndex = 1, targetTitle = "Right-Click Hero Spec Swap" },
    { title = "Talent Tree Backdrop Studio",           desc = "Choose Blizzard Spec Art or Solid Obsidian with optional Hero-Synced or Class Glow mist.",        keywords = "backdrop background obsidian blizzard spec art tree", tabIndex = 1, targetTitle = "Base Background" },
    { title = "Background Dimmer",                     desc = "Darken Blizzard Spec Art (0%-85%) behind talent nodes for sharper readability.",                  keywords = "dimmer dark opacity spec art readability",       tabIndex = 1, targetTitle = "Background Dimmer" },
    { title = "Ambient Mist & Mist Intensity",         desc = "Layer Hero-Synced or Class Glow mist (15%-100% intensity) over either Base Background.",         keywords = "ambient mist intensity hero glow animation pulse",tabIndex = 1, targetTitle = "Ambient Mist" },
    { title = "Custom Loadout Group Order",            desc = "Drag and drop or use arrows to reorder Raid, M+, Delves, PvP, and Custom groups across Talent Dock and switchers.", keywords = "group order sort drag drop raid m+ delves pvp custom", tabIndex = 1, targetTitle = "CUSTOM LOADOUT GROUP ORDER" },
}

local function RegisterWithDynamicSuite()
    _G.DynamicSuite = _G.DynamicSuite or {}
    _G.DynamicSuite.modules = _G.DynamicSuite.modules or {}
    _G.DynamicSuite.Changelogs = _G.DynamicSuite.Changelogs or {}
    _G.DynamicSuite.Changelogs["DynamicTalent"] = DynamicTalent.CHANGELOG
    _G.DynamicSuite.Changelogs["talent"]        = DynamicTalent.CHANGELOG

    local registration = {
        id           = "talent",
        key          = "DynamicTalent",
        name         = "DynamicTalent",
        title        = "DynamicTalent",
        addonName    = "DynamicTalent",
        subtitle     = "Talent Loadouts & Binds",
        version      = VERSION,
        date         = "25/11/2026",
        order        = 35,
        icon         = ICON_COLOR,
        fallbackIcon = ICON_COLOR,
        iconWhite    = ICON_WHITE,
        iconAccent   = ICON_ACCENT,
        slash        = "/dt",
        category     = "Talent Loadouts & Binds",
        desc         = "Unlimited per-spec talent loadout library, WCL/Northern Sky/Blizzard importer, Talent window dock, Raid/M+/PvP/Zone talent binds, custom loadout group ordering, and 1-click swap reminder toasts.",
        conflictRegistry = {
            conflicts        = {},
            hardConflicts    = {},
            partialConflicts = { "TalentLoadoutManager", "TalentLoadoutsEx", "BtWLoadouts", "ImprovedTalentLoadouts" },
            softConflicts    = { "TalentLoadoutManager", "TalentLoadoutsEx", "BtWLoadouts", "ImprovedTalentLoadouts" },
            category         = "Talent Loadouts & Binds",
        },
        searchEntries = DynamicTalent.SEARCH_ENTRIES,
        GetStatusText = function() return DynamicTalent:GetStatusText() end,
        GetStatus     = function() return DynamicTalent:GetStatusText() end,
        RenderEmbedded = function(a, b)
            local parent = (type(a) == "table" and a.CreateFrame == nil and b) and b or a
            return RenderTalentEmbedded(parent)
        end,
        RenderUI = function(a, b)
            local parent = (type(a) == "table" and a.CreateFrame == nil and b) and b or a
            return RenderTalentEmbedded(parent)
        end,
        SelectSubTab = function(a1, a2, a3, a4)
            local idx = (type(a1) == "number") and a1 or a2 or 1
            local entryOrOpts = (type(a1) == "number") and a3 or ((type(a4) == "table") and a4 or ((type(a3) == "table") and a3 or nil))
            return DynamicTalent:SelectSubTab(idx, nil, entryOrOpts)
        end,
        SelectTab = function(a1, a2, a3, a4)
            local idx = (type(a1) == "number") and a1 or a2 or 1
            local entryOrOpts = (type(a1) == "number") and a3 or ((type(a4) == "table") and a4 or ((type(a3) == "table") and a3 or nil))
            return DynamicTalent:SelectSubTab(idx, nil, entryOrOpts)
        end,
        ApplyTheme          = function() DynamicTalent:ApplyTheme() end,
        ApplyThemeToUI      = function() DynamicTalent:ApplyTheme() end,
        RefreshTheme        = function() DynamicTalent:ApplyTheme() end,
        ResetModuleDefaults = function() DynamicTalent:ResetModuleDefaults() end,
        ResetDefaults       = function() DynamicTalent:ResetModuleDefaults() end,
        ResetModule         = function() DynamicTalent:ResetModuleDefaults() end,
        Reset               = function() DynamicTalent:ResetModuleDefaults() end,
        OnDisableInSuite    = function() DynamicTalent:OnDisableInSuite() end,
        OnEnableInSuite     = function() DynamicTalent:OnEnableInSuite() end,
        CHANGELOG           = DynamicTalent.CHANGELOG,
        changelog           = DynamicTalent.CHANGELOG,
    }

    _G.DynamicSuite.modules["talent"]        = registration
    _G.DynamicSuite.modules["DynamicTalent"] = registration
    if type(_G.DynamicSuite.RegisterModule) == "function" then
        pcall(_G.DynamicSuite.RegisterModule, _G.DynamicSuite, "DynamicTalent", registration)
    end
end

-- ============================================================================
-- 13. EVENTS, ADDON COMPARTMENT & SLASH COMMANDS (/dt, /dynamictalent)
-- ============================================================================
local function SafeRegisterEvent(frame, eventName)
    if not frame or not eventName then return end
    if _G.C_EventUtils and type(_G.C_EventUtils.IsEventValid) == "function" then
        if not _G.C_EventUtils.IsEventValid(eventName) then return end
    end
    frame:RegisterEvent(eventName)
end

local evt = CreateFrame("Frame")
SafeRegisterEvent(evt, "ADDON_LOADED")
SafeRegisterEvent(evt, "PLAYER_LOGIN")
SafeRegisterEvent(evt, "PLAYER_ENTERING_WORLD")
SafeRegisterEvent(evt, "ZONE_CHANGED_NEW_AREA")
SafeRegisterEvent(evt, "ZONE_CHANGED")
SafeRegisterEvent(evt, "ENCOUNTER_END")
SafeRegisterEvent(evt, "PLAYER_REGEN_DISABLED")
SafeRegisterEvent(evt, "PLAYER_REGEN_ENABLED")
SafeRegisterEvent(evt, "PLAYER_SPECIALIZATION_CHANGED")
SafeRegisterEvent(evt, "PLAYER_LOOT_SPEC_UPDATED")
SafeRegisterEvent(evt, "READY_CHECK")
SafeRegisterEvent(evt, "START_PLAYER_COUNTDOWN")
SafeRegisterEvent(evt, "PLAYER_TARGET_CHANGED")
SafeRegisterEvent(evt, "PLAYER_SOFT_ENEMY_CHANGED")
SafeRegisterEvent(evt, "NAME_PLATE_UNIT_ADDED")
SafeRegisterEvent(evt, "UPDATE_MOUSEOVER_UNIT")
SafeRegisterEvent(evt, "PLAYER_UPDATE_RESTING")
SafeRegisterEvent(evt, "TRAIT_CONFIG_UPDATED")

local function IsSafeUnitPlayer(unit)
    if type(UnitIsPlayer) ~= "function" then return false end
    local okP, isPl = pcall(UnitIsPlayer, unit)
    return okP and not _IsSecret(isPl) and isPl == true
end

local function IsPlayerRestingSafe()
    if type(IsResting) ~= "function" then return false end
    local okR, resting = pcall(IsResting)
    return okR and not _IsSecret(resting) and resting == true
end

local function IsInRaidInstanceSafe()
    if type(GetInstanceInfo) ~= "function" then return false end
    local okI, _, instType = pcall(GetInstanceInfo)
    return okI and not _IsSecret(instType) and instType == "raid"
end

local function SafeUnitGUID(unit)
    if type(UnitGUID) ~= "function" then return nil end
    local okG, guid = pcall(UnitGUID, unit)
    if okG and type(guid) == "string" and not _IsSecret(guid) and guid ~= "" then
        return guid
    end
    return nil
end

local function ShouldRunPassiveUnitBossCheck(selfObj, reason, unit, skipWhenResting)
    if IsPlayerInCombat() then return false end
    if not selfObj or not selfObj.db or selfObj.db.enabled == false or selfObj.db.talentReminderEnabled == false then
        return false
    end
    if IsModuleDisabledInSuite("DynamicTalent") then return false end
    if type(unit) ~= "string" or _IsSecret(unit) or unit == "" then return false end
    if type(UnitExists) ~= "function" then return false end
    local okE, ex = pcall(UnitExists, unit)
    if not okE or _IsSecret(ex) or not ex then return false end
    if IsSafeUnitPlayer(unit) then return false end
    if skipWhenResting and IsPlayerRestingSafe() then return false end

    local specID = selfObj:GetActiveSpecID()
    if not specID then return false end
    local bossMap = selfObj.db.talentBossMap and selfObj.db.talentBossMap[specID]
    local hasBinds = HasSpecificBossBinds(bossMap)
    local inRaid = IsInRaidInstanceSafe()
    if reason == "MOUSEOVER" then
        if not hasBinds and not (inRaid and type(bossMap) == "table") then
            return false
        end
    elseif not hasBinds then
        return false
    end

    local unitName = ResolveLiveUnitName(unit, true)
    if not unitName then return false end

    local now = (type(GetTime) == "function") and (tonumber(GetTime()) or 0) or 0
    local guid = SafeUnitGUID(unit) or ""
    local dedupeKey = reason .. "|" .. unitName:lower() .. "|" .. guid
    if selfObj._lastPassiveCheckKey == dedupeKey and (now - (selfObj._lastPassiveCheckTime or 0)) < 0.35 then
        return false
    end
    selfObj._lastPassiveCheckKey = dedupeKey
    selfObj._lastPassiveCheckTime = now

    local diffKey = inRaid and GetActiveRaidDifficultyKey() or nil
    if hasBinds and MatchBoundBossByName(selfObj, bossMap, diffKey, unitName) then
        return true
    end
    if reason == "MOUSEOVER" and inRaid then
        local _, _, _, s2Boss = selfObj:MatchBossTargetName(unitName)
        if s2Boss then
            return true
        end
    end
    return false
end

local isInitialized = false
evt:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4, arg5)
    if event == "ADDON_LOADED" then
        if (arg1 == ADDON_FOLDER or arg1 == "DynamicSuite" or arg1 == "DynamicTalent") and not isInitialized then
            isInitialized = true
            EnsureDB()
            RegisterWithDynamicSuite()
            if IsModuleDisabledInSuite("DynamicTalent") then
                if _G.DynamicSuite and _G.DynamicSuite.modules then
                    if _G.DynamicSuite.modules["talent"] then _G.DynamicSuite.modules["talent"]._disabledAtStartup = true end
                    if _G.DynamicSuite.modules["DynamicTalent"] then _G.DynamicSuite.modules["DynamicTalent"]._disabledAtStartup = true end
                end
            end
        elseif arg1 == "Blizzard_PlayerSpells" then
            if isInitialized and not IsModuleDisabledInSuite("DynamicTalent") then
                DynamicTalent:EnsureTalentDockHooks()
            end
        elseif arg1 == "Blizzard_EncounterJournal" then
            DynamicTalent._cachedTierRaids = nil
            DynamicTalent._ejEnriched = false
            DynamicTalent._ejEnrichAttempted = false
        end
    elseif event == "PLAYER_LOGIN" then
        EnsureDB()
        RegisterWithDynamicSuite()
        if not IsModuleDisabledInSuite("DynamicTalent") then
            DynamicTalent:EnsureTalentDockHooks()
            if _G.DynamicPrep and type(_G.DynamicPrep.RefreshBar) == "function" then
                pcall(_G.DynamicPrep.RefreshBar, _G.DynamicPrep)
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        lastAlertedBossMismatchKey = nil
        DynamicTalent._lastCheckedMismatchSig = nil
        DynamicTalent._lastPassiveCheckKey = nil
        if event == "PLAYER_ENTERING_WORLD" then
            DynamicTalent:InvalidateActiveTalentStringCache()
        end
        stickyRaidBoss = nil
        local function RefreshZoneContextUI()
            DynamicTalent:CheckZoneTalentLoadout()
            DynamicTalent:RefreshTalentDock()
            if _G.DynamicPrep and type(_G.DynamicPrep.RefreshBar) == "function" then
                pcall(_G.DynamicPrep.RefreshBar, _G.DynamicPrep)
            end
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(1.2, RefreshZoneContextUI)
        else
            RefreshZoneContextUI()
        end
    elseif event == "ZONE_CHANGED" then
        if stickyRaidBoss and SafeGetSubZoneText() ~= stickyRaidBoss.subZone then
            stickyRaidBoss = nil
            if not IsPlayerInCombat() then
                DynamicTalent:CheckZoneTalentLoadout()
                if _G.DynamicPrep and type(_G.DynamicPrep.RefreshBar) == "function" then
                    pcall(_G.DynamicPrep.RefreshBar, _G.DynamicPrep)
                end
            end
        end
    elseif event == "ENCOUNTER_END" then
        if not _IsSecret(arg5) and arg5 == 1 then
            stickyRaidBoss = nil
            lastAlertedBossMismatchKey = nil
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        CloseAllDynamicTalentPopups()
        DynamicTalent:HideTalentReminderToast()
        DynamicTalent:HideTalentPopover()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if DynamicTalent._pendingSaveConfigID and C_ClassTalents and type(C_ClassTalents.SaveConfig) == "function" then
            local saveID = DynamicTalent._pendingSaveConfigID
            DynamicTalent._pendingSaveConfigID = nil
            pcall(C_ClassTalents.SaveConfig, saveID)
        end
        if pendingDockRefresh then
            pendingDockRefresh = false
            DynamicTalent:RefreshTalentDock()
        end
        local psf = _G.PlayerSpellsFrame
        local tf = psf and psf.TalentsFrame
        local tfVisible = psf and psf.IsShown and psf:IsShown() and tf and tf.IsShown and tf:IsShown()
        local isEnabled = not IsModuleDisabledInSuite("DynamicTalent") and EnsureDB().enabled ~= false
        if pendingBackdropRefresh or DynamicTalent._pendingBackdropRefresh then
            pendingBackdropRefresh = false
            DynamicTalent._pendingBackdropRefresh = false
            if not isEnabled then
                DynamicTalent:HideTalentTreeBackdrop()
            elseif tfVisible then
                DynamicTalent:EnsureHeroMedallionHooks()
                DynamicTalent:UpdateTalentTreeBackdrop()
            end
        elseif tfVisible and isEnabled then
            DynamicTalent:EnsureHeroMedallionHooks()
            DynamicTalent:UpdateTalentTreeBackdrop()
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if arg1 == nil or (not _IsSecret(arg1) and arg1 == "player") then
            lastAlertedBossMismatchKey = nil
            DynamicTalent._lastCheckedMismatchSig = nil
            DynamicTalent._lastPassiveCheckKey = nil
            stickyRaidBoss = nil
            wipe(silencedTalentMismatches)
            DynamicTalent._heroTreeCache = nil
            DynamicTalent:InvalidateActiveTalentStringCache()
            DynamicTalent:RefreshTalentDock()
            DynamicTalent:EnsureHeroMedallionHooks()
            DynamicTalent:UpdateTalentTreeBackdrop()
            if talentMgrModal and talentMgrModal:IsShown() then
                if talentMgrModal.RefreshQuickStartStrip then talentMgrModal:RefreshQuickStartStrip() end
                if talentMgrModal.RefreshBossList then talentMgrModal:RefreshBossList() end
            end
            if activeEmbeddedRoot and activeEmbeddedRoot:IsShown() and activeEmbeddedRoot.RefreshActionStrip then
                activeEmbeddedRoot:RefreshActionStrip()
            end
            if _G.DynamicPrep and type(_G.DynamicPrep.RefreshBar) == "function" then
                pcall(_G.DynamicPrep.RefreshBar, _G.DynamicPrep)
            end
        end
    elseif event == "PLAYER_LOOT_SPEC_UPDATED" then
        DynamicTalent:RefreshTalentDock()
    elseif event == "READY_CHECK" or event == "START_PLAYER_COUNTDOWN" then
        DynamicTalent:CheckZoneTalentLoadout(event)
    elseif event == "PLAYER_TARGET_CHANGED" then
        DynamicTalent:CheckBossTalentLoadout("TARGET")
    elseif event == "PLAYER_SOFT_ENEMY_CHANGED" then
        if ShouldRunPassiveUnitBossCheck(DynamicTalent, "SOFT_ENEMY", "softenemy", false) then
            DynamicTalent:CheckBossTalentLoadout("SOFT_ENEMY")
        end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if type(arg1) == "string" and not _IsSecret(arg1) and arg1 ~= ""
            and ShouldRunPassiveUnitBossCheck(DynamicTalent, "NAMEPLATE", arg1, false) then
            DynamicTalent:CheckBossTalentLoadout("NAMEPLATE")
        end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if ShouldRunPassiveUnitBossCheck(DynamicTalent, "MOUSEOVER", "mouseover", true) then
            DynamicTalent:CheckBossTalentLoadout("MOUSEOVER")
        end
    elseif event == "PLAYER_UPDATE_RESTING" then
        if not IsPlayerInCombat() then
            DynamicTalent:CheckZoneTalentLoadout()
        end
    elseif event == "TRAIT_CONFIG_UPDATED" then
        lastAlertedBossMismatchKey = nil
        DynamicTalent._lastCheckedMismatchSig = nil
        DynamicTalent._lastPassiveCheckKey = nil
        DynamicTalent._heroTreeCache = nil
        DynamicTalent:InvalidateActiveTalentStringCache()
        if DynamicTalent._pendingSaveConfigID and not IsPlayerInCombat() and C_ClassTalents and type(C_ClassTalents.SaveConfig) == "function" then
            local saveID = DynamicTalent._pendingSaveConfigID
            DynamicTalent._pendingSaveConfigID = nil
            pcall(C_ClassTalents.SaveConfig, saveID)
        end
        if DynamicTalent._pendingAppliedEntry then
            local appliedEntry = DynamicTalent._pendingAppliedEntry
            local appliedSpec = DynamicTalent._pendingAppliedSpecID or DynamicTalent:GetActiveSpecID()
            DynamicTalent._pendingAppliedEntry = nil
            DynamicTalent._pendingAppliedSpecID = nil
            local postStr = DynamicTalent:GetActiveTalentString()
            if postStr and postStr ~= "" then
                appliedEntry.liveHash = postStr
                if appliedSpec and DynamicTalent.db then
                    DynamicTalent.db.lastAppliedTalentID = DynamicTalent.db.lastAppliedTalentID or {}
                    DynamicTalent.db.lastAppliedTalentID[appliedSpec] = EnsureEntryID(appliedEntry, DynamicTalent.db)
                    DynamicTalent.db.lastAppliedTalentName = DynamicTalent.db.lastAppliedTalentName or {}
                    DynamicTalent.db.lastAppliedTalentName[appliedSpec] = appliedEntry.name
                    DynamicTalent.db.lastAppliedTalentLiveStr = DynamicTalent.db.lastAppliedTalentLiveStr or {}
                    DynamicTalent.db.lastAppliedTalentLiveStr[appliedSpec] = postStr
                end
            end
        end
        DynamicTalent:HideTalentReminderToast()
        DynamicTalent:SyncTalentBindsUI()
        DynamicTalent:UpdateTalentTreeBackdrop()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.05, function() DynamicTalent:UpdateTalentTreeBackdrop() end)
        end
    end
end)

_G.DynamicTalent_OnAddonCompartmentClick = function(_, buttonName)
    if buttonName == "RightButton" then
        DynamicTalent:OpenTalentManagerModal(2)
    else
        DynamicTalent:Open()
    end
end

function DynamicTalent:DiagnoseActiveRecommendation()
    local mID, mName, mLabel = self:GetActiveTalentMismatch()
    local d = self._lastDiag or {}
    local zc = d.zc or DetectCurrentZoneContext()
    local specID = d.specID or self:GetActiveSpecID()
    local activeEntry = specID and self:GetActiveTalentLibraryEntry(specID) or nil
    local activeLabel = activeEntry and (self:FormatTalentBadge(activeEntry) .. " " .. tostring(activeEntry.name)) or "Blizzard / Unsaved Build"
    local zoneDesc = (zc.instName ~= "" and zc.instName or "Open World")
    if zc.isRaid and d.diffLbl then
        zoneDesc = zoneDesc .. " (" .. d.diffLbl .. ")"
    end
    if d.subZone and d.subZone ~= "" then
        zoneDesc = zoneDesc .. " - " .. d.subZone
    end
    local src = d.source or self:GetActiveContentGroup()
    local ruleDesc = d.ruleDesc or (d.ruleName and (d.bossName and (d.bossName .. " -> " .. d.ruleName) or d.ruleName))
        or (mName and (tostring(mLabel or "Zone") .. " -> " .. tostring(mName)) or "No matching rule")
    local status = d.status or (mID and "Swap recommended" or "Already active / No swap needed")

    local tgtN = ResolveLiveUnitName("target", false) or "none"
    local softN = ResolveLiveUnitName("softenemy", false) or "none"
    local focN = ResolveLiveUnitName("focus", false) or "none"
    local b1N = ResolveLiveUnitName("boss1", false) or "none"
    local stickyDesc = (stickyRaidBoss and stickyRaidBoss.bossName)
        and string.format("%s (%s)", tostring(stickyRaidBoss.bossName), tostring(stickyRaidBoss.subZone ~= "" and stickyRaidBoss.subZone or "raid"))
        or "none"

    Print(string.format("Zone: |cFFFFFFFF%s|r | Active: %s", zoneDesc, activeLabel))
    Print(string.format("Source: |cFF38BDF8%s|r | Winning Rule: |cFFFBBF24%s|r | Status: |cFF34D399%s|r", tostring(src), tostring(ruleDesc), tostring(status)))
    Print(string.format("Units: target=|cFFFFFFFF%s|r, soft=|cFFFFFFFF%s|r, focus=|cFFFFFFFF%s|r, boss1=|cFFFFFFFF%s|r | Sticky: |cFFFBBF24%s|r", tgtN, softN, focN, b1N, stickyDesc))
end

_G.SLASH_DYNAMICTALENT1 = "/dt"
_G.SLASH_DYNAMICTALENT2 = "/dynamictalent"
_G.SlashCmdList["DYNAMICTALENT"] = function(msg)
    local cmd = SafeTrim(msg or ""):lower()
    if cmd == "binds" or cmd == "mgr" or cmd == "manager" then
        DynamicTalent:OpenTalentManagerModal(2)
    elseif cmd == "why" or cmd == "debug" then
        DynamicTalent:DiagnoseActiveRecommendation()
    elseif cmd == "reset" then
        DynamicTalent:ResetModuleDefaults()
    elseif cmd == "edit" or cmd == "hud" then
        if _G.DynamicSuite and type(_G.DynamicSuite.EnterHudEditMode) == "function" then
            _G.DynamicSuite:EnterHudEditMode("ALL")
        else
            DynamicTalent:Open(2)
            Print("Alert Toast position and style follow Suite Studio (/ds studio) -> Shared Alert Toast HUD.")
        end
    else
        DynamicTalent:Open()
    end
end
