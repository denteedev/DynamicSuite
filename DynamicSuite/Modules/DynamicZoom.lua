-- ============================================================================
-- DynamicZoom - Max 39-Yard Camera Unlock, Collision Shield & Situational Auto-Zoom
-- World of Warcraft Retail (12.1.5 / 12.1.7, Interface 120105, 120107)
-- Pure ASCII Only (NonASCII: 0, HasBOM: False) | Zero Raw CVar Names in UI
-- ============================================================================

local addonName = ...
local ADDON_FOLDER = (type(addonName) == "string" and addonName ~= "") and addonName or "DynamicSuite"

local function ResolveAddonVersion(folderName, fallback)
    local fb = fallback or "2.10.3"
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
            local suiteVer = globalTbl._loadedVersion or globalTbl.VERSION or globalTbl.version or (_G.DynamicSuite and _G.DynamicSuite.version) or "2.6.6"
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
            local stLoadedVer = globalTbl._loadedVersion or globalTbl.VERSION or globalTbl.version or "0.0.0"
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

local VERSION = ResolveAddonVersion(ADDON_FOLDER, "2.10.3")
if ShouldYieldToOtherInstall(ADDON_FOLDER, "DynamicZoom", VERSION, _G.DynamicZoom) then
    return
end
local DZ_NS = {}
local isInitialized = false

local function IsModuleDisabledInSuite(modName)
    local key = modName or "DynamicZoom"
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

local ADDON_NAME = "DynamicZoom"
local DynamicZoom = _G.DynamicZoom or CreateFrame("Frame", "DynamicZoomCoreFrame", UIParent)
_G.DynamicZoom = DynamicZoom
DZ_NS.DynamicZoom = DynamicZoom
DynamicZoom._loadedBySuite = (ADDON_FOLDER == "DynamicSuite")
DynamicZoom._loadedVersion = VERSION

DynamicZoom.VERSION = VERSION
DynamicZoom.version = VERSION
local MIN_ZOOM_YARDS = 15
local MAX_ZOOM_YARDS = 39

local ICON_COLOR        = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_zoom.tga"
local ICON_WHITE        = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_white.tga"
local ICON_ACCENT       = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_accent.tga"
local ICON_CHECK        = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_check.tga"
local ICON_CHEVRON_DOWN = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga"
local ICON_CHEVRON_UP   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga"
local ICON_COG          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_cog.tga"

-- ============================================================================
-- 1. EXPERIMENTAL CVAR POPUP SUPPRESSION (ITEM #3)
-- ============================================================================
local experimentalPopupHooked = false
local inExperimentalCVarWriteWindow = false

local function EnsureExperimentalPopupHook()
    if not experimentalPopupHooked and type(hooksecurefunc) == "function" and type(StaticPopup_Show) == "function" then
        experimentalPopupHooked = true
        hooksecurefunc("StaticPopup_Show", function(which)
            if inExperimentalCVarWriteWindow and which == "EXPERIMENTAL_CVAR_WARNING" and StaticPopup_Hide then
                pcall(StaticPopup_Hide, "EXPERIMENTAL_CVAR_WARNING")
            end
        end)
    end
end

local function SuppressExperimentalCVarPopup()
    EnsureExperimentalPopupHook()
    if inExperimentalCVarWriteWindow and StaticPopup_Hide then
        pcall(StaticPopup_Hide, "EXPERIMENTAL_CVAR_WARNING")
    end
end

local function IsSecretValue(val)
    if val == nil then return false end
    if type(_G.issecretvalue) == "function" then
        local ok, res = pcall(_G.issecretvalue, val)
        if ok and res then return true end
    end
    if type(_G.canaccessvalue) == "function" then
        local ok, res = pcall(_G.canaccessvalue, val)
        if ok and res == false then return true end
    end
    return false
end

local function SafeGetCameraZoom()
    if type(GetCameraZoom) ~= "function" then return nil end
    local ok, z = pcall(GetCameraZoom)
    if not ok or z == nil or IsSecretValue(z) or type(z) ~= "number" then
        return nil
    end
    return z
end

-- ============================================================================
-- 2. DEFAULT SAVEDVARIABLES & THEME PALETTES
-- ============================================================================
local DEFAULTS = {
    schemaVersion = 122,
    enabled = true,
    activeSubTab = 1,

    -- Engine 1: Max-Zoom, Reactive Scroll Accelerator & Collision Occlusion Shield
    maxZoomYards = 39,                  -- 15 to 39 yards (maps to 1.0 - 2.6 factor)
    reactiveScrollEnabled = true,       -- DynamicCam-style reactive scroll flick acceleration
    scrollDrawerOpen = true,            -- Sub-Settings (1) inline sub-drawer state
    flickBoost = 3.0,                   -- 1.0x to 5.0x quadratic flick multiplier
    scrollSpeed = 35,                   -- Base zoom glide speed (15 to 50)
    indirectVisibility = true,          -- Foliage & Pillar Alpha Raycast Shield
    pillarDrawerOpen = true,            -- Sub-Settings (1) inline sub-drawer state
    indirectOffset = 1.5,               -- Pillar Pre-Zoom Sensitivity (1.0 to 10.0, step 0.5)
    waterCollisionShield = true,        -- Prevents camera snapping over lakes during Skyriding
    reduceUnexpectedMovement = true,    -- Dampens sudden ramp/stairs camera jerks

    -- Engine 2: Event-Driven Situational Auto-Zoom State Machine (All Combat/World default 39 yds)
    autoZoomEnabled = true,
    autoZoomDrawerOpen = false,         -- Sub-Settings (5) collapsed by default on fresh profiles
    zoomRaidCombat = 39,                -- Raid & Boss Combat target distance (15-39 yds, default 39)
    zoomDungeon = 39,                   -- Mythic+ & 5-Player Dungeon target distance (15-39 yds, default 39)
    zoomDelve = 39,                     -- Delves & Scenarios target distance (15-39 yds, default 39)
    zoomPvP = 39,                       -- Arena & Battleground target distance (15-39 yds, default 39)
    zoomOutdoor = 39,                   -- Open World target distance (15-39 yds, default 39)
    indoorRule = "OFF",                 -- "OFF" (Do Not Change) or "39", "35", "30", "25", "20"
    cityRule = "OFF",                   -- "OFF" (Do Not Change) or "39", "35", "30", "25", "20"
    skyridingDiveTracking = true,       -- Aerial Dive Pitch Tracking while mounted/gliding
    npcDialogZoom = false,              -- Opt-In NPC Gossip/Quest gentle framing
    npcDialogDrawerOpen = false,        -- Sub-Settings (1) collapsed by default on fresh profiles
    npcDialogYards = 15,                -- Target distance for NPC dialogue framing (15-25 yds, default 15)

    -- Engine 3: Live Pitch, Shoulder Framing & Anti-Motion-Sickness
    pitchTiltPct = 0,                   -- Live Slider: 0% (Off) to 80%, step 5% (default 0% Off)
    shoulderOffsetVal = 0.0,            -- Live Slider: -1.5 (Left) to +1.5 (Right), step 0.1 (default 0.0)
}

local ZONE_RULE_OPTIONS = {
    { key = "OFF", label = "Do Not Change (Keep Current Zoom)" },
    { key = "39",  label = "39 yds (Maximum Tactical Zoom)" },
    { key = "35",  label = "35 yds (Wide Dungeon Framing)" },
    { key = "30",  label = "30 yds (Balanced Open World)" },
    { key = "25",  label = "25 yds (Mid-Range Framing)" },
    { key = "20",  label = "20 yds (Compact Indoor Framing)" },
}

local SURFACE_PALETTES = {
    MIDNIGHT_BLACK = {
        bg        = { 0.035, 0.039, 0.051, 0.99 },
        panel     = { 0.035, 0.039, 0.051, 0.99 },
        section   = { 0.043, 0.050, 0.066, 0.98 },
        card      = { 0.055, 0.063, 0.082, 0.96 },
        subCard   = { 0.035, 0.039, 0.051, 0.98 },
        header    = { 0.015, 0.018, 0.024, 1.00 },
        border    = { 0.145, 0.165, 0.212, 0.95 },
        secBorder = { 1.0,   1.0,   1.0,   0.14 },
    },
    OBSIDIAN_DARK = {
        bg        = { 0.067, 0.075, 0.094, 0.98 },
        panel     = { 0.067, 0.075, 0.094, 0.98 },
        section   = { 0.055, 0.063, 0.082, 0.98 },
        card      = { 0.090, 0.102, 0.129, 0.95 },
        subCard   = { 0.047, 0.055, 0.071, 0.98 },
        header    = { 0.035, 0.039, 0.051, 1.00 },
        border    = { 0.165, 0.188, 0.239, 0.95 },
        secBorder = { 1.0,   1.0,   1.0,   0.14 },
    },
    SLATE_STEEL = {
        bg        = { 0.090, 0.106, 0.141, 0.98 },
        panel     = { 0.090, 0.106, 0.141, 0.98 },
        section   = { 0.075, 0.090, 0.122, 0.98 },
        card      = { 0.118, 0.137, 0.180, 0.96 },
        subCard   = { 0.071, 0.086, 0.114, 0.98 },
        header    = { 0.055, 0.067, 0.090, 1.00 },
        border    = { 0.200, 0.235, 0.305, 0.95 },
        secBorder = { 1.0,   1.0,   1.0,   0.15 },
    },
    SMOKED_GLASS = {
        bg        = { 0.075, 0.090, 0.118, 0.86 },
        panel     = { 0.075, 0.090, 0.118, 0.86 },
        section   = { 0.060, 0.074, 0.098, 0.88 },
        card      = { 0.102, 0.122, 0.157, 0.84 },
        subCard   = { 0.055, 0.067, 0.090, 0.88 },
        header    = { 0.045, 0.055, 0.075, 0.92 },
        border    = { 0.190, 0.220, 0.285, 0.90 },
        secBorder = { 1.0,   1.0,   1.0,   0.14 },
    },
}

local LEGACY_SURFACE_MAP = {
    Obsidian = "OBSIDIAN_DARK",
    Midnight = "MIDNIGHT_BLACK",
    Charcoal = "OBSIDIAN_DARK",
    Slate    = "SLATE_STEEL",
}

local ACCENT_PALETTES = {
    Cyan      = { r = 0.024, g = 0.714, b = 0.831, hex = "06B6D4" },
    RoyalBlue = { r = 0.231, g = 0.510, b = 0.965, hex = "3B82F6" },
    Emerald   = { r = 0.063, g = 0.725, b = 0.506, hex = "10B981" },
    AmberGold = { r = 0.961, g = 0.620, b = 0.043, hex = "F59E0B" },
    Crimson   = { r = 0.937, g = 0.267, b = 0.267, hex = "EF4444" },
    Amethyst  = { r = 0.659, g = 0.333, b = 0.969, hex = "A855F7" },
}

local CONFLICT_REGISTRY = {
    { addon = "DynamicCam",    label = "DynamicCam",    mode = "EXCLUSIVE", desc = "Overlaps situational camera zoom & pitch state machine." },
    { addon = "MaxCam",        label = "MaxCam",        mode = "EXCLUSIVE", desc = "Overlaps maximum camera distance factor & scroll speed." },
    { addon = "ActionCamPlus", label = "ActionCamPlus", mode = "EXCLUSIVE", desc = "Overlaps ActionCam pitch, shoulder offset, and camera zoom settings." },
    { addon = "FasterCamera",  label = "FasterCamera",  mode = "EXCLUSIVE", desc = "Overlaps mousewheel zoom speed & distance stepping." },
}

-- ============================================================================
-- 3. DATABASE SANITIZATION, MIGRATION & SUITE ACCENT SYNC
-- ============================================================================
local function SanitizeZoomYards(val, fallback)
    local n = tonumber(val)
    if not n then return fallback or MAX_ZOOM_YARDS end
    -- Mandatory Unit Sanitization: Any stored factor <= 2.6 is migrated to yards (val * 15)
    if n > 0 and n <= 2.6 then
        n = math.floor((n * 15.0) + 0.5)
    end
    return math.max(MIN_ZOOM_YARDS, math.min(MAX_ZOOM_YARDS, math.floor(n + 0.5)))
end

local function EnsureDB()
    if type(_G.DynamicZoomDB) ~= "table" then
        _G.DynamicZoomDB = {}
    end
    local db = _G.DynamicZoomDB

    -- Migrate pre-122 profiles so old 30/35/28/24/20/18 defaults become 39 yds & Indoor/City = OFF
    if (tonumber(db.schemaVersion) or 0) < 122 then
        if db.zoomOutdoor == 30 or db.zoomOutdoor == nil then db.zoomOutdoor = 39 end
        if db.zoomDungeon == 35 or db.zoomDungeon == 28 or db.zoomDungeon == nil then db.zoomDungeon = 39 end
        if db.zoomDelve == 24 or db.zoomDelve == 20 or db.zoomDelve == nil then db.zoomDelve = 39 end
        if db.zoomRaidCombat == nil then db.zoomRaidCombat = 39 end
        if db.zoomPvP == nil then db.zoomPvP = 39 end
        db.indoorRule = "OFF"
        db.cityRule = "OFF"
        if db.pitchTiltPct == nil then db.pitchTiltPct = 0 end
        if db.shoulderOffsetVal == nil then db.shoulderOffsetVal = 0.0 end
        if db.scrollSpeed == 28 then db.scrollSpeed = 35 end
        db.schemaVersion = 122
    end

    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then
            db[k] = v
        end
    end
    db.scrollDrawerUserToggled = nil
    db.pillarDrawerUserToggled = nil

    -- Enforce hard 15..39 yd floor & factor->yard sanitization on all zoom distance keys
    db.maxZoomYards   = SanitizeZoomYards(db.maxZoomYards, 39)
    db.zoomRaidCombat = SanitizeZoomYards(db.zoomRaidCombat, 39)
    db.zoomDungeon    = SanitizeZoomYards(db.zoomDungeon, 39)
    db.zoomDelve      = SanitizeZoomYards(db.zoomDelve, 39)
    db.zoomPvP        = SanitizeZoomYards(db.zoomPvP, 39)
    db.zoomOutdoor    = SanitizeZoomYards(db.zoomOutdoor, 39)

    if type(db.zoneTargets) == "table" then
        for zk, zv in pairs(db.zoneTargets) do
            if type(zv) == "number" then
                db.zoneTargets[zk] = SanitizeZoomYards(zv, 39)
            end
        end
    end

    db.indirectOffset = math.max(1.0, math.min(10.0, tonumber(db.indirectOffset) or 1.5))
    db.flickBoost     = math.max(1.0, math.min(5.0, tonumber(db.flickBoost) or 3.0))
    db.scrollSpeed    = math.max(15, math.min(50, tonumber(db.scrollSpeed) or 35))
    db.pitchTiltPct   = math.max(0, math.min(80, tonumber(db.pitchTiltPct) or 0))
    db.shoulderOffsetVal = math.max(-1.5, math.min(1.5, tonumber(db.shoulderOffsetVal) or 0.0))
    db.npcDialogYards = math.max(15, math.min(25, math.floor((tonumber(db.npcDialogYards) or 15) + 0.5)))

    if type(db.savedBaselineCVars) ~= "table" then
        db.savedBaselineCVars = nil
    end
    return db
end

local function RGBToHex(r, g, b)
    local ri = math.max(0, math.min(255, math.floor((r or 0.024) * 255 + 0.5)))
    local gi = math.max(0, math.min(255, math.floor((g or 0.714) * 255 + 0.5)))
    local bi = math.max(0, math.min(255, math.floor((b or 0.831) * 255 + 0.5)))
    return string.format("%02X%02X%02X", ri, gi, bi)
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

local function GetTheme()
    EnsureDB()
    local g = _G.DynamicSuiteDB and _G.DynamicSuiteDB.global or {}
    local surfKey = nil
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.GetActiveSurfaceKey) == "function" then
        local okS, k = pcall(_G.DynamicSuite.UI.GetActiveSurfaceKey)
        if okS and type(k) == "string" and k ~= "" then
            surfKey = k
        end
    end
    if not surfKey then
        surfKey = g.surfaceTheme
    end
    if type(surfKey) == "string" and LEGACY_SURFACE_MAP[surfKey] then
        surfKey = LEGACY_SURFACE_MAP[surfKey]
    end
    local surf = SURFACE_PALETTES[surfKey or "MIDNIGHT_BLACK"] or SURFACE_PALETTES.MIDNIGHT_BLACK
    local acc = ACCENT_PALETTES[g.accentTheme or "Cyan"] or ACCENT_PALETTES.Cyan
    acc = { r = acc.r, g = acc.g, b = acc.b, hex = SanitizeHex6(acc.hex, acc.r, acc.g, acc.b) }

    -- Priority 1: Live _G.DynamicSuite:GetSuiteAccent() sync (Items #21, #29)
    if _G.DynamicSuite and type(_G.DynamicSuite.GetSuiteAccent) == "function" then
        local ok, r, gCol, b, hex = pcall(_G.DynamicSuite.GetSuiteAccent, _G.DynamicSuite)
        if ok and r then
            if type(r) == "table" then
                local tr = tonumber(r.r or r[1]) or acc.r
                local tg = tonumber(r.g or r[2]) or acc.g
                local tb = tonumber(r.b or r[3]) or acc.b
                local thex = SanitizeHex6(r.hex, tr, tg, tb)
                acc = { r = tr, g = tg, b = tb, hex = thex }
            elseif type(r) == "number" and type(gCol) == "number" and type(b) == "number" then
                local thex = SanitizeHex6(hex, r, gCol, b)
                acc = { r = r, g = gCol, b = b, hex = thex }
            end
        end
    end
    return surf, acc
end

local function GetActiveFont()
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.GetFont) == "function" then local okF, pF = pcall(_G.DynamicSuite.UI.GetFont); if okF and type(pF) == "string" and pF ~= "" then return pF end end
    if _G.DynamicSuite and type(_G.DynamicSuite.GetActiveFontPath) == "function" then
        local ok, path = pcall(_G.DynamicSuite.GetActiveFontPath, _G.DynamicSuite)
        if ok and type(path) == "string" and path ~= "" then
            return path
        end
    end
    if _G.DynamicLoadUI and type(_G.DynamicLoadUI.GetActiveFontPath) == "function" then
        local ok, path = pcall(_G.DynamicLoadUI.GetActiveFontPath)
        if ok and type(path) == "string" and path ~= "" then
            return path
        end
    end
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function SetFontSafe(fs, size, flags)
    if not fs or not fs.SetFont then return end
    local fontPath = GetActiveFont()
    local ok = fs:SetFont(fontPath, size or 12, flags or "")
    if not ok then
        fs:SetFont("Fonts\\FRIZQT__.TTF", size or 12, flags or "")
    end
end

