-- DynamicCursor v2.11.2 (/dcur, /dynamiccursor)
-- Cursor Ring, Radial GCD & Cast/Channel/Empower Arc, Character Crosshair, Find My Cursor, Pooled Trail & Smart Tooltips.
-- Retail 12.1.5 / 12.1.7 (Interface 120105, 120107) | Zero-Taint, Secret-Value Safe, 0.00 ms Idle CPU.

local addonName, addonTable = ...
local ADDON_FOLDER = (type(addonName) == "string" and addonName ~= "") and addonName or "DynamicCursor"
local STANDALONE_NAME = "DynamicCursor"

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

local VERSION = ResolveAddonVersion(ADDON_FOLDER, "2.11.2")

local function ShouldYieldToOtherInstall(thisFolder, standaloneName, thisVersion, globalTbl)
    if thisFolder == standaloneName then
        if type(globalTbl) == "table" and globalTbl._loadedFromSuite == true then
            local suiteVer = globalTbl._loadedVersion or globalTbl.version or "2.11.2"
            if CompareSemVer(thisVersion, suiteVer) <= 0 then
                return true
            end
        end
        return false
    end
    if type(globalTbl) == "table" and globalTbl._loadedFromStandalone == true then
        local stVer = globalTbl._loadedVersion or globalTbl.version or "0.0.0"
        if CompareSemVer(stVer, thisVersion) > 0 then
            return true
        end
    end
    return false
end

if ShouldYieldToOtherInstall(ADDON_FOLDER, STANDALONE_NAME, VERSION, _G.DynamicCursor) then
    return
end

local DynamicCursor = _G.DynamicCursor or {}
_G.DynamicCursor = DynamicCursor
DynamicCursor.version = VERSION
DynamicCursor._loadedVersion = VERSION
DynamicCursor._loadedFromSuite = (ADDON_FOLDER == "DynamicSuite")
DynamicCursor._loadedFromStandalone = (ADDON_FOLDER == STANDALONE_NAME)
DynamicCursor.folderName = ADDON_FOLDER

local MEDIA_BASE = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\"
local ICON_MODULE = MEDIA_BASE .. "Icons\\icon_mod_cursor.tga"
local ICON_CHEVRON_DOWN = MEDIA_BASE .. "Icons\\icon_chevron_down.tga"
local ICON_CHEVRON_UP = MEDIA_BASE .. "Icons\\icon_chevron_up.tga"

local function _IsSecret(v)
    if v == nil then return false end
    if type(issecretvalue) == "function" then
        local ok, res = pcall(issecretvalue, v)
        if not ok or res == true then return true end
    end
    if type(canaccessvalue) == "function" then
        local ok, can = pcall(canaccessvalue, v)
        if not ok or can == false then return true end
    end
    return false
end

local function IsModuleDisabledInSuite(modName)
    if _G.DynamicSuite and type(_G.DynamicSuite.IsModuleDisabled) == "function" then
        local ok, res = pcall(_G.DynamicSuite.IsModuleDisabled, _G.DynamicSuite, modName)
        if ok and res == true then return true end
    end
    local db = _G.DynamicSuiteDB
    if type(db) == "table" then
        if type(db.disabledModules) == "table" and (db.disabledModules[modName] or db.disabledModules.cursor) then
            return true
        end
        if type(db.global) == "table" and type(db.global.disabledModules) == "table" and (db.global.disabledModules[modName] or db.global.disabledModules.cursor) then
            return true
        end
    end
    return false
end

local function SafeRegisterEvent(frame, eventName)
    if not frame or not eventName then return end
    if _G.C_EventUtils and type(_G.C_EventUtils.IsEventValid) == "function" then
        if not _G.C_EventUtils.IsEventValid(eventName) then
            return
        end
    end
    frame:RegisterEvent(eventName)
end

local function GetSuiteAccent()
    if _G.DynamicSuite and type(_G.DynamicSuite.GetSuiteAccent) == "function" then
        local ok, r, g, b = pcall(_G.DynamicSuite.GetSuiteAccent, _G.DynamicSuite)
        if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return r, g, b
        end
    end
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.GetActiveAccentColor) == "function" then
        local ok, r, g, b = pcall(_G.DynamicSuite.UI.GetActiveAccentColor)
        if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return r, g, b
        end
    end
    return 0.220, 0.741, 0.973
end

local function GetAccentHex()
    local r, g, b = GetSuiteAccent()
    return string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function GetSuiteSurfaceColors()
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.GetActiveSurfaceColors) == "function" then
        local ok, surf = pcall(_G.DynamicSuite.UI.GetActiveSurfaceColors)
        if ok and type(surf) == "table" then return surf end
    end
    return nil
end

local function GetActiveFontPath()
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.GetFont) == "function" then
        local ok, p = pcall(_G.DynamicSuite.UI.GetFont)
        if ok and type(p) == "string" and p ~= "" then return p end
    end
    return "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.TTF"
end

local function SetSafeFont(fs, size, flags)
    if not fs or type(fs.SetFont) ~= "function" then return end
    local path = GetActiveFontPath()
    local ok = pcall(fs.SetFont, fs, path, size or 11, flags or "")
    if not ok then
        pcall(fs.SetFont, fs, _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 11, flags or "")
    end
end

local function PrintMsg(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF%sDynamic|r|cFFFFFFFFCursor:|r %s", GetAccentHex(), tostring(msg or "")))
    end
end

local function GetClassColorRGB()
    local cls = nil
    if type(UnitClass) == "function" then
        local okUC, _, c = pcall(UnitClass, "player")
        if okUC and not _IsSecret(c) and type(c) == "string" and c ~= "" then
            cls = c
        end
    end
    if cls then
        if _G.C_ClassColor and type(_G.C_ClassColor.GetClassColor) == "function" then
            local ok, col = pcall(_G.C_ClassColor.GetClassColor, cls)
            if ok and type(col) == "table" and type(col.GetRGB) == "function" then
                local r, g, b = col:GetRGB()
                if type(r) == "number" and type(g) == "number" and type(b) == "number" then
                    return r, g, b
                end
            end
        end
        if RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls] then
            local c = RAID_CLASS_COLORS[cls]
            return c.r or 1, c.g or 1, c.b or 1
        end
    end
    return GetSuiteAccent()
end

local function ParseHexRGB(hexStr)
    local s = tostring(hexStr or ""):gsub("#", ""):gsub("%s+", "")
    if #s == 8 then s = s:sub(3, 8) end
    if #s ~= 6 or not s:match("^[0-9a-fA-F]+$") then
        return 0.220, 0.741, 0.973
    end
    local r = tonumber(s:sub(1, 2), 16) / 255
    local g = tonumber(s:sub(3, 4), 16) / 255
    local b = tonumber(s:sub(5, 6), 16) / 255
    return r, g, b
end

local function RGBToHex(r, g, b)
    local cr = math.max(0, math.min(255, math.floor((tonumber(r) or 0) * 255 + 0.5)))
    local cg = math.max(0, math.min(255, math.floor((tonumber(g) or 0) * 255 + 0.5)))
    local cb = math.max(0, math.min(255, math.floor((tonumber(b) or 0) * 255 + 0.5)))
    return string.format("%02X%02X%02X", cr, cg, cb)
end

local function ResolveColorMode(mode, customHex, combatShift, matchR, matchG, matchB)
    if combatShift and InCombatLockdown and InCombatLockdown() then
        return 0.980, 0.450, 0.220
    end
    if mode == "MATCH_RING" and type(matchR) == "number" then
        return matchR, matchG, matchB
    elseif mode == "CLASS" then
        return GetClassColorRGB()
    elseif mode == "HIGH_VIS_GREEN" then
        return 0.133, 0.920, 0.369
    elseif mode == "BRIGHT_GOLD" then
        return 1.000, 0.820, 0.160
    elseif mode == "CRIMSON" then
        return 0.950, 0.220, 0.220
    elseif mode == "CUSTOM" then
        return ParseHexRGB(customHex)
    end
    return GetSuiteAccent()
end

local function OpenCursorColorPicker(anchorFrame, titleText, initialHex, onLiveChange)
    local r, g, b = ParseHexRGB(initialHex)
    local openObsidian = nil
    if _G.DynamicSuite then
        if type(_G.DynamicSuite.OpenColorPicker) == "function" then
            openObsidian = _G.DynamicSuite.OpenColorPicker
        elseif _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.OpenColorPicker) == "function" then
            openObsidian = _G.DynamicSuite.UI.OpenColorPicker
        elseif _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.OpenDSColorPicker) == "function" then
            openObsidian = _G.DynamicSuite.UI.OpenDSColorPicker
        end
    end
    if openObsidian then
        openObsidian(anchorFrame, titleText or "Custom Colour", { r = r, g = g, b = b, a = 1 }, false, function(nr, ng, nb)
            if type(onLiveChange) == "function" then
                onLiveChange(RGBToHex(nr, ng, nb))
            end
        end)
        return
    end
    if _G.ColorPickerFrame and type(_G.ColorPickerFrame.SetupColorPickerAndShow) == "function" then
        _G.ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            hasOpacity = false,
            swatchFunc = function()
                local nr, ng, nb = _G.ColorPickerFrame:GetColorRGB()
                if type(onLiveChange) == "function" then
                    onLiveChange(RGBToHex(nr, ng, nb))
                end
            end,
            cancelFunc = function()
                if type(onLiveChange) == "function" then
                    onLiveChange(RGBToHex(r, g, b))
                end
            end,
        })
    end
end

local function GetNativeCursorSize()
    local raw = nil
    if _G.C_CVar and type(_G.C_CVar.GetCVar) == "function" then
        local ok, v = pcall(_G.C_CVar.GetCVar, "cursorSizePreferred")
        if ok and not _IsSecret(v) then raw = v end
    elseif type(_G.GetCVar) == "function" then
        local ok, v = pcall(_G.GetCVar, "cursorSizePreferred")
        if ok and not _IsSecret(v) then raw = v end
    end
    local n = tonumber(raw)
    if n == 0 or n == 1 or n == 2 or n == 3 or n == 4 then
        return tostring(n)
    end
    return "-1"
end

local function SetNativeCursorSize(val)
    if InCombatLockdown and InCombatLockdown() then
        PrintMsg("Cannot change Built-In Mouse Pointer Size during combat.")
        return
    end
    local sVal = tostring(val or "-1")
    if _G.C_CVar and type(_G.C_CVar.SetCVar) == "function" then
        pcall(_G.C_CVar.SetCVar, "cursorSizePreferred", sVal)
    elseif type(_G.SetCVar) == "function" then
        pcall(_G.SetCVar, "cursorSizePreferred", sVal)
    end
end

-- ============================================================================
-- 1. DEFAULTS & SAVEDVARIABLES
-- ============================================================================
local DEFAULTS = {
    activeSubTab = 1,
    drawerExpanded = {},

    -- Tab 1: Cursor Ring, GCD & Cast Arc (Off by default)
    ringEnabled = false,
    ringStyle = "SOLID",            -- "SOLID" | "GLOW" | "DUAL"
    ringThickness = 3,              -- 1..5
    ringExtraContrast = false,      -- dark outline behind main ring, GCD ring & cast arc
    ringRadius = 24,                -- 16..96 (compact modern default)
    ringOffsetX = 0,                -- -16..16
    ringOffsetY = 0,                -- -16..16
    ringCenterDot = false,
    ringCenterDotSize = 4,          -- 2..8
    ringCenterDotColorMode = "MATCH_RING", -- "MATCH_RING" | "ACCENT" | "CLASS" | "CUSTOM"
    ringCenterDotCustomHex = "FFFFFF",
    ringOpacityOOC = 0.55,          -- 0.05..1.00
    ringOpacityCombat = 0.95,       -- 0.05..1.00
    ringIdleFade = "OFF",           -- "OFF" | "2" | "5"
    ringColorMode = "ACCENT",       -- "ACCENT" | "CLASS" | "HIGH_VIS_GREEN" | "CUSTOM"
    ringCustomHex = "38BDF8",
    ringCombatShift = false,
    ringStrata = "TOOLTIP",         -- "HIGH" | "DIALOG" | "TOOLTIP"
    ringKeepMouseLook = true,
    ringMouseLookOpacity = 0.35,    -- 0.10..1.00
    ringClickPulse = false,
    ringClickPulseScale = 1.75,     -- 1.25..2.50
    ringClickPulseColorMode = "MATCH_RING", -- "MATCH_RING" | "ACCENT" | "CUSTOM"
    ringClickPulseCustomHex = "38BDF8",
    groundTargetHighlight = true,
    groundTargetColorMode = "HIGH_VIS_GREEN", -- "HIGH_VIS_GREEN" | "BRIGHT_GOLD" | "CUSTOM"
    groundTargetCustomHex = "22EB5E",
    groundTargetSizeBoost = true,

    gcdEnabled = true,
    gcdGap = 6,                     -- 0..20 px inward
    gcdStyle = "THIN",              -- "THIN" | "CRISP" | "THICK"
    gcdColorMode = "MATCH_RING",    -- "MATCH_RING" | "ACCENT" | "CLASS" | "CUSTOM"
    gcdCustomHex = "38BDF8",
    gcdOpacity = 0.85,              -- 0.10..1.00
    castArcEnabled = true,
    castGap = 4,                    -- 0..24 px outward
    castStyle = "THIN",             -- "THIN" | "CRISP" | "THICK"
    castColorMode = "MATCH_RING",   -- "MATCH_RING" | "ACCENT" | "CLASS" | "CUSTOM"
    castCustomHex = "F59E0B",
    castOpacity = 0.92,             -- 0.10..1.00
    castInterruptColorMode = "CRIMSON", -- "CRIMSON" | "BRIGHT_GOLD" | "CUSTOM"
    castInterruptCustomHex = "F23838",
    castShowIcon = false,
    castIconSize = 20,              -- 14..32 px
    castIconPos = "TOP",            -- "TOP" | "BOTTOM" | "LEFT" | "RIGHT" | "CENTER"
    castIconGap = 6,                -- 2..24 px
    castInstantFlash = false,

    showOpenWorld = true,
    showDelves = true,
    showDungeons = true,
    showRaids = true,
    showPvP = true,
    autoHideSpecial = true,

    -- Tab 3: Character Crosshair & Cursor Locator (Off by default)
    crosshairEnabled = false,
    crosshairShowCross = true,
    crosshairShowBrackets = false,
    crosshairShowCircle = false,
    crosshairShowDot = false,
    crosshairElementsMigrated = true,
    crosshairSize = 24,             -- 8..64
    crosshairThickness = 2,         -- 1..6
    crosshairGap = 6,               -- 0..20
    crosshairCircleRadius = 24,     -- 8..64
    crosshairCircleThickness = 2,   -- 1..5
    crosshairDotSize = 4,           -- 2..8
    crosshairOutline = true,
    crosshairOffsetX = 0,           -- -100..100
    crosshairOffsetY = 0,           -- -100..100
    crosshairVisibility = "ALWAYS", -- "ALWAYS" | "COMBAT_ONLY" | "INSTANCES_ONLY" | "COMBAT_IN_INSTANCES"
    crosshairOpacityOOC = 0.45,
    crosshairOpacityCombat = 0.90,
    crosshairColorMode = "ACCENT",
    crosshairCustomHex = "38BDF8",
    crosshairCombatTint = false,

    shakeToFind = false,
    shakeSensitivity = "MEDIUM",    -- "LOW" | "MEDIUM" | "HIGH"
    pingAfterMouseLook = false,
    mouseLookPingDuration = 0.65,   -- 0.30..1.50
    locatorModifier = "OFF",        -- "OFF" | "SHIFT" | "CTRL" | "ALT"
    locatorStyle = "PING",          -- "PING" | "SPOTLIGHT" | "CROSSHAIR"
    locatorScale = 1.00,            -- 0.60..1.60
    locatorColorMode = "MATCH_RING", -- "MATCH_RING" | "ACCENT" | "CLASS" | "HIGH_VIS_GREEN" | "BRIGHT_GOLD" | "CUSTOM"
    locatorCustomHex = "38BDF8",

    -- Tab 3: Pooled Cursor Trail & Smart Cursor Tooltips (Off by default)
    trailEnabled = false,
    trailStyle = "SMOOTH_DOTS",     -- "SMOOTH_DOTS" | "SOFT_MIST" | "CLASS_SPARKS" | "ARCANE_MOTES"
    trailDuration = 0.45,           -- 0.15..1.20
    trailSize = 14,                 -- 6..32
    trailDensity = 3,               -- 1..5
    trailOpacity = 0.75,            -- 0.10..1.00
    trailColorMode = "ACCENT",
    trailCustomHex = "38BDF8",
    trailCombatOnly = false,
    trailShowMouseLook = false,

    tooltipEnabled = false,
    tooltipOffsetX = 18,            -- -60..60
    tooltipOffsetY = -18,           -- -60..60
    tooltipEdgeFlip = true,
    tooltipCombatMode = "KEEP",     -- "KEEP" | "CORNER" | "HIDE_SHIFT"
}

local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

local function EnsureDB()
    if type(_G.DynamicCursorDB) ~= "table" then
        _G.DynamicCursorDB = {}
    end
    local db = _G.DynamicCursorDB
    -- Migrate legacy ringStyle values ("THIN"/"CRISP"/"THICK") to Solid Ring + thickness
    if db.ringStyle == "THIN" then
        db.ringStyle = "SOLID"
        if db.ringThickness == nil then db.ringThickness = 2 end
    elseif db.ringStyle == "CRISP" then
        db.ringStyle = "SOLID"
        if db.ringThickness == nil then db.ringThickness = 3 end
    elseif db.ringStyle == "THICK" then
        db.ringStyle = "SOLID"
        if db.ringThickness == nil then db.ringThickness = 4 end
    end
    -- Migrate legacy crosshairStyle values to modular Crosshair Elements toggles
    if db.crosshairElementsMigrated ~= true and type(db.crosshairStyle) == "string" then
        local st = db.crosshairStyle
        if st == "DOT" then
            db.crosshairShowCross = false; db.crosshairShowBrackets = false; db.crosshairShowCircle = false; db.crosshairShowDot = true
        elseif st == "CROSS_DOT" then
            db.crosshairShowCross = true; db.crosshairShowBrackets = false; db.crosshairShowCircle = false; db.crosshairShowDot = true
        elseif st == "BRACKETS" then
            db.crosshairShowCross = false; db.crosshairShowBrackets = true; db.crosshairShowCircle = false; db.crosshairShowDot = false
        elseif st == "CIRCLE_DOT" then
            db.crosshairShowCross = false; db.crosshairShowBrackets = false; db.crosshairShowCircle = true; db.crosshairShowDot = true
        else
            db.crosshairShowCross = true; db.crosshairShowBrackets = false; db.crosshairShowCircle = false; db.crosshairShowDot = false
        end
        db.crosshairElementsMigrated = true
    end
    CopyDefaults(DEFAULTS, db)
    return db
end

local RING_STYLE_TEXTURES = {
    SOLID = {
        MEDIA_BASE .. "Textures\\cursor_ring_solid_1.tga",
        MEDIA_BASE .. "Textures\\cursor_ring_solid_2.tga",
        MEDIA_BASE .. "Textures\\cursor_ring_solid_3.tga",
        MEDIA_BASE .. "Textures\\cursor_ring_solid_4.tga",
        MEDIA_BASE .. "Textures\\cursor_ring_solid_5.tga",
    },
    GLOW = {
        MEDIA_BASE .. "Textures\\cursor_ring_glow_1.tga",
        MEDIA_BASE .. "Textures\\cursor_ring_glow_2.tga",
        MEDIA_BASE .. "Textures\\cursor_ring_glow_3.tga",
        MEDIA_BASE .. "Textures\\cursor_ring_glow_4.tga",
        MEDIA_BASE .. "Textures\\cursor_ring_glow_5.tga",
    },
    DUAL = {
        MEDIA_BASE .. "Textures\\cursor_ring_dual_1.tga",
        MEDIA_BASE .. "Textures\\cursor_ring_dual_2.tga",
        MEDIA_BASE .. "Textures\\cursor_ring_dual_3.tga",
        MEDIA_BASE .. "Textures\\cursor_ring_dual_4.tga",
        MEDIA_BASE .. "Textures\\cursor_ring_dual_5.tga",
    },
}

local function GetRingTexture(style, thickness)
    local t = math.max(1, math.min(5, math.floor((tonumber(thickness) or 3) + 0.5)))
    local bucket = RING_STYLE_TEXTURES[style or "SOLID"] or RING_STYLE_TEXTURES.SOLID
    return bucket[t] or RING_STYLE_TEXTURES.SOLID[3]
end

local RING_TEXTURES = {
    CRISP = MEDIA_BASE .. "Textures\\cursor_ring_crisp.tga",
    THIN  = MEDIA_BASE .. "Textures\\cursor_ring_thin.tga",
    THICK = MEDIA_BASE .. "Textures\\cursor_ring_thick.tga",
    GLOW  = MEDIA_BASE .. "Textures\\cursor_ring_glow.tga",
    DUAL  = MEDIA_BASE .. "Textures\\cursor_ring_dual.tga",
}

local DOT_TEX   = MEDIA_BASE .. "Textures\\cursor_dot.tga"
local SPARK_TEX = MEDIA_BASE .. "Textures\\cursor_spark.tga"

-- ============================================================================
-- 2. RUNTIME ENGINES (CURSOR RING, GCD/CAST ARCS, CROSSHAIR, LOCATOR, TRAIL, TOOLTIPS)
-- ============================================================================
local SyncAllEngines

