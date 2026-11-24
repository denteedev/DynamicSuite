-- [DynamicPrep M+ Secret-Value Shield & Zero-Lag Fast-Path]
local _rawConcat = table.concat
local _dpStatCache = {}
local _dpSimSecretMode = false

local function _IsSecret(v)
    if type(issecretvalue) == "function" and issecretvalue(v) then
        return true
    end
    if type(canaccessvalue) == "function" and not canaccessvalue(v) then
        return true
    end
    if v == nil then return false end
    if _dpSimSecretMode and type(v) == "table" and v.__dpSecret then return true end
    return false
end

local function IsPlayerInCombat()
    if _G.DynamicPrep and _G.DynamicPrep._inCombatState then return true end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then return true end
    if type(UnitAffectingCombat) == "function" then
        local ok, ac = pcall(UnitAffectingCombat, "player")
        if ok and not _IsSecret(ac) and ac then return true end
    end
    return false
end


local function _AreAurasSecret(unit)
    if _dpSimSecretMode then return true end
    if InCombatLockdown and InCombatLockdown() then return true end
    if C_Secrets then
        if C_Secrets.ShouldAurasBeSecret then
            local ok, res = pcall(C_Secrets.ShouldAurasBeSecret)
            if ok and res then return true end
            if unit then
                local okU, resU = pcall(C_Secrets.ShouldAurasBeSecret, unit)
                if okU and resU then return true end
            end
        end
        if unit and C_Secrets.ShouldUnitAurasBeSecret then
            local okU, resU = pcall(C_Secrets.ShouldUnitAurasBeSecret, unit)
            if okU and resU then return true end
        end
    end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
        return true
    end
    if IsEncounterInProgress and IsEncounterInProgress() then
        return true
    end
    if C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress and C_InstanceEncounter.IsEncounterInProgress() then
        return true
    end
    return false
end


local function _IsAuraIndexSecret(unit, index, filter)
    if _AreAurasSecret(unit) then return true end
    if C_Secrets then
        if C_Secrets.ShouldUnitAuraIndexBeSecret then
            local ok, res = pcall(C_Secrets.ShouldUnitAuraIndexBeSecret, unit, index, filter or "HELPFUL")
            if ok and res then return true end
        end
        if C_Secrets.ShouldUnitAuraSlotBeSecret then
            local ok, res = pcall(C_Secrets.ShouldUnitAuraSlotBeSecret, unit, index)
            if ok and res then return true end
        end
    end
    return false
end


local function _IsInActiveKeyOrCombat()
    if _dpSimSecretMode then return true end
    if InCombatLockdown and InCombatLockdown() then
        return true
    end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
        return true
    end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, res = pcall(C_Secrets.ShouldAurasBeSecret)
        if ok and res then return true end
    end
    return false
end


local function _SafeNum(key, val, fallback)
    if not _IsSecret(val) and val ~= nil and type(val) == "number" then
        _dpStatCache[key] = val
        return val
    end
    return _dpStatCache[key] or fallback or 0
end

local function _WrapStatFn(name, fn)
    return function(a1, a2, ...)
        local k1 = name .. ":" .. tostring(a1 or "") .. ":" .. tostring(a2 or "") .. ":1"
        local k2 = name .. ":" .. tostring(a1 or "") .. ":" .. tostring(a2 or "") .. ":2"
        if _IsInActiveKeyOrCombat() and _dpStatCache[k1] ~= nil then
            return _dpStatCache[k1], (_dpStatCache[k2] or 0), 0, 0
        end
        if type(fn) ~= "function" then return (_dpStatCache[k1] or 0), (_dpStatCache[k2] or 0), 0, 0 end
        local r1, r2, r3, r4 = fn(a1, a2, ...)
        if _dpSimSecretMode then
            r1 = { __dpSecret = true }
            r2 = { __dpSecret = true }
        end
        local s1 = _SafeNum(k1, r1, 0)
        local s2 = (r2 ~= nil) and _SafeNum(k2, r2, 0) or (_dpStatCache[k2] or 0)
        return s1, s2, r3, r4
    end
end

local UnitStat              = _WrapStatFn("UnitStat",              _G.UnitStat)
local GetCritChance         = _WrapStatFn("GetCritChance",         _G.GetCritChance)
local GetHaste              = _WrapStatFn("GetHaste",              _G.GetHaste)
local GetMasteryEffect      = _WrapStatFn("GetMasteryEffect",      _G.GetMasteryEffect)
local GetCombatRating       = _WrapStatFn("GetCombatRating",       _G.GetCombatRating)
local GetCombatRatingBonus  = _WrapStatFn("GetCombatRatingBonus",  _G.GetCombatRatingBonus)
local GetVersatilityBonus   = _WrapStatFn("GetVersatilityBonus",   _G.GetVersatilityBonus)
local GetSpeed              = _WrapStatFn("GetSpeed",              _G.GetSpeed)
local GetLifesteal          = _WrapStatFn("GetLifesteal",          _G.GetLifesteal)
local GetAvoidance          = _WrapStatFn("GetAvoidance",          _G.GetAvoidance)
local GetDodgeChance        = _WrapStatFn("GetDodgeChance",        _G.GetDodgeChance)
local GetParryChance        = _WrapStatFn("GetParryChance",        _G.GetParryChance)
local GetBlockChance        = _WrapStatFn("GetBlockChance",        _G.GetBlockChance)
local GetArmorEffectiveness = _WrapStatFn("GetArmorEffectiveness", _G.GetArmorEffectiveness)

local function SafeTableConcat(tbl, sep, i, j)
    if type(tbl) ~= "table" then return "" end
    sep = sep or ""
    local ok, res = pcall(_rawConcat, tbl, sep, i, j)
    if ok and not _IsSecret(res) then
        return res
    end
    local clean = {}
    local s = i or 1
    local e = j or #tbl
    for idx = s, e do
        local v = tbl[idx]
        if v ~= nil and not _IsSecret(v) and type(v) ~= "table" then
            clean[#clean + 1] = tostring(v)
        end
    end
    local ok2, res2 = pcall(_rawConcat, clean, sep)
    return (ok2 and res2) or ""
end
-- ============================================================================
-- DynamicPrep (/dprep)
-- Real-Time Character Readiness Bar, Midnight Omni Folio Tracker,
-- and Lightweight Everyday Convenience Automation for DynamicSuite.
-- ============================================================================

local ADDON_NAME = ...
local ADDON_FOLDER = (type(ADDON_NAME) == "string" and ADDON_NAME ~= "") and ADDON_NAME or "DynamicSuite"

local function ResolveAddonVersion(folderName, fallback)
    local fb = fallback or "2.9.0"
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

local function ShouldYieldToOtherInstall(addonFolder, standaloneName, thisVersion, globalTbl)
    local isAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
    local getAddOnEnableState = (C_AddOns and C_AddOns.GetAddOnEnableState) or _G.GetAddOnEnableState
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    local function isOtherEnabled(name)
        if type(isAddOnLoaded) == "function" and isAddOnLoaded(name) then
            return true
        end
        if type(getAddOnEnableState) == "function" then
            local pName = type(_G.UnitName) == "function" and _G.UnitName("player") or nil
            if type(pName) == "string" and pName ~= "" and pName ~= "Unknown" and pName ~= _G.UNKNOWNOBJECT then
                local ok, st = pcall(getAddOnEnableState, name, pName)
                if ok and type(st) == "number" and st > 0 then return true end
            end
            local ok2, st2 = pcall(getAddOnEnableState, name)
            if ok2 and type(st2) == "number" and st2 > 0 then return true end
        end
        return false
    end
    if addonFolder ~= "DynamicSuite" then
        if type(globalTbl) == "table" and globalTbl._loadedBySuite then
            local suiteVer = globalTbl._loadedVersion or globalTbl.version or globalTbl.VERSION or (_G.DynamicSuite and _G.DynamicSuite.version) or "2.6.6"
            if CompareSemVer(thisVersion, suiteVer) <= 0 then
                return true
            end
        end
        if isOtherEnabled("DynamicSuite") and type(getMeta) == "function" then
            local okS, sVer = pcall(getMeta, "DynamicSuite", "Version")
            if okS and type(sVer) == "string" and sVer ~= "" and not sVer:find("@") then
                if CompareSemVer(thisVersion, sVer) <= 0 then
                    return true
                end
            end
        end
    else
        if type(globalTbl) == "table" and globalTbl._loadedBySuite == false then
            local stLoadedVer = globalTbl._loadedVersion or globalTbl.version or globalTbl.VERSION or "0.0.0"
            if CompareSemVer(stLoadedVer, thisVersion) >= 0 then
                return true
            end
        end
        if isOtherEnabled(standaloneName) and type(getMeta) == "function" then
            local okV, stVer = pcall(getMeta, standaloneName, "Version")
            if okV and type(stVer) == "string" and stVer ~= "" and not stVer:find("@") then
                if CompareSemVer(stVer, thisVersion) > 0 then
                    return true
                end
            end
        end
    end
    return false
end


local VERSION = ResolveAddonVersion(ADDON_FOLDER, "2.9.0")
if ShouldYieldToOtherInstall(ADDON_FOLDER, "DynamicPrep", VERSION, _G.DynamicPrep) then
    return
end
local DP_NS = {}
local isInitialized = false

local function IsModuleDisabledInSuite(modName)
    local key = modName or "DynamicPrep"
    local shortK = key:gsub("^Dynamic", ""):lower()
    local db = _G.DynamicSuiteDB
    if type(db) == "table" then
        if type(db.disabledModules) == "table" and (db.disabledModules[key] or db.disabledModules[shortK]) then
            return true
        end
        if type(db.global) == "table" and type(db.global.disabledModules) == "table" and (db.global.disabledModules[key] or db.global.disabledModules[shortK]) then
            return true
        end
    end
    return false
end


local Suite = _G.DynamicSuite or {}
_G.DynamicSuite = Suite
Suite.modules = Suite.modules or {}
Suite.Changelogs = Suite.Changelogs or {}

local DynamicPrep = _G.DynamicPrep or DP_NS
_G.DynamicPrep = DynamicPrep
DynamicPrep._loadedBySuite = (ADDON_FOLDER == "DynamicSuite")
DynamicPrep._loadedVersion = VERSION
DynamicPrep.version = VERSION
DynamicPrep.addonName = "DynamicPrep"
-- ============================================================================
-- Safe WoW Retail 12.1.5 / 12.1.7 API Wrappers
-- ============================================================================
local AddOns = C_AddOns or {
    GetNumAddOns        = _G.GetNumAddOns,
    GetAddOnInfo        = _G.GetAddOnInfo,
    EnableAddOn         = _G.EnableAddOn,
    DisableAddOn        = _G.DisableAddOn,
    IsAddOnLoaded       = _G.IsAddOnLoaded,
    GetAddOnEnableState = _G.GetAddOnEnableState,
    GetAddOnMetadata    = _G.GetAddOnMetadata,
}

local function IsAddonEnabledForPlayer(addonName)
    if not addonName then return false end
    local player = UnitName("player")
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        local ok, state = pcall(C_AddOns.GetAddOnEnableState, addonName, player)
        if ok and state and state > 0 then return true end
        local ok2, state2 = pcall(C_AddOns.GetAddOnEnableState, player, addonName)
        if ok2 and state2 and state2 > 0 then return true end
    end
    if AddOns.IsAddOnLoaded and AddOns.IsAddOnLoaded(addonName) then
        return true
    end
    return false
end


local _backdropCache = {}
local function SetPixelBackdrop(frame, bgColor, borderColor, edgePixels)
    if not frame or not frame.SetBackdrop then return end
    local scale = frame:GetEffectiveScale() or 1
    local px = (PixelUtil and PixelUtil.GetNearestPixelSize) and PixelUtil.GetNearestPixelSize(edgePixels or 1, scale) or (edgePixels or 1)
    if px <= 0 then px = 1 end
    if frame._dpEdgePx ~= px then
        frame._dpEdgePx = px
        local bd = _backdropCache[px]
        if not bd then
            bd = {
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = px,
                insets = { left = px, right = px, top = px, bottom = px },
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

-- ============================================================================
-- Suite Font Family, Accent Color & Theme Helpers
-- ============================================================================
local ICON_CHECK        = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_check.tga"
local ICON_CHEVRON_DOWN = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga"
local ICON_CHEVRON_UP   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga"
local ICON_COG          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_cog.tga"

local trackedFontStrings = {}
local trackedAccentTexts = {}

local function RGBToHex(r, g, b)
    r = math.max(0, math.min(1, tonumber(r) or 0.220))
    g = math.max(0, math.min(1, tonumber(g) or 0.741))
    b = math.max(0, math.min(1, tonumber(b) or 0.973))
    return string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

if type(Suite.GetSuiteAccent) ~= "function" then
    function Suite:GetSuiteAccent()
        if _G.DynamicLoadUI and type(_G.DynamicLoadUI.GetActiveAccentRGB) == "function" then
            local ok, r, g, b = pcall(_G.DynamicLoadUI.GetActiveAccentRGB)
            if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
                return r, g, b, RGBToHex(r, g, b)
            end
        end
        if _G.DynamicLoadUI and type(_G.DynamicLoadUI.GetThemeColors) == "function" then
            local ok, pal = pcall(_G.DynamicLoadUI.GetThemeColors)
            if ok and type(pal) == "table" and type(pal.accent) == "table" then
                local r, g, b = pal.accent[1] or 0.220, pal.accent[2] or 0.741, pal.accent[3] or 0.973
                return r, g, b, RGBToHex(r, g, b)
            end
        end
        if type(self.GetAccentColor) == "function" then
            local ok, r, g, b = pcall(self.GetAccentColor, self)
            if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
                return r, g, b, RGBToHex(r, g, b)
            end
        end
        return 0.220, 0.741, 0.973, "38BDF8"
    end
end

local function SanitizeHex6(hex, r, g, b)
    if type(hex) == "string" and hex ~= "" then
        local clean = hex:gsub("^|c", ""):gsub("^#", "")
        if #clean == 8 then
            clean = clean:sub(3, 8)
        end
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
    return 0.220, 0.741, 0.973, "38BDF8"
end

local function GetAccentColorTable(alpha)
    local r, g, b = GetActiveAccentRGB()
    return { r, g, b, alpha or 1.0 }
end

local function GetAccentHex()
    local r, g, b, hex = GetActiveAccentRGB()
    return SanitizeHex6(hex, r, g, b)
end

local function GetPlayerClassColor()
    local _, classFile = UnitClass("player")
    if classFile and C_ClassColor and C_ClassColor.GetClassColor then
        local colorObj = C_ClassColor.GetClassColor(classFile)
        if colorObj and colorObj.GetRGB then
            local r, g, b = colorObj:GetRGB()
            return r, g, b, RGBToHex(r, g, b)
        end
    end
    if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        return c.r, c.g, c.b, RGBToHex(c.r, c.g, c.b)
    end
    return GetActiveAccentRGB()
end

local function GetActiveFontPath()
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.GetFont) == "function" then local okF, pF = pcall(_G.DynamicSuite.UI.GetFont); if okF and type(pF) == "string" and pF ~= "" then return pF end end
    if _G.DynamicLoadUI and _G.DynamicLoadUI.GetActiveFontPath then
        local ok, fontPath = pcall(_G.DynamicLoadUI.GetActiveFontPath)
        if ok and type(fontPath) == "string" and fontPath ~= "" then
            return fontPath
        end
    end
    if Suite and type(Suite.GetActiveFontPath) == "function" then
        local ok, fontPath = pcall(Suite.GetActiveFontPath, Suite)
        if ok and type(fontPath) == "string" and fontPath ~= "" then
            return fontPath
        end
    end
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function CreateText(parent, layer, template, customSize, customFlags)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontHighlightSmall")
    local _, defaultSize, defaultFlags = fs:GetFont()
    fs._dpFontSize = customSize or defaultSize or 12
    fs._dpFontFlags = customFlags or defaultFlags or ""
    local activeFont = GetActiveFontPath()
    if activeFont and fs.SetFont then
        pcall(fs.SetFont, fs, activeFont, fs._dpFontSize, fs._dpFontFlags)
    end
    table.insert(trackedFontStrings, fs)
    return fs
end

local function ApplyPrepThemeToUI()
    local activeFont = GetActiveFontPath()
    for _, fs in ipairs(trackedFontStrings) do
        if fs and fs.SetFont then
            pcall(fs.SetFont, fs, activeFont, fs._dpFontSize or 12, fs._dpFontFlags or "")
        end
    end
    local ar, ag, ab = GetActiveAccentRGB()
    for _, item in ipairs(trackedAccentTexts) do
        if item and item.fs and item.fs.SetTextColor then
            item.fs:SetTextColor(ar, ag, ab, 1.0)
        end
    end
    if DynamicPrep.standaloneShell and DynamicPrep.standaloneShell.logoAccentTex then
        DynamicPrep.standaloneShell.logoAccentTex:SetVertexColor(ar, ag, ab, 1.0)
    end
    if DynamicPrep.ResetStableCapsuleWidths then
        DynamicPrep:ResetStableCapsuleWidths()
    end
    if DynamicPrep.prepBarFrame then
        DynamicPrep:RefreshBar()
    end
    if DynamicPrep.RefreshCombatBuffAlert then
        DynamicPrep:RefreshCombatBuffAlert()
    end
    if DynamicPrep.ApplyTalentReminderToastVisuals then
        DynamicPrep:ApplyTalentReminderToastVisuals()
    end
    if DynamicPrep.ApplyMageFoodToastVisuals then
        DynamicPrep:ApplyMageFoodToastVisuals()
    end
    if DynamicPrep.ApplyDurabilityToastVisuals then
        DynamicPrep:ApplyDurabilityToastVisuals()
    end
    if DynamicPrep.workspaceFrame and DynamicPrep.workspaceFrame:IsShown() then
        DynamicPrep:RefreshWorkspaceView()
    end
end

DynamicPrep.ApplyThemeToUI = ApplyPrepThemeToUI
DynamicPrep.ApplyTheme = ApplyPrepThemeToUI
DynamicPrep.RefreshTheme = ApplyPrepThemeToUI

-- ============================================================================
-- Obsidian Design Tokens
-- ============================================================================
local COLORS = {
    BgVoid        = { 0.035, 0.039, 0.051, 0.98 }, -- #090A0D
    BgBarSurface  = { 0.035, 0.043, 0.059, 0.96 }, -- #090B0F
    BgCanvas      = { 0.067, 0.075, 0.094, 0.96 }, -- #111318
    BgSurface     = { 0.090, 0.102, 0.129, 1.00 }, -- #171A21
    BgElevated    = { 0.122, 0.141, 0.176, 1.00 }, -- #1F242D
    BgHover       = { 0.145, 0.169, 0.212, 1.00 }, -- #252B36
    CapsuleBg     = { 1.000, 1.000, 1.000, 0.04 }, -- #FFFFFF0A
    CapsuleBorder = { 1.000, 1.000, 1.000, 0.08 }, -- #FFFFFF14
    BorderSubtle  = { 1.000, 1.000, 1.000, 0.08 },
    BorderStrong  = { 1.000, 1.000, 1.000, 0.15 },
    Silver        = { 0.796, 0.835, 0.882, 1.00 }, -- #CBD5E1
    Gold          = { 0.984, 0.749, 0.141, 1.00 }, -- #FBBF24
    Green         = { 0.204, 0.827, 0.600, 1.00 }, -- #34D399
    Red           = { 0.973, 0.443, 0.443, 1.00 }, -- #F87171
}

-- ============================================================================
-- All 40 Retail Specializations: Recommended Stat Priority & Omni Folio Matrix
-- ============================================================================
local STAT_LABELS = {
    HASTE   = "Haste",
    MASTERY = "Mastery",
    CRIT    = "Critical Strike",
    VERS    = "Versatility",
    OFF     = "Off",
}

local STAT_SHORT = {
    HASTE   = "Haste",
    MASTERY = "Mast",
    CRIT    = "Crit",
    VERS    = "Vers",
    OFF     = "Off",
}

local VALID_FOLIO_TARGET_STATS = { HASTE = true, MASTERY = true, CRIT = true, VERS = true, OFF = true }
local VALID_FOLIO_ACTIVE_STATS = { HASTE = true, MASTERY = true, CRIT = true, VERS = true }
local FOLIO_ITEM_PATTERNS = { "omnium folio", "omni folio", "folio" }
local FOLIO_MOTE_PATTERNS = { "mote of omnial inquiry", "omnial inquiry" }
local FOLIO_BUFF_ANCHORS  = { "omnium", "folio", "omnidirectional", "thalassian", "attunement" }
local FOLIO_RUNE_CATALOG  = {
    { key = "HASTE",   label = "Haste",           short = "Haste", patterns = { "haste" },   requiresAnchor = true },
    { key = "MASTERY", label = "Mastery",         short = "Mast",  patterns = { "mastery" }, requiresAnchor = true },
    { key = "CRIT",    label = "Critical Strike", short = "Crit",  patterns = { "crit" },    requiresAnchor = true },
    { key = "VERS",    label = "Versatility",     short = "Vers",  patterns = { "vers" },    requiresAnchor = true },
}
local NEUTRAL_SPEC_META = {
    name    = "Unknown",
    mplus   = "HASTE",
    raid    = "HASTE",
    delve   = "HASTE",
    pvp     = "VERS",
    weights = { "HASTE", "CRIT", "MASTERY", "VERS" },
}

local SPEC_DATA = {
    -- Death Knight
    [250]  = { name = "Blood",         mplus = "HASTE",   raid = "HASTE",   delve = "HASTE",   pvp = "VERS", weights = { "HASTE", "VERS", "CRIT", "MASTERY" } },
    [251]  = { name = "Frost",         mplus = "MASTERY", raid = "CRIT",    delve = "CRIT",    pvp = "VERS", weights = { "MASTERY", "CRIT", "HASTE", "VERS" } },
    [252]  = { name = "Unholy",        mplus = "MASTERY", raid = "MASTERY", delve = "MASTERY", pvp = "VERS", weights = { "MASTERY", "HASTE", "CRIT", "VERS" } },
    -- Demon Hunter
    [577]  = { name = "Havoc",         mplus = "MASTERY", raid = "CRIT",    delve = "CRIT",    pvp = "VERS", weights = { "CRIT", "MASTERY", "HASTE", "VERS" } },
    [581]  = { name = "Vengeance",     mplus = "HASTE",   raid = "HASTE",   delve = "HASTE",   pvp = "VERS", weights = { "HASTE", "VERS", "CRIT", "MASTERY" } },
    [1480] = { name = "Devourer",      mplus = "HASTE",   raid = "HASTE",   delve = "HASTE",   pvp = "VERS", weights = { "HASTE", "MASTERY", "CRIT", "VERS" } },
    -- Druid
    [102]  = { name = "Balance",       mplus = "MASTERY", raid = "MASTERY", delve = "MASTERY", pvp = "VERS", weights = { "MASTERY", "HASTE", "CRIT", "VERS" } },
    [103]  = { name = "Feral",         mplus = "MASTERY", raid = "MASTERY", delve = "CRIT",    pvp = "VERS", weights = { "MASTERY", "CRIT", "HASTE", "VERS" } },
    [104]  = { name = "Guardian",      mplus = "HASTE",   raid = "HASTE",   delve = "HASTE",   pvp = "VERS", weights = { "HASTE", "VERS", "MASTERY", "CRIT" } },
    [105]  = { name = "Restoration",   mplus = "HASTE",   raid = "HASTE",   delve = "HASTE",   pvp = "VERS", weights = { "HASTE", "MASTERY", "VERS", "CRIT" } },
    -- Evoker
    [1467] = { name = "Devastation",   mplus = "MASTERY", raid = "MASTERY", delve = "CRIT",    pvp = "VERS", weights = { "MASTERY", "CRIT", "HASTE", "VERS" } },
    [1468] = { name = "Preservation",  mplus = "MASTERY", raid = "MASTERY", delve = "MASTERY", pvp = "VERS", weights = { "MASTERY", "CRIT", "HASTE", "VERS" } },
    [1473] = { name = "Augmentation",  mplus = "MASTERY", raid = "MASTERY", delve = "MASTERY", pvp = "VERS", weights = { "MASTERY", "HASTE", "CRIT", "VERS" } },
    -- Hunter
    [253]  = { name = "Beast Mastery", mplus = "HASTE",   raid = "HASTE",   delve = "CRIT",    pvp = "VERS", weights = { "HASTE", "CRIT", "MASTERY", "VERS" } },
    [254]  = { name = "Marksmanship",  mplus = "MASTERY", raid = "MASTERY", delve = "CRIT",    pvp = "VERS", weights = { "MASTERY", "CRIT", "HASTE", "VERS" } },
    [255]  = { name = "Survival",      mplus = "HASTE",   raid = "HASTE",   delve = "CRIT",    pvp = "VERS", weights = { "HASTE", "CRIT", "MASTERY", "VERS" } },
    -- Mage
    [62]   = { name = "Arcane",        mplus = "HASTE",   raid = "HASTE",   delve = "HASTE",   pvp = "VERS", weights = { "HASTE", "MASTERY", "CRIT", "VERS" } },
    [63]   = { name = "Fire",          mplus = "HASTE",   raid = "HASTE",   delve = "HASTE",   pvp = "VERS", weights = { "HASTE", "VERS", "MASTERY", "CRIT" } },
    [64]   = { name = "Frost",         mplus = "HASTE",   raid = "HASTE",   delve = "CRIT",    pvp = "VERS", weights = { "HASTE", "CRIT", "VERS", "MASTERY" } },
    -- Monk
    [268]  = { name = "Brewmaster",    mplus = "VERS",    raid = "VERS",    delve = "CRIT",    pvp = "VERS", weights = { "VERS", "CRIT", "MASTERY", "HASTE" } },
    [270]  = { name = "Mistweaver",    mplus = "HASTE",   raid = "HASTE",   delve = "HASTE",   pvp = "VERS", weights = { "HASTE", "CRIT", "VERS", "MASTERY" } },
    [269]  = { name = "Windwalker",    mplus = "MASTERY", raid = "MASTERY", delve = "CRIT",    pvp = "VERS", weights = { "MASTERY", "VERS", "CRIT", "HASTE" } },
    -- Paladin
    [65]   = { name = "Holy",          mplus = "HASTE",   raid = "HASTE",   delve = "CRIT",    pvp = "VERS", weights = { "HASTE", "CRIT", "MASTERY", "VERS" } },
    [66]   = { name = "Protection",    mplus = "HASTE",   raid = "HASTE",   delve = "HASTE",   pvp = "VERS", weights = { "HASTE", "MASTERY", "VERS", "CRIT" } },
    [70]   = { name = "Retribution",   mplus = "MASTERY", raid = "MASTERY", delve = "HASTE",   pvp = "VERS", weights = { "MASTERY", "HASTE", "CRIT", "VERS" } },
    -- Priest
    [256]  = { name = "Discipline",    mplus = "HASTE",   raid = "HASTE",   delve = "HASTE",   pvp = "VERS", weights = { "HASTE", "CRIT", "MASTERY", "VERS" } },
    [257]  = { name = "Holy",          mplus = "CRIT",    raid = "CRIT",    delve = "CRIT",    pvp = "VERS", weights = { "CRIT", "MASTERY", "HASTE", "VERS" } },
    [258]  = { name = "Shadow",        mplus = "HASTE",   raid = "HASTE",   delve = "HASTE",   pvp = "VERS", weights = { "HASTE", "MASTERY", "CRIT", "VERS" } },
    -- Rogue
    [259]  = { name = "Assassination", mplus = "CRIT",    raid = "CRIT",    delve = "CRIT",    pvp = "VERS", weights = { "CRIT", "MASTERY", "HASTE", "VERS" } },
    [260]  = { name = "Outlaw",        mplus = "VERS",    raid = "VERS",    delve = "CRIT",    pvp = "VERS", weights = { "VERS", "HASTE", "CRIT", "MASTERY" } },
    [261]  = { name = "Subtlety",      mplus = "MASTERY", raid = "MASTERY", delve = "CRIT",    pvp = "VERS", weights = { "MASTERY", "VERS", "CRIT", "HASTE" } },
    -- Shaman
    [262]  = { name = "Elemental",     mplus = "MASTERY", raid = "MASTERY", delve = "HASTE",   pvp = "VERS", weights = { "MASTERY", "HASTE", "CRIT", "VERS" } },
    [263]  = { name = "Enhancement",   mplus = "MASTERY", raid = "MASTERY", delve = "HASTE",   pvp = "VERS", weights = { "MASTERY", "HASTE", "CRIT", "VERS" } },
    [264]  = { name = "Restoration",   mplus = "CRIT",    raid = "CRIT",    delve = "CRIT",    pvp = "VERS", weights = { "CRIT", "VERS", "HASTE", "MASTERY" } },
    -- Warlock
    [265]  = { name = "Affliction",    mplus = "MASTERY", raid = "MASTERY", delve = "HASTE",   pvp = "VERS", weights = { "MASTERY", "HASTE", "CRIT", "VERS" } },
    [266]  = { name = "Demonology",    mplus = "HASTE",   raid = "HASTE",   delve = "HASTE",   pvp = "VERS", weights = { "HASTE", "CRIT", "MASTERY", "VERS" } },
    [267]  = { name = "Destruction",   mplus = "HASTE",   raid = "HASTE",   delve = "HASTE",   pvp = "VERS", weights = { "HASTE", "CRIT", "MASTERY", "VERS" } },
    -- Warrior
    [71]   = { name = "Arms",          mplus = "CRIT",    raid = "CRIT",    delve = "CRIT",    pvp = "VERS", weights = { "CRIT", "HASTE", "MASTERY", "VERS" } },
    [72]   = { name = "Fury",          mplus = "HASTE",   raid = "HASTE",   delve = "HASTE",   pvp = "VERS", weights = { "HASTE", "MASTERY", "CRIT", "VERS" } },
    [73]   = { name = "Protection",    mplus = "HASTE",   raid = "HASTE",   delve = "HASTE",   pvp = "VERS", weights = { "HASTE", "VERS", "CRIT", "MASTERY" } },
}

-- ============================================================================
-- Bar Segments Metadata
-- ============================================================================
local DEFAULT_SEGMENT_ORDER = {
    "primary",
    "stats",
    "loot",
    "talents",
    "vault",
    "folio",
    "dur",
    "bags",
    "key",
    "rc",
    "pull",
    "fps",
    "ping",
}

local SEGMENT_META = {
    primary = { id = "primary", icon = "*", label = "Primary Stat",           short = "Primary" },
    stats   = { id = "stats",   icon = "#", label = "Secondary Stats",        short = "Secondaries" },
    weights = { id = "weights", icon = "=", label = "Stat Weights",           short = "Weights" },
    loot    = { id = "loot",    icon = "+", label = "Spec & Loot",            short = "Spec/Loot" },
    talents = { id = "talents", icon = "+", label = "Talent Loadout",         short = "Talents" },
    vault   = { id = "vault",   icon = "+", label = "Great Vault",            short = "Vault" },
    folio   = { id = "folio",   icon = "+", label = "Omni Folio",             short = "Folio" },
    dur     = { id = "dur",     icon = "+", label = "Durability",             short = "Durability" },
    bags    = { id = "bags",    icon = "+", label = "Bag Space",              short = "Bags" },
    key     = { id = "key",     icon = "+", label = "Mythic+ Keystone",       short = "Keystone" },
    rc      = { id = "rc",      icon = "+", label = "Ready Check (RC)",       short = "Ready Check" },
    pull    = { id = "pull",    icon = "+", label = "Pull Countdown",         short = "Pull Timer" },
    fps     = { id = "fps",     icon = "~", label = "Framerate (FPS)",        short = "FPS" },
    ping    = { id = "ping",    icon = "~", label = "Network Latency (Ping)", short = "Ping" },
}

local DEFAULT_CUSTOM_SECONDARY_ORDER = { "HASTE", "MASTERY", "CRIT", "VERS" }
local PULL_TIMER_PRESETS = { 3, 5, 7, 10, 15, 20 }

-- ============================================================================
-- Conflict Registry for DynamicPrep (1:1 parity with DynamicSuite_Core.lua)
-- ============================================================================
local DIRECT_CONFLICTS  = { "EllesmereUIAuraBuffReminders", "EllesmereUI_AuraBuffReminders", "ClickableRaidBuffs" }
local PARTIAL_CONFLICTS = {
    "EnhanceQoL", "Leatrix_Plus", "EllesmereUI", "EllesmereUIQoL", "EllesmereUI_QoL",
    "ErrorFilter", "ErrorMonster",
    "EllesmereUIMythicTimer", "EllesmereUI_MythicPlus",
    "NoAutoClose", "BlizzMove", "DeModal", "MoveAny",
    "DialogUI", "DialogueUI", "Plumber", "Immersion", "Storyline", "AutoTurnIn", "BeQuiet", "TalkLess", "ElvUI", "WindTools",
}

Suite.CONFLICT_REGISTRY = Suite.CONFLICT_REGISTRY or {}
Suite.CONFLICT_REGISTRY.DynamicPrep = {
    conflicts = DIRECT_CONFLICTS,
    hardConflicts = DIRECT_CONFLICTS,
    partialConflicts = PARTIAL_CONFLICTS,
    softConflicts = PARTIAL_CONFLICTS,
    yieldFeature = "gossip/camera control",
    category = "Readiness & Automation",
}

-- ============================================================================
-- Changelog Registration
-- ============================================================================
DynamicPrep.CHANGELOG = {
    version = VERSION,
    date = "22/11/2026",
    entries = {
        { type = "FEATURE", text = "Release v2.8.1 - Red Error Text & Sound Filter (22/11/2026): Added an opt-in Red Error Text & Sound Filter in Tab 3 (Off by default) with Hide Combat & Cooldown Spam, Hide Movement & Mount Errors, and Mute Error Voice Lines (restoring your original Sound_EnableErrorSpeech setting when turned off or disabled), using taint-free Retail 12.1.5 secret-value guards and automatic yielding to EnhanceQoL, Leatrix Plus, ErrorFilter, or ErrorMonster." },
        { type = "FEATURE", text = "Release v2.8.1 - Low Durability Shared Alert Toast (22/11/2026): Added an enabled-by-default Low Durability Alert Toast (DynamicPrepDurabilityToast, default 20% threshold, 10%-40% slider + Test Toast in Tab 3) with 1-click Repair Mount summoning outdoors (Grand Expedition Yak, Grizzly Hills Packmaster, Traveler's Tundra Mammoth) or Open Gear indoors, Right-Click silence until gear drops another 10% or is repaired, and automatic suppression in combat and active Mythic+ keystones." },
        { type = "FEATURE", text = "Release v2.8.1 - Healer Mage Food Restock Toasts & Role-Smart [DynamicDrink] Macro (22/11/2026): Added a decoupled Follower Dungeon Conjured Mana Bun restock/leave Shared Alert Toast workflow (independent of Clickable Raid Buffs scope, with Healer Only / Any Mana Spec scope, 5-60 alert threshold, 20-80 auto-leave target, 1-click Queue Follower / Leave Dungeon buttons, Stage 3 'Ask for Table' group Mage prompt with 5-minute cooldown and encounter/chat lockdown safety, and Right-Click session silence) alongside a separate [nocombat]-guarded [DynamicDrink] macro with dynamic level 1-90 bag scanning, Role-Smart / Mana First / Health & Recup / Off priority, Recuperate fallback, and strict Well Fed buff-food exclusion." },
        { type = "REFACTOR", text = "Release v2.8.0 - Extracted Talent Loadouts & Talent Binds to DynamicTalent (/dt) (21/11/2026): Moved the unlimited per-spec Talent Loadouts library, PlayerSpellsFrame dock, 880x580 Talent Loadouts Manager, and Shared Alert Toast reminders into the dedicated DynamicTalent module while keeping the Top Info Bar 'Talents' capsule hooked cleanly to DynamicTalent and preserving backward-compatible forwarding stubs." },
        { type = "FEATURE", text = "Opt-In Auto-Confirm Free Dungeon & Raid Prompts (21/11/2026): Added an off-by-default 'Auto-Confirm Free Dungeon & Raid Prompts' toggle in Tab 3 under World & Survival Automation to automatically confirm free (0 copper) single-option NPC prompts inside Dungeons, Raids, and Delves (hold Shift to pause), while keeping paid, open-world, hearthstone, and exit/teleport prompts manual." },
        { type = "FEATURE", text = "Release v2.7.1 - Standardised Spec/Loot Clicks, Multi-Select M+ & 'All M+' Binds, LFR/Normal Merge, 'Talent Binds' Rename & 4px Scrollbars (21/11/2026): Standardised Left-Click (Switch Active Specialisation out of combat) and Right-Click (Loot Specialisation) across both the Top Info Bar and Left-Hand Talent Loadouts Dock with 1:1 plain Australian English tooltips; upgraded Tab 2's Pre-Keystone M+ Binder with an 'All' toggle pill alongside multi-select dungeon tiles (saving a single 'All M+ Dungeons' rule when All is selected, or batch-binding specific dungeons which take priority over All M+); merged LFR (difficulty 17) and Normal (difficulty 14) into one 'LFR / Normal' difficulty pill; renamed 'Boss Binds' to 'Talent Binds' across the dock, menus, settings, and headings; and added a 4px interactive 3-way Obsidian scrollbar to Talent Loadouts Manager dropdowns." },
        { type = "UI",      text = "Release v2.7.0 - Unified Talent Reminder Toast, Shared HUD Headers & Uniform Switches (21/11/2026): Updated the Talent Loadout Reminder Toast to inherit DynamicSuite's shared Toast Scale, Opacity, Border Style, Auto-Fade Duration, Alert Sound, and vertical toast stacking with a clean Off/Enabled toggle + [Test Toast] preview button; standardised binary toggle switches to 156x26px (68px Off / 84px Enabled); clamped section header titles and subtitles beside Edit HUD and Reset Order buttons; and replaced legacy Blaze Orange chat alerts with live Suite Accent." },
        { type = "UI",      text = "Blizzard Desktop Window Manager Relocated to Suite Studio (16/11/2026): moved the Blizzard Window Quality of Life controls out of DynamicPrep Tab 3 into their dedicated home in Suite Studio -> Desktop Windows & Menus (/ds windows) powered by the Core MS-Windows-style 32-panel Desktop Window Manager, keeping DynamicPrep Tab 3 focused purely on World, Instance & Survival Automation while preserving backward-compatible bridge stubs and automatic position/scale migration." },
        { type = "UI",      text = "3-Way Interactive Obsidian Scrollbar & Central Popover Auto-Close (16/11/2026): upgraded DynamicPrep's workspace and dropdown scrollbars to full 3-way interaction (Mousewheel, Left-Click & Drag on the thumb with Suite Accent hover/drag highlight and release guard, and Left-Click on the track to jump to the cursor position), added OnHide drag cleanup to Sleek Precision Track Sliders, and registered DynamicPrep's dropdown and top-bar popovers with DynamicSuite's central popover auto-close registry." },
        { type = "FIX",     text = "Smooth Cursor-Anchored Blizzard Window Header Dragging (16/11/2026): updated BeginBlizzFrameDrag() to set state.isDragging = true before Raise()/StopMovingOrSizing() and track exact cursor-to-window-center grab offsets (grabOffsetX, grabOffsetY) via overlay OnUpdate, neutralised Blizzard's native TitleContainer drag scripts out of combat, and prevented AttachFrameHooks() OnDragStart from calling StopMovingOrSizing() during an active header drag so Left-Drag on any window header moves as smoothly as Alt + Left-Drag with zero cursor jump." },
        { type = "FEATURE", text = "Paperdoll Missing-Enchant & Empty-Socket Slot Highlights + /dprep testaudit (16/11/2026): extended ScanEquippedGearEnchantsAndGems() to store flagged slot IDs missing Midnight Season 2 enchants or containing empty gem sockets, hooked CharacterFrame / PaperDollFrame OnShow, PLAYER_EQUIPMENT_CHANGED, and SOCKET_INFO_UPDATE out of combat to draw crisp 1px Warm Amber-Gold (#FBBF24) border overlays on the matching Blizzard paperdoll gear slots, and added /dprep testaudit (/dp testaudit) to preview the highlight borders on Head and Ring 1." },
        { type = "FEATURE", text = "Colour-Coded Food Stat Benefits on Clickable Raid Buffs HUD & Readiness Strip (15/11/2026): added FormatColoredFoodBenefit to colour-code parsed food stats (Mint Teal Primary/Int/Agi/Str, Sky Cyan Haste, Royal Amethyst Mastery, Warm Amber-Gold Crit, Emerald Green Versatility, Blaze Orange Highest Secondary Stat, and Slate-Silver Stamina) across Clickable Raid Buffs food tooltip titles, 'Food Benefit:' summary lines, expiring 'Current Buff:' lines, Readiness Strip Slot 3, and capsule tooltips." },
        { type = "FIX",     text = "Food Item Stat Benefit Tooltips on Clickable Raid Buffs HUD (15/11/2026): expanded ParseFoodBenefitFromTooltipText for Midnight food wording ('gain', 'gaining', 'well fed', 'become well fed'), comma-formatted numbers (e.g. '+1,250 Haste'), and 'Highest Secondary Stat' ('+445 Highest Sec'); cached statShort and statFullLine from C_TooltipInfo.GetBagItem (with GetItemByID / GetSpellByID fallback) in InspectFoodTooltip / ScanOwnedFoods; and added the food's stat benefit to both the HUD button tooltip title (e.g. 'Royal Roast (+445 Highest Sec)') and body above 'Click to eat...'." },
        { type = "FEATURE", text = "Blizzard Window Quality of Life & Silent Multi-Addon Coexistence (15/11/2026): added Tab 3 controls to keep 31 standard Blizzard panels (Character, Inspect, Dressing Room, Talents & Spells, Group Finder, Great Vault, Guild & Communities, Social & Friends, Collections, Transmogrify, Adventure Guide, Professions, Professions Book, Crafting Orders, Achievements, Item Upgrade, Item Socketing, Revival Catalyst, Renown, Delves, Trainer, Calendar, Macros, NPC Gossip, Quest, Trade, Merchant, Mail, Bank, Auction House, and AddOn List) open together via multi-panel restoration and Escape-protected UISpecialFrames / HideUIPanel / CloseWindows / ToggleGameMenu handling (dismissing strictly the most recently opened window per Escape while [X] and keybind toggles close that specific window cleanly) while freezing already-open windows in place so opening another panel never shifts them, smooth native StartMoving/StopMovingOrSizing header and Alt + Left-Drag window moving out of combat with unclamped SetClampedToScreen(false) free movement, scale-aware UIParent CENTER persistence, SetPoint tab-switch snap-back protection, TitleContainer-cleared header overlay layering (+50 frame levels, (-58, -2) Maximize/Minimize clearance), Ctrl+Wheel header scaling for the current session or Ctrl+Shift+Wheel anywhere on a window to save permanently (70%-140% in 5% steps with an auto-fading Obsidian/Blaze-Orange toast), Right-Click header reset and [Reset All Windows] (restoring default position, 100% scale, and screen clamping), strict World Map / Game Menu exclusion with zero combat taint, and automatic silent yielding for NoAutoClose, BlizzMove, DeModal, MoveAny, EllesmereUI, Leatrix Plus, and ElvUI." },
        { type = "FIX",     text = "Midnight Season 2 Enchantable Slot List Fix (15/11/2026): updated equipped gear enchant scanning to remove false-positive missing-enchant alerts on Cloak and Wrist (which do not have enchants in Midnight) and added Head and Shoulder to the Midnight Season 2 enchantable slot list (Head, Shoulder, Chest, Legs, Feet, Ring 1, Ring 2, Main Hand, and Off-Hand weapons)." },
        { type = "FEATURE", text = "Equipped Gear Missing-Enchant & Empty-Socket Detection (15/11/2026): added out-of-combat equipped gear auditing (ScanEquippedGearEnchantsAndGems) cached on PLAYER_ENTERING_WORLD, PLAYER_EQUIPMENT_CHANGED, SOCKET_INFO_UPDATE, and PLAYER_REGEN_ENABLED. Flags missing Midnight Season 2 enchants on max-level Head, Shoulder, Chest, Legs, Feet, Rings, Main Hand, and Off-Hand weapons (excluding shields/holdables and grey/white/heirloom items) and empty gem sockets across slots 1..18, surfacing a compact amber '!' badge in the Durability capsule, 'Enchants:' and 'Gems:' status lines in the Durability tooltip, and Left-Click Character Frame opening." },
        { type = "FEATURE", text = "Great Vault Mythic+ Telemetry, Group Finder Shortcut & Midnight Season 2 Consumables (15/11/2026): added weekly Mythic+ Great Vault run counts, 1/4/8 run threshold levels, and 'Reward Ready to Claim!' status to the Keystone capsule tooltip (guarded with pcall and _IsSecret), added Right-Click Group Finder toggling out of combat on the Keystone capsule, aligned DUNGEON_ABBREVIATIONS with DynamicGroup's Midnight Season 1/2 codes (DON, AOF, MR, VSA, FG, AK, PSF), and updated Midnight Season 2 consumable item IDs and Rank 2 Gold / Rank 1 Silver mappings." },
        { type = "FIX",     text = "Single-Option Auto-Gossip for Interactive World Objects (13/11/2026): Fixed world objects (GameObject-* GUIDs such as 'Unfinished Mixture') failing to auto-select when gossipOptionID is nil or when option text uses <...> / [Requires ...] brackets. Added C_GossipInfo.SelectOptionByIndex fallback, explicit Locked/Unavailable status checks, and a 0.05s secondary GOSSIP_SHOW check for skinned/delayed gossip frames (hold Shift to bypass)." },
        { type = "FIX",     text = "Single-Option Auto-Gossip now actually fires (13/11/2026): a hidden Blizzard flag that is switched off for almost every normal dialogue option was wrongly treated as 'do not auto-select', which stopped Auto-Gossip on most NPCs and objects. Multi-step conversations now also advance page by page instead of stopping after the first choice, with a safety limit of 8 automatic picks per conversation." },
        { type = "FEATURE", text = "One-Click Catalyst & Raid Combat UNIT_AURA Throttling (12/11/2026): Added a 'One-Click Catalyst' QoL toggle (enabled by default in Tab 3) that hooks ItemInteractionFrame.ButtonFrame.ActionButton and CONFIRM_ITEM_INTERACTION when C_ItemInteraction.GetItemInteractionInfo() is in Catalyst mode (Enum.UIItemInteractionType.ItemConversion) to complete tier conversions in a single click without a second confirmation popup or 5s timer (hold Shift to bypass). Overhauled raid combat event handling with an O(1) VALID_GROUP_UNITS lookup table ('player', 'party1'..'party4', 'raid1'..'raid40' - ignoring target, focus, mouseover, pets, nameplates, and bosses), coalesced all in-combat raid buff (16/17 MotW) and Symbiotic bond checks via a 0.30s (3.3 Hz max) C_Timer.NewTimer throttle, eliminated per-scan table allocations, and completely skipped Food, Flask, Weapon Oil, Augment Rune, and Bag Item Location scans during InCombatLockdown()." },
        { type = "FIX",     text = "Greyed-Out Ctrl-to-Release Death Button & Modifier-Free Sequential [DynamicHeal] Macro (12/11/2026): Hooked StaticPopup_OnUpdate and StaticPopup1..4 OnUpdate/OnShow/OnHide alongside MODIFIER_STATE_CHANGED, PLAYER_ALIVE, and PLAYER_UNGHOST so the DEATH StaticPopup 'Release Spirit' button stays natively disabled (greyed out with 'Hold CTRL to Release') every frame until Ctrl is held and restores cleanly when hidden; and stripped all [mod]/[nomod] conditionals from [DynamicHeal] in favour of a modifier-free sequential priority fallback (#showtooltip + /castsequence reset=combat item:<HealthstoneID>, item:<HealPotID> or /use item:<SingleID>) with out-of-combat cooldown reordering and post-combat sequence reset." },
        { type = "UI",      text = "Unified In-Combat Raid Buff Alert into the Readiness Tracker Strip (12/11/2026): Removed the standalone in-combat text banner and unified in-combat missing Class Raid Buff alerts (Mark of the Wild, Power Word: Fortitude, Arcane Intellect, Skyfury, Battle Shout, Blessing of the Bronze) directly into the Readiness Tracker Strip using the standard icon + border + top-right X/Y count (e.g. 16/17) + bottom MISSING label format while keeping personal consumables hidden mid-pull." },
        { type = "FIX",     text = "Fixed RefreshReadinessTrackerStrip nil-index Lua error & restored Top Info Bar Layout Builder capsules (12/11/2026): Moved CLASS_RAID_BUFFS, PARTNER_RAID_BUFFS, SYMBIOTIC_SPELL_IDS, and SafeIsPlayerSpellKnown above all functions that reference them, added defensive nil guards across RefreshReadinessTrackerStrip, and wrapped all RefreshReadinessTrackerStrip calls in pcall so Tab 2 readiness strip updates can never interrupt Tab 1 Top Info Bar Layout Builder rendering." },
        { type = "FEATURE", text = "Symbiotic Relationship Linked-Target Fix, Live Food Buff Stat Parser & In-Combat Brez / Mark of the Wild Tracker (12/11/2026): Scans player and party/raid units for Symbiotic Relationship (474750, 474754, and C_Spell.GetSpellName(474750) from player) plus UNIT_SPELLCAST_SUCCEEDED target caching to display 'Linked: [TankName]' and invalidate on ally death/group leave; parses exact Well Fed stat benefits via C_TooltipInfo.GetUnitBuffByAuraInstanceID (with aura.points fallback and out-of-combat cache); and tracks in-combat Battle Rez / Ankh life-state transitions to surface a zero-taint 'Missing MotW: [PlayerName] (19/20)' alert." },
        { type = "FEATURE", text = "External Addon Conflict Detector & Auto-Yield Engine (12/11/2026): Automatically detects DialogueUI, Immersion, Storyline, and AutoTurnIn as SOFT overlaps, hands gossip/camera and quest dialogue control to the active narrative addon, and surfaces non-intrusive Auto-Yield status in DynamicSuite." },
        { type = "FIX",     text = "Eliminated the 0.5s bank open delay and third-party DialogueUI popup flash on Banker NPCs with gossip options: auto-selects Banker, AccountBanker, and GuildBanker gossip synchronously at 0.00s on GOSSIP_SHOW, transiently suppresses DUIQuestFrame during auto-skipped gossip (restoring normal DialogueUI alpha/visibility on GOSSIP_CLOSED, PLAYER_INTERACTION_MANAGER_FRAME_SHOW, or 0.8s fallback), and pre-warms DynamicBags's companion bank window on the click frame." },
        { type = "FIX",     text = "Eliminated Omni Folio PostClick double-fire by guarding PostClick against keydown/keyup mismatch, triggering Right-Click popover strictly once on key release, and refreshing activeFolioStat via post-cast UNIT_AURA scan." },
        { type = "FIX",     text = "Guarded protected DynamicPrepBarFrame geometry and segment relayouts against InCombatLockdown() and deferred pending bar refreshes to PLAYER_REGEN_ENABLED." },
        { type = "FIX",     text = "Preserved table-based AUTO_YIELD conflict resolution entries in yieldHooks across ADDON_LOADED and updated ToggleLootSpecPopover to use 12.1.5 C_SpecializationInfo wrappers." },
        { type = "FEATURE", text = "Added Single-Target Friendly Partner Buff tracking and 1-Click Role-Smart Target Resolution to the Clickable Raid Buffs HUD for Symbiotic Relationship (Druid), Source of Magic & Blistering Scales (Evoker), Earth Shield (Shaman), and Beacon of Light & Beacon of Faith (Paladin) with [@mouseover,help,nodead][@target,help,nodead] override." },
        { type = "FIX",     text = "Unified ApplyPrepEditMode(state) so exiting HUD Edit Mode via Esc or Lock & Exit immediately clears movers and drag shields across both DynamicPrepBarFrame and DynamicPrepClickableBuffBar." },
        { type = "FIX",     text = "Fixed Augment Rune ('RUNE') active-buff detection in SafeHasAura and ScanAndPopulateRaidBuffQueue: scans owned Augment Runes first to dynamically match C_Item.GetItemSpell(runeID) spellID/name and runeIcon fileID against active player buffs, and removed premature loop break when a single aura index is inaccessible." },
        { type = "UI",      text = "Standardized Equipment Durability capsule and header status label from 'Gear 100%' to 'Dur 100%' so Durability naming is 100% consistent across DynamicPrep and DynamicChat." },
        { type = "UI",      text = "Added live action-bar status badge ([On Action Bar], [Created - Drag to Bar], [Not Created]) and reactive button styling to the [DynamicHeal] Combat Healing Macro card on Tab 3." },
        { type = "UI",      text = "Standardized all sliders to the Sleek Precision Track (4px track, Suite Accent fill bar, 6x14px blade thumb) and applied Option 3 semantic styling for negative/disabled pill states." },
        { type = "UI",      text = "Rebalanced DynamicPrep across 3 dedicated tabs: Tab 1 (Bar Layout & Style), Tab 2 (Raid Buffs & Omni Folio - grouping Clickable Raid Buffs and Midnight Omni Folio together), and Tab 3 (World & Survival QoL)." },
        { type = "UI",      text = "Migrated Merchant, Loot & Delete Chores (Auto-Repair Equipment + Funding Priority, Auto-Sell Grey Junk, Faster Auto-Loot, and Auto-Fill DELETE) into DynamicBags (Tab 3), and consolidated Auto-Insert Mythic+ Keystone into DynamicGroup (Tab 3)." },
        { type = "UI",      text = "Standardized all mouseover command tooltips on Top Info Bar capsules (Spec/Loot, Folio, Keystone, Ready Check, Pull Timer, FPS, Ping) and Clickable Raid Buffs to highlight only the input command prefix while keeping action descriptions Silver-White (#E2E8F0)." },
        { type = "FIX",     text = "Fixed Auto-Gossip on world objects, Delve interactables, and quest items by removing restrictive opt.flags bitmask blocking in ShouldAutoSelectSingleGossip, detecting active Delves (C_DelvesUI.HasActiveDelve / C_PartyInfo.IsDelveInProgress), safely defaulting nil quest/option tables in GOSSIP_SHOW, and handling ITEM_TEXT_READY." },
        { type = "FEATURE", text = "Enabled Clickable Raid Buffs & Consumable HUD mid-combat, mid-encounter, and inside active Mythic+ keys with SafeHasAura / _unitAuraStateCache fallback and 'active/total' (e.g. '4/5' or '19/20') missing group buff badge formatting." },
        { type = "FIX",     text = "Fixed Quest Auto-Accept, Auto-Turn-In & Gossip automation: isolated HandleQuestAndGossip from IsYieldingSharedHooks(), added Enum.GossipOptionRecFlags.QuestLabelPrepend (flags == 1) & quest icon detection, registered QUEST_ACCEPT_CONFIRM & QUEST_AUTOCOMPLETE, added CanAutoProgressQuest() gold protection, and added 0.05s deferred QuestFrame retries (hold Shift to bypass)." },
        { type = "FIX",     text = "Upgraded Secondary Stat Order, Clickable Raid Buffs & Consumable HUD, Auto-Repair Gear, and Auto-Sell Poor (Grey) Junk sub-drawers to full-width 24px horizontal chevron toggle bars (Sub-Settings (N)) with unified outer group borders per DESIGN_SYSTEM.md Section 2.6." },
        { type = "FIX",     text = "Resolved 'GetBuffDataByIndex(): Auras cannot be accessed when secret' error by adding _AreAurasSecret and _IsAuraIndexSecret guards, pcall wrappers, and deferred post-combat aura refresh." },
        { type = "FIX",     text = "Fixed Top Info Bar text corruption (e.g. '0a48%' and '0a+19 BV') by sanitizing 8-digit ARGB hex codes from GetSuiteAccent down to clean 6-digit RRGGBB strings before formatting into |cFF color sequences." },
        { type = "UI",      text = "Added connected L-bracket section headers (3x34px Suite Accent vertical bar + 1px horizontal underline) across all main section containers." },
        { type = "FEATURE", text = "Auto-Skip Gossip & Quest Accept / Turn-In automation in Tab 3: auto-triggers single-option dungeon/Delve/raid interactables even in combat, blocks open-world NPC service icons & destructive/hearth/exit prompts, and pauses when choosing between multiple item rewards (hold Shift to bypass)." },
        { type = "FEATURE", text = "Upgraded Clickable Raid Buffs & Consumable HUD for Midnight: 2-tier quality badges (Rank 2 Gold / Rank 1 Silver) grouped side-by-side by flask name, deep Well Fed stat-food tooltip & spell detection (including Impossibly Royal Roast 255847), Hearty [H] vs Normal food badges, 1-click Weapon Oil auto-apply (/use 16, Right-Click for off-hand), and Augment Runes." },
        { type = "FIX",     text = "Updated [DynamicHeal] macro scanner to detect Midnight's Concentrated Silvermoon Health Potion (271883) and Silvermoon Health Potion tiers, plus dynamic bag fallback." },
        { type = "PERF",    text = "Mythic+ Secret-Value Shield & O(1) Fast-Path (0.0019 ms/tick) with /dprep simkey benchmark to eliminate M+ keystone secret-number errors and GC lag." },
    },
}
Suite.Changelogs["DynamicPrep"] = DynamicPrep.CHANGELOG
Suite.Changelogs["prep"] = DynamicPrep.CHANGELOG

-- ============================================================================
-- SavedVariables Initialization & Defaults
-- ============================================================================
local DEFAULTS = {
    version = VERSION,
    displayMode = "ALWAYS", -- "ALWAYS", "OOC", "INSTANCE", "HIDDEN"
    hudBorderStyle = "ACCENT", -- "ACCENT", "DARK", "NONE"
    barColorTheme = "PRIORITY_GLOW", -- "PRIORITY_GLOW", "CLASS_ACCENT", "MONOCHROME"
    statSortMode = "RANK", -- "RANK" or "CUSTOM"
    secondaryStatOrderMode = "RANK", -- "RANK" or "CUSTOM"
    customSecondaryOrder = { "HASTE", "MASTERY", "CRIT", "VERS" },
    pingDisplayMode = "BOTH", -- "BOTH", "LOCAL_ONLY", "WORLD_ONLY"
    pingOrder = "LOCAL_FIRST", -- "LOCAL_FIRST", "WORLD_FIRST"
    pullTimer = 10,
    combatRefreshRate = 0.2,
    barScale = 1.0,
    barOpacity = 0.95,
    segmentOrder = { "primary", "stats", "loot", "talents", "vault", "folio", "dur", "bags", "key", "rc", "pull", "fps", "ping" },
    segments = {
        primary = true,
        stats   = true,
        weights = false,
        loot    = true,
        talents = true,
        vault   = true,
        folio   = true,
        dur     = true,
        bags    = true,
        key     = true,
        rc      = true,
        pull    = true,
        fps     = true,
        ping    = true,
    },
    omniFolio = {
        enabled    = true,
        presetMode = "WOWHEAD", -- "WOWHEAD" or "CUSTOM"
        mplus      = "HASTE",
        raid       = "HASTE",
        delve      = "HASTE",
        pvp        = "VERS",
        customBySpec = {},
    },
    activeFolioStat = nil,
    autoQuestGossip = true,
    autoConfirmInstanceGossip = false,
    autoSinglePlayerChoice = true,
    oneClickCatalyst = true,
    autoAcceptSummon = false,
    cinematicMode = "BOTH", -- "BOTH", "SKIP_ONLY", "OFF"
    autoRezMode = "OUT_OF_COMBAT", -- "OUT_OF_COMBAT", "ALWAYS", "OFF"
    autoReleaseMode = "WIPE_AND_CTRL", -- "WIPE_AND_CTRL", "HOLD_CTRL", "PVP_AUTO_WIPE_PVE", "ALWAYS", "OFF"
    healMacroOrder = "STONE_FIRST", -- "STONE_FIRST", "POT_FIRST", "BOTH", "OFF"
    autoHealMacroEnabled = true,
    mageFoodRestockEnabled = true,
    mageFoodRestockScope = "HEALER_ONLY", -- "HEALER_ONLY" or "ANY_MANA"
    mageFoodMinThreshold = 20, -- 5 to 60 step 5
    mageFoodLeaveTarget = 20, -- 20 to 80 step 20
    drinkMacroMode = "ROLE_SMART", -- "ROLE_SMART", "MANA_FIRST", "HEALTH_RECUP", "OFF"
    drinkMacroAllowBuffFood = false,
    drinkMacroRecupFallback = true,
    durabilityAlertEnabled = true,
    durabilityAlertThreshold = 20, -- 10% to 40% step 5%
    errorFilterEnabled = false,
    errorFilterHideCombatSpam = true,
    errorFilterHideMovement = true,
    errorFilterMuteSpeech = false,
    errorFilterSavedSpeechCVar = nil,
    blizzWinNoAutoClose = true,
    blizzWinDraggable = true,
    blizzWinScrollScale = true,
    windowPositions = {},
    windowScales = {},
    yieldHooks = false,
    activeSubTab = 1,
    raidBuffs = {
        enabled = true,
        scope = "ALWAYS", -- "ALWAYS", "GROUP_OR_INST", "INST_ONLY"
        iconSize = 44,
        expireThresholdMin = 5,
        trackClassBuffs = true,
        trackPartnerBuffs = true,
        trackWeaponEnchants = true,
        trackFlasks = true,
        trackFood = true,
        trackRunes = true,
        trackCombatBrez = true,
        point = "CENTER",
        relPoint = "CENTER",
        x = 0,
        y = 140,
        hudScale = 1.0,
        hudOpacity = 0.95,
        hudBorderStyle = "ACCENT",
        orientation = "HORIZONTAL",
    },
}

local function DeepCopyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = DeepCopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

function DynamicPrep:InitDB()
    _G.DynamicPrepDB = DeepCopyDefaults(DEFAULTS, _G.DynamicPrepDB)
    self.db = _G.DynamicPrepDB
    _G.DynamicSuiteDB = _G.DynamicSuiteDB or {}
    _G.DynamicSuiteDB.global = _G.DynamicSuiteDB.global or {}
    _G.DynamicSuiteDB.global.seenMovies = _G.DynamicSuiteDB.global.seenMovies or {}
    _G.DynamicSuiteDB.global.seenCinematics = _G.DynamicSuiteDB.global.seenCinematics or {}
    if self.db.yieldHooks == nil then
        self.db.yieldHooks = false
    end
    if self.db.autoReleaseMode == "PVP_AUTO_PVE_CTRL" then
        self.db.autoReleaseMode = "PVP_AUTO_WIPE_PVE"
    end

    if self.db.blizzWinNoAutoClose == nil then self.db.blizzWinNoAutoClose = true end
    if self.db.blizzWinDraggable == nil then self.db.blizzWinDraggable = true end
    if self.db.blizzWinScrollScale == nil then self.db.blizzWinScrollScale = true end
    if type(self.db.windowPositions) ~= "table" then self.db.windowPositions = {} end
    if type(self.db.windowScales) ~= "table" then self.db.windowScales = {} end
    self.db.windowPinned = nil

    -- Normalize Mage Food Restock & [DynamicDrink] settings
    if self.db.mageFoodRestockEnabled == nil then self.db.mageFoodRestockEnabled = true end
    if self.db.mageFoodRestockScope ~= "HEALER_ONLY" and self.db.mageFoodRestockScope ~= "ANY_MANA" then
        self.db.mageFoodRestockScope = "HEALER_ONLY"
    end
    local minT = tonumber(self.db.mageFoodMinThreshold) or 20
    minT = math.max(5, math.min(60, math.floor((minT / 5) + 0.5) * 5))
    self.db.mageFoodMinThreshold = minT
    local leaveT = tonumber(self.db.mageFoodLeaveTarget) or 20
    leaveT = math.max(20, math.min(80, math.floor((leaveT / 20) + 0.5) * 20))
    self.db.mageFoodLeaveTarget = leaveT
    if self.db.drinkMacroMode ~= "ROLE_SMART" and self.db.drinkMacroMode ~= "MANA_FIRST"
       and self.db.drinkMacroMode ~= "HEALTH_RECUP" and self.db.drinkMacroMode ~= "OFF" then
        self.db.drinkMacroMode = "ROLE_SMART"
    end
    self.db.drinkMacroAllowBuffFood = (self.db.drinkMacroAllowBuffFood == true)
    if self.db.drinkMacroRecupFallback == nil then self.db.drinkMacroRecupFallback = true end
    if self.db.durabilityAlertEnabled == nil then self.db.durabilityAlertEnabled = true end
    local durT = tonumber(self.db.durabilityAlertThreshold) or 20
    durT = math.max(10, math.min(40, math.floor((durT / 5) + 0.5) * 5))
    self.db.durabilityAlertThreshold = durT

    -- Ensure raidBuffs.trackRunes defaults to true for upgraded profiles
    if self.db.raidBuffs then
        if self.db.raidBuffs.trackRunes == nil or self.db.raidBuffs._runeDefaultMigrated ~= true then
            self.db.raidBuffs.trackRunes = true
            self.db.raidBuffs._runeDefaultMigrated = true
        end
    end

    -- Smooth DB migration & deduplication for all 12 segment keys
    self.db.segments = self.db.segments or {}
    local hasRCInOrder = false
    if type(self.db.segmentOrder) == "table" then
        for _, key in ipairs(self.db.segmentOrder) do
            if key == "rc" then
                hasRCInOrder = true
                break
            end
        end
    end
    local seen = {}
    local cleanOrder = {}
    local function AddSegKey(k)
        if k == "weights" then return end
        if SEGMENT_META[k] and not seen[k] then
            seen[k] = true
            table.insert(cleanOrder, k)
        end
    end
    if type(self.db.segmentOrder) == "table" then
        for _, key in ipairs(self.db.segmentOrder) do
            if key == "fps_ms" then
                AddSegKey("fps")
                AddSegKey("ping")
                self.db.segments.fps = true
                self.db.segments.ping = true
            elseif key == "pull" and not hasRCInOrder then
                AddSegKey("rc")
                AddSegKey("pull")
                self.db.segments.rc = true
                self.db.segments.pull = true
            else
                AddSegKey(key)
            end
        end
    end
    for _, key in ipairs(DEFAULT_SEGMENT_ORDER) do
        AddSegKey(key)
    end
    self.db.segmentOrder = cleanOrder
    if self.db.segments.talents == nil then self.db.segments.talents = true end
    if self.db.segments.fps == nil then self.db.segments.fps = true end
    if self.db.segments.ping == nil then self.db.segments.ping = true end
    if self.db.segments.rc == nil then self.db.segments.rc = true end
    if self.db.segments.pull == nil then self.db.segments.pull = true end; self.db.segments.weights = false
    self.db.segments.fps_ms = nil
    if self.db.pingDisplayMode ~= "BOTH" and self.db.pingDisplayMode ~= "LOCAL_ONLY" and self.db.pingDisplayMode ~= "WORLD_ONLY" then
        self.db.pingDisplayMode = "BOTH"
    end
    if self.db.pingOrder ~= "LOCAL_FIRST" and self.db.pingOrder ~= "WORLD_FIRST" then
        self.db.pingOrder = "LOCAL_FIRST"
    end
    self.db.pullTimer = tonumber(self.db.pullTimer) or 10

    -- Sync Secondary Stat Order Mode & Custom Secondary Order
    if self.db.statSortMode == "FIXED" or self.db.statSortMode == "CUSTOM" then
        self.db.secondaryStatOrderMode = "CUSTOM"
        self.db.statSortMode = "CUSTOM"
    elseif self.db.secondaryStatOrderMode == "CUSTOM" then
        self.db.statSortMode = "CUSTOM"
    else
        self.db.secondaryStatOrderMode = "RANK"
        self.db.statSortMode = "RANK"
    end

    local validSec = { CRIT = true, HASTE = true, MASTERY = true, VERS = true }
    local seenSec = {}
    local cleanSecOrder = {}
    if type(self.db.customSecondaryOrder) == "table" then
        for _, sk in ipairs(self.db.customSecondaryOrder) do
            if validSec[sk] and not seenSec[sk] then
                seenSec[sk] = true
                table.insert(cleanSecOrder, sk)
            end
        end
    end
    for _, sk in ipairs(DEFAULT_CUSTOM_SECONDARY_ORDER) do
        if not seenSec[sk] then
            seenSec[sk] = true
            table.insert(cleanSecOrder, sk)
        end
    end
    self.db.customSecondaryOrder = cleanSecOrder

    -- Account-wide DynamicSuiteDB.global
    _G.DynamicSuiteDB = _G.DynamicSuiteDB or {}
    _G.DynamicSuiteDB.global = _G.DynamicSuiteDB.global or {}
    local g = _G.DynamicSuiteDB.global
    g.window = g.window or { width = 980, height = 680, scale = 1.0 }
    g.window.width = math.max(800, math.min(1380, g.window.width or 980))
    g.window.height = math.max(520, math.min(900, g.window.height or 680))
    g.hudPositions = g.hudPositions or {}
    local existingPos = g.hudPositions["prep"] or g.hudPositions.prepBar
    local defaultPos = {
        point = self.db.barPoint or (existingPos and existingPos.point) or "TOP",
        relativePoint = self.db.barRelativePoint or (existingPos and (existingPos.relativePoint or existingPos.relPoint)) or "TOP",
        relPoint = self.db.barRelativePoint or (existingPos and (existingPos.relPoint or existingPos.relativePoint)) or "TOP",
        x = (self.db.barX ~= nil) and self.db.barX or ((existingPos and existingPos.x) or 0),
        y = (self.db.barY ~= nil) and self.db.barY or ((existingPos and existingPos.y) or -8),
    }
    g.hudPositions["prep"] = defaultPos
    g.hudPositions.prepBar = defaultPos
    self.db.barPoint = defaultPos.point
    self.db.barRelativePoint = defaultPos.relativePoint
    self.db.barX = defaultPos.x
    self.db.barY = defaultPos.y

    if type(self.db.omniFolio) == "table" then
        local specID = self:GetActiveSpecInfo()
        local meta = self:GetSpecMetadata(specID)
        for _, k in ipairs({ "mplus", "raid", "delve", "pvp" }) do
            local v = self.db.omniFolio[k]
            if v ~= nil and not VALID_FOLIO_TARGET_STATS[v] then
                self.db.omniFolio[k] = meta[k] or "HASTE"
            end
        end
    end
    if self.db.activeFolioStat ~= nil and not VALID_FOLIO_ACTIVE_STATS[self.db.activeFolioStat] then
        self.db.activeFolioStat = nil
    end

    if self.db.omniFolio.presetMode == "WOWHEAD" then
        self:ApplyWowheadPresetForCurrentSpec(true)
    end
end

local function GetPrepAnchorFraction(pointStr)
    local pt = type(pointStr) == "string" and pointStr:upper() or "CENTER"
    local fx = 0.5
    local fy = 0.5
    if pt:find("LEFT", 1, true) then
        fx = 0.0
    elseif pt:find("RIGHT", 1, true) then
        fx = 1.0
    end
    if pt:find("BOTTOM", 1, true) then
        fy = 0.0
    elseif pt:find("TOP", 1, true) then
        fy = 1.0
    end
    return fx, fy
end

local function ClampPrepFrameToScreen(frame, point, relPoint, rawX, rawY, fallbackW, fallbackH)
    local pt = point or "TOP"
    local rp = relPoint or pt
    local fScale = (frame and frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
    local uScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if fScale <= 0 then fScale = 1 end
    if uScale <= 0 then uScale = 1 end
    local relScale = fScale / uScale
    if relScale <= 0 then relScale = 1 end

    local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
    local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
    local screenCx = screenW / 2
    local screenCy = screenH / 2

    local frameW = (frame and frame.GetWidth and frame:GetWidth()) or fallbackW or 200
    local frameH = (frame and frame.GetHeight and frame:GetHeight()) or fallbackH or 36
    local visW = math.max(1, frameW * relScale)
    local visH = math.max(1, frameH * relScale)
    local halfW = visW / 2
    local halfH = visH / 2

    local pfx, pfy = GetPrepAnchorFraction(pt)
    local rfx, rfy = GetPrepAnchorFraction(rp)
    local refX = rfx * screenW
    local refY = rfy * screenH

    local inX = tonumber(rawX) or 0
    local inY = tonumber(rawY) or 0
    local anchorVisX = refX + (inX * relScale)
    local anchorVisY = refY + (inY * relScale)
    local candCx = anchorVisX + (0.5 - pfx) * visW
    local candCy = anchorVisY + (0.5 - pfy) * visH

    local minCx = halfW
    local maxCx = screenW - halfW
    local minCy = halfH
    local maxCy = screenH - halfH
    if minCx > maxCx then
        candCx = screenCx
    else
        candCx = math.max(minCx, math.min(maxCx, candCx))
    end
    if minCy > maxCy then
        candCy = screenCy
    else
        candCy = math.max(minCy, math.min(maxCy, candCy))
    end

    local outX = math.floor((((candCx - (0.5 - pfx) * visW) - refX) / relScale) + 0.5)
    local outY = math.floor((((candCy - (0.5 - pfy) * visH) - refY) / relScale) + 0.5)

    local minLocalX = ((minCx - (0.5 - pfx) * visW) - refX) / relScale
    local maxLocalX = ((maxCx - (0.5 - pfx) * visW) - refX) / relScale
    local minLocalY = ((minCy - (0.5 - pfy) * visH) - refY) / relScale
    local maxLocalY = ((maxCy - (0.5 - pfy) * visH) - refY) / relScale

    if minLocalX <= maxLocalX then
        local loX = math.ceil(minLocalX - 1e-6)
        local hiX = math.floor(maxLocalX + 1e-6)
        if loX <= hiX then outX = math.max(loX, math.min(hiX, outX)) end
    else
        outX = math.floor((((screenCx - (0.5 - pfx) * visW) - refX) / relScale) + 0.5)
    end
    if minLocalY <= maxLocalY then
        local loY = math.ceil(minLocalY - 1e-6)
        local hiY = math.floor(maxLocalY + 1e-6)
        if loY <= hiY then outY = math.max(loY, math.min(hiY, outY)) end
    else
        outY = math.floor((((screenCy - (0.5 - pfy) * visH) - refY) / relScale) + 0.5)
    end

    local didClamp = (outX ~= math.floor(inX + 0.5)) or (outY ~= math.floor(inY + 0.5))
    return outX, outY, didClamp
end

function DynamicPrep:GetSavedBarPosition()
    local g = _G.DynamicSuiteDB and _G.DynamicSuiteDB.global
    local pos = g and g.hudPositions and (g.hudPositions["prep"] or g.hudPositions.prepBar)
    local pt = (pos and pos.point) or (self.db and self.db.barPoint) or "TOP"
    local rp = (pos and (pos.relativePoint or pos.relPoint)) or (self.db and self.db.barRelativePoint) or pt
    local x = (pos and pos.x ~= nil) and pos.x or ((self.db and self.db.barX ~= nil) and self.db.barX or 0)
    local y = (pos and pos.y ~= nil) and pos.y or ((self.db and self.db.barY ~= nil) and self.db.barY or -8)
    return pt, rp, x, y
end

function DynamicPrep:SaveBarEditPosition(point, relPoint, x, y)
    local pt = point or "TOP"
    local rp = relPoint or pt
    local rawX = tonumber(x) or 0
    local rawY = tonumber(y) or -8
    local px, py = ClampPrepFrameToScreen(self.prepBarFrame, pt, rp, rawX, rawY, 320, 32)
    if self.db then
        self.db.barPoint = pt
        self.db.barRelativePoint = rp
        self.db.barX = px
        self.db.barY = py
    end
    _G.DynamicSuiteDB = _G.DynamicSuiteDB or {}
    _G.DynamicSuiteDB.global = _G.DynamicSuiteDB.global or {}
    _G.DynamicSuiteDB.global.hudPositions = _G.DynamicSuiteDB.global.hudPositions or {}
    local saved = {
        point = pt,
        relativePoint = rp,
        relPoint = rp,
        x = px,
        y = py,
    }
    _G.DynamicSuiteDB.global.hudPositions["prep"] = saved
    _G.DynamicSuiteDB.global.hudPositions.prepBar = saved
end

-- ============================================================================
-- Character Telemetry & Stat Resolution Engine
-- ============================================================================
local ZONE_TAGS = {
    outdoor  = "Outdoor",
    city     = "Outdoor",
    delve    = "Delve",
    dungeon  = "M+",
    mplus    = "M+",
    raid     = "Raid",
    pvp      = "PvP",
    scenario = "Story",
}

local function IsActiveDelveInstance()
    if type(_G.GetInstanceInfo) == "function" then
        local okI, _, _, diffID = pcall(_G.GetInstanceInfo)
        if okI and not _IsSecret(diffID) and type(diffID) == "number" and diffID == 208 then
            return true
        end
    end
    if C_DelvesUI and type(C_DelvesUI.HasActiveDelve) == "function" then
        local okD, hasD = pcall(C_DelvesUI.HasActiveDelve)
        if okD and not _IsSecret(hasD) and hasD == true then return true end
    end
    if C_PartyInfo and type(C_PartyInfo.IsDelveInProgress) == "function" then
        local okP, inP = pcall(C_PartyInfo.IsDelveInProgress)
        if okP and not _IsSecret(inP) and inP == true then return true end
    end
    if C_PartyInfo and type(C_PartyInfo.IsDelveComplete) == "function" then
        local okC, isC = pcall(C_PartyInfo.IsDelveComplete)
        if okC and not _IsSecret(isC) and isC == true then return true end
    end
    return false
end

local function SafeGetNumSpecializations()
    if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializations then
        return C_SpecializationInfo.GetNumSpecializations() or 0
    end
    return GetNumSpecializations and GetNumSpecializations() or 0
end

local function SafeGetSpecialization()
    local fn = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or _G.GetSpecialization
    if type(fn) ~= "function" then return nil end
    local ok, idx = pcall(fn)
    if not ok or _IsSecret(idx) or type(idx) ~= "number" or idx < 1 or idx > 4 then
        return nil
    end
    return idx
end

local function SafeGetSpecializationInfo(specIndex)
    if not specIndex or type(specIndex) ~= "number" or specIndex < 1 or specIndex > 4 then
        return nil
    end
    local fn = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or _G.GetSpecializationInfo
    if type(fn) ~= "function" then return nil end
    local ok, specID, specName, desc, icon, role, primaryStatIndex = pcall(fn, specIndex)
    if not ok or _IsSecret(specID) or type(specID) ~= "number" or specID <= 0 then
        return nil
    end
    if _IsSecret(specName) or type(specName) ~= "string" then specName = nil end
    if _IsSecret(primaryStatIndex) or type(primaryStatIndex) ~= "number" then primaryStatIndex = 1 end
    return specID, specName, desc, icon, role, primaryStatIndex
end

function DynamicPrep:GetActiveSpecInfo()
    local specIndex = SafeGetSpecialization()
    if specIndex then
        local specID, specName, _, _, _, primaryStatIndex = SafeGetSpecializationInfo(specIndex)
        if specID then
            return specID, specName or "Current", primaryStatIndex or 1
        end
    end
    return nil, "Unassigned", 1
end

function DynamicPrep:GetSpecMetadata(specID)
    specID = specID or select(1, self:GetActiveSpecInfo())
    return (specID and SPEC_DATA[specID]) or NEUTRAL_SPEC_META
end

function DynamicPrep:GetTopPriorityStatLabel()
    local specID = self:GetActiveSpecInfo()
    local meta = self:GetSpecMetadata(specID)
    local topKey = (meta.weights and meta.weights[1]) or meta.mplus or "HASTE"
    return STAT_LABELS[topKey] or "Haste", topKey
end

function DynamicPrep:ApplyWowheadPresetForCurrentSpec(silent)
    if not self.db or not self.db.omniFolio then return end
    local specID = self:GetActiveSpecInfo()
    local meta = self:GetSpecMetadata(specID)
    self.db.omniFolio.presetMode = "WOWHEAD"
    self.db.omniFolio.mplus = meta.mplus or "HASTE"
    self.db.omniFolio.raid  = meta.raid  or "HASTE"
    self.db.omniFolio.delve = meta.delve or "HASTE"
    self.db.omniFolio.pvp   = meta.pvp   or "VERS"
    if not silent then
        self:RefreshBar()
        self:RefreshWorkspaceView()
    end
end

function DynamicPrep:GetCurrentContentCategory()
    if self.previewZoneKey then
        local zk = tostring(self.previewZoneKey or "outdoor"):lower()
        local zoneTag = ZONE_TAGS[zk] or "Outdoor"
        return zk, "[" .. zoneTag .. "]"
    end
    local inInstance, instanceType = false, "none"
    if type(IsInInstance) == "function" then
        local okI, rIn, rType = pcall(IsInInstance)
        if okI then
            inInstance = (not _IsSecret(rIn) and rIn == true) and true or false
            if not _IsSecret(rType) and type(rType) == "string" then
                instanceType = rType
            end
        end
    end
    if inInstance then
        if instanceType == "pvp" or instanceType == "arena" then
            return "pvp", "[PvP]"
        elseif instanceType == "raid" then
            return "raid", "[Raid]"
        elseif instanceType == "party" then
            return "mplus", "[M+]"
        elseif instanceType == "scenario" then
            if IsActiveDelveInstance() then
                return "delve", "[Delve]"
            end
            return "scenario", "[Story]"
        end
    end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
        return "mplus", "[M+]"
    end
    if IsActiveDelveInstance() then
        return "delve", "[Delve]"
    end
    -- Open World or Capital City (IsResting()):
    return "outdoor", "[Outdoor]"
end

function DynamicPrep:GetCurrentContentTag(zoneKey)
    local zk = tostring(zoneKey or "outdoor"):lower()
    local zoneTag = ZONE_TAGS[zk] or "Outdoor"
    return "[" .. zoneTag .. "]"
end

function DynamicPrep:GetTargetFolioStatForZone(zoneKey)
    if not self.db or not self.db.omniFolio then return "HASTE" end
    local zk = tostring(zoneKey or select(1, self:GetCurrentContentCategory()) or "outdoor"):lower()
    local lookupKey = zk
    if zk == "outdoor" or zk == "city" or zk == "scenario" then
        lookupKey = "delve"
    elseif zk == "dungeon" then
        lookupKey = "mplus"
    end
    if self.db.omniFolio.presetMode == "WOWHEAD" then
        local specID = self:GetActiveSpecInfo()
        local meta = self:GetSpecMetadata(specID)
        return meta[lookupKey] or "HASTE"
    end
    local val = self.db.omniFolio[lookupKey]
    if not VALID_FOLIO_TARGET_STATS[val] then
        local specID = self:GetActiveSpecInfo()
        local meta = self:GetSpecMetadata(specID)
        val = meta[lookupKey] or "HASTE"
        self.db.omniFolio[lookupKey] = val
    end
    return val
end

function DynamicPrep:FindOmniFolioItemInBags()
    if not C_Container or not C_Container.GetContainerNumSlots then return nil, nil, nil end
    local maxBag = (type(_G.NUM_BAG_SLOTS) == "number" and _G.NUM_BAG_SLOTS) or 4
    for bag = 0, maxBag do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local link = C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot)
            if link and not _IsSecret(link) and type(link) == "string" then
                local low = link:lower()
                for _, pat in ipairs(FOLIO_ITEM_PATTERNS) do
                    if low:find(pat, 1, true) then
                        return bag, slot, link
                    end
                end
            end
        end
    end
    return nil, nil, nil
end

function DynamicPrep:ScanOmnialInquiryMotes()
    if not C_Container or not C_Container.GetContainerNumSlots then return 0 end
    local maxBag = ((type(_G.NUM_BAG_SLOTS) == "number" and _G.NUM_BAG_SLOTS) or 4) + 1
    local total = 0
    for bag = 0, maxBag do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
            if info and not _IsSecret(info) then
                local link = (not _IsSecret(info.hyperlink) and type(info.hyperlink) == "string") and info.hyperlink or nil
                local itemName = (not _IsSecret(info.itemName) and type(info.itemName) == "string") and info.itemName or nil
                local checkText = (link or itemName or ""):lower()
                if checkText ~= "" then
                    local matched = false
                    for _, pat in ipairs(FOLIO_MOTE_PATTERNS) do
                        if checkText:find(pat, 1, true) then
                            matched = true
                            break
                        end
                    end
                    if matched then
                        local cnt = (not _IsSecret(info.stackCount) and tonumber(info.stackCount)) or 1
                        total = total + math.max(1, cnt)
                    end
                end
            end
        end
    end
    return total
end

function DynamicPrep:DetectActiveFolioBuffStat(forceScan)
    local now = GetTime and GetTime() or 0
    if _AreAurasSecret("player") or _IsInActiveKeyOrCombat() or (InCombatLockdown and InCombatLockdown()) or (not forceScan and self._lastFolioScanTime and (now - self._lastFolioScanTime) < 2.0) then
        local cached = self._cachedFolioBuffStat
        if not VALID_FOLIO_ACTIVE_STATS[cached] then
            cached = (self.db and VALID_FOLIO_ACTIVE_STATS[self.db.activeFolioStat]) and self.db.activeFolioStat or nil
        end
        return cached, self._cachedFolioBuffName
    end
    self._lastFolioScanTime = now
    self._cachedFolioBuffStat, self._cachedFolioBuffName = nil, nil
    self._cachedFolioRunes = {}
    local seenKeys = {}

    local function HasFolioAnchor(lowerName)
        for _, anc in ipairs(FOLIO_BUFF_ANCHORS) do
            if lowerName:find(anc, 1, true) then
                return true
            end
        end
        return false
    end

    -- Scan player buffs for Omnium Folio secondary stat choice-node buffs (ignoring passive nodes like Critical Mass)
    if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex and not _AreAurasSecret("player") then
        for i = 1, 40 do
            if _AreAurasSecret("player") then break end
            if not _IsAuraIndexSecret("player", i, "HELPFUL") then
                local okAura, aura = pcall(C_UnitAuras.GetBuffDataByIndex, "player", i, "HELPFUL")
                if not okAura or not aura then break end
                if not _IsSecret(aura) then
                    local name = aura.name
                    if not _IsSecret(name) and type(name) == "string" and name ~= "" then
                        local low = name:lower()
                        local isPassiveRune = low:find("critical mass", 1, true) or low:find("empowerment", 1, true)
                        if not isPassiveRune and HasFolioAnchor(low) then
                            local matchedEntry = nil
                            for _, entry in ipairs(FOLIO_RUNE_CATALOG) do
                                for _, pat in ipairs(entry.patterns) do
                                    if low:find(pat, 1, true) then
                                        matchedEntry = entry
                                        break
                                    end
                                end
                                if matchedEntry then break end
                            end
                            if matchedEntry then
                                if not seenKeys[matchedEntry.key] then
                                    seenKeys[matchedEntry.key] = true
                                    table.insert(self._cachedFolioRunes, {
                                        key   = matchedEntry.key,
                                        label = matchedEntry.label,
                                        name  = name,
                                    })
                                end
                                if not self._cachedFolioBuffStat then
                                    self._cachedFolioBuffStat = matchedEntry.key
                                    self._cachedFolioBuffName = name
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if self._cachedFolioBuffStat then
        if self.db then self.db.activeFolioStat = self._cachedFolioBuffStat end
        return self._cachedFolioBuffStat, self._cachedFolioBuffName
    end
    local saved = self.db and self.db.activeFolioStat
    if VALID_FOLIO_ACTIVE_STATS[saved] then
        return saved, nil
    end
    if self.db and self.db.activeFolioStat ~= nil then
        self.db.activeFolioStat = nil
    end
    return nil, nil
end

local function IsSecretValue(val)
    if canaccessvalue and not canaccessvalue(val) then return true end
    if issecretvalue and issecretvalue(val) then return true end
    return false
end


local function SafeCompare(val1, op, val2)
    if canaccessvalue and (not canaccessvalue(val1) or not canaccessvalue(val2)) then return false end
    if issecretvalue and (issecretvalue(val1) or issecretvalue(val2)) then return false end
    local ok, res = pcall(function()
        if op == ">" then return val1 > val2
        elseif op == ">=" then return val1 >= val2
        elseif op == "<" then return val1 < val2
        elseif op == "<=" then return val1 <= val2
        elseif op == "==" then return val1 == val2
        end
        return false
    end)
    return ok and res or false
end

local function SafeGetStringWidth(fs, defaultW)
    if not fs or not fs.GetStringWidth then return defaultW or 60 end
    local ok, w = pcall(function()
        local rawW = fs:GetStringWidth()
        if IsSecretValue and IsSecretValue(rawW) then return nil end
        if canaccessvalue and not canaccessvalue(rawW) then return nil end
        local n = tonumber(rawW)
        if n and n > 0 then return math.ceil(n) end
        return nil
    end)
    if ok and w then return w end
    return defaultW or 60
end

function DynamicPrep:FormatCompactNumber(num)
    if canaccessvalue and not canaccessvalue(num) then return tostring(num or 0) end
    if issecretvalue and issecretvalue(num) then return tostring(num or 0) end
    local ok, res = pcall(function()
        local n = tonumber(num) or 0
        if n >= 1000000 then
            return string.format("%.2fM", n / 1000000)
        elseif n >= 1000 then
            return string.format("%.1fk", n / 1000)
        end
        return tostring(math.floor(n + 0.5))
    end)
    if ok and res then return res end
    return tostring(num or 0)
end

function DynamicPrep:GetPrimaryStatData()
    if _IsInActiveKeyOrCombat() and self._cachedPrimaryTuple then
        local t = self._cachedPrimaryTuple
        return t[1], t[2], t[3], t[4], t[5]
    end
    local _, _, primaryStatIndex = self:GetActiveSpecInfo()
    local statLabel = "Int"
    if primaryStatIndex == 1 then
        statLabel = "Str"
    elseif primaryStatIndex == 2 then
        statLabel = "Agi"
    else
        primaryStatIndex = 4
        statLabel = "Int"
    end

    local base, effectiveStat, posBuff = UnitStat("player", primaryStatIndex)
    if not IsSecretValue(effectiveStat) then
        effectiveStat = tonumber(effectiveStat) or 0
    end
    if not IsSecretValue(posBuff) then
        posBuff = tonumber(posBuff) or 0
    end

    if not InCombatLockdown() then
        self._safeRestingPrimaryBaseline = effectiveStat
    elseif not self._safeRestingPrimaryBaseline or SafeCompare(self._safeRestingPrimaryBaseline, "<=", 0) then
        self._safeRestingPrimaryBaseline = (not IsSecretValue(base) and tonumber(base)) or effectiveStat
    end

    local isProcActive = false
    if InCombatLockdown() and self._safeRestingPrimaryBaseline and not IsSecretValue(effectiveStat) and not IsSecretValue(self._safeRestingPrimaryBaseline) then
        local ok, proc = pcall(function()
            return effectiveStat > (self._safeRestingPrimaryBaseline * 1.01)
        end)
        if ok and proc then isProcActive = true end
    end
    if not isProcActive and InCombatLockdown() then
        if SafeCompare(posBuff, ">", 0) then
            isProcActive = true
        end
    end

    local formatted = self:FormatCompactNumber(effectiveStat)
    local theme = (self.db and self.db.barColorTheme) or "PRIORITY_GLOW"
    local valHex = "2DD4BF" -- Mint Teal default in Priority Glow
    if theme == "CLASS_ACCENT" then
        local _, _, _, cHex = GetPlayerClassColor()
        valHex = cHex or GetAccentHex()
    elseif theme == "MONOCHROME" then
        valHex = "FFFFFF"
    end

    local procSuffix = isProcActive and " *" or ""
    local text = string.format("|cFF94A3B8%s|r |cFF%s%s%s|r", statLabel, valHex, formatted, procSuffix)

    -- Check non-zero Tertiary stat (Leech / Avoidance / Speed) in Priority Glow
    local leech = GetLifesteal and GetLifesteal() or 0
    if leech and SafeCompare(leech, ">=", 0.5) then
        local tertHex = (theme == "MONOCHROME") and "CBD5E1" or "E879F9"
        local okLeech, leechInt = pcall(function() return math.floor(leech + 0.5) end)
        text = text .. string.format(" |cFF94A3B8Leech|r |cFF%s%s%%|r", tertHex, okLeech and tostring(leechInt) or tostring(leech))
    end

    self._cachedPrimaryTuple = self._cachedPrimaryTuple or {}
    local pt = self._cachedPrimaryTuple
    pt[1], pt[2], pt[3], pt[4], pt[5] = text, statLabel, effectiveStat, self._safeRestingPrimaryBaseline or effectiveStat, isProcActive
    return text, statLabel, effectiveStat, self._safeRestingPrimaryBaseline or effectiveStat, isProcActive
end

function DynamicPrep:GetSecondaryStatsData()
    if _IsInActiveKeyOrCombat() and self._cachedSecondaryTuple then
        local t = self._cachedSecondaryTuple
        return t[1], t[2], t[3], t[4], t[5]
    end
    local crit = GetCritChance and GetCritChance() or 0
    local haste = GetHaste and GetHaste() or 0
    local mast = GetMasteryEffect and GetMasteryEffect() or 0
    local vers = 0
    if GetCombatRatingBonus and CR_VERSATILITY_DAMAGE_DONE then
        local okV, vSum = pcall(function()
            return (GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) or 0) + (GetVersatilityBonus and GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE) or 0)
        end)
        vers = (okV and vSum) or (GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) or 0)
    end

    local specID = self:GetActiveSpecInfo()
    local meta = self:GetSpecMetadata(specID)
    local weightOrder = {}
    if meta and meta.weights then
        for idx, statKey in ipairs(meta.weights) do
            weightOrder[statKey] = idx
        end
    end

    local entries = {
        { key = "CRIT",    label = "Crit",  val = crit,  fixedIdx = 1, wRank = weightOrder["CRIT"] or 4 },
        { key = "HASTE",   label = "Haste", val = haste, fixedIdx = 2, wRank = weightOrder["HASTE"] or 4 },
        { key = "MASTERY", label = "Mast",  val = mast,  fixedIdx = 3, wRank = weightOrder["MASTERY"] or 4 },
        { key = "VERS",    label = "Vers",  val = vers,  fixedIdx = 4, wRank = weightOrder["VERS"] or 4 },
    }
    local entryMap = {
        CRIT    = entries[1],
        HASTE   = entries[2],
        MASTERY = entries[3],
        VERS    = entries[4],
    }

    -- Rank stats 1..4 by highest current value (breaking ties by spec priority weight)
    local ranked = { entries[1], entries[2], entries[3], entries[4] }
    pcall(function()
        table.sort(ranked, function(a, b)
            if IsSecretValue(a.val) or IsSecretValue(b.val) then
                return a.wRank < b.wRank
            end
            local okDiff, hasDiff = pcall(function() return math.abs(a.val - b.val) > 0.05 end)
            if okDiff and hasDiff then
                return SafeCompare(a.val, ">", b.val)
            end
            return a.wRank < b.wRank
        end)
    end)
    for rankIdx, item in ipairs(ranked) do
        item.valueRank = rankIdx
    end

    local sortMode = (self.db and (self.db.secondaryStatOrderMode or self.db.statSortMode)) or "RANK"
    local displayList = ranked
    if sortMode == "CUSTOM" or sortMode == "FIXED" then
        displayList = {}
        local customOrder = (self.db and self.db.customSecondaryOrder) or DEFAULT_CUSTOM_SECONDARY_ORDER
        for _, sk in ipairs(customOrder) do
            if entryMap[sk] then
                table.insert(displayList, entryMap[sk])
            end
        end
        if #displayList < 4 then
            displayList = entries
        end
    end
    local theme = (self.db and self.db.barColorTheme) or "PRIORITY_GLOW"
    local accentHex = GetAccentHex()
    local _, _, _, classHex = GetPlayerClassColor()

    local parts = {}
    for _, item in ipairs(displayList) do
        local valStr
        if IsSecretValue(item.val) then
            valStr = tostring(item.val) .. "%"
        else
            local okFmt, fmtRes = pcall(function() return string.format("%d%%", math.floor(item.val + 0.5)) end)
            valStr = (okFmt and fmtRes) or (tostring(item.val) .. "%")
        end
        local vHex = "CBD5E1"
        if theme == "PRIORITY_GLOW" then
            if item.valueRank == 1 then
                vHex = accentHex or "FBBF24"
            elseif item.valueRank == 2 then
                vHex = "FDE68A" -- Warm Ivory
            else
                vHex = "CBD5E1" -- Cool Periwinkle / Silver
            end
        elseif theme == "CLASS_ACCENT" then
            if item.valueRank == 1 then
                vHex = classHex or accentHex
            elseif item.valueRank == 2 then
                vHex = "FFFFFF"
            else
                vHex = "CBD5E1"
            end
        else -- MONOCHROME
            vHex = "FFFFFF"
        end
        table.insert(parts, string.format("|cFF94A3B8%s|r |cFF%s%s|r", item.label, vHex, valStr))
    end

    local text = SafeTableConcat(parts, "  ")
    self._cachedSecondaryTuple = self._cachedSecondaryTuple or {}
    local st = self._cachedSecondaryTuple
    st[1], st[2], st[3], st[4], st[5] = text, crit, haste, mast, vers
    return text, crit, haste, mast, vers
end

function DynamicPrep:GetStatWeightsText()
    local specID = self:GetActiveSpecInfo()
    local meta = self:GetSpecMetadata(specID)
    local w = meta.weights or { "HASTE", "MASTERY", "CRIT", "VERS" }
    local accentHex = GetAccentHex()
    return string.format(
        "|cFF94A3B8Prio|r |cFF%s%s|r |cFF64748B>|r |cFFFDE68A%s|r |cFF64748B>|r |cFFCBD5E1%s|r |cFF64748B>|r |cFF94A3B8%s|r",
        accentHex,
        STAT_SHORT[w[1]] or w[1],
        STAT_SHORT[w[2]] or w[2],
        STAT_SHORT[w[3]] or w[3],
        STAT_SHORT[w[4]] or w[4]
    )
end

function DynamicPrep:GetSpecAndLootData()
    local activeSpecID, activeSpecName = self:GetActiveSpecInfo()
    local lootSpecID = GetLootSpecialization and GetLootSpecialization() or 0
    local lootSpecName = activeSpecName
    local isOffSpecLoot = false

    if lootSpecID and lootSpecID ~= 0 and lootSpecID ~= activeSpecID then
        isOffSpecLoot = true
        if GetSpecializationInfoByID then
            local _, name = GetSpecializationInfoByID(lootSpecID)
            if name and name ~= "" then
                lootSpecName = name
            end
        end
    end

    local _, _, _, classHex = GetPlayerClassColor()
    local theme = (self.db and self.db.barColorTheme) or "PRIORITY_GLOW"
    local specHex = (theme == "MONOCHROME") and "FFFFFF" or (classHex or GetAccentHex())

    local text
    if isOffSpecLoot then
        text = string.format("|cFF94A3B8Spec|r |cFF%s%s|r |cFFFBBF24[Loot: %s]|r", specHex, activeSpecName, lootSpecName)
    else
        text = string.format("|cFF94A3B8Spec/Loot|r |cFF%s%s|r", specHex, activeSpecName)
    end
    return text, activeSpecName, lootSpecName, isOffSpecLoot, activeSpecID, lootSpecID
end

do
local ENCHANT_CHECK_SLOTS = {
    { slot = 1,  label = "Head" },
    { slot = 3,  label = "Shoulder" },
    { slot = 5,  label = "Chest" },
    { slot = 7,  label = "Legs" },
    { slot = 8,  label = "Feet" },
    { slot = 11, label = "Ring 1" },
    { slot = 12, label = "Ring 2" },
    { slot = 16, label = "Main Hand" },
    { slot = 17, label = "Off-Hand", weaponOnly = true },
}

local GEAR_SLOT_LABELS = {
    [1]  = "Head",
    [2]  = "Neck",
    [3]  = "Shoulder",
    [5]  = "Chest",
    [6]  = "Waist",
    [7]  = "Legs",
    [8]  = "Feet",
    [9]  = "Wrist",
    [10] = "Hands",
    [11] = "Ring 1",
    [12] = "Ring 2",
    [13] = "Trinket 1",
    [14] = "Trinket 2",
    [15] = "Cloak",
    [16] = "Main Hand",
    [17] = "Off-Hand",
}

local EMPTY_SOCKET_STRINGS = {}
for _, gName in ipairs({
    "EMPTY_SOCKET_PRISMATIC", "EMPTY_SOCKET_RED", "EMPTY_SOCKET_BLUE",
    "EMPTY_SOCKET_YELLOW", "EMPTY_SOCKET_META", "EMPTY_SOCKET_COGWHEEL",
    "EMPTY_SOCKET_HYDRAULIC", "EMPTY_SOCKET_DOMINATION", "EMPTY_SOCKET_CYPHER",
    "EMPTY_SOCKET_TINKER", "EMPTY_SOCKET_PRIMORDIAL", "EMPTY_SOCKET_SINGINGTHUNDER",
    "EMPTY_SOCKET_SINGINGSEA", "EMPTY_SOCKET_SINGINGWIND",
}) do
    local val = _G[gName]
    if type(val) == "string" and val ~= "" then
        EMPTY_SOCKET_STRINGS[val:lower()] = true
    end
end

function DynamicPrep:ScanEquippedGearEnchantsAndGems()
    if (InCombatLockdown and InCombatLockdown()) or _IsInActiveKeyOrCombat() then
        return self._gearAuditCache
    end

    local result = {
        missingEnchants = {},
        missingEnchantSlotIDs = {},
        emptyGemCount = 0,
        totalGemCount = 0,
        emptyGemSlots = {},
        emptyGemSlotIDs = {},
        flaggedSlotIDs = {},
    }

    local playerLevel = (UnitLevel and UnitLevel("player")) or 0
    local maxLevel = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or 90
    local checkEnchants = (playerLevel > 0 and maxLevel > 0 and playerLevel >= maxLevel)

    local enchantSlotMap = {}
    for _, entry in ipairs(ENCHANT_CHECK_SLOTS) do
        enchantSlotMap[entry.slot] = entry
    end

    local emptySlotSeen = {}
    local gemLineType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.GemSocket

    for slot = 1, 18 do
        local okLink, link = pcall(GetInventoryItemLink, "player", slot)
        if okLink and type(link) == "string" and not _IsSecret(link) and link ~= "" then
            local okQual, quality = pcall(GetInventoryItemQuality, "player", slot)
            if not okQual or _IsSecret(quality) or type(quality) ~= "number" then
                quality = 4
            end

            local classID, invType = nil, nil
            if C_Item and C_Item.GetItemInfoInstant then
                local okInst, _, _, _, iType, _, cID = pcall(C_Item.GetItemInfoInstant, link)
                if okInst then
                    classID = (not _IsSecret(cID)) and cID or nil
                    invType = (not _IsSecret(iType)) and iType or nil
                end
            end

            local tipLines = nil
            if C_TooltipInfo and type(C_TooltipInfo.GetInventoryItem) == "function" then
                local okTip, tipData = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
                if okTip and type(tipData) == "table" and not _IsSecret(tipData) and type(tipData.lines) == "table" then
                    tipLines = tipData.lines
                end
            end

            local enchEntry = enchantSlotMap[slot]
            if checkEnchants and enchEntry and quality > 1 and quality ~= 7 then
                local shouldCheckSlot = true
                if enchEntry.weaponOnly then
                    local weaponClass = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2
                    if classID ~= weaponClass or invType == "INVTYPE_HOLDABLE" or invType == "INVTYPE_SHIELD" then
                        shouldCheckSlot = false
                    end
                end
                if shouldCheckSlot then
                    local enchantID = tonumber(link:match("item:%d+:(%d*):")) or 0
                    local hasEnchant = (enchantID > 0)
                    if not hasEnchant and tipLines then
                        for _, line in ipairs(tipLines) do
                            local lt = line.leftText
                            if type(lt) == "string" and not _IsSecret(lt) then
                                local ltl = lt:lower()
                                if ltl:find("^enchanted:") then
                                    hasEnchant = true
                                    break
                                end
                            end
                        end
                    end
                    if not hasEnchant then
                        table.insert(result.missingEnchants, enchEntry.label)
                        result.missingEnchantSlotIDs[slot] = enchEntry.label
                        result.flaggedSlotIDs[slot] = true
                    end
                end
            end

            if tipLines then
                for _, line in ipairs(tipLines) do
                    local isSocketLine = false
                    if gemLineType ~= nil and not _IsSecret(line.type) and line.type == gemLineType then
                        isSocketLine = true
                    elseif line.socketType ~= nil and not _IsSecret(line.socketType) then
                        isSocketLine = true
                    end

                    local lt = line.leftText
                    local ltl = (type(lt) == "string" and not _IsSecret(lt)) and lt:lower() or ""
                    local isEmptyText = (ltl ~= "" and (EMPTY_SOCKET_STRINGS[ltl] or ltl:find("empty .* socket") ~= nil or ltl == "prismatic socket"))

                    if isSocketLine or isEmptyText then
                        result.totalGemCount = result.totalGemCount + 1
                        local hasGemIcon = (line.gemIcon ~= nil and not _IsSecret(line.gemIcon) and tonumber(line.gemIcon) ~= 0)
                        if isEmptyText or (isSocketLine and not hasGemIcon) then
                            result.emptyGemCount = result.emptyGemCount + 1
                            local sLabel = GEAR_SLOT_LABELS[slot] or ("Slot " .. slot)
                            result.emptyGemSlotIDs[slot] = sLabel
                            result.flaggedSlotIDs[slot] = true
                            if not emptySlotSeen[slot] then
                                emptySlotSeen[slot] = true
                                table.insert(result.emptyGemSlots, sLabel)
                            end
                        end
                    end
                end
            end
        end
    end

    self._gearAuditCache = result
    if self.UpdatePaperdollSlotHighlights then
        self:UpdatePaperdollSlotHighlights()
    end
    return result
end

local PAPERDOLL_SLOT_FRAMES = {
    [1]  = "CharacterHeadSlot",
    [2]  = "CharacterNeckSlot",
    [3]  = "CharacterShoulderSlot",
    [5]  = "CharacterChestSlot",
    [6]  = "CharacterWaistSlot",
    [7]  = "CharacterLegsSlot",
    [8]  = "CharacterFeetSlot",
    [9]  = "CharacterWristSlot",
    [10] = "CharacterHandsSlot",
    [11] = "CharacterFinger0Slot",
    [12] = "CharacterFinger1Slot",
    [13] = "CharacterTrinket0Slot",
    [14] = "CharacterTrinket1Slot",
    [15] = "CharacterBackSlot",
    [16] = "CharacterMainHandSlot",
    [17] = "CharacterSecondaryHandSlot",
}

local paperdollSlotOverlays = {}

function DynamicPrep:EnsurePaperdollHighlightHooks()
    if not self._paperdollCharHooked and _G.CharacterFrame and _G.CharacterFrame.HookScript then
        self._paperdollCharHooked = true
        _G.CharacterFrame:HookScript("OnShow", function()
            if not (InCombatLockdown and InCombatLockdown()) then
                DynamicPrep:ScanEquippedGearEnchantsAndGems()
                DynamicPrep:UpdatePaperdollSlotHighlights()
            end
        end)
    end
    if not self._paperdollTabHooked and _G.PaperDollFrame and _G.PaperDollFrame.HookScript then
        self._paperdollTabHooked = true
        _G.PaperDollFrame:HookScript("OnShow", function()
            if not (InCombatLockdown and InCombatLockdown()) then
                DynamicPrep:ScanEquippedGearEnchantsAndGems()
                DynamicPrep:UpdatePaperdollSlotHighlights()
            end
        end)
    end
end

function DynamicPrep:UpdatePaperdollSlotHighlights()
    if (InCombatLockdown and InCombatLockdown()) or _IsInActiveKeyOrCombat() then
        return
    end
    self:EnsurePaperdollHighlightHooks()
    if not _G.CharacterFrame or not _G.CharacterFrame:IsShown() then
        for _, ov in pairs(paperdollSlotOverlays) do
            if ov and ov.Hide then
                ov:Hide()
            end
        end
        return
    end

    local audit = self._gearAuditCache or self:ScanEquippedGearEnchantsAndGems()
    local flagged = audit and audit.flaggedSlotIDs
    local simAudit = (self._simPaperdollAudit == true)

    for slotID, frameName in pairs(PAPERDOLL_SLOT_FRAMES) do
        local slotBtn = _G[frameName]
        local isFlagged = (flagged and flagged[slotID] == true) or (simAudit and (slotID == 1 or slotID == 11))
        if isFlagged and slotBtn then
            local ov = paperdollSlotOverlays[slotID]
            if not ov then
                ov = CreateFrame("Frame", nil, slotBtn, "BackdropTemplate")
                ov:SetAllPoints(slotBtn)
                ov:EnableMouse(false)
                ov:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
                ov:SetBackdropBorderColor(0.984, 0.749, 0.141, 0.95)
                paperdollSlotOverlays[slotID] = ov
            end
            if ov.SetFrameLevel and slotBtn.GetFrameLevel then
                ov:SetFrameLevel((slotBtn:GetFrameLevel() or 1) + 8)
            end
            ov:Show()
        elseif paperdollSlotOverlays[slotID] then
            paperdollSlotOverlays[slotID]:Hide()
        end
    end
end

function DynamicPrep:TogglePaperdollAuditPreview()
    if (InCombatLockdown and InCombatLockdown()) or _IsInActiveKeyOrCombat() then
        print(string.format("|cFF%sDynamicPrep:|r Cannot toggle /dprep testaudit preview during combat or an active Mythic+ run.", GetAccentHex()))
        return
    end
    self._simPaperdollAudit = not (self._simPaperdollAudit == true)
    if self._simPaperdollAudit then
        if not (_G.CharacterFrame and _G.CharacterFrame:IsShown() and _G.PaperDollFrame and _G.PaperDollFrame:IsShown()) and type(ToggleCharacter) == "function" then
            pcall(ToggleCharacter, "PaperDollFrame")
        end
        self:UpdatePaperdollSlotHighlights()
        print(string.format("|cFF%sDynamicPrep:|r Paperdoll audit preview |cFFFBBF24ON|r (Head & Ring 1 highlighted; run /dprep testaudit again to clear).", GetAccentHex()))
    else
        self:ScanEquippedGearEnchantsAndGems()
        self:UpdatePaperdollSlotHighlights()
        print(string.format("|cFF%sDynamicPrep:|r Paperdoll audit preview cleared.", GetAccentHex()))
    end
end
end

function DynamicPrep:GetDurabilityData()
    local lowest = 100
    local totalCur, totalMax = 0, 0
    for slot = 1, 18 do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            totalCur = totalCur + cur
            totalMax = totalMax + max
            local pct = math.floor((cur / max) * 100 + 0.5)
            if pct < lowest then
                lowest = pct
            end
        end
    end
    local avg = (totalMax > 0) and math.floor((totalCur / totalMax) * 100 + 0.5) or 100
    if not self._gearAuditCache and not (InCombatLockdown and InCombatLockdown()) and not _IsInActiveKeyOrCombat() then
        self:ScanEquippedGearEnchantsAndGems()
    end
    local audit = self._gearAuditCache
    local hasGearIssue = audit and ((#(audit.missingEnchants or {}) > 0) or ((audit.emptyGemCount or 0) > 0))
    local issueBadge = hasGearIssue and " |cFFFBBF24!|r" or ""
    local text
    if lowest < 30 then
        text = string.format("|cFF94A3B8Dur|r |cFFF87171%d%% Repair!|r%s", lowest, issueBadge)
    elseif lowest < 50 then
        text = string.format("|cFF94A3B8Dur|r |cFFFBBF24%d%%|r%s", lowest, issueBadge)
    else
        text = string.format("|cFF94A3B8Dur|r |cFFFFFFFF%d%%|r%s", lowest, issueBadge)
    end
    return text, lowest, avg
end

function DynamicPrep:GetBagSlotsData()
    local freeSlots, totalSlots = 0, 0
    if C_Container and C_Container.GetContainerNumFreeSlots and C_Container.GetContainerNumSlots then
        for bag = 0, 4 do
            local free = C_Container.GetContainerNumFreeSlots(bag) or 0
            local total = C_Container.GetContainerNumSlots(bag) or 0
            freeSlots = freeSlots + free
            totalSlots = totalSlots + total
        end
    end
    local color = "|cFFFFFFFF"
    if freeSlots <= 4 then
        color = "|cFFF87171"
    elseif freeSlots <= 10 then
        color = "|cFFFBBF24"
    end
    local text = string.format("|cFF94A3B8Bags|r %s%d/%d|r", color, freeSlots, totalSlots)
    return text, freeSlots, totalSlots
end

local DUNGEON_ABBREVIATIONS = {
    ["Ruby Life Pools"]                  = "RLP",
    ["Siege of Boralus"]                 = "SOB",
    ["The Stonevault"]                   = "SV",
    ["The Dawnbreaker"]                  = "DB",
    ["Ara-Kara, City of Echoes"]         = "AK",
    ["City of Threads"]                  = "COT",
    ["Grim Batol"]                       = "GB",
    ["Mists of Tirna Scithe"]            = "MISTS",
    ["The Necrotic Wake"]                = "NW",
    ["Cinderbrew Meadery"]               = "BREW",
    ["Darkflame Cleft"]                  = "DFC",
    ["The Priory of the Sacred Flame"]   = "PSF",
    ["Priory of the Sacred Flame"]       = "PSF",
    ["The Rookery"]                      = "ROOK",
    ["Operation: Floodgate"]             = "FG",
    ["Theater of Pain"]                  = "TOP",
    ["The Motherlode!!"]                 = "ML",
    ["The MOTHERLODE!!"]                 = "ML",
    ["Operation: Mechagon - Workshop"]   = "WORK",
    ["Operation: Mechagon - Junkyard"]   = "YARD",
    ["Algeth'ar Academy"]                = "AA",
    ["The Nokhud Offensive"]             = "NO",
    ["Brackenhide Hollow"]               = "BH",
    ["Halls of Infusion"]                = "HOI",
    ["Neltharus"]                        = "NELT",
    ["The Azure Vault"]                  = "BV",
    ["Black Rook Hold"]                  = "BRH",
    ["Waycrest Manor"]                   = "WCM",
    ["Freehold"]                         = "FH",
    ["Atal'Dazar"]                       = "AD",
    ["Throne of the Tides"]              = "TOS",
    ["Everbloom"]                        = "EB",
    ["The Everbloom"]                    = "EB",
    ["Halls of Atonement"]               = "HOA",
    ["Uldaman: Legacy of Tyr"]           = "ULD",
    ["The Vortex Pinnacle"]              = "VP",
    ["Tazavesh: Streets of Wonder"]      = "STRT",
    ["Tazavesh: Streets"]                = "STRT",
    ["Tazavesh: So'leah's Gambit"]       = "GMBT",
    ["Tazavesh: Gambit"]                 = "GMBT",
    ["Dawn of the Infinite: Galakrond's Fall"] = "FALL",
    ["Dawn of the Infinite: Murozond's Rise"]  = "RISE",
    ["Den of Nalorakk"]                  = "DON",
    ["Altar of Fangs"]                   = "AOF",
    ["Murder Row"]                       = "MR",
    ["Magisters' / Murder Row"]          = "MR",
    ["Venomous Abyss"]                   = "VSA",
    ["Magisters' Terrace"]               = "MT",
    ["Maisara Caverns"]                  = "MC",
    ["Nexus-Point Xenas"]                = "NPX",
    ["Windrunner Spire"]                 = "WS",
    ["Skyreach"]                         = "SKY",
    ["Seat of the Triumvirate"]          = "SOTT",
    ["Pit of Saron"]                     = "POS",
}

local ACRONYM_STOP_WORDS = {
    ["the"] = true,
    ["of"]  = true,
    ["and"] = true,
    ["in"]  = true,
    ["to"]  = true,
    ["for"] = true,
    ["at"]  = true,
    ["a"]   = true,
    ["an"]  = true,
}

local function GetDungeonAbbreviation(name)
    if not name or name == "" then return "KEY" end
    if DUNGEON_ABBREVIATIONS[name] then
        return DUNGEON_ABBREVIATIONS[name]
    end
    local lowerName = name:lower()
    for k, v in pairs(DUNGEON_ABBREVIATIONS) do
        if k:lower() == lowerName then
            return v
        end
    end
    local words = {}
    for w in name:gmatch("[%a]+") do
        if not ACRONYM_STOP_WORDS[w:lower()] then
            table.insert(words, w)
        end
    end
    if #words == 0 then
        return name:sub(1, 4):upper()
    elseif #words == 1 then
        return words[1]:sub(1, 4):upper()
    else
        local initials = {}
        for _, w in ipairs(words) do
            table.insert(initials, w:sub(1, 1):upper())
        end
        return SafeTableConcat(initials, "")
    end
end

function DynamicPrep:GetKeystoneData()
    local level = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel and C_MythicPlus.GetOwnedKeystoneLevel() or 0
    local mapID = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID and C_MythicPlus.GetOwnedKeystoneChallengeMapID() or nil
    if level and level > 0 and mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        local abbrev = GetDungeonAbbreviation(name)
        return string.format("|cFF94A3B8Key|r |cFF%s+%d|r |cFFFFFFFF%s|r", GetAccentHex(), level, abbrev), level, name or abbrev, abbrev
    end
    return "|cFF94A3B8Key|r |cFF64748BNone|r", 0, nil, nil
end

function DynamicPrep:GetOmniFolioData()
    local rawZoneKey = self:GetCurrentContentCategory()
    local zk = tostring(rawZoneKey or "outdoor"):lower()
    local zoneTag = ZONE_TAGS[zk] or "Outdoor"
    local bracketTag = "[" .. zoneTag .. "]"
    local targetStat = self:GetTargetFolioStatForZone(zk) or "HASTE"
    if targetStat == "OFF" then
        return string.format("|cFF94A3B8Folio %s|r |cFF64748BOff|r", bracketTag), false, targetStat, nil, bracketTag
    end
    local activeStat = self:DetectActiveFolioBuffStat()
    local matchedByList = false
    if activeStat and self._cachedFolioRunes then
        for _, r in ipairs(self._cachedFolioRunes) do
            if r.key == targetStat then
                matchedByList = true
                activeStat = r.key
                break
            end
        end
    end
    local targetShort = tostring(STAT_SHORT[targetStat] or targetStat or "Haste")
    local isMismatch = (activeStat ~= nil and activeStat ~= targetStat and not matchedByList)
    if activeStat == nil then
        local inInst = false
        if type(IsInInstance) == "function" then
            local okI, rIn = pcall(IsInInstance)
            if okI and not _IsSecret(rIn) and rIn == true then inInst = true end
        end
        local activeSpecID = self:GetActiveSpecInfo()
        if ((inInst and zk ~= "scenario" and activeSpecID ~= nil) or self.previewFolioMismatch) then
            isMismatch = true
        end
    end
    local text
    if isMismatch then
        local curLabel = tostring(activeStat and (STAT_SHORT[activeStat] or activeStat) or "None")
        text = string.format("|cFFFBBF24Folio %s %s (Cur: %s)|r", bracketTag, targetShort, curLabel)
    else
        text = string.format("|cFF94A3B8Folio %s|r |cFF34D399%s|r", bracketTag, targetShort)
    end
    return text, isMismatch, targetStat, activeStat, bracketTag
end

function DynamicPrep:HasLeaderOrAssistPermission()
    if self.inEditMode then return true end
    local isLeader = UnitIsGroupLeader and UnitIsGroupLeader("player")
    local isAssist = UnitIsGroupAssistant and UnitIsGroupAssistant("player")
    return (isLeader or isAssist) and true or false
end

function DynamicPrep:SampleFpsAndLatency()
    local now = GetTime and GetTime() or 0
    if not self._lastFpsSampleTime or (now - self._lastFpsSampleTime) >= 1.0 or not self._cachedFps then
        self._lastFpsSampleTime = now
        self._cachedFps = math.floor(((GetFramerate and GetFramerate()) or 60) + 0.5)
        local homeMS, worldMS = 0, 0
        if GetNetStats then
            local _, _, h, w = GetNetStats()
            homeMS = math.floor((tonumber(h) or 0) + 0.5)
            worldMS = math.floor((tonumber(w) or 0) + 0.5)
        end
        self._cachedHomeMS = homeMS
        self._cachedWorldMS = worldMS
    end
    return self._cachedFps or 60, self._cachedHomeMS or 0, self._cachedWorldMS or 0
end

function DynamicPrep:GetFPSData()
    local fps = self:SampleFpsAndLatency()
    local colorHex = "34D399"
    if fps < 30 then
        colorHex = "F87171"
    elseif fps < 60 then
        colorHex = "FBBF24"
    end
    local text = string.format("|cFF%s%d FPS|r", colorHex, fps)
    return text, fps, "|cFF" .. colorHex
end

function DynamicPrep:GetPingData()
    local _, homeMS, worldMS = self:SampleFpsAndLatency()
    local mode = (self.db and self.db.pingDisplayMode) or "BOTH"
    local order = (self.db and self.db.pingOrder) or "LOCAL_FIRST"

    local maxMS
    if mode == "LOCAL_ONLY" then
        maxMS = homeMS
    elseif mode == "WORLD_ONLY" then
        maxMS = worldMS
    else
        maxMS = math.max(homeMS or 0, worldMS or 0)
    end

    local colorHex = "34D399"
    if maxMS > 120 then
        colorHex = "F87171"
    elseif maxMS >= 60 then
        colorHex = "FBBF24"
    end

    local rawStr
    if mode == "LOCAL_ONLY" then
        rawStr = string.format("%d ms (Home)", homeMS or 0)
    elseif mode == "WORLD_ONLY" then
        rawStr = string.format("%d ms (World)", worldMS or 0)
    else
        if order == "WORLD_FIRST" then
            rawStr = string.format("%d/%d ms", worldMS or 0, homeMS or 0)
        else
            rawStr = string.format("%d/%d ms", homeMS or 0, worldMS or 0)
        end
    end

    local text = string.format("|cFF%s%s|r", colorHex, rawStr)
    return text, homeMS, worldMS, "|cFF" .. colorHex
end

function DynamicPrep:GetReadyCheckData()
    return "|cFF34D399+|r RC"
end

function DynamicPrep:GetPullTimerData()
    local secs = tonumber(self.db and self.db.pullTimer) or 10
    return string.format("|cFF%s>|r Pull %d", GetAccentHex(), secs), secs
end

function DynamicPrep:GetFPSAndLatencyData()
    local _, fps, fpsColor = self:GetFPSData()
    local _, homeMS, worldMS, msColor = self:GetPingData()
    local text = string.format("%s%d|r |cFF94A3B8FPS|r |cFF475569/|r %s%d|r |cFF94A3B8ms|r", fpsColor, fps, msColor, worldMS)
    return text, fps, worldMS, homeMS, fpsColor, msColor
end

function DynamicPrep:GetHeaderStatusText()
    local topStat = self:GetTopPriorityStatLabel()
    local _, activeSpec, lootSpec, isOffSpec = self:GetSpecAndLootData()
    local _, lowestDur = self:GetDurabilityData()
    local _, fps, worldMS, _, fpsColor, msColor = self:GetFPSAndLatencyData()
    local accentHex = GetAccentHex()
    local specSummary = isOffSpec
        and string.format("|cFFFFFFFF%s|r |cFFFBBF24[Loot: %s]|r", activeSpec or "Spec", lootSpec or "Loot")
        or string.format("|cFFFFFFFF%s|r", activeSpec or "Spec")

    local extraTag = ""
    if self._lastCombatBuffSummary and self._lastCombatBuffSummary.missingCount and self._lastCombatBuffSummary.missingCount > 0 then
        local s = self._lastCombatBuffSummary
        extraTag = string.format("  |cFF475569/|r  |cFFF87171%s: %d/%d MISSING|r", s.shortLabel or "Buff", s.activeCount or 0, math.max(1, s.totalEligible or 1))
    elseif self._symbioticBondCache and self._symbioticBondCache.active and self._symbioticBondCache.coloredName then
        extraTag = string.format("  |cFF475569/|r  |cFF34D399Linked:|r %s", self._symbioticBondCache.coloredName)
    elseif self.GetActiveFoodBuffBenefit then
        local hasFood, foodShort = self:GetActiveFoodBuffBenefit()
        if hasFood and foodShort then
            extraTag = string.format("  |cFF475569/|r  |cFF34D399Food:|r |cFFFFFFFF%s|r", foodShort)
        end
    end

    return string.format(
        "|cFF34D399*|r Prio: |cFF%s%s|r  |cFF475569/|r  Spec: %s%s  |cFF475569/|r  Dur |cFFFFFFFF%d%%|r  |cFF475569/|r  %s%d|r |cFF94A3B8FPS|r  %s%d|r |cFF94A3B8ms|r",
        accentHex,
        topStat or "Haste",
        specSummary,
        extraTag,
        lowestDur or 100,
        fpsColor or "|cFF34D399",
        fps or 60,
        msColor or "|cFF34D399",
        worldMS or 0
    )
end

-- ============================================================================
-- Automatic Alert Toast Deduplication & Fallback Integration
-- ============================================================================
function DynamicPrep:SyncToastFallbackState()
    local barVisible = self.prepBarFrame and self.prepBarFrame:IsShown()
    local _, activeSpec, lootSpec, isOffSpec = self:GetSpecAndLootData()
    local _, lowestDur = self:GetDurabilityData()

    Suite.prepBarVisible = barVisible and true or false
    if not barVisible and self.db and self.db.displayMode == "HIDDEN" then
        Suite.prepToastFallback = string.format(
            "Spec: %s%s | Durability: %d%%",
            activeSpec or "Current",
            isOffSpec and (" [Loot: " .. tostring(lootSpec) .. "]") or "",
            lowestDur or 100
        )
    else
        -- De-duplicate Spec/Loot/Durability from Alert Toast when Top Info Bar is visible
        Suite.prepToastFallback = nil
    end

    if type(Suite.RenderAlertToast) == "function" then
        pcall(Suite.RenderAlertToast, Suite)
    end
end

-- ============================================================================
-- Popovers for Spec/Loot Selection & Omni Folio Selection (Item #41 & #47)
-- ============================================================================
local function SafeRegisterUISpecialFrame(frameName)
    if type(frameName) ~= "string" or frameName == "" or type(_G.UISpecialFrames) ~= "table" then return end
    for i = 1, #_G.UISpecialFrames do
        if _G.UISpecialFrames[i] == frameName then return end
    end
    table.insert(_G.UISpecialFrames, frameName)
end

local function HookPopoverAnchorOnHide(anchorBtn)
    if anchorBtn and type(anchorBtn.HookScript) == "function" and not anchorBtn._dpPopoverOnHideHooked then
        anchorBtn._dpPopoverOnHideHooked = true
        anchorBtn:HookScript("OnHide", function()
            DynamicPrep:HideBarPopovers()
        end)
    end
end

function DynamicPrep:EnsurePopoverClickCatcher()
    if self.popoverClickCatcher then return self.popoverClickCatcher end
    local catcher = CreateFrame("Button", "DynamicPrepPopoverClickCatcher", UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("TOOLTIP")
    catcher:SetFrameLevel(200)
    catcher:EnableMouse(true)
    catcher:RegisterForClicks("AnyDown")
    catcher:SetScript("OnClick", function()
        DynamicPrep:HideBarPopovers()
    end)
    catcher:Hide()
    self.popoverClickCatcher = catcher
    return catcher
end

function DynamicPrep:AreAnyBarPopoversShown()
    if self.lootPopover and self.lootPopover:IsShown() then return true end
    if self.specSwitchPopover and self.specSwitchPopover:IsShown() then return true end
    if self.folioPopover and self.folioPopover:IsShown() then return true end
    if self.pullTimerPopover and self.pullTimerPopover:IsShown() then return true end
    if _G.DynamicTalent and type(_G.DynamicTalent.IsTalentPopoverShown) == "function" then
        local okT, isShown = pcall(_G.DynamicTalent.IsTalentPopoverShown, _G.DynamicTalent)
        if okT and isShown then return true end
    end
    return false
end


function DynamicPrep:HideBarPopovers()
    if self.lootPopover and self.lootPopover:IsShown() then
        self.lootPopover:Hide()
    end
    if self.specSwitchPopover and self.specSwitchPopover:IsShown() then
        self.specSwitchPopover:Hide()
    end
    if self.folioPopover and self.folioPopover:IsShown() then
        self.folioPopover:Hide()
    end
    if self.pullTimerPopover and self.pullTimerPopover:IsShown() then
        self.pullTimerPopover:Hide()
    end
    if _G.DynamicTalent and type(_G.DynamicTalent.HideTalentPopover) == "function" then
        pcall(_G.DynamicTalent.HideTalentPopover, _G.DynamicTalent)
    end
    if self.popoverClickCatcher then
        self.popoverClickCatcher:Hide()
    end
end

function DynamicPrep:ToggleLootSpecPopover(anchorBtn)
    GameTooltip:Hide()
    if self.inEditMode then
        self:HideBarPopovers()
        return
    end
    HookPopoverAnchorOnHide(anchorBtn)
    if not self.lootPopover then
        local pop = CreateFrame("Frame", "DynamicPrepLootSpecPopover", UIParent, "BackdropTemplate")
        pop:SetSize(250, 180)
        pop:SetFrameStrata("TOOLTIP")
        pop:SetFrameLevel(220)
        pop:SetClampedToScreen(true)
        SetPixelBackdrop(pop, { 0.043, 0.051, 0.071, 0.99 }, GetAccentColorTable(1.0), 1)
        local borderOverlay = CreateFrame("Frame", nil, pop, "BackdropTemplate")
        borderOverlay:SetAllPoints(pop)
        borderOverlay:SetFrameStrata("TOOLTIP")
        borderOverlay:SetFrameLevel(230)
        SetPixelBackdrop(borderOverlay, { 0, 0, 0, 0 }, GetAccentColorTable(1.0), 1)
        pop.borderOverlay = borderOverlay
        SafeRegisterUISpecialFrame("DynamicPrepLootSpecPopover")
        pop:SetScript("OnHide", function()
            if DynamicPrep.popoverClickCatcher and not DynamicPrep:AreAnyBarPopoversShown() then
                DynamicPrep.popoverClickCatcher:Hide()
            end
        end)
        pop:Hide()

        pop.header = CreateText(pop, "OVERLAY", "GameFontHighlightSmall")
        pop.header:SetPoint("TOPLEFT", pop, "TOPLEFT", 10, -8)

        pop.buttons = {}
        self.lootPopover = pop
    end

    local pop = self.lootPopover
    if pop:IsShown() then
        pop:Hide()
        return
    end

    if self.specSwitchPopover then self.specSwitchPopover:Hide() end
    if self.folioPopover then self.folioPopover:Hide() end
    if self.pullTimerPopover then self.pullTimerPopover:Hide() end
    if _G.DynamicTalent and type(_G.DynamicTalent.HideTalentPopover) == "function" then
        pcall(_G.DynamicTalent.HideTalentPopover, _G.DynamicTalent)
    end

    local ar, ag, ab, accentHex = GetActiveAccentRGB()
    SetPixelBackdrop(pop, { 0.043, 0.051, 0.071, 0.99 }, { ar, ag, ab, 1.0 }, 1)
    if pop.borderOverlay then
        SetPixelBackdrop(pop.borderOverlay, { 0, 0, 0, 0 }, { ar, ag, ab, 1.0 }, 1)
    end
    pop.header:SetText(string.format("|cFF%sSelect Loot Specialisation|r", accentHex))

    for _, b in ipairs(pop.buttons) do b:Hide() end

    local _, activeSpecName = self:GetActiveSpecInfo()
    local currentLoot = GetLootSpecialization and GetLootSpecialization() or 0
    local numSpecs = SafeGetNumSpecializations()

    local options = {
        { id = 0, label = string.format("Current Spec (Auto - %s)", activeSpecName or "Current") },
    }
    for i = 1, numSpecs do
        local specID, name = SafeGetSpecializationInfo(i)
        if specID and name then
            table.insert(options, { id = specID, label = name })
        end
    end

    local maxTextW = pop.header:GetStringWidth() or 180
    local yOffset = -28
    for idx, opt in ipairs(options) do
        local btn = pop.buttons[idx]
        if not btn then
            btn = CreateFrame("Button", nil, pop, "BackdropTemplate")
            btn:SetHeight(26)
            btn.checkTex = btn:CreateTexture(nil, "OVERLAY")
            btn.checkTex:SetSize(12, 12)
            btn.checkTex:SetPoint("LEFT", btn, "LEFT", 8, 0)
            btn.checkTex:SetTexture(ICON_CHECK)

            btn.text = CreateText(btn, "OVERLAY", "GameFontHighlightSmall")
            btn.text:SetPoint("LEFT", btn, "LEFT", 24, 0)
            btn.text:SetJustifyH("LEFT")
            btn.text:SetWordWrap(false)
            pop.buttons[idx] = btn
        end
        btn:SetPoint("TOPLEFT", pop, "TOPLEFT", 8, yOffset)
        btn:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -8, yOffset)

        local isSelected = (currentLoot == opt.id)
        SetPixelBackdrop(
            btn,
            isSelected and COLORS.BgElevated or COLORS.BgSurface,
            isSelected and { ar, ag, ab, 0.90 } or COLORS.BorderSubtle,
            1
        )
        btn.checkTex:SetVertexColor(ar, ag, ab, 1.0)
        btn.checkTex:SetShown(isSelected)
        btn.text:SetText((isSelected and "|cFFFFFFFF" or "|cFFCBD5E1") .. opt.label .. "|r")

        local tw = btn.text:GetStringWidth() or 120
        if tw > maxTextW then maxTextW = tw end

        btn:SetScript("OnEnter", function(selfB)
            SetPixelBackdrop(selfB, COLORS.BgHover, { ar, ag, ab, 0.85 }, 1)
        end)
        btn:SetScript("OnLeave", function(selfB)
            SetPixelBackdrop(
                selfB,
                isSelected and COLORS.BgElevated or COLORS.BgSurface,
                isSelected and { ar, ag, ab, 0.90 } or COLORS.BorderSubtle,
                1
            )
        end)
        btn:SetScript("OnClick", function()
            if SetLootSpecialization then
                SetLootSpecialization(opt.id)
            end
            pop:Hide()
            C_Timer.After(0.05, function() DynamicPrep:RefreshBar() end)
        end)
        btn:Show()
        yOffset = yOffset - 30
    end

    local catcher = self:EnsurePopoverClickCatcher()
    catcher:Show()

    pop:SetSize(math.max(246, math.ceil(maxTextW) + 52), math.abs(yOffset) + 8)
    pop:ClearAllPoints()
    pop:SetPoint("TOP", anchorBtn, "BOTTOM", 0, -4)
    pop:Show()
end

function DynamicPrep:ToggleActiveSpecPopover(anchorBtn)
    GameTooltip:Hide()
    if self.inEditMode then
        self:HideBarPopovers()
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        print(string.format("|cFF%sDynamicPrep:|r Cannot switch active specialisation while in combat.", GetAccentHex()))
        return
    end
    HookPopoverAnchorOnHide(anchorBtn)
    if not self.specSwitchPopover then
        local pop = CreateFrame("Frame", "DynamicPrepSpecSwitchPopover", UIParent, "BackdropTemplate")
        pop:SetFrameStrata("TOOLTIP")
        pop:SetFrameLevel(220)
        pop:SetClampedToScreen(true)
        pop:EnableMouse(true)
        pop:Hide()
        pop.borderOverlay = CreateFrame("Frame", nil, pop, "BackdropTemplate")
        pop.borderOverlay:SetAllPoints(pop)
        pop.borderOverlay:SetFrameStrata("TOOLTIP")
        pop.borderOverlay:SetFrameLevel(230)
        pop.header = CreateText(pop, "OVERLAY", "GameFontHighlightSmall")
        pop.header:SetPoint("TOPLEFT", pop, "TOPLEFT", 10, -8)
        pop.header:SetJustifyH("LEFT")
        pop.buttons = {}
        SafeRegisterUISpecialFrame("DynamicPrepSpecSwitchPopover")
        pop:SetScript("OnHide", function()
            if DynamicPrep.popoverClickCatcher and not DynamicPrep:AreAnyBarPopoversShown() then
                DynamicPrep.popoverClickCatcher:Hide()
            end
        end)
        self.specSwitchPopover = pop
    end

    local pop = self.specSwitchPopover
    if pop:IsShown() then
        pop:Hide()
        return
    end

    if self.lootPopover then self.lootPopover:Hide() end
    if self.folioPopover then self.folioPopover:Hide() end
    if self.pullTimerPopover then self.pullTimerPopover:Hide() end
    if _G.DynamicTalent and type(_G.DynamicTalent.HideTalentPopover) == "function" then
        pcall(_G.DynamicTalent.HideTalentPopover, _G.DynamicTalent)
    end

    local ar, ag, ab, accentHex = GetActiveAccentRGB()
    SetPixelBackdrop(pop, { 0.043, 0.051, 0.071, 0.99 }, { ar, ag, ab, 1.0 }, 1)
    if pop.borderOverlay then
        SetPixelBackdrop(pop.borderOverlay, { 0, 0, 0, 0 }, { ar, ag, ab, 1.0 }, 1)
    end
    pop.header:SetText(string.format("|cFF%sSwitch Active Specialisation|r", accentHex))

    for _, b in ipairs(pop.buttons) do b:Hide() end

    local curSpecIdx = SafeGetSpecialization() or 1
    local numSpecs = SafeGetNumSpecializations()
    local maxTextW = pop.header:GetStringWidth() or 180
    local yOffset = -28
    for i = 1, numSpecs do
        local specID, name, _, icon = SafeGetSpecializationInfo(i)
        if specID and name then
            local btn = pop.buttons[i]
            if not btn then
                btn = CreateFrame("Button", nil, pop, "BackdropTemplate")
                btn:SetHeight(26)
                btn.iconTex = btn:CreateTexture(nil, "ARTWORK")
                btn.iconTex:SetSize(16, 16)
                btn.iconTex:SetPoint("LEFT", btn, "LEFT", 8, 0)
                btn.iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                btn.text = CreateText(btn, "OVERLAY", "GameFontHighlightSmall")
                btn.text:SetPoint("LEFT", btn.iconTex, "RIGHT", 7, 0)
                btn.text:SetJustifyH("LEFT")
                btn.text:SetWordWrap(false)
                pop.buttons[i] = btn
            end
            btn:SetPoint("TOPLEFT", pop, "TOPLEFT", 8, yOffset)
            btn:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -8, yOffset)

            local isActive = (i == curSpecIdx)
            SetPixelBackdrop(
                btn,
                isActive and { ar * 0.34, ag * 0.34, ab * 0.34, 0.98 } or COLORS.BgSurface,
                isActive and { ar, ag, ab, 0.95 } or COLORS.BorderSubtle,
                1
            )
            btn.iconTex:SetTexture(icon or 134400)
            local lblTxt = isActive and ("|cFFFFFFFF" .. name .. "|r  |cFF34D399(Active)|r") or ("|cFFCBD5E1" .. name .. "|r")
            btn.text:SetText(lblTxt)
            local tw = (btn.text:GetStringWidth() or 120) + 26
            if tw > maxTextW then maxTextW = tw end

            btn:SetScript("OnEnter", function(selfB)
                SetPixelBackdrop(selfB, COLORS.BgHover, { ar, ag, ab, 0.85 }, 1)
            end)
            btn:SetScript("OnLeave", function(selfB)
                SetPixelBackdrop(
                    selfB,
                    isActive and { ar * 0.34, ag * 0.34, ab * 0.34, 0.98 } or COLORS.BgSurface,
                    isActive and { ar, ag, ab, 0.95 } or COLORS.BorderSubtle,
                    1
                )
            end)
            local targetIdx = i
            btn:SetScript("OnClick", function()
                pop:Hide()
                if InCombatLockdown and InCombatLockdown() then return end
                if targetIdx ~= curSpecIdx then
                    if C_SpecializationInfo and C_SpecializationInfo.SetSpecialization then
                        pcall(C_SpecializationInfo.SetSpecialization, targetIdx)
                    elseif SetSpecialization then
                        pcall(SetSpecialization, targetIdx)
                    end
                end
            end)
            btn:Show()
            yOffset = yOffset - 30
        end
    end

    local catcher = self:EnsurePopoverClickCatcher()
    catcher:Show()

    pop:SetSize(math.max(246, math.ceil(maxTextW) + 34), math.abs(yOffset) + 8)
    pop:ClearAllPoints()
    pop:SetPoint("TOP", anchorBtn, "BOTTOM", 0, -4)
    pop:Show()
end

function DynamicPrep:CycleActiveSpec()
    if InCombatLockdown() then
        print(string.format("|cFF%sDynamicPrep:|r Cannot switch active specialisation while in combat.", GetAccentHex()))
        return
    end
    local numSpecs = SafeGetNumSpecializations()
    if numSpecs <= 1 then return end
    local curIndex = SafeGetSpecialization() or 1
    local nextIndex = (curIndex % numSpecs) + 1
    if C_SpecializationInfo and C_SpecializationInfo.SetSpecialization then
        C_SpecializationInfo.SetSpecialization(nextIndex)
    elseif SetSpecialization then
        SetSpecialization(nextIndex)
    end
end

function DynamicPrep:CycleLootSpec()
    local numSpecs = SafeGetNumSpecializations()
    if numSpecs <= 0 or not SetLootSpecialization then return end
    local currentLoot = GetLootSpecialization() or 0
    if currentLoot == 0 then
        local firstID = SafeGetSpecializationInfo(1)
        if firstID then SetLootSpecialization(firstID) end
        return
    end
    for i = 1, numSpecs do
        local specID = SafeGetSpecializationInfo(i)
        if specID == currentLoot then
            if i < numSpecs then
                local nextID = SafeGetSpecializationInfo(i + 1)
                SetLootSpecialization(nextID or 0)
            else
                SetLootSpecialization(0)
            end
            return
        end
    end
    SetLootSpecialization(0)
end

function DynamicPrep:ResolveOmniumFolioTraitIDs()
    if not (_G.C_Traits and type(_G.C_Traits.GetConfigInfo) == "function") then
        return nil, nil
    end
    local genericType = _G.Enum and _G.Enum.TraitConfigType and _G.Enum.TraitConfigType.Generic
    if genericType and type(_G.C_Traits.GetConfigIDsByType) == "function" then
        local okIds, cfgIds = pcall(_G.C_Traits.GetConfigIDsByType, genericType)
        if okIds and type(cfgIds) == "table" then
            for _, cfgID in ipairs(cfgIds) do
                if type(cfgID) == "number" and cfgID > 0 then
                    local okInfo, info = pcall(_G.C_Traits.GetConfigInfo, cfgID)
                    if okInfo and type(info) == "table" then
                        local rawName = info.name
                        local isSec = (issecretvalue and issecretvalue(rawName)) or false
                        if not isSec and type(rawName) == "string" then
                            local low = string.lower(rawName)
                            if string.find(low, "omnium", 1, true) or string.find(low, "folio", 1, true) then
                                local treeID = (type(info.treeIDs) == "table" and type(info.treeIDs[1]) == "number") and info.treeIDs[1] or nil
                                if type(_G.C_Traits.GetConfigIDBySystemID) == "function" then
                                    local okDef, defCfg = pcall(_G.C_Traits.GetConfigIDBySystemID, 48)
                                    if okDef and defCfg == cfgID then
                                        return 48, treeID
                                    end
                                    for sysID = 1, 80 do
                                        local okSys, sysCfg = pcall(_G.C_Traits.GetConfigIDBySystemID, sysID)
                                        if okSys and sysCfg == cfgID then
                                            return sysID, treeID
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if type(_G.C_Traits.GetConfigIDBySystemID) == "function" then
        local okDef, cfgID = pcall(_G.C_Traits.GetConfigIDBySystemID, 48)
        if okDef and type(cfgID) == "number" and cfgID > 0 then
            local okInfo, info = pcall(_G.C_Traits.GetConfigInfo, cfgID)
            local treeID = (okInfo and type(info) == "table" and type(info.treeIDs) == "table" and type(info.treeIDs[1]) == "number") and info.treeIDs[1] or 1186
            return 48, treeID
        end
    end
    return nil, nil
end

function DynamicPrep:ToggleOmniumFolioFrame()
    if InCombatLockdown and InCombatLockdown() then
        print(string.format("|cFF%sDynamicPrep:|r Cannot open the Omnium Folio while in combat.", GetAccentHex()))
        return false
    end
    if _G.GenericTraitFrame and _G.GenericTraitFrame.IsShown and _G.GenericTraitFrame:IsShown() and self._lastOpenedFolioSystemID then
        if type(_G.HideUIPanel) == "function" then
            pcall(_G.HideUIPanel, _G.GenericTraitFrame)
        else
            pcall(_G.GenericTraitFrame.Hide, _G.GenericTraitFrame)
        end
        return true
    end
    local systemID, treeID = self:ResolveOmniumFolioTraitIDs()
    if systemID then
        if type(_G.GenericTraitUI_LoadUI) == "function" then
            pcall(_G.GenericTraitUI_LoadUI)
        elseif _G.C_AddOns and type(_G.C_AddOns.LoadAddOn) == "function" then
            pcall(_G.C_AddOns.LoadAddOn, "Blizzard_GenericTraitUI")
        end
        if _G.GenericTraitFrame then
            if type(_G.GenericTraitFrame.SetSystemID) == "function" then
                pcall(_G.GenericTraitFrame.SetSystemID, _G.GenericTraitFrame, systemID)
            end
            if treeID and type(_G.GenericTraitFrame.SetTreeID) == "function" then
                pcall(_G.GenericTraitFrame.SetTreeID, _G.GenericTraitFrame, treeID)
            end
            if _G.DynamicSuite and _G.DynamicSuite.DesktopWindows and type(_G.DynamicSuite.DesktopWindows.Init) == "function" then
                pcall(_G.DynamicSuite.DesktopWindows.Init, _G.DynamicSuite.DesktopWindows, "Blizzard_GenericTraitUI")
            end
            if type(_G.ShowUIPanel) == "function" then
                pcall(_G.ShowUIPanel, _G.GenericTraitFrame)
            elseif type(_G.ToggleFrame) == "function" then
                pcall(_G.ToggleFrame, _G.GenericTraitFrame)
            else
                pcall(_G.GenericTraitFrame.Show, _G.GenericTraitFrame)
            end
            self._lastOpenedFolioSystemID = systemID
            return true
        end
    end
    if type(_G.ToggleExpansionLandingPage) == "function" then
        pcall(_G.ToggleExpansionLandingPage)
        return true
    elseif _G.ExpansionLandingPageMinimapButton and type(_G.ExpansionLandingPageMinimapButton.Click) == "function" then
        pcall(_G.ExpansionLandingPageMinimapButton.Click, _G.ExpansionLandingPageMinimapButton)
        return true
    end
    print(string.format("|cFF%sDynamicPrep:|r Omnium Folio is not available on this character right now.", GetAccentHex()))
    return false
end

function DynamicPrep:UpdateFolioSecureButton()
    if InCombatLockdown and InCombatLockdown() then
        self._pendingFolioSecureUpdate = true
        return
    end
    self._pendingFolioSecureUpdate = nil
    local bar = self.prepBarFrame
    local seg = bar and bar.segmentFrames and bar.segmentFrames["folio"]
    if not seg or not seg.secureBtn then return end
    seg.secureBtn:SetAttribute("type1", nil)
    seg.secureBtn:SetAttribute("item1", nil)
    seg.secureBtn:Hide()
end

function DynamicPrep:ApplySuggestedFolioBuff(fromSecureBtn)
    if not self.db then return end
    local zoneKey, zoneTag = self:GetCurrentContentCategory()
    local targetStat = self:GetTargetFolioStatForZone(zoneKey)
    if not targetStat or targetStat == "OFF" then
        targetStat = "HASTE"
    end
    local bag, slot = self:FindOmniFolioItemInBags()
    if fromSecureBtn and bag and slot then
        -- Wait for the item cast's post-cast UNIT_AURA scan (bypassing the 2.0s throttle) rather than reading the stale pre-cast buff
        self._awaitingPostCastFolioScan = true
        self._lastFolioScanTime = nil
        C_Timer.After(0.45, function()
            if self._awaitingPostCastFolioScan then
                self._awaitingPostCastFolioScan = nil
                self._lastFolioScanTime = nil
                local postStat = self:DetectActiveFolioBuffStat(true)
                self.db.activeFolioStat = postStat or targetStat
                self.previewFolioMismatch = false
                self:RefreshBar()
                self:RefreshWorkspaceView()
            end
        end)
    else
        local detectedStat = self:DetectActiveFolioBuffStat(true)
        if detectedStat then
            self.db.activeFolioStat = detectedStat
        else
            self.db.activeFolioStat = targetStat
        end
    end
    self.previewFolioMismatch = false
    self:RefreshBar()
    self:RefreshWorkspaceView()
    if bag and slot then
        print(string.format(
            "|cFF%sDynamicPrep:|r Applied suggested Omni Folio %s buff: |cFF34D399%s|r.",
            GetAccentHex(),
            tostring(zoneTag or "[Outdoor]"),
            STAT_LABELS[targetStat] or targetStat
        ))
    else
        print(string.format(
            "|cFF%sDynamicPrep:|r Target Omni Folio %s stat set to |cFF34D399%s|r (no Omni Folio item found in bags).",
            GetAccentHex(),
            tostring(zoneTag or "[Outdoor]"),
            STAT_LABELS[targetStat] or targetStat
        ))
    end
end

function DynamicPrep:ToggleFolioPopover(anchorBtn)
    GameTooltip:Hide()
    if self.inEditMode then
        self:HideBarPopovers()
        return
    end
    HookPopoverAnchorOnHide(anchorBtn)
    if not self.folioPopover then
        local pop = CreateFrame("Frame", "DynamicPrepFolioPopover", UIParent, "BackdropTemplate")
        pop:SetSize(248, 210)
        pop:SetFrameStrata("TOOLTIP")
        pop:SetFrameLevel(220)
        pop:SetClampedToScreen(true)
        SetPixelBackdrop(pop, { 0.043, 0.051, 0.071, 0.99 }, GetAccentColorTable(1.0), 1)
        local borderOverlay = CreateFrame("Frame", nil, pop, "BackdropTemplate")
        borderOverlay:SetAllPoints(pop)
        borderOverlay:SetFrameStrata("TOOLTIP")
        borderOverlay:SetFrameLevel(230)
        SetPixelBackdrop(borderOverlay, { 0, 0, 0, 0 }, GetAccentColorTable(1.0), 1)
        pop.borderOverlay = borderOverlay
        SafeRegisterUISpecialFrame("DynamicPrepFolioPopover")
        pop:SetScript("OnHide", function()
            if DynamicPrep.popoverClickCatcher and not DynamicPrep:AreAnyBarPopoversShown() then
                DynamicPrep.popoverClickCatcher:Hide()
            end
        end)
        pop:Hide()

        pop.title = CreateText(pop, "OVERLAY", "GameFontHighlightSmall")
        pop.title:SetPoint("TOPLEFT", pop, "TOPLEFT", 10, -8)

        pop.buttons = {}
        self.folioPopover = pop
    end

    local pop = self.folioPopover
    if pop:IsShown() then
        pop:Hide()
        return
    end
    if self.lootPopover then self.lootPopover:Hide() end
    if self.specSwitchPopover then self.specSwitchPopover:Hide() end
    if self.pullTimerPopover then self.pullTimerPopover:Hide() end
    if _G.DynamicTalent and type(_G.DynamicTalent.HideTalentPopover) == "function" then
        pcall(_G.DynamicTalent.HideTalentPopover, _G.DynamicTalent)
    end

    local ar, ag, ab, accentHex = GetActiveAccentRGB()
    SetPixelBackdrop(pop, { 0.043, 0.051, 0.071, 0.99 }, { ar, ag, ab, 1.0 }, 1)
    if pop.borderOverlay then
        SetPixelBackdrop(pop.borderOverlay, { 0, 0, 0, 0 }, { ar, ag, ab, 1.0 }, 1)
    end

    local zoneKey, zoneTag = self:GetCurrentContentCategory()
    local zk = tostring(zoneKey or "outdoor"):lower()
    local lookupKey = (zk == "outdoor" or zk == "city" or zk == "scenario") and "delve" or (zk == "dungeon" and "mplus" or zk)
    local targetStat = self:GetTargetFolioStatForZone(zk)
    pop.title:SetText(string.format("|cFF%sOmni Folio %s Target: %s|r", accentHex, tostring(zoneTag or "[Outdoor]"), STAT_SHORT[targetStat] or targetStat))

    local folioChoices = {
        { key = "CRIT",       label = "Crit (Critical Strike)" },
        { key = "HASTE",      label = "Haste" },
        { key = "MASTERY",    label = "Mastery" },
        { key = "VERS",       label = "Versatility" },
        { key = "OPEN_FOLIO", label = "Open Omnium Folio" },
        { key = "CYCLE",      label = "Cycle Content Zone Preview" },
    }

    local maxTextW = pop.title:GetStringWidth() or 190
    local yOffset = -28
    for idx, item in ipairs(folioChoices) do
        local btn = pop.buttons[idx]
        if not btn then
            btn = CreateFrame("Button", nil, pop, "BackdropTemplate")
            btn:SetHeight(26)
            btn.checkTex = btn:CreateTexture(nil, "OVERLAY")
            btn.checkTex:SetSize(12, 12)
            btn.checkTex:SetPoint("LEFT", btn, "LEFT", 8, 0)
            btn.checkTex:SetTexture(ICON_CHECK)

            btn.text = CreateText(btn, "OVERLAY", "GameFontHighlightSmall")
            btn.text:SetPoint("LEFT", btn, "LEFT", 24, 0)
            btn.text:SetJustifyH("LEFT")
            btn.text:SetWordWrap(false)
            pop.buttons[idx] = btn
        end
        btn:SetPoint("TOPLEFT", pop, "TOPLEFT", 8, yOffset)
        btn:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -8, yOffset)

        local isAction = (item.key == "CYCLE" or item.key == "OPEN_FOLIO")
        local isTarget = (item.key == targetStat)
        local isActive = (self.db.activeFolioStat == item.key)
        local isSelected = isTarget or isActive
        SetPixelBackdrop(
            btn,
            isSelected and COLORS.BgElevated or COLORS.BgSurface,
            isSelected and { ar, ag, ab, 0.90 } or COLORS.BorderSubtle,
            1
        )
        btn.checkTex:SetVertexColor(ar, ag, ab, 1.0)
        btn.checkTex:SetShown(isSelected and not isAction)

        local suffix = isTarget and " |cFFFBBF24(Target)|r" or ""
        if isAction then
            btn.text:SetPoint("LEFT", btn, "LEFT", 10, 0)
            btn.text:SetText(string.format("|cFF%s%s|r", accentHex, item.label))
        else
            btn.text:SetPoint("LEFT", btn, "LEFT", 24, 0)
            btn.text:SetText((isSelected and "|cFFFFFFFF" or "|cFFCBD5E1") .. item.label .. "|r" .. suffix)
        end

        local tw = btn.text:GetStringWidth() or 140
        if tw > maxTextW then maxTextW = tw end

        btn:SetScript("OnEnter", function(selfB)
            SetPixelBackdrop(selfB, COLORS.BgHover, { ar, ag, ab, 0.85 }, 1)
        end)
        btn:SetScript("OnLeave", function(selfB)
            SetPixelBackdrop(
                selfB,
                isSelected and COLORS.BgElevated or COLORS.BgSurface,
                isSelected and { ar, ag, ab, 0.90 } or COLORS.BorderSubtle,
                1
            )
        end)
        btn:SetScript("OnClick", function()
            if item.key == "OPEN_FOLIO" then
                pop:Hide()
                self:ToggleOmniumFolioFrame()
            elseif item.key == "CYCLE" then
                local order = { "outdoor", "mplus", "raid", "delve", "pvp" }
                local cur = tostring(self.previewZoneKey or select(1, self:GetCurrentContentCategory()) or "outdoor"):lower()
                local nextIdx = 1
                for i, k in ipairs(order) do
                    if k == cur then
                        nextIdx = (i % #order) + 1
                        break
                    end
                end
                self.previewZoneKey = order[nextIdx]
                self:RefreshBar()
                pop:Hide()
                self:ToggleFolioPopover(anchorBtn)
            else
                if self.db and self.db.omniFolio then
                    self.db.omniFolio.presetMode = "CUSTOM"
                    self.db.omniFolio[lookupKey] = item.key
                end
                self.db.activeFolioStat = item.key
                self.previewFolioMismatch = false
                pop:Hide()
                self:RefreshBar()
                self:RefreshWorkspaceView()
            end
        end)
        btn:Show()
        yOffset = yOffset - 30
    end
    for idx = #folioChoices + 1, #pop.buttons do
        if pop.buttons[idx] then
            pop.buttons[idx]:Hide()
        end
    end

    local catcher = self:EnsurePopoverClickCatcher()
    catcher:Show()

    pop:SetSize(math.max(248, math.ceil(maxTextW) + 52), math.abs(yOffset) + 10)
    pop:ClearAllPoints()
    pop:SetPoint("TOP", anchorBtn, "BOTTOM", 0, -4)
    pop:Show()
end

function DynamicPrep:IsPullCountdownActive()
    if C_PartyInfo and C_PartyInfo.IsCountdownRunning and C_PartyInfo.IsCountdownRunning() then
        return true
    end
    local now = GetTime and GetTime() or 0
    if self._isCountdownActive and self._countdownEndTime and now < self._countdownEndTime then
        return true
    end
    self._isCountdownActive = false
    return false
end


function DynamicPrep:CancelPullCountdown()
    if C_PartyInfo and C_PartyInfo.CancelCountdown then
        C_PartyInfo.CancelCountdown()
    elseif C_PartyInfo and C_PartyInfo.DoCountdown then
        C_PartyInfo.DoCountdown(0)
    end
    self._isCountdownActive = false
    self._countdownEndTime = nil
end

function DynamicPrep:ExecutePullCountdownToggle()
    if self:IsPullCountdownActive() then
        self:CancelPullCountdown()
        return
    end
    local secs = tonumber(self.db and self.db.pullTimer) or 10
    if C_PartyInfo and C_PartyInfo.DoCountdown then
        C_PartyInfo.DoCountdown(secs)
    end
    self._isCountdownActive = true
    local now = GetTime and GetTime() or 0
    self._countdownEndTime = now + secs
    if C_Timer and C_Timer.After then
        C_Timer.After(secs + 0.25, function()
            local cur = GetTime and GetTime() or 0
            if DynamicPrep._countdownEndTime and cur >= DynamicPrep._countdownEndTime then
                DynamicPrep._isCountdownActive = false
            end
        end)
    end
end

function DynamicPrep:StepPullTimerPreset(delta)
    if not self.db then return end
    local cur = tonumber(self.db.pullTimer) or 10
    local curIdx = 4
    for i, val in ipairs(PULL_TIMER_PRESETS) do
        if val == cur then
            curIdx = i
            break
        end
    end
    local step = (delta and delta > 0) and 1 or -1
    local nextIdx = curIdx + step
    if nextIdx > #PULL_TIMER_PRESETS then
        nextIdx = 1
    elseif nextIdx < 1 then
        nextIdx = #PULL_TIMER_PRESETS
    end
    self.db.pullTimer = PULL_TIMER_PRESETS[nextIdx] or 10
    self:RefreshBar()
    self:RefreshWorkspaceView()
end

function DynamicPrep:TogglePullTimerPopover(anchorBtn)
    GameTooltip:Hide()
    if self.inEditMode then
        self:HideBarPopovers()
        return
    end
    HookPopoverAnchorOnHide(anchorBtn)
    if not self.pullTimerPopover then
        local pop = CreateFrame("Frame", "DynamicPrepPullTimerPopover", UIParent, "BackdropTemplate")
        pop:SetSize(210, 260)
        pop:SetFrameStrata("TOOLTIP")
        pop:SetFrameLevel(220)
        pop:SetClampedToScreen(true)
        SetPixelBackdrop(pop, { 0.043, 0.051, 0.071, 0.99 }, GetAccentColorTable(1.0), 1)
        local borderOverlay = CreateFrame("Frame", nil, pop, "BackdropTemplate")
        borderOverlay:SetAllPoints(pop)
        borderOverlay:SetFrameStrata("TOOLTIP")
        borderOverlay:SetFrameLevel(230)
        SetPixelBackdrop(borderOverlay, { 0, 0, 0, 0 }, GetAccentColorTable(1.0), 1)
        pop.borderOverlay = borderOverlay
        SafeRegisterUISpecialFrame("DynamicPrepPullTimerPopover")
        pop:SetScript("OnHide", function()
            if DynamicPrep.popoverClickCatcher and not DynamicPrep:AreAnyBarPopoversShown() then
                DynamicPrep.popoverClickCatcher:Hide()
            end
        end)
        pop:Hide()

        pop.title = CreateText(pop, "OVERLAY", "GameFontHighlightSmall")
        pop.title:SetPoint("TOPLEFT", pop, "TOPLEFT", 10, -8)

        pop.buttons = {}
        self.pullTimerPopover = pop
    end

    local pop = self.pullTimerPopover
    if pop:IsShown() then
        pop:Hide()
        return
    end
    if self.lootPopover then self.lootPopover:Hide() end
    if self.specSwitchPopover then self.specSwitchPopover:Hide() end
    if self.folioPopover then self.folioPopover:Hide() end
    if _G.DynamicTalent and type(_G.DynamicTalent.HideTalentPopover) == "function" then
        pcall(_G.DynamicTalent.HideTalentPopover, _G.DynamicTalent)
    end

    local ar, ag, ab, accentHex = GetActiveAccentRGB()
    SetPixelBackdrop(pop, { 0.043, 0.051, 0.071, 0.99 }, { ar, ag, ab, 1.0 }, 1)
    if pop.borderOverlay then
        SetPixelBackdrop(pop.borderOverlay, { 0, 0, 0, 0 }, { ar, ag, ab, 1.0 }, 1)
    end
    local currentTimer = tonumber(self.db and self.db.pullTimer) or 10
    pop.title:SetText(string.format("|cFF%sPull Timer Duration (%ds)|r", accentHex, currentTimer))

    local choices = {}
    for _, secs in ipairs(PULL_TIMER_PRESETS) do
        table.insert(choices, { secs = secs, label = string.format("%ds Pull Countdown", secs) })
    end
    table.insert(choices, { secs = 0, label = "Cancel Active Countdown", isCancel = true })

    local maxTextW = SafeGetStringWidth(pop.title, 160)
    local yOffset = -28
    for idx, item in ipairs(choices) do
        local btn = pop.buttons[idx]
        if not btn then
            btn = CreateFrame("Button", nil, pop, "BackdropTemplate")
            btn:SetHeight(26)
            btn.checkTex = btn:CreateTexture(nil, "OVERLAY")
            btn.checkTex:SetSize(12, 12)
            btn.checkTex:SetPoint("LEFT", btn, "LEFT", 8, 0)
            btn.checkTex:SetTexture(ICON_CHECK)

            btn.text = CreateText(btn, "OVERLAY", "GameFontHighlightSmall")
            btn.text:SetPoint("LEFT", btn, "LEFT", 24, 0)
            btn.text:SetJustifyH("LEFT")
            btn.text:SetWordWrap(false)
            pop.buttons[idx] = btn
        end
        btn:SetPoint("TOPLEFT", pop, "TOPLEFT", 8, yOffset)
        btn:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -8, yOffset)

        local isSelected = (not item.isCancel) and (item.secs == currentTimer)
        SetPixelBackdrop(
            btn,
            isSelected and COLORS.BgElevated or COLORS.BgSurface,
            isSelected and { ar, ag, ab, 0.90 } or COLORS.BorderSubtle,
            1
        )
        btn.checkTex:SetVertexColor(ar, ag, ab, 1.0)
        btn.checkTex:SetShown(isSelected)

        if item.isCancel then
            btn.text:SetPoint("LEFT", btn, "LEFT", 10, 0)
            btn.text:SetText("|cFFF87171" .. item.label .. "|r")
        else
            btn.text:SetPoint("LEFT", btn, "LEFT", 24, 0)
            btn.text:SetText((isSelected and "|cFFFFFFFF" or "|cFFCBD5E1") .. item.label .. "|r")
        end

        local tw = SafeGetStringWidth(btn.text, 140)
        if tw > maxTextW then maxTextW = tw end

        btn:SetScript("OnEnter", function(selfB)
            SetPixelBackdrop(selfB, COLORS.BgHover, { ar, ag, ab, 0.85 }, 1)
        end)
        btn:SetScript("OnLeave", function(selfB)
            SetPixelBackdrop(
                selfB,
                isSelected and COLORS.BgElevated or COLORS.BgSurface,
                isSelected and { ar, ag, ab, 0.90 } or COLORS.BorderSubtle,
                1
            )
        end)
        btn:SetScript("OnClick", function()
            if item.isCancel then
                self:CancelPullCountdown()
                pop:Hide()
            else
                if self.db then
                    self.db.pullTimer = item.secs
                end
                pop:Hide()
                self:RefreshBar()
                self:RefreshWorkspaceView()
            end
        end)
        btn:Show()
        yOffset = yOffset - 30
    end

    local catcher = self:EnsurePopoverClickCatcher()
    catcher:Show()

    pop:SetSize(math.max(216, math.ceil(maxTextW) + 48), math.abs(yOffset) + 10)
    pop:ClearAllPoints()
    pop:SetPoint("TOP", anchorBtn, "BOTTOM", 0, -4)
    pop:Show()
end

-- ============================================================================
-- Keystone Chat Link Helper
-- ============================================================================
local function SafeSendPrepChatMessage(msg, chatType)
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(msg, chatType)
    elseif SendChatMessage then
        SendChatMessage(msg, chatType)
    end
end

local function IsInEncounterOrChatLockdown()
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        return true
    end
    if IsEncounterInProgress and IsEncounterInProgress() then
        return true
    end
    return false
end


function DynamicPrep:LinkKeystoneToPartyChat()
    local _, level, mapName = self:GetKeystoneData()
    local link = nil
    if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemLink then
        for bag = 0, 4 do
            local numSlots = C_Container.GetContainerNumSlots(bag) or 0
            for slot = 1, numSlots do
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink and not _IsSecret(itemLink) and type(itemLink) == "string" and (itemLink:find("|Hkeystone:") or itemLink:find("Keystone")) then
                    link = itemLink
                    break
                end
            end
            if link then break end
        end
    end

    local msg = link or ((level and level > 0 and mapName) and string.format("[DynamicPrep] Mythic+ Keystone: +%d %s", level, mapName) or nil)
    if not msg then
        print(string.format("|cFF%sDynamicPrep:|r You do not currently own a Mythic+ Keystone.", GetAccentHex()))
        return
    end

    if IsInEncounterOrChatLockdown() then
        print(string.format("|cFF%sDynamicPrep Keystone (Encounter Lockdown):|r %s", GetAccentHex(), msg))
        return
    end

    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        SafeSendPrepChatMessage(msg, "INSTANCE_CHAT")
    elseif IsInRaid() then
        SafeSendPrepChatMessage(msg, "RAID")
    elseif IsInGroup() then
        SafeSendPrepChatMessage(msg, "PARTY")
    else
        print(string.format("|cFF%sDynamicPrep Keystone:|r %s", GetAccentHex(), msg))
    end
end

-- ============================================================================
-- Top-of-Screen Permanent Info Bar (DynamicPrepBarFrame - Priority Telemetry)
-- ============================================================================
local function ApplyDefaultCapsuleStyle(seg)
    if not seg then return end
    if (seg.segKey == "folio" or seg.segKey == "talents") and seg.isFolioMismatch then
        SetPixelBackdrop(seg, { 0.984, 0.749, 0.141, 0.14 }, COLORS.Gold, 1)
    else
        SetPixelBackdrop(seg, COLORS.CapsuleBg, COLORS.CapsuleBorder, 1)
    end
end

function DynamicPrep:ApplyBarBorderStyle(targetBar)
    local bar = targetBar or self.prepBarFrame
    if not bar then return end
    local borderMode = (self.db and self.db.hudBorderStyle) or "ACCENT"
    local ar, ag, ab = GetActiveAccentRGB()
    if (self.db and self.db.barColorTheme) == "CLASS_ACCENT" then
        ar, ag, ab = GetPlayerClassColor()
    end

    if borderMode == "ACCENT" then
        SetPixelBackdrop(bar, COLORS.BgBarSurface, { ar, ag, ab, 0.72 }, 1)
        if bar.topAccent then
            bar.topAccent:SetColorTexture(ar, ag, ab, 0.85)
            bar.topAccent:Show()
        end
    elseif borderMode == "DARK" then
        SetPixelBackdrop(bar, COLORS.BgBarSurface, { 1.0, 1.0, 1.0, 0.12 }, 1)
        if bar.topAccent then
            bar.topAccent:Hide()
        end
    else -- "NONE" (Borderless)
        SetPixelBackdrop(bar, COLORS.BgBarSurface, { 0, 0, 0, 0 }, 1)
        if bar.topAccent then
            bar.topAccent:Hide()
        end
    end
end

function DynamicPrep:CreatePrepBar()
    if self.prepBarFrame then return self.prepBarFrame end

    local bar = CreateFrame("Frame", "DynamicPrepBarFrame", UIParent, "BackdropTemplate")
    bar:SetSize(740, 30)
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:HookScript("OnHide", function()
        DynamicPrep:HideBarPopovers()
    end)

    -- Top Suite/Class Accent hairline
    local topAccent = bar:CreateTexture(nil, "OVERLAY")
    topAccent:SetHeight(1)
    topAccent:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    topAccent:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -1, -1)
    bar.topAccent = topAccent

    self:ApplyBarBorderStyle(bar)

    bar.segmentFrames = {}

    local function CreateSegmentFrame(segKey)
        local seg = CreateFrame("Button", nil, bar, "BackdropTemplate")
        seg.segKey = segKey
        seg:SetHeight(22)
        seg:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        seg.lootPopover = self.lootPopover
        seg.folioPopover = self.folioPopover
        seg.pullTimerPopover = self.pullTimerPopover
        SetPixelBackdrop(seg, COLORS.CapsuleBg, COLORS.CapsuleBorder, 1)

        seg.text = CreateText(seg, "OVERLAY", "GameFontHighlightSmall")
        seg.text:SetPoint("CENTER", seg, "CENTER", 0, 0)
        seg.text:SetWordWrap(false)

        seg.divider = seg:CreateTexture(nil, "OVERLAY")
        seg.divider:SetWidth(1)
        seg.divider:SetPoint("TOPRIGHT", seg, "TOPRIGHT", 0, -4)
        seg.divider:SetPoint("BOTTOMRIGHT", seg, "BOTTOMRIGHT", 0, 4)
        seg.divider:SetColorTexture(1, 1, 1, 0.0)
        seg.divider:Hide()

        if segKey == "pull" then
            seg:EnableMouseWheel(true)
            seg:SetScript("OnMouseWheel", function(selfSeg, delta)
                if DynamicPrep.inEditMode then return end
                DynamicPrep:StepPullTimerPreset(delta)
                if GameTooltip and GameTooltip:IsOwned(selfSeg) then
                    GameTooltip:SetOwner(selfSeg, "ANCHOR_BOTTOM")
                    DynamicPrep:PopulateSegmentTooltip("pull", GameTooltip)
                    GameTooltip:Show()
                end
            end)
        end

        seg:SetScript("OnEnter", function(selfSeg)
            if DynamicPrep.inEditMode then return end
            selfSeg.lootPopover = DynamicPrep.lootPopover
            selfSeg.folioPopover = DynamicPrep.folioPopover
            selfSeg.pullTimerPopover = DynamicPrep.pullTimerPopover
            if DynamicPrep:AreAnyBarPopoversShown() then
                return
            end
            local ar, ag, ab = GetActiveAccentRGB()
            SetPixelBackdrop(selfSeg, { ar, ag, ab, 0.15 }, { ar, ag, ab, 0.90 }, 1)
            GameTooltip:SetOwner(selfSeg, "ANCHOR_BOTTOM")
            DynamicPrep:PopulateSegmentTooltip(segKey, GameTooltip)
            GameTooltip:Show()
        end)
        seg:SetScript("OnLeave", function(selfSeg)
            GameTooltip:Hide()
            ApplyDefaultCapsuleStyle(selfSeg)
        end)
        seg:SetScript("OnMouseDown", function()
            GameTooltip:Hide()
        end)

        seg:SetScript("OnClick", function(selfSeg, button)
            GameTooltip:Hide()
            if DynamicPrep.inEditMode then
                DynamicPrep:HideBarPopovers()
                return
            end
            if segKey == "loot" then
                if button == "RightButton" then
                    DynamicPrep:ToggleLootSpecPopover(selfSeg)
                else
                    DynamicPrep:ToggleActiveSpecPopover(selfSeg)
                end
            elseif segKey == "talents" then
                local dt = _G.DynamicTalent
                if dt and type(dt.HandlePrepBarClick) == "function" then
                    pcall(dt.HandlePrepBarClick, dt, selfSeg, button)
                else
                    DynamicPrep:HideBarPopovers()
                    if _G.DynamicSuite and type(_G.DynamicSuite.OpenModule) == "function" then
                        _G.DynamicSuite:OpenModule("talent")
                    end
                end
            elseif segKey == "vault" then
                DynamicPrep:HideBarPopovers()
                if button == "RightButton" then
                    if _G.DynamicVault and type(_G.DynamicVault.OpenBlizzardVault) == "function" then
                        pcall(_G.DynamicVault.OpenBlizzardVault, _G.DynamicVault)
                    end
                else
                    if _G.DynamicVault and type(_G.DynamicVault.Open) == "function" then
                        pcall(_G.DynamicVault.Open, _G.DynamicVault)
                    elseif _G.DynamicSuite and type(_G.DynamicSuite.OpenModule) == "function" then
                        _G.DynamicSuite:OpenModule("vault")
                    end
                end
            elseif segKey == "folio" then
                if button == "RightButton" then
                    DynamicPrep:HideBarPopovers()
                    DynamicPrep:ToggleOmniumFolioFrame()
                else
                    DynamicPrep:ToggleFolioPopover(selfSeg)
                end
            elseif segKey == "key" then
                DynamicPrep:HideBarPopovers()
                if button == "RightButton" then
                    if InCombatLockdown and InCombatLockdown() then
                        print(string.format("|cFF%sDynamicPrep:|r Cannot toggle Group Finder while in combat.", GetAccentHex()))
                    elseif type(PVEFrame_ToggleFrame) == "function" then
                        pcall(PVEFrame_ToggleFrame, "GroupFinderFrame", LFDParentFrame)
                    elseif type(ToggleLFDParentFrame) == "function" then
                        pcall(ToggleLFDParentFrame)
                    end
                else
                    DynamicPrep:LinkKeystoneToPartyChat()
                end
            elseif segKey == "rc" then
                DynamicPrep:HideBarPopovers()
                if DoReadyCheck then DoReadyCheck() end
            elseif segKey == "pull" then
                if button == "RightButton" then
                    DynamicPrep:TogglePullTimerPopover(selfSeg)
                else
                    DynamicPrep:HideBarPopovers()
                    DynamicPrep:ExecutePullCountdownToggle()
                end
            elseif segKey == "fps" or segKey == "fps_ms" then
                DynamicPrep:HideBarPopovers()
                if _G.DynamicSuite and _G.DynamicSuite.OpenModule then
                    _G.DynamicSuite:OpenModule("DynamicFPS")
                elseif _G.DynamicSuite and _G.DynamicSuite.SelectModule then
                    DynamicPrep:EnsureSuiteWindowShell()
                    _G.DynamicSuite:SelectModule("fps")
                elseif SlashCmdList and SlashCmdList["DYNAMICFPS"] then
                    SlashCmdList["DYNAMICFPS"]("")
                end
            elseif segKey == "ping" then
                DynamicPrep:HideBarPopovers()
                if DynamicPrep.db then
                    if button == "RightButton" then
                        DynamicPrep.db.pingOrder = (DynamicPrep.db.pingOrder == "WORLD_FIRST") and "LOCAL_FIRST" or "WORLD_FIRST"
                    else
                        local curMode = DynamicPrep.db.pingDisplayMode or "BOTH"
                        if curMode == "BOTH" then
                            DynamicPrep.db.pingDisplayMode = "LOCAL_ONLY"
                        elseif curMode == "LOCAL_ONLY" then
                            DynamicPrep.db.pingDisplayMode = "WORLD_ONLY"
                        else
                            DynamicPrep.db.pingDisplayMode = "BOTH"
                        end
                    end
                    DynamicPrep:RefreshBar()
                    DynamicPrep:RefreshWorkspaceView()
                end
            elseif segKey == "primary" or segKey == "stats" or segKey == "weights" then
                DynamicPrep:OpenWorkspace(1)
            elseif segKey == "dur" then
                DynamicPrep:HideBarPopovers()
                if InCombatLockdown and InCombatLockdown() then
                    print(string.format("|cFF%sDynamicPrep:|r Cannot open Character Frame while in combat.", GetAccentHex()))
                elseif type(ToggleCharacter) == "function" then
                    pcall(ToggleCharacter, "PaperDollFrame")
                end
            elseif segKey == "bags" then
                DynamicPrep:OpenWorkspace(2)
            end
        end)

        if segKey == "folio" then
            local secBtn = CreateFrame("Button", "DynamicPrepFolioSecureBtn", seg, "SecureActionButtonTemplate")
            secBtn:SetAllPoints(seg)
            secBtn:RegisterForClicks("AnyUp", "AnyDown")
            secBtn:SetScript("OnEnter", function()
                local onEnter = seg:GetScript("OnEnter")
                if onEnter then onEnter(seg) end
            end)
            secBtn:SetScript("OnLeave", function()
                local onLeave = seg:GetScript("OnLeave")
                if onLeave then onLeave(seg) end
            end)
            secBtn:SetScript("PostClick", function(_, button, down)
                GameTooltip:Hide()
                if DynamicPrep.inEditMode then
                    if not down then
                        DynamicPrep:HideBarPopovers()
                    end
                    return
                end
                if button == "RightButton" then
                    if not down then
                        DynamicPrep:ToggleFolioPopover(seg)
                    end
                else
                    local useKeyDown = false
                    if C_CVar and C_CVar.GetCVarBool then
                        local ok, res = pcall(C_CVar.GetCVarBool, "ActionButtonUseKeyDown")
                        if ok then useKeyDown = (res == true) end
                    end
                    if (down and true or false) ~= useKeyDown then
                        return
                    end
                    DynamicPrep:HideBarPopovers()
                    DynamicPrep:ApplySuggestedFolioBuff(true)
                end
            end)
            secBtn:Hide()
            seg.secureBtn = secBtn
        end

        bar.segmentFrames[segKey] = seg
    end

    for _, segKey in ipairs(DEFAULT_SEGMENT_ORDER) do
        CreateSegmentFrame(segKey)
    end

    -- Edit Mode Full-Bar Drag Shield Overlay (no protruding top handle bar; dims bar + shows live X/Y)
    local mover = CreateFrame("Button", nil, bar, "BackdropTemplate")
    mover:SetAllPoints(bar)
    mover:SetFrameLevel(bar:GetFrameLevel() + 30)
    if mover.SetIgnoreParentAlpha then mover:SetIgnoreParentAlpha(true) end
    local ar, ag, ab, accentHex = GetActiveAccentRGB()
    SetPixelBackdrop(mover, { 0.05, 0.06, 0.09, 0.84 }, { ar, ag, ab, 1.0 }, 1)
    mover.dimBg = mover:CreateTexture(nil, "BACKGROUND")
    mover.dimBg:SetAllPoints(mover)
    mover.dimBg:SetColorTexture(0.05, 0.06, 0.09, 0.84)
    mover.label = CreateText(mover, "OVERLAY", "GameFontHighlightSmall")
    mover.label:SetPoint("CENTER")
    local _, _, initX, initY = self:GetSavedBarPosition()
    mover.label:SetText(string.format("|cFF%sDynamicPrep Bar|r  |cFFFFFFFF(X: %d, Y: %d)|r", accentHex, math.floor((initX or 0) + 0.5), math.floor((initY or -8) + 0.5)))
    mover:EnableMouse(true)
    mover:RegisterForClicks("AnyUp", "AnyDown")
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnClick", function()
        GameTooltip:Hide()
        DynamicPrep:HideBarPopovers()
    end)
    mover:SetScript("OnDragStart", function(selfMover)
        if InCombatLockdown and InCombatLockdown() then return end
        GameTooltip:Hide()
        DynamicPrep:HideBarPopovers()
        bar:StartMoving()
        selfMover:SetScript("OnUpdate", function()
            if InCombatLockdown and InCombatLockdown() then
                selfMover:SetScript("OnUpdate", nil)
                bar:StopMovingOrSizing()
                return
            end
            local _, _, _, cx, cy = bar:GetPoint(1)
            local _, _, _, hex = GetActiveAccentRGB()
            selfMover.label:SetText(string.format("|cFF%sDynamicPrep Bar|r  |cFFFFFFFF(X: %d, Y: %d)|r", hex, math.floor((cx or 0) + 0.5), math.floor((cy or 0) + 0.5)))
        end)
    end)
    mover:SetScript("OnDragStop", function(selfMover)
        selfMover:SetScript("OnUpdate", nil)
        if InCombatLockdown and InCombatLockdown() then
            DynamicPrep.pendingBarRefreshAfterCombat = true
            return
        end
        bar:StopMovingOrSizing()
        local point, _, relativePoint, x, y = bar:GetPoint(1)
        local usePt = point or "TOP"
        local useRp = relativePoint or usePt
        local px = x or 0
        local py = y or -8
        if not IsShiftKeyDown() and not IsControlKeyDown() then
            px = math.floor((px / 8) + 0.5) * 8
            py = math.floor((py / 8) + 0.5) * 8
        end
        px, py = ClampPrepFrameToScreen(bar, usePt, useRp, px, py, 320, 32)
        bar:ClearAllPoints()
        bar:SetPoint(usePt, UIParent, useRp, px, py)
        bar:SaveEditPosition(usePt, useRp, px, py)
        local _, _, _, hex = GetActiveAccentRGB()
        selfMover.label:SetText(string.format("|cFF%sDynamicPrep Bar|r  |cFFFFFFFF(X: %d, Y: %d)|r", hex, math.floor((px or 0) + 0.5), math.floor((py or -8) + 0.5)))
    end)
    mover:Hide()
    bar.mover = mover
    bar.editDragShield = mover

    function bar:SaveEditPosition(point, relPoint, x, y)
        DynamicPrep:SaveBarEditPosition(point, relPoint, x, y)
    end

    function bar:SetEditMode(state)
        DynamicPrep:SetBarEditMode(state)
    end

    self.prepBarFrame = bar
    _G.DynamicPrepBarFrame = bar
    self:ApplyBarGeometry()
    self:EnsureFpsLatencyTicker()
    return bar
end

DynamicPrep.InitOmniBar = DynamicPrep.CreatePrepBar
DynamicPrep.InitBar = DynamicPrep.CreatePrepBar

function DynamicPrep:EnsureMeasureFontString()
    if not self._fpsMeasureFS and self.prepBarFrame then
        local mfs = CreateText(self.prepBarFrame, "OVERLAY", "GameFontHighlightSmall")
        mfs:Hide()
        self._fpsMeasureFS = mfs
    end
    return self._fpsMeasureFS
end

function DynamicPrep:GetFixedFpsCapsuleWidth()
    local mfs = self:EnsureMeasureFontString()
    if mfs then
        mfs:SetText("888 FPS")
        local refW = SafeGetStringWidth(mfs, 48)
        return math.max(66, math.ceil(refW + 18))
    end
    return 68
end

function DynamicPrep:GetFixedPingCapsuleWidth()
    local mfs = self:EnsureMeasureFontString()
    local mode = (self.db and self.db.pingDisplayMode) or "BOTH"
    if mfs then
        if mode == "LOCAL_ONLY" or mode == "WORLD_ONLY" then
            mfs:SetText("888 ms (World)")
            local refW = SafeGetStringWidth(mfs, 84)
            return math.max(98, math.ceil(refW + 18))
        else
            mfs:SetText("888/888 ms")
            local refW = SafeGetStringWidth(mfs, 66)
            return math.max(82, math.ceil(refW + 18))
        end
    end
    return (mode == "LOCAL_ONLY" or mode == "WORLD_ONLY") and 102 or 86
end

function DynamicPrep:GetFixedRcCapsuleWidth()
    local mfs = self:EnsureMeasureFontString()
    if mfs then
        mfs:SetText("+ RC")
        local refW = SafeGetStringWidth(mfs, 30)
        return math.max(48, math.ceil(refW + 16))
    end
    return 48
end

function DynamicPrep:GetFixedPullCapsuleWidth()
    local mfs = self:EnsureMeasureFontString()
    if mfs then
        mfs:SetText("> Pull 20")
        local refW = SafeGetStringWidth(mfs, 50)
        return math.max(68, math.ceil(refW + 18))
    end
    return 68
end

function DynamicPrep:ResetStableCapsuleWidths()
    if self.prepBarFrame and self.prepBarFrame.segmentFrames then
        for _, seg in pairs(self.prepBarFrame.segmentFrames) do
            seg._stableWidth = nil
        end
    end
    if self.workspaceFrame and self.workspaceFrame.previewBar and self.workspaceFrame.previewBar.capsules then
        for _, cap in pairs(self.workspaceFrame.previewBar.capsules) do
            cap._stableWidth = nil
        end
    end
end

function DynamicPrep:UpdateFpsLatencyOnly()
    if not self.db then return end
    self._lastFpsSampleTime = nil
    local fpsStr = self:GetFPSData()
    local pingStr = self:GetPingData()
    local bar = self.prepBarFrame
    if bar and bar:IsShown() and self.db.segments then
        if self.db.segments.fps then
            local segFps = bar.segmentFrames and bar.segmentFrames["fps"]
            if segFps and segFps:IsShown() and segFps.text then
                segFps.text:SetText(fpsStr or "")
            end
        end
        if self.db.segments.ping then
            local segPing = bar.segmentFrames and bar.segmentFrames["ping"]
            if segPing and segPing:IsShown() and segPing.text then
                segPing.text:SetText(pingStr or "")
            end
        end
    end
    local ws = self.workspaceFrame
    if ws and ws:IsShown() then
        self:UpdateSuiteHeaderStatus()
        if ws.previewBar and ws.previewBar.capsules then
            local capFps = ws.previewBar.capsules["fps"]
            if capFps and capFps:IsShown() and capFps.text then
                capFps.text:SetText(fpsStr or "")
            end
            local capPing = ws.previewBar.capsules["ping"]
            if capPing and capPing:IsShown() and capPing.text then
                capPing.text:SetText(pingStr or "")
            end
        end
    end
end

function DynamicPrep:EnsureFpsLatencyTicker()
    if self._fpsLatencyTicker or not (C_Timer and C_Timer.NewTicker) then return end
    self._fpsLatencyTicker = C_Timer.NewTicker(1.0, function()
        self:UpdateFpsLatencyOnly()
    end)
end

local function SafeIsPlayerSpellKnown(spellID)
    if not spellID then return false end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        local ok, res = pcall(C_SpellBook.IsSpellKnown, spellID, bank)
        if ok and res then return true end
    end
    if C_SpellBook and C_SpellBook.IsSpellInSpellBook and C_SpellBook.IsSpellInSpellBook(spellID) then
        return true
    end
    if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
    if IsSpellKnown and IsSpellKnown(spellID) then return true end
    if IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(spellID) then return true end
    return false
end


local SYMBIOTIC_SPELL_IDS = {
    [474750] = true, -- Symbiotic Relationship (Cast / Base Spell ID)
    [474754] = true, -- Symbiotic Relationship (Target Bond Aura ID)
    [474751] = true,
    [474752] = true,
    [474753] = true, -- Symbiotic Relationship (Caster Self-Bond Aura ID)
    [474756] = true,
    [474760] = true,
}

local CLASS_RAID_BUFFS = {
    DRUID = {
        spellID = 1126,
        name = "Mark of the Wild",
        shortLabel = "MotW",
        icon = 136078,
        isGroup = true,
        auraNames = { ["Mark of the Wild"] = true },
        auraIDs = { [1126] = true, [432661] = true },
    },
    PRIEST = {
        spellID = 21562,
        name = "Power Word: Fortitude",
        shortLabel = "Fort",
        icon = 135987,
        isGroup = true,
        auraNames = { ["Power Word: Fortitude"] = true },
        auraIDs = { [21562] = true },
    },
    MAGE = {
        spellID = 1459,
        name = "Arcane Intellect",
        shortLabel = "Int",
        icon = 135932,
        isGroup = true,
        auraNames = { ["Arcane Intellect"] = true, ["Dalaran Brilliance"] = true },
        auraIDs = { [1459] = true, [432778] = true },
    },
    WARRIOR = {
        spellID = 6673,
        name = "Battle Shout",
        shortLabel = "Shout",
        icon = 132333,
        isGroup = true,
        auraNames = { ["Battle Shout"] = true },
        auraIDs = { [6673] = true },
    },
    EVOKER = {
        spellID = 364342,
        altSpellID = 381748,
        name = "Blessing of the Bronze",
        shortLabel = "Bronze",
        icon = 4622448,
        isGroup = true,
        auraNames = { ["Blessing of the Bronze"] = true },
        auraIDs = {
            [364342] = true,
            [381732] = true,
            [381741] = true,
            [381746] = true,
            [381748] = true,
            [381749] = true,
            [381750] = true,
            [381751] = true,
            [381752] = true,
            [381753] = true,
            [381754] = true,
            [381756] = true,
            [381757] = true,
            [381758] = true,
        },
    },
    SHAMAN = {
        spellID = 462854,
        name = "Skyfury",
        shortLabel = "Skyfury",
        icon = 136088,
        isGroup = true,
        auraNames = { ["Skyfury"] = true },
        auraIDs = { [462854] = true, [462856] = true },
    },
}

local function IsClassRaidBuffKnown(cDef)
    if not cDef then return false end
    if cDef.spellID and SafeIsPlayerSpellKnown(cDef.spellID) then return true end
    if cDef.altSpellID and SafeIsPlayerSpellKnown(cDef.altSpellID) then return true end
    if not IsSpellKnown and not (C_SpellBook and C_SpellBook.IsSpellKnown) then return true end
    return false
end


local PARTNER_RAID_BUFFS = {
    DRUID = {
        {
            spellID = 474750,
            name = "Symbiotic Relationship",
            icon = 136063,
            targetRole = "TANK_OR_HEALER",
            requiresGroup = true,
            checkSelfAuraToo = true,
            auraNames = { ["Symbiotic Relationship"] = true },
            auraIDs = SYMBIOTIC_SPELL_IDS,
        },
    },
    EVOKER = {
        {
            spellID = 369459,
            name = "Source of Magic",
            icon = 4622476,
            targetRole = "HEALER",
            requiresGroup = true,
            auraNames = { ["Source of Magic"] = true },
            auraIDs = { [369459] = true },
        },
        {
            spellID = 360827,
            name = "Blistering Scales",
            icon = 4622451,
            targetRole = "TANK",
            requiresGroup = false,
            auraNames = { ["Blistering Scales"] = true },
            auraIDs = { [360827] = true },
        },
    },
    SHAMAN = {
        {
            spellID = 974,
            name = "Earth Shield",
            icon = 136089,
            targetRole = "TANK",
            requiresGroup = true,
            auraNames = { ["Earth Shield"] = true },
            auraIDs = { [974] = true, [383648] = true },
        },
    },
    PALADIN = {
        {
            spellID = 53563,
            name = "Beacon of Light",
            icon = 236247,
            targetRole = "TANK",
            requiresGroup = true,
            excludeIfTalentKnown = 200025, -- Beacon of Virtue
            auraNames = { ["Beacon of Light"] = true },
            auraIDs = { [53563] = true },
        },
        {
            spellID = 156910,
            name = "Beacon of Faith",
            icon = 1030095,
            targetRole = "OFF_TANK",
            requiresGroup = true,
            auraNames = { ["Beacon of Faith"] = true },
            auraIDs = { [156910] = true },
        },
    },
}

function DynamicPrep:PopulateSegmentTooltip(segKey, tooltip)
    local ar, ag, ab = GetActiveAccentRGB()
    local function SafeNumStr(v)
        if IsSecretValue(v) then return tostring(v or 0) end
        local ok, s = pcall(function() return BreakUpLargeNumbers and BreakUpLargeNumbers(v) or tostring(v) end)
        return (ok and s) or tostring(v or 0)
    end
    local function SafePctStr(v)
        if IsSecretValue(v) then return tostring(v or 0) .. "%" end
        local ok, s = pcall(function() return string.format("%.2f%%", v) end)
        return (ok and s) or (tostring(v or 0) .. "%")
    end
    if segKey == "primary" then
        local _, statLabel, effective, baseline, isProc = self:GetPrimaryStatData()
        tooltip:AddLine("Primary Stat (" .. statLabel .. ")", ar, ag, ab)
        tooltip:AddDoubleLine("Current Value:", SafeNumStr(effective), 0.8, 0.84, 0.88, 0.176, 0.831, 0.749)
        tooltip:AddDoubleLine("Resting Baseline:", SafeNumStr(baseline), 0.8, 0.84, 0.88, 0.7, 0.75, 0.8)
        if isProc then
            tooltip:AddLine("* Combat Proc Active: Above Resting Baseline!", 0.176, 0.831, 0.749)
        end
        if self.GetActiveFoodBuffBenefit then
            local hasFood, foodShort, foodFullLine = self:GetActiveFoodBuffBenefit()
            tooltip:AddLine(" ")
            if hasFood and foodShort then
                tooltip:AddDoubleLine("Food Buff:", DynamicPrep:FormatColoredFoodBenefit(foodShort), 0.8, 0.84, 0.88, 0.204, 0.827, 0.600)
                if foodFullLine and foodFullLine ~= "" then
                    tooltip:AddLine(foodFullLine, 0.68, 0.74, 0.82, true)
                end
            else
                tooltip:AddDoubleLine("Food Buff:", "Missing", 0.8, 0.84, 0.88, 0.973, 0.443, 0.443)
            end
        end
        if SafeIsPlayerSpellKnown(474750) and self.ValidateAndScanSymbioticBond then
            local isBonded, _, bondedColored = self:ValidateAndScanSymbioticBond(300)
            if isBonded and bondedColored then
                tooltip:AddDoubleLine("Symbiotic Relationship:", "Linked: " .. bondedColored, 0.8, 0.84, 0.88, 0.204, 0.827, 0.600)
            else
                tooltip:AddDoubleLine("Symbiotic Relationship:", "Missing", 0.8, 0.84, 0.88, 0.973, 0.443, 0.443)
            end
        end
    elseif segKey == "stats" or segKey == "weights" then
        local _, crit, haste, mast, vers = self:GetSecondaryStatsData()
        tooltip:AddLine(segKey == "weights" and "Recommended Stat Priority" or "Secondary Stats & Recommended Stat Priority", ar, ag, ab)
        tooltip:AddDoubleLine("Critical Strike:", SafePctStr(crit), 0.8, 0.84, 0.88, 1, 1, 1)
        tooltip:AddDoubleLine("Haste:", SafePctStr(haste), 0.8, 0.84, 0.88, 1, 1, 1)
        tooltip:AddDoubleLine("Mastery:", SafePctStr(mast), 0.8, 0.84, 0.88, 1, 1, 1)
        tooltip:AddDoubleLine("Versatility:", SafePctStr(vers), 0.8, 0.84, 0.88, 1, 1, 1)
        if self.GetActiveFoodBuffBenefit then
            local hasFood, foodShort, foodFullLine = self:GetActiveFoodBuffBenefit()
            if hasFood and foodShort then
                tooltip:AddDoubleLine("Active Food Buff:", DynamicPrep:FormatColoredFoodBenefit(foodShort), 0.8, 0.84, 0.88, 0.204, 0.827, 0.600)
                if foodFullLine and foodFullLine ~= "" then
                    tooltip:AddLine(foodFullLine, 0.68, 0.74, 0.82, true)
                end
            end
        end
        tooltip:AddLine(" ")
        tooltip:AddLine("Recommended Stat Priority:", ar, ag, ab)
        tooltip:AddLine(self:GetStatWeightsText(), 1, 1, 1)
    elseif segKey == "loot" then
        local _, activeSpec, lootSpec, isOffSpec = self:GetSpecAndLootData()
        tooltip:AddLine("Specialisation & Loot Target", ar, ag, ab)
        tooltip:AddDoubleLine("Active Specialisation:", activeSpec, 0.8, 0.84, 0.88, 1, 1, 1)
        tooltip:AddDoubleLine("Loot Specialisation:", isOffSpec and (lootSpec .. " (Off-Spec)") or ("Auto (" .. activeSpec .. ")"), 0.8, 0.84, 0.88, isOffSpec and 0.984 or 0.204, isOffSpec and 0.749 or 0.827, isOffSpec and 0.141 or 0.600)
        tooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Open Active Specialisation Selector (Out of Combat)|r", 1, 1, 1)
        tooltip:AddLine(string.format("|cFF%sRight-Click:|r |cFFE2E8F0Open Loot Specialisation Selector|r", GetAccentHex()), 1, 1, 1)
    elseif segKey == "talents" then
        if _G.DynamicTalent and type(_G.DynamicTalent.PopulatePrepBarTooltip) == "function" then
            pcall(_G.DynamicTalent.PopulatePrepBarTooltip, _G.DynamicTalent, tooltip)
        else
            tooltip:AddLine("Talent Loadout Quick-Switcher", ar, ag, ab)
            tooltip:AddLine("|cFF94A3B8DynamicTalent module is currently disabled or unloaded.|r", 1, 1, 1)
        end
    elseif segKey == "vault" then
        if _G.DynamicVault and type(_G.DynamicVault.PopulatePrepBarTooltip) == "function" then
            pcall(_G.DynamicVault.PopulatePrepBarTooltip, _G.DynamicVault, tooltip)
        else
            tooltip:AddLine("Great Vault Summary", ar, ag, ab)
            tooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Open DynamicVault (/dv)|r", 1, 1, 1)
            tooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Open Blizzard Great Vault|r", 1, 1, 1)
        end
    elseif segKey == "folio" then
        local _, isMismatch, targetStat, activeStat, zoneTag = self:GetOmniFolioData()
        local targetLabel = STAT_LABELS[targetStat] or targetStat or "Haste"
        tooltip:AddLine("Midnight Omnium Folio " .. tostring(zoneTag or "[Outdoor]"), 0.984, 0.749, 0.141)
        tooltip:AddDoubleLine("Zone Target Stat:", targetLabel, 0.8, 0.84, 0.88, 1, 1, 1)
        tooltip:AddDoubleLine("Active Folio Buff:", activeStat and (STAT_LABELS[activeStat] or self._cachedFolioBuffName or activeStat) or "None Detected", 0.8, 0.84, 0.88, isMismatch and 0.984 or 0.204, isMismatch and 0.749 or 0.827, isMismatch and 0.141 or 0.600)
        local moteCount = self.ScanOmnialInquiryMotes and self:ScanOmnialInquiryMotes() or 0
        if moteCount > 0 then
            tooltip:AddDoubleLine("Motes of Omnial Inquiry:", tostring(moteCount) .. " in bags", 0.8, 0.84, 0.88, 0.220, 0.741, 0.973)
        end
        if self.GetActiveFoodBuffBenefit then
            local hasFood, foodShort, foodFullLine = self:GetActiveFoodBuffBenefit()
            tooltip:AddDoubleLine("Active Food Buff:", (hasFood and DynamicPrep:FormatColoredFoodBenefit(foodShort)) or "Missing", 0.8, 0.84, 0.88, hasFood and 0.204 or 0.973, hasFood and 0.827 or 0.443, hasFood and 0.600 or 0.443)
            if hasFood and foodFullLine and foodFullLine ~= "" then
                tooltip:AddLine(foodFullLine, 0.68, 0.74, 0.82, true)
            end
        end
        tooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Choose Zone Target Stat|r", 1, 1, 1)
        tooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Open Omnium Folio|r", 1, 1, 1)
    elseif segKey == "dur" then
        local _, lowest, avg = self:GetDurabilityData()
        tooltip:AddLine("Equipment Durability", ar, ag, ab)
        tooltip:AddDoubleLine("Lowest Slot:", lowest .. "%", 0.8, 0.84, 0.88, lowest < 30 and 0.97 or 1, lowest < 30 and 0.44 or 1, lowest < 30 and 0.44 or 1)
        tooltip:AddDoubleLine("Average Gear:", avg .. "%", 0.8, 0.84, 0.88, 1, 1, 1)
        local audit = self._gearAuditCache
        if audit then
            local missing = audit.missingEnchants or {}
            if #missing == 0 then
                tooltip:AddDoubleLine("Enchants:", "All Enchanted", 0.8, 0.84, 0.88, 0.204, 0.827, 0.600)
            else
                tooltip:AddDoubleLine("Enchants:", "Missing: " .. table.concat(missing, ", "), 0.8, 0.84, 0.88, 0.984, 0.749, 0.141)
            end
            local emptyGems = audit.emptyGemCount or 0
            if emptyGems == 0 then
                tooltip:AddDoubleLine("Gems:", "All Socketed", 0.8, 0.84, 0.88, 0.204, 0.827, 0.600)
            else
                local slots = audit.emptyGemSlots or {}
                local slotSuffix = (#slots > 0) and (" (" .. table.concat(slots, ", ") .. ")") or ""
                tooltip:AddDoubleLine("Gems:", string.format("%d Empty %s%s", emptyGems, emptyGems == 1 and "Socket" or "Sockets", slotSuffix), 0.8, 0.84, 0.88, 0.984, 0.749, 0.141)
            end
        end
        tooltip:AddLine(" ")
        tooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Open Character Frame|r", 1, 1, 1)
    elseif segKey == "bags" then
        local _, free, total = self:GetBagSlotsData()
        tooltip:AddLine("Free Bag Space", ar, ag, ab)
        tooltip:AddDoubleLine("Available Slots:", string.format("%d / %d", free, total), 0.8, 0.84, 0.88, 1, 1, 1)
    elseif segKey == "key" then
        local _, level, name, abbrev = self:GetKeystoneData()
        tooltip:AddLine("Mythic+ Keystone", ar, ag, ab)
        if level and level > 0 then
            tooltip:AddDoubleLine("Owned Keystone:", string.format("+%d %s (%s)", level, name or "", abbrev or ""), 0.8, 0.84, 0.88, ar, ag, ab)
        else
            tooltip:AddLine("No Mythic+ Keystone found in bags.", 0.580, 0.639, 0.722)
        end

        if C_WeeklyRewards and type(C_WeeklyRewards.GetActivities) == "function" and Enum and Enum.WeeklyRewardChestThresholdType then
            local actType = Enum.WeeklyRewardChestThresholdType.Activities
            local okAct, activities = pcall(C_WeeklyRewards.GetActivities, actType)
            if okAct and type(activities) == "table" and not _IsSecret(activities) and #activities > 0 then
                table.sort(activities, function(a, b)
                    return (tonumber(a.threshold) or 0) < (tonumber(b.threshold) or 0)
                end)
                local maxProgress = 0
                local maxThreshold = 8
                for _, act in ipairs(activities) do
                    if type(act) == "table" then
                        local p = (not _IsSecret(act.progress)) and (tonumber(act.progress) or 0) or 0
                        local th = (not _IsSecret(act.threshold)) and (tonumber(act.threshold) or 0) or 0
                        if p > maxProgress then maxProgress = p end
                        if th > maxThreshold then maxThreshold = th end
                    end
                end
                tooltip:AddLine(" ")
                tooltip:AddDoubleLine("Great Vault (Mythic+):", string.format("%d / %d Runs", math.min(maxProgress, maxThreshold), maxThreshold), 0.8, 0.84, 0.88, 1, 1, 1)
                for idx, act in ipairs(activities) do
                    if type(act) == "table" then
                        local th = (not _IsSecret(act.threshold)) and (tonumber(act.threshold) or 0) or 0
                        local p = (not _IsSecret(act.progress)) and (tonumber(act.progress) or 0) or 0
                        local lvl = (not _IsSecret(act.level)) and (tonumber(act.level) or 0) or 0
                        local slotLabel = string.format("Slot %d (%d %s):", idx, th, th == 1 and "Run" or "Runs")
                        if p >= th then
                            local valText = (lvl > 0) and string.format("+%d", lvl) or "Unlocked"
                            tooltip:AddDoubleLine(slotLabel, valText, 0.75, 0.80, 0.86, 0.204, 0.827, 0.600)
                        else
                            local needed = math.max(1, th - p)
                            tooltip:AddDoubleLine(slotLabel, string.format("%d %s needed", needed, needed == 1 and "run" or "runs"), 0.580, 0.639, 0.722, 0.580, 0.639, 0.722)
                        end
                    end
                end
            end
        end

        if C_WeeklyRewards and type(C_WeeklyRewards.HasAvailableRewards) == "function" then
            local okHas, hasRewards = pcall(C_WeeklyRewards.HasAvailableRewards)
            if okHas and not _IsSecret(hasRewards) and hasRewards == true then
                tooltip:AddLine("Reward Ready to Claim!", 0.204, 0.827, 0.600)
            end
        end

        tooltip:AddLine(" ")
        if level and level > 0 then
            tooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Link Keystone to Party / Raid / Instance Chat|r", 1, 1, 1)
        end
        tooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Toggle Group Finder|r", 1, 1, 1)
    elseif segKey == "rc" then
        tooltip:AddLine("Ready Check (RC)", ar, ag, ab)
        tooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Initiate party or raid ready check.|r", 1, 1, 1)
    elseif segKey == "pull" then
        local secs = tonumber(self.db and self.db.pullTimer) or 10
        local accHex = GetAccentHex()
        tooltip:AddLine("Pull Countdown Timer", ar, ag, ab)
        tooltip:AddDoubleLine("Selected Duration:", string.format("%d Seconds", secs), 0.8, 0.84, 0.88, 1, 1, 1)
        tooltip:AddLine(string.format("|cFF34D399Left-Click:|r |cFFE2E8F0Start %ds Pull / Cancel Active Pull|r", secs), 1, 1, 1)
        tooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Choose Timer Preset (3s - 20s)|r", 1, 1, 1)
        tooltip:AddLine("|cFF" .. accHex .. "Mousewheel:|r |cFFE2E8F0Step Pull Timer Duration|r", 1, 1, 1)
    elseif segKey == "fps" or segKey == "fps_ms" then
        local _, fps = self:GetFPSData()
        local memMB = (collectgarbage and (collectgarbage("count") / 1024)) or 0
        tooltip:AddLine("Performance (FPS & Memory)", ar, ag, ab)
        tooltip:AddDoubleLine("Framerate:", string.format("%d FPS", fps or 60), 0.8, 0.84, 0.88, 1, 1, 1)
        tooltip:AddDoubleLine("AddOn Memory:", string.format("%.1f MB", memMB), 0.8, 0.84, 0.88, 0.75, 0.80, 0.86)
        tooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Open DynamicFPS (/dfps)|r", 1, 1, 1)
    elseif segKey == "ping" then
        local _, homeMS, worldMS = self:GetPingData()
        local mode = (self.db and self.db.pingDisplayMode) or "BOTH"
        local order = (self.db and self.db.pingOrder) or "LOCAL_FIRST"
        local modeLabel = (mode == "LOCAL_ONLY") and "Home (Local) Only" or (mode == "WORLD_ONLY") and "World (Instance) Only" or ((order == "WORLD_FIRST") and "Both (World / Home)" or "Both (Home / World)")
        tooltip:AddLine("Network Latency (Ping)", ar, ag, ab)
        tooltip:AddDoubleLine("Home (Local) Latency:", string.format("%d ms", homeMS or 0), 0.8, 0.84, 0.88, 1, 1, 1)
        tooltip:AddDoubleLine("World (Instance) Latency:", string.format("%d ms", worldMS or 0), 0.8, 0.84, 0.88, 1, 1, 1)
        tooltip:AddDoubleLine("Display Format:", modeLabel, 0.8, 0.84, 0.88, ar, ag, ab)
        tooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Cycle Display Mode (Both / Home / World)|r", 1, 1, 1)
        tooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Swap Home / World Order|r", 1, 1, 1)
    end
end

function DynamicPrep:ApplyBarGeometry()
    if not self.prepBarFrame or not self.db then return end
    if InCombatLockdown and InCombatLockdown() then
        self.pendingBarRefreshAfterCombat = true
        return
    end
    local scale = math.max(0.60, math.min(1.50, tonumber(self.db.barScale) or 1.0))
    local alpha = math.max(0.20, math.min(1.00, tonumber(self.db.barOpacity) or 0.95))
    self.prepBarFrame:SetScale(scale)
    self.prepBarFrame:SetAlpha(alpha)
    local pt, rp, x, y = self:GetSavedBarPosition()
    local cx, cy, didClamp = ClampPrepFrameToScreen(self.prepBarFrame, pt or "TOP", rp or "TOP", x or 0, y or -8, 320, 32)
    if didClamp then
        self:SaveBarEditPosition(pt or "TOP", rp or "TOP", cx, cy)
    end
    self.prepBarFrame:ClearAllPoints()
    self.prepBarFrame:SetPoint(pt or "TOP", UIParent, rp or "TOP", cx, cy)
    if self.prepBarFrame.mover and self.prepBarFrame.mover.label then
        local _, _, _, accentHex = GetActiveAccentRGB()
        self.prepBarFrame.mover.label:SetText(string.format("|cFF%sDynamicPrep Bar|r  |cFFFFFFFF(X: %d, Y: %d)|r", accentHex, math.floor((cx or 0) + 0.5), math.floor((cy or -8) + 0.5)))
    end
end

function DynamicPrep:ShouldShowPrepBar()
    if not self.db then return true end
    if self.inBarEditMode or (self.inEditMode and self.inBarEditMode ~= false) or (self.prepBarFrame and self.prepBarFrame._dsEditModeActive) then return true end
    local mode = self.db.displayMode or "ALWAYS"
    if mode == "HIDDEN" then
        return false
    end
    if self.workspaceFrame and self.workspaceFrame:IsShown() then
        return true
    elseif mode == "OOC" then
        return not InCombatLockdown()
    elseif mode == "INSTANCE" then
        local inInst = IsInInstance()
        return inInst and true or false
    end
    return true
end

function DynamicPrep:GetSegmentTelemetryText(segKey)
    if segKey == "primary" then
        return self:GetPrimaryStatData()
    elseif segKey == "stats" then
        return self:GetSecondaryStatsData()
    elseif segKey == "weights" then
        return self:GetStatWeightsText()
    elseif segKey == "loot" then
        return self:GetSpecAndLootData()
    elseif segKey == "talents" then
        if _G.DynamicTalent and type(_G.DynamicTalent.GetPrepBarCapsuleData) == "function" then
            local okT, tText, isMismatch = pcall(_G.DynamicTalent.GetPrepBarCapsuleData, _G.DynamicTalent)
            if okT and type(tText) == "string" then
                return tText, isMismatch == true
            end
        end
        return "|cFF94A3B8Talents|r", false
    elseif segKey == "vault" then
        if _G.DynamicVault and type(_G.DynamicVault.GetPrepBarCapsuleData) == "function" then
            local okV, vText, isReward = pcall(_G.DynamicVault.GetPrepBarCapsuleData, _G.DynamicVault)
            if okV and type(vText) == "string" then
                return vText, isReward == true
            end
        end
        return "|cFF94A3B8Vault|r", false
    elseif segKey == "folio" then
        local folioText, isMismatch = self:GetOmniFolioData()
        return folioText, isMismatch
    elseif segKey == "dur" then
        return self:GetDurabilityData()
    elseif segKey == "bags" then
        return self:GetBagSlotsData()
    elseif segKey == "key" then
        return self:GetKeystoneData()
    elseif segKey == "rc" then
        return self:GetReadyCheckData()
    elseif segKey == "pull" then
        return self:GetPullTimerData()
    elseif segKey == "fps" or segKey == "fps_ms" then
        return self:GetFPSData()
    elseif segKey == "ping" then
        return self:GetPingData()
    end
    return ""
end

function DynamicPrep:RefreshStatsCapsulesFast()
    if not self.db or not self.prepBarFrame or not self.prepBarFrame:IsShown() then return end
    local segs = self.prepBarFrame.segmentFrames
    if not segs then return end
    if self.db.segments and self.db.segments.primary and segs.primary and segs.primary:IsShown() then
        local pText = self:GetPrimaryStatData()
        if segs.primary._lastText ~= pText then
            segs.primary._lastText = pText
            segs.primary.text:SetText(pText or "")
        end
    end
    if self.db.segments and self.db.segments.stats and segs.stats and segs.stats:IsShown() then
        local sText = self:GetSecondaryStatsData()
        if segs.stats._lastText ~= sText then
            segs.stats._lastText = sText
            segs.stats.text:SetText(sText or "")
        end
    end
end

function DynamicPrep:RefreshBar()
    if not _IsInActiveKeyOrCombat() then
        self._cachedPrimaryTuple = nil
        self._cachedSecondaryTuple = nil
    end
    if InCombatLockdown and InCombatLockdown() then
        self.pendingBarRefreshAfterCombat = true
        self:RefreshStatsCapsulesFast()
        return
    end
    if _IsInActiveKeyOrCombat() and self.prepBarFrame and self.prepBarFrame:IsShown() and not self.inEditMode and not (self.workspaceFrame and self.workspaceFrame:IsShown()) then
        self:RefreshStatsCapsulesFast()
        return
    end
    if not self.db then return end
    local bar = self:CreatePrepBar()
    self:ApplyBarBorderStyle(bar)

    if bar.mover and bar.mover.label then
        local ar, ag, ab, accentHex = GetActiveAccentRGB()
        SetPixelBackdrop(bar.mover, { 0.05, 0.06, 0.09, 0.84 }, { ar, ag, ab, 1.0 }, 1)
        if bar.mover.dimBg then
            bar.mover.dimBg:SetColorTexture(0.05, 0.06, 0.09, 0.84)
        end
        local _, _, curX, curY = self:GetSavedBarPosition()
        bar.mover.label:SetText(string.format("|cFF%sDynamicPrep Bar|r  |cFFFFFFFF(X: %d, Y: %d)|r", accentHex, math.floor((curX or 0) + 0.5), math.floor((curY or -8) + 0.5)))
    end

    if not self:ShouldShowPrepBar() then
        bar:Hide()
        self:SyncToastFallbackState()
        if self.RefreshLiveStagePreview then
            self:RefreshLiveStagePreview()
        end
        return
    end
    bar:Show()

    local activeSegments = {}
    for _, segKey in ipairs(self.db.segmentOrder) do
        local isEnabled = self.db.segments and self.db.segments[segKey]
        if segKey == "folio" and (not self.db.omniFolio or not self.db.omniFolio.enabled) then
            isEnabled = false
        elseif segKey == "talents" then
            if not _G.DynamicTalent or IsModuleDisabledInSuite("DynamicTalent") or (_G.DynamicTalent.db and _G.DynamicTalent.db.enabled == false) then
                isEnabled = false
            end
        elseif (segKey == "rc" or segKey == "pull") and isEnabled then
            local inPreview = (self.workspaceFrame and self.workspaceFrame:IsShown()) or self.inEditMode
            if not inPreview and not self:HasLeaderOrAssistPermission() then
                isEnabled = false
            end
        end
        local segFrame = bar.segmentFrames[segKey]
        if segFrame then
            if isEnabled then
                table.insert(activeSegments, { key = segKey, frame = segFrame })
            else
                segFrame:Hide()
            end
        end
    end

    local fixedFpsW = self:GetFixedFpsCapsuleWidth()
    local fixedPingW = self:GetFixedPingCapsuleWidth()
    local fixedRcW = self:GetFixedRcCapsuleWidth()
    local fixedPullW = self:GetFixedPullCapsuleWidth()
    local xCursor = 6
    for _, item in ipairs(activeSegments) do
        local segKey = item.key
        local seg = item.frame
        local segWidth = 90

        local displayStr, isMismatch = self:GetSegmentTelemetryText(segKey)
        seg.isFolioMismatch = (segKey == "folio" or segKey == "talents") and isMismatch or false
        ApplyDefaultCapsuleStyle(seg)
        seg.text:SetText(displayStr or "")

        if segKey == "fps" or segKey == "fps_ms" then
            segWidth = fixedFpsW
        elseif segKey == "ping" then
            segWidth = fixedPingW
        elseif segKey == "rc" then
            segWidth = fixedRcW
        elseif segKey == "pull" then
            segWidth = fixedPullW
        elseif segKey == "key" then
            local textW = SafeGetStringWidth(seg.text, 78)
            segWidth = math.max(52, textW + 18)
        else
            local defW = (segKey == "stats") and 176 or (segKey == "primary") and 96 or 80
            local textW = SafeGetStringWidth(seg.text, defW)
            local rawW = math.max(52, textW + 18)
            seg._stableWidth = math.max(seg._stableWidth or 0, rawW)
            segWidth = seg._stableWidth
        end

        seg:ClearAllPoints()
        seg:SetPoint("LEFT", bar, "LEFT", xCursor, 0)
        seg:SetWidth(segWidth)
        seg.divider:Hide()
        local inBarEdit = (self.inBarEditMode or (self.inEditMode and self.inBarEditMode ~= false) or bar._dsEditModeActive) and true or false
        seg:EnableMouse(not inBarEdit)
        seg:Show()
        xCursor = xCursor + segWidth + 4
    end

    bar:SetWidth(math.max(220, xCursor + 2))
    if bar.mover and bar._dsEditModeActive then
        bar.mover:Hide()
    end
    if not (InCombatLockdown and InCombatLockdown()) and not self._prepRefreshingGeom and not bar._dsDragging then
        local pt, rp, curX, curY = self:GetSavedBarPosition()
        local cx, cy, didClamp = ClampPrepFrameToScreen(bar, pt or "TOP", rp or "TOP", curX or 0, curY or -8, 320, 32)
        if didClamp then
            self._prepRefreshingGeom = true
            self:SaveBarEditPosition(pt or "TOP", rp or "TOP", cx, cy)
            bar:ClearAllPoints()
            bar:SetPoint(pt or "TOP", UIParent, rp or "TOP", cx, cy)
            self._prepRefreshingGeom = false
        end
    end
    self:UpdateFolioSecureButton()
    self:SyncToastFallbackState()
    self:UpdateSuiteHeaderStatus()
    if self.RefreshLiveStagePreview then
        self:RefreshLiveStagePreview()
    end
end

-- ============================================================================
-- Throttled Event-Driven Combat Stat Dispatcher (Zero OnUpdate)
-- ============================================================================
local lastCombatStatRefresh = 0
local combatTimerPending = false

function DynamicPrep:RequestStatRefresh()
    if not self.db then return end
    -- Inside an active Mythic+ key, Blizzard locks stats anyway: zero need to re-run RefreshBar on aura ticks!
    if _IsInActiveKeyOrCombat() then
        return
    end
    local now = GetTime and GetTime() or 0
    if InCombatLockdown() then
        local throttle = math.max(0.25, math.min(1.0, tonumber(self.db.combatRefreshRate) or 0.25))
        local elapsed = now - lastCombatStatRefresh
        if elapsed < throttle then
            if not combatTimerPending then
                combatTimerPending = true
                C_Timer.After(throttle - elapsed, function()
                    combatTimerPending = false
                    lastCombatStatRefresh = GetTime and GetTime() or 0
                    DynamicPrep._cachedPrimaryTuple = nil
                    DynamicPrep._cachedSecondaryTuple = nil
                    DynamicPrep:RefreshStatsCapsulesFast()
                end)
            end
            return
        end
        lastCombatStatRefresh = now
        self._cachedPrimaryTuple = nil
        self._cachedSecondaryTuple = nil
        self:RefreshStatsCapsulesFast()
        return
    end
    lastCombatStatRefresh = now
    self:RefreshBar()
end

-- ============================================================================
-- Everyday Convenience Hooks (Tab 2 Automation Engine)
-- ============================================================================
function DynamicPrep:IsYieldingSharedHooks()
    if not self.db then return false end
    local yh = self.db.yieldHooks
    if yh == true then return true end
    if type(yh) == "table" and next(yh) ~= nil then return true end
    return false
end


function DynamicPrep:IsCatalystInteractionActive()
    if not C_ItemInteraction or not C_ItemInteraction.GetItemInteractionInfo then
        return false
    end
    local ok, info = pcall(C_ItemInteraction.GetItemInteractionInfo)
    if not ok or not info or _IsSecret(info) then
        return false
    end
    local itype = info.interactionType
    if _IsSecret(itype) then
        return false
    end
    local catalystEnum = (Enum and Enum.UIItemInteractionType and Enum.UIItemInteractionType.ItemConversion) or 1
    return (itype == catalystEnum)
end

function DynamicPrep:ShouldOneClickCatalyst()
    if IsModuleDisabledInSuite("DynamicPrep") then return false end
    if not self.db or self.db.oneClickCatalyst == false then return false end
    if IsShiftKeyDown and IsShiftKeyDown() then return false end
    return self:IsCatalystInteractionActive()
end

function DynamicPrep:EnsureCatalystHooks()
    local frame = _G.ItemInteractionFrame
    if frame and not frame._dpCatalystFrameHooked and frame.HookScript then
        frame._dpCatalystFrameHooked = true
        frame:HookScript("OnShow", function()
            if not IsModuleDisabledInSuite("DynamicPrep") then
                DynamicPrep:EnsureCatalystHooks()
            end
        end)
        frame:HookScript("OnHide", function()
            DynamicPrep._catalystFrameShown = false
        end)
    end
    local actionBtn = frame and frame.ButtonFrame and frame.ButtonFrame.ActionButton
    if actionBtn and not actionBtn._dpCatalystHooked and actionBtn.HookScript then
        actionBtn._dpCatalystHooked = true
        actionBtn:HookScript("OnClick", function()
            if DynamicPrep:ShouldOneClickCatalyst() then
                if C_ItemInteraction and C_ItemInteraction.PerformItemInteraction then
                    pcall(C_ItemInteraction.PerformItemInteraction)
                end
                if StaticPopup_Hide then
                    pcall(StaticPopup_Hide, "CONFIRM_ITEM_INTERACTION")
                end
            end
        end)
    end
end

function DynamicPrep:SetupDeleteConfirmationHook()
    if self.deleteHooked then return end
    self.deleteHooked = true

    if hooksecurefunc and _G.StaticPopup_Show then
        hooksecurefunc("StaticPopup_Show", function(which)
            if which == "DEATH" or which == "DEATH_PVP" then
                DynamicPrep:UpdateDeathDialogButtonState()
                C_Timer.After(0, function()
                    DynamicPrep:UpdateDeathDialogButtonState()
                end)
            elseif which == "CONFIRM_ITEM_INTERACTION" then
                if DynamicPrep:ShouldOneClickCatalyst() then
                    if C_ItemInteraction and C_ItemInteraction.PerformItemInteraction then
                        pcall(C_ItemInteraction.PerformItemInteraction)
                    end
                    if StaticPopup_Hide then
                        pcall(StaticPopup_Hide, "CONFIRM_ITEM_INTERACTION")
                    end
                    C_Timer.After(0, function()
                        if DynamicPrep:ShouldOneClickCatalyst() then
                            if C_ItemInteraction and C_ItemInteraction.PerformItemInteraction then
                                pcall(C_ItemInteraction.PerformItemInteraction)
                            end
                            if StaticPopup_Hide then
                                pcall(StaticPopup_Hide, "CONFIRM_ITEM_INTERACTION")
                            end
                        end
                    end)
                end
            end
        end)
    end
    self:EnsureCatalystHooks()
end

do
local SERVICE_GOSSIP_ICONS = {
    [132051] = true, -- Battlemaster
    [132052] = true, -- Binder / Innkeeper
    [132054] = true, -- Healer / Spirit Healer
    [132057] = true, -- Taxi / Flight Master
    [132058] = true, -- Trainer
    [132059] = true, -- Vendor
    [132060] = true, -- Gossip / Work Order / Auction
}

local DESTRUCTIVE_GOSSIP_KEYWORDS = {
    "make this inn",
    "set my hearthstone",
    "leave",
    "exit",
    "return to",
    "teleport out",
    "resurrect",
    "cut my hair",
    "check my mail",
    "lorewalk",
    "reset",
    "restart",
    "abandon",
    "progress",
    "overwrite",
    "forfeit",
    "delete",
    "destroy",
    "irreversible",
    "permanently",
    "lose ",
    "lost",
    "wipe",
    "story",
    "chapter",
}

local function IsLorewalkingActive()
    if _G.LorewalkingFrame and _G.LorewalkingFrame.IsShown then
        local okS, shown = pcall(_G.LorewalkingFrame.IsShown, _G.LorewalkingFrame)
        if okS and not _IsSecret(shown) and shown == true then
            return true
        end
    end
    if _G.C_Lorewalking then
        for _, fnName in ipairs({ "IsLorewalkingActive", "HasActiveLorewalking", "IsInLorewalking" }) do
            local fn = _G.C_Lorewalking[fnName]
            if type(fn) == "function" then
                local okL, res = pcall(fn)
                if okL and not _IsSecret(res) and res == true then
                    return true
                end
            end
        end
    end
    if C_GossipInfo and type(C_GossipInfo.GetText) == "function" then
        local okT, txt = pcall(C_GossipInfo.GetText)
        if okT and not _IsSecret(txt) and type(txt) == "string" and txt:lower():find("lorewalk", 1, true) then
            return true
        end
    end
    return false
end

local function DetectBankerGossipKind(opt)
    if not opt or _IsSecret(opt) then return nil end
    local icon = (not _IsSecret(opt.icon)) and opt.icon or nil
    local overrideIcon = (not _IsSecret(opt.overrideIconID)) and opt.overrideIconID or nil
    local rawName = (not _IsSecret(opt.name) and type(opt.name) == "string") and opt.name:lower() or ""
    if rawName:find("guild bank", 1, true) or rawName:find("guild vault", 1, true) then
        return "GUILD"
    elseif rawName:find("warband bank", 1, true) or rawName:find("account bank", 1, true) then
        return "WARBAND"
    elseif icon == 132050
        or overrideIcon == 132050
        or rawName:find("deposit box", 1, true)
        or rawName:find("personal bank", 1, true)
        or rawName:find("check my bank", 1, true)
        or rawName:find("access my bank", 1, true)
        or rawName:find("bank", 1, true) then
        return "BANK"
    end
    return nil
end

local NARRATIVE_GOSSIP_ADDONS = { "DialogueUI", "Immersion", "Storyline", "AutoTurnIn" }

function DynamicPrep:GetActiveGossipCameraConflict()
    local isLoadedFn = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
    if type(isLoadedFn) == "function" then
        for i = 1, #NARRATIVE_GOSSIP_ADDONS do
            local addonName = NARRATIVE_GOSSIP_ADDONS[i]
            local ok, loaded = pcall(isLoadedFn, addonName)
            if ok and loaded == true then
                return addonName
            end
        end
    end
    return nil
end

function DynamicPrep:SuppressDialogueUIForGossipSkip()
    if self:GetActiveGossipCameraConflict() then
        return
    end
    -- NOTE: NEVER call _G.GossipFrame:Hide() or dui:Hide() before SelectOption;
    -- Blizzard's GossipFrame:OnHide calls C_GossipInfo.CloseGossip(), which cancels
    -- the NPC/object interaction before C_GossipInfo.SelectOption() can execute.
    self._autoSkippingGossip = true
    if self._dialogueUIRestoreTimer then
        pcall(function() self._dialogueUIRestoreTimer:Cancel() end)
        self._dialogueUIRestoreTimer = nil
    end
    pcall(function()
        local dui = _G.DUIQuestFrame
        if dui then
            if not self._duiOnShowHooked and type(dui.HookScript) == "function" then
                self._duiOnShowHooked = true
                dui:HookScript("OnShow", function(frame)
                    if DynamicPrep._autoSkippingGossip then
                        pcall(function()
                            if frame.SetAlpha then frame:SetAlpha(0) end
                        end)
                    end
                end)
            end
            if dui.SetAlpha then dui:SetAlpha(0) end
        end
    end)
    if C_Timer and C_Timer.NewTimer then
        self._dialogueUIRestoreTimer = C_Timer.NewTimer(0.60, function()
            DynamicPrep._dialogueUIRestoreTimer = nil
            DynamicPrep:RestoreDialogueUIAfterGossipSkip(false)
        end)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(0.60, function()
            DynamicPrep:RestoreDialogueUIAfterGossipSkip(false)
        end)
    end
end

function DynamicPrep:RestoreDialogueUIAfterGossipSkip(keepHiddenForBank)
    self._gossipSessionHandled = nil
    if not self._autoSkippingGossip then return end
    self._autoSkippingGossip = false
    if self._dialogueUIRestoreTimer then
        pcall(function() self._dialogueUIRestoreTimer:Cancel() end)
        self._dialogueUIRestoreTimer = nil
    end
    pcall(function()
        local dui = _G.DUIQuestFrame
        if dui then
            if keepHiddenForBank and dui.Hide then
                dui:Hide()
            end
            if dui.SetAlpha then
                dui:SetAlpha(1)
            end
        end
    end)
end

local function GetGossipOptionKey(opt, fallbackIndex)
    if not opt or _IsSecret(opt) then return nil end
    local optID = (not _IsSecret(opt.gossipOptionID)) and opt.gossipOptionID or nil
    if optID and optID ~= 0 then return optID end
    local orderIdx = (not _IsSecret(opt.orderIndex)) and opt.orderIndex or nil
    if orderIdx then return "idx:" .. tostring(orderIdx) end
    if fallbackIndex then return "idx:" .. tostring(fallbackIndex) end
    return nil
end

local function SelectGossipOptionSafe(opt, fallbackIndex)
    if not C_GossipInfo or not opt or _IsSecret(opt) then return false end
    local optID = (not _IsSecret(opt.gossipOptionID)) and opt.gossipOptionID or nil
    if optID and optID ~= 0 and type(C_GossipInfo.SelectOption) == "function" then
        pcall(C_GossipInfo.SelectOption, optID)
        return true
    end
    if type(C_GossipInfo.SelectOptionByIndex) == "function" then
        -- C_GossipInfo.SelectOptionByIndex is 1-based; opt.orderIndex is 0-based on Retail
        local idx = fallbackIndex or 1
        if not fallbackIndex and not _IsSecret(opt.orderIndex) and type(opt.orderIndex) == "number" then
            idx = opt.orderIndex + 1
        end
        pcall(C_GossipInfo.SelectOptionByIndex, idx)
        return true
    end
    return false
end

local function IsPlayerInPvEInstance(inInstanceOpt, instTypeOpt)
    local inInstance = inInstanceOpt
    local instType = instTypeOpt
    if inInstance == nil and IsInInstance then
        local okInst, rIn, rType = pcall(IsInInstance)
        if okInst and not _IsSecret(rIn) then
            inInstance = rIn and true or false
            instType = (not _IsSecret(rType) and type(rType) == "string") and rType or "none"
        end
    end
    local isDelve = (C_DelvesUI and C_DelvesUI.HasActiveDelve and C_DelvesUI.HasActiveDelve())
        or (C_PartyInfo and C_PartyInfo.IsDelveInProgress and C_PartyInfo.IsDelveInProgress())
    return (inInstance == true and (instType == "party" or instType == "raid" or instType == "scenario")) or (isDelve and true or false)
end

local function HasUnsafeGossipText(rawText)
    if _IsSecret(rawText) or type(rawText) ~= "string" or rawText == "" then
        return false
    end
    local lower = rawText:lower()
    for i = 1, #DESTRUCTIVE_GOSSIP_KEYWORDS do
        if lower:find(DESTRUCTIVE_GOSSIP_KEYWORDS[i], 1, true) then
            return true
        end
    end
    if lower:find("hearthstone", 1, true)
        or lower:find("|tinterface\\moneyframe\\", 1, true)
        or lower:find("ui-goldicon", 1, true)
        or lower:find("ui-silvericon", 1, true)
        or lower:find("ui-coppericon", 1, true)
        or lower:find("gold", 1, true) then
        return true
    end
    return false
end

local function ShouldAutoSelectSingleGossip(opt, inInstance, instType)
    if not opt or _IsSecret(opt) then return false end
    local optID = (not _IsSecret(opt.gossipOptionID)) and opt.gossipOptionID or nil
    local hasIndexFallback = C_GossipInfo and type(C_GossipInfo.SelectOptionByIndex) == "function"
    if (not optID or optID == 0) and not hasIndexFallback then return false end
    if not _IsSecret(opt.status) and opt.status ~= nil then
        local lockedStatus = (Enum and Enum.GossipOptionStatus and Enum.GossipOptionStatus.Locked) or 2
        local unavailStatus = (Enum and Enum.GossipOptionStatus and Enum.GossipOptionStatus.Unavailable) or 1
        if opt.status == lockedStatus or opt.status == unavailStatus then
            return false
        end
    end
    -- NOTE: selectOptionWhenOnlyOption is false for ordinary options (Blizzard only sets it
    -- true when its own GossipFrame auto-selects), so it must NOT be treated as a block flag.
    -- World objects (GameObject-*) also frequently use <...> and [Requires ...] in opt.name;
    -- never block options on bracket or "Requires" text.

    local confirm = (not _IsSecret(opt.confirm)) and opt.confirm or nil
    local hasConfirm = (type(confirm) == "string" and confirm ~= "")
    local rawName = (not _IsSecret(opt.name) and type(opt.name) == "string") and opt.name or nil
    local isPvEInstance = IsPlayerInPvEInstance(inInstance, instType)

    if hasConfirm then
        if not (DynamicPrep.db and DynamicPrep.db.autoConfirmInstanceGossip == true and isPvEInstance) then
            return false
        end
        if HasUnsafeGossipText(confirm) or HasUnsafeGossipText(rawName) then
            return false
        end
    end

    if rawName then
        if not hasConfirm and (rawName:find("%(Quest%)") or rawName:find("<Skip")) then
            return true
        end
        if HasUnsafeGossipText(rawName) then
            return false
        end
    end

    if isPvEInstance then
        return true
    end

    if DetectBankerGossipKind(opt) then
        return true
    end
    local icon = (not _IsSecret(opt.icon)) and opt.icon or nil
    if icon and icon ~= 132060 and SERVICE_GOSSIP_ICONS[icon] then
        return false
    end
    return true
end

local function CanAutoProgressQuest()
    if not (IsQuestCompletable and IsQuestCompletable()) then
        return false
    end
    if GetQuestMoneyToGet and (GetQuestMoneyToGet() or 0) > 0 then
        return false
    end
    local numItems = (GetNumQuestItems and GetNumQuestItems()) or 0
    for i = 1, numItems do
        if GetQuestItemLink then
            pcall(GetQuestItemLink, "required", i)
        end
    end
    return true
end

local function IsQuestOrSkipGossipOption(opt)
    if not opt or _IsSecret(opt) then return false end
    local confirm = (not _IsSecret(opt.confirm)) and opt.confirm or nil
    if type(confirm) == "string" and confirm ~= "" then
        return false
    end
    local rawName = (not _IsSecret(opt.name) and type(opt.name) == "string") and opt.name or nil
    if rawName and HasUnsafeGossipText(rawName) then
        return false
    end
    local flags = (not _IsSecret(opt.flags) and type(opt.flags) == "number") and opt.flags or 0
    if flags ~= 0 then
        local questFlag = (Enum and Enum.GossipOptionRecFlags and Enum.GossipOptionRecFlags.QuestLabelPrepend) or 1
        if flags == questFlag or (bit and bit.band and bit.band(flags, questFlag) ~= 0) then
            return true
        end
    end
    local icon = (not _IsSecret(opt.icon)) and opt.icon or nil
    if icon == 132048 or icon == 132049 then
        return true
    end
    if rawName and (rawName:find("%(Quest%)") or rawName:find("<Skip")) then
        return true
    end
    return false
end


local function TryAcceptCurrentQuest()
    if InCombatLockdown and InCombatLockdown() then return end
    if IsShiftKeyDown and IsShiftKeyDown() then return end
    if QuestFlagsPVP and QuestFlagsPVP() then return end

    if QuestGetAutoAccept and QuestGetAutoAccept() and QuestIsFromAreaTrigger and QuestIsFromAreaTrigger() then
        if AcknowledgeAutoAcceptQuest then
            pcall(AcknowledgeAutoAcceptQuest)
        elseif AcceptQuest then
            pcall(AcceptQuest)
        end
    else
        if AcceptQuest then
            pcall(AcceptQuest)
        end
    end
end

local function TryProgressCurrentQuest()
    if InCombatLockdown and InCombatLockdown() then return end
    if IsShiftKeyDown and IsShiftKeyDown() then return end
    if not CanAutoProgressQuest() then return end
    if CompleteQuest then
        pcall(CompleteQuest)
    end
end

local function TryCompleteCurrentQuest()
    if InCombatLockdown and InCombatLockdown() then return end
    if IsShiftKeyDown and IsShiftKeyDown() then return end
    if GetQuestMoneyToGet and (GetQuestMoneyToGet() or 0) > 0 then return end
    local numChoices = (GetNumQuestChoices and GetNumQuestChoices()) or 0
    if numChoices <= 1 and GetQuestReward then
        if numChoices == 1 and _G.QuestInfoFrame then
            _G.QuestInfoFrame.itemChoice = 1
        end
        pcall(GetQuestReward, numChoices == 1 and 1 or nil)
    end
end

function DynamicPrep:HandleQuestAndGossip(event, arg1)
    if not self.db then
        self:InitDB()
    end
    if GetQuestID then
        local okQ, qid = pcall(GetQuestID)
        if okQ and qid and not _IsSecret(qid) and type(qid) == "number" and qid > 0 then
            self._lastCutsceneContext = "Q" .. tostring(qid)
        end
    end
    if not self.db or self.db.autoQuestGossip == false or (IsShiftKeyDown and IsShiftKeyDown()) then
        return
    end
    if self:GetActiveGossipCameraConflict() then
        return
    end

    if event == "GOSSIP_SHOW" and C_GossipInfo then
        -- Never intercept Delve difficulty/companion picker frames (allow Midnight dungeon/world object custom textureKits)
        if (_G.DelvesDifficultyPickerFrame and _G.DelvesDifficultyPickerFrame.IsShown and _G.DelvesDifficultyPickerFrame:IsShown())
            or (_G.DelvesCompanionConfigurationFrame and _G.DelvesCompanionConfigurationFrame.IsShown and _G.DelvesCompanionConfigurationFrame:IsShown()) then
            return
        end
        if type(arg1) == "string" and arg1 ~= "" then
            local lowKit = arg1:lower()
            if (lowKit:find("delve", 1, true) and lowKit:find("picker", 1, true))
                or lowKit:find("lorewalk", 1, true) then
                return
            end
        end
        if IsLorewalkingActive() then
            return
        end
        local getGranular = _G.DynamicSuite and _G.DynamicSuite.GetGranularConflictMode
        if type(getGranular) == "function" then
            if getGranular("DynamicPrep", "DialogUI") == "YIELD_TO_EXTERNAL"
                or getGranular("DynamicPrep", "DialogueUI") == "YIELD_TO_EXTERNAL"
                or getGranular("DynamicPrep", "Plumber") == "YIELD_TO_EXTERNAL" then
                return
            end
        end
        local nowGossip = (type(GetTime) == "function" and GetTime()) or 0
        -- Per-option de-duplication (instead of a whole-session latch) so multi-step NPC/Delve
        -- dialogue chains can advance page-by-page, while the same option is never re-selected
        -- within 1s and a single conversation is capped at 8 automatic selections (loop guard).
        local function CanAutoSelectGossip(optID)
            if (self._gossipChainCount or 0) >= 8 then return false end
            if self._lastGossipOptionID == optID and self._lastGossipSelectTime
                and (nowGossip - self._lastGossipSelectTime) < 1.0 then
                return false
            end
            return true
        end
        local function MarkGossipSelected(optID)
            self._gossipSessionHandled = true
            self._lastGossipSelectTime = nowGossip
            self._lastGossipOptionID = optID
            self._gossipChainCount = (self._gossipChainCount or 0) + 1
        end
        local inCombat = InCombatLockdown and InCombatLockdown() or false
        local rawActive = (C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests()) or {}
        local rawAvail  = (C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests()) or {}
        local rawOpts   = (C_GossipInfo.GetOptions and C_GossipInfo.GetOptions()) or {}
        local activeQuests = (type(rawActive) == "table" and not _IsSecret(rawActive)) and rawActive or {}
        local availQuests  = (type(rawAvail) == "table" and not _IsSecret(rawAvail)) and rawAvail or {}
        local options      = (type(rawOpts) == "table" and not _IsSecret(rawOpts)) and rawOpts or {}
        local numActive = #activeQuests
        local numAvail  = #availQuests
        local numCompletedActive = 0

        if not inCombat then
            -- 1. Turn in completed active quests first
            if numActive > 0 then
                for _, q in ipairs(activeQuests) do
                    local qID = (q and not _IsSecret(q) and not _IsSecret(q.questID)) and q.questID or nil
                    if qID then
                        local isComp = (not _IsSecret(q.isComplete) and q.isComplete == true)
                            or (C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(qID))
                            or (C_QuestLog and C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(qID))
                        if isComp then
                            numCompletedActive = numCompletedActive + 1
                            C_GossipInfo.SelectActiveQuest(qID)
                            return
                        end
                    end
                end
            end

            -- 2. Pick up available quests (prioritize non-trivial first, then accept any non-ignored quest on the clicked NPC)
            if numAvail > 0 then
                for _, q in ipairs(availQuests) do
                    local qID = (q and not _IsSecret(q) and not _IsSecret(q.questID)) and q.questID or nil
                    local isIgnored = (q and not _IsSecret(q) and not _IsSecret(q.isIgnored) and q.isIgnored == true) or false
                    local isTrivial = (q and not _IsSecret(q) and not _IsSecret(q.isTrivial) and q.isTrivial == true) or false
                    if qID and not isIgnored and not isTrivial then
                        C_GossipInfo.SelectAvailableQuest(qID)
                        return
                    end
                end
                for _, q in ipairs(availQuests) do
                    local qID = (q and not _IsSecret(q) and not _IsSecret(q.questID)) and q.questID or nil
                    local isIgnored = (q and not _IsSecret(q) and not _IsSecret(q.isIgnored) and q.isIgnored == true) or false
                    if qID and not isIgnored then
                        C_GossipInfo.SelectAvailableQuest(qID)
                        return
                    end
                end
            end
        end

        -- 3. Auto-select Gossip options (NPCs, Delve objects, chests, cages, and world interactables)
        if #options > 0 then
            local inInstance, instType = false, "none"
            if IsInInstance then
                local okInst, rIn, rType = pcall(IsInInstance)
                if okInst and not _IsSecret(rIn) then
                    inInstance = rIn and true or false
                    instType = (not _IsSecret(rType) and type(rType) == "string") and rType or "none"
                end
            end

            -- Priority A: Always select explicit (Quest) flag/label or <Skip gossip options first
            for i = 1, #options do
                local opt = options[i]
                local optKey = GetGossipOptionKey(opt, i)
                if opt and optKey then
                    if IsQuestOrSkipGossipOption(opt) and CanAutoSelectGossip(optKey) then
                        if not inCombat or (inInstance and (instType == "party" or instType == "raid" or instType == "scenario")) then
                            MarkGossipSelected(optKey)
                            SelectGossipOptionSafe(opt, i)
                            return
                        end
                    end
                end
            end

            -- Priority B (Strict Single Option): #options == 1, #availableQuests == 0, #activeQuests == 0
            if #options == 1 and numActive == 0 and numAvail == 0 then
                local opt = options[1]
                local optKey = GetGossipOptionKey(opt, 1)
                if optKey and ShouldAutoSelectSingleGossip(opt, inInstance, instType) and CanAutoSelectGossip(optKey) then
                    local bankKind = DetectBankerGossipKind(opt)
                    MarkGossipSelected(optKey)
                    if bankKind then
                        self:SuppressDialogueUIForGossipSkip()
                    end
                    SelectGossipOptionSafe(opt, 1)
                    if bankKind and _G.DynamicBags and type(_G.DynamicBags.PreWarmCompanionBank) == "function" then
                        pcall(_G.DynamicBags.PreWarmCompanionBank, bankKind)
                    end
                    return
                end
            end
        elseif numActive == 0 and numAvail == 0 and not arg1 and C_Timer and C_Timer.After then
            -- Fallback: some world objects/instance interactables populate C_GossipInfo.GetOptions() one frame after GOSSIP_SHOW
            C_Timer.After(0, function()
                if not IsModuleDisabledInSuite("DynamicPrep") and not (IsShiftKeyDown and IsShiftKeyDown()) then
                    DynamicPrep:HandleQuestAndGossip("GOSSIP_SHOW", true)
                end
            end)
        end
        -- Lightweight 0.05s secondary check in case EllesmereUI Blizzard Skins+ / DialogueUI / server latency
        -- delays option population or GossipFrame readiness on the initial GOSSIP_SHOW frame.
        if not arg1 and C_Timer and C_Timer.After then
            C_Timer.After(0.05, function()
                if IsModuleDisabledInSuite("DynamicPrep") or (IsShiftKeyDown and IsShiftKeyDown()) then return end
                local frameShown = _G.GossipFrame and _G.GossipFrame.IsShown and _G.GossipFrame:IsShown()
                local numOpts = C_GossipInfo and C_GossipInfo.GetNumOptions and C_GossipInfo.GetNumOptions() or 0
                if frameShown or numOpts == 1 then
                    DynamicPrep:HandleQuestAndGossip("GOSSIP_SHOW", true)
                end
            end)
        end
        return
    end

    if InCombatLockdown and InCombatLockdown() then return end

    if event == "QUEST_GREETING" then
        local numActive = GetNumActiveQuests and GetNumActiveQuests() or 0
        for i = 1, numActive do
            local _, isComplete = GetActiveTitle(i)
            local qID = GetActiveQuestID and GetActiveQuestID(i)
            local isComp = isComplete or (qID and C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(qID))
            if isComp then
                SelectActiveQuest(i)
                return
            end
        end
        local numAvail = GetNumAvailableQuests and GetNumAvailableQuests() or 0
        for i = 1, numAvail do
            local isTrivial = IsAvailableQuestTrivial and IsAvailableQuestTrivial(i)
            if not isTrivial then
                SelectAvailableQuest(i)
                return
            end
        end
        if numAvail > 0 then
            SelectAvailableQuest(1)
            return
        end

    elseif event == "QUEST_DETAIL" then
        TryAcceptCurrentQuest()
        C_Timer.After(0.05, function()
            if not DynamicPrep.db or DynamicPrep.db.autoQuestGossip == false then return end
            if _G.QuestFrameDetailPanel and _G.QuestFrameDetailPanel:IsVisible() then
                TryAcceptCurrentQuest()
            end
        end)

    elseif event == "QUEST_ACCEPT_CONFIRM" then
        if ConfirmAcceptQuest then
            pcall(ConfirmAcceptQuest)
        end
        if StaticPopup_Hide then
            StaticPopup_Hide("QUEST_ACCEPT")
        end

    elseif event == "QUEST_AUTOCOMPLETE" then
        if arg1 and ShowQuestComplete then
            pcall(ShowQuestComplete, arg1)
        end

    elseif event == "QUEST_PROGRESS" then
        TryProgressCurrentQuest()
        C_Timer.After(0.05, function()
            if not DynamicPrep.db or DynamicPrep.db.autoQuestGossip == false then return end
            if _G.QuestFrameProgressPanel and _G.QuestFrameProgressPanel:IsVisible() then
                TryProgressCurrentQuest()
            end
        end)

    elseif event == "QUEST_COMPLETE" then
        TryCompleteCurrentQuest()
        C_Timer.After(0.05, function()
            if not DynamicPrep.db or DynamicPrep.db.autoQuestGossip == false then return end
            if _G.QuestFrameRewardPanel and _G.QuestFrameRewardPanel:IsVisible() then
                TryCompleteCurrentQuest()
            end
        end)

    elseif event == "ITEM_TEXT_READY" then
        if ItemTextGetPage and ItemTextGetPage() and ItemTextGetPage() > 0 then
            if ItemTextHasNextPage and ItemTextHasNextPage() and ItemTextNextPage then
                pcall(ItemTextNextPage)
            end
        end
    end
end

function DynamicPrep:HandleGossipConfirm(gossipID, text, cost)
    if not self.db then self:InitDB() end
    if not self.db or self.db.autoQuestGossip == false or self.db.autoConfirmInstanceGossip ~= true then
        return
    end
    if IsModuleDisabledInSuite("DynamicPrep") or (IsShiftKeyDown and IsShiftKeyDown()) then
        return
    end
    if self:GetActiveGossipCameraConflict() then
        return
    end
    local getGranular = _G.DynamicSuite and _G.DynamicSuite.GetGranularConflictMode
    if type(getGranular) == "function" then
        if getGranular("DynamicPrep", "DialogUI") == "YIELD_TO_EXTERNAL"
            or getGranular("DynamicPrep", "DialogueUI") == "YIELD_TO_EXTERNAL"
            or getGranular("DynamicPrep", "Plumber") == "YIELD_TO_EXTERNAL" then
            return
        end
    end
    if not IsPlayerInPvEInstance() then
        return
    end
    if _IsSecret(gossipID) or _IsSecret(cost) or _IsSecret(text) then
        return
    end
    local gID = tonumber(gossipID)
    if not gID or gID <= 0 then
        return
    end
    local numCost = (cost == nil) and 0 or tonumber(cost)
    if numCost ~= 0 then
        return
    end
    if IsLorewalkingActive() or HasUnsafeGossipText(text) then
        return
    end

    self._lastAutoConfirmedGossipID = gID
    self._lastAutoConfirmedGossipAt = (type(GetTime) == "function" and GetTime()) or 0
    if C_GossipInfo and type(C_GossipInfo.SelectOption) == "function" then
        pcall(C_GossipInfo.SelectOption, gID, "", true)
    end
    if type(_G.StaticPopup_Hide) == "function" then
        pcall(_G.StaticPopup_Hide, "GOSSIP_CONFIRM")
    end
end

function DynamicPrep:HandlePlayerChoiceUpdate()
    if not self.db then self:InitDB() end
    if not self.db or self.db.autoSinglePlayerChoice == false or IsModuleDisabledInSuite("DynamicPrep") then
        return
    end
    if IsShiftKeyDown and IsShiftKeyDown() then return end
    if not (C_PlayerChoice and type(C_PlayerChoice.GetCurrentPlayerChoiceInfo) == "function"
        and type(C_PlayerChoice.SendPlayerChoiceResponse) == "function") then
        return
    end

    local inCombat = (InCombatLockdown and InCombatLockdown()) and true or false
    local ok, info = pcall(C_PlayerChoice.GetCurrentPlayerChoiceInfo)
    if not ok or type(info) ~= "table" or _IsSecret(info) then return end
    if type(info.options) ~= "table" or _IsSecret(info.options) or #info.options ~= 1 then
        return
    end

    local opt = info.options[1]
    if type(opt) ~= "table" or _IsSecret(opt) then return end
    if not _IsSecret(opt.disabledOption) and opt.disabledOption then
        if inCombat then self._pendingPlayerChoiceAfterCombat = true end
        return
    end
    if type(opt.buttons) ~= "table" or _IsSecret(opt.buttons) or #opt.buttons ~= 1 then
        return
    end

    local btn = opt.buttons[1]
    if type(btn) ~= "table" or _IsSecret(btn) then return end
    if not _IsSecret(btn.disabled) and btn.disabled then
        if inCombat then self._pendingPlayerChoiceAfterCombat = true end
        return
    end
    if not _IsSecret(btn.hideButtonShowText) and btn.hideButtonShowText then return end
    if not _IsSecret(btn.confirmation) and type(btn.confirmation) == "string" and btn.confirmation ~= "" then
        return
    end
    local respID = (not _IsSecret(btn.id) and type(btn.id) == "number") and btn.id or nil
    if not respID then return end

    local choiceID = (not _IsSecret(info.choiceID) and type(info.choiceID) == "number") and info.choiceID or 0
    local key = tostring(choiceID) .. ":" .. tostring(respID)
    local now = (type(GetTime) == "function" and GetTime()) or 0
    if self._lastPlayerChoiceKey == key and self._lastPlayerChoiceTime and (now - self._lastPlayerChoiceTime) < 1.2 then
        return
    end
    self._lastPlayerChoiceKey = key
    self._lastPlayerChoiceTime = now

    -- C_PlayerChoice.SendPlayerChoiceResponse is a safe network call (works in combat with zero taint).
    pcall(C_PlayerChoice.SendPlayerChoiceResponse, respID)
    if inCombat then
        self._pendingPlayerChoiceAfterCombat = true
    else
        self._pendingPlayerChoiceAfterCombat = nil
    end

    local function CloseChoiceUI()
        if InCombatLockdown and InCombatLockdown() then
            DynamicPrep._pendingPlayerChoiceAfterCombat = true
            return
        end
        local pcf = _G.PlayerChoiceFrame
        if pcf and pcf.IsShown and pcf:IsShown() then
            if HideUIPanel then
                pcall(HideUIPanel, pcf)
            elseif pcf.Hide then
                pcall(pcf.Hide, pcf)
            end
        end
    end
    CloseChoiceUI()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, CloseChoiceUI)
        C_Timer.After(0.05, CloseChoiceUI)
    end
end

local function SuppressTalkingHeadNow()
    if not DynamicPrep.db or ( DynamicPrep.db.cinematicMode or "BOTH" ) ~= "BOTH" then return end
    if IsShiftKeyDown and IsShiftKeyDown() then return end
    local th = _G.TalkingHeadFrame
    if not th then return end
    if th.CloseImmediately then
        pcall(th.CloseImmediately, th)
    end
    if th.Hide then
        pcall(th.Hide, th)
    end
end

function DynamicPrep:UpdateTalkingHeadSuppression()
    if not self.db then return end
    local th = _G.TalkingHeadFrame
    if th and not self._talkingHeadHooked then
        self._talkingHeadHooked = true
        if type(th.PlayCurrent) == "function" then
            hooksecurefunc(th, "PlayCurrent", SuppressTalkingHeadNow)
        end
        if th.HookScript then
            th:HookScript("OnShow", SuppressTalkingHeadNow)
        end
    end
    if not self._talkingHeadGlobalHooked and type(_G.TalkingHeadFrame_PlayCurrent) == "function" then
        self._talkingHeadGlobalHooked = true
        hooksecurefunc("TalkingHeadFrame_PlayCurrent", SuppressTalkingHeadNow)
    end
    SuppressTalkingHeadNow()
end

function DynamicPrep:HandleCinematicOrMovie(event, arg1)
    if not self.db then return end
    if IsModifierKeyDown and IsModifierKeyDown() then return end
    local mode = self.db.cinematicMode or "BOTH"
    if mode == "OFF" then return end

    if event == "PLAY_MOVIE" then
        if arg1 and not _IsSecret(arg1) then
            _G.DynamicSuiteDB = _G.DynamicSuiteDB or {}
            _G.DynamicSuiteDB.global = _G.DynamicSuiteDB.global or {}
            if type(_G.DynamicSuiteDB.global.seenMovies) ~= "table" then
                _G.DynamicSuiteDB.global.seenMovies = {}
            end
            local movieID = tonumber(arg1) or tostring(arg1)
            _G.DynamicSuiteDB.global.seenMovies[movieID] = true
        end
        if MovieFrame_StopMovie and _G.MovieFrame then
            pcall(MovieFrame_StopMovie, _G.MovieFrame)
        end
        if _G.MovieFrame and _G.MovieFrame.StopMovie then
            pcall(_G.MovieFrame.StopMovie, _G.MovieFrame)
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, function()
                if _G.MovieFrame and _G.MovieFrame:IsShown() then
                    if MovieFrame_StopMovie then
                        pcall(MovieFrame_StopMovie, _G.MovieFrame)
                    end
                    if _G.MovieFrame.StopMovie then
                        pcall(_G.MovieFrame.StopMovie, _G.MovieFrame)
                    end
                end
            end)
        end
    elseif event == "CINEMATIC_START" then
        if CinematicFrame_CancelCinematic then
            pcall(CinematicFrame_CancelCinematic)
        end
        if StopCinematic then
            pcall(StopCinematic)
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, function()
                if _G.CinematicFrame and _G.CinematicFrame:IsShown() then
                    if CinematicFrame_CancelCinematic then
                        pcall(CinematicFrame_CancelCinematic)
                    end
                    if StopCinematic then
                        pcall(StopCinematic)
                    end
                end
            end)
        end
    end
end

function DynamicPrep:IsGroupOrEncounterInCombat(inviter)
    if InCombatLockdown() then return true end
    if IsEncounterInProgress and IsEncounterInProgress() then return true end
    if inviter and UnitAffectingCombat and UnitAffectingCombat(inviter) then return true end
    if IsInRaid and IsInRaid() then
        local n = GetNumGroupMembers and GetNumGroupMembers() or 0
        for i = 1, n do
            if UnitAffectingCombat and UnitAffectingCombat("raid" .. i) then
                return true
            end
        end
    elseif IsInGroup and IsInGroup() then
        local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
        for i = 1, n do
            if UnitAffectingCombat and UnitAffectingCombat("party" .. i) then
                return true
            end
        end
    end
    return false
end


function DynamicPrep:AcceptAndHideResurrectPopups()
    if AcceptResurrect then
        AcceptResurrect()
    end
    C_Timer.After(0.05, function()
        if StaticPopup_Hide then
            StaticPopup_Hide("RESURRECT")
            StaticPopup_Hide("RESURRECT_NO_SICKNESS")
            StaticPopup_Hide("RESURRECT_NO_TIMER")
        end
    end)
end

function DynamicPrep:HandleResurrectRequest(inviter)
    if not self.db then return end
    local mode = self.db.autoRezMode or "OUT_OF_COMBAT"
    if mode == "OFF" then return end
    if ResurrectHasSickness and ResurrectHasSickness() then return end

    if mode == "OUT_OF_COMBAT" and self:IsGroupOrEncounterInCombat(inviter) then
        -- Do not auto-accept a mid-pull combat Battle Rez
        return
    end

    local delay = GetCorpseRecoveryDelay and GetCorpseRecoveryDelay() or 0
    if (delay and delay > 0) or (ResurrectHasTimer and ResurrectHasTimer()) then
        local waitSec = math.max(0.1, tonumber(delay) or 0.1) + 0.1
        C_Timer.After(waitSec, function()
            if not DynamicPrep.db or DynamicPrep.db.autoRezMode == "OFF" then return end
            if ResurrectHasSickness and ResurrectHasSickness() then return end
            if DynamicPrep.db.autoRezMode == "OUT_OF_COMBAT" and DynamicPrep:IsGroupOrEncounterInCombat(inviter) then
                return
            end
            DynamicPrep:AcceptAndHideResurrectPopups()
        end)
    else
        self:AcceptAndHideResurrectPopups()
    end
end

local function SafeDeathUnitFlag(fn, u)
    if type(fn) ~= "function" then return false end
    local ok, val = pcall(fn, u)
    if not ok or val == nil or _IsSecret(val) then return false end
    return val and true or false
end

local function GetStaticPopupButton1(dialog)
    if not dialog then return nil end
    if dialog.button1 then return dialog.button1 end
    if type(dialog.GetButton1) == "function" then
        local ok, b = pcall(dialog.GetButton1, dialog)
        if ok and b then return b end
    end
    if type(dialog.GetName) == "function" then
        local dName = dialog:GetName()
        if dName and _G[dName .. "Button1"] then
            return _G[dName .. "Button1"]
        end
    end
    return nil
end

function DynamicPrep:IsReleaseProtectionActive()
    if IsModuleDisabledInSuite("DynamicPrep") then return false end
    local mode = (self.db and self.db.autoReleaseMode) or "WIPE_AND_CTRL"
    return (mode == "WIPE_AND_CTRL" or mode == "HOLD_CTRL" or mode == "PVP_AUTO_WIPE_PVE" or mode == "PVP_AUTO_PVE_CTRL")
end

function DynamicPrep:CanSafelyAutoRelease(ignoreSelfRez)
    if not SafeDeathUnitFlag(UnitIsDeadOrGhost, "player") then
        return false
    end
    if SafeDeathUnitFlag(UnitIsGhost, "player") then
        return false
    end
    if not ignoreSelfRez and C_DeathInfo and C_DeathInfo.GetSelfResurrectOptions then
        local ok, opts = pcall(C_DeathInfo.GetSelfResurrectOptions)
        if ok and opts and #opts > 0 then
            return false
        end
    end
    return true
end

local function ApplyDeathPopupReleaseLock(dialog, forceRestore)
    if not dialog then return end
    local btn = GetStaticPopupButton1(dialog)
    if not btn then return end
    local which = dialog.which
    local normalLabel = _G.DEATH_RELEASE or _G.RELEASE_SPIRIT or _G.RELEASESPIRIT or "Release Spirit"

    if forceRestore then
        if btn.Enable then btn:Enable() end
        if dialog._dpHoldCtrlTextApplied and (which == "DEATH" or which == "DEATH_PVP") and btn.SetText then
            btn:SetText(normalLabel)
        end
        dialog._dpHoldCtrlTextApplied = nil
        return
    end

    if which ~= "DEATH" and which ~= "DEATH_PVP" then
        if dialog._dpHoldCtrlTextApplied then
            if btn.Enable then btn:Enable() end
            dialog._dpHoldCtrlTextApplied = nil
        end
        return
    end

    local isDeadNotGhost = SafeDeathUnitFlag(UnitIsDead, "player") and not SafeDeathUnitFlag(UnitIsGhost, "player")
    if not dialog:IsShown() or not isDeadNotGhost or not DynamicPrep:IsReleaseProtectionActive() then
        if btn.Enable then btn:Enable() end
        if btn.SetText then
            btn:SetText(normalLabel)
        end
        dialog._dpHoldCtrlTextApplied = nil
        return
    end

    if IsControlKeyDown and IsControlKeyDown() then
        if btn.Enable then btn:Enable() end
        if btn.SetText then
            btn:SetText(normalLabel)
        end
        dialog._dpHoldCtrlTextApplied = true
    else
        if btn.Disable then btn:Disable() end
        if btn.SetText then
            btn:SetText("Hold CTRL to Release")
        end
        dialog._dpHoldCtrlTextApplied = true
    end
end

function DynamicPrep:EnsureDeathPopupHooks()
    if self._deathPopupHooksInstalled then return end
    self._deathPopupHooksInstalled = true

    if type(_G.StaticPopup_OnUpdate) == "function" then
        hooksecurefunc("StaticPopup_OnUpdate", function(dialog)
            if dialog and (dialog.which == "DEATH" or dialog.which == "DEATH_PVP") then
                ApplyDeathPopupReleaseLock(dialog, false)
            end
        end)
    end
    if type(_G.StaticPopup_OnShow) == "function" then
        hooksecurefunc("StaticPopup_OnShow", function(dialog)
            if dialog and (dialog.which == "DEATH" or dialog.which == "DEATH_PVP") then
                ApplyDeathPopupReleaseLock(dialog, false)
            end
        end)
    end
    if type(_G.StaticPopup_OnHide) == "function" then
        hooksecurefunc("StaticPopup_OnHide", function(dialog)
            if dialog and dialog._dpHoldCtrlTextApplied then
                ApplyDeathPopupReleaseLock(dialog, true)
            end
        end)
    end

    for i = 1, 4 do
        local popup = _G["StaticPopup" .. i]
        if popup and popup.HookScript and not popup._dpDeathHooked then
            popup._dpDeathHooked = true
            popup:HookScript("OnUpdate", function(selfPopup)
                if selfPopup.which == "DEATH" or selfPopup.which == "DEATH_PVP" then
                    ApplyDeathPopupReleaseLock(selfPopup, false)
                end
            end)
            popup:HookScript("OnShow", function(selfPopup)
                if selfPopup.which == "DEATH" or selfPopup.which == "DEATH_PVP" then
                    ApplyDeathPopupReleaseLock(selfPopup, false)
                end
            end)
            popup:HookScript("OnHide", function(selfPopup)
                if selfPopup._dpHoldCtrlTextApplied then
                    ApplyDeathPopupReleaseLock(selfPopup, true)
                end
            end)
        end
    end
end

function DynamicPrep:UpdateDeathDialogButtonState(forceRestore)
    self:EnsureDeathPopupHooks()
    local foundDialog = nil
    if StaticPopup_FindVisible then
        foundDialog = StaticPopup_FindVisible("DEATH") or StaticPopup_FindVisible("DEATH_PVP")
    end
    if foundDialog then
        ApplyDeathPopupReleaseLock(foundDialog, forceRestore == true)
    end
    for i = 1, 4 do
        local popup = _G["StaticPopup" .. i]
        if popup and (popup.which == "DEATH" or popup.which == "DEATH_PVP" or popup._dpHoldCtrlTextApplied) then
            ApplyDeathPopupReleaseLock(popup, forceRestore == true)
        end
    end
end

function DynamicPrep:ExecuteReleaseSpirit()
    if RepopMe then
        RepopMe()
    end
end

function DynamicPrep:HandlePlayerDead()
    if not self.db then return end
    self:UpdateDeathDialogButtonState(false)
    C_Timer.After(0.05, function()
        DynamicPrep:UpdateDeathDialogButtonState(false)
    end)

    local mode = self.db.autoReleaseMode or "WIPE_AND_CTRL"
    if mode == "OFF" or mode == "WIPE_AND_CTRL" or mode == "HOLD_CTRL" then
        return
    end

    if mode == "PVP_AUTO_WIPE_PVE" or mode == "PVP_AUTO_PVE_CTRL" then
        local _, instType = IsInInstance()
        if (instType == "pvp" or instType == "arena") and self:CanSafelyAutoRelease(false) then
            self:ExecuteReleaseSpirit()
        end
    elseif mode == "ALWAYS" then
        if self:CanSafelyAutoRelease(false) then
            self:ExecuteReleaseSpirit()
        end
    end
end

function DynamicPrep:HandleModifierStateChanged(key, down)
    if not self.db then return end
    self:UpdateDeathDialogButtonState(false)
end
end

-- ============================================================================
-- Blizzard Desktop Window Manager Bridge Stubs (Delegated to DynamicSuite Core)
-- ============================================================================
do
    local function GetCoreDesktopWindows()
        local ds = _G.DynamicSuite
        if type(ds) == "table" and type(ds.DesktopWindows) == "table" then
            return ds.DesktopWindows
        end
        return nil
    end

    function DynamicPrep:GetBlizzardWindowYieldAddon()
        local dw = GetCoreDesktopWindows()
        if dw then
            local fn = dw.GetBlizzardWindowYieldAddon or dw.GetYieldAddon
            if type(fn) == "function" then
                local ok, r1, r2 = pcall(fn, dw)
                if ok then
                    if type(r1) == "boolean" then
                        return r1, r2
                    elseif type(r1) == "string" and r1 ~= "" then
                        return true, r1
                    end
                end
            end
        end
        return false, nil
    end

    function DynamicPrep:IsYieldingBlizzardWindowsToEllesmereUI()
        local dw = GetCoreDesktopWindows()
        if dw then
            local fn = dw.IsYieldingBlizzardWindowsToEllesmereUI or dw.IsYielding
            if type(fn) == "function" then
                local ok, res = pcall(fn, dw)
                if ok then return res == true end
            end
        end
        local yielding = self:GetBlizzardWindowYieldAddon()
        return yielding == true
    end

    function DynamicPrep:ApplyAllBlizzardWindowStates()
        local dw = GetCoreDesktopWindows()
        if dw then
            local fn = dw.ApplyAllWindowStates or dw.ApplyAllBlizzardWindowStates
            if type(fn) == "function" then
                pcall(fn, dw)
            end
        end
    end

    function DynamicPrep:ResetSingleBlizzardWindow(frameName, showToast)
        local dw = GetCoreDesktopWindows()
        if dw then
            local fn = dw.ResetSingleWindow or dw.ResetSingleBlizzardWindow
            if type(fn) == "function" then
                pcall(fn, dw, frameName, showToast)
            end
        end
    end

    function DynamicPrep:ResetAllBlizzardWindows(silent)
        local dw = GetCoreDesktopWindows()
        if dw then
            local fn = dw.ResetAllWindows or dw.ResetAllBlizzardWindows
            if type(fn) == "function" then
                pcall(fn, dw, silent)
            end
        end
    end

    function DynamicPrep:InitBlizzardWindowQoL(loadedAddonName)
        local dw = GetCoreDesktopWindows()
        if dw and type(dw.Init) == "function" then
            pcall(dw.Init, dw, loadedAddonName)
        end
    end

    function DynamicPrep:HandleBlizzardWindowCombatChange(inCombat)
        local dw = GetCoreDesktopWindows()
        if dw then
            local fn = dw.HandleCombatChange or dw.HandleBlizzardWindowCombatChange
            if type(fn) == "function" then
                pcall(fn, dw, inCombat)
            end
        end
    end
end

-- ============================================================================
-- Automated Healing Macro ([DynamicHeal]) Engine (Modifier-Free Sequential Fallback)
-- ============================================================================
do
local HEALTHSTONES = { 224464, 5512 } -- Demonic Healthstone, Healthstone
local PRIMARY_HEALING_POTIONS = {
    -- Midnight Health Potions (Concentrated Silvermoon & Silvermoon Health Potions)
    271883, 271882, 271881, 271884, -- Concentrated Silvermoon Health Potion (R2/R1/tiers)
    241305, 241304, 241303,         -- Silvermoon Health Potion (R2/R1/tiers)
    -- The War Within Health Potions
    211880, 211879, 211878,         -- Algari Healing Potion R3/R2/R1
    -- Dragonflight & Legacy Health Potions
    191380, 191379, 191378,         -- Refreshing Healing Potion R3/R2/R1
    187802, 171266,                 -- Cosmic / Spiritual Healing Potion
}
local SECONDARY_HEALING_POTIONS = {
    212265, 212264, 212263,         -- Cavedweller's Delight R3/R2/R1
}

local CLASS_SURVIVAL_SPELLS = {
    ROGUE       = { "Crimson Vial" },
    HUNTER      = { "Exhilaration" },
    WARRIOR     = { "Impending Victory", "Victory Rush" },
    PRIEST      = { "Desperate Prayer" },
    MAGE        = { "Ice Barrier" },
    PALADIN     = { "Word of Glory" },
    DRUID       = { "Frenzied Regeneration" },
    MONK        = { "Expel Harm" },
    DEATHKNIGHT = { "Death Strike" },
    DEMONHUNTER = { "Blur" },
    WARLOCK     = { "Dark Pact", "Mortal Coil" },
    EVOKER      = { "Verdant Embrace" },
    SHAMAN      = { "Healing Surge" },
}

local function GetSafeBagItemCount(itemID)
    if C_Item and C_Item.GetItemCount then
        local ok, cnt = pcall(C_Item.GetItemCount, itemID, false, false, true)
        if ok and type(cnt) == "number" and not IsSecretValue(cnt) then
            return cnt
        end
    end
    if GetItemCount then
        local ok, cnt = pcall(GetItemCount, itemID, false, false)
        if ok and type(cnt) == "number" and not IsSecretValue(cnt) then
            return cnt
        end
    end
    return 0
end

local function GetSafeItemCooldownRemaining(itemID)
    if not itemID then return 0 end
    local start, duration, enable
    if C_Item and type(C_Item.GetItemCooldown) == "function" then
        local ok, s, d, e = pcall(C_Item.GetItemCooldown, itemID)
        if ok then start, duration, enable = s, d, e end
    elseif C_Container and type(C_Container.GetItemCooldown) == "function" then
        local ok, s, d, e = pcall(C_Container.GetItemCooldown, itemID)
        if ok then start, duration, enable = s, d, e end
    elseif type(_G.GetItemCooldown) == "function" then
        local ok, s, d, e = pcall(_G.GetItemCooldown, itemID)
        if ok then start, duration, enable = s, d, e end
    end
    if not start or not duration or _IsSecret(start) or _IsSecret(duration) or _IsSecret(enable) then
        return 0
    end
    start = tonumber(start) or 0
    duration = tonumber(duration) or 0
    if start > 0 and duration > 1.5 then
        local now = (GetTime and GetTime()) or 0
        local rem = (start + duration) - now
        if rem > 0 then
            return rem
        end
    end
    return 0
end

function DynamicPrep:GetClassSurvivalSpell()
    local _, classFile = UnitClass("player")
    local list = (classFile and CLASS_SURVIVAL_SPELLS[classFile]) or { "Crimson Vial" }
    if #list > 1 and C_Spell and C_Spell.GetSpellInfo then
        for _, spellName in ipairs(list) do
            local ok, info = pcall(C_Spell.GetSpellInfo, spellName)
            if ok and info and info.spellID and SafeIsPlayerSpellKnown(info.spellID) then
                return spellName
            end
        end
    end
    return list[1] or "Crimson Vial"
end

function DynamicPrep:ScanHealingConsumables()
    local bestStoneID, stoneCount = nil, 0
    for _, id in ipairs(HEALTHSTONES) do
        local cnt = GetSafeBagItemCount(id)
        if cnt and cnt > 0 then
            bestStoneID = id
            stoneCount = cnt
            break
        end
    end

    local bestPotID, potCount = nil, 0
    for _, id in ipairs(PRIMARY_HEALING_POTIONS) do
        local cnt = GetSafeBagItemCount(id)
        if cnt and cnt > 0 then
            bestPotID = id
            potCount = cnt
            break
        end
    end

    local secondaryPotID, secondaryPotCount = nil, 0
    for _, id in ipairs(SECONDARY_HEALING_POTIONS) do
        local cnt = GetSafeBagItemCount(id)
        if cnt and cnt > 0 then
            secondaryPotID = id
            secondaryPotCount = cnt
            break
        end
    end

    if not bestPotID and secondaryPotID then
        bestPotID = secondaryPotID
        potCount = secondaryPotCount
        secondaryPotID = nil
        secondaryPotCount = 0
    end

    -- Dynamic Bag Scan Fallback: Detects any health potion in bags if not in hardcoded list
    if not bestPotID and C_Container and C_Container.GetContainerNumSlots then
        for bag = 0, 4 do
            local slots = C_Container.GetContainerNumSlots(bag) or 0
            for slot = 1, slots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID and info.hyperlink and not IsSecretValue(info.hyperlink) then
                    local _, _, _, _, _, classID, subClassID
                    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
                        _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(info.itemID)
                    end
                    -- Consumable (0): Potion (1)
                    if classID == 0 and subClassID == 1 then
                        local name = info.hyperlink:match("%[(.-)%]") or (C_Item.GetItemNameByID and C_Item.GetItemNameByID(info.itemID)) or ""
                        if name:find("Health Potion") or name:find("Healing Potion") then
                            local cnt = GetSafeBagItemCount(info.itemID)
                            if cnt and cnt > 0 then
                                bestPotID = info.itemID
                                potCount = cnt
                                break
                            end
                        end
                    end
                end
            end
            if bestPotID then break end
        end
    end

    return bestStoneID, stoneCount, bestPotID, potCount, secondaryPotID, secondaryPotCount
end

function DynamicPrep:UpdateHealMacro(pickupToCursor, forceReset)
    if InCombatLockdown and InCombatLockdown() then
        self.pendingHealMacroUpdate = true
        if pickupToCursor then
            print(string.format("|cFF%sDynamicPrep:|r Cannot create or pick up [DynamicHeal] while in combat. Queued for combat end.", GetAccentHex()))
        end
        return
    end
    if not self.db then return end

    local order = self.db.healMacroOrder or "STONE_FIRST"
    if pickupToCursor and (order == "OFF" or self.db.autoHealMacroEnabled == false) then
        order = "STONE_FIRST"
        self.db.healMacroOrder = "STONE_FIRST"
        self.db.autoHealMacroEnabled = true
    end
    if order == "OFF" or self.db.autoHealMacroEnabled == false then
        return
    end

    local stoneID, stoneCnt, potID, potCnt, secPotID, secPotCnt = self:ScanHealingConsumables()
    local classSpell = self:GetClassSurvivalSpell()

    -- Build priority list strictly from items currently in bags (count > 0)
    local rawChain = {}
    local function PushUniqueItem(id, cnt)
        if not id or (cnt or 0) <= 0 then return end
        for i = 1, #rawChain do
            if rawChain[i] == id then return end
        end
        rawChain[#rawChain + 1] = id
    end

    if order == "POT_FIRST" then
        PushUniqueItem(potID, potCnt)
        PushUniqueItem(stoneID, stoneCnt)
        PushUniqueItem(secPotID, secPotCnt)
    else
        -- Default ("STONE_FIRST" / "BOTH"): Healthstone -> Primary Healing Potion -> Secondary Healing Potion
        PushUniqueItem(stoneID, stoneCnt)
        PushUniqueItem(potID, potCnt)
        PushUniqueItem(secPotID, secPotCnt)
    end

    -- Out-of-Combat Cooldown Awareness:
    -- If the 1st priority item (e.g. Healthstone) is on cooldown out of combat (>2s remaining) while a fallback item is ready,
    -- place the ready item(s) first and schedule a post-cooldown refresh so the macro is always primed on the first usable item.
    local finalChain = rawChain
    if #rawChain >= 2 then
        local readyItems = {}
        local coolingItems = {}
        local minCoolingRem = nil
        for i = 1, #rawChain do
            local id = rawChain[i]
            local rem = GetSafeItemCooldownRemaining(id)
            if rem > 2.0 then
                coolingItems[#coolingItems + 1] = id
                if not minCoolingRem or rem < minCoolingRem then
                    minCoolingRem = rem
                end
            else
                readyItems[#readyItems + 1] = id
            end
        end
        if #readyItems > 0 and #coolingItems > 0 then
            finalChain = {}
            for i = 1, #readyItems do finalChain[#finalChain + 1] = readyItems[i] end
            for i = 1, #coolingItems do finalChain[#finalChain + 1] = coolingItems[i] end
            if minCoolingRem and C_Timer and C_Timer.After then
                local waitSec = math.min(300, math.max(0.5, minCoolingRem + 0.2))
                local now = (GetTime and GetTime()) or 0
                if not self._nextHealCooldownWakeup or (now + waitSec) < (self._nextHealCooldownWakeup - 0.2) then
                    self._nextHealCooldownWakeup = now + waitSec
                    C_Timer.After(waitSec, function()
                        DynamicPrep._nextHealCooldownWakeup = nil
                        if not (InCombatLockdown and InCombatLockdown()) then
                            DynamicPrep:UpdateHealMacro(false, true)
                        else
                            DynamicPrep.pendingHealMacroUpdate = true
                        end
                    end)
                end
            end
        end
    end

    -- Modifier-Free Priority Healing Macro Body (#showtooltip + /castsequence reset=combat when 2+ items exist)
    local body
    if #finalChain >= 2 then
        local seqParts = {}
        for i = 1, #finalChain do
            seqParts[i] = "item:" .. tostring(finalChain[i])
        end
        body = "#showtooltip\n/castsequence reset=combat " .. table.concat(seqParts, ", ")
    elseif #finalChain == 1 then
        body = string.format("#showtooltip\n/use item:%d", finalChain[1])
    else
        body = string.format("#showtooltip %s\n/cast %s", classSpell, classSpell)
    end

    if GetMacroIndexByName then
        local idx = GetMacroIndexByName("DynamicHeal") or 0
        if idx and idx > 0 then
            if EditMacro then
                local _, _, curBody = GetMacroInfo(idx)
                if curBody ~= body or forceReset then
                    if curBody == body and forceReset and #finalChain >= 2 then
                        -- Force C++ /castsequence step index reset back to Item 1 out of combat
                        pcall(EditMacro, idx, "DynamicHeal", "INV_Misc_QuestionMark", body .. " ")
                    end
                    pcall(EditMacro, idx, "DynamicHeal", "INV_Misc_QuestionMark", body)
                end
            end
        elseif CreateMacro then
            local numGlobal = GetNumMacros and select(1, GetNumMacros()) or 0
            if numGlobal < 120 then
                pcall(CreateMacro, "DynamicHeal", "INV_Misc_QuestionMark", body, nil)
            end
        end
    end

    if pickupToCursor and PickupMacro then
        pcall(PickupMacro, "DynamicHeal")
    end
end

function DynamicPrep:GetHealMacroActionBarStatus()
    local idx = (GetMacroIndexByName and GetMacroIndexByName("DynamicHeal")) or 0
    if not idx or idx <= 0 then
        return "NOT_CREATED", "|cFFF87171[Not Created]|r", "Create & Pickup Macro"
    end
    if type(_G.GetActionInfo) == "function" then
        for slot = 1, 180 do
            local ok, actionType, id = pcall(_G.GetActionInfo, slot)
            if ok and actionType == "macro" then
                if id == idx then
                    return "ON_BAR", "|cFF34D399[On Action Bar]|r", "Pickup Macro (On Bar)"
                end
                if type(_G.GetActionText) == "function" then
                    local okT, actionName = pcall(_G.GetActionText, slot)
                    if okT and actionName == "DynamicHeal" then
                        return "ON_BAR", "|cFF34D399[On Action Bar]|r", "Pickup Macro (On Bar)"
                    end
                end
            end
        end
    end
    return "NOT_ON_BAR", "|cFFFBBF24[Created - Drag to Bar]|r", "Pickup Macro to Cursor"
end

-- ============================================================================
-- Role-Smart [DynamicDrink] Recovery Macro & Decoupled Mage Food Restock Engine
-- ============================================================================
do (function()
local CONJURED_MAGE_FOOD_IDS = {
    [113509] = true, -- Conjured Mana Bun
    [80618]  = true, -- Conjured Mana Fritter
    [80610]  = true, -- Conjured Mana Pudding
    [65517]  = true, -- Conjured Mana Lollipop
    [65516]  = true, -- Conjured Mana Cupcake
    [65515]  = true, -- Conjured Mana Brownie
    [65500]  = true, -- Conjured Mana Cookie
    [65499]  = true, -- Conjured Mana Cake
    [43523]  = true, -- Conjured Mana Strudel
    [43518]  = true, -- Conjured Mana Pie
    [34062]  = true, -- Conjured Mana Biscuit
}
local RECUPERATE_SPELL_ID = 1231411

local lastRecoveryScan = nil
local mageFoodToastFrame = nil
local mageFoodRestockSilenced = false
local mageFoodGroupAskSilenced = false
local mageFoodAskCooldownUntil = 0
local mageFoodWasInGroup = false
local mageFoodLeaveAlertedThisRun = false
local mageFoodCheckPending = false
local mageFoodPreviewIdx = 0

local function SafeExtractTooltipLowerText(tipData)
    if type(tipData) ~= "table" or type(tipData.lines) ~= "table" then return "" end
    local parts = {}
    for _, line in ipairs(tipData.lines) do
        if type(line) == "table" then
            if type(line.leftText) == "string" and not IsSecretValue(line.leftText) and line.leftText ~= "" then
                parts[#parts + 1] = line.leftText:lower()
            end
            if type(line.rightText) == "string" and not IsSecretValue(line.rightText) and line.rightText ~= "" then
                parts[#parts + 1] = line.rightText:lower()
            end
        end
    end
    return table.concat(parts, " ")
end

local function IsPlayerInPvPInstance()
    if type(GetInstanceInfo) == "function" then
        local ok, _, instType = pcall(GetInstanceInfo)
        if ok and type(instType) == "string" and not IsSecretValue(instType) then
            if instType == "arena" or instType == "pvp" then
                return true
            end
        end
    end
    if type(IsInInstance) == "function" then
        local okI, inInst, instType = pcall(IsInInstance)
        if okI and not IsSecretValue(inInst) and inInst and type(instType) == "string" and not IsSecretValue(instType) then
            if instType == "arena" or instType == "pvp" then
                return true
            end
        end
    end
    return false
end

local function IsConjuredMageFood(itemID, lowerName, tipText)
    if CONJURED_MAGE_FOOD_IDS[itemID] then return true end
    if type(lowerName) == "string" and lowerName:find("conjured mana", 1, true) then
        return true
    end
    if type(tipText) == "string" and tipText:find("conjured item", 1, true) and tipText:find("mana", 1, true) then
        return true
    end
    return false
end

local function IsBuffFoodItem(itemID, lowerName, tipText, spellLowerName)
    if itemID == 255847 or (itemID >= 255800 and itemID <= 256000) or (itemID >= 222700 and itemID <= 222760) then
        return true
    end
    if type(lowerName) == "string" then
        if lowerName:find("^hearty") or lowerName:find("hearty ", 1, true)
           or lowerName:find("feast", 1, true) or lowerName:find("banquet", 1, true) then
            return true
        end
    end
    if type(spellLowerName) == "string" then
        if spellLowerName:find("well fed", 1, true) or spellLowerName:find("hearty", 1, true) or spellLowerName:find("feast", 1, true) then
            return true
        end
    end
    if type(tipText) == "string" and tipText ~= "" then
        if tipText:find("well fed", 1, true)
           or tipText:find("spend at least", 1, true)
           or tipText:find("persists through death", 1, true) then
            return true
        end
        local hasStatWord = tipText:find("haste", 1, true) or tipText:find("mastery", 1, true)
            or tipText:find("critical strike", 1, true) or tipText:find("versatility", 1, true)
            or tipText:find("stamina", 1, true) or tipText:find("intellect", 1, true)
            or tipText:find("agility", 1, true) or tipText:find("strength", 1, true)
            or tipText:find("primary stat", 1, true) or tipText:find("secondary stat", 1, true)
        if hasStatWord and (tipText:find("gain", 1, true) or tipText:find("increases", 1, true) or tipText:find("for 1 hour", 1, true)) then
            return true
        end
    end
    return false
end

local function IsPvPOnlyFoodOrDrink(lowerName, tipText)
    if type(tipText) == "string" and tipText ~= "" then
        if tipText:find("only usable in arena", 1, true)
           or tipText:find("only usable in battleground", 1, true)
           or tipText:find("usable only in arena", 1, true)
           or tipText:find("usable only in battleground", 1, true)
           or tipText:find("arenas and battlegrounds", 1, true)
           or tipText:find("battlegrounds and arenas", 1, true) then
            return true
        end
        if tipText:find("requires", 1, true) and (tipText:find("arena", 1, true) or tipText:find("battleground", 1, true)) then
            return true
        end
    end
    if type(lowerName) == "string" and (lowerName:find("gladiator", 1, true) or lowerName:find("brawler", 1, true)) then
        return true
    end
    return false
end

local function PickBetterRecoveryItem(cur, cand, inPvP)
    if not cur then return cand end
    if inPvP and cand.isPvPOnly ~= cur.isPvPOnly then
        return cand.isPvPOnly and cand or cur
    end
    if (cand.minLevel or 0) ~= (cur.minLevel or 0) then
        return (cand.minLevel or 0) > (cur.minLevel or 0) and cand or cur
    end
    if (cand.itemLevel or 0) ~= (cur.itemLevel or 0) then
        return (cand.itemLevel or 0) > (cur.itemLevel or 0) and cand or cur
    end
    if (cand.count or 0) ~= (cur.count or 0) then
        return (cand.count or 0) > (cur.count or 0) and cand or cur
    end
    return (cand.itemID or 0) > (cur.itemID or 0) and cand or cur
end

function DynamicPrep:ScanRecoveryConsumables()
    if InCombatLockdown and InCombatLockdown() and lastRecoveryScan then
        return lastRecoveryScan
    end

    local inPvP = IsPlayerInPvPInstance()
    local playerLevel = 80
    if type(UnitLevel) == "function" then
        local okL, lvl = pcall(UnitLevel, "player")
        if okL and type(lvl) == "number" and not IsSecretValue(lvl) and lvl > 0 then
            playerLevel = lvl
        end
    end

    local byID = {}
    if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo then
        for bag = 0, 4 do
            local okS, slots = pcall(C_Container.GetContainerNumSlots, bag)
            slots = (okS and type(slots) == "number" and not IsSecretValue(slots)) and slots or 0
            for slot = 1, slots do
                local okI, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
                if okI and type(info) == "table" and info.itemID and not IsSecretValue(info.itemID) then
                    local itemID = info.itemID
                    local stackCount = (type(info.stackCount) == "number" and not IsSecretValue(info.stackCount)) and info.stackCount or 1
                    local rec = byID[itemID]
                    if rec then
                        rec.count = rec.count + stackCount
                    else
                        local classID, subClassID
                        if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
                            local okInst, _, _, _, _, _, cID, scID = pcall(C_Item.GetItemInfoInstant, itemID)
                            if okInst then
                                classID, subClassID = cID, scID
                            end
                        end
                        if (classID == 0 and subClassID == 5) or CONJURED_MAGE_FOOD_IDS[itemID] then
                            byID[itemID] = {
                                itemID = itemID,
                                bag = bag,
                                slot = slot,
                                count = stackCount,
                                hyperlink = (type(info.hyperlink) == "string" and not IsSecretValue(info.hyperlink)) and info.hyperlink or nil,
                            }
                        end
                    end
                end
            end
        end
    end

    local mageFoodCount = 0
    local manaDrinkCount = 0
    local vendorFoodCount = 0
    local buffFoodCount = 0
    local bestMageFood, bestManaDrink, bestVendorFood, bestBuffFood = nil, nil, nil, nil

    for itemID, rec in pairs(byID) do
        local itemName = rec.hyperlink and rec.hyperlink:match("%[(.-)%]")
        local minLevel, itemLevel = 0, 1
        if C_Item and type(C_Item.GetItemInfo) == "function" then
            local okInfo, iName, _, _, iLvl, iMinLvl = pcall(C_Item.GetItemInfo, itemID)
            if okInfo then
                if (not itemName or itemName == "") and type(iName) == "string" and not IsSecretValue(iName) then
                    itemName = iName
                end
                if type(iLvl) == "number" and not IsSecretValue(iLvl) then itemLevel = iLvl end
                if type(iMinLvl) == "number" and not IsSecretValue(iMinLvl) then minLevel = iMinLvl end
            end
        end
        if (not itemName or itemName == "") and C_Item and type(C_Item.GetItemNameByID) == "function" then
            local okN, n = pcall(C_Item.GetItemNameByID, itemID)
            if okN and type(n) == "string" and not IsSecretValue(n) then itemName = n end
        end
        itemName = itemName or ("Item " .. tostring(itemID))
        local lowerName = itemName:lower()

        if minLevel <= playerLevel then
            local tipText = ""
            if C_TooltipInfo and type(C_TooltipInfo.GetBagItem) == "function" then
                local okT, tData = pcall(C_TooltipInfo.GetBagItem, rec.bag, rec.slot)
                if okT and tData then
                    tipText = SafeExtractTooltipLowerText(tData)
                end
            elseif C_TooltipInfo and type(C_TooltipInfo.GetItemByID) == "function" then
                local okT, tData = pcall(C_TooltipInfo.GetItemByID, itemID)
                if okT and tData then
                    tipText = SafeExtractTooltipLowerText(tData)
                end
            end

            local spellLowerName = ""
            local spellTipText = ""
            if C_Item and type(C_Item.GetItemSpell) == "function" then
                local okSp, sName, sID = pcall(C_Item.GetItemSpell, itemID)
                if okSp then
                    if type(sName) == "string" and not IsSecretValue(sName) then
                        spellLowerName = sName:lower()
                    end
                    if sID and not IsSecretValue(sID) and C_TooltipInfo and type(C_TooltipInfo.GetSpellByID) == "function" then
                        local okST, sData = pcall(C_TooltipInfo.GetSpellByID, sID)
                        if okST and sData then
                            spellTipText = SafeExtractTooltipLowerText(sData)
                        end
                    end
                end
            end

            local combinedTip = tipText .. " " .. spellTipText
            local isPvPOnly = IsPvPOnlyFoodOrDrink(lowerName, combinedTip)
            if not isPvPOnly or inPvP then
                rec.name = itemName
                rec.minLevel = minLevel
                rec.itemLevel = itemLevel
                rec.isPvPOnly = isPvPOnly

                if IsConjuredMageFood(itemID, lowerName, combinedTip) then
                    mageFoodCount = mageFoodCount + rec.count
                    bestMageFood = PickBetterRecoveryItem(bestMageFood, rec, inPvP)
                elseif IsBuffFoodItem(itemID, lowerName, combinedTip, spellLowerName) then
                    buffFoodCount = buffFoodCount + rec.count
                    bestBuffFood = PickBetterRecoveryItem(bestBuffFood, rec, inPvP)
                else
                    local restoresMana = (combinedTip:find("mana", 1, true) ~= nil)
                        or (spellLowerName:find("drink", 1, true) ~= nil)
                        or (lowerName:find("water", 1, true) ~= nil)
                        or (lowerName:find("tea", 1, true) ~= nil)
                        or (lowerName:find("juice", 1, true) ~= nil)
                        or (lowerName:find("milk", 1, true) ~= nil)
                    if restoresMana then
                        manaDrinkCount = manaDrinkCount + rec.count
                        bestManaDrink = PickBetterRecoveryItem(bestManaDrink, rec, inPvP)
                    else
                        vendorFoodCount = vendorFoodCount + rec.count
                        bestVendorFood = PickBetterRecoveryItem(bestVendorFood, rec, inPvP)
                    end
                end
            end
        end
    end

    lastRecoveryScan = {
        mageFoodCount   = mageFoodCount,
        bestMageFood    = bestMageFood,
        manaDrinkCount  = manaDrinkCount,
        bestManaDrink   = bestManaDrink,
        vendorFoodCount = vendorFoodCount,
        bestVendorFood  = bestVendorFood,
        buffFoodCount   = buffFoodCount,
        bestBuffFood    = bestBuffFood,
        inPvP           = inPvP,
    }
    return lastRecoveryScan
end

function DynamicPrep:GetConjuredMageFoodCount()
    if InCombatLockdown and InCombatLockdown() and lastRecoveryScan then
        return lastRecoveryScan.mageFoodCount or 0
    end
    local scan = self:ScanRecoveryConsumables()
    return (scan and scan.mageFoodCount) or 0
end

function DynamicPrep:GetPlayerRole()
    if type(GetSpecialization) ~= "function" or type(GetSpecializationRole) ~= "function" then
        return "DAMAGER"
    end
    local okIdx, idx = pcall(GetSpecialization)
    if not okIdx or type(idx) ~= "number" or IsSecretValue(idx) or idx <= 0 then
        return "DAMAGER"
    end
    local okRole, role = pcall(GetSpecializationRole, idx)
    if okRole and type(role) == "string" and not IsSecretValue(role) and role ~= "" then
        return role
    end
    return "DAMAGER"
end

function DynamicPrep:IsRecuperateKnown()
    local known = false
    if SafeIsPlayerSpellKnown(RECUPERATE_SPELL_ID) then
        known = true
    elseif type(IsSpellKnown) == "function" then
        local okK, k = pcall(IsSpellKnown, RECUPERATE_SPELL_ID)
        if okK and not IsSecretValue(k) and k == true then known = true end
    elseif type(IsPlayerSpell) == "function" then
        local okP, p = pcall(IsPlayerSpell, RECUPERATE_SPELL_ID)
        if okP and not IsSecretValue(p) and p == true then known = true end
    end
    local spellName = "Recuperate"
    if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
        local okS, info = pcall(C_Spell.GetSpellInfo, RECUPERATE_SPELL_ID)
        if okS and type(info) == "table" and type(info.name) == "string" and not IsSecretValue(info.name) and info.name ~= "" then
            spellName = info.name
        end
    end
    return known, spellName
end

function DynamicPrep:ResolveDrinkMacroTarget(scan)
    if not self.db then return nil end
    local mode = self.db.drinkMacroMode or "ROLE_SMART"
    if mode == "OFF" then return nil end

    scan = scan or self:ScanRecoveryConsumables()
    local allowBuff = (self.db.drinkMacroAllowBuffFood == true)
    local recupFallback = (self.db.drinkMacroRecupFallback ~= false)
    local recupKnown, recupName = self:IsRecuperateKnown()
    local role = self:GetPlayerRole()

    local function PickItem(rec, kind)
        if rec and rec.itemID then
            return { kind = "item", itemID = rec.itemID, name = rec.name, bucket = kind }
        end
        return nil
    end
    local function PickRecup()
        if recupFallback and recupKnown then
            return { kind = "spell", spellName = recupName or "Recuperate", name = recupName or "Recuperate", bucket = "RECUP" }
        end
        return nil
    end

    if mode == "MANA_FIRST" then
        return PickItem(scan.bestMageFood, "MAGE")
            or PickItem(scan.bestManaDrink, "DRINK")
            or (allowBuff and PickItem(scan.bestBuffFood, "BUFF"))
            or PickRecup()
    elseif mode == "HEALTH_RECUP" then
        return PickItem(scan.bestMageFood, "MAGE")
            or PickRecup()
            or PickItem(scan.bestVendorFood, "FOOD")
            or (allowBuff and PickItem(scan.bestBuffFood, "BUFF"))
    else
        -- ROLE_SMART
        if role == "HEALER" then
            return PickItem(scan.bestMageFood, "MAGE")
                or PickItem(scan.bestManaDrink, "DRINK")
                or (allowBuff and PickItem(scan.bestBuffFood, "BUFF"))
                or PickRecup()
        else
            return PickItem(scan.bestMageFood, "MAGE")
                or PickItem(scan.bestVendorFood, "FOOD")
                or PickRecup()
                or (allowBuff and PickItem(scan.bestBuffFood, "BUFF"))
        end
    end
end

function DynamicPrep:UpdateDrinkMacro(pickupToCursor)
    if InCombatLockdown and InCombatLockdown() then
        self.pendingDrinkMacroUpdate = true
        if pickupToCursor then
            print(string.format("|cFF%sDynamicPrep:|r Cannot create or pick up [DynamicDrink] while in combat. Queued for combat end.", GetAccentHex()))
        end
        return
    end
    if not self.db then return end

    local mode = self.db.drinkMacroMode or "ROLE_SMART"
    if pickupToCursor and mode == "OFF" then
        mode = "ROLE_SMART"
        self.db.drinkMacroMode = "ROLE_SMART"
    end
    if mode == "OFF" then return end

    local scan = self:ScanRecoveryConsumables()
    local target = self:ResolveDrinkMacroTarget(scan)
    local body
    if target and target.kind == "item" and target.itemID then
        body = string.format("#showtooltip\n/use [nocombat] item:%d", target.itemID)
    elseif target and target.kind == "spell" and target.spellName then
        body = string.format("#showtooltip %s\n/cast [nocombat] %s", target.spellName, target.spellName)
    else
        body = "#showtooltip\n/use [nocombat] item:113509"
    end

    if GetMacroIndexByName then
        local idx = GetMacroIndexByName("DynamicDrink") or 0
        if idx and idx > 0 then
            if EditMacro then
                local _, _, curBody = GetMacroInfo(idx)
                if curBody ~= body then
                    pcall(EditMacro, idx, "DynamicDrink", "INV_Misc_QuestionMark", body)
                end
            end
        elseif CreateMacro then
            local numGlobal = GetNumMacros and select(1, GetNumMacros()) or 0
            if numGlobal < 120 then
                pcall(CreateMacro, "DynamicDrink", "INV_Misc_QuestionMark", body, nil)
            end
        end
    end

    if pickupToCursor and PickupMacro then
        pcall(PickupMacro, "DynamicDrink")
    end
end

function DynamicPrep:GetDrinkMacroActionBarStatus()
    local idx = (GetMacroIndexByName and GetMacroIndexByName("DynamicDrink")) or 0
    if not idx or idx <= 0 then
        return "NOT_CREATED", "|cFFF87171[Not Created]|r", "Create & Pickup Macro"
    end
    if type(_G.GetActionInfo) == "function" then
        for slot = 1, 180 do
            local ok, actionType, id = pcall(_G.GetActionInfo, slot)
            if ok and actionType == "macro" then
                if id == idx then
                    return "ON_BAR", "|cFF34D399[On Action Bar]|r", "Pickup Macro (On Bar)"
                end
                if type(_G.GetActionText) == "function" then
                    local okT, actionName = pcall(_G.GetActionText, slot)
                    if okT and actionName == "DynamicDrink" then
                        return "ON_BAR", "|cFF34D399[On Action Bar]|r", "Pickup Macro (On Bar)"
                    end
                end
            end
        end
    end
    return "NOT_ON_BAR", "|cFFFBBF24[Created - Drag to Bar]|r", "Pickup Macro to Cursor"
end

-- ============================================================================
-- Decoupled Healer Mage Food Restock & Leave Toasts (DynamicPrepMageFoodToast)
-- ============================================================================
function DynamicPrep:MatchesMageFoodScope()
    if not self.db then return false end
    local scope = self.db.mageFoodRestockScope or "HEALER_ONLY"
    local role = self:GetPlayerRole()
    if scope == "HEALER_ONLY" then
        return role == "HEALER"
    end
    if role == "HEALER" then return true end
    if type(UnitPowerMax) == "function" then
        local okM, maxMana = pcall(UnitPowerMax, "player", 0)
        if okM and type(maxMana) == "number" and not IsSecretValue(maxMana) and maxMana > 0 then
            return true
        end
    end
    if type(UnitPowerType) == "function" then
        local okT, pType = pcall(UnitPowerType, "player")
        if okT and not IsSecretValue(pType) and pType == 0 then
            return true
        end
    end
    return false
end

function DynamicPrep:IsInFollowerDungeon()
    if C_LFGInfo and type(C_LFGInfo.IsInLFGFollowerDungeon) == "function" then
        local ok, inFol = pcall(C_LFGInfo.IsInLFGFollowerDungeon)
        if ok and not IsSecretValue(inFol) and inFol == true then
            return true
        end
    end
    if type(_G.IsInLFGFollowerDungeon) == "function" then
        local ok, inFol = pcall(_G.IsInLFGFollowerDungeon)
        if ok and not IsSecretValue(inFol) and inFol == true then
            return true
        end
    end
    if type(GetInstanceInfo) == "function" then
        local okI, _, _, diffID = pcall(GetInstanceInfo)
        if okI and type(diffID) == "number" and not IsSecretValue(diffID) and diffID == 205 then
            return true
        end
    end
    return false
end

function DynamicPrep:IsQueuedInLFD()
    if type(GetLFGMode) == "function" then
        local cat = _G.LE_LFG_CATEGORY_LFD or 1
        local ok, mode = pcall(GetLFGMode, cat)
        if ok and type(mode) == "string" and not IsSecretValue(mode) then
            if mode == "queued" or mode == "proposal" or mode == "rolecheck" or mode == "suspended" then
                return true
            end
        end
    end
    return false
end

function DynamicPrep:FindJoinableFollowerDungeon()
    local cat = _G.LE_LFG_CATEGORY_LFD or 1
    local candidates = {}
    if C_LFGInfo and type(C_LFGInfo.GetAllEntriesForCategory) == "function" then
        local ok, list = pcall(C_LFGInfo.GetAllEntriesForCategory, cat)
        if ok and type(list) == "table" then
            candidates = list
        end
    end
    if #candidates == 0 and type(GetLFDChoiceOrder) == "function" then
        local ok, list = pcall(GetLFDChoiceOrder)
        if ok and type(list) == "table" then
            candidates = list
        end
    end

    for _, dID in ipairs(candidates) do
        if type(dID) == "number" and not IsSecretValue(dID) and dID > 0 then
            local isFol = false
            if C_LFGInfo and type(C_LFGInfo.IsLFGFollowerDungeon) == "function" then
                local okF, f = pcall(C_LFGInfo.IsLFGFollowerDungeon, dID)
                if okF and not IsSecretValue(f) and f == true then isFol = true end
            elseif type(_G.IsLFGFollowerDungeon) == "function" then
                local okF, f = pcall(_G.IsLFGFollowerDungeon, dID)
                if okF and not IsSecretValue(f) and f == true then isFol = true end
            end
            if isFol then
                local joinable = true
                if type(IsLFGDungeonJoinable) == "function" then
                    local okJ, j = pcall(IsLFGDungeonJoinable, dID)
                    if not okJ or IsSecretValue(j) or not j then
                        joinable = false
                    end
                end
                if joinable then
                    local dName = "Follower Dungeon"
                    if type(GetLFGDungeonInfo) == "function" then
                        local okN, name = pcall(GetLFGDungeonInfo, dID)
                        if okN and type(name) == "string" and not IsSecretValue(name) and name ~= "" then
                            dName = name
                        end
                    end
                    return dID, dName
                end
            end
        end
    end
    return nil, nil
end

function DynamicPrep:QueueFirstFollowerDungeon()
    if InCombatLockdown and InCombatLockdown() then
        print(string.format("|cFF%sDynamicPrep:|r Leave combat before queuing for a Follower Dungeon.", GetAccentHex()))
        return false
    end
    local dID, dName = self:FindJoinableFollowerDungeon()
    if not dID then
        print(string.format("|cFF%sDynamicPrep:|r No Follower Dungeon is currently available to queue.", GetAccentHex()))
        return false
    end

    local cat = _G.LE_LFG_CATEGORY_LFD or 1
    local role = self:GetPlayerRole()
    if type(SetLFGRoles) == "function" then
        pcall(SetLFGRoles, false, role == "TANK", role == "HEALER", role ~= "TANK" and role ~= "HEALER")
    end
    if type(ClearAllLFGDungeons) == "function" then
        pcall(ClearAllLFGDungeons, cat)
    end
    if type(SetLFGDungeon) == "function" then
        pcall(SetLFGDungeon, cat, dID)
    elseif type(LFDQueueFrame_SetType) == "function" then
        pcall(LFDQueueFrame_SetType, dID)
    end
    if type(JoinLFG) == "function" then
        pcall(JoinLFG, cat)
    elseif type(JoinSingleLFG) == "function" then
        pcall(JoinSingleLFG, cat, dID)
    end

    self:HideMageFoodToast()
    print(string.format("|cFF%sDynamicPrep:|r Queued for |cFFFFFFFF%s|r (Follower Dungeon) to restock Conjured Mana Buns.", GetAccentHex(), tostring(dName)))
    return true
end

function DynamicPrep:LeaveFollowerDungeon()
    if InCombatLockdown and InCombatLockdown() then
        print(string.format("|cFF%sDynamicPrep:|r Leave combat before exiting the Follower Dungeon.", GetAccentHex()))
        return false
    end
    self:HideMageFoodToast()
    if C_PartyInfo and type(C_PartyInfo.LeaveParty) == "function" then
        pcall(C_PartyInfo.LeaveParty)
    elseif type(LeaveParty) == "function" then
        pcall(LeaveParty)
    end
    print(string.format("|cFF%sDynamicPrep:|r Leaving Follower Dungeon.", GetAccentHex()))
    return true
end

local function GetMageFoodSharedToastStyle()
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

local function StyleMageFoodToastActionBtn(btn, st, isHover)
    if not btn then return end
    st = st or GetMageFoodSharedToastStyle()
    local ar, ag, ab = st.ar, st.ag, st.ab
    local bgMult = isHover and 0.56 or 0.42
    local bdrAlpha = isHover and 1.00 or 0.95
    SetPixelBackdrop(btn, { ar * bgMult, ag * bgMult, ab * bgMult, isHover and 1.00 or 0.98 }, { ar, ag, ab, bdrAlpha }, 1)
    if btn.txt then btn.txt:SetTextColor(1, 1, 1, 1) end
end

function DynamicPrep:ApplyMageFoodToastVisuals()
    local f = mageFoodToastFrame
    if not f then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local st = nil
    if _G.DynamicSuite and type(_G.DynamicSuite.ApplySharedToastLayout) == "function" then
        local ok, sharedSt = pcall(_G.DynamicSuite.ApplySharedToastLayout, f, { toastKind = "ACTION", tintIcon = false })
        if ok and type(sharedSt) == "table" then st = sharedSt end
    end
    if not st then
        st = GetMageFoodSharedToastStyle()
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
        if f.iconBorder then f.iconBorder:SetBackdropBorderColor(ar, ag, ab, 0.85) end
        if f:IsShown() and _G.DynamicSuite and type(_G.DynamicSuite.RestackAllToasts) == "function" then
            pcall(_G.DynamicSuite.RestackAllToasts)
        end
    end
    if f.actionBtn then
        StyleMageFoodToastActionBtn(f.actionBtn, st, f.actionBtn.IsMouseOver and f.actionBtn:IsMouseOver())
    end
end

function DynamicPrep:HideMageFoodToast()
    if not mageFoodToastFrame then return end
    if _G.DynamicSuite and type(_G.DynamicSuite.HideSharedToast) == "function" then
        pcall(_G.DynamicSuite.HideSharedToast, mageFoodToastFrame)
    elseif not (InCombatLockdown and InCombatLockdown()) then
        if mageFoodToastFrame.animGroup then mageFoodToastFrame.animGroup:Stop() end
        mageFoodToastFrame:Hide()
        mageFoodToastFrame:SetAlpha(1)
    end
end

function DynamicPrep:ResetMageFoodSessionState()
    mageFoodRestockSilenced = false
    mageFoodGroupAskSilenced = false
    mageFoodAskCooldownUntil = 0
    mageFoodWasInGroup = false
    mageFoodLeaveAlertedThisRun = false
end

function DynamicPrep:HasConnectedLivingGroupMage()
    if type(UnitClass) ~= "function" then return false end
    local okSelf, _, selfClass = pcall(UnitClass, "player")
    if okSelf and type(selfClass) == "string" and not IsSecretValue(selfClass) and selfClass == "MAGE" then
        return false
    end

    local inRaid = false
    if type(IsInRaid) == "function" then
        local okR, r = pcall(IsInRaid)
        if okR and not IsSecretValue(r) and r == true then inRaid = true end
    end
    local inGroup = inRaid
    if not inGroup and type(IsInGroup) == "function" then
        local okG, g = pcall(IsInGroup)
        if okG and not IsSecretValue(g) and g == true then inGroup = true end
    end
    if not inGroup then return false end

    local function IsUnitConnectedLivingMage(unit)
        if type(UnitExists) ~= "function" then return false end
        local okE, ex = pcall(UnitExists, unit)
        if not okE or IsSecretValue(ex) or not ex then return false end
        if type(UnitIsUnit) == "function" then
            local okU, isSelf = pcall(UnitIsUnit, unit, "player")
            if okU and not IsSecretValue(isSelf) and isSelf == true then return false end
        end
        if type(UnitIsConnected) == "function" then
            local okC, conn = pcall(UnitIsConnected, unit)
            if not okC or IsSecretValue(conn) or not conn then return false end
        end
        if type(UnitIsDeadOrGhost) == "function" then
            local okD, dead = pcall(UnitIsDeadOrGhost, unit)
            if not okD or IsSecretValue(dead) or dead == true then return false end
        end
        local okCl, _, uClass = pcall(UnitClass, unit)
        return (okCl and type(uClass) == "string" and not IsSecretValue(uClass) and uClass == "MAGE")
    end

    if inRaid then
        local count = 40
        if type(GetNumGroupMembers) == "function" then
            local okN, n = pcall(GetNumGroupMembers)
            if okN and type(n) == "number" and not IsSecretValue(n) and n > 0 then
                count = math.min(n, 40)
            end
        end
        for i = 1, count do
            if IsUnitConnectedLivingMage("raid" .. i) then
                return true
            end
        end
    else
        for i = 1, 4 do
            if IsUnitConnectedLivingMage("party" .. i) then
                return true
            end
        end
    end
    return false
end

function DynamicPrep:RequestMageTableInChat()
    if InCombatLockdown and InCombatLockdown() then
        print(string.format("|cFF%sDynamicPrep:|r Leave combat before asking for a Mage table.", GetAccentHex()))
        return false
    end
    if IsInEncounterOrChatLockdown() then
        print(string.format("|cFF%sDynamicPrep:|r Chat messaging is currently locked down; ask your group's Mage manually when free.", GetAccentHex()))
        return false
    end

    local chatType = nil
    if type(IsInGroup) == "function" then
        local okInst, inInstGrp = pcall(IsInGroup, _G.LE_PARTY_CATEGORY_INSTANCE)
        if okInst and not IsSecretValue(inInstGrp) and inInstGrp == true then
            chatType = "INSTANCE_CHAT"
        end
    end
    if not chatType and type(IsInRaid) == "function" then
        local okR, inRaid = pcall(IsInRaid)
        if okR and not IsSecretValue(inRaid) and inRaid == true then
            chatType = "RAID"
        end
    end
    if not chatType and type(IsInGroup) == "function" then
        local okG, inGrp = pcall(IsInGroup)
        if okG and not IsSecretValue(inGrp) and inGrp == true then
            chatType = "PARTY"
        end
    end
    if not chatType then
        print(string.format("|cFF%sDynamicPrep:|r You are not currently in a party or raid.", GetAccentHex()))
        return false
    end

    pcall(SafeSendPrepChatMessage, "Could we grab a Mage table when free, please?", chatType)
    local now = (GetTime and GetTime()) or 0
    mageFoodAskCooldownUntil = now + 300
    self:HideMageFoodToast()
    return true, chatType
end

function DynamicPrep:ShowMageFoodToast(stage, bunCount, targetCount, isPreview)
    if InCombatLockdown and InCombatLockdown() then return end
    if not mageFoodToastFrame then
        local f = nil
        if _G.DynamicSuite and type(_G.DynamicSuite.EnsureSharedToastFrame) == "function" then
            local ok, sharedFrame = pcall(_G.DynamicSuite.EnsureSharedToastFrame, "DynamicPrepMageFoodToast", {
                toastKind = "ACTION",
                clickButtons = { "LeftButtonUp", "RightButtonUp" },
                iconMode = "FULL",
                iconTexture = 134029, -- Conjured Mana Bun icon
                rightActionWidth = 112,
                rightActionGap = 10,
                autoFade = true,
                onRightClickDismiss = function()
                    if mageFoodToastFrame and not mageFoodToastFrame._isPreview then
                        if mageFoodToastFrame._stage == "RESTOCK" then
                            mageFoodRestockSilenced = true
                        elseif mageFoodToastFrame._stage == "ASK_MAGE" then
                            mageFoodGroupAskSilenced = true
                        end
                    end
                    DynamicPrep:HideMageFoodToast()
                end,
            })
            if ok and sharedFrame then f = sharedFrame end
        end

        if not f then
            local stInit = GetMageFoodSharedToastStyle()
            f = CreateFrame("Button", "DynamicPrepMageFoodToast", UIParent, "BackdropTemplate")
            f:SetSize(410, 74)
            f:SetFrameStrata("TOOLTIP")
            f:SetFrameLevel(20)
            f:SetToplevel(false)
            f:SetClampedToScreen(true)
            f:EnableMouse(true)
            f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            f:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = false, tileSize = 0, edgeSize = 1.5,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            local iconBorder = CreateFrame("Frame", nil, f, "BackdropTemplate")
            iconBorder:SetSize(44, 44)
            iconBorder:SetPoint("LEFT", f, "LEFT", 14, 0)
            iconBorder:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = false, tileSize = 0, edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            iconBorder:SetBackdropColor(0.04, 0.05, 0.07, 1)
            local ic = iconBorder:CreateTexture(nil, "ARTWORK")
            ic:SetSize(40, 40)
            ic:SetPoint("CENTER", iconBorder, "CENTER", 0, 0)
            ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            ic:SetTexture(134029)
            f.iconBorder = iconBorder
            f.iconTex = ic

            f.title = CreateText(f, "OVERLAY", "GameFontHighlight")
            f.badge = CreateText(f, "OVERLAY", "GameFontHighlightSmall")
            f.subtext = CreateText(f, "OVERLAY", "GameFontHighlightSmall")

            local ag = f:CreateAnimationGroup()
            local hold = ag:CreateAnimation("Animation")
            local initDur = tonumber(stInit.duration)
            if initDur == nil then initDur = 12 end
            hold:SetDuration((initDur > 0) and initDur or 12)
            hold:SetOrder(1)
            local fade = ag:CreateAnimation("Alpha")
            fade:SetFromAlpha(1)
            fade:SetToAlpha(0)
            fade:SetDuration(1.2)
            fade:SetOrder(2)
            ag:SetScript("OnFinished", function()
                if not (InCombatLockdown and InCombatLockdown()) then
                    f:Hide()
                    f:SetAlpha(1)
                end
            end)
            f.animGroup = ag
            f.holdAnim = hold

            f:SetScript("OnClick", function(_, button)
                if button == "RightButton" then
                    if not f._isPreview then
                        if f._stage == "RESTOCK" then
                            mageFoodRestockSilenced = true
                        elseif f._stage == "ASK_MAGE" then
                            mageFoodGroupAskSilenced = true
                        end
                    end
                    DynamicPrep:HideMageFoodToast()
                end
            end)
            f:SetScript("OnEnter", function()
                if f.animGroup then f.animGroup:Pause() end
                f:SetAlpha(1)
            end)
            f:SetScript("OnLeave", function()
                if f.actionBtn and f.actionBtn.IsMouseOver and f.actionBtn:IsMouseOver() then return end
                local curSt = GetMageFoodSharedToastStyle()
                local leaveDur = tonumber(curSt.duration)
                if leaveDur == nil then leaveDur = 12 end
                if f.animGroup and leaveDur > 0 then f.animGroup:Play() end
            end)
        end

        if not f.actionBtn then
            local actionBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
            actionBtn:SetSize(112, 28)
            actionBtn:SetPoint("RIGHT", f, "RIGHT", -12, 0)
            actionBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            actionBtn.txt = CreateText(actionBtn, "OVERLAY", "GameFontHighlightSmall")
            actionBtn.txt:SetPoint("CENTER")
            actionBtn.txt:SetWordWrap(false)
            actionBtn.txt:SetText("Queue Follower")
            f.actionBtn = actionBtn
        end

        if f.SetRightTextAnchor then
            f.SetRightTextAnchor(f.actionBtn, 10)
        elseif f.title and f.badge and f.subtext then
            f.title:ClearAllPoints()
            f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -11)
            f.title:SetPoint("RIGHT", f.actionBtn, "LEFT", -10, 0)
            f.badge:ClearAllPoints()
            f.badge:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -5)
            f.badge:SetPoint("RIGHT", f.actionBtn, "LEFT", -10, 0)
            f.subtext:ClearAllPoints()
            f.subtext:SetPoint("TOPLEFT", f.badge, "BOTTOMLEFT", 0, -5)
            f.subtext:SetPoint("RIGHT", f.actionBtn, "LEFT", -10, 0)
        end

        mageFoodToastFrame = f
    end

    local f = mageFoodToastFrame
    f._stage = stage
    f._isPreview = (isPreview == true)
    local st = GetMageFoodSharedToastStyle()
    local dur = tonumber(st.duration)
    if dur == nil then dur = 12 end

    local isLeave = (stage == "LEAVE")
    local isAskMage = (stage == "ASK_MAGE")
    f.actionBtn.txt:SetText((isLeave and "Leave Dungeon") or (isAskMage and "Ask for Table") or "Queue Follower")
    f.actionBtn:SetScript("OnEnter", function(s)
        local curSt = GetMageFoodSharedToastStyle()
        if f.animGroup then f.animGroup:Pause() end
        f:SetAlpha(1)
        StyleMageFoodToastActionBtn(s, curSt, true)
    end)
    f.actionBtn:SetScript("OnLeave", function(s)
        local curSt = GetMageFoodSharedToastStyle()
        StyleMageFoodToastActionBtn(s, curSt, false)
        local leaveDur = tonumber(curSt.duration)
        if leaveDur == nil then leaveDur = 12 end
        if not (f.IsMouseOver and f:IsMouseOver()) and f.animGroup and leaveDur > 0 then
            f.animGroup:Play()
        end
    end)
    f.actionBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if not f._isPreview then
                if f._stage == "RESTOCK" then
                    mageFoodRestockSilenced = true
                elseif f._stage == "ASK_MAGE" then
                    mageFoodGroupAskSilenced = true
                end
            end
            DynamicPrep:HideMageFoodToast()
            return
        end
        if f._isPreview then
            DynamicPrep:HideMageFoodToast()
            return
        end
        if isLeave then
            DynamicPrep:LeaveFollowerDungeon()
        elseif isAskMage then
            DynamicPrep:RequestMageTableInChat()
        else
            DynamicPrep:QueueFirstFollowerDungeon()
        end
    end)

    local titleText = isLeave
        and "|cFFCBD5E1Dynamic|r|cFFFFFFFFPrep|r  |cFF475569|||r  |cFF34D399Mage Food Restocked|r"
        or  "|cFFCBD5E1Dynamic|r|cFFFFFFFFPrep|r  |cFF475569|||r  |cFFFBBF24Low Conjured Mana Buns|r"
    local badgeText = isLeave
        and string.format("|cFF94A3B8In Bags:|r |cFFFFFFFF%d|r |cFF64748B(Target: %d)|r", tonumber(bunCount) or 0, tonumber(targetCount) or 20)
        or (isAskMage
            and string.format("|cFF94A3B8In Bags:|r |cFFF87171%d|r |cFF64748B(Below %d)  |  |cFF38BDF8Mage in group|r", tonumber(bunCount) or 0, tonumber(targetCount) or 20)
            or  string.format("|cFF94A3B8In Bags:|r |cFFF87171%d|r |cFF64748B(Alert below %d)|r", tonumber(bunCount) or 0, tonumber(targetCount) or 20))
    local subtextText = isLeave
        and "|cFF34D399Click Leave Dungeon|r |cFF94A3B8to exit|r   |cFF475569|||r   |cFF38BDF8Right-Click|r |cFF94A3B8to dismiss|r"
        or (isAskMage
            and "|cFF34D399Click Ask for Table|r |cFF94A3B8to request|r   |cFF475569|||r   |cFF38BDF8Right-Click|r |cFF94A3B8to silence|r"
            or  "|cFF34D399Click Queue Follower|r |cFF94A3B8for buns|r   |cFF475569|||r   |cFF38BDF8Right-Click|r |cFF94A3B8to silence|r")

    if _G.DynamicSuite and type(_G.DynamicSuite.ShowSharedToast) == "function" then
        local okShown, resShown = pcall(_G.DynamicSuite.ShowSharedToast, f, {
            toastKind = "ACTION",
            title = titleText,
            badge = badgeText,
            subtext = subtextText,
            tintIcon = false,
            autoFade = true,
            playSound = true,
        })
        if okShown and resShown then
            StyleMageFoodToastActionBtn(f.actionBtn, GetMageFoodSharedToastStyle(), false)
            return
        end
    end

    self:ApplyMageFoodToastVisuals()
    f.title:SetText(titleText)
    f.badge:SetText(badgeText)
    f.subtext:SetText(subtextText)
    if f.animGroup then f.animGroup:Stop() end
    f:SetAlpha(1)
    f:Show()
    if _G.DynamicSuite and type(_G.DynamicSuite.RestackAllToasts) == "function" then
        pcall(_G.DynamicSuite.RestackAllToasts)
    else
        f:ClearAllPoints()
        if type(st.pos) == "table" and st.pos.point then
            f:SetPoint(st.pos.point, UIParent, st.pos.relPoint or st.pos.point, st.pos.x or 0, st.pos.y or -140)
        else
            f:SetPoint("TOP", UIParent, "TOP", 0, -140)
        end
    end
    if _G.DynamicSuite and type(_G.DynamicSuite.PlaySharedToastSound) == "function" then
        pcall(_G.DynamicSuite.PlaySharedToastSound)
    end
    if dur > 0 and f.animGroup and f.holdAnim then
        f.holdAnim:SetDuration(dur)
        f.animGroup:Play()
    end
end

function DynamicPrep:CheckMageFoodRestock(triggerReason)
    if not self.db or self.db.mageFoodRestockEnabled == false then
        self:HideMageFoodToast()
        return
    end
    if IsModuleDisabledInSuite("DynamicPrep") then return end
    if InCombatLockdown and InCombatLockdown() then return end

    local bunCount = self:GetConjuredMageFoodCount()
    local minThreshold = tonumber(self.db.mageFoodMinThreshold) or 20
    local leaveTarget = tonumber(self.db.mageFoodLeaveTarget) or 20

    local function HideNonPreviewRestockOrAsk()
        if mageFoodToastFrame and mageFoodToastFrame:IsShown() and not mageFoodToastFrame._isPreview
           and (mageFoodToastFrame._stage == "RESTOCK" or mageFoodToastFrame._stage == "ASK_MAGE") then
            self:HideMageFoodToast()
        end
    end

    if bunCount >= minThreshold then
        mageFoodRestockSilenced = false
        mageFoodGroupAskSilenced = false
    end

    -- Priority 1 (Stage 2): Inside a Follower Dungeon -> prompt to leave once target is reached
    if self:IsInFollowerDungeon() then
        if bunCount >= leaveTarget and not mageFoodLeaveAlertedThisRun then
            mageFoodLeaveAlertedThisRun = true
            self:ShowMageFoodToast("LEAVE", bunCount, leaveTarget, false)
        elseif bunCount < leaveTarget then
            HideNonPreviewRestockOrAsk()
        end
        return
    else
        mageFoodLeaveAlertedThisRun = false
    end

    if not self:MatchesMageFoodScope() then
        HideNonPreviewRestockOrAsk()
        return
    end

    local inGroup = false
    if type(IsInGroup) == "function" then
        local okG, g = pcall(IsInGroup)
        if okG and not IsSecretValue(g) and g == true then inGroup = true end
    end
    if not inGroup and type(IsInRaid) == "function" then
        local okR, r = pcall(IsInRaid)
        if okR and not IsSecretValue(r) and r == true then inGroup = true end
    end
    if not inGroup and mageFoodWasInGroup then
        mageFoodGroupAskSilenced = false
    end
    mageFoodWasInGroup = inGroup

    local inInstance = false
    if type(IsInInstance) == "function" then
        local okI, inInst = pcall(IsInInstance)
        if okI and not IsSecretValue(inInst) and inInst == true then inInstance = true end
    end

    -- Priority 2 (Stage 1): Solo & out of combat, not in group/instance, not queued in LFD
    if not inGroup and not inInstance and not self:IsQueuedInLFD() then
        if bunCount < minThreshold and not mageFoodRestockSilenced then
            self:ShowMageFoodToast("RESTOCK", bunCount, minThreshold, false)
        else
            HideNonPreviewRestockOrAsk()
        end
        return
    end

    -- Priority 3 (Stage 3): In a Party or Raid with a connected living Mage (not active M+)
    if inGroup then
        local isKeyActive = false
        if C_ChallengeMode and type(C_ChallengeMode.IsChallengeModeActive) == "function" then
            local okK, k = pcall(C_ChallengeMode.IsChallengeModeActive)
            if okK and not IsSecretValue(k) and k == true then isKeyActive = true end
        end
        local now = (GetTime and GetTime()) or 0
        if not isKeyActive and bunCount < minThreshold and not mageFoodGroupAskSilenced
           and now >= mageFoodAskCooldownUntil and self:HasConnectedLivingGroupMage() then
            self:ShowMageFoodToast("ASK_MAGE", bunCount, minThreshold, false)
        else
            HideNonPreviewRestockOrAsk()
        end
        return
    end

    HideNonPreviewRestockOrAsk()
end

function DynamicPrep:RequestMageFoodCheck(triggerReason, delaySec)
    if delaySec and delaySec > 0 and C_Timer and C_Timer.After then
        if mageFoodCheckPending then return end
        mageFoodCheckPending = true
        C_Timer.After(delaySec, function()
            mageFoodCheckPending = false
            DynamicPrep:CheckMageFoodRestock(triggerReason or "DEBOUNCED")
        end)
    else
        self:CheckMageFoodRestock(triggerReason or "IMMEDIATE")
    end
end

function DynamicPrep:TriggerMageFoodToastPreview()
    mageFoodPreviewIdx = (mageFoodPreviewIdx % 3) + 1
    local bunCount = self:GetConjuredMageFoodCount()
    if mageFoodPreviewIdx == 1 then
        local minT = (self.db and tonumber(self.db.mageFoodMinThreshold)) or 20
        self:ShowMageFoodToast("RESTOCK", bunCount, minT, true)
    elseif mageFoodPreviewIdx == 2 then
        local leaveT = (self.db and tonumber(self.db.mageFoodLeaveTarget)) or 20
        self:ShowMageFoodToast("LEAVE", math.max(bunCount, leaveT), leaveT, true)
    else
        local minT = (self.db and tonumber(self.db.mageFoodMinThreshold)) or 20
        self:ShowMageFoodToast("ASK_MAGE", bunCount, minT, true)
    end
end

-- ============================================================================
-- Low Durability Shared Alert Toast (DynamicPrepDurabilityToast)
-- ============================================================================
local REPAIR_MOUNT_IDS = { 460, 2237, 280, 284 } -- Grand Expedition Yak, Grizzly Hills Packmaster, Traveler's Tundra Mammoth (A/H)
local durabilityToastFrame = nil
local durabilitySilencedAtPct = nil
local durabilityLastAlertedPct = nil
local durabilityCheckPending = false

function DynamicPrep:GetUsableRepairMount()
    local isOutdoors = true
    if type(IsOutdoors) == "function" then
        local okO, out = pcall(IsOutdoors)
        if okO and not IsSecretValue(out) then
            isOutdoors = (out == true)
        end
    end
    if isOutdoors and type(IsIndoors) == "function" then
        local okI, ind = pcall(IsIndoors)
        if okI and not IsSecretValue(ind) and ind == true then
            isOutdoors = false
        end
    end
    if not isOutdoors then return nil, nil end

    if C_MountJournal and type(C_MountJournal.GetMountInfoByID) == "function" then
        for _, mID in ipairs(REPAIR_MOUNT_IDS) do
            local okM, name, _, _, _, isUsable, _, _, _, _, shouldHideOnChar, isCollected = pcall(C_MountJournal.GetMountInfoByID, mID)
            if okM and isCollected == true and shouldHideOnChar ~= true and isUsable ~= false then
                return mID, (type(name) == "string" and not IsSecretValue(name)) and name or "Repair Mount"
            end
        end
    end
    return nil, nil
end

function DynamicPrep:HandleDurabilityToastAction(mountID)
    if InCombatLockdown and InCombatLockdown() then
        print(string.format("|cFF%sDynamicPrep:|r Leave combat before using that.", GetAccentHex()))
        return
    end
    self:HideDurabilityToast()
    if mountID and C_MountJournal and type(C_MountJournal.SummonByID) == "function" then
        pcall(C_MountJournal.SummonByID, mountID)
    elseif type(ToggleCharacter) == "function" then
        pcall(ToggleCharacter, "PaperDollFrame")
    end
end

function DynamicPrep:ApplyDurabilityToastVisuals()
    local f = durabilityToastFrame
    if not f then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local st = nil
    if _G.DynamicSuite and type(_G.DynamicSuite.ApplySharedToastLayout) == "function" then
        local ok, sharedSt = pcall(_G.DynamicSuite.ApplySharedToastLayout, f, { toastKind = "ACTION", tintIcon = false })
        if ok and type(sharedSt) == "table" then st = sharedSt end
    end
    if not st then
        st = GetMageFoodSharedToastStyle()
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
        if f.iconBorder then f.iconBorder:SetBackdropBorderColor(ar, ag, ab, 0.85) end
        if f:IsShown() and _G.DynamicSuite and type(_G.DynamicSuite.RestackAllToasts) == "function" then
            pcall(_G.DynamicSuite.RestackAllToasts)
        end
    end
    if f.actionBtn then
        StyleMageFoodToastActionBtn(f.actionBtn, st, f.actionBtn.IsMouseOver and f.actionBtn:IsMouseOver())
    end
end

function DynamicPrep:HideDurabilityToast()
    if not durabilityToastFrame then return end
    if _G.DynamicSuite and type(_G.DynamicSuite.HideSharedToast) == "function" then
        pcall(_G.DynamicSuite.HideSharedToast, durabilityToastFrame)
    elseif not (InCombatLockdown and InCombatLockdown()) then
        if durabilityToastFrame.animGroup then durabilityToastFrame.animGroup:Stop() end
        durabilityToastFrame:Hide()
        durabilityToastFrame:SetAlpha(1)
    end
end

function DynamicPrep:ResetDurabilityAlertState()
    durabilitySilencedAtPct = nil
    durabilityLastAlertedPct = nil
end

do
    local function NormalizeErrorMsg(str)
        if type(str) ~= "string" then return nil end
        local s = str:lower():match("^%s*(.-)%s*$")
        if not s or s == "" then return nil end
        s = s:gsub("[%.!]+$", "")
        return s
    end

    local COMBAT_SPAM_MESSAGES = {}
    local MOVEMENT_SPAM_MESSAGES = {}

    local function AddGlobalMsg(tbl, globalKey, fallbackText)
        local gVal = _G[globalKey]
        if type(gVal) == "string" and not _IsSecret(gVal) then
            local n = NormalizeErrorMsg(gVal)
            if n then tbl[n] = true end
        end
        if type(fallbackText) == "string" then
            local nf = NormalizeErrorMsg(fallbackText)
            if nf then tbl[nf] = true end
        end
    end

    for _, pair in ipairs({
        { "ERR_ABILITY_COOLDOWN",            "Ability is not ready yet" },
        { "ERR_SPELL_COOLDOWN",              "Spell is not ready yet" },
        { "ERR_ITEM_COOLDOWN",               "Item is not ready yet" },
        { "SPELL_FAILED_SPELL_IN_PROGRESS",  "Another action is in progress" },
        { "SPELL_FAILED_NOT_READY",          "Not yet recovered" },
        { "ERR_OUT_OF_MANA",                 "Not enough mana" },
        { "ERR_OUT_OF_ENERGY",               "Not enough energy" },
        { "ERR_OUT_OF_RAGE",                 "Not enough rage" },
        { "ERR_OUT_OF_FOCUS",                "Not enough focus" },
        { "ERR_OUT_OF_RUNIC_POWER",          "Not enough runic power" },
        { "ERR_OUT_OF_RUNES",                "Not enough runes" },
        { "ERR_OUT_OF_FURY",                 "Not enough fury" },
        { "ERR_OUT_OF_PAIN",                 "Not enough pain" },
        { "ERR_OUT_OF_INSANITY",             "Not enough insanity" },
        { "ERR_OUT_OF_LUNAR_POWER",          "Not enough astral power" },
        { "ERR_OUT_OF_MAELSTROM",            "Not enough maelstrom" },
        { "ERR_OUT_OF_HOLY_POWER",           "Not enough holy power" },
        { "ERR_OUT_OF_SOUL_SHARDS",          "Not enough soul shards" },
        { "ERR_OUT_OF_CHI",                  "Not enough chi" },
        { "ERR_OUT_OF_COMBO_POINTS",         "That ability requires combo points" },
        { "ERR_OUT_OF_ARCANE_CHARGES",       "Not enough arcane charges" },
        { "ERR_OUT_OF_ESSENCE",              "Not enough essence" },
        { "ERR_OUT_OF_RANGE",                "Out of range" },
        { "SPELL_FAILED_OUT_OF_RANGE",       "Out of range" },
        { "SPELL_FAILED_UNIT_NOT_INFRONT",   "Target needs to be in front of you" },
        { "ERR_BADATTACKFACING",             "You are facing the wrong way" },
        { "ERR_BADATTACKPOS",                "You are too far away" },
        { "ERR_ATTACK_TOO_FAR",              "You are too far away" },
        { "SPELL_FAILED_LINE_OF_SIGHT",      "Target not in line of sight" },
        { "ERR_GENERIC_NO_TARGET",           "You have no target" },
        { "ERR_NO_ATTACK_TARGET",            "There is nothing to attack" },
    }) do
        AddGlobalMsg(COMBAT_SPAM_MESSAGES, pair[1], pair[2])
    end

    for _, pair in ipairs({
        { "SPELL_FAILED_MOVING",             "Can't do that while moving" },
        { "ERR_CANT_DO_THAT_WHILE_MOVING",   "You can't do that while moving" },
        { "ERR_CANT_USE_ITEM_WHILE_MOVING",  "You cannot use that while moving" },
        { "SPELL_FAILED_NOT_MOUNTED",        "You are mounted" },
        { "ERR_NOT_WHILE_MOUNTED",           "You can't do that while mounted" },
        { "ERR_ATTACK_MOUNTED",              "Can't attack while mounted" },
        { "SPELL_FAILED_NOT_ON_MOUNTED",     "You are mounted" },
        { "ERR_TAXIPLAYERALREADYMOUNTED",    "You are already mounted" },
    }) do
        AddGlobalMsg(MOVEMENT_SPAM_MESSAGES, pair[1], pair[2])
    end

    local function SafeGetCVar(name)
        if _G.C_CVar and type(_G.C_CVar.GetCVar) == "function" then
            local ok, v = pcall(_G.C_CVar.GetCVar, name)
            if ok then return v end
        elseif type(_G.GetCVar) == "function" then
            local ok, v = pcall(_G.GetCVar, name)
            if ok then return v end
        end
        return nil
    end

    local function SafeSetCVar(name, val)
        if _G.C_CVar and type(_G.C_CVar.SetCVar) == "function" then
            pcall(_G.C_CVar.SetCVar, name, tostring(val))
        elseif type(_G.SetCVar) == "function" then
            pcall(_G.SetCVar, name, tostring(val))
        end
    end

    function DynamicPrep:GetErrorFilterYieldAddon()
        if _G.DynamicSuite and type(_G.DynamicSuite.GetFeatureAutoYield) == "function" then
            local ok, yielding, addonName, friendlyName = pcall(_G.DynamicSuite.GetFeatureAutoYield, _G.DynamicSuite, "DynamicPrep", "ERROR_FILTER")
            if ok and yielding == true then
                return addonName, friendlyName or addonName
            end
            return nil, nil
        end
        local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
        if type(isLoaded) ~= "function" then return nil, nil end
        for _, other in ipairs({ "ErrorFilter", "ErrorMonster", "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL", "EllesmereUI" }) do
            local okL, loaded = pcall(isLoaded, other)
            if okL and loaded then
                local active = false
                pcall(function()
                    if other == "ErrorFilter" then
                        local efdb = _G.ErrorFilterDB
                        if type(efdb) == "table" and type(efdb.profile) == "table" and efdb.profile.mode == 0 then
                            active = false
                        else
                            active = true
                        end
                    elseif other == "ErrorMonster" then
                        active = true
                    elseif other == "EnhanceQoL" then
                        local edb = _G.EnhanceQoLDB
                        local prof = (type(edb) == "table" and type(edb.profile) == "table") and edb.profile or edb
                        if type(prof) == "table" and (prof.hideErrorText == true or prof.hideErrors == true or prof.hideUIErrors == true or prof.errorFilter == true or prof.muteErrorSpeech == true or prof.hideErrorFrame == true) then
                            active = true
                        end
                    elseif other == "Leatrix_Plus" then
                        local ldb = _G.LeaPlusDB
                        if type(ldb) == "table" and (ldb["HideErrorMessages"] == "On" or ldb["NoErrorFrame"] == "On" or ldb["MuteErrorSpeech"] == "On") then
                            active = true
                        end
                    else
                        local edb = _G.EllesmereUIDB
                        if type(edb) == "table" and (edb.hideErrorMessages == true or edb.hideErrorText == true) then
                            active = true
                        end
                    end
                end)
                if active then
                    local friendly = (other == "Leatrix_Plus" and "Leatrix Plus") or (other:find("^Ellesmere") and "EllesmereUI Quality of Life") or other
                    return other, friendly
                end
            end
        end
        return nil, nil
    end

    local errorFilterFrame = CreateFrame("Frame")
    errorFilterFrame:SetScript("OnEvent", function(_, event, errorType, message)
        if event ~= "UI_ERROR_MESSAGE" then return end
        local function ForwardToBlizzard()
            local uef = _G.UIErrorsFrame
            if not uef then return end
            if type(uef.OnEvent) == "function" then
                pcall(uef.OnEvent, uef, "UI_ERROR_MESSAGE", errorType, message)
            elseif type(uef.AddMessage) == "function" and not _IsSecret(message) and type(message) == "string" then
                pcall(uef.AddMessage, uef, message, 1.0, 0.1, 0.1, 1.0)
            end
        end

        if _IsSecret(errorType) or _IsSecret(message) or type(message) ~= "string" then
            ForwardToBlizzard()
            return
        end
        local db = DynamicPrep.db
        if IsModuleDisabledInSuite("DynamicPrep") or not db or db.errorFilterEnabled ~= true or DynamicPrep:GetErrorFilterYieldAddon() then
            ForwardToBlizzard()
            return
        end

        local okMatch, suppressed = pcall(function()
            local norm = NormalizeErrorMsg(message)
            if not norm then return false end
            if db.errorFilterHideCombatSpam == true and COMBAT_SPAM_MESSAGES[norm] then
                return true
            end
            if db.errorFilterHideMovement == true and MOVEMENT_SPAM_MESSAGES[norm] then
                return true
            end
            return false
        end)
        if okMatch and suppressed == true then
            return
        end
        ForwardToBlizzard()
    end)

    function DynamicPrep:SyncErrorFilterState(forceRestore)
        local db = self.db
        local isDisabled = IsModuleDisabledInSuite("DynamicPrep")
        local isYielding = (self:GetErrorFilterYieldAddon() ~= nil)
        local shouldFilterText = (not forceRestore) and (not isDisabled) and (not isYielding)
            and db and (db.errorFilterEnabled == true)
            and ((db.errorFilterHideCombatSpam == true) or (db.errorFilterHideMovement == true))
        local shouldMuteSpeech = (not forceRestore) and (not isDisabled) and (not isYielding)
            and db and (db.errorFilterEnabled == true) and (db.errorFilterMuteSpeech == true)

        if shouldFilterText then
            if not self._errorFilterHooked and _G.UIErrorsFrame and type(_G.UIErrorsFrame.UnregisterEvent) == "function" then
                pcall(_G.UIErrorsFrame.UnregisterEvent, _G.UIErrorsFrame, "UI_ERROR_MESSAGE")
                self._errorFilterHooked = true
            end
            if _G.C_EventUtils and type(_G.C_EventUtils.IsEventValid) == "function" then
                if _G.C_EventUtils.IsEventValid("UI_ERROR_MESSAGE") then
                    errorFilterFrame:RegisterEvent("UI_ERROR_MESSAGE")
                end
            else
                errorFilterFrame:RegisterEvent("UI_ERROR_MESSAGE")
            end
        else
            errorFilterFrame:UnregisterEvent("UI_ERROR_MESSAGE")
            if self._errorFilterHooked and _G.UIErrorsFrame and type(_G.UIErrorsFrame.RegisterEvent) == "function" then
                pcall(_G.UIErrorsFrame.RegisterEvent, _G.UIErrorsFrame, "UI_ERROR_MESSAGE")
                self._errorFilterHooked = false
            end
        end

        if shouldMuteSpeech then
            if db.errorFilterSavedSpeechCVar == nil then
                local cur = SafeGetCVar("Sound_EnableErrorSpeech")
                if cur ~= nil then
                    db.errorFilterSavedSpeechCVar = tostring(cur)
                end
            end
            local curNow = SafeGetCVar("Sound_EnableErrorSpeech")
            if curNow ~= "0" then
                SafeSetCVar("Sound_EnableErrorSpeech", "0")
            end
        else
            if db and db.errorFilterSavedSpeechCVar ~= nil then
                SafeSetCVar("Sound_EnableErrorSpeech", tostring(db.errorFilterSavedSpeechCVar))
                db.errorFilterSavedSpeechCVar = nil
            end
        end
    end
end

local function SilenceDurabilityToast(f)
    if f and not f._isPreview and f._lowestPct then
        durabilitySilencedAtPct = f._lowestPct
        print(string.format("|cFF%sDynamicPrep:|r Silenced durability alerts until gear drops another 10%% or is repaired.", GetAccentHex()))
    end
    DynamicPrep:HideDurabilityToast()
end

function DynamicPrep:ShowDurabilityToast(lowestPct, avgPct, isPreview)
    if InCombatLockdown and InCombatLockdown() then return end
    if not durabilityToastFrame then
        local f = nil
        if _G.DynamicSuite and type(_G.DynamicSuite.EnsureSharedToastFrame) == "function" then
            local ok, sharedFrame = pcall(_G.DynamicSuite.EnsureSharedToastFrame, "DynamicPrepDurabilityToast", {
                toastKind = "ACTION",
                clickButtons = { "LeftButtonUp", "RightButtonUp" },
                iconMode = "FULL",
                iconTexture = 136241, -- Repair anvil icon
                rightActionWidth = 104,
                rightActionGap = 10,
                autoFade = true,
                onRightClickDismiss = function(selfT)
                    SilenceDurabilityToast(selfT or durabilityToastFrame)
                end,
            })
            if ok and sharedFrame then f = sharedFrame end
        end

        if not f then
            local stInit = GetMageFoodSharedToastStyle()
            f = CreateFrame("Button", "DynamicPrepDurabilityToast", UIParent, "BackdropTemplate")
            f:SetSize(410, 74)
            f:SetFrameStrata("TOOLTIP")
            f:SetFrameLevel(20)
            f:SetToplevel(false)
            f:SetClampedToScreen(true)
            f:EnableMouse(true)
            f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            f:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = false, tileSize = 0, edgeSize = 1.5,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            local iconBorder = CreateFrame("Frame", nil, f, "BackdropTemplate")
            iconBorder:SetSize(44, 44)
            iconBorder:SetPoint("LEFT", f, "LEFT", 14, 0)
            iconBorder:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = false, tileSize = 0, edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            iconBorder:SetBackdropColor(0.04, 0.05, 0.07, 1)
            local ic = iconBorder:CreateTexture(nil, "ARTWORK")
            ic:SetSize(40, 40)
            ic:SetPoint("CENTER", iconBorder, "CENTER", 0, 0)
            ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            ic:SetTexture(136241)
            f.iconBorder = iconBorder
            f.iconTex = ic

            f.title = CreateText(f, "OVERLAY", "GameFontHighlight")
            f.badge = CreateText(f, "OVERLAY", "GameFontHighlightSmall")
            f.subtext = CreateText(f, "OVERLAY", "GameFontHighlightSmall")

            local ag = f:CreateAnimationGroup()
            local hold = ag:CreateAnimation("Animation")
            local initDur = tonumber(stInit.duration)
            if initDur == nil then initDur = 12 end
            hold:SetDuration((initDur > 0) and initDur or 12)
            hold:SetOrder(1)
            local fade = ag:CreateAnimation("Alpha")
            fade:SetFromAlpha(1)
            fade:SetToAlpha(0)
            fade:SetDuration(1.2)
            fade:SetOrder(2)
            ag:SetScript("OnFinished", function()
                if not (InCombatLockdown and InCombatLockdown()) then
                    f:Hide()
                    f:SetAlpha(1)
                end
            end)
            f.animGroup = ag
            f.holdAnim = hold

            f:SetScript("OnClick", function(selfT, button)
                if button == "RightButton" then
                    SilenceDurabilityToast(selfT)
                end
            end)
            f:SetScript("OnEnter", function()
                if f.animGroup then f.animGroup:Pause() end
                f:SetAlpha(1)
            end)
            f:SetScript("OnLeave", function()
                if f.actionBtn and f.actionBtn.IsMouseOver and f.actionBtn:IsMouseOver() then return end
                local curSt = GetMageFoodSharedToastStyle()
                local leaveDur = tonumber(curSt.duration)
                if leaveDur == nil then leaveDur = 12 end
                if f.animGroup and leaveDur > 0 then f.animGroup:Play() end
            end)
        end

        if not f.actionBtn then
            local actionBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
            actionBtn:SetSize(104, 28)
            actionBtn:SetPoint("RIGHT", f, "RIGHT", -12, 0)
            actionBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            actionBtn.txt = CreateText(actionBtn, "OVERLAY", "GameFontHighlightSmall")
            actionBtn.txt:SetPoint("CENTER")
            actionBtn.txt:SetWordWrap(false)
            actionBtn.txt:SetText("Open Gear")
            f.actionBtn = actionBtn
        end

        if f.SetRightTextAnchor then
            f.SetRightTextAnchor(f.actionBtn, 10)
        elseif f.title and f.badge and f.subtext then
            f.title:ClearAllPoints()
            f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -11)
            f.title:SetPoint("RIGHT", f.actionBtn, "LEFT", -10, 0)
            f.badge:ClearAllPoints()
            f.badge:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -5)
            f.badge:SetPoint("RIGHT", f.actionBtn, "LEFT", -10, 0)
            f.subtext:ClearAllPoints()
            f.subtext:SetPoint("TOPLEFT", f.badge, "BOTTOMLEFT", 0, -5)
            f.subtext:SetPoint("RIGHT", f.actionBtn, "LEFT", -10, 0)
        end

        durabilityToastFrame = f
    end

    local f = durabilityToastFrame
    f._lowestPct = tonumber(lowestPct) or 0
    f._isPreview = (isPreview == true)
    local st = GetMageFoodSharedToastStyle()
    local dur = tonumber(st.duration)
    if dur == nil then dur = 12 end

    local mountID = self:GetUsableRepairMount()
    f.actionBtn.txt:SetText(mountID and "Repair Mount" or "Open Gear")
    f.actionBtn:SetScript("OnEnter", function(s)
        local curSt = GetMageFoodSharedToastStyle()
        if f.animGroup then f.animGroup:Pause() end
        f:SetAlpha(1)
        StyleMageFoodToastActionBtn(s, curSt, true)
    end)
    f.actionBtn:SetScript("OnLeave", function(s)
        local curSt = GetMageFoodSharedToastStyle()
        StyleMageFoodToastActionBtn(s, curSt, false)
        local leaveDur = tonumber(curSt.duration)
        if leaveDur == nil then leaveDur = 12 end
        if not (f.IsMouseOver and f:IsMouseOver()) and f.animGroup and leaveDur > 0 then
            f.animGroup:Play()
        end
    end)
    f.actionBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            SilenceDurabilityToast(f)
            return
        end
        if f._isPreview then
            DynamicPrep:HideDurabilityToast()
            return
        end
        DynamicPrep:HandleDurabilityToastAction(mountID)
    end)

    local titleText = "|cFFCBD5E1Dynamic|r|cFFFFFFFFPrep|r  |cFF475569|||r  |cFFF87171Low Gear Durability|r"
    local badgeText = string.format("|cFF94A3B8Lowest Slot:|r |cFFF87171%d%%|r |cFF64748B(Average: %d%%)|r", tonumber(lowestPct) or 0, tonumber(avgPct) or 0)
    local subtextText = mountID
        and "|cFF34D399Click Repair Mount|r |cFF94A3B8to summon|r   |cFF475569|||r   |cFF38BDF8Right-Click|r |cFF94A3B8to silence|r"
        or  "|cFF34D399Click Open Gear|r |cFF94A3B8to inspect|r   |cFF475569|||r   |cFF38BDF8Right-Click|r |cFF94A3B8to silence|r"

    if _G.DynamicSuite and type(_G.DynamicSuite.ShowSharedToast) == "function" then
        local okShown, resShown = pcall(_G.DynamicSuite.ShowSharedToast, f, {
            toastKind = "ACTION",
            title = titleText,
            badge = badgeText,
            subtext = subtextText,
            tintIcon = false,
            autoFade = true,
            playSound = true,
        })
        if okShown and resShown then
            StyleMageFoodToastActionBtn(f.actionBtn, GetMageFoodSharedToastStyle(), false)
            return
        end
    end

    self:ApplyDurabilityToastVisuals()
    f.title:SetText(titleText)
    f.badge:SetText(badgeText)
    f.subtext:SetText(subtextText)
    if f.animGroup then f.animGroup:Stop() end
    f:SetAlpha(1)
    f:Show()
    if _G.DynamicSuite and type(_G.DynamicSuite.RestackAllToasts) == "function" then
        pcall(_G.DynamicSuite.RestackAllToasts)
    else
        f:ClearAllPoints()
        if type(st.pos) == "table" and st.pos.point then
            f:SetPoint(st.pos.point, UIParent, st.pos.relPoint or st.pos.point, st.pos.x or 0, st.pos.y or -140)
        else
            f:SetPoint("TOP", UIParent, "TOP", 0, -140)
        end
    end
    if _G.DynamicSuite and type(_G.DynamicSuite.PlaySharedToastSound) == "function" then
        pcall(_G.DynamicSuite.PlaySharedToastSound)
    end
    if dur > 0 and f.animGroup and f.holdAnim then
        f.holdAnim:SetDuration(dur)
        f.animGroup:Play()
    end
end

function DynamicPrep:CheckDurabilityAlert(triggerReason)
    if not self.db or self.db.durabilityAlertEnabled == false then
        self:HideDurabilityToast()
        return
    end
    if IsModuleDisabledInSuite("DynamicPrep") then return end
    if InCombatLockdown and InCombatLockdown() then return end

    if C_ChallengeMode and type(C_ChallengeMode.IsChallengeModeActive) == "function" then
        local okK, isKey = pcall(C_ChallengeMode.IsChallengeModeActive)
        if okK and not IsSecretValue(isKey) and isKey == true then
            return
        end
    end

    local _, lowest, avg = self:GetDurabilityData()
    local threshold = tonumber(self.db.durabilityAlertThreshold) or 20
    if lowest > threshold then
        durabilitySilencedAtPct = nil
        durabilityLastAlertedPct = nil
        if durabilityToastFrame and durabilityToastFrame:IsShown() and not durabilityToastFrame._isPreview then
            self:HideDurabilityToast()
        end
        return
    end

    if durabilitySilencedAtPct ~= nil then
        if lowest > (durabilitySilencedAtPct - 10) then
            return
        end
        durabilitySilencedAtPct = nil
    end

    local forcePrompt = (triggerReason == "READY_CHECK" or triggerReason == "TOGGLE")
    if not forcePrompt and durabilityLastAlertedPct ~= nil and lowest >= durabilityLastAlertedPct then
        return
    end
    durabilityLastAlertedPct = lowest
    self:ShowDurabilityToast(lowest, avg, false)
end

function DynamicPrep:RequestDurabilityCheck(triggerReason, delaySec)
    if delaySec and delaySec > 0 and C_Timer and C_Timer.After then
        if durabilityCheckPending then return end
        durabilityCheckPending = true
        C_Timer.After(delaySec, function()
            durabilityCheckPending = false
            DynamicPrep:CheckDurabilityAlert(triggerReason or "DEBOUNCED")
        end)
    else
        self:CheckDurabilityAlert(triggerReason or "IMMEDIATE")
    end
end

function DynamicPrep:TriggerDurabilityToastPreview()
    local _, lowest, avg = self:GetDurabilityData()
    local threshold = (self.db and tonumber(self.db.durabilityAlertThreshold)) or 20
    local demoLow = (lowest <= threshold) and lowest or math.max(5, threshold - 5)
    local demoAvg = (lowest <= threshold) and avg or math.min(100, demoLow + 22)
    self:ShowDurabilityToast(demoLow, demoAvg, true)
end
end)() end

-- ============================================================================
-- Conflict Scanner & 1-Click Resolution Engine
-- ============================================================================
local ADDON_DISPLAY_NAMES = {
    ClickableRaidBuffs = "Clickable Raid Buffs (Funki)",
    EnhanceQoL   = "Enhance QoL",
    ErrorFilter  = "ErrorFilter",
    ErrorMonster = "ErrorMonster",
    DialogueUI   = "DialogueUI",
    Immersion    = "Immersion",
    Storyline    = "Storyline",
    AutoTurnIn   = "AutoTurnIn",
    BeQuiet      = "BeQuiet",
    TalkLess     = "TalkLess",
    Scrap        = "Scrap",
    Dejunk       = "Dejunk",
    Leatrix_Plus = "Leatrix Plus",
    ElvUI        = "ElvUI",
    WindTools    = "WindTools",
}

function DynamicPrep:GetFriendlyAddonName(addonName)
    if not addonName then return "Addon" end
    return ADDON_DISPLAY_NAMES[addonName] or addonName:gsub("_", " ")
end

function DynamicPrep:ScanActiveConflicts()
    local results = {}
    for _, addonName in ipairs(DIRECT_CONFLICTS) do
        if IsAddonEnabledForPlayer(addonName) then
            table.insert(results, { addon = addonName, kind = "DIRECT" })
        end
    end
    for _, addonName in ipairs(PARTIAL_CONFLICTS) do
        local isConflict = false
        if addonName == "ElvUI" or addonName == "Leatrix_Plus" or addonName == "EllesmereUI"
            or addonName == "EllesmereUIQoL" or addonName == "EllesmereUI_QoL" or addonName == "EnhanceQoL" then
            if _G.DynamicSuite and type(_G.DynamicSuite.InspectSmartSubModuleConflict) == "function" then
                local ok, subConflict = pcall(_G.DynamicSuite.InspectSmartSubModuleConflict, "DynamicPrep", addonName)
                if ok and subConflict == true then
                    isConflict = true
                end
            end
        elseif IsAddonEnabledForPlayer(addonName) then
            isConflict = true
        end
        if isConflict then
            table.insert(results, { addon = addonName, kind = "PARTIAL" })
        end
    end
    return results
end

function DynamicPrep:DisableAndFreezeConflictAddon(addonName)
    if not addonName then return end
    if AddOns.DisableAddOn then
        pcall(AddOns.DisableAddOn, addonName, UnitName("player"))
        pcall(AddOns.DisableAddOn, addonName)
    end
    _G.DynamicLoadDB = _G.DynamicLoadDB or {}
    _G.DynamicLoadDB.addonStates = _G.DynamicLoadDB.addonStates or {}
    _G.DynamicLoadDB.addonStates[addonName] = "FROZEN"
    local friendly = self:GetFriendlyAddonName(addonName)
    local hex = GetAccentHex()
    print(string.format("|cFF%sDynamicPrep:|r Disabled |cFFFFFFFF%s|r and locked it as |cFF%s[Frozen]|r so zone switches never re-enable it.", hex, friendly, hex))
    self:RefreshWorkspaceView()
end

function DynamicPrep:KeepConflictAddon(addonName)
    local friendly = self:GetFriendlyAddonName(addonName or "EnhanceQoL")
    _G.DynamicSuiteDB = _G.DynamicSuiteDB or {}
    _G.DynamicSuiteDB.disabledModules = _G.DynamicSuiteDB.disabledModules or {}
    _G.DynamicSuiteDB.disabledModules["DynamicPrep"] = true
    if _G.DynamicSuiteDB.global then
        _G.DynamicSuiteDB.global.disabledModules = _G.DynamicSuiteDB.global.disabledModules or {}
        _G.DynamicSuiteDB.global.disabledModules["DynamicPrep"] = true
    end
    if AddOns.DisableAddOn and AddOns.GetAddOnInfo and AddOns.GetAddOnInfo("DynamicPrep") then
        pcall(AddOns.DisableAddOn, "DynamicPrep", UnitName("player"))
        pcall(AddOns.DisableAddOn, "DynamicPrep")
    end
    print(string.format("|cFF%sDynamicPrep:|r Keeping |cFFFFFFFF%s|r active. DynamicPrep has been staged to disable on next reload.", GetAccentHex(), friendly))
    self:RefreshWorkspaceView()
end

function DynamicPrep:EnableAutoYieldHooks()
    if not self.db then return end
    self.db.yieldHooks = true
    print(string.format("|cFF%sDynamicPrep:|r Enabled |cFF34D399Auto-Yield Compatibility|r - overlapping automation yielded while keeping the Top Info Bar & Omni Folio active.", GetAccentHex()))
    self:RefreshWorkspaceView()
end
end

-- ============================================================================
-- Custom Obsidian UI Widget Factory (Dropdowns, Segmented Pills, Sliders, Scrollbar)
-- ============================================================================
do (function()
local activeDropdownMenu = nil
local dropdownClickCatcher = nil
local dropdownMenuSeq = 0

local function EnsureDropdownClickCatcher()
    if dropdownClickCatcher then return dropdownClickCatcher end
    local catcher = CreateFrame("Button", "DynamicPrepDropdownClickCatcher", UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("TOOLTIP")
    catcher:SetFrameLevel(200)
    catcher:EnableMouse(true)
    catcher:RegisterForClicks("AnyDown")
    catcher:SetScript("OnClick", function()
        if activeDropdownMenu and activeDropdownMenu:IsShown() then
            activeDropdownMenu:Hide()
        end
        catcher:Hide()
    end)
    catcher:Hide()
    dropdownClickCatcher = catcher
    return catcher
end

local function CloseActiveDropdown()
    if activeDropdownMenu and activeDropdownMenu:IsShown() then
        activeDropdownMenu:Hide()
    end
    if dropdownClickCatcher then
        dropdownClickCatcher:Hide()
    end
end

local function CloseAllDynamicPrepPopups()
    CloseActiveDropdown()
    if DynamicPrep and DynamicPrep.HideBarPopovers then
        DynamicPrep:HideBarPopovers()
    end
end

local function RegisterDynamicPrepPopupClosers()
    local ui = _G.DynamicSuite and _G.DynamicSuite.UI
    if ui and type(ui.RegisterPopupCloser) == "function" then
        pcall(ui.RegisterPopupCloser, "DynamicPrep", function()
            CloseActiveDropdown()
            DynamicPrep:HideBarPopovers()
        end)
    end
end

DynamicPrep.CloseActiveDropdown = CloseAllDynamicPrepPopups
DynamicPrep.ClosePopups = CloseAllDynamicPrepPopups
RegisterDynamicPrepPopupClosers()

local function StyleObsidianScrollBar(scrollFrame, wsFrame)
    if not scrollFrame then return end
    local sb = scrollFrame.ScrollBar or (scrollFrame.GetName and scrollFrame:GetName() and _G[scrollFrame:GetName() .. "ScrollBar"])
    if sb then
        local upBtn = sb.ScrollUpButton or sb.UpButton or (sb.GetName and sb:GetName() and _G[sb:GetName() .. "ScrollUpButton"])
        local downBtn = sb.ScrollDownButton or sb.DownButton or (sb.GetName and sb:GetName() and _G[sb:GetName() .. "ScrollDownButton"])
        for _, b in ipairs({ upBtn, downBtn }) do
            if b then
                b:Hide()
                b:SetAlpha(0)
                b:SetSize(1, 1)
                b:EnableMouse(false)
            end
        end
        for _, reg in ipairs({ sb:GetRegions() }) do
            if reg and reg.SetAlpha then
                reg:SetAlpha(0)
            end
        end
        sb:Hide()
        sb:SetAlpha(0)
        sb:SetSize(1, 1)
        sb:EnableMouse(false)
    end

    local host = wsFrame or scrollFrame:GetParent() or scrollFrame
    local trackFrame = scrollFrame.obsidianTrackFrame
    if not trackFrame then
        trackFrame = CreateFrame("Frame", nil, host)
        trackFrame:SetWidth(4)
        trackFrame:EnableMouse(true)
        trackFrame:EnableMouseWheel(true)
        trackFrame:SetHitRectInsets(-5, -5, 0, 0)
        local trackBg = trackFrame:CreateTexture(nil, "BACKGROUND")
        trackBg:SetAllPoints(trackFrame)
        trackBg:SetColorTexture(0.035, 0.039, 0.051, 0.70)
        trackFrame.bg = trackBg
        scrollFrame.obsidianTrackFrame = trackFrame
    else
        trackFrame:SetParent(host)
    end

    trackFrame:ClearAllPoints()
    if wsFrame then
        trackFrame:SetPoint("TOPRIGHT", wsFrame, "TOPRIGHT", -6, -54)
        trackFrame:SetPoint("BOTTOMRIGHT", wsFrame, "BOTTOMRIGHT", -6, 12)
    else
        trackFrame:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 8, -2)
        trackFrame:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 8, 2)
    end

    local thumbBtn = scrollFrame.obsidianThumbBtn
    if not thumbBtn then
        thumbBtn = CreateFrame("Button", nil, trackFrame)
        thumbBtn:SetSize(4, 48)
        thumbBtn:SetPoint("TOP", trackFrame, "TOP", 0, 0)
        thumbBtn:EnableMouse(true)
        thumbBtn:EnableMouseWheel(true)
        thumbBtn:SetHitRectInsets(-5, -5, 0, 0)
        local thumbTex = thumbBtn:CreateTexture(nil, "OVERLAY")
        thumbTex:SetAllPoints(thumbBtn)
        thumbTex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
        thumbBtn.tex = thumbTex
        function thumbBtn:SetVertexColor(r, g, b, a)
            if not self.isDragging and not self:IsMouseOver() then
                self.tex:SetColorTexture(r or 0.38, g or 0.45, b or 0.56, a or 0.85)
            end
        end
        scrollFrame.obsidianThumbBtn = thumbBtn
    end

    if host then
        host.sbTrack = trackFrame
        host.sbThumb = thumbBtn
    end

    local function RefreshThumbVisual()
        if thumbBtn.isDragging then
            local ar, ag, ab = GetActiveAccentRGB()
            thumbBtn.tex:SetColorTexture(ar, ag, ab, 1.0)
        elseif thumbBtn:IsMouseOver() then
            local ar, ag, ab = GetActiveAccentRGB()
            thumbBtn.tex:SetColorTexture(ar, ag, ab, 0.92)
        else
            thumbBtn.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
        end
    end

    function scrollFrame:UpdateScrollThumb()
        if self.UpdateScrollChildRect then
            pcall(self.UpdateScrollChildRect, self)
        end
        local child = self:GetScrollChild()
        local viewH = self:GetHeight() or 0
        local contentH = (child and child:GetHeight()) or viewH
        local trackH = trackFrame:GetHeight() or viewH
        if trackH <= 1 or viewH <= 1 then return end
        local maxScroll = math.max(0, contentH - viewH)
        if maxScroll <= 0.5 then
            trackFrame:Hide()
            thumbBtn:Hide()
            if (self:GetVerticalScroll() or 0) ~= 0 then
                self:SetVerticalScroll(0)
            end
            return
        end
        trackFrame:Show()
        thumbBtn:Show()
        local curScroll = math.max(0, math.min(maxScroll, self:GetVerticalScroll() or 0))
        if math.abs((self:GetVerticalScroll() or 0) - curScroll) > 0.5 then
            self:SetVerticalScroll(curScroll)
        end
        local ratio = math.max(0.10, math.min(1, viewH / contentH))
        local thumbH = math.max(28, math.min(trackH, math.floor(trackH * ratio + 0.5)))
        thumbBtn:SetSize(4, thumbH)
        local travel = math.max(1, trackH - thumbH)
        local yOff = -(curScroll / maxScroll) * travel
        thumbBtn:ClearAllPoints()
        thumbBtn:SetPoint("TOP", trackFrame, "TOP", 0, yOff)
        RefreshThumbVisual()
    end

    local function ScrollFromCursor()
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            thumbBtn.isDragging = false
            thumbBtn.grabOffset = nil
            thumbBtn:SetScript("OnUpdate", nil)
            trackFrame:SetScript("OnUpdate", nil)
            RefreshThumbVisual()
            return
        end
        local child = scrollFrame:GetScrollChild()
        local viewH = scrollFrame:GetHeight() or 0
        local contentH = (child and child:GetHeight()) or viewH
        local maxScroll = math.max(0, contentH - viewH)
        if maxScroll <= 0 then return end

        local eff = trackFrame:GetEffectiveScale() or 1
        local _, cy = GetCursorPosition()
        cy = cy / eff
        local top = trackFrame:GetTop()
        local bottom = trackFrame:GetBottom()
        if top and bottom and top > bottom then
            local trackH = top - bottom
            local thumbH = thumbBtn:GetHeight() or 28
            local usableH = math.max(1, trackH - thumbH)
            local grabOff = thumbBtn.grabOffset or (thumbH * 0.5)
            local offsetFromTop = (top - cy) - grabOff
            local ratio = math.max(0, math.min(1, offsetFromTop / usableH))
            scrollFrame:SetVerticalScroll(ratio * maxScroll)
            scrollFrame:UpdateScrollThumb()
        end
    end

    local function HandleWheel(_, delta)
        CloseActiveDropdown()
        local child = scrollFrame:GetScrollChild()
        local viewH = scrollFrame:GetHeight() or 0
        local contentH = (child and child:GetHeight()) or viewH
        local maxScroll = math.max(0, contentH - viewH)
        local cur = scrollFrame:GetVerticalScroll() or 0
        local nextScroll = math.max(0, math.min(maxScroll, cur - (delta * 44)))
        scrollFrame:SetVerticalScroll(nextScroll)
        scrollFrame:UpdateScrollThumb()
    end

    thumbBtn:SetScript("OnEnter", RefreshThumbVisual)
    thumbBtn:SetScript("OnLeave", RefreshThumbVisual)
    thumbBtn:SetScript("OnMouseDown", function(selfBtn, button)
        if button == "LeftButton" then
            CloseActiveDropdown()
            selfBtn.isDragging = true
            local eff = selfBtn:GetEffectiveScale() or 1
            local _, cy = GetCursorPosition()
            cy = cy / eff
            local tTop = selfBtn:GetTop()
            local tH = selfBtn:GetHeight() or 28
            if tTop then
                selfBtn.grabOffset = math.max(0, math.min(tH, tTop - cy))
            else
                selfBtn.grabOffset = tH * 0.5
            end
            RefreshThumbVisual()
            selfBtn:SetScript("OnUpdate", ScrollFromCursor)
        end
    end)
    thumbBtn:SetScript("OnMouseUp", function(selfBtn, button)
        if button == "LeftButton" then
            selfBtn.isDragging = false
            selfBtn.grabOffset = nil
            selfBtn:SetScript("OnUpdate", nil)
            trackFrame:SetScript("OnUpdate", nil)
            RefreshThumbVisual()
        end
    end)
    thumbBtn:SetScript("OnHide", function(selfBtn)
        selfBtn.isDragging = false
        selfBtn.grabOffset = nil
        selfBtn:SetScript("OnUpdate", nil)
        trackFrame:SetScript("OnUpdate", nil)
        RefreshThumbVisual()
    end)
    thumbBtn:SetScript("OnMouseWheel", HandleWheel)

    trackFrame:SetScript("OnMouseDown", function(selfTrack, button)
        if button == "LeftButton" then
            CloseActiveDropdown()
            thumbBtn.isDragging = true
            thumbBtn.grabOffset = (thumbBtn:GetHeight() or 28) * 0.5
            RefreshThumbVisual()
            ScrollFromCursor()
            selfTrack:SetScript("OnUpdate", ScrollFromCursor)
        end
    end)
    trackFrame:SetScript("OnMouseUp", function(selfTrack, button)
        if button == "LeftButton" then
            thumbBtn.isDragging = false
            thumbBtn.grabOffset = nil
            selfTrack:SetScript("OnUpdate", nil)
            thumbBtn:SetScript("OnUpdate", nil)
            RefreshThumbVisual()
        end
    end)
    trackFrame:SetScript("OnHide", function(selfTrack)
        thumbBtn.isDragging = false
        thumbBtn.grabOffset = nil
        selfTrack:SetScript("OnUpdate", nil)
        thumbBtn:SetScript("OnUpdate", nil)
        RefreshThumbVisual()
    end)
    trackFrame:SetScript("OnMouseWheel", HandleWheel)

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", HandleWheel)
    if not scrollFrame._dpScrollHooksDone then
        scrollFrame._dpScrollHooksDone = true
        scrollFrame:HookScript("OnScrollRangeChanged", function(selfSF)
            if selfSF.UpdateScrollThumb then
                selfSF:UpdateScrollThumb()
            end
        end)
        scrollFrame:HookScript("OnVerticalScroll", function(selfSF)
            if selfSF.UpdateScrollThumb then
                selfSF:UpdateScrollThumb()
            end
        end)
    end
end

local function CreateObsidianDropdown(parent, width, optionsProvider, getValue, setValue)
    RegisterDynamicPrepPopupClosers()
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 240, 26)
    SetPixelBackdrop(btn, COLORS.BgElevated, COLORS.BorderStrong, 1)

    btn.label = CreateText(btn, "OVERLAY", "GameFontHighlightSmall")
    btn.label:SetPoint("LEFT", btn, "LEFT", 10, 0)
    btn.label:SetPoint("RIGHT", btn, "RIGHT", -24, 0)
    btn.label:SetJustifyH("LEFT")
    btn.label:SetWordWrap(false)

    btn.chevron = btn:CreateTexture(nil, "OVERLAY")
    btn.chevron:SetSize(12, 12)
    btn.chevron:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    btn.chevron:SetTexture(ICON_CHEVRON_DOWN)
    btn.chevron:SetTexCoord(0, 1, 0, 1)
    if btn.chevron.SetSnapToPixelGrid then
        btn.chevron:SetSnapToPixelGrid(false)
        btn.chevron:SetTexelSnappingBias(0)
    end

    function btn:RefreshValue()
        local ar, ag, ab = GetActiveAccentRGB()
        local isOpen = (activeDropdownMenu and activeDropdownMenu:IsShown() and activeDropdownMenu.owner == btn)
        btn.chevron:SetTexture(isOpen and ICON_CHEVRON_UP or ICON_CHEVRON_DOWN)
        btn.chevron:SetVertexColor(ar, ag, ab, (isOpen or btn:IsMouseOver()) and 1.0 or 0.90)
        local cur = getValue()
        local opts = type(optionsProvider) == "function" and optionsProvider() or optionsProvider
        for _, opt in ipairs(opts) do
            if opt.value == cur then
                btn.label:SetText(opt.label)
                return
            end
        end
        if opts[1] then
            btn.label:SetText(opts[1].label)
        end
    end

    btn:SetScript("OnEnter", function(selfBtn)
        local ar, ag, ab = GetActiveAccentRGB()
        SetPixelBackdrop(selfBtn, COLORS.BgHover, GetAccentColorTable(1.0), 1)
        if selfBtn.chevron then
            selfBtn.chevron:SetVertexColor(ar, ag, ab, 1.0)
        end
    end)
    btn:SetScript("OnLeave", function(selfBtn)
        local isOpen = (activeDropdownMenu and activeDropdownMenu:IsShown() and activeDropdownMenu.owner == selfBtn)
        SetPixelBackdrop(selfBtn, COLORS.BgElevated, isOpen and GetAccentColorTable(1.0) or COLORS.BorderStrong, 1)
        if selfBtn.chevron then
            local ar, ag, ab = GetActiveAccentRGB()
            selfBtn.chevron:SetVertexColor(ar, ag, ab, isOpen and 1.0 or 0.90)
        end
    end)
    if not btn._dpDropdownOnHideHooked then
        btn._dpDropdownOnHideHooked = true
        btn:HookScript("OnHide", function(selfBtn)
            if activeDropdownMenu and activeDropdownMenu.owner == selfBtn then
                CloseActiveDropdown()
            end
        end)
    end

    btn:SetScript("OnClick", function(selfBtn)
        RegisterDynamicPrepPopupClosers()
        if activeDropdownMenu and activeDropdownMenu:IsShown() and activeDropdownMenu.owner == selfBtn then
            CloseActiveDropdown()
            return
        end
        CloseAllDynamicPrepPopups()

        if not selfBtn.menu then
            dropdownMenuSeq = dropdownMenuSeq + 1
            local menuName = "DynamicPrepDropdownPopover" .. tostring(dropdownMenuSeq)
            local menu = CreateFrame("Frame", menuName, UIParent, "BackdropTemplate")
            menu:SetFrameStrata("TOOLTIP")
            menu:SetFrameLevel(220)
            menu:SetClampedToScreen(true)
            menu:EnableMouse(true)
            menu.items = {}
            SafeRegisterUISpecialFrame(menuName)

            local searchWrap = CreateFrame("Frame", nil, menu, "BackdropTemplate")
            searchWrap:SetHeight(24)
            searchWrap:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6)
            searchWrap:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -6, -6)
            SetPixelBackdrop(searchWrap, { 0.035, 0.039, 0.051, 0.98 }, COLORS.BorderSubtle, 1)
            searchWrap:Hide()
            menu.searchWrap = searchWrap

            local searchBox = CreateFrame("EditBox", nil, searchWrap)
            searchBox:SetPoint("TOPLEFT", searchWrap, "TOPLEFT", 8, 0)
            searchBox:SetPoint("BOTTOMRIGHT", searchWrap, "BOTTOMRIGHT", -22, 0)
            searchBox:SetAutoFocus(false)
            searchBox:SetFontObject("GameFontHighlightSmall")
            local activeFont = GetActiveFontPath()
            if activeFont and searchBox.SetFont then
                pcall(searchBox.SetFont, searchBox, activeFont, 11, "")
            end
            table.insert(trackedFontStrings, searchBox)
            menu.searchBox = searchBox

            local searchHint = CreateText(searchWrap, "OVERLAY", "GameFontDisableSmall", 11)
            searchHint:SetPoint("LEFT", searchWrap, "LEFT", 8, 0)
            searchHint:SetText("|cFF64748BFilter options...|r")
            menu.searchHint = searchHint

            local clearBtn = CreateFrame("Button", nil, searchWrap)
            clearBtn:SetSize(16, 16)
            clearBtn:SetPoint("RIGHT", searchWrap, "RIGHT", -4, 0)
            clearBtn.txt = CreateText(clearBtn, "OVERLAY", "GameFontHighlightSmall", 10)
            clearBtn.txt:SetPoint("CENTER")
            clearBtn.txt:SetText("|cFF94A3B8X|r")
            clearBtn:Hide()
            clearBtn:SetScript("OnClick", function()
                searchBox:SetText("")
                searchBox:ClearFocus()
            end)
            menu.clearBtn = clearBtn

            searchBox:SetScript("OnEscapePressed", function(eb)
                eb:ClearFocus()
                CloseActiveDropdown()
            end)
            searchBox:SetScript("OnEnterPressed", function(eb)
                eb:ClearFocus()
            end)

            local sf = CreateFrame("ScrollFrame", nil, menu)
            sf:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6)
            sf:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -6, 6)
            sf:SetClipsChildren(true)
            menu.scrollFrame = sf

            local sc = CreateFrame("Frame", nil, sf)
            sc:SetSize(220, 100)
            sf:SetScrollChild(sc)
            menu.scrollChild = sc
            StyleObsidianScrollBar(sf, nil)
            if sf.obsidianTrackFrame then
                sf.obsidianTrackFrame:ClearAllPoints()
                sf.obsidianTrackFrame:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 4, -2)
                sf.obsidianTrackFrame:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 4, 2)
            end

            local borderOverlay = CreateFrame("Frame", nil, menu, "BackdropTemplate")
            borderOverlay:SetAllPoints(menu)
            borderOverlay:SetFrameStrata("TOOLTIP")
            borderOverlay:SetFrameLevel(230)
            SetPixelBackdrop(borderOverlay, { 0, 0, 0, 0 }, GetAccentColorTable(1.0), 1)
            menu.borderOverlay = borderOverlay

            menu:SetScript("OnHide", function(selfMenu)
                if selfMenu.searchBox then
                    selfMenu.searchBox:SetText("")
                    selfMenu.searchBox:ClearFocus()
                end
                if selfMenu.owner and selfMenu.owner.chevron then
                    selfMenu.owner.chevron:SetTexture(ICON_CHEVRON_DOWN)
                    local r, g, b = GetActiveAccentRGB()
                    selfMenu.owner.chevron:SetVertexColor(r, g, b, 0.95)
                    SetPixelBackdrop(selfMenu.owner, COLORS.BgElevated, COLORS.BorderStrong, 1)
                end
                if dropdownClickCatcher then
                    dropdownClickCatcher:Hide()
                end
            end)
            selfBtn.menu = menu
        end

        local ar, ag, ab = GetActiveAccentRGB()
        local menu = selfBtn.menu
        menu.owner = selfBtn
        SetPixelBackdrop(menu, { 0.043, 0.051, 0.071, 0.99 }, { ar, ag, ab, 1.0 }, 1)
        if menu.borderOverlay then
            SetPixelBackdrop(menu.borderOverlay, { 0, 0, 0, 0 }, { ar, ag, ab, 1.0 }, 1)
        end
        selfBtn.chevron:SetTexture(ICON_CHEVRON_UP)
        selfBtn.chevron:SetVertexColor(1.0, 1.0, 1.0, 1.0)
        SetPixelBackdrop(selfBtn, COLORS.BgElevated, { ar, ag, ab, 1.0 }, 1)

        local rawOpts = type(optionsProvider) == "function" and optionsProvider() or optionsProvider
        local hasSearch = (#rawOpts > 12)
        local sf = menu.scrollFrame
        local sc = menu.scrollChild
        sf:ClearAllPoints()
        if hasSearch then
            menu.searchWrap:Show()
            sf:SetPoint("TOPLEFT", menu.searchWrap, "BOTTOMLEFT", 0, -4)
            sf:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -12, 6)
        else
            menu.searchWrap:Hide()
            sf:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6)
            sf:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -6, 6)
        end

        local function RebuildMenuOptions(filterText)
            for _, item in ipairs(menu.items) do item:Hide() end
            local q = tostring(filterText or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
            if menu.searchHint then menu.searchHint:SetShown(q == "") end
            if menu.clearBtn then menu.clearBtn:SetShown(q ~= "") end

            local cur = getValue()
            local maxOptionW = selfBtn:GetWidth()
            local y = 0
            local shownCount = 0
            for _, opt in ipairs(rawOpts) do
                local plainLbl = tostring(opt.label or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
                if q == "" or plainLbl:find(q, 1, true) then
                    shownCount = shownCount + 1
                    local item = menu.items[shownCount]
                    if not item then
                        item = CreateFrame("Button", nil, sc, "BackdropTemplate")
                        item:SetHeight(26)
                        item.checkTex = item:CreateTexture(nil, "OVERLAY")
                        item.checkTex:SetSize(12, 12)
                        item.checkTex:SetPoint("LEFT", item, "LEFT", 8, 0)
                        item.checkTex:SetTexture(ICON_CHECK)

                        item.text = CreateText(item, "OVERLAY", "GameFontHighlightSmall")
                        item.text:SetPoint("LEFT", item, "LEFT", 24, 0)
                        item.text:SetPoint("RIGHT", item, "RIGHT", -10, 0)
                        item.text:SetJustifyH("LEFT")
                        item.text:SetWordWrap(false)
                        menu.items[shownCount] = item
                    end
                    item:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, y)
                    item:SetPoint("TOPRIGHT", sc, "TOPRIGHT", 0, y)
                    local selected = (opt.value == cur)
                    SetPixelBackdrop(
                        item,
                        selected and COLORS.BgElevated or COLORS.BgSurface,
                        selected and { ar, ag, ab, 0.90 } or COLORS.BorderSubtle,
                        1
                    )
                    item.checkTex:SetVertexColor(ar, ag, ab, 1.0)
                    item.checkTex:SetShown(selected)
                    item.text:SetText((selected and "|cFFFFFFFF" or "|cFFCBD5E1") .. opt.label .. "|r")

                    local tw = (item.text:GetStringWidth() or 120) + 52
                    if tw > maxOptionW then
                        maxOptionW = tw
                    end

                    item:SetScript("OnEnter", function(selfItem)
                        SetPixelBackdrop(selfItem, COLORS.BgHover, { ar, ag, ab, 0.85 }, 1)
                    end)
                    item:SetScript("OnLeave", function(selfItem)
                        SetPixelBackdrop(
                            selfItem,
                            selected and COLORS.BgElevated or COLORS.BgSurface,
                            selected and { ar, ag, ab, 0.90 } or COLORS.BorderSubtle,
                            1
                        )
                    end)
                    local optVal = opt.value
                    item:SetScript("OnClick", function()
                        setValue(optVal)
                        menu:Hide()
                        selfBtn:RefreshValue()
                    end)
                    item:Show()
                    y = y - 28
                end
            end

            local contentH = math.max(26, math.abs(y) - 2)
            local maxVisibleRows = 10
            local viewH = math.min(contentH, maxVisibleRows * 28 - 2)
            local totalW = math.ceil(maxOptionW) + (contentH > viewH and 10 or 0)
            local headerExtra = hasSearch and 28 or 0
            menu:SetSize(totalW, viewH + 12 + headerExtra)
            sc:SetSize(totalW - (hasSearch and 18 or 12), contentH)
            sf:SetVerticalScroll(0)
            if sf.UpdateScrollThumb then
                sf:UpdateScrollThumb()
            end
        end

        menu.searchBox:SetScript("OnTextChanged", function(eb, userInput)
            if userInput then
                RebuildMenuOptions(eb:GetText())
            end
        end)

        RebuildMenuOptions("")

        local catcher = EnsureDropdownClickCatcher()
        catcher:Show()

        menu:ClearAllPoints()
        local btnBottom = selfBtn:GetBottom() or 400
        local menuH = menu:GetHeight() or 160
        if btnBottom < (menuH + 24) then
            menu:SetPoint("BOTTOMRIGHT", selfBtn, "TOPRIGHT", 0, 2)
        else
            menu:SetPoint("TOPRIGHT", selfBtn, "BOTTOMRIGHT", 0, -2)
        end
        menu:Show()
        if sf.UpdateScrollThumb then
            sf:UpdateScrollThumb()
        end
        activeDropdownMenu = menu
    end)

    btn:RefreshValue()
    return btn
end

-- Direction A ("Smart Rule of 4"): Inline Segmented Pills (2 to 4 short options, 26px height, Option 3 Negative Pill Styling & 6-Tier Semantic Underline)
local function IsNegativePillOption(val, label)
    local lbl = tostring(label or ""):upper():gsub("^|C%x%x%x%x%x%x%x%x", ""):gsub("|R", "")
    if lbl ~= "" then
        if lbl == "LOW" or lbl == "FAIR" or lbl == "GOOD" or lbl == "HIGH" or lbl == "ULTRA" or lbl == "ULTRA HIGH" or lbl == "ESSENTIAL" or lbl == "REDUCED" or lbl == "EVERYTHING" then
            return false
        end
        if lbl == "OFF" or lbl == "DISABLED" or lbl == "NONE" or lbl == "MUTED" or lbl == "HIDDEN" or lbl == "NEVER" or lbl == "MANUAL" or lbl == "RESET TO PREVIOUS" or string.find(lbl, "^OFF ") then
            return true
        end
        if val == false then return true end
        local s = tostring(val or ""):upper()
        if s == "OFF" or s == "DISABLED" or s == "NONE" or s == "MUTED" or s == "HIDDEN" or s == "NEVER" or s == "MANUAL" or s == "BLIZZARD_DEFAULT" then
            return true
        end
        return false
    end
    if val == false or val == 0 or val == "0" then return true end
    local s = tostring(val or ""):upper()
    if s == "OFF" or s == "DISABLED" or s == "NONE" or s == "MUTED" or s == "HIDDEN" or s == "NEVER" or s == "MANUAL" or s == "BLIZZARD_DEFAULT" then
        return true
    end
    return false
end


local function GetPillTierUnderlineColor(val, label)
    local lbl = tostring(label or ""):upper():gsub("^|C%x%x%x%x%x%x%x%x", ""):gsub("|R", "")
    -- Tier 0: Off / Disabled / None (Slate-Charcoal pill + Coral-Rose bar #F87171)
    if IsNegativePillOption(val, lbl) then
        return 0.973, 0.443, 0.443, 0.90, true
    end
    -- Tier 1: Low / Essential / 120 Lines / Clear 0% (Cool Ice-Cyan #38BDF8)
    if lbl == "LOW" or lbl == "ESSENTIAL" or lbl == "120 LINES" or lbl:find("^CLEAR") then
        return 0.220, 0.741, 0.973, 0.95, false
    end
    -- Tier 2: Fair / Reduced / 250 Lines / Smoked 45% (Emerald Green #34D399)
    if lbl == "FAIR" or lbl == "REDUCED" or lbl == "250 LINES" or lbl:find("^SMOKED") then
        return 0.204, 0.827, 0.600, 0.95, false
    end
    -- Tier 3: Good / 500 Lines / Obsidian 72% (Warm Amber-Gold #FACC15)
    if lbl == "GOOD" or lbl == "500 LINES" or lbl:find("^OBSIDIAN") then
        return 0.980, 0.800, 0.082, 0.95, false
    end
    -- Tier 4: High / Everything / 1000 Lines / Solid 92% (Vibrant Tangerine #FB923C)
    if lbl == "HIGH" or lbl == "EVERYTHING" or lbl == "1000 LINES" or lbl:find("^SOLID") then
        return 0.984, 0.573, 0.235, 0.95, false
    end
    -- Tier 5: Ultra / Ultra High (Royal Amethyst #C084FC)
    if lbl == "ULTRA" or lbl == "ULTRA HIGH" then
        return 0.753, 0.518, 0.988, 0.95, false
    end
    return nil, nil, nil, nil, false
end

local function CreateSegmentedPills(parent, totalWidth, options, getValue, setValue)
    local count = #options
    local gap = 4
    local baseW = totalWidth or 200
    local minW = math.max(58, math.floor((baseW - gap * (count - 1)) / math.max(1, count)))

    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(baseW, 26)
    container.pills = {}

    for idx, opt in ipairs(options) do
        local p = CreateFrame("Button", nil, container, "BackdropTemplate")
        p:SetHeight(26)

        p.checkTex = p:CreateTexture(nil, "OVERLAY")
        p.checkTex:SetSize(11, 11)
        p.checkTex:SetPoint("LEFT", p, "LEFT", 8, 0)
        p.checkTex:SetTexture(ICON_CHECK)

        p.OffBar = p:CreateTexture(nil, "OVERLAY")
        p.OffBar:SetHeight(1.5)
        p.OffBar:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 1, 1)
        p.OffBar:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -1, 1)
        p.OffBar:SetColorTexture(0.973, 0.443, 0.443, 0.90)
        p.OffBar:Hide()
        p.TierBar = p.OffBar

        p.label = CreateText(p, "OVERLAY", "GameFontHighlightSmall")
        p.label:SetWordWrap(false)
        p.label:SetText(opt.label)

        p.minW = minW
        p.optValue = opt.value
        p.optLabel = opt.label
        p.isNegativeOpt = IsNegativePillOption(opt.value, opt.label)
        p:SetScript("OnEnter", function(selfPill)
            local cur = getValue()
            if selfPill.optValue ~= cur then
                if selfPill.isNegativeOpt then
                    SetPixelBackdrop(selfPill, COLORS.BgHover, { 0.392, 0.455, 0.545, 0.85 }, 1)
                else
                    SetPixelBackdrop(selfPill, COLORS.BgHover, GetAccentColorTable(0.65), 1)
                end
            end
        end)
        p:SetScript("OnLeave", function()
            container:RefreshValue()
        end)
        p:SetScript("OnClick", function()
            CloseActiveDropdown()
            setValue(opt.value)
            container:RefreshValue()
        end)
        container.pills[idx] = p
    end

    function container:LayoutPills()
        local x = 0
        for idx, p in ipairs(self.pills) do
            local isBinOff = (count == 2 and p.optLabel == "Off")
            local isBinOn  = (count == 2 and p.optLabel == "Enabled")
            local btnW
            if isBinOff then
                btnW = 68
            elseif isBinOn then
                btnW = 84
            else
                local strW = (p.label.GetUnboundedStringWidth and p.label:GetUnboundedStringWidth()) or p.label:GetStringWidth() or 0
                if strW < 18 then
                    strW = (#tostring(p.label:GetText() or "") * 6.5)
                end
                btnW = math.max(p.minW or 58, math.ceil(strW + 20))
            end
            p:SetSize(btnW, 26)
            p:ClearAllPoints()
            p:SetPoint("LEFT", self, "LEFT", x, 0)
            x = x + btnW + (idx < #self.pills and gap or 0)
        end
        self:SetSize(math.max(count == 2 and (self.pills[1] and self.pills[1].optLabel == "Off" and 156 or baseW) or baseW, x), 26)
    end

    function container:RefreshValue()
        self:LayoutPills()
        local cur = getValue()
        local ar, ag, ab = GetActiveAccentRGB()
        local fillAlpha = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42
        for _, p in ipairs(self.pills) do
            local active = (p.optValue == cur)
            p.label:ClearAllPoints()
            if active then
                local tr, tg, tb, ta, isNeg = GetPillTierUnderlineColor(p.optValue, p.optLabel)
                if isNeg or p.isNegativeOpt then
                    SetPixelBackdrop(p, { 0.118, 0.141, 0.188, 0.98 }, { 0.392, 0.455, 0.545, 0.90 }, 1)
                    p.OffBar:SetColorTexture(tr or 0.973, tg or 0.443, tb or 0.443, ta or 0.90)
                    p.OffBar:Show()
                    p.label:SetTextColor(0.886, 0.910, 0.941, 1.0)
                else
                    SetPixelBackdrop(p, { ar * fillAlpha, ag * fillAlpha, ab * fillAlpha, 0.98 }, { ar, ag, ab, 0.95 }, 1)
                    if tr then
                        p.OffBar:SetColorTexture(tr, tg, tb, ta)
                        p.OffBar:Show()
                    else
                        p.OffBar:Hide()
                    end
                    p.label:SetTextColor(1, 1, 1, 1)
                end
                p.checkTex:SetColorTexture(1, 1, 1, 0.98)
                p.checkTex:ClearAllPoints()
                p.checkTex:SetPoint("LEFT", p, "LEFT", 8, 0)
                p.checkTex:Hide()
                p.label:SetPoint("LEFT", p, "LEFT", 6, 0); p.label:SetPoint("RIGHT", p, "RIGHT", -6, 0); p.label:SetJustifyH("CENTER")
            else
                p.OffBar:Hide()
                SetPixelBackdrop(p, COLORS.BgElevated, COLORS.BorderStrong, 1)
                p.checkTex:Hide()
                p.label:SetPoint("LEFT", p, "LEFT", 6, 0); p.label:SetPoint("RIGHT", p, "RIGHT", -6, 0); p.label:SetJustifyH("CENTER")
                p.label:SetTextColor(0.75, 0.80, 0.86, 1)
            end
        end
    end

    container:RefreshValue()
    return container
end

local function CreateObsidianSlider(parent, width, minVal, maxVal, stepVal, formatFunc, getValue, setValue)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(256, 26)
    stepVal = stepVal or 1

    local valText = CreateText(holder, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
    valText:SetWidth(52)
    valText:SetJustifyH("RIGHT")
    valText:SetWordWrap(false)

    local slider = CreateFrame("Slider", nil, holder)
    slider:SetPoint("LEFT", holder, "LEFT", 0, 0)
    slider:SetPoint("RIGHT", valText, "LEFT", -10, 0)
    slider:SetHeight(4)
    slider:SetHitRectInsets(0, 0, -10, -10)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(stepVal)
    slider:SetObeyStepOnDrag(false)
    slider:EnableMouse(true)
    slider:EnableMouseWheel(true)

    local hairline = slider:CreateTexture(nil, "BACKGROUND", nil, -1)
    hairline:SetPoint("TOPLEFT", slider, "TOPLEFT", -1, 1)
    hairline:SetPoint("BOTTOMRIGHT", slider, "BOTTOMRIGHT", 1, -1)
    hairline:SetColorTexture(1, 1, 1, 0.14)

    local trackBg = slider:CreateTexture(nil, "BACKGROUND", nil, 0)
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0.035, 0.039, 0.051, 0.98)

    local ar0, ag0, ab0 = GetActiveAccentRGB()
    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", slider, "TOPLEFT", 0, 0)
    fill:SetPoint("BOTTOMLEFT", slider, "BOTTOMLEFT", 0, 0)
    fill:SetWidth(1)
    fill:SetColorTexture(ar0, ag0, ab0, 0.85)
    slider.FillBar = fill

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(6, 14)
    thumb:SetColorTexture(0.97, 0.98, 1.00, 1.0)
    if thumb.SetSnapToPixelGrid then
        thumb:SetSnapToPixelGrid(false)
        thumb:SetTexelSnappingBias(0)
    end
    slider:SetThumbTexture(thumb)

    local isDragging = false
    local lastCommittedValue = nil

    local function SnapValue(v)
        v = math.max(minVal, math.min(maxVal, v or minVal))
        if stepVal and stepVal > 0 then
            v = math.floor(((v - minVal) / stepVal) + 0.5) * stepVal + minVal
        end
        return math.max(minVal, math.min(maxVal, v))
    end

    local function UpdateFillAndThumb(rawVal)
        local r, g, b = GetActiveAccentRGB()
        fill:SetColorTexture(r, g, b, 0.85)
        if isDragging or slider:IsMouseOver() then
            thumb:SetColorTexture(r, g, b, 1.0)
        else
            thumb:SetColorTexture(0.97, 0.98, 1.00, 1.0)
        end
        local v = rawVal or slider:GetValue() or minVal
        local pct = (maxVal > minVal) and ((v - minVal) / (maxVal - minVal)) or 0
        pct = math.max(0, math.min(1, pct))
        local tw = slider:GetWidth()
        if not tw or tw <= 0 then tw = 194 end
        fill:SetWidth(math.max(1, pct * tw))
    end

    function holder:RefreshValue()
        local r, g, b, hex = GetActiveAccentRGB()
        local v = SnapValue(getValue() or minVal)
        lastCommittedValue = v
        slider._suppress = true
        slider:SetValue(v)
        slider._suppress = false
        valText:SetText(string.format("|cFF%s%s|r", hex, formatFunc(v)))
        UpdateFillAndThumb(v)
    end

    slider:SetScript("OnValueChanged", function(selfSlider, value)
        local stepped = SnapValue(value)
        valText:SetText(string.format("|cFF%s%s|r", GetAccentHex(), formatFunc(stepped)))
        UpdateFillAndThumb(value)
        if not selfSlider._suppress and stepped ~= lastCommittedValue then
            lastCommittedValue = stepped
            setValue(stepped)
        end
    end)

    local function UpdateSliderFromCursor()
        if isDragging and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            isDragging = false
            slider:SetScript("OnUpdate", nil)
            holder:RefreshValue()
            return
        end
        local scale = slider:GetEffectiveScale()
        local cx = GetCursorPosition() / scale
        local left, tw = slider:GetLeft(), slider:GetWidth()
        if left and tw and tw > 0 then
            local pct = math.max(0, math.min(1, (cx - left) / tw))
            slider:SetValue(minVal + pct * (maxVal - minVal))
        end
    end

    slider:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            CloseActiveDropdown()
            isDragging = true
            UpdateSliderFromCursor()
            self:SetScript("OnUpdate", UpdateSliderFromCursor)
        end
    end)
    slider:SetScript("OnMouseUp", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
        holder:RefreshValue()
    end)
    slider:SetScript("OnHide", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
        UpdateFillAndThumb()
    end)
    holder:HookScript("OnHide", function()
        isDragging = false
        slider:SetScript("OnUpdate", nil)
        UpdateFillAndThumb()
    end)
    slider:SetScript("OnEnter", function(self)
        UpdateFillAndThumb()
        if GameTooltip then
            local hex = GetAccentHex()
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(string.format("|cFF%sLeft-Click / Drag:|r |cFFE2E8F0Adjust value|r", hex))
            GameTooltip:AddLine(string.format("|cFF%sMousewheel:|r |cFFE2E8F0Fine-tune by 1 step|r", hex))
            GameTooltip:Show()
        end
    end)
    slider:SetScript("OnLeave", function()
        UpdateFillAndThumb()
        if GameTooltip then GameTooltip:Hide() end
    end)
    slider:SetScript("OnMouseWheel", function(_, delta)
        CloseActiveDropdown()
        local cur = getValue() or minVal
        local newVal = SnapValue(cur + (delta > 0 and stepVal or -stepVal))
        lastCommittedValue = newVal
        setValue(newVal)
        holder:RefreshValue()
    end)
    slider:SetScript("OnSizeChanged", function()
        UpdateFillAndThumb()
    end)

    holder:HookScript("OnShow", function(s) C_Timer.After(0, function() s:RefreshValue() end) end)
    holder:RefreshValue()
    return holder
end

local function CreateSpaciousRow(parent, topOffset, titleText, subtitleText, rightReserveWidth)
    local reserve = (rightReserveWidth or 260) + 30
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(56)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, topOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, topOffset)
    SetPixelBackdrop(row, COLORS.BgSurface, COLORS.BorderSubtle, 1)

    row.title = CreateText(row, "OVERLAY", "GameFontHighlight")
    row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -9)
    row.title:SetPoint("RIGHT", row, "RIGHT", -reserve, 0)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    row.title:SetText(titleText)

    row.subtitle = CreateText(row, "OVERLAY", "GameFontDisableSmall")
    row.subtitle:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
    row.subtitle:SetPoint("RIGHT", row, "RIGHT", -reserve, 0)
    row.subtitle:SetJustifyH("LEFT")
    row.subtitle:SetWordWrap(true); if row.subtitle.SetMaxLines then row.subtitle:SetMaxLines(2) end
    row.subtitle:SetText(subtitleText)
    row.desc = row.subtitle

    function row:BindRightControl(ctrl)
        if not ctrl then return end
        ctrl:ClearAllPoints()
        ctrl:SetPoint("RIGHT", row, "RIGHT", -14, 0)
        row.title:ClearAllPoints()
        row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -9)
        row.title:SetPoint("RIGHT", ctrl, "LEFT", -16, 0)
        row.subtitle:ClearAllPoints()
        row.subtitle:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
        row.subtitle:SetPoint("RIGHT", ctrl, "LEFT", -16, 0)
    end

    row:SetScript("OnEnter", function(selfRow)
        SetPixelBackdrop(selfRow, COLORS.BgElevated, COLORS.BorderStrong, 1)
    end)
    row:SetScript("OnLeave", function(selfRow)
        SetPixelBackdrop(selfRow, COLORS.BgSurface, COLORS.BorderSubtle, 1)
    end)

    return row
end

-- Hybrid Inline Sub-Drawer (2px Left Suite Accent Rail + Crisp 5x5 Square Pip)
local function CreateInlineSubDrawer(parent, labelText)
    local drawer = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    drawer:SetHeight(42)
    SetPixelBackdrop(drawer, COLORS.BgVoid, COLORS.BorderSubtle, 1)

    -- 2px vertical Suite Accent rail on the left edge
    local leftRail = drawer:CreateTexture(nil, "OVERLAY")
    leftRail:SetWidth(2)
    leftRail:SetPoint("TOPLEFT", drawer, "TOPLEFT", 0, -1)
    leftRail:SetPoint("BOTTOMLEFT", drawer, "BOTTOMLEFT", 0, 1)
    drawer.leftRail = leftRail

    -- Crisp 5x5 square Suite Accent bullet texture (zero ASCII branch characters)
    local pip = drawer:CreateTexture(nil, "OVERLAY")
    pip:SetSize(5, 5)
    pip:SetPoint("LEFT", drawer, "LEFT", 14, 0)
    drawer.pip = pip

    drawer.title = CreateText(drawer, "OVERLAY", "GameFontHighlightSmall")
    drawer.title:SetPoint("LEFT", pip, "RIGHT", 10, 0)
    drawer.title:SetJustifyH("LEFT")
    drawer.title:SetWordWrap(false)
    drawer.title:SetText("|cFFCBD5E1" .. labelText .. "|r")

    function drawer:BindRightControl(ctrl)
        if not ctrl then return end
        ctrl:ClearAllPoints()
        ctrl:SetPoint("RIGHT", drawer, "RIGHT", -14, 0)
        drawer.title:SetPoint("RIGHT", ctrl, "LEFT", -16, 0)
    end

    function drawer:RefreshBranchAccent()
        local ar, ag, ab = GetActiveAccentRGB()
        if self.leftRail then
            self.leftRail:SetColorTexture(ar, ag, ab, 0.95)
        end
        self.pip:SetColorTexture(ar, ag, ab, 0.90)
    end

    drawer:RefreshBranchAccent()
    return drawer
end

-- ============================================================================
-- Collapsible Sub-Drawer Group & Full-Width Horizontal Chevron Toggle Bar (DESIGN_SYSTEM.md Section 2.6)
-- ============================================================================
local function CreateSubDrawerToggleBar(parent, arg2, isVisibleGetter, isExpandedGetter, onToggle)
    local subCount = 1
    local visGetter = isVisibleGetter
    local expGetter = isExpandedGetter
    local toggleFn  = onToggle

    if type(arg2) == "number" then
        subCount = arg2
    elseif type(arg2) == "function" then
        visGetter = arg2
        expGetter = isVisibleGetter
        toggleFn  = isExpandedGetter
        subCount  = tonumber(onToggle) or 1
    elseif type(arg2) == "table" and type(isVisibleGetter) == "function" then
        subCount = 1
    end

    local parentCard = (parent and parent.GetParent and parent:GetParent()) or parent
    local bar = CreateFrame("Button", nil, parentCard, "BackdropTemplate")
    bar:SetHeight(24)
    bar:EnableMouse(true)
    bar:RegisterForClicks("AnyUp")

    local label = CreateText(bar, "OVERLAY", "GameFontHighlightSmall", 11)
    label:SetPoint("CENTER", bar, "CENTER", 8, 0)
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    label:SetText(string.format("Sub-Settings (%d)", subCount))
    bar.label = label

    local chev = bar:CreateTexture(nil, "OVERLAY")
    chev:SetSize(11, 11)
    chev:SetPoint("RIGHT", label, "LEFT", -6, 0)
    chev:SetTexture(ICON_CHEVRON_DOWN)
    chev:SetTexCoord(0, 1, 0, 1)
    if chev.SetSnapToPixelGrid then
        chev:SetSnapToPixelGrid(false)
        chev:SetTexelSnappingBias(0)
    end
    bar.chevron = chev
    bar.chevronTex = chev
    bar.chevTex = chev
    bar.Chevron = chev

    function bar:RefreshValue()
        local isVisible = visGetter and visGetter() or false
        if not isVisible then
            self:Hide()
            return
        end
        self:Show()
        local open = expGetter and expGetter() or false
        local ar, ag, ab = GetActiveAccentRGB()
        local fillAlpha = ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42)
        label:SetText(string.format("Sub-Settings (%d)", subCount))
        if open then
            SetPixelBackdrop(
                self,
                { ar * (fillAlpha * 0.60), ag * (fillAlpha * 0.60), ab * (fillAlpha * 0.60), 0.96 },
                { ar, ag, ab, 0.95 },
                1
            )
            chev:SetTexture(ICON_CHEVRON_UP)
            chev:SetVertexColor(1.0, 1.0, 1.0, 1.0)
            label:SetTextColor(1.0, 1.0, 1.0, 1.0)
        else
            SetPixelBackdrop(
                self,
                { 0.078, 0.090, 0.122, 0.96 },
                { 0.145, 0.165, 0.212, 0.95 },
                1
            )
            chev:SetTexture(ICON_CHEVRON_DOWN)
            chev:SetVertexColor(ar, ag, ab, 0.95)
            label:SetTextColor(0.84, 0.89, 0.96, 1.0)
        end
    end

    bar:SetScript("OnEnter", function(selfBar)
        local ar, ag, ab = GetActiveAccentRGB()
        local fillAlpha = ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42)
        SetPixelBackdrop(
            selfBar,
            { ar * (fillAlpha + 0.10), ag * (fillAlpha + 0.10), ab * (fillAlpha + 0.10), 0.98 },
            { ar, ag, ab, 1.0 },
            1
        )
        selfBar.label:SetTextColor(1.0, 1.0, 1.0, 1.0)
        selfBar.chevron:SetVertexColor(1.0, 1.0, 1.0, 1.0)
    end)
    bar:SetScript("OnLeave", function(selfBar)
        selfBar:RefreshValue()
    end)
    bar:SetScript("OnClick", function()
        CloseActiveDropdown()
        if toggleFn then
            toggleFn()
        end
    end)

    if parent and parent.tuneBtn == nil and parent.GetObjectType and parent:GetObjectType() == "Frame" then
        parent.tuneBtn = bar
    end

    bar:RefreshValue()
    return bar
end
local CreateTuneDrawerButton = CreateSubDrawerToggleBar

-- ============================================================================
-- Workspace Builder (Embedded Live HUD Stage, Tactile Drag-and-Drop & Sub-Drawers)
-- ============================================================================
function DynamicPrep:MoveSegmentOrder(segKey, delta)
    if not self.db or not self.db.segmentOrder then return end
    local order = self.db.segmentOrder
    for i, k in ipairs(order) do
        if k == segKey then
            local targetIdx = i + delta
            if targetIdx >= 1 and targetIdx <= #order then
                order[i], order[targetIdx] = order[targetIdx], order[i]
                self:RefreshBar()
                self:RefreshWorkspaceView()
            end
            return
        end
    end
end

function DynamicPrep:MoveCustomSecondaryOrder(statKey, delta)
    if not self.db or not self.db.customSecondaryOrder then return end
    local order = self.db.customSecondaryOrder
    for i, k in ipairs(order) do
        if k == statKey then
            local targetIdx = i + delta
            if targetIdx < 1 then
                targetIdx = #order
            elseif targetIdx > #order then
                targetIdx = 1
            end
            order[i], order[targetIdx] = order[targetIdx], order[i]
            self:RefreshBar()
            self:RefreshWorkspaceView()
            return
        end
    end
end

function DynamicPrep:LayoutPillGrid()
    local ws = self.workspaceFrame
    if not ws or not ws.pillStrip or not ws.pillCards then return end
    local gridW = ws.pillStrip:GetWidth()
    if not gridW or gridW < 240 then
        gridW = 660
    end
    local padX, padY, gapX, gapY = 8, 8, 8, 6
    local cellW = math.floor((gridW - padX * 2 - gapX * 2) / 3)
    local cellH = 32
    for idx = 1, #ws.pillCards do if idx > #DEFAULT_SEGMENT_ORDER then ws.pillCards[idx]:Hide() end end; for idx = 1, #DEFAULT_SEGMENT_ORDER do
        local pCard = ws.pillCards[idx]
        if pCard then
            local rowIdx = math.floor((idx - 1) / 3)
            local colIdx = (idx - 1) % 3
            pCard:ClearAllPoints()
            pCard:SetSize(cellW, cellH)
            pCard:SetPoint("TOPLEFT", ws.pillStrip, "TOPLEFT", padX + colIdx * (cellW + gapX), -(padY + rowIdx * (cellH + gapY)))
        end
    end
end

function DynamicPrep:EnsureDragGhostPill()
    if self.dragGhostPill then return self.dragGhostPill end
    local ghost = CreateFrame("Frame", "DynamicPrepDragGhostPill", UIParent, "BackdropTemplate")
    ghost:SetSize(210, 32)
    ghost:SetFrameStrata("TOOLTIP")
    ghost:SetFrameLevel(50)
    ghost:SetScale(1.06)
    ghost.label = CreateText(ghost, "OVERLAY", "GameFontHighlightSmall")
    ghost.label:SetPoint("CENTER")
    ghost.label:SetWordWrap(false)
    ghost:Hide()
    self.dragGhostPill = ghost
    return ghost
end

function DynamicPrep:RefreshLiveStagePreview()
    local ws = self.workspaceFrame
    if not ws or not self.db then return end
    if ws.posScreenBtn and ws.posScreenBtn.txt then
        local ar, ag, ab, hex = GetActiveAccentRGB()
        if ws.posScreenBtn.icon then ws.posScreenBtn.icon:SetVertexColor(ar, ag, ab, 1.0) end
        SetPixelBackdrop(ws.posScreenBtn, self.inEditMode and { ar, ag, ab, 0.22 } or COLORS.BgElevated, { ar, ag, ab, 0.90 }, 1)
        ws.posScreenBtn.txt:SetText(self.inEditMode and string.format("|cFF%sLock Bar Position|r", hex) or "Position on Screen")
    end
end

-- ============================================================================
-- Hybrid L-Bracket Section Header Factory (Section 2.4 / Design System - Design A 36px 2-Line Tall L-Bracket)
-- ============================================================================
local function CreateSectionHeader(parent, arg2, arg3, arg4, arg5)
    local text, yOffset, subtitleText, padOverride
    if type(arg2) == "number" then
        yOffset = arg2
        text = arg3
    else
        text = arg2
        yOffset = arg3
    end
    if type(arg4) == "number" then
        padOverride = arg4
        subtitleText = nil
    else
        subtitleText = arg4
        padOverride = arg5
    end

    local hasSub = (type(subtitleText) == "string" and subtitleText ~= "")
    local padX = padOverride or parent.innerPadX or 0
    local hdr = CreateFrame("Frame", nil, parent)
    hdr:SetHeight(hasSub and 36 or 20)
    local y = yOffset or 0
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
    hdr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -padX, y)

    local ar, ag, ab = GetActiveAccentRGB()
    local leftBar = hdr:CreateTexture(nil, "ARTWORK")
    leftBar:SetSize(3, hasSub and 34 or 16)
    leftBar:SetPoint("TOPLEFT", hdr, "TOPLEFT", 0, -1)
    leftBar:SetColorTexture(ar, ag, ab, 1.0)
    hdr.leftBar = leftBar

    local botLine = hdr:CreateTexture(nil, "ARTWORK")
    botLine:SetHeight(1)
    botLine:SetPoint("TOPLEFT", leftBar, "BOTTOMLEFT", 0, 0)
    botLine:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
    botLine:SetColorTexture(ar, ag, ab, 0.35)
    hdr.botLine = botLine

    local title = CreateText(hdr, "OVERLAY", "GameFontHighlight", 11, "")
    if hasSub then
        title:SetPoint("TOPLEFT", leftBar, "TOPRIGHT", 8, 0)
    else
        title:SetPoint("LEFT", leftBar, "RIGHT", 8, 0)
    end
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetTextColor(ar, ag, ab, 1.0)
    title:SetText(string.upper(text or ""))
    hdr.title = title

    local subtitle = CreateText(hdr, "OVERLAY", "GameFontNormalSmall", 10, "")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    subtitle:SetPoint("RIGHT", hdr, "RIGHT", -12, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetWordWrap(false)
    subtitle:SetTextColor(0.64, 0.70, 0.78, 1.0)
    subtitle:SetText(subtitleText or "")
    subtitle:SetShown(hasSub)
    hdr.subtitle = subtitle

    function hdr:SetText(newText, newSubtitle)
        if self.title then
            self.title:SetText(string.upper(newText or ""))
        end
        if newSubtitle ~= nil and self.subtitle then
            local subOk = (type(newSubtitle) == "string" and newSubtitle ~= "")
            self.subtitle:SetText(newSubtitle or "")
            self.subtitle:SetShown(subOk)
            self:SetHeight(subOk and 36 or 20)
            if self.leftBar then self.leftBar:SetSize(3, subOk and 34 or 16) end
        end
    end

    function hdr:RefreshAccent()
        local r, g, b = GetActiveAccentRGB()
        if self.leftBar then self.leftBar:SetColorTexture(r, g, b, 1.0) end
        if self.botLine then self.botLine:SetColorTexture(r, g, b, 0.35) end
        if self.title then self.title:SetTextColor(r, g, b, 1.0) end
        if self.subtitle then self.subtitle:SetTextColor(0.64, 0.70, 0.78, 1.0) end
    end

    table.insert(trackedAccentTexts, {
        fs = {
            SetTextColor = function(_, r, g, b, a)
                hdr:RefreshAccent()
            end
        }
    })

    return hdr
end
DynamicPrep.CreateSectionHeader = CreateSectionHeader

function DynamicPrep:RefreshReadinessTrackerStrip()
    local ws = self.workspaceFrame
    if not ws or not ws:IsShown() then return end
    local strip = ws.readinessStrip
    if not strip or not strip.slots or not strip:IsShown() then return end

    local expThresholdSec = ((self.db and self.db.raidBuffs and tonumber(self.db.raidBuffs.expireThresholdMin)) or 5) * 60
    local _, classFile = UnitClass("player")
    local bgSurf = (COLORS and COLORS.BgSurface) or { 0.055, 0.068, 0.095, 0.96 }
    local brdSub = (COLORS and COLORS.BorderSubtle) or { 1, 1, 1, 0.08 }
    local brdGold = (COLORS and COLORS.Gold) or { 0.984, 0.749, 0.141, 0.85 }

    -- 1. Slot 1: Class Raid Buff & In-Combat Battle-Rez Tracker (Mark of the Wild / Fortitude / Intellect / etc.)
    local sRaid = strip.slots.raidBuff
    if sRaid and sRaid.icon and sRaid.title and sRaid.sub then
        local cDef = (CLASS_RAID_BUFFS and classFile and CLASS_RAID_BUFFS[classFile])
            or (CLASS_RAID_BUFFS and CLASS_RAID_BUFFS.DRUID)
            or { spellID = 1126, name = "Mark of the Wild", icon = 136078 }
        local isClassBuffKnown = (CLASS_RAID_BUFFS and classFile and CLASS_RAID_BUFFS[classFile] and IsClassRaidBuffKnown(cDef)) and true or false
        sRaid.icon:SetTexture(cDef.icon or 136078)
        sRaid.title:SetText(cDef.name or "Mark of the Wild")
        if isClassBuffKnown and self.ScanCombatRaidBuffStatus then
            local sum = (IsPlayerInCombat() and self._lastCombatBuffSummary) or self:ScanCombatRaidBuffStatus(expThresholdSec)
            if sum and sum.missingCount and sum.missingCount > 0 then
                local act = sum.activeCount or 0
                local tot = math.max(1, sum.totalEligible or 1)
                sRaid.sub:SetText(string.format("|cFFF87171%d/%d MISSING|r", act, tot))
                SetPixelBackdrop(sRaid, { 0.085, 0.045, 0.055, 0.96 }, { 0.973, 0.443, 0.443, 0.90 }, 1)
                sRaid._ttTitle = (cDef.name or "Class Raid Buff") .. " (Missing)"
                sRaid._ttBody = string.format(
                    "%s\n%d/%d living eligible group members buffed.",
                    sum.alertText or "Missing Raid Buff",
                    act,
                    tot
                )
            else
                local act = (sum and sum.activeCount) or 1
                local tot = (sum and math.max(1, sum.totalEligible or 1)) or 1
                sRaid.sub:SetText(string.format("|cFF34D399Active (%d/%d Buffed)|r", act, tot))
                SetPixelBackdrop(sRaid, bgSurf, { 0.204, 0.827, 0.600, 0.75 }, 1)
                sRaid._ttTitle = (cDef.name or "Class Raid Buff") .. " (Active)"
                sRaid._ttBody = string.format("All %d/%d living eligible group members have %s.\nAutomatically displays the X/Y + MISSING icon on the Readiness Tracker Strip during combat if a living group member is missing the buff.", act, tot, cDef.name or "Class Raid Buff")
            end
        else
            sRaid.sub:SetText("|cFF94A3B8Passive / Class N/A|r")
            SetPixelBackdrop(sRaid, bgSurf, brdSub, 1)
            sRaid._ttTitle = "Class Raid Buff & Brez Tracker"
            sRaid._ttBody = "Automatically tracks Mark of the Wild (1126) and class raid buffs, displaying the X/Y + MISSING icon on the Readiness Tracker Strip during combat."
        end
    end

    -- 2. Slot 2: Symbiotic Relationship / Partner Link Tracker
    local sPartner = strip.slots.partnerBuff
    if sPartner and sPartner.icon and sPartner.title and sPartner.sub then
        local pList = PARTNER_RAID_BUFFS and classFile and PARTNER_RAID_BUFFS[classFile]
        local pDef = (pList and pList[1])
            or (PARTNER_RAID_BUFFS and PARTNER_RAID_BUFFS.DRUID and PARTNER_RAID_BUFFS.DRUID[1])
            or { spellID = 474750, name = "Symbiotic Relationship", icon = 136063 }
        local spellIcon = (pDef.spellID and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(pDef.spellID)) or pDef.icon or 136063
        sPartner.icon:SetTexture(spellIcon)
        sPartner.title:SetText(pDef.name or "Symbiotic Relationship")

        local inGroup = ((IsInRaid and IsInRaid()) or (IsInGroup and IsInGroup())) and true or false
        if pDef.spellID == 474750 and SafeIsPlayerSpellKnown(474750) and self.ValidateAndScanSymbioticBond then
            local isBonded, bondedUnit, bondedColored, bondRem, isExp = self:ValidateAndScanSymbioticBond(expThresholdSec)
            if isBonded and bondedColored then
                if isExp then
                    local mins = math.max(1, math.ceil((bondRem or 60) / 60))
                    sPartner.sub:SetText(string.format("|cFFFBBF24Linked: %s (%dm)|r", bondedColored, mins))
                    SetPixelBackdrop(sPartner, bgSurf, brdGold, 1)
                else
                    sPartner.sub:SetText(string.format("|cFF34D399Linked:|r %s", bondedColored))
                    SetPixelBackdrop(sPartner, { 0.040, 0.080, 0.068, 0.96 }, { 0.204, 0.827, 0.600, 0.90 }, 1)
                end
                sPartner._ttTitle = "Symbiotic Relationship (Active)"
                sPartner._ttBody = string.format(
                    "Linked: %s (%s)\nVerified via multi-ID bond aura scan (474750 / 474754) + player sourceUnit check.\nAutomatically invalidates if the bonded ally dies, leaves the group, or loses the aura.",
                    bondedColored,
                    tostring(bondedUnit or "ally")
                )
            elseif inGroup then
                sPartner.sub:SetText("|cFFF87171Missing|r")
                SetPixelBackdrop(sPartner, { 0.085, 0.045, 0.055, 0.96 }, { 0.973, 0.443, 0.443, 0.90 }, 1)
                sPartner._ttTitle = "Symbiotic Relationship (Missing)"
                sPartner._ttBody = "No active Symbiotic Relationship bond detected on any living group member.\nCast Symbiotic Relationship on your Tank or Healer ally."
            else
                sPartner.sub:SetText("|cFF94A3B8Missing (Group Required)|r")
                SetPixelBackdrop(sPartner, bgSurf, brdSub, 1)
                sPartner._ttTitle = "Symbiotic Relationship"
                sPartner._ttBody = "Join a party or raid to link Symbiotic Relationship with a Tank or ally."
            end
        elseif pList and pDef.spellID and SafeIsPlayerSpellKnown(pDef.spellID) then
            if inGroup then
                sPartner.sub:SetText("|cFF38BDF8Smart Role Target Active|r")
            else
                sPartner.sub:SetText("|cFF94A3B8Standby (Group)|r")
            end
            SetPixelBackdrop(sPartner, bgSurf, brdSub, 1)
            sPartner._ttTitle = pDef.name or "Partner Buff"
            sPartner._ttBody = "Tracks your active partner buff across party and raid members."
        else
            sPartner.sub:SetText("|cFF94A3B8Symbiotic / Partner Link|r")
            SetPixelBackdrop(sPartner, bgSurf, brdSub, 1)
            sPartner._ttTitle = "Symbiotic Relationship & Partner Buffs"
            sPartner._ttBody = "Tracks Symbiotic Relationship (474750 / 474754), Source of Magic, Earth Shield, and Beacons on linked group allies."
        end
    end

    -- 3. Slot 3: Exact Food Buff Stat Benefit Tracker
    local sFood = strip.slots.foodBuff
    if sFood and sFood.icon and sFood.title and sFood.sub and self.GetActiveFoodBuffBenefit then
        local hasFood, shortStat, fullLine, rem, isHearty, cachedEntry = self:GetActiveFoodBuffBenefit()
        if hasFood and shortStat then
            local coloredShortStat = DynamicPrep:FormatColoredFoodBenefit(shortStat)
            sFood.icon:SetTexture((cachedEntry and cachedEntry.icon) or 136000)
            sFood.title:SetText(isHearty and "Hearty Well Fed" or "Well Fed")
            local isExp = (rem and rem > 0 and rem <= expThresholdSec) and true or false
            if isExp then
                local mins = math.max(1, math.ceil(rem / 60))
                sFood.sub:SetText(string.format("%s |cFFFBBF24(%dm)|r", coloredShortStat, mins))
                SetPixelBackdrop(sFood, bgSurf, brdGold, 1)
            else
                sFood.sub:SetText((coloredShortStat ~= shortStat) and coloredShortStat or ("|cFF34D399" .. shortStat .. "|r"))
                SetPixelBackdrop(sFood, { 0.040, 0.080, 0.068, 0.96 }, { 0.204, 0.827, 0.600, 0.90 }, 1)
            end
            sFood._ttTitle = (isHearty and "Hearty Well Fed" or "Well Fed") .. " (" .. coloredShortStat .. ")"
            local remStr = (rem and rem > 0 and rem < 90000) and string.format("\nRemaining: %d min", math.max(1, math.ceil(rem / 60))) or ""
            sFood._ttBody = tostring(fullLine or ("Active Food Benefit: " .. coloredShortStat)) .. remStr
        else
            sFood.icon:SetTexture(134019)
            sFood.title:SetText("Food Buff (Well Fed)")
            sFood.sub:SetText("|cFFF87171Missing|r")
            SetPixelBackdrop(sFood, { 0.085, 0.045, 0.055, 0.96 }, { 0.973, 0.443, 0.443, 0.90 }, 1)
            sFood._ttTitle = "Food Buff (Missing)"
            sFood._ttBody = "No Well Fed or Hearty Well Fed aura detected.\nWhen active, parses exact live stat benefits (e.g. +445 Intellect, +615 Mastery) from your buff tooltip."
        end
    end
end

function DynamicPrep:CreateEditHudButton(parent, targetKey, fallbackFn)
    if _G.DynamicSuite and type(_G.DynamicSuite.CreateEditHudButton) == "function" then
        return _G.DynamicSuite.CreateEditHudButton(parent, targetKey, function()
            if _G.DynamicSuite and type(_G.DynamicSuite.EnterHudEditMode) == "function" then
                _G.DynamicSuite.EnterHudEditMode(targetKey)
            elseif fallbackFn then
                fallbackFn()
            end
        end)
    end
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(86, 22)
    local ar0, ag0, ab0 = GetActiveAccentRGB()
    SetPixelBackdrop(btn, { 0.043, 0.051, 0.071, 0.96 }, { ar0, ag0, ab0, 0.85 }, 1)
    btn.txt = CreateText(btn, "OVERLAY", "GameFontHighlightSmall", 11, "Edit HUD")
    btn.txt:SetPoint("CENTER")
    btn.txt:SetTextColor(0.976, 0.984, 1.0, 1.0)
    btn:SetScript("OnEnter", function(s)
        local ar, ag, ab = GetActiveAccentRGB()
        SetPixelBackdrop(s, { ar * 0.22, ag * 0.22, ab * 0.22, 0.98 }, { ar, ag, ab, 1.0 }, 1)
    end)
    btn:SetScript("OnLeave", function(s)
        local ar, ag, ab = GetActiveAccentRGB()
        SetPixelBackdrop(s, { 0.043, 0.051, 0.071, 0.96 }, { ar, ag, ab, 0.85 }, 1)
    end)
    btn:SetScript("OnClick", function()
        if _G.DynamicSuite and type(_G.DynamicSuite.EnterHudEditMode) == "function" then
            _G.DynamicSuite.EnterHudEditMode(targetKey)
        elseif fallbackFn then
            fallbackFn()
        end
    end)
    return btn
end

local function BuildRaidBuffsTab(self, ws)
    if ws.tab2 then return ws.tab2 end

    self.db.raidBuffs = DeepCopyDefaults(DEFAULTS.raidBuffs, self.db.raidBuffs or {})

    local tab2 = CreateFrame("Frame", nil, ws.scrollChild)
    tab2:SetPoint("TOPLEFT", ws.scrollChild, "TOPLEFT", 0, 0)
    tab2:SetPoint("TOPRIGHT", ws.scrollChild, "TOPRIGHT", 0, 0)
    tab2:SetHeight(744)
    ws.tab2 = tab2

    local cBuffs = CreateFrame("Frame", nil, tab2, "BackdropTemplate")
    cBuffs:SetPoint("TOPLEFT", tab2, "TOPLEFT", 0, 0)
    cBuffs:SetPoint("TOPRIGHT", tab2, "TOPRIGHT", 0, 0)
    cBuffs:SetHeight(728)
    SetPixelBackdrop(cBuffs, COLORS.BgCanvas, COLORS.BorderStrong, 1)
    ws.raidBuffsCard = cBuffs

    local cbHdr = CreateSectionHeader(
        cBuffs, -10,
        "CLICKABLE RAID BUFFS & CONSUMABLE HUD",
        "1-click reminders, Symbiotic tank-link detection, exact Food Buff stat parser, and In-Combat Brez / MotW tracker.",
        14
    )
    local cbEditHudBtn = self:CreateEditHudButton(cBuffs, "prepBuffs", function()
        self:SetEditMode(true)
    end)
    cbEditHudBtn:SetPoint("TOPRIGHT", cBuffs, "TOPRIGHT", -14, -7)
    ws.raidBuffsEditHudBtn = cbEditHudBtn
    cbHdr.title:SetPoint("RIGHT", cbEditHudBtn, "LEFT", -10, 0)
    cbHdr.title:SetWordWrap(false)
    if cbHdr.subtitle then
        cbHdr.subtitle:SetPoint("RIGHT", cbEditHudBtn, "LEFT", -10, 0)
    end

    -- Live 3-Slot Readiness Status Strip (Raid Buff / Brez | Symbiotic Partner Link | Exact Food Buff Stat)
    local readinessStrip = CreateFrame("Frame", nil, cBuffs)
    readinessStrip:SetHeight(48)
    readinessStrip:SetPoint("TOPLEFT", cBuffs, "TOPLEFT", 14, -52)
    readinessStrip:SetPoint("TOPRIGHT", cBuffs, "TOPRIGHT", -14, -52)
    ws.readinessStrip = readinessStrip
    readinessStrip.slots = {}

    local slotKeys = { "raidBuff", "partnerBuff", "foodBuff" }
    for idx, sKey in ipairs(slotKeys) do
        local slot = CreateFrame("Frame", nil, readinessStrip, "BackdropTemplate")
        slot:SetHeight(46)
        slot:EnableMouse(true)
        SetPixelBackdrop(slot, COLORS.BgSurface, COLORS.BorderSubtle, 1)

        slot.iconBox = CreateFrame("Frame", nil, slot, "BackdropTemplate")
        slot.iconBox:SetSize(30, 30)
        slot.iconBox:SetPoint("LEFT", slot, "LEFT", 8, 0)
        SetPixelBackdrop(slot.iconBox, COLORS.BgVoid, COLORS.BorderStrong, 1)

        slot.icon = slot.iconBox:CreateTexture(nil, "ARTWORK")
        slot.icon:SetPoint("TOPLEFT", slot.iconBox, "TOPLEFT", 1, -1)
        slot.icon:SetPoint("BOTTOMRIGHT", slot.iconBox, "BOTTOMRIGHT", -1, 1)
        slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        slot.icon:SetTexture(134400)

        slot.title = CreateText(slot, "OVERLAY", "GameFontHighlightSmall", 10, "")
        slot.title:SetPoint("TOPLEFT", slot.iconBox, "TOPRIGHT", 8, -1)
        slot.title:SetPoint("RIGHT", slot, "RIGHT", -6, 0)
        slot.title:SetJustifyH("LEFT")
        slot.title:SetWordWrap(false)

        slot.sub = CreateText(slot, "OVERLAY", "GameFontNormalSmall", 10, "")
        slot.sub:SetPoint("BOTTOMLEFT", slot.iconBox, "BOTTOMRIGHT", 8, 1)
        slot.sub:SetPoint("RIGHT", slot, "RIGHT", -6, 0)
        slot.sub:SetJustifyH("LEFT")
        slot.sub:SetWordWrap(false)

        slot:SetScript("OnEnter", function(selfSlot)
            if not GameTooltip or not selfSlot._ttTitle then return end
            local ar, ag, ab = GetActiveAccentRGB()
            GameTooltip:SetOwner(selfSlot, "ANCHOR_TOP")
            GameTooltip:AddLine(selfSlot._ttTitle, ar, ag, ab)
            if selfSlot._ttBody and selfSlot._ttBody ~= "" then
                GameTooltip:AddLine(selfSlot._ttBody, 0.85, 0.90, 0.96, true)
            end
            GameTooltip:Show()
        end)
        slot:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)

        readinessStrip.slots[sKey] = slot
    end

    local function ReflowReadinessSlots()
        local w = readinessStrip:GetWidth()
        if not w or w < 120 then
            w = (cBuffs:GetWidth() or 700) - 28
        end
        local gap = 8
        local sw = math.floor((w - (gap * 2)) / 3)
        local s1 = readinessStrip.slots.raidBuff
        local s2 = readinessStrip.slots.partnerBuff
        local s3 = readinessStrip.slots.foodBuff
        if s1 and s2 and s3 then
            s1:ClearAllPoints()
            s1:SetPoint("TOPLEFT", readinessStrip, "TOPLEFT", 0, 0)
            s1:SetSize(sw, 46)

            s2:ClearAllPoints()
            s2:SetPoint("LEFT", s1, "RIGHT", gap, 0)
            s2:SetSize(sw, 46)

            s3:ClearAllPoints()
            s3:SetPoint("LEFT", s2, "RIGHT", gap, 0)
            s3:SetPoint("TOPRIGHT", readinessStrip, "TOPRIGHT", 0, 0)
            s3:SetHeight(46)
        end
    end
    readinessStrip:SetScript("OnSizeChanged", ReflowReadinessSlots)
    ReflowReadinessSlots()

    -- Row 1: Enable Clickable Raid Buffs HUD
    local rEnable = CreateSpaciousRow(
        cBuffs, -112,
        "Enable Clickable Raid Buffs HUD",
        "Displays clickable 1-click reminder icons on screen when your Class Raid Buff, Weapon Oil, Flask, or Food is missing.",
        200
    )
    local pEnable = CreateSegmentedPills(
        rEnable, 200,
        {
            { value = false, label = "Off" },
            { value = true,  label = "Enabled" },
        },
        function() return self.db.raidBuffs.enabled and true or false end,
        function(v)
            self.db.raidBuffs.enabled = v
            self:RefreshClickableBuffs(true)
        end
    )
    rEnable:BindRightControl(pEnable)
    table.insert(self.refreshWidgets, pEnable)

    -- Row 2: Active Content Scope
    local rScope = CreateSpaciousRow(
        cBuffs, -172,
        "Active Content Scope",
        "Choose where Clickable Raid Buffs actively scans and prompts for missing buffs and consumables.",
        336
    )
    local pScope = CreateSegmentedPills(
        rScope, 336,
        {
            { value = "ALWAYS",        label = "Always" },
            { value = "GROUP_OR_INST", label = "Groups & Instances" },
            { value = "INST_ONLY",     label = "Instances Only" },
        },
        function() return self.db.raidBuffs.scope or "ALWAYS" end,
        function(v)
            self.db.raidBuffs.scope = v
            self:RefreshClickableBuffs(true)
        end
    )
    rScope:BindRightControl(pScope)
    table.insert(self.refreshWidgets, pScope)

    -- Row 3: Track Class & Partner Raid Buffs
    local rClass = CreateSpaciousRow(
        cBuffs, -232,
        "Class & Partner Raid Buffs (Smart Role Target)",
        "Scans group members for Raid Buffs (Mark of the Wild, etc.) and Partner Buffs (Symbiotic Relationship, Source of Magic, Earth Shield, Beacons).",
        200
    )
    local pClass = CreateSegmentedPills(
        rClass, 200,
        {
            { value = false, label = "Off" },
            { value = true,  label = "Enabled" },
        },
        function() return self.db.raidBuffs.trackClassBuffs ~= false end,
        function(v)
            self.db.raidBuffs.trackClassBuffs = v
            self:RefreshClickableBuffs(true)
        end
    )
    rClass:BindRightControl(pClass)
    table.insert(self.refreshWidgets, pClass)

    -- Row 4: In-Combat Battle-Rez & Missing Raid Buff Readiness Strip Override
    local rBrez = CreateSpaciousRow(
        cBuffs, -292,
        "In-Combat Brez & Missing Raid Buff Tracker",
        "Shows your missing Class Raid Buff icon (e.g. 16/17 + MISSING) on the Readiness Tracker Strip during combat while keeping consumables suppressed.",
        200
    )
    local pBrez = CreateSegmentedPills(
        rBrez, 200,
        {
            { value = false, label = "Off" },
            { value = true,  label = "Enabled" },
        },
        function() return self.db.raidBuffs.trackCombatBrez ~= false end,
        function(v)
            self.db.raidBuffs.trackCombatBrez = v
            self:RefreshCombatBuffAlert()
            if self.RefreshReadinessTrackerStrip then
                pcall(self.RefreshReadinessTrackerStrip, self)
            end
        end
    )
    rBrez:BindRightControl(pBrez)
    table.insert(self.refreshWidgets, pBrez)

    -- Row 5: Track Weapon Oils & Stones
    local rOil = CreateSpaciousRow(
        cBuffs, -352,
        "Weapon Oils & Stones (1-Click Auto-Apply)",
        "1-Click auto-applies your best owned Weapon Oil or Whetstone directly to your Main-Hand weapon (Right-Click for Off-Hand).",
        200
    )
    local pOil = CreateSegmentedPills(
        rOil, 200,
        {
            { value = false, label = "Off" },
            { value = true,  label = "Enabled" },
        },
        function() return self.db.raidBuffs.trackWeaponEnchants ~= false end,
        function(v)
            self.db.raidBuffs.trackWeaponEnchants = v
            self:RefreshClickableBuffs(true)
        end
    )
    rOil:BindRightControl(pOil)
    table.insert(self.refreshWidgets, pOil)

    -- Row 6: Track Flasks & Phials
    local rFlask = CreateSpaciousRow(
        cBuffs, -412,
        "Flasks & Phials (Fleeting & Quality Badges)",
        "Tracks owned Flasks (prioritising Fleeting flasks from cauldrons) and shows Midnight Rank 1 Silver vs Rank 2 Gold quality badges.",
        200
    )
    local pFlask = CreateSegmentedPills(
        rFlask, 200,
        {
            { value = false, label = "Off" },
            { value = true,  label = "Enabled" },
        },
        function() return self.db.raidBuffs.trackFlasks ~= false end,
        function(v)
            self.db.raidBuffs.trackFlasks = v
            self:RefreshClickableBuffs(true)
        end
    )
    rFlask:BindRightControl(pFlask)
    table.insert(self.refreshWidgets, pFlask)

    -- Row 7: Track Well Fed / Hearty Food
    local rFood = CreateSpaciousRow(
        cBuffs, -472,
        "Well Fed & Hearty Food Reminder (Exact Stat Parser)",
        "Prompts to eat when missing Well Fed and parses exact stat benefits (e.g. +445 Intellect, +615 Mastery) directly from your buff tooltip.",
        200
    )
    local pFood = CreateSegmentedPills(
        rFood, 200,
        {
            { value = false, label = "Off" },
            { value = true,  label = "Enabled" },
        },
        function() return self.db.raidBuffs.trackFood ~= false end,
        function(v)
            self.db.raidBuffs.trackFood = v
            self:RefreshClickableBuffs(true)
        end
    )
    rFood:BindRightControl(pFood)
    table.insert(self.refreshWidgets, pFood)

    -- Row 8: Track Augment Runes
    local rRune = CreateSpaciousRow(
        cBuffs, -532,
        "Augment Rune Reminder",
        "Optional reminder for Crystallized / Dreambound Augment Runes in your bags.",
        200
    )
    local pRune = CreateSegmentedPills(
        rRune, 200,
        {
            { value = false, label = "Off" },
            { value = true,  label = "Enabled" },
        },
        function() return self.db.raidBuffs.trackRunes and true or false end,
        function(v)
            self.db.raidBuffs.trackRunes = v
            self:RefreshClickableBuffs(true)
        end
    )
    rRune:BindRightControl(pRune)
    table.insert(self.refreshWidgets, pRune)

    -- Row 9: Expiring Warning Threshold (Minutes)
    local rExp = CreateSpaciousRow(
        cBuffs, -592,
        "Expiring Warning Threshold",
        "Highlights buffs/consumables in gold when their remaining duration drops below this threshold before a pull.",
        245
    )
    local slExp = CreateObsidianSlider(
        rExp, 245, 1, 15, 1,
        function(v) return string.format("%d min", math.floor(v + 0.5)) end,
        function() return self.db.raidBuffs.expireThresholdMin or 5 end,
        function(v)
            self.db.raidBuffs.expireThresholdMin = v
            self:RefreshClickableBuffs(true)
        end
    )
    rExp:BindRightControl(slExp)
    table.insert(self.refreshWidgets, slExp)

    -- Row 10: Clickable Icon Size
    local rSize = CreateSpaciousRow(
        cBuffs, -652,
        "Clickable Icon Size",
        "Adjust the pixel size of each clickable raid buff icon (32px to 64px).",
        245
    )
    local slSize = CreateObsidianSlider(
        rSize, 245, 32, 64, 2,
        function(v) return string.format("%d px", math.floor(v + 0.5)) end,
        function() return self.db.raidBuffs.iconSize or 44 end,
        function(v)
            self.db.raidBuffs.iconSize = v
            self:RefreshClickableBuffs(true)
        end
    )
    rSize:BindRightControl(slSize)
    table.insert(self.refreshWidgets, slSize)

    if self.RefreshReadinessTrackerStrip then
        pcall(self.RefreshReadinessTrackerStrip, self)
    end
    return tab2
end

function DynamicPrep:RenderWorkspace(parentFrame)
    if not parentFrame then return end
    self:InitDB()
    RegisterDynamicPrepPopupClosers()

    if self.workspaceFrame and self.workspaceFrame:GetParent() ~= parentFrame then
        self.workspaceFrame:SetParent(parentFrame)
    end

    if not self.workspaceFrame then
        local ws = CreateFrame("Frame", "DynamicPrepWorkspaceFrame", parentFrame)
        ws:SetAllPoints(parentFrame)
        ws:SetScript("OnHide", function()
            CloseAllDynamicPrepPopups()
            if DynamicPrep.dragGhostPill then
                DynamicPrep.dragGhostPill:Hide()
            end
        end)
        self.workspaceFrame = ws
        self.refreshWidgets = {}

        -- Sub-Tab Navigation Bar (34px bevel strip at 14,-10 / -16,-10; 26px buttons anchored LEFT/RIGHT only)
        local tabStrip = CreateFrame("Frame", nil, ws, "BackdropTemplate")
        tabStrip:SetHeight(34)
        tabStrip:SetPoint("TOPLEFT", ws, "TOPLEFT", 14, -10)
        tabStrip:SetPoint("TOPRIGHT", ws, "TOPRIGHT", -16, -10)
        SetPixelBackdrop(tabStrip, { 0.043, 0.051, 0.071, 0.98 }, { 1, 1, 1, 0.08 }, 1)
        ws.tabStrip = tabStrip

        local tabDefs = {
            { id = 1, label = "Bar Layout & Style" },
            { id = 2, label = "Raid Buffs & Omni Folio" },
            { id = 3, label = "World & Survival QoL" },
        }
        ws.tabButtons = {}
        for i, def in ipairs(tabDefs) do
            local tBtn = CreateFrame("Button", nil, tabStrip, "BackdropTemplate")
            tBtn:SetHeight(26)
            tBtn.label = CreateText(tBtn, "OVERLAY", "GameFontHighlight")
            tBtn.label:SetPoint("CENTER")
            tBtn.label:SetWordWrap(false)
            tBtn.label:SetText(def.label)
            tBtn:SetScript("OnClick", function()
                CloseActiveDropdown()
                self.db.activeSubTab = def.id
                self:RefreshWorkspaceView()
            end)
            ws.tabButtons[i] = tBtn
        end

        local function ReflowPrepTabs()
            local w = tabStrip:GetWidth()
            if not w or w < 100 then
                w = (ws:GetWidth() or 730) - 30
            end
            local bw = math.floor((w - 16) / 3)
            for i, b in ipairs(ws.tabButtons) do
                b:ClearAllPoints()
                b:SetHeight(26)
                if i == 1 then
                    b:SetPoint("LEFT", tabStrip, "LEFT", 4, 0)
                    b:SetWidth(bw)
                elseif i == 2 then
                    b:SetPoint("LEFT", ws.tabButtons[1], "RIGHT", 4, 0)
                    b:SetWidth(bw)
                else
                    b:SetPoint("LEFT", ws.tabButtons[2], "RIGHT", 4, 0)
                    b:SetPoint("RIGHT", tabStrip, "RIGHT", -4, 0)
                end
            end
        end
        tabStrip:SetScript("OnSizeChanged", ReflowPrepTabs)
        ws.ReflowPrepTabs = ReflowPrepTabs
        ReflowPrepTabs()

        -- ScrollFrame for spacious single-column cards (1:1 aligned with 14 / -16 bevel; 4px outside scrollbar at -6)
        local scrollFrame = CreateFrame("ScrollFrame", "DynamicPrepWorkspaceScrollFrame", ws, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", tabStrip, "BOTTOMLEFT", 0, -10)
        scrollFrame:SetPoint("BOTTOMRIGHT", ws, "BOTTOMRIGHT", -16, 12)
        StyleObsidianScrollBar(scrollFrame, ws)
        ws.scrollFrame = scrollFrame

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        local initW = scrollFrame:GetWidth()
        if not initW or initW < 100 then
            initW = (ws:GetWidth() or 730) - 30
        end
        scrollChild:SetSize(initW, 800)
        scrollFrame:SetScrollChild(scrollChild)
        scrollFrame:SetScript("OnSizeChanged", function(_, w)
            if w and w > 100 then
                scrollChild:SetWidth(w)
                self:LayoutPillGrid()
                self:RefreshLiveStagePreview()
                if scrollFrame.UpdateScrollThumb then
                    scrollFrame:UpdateScrollThumb()
                end
            end
        end)
        ws.scrollChild = scrollChild

        -- ====================================================================
        -- TAB 1: Bar Layout & Style + Omni Folio
        -- ====================================================================
        local tab1 = CreateFrame("Frame", nil, scrollChild)
        tab1:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
        tab1:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, 0)
        tab1:SetHeight(1146)
        ws.tab1 = tab1

        -- Card 1: Top Info Bar Layout Builder & Embedded Live HUD Stage
        local card1 = CreateFrame("Frame", nil, tab1, "BackdropTemplate")
        card1:SetPoint("TOPLEFT", tab1, "TOPLEFT", 0, 0)
        card1:SetPoint("TOPRIGHT", tab1, "TOPRIGHT", 0, 0)
        card1:SetHeight(712)
        SetPixelBackdrop(card1, COLORS.BgCanvas, COLORS.BorderStrong, 1)
        ws.card1 = card1

        local c1Hdr = CreateSectionHeader(
            card1, -10,
            "TOP INFO BAR LAYOUT BUILDER",
            "Click any capsule to toggle it on/off, drag to reorder, and customise your Top Info Bar appearance.",
            14
        )

        local c1EditHudBtn = self:CreateEditHudButton(card1, "PREP", function()
            self:SetEditMode(true)
        end)
        c1EditHudBtn:SetPoint("TOPRIGHT", card1, "TOPRIGHT", -14, -7)
        ws.topBarEditHudBtn = c1EditHudBtn

        local resetSegOrderBtn = CreateFrame("Button", nil, card1, "BackdropTemplate")
        resetSegOrderBtn:SetSize(96, 22)
        resetSegOrderBtn:SetPoint("RIGHT", c1EditHudBtn, "LEFT", -6, 0)
        SetPixelBackdrop(resetSegOrderBtn, COLORS.BgElevated, COLORS.BorderStrong, 1)
        resetSegOrderBtn.txt = CreateText(resetSegOrderBtn, "OVERLAY", "GameFontHighlightSmall")
        resetSegOrderBtn.txt:SetPoint("CENTER")
        resetSegOrderBtn.txt:SetText("Reset Order")
        resetSegOrderBtn:SetScript("OnClick", function()
            self.db.segmentOrder = DeepCopyDefaults(DEFAULT_SEGMENT_ORDER, {})
            for k, v in pairs(DEFAULTS.segments) do self.db.segments[k] = v end
            self:ResetStableCapsuleWidths()
            self:RefreshBar()
            self:RefreshWorkspaceView()
        end)

        c1Hdr.title:SetPoint("RIGHT", resetSegOrderBtn, "LEFT", -10, 0)
        c1Hdr.title:SetWordWrap(false)
        if c1Hdr.subtitle then
            c1Hdr.subtitle:SetPoint("RIGHT", resetSegOrderBtn, "LEFT", -10, 0)
        end

        -- Dynamic 3-column Grid of Interactive Pill Cards (Tactile Drag-and-Drop)
        local numPillRows = math.max(1, math.ceil(#DEFAULT_SEGMENT_ORDER / 3))
        local pillStripH = 16 + (numPillRows * 32) + ((numPillRows - 1) * 6)
        local pillStrip = CreateFrame("Frame", nil, card1, "BackdropTemplate")
        pillStrip:SetPoint("TOPLEFT", card1, "TOPLEFT", 14, -54)
        pillStrip:SetPoint("TOPRIGHT", card1, "TOPRIGHT", -14, -54)
        pillStrip:SetHeight(pillStripH)
        SetPixelBackdrop(pillStrip, COLORS.BgVoid, COLORS.BorderSubtle, 1)
        pillStrip:SetScript("OnSizeChanged", function()
            self:LayoutPillGrid()
        end)
        pillStrip:SetScript("OnHide", function(selfGrid)
            selfGrid:SetScript("OnUpdate", nil)
            ws.dragState = nil
            if self.dragGhostPill then
                self.dragGhostPill:Hide()
            end
        end)
        ws.pillStrip = pillStrip

        ws.pillCards = {}
        for i = 1, #DEFAULT_SEGMENT_ORDER do
            local pCard = CreateFrame("Button", nil, pillStrip, "BackdropTemplate")
            pCard:SetSize(208, 32)
            pCard:EnableMouse(true)

            pCard.leftBtn = CreateFrame("Button", nil, pCard, "BackdropTemplate")
            pCard.leftBtn:SetSize(18, 22)
            pCard.leftBtn:SetPoint("LEFT", pCard, "LEFT", 4, 0)
            SetPixelBackdrop(pCard.leftBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
            pCard.leftBtn.icon = pCard.leftBtn:CreateTexture(nil, "OVERLAY")
            pCard.leftBtn.icon:SetSize(10, 10)
            pCard.leftBtn.icon:SetPoint("CENTER")
            pCard.leftBtn.icon:SetTexture(ICON_CHEVRON_UP)
            pCard.leftBtn.icon:SetTexCoord(0, 1, 0, 1)
            pCard.leftBtn.icon:SetRotation(math.rad(90))
            if pCard.leftBtn.icon.SetSnapToPixelGrid then
                pCard.leftBtn.icon:SetSnapToPixelGrid(false)
                pCard.leftBtn.icon:SetTexelSnappingBias(0)
            end
            pCard.leftBtn.icon:SetVertexColor(0.796, 0.835, 0.882, 0.90)

            pCard.rightBtn = CreateFrame("Button", nil, pCard, "BackdropTemplate")
            pCard.rightBtn:SetSize(18, 22)
            pCard.rightBtn:SetPoint("RIGHT", pCard, "RIGHT", -4, 0)
            SetPixelBackdrop(pCard.rightBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
            pCard.rightBtn.icon = pCard.rightBtn:CreateTexture(nil, "OVERLAY")
            pCard.rightBtn.icon:SetSize(10, 10)
            pCard.rightBtn.icon:SetPoint("CENTER")
            pCard.rightBtn.icon:SetTexture(ICON_CHEVRON_UP)
            pCard.rightBtn.icon:SetTexCoord(0, 1, 0, 1)
            pCard.rightBtn.icon:SetRotation(math.rad(-90))
            if pCard.rightBtn.icon.SetSnapToPixelGrid then
                pCard.rightBtn.icon:SetSnapToPixelGrid(false)
                pCard.rightBtn.icon:SetTexelSnappingBias(0)
            end
            pCard.rightBtn.icon:SetVertexColor(0.796, 0.835, 0.882, 0.90)

            pCard.label = CreateText(pCard, "OVERLAY", "GameFontHighlightSmall")
            pCard.label:SetPoint("LEFT", pCard.leftBtn, "RIGHT", 4, 0)
            pCard.label:SetPoint("RIGHT", pCard.rightBtn, "LEFT", -4, 0)
            pCard.label:SetJustifyH("CENTER")
            pCard.label:SetWordWrap(false)

            ws.pillCards[i] = pCard
        end

        -- 7 Spacious Rows inside Card 1 (HUD Border, Bar Color Theme, Stat Sort + Custom Sub-Drawer, Display Mode, Sliders)
        local rBorder = CreateSpaciousRow(
            card1, -304,
            "HUD Border Style",
            "Choose the outer frame styling for the Top Info Bar.",
            336
        )
        local pillsBorder = CreateSegmentedPills(
            rBorder, 336,
            {
                { value = "ACCENT", label = "Class / Suite Accent" },
                { value = "DARK",   label = "Subtle Dark" },
                { value = "NONE",   label = "Borderless" },
            },
            function() return self.db.hudBorderStyle or "ACCENT" end,
            function(v)
                self.db.hudBorderStyle = v
                self:RefreshBar()
            end
        )
        rBorder:BindRightControl(pillsBorder)
        table.insert(self.refreshWidgets, pillsBorder)

        local rColorTheme = CreateSpaciousRow(
            card1, -364,
            "Bar Colour Theme",
            "Priority Glow highlights Primary in Mint Teal and ranks your #1 Secondary Stat in Accent/Gold.",
            348
        )
        local pillsColorTheme = CreateSegmentedPills(
            rColorTheme, 348,
            {
                { value = "PRIORITY_GLOW", label = "Priority Glow" },
                { value = "CLASS_ACCENT",  label = "Class Accent" },
                { value = "MONOCHROME",    label = "Crisp Monochrome" },
            },
            function() return self.db.barColorTheme or "PRIORITY_GLOW" end,
            function(v)
                self.db.barColorTheme = v
                self:RefreshBar()
            end
        )
        rColorTheme:BindRightControl(pillsColorTheme)
        table.insert(self.refreshWidgets, pillsColorTheme)

        ws.statSortDrawerOpen = true
        local rStatSort = CreateSpaciousRow(
            card1, -424,
            "Secondary Stat Order",
            "Dynamically rank your highest secondary stat first or customise your exact Crit / Haste / Mastery / Vers sequence.",
            376
        )
        local pillsStatSort = CreateSegmentedPills(
            rStatSort, 292,
            {
                { value = "RANK",   label = "Rank Highest First" },
                { value = "CUSTOM", label = "Custom Order" },
            },
            function() return self.db.secondaryStatOrderMode or self.db.statSortMode or "RANK" end,
            function(v)
                self.db.secondaryStatOrderMode = v
                self.db.statSortMode = v
                if v == "CUSTOM" then
                    ws.statSortDrawerOpen = true
                end
                self:RefreshBar()
                self:RefreshWorkspaceView()
            end
        )
        rStatSort:BindRightControl(pillsStatSort)
        table.insert(self.refreshWidgets, pillsStatSort)

        local tuneStatSort = CreateSubDrawerToggleBar(
            card1, 1,
            function()
                local m = (self.db and (self.db.secondaryStatOrderMode or self.db.statSortMode)) or "RANK"
                return m == "CUSTOM" or m == "FIXED"
            end,
            function() return ws.statSortDrawerOpen ~= false end,
            function()
                ws.statSortDrawerOpen = (ws.statSortDrawerOpen == false)
                self:RefreshWorkspaceView()
            end
        )
        rStatSort.tuneBtn = tuneStatSort
        table.insert(self.refreshWidgets, tuneStatSort)

        local dCustomStatOrder = CreateInlineSubDrawer(card1, "Custom Stat Order - Drag or Click to Reorder:")
        local statOrderStrip = CreateFrame("Frame", nil, dCustomStatOrder)
        statOrderStrip:SetSize(356, 26)
        statOrderStrip:SetScript("OnHide", function(selfStrip)
            selfStrip:SetScript("OnUpdate", nil)
            ws.statDragState = nil
            if self.dragGhostPill then
                self.dragGhostPill:Hide()
            end
        end)
        dCustomStatOrder:BindRightControl(statOrderStrip)
        ws.statOrderStrip = statOrderStrip
        ws.statOrderPills = {}
        for i = 1, 4 do
            local sp = CreateFrame("Button", nil, statOrderStrip, "BackdropTemplate")
            sp:SetSize(86, 26)
            sp:SetPoint("LEFT", statOrderStrip, "LEFT", (i - 1) * 90, 0)
            sp:EnableMouse(true)
            sp:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            sp.label = CreateText(sp, "OVERLAY", "GameFontHighlightSmall")
            sp.label:SetPoint("CENTER")
            sp.label:SetWordWrap(false)
            ws.statOrderPills[i] = sp
        end

        ws.pingDrawerOpen = true
        local rPingFormat = CreateSpaciousRow(
            card1, -484,
            "Ping Display Format",
            "Choose whether the Ping capsule shows Both (Home & World), Local Only, or World Only latency.",
            316
        )
        local pillsPingFormat = CreateSegmentedPills(
            rPingFormat, 276,
            {
                { value = "BOTH",       label = "Both" },
                { value = "LOCAL_ONLY", label = "Local" },
                { value = "WORLD_ONLY", label = "World" },
            },
            function() return self.db.pingDisplayMode or "BOTH" end,
            function(v)
                self.db.pingDisplayMode = v
                if v == "BOTH" then
                    ws.pingDrawerOpen = true
                end
                self:RefreshBar()
                self:RefreshWorkspaceView()
            end
        )
        rPingFormat:BindRightControl(pillsPingFormat)
        table.insert(self.refreshWidgets, pillsPingFormat)

        local tunePingFormat = CreateSubDrawerToggleBar(
            card1, 1,
            function()
                return (self.db and (self.db.pingDisplayMode or "BOTH")) == "BOTH"
            end,
            function() return ws.pingDrawerOpen ~= false end,
            function()
                ws.pingDrawerOpen = (ws.pingDrawerOpen == false)
                self:RefreshWorkspaceView()
            end
        )
        rPingFormat.tuneBtn = tunePingFormat
        table.insert(self.refreshWidgets, tunePingFormat)

        local dPingOrder = CreateInlineSubDrawer(card1, "Ping Latency Order (When Showing Both):")
        local pillsPingOrder = CreateSegmentedPills(
            dPingOrder, 260,
            {
                { value = "LOCAL_FIRST", label = "Local / World" },
                { value = "WORLD_FIRST", label = "World / Local" },
            },
            function() return self.db.pingOrder or "LOCAL_FIRST" end,
            function(v)
                self.db.pingOrder = v
                self:RefreshBar()
                self:RefreshWorkspaceView()
            end
        )
        dPingOrder:BindRightControl(pillsPingOrder)
        table.insert(self.refreshWidgets, pillsPingOrder)

        local rDisplay = CreateSpaciousRow(
            card1, -544,
            "Top Info Bar Display Mode",
            "Choose when the top bar is shown. When hidden, the Alert Toast displays your readiness summary.",
            348
        )
        local pillsDisplay = CreateSegmentedPills(
            rDisplay, 348,
            {
                { value = "ALWAYS",   label = "Always" },
                { value = "OOC",      label = "Out of Combat" },
                { value = "INSTANCE", label = "Instance" },
                { value = "HIDDEN",   label = "Hidden" },
            },
            function() return self.db.displayMode or "ALWAYS" end,
            function(v)
                self.db.displayMode = v
                self:RefreshBar()
            end
        )
        rDisplay:BindRightControl(pillsDisplay)
        table.insert(self.refreshWidgets, pillsDisplay)

        local rThrottle = CreateSpaciousRow(
            card1, -604,
            "Combat Stat Refresh Rate",
            "Controls how frequently primary and secondary stat procs refresh during active combat.",
            245
        )
        local slThrottle = CreateObsidianSlider(
            rThrottle, 245, 0.1, 1.0, 0.05,
            function(v) return string.format("%.2fs", v) end,
            function() return self.db.combatRefreshRate or 0.2 end,
            function(v) self.db.combatRefreshRate = v end
        )
        rThrottle:BindRightControl(slThrottle)
        table.insert(self.refreshWidgets, slThrottle)

        local rScale = CreateSpaciousRow(
            card1, -664,
            "Bar Scale",
            "Independently scale the Top Info Bar size (60% to 150%), decoupled from Opacity.",
            245
        )
        local slScale = CreateObsidianSlider(
            rScale, 245, 0.60, 1.50, 0.05,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return self.db.barScale or 1.0 end,
            function(v)
                self.db.barScale = v
                self:ApplyBarGeometry()
            end
        )
        rScale:BindRightControl(slScale)
        table.insert(self.refreshWidgets, slScale)

        local rOpacity = CreateSpaciousRow(
            card1, -724,
            "Bar Opacity",
            "Independently adjust the Top Info Bar transparency (20% to 100%), decoupled from Scale.",
            245
        )
        local slOpacity = CreateObsidianSlider(
            rOpacity, 245, 0.20, 1.00, 0.05,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return self.db.barOpacity or 0.95 end,
            function(v)
                self.db.barOpacity = v
                self:ApplyBarGeometry()
            end
        )
        rOpacity:BindRightControl(slOpacity)
        table.insert(self.refreshWidgets, slOpacity)

        ws.tab1Rows = {
            rBorder          = rBorder,
            rColorTheme      = rColorTheme,
            rStatSort        = rStatSort,
            tuneStatSort     = tuneStatSort,
            dCustomStatOrder = dCustomStatOrder,
            rPingFormat      = rPingFormat,
            tunePingFormat   = tunePingFormat,
            dPingOrder       = dPingOrder,
            others           = { rDisplay, rThrottle, rScale, rOpacity },
        }

        -- ====================================================================
        -- TAB 2: Raid Buffs & Omni Folio (Clickable Raid Buffs + Omni Folio)
        -- ====================================================================
        local tab2 = BuildRaidBuffsTab(self, ws)
        ws.tab2 = tab2

        -- Card 2 (inside Tab 2 below Clickable Raid Buffs): Midnight Omni Folio Configuration
        local card2 = CreateFrame("Frame", nil, tab2, "BackdropTemplate")
        card2:SetPoint("TOPLEFT", ws.raidBuffsCard, "BOTTOMLEFT", 0, -14)
        card2:SetPoint("TOPRIGHT", ws.raidBuffsCard, "BOTTOMRIGHT", 0, -14)
        card2:SetHeight(422)
        SetPixelBackdrop(card2, COLORS.BgCanvas, COLORS.BorderStrong, 1)
        ws.card2 = card2

        local c2Hdr = CreateSectionHeader(
            card2, -10,
            "MIDNIGHT OMNIUM FOLIO CONFIGURATION",
            "Assign your target Omnium Folio secondary stat for each content type or use built-in 40-spec presets.",
            14
        )

        local folioStatOptions = {
            { value = "HASTE",   label = "Haste" },
            { value = "MASTERY", label = "Mastery" },
            { value = "CRIT",    label = "Critical Strike" },
            { value = "VERS",    label = "Versatility" },
            { value = "OFF",     label = "Off" },
        }

        local rFolioEnable = CreateSpaciousRow(
            card2, -54,
            "Omni Folio Tracking",
            "Show the Omni Folio target stat on the Top Info Bar and highlight in gold when your buff mismatches.",
            220
        )
        local pillsFolioEnable = CreateSegmentedPills(
            rFolioEnable, 220,
            {
                { value = false, label = "Off" },
                { value = true,  label = "Enabled" },
            },
            function() return self.db.omniFolio.enabled and true or false end,
            function(v)
                self.db.omniFolio.enabled = v
                self:RefreshBar()
            end
        )
        rFolioEnable:BindRightControl(pillsFolioEnable)
        table.insert(self.refreshWidgets, pillsFolioEnable)

        local rFolioPreset = CreateSpaciousRow(
            card2, -114,
            "Specialisation Preset",
            "Populate all 4 content targets from the built-in 40-spec Recommended Stat Priority matrix.",
            240
        )
        local pillsFolioPreset = CreateSegmentedPills(
            rFolioPreset, 240,
            {
                { value = "WOWHEAD", label = "Wowhead Preset" },
                { value = "CUSTOM",  label = "Custom" },
            },
            function() return self.db.omniFolio.presetMode or "WOWHEAD" end,
            function(v)
                self.db.omniFolio.presetMode = v
                if v == "WOWHEAD" then
                    self:ApplyWowheadPresetForCurrentSpec(false)
                else
                    self:RefreshBar()
                    self:RefreshWorkspaceView()
                end
            end
        )
        rFolioPreset:BindRightControl(pillsFolioPreset)
        table.insert(self.refreshWidgets, pillsFolioPreset)

        local contentRows = {
            { key = "mplus", offset = -174, title = "Mythic+ Dungeons Target Stat",    desc = "Recommended Omni Folio secondary stat for Mythic+ Keystone dungeons." },
            { key = "raid",  offset = -234, title = "Raid Encounters Target Stat",     desc = "Recommended Omni Folio secondary stat inside Raid instances." },
            { key = "delve", offset = -294, title = "Delves & Open World Target Stat", desc = "Recommended Omni Folio secondary stat for Delves and Open World." },
            { key = "pvp",   offset = -354, title = "Rated & Casual PvP Target Stat",  desc = "Recommended Omni Folio secondary stat for Arenas and Battlegrounds." },
        }

        for _, cr in ipairs(contentRows) do
            local row = CreateSpaciousRow(card2, cr.offset, cr.title, cr.desc, 240)
            local dd = CreateObsidianDropdown(
                row, 240,
                folioStatOptions,
                function() return self:GetTargetFolioStatForZone(cr.key) end,
                function(v)
                    self.db.omniFolio.presetMode = "CUSTOM"
                    self.db.omniFolio[cr.key] = v
                    self:RefreshBar()
                    self:RefreshWorkspaceView()
                end
            )
            row:BindRightControl(dd)
            table.insert(self.refreshWidgets, dd)
        end
        tab2:SetHeight(728 + 14 + 422 + 14)

        -- ====================================================================
        -- TAB 3: World, Instance & Survival Automation + Conflict Scanner
        -- ====================================================================
        local tab3 = CreateFrame("Frame", nil, scrollChild)
        tab3:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
        tab3:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, 0)
        tab3:SetHeight(480)
        ws.tab3 = tab3

        -- Card 1: Active Conflict Scanner (Completely hidden when zero conflicts are enabled!)
        local cScan = CreateFrame("Frame", nil, tab3, "BackdropTemplate")
        cScan:SetPoint("TOPLEFT", tab3, "TOPLEFT", 0, 0)
        cScan:SetPoint("TOPRIGHT", tab3, "TOPRIGHT", 0, 0)
        cScan:SetHeight(194)
        SetPixelBackdrop(cScan, COLORS.BgCanvas, COLORS.BorderStrong, 1)
        ws.conflictCard = cScan

        local csRescanBtn = CreateFrame("Button", nil, cScan, "BackdropTemplate")
        csRescanBtn:SetSize(124, 20)
        csRescanBtn:SetPoint("TOPRIGHT", cScan, "TOPRIGHT", -14, -7)
        SetPixelBackdrop(csRescanBtn, COLORS.BgElevated, COLORS.BorderStrong, 1)
        csRescanBtn.txt = CreateText(csRescanBtn, "OVERLAY", "GameFontHighlightSmall")
        csRescanBtn.txt:SetPoint("CENTER")
        csRescanBtn.txt:SetWordWrap(false)
        csRescanBtn.txt:SetText("Rescan Addons")
        csRescanBtn:SetScript("OnClick", function()
            DynamicPrep:RefreshWorkspaceView()
        end)

        local csHdr = CreateSectionHeader(
            cScan, -10,
            "ACTIVE CONFLICT SCANNER & COMPATIBILITY",
            "Overlapping automation addons detected - choose which addon manages your UI and readiness features.",
            14
        )
        csHdr.title:SetPoint("RIGHT", csRescanBtn, "LEFT", -12, 0)

        cScan.statusText = CreateText(cScan, "OVERLAY", "GameFontNormalSmall")
        cScan.statusText:SetPoint("TOPLEFT", csHdr, "BOTTOMLEFT", 0, -6)
        cScan.statusText:SetPoint("RIGHT", csRescanBtn, "LEFT", -12, 0)
        cScan.statusText:SetJustifyH("LEFT")
        cScan.statusText:SetWordWrap(false)

        cScan.rows = {}
        for i = 1, 2 do
            local crow = CreateFrame("Frame", nil, cScan, "BackdropTemplate")
            crow:SetHeight(52)
            crow:SetPoint("TOPLEFT", cScan, "TOPLEFT", 14, -74 - (i - 1) * 56)
            crow:SetPoint("TOPRIGHT", cScan, "TOPRIGHT", -14, -74 - (i - 1) * 56)
            SetPixelBackdrop(crow, COLORS.BgSurface, COLORS.BorderSubtle, 1)

            crow.actionBtn = CreateFrame("Button", nil, crow, "BackdropTemplate")
            crow.actionBtn:SetSize(i == 1 and 142 or 178, 28)
            crow.actionBtn:SetPoint("RIGHT", crow, "RIGHT", -10, 0)
            SetPixelBackdrop(crow.actionBtn, COLORS.BgElevated, GetAccentColorTable(1.0), 1)
            crow.actionBtn.txt = CreateText(crow.actionBtn, "OVERLAY", "GameFontHighlightSmall")
            crow.actionBtn.txt:SetPoint("CENTER")
            crow.actionBtn.txt:SetWordWrap(false)

            if i == 1 then
                crow.secondaryBtn = CreateFrame("Button", nil, crow, "BackdropTemplate")
                crow.secondaryBtn:SetSize(136, 28)
                crow.secondaryBtn:SetPoint("RIGHT", crow.actionBtn, "LEFT", -8, 0)
                SetPixelBackdrop(crow.secondaryBtn, COLORS.BgSurface, COLORS.BorderStrong, 1)
                crow.secondaryBtn.txt = CreateText(crow.secondaryBtn, "OVERLAY", "GameFontHighlightSmall")
                crow.secondaryBtn.txt:SetPoint("CENTER")
                crow.secondaryBtn.txt:SetWordWrap(false)
            end

            local rightBoundaryTarget = (i == 1) and crow.secondaryBtn or crow.actionBtn

            crow.title = CreateText(crow, "OVERLAY", "GameFontHighlight")
            crow.title:SetPoint("TOPLEFT", crow, "TOPLEFT", 12, -8)
            crow.title:SetPoint("RIGHT", rightBoundaryTarget, "LEFT", -16, 0)
            crow.title:SetJustifyH("LEFT")
            crow.title:SetWordWrap(false)

            crow.label = CreateText(crow, "OVERLAY", "GameFontDisableSmall")
            crow.label:SetPoint("TOPLEFT", crow.title, "BOTTOMLEFT", 0, -3)
            crow.label:SetPoint("RIGHT", rightBoundaryTarget, "LEFT", -16, 0)
            crow.label:SetJustifyH("LEFT")
            crow.label:SetWordWrap(true)

            cScan.rows[i] = crow
        end

        -- Card 2: World, Instance & Survival Automation
        local cQoL = CreateFrame("Frame", nil, tab3, "BackdropTemplate")
        cQoL:SetPoint("TOPLEFT", tab3, "TOPLEFT", 0, 0)
        cQoL:SetPoint("TOPRIGHT", tab3, "TOPRIGHT", 0, 0)
        cQoL:SetHeight(440)
        SetPixelBackdrop(cQoL, COLORS.BgCanvas, COLORS.BorderStrong, 1)
        ws.qolCard = cQoL

        local qHdr = CreateSectionHeader(
            cQoL, -10,
            "WORLD, INSTANCE & SURVIVAL AUTOMATION",
            "Automate quest turn-ins, Catalyst conversions, instance cutscenes, post-wipe resurrection/release, and survival macros.",
            14
        )

        -- 1. Auto-Skip Gossip & Quest Accept / Turn-In
        local rQuestGossip = CreateSpaciousRow(
            cQoL, -54,
            "Auto-Skip Gossip & Quest Turn-In",
            "Automatically accepts quests, turns in completed quests (pauses if choosing between rewards), and skips quest gossip (hold Shift to bypass).",
            200
        )
        local pillsQuestGossip = CreateSegmentedPills(
            rQuestGossip, 200,
            {
                { value = false, label = "Off" },
                { value = true,  label = "Enabled" },
            },
            function() return self.db.autoQuestGossip ~= false end,
            function(v) self.db.autoQuestGossip = v end
        )
        rQuestGossip:BindRightControl(pillsQuestGossip)
        table.insert(self.refreshWidgets, pillsQuestGossip)

        -- 1a-i. Opt-In Auto-Confirm Free Dungeon & Raid Prompts (Off by default)
        local rAutoConfirmInstanceGossip = CreateSpaciousRow(
            cQoL, -114,
            "Auto-Confirm Free Dungeon & Raid Prompts",
            "Automatically confirms free single-option NPC prompts (such as boss starts) inside Dungeons, Raids, and Delves. Open-world and paid prompts always ask first (hold Shift to pause).",
            156
        )
        local pillsAutoConfirmInstanceGossip = CreateSegmentedPills(
            rAutoConfirmInstanceGossip, 156,
            {
                { value = false, label = "Off" },
                { value = true,  label = "Enabled" },
            },
            function() return self.db.autoConfirmInstanceGossip == true end,
            function(v) self.db.autoConfirmInstanceGossip = (v == true) end
        )
        rAutoConfirmInstanceGossip:BindRightControl(pillsAutoConfirmInstanceGossip)
        table.insert(self.refreshWidgets, pillsAutoConfirmInstanceGossip)

        -- 1a-ii. Auto-Confirm Single-Option Chamber Doors & Player Choices (Labyrinth / Delve / World PlayerChoiceFrame)
        local rAutoChoice = CreateSpaciousRow(
            cQoL, -114,
            "Auto-Confirm Single-Option Doors & Choices",
            "Automatically confirms single-option choice popups across Delves, Labyrinth doors, dungeons, and world events on Right-Click or Interact keybind (hold Shift to open manually).",
            200
        )
        local pillsAutoChoice = CreateSegmentedPills(
            rAutoChoice, 200,
            {
                { value = false, label = "Off" },
                { value = true,  label = "Enabled" },
            },
            function() return self.db.autoSinglePlayerChoice ~= false end,
            function(v) self.db.autoSinglePlayerChoice = v end
        )
        rAutoChoice:BindRightControl(pillsAutoChoice)
        table.insert(self.refreshWidgets, pillsAutoChoice)

        -- 1b. One-Click Catalyst (Revival Catalyst instant item conversion without confirmation popup)
        local rCatalyst = CreateSpaciousRow(
            cQoL, -114,
            "One-Click Catalyst",
            "Completes Revival Catalyst tier conversions in a single click on Transform without a second confirmation popup or 5-second wait (hold Shift to show popup).",
            200
        )
        local pillsCatalyst = CreateSegmentedPills(
            rCatalyst, 200,
            {
                { value = false, label = "Off" },
                { value = true,  label = "Enabled" },
            },
            function() return self.db.oneClickCatalyst ~= false end,
            function(v) self.db.oneClickCatalyst = v end
        )
        rCatalyst:BindRightControl(pillsCatalyst)
        table.insert(self.refreshWidgets, pillsCatalyst)

        -- 1c. Auto-Accept Group Summons (CONFIRM_SUMMON, 1.5s out-of-combat safety delay)
        local rAutoSummon = CreateSpaciousRow(
            cQoL, -114,
            "Auto-Accept Group Summons",
            "Automatically accepts Warlock and Meeting Stone summons after a 1.5s out-of-combat safety delay (skipped while dead or in combat; hold Shift to cancel).",
            200
        )
        local pillsAutoSummon = CreateSegmentedPills(
            rAutoSummon, 200,
            {
                { value = false, label = "Off" },
                { value = true,  label = "Enabled" },
            },
            function() return self.db.autoAcceptSummon == true end,
            function(v) self.db.autoAcceptSummon = v end
        )
        rAutoSummon:BindRightControl(pillsAutoSummon)
        table.insert(self.refreshWidgets, pillsAutoSummon)

        -- 2. Hide Talking Head & Skip Cutscenes
        local rCine = CreateSpaciousRow(
            cQoL, -114,
            "Hide Talking Head & Skip Cutscenes",
            "Hides Talking Head popups and skips cutscenes and movies automatically. Hold Shift to watch a cutscene without skipping.",
            280
        )
        local pillsCine = CreateSegmentedPills(
            rCine, 280,
            {
                { value = "OFF",       label = "Off" },
                { value = "SKIP_ONLY", label = "Skip Cutscenes" },
                { value = "BOTH",      label = "Hide Head & Skip" },
            },
            function() return self.db.cinematicMode or "BOTH" end,
            function(v)
                self.db.cinematicMode = v
                self:UpdateTalkingHeadSuppression()
            end
        )
        rCine:BindRightControl(pillsCine)
        table.insert(self.refreshWidgets, pillsCine)

        -- 3. Smart Auto-Accept Resurrection (Long descriptive rules -> Fixed-Width 240px Obsidian Dropdown)
        local rRez = CreateSpaciousRow(
            cQoL, -174,
            "Smart Auto-Accept Resurrection",
            "Auto-accepts mass/normal rez after a wipe when the group is out of combat; never auto-takes a combat Battle Rez.",
            240
        )
        local ddRez = CreateObsidianDropdown(
            rRez, 290,
            {
                { value = "OUT_OF_COMBAT", label = "Safe Out-of-Combat Only (Post-Wipe)" },
                { value = "ALWAYS",        label = "Always (Include Combat Battle Rez)" },
                { value = "OFF",           label = "Disabled (Manual Accept)" },
            },
            function() return self.db.autoRezMode or "OUT_OF_COMBAT" end,
            function(v) self.db.autoRezMode = v end
        )
        rRez:BindRightControl(ddRez)
        table.insert(self.refreshWidgets, ddRez)

        -- 4. Smart Auto-Release Spirit (Long descriptive rules -> Fixed-Width 240px Obsidian Dropdown)
        local rRelease = CreateSpaciousRow(
            cQoL, -234,
            "Smart Auto-Release Spirit",
            "Auto-releases spirit upon raid/dungeon wipes. Keeps the Release button greyed out until Ctrl is held to prevent accidental releases.",
            240
        )
        local ddRelease = CreateObsidianDropdown(
            rRelease, 290,
            {
                { value = "WIPE_AND_CTRL",     label = "Auto-Release on Wipe + Hold Ctrl Safety" },
                { value = "HOLD_CTRL",         label = "Hold Ctrl to Release (Never Auto-Release)" },
                { value = "PVP_AUTO_WIPE_PVE", label = "Instant in PvP + Wipe/Ctrl in PvE" },
                { value = "ALWAYS",            label = "Instant Release Everywhere" },
                { value = "OFF",               label = "Disabled (Standard Blizzard)" },
            },
            function() return self.db.autoReleaseMode or "WIPE_AND_CTRL" end,
            function(v)
                self.db.autoReleaseMode = v
                self:UpdateDeathDialogButtonState()
            end
        )
        rRelease:BindRightControl(ddRelease)
        table.insert(self.refreshWidgets, ddRelease)

        -- 5. Automated Healing Macro ([DynamicHeal]) + Action Sub-Drawer
        ws.healDrawerOpen = true
        local rHealMacro = CreateSpaciousRow(
            cQoL, -294,
            "Automated Healing Macro ([DynamicHeal])",
            "Scans bags on zone entry and Soulwell loot. Updates out of combat.",
            416
        )
        local pillsHealMacro = CreateSegmentedPills(
            rHealMacro, 376,
            {
                { value = "STONE_FIRST", label = "Stone -> Pot" },
                { value = "POT_FIRST",   label = "Pot -> Stone" },
                { value = "BOTH",        label = "Both (Panic)" },
                { value = "OFF",         label = "Off" },
            },
            function()
                if self.db.autoHealMacroEnabled == false then return "OFF" end
                return self.db.healMacroOrder or "STONE_FIRST"
            end,
            function(v)
                self.db.healMacroOrder = v
                self.db.autoHealMacroEnabled = (v ~= "OFF")
                if v ~= "OFF" then
                    ws.healDrawerOpen = true
                    self:UpdateHealMacro(false)
                end
                self:RefreshWorkspaceView()
            end
        )
        rHealMacro:BindRightControl(pillsHealMacro)
        table.insert(self.refreshWidgets, pillsHealMacro)

        local tuneHealMacro = CreateSubDrawerToggleBar(
            cQoL, 1,
            function()
                return self.db and self.db.autoHealMacroEnabled ~= false and (self.db.healMacroOrder or "STONE_FIRST") ~= "OFF"
            end,
            function() return ws.healDrawerOpen ~= false end,
            function()
                ws.healDrawerOpen = (ws.healDrawerOpen == false)
                self:RefreshWorkspaceView()
            end
        )
        rHealMacro.tuneBtn = tuneHealMacro
        table.insert(self.refreshWidgets, tuneHealMacro)

        local dHealMacro = CreateInlineSubDrawer(cQoL, "Macro [DynamicHeal]: Drag to Action Bar")
        local btnPickupHeal = CreateFrame("Button", nil, dHealMacro, "BackdropTemplate")
        btnPickupHeal:SetSize(184, 26)
        btnPickupHeal.txt = CreateText(btnPickupHeal, "OVERLAY", "GameFontHighlightSmall")
        btnPickupHeal.txt:SetPoint("CENTER")
        btnPickupHeal.txt:SetWordWrap(false)
        btnPickupHeal.txt:SetText("Create & Pickup Macro")
        function btnPickupHeal:RefreshValue()
            local ar, ag, ab = GetActiveAccentRGB()
            local stateKey, statusBadge, btnLabel = DynamicPrep:GetHealMacroActionBarStatus()
            if stateKey == "ON_BAR" then
                SetPixelBackdrop(self, { 0.063 * 0.45, 0.725 * 0.45, 0.506 * 0.45, 0.98 }, { 0.204, 0.827, 0.600, 0.95 }, 1)
            else
                SetPixelBackdrop(self, COLORS.BgElevated, { ar, ag, ab, 0.90 }, 1)
            end
            self.txt:SetText(btnLabel)
            local _, stoneCnt, _, potCnt = DynamicPrep:ScanHealingConsumables()
            local fallbackSpell = DynamicPrep:GetClassSurvivalSpell()
            dHealMacro.title:SetText(string.format(
                "|cFFCBD5E1[DynamicHeal]|r %s  |cFF34D399%d Stone|r, |cFF38BDF8%d Pot|r |cFF64748B(%s)|r",
                statusBadge, stoneCnt or 0, potCnt or 0, fallbackSpell
            ))
        end
        btnPickupHeal:SetScript("OnEnter", function(selfBtn)
            local ar, ag, ab = GetActiveAccentRGB()
            SetPixelBackdrop(selfBtn, COLORS.BgHover, { ar, ag, ab, 1.0 }, 1)
        end)
        btnPickupHeal:SetScript("OnLeave", function(selfBtn)
            selfBtn:RefreshValue()
        end)
        btnPickupHeal:SetScript("OnClick", function()
            DynamicPrep:UpdateHealMacro(true)
            DynamicPrep:RefreshWorkspaceView()
        end)
        dHealMacro:BindRightControl(btnPickupHeal)
        table.insert(self.refreshWidgets, btnPickupHeal)

        local function BuildRecoveryQoLRows()
            -- 6. Automated Drink & Recovery Macro ([DynamicDrink]) + 3-Row Sub-Drawer
            ws.drinkDrawerOpen = true
            local rDrinkMacro = CreateSpaciousRow(
                cQoL, -294,
                "Automated Drink & Recovery Macro ([DynamicDrink])",
                "Out-of-combat [nocombat] drink and food macro. Excludes Well Fed buff food by default.",
                416
            )
            local pillsDrinkMacro = CreateSegmentedPills(
                rDrinkMacro, 416,
                {
                    { value = "ROLE_SMART",   label = "Role-Smart" },
                    { value = "MANA_FIRST",   label = "Mana First" },
                    { value = "HEALTH_RECUP", label = "Health / Recup" },
                    { value = "OFF",          label = "Off" },
                },
                function() return self.db.drinkMacroMode or "ROLE_SMART" end,
                function(v)
                    self.db.drinkMacroMode = v
                    if v ~= "OFF" then
                        ws.drinkDrawerOpen = true
                        self:UpdateDrinkMacro(false)
                    end
                    self:RefreshWorkspaceView()
                end
            )
            rDrinkMacro:BindRightControl(pillsDrinkMacro)
            table.insert(self.refreshWidgets, pillsDrinkMacro)

            local tuneDrinkMacro = CreateSubDrawerToggleBar(
                cQoL, 3,
                function()
                    return self.db and (self.db.drinkMacroMode or "ROLE_SMART") ~= "OFF"
                end,
                function() return ws.drinkDrawerOpen ~= false end,
                function()
                    ws.drinkDrawerOpen = (ws.drinkDrawerOpen == false)
                    self:RefreshWorkspaceView()
                end
            )
            rDrinkMacro.tuneBtn = tuneDrinkMacro
            table.insert(self.refreshWidgets, tuneDrinkMacro)

            local dDrinkMacro = CreateInlineSubDrawer(cQoL, "Macro [DynamicDrink]: Drag to Action Bar")
            local btnPickupDrink = CreateFrame("Button", nil, dDrinkMacro, "BackdropTemplate")
            btnPickupDrink:SetSize(184, 26)
            btnPickupDrink.txt = CreateText(btnPickupDrink, "OVERLAY", "GameFontHighlightSmall")
            btnPickupDrink.txt:SetPoint("CENTER")
            btnPickupDrink.txt:SetWordWrap(false)
            btnPickupDrink.txt:SetText("Create & Pickup Macro")
            function btnPickupDrink:RefreshValue()
                local ar, ag, ab = GetActiveAccentRGB()
                local stateKey, statusBadge, btnLabel = DynamicPrep:GetDrinkMacroActionBarStatus()
                if stateKey == "ON_BAR" then
                    SetPixelBackdrop(self, { 0.063 * 0.45, 0.725 * 0.45, 0.506 * 0.45, 0.98 }, { 0.204, 0.827, 0.600, 0.95 }, 1)
                else
                    SetPixelBackdrop(self, COLORS.BgElevated, { ar, ag, ab, 0.90 }, 1)
                end
                self.txt:SetText(btnLabel)
                local scan = DynamicPrep:ScanRecoveryConsumables()
                local target = DynamicPrep:ResolveDrinkMacroTarget(scan)
                local targetName = (target and target.name) or "None"
                dDrinkMacro.title:SetText(string.format(
                    "|cFFCBD5E1[DynamicDrink]|r %s  |cFF34D399%d Buns|r, |cFF38BDF8%d Drink|r, |cFFFBBF24%d Food|r |cFF64748B(%s)|r",
                    statusBadge, scan.mageFoodCount or 0, scan.manaDrinkCount or 0, scan.vendorFoodCount or 0, targetName
                ))
            end
            btnPickupDrink:SetScript("OnEnter", function(selfBtn)
                local ar, ag, ab = GetActiveAccentRGB()
                SetPixelBackdrop(selfBtn, COLORS.BgHover, { ar, ag, ab, 1.0 }, 1)
            end)
            btnPickupDrink:SetScript("OnLeave", function(selfBtn)
                selfBtn:RefreshValue()
            end)
            btnPickupDrink:SetScript("OnClick", function()
                DynamicPrep:UpdateDrinkMacro(true)
                DynamicPrep:RefreshWorkspaceView()
            end)
            dDrinkMacro:BindRightControl(btnPickupDrink)
            table.insert(self.refreshWidgets, btnPickupDrink)

            local dDrinkRecup = CreateInlineSubDrawer(cQoL, "Fallback to Recuperate (when out of drinks/food)")
            local pDrinkRecup = CreateSegmentedPills(
                dDrinkRecup, 156,
                {
                    { value = false, label = "Off" },
                    { value = true,  label = "Enabled" },
                },
                function() return self.db.drinkMacroRecupFallback ~= false end,
                function(v)
                    self.db.drinkMacroRecupFallback = (v == true)
                    self:UpdateDrinkMacro(false)
                    self:RefreshWorkspaceView()
                end
            )
            dDrinkRecup:BindRightControl(pDrinkRecup)
            table.insert(self.refreshWidgets, pDrinkRecup)

            local dDrinkBuffFood = CreateInlineSubDrawer(cQoL, "Allow Buff Food as Last Resort (Warning: consumes Well Fed food)")
            local pDrinkBuffFood = CreateSegmentedPills(
                dDrinkBuffFood, 156,
                {
                    { value = false, label = "Off" },
                    { value = true,  label = "Enabled" },
                },
                function() return self.db.drinkMacroAllowBuffFood == true end,
                function(v)
                    self.db.drinkMacroAllowBuffFood = (v == true)
                    self:UpdateDrinkMacro(false)
                    self:RefreshWorkspaceView()
                end
            )
            dDrinkBuffFood:BindRightControl(pDrinkBuffFood)
            table.insert(self.refreshWidgets, pDrinkBuffFood)

            -- 7. Healer Mage Food Restock (Follower Dungeon) + 4-Row Sub-Drawer
            ws.mageFoodDrawerOpen = true
            local rMageFood = CreateSpaciousRow(
                cQoL, -294,
                "Healer Mage Food Restock (Follower Dungeon)",
                "Prompts solo players to queue a Follower Dungeon when low on Conjured Mana Buns, prompts to leave once restocked, and offers a 1-click Ask for Table toast in groups with a Mage.",
                156
            )
            rMageFood:HookScript("OnEnter", function(selfRow)
                if GameTooltip then
                    local ar, ag, ab = GetActiveAccentRGB()
                    GameTooltip:SetOwner(selfRow, "ANCHOR_TOP")
                    GameTooltip:AddLine("Healer Mage Food Restock & Group Table Prompt", ar, ag, ab)
                    GameTooltip:AddLine("1. Solo & low on buns: shows a 1-click Queue Follower toast.", 0.88, 0.91, 0.96, true)
                    GameTooltip:AddLine("2. Inside Follower Dungeon at target count: shows Leave Dungeon.", 0.88, 0.91, 0.96, true)
                    GameTooltip:AddLine("3. In a party or raid with a Mage (outside active M+): shows Ask for Table (5-min cooldown, Right-Click to silence).", 0.88, 0.91, 0.96, true)
                    GameTooltip:Show()
                end
            end)
            rMageFood:HookScript("OnLeave", function()
                if GameTooltip then GameTooltip:Hide() end
            end)
            local pillsMageFood = CreateSegmentedPills(
                rMageFood, 156,
                {
                    { value = false, label = "Off" },
                    { value = true,  label = "Enabled" },
                },
                function() return self.db.mageFoodRestockEnabled ~= false end,
                function(v)
                    self.db.mageFoodRestockEnabled = (v == true)
                    if v == true then
                        ws.mageFoodDrawerOpen = true
                        self:RequestMageFoodCheck("TOGGLE", 0.1)
                    else
                        self:HideMageFoodToast()
                    end
                    self:RefreshWorkspaceView()
                end
            )
            rMageFood:BindRightControl(pillsMageFood)
            table.insert(self.refreshWidgets, pillsMageFood)

            local tuneMageFood = CreateSubDrawerToggleBar(
                cQoL, 4,
                function() return self.db and self.db.mageFoodRestockEnabled ~= false end,
                function() return ws.mageFoodDrawerOpen ~= false end,
                function()
                    ws.mageFoodDrawerOpen = (ws.mageFoodDrawerOpen == false)
                    self:RefreshWorkspaceView()
                end
            )
            rMageFood.tuneBtn = tuneMageFood
            table.insert(self.refreshWidgets, tuneMageFood)

            local dMageScope = CreateInlineSubDrawer(cQoL, "Role Scope (Restock & Mage Table Prompts)")
            local pMageScope = CreateSegmentedPills(
                dMageScope, 240,
                {
                    { value = "HEALER_ONLY", label = "Healer Only" },
                    { value = "ANY_MANA",    label = "Any Mana Spec" },
                },
                function() return self.db.mageFoodRestockScope or "HEALER_ONLY" end,
                function(v)
                    self.db.mageFoodRestockScope = v
                    self:RequestMageFoodCheck("SCOPE_CHANGE", 0.1)
                end
            )
            dMageScope:BindRightControl(pMageScope)
            table.insert(self.refreshWidgets, pMageScope)

            local dMageMin = CreateInlineSubDrawer(cQoL, "Low Food Alert Threshold (Alert when below)")
            local sMageMin = CreateObsidianSlider(
                dMageMin, 256, 5, 60, 5,
                function(val) return string.format("%d", val) end,
                function() return self.db.mageFoodMinThreshold or 20 end,
                function(val)
                    self.db.mageFoodMinThreshold = val
                    self:RequestMageFoodCheck("THRESHOLD_CHANGE", 0.1)
                end
            )
            dMageMin:BindRightControl(sMageMin)
            table.insert(self.refreshWidgets, sMageMin)

            local dMageLeave = CreateInlineSubDrawer(cQoL, "Auto-Leave Target (Prompt to leave inside Follower Dungeon)")
            local sMageLeave = CreateObsidianSlider(
                dMageLeave, 256, 20, 80, 20,
                function(val) return string.format("%d", val) end,
                function() return self.db.mageFoodLeaveTarget or 20 end,
                function(val)
                    self.db.mageFoodLeaveTarget = val
                end
            )
            dMageLeave:BindRightControl(sMageLeave)
            table.insert(self.refreshWidgets, sMageLeave)

            local dMageTest = CreateInlineSubDrawer(cQoL, "Conjured Mana Buns in Bags: 0")
            local btnTestMageToast = CreateFrame("Button", nil, dMageTest, "BackdropTemplate")
            btnTestMageToast:SetSize(156, 26)
            btnTestMageToast.txt = CreateText(btnTestMageToast, "OVERLAY", "GameFontHighlightSmall")
            btnTestMageToast.txt:SetPoint("CENTER")
            btnTestMageToast.txt:SetWordWrap(false)
            btnTestMageToast.txt:SetText("Test Toast")
            function btnTestMageToast:RefreshValue()
                local ar, ag, ab = GetActiveAccentRGB()
                SetPixelBackdrop(self, COLORS.BgElevated, { ar, ag, ab, 0.90 }, 1)
                local buns = DynamicPrep:GetConjuredMageFoodCount()
                dMageTest.title:SetText(string.format("|cFFCBD5E1Conjured Mana Buns in Bags:|r |cFF34D399%d|r", buns))
            end
            btnTestMageToast:SetScript("OnEnter", function(selfBtn)
                local ar, ag, ab = GetActiveAccentRGB()
                SetPixelBackdrop(selfBtn, COLORS.BgHover, { ar, ag, ab, 1.0 }, 1)
            end)
            btnTestMageToast:SetScript("OnLeave", function(selfBtn)
                selfBtn:RefreshValue()
            end)
            btnTestMageToast:SetScript("OnClick", function()
                DynamicPrep:TriggerMageFoodToastPreview()
            end)
            dMageTest:BindRightControl(btnTestMageToast)
            table.insert(self.refreshWidgets, btnTestMageToast)

            -- 8. Low Durability Alert Toast + 2-Row Sub-Drawer
            ws.durabilityDrawerOpen = true
            local rDurabilityAlert = CreateSpaciousRow(
                cQoL, -294,
                "Low Durability Alert Toast",
                "Shows a 1-click alert toast when any equipped gear slot drops to or below your durability threshold (summons a repair mount outdoors or opens your gear).",
                156
            )
            local pillsDurability = CreateSegmentedPills(
                rDurabilityAlert, 156,
                {
                    { value = false, label = "Off" },
                    { value = true,  label = "Enabled" },
                },
                function() return self.db.durabilityAlertEnabled ~= false end,
                function(v)
                    self.db.durabilityAlertEnabled = (v == true)
                    if v == true then
                        ws.durabilityDrawerOpen = true
                        self:RequestDurabilityCheck("TOGGLE", 0.1)
                    else
                        self:HideDurabilityToast()
                    end
                    self:RefreshWorkspaceView()
                end
            )
            rDurabilityAlert:BindRightControl(pillsDurability)
            table.insert(self.refreshWidgets, pillsDurability)

            local tuneDurability = CreateSubDrawerToggleBar(
                cQoL, 2,
                function() return self.db and self.db.durabilityAlertEnabled ~= false end,
                function() return ws.durabilityDrawerOpen ~= false end,
                function()
                    ws.durabilityDrawerOpen = (ws.durabilityDrawerOpen == false)
                    self:RefreshWorkspaceView()
                end
            )
            rDurabilityAlert.tuneBtn = tuneDurability
            table.insert(self.refreshWidgets, tuneDurability)

            local dDurThresh = CreateInlineSubDrawer(cQoL, "Alert Threshold (Lowest Equipped Slot)")
            local sDurThresh = CreateObsidianSlider(
                dDurThresh, 256, 10, 40, 5,
                function(val) return string.format("%d%%", val) end,
                function() return self.db.durabilityAlertThreshold or 20 end,
                function(val)
                    self.db.durabilityAlertThreshold = val
                    self:RequestDurabilityCheck("TOGGLE", 0.1)
                end
            )
            dDurThresh:BindRightControl(sDurThresh)
            table.insert(self.refreshWidgets, sDurThresh)

            local dDurTest = CreateInlineSubDrawer(cQoL, "Current Lowest Slot: 100% (Average: 100%)")
            local btnTestDurToast = CreateFrame("Button", nil, dDurTest, "BackdropTemplate")
            btnTestDurToast:SetSize(156, 26)
            btnTestDurToast.txt = CreateText(btnTestDurToast, "OVERLAY", "GameFontHighlightSmall")
            btnTestDurToast.txt:SetPoint("CENTER")
            btnTestDurToast.txt:SetWordWrap(false)
            btnTestDurToast.txt:SetText("Test Toast")
            function btnTestDurToast:RefreshValue()
                local ar, ag, ab = GetActiveAccentRGB()
                SetPixelBackdrop(self, COLORS.BgElevated, { ar, ag, ab, 0.90 }, 1)
                local _, low, avg = DynamicPrep:GetDurabilityData()
                dDurTest.title:SetText(string.format("|cFFCBD5E1Current Lowest Slot:|r |cFF34D399%d%%|r |cFF64748B(Average: %d%%)|r", low or 100, avg or 100))
            end
            btnTestDurToast:SetScript("OnEnter", function(selfBtn)
                local ar, ag, ab = GetActiveAccentRGB()
                SetPixelBackdrop(selfBtn, COLORS.BgHover, { ar, ag, ab, 1.0 }, 1)
            end)
            btnTestDurToast:SetScript("OnLeave", function(selfBtn)
                selfBtn:RefreshValue()
            end)
            btnTestDurToast:SetScript("OnClick", function()
                DynamicPrep:TriggerDurabilityToastPreview()
            end)
            dDurTest:BindRightControl(btnTestDurToast)
            table.insert(self.refreshWidgets, btnTestDurToast)

            -- 9. Red Error Text & Sound Filter + 3-Row Sub-Drawer
            ws.errorFilterDrawerOpen = true
            local rErrorFilter = CreateSpaciousRow(
                cQoL, -294,
                "Red Error Text & Sound Filter",
                "Hides repetitive red combat and movement errors and optionally mutes error voice lines. Quest, encounter, and system messages are never hidden.",
                156
            )
            local pillsErrorFilter = CreateSegmentedPills(
                rErrorFilter, 156,
                {
                    { value = false, label = "Off" },
                    { value = true,  label = "Enabled" },
                },
                function() return self.db.errorFilterEnabled == true end,
                function(v)
                    self.db.errorFilterEnabled = (v == true)
                    if v == true then
                        ws.errorFilterDrawerOpen = true
                    end
                    self:SyncErrorFilterState(false)
                    self:RefreshWorkspaceView()
                end
            )
            rErrorFilter:BindRightControl(pillsErrorFilter)
            table.insert(self.refreshWidgets, pillsErrorFilter)

            local dErrorYieldNote = CreateInlineSubDrawer(cQoL, "Auto-yielding to external addon.")
            dErrorYieldNote.title:SetTextColor(0.220, 0.741, 0.973, 1.0)
            function dErrorYieldNote:RefreshValue()
                local yieldAddon, friendlyName = DynamicPrep:GetErrorFilterYieldAddon()
                if yieldAddon then
                    local hint = (_G.DynamicSuite and _G.DynamicSuite._isHubLoaded)
                        and "Override in /ds conflicts."
                        or ("Disable in " .. tostring(friendlyName) .. " to use DynamicPrep.")
                    self.title:SetText("Auto-yielding to " .. tostring(friendlyName) .. " (handling UI error filtering). " .. hint)
                end
            end
            table.insert(self.refreshWidgets, dErrorYieldNote)

            local tuneErrorFilter = CreateSubDrawerToggleBar(
                cQoL, 3,
                function() return self.db and self.db.errorFilterEnabled == true end,
                function() return ws.errorFilterDrawerOpen ~= false end,
                function()
                    ws.errorFilterDrawerOpen = (ws.errorFilterDrawerOpen == false)
                    self:RefreshWorkspaceView()
                end
            )
            rErrorFilter.tuneBtn = tuneErrorFilter
            table.insert(self.refreshWidgets, tuneErrorFilter)

            local dErrCombat = CreateInlineSubDrawer(cQoL, "Hide Combat & Cooldown Spam")
            dErrCombat:HookScript("OnEnter", function(selfRow)
                if GameTooltip then
                    local ar, ag, ab = GetActiveAccentRGB()
                    GameTooltip:SetOwner(selfRow, "ANCHOR_TOP")
                    GameTooltip:AddLine("Hide Combat & Cooldown Spam", ar, ag, ab)
                    GameTooltip:AddLine("Suppresses 'Ability is not ready yet', 'Another action is in progress', 'Not enough mana/energy/rage/focus/runic power/fury/insanity/astral power', 'Out of range', and 'Target needs to be in front of you'.", 0.88, 0.91, 0.96, true)
                    GameTooltip:Show()
                end
            end)
            dErrCombat:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            local pErrCombat = CreateSegmentedPills(
                dErrCombat, 156,
                {
                    { value = false, label = "Off" },
                    { value = true,  label = "Enabled" },
                },
                function() return self.db.errorFilterHideCombatSpam ~= false end,
                function(v)
                    self.db.errorFilterHideCombatSpam = (v == true)
                    self:SyncErrorFilterState(false)
                    self:RefreshWorkspaceView()
                end
            )
            dErrCombat:BindRightControl(pErrCombat)
            table.insert(self.refreshWidgets, pErrCombat)

            local dErrMove = CreateInlineSubDrawer(cQoL, "Hide Movement & Mount Errors")
            dErrMove:HookScript("OnEnter", function(selfRow)
                if GameTooltip then
                    local ar, ag, ab = GetActiveAccentRGB()
                    GameTooltip:SetOwner(selfRow, "ANCHOR_TOP")
                    GameTooltip:AddLine("Hide Movement & Mount Errors", ar, ag, ab)
                    GameTooltip:AddLine("Suppresses 'Can't do that while moving', 'You are mounted', and 'You cannot use that while moving'.", 0.88, 0.91, 0.96, true)
                    GameTooltip:Show()
                end
            end)
            dErrMove:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            local pErrMove = CreateSegmentedPills(
                dErrMove, 156,
                {
                    { value = false, label = "Off" },
                    { value = true,  label = "Enabled" },
                },
                function() return self.db.errorFilterHideMovement ~= false end,
                function(v)
                    self.db.errorFilterHideMovement = (v == true)
                    self:SyncErrorFilterState(false)
                    self:RefreshWorkspaceView()
                end
            )
            dErrMove:BindRightControl(pErrMove)
            table.insert(self.refreshWidgets, pErrMove)

            local dErrSpeech = CreateInlineSubDrawer(cQoL, "Mute Error Voice Lines")
            dErrSpeech:HookScript("OnEnter", function(selfRow)
                if GameTooltip then
                    local ar, ag, ab = GetActiveAccentRGB()
                    GameTooltip:SetOwner(selfRow, "ANCHOR_TOP")
                    GameTooltip:AddLine("Mute Error Voice Lines", ar, ag, ab)
                    GameTooltip:AddLine("Toggles Sound_EnableErrorSpeech to silence 'I can't cast that yet' voice lines, and restores your original setting when turned off or if DynamicPrep is disabled.", 0.88, 0.91, 0.96, true)
                    GameTooltip:Show()
                end
            end)
            dErrSpeech:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            local pErrSpeech = CreateSegmentedPills(
                dErrSpeech, 156,
                {
                    { value = false, label = "Off" },
                    { value = true,  label = "Enabled" },
                },
                function() return self.db.errorFilterMuteSpeech == true end,
                function(v)
                    self.db.errorFilterMuteSpeech = (v == true)
                    self:SyncErrorFilterState(false)
                    self:RefreshWorkspaceView()
                end
            )
            dErrSpeech:BindRightControl(pErrSpeech)
            table.insert(self.refreshWidgets, pErrSpeech)

            return {
                rDrinkMacro = rDrinkMacro, tuneDrinkMacro = tuneDrinkMacro,
                dDrinkDrawers = { dDrinkMacro, dDrinkRecup, dDrinkBuffFood },
                rMageFood = rMageFood, tuneMageFood = tuneMageFood,
                dMageDrawers = { dMageScope, dMageMin, dMageLeave, dMageTest },
                rDurabilityAlert = rDurabilityAlert, tuneDurability = tuneDurability,
                dDurDrawers = { dDurThresh, dDurTest },
                rErrorFilter = rErrorFilter, tuneErrorFilter = tuneErrorFilter,
                dErrorYieldNote = dErrorYieldNote,
                dErrorDrawers = { dErrCombat, dErrMove, dErrSpeech },
            }
        end
        local recRows = BuildRecoveryQoLRows()

        ws.qolRows = {
            rHealMacro       = rHealMacro,
            tuneHealMacro    = tuneHealMacro,
            dHealMacro       = dHealMacro,
            rDrinkMacro      = recRows.rDrinkMacro,
            tuneDrinkMacro   = recRows.tuneDrinkMacro,
            dDrinkDrawers    = recRows.dDrinkDrawers,
            rMageFood        = recRows.rMageFood,
            tuneMageFood     = recRows.tuneMageFood,
            dMageDrawers     = recRows.dMageDrawers,
            rDurabilityAlert = recRows.rDurabilityAlert,
            tuneDurability   = recRows.tuneDurability,
            dDurDrawers      = recRows.dDurDrawers,
            rErrorFilter     = recRows.rErrorFilter,
            tuneErrorFilter  = recRows.tuneErrorFilter,
            dErrorYieldNote  = recRows.dErrorYieldNote,
            dErrorDrawers    = recRows.dErrorDrawers,
            others           = { rQuestGossip, rAutoConfirmInstanceGossip, rAutoChoice, rCatalyst, rAutoSummon, rCine, rRez, rRelease },
        }
    end

    self.workspaceFrame:Show()
    self:RefreshWorkspaceView()
    return self.workspaceFrame
end

function DynamicPrep:LayoutTab1CardRows()
    local ws = self.workspaceFrame
    if not ws or not ws.card1 or not ws.tab1Rows then return 758 end
    local card1 = ws.card1
    local tr = ws.tab1Rows
    local stripH = (ws.pillStrip and ws.pillStrip.GetHeight and ws.pillStrip:GetHeight()) or 200
    local y = -(54 + math.floor(stripH + 0.5) + 8)

    for _, row in ipairs({ tr.rBorder, tr.rColorTheme, tr.rStatSort }) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", card1, "TOPLEFT", 14, y)
        row:SetPoint("TOPRIGHT", card1, "TOPRIGHT", -14, y)
        y = y - 60
    end

    local sortMode = (self.db and (self.db.secondaryStatOrderMode or self.db.statSortMode)) or "RANK"
    local hasStatSub = (sortMode == "CUSTOM" or sortMode == "FIXED")
    local tuneStat = tr.tuneStatSort or (tr.rStatSort and tr.rStatSort.tuneBtn)
    if tuneStat then
        tuneStat:RefreshValue()
    end
    if hasStatSub and tuneStat then
        tuneStat:ClearAllPoints()
        tuneStat:SetPoint("TOPLEFT", card1, "TOPLEFT", 14, y + 2)
        tuneStat:SetPoint("TOPRIGHT", card1, "TOPRIGHT", -14, y + 2)
        tuneStat:Show()
        y = y - 28

        if ws.statSortDrawerOpen ~= false then
            tr.dCustomStatOrder:ClearAllPoints()
            tr.dCustomStatOrder:SetPoint("TOPLEFT", card1, "TOPLEFT", 14, y + 2)
            tr.dCustomStatOrder:SetPoint("TOPRIGHT", card1, "TOPRIGHT", -14, y + 2)
            tr.dCustomStatOrder:RefreshBranchAccent()
            tr.dCustomStatOrder:Show()
            y = y - 46
        else
            tr.dCustomStatOrder:Hide()
        end
    else
        if tuneStat then tuneStat:Hide() end
        tr.dCustomStatOrder:Hide()
    end

    if tr.rPingFormat then
        tr.rPingFormat:ClearAllPoints()
        tr.rPingFormat:SetPoint("TOPLEFT", card1, "TOPLEFT", 14, y)
        tr.rPingFormat:SetPoint("TOPRIGHT", card1, "TOPRIGHT", -14, y)
        y = y - 60

        local pingMode = (self.db and self.db.pingDisplayMode) or "BOTH"
        local hasPingSub = (pingMode == "BOTH")
        local tunePing = tr.tunePingFormat or (tr.rPingFormat and tr.rPingFormat.tuneBtn)
        if tunePing then
            tunePing:RefreshValue()
        end
        if hasPingSub and tunePing then
            tunePing:ClearAllPoints()
            tunePing:SetPoint("TOPLEFT", card1, "TOPLEFT", 14, y + 2)
            tunePing:SetPoint("TOPRIGHT", card1, "TOPRIGHT", -14, y + 2)
            tunePing:Show()
            y = y - 28

            if ws.pingDrawerOpen ~= false then
                tr.dPingOrder:ClearAllPoints()
                tr.dPingOrder:SetPoint("TOPLEFT", card1, "TOPLEFT", 14, y + 2)
                tr.dPingOrder:SetPoint("TOPRIGHT", card1, "TOPRIGHT", -14, y + 2)
                tr.dPingOrder:RefreshBranchAccent()
                tr.dPingOrder:Show()
                y = y - 46
            else
                tr.dPingOrder:Hide()
            end
        else
            if tunePing then tunePing:Hide() end
            if tr.dPingOrder then tr.dPingOrder:Hide() end
        end
    end

    for _, row in ipairs(tr.others) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", card1, "TOPLEFT", 14, y)
        row:SetPoint("TOPRIGHT", card1, "TOPRIGHT", -14, y)
        y = y - 60
    end

    local totalH = math.abs(y) + 28
    card1:SetHeight(totalH)
    return totalH
end

function DynamicPrep:LayoutQoLCardRows()
    local ws = self.workspaceFrame
    if not ws or not ws.qolCard or not ws.qolRows then return 440 end
    local cQoL = ws.qolCard
    local qr = ws.qolRows
    local y = -54

    for _, row in ipairs(qr.others) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", cQoL, "TOPLEFT", 14, y)
        row:SetPoint("TOPRIGHT", cQoL, "TOPRIGHT", -14, y)
        y = y - 60
    end

    if qr.rHealMacro then
        qr.rHealMacro:ClearAllPoints()
        qr.rHealMacro:SetPoint("TOPLEFT", cQoL, "TOPLEFT", 14, y)
        qr.rHealMacro:SetPoint("TOPRIGHT", cQoL, "TOPRIGHT", -14, y)
        y = y - 60

        local healEnabled = self.db and self.db.autoHealMacroEnabled ~= false and (self.db.healMacroOrder or "STONE_FIRST") ~= "OFF"
        local tuneHeal = qr.tuneHealMacro or (qr.rHealMacro and qr.rHealMacro.tuneBtn)
        if tuneHeal then
            tuneHeal:RefreshValue()
        end
        if healEnabled and tuneHeal then
            tuneHeal:ClearAllPoints()
            tuneHeal:SetPoint("TOPLEFT", cQoL, "TOPLEFT", 14, y + 2)
            tuneHeal:SetPoint("TOPRIGHT", cQoL, "TOPRIGHT", -14, y + 2)
            tuneHeal:Show()
            y = y - 28

            if ws.healDrawerOpen ~= false then
                qr.dHealMacro:ClearAllPoints()
                qr.dHealMacro:SetPoint("TOPLEFT", cQoL, "TOPLEFT", 14, y + 2)
                qr.dHealMacro:SetPoint("TOPRIGHT", cQoL, "TOPRIGHT", -14, y + 2)
                qr.dHealMacro:RefreshBranchAccent()
                qr.dHealMacro:Show()
                y = y - 46
            else
                qr.dHealMacro:Hide()
            end
        else
            if tuneHeal then tuneHeal:Hide() end
            if qr.dHealMacro then qr.dHealMacro:Hide() end
        end
    end

    if qr.rDrinkMacro then
        qr.rDrinkMacro:ClearAllPoints()
        qr.rDrinkMacro:SetPoint("TOPLEFT", cQoL, "TOPLEFT", 14, y)
        qr.rDrinkMacro:SetPoint("TOPRIGHT", cQoL, "TOPRIGHT", -14, y)
        y = y - 60

        local drinkEnabled = self.db and (self.db.drinkMacroMode or "ROLE_SMART") ~= "OFF"
        local tuneDrink = qr.tuneDrinkMacro or (qr.rDrinkMacro and qr.rDrinkMacro.tuneBtn)
        if tuneDrink then tuneDrink:RefreshValue() end
        if drinkEnabled and tuneDrink then
            tuneDrink:ClearAllPoints()
            tuneDrink:SetPoint("TOPLEFT", cQoL, "TOPLEFT", 14, y + 2)
            tuneDrink:SetPoint("TOPRIGHT", cQoL, "TOPRIGHT", -14, y + 2)
            tuneDrink:Show()
            y = y - 28

            for _, dr in ipairs(qr.dDrinkDrawers or {}) do
                if ws.drinkDrawerOpen ~= false then
                    dr:ClearAllPoints()
                    dr:SetPoint("TOPLEFT", cQoL, "TOPLEFT", 14, y + 2)
                    dr:SetPoint("TOPRIGHT", cQoL, "TOPRIGHT", -14, y + 2)
                    dr:RefreshBranchAccent()
                    dr:Show()
                    y = y - 46
                else
                    dr:Hide()
                end
            end
        else
            if tuneDrink then tuneDrink:Hide() end
            for _, dr in ipairs(qr.dDrinkDrawers or {}) do dr:Hide() end
        end
    end

    if qr.rMageFood then
        qr.rMageFood:ClearAllPoints()
        qr.rMageFood:SetPoint("TOPLEFT", cQoL, "TOPLEFT", 14, y)
        qr.rMageFood:SetPoint("TOPRIGHT", cQoL, "TOPRIGHT", -14, y)
        y = y - 60

        local mageEnabled = self.db and self.db.mageFoodRestockEnabled ~= false
        local tuneMage = qr.tuneMageFood or (qr.rMageFood and qr.rMageFood.tuneBtn)
        if tuneMage then tuneMage:RefreshValue() end
        if mageEnabled and tuneMage then
            tuneMage:ClearAllPoints()
            tuneMage:SetPoint("TOPLEFT", cQoL, "TOPLEFT", 14, y + 2)
            tuneMage:SetPoint("TOPRIGHT", cQoL, "TOPRIGHT", -14, y + 2)
            tuneMage:Show()
            y = y - 28

            for _, dr in ipairs(qr.dMageDrawers or {}) do
                if ws.mageFoodDrawerOpen ~= false then
                    dr:ClearAllPoints()
                    dr:SetPoint("TOPLEFT", cQoL, "TOPLEFT", 14, y + 2)
                    dr:SetPoint("TOPRIGHT", cQoL, "TOPRIGHT", -14, y + 2)
                    dr:RefreshBranchAccent()
                    dr:Show()
                    y = y - 46
                else
                    dr:Hide()
                end
            end
        else
            if tuneMage then tuneMage:Hide() end
            for _, dr in ipairs(qr.dMageDrawers or {}) do dr:Hide() end
        end
    end

    if qr.rDurabilityAlert then
        qr.rDurabilityAlert:ClearAllPoints()
        qr.rDurabilityAlert:SetPoint("TOPLEFT", cQoL, "TOPLEFT", 14, y)
        qr.rDurabilityAlert:SetPoint("TOPRIGHT", cQoL, "TOPRIGHT", -14, y)
        y = y - 60

        local durEnabled = self.db and self.db.durabilityAlertEnabled ~= false
        local tuneDur = qr.tuneDurability or (qr.rDurabilityAlert and qr.rDurabilityAlert.tuneBtn)
        if tuneDur then tuneDur:RefreshValue() end
        if durEnabled and tuneDur then
            tuneDur:ClearAllPoints()
            tuneDur:SetPoint("TOPLEFT", cQoL, "TOPLEFT", 14, y + 2)
            tuneDur:SetPoint("TOPRIGHT", cQoL, "TOPRIGHT", -14, y + 2)
            tuneDur:Show()
            y = y - 28

            for _, dr in ipairs(qr.dDurDrawers or {}) do
                if ws.durabilityDrawerOpen ~= false then
                    dr:ClearAllPoints()
                    dr:SetPoint("TOPLEFT", cQoL, "TOPLEFT", 14, y + 2)
                    dr:SetPoint("TOPRIGHT", cQoL, "TOPRIGHT", -14, y + 2)
                    dr:RefreshBranchAccent()
                    dr:Show()
                    y = y - 46
                else
                    dr:Hide()
                end
            end
        else
            if tuneDur then tuneDur:Hide() end
            for _, dr in ipairs(qr.dDurDrawers or {}) do dr:Hide() end
        end
    end

    if qr.rErrorFilter then
        qr.rErrorFilter:ClearAllPoints()
        qr.rErrorFilter:SetPoint("TOPLEFT", cQoL, "TOPLEFT", 14, y)
        qr.rErrorFilter:SetPoint("TOPRIGHT", cQoL, "TOPRIGHT", -14, y)
        y = y - 60

        local isYieldingErr = (self:GetErrorFilterYieldAddon() ~= nil)
        if qr.dErrorYieldNote then
            if isYieldingErr then
                qr.dErrorYieldNote:ClearAllPoints()
                qr.dErrorYieldNote:SetPoint("TOPLEFT", cQoL, "TOPLEFT", 14, y + 2)
                qr.dErrorYieldNote:SetPoint("TOPRIGHT", cQoL, "TOPRIGHT", -14, y + 2)
                qr.dErrorYieldNote:RefreshValue()
                qr.dErrorYieldNote:Show()
                y = y - 46
            else
                qr.dErrorYieldNote:Hide()
            end
        end

        local errEnabled = self.db and self.db.errorFilterEnabled == true
        local tuneErr = qr.tuneErrorFilter or (qr.rErrorFilter and qr.rErrorFilter.tuneBtn)
        if tuneErr then tuneErr:RefreshValue() end
        if errEnabled and tuneErr then
            tuneErr:ClearAllPoints()
            tuneErr:SetPoint("TOPLEFT", cQoL, "TOPLEFT", 14, y + 2)
            tuneErr:SetPoint("TOPRIGHT", cQoL, "TOPRIGHT", -14, y + 2)
            tuneErr:Show()
            y = y - 28

            for _, dr in ipairs(qr.dErrorDrawers or {}) do
                if ws.errorFilterDrawerOpen ~= false then
                    dr:ClearAllPoints()
                    dr:SetPoint("TOPLEFT", cQoL, "TOPLEFT", 14, y + 2)
                    dr:SetPoint("TOPRIGHT", cQoL, "TOPRIGHT", -14, y + 2)
                    dr:RefreshBranchAccent()
                    dr:Show()
                    y = y - 46
                else
                    dr:Hide()
                end
            end
        else
            if tuneErr then tuneErr:Hide() end
            for _, dr in ipairs(qr.dErrorDrawers or {}) do dr:Hide() end
        end
    end

    local totalH = math.abs(y) + 12
    cQoL:SetHeight(totalH)
    return totalH
end

function DynamicPrep:RefreshWorkspaceView()
    local ws = self.workspaceFrame
    if not ws or not ws:IsShown() then return end

    local ar, ag, ab = GetActiveAccentRGB()
    for _, item in ipairs(trackedAccentTexts) do
        if item and item.fs and item.fs.SetTextColor then
            item.fs:SetTextColor(ar, ag, ab, 1.0)
        end
    end

    if ws.sbThumb and ws.sbThumb.SetVertexColor then
        ws.sbThumb:SetVertexColor(0.38, 0.45, 0.56, 0.85)
    end
    if ws.tabStrip and ws.tabButtons and #ws.tabButtons >= 3 then
        local stripW = ws.tabStrip:GetWidth()
        if stripW and stripW > 100 then
            local bw = math.floor((stripW - 16) / 3)
            ws.tabButtons[1]:ClearAllPoints()
            ws.tabButtons[1]:SetPoint("LEFT", ws.tabStrip, "LEFT", 4, 0)
            ws.tabButtons[1]:SetSize(bw, 26)

            ws.tabButtons[2]:ClearAllPoints()
            ws.tabButtons[2]:SetPoint("LEFT", ws.tabButtons[1], "RIGHT", 4, 0)
            ws.tabButtons[2]:SetSize(bw, 26)

            ws.tabButtons[3]:ClearAllPoints()
            ws.tabButtons[3]:SetPoint("LEFT", ws.tabButtons[2], "RIGHT", 4, 0)
            ws.tabButtons[3]:SetPoint("RIGHT", ws.tabStrip, "RIGHT", -4, 0)
            ws.tabButtons[3]:SetHeight(26)
        end
    end
    if ws.scrollFrame and ws.scrollChild then
        local sfW = ws.scrollFrame:GetWidth()
        if sfW and sfW > 100 then
            ws.scrollChild:SetWidth(sfW)
        end
    end
    local activeTab = (self.db and self.db.activeSubTab) or 1
    for i, tBtn in ipairs(ws.tabButtons) do
        local isSelected = (i == activeTab)
        SetPixelBackdrop(
            tBtn,
            isSelected and { ar * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), ag * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), ab * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), 0.98 } or { 0.078, 0.090, 0.122, 0.96 },
            isSelected and { ar, ag, ab, 0.95 } or { 0.145, 0.165, 0.212, 0.95 },
            1
        )
        if isSelected then
            tBtn.label:SetTextColor(1.0, 1.0, 1.0, 1.0)
        else
            tBtn.label:SetTextColor(0.68, 0.74, 0.82, 1.0)
        end
    end

    if ws.tab1 then ws.tab1:SetShown(activeTab == 1) end
    if ws.tab2 then ws.tab2:SetShown(activeTab == 2) end
    if ws.tab3 then ws.tab3:SetShown(activeTab == 3) end

    local card1H = self:LayoutTab1CardRows()
    local tab1TotalH = card1H + 14
    local tab2TotalH = (ws.raidBuffsCard and ws.raidBuffsCard:GetHeight() or 728) + 14 + (ws.card2 and ws.card2:GetHeight() or 422) + 14
    if ws.tab1 then ws.tab1:SetHeight(tab1TotalH) end
    if ws.tab2 then ws.tab2:SetHeight(tab2TotalH) end
    if self.RefreshReadinessTrackerStrip then
        pcall(self.RefreshReadinessTrackerStrip, self)
    end

    -- Refresh 10 Interactive Pill Cards in 4x3 Grid with Tactile Floating Ghost Drag-and-Drop
    if ws.pillCards and self.db and self.db.segmentOrder then
        self:LayoutPillGrid()
        for idx, segKey in ipairs(self.db.segmentOrder) do
            local pCard = ws.pillCards[idx]
            local meta = SEGMENT_META[segKey]
            if pCard and meta then
                local enabled = self.db.segments and self.db.segments[segKey]
                local isBeingDragged = (ws.dragState and ws.dragState.isDragging and ws.dragState.segKey == segKey)
                SetPixelBackdrop(
                    pCard,
                    enabled and COLORS.BgElevated or COLORS.BgSurface,
                    isBeingDragged and { ar, ag, ab, 1.0 } or (enabled and { ar, ag, ab, 0.85 } or COLORS.BorderSubtle),
                    1
                )
                -- Dim origin slot to 35% alpha while lifted into floating ghost pill (Item #19)
                pCard:SetAlpha(isBeingDragged and 0.35 or 1.0)
                pCard.label:SetText(string.format("%s%d. %s|r", enabled and "|cFFFFFFFF" or "|cFF64748B", idx, meta.short))

                pCard:SetScript("OnMouseDown", function(_, button)
                    if button ~= "LeftButton" then return end
                    local scale = UIParent:GetEffectiveScale() or 1
                    local cx, cy = GetCursorPosition()
                    cx, cy = cx / scale, cy / scale
                    ws.dragState = {
                        segKey = segKey,
                        startX = cx,
                        startY = cy,
                        isDragging = false,
                    }
                    ws.pillStrip:SetScript("OnUpdate", function(gridFrame)
                        local st = ws.dragState
                        if not st then
                            gridFrame:SetScript("OnUpdate", nil)
                            if self.dragGhostPill then self.dragGhostPill:Hide() end
                            return
                        end
                        if not IsMouseButtonDown("LeftButton") then
                            gridFrame:SetScript("OnUpdate", nil)
                            ws.dragState = nil
                            if self.dragGhostPill then self.dragGhostPill:Hide() end
                            self:RefreshWorkspaceView()
                            return
                        end
                        local s = UIParent:GetEffectiveScale() or 1
                        local mx, my = GetCursorPosition()
                        mx, my = mx / s, my / s
                        local dx = mx - st.startX
                        local dy = my - st.startY
                        if not st.isDragging and ((dx * dx + dy * dy) > 36) then
                            st.isDragging = true
                            local ghost = self:EnsureDragGhostPill()
                            local r, g, b = GetActiveAccentRGB()
                            SetPixelBackdrop(ghost, COLORS.BgElevated, { r, g, b, 1.0 }, 1)
                            local draggedMeta = SEGMENT_META[st.segKey]
                            ghost.label:SetText(string.format("|cFFFFFFFF%s|r", draggedMeta and draggedMeta.short or st.segKey))
                            ghost:Show()
                            self:RefreshWorkspaceView()
                        end
                        if st.isDragging then
                            local ghost = self:EnsureDragGhostPill()
                            local gs = ghost:GetEffectiveScale() or 1
                            local rawX, rawY = GetCursorPosition()
                            ghost:ClearAllPoints()
                            ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", rawX / gs, rawY / gs)

                            local gLeft = gridFrame:GetLeft()
                            local gTop = gridFrame:GetTop()
                            local gWidth = gridFrame:GetWidth()
                            local gHeight = gridFrame:GetHeight()
                            if gLeft and gTop and gWidth and gWidth > 0 and gHeight and gHeight > 0 then
                                local relX = mx - gLeft
                                local relY = gTop - my
                                local numRows = math.ceil(#DEFAULT_SEGMENT_ORDER / 3)
                                local col = math.floor((relX / gWidth) * 3)
                                local row = math.floor((relY / gHeight) * numRows)
                                col = math.max(0, math.min(2, col))
                                row = math.max(0, math.min(numRows - 1, row))
                                local targetSlot = math.max(1, math.min(#DEFAULT_SEGMENT_ORDER, row * 3 + col + 1))

                                local order = self.db and self.db.segmentOrder
                                if order then
                                    local curSlot = nil
                                    for i, k in ipairs(order) do
                                        if k == st.segKey then
                                            curSlot = i
                                            break
                                        end
                                    end
                                    if curSlot and curSlot ~= targetSlot then
                                        table.remove(order, curSlot)
                                        table.insert(order, targetSlot, st.segKey)
                                        self:RefreshBar()
                                        self:RefreshWorkspaceView()
                                    end
                                end
                            end
                        end
                    end)
                end)

                pCard:SetScript("OnMouseUp", function(_, button)
                    if button ~= "LeftButton" then return end
                    if ws.pillStrip then
                        ws.pillStrip:SetScript("OnUpdate", nil)
                    end
                    if self.dragGhostPill then
                        self.dragGhostPill:Hide()
                    end
                    local st = ws.dragState
                    ws.dragState = nil
                    if st and not st.isDragging and st.segKey then
                        self.db.segments[st.segKey] = not self.db.segments[st.segKey]
                        self:RefreshBar()
                    end
                    self:RefreshWorkspaceView()
                end)

                pCard.leftBtn.icon:SetVertexColor(enabled and ar or 0.62, enabled and ag or 0.68, enabled and ab or 0.76, enabled and 0.95 or 0.85)
                pCard.rightBtn.icon:SetVertexColor(enabled and ar or 0.62, enabled and ag or 0.68, enabled and ab or 0.76, enabled and 0.95 or 0.85)
                pCard.leftBtn:SetScript("OnEnter", function(selfBtn)
                    SetPixelBackdrop(selfBtn, COLORS.BgHover, { ar, ag, ab, 0.90 }, 1)
                    selfBtn.icon:SetVertexColor(1, 1, 1, 1.0)
                end)
                pCard.leftBtn:SetScript("OnLeave", function(selfBtn)
                    SetPixelBackdrop(selfBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
                    selfBtn.icon:SetVertexColor(enabled and ar or 0.62, enabled and ag or 0.68, enabled and ab or 0.76, enabled and 0.95 or 0.85)
                end)
                pCard.rightBtn:SetScript("OnEnter", function(selfBtn)
                    SetPixelBackdrop(selfBtn, COLORS.BgHover, { ar, ag, ab, 0.90 }, 1)
                    selfBtn.icon:SetVertexColor(1, 1, 1, 1.0)
                end)
                pCard.rightBtn:SetScript("OnLeave", function(selfBtn)
                    SetPixelBackdrop(selfBtn, COLORS.BgElevated, COLORS.BorderSubtle, 1)
                    selfBtn.icon:SetVertexColor(enabled and ar or 0.62, enabled and ag or 0.68, enabled and ab or 0.76, enabled and 0.95 or 0.85)
                end)
                pCard.leftBtn:SetScript("OnClick", function()
                    self:MoveSegmentOrder(segKey, -1)
                end)
                pCard.rightBtn:SetScript("OnClick", function()
                    self:MoveSegmentOrder(segKey, 1)
                end)
                pCard:Show()
            end
        end
    end

    -- Refresh 4 Interactive Custom Secondary Stat Order Pills in Connected Sub-Drawer
    if ws.statOrderPills and self.db and self.db.customSecondaryOrder then
        for idx = 1, 4 do
            local sp = ws.statOrderPills[idx]
            local statKey = self.db.customSecondaryOrder[idx] or DEFAULT_CUSTOM_SECONDARY_ORDER[idx]
            local statShort = STAT_SHORT[statKey] or statKey
            if sp and statKey then
                local isDraggingStat = (ws.statDragState and ws.statDragState.isDragging and ws.statDragState.statKey == statKey)
                SetPixelBackdrop(
                    sp,
                    COLORS.BgElevated,
                    isDraggingStat and { ar, ag, ab, 1.0 } or { ar, ag, ab, 0.85 },
                    1
                )
                sp:SetAlpha(isDraggingStat and 0.35 or 1.0)
                sp.label:SetText(string.format("|cFFFFFFFF%d. %s|r", idx, statShort))

                sp:SetScript("OnMouseDown", function(_, button)
                    if button ~= "LeftButton" and button ~= "RightButton" then return end
                    local scale = UIParent:GetEffectiveScale() or 1
                    local cx, cy = GetCursorPosition()
                    cx, cy = cx / scale, cy / scale
                    ws.statDragState = {
                        statKey = statKey,
                        button = button,
                        startX = cx,
                        startY = cy,
                        isDragging = false,
                    }
                    if button == "LeftButton" and ws.statOrderStrip then
                        ws.statOrderStrip:SetScript("OnUpdate", function(stripFrame)
                            local st = ws.statDragState
                            if not st then
                                stripFrame:SetScript("OnUpdate", nil)
                                if self.dragGhostPill then self.dragGhostPill:Hide() end
                                return
                            end
                            if not IsMouseButtonDown("LeftButton") then
                                stripFrame:SetScript("OnUpdate", nil)
                                ws.statDragState = nil
                                if self.dragGhostPill then self.dragGhostPill:Hide() end
                                self:RefreshWorkspaceView()
                                return
                            end
                            local s = UIParent:GetEffectiveScale() or 1
                            local mx, my = GetCursorPosition()
                            mx, my = mx / s, my / s
                            local dx = mx - st.startX
                            local dy = my - st.startY
                            if not st.isDragging and ((dx * dx + dy * dy) > 36) then
                                st.isDragging = true
                                local ghost = self:EnsureDragGhostPill()
                                ghost:SetSize(96, 26)
                                local r, g, b = GetActiveAccentRGB()
                                SetPixelBackdrop(ghost, COLORS.BgElevated, { r, g, b, 1.0 }, 1)
                                ghost.label:SetText(string.format("|cFFFFFFFF%s|r", STAT_SHORT[st.statKey] or st.statKey))
                                ghost:Show()
                                self:RefreshWorkspaceView()
                            end
                            if st.isDragging then
                                local ghost = self:EnsureDragGhostPill()
                                local gs = ghost:GetEffectiveScale() or 1
                                local rawX, rawY = GetCursorPosition()
                                ghost:ClearAllPoints()
                                ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", rawX / gs, rawY / gs)

                                local sLeft = stripFrame:GetLeft()
                                local sWidth = stripFrame:GetWidth()
                                if sLeft and sWidth and sWidth > 0 then
                                    local relX = mx - sLeft
                                    local targetSlot = math.floor((relX / sWidth) * 4) + 1
                                    targetSlot = math.max(1, math.min(4, targetSlot))
                                    local order = self.db and self.db.customSecondaryOrder
                                    if order then
                                        local curSlot = nil
                                        for i, k in ipairs(order) do
                                            if k == st.statKey then
                                                curSlot = i
                                                break
                                            end
                                        end
                                        if curSlot and curSlot ~= targetSlot then
                                            table.remove(order, curSlot)
                                            table.insert(order, targetSlot, st.statKey)
                                            self:RefreshBar()
                                            self:RefreshWorkspaceView()
                                        end
                                    end
                                end
                            end
                        end)
                    end
                end)

                sp:SetScript("OnMouseUp", function(_, button)
                    if ws.statOrderStrip then
                        ws.statOrderStrip:SetScript("OnUpdate", nil)
                    end
                    if self.dragGhostPill then
                        self.dragGhostPill:SetSize(210, 32)
                        self.dragGhostPill:Hide()
                    end
                    local st = ws.statDragState
                    ws.statDragState = nil
                    if st and not st.isDragging and st.statKey then
                        if button == "RightButton" then
                            self:MoveCustomSecondaryOrder(st.statKey, 1)
                        else
                            self:MoveCustomSecondaryOrder(st.statKey, -1)
                        end
                        return
                    end
                    self:RefreshWorkspaceView()
                end)
                sp:Show()
            end
        end
    end

    self:RefreshLiveStagePreview()

    -- Refresh Conflict Scanner Card & QoL Layout in Tab 3 (completely hide if #conflicts == 0)
    local qolH = self:LayoutQoLCardRows()
    local tab3TotalH = qolH
    if ws.conflictCard and ws.qolCard and ws.tab3 then
        local conflicts = self:ScanActiveConflicts()
        local cScan = ws.conflictCard
        local cQoL = ws.qolCard
        local hostedInSuite = (_G.DynamicSuite and _G.DynamicSuite.HasUnifiedModuleConflictBanner and _G.DynamicSuiteMainFrame and ws:GetParent() ~= UIParent)

        if #conflicts == 0 or hostedInSuite then
            cScan:Hide()
            cQoL:ClearAllPoints()
            cQoL:SetPoint("TOPLEFT", ws.tab3, "TOPLEFT", 0, 0)
            cQoL:SetPoint("TOPRIGHT", ws.tab3, "TOPRIGHT", 0, 0)
        else
            cScan:Show()
            cScan.statusText:SetText(string.format("|cFFFBBF24Detected %d active overlapping addon(s).|r Choose your preferred resolution below:", #conflicts))

            local directAddon = nil
            local partialAddons = {}
            for _, c in ipairs(conflicts) do
                if c.kind == "DIRECT" and not directAddon then
                    directAddon = c.addon
                elseif c.kind == "PARTIAL" then
                    table.insert(partialAddons, self:GetFriendlyAddonName(c.addon))
                end
            end

            local rowY = -74
            local row1 = cScan.rows[1]
            if directAddon then
                local friendlyDirect = self:GetFriendlyAddonName(directAddon)
                row1:ClearAllPoints()
                row1:SetPoint("TOPLEFT", cScan, "TOPLEFT", 14, rowY)
                row1:SetPoint("TOPRIGHT", cScan, "TOPRIGHT", -14, rowY)
                SetPixelBackdrop(row1.actionBtn, COLORS.BgElevated, { ar, ag, ab, 1.0 }, 1)
                row1.title:SetText(string.format("|cFFFFFFFF%s|r", friendlyDirect))
                row1.label:SetText(string.format("|cFFFBBF24Conflict Detected: %s is currently active and may cause UI errors or blocked actions.|r", friendlyDirect))
                row1.actionBtn.txt:SetText("Use DynamicPrep")
                row1.actionBtn:SetScript("OnClick", function()
                    self:DisableAndFreezeConflictAddon(directAddon)
                end)
                if row1.secondaryBtn then
                    row1.secondaryBtn.txt:SetText("Keep " .. friendlyDirect)
                    row1.secondaryBtn:SetScript("OnClick", function()
                        self:KeepConflictAddon(directAddon)
                    end)
                end
                row1:Show()
                rowY = rowY - 56
            else
                row1:Hide()
            end

            local row2 = cScan.rows[2]
            if #partialAddons > 0 then
                local narrativeConflict = self:GetActiveGossipCameraConflict()
                local yielding = (narrativeConflict ~= nil) or self:IsYieldingSharedHooks()
                row2:ClearAllPoints()
                row2:SetPoint("TOPLEFT", cScan, "TOPLEFT", 14, rowY)
                row2:SetPoint("TOPRIGHT", cScan, "TOPRIGHT", -14, rowY)
                SetPixelBackdrop(row2.actionBtn, COLORS.BgElevated, { ar, ag, ab, 1.0 }, 1)
                row2.title:SetText("|cFFFFFFFF" .. SafeTableConcat(partialAddons, ", ") .. "|r")
                if narrativeConflict then
                    row2.label:SetText(string.format("|cFF38BDF8Auto-Yield Active: Handing gossip/camera control to %s|r", narrativeConflict))
                else
                    row2.label:SetText(
                        yielding and "|cFF34D399Auto-Yield Active: Handing overlapping sub-features to " .. SafeTableConcat(partialAddons, ", ") .. ".|r"
                        or "|cFF94A3B8Yield overlapping sub-features while keeping the Info Bar active.|r"
                    )
                end
                row2.actionBtn.txt:SetText(yielding and "Auto-Yield Active" or "Keep Both (Auto-Yield)")
                row2.actionBtn:SetScript("OnClick", function()
                    self.db.yieldHooks = not self:IsYieldingSharedHooks()
                    self:RefreshWorkspaceView()
                end)
                row2:Show()
                rowY = rowY - 56
            else
                row2:Hide()
            end

            local scanH = math.abs(rowY) + 8
            cScan:SetHeight(scanH)
            cQoL:ClearAllPoints()
            cQoL:SetPoint("TOPLEFT", cScan, "BOTTOMLEFT", 0, -14)
            cQoL:SetPoint("TOPRIGHT", cScan, "BOTTOMRIGHT", 0, -14)
            tab3TotalH = scanH + 14 + qolH
        end
        ws.tab3:SetHeight(tab3TotalH)
    end

    if activeTab == 1 then
        ws.scrollChild:SetHeight(tab1TotalH)
    elseif activeTab == 2 then
        ws.scrollChild:SetHeight(tab2TotalH)
    else
        ws.scrollChild:SetHeight(tab3TotalH)
    end
    if ws.scrollFrame and ws.scrollFrame.UpdateScrollThumb then
        ws.scrollFrame:UpdateScrollThumb()
    end

    -- Refresh all registered dropdowns, segmented pills & sliders
    if self.refreshWidgets then
        for _, w in ipairs(self.refreshWidgets) do
            if w and w.RefreshValue then
                w:RefreshValue()
            end
        end
    end

    self:UpdateSuiteHeaderStatus()
end

-- ============================================================================
-- Atomic Module Reset & Suite Reset Contract
-- ============================================================================
local function ResetPrepModuleDefaults()
    if DynamicPrep.SyncErrorFilterState then
        DynamicPrep:SyncErrorFilterState(true)
    end
    local prevDB = _G.DynamicPrepDB
    local savedWinPos = type(prevDB) == "table" and prevDB.windowPositions or nil
    local savedWinScales = type(prevDB) == "table" and prevDB.windowScales or nil
    local savedNoAutoClose = type(prevDB) == "table" and prevDB.blizzWinNoAutoClose or nil
    local savedDraggable = type(prevDB) == "table" and prevDB.blizzWinDraggable or nil
    local savedScrollScale = type(prevDB) == "table" and prevDB.blizzWinScrollScale or nil
    _G.DynamicPrepDB = nil
    DynamicPrep:InitDB()
    if type(savedWinPos) == "table" then DynamicPrep.db.windowPositions = savedWinPos end
    if type(savedWinScales) == "table" then DynamicPrep.db.windowScales = savedWinScales end
    if savedNoAutoClose ~= nil then DynamicPrep.db.blizzWinNoAutoClose = savedNoAutoClose end
    if savedDraggable ~= nil then DynamicPrep.db.blizzWinDraggable = savedDraggable end
    if savedScrollScale ~= nil then DynamicPrep.db.blizzWinScrollScale = savedScrollScale end
    DynamicPrep:SaveBarEditPosition("TOP", "TOP", 0, -8)
    DynamicPrep.previewZoneKey = nil
    DynamicPrep.previewFolioMismatch = nil
    DynamicPrep:ApplyBarGeometry()
    DynamicPrep:RefreshBar()
    DynamicPrep:RefreshWorkspaceView()
    print(string.format("|cFF%sDynamicPrep:|r Restored all DynamicPrep settings and Info Bar position to defaults.", GetAccentHex()))
end

DynamicPrep.ResetModuleDefaults = ResetPrepModuleDefaults

-- ============================================================================
-- Edit Mode Toggle & HUD Positioning (Non-Recursive Safe Wrappers)
-- ============================================================================
function DynamicPrep:SetBarEditMode(state)
    local enabled = state and true or false
    if enabled and InCombatLockdown and InCombatLockdown() then
        return
    end
    DynamicPrep.inBarEditMode = enabled
    DynamicPrep.inEditMode = (DynamicPrep.inBarEditMode or DynamicPrep.inBuffsEditMode) and true or false
    if enabled then
        GameTooltip:Hide()
        CloseAllDynamicPrepPopups()
    end
    local bar = DynamicPrep.prepBarFrame or (not (InCombatLockdown and InCombatLockdown()) and DynamicPrep:CreatePrepBar())
    if bar then
        if not enabled and bar.mover then
            bar.mover:SetScript("OnUpdate", nil)
        end
        local useInternalMover = enabled and not bar._dsEditModeActive
        if bar.editDragShield then
            bar.editDragShield:SetShown(useInternalMover)
        elseif bar.mover then
            bar.mover:SetShown(useInternalMover)
        end
        if not enabled and bar._dsDragShield then
            bar._dsDragShield:Hide()
        end
        if bar.segmentFrames then
            for _, seg in pairs(bar.segmentFrames) do
                if seg and seg.EnableMouse then
                    seg:EnableMouse(not enabled)
                end
            end
        end
    end
    DynamicPrep:UpdateFolioSecureButton()
    if InCombatLockdown and InCombatLockdown() then
        DynamicPrep.pendingBarRefreshAfterCombat = true
    else
        DynamicPrep:RefreshBar()
    end
end

function DynamicPrep:SetBuffsEditMode(state)
    local enabled = state and true or false
    if enabled and InCombatLockdown and InCombatLockdown() then
        return
    end
    DynamicPrep.inBuffsEditMode = enabled
    DynamicPrep.inEditMode = (DynamicPrep.inBarEditMode or DynamicPrep.inBuffsEditMode) and true or false
    if enabled then
        GameTooltip:Hide()
        CloseAllDynamicPrepPopups()
    end
    local bar = DynamicPrep.clickableBuffBar or (not (InCombatLockdown and InCombatLockdown()) and DynamicPrep:CreateClickableBuffBar())
    if bar then
        if not enabled and bar.mover then
            bar.mover:SetScript("OnUpdate", nil)
        end
        local useInternalMover = enabled and not bar._dsEditModeActive
        if bar.mover then
            bar.mover:SetShown(useInternalMover)
        end
        if not enabled and bar._dsDragShield then
            bar._dsDragShield:Hide()
        end
    end
    if InCombatLockdown and InCombatLockdown() then
        DynamicPrep._pendingCrbAfterCombat = true
    elseif DynamicPrep.RefreshClickableBuffs then
        DynamicPrep:RefreshClickableBuffs(true)
    end
end

function DynamicPrep:SetEditMode(arg1, arg2)
    local enabled
    if arg1 == DynamicPrep or (type(arg1) == "table" and arg2 ~= nil) then
        enabled = arg2
    else
        enabled = arg1
    end
    if enabled and InCombatLockdown and InCombatLockdown() then
        return
    end
    DynamicPrep:SetBarEditMode(enabled)
    DynamicPrep:SetBuffsEditMode(enabled)
end

local function NudgePrepHUD(arg1, arg2, arg3)
    local dx, dy
    if arg1 == DynamicPrep or type(arg1) == "table" then
        dx, dy = tonumber(arg2) or 0, tonumber(arg3) or 0
    else
        dx, dy = tonumber(arg1) or 0, tonumber(arg2) or 0
    end
    DynamicPrep:InitDB()
    local pt, rp, curX, curY = DynamicPrep:GetSavedBarPosition()
    DynamicPrep:SaveBarEditPosition(pt, rp, (curX or 0) + dx, (curY or -8) + dy)
    if InCombatLockdown and InCombatLockdown() then
        DynamicPrep.pendingBarRefreshAfterCombat = true
        return
    end
    DynamicPrep:ApplyBarGeometry()
end

local function ResetPrepHUDPosition(silent)
    if InCombatLockdown and InCombatLockdown() then
        DynamicPrep.pendingBarRefreshAfterCombat = true
        if not silent then
            print("|cFF38BDF8DynamicPrep|r: |cFFF87171Cannot reset protected HUD position during combat lockdown.|r Please wait until combat ends.")
        end
        return false
    end
    DynamicPrep:InitDB()
    DynamicPrep:SaveBarEditPosition("TOP", "TOP", 0, -8)
    DynamicPrep.db.barScale = 1.0
    DynamicPrep.db.barOpacity = 0.95
    DynamicPrep.db.hudBorderStyle = "ACCENT"
    DynamicPrep:ApplyBarBorderStyle()
    DynamicPrep:ApplyBarGeometry()
    return true
end

DynamicPrep.NudgeHUD = NudgePrepHUD
DynamicPrep.ResetHUDPosition = ResetPrepHUDPosition

-- ============================================================================
-- Standalone + Shared 980x680 Resizable Obsidian _G.DynamicSuite Window Shell
-- ============================================================================
function DynamicPrep:UpdateSuiteHeaderStatus()
    local shell = Suite.MainFrame or Suite.mainFrame or self.standaloneShell
    if shell and shell:IsShown() and (shell.activeModuleKey == "prep" or shell.activeModuleKey == "DynamicPrep") then
        if shell.headerModuleTitle then
            shell.headerModuleTitle:SetText("|cFFCBD5E1Dynamic|r|cFFFFFFFFSuite|r")
        end
        if shell.headerVersionBtn and shell.headerVersionBtn.txt then
            shell.headerVersionBtn.txt:SetText("v" .. VERSION)
        end
        if shell.headerStatusText then
            shell.headerStatusText:SetText(self:GetHeaderStatusText())
        end
    end
end

function DynamicPrep:EnsureSuiteWindowShell()
    if Suite.MainFrame or Suite.mainFrame then
        return Suite.MainFrame or Suite.mainFrame
    end

    local gWin = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.window) or { width = 980, height = 680 }
    local win = CreateFrame("Frame", "DynamicSuiteMainFrame", UIParent, "BackdropTemplate")
    win:SetSize(gWin.width or 980, gWin.height or 680)
    win:SetPoint("CENTER")
    win:SetFrameStrata("HIGH")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:SetResizable(true)
    if win.SetResizeBounds then
        win:SetResizeBounds(800, 520, 1380, 900)
    end
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    win:HookScript("OnHide", function()
        CloseAllDynamicPrepPopups()
    end)
    SetPixelBackdrop(win, COLORS.BgVoid, COLORS.BorderStrong, 1)
    win:Hide()

    SafeRegisterUISpecialFrame("DynamicSuiteMainFrame")

    -- Clean 3-Zone Top Header (52px height)
    -- Zone 1: [Logo + Module Name + Clickable Version]
    -- Zone 2: [Spacious 1-Line Status Bar]
    -- Zone 3: [All Characters v + X]
    local header = CreateFrame("Frame", nil, win, "BackdropTemplate")
    header:SetHeight(52)
    header:SetPoint("TOPLEFT", win, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", win, "TOPRIGHT", -1, -1)
    SetPixelBackdrop(header, COLORS.BgCanvas, COLORS.BorderSubtle, 1)

    local logoBox = CreateFrame("Frame", nil, header, "BackdropTemplate")
    logoBox:SetSize(28, 28)
    logoBox:SetPoint("LEFT", header, "LEFT", 14, 0)
    SetPixelBackdrop(logoBox, COLORS.BgElevated, COLORS.BorderStrong, 1)

    local logoWhite = logoBox:CreateTexture(nil, "ARTWORK")
    logoWhite:SetPoint("TOPLEFT", logoBox, "TOPLEFT", 2, -2)
    logoWhite:SetPoint("BOTTOMRIGHT", logoBox, "BOTTOMRIGHT", -2, 2)
    logoWhite:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_white.tga")
    logoWhite:SetVertexColor(1.0, 1.0, 1.0, 1.0)

    local logoAccent = logoBox:CreateTexture(nil, "OVERLAY")
    logoAccent:SetPoint("TOPLEFT", logoBox, "TOPLEFT", 2, -2)
    logoAccent:SetPoint("BOTTOMRIGHT", logoBox, "BOTTOMRIGHT", -2, 2)
    logoAccent:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_accent.tga")
    local ar, ag, ab = GetActiveAccentRGB()
    logoAccent:SetVertexColor(ar, ag, ab, 1.0)
    win.logoAccentTex = logoAccent

    win.headerModuleTitle = CreateText(header, "OVERLAY", "GameFontHighlightLarge")
    win.headerModuleTitle:SetPoint("LEFT", logoBox, "RIGHT", 10, 0)
    win.headerModuleTitle:SetWordWrap(false)
    win.headerModuleTitle:SetText("|cFFCBD5E1Dynamic|r|cFFFFFFFFSuite|r")

    local verBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
    verBtn:SetSize(64, 22)
    verBtn:SetPoint("LEFT", win.headerModuleTitle, "RIGHT", 10, 0)
    SetPixelBackdrop(verBtn, COLORS.BgElevated, COLORS.BorderStrong, 1)
    verBtn.txt = CreateText(verBtn, "OVERLAY", "GameFontHighlightSmall")
    verBtn.txt:SetPoint("CENTER")
    verBtn.txt:SetWordWrap(false)
    verBtn.txt:SetText("v" .. VERSION)
    verBtn:SetScript("OnClick", function()
        DynamicPrep:ToggleChangelogModal(win)
    end)
    win.headerVersionBtn = verBtn

    -- Zone 3 (Right): [All Characters v + X]
    local closeBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -12, 0)
    SetPixelBackdrop(closeBtn, COLORS.BgElevated, COLORS.BorderStrong, 1)
    closeBtn.txt = CreateText(closeBtn, "OVERLAY", "GameFontHighlight")
    closeBtn.txt:SetPoint("CENTER")
    closeBtn.txt:SetText("X")
    closeBtn:SetScript("OnClick", function()
        CloseActiveDropdown()
        DynamicPrep:HideBarPopovers()
        win:Hide()
    end)

    local scopeBadge = CreateFrame("Button", nil, header, "BackdropTemplate")
    scopeBadge:SetSize(128, 28)
    scopeBadge:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)
    SetPixelBackdrop(scopeBadge, COLORS.BgSurface, COLORS.BorderSubtle, 1)
    scopeBadge.txt = CreateText(scopeBadge, "OVERLAY", "GameFontHighlightSmall")
    scopeBadge.txt:SetPoint("CENTER")
    scopeBadge.txt:SetWordWrap(false)
    scopeBadge.txt:SetText("|cFFCBD5E1All Characters|r")

    -- Zone 2 (Center): Spacious 1-Line Status Capsule
    local statusCapsule = CreateFrame("Frame", nil, header, "BackdropTemplate")
    statusCapsule:SetHeight(28)
    statusCapsule:SetPoint("LEFT", verBtn, "RIGHT", 14, 0)
    statusCapsule:SetPoint("RIGHT", scopeBadge, "LEFT", -14, 0)
    SetPixelBackdrop(statusCapsule, COLORS.BgVoid, COLORS.BorderSubtle, 1)

    win.headerStatusText = CreateText(statusCapsule, "OVERLAY", "GameFontHighlightSmall")
    win.headerStatusText:SetPoint("LEFT", statusCapsule, "LEFT", 12, 0)
    win.headerStatusText:SetPoint("RIGHT", statusCapsule, "RIGHT", -12, 0)
    win.headerStatusText:SetJustifyH("CENTER")
    win.headerStatusText:SetWordWrap(false)

    -- Left Suite Rail (210px width): DYNAMIC MODULES + SUITE STUDIO & TOOLS + Reset Dock
    local rail = CreateFrame("Frame", nil, win, "BackdropTemplate")
    rail:SetWidth(210)
    rail:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    rail:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 1, 1)
    SetPixelBackdrop(rail, COLORS.BgCanvas, COLORS.BorderSubtle, 1)
    win.rail = rail

    local modHeader = CreateText(rail, "OVERLAY", "GameFontDisableSmall")
    modHeader:SetPoint("TOPLEFT", rail, "TOPLEFT", 14, -14)
    modHeader:SetText("DYNAMIC MODULES")

    local railModules = {
        { key = "load",   name = "DynamicLoad",   slash = "/dl" },
        { key = "marker", name = "DynamicMarker", slash = "/dm" },
        { key = "zoom",   name = "DynamicZoom",   slash = "/dz" },
        { key = "fps",    name = "DynamicFPS",    slash = "/dfps" },
        { key = "prep",   name = "DynamicPrep",   slash = "/dprep" },
        { key = "group",  name = "DynamicGroup",  slash = "/dgroup" },
        { key = "bags",   name = "DynamicBags",   slash = "/dbag" },
        { key = "chat",   name = "DynamicChat",   slash = "/dchat" },
    }
    win.railButtons = {}
    for idx, m in ipairs(railModules) do
        local rBtn = CreateFrame("Button", nil, rail, "BackdropTemplate")
        rBtn:SetHeight(35)
        rBtn:SetPoint("TOPLEFT", rail, "TOPLEFT", 10, -24 - (idx - 1) * 38)
        rBtn:SetPoint("TOPRIGHT", rail, "TOPRIGHT", -10, -24 - (idx - 1) * 38)
        rBtn.label = CreateText(rBtn, "OVERLAY", "GameFontHighlightSmall")
        rBtn.label:SetPoint("LEFT", rBtn, "LEFT", 12, 0)
        rBtn.label:SetWordWrap(false)
        rBtn.label:SetText(m.name)

        rBtn:SetScript("OnClick", function()
            CloseActiveDropdown()
            local regMod = Suite.modules and (Suite.modules[m.name] or Suite.modules[m.key])
            if m.key == "prep" or m.name == "DynamicPrep" then
                if Suite.SelectModule then
                    Suite:SelectModule("prep")
                else
                    DynamicPrep:RenderWorkspace(win.contentFrame)
                    win:Show()
                end
            elseif regMod then
                if type(regMod.Render) == "function" or type(regMod.BuildWorkspace) == "function" then
                    if Suite.SelectModule then
                        Suite:SelectModule(m.key)
                    else
                        for _, child in ipairs({ win.contentFrame:GetChildren() }) do
                            child:Hide()
                        end
                        if regMod.Render then
                            regMod.Render(win.contentFrame)
                        else
                            regMod.BuildWorkspace(win.contentFrame)
                        end
                        win:Show()
                    end
                elseif type(regMod.Open) == "function" then
                    win:Hide()
                    regMod.Open()
                elseif type(regMod.ToggleUI) == "function" then
                    win:Hide()
                    regMod.ToggleUI(true)
                end
            end
        end)
        win.railButtons[m.key] = rBtn
    end

    -- Bottom SUITE STUDIO & TOOLS section in Left Suite Rail
    local toolsHeader = CreateText(rail, "OVERLAY", "GameFontDisableSmall")
    toolsHeader:SetPoint("BOTTOMLEFT", rail, "BOTTOMLEFT", 14, 212)
    toolsHeader:SetText("SUITE STUDIO & TOOLS")

    local studioTools = {
        { label = "Theme & Font",      action = function() DynamicPrep:ApplyThemeToUI(); print(string.format("|cFF%sDynamicSuite:|r Applied active Suite Theme & Font Family.", GetAccentHex())) end },
        { label = "Guided Setup",      action = function() DynamicPrep:OpenWorkspace(2) end },
        { label = "Edit Mode (HUDs)",  action = function() DynamicPrep:SetEditMode(not DynamicPrep.inEditMode) end },
        { label = "Changelog",         action = function() DynamicPrep:ToggleChangelogModal(win) end },
        { label = "Support",           action = function() print(string.format("|cFF%sDynamicSuite:|r Thank you for supporting DynamicSuite on CurseForge!", GetAccentHex())) end },
    }
    for idx, t in ipairs(studioTools) do
        local sBtn = CreateFrame("Button", nil, rail, "BackdropTemplate")
        sBtn:SetHeight(26)
        sBtn:SetPoint("BOTTOMLEFT", rail, "BOTTOMLEFT", 10, 210 - idx * 30)
        sBtn:SetPoint("BOTTOMRIGHT", rail, "BOTTOMRIGHT", -10, 210 - idx * 30)
        SetPixelBackdrop(sBtn, COLORS.BgSurface, COLORS.BorderSubtle, 1)
        sBtn.txt = CreateText(sBtn, "OVERLAY", "GameFontHighlightSmall")
        sBtn.txt:SetPoint("LEFT", sBtn, "LEFT", 10, 0)
        sBtn.txt:SetWordWrap(false)
        sBtn.txt:SetText(t.label)
        sBtn:SetScript("OnClick", t.action)
    end

    -- Standardized Bottom-Left Reset Dock (BOTTOMLEFT, 16, 16) with 2-Tap Inline Confirmation
    local resetBtn = CreateFrame("Button", nil, rail, "BackdropTemplate")
    resetBtn:SetHeight(30)
    resetBtn:SetPoint("BOTTOMLEFT", rail, "BOTTOMLEFT", 10, 14)
    resetBtn:SetPoint("BOTTOMRIGHT", rail, "BOTTOMRIGHT", -10, 14)
    SetPixelBackdrop(resetBtn, COLORS.BgElevated, COLORS.BorderStrong, 1)
    resetBtn.txt = CreateText(resetBtn, "OVERLAY", "GameFontHighlightSmall")
    resetBtn.txt:SetPoint("CENTER")
    resetBtn.txt:SetWordWrap(false)
    resetBtn.txt:SetText("Reset DynamicPrep")
    resetBtn:SetScript("OnClick", function(selfBtn)
        if not selfBtn.confirmPending then
            selfBtn.confirmPending = true
            selfBtn.txt:SetText("|cFFFF4444Click again to confirm|r")
            C_Timer.After(3.0, function()
                if selfBtn.confirmPending then
                    selfBtn.confirmPending = false
                    selfBtn.txt:SetText("Reset DynamicPrep")
                end
            end)
        else
            selfBtn.confirmPending = false
            selfBtn.txt:SetText("Reset DynamicPrep")
            DynamicPrep:ResetModuleDefaults()
        end
    end)

    -- Main Workspace Content Area
    local content = CreateFrame("Frame", nil, win, "BackdropTemplate")
    content:SetPoint("TOPLEFT", rail, "TOPRIGHT", 0, 0)
    content:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -1, 1)
    SetPixelBackdrop(content, COLORS.BgVoid, COLORS.BorderSubtle, 1)
    win.contentFrame = content

    -- Unified Bottom-Right Corner Resize Grip (14x14, -4/4, Slate at rest -> #F97316 Blaze Orange hover)
    local resizeGrip = CreateFrame("Button", nil, win)
    resizeGrip:SetSize(14, 14)
    resizeGrip:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -4, 4)
    resizeGrip:SetFrameLevel(win:GetFrameLevel() + 8)
    resizeGrip:EnableMouse(true)

    local gripTex = resizeGrip:CreateTexture(nil, "OVERLAY", nil, 5)
    gripTex:SetAllPoints()
    gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    gripTex:SetDesaturated(true)
    gripTex:SetVertexColor(0.55, 0.58, 0.65, 0.75)

    resizeGrip:SetScript("OnEnter", function()
        local ar, ag, ab = GetActiveAccentRGB()
        gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        gripTex:SetDesaturated(false)
        gripTex:SetVertexColor(ar, ag, ab, 0.95)
    end)
    resizeGrip:SetScript("OnLeave", function()
        gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        gripTex:SetDesaturated(true)
        gripTex:SetVertexColor(0.55, 0.58, 0.65, 0.75)
    end)
    resizeGrip:SetScript("OnMouseDown", function(_, mBtn)
        if mBtn == "LeftButton" then
            win:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        win:StopMovingOrSizing()
        if _G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.window then
            _G.DynamicSuiteDB.global.window.width = math.floor(win:GetWidth() + 0.5)
            _G.DynamicSuiteDB.global.window.height = math.floor(win:GetHeight() + 0.5)
        end
        DynamicPrep:LayoutPillGrid()
    end)

    Suite.MainFrame = win
    Suite.mainFrame = win
    self.standaloneShell = win

    if not Suite.SelectModule then
        function Suite:SelectModule(modKey)
            local rawKey = modKey or "prep"
            local lowerKey = rawKey:lower()
            local capName = "Dynamic" .. lowerKey:sub(1, 1):upper() .. lowerKey:sub(2)
            local mod = self.modules[rawKey] or self.modules[lowerKey] or self.modules[capName] or self.modules["prep"]
            if not mod then return end

            if lowerKey ~= "prep" and rawKey ~= "DynamicPrep" and type(mod.Render) ~= "function" and type(mod.BuildWorkspace) ~= "function" then
                if type(mod.Open) == "function" then
                    win:Hide()
                    mod.Open()
                    return
                elseif type(mod.ToggleUI) == "function" then
                    win:Hide()
                    mod.ToggleUI(true)
                    return
                end
            end

            win.activeModuleKey = mod.key or lowerKey

            for k, btn in pairs(win.railButtons) do
                local isSel = (k == win.activeModuleKey)
                SetPixelBackdrop(btn, isSel and COLORS.BgElevated or COLORS.BgSurface, isSel and GetAccentColorTable(1.0) or COLORS.BorderSubtle, 1)
            end

            for _, child in ipairs({ win.contentFrame:GetChildren() }) do
                child:Hide()
            end

            if mod.Render then
                mod.Render(win.contentFrame)
            elseif mod.BuildWorkspace then
                mod.BuildWorkspace(win.contentFrame)
            end

            if mod.GetStatusText and win.headerStatusText then
                win.headerStatusText:SetText(mod.GetStatusText())
            end
            if win.headerModuleTitle then
                win.headerModuleTitle:SetText("|cFFCBD5E1Dynamic|r|cFFFFFFFFSuite|r")
            end
            win:Show()
        end
    end

    return win
end

function DynamicPrep:ToggleChangelogModal(parentWin)
    CloseAllDynamicPrepPopups()
    if not self.changelogModal then
        local modal = CreateFrame("Frame", "DynamicPrepChangelogModal", parentWin or UIParent, "BackdropTemplate")
        modal:SetSize(560, 380)
        modal:SetPoint("CENTER")
        modal:SetFrameStrata("DIALOG")
        SetPixelBackdrop(modal, COLORS.BgVoid, GetAccentColorTable(1.0), 1)
        SafeRegisterUISpecialFrame("DynamicPrepChangelogModal")
        modal:Hide()

        modal.title = CreateText(modal, "OVERLAY", "GameFontHighlightLarge")
        modal.title:SetPoint("TOPLEFT", modal, "TOPLEFT", 16, -14)

        local close = CreateFrame("Button", nil, modal, "BackdropTemplate")
        close:SetSize(24, 24)
        close:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -12, -12)
        SetPixelBackdrop(close, COLORS.BgElevated, COLORS.BorderStrong, 1)
        close.txt = CreateText(close, "OVERLAY", "GameFontHighlight")
        close.txt:SetPoint("CENTER")
        close.txt:SetText("X")
        close:SetScript("OnClick", function() modal:Hide() end)

        local clScroll = CreateFrame("ScrollFrame", nil, modal)
        clScroll:SetPoint("TOPLEFT", modal, "TOPLEFT", 16, -46)
        clScroll:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -22, 14)
        clScroll:SetClipsChildren(true)
        modal.scrollFrame = clScroll

        local clChild = CreateFrame("Frame", nil, clScroll)
        clChild:SetSize(514, 400)
        clScroll:SetScrollChild(clChild)
        StyleObsidianScrollBar(clScroll, nil)

        local y = 0
        for _, item in ipairs(self.CHANGELOG.entries) do
            local line = CreateText(clChild, "OVERLAY", "GameFontHighlightSmall")
            line:SetPoint("TOPLEFT", clChild, "TOPLEFT", 0, y)
            line:SetPoint("RIGHT", clChild, "RIGHT", -8, 0)
            line:SetJustifyH("LEFT")
            line:SetWordWrap(true)
            line:SetText("|cFF34D399[" .. item.type .. "]|r |cFFCBD5E1" .. item.text .. "|r")
            local h = math.max(36, (line.GetStringHeight and line:GetStringHeight() or 36) + 12)
            y = y - h
        end
        clChild:SetHeight(math.max(320, math.abs(y) + 10))
        modal:HookScript("OnShow", function()
            if clScroll.UpdateScrollThumb then
                C_Timer.After(0, function() clScroll:UpdateScrollThumb() end)
            end
        end)

        self.changelogModal = modal
    end

    local m = self.changelogModal
    SetPixelBackdrop(m, COLORS.BgVoid, GetAccentColorTable(1.0), 1)
    if m.title then
        m.title:SetText(string.format("|cFF%sDynamicPrep v%s Changelog|r", GetAccentHex(), VERSION))
    end
    m:SetShown(not m:IsShown())
    if m:IsShown() and m.scrollFrame and m.scrollFrame.UpdateScrollThumb then
        m.scrollFrame:UpdateScrollThumb()
    end
end

local function RenderPrepEmbedded(arg1, arg2)
    local parent = (arg1 == DynamicPrep) and arg2 or arg1
    return DynamicPrep:RenderWorkspace(parent)
end

local function OpenPrepWorkspace(arg1, arg2)
    local subTab = (arg1 == DynamicPrep) and arg2 or arg1
    DynamicPrep:InitDB()
    ApplyPrepThemeToUI()
    if type(subTab) == "number" then
        DynamicPrep.db.activeSubTab = subTab
    end

    if type(Suite.OpenModule) == "function" then
        Suite:OpenModule("prep")
        DynamicPrep:RefreshWorkspaceView()
        return
    elseif type(Suite.OpenSuiteWindow) == "function" then
        Suite:OpenSuiteWindow("prep")
        DynamicPrep:RefreshWorkspaceView()
        return
    end

    local win = DynamicPrep:EnsureSuiteWindowShell()
    if Suite.SelectModule then
        Suite:SelectModule("prep")
    else
        DynamicPrep:RenderWorkspace(win.contentFrame)
        win:Show()
    end
    DynamicPrep:UpdateSuiteHeaderStatus()
end

local function TogglePrepMainWindow(arg1, arg2)
    local forceShow
    if arg1 == DynamicPrep then
        forceShow = arg2
    else
        forceShow = arg1
    end
    local win = DynamicPrep.standaloneShell or Suite.MainFrame or Suite.mainFrame
    if forceShow == false then
        if win and win:IsShown() then
            win:Hide()
        end
        return
    elseif forceShow == nil and win and win:IsShown() and (win.activeModuleKey == "prep" or win.activeModuleKey == "DynamicPrep") then
        win:Hide()
        return
    end
    OpenPrepWorkspace()
end

DynamicPrep.OpenWorkspace = OpenPrepWorkspace
DynamicPrep.ToggleMainWindow = TogglePrepMainWindow
DynamicPrep.ToggleUI = TogglePrepMainWindow

-- ============================================================================
-- Register DynamicPrep into _G.DynamicSuite.modules["prep"]
-- ============================================================================
function DynamicPrep:OnDisableInSuite()
    if self.SyncErrorFilterState then
        self:SyncErrorFilterState(true)
    end
end

function DynamicPrep:OnEnableInSuite()
    if self.SyncErrorFilterState then
        self:SyncErrorFilterState(false)
    end
end

function DynamicPrep:RegisterWithSuite()
    RegisterDynamicPrepPopupClosers()
    local moduleEntry = {
        id = "prep",
        key = "prep",
        name = "DynamicPrep",
        title = "DynamicPrep",
        addonName = "DynamicPrep",
        version = VERSION,
        slash = "/dprep",
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_prep.tga",
        fallbackIcon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_white.tga",
        subtitle = "Stats, Buffs & QoL",
        desc = "Live stat and readiness top bar, clickable raid buffs and consumables, Omni Folio tracking, quest/cutscene skipping, and survival macros.",
        isInstalled = true,
        isLoaded = true,
        ref = DynamicPrep,
        GetStatus = function() return DynamicPrep:GetHeaderStatusText() end,
        GetStatusText = function() return DynamicPrep:GetHeaderStatusText() end,
        Render = RenderPrepEmbedded,
        RenderEmbedded = RenderPrepEmbedded,
        Build = RenderPrepEmbedded,
        BuildView = RenderPrepEmbedded,
        BuildWorkspace = RenderPrepEmbedded,
        Show = RenderPrepEmbedded,
        Hide = function()
            CloseAllDynamicPrepPopups()
            if DynamicPrep.workspaceFrame then DynamicPrep.workspaceFrame:Hide() end
        end,
        CloseActiveDropdown = CloseAllDynamicPrepPopups,
        ClosePopups = CloseAllDynamicPrepPopups,
        Reset = ResetPrepModuleDefaults,
        OnReset = ResetPrepModuleDefaults,
        ResetModuleDefaults = ResetPrepModuleDefaults, ResetDefaults = ResetPrepModuleDefaults, ResetModule = ResetPrepModuleDefaults,
        SetEditMode = DynamicPrep.SetEditMode,
        NudgeHUD = NudgePrepHUD,
        ResetHUDPosition = ResetPrepHUDPosition,
        ApplyTheme = ApplyPrepThemeToUI,
        ApplyThemeToUI = ApplyPrepThemeToUI,
        RefreshTheme = ApplyPrepThemeToUI,
        ToggleUI = TogglePrepMainWindow,
        ToggleMainWindow = TogglePrepMainWindow,
        Open = function() OpenPrepWorkspace() end,
        OpenOptions = function() OpenPrepWorkspace() end,
        OnDisableInSuite = function()
            CloseAllDynamicPrepPopups()
            if DynamicPrep.SyncErrorFilterState then DynamicPrep:SyncErrorFilterState(true) end
            if DynamicPrep.HideMageFoodToast then DynamicPrep:HideMageFoodToast() end
            if DynamicPrep.HideDurabilityToast then DynamicPrep:HideDurabilityToast() end
            if DynamicPrep.barFrame then DynamicPrep.barFrame:Hide() end
            if DynamicPrep.crbBar and not (InCombatLockdown and InCombatLockdown()) then DynamicPrep.crbBar:Hide() end
        end,
        OnEnableInSuite = function()
            if DynamicPrep.SyncErrorFilterState then DynamicPrep:SyncErrorFilterState(false) end
        end,
        GetChangelog = function() return DynamicPrep.CHANGELOG end,
        SelectSubTab = function(a1, a2, a3)
            CloseAllDynamicPrepPopups()
            local idx = (type(a1) == "number") and a1 or a2 or 1
            local expandDrawers = (type(a1) == "number") and a2 or a3
            if DynamicPrep.db then
                DynamicPrep.db.activeSubTab = idx
            end
            local ws = DynamicPrep.workspaceFrame
            if ws and expandDrawers then
                ws.statSortDrawerOpen = true
                ws.pingDrawerOpen = true
                ws.healDrawerOpen = true
                ws.drinkDrawerOpen = true
                ws.mageFoodDrawerOpen = true
                ws.durabilityDrawerOpen = true
                ws.errorFilterDrawerOpen = true
            end
            if DynamicPrep.SyncErrorFilterState then
                DynamicPrep:SyncErrorFilterState(false)
            end
            if DynamicPrep.RefreshWorkspaceView then
                DynamicPrep:RefreshWorkspaceView()
            end
            if ws and ws.scrollFrame then
                ws.scrollFrame:SetVerticalScroll(0)
            end
        end,
    }
    moduleEntry.SelectTab = moduleEntry.SelectSubTab
    DynamicPrep.SelectSubTab = moduleEntry.SelectSubTab
    DynamicPrep.SelectTab = moduleEntry.SelectSubTab

    if type(Suite.RegisterModule) == "function" then
        pcall(Suite.RegisterModule, Suite, "prep", DynamicPrep, "/dprep", moduleEntry.desc)
    end
    Suite.modules["prep"] = Suite.modules["prep"] or {}
    for k, v in pairs(moduleEntry) do
        Suite.modules["prep"][k] = v
    end
    Suite.modules["DynamicPrep"] = Suite.modules["prep"]
end

DynamicPrep:RegisterWithSuite()

-- ============================================================================
-- Slash Commands (/dprep, /dp, and fallback /ds)
-- ============================================================================
SLASH_DYNAMICPREP1 = "/dprep"
SLASH_DYNAMICPREP2 = "/dp"
SlashCmdList["DYNAMICPREP"] = function(msg)
    local cmd = (msg or ""):lower():match("^(%S*)") or ""
    if cmd == "edit" then
        DynamicPrep:SetEditMode(not DynamicPrep.inEditMode)
    elseif cmd == "reset" then
        DynamicPrep:ResetModuleDefaults()
    elseif cmd == "testaudit" then
        DynamicPrep:TogglePaperdollAuditPreview()
    elseif cmd == "drink" then
        DynamicPrep:OpenWorkspace(3)
        DynamicPrep:SelectSubTab(3, true)
        local scan = DynamicPrep:ScanRecoveryConsumables()
        local _, badge = DynamicPrep:GetDrinkMacroActionBarStatus()
        print(string.format("|cFF%sDynamicPrep:|r [DynamicDrink] %s | Buns: %d, Mana Drink: %d, Plain Food: %d, Buff Food: %d.",
            GetAccentHex(), badge, scan.mageFoodCount or 0, scan.manaDrinkCount or 0, scan.vendorFoodCount or 0, scan.buffFoodCount or 0))
    elseif cmd == "qol" or cmd == "3" then
        DynamicPrep:OpenWorkspace(3)
    elseif cmd == "buffs" or cmd == "2" then
        DynamicPrep:OpenWorkspace(2)
    else
        DynamicPrep:OpenWorkspace(1)
    end
end

if not SlashCmdList["DYNAMICSUITE"] then
    SLASH_DYNAMICSUITE1 = "/ds"
    SLASH_DYNAMICSUITE2 = "/dynamicsuite"
    SlashCmdList["DYNAMICSUITE"] = function(msg)
        local cmd = (msg or ""):lower():match("^(%S*)") or ""
        if cmd ~= "" and Suite.SelectModule then
            DynamicPrep:EnsureSuiteWindowShell()
            Suite:SelectModule(cmd)
        else
            DynamicPrep:OpenWorkspace()
        end
    end
end
end)() end

-- ============================================================================
-- Native Event Dispatcher (Zero OnUpdate & Decoupled from Blizzard Edit Mode)
-- ============================================================================
local function SafeRegisterEvent(frame, eventName)
    if not frame or not eventName then return end
    if _G.C_EventUtils and type(_G.C_EventUtils.IsEventValid) == "function" then
        if not _G.C_EventUtils.IsEventValid(eventName) then
            return
        end
    end
    frame:RegisterEvent(eventName)
end

local eventFrame = CreateFrame("Frame")
SafeRegisterEvent(eventFrame, "ADDON_LOADED")
SafeRegisterEvent(eventFrame, "PLAYER_LOGIN")
SafeRegisterEvent(eventFrame, "PLAYER_ENTERING_WORLD")
SafeRegisterEvent(eventFrame, "ZONE_CHANGED_NEW_AREA")
SafeRegisterEvent(eventFrame, "PLAYER_REGEN_DISABLED")
SafeRegisterEvent(eventFrame, "PLAYER_REGEN_ENABLED")
if eventFrame.RegisterUnitEvent then
    eventFrame:RegisterUnitEvent("UNIT_STATS", "player")
    eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
else
    SafeRegisterEvent(eventFrame, "UNIT_STATS")
    SafeRegisterEvent(eventFrame, "UNIT_AURA")
end
SafeRegisterEvent(eventFrame, "COMBAT_RATING_UPDATE")
SafeRegisterEvent(eventFrame, "MASTERY_UPDATE")
SafeRegisterEvent(eventFrame, "PLAYER_SPECIALIZATION_CHANGED")
SafeRegisterEvent(eventFrame, "PLAYER_LOOT_SPEC_UPDATED")
SafeRegisterEvent(eventFrame, "UPDATE_INVENTORY_DURABILITY")
SafeRegisterEvent(eventFrame, "PLAYER_EQUIPMENT_CHANGED")
SafeRegisterEvent(eventFrame, "SOCKET_INFO_UPDATE")
SafeRegisterEvent(eventFrame, "BAG_UPDATE_DELAYED")
SafeRegisterEvent(eventFrame, "CHALLENGE_MODE_MAPS_UPDATE")
SafeRegisterEvent(eventFrame, "GROUP_ROSTER_UPDATE")
SafeRegisterEvent(eventFrame, "PARTY_LEADER_CHANGED")
SafeRegisterEvent(eventFrame, "GOSSIP_SHOW")
SafeRegisterEvent(eventFrame, "GOSSIP_CONFIRM")
SafeRegisterEvent(eventFrame, "GOSSIP_CLOSED")
SafeRegisterEvent(eventFrame, "PLAYER_CHOICE_UPDATE")
SafeRegisterEvent(eventFrame, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
SafeRegisterEvent(eventFrame, "BANKFRAME_OPENED")
SafeRegisterEvent(eventFrame, "QUEST_GREETING")
SafeRegisterEvent(eventFrame, "QUEST_DETAIL")
SafeRegisterEvent(eventFrame, "QUEST_ACCEPT_CONFIRM")
SafeRegisterEvent(eventFrame, "QUEST_AUTOCOMPLETE")
SafeRegisterEvent(eventFrame, "QUEST_PROGRESS")
SafeRegisterEvent(eventFrame, "QUEST_COMPLETE")
SafeRegisterEvent(eventFrame, "ITEM_TEXT_READY")
SafeRegisterEvent(eventFrame, "CINEMATIC_START")
SafeRegisterEvent(eventFrame, "PLAY_MOVIE")
SafeRegisterEvent(eventFrame, "TALKINGHEAD_REQUESTED")
SafeRegisterEvent(eventFrame, "ENCOUNTER_START")
SafeRegisterEvent(eventFrame, "RESURRECT_REQUEST")
SafeRegisterEvent(eventFrame, "CONFIRM_SUMMON")
SafeRegisterEvent(eventFrame, "PLAYER_DEAD")
SafeRegisterEvent(eventFrame, "PLAYER_ALIVE")
SafeRegisterEvent(eventFrame, "PLAYER_UNGHOST")
SafeRegisterEvent(eventFrame, "MODIFIER_STATE_CHANGED")
SafeRegisterEvent(eventFrame, "ENCOUNTER_END")
SafeRegisterEvent(eventFrame, "ACTIONBAR_SLOT_CHANGED")
SafeRegisterEvent(eventFrame, "UPDATE_MACROS")
SafeRegisterEvent(eventFrame, "SPELL_UPDATE_COOLDOWN")
SafeRegisterEvent(eventFrame, "BAG_UPDATE_COOLDOWN")
SafeRegisterEvent(eventFrame, "LFG_UPDATE")
SafeRegisterEvent(eventFrame, "PLAYER_LEVEL_UP")
SafeRegisterEvent(eventFrame, "READY_CHECK")

-- ============================================================================
-- TALENT LOADOUT FORWARDING STUBS (Extracted to DynamicTalent) & AUTO-ACCEPT SUMMON
-- ============================================================================
function DynamicPrep:OpenTalentManagerModal(initialTab, targetEntry)
    if _G.DynamicTalent and type(_G.DynamicTalent.OpenTalentManagerModal) == "function" then
        return _G.DynamicTalent:OpenTalentManagerModal(initialTab, targetEntry)
    end
end

function DynamicPrep:RefreshTalentDock()
    if _G.DynamicTalent and type(_G.DynamicTalent.RefreshTalentDock) == "function" then
        return _G.DynamicTalent:RefreshTalentDock()
    end
end

function DynamicPrep:CheckZoneTalentLoadout(...)
    if _G.DynamicTalent and type(_G.DynamicTalent.CheckZoneTalentLoadout) == "function" then
        return _G.DynamicTalent:CheckZoneTalentLoadout(...)
    end
end

function DynamicPrep:GetActiveTalentMismatch()
    if _G.DynamicTalent and type(_G.DynamicTalent.GetActiveTalentMismatch) == "function" then
        return _G.DynamicTalent:GetActiveTalentMismatch()
    end
    return nil
end

function DynamicPrep:ApplyTalentReminderToastVisuals()
    if _G.DynamicTalent and type(_G.DynamicTalent.ApplyTalentReminderToastVisuals) == "function" then
        return _G.DynamicTalent:ApplyTalentReminderToastVisuals()
    end
end

function DynamicPrep:HandleConfirmSummon()
    if not self.db or self.db.autoAcceptSummon ~= true or IsModuleDisabledInSuite("DynamicPrep") then return end
    if (InCombatLockdown and InCombatLockdown()) or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then return end
    if IsShiftKeyDown and IsShiftKeyDown() then return end
    if not (C_SummonInfo and C_SummonInfo.ConfirmSummon) then return end
    local summoner = (C_SummonInfo.GetSummonConfirmSummoner and C_SummonInfo.GetSummonConfirmSummoner()) or "Someone"
    local area = (C_SummonInfo.GetSummonConfirmAreaName and C_SummonInfo.GetSummonConfirmAreaName()) or "destination"
    if _IsSecret(summoner) then summoner = "Party Member" end
    if _IsSecret(area) then area = "destination" end
    print(string.format("|cFFCBD5E1Dynamic|r|cFF38BDF8Prep|r: Auto-accepting summon from |cFFFFFFFF%s|r to |cFF38BDF8%s|r in 1.5s (hold Shift to cancel).", tostring(summoner), tostring(area)))
    if C_Timer and C_Timer.After then
        C_Timer.After(1.5, function()
            if not DynamicPrep.db or DynamicPrep.db.autoAcceptSummon ~= true then return end
            if (InCombatLockdown and InCombatLockdown()) or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then return end
            if IsShiftKeyDown and IsShiftKeyDown() then return end
            local left = (C_SummonInfo.GetSummonConfirmTimeLeft and C_SummonInfo.GetSummonConfirmTimeLeft()) or 0
            if left > 0 then
                pcall(C_SummonInfo.ConfirmSummon)
                if _G.StaticPopup_Hide then pcall(_G.StaticPopup_Hide, "CONFIRM_SUMMON") end
            end
        end)
    end
end

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4, arg5)
    if event == "ADDON_LOADED" then
        if (arg1 == ADDON_FOLDER or arg1 == "DynamicPrep") and not isInitialized then
            isInitialized = true
            DynamicPrep:InitDB()
            DynamicPrep:RegisterWithSuite()
            if IsModuleDisabledInSuite("DynamicPrep") then
                if Suite.modules["prep"] then Suite.modules["prep"]._disabledAtStartup = true end
                if Suite.modules["DynamicPrep"] then Suite.modules["DynamicPrep"]._disabledAtStartup = true end
                eventFrame:UnregisterAllEvents()
                return
            end
            DynamicPrep:SetupDeleteConfirmationHook()
            DynamicPrep:EnsureCatalystHooks()
            if _G.EventUtil and type(_G.EventUtil.ContinueOnAddOnLoaded) == "function" then
                _G.EventUtil.ContinueOnAddOnLoaded("Blizzard_ItemInteractionUI", function()
                    if not IsModuleDisabledInSuite("DynamicPrep") then
                        DynamicPrep:EnsureCatalystHooks()
                    end
                end)
            end
            DynamicPrep:EnsureDeathPopupHooks()
            DynamicPrep:InitBlizzardWindowQoL()
            DynamicPrep:CreatePrepBar()
        elseif arg1 == "Blizzard_TalkingHeadUI" then
            if not IsModuleDisabledInSuite("DynamicPrep") then
                DynamicPrep:UpdateTalkingHeadSuppression()
        DynamicPrep:SyncErrorFilterState(false)
            end
        elseif arg1 == "Blizzard_ItemInteractionUI" then
            if not IsModuleDisabledInSuite("DynamicPrep") then
                DynamicPrep:EnsureCatalystHooks()
                DynamicPrep:InitBlizzardWindowQoL(arg1)
            end
        elseif arg1 == "Blizzard_InspectUI"
            or arg1 == "Blizzard_PlayerSpells"
            or arg1 == "Blizzard_GroupFinder"
            or arg1 == "Blizzard_WeeklyRewards"
            or arg1 == "Blizzard_Communities"
            or arg1 == "Blizzard_Collections"
            or arg1 == "Blizzard_EncounterJournal"
            or arg1 == "Blizzard_Professions"
            or arg1 == "Blizzard_ProfessionsBook"
            or arg1 == "Blizzard_AchievementUI"
            or arg1 == "Blizzard_ItemUpgradeUI"
            or arg1 == "Blizzard_ItemSocketingUI"
            or arg1 == "Blizzard_ProfessionsCustomerOrders"
            or arg1 == "Blizzard_MajorFactions"
            or arg1 == "Blizzard_TrainerUI"
            or arg1 == "Blizzard_Calendar"
            or arg1 == "Blizzard_MacroUI"
            or arg1 == "Blizzard_AuctionHouseUI"
            or arg1 == "NoAutoClose"
            or arg1 == "BlizzMove"
            or arg1 == "DeModal"
            or arg1 == "MoveAny"
            or arg1 == "EllesmereUI"
            or arg1 == "EllesmereUIQoL"
            or arg1 == "EllesmereUI_QoL"
            or arg1 == "Leatrix_Plus"
            or arg1 == "ElvUI" then
            if isInitialized and not IsModuleDisabledInSuite("DynamicPrep") then
                DynamicPrep:InitBlizzardWindowQoL(arg1)
                if DynamicPrep.workspaceFrame and DynamicPrep.workspaceFrame.IsShown and DynamicPrep.workspaceFrame:IsShown() then
                    DynamicPrep:RefreshWorkspaceView()
                end
            end
        end
    elseif event == "PLAYER_LOGIN" then
        DynamicPrep:InitDB()
        DynamicPrep:RegisterWithSuite()
        if IsModuleDisabledInSuite("DynamicPrep") then
            if Suite.modules["prep"] then Suite.modules["prep"]._disabledAtStartup = true end
            if Suite.modules["DynamicPrep"] then Suite.modules["DynamicPrep"]._disabledAtStartup = true end
            eventFrame:UnregisterAllEvents()
            if DynamicPrep.barFrame then DynamicPrep.barFrame:Hide() end
            return
        end
        DynamicPrep:EnsureCatalystHooks()
        DynamicPrep:EnsureDeathPopupHooks()
        DynamicPrep:EnsurePaperdollHighlightHooks()
        DynamicPrep:InitBlizzardWindowQoL()
        DynamicPrep:UpdateTalkingHeadSuppression()
        DynamicPrep:SyncErrorFilterState(false)
        DynamicPrep:UpdateDrinkMacro(false)
        DynamicPrep:RequestMageFoodCheck("PLAYER_LOGIN", 0.5)
        DynamicPrep:RefreshBar()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        DynamicPrep:ResetStableCapsuleWidths()
        DynamicPrep:UpdateTalkingHeadSuppression()
        DynamicPrep:SyncErrorFilterState(false)
        if event == "PLAYER_ENTERING_WORLD" then
            DynamicPrep:UpdateHealMacro(false, true)
            DynamicPrep:UpdateDrinkMacro(false)
            DynamicPrep:ScanEquippedGearEnchantsAndGems()
            DynamicPrep:RequestDurabilityCheck("PLAYER_ENTERING_WORLD", 1.0)
        else
            DynamicPrep:UpdateDrinkMacro(false)
        end
        DynamicPrep:RequestMageFoodCheck(event, 0.8)
        DynamicPrep:RefreshBar()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "SOCKET_INFO_UPDATE" then
        DynamicPrep:ScanEquippedGearEnchantsAndGems()
        if not (InCombatLockdown and InCombatLockdown()) then
            DynamicPrep:RefreshBar()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if DynamicPrep.HideMageFoodToast then
            DynamicPrep:HideMageFoodToast()
        end
        if DynamicPrep.HideDurabilityToast then
            DynamicPrep:HideDurabilityToast()
        end
        if DynamicPrep.inEditMode then
            DynamicPrep:SetEditMode(false)
        end
        DynamicPrep:HandleBlizzardWindowCombatChange(true)
        DynamicPrep.pendingBarRefreshAfterCombat = true
        DynamicPrep:RefreshStatsCapsulesFast()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if DynamicPrep._pendingFolioSecureUpdate then
            DynamicPrep:UpdateFolioSecureButton()
        end
        if DynamicPrep.pendingBarRefreshAfterCombat then
            DynamicPrep.pendingBarRefreshAfterCombat = nil
            DynamicPrep:ApplyBarGeometry()
        end
        DynamicPrep:HandleBlizzardWindowCombatChange(false)
        -- Re-evaluate any single-option PlayerChoice / Gossip window that opened during combat
        local pcfOpen = _G.PlayerChoiceFrame and _G.PlayerChoiceFrame.IsShown and _G.PlayerChoiceFrame:IsShown()
        if DynamicPrep._pendingPlayerChoiceAfterCombat or pcfOpen then
            DynamicPrep._pendingPlayerChoiceAfterCombat = nil
            DynamicPrep._lastPlayerChoiceKey = nil
            DynamicPrep:HandlePlayerChoiceUpdate()
            if _G.PlayerChoiceFrame and _G.PlayerChoiceFrame.IsShown and _G.PlayerChoiceFrame:IsShown() then
                if HideUIPanel then
                    pcall(HideUIPanel, _G.PlayerChoiceFrame)
                elseif _G.PlayerChoiceFrame.Hide then
                    pcall(_G.PlayerChoiceFrame.Hide, _G.PlayerChoiceFrame)
                end
            end
        end
        if _G.GossipFrame and _G.GossipFrame.IsShown and _G.GossipFrame:IsShown() then
            DynamicPrep:HandleQuestAndGossip("GOSSIP_SHOW", true)
        end
        DynamicPrep:ScanEquippedGearEnchantsAndGems()
        DynamicPrep:RefreshBar()
        DynamicPrep.pendingHealMacroUpdate = nil
        DynamicPrep:UpdateHealMacro(false, true)
        DynamicPrep.pendingDrinkMacroUpdate = nil
        DynamicPrep:UpdateDrinkMacro(false)
        DynamicPrep:RequestMageFoodCheck("PLAYER_REGEN_ENABLED", 0.3)
        DynamicPrep:RequestDurabilityCheck("PLAYER_REGEN_ENABLED", 0.4)
        if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") and not (UnitIsGhost and UnitIsGhost("player")) then
            local inInst, instType = IsInInstance()
            if inInst and (instType == "raid" or instType == "party") then
                local mode = (DynamicPrep.db and DynamicPrep.db.autoReleaseMode) or "WIPE_AND_CTRL"
                if mode == "WIPE_AND_CTRL" or mode == "PVP_AUTO_WIPE_PVE" then
                    C_Timer.After(0.5, function()
                        if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") and not (UnitIsGhost and UnitIsGhost("player")) then
                            DynamicPrep:ExecuteReleaseSpirit()
                        end
                    end)
                end
            end
        end
    elseif event == "ENCOUNTER_START" then
        if arg1 and not _IsSecret(arg1) then
            DynamicPrep._lastCutsceneContext = "E" .. tostring(arg1)
        end
    elseif event == "ENCOUNTER_END" then
        local success = arg5
        if success == 0 and UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") and not (UnitIsGhost and UnitIsGhost("player")) then
            local mode = (DynamicPrep.db and DynamicPrep.db.autoReleaseMode) or "WIPE_AND_CTRL"
            if mode == "WIPE_AND_CTRL" or mode == "PVP_AUTO_WIPE_PVE" then
                C_Timer.After(0.5, function()
                    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") and not (UnitIsGhost and UnitIsGhost("player")) then
                        DynamicPrep:ExecuteReleaseSpirit()
                    end
                end)
            end
        end
    elseif event == "UNIT_STATS" or event == "UNIT_AURA" then
        if not _IsSecret(arg1) and arg1 == "player" then
            if event == "UNIT_AURA" then
                if InCombatLockdown and InCombatLockdown() then
                    return
                end
                if DynamicPrep._awaitingPostCastFolioScan then
                    DynamicPrep._awaitingPostCastFolioScan = nil
                    DynamicPrep._lastFolioScanTime = nil
                    local postStat = DynamicPrep:DetectActiveFolioBuffStat(true)
                    if postStat and DynamicPrep.db then
                        DynamicPrep.db.activeFolioStat = postStat
                        DynamicPrep.previewFolioMismatch = false
                    end
                end
            end
            DynamicPrep:RequestStatRefresh()
        end
    elseif event == "COMBAT_RATING_UPDATE" or event == "MASTERY_UPDATE" then
        DynamicPrep:RequestStatRefresh()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if not arg1 or arg1 == "player" then
            DynamicPrep:ResetStableCapsuleWidths()
            if DynamicPrep.db and DynamicPrep.db.omniFolio and DynamicPrep.db.omniFolio.presetMode == "WOWHEAD" then
                DynamicPrep:ApplyWowheadPresetForCurrentSpec(true)
            end
            DynamicPrep:UpdateHealMacro(false)
            DynamicPrep:UpdateDrinkMacro(false)
            DynamicPrep:RequestMageFoodCheck("PLAYER_SPECIALIZATION_CHANGED", 0.3)
            DynamicPrep:RefreshBar()
            DynamicPrep:RefreshWorkspaceView()
        end
    elseif event == "PLAYER_LEVEL_UP" then
        DynamicPrep:UpdateDrinkMacro(false)
        DynamicPrep:RequestMageFoodCheck("PLAYER_LEVEL_UP", 0.3)
    elseif event == "LFG_UPDATE" then
        DynamicPrep:RequestMageFoodCheck("LFG_UPDATE", 0.3)
    elseif event == "READY_CHECK" then
        DynamicPrep:CheckDurabilityAlert("READY_CHECK")
    elseif event == "PLAYER_LOOT_SPEC_UPDATED" or event == "UPDATE_INVENTORY_DURABILITY" or event == "BAG_UPDATE_DELAYED" or event == "CHALLENGE_MODE_MAPS_UPDATE" or event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" then
        if event == "PLAYER_LOOT_SPEC_UPDATED" then
            DynamicPrep:ResetStableCapsuleWidths()
        elseif event == "BAG_UPDATE_DELAYED" then
            DynamicPrep:UpdateHealMacro(false)
            DynamicPrep:UpdateDrinkMacro(false)
            DynamicPrep:RequestMageFoodCheck("BAG_UPDATE_DELAYED", 0.35)
            if DynamicPrep.workspaceFrame and DynamicPrep.workspaceFrame:IsShown() then
                DynamicPrep:RefreshWorkspaceView()
            end
        elseif event == "GROUP_ROSTER_UPDATE" then
            DynamicPrep:RequestMageFoodCheck("GROUP_ROSTER_UPDATE", 0.4)
        elseif event == "UPDATE_INVENTORY_DURABILITY" then
            DynamicPrep:RequestDurabilityCheck("UPDATE_INVENTORY_DURABILITY", 0.4)
        end
        if not InCombatLockdown() or event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" then
            DynamicPrep:RefreshBar()
        end
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" then
        if not (InCombatLockdown and InCombatLockdown()) then
            local now = (GetTime and GetTime()) or 0
            if not DynamicPrep._lastHealCdCheck or (now - DynamicPrep._lastHealCdCheck) >= 0.40 then
                DynamicPrep._lastHealCdCheck = now
                DynamicPrep:UpdateHealMacro(false)
            elseif not DynamicPrep._healCdCheckPending then
                DynamicPrep._healCdCheckPending = true
                C_Timer.After(0.40, function()
                    DynamicPrep._healCdCheckPending = nil
                    DynamicPrep._lastHealCdCheck = (GetTime and GetTime()) or 0
                    if not (InCombatLockdown and InCombatLockdown()) then
                        DynamicPrep:UpdateHealMacro(false)
                    end
                end)
            end
        end
    elseif event == "GOSSIP_SHOW" or event == "QUEST_GREETING" or event == "QUEST_DETAIL" or event == "QUEST_ACCEPT_CONFIRM" or event == "QUEST_AUTOCOMPLETE" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" or event == "ITEM_TEXT_READY" then
        DynamicPrep:HandleQuestAndGossip(event, arg1)
    elseif event == "GOSSIP_CONFIRM" then
        DynamicPrep:HandleGossipConfirm(arg1, arg2, arg3)
    elseif event == "PLAYER_CHOICE_UPDATE" then
        DynamicPrep:HandlePlayerChoiceUpdate()
    elseif event == "GOSSIP_CLOSED" or event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event == "BANKFRAME_OPENED" then
        local keepHidden = (event == "BANKFRAME_OPENED")
        if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            if Enum and Enum.PlayerInteractionType then
                local PIT = Enum.PlayerInteractionType
                if arg1 == PIT.Banker or arg1 == PIT.AccountBanker or arg1 == PIT.GuildBanker then
                    keepHidden = true
                end
            end
            DynamicPrep:EnsureCatalystHooks()
        end
        if event == "GOSSIP_CLOSED" then
            DynamicPrep._gossipChainCount = 0
        end
        DynamicPrep:RestoreDialogueUIAfterGossipSkip(keepHidden)
    elseif event == "CINEMATIC_START" or event == "PLAY_MOVIE" then
        DynamicPrep:HandleCinematicOrMovie(event, arg1)
    elseif event == "TALKINGHEAD_REQUESTED" then
        DynamicPrep:UpdateTalkingHeadSuppression()
        DynamicPrep:SyncErrorFilterState(false)
    elseif event == "RESURRECT_REQUEST" then
        DynamicPrep:HandleResurrectRequest(arg1)
    elseif event == "CONFIRM_SUMMON" then
        DynamicPrep:HandleConfirmSummon()
    elseif event == "PLAYER_DEAD" then
        DynamicPrep:HandlePlayerDead()
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        DynamicPrep:UpdateDeathDialogButtonState(true)
    elseif event == "MODIFIER_STATE_CHANGED" then
        DynamicPrep:HandleModifierStateChanged(arg1, arg2)
    elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_MACROS" then
        if DynamicPrep.workspaceFrame and DynamicPrep.workspaceFrame:IsShown() then
            DynamicPrep:RefreshWorkspaceView()
        end
    end
end)



-- ============================================================================
-- NATIVE CLICKABLE RAID BUFFS & CONSUMABLES ENGINE (TAB 2)
-- Zero-lag, pre-allocated SecureActionButtonTemplate HUD with C++ combat hide
-- ============================================================================
do (function()

-- Priority Consumable ItemIDs (Midnight & The War Within R3 -> R2 -> R1)
local CONSUMABLE_FLASKS = {
    241288, -- Midnight Flask (Rank 2 Gold)
    241289, -- Midnight Flask (Rank 1 Silver)
    212283, 212282, 212281, -- Flask of Alchemical Chaos R3/R2/R1
    212274, 212273, 212272, -- Flask of Tempered Swiftness (Haste) R3/R2/R1
    212277, 212276, 212275, -- Flask of Tempered Mastery R3/R2/R1
    212271, 212270, 212269, -- Flask of Tempered Aggression (Crit) R3/R2/R1
    212280, 212279, 212278, -- Flask of Tempered Versatility R3/R2/R1
    212301, 212300, 212299, -- Vicious Flasks
    191341, 191339, 191350, 191359, -- Dragonflight / Phials fallback
}

local CONSUMABLE_WEAPON_OILS = {
    224107, 224106, 224105, -- Algari Mana Oil R3/R2/R1
    224113, 224112, 224111, -- Oil of Deep Toxins R3/R2/R1
    224110, 224109, 224108, -- Oil of Beleaguered Grace R3/R2/R1
    222504, 222503, 222502, -- Ironclaw Whetstone R3/R2/R1
    222510, 222509, 222508, -- Ironclaw Weightstone R3/R2/R1
}

local CONSUMABLE_RUNES = {
    259085, -- Void-Touched Augment Rune (Midnight)
    246492, -- Void-Touched / Midnight Augment Rune variant
    243191, -- Ethereal Augment Rune (Reusable)
    224572, -- Crystallized Augment Rune (TWW)
    211495, -- Dreambound Augment Rune (DF)
    201325, -- Draconic Augment Rune (DF)
    188016, -- Eternal Augment Rune (SL)
    160053, -- Battle-Scarred Augment Rune (BfA)
    153023, -- Lightforged Augment Rune (Legion)
    140587, -- Defiled Augment Rune (Legion)
    128482, -- Empowered Augment Rune (WoD)
    128475, -- Stout Augment Rune
    128461, -- Focus Augment Rune
    128474, -- Hyper Augment Rune
}

local CONSUMABLE_FOODS = {
    -- Midnight Foods
    241288, 241289, 241290, 241291, 241292,
    -- TWW Hearty Foods
    222718, 222719, 222720, 222721, 222722, 222723,
    222724, 222725, 222726, 222727, 222728, 222729,
    222730, 222731, 222732, 222733, 222734, 222735,
    222746, 222747,
    -- TWW Standard Food Portions & Meals
    222736, 222737, 222738, 222739, 222740, 222741,
    222742, 222743, 222744, 222745,
    -- Common Well Fed Portions (Meatballs, Tenderloin, Chowder, Sushi, Curry, etc.)
    224016, 224017, 224018, 224019, 224020, 224021, 224022, 224023, 224024, 224025,
    210652, 210653, 210654, 210655, 210656, 210657,
}

-- Known Midnight consumable quality overrides (Rank 2 Gold / Rank 1 Silver)
local KNOWN_MIDNIGHT_ITEMS = {
    [241288] = { tier = 2, maxTiers = 2 }, -- Gold quality (Tier 2)
    [241289] = { tier = 1, maxTiers = 2 }, -- Silver quality (Tier 1)
    [271883] = { tier = 2, maxTiers = 2 }, -- Concentrated Silvermoon Health Potion (Rank 2 Gold)
    [271882] = { tier = 1, maxTiers = 2 }, -- Concentrated Silvermoon Health Potion (Rank 1 Silver)
    [241305] = { tier = 2, maxTiers = 2 }, -- Silvermoon Health Potion (Rank 2 Gold)
    [241304] = { tier = 1, maxTiers = 2 }, -- Silvermoon Health Potion (Rank 1 Silver)
}

local function DetectConsumableQuality(link, itemID, bagID, slotID, classID)
    if not itemID and not link then return nil, nil, nil end
    local id = itemID or (type(link) == "string" and tonumber(link:match("item:(%d+)")))
    if id and KNOWN_MIDNIGHT_ITEMS[id] then
        local k = KNOWN_MIDNIGHT_ITEMS[id]
        return k.tier, k.maxTiers, nil
    end

    local q, atlas = nil, nil
    if C_TradeSkillUI and C_TradeSkillUI.GetItemCraftedQualityByItemInfo then
        local ok, val = pcall(C_TradeSkillUI.GetItemCraftedQualityByItemInfo, link or id)
        if ok and type(val) == "number" and val > 0 then q = val end
    end
    if not q and C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo then
        local ok, val = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, link or id)
        if ok and type(val) == "number" and val > 0 then q = val end
    end
    if not q and C_Item and C_Item.GetItemCraftedQualityByItemInfo then
        local ok, val = pcall(C_Item.GetItemCraftedQualityByItemInfo, link or id)
        if ok and type(val) == "number" and val > 0 then q = val end
    end

    if not q and C_TooltipInfo then
        local data = nil
        if bagID and slotID then
            local ok, d = pcall(C_TooltipInfo.GetBagItem, bagID, slotID)
            if ok and d then data = d end
        end
        if not data and link then
            local ok, d = pcall(C_TooltipInfo.GetHyperlink, link)
            if ok and d then data = d end
        end
        if not data and id then
            local ok, d = pcall(C_TooltipInfo.GetItemByID, id)
            if ok and d then data = d end
        end
        if data and data.lines then
            for _, line in ipairs(data.lines) do
                if line.atlas then
                    local t = line.atlas:match("Professions%-[%w%-_]*Quality%-Tier(%d)") or line.atlas:match("Quality%-Tier(%d)") or line.atlas:match("Tier(%d)")
                    if t then q = tonumber(t); atlas = line.atlas; break end
                end
                if line.leftText then
                    local t = line.leftText:match("Professions%-[%w%-_]*Quality%-Tier(%d)") or line.leftText:match("Quality%-Tier(%d)") or line.leftText:match("Tier(%d)")
                    if t then q = tonumber(t); break end
                end
            end
        end
    end

    if not q or q <= 0 then return nil, nil, atlas end

    -- Consumables in Midnight use a 2-tier system (Rank 2 Gold, Rank 1 Silver)
    local maxTiers = 2
    if q >= 3 then
        maxTiers = 3 -- Legacy 3-tier
    end
    return q, maxTiers, atlas
end

local function GetConsumableQualityAtlas(quality, maxTiers, tooltipAtlas)
    if tooltipAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(tooltipAtlas) then
        return tooltipAtlas, 1, 1, 1
    end
    if maxTiers == 2 then
        -- Midnight 2-tier system: Rank 2 = Gold, Rank 1 = Silver
        if quality >= 2 then
            return "Professions-Icon-Quality-Tier3-Small", 1.0, 0.84, 0.0 -- Gold
        else
            return "Professions-Icon-Quality-Tier2-Small", 0.78, 0.82, 0.88 -- Silver
        end
    elseif maxTiers == 3 then
        -- 3-tier legacy: Rank 1 = Bronze, Rank 2 = Silver, Rank 3 = Gold
        if quality == 1 then
            return "Professions-Icon-Quality-Tier1-Small", 0.80, 0.50, 0.20
        elseif quality == 2 then
            return "Professions-Icon-Quality-Tier2-Small", 0.78, 0.82, 0.88
        else
            return "Professions-Icon-Quality-Tier3-Small", 1.0, 0.84, 0.0
        end
    end
    return "Professions-Icon-Quality-Tier2-Small", 1, 1, 1
end

-- Reusable static queue table (expanded to 12 slots so Food & Runes are never starved)
local MAX_CRB_SLOTS = 16
local _crbQueue = {}
for i = 1, MAX_CRB_SLOTS do
    _crbQueue[i] = {
        active = false,
        actionType = nil,
        actionTarget = nil,
        macroText = nil,
        unit = nil,
        icon = nil,
        topText = "",
        bottomText = "",
        stackText = "",
        isExpiring = false,
        tooltipTitle = "",
        tooltipSub = "",
        isHearty = false,
        quality = nil,
        maxTiers = nil,
        qualityAtlas = nil,
    }
end

-- Helper: Strictly reject any equipped/equippable gear, weapons, bags, gems, or recipes
local function IsStrictlyConsumableItem(itemID, link, classID, invType)
    if invType and invType ~= "" and invType ~= "INVTYPE_NON_EQUIP" and invType ~= "INVTYPE_NON_EQUIP_IGNORE" then
        return false
    end
    if C_Item and C_Item.IsEquippableItem and C_Item.IsEquippableItem(link or itemID) then
        return false
    end
    -- classID 0 = Consumable, classID 19 = Item Enhancement (Oils/Stones)
    if classID and classID ~= 0 and classID ~= 19 then
        return false
    end
    return true
end

-- 1. Specialized Food Identification & Scanner (All Midnight & TWW Stat-Boosting / "Well Fed" Foods)
local function NormalizeConsumableBaseName(rawName)
    if not rawName then return "" end
    local clean = rawName
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("|A:.-|a", "")
        :gsub("|T.-|t", "")
        :gsub("^Hearty%s+", "")
        :gsub("^hearty%s+", "")
        :gsub("%s+", " ")
        :match("^%s*(.-)%s*$") or rawName
    return clean:lower()
end

local function ExtractAllTooltipText(tooltipData)
    if not tooltipData then return "" end
    local chunks = {}
    local function scanTbl(t, depth)
        if type(t) ~= "table" or depth > 4 then return end
        if type(t.leftText) == "string" and not _IsSecret(t.leftText) then
            chunks[#chunks + 1] = t.leftText
        end
        if type(t.rightText) == "string" and not _IsSecret(t.rightText) then
            chunks[#chunks + 1] = t.rightText
        end
        if type(t.stringVal) == "string" and not _IsSecret(t.stringVal) then
            chunks[#chunks + 1] = t.stringVal
        end
        if type(t.lines) == "table" then
            for i = 1, #t.lines do scanTbl(t.lines[i], depth + 1) end
        end
        if type(t.args) == "table" then
            for i = 1, #t.args do scanTbl(t.args[i], depth + 1) end
        end
    end
    scanTbl(tooltipData, 1)
    return table.concat(chunks, " \n "):lower()
end

local function InspectFoodTooltip(bag, slot, itemID, cleanName, itemRarity)
    local lowerName = cleanName and cleanName:lower() or ""
    local isHearty = (lowerName:find("^hearty") ~= nil) or (lowerName:find("hearty ") ~= nil)
    local isWellFedStatFood = isHearty

    -- Known Midnight & TWW Stat Food ItemID ranges (including 255847 Impossibly Royal Roast)
    if itemID == 255847 or (itemID >= 255800 and itemID <= 256000) or (itemID >= 222700 and itemID <= 222760) then
        isWellFedStatFood = true
    end

    local bagTipData = nil
    local spellTipData = nil

    -- Check Item Spell for Well Fed / Hearty / Food buff
    if C_Item and C_Item.GetItemSpell then
        local spellName, spellID = C_Item.GetItemSpell(itemID)
        if spellName and not _IsSecret(spellName) then
            local sn = spellName:lower()
            if sn:find("well fed") or sn:find("hearty") or sn:find("feast") then
                isWellFedStatFood = true
            end
        end
        if spellID and C_TooltipInfo and C_TooltipInfo.GetSpellByID then
            local okS, sData = pcall(C_TooltipInfo.GetSpellByID, spellID)
            if okS and sData then
                spellTipData = sData
                local sText = ExtractAllTooltipText(sData)
                if sText:find("well fed") or sText:find("primary stat") or sText:find("secondary stat")
                   or sText:find("haste") or sText:find("mastery") or sText:find("critical strike")
                   or sText:find("versatility") or sText:find("stamina") or sText:find("spend at least") then
                    isWellFedStatFood = true
                end
                if sText:find("persists through death") then
                    isHearty = true
                    isWellFedStatFood = true
                end
            end
        end
    end

    -- Deep scan Bag Item Tooltip (captures embedded Midnight [Well Fed] sub-blocks!)
    if C_TooltipInfo and bag and slot and C_TooltipInfo.GetBagItem then
        local ok, d = pcall(C_TooltipInfo.GetBagItem, bag, slot)
        if ok and d then
            bagTipData = d
            local fullText = ExtractAllTooltipText(d)
            if fullText:find("well fed")
               or fullText:find("spend at least")
               or (fullText:find("gaining") and (fullText:find("stat") or fullText:find("haste") or fullText:find("mastery") or fullText:find("critical") or fullText:find("versatility") or fullText:find("stamina")))
               or (fullText:find("gain") and (fullText:find("stat") or fullText:find("haste") or fullText:find("mastery") or fullText:find("critical") or fullText:find("versatility") or fullText:find("stamina")))
               or (fullText:find("increases") and (fullText:find("stat") or fullText:find("haste") or fullText:find("mastery") or fullText:find("critical") or fullText:find("versatility") or fullText:find("stamina")) and fullText:find("1 hour")) then
                isWellFedStatFood = true
            end
            if fullText:find("persists through death") then
                isHearty = true
                isWellFedStatFood = true
            end
        end
    end

    -- Reject poor/common (grey/white, rarity <= 1) food/drink that didn't explicitly match "well fed" or "gaining ... stat"
    if (itemRarity or 1) <= 1 and not isHearty then
        isWellFedStatFood = false
    end

    local statShort, statFullLine = nil, nil
    if isWellFedStatFood and DynamicPrep and type(DynamicPrep.ParseFoodBenefitFromTooltipText) == "function" then
        if bagTipData then
            statShort, statFullLine = DynamicPrep:ParseFoodBenefitFromTooltipText(bagTipData)
        end
        if (not statShort or statShort == "") and C_TooltipInfo and C_TooltipInfo.GetItemByID then
            local okI, iData = pcall(C_TooltipInfo.GetItemByID, itemID)
            if okI and iData then
                local iShort, iFull = DynamicPrep:ParseFoodBenefitFromTooltipText(iData)
                if iShort and iShort ~= "" then
                    statShort = iShort
                    statFullLine = iFull
                elseif not statFullLine then
                    statFullLine = iFull
                end
            end
        end
        if (not statShort or statShort == "") and spellTipData then
            local sShort, sFull = DynamicPrep:ParseFoodBenefitFromTooltipText(spellTipData)
            if sShort and sShort ~= "" then
                statShort = sShort
                statFullLine = sFull
            elseif not statFullLine then
                statFullLine = sFull
            end
        end
    end

    return isWellFedStatFood, isHearty, statShort, statFullLine
end

local function IsStatFoodItem(itemID, link, classID, subClassID, invType, cleanName, itemRarity, bag, slot)
    if not itemID or not cleanName then return false, false end
    if not IsStrictlyConsumableItem(itemID, link, classID, invType) then return false, false end
    if classID ~= 0 then return false, false end

    local lower = cleanName:lower()
    -- Exclude flasks, phials, potions, runes, oils, stones, keystones, hearthstones, bandages, cauldrons
    if lower:find("flask") or lower:find("phial") or lower:find("potion")
       or lower:find("rune") or lower:find("oil") or lower:find("whetstone")
       or lower:find("weightstone") or lower:find("keystone") or lower:find("hearthstone")
       or lower:find("flightstone") or lower:find("bandage") or lower:find("cauldron")
       or subClassID == 1 or subClassID == 2 or subClassID == 3 or subClassID == 7 or subClassID == 9 then
        return false, false
    end

    return InspectFoodTooltip(bag, slot, itemID, cleanName, itemRarity)
end

DynamicPrep._bagConsumablesDirty = true
local _cachedFoods, _cachedFlasks, _cachedOil, _cachedRune = nil, nil, nil, nil

local function ScanOwnedFoods()
    if _cachedFoods and not DynamicPrep._bagConsumablesDirty then
        return _cachedFoods
    end
    local groupMap = {}
    local heartyList = {}
    local normalList = {}

    if C_Container and C_Container.GetContainerNumSlots then
        for bag = 0, 4 do
            local slots = C_Container.GetContainerNumSlots(bag) or 0
            for slot = 1, slots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID and info.hyperlink and not _IsSecret(info.hyperlink) then
                    local _, _, _, invType, icon, classID, subClassID
                    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
                        _, _, _, invType, icon, classID, subClassID = C_Item.GetItemInfoInstant(info.hyperlink or info.itemID)
                    end
                    local rawName = (C_Item.GetItemNameByID and C_Item.GetItemNameByID(info.itemID)) or info.hyperlink:match("%[(.-)%]") or ("item:" .. info.itemID)
                    local cleanName = rawName:gsub("|A:.-|a", ""):gsub("|T.-|t", ""):match("^%s*(.-)%s*$") or rawName
                    local itemRarity = info.quality or (C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(info.itemID)) or 1

                    local isStatFood, isHearty, statShort, statFullLine = IsStatFoodItem(info.itemID, info.hyperlink, classID, subClassID, invType, cleanName, itemRarity, bag, slot)
                    if isStatFood then
                        local q, maxT, atlas = DetectConsumableQuality(info.hyperlink, info.itemID, bag, slot, classID)
                        local slotStack = info.stackCount or 1

                        -- Group multiple stacks of the exact same food itemID (e.g. 15 + 3 = 18 Impossibly Royal Roast!)
                        local groupKey = (isHearty and "H:" or "N:") .. tostring(info.itemID)
                        local existing = groupMap[groupKey]
                        if existing then
                            existing.cnt = existing.cnt + slotStack
                            if (not existing.statShort or existing.statShort == "") and statShort then
                                existing.statShort = statShort
                                existing.statFullLine = statFullLine
                            end
                        else
                            local entry = {
                                itemID = info.itemID,
                                cnt = slotStack,
                                icon = icon or info.iconFileID or 134400,
                                name = cleanName,
                                baseName = NormalizeConsumableBaseName(cleanName),
                                isHearty = isHearty,
                                itemRarity = itemRarity,
                                quality = q,
                                maxTiers = maxT or (q and 2 or nil),
                                atlas = atlas,
                                statShort = statShort,
                                statFullLine = statFullLine,
                            }
                            groupMap[groupKey] = entry
                            if isHearty then
                                table.insert(heartyList, entry)
                            else
                                table.insert(normalList, entry)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Sort by Item Rarity (Epic > Rare Blue like Impossibly Royal Roast > Uncommon Green), then Crafting Quality, then Stack Count!
    local function sortFoodGroup(a, b)
        local ra, rb = a.itemRarity or 1, b.itemRarity or 1
        if ra ~= rb then return ra > rb end
        local qa, qb = a.quality or 0, b.quality or 0
        if qa ~= qb then return qa > qb end
        return (a.cnt or 0) > (b.cnt or 0)
    end
    table.sort(heartyList, sortFoodGroup)
    table.sort(normalList, sortFoodGroup)

    local finalFoods = {}
    for _, h in ipairs(heartyList) do table.insert(finalFoods, h) end
    for _, n in ipairs(normalList) do table.insert(finalFoods, n) end
    _cachedFoods = finalFoods
    return finalFoods
end

local function ScanOwnedFood()
    local foods = ScanOwnedFoods()
    if foods and #foods > 0 then
        local b = foods[1]
        return b.itemID, b.cnt, b.icon, b.name, b.isHearty, b.quality, b.maxTiers, b.atlas
    end
    return nil, 0, nil, nil, false, nil, nil, nil
end

-- 2. Specialized Flask / Phial Identification & Scanner
-- Shows BOTH Rank 2 Gold & Rank 1 Silver, GROUPED together by Flask Type (e.g. Flask A Gold -> Flask A Silver -> Flask B Gold -> Flask B Silver)
local function IsFlaskItem(itemID, link, classID, subClassID, itemType, itemSubType, invType, name)
    if not itemID or not name then return false end
    if not IsStrictlyConsumableItem(itemID, link, classID, invType) then return false end
    if classID ~= 0 then return false end

    local lower = name:lower()

    if lower:find("potion") or lower:find("feast") or lower:find("food") or lower:find("drink")
       or lower:find("rune") or lower:find("oil") or lower:find("whetstone") or lower:find("weightstone")
       or lower:find("keystone") or lower:find("hearthstone") or lower:find("flightstone")
       or lower:find("bandage") or lower:find("cauldron") or lower:find("roast") or lower:find("salad")
       or subClassID == 1 or subClassID == 5 or subClassID == 7 or subClassID == 9 then
        return false
    end

    if subClassID == 3 or subClassID == 2 then
        return true
    end
    if itemSubType and (itemSubType:find("Flask") or itemSubType:find("Phial")) then
        return true
    end
    if lower:find("flask") or lower:find("phial") then
        return true
    end

    return false
end


local function ScanOwnedFlasks()
    if _cachedFlasks and not DynamicPrep._bagConsumablesDirty then
        return _cachedFlasks
    end
    local list = {}
    local byItemID = {}

    if C_Container and C_Container.GetContainerNumSlots then
        for bag = 0, 4 do
            local slots = C_Container.GetContainerNumSlots(bag) or 0
            for slot = 1, slots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID and info.hyperlink and not _IsSecret(info.hyperlink) then
                    local _, itemType, itemSubType, invType, icon, classID, subClassID
                    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
                        _, itemType, itemSubType, invType, icon, classID, subClassID = C_Item.GetItemInfoInstant(info.hyperlink or info.itemID)
                    end
                    local rawName = (C_Item.GetItemNameByID and C_Item.GetItemNameByID(info.itemID)) or info.hyperlink:match("%[(.-)%]") or ("item:" .. info.itemID)
                    local cleanName = rawName:gsub("|A:.-|a", ""):gsub("|T.-|t", ""):match("^%s*(.-)%s*$") or rawName

                    if IsFlaskItem(info.itemID, info.hyperlink, classID, subClassID, itemType, itemSubType, invType, cleanName) then
                        local isFleeting = (cleanName:lower():find("fleeting") ~= nil)
                        local q, maxT, atlas = DetectConsumableQuality(info.hyperlink, info.itemID, bag, slot, classID)
                        local slotStack = info.stackCount or 1
                        local baseName = NormalizeConsumableBaseName(cleanName)

                        -- Key strictly by itemID so Rank 2 Gold and Rank 1 Silver are BOTH shown as separate buttons!
                        local existing = byItemID[info.itemID]
                        if existing then
                            existing.cnt = existing.cnt + slotStack
                        else
                            local entry = {
                                itemID = info.itemID,
                                cnt = slotStack,
                                icon = icon or info.iconFileID or 134400,
                                name = cleanName,
                                baseName = baseName,
                                isFleeting = isFleeting,
                                quality = q or 1,
                                maxTiers = maxT or 2,
                                atlas = atlas,
                            }
                            byItemID[info.itemID] = entry
                            table.insert(list, entry)
                        end
                    end
                end
            end
        end
    end

    if #list > 0 then
        -- Group by Flask Name (`baseName`) first, and within that Flask put Rank 2 Gold before Rank 1 Silver!
        table.sort(list, function(a, b)
            if a.isFleeting ~= b.isFleeting then return a.isFleeting end
            if a.baseName ~= b.baseName then
                return a.baseName < b.baseName
            end
            local qa = a.quality or 0
            local qb = b.quality or 0
            if qa ~= qb then return qa > qb end
            return (a.cnt or 0) > (b.cnt or 0)
        end)
    end

    _cachedFlasks = list
    return list
end

local function ScanOwnedFlask()
    local flasks = ScanOwnedFlasks()
    if flasks and #flasks > 0 then
        local b = flasks[1]
        return b.itemID, b.cnt, b.icon, b.name, b.isFleeting, b.quality, b.maxTiers, b.atlas
    end
    return nil, 0, nil, nil, false, nil, nil, nil
end
local function IsWeaponOilItem(itemID, link, classID, subClassID, invType, name, bag, slot)
    if not itemID or not name then return false end
    if not IsStrictlyConsumableItem(itemID, link, classID, invType) then return false end
    local lower = name:lower()
    if lower:find("rune") or lower:find("keystone") or lower:find("hearthstone") or lower:find("flightstone")
       or lower:find("potion") or lower:find("flask") or lower:find("phial") or lower:find("feast")
       or lower:find("bandage") or lower:find("food") or lower:find("drink") then
        return false
    end
    for i = 1, #CONSUMABLE_WEAPON_OILS do
        if CONSUMABLE_WEAPON_OILS[i] == itemID then return true end
    end
    if classID == 0 or classID == 19 then
        if lower:find("oil") or lower:find("whetstone") or lower:find("weightstone") or lower:find("mana oil") or lower:find("sharpening stone") then
            return true
        end
    end
    return false
end


-- 3. Specialized Weapon Oil Scanner: Groups ranks of the same oil and picks highest rank for 1-click apply
local function ScanOwnedWeaponOil()
    if _cachedOil and not DynamicPrep._bagConsumablesDirty then
        return _cachedOil[1], _cachedOil[2], _cachedOil[3], _cachedOil[4], _cachedOil[5], _cachedOil[6], _cachedOil[7]
    end
    local bestOil = nil
    local totalSameOilCnt = 0
    local countedIDs = {}

    if C_Container and C_Container.GetContainerNumSlots then
        for bag = 0, 4 do
            local slots = C_Container.GetContainerNumSlots(bag) or 0
            for slot = 1, slots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID and info.hyperlink and not _IsSecret(info.hyperlink) then
                    local _, _, _, invType, icon, classID, subClassID
                    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
                        _, _, _, invType, icon, classID, subClassID = C_Item.GetItemInfoInstant(info.hyperlink or info.itemID)
                    end
                    local name = info.hyperlink:match("%[(.-)%]") or (C_Item.GetItemNameByID and C_Item.GetItemNameByID(info.itemID)) or ""
                    if IsWeaponOilItem(info.itemID, info.hyperlink, classID, subClassID, invType, name, bag, slot) then
                        local cnt = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(info.itemID, false, false, false)) or info.stackCount or 1
                        if not countedIDs[info.itemID] then
                            countedIDs[info.itemID] = true
                            totalSameOilCnt = totalSameOilCnt + cnt
                        end
                        local q, maxT, atlas = DetectConsumableQuality(info.hyperlink, info.itemID, bag, slot, classID)
                        local entry = {
                            itemID = info.itemID,
                            cnt = cnt,
                            icon = icon or info.iconFileID or 134400,
                            name = name,
                            quality = q or 1,
                            maxTiers = maxT or 2,
                            atlas = atlas,
                        }
                        if not bestOil or (entry.quality > bestOil.quality) or (entry.quality == bestOil.quality and cnt > bestOil.cnt) then
                            bestOil = entry
                        end
                    end
                end
            end
        end
    end

    if bestOil then
        local cnt = (totalSameOilCnt > 0 and totalSameOilCnt or bestOil.cnt)
        _cachedOil = { bestOil.itemID, cnt, bestOil.icon, bestOil.name, bestOil.quality, bestOil.maxTiers, bestOil.atlas }
        return bestOil.itemID, cnt, bestOil.icon, bestOil.name, bestOil.quality, bestOil.maxTiers, bestOil.atlas
    end
    _cachedOil = { nil, 0, nil, nil, nil, nil, nil }
    return nil, 0, nil, nil, nil, nil, nil
end

local function IsAugmentRuneItem(itemID, link, classID, subClassID, invType, name, bag, slot)
    if not itemID or not name then return false end
    if not IsStrictlyConsumableItem(itemID, link, classID, invType) then return false end
    if classID ~= 0 then return false end

    local lower = name:lower()
    if lower:find("vantus") or lower:find("keystone") or lower:find("hearthstone") or lower:find("flightstone")
       or lower:find("potion") or lower:find("flask") or lower:find("phial") or lower:find("food")
       or lower:find("oil") or lower:find("whetstone") or lower:find("weightstone") then
        return false
    end
    for i = 1, #CONSUMABLE_RUNES do
        if CONSUMABLE_RUNES[i] == itemID then return true end
    end
    if lower:find("augment rune") or (lower:find("augment") and lower:find("rune")) then
        return true
    end
    if C_TooltipInfo and bag and slot then
        local ok, d = pcall(C_TooltipInfo.GetBagItem, bag, slot)
        if ok and d and d.lines then
            for _, l in ipairs(d.lines) do
                local text = l.leftText
                if not text and l.args then
                    for _, a in ipairs(l.args) do
                        if a.stringVal then text = (text and (text .. " ") or "") .. a.stringVal end
                    end
                end
                if text then
                    local tl = text:lower()
                    if tl:find("augmentation") or (tl:find("primary stat") and tl:find("1 hour")) or (tl:find("agility") and tl:find("strength") and tl:find("intellect")) then
                        return true
                    end
                end
            end
        end
    end
    return false
end


-- 4. Specialized Augment Rune Scanner
local function ScanOwnedAugmentRune()
    if _cachedRune and not DynamicPrep._bagConsumablesDirty then
        return _cachedRune[1], _cachedRune[2], _cachedRune[3], _cachedRune[4], _cachedRune[5], _cachedRune[6], _cachedRune[7]
    end
    local bestRune = nil

    if C_Container and C_Container.GetContainerNumSlots then
        for bag = 0, 4 do
            local slots = C_Container.GetContainerNumSlots(bag) or 0
            for slot = 1, slots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID and info.hyperlink and not _IsSecret(info.hyperlink) then
                    local _, _, _, invType, icon, classID, subClassID
                    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
                        _, _, _, invType, icon, classID, subClassID = C_Item.GetItemInfoInstant(info.hyperlink or info.itemID)
                    end
                    local name = info.hyperlink:match("%[(.-)%]") or (C_Item.GetItemNameByID and C_Item.GetItemNameByID(info.itemID)) or ""
                    if IsAugmentRuneItem(info.itemID, info.hyperlink, classID, subClassID, invType, name, bag, slot) then
                        local cnt = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(info.itemID, false, false, false)) or info.stackCount or 1
                        local q, maxT, atlas = DetectConsumableQuality(info.hyperlink, info.itemID, bag, slot, classID)
                        local entry = {
                            itemID = info.itemID,
                            cnt = cnt,
                            icon = icon or info.iconFileID or 134400,
                            name = name,
                            quality = q,
                            maxTiers = maxT,
                            atlas = atlas,
                        }
                        if not bestRune or cnt > bestRune.cnt then
                            bestRune = entry
                        end
                    end
                end
            end
        end
    end

    if bestRune then
        _cachedRune = { bestRune.itemID, bestRune.cnt, bestRune.icon, bestRune.name, bestRune.quality, bestRune.maxTiers, bestRune.atlas }
        return bestRune.itemID, bestRune.cnt, bestRune.icon, bestRune.name, bestRune.quality, bestRune.maxTiers, bestRune.atlas
    end
    _cachedRune = { nil, 0, nil, nil, nil, nil, nil }
    return nil, 0, nil, nil, nil, nil, nil
end

-- 5. Generic Consumable Scanner (fallback)
local function ScanOwnedConsumable(itemList)
    if C_Item and C_Item.GetItemCount then
        for i = 1, #itemList do
            local itemID = itemList[i]
            local ok, cnt = pcall(C_Item.GetItemCount, itemID, false, false, false)
            if ok and type(cnt) == "number" and not _IsSecret(cnt) and cnt > 0 then
                local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID) or 134400
                local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID) or ("item:" .. itemID)
                return itemID, cnt, icon, name
            end
        end
    end
    return nil, 0, nil, nil
end

local _unitAuraStateCache = {}
local _staticWellFedNames = { ["Well Fed"] = true, ["Hearty Well Fed"] = true }
local _staticEatingNames = { ["Food"] = true, ["Food & Drink"] = true }
local _staticBeaconNames = { ["Beacon of Light"] = true }
local _staticBeaconIDs = { [53563] = true }
local _staticEarthShieldIDs = { [974] = true }

local function _IsMidnightAuraSecretForUnit(unit)
    if _dpSimSecretMode then return true end
    if C_Secrets then
        if C_Secrets.ShouldAurasBeSecret then
            local ok, res = pcall(C_Secrets.ShouldAurasBeSecret)
            if ok and not _IsSecret(res) and res then return true end
            if unit then
                local okU, resU = pcall(C_Secrets.ShouldAurasBeSecret, unit)
                if okU and not _IsSecret(resU) and resU then return true end
            end
        end
        if unit and C_Secrets.ShouldUnitAurasBeSecret then
            local okU, resU = pcall(C_Secrets.ShouldUnitAurasBeSecret, unit)
            if okU and not _IsSecret(resU) and resU then return true end
        end
    end
    return false
end


local function GetUnitAuraCacheKey(unitKey, matchNames, matchIDs, matchSubstring)
    local buffKey = matchSubstring
    if not buffKey and matchIDs then
        local minK = nil
        for k in pairs(matchIDs) do
            if type(k) == "number" and (not minK or k < minK) then
                minK = k
            end
        end
        if minK then buffKey = "id:" .. tostring(minK) end
    end
    if not buffKey and matchNames then
        local minN = nil
        for k in pairs(matchNames) do
            if type(k) == "string" and (not minN or k < minN) then
                minN = k
            end
        end
        if minN then buffKey = "nm:" .. tostring(minN) end
    end
    return tostring(unitKey) .. "|" .. tostring(buffKey or "aura")
end

local function SafeHasAura(unit, matchNames, matchIDs, matchSubstring, matchIcons, allowDuringCombat)
    if not unit then return false, 0, false, 0, nil end
    if not allowDuringCombat and _AreAurasSecret(unit) then
        return false, 0, true, 0, nil
    end
    if type(UnitExists) ~= "function" then
        return false, 0, false, 0, nil
    end
    local okEx, exists = pcall(UnitExists, unit)
    if not okEx or _IsSecret(exists) or not exists then
        return false, 0, false, 0, nil
    end
    if _dpSimSecretMode then
        return false, 0, true, 0, nil
    end
    local now = (type(GetTime) == "function" and GetTime()) or 0
    local sawSecret = _IsMidnightAuraSecretForUnit(unit)
    if matchIDs and C_UnitAuras then
        local checkedBySpellID = false
        if unit == "player" and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function" then
            checkedBySpellID = true
            for spellID in pairs(matchIDs) do
                local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
                if not ok then
                    sawSecret = true
                elseif _IsSecret(aura) then
                    sawSecret = true
                elseif aura then
                    local exp = (not _IsSecret(aura.expirationTime) and type(aura.expirationTime) == "number") and aura.expirationTime or 0
                    local rem = (exp > 0) and math.max(0, exp - now) or 99999
                    return true, rem, false, exp, aura
                end
            end
        end
        if type(C_UnitAuras.GetUnitAuraBySpellID) == "function" then
            checkedBySpellID = true
            for spellID in pairs(matchIDs) do
                local ok, aura = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, spellID)
                if not ok then
                    sawSecret = true
                elseif _IsSecret(aura) then
                    sawSecret = true
                elseif aura then
                    local exp = (not _IsSecret(aura.expirationTime) and type(aura.expirationTime) == "number") and aura.expirationTime or 0
                    local rem = (exp > 0) and math.max(0, exp - now) or 99999
                    return true, rem, false, exp, aura
                end
            end
        end
        -- Fast-path during combat: if spellID lookup succeeded without secret taint and no substring/icon fallback is requested,
        -- return immediately in O(1) without iterating 1..60 GetBuffDataByIndex slots per raid member.
        if checkedBySpellID and IsPlayerInCombat() and matchSubstring == nil and matchIcons == nil then
            return false, 0, sawSecret, 0, nil
        end
    end
    if matchNames and AuraUtil and type(AuraUtil.FindAuraByName) == "function" then
        for aName in pairs(matchNames) do
            local okA, nameVal, _, _, _, _, expVal = pcall(AuraUtil.FindAuraByName, aName, unit, "HELPFUL")
            if not okA then
                sawSecret = true
            elseif not _IsSecret(nameVal) and nameVal then
                local exp = (not _IsSecret(expVal) and type(expVal) == "number") and expVal or 0
                local rem = (exp > 0) and math.max(0, exp - now) or 99999
                return true, rem, false, exp, nil
            end
        end
    end
    local lowerSub = (type(matchSubstring) == "string" and matchSubstring ~= "") and matchSubstring:lower() or nil
    local auraByIndexFn = C_UnitAuras and ((type(C_UnitAuras.GetBuffDataByIndex) == "function" and C_UnitAuras.GetBuffDataByIndex)
        or (type(C_UnitAuras.GetAuraDataByIndex) == "function" and C_UnitAuras.GetAuraDataByIndex))
    if auraByIndexFn then
        for i = 1, 60 do
            local ok, aura = pcall(auraByIndexFn, unit, i, "HELPFUL")
            if not ok then
                sawSecret = true
            elseif _IsSecret(aura) then
                sawSecret = true
            elseif not aura then
                break
            else
                local spellId = (not _IsSecret(aura.spellId) and type(aura.spellId) == "number") and aura.spellId or nil
                local name = (not _IsSecret(aura.name) and type(aura.name) == "string") and aura.name or nil
                local icon = (not _IsSecret(aura.icon) and type(aura.icon) == "number") and aura.icon or nil
                if _IsSecret(aura.spellId) or _IsSecret(aura.name) or _IsSecret(aura.icon) then
                    sawSecret = true
                end
                local matched = false
                if spellId and matchIDs and matchIDs[spellId] then
                    matched = true
                elseif icon and matchIcons and matchIcons[icon] then
                    matched = true
                elseif name and matchNames and matchNames[name] then
                    matched = true
                elseif name and lowerSub and name:lower():find(lowerSub, 1, true) then
                    matched = true
                end
                if matched then
                    local exp = (not _IsSecret(aura.expirationTime) and type(aura.expirationTime) == "number") and aura.expirationTime or 0
                    local rem = (exp > 0) and math.max(0, exp - now) or 99999
                    return true, rem, false, exp, aura
                end
            end
        end
    end
    return false, 0, sawSecret, 0, nil
end

local function CheckUnitAuraState(unit, matchNames, matchIDs, matchSubstring, expireThresholdSec, matchIcons, allowDuringCombat)
    if not unit or not C_UnitAuras then return false, 0, false end

    local unitKey = unit
    if UnitGUID then
        local okG, guid = pcall(UnitGUID, unit)
        if okG and not _IsSecret(guid) and guid and type(guid) == "string" then
            unitKey = guid
        end
    end
    local cacheKey = GetUnitAuraCacheKey(unitKey, matchNames, matchIDs, matchSubstring)

    local found, rem, sawSecret, expTime = SafeHasAura(unit, matchNames, matchIDs, matchSubstring, matchIcons, allowDuringCombat)
    if found then
        _unitAuraStateCache[cacheKey] = { hasBuff = true, rem = rem, expirationTime = expTime or 0 }
        return true, rem, false
    end

    if sawSecret then
        local cached = _unitAuraStateCache[cacheKey]
        if cached ~= nil then
            local now = GetTime and GetTime() or 0
            local liveRem = cached.rem or 99999
            if cached.expirationTime and cached.expirationTime > 0 then
                liveRem = math.max(0, cached.expirationTime - now)
                if liveRem <= 0 then
                    return false, 0, false
                end
            end
            return cached.hasBuff, liveRem, false
        end
        return true, 99999, true
    end

    _unitAuraStateCache[cacheKey] = { hasBuff = false, rem = 0, expirationTime = 0 }
    return false, 0, false
end

-- ============================================================================
-- 1. SYMBIOTIC RELATIONSHIP LINKED-TARGET DETECTION & BOND CACHE ENGINE
-- ============================================================================
DynamicPrep._symbioticBondCache = {
    active = false,
    unit = nil,
    guid = nil,
    name = nil,
    classFile = nil,
    coloredName = nil,
    castTime = 0,
    expirationTime = 0,
}

function DynamicPrep:GetUnitClassColoredName(unit, fallbackName, fallbackClassFile)
    local rawName = fallbackName
    local classFile = fallbackClassFile
    if unit and UnitExists then
        local okEx, ex = pcall(UnitExists, unit)
        if okEx and not _IsSecret(ex) and ex then
            if UnitName then
                local okN, n = pcall(UnitName, unit)
                if okN and type(n) == "string" and not _IsSecret(n) and n ~= "" then
                    rawName = n
                end
            end
            if UnitClass then
                local okC, _, cf = pcall(UnitClass, unit)
                if okC and type(cf) == "string" and not _IsSecret(cf) and cf ~= "" then
                    classFile = cf
                end
            end
        end
    end
    rawName = (type(rawName) == "string" and rawName ~= "") and rawName:gsub("%-.+$", "") or "Ally"
    local hex = "38BDF8"
    if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        if c.colorStr and type(c.colorStr) == "string" and #c.colorStr == 8 then
            hex = c.colorStr:sub(3, 8)
        elseif c.r and c.g and c.b then
            hex = string.format("%02X%02X%02X", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
        end
    end
    return "|cFF" .. hex .. rawName .. "|r", rawName, classFile
end

function DynamicPrep:InvalidateSymbioticBond(reason)
    local bc = self._symbioticBondCache
    if not bc then return end
    bc.active = false
    bc.unit = nil
    bc.guid = nil
    bc.name = nil
    bc.classFile = nil
    bc.coloredName = nil
    bc.castTime = 0
    bc.expirationTime = 0
    bc.lastInvalidateReason = reason
end

function DynamicPrep:RecordSymbioticCastTarget(targetHint)
    local bc = self._symbioticBondCache
    if not bc then return end

    local resolvedUnit = nil
    local cleanHint = (type(targetHint) == "string" and not _IsSecret(targetHint)) and targetHint:gsub("%-.+$", "") or nil

    local function MatchesHintOrRole(u, checkNameOnly)
        if not u or not UnitExists then return false end
        local okEx, ex = pcall(UnitExists, u)
        if not okEx or _IsSecret(ex) or not ex then return false end
        local okDead, dead = pcall(UnitIsDeadOrGhost, u)
        if okDead and not _IsSecret(dead) and dead then return false end
        if cleanHint and cleanHint ~= "" and UnitName then
            local okN, n = pcall(UnitName, u)
            if okN and type(n) == "string" and not _IsSecret(n) then
                local shortN = n:gsub("%-.+$", "")
                if shortN == cleanHint or n == targetHint then
                    return true
                end
            end
        end
        if not checkNameOnly and (u == "mouseover" or u == "target" or u == "focus") then
            if UnitInParty or UnitInRaid then
                local okP, inP = pcall(UnitInParty, u)
                local okR, inR = pcall(UnitInRaid, u)
                if (okP and not _IsSecret(inP) and inP) or (okR and not _IsSecret(inR) and inR) then
                    local okSelf, isSelf = pcall(UnitIsUnit, u, "player")
                    if not (okSelf and not _IsSecret(isSelf) and isSelf) then
                        return true
                    end
                end
            end
        end
        return false
    end

    -- 1. Try matching targetHint against party1..4 / raid1..40 first so we store a stable group unit token
    if IsInRaid and IsInRaid() then
        local n = GetNumGroupMembers and GetNumGroupMembers() or 0
        for i = 1, n do
            local u = "raid" .. i
            if MatchesHintOrRole(u, true) then
                resolvedUnit = u
                break
            end
        end
    elseif IsInGroup and IsInGroup() then
        local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
        for i = 1, n do
            local u = "party" .. i
            if MatchesHintOrRole(u, true) then
                resolvedUnit = u
                break
            end
        end
    end

    -- 2. Check mouseover / target if targetHint wasn't given (e.g. UNIT_SPELLCAST_SUCCEEDED without prior SENT name)
    if not resolvedUnit then
        for _, cand in ipairs({ "mouseover", "target", "focus" }) do
            if MatchesHintOrRole(cand, false) then
                -- Map back to party/raid token if possible
                if IsInRaid and IsInRaid() then
                    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
                    for i = 1, n do
                        local u = "raid" .. i
                        local okU, same = pcall(UnitIsUnit, u, cand)
                        if okU and not _IsSecret(same) and same then
                            resolvedUnit = u
                            break
                        end
                    end
                elseif IsInGroup and IsInGroup() then
                    local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
                    for i = 1, n do
                        local u = "party" .. i
                        local okU, same = pcall(UnitIsUnit, u, cand)
                        if okU and not _IsSecret(same) and same then
                            resolvedUnit = u
                            break
                        end
                    end
                end
                resolvedUnit = resolvedUnit or cand
                break
            end
        end
    end

    -- 3. Fallback to preferred Tank/Healer in group if macro auto-targeted them
    if not resolvedUnit then
        if IsInRaid and IsInRaid() then
            local n = GetNumGroupMembers and GetNumGroupMembers() or 0
            for i = 1, n do
                local u = "raid" .. i
                local okSelf, isSelf = pcall(UnitIsUnit, u, "player")
                if not (okSelf and not _IsSecret(isSelf) and isSelf) and UnitGroupRolesAssigned then
                    local okR, r = pcall(UnitGroupRolesAssigned, u)
                    if okR and not _IsSecret(r) and (r == "TANK" or r == "HEALER") then
                        resolvedUnit = u
                        break
                    end
                end
            end
        elseif IsInGroup and IsInGroup() then
            local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
            for i = 1, n do
                local u = "party" .. i
                if UnitGroupRolesAssigned then
                    local okR, r = pcall(UnitGroupRolesAssigned, u)
                    if okR and not _IsSecret(r) and (r == "TANK" or r == "HEALER") then
                        resolvedUnit = u
                        break
                    end
                end
                if not resolvedUnit then resolvedUnit = u end
            end
        end
    end

    local colored, rawName, classFile = self:GetUnitClassColoredName(resolvedUnit, cleanHint, nil)
    local guid = nil
    if resolvedUnit and UnitGUID then
        local okG, g = pcall(UnitGUID, resolvedUnit)
        if okG and type(g) == "string" and not _IsSecret(g) then guid = g end
    end

    bc.active = true
    bc.unit = resolvedUnit
    bc.guid = guid
    bc.name = rawName
    bc.classFile = classFile
    bc.coloredName = colored
    bc.castTime = GetTime and GetTime() or 0
    bc.expirationTime = (bc.castTime > 0) and (bc.castTime + 3600) or 0
end

function DynamicPrep:ValidateAndScanSymbioticBond(expThresholdSec)
    local bc = self._symbioticBondCache
    local inGroup = ((IsInRaid and IsInRaid()) or (IsInGroup and IsInGroup())) and true or false
    if not inGroup then
        self:InvalidateSymbioticBond("NOT_IN_GROUP")
        return false, nil, nil, 0, false
    end
    if not SafeIsPlayerSpellKnown(474750) then
        return false, nil, nil, 0, false
    end

    local function SafeBool(fn, u, def)
        if type(fn) ~= "function" then return def end
        local ok, v = pcall(fn, u)
        if ok and v ~= nil and not _IsSecret(v) then
            return v and true or false
        end
        return def
    end

    -- Fast-path during combat: never scan 40 raid members x 60 buffs in combat.
    -- Instead verify the cached bonded partner's life & connection state in O(1).
    if IsPlayerInCombat() then
        if SafeBool(UnitIsDeadOrGhost, "player", false) then
            self:InvalidateSymbioticBond("PLAYER_DEAD")
            return false, nil, nil, 0, false
        end
        if bc.active and bc.unit and SafeBool(UnitExists, bc.unit, false) then
            if SafeBool(UnitIsDeadOrGhost, bc.unit, false) or not SafeBool(UnitIsConnected, bc.unit, true) then
                self:InvalidateSymbioticBond("ALLY_DEAD_OR_OFFLINE")
                return false, nil, nil, 0, false
            end
            local now = GetTime and GetTime() or 0
            local rem = (bc.expirationTime and bc.expirationTime > now) and (bc.expirationTime - now) or 3600
            local isExp = (expThresholdSec and rem > 0 and rem <= expThresholdSec) and true or false
            return true, bc.unit, bc.coloredName or bc.name or "Ally", rem, isExp
        end
        return false, nil, nil, 0, false
    end

    local symSpellName = "Symbiotic Relationship"
    if C_Spell and C_Spell.GetSpellName then
        local okS, spName = pcall(C_Spell.GetSpellName, 474750)
        if okS and type(spName) == "string" and not _IsSecret(spName) and spName ~= "" then
            symSpellName = spName
        end
    end
    local symNameMap = {
        ["Symbiotic Relationship"] = true,
        [symSpellName] = true,
    }

    local function InspectUnitForSymbioticAura(u)
        if not u or not SafeBool(UnitExists, u, false) then return false, 0, false end
        if u ~= "player" then
            if not SafeBool(UnitIsConnected, u, true) then return false, 0, false end
            if SafeBool(UnitIsDeadOrGhost, u, false) then return false, 0, false end
        else
            if SafeBool(UnitIsDeadOrGhost, "player", false) then return false, 0, false end
        end

        local now = GetTime and GetTime() or 0
        local sawSecret = false

        -- A. Check direct spell IDs (474750, 474754, 474753, etc.) via GetPlayerAuraBySpellID / GetUnitAuraBySpellID
        if C_UnitAuras then
            if u == "player" and C_UnitAuras.GetPlayerAuraBySpellID then
                for spID in pairs(SYMBIOTIC_SPELL_IDS) do
                    local okA, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spID)
                    if not okA then
                        sawSecret = true
                    elseif aura then
                        if _IsSecret(aura) then
                            sawSecret = true
                        else
                            local exp = (not _IsSecret(aura.expirationTime) and type(aura.expirationTime) == "number") and aura.expirationTime or 0
                            local rem = (exp > 0) and math.max(0, exp - now) or 99999
                            return true, rem, false
                        end
                    end
                end
            end
            if C_UnitAuras.GetUnitAuraBySpellID then
                for spID in pairs(SYMBIOTIC_SPELL_IDS) do
                    local okA, aura = pcall(C_UnitAuras.GetUnitAuraBySpellID, u, spID)
                    if not okA then
                        sawSecret = true
                    elseif aura then
                        if _IsSecret(aura) then
                            sawSecret = true
                        else
                            local src = (not _IsSecret(aura.sourceUnit) and type(aura.sourceUnit) == "string") and aura.sourceUnit or nil
                            local fromPlayer = (not _IsSecret(aura.isFromPlayerOrPlayerPet) and aura.isFromPlayerOrPlayerPet == true)
                            if u == "player" or fromPlayer or src == "player" or src == nil then
                                local exp = (not _IsSecret(aura.expirationTime) and type(aura.expirationTime) == "number") and aura.expirationTime or 0
                                local rem = (exp > 0) and math.max(0, exp - now) or 99999
                                return true, rem, false
                            end
                        end
                    end
                end
            end
        end

        -- B. Scan all helpful auras on the unit for SYMBIOTIC_SPELL_IDS OR localized spell name where sourceUnit == "player" or isFromPlayerOrPlayerPet
        if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
            for idx = 1, 60 do
                local okB, aura = pcall(C_UnitAuras.GetBuffDataByIndex, u, idx, "HELPFUL")
                if not okB then
                    sawSecret = true
                elseif not aura then
                    break
                elseif _IsSecret(aura) then
                    sawSecret = true
                else
                    local spId = (not _IsSecret(aura.spellId) and type(aura.spellId) == "number") and aura.spellId or nil
                    local aName = (not _IsSecret(aura.name) and type(aura.name) == "string") and aura.name or nil
                    local src = (not _IsSecret(aura.sourceUnit) and type(aura.sourceUnit) == "string") and aura.sourceUnit or nil
                    local fromPlayer = (not _IsSecret(aura.isFromPlayerOrPlayerPet) and aura.isFromPlayerOrPlayerPet == true)
                    if _IsSecret(aura.spellId) or _IsSecret(aura.name) then
                        sawSecret = true
                    end

                    local isMatch = false
                    if spId and SYMBIOTIC_SPELL_IDS[spId] then
                        if u == "player" or fromPlayer or src == "player" or src == nil then
                            isMatch = true
                        end
                    elseif aName and (symNameMap[aName] or aName:lower():find("symbiotic relationship", 1, true)) then
                        if u == "player" or fromPlayer or src == "player" or src == nil then
                            isMatch = true
                        end
                    end

                    if isMatch then
                        local exp = (not _IsSecret(aura.expirationTime) and type(aura.expirationTime) == "number") and aura.expirationTime or 0
                        local rem = (exp > 0) and math.max(0, exp - now) or 99999
                        return true, rem, false
                    end
                end
            end
        end

        return false, 0, sawSecret
    end

    -- Collect all current group units (party1..4 or raid1..40), WITHOUT 40yd range rejection so an already-bonded tank kiting >40yd is still recognized!
    local groupUnits = {}
    if IsInRaid and IsInRaid() then
        local n = GetNumGroupMembers and GetNumGroupMembers() or 0
        for i = 1, n do
            local u = "raid" .. i
            local okSame, same = pcall(UnitIsUnit, u, "player")
            if not (okSame and not _IsSecret(same) and same) then
                groupUnits[#groupUnits + 1] = u
            end
        end
    elseif IsInGroup and IsInGroup() then
        local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
        for i = 1, n do
            groupUnits[#groupUnits + 1] = "party" .. i
        end
    end

    -- If we had a previously bonded unit, verify they haven't died or left the group
    if bc.active and (bc.guid or bc.name or bc.unit) then
        local resolvedCachedUnit = nil
        for _, u in ipairs(groupUnits) do
            if bc.guid and UnitGUID then
                local okG, g = pcall(UnitGUID, u)
                if okG and not _IsSecret(g) and g == bc.guid then
                    resolvedCachedUnit = u
                    break
                end
            end
            if not resolvedCachedUnit and bc.name and UnitName then
                local okN, n = pcall(UnitName, u)
                if okN and type(n) == "string" and not _IsSecret(n) and n:gsub("%-.+$", "") == bc.name then
                    resolvedCachedUnit = u
                    break
                end
            end
        end
        if not resolvedCachedUnit then
            -- Bonded ally left the group!
            self:InvalidateSymbioticBond("LEFT_GROUP")
        else
            bc.unit = resolvedCachedUnit
            if SafeBool(UnitIsDeadOrGhost, resolvedCachedUnit, false) or not SafeBool(UnitIsConnected, resolvedCachedUnit, true) then
                -- Bonded ally died or disconnected -> bond is broken!
                self:InvalidateSymbioticBond("ALLY_DEAD_OR_OFFLINE")
                return false, nil, nil, 0, false
            end
        end
    end
    if SafeBool(UnitIsDeadOrGhost, "player", false) then
        self:InvalidateSymbioticBond("PLAYER_DEAD")
        return false, nil, nil, 0, false
    end

    -- 1. Scan all group units (party1..4 / raid1..40) for the active Symbiotic bond aura
    local foundOnAllyUnit = nil
    local bestRem = 99999
    local anySecretOnGroup = false
    for _, u in ipairs(groupUnits) do
        local hasBond, rem, isSec = InspectUnitForSymbioticAura(u)
        if isSec then anySecretOnGroup = true end
        if hasBond then
            foundOnAllyUnit = u
            bestRem = rem
            break
        end
    end

    -- 2. Also scan "player" for self-bond aura (e.g. 474750 / 474753 / "Symbiotic Relationship")
    local hasSelfBond, selfRem, selfSecret = InspectUnitForSymbioticAura("player")
    if selfSecret then anySecretOnGroup = true end

    if foundOnAllyUnit then
        local colored, rawName, classFile = self:GetUnitClassColoredName(foundOnAllyUnit, bc.name, bc.classFile)
        local guid = nil
        if UnitGUID then
            local okG, g = pcall(UnitGUID, foundOnAllyUnit)
            if okG and type(g) == "string" and not _IsSecret(g) then guid = g end
        end
        bc.active = true
        bc.unit = foundOnAllyUnit
        bc.guid = guid or bc.guid
        bc.name = rawName
        bc.classFile = classFile
        bc.coloredName = colored
        local now = GetTime and GetTime() or 0
        bc.expirationTime = (bestRem < 90000) and (now + bestRem) or (now + 3600)
        local isExp = (expThresholdSec and bestRem > 0 and bestRem <= expThresholdSec) and true or false
        return true, foundOnAllyUnit, colored, bestRem, isExp
    end

    -- If player has the caster bond aura (or aura reads are secret in combat / within 4s of UNIT_SPELLCAST_SUCCEEDED) and cached partner is alive & in group
    local now = GetTime and GetTime() or 0
    local withinCastGrace = bc.active and bc.castTime and (now - bc.castTime) <= 4.0
    if hasSelfBond or ((anySecretOnGroup or (InCombatLockdown and InCombatLockdown())) and bc.active) or withinCastGrace then
        local partnerUnit = bc.unit
        if partnerUnit and SafeBool(UnitExists, partnerUnit, false) and not SafeBool(UnitIsDeadOrGhost, partnerUnit, false) then
            local colored, rawName, classFile = self:GetUnitClassColoredName(partnerUnit, bc.name, bc.classFile)
            bc.active = true
            bc.name = rawName
            bc.classFile = classFile
            bc.coloredName = colored
            local rem = hasSelfBond and selfRem or ((bc.expirationTime and bc.expirationTime > now) and (bc.expirationTime - now) or 3600)
            local isExp = (expThresholdSec and rem > 0 and rem <= expThresholdSec) and true or false
            return true, partnerUnit, colored, rem, isExp
        elseif hasSelfBond then
            -- Player definitely has the Symbiotic self-bond aura, find the living Tank/Healer partner in group to label
            local inferredUnit = nil
            for _, u in ipairs(groupUnits) do
                if not SafeBool(UnitIsDeadOrGhost, u, false) and SafeBool(UnitIsConnected, u, true) then
                    if UnitGroupRolesAssigned then
                        local okR, r = pcall(UnitGroupRolesAssigned, u)
                        if okR and not _IsSecret(r) and r == "TANK" then
                            inferredUnit = u
                            break
                        end
                    end
                    if not inferredUnit then inferredUnit = u end
                end
            end
            if inferredUnit then
                local colored, rawName, classFile = self:GetUnitClassColoredName(inferredUnit, bc.name, bc.classFile)
                bc.active = true
                bc.unit = inferredUnit
                bc.name = rawName
                bc.classFile = classFile
                bc.coloredName = colored
                local isExp = (expThresholdSec and selfRem > 0 and selfRem <= expThresholdSec) and true or false
                return true, inferredUnit, colored, selfRem, isExp
            end
        end
    end

    -- Aura lost on both player and group units outside combat -> invalidate cached link
    if not anySecretOnGroup and not withinCastGrace then
        self:InvalidateSymbioticBond("AURA_LOST")
    end
    return false, nil, nil, 0, false
end

-- ============================================================================
-- 2. EXACT FOOD BUFF BENEFIT EXTRACTOR & OUT-OF-COMBAT STAT CACHE
-- ============================================================================
DynamicPrep._foodBenefitByInstanceID = {}
DynamicPrep._foodBenefitBySpellID = {}
DynamicPrep._lastActiveFoodBenefit = nil

local FOOD_STAT_PATTERNS = {
    { pattern = "critical strike", short = "Crit",      full = "Critical Strike" },
    { pattern = "haste",           short = "Haste",     full = "Haste" },
    { pattern = "mastery",         short = "Mastery",   full = "Mastery" },
    { pattern = "versatility",     short = "Vers",      full = "Versatility" },
    { pattern = "intellect",       short = "Intellect", full = "Intellect" },
    { pattern = "agility",         short = "Agility",   full = "Agility" },
    { pattern = "strength",        short = "Strength",  full = "Strength" },
    { pattern = "primary stat",    short = "Primary",   full = "Primary Stat" },
    { pattern = "highest secondary stat", short = "Highest Sec", full = "Highest Secondary Stat" },
    { pattern = "stamina",         short = "Stamina",   full = "Stamina" },
    { pattern = "speed",           short = "Speed",     full = "Speed" },
}

local function FormatFoodStatNumber(val)
    local n = tonumber(val)
    if not n then return tostring(val or "") end
    local s = tostring(math.floor(n + 0.5))
    local left, num, right = s:match("^([^%d]*%d)(%d*)(.-)$")
    if not left then return s end
    return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

function DynamicPrep:ParseFoodBenefitFromTooltipText(tooltipData, auraPoints)
    local rawLines = {}
    local function collectLines(t, depth)
        if type(t) ~= "table" or depth > 4 then return end
        if type(t.leftText) == "string" and not _IsSecret(t.leftText) and t.leftText ~= "" then
            rawLines[#rawLines + 1] = t.leftText
        end
        if type(t.stringVal) == "string" and not _IsSecret(t.stringVal) and t.stringVal ~= "" then
            rawLines[#rawLines + 1] = t.stringVal
        end
        if type(t.lines) == "table" then
            for i = 1, #t.lines do collectLines(t.lines[i], depth + 1) end
        end
        if type(t.args) == "table" then
            for i = 1, #t.args do collectLines(t.args[i], depth + 1) end
        end
    end
    if tooltipData then
        collectLines(tooltipData, 1)
    end

    local benefitLine = nil
    for _, line in ipairs(rawLines) do
        local clean = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|A:.-|a", ""):gsub("|T.-|t", ""):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
        local lower = clean:lower()
        if (lower:find("increases") or lower:find("increased by") or lower:find("grants")
            or lower:find("gain") or lower:find("gaining")
            or lower:find("well fed") or lower:find("become well fed"))
           and (lower:find("intellect") or lower:find("agility") or lower:find("strength") or lower:find("haste")
                or lower:find("mastery") or lower:find("critical") or lower:find("versatility")
                or lower:find("primary stat") or lower:find("secondary stat") or lower:find("stamina")) then
            benefitLine = clean
            break
        end
    end

    if not benefitLine and #rawLines >= 2 then
        for i = 2, #rawLines do
            local clean = rawLines[i]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
            local lower = clean:lower()
            if not lower:find("remaining") and not lower:find("^%d+ min") and not lower:find("^%d+ sec") and not lower:find("^%d+ hour") and #clean > 6 then
                benefitLine = clean
                break
            end
        end
    end

    local statPairs = {}
    if benefitLine then
        local norm = benefitLine:gsub(",", "")
        local lowerNorm = norm:lower()
        local strippedNorm = lowerNorm
            :gsub("spend at least%s+%d+%s+seconds?", "spend at least seconds")
            :gsub("for%s+%d+%s+hours?", "for hours")
            :gsub("for%s+%d+%s+min[utes]*", "for minutes")

        -- Pattern A: "Increases [Stat] by [Num]", "[Stat] increased by [Num]", or "gain [Num] [Stat]"
        for _, sp in ipairs(FOOD_STAT_PATTERNS) do
            local pos = strippedNorm:find(sp.pattern, 1, true)
            if pos then
                local afterSub = strippedNorm:sub(pos, math.min(#strippedNorm, pos + 48))
                local beforeSub = strippedNorm:sub(math.max(1, pos - 24), pos + #sp.pattern)
                local numStr = afterSub:match("by%s+(%d+)") or beforeSub:match("(%d+)%s+" .. sp.pattern) or afterSub:match("(%d+)")
                local val = numStr and tonumber(numStr) or nil
                if val and val == 1 and lowerNorm:find("1 hour", 1, true) then
                    val = nil
                end
                statPairs[#statPairs + 1] = { pos = pos, short = sp.short, full = sp.full, val = val }
            end
        end
        table.sort(statPairs, function(a, b) return a.pos < b.pos end)
    end

    -- Fallback to aura.points if tooltip numbers were not extracted
    local firstPoint = nil
    if type(auraPoints) == "table" and not _IsSecret(auraPoints) then
        for i = 1, #auraPoints do
            local pt = auraPoints[i]
            if not _IsSecret(pt) and type(pt) == "number" and pt > 0 then
                firstPoint = math.floor(pt + 0.5)
                break
            end
        end
    end

    if #statPairs > 0 then
        -- Filter out Stamina if a primary/secondary stat is also present so the concise tracker shows the main combat stat(s)
        local combatStats = {}
        for _, p in ipairs(statPairs) do
            if p.short ~= "Stamina" then
                combatStats[#combatStats + 1] = p
            end
        end
        local activeList = (#combatStats > 0) and combatStats or statPairs
        if #activeList >= 2 then
            local p1, p2 = activeList[1], activeList[2]
            local v1 = p1.val or firstPoint
            local v2 = p2.val
            if v1 and v2 and v1 ~= v2 then
                return string.format("+%s %s / +%s %s", FormatFoodStatNumber(v1), p1.short, FormatFoodStatNumber(v2), p2.short), benefitLine
            elseif v1 then
                return string.format("+%s %s / %s", FormatFoodStatNumber(v1), p1.short, p2.short), benefitLine
            else
                return string.format("%s / %s", p1.short, p2.short), benefitLine
            end
        else
            local p1 = activeList[1]
            local label = (p1.short == "Highest Sec" or p1.short == "Crit" or p1.short == "Vers") and p1.short or p1.full
            local v1 = p1.val or firstPoint
            if v1 and v1 > 0 then
                return string.format("+%s %s", FormatFoodStatNumber(v1), label), benefitLine
            else
                return label, benefitLine
            end
        end
    elseif firstPoint and firstPoint > 0 then
        local _, primaryLabel = self:GetPrimaryStatData()
        local statName = primaryLabel or "Stat"
        return string.format("+%s %s", FormatFoodStatNumber(firstPoint), statName), benefitLine or string.format("Increases %s by %s.", statName, FormatFoodStatNumber(firstPoint))
    end

    return nil, benefitLine
end

function DynamicPrep:FormatColoredFoodBenefit(statText)
    if type(statText) ~= "string" or statText == "" then return statText end
    if statText:find("|cFF", 1, true) then return statText end
    local function GetFoodStatHexColor(statSegment)
        if type(statSegment) ~= "string" then return nil end
        local lower = statSegment:lower()
        if lower:find("primary stat", 1, true)
            or lower:find("intellect", 1, true)
            or lower:find("agility", 1, true)
            or lower:find("strength", 1, true) then
            return "2DD4BF" -- Mint Teal
        elseif lower:find("highest secondary", 1, true)
            or lower:find("highest sec", 1, true) then
            return "F97316" -- Blaze Orange
        elseif lower:find("haste", 1, true) then
            return "38BDF8" -- Sky Cyan
        elseif lower:find("mastery", 1, true) then
            return "C084FC" -- Royal Amethyst
        elseif lower:find("critical strike", 1, true)
            or lower:find("crit", 1, true) then
            return "FACC15" -- Warm Amber-Gold
        elseif lower:find("versatility", 1, true)
            or lower:find("vers", 1, true) then
            return "34D399" -- Emerald Green
        elseif lower:find("stamina", 1, true) then
            return "94A3B8" -- Slate-Silver
        end
        return nil
    end
    local parts = {}
    local startIdx = 1
    while true do
        local sepStart, sepEnd = statText:find(" / ", startIdx, true)
        local seg = sepStart and statText:sub(startIdx, sepStart - 1) or statText:sub(startIdx)
        local hex = GetFoodStatHexColor(seg)
        parts[#parts + 1] = hex and ("|cFF" .. hex .. seg .. "|r") or seg
        if not sepStart then break end
        startIdx = sepEnd + 1
    end
    return table.concat(parts, " / ")
end

function DynamicPrep:GetActiveFoodBuffBenefit()
    local now = GetTime and GetTime() or 0
    -- Completely skip scanning Food buffs during combat (food cannot be eaten in combat)
    if IsPlayerInCombat() then
        local cached = self._lastActiveFoodBenefit
        if cached and cached.shortText then
            local rem = (cached.expirationTime and cached.expirationTime > 0) and math.max(0, cached.expirationTime - now) or (cached.rem or 3600)
            return true, cached.shortText, cached.fullLine, rem, cached.isHearty and true or false, cached
        end
        return false, nil, nil, 0, false, nil
    end
    local foodAuraFn = C_UnitAuras and ((type(C_UnitAuras.GetBuffDataByIndex) == "function" and C_UnitAuras.GetBuffDataByIndex)
        or (type(C_UnitAuras.GetAuraDataByIndex) == "function" and C_UnitAuras.GetAuraDataByIndex))
    if not foodAuraFn then
        return false, nil, nil, 0, false, nil
    end

    local sawSecret = false
    local matchedAura = nil
    local isHearty = false

    for i = 1, 60 do
        local ok, aura = pcall(foodAuraFn, "player", i, "HELPFUL")
        if not ok then
            sawSecret = true
        elseif not aura then
            break
        elseif _IsSecret(aura) then
            sawSecret = true
        else
            local name = (not _IsSecret(aura.name) and type(aura.name) == "string") and aura.name or nil
            if _IsSecret(aura.name) then
                sawSecret = true
            elseif name then
                local lower = name:lower()
                if _staticWellFedNames[name] or lower:find("well fed", 1, true) then
                    matchedAura = aura
                    isHearty = (lower:find("hearty", 1, true) ~= nil)
                    break
                end
            end
        end
    end

    if matchedAura then
        local instID = (not _IsSecret(matchedAura.auraInstanceID) and type(matchedAura.auraInstanceID) == "number") and matchedAura.auraInstanceID or nil
        local spID = (not _IsSecret(matchedAura.spellId) and type(matchedAura.spellId) == "number") and matchedAura.spellId or nil
        local exp = (not _IsSecret(matchedAura.expirationTime) and type(matchedAura.expirationTime) == "number") and matchedAura.expirationTime or 0
        local rem = (exp > 0) and math.max(0, exp - now) or 99999
        local auraName = (not _IsSecret(matchedAura.name) and type(matchedAura.name) == "string") and matchedAura.name or (isHearty and "Hearty Well Fed" or "Well Fed")
        local icon = (not _IsSecret(matchedAura.icon) and type(matchedAura.icon) == "number") and matchedAura.icon or 136000

        -- 1. Check cache first
        local cached = (instID and self._foodBenefitByInstanceID[instID]) or (spID and self._foodBenefitBySpellID[spID])
        if cached and cached.shortText then
            cached.rem = rem
            cached.expirationTime = exp
            cached.isHearty = isHearty
            cached.auraName = auraName
            cached.icon = icon
            self._lastActiveFoodBenefit = cached
            return true, cached.shortText, cached.fullLine, rem, isHearty, cached
        end

        -- 2. Parse via C_TooltipInfo.GetUnitBuffByAuraInstanceID("player", aura.auraInstanceID) with safe pcall fallback to aura.points
        local tooltipData = nil
        if instID and C_TooltipInfo and C_TooltipInfo.GetUnitBuffByAuraInstanceID then
            local okT, tData = pcall(C_TooltipInfo.GetUnitBuffByAuraInstanceID, "player", instID)
            if okT and tData and not _IsSecret(tData) then
                tooltipData = tData
            end
        end
        if not tooltipData and spID and C_TooltipInfo and C_TooltipInfo.GetSpellByID then
            local okS, sData = pcall(C_TooltipInfo.GetSpellByID, spID)
            if okS and sData and not _IsSecret(sData) then
                tooltipData = sData
            end
        end

        local pointsTbl = (not _IsSecret(matchedAura.points) and type(matchedAura.points) == "table") and matchedAura.points or nil
        local shortStat, fullLine = self:ParseFoodBenefitFromTooltipText(tooltipData, pointsTbl)
        if not shortStat and self._lastActiveFoodBenefit and self._lastActiveFoodBenefit.shortText then
            shortStat = self._lastActiveFoodBenefit.shortText
            fullLine = fullLine or self._lastActiveFoodBenefit.fullLine
        end
        shortStat = shortStat or (isHearty and "Hearty Well Fed" or "Well Fed")
        fullLine = fullLine or string.format("%s active (%s).", auraName, shortStat)

        local entry = {
            shortText = shortStat,
            fullLine = fullLine,
            auraName = auraName,
            isHearty = isHearty,
            icon = icon,
            rem = rem,
            expirationTime = exp,
            auraInstanceID = instID,
            spellId = spID,
        }
        if instID then self._foodBenefitByInstanceID[instID] = entry end
        if spID then self._foodBenefitBySpellID[spID] = entry end
        self._lastActiveFoodBenefit = entry
        return true, shortStat, fullLine, rem, isHearty, entry
    end

    -- If combat/secret restrictions blocked live aura reads, return the cached food buff benefit without flickering!
    if sawSecret and self._lastActiveFoodBenefit then
        local last = self._lastActiveFoodBenefit
        local liveRem = last.rem or 3600
        if last.expirationTime and last.expirationTime > 0 then
            liveRem = math.max(0, last.expirationTime - now)
            if liveRem <= 0 then
                self._lastActiveFoodBenefit = nil
                return false, nil, nil, 0, false, nil
            end
        end
        return true, last.shortText, last.fullLine, liveRem, last.isHearty, last
    end

    self._lastActiveFoodBenefit = nil
    return false, nil, nil, 0, false, nil
end

-- ============================================================================
-- 3. IN-COMBAT BATTLE-REZ & MISSING RAID BUFF TRACKER (UNIFIED READINESS STRIP)
-- ============================================================================
DynamicPrep._groupLifeStateByGUID = {}
DynamicPrep._combatNeedsRebuffQueue = {}
DynamicPrep._lastCombatBuffSummary = nil
DynamicPrep._inCombatState = false

local function SafeUnitBool(fn, u, fallback)
    if type(fn) ~= "function" or not u then return fallback end
    local ok, val = pcall(fn, u)
    if not ok or _IsSecret(val) or val == nil then
        return fallback
    end
    if type(val) == "boolean" then
        return val
    end
    return (val and true or false)
end

local function IsUnitEligibleForRaidBuff(u, playerInstID)
    if not SafeUnitBool(UnitExists, u, false) then return false end
    if not SafeUnitBool(UnitIsConnected, u, true) then return false end
    -- Dead players or players with an unaccepted pending Battle Res remain excluded until alive
    if SafeUnitBool(UnitIsDeadOrGhost, u, false) then return false end
    if not SafeUnitBool(UnitIsVisible, u, true) then return false end
    if u ~= "player" then
        if UnitPhaseReason then
            local okPh, phReason = pcall(UnitPhaseReason, u)
            if okPh and not _IsSecret(phReason) and phReason ~= nil then
                return false
            end
        elseif UnitInPhase then
            local okPh, inPh = pcall(UnitInPhase, u)
            if okPh and not _IsSecret(inPh) and not inPh then
                return false
            end
        end
        if playerInstID and UnitPosition then
            local okU, _, _, _, uInstID = pcall(UnitPosition, u)
            if okU and not _IsSecret(uInstID) and uInstID and uInstID ~= playerInstID then
                return false
            end
        end
    end
    return true
end

local function GetSafeUnitGUIDKey(u)
    if not u then return "unknown" end
    if UnitGUID then
        local okG, guid = pcall(UnitGUID, u)
        if okG and not _IsSecret(guid) and type(guid) == "string" and guid ~= "" then
            return guid
        end
    end
    return u
end

local function SetCachedClassRaidBuffState(unitKey, cDef, hasBuff, remSec)
    if not unitKey or not cDef then return end
    local cacheKey = GetUnitAuraCacheKey(unitKey, cDef.auraNames, cDef.auraIDs, nil)
    local now = GetTime and GetTime() or 0
    local r = hasBuff and (remSec or 3600) or 0
    _unitAuraStateCache[cacheKey] = {
        hasBuff = hasBuff and true or false,
        rem = r,
        expirationTime = hasBuff and (now + r) or 0,
    }
end

function DynamicPrep:ClearCombatRebuffQueueOnCast(castSpellID)
    local _, classFile = UnitClass("player")
    local cDef = classFile and CLASS_RAID_BUFFS[classFile]
    if not cDef then return end
    if castSpellID and (castSpellID == cDef.spellID or castSpellID == cDef.altSpellID or (cDef.auraIDs and cDef.auraIDs[castSpellID])) then
        wipe(self._combatNeedsRebuffQueue)

        local playerInstID = nil
        if UnitPosition then
            local okP, _, _, _, instID = pcall(UnitPosition, "player")
            if okP and not _IsSecret(instID) then playerInstID = instID end
        end

        local function MarkEligibleUnitBuffed(u)
            if IsUnitEligibleForRaidBuff(u, playerInstID) then
                local key = GetSafeUnitGUIDKey(u)
                SetCachedClassRaidBuffState(key, cDef, true, 3600)
                if key ~= u then
                    SetCachedClassRaidBuffState(u, cDef, true, 3600)
                end
            end
        end

        MarkEligibleUnitBuffed("player")
        if IsInRaid and IsInRaid() then
            local n = GetNumGroupMembers and GetNumGroupMembers() or 0
            for i = 1, n do
                MarkEligibleUnitBuffed("raid" .. i)
            end
        elseif IsInGroup and IsInGroup() then
            local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
            for i = 1, n do
                MarkEligibleUnitBuffed("party" .. i)
            end
        end

        self:RefreshCombatBuffAlert()
        if self.RefreshReadinessTrackerStrip then
            pcall(self.RefreshReadinessTrackerStrip, self)
        end
        self:UpdateSuiteHeaderStatus()
    end
end

local _reusableSeenGUIDs = {}
local _reusableMissingUnits = {}
local _reusableMissingByKey = {}
local _reusableColoredNames = {}
local _reusableCombatEntryPool = {}
local _reusableCombatSummary = {}

function DynamicPrep:UpdateGroupLifeStates(triggerEvent, triggerUnit)
    local inGroup = ((IsInRaid and IsInRaid()) or (IsInGroup and IsInGroup())) and true or false
    if not inGroup then
        wipe(self._groupLifeStateByGUID)
        wipe(self._combatNeedsRebuffQueue)
        return
    end

    local _, playerClassFile = UnitClass("player")
    local cDef = playerClassFile and CLASS_RAID_BUFFS[playerClassFile]
    local inCombat = IsPlayerInCombat()
    local seenGUIDs = _reusableSeenGUIDs
    wipe(seenGUIDs)

    local function CheckUnitLifeTransition(u, recordSeen)
        if not u or not SafeUnitBool(UnitExists, u, false) then return end

        local key = GetSafeUnitGUIDKey(u)
        if recordSeen then
            seenGUIDs[key] = true
        end

        if not SafeUnitBool(UnitIsConnected, u, true) then
            return
        end

        -- Guard UnitIsDeadOrGhost with SafeUnitBool (pcall + issecretvalue);
        -- Dead players or players with an unaccepted pending Battle Res remain "DEAD" until they accept and come back to life
        local isDead = SafeUnitBool(UnitIsDeadOrGhost, u, false)
        local wasDead = (self._groupLifeStateByGUID[key] == "DEAD")
        local nowState = isDead and "DEAD" or "ALIVE"
        self._groupLifeStateByGUID[key] = nowState

        if nowState == "DEAD" then
            -- Never count or flag a dead player (or pending unaccepted Brez) as missing the buff before they accept!
            self._combatNeedsRebuffQueue[key] = nil
            if cDef then
                SetCachedClassRaidBuffState(key, cDef, false, 0)
                if key ~= u then
                    SetCachedClassRaidBuffState(u, cDef, false, 0)
                end
            end
            if self._symbioticBondCache and self._symbioticBondCache.active then
                if self._symbioticBondCache.guid == key or self._symbioticBondCache.unit == u or u == "player" then
                    self:InvalidateSymbioticBond("UNIT_DIED")
                end
            end
        elseif wasDead and nowState == "ALIVE" and inCombat then
            -- Transitioned from Dead/Ghost -> Alive during combat (Battle Rez / Ankh accepted!)
            local colored, rawName, classFile = self:GetUnitClassColoredName(u, nil, nil)
            local existing = self._combatNeedsRebuffQueue[key]
            if not existing then
                existing = {}
                self._combatNeedsRebuffQueue[key] = existing
            end
            existing.unit = u
            existing.guid = key
            existing.name = rawName
            existing.classFile = classFile
            existing.coloredName = colored
            existing.rezTime = GetTime and GetTime() or 0
            if cDef then
                SetCachedClassRaidBuffState(key, cDef, false, 0)
                if key ~= u then
                    SetCachedClassRaidBuffState(u, cDef, false, 0)
                end
            end
        elseif self._combatNeedsRebuffQueue[key] then
            self._combatNeedsRebuffQueue[key].unit = u
        end
    end

    -- If a specific valid group unit triggered a health/flag/aura event, only evaluate that unit in O(1)
    if triggerUnit and (triggerEvent == "UNIT_HEALTH" or triggerEvent == "UNIT_FLAGS" or triggerEvent == "UNIT_AURA" or triggerEvent == "INCOMING_RESURRECT_CHANGED") then
        CheckUnitLifeTransition(triggerUnit, false)
        return
    end

    CheckUnitLifeTransition("player", true)
    if IsInRaid and IsInRaid() then
        local n = GetNumGroupMembers and GetNumGroupMembers() or 0
        for i = 1, n do
            CheckUnitLifeTransition("raid" .. i, true)
        end
    elseif IsInGroup and IsInGroup() then
        local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
        for i = 1, n do
            CheckUnitLifeTransition("party" .. i, true)
        end
    end

    for k in pairs(self._combatNeedsRebuffQueue) do
        if not seenGUIDs[k] then
            self._combatNeedsRebuffQueue[k] = nil
        end
    end
end

function DynamicPrep:ScanCombatRaidBuffStatus(expThresholdSec)
    local _, classFile = UnitClass("player")
    local cDef = classFile and CLASS_RAID_BUFFS[classFile]
    if not IsClassRaidBuffKnown(cDef) then
        self._lastCombatBuffSummary = nil
        return nil
    end

    self:UpdateGroupLifeStates("SCAN")

    local playerInstID = nil
    if UnitPosition then
        local okP, _, _, _, instID = pcall(UnitPosition, "player")
        if okP and not _IsSecret(instID) then playerInstID = instID end
    end

    local totalEligible = 0
    local missingUnits = _reusableMissingUnits
    local missingByKey = _reusableMissingByKey
    wipe(missingUnits)
    wipe(missingByKey)
    local poolIdx = 0
    local minRem = 99999

    local function PushMissingUnit(u, key, rawName, cf, colored, isBrez)
        poolIdx = poolIdx + 1
        local entry = _reusableCombatEntryPool[poolIdx]
        if not entry then
            entry = {}
            _reusableCombatEntryPool[poolIdx] = entry
        end
        entry.unit = u
        entry.guid = key
        entry.name = rawName
        entry.classFile = cf
        entry.coloredName = colored
        entry.isBrez = isBrez and true or false
        missingByKey[key] = entry
        missingUnits[#missingUnits + 1] = entry
    end

    local function InspectGroupMember(u)
        if not IsUnitEligibleForRaidBuff(u, playerInstID) then return end

        totalEligible = totalEligible + 1

        local key = GetSafeUnitGUIDKey(u)
        local queuedBrez = self._combatNeedsRebuffQueue[key]

        -- Try live aura read even during combat (wrapped in pcall + secret guards)
        local foundLive, rem, sawSecret, expTime = SafeHasAura(u, cDef.auraNames, cDef.auraIDs, nil, nil, true)
        local cacheKey = GetUnitAuraCacheKey(key, cDef.auraNames, cDef.auraIDs, nil)
        if not sawSecret then
            local cachedEntry = _unitAuraStateCache[cacheKey]
            if not cachedEntry then
                cachedEntry = {}
                _unitAuraStateCache[cacheKey] = cachedEntry
            end
            cachedEntry.hasBuff = foundLive and true or false
            cachedEntry.rem = rem or 0
            cachedEntry.expirationTime = expTime or 0
            if foundLive then
                -- Live aura verification confirms the buff is applied -> remove from Needs Rebuff queue!
                self._combatNeedsRebuffQueue[key] = nil
                if rem < minRem then minRem = rem end
            else
                local colored, rawName, cf = self:GetUnitClassColoredName(u, queuedBrez and queuedBrez.name, queuedBrez and queuedBrez.classFile)
                if not missingByKey[key] then
                    PushMissingUnit(u, key, rawName, cf, colored, queuedBrez ~= nil)
                end
            end
        else
            -- Combat aura restrictions blocked direct aura inspection on this unit:
            -- If this unit is in the Battle-Rez "Needs Rebuff" queue, keep them flagged until the raid buff is cast!
            if queuedBrez then
                local colored, rawName, cf = self:GetUnitClassColoredName(u, queuedBrez.name, queuedBrez.classFile)
                if not missingByKey[key] then
                    PushMissingUnit(u, key, rawName, cf, colored, true)
                end
            else
                -- Check pre-combat / death-invalidated cached aura state for group members
                local hasCached, cachedRem, isSecBlock = CheckUnitAuraState(u, cDef.auraNames, cDef.auraIDs, nil, expThresholdSec, nil, false)
                if not isSecBlock and not hasCached then
                    local colored, rawName, cf = self:GetUnitClassColoredName(u, nil, nil)
                    if not missingByKey[key] then
                        PushMissingUnit(u, key, rawName, cf, colored, false)
                    end
                elseif hasCached and cachedRem < minRem then
                    minRem = cachedRem
                end
            end
        end
    end

    InspectGroupMember("player")
    if IsInRaid and IsInRaid() then
        local n = GetNumGroupMembers and GetNumGroupMembers() or 0
        for i = 1, n do
            local u = "raid" .. i
            local okSame, isSame = pcall(UnitIsUnit, u, "player")
            if okSame and not _IsSecret(isSame) and not isSame then
                InspectGroupMember(u)
            end
        end
    elseif IsInGroup and IsInGroup() then
        local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
        for i = 1, n do
            InspectGroupMember("party" .. i)
        end
    end

    local missingCount = #missingUnits
    local activeCount = math.max(0, totalEligible - missingCount)
    local shortTag = cDef.shortLabel or cDef.name

    local coloredNamesList = _reusableColoredNames
    wipe(coloredNamesList)
    local hasBrezUnit = false
    for i = 1, math.min(#missingUnits, 3) do
        coloredNamesList[#coloredNamesList + 1] = missingUnits[i].coloredName
        if missingUnits[i].isBrez then hasBrezUnit = true end
    end
    local namesStr = (#coloredNamesList > 0) and table.concat(coloredNamesList, ", ") or ""
    if #missingUnits > 3 then
        namesStr = namesStr .. string.format(" +%d", #missingUnits - 3)
    end

    local alertText = nil
    if missingCount > 0 then
        alertText = string.format("%s: %d/%d MISSING (%s)", shortTag, activeCount, math.max(1, totalEligible), namesStr ~= "" and namesStr or "Group")
    end

    local summary = _reusableCombatSummary
    summary.cDef = cDef
    summary.shortLabel = shortTag
    summary.missingCount = missingCount
    summary.activeCount = activeCount
    summary.totalEligible = totalEligible
    summary.missingUnits = missingUnits
    summary.hasBrezUnit = hasBrezUnit
    summary.minRem = minRem
    summary.alertText = alertText
    summary.namesStr = namesStr
    self._lastCombatBuffSummary = summary
    return summary
end

function DynamicPrep:EnsureCombatReadinessStrip()
    -- Hide any deprecated standalone combat alert banner frame if present
    if _G.DynamicPrepCombatBuffAlertFrame and _G.DynamicPrepCombatBuffAlertFrame.Hide then
        _G.DynamicPrepCombatBuffAlertFrame:Hide()
    end
    if self.combatBuffAlertFrame and self.combatBuffAlertFrame.Hide then
        self.combatBuffAlertFrame:Hide()
    end
    if self.combatReadinessStrip then
        return self.combatReadinessStrip
    end

    -- Non-protected, click-through Readiness Tracker Strip override for In-Combat missing Class Raid Buffs (16/17 + MISSING).
    -- Anchored at the exact same position/scale/iconSize as DynamicPrepClickableBuffBar so showing/hiding dynamically mid-combat
    -- never calls Show()/Hide() on protected SecureActionButtonTemplate frames and never intercepts combat mouse clicks.
    local strip = CreateFrame("Frame", "DynamicPrepCombatReadinessStrip", UIParent)
    strip:SetSize(60, 66)
    strip:SetFrameStrata("MEDIUM")
    strip:SetClampedToScreen(true)
    strip:EnableMouse(false)

    strip.hudBg = CreateFrame("Frame", nil, strip, "BackdropTemplate")
    strip.hudBg:SetAllPoints(strip)
    strip.hudBg:SetFrameLevel(math.max(1, strip:GetFrameLevel() - 1))
    strip.hudBg:EnableMouse(false)
    SetPixelBackdrop(strip.hudBg, { 0.035, 0.043, 0.059, 0.0 }, { 0, 0, 0, 0 }, 1)
    strip.hudBg:Hide()

    local slot = CreateFrame("Frame", nil, strip)
    slot:SetSize(44, 44)
    slot:SetPoint("CENTER", strip, "CENTER", 0, 4)
    slot:EnableMouse(false)

    slot.bgFrame = CreateFrame("Frame", nil, slot, "BackdropTemplate")
    slot.bgFrame:SetAllPoints(slot)
    slot.bgFrame:SetFrameLevel(math.max(1, slot:GetFrameLevel() - 1))
    slot.bgFrame:EnableMouse(false)
    local ar, ag, ab = GetActiveAccentRGB()
    SetPixelBackdrop(slot.bgFrame, COLORS.BgVoid, { ar, ag, ab, 0.90 }, 1)

    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, -2)
    slot.icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
    slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    slot.icon:SetTexture(136078)

    -- Top-Right Badge: Group coverage ratio (e.g. 16/17)
    slot.topBadge = CreateText(slot, "OVERLAY", "GameFontHighlightSmall", 11, "OUTLINE")
    slot.topBadge:SetPoint("TOPRIGHT", slot, "TOPRIGHT", -2, -2)
    slot.topBadge:SetJustifyH("RIGHT")

    -- Bottom Status Label: Dead-Center "MISSING"
    slot.statusLabel = CreateText(slot, "OVERLAY", "GameFontHighlightSmall", 9, "OUTLINE")
    slot.statusLabel:SetPoint("TOP", slot, "BOTTOM", 0, -3)
    slot.statusLabel:SetJustifyH("CENTER")
    slot.statusLabel:SetText("|cFFF87171MISSING|r")

    strip.slot = slot
    strip:Hide()
    self.combatReadinessStrip = strip
    return strip
end

function DynamicPrep:RefreshCombatBuffAlert()
    local strip = self.combatReadinessStrip or self:EnsureCombatReadinessStrip()
    if not strip then return end

    local rb = (self.db and self.db.raidBuffs) or DEFAULTS.raidBuffs
    local expThresholdSec = (tonumber(rb.expireThresholdMin) or 5) * 60
    local sum = self:ScanCombatRaidBuffStatus(expThresholdSec)

    -- Outside combat, DynamicPrepClickableBuffBar renders all readiness strip icons directly; keep the combat override hidden.
    if not IsPlayerInCombat() then
        strip:Hide()
        return
    end

    if not self:ShouldShowRaidBuffsForZone() or rb.trackClassBuffs == false or rb.trackCombatBrez == false then
        strip:Hide()
        return
    end

    if sum and sum.cDef and (sum.missingCount or 0) > 0 and (sum.activeCount or 0) < (sum.totalEligible or 0) then
        local iconSize = math.max(32, math.min(64, tonumber(rb.iconSize) or 44))
        local barW = iconSize + 16
        local barH = iconSize + 22
        local pt, rp, curX, curY = self:GetSavedBuffBarPosition()
        local ar, ag, ab = GetActiveAccentRGB()

        strip:SetSize(barW, barH)
        local hudScale = tonumber(rb.hudScale)
        if hudScale and hudScale > 0 then
            strip:SetScale(math.max(0.60, math.min(1.50, hudScale)))
        else
            strip:SetScale(1.0)
        end
        strip:ClearAllPoints()
        strip:SetPoint(pt or "CENTER", UIParent, rp or "CENTER", curX or 0, curY or 140)

        if strip.hudBg then
            if rb.showHudCapsule == true then
                SetPixelBackdrop(strip.hudBg, { 0.035, 0.043, 0.059, 0.78 }, { ar, ag, ab, 0.45 }, 1)
                strip.hudBg:Show()
            else
                strip.hudBg:Hide()
            end
        end

        local slot = strip.slot
        slot:SetSize(iconSize, iconSize)
        slot:ClearAllPoints()
        slot:SetPoint("CENTER", strip, "CENTER", 0, 4)
        SetPixelBackdrop(slot.bgFrame, COLORS.BgVoid, { ar, ag, ab, 0.90 }, 1)
        slot.icon:SetTexture(sum.cDef.icon or 136078)
        slot.topBadge:SetText(string.format("|cFFF87171%d/%d|r", sum.activeCount or 0, math.max(1, sum.totalEligible or 1)))
        slot.statusLabel:SetText("|cFFF87171MISSING|r")
        strip:Show()
    else
        strip:Hide()
    end
end

function DynamicPrep:ShouldShowRaidBuffsForZone()
    if self.inBuffsEditMode or (self.inEditMode and self.inBuffsEditMode ~= false) or (self.clickableBuffBar and self.clickableBuffBar._dsEditModeActive) or self.previewRaidBuffs then
        return true
    end
    if not self.db or not self.db.raidBuffs or not self.db.raidBuffs.enabled then
        return false
    end
    local scope = self.db.raidBuffs.scope or "ALWAYS"
    if scope == "ALWAYS" then
        return true
    end
    local inInst, instType = false, "none"
    if type(IsInInstance) == "function" then
        local okI, rIn, rType = pcall(IsInInstance)
        if okI then
            inInst = (not _IsSecret(rIn) and rIn == true) and true or false
            if not _IsSecret(rType) and type(rType) == "string" then
                instType = rType
            end
        end
    end
    local isPvEOrPvPInst = inInst and (instType == "party" or instType == "raid" or instType == "pvp" or instType == "arena" or (instType == "scenario" and IsActiveDelveInstance()))
    if scope == "INST_ONLY" then
        return isPvEOrPvPInst and true or false
    end
    -- "GROUP_OR_INST"
    return (isPvEOrPvPInst or (IsInGroup and IsInGroup())) and true or false
end

function DynamicPrep:GetSavedBuffBarPosition()
    local g = _G.DynamicSuiteDB and _G.DynamicSuiteDB.global
    local pos = g and g.hudPositions and g.hudPositions["prepBuffs"]
    local rb = (self.db and self.db.raidBuffs) or DEFAULTS.raidBuffs
    local pt = (pos and pos.point) or (rb and rb.point) or "CENTER"
    local rp = (pos and (pos.relativePoint or pos.relPoint)) or (rb and rb.relPoint) or "CENTER"
    local x  = (pos and pos.x ~= nil) and pos.x or ((rb and rb.x ~= nil) and rb.x or 0)
    local y  = (pos and pos.y ~= nil) and pos.y or ((rb and rb.y ~= nil) and rb.y or 140)
    return pt, rp, x, y
end

function DynamicPrep:SaveBuffBarEditPosition(point, relPoint, x, y)
    local pt = point or "CENTER"
    local rp = relPoint or pt
    local rawX = tonumber(x) or 0
    local rawY = tonumber(y) or 140
    local px, py = ClampPrepFrameToScreen(self.clickableBuffBar, pt, rp, rawX, rawY, 200, 56)
    if self.db and self.db.raidBuffs then
        self.db.raidBuffs.point = pt
        self.db.raidBuffs.relPoint = rp
        self.db.raidBuffs.x = px
        self.db.raidBuffs.y = py
    end
    _G.DynamicSuiteDB = _G.DynamicSuiteDB or {}
    _G.DynamicSuiteDB.global = _G.DynamicSuiteDB.global or {}
    _G.DynamicSuiteDB.global.hudPositions = _G.DynamicSuiteDB.global.hudPositions or {}
    _G.DynamicSuiteDB.global.hudPositions["prepBuffs"] = {
        point = pt,
        relativePoint = rp,
        relPoint = rp,
        x = px,
        y = py,
    }
end

function DynamicPrep:ResetBuffBarHUDPosition(silent)
    if InCombatLockdown and InCombatLockdown() then
        if not silent then
            print("|cFF38BDF8DynamicPrep|r: |cFFF87171Cannot reset protected Raid Buffs HUD during combat lockdown.|r Please wait until combat ends.")
        end
        return false
    end
    self:SaveBuffBarEditPosition("CENTER", "CENTER", 0, 140)
    if self.db and self.db.raidBuffs then
        self.db.raidBuffs.hudScale = 1.0
        self.db.raidBuffs.hudOpacity = 0.95
        self.db.raidBuffs.hudBorderStyle = "ACCENT"
        self.db.raidBuffs.orientation = "HORIZONTAL"
    end
    self:RefreshClickableBuffs(true)
    return true
end

function DynamicPrep:NudgeBuffBarHUD(dx, dy)
    if InCombatLockdown and InCombatLockdown() then return end
    local pt, rp, curX, curY = self:GetSavedBuffBarPosition()
    self:SaveBuffBarEditPosition(pt, rp, (curX or 0) + (tonumber(dx) or 0), (curY or 140) + (tonumber(dy) or 0))
    self:RefreshClickableBuffs(true)
end

function DynamicPrep:CreateClickableBuffBar()
    if self.clickableBuffBar then return self.clickableBuffBar end

    local bar = CreateFrame("Frame", "DynamicPrepClickableBuffBar", UIParent, "SecureHandlerStateTemplate")
    bar:SetSize(200, 56)
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)

    local pt, rp, initX, initY = self:GetSavedBuffBarPosition()
    self:SaveBuffBarEditPosition(pt, rp, initX, initY)
    bar:SetPoint(pt, UIParent, rp, initX, initY)

    -- Subtle HUD Container Backdrop (can be toggled or shown in Edit Mode)
    bar.hudBg = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    bar.hudBg:SetAllPoints(bar)
    bar.hudBg:SetFrameLevel(math.max(1, bar:GetFrameLevel() - 1))
    SetPixelBackdrop(bar.hudBg, { 0.035, 0.043, 0.059, 0.0 }, { 0, 0, 0, 0 }, 1)

    -- C++ Macro Visibility Driver: Hides in combat, Pet Battles, or Vehicle UI so satisfied buttons never swallow center-screen clicks mid-combat
    if RegisterStateDriver then
        pcall(RegisterStateDriver, bar, "visibility", "[petbattle][vehicleui][combat] hide; show")
    end

    bar.buttons = {}
    for i = 1, MAX_CRB_SLOTS do
        local btn = CreateFrame("Button", "DynamicPrepBuffBtn" .. i, bar, "SecureActionButtonTemplate")
        btn:SetSize(44, 44)
        btn:RegisterForClicks("AnyUp", "AnyDown")

        btn.bgFrame = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        btn.bgFrame:SetAllPoints(btn)
        btn.bgFrame:SetFrameLevel(math.max(1, btn:GetFrameLevel() - 1))
        SetPixelBackdrop(btn.bgFrame, COLORS.BgVoid, COLORS.BorderStrong, 1)

        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        -- Top-Left Badge (Quality badge for Flasks/Oils)
        local qb = btn:CreateTexture(nil, "OVERLAY", nil, 6)
        qb:SetSize(14, 14)
        qb:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        qb:Hide()
        btn.qualityBadge = qb

        -- Hearty Food Badge (Golden Heart / Shield Icon & Text)
        local hb = btn:CreateTexture(nil, "OVERLAY", nil, 6)
        hb:SetSize(14, 14)
        hb:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        hb:SetTexture("Interface\\Icons\\Spell_Holy_GreaterBlessingofSanctuary")
        hb:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        hb:Hide()
        btn.heartyBadge = hb

        local htxt = CreateText(btn, "OVERLAY", "GameFontHighlightSmall", 9, "OUTLINE")
        htxt:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        htxt:SetTextColor(1.0, 0.85, 0.15, 1.0)
        htxt:SetText("[H]")
        htxt:Hide()
        btn.heartyText = htxt

        -- Top-Right Badge (Missing group ratio e.g. 2/5 or Expiring minutes e.g. 4m)
        btn.topBadge = CreateText(btn, "OVERLAY", "GameFontHighlightSmall", 11, "OUTLINE")
        btn.topBadge:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -2)
        btn.topBadge:SetJustifyH("RIGHT")

        -- Bottom-Right Badge (Bag item stack count)
        btn.stackBadge = CreateText(btn, "OVERLAY", "GameFontHighlightSmall", 11, "OUTLINE")
        btn.stackBadge:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
        btn.stackBadge:SetJustifyH("RIGHT")

        -- Bottom Status Label ("MISSING" / "EXPIRING" / "NO FOOD") - Dead-Center Aligned
        btn.statusLabel = CreateText(btn, "OVERLAY", "GameFontHighlightSmall", 9, "OUTLINE")
        btn.statusLabel:SetPoint("TOP", btn, "BOTTOM", 0, -3)
        btn.statusLabel:SetJustifyH("CENTER")

        btn:SetScript("OnEnter", function(selfBtn)
            if DynamicPrep.inEditMode or (selfBtn:GetAlpha() or 1) <= 0.01 then return end
            local ar, ag, ab = GetActiveAccentRGB()
            SetPixelBackdrop(selfBtn.bgFrame or selfBtn, COLORS.BgElevated, { ar, ag, ab, 1.0 }, 1)
            if GameTooltip and selfBtn._tooltipTitle and selfBtn._tooltipTitle ~= "" then
                GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
                GameTooltip:AddLine(selfBtn._tooltipTitle, ar, ag, ab)
                if selfBtn._tooltipSub and selfBtn._tooltipSub ~= "" then
                    GameTooltip:AddLine(selfBtn._tooltipSub, 0.85, 0.90, 0.96, true)
                end
                if selfBtn._actionType == "macro" then
                    if type(selfBtn._actionTarget) == "string" and selfBtn._actionTarget:find("^PARTNER_BUFF:") then
                        GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F01-Click Cast on Smart Target|r", 1, 1, 1)
                        GameTooltip:AddLine("|cFF38BDF8Mouseover / Target:|r |cFFE2E8F0Overrides Smart Target|r", 1, 1, 1)
                    else
                        GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F01-Click Auto-Apply to Main Hand|r", 1, 1, 1)
                        GameTooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Apply to Off Hand|r", 1, 1, 1)
                    end
                else
                    GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Cast / Use Now|r", 1, 1, 1)
                end
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function(selfBtn)
            if GameTooltip then GameTooltip:Hide() end
            local ar, ag, ab = GetActiveAccentRGB()
            local rbCfg = DynamicPrep.db and DynamicPrep.db.raidBuffs
            local bStyle = (rbCfg and rbCfg.hudBorderStyle) or (DynamicPrep.db and DynamicPrep.db.hudBorderStyle) or "ACCENT"
            local bRGBA
            if bStyle == "NONE" then
                bRGBA = { 0, 0, 0, 0 }
            elseif bStyle == "DARK" or bStyle == "SUBTLE" then
                bRGBA = COLORS.BorderStrong
            else
                bRGBA = { ar, ag, ab, 0.90 }
            end
            if selfBtn._isExpiring then
                SetPixelBackdrop(selfBtn.bgFrame or selfBtn, COLORS.BgVoid, COLORS.Gold, 1)
            else
                SetPixelBackdrop(selfBtn.bgFrame or selfBtn, COLORS.BgVoid, bRGBA, 1)
            end
        end)

        btn:Hide()
        bar.buttons[i] = btn
    end

    -- Unified HUD Edit Mode Drag Shield (matches DynamicPrepBarFrame.mover & Suite HUD Edit Mode)
    local mover = CreateFrame("Button", nil, bar, "BackdropTemplate")
    mover:SetAllPoints(bar)
    mover:SetFrameLevel(bar:GetFrameLevel() + 30)
    if mover.SetIgnoreParentAlpha then mover:SetIgnoreParentAlpha(true) end
    local ar, ag, ab, hex = GetActiveAccentRGB()
    SetPixelBackdrop(mover, { 0.05, 0.06, 0.09, 0.86 }, { ar, ag, ab, 1.0 }, 1)
    mover.dimBg = mover:CreateTexture(nil, "BACKGROUND")
    mover.dimBg:SetAllPoints(mover)
    mover.dimBg:SetColorTexture(0.05, 0.06, 0.09, 0.86)
    mover.label = CreateText(mover, "OVERLAY", "GameFontHighlightSmall")
    mover.label:SetPoint("CENTER")
    mover.label:SetJustifyH("CENTER")
    mover.label:SetText(string.format("|cFF%sClickable Raid Buffs HUD|r\n|cFFFFFFFF(X: %d, Y: %d)  [Right-Click: Center X=0]|r", hex, math.floor((initX or 0) + 0.5), math.floor((initY or 140) + 0.5)))
    mover:EnableMouse(true)
    mover:RegisterForClicks("AnyUp")
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnClick", function(_, button)
        if button == "RightButton" and not InCombatLockdown() then
            -- Right-click in HUD Edit Mode snaps X to 0 (Dead-Center Horizontal Alignment!)
            local curPt, curRp, _, curY = DynamicPrep:GetSavedBuffBarPosition()
            DynamicPrep:SaveBuffBarEditPosition("CENTER", "CENTER", 0, curY or 140)
            DynamicPrep:RefreshClickableBuffs(true)
            DynamicPrep:RefreshWorkspaceView()
        end
    end)
    mover:SetScript("OnDragStart", function(selfMover)
        if InCombatLockdown() then return end
        GameTooltip:Hide()
        bar:StartMoving()
        selfMover:SetScript("OnUpdate", function()
            local fScale = (bar.GetEffectiveScale and bar:GetEffectiveScale()) or 1
            local uScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
            local relScale = (fScale > 0 and uScale > 0) and (fScale / uScale) or 1
            local cx, cy = bar:GetCenter()
            local ux, uy = UIParent:GetCenter()
            local relX = (cx and ux) and (((cx * relScale) - ux) / relScale) or 0
            local relY = (cy and uy) and (((cy * relScale) - uy) / relScale) or 140
            local _, _, _, h = GetActiveAccentRGB()
            selfMover.label:SetText(string.format("|cFF%sClickable Raid Buffs HUD|r\n|cFFFFFFFF(X: %d, Y: %d)  [Right-Click: Center X=0]|r", h, math.floor(relX + 0.5), math.floor(relY + 0.5)))
        end)
    end)
    mover:SetScript("OnDragStop", function(selfMover)
        selfMover:SetScript("OnUpdate", nil)
        bar:StopMovingOrSizing()
        -- Always compute true CENTER-relative coordinates in frame local scale so icons expand symmetrically around the chosen center point!
        local fScale = (bar.GetEffectiveScale and bar:GetEffectiveScale()) or 1
        local uScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local relScale = (fScale > 0 and uScale > 0) and (fScale / uScale) or 1
        local cx, cy = bar:GetCenter()
        local ux, uy = UIParent:GetCenter()
        local x = (cx and ux) and (((cx * relScale) - ux) / relScale) or 0
        local y = (cy and uy) and (((cy * relScale) - uy) / relScale) or 140
        if not IsShiftKeyDown() and not IsControlKeyDown() then
            x = math.floor((x / 8) + 0.5) * 8
            y = math.floor((y / 8) + 0.5) * 8
        else
            x = math.floor(x + 0.5)
            y = math.floor(y + 0.5)
        end
        x, y = ClampPrepFrameToScreen(bar, "CENTER", "CENTER", x, y, bar:GetWidth() or 200, bar:GetHeight() or 56)
        if not InCombatLockdown() then
            bar:ClearAllPoints()
            bar:SetPoint("CENTER", UIParent, "CENTER", x, y)
        end
        bar:SaveEditPosition("CENTER", "CENTER", x, y)
        local _, _, _, h = GetActiveAccentRGB()
        selfMover.label:SetText(string.format("|cFF%sClickable Raid Buffs HUD|r\n|cFFFFFFFF(X: %d, Y: %d)  [Right-Click: Center X=0]|r", h, x, y))
        DynamicPrep:RefreshWorkspaceView()
    end)
    mover:Hide()
    bar.mover = mover
    bar.editDragShield = mover

    function bar:SaveEditPosition(point, relPoint, x, y)
        DynamicPrep:SaveBuffBarEditPosition(point, relPoint, x, y)
    end

    function bar:SetEditMode(state)
        DynamicPrep:SetBuffsEditMode(state)
    end

    bar.NudgeHUD = function(_, dx, dy) DynamicPrep:NudgeBuffBarHUD(dx, dy) end
    bar.ResetHUDPosition = function() DynamicPrep:ResetBuffBarHUDPosition() end

    self.clickableBuffBar = bar
    _G.DynamicPrepClickableBuffBar = bar

    -- Register as a first-class HUD element in _G.DynamicSuite so Suite HUD Edit Mode manages it alongside Top Info Bar
    _G.DynamicSuite = _G.DynamicSuite or {}
    _G.DynamicSuite.hudFrames = _G.DynamicSuite.hudFrames or {}
    _G.DynamicSuite.hudFrames["prepBuffs"] = bar

    return bar
end
DynamicPrep.InitClickableBuffBar = DynamicPrep.CreateClickableBuffBar

local _staticRuneMatchNames = {
    ["Augmentation"] = true,
    ["Crystallized Augmentation"] = true,
    ["Ethereal Augmentation"] = true,
    ["Soulsplit Augmentation"] = true,
    ["Radiant Augmentation"] = true,
    ["Silvermoon Augmentation"] = true,
    ["Voidbound Augmentation"] = true,
    ["Draconic Augmentation"] = true,
    ["Dreambound Augmentation"] = true,
    ["Eternal Augmentation"] = true,
    ["Battle-Scarred Augmentation"] = true,
    ["Lightforged Augmentation"] = true,
    ["Defiled Augmentation"] = true,
    ["Augmented"] = true,
}
local _staticRuneMatchIDs = {
    [393438] = true,
    [453250] = true,
    [367405] = true,
    [347901] = true,
    [270058] = true,
    [224001] = true,
    [175457] = true,
    [175456] = true,
    [175439] = true,
}
local _staticRuneMatchIcons = {
    [5764478] = true, -- Crystallized Augment Rune iconFileID
}
local _staticFlaskMatchNames = {}
local _staticFlaskMatchIDs = {}
local _staticFlaskMatchIcons = {}

local function AddRuneItemSignatures(id, ic, nm)
    if ic and not _IsSecret(ic) and type(ic) == "number" and ic ~= 134400 then
        _staticRuneMatchIcons[ic] = true
    end
    if nm and not _IsSecret(nm) and type(nm) == "string" and nm ~= "" then
        _staticRuneMatchNames[nm] = true
    end
    if id and C_Item then
        if C_Item.GetItemIconByID then
            local okIc, itemIc = pcall(C_Item.GetItemIconByID, id)
            if okIc and itemIc and not _IsSecret(itemIc) and type(itemIc) == "number" and itemIc ~= 134400 then
                _staticRuneMatchIcons[itemIc] = true
            end
        end
        if C_Item.GetItemSpell then
            local okSp, spName, spID = pcall(C_Item.GetItemSpell, id)
            if okSp then
                if spName and not _IsSecret(spName) and type(spName) == "string" and spName ~= "" then
                    _staticRuneMatchNames[spName] = true
                end
                if spID and not _IsSecret(spID) and type(spID) == "number" then
                    _staticRuneMatchIDs[spID] = true
                    if C_Spell and C_Spell.GetSpellTexture then
                        local okTex, spTex = pcall(C_Spell.GetSpellTexture, spID)
                        if okTex and spTex and not _IsSecret(spTex) and type(spTex) == "number" and spTex ~= 134400 then
                            _staticRuneMatchIcons[spTex] = true
                        end
                    end
                end
            end
        end
    end
end

function DynamicPrep:ScanAndPopulateRaidBuffQueue()
    for i = 1, MAX_CRB_SLOTS do _crbQueue[i].active = false end
    if not self:ShouldShowRaidBuffsForZone() then return 0 end

    local rb = self.db.raidBuffs
    local expThresholdSec = (tonumber(rb.expireThresholdMin) or 5) * 60
    local qCount = 0

    local function PushEntry(actionType, actionTarget, unit, icon, topTxt, botTxt, stackTxt, isExp, tTitle, tSub, macroTxt, isHearty, qual, maxT, qAtlas)
        if qCount >= MAX_CRB_SLOTS then return end
        qCount = qCount + 1
        local slot = _crbQueue[qCount]
        slot.active = true
        slot.actionType = actionType
        slot.actionTarget = actionTarget
        slot.macroText = macroTxt
        slot.unit = unit
        slot.icon = icon or 134400
        slot.topText = topTxt or ""
        slot.bottomText = botTxt or "|cFFF87171MISSING|r"
        slot.stackText = stackTxt or ""
        slot.isExpiring = isExp and true or false
        slot.tooltipTitle = tTitle or "Raid Buff"
        slot.tooltipSub = tSub or ""
        slot.isHearty = isHearty and true or false
        slot.quality = qual
        slot.maxTiers = maxT
        slot.qualityAtlas = qAtlas
    end

    -- Preview / Test Mode (or HUD Edit Mode when no live buffs are currently missing)
    if self.previewRaidBuffs then
        local _, classFile = UnitClass("player")
        local cDef = (classFile and CLASS_RAID_BUFFS[classFile]) or CLASS_RAID_BUFFS.DRUID
        PushEntry("spell", cDef.name, "player", cDef.icon, "|cFFF871714/5|r", "|cFFF87171MISSING|r", "", false, cDef.name .. " (Preview)", "Click to cast " .. cDef.name)
        PushEntry("item", "item:212283", nil, 463543, "|cFFFBBF244m|r", "|cFFFBBF24EXPIRING|r", "8", true, "Flask of Alchemical Chaos [Rank 2 Gold] (Preview)", "Click to refresh Flask before key starts.", nil, false, 2, 2, "Professions-Icon-Quality-Tier3-Small")
        PushEntry("macro", nil, nil, 463546, "", "|cFFF87171OIL|r", "12", false, "Algari Mana Oil [Rank 2 Gold] (Preview)", "1-Click Auto-Apply: Left-Click applies to Main-Hand (slot 16); Right-Click applies to Off-Hand (slot 17).", "/use 16", false, 2, 2, "Professions-Icon-Quality-Tier3-Small")
        PushEntry("item", "item:222746", nil, 134019, "", "|cFFFFD100HEARTY|r", "5", false, "Hearty Feast of the Midnight Masquerade [Hearty] (Preview)", "Hearty Well Fed persists through death in M+ and raids. Click to eat.", nil, true, nil, nil, nil)
        PushEntry("item", "item:224572", nil, 5764478, "", "|cFFF87171RUNE|r", "18", false, "Crystallized Augment Rune (Preview)", "Click to activate your Augment Rune.", nil, false, nil, nil, nil)
        return qCount
    end

    -- 1. Class Raid Buff Check (Mark of the Wild, Fortitude, Intellect, Battle Shout, Bronze, Skyfury)
    local inCombatNow = IsPlayerInCombat()
    if rb.trackClassBuffs ~= false then
        local _, classFile = UnitClass("player")
        local cDef = classFile and CLASS_RAID_BUFFS[classFile]
        if cDef and IsClassRaidBuffKnown(cDef) then
            local combatSum = self:ScanCombatRaidBuffStatus(expThresholdSec)
            local missingCount = (combatSum and combatSum.missingCount) or 0
            local totalEligible = (combatSum and combatSum.totalEligible) or 0
            local activeCount = (combatSum and combatSum.activeCount) or 0
            local minRem = (combatSum and combatSum.minRem) or 99999

            if missingCount > 0 then
                local badge = string.format("|cFFF87171%d/%d|r", activeCount, math.max(1, totalEligible))
                local missingLine = (combatSum and combatSum.alertText) and (combatSum.alertText .. "\n") or ""
                PushEntry(
                    "spell",
                    cDef.name,
                    "player",
                    cDef.icon,
                    badge,
                    "|cFFF87171MISSING|r",
                    "",
                    false,
                    cDef.name,
                    string.format("%s%d/%d eligible living group members buffed (%d missing %s).", missingLine, activeCount, totalEligible, missingCount, cDef.name)
                )
            elseif not inCombatNow and minRem > 0 and minRem <= expThresholdSec then
                local mins = math.max(1, math.ceil(minRem / 60))
                PushEntry("spell", cDef.name, "player", cDef.icon, string.format("|cFFFBBF24%dm|r", mins), "|cFFFBBF24EXPIRING|r", "", true, cDef.name, string.format("%s expires in %d min.", cDef.name, mins))
            end
        end

        -- Non-combat-castable or personal prep items (Partner Buffs, Weapon Oils, Flasks, Food, Augment Runes)
        -- MUST remain suppressed/hidden during combat so they never clutter the screen mid-pull.
        if inCombatNow then
            return qCount
        end

        -- 1b. Single-Target Friendly Partner Buffs (Symbiotic Relationship, Source of Magic, Blistering Scales, Earth Shield, Beacons)
        local pList = classFile and PARTNER_RAID_BUFFS[classFile]
        if pList and rb.trackPartnerBuffs ~= false then
            local IsKnownPartnerSpell = SafeIsPlayerSpellKnown

            local function IsUnitEligiblePartner(u)
                return IsUnitEligibleForRaidBuff(u, nil)
            end

            local function GetSafeUnitRole(u)
                if not UnitGroupRolesAssigned then return "NONE" end
                local ok, role = pcall(UnitGroupRolesAssigned, u)
                if ok and type(role) == "string" and not _IsSecret(role) then
                    return role
                end
                return "NONE"
            end

            local function GetSafeUnitLabel(u)
                if u == "player" then return "You" end
                if UnitName then
                    local ok, n = pcall(UnitName, u)
                    if ok and type(n) == "string" and not _IsSecret(n) and n ~= "" then
                        return n
                    end
                end
                return u:upper()
            end

            local function IsSameUnitSafe(u1, u2)
                if not u1 or not u2 then return false end
                if u1 == u2 then return true end
                if UnitIsUnit then
                    local ok, same = pcall(UnitIsUnit, u1, u2)
                    if ok and not _IsSecret(same) then
                        return same and true or false
                    end
                end
                return false
            end

            local inGroup = ((IsInRaid and IsInRaid()) or (IsInGroup and IsInGroup())) and true or false
            local alliedUnits = {}
            if IsInRaid and IsInRaid() then
                local n = GetNumGroupMembers and GetNumGroupMembers() or 0
                for i = 1, n do
                    local u = "raid" .. i
                    if not IsSameUnitSafe(u, "player") and IsUnitEligiblePartner(u) then
                        alliedUnits[#alliedUnits + 1] = u
                    end
                end
            elseif IsInGroup and IsInGroup() then
                local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
                for i = 1, n do
                    local u = "party" .. i
                    if IsUnitEligiblePartner(u) then
                        alliedUnits[#alliedUnits + 1] = u
                    end
                end
            end

            local playerRole = GetSafeUnitRole("player")
            local assignedBeaconTargetUnit = nil

            for _, pDef in ipairs(pList) do
                local known = IsKnownPartnerSpell(pDef.spellID)
                if known and pDef.excludeIfTalentKnown and IsKnownPartnerSpell(pDef.excludeIfTalentKnown) then
                    known = false
                end
                if known and (not pDef.requiresGroup or inGroup) then
                    local hasPartnerBuff = false
                    local activeUnit = nil
                    local activeRem = 99999
                    local bondedColoredLabel = nil

                    if pDef.spellID == 474750 then
                        -- Specialized Symbiotic Relationship Linked-Target Detector (474750 / 474754 / 474753 + localized spell name + sourceUnit=="player" + cast cache)
                        local isBonded, bUnit, bColored, bRem = self:ValidateAndScanSymbioticBond(expThresholdSec)
                        if isBonded then
                            hasPartnerBuff = true
                            activeUnit = bUnit
                            activeRem = bRem or 99999
                            bondedColoredLabel = bColored
                        end
                    else
                        -- Shaman Elemental Orbit (383010) allows personal Earth Shield (383648) plus an ally Earth Shield (974)
                        local checkAuraIDs = pDef.auraIDs
                        if pDef.spellID == 974 and inGroup and IsKnownPartnerSpell(383010) then
                            checkAuraIDs = _staticEarthShieldIDs
                        end

                        -- 1. Check allied group units first
                        for _, u in ipairs(alliedUnits) do
                            local hasB, rem, isSec = CheckUnitAuraState(u, pDef.auraNames, checkAuraIDs, pDef.name, expThresholdSec)
                            if not isSec and hasB then
                                hasPartnerBuff = true
                                activeUnit = u
                                if rem < activeRem then activeRem = rem end
                                break
                            end
                        end

                        -- 2. Check player if checkSelfAuraToo is true, or solo when not requiresGroup, or player is a Tank for Tank-targeted buffs
                        if not hasPartnerBuff then
                            local checkSelf = (pDef.checkSelfAuraToo == true) or (not inGroup and not pDef.requiresGroup) or (pDef.targetRole == "TANK" and playerRole == "TANK" and (pDef.spellID ~= 974 or not IsKnownPartnerSpell(383010)))
                            if checkSelf then
                                local hasB, rem, isSec = CheckUnitAuraState("player", pDef.auraNames, checkAuraIDs, pDef.name, expThresholdSec)
                                if not isSec and hasB then
                                    hasPartnerBuff = true
                                    activeUnit = "player"
                                    if rem < activeRem then activeRem = rem end
                                end
                            end
                        end
                    end

                    if pDef.spellID == 53563 and activeUnit then
                        assignedBeaconTargetUnit = activeUnit
                    end

                    local isExpiring = hasPartnerBuff and activeRem > 0 and activeRem <= expThresholdSec
                    if not hasPartnerBuff or isExpiring then
                        local resolvedUnit = activeUnit
                        local resolvedBadge = "PARTNER"

                        if not resolvedUnit then
                            if pDef.targetRole == "TANK" then
                                resolvedBadge = "TANK"
                                for _, u in ipairs(alliedUnits) do
                                    if GetSafeUnitRole(u) == "TANK" then
                                        resolvedUnit = u
                                        break
                                    end
                                end
                                if not resolvedUnit and playerRole == "TANK" then
                                    resolvedUnit = "player"
                                    resolvedBadge = "SELF"
                                end
                                if not resolvedUnit and #alliedUnits > 0 then
                                    resolvedUnit = alliedUnits[1]
                                    resolvedBadge = "ALLY"
                                end
                                if not resolvedUnit and not pDef.requiresGroup then
                                    resolvedUnit = "player"
                                    resolvedBadge = "SELF"
                                end
                            elseif pDef.targetRole == "OFF_TANK" then
                                resolvedBadge = "TANK 2"
                                for _, u in ipairs(alliedUnits) do
                                    if GetSafeUnitRole(u) == "TANK" and not IsSameUnitSafe(u, assignedBeaconTargetUnit) then
                                        local hasB1 = CheckUnitAuraState(u, _staticBeaconNames, _staticBeaconIDs, "Beacon of Light", expThresholdSec)
                                        if not hasB1 then
                                            resolvedUnit = u
                                            break
                                        end
                                    end
                                end
                                if not resolvedUnit then
                                    for _, u in ipairs(alliedUnits) do
                                        if GetSafeUnitRole(u) == "HEALER" and not IsSameUnitSafe(u, assignedBeaconTargetUnit) then
                                            resolvedUnit = u
                                            resolvedBadge = "HEAL"
                                            break
                                        end
                                    end
                                end
                                if not resolvedUnit and not IsSameUnitSafe("player", assignedBeaconTargetUnit) then
                                    resolvedUnit = "player"
                                    resolvedBadge = "SELF"
                                end
                                if not resolvedUnit then
                                    for _, u in ipairs(alliedUnits) do
                                        if not IsSameUnitSafe(u, assignedBeaconTargetUnit) then
                                            resolvedUnit = u
                                            resolvedBadge = "ALLY"
                                            break
                                        end
                                    end
                                end
                            elseif pDef.targetRole == "HEALER" then
                                resolvedBadge = "HEAL"
                                for _, u in ipairs(alliedUnits) do
                                    if GetSafeUnitRole(u) == "HEALER" then
                                        resolvedUnit = u
                                        break
                                    end
                                end
                            elseif pDef.targetRole == "TANK_OR_HEALER" then
                                local preferredRole = (playerRole == "TANK") and "HEALER" or "TANK"
                                local fallbackRole = (preferredRole == "TANK") and "HEALER" or "TANK"
                                for _, u in ipairs(alliedUnits) do
                                    if GetSafeUnitRole(u) == preferredRole then
                                        resolvedUnit = u
                                        resolvedBadge = (preferredRole == "TANK") and "TANK" or "HEAL"
                                        break
                                    end
                                end
                                if not resolvedUnit then
                                    for _, u in ipairs(alliedUnits) do
                                        if GetSafeUnitRole(u) == fallbackRole then
                                            resolvedUnit = u
                                            resolvedBadge = (fallbackRole == "TANK") and "TANK" or "HEAL"
                                            break
                                        end
                                    end
                                end
                                if not resolvedUnit and #alliedUnits > 0 then
                                    resolvedUnit = alliedUnits[1]
                                    resolvedBadge = "ALLY"
                                end
                            end
                        else
                            local r = GetSafeUnitRole(resolvedUnit)
                            if resolvedUnit == "player" then
                                resolvedBadge = "SELF"
                            elseif r == "TANK" then
                                resolvedBadge = "TANK"
                            elseif r == "HEALER" then
                                resolvedBadge = "HEAL"
                            else
                                resolvedBadge = "ALLY"
                            end
                        end

                        if resolvedUnit then
                            if pDef.spellID == 53563 and not assignedBeaconTargetUnit then
                                assignedBeaconTargetUnit = resolvedUnit
                            end
                            local spellIcon = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(pDef.spellID)) or pDef.icon
                            local coloredTarget = bondedColoredLabel or self:GetUnitClassColoredName(resolvedUnit, GetSafeUnitLabel(resolvedUnit), nil)
                            local macroTxt = string.format("/cast [@mouseover,help,nodead][@target,help,nodead][@%s,help,nodead][] %s", resolvedUnit, pDef.name)
                            if isExpiring then
                                local mins = math.max(1, math.ceil(activeRem / 60))
                                PushEntry(
                                    "macro",
                                    "PARTNER_BUFF:" .. pDef.name,
                                    resolvedUnit,
                                    spellIcon,
                                    string.format("|cFFFBBF24%dm|r", mins),
                                    "|cFFFBBF24" .. resolvedBadge .. "|r",
                                    "",
                                    true,
                                    pDef.name,
                                    string.format("Linked: %s (%s) - expires in %d min.\nSmart Target: %s (%s)", coloredTarget, resolvedBadge, mins, coloredTarget, resolvedUnit),
                                    macroTxt
                                )
                            else
                                PushEntry(
                                    "macro",
                                    "PARTNER_BUFF:" .. pDef.name,
                                    resolvedUnit,
                                    spellIcon,
                                    "|cFF38BDF8" .. resolvedBadge .. "|r",
                                    "|cFFF87171MISSING|r",
                                    "",
                                    false,
                                    pDef.name,
                                    string.format("%s is missing on your group partner.\nSmart Target: %s (%s - %s)", pDef.name, coloredTarget, resolvedBadge, resolvedUnit),
                                    macroTxt
                                )
                            end
                        end
                    end
                end
            end
        end
    end

    if inCombatNow then
        return qCount
    end

    -- 2. Weapon Enchant / Oil / Whetstone Check (1-Click Auto-Apply to Weapon)
    if rb.trackWeaponEnchants ~= false and GetWeaponEnchantInfo then
        local mhItemID = GetInventoryItemID and GetInventoryItemID("player", 16)
        if mhItemID then
            local hasMH, mhExp, _, _, hasOH, ohExp = GetWeaponEnchantInfo()
            local mhRemSec = (hasMH and mhExp and not _IsSecret(mhExp)) and (mhExp / 1000) or 0
            local ohRemSec = (hasOH and ohExp and not _IsSecret(ohExp)) and (ohExp / 1000) or 0

            local ohItemID = GetInventoryItemID and GetInventoryItemID("player", 17)
            local ohIsEnchantableWeapon = false
            if ohItemID and C_Item and C_Item.GetItemInfoInstant then
                local _, _, _, ohInvType, _, ohClassID = C_Item.GetItemInfoInstant(ohItemID)
                if ohClassID == 2 and ohInvType ~= "INVTYPE_SHIELD" and ohInvType ~= "INVTYPE_HOLDABLE" then
                    ohIsEnchantableWeapon = true
                end
            end

            local mhExpiring = hasMH and mhRemSec > 0 and mhRemSec <= expThresholdSec
            local ohExpiring = ohIsEnchantableWeapon and hasOH and ohRemSec > 0 and ohRemSec <= expThresholdSec
            local isMissing = (not hasMH) or (ohIsEnchantableWeapon and not hasOH)
            local isExp = (not isMissing) and (mhExpiring or ohExpiring) and true or false

            if isMissing or isExp then
                local oilID, oilCnt, oilIcon, oilName, oilQual, oilMaxT, oilAtlas = ScanOwnedWeaponOil()
                if oilID and oilCnt > 0 then
                    local minRem = 0
                    if mhExpiring and ohExpiring then
                        minRem = math.min(mhRemSec, ohRemSec)
                    elseif mhExpiring then
                        minRem = mhRemSec
                    elseif ohExpiring then
                        minRem = ohRemSec
                    end
                    local topTxt = isExp and string.format("|cFFFBBF24%dm|r", math.max(1, math.ceil(minRem / 60))) or ""
                    local botTxt = isExp and "|cFFFBBF24EXPIRING|r" or "|cFFF87171OIL|r"
                    local targetSlot = 16
                    if hasMH and not mhExpiring and ((ohIsEnchantableWeapon and not hasOH) or ohExpiring) then
                        targetSlot = 17
                    end
                    local targetAlreadyEnchanted = (targetSlot == 17 and hasOH) or (targetSlot == 16 and hasMH)
                    local macro
                    if targetAlreadyEnchanted then
                        macro = string.format("/use item:%d\n/use [button:2] 17; %d\n/click StaticPopup1Button1", oilID, targetSlot)
                    else
                        macro = string.format("/use item:%d\n/use [button:2] 17; %d", oilID, targetSlot)
                    end
                    local sub = "1-Click Auto-Apply: Left-Click applies to Main-Hand (slot 16); Right-Click applies to Off-Hand (slot 17)."
                    PushEntry("macro", nil, nil, oilIcon, topTxt, botTxt, tostring(oilCnt), isExp, oilName or "Weapon Oil", sub, macro, false, oilQual, oilMaxT, oilAtlas)
                end
            end
        end
    end

    -- 3. Flask / Phial Check (All available quality tiers and ranks in bags)
    if rb.trackFlasks ~= false then
        local flasks = ScanOwnedFlasks()
        wipe(_staticFlaskMatchNames)
        wipe(_staticFlaskMatchIDs)
        wipe(_staticFlaskMatchIcons)
        if flasks then
            for i = 1, #flasks do
                local f = flasks[i]
                if f.icon and type(f.icon) == "number" and f.icon ~= 134400 then
                    _staticFlaskMatchIcons[f.icon] = true
                end
                if f.itemID and C_Item and C_Item.GetItemSpell then
                    local okSp, spName, spID = pcall(C_Item.GetItemSpell, f.itemID)
                    if okSp then
                        if spName and not _IsSecret(spName) and type(spName) == "string" then
                            _staticFlaskMatchNames[spName] = true
                        end
                        if spID and not _IsSecret(spID) and type(spID) == "number" then
                            _staticFlaskMatchIDs[spID] = true
                        end
                    end
                end
            end
        end
        local hasFlask, flaskRem = CheckUnitAuraState("player", _staticFlaskMatchNames, _staticFlaskMatchIDs, "Flask", expThresholdSec, _staticFlaskMatchIcons)
        if not hasFlask then
            hasFlask, flaskRem = CheckUnitAuraState("player", _staticFlaskMatchNames, _staticFlaskMatchIDs, "Phial", expThresholdSec, _staticFlaskMatchIcons)
        end
        if not hasFlask or (flaskRem > 0 and flaskRem <= expThresholdSec) then
            for fIdx = 1, math.min(#flasks, 8) do
                if qCount >= (MAX_CRB_SLOTS - 5) then break end
                local f = flasks[fIdx]
                local isExp = hasFlask and true or false
                local topTxt = isExp and string.format("|cFFFBBF24%dm|r", math.max(1, math.ceil(flaskRem / 60))) or ""
                local botTxt
                if isExp then
                    botTxt = "|cFFFBBF24EXPIRING|r"
                elseif f.isFleeting then
                    botTxt = "|cFF38BDF8FLEETING|r"
                else
                    botTxt = "|cFFF87171FLASK|r"
                end

                local rankLabel = ""
                if f.maxTiers == 2 then
                    rankLabel = (f.quality and f.quality >= 2) and " [Rank 2 Gold]" or ((f.quality == 1) and " [Rank 1 Silver]" or "")
                elseif f.maxTiers == 3 then
                    rankLabel = (f.quality and f.quality >= 3) and " [Rank 3 Gold]" or ((f.quality == 2) and " [Rank 2 Silver]" or ((f.quality == 1) and " [Rank 1 Bronze]" or ""))
                end
                local fleetLabel = f.isFleeting and " [Fleeting]" or ""
                local title = (f.name or "Flask") .. rankLabel .. fleetLabel
                local sub = f.isFleeting and "Fleeting Flask from Cauldron. Click to drink." or "Click to drink your Flask."
                PushEntry("item", "item:" .. f.itemID, nil, f.icon, topTxt, botTxt, tostring(f.cnt), isExp, title, sub, nil, false, f.quality, f.maxTiers, f.atlas)
            end
        end
    end

    -- 4. Well Fed / Hearty Food Check (All available quality tiers and ranks in bags + Exact Food Buff Benefit Extraction)
    local hasActiveFood, foodShortStat, foodFullLine, activeFoodRem = self:GetActiveFoodBuffBenefit()
    if rb.trackFood ~= false then
        local hasFood, foodRem = CheckUnitAuraState("player", _staticWellFedNames, nil, "Well Fed", expThresholdSec)
        if hasActiveFood then
            hasFood = true
            if activeFoodRem and activeFoodRem > 0 then
                foodRem = activeFoodRem
            end
        end
        local isEating, _, isEatingSecret = CheckUnitAuraState("player", _staticEatingNames, nil, nil, 0)
        if isEatingSecret then isEating = false end
        if not isEating and (not hasFood or (foodRem > 0 and foodRem <= expThresholdSec)) then
            local foods = ScanOwnedFoods()
            for fIdx = 1, math.min(#foods, 8) do
                if qCount >= (MAX_CRB_SLOTS - 1) then break end
                local fd = foods[fIdx]
                local isExp = hasFood and true or false
                local topTxt = isExp and string.format("|cFFFBBF24%dm|r", math.max(1, math.ceil(foodRem / 60))) or ""
                local botTxt
                if isExp then
                    botTxt = "|cFFFBBF24EXPIRING|r"
                elseif fd.isHearty then
                    botTxt = "|cFFFFD100HEARTY|r"
                else
                    botTxt = "|cFFF87171FOOD|r"
                end

                local rankLabel = ""
                if fd.maxTiers == 2 then
                    rankLabel = (fd.quality and fd.quality >= 2) and " [Rank 2 Gold]" or ((fd.quality == 1) and " [Rank 1 Silver]" or "")
                elseif fd.maxTiers == 3 then
                    rankLabel = (fd.quality and fd.quality >= 3) and " [Rank 3 Gold]" or ((fd.quality == 2) and " [Rank 2 Silver]" or ((fd.quality == 1) and " [Rank 1 Bronze]" or ""))
                end
                local heartyLabel = fd.isHearty and " [Hearty - Persists Through Death]" or ""
                local coloredStatShort = (fd.statShort and fd.statShort ~= "") and DynamicPrep:FormatColoredFoodBenefit(fd.statShort) or nil
                local statBadge = coloredStatShort and (" (" .. coloredStatShort .. ")") or ""
                local title = (fd.name or "Food") .. statBadge .. heartyLabel .. rankLabel
                local sub = fd.isHearty and "Hearty Well Fed persists through death in M+ and raids. Click to eat." or "Click to eat and gain Well Fed."
                if fd.statFullLine and fd.statFullLine ~= "" then
                    sub = fd.statFullLine .. "\n" .. sub
                end
                if coloredStatShort then
                    sub = "Food Benefit: " .. coloredStatShort .. "\n" .. sub
                end
                if isExp and foodFullLine and foodFullLine ~= "" then
                    sub = string.format("Current Buff: %s (%s)\n%s", DynamicPrep:FormatColoredFoodBenefit(foodShortStat or "Well Fed"), foodFullLine, sub)
                end
                PushEntry("item", "item:" .. fd.itemID, nil, fd.icon, topTxt, botTxt, tostring(fd.cnt), isExp, title, sub, nil, fd.isHearty, fd.quality, fd.maxTiers, fd.atlas)
            end
        end
    end

    -- 5. Augment Rune Check (Midnight, The War Within, & Legacy Augment Runes)
    if rb.trackRunes ~= false then
        local runeID, runeCnt, runeIcon, runeName, runeQual, runeMaxT, runeAtlas = ScanOwnedAugmentRune()
        if not runeID then
            runeID, runeCnt, runeIcon, runeName = ScanOwnedConsumable(CONSUMABLE_RUNES)
        end

        if runeID then
            AddRuneItemSignatures(runeID, runeIcon, runeName)
        end
        if not self._runeStaticSignaturesPrimed then
            self._runeStaticSignaturesPrimed = true
            for i = 1, #CONSUMABLE_RUNES do
                AddRuneItemSignatures(CONSUMABLE_RUNES[i], nil, nil)
            end
        end

        local hasRune, runeRem = CheckUnitAuraState("player", _staticRuneMatchNames, _staticRuneMatchIDs, "Augment", expThresholdSec, _staticRuneMatchIcons)
        if not hasRune or (runeRem > 0 and runeRem <= expThresholdSec) then
            if runeID and runeCnt > 0 then
                local isExp = hasRune and true or false
                local topTxt = isExp and string.format("|cFFFBBF24%dm|r", math.max(1, math.ceil(runeRem / 60))) or ""
                local botTxt = isExp and "|cFFFBBF24EXPIRING|r" or "|cFFF87171RUNE|r"
                PushEntry("item", "item:" .. runeID, nil, runeIcon, topTxt, botTxt, tostring(runeCnt), isExp, runeName or "Augment Rune", "Click to activate your Augment Rune.", nil, false, runeQual, runeMaxT, runeAtlas)
            end
        end
    end

    -- If in HUD Edit Mode and all buffs are currently satisfied, show 5 centered sample icons so you can see exact alignment!
    local inBuffEdit = (self.inBuffsEditMode or (self.inEditMode and self.inBuffsEditMode ~= false) or (self.clickableBuffBar and self.clickableBuffBar._dsEditModeActive)) and true or false
    if qCount == 0 and inBuffEdit then
        local _, classFile = UnitClass("player")
        local cDef = (classFile and CLASS_RAID_BUFFS[classFile]) or CLASS_RAID_BUFFS.DRUID
        PushEntry("spell", cDef.name, "player", cDef.icon, "|cFFF871714/5|r", "|cFFF87171MISSING|r", "", false, cDef.name, "")
        PushEntry("spell", cDef.name, "player", 463543, "|cFFFBBF244m|r", "|cFFFBBF24EXPIRING|r", "8", true, "Flask", "")
        PushEntry("spell", cDef.name, "player", 463546, "", "|cFFF87171OIL|r", "12", false, "Weapon Oil", "")
        PushEntry("spell", cDef.name, "player", 134019, "", "|cFFFFD100HEARTY|r", "5", false, "Food", "")
        PushEntry("spell", cDef.name, "player", 5764478, "", "|cFFF87171RUNE|r", "18", false, "Augment Rune", "")
    end

    self._bagConsumablesDirty = false
    return qCount
end

local _crbRefreshPending = false
local _lastCrbRefresh = 0

function DynamicPrep:RefreshClickableBuffs(forceImmediate)
    local now = GetTime and GetTime() or 0
    if not forceImmediate and (now - _lastCrbRefresh) < 0.45 then
        if not _crbRefreshPending then
            _crbRefreshPending = true
            C_Timer.After(0.45, function()
                _crbRefreshPending = false
                DynamicPrep:RefreshClickableBuffs(true)
            end)
        end
        return
    end
    _lastCrbRefresh = now

    if InCombatLockdown and InCombatLockdown() then
        self._inCombatState = true
        self._pendingCrbAfterCombat = true
        -- Coalesce in-combat raid buff (16/17 MotW) & Symbiotic tank link checks into the 0.30s combat ticker
        self:ScheduleCombatAuraEvaluation(forceImmediate and true or false)
        return
    end

    local bar = self:CreateClickableBuffBar()
    if not bar or InCombatLockdown() then return end

    local inBuffEdit = (self.inBuffsEditMode or (self.inEditMode and self.inBuffsEditMode ~= false) or bar._dsEditModeActive) and true or false
    if inBuffEdit then
        if UnregisterStateDriver then
            pcall(UnregisterStateDriver, bar, "visibility")
        end
        bar:Show()
    else
        if RegisterStateDriver then
            pcall(RegisterStateDriver, bar, "visibility", "[petbattle][vehicleui][combat] hide; show")
        end
    end

    local rb = (self.db and self.db.raidBuffs) or DEFAULTS.raidBuffs
    local iconSize = math.max(32, math.min(64, tonumber(rb.iconSize) or 44))
    local gap = 10
    local ar, ag, ab, hex = GetActiveAccentRGB()

    local count = self:ScanAndPopulateRaidBuffQueue()
    self:RefreshCombatBuffAlert()
    if self.RefreshReadinessTrackerStrip then pcall(self.RefreshReadinessTrackerStrip, self) end
    self:UpdateSuiteHeaderStatus()

    if count <= 0 and not inBuffEdit then
        for i = 1, MAX_CRB_SLOTS do
            bar.buttons[i]:SetAlpha(1.0)
            bar.buttons[i]:EnableMouse(true)
            bar.buttons[i]:Hide()
        end
        if bar.hudBg then bar.hudBg:Hide() end
        bar.mover:Hide()
        return
    end

    -- TRUE CENTER-ALIGNED SYMMETRIC LAYOUT:
    -- Whether 1, 2, 3, or 8 icons are active, they are always centered symmetrically around the middle of `bar`!
    local visibleCount = math.max(1, count)
    local isVert = (rb.orientation == "VERTICAL")
    local hudOpa = math.max(0.20, math.min(1.00, tonumber(rb.hudOpacity) or 0.95))
    local borderStyle = rb.hudBorderStyle or (self.db and self.db.hudBorderStyle) or "ACCENT"
    local isShownSetting = (rb.enabled ~= false)
    if inBuffEdit then
        bar:SetAlpha(isShownSetting and hudOpa or math.min(0.65, hudOpa))
    else
        bar:SetAlpha(hudOpa)
    end

    local btnBorderRGBA
    if borderStyle == "NONE" then
        btnBorderRGBA = { 0, 0, 0, 0 }
    elseif borderStyle == "DARK" or borderStyle == "SUBTLE" then
        btnBorderRGBA = COLORS.BorderStrong
    else
        btnBorderRGBA = { ar, ag, ab, 0.90 }
    end

    local contentW, contentH, barW, barH
    local vGap = gap + 12
    if isVert then
        contentW = iconSize
        contentH = visibleCount * iconSize + (visibleCount - 1) * vGap
        barW = iconSize + 20
        barH = math.max(iconSize + 22, contentH + 22)
    else
        contentW = visibleCount * iconSize + (visibleCount - 1) * gap
        contentH = iconSize
        barW = math.max(iconSize + 16, contentW + 16)
        barH = iconSize + 22
    end

    if bar.hudBg then
        local showHudCapsule = (rb.showHudCapsule == true) or inBuffEdit
        if showHudCapsule then
            local capsuleBorder = (borderStyle == "NONE") and { 0, 0, 0, 0 }
                or ((borderStyle == "DARK" or borderStyle == "SUBTLE") and COLORS.BorderStrong)
                or { ar, ag, ab, 0.45 }
            SetPixelBackdrop(bar.hudBg, { 0.035, 0.043, 0.059, 0.78 }, capsuleBorder, 1)
            bar.hudBg:Show()
        else
            bar.hudBg:Hide()
        end
    end

    for i = 1, MAX_CRB_SLOTS do
        local btn = bar.buttons[i]
        btn:EnableMouse(not inBuffEdit)
        local entry = _crbQueue[i]
        if i <= count and entry and entry.active then
            btn:SetAlpha(1.0)
            btn:SetSize(iconSize, iconSize)
            btn:ClearAllPoints()
            if isVert then
                local offsetY = (contentH / 2) - ((i - 0.5) * iconSize) - ((i - 1) * vGap) + 6
                btn:SetPoint("CENTER", bar, "CENTER", 0, offsetY)
            else
                -- Exact horizontal center offset from the center of `bar` (shifted +4px Y to leave room for the bottom label)
                local offsetX = (-contentW / 2) + ((i - 0.5) * iconSize) + ((i - 1) * gap)
                btn:SetPoint("CENTER", bar, "CENTER", offsetX, 4)
            end

            btn:SetAttribute("type", entry.actionType)
            if entry.actionType == "spell" then
                btn:SetAttribute("spell", entry.actionTarget)
                btn:SetAttribute("item", nil)
                btn:SetAttribute("macrotext", nil)
                btn:SetAttribute("unit", entry.unit or "player")
            elseif entry.actionType == "macro" then
                btn:SetAttribute("macrotext", entry.macroText)
                btn:SetAttribute("spell", nil)
                btn:SetAttribute("item", nil)
                btn:SetAttribute("unit", nil)
            else
                btn:SetAttribute("item", entry.actionTarget)
                btn:SetAttribute("spell", nil)
                btn:SetAttribute("macrotext", nil)
                btn:SetAttribute("unit", nil)
            end

            btn.icon:SetTexture(entry.icon or 134400)
            btn.topBadge:SetText(entry.topText or "")
            btn.stackBadge:SetText(entry.stackText or "")
            btn.statusLabel:SetText(entry.bottomText or "")
            btn._isExpiring = entry.isExpiring
            btn._tooltipTitle = entry.tooltipTitle
            btn._tooltipSub = entry.tooltipSub
            btn._actionType = entry.actionType
            btn._actionTarget = entry.actionTarget

            -- Hearty Food Distinguishing Badge
            if entry.isHearty then
                btn.heartyBadge:Show()
                btn.heartyText:Show()
            else
                btn.heartyBadge:Hide()
                btn.heartyText:Hide()
            end

            -- Consumable Quality Badge (Rank 1 Silver vs Rank 2 Gold)
            if entry.quality and entry.quality > 0 then
                local atlas, tr, tg, tb = GetConsumableQualityAtlas(entry.quality, entry.maxTiers, entry.qualityAtlas)
                local isSet = false
                if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
                    btn.qualityBadge:SetAtlas(atlas, false)
                    btn.qualityBadge:SetSize(14, 14)
                    btn.qualityBadge:SetVertexColor(1, 1, 1, 1)
                    isSet = true
                end
                if not isSet then
                    local ok = pcall(function() btn.qualityBadge:SetAtlas(atlas, false) end)
                    if not ok then
                        btn.qualityBadge:SetTexture("Interface\\Buttons\\WHITE8X8")
                    end
                    btn.qualityBadge:SetSize(11, 11)
                    btn.qualityBadge:SetVertexColor(tr or 1, tg or 1, tb or 1, 0.95)
                end
                btn.qualityBadge:ClearAllPoints()
                if entry.isHearty then
                    btn.qualityBadge:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 2)
                else
                    btn.qualityBadge:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
                end
                btn.qualityBadge:Show()
            else
                btn.qualityBadge:Hide()
            end

            if entry.isExpiring then
                SetPixelBackdrop(btn.bgFrame or btn, COLORS.BgVoid, COLORS.Gold, 1)
            else
                SetPixelBackdrop(btn.bgFrame or btn, COLORS.BgVoid, btnBorderRGBA, 1)
            end
            btn:Show()
        else
            btn:Hide()
        end
    end

    bar:SetSize(barW, barH)
    local hudScale = tonumber(rb.hudScale)
    if hudScale and hudScale > 0 then
        bar:SetScale(math.max(0.60, math.min(1.50, hudScale)))
    end
    local pt, rp, curX, curY = self:GetSavedBuffBarPosition()
    local cx, cy, didClamp = ClampPrepFrameToScreen(bar, pt or "CENTER", rp or "CENTER", curX or 0, curY or 140, barW, barH)
    if didClamp then
        self:SaveBuffBarEditPosition(pt or "CENTER", rp or "CENTER", cx, cy)
    end
    curX, curY = cx, cy
    bar:ClearAllPoints()
    bar:SetPoint(pt or "CENTER", UIParent, rp or "CENTER", curX or 0, curY or 140)

    if bar.mover then
        SetPixelBackdrop(bar.mover, { 0.05, 0.06, 0.09, 0.86 }, { ar, ag, ab, 1.0 }, 1)
        if bar.mover.dimBg then bar.mover.dimBg:SetColorTexture(0.05, 0.06, 0.09, 0.86) end
        bar.mover.label:SetText(string.format("|cFF%sClickable Raid Buffs HUD|r\n|cFFFFFFFF(X: %d, Y: %d)  [Right-Click: Center X=0]|r", hex, math.floor((curX or 0) + 0.5), math.floor((curY or 140) + 0.5)))
        bar.mover:SetShown(inBuffEdit and not bar._dsEditModeActive and true or false)
    end
end

-- Hook ResetHUDPosition so Suite HUD Edit Mode resets BOTH the Top Info Bar & Clickable Raid Buffs HUD!
do
    local origResetHUD = DynamicPrep.ResetHUDPosition
    function DynamicPrep.ResetHUDPosition(...)
        if origResetHUD then origResetHUD(...) end
        DynamicPrep:ResetBuffBarHUDPosition()
        DynamicPrep:RefreshCombatBuffAlert()
    end
end
-- ============================================================================
-- 3-TAB WORKSPACE (Tab 1: Bar & Folio | Tab 2: Clickable Raid Buffs | Tab 3: Everyday Convenience)
-- ============================================================================
function DynamicPrep:EnsureThreeTabWorkspace()
    -- Fully unified and initialized directly within DynamicPrep:RenderWorkspace()
end

-- O(1) Valid Group Unit Lookup Table (Strictly "player", "party1".."party4", "raid1".."raid40").
-- Rejects "target", "focus", "mouseover", "SoftEnemy", "pet", "partypet*", "raidpet*", "nameplate*", "boss*", "arena*", etc.
local VALID_GROUP_UNITS = { player = true }
for i = 1, 4 do VALID_GROUP_UNITS["party" .. i] = true end
for i = 1, 40 do VALID_GROUP_UNITS["raid" .. i] = true end

local COMBAT_AURA_THROTTLE_SEC = 0.30

local function RunCoalescedCombatAuraTick()
    DynamicPrep._combatAuraTimer = nil
    if not DynamicPrep._combatAuraDirty then return end
    DynamicPrep._combatAuraDirty = false
    DynamicPrep._lastCombatAuraEvalTime = GetTime and GetTime() or 0
    if IsPlayerInCombat() then
        DynamicPrep:RefreshCombatBuffAlert()
        if DynamicPrep.RefreshReadinessTrackerStrip then
            pcall(DynamicPrep.RefreshReadinessTrackerStrip, DynamicPrep)
        end
        DynamicPrep:UpdateSuiteHeaderStatus()
    else
        DynamicPrep:RefreshCombatBuffAlert()
        DynamicPrep:RefreshClickableBuffs(false)
    end
end

function DynamicPrep:ScheduleCombatAuraEvaluation(forceImmediate)
    self._combatAuraDirty = true
    if forceImmediate then
        if self._combatAuraTimer and self._combatAuraTimer.Cancel then
            self._combatAuraTimer:Cancel()
        end
        RunCoalescedCombatAuraTick()
        return
    end
    local now = GetTime and GetTime() or 0
    local elapsed = now - (self._lastCombatAuraEvalTime or 0)
    if elapsed >= COMBAT_AURA_THROTTLE_SEC and not self._combatAuraTimer then
        RunCoalescedCombatAuraTick()
        return
    end
    if not self._combatAuraTimer then
        local delay = math.max(0.05, COMBAT_AURA_THROTTLE_SEC - math.max(0, elapsed))
        if C_Timer and C_Timer.NewTimer then
            self._combatAuraTimer = C_Timer.NewTimer(delay, RunCoalescedCombatAuraTick)
        else
            self._combatAuraTimer = true
            C_Timer.After(delay, RunCoalescedCombatAuraTick)
        end
    end
end

-- Event Listener for Clickable Raid Buffs, Symbiotic Bond, Food Benefit & In-Combat Brez / Raid Buff Tracker
local crbEventFrame = CreateFrame("Frame")
SafeRegisterEvent(crbEventFrame, "PLAYER_LOGIN")
SafeRegisterEvent(crbEventFrame, "PLAYER_ENTERING_WORLD")
SafeRegisterEvent(crbEventFrame, "PLAYER_REGEN_DISABLED")
SafeRegisterEvent(crbEventFrame, "PLAYER_REGEN_ENABLED")
SafeRegisterEvent(crbEventFrame, "PLAYER_SPECIALIZATION_CHANGED")
SafeRegisterEvent(crbEventFrame, "UNIT_AURA")
SafeRegisterEvent(crbEventFrame, "UNIT_HEALTH")
SafeRegisterEvent(crbEventFrame, "UNIT_FLAGS")
SafeRegisterEvent(crbEventFrame, "INCOMING_RESURRECT_CHANGED")
SafeRegisterEvent(crbEventFrame, "UNIT_SPELLCAST_SENT")
SafeRegisterEvent(crbEventFrame, "UNIT_SPELLCAST_SUCCEEDED")
SafeRegisterEvent(crbEventFrame, "UNIT_INVENTORY_CHANGED")
SafeRegisterEvent(crbEventFrame, "BAG_UPDATE_DELAYED")
SafeRegisterEvent(crbEventFrame, "GROUP_ROSTER_UPDATE")
SafeRegisterEvent(crbEventFrame, "READY_CHECK")
SafeRegisterEvent(crbEventFrame, "CHALLENGE_MODE_START")
SafeRegisterEvent(crbEventFrame, "CHALLENGE_MODE_COMPLETED")
SafeRegisterEvent(crbEventFrame, "CHALLENGE_MODE_RESET")
SafeRegisterEvent(crbEventFrame, "ENCOUNTER_END")
crbEventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
    if IsModuleDisabledInSuite("DynamicPrep") then crbEventFrame:UnregisterAllEvents(); return end
    if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" or event == "CHALLENGE_MODE_RESET" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        wipe(_unitAuraStateCache)
        DynamicPrep:UpdateGroupLifeStates(event)
    end
    if event == "UNIT_SPELLCAST_SENT" then
        if arg1 == "player" then
            local spellID = (not _IsSecret(arg4) and type(arg4) == "number") and arg4 or nil
            if spellID and SYMBIOTIC_SPELL_IDS[spellID] then
                DynamicPrep._pendingSymbioticSentTarget = (not _IsSecret(arg2) and type(arg2) == "string") and arg2 or nil
            end
        end
        return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if arg1 == "player" then
            local spellID = (not _IsSecret(arg3) and type(arg3) == "number") and arg3 or nil
            if spellID then
                if SYMBIOTIC_SPELL_IDS[spellID] then
                    DynamicPrep:RecordSymbioticCastTarget(DynamicPrep._pendingSymbioticSentTarget)
                    DynamicPrep._pendingSymbioticSentTarget = nil
                    if not IsPlayerInCombat() then
                        DynamicPrep:RefreshClickableBuffs(true)
                    end
                end
                DynamicPrep:ClearCombatRebuffQueueOnCast(spellID)
            end
        end
        return
    end
    if event == "UNIT_HEALTH" or event == "UNIT_FLAGS" or event == "INCOMING_RESURRECT_CHANGED" then
        local u = (not _IsSecret(arg1) and type(arg1) == "string") and arg1 or nil
        if not u or not VALID_GROUP_UNITS[u] then
            return
        end
        DynamicPrep:UpdateGroupLifeStates(event, u)
        if event == "INCOMING_RESURRECT_CHANGED" then
            -- Follow-up check right after resurrect state changes so accepted Brez transitions (not UnitIsDeadOrGhost) are caught immediately
            C_Timer.After(0.30, function()
                DynamicPrep:UpdateGroupLifeStates("INCOMING_RESURRECT_CHANGED", u)
                DynamicPrep:ScheduleCombatAuraEvaluation(false)
            end)
        end
        DynamicPrep:ScheduleCombatAuraEvaluation(false)
        return
    end
    if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
        if InCombatLockdown and InCombatLockdown() and event == "BAG_UPDATE_DELAYED" then
            DynamicPrep._pendingBagCacheInvalidate = true
            return
        end
        DynamicPrep._bagConsumablesDirty = true
        _cachedFoods, _cachedFlasks, _cachedOil, _cachedRune = nil, nil, nil, nil
    end
    if event == "CHALLENGE_MODE_START" then
        if not IsPlayerInCombat() then
            DynamicPrep:RefreshClickableBuffs(true)
        end
        return
    end
    if event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" or event == "ENCOUNTER_END" then
        C_Timer.After(0.5, function()
            if not IsPlayerInCombat() then
                DynamicPrep:RefreshClickableBuffs(true)
            end
        end)
        return
    end
    if event == "UNIT_INVENTORY_CHANGED" then
        if arg1 ~= "player" or IsPlayerInCombat() then return end
    elseif event == "UNIT_AURA" then
        local u = (not _IsSecret(arg1) and type(arg1) == "string") and arg1 or nil
        if not u or not VALID_GROUP_UNITS[u] then return end
        DynamicPrep:UpdateGroupLifeStates(event, u)
        if IsPlayerInCombat() then
            -- Never run synchronous raid aura or consumable scans on UNIT_AURA during combat (including u == "player").
            -- Coalesce via the 0.30s (3.3 Hz max) timer throttle.
            DynamicPrep:ScheduleCombatAuraEvaluation(false)
            return
        end
        if u ~= "player" then
            local rb = DynamicPrep.db and DynamicPrep.db.raidBuffs
            if not (rb and (rb.trackClassBuffs ~= false or rb.trackPartnerBuffs ~= false)) then
                return
            end
            local now = GetTime and GetTime() or 0
            local hasMissingNow = (DynamicPrep._lastCombatBuffSummary and (DynamicPrep._lastCombatBuffSummary.missingCount or 0) > 0) and true or false
            local throttleWindow = hasMissingNow and 0.30 or 1.00
            if DynamicPrep._lastGroupAuraTick and (now - DynamicPrep._lastGroupAuraTick) < throttleWindow then
                if not DynamicPrep._groupAuraTimerPending then
                    DynamicPrep._groupAuraTimerPending = true
                    C_Timer.After(throttleWindow, function()
                        DynamicPrep._groupAuraTimerPending = nil
                        DynamicPrep._lastGroupAuraTick = GetTime and GetTime() or 0
                        if IsPlayerInCombat() then
                            DynamicPrep:ScheduleCombatAuraEvaluation(false)
                        else
                            DynamicPrep:RefreshClickableBuffs(false)
                        end
                    end)
                end
                return
            end
            DynamicPrep._lastGroupAuraTick = now
        end
    end
    if event == "PLAYER_REGEN_DISABLED" then
        DynamicPrep._inCombatState = true
        DynamicPrep:UpdateGroupLifeStates(event)
        DynamicPrep:ScheduleCombatAuraEvaluation(true)
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        DynamicPrep._inCombatState = false
        DynamicPrep._pendingCrbAfterCombat = nil
        DynamicPrep._combatAuraDirty = false
        if DynamicPrep._combatAuraTimer and DynamicPrep._combatAuraTimer.Cancel then
            DynamicPrep._combatAuraTimer:Cancel()
        end
        DynamicPrep._combatAuraTimer = nil
        wipe(DynamicPrep._combatNeedsRebuffQueue)
        if DynamicPrep._pendingBagCacheInvalidate then
            DynamicPrep._pendingBagCacheInvalidate = nil
            DynamicPrep._bagConsumablesDirty = true
            _cachedFoods, _cachedFlasks, _cachedOil, _cachedRune = nil, nil, nil, nil
        end
        DynamicPrep:RefreshCombatBuffAlert()
        -- Defer slightly past the exact PLAYER_REGEN_ENABLED tick so WoW's combat secret aura state has cleared
        C_Timer.After(0.15, function()
            if not (InCombatLockdown and InCombatLockdown()) then
                DynamicPrep._inCombatState = false
                DynamicPrep:RefreshClickableBuffs(true)
            end
        end)
    elseif not IsPlayerInCombat() then
        DynamicPrep:RefreshClickableBuffs(false)
    end
end)

-- ============================================================================
-- M+ SECRET LOCKDOWN & 500-PULL STRESS BENCHMARK (/dprep simkey)
-- ============================================================================
function DynamicPrep:RunKeystoneSimulation()
    -- 1. Prime cache with current normal stats first
    _dpSimSecretMode = false
    if self.RefreshBar then pcall(self.RefreshBar, self) end
    if self.RefreshClickableBuffs then pcall(self.RefreshClickableBuffs, self, true) end

    -- 2. Activate simulated M+ Secret Lockdown and run 500 back-to-back RefreshBar() & RefreshClickableBuffs() calls
    _dpSimSecretMode = true
    UpdateAddOnMemoryUsage()
    local memBefore = GetAddOnMemoryUsage("DynamicPrep") or 0
    local t0 = debugprofilestop and debugprofilestop() or 0
    local errors = 0
    for i = 1, 500 do
        local ok = pcall(function()
            if self.RefreshBar then self:RefreshBar() end
            if self.RefreshClickableBuffs then self:RefreshClickableBuffs(true) end
        end)
        if not ok then errors = errors + 1 end
    end
    local t1 = debugprofilestop and debugprofilestop() or 0
    UpdateAddOnMemoryUsage()
    local memAfter = GetAddOnMemoryUsage("DynamicPrep") or 0
    _dpSimSecretMode = false
    if self.RefreshClickableBuffs then pcall(self.RefreshClickableBuffs, self, true) end

    local elapsedMs = t1 - t0
    local perCallMs = elapsedMs / 500
    local memDelta  = math.max(0, memAfter - memBefore)
    DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "|cFFFF7C0ADynamic|r|cFFFFFFFFPrep|r [M+ SimKey]: 500 refreshes under Secret Lockdown -> |cFF22C55E%d errors|r | Total: |cFFFFFFFF%.2f ms|r (|cFF22C55E%.4f ms/tick|r) | Mem Delta: |cFFFFFFFF%.1f KB|r",
        errors, elapsedMs, perCallMs, memDelta
    ))
end
end)() end

do
    local oldSlash = SlashCmdList["DYNAMICPREP"]
    if type(oldSlash) == "function" then
        SlashCmdList["DYNAMICPREP"] = function(msg)
            local clean = (msg or ""):lower():match("^%s*(.-)%s*$")
            if clean == "simkey" or clean == "testkey" then
                DynamicPrep:RunKeystoneSimulation()
                return
            elseif clean == "testaudit" then
                DynamicPrep:TogglePaperdollAuditPreview()
                return
            end
            oldSlash(msg)
        end
    end
end

-- Register Clickable Raid Buffs HUD into DynamicSuite HUD Edit Mode Manager
do
    _G.DynamicSuite = _G.DynamicSuite or {}
    _G.DynamicSuite.hudFrames = _G.DynamicSuite.hudFrames or {}
    
    local function RegisterRaidBuffsHudDefinition()
        if _G.DynamicLoad and type(_G.DynamicLoad.RegisterHudFrame) == "function" then
            pcall(_G.DynamicLoad.RegisterHudFrame, _G.DynamicLoad, {
                id = "prepBuffs",
                name = "Raid Buffs",
                label = "Clickable Raid Buffs HUD",
                getFrame = function() return DynamicPrep:CreateClickableBuffBar() end,
                isVisible = function() return DynamicPrep:ShouldShowRaidBuffsForZone() end,
            })
        end
    end
    
    C_Timer.After(0.5, RegisterRaidBuffsHudDefinition)
end

function _G.DynamicPrep_OnAddonCompartmentClick(_, buttonName)
    if buttonName == "RightButton" then
        DynamicPrep:SetEditMode(not DynamicPrep.inEditMode)
    elseif _G.DynamicSuite and type(_G.DynamicSuite.OpenModule) == "function" then
        _G.DynamicSuite:OpenModule("DynamicPrep")
    else
        DynamicPrep:OpenWorkspace(1)
    end
end