local function ApplyBackdrop(frame, bgCol, borderCol)
    if not frame then return end
    if not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
    end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    if bgCol then
        frame:SetBackdropColor(bgCol[1], bgCol[2], bgCol[3], bgCol[4] or 1)
    end
    if borderCol then
        frame:SetBackdropBorderColor(borderCol[1], borderCol[2], borderCol[3], borderCol[4] or 1)
    end
end

local function CreateSolidTex(parent, layer, sublevel, r, g, b, a)
    local tex = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
    tex:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
    return tex
end

-- ============================================================================
-- 4. NATIVE C++ CAMERA ENGINE, ZERO-FIRST-PERSON GUARD & REACTIVE SCROLL
-- ============================================================================
local activeZoomStopTimer = nil
local preDialogZoomYards = nil
local activeContextLabel = "Outdoor (39 yds)"
local lastAppliedZoomContext = nil
local lastAppliedPitchNonZero = false
local lastAppliedShoulderNonZero = false
local pendingEngineApplyAfterCombat = false
local pendingExperimentalResetAfterCombat = false
local zoneChangeDebounceTimer = nil

local BASELINE_CAMERA_CVAR_KEYS = {
    "CameraKeepCharacterCentered",
    "cameraDistanceMaxZoomFactor",
    "cameraIndirectVisibility",
    "cameraIndirectOffset",
    "cameraWaterCollision",
    "CameraReduceUnexpectedMovement",
    "cameraZSmooth",
    "cameraZoomSpeed",
    "cameraPitchMoveSpeed",
    "test_cameraOverShoulder",
    "test_cameraDynamicPitch",
    "test_cameraDynamicPitchBaseFovPad",
    "test_cameraDynamicPitchBaseFovPadDownScale",
    "test_cameraDynamicPitchBaseFovPadFlying",
    "test_cameraDynamicPitchSmartPivotCutoffDist",
    "test_cameraHeadMovementStrength",
    "test_cameraTargetFocusEnemyEnable",
    "test_cameraTargetFocusInteractEnable",
}

local function SafeGetCVar(cvarName)
    if C_CVar and C_CVar.GetCVar then
        local ok, val = pcall(C_CVar.GetCVar, cvarName)
        if ok and val ~= nil and not IsSecretValue(val) then return tostring(val) end
    end
    if GetCVar then
        local ok, val = pcall(GetCVar, cvarName)
        if ok and val ~= nil and not IsSecretValue(val) then return tostring(val) end
    end
    return nil
end

local function SafeGetCVarDefault(cvarName)
    if C_CVar and C_CVar.GetCVarDefault then
        local ok, val = pcall(C_CVar.GetCVarDefault, cvarName)
        if ok and val ~= nil and not IsSecretValue(val) then return tostring(val) end
    end
    if GetCVarDefault then
        local ok, val = pcall(GetCVarDefault, cvarName)
        if ok and val ~= nil and not IsSecretValue(val) then return tostring(val) end
    end
    return nil
end

local function CaptureBaselineCameraCVars()
    local db = EnsureDB()
    if type(db.savedBaselineCVars) ~= "table" then
        db.savedBaselineCVars = {}
    end
    for _, k in ipairs(BASELINE_CAMERA_CVAR_KEYS) do
        if db.savedBaselineCVars[k] == nil then
            local cur = SafeGetCVar(k)
            if cur ~= nil then
                db.savedBaselineCVars[k] = cur
            end
        end
    end
end

local function SafeSetCVar(cvarName, val, isExperimental)
    if InCombatLockdown and InCombatLockdown() then
        pendingEngineApplyAfterCombat = true
        return
    end
    local targetStr = tostring(val)
    local curStr = SafeGetCVar(cvarName)
    if curStr ~= nil then
        if curStr == targetStr then return end
        local nCur, nTgt = tonumber(curStr), tonumber(targetStr)
        if nCur and nTgt and math.abs(nCur - nTgt) < 0.0001 then
            return
        end
    end
    if isExperimental then
        EnsureExperimentalPopupHook()
        inExperimentalCVarWriteWindow = true
    end
    if _G.DynamicSuite and _G.DynamicSuite.SnapshotCVar then
        _G.DynamicSuite.SnapshotCVar(cvarName)
    end
    if C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, cvarName, targetStr)
    elseif SetCVar then
        pcall(SetCVar, cvarName, targetStr)
    end
    if isExperimental then
        SuppressExperimentalCVarPopup()
        inExperimentalCVarWriteWindow = false
    end
end

local function RestoreBaselineCameraCVars()
    if InCombatLockdown and InCombatLockdown() then
        pendingEngineApplyAfterCombat = true
        return
    end
    local db = EnsureDB()
    local base = (type(db.savedBaselineCVars) == "table") and db.savedBaselineCVars or {}
    for _, k in ipairs(BASELINE_CAMERA_CVAR_KEYS) do
        local isExp = (k:sub(1, 5) == "test_")
        local val = base[k]
        if val == nil then
            val = SafeGetCVarDefault(k)
        end
        if val ~= nil then
            SafeSetCVar(k, val, isExp)
        end
    end
    lastAppliedPitchNonZero = false
    lastAppliedShoulderNonZero = false
    db._actionCamActive = false
    db._dirtyActionCam = false
end

local function CancelZoomGlide()
    if activeZoomStopTimer then
        activeZoomStopTimer:Cancel()
        activeZoomStopTimer = nil
    end
    if MoveViewOutStop then pcall(MoveViewOutStop) end
    if MoveViewInStop then pcall(MoveViewInStop) end
end

local function IsYieldingConflictHooks()
    local db = EnsureDB()
    local yh = db.yieldHooks
    local isYieldEnabled = (yh == true) or (type(yh) == "table" and next(yh) ~= nil)
    if not isYieldEnabled then return false end
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        local playerName = UnitName and UnitName("player") or nil
        for _, entry in ipairs(CONFLICT_REGISTRY) do
            local ok, state = pcall(C_AddOns.GetAddOnEnableState, entry.addon, playerName)
            if ok and state and state > 0 then
                return true
            end
        end
    end
    return false
end