do
    local GCD_SPELL_ID = 61304
    local ringRoot, ringTex, ghostTex, pulseTex, ringDotBg, ringDotTex
    local gcdCooldown, castCooldown, castIconFrame, castIconTex
    local gcdContrastFrame, castContrastFrame
    local ringContrastActive = false
    local locatorRoot, locatorPingTex, locatorSpotTex, locatorCrossH, locatorCrossV
    local crosshairRoot
    local chLines = {}
    local chOutlines = {}
    local chDot, chDotBg, chCircle

    local TRAIL_POOL_SIZE = 48
    local trailRoot
    local trailPool = {}
    local trailHead = 1
    local trailSpawnAcc = 0

    local activeUpdateFrame = CreateFrame("Frame")
    local isMouseLooking = false
    local isGroundTargeting = false
    local lastCX, lastCY = 0, 0
    local lastVX, lastVY = 0, 0
    local shakeReversals = 0
    local shakeWindowEnd = 0
    local shakeLastRevTime = 0
    local shakeBurstEnd = 0
    local mouseLookPingEnd = 0
    local lastMoveTime = 0
    local idleFadeMult = 1.0
    local baseRingAlpha = 0.55
    local ringSizeScale = 1.0
    local pulseRemaining = 0
    local castFlashEnd = 0
    local instantFlashEnd = 0
    local isCastingNow = false
    local isChannelingNow = false
    local cachedDB = nil
    local cachedModuleDisabled = false
    local cachedActivityAllowed = true
    local lastRingX, lastRingY = nil, nil

    local function RefreshCachedModuleDisabled()
        cachedModuleDisabled = IsModuleDisabledInSuite("DynamicCursor") and true or false
        return cachedModuleDisabled
    end

    local function IsSpecialHideActive(db)
        if not db.autoHideSpecial then return false end
        if _G.C_PetBattles and type(_G.C_PetBattles.IsInBattle) == "function" then
            local okP, inPet = pcall(_G.C_PetBattles.IsInBattle)
            if okP and inPet == true then return true end
        end
        if type(_G.UnitInVehicle) == "function" then
            local okV, inVeh = pcall(_G.UnitInVehicle, "player")
            if okV and not _IsSecret(inVeh) and inVeh == true then return true end
        end
        if (_G.MovieFrame and _G.MovieFrame:IsShown()) or (_G.CinematicFrame and _G.CinematicFrame:IsShown()) then
            return true
        end
        return false
    end

    local function GetActivityBucket()
        local inInst, instType, diffID = false, "none", 0
        if type(_G.GetInstanceInfo) == "function" then
            local ok, _, it, dID = pcall(_G.GetInstanceInfo)
            if ok and not _IsSecret(it) then
                instType = it or "none"
                diffID = (not _IsSecret(dID) and tonumber(dID)) or 0
            end
        end
        if _G.IsInInstance then
            local okI, isIn, it2 = pcall(_G.IsInInstance)
            if okI and not _IsSecret(isIn) then
                inInst = (isIn == true)
                if (instType == "none" or instType == "") and not _IsSecret(it2) and type(it2) == "string" then
                    instType = it2
                end
            end
        end
        if diffID == 208 then return "DELVE" end
        if _G.C_DelvesUI and type(_G.C_DelvesUI.HasActiveDelve) == "function" then
            local okD, hasD = pcall(_G.C_DelvesUI.HasActiveDelve)
            if okD and not _IsSecret(hasD) and hasD == true then return "DELVE" end
        end
        if _G.C_PartyInfo and type(_G.C_PartyInfo.IsDelveInProgress) == "function" then
            local okP, inP = pcall(_G.C_PartyInfo.IsDelveInProgress)
            if okP and not _IsSecret(inP) and inP == true then return "DELVE" end
        end
        if _G.C_PartyInfo and type(_G.C_PartyInfo.IsDelveComplete) == "function" then
            local okC, isC = pcall(_G.C_PartyInfo.IsDelveComplete)
            if okC and not _IsSecret(isC) and isC == true then return "DELVE" end
        end
        if instType == "pvp" or instType == "arena" then return "PVP" end
        if instType == "raid" then return "RAID" end
        if instType == "party" then return "DUNGEON" end
        if instType == "scenario" then return "WORLD" end
        return "WORLD"
    end

    local function IsActivityAllowed(db)
        if IsSpecialHideActive(db) then return false end
        local b = GetActivityBucket()
        if b == "DELVE" then return db.showDelves ~= false end
        if b == "PVP" then return db.showPvP ~= false end
        if b == "RAID" then return db.showRaids ~= false end
        if b == "DUNGEON" then return db.showDungeons ~= false end
        return db.showOpenWorld ~= false
    end

    local function RefreshActivityAllowed(db)
        local d = db or cachedDB or EnsureDB()
        cachedDB = d
        cachedActivityAllowed = IsActivityAllowed(d) and true or false
        return cachedActivityAllowed
    end

    local function IsLocatorModifierHeld(db)
        local m = db.locatorModifier or "OFF"
        if m == "SHIFT" then return IsShiftKeyDown and IsShiftKeyDown() end
        if m == "CTRL" then return IsControlKeyDown and IsControlKeyDown() end
        if m == "ALT" then return IsAltKeyDown and IsAltKeyDown() end
        return false
    end

    local function EnsureRingFrames()
        if ringRoot then return end
        ringRoot = CreateFrame("Frame", "DynamicCursorRingFrame", UIParent)
        ringRoot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 0, 0)
        ringRoot:SetSize(80, 80)
        ringRoot:EnableMouse(false)
        ringRoot:SetFrameStrata("TOOLTIP")
        ringRoot:SetFrameLevel(90)
        ringRoot:Hide()

        ringRoot.contrastOuter = ringRoot:CreateTexture(nil, "BACKGROUND", nil, 1)
        ringRoot.contrastOuter:SetVertexColor(0.01, 0.01, 0.02, 0.92)
        ringRoot.contrastOuter:Hide()

        ringRoot.contrastInner = ringRoot:CreateTexture(nil, "BACKGROUND", nil, 1)
        ringRoot.contrastInner:SetVertexColor(0.01, 0.01, 0.02, 0.92)
        ringRoot.contrastInner:Hide()

        ringTex = ringRoot:CreateTexture(nil, "ARTWORK")
        ringTex:SetAllPoints()

        ghostTex = ringRoot:CreateTexture(nil, "BACKGROUND")
        ghostTex:SetAllPoints()
        ghostTex:Hide()

        pulseTex = ringRoot:CreateTexture(nil, "OVERLAY")
        pulseTex:SetPoint("CENTER")
        pulseTex:Hide()

        ringDotBg = ringRoot:CreateTexture(nil, "ARTWORK", nil, 6)
        ringDotBg:SetTexture(DOT_TEX)
        ringDotBg:SetVertexColor(0, 0, 0, 0.95)
        ringDotBg:SetPoint("CENTER")
        ringDotBg:Hide()

        ringDotTex = ringRoot:CreateTexture(nil, "OVERLAY", nil, 1)
        ringDotTex:SetTexture(DOT_TEX)
        ringDotTex:SetPoint("CENTER")
        ringDotTex:Hide()

        gcdCooldown = CreateFrame("Cooldown", nil, ringRoot, "CooldownFrameTemplate")
        gcdCooldown:SetAllPoints()
        gcdCooldown:SetFrameLevel(92)
        gcdCooldown:EnableMouse(false)
        gcdCooldown:SetDrawEdge(false)
        gcdCooldown:SetDrawBling(false)
        gcdCooldown:SetDrawSwipe(true)
        gcdCooldown:SetReverse(false)
        if gcdCooldown.SetHideCountdownNumbers then gcdCooldown:SetHideCountdownNumbers(true) end
        gcdCooldown.noCooldownCount = true
        gcdCooldown:Hide()

        gcdContrastFrame = CreateFrame("Frame", nil, ringRoot)
        gcdContrastFrame:SetFrameLevel(91)
        gcdContrastFrame:EnableMouse(false)
        gcdContrastFrame:SetAllPoints(gcdCooldown)
        gcdContrastFrame:Hide()
        gcdContrastFrame.outerTex = gcdContrastFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
        gcdContrastFrame.outerTex:SetVertexColor(0.01, 0.01, 0.02, 0.88)
        gcdContrastFrame.innerTex = gcdContrastFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
        gcdContrastFrame.innerTex:SetVertexColor(0.01, 0.01, 0.02, 0.88)

        gcdCooldown:HookScript("OnShow", function()
            if gcdContrastFrame then gcdContrastFrame:SetShown(ringContrastActive) end
        end)
        gcdCooldown:HookScript("OnHide", function()
            if gcdContrastFrame then gcdContrastFrame:Hide() end
        end)
        if gcdCooldown.HasScript and gcdCooldown:HasScript("OnCooldownDone") then
            gcdCooldown:HookScript("OnCooldownDone", function(self) self:Hide() end)
        end

        castCooldown = CreateFrame("Cooldown", nil, ringRoot, "CooldownFrameTemplate")
        castCooldown:SetPoint("TOPLEFT", ringRoot, "TOPLEFT", -4, 4)
        castCooldown:SetPoint("BOTTOMRIGHT", ringRoot, "BOTTOMRIGHT", 4, -4)
        castCooldown:SetFrameLevel(92)
        castCooldown:EnableMouse(false)
        castCooldown:SetDrawEdge(false)
        castCooldown:SetDrawBling(false)
        castCooldown:SetDrawSwipe(true)
        castCooldown:SetReverse(false)
        if castCooldown.SetHideCountdownNumbers then castCooldown:SetHideCountdownNumbers(true) end
        castCooldown.noCooldownCount = true
        castCooldown:Hide()

        castContrastFrame = CreateFrame("Frame", nil, ringRoot)
        castContrastFrame:SetFrameLevel(91)
        castContrastFrame:EnableMouse(false)
        castContrastFrame:SetAllPoints(castCooldown)
        castContrastFrame:Hide()
        castContrastFrame.outerTex = castContrastFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
        castContrastFrame.outerTex:SetVertexColor(0.01, 0.01, 0.02, 0.88)
        castContrastFrame.innerTex = castContrastFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
        castContrastFrame.innerTex:SetVertexColor(0.01, 0.01, 0.02, 0.88)

        castCooldown:HookScript("OnShow", function()
            if castContrastFrame then castContrastFrame:SetShown(ringContrastActive) end
        end)
        castCooldown:HookScript("OnHide", function()
            if castContrastFrame then castContrastFrame:Hide() end
        end)
        if castCooldown.HasScript and castCooldown:HasScript("OnCooldownDone") then
            castCooldown:HookScript("OnCooldownDone", function(self)
                if not isCastingNow and not isChannelingNow and castFlashEnd <= ((GetTime and GetTime()) or 0) then
                    self:Hide()
                end
            end)
        end

        castIconFrame = CreateFrame("Frame", nil, ringRoot, "BackdropTemplate")
        castIconFrame:SetSize(20, 20)
        castIconFrame:SetFrameLevel(95)
        castIconFrame:EnableMouse(false)
        castIconFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        castIconFrame:SetBackdropColor(0.043, 0.051, 0.071, 0.96)
        castIconFrame:SetBackdropBorderColor(0.220, 0.741, 0.973, 0.95)
        castIconFrame:SetPoint("BOTTOM", castCooldown, "TOP", 0, 6)
        castIconFrame:Hide()

        castIconTex = castIconFrame:CreateTexture(nil, "ARTWORK")
        castIconTex:SetPoint("TOPLEFT", castIconFrame, "TOPLEFT", 1, -1)
        castIconTex:SetPoint("BOTTOMRIGHT", castIconFrame, "BOTTOMRIGHT", -1, 1)
        castIconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    local function EnsureLocatorFrames()
        if locatorRoot then return end
        locatorRoot = CreateFrame("Frame", "DynamicCursorLocatorFrame", UIParent)
        locatorRoot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 0, 0)
        locatorRoot:SetSize(160, 160)
        locatorRoot:EnableMouse(false)
        locatorRoot:SetFrameStrata("TOOLTIP")
        locatorRoot:SetFrameLevel(95)
        locatorRoot:Hide()

        locatorPingTex = locatorRoot:CreateTexture(nil, "OVERLAY")
        locatorPingTex:SetPoint("CENTER")
        locatorPingTex:SetTexture(RING_TEXTURES.GLOW)
        locatorPingTex:Hide()

        locatorSpotTex = locatorRoot:CreateTexture(nil, "ARTWORK")
        locatorSpotTex:SetPoint("CENTER")
        locatorSpotTex:SetSize(120, 120)
        locatorSpotTex:SetTexture(DOT_TEX)
        locatorSpotTex:Hide()

        locatorCrossH = locatorRoot:CreateTexture(nil, "OVERLAY")
        locatorCrossH:SetColorTexture(1, 1, 1, 0.85)
        locatorCrossH:SetHeight(2)
        locatorCrossH:SetWidth(4000)
        locatorCrossH:SetPoint("CENTER")
        locatorCrossH:Hide()

        locatorCrossV = locatorRoot:CreateTexture(nil, "OVERLAY")
        locatorCrossV:SetColorTexture(1, 1, 1, 0.85)
        locatorCrossV:SetWidth(2)
        locatorCrossV:SetHeight(4000)
        locatorCrossV:SetPoint("CENTER")
        locatorCrossV:Hide()
    end

    local function EnsureCrosshairFrames()
        if crosshairRoot then return end
        crosshairRoot = CreateFrame("Frame", "DynamicCursorCrosshairFrame", UIParent)
        crosshairRoot:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        crosshairRoot:SetSize(64, 64)
        crosshairRoot:EnableMouse(false)
        crosshairRoot:SetFrameStrata("LOW")
        crosshairRoot:SetFrameLevel(20)
        crosshairRoot:Hide()

        for i = 1, 10 do
            local ol = crosshairRoot:CreateTexture(nil, "BACKGROUND")
            ol:SetColorTexture(0, 0, 0, 0.90)
            ol:Hide()
            chOutlines[i] = ol

            local ln = crosshairRoot:CreateTexture(nil, "ARTWORK")
            ln:SetColorTexture(1, 1, 1, 1)
            ln:Hide()
            chLines[i] = ln
        end

        chDotBg = crosshairRoot:CreateTexture(nil, "BACKGROUND")
        chDotBg:SetTexture(DOT_TEX)
        chDotBg:SetVertexColor(0, 0, 0, 0.90)
        chDotBg:SetPoint("CENTER")
        chDotBg:Hide()

        chDot = crosshairRoot:CreateTexture(nil, "OVERLAY")
        chDot:SetTexture(DOT_TEX)
        chDot:SetPoint("CENTER")
        chDot:Hide()

        chCircle = crosshairRoot:CreateTexture(nil, "ARTWORK")
        chCircle:SetTexture(RING_TEXTURES.THIN)
        chCircle:SetPoint("CENTER")
        chCircle:Hide()

        crosshairRoot.circleBgOuter = crosshairRoot:CreateTexture(nil, "BACKGROUND", nil, 1)
        crosshairRoot.circleBgOuter:SetVertexColor(0.01, 0.01, 0.02, 0.90)
        crosshairRoot.circleBgOuter:SetPoint("CENTER")
        crosshairRoot.circleBgOuter:Hide()

        crosshairRoot.circleBgInner = crosshairRoot:CreateTexture(nil, "BACKGROUND", nil, 1)
        crosshairRoot.circleBgInner:SetVertexColor(0.01, 0.01, 0.02, 0.90)
        crosshairRoot.circleBgInner:SetPoint("CENTER")
        crosshairRoot.circleBgInner:Hide()
    end

    local function EnsureTrailPool()
        if trailRoot then return end
        trailRoot = CreateFrame("Frame", "DynamicCursorTrailFrame", UIParent)
        trailRoot:SetAllPoints(UIParent)
        trailRoot:EnableMouse(false)
        trailRoot:SetFrameStrata("TOOLTIP")
        trailRoot:SetFrameLevel(85)
        for i = 1, TRAIL_POOL_SIZE do
            local tex = trailRoot:CreateTexture(nil, "ARTWORK")
            tex:SetTexture(DOT_TEX)
            tex:Hide()
            trailPool[i] = { tex = tex, active = false, born = 0, life = 0.45, size = 14, x = 0, y = 0, r = 1, g = 1, b = 1, a = 0.7 }
        end
    end

    local function UpdateCrosshairVisuals(db)
        if not db.crosshairEnabled or IsModuleDisabledInSuite("DynamicCursor") or IsSpecialHideActive(db) then
            if crosshairRoot then crosshairRoot:Hide() end
            return
        end
        local inCombat = (InCombatLockdown and InCombatLockdown()) and true or false
        local b = GetActivityBucket()
        local inInstance = (b == "DUNGEON" or b == "RAID" or b == "DELVE" or b == "PVP")
        local vis = db.crosshairVisibility or "ALWAYS"
        if vis == "COMBAT_ONLY" and not inCombat then
            if crosshairRoot then crosshairRoot:Hide() end
            return
        elseif vis == "INSTANCES_ONLY" and not inInstance then
            if crosshairRoot then crosshairRoot:Hide() end
            return
        elseif vis == "COMBAT_IN_INSTANCES" and (not inCombat or not inInstance) then
            if crosshairRoot then crosshairRoot:Hide() end
            return
        end

        EnsureCrosshairFrames()
        crosshairRoot:ClearAllPoints()
        crosshairRoot:SetPoint("CENTER", UIParent, "CENTER", tonumber(db.crosshairOffsetX) or 0, tonumber(db.crosshairOffsetY) or 0)

        local sz = tonumber(db.crosshairSize) or 24
        local th = tonumber(db.crosshairThickness) or 2
        local gap = tonumber(db.crosshairGap) or 6
        local outline = (db.crosshairOutline ~= false)
        local r, g, bCol = ResolveColorMode(db.crosshairColorMode or "ACCENT", db.crosshairCustomHex, db.crosshairCombatTint)
        local alpha = inCombat and (tonumber(db.crosshairOpacityCombat) or 0.90) or (tonumber(db.crosshairOpacityOOC) or 0.45)

        crosshairRoot:SetAlpha(alpha)
        for i = 1, 10 do
            chLines[i]:Hide()
            chOutlines[i]:Hide()
        end
        chDot:Hide(); chDotBg:Hide(); chCircle:Hide()
        if crosshairRoot.circleBgOuter then crosshairRoot.circleBgOuter:Hide() end
        if crosshairRoot.circleBgInner then crosshairRoot.circleBgInner:Hide() end

        local function PlaceBar(idx, w, h, pt, relPt, ox, oy)
            local ln = chLines[idx]
            ln:ClearAllPoints()
            ln:SetSize(w, h)
            ln:SetPoint(pt, crosshairRoot, relPt, ox, oy)
            ln:SetColorTexture(r, g, bCol, 1)
            ln:Show()
            if outline then
                local ol = chOutlines[idx]
                ol:ClearAllPoints()
                ol:SetSize(w + 2, h + 2)
                ol:SetPoint("CENTER", ln, "CENTER", 0, 0)
                ol:Show()
            end
        end

        if db.crosshairShowCross == true then
            local arm = math.max(3, math.floor((sz - gap * 2) * 0.5))
            PlaceBar(1, arm, th, "RIGHT",  "CENTER", -gap, 0)
            PlaceBar(2, arm, th, "LEFT",   "CENTER",  gap, 0)
            PlaceBar(3, th, arm, "BOTTOM", "CENTER", 0,  gap)
            PlaceBar(4, th, arm, "TOP",    "CENTER", 0, -gap)
        end

        if db.crosshairShowBrackets == true then
            local half = math.max(6, math.floor(sz * 0.5))
            local leg = math.max(4, math.floor(sz * 0.30))
            PlaceBar(5,  th, sz * 0.65, "RIGHT",       "CENTER", -half,  0)
            PlaceBar(6,  th, sz * 0.65, "LEFT",        "CENTER",  half,  0)
            PlaceBar(7,  leg, th,       "TOPLEFT",     "CENTER", -half,  sz * 0.325)
            PlaceBar(8,  leg, th,       "BOTTOMLEFT",  "CENTER", -half, -sz * 0.325)
            PlaceBar(9,  leg, th,       "TOPRIGHT",    "CENTER",  half,  sz * 0.325)
            PlaceBar(10, leg, th,       "BOTTOMRIGHT", "CENTER",  half, -sz * 0.325)
        end

        if db.crosshairShowCircle == true then
            local cRad = math.max(8, math.min(64, tonumber(db.crosshairCircleRadius) or 24))
            local cDiam = cRad * 2
            local cTex = GetRingTexture("SOLID", db.crosshairCircleThickness or 2)
            chCircle:SetTexture(cTex)
            chCircle:SetSize(cDiam, cDiam)
            chCircle:SetVertexColor(r, g, bCol, 1)
            chCircle:Show()
            if outline and crosshairRoot.circleBgOuter and crosshairRoot.circleBgInner then
                local cPad = ((db.crosshairCircleThickness or 2) <= 1 and cDiam < 44) and 1.2 or 1.8
                crosshairRoot.circleBgOuter:SetTexture(cTex)
                crosshairRoot.circleBgOuter:SetSize(cDiam + cPad * 2, cDiam + cPad * 2)
                crosshairRoot.circleBgOuter:SetVertexColor(0.01, 0.01, 0.02, 0.90)
                crosshairRoot.circleBgOuter:Show()
                crosshairRoot.circleBgInner:SetTexture(cTex)
                local innerDiam = math.max(8, cDiam - cPad * 2)
                crosshairRoot.circleBgInner:SetSize(innerDiam, innerDiam)
                crosshairRoot.circleBgInner:SetVertexColor(0.01, 0.01, 0.02, 0.90)
                crosshairRoot.circleBgInner:Show()
            end
        end

        if db.crosshairShowDot == true then
            local dSz = math.max(2, math.min(8, tonumber(db.crosshairDotSize) or 4))
            chDot:SetSize(dSz, dSz)
            chDot:SetVertexColor(r, g, bCol, 1)
            chDot:Show()
            if outline then
                chDotBg:SetSize(dSz + 2, dSz + 2)
                chDotBg:Show()
            end
        end

        crosshairRoot:Show()
    end

    local function UpdateRingAppearance(db)
        if not ringRoot then return end
        local aoeActive = (db.groundTargetHighlight ~= false) and isGroundTargeting
        if not aoeActive or db.groundTargetSizeBoost == false then
            ringSizeScale = 1.0
        end
        local baseRad = tonumber(db.ringRadius) or 24
        local radius = baseRad * ringSizeScale
        local diam = radius * 2
        ringRoot:SetSize(diam, diam)
        ringRoot:SetFrameStrata(db.ringStrata or "TOOLTIP")

        local texPath = GetRingTexture(db.ringStyle or "SOLID", db.ringThickness or 3)
        ringTex:SetTexture(texPath)
        ghostTex:SetTexture(texPath)
        pulseTex:SetTexture(RING_TEXTURES.THIN)

        ringContrastActive = (db.ringExtraContrast == true)
        if ringRoot.contrastOuter and ringRoot.contrastInner then
            if ringContrastActive and not isMouseLooking then
                local th = tonumber(db.ringThickness) or 3
                local pad = (th <= 1 and diam < 44) and 1.2 or 2
                local cAlpha = ((db.ringStyle or "SOLID") == "GLOW") and 0.72 or 0.92
                ringRoot.contrastOuter:SetTexture(texPath)
                ringRoot.contrastOuter:SetVertexColor(0.01, 0.01, 0.02, cAlpha)
                ringRoot.contrastOuter:ClearAllPoints()
                ringRoot.contrastOuter:SetPoint("TOPLEFT", ringRoot, "TOPLEFT", -pad, pad)
                ringRoot.contrastOuter:SetPoint("BOTTOMRIGHT", ringRoot, "BOTTOMRIGHT", pad, -pad)
                ringRoot.contrastOuter:Show()

                ringRoot.contrastInner:SetTexture(texPath)
                ringRoot.contrastInner:SetVertexColor(0.01, 0.01, 0.02, cAlpha)
                ringRoot.contrastInner:ClearAllPoints()
                ringRoot.contrastInner:SetPoint("TOPLEFT", ringRoot, "TOPLEFT", pad, -pad)
                ringRoot.contrastInner:SetPoint("BOTTOMRIGHT", ringRoot, "BOTTOMRIGHT", -pad, pad)
                ringRoot.contrastInner:Show()
            else
                ringRoot.contrastOuter:Hide()
                ringRoot.contrastInner:Hide()
            end
        end

        local baseR, baseG, baseB = ResolveColorMode(db.ringColorMode or "ACCENT", db.ringCustomHex, db.ringCombatShift)
        local r, g, b = baseR, baseG, baseB
        local inCombat = (InCombatLockdown and InCombatLockdown()) and true or false
        local alpha = inCombat and (tonumber(db.ringOpacityCombat) or 0.95) or (tonumber(db.ringOpacityOOC) or 0.55)

        if aoeActive then
            r, g, b = ResolveColorMode(db.groundTargetColorMode or "HIGH_VIS_GREEN", db.groundTargetCustomHex, false)
            alpha = 1.0
            idleFadeMult = 1.0
        elseif inCombat or (tonumber(db.ringIdleFade) or 0) <= 0 then
            idleFadeMult = 1.0
        end

        baseRingAlpha = alpha
        ringTex:SetVertexColor(r, g, b, 1)
        local ghostAlpha = math.max(0.10, math.min(1.00, tonumber(db.ringMouseLookOpacity) or 0.35))
        ghostTex:SetVertexColor(r, g, b, ghostAlpha)
        local pr, pg, pb = ResolveColorMode(db.ringClickPulseColorMode or "MATCH_RING", db.ringClickPulseCustomHex, false, r, g, b)
        pulseTex:SetVertexColor(pr, pg, pb, 0.90)
        ringRoot:SetAlpha(baseRingAlpha * idleFadeMult)

        if ringDotTex and ringDotBg then
            if db.ringCenterDot == true then
                local dotSz = math.max(2, math.min(8, tonumber(db.ringCenterDotSize) or 4))
                local dr, dg, dbCol = ResolveColorMode(db.ringCenterDotColorMode or "MATCH_RING", db.ringCenterDotCustomHex, false, r, g, b)
                ringDotTex:SetSize(dotSz, dotSz)
                ringDotTex:SetVertexColor(dr, dg, dbCol, 1)
                ringDotTex:Show()
                ringDotBg:SetSize(dotSz + 2, dotSz + 2)
                ringDotBg:Show()
            else
                ringDotTex:Hide()
                ringDotBg:Hide()
            end
        end

        if gcdCooldown then
            local gr, gg, gb = ResolveColorMode(db.gcdColorMode or "MATCH_RING", db.gcdCustomHex, false, baseR, baseG, baseB)
            local gcdAlpha = math.max(0.10, math.min(1.00, tonumber(db.gcdOpacity) or 0.85))
            local gcdTex = RING_TEXTURES[db.gcdStyle or "THIN"] or RING_TEXTURES.THIN
            gcdCooldown:SetSwipeTexture(gcdTex)
            gcdCooldown:SetSwipeColor(gr, gg, gb, gcdAlpha)
            local reqGap = math.max(0, math.min(20, tonumber(db.gcdGap) or 6))
            local maxInset = math.max(0, math.floor((diam - 10) * 0.5))
            local inset = math.min(reqGap, maxInset)
            gcdCooldown:ClearAllPoints()
            gcdCooldown:SetPoint("TOPLEFT", ringRoot, "TOPLEFT", inset, -inset)
            gcdCooldown:SetPoint("BOTTOMRIGHT", ringRoot, "BOTTOMRIGHT", -inset, inset)
            if gcdContrastFrame then
                local gPad = ((db.gcdStyle or "THIN") == "THIN") and 1.5 or 2
                gcdContrastFrame.outerTex:SetTexture(gcdTex)
                gcdContrastFrame.outerTex:SetVertexColor(0.01, 0.01, 0.02, 0.88)
                gcdContrastFrame.outerTex:ClearAllPoints()
                gcdContrastFrame.outerTex:SetPoint("TOPLEFT", gcdContrastFrame, "TOPLEFT", -gPad, gPad)
                gcdContrastFrame.outerTex:SetPoint("BOTTOMRIGHT", gcdContrastFrame, "BOTTOMRIGHT", gPad, -gPad)

                gcdContrastFrame.innerTex:SetTexture(gcdTex)
                gcdContrastFrame.innerTex:SetVertexColor(0.01, 0.01, 0.02, 0.88)
                gcdContrastFrame.innerTex:ClearAllPoints()
                gcdContrastFrame.innerTex:SetPoint("TOPLEFT", gcdContrastFrame, "TOPLEFT", gPad, -gPad)
                gcdContrastFrame.innerTex:SetPoint("BOTTOMRIGHT", gcdContrastFrame, "BOTTOMRIGHT", -gPad, gPad)
                gcdContrastFrame:SetShown(ringContrastActive and gcdCooldown:IsShown())
            end
        end

        local castR, castG, castB = ResolveColorMode(db.castColorMode or "MATCH_RING", db.castCustomHex, false, baseR, baseG, baseB)
        local isFlashingInt = (castFlashEnd > (GetTime and GetTime() or 0))
        local intR, intG, intB = ResolveColorMode(db.castInterruptColorMode or "CRIMSON", db.castInterruptCustomHex, false)
        if castCooldown then
            local castAlpha = math.max(0.10, math.min(1.00, tonumber(db.castOpacity) or 0.92))
            local castTex = RING_TEXTURES[db.castStyle or "THIN"] or RING_TEXTURES.THIN
            local castGap = math.max(0, math.min(24, tonumber(db.castGap) or 4))
            castCooldown:SetSwipeTexture(castTex)
            castCooldown:ClearAllPoints()
            castCooldown:SetPoint("TOPLEFT", ringRoot, "TOPLEFT", -castGap, castGap)
            castCooldown:SetPoint("BOTTOMRIGHT", ringRoot, "BOTTOMRIGHT", castGap, -castGap)
            if isFlashingInt then
                castCooldown:SetSwipeColor(intR, intG, intB, 0.95)
            else
                castCooldown:SetSwipeColor(castR, castG, castB, castAlpha)
            end
            if castContrastFrame then
                local cPad = ((db.castStyle or "THIN") == "THIN") and 1.5 or 2
                castContrastFrame.outerTex:SetTexture(castTex)
                castContrastFrame.outerTex:SetVertexColor(0.01, 0.01, 0.02, 0.88)
                castContrastFrame.outerTex:ClearAllPoints()
                castContrastFrame.outerTex:SetPoint("TOPLEFT", castContrastFrame, "TOPLEFT", -cPad, cPad)
                castContrastFrame.outerTex:SetPoint("BOTTOMRIGHT", castContrastFrame, "BOTTOMRIGHT", cPad, -cPad)

                castContrastFrame.innerTex:SetTexture(castTex)
                castContrastFrame.innerTex:SetVertexColor(0.01, 0.01, 0.02, 0.88)
                castContrastFrame.innerTex:ClearAllPoints()
                castContrastFrame.innerTex:SetPoint("TOPLEFT", castContrastFrame, "TOPLEFT", cPad, -cPad)
                castContrastFrame.innerTex:SetPoint("BOTTOMRIGHT", castContrastFrame, "BOTTOMRIGHT", -cPad, cPad)
                castContrastFrame:SetShown(ringContrastActive and castCooldown:IsShown())
            end
        end

        if castIconFrame then
            local iconSz = math.max(14, math.min(32, tonumber(db.castIconSize) or 20))
            local iconGap = math.max(2, math.min(24, tonumber(db.castIconGap) or 6))
            local pos = db.castIconPos or "TOP"
            local anchorTarget = (db.castArcEnabled ~= false and castCooldown) or ringRoot
            castIconFrame:SetSize(iconSz, iconSz)
            castIconFrame:ClearAllPoints()
            if pos == "BOTTOM" then
                castIconFrame:SetPoint("TOP", anchorTarget, "BOTTOM", 0, -iconGap)
            elseif pos == "LEFT" then
                castIconFrame:SetPoint("RIGHT", anchorTarget, "LEFT", -iconGap, 0)
            elseif pos == "RIGHT" then
                castIconFrame:SetPoint("LEFT", anchorTarget, "RIGHT", iconGap, 0)
            elseif pos == "CENTER" then
                castIconFrame:SetPoint("CENTER", ringRoot, "CENTER", 0, 0)
            else
                castIconFrame:SetPoint("BOTTOM", anchorTarget, "TOP", 0, iconGap)
            end
            if isFlashingInt then
                castIconFrame:SetBackdropBorderColor(intR, intG, intB, 0.98)
            else
                castIconFrame:SetBackdropBorderColor(castR, castG, castB, 0.95)
            end
        end
    end

    local function TriggerGCDCooldown()
        local db = EnsureDB()
        if not db.ringEnabled or not db.gcdEnabled or IsModuleDisabledInSuite("DynamicCursor") then return end
        if not ringRoot or not gcdCooldown then return end
        if _G.C_Spell and type(_G.C_Spell.GetSpellCooldownDuration) == "function" and type(gcdCooldown.SetCooldownFromDurationObject) == "function" then
            local okD, durObj = pcall(_G.C_Spell.GetSpellCooldownDuration, GCD_SPELL_ID)
            if okD and durObj then
                if type(durObj.IsZero) == "function" then
                    local okZ, isZ = pcall(durObj.IsZero, durObj)
                    if okZ and not _IsSecret(isZ) and isZ == true then
                        gcdCooldown:Hide()
                        return
                    end
                end
                local okSet = pcall(gcdCooldown.SetCooldownFromDurationObject, gcdCooldown, durObj)
                if okSet then
                    gcdCooldown:Show()
                    return
                end
            end
        end
        if _G.C_Spell and type(_G.C_Spell.GetSpellCooldown) == "function" then
            local okC, info = pcall(_G.C_Spell.GetSpellCooldown, GCD_SPELL_ID)
            if okC and type(info) == "table" and not _IsSecret(info.startTime) and not _IsSecret(info.duration) then
                local s = tonumber(info.startTime) or 0
                local d = tonumber(info.duration) or 0
                if s > 0 and d > 0 then
                    pcall(gcdCooldown.SetCooldown, gcdCooldown, s, d)
                    gcdCooldown:Show()
                else
                    gcdCooldown:Hide()
                end
            end
        end
    end

    local function UpdateCastArc(isChannel, isEmpower, isInterrupted)
        local db = EnsureDB()
        if not db.ringEnabled or not db.castArcEnabled or IsModuleDisabledInSuite("DynamicCursor") then
            if castCooldown then castCooldown:Hide() end
            if castIconFrame and instantFlashEnd <= 0 then castIconFrame:Hide() end
            return
        end
        if not ringRoot or not castCooldown then return end
        local now = (GetTime and GetTime()) or 0
        if isInterrupted then
            castFlashEnd = now + 0.35
            UpdateRingAppearance(db)
            C_Timer.After(0.36, function()
                if not isCastingNow and not isChannelingNow and castCooldown then
                    castCooldown:Hide()
                    if castIconFrame and instantFlashEnd <= 0 then castIconFrame:Hide() end
                end
            end)
            return
        end

        local durFn = isChannel and _G.UnitChannelDuration or _G.UnitCastingDuration
        if type(durFn) == "function" and type(castCooldown.SetCooldownFromDurationObject) == "function" then
            local okD, durObj = pcall(durFn, "player")
            if okD and durObj then
                local okSet = pcall(castCooldown.SetCooldownFromDurationObject, castCooldown, durObj)
                if okSet then
                    castCooldown:SetReverse(isChannel and true or false)
                    castCooldown:Show()
                    if db.castShowIcon and castIconFrame and castIconTex then
                        local infoFn = isChannel and _G.UnitChannelInfo or _G.UnitCastingInfo
                        if type(infoFn) == "function" then
                            local okI, _, _, texID = pcall(infoFn, "player")
                            if okI and not _IsSecret(texID) and texID then
                                instantFlashEnd = 0
                                castIconFrame:SetAlpha(1)
                                castIconTex:SetTexture(texID)
                                castIconFrame:Show()
                            end
                        end
                    elseif castIconFrame and instantFlashEnd <= 0 then
                        castIconFrame:Hide()
                    end
                    return
                end
            end
        end

        local infoFn = isChannel and _G.UnitChannelInfo or _G.UnitCastingInfo
        if type(infoFn) == "function" then
            local okI, name, _, texID, startMS, endMS = pcall(infoFn, "player")
            if okI and not _IsSecret(name) and name and not _IsSecret(startMS) and not _IsSecret(endMS) and startMS and endMS then
                local durSec = (endMS - startMS) / 1000
                if durSec > 0 then
                    pcall(castCooldown.SetCooldown, castCooldown, startMS / 1000, durSec)
                    castCooldown:SetReverse(isChannel and true or false)
                    castCooldown:Show()
                    if db.castShowIcon and castIconFrame and castIconTex and not _IsSecret(texID) and texID then
                        instantFlashEnd = 0
                        castIconFrame:SetAlpha(1)
                        castIconTex:SetTexture(texID)
                        castIconFrame:Show()
                    elseif castIconFrame and instantFlashEnd <= 0 then
                        castIconFrame:Hide()
                    end
                    return
                end
            end
        end
        castCooldown:Hide()
        if castIconFrame and instantFlashEnd <= 0 then castIconFrame:Hide() end
    end

    local function SpawnTrailNode(db, x, y, now)
        EnsureTrailPool()
        local node = trailPool[trailHead]
        trailHead = (trailHead % TRAIL_POOL_SIZE) + 1
        local style = db.trailStyle or "SMOOTH_DOTS"
        local texPath = (style == "CLASS_SPARKS") and SPARK_TEX or ((style == "SOFT_MIST" or style == "ARCANE_MOTES") and RING_TEXTURES.GLOW or DOT_TEX)
        local r, g, b = ResolveColorMode(db.trailColorMode or "ACCENT", db.trailCustomHex, false)
        if style == "ARCANE_MOTES" and (db.trailColorMode or "ACCENT") == "ACCENT" then
            r, g, b = 0.65, 0.45, 0.98
        end
        node.tex:SetTexture(texPath)
        node.tex:SetVertexColor(r, g, b, 1)
        node.size = tonumber(db.trailSize) or 14
        node.life = tonumber(db.trailDuration) or 0.45
        node.born = now
        node.x = x
        node.y = y
        node.a = tonumber(db.trailOpacity) or 0.75
        node.active = true
        node.tex:SetSize(node.size, node.size)
        node.tex:ClearAllPoints()
        node.tex:SetPoint("CENTER", trailRoot, "BOTTOMLEFT", x, y)
        node.tex:SetAlpha(node.a)
        node.tex:Show()
    end

    local function ClearTrailNodes()
        for i = 1, TRAIL_POOL_SIZE do
            local n = trailPool[i]
            if n and n.active then
                n.active = false
                n.tex:Hide()
            end
        end
    end

    local function OnCursorUpdate(_, elapsed)
        local db = cachedDB or EnsureDB()
        cachedDB = db
        local now = (GetTime and GetTime()) or 0
        local dt = math.max(0.004, math.min(0.10, tonumber(elapsed) or 0.016))
        local effScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        if effScale <= 0 then effScale = 1 end
        local rawX, rawY = 0, 0
        if type(_G.GetCursorPosition) == "function" then
            rawX, rawY = _G.GetCursorPosition()
        end
        local cx, cy = rawX / effScale, rawY / effScale
        local dx, dy = cx - lastCX, cy - lastCY
        local moved = (dx ~= 0 or dy ~= 0)
        if moved then
            lastMoveTime = now
            if idleFadeMult < 1.0 then
                idleFadeMult = 1.0
                if ringRoot then ringRoot:SetAlpha(baseRingAlpha) end
            end
        end

        -- FPS-Normalised Shake-to-Find detection
        if db.shakeToFind == true and not isMouseLooking and moved then
            local vx, vy = dx / dt, dy / dt
            local sens = db.shakeSensitivity or "MEDIUM"
            local minSpeed, reqRevs, winSec = 1100, 4, 0.55
            if sens == "LOW" then
                minSpeed, reqRevs, winSec = 1600, 4, 0.50
            elseif sens == "HIGH" then
                minSpeed, reqRevs, winSec = 700, 3, 0.60
            end
            local halfSpd = minSpeed * 0.5
            local revX = (math.abs(vx) >= halfSpd and math.abs(lastVX) >= halfSpd and vx * lastVX < 0)
            local revY = (math.abs(vy) >= halfSpd and math.abs(lastVY) >= halfSpd and vy * lastVY < 0)
            if (revX or revY) and (now - shakeLastRevTime) >= 0.045 then
                shakeLastRevTime = now
                if now > shakeWindowEnd then
                    shakeReversals = 1
                    shakeWindowEnd = now + winSec
                else
                    shakeReversals = shakeReversals + 1
                end
                if shakeReversals >= reqRevs then
                    shakeBurstEnd = now + 1.15
                    shakeReversals = 0
                end
            end
            if math.abs(vx) >= halfSpd then
                lastVX = vx
            elseif now > shakeWindowEnd and (now - shakeLastRevTime) > 0.25 then
                lastVX = 0
            end
            if math.abs(vy) >= halfSpd then
                lastVY = vy
            elseif now > shakeWindowEnd and (now - shakeLastRevTime) > 0.25 then
                lastVY = 0
            end
        end
        lastCX, lastCY = cx, cy

        -- Main Cursor Ring (uses event-cached activity state & CURRENT_SPELL_CAST_CHANGED ground targeting)
        local allowed = cachedActivityAllowed
        if db.ringEnabled and allowed and ringRoot then
            local aoeActive = (db.groundTargetHighlight ~= false) and isGroundTargeting
            if aoeActive and db.groundTargetSizeBoost ~= false then
                if ringSizeScale < 1.20 then
                    ringSizeScale = math.min(1.20, ringSizeScale + dt * 1.8)
                    local diam = (tonumber(db.ringRadius) or 24) * ringSizeScale * 2
                    ringRoot:SetSize(diam, diam)
                end
            elseif ringSizeScale ~= 1.0 then
                ringSizeScale = 1.0
                UpdateRingAppearance(db)
            end

            local fadeDelay = tonumber(db.ringIdleFade) or 0
            local inCombat = (InCombatLockdown and InCombatLockdown()) and true or false
            if fadeDelay > 0 and not inCombat and not aoeActive and not isMouseLooking then
                if lastMoveTime <= 0 then lastMoveTime = now end
                local idleFor = now - lastMoveTime
                if idleFor > fadeDelay then
                    local fadeProg = math.min(1.0, (idleFor - fadeDelay) / 0.35)
                    local targetMult = 1.0 - fadeProg
                    if math.abs(targetMult - idleFadeMult) > 0.005 or (targetMult == 0 and idleFadeMult ~= 0) then
                        idleFadeMult = targetMult
                        ringRoot:SetAlpha(baseRingAlpha * idleFadeMult)
                    end
                end
            elseif idleFadeMult < 1.0 then
                idleFadeMult = 1.0
                ringRoot:SetAlpha(baseRingAlpha)
            end

            if isMouseLooking then
                if db.ringKeepMouseLook then
                    if ringTex:IsShown() then ringTex:Hide() end
                    if ringRoot.contrastOuter and ringRoot.contrastOuter:IsShown() then ringRoot.contrastOuter:Hide() end
                    if ringRoot.contrastInner and ringRoot.contrastInner:IsShown() then ringRoot.contrastInner:Hide() end
                    if not ghostTex:IsShown() then ghostTex:Show() end
                    if not ringRoot:IsShown() then ringRoot:Show() end
                else
                    if ringRoot:IsShown() then ringRoot:Hide() end
                end
            else
                if not ringTex:IsShown() then ringTex:Show() end
                if ringRoot.contrastOuter and ringRoot.contrastOuter:IsShown() ~= ringContrastActive then
                    ringRoot.contrastOuter:SetShown(ringContrastActive)
                end
                if ringRoot.contrastInner and ringRoot.contrastInner:IsShown() ~= ringContrastActive then
                    ringRoot.contrastInner:SetShown(ringContrastActive)
                end
                if ghostTex:IsShown() then ghostTex:Hide() end
                local rox = tonumber(db.ringOffsetX) or 0
                local roy = tonumber(db.ringOffsetY) or 0
                local targetX, targetY = cx + rox, cy + roy
                if moved or targetX ~= lastRingX or targetY ~= lastRingY then
                    lastRingX, lastRingY = targetX, targetY
                    ringRoot:ClearAllPoints()
                    ringRoot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", targetX, targetY)
                end
                if not ringRoot:IsShown() then ringRoot:Show() end
            end

            if pulseRemaining > 0 and pulseTex then
                pulseRemaining = pulseRemaining - elapsed
                if pulseRemaining <= 0 then
                    pulseTex:Hide()
                else
                    local pProg = 1.0 - (pulseRemaining / 0.25)
                    local maxScale = math.max(1.25, math.min(2.50, tonumber(db.ringClickPulseScale) or 1.75))
                    local rad = (tonumber(db.ringRadius) or 24) * (1.0 + pProg * (maxScale - 1.0))
                    pulseTex:SetSize(rad * 2, rad * 2)
                    pulseTex:SetAlpha((1.0 - pProg) * 0.85)
                    pulseTex:Show()
                end
            end

            if instantFlashEnd > 0 and castIconFrame then
                if isCastingNow or isChannelingNow then
                    instantFlashEnd = 0
                    castIconFrame:SetAlpha(1)
                elseif now >= instantFlashEnd then
                    instantFlashEnd = 0
                    castIconFrame:SetAlpha(1)
                    castIconFrame:Hide()
                else
                    local rem = (instantFlashEnd - now) / 0.55
                    castIconFrame:SetAlpha(math.max(0, math.min(1, rem)))
                end
            end
        elseif ringRoot and ringRoot:IsShown() then
            ringRoot:Hide()
        end

        -- Find My Cursor / Modifier Locator / Ping After Mouse-Look
        local showLocator = (now < shakeBurstEnd) or (now < mouseLookPingEnd) or IsLocatorModifierHeld(db)
        if showLocator and allowed and not isMouseLooking then
            EnsureLocatorFrames()
            locatorRoot:ClearAllPoints()
            locatorRoot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
            local baseR, baseG, baseB = ResolveColorMode(db.ringColorMode or "ACCENT", db.ringCustomHex, false)
            local r, g, b = ResolveColorMode(db.locatorColorMode or "MATCH_RING", db.locatorCustomHex, false, baseR, baseG, baseB)
            local lStyle = db.locatorStyle or "PING"
            local lScale = math.max(0.60, math.min(1.60, tonumber(db.locatorScale) or 1.0))
            locatorPingTex:Hide(); locatorSpotTex:Hide(); locatorCrossH:Hide(); locatorCrossV:Hide()
            if lStyle == "PING" then
                local phase = (now * 2.2) % 1.0
                local pSize = (48 + phase * 110) * lScale
                locatorPingTex:SetSize(pSize, pSize)
                locatorPingTex:SetVertexColor(r, g, b, (1.0 - phase) * 0.90)
                locatorPingTex:Show()
            elseif lStyle == "SPOTLIGHT" then
                locatorSpotTex:SetSize(120 * lScale, 120 * lScale)
                locatorSpotTex:SetVertexColor(r, g, b, 0.32)
                locatorSpotTex:Show()
            else
                local cw = math.max(1, math.floor(2 * lScale + 0.5))
                locatorCrossH:SetHeight(cw)
                locatorCrossV:SetWidth(cw)
                locatorCrossH:SetColorTexture(r, g, b, 0.75)
                locatorCrossV:SetColorTexture(r, g, b, 0.75)
                locatorCrossH:Show()
                locatorCrossV:Show()
            end
            locatorRoot:Show()
        elseif locatorRoot and locatorRoot:IsShown() then
            locatorRoot:Hide()
        end

        -- Pooled Cursor Trail
        local anyTrailAlive = false
        if db.trailEnabled and allowed then
            local inCombat = (InCombatLockdown and InCombatLockdown()) and true or false
            local canSpawn = (not db.trailCombatOnly or inCombat) and (not isMouseLooking or db.trailShowMouseLook)
            if canSpawn and moved then
                local dist = math.sqrt(dx * dx + dy * dy)
                local threshold = math.max(3, 18 - (tonumber(db.trailDensity) or 3) * 3)
                trailSpawnAcc = trailSpawnAcc + dist
                if trailSpawnAcc >= threshold then
                    trailSpawnAcc = 0
                    SpawnTrailNode(db, cx, cy, now)
                end
            end
            for i = 1, TRAIL_POOL_SIZE do
                local n = trailPool[i]
                if n and n.active then
                    local age = now - n.born
                    if age >= n.life then
                        n.active = false
                        n.tex:Hide()
                    else
                        anyTrailAlive = true
                        local t = 1.0 - (age / n.life)
                        n.tex:SetAlpha(n.a * t)
                        local s = math.max(2, n.size * (0.35 + 0.65 * t))
                        n.tex:SetSize(s, s)
                    end
                end
            end
        elseif trailRoot then
            ClearTrailNodes()
        end

        if not anyTrailAlive and not db.ringEnabled and not db.trailEnabled and not db.shakeToFind
            and (db.locatorModifier or "OFF") == "OFF" and now >= shakeBurstEnd and now >= mouseLookPingEnd then
            activeUpdateFrame:SetScript("OnUpdate", nil)
        end
    end

    local function RepositionSmartTooltip(tooltip, db)
        local rawScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local effScale = (not _IsSecret(rawScale) and tonumber(rawScale)) or 1
        if effScale <= 0 then effScale = 1 end
        local rawX, rawY = _G.GetCursorPosition()
        if _IsSecret(rawX) or _IsSecret(rawY) then return end
        local cx, cy = (tonumber(rawX) or 0) / effScale, (tonumber(rawY) or 0) / effScale
        local ox = tonumber(db.tooltipOffsetX) or 18
        local oy = tonumber(db.tooltipOffsetY) or -18
        local rawSW = (_G.GetScreenWidth and _G.GetScreenWidth()) or 1920
        local rawSH = (_G.GetScreenHeight and _G.GetScreenHeight()) or 1080
        local sw = (not _IsSecret(rawSW) and tonumber(rawSW)) or 1920
        local sh = (not _IsSecret(rawSH) and tonumber(rawSH)) or 1080
        local pt = "TOPLEFT"
        if db.tooltipEdgeFlip ~= false then
            local flipX = (cx > sw * 0.72)
            local flipY = (cy < sh * 0.25)
            if flipX and flipY then
                pt = "BOTTOMRIGHT"; ox = -math.abs(ox); oy = math.abs(oy)
            elseif flipX then
                pt = "TOPRIGHT"; ox = -math.abs(ox)
            elseif flipY then
                pt = "BOTTOMLEFT"; oy = math.abs(oy)
            end
        end
        tooltip:ClearAllPoints()
        tooltip:SetPoint(pt, UIParent, "BOTTOMLEFT", cx + ox, cy + oy)
    end

    local smartTooltipHooked = false
    local function EnsureSmartTooltipHook()
        RefreshCachedModuleDisabled()
        cachedDB = cachedDB or EnsureDB()
        if smartTooltipHooked or type(_G.hooksecurefunc) ~= "function" then return end
        smartTooltipHooked = true
        _G.hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip)
            if cachedModuleDisabled then return end
            local db = cachedDB
            if not db then
                db = EnsureDB()
                cachedDB = db
            end
            if not db.tooltipEnabled then return end
            if not tooltip or _IsSecret(tooltip) or tooltip ~= _G.GameTooltip then return end
            if type(tooltip.IsForbidden) == "function" then
                local okF, forb = pcall(tooltip.IsForbidden, tooltip)
                if not okF or _IsSecret(forb) or forb then return end
            end
            local inCombat = (InCombatLockdown and InCombatLockdown()) and true or false
            local cMode = db.tooltipCombatMode or "KEEP"
            if inCombat then
                if cMode == "CORNER" then
                    return
                elseif cMode == "HIDE_SHIFT" and not (IsShiftKeyDown and IsShiftKeyDown()) then
                    pcall(tooltip.Hide, tooltip)
                    return
                end
            end
            if type(_G.GetCursorPosition) ~= "function" then return end
            pcall(RepositionSmartTooltip, tooltip, db)
        end)
    end

    SyncAllEngines = function()
        local db = EnsureDB()
        cachedDB = db
        lastRingX, lastRingY = nil, nil
        local disabled = RefreshCachedModuleDisabled()
        if disabled then
            cachedActivityAllowed = false
            if ringRoot then ringRoot:Hide() end
            if locatorRoot then locatorRoot:Hide() end
            if crosshairRoot then crosshairRoot:Hide() end
            ClearTrailNodes()
            activeUpdateFrame:SetScript("OnUpdate", nil)
            return
        end

        if db.ringEnabled then
            EnsureRingFrames()
            UpdateRingAppearance(db)
            if not db.gcdEnabled and gcdCooldown then gcdCooldown:Hide() end
            if not db.castArcEnabled and castCooldown then
                castCooldown:Hide()
            end
            if not db.castShowIcon and castIconFrame then
                instantFlashEnd = 0
                castIconFrame:Hide()
            end
        elseif ringRoot and ringRoot:IsShown() then
            ringRoot:Hide()
        end

        if db.trailEnabled then
            EnsureTrailPool()
        else
            ClearTrailNodes()
        end

        UpdateCrosshairVisuals(db)
        if db.tooltipEnabled then
            EnsureSmartTooltipHook()
        end

        local now = (GetTime and GetTime()) or 0
        local allowed = RefreshActivityAllowed(db)
        local needsUpdate = (db.ringEnabled == true) or (db.trailEnabled == true) or (db.shakeToFind == true)
            or ((db.locatorModifier or "OFF") ~= "OFF") or (now < mouseLookPingEnd) or (now < shakeBurstEnd)
        if needsUpdate and allowed then
            activeUpdateFrame:SetScript("OnUpdate", OnCursorUpdate)
        else
            activeUpdateFrame:SetScript("OnUpdate", nil)
            if ringRoot then ringRoot:Hide() end
            if locatorRoot then locatorRoot:Hide() end
            ClearTrailNodes()
        end
    end
    DynamicCursor.SyncAllEngines = SyncAllEngines

    local function HandleMouseLookStop()
        local wasLooking = isMouseLooking
        isMouseLooking = false
        local now = (GetTime and GetTime()) or 0
        lastMoveTime = now
        if idleFadeMult < 1.0 and ringRoot then
            idleFadeMult = 1.0
            ringRoot:SetAlpha(baseRingAlpha)
        end
        if IsModuleDisabledInSuite("DynamicCursor") then return end
        local db = cachedDB or EnsureDB()
        cachedDB = db
        if db.pingAfterMouseLook == true and (wasLooking or now > mouseLookPingEnd - 0.55) and cachedActivityAllowed then
            local pingDur = math.max(0.30, math.min(1.50, tonumber(db.mouseLookPingDuration) or 0.65))
            mouseLookPingEnd = now + pingDur
            activeUpdateFrame:SetScript("OnUpdate", OnCursorUpdate)
        end
    end

    local evFrame = CreateFrame("Frame")
    SafeRegisterEvent(evFrame, "PLAYER_LOGIN")
    SafeRegisterEvent(evFrame, "PLAYER_ENTERING_WORLD")
    SafeRegisterEvent(evFrame, "ZONE_CHANGED_NEW_AREA")
    SafeRegisterEvent(evFrame, "PLAYER_REGEN_DISABLED")
    SafeRegisterEvent(evFrame, "PLAYER_REGEN_ENABLED")
    SafeRegisterEvent(evFrame, "MODIFIER_STATE_CHANGED")
    SafeRegisterEvent(evFrame, "GLOBAL_MOUSE_DOWN")
    SafeRegisterEvent(evFrame, "PLAYER_STARTED_LOOKING")
    SafeRegisterEvent(evFrame, "PLAYER_STOPPED_LOOKING")
    SafeRegisterEvent(evFrame, "PET_BATTLE_OPENING_START")
    SafeRegisterEvent(evFrame, "PET_BATTLE_CLOSE")
    SafeRegisterEvent(evFrame, "UNIT_ENTERED_VEHICLE")
    SafeRegisterEvent(evFrame, "UNIT_EXITED_VEHICLE")
    SafeRegisterEvent(evFrame, "CINEMATIC_START")
    SafeRegisterEvent(evFrame, "CINEMATIC_STOP")
    SafeRegisterEvent(evFrame, "PLAY_MOVIE")
    SafeRegisterEvent(evFrame, "STOP_MOVIE")
    SafeRegisterEvent(evFrame, "UNIT_SPELLCAST_SUCCEEDED")
    SafeRegisterEvent(evFrame, "UNIT_SPELLCAST_START")
    SafeRegisterEvent(evFrame, "UNIT_SPELLCAST_STOP")
    SafeRegisterEvent(evFrame, "UNIT_SPELLCAST_FAILED")
    SafeRegisterEvent(evFrame, "UNIT_SPELLCAST_INTERRUPTED")
    SafeRegisterEvent(evFrame, "UNIT_SPELLCAST_CHANNEL_START")
    SafeRegisterEvent(evFrame, "UNIT_SPELLCAST_CHANNEL_STOP")
    SafeRegisterEvent(evFrame, "UNIT_SPELLCAST_EMPOWER_START")
    SafeRegisterEvent(evFrame, "UNIT_SPELLCAST_EMPOWER_STOP")
    SafeRegisterEvent(evFrame, "CURRENT_SPELL_CAST_CHANGED")

    evFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
        if event == "PLAYER_LOGIN" then
            EnsureDB()
            if RefreshCachedModuleDisabled() then
                if _G.DynamicSuite and _G.DynamicSuite.modules then
                    if _G.DynamicSuite.modules["cursor"] then _G.DynamicSuite.modules["cursor"]._disabledAtStartup = true end
                    if _G.DynamicSuite.modules["DynamicCursor"] then _G.DynamicSuite.modules["DynamicCursor"]._disabledAtStartup = true end
                end
                cachedActivityAllowed = false
                if ringRoot then ringRoot:Hide() end
                if locatorRoot then locatorRoot:Hide() end
                if crosshairRoot then crosshairRoot:Hide() end
                ClearTrailNodes()
                activeUpdateFrame:SetScript("OnUpdate", nil)
                evFrame:UnregisterAllEvents()
                return
            end
            if type(_G.hooksecurefunc) == "function" then
                if _G.MouselookStart then
                    _G.hooksecurefunc("MouselookStart", function() isMouseLooking = true end)
                end
                if _G.MouselookStop then
                    _G.hooksecurefunc("MouselookStop", HandleMouseLookStop)
                end
            end
            SyncAllEngines()
            return
        end
        if IsModuleDisabledInSuite("DynamicCursor") then
            SyncAllEngines()
            evFrame:UnregisterAllEvents()
            return
        end
        local db = EnsureDB()

        if event == "PLAYER_STARTED_LOOKING" then
            isMouseLooking = true
        elseif event == "PLAYER_STOPPED_LOOKING" then
            HandleMouseLookStop()
        elseif event == "GLOBAL_MOUSE_DOWN" then
            if db.ringEnabled and db.ringClickPulse and not isMouseLooking then
                pulseRemaining = 0.25
            end
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            if not _IsSecret(arg1) and arg1 == "player" then
                TriggerGCDCooldown()
                if db.ringEnabled and db.castShowIcon and db.castInstantFlash and not isCastingNow and not isChannelingNow and castIconFrame and castIconTex then
                    if not _IsSecret(arg3) and type(arg3) == "number" and arg3 > 0 then
                        local texID = nil
                        if _G.C_Spell and type(_G.C_Spell.GetSpellTexture) == "function" then
                            local okT, t = pcall(_G.C_Spell.GetSpellTexture, arg3)
                            if okT and not _IsSecret(t) and t then texID = t end
                        elseif type(_G.GetSpellTexture) == "function" then
                            local okT, t = pcall(_G.GetSpellTexture, arg3)
                            if okT and not _IsSecret(t) and t then texID = t end
                        end
                        if texID then
                            castIconTex:SetTexture(texID)
                            castIconFrame:SetAlpha(1)
                            castIconFrame:Show()
                            instantFlashEnd = ((GetTime and GetTime()) or 0) + 0.55
                        end
                    end
                end
            end
        elseif event == "UNIT_SPELLCAST_START" then
            if not _IsSecret(arg1) and arg1 == "player" then
                isCastingNow = true; isChannelingNow = false
                TriggerGCDCooldown()
                UpdateCastArc(false, false, false)
            end
        elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
            if not _IsSecret(arg1) and arg1 == "player" then
                isChannelingNow = true; isCastingNow = false
                TriggerGCDCooldown()
                UpdateCastArc(true, false, false)
            end
        elseif event == "UNIT_SPELLCAST_EMPOWER_START" then
            if not _IsSecret(arg1) and arg1 == "player" then
                isChannelingNow = true; isCastingNow = false
                TriggerGCDCooldown()
                UpdateCastArc(false, true, false)
            end
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
            if not _IsSecret(arg1) and arg1 == "player" then
                isCastingNow = false; isChannelingNow = false
                UpdateCastArc(false, false, true)
            end
        elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
            or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
            if not _IsSecret(arg1) and arg1 == "player" then
                isCastingNow = false; isChannelingNow = false
                if castCooldown then castCooldown:Hide() end
                if castIconFrame and instantFlashEnd <= 0 then castIconFrame:Hide() end
            end
        elseif event == "CURRENT_SPELL_CAST_CHANGED" then
            if db.ringEnabled and db.groundTargetHighlight ~= false and type(_G.SpellIsTargeting) == "function" then
                local okT, nowT = pcall(_G.SpellIsTargeting)
                local targeting = (okT and nowT == true) and true or false
                if targeting ~= isGroundTargeting then
                    isGroundTargeting = targeting
                    if not targeting then
                        ringSizeScale = 1.0
                    else
                        lastMoveTime = (GetTime and GetTime()) or 0
                        idleFadeMult = 1.0
                    end
                    if ringRoot then UpdateRingAppearance(db) end
                end
            elseif isGroundTargeting then
                isGroundTargeting = false
                ringSizeScale = 1.0
                if ringRoot then UpdateRingAppearance(db) end
            end
        elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            if event == "PLAYER_REGEN_DISABLED" then
                lastMoveTime = (GetTime and GetTime()) or 0
                idleFadeMult = 1.0
            end
            if ringRoot then UpdateRingAppearance(db) end
            UpdateCrosshairVisuals(db)
        elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA"
            or event == "PET_BATTLE_OPENING_START" or event == "PET_BATTLE_CLOSE"
            or event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE"
            or event == "CINEMATIC_START" or event == "CINEMATIC_STOP"
            or event == "PLAY_MOVIE" or event == "STOP_MOVIE" then
            SyncAllEngines()
        end
    end)
