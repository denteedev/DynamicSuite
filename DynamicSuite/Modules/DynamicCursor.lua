-- DynamicCursor v2.8.1 (/dcur, /dynamiccursor)
-- Cursor Ring, Radial GCD & Cast/Channel/Empower Arc, Character Crosshair, Find My Cursor, Pooled Trail & Smart Tooltips.
-- Retail 12.1.5+ (Interface 120105) | Zero-Taint, Secret-Value Safe, 0.00 ms Idle CPU.

local addonName, addonTable = ...
local ADDON_FOLDER = (type(addonName) == "string" and addonName ~= "") and addonName or "DynamicCursor"
local STANDALONE_NAME = "DynamicCursor"

local function ResolveAddonVersion(folderName, fallback)
    local fb = fallback or "2.8.1"
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

local VERSION = ResolveAddonVersion(ADDON_FOLDER, "2.8.1")

local function ShouldYieldToOtherInstall(thisFolder, standaloneName, thisVersion, globalTbl)
    if thisFolder == standaloneName then
        if type(globalTbl) == "table" and globalTbl._loadedFromSuite == true then
            local suiteVer = globalTbl._loadedVersion or globalTbl.version or "2.8.1"
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

local function _IsSecret(v)
    if type(issecretvalue) == "function" and issecretvalue(v) then
        return true
    end
    if type(canaccessvalue) == "function" and v ~= nil and not canaccessvalue(v) then
        return true
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
        local _, c = UnitClass("player")
        if not _IsSecret(c) and type(c) == "string" and c ~= "" then
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

local function ResolveColorMode(mode, customHex, combatShift)
    if combatShift and InCombatLockdown and InCombatLockdown() then
        return 0.980, 0.450, 0.220
    end
    if mode == "CLASS" then
        return GetClassColorRGB()
    elseif mode == "HIGH_VIS_GREEN" then
        return 0.133, 0.920, 0.369
    elseif mode == "CUSTOM" then
        return ParseHexRGB(customHex)
    end
    return GetSuiteAccent()
end