-- CRITICAL FIX (Items #15, #43, #45): Zero-First-Person Safe Camera Transition
function DynamicZoom:SmoothZoomTo(targetYards, customDuration)
    local db = EnsureDB()
    if not db.enabled or IsYieldingConflictHooks() then return end

    -- 1. Sanitize & Clamp targetYards strictly to [MIN_ZOOM_YARDS (15), MAX_ZOOM_YARDS (39)]
    local maxAllowed = SanitizeZoomYards(db.maxZoomYards, MAX_ZOOM_YARDS)
    targetYards = SanitizeZoomYards(targetYards, maxAllowed)
    targetYards = math.max(MIN_ZOOM_YARDS, math.min(maxAllowed, targetYards))

    local currentYards = SafeGetCameraZoom()
    if not currentYards then return end

    CancelZoomGlide()

    -- 2. When targetYards >= 38.5 (Max Zoom 39 yds), ONLY EVER zoom OUT if currentZoom < 38.5!
    --    NEVER call CameraZoomIn or MoveViewInStart when target is Max Zoom!
    if targetYards >= 38.5 then
        if currentYards < 38.5 then
            local outDelta = math.max(0.5, 39.0 - currentYards)
            if CameraZoomOut then
                pcall(CameraZoomOut, outDelta)
            end
        end
        return
    end

    local delta = targetYards - currentYards
    if math.abs(delta) <= 1.0 then
        return
    end

    if delta > 0 then
        -- Zooming OUT toward targetYards
        if CameraZoomOut then
            pcall(CameraZoomOut, delta)
        end
    else
        -- Zooming IN toward a closer user-configured target (e.g. 25 yds):
        -- NEVER call CameraZoomIn if currentYards <= MIN_ZOOM_YARDS (15 yds)!
        if currentYards <= MIN_ZOOM_YARDS then
            return
        end
        local safeInDelta = math.min(math.abs(delta), math.max(0, currentYards - MIN_ZOOM_YARDS))
        if safeInDelta > 0.5 and CameraZoomIn then
            pcall(CameraZoomIn, safeInDelta)
        end
    end
end

DynamicZoom.ApplySituationalZoom = function(self, targetYards)
    return self:SmoothZoomTo(targetYards)
end

-- DynamicCam-Style Reactive Scroll Wheel Accelerator (Items #15, #16, #37)
local isAcceleratingScroll = false
local lastScrollTickTime = 0
local lastScrollDir = 0
local rapidTickStreak = 0
local scrollSpeedRestoreTimer = nil

local function OnManualCameraZoom(direction, increments)
    if isAcceleratingScroll then return end
    local db = EnsureDB()
    if not db.enabled or not db.reactiveScrollEnabled or IsYieldingConflictHooks() then return end

    local step = tonumber(increments) or 1
    -- Ignore large programmatic jumps (> 4.5 yards) from SmoothZoomTo / ApplySituationalZoom
    if step > 4.5 then return end

    local now = GetTime and GetTime() or 0
    local dt = now - lastScrollTickTime
    lastScrollTickTime = now

    if direction == lastScrollDir and dt > 0 and dt < 0.18 then
        rapidTickStreak = math.min(6, rapidTickStreak + 1)
    else
        rapidTickStreak = 0
    end
    lastScrollDir = direction

    if rapidTickStreak >= 1 then
        local boost = tonumber(db.flickBoost) or 3.0
        -- Quadratic flick acceleration: 1 fast flick glides smoothly all the way to 39 yds
        local extraYards = step * ((boost - 1.0) * (1.0 + (rapidTickStreak * 0.65)))
        if extraYards > 0.25 then
            if not (InCombatLockdown and InCombatLockdown()) then
                SafeSetCVar("cameraZoomSpeed", 50)
                if scrollSpeedRestoreTimer then
                    scrollSpeedRestoreTimer:Cancel()
                end
                scrollSpeedRestoreTimer = C_Timer.NewTimer(0.45, function()
                    scrollSpeedRestoreTimer = nil
                    local curDB = EnsureDB()
                    SafeSetCVar("cameraZoomSpeed", math.max(15, math.min(50, tonumber(curDB.scrollSpeed) or 35)))
                end)
            end

            isAcceleratingScroll = true
            if direction > 0 then
                -- Scrolling OUT
                if CameraZoomOut then
                    pcall(CameraZoomOut, extraYards)
                end
            else
                -- Scrolling IN: clamp extra acceleration so a fast flick never slams into 0 yd first-person
                local curZoom = SafeGetCameraZoom()
                if curZoom and curZoom > (MIN_ZOOM_YARDS + 2) then
                    local safeExtraIn = math.min(extraYards, math.max(0, curZoom - MIN_ZOOM_YARDS))
                    if safeExtraIn > 0.25 and CameraZoomIn then
                        pcall(CameraZoomIn, safeExtraIn)
                    end
                end
            end
            isAcceleratingScroll = false
        end
    end
end

if type(hooksecurefunc) == "function" then
    if type(CameraZoomOut) == "function" then
        hooksecurefunc("CameraZoomOut", function(increments)
            OnManualCameraZoom(1, increments)
        end)
    end
    if type(CameraZoomIn) == "function" then
        hooksecurefunc("CameraZoomIn", function(increments)
            OnManualCameraZoom(-1, increments)
        end)
    end
end

function DynamicZoom:ApplyEngineSettings(forceExperimentalReset)
    local db = EnsureDB()
    if not db.enabled then
        RestoreBaselineCameraCVars()
        return
    end
    if IsYieldingConflictHooks() then return end

    if InCombatLockdown and InCombatLockdown() then
        pendingEngineApplyAfterCombat = true
        if forceExperimentalReset then
            pendingExperimentalResetAfterCombat = true
        end
        return
    end

    CaptureBaselineCameraCVars()
    EnsureExperimentalPopupHook()

    local pitchPct = math.max(0, math.min(80, tonumber(db.pitchTiltPct) or 0))
    local shoulderVal = math.floor((math.max(-1.5, math.min(1.5, tonumber(db.shoulderOffsetVal) or 0.0)) * 10) + 0.5) / 10
    local usingActionCam = (pitchPct > 0) or (math.abs(shoulderVal) >= 0.05)
    local wasDirtyActionCam = (db._actionCamActive == true) or (db._dirtyActionCam == true)
    db._actionCamActive = usingActionCam
    db._dirtyActionCam = usingActionCam

    -- 1. Max Camera Distance Unlock (15 to 39 yds -> factor 1.0 to 2.6)
    local getGranular = _G.DynamicSuite and _G.DynamicSuite.GetGranularConflictMode
    local yieldZoom = db.yieldCameraMaxZoom == true
        or (type(getGranular) == "function" and (getGranular("DynamicZoom", "EnhanceQoL") == "YIELD_TO_EXTERNAL" or getGranular("DynamicZoom", "Leatrix_Plus") == "YIELD_TO_EXTERNAL"))
    if not yieldZoom then
        local maxYards = SanitizeZoomYards(db.maxZoomYards, 39)
        local factor = math.floor(((maxYards / 15.0) * 100) + 0.5) / 100
        SafeSetCVar("cameraDistanceMaxZoomFactor", factor)
    end

    -- 2. Foliage & Pillar Alpha Raycast Shield (cameraIndirectVisibility & cameraIndirectOffset 1.0..10.0)
    SafeSetCVar("cameraIndirectVisibility", db.indirectVisibility and 1 or 0)
    local offsetVal = math.max(1.0, math.min(10.0, tonumber(db.indirectOffset) or 1.5))
    SafeSetCVar("cameraIndirectOffset", offsetVal)

    -- 3. Water Surface Skimming Shield (0 = ignore water surface collision, 1 = collide)
    SafeSetCVar("cameraWaterCollision", db.waterCollisionShield and 0 or 1)

    -- 4. Sudden Geometry & Ramp Smoothing + ActionCam Centering Unlock
    -- CRITICAL: WoW's Accessibility CVars CameraKeepCharacterCentered (default 1) and
    -- CameraReduceUnexpectedMovement lock the camera dead-center and completely block
    -- test_cameraDynamicPitch and test_cameraOverShoulder from tilting or shifting the camera!
    if usingActionCam then
        SafeSetCVar("CameraKeepCharacterCentered", 0)
        SafeSetCVar("CameraReduceUnexpectedMovement", 0)
    else
        if wasDirtyActionCam or forceExperimentalReset then
            local baseCentered = (type(db.savedBaselineCVars) == "table" and db.savedBaselineCVars["CameraKeepCharacterCentered"]) or 1
            SafeSetCVar("CameraKeepCharacterCentered", baseCentered)
        end
        SafeSetCVar("CameraReduceUnexpectedMovement", db.reduceUnexpectedMovement and 1 or 0)
    end
    SafeSetCVar("cameraZSmooth", db.reduceUnexpectedMovement and 1 or 0)

    -- 5. Base Zoom Glide Speed (15 to 50, default 35)
    local scrollSpd = math.max(15, math.min(50, tonumber(db.scrollSpeed) or 35))
    if not scrollSpeedRestoreTimer then
        SafeSetCVar("cameraZoomSpeed", scrollSpd)
    end

    -- 6. Dynamic Horizon Pitch Slider (0% Off to 80%, step 5%) - Item #3 & #14
    if pitchPct > 0 then
        local pad = math.max(0.15, math.min(0.98, math.floor((1.0 - (pitchPct / 100.0)) * 100 + 0.5) / 100))
        local isFlyingNow = (IsFlying and IsFlying()) or false
        local flyPad = pad
        if db.skyridingDiveTracking and isFlyingNow then
            flyPad = math.max(0.10, math.min(0.98, math.floor((pad - 0.12) * 100 + 0.5) / 100))
        end
        SafeSetCVar("test_cameraDynamicPitch", 1, true)
        SafeSetCVar("test_cameraDynamicPitchBaseFovPad", pad, true)
        SafeSetCVar("test_cameraDynamicPitchBaseFovPadDownScale", 0.25, true)
        SafeSetCVar("test_cameraDynamicPitchBaseFovPadFlying", flyPad, true)
        SafeSetCVar("test_cameraDynamicPitchSmartPivotCutoffDist", 10, true)
        SafeSetCVar("cameraPitchMoveSpeed", db.skyridingDiveTracking and 35 or 90)
        lastAppliedPitchNonZero = true
    elseif lastAppliedPitchNonZero or wasDirtyActionCam or forceExperimentalReset then
        SafeSetCVar("test_cameraDynamicPitch", 0, true)
        SafeSetCVar("test_cameraDynamicPitchBaseFovPad", 0.4, true)
        SafeSetCVar("test_cameraDynamicPitchBaseFovPadDownScale", 0.25, true)
        SafeSetCVar("test_cameraDynamicPitchBaseFovPadFlying", 0.75, true)
        SafeSetCVar("test_cameraDynamicPitchSmartPivotCutoffDist", 10, true)
        SafeSetCVar("cameraPitchMoveSpeed", 90)
        lastAppliedPitchNonZero = false
    end

    -- 7. Horizontal Shoulder Offset Slider (-1.5 Left to +1.5 Right, step 0.1) - Item #3 & #14
    if math.abs(shoulderVal) >= 0.05 then
        SafeSetCVar("test_cameraOverShoulder", shoulderVal, true)
        lastAppliedShoulderNonZero = true
    elseif lastAppliedShoulderNonZero or wasDirtyActionCam or forceExperimentalReset then
        SafeSetCVar("test_cameraOverShoulder", 0, true)
        lastAppliedShoulderNonZero = false
    end
end

-- ============================================================================
-- 5. EVENT-DRIVEN SITUATIONAL AUTO-ZOOM STATE MACHINE (0.00% OnUpdate)
-- ============================================================================
local currentProfileKey = "OUTDOOR"

local function IsActiveDelve()
    if type(_G.GetInstanceInfo) == "function" then
        local okI, _, _, diffID = pcall(_G.GetInstanceInfo)
        if okI and not IsSecretValue(diffID) and type(diffID) == "number" and diffID == 208 then
            return true
        end
    end
    if _G.C_DelvesUI and type(_G.C_DelvesUI.HasActiveDelve) == "function" then
        local okD, hasD = pcall(_G.C_DelvesUI.HasActiveDelve)
        if okD and not IsSecretValue(hasD) and hasD == true then return true end
    end
    if _G.C_PartyInfo and type(_G.C_PartyInfo.IsDelveInProgress) == "function" then
        local okP, inP = pcall(_G.C_PartyInfo.IsDelveInProgress)
        if okP and not IsSecretValue(inP) and inP == true then return true end
    end
    if _G.C_PartyInfo and type(_G.C_PartyInfo.IsDelveComplete) == "function" then
        local okC, isC = pcall(_G.C_PartyInfo.IsDelveComplete)
        if okC and not IsSecretValue(isC) and isC == true then return true end
    end
    return false
end

local function GetActiveProfileKey()
    local inInstance, instanceType = false, "none"
    if type(IsInInstance) == "function" then
        local ok, rIn, rType = pcall(IsInInstance)
        if ok then
            inInstance = (not IsSecretValue(rIn) and rIn == true) and true or false
            if not IsSecretValue(rType) and type(rType) == "string" then
                instanceType = rType
            end
        end
    end
    local inCombat = InCombatLockdown and InCombatLockdown() or false
    if inInstance and instanceType == "raid" then
        currentProfileKey = "RAID"
    elseif inCombat and UnitExists("boss1") then
        currentProfileKey = "RAID"
    elseif inInstance and (instanceType == "pvp" or instanceType == "arena") then
        currentProfileKey = "PVP"
    elseif inInstance and instanceType == "party" then
        currentProfileKey = "DUNGEON"
    elseif inInstance and instanceType == "scenario" and IsActiveDelve() then
        currentProfileKey = "DELVE"
    elseif IsActiveDelve() then
        currentProfileKey = "DELVE"
    else
        currentProfileKey = "OUTDOOR"
    end
    return currentProfileKey
end

DynamicZoom.GetActiveProfileKey = GetActiveProfileKey

function DynamicZoom:EvaluateSituationalZoom(reason)
    local db = EnsureDB()
    GetActiveProfileKey()
    if not db.enabled or not db.autoZoomEnabled or IsYieldingConflictHooks() then
        activeContextLabel = "Manual"
        lastAppliedZoomContext = nil
        return
    end

    local inInstance, instanceType = false, "none"
    if type(IsInInstance) == "function" then
        local ok, rIn, rType = pcall(IsInInstance)
        if ok then
            inInstance = (not IsSecretValue(rIn) and rIn == true) and true or false
            if not IsSecretValue(rType) and type(rType) == "string" then
                instanceType = rType
            end
        end
    end
    local isIndoors = IsIndoors and IsIndoors() or false
    local isResting = IsResting and IsResting() or false
    local inCombat = InCombatLockdown and InCombatLockdown() or false

    local targetYards = nil
    local resolvedContextKey = nil

    if inInstance and instanceType == "raid" then
        targetYards = SanitizeZoomYards(db.zoomRaidCombat, 39)
        activeContextLabel = "Raid (" .. tostring(targetYards) .. " yds)"
        resolvedContextKey = "RAID"
    elseif inCombat and UnitExists("boss1") then
        targetYards = SanitizeZoomYards(db.zoomRaidCombat, 39)
        activeContextLabel = "Boss (" .. tostring(targetYards) .. " yds)"
        resolvedContextKey = "BOSS"
    elseif inInstance and (instanceType == "pvp" or instanceType == "arena") then
        targetYards = SanitizeZoomYards(db.zoomPvP, 39)
        activeContextLabel = "PvP (" .. tostring(targetYards) .. " yds)"
        resolvedContextKey = "PVP"
    elseif inInstance and instanceType == "party" then
        targetYards = SanitizeZoomYards(db.zoomDungeon, 39)
        activeContextLabel = "Dungeon (" .. tostring(targetYards) .. " yds)"
        resolvedContextKey = "DUNGEON"
    elseif (inInstance and instanceType == "scenario" and IsActiveDelve()) or IsActiveDelve() then
        targetYards = SanitizeZoomYards(db.zoomDelve, 39)
        activeContextLabel = "Delve (" .. tostring(targetYards) .. " yds)"
        resolvedContextKey = "DELVE"
    elseif isIndoors then
        if db.indoorRule and db.indoorRule ~= "OFF" then
            targetYards = SanitizeZoomYards(tonumber(db.indoorRule), 39)
            activeContextLabel = "Indoors (" .. tostring(targetYards) .. " yds)"
            resolvedContextKey = "INDOORS_" .. tostring(targetYards)
        else
            activeContextLabel = "Indoors (Hold Zoom)"
            return
        end
    elseif isResting and not inCombat then
        if db.cityRule and db.cityRule ~= "OFF" then
            targetYards = SanitizeZoomYards(tonumber(db.cityRule), 39)
            activeContextLabel = "City (" .. tostring(targetYards) .. " yds)"
            resolvedContextKey = "CITY_" .. tostring(targetYards)
        else
            targetYards = SanitizeZoomYards(db.zoomOutdoor, 39)
            activeContextLabel = "Outdoor (" .. tostring(targetYards) .. " yds)"
            resolvedContextKey = "OUTDOOR"
        end
    else
        targetYards = SanitizeZoomYards(db.zoomOutdoor, 39)
        activeContextLabel = "Outdoor (" .. tostring(targetYards) .. " yds)"
        resolvedContextKey = "OUTDOOR"
    end

    local isRegenEvent = (reason == "PLAYER_REGEN_DISABLED" or reason == "PLAYER_REGEN_ENABLED")
    if isRegenEvent and lastAppliedZoomContext == resolvedContextKey then
        return
    end
    lastAppliedZoomContext = resolvedContextKey

    if targetYards then
        self:SmoothZoomTo(targetYards, 0.55)
    end
    if _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
        pcall(_G.DynamicSuite.RefreshHeaderStatus)
    end
end

local function IsNarrativeCameraAddonLoaded()
    local isLoadedFn = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
    if type(isLoadedFn) == "function" then
        for _, name in ipairs({ "DialogueUI", "Immersion", "Storyline" }) do
            local ok, loaded = pcall(isLoadedFn, name)
            if ok and loaded == true then
                return true, name
            end
        end
    end
    return false, nil
end

function DynamicZoom:OnNPCDialogOpen()
    local db = EnsureDB()
    if not db.enabled or not db.npcDialogZoom or IsYieldingConflictHooks() or IsNarrativeCameraAddonLoaded() then return end
    if InCombatLockdown and InCombatLockdown() then return end

    local targetYards = math.max(15, math.min(25, math.floor((tonumber(db.npcDialogYards) or MIN_ZOOM_YARDS) + 0.5)))
    if not preDialogZoomYards then
        local cur = SafeGetCameraZoom()
        if cur and cur > (targetYards + 1.5) then
            preDialogZoomYards = cur
            self:SmoothZoomTo(targetYards, 0.45)
        end
    end
end

function DynamicZoom:OnNPCDialogClose()
    local db = EnsureDB()
    if not db.enabled or not db.npcDialogZoom or IsYieldingConflictHooks() or IsNarrativeCameraAddonLoaded() then return end
    if preDialogZoomYards then
        local restore = SanitizeZoomYards(preDialogZoomYards, 39)
        preDialogZoomYards = nil
        self:SmoothZoomTo(restore, 0.45)
    end
end

function DynamicZoom:SafeExitCleanup()
    CancelZoomGlide()
    local db = EnsureDB()
    if scrollSpeedRestoreTimer then
        scrollSpeedRestoreTimer:Cancel()
        scrollSpeedRestoreTimer = nil
        SafeSetCVar("cameraZoomSpeed", math.max(15, math.min(50, tonumber(db.scrollSpeed) or 35)))
    end
    if lastAppliedPitchNonZero or lastAppliedShoulderNonZero or db._actionCamActive or db._dirtyActionCam then
        local baseCentered = (type(db.savedBaselineCVars) == "table" and db.savedBaselineCVars["CameraKeepCharacterCentered"]) or 1
        SafeSetCVar("CameraKeepCharacterCentered", baseCentered)
        SafeSetCVar("test_cameraOverShoulder", 0, true)
        SafeSetCVar("test_cameraDynamicPitch", 0, true)
        SafeSetCVar("test_cameraDynamicPitchBaseFovPad", 0.4, true)
        SafeSetCVar("test_cameraDynamicPitchBaseFovPadDownScale", 0.25, true)
        SafeSetCVar("test_cameraDynamicPitchBaseFovPadFlying", 0.75, true)
        db._actionCamActive = false
        db._dirtyActionCam = false
    end
end

function DynamicZoom:ResetCameraToBlizzardDefaults()
    CancelZoomGlide()
    local db = EnsureDB()
    local base = (type(db.savedBaselineCVars) == "table") and db.savedBaselineCVars or {}
    local fallbackDefaults = {
        CameraKeepCharacterCentered = 1,
        cameraDistanceMaxZoomFactor = 2.6,
        cameraIndirectVisibility = 1,
        cameraIndirectOffset = 1.5,
        cameraWaterCollision = 0,
        CameraReduceUnexpectedMovement = 1,
        cameraZSmooth = 1,
        cameraZoomSpeed = 20,
        cameraPitchMoveSpeed = 90,
        test_cameraOverShoulder = 0,
        test_cameraDynamicPitch = 0,
        test_cameraDynamicPitchBaseFovPad = 0.4,
        test_cameraDynamicPitchBaseFovPadDownScale = 0.25,
        test_cameraDynamicPitchBaseFovPadFlying = 0.75,
        test_cameraDynamicPitchSmartPivotCutoffDist = 10,
        test_cameraHeadMovementStrength = 0,
        test_cameraTargetFocusEnemyEnable = 0,
        test_cameraTargetFocusInteractEnable = 0,
    }
    for _, k in ipairs(BASELINE_CAMERA_CVAR_KEYS) do
        local isExp = (k:sub(1, 5) == "test_")
        local defVal = SafeGetCVarDefault(k)
        if defVal == nil then
            defVal = base[k]
        end
        if defVal == nil then
            defVal = fallbackDefaults[k]
        end
        if defVal ~= nil then
            SafeSetCVar(k, defVal, isExp)
        end
    end
    -- Re-apply unlocked 39 yd factor so user keeps 39 yd capability after factory camera reset
    SafeSetCVar("cameraDistanceMaxZoomFactor", 2.6)
    lastAppliedPitchNonZero = false
    lastAppliedShoulderNonZero = false
    db._actionCamActive = false
    db._dirtyActionCam = false
    db.pitchTiltPct = 0
    db.shoulderOffsetVal = 0.0
    self:SmoothZoomTo(39, 0.50)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF06B6D4[DynamicZoom]|r Camera pitch & shoulder offsets reset to 0.0 and max distance restored to 39 yards.")
end

-- ============================================================================
-- 6. ACTIVE ADDON CONFLICT SCANNER
-- ============================================================================
function DynamicZoom:ScanConflicts()
    local activeConflicts = {}
    if not C_AddOns or not C_AddOns.GetAddOnEnableState then
        return activeConflicts
    end
    local playerName = UnitName("player")
    for _, entry in ipairs(CONFLICT_REGISTRY) do
        local ok, state = pcall(C_AddOns.GetAddOnEnableState, entry.addon, playerName)
        if ok and state and state > 0 then
            table.insert(activeConflicts, entry)
        end
    end
    return activeConflicts
end

function DynamicZoom:ResolveConflictDisableOther(addonName)
    if C_AddOns and C_AddOns.DisableAddOn then
        pcall(C_AddOns.DisableAddOn, addonName)
    end
    if type(_G.DynamicLoadDB) == "table" then
        _G.DynamicLoadDB.addonStates = _G.DynamicLoadDB.addonStates or {}
        _G.DynamicLoadDB.addonStates[addonName] = "FROZEN"
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cFF06B6D4[DynamicZoom]|r Disabled & froze overlapping addon: |cFFFFFFFF" .. tostring(addonName) .. "|r. Type |cFF06B6D4/reload|r to apply.")
end

-- ============================================================================
-- 7. STATUS STRING & MODULE SUMMARY
-- ============================================================================
function DynamicZoom:GetStatusText()
    local db = EnsureDB()
    local maxStr = tostring(db.maxZoomYards or 39) .. " yds"
    local cleanZone = (activeContextLabel or "Outdoor"):gsub("%s*%b()", "")
    if cleanZone == "" then cleanZone = "Outdoor" end
    local autoStr = db.autoZoomEnabled and cleanZone or "Off"
    local shieldStr = db.indirectVisibility and "ON" or "OFF"
    return "Max Zoom: " .. maxStr .. "  |  Auto-Zoom: " .. autoStr .. "  |  Collision Shield: " .. shieldStr
end

-- ============================================================================
-- 8. UNIFIED 3-TAB OBSIDIAN UI (DIRECTION A WIDGETS, ARTY ICONS & LIVE SLIDERS)
-- ============================================================================
local activeEmbeddedRoot = nil
local standaloneWindow = nil
local openDropdownMenu = nil
local zoomDropdownPopup = nil
local dropdownCatcher = nil

local function CloseAnyDropdown()
    if openDropdownMenu then
        local s, a = GetTheme()
        if openDropdownMenu.ownerBtn then
            ApplyBackdrop(openDropdownMenu.ownerBtn, s.header, s.border)
        end
        if openDropdownMenu.chevronTex then
            openDropdownMenu.chevronTex:SetTexture(ICON_CHEVRON_DOWN)
            openDropdownMenu.chevronTex:SetVertexColor(a.r, a.g, a.b, 0.90)
        end
        local m = openDropdownMenu
        openDropdownMenu = nil
        m.ownerBtn = nil
        m.chevronTex = nil
        if m:IsShown() then
            m:Hide()
        end
    end
    if dropdownCatcher and dropdownCatcher:IsShown() then
        dropdownCatcher:Hide()
    end
end

local function RegisterZoomPopupCloser()
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.RegisterPopupCloser) == "function" then
        pcall(_G.DynamicSuite.UI.RegisterPopupCloser, "DynamicZoom", CloseAnyDropdown)
    end
end
RegisterZoomPopupCloser()

local function EnsureDropdownCatcher()
    if dropdownCatcher then return dropdownCatcher end
    dropdownCatcher = CreateFrame("Button", nil, UIParent)
    dropdownCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
    dropdownCatcher:SetAllPoints(UIParent)
    dropdownCatcher:EnableMouse(true)
    dropdownCatcher:Hide()
    dropdownCatcher:SetScript("OnClick", function()
        CloseAnyDropdown()
    end)
    return dropdownCatcher
end

local function CreateStyledButton(parent, text, width, height, isAccent, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 140, height or 26)

    local function StyleNormal()
        local s, a = GetTheme()
        if isAccent then
            ApplyBackdrop(btn, { a.r * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), a.g * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), a.b * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), 0.95 }, { a.r, a.g, a.b, 0.90 })
        else
            ApplyBackdrop(btn, { s.card[1] + 0.03, s.card[2] + 0.03, s.card[3] + 0.03, 0.95 }, s.border)
        end
    end

    local label = btn:CreateFontString(nil, "OVERLAY")
    SetFontSafe(label, 11, "")
    label:SetPoint("LEFT", btn, "LEFT", 6, 0); label:SetPoint("RIGHT", btn, "RIGHT", -6, 0); label:SetJustifyH("CENTER"); label:SetWordWrap(false)
    label:SetText(text or "")
    label:SetTextColor(0.95, 0.97, 1.0, 1.0)
    btn.label = label

    StyleNormal()

    btn:SetScript("OnEnter", function()
        local _, a = GetTheme()
        ApplyBackdrop(btn, { a.r * 0.35, a.g * 0.35, a.b * 0.35, 0.98 }, { a.r, a.g, a.b, 1.0 })
    end)
    btn:SetScript("OnLeave", function()
        StyleNormal()
    end)
    btn:SetScript("OnClick", function(self, button)
        CloseAnyDropdown()
        if onClick then onClick(self, button) end
    end)
    btn.RefreshTheme = StyleNormal
    return btn
end

local function CreateSectionBox(parent, yTop)
    local surf, _ = GetTheme()
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box.innerPadX = 14
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yTop)
    box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yTop)
    ApplyBackdrop(box, surf.section or surf.panel or { 0.043, 0.050, 0.066, 0.98 }, surf.secBorder or surf.border)
    return box
end

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
    local _, acc = GetTheme()
    local padX = padOverride or (parent and parent.innerPadX) or 0
    local hdr = CreateFrame("Frame", nil, parent)
    hdr:SetHeight(hasSub and 36 or 20)
    local y = yOffset or 0
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
    hdr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -padX, y)

    local leftBar = CreateSolidTex(hdr, "ARTWORK", 1, acc.r, acc.g, acc.b, 1.0)
    leftBar:SetSize(3, hasSub and 34 or 16)
    leftBar:SetPoint("TOPLEFT", hdr, "TOPLEFT", 0, -1)
    hdr.leftBar = leftBar

    local botLine = CreateSolidTex(hdr, "ARTWORK", 1, acc.r, acc.g, acc.b, 0.35)
    botLine:SetHeight(1)
    botLine:SetPoint("TOPLEFT", leftBar, "BOTTOMLEFT", 0, 0)
    botLine:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
    hdr.botLine = botLine

    local txt = hdr:CreateFontString(nil, "OVERLAY")
    SetFontSafe(txt, 11, "")
    if hasSub then
        txt:SetPoint("TOPLEFT", leftBar, "TOPRIGHT", 8, 0)
    else
        txt:SetPoint("LEFT", leftBar, "RIGHT", 8, 0)
    end
    txt:SetPoint("RIGHT", hdr, "RIGHT", -4, 0)
    txt:SetJustifyH("LEFT")
    txt:SetWordWrap(false)
    txt:SetTextColor(acc.r, acc.g, acc.b, 1.0)
    txt:SetText(string.upper(text or ""))
    hdr.txt = txt
    hdr.title = txt

    local subtitle = hdr:CreateFontString(nil, "OVERLAY")
    SetFontSafe(subtitle, 10, "")
    subtitle:SetPoint("TOPLEFT", txt, "BOTTOMLEFT", 0, -3)
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
        local _, a = GetTheme()
        if self.leftBar then self.leftBar:SetColorTexture(a.r, a.g, a.b, 1.0) end
        if self.botLine then self.botLine:SetColorTexture(a.r, a.g, a.b, 0.35) end
        if self.title then self.title:SetTextColor(a.r, a.g, a.b, 1.0) end
        if self.subtitle then self.subtitle:SetTextColor(0.64, 0.70, 0.78, 1.0) end
    end

    return hdr, hasSub and -44 or -26
end
local CreateDzSectionHeader = CreateSectionHeader
DynamicZoom.CreateSectionHeader = CreateSectionHeader

local function CreateCard(parent, height, yOffset, isSubDrawer)
    local surf, acc = GetTheme()
    local padX = (parent and parent.innerPadX) or 0
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetHeight(height or 56)
    if isSubDrawer then
        card:SetPoint("TOPLEFT", parent, "TOPLEFT", padX + 10, yOffset)
        card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(padX + 10), yOffset)
        ApplyBackdrop(card, surf.subCard or surf.panel, surf.border)
        local leftBar = card:CreateTexture(nil, "OVERLAY")
        leftBar:SetWidth(2)
        card.leftBar = leftBar
        leftBar:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -1)
        leftBar:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 1)
        leftBar:SetColorTexture(acc.r, acc.g, acc.b, 0.95)
    else
        card:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, yOffset)
        card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -padX, yOffset)
        ApplyBackdrop(card, surf.card, surf.border)
    end
    return card
end