end

-- ============================================================================
-- 3. PRESETS & RESET
-- ============================================================================
function DynamicCursor:ApplyPreset(presetKey)
    local db = EnsureDB()
    if presetKey == "CLEAN_RAID" then
        db.ringEnabled = true
        db.ringStyle = "SOLID"
        db.ringThickness = 3
        db.ringExtraContrast = false
        db.ringRadius = 24
        db.ringOpacityOOC = 0.45
        db.ringOpacityCombat = 0.90
        db.ringColorMode = "ACCENT"
        db.ringCombatShift = false
        db.gcdEnabled = true
        db.gcdGap = 6
        db.castArcEnabled = true
        db.castGap = 4
        db.castShowIcon = false
        db.castInstantFlash = false
        db.crosshairEnabled = false
        db.trailEnabled = false
        PrintMsg("Applied preset: Clean Raid.")
    elseif presetKey == "HIGH_VIS" then
        db.ringEnabled = true
        db.ringStyle = "DUAL"
        db.ringThickness = 3
        db.ringExtraContrast = true
        db.ringRadius = 24
        db.ringOpacityOOC = 0.75
        db.ringOpacityCombat = 1.00
        db.ringColorMode = "HIGH_VIS_GREEN"
        db.ringCombatShift = true
        db.gcdEnabled = true
        db.gcdGap = 6
        db.castArcEnabled = true
        db.castGap = 4
        db.castShowIcon = true
        db.crosshairEnabled = true
        db.crosshairShowCross = true
        db.crosshairShowBrackets = false
        db.crosshairShowCircle = false
        db.crosshairShowDot = true
        db.crosshairElementsMigrated = true
        db.crosshairSize = 26
        db.crosshairDotSize = 4
        db.crosshairOutline = true
        db.shakeToFind = true
        db.trailEnabled = true
        db.trailStyle = "SMOOTH_DOTS"
        db.trailSize = 10
        db.trailDensity = 4
        PrintMsg("Applied preset: High-Visibility.")
    elseif presetKey == "MINIMALIST" then
        db.ringEnabled = true
        db.ringStyle = "SOLID"
        db.ringThickness = 2
        db.ringExtraContrast = false
        db.ringRadius = 20
        db.ringOpacityOOC = 0.35
        db.ringOpacityCombat = 0.75
        db.ringColorMode = "CLASS"
        db.gcdEnabled = true
        db.gcdGap = 6
        db.castArcEnabled = false
        db.castGap = 4
        db.castShowIcon = false
        db.castInstantFlash = false
        db.crosshairEnabled = false
        db.trailEnabled = false
        PrintMsg("Applied preset: Minimalist.")
    elseif presetKey == "FULL_TELEMETRY" then
        db.ringEnabled = true
        db.ringStyle = "GLOW"
        db.ringThickness = 3
        db.ringExtraContrast = false
        db.ringRadius = 26
        db.ringOpacityOOC = 0.65
        db.ringOpacityCombat = 0.95
        db.ringColorMode = "ACCENT"
        db.ringClickPulse = true
        db.gcdEnabled = true
        db.gcdGap = 6
        db.castArcEnabled = true
        db.castGap = 4
        db.castShowIcon = true
        db.castInstantFlash = true
        db.crosshairEnabled = true
        db.crosshairShowCross = false
        db.crosshairShowBrackets = true
        db.crosshairShowCircle = false
        db.crosshairShowDot = false
        db.crosshairElementsMigrated = true
        db.crosshairSize = 28
        db.shakeToFind = true
        db.locatorModifier = "SHIFT"
        db.trailEnabled = true
        db.trailStyle = "CLASS_SPARKS"
        db.trailDensity = 4
        PrintMsg("Applied preset: All Overlays.")
    end
    SyncAllEngines()
    if self.RefreshWorkspaceUI then self:RefreshWorkspaceUI() end