-- ============================================================================
-- 1. DEFAULTS & SAVEDVARIABLES
-- ============================================================================
local DEFAULTS = {
    activeSubTab = 1,

    -- Tab 1: Cursor Ring, GCD & Cast Arc (Off by default)
    ringEnabled = false,
    ringStyle = "CRISP",            -- "CRISP" | "THIN" | "THICK" | "GLOW" | "DUAL"
    ringRadius = 40,                -- 16..96
    ringOpacityOOC = 0.55,          -- 0.05..1.00
    ringOpacityCombat = 0.95,       -- 0.05..1.00
    ringColorMode = "ACCENT",       -- "ACCENT" | "CLASS" | "HIGH_VIS_GREEN" | "CUSTOM"
    ringCustomHex = "38BDF8",
    ringCombatShift = false,
    ringStrata = "TOOLTIP",         -- "HIGH" | "DIALOG" | "TOOLTIP"
    ringKeepMouseLook = true,
    ringClickPulse = false,

    gcdEnabled = true,
    castArcEnabled = true,
    castShowIcon = false,

    showOpenWorld = true,
    showDelves = true,
    showDungeons = true,
    showRaids = true,
    showPvP = true,
    autoHideSpecial = true,

    -- Tab 2: Character Crosshair & Cursor Locator (Off by default)
    crosshairEnabled = false,
    crosshairStyle = "CLASSIC",     -- "CLASSIC" | "DOT" | "CROSS_DOT" | "BRACKETS" | "CIRCLE_DOT"
    crosshairSize = 24,             -- 8..64
    crosshairThickness = 2,         -- 1..6
    crosshairGap = 6,               -- 0..20
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
    locatorModifier = "OFF",        -- "OFF" | "SHIFT" | "CTRL" | "ALT"
    locatorStyle = "PING",          -- "PING" | "SPOTLIGHT" | "CROSSHAIR"

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
    CopyDefaults(DEFAULTS, _G.DynamicCursorDB)
    return _G.DynamicCursorDB
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
    local ringRoot, ringTex, ghostTex, pulseTex
    local gcdCooldown, castCooldown, castIconTex
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
    local lastCX, lastCY = 0, 0
    local lastVX, lastVY = 0, 0
    local shakeReversals = 0
    local shakeWindowEnd = 0
    local shakeBurstEnd = 0
    local pulseRemaining = 0
    local castFlashEnd = 0
    local isCastingNow = false
    local isChannelingNow = false

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
            local okI, isIn = pcall(_G.IsInInstance)
            if okI and not _IsSecret(isIn) then inInst = (isIn == true) end
        end
        if diffID == 208 then return "DELVE" end
        if _G.C_DelvesUI and type(_G.C_DelvesUI.HasActiveDelve) == "function" then
            local okD, hasD = pcall(_G.C_DelvesUI.HasActiveDelve)
            if okD and hasD == true then return "DELVE" end
        end
        if instType == "pvp" or instType == "arena" then return "PVP" end
        if instType == "raid" then return "RAID" end
        if instType == "party" then return "DUNGEON" end
        if inInst then return "DUNGEON" end
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

        ringTex = ringRoot:CreateTexture(nil, "ARTWORK")
        ringTex:SetAllPoints()

        ghostTex = ringRoot:CreateTexture(nil, "BACKGROUND")
        ghostTex:SetAllPoints()
        ghostTex:Hide()

        pulseTex = ringRoot:CreateTexture(nil, "OVERLAY")
        pulseTex:SetPoint("CENTER")
        pulseTex:Hide()

        gcdCooldown = CreateFrame("Cooldown", nil, ringRoot, "CooldownFrameTemplate")
        gcdCooldown:SetAllPoints()
        gcdCooldown:EnableMouse(false)
        gcdCooldown:SetDrawEdge(false)
        gcdCooldown:SetDrawBling(false)
        gcdCooldown:SetDrawSwipe(true)
        gcdCooldown:SetReverse(false)
        if gcdCooldown.SetHideCountdownNumbers then gcdCooldown:SetHideCountdownNumbers(true) end
        gcdCooldown.noCooldownCount = true
        gcdCooldown:Hide()

        castCooldown = CreateFrame("Cooldown", nil, ringRoot, "CooldownFrameTemplate")
        castCooldown:SetPoint("TOPLEFT", ringRoot, "TOPLEFT", -8, 8)
        castCooldown:SetPoint("BOTTOMRIGHT", ringRoot, "BOTTOMRIGHT", 8, -8)
        castCooldown:EnableMouse(false)
        castCooldown:SetDrawEdge(false)
        castCooldown:SetDrawBling(false)
        castCooldown:SetDrawSwipe(true)
        castCooldown:SetReverse(false)
        if castCooldown.SetHideCountdownNumbers then castCooldown:SetHideCountdownNumbers(true) end
        castCooldown.noCooldownCount = true
        castCooldown:Hide()

        castIconTex = ringRoot:CreateTexture(nil, "OVERLAY")
        castIconTex:SetSize(18, 18)
        castIconTex:SetPoint("BOTTOM", ringRoot, "TOP", 0, 6)
        castIconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        castIconTex:Hide()
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

        for i = 1, 8 do
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
        local style = db.crosshairStyle or "CLASSIC"
        local r, g, bCol = ResolveColorMode(db.crosshairColorMode or "ACCENT", db.crosshairCustomHex, db.crosshairCombatTint)
        local alpha = inCombat and (tonumber(db.crosshairOpacityCombat) or 0.90) or (tonumber(db.crosshairOpacityOOC) or 0.45)

        crosshairRoot:SetAlpha(alpha)
        for i = 1, 8 do
            chLines[i]:Hide()
            chOutlines[i]:Hide()
        end
        chDot:Hide(); chDotBg:Hide(); chCircle:Hide()

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

        if style == "DOT" or style == "CROSS_DOT" or style == "CIRCLE_DOT" then
            local dSz = math.max(4, th * 2 + 2)
            chDot:SetSize(dSz, dSz)
            chDot:SetVertexColor(r, g, bCol, 1)
            chDot:Show()
            if outline then
                chDotBg:SetSize(dSz + 3, dSz + 3)
                chDotBg:Show()
            end
        end

        if style == "CIRCLE_DOT" then
            chCircle:SetSize(sz, sz)
            chCircle:SetVertexColor(r, g, bCol, 1)
            chCircle:Show()
        elseif style == "CLASSIC" or style == "CROSS_DOT" then
            local arm = math.max(3, math.floor((sz - gap * 2) * 0.5))
            PlaceBar(1, arm, th, "RIGHT", "CENTER", -gap, 0)
            PlaceBar(2, arm, th, "LEFT",  "CENTER",  gap, 0)
            PlaceBar(3, th, arm, "BOTTOM", "CENTER", 0,  gap)
            PlaceBar(4, th, arm, "TOP",    "CENTER", 0, -gap)
        elseif style == "BRACKETS" then
            local half = math.max(6, math.floor(sz * 0.5))
            local leg = math.max(4, math.floor(sz * 0.30))
            PlaceBar(1, th, sz * 0.65, "RIGHT", "CENTER", -half, 0)
            PlaceBar(2, th, sz * 0.65, "LEFT",  "CENTER",  half, 0)
            PlaceBar(3, leg, th, "TOPLEFT",     "CENTER", -half,  sz * 0.325)
            PlaceBar(4, leg, th, "BOTTOMLEFT",  "CENTER", -half, -sz * 0.325)
            PlaceBar(5, leg, th, "TOPRIGHT",    "CENTER",  half,  sz * 0.325)
            PlaceBar(6, leg, th, "BOTTOMRIGHT", "CENTER",  half, -sz * 0.325)
        end

        crosshairRoot:Show()
    end

    local function UpdateRingAppearance(db)
        if not ringRoot then return end
        local radius = tonumber(db.ringRadius) or 40
        local diam = radius * 2
        ringRoot:SetSize(diam, diam)
        ringRoot:SetFrameStrata(db.ringStrata or "TOOLTIP")

        local texPath = RING_TEXTURES[db.ringStyle or "CRISP"] or RING_TEXTURES.CRISP
        ringTex:SetTexture(texPath)
        ghostTex:SetTexture(texPath)
        pulseTex:SetTexture(RING_TEXTURES.THIN)

        local r, g, b = ResolveColorMode(db.ringColorMode or "ACCENT", db.ringCustomHex, db.ringCombatShift)
        ringTex:SetVertexColor(r, g, b, 1)
        ghostTex:SetVertexColor(r, g, b, 0.35)
        pulseTex:SetVertexColor(r, g, b, 0.90)

        local inCombat = (InCombatLockdown and InCombatLockdown()) and true or false
        local alpha = inCombat and (tonumber(db.ringOpacityCombat) or 0.95) or (tonumber(db.ringOpacityOOC) or 0.55)
        ringRoot:SetAlpha(alpha)

        if gcdCooldown then
            gcdCooldown:SetSwipeTexture(RING_TEXTURES.THIN)
            gcdCooldown:SetSwipeColor(r, g, b, 0.85)
            local inset = math.max(4, math.floor(radius * 0.22))
            gcdCooldown:ClearAllPoints()
            gcdCooldown:SetPoint("TOPLEFT", ringRoot, "TOPLEFT", inset, -inset)
            gcdCooldown:SetPoint("BOTTOMRIGHT", ringRoot, "BOTTOMRIGHT", -inset, inset)
        end
        if castCooldown then
            castCooldown:SetSwipeTexture(RING_TEXTURES.THIN)
            if castFlashEnd > (GetTime and GetTime() or 0) then
                castCooldown:SetSwipeColor(0.95, 0.22, 0.22, 0.95)
            else
                castCooldown:SetSwipeColor(r, g, b, 0.92)
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
            if castIconTex then castIconTex:Hide() end
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
                    if castIconTex then castIconTex:Hide() end
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
                    if db.castShowIcon and castIconTex then
                        local infoFn = isChannel and _G.UnitChannelInfo or _G.UnitCastingInfo
                        if type(infoFn) == "function" then
                            local okI, _, _, texID = pcall(infoFn, "player")
                            if okI and not _IsSecret(texID) and texID then
                                castIconTex:SetTexture(texID)
                                castIconTex:Show()
                            end
                        end
                    elseif castIconTex then
                        castIconTex:Hide()
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
                    if db.castShowIcon and castIconTex and not _IsSecret(texID) and texID then
                        castIconTex:SetTexture(texID)
                        castIconTex:Show()
                    elseif castIconTex then
                        castIconTex:Hide()
                    end
                    return
                end
            end
        end
        castCooldown:Hide()
        if castIconTex then castIconTex:Hide() end
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
        local db = EnsureDB()
        local now = (GetTime and GetTime()) or 0
        local effScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        if effScale <= 0 then effScale = 1 end
        local rawX, rawY = 0, 0
        if type(_G.GetCursorPosition) == "function" then
            rawX, rawY = _G.GetCursorPosition()
        end
        local cx, cy = rawX / effScale, rawY / effScale
        local dx, dy = cx - lastCX, cy - lastCY
        local moved = (dx ~= 0 or dy ~= 0)

        -- Shake-to-Find detection
        if db.shakeToFind == true and not isMouseLooking and moved then
            if (dx * lastVX < -180) or (dy * lastVY < -180) then
                if now > shakeWindowEnd then
                    shakeReversals = 1
                    shakeWindowEnd = now + 0.55
                else
                    shakeReversals = shakeReversals + 1
                end
                if shakeReversals >= 4 then
                    shakeBurstEnd = now + 1.15
                    shakeReversals = 0
                end
            end
            lastVX, lastVY = dx, dy
        end
        lastCX, lastCY = cx, cy

        -- Main Cursor Ring
        local allowed = IsActivityAllowed(db)
        if db.ringEnabled and allowed and ringRoot then
            if isMouseLooking then
                if db.ringKeepMouseLook then
                    ringTex:Hide()
                    ghostTex:Show()
                    ringRoot:Show()
                else
                    ringRoot:Hide()
                end
            else
                ringTex:Show()
                ghostTex:Hide()
                ringRoot:ClearAllPoints()
                ringRoot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
                ringRoot:Show()
            end

            if pulseRemaining > 0 and pulseTex then
                pulseRemaining = pulseRemaining - elapsed
                if pulseRemaining <= 0 then
                    pulseTex:Hide()
                else
                    local pProg = 1.0 - (pulseRemaining / 0.25)
                    local rad = (tonumber(db.ringRadius) or 40) * (1.0 + pProg * 0.75)
                    pulseTex:SetSize(rad * 2, rad * 2)
                    pulseTex:SetAlpha((1.0 - pProg) * 0.85)
                    pulseTex:Show()
                end
            end
        elseif ringRoot then
            ringRoot:Hide()
        end

        -- Find My Cursor / Modifier Locator
        local showLocator = (now < shakeBurstEnd) or IsLocatorModifierHeld(db)
        if showLocator and allowed and not isMouseLooking then
            EnsureLocatorFrames()
            locatorRoot:ClearAllPoints()
            locatorRoot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
            local r, g, b = ResolveColorMode(db.ringColorMode or "ACCENT", db.ringCustomHex, false)
            local lStyle = (now < shakeBurstEnd and db.locatorModifier == "OFF") and "PING" or (db.locatorStyle or "PING")
            locatorPingTex:Hide(); locatorSpotTex:Hide(); locatorCrossH:Hide(); locatorCrossV:Hide()
            if lStyle == "PING" then
                local phase = (now * 2.2) % 1.0
                local pSize = 48 + phase * 110
                locatorPingTex:SetSize(pSize, pSize)
                locatorPingTex:SetVertexColor(r, g, b, (1.0 - phase) * 0.90)
                locatorPingTex:Show()
            elseif lStyle == "SPOTLIGHT" then
                locatorSpotTex:SetVertexColor(r, g, b, 0.32)
                locatorSpotTex:Show()
            else
                locatorCrossH:SetColorTexture(r, g, b, 0.75)
                locatorCrossV:SetColorTexture(r, g, b, 0.75)
                locatorCrossH:Show()
                locatorCrossV:Show()
            end
            locatorRoot:Show()
        elseif locatorRoot then
            locatorRoot:Hide()
        end

        -- Pooled Cursor Trail
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
            local anyAlive = false
            for i = 1, TRAIL_POOL_SIZE do
                local n = trailPool[i]
                if n and n.active then
                    local age = now - n.born
                    if age >= n.life then
                        n.active = false
                        n.tex:Hide()
                    else
                        anyAlive = true
                        local t = 1.0 - (age / n.life)
                        n.tex:SetAlpha(n.a * t)
                        local s = math.max(2, n.size * (0.35 + 0.65 * t))
                        n.tex:SetSize(s, s)
                    end
                end
            end
            if not anyAlive and not db.ringEnabled and not db.shakeToFind and db.locatorModifier == "OFF" then
                activeUpdateFrame:SetScript("OnUpdate", nil)
            end
        elseif trailRoot then
            ClearTrailNodes()
        end
    end

    local smartTooltipHooked = false
    local function EnsureSmartTooltipHook()
        if smartTooltipHooked or type(_G.hooksecurefunc) ~= "function" then return end
        smartTooltipHooked = true
        _G.hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
            local db = EnsureDB()
            if not db.tooltipEnabled or IsModuleDisabledInSuite("DynamicCursor") then return end
            if not tooltip or tooltip ~= _G.GameTooltip then return end
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
            pcall(function()
                local effScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
                if effScale <= 0 then effScale = 1 end
                local rawX, rawY = _G.GetCursorPosition()
                local cx, cy = rawX / effScale, rawY / effScale
                local ox = tonumber(db.tooltipOffsetX) or 18
                local oy = tonumber(db.tooltipOffsetY) or -18
                local sw = (_G.GetScreenWidth and _G.GetScreenWidth()) or 1920
                local sh = (_G.GetScreenHeight and _G.GetScreenHeight()) or 1080
                local anchor = "ANCHOR_NONE"
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
                tooltip:SetOwner(parent or UIParent, anchor)
                tooltip:ClearAllPoints()
                tooltip:SetPoint(pt, UIParent, "BOTTOMLEFT", cx + ox, cy + oy)
            end)
        end)
    end

    SyncAllEngines = function()
        local db = EnsureDB()
        local disabled = IsModuleDisabledInSuite("DynamicCursor")
        if disabled then
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
                if castIconTex then castIconTex:Hide() end
            end
        elseif ringRoot then
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

        local needsUpdate = (db.ringEnabled == true) or (db.trailEnabled == true) or (db.shakeToFind == true) or ((db.locatorModifier or "OFF") ~= "OFF")
        if needsUpdate and IsActivityAllowed(db) then
            activeUpdateFrame:SetScript("OnUpdate", OnCursorUpdate)
        else
            activeUpdateFrame:SetScript("OnUpdate", nil)
            if ringRoot then ringRoot:Hide() end
            if locatorRoot then locatorRoot:Hide() end
            ClearTrailNodes()
        end
    end
    DynamicCursor.SyncAllEngines = SyncAllEngines

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
    SafeRegisterEvent(evFrame, "UNIT_SPELLCAST_SUCCEEDED")
    SafeRegisterEvent(evFrame, "UNIT_SPELLCAST_START")
    SafeRegisterEvent(evFrame, "UNIT_SPELLCAST_STOP")
    SafeRegisterEvent(evFrame, "UNIT_SPELLCAST_FAILED")
    SafeRegisterEvent(evFrame, "UNIT_SPELLCAST_INTERRUPTED")
    SafeRegisterEvent(evFrame, "UNIT_SPELLCAST_CHANNEL_START")
    SafeRegisterEvent(evFrame, "UNIT_SPELLCAST_CHANNEL_STOP")
    SafeRegisterEvent(evFrame, "UNIT_SPELLCAST_EMPOWER_START")
    SafeRegisterEvent(evFrame, "UNIT_SPELLCAST_EMPOWER_STOP")

    evFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "PLAYER_LOGIN" then
            EnsureDB()
            if type(_G.hooksecurefunc) == "function" then
                if _G.MouselookStart then
                    _G.hooksecurefunc("MouselookStart", function() isMouseLooking = true end)
                end
                if _G.MouselookStop then
                    _G.hooksecurefunc("MouselookStop", function() isMouseLooking = false end)
                end
            end
            SyncAllEngines()
            return
        end
        if IsModuleDisabledInSuite("DynamicCursor") then return end
        local db = EnsureDB()

        if event == "PLAYER_STARTED_LOOKING" then
            isMouseLooking = true
        elseif event == "PLAYER_STOPPED_LOOKING" then
            isMouseLooking = false
        elseif event == "GLOBAL_MOUSE_DOWN" then
            if db.ringEnabled and db.ringClickPulse and not isMouseLooking then
                pulseRemaining = 0.25
            end
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            if arg1 == "player" then TriggerGCDCooldown() end
        elseif event == "UNIT_SPELLCAST_START" then
            if arg1 == "player" then
                isCastingNow = true; isChannelingNow = false
                TriggerGCDCooldown()
                UpdateCastArc(false, false, false)
            end
        elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
            if arg1 == "player" then
                isChannelingNow = true; isCastingNow = false
                TriggerGCDCooldown()
                UpdateCastArc(true, false, false)
            end
        elseif event == "UNIT_SPELLCAST_EMPOWER_START" then
            if arg1 == "player" then
                isChannelingNow = true; isCastingNow = false
                TriggerGCDCooldown()
                UpdateCastArc(false, true, false)
            end
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
            if arg1 == "player" then
                isCastingNow = false; isChannelingNow = false
                UpdateCastArc(false, false, true)
            end
        elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
            or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
            if arg1 == "player" then
                isCastingNow = false; isChannelingNow = false
                if castCooldown then castCooldown:Hide() end
                if castIconTex then castIconTex:Hide() end
            end
        elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            if ringRoot then UpdateRingAppearance(db) end
            UpdateCrosshairVisuals(db)
        elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA"
            or event == "PET_BATTLE_OPENING_START" or event == "PET_BATTLE_CLOSE"
            or event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
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
        db.ringStyle = "CRISP"
        db.ringRadius = 38
        db.ringOpacityOOC = 0.45
        db.ringOpacityCombat = 0.90
        db.ringColorMode = "ACCENT"
        db.ringCombatShift = false
        db.gcdEnabled = true
        db.castArcEnabled = true
        db.castShowIcon = false
        db.crosshairEnabled = false
        db.trailEnabled = false
        PrintMsg("Applied preset: Clean Raid.")
    elseif presetKey == "HIGH_VIS" then
        db.ringEnabled = true
        db.ringStyle = "DUAL"
        db.ringRadius = 52
        db.ringOpacityOOC = 0.75
        db.ringOpacityCombat = 1.00
        db.ringColorMode = "HIGH_VIS_GREEN"
        db.ringCombatShift = true
        db.gcdEnabled = true
        db.castArcEnabled = true
        db.castShowIcon = true
        db.crosshairEnabled = true
        db.crosshairStyle = "CROSS_DOT"
        db.crosshairSize = 26
        db.crosshairOutline = true
        db.shakeToFind = true
        db.trailEnabled = false
        PrintMsg("Applied preset: High-Visibility.")
    elseif presetKey == "MINIMALIST" then
        db.ringEnabled = true
        db.ringStyle = "THIN"
        db.ringRadius = 30
        db.ringOpacityOOC = 0.35
        db.ringOpacityCombat = 0.75
        db.ringColorMode = "CLASS"
        db.gcdEnabled = true
        db.castArcEnabled = false
        db.crosshairEnabled = false
        db.trailEnabled = false
        PrintMsg("Applied preset: Minimalist.")
    elseif presetKey == "FULL_TELEMETRY" then
        db.ringEnabled = true
        db.ringStyle = "GLOW"
        db.ringRadius = 46
        db.ringOpacityOOC = 0.65
        db.ringOpacityCombat = 0.95
        db.ringColorMode = "ACCENT"
        db.ringClickPulse = true
        db.gcdEnabled = true
        db.castArcEnabled = true
        db.castShowIcon = true
        db.crosshairEnabled = true
        db.crosshairStyle = "BRACKETS"
        db.crosshairSize = 28
        db.shakeToFind = true
        db.locatorModifier = "SHIFT"
        db.trailEnabled = true
        db.trailStyle = "CLASS_SPARKS"
        db.trailDensity = 4
        PrintMsg("Applied preset: Full Telemetry.")
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
    local function CloseCursorPopups()
        if activeDropPopup then
            activeDropPopup:Hide()
            activeDropPopup = nil
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

    local function CreateDropdownControl(parent, width, options, getFn, setFn)
        local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        btn:SetSize(width, 26)
        btn.lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        SetSafeFont(btn.lbl, 11, "")
        btn.lbl:SetPoint("LEFT", btn, "LEFT", 10, 0)
        btn.lbl:SetPoint("RIGHT", btn, "RIGHT", -22, 0)
        btn.lbl:SetJustifyH("LEFT")
        btn.lbl:SetWordWrap(false)
        btn.arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        SetSafeFont(btn.arrow, 10, "")
        btn.arrow:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
        btn.arrow:SetText("v")

        function btn:RefreshValue()
            local ar, ag, ab = GetSuiteAccent()
            SetBackdropSolid(self, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)
            self.arrow:SetTextColor(ar, ag, ab, 1)
            local cur = getFn()
            for _, opt in ipairs(options) do
                if opt.value == cur then
                    self.lbl:SetText(opt.label)
                    return
                end
            end
            self.lbl:SetText(tostring(cur or ""))
        end

        btn:SetScript("OnHide", CloseCursorPopups)
        btn:SetScript("OnClick", function(selfBtn)
            if activeDropPopup and activeDropPopup.owner == selfBtn and activeDropPopup:IsShown() then
                CloseCursorPopups()
                return
            end
            CloseCursorPopups()
            local pop = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            pop:SetFrameStrata("TOOLTIP")
            pop:SetFrameLevel(120)
            pop:SetWidth(width)
            pop:SetHeight(#options * 24 + 8)
            pop.owner = selfBtn
            local ar, ag, ab = GetSuiteAccent()
            SetBackdropSolid(pop, { 0.043, 0.051, 0.071, 0.99 }, { ar, ag, ab, 0.95 }, 1)
            pop:SetPoint("TOPLEFT", selfBtn, "BOTTOMLEFT", 0, -2)
            for i, opt in ipairs(options) do
                local row = CreateFrame("Button", nil, pop)
                row:SetSize(width - 8, 22)
                row:SetPoint("TOPLEFT", pop, "TOPLEFT", 4, -4 - (i - 1) * 24)
                local hl = row:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetColorTexture(ar, ag, ab, 0.22)
                local rl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                SetSafeFont(rl, 11, "")
                rl:SetPoint("LEFT", row, "LEFT", 8, 0)
                rl:SetText(opt.label)
                rl:SetTextColor(opt.value == getFn() and ar or 0.90, opt.value == getFn() and ag or 0.93, opt.value == getFn() and ab or 0.96, 1)
                row:SetScript("OnClick", function()
                    setFn(opt.value)
                    selfBtn:RefreshValue()
                    CloseCursorPopups()
                end)
            end
            activeDropPopup = pop
        end)
        return btn
    end

    local function CreateSettingCard(parent, titleTxt, descTxt, rightW)
        local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        card:SetHeight(62)
        SetBackdropSolid(card, { 0.055, 0.063, 0.082, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)

        local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        SetSafeFont(title, 12, "")
        title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -10)
        title:SetPoint("RIGHT", card, "RIGHT", -(rightW + 28), 0)
        title:SetJustifyH("LEFT")
        title:SetWordWrap(false)
        title:SetTextColor(0.96, 0.98, 1.0, 1)
        title:SetText(titleTxt)
        card.title = title

        local desc = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        SetSafeFont(desc, 10, "")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        desc:SetPoint("RIGHT", card, "RIGHT", -(rightW + 28), 0)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        desc:SetMaxLines(2)
        desc:SetTextColor(0.64, 0.70, 0.78, 1)
        desc:SetText(descTxt)
        card.desc = desc

        function card:BindRight(ctrl)
            ctrl:ClearAllPoints()
            ctrl:SetPoint("RIGHT", self, "RIGHT", -14, 0)
            self.ctrl = ctrl
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

    local function LayoutPage(page)
        local y = -4
        for _, item in ipairs(page.items or {}) do
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
            item:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, y)
            y = y - (item:GetHeight() + 8)
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

        -- 3-Tab Segmented Bar (anchored at top of workspace for 1:1 DynamicSuite parity)
        local tabBar = CreateFrame("Frame", nil, root, "BackdropTemplate")
        tabBar:SetHeight(34)
        tabBar:SetPoint("TOPLEFT", root, "TOPLEFT", 14, -10)
        tabBar:SetPoint("TOPRIGHT", root, "TOPRIGHT", -16, -10)
        SetBackdropSolid(tabBar, { 0.043, 0.051, 0.071, 0.98 }, { 1, 1, 1, 0.08 }, 1)

        local tabDefs = {
            { id = 1, label = "Cursor Ring & Cast Arc" },
            { id = 2, label = "Crosshair & Locator" },
            { id = 3, label = "Trail & Tooltips" },
        }
        local tabBtns = {}
        for i, td in ipairs(tabDefs) do
            local tb = CreateFrame("Button", nil, tabBar, "BackdropTemplate")
            tb:SetHeight(26)
            tb.lbl = tb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            SetSafeFont(tb.lbl, 11, "")
            tb.lbl:SetPoint("CENTER")
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
            local w = math.max(300, rawW - 8)
            local bw = math.floor((w - 8) / 3)
            for i, tb in ipairs(tabBtns) do
                tb:ClearAllPoints()
                tb:SetWidth(i == 3 and (w - (bw + 4) * 2) or bw)
                tb:SetPoint("LEFT", tabBar, "LEFT", 4 + (i - 1) * (bw + 4), 0)
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
        track:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", -2, -8)
        track:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -18, 10)
        local trackBg = track:CreateTexture(nil, "BACKGROUND")
        trackBg:SetAllPoints()
        trackBg:SetColorTexture(0.035, 0.039, 0.051, 0.95)

        local thumb = CreateFrame("Button", nil, track)
        thumb:SetWidth(4)
        thumb:SetHeight(40)
        thumb:SetPoint("TOP", track, "TOP", 0, 0)
        local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
        thumbTex:SetAllPoints()
        thumbTex:SetColorTexture(0.38, 0.45, 0.56, 0.85)

        local function UpdateThumb()
            local maxS = math.max(0, (content:GetHeight() or 0) - (sf:GetHeight() or 0))
            if maxS <= 1 then
                track:Hide()
                return
            end
            track:Show()
            local th = track:GetHeight() or 200
            local thumbH = math.max(24, th * ((sf:GetHeight() or 200) / math.max(1, content:GetHeight() or 200)))
            thumb:SetHeight(thumbH)
            local cur = sf:GetVerticalScroll() or 0
            local pct = math.max(0, math.min(1, cur / maxS))
            thumb:ClearAllPoints()
            thumb:SetPoint("TOP", track, "TOP", 0, -pct * (th - thumbH))
        end

        sf:SetScript("OnMouseWheel", function(_, delta)
            local maxS = math.max(0, (content:GetHeight() or 0) - (sf:GetHeight() or 0))
            local nextS = math.max(0, math.min(maxS, (sf:GetVerticalScroll() or 0) - delta * 36))
            sf:SetVerticalScroll(nextS)
            UpdateThumb()
        end)
        local thumbDrag = false
        thumb:SetScript("OnMouseDown", function(_, b) if b == "LeftButton" then thumbDrag = true end end)
        thumb:SetScript("OnMouseUp", function() thumbDrag = false end)
        thumb:SetScript("OnHide", function() thumbDrag = false end)
        thumb:SetScript("OnUpdate", function()
            if not thumbDrag then return end
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then thumbDrag = false; return end
            local top = track:GetTop(); local bot = track:GetBottom()
            if not top or not bot or top <= bot then return end
            local _, cy = GetCursorPosition()
            cy = cy / (track:GetEffectiveScale() or 1)
            local pct = math.max(0, math.min(1, (top - cy) / (top - bot)))
            local maxS = math.max(0, (content:GetHeight() or 0) - (sf:GetHeight() or 0))
            sf:SetVerticalScroll(pct * maxS)
            UpdateThumb()
        end)

        local pages = { CreateFrame("Frame", nil, content), CreateFrame("Frame", nil, content), CreateFrame("Frame", nil, content) }
        for _, pg in ipairs(pages) do
            pg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
            pg:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
            pg.items = {}
            pg:Hide()
        end

        local refreshables = {}
        local headers = {}

        local function AddHeader(pgIdx, t, s)
            local h = CreateSectionHeader(pages[pgIdx], t, s)
            pages[pgIdx].items[#pages[pgIdx].items + 1] = h
            headers[#headers + 1] = h
        end
        local function AddToggle(pgIdx, title, desc, getFn, setFn)
            local c = CreateSettingCard(pages[pgIdx], title, desc, 156)
            local p = CreateSegmentedPills(c, 156, { { value = false, label = "Off" }, { value = true, label = "Enabled" } }, getFn, function(v)
                setFn(v); SyncAllEngines(); DynamicCursor:RefreshWorkspaceUI()
            end)
            c:BindRight(p)
            pages[pgIdx].items[#pages[pgIdx].items + 1] = c
            refreshables[#refreshables + 1] = p
        end
        local function AddSlider(pgIdx, title, desc, minV, maxV, stepV, fmtFn, getFn, setFn)
            local c = CreateSettingCard(pages[pgIdx], title, desc, 256)
            local s = CreateTrue4pxSlider(c, 256, minV, maxV, stepV, fmtFn, getFn, function(v)
                setFn(v); SyncAllEngines()
            end)
            c:BindRight(s)
            pages[pgIdx].items[#pages[pgIdx].items + 1] = c
            refreshables[#refreshables + 1] = s
        end
        local function AddPills(pgIdx, title, desc, w, opts, getFn, setFn)
            local c = CreateSettingCard(pages[pgIdx], title, desc, w)
            local p = CreateSegmentedPills(c, w, opts, getFn, function(v)
                setFn(v); SyncAllEngines(); DynamicCursor:RefreshWorkspaceUI()
            end)
            c:BindRight(p)
            pages[pgIdx].items[#pages[pgIdx].items + 1] = c
            refreshables[#refreshables + 1] = p
        end
        local function AddDropdown(pgIdx, title, desc, w, opts, getFn, setFn)
            local c = CreateSettingCard(pages[pgIdx], title, desc, w)
            local d = CreateDropdownControl(c, w, opts, getFn, function(v)
                setFn(v); SyncAllEngines(); DynamicCursor:RefreshWorkspaceUI()
            end)
            c:BindRight(d)
            pages[pgIdx].items[#pages[pgIdx].items + 1] = c
            refreshables[#refreshables + 1] = d
        end

        -- TAB 1: Quick Presets Strip + Cursor Ring, GCD & Cast Arc
        local presetCard = CreateFrame("Frame", nil, pages[1], "BackdropTemplate")
        presetCard:SetHeight(42)
        SetBackdropSolid(presetCard, { 0.055, 0.063, 0.082, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)

        local presetLbl = presetCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        SetSafeFont(presetLbl, 10, "")
        presetLbl:SetPoint("LEFT", presetCard, "LEFT", 12, 0)
        presetLbl:SetText("QUICK PRESETS")
        presetLbl:SetTextColor(0.58, 0.64, 0.72, 1)

        local presetDefs = {
            { key = "CLEAN_RAID",     label = "Clean Raid",      w = 88 },
            { key = "HIGH_VIS",       label = "High-Visibility", w = 104 },
            { key = "MINIMALIST",     label = "Minimalist",      w = 84 },
            { key = "FULL_TELEMETRY", label = "Full Telemetry",  w = 104 },
        }
        local px = 114
        local presetBtns = {}
        for _, p in ipairs(presetDefs) do
            local pb = CreateFrame("Button", nil, presetCard, "BackdropTemplate")
            pb:SetSize(p.w, 24)
            pb:SetPoint("LEFT", presetCard, "LEFT", px, 0)
            pb.lbl = pb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            SetSafeFont(pb.lbl, 10, "")
            pb.lbl:SetPoint("CENTER")
            pb.lbl:SetText(p.label)
            pb:SetScript("OnClick", function() DynamicCursor:ApplyPreset(p.key) end)
            presetBtns[#presetBtns + 1] = pb
            px = px + p.w + 6
        end
        pages[1].items[#pages[1].items + 1] = presetCard

        AddHeader(1, "MAIN CURSOR RING", "Keep track of your pointer with a clean, click-through ring around your cursor.")
        AddToggle(1, "Enable Cursor Ring", "Displays a customisable ring around your mouse cursor (Off by default).",
            function() return EnsureDB().ringEnabled == true end, function(v) EnsureDB().ringEnabled = v end)
        AddDropdown(1, "Ring Style", "Choose between 5 crisp procedural ring styles.", 220, {
            { value = "CRISP", label = "Crisp Ring" },
            { value = "THIN",  label = "Thin Ring" },
            { value = "THICK", label = "Thick Ring" },
            { value = "GLOW",  label = "Soft Glow" },
            { value = "DUAL",  label = "High-Contrast Black/White Dual" },
        }, function() return EnsureDB().ringStyle or "CRISP" end, function(v) EnsureDB().ringStyle = v end)
        AddSlider(1, "Ring Radius", "Adjust the cursor ring radius in pixels (16 to 96 px).", 16, 96, 2,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().ringRadius or 40 end, function(v) EnsureDB().ringRadius = v end)
        AddSlider(1, "Out-of-Combat Opacity", "Ring transparency while out of combat.", 0.05, 1.00, 0.05,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return EnsureDB().ringOpacityOOC or 0.55 end, function(v) EnsureDB().ringOpacityOOC = v end)
        AddSlider(1, "In-Combat Opacity", "Ring transparency during combat.", 0.05, 1.00, 0.05,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return EnsureDB().ringOpacityCombat or 0.95 end, function(v) EnsureDB().ringOpacityCombat = v end)
        AddDropdown(1, "Ring Colour Mode", "Follow your Suite Accent, Class Colour, High-Vis Green, or a custom hex colour.", 220, {
            { value = "ACCENT",         label = "Suite Accent" },
            { value = "CLASS",          label = "Class Colour" },
            { value = "HIGH_VIS_GREEN", label = "High-Vis Green" },
            { value = "CUSTOM",         label = "Custom Hex (Edit)" },
        }, function() return EnsureDB().ringColorMode or "ACCENT" end, function(v) EnsureDB().ringColorMode = v end)
        AddToggle(1, "Combat Colour Shift", "Tints the cursor ring warm amber-orange while you are in combat.",
            function() return EnsureDB().ringCombatShift == true end, function(v) EnsureDB().ringCombatShift = v end)
        AddPills(1, "Frame Strata", "Layer order above UI panels.", 210, {
            { value = "HIGH", label = "HIGH" }, { value = "DIALOG", label = "DIALOG" }, { value = "TOOLTIP", label = "TOOLTIP" },
        }, function() return EnsureDB().ringStrata or "TOOLTIP" end, function(v) EnsureDB().ringStrata = v end)
        AddToggle(1, "Keep Visible During Mouse-Look", "Shows a subtle ghost ring while Right-Click turning your camera.",
            function() return EnsureDB().ringKeepMouseLook ~= false end, function(v) EnsureDB().ringKeepMouseLook = v end)
        AddToggle(1, "Click-Pulse Ripple", "Plays a quick expanding ripple when you click.",
            function() return EnsureDB().ringClickPulse == true end, function(v) EnsureDB().ringClickPulse = v end)

        AddHeader(1, "RADIAL GCD & CAST / EMPOWER ARCS", "Secret-value safe C++ swipe arcs attached cleanly to your cursor ring.")
        AddToggle(1, "Inner GCD Ring", "Shows your Global Cooldown swipe inside the cursor ring.",
            function() return EnsureDB().gcdEnabled ~= false end, function(v) EnsureDB().gcdEnabled = v end)
        AddToggle(1, "Outer Cast / Channel / Empower Arc", "Shows your spell cast, channel, or empower progress around the ring with an interrupt flash.",
            function() return EnsureDB().castArcEnabled ~= false end, function(v) EnsureDB().castArcEnabled = v end)
        AddToggle(1, "Show Mini Spell Icon on Cast", "Displays the active spell icon just above the cursor ring while casting.",
            function() return EnsureDB().castShowIcon == true end, function(v) EnsureDB().castShowIcon = v end)

        AddHeader(1, "ACTIVITY VISIBILITY (SHOW IN)", "Choose which content types show the cursor ring and auto-hide during special modes.")
        AddToggle(1, "Show in Open World", "Keep the cursor ring active outdoors.",
            function() return EnsureDB().showOpenWorld ~= false end, function(v) EnsureDB().showOpenWorld = v end)
        AddToggle(1, "Show in Delves", "Keep the cursor ring active inside Delves.",
            function() return EnsureDB().showDelves ~= false end, function(v) EnsureDB().showDelves = v end)
        AddToggle(1, "Show in Dungeons", "Keep the cursor ring active inside 5-player and Mythic+ dungeons.",
            function() return EnsureDB().showDungeons ~= false end, function(v) EnsureDB().showDungeons = v end)
        AddToggle(1, "Show in Raids", "Keep the cursor ring active inside raids.",
            function() return EnsureDB().showRaids ~= false end, function(v) EnsureDB().showRaids = v end)
        AddToggle(1, "Show in PvP", "Keep the cursor ring active in Arenas and Battlegrounds.",
            function() return EnsureDB().showPvP ~= false end, function(v) EnsureDB().showPvP = v end)
        AddToggle(1, "Auto-Hide in Pet Battles, Vehicles & Cutscenes", "Temporarily hides cursor overlays during pet battles, vehicles, and movies.",
            function() return EnsureDB().autoHideSpecial ~= false end, function(v) EnsureDB().autoHideSpecial = v end)

        -- TAB 2: Character Crosshair & Cursor Locator
        AddHeader(2, "CHARACTER CROSSHAIR", "Screen-centre reference crosshair for melee range and positioning.")
        AddToggle(2, "Enable Character Crosshair", "Displays a screen-centre crosshair around your character (Off by default).",
            function() return EnsureDB().crosshairEnabled == true end, function(v) EnsureDB().crosshairEnabled = v end)
        AddDropdown(2, "Crosshair Style", "Choose between 5 crosshair layouts.", 220, {
            { value = "CLASSIC",    label = "Classic Crosshair" },
            { value = "DOT",        label = "Precision Dot" },
            { value = "CROSS_DOT",  label = "Crosshair + Dot" },
            { value = "BRACKETS",   label = "Tactical Brackets" },
            { value = "CIRCLE_DOT", label = "Circle + Dot" },
        }, function() return EnsureDB().crosshairStyle or "CLASSIC" end, function(v) EnsureDB().crosshairStyle = v end)
        AddSlider(2, "Crosshair Size", "Overall crosshair span in pixels (8 to 64 px).", 8, 64, 2,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().crosshairSize or 24 end, function(v) EnsureDB().crosshairSize = v end)
        AddSlider(2, "Line Thickness", "Crosshair line stroke thickness (1 to 6 px).", 1, 6, 1,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().crosshairThickness or 2 end, function(v) EnsureDB().crosshairThickness = v end)
        AddSlider(2, "Centre Gap", "Inner gap around the centre point (0 to 20 px).", 0, 20, 1,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().crosshairGap or 6 end, function(v) EnsureDB().crosshairGap = v end)
        AddToggle(2, "High-Contrast Outline", "Adds a crisp dark 1px outline behind crosshair lines.",
            function() return EnsureDB().crosshairOutline ~= false end, function(v) EnsureDB().crosshairOutline = v end)
        AddSlider(2, "Horizontal Offset (X)", "Nudge crosshair left or right from screen centre (-100 to +100 px).", -100, 100, 2,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().crosshairOffsetX or 0 end, function(v) EnsureDB().crosshairOffsetX = v end)
        AddSlider(2, "Vertical Offset (Y)", "Nudge crosshair up or down from screen centre (-100 to +100 px).", -100, 100, 2,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().crosshairOffsetY or 0 end, function(v) EnsureDB().crosshairOffsetY = v end)
        AddDropdown(2, "Crosshair Visibility", "Choose when the character crosshair appears.", 220, {
            { value = "ALWAYS",              label = "Always" },
            { value = "COMBAT_ONLY",         label = "In Combat Only" },
            { value = "INSTANCES_ONLY",      label = "Instances Only" },
            { value = "COMBAT_IN_INSTANCES", label = "Combat in Instances" },
        }, function() return EnsureDB().crosshairVisibility or "ALWAYS" end, function(v) EnsureDB().crosshairVisibility = v end)
        AddSlider(2, "Crosshair Out-of-Combat Opacity", "Crosshair transparency out of combat.", 0.05, 1.00, 0.05,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return EnsureDB().crosshairOpacityOOC or 0.45 end, function(v) EnsureDB().crosshairOpacityOOC = v end)
        AddSlider(2, "Crosshair In-Combat Opacity", "Crosshair transparency during combat.", 0.05, 1.00, 0.05,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return EnsureDB().crosshairOpacityCombat or 0.90 end, function(v) EnsureDB().crosshairOpacityCombat = v end)
        AddDropdown(2, "Crosshair Colour Mode", "Follow your Suite Accent, Class Colour, High-Vis Green, or a custom hex colour.", 220, {
            { value = "ACCENT",         label = "Suite Accent" },
            { value = "CLASS",          label = "Class Colour" },
            { value = "HIGH_VIS_GREEN", label = "High-Vis Green" },
            { value = "CUSTOM",         label = "Custom Hex (Edit)" },
        }, function() return EnsureDB().crosshairColorMode or "ACCENT" end, function(v) EnsureDB().crosshairColorMode = v end)
        AddToggle(2, "Crosshair Combat Tint", "Shifts the crosshair colour to warm amber-orange during combat.",
            function() return EnsureDB().crosshairCombatTint == true end, function(v) EnsureDB().crosshairCombatTint = v end)

        AddHeader(2, "FIND MY CURSOR", "Quickly locate your mouse pointer during hectic raid or Mythic+ pulls.")
        AddToggle(2, "Shake-to-Find", "Rapidly wiggle your mouse back and forth to trigger a brief cursor ping burst.",
            function() return EnsureDB().shakeToFind == true end, function(v) EnsureDB().shakeToFind = v end)
        AddPills(2, "Modifier Key Locator", "Hold a modifier key to highlight your cursor.", 260, {
            { value = "OFF", label = "Off" }, { value = "SHIFT", label = "Shift" }, { value = "CTRL", label = "Ctrl" }, { value = "ALT", label = "Alt" },
        }, function() return EnsureDB().locatorModifier or "OFF" end, function(v) EnsureDB().locatorModifier = v end)
        AddPills(2, "Locator Highlight Style", "Visual cue shown while Shake-to-Find or Modifier Locator is active.", 260, {
            { value = "PING", label = "Ping Ring" }, { value = "SPOTLIGHT", label = "Spotlight" }, { value = "CROSSHAIR", label = "Screen Cross" },
        }, function() return EnsureDB().locatorStyle or "PING" end, function(v) EnsureDB().locatorStyle = v end)

        -- TAB 3: Cursor Trail & Smart Cursor Tooltips
        AddHeader(3, "POOLED CURSOR TRAIL", "Pre-allocated 48-node trail with zero garbage collection and 0.00 ms idle CPU.")
        AddToggle(3, "Enable Cursor Trail", "Draws a smooth fading trail behind mouse movement (Off by default).",
            function() return EnsureDB().trailEnabled == true end, function(v) EnsureDB().trailEnabled = v end)
        AddDropdown(3, "Trail Style", "Choose between 4 trail particle styles.", 220, {
            { value = "SMOOTH_DOTS",  label = "Smooth Dots" },
            { value = "SOFT_MIST",    label = "Soft Mist" },
            { value = "CLASS_SPARKS", label = "Class Sparks" },
            { value = "ARCANE_MOTES", label = "Arcane Motes" },
        }, function() return EnsureDB().trailStyle or "SMOOTH_DOTS" end, function(v) EnsureDB().trailStyle = v end)
        AddSlider(3, "Trail Fade Duration", "How long each trail node takes to fade out (0.15s to 1.20s).", 0.15, 1.20, 0.05,
            function(v) return string.format("%.2fs", v) end,
            function() return EnsureDB().trailDuration or 0.45 end, function(v) EnsureDB().trailDuration = v end)
        AddSlider(3, "Trail Particle Size", "Base size of each trail node (6 to 32 px).", 6, 32, 2,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().trailSize or 14 end, function(v) EnsureDB().trailSize = v end)
        AddSlider(3, "Trail Density", "How closely trail nodes spawn along your path (1 to 5).", 1, 5, 1,
            function(v) return string.format("%d", v) end,
            function() return EnsureDB().trailDensity or 3 end, function(v) EnsureDB().trailDensity = v end)
        AddSlider(3, "Trail Opacity", "Maximum trail opacity.", 0.10, 1.00, 0.05,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return EnsureDB().trailOpacity or 0.75 end, function(v) EnsureDB().trailOpacity = v end)
        AddDropdown(3, "Trail Colour Mode", "Follow your Suite Accent, Class Colour, High-Vis Green, or a custom hex colour.", 220, {
            { value = "ACCENT",         label = "Suite Accent" },
            { value = "CLASS",          label = "Class Colour" },
            { value = "HIGH_VIS_GREEN", label = "High-Vis Green" },
            { value = "CUSTOM",         label = "Custom Hex (Edit)" },
        }, function() return EnsureDB().trailColorMode or "ACCENT" end, function(v) EnsureDB().trailColorMode = v end)
        AddToggle(3, "Show Trail in Combat Only", "Only spawns trail particles while you are in combat.",
            function() return EnsureDB().trailCombatOnly == true end, function(v) EnsureDB().trailCombatOnly = v end)
        AddToggle(3, "Keep Trail During Mouse-Look", "Continues drawing trail nodes while Right-Click turning.",
            function() return EnsureDB().trailShowMouseLook == true end, function(v) EnsureDB().trailShowMouseLook = v end)

        AddHeader(3, "SMART CURSOR TOOLTIPS", "Optionally anchor GameTooltip near your cursor with automatic screen-edge flipping.")
        AddToggle(3, "Anchor Tooltips to Cursor", "Moves mouseover tooltips beside your pointer (Off by default).",
            function() return EnsureDB().tooltipEnabled == true end, function(v) EnsureDB().tooltipEnabled = v end)
        AddSlider(3, "Tooltip Horizontal Offset (X)", "Horizontal gap from your cursor (-60 to +60 px).", -60, 60, 2,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().tooltipOffsetX or 18 end, function(v) EnsureDB().tooltipOffsetX = v end)
        AddSlider(3, "Tooltip Vertical Offset (Y)", "Vertical gap from your cursor (-60 to +60 px).", -60, 60, 2,
            function(v) return string.format("%d px", v) end,
            function() return EnsureDB().tooltipOffsetY or -18 end, function(v) EnsureDB().tooltipOffsetY = v end)
        AddToggle(3, "Automatic Screen-Edge Flip", "Flips tooltip anchor inward when your cursor is near a screen edge.",
            function() return EnsureDB().tooltipEdgeFlip ~= false end, function(v) EnsureDB().tooltipEdgeFlip = v end)
        AddDropdown(3, "Tooltip Combat Behaviour", "Choose how cursor tooltips behave during combat.", 240, {
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
            local sfW = (sf and sf.GetWidth and sf:GetWidth()) or 0
            if sfW > 40 then
                content:SetWidth(sfW)
            end

            for _, pb in ipairs(presetBtns) do
                SetBackdropSolid(pb, { 0.078, 0.090, 0.122, 0.96 }, { ar, ag, ab, 0.70 }, 1)
                pb.lbl:SetTextColor(0.92, 0.95, 0.99, 1)
            end

            local activeTab = tonumber(db.activeSubTab) or 1
            if activeTab < 1 or activeTab > 3 then activeTab = 1 end
            for i, tb in ipairs(tabBtns) do
                if i == activeTab then
                    SetBackdropSolid(tb, { ar * alphaPill, ag * alphaPill, ab * alphaPill, 0.98 }, { ar, ag, ab, 0.95 }, 1)
                    tb.lbl:SetTextColor(1, 1, 1, 1)
                else
                    SetBackdropSolid(tb, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)
                    tb.lbl:SetTextColor(0.68, 0.74, 0.82, 1)
                end
            end
            for _, h in ipairs(headers) do h:RefreshAccent() end
            for _, rCtrl in ipairs(refreshables) do
                if rCtrl.RefreshValue then rCtrl:RefreshValue() end
            end
            for i, pg in ipairs(pages) do
                if i == activeTab then
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
            UpdateThumb()
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
            local f = CreateFrame("Frame", "DynamicCursorStandaloneFrame", UIParent, "BackdropTemplate")
            f:SetSize(880, 620)
            f:SetPoint("CENTER")
            f:SetMovable(true)
            f:EnableMouse(true)
            f:RegisterForDrag("LeftButton")
            f:SetScript("OnDragStart", f.StartMoving)
            f:SetScript("OnDragStop", f.StopMovingOrSizing)
            f:SetClampedToScreen(true)
            f:SetFrameStrata("DIALOG")
            SetBackdropSolid(f, { 0.035, 0.039, 0.051, 0.99 }, { 0.145, 0.165, 0.212, 0.95 }, 1)

            local hdr = CreateFrame("Frame", nil, f, "BackdropTemplate")
            hdr:SetHeight(42)
            hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
            hdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
            SetBackdropSolid(hdr, { 0.015, 0.018, 0.024, 1.00 }, { 0.145, 0.165, 0.212, 0.95 }, 1)

            local title = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            SetSafeFont(title, 13, "")
            title:SetPoint("LEFT", hdr, "LEFT", 14, 0)
            title:SetText(string.format("|cFF%sDynamic|r|cFFFFFFFFCursor|r  |cFF94A3B8v%s|r", GetAccentHex(), VERSION))

            local closeBtn = CreateFrame("Button", nil, hdr, "BackdropTemplate")
            closeBtn:SetSize(24, 24)
            closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -10, 0)
            SetBackdropSolid(closeBtn, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 }, 1)
            local xLbl = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            SetSafeFont(xLbl, 11, "")
            xLbl:SetPoint("CENTER")
            xLbl:SetText("X")
            closeBtn:SetScript("OnClick", function() f:Hide() end)

            local body = CreateFrame("Frame", nil, f)
            body:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, 0)
            body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
            RenderCursorEmbedded(body)

            if type(UISpecialFrames) == "table" then
                table.insert(UISpecialFrames, "DynamicCursorStandaloneFrame")
            end
            DynamicCursor.standaloneFrame = f
        end
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
    date = "23/11/2026",
    entries = {
        { type = "FEATURE", text = "[Unreleased] New 13th Dual-Mode Module: DynamicCursor (/dcur, /dynamiccursor) (23/11/2026): Added a customisable Cursor Ring (5 procedural ring styles, radius, OOC/combat opacity, colour modes, Mouse-Look ghost ring, and click-pulse ripple), secret-safe native C++ Radial GCD and Cast/Channel/Empower arcs, Character Crosshair (5 styles with X/Y offset and Combat/Instance visibility), Find My Cursor (Shake-to-Find + Modifier Key Locator), pre-allocated 48-node Pooled Cursor Trail (0.00 ms idle CPU), Smart Cursor Tooltips, and 4 one-click presets (Clean Raid, High-Visibility, Minimalist, Full Telemetry)." },
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
        ApplyTheme = function() if DynamicCursor.RefreshWorkspaceUI then DynamicCursor:RefreshWorkspaceUI() end end,
        ApplyThemeToUI = function() if DynamicCursor.RefreshWorkspaceUI then DynamicCursor:RefreshWorkspaceUI() end end,
        ResetModuleDefaults = ResetCursorModuleDefaults,
        ResetDefaults = ResetCursorModuleDefaults,
        Reset = ResetCursorModuleDefaults,
        OpenWorkspace = function() return DynamicCursor.OpenWorkspace() end,
        GetStatusText = GetStatusText,
        OnDisableInSuite = function() SyncAllEngines() end,
        OnEnableInSuite = function() SyncAllEngines() end,
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
    elseif cmd == "full" then
        DynamicCursor:ApplyPreset("FULL_TELEMETRY")
    else
        DynamicCursor.OpenWorkspace()
    end
end

function _G.DynamicCursor_OnAddonCompartmentClick()
    DynamicCursor.OpenWorkspace()
end