-- Direction A 2-Pill Segmented Switch: [ Off | Enabled ] + Full-Width Horizontal Sub-Drawer Chevron Bar (DESIGN_SYSTEM.md)
local function CreateSegmentedSwitchCard(parent, yOffset, titleText, descText, getter, setter, tuneSpec)
    local isInitiallyOn = getter() and true or false
    local baseHeight = (tuneSpec and isInitiallyOn) and 84 or 56
    local card = CreateCard(parent, baseHeight, yOffset, false)

    local surf, acc = GetTheme()
    local title = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(title, 11, "")
    title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -9)
    title:SetText(titleText)
    title:SetTextColor(0.97, 0.98, 1.0, 1.0)
    card.title = title

    -- 2-Pill Container: [ Off | Enabled ] with auto-sized pill widths
    local pillGroup = CreateFrame("Frame", nil, card, "BackdropTemplate")
    pillGroup:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -14)
    ApplyBackdrop(pillGroup, surf.header, surf.border)

    local offBtn = CreateFrame("Button", nil, pillGroup, "BackdropTemplate")
    offBtn:SetPoint("LEFT", pillGroup, "LEFT", 2, 0)
    local offTxt = offBtn:CreateFontString(nil, "OVERLAY")
    SetFontSafe(offTxt, 11, "")
    offTxt:SetPoint("CENTER", 0, 0)
    offTxt:SetText("Off")
    local rawOffW = (offTxt.GetUnboundedStringWidth and offTxt:GetUnboundedStringWidth()) or offTxt:GetStringWidth() or 0; local offW = math.max(58, math.ceil(math.max(rawOffW, 24) + 24))
    offBtn:SetSize(offW, 22)

    local offBar = offBtn:CreateTexture(nil, "OVERLAY")
    offBar:SetHeight(1.5)
    offBar:SetPoint("BOTTOMLEFT", offBtn, "BOTTOMLEFT", 1, 1)
    offBar:SetPoint("BOTTOMRIGHT", offBtn, "BOTTOMRIGHT", -1, 1)
    offBar:SetColorTexture(0.973, 0.443, 0.443, 0.85)
    offBar:Hide()
    offBtn.OffBar = offBar

    local onBtn = CreateFrame("Button", nil, pillGroup, "BackdropTemplate")
    onBtn:SetPoint("RIGHT", pillGroup, "RIGHT", -2, 0)

    local checkIcon = onBtn:CreateTexture(nil, "ARTWORK")
    checkIcon:SetSize(6, 6)
    checkIcon:SetPoint("LEFT", onBtn, "LEFT", 8, 0)
    checkIcon:SetColorTexture(1, 1, 1, 0.98)
    if checkIcon.SetSnapToPixelGrid then checkIcon:SetSnapToPixelGrid(false); checkIcon:SetTexelSnappingBias(0) end

    local onTxt = onBtn:CreateFontString(nil, "OVERLAY")
    SetFontSafe(onTxt, 11, "")
    onTxt:SetPoint("CENTER", onBtn, "CENTER", 0, 0)
    onTxt:SetText("Enabled")
    local rawOnW = (onTxt.GetUnboundedStringWidth and onTxt:GetUnboundedStringWidth()) or onTxt:GetStringWidth() or 0; local onW = math.max(84, math.ceil(math.max(rawOnW, 48) + 30))
    onBtn:SetSize(onW, 22)

    pillGroup:SetSize(offW + onW + 6, 26)
    title:SetPoint("RIGHT", pillGroup, "LEFT", -16, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)

    local tuneBar, tuneLabel, tuneChevron
    local subCount = (tuneSpec and tonumber(tuneSpec.count)) or 1
    if tuneSpec then
        tuneBar = CreateFrame("Button", nil, card, "BackdropTemplate")
        tuneBar:SetSize(400, 24)
        tuneBar:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -52)
        tuneBar:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -52)
        tuneBar:EnableMouse(true)
        tuneBar:RegisterForClicks("AnyUp")

        tuneLabel = tuneBar:CreateFontString(nil, "OVERLAY")
        SetFontSafe(tuneLabel, 11, "")
        tuneLabel:SetPoint("CENTER", tuneBar, "CENTER", 8, 0)
        tuneLabel:SetJustifyH("CENTER")
        tuneLabel:SetWordWrap(false)
        tuneLabel:SetText(string.format("Sub-Settings (%d)", subCount))

        tuneChevron = tuneBar:CreateTexture(nil, "ARTWORK")
        tuneChevron:SetSize(11, 11)
        tuneChevron:SetPoint("RIGHT", tuneLabel, "LEFT", -6, 0)
        if tuneChevron.SetSnapToPixelGrid then
            tuneChevron:SetSnapToPixelGrid(false)
            tuneChevron:SetTexelSnappingBias(0)
        end

        tuneBar:SetScript("OnEnter", function(self)
            local _, a = GetTheme()
            local fillAlpha = ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42)
            ApplyBackdrop(self, { a.r * (fillAlpha + 0.10), a.g * (fillAlpha + 0.10), a.b * (fillAlpha + 0.10), 0.98 }, { a.r, a.g, a.b, 1.0 })
            tuneLabel:SetTextColor(1.0, 1.0, 1.0, 1.0)
            tuneChevron:SetVertexColor(1.0, 1.0, 1.0, 1.0)
        end)
        tuneBar:SetScript("OnLeave", function()
            if card.RefreshTuneVisual then card.RefreshTuneVisual() end
        end)
        tuneBar:SetScript("OnClick", function()
            CloseAnyDropdown()
            tuneSpec.onToggle()
        end)
        card.tuneBar = tuneBar
    end

    local desc = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(desc, 10.5, "")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    desc:SetPoint("RIGHT", pillGroup, "LEFT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true); if desc.SetMaxLines then desc:SetMaxLines(2) end
    desc:SetText(descText)
    desc:SetTextColor(0.62, 0.68, 0.76, 1.0)

    local function UpdateVisual()
        local isOn = getter() and true or false
        local s, a = GetTheme()
        local fillAlpha = ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42)
        if isOn then
            offBtn.OffBar:Hide()
            ApplyBackdrop(offBtn, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
            offTxt:SetTextColor(0.55, 0.62, 0.70, 1.0)

            ApplyBackdrop(onBtn, { a.r * fillAlpha, a.g * fillAlpha, a.b * fillAlpha, 0.98 }, { a.r, a.g, a.b, 0.95 })
            checkIcon:Hide()
            checkIcon:SetColorTexture(1, 1, 1, 0.98)
            onTxt:ClearAllPoints()
            onTxt:SetPoint("CENTER", onBtn, "CENTER", 0, 0)
            onTxt:SetTextColor(1.0, 1.0, 1.0, 1.0)
        else
            offBtn.OffBar:Show()
            ApplyBackdrop(offBtn, { 0.118, 0.141, 0.188, 0.98 }, { 0.392, 0.455, 0.545, 0.90 })
            offTxt:SetTextColor(0.886, 0.910, 0.941, 1.0)

            ApplyBackdrop(onBtn, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
            checkIcon:Hide()
            onTxt:ClearAllPoints()
            onTxt:SetPoint("CENTER", onBtn, "CENTER", 0, 0)
            onTxt:SetTextColor(0.55, 0.62, 0.70, 1.0)
        end

        if tuneBar and tuneSpec then
            if isOn then
                tuneBar:Show()
                local open = (tuneSpec.isOpen() ~= false)
                tuneLabel:SetText(string.format("Sub-Settings (%d)", subCount))
                if open then
                    ApplyBackdrop(card, s.card, { a.r, a.g, a.b, 0.85 })
                    ApplyBackdrop(tuneBar, { a.r * (fillAlpha * 0.60), a.g * (fillAlpha * 0.60), a.b * (fillAlpha * 0.60), 0.96 }, { a.r, a.g, a.b, 0.95 })
                    tuneChevron:SetTexture(ICON_CHEVRON_UP)
                    tuneChevron:SetVertexColor(1.0, 1.0, 1.0, 1.0)
                    tuneLabel:SetTextColor(1.0, 1.0, 1.0, 1.0)
                else
                    card:SetHeight(84)
                    ApplyBackdrop(card, s.card, { a.r * 0.65, a.g * 0.65, a.b * 0.65, 0.80 })
                    ApplyBackdrop(tuneBar, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 })
                    tuneChevron:SetTexture(ICON_CHEVRON_DOWN)
                    tuneChevron:SetVertexColor(a.r, a.g, a.b, 0.95)
                    tuneLabel:SetTextColor(0.84, 0.89, 0.96, 1.0)
                end
            else
                tuneBar:Hide()
                card:SetHeight(56)
                ApplyBackdrop(card, s.card, s.border)
            end
        end
    end
    card.RefreshTuneVisual = UpdateVisual

    offBtn:SetScript("OnClick", function()
        CloseAnyDropdown()
        if getter() then
            setter(false)
            if card:IsShown() then UpdateVisual() end
            DynamicZoom:ApplyEngineSettings()
            if _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
                pcall(_G.DynamicSuite.RefreshHeaderStatus)
            end
        end
    end)

    onBtn:SetScript("OnClick", function()
        CloseAnyDropdown()
        if not getter() then
            setter(true)
            if card:IsShown() then UpdateVisual() end
            DynamicZoom:ApplyEngineSettings()
            if _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
                pcall(_G.DynamicSuite.RefreshHeaderStatus)
            end
        end
    end)

    UpdateVisual()
    return card, -(baseHeight + 6)
end

local function CreateSliderCard(parent, yOffset, titleText, descText, minVal, maxVal, stepVal, formatValueFn, getter, setter, extraBtnText, extraBtnClick, isSubDrawer, skipEngineApply, onChangedCallback)
    local cardHeight = isSubDrawer and 52 or 58
    local card = CreateCard(parent, cardHeight, yOffset, isSubDrawer)
    local _, acc = GetTheme()
    stepVal = stepVal or 1

    local title = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(title, 11, "")
    if isSubDrawer then
        title:SetPoint("TOPLEFT", card, "TOPLEFT", 22, -8)
        local pip = card:CreateTexture(nil, "OVERLAY")
        pip:SetSize(5, 5)
        pip:SetPoint("RIGHT", title, "LEFT", -6, 0)
        pip:SetColorTexture(acc.r, acc.g, acc.b, 0.95)
        title:SetText(titleText)
        title:SetTextColor(0.96, 0.98, 1.0, 1.0)
    else
        title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -9)
        title:SetText(titleText)
        title:SetTextColor(0.96, 0.98, 1.0, 1.0)
    end
    card.title = title

    local holder = CreateFrame("Frame", nil, card)
    holder:SetSize(256, 26)
    holder:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    title:SetPoint("RIGHT", holder, "LEFT", -16, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)

    local valBadge = holder:CreateFontString(nil, "OVERLAY")
    SetFontSafe(valBadge, 11, "")
    valBadge:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
    valBadge:SetWidth(52)
    valBadge:SetJustifyH("RIGHT")
    valBadge:SetWordWrap(false)

    local track = CreateFrame("Slider", nil, holder)
    track:SetPoint("LEFT", holder, "LEFT", 0, 0)
    track:SetPoint("RIGHT", valBadge, "LEFT", -10, 0)
    track:SetHeight(4)
    track:SetHitRectInsets(0, 0, -10, -10)
    track:SetOrientation("HORIZONTAL")
    track:SetMinMaxValues(minVal, maxVal)
    track:SetValueStep(stepVal)
    track:SetObeyStepOnDrag(false)
    track:EnableMouse(true)
    track:EnableMouseWheel(true)

    local hairline = track:CreateTexture(nil, "BACKGROUND", nil, -1)
    hairline:SetPoint("TOPLEFT", track, "TOPLEFT", -1, 1)
    hairline:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 1, -1)
    hairline:SetColorTexture(1, 1, 1, 0.14)

    local trackBg = track:CreateTexture(nil, "BACKGROUND", nil, 0)
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0.035, 0.039, 0.051, 0.98)

    if descText and descText ~= "" then
        local desc = card:CreateFontString(nil, "OVERLAY")
        SetFontSafe(desc, 10.5, "")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
        desc:SetPoint("RIGHT", holder, "LEFT", -16, 0)
        desc:SetJustifyH("LEFT")
        desc:SetJustifyV("TOP")
        desc:SetWordWrap(true)
        if desc.SetMaxLines then desc:SetMaxLines(2) end
        desc:SetText(descText)
        desc:SetTextColor(0.62, 0.68, 0.76, 1.0)
    end

    local fill = track:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
    fill:SetWidth(1)
    fill:SetColorTexture(acc.r, acc.g, acc.b, 0.85)
    track.FillBar = fill

    local thumb = track:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(6, 14)
    thumb:SetColorTexture(0.97, 0.98, 1.00, 1.0)
    if thumb.SetSnapToPixelGrid then
        thumb:SetSnapToPixelGrid(false)
        thumb:SetTexelSnappingBias(0)
    end
    track:SetThumbTexture(thumb)

    local isDragging = false
    local isInitializing = false
    local lastCommittedValue = nil

    local function RoundStep(v)
        v = math.max(minVal, math.min(maxVal, v or minVal))
        local st = stepVal or 1
        local rounded = math.floor(((v - minVal) / st) + 0.5) * st + minVal
        rounded = math.max(minVal, math.min(maxVal, rounded))
        return tonumber(string.format("%.2f", rounded)) or rounded
    end

    local function UpdateFill(v, rawVal)
        local _, a = GetTheme()
        fill:SetColorTexture(a.r, a.g, a.b, 0.85)
        if isDragging or track:IsMouseOver() then
            thumb:SetColorTexture(a.r, a.g, a.b, 1.0)
        else
            thumb:SetColorTexture(0.97, 0.98, 1.00, 1.0)
        end
        local posVal = rawVal or v
        local pct = (posVal - minVal) / math.max(0.001, (maxVal - minVal))
        pct = math.max(0, math.min(1.0, pct))
        local w = track:GetWidth()
        if not w or w <= 4 then w = 194 end
        fill:SetWidth(math.max(1, w * pct))
        local disp = formatValueFn and formatValueFn(v) or tostring(v)
        valBadge:SetText(disp)
        valBadge:SetTextColor(a.r, a.g, a.b, 1.0)
    end

    local curVal = RoundStep(getter() or minVal)
    lastCommittedValue = curVal
    isInitializing = true
    track:SetValue(curVal)
    UpdateFill(curVal, curVal)
    isInitializing = false

    track:SetScript("OnSizeChanged", function()
        local r = RoundStep(track:GetValue())
        UpdateFill(r, track:GetValue())
    end)

    local function DispatchSliderApply(rounded)
        if type(onChangedCallback) == "function" then
            onChangedCallback(rounded)
        elseif not skipEngineApply then
            DynamicZoom:ApplyEngineSettings()
        end
    end

    track:SetScript("OnValueChanged", function(_, val)
        if isInitializing then return end
        CloseAnyDropdown()
        local rounded = RoundStep(val)
        UpdateFill(rounded, val)
        if rounded ~= lastCommittedValue then
            lastCommittedValue = rounded
            setter(rounded)
            DispatchSliderApply(rounded)
        end
    end)

    local dragElapsed = 0
    local function UpdateSliderFromCursor(_, elapsed)
        if isDragging and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            isDragging = false
            track:SetScript("OnUpdate", nil)
            local r = RoundStep(getter() or minVal)
            isInitializing = true
            track:SetValue(r)
            UpdateFill(r, r)
            isInitializing = false
            return
        end
        if elapsed then
            dragElapsed = dragElapsed + elapsed
            if dragElapsed < 0.03 then return end
            dragElapsed = 0
        end
        local scale = track:GetEffectiveScale()
        local cx = GetCursorPosition() / scale
        local left, tw = track:GetLeft(), track:GetWidth()
        if left and tw and tw > 0 then
            local pct = math.max(0, math.min(1, (cx - left) / tw))
            track:SetValue(minVal + pct * (maxVal - minVal))
        end
    end

    track:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            CloseAnyDropdown()
            isDragging = true
            dragElapsed = 0
            UpdateSliderFromCursor()
            self:SetScript("OnUpdate", UpdateSliderFromCursor)
        elseif button == "RightButton" and type(extraBtnClick) == "function" then
            CloseAnyDropdown()
            extraBtnClick()
        end
    end)
    track:SetScript("OnMouseUp", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
        local r = RoundStep(getter() or minVal)
        isInitializing = true
        track:SetValue(r)
        UpdateFill(r, r)
        isInitializing = false
    end)
    track:SetScript("OnHide", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
    end)
    track:SetScript("OnEnter", function(self)
        UpdateFill(RoundStep(self:GetValue()), self:GetValue())
        if GameTooltip then
            local _, a = GetTheme()
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(string.format("|cFF%sLeft-Click / Drag:|r |cFFE2E8F0Adjust value|r", a.hex))
            GameTooltip:AddLine(string.format("|cFF%sMousewheel:|r |cFFE2E8F0Fine-tune by 1 step|r", a.hex))
            if extraBtnText and type(extraBtnClick) == "function" then
                GameTooltip:AddLine(string.format("|cFF%sRight-Click:|r |cFFE2E8F0%s|r", a.hex, extraBtnText))
            end
            GameTooltip:Show()
        end
    end)
    track:SetScript("OnLeave", function(self)
        UpdateFill(RoundStep(self:GetValue()), self:GetValue())
        if GameTooltip then GameTooltip:Hide() end
    end)
    track:SetScript("OnMouseWheel", function(_, delta)
        CloseAnyDropdown()
        local cur = getter() or minVal
        local newVal = RoundStep(cur + (delta > 0 and stepVal or -stepVal))
        lastCommittedValue = newVal
        setter(newVal)
        DispatchSliderApply(newVal)
        isInitializing = true
        track:SetValue(newVal)
        UpdateFill(newVal, newVal)
        isInitializing = false
    end)

    card.SetSliderValue = function(_, newVal)
        isInitializing = true
        local r = RoundStep(newVal)
        lastCommittedValue = r
        track:SetValue(r)
        UpdateFill(r, r)
        isInitializing = false
    end

    return card, -(cardHeight + 6)
end

