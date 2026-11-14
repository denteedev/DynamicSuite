-- ============================================================================
-- DynamicGroup v1.4.0
-- Premade LFG Region & Composition Filter, 1-Click Sign-Up & Guild/Friend Auto-Invite Engine
-- Retail 12.1.5 (Interface 120105) | Strict ASCII (NonASCII: 0, HasBOM: False)
-- ============================================================================

local addonName = ...
local ADDON_FOLDER = (type(addonName) == "string" and addonName ~= "") and addonName or "DynamicSuite"

local function ResolveAddonVersion(folderName, fallback)
    local fb = fallback or "2.0.5"
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
            local suiteVer = globalTbl._loadedVersion or globalTbl.version or globalTbl.VERSION or (_G.DynamicSuite and _G.DynamicSuite.version) or "2.0.5"
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

local VERSION = ResolveAddonVersion(ADDON_FOLDER, "2.0.5")
if ShouldYieldToOtherInstall(ADDON_FOLDER, "DynamicGroup", VERSION, _G.DynamicGroup) then
    return
end
local DG_NS = {}
local isInitialized = false

local function IsModuleDisabledInSuite(modName)
    local key = modName or "DynamicGroup"
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

local DynamicGroup = _G.DynamicGroup or CreateFrame("Frame", "DynamicGroupEngineFrame")
_G.DynamicGroup = DynamicGroup
DG_NS.DynamicGroup = DynamicGroup
DynamicGroup._loadedBySuite = (ADDON_FOLDER == "DynamicSuite")
DynamicGroup._loadedVersion = VERSION
DynamicGroup.version = VERSION

local ICON_CHECK        = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_check.tga"
local ICON_CHEVRON_DOWN = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga"
local ICON_CHEVRON_UP   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga"
local ICON_COG          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_cog.tga"

local function IsSecretValue(val)
    if val == nil then return false end
    if canaccessvalue and not canaccessvalue(val) then return true end
    if issecretvalue and issecretvalue(val) then return true end
    return false
end

-- ============================================================================
-- 1. DEFAULTS, CONFLICT REGISTRY & REALM-TO-REGION LOOKUP TABLE
-- ============================================================================

DynamicGroup.CONFLICT_REGISTRY = {
    { addon = "PremadeGroupsFilter", label = "Premade Groups Filter", mode = "REPLACE", reason = "Overlaps with DynamicGroup Premade LFG Region & Composition Filter." },
    { addon = "PremadeRegionFilter", label = "Premade Region Filter", mode = "REPLACE", reason = "Overlaps with DynamicGroup Premade LFG Region Filter." },
    { addon = "EllesmereUIGroupFinder", label = "EllesmereUI Group Finder", mode = "YIELD", reason = "Lets EllesmereUI Group Finder handle overlapping list enhancements while keeping DynamicGroup's filters active." },
}

DynamicGroup.SUITE_CONFLICT_REGISTRY = {
    conflicts = { "PremadeGroupsFilter", "PremadeRegionFilter" },
    hardConflicts = { "PremadeGroupsFilter", "PremadeRegionFilter" },
    partialConflicts = { "EllesmereUIGroupFinder", "LFGListFilter", "WorldQuestTab" },
    softConflicts = { "EllesmereUIGroupFinder", "LFGListFilter", "WorldQuestTab" },
    yieldFeature = "overlapping Group Finder features",
    category = "LFG Filtering & Group Automation",
}

local DEFAULTS = {
    -- Tab 1: LFG Premade Filter & Regions
    lfgFilterEnabled = true,
    showPortalBar = true,
    enabledRegions = {
        OCE = true,
        USW = true,
        USC = true,
        USE = true,
        LATAM = true,
        BR = true,
    },
    overlayMode = "COMPACT",         -- Legacy synced key: "COMPACT" | "OFF"
    showEntryOverlay = true,
    minLeaderScore = 0,              -- 0 | 1500 | 2000 | 2500 | 2800 | 3000
    partyFitFilter = "ALL",          -- Legacy summary: "ALL" | "NEEDS_LUST" | "NEEDS_CR" | "NEEDS_BOTH"
    needsTank = false,
    needsHealer = false,
    needsDamage = false,
    noDuplicateClass = false,
    hasTank = false,
    hasHealer = false,
    hasLust = false,
    hasCR = false,
    filteredDungeons = {},           -- [dungeonCode] = true
    sortMode = "SMART_HIDE_FULL",    -- "SMART_HIDE_FULL" | "SCORE_DESC" | "OPEN_SLOTS" | "BLIZZARD"
    hideFullGroups = true,
    smartSort = true,
    rememberSearchText = true,
    lastSearchText = "",
    doubleClickSignUp = true,

    -- Tab 2: Whisper Auto-Invite & Ready Check
    enableWhisperInvite = true,
    whisperInviteScope = "GUILD_AND_FRIENDS", -- "ANYONE" | "GUILD_AND_FRIENDS"
    whisperInviteMode = "FRIENDS_AND_GUILD",  -- Legacy synced key
    whisperKeywords = "inv, invite, 123",
    autoConvertToRaid = true,
    autoPromoteFriendsTanks = false,
    autoAcceptRoleCheck = true,

    -- Tab 3: Party & Keystone Automation
    incomingInviteMode = nil,        -- Migrated on login or defaults to "FRIENDS_AND_GUILD"
    protectActiveQueues = true,
    announceInvites = true,
    autoInsertKeystone = true,
    showGroupTeleportToast = true,
    oneClickSignUp = true,
    autoSelectRole = true,
    autoFillNote = true,
    persistentNote = "",
    appendIlvlToNote = true,
    autoRefreshInterval = 0,         -- 0 | 10 | 15 | 30

    -- UI State
    activeSubTab = 1,
    whisperDrawerExpanded = true,
    noteDrawerExpanded = true,
}

local REGION_ORDER = { "OCE", "USW", "USC", "USE", "LATAM", "BR" }

local REGION_COLORS = {
    OCE     = { r = 0.133, g = 0.827, b = 0.933, hex = "FF22D3EE" }, -- Cyan #22D3EE
    USW     = { r = 0.984, g = 0.573, b = 0.235, hex = "FFFB923C" }, -- Orange #FB923C
    ["US-W"]= { r = 0.984, g = 0.573, b = 0.235, hex = "FFFB923C" },
    USC     = { r = 0.980, g = 0.800, b = 0.082, hex = "FFFACC15" }, -- Gold #FACC15
    ["US-C"]= { r = 0.980, g = 0.800, b = 0.082, hex = "FFFACC15" },
    USE     = { r = 0.957, g = 0.447, b = 0.714, hex = "FFF472B6" }, -- Rose #F472B6
    ["US-E"]= { r = 0.957, g = 0.447, b = 0.714, hex = "FFF472B6" },
    BR      = { r = 0.204, g = 0.827, b = 0.600, hex = "FF34D399" }, -- Emerald #34D399
    LATAM   = { r = 0.753, g = 0.518, b = 0.988, hex = "FFC084FC" }, -- Violet #C084FC
    LA      = { r = 0.753, g = 0.518, b = 0.988, hex = "FFC084FC" }, -- Violet #C084FC
    EU      = { r = 0.376, g = 0.647, b = 0.980, hex = "FF60A5FA" }, -- Blue #60A5FA
    KR      = { r = 0.176, g = 0.831, b = 0.749, hex = "FF2DD4BF" }, -- Teal #2DD4BF
    TW      = { r = 0.176, g = 0.831, b = 0.749, hex = "FF2DD4BF" },
    CN      = { r = 0.176, g = 0.831, b = 0.749, hex = "FF2DD4BF" },
    OTHER   = { r = 0.176, g = 0.831, b = 0.749, hex = "FF2DD4BF" },
    UNKNOWN = { r = 0.580, g = 0.639, b = 0.722, hex = "FF94A3B8" }, -- Slate #94A3B8
}
DynamicGroup.REGION_COLORS = REGION_COLORS

local function GetRegionColor(regionKey)
    if regionKey and REGION_COLORS[regionKey] then
        return REGION_COLORS[regionKey]
    end
    return REGION_COLORS.UNKNOWN
end

function DynamicGroup:GetRegionColor(regionKey)
    return GetRegionColor(regionKey)
end

local REGION_META

local function FormatRegionTag(regionKey, customText)
    local rc = GetRegionColor(regionKey)
    local meta = (regionKey and REGION_META and REGION_META[regionKey]) or nil
    local label = customText or (meta and meta.badge) or ("[" .. tostring(regionKey or "UNK") .. "]")
    return "|c" .. rc.hex .. label .. "|r"
end

REGION_META = {
    OCE     = { code = "OCE",   badge = "OCE",   pillLabel = "OCE",           title = "OCE - Oceanic (Sydney)" },
    USW     = { code = "USW",   badge = "USW",   pillLabel = "US-West",       title = "USW - West (Phoenix/Vegas)" },
    USC     = { code = "USC",   badge = "USC",   pillLabel = "US-Central",    title = "USC - Central (Chicago)" },
    USE     = { code = "USE",   badge = "USE",   pillLabel = "US-East",       title = "USE - East (Virginia/NY)" },
    LATAM   = { code = "LA",    badge = "LA",    pillLabel = "Latin America", title = "LA - Latin America" },
    BR      = { code = "BR",    badge = "BR",    pillLabel = "Brazil",        title = "BR - Brazil" },
    EU      = { code = "EU",    badge = "EU",    pillLabel = "Europe",        title = "EU - Europe" },
    KR      = { code = "KR",    badge = "KR",    pillLabel = "Korea",         title = "KR - Korea" },
    TW      = { code = "TW",    badge = "TW",    pillLabel = "Taiwan",        title = "TW - Taiwan" },
    CN      = { code = "CN",    badge = "CN",    pillLabel = "China",         title = "CN - China" },
    OTHER   = { code = "OTHER", badge = "OTHER", pillLabel = "Other",         title = "Other Region" },
    UNKNOWN = { code = "UNK",   badge = "UNK",   pillLabel = "Unknown",       title = "Unknown Region" },
}

local RAW_REALMS_BY_REGION = {
    OCE = {
        "Frostmourne", "Barthilas", "Thaurissan", "Jubei'Thos", "Gundrak",
        "Dreadmaul", "Nagrand", "Caelestrasz", "Saurfang", "Aman'Thul",
        "Khaz'goroth", "Dath'Remar", "Remulos", "Arugal", "Yojamba",
    },
    USW = {
        "Tichondrius", "Proudmoore", "Hyjal", "Kil'jaeden", "Blackrock",
        "Frostwolf", "Ner'zhul", "Silver Hand", "Cenarius", "Lightbringer",
        "Bonechewer", "Daggerspine", "Gurubashi", "Hakkar", "Aegwynn",
        "Akama", "Antonidas", "Borean Tundra", "Cairne", "Drak'Tharon",
        "Drenden", "Echo Isles", "Farstriders", "Fenris", "Garrosh",
        "Hydraxis", "Korialstrasz", "Misha", "Mok'Nathal", "Moonrunner",
        "Nazgrel", "Nesingwary", "Nordrassil", "Quel'dorei", "Rivendare",
        "Shandris", "Shu'halo", "Sisters of Elune", "Suramar", "Tortheldrin",
        "Uldum", "Vashj", "Warcraft", "Windrunner", "Winterhoof", "Wyrmrest Accord",
    },
    USC = {
        "Illidan", "Mal'Ganis", "Bleeding Hollow", "Emerald Dream", "Sargeras",
        "Kel'Thuzad", "Stormreaver", "Whisperwind", "Azgalor", "Azshara",
        "Baelgun", "Blackhand", "Blackwater Raiders", "Blade's Edge", "Blood Furnace",
        "Burning Blade", "Cho'gall", "Coilfang", "Darkspear", "Deathwing",
        "Demon Soul", "Destromath", "Dethecus", "Detheroc", "Doomhammer",
        "Draenor", "Dragonblight", "Eitrigg", "Agamaggan", "Aggramar",
        "Alexstrasza", "Alleria", "Archimonde", "Burning Legion", "Garona",
        "Ghostlands", "Greymane", "Gul'dan", "Hellscream", "Kael'thas",
        "Kalecgos", "Kirin Tor", "Laughing Skull", "Lightning's Blade", "Madoran",
        "Maelstrom", "Mannoroth", "Medivh", "Nazjatar",
        "Perenolde", "Ravencrest", "Shattered Halls", "Shattered Hand", "Skullcrusher",
        "Spinebreaker", "Spirestone", "Staghelm", "The Underbog", "Thunderhorn",
        "Thunderlord", "Twisting Nether", "Ursin", "Vek'nilash", "Wildhammer",
        "Zangarmarsh",
    },
    USE = {
        "Area 52", "Stormrage", "Zul'jin", "Thrall", "Dalaran",
        "Moon Guard", "Turalyon", "Gilneas", "Arthas",
        "Aerie Peak", "Altar of Storms", "Alterac Mountains", "Andorhal", "Anetheron",
        "Anub'arak", "Anvilmar", "Argent Dawn", "Arygos", "Auchindoun",
        "Balnazzar", "Black Dragonflight", "Bladefist", "Bloodhoof", "Bloodscalp",
        "Bolvar", "Bronzebeard", "Connected Area 52", "Darrowmere", "Duskwood",
        "Earthen Ring", "Eldre'Thalas", "Elune", "Eonar", "Eredar",
        "Exodar", "Executus", "Feathermoon", "Firetree", "Frostmane",
        "Galakrond", "Gnomeregan", "Gorefiend", "Grizzly Hills", "Haomarush",
        "Jaedenar", "Kargath", "Khadgar", "Kilrogg", "Korgath",
        "Kul Tiras", "Lethon", "Light's Hope", "Llane", "Lothar",
        "Magtheridon", "Malfurion", "Malorne", "Malygos", "Muradin",
        "Nathrezim", "Norgannon", "Onyxia", "Runetotem",
        "Scilla", "Sen'jin", "Sentinels", "Shadowmoon", "Shadow Council",
        "Silvermoon", "Skywall", "Smolderthorn", "Steamwheedle Cartel", "Stonemaul",
        "Tanaris", "Terenas", "Terokkar", "The Forgotten Coast", "The Scryers",
        "The Venture Co", "Trollbane", "Uldaman", "Undermine", "Uther",
        "Velen", "Warsong", "Ysera", "Ysondre", "Zuluhed",
    },
    LATAM = {
        "Ragnaros", "Quel'Thalas", "QuelThalas", "Drakkari",
    },
    BR = {
        "Azralon", "Nemesis", "Goldrinn", "Tol Barad", "TolBarad", "Gallywix",
    },
}

local REALM_TO_REGION = {}

local function NormalizeRealmKey(realm)
    if not realm or IsSecretValue(realm) or type(realm) ~= "string" then return "" end
    local ok, res = pcall(function()
        return (realm:lower():gsub("[%s'%-%._]", ""))
    end)
    return (ok and res) or ""
end

for _, regionKey in ipairs(REGION_ORDER) do
    local list = RAW_REALMS_BY_REGION[regionKey]
    if list then
        for _, realmName in ipairs(list) do
            REALM_TO_REGION[realmName] = regionKey
            REALM_TO_REGION[realmName:lower()] = regionKey
            REALM_TO_REGION[NormalizeRealmKey(realmName)] = regionKey
        end
    end
end

-- ============================================================================
-- 2. UTILITY, FONT & 90/8/2 SUITE ACCENT PALETTE HELPERS
-- ============================================================================

local function GetFontPath()
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.GetFont) == "function" then local okF, pF = pcall(_G.DynamicSuite.UI.GetFont); if okF and type(pF) == "string" and pF ~= "" then return pF end end
    if _G.DynamicSuite and type(_G.DynamicSuite.GetFontPath) == "function" then
        local ok, p = pcall(_G.DynamicSuite.GetFontPath, _G.DynamicSuite)
        if ok and type(p) == "string" and p ~= "" then return p end
    end
    if _G.DynamicLoadUI and type(_G.DynamicLoadUI.GetActiveFontPath) == "function" then
        local ok, p = pcall(_G.DynamicLoadUI.GetActiveFontPath)
        if ok and type(p) == "string" and p ~= "" then return p end
    end
    return "Fonts\\FRIZQT__.TTF"
end

local function SetSafeFont(fs, size, flags)
    if not fs or not fs.SetFont then return end
    local ok = fs:SetFont(GetFontPath(), size or 12, flags or "")
    if not ok then
        fs:SetFont("Fonts\\FRIZQT__.TTF", size or 12, flags or "")
    end
end

local function DisableTexPixelSnap(tex)
    if not tex then return end
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
end

local function FormatColorHex(r, g, b)
    local ri = math.max(0, math.min(255, math.floor((tonumber(r) or 0.22) * 255 + 0.5)))
    local gi = math.max(0, math.min(255, math.floor((tonumber(g) or 0.74) * 255 + 0.5)))
    local bi = math.max(0, math.min(255, math.floor((tonumber(b) or 0.97) * 255 + 0.5)))
    return string.format("FF%02X%02X%02X", ri, gi, bi)
end

local function GetSuiteAccent()
    if _G.DynamicSuite and type(_G.DynamicSuite.GetSuiteAccent) == "function" then
        local ok, a, b, c, d = pcall(_G.DynamicSuite.GetSuiteAccent, _G.DynamicSuite)
        if ok then
            if type(a) == "table" then
                local r = tonumber(a.r or a[1]) or 0.22
                local g = tonumber(a.g or a[2]) or 0.74
                local bl = tonumber(a.b or a[3]) or 0.97
                local hx = a.hex or FormatColorHex(r, g, bl)
                if #hx == 6 then hx = "FF" .. hx end
                return r, g, bl, hx
            elseif type(a) == "number" and type(b) == "number" and type(c) == "number" then
                local hx = (type(d) == "string" and d ~= "") and d or FormatColorHex(a, b, c)
                if #hx == 6 then hx = "FF" .. hx end
                return a, b, c, hx
            end
        end
    end
    if _G.DynamicLoadUI and type(_G.DynamicLoadUI.GetActiveThemeColors) == "function" then
        local ok, cols = pcall(_G.DynamicLoadUI.GetActiveThemeColors)
        if ok and type(cols) == "table" and type(cols.accent) == "table" then
            local r = tonumber(cols.accent[1] or cols.accent.r) or 0.22
            local g = tonumber(cols.accent[2] or cols.accent.g) or 0.74
            local bl = tonumber(cols.accent[3] or cols.accent.b) or 0.97
            return r, g, bl, FormatColorHex(r, g, bl)
        end
    end
    return 0.22, 0.74, 0.97, "FF38BDF8"
end

local function ColorWithAccent(text)
    local _, _, _, hex = GetSuiteAccent()
    return "|c" .. hex .. tostring(text or "") .. "|r"
end

local function PrintMsg(msg)
    DEFAULT_CHAT_FRAME:AddMessage(ColorWithAccent("Dynamic") .. "|cFFFFFFFFGroup|r: " .. tostring(msg))
end

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

local function SyncLegacyPartyFitFromFlags(db)
    if type(db) ~= "table" then return end
    if db.hasLust and db.hasCR then
        db.partyFitFilter = "NEEDS_BOTH"
    elseif db.hasLust then
        db.partyFitFilter = "NEEDS_LUST"
    elseif db.hasCR then
        db.partyFitFilter = "NEEDS_CR"
    else
        db.partyFitFilter = "ALL"
    end
end

local function SyncWhisperInviteSettings(db)
    if not db.enableWhisperInvite then
        db.whisperInviteMode = "OFF"
    else
        if db.whisperInviteScope == "ANYONE" then
            db.whisperInviteMode = "ANYONE"
        else
            db.whisperInviteMode = "FRIENDS_AND_GUILD"
        end
    end
end

local function EnsureDB()
    if type(_G.DynamicGroupDB) ~= "table" then
        _G.DynamicGroupDB = {}
    end
    if _G.DynamicGroupDB.incomingInviteMode == nil then
        if type(_G.DynamicPrepDB) == "table" and _G.DynamicPrepDB.autoAcceptInvites ~= nil then
            local legacy = _G.DynamicPrepDB.autoAcceptInvites
            if legacy == true or legacy == "FRIENDS_AND_GUILD" or legacy == "ALL" then
                _G.DynamicGroupDB.incomingInviteMode = "FRIENDS_AND_GUILD"
            elseif legacy == "FRIENDS_ONLY" or legacy == "FRIENDS" then
                _G.DynamicGroupDB.incomingInviteMode = "FRIENDS_ONLY"
            elseif legacy == "GUILD_ONLY" or legacy == "GUILD" then
                _G.DynamicGroupDB.incomingInviteMode = "GUILD_ONLY"
            elseif legacy == false or legacy == "OFF" or legacy == "DISABLED" then
                _G.DynamicGroupDB.incomingInviteMode = "OFF"
            else
                _G.DynamicGroupDB.incomingInviteMode = "FRIENDS_AND_GUILD"
            end
        else
            _G.DynamicGroupDB.incomingInviteMode = "FRIENDS_AND_GUILD"
        end
    end

    if _G.DynamicGroupDB.autoInsertKeystone == nil and type(_G.DynamicPrepDB) == "table" and _G.DynamicPrepDB.autoSlotKeystone ~= nil then
        _G.DynamicGroupDB.autoInsertKeystone = (_G.DynamicPrepDB.autoSlotKeystone and true or false)
        _G.DynamicGroupDB._migratedKeystoneFromPrep = true
    end

    -- Migrate legacy partyFitFilter lust/CR selections into multi-toggle flags before CopyDefaults
    if _G.DynamicGroupDB.hasLust == nil and (_G.DynamicGroupDB.partyFitFilter == "NEEDS_LUST" or _G.DynamicGroupDB.partyFitFilter == "NEEDS_BOTH") then
        _G.DynamicGroupDB.hasLust = true
    end
    if _G.DynamicGroupDB.hasCR == nil and (_G.DynamicGroupDB.partyFitFilter == "NEEDS_CR" or _G.DynamicGroupDB.partyFitFilter == "NEEDS_BOTH") then
        _G.DynamicGroupDB.hasCR = true
    end

    CopyDefaults(DEFAULTS, _G.DynamicGroupDB)
    if _G.DynamicGroupDB._migratedKeystoneFromPrep ~= true and type(_G.DynamicPrepDB) == "table" and _G.DynamicPrepDB.autoSlotKeystone ~= nil then
        if _G.DynamicPrepDB.autoSlotKeystone == false then
            _G.DynamicGroupDB.autoInsertKeystone = false
        end
        _G.DynamicGroupDB._migratedKeystoneFromPrep = true
    end
    if type(_G.DynamicGroupDB.enabledRegions) ~= "table" then
        _G.DynamicGroupDB.enabledRegions = CopyDefaults(DEFAULTS.enabledRegions, {})
    end
    if type(_G.DynamicGroupDB.filteredDungeons) ~= "table" then
        _G.DynamicGroupDB.filteredDungeons = {}
    end

    -- Migrate legacy partyFitFilter values to Party Utility Filter
    if _G.DynamicGroupDB.partyFitFilter == "NEEDS_MY_ROLE" or _G.DynamicGroupDB.partyFitFilter == "HAS_TANK_OR_HEAL" then
        _G.DynamicGroupDB.partyFitFilter = "ALL"
    end
    SyncLegacyPartyFitFromFlags(_G.DynamicGroupDB)

    if not _G.DynamicGroupDB.v121_cleanOverlay then
        _G.DynamicGroupDB.v121_cleanOverlay = true
        if _G.DynamicGroupDB.overlayMode == "FULL" then
            _G.DynamicGroupDB.overlayMode = "COMPACT"
        end
    end
    if not _G.DynamicGroupDB.v200_sleekOverlay then
        _G.DynamicGroupDB.v200_sleekOverlay = true
        if _G.DynamicGroupDB.overlayMode == "FULL" then
            _G.DynamicGroupDB.overlayMode = "COMPACT"
        end
    end
    if _G.DynamicGroupDB.showEntryOverlay == nil then
        _G.DynamicGroupDB.showEntryOverlay = (_G.DynamicGroupDB.overlayMode ~= "OFF")
    end
    if _G.DynamicGroupDB.showEntryOverlay then
        _G.DynamicGroupDB.overlayMode = "COMPACT"
    else
        _G.DynamicGroupDB.overlayMode = "OFF"
    end
    _G.DynamicGroupDB.mythicPlusOnly = nil
    _G.DynamicGroupDB.fitMyRole = nil

    -- Migrate legacy whisperInviteMode if needed
    if _G.DynamicGroupDB.whisperInviteMode == "OFF" and _G.DynamicGroupDB.enableWhisperInvite == nil then
        _G.DynamicGroupDB.enableWhisperInvite = false
    elseif _G.DynamicGroupDB.whisperInviteMode == "ANYONE" and _G.DynamicGroupDB.whisperInviteScope == nil then
        _G.DynamicGroupDB.whisperInviteScope = "ANYONE"
    end
    SyncWhisperInviteSettings(_G.DynamicGroupDB)

    return _G.DynamicGroupDB
end

local function IsYieldingSharedHooks()
    local db = _G.DynamicGroupDB
    if type(db) == "table" then
        if db.yieldHooks == true then return true end
        if type(db.yieldHooks) == "table" and next(db.yieldHooks) ~= nil then
            return true
        end
    end
    return false
end

function DynamicGroup:IsYieldingSharedHooks()
    return IsYieldingSharedHooks()
end

function DynamicGroup:GetActiveRegionCount()
    local db = EnsureDB()
    local count = 0
    for _, key in ipairs(REGION_ORDER) do
        if db.enabledRegions[key] ~= false then
            count = count + 1
        end
    end
    return count, #REGION_ORDER
end

function DynamicGroup:ResolveLeaderRegion(leaderName)
    if not leaderName or IsSecretValue(leaderName) or type(leaderName) ~= "string" or leaderName == "" then
        return "PENDING", ""
    end
    local ok, region, realm = pcall(function()
        local r = leaderName:match("^[^%-]+%-(.+)$") or leaderName:match("%-(.+)$")
        if not r or r == "" then
            r = GetRealmName and GetRealmName() or ""
        end
        if not r or r == "" then
            return "PENDING", ""
        end
        r = r:gsub("%s*%b()%s*$", ""):match("^%s*(.-)%s*$") or r
        local norm = NormalizeRealmKey(r)
        local reg = REALM_TO_REGION[r]
            or REALM_TO_REGION[r:lower()]
            or REALM_TO_REGION[norm]
        if not reg and r:find("%-") then
            for part in r:gmatch("[^%-]+") do
                reg = REALM_TO_REGION[part] or REALM_TO_REGION[part:lower()] or REALM_TO_REGION[NormalizeRealmKey(part)]
                if reg then break end
            end
        end
        return reg or "USE", r
    end)
    if ok and region then
        return region, realm or ""
    end
    return "PENDING", ""
end

-- ============================================================================
-- 3. ENGINE 1: TWO-WAY GUILD & FRIEND AUTO-INVITE, ROLE CHECK & KEYSTONE
-- ============================================================================

local function IsPlayerInActiveQueue()
    if type(GetLFGMode) == "function" then
        local categories = {
            _G.LE_LFG_CATEGORY_LFD or 1,
            _G.LE_LFG_CATEGORY_RF or 3,
            _G.LE_LFG_CATEGORY_SCENARIO or 4,
            _G.LE_LFG_CATEGORY_LFR or 2,
        }
        for _, cat in ipairs(categories) do
            local ok, mode = pcall(GetLFGMode, cat)
            if ok and mode and mode ~= "abandonedInDungeon" then
                return true, "LFG Queue"
            end
        end
    end

    if C_LFGList and type(C_LFGList.GetApplications) == "function" then
        local ok, apps = pcall(C_LFGList.GetApplications)
        if ok and type(apps) == "table" then
            for _, resultID in ipairs(apps) do
                if type(C_LFGList.GetApplicationInfo) == "function" then
                    local okApp, _, appStatus = pcall(C_LFGList.GetApplicationInfo, resultID)
                    if okApp and not IsSecretValue(appStatus) and (appStatus == "applied" or appStatus == "invited") then
                        return true, "Premade LFG Application"
                    end
                end
            end
        end
    end

    if type(GetMaxBattlefieldID) == "function" and type(GetBattlefieldStatus) == "function" then
        local maxBG = GetMaxBattlefieldID() or 0
        for i = 1, maxBG do
            local status = GetBattlefieldStatus(i)
            if status == "queued" or status == "confirm" then
                return true, "PvP Queue"
            end
        end
    end

    return false, nil
end

local function NormalizeQualifiedName(name)
    if not name or IsSecretValue(name) or type(name) ~= "string" then return "" end
    local ok, res = pcall(function()
        local cleaned = name:gsub("%s+", "")
        if not cleaned:find("%-") then
            local myRealm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName() and GetRealmName():gsub("%s+", "")) or ""
            if myRealm ~= "" then
                cleaned = cleaned .. "-" .. myRealm
            end
        end
        return cleaned:lower()
    end)
    return (ok and res) or ""
end

local _trustedGuildCache = {}
local _trustedFriendCache = {}
local _lastTrustedCacheTime = 0

local function RebuildTrustedContactCaches()
    local now = (GetTime and GetTime()) or 0
    if (now - _lastTrustedCacheTime) < 3.0 then return end
    _lastTrustedCacheTime = now
    wipe(_trustedGuildCache)
    wipe(_trustedFriendCache)

    if C_FriendList and type(C_FriendList.GetNumFriends) == "function" then
        local numFriends = C_FriendList.GetNumFriends() or 0
        for i = 1, numFriends do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.name and not IsSecretValue(info.name) then
                local q = NormalizeQualifiedName(info.name)
                if q ~= "" then _trustedFriendCache[q] = true end
            end
        end
    end

    if type(BNGetNumFriends) == "function" and C_BattleNet and type(C_BattleNet.GetFriendAccountInfo) == "function" then
        local numBNet = BNGetNumFriends() or 0
        local reqClient = BNET_CLIENT_WOW or "WoW"
        local reqProj = WOW_PROJECT_MAINLINE or 1
        for i = 1, numBNet do
            local acct = C_BattleNet.GetFriendAccountInfo(i)
            local gameInfo = acct and acct.gameAccountInfo
            if gameInfo and gameInfo.characterName and not IsSecretValue(gameInfo.characterName) then
                if (not gameInfo.clientProgram or gameInfo.clientProgram == reqClient) and (not gameInfo.wowProjectID or gameInfo.wowProjectID == reqProj) then
                    local full = gameInfo.characterName
                    if gameInfo.realmName and not IsSecretValue(gameInfo.realmName) and gameInfo.realmName ~= "" then
                        full = full .. "-" .. gameInfo.realmName:gsub("%s+", "")
                    end
                    local q = NormalizeQualifiedName(full)
                    if q ~= "" then _trustedFriendCache[q] = true end
                end
            end
        end
    end

    if IsInGuild and IsInGuild() and type(GetNumGuildMembers) == "function" and type(GetGuildRosterInfo) == "function" then
        local numGuild = GetNumGuildMembers() or 0
        for i = 1, numGuild do
            local name = GetGuildRosterInfo(i)
            if name and not IsSecretValue(name) then
                local q = NormalizeQualifiedName(name)
                if q ~= "" then _trustedGuildCache[q] = true end
            end
        end
    end
end

local function IsSenderFriendOrBNet(senderName, senderGUID)
    if IsSecretValue(senderName) then senderName = nil end
    if IsSecretValue(senderGUID) then senderGUID = nil end
    if senderGUID and senderGUID ~= "" then
        if C_BattleNet and type(C_BattleNet.GetAccountInfoByGUID) == "function" then
            local ok, acct = pcall(C_BattleNet.GetAccountInfoByGUID, senderGUID)
            if ok and acct then return true, "Battle.net" end
        end
        if C_FriendList and type(C_FriendList.IsFriend) == "function" then
            local ok, isFr = pcall(C_FriendList.IsFriend, senderGUID)
            if ok and isFr then return true, "Friend" end
        end
    end

    local qualSender = NormalizeQualifiedName(senderName)
    if qualSender == "" then return false, nil end
    RebuildTrustedContactCaches()
    if _trustedFriendCache[qualSender] then
        return true, "Friend"
    end
    return false, nil
end

local function IsSenderGuildMember(senderName, senderGUID)
    if not IsInGuild or not IsInGuild() then return false end
    if IsSecretValue(senderName) then senderName = nil end
    if IsSecretValue(senderGUID) then senderGUID = nil end
    if senderGUID and senderGUID ~= "" and type(IsGuildMember) == "function" then
        local ok, isGM = pcall(IsGuildMember, senderGUID)
        if ok and isGM then return true end
    end
    if senderName and type(UnitIsInMyGuild) == "function" then
        local ok, inGuild = pcall(UnitIsInMyGuild, senderName)
        if ok and inGuild then return true end
    end
    local qualSender = NormalizeQualifiedName(senderName)
    if qualSender ~= "" then
        RebuildTrustedContactCaches()
        if _trustedGuildCache[qualSender] then
            return true
        end
    end
    return false
end

local function ShouldAllowContact(mode, senderName, senderGUID, forceBNet)
    if mode == "OFF" then return false, nil end
    if mode == "ANYONE" then return true, "Open Keyword" end

    if forceBNet and (mode == "FRIENDS_AND_GUILD" or mode == "FRIENDS_ONLY" or mode == "GUILD_AND_FRIENDS") then
        return true, "Battle.net"
    end

    if mode == "FRIENDS_AND_GUILD" or mode == "FRIENDS_ONLY" or mode == "GUILD_AND_FRIENDS" then
        local isFr, label = IsSenderFriendOrBNet(senderName, senderGUID)
        if isFr then return true, label or "Friend" end
    end

    if mode == "FRIENDS_AND_GUILD" or mode == "GUILD_ONLY" or mode == "GUILD_AND_FRIENDS" then
        if IsSenderGuildMember(senderName, senderGUID) then
            return true, "Guild"
        end
    end

    return false, nil
end

local function HandlePartyInviteRequest(senderName, isTank, isHealer, isDamage, isNativeRealm, allowMultipleRoles, inviterGUID)
    if IsSecretValue(senderName) then senderName = nil end
    if IsSecretValue(inviterGUID) then inviterGUID = nil end
    local db = EnsureDB()
    local mode = db.incomingInviteMode or "FRIENDS_AND_GUILD"
    if mode == "OFF" then return end
    if IsInGroup() then return end

    if db.protectActiveQueues then
        local inQueue, queueType = IsPlayerInActiveQueue()
        if inQueue then
            if db.announceInvites then
                PrintMsg("Queue Shield protected your active " .. tostring(queueType) .. " (held invite from " .. tostring(senderName or "Unknown") .. ").")
            end
            return
        end
    end

    local allowed, sourceLabel = ShouldAllowContact(mode, senderName, inviterGUID, false)
    if not allowed then return end

    if type(AcceptGroup) == "function" then
        AcceptGroup()
        C_Timer.After(0.05, function()
            if type(StaticPopup_Hide) == "function" then
                StaticPopup_Hide("PARTY_INVITE")
                StaticPopup_Hide("PARTY_INVITE_XREALM")
            end
            if _G.LFGInvitePopup and _G.LFGInvitePopup.Hide then
                _G.LFGInvitePopup:Hide()
            end
        end)
        if db.announceInvites then
            PrintMsg("Auto-accepted group invite from " .. tostring(senderName or "Friend") .. " (" .. tostring(sourceLabel or "Trusted") .. ").")
        end
    end
end

local function MatchesWhisperKeyword(text, keywordCsv)
    if not text or IsSecretValue(text) or type(text) ~= "string" then return false end
    local ok, cleanMsg = pcall(function()
        return text:lower():match("^%s*(.-)%s*$")
    end)
    if not ok or not cleanMsg or cleanMsg == "" then return false end

    local rawKeywords = (keywordCsv and not IsSecretValue(keywordCsv) and keywordCsv ~= "") and keywordCsv or "inv, invite, 123"
    for token in rawKeywords:gmatch("[^,]+") do
        local kw = token:lower():match("^%s*(.-)%s*$")
        if kw and kw ~= "" and cleanMsg == kw then
            return true
        end
    end
    return false
end

local _pendingRaidConversionInvites = {}

local function FlushPendingRaidConversionInvites()
    if #_pendingRaidConversionInvites == 0 then return end
    if not IsInRaid or not IsInRaid() then return end
    local db = EnsureDB()
    for i = 1, #_pendingRaidConversionInvites do
        local req = _pendingRaidConversionInvites[i]
        if req.bnetGameAccountID and type(BNInviteFriend) == "function" then
            BNInviteFriend(req.bnetGameAccountID)
            if db.announceInvites then
                PrintMsg("Auto-invited Battle.net friend " .. tostring(req.display or "BNet") .. " after Raid conversion.")
            end
        elseif req.target and C_PartyInfo and type(C_PartyInfo.InviteUnit) == "function" then
            C_PartyInfo.InviteUnit(req.target)
            if db.announceInvites then
                PrintMsg("Auto-invited " .. tostring(req.target) .. " after Raid conversion (" .. tostring(req.sourceLabel or "Whisper") .. ").")
            end
        end
    end
    wipe(_pendingRaidConversionInvites)
end

local function PrepareGroupForOutgoingInvite(pendingReq)
    local db = EnsureDB()
    if IsInGroup() and not UnitIsGroupLeader("player") and not UnitIsGroupAssistant("player") then
        return false, false
    end
    if db.autoConvertToRaid and IsInGroup() and not IsInRaid() then
        local count = GetNumGroupMembers and GetNumGroupMembers() or 0
        if count >= 5 and UnitIsGroupLeader("player") then
            if pendingReq then
                _pendingRaidConversionInvites[#_pendingRaidConversionInvites + 1] = pendingReq
            end
            if C_PartyInfo and type(C_PartyInfo.ConvertToRaid) == "function" then
                C_PartyInfo.ConvertToRaid()
                if db.announceInvites then
                    PrintMsg("Auto-converted party to Raid; queued 6th+ member invite until conversion completes.")
                end
            end
            return true, true
        end
    end
    return true, false
end

local function HandleWhisperAutoInvite(text, senderName, senderGUID)
    if IsSecretValue(text) or IsSecretValue(senderName) then return end
    if IsSecretValue(senderGUID) then senderGUID = nil end
    local db = EnsureDB()
    if not db.enableWhisperInvite then return end
    local scope = (db.whisperInviteScope == "ANYONE") and "ANYONE" or "FRIENDS_AND_GUILD"
    if not MatchesWhisperKeyword(text, db.whisperKeywords) then return end

    local allowed, sourceLabel = ShouldAllowContact(scope, senderName, senderGUID, false)
    if not allowed then return end
    local canInvite, queuedForRaid = PrepareGroupForOutgoingInvite({ target = senderName, sourceLabel = sourceLabel })
    if not canInvite or queuedForRaid then return end

    if C_PartyInfo and type(C_PartyInfo.InviteUnit) == "function" then
        C_PartyInfo.InviteUnit(senderName)
        if db.announceInvites then
            PrintMsg("Auto-invited " .. tostring(senderName) .. " via keyword (" .. tostring(sourceLabel or "Whisper") .. ").")
        end
    end
end

local function HandleBNetWhisperAutoInvite(text, senderDisplayName, bnetIDAccount)
    if IsSecretValue(text) or IsSecretValue(senderDisplayName) or IsSecretValue(bnetIDAccount) then return end
    local db = EnsureDB()
    if not db.enableWhisperInvite then return end
    if not MatchesWhisperKeyword(text, db.whisperKeywords) then return end

    if C_BattleNet and type(C_BattleNet.GetAccountInfoByID) == "function" and bnetIDAccount then
        local ok, acct = pcall(C_BattleNet.GetAccountInfoByID, bnetIDAccount)
        if ok and acct and acct.gameAccountInfo then
            local gameInfo = acct.gameAccountInfo
            local reqClient = BNET_CLIENT_WOW or "WoW"
            local reqProj = WOW_PROJECT_MAINLINE or 1
            if (gameInfo.clientProgram and gameInfo.clientProgram ~= reqClient) or (gameInfo.wowProjectID and gameInfo.wowProjectID ~= reqProj) then
                return
            end
            if gameInfo.gameAccountID and not IsSecretValue(gameInfo.gameAccountID) and type(BNInviteFriend) == "function" then
                local disp = (not IsSecretValue(gameInfo.characterName) and gameInfo.characterName) or senderDisplayName or "BNet"
                local canInvite, queuedForRaid = PrepareGroupForOutgoingInvite({ bnetGameAccountID = gameInfo.gameAccountID, display = disp })
                if not canInvite or queuedForRaid then return end
                BNInviteFriend(gameInfo.gameAccountID)
                if db.announceInvites then
                    PrintMsg("Auto-invited Battle.net friend " .. tostring(disp) .. " via keyword.")
                end
                return
            elseif gameInfo.characterName and not IsSecretValue(gameInfo.characterName) and gameInfo.characterName ~= "" then
                local target = gameInfo.characterName
                if gameInfo.realmName and not IsSecretValue(gameInfo.realmName) and gameInfo.realmName ~= "" then
                    target = target .. "-" .. gameInfo.realmName:gsub("%s+", "")
                end
                local canInvite, queuedForRaid = PrepareGroupForOutgoingInvite({ target = target, sourceLabel = "Battle.net" })
                if not canInvite or queuedForRaid then return end
                if C_PartyInfo and type(C_PartyInfo.InviteUnit) == "function" then
                    C_PartyInfo.InviteUnit(target)
                    if db.announceInvites then
                        PrintMsg("Auto-invited Battle.net friend " .. tostring(target) .. " via keyword.")
                    end
                end
            end
        end
    end
end

local _autoPromotePending = false

local function HandleAutoPromoteRosterImmediate()
    local db = EnsureDB()
    if not db.autoPromoteFriendsTanks then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if not IsInRaid or not IsInRaid() or not UnitIsGroupLeader("player") then return end

    RebuildTrustedContactCaches()
    local num = GetNumGroupMembers and GetNumGroupMembers() or 0
    for i = 1, num do
        local unit = "raid" .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") and not UnitIsGroupAssistant(unit) and not UnitIsGroupLeader(unit) then
            local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
            local guid = UnitGUID and UnitGUID(unit) or nil
            local name = GetUnitName and GetUnitName(unit, true) or nil
            local isTrusted = (role == "TANK") or IsSenderFriendOrBNet(name, guid) or IsSenderGuildMember(name, guid)
            if isTrusted and type(PromoteToAssistant) == "function" then
                pcall(PromoteToAssistant, unit)
            end
        end
    end
end

local function HandleAutoPromoteRoster()
    FlushPendingRaidConversionInvites()
    if _autoPromotePending then return end
    _autoPromotePending = true
    C_Timer.After(0.5, function()
        _autoPromotePending = false
        HandleAutoPromoteRosterImmediate()
    end)
end

local _keystoneSlotLock = false

local function TryAutoInsertKeystone()
    if _keystoneSlotLock then return end
    local db = EnsureDB()
    if not db.autoInsertKeystone then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if not C_ChallengeMode or type(C_ChallengeMode.HasSlottedKeystone) ~= "function" then return end
    if C_ChallengeMode.HasSlottedKeystone() then return end
    if not C_Container or type(C_Container.GetContainerNumSlots) ~= "function" then return end

    _keystoneSlotLock = true
    C_Timer.After(0.25, function() _keystoneSlotLock = false end)

    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                local isKey = false
                if C_Item and type(C_Item.IsItemKeystoneByID) == "function" then
                    local ok, res = pcall(C_Item.IsItemKeystoneByID, itemID)
                    if ok and res then isKey = true end
                end
                if not isKey then
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    if info and info.hyperlink and not IsSecretValue(info.hyperlink) and info.hyperlink:find("|Hkeystone:") then
                        isKey = true
                    end
                end
                if isKey then
                    C_Container.PickupContainerItem(bag, slot)
                    if CursorHasItem and CursorHasItem() and type(C_ChallengeMode.SlotKeystone) == "function" then
                        local okSlot = pcall(C_ChallengeMode.SlotKeystone)
                        if okSlot and C_ChallengeMode.HasSlottedKeystone() then
                            PrintMsg("Auto-slotted Mythic+ Keystone.")
                        elseif ClearCursor then
                            ClearCursor()
                        end
                        return
                    elseif ClearCursor then
                        ClearCursor()
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- 4. ENGINE 2: PREMADE LFG REGION TAGGING, COMPOSITION PILLS & FILTER ENGINE
-- ============================================================================

local LUST_CLASSES = {
    MAGE = true,
    SHAMAN = true,
    EVOKER = true,
    HUNTER = true,
}

local CR_CLASSES = {
    DRUID = true,
    DEATHKNIGHT = true,
    WARLOCK = true,
    PALADIN = true,
}

local CLASS_COLORS_HEX = {
    DEATHKNIGHT = "FFC41E3A",
    DEMONHUNTER = "FFA330C9",
    DRUID       = "FFFF7C0A",
    EVOKER      = "FF33937F",
    HUNTER      = "FFAAD372",
    MAGE        = "FF3FC7EB",
    MONK        = "FF00FF98",
    PALADIN     = "FFF48CBA",
    PRIEST      = "FFFFFFFF",
    ROGUE       = "FFFFF468",
    SHAMAN      = "FF0070DD",
    WARLOCK     = "FF8788EE",
    WARRIOR     = "FFC69B6D",
}

local ROLE_SHORT = {
    TANK = "T",
    HEALER = "H",
    DAMAGER = "D",
}

local function GetScoreColorHex(score)
    score = tonumber(score) or 0
    if C_ChallengeMode and type(C_ChallengeMode.GetDungeonScoreRarityColor) == "function" and score > 0 then
        local ok, col = pcall(C_ChallengeMode.GetDungeonScoreRarityColor, score)
        if ok and col and type(col.GenerateHexColor) == "function" then
            return col:GenerateHexColor()
        end
    end
    if score >= 3000 then return "FFFF8000"
    elseif score >= 2500 then return "FFA335EE"
    elseif score >= 2000 then return "FF0070DD"
    elseif score >= 1500 then return "FF1EFF00"
    else return "FF94A3B8" end
end

local function IsValidSearchResultID(resultID)
    if type(resultID) ~= "number" or IsSecretValue(resultID) then
        return false
    end
    if not C_LFGList or type(C_LFGList.GetSearchResultInfo) ~= "function" then
        return false
    end
    if type(C_LFGList.HasSearchResultInfo) == "function" then
        local okH, hasInfo = pcall(C_LFGList.HasSearchResultInfo, resultID)
        if okH and not hasInfo then
            return false
        end
    end
    local ok, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
    if not ok or type(info) ~= "table" then
        return false
    end
    return true
end

local MIDNIGHT_S1_FALLBACK_SLOTS = {
    { code = "DON", name = "Den of Nalorakk",              mapID = 540, spellID = 1216786, icon = 136095,  patterns = { "nalorakk" },                             spellCandidates = { 1216786 } },
    { code = "AOF", name = "Altar of Fangs",               mapID = 402, spellID = 393273,  icon = 4511692, patterns = { "altar", "fangs", "algeth", "arena of", "forge" }, spellCandidates = { 393273 } },
    { code = "BV",  name = "The Azure Vault",              mapID = 401, spellID = 393279,  icon = 4511694, patterns = { "azure vault", "bracken", "vault" },        spellCandidates = { 393279, 393267 } },
    { code = "MR",  name = "Magisters' / Murder Row",      mapID = 541, spellID = 1216788, icon = 135764,  patterns = { "murder", "magister", "row" },            spellCandidates = { 1216788 } },
    { code = "RLP", name = "Ruby Life Pools",              mapID = 399, spellID = 393256,  icon = 4511698, patterns = { "ruby life" },                            spellCandidates = { 393256 } },
    { code = "VSA", name = "Venomous Abyss",               mapID = 542, spellID = 1216790, icon = 136051,  patterns = { "venomous", "abyss", "sacred", "ancient", "seat" }, spellCandidates = { 1216790, 1237215 } },
    { code = "TOS", name = "Temple of Sethraliss",         mapID = 250, spellID = 424167,  icon = 2065604, patterns = { "sethraliss", "jade", "temple", "tides" }, spellCandidates = { 424167, 131204, 424142 } },
    { code = "KR",  name = "Kings' Rest",                  mapID = 249, spellID = 467553,  icon = 2065599, patterns = { "kings", "karazhan" },                    spellCandidates = { 467553, 445269, 373262 } },
}

local KNOWN_DUNGEON_BY_MAP_ID = {
    [2]   = { code = "TOS", name = "Temple of the Jade Serpent", spellID = 131204,  spellCandidates = { 131204 } },
    [165] = { code = "SBG", name = "Shadowmoon Burial Grounds",  spellID = 159899,  spellCandidates = { 159899 } },
    [166] = { code = "GD",  name = "Grimrail Depot",             spellID = 159900,  spellCandidates = { 159900 } },
    [168] = { code = "EB",  name = "The Everbloom",              spellID = 159901,  spellCandidates = { 159901 } },
    [169] = { code = "ID",  name = "Iron Docks",                 spellID = 159896,  spellCandidates = { 159896 } },
    [198] = { code = "DHT", name = "Darkheart Thicket",          spellID = 424163,  spellCandidates = { 424163 } },
    [199] = { code = "BRH", name = "Black Rook Hold",            spellID = 424153,  spellCandidates = { 424153 } },
    [200] = { code = "HOV", name = "Halls of Valor",             spellID = 393764,  spellCandidates = { 393764 } },
    [206] = { code = "NL",  name = "Neltharion's Lair",          spellID = 410078,  spellCandidates = { 410078 } },
    [210] = { code = "COS", name = "Court of Stars",             spellID = 393766,  spellCandidates = { 393766 } },
    [227] = { code = "LOWR",name = "Return to Karazhan: Lower",  spellID = 373262,  spellCandidates = { 373262 } },
    [234] = { code = "UPPR",name = "Return to Karazhan: Upper",  spellID = 373262,  spellCandidates = { 373262 } },
    [244] = { code = "AD",  name = "Atal'Dazar",                 spellID = 424187,  spellCandidates = { 424187 } },
    [245] = { code = "FH",  name = "Freehold",                   spellID = 410071,  spellCandidates = { 410071 } },
    [247] = { code = "ML",  name = "The MOTHERLODE!!",           spellID = 467553,  spellCandidates = { 467553, 467555 } },
    [248] = { code = "WCM", name = "Waycrest Manor",             spellID = 424167,  spellCandidates = { 424167 } },
    [249] = { code = "KR",  name = "Kings' Rest",                spellID = 467553,  spellCandidates = { 467553, 445269 } },
    [250] = { code = "TOS", name = "Temple of Sethraliss",       spellID = 424167,  spellCandidates = { 424167 } },
    [251] = { code = "UNDR",name = "The Underrot",               spellID = 410074,  spellCandidates = { 410074 } },
    [253] = { code = "SOB", name = "Siege of Boralus",           spellID = 445418,  spellCandidates = { 445418, 464256 } },
    [353] = { code = "SOB", name = "Siege of Boralus",           spellID = 445418,  spellCandidates = { 445418, 464256 } },
    [369] = { code = "YARD",name = "Mechagon: Junkyard",         spellID = 373274,  spellCandidates = { 373274 } },
    [370] = { code = "WORK",name = "Mechagon: Workshop",         spellID = 373274,  spellCandidates = { 373274 } },
    [375] = { code = "MISTS",name = "Mists of Tirna Scithe",     spellID = 354464,  spellCandidates = { 354464 } },
    [376] = { code = "NW",  name = "The Necrotic Wake",          spellID = 354462,  spellCandidates = { 354462 } },
    [378] = { code = "HOA", name = "Halls of Atonement",         spellID = 354465,  spellCandidates = { 354465 } },
    [382] = { code = "TOP", name = "Theater of Pain",            spellID = 354467,  spellCandidates = { 354467 } },
    [391] = { code = "STRT",name = "Tazavesh: Streets",          spellID = 367416,  spellCandidates = { 367416 } },
    [392] = { code = "GMBT",name = "Tazavesh: Gambit",           spellID = 367416,  spellCandidates = { 367416 } },
    [399] = { code = "RLP", name = "Ruby Life Pools",            spellID = 393256,  spellCandidates = { 393256 } },
    [400] = { code = "NO",  name = "The Nokhud Offensive",       spellID = 393262,  spellCandidates = { 393262 } },
    [401] = { code = "BV",  name = "The Azure Vault",            spellID = 393279,  spellCandidates = { 393279 } },
    [402] = { code = "AOF", name = "Altar of Fangs",             spellID = 393273,  spellCandidates = { 393273 } },
    [403] = { code = "ULD", name = "Uldaman: Legacy of Tyr",     spellID = 393222,  spellCandidates = { 393222 } },
    [404] = { code = "NELT",name = "Neltharus",                  spellID = 393276,  spellCandidates = { 393276 } },
    [405] = { code = "BH",  name = "Brackenhide Hollow",         spellID = 393267,  spellCandidates = { 393267 } },
    [406] = { code = "HOI", name = "Halls of Infusion",          spellID = 393283,  spellCandidates = { 393283 } },
    [438] = { code = "VP",  name = "The Vortex Pinnacle",        spellID = 410080,  spellCandidates = { 410080 } },
    [456] = { code = "TOS", name = "Throne of the Tides",        spellID = 424142,  spellCandidates = { 424142 } },
    [463] = { code = "FALL",name = "Dawn of the Infinite: Fall", spellID = 424197,  spellCandidates = { 424197 } },
    [464] = { code = "RISE",name = "Dawn of the Infinite: Rise", spellID = 424197,  spellCandidates = { 424197 } },
    [499] = { code = "PSF", name = "Priory of the Sacred Flame", spellID = 445444,  spellCandidates = { 445444 } },
    [500] = { code = "ROOK",name = "The Rookery",                spellID = 445443,  spellCandidates = { 445443 } },
    [501] = { code = "SV",  name = "The Stonevault",             spellID = 445416,  spellCandidates = { 445416 } },
    [502] = { code = "COT", name = "City of Threads",            spellID = 445417,  spellCandidates = { 445417 } },
    [503] = { code = "AK",  name = "Ara-Kara, City of Echoes",   spellID = 445417,  spellCandidates = { 445417 } },
    [504] = { code = "DFC", name = "Darkflame Cleft",            spellID = 445441,  spellCandidates = { 445441 } },
    [505] = { code = "DB",  name = "The Dawnbreaker",            spellID = 445414,  spellCandidates = { 445414 } },
    [506] = { code = "BREW",name = "Cinderbrew Meadery",         spellID = 445440,  spellCandidates = { 445440 } },
    [507] = { code = "GB",  name = "Grim Batol",                 spellID = 445424,  spellCandidates = { 445424 } },
    [525] = { code = "FG",  name = "Operation: Floodgate",       spellID = 1216786, spellCandidates = { 1216786 } },
    [540] = { code = "DON", name = "Den of Nalorakk",            spellID = 1216786, spellCandidates = { 1216786 } },
    [541] = { code = "MR",  name = "Magisters' / Murder Row",    spellID = 1216788, spellCandidates = { 1216788 } },
    [542] = { code = "VSA", name = "Venomous Abyss",             spellID = 1216790, spellCandidates = { 1216790, 1237215 } },
}

local activityInfoCache = {}
local seasonGroupToSlot = {}
local seasonSlotsCache = nil
local requestedMythicMapInfo = false

local function NormalizeDungeonMatchName(raw)
    if type(raw) ~= "string" then return "" end
    local clean = raw:gsub("%b()", " "):lower()
    clean = clean:gsub("[:,'\"%-]", " ")
    clean = clean:gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
    return clean
end

local function BuildDungeonShortCode(dungeonName, mapID)
    local known = mapID and KNOWN_DUNGEON_BY_MAP_ID[mapID] or nil
    if known and known.code then
        return known.code
    end
    local norm = NormalizeDungeonMatchName(dungeonName)
    if norm ~= "" then
        for _, fb in ipairs(MIDNIGHT_S1_FALLBACK_SLOTS) do
            if fb.patterns then
                for _, pat in ipairs(fb.patterns) do
                    if norm:find(pat, 1, true) then
                        return fb.code
                    end
                end
            end
        end
        local stopWords = { the = true, of = true, ["and"] = true, ["in"] = true, at = true, to = true, a = true }
        local letters = {}
        for word in norm:gmatch("%a+") do
            if not stopWords[word] then
                letters[#letters + 1] = word:sub(1, 1):upper()
            end
        end
        if #letters >= 2 and #letters <= 4 then
            return table.concat(letters)
        elseif #letters > 4 then
            return table.concat(letters, "", 1, 4)
        elseif #norm >= 2 then
            return norm:gsub("%s+", ""):sub(1, 3):upper()
        end
    end
    return mapID and ("M" .. tostring(mapID)) or "M+"
end

local function IsTeleportSpellKnown(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then return false end
    if C_SpellBook and type(C_SpellBook.IsSpellInSpellBook) == "function" then
        local ok, known = pcall(C_SpellBook.IsSpellInSpellBook, spellID)
        if ok and known then return true end
    end
    if C_SpellBook and type(C_SpellBook.IsSpellKnown) == "function" then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok and known then return true end
    end
    if type(_G.IsSpellKnown) == "function" then
        local ok, known = pcall(_G.IsSpellKnown, spellID)
        if ok and known then return true end
    end
    if type(_G.IsPlayerSpell) == "function" then
        local ok, known = pcall(_G.IsPlayerSpell, spellID)
        if ok and known then return true end
    end
    return false
end

local function SafeGetSpellName(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then return nil end
    if C_Spell and type(C_Spell.GetSpellName) == "function" then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and type(name) == "string" and name ~= "" and not IsSecretValue(name) then
            return name
        end
    end
    if type(_G.GetSpellInfo) == "function" then
        local ok, name = pcall(_G.GetSpellInfo, spellID)
        if ok and type(name) == "string" and name ~= "" and not IsSecretValue(name) then
            return name
        end
    end
    return nil
end

local function SafeGetSpellCooldown(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then return 0, 0, false end
    if C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
        local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
        if ok and type(info) == "table" and not IsSecretValue(info.startTime) and not IsSecretValue(info.duration) then
            return tonumber(info.startTime) or 0, tonumber(info.duration) or 0, (info.isEnabled ~= false)
        end
    end
    if type(_G.GetSpellCooldown) == "function" then
        local ok, st, dur, enabled = pcall(_G.GetSpellCooldown, spellID)
        if ok and not IsSecretValue(st) and not IsSecretValue(dur) then
            return tonumber(st) or 0, tonumber(dur) or 0, (enabled ~= 0 and enabled ~= false)
        end
    end
    return 0, 0, false
end

local function SafeGetSpellDescription(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then return "" end
    if C_Spell and type(C_Spell.GetSpellDescription) == "function" then
        local ok, desc = pcall(C_Spell.GetSpellDescription, spellID)
        if ok and type(desc) == "string" and not IsSecretValue(desc) then
            return desc
        end
    end
    if type(_G.GetSpellDescription) == "function" then
        local ok, desc = pcall(_G.GetSpellDescription, spellID)
        if ok and type(desc) == "string" and not IsSecretValue(desc) then
            return desc
        end
    end
    return ""
end

local challengesMapToSpellCache = {}
local spellbookTeleportCache = nil

local function RefreshChallengesFrameTeleportCache()
    local cf = _G.ChallengesFrame
    if not cf or type(cf.DungeonIcons) ~= "table" then return end
    for _, icon in ipairs(cf.DungeonIcons) do
        local mID = icon and icon.mapID
        local sID = icon and icon.spellID
        if type(mID) == "number" and mID > 0 and type(sID) == "number" and sID > 0 and IsTeleportSpellKnown(sID) then
            challengesMapToSpellCache[mID] = sID
        end
    end
end

local function GetSpellbookTeleportEntries()
    if spellbookTeleportCache then
        return spellbookTeleportCache
    end
    local entries = {}
    local seenSpells = {}

    local function RecordTeleportSpell(spellID, fallbackName)
        if type(spellID) ~= "number" or spellID <= 0 or seenSpells[spellID] then return end
        if not IsTeleportSpellKnown(spellID) then return end
        local sName = SafeGetSpellName(spellID) or fallbackName
        if type(sName) ~= "string" or sName == "" or IsSecretValue(sName) then return end
        local lowerName = sName:lower()
        local isTeleportName = (lowerName:find("^path of") ~= nil) or (lowerName:find("teleport", 1, true) ~= nil)
        if not isTeleportName then return end
        seenSpells[spellID] = true
        local desc = SafeGetSpellDescription(spellID)
        entries[#entries + 1] = {
            spellID = spellID,
            name = sName,
            normName = NormalizeDungeonMatchName(sName),
            haystack = NormalizeDungeonMatchName(sName .. " " .. desc),
        }
    end

    local playerBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if C_SpellBook and type(C_SpellBook.GetNumSpellBookSkillLines) == "function"
        and type(C_SpellBook.GetSpellBookItemInfo) == "function"
        and type(C_SpellBook.GetSpellBookSkillLineInfo) == "function"
        and playerBank
    then
        local okLines, numLines = pcall(C_SpellBook.GetNumSpellBookSkillLines)
        if okLines and type(numLines) == "number" then
            for line = 1, numLines do
                local okL, lineInfo = pcall(C_SpellBook.GetSpellBookSkillLineInfo, line)
                if okL and type(lineInfo) == "table" and not lineInfo.offSpecID then
                    local offset = tonumber(lineInfo.itemIndexOffset) or 0
                    local count = tonumber(lineInfo.numSpellBookItems) or 0
                    for slotIdx = offset + 1, offset + count do
                        local okI, itemInfo = pcall(C_SpellBook.GetSpellBookItemInfo, slotIdx, playerBank)
                        if okI and type(itemInfo) == "table" and not itemInfo.isOffSpec then
                            if Enum.SpellBookItemType and itemInfo.itemType == Enum.SpellBookItemType.Flyout and itemInfo.actionID then
                                if type(_G.GetFlyoutInfo) == "function" and type(_G.GetFlyoutSlotInfo) == "function" then
                                    local okF, _, _, numSlots = pcall(_G.GetFlyoutInfo, itemInfo.actionID)
                                    if okF and type(numSlots) == "number" then
                                        for fSlot = 1, numSlots do
                                            local okFS, fSpellID, _, fKnown = pcall(_G.GetFlyoutSlotInfo, itemInfo.actionID, fSlot)
                                            if okFS and fKnown and type(fSpellID) == "number" then
                                                RecordTeleportSpell(fSpellID)
                                            end
                                        end
                                    end
                                end
                            elseif itemInfo.spellID then
                                RecordTeleportSpell(itemInfo.spellID, itemInfo.name)
                            end
                        end
                    end
                end
            end
        end
    end

    spellbookTeleportCache = entries
    return entries
end

local STOP_WORDS_DUNGEON = {
    the = true, of = true, ["and"] = true, ["for"] = true, ["in"] = true, at = true, to = true,
    path = true, teleport = true, dungeon = true,
}

local function ResolveTeleportSpellForDungeon(mapID, code, dungeonName, fallbackSpellID)
    RefreshChallengesFrameTeleportCache()
    if mapID and challengesMapToSpellCache[mapID] and IsTeleportSpellKnown(challengesMapToSpellCache[mapID]) then
        return challengesMapToSpellCache[mapID], true
    end

    local candidates = {}
    local seen = {}
    local matchKeywords = {}
    local seenKw = {}
    local function AddCand(id)
        if type(id) == "number" and id > 0 and not seen[id] then
            seen[id] = true
            candidates[#candidates + 1] = id
        end
    end
    local function AddKeyword(kw)
        if type(kw) == "string" then
            local nkw = NormalizeDungeonMatchName(kw)
            if #nkw >= 3 and not STOP_WORDS_DUNGEON[nkw] and not seenKw[nkw] then
                seenKw[nkw] = true
                matchKeywords[#matchKeywords + 1] = nkw
            end
        end
    end

    AddCand(fallbackSpellID)
    local known = mapID and KNOWN_DUNGEON_BY_MAP_ID[mapID] or nil
    if known then
        AddCand(known.spellID)
        if known.spellCandidates then
            for _, cid in ipairs(known.spellCandidates) do AddCand(cid) end
        end
        if known.patterns then
            for _, pat in ipairs(known.patterns) do AddKeyword(pat) end
        end
    end
    local norm = NormalizeDungeonMatchName(dungeonName)
    if norm ~= "" then
        for word in norm:gmatch("%S+") do
            AddKeyword(word)
        end
    end
    for _, fb in ipairs(MIDNIGHT_S1_FALLBACK_SLOTS) do
        local matchFB = (code and fb.code == code)
        if not matchFB and norm ~= "" and fb.patterns then
            for _, pat in ipairs(fb.patterns) do
                if norm:find(pat, 1, true) then matchFB = true; break end
            end
        end
        if matchFB then
            AddCand(fb.spellID)
            if fb.spellCandidates then
                for _, cid in ipairs(fb.spellCandidates) do AddCand(cid) end
            end
            if fb.patterns then
                for _, pat in ipairs(fb.patterns) do AddKeyword(pat) end
            end
        end
    end
    for _, cid in ipairs(candidates) do
        if IsTeleportSpellKnown(cid) then
            return cid, true
        end
    end

    -- Source B: Live Spellbook scan for learned "Path of ..." / dungeon teleports
    if #matchKeywords > 0 then
        local sbEntries = GetSpellbookTeleportEntries()
        local bestSpellID = nil
        local bestScore = 0
        for _, sb in ipairs(sbEntries) do
            local score = 0
            for _, kw in ipairs(matchKeywords) do
                if sb.haystack:find(kw, 1, true) then
                    score = score + ((#kw >= 5) and 2 or 1)
                end
            end
            if score > bestScore then
                bestScore = score
                bestSpellID = sb.spellID
            end
        end
        if bestSpellID and bestScore >= 2 then
            if mapID then
                challengesMapToSpellCache[mapID] = bestSpellID
            end
            return bestSpellID, true
        elseif bestSpellID and bestScore == 1 then
            if mapID then
                challengesMapToSpellCache[mapID] = bestSpellID
            end
            return bestSpellID, true
        end
    end

    local primary = candidates[1] or 0
    return primary, IsTeleportSpellKnown(primary)
end

local function PopulateSeasonActivityGroups(slots)
    if not C_LFGList or type(C_LFGList.GetAvailableActivityGroups) ~= "function" or type(C_LFGList.GetActivityGroupInfo) ~= "function" then
        return
    end
    local okG, groupIDs = pcall(C_LFGList.GetAvailableActivityGroups, 2)
    if not okG or type(groupIDs) ~= "table" then return end

    for _, gid in ipairs(groupIDs) do
        local okN, gName = pcall(C_LFGList.GetActivityGroupInfo, gid)
        if okN and type(gName) == "string" and gName ~= "" and not IsSecretValue(gName) then
            local normG = NormalizeDungeonMatchName(gName)
            for _, slot in ipairs(slots) do
                local normS = NormalizeDungeonMatchName(slot.name)
                if normS ~= "" and (normG == normS or normG:find(normS, 1, true) or normS:find(normG, 1, true)) then
                    slot.activityGroupID = gid
                    seasonGroupToSlot[gid] = slot
                    break
                elseif slot.patterns then
                    local hit = false
                    for _, pat in ipairs(slot.patterns) do
                        if normG:find(pat, 1, true) then hit = true; break end
                    end
                    if hit then
                        slot.activityGroupID = gid
                        seasonGroupToSlot[gid] = slot
                        break
                    end
                end
            end
        end
    end
end

local function GetSeasonDungeonSlots(forceRefresh)
    if seasonSlotsCache and not forceRefresh then
        return seasonSlotsCache
    end
    if not requestedMythicMapInfo and C_MythicPlus and type(C_MythicPlus.RequestMapInfo) == "function" then
        requestedMythicMapInfo = true
        pcall(C_MythicPlus.RequestMapInfo)
    end

    local mapTable = nil
    if C_MythicPlus and type(C_MythicPlus.GetMapTable) == "function" then
        local okM, tbl = pcall(C_MythicPlus.GetMapTable)
        if okM and type(tbl) == "table" and #tbl > 0 then
            mapTable = tbl
        end
    end
    if (not mapTable or #mapTable == 0) and C_ChallengeMode and type(C_ChallengeMode.GetMapTable) == "function" then
        local okC, tbl = pcall(C_ChallengeMode.GetMapTable)
        if okC and type(tbl) == "table" and #tbl > 0 then
            mapTable = tbl
        end
    end

    local slots = {}
    if mapTable and #mapTable > 0 then
        for i = 1, math.min(8, #mapTable) do
            local mapID = tonumber(mapTable[i])
            if mapID then
                local fallbackMeta = KNOWN_DUNGEON_BY_MAP_ID[mapID]
                local dName = fallbackMeta and fallbackMeta.name or ("Dungeon #" .. tostring(mapID))
                local texture = nil
                if C_ChallengeMode and type(C_ChallengeMode.GetMapUIInfo) == "function" then
                    local okU, uiName, _, _, uiTex = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
                    if okU and type(uiName) == "string" and uiName ~= "" and not IsSecretValue(uiName) then
                        dName = uiName
                    end
                    if okU and uiTex and not IsSecretValue(uiTex) then
                        texture = uiTex
                    end
                end
                local code = BuildDungeonShortCode(dName, mapID)
                local patterns = fallbackMeta and fallbackMeta.patterns or nil
                if not patterns then
                    for _, fb in ipairs(MIDNIGHT_S1_FALLBACK_SLOTS) do
                        if fb.code == code then
                            patterns = fb.patterns
                            if not texture then texture = fb.icon end
                            break
                        end
                    end
                end
                local spellID, spellKnown = ResolveTeleportSpellForDungeon(mapID, code, dName, fallbackMeta and fallbackMeta.spellID)
                slots[#slots + 1] = {
                    mapID = mapID,
                    code = code,
                    name = dName,
                    icon = texture or 136095,
                    spellID = spellID,
                    spellKnown = spellKnown,
                    patterns = patterns,
                }
            end
        end
    end

    if #slots == 0 then
        for _, fb in ipairs(MIDNIGHT_S1_FALLBACK_SLOTS) do
            local spellID, spellKnown = ResolveTeleportSpellForDungeon(fb.mapID, fb.code, fb.name, fb.spellID)
            local tex = fb.icon
            if C_ChallengeMode and type(C_ChallengeMode.GetMapUIInfo) == "function" then
                local okU, uiName, _, _, uiTex = pcall(C_ChallengeMode.GetMapUIInfo, fb.mapID)
                if okU and type(uiName) == "string" and uiName ~= "" and not IsSecretValue(uiName) then
                    fb.name = uiName
                end
                if okU and uiTex and not IsSecretValue(uiTex) then
                    tex = uiTex
                end
            end
            slots[#slots + 1] = {
                mapID = fb.mapID,
                code = fb.code,
                name = fb.name,
                icon = tex,
                spellID = spellID,
                spellKnown = spellKnown,
                patterns = fb.patterns,
            }
        end
    end

    PopulateSeasonActivityGroups(slots)
    seasonSlotsCache = slots
    return slots
end

local function MatchTextToDungeonSlot(text, slots)
    local norm = NormalizeDungeonMatchName(text)
    if norm == "" then return nil end
    for _, slot in ipairs(slots) do
        local normS = NormalizeDungeonMatchName(slot.name)
        if normS ~= "" and (norm == normS or norm:find(normS, 1, true) or normS:find(norm, 1, true)) then
            return slot
        end
        if slot.patterns then
            for _, pat in ipairs(slot.patterns) do
                if norm:find(pat, 1, true) then
                    return slot
                end
            end
        end
    end
    return nil
end

local function GetCachedActivityInfo(activityID)
    if type(activityID) ~= "number" or activityID <= 0 or IsSecretValue(activityID) then
        return nil
    end
    if activityInfoCache[activityID] then
        return activityInfoCache[activityID]
    end
    if not C_LFGList or type(C_LFGList.GetActivityInfoTable) ~= "function" then
        return nil
    end
    local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
    if not ok or type(info) ~= "table" then
        return nil
    end

    local categoryID = (not IsSecretValue(info.categoryID) and tonumber(info.categoryID)) or 0
    local groupID = (not IsSecretValue(info.groupFinderActivityGroupID) and tonumber(info.groupFinderActivityGroupID)) or nil
    local rawMapID = (not IsSecretValue(info.mapChallengeModeID) and tonumber(info.mapChallengeModeID)) or nil
    local fullName = (type(info.fullName) == "string" and not IsSecretValue(info.fullName)) and info.fullName or ""
    local shortName = (type(info.shortName) == "string" and not IsSecretValue(info.shortName)) and info.shortName or ""
    local isMPlus = (not IsSecretValue(info.isMythicPlusActivity) and info.isMythicPlusActivity == true) or false
    local isDungeon = (categoryID == 2) or isMPlus or (not IsSecretValue(info.isMythicActivity) and info.isMythicActivity == true and categoryID == 2)

    local slots = GetSeasonDungeonSlots(false)
    local matchedSlot = nil
    if groupID and seasonGroupToSlot[groupID] then
        matchedSlot = seasonGroupToSlot[groupID]
    end
    if not matchedSlot and rawMapID then
        for _, slot in ipairs(slots) do
            if slot.mapID == rawMapID then matchedSlot = slot; break end
        end
    end
    if not matchedSlot and fullName ~= "" then
        matchedSlot = MatchTextToDungeonSlot(fullName, slots)
    end
    if not matchedSlot and groupID and C_LFGList and type(C_LFGList.GetActivityGroupInfo) == "function" then
        local okG, gName = pcall(C_LFGList.GetActivityGroupInfo, groupID)
        if okG and type(gName) == "string" and not IsSecretValue(gName) then
            matchedSlot = MatchTextToDungeonSlot(gName, slots)
            if matchedSlot then
                seasonGroupToSlot[groupID] = matchedSlot
            end
        end
    end

    local resolvedMapID = (matchedSlot and matchedSlot.mapID) or rawMapID
    local resolvedCode = (matchedSlot and matchedSlot.code) or BuildDungeonShortCode(fullName ~= "" and fullName or shortName, resolvedMapID)

    local entry = {
        activityID = activityID,
        categoryID = categoryID,
        groupID = groupID,
        mapID = resolvedMapID,
        code = resolvedCode,
        fullName = fullName,
        shortName = shortName,
        isMythicPlusActivity = isMPlus,
        isDungeonActivity = isDungeon,
    }
    activityInfoCache[activityID] = entry
    return entry
end

local function GetPlayerBestForDungeon(mapID)
    if type(mapID) ~= "number" or mapID <= 0 then
        return 0, 0, false
    end
    local bestLevel = 0
    local bestScore = 0
    local isTimed = false

    if C_MythicPlus and type(C_MythicPlus.GetSeasonBestAffixScoreInfoForMap) == "function" then
        local okA, affixScores, overallScore = pcall(C_MythicPlus.GetSeasonBestAffixScoreInfoForMap, mapID)
        if okA then
            if type(overallScore) == "number" and not IsSecretValue(overallScore) then
                bestScore = math.floor(overallScore + 0.5)
            end
            if type(affixScores) == "table" then
                for _, entry in ipairs(affixScores) do
                    if type(entry) == "table" then
                        local lvl = (not IsSecretValue(entry.level) and tonumber(entry.level)) or 0
                        if lvl > bestLevel then
                            bestLevel = lvl
                            if not IsSecretValue(entry.overTime) then
                                isTimed = (entry.overTime == false)
                            end
                        end
                    end
                end
            end
        end
    end

    if C_MythicPlus and type(C_MythicPlus.GetSeasonBestForMap) == "function" then
        local okS, intimeInfo, overtimeInfo = pcall(C_MythicPlus.GetSeasonBestForMap, mapID)
        if okS then
            if type(intimeInfo) == "table" then
                local lvl = (not IsSecretValue(intimeInfo.level) and tonumber(intimeInfo.level)) or 0
                if lvl >= bestLevel and lvl > 0 then
                    bestLevel = lvl
                    isTimed = true
                end
                local sc = (not IsSecretValue(intimeInfo.dungeonScore) and tonumber(intimeInfo.dungeonScore)) or 0
                if sc > bestScore then bestScore = math.floor(sc + 0.5) end
            end
            if bestLevel == 0 and type(overtimeInfo) == "table" then
                local lvl = (not IsSecretValue(overtimeInfo.level) and tonumber(overtimeInfo.level)) or 0
                if lvl > 0 then
                    bestLevel = lvl
                    isTimed = false
                end
                local sc = (not IsSecretValue(overtimeInfo.dungeonScore) and tonumber(overtimeInfo.dungeonScore)) or 0
                if sc > bestScore then bestScore = math.floor(sc + 0.5) end
            end
        end
    end

    return bestLevel, bestScore, isTimed
end

local function GetOwnedKeystoneInfo()
    local mapID, level = nil, 0
    if C_MythicPlus then
        if type(C_MythicPlus.GetOwnedKeystoneChallengeMapID) == "function" then
            local okM, id = pcall(C_MythicPlus.GetOwnedKeystoneChallengeMapID)
            if okM and not IsSecretValue(id) and tonumber(id) then
                mapID = tonumber(id)
            end
        end
        if type(C_MythicPlus.GetOwnedKeystoneLevel) == "function" then
            local okL, lvl = pcall(C_MythicPlus.GetOwnedKeystoneLevel)
            if okL and not IsSecretValue(lvl) and tonumber(lvl) then
                level = tonumber(lvl)
            end
        end
    end
    if not mapID or level <= 0 then
        return nil, 0, nil, nil
    end
    local slots = GetSeasonDungeonSlots(false)
    for _, slot in ipairs(slots) do
        if slot.mapID == mapID then
            return mapID, level, slot.code, slot.name
        end
    end
    local dName = "Keystone Dungeon"
    if C_ChallengeMode and type(C_ChallengeMode.GetMapUIInfo) == "function" then
        local okU, uiName = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
        if okU and type(uiName) == "string" and uiName ~= "" and not IsSecretValue(uiName) then
            dName = uiName
        end
    end
    return mapID, level, BuildDungeonShortCode(dName, mapID), dName
end

local function HasActiveDungeonFilters(db)
    if type(db) ~= "table" or type(db.filteredDungeons) ~= "table" then return false end
    for _, v in pairs(db.filteredDungeons) do
        if v then return true end
    end
    return false
end

local function CountActiveUtilityFilters(db)
    if type(db) ~= "table" then return 0 end
    local count = 0
    if db.needsTank then count = count + 1 end
    if db.needsHealer then count = count + 1 end
    if db.needsDamage then count = count + 1 end
    if db.noDuplicateClass then count = count + 1 end
    if db.hasTank then count = count + 1 end
    if db.hasHealer then count = count + 1 end
    if db.hasLust or db.partyFitFilter == "NEEDS_LUST" or db.partyFitFilter == "NEEDS_BOTH" then count = count + 1 end
    if db.hasCR or db.partyFitFilter == "NEEDS_CR" or db.partyFitFilter == "NEEDS_BOTH" then count = count + 1 end
    return count
end

local recentSearchResultCache = {}

local function InspectSearchResult(resultID)
    if not IsValidSearchResultID(resultID) then
        return nil
    end
    local ok, searchInfo = pcall(C_LFGList.GetSearchResultInfo, resultID)
    if not ok or type(searchInfo) ~= "table" then
        return nil
    end

    local hasLeader = (searchInfo.leaderName ~= nil and not IsSecretValue(searchInfo.leaderName) and type(searchInfo.leaderName) == "string" and searchInfo.leaderName ~= "")
    local leaderName = hasLeader and searchInfo.leaderName or ""
    local leaderScore = (not IsSecretValue(searchInfo.leaderOverallDungeonScore) and tonumber(searchInfo.leaderOverallDungeonScore)) or 0
    local numMembers = (not IsSecretValue(searchInfo.numMembers) and tonumber(searchInfo.numMembers)) or 0
    local maxMembers = (not IsSecretValue(searchInfo.maxMembers) and tonumber(searchInfo.maxMembers)) or 5
    if maxMembers <= 0 then maxMembers = 5 end

    local _, playerClassFile = UnitClass("player")
    local tanks, healers, dps = 0, 0, 0
    local tankClass, healerClass = nil, nil
    local dpsClasses = {}
    local hasLust, hasCR, hasPlayerClass = false, false, false
    local memberDots = {}

    if numMembers > 0 then
        local hasPlayerInfoAPI = (type(C_LFGList.GetSearchResultPlayerInfo) == "function")
        local hasMemberInfoAPI = (type(C_LFGList.GetSearchResultMemberInfo) == "function")
        for i = 1, math.min(numMembers, 5) do
            local role, classFile = nil, nil
            if hasPlayerInfoAPI then
                local pOk, pInfo = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, i)
                if pOk and type(pInfo) == "table" and not IsSecretValue(pInfo) then
                    role = (not IsSecretValue(pInfo.assignedRole) and pInfo.assignedRole) or nil
                    classFile = (not IsSecretValue(pInfo.classFilename) and pInfo.classFilename) or nil
                    if not hasLeader and pInfo.isLeader and pInfo.name and not IsSecretValue(pInfo.name) and type(pInfo.name) == "string" and pInfo.name ~= "" then
                        leaderName = pInfo.name
                        hasLeader = true
                    end
                end
            elseif hasMemberInfoAPI then
                local mOk, r, c = pcall(C_LFGList.GetSearchResultMemberInfo, resultID, i)
                if mOk then
                    role = (not IsSecretValue(r) and r) or nil
                    classFile = (not IsSecretValue(c) and c) or nil
                end
            end

            if role then
                if role == "TANK" then
                    tanks = tanks + 1
                    if not tankClass and classFile then tankClass = classFile end
                elseif role == "HEALER" then
                    healers = healers + 1
                    if not healerClass and classFile then healerClass = classFile end
                else
                    dps = dps + 1
                    dpsClasses[#dpsClasses + 1] = classFile or false
                end

                if classFile then
                    if LUST_CLASSES[classFile] then hasLust = true end
                    if CR_CLASSES[classFile] then hasCR = true end
                    if playerClassFile and classFile == playerClassFile then hasPlayerClass = true end
                end

                local hex = (classFile and CLASS_COLORS_HEX[classFile]) or "FF94A3B8"
                local rTag = ROLE_SHORT[role] or "D"
                memberDots[#memberDots + 1] = "|c" .. hex .. rTag .. "|r"
            end
        end
    end

    local activityID = (not IsSecretValue(searchInfo.activityID) and tonumber(searchInfo.activityID)) or nil
    if not activityID and type(searchInfo.activityIDs) == "table" and not IsSecretValue(searchInfo.activityIDs) then
        local firstAct = searchInfo.activityIDs[1]
        if not IsSecretValue(firstAct) and tonumber(firstAct) then
            activityID = tonumber(firstAct)
        end
    end
    local actMeta = activityID and GetCachedActivityInfo(activityID) or nil
    local rawListingName = (type(searchInfo.name) == "string" and not IsSecretValue(searchInfo.name)) and searchInfo.name or nil
    if resultID and activityID then
        recentSearchResultCache[resultID] = {
            activityID = activityID,
            name = rawListingName,
        }
    end

    local regionKey, realmName = "PENDING", ""
    if hasLeader then
        regionKey, realmName = DynamicGroup:ResolveLeaderRegion(leaderName)
    end

    local isDelisted = (not IsSecretValue(searchInfo.isDelisted) and searchInfo.isDelisted) and true or false

    return {
        resultID = resultID,
        searchInfo = searchInfo,
        leaderName = leaderName,
        realmName = realmName,
        regionKey = regionKey,
        leaderScore = leaderScore,
        numMembers = numMembers,
        maxMembers = maxMembers,
        openSlots = math.max(0, maxMembers - numMembers),
        isDelisted = isDelisted,
        isFull = (numMembers >= maxMembers),
        tanks = tanks,
        healers = healers,
        dps = dps,
        tankClass = tankClass,
        healerClass = healerClass,
        dpsClasses = dpsClasses,
        hasLust = hasLust,
        hasCR = hasCR,
        hasPlayerClass = hasPlayerClass,
        activityID = activityID,
        challengeMapID = actMeta and actMeta.mapID or nil,
        dungeonCode = actMeta and actMeta.code or nil,
        isMythicPlusActivity = actMeta and actMeta.isMythicPlusActivity or false,
        isDungeonActivity = actMeta and actMeta.isDungeonActivity or false,
        memberDots = memberDots,
    }
end

local function SafeGetSpecialization()
    if C_SpecializationInfo and type(C_SpecializationInfo.GetSpecialization) == "function" then
        return C_SpecializationInfo.GetSpecialization()
    end
    if type(GetSpecialization) == "function" then
        return GetSpecialization()
    end
    return nil
end

local function SafeGetSpecializationRole(specIndex)
    if C_SpecializationInfo and type(C_SpecializationInfo.GetSpecializationRole) == "function" then
        return C_SpecializationInfo.GetSpecializationRole(specIndex)
    end
    if type(GetSpecializationRole) == "function" then
        return GetSpecializationRole(specIndex)
    end
    return nil
end

local function SafeGetSpecializationInfo(specIndex)
    if C_SpecializationInfo and type(C_SpecializationInfo.GetSpecializationInfo) == "function" then
        return C_SpecializationInfo.GetSpecializationInfo(specIndex)
    end
    if type(GetSpecializationInfo) == "function" then
        return GetSpecializationInfo(specIndex)
    end
    return nil
end

local function GetPlayerActiveRoleAndLust()
    local role = "DAMAGER"
    local spec = SafeGetSpecialization()
    if spec then
        role = SafeGetSpecializationRole(spec) or "DAMAGER"
    end
    local _, classFile = UnitClass("player")
    local playerHasLust = (classFile and LUST_CLASSES[classFile]) and true or false
    return role, playerHasLust
end

local function GroupNeedsRole(meta, role)
    if not meta then return true end
    if meta.maxMembers > 5 then return not meta.isFull end
    if role == "TANK" then return meta.tanks < 1
    elseif role == "HEALER" then return meta.healers < 1
    else return meta.dps < 3 end
end

local isSyncingAdvancedFilter = false

local function HealBlizzardMythicPlusDifficultyFlag(adv, db)
    if type(adv) ~= "table" or type(db) ~= "table" then return false end
    local allDiffFalse = (adv.difficultyNormal == false and adv.difficultyHeroic == false and adv.difficultyMythic == false and adv.difficultyMythicPlus == false)
    if allDiffFalse or (db._fixedMPlusDifficultyReset ~= true and adv.difficultyMythicPlus == false) then
        adv.difficultyMythicPlus = true
        db._fixedMPlusDifficultyReset = true
        return true
    end
    if db._fixedMPlusDifficultyReset ~= true then
        db._fixedMPlusDifficultyReset = true
    end
    return false
end

local function PushFiltersToBlizzardAdvancedFilter(syncDungeons)
    if isSyncingAdvancedFilter then return end
    if not C_LFGList or type(C_LFGList.GetAdvancedFilter) ~= "function" or type(C_LFGList.SaveAdvancedFilter) ~= "function" then
        return
    end
    isSyncingAdvancedFilter = true
    pcall(function()
        local okG, adv = pcall(C_LFGList.GetAdvancedFilter)
        if not okG or type(adv) ~= "table" then return end
        local db = EnsureDB()

        adv.needsTank = (db.needsTank == true)
        adv.needsHealer = (db.needsHealer == true)
        adv.needsDamage = (db.needsDamage == true)
        adv.needsMyClass = (db.noDuplicateClass == true)
        adv.hasTank = (db.hasTank == true)
        adv.hasHealer = (db.hasHealer == true)
        HealBlizzardMythicPlusDifficultyFlag(adv, db)

        if syncDungeons then
            local slots = GetSeasonDungeonSlots(false)
            local seasonGroupLookup = {}
            local allSeasonGroupIDs = {}
            local selectedGroupIDs = {}
            for _, slot in ipairs(slots) do
                if slot.activityGroupID then
                    seasonGroupLookup[slot.activityGroupID] = true
                    allSeasonGroupIDs[#allSeasonGroupIDs + 1] = slot.activityGroupID
                    if db.filteredDungeons[slot.code] or db.filteredDungeons[slot.mapID] then
                        selectedGroupIDs[#selectedGroupIDs + 1] = slot.activityGroupID
                    end
                end
            end
            if #allSeasonGroupIDs > 0 then
                local nextActs = {}
                if type(adv.activities) == "table" then
                    for _, gid in ipairs(adv.activities) do
                        if not seasonGroupLookup[gid] then
                            nextActs[#nextActs + 1] = gid
                        end
                    end
                end
                local toAdd = HasActiveDungeonFilters(db) and selectedGroupIDs or allSeasonGroupIDs
                for _, gid in ipairs(toAdd) do
                    nextActs[#nextActs + 1] = gid
                end
                adv.activities = nextActs
            end
        end

        pcall(C_LFGList.SaveAdvancedFilter, adv)
    end)
    isSyncingAdvancedFilter = false
end

local function PullFiltersFromBlizzardAdvancedFilter()
    if isSyncingAdvancedFilter then return end
    if not C_LFGList or type(C_LFGList.GetAdvancedFilter) ~= "function" then
        return
    end
    isSyncingAdvancedFilter = true
    pcall(function()
        local okG, adv = pcall(C_LFGList.GetAdvancedFilter)
        if not okG or type(adv) ~= "table" then return end
        local db = EnsureDB()

        if HealBlizzardMythicPlusDifficultyFlag(adv, db) and type(C_LFGList.SaveAdvancedFilter) == "function" then
            pcall(C_LFGList.SaveAdvancedFilter, adv)
        end

        if adv.needsTank ~= nil then
            db.needsTank = (adv.needsTank == true)
        end
        if adv.needsHealer ~= nil then
            db.needsHealer = (adv.needsHealer == true)
        end
        if adv.needsDamage ~= nil then
            db.needsDamage = (adv.needsDamage == true)
        end
        if adv.needsMyClass ~= nil then
            db.noDuplicateClass = (adv.needsMyClass == true)
        end
        if adv.hasTank ~= nil then
            db.hasTank = (adv.hasTank == true)
        end
        if adv.hasHealer ~= nil then
            db.hasHealer = (adv.hasHealer == true)
        end
        SyncLegacyPartyFitFromFlags(db)
    end)
    isSyncingAdvancedFilter = false
end

local function DoesMetaPassAllFilters(meta, db, myRole)
    if not meta then return false end
    if meta.regionKey ~= "PENDING" and db.enabledRegions[meta.regionKey] == false then
        return false
    end

    local minScore = tonumber(db.minLeaderScore) or 0
    if minScore > 0 and meta.leaderScore < minScore then
        return false
    end

    if db.hideFullGroups and (meta.isFull or meta.isDelisted) then
        return false
    end

    local spCat = _G.LFGListFrame and _G.LFGListFrame.SearchPanel and _G.LFGListFrame.SearchPanel.categoryID
    local inDungeonContext = meta.isDungeonActivity or (spCat == 2)
    if inDungeonContext and HasActiveDungeonFilters(db) then
        local matched = (meta.dungeonCode and db.filteredDungeons[meta.dungeonCode])
            or (meta.challengeMapID and db.filteredDungeons[meta.challengeMapID])
        if not matched and (meta.activityID or meta.dungeonCode or meta.challengeMapID) then
            return false
        end
    end

    if db.needsTank then
        if meta.maxMembers <= 5 then
            if (tonumber(meta.tanks) or 0) >= 1 then return false end
        elseif meta.isFull then
            return false
        end
    end
    if db.needsHealer then
        if meta.maxMembers <= 5 then
            if (tonumber(meta.healers) or 0) >= 1 then return false end
        elseif meta.isFull then
            return false
        end
    end
    if db.needsDamage then
        if meta.maxMembers <= 5 then
            if (tonumber(meta.dps) or 0) >= 3 then return false end
        elseif meta.isFull then
            return false
        end
    end

    if db.noDuplicateClass and meta.hasPlayerClass then
        return false
    end

    if db.hasTank and (tonumber(meta.tanks) or 0) < 1 then
        return false
    end

    if db.hasHealer and (tonumber(meta.healers) or 0) < 1 then
        return false
    end

    local fitFilter = db.partyFitFilter or "ALL"
    if (db.hasLust or fitFilter == "NEEDS_LUST" or fitFilter == "NEEDS_BOTH") and not meta.hasLust then
        return false
    end
    if (db.hasCR or fitFilter == "NEEDS_CR" or fitFilter == "NEEDS_BOTH") and not meta.hasCR then
        return false
    end

    return true
end

local function ResolveLiveResultID(entry)
    if not entry then return nil end
    local elementData = entry.GetElementData and entry:GetElementData()
    if elementData then
        if type(elementData) == "table" then
            local rID = elementData.resultID or elementData.id or elementData.searchResultID
            if rID and type(rID) == "number" then return rID end
        elseif type(elementData) == "number" then
            return elementData
        end
    end
    if entry.resultID and type(entry.resultID) == "number" then
        return entry.resultID
    end
    return nil
end

local function HasExternalLFGConflict()
    if IsYieldingSharedHooks() then
        return true, "Suite Conflict Resolution (AUTO_YIELD)"
    end
    -- Check WindTools QuickJoin
    if _G.WindTools and _G.WindTools.GetModule then
        local ok, mod = pcall(_G.WindTools.GetModule, _G.WindTools, "QuickJoin")
        if ok and mod and mod.db and mod.db.enable then
            return true, "WindTools QuickJoin"
        end
    end
    if _G.ElvUI and _G.ElvUI[1] then
        local E = _G.ElvUI[1]
        if E.db and E.db.windtools and E.db.windtools.more and E.db.windtools.more.quickJoin and E.db.windtools.more.quickJoin.enable then
            return true, "WindTools QuickJoin"
        end
        if E.private and E.private.wt and E.private.wt.quickJoin then
            return true, "WindTools QuickJoin"
        end
    end
    -- Check EUI LFG Quick Join
    if _G.EUI and _G.EUI.db and _G.EUI.db.lfg and _G.EUI.db.lfg.enable then
        return true, "EUI LFG"
    end
    -- Check Premade Groups Filter quick signup if active
    if _G.PremadeGroupsFilter and _G.PremadeGroupsFilter.QuickSignUpActive then
        return true, "PremadeGroupsFilter QuickSignUp"
    end
    return false, nil
end

local lastSignUpResultID = nil
local lastSignUpTime = 0

local function PerformLFGSignUp(entry, isDoubleClick, explicitResultID)
    if InCombatLockdown and InCombatLockdown() then return end
    if HasExternalLFGConflict() then return end

    local liveResultID = (type(explicitResultID) == "number" and explicitResultID)
        or (entry and type(entry.resultID) == "number" and entry.resultID)
        or ResolveLiveResultID(entry)
    if not liveResultID then return end

    -- Verify search result info is valid and not delisted before submitting
    if not C_LFGList or type(C_LFGList.HasSearchResultInfo) ~= "function" then
        return
    end
    local okHas, hasInfo = pcall(C_LFGList.HasSearchResultInfo, liveResultID)
    if not okHas or IsSecretValue(hasInfo) or not hasInfo then
        return
    end

    if type(C_LFGList.GetSearchResultInfo) ~= "function" then
        return
    end
    local okInfo, searchInfo = pcall(C_LFGList.GetSearchResultInfo, liveResultID)
    if not okInfo or type(searchInfo) ~= "table" or IsSecretValue(searchInfo) then
        return
    end
    if (not IsSecretValue(searchInfo.isDelisted) and searchInfo.isDelisted)
        or (not IsSecretValue(searchInfo.hasSearchResult) and searchInfo.hasSearchResult == false) then
        return
    end

    local now = (GetTime and GetTime()) or 0
    if (now - lastSignUpTime) < 0.40 and lastSignUpResultID == liveResultID then
        -- Debounce rapid duplicate trigger within 400ms on same group
        return
    end

    local sp = _G.LFGListFrame and _G.LFGListFrame.SearchPanel
    if not sp then return end

    -- Synchronize selectedResult without rebuilding/re-sorting the ScrollBox
    sp.selectedResult = liveResultID
    if type(_G.LFGListSearchPanel_UpdateButtonStatus) == "function" then
        pcall(_G.LFGListSearchPanel_UpdateButtonStatus, sp)
    end

    lastSignUpResultID = liveResultID
    lastSignUpTime = now

    -- Open LFGListApplicationDialog directly with the exact clicked liveResultID
    if type(_G.LFGListApplicationDialog_Show) == "function" and _G.LFGListApplicationDialog then
        pcall(_G.LFGListApplicationDialog_Show, _G.LFGListApplicationDialog, liveResultID)
    elseif sp.SignUpButton and sp.SignUpButton:IsEnabled() and type(_G.LFGListSearchPanel_SignUp) == "function" then
        pcall(_G.LFGListSearchPanel_SignUp, sp)
    elseif sp.SignUpButton and sp.SignUpButton:IsEnabled() and sp.SignUpButton.Click then
        pcall(sp.SignUpButton.Click, sp.SignUpButton)
    end
end

local ScheduleAsyncResultRefilter
local _dgEntryState = setmetatable({}, { __mode = "k" })
local _dgPanelState = setmetatable({}, { __mode = "k" })
local _dgDialogState = setmetatable({}, { __mode = "k" })

local function GetEntryState(entry)
    local st = _dgEntryState[entry]
    if not st then
        st = {}
        _dgEntryState[entry] = st
    end
    return st
end

local function GetPanelState(panel)
    local st = _dgPanelState[panel]
    if not st then
        st = {}
        _dgPanelState[panel] = st
    end
    return st
end

local function OnLFGListSearchEntryUpdate(entry)
    if not entry then return end
    local db = EnsureDB()
    local eState = GetEntryState(entry)
    if IsYieldingSharedHooks() then
        if eState.overlay then
            eState.overlay:Hide()
        end
        return
    end

    if not eState.enterHooked and entry.GetScript and entry.SetScript then
        local origOnEnter = entry:GetScript("OnEnter")
        if type(origOnEnter) == "function" then
            eState.enterHooked = true
            entry:SetScript("OnEnter", function(selfEntry, ...)
                local rID = selfEntry.resultID or ResolveLiveResultID(selfEntry)
                if not IsValidSearchResultID(rID) then
                    if _G.GameTooltip and _G.GameTooltip:IsOwned(selfEntry) then
                        _G.GameTooltip:Hide()
                    end
                    if ScheduleAsyncResultRefilter then
                        ScheduleAsyncResultRefilter()
                    end
                    return
                end
                return origOnEnter(selfEntry, ...)
            end)
        end
    end

    if not eState.clickHooked and entry.HookScript then
        eState.clickHooked = true
        entry:HookScript("OnMouseDown", function(selfEntry, button)
            if button == "LeftButton" then
                GetEntryState(selfEntry).pressedResultID = (type(selfEntry.resultID) == "number" and selfEntry.resultID) or ResolveLiveResultID(selfEntry)
            end
        end)
    end

    if not eState.doubleClickHooked and entry.HookScript then
        eState.doubleClickHooked = true
        entry:HookScript("OnDoubleClick", function(selfEntry, button)
            if button and button ~= "LeftButton" then return end
            if not EnsureDB().doubleClickSignUp then return end
            local st = GetEntryState(selfEntry)
            local lockedID = st.pressedResultID
            st.pressedResultID = nil
            PerformLFGSignUp(selfEntry, true, lockedID)
        end)
    end

    if not eState.overlay then
        local ov = CreateFrame("Frame", nil, entry)
        ov:SetAllPoints(entry)
        ov:EnableMouse(false)
        if ov.SetIgnoreParentAlpha then
            ov:SetIgnoreParentAlpha(true)
        end

        -- Single sleek borderless micro-pill at TOPRIGHT (e.g. "OCE / 3458")
        local topPill = CreateFrame("Frame", nil, ov)
        topPill:SetHeight(14)
        topPill:SetPoint("TOPRIGHT", entry, "TOPRIGHT", -6, -3)
        topPill:EnableMouse(false)

        topPill.bg = topPill:CreateTexture(nil, "BACKGROUND")
        topPill.bg:SetAllPoints(topPill)
        topPill.bg:SetColorTexture(0.043, 0.051, 0.071, 0.65) -- #0B0D12 at 65% alpha

        topPill.text = topPill:CreateFontString(nil, "OVERLAY")
        SetSafeFont(topPill.text, 10, "OUTLINE")
        topPill.text:SetPoint("CENTER", topPill, "CENTER", 0, 0)
        topPill.text:SetJustifyH("CENTER")

        ov.topPill = topPill
        ov.topTag = topPill.text

        -- 5-Player Open Role-Slot Overlays (centered over Blizzard's empty Enumerate grey dots)
        ov.enumRoleSlots = {}
        for idx = 1, 5 do
            local slotOv = CreateFrame("Frame", nil, ov)
            slotOv:SetSize(18, 18)
            slotOv:EnableMouse(false)

            slotOv.tex = slotOv:CreateTexture(nil, "ARTWORK")
            slotOv.tex:SetAllPoints(slotOv)
            slotOv.tex:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
            DisableTexPixelSnap(slotOv.tex)
            slotOv:Hide()

            ov.enumRoleSlots[idx] = slotOv
        end

        eState.overlay = ov
    end

    local ov = eState.overlay
    local sp = _G.LFGListFrame and _G.LFGListFrame.SearchPanel
    local sbAlpha = (sp and sp.ScrollBox and sp.ScrollBox.GetAlpha and sp.ScrollBox:GetAlpha()) or 1
    local pFrame = entry.GetParent and entry:GetParent()
    local pAlpha = (pFrame and pFrame.GetAlpha and pFrame:GetAlpha()) or 1
    if ov.SetIgnoreParentAlpha then
        if sbAlpha <= 0.01 or pAlpha <= 0.01 then
            ov:SetIgnoreParentAlpha(false)
        else
            ov:SetIgnoreParentAlpha(true)
        end
    end

    local resultID = entry.resultID or ResolveLiveResultID(entry)
    local meta = InspectSearchResult(resultID)
    if not meta then
        ov:Hide()
        if _G.GameTooltip and _G.GameTooltip:IsOwned(entry) then
            _G.GameTooltip:Hide()
        end
        if resultID and ScheduleAsyncResultRefilter then
            ScheduleAsyncResultRefilter()
        end
        return
    end

    if db.lfgFilterEnabled and meta.regionKey ~= "PENDING" and db.enabledRegions[meta.regionKey] == false then
        ov:Hide()
        if ScheduleAsyncResultRefilter then
            ScheduleAsyncResultRefilter()
        end
        return
    end

    if not db.lfgFilterEnabled or db.showEntryOverlay == false or db.overlayMode == "OFF" or sbAlpha <= 0.01 or pAlpha <= 0.01 then
        ov:Hide()
        return
    end

    -- Keep region & score tags legible (>= 78% alpha even on dimmed/delisted or red-selected rows)
    local parentAlpha = (entry.GetAlpha and entry:GetAlpha()) or 1.0
    ov:SetAlpha((meta.isDelisted or parentAlpha < 0.75) and 0.78 or 0.96)

    local showRegion = (meta.regionKey and meta.regionKey ~= "PENDING")
    local hasScore = (meta.leaderScore and meta.leaderScore > 0)
    local topPill = ov.topPill
    if showRegion or hasScore then
        local parts = {}
        if showRegion then
            local regMeta = REGION_META[meta.regionKey] or REGION_META.UNKNOWN
            local rc = GetRegionColor(meta.regionKey)
            local cleanReg = (regMeta.badge or "UNK"):gsub("%[", ""):gsub("%]", "")
            parts[#parts + 1] = "|c" .. rc.hex .. cleanReg .. "|r"
        end
        if hasScore then
            local sHex = GetScoreColorHex(meta.leaderScore)
            parts[#parts + 1] = "|c" .. sHex .. tostring(meta.leaderScore) .. "|r"
        end
        SetSafeFont(topPill.text, 10, "OUTLINE")
        topPill.text:SetText(table.concat(parts, " |cFF64748B/|r "))
        local pillW = math.ceil((topPill.text:GetStringWidth() or 24) + 10)
        topPill:SetSize(math.max(26, pillW), 14)
        topPill:ClearAllPoints()
        topPill:SetPoint("TOPRIGHT", entry, "TOPRIGHT", -6, -3)
        topPill:Show()
    else
        topPill.text:SetText("")
        topPill:Hide()
    end

    -- Overlay Desaturated Tank / Healer / DPS Icons Directly on Empty Grey Dots in Enumerate
    local enumSlots = ov.enumRoleSlots
    if enumSlots then
        local enumFrame = entry.DataDisplay and entry.DataDisplay.Enumerate
        if meta.maxMembers == 5 and enumFrame and enumFrame.IsShown and enumFrame:IsShown() then
            local slotAnchors = {}
            for i = 1, 5 do
                local ic = enumFrame["Icon" .. i]
                if ic then
                    slotAnchors[#slotAnchors + 1] = ic
                end
            end
            if #slotAnchors < 5 and type(enumFrame.Icons) == "table" then
                slotAnchors = {}
                for _, ic in ipairs(enumFrame.Icons) do
                    slotAnchors[#slotAnchors + 1] = ic
                end
            end
            if #slotAnchors < 5 and enumFrame.GetChildren then
                local children = { enumFrame:GetChildren() }
                if #children > 0 then
                    slotAnchors = children
                end
            end
            -- Idempotent -2px vertical baseline nudge on Enumerate (preserving all original points)
            if not enumFrame._dgOrigPoints and enumFrame.GetNumPoints and enumFrame.GetPoint then
                local numPts = enumFrame:GetNumPoints()
                if numPts and numPts > 0 then
                    local pts = {}
                    for p = 1, numPts do
                        local pt, relTo, relPt, x, y = enumFrame:GetPoint(p)
                        if pt then
                            pts[#pts + 1] = { pt, relTo, relPt, x or 0, y or 0 }
                        end
                    end
                    if #pts > 0 then
                        enumFrame._dgOrigPoints = pts
                    end
                end
            end
            if enumFrame._dgOrigPoints and enumFrame.SetPoint then
                for _, p in ipairs(enumFrame._dgOrigPoints) do
                    enumFrame:SetPoint(p[1], p[2], p[3], p[4], p[5] - 4)
                end
            end

            -- Idempotent 4px horizontal gap between sibling Enumerate icons in Blizzard's native chain
            for _, ic in ipairs(slotAnchors) do
                if ic and not ic._dgOrigPoint and ic.GetPoint then
                    local pt, relTo, relPt, x, y = ic:GetPoint(1)
                    if pt then
                        ic._dgOrigPoint = { pt, relTo, relPt, x or 0, y or 0 }
                    end
                end
                if ic and ic._dgOrigPoint and ic.SetPoint then
                    local op = ic._dgOrigPoint
                    if op[2] and op[2] ~= enumFrame then
                        local nx = (op[1]:find("LEFT") and (op[4] + 4) or (op[4] - 4))
                        ic:SetPoint(op[1], op[2], op[3], nx, op[5])
                    end
                end
            end

            table.sort(slotAnchors, function(a, b)
                local la = (a and a.GetLeft and a:GetLeft()) or 0
                local lb = (b and b.GetLeft and b:GetLeft()) or 0
                return la < lb
            end)

            local openRoles = {}
            local openTanks = math.max(0, 1 - (meta.tanks or 0))
            local openHealers = math.max(0, 1 - (meta.healers or 0))
            local openDPS = math.max(0, 3 - (meta.dps or 0))
            for _ = 1, openTanks do openRoles[#openRoles + 1] = "TANK" end
            for _ = 1, openHealers do openRoles[#openRoles + 1] = "HEALER" end
            for _ = 1, openDPS do openRoles[#openRoles + 1] = "DAMAGER" end

            local filledCount = math.max(0, math.min(5, meta.numMembers or ((meta.tanks or 0) + (meta.healers or 0) + (meta.dps or 0))))
            local enumLevel = (enumFrame.GetFrameLevel and enumFrame:GetFrameLevel()) or (ov.GetFrameLevel and ov:GetFrameLevel()) or 1

            local function SetAnchorGreyDotVisible(anchorObj, showDot)
                if not anchorObj then return end
                local alphaVal = showDot and 1 or 0
                if anchorObj.IsObjectType and anchorObj:IsObjectType("Texture") then
                    if anchorObj.SetAlpha then
                        anchorObj:SetAlpha(alphaVal)
                    end
                elseif anchorObj.GetRegions then
                    local regions = { anchorObj:GetRegions() }
                    for _, reg in ipairs(regions) do
                        if reg and reg.IsObjectType and reg:IsObjectType("Texture") and reg.SetAlpha then
                            reg:SetAlpha(alphaVal)
                        end
                    end
                end
            end

            local sibW, sibH = nil, nil
            if slotAnchors[1] then
                sibW = slotAnchors[1].GetWidth and slotAnchors[1]:GetWidth() or nil
                sibH = slotAnchors[1].GetHeight and slotAnchors[1]:GetHeight() or nil
            end

            for idx = 1, 5 do
                local slotOv = enumSlots[idx]
                local anchor = slotAnchors[idx]
                if slotOv then
                    if idx > filledCount and anchor and (not anchor.IsShown or anchor:IsShown()) then
                        local roleKey = openRoles[idx - filledCount]
                        if roleKey then
                            SetAnchorGreyDotVisible(anchor, false)
                            local aw = (anchor.GetWidth and anchor:GetWidth()) or sibW or 16
                            local ah = (anchor.GetHeight and anchor:GetHeight()) or sibH or 16
                            if aw <= 0 then aw = (sibW and sibW > 0) and sibW or 16 end
                            if ah <= 0 then ah = (sibH and sibH > 0) and sibH or 16 end
                            slotOv:SetSize(aw, ah)
                            slotOv:ClearAllPoints()
                            slotOv:SetPoint("CENTER", anchor, "CENTER", 0, 0)
                            if slotOv.SetFrameLevel then
                                slotOv:SetFrameLevel(enumLevel + 2)
                            end
                            if slotOv.tex.SetDesaturated then
                                slotOv.tex:SetDesaturated(true)
                            end
                            if roleKey == "TANK" then
                                slotOv.tex:SetTexCoord(0 / 64, 19 / 64, 22 / 64, 41 / 64)
                            elseif roleKey == "HEALER" then
                                slotOv.tex:SetTexCoord(20 / 64, 39 / 64, 1 / 64, 20 / 64)
                            else
                                slotOv.tex:SetTexCoord(20 / 64, 39 / 64, 22 / 64, 41 / 64)
                            end
                            slotOv.tex:SetVertexColor(0.56, 0.60, 0.66, 0.72)
                            slotOv:Show()
                        else
                            SetAnchorGreyDotVisible(anchor, true)
                            slotOv:Hide()
                        end
                    else
                        SetAnchorGreyDotVisible(anchor, true)
                        slotOv:Hide()
                    end
                end
            end
        else
            if enumFrame then
                for i = 1, 5 do
                    local ic = enumFrame["Icon" .. i]
                    if ic then
                        if ic.IsObjectType and ic:IsObjectType("Texture") and ic.SetAlpha then
                            ic:SetAlpha(1)
                        elseif ic.GetRegions then
                            for _, reg in ipairs({ ic:GetRegions() }) do
                                if reg and reg.IsObjectType and reg:IsObjectType("Texture") and reg.SetAlpha then
                                    reg:SetAlpha(1)
                                end
                            end
                        end
                    end
                end
            end
            for idx = 1, 5 do
                if enumSlots[idx] then
                    enumSlots[idx]:Hide()
                end
            end
        end
    end

    ov:Show()
end

function DynamicGroup:DoesResultPassFilters(resultID)
    if not IsValidSearchResultID(resultID) then
        return false
    end
    if IsYieldingSharedHooks() then
        return true
    end
    local db = EnsureDB()
    if not db.lfgFilterEnabled then return true end
    local meta = InspectSearchResult(resultID)
    if not meta then return false end
    local myRole = GetPlayerActiveRoleAndLust()
    return DoesMetaPassAllFilters(meta, db, myRole)
end

local function SuppressEUIGroupFinderIfNeeded()
    -- Do not silently mutate external addon SavedVariables (_G.EllesmereUIDB); conflicts are handled via Suite Conflict Detection.
    local sp = _G.LFGListFrame and _G.LFGListFrame.SearchPanel
    if sp then
        if sp.ScrollBox and sp.ScrollBox.SetAlpha and (sp.ScrollBox:GetAlpha() or 1) < 0.05 then
            pcall(sp.ScrollBox.SetAlpha, sp.ScrollBox, 1)
        end
        if sp.ScrollBar and sp.ScrollBar.SetAlpha and (sp.ScrollBar:GetAlpha() or 1) < 0.05 then
            pcall(sp.ScrollBar.SetAlpha, sp.ScrollBar, 1)
        end
        if sp.SignUpButton and sp.SignUpButton.SetAlpha and (sp.SignUpButton:GetAlpha() or 1) < 0.05 then
            pcall(sp.SignUpButton.SetAlpha, sp.SignUpButton, 1)
        end
    end
end
DynamicGroup.SuppressEUIGroupFinderIfNeeded = SuppressEUIGroupFinderIfNeeded

local pendingResultUpdateTimer = nil

local function SyncScrollBoxToFilteredResults(panel)
    if not panel then return end
    if InCombatLockdown and InCombatLockdown() then return end

    if type(panel.results) == "table" then
        local validResults = {}
        local scrubbed = false
        for i = 1, #panel.results do
            local rID = panel.results[i]
            if IsValidSearchResultID(rID) then
                validResults[#validResults + 1] = rID
            else
                scrubbed = true
            end
        end
        if scrubbed then
            panel.results = validResults
            panel.totalResults = #validResults
        end
    end
    if panel.selectedResult and not IsValidSearchResultID(panel.selectedResult) then
        panel.selectedResult = nil
    end

    if panel.ScrollBox and type(panel.ScrollBox.ForEachFrame) == "function" then
        pcall(panel.ScrollBox.ForEachFrame, panel.ScrollBox, OnLFGListSearchEntryUpdate)
    end
end

local function RemoveFilteredResultsInPlace(panel)
    if not panel or type(panel.results) ~= "table" then return end
    if InCombatLockdown and InCombatLockdown() then return end

    -- Only defer while the left mouse button is actively held down
    if IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
        return
    end

    local pState = GetPanelState(panel)
    local newResults = {}
    local removedAny = false
    for _, resultID in ipairs(panel.results) do
        if DynamicGroup:DoesResultPassFilters(resultID) then
            newResults[#newResults + 1] = resultID
        else
            removedAny = true
        end
    end

    if removedAny then
        panel.results = newResults
        panel.totalResults = #newResults
        pState.orderedResults = newResults
        if type(_G.LFGListSearchPanel_UpdateResults) == "function" and not pState.inUpdateResultList then
            pcall(_G.LFGListSearchPanel_UpdateResults, panel)
        end
        SyncScrollBoxToFilteredResults(panel)
        if DynamicGroup.UpdateLFGMiniBar then
            DynamicGroup:UpdateLFGMiniBar()
        end
    end
end

ScheduleAsyncResultRefilter = function()
    if pendingResultUpdateTimer then return end
    pendingResultUpdateTimer = C_Timer.NewTimer(0.03, function()
        pendingResultUpdateTimer = nil
        if InCombatLockdown and InCombatLockdown() then return end
        local sp = _G.LFGListFrame and _G.LFGListFrame.SearchPanel
        if sp and sp:IsShown() then
            if IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
                ScheduleAsyncResultRefilter()
                return
            end
            RemoveFilteredResultsInPlace(sp)
        end
    end)
end

local function FilterAndSortSearchPanelResults(panel, allowSort)
    if not panel then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local pState = GetPanelState(panel)

    -- Always fetch authoritative unfiltered results directly from Blizzard's C++ API when available
    local sourceList = nil
    if C_LFGList and type(C_LFGList.GetSearchResults) == "function" then
        local ok, _, apiResults = pcall(C_LFGList.GetSearchResults)
        if ok and type(apiResults) == "table" then
            sourceList = apiResults
            pState.rawResults = apiResults
        end
    end
    if not sourceList then
        sourceList = pState.rawResults or panel.results
    end
    if type(sourceList) ~= "table" then return end

    local db = EnsureDB()
    if not db.lfgFilterEnabled or IsYieldingSharedHooks() then
        local copy = {}
        for i = 1, #sourceList do
            local rID = sourceList[i]
            if IsValidSearchResultID(rID) then
                copy[#copy + 1] = rID
            end
        end
        panel.results = copy
        panel.totalResults = #copy
        pState.orderedResults = copy
        if DynamicGroup.UpdateLFGMiniBar then DynamicGroup:UpdateLFGMiniBar() end
        return
    end

    local myRole, playerHasLust = GetPlayerActiveRoleAndLust()
    local sortMode = db.sortMode or "SMART_HIDE_FULL"

    local passesMap = {}
    local metaCache = {}

    for _, resultID in ipairs(sourceList) do
        local meta = InspectSearchResult(resultID)
        if meta then
            metaCache[resultID] = meta
            if DoesMetaPassAllFilters(meta, db, myRole) then
                passesMap[resultID] = true
            end
        end
    end

    local filtered = {}
    if allowSort == false and type(pState.orderedResults) == "table" and #pState.orderedResults > 0 then
        -- Preserve existing row order on live background updates so rows never jump under the cursor
        local seen = {}
        for _, resultID in ipairs(pState.orderedResults) do
            if passesMap[resultID] and not seen[resultID] then
                seen[resultID] = true
                filtered[#filtered + 1] = resultID
            end
        end
        for _, resultID in ipairs(sourceList) do
            if passesMap[resultID] and not seen[resultID] then
                seen[resultID] = true
                filtered[#filtered + 1] = resultID
            end
        end
    else
        for _, resultID in ipairs(sourceList) do
            if passesMap[resultID] then
                filtered[#filtered + 1] = resultID
            end
        end

        if sortMode ~= "BLIZZARD" and #filtered > 1 then
            table.sort(filtered, function(a, b)
                local ma = metaCache[a]
                local mb = metaCache[b]
                if not ma or not mb then return (tonumber(a) or 0) < (tonumber(b) or 0) end

                if ma.isDelisted ~= mb.isDelisted then
                    return not ma.isDelisted
                end

                if sortMode == "SCORE_DESC" then
                    if ma.leaderScore ~= mb.leaderScore then
                        return ma.leaderScore > mb.leaderScore
                    end
                elseif sortMode == "OPEN_SLOTS" then
                    if ma.openSlots ~= mb.openSlots then
                        return ma.openSlots > mb.openSlots
                    end
                    if ma.leaderScore ~= mb.leaderScore then
                        return ma.leaderScore > mb.leaderScore
                    end
                else
                    local aNeedsRole = GroupNeedsRole(ma, myRole)
                    local bNeedsRole = GroupNeedsRole(mb, myRole)
                    if aNeedsRole ~= bNeedsRole then
                        return aNeedsRole
                    end

                    if playerHasLust then
                        local aNeedsLust = not ma.hasLust
                        local bNeedsLust = not mb.hasLust
                        if aNeedsLust ~= bNeedsLust then
                            return aNeedsLust
                        end
                    else
                        if ma.hasLust ~= mb.hasLust then
                            return ma.hasLust
                        end
                    end

                    if ma.leaderScore ~= mb.leaderScore then
                        return ma.leaderScore > mb.leaderScore
                    end
                end

                return (tonumber(a) or 0) < (tonumber(b) or 0)
            end)
        end

        if #filtered > 0 then
            pState.needsInitialSort = false
        end
    end

    local orderedCopy = {}
    for i = 1, #filtered do
        orderedCopy[i] = filtered[i]
    end
    pState.orderedResults = orderedCopy
    panel.results = filtered
    panel.totalResults = #filtered
    if panel.selectedResult and not passesMap[panel.selectedResult] then
        panel.selectedResult = nil
    end

    if DynamicGroup.UpdateLFGMiniBar then
        DynamicGroup:UpdateLFGMiniBar()
    end
end

local function OnLFGListSearchPanelUpdateResultList(panel)
    if not panel or type(panel.results) ~= "table" then return end
    if InCombatLockdown and InCombatLockdown() then return end

    SuppressEUIGroupFinderIfNeeded()
    local pState = GetPanelState(panel)
    pState.inUpdateResultList = true

    if C_LFGList and type(C_LFGList.GetSearchResults) == "function" then
        local ok, _, apiResults = pcall(C_LFGList.GetSearchResults)
        if ok and type(apiResults) == "table" then
            pState.rawResults = apiResults
        end
    end
    if not pState.rawResults then
        local rawCopy = {}
        for i = 1, #panel.results do
            rawCopy[i] = panel.results[i]
        end
        pState.rawResults = rawCopy
    end

    local shouldSort = (pState.needsInitialSort ~= false)
        or (type(pState.orderedResults) ~= "table")
        or (#pState.orderedResults == 0)

    FilterAndSortSearchPanelResults(panel, shouldSort)
    pState.inUpdateResultList = false
end

local activeDropdownMenu = nil
local activeRegionPopover = nil
local activeFilterPopover = nil
local dropdownClickCatcher = nil

local function EnsureDropdownClickCatcher()
    if not dropdownClickCatcher then
        dropdownClickCatcher = CreateFrame("Button", "DynamicGroupDropdownCatcher", UIParent)
        dropdownClickCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
        dropdownClickCatcher:SetFrameLevel(90)
        dropdownClickCatcher:SetAllPoints(UIParent)
        dropdownClickCatcher:EnableMouse(true)
        dropdownClickCatcher:Hide()
    end
    return dropdownClickCatcher
end

local function CloseActiveDropdown()
    if activeDropdownMenu then
        if activeDropdownMenu.anchorBtn and activeDropdownMenu.anchorBtn.SetChevronOpen then
            activeDropdownMenu.anchorBtn:SetChevronOpen(false)
        end
        activeDropdownMenu.anchorBtn = nil
        activeDropdownMenu:Hide()
    end
    if activeRegionPopover then
        if activeRegionPopover.anchorBtn and activeRegionPopover.anchorBtn.SetChevronOpen then
            activeRegionPopover.anchorBtn:SetChevronOpen(false)
        end
        activeRegionPopover.anchorBtn = nil
        activeRegionPopover:Hide()
    end
    if activeFilterPopover then
        if activeFilterPopover.anchorBtn and activeFilterPopover.anchorBtn.SetChevronOpen then
            activeFilterPopover.anchorBtn:SetChevronOpen(false)
        end
        activeFilterPopover.anchorBtn = nil
        activeFilterPopover:Hide()
    end
    if dropdownClickCatcher then
        dropdownClickCatcher:Hide()
    end
end

EnsureDropdownClickCatcher():SetScript("OnClick", function()
    CloseActiveDropdown()
end)

local function ShowObsidianDropdown(anchorBtn, options, currentValue, onSelect, alignMode)
    EnsureDropdownClickCatcher()

    if not activeDropdownMenu then
        activeDropdownMenu = CreateFrame("Frame", "DynamicGroupDropdownMenu", UIParent, "BackdropTemplate")
        activeDropdownMenu:SetFrameStrata("FULLSCREEN_DIALOG")
        activeDropdownMenu:SetFrameLevel(100)
        activeDropdownMenu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        activeDropdownMenu.measureFs = activeDropdownMenu:CreateFontString(nil, "OVERLAY")
        SetSafeFont(activeDropdownMenu.measureFs, 11, "")
        activeDropdownMenu.measureFs:Hide()
        activeDropdownMenu.rows = {}
    end

    if activeDropdownMenu:IsShown() and activeDropdownMenu.anchorBtn == anchorBtn then
        CloseActiveDropdown()
        return
    end

    CloseActiveDropdown()

    local ar, ag, ab = GetSuiteAccent()
    activeDropdownMenu:SetBackdropColor(0.08, 0.09, 0.12, 0.98)
    activeDropdownMenu:SetBackdropBorderColor(ar, ag, ab, 0.90)
    activeDropdownMenu.anchorBtn = anchorBtn
    if anchorBtn.SetChevronOpen then
        anchorBtn:SetChevronOpen(true)
    end

    SetSafeFont(activeDropdownMenu.measureFs, 11, "")
    local maxTextWidth = 0
    for _, opt in ipairs(options) do
        activeDropdownMenu.measureFs:SetText(opt.label or "")
        local w = activeDropdownMenu.measureFs:GetStringWidth() or 0
        if w > maxTextWidth then maxTextWidth = w end
    end

    local minMenuW = (alignMode == "TOPLEFT") and 190 or 240
    local width = math.max(anchorBtn:GetWidth() or minMenuW, math.ceil(maxTextWidth) + 54, minMenuW)
    local rowHeight = 26
    local pad = 5

    for _, r in ipairs(activeDropdownMenu.rows) do
        r:Hide()
    end

    for i, opt in ipairs(options) do
        local row = activeDropdownMenu.rows[i]
        if not row then
            row = CreateFrame("Button", nil, activeDropdownMenu)
            row:SetHeight(rowHeight)

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(1, 1, 1, 0)

            row.check = row:CreateTexture(nil, "ARTWORK")
            row.check:SetSize(12, 12)
            row.check:SetPoint("LEFT", row, "LEFT", 10, 0)
            row.check:SetTexture(ICON_CHECK)
            DisableTexPixelSnap(row.check)

            row.text = row:CreateFontString(nil, "OVERLAY")
            SetSafeFont(row.text, 11, "")
            row.text:SetPoint("LEFT", row, "LEFT", 28, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", -10, 0)
            row.text:SetJustifyH("LEFT")
            row.text:SetWordWrap(false)

            row:SetScript("OnEnter", function(s)
                local r, g, b = GetSuiteAccent()
                s.bg:SetColorTexture(r, g, b, 0.16)
            end)
            row:SetScript("OnLeave", function(s)
                s.bg:SetColorTexture(1, 1, 1, 0)
            end)
            activeDropdownMenu.rows[i] = row
        end

        row:SetPoint("TOPLEFT", activeDropdownMenu, "TOPLEFT", pad, -pad - ((i - 1) * rowHeight))
        row:SetPoint("TOPRIGHT", activeDropdownMenu, "TOPRIGHT", -pad, -pad - ((i - 1) * rowHeight))
        SetSafeFont(row.text, 11, "")

        local isSelected = (opt.value == currentValue)
        if isSelected then
            row.check:SetVertexColor(ar, ag, ab, 1)
            row.check:Show()
            row.text:SetTextColor(ar, ag, ab, 1)
        else
            row.check:Hide()
            row.text:SetTextColor(0.90, 0.93, 0.97, 1)
        end
        row.text:SetText(opt.label or "")

        row:SetScript("OnClick", function()
            CloseActiveDropdown()
            if onSelect then onSelect(opt.value, opt.label) end
        end)
        row:Show()
    end

    activeDropdownMenu:SetSize(width, (#options * rowHeight) + (pad * 2))
    activeDropdownMenu:ClearAllPoints()
    if alignMode == "TOPLEFT" then
        activeDropdownMenu:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -2)
    else
        activeDropdownMenu:SetPoint("TOPRIGHT", anchorBtn, "BOTTOMRIGHT", 0, -3)
    end
    dropdownClickCatcher:Show()
    activeDropdownMenu:Show()
end

local function ShowRegionPopover(anchorBtn)
    EnsureDropdownClickCatcher()

    if not activeRegionPopover then
        local pop = CreateFrame("Frame", "DynamicGroupRegionPopover", UIParent, "BackdropTemplate")
        pop:SetFrameStrata("FULLSCREEN_DIALOG")
        pop:SetFrameLevel(100)
        pop:SetWidth(242)
        pop:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })

        pop.headerLabel = pop:CreateFontString(nil, "OVERLAY")
        SetSafeFont(pop.headerLabel, 11, "")
        pop.headerLabel:SetPoint("TOPLEFT", pop, "TOPLEFT", 10, -9)
        pop.headerLabel:SetText("Datacentre Regions")
        pop.headerLabel:SetTextColor(0.96, 0.98, 1.00, 1)

        local function CreateQuickHeaderBtn(textLabel, rightOffset, onClickFn)
            local qBtn = CreateFrame("Button", nil, pop, "BackdropTemplate")
            qBtn:SetSize(44, 18)
            qBtn:SetPoint("TOPRIGHT", pop, "TOPRIGHT", rightOffset, -6)
            qBtn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            qBtn:SetBackdropColor(0.10, 0.12, 0.16, 0.95)
            qBtn:SetBackdropBorderColor(0.20, 0.24, 0.32, 0.95)
            qBtn.txt = qBtn:CreateFontString(nil, "OVERLAY")
            SetSafeFont(qBtn.txt, 10, "")
            qBtn.txt:SetPoint("CENTER", 0, 0)
            qBtn.txt:SetText(textLabel)
            qBtn.txt:SetTextColor(0.84, 0.89, 0.95, 1)
            qBtn:SetScript("OnEnter", function(s)
                local r, g, b = GetSuiteAccent()
                s:SetBackdropBorderColor(r, g, b, 1)
                s.txt:SetTextColor(1, 1, 1, 1)
            end)
            qBtn:SetScript("OnLeave", function(s)
                s:SetBackdropBorderColor(0.20, 0.24, 0.32, 0.95)
                s.txt:SetTextColor(0.84, 0.89, 0.95, 1)
            end)
            qBtn:SetScript("OnClick", onClickFn)
            return qBtn
        end

        pop.noneBtn = CreateQuickHeaderBtn("None", -8, function()
            local db = EnsureDB()
            for _, rk in ipairs(REGION_ORDER) do
                db.enabledRegions[rk] = false
            end
            pop:RefreshRows()
            DynamicGroup:RefreshLFGResults()
            DynamicGroup:RefreshConfigUI()
            if _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
                pcall(_G.DynamicSuite.RefreshHeaderStatus)
            end
        end)

        pop.allBtn = CreateQuickHeaderBtn("All", -56, function()
            local db = EnsureDB()
            for _, rk in ipairs(REGION_ORDER) do
                db.enabledRegions[rk] = true
            end
            pop:RefreshRows()
            DynamicGroup:RefreshLFGResults()
            DynamicGroup:RefreshConfigUI()
            if _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
                pcall(_G.DynamicSuite.RefreshHeaderStatus)
            end
        end)

        pop.divider = pop:CreateTexture(nil, "ARTWORK")
        pop.divider:SetHeight(1)
        pop.divider:SetPoint("TOPLEFT", pop, "TOPLEFT", 6, -28)
        pop.divider:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -6, -28)
        pop.divider:SetColorTexture(0.16, 0.19, 0.25, 0.90)

        pop.rows = {}
        local rowH = 26
        for i, rKey in ipairs(REGION_ORDER) do
            local meta = REGION_META[rKey]
            local row = CreateFrame("Button", nil, pop)
            row:SetHeight(rowH)
            row:SetPoint("TOPLEFT", pop, "TOPLEFT", 5, -32 - ((i - 1) * rowH))
            row:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -5, -32 - ((i - 1) * rowH))

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(1, 1, 1, 0)

            row.check = row:CreateTexture(nil, "ARTWORK")
            row.check:SetSize(11, 11)
            row.check:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.check:SetTexture(ICON_CHECK)
            DisableTexPixelSnap(row.check)

            row.dot = row:CreateTexture(nil, "ARTWORK")
            row.dot:SetSize(6, 6)
            row.dot:SetPoint("LEFT", row, "LEFT", 10, 0)
            row.dot:SetTexture("Interface\\Buttons\\WHITE8x8")
            DisableTexPixelSnap(row.dot)

            row.badgeText = row:CreateFontString(nil, "OVERLAY")
            SetSafeFont(row.badgeText, 10, "OUTLINE")
            row.badgeText:SetPoint("LEFT", row, "LEFT", 26, 0)
            row.badgeText:SetWidth(48)
            row.badgeText:SetJustifyH("LEFT")

            row.titleText = row:CreateFontString(nil, "OVERLAY")
            SetSafeFont(row.titleText, 11, "")
            row.titleText:SetPoint("LEFT", row.badgeText, "RIGHT", 6, 0)
            row.titleText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            row.titleText:SetJustifyH("LEFT")
            row.titleText:SetWordWrap(false)

            row:SetScript("OnEnter", function(s)
                local rc = GetRegionColor(rKey)
                s.bg:SetColorTexture(rc.r, rc.g, rc.b, 0.16)
            end)
            row:SetScript("OnLeave", function(s)
                local isOn = (EnsureDB().enabledRegions[rKey] ~= false)
                local rc = GetRegionColor(rKey)
                if isOn then
                    s.bg:SetColorTexture(rc.r, rc.g, rc.b, 0.07)
                else
                    s.bg:SetColorTexture(1, 1, 1, 0)
                end
            end)

            row:SetScript("OnClick", function()
                local db = EnsureDB()
                db.enabledRegions[rKey] = not (db.enabledRegions[rKey] ~= false)
                pop:RefreshRows()
                DynamicGroup:RefreshLFGResults()
                DynamicGroup:RefreshConfigUI()
                if _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
                    pcall(_G.DynamicSuite.RefreshHeaderStatus)
                end
            end)

            pop.rows[i] = { frame = row, key = rKey, meta = meta }
        end

        pop:SetHeight(32 + (#REGION_ORDER * rowH) + 6)

        function pop:RefreshRows()
            local db = EnsureDB()
            local ar, ag, ab = GetSuiteAccent()
            self:SetBackdropColor(0.07, 0.08, 0.11, 0.98)
            self:SetBackdropBorderColor(ar, ag, ab, 0.92)
            SetSafeFont(self.headerLabel, 11, "")
            SetSafeFont(self.allBtn.txt, 10, "")
            SetSafeFont(self.noneBtn.txt, 10, "")

            for _, item in ipairs(self.rows) do
                local r = item.frame
                local rKey = item.key
                local m = item.meta
                local rc = GetRegionColor(rKey)
                local isOn = (db.enabledRegions[rKey] ~= false)

                SetSafeFont(r.badgeText, 10, "OUTLINE")
                SetSafeFont(r.titleText, 11, "")
                r.badgeText:SetText(FormatRegionTag(rKey, m.badge))
                r.titleText:SetText(m.pillLabel)

                if isOn then
                    r.check:SetVertexColor(rc.r, rc.g, rc.b, 1)
                    r.check:Show()
                    r.dot:Hide()
                    r.titleText:SetTextColor(0.96, 0.98, 1.00, 1)
                    r.bg:SetColorTexture(rc.r, rc.g, rc.b, 0.07)
                else
                    r.check:Hide()
                    r.dot:SetVertexColor(rc.r, rc.g, rc.b, 0.85)
                    r.dot:Show()
                    r.titleText:SetTextColor(0.54, 0.60, 0.68, 1)
                    r.bg:SetColorTexture(1, 1, 1, 0)
                end
            end
        end

        activeRegionPopover = pop
    end

    if activeRegionPopover:IsShown() and activeRegionPopover.anchorBtn == anchorBtn then
        CloseActiveDropdown()
        return
    end

    CloseActiveDropdown()

    activeRegionPopover.anchorBtn = anchorBtn
    if anchorBtn.SetChevronOpen then
        anchorBtn:SetChevronOpen(true)
    end
    activeRegionPopover:RefreshRows()
    activeRegionPopover:ClearAllPoints()
    activeRegionPopover:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -2)
    dropdownClickCatcher:Show()
    activeRegionPopover:Show()
end

local ROLE_ICON_TANK   = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:12:12:0:0:64:64:0:19:22:41|t"
local ROLE_ICON_HEALER = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:12:12:0:0:64:64:20:39:1:20|t"
local ROLE_ICON_DPS    = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:12:12:0:0:64:64:20:39:22:41|t"

local FILTER_POPOVER_OPTIONS = {
    { key = "needsTank",        badge = "[Open]",  color = { r = 0.204, g = 0.827, b = 0.600, hex = "FF34D399" }, label = ROLE_ICON_TANK .. " Tank Role Available" },
    { key = "needsHealer",      badge = "[Open]",  color = { r = 0.204, g = 0.827, b = 0.600, hex = "FF34D399" }, label = ROLE_ICON_HEALER .. " Healer Role Available" },
    { key = "needsDamage",      badge = "[Open]",  color = { r = 0.204, g = 0.827, b = 0.600, hex = "FF34D399" }, label = ROLE_ICON_DPS .. " DPS Role Available" },
    { key = "noDuplicateClass", badge = "[Class]", color = { r = 0.220, g = 0.741, b = 0.973, hex = "FF38BDF8" }, labelFn = function() local cName = UnitClass("player") or "Class"; return "No Duplicate " .. cName end },
    { key = "hasTank",          badge = "[Has]",   color = { r = 0.376, g = 0.647, b = 0.980, hex = "FF60A5FA" }, label = ROLE_ICON_TANK .. " Has Tank in Group" },
    { key = "hasHealer",        badge = "[Has]",   color = { r = 0.176, g = 0.831, b = 0.749, hex = "FF2DD4BF" }, label = ROLE_ICON_HEALER .. " Has Healer in Group" },
    { key = "hasLust",          badge = "[Lust]",  color = { r = 0.984, g = 0.573, b = 0.235, hex = "FFFB923C" }, label = "Has Bloodlust / Heroism" },
    { key = "hasCR",            badge = "[CR]",    color = { r = 0.753, g = 0.518, b = 0.988, hex = "FFC084FC" }, label = "Has Battle Rez (CR)" },
}

local function GetUtilityFilterSummary(db, compact)
    local count = CountActiveUtilityFilters(db)
    if count == 0 then
        return compact and "Filter: All" or "All Groups (No Filter Active)", 0
    end
    if count == 1 then
        if db.needsTank then return compact and "Filter: Tank" or "Tank Role Available", 1 end
        if db.needsHealer then return compact and "Filter: Heal" or "Healer Role Available", 1 end
        if db.needsDamage then return compact and "Filter: DPS" or "DPS Role Available", 1 end
        if db.noDuplicateClass then return compact and "Filter: NoDup" or ("No Duplicate " .. (UnitClass("player") or "Class")), 1 end
        if db.hasTank then return compact and "Filter: +Tank" or "Has Tank in Group", 1 end
        if db.hasHealer then return compact and "Filter: +Heal" or "Has Healer in Group", 1 end
        if db.hasLust or db.partyFitFilter == "NEEDS_LUST" then return compact and "Filter: Lust" or "Has Bloodlust / Heroism", 1 end
        if db.hasCR or db.partyFitFilter == "NEEDS_CR" then return compact and "Filter: CR" or "Has Battle Rez (CR)", 1 end
    end
    if compact then
        return string.format("Filter: %d", count), count
    end
    return string.format("%d Composition Filters Active", count), count
end

local function ShowFilterPopover(anchorBtn)
    EnsureDropdownClickCatcher()

    if not activeFilterPopover then
        local pop = CreateFrame("Frame", "DynamicGroupFilterPopover", UIParent, "BackdropTemplate")
        pop:SetFrameStrata("FULLSCREEN_DIALOG")
        pop:SetFrameLevel(100)
        pop:SetWidth(268)
        pop:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })

        pop.headerLabel = pop:CreateFontString(nil, "OVERLAY")
        SetSafeFont(pop.headerLabel, 11, "")
        pop.headerLabel:SetPoint("TOPLEFT", pop, "TOPLEFT", 10, -9)
        pop.headerLabel:SetText("Premade Group Filters")
        pop.headerLabel:SetTextColor(0.96, 0.98, 1.00, 1)

        local resetBtn = CreateFrame("Button", nil, pop, "BackdropTemplate")
        resetBtn:SetSize(48, 18)
        resetBtn:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -8, -6)
        resetBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        resetBtn:SetBackdropColor(0.10, 0.12, 0.16, 0.95)
        resetBtn:SetBackdropBorderColor(0.20, 0.24, 0.32, 0.95)
        resetBtn.txt = resetBtn:CreateFontString(nil, "OVERLAY")
        SetSafeFont(resetBtn.txt, 10, "")
        resetBtn.txt:SetPoint("CENTER", 0, 0)
        resetBtn.txt:SetText("Reset")
        resetBtn.txt:SetTextColor(0.84, 0.89, 0.95, 1)
        resetBtn:SetScript("OnEnter", function(s)
            local r, g, b = GetSuiteAccent()
            s:SetBackdropBorderColor(r, g, b, 1)
            s.txt:SetTextColor(1, 1, 1, 1)
        end)
        resetBtn:SetScript("OnLeave", function(s)
            s:SetBackdropBorderColor(0.20, 0.24, 0.32, 0.95)
            s.txt:SetTextColor(0.84, 0.89, 0.95, 1)
        end)
        resetBtn:SetScript("OnClick", function()
            local db = EnsureDB()
            for _, opt in ipairs(FILTER_POPOVER_OPTIONS) do
                db[opt.key] = false
            end
            SyncLegacyPartyFitFromFlags(db)
            PushFiltersToBlizzardAdvancedFilter(false)
            pop:RefreshRows()
            DynamicGroup:RefreshLFGResults()
            DynamicGroup:RefreshConfigUI()
            if _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
                pcall(_G.DynamicSuite.RefreshHeaderStatus)
            end
        end)
        pop.resetBtn = resetBtn

        pop.divider = pop:CreateTexture(nil, "ARTWORK")
        pop.divider:SetHeight(1)
        pop.divider:SetPoint("TOPLEFT", pop, "TOPLEFT", 6, -28)
        pop.divider:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -6, -28)
        pop.divider:SetColorTexture(0.16, 0.19, 0.25, 0.90)

        pop.rows = {}
        local rowH = 26
        for i, opt in ipairs(FILTER_POPOVER_OPTIONS) do
            local row = CreateFrame("Button", nil, pop)
            row:SetHeight(rowH)
            row:SetPoint("TOPLEFT", pop, "TOPLEFT", 5, -32 - ((i - 1) * rowH))
            row:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -5, -32 - ((i - 1) * rowH))

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(1, 1, 1, 0)

            row.check = row:CreateTexture(nil, "ARTWORK")
            row.check:SetSize(11, 11)
            row.check:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.check:SetTexture(ICON_CHECK)
            DisableTexPixelSnap(row.check)

            row.dot = row:CreateTexture(nil, "ARTWORK")
            row.dot:SetSize(6, 6)
            row.dot:SetPoint("LEFT", row, "LEFT", 10, 0)
            row.dot:SetTexture("Interface\\Buttons\\WHITE8x8")
            DisableTexPixelSnap(row.dot)

            row.badgeText = row:CreateFontString(nil, "OVERLAY")
            SetSafeFont(row.badgeText, 10, "OUTLINE")
            row.badgeText:SetPoint("LEFT", row, "LEFT", 26, 0)
            row.badgeText:SetWidth(48)
            row.badgeText:SetJustifyH("LEFT")

            row.titleText = row:CreateFontString(nil, "OVERLAY")
            SetSafeFont(row.titleText, 11, "")
            row.titleText:SetPoint("LEFT", row.badgeText, "RIGHT", 6, 0)
            row.titleText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            row.titleText:SetJustifyH("LEFT")
            row.titleText:SetWordWrap(false)

            row:SetScript("OnEnter", function(s)
                local col = opt.color
                s.bg:SetColorTexture(col.r, col.g, col.b, 0.16)
            end)
            row:SetScript("OnLeave", function(s)
                local isOn = (EnsureDB()[opt.key] == true)
                local col = opt.color
                if isOn then
                    s.bg:SetColorTexture(col.r, col.g, col.b, 0.07)
                else
                    s.bg:SetColorTexture(1, 1, 1, 0)
                end
            end)
            row:SetScript("OnClick", function()
                local db = EnsureDB()
                db[opt.key] = not (db[opt.key] == true)
                SyncLegacyPartyFitFromFlags(db)
                PushFiltersToBlizzardAdvancedFilter(false)
                pop:RefreshRows()
                DynamicGroup:RefreshLFGResults()
                DynamicGroup:RefreshConfigUI()
                if _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
                    pcall(_G.DynamicSuite.RefreshHeaderStatus)
                end
            end)

            pop.rows[i] = { frame = row, opt = opt }
        end

        pop:SetHeight(32 + (#FILTER_POPOVER_OPTIONS * rowH) + 6)

        function pop:RefreshRows()
            local db = EnsureDB()
            local ar, ag, ab = GetSuiteAccent()
            self:SetBackdropColor(0.07, 0.08, 0.11, 0.98)
            self:SetBackdropBorderColor(ar, ag, ab, 0.92)
            SetSafeFont(self.headerLabel, 11, "")
            SetSafeFont(self.resetBtn.txt, 10, "")

            for _, item in ipairs(self.rows) do
                local r = item.frame
                local opt = item.opt
                local col = opt.color
                local isOn = (db[opt.key] == true)
                local lbl = opt.labelFn and opt.labelFn() or opt.label

                SetSafeFont(r.badgeText, 10, "OUTLINE")
                SetSafeFont(r.titleText, 11, "")
                r.badgeText:SetText("|c" .. col.hex .. opt.badge .. "|r")
                r.titleText:SetText(lbl or "")

                if isOn then
                    r.check:SetVertexColor(col.r, col.g, col.b, 1)
                    r.check:Show()
                    r.dot:Hide()
                    r.titleText:SetTextColor(0.96, 0.98, 1.00, 1)
                    r.bg:SetColorTexture(col.r, col.g, col.b, 0.07)
                else
                    r.check:Hide()
                    r.dot:SetVertexColor(col.r, col.g, col.b, 0.85)
                    r.dot:Show()
                    r.titleText:SetTextColor(0.62, 0.68, 0.76, 1)
                    r.bg:SetColorTexture(1, 1, 1, 0)
                end
            end
        end

        activeFilterPopover = pop
    end

    if activeFilterPopover:IsShown() and activeFilterPopover.anchorBtn == anchorBtn then
        CloseActiveDropdown()
        return
    end

    CloseActiveDropdown()

    activeFilterPopover.anchorBtn = anchorBtn
    if anchorBtn.SetChevronOpen then
        anchorBtn:SetChevronOpen(true)
    end
    activeFilterPopover:RefreshRows()
    activeFilterPopover:ClearAllPoints()
    local anchorBottom = anchorBtn.GetBottom and anchorBtn:GetBottom() or 400
    if anchorBottom < 245 then
        activeFilterPopover:SetPoint("BOTTOMLEFT", anchorBtn, "TOPLEFT", 0, 2)
    else
        activeFilterPopover:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -2)
    end
    dropdownClickCatcher:Show()
    activeFilterPopover:Show()
end

function DynamicGroup:EnsureLFGMiniBar()
    if self.lfgMiniBar then return self.lfgMiniBar end
    if not _G.LFGListFrame or not _G.LFGListFrame.SearchPanel then return nil end

    local searchPanel = _G.LFGListFrame.SearchPanel
    local bar = CreateFrame("Frame", "DynamicGroupLFGMiniBar", searchPanel, "BackdropTemplate")
    bar:SetHeight(24)
    bar:SetPoint("BOTTOMLEFT", searchPanel, "TOPLEFT", 4, 2)
    bar:SetPoint("BOTTOMRIGHT", searchPanel, "TOPRIGHT", -4, 2)
    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bar:SetBackdropColor(0.06, 0.08, 0.12, 0.94)
    local ar, ag, ab = GetSuiteAccent()
    bar:SetBackdropBorderColor(ar, ag, ab, 0.45)

    bar:SetScript("OnHide", function()
        CloseActiveDropdown()
    end)

    local function CreateMiniPill(parent, width, point, rel, relPoint, xOff, hasChevron)
        local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        btn:SetSize(width, 18)
        btn:SetPoint(point, rel, relPoint, xOff, 0)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(0.08, 0.09, 0.12, 0.95)
        btn:SetBackdropBorderColor(0.15, 0.17, 0.21, 0.95)
        btn.label = btn:CreateFontString(nil, "OVERLAY")
        SetSafeFont(btn.label, 10, "")
        if hasChevron then
            btn.label:SetPoint("LEFT", btn, "LEFT", 5, 0)
            btn.chevron = btn:CreateTexture(nil, "ARTWORK")
            btn.chevron:SetSize(8, 8)
            btn.chevron:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
            btn.chevron:SetTexture(ICON_CHEVRON_DOWN)
            DisableTexPixelSnap(btn.chevron)
            btn.chevron:SetVertexColor(0.68, 0.74, 0.82, 1)
            function btn:SetChevronOpen(isOpen)
                self.isOpen = isOpen and true or false
                self.chevron:SetTexture(isOpen and ICON_CHEVRON_UP or ICON_CHEVRON_DOWN)
                DisableTexPixelSnap(self.chevron)
                local r, g, b = GetSuiteAccent()
                if isOpen then
                    self:SetBackdropBorderColor(r, g, b, 1)
                    self.chevron:SetVertexColor(r, g, b, 1)
                elseif self.RefreshFilterBtnStyle then
                    self:RefreshFilterBtnStyle()
                else
                    self:SetBackdropBorderColor(0.15, 0.17, 0.21, 0.95)
                    self.chevron:SetVertexColor(0.68, 0.74, 0.82, 1)
                end
            end
        else
            btn.label:SetPoint("CENTER", 0, 0)
        end
        btn:SetScript("OnEnter", function(s)
            local r, g, b = GetSuiteAccent()
            s:SetBackdropBorderColor(r, g, b, 1)
            if s.chevron then s.chevron:SetVertexColor(r, g, b, 1) end
        end)
        btn:SetScript("OnLeave", function(s)
            if _G.GameTooltip then _G.GameTooltip:Hide() end
            if s.isOpen then
                local r, g, b = GetSuiteAccent()
                s:SetBackdropBorderColor(r, g, b, 1)
                if s.chevron then s.chevron:SetVertexColor(r, g, b, 1) end
            elseif s.RefreshOneClickStyle then
                s:RefreshOneClickStyle()
            elseif s.RefreshFilterBtnStyle then
                s:RefreshFilterBtnStyle()
            else
                s:SetBackdropBorderColor(0.15, 0.17, 0.21, 0.95)
                if s.chevron then s.chevron:SetVertexColor(0.68, 0.74, 0.82, 1) end
            end
        end)
        return btn
    end

    -- 1. Region On-the-Fly Multi-Select Popover Button
    bar.regionBtn = CreateMiniPill(bar, 74, "LEFT", bar, "LEFT", 4, true)
    bar.regionBtn:HookScript("OnEnter", function(s)
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(s, "ANCHOR_TOP")
            _G.GameTooltip:ClearLines()
            _G.GameTooltip:AddLine("Premade LFG Datacentre Regions", 1, 1, 1)
            local db = EnsureDB()
            for _, rKey in ipairs(REGION_ORDER) do
                local m = REGION_META[rKey]
                local rc = GetRegionColor(rKey)
                local isOn = (db.enabledRegions[rKey] ~= false)
                local stateTxt = isOn and "|cFF34D399Active|r" or "|cFF64748BFiltered|r"
                _G.GameTooltip:AddDoubleLine(
                    "|c" .. rc.hex .. m.badge .. "|r " .. m.pillLabel,
                    stateTxt,
                    rc.r, rc.g, rc.b,
                    0.85, 0.90, 0.96
                )
            end
            _G.GameTooltip:AddLine(" ")
            _G.GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Open datacentre region filter popover.|r", 0.886, 0.910, 0.941)
            _G.GameTooltip:Show()
        end
    end)
    bar.regionBtn:SetScript("OnClick", function(s)
        if _G.GameTooltip then _G.GameTooltip:Hide() end
        ShowRegionPopover(s)
    end)

    -- 2. Minimum M+ Score On-the-Fly Dropdown Button
    bar.scoreBtn = CreateMiniPill(bar, 64, "LEFT", bar.regionBtn, "RIGHT", 3, true)
    local scoreMenuOptions = {
        { value = 0,    label = "Any Score (0+)" },
        { value = 1500, label = "1500+ M+ Score" },
        { value = 2000, label = "2000+ M+ Score" },
        { value = 2500, label = "2500+ M+ Score" },
        { value = 2800, label = "2800+ M+ Score" },
        { value = 3000, label = "3000+ M+ Score" },
    }
    bar.scoreBtn:HookScript("OnEnter", function(s)
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(s, "ANCHOR_TOP")
            _G.GameTooltip:ClearLines()
            _G.GameTooltip:AddLine("Minimum Leader M+ Score", 1, 1, 1)
            _G.GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Select a minimum Mythic+ rating threshold.|r", 0.886, 0.910, 0.941, true)
            _G.GameTooltip:Show()
        end
    end)
    bar.scoreBtn:SetScript("OnClick", function(s)
        if _G.GameTooltip then _G.GameTooltip:Hide() end
        local db = EnsureDB()
        ShowObsidianDropdown(s, scoreMenuOptions, tonumber(db.minLeaderScore) or 0, function(val)
            db.minLeaderScore = val
            DynamicGroup:RefreshLFGResults()
            DynamicGroup:RefreshConfigUI()
        end, "TOPLEFT")
    end)

    -- 3. Multi-Toggle Composition & Blizzard Filter Popover Button
    bar.roleBtn = CreateMiniPill(bar, 74, "LEFT", bar.scoreBtn, "RIGHT", 3, true)
    function bar.roleBtn:RefreshFilterBtnStyle()
        local db = EnsureDB()
        local labelTxt, activeFilters = GetUtilityFilterSummary(db, true)
        if self.label then self.label:SetText(labelTxt) end
        local r, g, b = GetSuiteAccent()
        if activeFilters > 0 then
            self:SetBackdropBorderColor(r, g, b, 0.80)
            if self.chevron then self.chevron:SetVertexColor(r, g, b, 1) end
        else
            self:SetBackdropBorderColor(0.15, 0.17, 0.21, 0.95)
            if self.chevron then self.chevron:SetVertexColor(0.68, 0.74, 0.82, 1) end
        end
    end
    bar.roleBtn:HookScript("OnEnter", function(s)
        if _G.GameTooltip then
            local db = EnsureDB()
            _G.GameTooltip:SetOwner(s, "ANCHOR_TOP")
            _G.GameTooltip:ClearLines()
            _G.GameTooltip:AddLine("Premade Group Filters", 1, 1, 1)
            local anyShown = false
            for _, opt in ipairs(FILTER_POPOVER_OPTIONS) do
                if db[opt.key] == true then
                    anyShown = true
                    local lbl = opt.labelFn and opt.labelFn() or opt.label
                    _G.GameTooltip:AddDoubleLine(lbl, "|cFF34D399Active|r", 0.886, 0.910, 0.941, 0.204, 0.827, 0.600)
                end
            end
            if not anyShown then
                _G.GameTooltip:AddLine("Showing all group compositions and difficulties.", 0.58, 0.64, 0.72)
            end
            _G.GameTooltip:AddLine(" ")
            _G.GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Open multi-toggle group filter menu.|r", 0.886, 0.910, 0.941, true)
            _G.GameTooltip:Show()
        end
    end)
    bar.roleBtn:SetScript("OnClick", function(s)
        if _G.GameTooltip then _G.GameTooltip:Hide() end
        ShowFilterPopover(s)
    end)

    -- 4. Dedicated 1-Click Sign-Up Toggle Pill ([ 1-Click: ON ] / [ 1-Click: OFF ])
    bar.oneClickBtn = CreateMiniPill(bar, 72, "LEFT", bar.roleBtn, "RIGHT", 3, false)
    function bar.oneClickBtn:RefreshOneClickStyle()
        local isOn = EnsureDB().oneClickSignUp and true or false
        if isOn then
            self:SetBackdropColor(0.06, 0.16, 0.12, 0.96)
            self:SetBackdropBorderColor(0.204, 0.827, 0.600, 0.85)
            self.label:SetText("|cFF34D3991-Click: ON|r")
        else
            self:SetBackdropColor(0.08, 0.09, 0.12, 0.95)
            self:SetBackdropBorderColor(0.15, 0.17, 0.21, 0.95)
            self.label:SetText("|cFF64748B1-Click: OFF|r")
        end
    end
    bar.oneClickBtn:HookScript("OnEnter", function(s)
        if _G.GameTooltip then
            local r, g, b = GetSuiteAccent()
            local accHex = string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
            _G.GameTooltip:SetOwner(s, "ANCHOR_TOP")
            _G.GameTooltip:ClearLines()
            _G.GameTooltip:AddLine("One-Click Sign-Up", 1, 1, 1)
            _G.GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Toggle instant 1-Click Sign-Up ON or OFF.|r", 0.886, 0.910, 0.941, true)
            _G.GameTooltip:AddLine("|cFF" .. accHex .. "Hold Shift / Alt:|r |cFFE2E8F0Manually customise role & note when clicking a group.|r", 0.886, 0.910, 0.941, true)
            _G.GameTooltip:Show()
        end
    end)
    bar.oneClickBtn:SetScript("OnClick", function()
        CloseActiveDropdown()
        local db = EnsureDB()
        db.oneClickSignUp = not (db.oneClickSignUp and true or false)
        DynamicGroup:UpdateLFGMiniBar()
        DynamicGroup:RefreshConfigUI()
        if _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
            pcall(_G.DynamicSuite.RefreshHeaderStatus)
        end
    end)

    -- 5. Compact 22x18 Settings Cog Button on Far Right
    local cogBtn = CreateFrame("Button", nil, bar, "BackdropTemplate")
    cogBtn:SetSize(22, 18)
    cogBtn:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    cogBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    cogBtn:SetBackdropColor(0.08, 0.09, 0.12, 0.95)
    cogBtn:SetBackdropBorderColor(0.15, 0.17, 0.21, 0.95)
    cogBtn.icon = cogBtn:CreateTexture(nil, "ARTWORK")
    cogBtn.icon:SetSize(12, 12)
    cogBtn.icon:SetPoint("CENTER", 0, 0)
    cogBtn.icon:SetTexture(ICON_COG)
    DisableTexPixelSnap(cogBtn.icon)
    cogBtn.icon:SetVertexColor(ar, ag, ab, 0.92)
    cogBtn:SetScript("OnEnter", function(s)
        local r, g, b = GetSuiteAccent()
        s:SetBackdropBorderColor(r, g, b, 1)
        s.icon:SetVertexColor(r, g, b, 1)
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(s, "ANCHOR_TOP")
            _G.GameTooltip:ClearLines()
            _G.GameTooltip:AddLine("DynamicGroup Settings (/dgroup)", 1, 1, 1)
            _G.GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Open the DynamicGroup configuration workspace.|r", 0.886, 0.910, 0.941, true)
            _G.GameTooltip:Show()
        end
    end)
    cogBtn:SetScript("OnLeave", function(s)
        if _G.GameTooltip then _G.GameTooltip:Hide() end
        local r, g, b = GetSuiteAccent()
        s:SetBackdropBorderColor(0.15, 0.17, 0.21, 0.95)
        s.icon:SetVertexColor(r, g, b, 0.92)
    end)
    cogBtn:SetScript("OnClick", function()
        CloseActiveDropdown()
        DynamicGroup:OpenWorkspace()
    end)
    bar.cogBtn = cogBtn
    bar.openBtn = cogBtn

    self.lfgMiniBar = bar
    self:EnsurePortalBar()
    self:UpdateLFGMiniBar()
    return bar
end

local function SetPortalTileActiveBorder(tile, isActive, ar, ag, ab)
    if not tile or not tile.activeEdges then return end
    for _, edge in ipairs(tile.activeEdges) do
        if isActive then
            -- Blaze Orange #F97316 highlight for active filtered dungeons
            edge:SetColorTexture(0.976, 0.451, 0.086, 1.0)
            edge:Show()
        else
            edge:Hide()
        end
    end
end

local function PopulateDungeonTileTooltip(tile)
    if not _G.GameTooltip or not tile or not tile.slotData then return end
    local slot = tile.slotData
    local db = EnsureDB()
    local isFiltered = (db.filteredDungeons[slot.code] == true) or (slot.mapID and db.filteredDungeons[slot.mapID] == true)
    local bestLevel, bestScore, isTimed = GetPlayerBestForDungeon(slot.mapID)
    local _, _, _, accHex = GetSuiteAccent()
    if type(accHex) ~= "string" or accHex == "" then
        accHex = "FF38BDF8"
    elseif #accHex == 6 then
        accHex = "FF" .. accHex
    end

    _G.GameTooltip:SetOwner(tile, "ANCHOR_TOP")
    _G.GameTooltip:ClearLines()
    _G.GameTooltip:AddDoubleLine(slot.name or "Season Dungeon", "[" .. tostring(slot.code or "M+") .. "]", 1, 1, 1, 0.58, 0.66, 0.78)

    if bestLevel > 0 then
        local timedSuffix = isTimed and " |cFF22C55E(Timed)|r" or " |cFFFACC15(Over Time)|r"
        local scorePart = (bestScore > 0) and ("  |cFF94A3B8Score: " .. tostring(bestScore) .. "|r") or ""
        _G.GameTooltip:AddLine("Season Best: |cFF34D399+" .. tostring(bestLevel) .. "|r" .. timedSuffix .. scorePart, 0.886, 0.910, 0.941)
    else
        _G.GameTooltip:AddLine("Season Best: |cFF94A3B8No timed key recorded yet|r", 0.886, 0.910, 0.941)
    end

    if slot.spellKnown then
        local st, dur, enabled = SafeGetSpellCooldown(slot.spellID)
        if enabled and st > 0 and dur > 1.5 and _G.GetTime then
            local rem = math.max(0, (st + dur) - _G.GetTime())
            local mins = math.floor(rem / 60)
            local secs = math.floor(rem % 60)
            _G.GameTooltip:AddLine(string.format("Dungeon Teleport: |cFFFACC15Cooldown (%dm %02ds)|r", mins, secs), 0.886, 0.910, 0.941)
        else
            _G.GameTooltip:AddLine("Dungeon Teleport: |cFF22C55EReady|r", 0.886, 0.910, 0.941)
        end
    else
        _G.GameTooltip:AddLine("Dungeon Teleport: |cFF94A3B8Not learned yet (complete +10 in time)|r", 0.886, 0.910, 0.941)
    end

    _G.GameTooltip:AddDoubleLine(
        "LFG Dungeon Filter:",
        isFiltered and "|cFFF97316Filtered (Shown)|r" or "|cFF94A3B8Unfiltered|r",
        0.64, 0.70, 0.78,
        1, 1, 1
    )

    _G.GameTooltip:AddLine(" ")
    _G.GameTooltip:AddLine("|cFF22C55ELeft-Click:|r |cFFE2E8F0Toggle LFG filter for this dungeon.|r", 0.886, 0.910, 0.941)
    _G.GameTooltip:AddLine("|c" .. accHex .. "Shift + Left-Click:|r |cFFE2E8F0Filter exclusively to this dungeon.|r", 0.886, 0.910, 0.941)
    if slot.spellKnown then
        _G.GameTooltip:AddLine("|cFFF97316Right-Click:|r |cFFE2E8F0Cast Dungeon Teleport.|r", 0.886, 0.910, 0.941)
    else
        _G.GameTooltip:AddLine("|cFF64748BRight-Click:|r |cFF94A3B8Not learned yet (complete +10 in time).|r", 0.886, 0.910, 0.941)
    end
    _G.GameTooltip:Show()
end

function DynamicGroup:EnsurePortalBar()
    if self.portalBar then return self.portalBar end
    local bar = self.lfgMiniBar
    if not bar or not _G.LFGListFrame or not _G.LFGListFrame.SearchPanel then return nil end
    if InCombatLockdown and InCombatLockdown() then
        self.pendingPortalBarUpdate = true
        return nil
    end

    local searchPanel = _G.LFGListFrame.SearchPanel
    local pbar = CreateFrame("Frame", "DynamicGroupPortalBar", searchPanel, "BackdropTemplate")
    pbar:SetFrameStrata("HIGH")
    pbar:SetFrameLevel((bar:GetFrameLevel() or 20) + 2)
    pbar:SetHeight(32)
    pbar:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 2)
    pbar:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 2)
    pbar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    pbar:SetBackdropColor(0.043, 0.051, 0.071, 0.96) -- Dark Obsidian #0B0D12
    local ar, ag, ab = GetSuiteAccent()
    pbar:SetBackdropBorderColor(ar, ag, ab, 0.45)

    -- Left Pill: Owned Keystone
    local function ResolveOwnedKeystoneTeleport(kMapID, kCode, kName)
        if not kMapID and not kCode then return nil, false end
        local slots = GetSeasonDungeonSlots(false)
        for _, slot in ipairs(slots or {}) do
            if (kMapID and slot.mapID == kMapID) or (kCode and slot.code == kCode) then
                return slot.spellID, slot.spellKnown and true or false
            end
        end
        return ResolveTeleportSpellForDungeon(kMapID, kCode, kName, nil)
    end

    local keyBtn = CreateFrame("Button", "DynamicGroupPortalKeyBtn", pbar, "SecureActionButtonTemplate,BackdropTemplate")
    keyBtn:SetSize(82, 24)
    keyBtn:SetPoint("LEFT", pbar, "LEFT", 4, 0)
    keyBtn:RegisterForClicks("AnyUp", "AnyDown")
    keyBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    keyBtn:SetBackdropColor(0.078, 0.090, 0.122, 0.96)
    keyBtn:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95)
    keyBtn.cooldown = CreateFrame("Cooldown", "DynamicGroupPortalKeyBtnCD", keyBtn, "CooldownFrameTemplate")
    keyBtn.cooldown:SetPoint("TOPLEFT", keyBtn, "TOPLEFT", 1, -1)
    keyBtn.cooldown:SetPoint("BOTTOMRIGHT", keyBtn, "BOTTOMRIGHT", -1, 1)
    if keyBtn.cooldown.SetDrawEdge then keyBtn.cooldown:SetDrawEdge(false) end
    keyBtn.label = keyBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(keyBtn.label, 9, "")
    keyBtn.label:SetPoint("LEFT", keyBtn, "LEFT", 4, 0)
    keyBtn.label:SetPoint("RIGHT", keyBtn, "RIGHT", -4, 0)
    keyBtn.label:SetJustifyH("CENTER")
    keyBtn.label:SetWordWrap(false)
    keyBtn:SetScript("OnEnter", function(s)
        local r, g, b = GetSuiteAccent()
        s:SetBackdropBorderColor(r, g, b, 1)
        if _G.GameTooltip then
            local kMapID, kLvl, kCode, kName = GetOwnedKeystoneInfo()
            _G.GameTooltip:SetOwner(s, "ANCHOR_TOP")
            _G.GameTooltip:ClearLines()
            _G.GameTooltip:AddLine("Your Mythic+ Keystone", 1, 1, 1)
            if kMapID and kLvl > 0 and kName then
                _G.GameTooltip:AddLine(string.format("+%d %s [%s]", kLvl, kName, kCode or "M+"), r, g, b)
                local bestLevel, bestScore, isTimed = GetPlayerBestForDungeon(kMapID)
                if bestLevel > 0 then
                    local timedSuffix = isTimed and " |cFF22C55E(Timed)|r" or " |cFFFACC15(Over Time)|r"
                    local scorePart = (bestScore > 0) and ("  |cFF94A3B8Score: " .. tostring(bestScore) .. "|r") or ""
                    _G.GameTooltip:AddLine("Season Best: |cFF34D399+" .. tostring(bestLevel) .. "|r" .. timedSuffix .. scorePart, 0.886, 0.910, 0.941)
                else
                    _G.GameTooltip:AddLine("Season Best: |cFF94A3B8No timed key recorded yet|r", 0.886, 0.910, 0.941)
                end

                local kSpellID, kSpellKnown = ResolveOwnedKeystoneTeleport(kMapID, kCode, kName)
                if kSpellKnown and kSpellID then
                    local st, dur, enabled = SafeGetSpellCooldown(kSpellID)
                    if enabled and st > 0 and dur > 1.5 and _G.GetTime then
                        local rem = math.max(0, (st + dur) - _G.GetTime())
                        local mins = math.floor(rem / 60)
                        local secs = math.floor(rem % 60)
                        _G.GameTooltip:AddLine(string.format("Dungeon Teleport: |cFFFACC15Cooldown (%dm %02ds)|r", mins, secs), 0.886, 0.910, 0.941)
                    else
                        _G.GameTooltip:AddLine("Dungeon Teleport: |cFF22C55EReady|r", 0.886, 0.910, 0.941)
                    end
                else
                    _G.GameTooltip:AddLine("Dungeon Teleport: |cFF94A3B8Not learned yet (complete +10 in time)|r", 0.886, 0.910, 0.941)
                end

                _G.GameTooltip:AddLine(" ")
                _G.GameTooltip:AddLine("|cFF22C55ELeft-Click:|r |cFFE2E8F0Filter Premade Groups to your keystone dungeon.|r", 0.886, 0.910, 0.941, true)
                if kSpellKnown and kSpellID then
                    _G.GameTooltip:AddLine("|cFFF97316Right-Click:|r |cFFE2E8F0Cast Dungeon Teleport.|r", 0.886, 0.910, 0.941, true)
                else
                    _G.GameTooltip:AddLine("|cFF64748BRight-Click:|r |cFF94A3B8Cast Dungeon Teleport (not learned yet).|r", 0.886, 0.910, 0.941, true)
                end
            else
                _G.GameTooltip:AddLine("No Mythic+ keystone found in your bags.", 0.58, 0.64, 0.72)
            end
            _G.GameTooltip:Show()
        end
    end)
    keyBtn:SetScript("OnLeave", function(s)
        if _G.GameTooltip then _G.GameTooltip:Hide() end
        if DynamicGroup.UpdatePortalBarVisuals then DynamicGroup:UpdatePortalBarVisuals() end
    end)
    keyBtn:SetScript("PostClick", function(_, button, down)
        local useKeyDown = (type(_G.GetCVarBool) == "function" and _G.GetCVarBool("ActionButtonUseKeyDown")) and true or false
        if (down == true) ~= useKeyDown then return end
        if button ~= "LeftButton" then return end
        local kMapID, kLvl, kCode = GetOwnedKeystoneInfo()
        if not kCode then
            PrintMsg("No Mythic+ keystone found in your bags.")
            return
        end
        local db = EnsureDB()
        local onlyThis = (db.filteredDungeons[kCode] == true)
        if onlyThis then
            for k, v in pairs(db.filteredDungeons) do
                if v and k ~= kCode then
                    onlyThis = false
                    break
                end
            end
        end
        wipe(db.filteredDungeons)
        if not onlyThis then
            db.filteredDungeons[kCode] = true
        end
        PushFiltersToBlizzardAdvancedFilter(true)
        DynamicGroup:RefreshLFGResults()
    end)
    pbar.ResolveOwnedKeystoneTeleport = ResolveOwnedKeystoneTeleport
    pbar.keyBtn = keyBtn

    -- Right Quick "All" Clear Button
    local allBtn = CreateFrame("Button", nil, pbar, "BackdropTemplate")
    allBtn:SetSize(26, 24)
    allBtn:SetPoint("RIGHT", pbar, "RIGHT", -4, 0)
    allBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    allBtn:SetBackdropColor(0.078, 0.090, 0.122, 0.96)
    allBtn:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95)
    allBtn.label = allBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(allBtn.label, 9, "")
    allBtn.label:SetPoint("CENTER", 0, 0)
    allBtn.label:SetText("All")
    allBtn:SetScript("OnEnter", function(s)
        local r, g, b = GetSuiteAccent()
        s:SetBackdropBorderColor(r, g, b, 1)
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(s, "ANCHOR_TOP")
            _G.GameTooltip:ClearLines()
            _G.GameTooltip:AddLine("All Season Dungeons", 1, 1, 1)
            _G.GameTooltip:AddLine("|cFF22C55ELeft-Click:|r |cFFE2E8F0Clear active dungeon filters and show all dungeons.|r", 0.886, 0.910, 0.941, true)
            _G.GameTooltip:Show()
        end
    end)
    allBtn:SetScript("OnLeave", function()
        if _G.GameTooltip then _G.GameTooltip:Hide() end
        if DynamicGroup.UpdatePortalBarVisuals then DynamicGroup:UpdatePortalBarVisuals() end
    end)
    allBtn:SetScript("OnClick", function()
        local db = EnsureDB()
        wipe(db.filteredDungeons)
        PushFiltersToBlizzardAdvancedFilter(true)
        DynamicGroup:RefreshLFGResults()
    end)
    pbar.allBtn = allBtn

    -- 8 SecureActionButtonTemplate Season Dungeon Tiles
    pbar.tiles = {}
    for i = 1, 8 do
        local tile = CreateFrame("Button", "DynamicGroupPortalTile" .. i, pbar, "SecureActionButtonTemplate,BackdropTemplate")
        tile:SetSize(23, 26)
        tile:RegisterForClicks("AnyUp", "AnyDown")
        tile:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        tile:SetBackdropColor(0.06, 0.07, 0.10, 0.96)
        tile:SetBackdropBorderColor(0.15, 0.18, 0.24, 0.95)

        tile.icon = tile:CreateTexture(nil, "ARTWORK")
        tile.icon:SetPoint("TOPLEFT", tile, "TOPLEFT", 2, -2)
        tile.icon:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -2, 2)
        tile.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        DisableTexPixelSnap(tile.icon)

        tile.shade = tile:CreateTexture(nil, "ARTWORK", nil, 1)
        tile.shade:SetAllPoints(tile.icon)
        tile.shade:SetColorTexture(0, 0, 0, 0.34)

        tile.cooldown = CreateFrame("Cooldown", "DynamicGroupPortalTileCD" .. i, tile, "CooldownFrameTemplate")
        tile.cooldown:SetAllPoints(tile.icon)
        if tile.cooldown.SetDrawEdge then tile.cooldown:SetDrawEdge(false) end

        tile.codeText = tile:CreateFontString(nil, "OVERLAY")
        SetSafeFont(tile.codeText, 8, "OUTLINE")
        tile.codeText:SetPoint("TOP", tile, "TOP", 0, -2)
        tile.codeText:SetTextColor(0.96, 0.98, 1.00, 1)

        tile.bestText = tile:CreateFontString(nil, "OVERLAY")
        SetSafeFont(tile.bestText, 8, "OUTLINE")
        tile.bestText:SetPoint("BOTTOM", tile, "BOTTOM", 0, 2)

        -- 2px Blaze Orange Active Filter Border Edges
        local edges = {}
        local topE = tile:CreateTexture(nil, "OVERLAY")
        topE:SetHeight(2); topE:SetPoint("TOPLEFT", tile, "TOPLEFT", 0, 0); topE:SetPoint("TOPRIGHT", tile, "TOPRIGHT", 0, 0); topE:Hide()
        local botE = tile:CreateTexture(nil, "OVERLAY")
        botE:SetHeight(2); botE:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 0, 0); botE:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", 0, 0); botE:Hide()
        local leftE = tile:CreateTexture(nil, "OVERLAY")
        leftE:SetWidth(2); leftE:SetPoint("TOPLEFT", tile, "TOPLEFT", 0, -2); leftE:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 0, 2); leftE:Hide()
        local rightE = tile:CreateTexture(nil, "OVERLAY")
        rightE:SetWidth(2); rightE:SetPoint("TOPRIGHT", tile, "TOPRIGHT", 0, -2); rightE:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", 0, 2); rightE:Hide()
        edges[1], edges[2], edges[3], edges[4] = topE, botE, leftE, rightE
        tile.activeEdges = edges

        tile:SetScript("OnEnter", function(s)
            local r, g, b = GetSuiteAccent()
            s:SetBackdropBorderColor(r, g, b, 1)
            PopulateDungeonTileTooltip(s)
        end)
        tile:SetScript("OnLeave", function(s)
            if _G.GameTooltip then _G.GameTooltip:Hide() end
            s:SetBackdropBorderColor(0.15, 0.18, 0.24, 0.95)
        end)

        tile:SetScript("PostClick", function(selfTile, button, down)
            local useKeyDown = (type(_G.GetCVarBool) == "function" and _G.GetCVarBool("ActionButtonUseKeyDown")) and true or false
            local isDown = (down == true)
            if isDown ~= useKeyDown then return end

            if button ~= "LeftButton" or not selfTile.dungeonCode then return end

            local db = EnsureDB()
            if IsShiftKeyDown and IsShiftKeyDown() then
                local alreadySolo = (db.filteredDungeons[selfTile.dungeonCode] == true)
                if alreadySolo then
                    for k, v in pairs(db.filteredDungeons) do
                        if v and k ~= selfTile.dungeonCode then alreadySolo = false; break end
                    end
                end
                wipe(db.filteredDungeons)
                if not alreadySolo then
                    db.filteredDungeons[selfTile.dungeonCode] = true
                end
            else
                if db.filteredDungeons[selfTile.dungeonCode] then
                    db.filteredDungeons[selfTile.dungeonCode] = nil
                else
                    db.filteredDungeons[selfTile.dungeonCode] = true
                end
            end

            PushFiltersToBlizzardAdvancedFilter(true)
            DynamicGroup:RefreshLFGResults()
            if _G.GameTooltip and _G.GameTooltip:IsOwned(selfTile) then
                PopulateDungeonTileTooltip(selfTile)
            end
        end)

        pbar.tiles[i] = tile
    end

    local function LayoutPortalTiles()
        if InCombatLockdown and InCombatLockdown() then
            DynamicGroup.pendingPortalBarUpdate = true
            return
        end
        local totalW = pbar:GetWidth() or 0
        if totalW < 150 then
            totalW = (bar:GetWidth() and bar:GetWidth() > 150) and bar:GetWidth() or 326
        end
        local keyW = keyBtn:GetWidth() or 82
        local allW = allBtn:GetWidth() or 26
        local availW = totalW - 4 - keyW - 4 - 4 - allW - 4
        local gap = 2
        local tileW = math.max(18, math.floor((availW - (gap * 7)) / 8))
        local rowW = (tileW * 8) + (gap * 7)
        local startOffset = math.max(4, math.floor((availW - rowW) * 0.5) + 4)

        for idx = 1, 8 do
            local tile = pbar.tiles[idx]
            tile:ClearAllPoints()
            tile:SetSize(tileW, 26)
            if idx == 1 then
                tile:SetPoint("LEFT", keyBtn, "RIGHT", startOffset, 0)
            else
                tile:SetPoint("LEFT", pbar.tiles[idx - 1], "RIGHT", gap, 0)
            end
        end
    end
    pbar.LayoutPortalTiles = LayoutPortalTiles
    pbar:SetScript("OnSizeChanged", LayoutPortalTiles)
    LayoutPortalTiles()

    self.portalBar = pbar
    self:UpdatePortalBar()
    return pbar
end

function DynamicGroup:UpdatePortalBarVisuals()
    local pbar = self.portalBar
    if not pbar then return end
    local db = EnsureDB()
    local ar, ag, ab, accHex = GetSuiteAccent()
    pbar:SetBackdropBorderColor(ar, ag, ab, 0.45)

    local slots = GetSeasonDungeonSlots(false)
    local hasAnyFilter = HasActiveDungeonFilters(db)

    if pbar.keyBtn and pbar.keyBtn.label then
        local kMapID, kLvl, kCode, kName = GetOwnedKeystoneInfo()
        if kMapID and kLvl > 0 and kCode then
            pbar.keyBtn.label:SetText("|c" .. accHex .. "Key:|r |cFFFFFFFF+" .. tostring(kLvl) .. " " .. tostring(kCode) .. "|r")
            local isKeyFiltered = (db.filteredDungeons[kCode] == true)
            if isKeyFiltered then
                pbar.keyBtn:SetBackdropBorderColor(0.976, 0.451, 0.086, 1.0)
            else
                pbar.keyBtn:SetBackdropBorderColor(ar, ag, ab, 0.65)
            end
            local kSpellID, kSpellKnown = nil, false
            if pbar.ResolveOwnedKeystoneTeleport then
                kSpellID, kSpellKnown = pbar.ResolveOwnedKeystoneTeleport(kMapID, kCode, kName)
            end
            if pbar.keyBtn.cooldown and pbar.keyBtn.cooldown.SetCooldown then
                if kSpellKnown and kSpellID then
                    local st, dur, enabled = SafeGetSpellCooldown(kSpellID)
                    if enabled and st > 0 and dur > 1.5 then
                        pcall(pbar.keyBtn.cooldown.SetCooldown, pbar.keyBtn.cooldown, st, dur)
                    elseif pbar.keyBtn.cooldown.Clear then
                        pcall(pbar.keyBtn.cooldown.Clear, pbar.keyBtn.cooldown)
                    else
                        pcall(pbar.keyBtn.cooldown.SetCooldown, pbar.keyBtn.cooldown, 0, 0)
                    end
                elseif pbar.keyBtn.cooldown.Clear then
                    pcall(pbar.keyBtn.cooldown.Clear, pbar.keyBtn.cooldown)
                else
                    pcall(pbar.keyBtn.cooldown.SetCooldown, pbar.keyBtn.cooldown, 0, 0)
                end
            end
        else
            pbar.keyBtn.label:SetText("|cFF64748BKey: None|r")
            pbar.keyBtn:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95)
            if pbar.keyBtn.cooldown then
                if pbar.keyBtn.cooldown.Clear then
                    pcall(pbar.keyBtn.cooldown.Clear, pbar.keyBtn.cooldown)
                elseif pbar.keyBtn.cooldown.SetCooldown then
                    pcall(pbar.keyBtn.cooldown.SetCooldown, pbar.keyBtn.cooldown, 0, 0)
                end
            end
        end
    end

    if pbar.allBtn and pbar.allBtn.label then
        if hasAnyFilter then
            pbar.allBtn:SetBackdropColor(0.078, 0.090, 0.122, 0.96)
            pbar.allBtn:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95)
            pbar.allBtn.label:SetTextColor(0.68, 0.74, 0.82, 1)
        else
            pbar.allBtn:SetBackdropColor(ar * 0.18, ag * 0.18, ab * 0.18, 0.96)
            pbar.allBtn:SetBackdropBorderColor(ar, ag, ab, 0.85)
            pbar.allBtn.label:SetTextColor(1, 1, 1, 1)
        end
    end

    for idx = 1, 8 do
        local tile = pbar.tiles[idx]
        local slot = slots[idx]
        if tile and slot then
            tile.slotData = slot
            tile.dungeonCode = slot.code
            tile.spellKnown = slot.spellKnown and true or false

            if tile.icon then
                tile.icon:SetTexture(slot.icon or 136095)
                if tile.icon.SetDesaturated then
                    tile.icon:SetDesaturated(not slot.spellKnown)
                end
                tile.icon:SetVertexColor(slot.spellKnown and 1 or 0.72, slot.spellKnown and 1 or 0.72, slot.spellKnown and 1 or 0.72, 1)
            end

            if tile.codeText then
                SetSafeFont(tile.codeText, 8, "OUTLINE")
                tile.codeText:SetText(slot.code or "M+")
            end

            local bestLevel, _, isTimed = GetPlayerBestForDungeon(slot.mapID)
            if tile.bestText then
                SetSafeFont(tile.bestText, 8, "OUTLINE")
                if bestLevel > 0 then
                    tile.bestText:SetText("+" .. tostring(bestLevel))
                    if isTimed then
                        tile.bestText:SetTextColor(0.204, 0.827, 0.600, 1)
                    else
                        tile.bestText:SetTextColor(0.980, 0.800, 0.082, 1)
                    end
                else
                    tile.bestText:SetText("--")
                    tile.bestText:SetTextColor(0.62, 0.68, 0.76, 1)
                end
            end

            local st, dur, enabled = SafeGetSpellCooldown(slot.spellID)
            if tile.cooldown and tile.cooldown.SetCooldown then
                if slot.spellKnown and enabled and st > 0 and dur > 1.5 then
                    pcall(tile.cooldown.SetCooldown, tile.cooldown, st, dur)
                elseif tile.cooldown.Clear then
                    pcall(tile.cooldown.Clear, tile.cooldown)
                else
                    pcall(tile.cooldown.SetCooldown, tile.cooldown, 0, 0)
                end
            end

            local isFiltered = (db.filteredDungeons[slot.code] == true) or (slot.mapID and db.filteredDungeons[slot.mapID] == true)
            SetPortalTileActiveBorder(tile, isFiltered, ar, ag, ab)
        end
    end
end

function DynamicGroup:UpdatePortalBar(forceSeasonRefresh)
    if forceSeasonRefresh then
        seasonSlotsCache = GetSeasonDungeonSlots(true)
    end
    local db = EnsureDB()
    local shouldShow = (db.showPortalBar ~= false) and not IsYieldingSharedHooks() and (self.lfgMiniBar and self.lfgMiniBar:IsShown())

    if not self.portalBar then
        if shouldShow then
            if InCombatLockdown and InCombatLockdown() then
                self.pendingPortalBarUpdate = true
                return
            end
            self:EnsurePortalBar()
        end
        if not self.portalBar then return end
    end

    local pbar = self.portalBar
    self:UpdatePortalBarVisuals()

    if InCombatLockdown and InCombatLockdown() then
        self.pendingPortalBarUpdate = true
        return
    end

    if shouldShow then
        if not pbar:IsShown() then pbar:Show() end
        if pbar.keyBtn and pbar.keyBtn.GetAttribute then
            local kMapID, kLvl, kCode, kName = GetOwnedKeystoneInfo()
            local kSpellTarget = nil
            if kMapID and kLvl > 0 and pbar.ResolveOwnedKeystoneTeleport then
                local kSpellID, kSpellKnown = pbar.ResolveOwnedKeystoneTeleport(kMapID, kCode, kName)
                if kSpellKnown and kSpellID then
                    kSpellTarget = SafeGetSpellName(kSpellID) or kSpellID
                end
            end
            if pbar.keyBtn:GetAttribute("type1") ~= nil or pbar.keyBtn:GetAttribute("spell1") ~= nil then
                pbar.keyBtn:SetAttribute("type1", nil)
                pbar.keyBtn:SetAttribute("spell1", nil)
            end
            local desiredKeyType2 = kSpellTarget and "spell" or nil
            if pbar.keyBtn:GetAttribute("type2") ~= desiredKeyType2 or pbar.keyBtn:GetAttribute("spell2") ~= kSpellTarget then
                pbar.keyBtn:SetAttribute("type2", desiredKeyType2)
                pbar.keyBtn:SetAttribute("spell2", kSpellTarget)
            end
        end
        local slots = GetSeasonDungeonSlots(false)
        for idx = 1, 8 do
            local tile = pbar.tiles[idx]
            local slot = slots[idx]
            if tile and slot then
                local spellTarget = nil
                if slot.spellKnown then
                    spellTarget = SafeGetSpellName(slot.spellID) or slot.spellID
                end
                if tile.GetAttribute then
                    if tile:GetAttribute("type1") ~= nil or tile:GetAttribute("spell1") ~= nil then
                        tile:SetAttribute("type1", nil)
                        tile:SetAttribute("spell1", nil)
                    end
                    local desiredType2 = spellTarget and "spell" or nil
                    if tile:GetAttribute("type2") ~= desiredType2 or tile:GetAttribute("spell2") ~= spellTarget then
                        tile:SetAttribute("type2", desiredType2)
                        tile:SetAttribute("spell2", spellTarget)
                    end
                end
                if not tile:IsShown() then tile:Show() end
            elseif tile and tile:IsShown() then
                tile:Hide()
            end
        end
        if pbar.LayoutPortalTiles then pbar.LayoutPortalTiles() end
    else
        if pbar:IsShown() then pbar:Hide() end
    end
    self.pendingPortalBarUpdate = false
end

local function GetSharedAlertToastPosAndScale()
    local g = (_G.DynamicSuiteDB and type(_G.DynamicSuiteDB.global) == "table") and _G.DynamicSuiteDB.global or nil
    local dl = type(_G.DynamicLoadDB) == "table" and _G.DynamicLoadDB or nil
    local pos = (g and type(g.toastPos) == "table" and g.toastPos)
        or (dl and type(dl.toastPos) == "table" and dl.toastPos)
        or { point = "TOP", relPoint = "TOP", x = 0, y = -140 }
    local scale = tonumber((g and g.toastScale) or (dl and dl.toastScale)) or 1.0
    if scale < 0.5 then scale = 0.5 elseif scale > 2.0 then scale = 2.0 end
    return pos, scale
end

function DynamicGroup:ApplyTeleportToastPosition()
    local toast = self.teleportToast
    if not toast then return end
    if InCombatLockdown and InCombatLockdown() then
        self.pendingTeleportToastUpdate = true
        return
    end
    local pos, scale = GetSharedAlertToastPosAndScale()
    if toast.SetScale then
        toast:SetScale(scale)
    end
    toast:ClearAllPoints()
    local dlToast = _G.DynamicLoadToastFrame
    if dlToast and dlToast:IsShown() and not dlToast._dsStackedUnderGroup then
        toast._dsStackedUnderLoad = true
        toast:SetPoint("TOP", dlToast, "BOTTOM", 0, -8)
    else
        toast._dsStackedUnderLoad = false
        toast:SetPoint(pos.point or "TOP", UIParent, pos.relPoint or pos.point or "TOP", tonumber(pos.x) or 0, tonumber(pos.y) or -140)
    end
end

function DynamicGroup:OnAlertToastHidden()
    local toast = self.teleportToast
    if toast and toast:IsShown() and toast._dsStackedUnderLoad then
        toast._dsStackedUnderLoad = false
        self:ApplyTeleportToastPosition()
    end
end

function DynamicGroup:HideTeleportToast()
    self.activeTeleportToastData = nil
    if self.teleportToast then
        if InCombatLockdown and InCombatLockdown() then
            self.pendingTeleportToastHide = true
        else
            self.teleportToast:Hide()
            self.pendingTeleportToastHide = false
        end
    else
        self.pendingTeleportToastHide = false
    end
    self.pendingTeleportToastUpdate = false
end

function DynamicGroup:EnsureTeleportToast()
    if self.teleportToast then return self.teleportToast end
    if InCombatLockdown and InCombatLockdown() then
        self.pendingTeleportToastUpdate = true
        return nil
    end

    local toast = CreateFrame("Button", "DynamicGroupTeleportToast", UIParent, "BackdropTemplate")
    toast:SetSize(410, 74)
    toast:SetFrameStrata("HIGH")
    toast:SetToplevel(true)
    toast:SetClampedToScreen(true)
    toast:RegisterForClicks("RightButtonUp")
    toast:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1.5,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    toast:SetBackdropColor(0.043, 0.051, 0.071, 0.96) -- #0B0D12
    local ar, ag, ab = GetSuiteAccent()
    toast:SetBackdropBorderColor(ar, ag, ab, 0.85)

    toast:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            DynamicGroup:HideTeleportToast()
        end
    end)

    toast:HookScript("OnHide", function(selfToast)
        selfToast._dsStackedUnderLoad = false
        local dlToast = _G.DynamicLoadToastFrame
        if dlToast and dlToast:IsShown() and dlToast._dsStackedUnderGroup then
            dlToast._dsStackedUnderGroup = false
            if _G.DynamicSuite and type(_G.DynamicSuite.ApplyToastVisuals) == "function" then
                pcall(_G.DynamicSuite.ApplyToastVisuals)
            end
        end
    end)

    -- Left Dungeon Icon (44x44 framed, matching DynamicSuite Alert Toast)
    local iconBorder = CreateFrame("Frame", nil, toast, "BackdropTemplate")
    iconBorder:SetSize(44, 44)
    iconBorder:SetPoint("LEFT", toast, "LEFT", 14, 0)
    iconBorder:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    iconBorder:SetBackdropColor(0.04, 0.05, 0.07, 1)
    iconBorder:SetBackdropBorderColor(0.20, 0.24, 0.32, 0.95)
    toast.iconBorder = iconBorder

    toast.icon = iconBorder:CreateTexture(nil, "ARTWORK")
    toast.icon:SetSize(40, 40)
    toast.icon:SetPoint("CENTER", iconBorder, "CENTER", 0, 0)
    toast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    DisableTexPixelSnap(toast.icon)

    -- Secure Teleport Action Button (right-aligned pill, matching Alert Toast)
    local tpBtn = CreateFrame("Button", "DynamicGroupTeleportToastBtn", toast, "SecureActionButtonTemplate,BackdropTemplate")
    tpBtn:SetSize(76, 24)
    tpBtn:SetPoint("RIGHT", toast, "RIGHT", -12, 0)
    tpBtn:RegisterForClicks("AnyUp", "AnyDown")
    tpBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    tpBtn:SetBackdropColor(0.08, 0.10, 0.14, 0.96)
    tpBtn:SetBackdropBorderColor(0.24, 0.28, 0.36, 0.95)
    tpBtn.label = tpBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(tpBtn.label, 11, "")
    tpBtn.label:SetPoint("CENTER", 0, 0)
    tpBtn.label:SetText("Teleport")
    tpBtn:SetScript("OnEnter", function(s)
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(s, "ANCHOR_TOP")
            _G.GameTooltip:ClearLines()
            local data = DynamicGroup.activeTeleportToastData
            _G.GameTooltip:AddLine((data and data.dungeonName) or "Dungeon Teleport", 1, 1, 1)
            if data and data.spellKnown then
                _G.GameTooltip:AddLine("|cFF22C55ELeft-Click:|r |cFFE2E8F0Cast dungeon teleport.|r", 0.886, 0.910, 0.941)
            else
                _G.GameTooltip:AddLine("Dungeon teleport not learned yet (complete +10 in time).", 0.62, 0.68, 0.76, true)
            end
            _G.GameTooltip:Show()
        end
    end)
    tpBtn:SetScript("OnLeave", function()
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)
    tpBtn:SetScript("PostClick", function(selfBtn, button, down)
        local useKeyDown = (type(_G.GetCVarBool) == "function" and _G.GetCVarBool("ActionButtonUseKeyDown")) and true or false
        if (down == true) ~= useKeyDown then return end
        if button == "RightButton" then
            DynamicGroup:HideTeleportToast()
            return
        end
        if button ~= "LeftButton" then return end
        local data = DynamicGroup.activeTeleportToastData
        if data and data.spellKnown then
            DynamicGroup:HideTeleportToast()
        end
    end)
    toast.teleportBtn = tpBtn

    -- Line 1: Title (13pt, matching Alert Toast)
    toast.titleText = toast:CreateFontString(nil, "OVERLAY")
    SetSafeFont(toast.titleText, 13, "")
    toast.titleText:SetPoint("TOPLEFT", toast, "TOPLEFT", 70, -11)
    toast.titleText:SetPoint("RIGHT", tpBtn, "LEFT", -8, 0)
    toast.titleText:SetJustifyH("LEFT")
    toast.titleText:SetWordWrap(false)
    toast.titleText:SetTextColor(0.96, 0.98, 1.00, 1)

    -- Line 2: Status (11pt, matching Alert Toast)
    toast.rosterText = toast:CreateFontString(nil, "OVERLAY")
    SetSafeFont(toast.rosterText, 11, "")
    toast.rosterText:SetPoint("TOPLEFT", toast.titleText, "BOTTOMLEFT", 0, -5)
    toast.rosterText:SetPoint("RIGHT", tpBtn, "LEFT", -8, 0)
    toast.rosterText:SetJustifyH("LEFT")
    toast.rosterText:SetWordWrap(false)
    toast.rosterText:SetTextColor(0.886, 0.910, 0.941, 1)

    -- Line 3: Action Hint (10pt, matching Alert Toast)
    toast.statusText = toast:CreateFontString(nil, "OVERLAY")
    SetSafeFont(toast.statusText, 10, "")
    toast.statusText:SetPoint("TOPLEFT", toast.rosterText, "BOTTOMLEFT", 0, -5)
    toast.statusText:SetPoint("RIGHT", tpBtn, "LEFT", -8, 0)
    toast.statusText:SetJustifyH("LEFT")
    toast.statusText:SetWordWrap(false)
    toast.statusText:SetTextColor(0.58, 0.64, 0.72, 1)

    toast:Hide()
    self.teleportToast = toast
    self:ApplyTeleportToastPosition()
    return toast
end

function DynamicGroup:UpdateTeleportToast(playAudioOnRosterIncrease)
    local db = EnsureDB()
    local data = self.activeTeleportToastData
    if not data or IsYieldingSharedHooks() or (not data.isPreview and db.showGroupTeleportToast == false) then
        self:HideTeleportToast()
        return
    end

    local inGroup = (type(_G.IsInGroup) == "function" and _G.IsInGroup()) and true or false
    local numMembers
    if data.isPreview then
        numMembers = math.max(1, math.min(5, tonumber(data.previewCount) or 3))
    else
        numMembers = inGroup and ((type(_G.GetNumGroupMembers) == "function" and _G.GetNumGroupMembers()) or 1) or 1
        numMembers = math.max(1, math.min(5, tonumber(numMembers) or 1))
    end

    if playAudioOnRosterIncrease then
        local prevCount = data.lastMemberCount or 0
        if numMembers > prevCount then
            if type(_G.PlaySound) == "function" then
                if numMembers >= 5 and prevCount < 5 then
                    pcall(_G.PlaySound, (_G.SOUNDKIT and _G.SOUNDKIT.READY_CHECK) or 8960, "Master")
                else
                    pcall(_G.PlaySound, (_G.SOUNDKIT and _G.SOUNDKIT.IG_PLAYER_INVITE) or 880, "Master")
                end
            end
        end
    end
    data.lastMemberCount = numMembers

    local resolvedSpellID, spellKnown = ResolveTeleportSpellForDungeon(data.mapID, data.code, data.dungeonName, data.spellID)
    if resolvedSpellID and resolvedSpellID > 0 then
        data.spellID = resolvedSpellID
    end
    data.spellKnown = spellKnown and true or false

    local toast = self:EnsureTeleportToast()
    if not toast then
        self.pendingTeleportToastUpdate = true
        return
    end

    local ar, ag, ab = GetSuiteAccent()
    local isFull = (numMembers >= 5)
    if isFull then
        toast:SetBackdropBorderColor(0.133, 0.773, 0.369, 0.95) -- Emerald #22C55E
    else
        toast:SetBackdropBorderColor(ar, ag, ab, 0.80)
    end

    if toast.icon then
        toast.icon:SetTexture(data.icon or 136095)
    end
    if toast.iconBorder then
        if isFull then
            toast.iconBorder:SetBackdropBorderColor(0.133, 0.773, 0.369, 0.95)
        else
            toast.iconBorder:SetBackdropBorderColor(ar, ag, ab, 0.85)
        end
    end

    local titleDisplay = data.listingName
    if type(titleDisplay) ~= "string" or titleDisplay == "" then
        titleDisplay = data.dungeonName or "Mythic+ Dungeon"
    elseif data.code and data.dungeonName and not titleDisplay:lower():find(data.dungeonName:lower():sub(1, 5), 1, true) then
        titleDisplay = tostring(data.code) .. ": " .. titleDisplay
    end
    SetSafeFont(toast.titleText, 13, "")
    toast.titleText:SetText(titleDisplay)

    SetSafeFont(toast.rosterText, 11, "")
    if isFull then
        toast.rosterText:SetText("|cFF22C55EGroup Full (5/5) - Ready to Teleport!|r")
    else
        toast.rosterText:SetText(string.format("Members: %d/5", numMembers))
    end

    SetSafeFont(toast.statusText, 10, "")
    if data.spellKnown then
        toast.statusText:SetText("|cFF94A3B8Click [Teleport] to Cast   Right-Click: Dismiss|r")
    else
        toast.statusText:SetText("|cFF94A3B8No Portal Learned   Right-Click: Dismiss|r")
    end

    if InCombatLockdown and InCombatLockdown() then
        self.pendingTeleportToastUpdate = true
        return
    end

    self:ApplyTeleportToastPosition()

    local tpBtn = toast.teleportBtn
    if tpBtn then
        local spellTarget = nil
        if data.spellKnown and data.spellID and data.spellID > 0 then
            spellTarget = SafeGetSpellName(data.spellID) or data.spellID
        end
        if tpBtn.SetAttribute then
            tpBtn:SetAttribute("type1", spellTarget and "spell" or nil)
            tpBtn:SetAttribute("spell1", spellTarget)
        end
        SetSafeFont(tpBtn.label, 11, "")
        if spellTarget then
            tpBtn.label:SetText("Teleport")
            if isFull then
                tpBtn:SetBackdropColor(0.08, 0.24, 0.14, 0.96)
                tpBtn:SetBackdropBorderColor(0.133, 0.773, 0.369, 0.95)
                tpBtn.label:SetTextColor(0.204, 0.827, 0.600, 1)
            else
                tpBtn:SetBackdropColor(0.20, 0.10, 0.03, 0.96)
                tpBtn:SetBackdropBorderColor(0.976, 0.451, 0.086, 0.95)
                tpBtn.label:SetTextColor(1.0, 0.72, 0.36, 1)
            end
        else
            tpBtn.label:SetText("No Portal")
            tpBtn:SetBackdropColor(0.06, 0.07, 0.10, 0.92)
            tpBtn:SetBackdropBorderColor(0.16, 0.19, 0.25, 0.90)
            tpBtn.label:SetTextColor(0.50, 0.56, 0.64, 1)
        end
    end

    if self.pendingTeleportToastHide then
        toast:Hide()
        self.pendingTeleportToastHide = false
    elseif not toast:IsShown() then
        toast:Show()
    end
    self.pendingTeleportToastUpdate = false
end

function DynamicGroup:HandleApplicationStatusUpdated(searchResultID, newStatus, oldStatus, groupName)
    if IsSecretValue(searchResultID) or IsSecretValue(newStatus) then return end
    if type(searchResultID) ~= "number" or searchResultID <= 0 then return end

    if newStatus == "applied" or newStatus == "invited" then
        pcall(InspectSearchResult, searchResultID)
        return
    end
    if newStatus ~= "inviteaccepted" then return end

    local db = EnsureDB()
    if db.showGroupTeleportToast == false or IsYieldingSharedHooks() then return end

    local activityID = nil
    local listingName = (type(groupName) == "string" and not IsSecretValue(groupName) and groupName ~= "") and groupName or nil
    if C_LFGList and type(C_LFGList.GetSearchResultInfo) == "function" then
        local okR, rInfo = pcall(C_LFGList.GetSearchResultInfo, searchResultID)
        if okR and type(rInfo) == "table" then
            if not IsSecretValue(rInfo.activityID) and tonumber(rInfo.activityID) then
                activityID = tonumber(rInfo.activityID)
            elseif type(rInfo.activityIDs) == "table" and not IsSecretValue(rInfo.activityIDs) then
                local firstAct = rInfo.activityIDs[1]
                if not IsSecretValue(firstAct) and tonumber(firstAct) then
                    activityID = tonumber(firstAct)
                end
            end
            if type(rInfo.name) == "string" and not IsSecretValue(rInfo.name) and rInfo.name ~= "" then
                listingName = rInfo.name
            end
        end
    end

    local cached = recentSearchResultCache[searchResultID]
    if cached then
        if not activityID and cached.activityID then
            activityID = cached.activityID
        end
        if (not listingName or listingName == "") and cached.name then
            listingName = cached.name
        end
    end

    local actMeta = activityID and GetCachedActivityInfo(activityID) or nil
    local slots = GetSeasonDungeonSlots(false)
    local matchedSlot = nil
    if actMeta and actMeta.mapID then
        for _, slot in ipairs(slots) do
            if slot.mapID == actMeta.mapID then matchedSlot = slot; break end
        end
    end
    if not matchedSlot and actMeta and actMeta.code then
        for _, slot in ipairs(slots) do
            if slot.code == actMeta.code then matchedSlot = slot; break end
        end
    end
    if not matchedSlot and actMeta and actMeta.fullName and actMeta.fullName ~= "" then
        matchedSlot = MatchTextToDungeonSlot(actMeta.fullName, slots)
    end
    if not matchedSlot and listingName and listingName ~= "" then
        matchedSlot = MatchTextToDungeonSlot(listingName, slots)
    end

    if not matchedSlot and not (actMeta and actMeta.isDungeonActivity) then
        return
    end

    local dMapID = (matchedSlot and matchedSlot.mapID) or (actMeta and actMeta.mapID) or nil
    local dCode = (matchedSlot and matchedSlot.code) or (actMeta and actMeta.code) or "M+"
    local dName = (matchedSlot and matchedSlot.name) or (actMeta and actMeta.fullName ~= "" and actMeta.fullName) or listingName or "Season Dungeon"
    local dIcon = (matchedSlot and matchedSlot.icon) or 136095
    local dSpellID, dSpellKnown = ResolveTeleportSpellForDungeon(dMapID, dCode, dName, matchedSlot and matchedSlot.spellID)

    local inGroup = (type(_G.IsInGroup) == "function" and _G.IsInGroup()) and true or false
    local curMembers = inGroup and ((type(_G.GetNumGroupMembers) == "function" and _G.GetNumGroupMembers()) or 1) or 1
    curMembers = math.max(1, math.min(5, tonumber(curMembers) or 1))

    self.activeTeleportToastData = {
        resultID = searchResultID,
        activityID = activityID,
        mapID = dMapID,
        code = dCode,
        dungeonName = dName,
        listingName = listingName or dName,
        icon = dIcon,
        spellID = dSpellID,
        spellKnown = dSpellKnown and true or false,
        lastMemberCount = curMembers,
    }

    if type(_G.PlaySound) == "function" then
        if curMembers >= 5 then
            pcall(_G.PlaySound, (_G.SOUNDKIT and _G.SOUNDKIT.READY_CHECK) or 8960, "Master")
        else
            pcall(_G.PlaySound, (_G.SOUNDKIT and _G.SOUNDKIT.IG_PLAYER_INVITE) or 880, "Master")
        end
    end

    self:UpdateTeleportToast(false)
end

function DynamicGroup:TriggerTeleportToastPreview(mode)
    if IsYieldingSharedHooks() then
        PrintMsg("DynamicGroup is currently yielding to another LFG addon.")
        return
    end
    local slots = GetSeasonDungeonSlots(false)
    local chosenSlot = nil
    for _, slot in ipairs(slots) do
        if slot.spellKnown then
            chosenSlot = slot
            break
        end
    end
    if not chosenSlot then
        chosenSlot = slots[1]
    end

    local isFull = (mode == "FULL")
    local count = isFull and 5 or 3
    self.activeTeleportToastData = {
        isPreview = true,
        previewCount = count,
        mapID = chosenSlot and chosenSlot.mapID or nil,
        code = chosenSlot and chosenSlot.code or "M+",
        dungeonName = chosenSlot and chosenSlot.name or "Midnight Season 2 Dungeon",
        listingName = "+12 Midnight Season 2 Dungeon",
        icon = chosenSlot and chosenSlot.icon or 136095,
        spellID = chosenSlot and chosenSlot.spellID or 0,
        spellKnown = (chosenSlot and chosenSlot.spellKnown) and true or false,
        lastMemberCount = count,
    }

    if type(_G.PlaySound) == "function" then
        if isFull then
            pcall(_G.PlaySound, (_G.SOUNDKIT and _G.SOUNDKIT.READY_CHECK) or 8960, "Master")
        else
            pcall(_G.PlaySound, (_G.SOUNDKIT and _G.SOUNDKIT.IG_PLAYER_INVITE) or 880, "Master")
        end
    end

    self:UpdateTeleportToast(false)
end

function DynamicGroup:CycleTeleportToastPreview()
    local cur = self.activeTeleportToastData
    local isShowingPreview = cur and cur.isPreview and self.teleportToast and self.teleportToast:IsShown()
    if not isShowingPreview then
        self:TriggerTeleportToastPreview("JOIN")
        PrintMsg("Showing teleport toast preview (3/5 joined).")
    elseif (cur.previewCount or 3) < 5 then
        self:TriggerTeleportToastPreview("FULL")
        PrintMsg("Advancing teleport toast preview to Group Full (5/5).")
    else
        self:HideTeleportToast()
        PrintMsg("Teleport toast preview dismissed.")
    end
end

function DynamicGroup:UpdateLFGMiniBar()
    local bar = self.lfgMiniBar
    if not bar then return end
    if IsYieldingSharedHooks() then
        CloseActiveDropdown()
        bar:Hide()
        self:UpdatePortalBar()
        return
    elseif not bar:IsShown() then
        bar:Show()
    end
    local db = EnsureDB()
    local ar, ag, ab = GetSuiteAccent()
    bar:SetBackdropBorderColor(ar, ag, ab, 0.45)

    local activeCount, totalCount = self:GetActiveRegionCount()
    if bar.regionBtn and bar.regionBtn.label then
        bar.regionBtn.label:SetText(string.format("Reg (%d/%d)", activeCount, totalCount))
    end
    if bar.scoreBtn and bar.scoreBtn.label then
        bar.scoreBtn.label:SetText(string.format("IO: %d+", tonumber(db.minLeaderScore) or 0))
    end

    if bar.roleBtn and bar.roleBtn.RefreshFilterBtnStyle then
        bar.roleBtn:RefreshFilterBtnStyle()
    end
    if bar.oneClickBtn and bar.oneClickBtn.RefreshOneClickStyle then
        bar.oneClickBtn:RefreshOneClickStyle()
    end
    if bar.cogBtn and bar.cogBtn.icon then
        bar.cogBtn.icon:SetVertexColor(ar, ag, ab, 0.92)
    end
    if activeRegionPopover and activeRegionPopover:IsShown() and activeRegionPopover.RefreshRows then
        activeRegionPopover:RefreshRows()
    end
    if activeFilterPopover and activeFilterPopover:IsShown() and activeFilterPopover.RefreshRows then
        activeFilterPopover:RefreshRows()
    end
    self:UpdatePortalBar()
end

function DynamicGroup:RefreshLFGResults()
    SuppressEUIGroupFinderIfNeeded()
    self:UpdateLFGMiniBar()
    if _G.LFGListFrame and _G.LFGListFrame.SearchPanel and _G.LFGListFrame.SearchPanel:IsShown() then
        local sp = _G.LFGListFrame.SearchPanel
        local pState = GetPanelState(sp)
        pState.needsInitialSort = true
        FilterAndSortSearchPanelResults(sp, true)
        if type(_G.LFGListSearchPanel_UpdateResults) == "function" and not (InCombatLockdown and InCombatLockdown()) then
            pcall(_G.LFGListSearchPanel_UpdateResults, sp)
        end
        SyncScrollBoxToFilteredResults(sp)
    end
end

-- ============================================================================
-- 5. ENGINE 3: SIGN-UP, AUTO-ROLE, REMEMBER SEARCH & SAFE AUTO-REFRESH TICKER
-- ============================================================================

local function OnLFGListApplicationDialogUpdateRoles(dialog)
    if not dialog or IsYieldingSharedHooks() then return end
    local db = EnsureDB()
    if not db.autoSelectRole then return end
    local spec = SafeGetSpecialization()
    if not spec then return end
    local role = SafeGetSpecializationRole(spec)
    if not role then return end

    if role == "TANK" and dialog.TankButton and dialog.TankButton:IsShown() and dialog.TankButton.CheckButton then
        dialog.TankButton.CheckButton:SetChecked(true)
    elseif role == "HEALER" and dialog.HealerButton and dialog.HealerButton:IsShown() and dialog.HealerButton.CheckButton then
        dialog.HealerButton.CheckButton:SetChecked(true)
    elseif role == "DAMAGER" and dialog.DamagerButton and dialog.DamagerButton:IsShown() and dialog.DamagerButton.CheckButton then
        dialog.DamagerButton.CheckButton:SetChecked(true)
    end
end

local function BuildSignUpNoteString()
    local db = EnsureDB()
    local parts = {}

    if db.appendIlvlToNote then
        local eqIlvl = 0
        if type(GetAverageItemLevel) == "function" then
            local _, equipped = GetAverageItemLevel()
            eqIlvl = math.floor(tonumber(equipped) or 0)
        end
        local specName = ""
        local spec = SafeGetSpecialization()
        if spec then
            local _, sName = SafeGetSpecializationInfo(spec)
            specName = sName or ""
        end
        local classLoc = UnitClass("player") or ""
        if eqIlvl > 0 then
            parts[#parts + 1] = string.format("[%d %s %s]", eqIlvl, specName, classLoc):gsub("%s+", " ")
        end
    end

    if db.persistentNote and db.persistentNote ~= "" then
        parts[#parts + 1] = db.persistentNote
    end

    return table.concat(parts, " ")
end

local function SnapDialogSignUpUnderCursor(dialog)
    if not dialog or not dialog.SignUpButton then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local scale = dialog:GetEffectiveScale() or 1
    local cx, cy = GetCursorPosition()
    cx, cy = cx / scale, cy / scale

    -- Position the dialog so its SignUpButton sits directly under the user's cursor for an instant, zero-movement hardware click!
    local btn = dialog.SignUpButton
    local dCenterX, dCenterY = dialog:GetCenter()
    local bCenterX, bCenterY = btn:GetCenter()
    if dCenterX and dCenterY and bCenterX and bCenterY then
        local dx = dCenterX - bCenterX
        local dy = dCenterY - bCenterY
        dialog:ClearAllPoints()
        dialog:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx + dx, cy + dy)
        _dgDialogState[dialog] = true
    end
end

local function OnLFGListApplicationDialogOnShow(dialog)
    if not dialog or IsYieldingSharedHooks() then return end
    local db = EnsureDB()

    OnLFGListApplicationDialogUpdateRoles(dialog)

    if db.autoFillNote and dialog.Description and not dialog.Description.securityDisableSetText then
        local editBox = dialog.Description.EditBox or (dialog.Description.GetEditBox and dialog.Description:GetEditBox()) or dialog.Description
        if editBox and editBox.SetText and not editBox.securityDisableSetText then
            local okText, curText = pcall(editBox.GetText, editBox)
            if okText and (not curText or (not IsSecretValue(curText) and curText == "")) then
                local note = BuildSignUpNoteString()
                if note and note ~= "" then
                    pcall(editBox.SetText, editBox, note)
                end
            end
        end
    end

    if db.oneClickSignUp and not (IsModifierKeyDown and IsModifierKeyDown()) then
        SnapDialogSignUpUnderCursor(dialog)
        C_Timer.After(0, function()
            if dialog and dialog:IsShown() and not (IsModifierKeyDown and IsModifierKeyDown()) then
                SnapDialogSignUpUnderCursor(dialog)
            end
        end)
    elseif _dgDialogState[dialog] then
        -- Restore standard center position if previously snapped by DynamicGroup and modifier key is held or 1-Click is off
        if not InCombatLockdown or not InCombatLockdown() then
            dialog:ClearAllPoints()
            dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
            _dgDialogState[dialog] = nil
        end
    end
end
function DynamicGroup:UpdateAutoRefreshTicker()
    if self.refreshTicker then
        self.refreshTicker:Cancel()
        self.refreshTicker = nil
    end

    local db = EnsureDB()
    local interval = tonumber(db.autoRefreshInterval) or 0
    if interval <= 0 then return end

    self.refreshTicker = C_Timer.NewTicker(interval, function()
        if InCombatLockdown and InCombatLockdown() then return end
        local sp = _G.LFGListFrame and _G.LFGListFrame.SearchPanel
        if not sp or not sp:IsShown() then return end
        if _G.LFGListApplicationDialog and _G.LFGListApplicationDialog:IsShown() then return end
        if sp.SearchBox and sp.SearchBox.HasFocus and sp.SearchBox:HasFocus() then return end
        if sp.RefreshButton and sp.RefreshButton:IsEnabled() and type(_G.LFGListSearchPanel_DoSearch) == "function" then
            pcall(_G.LFGListSearchPanel_DoSearch, sp)
        end
    end)
end

function DynamicGroup:InstallLFGHooks()
    SuppressEUIGroupFinderIfNeeded()
    if self.lfgHooksInstalled then return end
    if type(_G.LFGListSearchEntry_Update) == "function" then
        hooksecurefunc("LFGListSearchEntry_Update", OnLFGListSearchEntryUpdate)
        hooksecurefunc("LFGListSearchPanel_UpdateResultList", OnLFGListSearchPanelUpdateResultList)
        if type(_G.LFGListSearchPanel_UpdateResults) == "function" then
            hooksecurefunc("LFGListSearchPanel_UpdateResults", function(panel)
                if not panel then return end
                if InCombatLockdown and InCombatLockdown() then return end
                SyncScrollBoxToFilteredResults(panel)
            end)
        end
        if type(_G.LFGListSearchPanel_DoSearch) == "function" then
            hooksecurefunc("LFGListSearchPanel_DoSearch", function(sp)
                if sp then
                    local pState = GetPanelState(sp)
                    pState.needsInitialSort = true
                    pState.orderedResults = nil
                    pState.rawResults = nil
                    local db = EnsureDB()
                    if db.rememberSearchText and sp.SearchBox and sp.SearchBox.GetText then
                        local okT, txt = pcall(sp.SearchBox.GetText, sp.SearchBox)
                        if okT and type(txt) == "string" and not IsSecretValue(txt) then
                            db.lastSearchText = txt
                        end
                    end
                end
            end)
        end
        if type(_G.LFGListSearchPanel_SetCategory) == "function" then
            hooksecurefunc("LFGListSearchPanel_SetCategory", function(sp)
                if sp then
                    local pState = GetPanelState(sp)
                    pState.needsInitialSort = true
                    pState.orderedResults = nil
                    pState.rawResults = nil
                    local db = EnsureDB()
                    if db.rememberSearchText and db.lastSearchText and db.lastSearchText ~= "" and sp.SearchBox and sp.SearchBox.SetText and not sp.SearchBox.securityDisableSetText then
                        local okCur, cur = pcall(sp.SearchBox.GetText, sp.SearchBox)
                        if okCur and (not cur or (not IsSecretValue(cur) and cur == "")) then
                            pcall(sp.SearchBox.SetText, sp.SearchBox, db.lastSearchText)
                        end
                    end
                end
            end)
        end
        if type(_G.LFGListSearchPanel_Clear) == "function" then
            hooksecurefunc("LFGListSearchPanel_Clear", function(sp)
                if sp then
                    local pState = GetPanelState(sp)
                    pState.needsInitialSort = true
                    pState.orderedResults = nil
                    pState.rawResults = nil
                end
            end)
        end
        if type(_G.LFGListSearchEntry_OnClick) == "function" then
            hooksecurefunc("LFGListSearchEntry_OnClick", function(entry, button)
                if button ~= "LeftButton" then return end
                if IsModifierKeyDown and IsModifierKeyDown() then return end
                local db = EnsureDB()
                if not db.oneClickSignUp then return end
                local st = entry and GetEntryState(entry)
                local lockedID = st and st.pressedResultID
                if st then st.pressedResultID = nil end
                PerformLFGSignUp(entry, false, lockedID)
            end)
        end
        if type(_G.LFGListUtil_SetSearchEntryTooltip) == "function" then
            hooksecurefunc("LFGListUtil_SetSearchEntryTooltip", function(tooltip, resultID)
                if not tooltip or not resultID or IsYieldingSharedHooks() then return end
                if not IsValidSearchResultID(resultID) then return end
                local db = EnsureDB()
                if not db.lfgFilterEnabled then return end
                local meta = InspectSearchResult(resultID)
                if not meta then return end

                if meta.regionKey ~= "PENDING" then
                    local regMeta = REGION_META[meta.regionKey] or REGION_META.UNKNOWN
                    local rc = GetRegionColor(meta.regionKey)
                    local realmSuffix = (meta.realmName and meta.realmName ~= "") and (" (" .. tostring(meta.realmName) .. ")") or ""
                    tooltip:AddDoubleLine(
                        "Datacentre Region:",
                        FormatRegionTag(meta.regionKey, regMeta.badge) .. " |c" .. rc.hex .. regMeta.pillLabel .. "|r" .. realmSuffix,
                        0.64, 0.70, 0.78,
                        rc.r, rc.g, rc.b
                    )
                end

                local utilParts = {}
                if meta.hasLust then
                    utilParts[#utilParts + 1] = "|cFF38BDF8Bloodlust / Heroism|r"
                end
                if meta.hasCR then
                    utilParts[#utilParts + 1] = "|cFF34D399Battle Rez|r"
                end
                local utilText = (#utilParts > 0) and table.concat(utilParts, " + ") or "|cFF94A3B8None|r"
                tooltip:AddDoubleLine(
                    "Party Utility:",
                    utilText,
                    0.64, 0.70, 0.78,
                    1, 1, 1
                )

                if meta.challengeMapID then
                    local bestLevel, bestScore, isTimed = GetPlayerBestForDungeon(meta.challengeMapID)
                    local bestText
                    if bestLevel > 0 then
                        local timedLabel = isTimed and "Timed" or "Over Time"
                        local scoreSuffix = (bestScore > 0) and (" (Score: " .. tostring(bestScore) .. ")") or ""
                        bestText = string.format("|cFF22C55E+%d (%s)|r%s", bestLevel, timedLabel, scoreSuffix)
                    else
                        bestText = "|cFF94A3B8No timed key recorded|r"
                    end
                    tooltip:AddDoubleLine(
                        "Your Dungeon Best:",
                        bestText,
                        0.64, 0.70, 0.78,
                        1, 1, 1
                    )
                end

                if meta.numMembers and meta.numMembers > 0 then
                    tooltip:AddDoubleLine(
                        "Your Class in Group:",
                        meta.hasPlayerClass and "|cFFF97316Yes|r" or "|cFF34D399No|r",
                        0.64, 0.70, 0.78,
                        1, 1, 1
                    )
                end

                tooltip:Show()
            end)
        end
        if C_LFGList and type(C_LFGList.SaveAdvancedFilter) == "function" then
            pcall(hooksecurefunc, C_LFGList, "SaveAdvancedFilter", function()
                if isSyncingAdvancedFilter or IsYieldingSharedHooks() then return end
                PullFiltersFromBlizzardAdvancedFilter()
                if DynamicGroup.UpdateLFGMiniBar then
                    DynamicGroup:UpdateLFGMiniBar()
                end
                if DynamicGroup.RefreshLFGResults then
                    DynamicGroup:RefreshLFGResults()
                end
                if DynamicGroup.RefreshConfigUI then
                    DynamicGroup:RefreshConfigUI()
                end
            end)
        end
        if type(_G.LFGListApplicationDialog_UpdateRoles) == "function" then
            hooksecurefunc("LFGListApplicationDialog_UpdateRoles", OnLFGListApplicationDialogUpdateRoles)
        end
        if _G.LFGListApplicationDialog and _G.LFGListApplicationDialog.HookScript then
            _G.LFGListApplicationDialog:HookScript("OnShow", OnLFGListApplicationDialogOnShow)
        end
        if _G.LFGListFrame and _G.LFGListFrame.SearchPanel and _G.LFGListFrame.SearchPanel.HookScript then
            _G.LFGListFrame.SearchPanel:HookScript("OnShow", function()
                SuppressEUIGroupFinderIfNeeded()
                PullFiltersFromBlizzardAdvancedFilter()
                if DynamicGroup.EnsureLFGMiniBar then
                    DynamicGroup:EnsureLFGMiniBar()
                end
                if DynamicGroup.EnsurePortalBar then
                    DynamicGroup:EnsurePortalBar()
                end
                if DynamicGroup.UpdateLFGMiniBar then
                    DynamicGroup:UpdateLFGMiniBar()
                end
            end)
        end
        self:EnsureLFGMiniBar()
        self:EnsurePortalBar()
        self.lfgHooksInstalled = true
    end
end

-- ============================================================================
-- 6. TELEMETRY & STATUS TEXT FOR DYNAMICSUITE HEADER BAR
-- ============================================================================

local function GetGroupStatusText()
    local db = EnsureDB()
    local inviteLabels = {
        FRIENDS_AND_GUILD = "Friends & Guild",
        FRIENDS_ONLY      = "Friends Only",
        GUILD_ONLY        = "Guild Only",
        OFF               = "Manual",
    }
    local invText = inviteLabels[db.incomingInviteMode or "FRIENDS_AND_GUILD"] or "Friends & Guild"
    local activeReg, totalReg = DynamicGroup:GetActiveRegionCount()
    local roleText = db.autoSelectRole and "ON" or "OFF"
    return string.format("* Auto-Invite: %s | LFG Regions: %d/%d Active | Auto-Role: %s", invText, activeReg, totalReg, roleText)
end

function DynamicGroup:GetStatusText()
    return GetGroupStatusText()
end

-- ============================================================================
-- 7. UNIFIED 3-TAB OBSIDIAN UI (DIRECTION A + HYBRID INLINE SUB-DRAWERS)
-- ============================================================================

-- Custom 4px Click-Draggable Obsidian ScrollContainer (Gold Standard Geometry)
local function CreateObsidianScrollArea(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -52)
    holder:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -16, 10)

    local scrollFrame = CreateFrame("ScrollFrame", nil, holder)
    scrollFrame:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(640, 480)
    scrollFrame:SetScrollChild(content)

    local track = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    track:SetWidth(4)
    track:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 10, -2)
    track:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 10, 2)
    track:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    track:SetBackdropColor(1, 1, 1, 0.05)

    local thumb = CreateFrame("Button", nil, track, "BackdropTemplate")
    thumb:SetWidth(4)
    thumb:SetHeight(48)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    thumb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    thumb:SetBackdropColor(0.38, 0.45, 0.56, 0.85)

    local function UpdateThumb()
        local maxScroll = math.max(0, (content:GetHeight() or 0) - (scrollFrame:GetHeight() or 0))
        if maxScroll <= 1 then
            track:Hide()
            scrollFrame:SetVerticalScroll(0)
            return
        end
        track:Show()
        local trackH = math.max(20, track:GetHeight() or 200)
        local ratio = math.min(1, (scrollFrame:GetHeight() or 1) / math.max(1, content:GetHeight() or 1))
        local thumbH = math.max(28, math.floor(trackH * ratio))
        thumb:SetHeight(thumbH)

        local cur = math.min(maxScroll, math.max(0, scrollFrame:GetVerticalScroll() or 0))
        local travel = math.max(1, trackH - thumbH)
        local yOff = -(cur / maxScroll) * travel
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, yOff)
    end

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        CloseActiveDropdown()
        local maxScroll = math.max(0, (content:GetHeight() or 0) - (self:GetHeight() or 0))
        local nextScroll = math.min(maxScroll, math.max(0, (self:GetVerticalScroll() or 0) - (delta * 36)))
        self:SetVerticalScroll(nextScroll)
        UpdateThumb()
    end)

    thumb:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local startY = select(2, GetCursorPosition()) / (self:GetEffectiveScale() or 1)
        local startScroll = scrollFrame:GetVerticalScroll() or 0
        self:SetScript("OnUpdate", function()
            if not IsMouseButtonDown("LeftButton") then
                self:SetScript("OnUpdate", nil)
                return
            end
            local curY = select(2, GetCursorPosition()) / (self:GetEffectiveScale() or 1)
            local dy = startY - curY
            local maxScroll = math.max(0, (content:GetHeight() or 0) - (scrollFrame:GetHeight() or 0))
            local trackH = math.max(20, track:GetHeight() or 200)
            local travel = math.max(1, trackH - (self:GetHeight() or 28))
            local nextScroll = math.min(maxScroll, math.max(0, startScroll + (dy / travel) * maxScroll))
            scrollFrame:SetVerticalScroll(nextScroll)
            UpdateThumb()
        end)
    end)
    thumb:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    thumb:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    scrollFrame:SetScript("OnSizeChanged", function(self, w)
        if w and w > 40 then
            content:SetWidth(w)
        end
        UpdateThumb()
    end)

    holder.scrollFrame = scrollFrame
    holder.content = content
    holder.UpdateThumb = UpdateThumb
    holder.thumb = thumb
    return holder
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
    local padX = padOverride or (parent and parent.innerPadX) or 0
    local hdr = CreateFrame("Frame", nil, parent)
    hdr:SetHeight(hasSub and 36 or 20)
    local y = yOffset or 0
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
    hdr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -padX, y)

    local ar, ag, ab = GetSuiteAccent()
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

    local title = hdr:CreateFontString(nil, "OVERLAY")
    SetSafeFont(title, 11, "")
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

    local subtitle = hdr:CreateFontString(nil, "OVERLAY")
    SetSafeFont(subtitle, 10, "")
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
        local r, g, b = GetSuiteAccent()
        if self.leftBar then self.leftBar:SetColorTexture(r, g, b, 1.0) end
        if self.botLine then self.botLine:SetColorTexture(r, g, b, 0.35) end
        if self.title then
            SetSafeFont(self.title, 11, "")
            self.title:SetTextColor(r, g, b, 1.0)
        end
        if self.subtitle then
            SetSafeFont(self.subtitle, 10, "")
            self.subtitle:SetTextColor(0.64, 0.70, 0.78, 1.0)
        end
    end

    return hdr
end
DynamicGroup.CreateSectionHeader = CreateSectionHeader

local function CreateSectionBox(page, titleText, subtitleText, root)
    local box = CreateFrame("Frame", nil, page, "BackdropTemplate")
    box.innerPadX = 14
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    box:SetBackdropColor(0.055, 0.063, 0.082, 0.96) -- #0E1015
    box:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95) -- #252A36
    box.hdr = CreateSectionHeader(box, -10, titleText, subtitleText, 14)
    box.orderedCards = {}
    page.sections = page.sections or {}
    page.sections[#page.sections + 1] = box
    if root then
        root.sectionHeaders = root.sectionHeaders or {}
        root.sectionHeaders[#root.sectionHeaders + 1] = box.hdr
    end
    return box
end

local trackedCardRows = {}

local function CreateCardRow(parent, height, titleText, descText)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetHeight(height or 62)
    card.baseHeight = height or 62
    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    -- #14171F surface with #252A36 border (90/8/2 palette)
    card:SetBackdropColor(0.078, 0.090, 0.122, 0.95)
    card:SetBackdropBorderColor(0.145, 0.165, 0.212, 1.00)

    card.title = card:CreateFontString(nil, "OVERLAY")
    SetSafeFont(card.title, 11, "")
    card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -10)
    card.title:SetPoint("RIGHT", card, "RIGHT", -16, 0)
    card.title:SetJustifyH("LEFT")
    card.title:SetWordWrap(false)
    local ar, ag, ab = GetSuiteAccent()
    card.title:SetTextColor(0.97, 0.98, 1.00, 1.00)
    card.title:SetText(titleText or "")

    card.desc = card:CreateFontString(nil, "OVERLAY")
    SetSafeFont(card.desc, 10, "")
    card.desc:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
    card.desc:SetPoint("RIGHT", card, "RIGHT", -16, 0)
    card.desc:SetJustifyH("LEFT")
    card.desc:SetWordWrap(true); if card.desc.SetMaxLines then card.desc:SetMaxLines(2) end
    card.desc:SetTextColor(0.58, 0.64, 0.72)
    card.desc:SetText(descText or "")

    table.insert(trackedCardRows, card)
    return card
end

local function AnchorCardTextToRightWidget(card, rightWidget)
    if not card or not rightWidget then return end
    if card.title then
        card.title:ClearAllPoints()
        card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -10)
        card.title:SetPoint("RIGHT", rightWidget, "LEFT", -16, 0)
    end
    if card.desc then
        card.desc:ClearAllPoints()
        card.desc:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
        card.desc:SetPoint("RIGHT", rightWidget, "LEFT", -16, 0)
    end
end

local function AttachDropdownToCard(card, width, options, getValue, onSelect)
    local btn = CreateFrame("Button", nil, card, "BackdropTemplate")
    btn:SetSize(width or 250, 26)
    btn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -17)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(0.059, 0.071, 0.094, 0.98)
    btn:SetBackdropBorderColor(0.145, 0.165, 0.212, 1.00)

    AnchorCardTextToRightWidget(card, btn)

    btn.label = btn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(btn.label, 11, "")
    btn.label:SetPoint("LEFT", 10, 0)
    btn.label:SetPoint("RIGHT", -24, 0)
    btn.label:SetJustifyH("LEFT")
    btn.label:SetWordWrap(false)
    btn.label:SetTextColor(0.92, 0.95, 0.99)

    btn.chevron = btn:CreateTexture(nil, "ARTWORK")
    btn.chevron:SetSize(12, 12)
    btn.chevron:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    btn.chevron:SetTexture(ICON_CHEVRON_DOWN)

    function btn:SetChevronOpen(isOpen)
        local ar, ag, ab = GetSuiteAccent()
        self.chevron:SetTexture(isOpen and ICON_CHEVRON_UP or ICON_CHEVRON_DOWN)
        self.chevron:SetVertexColor(ar, ag, ab, 1)
        if isOpen then
            self:SetBackdropBorderColor(ar, ag, ab, 0.95)
        else
            self:SetBackdropBorderColor(0.145, 0.165, 0.212, 1.00)
        end
    end

    function btn:RefreshValue()
        SetSafeFont(self.label, 11, "")
        local cur = getValue()
        for _, opt in ipairs(options) do
            if opt.value == cur then
                self.label:SetText(opt.label)
                break
            end
        end
        self:SetChevronOpen(activeDropdownMenu and activeDropdownMenu:IsShown() and activeDropdownMenu.anchorBtn == self)
    end

    btn:SetScript("OnEnter", function(self)
        local ar, ag, ab = GetSuiteAccent()
        self:SetBackdropBorderColor(ar, ag, ab, 0.85)
    end)
    btn:SetScript("OnLeave", function(self)
        if not (activeDropdownMenu and activeDropdownMenu:IsShown() and activeDropdownMenu.anchorBtn == self) then
            self:SetBackdropBorderColor(0.145, 0.165, 0.212, 1.00)
        end
    end)

    btn:SetScript("OnClick", function(self)
        ShowObsidianDropdown(self, options, getValue(), function(val, lbl)
            onSelect(val, lbl)
            self:RefreshValue()
            if _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
                pcall(_G.DynamicSuite.RefreshHeaderStatus)
            end
        end)
    end)

    btn:SetScript("OnHide", function(self)
        if activeDropdownMenu and activeDropdownMenu.anchorBtn == self then
            CloseActiveDropdown()
        end
    end)

    btn:RefreshValue()
    card.dropdown = btn
    return btn
end

-- Direction A: 2-Pill Segmented Switch ([ Off | <check> Enabled ]) with auto-sized pill widths
local function AttachSegmentedSwitchToCard(card, getValue, onToggle, offText, onText)
    local wrap = CreateFrame("Frame", nil, card, "BackdropTemplate")
    wrap:SetSize(164, 26)
    wrap:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -17)
    wrap:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    wrap:SetBackdropColor(0.059, 0.071, 0.094, 0.98)
    wrap:SetBackdropBorderColor(0.145, 0.165, 0.212, 1.00)

    AnchorCardTextToRightWidget(card, wrap)

    local offBtn = CreateFrame("Button", nil, wrap, "BackdropTemplate")
    offBtn:SetHeight(24)
    offBtn:SetPoint("LEFT", wrap, "LEFT", 1, 0)
    offBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    offBtn.label = offBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(offBtn.label, 11, "")
    offBtn.label:SetPoint("LEFT", offBtn, "LEFT", 6, 0); offBtn.label:SetPoint("RIGHT", offBtn, "RIGHT", -6, 0); offBtn.label:SetJustifyH("CENTER")
    offBtn.label:SetText(offText or "Off")

    local offBar = offBtn:CreateTexture(nil, "OVERLAY")
    offBar:SetHeight(1.5)
    offBar:SetPoint("BOTTOMLEFT", offBtn, "BOTTOMLEFT", 1, 1)
    offBar:SetPoint("BOTTOMRIGHT", offBtn, "BOTTOMRIGHT", -1, 1)
    offBar:SetColorTexture(0.973, 0.443, 0.443, 0.85)
    offBar:Hide()
    offBtn.OffBar = offBar

    local onBtn = CreateFrame("Button", nil, wrap, "BackdropTemplate")
    onBtn:SetHeight(24)
    onBtn:SetPoint("RIGHT", wrap, "RIGHT", -1, 0)
    onBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    onBtn.check = onBtn:CreateTexture(nil, "ARTWORK")
    onBtn.check:SetSize(6, 6)
    onBtn.check:SetColorTexture(1, 1, 1, 0.98)
    onBtn.check:SetPoint("LEFT", onBtn, "LEFT", 8, 0)

    onBtn.label = onBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(onBtn.label, 11, "")
    onBtn.label:SetText(onText or "Enabled")
    onBtn.label:SetPoint("CENTER", onBtn, "CENTER", 0, 0)

    function wrap:RefreshValue()
        SetSafeFont(offBtn.label, 11, "")
        SetSafeFont(onBtn.label, 11, "")

        local rawOff = (offBtn.label.GetUnboundedStringWidth and offBtn.label:GetUnboundedStringWidth()) or offBtn.label:GetStringWidth() or 0; local offW = math.max(58, math.ceil(math.max(rawOff, 24) + 24))
        local rawOn = (onBtn.label.GetUnboundedStringWidth and onBtn.label:GetUnboundedStringWidth()) or onBtn.label:GetStringWidth() or 0; local onW = math.max(88, math.ceil(math.max(rawOn, 48) + 34))
        offBtn:SetWidth(offW)
        onBtn:SetWidth(onW)
        self:SetSize(offW + onW + 3, 26)

        local isEnabled = getValue() and true or false
        local ar, ag, ab = GetSuiteAccent()
        local fillAlpha = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42
        if isEnabled then
            offBtn.OffBar:Hide()
            offBtn:SetBackdropColor(0.059, 0.071, 0.094, 0)
            offBtn:SetBackdropBorderColor(0, 0, 0, 0)
            offBtn.label:SetTextColor(0.55, 0.60, 0.68)

            onBtn:SetBackdropColor(ar * fillAlpha, ag * fillAlpha, ab * fillAlpha, 0.96)
            onBtn:SetBackdropBorderColor(ar, ag, ab, 0.95)
            onBtn.check:ClearAllPoints()
            onBtn.check:SetPoint("LEFT", onBtn, "LEFT", 8, 0)
            onBtn.check:SetColorTexture(1, 1, 1, 0.98)
            onBtn.check:Hide()
            onBtn.label:ClearAllPoints()
            onBtn.label:SetPoint("CENTER", onBtn, "CENTER", 0, 0)
            onBtn.label:SetTextColor(0.98, 0.99, 1.00)
        else
            offBtn.OffBar:Show()
            offBtn:SetBackdropColor(0.118, 0.141, 0.188, 0.98)
            offBtn:SetBackdropBorderColor(0.392, 0.455, 0.545, 0.90)
            offBtn.label:SetTextColor(0.886, 0.910, 0.941)

            onBtn:SetBackdropColor(0.059, 0.071, 0.094, 0)
            onBtn:SetBackdropBorderColor(0, 0, 0, 0)
            onBtn.check:Hide()
            onBtn.label:ClearAllPoints()
            onBtn.label:SetPoint("CENTER", onBtn, "CENTER", 0, 0)
            onBtn.label:SetTextColor(0.55, 0.60, 0.68)
        end
    end

    offBtn:SetScript("OnClick", function()
        CloseActiveDropdown()
        if getValue() then
            onToggle(false)
            wrap:RefreshValue()
            if _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
                pcall(_G.DynamicSuite.RefreshHeaderStatus)
            end
        end
    end)

    onBtn:SetScript("OnClick", function()
        CloseActiveDropdown()
        if not getValue() then
            onToggle(true)
            wrap:RefreshValue()
            if _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
                pcall(_G.DynamicSuite.RefreshHeaderStatus)
            end
        end
    end)

    wrap:RefreshValue()
    card.toggleBtn = wrap
    return wrap
end

-- ============================================================================
-- Collapsible Sub-Drawer Group & Full-Width Horizontal Chevron Toggle Bar (DESIGN_SYSTEM.md Section 2.6)
-- ============================================================================
local function CreateSubDrawerToggleBar(card, subCount, getExpanded, setExpanded, onToggleLayout)
    local bar = CreateFrame("Button", nil, card, "BackdropTemplate")
    bar:SetSize(400, 24)
    bar:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -52)
    bar:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -52)
    bar:EnableMouse(true)
    bar:RegisterForClicks("AnyUp")
    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    local label = bar:CreateFontString(nil, "OVERLAY")
    SetSafeFont(label, 11, "")
    label:SetPoint("CENTER", bar, "CENTER", 8, 0)
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    label:SetText(string.format("Sub-Settings (%d)", subCount or 1))
    bar.label = label

    local chev = bar:CreateTexture(nil, "OVERLAY")
    chev:SetSize(11, 11)
    chev:SetPoint("RIGHT", label, "LEFT", -6, 0)
    chev:SetTexture(ICON_CHEVRON_DOWN)
    DisableTexPixelSnap(chev)
    bar.chevron = chev
    bar.chevronTex = chev
    bar.chevTex = chev
    bar.Chevron = chev

    function bar:RefreshValue()
        local isOpen = (getExpanded() ~= false)
        local ar, ag, ab = GetSuiteAccent()
        local fillAlpha = ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42)
        SetSafeFont(label, 11, "")
        label:SetText(string.format("Sub-Settings (%d)", subCount or 1))
        if isOpen then
            self:SetBackdropColor(ar * (fillAlpha * 0.60), ag * (fillAlpha * 0.60), ab * (fillAlpha * 0.60), 0.96)
            self:SetBackdropBorderColor(ar, ag, ab, 0.95)
            self.chevron:SetTexture(ICON_CHEVRON_UP)
            DisableTexPixelSnap(self.chevron)
            self.chevron:SetVertexColor(1.0, 1.0, 1.0, 1.0)
            self.label:SetTextColor(1.0, 1.0, 1.0, 1.0)
        else
            self:SetBackdropColor(0.078, 0.090, 0.122, 0.96) -- CELL_BG #14171F
            self:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95) -- CELL_BORDER #252A36
            self.chevron:SetTexture(ICON_CHEVRON_DOWN)
            DisableTexPixelSnap(self.chevron)
            self.chevron:SetVertexColor(ar, ag, ab, 0.95)
            self.label:SetTextColor(0.84, 0.89, 0.96, 1.0)
        end
    end

    bar:SetScript("OnEnter", function(selfBar)
        local ar, ag, ab = GetSuiteAccent()
        local fillAlpha = ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42)
        selfBar:SetBackdropColor(ar * (fillAlpha + 0.10), ag * (fillAlpha + 0.10), ab * (fillAlpha + 0.10), 0.98)
        selfBar:SetBackdropBorderColor(ar, ag, ab, 1.0)
        selfBar.label:SetTextColor(1.0, 1.0, 1.0, 1.0)
        selfBar.chevron:SetVertexColor(1.0, 1.0, 1.0, 1.0)
    end)
    bar:SetScript("OnLeave", function(selfBar)
        selfBar:RefreshValue()
    end)
    bar:SetScript("OnClick", function()
        CloseActiveDropdown()
        local nextExp = not (getExpanded() ~= false)
        setExpanded(nextExp)
        if onToggleLayout then
            onToggleLayout()
        end
    end)

    card.tuneBar = bar
    card.horizontalChevronBar = bar
    return bar
end
local CreateDrawerTuneButton = CreateSubDrawerToggleBar

-- Dynamic vertical stack layout helper for a page (handles bordered Section Boxes + collapsible sub-drawers)
local function LayoutPageCards(page)
    if not page then return end
    if page.sections and #page.sections > 0 then
        local pageY = 0
        for _, sec in ipairs(page.sections) do
            if sec:IsShown() then
                sec:ClearAllPoints()
                sec:SetPoint("TOPLEFT", page, "TOPLEFT", 0, pageY)
                sec:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, pageY)
                local cardY = -54
                for _, card in ipairs(sec.orderedCards or {}) do
                    if card:IsShown() then
                        card:ClearAllPoints()
                        card:SetPoint("TOPLEFT", sec, "TOPLEFT", 14, cardY)
                        card:SetPoint("TOPRIGHT", sec, "TOPRIGHT", -14, cardY)
                        cardY = cardY - (card:GetHeight() or 62) - 6
                    end
                end
                local secH = (math.abs(cardY) - 6) + 12
                sec:SetHeight(math.max(64, secH))
                pageY = pageY - sec:GetHeight() - 14
            end
        end
        local totalH = math.abs(pageY)
        if totalH > 14 then totalH = totalH - 14 + 12 end
        page:SetHeight(math.max(1, totalH))
        return
    end
    if not page.orderedCards then return end
    local y = 0
    for _, card in ipairs(page.orderedCards) do
        if card:IsShown() then
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
            card:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, y)
            y = y - (card:GetHeight() or 58) - 8
        end
    end
    local totalH = math.abs(y)
    if totalH > 8 then totalH = totalH - 8 end
    page:SetHeight(math.max(1, totalH))
end

-- Build Embedded Workspace (Supports both RenderEmbedded(parent) and RenderEmbedded(self, parent))
local function RenderGroupEmbedded(arg1, arg2)
    local parent = (type(arg1) == "table" and type(arg1.GetObjectType) == "function") and arg1 or arg2
    if not parent or type(parent.GetObjectType) ~= "function" then return nil end

    EnsureDB()
    parent:Show()

    if parent.DynamicGroupContainer then
        local existing = parent.DynamicGroupContainer
        existing:ClearAllPoints()
        existing:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        existing:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
        existing:Show()
        DynamicGroup.embeddedRoot = existing
        DynamicGroup:RefreshConfigUI()
        return existing
    end

    local root = CreateFrame("Frame", nil, parent)
    root:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    root:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    root:Show()
    root:SetScript("OnHide", function()
        CloseActiveDropdown()
    end)

    parent.DynamicGroupContainer = root
    DynamicGroup.embeddedRoot = root

    -- Top Segmented 3-Tab Strip (34px bevel at (14,-10)/(-16,-10), 26px inner buttons, 4px insets/gaps)
    local tabBar = CreateFrame("Frame", nil, root, "BackdropTemplate")
    tabBar:SetHeight(34)
    tabBar:SetPoint("TOPLEFT", root, "TOPLEFT", 14, -10)
    tabBar:SetPoint("TOPRIGHT", root, "TOPRIGHT", -16, -10)
    tabBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    tabBar:SetBackdropColor(0.043, 0.051, 0.071, 0.98)
    tabBar:SetBackdropBorderColor(1, 1, 1, 0.08)

    local tabDefs = {
        { id = 1, label = "LFG Premade Filter & Regions" },
        { id = 2, label = "Whisper Auto-Invite & Roles" },
        { id = 3, label = "Party & Keystone Automation" },
    }

    root.tabButtons = {}
    root.tabPages = {}
    root.allControls = {}

    local scrollHolder = CreateObsidianScrollArea(root)
    scrollHolder:ClearAllPoints()
    scrollHolder:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -8)
    scrollHolder:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", 0, -8)
    scrollHolder:SetPoint("BOTTOM", root, "BOTTOM", 0, 10)
    root.tabBar = tabBar
    root.scrollHolder = scrollHolder

    for idx, tDef in ipairs(tabDefs) do
        local tBtn = CreateFrame("Button", nil, tabBar, "BackdropTemplate")
        tBtn:SetHeight(26)
        if idx == 1 then
            tBtn:SetPoint("LEFT", tabBar, "LEFT", 4, 0)
        else
            tBtn:SetPoint("LEFT", root.tabButtons[idx - 1], "RIGHT", 4, 0)
        end
        tBtn:SetWidth(220)
        tBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        tBtn:SetBackdropColor(0.078, 0.090, 0.122, 0.96)
        tBtn:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95)
        tBtn.text = tBtn:CreateFontString(nil, "OVERLAY")
        SetSafeFont(tBtn.text, 11, "")
        tBtn.text:SetPoint("CENTER", 0, 0)
        tBtn.text:SetText(tDef.label)

        local page = CreateFrame("Frame", nil, scrollHolder.content)
        page:SetPoint("TOPLEFT", scrollHolder.content, "TOPLEFT", 0, 0)
        page:SetPoint("TOPRIGHT", scrollHolder.content, "TOPRIGHT", 0, 0)
        page:SetHeight(480)
        page.orderedCards = {}
        page:Hide()
        root.tabPages[idx] = page

        tBtn:SetScript("OnClick", function()
            CloseActiveDropdown()
            EnsureDB().activeSubTab = idx
            DynamicGroup:RefreshConfigUI()
        end)

        root.tabButtons[idx] = tBtn
    end

    local function ReflowGroupTabBar()
        local w = tabBar:GetWidth()
        if not w or w < 100 then
            w = (root:GetWidth() and root:GetWidth() > 100) and (root:GetWidth() - 30) or 806
        end
        if scrollHolder and scrollHolder.content then
            local sfW = (scrollHolder.scrollFrame and scrollHolder.scrollFrame:GetWidth()) or w
            if sfW and sfW > 100 then
                scrollHolder.content:SetWidth(sfW)
            end
        end
        local eachW = math.floor((w - 16) / 3)
        for i, b in ipairs(root.tabButtons) do
            b:ClearAllPoints()
            b:SetHeight(26)
            if i == 1 then
                b:SetPoint("LEFT", tabBar, "LEFT", 4, 0)
                b:SetWidth(eachW)
            elseif i == 2 then
                b:SetPoint("LEFT", root.tabButtons[1], "RIGHT", 4, 0)
                b:SetWidth(eachW)
            else
                b:SetPoint("LEFT", root.tabButtons[2], "RIGHT", 4, 0)
                b:SetPoint("RIGHT", tabBar, "RIGHT", -4, 0)
            end
        end
    end
    tabBar:SetScript("OnSizeChanged", ReflowGroupTabBar)
    tabBar:HookScript("OnShow", function() C_Timer.After(0, ReflowGroupTabBar) end)
    root.ReflowGroupTabBar = ReflowGroupTabBar
    C_Timer.After(0, ReflowGroupTabBar)

    -- ========================================================================
    -- TAB 1: LFG Premade Filter & Regions
    -- ========================================================================
    local page1 = root.tabPages[1]
    local sec1a = CreateSectionBox(
        page1,
        "PREMADE REGION & GROUP FILTERING",
        "Filter Premade LFG search results by datacentre region, leader M+ rating, and party utility.",
        root
    )
    local sec1b = CreateSectionBox(
        page1,
        "SEARCH SORTING, OVERLAYS & QUICK SIGN-UP",
        "Customise result sorting, in-place entry badges, persistent search text, and double-click sign-up.",
        root
    )

    -- Card 1.1: Enable LFG Premade Filter (2-Pill Segmented Switch)
    local c1_enable = CreateCardRow(sec1a, 62,
        "Enable LFG Premade Filter",
        "Enables region filtering, M+ rating filtering, role-fit sorting, and passive composition badges."
    )
    AttachSegmentedSwitchToCard(c1_enable,
        function() return EnsureDB().lfgFilterEnabled end,
        function(val)
            EnsureDB().lfgFilterEnabled = val
            DynamicGroup:RefreshLFGResults()
        end
    )
    sec1a.orderedCards[#sec1a.orderedCards + 1] = c1_enable
    page1.orderedCards[#page1.orderedCards + 1] = c1_enable
    root.allControls[#root.allControls + 1] = c1_enable

    -- Card 1.1b: Show Season Dungeon Portals & Quick-Filter Bar
    local c1_portalBar = CreateCardRow(sec1a, 62,
        "Show Season Dungeon Portals & Quick-Filter Bar",
        "Displays the 8 season Mythic+ dungeon teleports, your current keystone, and one-click dungeon filters above Group Finder."
    )
    AttachSegmentedSwitchToCard(c1_portalBar,
        function() return EnsureDB().showPortalBar ~= false end,
        function(val)
            EnsureDB().showPortalBar = val
            DynamicGroup:UpdatePortalBar()
        end
    )
    sec1a.orderedCards[#sec1a.orderedCards + 1] = c1_portalBar
    page1.orderedCards[#page1.orderedCards + 1] = c1_portalBar
    root.allControls[#root.allControls + 1] = c1_portalBar

    -- Card 1.2: Multi-Select Region Filter Pills ([check OCE] [check US-West] ...)
    local c1_regions = CreateCardRow(sec1a, 102,
        "Datacentre Region Filter Pills",
        "Click to toggle datacentre regions shown in Premade LFG search results."
    )
    root.regionPills = {}
    local pillContainer = CreateFrame("Frame", nil, c1_regions)
    pillContainer:SetPoint("TOPLEFT", c1_regions, "TOPLEFT", 14, -48)
    pillContainer:SetPoint("BOTTOMRIGHT", c1_regions, "BOTTOMRIGHT", -14, 12)

    for i, rKey in ipairs(REGION_ORDER) do
        local meta = REGION_META[rKey]
        local pill = CreateFrame("Button", nil, pillContainer, "BackdropTemplate")
        pill:SetHeight(26)
        pill:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })

        pill.check = pill:CreateTexture(nil, "ARTWORK")
        pill.check:SetSize(6, 6)
        pill.check:SetPoint("LEFT", pill, "LEFT", 9, 0)
        pill.check:SetColorTexture(1, 1, 1, 0.98)
        DisableTexPixelSnap(pill.check)

        pill.dot = pill:CreateTexture(nil, "ARTWORK")
        pill.dot:SetSize(6, 6)
        pill.dot:SetPoint("LEFT", pill, "LEFT", 9, 0)
        pill.dot:SetTexture("Interface\\Buttons\\WHITE8x8")
        DisableTexPixelSnap(pill.dot)

        pill.label = pill:CreateFontString(nil, "OVERLAY")
        SetSafeFont(pill.label, 11, "")
        pill.label:SetText(meta.pillLabel)

        function pill:RefreshPill()
            SetSafeFont(self.label, 11, "")
            local isOn = (EnsureDB().enabledRegions[rKey] ~= false)
            local rc = GetRegionColor(rKey)
            if isOn then
                self:SetBackdropColor(rc.r * 0.16, rc.g * 0.16, rc.b * 0.16, 0.96)
                self:SetBackdropBorderColor(rc.r, rc.g, rc.b, 0.92)
                self.dot:Hide()
                self.check:ClearAllPoints()
                self.check:SetPoint("LEFT", self, "LEFT", 8, 0)
                self.check:SetVertexColor(rc.r, rc.g, rc.b, 1)
                self.check:Show()
                self.label:ClearAllPoints()
                self.label:SetPoint("LEFT", self.check, "RIGHT", 6, 0)
                self.label:SetTextColor(rc.r, rc.g, rc.b, 1.0)
            else
                self:SetBackdropColor(0.059, 0.071, 0.094, 0.92)
                self:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95)
                self.check:Hide()
                self.dot:ClearAllPoints()
                self.dot:SetPoint("LEFT", self, "LEFT", 9, 0)
                self.dot:SetVertexColor(rc.r, rc.g, rc.b, 0.95)
                self.dot:Show()
                self.label:ClearAllPoints()
                self.label:SetPoint("LEFT", self.dot, "RIGHT", 7, 0)
                self.label:SetTextColor(0.62, 0.68, 0.76, 1.0)
            end
        end

        pill:SetScript("OnEnter", function(self)
            local rc = GetRegionColor(rKey)
            self:SetBackdropBorderColor(rc.r, rc.g, rc.b, 1.0)
            if _G.GameTooltip then
                _G.GameTooltip:SetOwner(self, "ANCHOR_TOP")
                _G.GameTooltip:ClearLines()
                local isOn = (EnsureDB().enabledRegions[rKey] ~= false)
                _G.GameTooltip:AddLine(FormatRegionTag(rKey, meta.badge) .. " " .. meta.title, 1, 1, 1)
                _G.GameTooltip:AddLine(
                    isOn and "Status: |cFF34D399Active (Shown in LFG)|r" or "Status: |cFF94A3B8Filtered (Hidden from LFG)|r",
                    0.75, 0.82, 0.90
                )
                _G.GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Toggle region in Premade LFG search results.|r", 0.886, 0.910, 0.941)
                _G.GameTooltip:Show()
            end
        end)
        pill:SetScript("OnLeave", function(self)
            if _G.GameTooltip then _G.GameTooltip:Hide() end
            self:RefreshPill()
        end)

        pill:SetScript("OnClick", function(self)
            CloseActiveDropdown()
            local d = EnsureDB()
            d.enabledRegions[rKey] = not (d.enabledRegions[rKey] ~= false)
            self:RefreshPill()
            DynamicGroup:RefreshLFGResults()
            if _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
                pcall(_G.DynamicSuite.RefreshHeaderStatus)
            end
        end)

        root.regionPills[i] = pill
    end

    pillContainer:SetScript("OnSizeChanged", function(self, w)
        if not w or w < 120 then return end
        local gap = 6
        local equalW = math.floor((w - (gap * 5)) / 6)
        local xCursor = 0
        for i, pill in ipairs(root.regionPills) do
            SetSafeFont(pill.label, 11, "")
            local minW = math.ceil((pill.label:GetStringWidth() or 40) + 32)
            local pillW = math.max(equalW, minW)
            pill:ClearAllPoints()
            pill:SetWidth(pillW)
            pill:SetPoint("LEFT", self, "LEFT", xCursor, 0)
            xCursor = xCursor + pillW + gap
        end
    end)

    sec1a.orderedCards[#sec1a.orderedCards + 1] = c1_regions
    page1.orderedCards[#page1.orderedCards + 1] = c1_regions

    -- Card 1.3: Hide Full 5/5 Groups (2-Pill Segmented Switch)
    local c1_hideFull = CreateCardRow(sec1a, 62,
        "Hide Full 5/5 Groups",
        "Automatically hides full 5/5 party listings and delisted groups from search results."
    )
    AttachSegmentedSwitchToCard(c1_hideFull,
        function() return EnsureDB().hideFullGroups end,
        function(val)
            EnsureDB().hideFullGroups = val
            DynamicGroup:RefreshLFGResults()
        end
    )
    sec1a.orderedCards[#sec1a.orderedCards + 1] = c1_hideFull
    page1.orderedCards[#page1.orderedCards + 1] = c1_hideFull
    root.allControls[#root.allControls + 1] = c1_hideFull

    -- Card 1.5: Minimum M+ Rating Filter (EUI-Style Dropdown)
    local c1_score = CreateCardRow(sec1a, 62,
        "Minimum M+ Rating Filter",
        "Hides Premade LFG groups whose leader falls below your target Mythic+ rating threshold."
    )
    AttachDropdownToCard(c1_score, 270, {
        { value = 0,    label = "No Minimum (0+)" },
        { value = 1500, label = "1500+ Mythic+ Rating" },
        { value = 2000, label = "2000+ Mythic+ Rating" },
        { value = 2500, label = "2500+ Mythic+ Rating" },
        { value = 2800, label = "2800+ Mythic+ Rating" },
        { value = 3000, label = "3000+ Mythic+ Rating" },
    }, function() return tonumber(EnsureDB().minLeaderScore) or 0 end, function(val)
        EnsureDB().minLeaderScore = val
        DynamicGroup:RefreshLFGResults()
    end)
    sec1a.orderedCards[#sec1a.orderedCards + 1] = c1_score
    page1.orderedCards[#page1.orderedCards + 1] = c1_score
    root.allControls[#root.allControls + 1] = c1_score

    -- Card 1.6: Premade Group Filters (Role, Class & Utility) (Multi-Toggle Popover Button)
    local c1_roleFit = CreateCardRow(sec1a, 62,
        "Premade Group Filters (Role, Class & Utility)",
        "Choose Tank/Healer/DPS role openings, duplicate-class checks, Tank/Healer presence, and Lust/CR utility."
    )
    local roleFilterBtn = CreateFrame("Button", nil, c1_roleFit, "BackdropTemplate")
    roleFilterBtn:SetSize(270, 26)
    roleFilterBtn:SetPoint("TOPRIGHT", c1_roleFit, "TOPRIGHT", -14, -17)
    roleFilterBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    roleFilterBtn:SetBackdropColor(0.059, 0.071, 0.094, 0.98)
    roleFilterBtn:SetBackdropBorderColor(0.145, 0.165, 0.212, 1.00)
    AnchorCardTextToRightWidget(c1_roleFit, roleFilterBtn)

    roleFilterBtn.label = roleFilterBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(roleFilterBtn.label, 11, "")
    roleFilterBtn.label:SetPoint("LEFT", 10, 0)
    roleFilterBtn.label:SetPoint("RIGHT", -24, 0)
    roleFilterBtn.label:SetJustifyH("LEFT")
    roleFilterBtn.label:SetWordWrap(false)
    roleFilterBtn.label:SetTextColor(0.92, 0.95, 0.99)

    roleFilterBtn.chevron = roleFilterBtn:CreateTexture(nil, "ARTWORK")
    roleFilterBtn.chevron:SetSize(12, 12)
    roleFilterBtn.chevron:SetPoint("RIGHT", roleFilterBtn, "RIGHT", -8, 0)
    roleFilterBtn.chevron:SetTexture(ICON_CHEVRON_DOWN)

    function roleFilterBtn:SetChevronOpen(isOpen)
        self.isOpen = isOpen and true or false
        local ar, ag, ab = GetSuiteAccent()
        self.chevron:SetTexture(isOpen and ICON_CHEVRON_UP or ICON_CHEVRON_DOWN)
        self.chevron:SetVertexColor(ar, ag, ab, 1)
        if isOpen then
            self:SetBackdropBorderColor(ar, ag, ab, 0.95)
        else
            self:SetBackdropBorderColor(0.145, 0.165, 0.212, 1.00)
        end
    end

    function roleFilterBtn:RefreshValue()
        SetSafeFont(self.label, 11, "")
        local summary = GetUtilityFilterSummary(EnsureDB(), false)
        self.label:SetText(summary)
        self:SetChevronOpen(activeFilterPopover and activeFilterPopover:IsShown() and activeFilterPopover.anchorBtn == self)
    end

    roleFilterBtn:SetScript("OnEnter", function(self)
        local ar, ag, ab = GetSuiteAccent()
        self:SetBackdropBorderColor(ar, ag, ab, 0.85)
    end)
    roleFilterBtn:SetScript("OnLeave", function(self)
        if not (activeFilterPopover and activeFilterPopover:IsShown() and activeFilterPopover.anchorBtn == self) then
            self:SetBackdropBorderColor(0.145, 0.165, 0.212, 1.00)
        end
    end)
    roleFilterBtn:SetScript("OnClick", function(self)
        ShowFilterPopover(self)
    end)
    roleFilterBtn:SetScript("OnHide", function(self)
        if activeFilterPopover and activeFilterPopover.anchorBtn == self then
            CloseActiveDropdown()
        end
    end)
    roleFilterBtn:RefreshValue()
    c1_roleFit.dropdown = roleFilterBtn

    sec1a.orderedCards[#sec1a.orderedCards + 1] = c1_roleFit
    page1.orderedCards[#page1.orderedCards + 1] = c1_roleFit
    root.allControls[#root.allControls + 1] = c1_roleFit

    -- Card 1.4: Sort LFG Results By (EUI-Style Dropdown)
    local c1_sort = CreateCardRow(sec1b, 62,
        "Sort LFG Results By",
        "Prioritises open groups needing your active specialisation role, Lust/CR utility, and Leader M+ score."
    )
    AttachDropdownToCard(c1_sort, 300, {
        { value = "SMART_HIDE_FULL", label = "Smart Sort (Role Fit > Lust/CR > Leader IO)" },
        { value = "SCORE_DESC",      label = "Leader Mythic+ Rating (High to Low)" },
        { value = "OPEN_SLOTS",      label = "Group Size (Most Open Slots First)" },
        { value = "BLIZZARD",        label = "Standard Blizzard Order" },
    }, function() return EnsureDB().sortMode or "SMART_HIDE_FULL" end, function(val)
        local d = EnsureDB()
        d.sortMode = val
        d.smartSort = (val ~= "BLIZZARD")
        DynamicGroup:RefreshLFGResults()
    end)
    sec1b.orderedCards[#sec1b.orderedCards + 1] = c1_sort
    page1.orderedCards[#page1.orderedCards + 1] = c1_sort
    root.allControls[#root.allControls + 1] = c1_sort

    -- Card 1.7: Show Region & Leader IO Badge (2-Pill Segmented Switch)
    local c1_badges = CreateCardRow(sec1b, 62,
        "Show Region & Leader IO Badge",
        "Displays the leader's datacentre region (OCE, USE, USW, USC, LA, BR) and Mythic+ rating in the top-right corner of each Premade Group listing."
    )
    AttachSegmentedSwitchToCard(c1_badges,
        function()
            local d = EnsureDB()
            return (d.showEntryOverlay ~= false) and (d.overlayMode ~= "OFF")
        end,
        function(val)
            local d = EnsureDB()
            d.showEntryOverlay = val and true or false
            d.overlayMode = val and "COMPACT" or "OFF"
            DynamicGroup:RefreshLFGResults()
        end
    )
    sec1b.orderedCards[#sec1b.orderedCards + 1] = c1_badges
    page1.orderedCards[#page1.orderedCards + 1] = c1_badges
    root.allControls[#root.allControls + 1] = c1_badges

    -- Card 1.8: Remember Last Search Text (2-Pill Segmented Switch)
    local c1_remember = CreateCardRow(sec1b, 62,
        "Remember Last Search Text",
        "Automatically restores your last Premade LFG search filter text when reopening the Group Finder."
    )
    AttachSegmentedSwitchToCard(c1_remember,
        function() return EnsureDB().rememberSearchText end,
        function(val) EnsureDB().rememberSearchText = val end
    )
    sec1b.orderedCards[#sec1b.orderedCards + 1] = c1_remember
    page1.orderedCards[#page1.orderedCards + 1] = c1_remember
    root.allControls[#root.allControls + 1] = c1_remember

    -- Card 1.9: One-Click Double-Click Sign Up (2-Pill Segmented Switch)
    local c1_dblClick = CreateCardRow(sec1b, 62,
        "One-Click Double-Click Sign Up",
        "Double-click any Premade LFG search result entry to open the Sign-Up dialog immediately."
    )
    AttachSegmentedSwitchToCard(c1_dblClick,
        function() return EnsureDB().doubleClickSignUp end,
        function(val) EnsureDB().doubleClickSignUp = val end
    )
    sec1b.orderedCards[#sec1b.orderedCards + 1] = c1_dblClick
    page1.orderedCards[#page1.orderedCards + 1] = c1_dblClick
    root.allControls[#root.allControls + 1] = c1_dblClick

    -- ========================================================================
    -- TAB 2: Whisper Auto-Invite & Roles
    -- ========================================================================
    local page2 = root.tabPages[2]
    local sec2a = CreateSectionBox(
        page2,
        "WHISPER KEYWORD AUTO-INVITE ENGINE",
        "Automatically invite players who whisper your trigger keywords and scale 5-player parties into raids.",
        root
    )
    local sec2b = CreateSectionBox(
        page2,
        "RAID & PARTY COORDINATION TOOLS",
        "Automatic party invites, trusted assistant promotions, and instant role check confirmations.",
        root
    )

    -- Card 2.1: Enable Whisper Auto-Invite + Hybrid Inline Sub-Drawer (Item #37)
    local c2_whisper = CreateCardRow(sec2a, 62,
        "Enable Whisper Auto-Invite",
        "Automatically sends a party/raid invite when a player whispers one of your trigger keywords."
    )

    local whisperSwitch = AttachSegmentedSwitchToCard(c2_whisper,
        function() return EnsureDB().enableWhisperInvite end,
        function(val)
            local db = EnsureDB()
            db.enableWhisperInvite = val
            if val then
                db.whisperDrawerExpanded = true
            end
            SyncWhisperInviteSettings(db)
            if root.UpdateWhisperDrawerLayout then root.UpdateWhisperDrawerLayout() end
            if root.scrollHolder and root.scrollHolder.UpdateThumb then
                root.scrollHolder.UpdateThumb()
            end
        end
    )
    AnchorCardTextToRightWidget(c2_whisper, whisperSwitch)

    local whisperBar = CreateSubDrawerToggleBar(
        c2_whisper,
        2,
        function() return EnsureDB().whisperDrawerExpanded ~= false end,
        function(exp) EnsureDB().whisperDrawerExpanded = exp end,
        function()
            if root.UpdateWhisperDrawerLayout then root.UpdateWhisperDrawerLayout() end
            if root.scrollHolder and root.scrollHolder.UpdateThumb then
                root.scrollHolder.UpdateThumb()
            end
        end
    )

    -- Recessed Sub-Drawer Container holding 2 Nested Sub-Setting Cards (PANEL_BG #090A0D, 1px CELL_BORDER, 2px Suite Accent left bar, 5x5 pip)
    local whisperDrawer = CreateFrame("Frame", nil, c2_whisper)
    whisperDrawer:SetPoint("TOPLEFT", c2_whisper, "TOPLEFT", 10, -82)
    whisperDrawer:SetPoint("TOPRIGHT", c2_whisper, "TOPRIGHT", -10, -82)
    whisperDrawer:SetHeight(88)

    local kwCard = CreateFrame("Frame", nil, whisperDrawer, "BackdropTemplate")
    kwCard:SetPoint("TOPLEFT", whisperDrawer, "TOPLEFT", 0, 0)
    kwCard:SetPoint("TOPRIGHT", whisperDrawer, "TOPRIGHT", 0, 0)
    kwCard:SetHeight(42)
    kwCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    kwCard:SetBackdropColor(0.035, 0.039, 0.051, 0.99) -- PANEL_BG #090A0D
    kwCard:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95) -- CELL_BORDER #252A36

    whisperDrawer.accentBar = kwCard:CreateTexture(nil, "OVERLAY")
    whisperDrawer.accentBar:SetWidth(2)
    whisperDrawer.accentBar:SetPoint("TOPLEFT", kwCard, "TOPLEFT", 0, 0)
    whisperDrawer.accentBar:SetPoint("BOTTOMLEFT", kwCard, "BOTTOMLEFT", 0, 0)

    local scopeCard = CreateFrame("Frame", nil, whisperDrawer, "BackdropTemplate")
    scopeCard:SetPoint("TOPLEFT", whisperDrawer, "TOPLEFT", 0, -46)
    scopeCard:SetPoint("TOPRIGHT", whisperDrawer, "TOPRIGHT", 0, -46)
    scopeCard:SetHeight(42)
    scopeCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    scopeCard:SetBackdropColor(0.035, 0.039, 0.051, 0.99) -- PANEL_BG #090A0D
    scopeCard:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95) -- CELL_BORDER #252A36

    whisperDrawer.accentBar2 = scopeCard:CreateTexture(nil, "OVERLAY")
    whisperDrawer.accentBar2:SetWidth(2)
    whisperDrawer.accentBar2:SetPoint("TOPLEFT", scopeCard, "TOPLEFT", 0, 0)
    whisperDrawer.accentBar2:SetPoint("BOTTOMLEFT", scopeCard, "BOTTOMLEFT", 0, 0)

    -- Sub-Row 1: 5x5 Suite Accent Pip + Trigger Keywords
    local kwPip = kwCard:CreateTexture(nil, "ARTWORK")
    kwPip:SetSize(5, 5)
    kwPip:SetPoint("LEFT", kwCard, "LEFT", 14, 0)
    whisperDrawer.kwPip = kwPip

    local kwBox = CreateFrame("EditBox", nil, kwCard, "BackdropTemplate")
    kwBox:SetSize(190, 24)
    kwBox:SetPoint("RIGHT", kwCard, "RIGHT", -78, 0)
    kwBox:SetAutoFocus(false)
    kwBox:SetMaxLetters(100)
    kwBox:SetTextInsets(8, 8, 0, 0)
    SetSafeFont(kwBox, 11, "")
    kwBox:SetTextColor(0.95, 0.97, 1.00)
    kwBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    kwBox:SetBackdropColor(0.04, 0.05, 0.08, 0.98)
    kwBox:SetBackdropBorderColor(0.18, 0.21, 0.28, 1.00)
    kwBox:SetText(EnsureDB().whisperKeywords or "inv, invite, 123")

    local kwLabel = kwCard:CreateFontString(nil, "OVERLAY")
    SetSafeFont(kwLabel, 11, "")
    kwLabel:SetPoint("LEFT", kwPip, "RIGHT", 8, 0)
    kwLabel:SetPoint("RIGHT", kwBox, "LEFT", -12, 0)
    kwLabel:SetJustifyH("LEFT")
    kwLabel:SetTextColor(0.84, 0.89, 0.95)
    kwLabel:SetText("Trigger Keywords")

    local saveKwBtn = CreateFrame("Button", nil, kwCard, "BackdropTemplate")
    saveKwBtn:SetSize(60, 24)
    saveKwBtn:SetPoint("RIGHT", kwCard, "RIGHT", -12, 0)
    saveKwBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    saveKwBtn.label = saveKwBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(saveKwBtn.label, 11, "")
    saveKwBtn.label:SetPoint("CENTER", 0, 0)
    saveKwBtn.label:SetText("Save")

    local function CommitKeywords()
        local val = kwBox:GetText() or "inv, invite, 123"
        if val:match("^%s*$") then val = "inv, invite, 123" end
        EnsureDB().whisperKeywords = val
        kwBox:SetText(val)
        kwBox:ClearFocus()
        PrintMsg("Saved whisper auto-invite keywords: " .. val)
    end
    kwBox:SetScript("OnEnterPressed", CommitKeywords)
    kwBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    saveKwBtn:SetScript("OnClick", CommitKeywords)
    root.kwEditBox = kwBox
    root.saveKwBtn = saveKwBtn

    -- Sub-Row 2: 5x5 Suite Accent Pip + Accept Whispers From: [ Anyone | Guild & Friends Only ]
    local scopePip = scopeCard:CreateTexture(nil, "ARTWORK")
    scopePip:SetSize(5, 5)
    scopePip:SetPoint("LEFT", scopeCard, "LEFT", 14, 0)
    whisperDrawer.scopePip = scopePip

    local scopeWrap = CreateFrame("Frame", nil, scopeCard, "BackdropTemplate")
    scopeWrap:SetSize(272, 24)
    scopeWrap:SetPoint("RIGHT", scopeCard, "RIGHT", -12, 0)
    scopeWrap:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    scopeWrap:SetBackdropColor(0.04, 0.05, 0.08, 0.98)
    scopeWrap:SetBackdropBorderColor(0.18, 0.21, 0.28, 1.00)

    local scopeLabel = scopeCard:CreateFontString(nil, "OVERLAY")
    SetSafeFont(scopeLabel, 11, "")
    scopeLabel:SetPoint("LEFT", scopePip, "RIGHT", 8, 0)
    scopeLabel:SetPoint("RIGHT", scopeWrap, "LEFT", -12, 0)
    scopeLabel:SetJustifyH("LEFT")
    scopeLabel:SetTextColor(0.84, 0.89, 0.95)
    scopeLabel:SetText("Accept Whispers From")

    local anyBtn = CreateFrame("Button", nil, scopeWrap, "BackdropTemplate")
    anyBtn:SetHeight(22)
    anyBtn:SetPoint("LEFT", scopeWrap, "LEFT", 1, 0)
    anyBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    anyBtn.check = anyBtn:CreateTexture(nil, "ARTWORK")
    anyBtn.check:SetSize(11, 11)
    anyBtn.check:SetTexture(ICON_CHECK)
    anyBtn.check:SetPoint("LEFT", anyBtn, "LEFT", 8, 0)
    anyBtn.label = anyBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(anyBtn.label, 10, "")
    anyBtn.label:SetText("Anyone")

    local gfBtn = CreateFrame("Button", nil, scopeWrap, "BackdropTemplate")
    gfBtn:SetHeight(22)
    gfBtn:SetPoint("RIGHT", scopeWrap, "RIGHT", -1, 0)
    gfBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    gfBtn.check = gfBtn:CreateTexture(nil, "ARTWORK")
    gfBtn.check:SetSize(11, 11)
    gfBtn.check:SetTexture(ICON_CHECK)
    gfBtn.check:SetPoint("LEFT", gfBtn, "LEFT", 8, 0)
    gfBtn.label = gfBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(gfBtn.label, 10, "")
    gfBtn.label:SetText("Guild & Friends Only")

    function scopeWrap:RefreshScope()
        SetSafeFont(anyBtn.label, 10, "")
        SetSafeFont(gfBtn.label, 10, "")

        local rawAny = (anyBtn.label.GetUnboundedStringWidth and anyBtn.label:GetUnboundedStringWidth()) or anyBtn.label:GetStringWidth() or 44
        local rawGf  = (gfBtn.label.GetUnboundedStringWidth and gfBtn.label:GetUnboundedStringWidth()) or gfBtn.label:GetStringWidth() or 116
        local anyW = math.max(88, math.ceil(rawAny + 34))
        local gfW  = math.max(158, math.ceil(rawGf + 34))
        local totalScopeW = anyW + gfW + 3
        anyBtn:SetWidth(anyW)
        gfBtn:SetWidth(gfW)
        self:SetSize(totalScopeW, 24)
        kwBox:ClearAllPoints()
        kwBox:SetPoint("RIGHT", kwCard, "RIGHT", -78, 0)
        kwBox:SetWidth(totalScopeW - 66)

        local db = EnsureDB()
        local isAnyone = (db.whisperInviteScope == "ANYONE")
        local ar, ag, ab = GetSuiteAccent()
        whisperDrawer.accentBar:SetColorTexture(ar, ag, ab, 1)
        if whisperDrawer.accentBar2 then whisperDrawer.accentBar2:SetColorTexture(ar, ag, ab, 1) end
        kwPip:SetColorTexture(ar, ag, ab, 0.90)
        scopePip:SetColorTexture(ar, ag, ab, 0.90)
        saveKwBtn:SetBackdropColor(ar * 0.20, ag * 0.20, ab * 0.20, 0.96)
        saveKwBtn:SetBackdropBorderColor(ar, ag, ab, 0.90)
        saveKwBtn.label:SetTextColor(ar, ag, ab, 1)

        if isAnyone then
            anyBtn:SetBackdropColor(ar * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), ag * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), ab * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), 0.96)
            anyBtn:SetBackdropBorderColor(ar, ag, ab, 0.95)
            anyBtn.check:ClearAllPoints()
            anyBtn.check:SetPoint("LEFT", anyBtn, "LEFT", 8, 0)
            anyBtn.check:SetVertexColor(ar, ag, ab, 1)
            anyBtn.check:Hide()
            anyBtn.label:ClearAllPoints()
            anyBtn.label:SetPoint("CENTER", anyBtn, "CENTER", 0, 0)
            anyBtn.label:SetTextColor(0.98, 0.99, 1.00)

            gfBtn:SetBackdropColor(0, 0, 0, 0)
            gfBtn:SetBackdropBorderColor(0, 0, 0, 0)
            gfBtn.check:Hide()
            gfBtn.label:ClearAllPoints()
            gfBtn.label:SetPoint("CENTER", gfBtn, "CENTER", 0, 0)
            gfBtn.label:SetTextColor(0.55, 0.60, 0.68)
        else
            anyBtn:SetBackdropColor(0, 0, 0, 0)
            anyBtn:SetBackdropBorderColor(0, 0, 0, 0)
            anyBtn.check:Hide()
            anyBtn.label:ClearAllPoints()
            anyBtn.label:SetPoint("CENTER", anyBtn, "CENTER", 0, 0)
            anyBtn.label:SetTextColor(0.55, 0.60, 0.68)

            gfBtn:SetBackdropColor(ar * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), ag * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), ab * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), 0.96)
            gfBtn:SetBackdropBorderColor(ar, ag, ab, 0.95)
            gfBtn.check:ClearAllPoints()
            gfBtn.check:SetPoint("LEFT", gfBtn, "LEFT", 8, 0)
            gfBtn.check:SetVertexColor(ar, ag, ab, 1)
            gfBtn.check:Hide()
            gfBtn.label:ClearAllPoints()
            gfBtn.label:SetPoint("CENTER", gfBtn, "CENTER", 0, 0)
            gfBtn.label:SetTextColor(0.98, 0.99, 1.00)
        end
    end

    anyBtn:SetScript("OnClick", function()
        local db = EnsureDB()
        db.whisperInviteScope = "ANYONE"
        SyncWhisperInviteSettings(db)
        scopeWrap:RefreshScope()
    end)
    gfBtn:SetScript("OnClick", function()
        local db = EnsureDB()
        db.whisperInviteScope = "GUILD_AND_FRIENDS"
        SyncWhisperInviteSettings(db)
        scopeWrap:RefreshScope()
    end)

    c2_whisper.whisperDrawer = whisperDrawer
    c2_whisper.scopeWrap = scopeWrap

    local function UpdateWhisperDrawerLayout()
        local db = EnsureDB()
        local isOn = db.enableWhisperInvite and true or false
        local isExp = (db.whisperDrawerExpanded ~= false)
        local ar, ag, ab = GetSuiteAccent()

        whisperDrawer.accentBar:SetColorTexture(ar, ag, ab, 1)
        if whisperDrawer.accentBar2 then whisperDrawer.accentBar2:SetColorTexture(ar, ag, ab, 1) end
        kwPip:SetColorTexture(ar, ag, ab, 0.90)
        scopePip:SetColorTexture(ar, ag, ab, 0.90)
        saveKwBtn:SetBackdropColor(ar * 0.20, ag * 0.20, ab * 0.20, 0.96)
        saveKwBtn:SetBackdropBorderColor(ar, ag, ab, 0.90)
        saveKwBtn.label:SetTextColor(ar, ag, ab, 1)

        AnchorCardTextToRightWidget(c2_whisper, whisperSwitch)
        if isOn then
            whisperBar:Show()
            whisperBar:RefreshValue()
            if isExp then
                whisperDrawer:Show()
                c2_whisper:SetHeight(178)
                c2_whisper:SetBackdropBorderColor(ar, ag, ab, 0.85)
            else
                whisperDrawer:Hide()
                c2_whisper:SetHeight(84)
                c2_whisper:SetBackdropBorderColor(0.145, 0.165, 0.212, 1.00)
            end
        else
            whisperBar:Hide()
            whisperDrawer:Hide()
            c2_whisper:SetHeight(62)
            c2_whisper:SetBackdropBorderColor(0.145, 0.165, 0.212, 1.00)
        end
        scopeWrap:RefreshScope()
        LayoutPageCards(page2)
    end
    root.UpdateWhisperDrawerLayout = UpdateWhisperDrawerLayout
    sec2a.orderedCards[#sec2a.orderedCards + 1] = c2_whisper
    page2.orderedCards[#page2.orderedCards + 1] = c2_whisper
    root.allControls[#root.allControls + 1] = c2_whisper

    -- Card 2.2: Auto-Convert Party to Raid Above 5 Players
    local c2_convert = CreateCardRow(sec2a, 62,
        "Auto-Convert Party to Raid Above 5 Players",
        "Automatically converts your 5-player party into a raid when a 6th player whispers your invite keyword."
    )
    AttachSegmentedSwitchToCard(c2_convert,
        function() return EnsureDB().autoConvertToRaid end,
        function(val) EnsureDB().autoConvertToRaid = val end
    )
    sec2a.orderedCards[#sec2a.orderedCards + 1] = c2_convert
    page2.orderedCards[#page2.orderedCards + 1] = c2_convert
    root.allControls[#root.allControls + 1] = c2_convert

    -- Card 2.3: Auto-Promote Friends/Tanks
    local c2_promote = CreateCardRow(sec2b, 62,
        "Auto-Promote Friends/Tanks",
        "Automatically grants Raid Assistant (A) to Battle.net Friends, Guild members, and Tanks when you are Leader."
    )
    AttachSegmentedSwitchToCard(c2_promote,
        function() return EnsureDB().autoPromoteFriendsTanks end,
        function(val)
            EnsureDB().autoPromoteFriendsTanks = val
            if val then HandleAutoPromoteRoster() end
        end
    )
    sec2b.orderedCards[#sec2b.orderedCards + 1] = c2_promote
    page2.orderedCards[#page2.orderedCards + 1] = c2_promote
    root.allControls[#root.allControls + 1] = c2_promote

    -- Card 2.4: Auto-Accept Role Check
    local c2_roleCheck = CreateCardRow(sec2b, 62,
        "Auto-Accept Role Check",
        "Automatically confirms your active specialisation role when a party or raid leader initiates a Role Check."
    )
    AttachSegmentedSwitchToCard(c2_roleCheck,
        function() return EnsureDB().autoAcceptRoleCheck end,
        function(val) EnsureDB().autoAcceptRoleCheck = val end
    )
    sec2b.orderedCards[#sec2b.orderedCards + 1] = c2_roleCheck
    page2.orderedCards[#page2.orderedCards + 1] = c2_roleCheck
    root.allControls[#root.allControls + 1] = c2_roleCheck

    -- ========================================================================
    -- TAB 3: Party & Keystone Automation
    -- ========================================================================
    local page3 = root.tabPages[3]
    local sec3a = CreateSectionBox(
        page3,
        "INCOMING INVITES & KEYSTONE PEDESTAL",
        "Auto-accept invites from trusted contacts while protecting active queues, and auto-slot M+ keystones.",
        root
    )
    local sec3b = CreateSectionBox(
        page3,
        "ONE-CLICK SIGN-UP, AUTO-ROLE & SEARCH REFRESH",
        "Streamline Premade LFG applications with instant sign-up, spec role selection, and note pre-filling.",
        root
    )

    -- Card 3.1: Incoming Auto-Accept Party & Raid Invites (EUI-Style Dropdown)
    local c3_incoming = CreateCardRow(sec3a, 62,
        "Incoming Auto-Accept Party & Raid Invites",
        "Instantly accepts group invitations from trusted Friends, Battle.net contacts, or Guild members."
    )
    AttachDropdownToCard(c3_incoming, 305, {
        { value = "FRIENDS_AND_GUILD", label = "Friends, Battle.net & Guild (Recommended)" },
        { value = "FRIENDS_ONLY",      label = "Friends & Battle.net Only" },
        { value = "GUILD_ONLY",        label = "Guild Members Only" },
        { value = "OFF",               label = "Disabled (Manual Accept)" },
    }, function() return EnsureDB().incomingInviteMode or "FRIENDS_AND_GUILD" end, function(val)
        EnsureDB().incomingInviteMode = val
    end)
    sec3a.orderedCards[#sec3a.orderedCards + 1] = c3_incoming
    page3.orderedCards[#page3.orderedCards + 1] = c3_incoming
    root.allControls[#root.allControls + 1] = c3_incoming

    -- Card 3.2: Active LFG & Delve Queue Protection Shield
    local c3_shield = CreateCardRow(sec3a, 62,
        "Active LFG & Delve Queue Protection Shield",
        "Prevents auto-accepting party invites while queued in Dungeon Finder, Raid Finder, LFG, or PvP."
    )
    AttachSegmentedSwitchToCard(c3_shield,
        function() return EnsureDB().protectActiveQueues end,
        function(val) EnsureDB().protectActiveQueues = val end
    )
    sec3a.orderedCards[#sec3a.orderedCards + 1] = c3_shield
    page3.orderedCards[#page3.orderedCards + 1] = c3_shield
    root.allControls[#root.allControls + 1] = c3_shield

    -- Card 3.3: Auto-Insert Mythic+ Keystone
    local c3_keystone = CreateCardRow(sec3a, 62,
        "Auto-Insert Mythic+ Keystone",
        "Automatically slots your Mythic+ Keystone from your bags when opening the Font of Power pedestal."
    )
    AttachSegmentedSwitchToCard(c3_keystone,
        function() return EnsureDB().autoInsertKeystone end,
        function(val) EnsureDB().autoInsertKeystone = val end
    )
    sec3a.orderedCards[#sec3a.orderedCards + 1] = c3_keystone
    page3.orderedCards[#page3.orderedCards + 1] = c3_keystone
    root.allControls[#root.allControls + 1] = c3_keystone

    -- Card 3.3c: Dungeon Joined & Group Full Teleport Toast
    local c3_tpToast = CreateCardRow(sec3a, 94,
        "Dungeon Joined & Group Full Teleport Toast",
        "Shows a quick-teleport toast when your Premade Group application is accepted, plays a chime as members join, and alerts you once the group reaches 5/5."
    )
    local tpToastSwitch = AttachSegmentedSwitchToCard(c3_tpToast,
        function() return EnsureDB().showGroupTeleportToast ~= false end,
        function(val)
            EnsureDB().showGroupTeleportToast = val and true or false
            if not val then
                DynamicGroup:HideTeleportToast()
            end
        end
    )
    AnchorCardTextToRightWidget(c3_tpToast, tpToastSwitch)

    local function CreateToastPreviewBtn(btnLabel, anchorRel, offsetX, onClickFn)
        local btn = CreateFrame("Button", nil, c3_tpToast, "BackdropTemplate")
        btn:SetSize(96, 22)
        if anchorRel then
            btn:SetPoint("LEFT", anchorRel, "RIGHT", offsetX or 8, 0)
        else
            btn:SetPoint("BOTTOMLEFT", c3_tpToast, "BOTTOMLEFT", 14, 10)
        end
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(0.043, 0.051, 0.071, 0.96) -- #0B0D12
        btn:SetBackdropBorderColor(0.976, 0.451, 0.086, 0.72) -- #F97316
        btn.label = btn:CreateFontString(nil, "OVERLAY")
        SetSafeFont(btn.label, 10, "")
        btn.label:SetPoint("CENTER", 0, 0)
        btn.label:SetText(btnLabel)
        btn.label:SetTextColor(0.96, 0.98, 1.00, 1)
        btn:SetScript("OnEnter", function(s)
            s:SetBackdropColor(0.16, 0.09, 0.04, 0.96)
            s:SetBackdropBorderColor(0.976, 0.451, 0.086, 1.0)
        end)
        btn:SetScript("OnLeave", function(s)
            s:SetBackdropColor(0.043, 0.051, 0.071, 0.96)
            s:SetBackdropBorderColor(0.976, 0.451, 0.086, 0.72)
        end)
        btn:SetScript("OnClick", onClickFn)
        return btn
    end

    local testJoinBtn = CreateToastPreviewBtn("Test Join (3/5)", nil, 0, function()
        DynamicGroup:TriggerTeleportToastPreview("JOIN")
    end)
    local testFullBtn = CreateToastPreviewBtn("Test Full (5/5)", testJoinBtn, 8, function()
        DynamicGroup:TriggerTeleportToastPreview("FULL")
    end)
    CreateToastPreviewBtn("Edit HUD", testFullBtn, 8, function()
        if _G.DynamicSuite and type(_G.DynamicSuite.IsHudEditModeActive) == "function" and _G.DynamicSuite.IsHudEditModeActive() then
            if type(_G.DynamicSuite.ExitHudEditMode) == "function" then
                _G.DynamicSuite.ExitHudEditMode(false)
            end
        elseif _G.DynamicSuite and type(_G.DynamicSuite.EnterHudEditMode) == "function" then
            _G.DynamicSuite.EnterHudEditMode("TOAST")
        end
    end)

    sec3a.orderedCards[#sec3a.orderedCards + 1] = c3_tpToast
    page3.orderedCards[#page3.orderedCards + 1] = c3_tpToast
    root.allControls[#root.allControls + 1] = c3_tpToast

    -- Card 3.3b: Instant One-Click Sign-Up
    local c3_oneClick = CreateCardRow(sec3b, 62,
        "Instant One-Click Sign-Up",
        "Automatically signs up when selecting a group with your preferred role and note. Hold Shift or Alt to manually edit before submitting."
    )
    AttachSegmentedSwitchToCard(c3_oneClick,
        function() return EnsureDB().oneClickSignUp end,
        function(val)
            EnsureDB().oneClickSignUp = val
            DynamicGroup:UpdateLFGMiniBar()
            if _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
                pcall(_G.DynamicSuite.RefreshHeaderStatus)
            end
        end
    )
    sec3b.orderedCards[#sec3b.orderedCards + 1] = c3_oneClick
    page3.orderedCards[#page3.orderedCards + 1] = c3_oneClick
    root.allControls[#root.allControls + 1] = c3_oneClick

    -- Card 3.4: Auto-Select Active Specialisation Role on Sign-Up
    local c3_autoRole = CreateCardRow(sec3b, 62,
        "Auto-Select Active Specialisation Role on Sign-Up",
        "Automatically checks Tank, Healer, or Damager matching your active spec when signing up for LFG."
    )
    AttachSegmentedSwitchToCard(c3_autoRole,
        function() return EnsureDB().autoSelectRole end,
        function(val) EnsureDB().autoSelectRole = val end
    )
    sec3b.orderedCards[#sec3b.orderedCards + 1] = c3_autoRole
    page3.orderedCards[#page3.orderedCards + 1] = c3_autoRole
    root.allControls[#root.allControls + 1] = c3_autoRole

    -- Card 3.5: Persistent Sign-Up Note Pre-Fill + Hybrid Inline Sub-Drawer
    local c3_note = CreateCardRow(sec3b, 62,
        "Persistent Sign-Up Note Pre-Fill",
        "Pre-fills the LFG sign-up note box with your custom message and item level when applying to groups."
    )

    local noteSwitch = AttachSegmentedSwitchToCard(c3_note,
        function() return EnsureDB().autoFillNote end,
        function(val)
            local db = EnsureDB()
            db.autoFillNote = val
            if val then
                db.noteDrawerExpanded = true
            end
            if root.UpdateNoteDrawerLayout then root.UpdateNoteDrawerLayout() end
            if root.scrollHolder and root.scrollHolder.UpdateThumb then
                root.scrollHolder.UpdateThumb()
            end
        end
    )
    AnchorCardTextToRightWidget(c3_note, noteSwitch)

    local noteBar = CreateSubDrawerToggleBar(
        c3_note,
        2,
        function() return EnsureDB().noteDrawerExpanded ~= false end,
        function(exp) EnsureDB().noteDrawerExpanded = exp end,
        function()
            if root.UpdateNoteDrawerLayout then root.UpdateNoteDrawerLayout() end
            if root.scrollHolder and root.scrollHolder.UpdateThumb then
                root.scrollHolder.UpdateThumb()
            end
        end
    )

    -- Recessed Sub-Drawer Container holding 2 Nested Sub-Setting Cards (PANEL_BG #090A0D, 1px CELL_BORDER, 2px Suite Accent left bar, 5x5 pip)
    local noteDrawer = CreateFrame("Frame", nil, c3_note)
    noteDrawer:SetPoint("TOPLEFT", c3_note, "TOPLEFT", 10, -82)
    noteDrawer:SetPoint("TOPRIGHT", c3_note, "TOPRIGHT", -10, -82)
    noteDrawer:SetHeight(88)

    local noteCard = CreateFrame("Frame", nil, noteDrawer, "BackdropTemplate")
    noteCard:SetPoint("TOPLEFT", noteDrawer, "TOPLEFT", 0, 0)
    noteCard:SetPoint("TOPRIGHT", noteDrawer, "TOPRIGHT", 0, 0)
    noteCard:SetHeight(42)
    noteCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    noteCard:SetBackdropColor(0.035, 0.039, 0.051, 0.99) -- PANEL_BG #090A0D
    noteCard:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95) -- CELL_BORDER #252A36

    noteDrawer.accentBar = noteCard:CreateTexture(nil, "OVERLAY")
    noteDrawer.accentBar:SetWidth(2)
    noteDrawer.accentBar:SetPoint("TOPLEFT", noteCard, "TOPLEFT", 0, 0)
    noteDrawer.accentBar:SetPoint("BOTTOMLEFT", noteCard, "BOTTOMLEFT", 0, 0)

    local ilvlCard = CreateFrame("Frame", nil, noteDrawer, "BackdropTemplate")
    ilvlCard:SetPoint("TOPLEFT", noteDrawer, "TOPLEFT", 0, -46)
    ilvlCard:SetPoint("TOPRIGHT", noteDrawer, "TOPRIGHT", 0, -46)
    ilvlCard:SetHeight(42)
    ilvlCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    ilvlCard:SetBackdropColor(0.035, 0.039, 0.051, 0.99) -- PANEL_BG #090A0D
    ilvlCard:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95) -- CELL_BORDER #252A36

    noteDrawer.accentBar2 = ilvlCard:CreateTexture(nil, "OVERLAY")
    noteDrawer.accentBar2:SetWidth(2)
    noteDrawer.accentBar2:SetPoint("TOPLEFT", ilvlCard, "TOPLEFT", 0, 0)
    noteDrawer.accentBar2:SetPoint("BOTTOMLEFT", ilvlCard, "BOTTOMLEFT", 0, 0)

    local notePip = noteCard:CreateTexture(nil, "ARTWORK")
    notePip:SetSize(5, 5)
    notePip:SetPoint("LEFT", noteCard, "LEFT", 14, 0)
    noteDrawer.notePip = notePip

    local noteBox = CreateFrame("EditBox", nil, noteCard, "BackdropTemplate")
    noteBox:SetSize(210, 24)
    noteBox:SetPoint("RIGHT", noteCard, "RIGHT", -78, 0)
    noteBox:SetAutoFocus(false)
    noteBox:SetMaxLetters(120)
    noteBox:SetTextInsets(8, 8, 0, 0)
    SetSafeFont(noteBox, 11, "")
    noteBox:SetTextColor(0.95, 0.97, 1.00)
    noteBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    noteBox:SetBackdropColor(0.04, 0.05, 0.08, 0.98)
    noteBox:SetBackdropBorderColor(0.18, 0.21, 0.28, 1.00)
    noteBox:SetText(EnsureDB().persistentNote or "")

    local noteSubLabel = noteCard:CreateFontString(nil, "OVERLAY")
    SetSafeFont(noteSubLabel, 11, "")
    noteSubLabel:SetPoint("LEFT", notePip, "RIGHT", 8, 0)
    noteSubLabel:SetPoint("RIGHT", noteBox, "LEFT", -12, 0)
    noteSubLabel:SetJustifyH("LEFT")
    noteSubLabel:SetTextColor(0.84, 0.89, 0.95)
    noteSubLabel:SetText("Custom Sign-Up Note")

    local saveNoteBtn = CreateFrame("Button", nil, noteCard, "BackdropTemplate")
    saveNoteBtn:SetSize(60, 24)
    saveNoteBtn:SetPoint("RIGHT", noteCard, "RIGHT", -12, 0)
    saveNoteBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    saveNoteBtn.label = saveNoteBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(saveNoteBtn.label, 11, "")
    saveNoteBtn.label:SetPoint("CENTER", 0, 0)
    saveNoteBtn.label:SetText("Save")

    local function CommitNote()
        EnsureDB().persistentNote = noteBox:GetText() or ""
        noteBox:ClearFocus()
        PrintMsg("Saved persistent LFG sign-up note.")
    end
    noteBox:SetScript("OnEnterPressed", CommitNote)
    noteBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    saveNoteBtn:SetScript("OnClick", CommitNote)
    root.noteEditBox = noteBox
    root.saveNoteBtn = saveNoteBtn

    local ilvlPip = ilvlCard:CreateTexture(nil, "ARTWORK")
    ilvlPip:SetSize(5, 5)
    ilvlPip:SetPoint("LEFT", ilvlCard, "LEFT", 14, 0)
    noteDrawer.ilvlPip = ilvlPip

    local ilvlSwitch = AttachSegmentedSwitchToCard(ilvlCard,
        function() return EnsureDB().appendIlvlToNote end,
        function(val) EnsureDB().appendIlvlToNote = val end
    )
    ilvlSwitch:ClearAllPoints()
    ilvlSwitch:SetPoint("RIGHT", ilvlCard, "RIGHT", -12, 0)
    noteDrawer.toggleBtn = ilvlSwitch
    root.allControls[#root.allControls + 1] = noteDrawer

    local ilvlSubLabel = ilvlCard:CreateFontString(nil, "OVERLAY")
    SetSafeFont(ilvlSubLabel, 11, "")
    ilvlSubLabel:SetPoint("LEFT", ilvlPip, "RIGHT", 8, 0)
    ilvlSubLabel:SetPoint("RIGHT", ilvlSwitch, "LEFT", -12, 0)
    ilvlSubLabel:SetJustifyH("LEFT")
    ilvlSubLabel:SetTextColor(0.84, 0.89, 0.95)
    ilvlSubLabel:SetText("Prepend Active Spec & Equipped Item Level")

    local function UpdateNoteDrawerLayout()
        local db = EnsureDB()
        local isOn = db.autoFillNote and true or false
        local isExp = (db.noteDrawerExpanded ~= false)
        local ar, ag, ab = GetSuiteAccent()
        noteDrawer.accentBar:SetColorTexture(ar, ag, ab, 1)
        if noteDrawer.accentBar2 then noteDrawer.accentBar2:SetColorTexture(ar, ag, ab, 1) end
        notePip:SetColorTexture(ar, ag, ab, 0.90)
        ilvlPip:SetColorTexture(ar, ag, ab, 0.90)
        saveNoteBtn:SetBackdropColor(ar * 0.20, ag * 0.20, ab * 0.20, 0.96)
        saveNoteBtn:SetBackdropBorderColor(ar, ag, ab, 0.90)
        saveNoteBtn.label:SetTextColor(ar, ag, ab, 1)

        AnchorCardTextToRightWidget(c3_note, noteSwitch)
        if isOn then
            noteBar:Show()
            noteBar:RefreshValue()
            if isExp then
                noteDrawer:Show()
                c3_note:SetHeight(178)
                c3_note:SetBackdropBorderColor(ar, ag, ab, 0.85)
            else
                noteDrawer:Hide()
                c3_note:SetHeight(84)
                c3_note:SetBackdropBorderColor(0.145, 0.165, 0.212, 1.00)
            end
        else
            noteBar:Hide()
            noteDrawer:Hide()
            c3_note:SetHeight(62)
            c3_note:SetBackdropBorderColor(0.145, 0.165, 0.212, 1.00)
        end
        LayoutPageCards(page3)
    end
    root.UpdateNoteDrawerLayout = UpdateNoteDrawerLayout
    sec3b.orderedCards[#sec3b.orderedCards + 1] = c3_note
    page3.orderedCards[#page3.orderedCards + 1] = c3_note
    root.allControls[#root.allControls + 1] = c3_note

    -- Card 3.6: Safe LFG Search Auto-Refresh Ticker (EUI-Style Dropdown)
    local c3_refresh = CreateCardRow(sec3b, 62,
        "Safe LFG Search Auto-Refresh Ticker",
        "Periodically refreshes open LFG search results; pauses automatically while typing or signing up."
    )
    AttachDropdownToCard(c3_refresh, 250, {
        { value = 0,  label = "Disabled (Manual Refresh)" },
        { value = 10, label = "Every 10 Seconds" },
        { value = 15, label = "Every 15 Seconds" },
        { value = 30, label = "Every 30 Seconds" },
    }, function() return tonumber(EnsureDB().autoRefreshInterval) or 0 end, function(val)
        EnsureDB().autoRefreshInterval = val
        DynamicGroup:UpdateAutoRefreshTicker()
    end)
    sec3b.orderedCards[#sec3b.orderedCards + 1] = c3_refresh
    page3.orderedCards[#page3.orderedCards + 1] = c3_refresh
    root.allControls[#root.allControls + 1] = c3_refresh

    LayoutPageCards(page1)
    UpdateWhisperDrawerLayout()
    UpdateNoteDrawerLayout()
    DynamicGroup:RefreshConfigUI()
    return root
end

function DynamicGroup:RefreshConfigUI()
    local root = self.embeddedRoot
    if not root then return end
    local db = EnsureDB()
    local activeTab = tonumber(db.activeSubTab) or 1
    if activeTab < 1 or activeTab > 3 then activeTab = 1 end

    local ar, ag, ab = GetSuiteAccent()

    -- Top Segmented Tab Bar (#14171F cells, #252A36 1px border, active Suite Accent border/tint)
    if root.ReflowGroupTabBar then root.ReflowGroupTabBar() end
    for idx, btn in ipairs(root.tabButtons or {}) do
        SetSafeFont(btn.text, 11, "")
        local isSel = (idx == activeTab)
        if isSel then
            btn:SetBackdropColor(ar * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), ag * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), ab * ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42), 0.98)
            btn:SetBackdropBorderColor(ar, ag, ab, 0.95)
            btn.text:SetTextColor(1, 1, 1, 1)
        else
            btn:SetBackdropColor(0.078, 0.090, 0.122, 0.96) -- #14171F
            btn:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95) -- #252A36
            btn.text:SetTextColor(0.68, 0.74, 0.82, 1)
        end
    end

    for _, hdr in ipairs(root.sectionHeaders or {}) do
        if hdr.RefreshAccent then hdr:RefreshAccent() end
    end

    for _, c in ipairs(trackedCardRows) do
        if c.title then c.title:SetTextColor(0.97, 0.98, 1.0, 1.0) end
    end

    if root.UpdateWhisperDrawerLayout then root.UpdateWhisperDrawerLayout() end
    if root.UpdateNoteDrawerLayout then root.UpdateNoteDrawerLayout() end

    for idx, page in ipairs(root.tabPages or {}) do
        LayoutPageCards(page)
        if idx == activeTab then
            page:Show()
            root.scrollHolder.content:SetHeight(math.max(1, page:GetHeight() or 1))
        else
            page:Hide()
        end
    end

    for _, pill in ipairs(root.regionPills or {}) do
        if pill.RefreshPill then pill:RefreshPill() end
    end

    for _, ctrl in ipairs(root.allControls or {}) do
        if ctrl.title then SetSafeFont(ctrl.title, 12, "") end
        if ctrl.desc then SetSafeFont(ctrl.desc, 10, "") end
        if ctrl.dropdown and ctrl.dropdown.RefreshValue then ctrl.dropdown:RefreshValue() end
        if ctrl.toggleBtn and ctrl.toggleBtn.RefreshValue then ctrl.toggleBtn:RefreshValue() end
    end

    for _, actBtn in ipairs(root.actionButtons or {}) do
        actBtn:SetBackdropColor(ar * 0.20, ag * 0.20, ab * 0.20, 0.96)
        actBtn:SetBackdropBorderColor(ar, ag, ab, 0.90)
        if actBtn.label then
            SetSafeFont(actBtn.label, 11, "")
            actBtn.label:SetTextColor(ar, ag, ab, 1)
        end
    end

    if root.noteEditBox and not root.noteEditBox:HasFocus() then
        SetSafeFont(root.noteEditBox, 11, "")
        root.noteEditBox:SetText(db.persistentNote or "")
    end
    if root.kwEditBox and not root.kwEditBox:HasFocus() then
        SetSafeFont(root.kwEditBox, 11, "")
        root.kwEditBox:SetText(db.whisperKeywords or "inv, invite, 123")
    end

    if root.scrollHolder and root.scrollHolder.thumb then
        root.scrollHolder.thumb:SetBackdropColor(0.38, 0.45, 0.56, 0.85)
    end
    if root.scrollHolder and root.scrollHolder.UpdateThumb then
        root.scrollHolder.UpdateThumb()
    end
end

local function ApplyGroupThemeToUI()
    DynamicGroup:UpdateLFGMiniBar()
    DynamicGroup:RefreshConfigUI()
end

local function ResetGroupModuleDefaults()
    CloseActiveDropdown()
    local savedYield = type(_G.DynamicGroupDB) == "table" and _G.DynamicGroupDB.yieldHooks or nil
    _G.DynamicGroupDB = nil
    local db = EnsureDB()
    if savedYield ~= nil then
        db.yieldHooks = savedYield
    end
    db.incomingInviteMode = "FRIENDS_AND_GUILD"
    DynamicGroup:UpdateAutoRefreshTicker()
    DynamicGroup:RefreshLFGResults()
    DynamicGroup:RefreshConfigUI()
    PrintMsg("Reset all DynamicGroup settings to factory defaults.")
end

-- Standalone Shell Window (/dgroup & /dg fallback when DynamicSuite shell is not hosting)
local function EnsureStandaloneWindow()
    if DynamicGroup.standaloneFrame then return DynamicGroup.standaloneFrame end

    local f = CreateFrame("Frame", "DynamicGroupStandaloneFrame", UIParent, "BackdropTemplate")
    f:SetSize(860, 600)
    if type(UISpecialFrames) == "table" then
        local foundSpecial = false
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == "DynamicGroupStandaloneFrame" then
                foundSpecial = true
                break
            end
        end
        if not foundSpecial then
            table.insert(UISpecialFrames, "DynamicGroupStandaloneFrame")
        end
    end
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then
        f:SetResizeBounds(760, 500, 1280, 860)
    end
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.04, 0.05, 0.08, 0.98)
    local ar, ag, ab = GetSuiteAccent()
    f:SetBackdropBorderColor(ar, ag, ab, 0.75)

    local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
    header:SetHeight(42)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    header:SetBackdropColor(0.06, 0.07, 0.11, 0.98)

    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(22, 22)
    logo:SetPoint("LEFT", header, "LEFT", 12, 0)
    logo:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_group.tga")

    local title = header:CreateFontString(nil, "OVERLAY")
    SetSafeFont(title, 14, "")
    title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    title:SetText("|cFFCBD5E1Dynamic|r|cFFFFFFFFGroup|r " .. ColorWithAccent("v" .. DynamicGroup.version))
    f.titleText = title

    local status = header:CreateFontString(nil, "OVERLAY")
    SetSafeFont(status, 11, "")
    status:SetPoint("CENTER", header, "CENTER", 20, 0)
    status:SetTextColor(0.58, 0.66, 0.78)
    f.statusText = status

    local closeBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
    closeBtn:SetSize(26, 24)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -10, 0)
    closeBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    closeBtn:SetBackdropColor(0.08, 0.09, 0.12, 0.92)
    closeBtn:SetBackdropBorderColor(0.18, 0.21, 0.28, 0.95)
    closeBtn.txt = closeBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(closeBtn.txt, 12, "")
    closeBtn.txt:SetPoint("CENTER", 0, 0)
    closeBtn.txt:SetText("X")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 10, -8)
    body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 12)
    f.body = body

    RenderGroupEmbedded(body)
    f:Hide()
    DynamicGroup.standaloneFrame = f
    return f
end

local function OpenGroupWorkspace()
    if _G.DynamicSuite and type(_G.DynamicSuite.OpenModule) == "function" then
        local ok = pcall(_G.DynamicSuite.OpenModule, _G.DynamicSuite, "DynamicGroup")
        if ok then return end
    end
    if _G.DynamicLoadUI and type(_G.DynamicLoadUI.OpenToModule) == "function" then
        local ok = pcall(_G.DynamicLoadUI.OpenToModule, _G.DynamicLoadUI, "group")
        if ok then return end
    end
    local f = EnsureStandaloneWindow()
    local ar, ag, ab = GetSuiteAccent()
    f:SetBackdropBorderColor(ar, ag, ab, 0.75)
    if f.titleText then
        f.titleText:SetText("|cFFCBD5E1Dynamic|r|cFFFFFFFFGroup|r " .. ColorWithAccent("v" .. DynamicGroup.version))
    end
    if f.statusText then
        f.statusText:SetText(GetGroupStatusText())
    end
    RenderGroupEmbedded(f.body)
    f:Show()
    DynamicGroup:RefreshConfigUI()
end

-- Public Entry Methods on DynamicGroup
function DynamicGroup:RenderEmbedded(arg1, arg2)
    return RenderGroupEmbedded(arg1, arg2)
end

function DynamicGroup:BuildEmbeddedPanel(arg1, arg2)
    return RenderGroupEmbedded(arg1, arg2)
end

function DynamicGroup:ApplyThemeToUI()
    return ApplyGroupThemeToUI()
end

function DynamicGroup:ResetModuleDefaults()
    return ResetGroupModuleDefaults()
end

function DynamicGroup:OpenWorkspace()
    return OpenGroupWorkspace()
end

-- ============================================================================
-- 8. _G.DYNAMICSUITE REGISTRATION & SLASH COMMANDS (/dgroup & /dg)
-- ============================================================================

local function RegisterWithDynamicSuite()
    _G.DynamicSuite = _G.DynamicSuite or {}
    _G.DynamicSuite.modules = _G.DynamicSuite.modules or {}

    local descriptor = {
        id = "group",
        key = "group",
        name = "DynamicGroup",
        title = "DynamicGroup",
        subtitle = "LFG Filter & Invites",
        desc = "Filters Premade Groups by datacentre region, M+ score, and Lust/CR utility, with 1-click sign-up, auto-invite, and M+ keystone slotting.",
        version = DynamicGroup.version,
        order = 60,
        icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_group.tga",
        fallbackIcon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_group.tga",
        iconWhite = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_white.tga",
        iconAccent = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_accent.tga",
        conflictRegistry = DynamicGroup.SUITE_CONFLICT_REGISTRY,
        RenderEmbedded = function(arg1, arg2) return RenderGroupEmbedded(arg1, arg2) end,
        BuildEmbeddedPanel = function(arg1, arg2) return RenderGroupEmbedded(arg1, arg2) end,
        ApplyThemeToUI = function() return ApplyGroupThemeToUI() end,
        Render = function(a1, a2) return RenderGroupEmbedded(a1, a2) end, ApplyTheme = ApplyGroupThemeToUI, ResetModuleDefaults = ResetGroupModuleDefaults, ResetDefaults = ResetGroupModuleDefaults, ResetModule = ResetGroupModuleDefaults, Reset = ResetGroupModuleDefaults,
        OpenWorkspace = function() return OpenGroupWorkspace() end,
        GetStatusText = function() return GetGroupStatusText() end,
        OnDisableInSuite = function()
            if DynamicGroup.lfgMiniBar then DynamicGroup.lfgMiniBar:Hide() end
            if DynamicGroup.portalBar and not (InCombatLockdown and InCombatLockdown()) then
                DynamicGroup.portalBar:Hide()
            end
            DynamicGroup:HideTeleportToast()
            DynamicGroup:UnregisterAllEvents()
        end,
        SelectSubTab = function(a1, a2, a3)
            local idx = (type(a1) == "number") and a1 or a2 or 1
            local expandDrawers = (type(a1) == "number") and a2 or a3
            local db = EnsureDB()
            db.activeSubTab = idx
            if expandDrawers then
                db.whisperDrawerExpanded = true
                db.noteDrawerExpanded = true
            end
            if DynamicGroup.RefreshConfigUI then
                DynamicGroup:RefreshConfigUI()
            end
        end,
    }
    descriptor.SelectTab = descriptor.SelectSubTab
    DynamicGroup.SelectSubTab = descriptor.SelectSubTab
    DynamicGroup.SelectTab = descriptor.SelectSubTab

    _G.DynamicSuite.modules["group"] = descriptor
    _G.DynamicSuite.modules["DynamicGroup"] = descriptor

    DynamicGroup.CHANGELOG = {
        version = DynamicGroup.version or VERSION,
        date = "15/11/2026",
        entries = {
            { type = "FEATURE", text = "Portal Deck Owned Keystone Telemetry & Right-Click Teleport (15/11/2026): Upgraded the Portal Deck's Owned Keystone pill (pbar.keyBtn) to support secure Right-Click Dungeon Teleport casting out of combat with a synced cooldown swipe overlay, plus Season Best (timed/over-time level and score) and Dungeon Teleport readiness/cooldown lines in the tooltip while preserving Left-Click exclusive dungeon filtering." },
            { type = "FEATURE", text = "Dungeon Joined & Group Full Teleport Toast (15/11/2026): Displays a 410x74 Alert Toast-matched banner with a one-click Dungeon Teleport button and Right-Click dismissal when your Premade Group application is accepted, chimes as players join, and highlights when the group reaches 5/5. Shares DynamicSuite's Alert Toast HUD Edit slot with automatic mutual stacking, plus Test Join (3/5), Test Full (5/5), Edit HUD buttons, and /dg testtoast." },
            { type = "FEATURE", text = "Season Dungeon Portals & 1-Click Dungeon Filter Deck (15/11/2026): Docked a sleek portal bar above Premade Groups showing your current Mythic+ keystone pill and the 8 season dungeon tiles with best timed key levels. Dynamically discovers all learned Midnight Season 2 teleport spells from the Mythic+ tab and spellbook so Left-click toggles the dungeon filter (Shift+Left-click solo filters) and Right-click casts learned dungeon teleports out of combat." },
            { type = "FEATURE", text = "Integrated Multi-Toggle Premade Group Filters (15/11/2026): Upgraded the Group Finder filter menu with Tank, Healer, and DPS role availability toggles (with role icons), No Duplicate Class, Has Tank, Has Healer, Bloodlust/Heroism, and Battle Rez, kept in two-way sync with Blizzard's native Filter menu without altering difficulty checkboxes." },
            { type = "UI",      text = "De-cluttered Premade Group rows with a sleek borderless Region / Leader IO pill (OCE, USE, USW, USC, LA, BR), desaturated greyscale Tank/Healer/DPS icons matched to Blizzard's slot size over empty group slots, a simplified Show Region & Leader IO Badge switch, and personal best key levels plus same-class warnings in group tooltips." },
            { type = "FIX",     text = "Fixed the dungeon tile tooltip colour code and updated the Portal Bar All button to stay unhighlighted while a dungeon filter is active." },
            { type = "FEATURE", text = "External Addon Conflict Detector & Yield Engine (12/11/2026): Added PremadeGroupsFilter and PremadeRegionFilter to the curated HARD conflict registry with unified DynamicSuite top-of-module warning banner and 1-click resolution." },
            { type = "FIX",     text = "Eliminated direct property write onto LFGListApplicationDialog.resultID before LFGListApplicationDialog_Show, added pcall and IsSecretValue guards across C_LFGList.GetApplicationInfo, HasSearchResultInfo, GetSearchResultInfo, and sp.SearchBox:GetText(), and pre-guarded LFGListSearchEntry OnEnter against expired resultIDs." },
            { type = "FIX",     text = "Added PLAYER_REGEN_DISABLED cleanup to close DynamicGroupDropdownCatcher and active dropdown popovers on combat entry, added OnMouseUp and OnHide OnUpdate cleanup on the workspace scrollbar thumb, and wired DynamicGroupDB.yieldHooks (AUTO_YIELD) across all LFG filter and sign-up hooks." },
            { type = "FIX",     text = "Fixed LFGList.lua:4390 Nil searchResultInfo Tooltip Crash: Added IsValidSearchResultID(resultID) (verifying C_LFGList.HasSearchResultInfo and C_LFGList.GetSearchResultInfo), purged expired/nil resultIDs across DoesResultPassFilters, FilterAndSortSearchPanelResults, SyncScrollBoxToFilteredResults, and OnLFGListSearchPanelUpdateResultList (including empty #apiResults == 0 updates and DoSearch/SetCategory/Clear resets), and guarded LFGListSearchEntry OnEnter so hovering an expired row never crashes LFGListUtil_SetSearchEntryTooltip." },
            { type = "UI",      text = "Consolidated Auto-Insert Mythic+ Keystone exclusively into DynamicGroup (Tab 3: Party & Keystone Automation) with automatic SavedVariables migration from DynamicPrepDB.autoSlotKeystone." },
            { type = "UI",      text = "Standardized all LFG Mini-Bar and Datacenter Region pill tooltips to use Command-Prefix-Only Highlighting (Emerald Left-Click: / Suite Accent Hold Shift / Alt: prefixes paired with Silver-White action descriptions)." },
            { type = "UI",      text = "Cleaned up LFG search row overlays: removed [D D D] member dots and top-right [Lust]/[CR] brackets so the top-right [Region] [Score] badge stays compact (~80px) without colliding with group titles or Blizzard's green Playstyle text; defaulted overlayMode to COMPACT (v121_cleanOverlay), anchored FULL mode borderless Lust/CR tags at BOTTOMRIGHT beneath the 5 role icons, and added an always-on 'Party Utility:' line to the LFG tooltip." },
            { type = "FIX",     text = "Added Retail 12.1.5 C_LFGList.GetSearchResultPlayerInfo(resultID, i) support for reliable Bloodlust and Battle Rez detection, and added SyncScrollBoxToFilteredResults (LFGListSearchPanel_UpdateResults + DataProvider:RemoveByPredicate + ScrollBox:ForEachFrame) so disabled regions ([BR], [LATAM]) are immediately removed from the ScrollBox." },
            { type = "FIX",     text = "Locked entry._dgPressedResultID on LeftButton OnMouseDown and froze panel._dgOrderedResults across background LFG_LIST_SEARCH_RESULT_UPDATED refreshes so rows never jump under the cursor during 1-Click Sign-Up." },
            { type = "FIX",     text = "Fixed unticking a region (Reg 5/6) blanking out the LFG list by keeping groups with pending/secret leaderName (regionKey = PENDING) and fetching authoritative unfiltered results from C_LFGList.GetSearchResults(); fixed 1-Click Sign-Up targeting random groups by opening LFGListApplicationDialog_Show directly with liveResultID." },
            { type = "FIX",     text = "Fixed LATAM / BR region filtering: removed duplicate Ragnaros (USE) and Nemesis (USC) realm entries, preserved panel._dgRawResults across refreshes, hooked LFGListSearchPanel_UpdateResults & LFG_LIST_SEARCH_RESULT_UPDATED for async leaderName resolution, and upgraded Fit: Role to Party Utility Filter (Util: All / Lust / CR / Both)." },
            { type = "FIX",     text = "Resolved EllesmereUIGroupFinder conflict where EUI hides Blizzard's LFG ScrollBox (alpha 0) and blocks DynamicGroup filtering, badges, and 1-Click Sign-Up: auto-suppresses EUI Group Finder list override, restores ScrollBox/SignUpButton alpha, hooks ExtraPasses fallback, and prevents DynamicGroupOverlay ghosting." },
            { type = "FIX",     text = "Hardened LFG Application Note auto-fill with securityDisableSetText, pcall, and IsSecretValue(curText) guards so protected or secret EditBox states never throw EditBox:SetText() security taint or secret-value Lua errors, plus dialog._dgSnapped cursor snap tracking." },
            { type = "FEATURE", text = "On-The-Fly LFG Mini-Bar with Datacenter Region popover, Minimum M+ Score filter, and Party Utility filter (Lust / CR / Both) directly above Blizzard Premade panel." },
            { type = "FEATURE", text = "In-Place Premade Group Badges displaying Datacenter Region ([OCE], [US-W], [US-C], [US-E], [LATAM], [BR]) and Leader M+ Score in the top-right corner, with optional bottom-right Lust/CR tags and tooltip utility breakdown." },
        },
    }
    _G.DynamicSuite.Changelogs = _G.DynamicSuite.Changelogs or {}
    _G.DynamicSuite.Changelogs["DynamicGroup"] = DynamicGroup.CHANGELOG
    _G.DynamicSuite.Changelogs["group"] = DynamicGroup.CHANGELOG

    if type(_G.DynamicSuite.RegisterModule) == "function" then
        pcall(_G.DynamicSuite.RegisterModule, _G.DynamicSuite, "group", descriptor)
    end
end

RegisterWithDynamicSuite()

SLASH_DYNAMICGROUP1 = "/dgroup"
SLASH_DYNAMICGROUP2 = "/dg"
SlashCmdList["DYNAMICGROUP"] = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(.-)%s*$")
    if cmd == "reset" then
        ResetGroupModuleDefaults()
    elseif cmd == "rc" or cmd == "ready" then
        if type(DoReadyCheck) == "function" then DoReadyCheck() end
    elseif cmd == "pull" then
        if C_PartyInfo and type(C_PartyInfo.DoCountdown) == "function" then C_PartyInfo.DoCountdown(10) end
    elseif cmd == "testtoast" then
        DynamicGroup:CycleTeleportToastPreview()
    else
        OpenGroupWorkspace()
    end
end

-- ============================================================================
-- 9. EVENT DISPATCHER
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

SafeRegisterEvent(DynamicGroup, "ADDON_LOADED")
SafeRegisterEvent(DynamicGroup, "PLAYER_LOGIN")
SafeRegisterEvent(DynamicGroup, "PLAYER_REGEN_DISABLED")
SafeRegisterEvent(DynamicGroup, "PLAYER_REGEN_ENABLED")
SafeRegisterEvent(DynamicGroup, "BAG_UPDATE_DELAYED")
SafeRegisterEvent(DynamicGroup, "CHALLENGE_MODE_MAPS_UPDATE")
SafeRegisterEvent(DynamicGroup, "CHALLENGE_MODE_MEMBER_INFO_UPDATED")
SafeRegisterEvent(DynamicGroup, "MYTHIC_PLUS_CURRENT_AFFIX_UPDATE")
SafeRegisterEvent(DynamicGroup, "SPELLS_CHANGED")
SafeRegisterEvent(DynamicGroup, "PARTY_INVITE_REQUEST")
SafeRegisterEvent(DynamicGroup, "CHAT_MSG_WHISPER")
SafeRegisterEvent(DynamicGroup, "CHAT_MSG_BN_WHISPER")
SafeRegisterEvent(DynamicGroup, "LFG_ROLE_CHECK_SHOW")
SafeRegisterEvent(DynamicGroup, "GROUP_ROSTER_UPDATE")
SafeRegisterEvent(DynamicGroup, "CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
SafeRegisterEvent(DynamicGroup, "LFG_LIST_SEARCH_RESULT_UPDATED")
SafeRegisterEvent(DynamicGroup, "LFG_LIST_APPLICATION_STATUS_UPDATED")
SafeRegisterEvent(DynamicGroup, "PLAYER_ENTERING_WORLD")

DynamicGroup:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedName = ...
        if (loadedName == ADDON_FOLDER or loadedName == "DynamicGroup") and not isInitialized then
            isInitialized = true
            EnsureDB()
            RegisterWithDynamicSuite()
            if IsModuleDisabledInSuite("DynamicGroup") then
                if _G.DynamicSuite and _G.DynamicSuite.modules then
                    if _G.DynamicSuite.modules["group"] then _G.DynamicSuite.modules["group"]._disabledAtStartup = true end
                    if _G.DynamicSuite.modules["DynamicGroup"] then _G.DynamicSuite.modules["DynamicGroup"]._disabledAtStartup = true end
                end
                self:UnregisterAllEvents()
                return
            end
        elseif loadedName == "Blizzard_GroupFinder" or loadedName == "EllesmereUIGroupFinder" then
            if not IsModuleDisabledInSuite("DynamicGroup") then
                SuppressEUIGroupFinderIfNeeded()
                self:InstallLFGHooks()
            end
        elseif loadedName == "Blizzard_ChallengesUI" then
            if not IsModuleDisabledInSuite("DynamicGroup") then
                if _G.ChallengesKeystoneFrame and _G.ChallengesKeystoneFrame.HookScript and not self.keystoneHooked then
                    self.keystoneHooked = true
                    _G.ChallengesKeystoneFrame:HookScript("OnShow", function()
                        if not IsModuleDisabledInSuite("DynamicGroup") then
                            C_Timer.After(0.05, TryAutoInsertKeystone)
                        end
                    end)
                end
                if _G.ChallengesFrame and _G.ChallengesFrame.HookScript and not self.challengesFrameHooked then
                    self.challengesFrameHooked = true
                    _G.ChallengesFrame:HookScript("OnShow", function()
                        if not IsModuleDisabledInSuite("DynamicGroup") then
                            seasonSlotsCache = nil
                            spellbookTeleportCache = nil
                            if self.portalBar or (self.lfgMiniBar and self.lfgMiniBar:IsShown()) then
                                self:UpdatePortalBar(true)
                            end
                        end
                    end)
                end
                seasonSlotsCache = nil
                spellbookTeleportCache = nil
                if self.portalBar or (self.lfgMiniBar and self.lfgMiniBar:IsShown()) then
                    self:UpdatePortalBar(true)
                end
            end
        end
    elseif event == "PLAYER_LOGIN" then
        EnsureDB()
        RegisterWithDynamicSuite()
        if IsModuleDisabledInSuite("DynamicGroup") then
            if _G.DynamicSuite and _G.DynamicSuite.modules then
                if _G.DynamicSuite.modules["group"] then _G.DynamicSuite.modules["group"]._disabledAtStartup = true end
                if _G.DynamicSuite.modules["DynamicGroup"] then _G.DynamicSuite.modules["DynamicGroup"]._disabledAtStartup = true end
            end
            self:UnregisterAllEvents()
            return
        end
        SuppressEUIGroupFinderIfNeeded()
        self:InstallLFGHooks()
        self:UpdateAutoRefreshTicker()
        if _G.ChallengesKeystoneFrame and _G.ChallengesKeystoneFrame.HookScript and not self.keystoneHooked then
            self.keystoneHooked = true
            _G.ChallengesKeystoneFrame:HookScript("OnShow", function()
                C_Timer.After(0.05, TryAutoInsertKeystone)
            end)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        CloseActiveDropdown()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if self.pendingPortalBarUpdate then
            self:UpdatePortalBar(false)
        end
        if self.pendingTeleportToastHide then
            self:HideTeleportToast()
        elseif self.pendingTeleportToastUpdate then
            self:UpdateTeleportToast(false)
        end
    elseif event == "BAG_UPDATE_DELAYED" or event == "CHALLENGE_MODE_MEMBER_INFO_UPDATED" or event == "MYTHIC_PLUS_CURRENT_AFFIX_UPDATE" then
        if self.portalBar and self.UpdatePortalBarVisuals then
            self:UpdatePortalBarVisuals()
        end
    elseif event == "CHALLENGE_MODE_MAPS_UPDATE" or event == "SPELLS_CHANGED" then
        seasonSlotsCache = nil
        spellbookTeleportCache = nil
        if self.portalBar or (self.lfgMiniBar and self.lfgMiniBar:IsShown()) then
            self:UpdatePortalBar(true)
        end
    elseif event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
        local resultID = ...
        local sp = _G.LFGListFrame and _G.LFGListFrame.SearchPanel
        if sp and sp:IsShown() and resultID then
            if not IsValidSearchResultID(resultID) then
                if _G.GameTooltip and _G.GameTooltip.GetOwner then
                    local owner = _G.GameTooltip:GetOwner()
                    if owner and owner.resultID == resultID then
                        _G.GameTooltip:Hide()
                    end
                end
                ScheduleAsyncResultRefilter()
            else
                local db = EnsureDB()
                if db.lfgFilterEnabled and not self:DoesResultPassFilters(resultID) then
                    ScheduleAsyncResultRefilter()
                end
            end
        end
    elseif event == "PARTY_INVITE_REQUEST" then
        HandlePartyInviteRequest(...)
    elseif event == "CHAT_MSG_WHISPER" then
        local text, senderName, _, _, _, _, _, _, _, _, _, guid = ...
        if IsSecretValue(text) or IsSecretValue(senderName) then return end
        HandleWhisperAutoInvite(text, senderName, guid)
    elseif event == "CHAT_MSG_BN_WHISPER" then
        local text, senderDisplayName, _, _, _, _, _, _, _, _, _, _, bnetIDAccount = ...
        if IsSecretValue(text) or IsSecretValue(senderDisplayName) then return end
        HandleBNetWhisperAutoInvite(text, senderDisplayName, bnetIDAccount)
    elseif event == "LFG_ROLE_CHECK_SHOW" then
        if EnsureDB().autoAcceptRoleCheck and not (InCombatLockdown and InCombatLockdown()) then
            if type(CompleteLFGRoleCheck) == "function" then
                pcall(CompleteLFGRoleCheck, true)
            end
        end
    elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
        self:HandleApplicationStatusUpdated(...)
    elseif event == "GROUP_ROSTER_UPDATE" then
        HandleAutoPromoteRoster()
        if self.activeTeleportToastData then
            local inGroupNow = (type(_G.IsInGroup) == "function" and _G.IsInGroup()) and true or false
            if self.activeTeleportToastData.isPreview then
                if inGroupNow then
                    self:HideTeleportToast()
                end
            elseif not inGroupNow then
                self:HideTeleportToast()
            else
                self:UpdateTeleportToast(true)
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if self.activeTeleportToastData and type(_G.IsInInstance) == "function" then
            local okI, inInst, instType = pcall(_G.IsInInstance)
            if okI and inInst and (instType == "party" or instType == "raid" or instType == "scenario") then
                self:HideTeleportToast()
            end
        end
    elseif event == "CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN" then
        if not self.keystoneHooked then
            C_Timer.After(0.05, TryAutoInsertKeystone)
        end
    end
end)

function _G.DynamicGroup_OnAddonCompartmentClick()
    OpenGroupWorkspace()
end