end

local function ResetCursorModuleDefaults()
    _G.DynamicCursorDB = CopyDefaults(DEFAULTS, {})
    SyncAllEngines()
    if DynamicCursor.RefreshWorkspaceUI then DynamicCursor:RefreshWorkspaceUI(true) end
    PrintMsg("Restored all DynamicCursor settings to defaults.")
end
DynamicCursor.ResetModuleDefaults = ResetCursorModuleDefaults

-- ============================================================================
-- 4. 3-TAB OBSIDIAN WORKSPACE & STANDALONE WINDOW
-- ============================================================================
local function GetStatusText()
    local db = EnsureDB()
    local r = db.ringEnabled and "On" or "Off"
    local c = db.crosshairEnabled and "On" or "Off"
    local t = db.trailEnabled and "On" or "Off"
    return string.format("Ring: %s | Crosshair: %s | Trail: %s", r, c, t)
end

do
    local activeDropPopup = nil
    local sharedDropPopup = nil
    local function CloseCursorPopups()
        if activeDropPopup then
            local prevOwner = activeDropPopup.owner
            activeDropPopup.owner = nil
            activeDropPopup:Hide()
            activeDropPopup = nil
            if prevOwner and type(prevOwner.SetOpenState) == "function" then
                prevOwner:SetOpenState(false)
            end
        end
    end
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.RegisterPopupCloser) == "function" then
        pcall(_G.DynamicSuite.UI.RegisterPopupCloser, "DynamicCursor_Popups", CloseCursorPopups)
    end

    local function SetBackdropSolid(frame, bg, border, edgeSize)
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = edgeSize or 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 0.96)
        frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 0.95)
    end

    local function CreateTrue4pxSlider(parent, width, minV, maxV, stepV, fmtFn, getFn, setFn)
        local wrap = CreateFrame("Frame", nil, parent)
        wrap:SetSize(width, 26)

        local readFs = wrap:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        SetSafeFont(readFs, 11, "")
        readFs:SetWidth(52)
        readFs:SetJustifyH("RIGHT")
        readFs:SetWordWrap(false)
        readFs:SetPoint("RIGHT", wrap, "RIGHT", 0, 0)

        local trackBorder = CreateFrame("Frame", nil, wrap, "BackdropTemplate")
        trackBorder:SetHeight(6)
        trackBorder:SetPoint("LEFT", wrap, "LEFT", 0, 0)
        trackBorder:SetPoint("RIGHT", readFs, "LEFT", -10, 0)
        SetBackdropSolid(trackBorder, { 0.035, 0.039, 0.051, 1.0 }, { 0.145, 0.165, 0.212, 0.95 }, 1)

        local fillBar = trackBorder:CreateTexture(nil, "ARTWORK")
        fillBar:SetPoint("TOPLEFT", trackBorder, "TOPLEFT", 1, -1)
        fillBar:SetPoint("BOTTOMLEFT", trackBorder, "BOTTOMLEFT", 1, 1)
        fillBar:SetWidth(1)

        local thumb = trackBorder:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(6, 14)
        thumb:SetColorTexture(0.88, 0.91, 0.96, 1)

        local hit = CreateFrame("Button", nil, wrap)
        hit:SetPoint("TOPLEFT", trackBorder, "TOPLEFT", 0, 10)
        hit:SetPoint("BOTTOMRIGHT", trackBorder, "BOTTOMRIGHT", 0, -10)
        hit:EnableMouseWheel(true)

        local dragging = false
        local function ClampStep(v)
            v = math.max(minV, math.min(maxV, v))
            if stepV and stepV > 0 then
                v = math.floor((v - minV) / stepV + 0.5) * stepV + minV
                v = math.max(minV, math.min(maxV, v))
            end
            return v
        end

        function wrap:RefreshValue()
            local val = tonumber(getFn()) or minV
            local pct = (maxV > minV) and ((val - minV) / (maxV - minV)) or 0
            pct = math.max(0, math.min(1, pct))
            local ar, ag, ab = GetSuiteAccent()
            readFs:SetTextColor(ar, ag, ab, 1)
            readFs:SetText(fmtFn(val))
            local tw = math.max(10, (trackBorder:GetWidth() or 120) - 2)
            fillBar:SetColorTexture(ar, ag, ab, 1)
            fillBar:SetWidth(math.max(1, tw * pct))
            thumb:ClearAllPoints()
            thumb:SetPoint("CENTER", trackBorder, "LEFT", 1 + tw * pct, 0)
            if dragging or hit:IsMouseOver() then
                thumb:SetColorTexture(ar, ag, ab, 1)
            else
                thumb:SetColorTexture(0.88, 0.91, 0.96, 1)
            end
        end

        local function ApplyCursorX()
            local left = trackBorder:GetLeft()
            local w = trackBorder:GetWidth()
            if not left or not w or w <= 2 then return end
            local cx = GetCursorPosition() / (trackBorder:GetEffectiveScale() or 1)
            local pct = math.max(0, math.min(1, (cx - left) / w))
            local val = ClampStep(minV + pct * (maxV - minV))
            setFn(val)
            wrap:RefreshValue()
        end

        hit:SetScript("OnMouseDown", function(_, btn)
            if btn == "LeftButton" then
                dragging = true
                ApplyCursorX()
            end
        end)
        hit:SetScript("OnMouseUp", function()
            dragging = false
            wrap:RefreshValue()
        end)
        hit:SetScript("OnEnter", function() wrap:RefreshValue() end)
        hit:SetScript("OnLeave", function() wrap:RefreshValue() end)
        hit:SetScript("OnUpdate", function()
            if dragging then
                if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                    dragging = false
                    wrap:RefreshValue()
                    return
                end
                ApplyCursorX()
            end
        end)
        hit:SetScript("OnHide", function() dragging = false end)
        hit:SetScript("OnMouseWheel", function(_, delta)
            local val = ClampStep((tonumber(getFn()) or minV) + delta * (stepV or 1))
            setFn(val)
            wrap:RefreshValue()
        end)
        trackBorder:SetScript("OnSizeChanged", function() wrap:RefreshValue() end)
        return wrap
    end

    local function CreateSegmentedPills(parent, totalW, options, getFn, setFn)
        local holder = CreateFrame("Frame", nil, parent)
        holder:SetSize(totalW, 26)
        local n = #options
        local gap = 4
        local isBinary = (n == 2 and options[1].label == "Off" and options[2].label == "Enabled")
        local btns = {}
        local xOff = 0
        for i, opt in ipairs(options) do
            local bw = isBinary and (i == 1 and 68 or 84) or math.floor((totalW - gap * (n - 1)) / n)
            if not isBinary and i == n then bw = totalW - xOff end
            local b = CreateFrame("Button", nil, holder, "BackdropTemplate")
            b:SetSize(bw, 26)
            b:SetPoint("LEFT", holder, "LEFT", xOff, 0)
            b.lbl = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            SetSafeFont(b.lbl, 11, "")
            b.lbl:SetPoint("CENTER")
            b.lbl:SetWordWrap(false)
            b.lbl:SetText(opt.label)
            b.offBar = b:CreateTexture(nil, "OVERLAY")
            b.offBar:SetHeight(1.5)
            b.offBar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 1)
            b.offBar:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
            b.offBar:SetColorTexture(0.973, 0.443, 0.443, 1)
            b.offBar:Hide()
            b.opt = opt
            b:SetScript("OnClick", function()
                setFn(opt.value)
                holder:RefreshValue()
            end)
            btns[i] = b
            xOff = xOff + bw + gap
        end
        function holder:RefreshValue()
            local cur = getFn()
            local ar, ag, ab = GetSuiteAccent()
            for _, b in ipairs(btns) do
                local sel = (b.opt.value == cur)
                local up = tostring(b.opt.label or ""):upper()
                local isNeg = (up == "OFF" or up == "DISABLED")
                if sel and isNeg then
                    SetBackdropSolid(b, { 0.118, 0.141, 0.188, 0.98 }, { 0.392, 0.455, 0.545, 0.95 }, 1)
                    b.lbl:SetTextColor(0.886, 0.910, 0.941, 1)
                    b.offBar:Show()
                elseif sel then
                    SetBackdropSolid(b, { ar * 0.42, ag * 0.42, ab * 0.42, 0.98 }, { ar, ag, ab, 0.95 }, 1)
                    b.lbl:SetTextColor(1, 1, 1, 1)
                    b.offBar:Hide()
                else
                    SetBackdropSolid(b, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)
                    b.lbl:SetTextColor(0.68, 0.74, 0.82, 1)
                    b.offBar:Hide()
                end
            end
        end
        return holder
    end

    local function DisablePixelSnap(tex)
        if not tex then return end
        if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
        if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
    end

    local function CreateDropdownControl(parent, width, options, getFn, setFn)
        local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        btn:SetSize(width, 26)
        btn.isOpen = false
        btn.lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        SetSafeFont(btn.lbl, 11, "")
        btn.lbl:SetPoint("LEFT", btn, "LEFT", 10, 0)
        btn.lbl:SetPoint("RIGHT", btn, "RIGHT", -24, 0)
        btn.lbl:SetJustifyH("LEFT")
        btn.lbl:SetWordWrap(false)

        local chevronHolder = CreateFrame("Frame", nil, btn)
        chevronHolder:SetSize(12, 12)
        chevronHolder:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
        btn.chevronHolder = chevronHolder

        btn.chevron = chevronHolder:CreateTexture(nil, "OVERLAY", nil, 3)
        btn.chevron:SetAllPoints()
        btn.chevron:SetTexCoord(0, 1, 0, 1)
        btn.chevron:SetTexture(ICON_CHEVRON_DOWN)
        do
            local ar0, ag0, ab0 = GetSuiteAccent()
            btn.chevron:SetVertexColor(ar0, ag0, ab0, 0.90)
        end
        DisablePixelSnap(btn.chevron)

        function btn:SetOpenState(open)
            self.isOpen = open and true or false
            self.chevron:SetTexture(self.isOpen and ICON_CHEVRON_UP or ICON_CHEVRON_DOWN)
            local ar, ag, ab = GetSuiteAccent()
            if self.isOpen then
                self.chevron:SetVertexColor(ar, ag, ab, 1.0)
                self:SetBackdropBorderColor(ar, ag, ab, 0.95)
            elseif self:IsMouseOver() then
                self.chevron:SetVertexColor(ar, ag, ab, 1.0)
                self:SetBackdropBorderColor(ar, ag, ab, 0.75)
            else
                self.chevron:SetVertexColor(ar, ag, ab, 0.90)
                self:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95)
            end
        end

        function btn:RefreshValue()
            local ar, ag, ab = GetSuiteAccent()
            local borderCol = (self.isOpen and { ar, ag, ab, 0.95 }) or (self:IsMouseOver() and { ar, ag, ab, 0.75 }) or { 0.145, 0.165, 0.212, 0.95 }
            SetBackdropSolid(self, { 0.078, 0.090, 0.122, 0.96 }, borderCol, 1)
            self.chevron:SetTexture(self.isOpen and ICON_CHEVRON_UP or ICON_CHEVRON_DOWN)
            if self.isOpen or self:IsMouseOver() then
                self.chevron:SetVertexColor(ar, ag, ab, 1.0)
            else
                self.chevron:SetVertexColor(ar, ag, ab, 0.90)
            end
            local cur = getFn()
            for _, opt in ipairs(options) do
                if opt.value == cur then
                    self.lbl:SetText(opt.label)
                    return
                end
            end
            self.lbl:SetText(tostring(cur or ""))
        end

        btn:SetScript("OnEnter", function(selfBtn)
            if not selfBtn.isOpen then
                local ar, ag, ab = GetSuiteAccent()
                selfBtn:SetBackdropBorderColor(ar, ag, ab, 0.75)
                selfBtn.chevron:SetVertexColor(ar, ag, ab, 1.0)
            end
        end)
        btn:SetScript("OnLeave", function(selfBtn)
            if not selfBtn.isOpen then
                local ar, ag, ab = GetSuiteAccent()
                selfBtn:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95)
                selfBtn.chevron:SetVertexColor(ar, ag, ab, 0.90)
            end
        end)
        btn:SetScript("OnHide", CloseCursorPopups)
        btn:SetScript("OnClick", function(selfBtn)
            if activeDropPopup and activeDropPopup.owner == selfBtn and activeDropPopup:IsShown() then
                CloseCursorPopups()
                return
            end
            CloseCursorPopups()
            if not sharedDropPopup then
                local p = CreateFrame("Frame", "DynamicCursorDropdownPopup", UIParent, "BackdropTemplate")
                p:SetFrameStrata("TOOLTIP")
                p:SetFrameLevel(120)
                p:SetClampedToScreen(true)
                p:EnableMouse(true)
                p.rows = {}
                p:SetScript("OnHide", function(selfPop)
                    local prevOwner = selfPop.owner
                    selfPop.owner = nil
                    if activeDropPopup == selfPop then activeDropPopup = nil end
                    if prevOwner and type(prevOwner.SetOpenState) == "function" then
                        prevOwner:SetOpenState(false)
                    end
                end)
                if type(UISpecialFrames) == "table" then
                    local exists = false
                    for _, n in ipairs(UISpecialFrames) do
                        if n == "DynamicCursorDropdownPopup" then exists = true; break end
                    end
                    if not exists then table.insert(UISpecialFrames, "DynamicCursorDropdownPopup") end
                end
                sharedDropPopup = p
            end

            local pop = sharedDropPopup
            local popH = #options * 24 + 8
            pop:SetWidth(width)
            pop:SetHeight(popH)
            pop.owner = selfBtn
            local ar, ag, ab = GetSuiteAccent()
            SetBackdropSolid(pop, { 0.043, 0.051, 0.071, 0.99 }, { ar, ag, ab, 0.95 }, 1)

            -- Screen-bottom flip when opening near the bottom edge
            pop:ClearAllPoints()
            local btnBot = selfBtn.GetBottom and selfBtn:GetBottom() or 300
            if btnBot - popH - 6 < 20 then
                pop:SetPoint("BOTTOMLEFT", selfBtn, "TOPLEFT", 0, 2)
            else
                pop:SetPoint("TOPLEFT", selfBtn, "BOTTOMLEFT", 0, -2)
            end

            for _, oldR in ipairs(pop.rows) do oldR:Hide() end
            local curVal = getFn()
            for i, opt in ipairs(options) do
                local row = pop.rows[i]
                if not row then
                    row = CreateFrame("Button", nil, pop)
                    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
                    row.hl:SetAllPoints()
                    row.rl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    SetSafeFont(row.rl, 11, "")
                    row.rl:SetPoint("LEFT", row, "LEFT", 8, 0)
                    row.rl:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                    row.rl:SetJustifyH("LEFT")
                    row.rl:SetWordWrap(false)
                    pop.rows[i] = row
                end
                row:SetSize(width - 8, 22)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", pop, "TOPLEFT", 4, -4 - (i - 1) * 24)
                row.hl:SetColorTexture(ar, ag, ab, 0.22)
                row.rl:SetText(opt.label)
                local isSel = (opt.value == curVal)
                row.rl:SetTextColor(isSel and ar or 0.90, isSel and ag or 0.93, isSel and ab or 0.96, 1)
                row:SetScript("OnClick", function()
                    setFn(opt.value)
                    selfBtn:RefreshValue()
                    CloseCursorPopups()
                end)
                row:Show()
            end
            activeDropPopup = pop
            selfBtn:SetOpenState(true)
            pop:Show()
        end)
        return btn
    end

    local function CreateSettingCard(parent, titleTxt, descTxt, rightW, customHeight)
        local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        row:SetHeight(customHeight or 56)
        SetBackdropSolid(row, { 0.055, 0.063, 0.082, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)

        local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        SetSafeFont(title, 12, "")
        title:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -9)
        if rightW and rightW > 0 then
            title:SetPoint("RIGHT", row, "RIGHT", -(rightW + 26), 0)
        else
            title:SetPoint("RIGHT", row, "RIGHT", -14, 0)
        end
        title:SetJustifyH("LEFT")
        title:SetWordWrap(false)
        title:SetTextColor(0.96, 0.98, 1.0, 1)
        title:SetText(titleTxt)
        row.title = title

        local desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        SetSafeFont(desc, 10, "")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
        if rightW and rightW > 0 then
            desc:SetPoint("RIGHT", row, "RIGHT", -(rightW + 26), 0)
        else
            desc:SetPoint("RIGHT", row, "RIGHT", -14, 0)
        end
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        desc:SetMaxLines(2)
        desc:SetTextColor(0.64, 0.70, 0.78, 1)
        desc:SetText(descTxt or "")
        row.desc = desc

        row:SetScript("OnEnter", function(s)
            s:SetBackdropBorderColor(0.24, 0.28, 0.36, 0.98)
        end)
        row:SetScript("OnLeave", function(s)
            s:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95)
        end)

        function row:BindRight(ctrl)
            ctrl:ClearAllPoints()
            ctrl:SetPoint("RIGHT", self, "RIGHT", -14, 0)
            self.ctrl = ctrl
            if self.title then
                self.title:ClearAllPoints()
                self.title:SetPoint("TOPLEFT", self, "TOPLEFT", 14, -9)
                self.title:SetPoint("RIGHT", ctrl, "LEFT", -12, 0)
            end
            if self.desc then
                self.desc:ClearAllPoints()
                self.desc:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -3)
                self.desc:SetPoint("RIGHT", ctrl, "LEFT", -12, 0)
            end
        end
        return row
    end

    local function CreateSubRow(parent, titleTxt, descTxt, rightW, customHeight)
        local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        row:SetHeight(customHeight or 54)
        SetBackdropSolid(row, { 0.035, 0.039, 0.051, 0.99 }, { 0.145, 0.165, 0.212, 0.95 }, 1)

        local ar, ag, ab = GetSuiteAccent()
        local subBar = row:CreateTexture(nil, "OVERLAY")
        subBar:SetWidth(2)
        subBar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
        subBar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
        subBar:SetColorTexture(ar, ag, ab, 0.85)
        DisablePixelSnap(subBar)
        row.subBar = subBar

        local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        SetSafeFont(title, 11, "")
        title:SetPoint("TOPLEFT", row, "TOPLEFT", 22, -9)
        if rightW and rightW > 0 then
            title:SetPoint("RIGHT", row, "RIGHT", -(rightW + 26), 0)
        else
            title:SetPoint("RIGHT", row, "RIGHT", -14, 0)
        end
        title:SetJustifyH("LEFT")
        title:SetWordWrap(false)
        title:SetTextColor(0.96, 0.98, 1.0, 1)
        title:SetText(titleTxt)
        row.title = title

        local pip = row:CreateTexture(nil, "OVERLAY")
        pip:SetSize(5, 5)
        pip:SetPoint("RIGHT", title, "LEFT", -6, 0)
        pip:SetColorTexture(ar, ag, ab, 0.95)
        DisablePixelSnap(pip)
        row.subPip = pip

        local desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        SetSafeFont(desc, 10, "")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
        if rightW and rightW > 0 then
            desc:SetPoint("RIGHT", row, "RIGHT", -(rightW + 26), 0)
        else
            desc:SetPoint("RIGHT", row, "RIGHT", -14, 0)
        end
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        desc:SetMaxLines(2)
        desc:SetTextColor(0.64, 0.70, 0.78, 1)
        desc:SetText(descTxt or "")
        row.desc = desc

        function row:RefreshAccent()
            local r, g, b = GetSuiteAccent()
            if self.subBar then self.subBar:SetColorTexture(r, g, b, 0.85) end
            if self.subPip then self.subPip:SetColorTexture(r, g, b, 0.95) end
        end

        function row:BindRight(ctrl)
            ctrl:ClearAllPoints()
            ctrl:SetPoint("RIGHT", self, "RIGHT", -14, 0)
            self.ctrl = ctrl
            if self.title then
                self.title:ClearAllPoints()
                self.title:SetPoint("TOPLEFT", self, "TOPLEFT", 22, -9)
                self.title:SetPoint("RIGHT", ctrl, "LEFT", -12, 0)
            end
            if self.desc then
                self.desc:ClearAllPoints()
                self.desc:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -3)
                self.desc:SetPoint("RIGHT", ctrl, "LEFT", -12, 0)
            end
        end
        return row
    end

    local function CreateGroupDrawerCard(parent, drawerKey, titleTxt, descTxt, getEnabledFn, setEnabledFn, cardVisibleFn, onChangedFn)
        local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        SetBackdropSolid(card, { 0.055, 0.063, 0.082, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)
        card.subRows = {}
        card.rows = card.subRows
        card.isGroupDrawer = true

        local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        SetSafeFont(title, 12, "")
        title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -9)
        title:SetPoint("RIGHT", card, "RIGHT", -182, 0)
        title:SetJustifyH("LEFT")
        title:SetWordWrap(false)
        title:SetTextColor(0.96, 0.98, 1.0, 1)
        title:SetText(titleTxt)

        local desc = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        SetSafeFont(desc, 10, "")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
        desc:SetPoint("RIGHT", card, "RIGHT", -182, 0)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        desc:SetMaxLines(2)
        desc:SetTextColor(0.64, 0.70, 0.78, 1)
        desc:SetText(descTxt)

        local toggle = CreateSegmentedPills(card, 156, {
            { value = false, label = "Off" },
            { value = true,  label = "Enabled" },
        }, getEnabledFn, function(v)
            setEnabledFn(v)
            local db = EnsureDB()
            db.drawerExpanded = db.drawerExpanded or {}
            if v == true then
                db.drawerExpanded[drawerKey] = true
            end
            if onChangedFn then onChangedFn() end
        end)
        toggle:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -15)
        card.toggle = toggle

        local chevBar = CreateFrame("Button", nil, card, "BackdropTemplate")
        chevBar:SetHeight(24)
        chevBar:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -52)
        chevBar:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -52)

        local chevLabel = chevBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        SetSafeFont(chevLabel, 11, "")
        chevLabel:SetPoint("CENTER", chevBar, "CENTER", 8, 0)
        chevLabel:SetText("Sub-Settings (0)")
        chevBar.label = chevLabel

        local chevTex = chevBar:CreateTexture(nil, "ARTWORK")
        chevTex:SetSize(11, 11)
        chevTex:SetPoint("RIGHT", chevLabel, "LEFT", -6, 0)
        DisablePixelSnap(chevTex)
        chevBar.chevron = chevTex
        card.chevBar = chevBar

        local function IsExpanded()
            local db = EnsureDB()
            db.drawerExpanded = db.drawerExpanded or {}
            if db.drawerExpanded[drawerKey] == nil then
                return true
            end
            return db.drawerExpanded[drawerKey] == true
        end

        local function RefreshChevBarVisual(hovered)
            local enabled = (getEnabledFn() == true)
            local expanded = enabled and IsExpanded()
            local ar, ag, ab = GetSuiteAccent()
            local fillAlpha = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42
            chevTex:SetTexture(expanded and ICON_CHEVRON_UP or ICON_CHEVRON_DOWN)
            if hovered then
                local hovA = math.min(0.65, fillAlpha + 0.10)
                SetBackdropSolid(chevBar, { ar * hovA, ag * hovA, ab * hovA, 0.98 }, { ar, ag, ab, 1.0 }, 1)
                chevTex:SetVertexColor(1, 1, 1, 1)
                chevLabel:SetTextColor(1, 1, 1, 1)
            elseif expanded then
                local expA = fillAlpha * 0.60
                SetBackdropSolid(chevBar, { ar * expA, ag * expA, ab * expA, 0.96 }, { ar, ag, ab, 0.95 }, 1)
                chevTex:SetVertexColor(1, 1, 1, 1)
                chevLabel:SetTextColor(1, 1, 1, 1)
            else
                SetBackdropSolid(chevBar, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)
                chevTex:SetVertexColor(ar, ag, ab, 0.95)
                chevLabel:SetTextColor(0.84, 0.89, 0.96, 1.0)
            end
        end

        chevBar:SetScript("OnEnter", function() RefreshChevBarVisual(true) end)
        chevBar:SetScript("OnLeave", function() RefreshChevBarVisual(false) end)
        chevBar:SetScript("OnClick", function()
            local db = EnsureDB()
            db.drawerExpanded = db.drawerExpanded or {}
            db.drawerExpanded[drawerKey] = not IsExpanded()
            if onChangedFn then onChangedFn() end
        end)

        function card:RefreshAccent()
            toggle:RefreshValue()
            RefreshChevBarVisual(chevBar:IsMouseOver())
            for _, sr in ipairs(self.subRows) do
                if sr.RefreshAccent then sr:RefreshAccent() end
            end
        end

        function card:LayoutRows()
            if cardVisibleFn and cardVisibleFn() ~= true then
                self:Hide()
                self:SetHeight(0)
                return
            end
            self:Show()
            toggle:RefreshValue()

            local enabled = (getEnabledFn() == true)
            local visRows = {}
            for _, sr in ipairs(self.subRows) do
                if (not sr.visibleFn) or (sr.visibleFn() == true) then
                    visRows[#visRows + 1] = sr
                else
                    sr:Hide()
                end
            end

            local ar, ag, ab = GetSuiteAccent()
            if (not enabled) or (#visRows == 0) then
                chevBar:Hide()
                for _, sr in ipairs(visRows) do sr:Hide() end
                self:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95)
                self:SetHeight(56)
                return
            end

            local expanded = IsExpanded()
            chevLabel:SetText(string.format("Sub-Settings (%d)", #visRows))
            chevBar:Show()
            RefreshChevBarVisual(chevBar:IsMouseOver())

            if expanded then
                self:SetBackdropBorderColor(ar, ag, ab, 0.85)
                local y = -82
                for _, sr in ipairs(visRows) do
                    sr:ClearAllPoints()
                    sr:SetPoint("TOPLEFT", self, "TOPLEFT", 10, y)
                    sr:SetPoint("TOPRIGHT", self, "TOPRIGHT", -10, y)
                    if sr.RefreshAccent then sr:RefreshAccent() end
                    sr:Show()
                    y = y - ((sr:GetHeight() or 54) + 6)
                end
                self:SetHeight(math.abs(y) + 4)
            else
                self:SetBackdropBorderColor(ar * 0.65, ag * 0.65, ab * 0.65, 0.80)
                for _, sr in ipairs(visRows) do sr:Hide() end
                self:SetHeight(84)
            end
        end

        return card
    end

    local function CreateSectionHeader(parent, titleTxt, subTxt)
        local hdr = CreateFrame("Frame", nil, parent)
        hdr:SetHeight(36)
        local bar = hdr:CreateTexture(nil, "OVERLAY")
        bar:SetSize(3, 34)
        bar:SetPoint("TOPLEFT", hdr, "TOPLEFT", 0, -1)
        local t = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        SetSafeFont(t, 11, "")
        t:SetPoint("TOPLEFT", bar, "TOPRIGHT", 8, 0)
        t:SetPoint("RIGHT", hdr, "RIGHT", -4, 0)
        t:SetJustifyH("LEFT")
        t:SetWordWrap(false)
        t:SetText(titleTxt)
        local s = hdr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        SetSafeFont(s, 10, "")
        s:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -3)
        s:SetPoint("RIGHT", hdr, "RIGHT", -4, 0)
        s:SetJustifyH("LEFT")
        s:SetWordWrap(false)
        s:SetTextColor(0.639, 0.702, 0.780, 1)
        s:SetText(subTxt)
        local bot = hdr:CreateTexture(nil, "OVERLAY")
        bot:SetHeight(1)
        bot:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 0, 0)
        bot:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
        function hdr:RefreshAccent()
            local ar, ag, ab = GetSuiteAccent()
            bar:SetColorTexture(ar, ag, ab, 1)
            t:SetTextColor(ar, ag, ab, 1)
            bot:SetColorTexture(ar, ag, ab, 0.35)
        end
        hdr:RefreshAccent()
        return hdr
    end

    local function CreateSectionContainer(parent, titleTxt, subTxt)
        local sec = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        SetBackdropSolid(sec, { 0.043, 0.050, 0.066, 0.98 }, { 1.0, 1.0, 1.0, 0.14 }, 1)
        sec.cards = {}
        sec.rows = sec.cards

        local hdr = CreateSectionHeader(sec, titleTxt, subTxt)
        hdr:SetPoint("TOPLEFT", sec, "TOPLEFT", 14, -10)
        hdr:SetPoint("TOPRIGHT", sec, "TOPRIGHT", -14, -10)
        sec.hdr = hdr

        function sec:RefreshAccent()
            self.hdr:RefreshAccent()
            for _, c in ipairs(self.cards) do
                if c.RefreshAccent then c:RefreshAccent() end
            end
        end

        function sec:LayoutRows()
            local y = -54
            for _, c in ipairs(self.cards) do
                if c.LayoutRows then
                    c:LayoutRows()
                elseif c.visibleFn then
                    c:SetShown(c.visibleFn() == true)
                end
                if c:IsShown() then
                    c:ClearAllPoints()
                    c:SetPoint("TOPLEFT", self, "TOPLEFT", 14, y)
                    c:SetPoint("TOPRIGHT", self, "TOPRIGHT", -14, y)
                    y = y - ((c:GetHeight() or 56) + 8)
                end
            end
            self:SetHeight(math.max(68, math.abs(y) + 6))
        end

        return sec
    end

    local function LayoutPage(page)
        local y = -4
        for _, item in ipairs(page.items or {}) do
            if item.LayoutRows then item:LayoutRows() end
            if item:IsShown() then
                item:ClearAllPoints()
                item:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
                item:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, y)
                y = y - ((item:GetHeight() or 68) + 12)
            end
        end
        page:SetHeight(math.max(100, math.abs(y) + 12))
    end

    local function RenderCursorEmbedded(a1, a2)
        local parent = nil
        if type(a2) == "table" and type(a2.GetObjectType) == "function" then
            parent = a2
        elseif type(a1) == "table" and type(a1.GetObjectType) == "function" then
            parent = a1
        end
        if not parent then return nil end
        if parent.DynamicCursorContainer then
            parent.DynamicCursorContainer:Show()
            DynamicCursor.embeddedRoot = parent.DynamicCursorContainer
            DynamicCursor:RefreshWorkspaceUI()
            return parent.DynamicCursorContainer
        end

        local root = CreateFrame("Frame", nil, parent)
        root:SetAllPoints(parent)
        root:Show()
        root:SetScript("OnHide", CloseCursorPopups)
        parent.DynamicCursorContainer = root
        DynamicCursor.embeddedRoot = root

        -- 4-Tab Segmented Bar (anchored at top of workspace for 1:1 DynamicSuite parity)
        local tabBar = CreateFrame("Frame", nil, root, "BackdropTemplate")
        tabBar:SetHeight(34)
        tabBar:SetPoint("TOPLEFT", root, "TOPLEFT", 14, -10)
        tabBar:SetPoint("TOPRIGHT", root, "TOPRIGHT", -16, -10)
        SetBackdropSolid(tabBar, { 0.043, 0.051, 0.071, 0.98 }, { 1, 1, 1, 0.08 }, 1)

        local tabDefs = {
            { id = 1, label = "Ring & Trail" },
            { id = 2, label = "GCD & Cast Arc" },
            { id = 3, label = "Crosshair & Locator" },
            { id = 4, label = "Visibility & Tooltips" },
        }
        local tabBtns = {}
        for i, td in ipairs(tabDefs) do
            local tb = CreateFrame("Button", nil, tabBar, "BackdropTemplate")
            tb:SetHeight(26)
            tb.lbl = tb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            SetSafeFont(tb.lbl, 11, "")
            tb.lbl:SetPoint("CENTER")
            tb.lbl:SetWordWrap(false)
            tb.lbl:SetText(td.label)
            tb:SetScript("OnClick", function()
                local db = EnsureDB()
                local changed = (db.activeSubTab ~= td.id)
                db.activeSubTab = td.id
                CloseCursorPopups()
                DynamicCursor:RefreshWorkspaceUI(changed)
            end)
            tabBtns[i] = tb
        end
        local function ReflowTabBar()
            local rawW = (tabBar and tabBar.GetWidth and tabBar:GetWidth()) or 0
            if rawW < 100 then
                rawW = ((parent and parent.GetWidth and parent:GetWidth()) or 760) - 30
            end
            local n = #tabBtns
            local w = math.max(320, rawW - 8)
            local gap = 4
            local bw = math.floor((w - gap * (n - 1)) / n)
            for i, tb in ipairs(tabBtns) do
                tb:ClearAllPoints()
                tb:SetWidth(i == n and (w - (bw + gap) * (n - 1)) or bw)
                tb:SetPoint("LEFT", tabBar, "LEFT", 4 + (i - 1) * (bw + gap), 0)
            end
        end
        tabBar:SetScript("OnSizeChanged", ReflowTabBar)
        ReflowTabBar()

        -- Scrollable Content + 4px 3-Way Scrollbar
        local sf = CreateFrame("ScrollFrame", nil, root)
        sf:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -8)
        sf:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", -10, -8)
        sf:SetPoint("BOTTOM", root, "BOTTOM", 0, 10)
        sf:EnableMouseWheel(true)

        local content = CreateFrame("Frame", nil, sf)
        content:SetWidth(640)
        content:SetHeight(600)
        sf:SetScrollChild(content)
        sf:SetScript("OnSizeChanged", function(selfSF, w)
            if w and w > 40 then
                content:SetWidth(w)
            end
        end)

        local track = CreateFrame("Frame", nil, root)
        track:SetWidth(4)
        track:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 8, -2)
        track:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 8, 2)
        track:EnableMouse(true)
        track:EnableMouseWheel(true)
        track:SetHitRectInsets(-5, -5, 0, 0)
        local trackBg = track:CreateTexture(nil, "BACKGROUND")
        trackBg:SetAllPoints()
        trackBg:SetColorTexture(0.035, 0.039, 0.051, 0.90)
        DisablePixelSnap(trackBg)

        local thumb = CreateFrame("Button", nil, track)
        thumb:SetWidth(4)
        thumb:SetHeight(40)
        thumb:SetPoint("TOP", track, "TOP", 0, 0)
        thumb:EnableMouse(true)
        thumb:EnableMouseWheel(true)
        thumb:SetHitRectInsets(-5, -5, 0, 0)
        local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
        thumbTex:SetAllPoints()
        thumbTex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
        DisablePixelSnap(thumbTex)
        thumb.tex = thumbTex

        local function SyncThumbColor()
            if thumb.isDragging then
                local ar, ag, ab = GetSuiteAccent()
                thumbTex:SetColorTexture(ar, ag, ab, 1.0)
            elseif thumb.isHovered then
                local ar, ag, ab = GetSuiteAccent()
                thumbTex:SetColorTexture(ar, ag, ab, 0.92)
            else
                thumbTex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
            end
        end

        local function UpdateScrollBar()
            if sf.UpdateScrollChildRect then pcall(sf.UpdateScrollChildRect, sf) end
            local viewH = sf:GetHeight() or 0
            local totalH = content:GetHeight() or 0
            local trackH = track:GetHeight() or 0
            if viewH <= 1 or trackH <= 1 then return end
            local maxS = math.max(0, totalH - viewH)
            if maxS <= 1 then
                track:Hide()
                thumb:Hide()
                sf:SetVerticalScroll(0)
                return
            end
            track:Show()
            thumb:Show()
            local ratio = math.max(0.12, math.min(1, viewH / math.max(1, totalH)))
            local thumbH = math.min(trackH, math.max(24, math.floor(trackH * ratio + 0.5)))
            thumb:SetHeight(thumbH)
            local cur = math.max(0, math.min(maxS, sf:GetVerticalScroll() or 0))
            local usableH = math.max(1, trackH - thumbH)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOP", track, "TOP", 0, -(cur / maxS) * usableH)
            SyncThumbColor()
        end

        local function ScrollFromCursor()
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                thumb.isDragging = false
                thumb:SetScript("OnUpdate", nil)
                track:SetScript("OnUpdate", nil)
                SyncThumbColor()
                return
            end
            local viewH = sf:GetHeight() or 0
            local totalH = content:GetHeight() or 0
            local maxS = math.max(0, totalH - viewH)
            if maxS <= 0 then return end
            local eff = track:GetEffectiveScale() or 1
            if eff <= 0 then eff = 1 end
            local _, cy = GetCursorPosition()
            cy = (cy or 0) / eff
            local top = track:GetTop()
            local bot = track:GetBottom()
            if top and bot and top > bot then
                local trackH = top - bot
                local thumbH = thumb:GetHeight() or 24
                local usableH = math.max(1, trackH - thumbH)
                local offsetFromTop = (top - cy) - (thumbH * 0.5)
                local pct = math.max(0, math.min(1, offsetFromTop / usableH))
                sf:SetVerticalScroll(pct * maxS)
                UpdateScrollBar()
            end
        end

        local function ScrollByDelta(delta)
            local maxS = math.max(0, (content:GetHeight() or 0) - (sf:GetHeight() or 0))
            local nextS = math.max(0, math.min(maxS, (sf:GetVerticalScroll() or 0) - delta * 38))
            sf:SetVerticalScroll(nextS)
            UpdateScrollBar()
        end

        sf:SetScript("OnMouseWheel", function(_, delta) ScrollByDelta(delta) end)
        track:SetScript("OnMouseWheel", function(_, delta) ScrollByDelta(delta) end)
        thumb:SetScript("OnMouseWheel", function(_, delta) ScrollByDelta(delta) end)
        sf:SetScript("OnVerticalScroll", UpdateScrollBar)
        sf:SetScript("OnScrollRangeChanged", UpdateScrollBar)
        sf:SetScript("OnShow", UpdateScrollBar)

        thumb:SetScript("OnEnter", function(selfBtn)
            selfBtn.isHovered = true
            SyncThumbColor()
        end)
        thumb:SetScript("OnLeave", function(selfBtn)
            selfBtn.isHovered = false
            SyncThumbColor()
        end)
        thumb:SetScript("OnMouseDown", function(selfBtn, b)
            if b == "LeftButton" then
                CloseCursorPopups()
                selfBtn.isDragging = true
                SyncThumbColor()
                ScrollFromCursor()
                selfBtn:SetScript("OnUpdate", ScrollFromCursor)
            end
        end)
        thumb:SetScript("OnMouseUp", function(selfBtn, b)
            if b == "LeftButton" then
                selfBtn.isDragging = false
                selfBtn:SetScript("OnUpdate", nil)
                SyncThumbColor()
            end
        end)
        thumb:SetScript("OnHide", function(selfBtn)
            selfBtn.isDragging = false
            selfBtn.isHovered = false
            selfBtn:SetScript("OnUpdate", nil)
            SyncThumbColor()
        end)

        track:SetScript("OnMouseDown", function(selfTr, b)
            if b == "LeftButton" then
                CloseCursorPopups()
                thumb.isDragging = true
                SyncThumbColor()
                ScrollFromCursor()
                selfTr:SetScript("OnUpdate", ScrollFromCursor)
            end
        end)
        track:SetScript("OnMouseUp", function(selfTr, b)
            if b == "LeftButton" then
                thumb.isDragging = false
                selfTr:SetScript("OnUpdate", nil)
                SyncThumbColor()
            end
        end)
        track:SetScript("OnHide", function(selfTr)
            thumb.isDragging = false
            selfTr:SetScript("OnUpdate", nil)
            SyncThumbColor()
        end)

        local pages = {}
        for i = 1, 4 do
            local pg = CreateFrame("Frame", nil, content)
            pg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
            pg:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
            pg.items = {}
            pg:Hide()
            pages[i] = pg
        end

        local refreshables = {}
        local sections = {}

        local function RefreshAllUI()
            SyncAllEngines()
            DynamicCursor:RefreshWorkspaceUI()
        end
        local function AddSection(pgIdx, t, s)
            local sec = CreateSectionContainer(pages[pgIdx], t, s)
            pages[pgIdx].items[#pages[pgIdx].items + 1] = sec
            sections[#sections + 1] = sec
            return sec
        end
        local function AddGroupCard(sec, drawerKey, title, desc, getFn, setFn, cardVisibleFn)
            local card = CreateGroupDrawerCard(sec, drawerKey, title, desc, getFn, setFn, cardVisibleFn, RefreshAllUI)
            sec.cards[#sec.cards + 1] = card
            return card
        end
        local function MakeRow(sec, title, desc, rightW, customHeight)
            if sec.isGroupDrawer then
                return CreateSubRow(sec, title, desc, rightW, customHeight)
            end
            return CreateSettingCard(sec, title, desc, rightW, customHeight)
        end
        local function AddToggle(sec, title, desc, getFn, setFn, visibleFn)
            local r = MakeRow(sec, title, desc, 156)
            r.visibleFn = visibleFn
            local p = CreateSegmentedPills(r, 156, { { value = false, label = "Off" }, { value = true, label = "Enabled" } }, getFn, function(v)
                setFn(v); SyncAllEngines(); DynamicCursor:RefreshWorkspaceUI()
            end)
            r:BindRight(p)
            sec.rows[#sec.rows + 1] = r
            refreshables[#refreshables + 1] = p
        end
        local function AddSlider(sec, title, desc, minV, maxV, stepV, fmtFn, getFn, setFn, visibleFn)
            local r = MakeRow(sec, title, desc, 256)
            r.visibleFn = visibleFn
            local s = CreateTrue4pxSlider(r, 256, minV, maxV, stepV, fmtFn, getFn, function(v)
                setFn(v); SyncAllEngines()
            end)
            r:BindRight(s)
            sec.rows[#sec.rows + 1] = r
            refreshables[#refreshables + 1] = s
        end
        local function AddPills(sec, title, desc, w, opts, getFn, setFn, visibleFn)
            local r = MakeRow(sec, title, desc, w)
            r.visibleFn = visibleFn
            local p = CreateSegmentedPills(r, w, opts, getFn, function(v)
                setFn(v); SyncAllEngines(); DynamicCursor:RefreshWorkspaceUI()
            end)
            r:BindRight(p)
            sec.rows[#sec.rows + 1] = r
            refreshables[#refreshables + 1] = p
        end
        local function AddDropdown(sec, title, desc, w, opts, getFn, setFn, visibleFn)
            local r = MakeRow(sec, title, desc, w)
            r.visibleFn = visibleFn
            local d = CreateDropdownControl(r, w, opts, getFn, function(v)
                setFn(v); SyncAllEngines(); DynamicCursor:RefreshWorkspaceUI()
            end)
            r:BindRight(d)
            sec.rows[#sec.rows + 1] = r
            refreshables[#refreshables + 1] = d
        end
        local function AddColorModeDropdown(sec, title, desc, w, opts, getModeFn, setModeFn, getHexFn, setHexFn, pickerTitle, matchRgbFn, visibleFn)
            local totalW = w + 34
            local r = MakeRow(sec, title, desc, totalW)
            r.visibleFn = visibleFn
            local wrap = CreateFrame("Frame", nil, r)
            wrap:SetSize(totalW, 24)

            local d = CreateDropdownControl(wrap, w, opts, getModeFn, function(v)
                setModeFn(v); SyncAllEngines(); DynamicCursor:RefreshWorkspaceUI()
            end)
            d:SetPoint("LEFT", wrap, "LEFT", 0, 0)

            local swatch = CreateFrame("Button", nil, wrap, "BackdropTemplate")
            swatch:SetSize(28, 24)
            swatch:SetPoint("RIGHT", wrap, "RIGHT", 0, 0)
            SetBackdropSolid(swatch, { 0.04, 0.05, 0.07, 1.0 }, { 0.25, 0.30, 0.38, 0.95 }, 1)

            local swTex = swatch:CreateTexture(nil, "ARTWORK")
            swTex:SetPoint("TOPLEFT", swatch, "TOPLEFT", 2, -2)
            swTex:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -2, 2)
            swatch.tex = swTex

            local function GetResolvedRGB()
                local mr, mg, mb = nil, nil, nil
                if type(matchRgbFn) == "function" then
                    mr, mg, mb = matchRgbFn()
                end
                return ResolveColorMode(getModeFn(), getHexFn(), false, mr, mg, mb)
            end

            swatch:SetScript("OnClick", function(selfBtn)
                local curMode = getModeFn()
                local initHex = getHexFn()
                if curMode ~= "CUSTOM" then
                    local cr, cg, cb = GetResolvedRGB()
                    initHex = RGBToHex(cr, cg, cb)
                    setModeFn("CUSTOM")
                    setHexFn(initHex)
                    SyncAllEngines()
                    DynamicCursor:RefreshWorkspaceUI()
                end
                OpenCursorColorPicker(selfBtn, pickerTitle or title, initHex, function(newHex)
                    setModeFn("CUSTOM")
                    setHexFn(newHex)
                    SyncAllEngines()
                    DynamicCursor:RefreshWorkspaceUI()
                end)
            end)
            swatch:SetScript("OnEnter", function(selfBtn)
                if _G.GameTooltip then
                    _G.GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
                    _G.GameTooltip:SetText(pickerTitle or title, 1, 1, 1)
                    _G.GameTooltip:AddLine("Click to open the Custom Colour Picker.", 0.72, 0.78, 0.86, true)
                    _G.GameTooltip:Show()
                end
            end)
            swatch:SetScript("OnLeave", function()
                if _G.GameTooltip then _G.GameTooltip:Hide() end
            end)

            function wrap:RefreshValue()
                d:RefreshValue()
                local cr, cg, cb = GetResolvedRGB()
                swTex:SetColorTexture(cr, cg, cb, 1)
                if getModeFn() == "CUSTOM" then
                    local ar, ag, ab = GetSuiteAccent()
                    swatch:SetBackdropBorderColor(ar, ag, ab, 0.95)
                else
                    swatch:SetBackdropBorderColor(0.25, 0.30, 0.38, 0.95)
                end
            end

            r:BindRight(wrap)
            sec.rows[#sec.rows + 1] = r
            refreshables[#refreshables + 1] = wrap
        end

        local function GetBaseRingRGB()
            local db = EnsureDB()
            return ResolveColorMode(db.ringColorMode or "ACCENT", db.ringCustomHex, false)
        end
        local function IsRingOn() return EnsureDB().ringEnabled == true end
        local function IsRingDotOn() local db = EnsureDB(); return db.ringEnabled == true and db.ringCenterDot == true end
        local function IsGroundTargetOn() local db = EnsureDB(); return db.ringEnabled == true and db.groundTargetHighlight ~= false end
        local function IsTrailOn() return EnsureDB().trailEnabled == true end
        local function IsGcdOn() return EnsureDB().gcdEnabled ~= false end
        local function IsCastArcOn() return EnsureDB().castArcEnabled ~= false end
        local function IsCastIconOn() return EnsureDB().castShowIcon == true end
        local function IsCrosshairOn() return EnsureDB().crosshairEnabled == true end
        local function IsCrosshairLinesOn() local db = EnsureDB(); return db.crosshairEnabled == true and (db.crosshairShowCross == true or db.crosshairShowBrackets == true) end
        local function IsCrosshairCrossOn() local db = EnsureDB(); return db.crosshairEnabled == true and db.crosshairShowCross == true end
        local function IsCrosshairCircleOn() local db = EnsureDB(); return db.crosshairEnabled == true and db.crosshairShowCircle == true end
        local function IsCrosshairDotOn() local db = EnsureDB(); return db.crosshairEnabled == true and db.crosshairShowDot == true end
        local function IsShakeOn() return EnsureDB().shakeToFind == true end
        local function IsTooltipOn() return EnsureDB().tooltipEnabled == true end

        -- ====================================================================
        -- TAB 1: Ring & Trail
        -- ====================================================================
        local secPresets = AddSection(1, "QUICK PRESETS", "Apply a ready-made setup in one click, or fine-tune every option below.")
        local presetCard = CreateFrame("Frame", nil, secPresets, "BackdropTemplate")
        presetCard:SetHeight(46)
        SetBackdropSolid(presetCard, { 0.055, 0.063, 0.082, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)

        local presetLbl = presetCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        SetSafeFont(presetLbl, 10, "")
        presetLbl:SetPoint("LEFT", presetCard, "LEFT", 14, 0)
        presetLbl:SetText("PRESETS")
        presetLbl:SetTextColor(0.58, 0.64, 0.72, 1)

        local presetDefs = {
            { key = "CLEAN_RAID",     label = "Clean Raid",      w = 90 },
            { key = "HIGH_VIS",       label = "High-Visibility", w = 108 },
            { key = "MINIMALIST",     label = "Minimalist",      w = 88 },
            { key = "FULL_TELEMETRY", label = "All Overlays",    w = 98 },
        }
        local presetBtns = {}
        local function StylePresetBtn(pb, hovered)
            local ar, ag, ab = GetSuiteAccent()
            if hovered then
                SetBackdropSolid(pb, { ar * 0.20, ag * 0.20, ab * 0.20, 0.98 }, { ar, ag, ab, 1.0 }, 1)
                pb.lbl:SetTextColor(1, 1, 1, 1)
            else
                SetBackdropSolid(pb, { 0.078, 0.090, 0.122, 0.96 }, { ar, ag, ab, 0.70 }, 1)
                pb.lbl:SetTextColor(0.92, 0.95, 0.99, 1)
            end
        end
        local function ReflowPresets()
            local cardW = presetCard:GetWidth() or 540
            if cardW < 240 then return end
            local startX = 82
            local rightPad = 14
            local gap = 6
            local avail = math.max(200, cardW - startX - rightPad - (gap * (#presetBtns - 1)))
            local weightSum = 0
            for _, p in ipairs(presetDefs) do weightSum = weightSum + p.w end
            local x = startX
            for i, pb in ipairs(presetBtns) do
                pb:ClearAllPoints()
                pb:SetHeight(26)
                if i == #presetBtns then
                    pb:SetPoint("LEFT", presetCard, "LEFT", x, 0)
                    pb:SetPoint("RIGHT", presetCard, "RIGHT", -rightPad, 0)
                else
                    local bw = math.max(58, math.floor((avail * presetDefs[i].w) / weightSum))
                    pb:SetWidth(bw)
                    pb:SetPoint("LEFT", presetCard, "LEFT", x, 0)
                    x = x + bw + gap
                end
            end
        end
        for _, p in ipairs(presetDefs) do
            local pb = CreateFrame("Button", nil, presetCard, "BackdropTemplate")
            pb:SetSize(p.w, 26)
            pb.lbl = pb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            SetSafeFont(pb.lbl, 10, "")
            pb.lbl:SetPoint("LEFT", pb, "LEFT", 4, 0)
            pb.lbl:SetPoint("RIGHT", pb, "RIGHT", -4, 0)
            pb.lbl:SetJustifyH("CENTER")
            pb.lbl:SetWordWrap(false)
            pb.lbl:SetText(p.label)
            pb:SetScript("OnEnter", function(selfBtn) StylePresetBtn(selfBtn, true) end)
            pb:SetScript("OnLeave", function(selfBtn) StylePresetBtn(selfBtn, false) end)
            pb:SetScript("OnClick", function() DynamicCursor:ApplyPreset(p.key) end)
            presetBtns[#presetBtns + 1] = pb
        end
        presetCard:SetScript("OnSizeChanged", ReflowPresets)
        ReflowPresets()
        secPresets.cards[#secPresets.cards + 1] = presetCard

        local secRing = AddSection(1, "MAIN CURSOR RING", "Keep track of your pointer with a clean, click-through ring around your cursor.")
        local grpRing = AddGroupCard(secRing, "ringCore", "Enable Cursor Ring", "Displays a customisable ring around your mouse cursor (Off by default).",
            function() return EnsureDB().ringEnabled == true end, function(v) EnsureDB().ringEnabled = v end)
        AddDropdown(grpRing, "Ring Style", "Choose between Solid Ring, Soft Glow, or High-Contrast Dual.", 220, {
            { value = "SOLID", label = "Solid Ring" },
            { value = "GLOW",  label = "Soft Glow" },
            { value = "DUAL",  label = "High-Contrast Dual" },
        }, function() return EnsureDB().ringStyle or "SOLID" end, function(v) EnsureDB().ringStyle = v end)
        AddSlider(grpRing, "Ring Thickness", "Adjust how thick the cursor ring line is from 1 (finest) to 5 (boldest).", 1, 5, 1,
            function(v) return string.format("%d / 5", v) end,
            function() return EnsureDB().ringThickness or 3 end, function(v) EnsureDB().ringThickness = v end)
        AddToggle(grpRing, "Extra Ring Contrast", "Adds a crisp dark outline behind the main cursor ring, inner GCD ring, and outer cast arc so they stand out over bright spell effects.",
            function() return EnsureDB().ringExtraContrast == true end, function(v) EnsureDB().ringExtraContrast = v end)
        AddSlider(grpRing, "Ring Radius", "Adjust the cursor ring radius in pixels (16 to 96 px).", 16, 96, 2,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().ringRadius or 24 end, function(v) EnsureDB().ringRadius = v end)
        AddSlider(grpRing, "Ring Offset (X)", "Fine-tune horizontal ring alignment around your pointer tip (-16 to +16 px).", -16, 16, 1,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().ringOffsetX or 0 end, function(v) EnsureDB().ringOffsetX = v end)
        AddSlider(grpRing, "Ring Offset (Y)", "Fine-tune vertical ring alignment around your pointer tip (-16 to +16 px).", -16, 16, 1,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().ringOffsetY or 0 end, function(v) EnsureDB().ringOffsetY = v end)
        AddColorModeDropdown(grpRing, "Ring Colour Mode", "Follow your Suite Accent, Class Colour, High-Vis Green, or click the swatch for a custom colour.", 210, {
            { value = "ACCENT",         label = "Suite Accent" },
            { value = "CLASS",          label = "Class Colour" },
            { value = "HIGH_VIS_GREEN", label = "High-Vis Green" },
            { value = "CUSTOM",         label = "Custom Colour" },
        }, function() return EnsureDB().ringColorMode or "ACCENT" end, function(v) EnsureDB().ringColorMode = v end,
           function() return EnsureDB().ringCustomHex or "38BDF8" end, function(h) EnsureDB().ringCustomHex = h end,
           "Cursor Ring Custom Colour", nil)
        AddToggle(grpRing, "Combat Colour Shift", "Tints the cursor ring warm amber-orange while you are in combat.",
            function() return EnsureDB().ringCombatShift == true end, function(v) EnsureDB().ringCombatShift = v end)
        AddSlider(grpRing, "Out-of-Combat Opacity", "Ring transparency while out of combat.", 0.05, 1.00, 0.05,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return EnsureDB().ringOpacityOOC or 0.55 end, function(v) EnsureDB().ringOpacityOOC = v end)
        AddSlider(grpRing, "In-Combat Opacity", "Ring transparency during combat.", 0.05, 1.00, 0.05,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return EnsureDB().ringOpacityCombat or 0.95 end, function(v) EnsureDB().ringOpacityCombat = v end)
        AddPills(grpRing, "Out-of-Combat Idle Fade", "Smoothly fades the cursor ring and centre dot to 0% out of combat after your mouse stops moving.", 190, {
            { value = "OFF", label = "Off" }, { value = "2", label = "2s" }, { value = "5", label = "5s" },
        }, function() return EnsureDB().ringIdleFade or "OFF" end, function(v) EnsureDB().ringIdleFade = v end)

        local grpDot = AddGroupCard(secRing, "ringDot", "Cursor Centre Dot", "Shows a crisp dot with a dark outline right at the pointer tip inside the ring (Off by default).",
            function() return EnsureDB().ringCenterDot == true end, function(v) EnsureDB().ringCenterDot = v end, IsRingOn)
        AddSlider(grpDot, "Centre Dot Size", "Adjust the cursor centre dot size in pixels (2 to 8 px).", 2, 8, 1,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().ringCenterDotSize or 4 end, function(v) EnsureDB().ringCenterDotSize = v end)
        AddColorModeDropdown(grpDot, "Centre Dot Colour Mode", "Match the cursor ring or pick an independent colour for the pointer centre dot.", 210, {
            { value = "MATCH_RING", label = "Match Ring" },
            { value = "ACCENT",     label = "Suite Accent" },
            { value = "CLASS",      label = "Class Colour" },
            { value = "CUSTOM",     label = "Custom Colour" },
        }, function() return EnsureDB().ringCenterDotColorMode or "MATCH_RING" end, function(v) EnsureDB().ringCenterDotColorMode = v end,
           function() return EnsureDB().ringCenterDotCustomHex or "FFFFFF" end, function(h) EnsureDB().ringCenterDotCustomHex = h end,
           "Centre Dot Custom Colour", GetBaseRingRGB)

        local grpAoE = AddGroupCard(secRing, "ringAoE", "Ground-Target AoE Highlight", "Boosts the cursor ring to 100% opacity and a highlight colour while aiming ground-targeted spells.",
            function() return EnsureDB().groundTargetHighlight ~= false end, function(v) EnsureDB().groundTargetHighlight = v end, IsRingOn)
        AddColorModeDropdown(grpAoE, "Ground-Target Highlight Colour", "Highlight colour used while aiming ground-targeted AoE spells.", 210, {
            { value = "HIGH_VIS_GREEN", label = "High-Vis Green" },
            { value = "BRIGHT_GOLD",    label = "Bright Gold" },
            { value = "CUSTOM",         label = "Custom Colour" },
        }, function() return EnsureDB().groundTargetColorMode or "HIGH_VIS_GREEN" end, function(v) EnsureDB().groundTargetColorMode = v end,
           function() return EnsureDB().groundTargetCustomHex or "22EB5E" end, function(h) EnsureDB().groundTargetCustomHex = h end,
           "Ground-Target Highlight Colour", nil)
        AddToggle(grpAoE, "Ground-Target Size Boost", "Smoothly increases the cursor ring size by 20% while aiming a ground-targeted spell.",
            function() return EnsureDB().groundTargetSizeBoost ~= false end, function(v) EnsureDB().groundTargetSizeBoost = v end)

        local grpMouseLook = AddGroupCard(secRing, "ringMouseLook", "Keep Visible During Mouse-Look", "Shows a subtle ghost ring while Right-Click turning your camera.",
            function() return EnsureDB().ringKeepMouseLook ~= false end, function(v) EnsureDB().ringKeepMouseLook = v end, IsRingOn)
        AddSlider(grpMouseLook, "Mouse-Look Ghost Opacity", "Opacity of the subtle ghost ring while holding Right-Click to turn.", 0.10, 1.00, 0.05,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return EnsureDB().ringMouseLookOpacity or 0.35 end, function(v) EnsureDB().ringMouseLookOpacity = v end)

        local grpPulse = AddGroupCard(secRing, "ringClickPulse", "Click-Pulse Ripple", "Plays a quick expanding ripple when you click.",
            function() return EnsureDB().ringClickPulse == true end, function(v) EnsureDB().ringClickPulse = v end, IsRingOn)
        AddSlider(grpPulse, "Click-Pulse Scale", "How wide the click-pulse ripple expands relative to your cursor ring (125% to 250%).", 1.25, 2.50, 0.05,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return EnsureDB().ringClickPulseScale or 1.75 end, function(v) EnsureDB().ringClickPulseScale = v end)
        AddColorModeDropdown(grpPulse, "Click-Pulse Colour Mode", "Match the cursor ring, use Suite Accent, or pick a custom ripple colour.", 210, {
            { value = "MATCH_RING", label = "Match Ring" },
            { value = "ACCENT",     label = "Suite Accent" },
            { value = "CUSTOM",     label = "Custom Colour" },
        }, function() return EnsureDB().ringClickPulseColorMode or "MATCH_RING" end, function(v) EnsureDB().ringClickPulseColorMode = v end,
           function() return EnsureDB().ringClickPulseCustomHex or "38BDF8" end, function(h) EnsureDB().ringClickPulseCustomHex = h end,
           "Click-Pulse Custom Colour", GetBaseRingRGB)

        local secTrail = AddSection(1, "POOLED CURSOR TRAIL", "Draws a smooth, lightweight fading trail behind your mouse movement.")
        local grpTrail = AddGroupCard(secTrail, "trailCore", "Enable Cursor Trail", "Draws a smooth fading trail behind mouse movement (Off by default).",
            function() return EnsureDB().trailEnabled == true end, function(v) EnsureDB().trailEnabled = v end)
        AddDropdown(grpTrail, "Trail Style", "Choose between 4 trail particle styles.", 220, {
            { value = "SMOOTH_DOTS",  label = "Smooth Dots" },
            { value = "SOFT_MIST",    label = "Soft Mist" },
            { value = "CLASS_SPARKS", label = "Class Sparks" },
            { value = "ARCANE_MOTES", label = "Arcane Motes" },
        }, function() return EnsureDB().trailStyle or "SMOOTH_DOTS" end, function(v) EnsureDB().trailStyle = v end)
        AddColorModeDropdown(grpTrail, "Trail Colour Mode", "Follow your Suite Accent, Class Colour, High-Vis Green, or click the swatch for a custom colour.", 210, {
            { value = "ACCENT",         label = "Suite Accent" },
            { value = "CLASS",          label = "Class Colour" },
            { value = "HIGH_VIS_GREEN", label = "High-Vis Green" },
            { value = "CUSTOM",         label = "Custom Colour" },
        }, function() return EnsureDB().trailColorMode or "ACCENT" end, function(v) EnsureDB().trailColorMode = v end,
           function() return EnsureDB().trailCustomHex or "38BDF8" end, function(h) EnsureDB().trailCustomHex = h end,
           "Cursor Trail Custom Colour", nil)
        AddSlider(grpTrail, "Trail Opacity", "Maximum trail opacity.", 0.10, 1.00, 0.05,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return EnsureDB().trailOpacity or 0.75 end, function(v) EnsureDB().trailOpacity = v end)
        AddSlider(grpTrail, "Trail Particle Size", "Base size of each trail particle (6 to 32 px).", 6, 32, 2,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().trailSize or 14 end, function(v) EnsureDB().trailSize = v end)
        AddSlider(grpTrail, "Trail Density", "How closely trail particles appear along your mouse path (1 to 5).", 1, 5, 1,
            function(v) return string.format("%d", v) end,
            function() return EnsureDB().trailDensity or 3 end, function(v) EnsureDB().trailDensity = v end)
        AddSlider(grpTrail, "Trail Fade Duration", "How long each trail particle takes to fade out (0.15s to 1.20s).", 0.15, 1.20, 0.05,
            function(v) return string.format("%.2fs", v) end,
            function() return EnsureDB().trailDuration or 0.45 end, function(v) EnsureDB().trailDuration = v end)
        AddToggle(grpTrail, "Show Trail in Combat Only", "Only shows trail particles while you are in combat.",
            function() return EnsureDB().trailCombatOnly == true end, function(v) EnsureDB().trailCombatOnly = v end)
        AddToggle(grpTrail, "Keep Trail During Mouse-Look", "Continues drawing the cursor trail while Right-Click turning your camera.",
            function() return EnsureDB().trailShowMouseLook == true end, function(v) EnsureDB().trailShowMouseLook = v end)

        -- ====================================================================
        -- TAB 2: GCD & Cast Arc
        -- ====================================================================
        local secGcd = AddSection(2, "INNER GCD RING", "Global Cooldown ring nested cleanly inside your main cursor ring.")
        local grpGcd = AddGroupCard(secGcd, "gcdCore", "Inner GCD Ring", "Shows your Global Cooldown sweep inside the cursor ring.",
            function() return EnsureDB().gcdEnabled ~= false end, function(v) EnsureDB().gcdEnabled = v end)
        AddSlider(grpGcd, "Inner GCD Ring Gap", "Inward spacing from the main cursor ring (0 to 20 px; automatically kept legible).", 0, 20, 1,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().gcdGap or 6 end, function(v) EnsureDB().gcdGap = v end)
        AddPills(grpGcd, "Inner GCD Ring Style", "Choose the line thickness for the inner GCD ring.", 210, {
            { value = "THIN", label = "Thin" }, { value = "CRISP", label = "Crisp" }, { value = "THICK", label = "Thick" },
        }, function() return EnsureDB().gcdStyle or "THIN" end, function(v) EnsureDB().gcdStyle = v end)
        AddColorModeDropdown(grpGcd, "Inner GCD Colour Mode", "Match the cursor ring or pick an independent colour for the inner GCD ring.", 210, {
            { value = "MATCH_RING", label = "Match Ring" },
            { value = "ACCENT",     label = "Suite Accent" },
            { value = "CLASS",      label = "Class Colour" },
            { value = "CUSTOM",     label = "Custom Colour" },
        }, function() return EnsureDB().gcdColorMode or "MATCH_RING" end, function(v) EnsureDB().gcdColorMode = v end,
           function() return EnsureDB().gcdCustomHex or "38BDF8" end, function(h) EnsureDB().gcdCustomHex = h end,
           "Inner GCD Ring Colour", GetBaseRingRGB)
        AddSlider(grpGcd, "Inner GCD Opacity", "Transparency of the inner Global Cooldown ring.", 0.10, 1.00, 0.05,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return EnsureDB().gcdOpacity or 0.85 end, function(v) EnsureDB().gcdOpacity = v end)

        local secCast = AddSection(2, "OUTER CAST / CHANNEL / EMPOWER ARC", "Outer progress ring tracking spell casts, channels, and empowered spells with an interrupt flash.")
        local grpCast = AddGroupCard(secCast, "castCore", "Outer Cast / Channel / Empower Arc", "Shows your spell cast, channel, or empower progress around the ring with an interrupt flash.",
            function() return EnsureDB().castArcEnabled ~= false end, function(v) EnsureDB().castArcEnabled = v end)
        AddSlider(grpCast, "Outer Cast Arc Gap", "Outward spacing beyond the main cursor ring (0 to 24 px).", 0, 24, 1,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().castGap or 4 end, function(v) EnsureDB().castGap = v end)
        AddPills(grpCast, "Outer Cast Arc Style", "Choose the line thickness for the outer cast arc.", 210, {
            { value = "THIN", label = "Thin" }, { value = "CRISP", label = "Crisp" }, { value = "THICK", label = "Thick" },
        }, function() return EnsureDB().castStyle or "THIN" end, function(v) EnsureDB().castStyle = v end)
        AddColorModeDropdown(grpCast, "Outer Cast Arc Colour Mode", "Match the cursor ring or pick an independent colour for the outer cast arc.", 210, {
            { value = "MATCH_RING", label = "Match Ring" },
            { value = "ACCENT",     label = "Suite Accent" },
            { value = "CLASS",      label = "Class Colour" },
            { value = "CUSTOM",     label = "Custom Colour" },
        }, function() return EnsureDB().castColorMode or "MATCH_RING" end, function(v) EnsureDB().castColorMode = v end,
           function() return EnsureDB().castCustomHex or "F59E0B" end, function(h) EnsureDB().castCustomHex = h end,
           "Outer Cast Arc Colour", GetBaseRingRGB)
        AddSlider(grpCast, "Outer Cast Arc Opacity", "Transparency of the outer cast, channel, or empower arc.", 0.10, 1.00, 0.05,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return EnsureDB().castOpacity or 0.92 end, function(v) EnsureDB().castOpacity = v end)
        AddColorModeDropdown(grpCast, "Interrupt Flash Colour", "Colour flashed briefly on the cast arc and icon border when a spell is interrupted.", 210, {
            { value = "CRIMSON",     label = "Crimson Red" },
            { value = "BRIGHT_GOLD", label = "Bright Gold" },
            { value = "CUSTOM",      label = "Custom Colour" },
        }, function() return EnsureDB().castInterruptColorMode or "CRIMSON" end, function(v) EnsureDB().castInterruptColorMode = v end,
           function() return EnsureDB().castInterruptCustomHex or "F23838" end, function(h) EnsureDB().castInterruptCustomHex = h end,
           "Interrupt Flash Colour", nil)

        local secIcon = AddSection(2, "MINI SPELL ICON", "Shows a bordered spell icon anchored cleanly to your outer cast arc or cursor ring.")
        local grpIcon = AddGroupCard(secIcon, "castIconCore", "Show Mini Spell Icon on Cast", "Displays the active spell icon beside your cursor ring while casting.",
            function() return EnsureDB().castShowIcon == true end, function(v) EnsureDB().castShowIcon = v end)
        AddSlider(grpIcon, "Mini Spell Icon Size", "Adjust the mini spell icon size in pixels (14 to 32 px).", 14, 32, 1,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().castIconSize or 20 end, function(v) EnsureDB().castIconSize = v end)
        AddDropdown(grpIcon, "Mini Spell Icon Position", "Choose which side of the outer cast arc the spell icon appears on.", 220, {
            { value = "TOP",    label = "Top" },
            { value = "BOTTOM", label = "Bottom" },
            { value = "LEFT",   label = "Left" },
            { value = "RIGHT",  label = "Right" },
            { value = "CENTER", label = "Inside Centre" },
        }, function() return EnsureDB().castIconPos or "TOP" end, function(v) EnsureDB().castIconPos = v end)
        AddSlider(grpIcon, "Mini Spell Icon Gap", "Distance between the outer arc edge and the spell icon (2 to 24 px).", 2, 24, 1,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().castIconGap or 6 end, function(v) EnsureDB().castIconGap = v end)
        AddToggle(grpIcon, "Flash Icon on Instant Casts", "Briefly flashes and fades the spell icon (0.55s) when you cast an instant spell.",
            function() return EnsureDB().castInstantFlash == true end, function(v) EnsureDB().castInstantFlash = v end)

        -- ====================================================================
        -- TAB 3: Crosshair & Locator
        -- ====================================================================
        local secCross = AddSection(3, "CHARACTER CROSSHAIR", "Screen-centre reference crosshair for melee range and positioning.")
        local grpCross = AddGroupCard(secCross, "crosshairCore", "Enable Character Crosshair", "Displays a screen-centre crosshair around your character (Off by default).",
            function() return EnsureDB().crosshairEnabled == true end, function(v) EnsureDB().crosshairEnabled = v end)
        do
            local elemRow = CreateSubRow(grpCross, "Crosshair Elements", "Mix and match any combination of crosshair, bracket, circle, or centre dot elements.", 0, 90)

            local elemDefs = {
                { key = "crosshairShowCross",    label = "Crosshair",  w = 92 },
                { key = "crosshairShowBrackets", label = "Brackets",   w = 88 },
                { key = "crosshairShowCircle",   label = "Circle",     w = 76 },
                { key = "crosshairShowDot",      label = "Centre Dot", w = 96 },
            }
            local eBtns = {}
            local function ReflowElemBtns()
                local rowW = elemRow:GetWidth() or 520
                if rowW < 220 then return end
                local leftPad = 22
                local rightPad = 14
                local gap = 6
                local avail = math.max(180, rowW - leftPad - rightPad - (gap * (#eBtns - 1)))
                local sumW = 0
                for _, ed in ipairs(elemDefs) do sumW = sumW + ed.w end
                local ex = leftPad
                for i, eb in ipairs(eBtns) do
                    eb:ClearAllPoints()
                    eb:SetHeight(26)
                    if i == #eBtns then
                        eb:SetPoint("BOTTOMLEFT", elemRow, "BOTTOMLEFT", ex, 10)
                        eb:SetPoint("BOTTOMRIGHT", elemRow, "BOTTOMRIGHT", -rightPad, 10)
                    else
                        local bw = math.max(54, math.floor((avail * elemDefs[i].w) / sumW))
                        eb:SetWidth(bw)
                        eb:SetPoint("BOTTOMLEFT", elemRow, "BOTTOMLEFT", ex, 10)
                        ex = ex + bw + gap
                    end
                end
            end
            for i, ed in ipairs(elemDefs) do
                local eb = CreateFrame("Button", nil, elemRow, "BackdropTemplate")
                eb:SetSize(ed.w, 26)
                eb.lbl = eb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                SetSafeFont(eb.lbl, 11, "")
                eb.lbl:SetPoint("LEFT", eb, "LEFT", 4, 0)
                eb.lbl:SetPoint("RIGHT", eb, "RIGHT", -4, 0)
                eb.lbl:SetJustifyH("CENTER")
                eb.lbl:SetWordWrap(false)
                eb.lbl:SetText(ed.label)
                eb.ed = ed
                eb:SetScript("OnEnter", function(selfBtn)
                    local db = EnsureDB()
                    if db[ed.key] ~= true then
                        local ar, ag, ab = GetSuiteAccent()
                        selfBtn:SetBackdropBorderColor(ar, ag, ab, 0.70)
                    end
                end)
                eb:SetScript("OnLeave", function() elemRow:RefreshValue() end)
                eb:SetScript("OnClick", function()
                    local db = EnsureDB()
                    db[ed.key] = not (db[ed.key] == true)
                    SyncAllEngines()
                    DynamicCursor:RefreshWorkspaceUI()
                end)
                eBtns[i] = eb
            end

            function elemRow:RefreshValue()
                ReflowElemBtns()
                local db = EnsureDB()
                local ar, ag, ab = GetSuiteAccent()
                local alphaPill = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42
                for _, eb in ipairs(eBtns) do
                    local active = (db[eb.ed.key] == true)
                    if active then
                        SetBackdropSolid(eb, { ar * alphaPill, ag * alphaPill, ab * alphaPill, 0.98 }, { ar, ag, ab, 0.95 }, 1)
                        eb.lbl:SetTextColor(1, 1, 1, 1)
                    else
                        SetBackdropSolid(eb, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)
                        eb.lbl:SetTextColor(0.68, 0.74, 0.82, 1)
                    end
                end
            end

            elemRow:SetScript("OnSizeChanged", ReflowElemBtns)
            ReflowElemBtns()
            grpCross.rows[#grpCross.rows + 1] = elemRow
            refreshables[#refreshables + 1] = elemRow
        end
        AddSlider(grpCross, "Crosshair / Bracket Span", "Overall crosshair or bracket span in pixels (8 to 64 px).", 8, 64, 2,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().crosshairSize or 24 end, function(v) EnsureDB().crosshairSize = v end, IsCrosshairLinesOn)
        AddSlider(grpCross, "Line Thickness", "Crosshair and bracket line thickness (1 to 6 px).", 1, 6, 1,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().crosshairThickness or 2 end, function(v) EnsureDB().crosshairThickness = v end, IsCrosshairLinesOn)
        AddSlider(grpCross, "Centre Gap", "Inner gap around the centre point for the 4-arm crosshair (0 to 20 px).", 0, 20, 1,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().crosshairGap or 6 end, function(v) EnsureDB().crosshairGap = v end, IsCrosshairCrossOn)
        AddSlider(grpCross, "Circle Radius", "Radius of the character crosshair circle in pixels (8 to 64 px).", 8, 64, 2,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().crosshairCircleRadius or 24 end, function(v) EnsureDB().crosshairCircleRadius = v end, IsCrosshairCircleOn)
        AddSlider(grpCross, "Circle Thickness", "Line thickness for the character crosshair circle (1 to 5).", 1, 5, 1,
            function(v) return string.format("%d / 5", v) end,
            function() return EnsureDB().crosshairCircleThickness or 2 end, function(v) EnsureDB().crosshairCircleThickness = v end, IsCrosshairCircleOn)
        AddSlider(grpCross, "Centre Dot Size", "Size of the character crosshair centre dot in pixels (2 to 8 px).", 2, 8, 1,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().crosshairDotSize or 4 end, function(v) EnsureDB().crosshairDotSize = v end, IsCrosshairDotOn)
        AddToggle(grpCross, "High-Contrast Outline", "Adds a crisp dark outline behind active crosshair lines, brackets, circle, and centre dot.",
            function() return EnsureDB().crosshairOutline ~= false end, function(v) EnsureDB().crosshairOutline = v end)
        AddSlider(grpCross, "Horizontal Offset (X)", "Nudge crosshair left or right from screen centre (-100 to +100 px).", -100, 100, 2,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().crosshairOffsetX or 0 end, function(v) EnsureDB().crosshairOffsetX = v end)
        AddSlider(grpCross, "Vertical Offset (Y)", "Nudge crosshair up or down from screen centre (-100 to +100 px).", -100, 100, 2,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().crosshairOffsetY or 0 end, function(v) EnsureDB().crosshairOffsetY = v end)
        AddDropdown(grpCross, "Crosshair Visibility", "Choose when the character crosshair appears.", 220, {
            { value = "ALWAYS",              label = "Always" },
            { value = "COMBAT_ONLY",         label = "In Combat Only" },
            { value = "INSTANCES_ONLY",      label = "Instances Only" },
            { value = "COMBAT_IN_INSTANCES", label = "Combat in Instances" },
        }, function() return EnsureDB().crosshairVisibility or "ALWAYS" end, function(v) EnsureDB().crosshairVisibility = v end)
        AddSlider(grpCross, "Crosshair Out-of-Combat Opacity", "Crosshair transparency out of combat.", 0.05, 1.00, 0.05,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return EnsureDB().crosshairOpacityOOC or 0.45 end, function(v) EnsureDB().crosshairOpacityOOC = v end)
        AddSlider(grpCross, "Crosshair In-Combat Opacity", "Crosshair transparency during combat.", 0.05, 1.00, 0.05,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return EnsureDB().crosshairOpacityCombat or 0.90 end, function(v) EnsureDB().crosshairOpacityCombat = v end)
        AddColorModeDropdown(grpCross, "Crosshair Colour Mode", "Follow your Suite Accent, Class Colour, High-Vis Green, or click the swatch for a custom colour.", 210, {
            { value = "ACCENT",         label = "Suite Accent" },
            { value = "CLASS",          label = "Class Colour" },
            { value = "HIGH_VIS_GREEN", label = "High-Vis Green" },
            { value = "CUSTOM",         label = "Custom Colour" },
        }, function() return EnsureDB().crosshairColorMode or "ACCENT" end, function(v) EnsureDB().crosshairColorMode = v end,
           function() return EnsureDB().crosshairCustomHex or "38BDF8" end, function(h) EnsureDB().crosshairCustomHex = h end,
           "Crosshair Custom Colour", nil)
        AddToggle(grpCross, "Crosshair Combat Tint", "Shifts the crosshair colour to warm amber-orange during combat.",
            function() return EnsureDB().crosshairCombatTint == true end, function(v) EnsureDB().crosshairCombatTint = v end)

        local secLoc = AddSection(3, "FIND MY CURSOR", "Quickly locate your mouse pointer during hectic raid or Mythic+ pulls.")
        local grpShake = AddGroupCard(secLoc, "shakeCore", "Shake-to-Find", "Rapidly wiggle your mouse back and forth to trigger a brief cursor ping burst.",
            function() return EnsureDB().shakeToFind == true end, function(v) EnsureDB().shakeToFind = v end)
        AddPills(grpShake, "Shake Sensitivity", "Adjusts how briskly you need to wiggle the mouse to trigger Shake-to-Find.", 210, {
            { value = "LOW", label = "Low" }, { value = "MEDIUM", label = "Medium" }, { value = "HIGH", label = "High" },
        }, function() return EnsureDB().shakeSensitivity or "MEDIUM" end, function(v) EnsureDB().shakeSensitivity = v end)

        local grpMousePing = AddGroupCard(secLoc, "mouseLookPingCore", "Ping After Mouse-Look", "Briefly pulses your cursor locator when you finish Right-Click camera turning.",
            function() return EnsureDB().pingAfterMouseLook == true end, function(v) EnsureDB().pingAfterMouseLook = v end)
        AddSlider(grpMousePing, "Mouse-Look Ping Duration", "How long the cursor locator stays visible after releasing Right-Click (0.30s to 1.50s).", 0.30, 1.50, 0.05,
            function(v) return string.format("%.2fs", v) end,
            function() return EnsureDB().mouseLookPingDuration or 0.65 end, function(v) EnsureDB().mouseLookPingDuration = v end)

        AddPills(secLoc, "Modifier Key Locator", "Hold a modifier key to highlight your cursor.", 260, {
            { value = "OFF", label = "Off" }, { value = "SHIFT", label = "Shift" }, { value = "CTRL", label = "Ctrl" }, { value = "ALT", label = "Alt" },
        }, function() return EnsureDB().locatorModifier or "OFF" end, function(v) EnsureDB().locatorModifier = v end)
        AddPills(secLoc, "Locator Highlight Style", "Visual cue shown for Shake-to-Find, Ping After Mouse-Look, and Modifier Locator.", 260, {
            { value = "PING", label = "Ping Ring" }, { value = "SPOTLIGHT", label = "Spotlight" }, { value = "CROSSHAIR", label = "Screen Cross" },
        }, function() return EnsureDB().locatorStyle or "PING" end, function(v) EnsureDB().locatorStyle = v end)
        AddSlider(secLoc, "Locator Highlight Scale", "Scale of the Ping Ring, Spotlight, or Screen Cross locator (60% to 160%).", 0.60, 1.60, 0.10,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return EnsureDB().locatorScale or 1.00 end, function(v) EnsureDB().locatorScale = v end)
        AddColorModeDropdown(secLoc, "Locator Colour Mode", "Choose an independent colour for Find My Cursor or match your main cursor ring.", 210, {
            { value = "MATCH_RING",     label = "Match Ring" },
            { value = "ACCENT",         label = "Suite Accent" },
            { value = "CLASS",          label = "Class Colour" },
            { value = "HIGH_VIS_GREEN", label = "High-Vis Green" },
            { value = "BRIGHT_GOLD",    label = "Bright Gold" },
            { value = "CUSTOM",         label = "Custom Colour" },
        }, function() return EnsureDB().locatorColorMode or "MATCH_RING" end, function(v) EnsureDB().locatorColorMode = v end,
           function() return EnsureDB().locatorCustomHex or "38BDF8" end, function(h) EnsureDB().locatorCustomHex = h end,
           "Locator Custom Colour", GetBaseRingRGB)

        -- ====================================================================
        -- TAB 4: Visibility & Tooltips
        -- ====================================================================
        local secVis = AddSection(4, "ACTIVITY VISIBILITY", "Choose which content types show the cursor ring and auto-hide during special modes.")
        do
            local zoneRow = CreateSettingCard(secVis, "Active Zones", "Toggle individual content types or click All Zones to enable all five.", 0, 92)

            local zoneDefs = {
                { key = "ALL",           label = "All Zones",  w = 82 },
                { key = "showOpenWorld", label = "Open World", w = 92 },
                { key = "showDelves",    label = "Delves",     w = 68 },
                { key = "showDungeons",  label = "Dungeons",   w = 82 },
                { key = "showRaids",     label = "Raids",      w = 64 },
                { key = "showPvP",       label = "PvP",        w = 54 },
            }
            local zBtns = {}
            local function ReflowZoneBtns()
                local rowW = zoneRow:GetWidth() or 538
                if rowW < 240 then return end
                local leftPad = 14
                local rightPad = 14
                local gap = 5
                local avail = math.max(200, rowW - leftPad - rightPad - (gap * (#zBtns - 1)))
                local sumW = 0
                for _, zd in ipairs(zoneDefs) do sumW = sumW + zd.w end
                local zx = leftPad
                for i, zb in ipairs(zBtns) do
                    zb:ClearAllPoints()
                    zb:SetHeight(26)
                    if i == #zBtns then
                        zb:SetPoint("BOTTOMLEFT", zoneRow, "BOTTOMLEFT", zx, 10)
                        zb:SetPoint("BOTTOMRIGHT", zoneRow, "BOTTOMRIGHT", -rightPad, 10)
                    else
                        local bw = math.max(40, math.floor((avail * zoneDefs[i].w) / sumW))
                        zb:SetWidth(bw)
                        zb:SetPoint("BOTTOMLEFT", zoneRow, "BOTTOMLEFT", zx, 10)
                        zx = zx + bw + gap
                    end
                end
            end
            for i, zd in ipairs(zoneDefs) do
                local zb = CreateFrame("Button", nil, zoneRow, "BackdropTemplate")
                zb:SetSize(zd.w, 26)
                zb.lbl = zb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                SetSafeFont(zb.lbl, 10.5, "")
                zb.lbl:SetPoint("LEFT", zb, "LEFT", 3, 0)
                zb.lbl:SetPoint("RIGHT", zb, "RIGHT", -3, 0)
                zb.lbl:SetJustifyH("CENTER")
                zb.lbl:SetWordWrap(false)
                zb.lbl:SetText(zd.label)
                zb.zd = zd
                zb:SetScript("OnEnter", function(selfBtn)
                    local db = EnsureDB()
                    local allOn = (db.showOpenWorld ~= false) and (db.showDelves ~= false)
                        and (db.showDungeons ~= false) and (db.showRaids ~= false) and (db.showPvP ~= false)
                    local active = (zd.key == "ALL") and allOn or (db[zd.key] ~= false)
                    if not active then
                        local ar, ag, ab = GetSuiteAccent()
                        selfBtn:SetBackdropBorderColor(ar, ag, ab, 0.70)
                    end
                end)
                zb:SetScript("OnLeave", function() zoneRow:RefreshValue() end)
                zb:SetScript("OnClick", function()
                    local db = EnsureDB()
                    if zd.key == "ALL" then
                        db.showOpenWorld = true
                        db.showDelves = true
                        db.showDungeons = true
                        db.showRaids = true
                        db.showPvP = true
                    else
                        db[zd.key] = not (db[zd.key] ~= false)
                    end
                    SyncAllEngines()
                    DynamicCursor:RefreshWorkspaceUI()
                end)
                zBtns[i] = zb
            end

            function zoneRow:RefreshValue()
                ReflowZoneBtns()
                local db = EnsureDB()
                local ar, ag, ab = GetSuiteAccent()
                local alphaPill = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42
                local allOn = (db.showOpenWorld ~= false) and (db.showDelves ~= false)
                    and (db.showDungeons ~= false) and (db.showRaids ~= false) and (db.showPvP ~= false)
                for _, zb in ipairs(zBtns) do
                    local active = (zb.zd.key == "ALL") and allOn or (db[zb.zd.key] ~= false)
                    if active then
                        SetBackdropSolid(zb, { ar * alphaPill, ag * alphaPill, ab * alphaPill, 0.98 }, { ar, ag, ab, 0.95 }, 1)
                        zb.lbl:SetTextColor(1, 1, 1, 1)
                    else
                        SetBackdropSolid(zb, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)
                        zb.lbl:SetTextColor(0.68, 0.74, 0.82, 1)
                    end
                end
            end

            zoneRow:SetScript("OnSizeChanged", ReflowZoneBtns)
            ReflowZoneBtns()
            secVis.cards[#secVis.cards + 1] = zoneRow
            refreshables[#refreshables + 1] = zoneRow
        end
        AddToggle(secVis, "Auto-Hide in Pet Battles, Vehicles & Cutscenes", "Temporarily hides cursor overlays during pet battles, vehicles, and movies.",
            function() return EnsureDB().autoHideSpecial ~= false end, function(v) EnsureDB().autoHideSpecial = v end)

        local secSys = AddSection(4, "CURSOR & LAYER SYSTEM", "Adjust WoW's built-in mouse pointer size and how cursor overlays layer above interface panels.")
        AddDropdown(secSys, "Built-In Mouse Pointer Size", "Adjusts WoW's built-in mouse pointer size while out of combat.", 220, {
            { value = "-1", label = "Automatic (Default)" },
            { value = "0",  label = "32 x 32" },
            { value = "1",  label = "48 x 48" },
            { value = "2",  label = "64 x 64" },
            { value = "3",  label = "96 x 96" },
            { value = "4",  label = "128 x 128" },
        }, GetNativeCursorSize, SetNativeCursorSize)
        AddPills(secSys, "Overlay Layer Priority", "Controls how high cursor overlays appear above interface windows.", 268, {
            { value = "HIGH", label = "Standard" }, { value = "DIALOG", label = "Above Windows" }, { value = "TOOLTIP", label = "Topmost" },
        }, function() return EnsureDB().ringStrata or "TOOLTIP" end, function(v) EnsureDB().ringStrata = v end)

        local secTip = AddSection(4, "SMART CURSOR TOOLTIPS", "Optionally anchor mouseover tooltips near your cursor with automatic screen-edge flipping.")
        local grpTip = AddGroupCard(secTip, "tooltipCore", "Anchor Tooltips to Cursor", "Moves mouseover tooltips beside your pointer (Off by default).",
            function() return EnsureDB().tooltipEnabled == true end, function(v) EnsureDB().tooltipEnabled = v end)
        AddSlider(grpTip, "Tooltip Horizontal Offset (X)", "Horizontal gap from your cursor (-60 to +60 px).", -60, 60, 2,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().tooltipOffsetX or 18 end, function(v) EnsureDB().tooltipOffsetX = v end)
        AddSlider(grpTip, "Tooltip Vertical Offset (Y)", "Vertical gap from your cursor (-60 to +60 px).", -60, 60, 2,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().tooltipOffsetY or -18 end, function(v) EnsureDB().tooltipOffsetY = v end)
        AddToggle(grpTip, "Automatic Screen-Edge Flip", "Automatically flips tooltips inward when your cursor is near the edge of the screen.",
            function() return EnsureDB().tooltipEdgeFlip ~= false end, function(v) EnsureDB().tooltipEdgeFlip = v end)
        AddDropdown(grpTip, "Tooltip Combat Behaviour", "Choose how cursor tooltips behave during combat.", 240, {
            { value = "KEEP",       label = "Keep at Cursor" },
            { value = "CORNER",     label = "Snap to Default Corner" },
            { value = "HIDE_SHIFT", label = "Hide in Combat (Hold Shift)" },
        }, function() return EnsureDB().tooltipCombatMode or "KEEP" end, function(v) EnsureDB().tooltipCombatMode = v end)

        for _, pg in ipairs(pages) do LayoutPage(pg) end

        function DynamicCursor:RefreshWorkspaceUI(resetScroll)
            local db = EnsureDB()
            local ar, ag, ab = GetSuiteAccent()
            local alphaPill = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42

            ReflowTabBar()
            ReflowPresets()
            local sfW = (sf and sf.GetWidth and sf:GetWidth()) or 0
            if sfW > 40 then
                content:SetWidth(sfW)
            end

            for _, pb in ipairs(presetBtns) do
                StylePresetBtn(pb, pb:IsMouseOver())
            end

            local activeTab = tonumber(db.activeSubTab) or 1
            if activeTab < 1 or activeTab > 4 then activeTab = 1 end
            for i, tb in ipairs(tabBtns) do
                if i == activeTab then
                    SetBackdropSolid(tb, { ar * alphaPill, ag * alphaPill, ab * alphaPill, 0.98 }, { ar, ag, ab, 0.95 }, 1)
                    tb.lbl:SetTextColor(1, 1, 1, 1)
                else
                    SetBackdropSolid(tb, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)
                    tb.lbl:SetTextColor(0.68, 0.74, 0.82, 1)
                end
            end
            for _, sec in ipairs(sections) do sec:RefreshAccent() end
            for _, rCtrl in ipairs(refreshables) do
                if rCtrl.RefreshValue then rCtrl:RefreshValue() end
            end
            for i, pg in ipairs(pages) do
                if i == activeTab then
                    LayoutPage(pg)
                    pg:Show()
                    content:SetHeight(math.max(100, pg:GetHeight() or 100))
                else
                    pg:Hide()
                end
            end
            if resetScroll == true then
                sf:SetVerticalScroll(0)
            else
                local maxS = math.max(0, (content:GetHeight() or 0) - (sf:GetHeight() or 0))
                local curS = (sf.GetVerticalScroll and sf:GetVerticalScroll()) or 0
                if curS > maxS then
                    sf:SetVerticalScroll(maxS)
                elseif curS < 0 then
                    sf:SetVerticalScroll(0)
                end
            end
            UpdateScrollBar()
            if (sf:GetHeight() or 0) <= 1 and _G.C_Timer and type(_G.C_Timer.After) == "function" then
                _G.C_Timer.After(0, UpdateScrollBar)
            end
            if _G.DynamicSuite and type(_G.DynamicSuite.UpdateHeaderTelemetry) == "function" then
                pcall(_G.DynamicSuite.UpdateHeaderTelemetry)
            end
        end

        root:SetScript("OnShow", function()
            ReflowTabBar()
            DynamicCursor:RefreshWorkspaceUI()
        end)

        DynamicCursor:RefreshWorkspaceUI(true)
        return root
    end
    DynamicCursor.RenderEmbedded = RenderCursorEmbedded

    local function OpenStandaloneWindow()
        if InCombatLockdown and InCombatLockdown() then
            PrintMsg("Cannot open the settings window during combat.")
            return
        end
        if _G.DynamicSuite and type(_G.DynamicSuite.OpenModule) == "function" and not IsModuleDisabledInSuite("DynamicCursor") then
            _G.DynamicSuite:OpenModule("cursor")
            return
        end
        if not DynamicCursor.standaloneFrame then
            local ar0, ag0, ab0 = GetSuiteAccent()
            local f = CreateFrame("Frame", "DynamicCursorStandaloneFrame", UIParent, "BackdropTemplate")
            f:SetSize(880, 620)
            f:SetPoint("CENTER")
            f:SetMovable(true)
            f:SetResizable(true)
            if f.SetResizeBounds then f:SetResizeBounds(760, 480, 1280, 860) end
            f:EnableMouse(true)
            f:RegisterForDrag("LeftButton")
            f:SetScript("OnDragStart", f.StartMoving)
            f:SetScript("OnDragStop", f.StopMovingOrSizing)
            f:SetScript("OnHide", CloseCursorPopups)
            f:SetClampedToScreen(true)
            f:SetFrameStrata("DIALOG")
            SetBackdropSolid(f, { 0.035, 0.039, 0.051, 0.99 }, { ar0, ag0, ab0, 0.90 }, 1)

            local hdr = CreateFrame("Frame", nil, f, "BackdropTemplate")
            hdr:SetHeight(42)
            hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
            hdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
            SetBackdropSolid(hdr, { 0.015, 0.018, 0.024, 1.00 }, { 0.145, 0.165, 0.212, 0.95 }, 1)

            local topLine = hdr:CreateTexture(nil, "OVERLAY")
            topLine:SetHeight(2)
            topLine:SetPoint("TOPLEFT", hdr, "TOPLEFT", 0, 0)
            topLine:SetPoint("TOPRIGHT", hdr, "TOPRIGHT", 0, 0)
            topLine:SetColorTexture(ar0, ag0, ab0, 1.0)
            hdr.topLine = topLine

            local closeBtn = CreateFrame("Button", nil, hdr, "BackdropTemplate")
            closeBtn:SetSize(24, 24)
            closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -10, 0)
            SetBackdropSolid(closeBtn, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)
            local xLbl = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            SetSafeFont(xLbl, 11, "")
            xLbl:SetPoint("CENTER")
            xLbl:SetText("X")
            closeBtn:SetScript("OnClick", function() f:Hide() end)

            local title = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            SetSafeFont(title, 13, "")
            title:SetPoint("LEFT", hdr, "LEFT", 14, 0)
            title:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
            title:SetJustifyH("LEFT")
            title:SetWordWrap(false)
            title:SetText(string.format("|cFF%sDynamic|r|cFFFFFFFFCursor|r  |cFF94A3B8v%s|r", GetAccentHex(), VERSION))
            hdr.title = title

            local footer = CreateFrame("Frame", nil, f, "BackdropTemplate")
            footer:SetHeight(36)
            footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
            footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
            SetBackdropSolid(footer, { 0.015, 0.018, 0.024, 1.00 }, { 0.145, 0.165, 0.212, 0.95 }, 1)

            local resetBtn = CreateFrame("Button", nil, footer, "BackdropTemplate")
            resetBtn:SetSize(148, 24)
            resetBtn:SetPoint("LEFT", footer, "LEFT", 14, 0)
            SetBackdropSolid(resetBtn, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)
            local rstLbl = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            SetSafeFont(rstLbl, 10.5, "")
            rstLbl:SetPoint("CENTER")
            rstLbl:SetText("Reset DynamicCursor")
            resetBtn:SetScript("OnClick", ResetCursorModuleDefaults)

            local reloadBtn = CreateFrame("Button", nil, footer, "BackdropTemplate")
            reloadBtn:SetSize(92, 24)
            reloadBtn:SetPoint("RIGHT", footer, "RIGHT", -32, 0)
            SetBackdropSolid(reloadBtn, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)
            local relLbl = reloadBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            SetSafeFont(relLbl, 10.5, "")
            relLbl:SetPoint("CENTER")
            relLbl:SetText("Reload UI")
            reloadBtn:SetScript("OnClick", function() if type(_G.ReloadUI) == "function" then _G.ReloadUI() end end)

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
            grip:SetScript("OnEnter", function()
                local ar, ag, ab = GetSuiteAccent()
                gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
                gripTex:SetDesaturated(false)
                gripTex:SetVertexColor(ar, ag, ab, 0.95)
            end)
            grip:SetScript("OnLeave", function()
                gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
                gripTex:SetDesaturated(true)
                gripTex:SetVertexColor(0.55, 0.58, 0.65, 0.75)
            end)
            grip:SetScript("OnMouseDown", function(_, btn)
                if btn == "LeftButton" then
                    CloseCursorPopups()
                    f:StartSizing("BOTTOMRIGHT")
                elseif btn == "RightButton" then
                    f:SetSize(880, 620)
                end
            end)
            grip:SetScript("OnMouseUp", function()
                f:StopMovingOrSizing()
            end)

            local body = CreateFrame("Frame", nil, f)
            body:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, 0)
            body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
            RenderCursorEmbedded(body)

            function f:RefreshTheme()
                local ar, ag, ab = GetSuiteAccent()
                self:SetBackdropBorderColor(ar, ag, ab, 0.90)
                if hdr.topLine then hdr.topLine:SetColorTexture(ar, ag, ab, 1.0) end
                if hdr.title then
                    hdr.title:SetText(string.format("|cFF%sDynamic|r|cFFFFFFFFCursor|r  |cFF94A3B8v%s|r", GetAccentHex(), VERSION))
                end
            end

            if type(UISpecialFrames) == "table" then
                table.insert(UISpecialFrames, "DynamicCursorStandaloneFrame")
            end
            DynamicCursor.standaloneFrame = f
        end
        DynamicCursor.standaloneFrame:RefreshTheme()
        DynamicCursor.standaloneFrame:Show()
        DynamicCursor:RefreshWorkspaceUI()
    end
    DynamicCursor.OpenWorkspace = OpenStandaloneWindow
end

-- ============================================================================
-- 5. SUITE REGISTRATION, CHANGELOG & SLASH COMMANDS
-- ============================================================================
DynamicCursor.CHANGELOG = {
    version = VERSION,
    date = "27/11/2026",
    entries = {
        { type = "PERF",    text = "Smart Tooltip Hover Cache (27/11/2026): Cached the module-disabled state across lifecycle and suite enable/disable events so GameTooltip_SetDefaultAnchor no longer invokes pcall(IsModuleDisabled) on every tooltip hover." },
        { type = "UI",      text = "Release v2.10.2 - Pass 6 800x520 Layout Sweep, Standalone Window Parity & Plain-English Copy (25/11/2026): Made DynamicCursorStandaloneFrame resizable (760x480 to 1280x860) with a 36px Reset/Reload footer, 14x14 live-accent resize grip, and ApplyTheme border/header repaint; reflowed Tab 1 Quick Presets proportionally across the card width; fixed Tab 3 Crosshair Elements and Tab 4 Active Zones so descriptions wrap cleanly beneath titles with responsive pills; right-clamped all setting cards and sub-rows against their controls at 800x520; and updated Overlay Layer Priority (Standard / Above Windows / Topmost), Built-In Mouse Pointer Size (Automatic Default), and All Overlays preset labels in plain Australian English." },
        { type = "FEATURE", text = "Release v2.8.2 - New 13th Dual-Mode Module: DynamicCursor (/dcur, /dynamiccursor) (24/11/2026): Launched DynamicCursor with 4 Obsidian tabs built on enclosing Section Containers, individual setting cards, collapsible Sub-Settings (N) drawers (2px Suite Accent rail + 5x5px square pip), a 4px 3-way scrollbar, smooth 12x12 live Suite Accent dropdown chevrons, and 4 Quick Presets (Clean Raid, High-Visibility, Minimalist, All Overlays). Includes Main Cursor Ring (Solid Ring, Soft Glow, High-Contrast Dual across 5 thickness levels, Extra Ring Contrast dark outline behind all rings and crosshair circle, Centre Dot size & colour, Ground-Target AoE Highlight & +20% Size Boost, Mouse-Look ghost opacity, Click-Pulse scale & colour), Inner GCD Ring (6 px default gap), Outer Cast/Channel/Empower Arc (4 px default gap, Interrupt Flash Colour, Mini Spell Icon & Instant-Cast Flash), modular Character Crosshair, Find My Cursor (Shake-to-Find sensitivity, Ping After Mouse-Look duration, Modifier Key Locator, Locator Highlight Scale & colour), Pooled Cursor Trail, Active Zones, built-in mouse pointer size, and Smart Cursor Tooltips." },
    },
}

if _G.DynamicSuite then
    _G.DynamicSuite.modules = _G.DynamicSuite.modules or {}
    _G.DynamicSuite.Changelogs = _G.DynamicSuite.Changelogs or {}
    _G.DynamicSuite.Changelogs["DynamicCursor"] = DynamicCursor.CHANGELOG
    _G.DynamicSuite.Changelogs["cursor"] = DynamicCursor.CHANGELOG

    local desc = {
        key = "cursor",
        id = "cursor",
        name = "DynamicCursor",
        title = "DynamicCursor",
        addonName = "DynamicCursor",
        version = VERSION,
        slash = "/dcur",
        icon = ICON_MODULE,
        subtitle = "Cursor Ring, Crosshair & Trail",
        desc = "Customisable cursor ring with radial GCD and cast/channel/empower arcs, character crosshair, Find My Cursor locator, pooled cursor trail, and smart cursor tooltips.",
        Render = function(a1, a2) return DynamicCursor.RenderEmbedded(a1, a2) end,
        RenderEmbedded = function(a1, a2) return DynamicCursor.RenderEmbedded(a1, a2) end,
        BuildWorkspace = function(a1, a2) return DynamicCursor.RenderEmbedded(a1, a2) end,
        ApplyTheme = function()
            if SyncAllEngines then SyncAllEngines() end
            if DynamicCursor.standaloneFrame and DynamicCursor.standaloneFrame.RefreshTheme then
                DynamicCursor.standaloneFrame:RefreshTheme()
            end
            if DynamicCursor.RefreshWorkspaceUI then DynamicCursor:RefreshWorkspaceUI() end
        end,
        ApplyThemeToUI = function()
            if SyncAllEngines then SyncAllEngines() end
            if DynamicCursor.standaloneFrame and DynamicCursor.standaloneFrame.RefreshTheme then
                DynamicCursor.standaloneFrame:RefreshTheme()
            end
            if DynamicCursor.RefreshWorkspaceUI then DynamicCursor:RefreshWorkspaceUI() end
        end,
        ResetModuleDefaults = ResetCursorModuleDefaults,
        ResetDefaults = ResetCursorModuleDefaults,
        Reset = ResetCursorModuleDefaults,
        OpenWorkspace = function() return DynamicCursor.OpenWorkspace() end,
        GetStatusText = GetStatusText,
        OnDisableInSuite = function()
            if DynamicCursor.SyncAllEngines then DynamicCursor.SyncAllEngines() else SyncAllEngines() end
        end,
        OnEnableInSuite = function()
            if DynamicCursor.SyncAllEngines then DynamicCursor.SyncAllEngines() else SyncAllEngines() end
        end,
        GetChangelog = function() return DynamicCursor.CHANGELOG end,
        SelectSubTab = function(a1, a2)
            local idx = (type(a1) == "number") and a1 or a2 or 1
            local db = EnsureDB()
            local changed = (db.activeSubTab ~= idx)
            db.activeSubTab = idx
            if DynamicCursor.RefreshWorkspaceUI then DynamicCursor:RefreshWorkspaceUI(changed) end
        end,
    }
    desc.SelectTab = desc.SelectSubTab

    -- Mirror self-safe wrapper methods onto DynamicCursor directly so both direct and descriptor calls work identically
    DynamicCursor.Render = desc.Render
    DynamicCursor.BuildWorkspace = desc.BuildWorkspace
    DynamicCursor.ApplyTheme = desc.ApplyTheme
    DynamicCursor.ApplyThemeToUI = desc.ApplyThemeToUI
    DynamicCursor.GetStatusText = desc.GetStatusText
    DynamicCursor.OnEnableInSuite = desc.OnEnableInSuite
    DynamicCursor.OnDisableInSuite = desc.OnDisableInSuite
    DynamicCursor.Reset = desc.Reset
    DynamicCursor.ResetDefaults = desc.ResetDefaults
    DynamicCursor.ResetModuleDefaults = desc.ResetModuleDefaults
    DynamicCursor.SelectSubTab = desc.SelectSubTab
    DynamicCursor.SelectTab = desc.SelectSubTab

    if type(_G.DynamicSuite.RegisterModule) == "function" then
        pcall(_G.DynamicSuite.RegisterModule, _G.DynamicSuite, "cursor", desc, "/dcur", desc.desc)
    end
    _G.DynamicSuite.modules["cursor"] = desc
    _G.DynamicSuite.modules["DynamicCursor"] = desc
end

SLASH_DYNAMICCURSOR1 = "/dcur"
SLASH_DYNAMICCURSOR2 = "/dynamiccursor"
SlashCmdList["DYNAMICCURSOR"] = function(msg)
    local cmd = (msg or ""):lower():match("^(%S*)") or ""
    if cmd == "reset" then
        ResetCursorModuleDefaults()
    elseif cmd == "raid" then
        DynamicCursor:ApplyPreset("CLEAN_RAID")
    elseif cmd == "highvis" then
        DynamicCursor:ApplyPreset("HIGH_VIS")
    elseif cmd == "minimal" then
        DynamicCursor:ApplyPreset("MINIMALIST")
    elseif cmd == "full" or cmd == "all" then
        DynamicCursor:ApplyPreset("FULL_TELEMETRY")
    else
        DynamicCursor.OpenWorkspace()
    end
end

function _G.DynamicCursor_OnAddonCompartmentClick()
    DynamicCursor.OpenWorkspace()
end