-- Obsidian Dropdown with Arty's Chevron TGA Icons, Auto-Width, Click-Outside Catcher & OnHide Cleanup
local function CreateDropdownCard(parent, yOffset, titleText, descText, optionsList, getter, setter)
    local card = CreateCard(parent, 56, yOffset, false)
    local surf, acc = GetTheme()

    local title = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(title, 11, "")
    title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -9)
    title:SetText(titleText)
    title:SetTextColor(0.96, 0.98, 1.0, 1.0)
    card.title = title

    local dropBtn = CreateFrame("Button", nil, card, "BackdropTemplate")
    dropBtn:SetSize(256, 26)
    dropBtn:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    ApplyBackdrop(dropBtn, surf.header, surf.border)
    title:SetPoint("RIGHT", dropBtn, "LEFT", -16, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)

    local desc = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(desc, 10.5, "")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    desc:SetPoint("RIGHT", dropBtn, "LEFT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true); if desc.SetMaxLines then desc:SetMaxLines(2) end
    desc:SetText(descText)
    desc:SetTextColor(0.62, 0.68, 0.76, 1.0)

    local dropText = dropBtn:CreateFontString(nil, "OVERLAY")
    SetFontSafe(dropText, 11, "")
    dropText:SetPoint("LEFT", dropBtn, "LEFT", 10, 0)
    dropText:SetPoint("RIGHT", dropBtn, "RIGHT", -26, 0)
    dropText:SetJustifyH("LEFT"); dropText:SetWordWrap(false)
    dropText:SetTextColor(0.94, 0.97, 1.0, 1.0)

    local chevron = dropBtn:CreateTexture(nil, "ARTWORK")
    chevron:SetSize(12, 12)
    chevron:SetPoint("RIGHT", dropBtn, "RIGHT", -8, 0)
    chevron:SetTexture(ICON_CHEVRON_DOWN)
    if chevron.SetSnapToPixelGrid then chevron:SetSnapToPixelGrid(false) end
    if chevron.SetTexelSnappingBias then chevron:SetTexelSnappingBias(0) end
    chevron:SetVertexColor(acc.r, acc.g, acc.b, 0.90)

    local function RefreshLabel()
        local curKey = tostring(getter() or "OFF")
        for _, opt in ipairs(optionsList) do
            if tostring(opt.key) == curKey then
                dropText:SetText(opt.label)
                return
            end
        end
        if optionsList[1] then
            dropText:SetText(optionsList[1].label)
        end
    end

    RefreshLabel()

    card:SetScript("OnHide", function()
        if openDropdownMenu and openDropdownMenu.ownerBtn == dropBtn then
            CloseAnyDropdown()
        end
    end)
    if not dropBtn._dzOnHideHooked then
        dropBtn._dzOnHideHooked = true
        dropBtn:HookScript("OnHide", function(self)
            if openDropdownMenu and openDropdownMenu.ownerBtn == self then
                CloseAnyDropdown()
            end
        end)
    end

    dropBtn:SetScript("OnEnter", function(self)
        local _, a = GetTheme()
        ApplyBackdrop(self, { surf.header[1], surf.header[2], surf.header[3], surf.header[4] or 1.0 }, { a.r, a.g, a.b, 0.95 })
        chevron:SetVertexColor(a.r, a.g, a.b, 1.0)
    end)
    dropBtn:SetScript("OnLeave", function(self)
        local s, a = GetTheme()
        if openDropdownMenu and openDropdownMenu:IsShown() and openDropdownMenu.ownerBtn == self then
            ApplyBackdrop(self, { s.header[1], s.header[2], s.header[3], s.header[4] or 1.0 }, { a.r, a.g, a.b, 0.95 })
            chevron:SetVertexColor(a.r, a.g, a.b, 1.0)
        else
            ApplyBackdrop(self, s.header, s.border)
            chevron:SetVertexColor(a.r, a.g, a.b, 0.90)
        end
    end)

    dropBtn:SetScript("OnClick", function(self)
        RegisterZoomPopupCloser()
        if openDropdownMenu and openDropdownMenu:IsShown() and openDropdownMenu.ownerBtn == self then
            CloseAnyDropdown()
            return
        end
        CloseAnyDropdown()

        local catcher = EnsureDropdownCatcher()
        catcher:Show()

        local _, a = GetTheme()
        if not zoomDropdownPopup then
            local menu = CreateFrame("Frame", "DynamicZoomDropdownPopup", UIParent, "BackdropTemplate")
            menu:SetFrameStrata("TOOLTIP")
            menu:SetFrameLevel(220)
            menu:SetToplevel(true)
            menu:SetClampedToScreen(true)
            menu:EnableMouse(true)
            menu.measureFS = menu:CreateFontString(nil, "OVERLAY")
            menu.measureFS:Hide()
            menu.rows = {}
            menu:SetScript("OnHide", function(m)
                local sHide, aHide = GetTheme()
                if m.ownerBtn then
                    ApplyBackdrop(m.ownerBtn, sHide.header, sHide.border)
                end
                if m.chevronTex then
                    m.chevronTex:SetTexture(ICON_CHEVRON_DOWN)
                    m.chevronTex:SetVertexColor(aHide.r, aHide.g, aHide.b, 0.90)
                end
                m.ownerBtn = nil
                m.chevronTex = nil
                if openDropdownMenu == m then
                    openDropdownMenu = nil
                end
                if dropdownCatcher and dropdownCatcher:IsShown() then
                    dropdownCatcher:Hide()
                end
            end)
            if type(UISpecialFrames) == "table" then
                local found = false
                for i = 1, #UISpecialFrames do
                    if UISpecialFrames[i] == "DynamicZoomDropdownPopup" then
                        found = true
                        break
                    end
                end
                if not found then
                    tinsert(UISpecialFrames, "DynamicZoomDropdownPopup")
                end
            end
            zoomDropdownPopup = menu
        end

        local menu = zoomDropdownPopup
        menu.ownerBtn = self
        menu.chevronTex = chevron
        chevron:SetTexture(ICON_CHEVRON_UP)
        chevron:SetVertexColor(a.r, a.g, a.b, 1.0)
        openDropdownMenu = menu

        -- Measure max option width so zero text is ever truncated (Item #28)
        local maxW = 256
        local measureFS = menu.measureFS
        SetFontSafe(measureFS, 11, "")
        for _, opt in ipairs(optionsList) do
            measureFS:SetText(opt.label or "")
            local w = ((measureFS.GetUnboundedStringWidth and measureFS:GetUnboundedStringWidth()) or measureFS:GetStringWidth() or 200) + 46
            if w > maxW then maxW = w end
        end

        menu:SetSize(maxW, (#optionsList * 26) + 6)
        menu:ClearAllPoints()
        menu:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -2)
        ApplyBackdrop(menu, { 0.043, 0.051, 0.071, 0.99 }, { a.r, a.g, a.b, 0.90 })

        for _, r in ipairs(menu.rows) do
            r:Hide()
        end

        for idx, opt in ipairs(optionsList) do
            local item = menu.rows[idx]
            if not item then
                item = CreateFrame("Button", nil, menu, "BackdropTemplate")
                local chk = item:CreateTexture(nil, "ARTWORK")
                chk:SetSize(10, 10)
                chk:SetPoint("LEFT", item, "LEFT", 8, 0)
                chk:SetTexture(ICON_CHECK)
                item.chk = chk

                local itemText = item:CreateFontString(nil, "OVERLAY")
                SetFontSafe(itemText, 11, "")
                itemText:SetPoint("LEFT", item, "LEFT", 24, 0)
                itemText:SetPoint("RIGHT", item, "RIGHT", -8, 0)
                itemText:SetJustifyH("LEFT")
                itemText:SetWordWrap(false)
                item.itemText = itemText
                menu.rows[idx] = item
            end

            item:SetSize(maxW - 6, 24)
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", menu, "TOPLEFT", 3, -3 - ((idx - 1) * 26))
            local isCurrent = (tostring(getter()) == tostring(opt.key))
            if isCurrent then
                ApplyBackdrop(item, { a.r * 0.25, a.g * 0.25, a.b * 0.25, 0.95 }, { a.r, a.g, a.b, 0.65 })
            else
                ApplyBackdrop(item, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
            end

            if isCurrent then
                item.chk:SetVertexColor(a.r, a.g, a.b, 1.0)
                item.chk:Show()
            else
                item.chk:Hide()
            end

            SetFontSafe(item.itemText, 11, "")
            item.itemText:SetText(opt.label)
            item.itemText:SetTextColor(isCurrent and a.r or 0.90, isCurrent and a.g or 0.93, isCurrent and a.b or 0.98, 1.0)

            item:SetScript("OnEnter", function()
                ApplyBackdrop(item, { a.r * 0.30, a.g * 0.30, a.b * 0.30, 0.95 }, { a.r, a.g, a.b, 0.85 })
            end)
            item:SetScript("OnLeave", function()
                if tostring(getter()) == tostring(opt.key) then
                    ApplyBackdrop(item, { a.r * 0.25, a.g * 0.25, a.b * 0.25, 0.95 }, { a.r, a.g, a.b, 0.65 })
                else
                    ApplyBackdrop(item, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
                end
            end)
            item:SetScript("OnClick", function()
                setter(opt.key)
                RefreshLabel()
                CloseAnyDropdown()
                DynamicZoom:ApplyEngineSettings()
            end)
            item:Show()
        end
        menu:Show()
    end)

    return card, -62
end

-- ============================================================================
-- 9. RENDER EMBEDDED WORKSPACE (3 SUB-TABS, LIVE READOUT & 6PX SCROLLBAR)
-- ============================================================================
local function RenderZoomEmbedded(parent)
    if not parent then return end
    RegisterZoomPopupCloser()
    CloseAnyDropdown()
    local db = EnsureDB()
    local surf, acc = GetTheme()

    if parent.dzRoot then
        parent.dzRoot:Hide()
        parent.dzRoot:SetParent(nil)
        parent.dzRoot = nil
    end

    local root = CreateFrame("Frame", nil, parent)
    root:SetAllPoints(parent)
    parent.dzRoot = root
    activeEmbeddedRoot = root

    root:SetScript("OnShow", function(self)
        if self._needsThemeRebuild then
            self._needsThemeRebuild = nil
            local p = self:GetParent()
            if p then
                RenderZoomEmbedded(p)
            end
        end
    end)

    root:SetScript("OnHide", function()
        CloseAnyDropdown()
    end)

    -- Live Camera Distance Readout Bar (Positioned directly below the Top 3-Tab Strip)
    local liveBar = CreateFrame("Frame", nil, root, "BackdropTemplate")
    liveBar:SetHeight(28)
    ApplyBackdrop(liveBar, surf.card, surf.border)

    local contextBadge = liveBar:CreateFontString(nil, "OVERLAY")
    SetFontSafe(contextBadge, 11, "")
    contextBadge:SetPoint("RIGHT", liveBar, "RIGHT", -12, 0)
    contextBadge:SetJustifyH("RIGHT")
    contextBadge:SetWordWrap(false)
    contextBadge:SetTextColor(0.68, 0.75, 0.84, 1.0)

    local liveText = liveBar:CreateFontString(nil, "OVERLAY")
    SetFontSafe(liveText, 11, "")
    liveText:SetPoint("LEFT", liveBar, "LEFT", 12, 0)
    liveText:SetPoint("RIGHT", contextBadge, "LEFT", -10, 0)
    liveText:SetJustifyH("LEFT")
    liveText:SetWordWrap(false)
    liveText:SetTextColor(0.88, 0.93, 1.0, 1.0)

    local readoutElapsed = 0
    local cachedAccentHex = acc.hex
    local function UpdateLiveBarText()
        local _, liveAcc = GetTheme()
        cachedAccentHex = (liveAcc and liveAcc.hex) or cachedAccentHex
        local curZ = SafeGetCameraZoom() or 0
        local maxZ = tonumber(db.maxZoomYards) or 39
        liveText:SetText(string.format("Current Camera Distance: |cFF%s%.1f|r / %.1f yds", cachedAccentHex, curZ, maxZ))
        contextBadge:SetText("Active Profile: |cFF" .. cachedAccentHex .. (activeContextLabel or "Outdoor (39 yds)") .. "|r")
    end
    UpdateLiveBarText()
    liveBar:SetScript("OnUpdate", function(_, elapsed)
        readoutElapsed = readoutElapsed + (elapsed or 0)
        if readoutElapsed < 0.15 then return end
        readoutElapsed = 0
        UpdateLiveBarText()
    end)

    -- Top Segmented 3-Tab Bar (Recessed #0B0D12 Track + 1px Outer Border matching Suite Standard)
    local tabBar = CreateFrame("Frame", nil, root, "BackdropTemplate")
    tabBar:SetPoint("TOPLEFT", root, "TOPLEFT", 14, -10)
    tabBar:SetPoint("TOPRIGHT", root, "TOPRIGHT", -16, -10)
    tabBar:SetHeight(34)
    ApplyBackdrop(tabBar, { 0.043, 0.051, 0.071, 0.98 }, { 1, 1, 1, 0.08 })
    liveBar:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -6)
    liveBar:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", 0, -6)

    local SUB_TABS = {
        { id = 1, label = "Max Zoom & Collision Shield" },
        { id = 2, label = "Context Auto-Zoom" },
        { id = 3, label = "Speed, Pitch & Framing" },
    }

    local tabButtons = {}
    local scrollFrame, scrollContent, UpdateScrollbar
    local tabPages = {}
    local tabHeights = {}
    local conflictBannerPool = {}
    local PopulateActiveTab

    local function BuildTabPage(tabId)
        local page = CreateFrame("Frame", nil, scrollContent)
        page:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, 0)
        page:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, 0)
        page:Hide()
        tabPages[tabId] = page

        if tabId == 1 then
            local sec1a = CreateSectionBox(page, 0)
            local sec1b = CreateSectionBox(page, 0)

            local _, dHdr1 = CreateDzSectionHeader(
                sec1a, -10,
                "MAX CAMERA DISTANCE & FAST SCROLL BOOST",
                "Unlock the 39-yard maximum camera distance and speed up rapid mousewheel scroll flicks."
            )
            local sy1Base = -10 + dHdr1
            local _, dy1 = CreateSliderCard(
                sec1a, sy1Base,
                "Maximum Camera Distance Unlock",
                "Unlocks maximum tactical zoom distance (up to 39 yards) for full boss-room awareness.",
                15, 39, 1,
                function(v) return string.format("%d yds", v) end,
                function() return db.maxZoomYards end,
                function(v) db.maxZoomYards = v end,
                nil,
                nil,
                false,
                true,
                function(v)
                    if db.enabled and not IsYieldingConflictHooks() then
                        local maxFactor = string.format("%.2f", math.max(1.0, math.min(2.6, (tonumber(v) or 39) / 15.0)))
                        SafeSetCVar("cameraDistanceMaxZoomFactor", maxFactor)
                    end
                end
            )
            local syScrollTop = sy1Base + dy1

            local scrollCard = CreateSegmentedSwitchCard(
                sec1a, syScrollTop,
                "Fast Scroll Wheel Boost",
                "Speeds up quick mousewheel flicks so one flick zooms out to 39 yards, while slow clicks step smoothly.",
                function() return db.reactiveScrollEnabled end,
                function(v)
                    db.reactiveScrollEnabled = v
                    if v then
                        db.scrollDrawerOpen = true
                    end
                    if page.ReflowTab1 then page.ReflowTab1() end
                end,
                {
                    count = 1,
                    isOpen = function() return db.scrollDrawerOpen ~= false end,
                    onToggle = function()
                        db.scrollDrawerOpen = not (db.scrollDrawerOpen ~= false)
                        if page.ReflowTab1 then page.ReflowTab1() end
                    end,
                }
            )

            local sub1Card, dySub1 = CreateSliderCard(
                scrollCard, -82,
                "Flick Boost Multiplier",
                "Speed multiplier for rapid consecutive mousewheel scroll flicks.",
                1.0, 5.0, 0.5,
                function(v) return string.format("%.1fx Boost", v) end,
                function() return db.flickBoost end,
                function(v) db.flickBoost = v end,
                nil, nil, true, true
            )
            local scrollExpandedH = math.abs(-82 + dySub1) + 4

            local _, dHdr1b = CreateDzSectionHeader(
                sec1b, -10,
                "SEE-THROUGH FOLIAGE & WALL PROTECTION",
                "Turn intersecting trees, dungeon pillars, and water surfaces see-through instead of snapping the camera inward."
            )
            local sy2PillarTop = -10 + dHdr1b
            local pillarCard = CreateSegmentedSwitchCard(
                sec1b, sy2PillarTop,
                "See-Through Trees & Dungeon Pillars",
                "Turns trees, doorway arches, and pillars see-through instead of snapping your camera forward.",
                function() return db.indirectVisibility end,
                function(v)
                    db.indirectVisibility = v
                    if v then
                        db.pillarDrawerOpen = true
                    end
                    if page.ReflowTab1 then page.ReflowTab1() end
                end,
                {
                    count = 1,
                    isOpen = function() return db.pillarDrawerOpen ~= false end,
                    onToggle = function()
                        db.pillarDrawerOpen = not (db.pillarDrawerOpen ~= false)
                        if page.ReflowTab1 then page.ReflowTab1() end
                    end,
                }
            )

            local pillarSubCard, dyPillarSub = CreateSliderCard(
                pillarCard, -82,
                "Pillar Fade Sensitivity",
                "Controls how early dungeon pillars, arches, and low ceilings turn see-through.",
                1.0, 10.0, 0.5,
                function(v) return string.format("%.1f Buffer", v) end,
                function() return db.indirectOffset end,
                function(v) db.indirectOffset = v end,
                nil, nil, true, true,
                function(v)
                    if db.enabled and not IsYieldingConflictHooks() then
                        SafeSetCVar("cameraIndirectOffset", math.max(1.0, math.min(10.0, tonumber(v) or 5.0)))
                    end
                end
            )
            local pillarExpandedH = math.abs(-82 + dyPillarSub) + 4

            local waterCard, dy4 = CreateSegmentedSwitchCard(
                sec1b, 0,
                "Ignore Water Surface Collision",
                "Prevents the camera from snapping forward when skimming across lakes or rivers during Skyriding.",
                function() return db.waterCollisionShield end,
                function(v) db.waterCollisionShield = v end
            )

            local stairsCard, dy5 = CreateSegmentedSwitchCard(
                sec1b, 0,
                "Smooth Stairs & Uneven Ground",
                "Smooths out sudden vertical camera jerks when running up dungeon stairs, ledges, and uneven ground.",
                function() return db.reduceUnexpectedMovement end,
                function(v) db.reduceUnexpectedMovement = v end
            )

            page.ReflowTab1 = function(isInitialBuild)
                if scrollCard.RefreshTuneVisual then scrollCard.RefreshTuneVisual() end
                local showScrollSubs = db.reactiveScrollEnabled and (db.scrollDrawerOpen ~= false)
                sub1Card:SetShown(showScrollSubs)
                local scrollH = db.reactiveScrollEnabled and (showScrollSubs and scrollExpandedH or 84) or 56
                scrollCard:SetHeight(scrollH)
                local sy1End = syScrollTop - (scrollH + 6)
                local sec1aH = (math.abs(sy1End) - 6) + 12
                sec1a:SetHeight(sec1aH)

                local sec1bY = -sec1aH - 14
                sec1b:ClearAllPoints()
                sec1b:SetPoint("TOPLEFT", page, "TOPLEFT", 0, sec1bY)
                sec1b:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, sec1bY)

                if pillarCard.RefreshTuneVisual then pillarCard.RefreshTuneVisual() end
                local showPillarSub = db.indirectVisibility and (db.pillarDrawerOpen ~= false)
                pillarSubCard:SetShown(showPillarSub)
                local pillarH = db.indirectVisibility and (showPillarSub and pillarExpandedH or 84) or 56
                pillarCard:SetHeight(pillarH)
                local sy2Water = sy2PillarTop - (pillarH + 6)

                local padX = sec1b.innerPadX or 14
                waterCard:ClearAllPoints()
                waterCard:SetPoint("TOPLEFT", sec1b, "TOPLEFT", padX, sy2Water)
                waterCard:SetPoint("TOPRIGHT", sec1b, "TOPRIGHT", -padX, sy2Water)
                local sy2Stairs = sy2Water + dy4

                stairsCard:ClearAllPoints()
                stairsCard:SetPoint("TOPLEFT", sec1b, "TOPLEFT", padX, sy2Stairs)
                stairsCard:SetPoint("TOPRIGHT", sec1b, "TOPRIGHT", -padX, sy2Stairs)
                local sy2End = sy2Stairs + dy5
                local sec1bH = (math.abs(sy2End) - 6) + 12
                sec1b:SetHeight(sec1bH)

                local totalH = sec1aH + 14 + sec1bH + 14
                page:SetHeight(totalH)
                tabHeights[1] = totalH
                if not isInitialBuild and PopulateActiveTab and (db.activeSubTab or 1) == 1 then
                    PopulateActiveTab(true)
                end
            end

            page.ReflowTab1(true)

        elseif tabId == 2 then
            local sec2a = CreateSectionBox(page, 0)
            local sec2b = CreateSectionBox(page, 0)

            local _, dHdr2 = CreateDzSectionHeader(
                sec2a, -10,
                "AUTOMATIC ZONE ZOOM & PROFILES",
                "Automatically glide to your preferred camera distance when entering Raids, Dungeons, Delves, or PvP."
            )
            local syAutoTop = -10 + dHdr2
            local autoZoomCard = CreateSegmentedSwitchCard(
                sec2a, syAutoTop,
                "Automatic Zone Zoom",
                "Automatically maintains your target camera distance across Raids, Dungeons, Delves, and Open World.",
                function() return db.autoZoomEnabled end,
                function(v)
                    db.autoZoomEnabled = v
                    if v then
                        db.autoZoomDrawerOpen = true
                        DynamicZoom:EvaluateSituationalZoom("TOGGLE")
                    else
                        CancelZoomGlide()
                        activeContextLabel = "Manual"
                    end
                    if page.ReflowTab2 then page.ReflowTab2() end
                end,
                {
                    count = 5,
                    isOpen = function() return db.autoZoomDrawerOpen == true end,
                    onToggle = function()
                        db.autoZoomDrawerOpen = not (db.autoZoomDrawerOpen == true)
                        if page.ReflowTab2 then page.ReflowTab2() end
                    end,
                }
            )

            local zoneSubSpecs = {
                {
                    title = "Raid & Boss Combat Target Distance",
                    desc = "Target zoom distance inside Raid instances or during Boss encounters.",
                    get = function() return db.zoomRaidCombat end,
                    set = function(v) db.zoomRaidCombat = v end,
                },
                {
                    title = "Mythic+ & 5-Player Dungeon Target Distance",
                    desc = "Target zoom distance inside 5-player Mythic+ and normal Dungeons.",
                    get = function() return db.zoomDungeon end,
                    set = function(v) db.zoomDungeon = v end,
                },
                {
                    title = "Delves & Scenarios Target Distance",
                    desc = "Target zoom distance inside Delves and Scenarios.",
                    get = function() return db.zoomDelve end,
                    set = function(v) db.zoomDelve = v end,
                },
                {
                    title = "PvP Arenas & Battlegrounds Target Distance",
                    desc = "Target zoom distance inside Arenas and Battlegrounds.",
                    get = function() return db.zoomPvP end,
                    set = function(v) db.zoomPvP = v end,
                },
                {
                    title = "Open World Target Distance",
                    desc = "Default camera distance when questing, flying, or in the Open World.",
                    get = function() return db.zoomOutdoor end,
                    set = function(v) db.zoomOutdoor = v end,
                },
            }

            local zoneSubCards = {}
            local subY = -82
            for _, spec in ipairs(zoneSubSpecs) do
                local zCard, dyZ = CreateSliderCard(
                    autoZoomCard, subY,
                    spec.title,
                    spec.desc,
                    15, 39, 1,
                    function(v) return string.format("%d yds", v) end,
                    spec.get,
                    spec.set,
                    "Test Glide",
                    function() DynamicZoom:SmoothZoomTo(spec.get() or 39, 0.50) end,
                    true,
                    true
                )
                zoneSubCards[#zoneSubCards + 1] = zCard
                subY = subY + dyZ
            end
            local autoZoomExpandedH = math.abs(subY) + 4

            local sy2 = -10
            local _, dHdr2b = CreateDzSectionHeader(
                sec2b, sy2,
                "INDOOR, CITY & NPC DIALOGUE FRAMING RULES",
                "Configure how your camera responds inside buildings, capital sanctuaries, and NPC quest dialogues."
            ); sy2 = sy2 + dHdr2b
            local _, dyIndoor = CreateDropdownCard(
                sec2b, sy2,
                "Indoors & Tunnel Entrance Behaviour",
                "Default 'Do Not Change' prevents dungeon entrance tunnels or buildings from pulling your camera inward.",
                ZONE_RULE_OPTIONS,
                function() return db.indoorRule or "OFF" end,
                function(v) db.indoorRule = v end
            )
            sy2 = sy2 + dyIndoor

            local _, dyCity = CreateDropdownCard(
                sec2b, sy2,
                "Capital Cities & Rested Areas Behaviour",
                "Choose whether to keep your current zoom or transition to a specific distance inside sanctuaries.",
                ZONE_RULE_OPTIONS,
                function() return db.cityRule or "OFF" end,
                function(v) db.cityRule = v end
            )
            sy2 = sy2 + dyCity

            local syNpcTop = sy2
            local npcDialogCard = CreateSegmentedSwitchCard(
                sec2b, syNpcTop,
                "Opt-In NPC Dialogue & Quest Framing",
                "Gently glides closer when speaking with quest or gossip NPCs out of combat and restores your prior zoom on close.",
                function() return db.npcDialogZoom end,
                function(v)
                    db.npcDialogZoom = v
                    if v then
                        db.npcDialogDrawerOpen = true
                    end
                    if page.ReflowTab2 then page.ReflowTab2() end
                end,
                {
                    count = 1,
                    isOpen = function() return db.npcDialogDrawerOpen == true end,
                    onToggle = function()
                        db.npcDialogDrawerOpen = not (db.npcDialogDrawerOpen == true)
                        if page.ReflowTab2 then page.ReflowTab2() end
                    end,
                }
            )

            local npcDialogSubCard, dyNpcSub = CreateSliderCard(
                npcDialogCard, -82,
                "NPC Dialogue Distance",
                "Target camera distance when speaking with quest or gossip NPCs out of combat (15 to 25 yards).",
                15, 25, 1,
                function(v) return string.format("%d yds", v) end,
                function() return db.npcDialogYards or 15 end,
                function(v) db.npcDialogYards = v end,
                "Test Glide",
                function() DynamicZoom:SmoothZoomTo(db.npcDialogYards or 15, 0.45) end,
                true,
                true
            )
            local npcDialogExpandedH = math.abs(-82 + dyNpcSub) + 4

            page.ReflowTab2 = function(isInitialBuild)
                if autoZoomCard.RefreshTuneVisual then autoZoomCard.RefreshTuneVisual() end
                local showAutoSubs = db.autoZoomEnabled and (db.autoZoomDrawerOpen == true)
                for _, zCard in ipairs(zoneSubCards) do
                    zCard:SetShown(showAutoSubs)
                end
                local autoZoomH = db.autoZoomEnabled and (showAutoSubs and autoZoomExpandedH or 84) or 56
                autoZoomCard:SetHeight(autoZoomH)
                local sy2aEnd = syAutoTop - (autoZoomH + 6)
                local sec2aH = (math.abs(sy2aEnd) - 6) + 12
                sec2a:SetHeight(sec2aH)

                local sec2bY = -sec2aH - 14
                sec2b:ClearAllPoints()
                sec2b:SetPoint("TOPLEFT", page, "TOPLEFT", 0, sec2bY)
                sec2b:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, sec2bY)

                if npcDialogCard.RefreshTuneVisual then npcDialogCard.RefreshTuneVisual() end
                local showNpcSub = db.npcDialogZoom and (db.npcDialogDrawerOpen == true)
                npcDialogSubCard:SetShown(showNpcSub)
                local npcH = db.npcDialogZoom and (showNpcSub and npcDialogExpandedH or 84) or 56
                npcDialogCard:SetHeight(npcH)
                local sy2bEnd = syNpcTop - (npcH + 6)
                local sec2bH = (math.abs(sy2bEnd) - 6) + 12
                sec2b:SetHeight(sec2bH)

                local totalH = sec2aH + 14 + sec2bH + 14
                page:SetHeight(totalH)
                tabHeights[2] = totalH
                if not isInitialBuild and PopulateActiveTab and (db.activeSubTab or 1) == 2 then
                    PopulateActiveTab(true)
                end
            end

            page.ReflowTab2(true)

        else
            local y = 0
            local sec3 = CreateSectionBox(page, y)
            local sy = -10
            local _, dHdr3 = CreateDzSectionHeader(
                sec3, sy,
                "CAMERA SPEED, HORIZON PITCH & SHOULDER FRAMING",
                "Fine-tune manual zoom glide speed, upward horizon pitch tilt, and over-the-shoulder framing."
            ); sy = sy + dHdr3
            local speedCard, dy1 = CreateSliderCard(
                sec3, sy,
                "Base Mousewheel Zoom Glide Speed",
                "Controls how fast the camera glides during manual mousewheel scrolling.",
                15, 50, 1,
                function(v) return string.format("%d Speed", v) end,
                function() return db.scrollSpeed end,
                function(v) db.scrollSpeed = v end,
                nil, nil, false, true,
                function(v)
                    if db.enabled and not IsYieldingConflictHooks() then
                        SafeSetCVar("cameraZoomSpeed", math.max(15, math.min(50, tonumber(v) or 35)))
                    end
                end
            )
            sy = sy + dy1

            local pitchCard, dy2
            pitchCard, dy2 = CreateSliderCard(
                sec3, sy,
                "Dynamic Horizon Pitch Tilt",
                "Tilts the camera upward as you zoom out to reveal ground swirlies ahead.",
                0, 80, 5,
                function(v)
                    if v <= 0 then return "0% (Off)" end
                    return string.format("%d%% Tilt", v)
                end,
                function() return db.pitchTiltPct end,
                function(v) db.pitchTiltPct = v end,
                "Reset (0%)",
                function()
                    db.pitchTiltPct = 0
                    DynamicZoom:ApplyEngineSettings(true)
                    if pitchCard and pitchCard.SetSliderValue then
                        pitchCard:SetSliderValue(0)
                    end
                end,
                false,
                false
            )
            sy = sy + dy2

            local shoulderCard, dy3
            shoulderCard, dy3 = CreateSliderCard(
                sec3, sy,
                "Horizontal Shoulder Framing Offset",
                "Keep centred (0.0) for Raid/M+ ground targeting, or offset Left/Right.",
                -1.5, 1.5, 0.1,
                function(v)
                    if math.abs(v) < 0.05 then return "0.0 (Centred)" end
                    if v > 0 then return string.format("+%.1f Right", v) end
                    return string.format("%.1f Left", v)
                end,
                function() return db.shoulderOffsetVal end,
                function(v) db.shoulderOffsetVal = v end,
                "Centre 0.0",
                function()
                    db.shoulderOffsetVal = 0.0
                    DynamicZoom:ApplyEngineSettings(true)
                    if shoulderCard and shoulderCard.SetSliderValue then
                        shoulderCard:SetSliderValue(0.0)
                    end
                end,
                false,
                true,
                function(v)
                    if not db.enabled or IsYieldingConflictHooks() then return end
                    local shoulderVal = math.max(-1.5, math.min(1.5, tonumber(v) or 0.0))
                    if math.abs(shoulderVal) < 0.05 then
                        shoulderVal = 0.0
                    end
                    local shoulderActive = (math.abs(shoulderVal) >= 0.05)
                    local pitchActive = ((tonumber(db.pitchTiltPct) or 0) > 0)
                    local usingActionCam = (pitchActive or shoulderActive)
                    db._actionCamActive = usingActionCam
                    db._dirtyActionCam = usingActionCam
                    if usingActionCam then
                        SafeSetCVar("CameraKeepCharacterCentered", 0)
                        SafeSetCVar("test_cameraOverShoulder", string.format("%.2f", shoulderVal), true)
                    else
                        local baseCentered = (type(db.savedBaselineCVars) == "table" and db.savedBaselineCVars["CameraKeepCharacterCentered"]) or 1
                        SafeSetCVar("CameraKeepCharacterCentered", baseCentered)
                        SafeSetCVar("test_cameraOverShoulder", 0, true)
                    end
                    lastAppliedShoulderNonZero = shoulderActive
                end
            )
            sy = sy + dy3

            local _, dySky = CreateSegmentedSwitchCard(
                sec3, sy,
                "Skyriding Aerial Dive Pitch Padding",
                "When Horizon Pitch Tilt is active (> 0%), expands vertical field-of-view padding during steep Skyriding dives.",
                function() return db.skyridingDiveTracking end,
                function(v) db.skyridingDiveTracking = v end
            )
            sy = sy + dySky

            local resetCard = CreateCard(sec3, 56, sy, false)
            local rTitle = resetCard:CreateFontString(nil, "OVERLAY")
            SetFontSafe(rTitle, 11, "")
            rTitle:SetPoint("TOPLEFT", resetCard, "TOPLEFT", 14, -9)
            rTitle:SetText("Anti-Motion-Sickness Guard & Factory Camera Recovery")
            rTitle:SetTextColor(0.97, 0.98, 1.0, 1.0)

            local resetBtn = CreateStyledButton(resetCard, "Reset Camera Defaults", 184, 26, false, function()
                DynamicZoom:ResetCameraToBlizzardDefaults()
                if speedCard and speedCard.SetSliderValue then speedCard:SetSliderValue(db.scrollSpeed or 35) end
                if pitchCard and pitchCard.SetSliderValue then pitchCard:SetSliderValue(0) end
                if shoulderCard and shoulderCard.SetSliderValue then shoulderCard:SetSliderValue(0.0) end
            end)
            resetBtn:SetPoint("RIGHT", resetCard, "RIGHT", -14, 0)
            rTitle:SetPoint("RIGHT", resetBtn, "LEFT", -16, 0)
            rTitle:SetJustifyH("LEFT")
            rTitle:SetWordWrap(false)

            local rDesc = resetCard:CreateFontString(nil, "OVERLAY")
            SetFontSafe(rDesc, 10.5, "")
            rDesc:SetPoint("TOPLEFT", rTitle, "BOTTOMLEFT", 0, -3)
            rDesc:SetPoint("RIGHT", resetBtn, "LEFT", -16, 0)
            rDesc:SetJustifyH("LEFT")
            rDesc:SetWordWrap(true); if rDesc.SetMaxLines then rDesc:SetMaxLines(2) end
            rDesc:SetText("Camera head-bobbing is permanently locked OFF. Click to reset pitch/shoulder offsets and restore 39 yd zoom.")
            rDesc:SetTextColor(0.62, 0.68, 0.76, 1.0)
            sy = sy - 62
            local sec3H = (math.abs(sy) - 6) + 12
            sec3:SetHeight(sec3H)
            y = y - sec3H - 14
            local totalH = math.abs(y)
            page:SetHeight(totalH)
            tabHeights[3] = totalH
        end

        tabPages[tabId] = page
        return page
    end

    PopulateActiveTab = function(skipPageReflow)
        CloseAnyDropdown()
        local y = -4
        local activeTab = db.activeSubTab or 1

        -- Optional Active Conflict Banner if another camera addon is enabled (deferred when hosted in DynamicSuite)
        local hostedInSuite = (_G.DynamicSuite and _G.DynamicSuite.HasUnifiedModuleConflictBanner and _G.DynamicSuiteMainFrame and root:GetParent() ~= UIParent)
        local conflicts = hostedInSuite and {} or DynamicZoom:ScanConflicts()
        for idx, b in ipairs(conflictBannerPool) do
            b:Hide()
        end
        if not hostedInSuite and #conflicts > 0 then
            for idx, c in ipairs(conflicts) do
                local banner = conflictBannerPool[idx]
                if not banner then
                    banner = CreateCard(scrollContent, 56, y, false)
                    ApplyBackdrop(banner, { 0.26, 0.12, 0.08, 0.95 }, { 0.96, 0.55, 0.15, 0.90 })
                    local bTitle = banner:CreateFontString(nil, "OVERLAY")
                    SetFontSafe(bTitle, 12, "")
                    bTitle:SetPoint("TOPLEFT", banner, "TOPLEFT", 14, -10)
                    banner.bTitle = bTitle

                    local bDesc = banner:CreateFontString(nil, "OVERLAY")
                    SetFontSafe(bDesc, 11, "")
                    bDesc:SetPoint("TOPLEFT", bTitle, "BOTTOMLEFT", 0, -4)
                    bDesc:SetTextColor(0.88, 0.82, 0.74, 1)
                    banner.bDesc = bDesc

                    local resolveBtn = CreateStyledButton(banner, "", 175, 24, true, function()
                        if banner.conflictAddon then
                            DynamicZoom:ResolveConflictDisableOther(banner.conflictAddon)
                            PopulateActiveTab()
                        end
                    end)
                    resolveBtn:SetPoint("RIGHT", banner, "RIGHT", -14, 0)
                    bTitle:SetPoint("RIGHT", resolveBtn, "LEFT", -12, 0)
                    bTitle:SetJustifyH("LEFT")
                    bTitle:SetWordWrap(false)
                    bDesc:SetPoint("RIGHT", resolveBtn, "LEFT", -12, 0)
                    bDesc:SetJustifyH("LEFT")
                    bDesc:SetWordWrap(true)
                    if bDesc.SetMaxLines then bDesc:SetMaxLines(2) end
                    banner.resolveBtn = resolveBtn
                    conflictBannerPool[idx] = banner
                end
                banner.conflictAddon = c.addon
                banner.bTitle:SetText("|cFFF59E0BConflict Detected: " .. c.label .. " is currently active and may cause UI errors or blocked actions.|r")
                banner.bDesc:SetText(c.desc)
                if banner.resolveBtn and banner.resolveBtn.label then
                    banner.resolveBtn.label:SetText("Disable & Freeze " .. c.label)
                end
                banner:ClearAllPoints()
                banner:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, y)
                banner:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, y)
                banner:Show()
                y = y - 62
            end
        end

        if not tabPages[activeTab] then
            BuildTabPage(activeTab)
        end

        for id = 1, 3 do
            if tabPages[id] then
                if id == activeTab then
                    tabPages[id]:ClearAllPoints()
                    tabPages[id]:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, y)
                    tabPages[id]:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, y)
                    tabPages[id]:Show()
                    if not skipPageReflow then
                        if id == 1 and tabPages[1].ReflowTab1 then
                            tabPages[1].ReflowTab1(true)
                        elseif id == 2 and tabPages[2].ReflowTab2 then
                            tabPages[2].ReflowTab2(true)
                        end
                    end
                else
                    tabPages[id]:Hide()
                end
            end
        end

        local sfW = scrollFrame:GetWidth()
        if sfW and sfW > 20 then
            scrollContent:SetWidth(sfW)
        end
        local pageH = tabHeights[activeTab] or 400
        local totalHeight = math.abs(y) + pageH + 16
        scrollContent:SetHeight(math.max(1, totalHeight))
        if UpdateScrollbar then UpdateScrollbar() end
    end

    -- Distinct #14171F Tab Cells with 1px Borders (Category Tabs Never Have Active Zone Dots or Underlines)
    local function RefreshTabBarVisuals()
        local _, a = GetTheme()
        local activeId = db.activeSubTab or 1
        for _, tb in ipairs(tabButtons) do
            if tb.id == activeId then
                ApplyBackdrop(tb.btn, { a.r * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), a.g * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), a.b * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), 0.98 }, { a.r, a.g, a.b, 0.95 })
                tb.txt:SetTextColor(1, 1, 1, 1)
            else
                ApplyBackdrop(tb.btn, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 })
                tb.txt:SetTextColor(0.68, 0.74, 0.82, 1)
            end
        end
    end

    for _, tInfo in ipairs(SUB_TABS) do
        local b = CreateFrame("Button", nil, tabBar, "BackdropTemplate")
        b:SetHeight(26)
        b:SetScript("OnClick", function()
            CloseAnyDropdown()
            db.activeSubTab = tInfo.id
            RefreshTabBarVisuals()
            PopulateActiveTab()
        end)
        local txt = b:CreateFontString(nil, "OVERLAY")
        SetFontSafe(txt, 11, "")
        txt:SetPoint("LEFT", b, "LEFT", 6, 0)
        txt:SetPoint("RIGHT", b, "RIGHT", -6, 0)
        txt:SetJustifyH("CENTER")
        txt:SetWordWrap(false)
        txt:SetText(tInfo.label)
        b.label = txt

        table.insert(tabButtons, { id = tInfo.id, btn = b, txt = txt })
    end

    local function ReflowDzTabs()
        local n = #tabButtons
        if n == 0 then return end
        local w = tabBar:GetWidth()
        if not w or w <= 60 then
            local rw = root:GetWidth() or parent:GetWidth() or 790
            w = rw - 30
        end
        local gap = 6
        local avail = math.max(200, w - 8)
        local step = (avail - gap * (n - 1)) / n
        for i, tb in ipairs(tabButtons) do
            local leftOff = 4 + math.floor((i - 1) * (step + gap) + 0.5)
            local rightOff = (i == n) and -4 or -(w - (4 + math.floor(i * step + (i - 1) * gap + 0.5)))
            tb.btn:ClearAllPoints()
            tb.btn:SetHeight(26)
            tb.btn:SetPoint("LEFT", tabBar, "LEFT", leftOff, 0)
            tb.btn:SetPoint("RIGHT", tabBar, "RIGHT", rightOff, 0)
        end
    end
    tabBar:SetScript("OnSizeChanged", ReflowDzTabs)
    tabBar:HookScript("OnShow", function() C_Timer.After(0, ReflowDzTabs) end)
    C_Timer.After(0, ReflowDzTabs)

    -- ScrollFrame + Custom 4px Slate-Grey Scrollbar Docked Outside at +10
    scrollFrame = CreateFrame("ScrollFrame", nil, root)
    scrollFrame:SetPoint("TOPLEFT", liveBar, "BOTTOMLEFT", 0, -8)
    scrollFrame:SetPoint("TOPRIGHT", liveBar, "BOTTOMRIGHT", 0, -8)
    scrollFrame:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 14, 10)
    scrollFrame:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -16, 10)
    scrollFrame:EnableMouseWheel(true)

    scrollContent = CreateFrame("Frame", nil, scrollFrame)
    local initScrollW = scrollFrame:GetWidth()
    if not initScrollW or initScrollW <= 20 then
        initScrollW = math.max(200, (root:GetWidth() or parent:GetWidth() or 790) - 30)
    end
    scrollContent:SetSize(initScrollW, 1)
    scrollFrame:SetScrollChild(scrollContent)

    local track = CreateFrame("Frame", nil, root, "BackdropTemplate")
    track:SetWidth(4)
    track:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 10, 0)
    track:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 10, 0)
    track:EnableMouse(true)
    track:EnableMouseWheel(true)
    track:SetHitRectInsets(-5, -5, 0, 0)
    ApplyBackdrop(track, { 0.035, 0.039, 0.051, 0.90 }, { 1, 1, 1, 0.04 })

    local thumb = CreateFrame("Button", nil, track, "BackdropTemplate")
    thumb:SetWidth(4)
    thumb:SetHeight(48)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    thumb:EnableMouse(true)
    thumb:EnableMouseWheel(true)
    thumb:SetHitRectInsets(-5, -5, 0, 0)
    ApplyBackdrop(thumb, { 0.38, 0.45, 0.56, 0.85 }, { 0, 0, 0, 0 })

    local function RefreshThumbColor()
        if thumb.isDragging then
            local _, a = GetTheme()
            ApplyBackdrop(thumb, { a.r, a.g, a.b, 1.0 }, { 0, 0, 0, 0 })
        elseif thumb:IsMouseOver() then
            local _, a = GetTheme()
            ApplyBackdrop(thumb, { a.r, a.g, a.b, 0.92 }, { 0, 0, 0, 0 })
        else
            ApplyBackdrop(thumb, { 0.38, 0.45, 0.56, 0.85 }, { 0, 0, 0, 0 })
        end
    end

    UpdateScrollbar = function()
        local viewH = scrollFrame:GetHeight() or 1
        local contentH = scrollContent:GetHeight() or 1
        local maxScroll = math.max(0, contentH - viewH)
        if maxScroll <= 2 then
            track:Hide()
            scrollFrame:SetVerticalScroll(0)
            return
        end
        track:Show()
        local trackH = track:GetHeight() or 200
        local thumbH = math.max(28, math.min(trackH, math.floor((viewH / contentH) * trackH + 0.5)))
        thumb:SetHeight(thumbH)

        local curScroll = math.max(0, math.min(maxScroll, scrollFrame:GetVerticalScroll()))
        local pct = curScroll / maxScroll
        local offset = -pct * math.max(1, trackH - thumbH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, offset)
        RefreshThumbColor()
    end

    local function ScrollByDelta(delta)
        CloseAnyDropdown()
        local maxScroll = math.max(0, (scrollContent:GetHeight() or 1) - (scrollFrame:GetHeight() or 1))
        local nextScroll = math.max(0, math.min(maxScroll, (scrollFrame:GetVerticalScroll() or 0) - (delta * 38)))
        scrollFrame:SetVerticalScroll(nextScroll)
        UpdateScrollbar()
    end

    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        ScrollByDelta(delta)
    end)
    track:SetScript("OnMouseWheel", function(_, delta)
        ScrollByDelta(delta)
    end)
    thumb:SetScript("OnMouseWheel", function(_, delta)
        ScrollByDelta(delta)
    end)

    scrollFrame:SetScript("OnSizeChanged", function(self, w)
        if w and w > 20 then
            scrollContent:SetWidth(w)
        end
        UpdateScrollbar()
    end)

    track:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        CloseAnyDropdown()
        local viewH = scrollFrame:GetHeight() or 1
        local contentH = scrollContent:GetHeight() or 1
        local maxScroll = math.max(0, contentH - viewH)
        if maxScroll <= 0 then return end
        local scale = self:GetEffectiveScale() or 1
        local _, cy = GetCursorPosition()
        cy = cy / scale
        local top = self:GetTop()
        local bottom = self:GetBottom()
        if top and bottom and top > bottom then
            local trackH = top - bottom
            local thumbH = thumb:GetHeight() or 28
            local travel = math.max(1, trackH - thumbH)
            local ratio = math.max(0, math.min(1, ((top - cy) - (thumbH * 0.5)) / travel))
            scrollFrame:SetVerticalScroll(ratio * maxScroll)
            UpdateScrollbar()
        end
    end)

    local function OnThumbDragUpdate(self)
        if not self.isDragging or (IsMouseButtonDown and not IsMouseButtonDown("LeftButton")) then
            self.isDragging = false
            self:SetScript("OnUpdate", nil)
            RefreshThumbColor()
            return
        end
        local _, cursorY = GetCursorPosition()
        local curY = cursorY / (self:GetEffectiveScale() or 1)
        local dy = (self.startY or curY) - curY
        local viewH = scrollFrame:GetHeight() or 1
        local contentH = scrollContent:GetHeight() or 1
        local maxScroll = math.max(0, contentH - viewH)
        local trackH = math.max(1, (track:GetHeight() or 200) - (self:GetHeight() or 28))
        local nextScroll = math.max(0, math.min(maxScroll, (self.startScroll or 0) + (dy / trackH) * maxScroll))
        scrollFrame:SetVerticalScroll(nextScroll)
        UpdateScrollbar()
    end
    thumb:SetScript("OnEnter", function() RefreshThumbColor() end)
    thumb:SetScript("OnLeave", function() RefreshThumbColor() end)
    thumb:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        CloseAnyDropdown()
        self.isDragging = true
        local _, cursorY = GetCursorPosition()
        self.startY = cursorY / (self:GetEffectiveScale() or 1)
        self.startScroll = scrollFrame:GetVerticalScroll() or 0
        RefreshThumbColor()
        self:SetScript("OnUpdate", OnThumbDragUpdate)
    end)
    thumb:SetScript("OnMouseUp", function(self)
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
        RefreshThumbColor()
    end)
    thumb:SetScript("OnHide", function(self)
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
        RefreshThumbColor()
    end)

    RefreshTabBarVisuals()
    PopulateActiveTab()

    DynamicZoom.SelectSubTab = function(selfOrIdx, maybeIdx, maybeExpand)
        local idx = (type(selfOrIdx) == "number") and selfOrIdx or maybeIdx or 1
        local expandDrawers = (type(selfOrIdx) == "number") and maybeIdx or maybeExpand
        db.activeSubTab = idx
        if expandDrawers then
            if idx == 1 then
                db.scrollDrawerOpen = true
                db.pillarDrawerOpen = true
            elseif idx == 2 then
                db.autoZoomDrawerOpen = true
                db.npcDialogDrawerOpen = true
            end
        end
        RefreshTabBarVisuals()
        PopulateActiveTab()
        if scrollFrame then
            scrollFrame:SetVerticalScroll(0)
            UpdateScrollbar()
        end
    end
    DynamicZoom.SelectTab = DynamicZoom.SelectSubTab

    C_Timer.After(0.02, function()
        if tabBar and tabBar:GetWidth() then
            tabBar:GetScript("OnSizeChanged")(tabBar, tabBar:GetWidth())
        end
        if scrollFrame and scrollFrame:GetWidth() then
            scrollContent:SetWidth(scrollFrame:GetWidth())
            UpdateScrollbar()
        end
    end)
end

-- ============================================================================
-- 10. STANDALONE SHELL (/dz) & _G.DynamicSuite ROUTER REGISTRATION
-- ============================================================================
local function EnsureStandaloneWindow()
    if standaloneWindow then
        return standaloneWindow
    end

    local surf, _ = GetTheme()
    local win = CreateFrame("Frame", "DynamicZoomStandaloneWindow", UIParent, "BackdropTemplate")
    win:SetSize(880, 600)
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    win:SetFrameStrata("HIGH")
    win:SetMovable(true)
    win:SetResizable(true)
    if win.SetResizeBounds then
        win:SetResizeBounds(800, 520, 1280, 860)
    end
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    win:SetScript("OnHide", function() CloseAnyDropdown() end)
    ApplyBackdrop(win, surf.bg, surf.border)
    local alreadySpecial = false
    if type(UISpecialFrames) == "table" then
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == "DynamicZoomStandaloneWindow" then
                alreadySpecial = true
                break
            end
        end
        if not alreadySpecial then
            tinsert(UISpecialFrames, "DynamicZoomStandaloneWindow")
        end
    end

    local header = CreateFrame("Frame", nil, win, "BackdropTemplate")
    header:SetPoint("TOPLEFT", win, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", win, "TOPRIGHT", -1, -1)
    header:SetHeight(44)
    ApplyBackdrop(header, surf.header, surf.border)
    win.header = header

    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(26, 26)
    logo:SetPoint("LEFT", header, "LEFT", 14, 0)
    logo:SetTexture(ICON_COLOR)

    local brandTitle = header:CreateFontString(nil, "OVERLAY")
    SetFontSafe(brandTitle, 15, "")
    brandTitle:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    brandTitle:SetWordWrap(false)
    brandTitle:SetText("|cFFCBD5E1Dynamic|r|cFFFFFFFFZoom|r  |cFF64748Bv" .. DynamicZoom.VERSION .. "|r")

    local closeBtn = CreateStyledButton(header, "X", 28, 24, false, function()
        CloseAnyDropdown()
        win:Hide()
    end)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -10, 0)
    win.closeBtn = closeBtn

    local statusText = header:CreateFontString(nil, "OVERLAY")
    SetFontSafe(statusText, 11, "")
    statusText:SetPoint("LEFT", brandTitle, "RIGHT", 12, 0)
    statusText:SetPoint("RIGHT", closeBtn, "LEFT", -12, 0)
    statusText:SetJustifyH("CENTER")
    statusText:SetWordWrap(false)
    statusText:SetTextColor(0.75, 0.82, 0.90, 1.0)
    statusText:SetText(DynamicZoom:GetStatusText())
    win.statusText = statusText

    local footer = CreateFrame("Frame", nil, win, "BackdropTemplate")
    footer:SetHeight(36)
    footer:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 1, 1)
    footer:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -1, 1)
    ApplyBackdrop(footer, surf.header, surf.border)
    win.footer = footer

    local resetModBtn = CreateStyledButton(footer, "Reset DynamicZoom", 142, 24, false, function()
        if DynamicZoom.ResetModuleDefaults then
            DynamicZoom.ResetModuleDefaults()
        end
    end)
    resetModBtn:SetPoint("LEFT", footer, "LEFT", 14, 0)
    win.resetModBtn = resetModBtn

    local blizzResetBtn = CreateStyledButton(footer, "Restore Blizzard Defaults", 174, 24, false, function()
        DynamicZoom:RestoreBlizzardDefaults()
    end)
    blizzResetBtn:SetPoint("LEFT", resetModBtn, "RIGHT", 8, 0)
    win.blizzResetBtn = blizzResetBtn

    local body = CreateFrame("Frame", nil, win)
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 6, -6)
    body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", -6, 4)
    win.body = body

    -- Unified Bottom-Right Corner Resize Grip (14x14, -4/4, Slate at rest -> live Suite Accent hover)
    local grip = CreateFrame("Button", nil, win)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -4, 4)
    grip:SetFrameLevel(footer:GetFrameLevel() + 2)
    grip:EnableMouse(true)

    local gripTex = grip:CreateTexture(nil, "OVERLAY", nil, 5)
    gripTex:SetAllPoints()
    gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    gripTex:SetDesaturated(true)
    gripTex:SetVertexColor(0.55, 0.58, 0.65, 0.75)

    grip:SetScript("OnEnter", function()
        local _, acc = GetTheme()
        gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        gripTex:SetDesaturated(false)
        gripTex:SetVertexColor(acc.r, acc.g, acc.b, 0.95)
    end)
    grip:SetScript("OnLeave", function()
        gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        gripTex:SetDesaturated(true)
        gripTex:SetVertexColor(0.55, 0.58, 0.65, 0.75)
    end)
    grip:SetScript("OnMouseDown", function(_, mBtn)
        if mBtn == "LeftButton" then
            win:StartSizing("BOTTOMRIGHT")
        end
    end)
    grip:SetScript("OnMouseUp", function() win:StopMovingOrSizing() end)

    standaloneWindow = win
    return win
end

local reloadPromptModal = nil

local function ShowDynamicZoomReloadPromptModal()
    if type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() then
        return
    end
    CloseAnyDropdown()
    local surf, acc = GetTheme()
    if not reloadPromptModal then
        local modal = CreateFrame("Frame", "DynamicZoomReloadPromptModal", UIParent, "BackdropTemplate")
        modal:SetSize(432, 180)
        modal:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        modal:SetFrameStrata("DIALOG")
        modal:SetFrameLevel(260)
        modal:SetToplevel(true)
        modal:SetClampedToScreen(true)
        modal:SetMovable(true)
        modal:EnableMouse(true)
        modal:RegisterForDrag("LeftButton")
        modal:SetScript("OnDragStart", modal.StartMoving)
        modal:SetScript("OnDragStop", modal.StopMovingOrSizing)
        ApplyBackdrop(modal, surf.panel or { 0.035, 0.039, 0.051, 0.99 }, { acc.r, acc.g, acc.b, 0.95 })

        if type(_G.UISpecialFrames) == "table" then
            local found = false
            for i = 1, #_G.UISpecialFrames do
                if _G.UISpecialFrames[i] == "DynamicZoomReloadPromptModal" then
                    found = true
                    break
                end
            end
            if not found then
                tinsert(_G.UISpecialFrames, "DynamicZoomReloadPromptModal")
            end
        end

        local topAccent = modal:CreateTexture(nil, "OVERLAY")
        topAccent:SetHeight(2)
        topAccent:SetPoint("TOPLEFT", modal, "TOPLEFT", 1, -1)
        topAccent:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -1, -1)
        topAccent:SetColorTexture(acc.r, acc.g, acc.b, 1.0)
        modal.topAccent = topAccent

        local closeBtn = CreateStyledButton(modal, "X", 22, 20, false, function()
            modal:Hide()
        end)
        closeBtn:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -10, -10)
        modal.closeBtn = closeBtn

        local title = modal:CreateFontString(nil, "OVERLAY")
        SetFontSafe(title, 12, "")
        title:SetPoint("TOPLEFT", modal, "TOPLEFT", 18, -14)
        title:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)
        title:SetJustifyH("LEFT")
        title:SetWordWrap(false)
        modal.title = title

        local headerSep = modal:CreateTexture(nil, "ARTWORK")
        headerSep:SetHeight(1)
        headerSep:SetPoint("TOPLEFT", modal, "TOPLEFT", 18, -38)
        headerSep:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -18, -38)
        headerSep:SetColorTexture(0.200, 0.240, 0.310, 0.65)

        local body = modal:CreateFontString(nil, "OVERLAY")
        SetFontSafe(body, 10.5, "")
        body:SetPoint("TOPLEFT", modal, "TOPLEFT", 18, -50)
        body:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -18, -50)
        body:SetJustifyH("LEFT")
        body:SetJustifyV("TOP")
        body:SetSpacing(3)
        body:SetTextColor(0.886, 0.910, 0.941, 1.0)
        body:SetText("DynamicZoom has restored Blizzard default camera settings.\n\nReload UI now to complete cleanup?")
        modal.body = body

        local reloadBtn = CreateStyledButton(modal, "Reload UI", 138, 28, true, function()
            modal:Hide()
            if type(_G.ReloadUI) == "function" then
                _G.ReloadUI()
            end
        end)
        reloadBtn:SetPoint("BOTTOMRIGHT", modal, "BOTTOM", -6, 16)
        modal.reloadBtn = reloadBtn

        local laterBtn = CreateStyledButton(modal, "Later", 138, 28, false, function()
            modal:Hide()
        end)
        laterBtn:SetPoint("BOTTOMLEFT", modal, "BOTTOM", 6, 16)
        modal.laterBtn = laterBtn

        modal:Hide()
        reloadPromptModal = modal
    end

    ApplyBackdrop(reloadPromptModal, surf.panel or { 0.035, 0.039, 0.051, 0.99 }, { acc.r, acc.g, acc.b, 0.95 })
    if reloadPromptModal.topAccent then reloadPromptModal.topAccent:SetColorTexture(acc.r, acc.g, acc.b, 1.0) end
    if reloadPromptModal.title then
        reloadPromptModal.title:SetText(string.format("|cFF%sDynamic|r|cFFFFFFFFZoom|r  |cFF94A3B8-- Restore Blizzard Defaults|r", acc.hex))
    end
    if reloadPromptModal.closeBtn and reloadPromptModal.closeBtn.RefreshTheme then reloadPromptModal.closeBtn.RefreshTheme() end
    if reloadPromptModal.reloadBtn and reloadPromptModal.reloadBtn.RefreshTheme then reloadPromptModal.reloadBtn.RefreshTheme() end
    if reloadPromptModal.laterBtn and reloadPromptModal.laterBtn.RefreshTheme then reloadPromptModal.laterBtn.RefreshTheme() end
    reloadPromptModal:Show()
    reloadPromptModal:Raise()
end

local function ApplyZoomThemeToUI()
    local surf, acc = GetTheme()
    if activeEmbeddedRoot and activeEmbeddedRoot:GetParent() then
        if activeEmbeddedRoot:IsShown() then
            RenderZoomEmbedded(activeEmbeddedRoot:GetParent())
        else
            activeEmbeddedRoot._needsThemeRebuild = true
        end
    end
    if standaloneWindow then
        ApplyBackdrop(standaloneWindow, surf.bg, surf.border)
        if standaloneWindow.header then ApplyBackdrop(standaloneWindow.header, surf.header, surf.border) end
        if standaloneWindow.footer then ApplyBackdrop(standaloneWindow.footer, surf.header, surf.border) end
        if standaloneWindow.closeBtn and standaloneWindow.closeBtn.RefreshTheme then standaloneWindow.closeBtn.RefreshTheme() end
        if standaloneWindow.resetModBtn and standaloneWindow.resetModBtn.RefreshTheme then standaloneWindow.resetModBtn.RefreshTheme() end
        if standaloneWindow.blizzResetBtn and standaloneWindow.blizzResetBtn.RefreshTheme then standaloneWindow.blizzResetBtn.RefreshTheme() end
        if standaloneWindow.statusText then
            standaloneWindow.statusText:SetText(DynamicZoom:GetStatusText())
        end
    end
    if reloadPromptModal and reloadPromptModal:IsShown() then
        ApplyBackdrop(reloadPromptModal, surf.panel or { 0.035, 0.039, 0.051, 0.99 }, { acc.r, acc.g, acc.b, 0.95 })
        if reloadPromptModal.topAccent then reloadPromptModal.topAccent:SetColorTexture(acc.r, acc.g, acc.b, 1.0) end
        if reloadPromptModal.reloadBtn and reloadPromptModal.reloadBtn.RefreshTheme then reloadPromptModal.reloadBtn.RefreshTheme() end
        if reloadPromptModal.laterBtn and reloadPromptModal.laterBtn.RefreshTheme then reloadPromptModal.laterBtn.RefreshTheme() end
    end
end

function DynamicZoom:RestoreBlizzardDefaults()
    if type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF06B6D4[DynamicZoom]|r Cannot restore Blizzard defaults while in combat. Please leave combat and try again.")
        return false
    end
    CancelZoomGlide()
    local db = EnsureDB()
    local base = (type(db.savedBaselineCVars) == "table") and db.savedBaselineCVars or {}
    local zoomCVars = {
        "cameraDistanceMaxZoomFactor", "cameraIndirectVisibility", "cameraIndirectOffset",
        "cameraWaterCollision", "CameraKeepCharacterCentered", "CameraReduceUnexpectedMovement",
        "cameraZSmooth", "cameraZoomSpeed",
        "test_cameraDynamicPitch", "test_cameraDynamicPitchBaseFovPad",
        "test_cameraDynamicPitchBaseFovPadDownScale", "test_cameraDynamicPitchBaseFovPadFlying",
        "test_cameraDynamicPitchSmartPivotCutoffDist", "cameraPitchMoveSpeed",
        "test_cameraOverShoulder", "test_cameraHeadMovementStrength",
        "test_cameraTargetFocusEnemyEnable", "test_cameraTargetFocusInteractEnable",
    }
    for _, cvarName in ipairs(zoomCVars) do
        local isExp = (cvarName:sub(1, 5) == "test_")
        local targetVal = base[cvarName]
        if targetVal == nil then
            targetVal = SafeGetCVarDefault(cvarName)
        end
        if targetVal ~= nil then
            SafeSetCVar(cvarName, targetVal, isExp)
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cFF06B6D4[DynamicZoom]|r Restored Blizzard default camera settings. Reload UI to complete cleanup.")
    ShowDynamicZoomReloadPromptModal()
    return true
end

local function ResetZoomModuleDefaults()
    _G.DynamicZoomDB = {}
    EnsureDB()
    DynamicZoom:ApplyEngineSettings(true)
    DynamicZoom:EvaluateSituationalZoom("RESET")
    ApplyZoomThemeToUI()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF06B6D4[DynamicZoom]|r Module settings restored to recommended defaults (39 yards).")
end

-- Item #42: Ensure /dz calls _G.DynamicSuite:OpenModule("DynamicZoom") and opens directly to DynamicZoom
local function OpenZoomWorkspace()
    if _G.DynamicSuite and type(_G.DynamicSuite.OpenModule) == "function" then
        local ok = pcall(_G.DynamicSuite.OpenModule, _G.DynamicSuite, "DynamicZoom")
        if ok then return end
        local ok2 = pcall(_G.DynamicSuite.OpenModule, "DynamicZoom")
        if ok2 then return end
    end
    if _G.DynamicLoadUI and type(_G.DynamicLoadUI.OpenToModule) == "function" then
        local ok = pcall(_G.DynamicLoadUI.OpenToModule, "DynamicZoom")
        if ok then return end
    end
    local win = EnsureStandaloneWindow()
    win:Show()
    win:Raise()
    win.statusText:SetText(DynamicZoom:GetStatusText())
    RenderZoomEmbedded(win.body)
end

DynamicZoom.RenderEmbedded = function(self, parent) return RenderZoomEmbedded(parent or self) end
DynamicZoom.ApplyTheme     = function() return ApplyZoomThemeToUI() end
DynamicZoom.ResetDefaults  = function() return ResetZoomModuleDefaults() end
DynamicZoom.ResetModuleDefaults = function() return ResetZoomModuleDefaults() end
DynamicZoom.ResetModule    = function() return ResetZoomModuleDefaults() end
DynamicZoom.Reset          = function() return ResetZoomModuleDefaults() end
DynamicZoom.Open           = function() return OpenZoomWorkspace() end

local function RegisterWithDynamicSuite()
    _G.DynamicSuite = _G.DynamicSuite or {}
    _G.DynamicSuite.modules = _G.DynamicSuite.modules or {}

    local registration = {
        id = "zoom",
        key = "DynamicZoom",
        name = "DynamicZoom",
        title = "DynamicZoom",
        subtitle = "Max Zoom & Camera",
        version = DynamicZoom.VERSION,
        order = 30,
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_zoom.tga",
        fallbackIcon = ICON_COLOR,
        iconWhite = ICON_WHITE,
        iconAccent = ICON_ACCENT,
        slash = "/dz",
        desc = "Unlocks 39-yard max camera distance, fast scroll wheel boost, see-through trees and pillars, and automatic zone zoom.",
        GetStatusText = function() return DynamicZoom:GetStatusText() end,
        RenderEmbedded = function(a, b)
            local parent = (type(a) == "table" and a.CreateFrame == nil and b) and b or a
            return RenderZoomEmbedded(parent)
        end,
        Render = function(a, b)
            local parent = (type(a) == "table" and a.CreateFrame == nil and b) and b or a
            return RenderZoomEmbedded(parent)
        end,
        ApplyTheme = ApplyZoomThemeToUI,
        ResetDefaults = ResetZoomModuleDefaults,
        ResetModuleDefaults = ResetZoomModuleDefaults,
        ResetModule = ResetZoomModuleDefaults,
        Reset = ResetZoomModuleDefaults,
        Open = OpenZoomWorkspace,
        OnDisableInSuite = function()
            if DynamicZoom and DynamicZoom.SafeExitCleanup then
                pcall(DynamicZoom.SafeExitCleanup, DynamicZoom)
            end
        end,
        SelectSubTab = function(a1, a2, a3)
            if DynamicZoom.SelectSubTab then
                return DynamicZoom.SelectSubTab(a1, a2, a3)
            end
        end,
        SelectTab = function(a1, a2, a3)
            if DynamicZoom.SelectSubTab then
                return DynamicZoom.SelectSubTab(a1, a2, a3)
            end
        end,
    }

    _G.DynamicSuite.modules["zoom"] = registration
    _G.DynamicSuite.modules["DynamicZoom"] = registration
    if type(_G.DynamicSuite.RegisterModule) == "function" then
        pcall(_G.DynamicSuite.RegisterModule, _G.DynamicSuite, "zoom", registration)
    end

    DynamicZoom.CHANGELOG = {
        version = DynamicZoom.VERSION or VERSION,
        date = "24/11/2026",
        entries = {
            { type = "FIX",     text = "Fixed the Tab 2 dropdown nil error on Indoors & Capital Cities menus so opening and closing dropdowns updates live Suite Accent chevron tinting cleanly." },
            { type = "UI",      text = "Decluttered Tab 2 by folding the 5 zone target distance sliders into a persisted Sub-Settings (5) drawer under Automatic Zone Zoom (default collapsed on fresh profiles), added a persisted Sub-Settings (1) NPC Dialogue Distance slider (15-25 yds) under Opt-In NPC Dialogue & Quest Framing, kept Base Mousewheel Zoom Glide Speed solely in Tab 3, synced Suite Studio surface themes, added an Obsidian reload prompt modal, and clamped all card and section titles for 800x520 windows." },
            { type = "UI",      text = "Release v2.7.0 (21/11/2026): Updated the standalone window corner resize grip hover highlight to track the active Suite Accent colour instead of hardcoded Blaze Orange." },
            { type = "FEATURE", text = "External Addon Conflict Detector & Auto-Yield Engine (12/11/2026): Added DynamicCam, MaxCam, and ActionCamPlus to the curated HARD conflict registry and automatically yielded NPC dialogue camera framing when DialogueUI, Immersion, or Storyline is active." },
            { type = "FIX",     text = "Eliminated StaticPopupDialogs and UIParent experimental CVar event taint by gating popup suppression to a hooksecurefunc post-hook during active CVar writes." },
            { type = "FIX",     text = "Guarded GetCameraZoom() and C_CVar.GetCVar() against 12.1.5 secret values and deferred CVar writes during combat lockdown to PLAYER_REGEN_ENABLED." },
            { type = "FIX",     text = "Tracked lastAppliedZoomContext so entering or leaving combat only triggers SmoothZoomTo when the resolved zoom profile changes, and persisted ActionCam state across UI reloads." },
            { type = "PERF",    text = "Throttled slider drag OnUpdate with per-slider CVar callbacks, slowed liveBar readout to 0.15s, and attached scrollbar thumb OnUpdate only during active drag." },
            { type = "FEATURE", text = "Added Blizzard Addon Compartment click handler, AUTO_YIELD conflict hook compliance, and ResetModuleDefaults aliases." },
        },
    }
    _G.DynamicSuite.Changelogs = _G.DynamicSuite.Changelogs or {}
    _G.DynamicSuite.Changelogs["DynamicZoom"] = DynamicZoom.CHANGELOG
    _G.DynamicSuite.Changelogs["zoom"] = DynamicZoom.CHANGELOG
end

RegisterWithDynamicSuite()

function _G.DynamicZoom_OnAddonCompartmentClick(addonName, buttonName)
    OpenZoomWorkspace()
end

-- ============================================================================
-- 11. SLASH COMMANDS (/dz, /dynamiczoom) & EVENT DISPATCHER
-- ============================================================================
SLASH_DYNAMICZOOM1 = "/dz"
SLASH_DYNAMICZOOM2 = "/dynamiczoom"
SlashCmdList["DYNAMICZOOM"] = function(msg)
    local cmd = strtrim(string.lower(msg or ""))
    if cmd == "reset" or cmd == "default" or cmd == "defaults" then
        DynamicZoom:ResetCameraToBlizzardDefaults()
    elseif cmd == "max" or cmd == "39" then
        local db = EnsureDB()
        db.maxZoomYards = 39
        DynamicZoom:ApplyEngineSettings()
        DynamicZoom:SmoothZoomTo(39, 0.50)
        DEFAULT_CHAT_FRAME:AddMessage("|cFF06B6D4[DynamicZoom]|r Max camera distance set to 39 yards.")
    else
        OpenZoomWorkspace()
    end
end

DynamicZoom:RegisterEvent("ADDON_LOADED")
DynamicZoom:RegisterEvent("PLAYER_LOGIN")
DynamicZoom:RegisterEvent("PLAYER_ENTERING_WORLD")
DynamicZoom:RegisterEvent("ZONE_CHANGED_NEW_AREA")
DynamicZoom:RegisterEvent("ZONE_CHANGED_INDOORS")
DynamicZoom:RegisterEvent("PLAYER_REGEN_DISABLED")
DynamicZoom:RegisterEvent("PLAYER_REGEN_ENABLED")
DynamicZoom:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
DynamicZoom:RegisterEvent("GOSSIP_SHOW")
DynamicZoom:RegisterEvent("GOSSIP_CLOSED")
DynamicZoom:RegisterEvent("QUEST_DETAIL")
DynamicZoom:RegisterEvent("QUEST_FINISHED")
DynamicZoom:RegisterEvent("MERCHANT_SHOW")
DynamicZoom:RegisterEvent("MERCHANT_CLOSED")
DynamicZoom:RegisterEvent("PLAYER_LOGOUT")

DynamicZoom:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if (arg1 == ADDON_FOLDER or arg1 == "DynamicZoom") and not isInitialized then
            isInitialized = true
            EnsureDB()
            RegisterWithDynamicSuite()
            if IsModuleDisabledInSuite("DynamicZoom") then
                if _G.DynamicSuite and _G.DynamicSuite.modules then
                    if _G.DynamicSuite.modules["zoom"] then _G.DynamicSuite.modules["zoom"]._disabledAtStartup = true end
                    if _G.DynamicSuite.modules["DynamicZoom"] then _G.DynamicSuite.modules["DynamicZoom"]._disabledAtStartup = true end
                end
                self:UnregisterAllEvents()
                return
            end
        end
    elseif event == "PLAYER_LOGIN" then
        EnsureDB()
        RegisterWithDynamicSuite()
        if IsModuleDisabledInSuite("DynamicZoom") then
            if _G.DynamicSuite and _G.DynamicSuite.modules then
                if _G.DynamicSuite.modules["zoom"] then _G.DynamicSuite.modules["zoom"]._disabledAtStartup = true end
                if _G.DynamicSuite.modules["DynamicZoom"] then _G.DynamicSuite.modules["DynamicZoom"]._disabledAtStartup = true end
            end
            self:UnregisterAllEvents()
            return
        end
        EnsureExperimentalPopupHook()
        CaptureBaselineCameraCVars()
        C_Timer.After(0.50, function()
            if not IsModuleDisabledInSuite("DynamicZoom") then
                self:ApplyEngineSettings()
            end
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- 0.2s CVar ownership guard so EnhanceQoL / Leatrix_Plus startup scripts don't overwrite cameraDistanceMaxZoomFactor
        C_Timer.After(0.2, function()
            local db = _G.DynamicZoomDB
            local getGranular = _G.DynamicSuite and _G.DynamicSuite.GetGranularConflictMode
            local yieldZoom = (type(db) == "table" and db.yieldCameraMaxZoom == true)
                or (type(getGranular) == "function" and (getGranular("DynamicZoom", "EnhanceQoL") == "YIELD_TO_EXTERNAL" or getGranular("DynamicZoom", "Leatrix_Plus") == "YIELD_TO_EXTERNAL"))
            if not yieldZoom then
                self:ApplyEngineSettings()
            end
        end)
        -- Mandatory Fix #3: 1.0s Post-Loading-Screen Settle Delay before reading GetCameraZoom()
        C_Timer.After(1.0, function()
            self:ApplyEngineSettings()
            self:EvaluateSituationalZoom("ENTERING_WORLD")
        end)
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED_INDOORS" then
        if zoneChangeDebounceTimer then
            zoneChangeDebounceTimer:Cancel()
            zoneChangeDebounceTimer = nil
        end
        zoneChangeDebounceTimer = C_Timer.NewTimer(0.45, function()
            zoneChangeDebounceTimer = nil
            self:ApplyEngineSettings()
            self:EvaluateSituationalZoom(event)
        end)
    elseif event == "PLAYER_REGEN_DISABLED" then
        self:EvaluateSituationalZoom(event)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingEngineApplyAfterCombat then
            pendingEngineApplyAfterCombat = false
            self:ApplyEngineSettings()
        end
        self:EvaluateSituationalZoom(event)
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        if InCombatLockdown and InCombatLockdown() then
            pendingEngineApplyAfterCombat = true
        else
            self:ApplyEngineSettings()
        end
    elseif event == "GOSSIP_SHOW" or event == "QUEST_DETAIL" or event == "MERCHANT_SHOW" then
        self:OnNPCDialogOpen()
    elseif event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" or event == "MERCHANT_CLOSED" then
        self:OnNPCDialogClose()
    elseif event == "PLAYER_LOGOUT" then
        self:SafeExitCleanup()
    end
end)
