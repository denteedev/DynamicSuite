-- ============================================================================
-- DynamicVault - Account-Wide Great Vault, Crests, Delve Keys & Weeklies
-- World of Warcraft Retail (12.1.5 / 12.1.7, Interface 120105, 120107)
-- Pure ASCII Only (NonASCII: 0, HasBOM: False) | Zero-Taint Midnight Engine
-- ============================================================================

local addonName = ...
local ADDON_FOLDER = (type(addonName) == "string" and addonName ~= "") and addonName or "DynamicSuite"

local function ResolveAddonVersion(folderName, fallback)
    local fb = fallback or "2.10.1"
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

local VERSION = ResolveAddonVersion(ADDON_FOLDER, "2.10.1")
if ShouldYieldToOtherInstall(ADDON_FOLDER, "DynamicVault", VERSION, _G.DynamicVault) then
    return
end

local DynamicVault = _G.DynamicVault or {}
_G.DynamicVault = DynamicVault
DynamicVault.VERSION        = VERSION
DynamicVault.version        = VERSION
DynamicVault._loadedBySuite = (ADDON_FOLDER == "DynamicSuite")
DynamicVault._loadedVersion = VERSION

-- ============================================================================
-- 1. SAFE HELPERS & ASSET PATHS
-- ============================================================================
local function SafeIsSecret(v)
    if type(_G.issecretvalue) == "function" then
        local ok, res = pcall(_G.issecretvalue, v)
        if ok and res then return true end
    end
    if type(_G.canaccessvalue) == "function" then
        local ok, can = pcall(_G.canaccessvalue, v)
        if ok and can == false then return true end
    end
    return false
end

local function SafeStr(v, fb)
    if v == nil or SafeIsSecret(v) then return fb or "" end
    local ok, s = pcall(tostring, v)
    return (ok and type(s) == "string") and s or (fb or "")
end

local function SafeNum(v, fb)
    if v == nil or SafeIsSecret(v) then return fb or 0 end
    local ok, n = pcall(tonumber, v)
    return (ok and type(n) == "number") and n or (fb or 0)
end

local function IsModuleDisabledInSuite(moduleName)
    local dsDB = _G.DynamicSuiteDB
    local dis = dsDB and dsDB.global and dsDB.global.disabledModules
    if type(dis) ~= "table" then return false end
    return (dis[moduleName] == true) or (dis["vault"] == true) or (dis["DynamicVault"] == true)
end

local MEDIA_BASE  = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\"
local ICON_COLOR  = MEDIA_BASE .. "Icons\\icon_mod_vault.tga"
local ICON_WHITE  = ICON_COLOR
local ICON_ACCENT = ICON_COLOR

local CLASS_HEX = {
    WARRIOR     = "C69B6D",
    PALADIN     = "F48CBA",
    HUNTER      = "AAD372",
    ROGUE       = "FFF468",
    PRIEST      = "FFFFFF",
    DEATHKNIGHT = "C41E3A",
    SHAMAN      = "0070DD",
    MAGE        = "3FC7EB",
    WARLOCK     = "8788EE",
    MONK        = "00FF98",
    DRUID       = "FF7C0A",
    DEMONHUNTER = "A330C9",
    EVOKER      = "33937F",
}

local function GetClassHex(classFile)
    return CLASS_HEX[classFile] or "CBD5E1"
end

local function FormatGoldCompact(copper)
    local c = math.floor(SafeNum(copper, 0))
    local g = math.floor(c / 10000)
    if g >= 1000000 then
        return string.format("%.2fM g", g / 1000000)
    elseif g >= 10000 then
        return string.format("%.1fk g", g / 1000)
    else
        return string.format("%dg", g)
    end
end

local function FormatTimeRemaining(seconds)
    local s = math.max(0, math.floor(SafeNum(seconds, 0)))
    local d = math.floor(s / 86400)
    local h = math.floor((s % 86400) / 3600)
    local m = math.floor((s % 3600) / 60)
    if d > 0 then
        return string.format("%dd %dh", d, h)
    elseif h > 0 then
        return string.format("%dh %dm", h, m)
    else
        return string.format("%dm", m)
    end
end

local function GetCurrentResetEpoch()
    local now = (type(GetServerTime) == "function" and SafeNum(GetServerTime(), 0)) or (type(time) == "function" and time()) or 0
    local secsLeft = 0
    if C_DateAndTime and type(C_DateAndTime.GetSecondsUntilWeeklyReset) == "function" then
        local ok, r = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
        if ok then secsLeft = SafeNum(r, 0) end
    end
    if secsLeft <= 0 then
        return math.floor(now / 604800) * 604800 + 604800
    end
    -- Round to nearest 10 minutes so minor clock jitter never triggers false resets
    return math.floor((now + secsLeft + 300) / 600) * 600
end

local function GetPlayerKey()
    local name = (type(UnitName) == "function") and SafeStr(UnitName("player"), "") or ""
    local realm = (type(GetRealmName) == "function") and SafeStr(GetRealmName(), "") or ""
    realm = realm:gsub("%s+", "")
    if name == "" then return nil end
    return (realm ~= "") and (name .. "-" .. realm) or name
end

local function Print(msg)
    local UI = _G.DynamicSuite and _G.DynamicSuite.UI
    local prefix = (UI and type(UI.FormatTwoToneBrand) == "function")
        and UI.FormatTwoToneBrand("Vault")
        or "|cFFCBD5E1Dynamic|r|cFF38BDF8Vault|r"
    print(prefix .. ": " .. tostring(msg or ""))
end

-- ============================================================================
-- 2. DATABASE DEFAULTS & WEEKLY ROLLOVER
-- ============================================================================
local DEFAULTS = {
    enabled            = true,
    dockOnGreatVault   = true,
    vaultSkinMode      = "OBSIDIAN", -- "OBSIDIAN" (Suite Obsidian & Accent, default) or "AUTO" (match EllesmereUI/ElvUI)
    showScreenOverlay  = false,
    overlayPos         = nil,
    overlayScale       = 1.0,
    overlayOpacity     = 0.96,
    overlayBorderStyle = "ACCENT",
    loginVaultReminder = true,
    syncDynamicBags    = true,
    filterMaxLevelOnly = false,
    minLevelFilter     = 80,
    showCurrencies     = true,
    showKeystones      = true,
    showRaidLockouts   = true,
    showBountifulDelves = true,
    sortMode           = "VAULT", -- "VAULT", "ILVL", "RATING", "NAME"
    activeSubTab       = 1,
    characters         = {},
    favourites         = {},
    customTasks        = {}, -- { id, title, scope = "CHAR"|"ACCT", doneAcct = false, doneChars = {}, resetEpoch = 0 }
    bountifulDelves    = {},
}

local function CopyDefaults(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then return end
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then
                dst[k] = {}
                CopyDefaults(dst[k], v)
            else
                dst[k] = v
            end
        elseif type(v) == "table" and type(dst[k]) == "table" then
            CopyDefaults(dst[k], v)
        end
    end
end

local function EnsureDB()
    if type(_G.DynamicVaultDB) ~= "table" then
        _G.DynamicVaultDB = {}
    end
    CopyDefaults(_G.DynamicVaultDB, DEFAULTS)
    if not _G.DynamicVaultDB.skinDefaultMigrated267 then
        if _G.DynamicVaultDB.vaultSkinMode == "AUTO" then
            _G.DynamicVaultDB.vaultSkinMode = "OBSIDIAN"
        end
        _G.DynamicVaultDB.skinDefaultMigrated267 = true
    end
    return _G.DynamicVaultDB
end

-- ============================================================================
-- 3. THEME & FONT INTEGRATION (1:1 DESIGN_SYSTEM.md)
-- ============================================================================
local function GetTheme()
    local ar, ag, ab = 0.220, 0.741, 0.973
    if _G.DynamicSuite and type(_G.DynamicSuite.GetSuiteAccent) == "function" then
        local ok, r, g, b = pcall(_G.DynamicSuite.GetSuiteAccent, _G.DynamicSuite)
        if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            ar, ag, ab = r, g, b
        end
    elseif _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.GetActiveAccentColor) == "function" then
        local ok, r, g, b = pcall(_G.DynamicSuite.UI.GetActiveAccentColor)
        if ok and type(r) == "number" then ar, ag, ab = r, g, b end
    end
    local surf = {
        bg     = { 0.031, 0.039, 0.055, 0.98 },
        card   = { 0.055, 0.067, 0.094, 0.94 },
        bevel  = { 0.043, 0.051, 0.071, 0.98 },
        tabOff = { 0.078, 0.090, 0.122, 0.96 },
        border = { 0.145, 0.165, 0.212, 0.95 },
    }
    return surf, { r = ar, g = ag, b = ab }
end

local ellesmereSkinHandle = nil
local function EnsureEllesmereSkinRegistered()
    if ellesmereSkinHandle then return ellesmereSkinHandle end
    local eui = _G.EllesmereUI
    if type(eui) == "table" and type(eui.RegisterSkin) == "function" then
        local ok, handle = pcall(eui.RegisterSkin, "DynamicVault", {
            title = "DynamicVault",
            blizzWindowKey = "greatvault",
        })
        if ok and type(handle) == "table" then
            ellesmereSkinHandle = handle
            if type(handle.OnLooksChanged) == "function" then
                pcall(handle.OnLooksChanged, function()
                    if _G.DynamicSuite and _G.DynamicSuite._isHubLoaded then
                        local syncExt = _G.DynamicSuiteDB and _G.DynamicSuiteDB.global and (_G.DynamicSuiteDB.global.syncExternalUI == true)
                        if not syncExt then return end
                    end
                    if DynamicVault.RefreshOverlays then DynamicVault:RefreshOverlays() end
                end)
            end
        end
    end
    return ellesmereSkinHandle
end

local function GetOverlayTheme()
    local surf, acc = GetTheme()
    return surf, acc, "OBSIDIAN"
end

local function SetFontSafe(fs, size, flags)
    if not fs then return end
    local UI = _G.DynamicSuite and _G.DynamicSuite.UI
    if UI and type(UI.SetFont) == "function" then
        pcall(UI.SetFont, fs, size, flags or "")
        return
    end
    local fontPath = "Fonts\\FRIZQT__.TTF"
    pcall(fs.SetFont, fs, fontPath, size or 11, flags or "")
end

local function ApplyBackdrop(frame, bg, border)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    if bg then frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1) end
    if border then frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1) end
end

local function CreateSolidTex(parent, layer, sub, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
    return t
end

-- ============================================================================
-- 4. LIVE CHARACTER SNAPSHOT & CURRENCY DISCOVERY (MIDNIGHT 12.1.5)
-- ============================================================================
-- Dynamic currency matcher: discovers Catalyst, Coffer Keys, Shards, and active
-- seasonal Crests cleanly via C_CurrencyInfo list traversal so it works across
-- Midnight seasons without brittle hardcoded IDs.
local function ScanCharacterCurrencies()
    local res = {
        catalyst    = 0,
        catalystMax = 0,
        cofferKeys  = 0,
        keyShards   = 0,
        crests      = {}, -- { { name, short, qty, maxQty, hex } }
    }
    if not C_CurrencyInfo then return res end

    -- Known Midnight/TWW fallback IDs (checked first if present)
    local function TryCurrency(id)
        if type(C_CurrencyInfo.GetCurrencyInfo) ~= "function" then return nil end
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
        if ok and type(info) == "table" and not SafeIsSecret(info.name) and type(info.name) == "string" and info.name ~= "" then
            return info
        end
        return nil
    end

    -- Restored Coffer Key (3028) & Coffer Key Shard (245635 item / currency)
    local cKey = TryCurrency(3028)
    if cKey then res.cofferKeys = SafeNum(cKey.quantity, 0) end

    -- Scan currency list to discover current season Catalyst, Coffer Keys, and Crests
    if type(C_CurrencyInfo.GetCurrencyListSize) == "function" and type(C_CurrencyInfo.GetCurrencyListInfo) == "function" then
        local okSz, listSize = pcall(C_CurrencyInfo.GetCurrencyListSize)
        listSize = okSz and SafeNum(listSize, 0) or 0
        local seenCrests = {}
        for i = 1, listSize do
            local okI, info = pcall(C_CurrencyInfo.GetCurrencyListInfo, i)
            if okI and type(info) == "table" and not info.isHeader and not SafeIsSecret(info.name) then
                local name = SafeStr(info.name, "")
                local low = name:lower()
                local qty = SafeNum(info.quantity, 0)
                local maxQ = SafeNum(info.maxQuantity, 0)

                if low:find("restored coffer key", 1, true) then
                    res.cofferKeys = math.max(res.cofferKeys, qty)
                elseif low:find("coffer key shard", 1, true) then
                    res.keyShards = math.max(res.keyShards, qty)
                elseif low:find("catalyst", 1, true) or low:find("revival", 1, true) or low:find("splintered spark", 1, true) then
                    if not low:find("spark", 1, true) then
                        if qty > res.catalyst or maxQ > res.catalystMax then
                            res.catalyst = qty
                            res.catalystMax = maxQ
                        end
                    end
                elseif low:find("crest", 1, true) and (
                    low:find("weathered", 1, true)
                    or low:find("carved", 1, true)
                    or low:find("runed", 1, true)
                    or low:find("gilded", 1, true)
                    or low:find("dawn", 1, true)
                    or low:find("adventurer", 1, true)
                    or low:find("veteran", 1, true)
                    or low:find("champion", 1, true)
                    or low:find("hero", 1, true)
                    or low:find("myth", 1, true)
                ) then
                    local firstWord = name:match("^(%a+)") or "Crest"
                    local short = firstWord
                    local hex = "94A3B8"
                    local order = 6
                    if low:find("weathered", 1, true) or low:find("adventurer", 1, true) then
                        short = low:find("adventurer", 1, true) and "Adv" or "Weath"; hex = "22C55E"; order = 1
                    elseif low:find("carved", 1, true) or low:find("veteran", 1, true) then
                        short = low:find("veteran", 1, true) and "Vet" or "Carved"; hex = "38BDF8"; order = 2
                    elseif low:find("champion", 1, true) then
                        short = "Champ"; hex = "06B6D4"; order = 3
                    elseif low:find("runed", 1, true) or low:find("hero", 1, true) then
                        short = low:find("hero", 1, true) and "Hero" or "Runed"; hex = "A855F7"; order = 4
                    elseif low:find("gilded", 1, true) or low:find("myth", 1, true) then
                        short = low:find("myth", 1, true) and "Myth" or "Gilded"; hex = "F59E0B"; order = 5
                    end
                    local earned = SafeNum(info.totalEarned, 0)
                    if not seenCrests[short] and (qty > 0 or maxQ > 0) then
                        seenCrests[short] = true
                        table.insert(res.crests, {
                            name   = name,
                            short  = short,
                            qty    = qty,
                            earned = earned,
                            maxQty = maxQ,
                            hex    = hex,
                            order  = order,
                        })
                    end
                end
            end
        end
        table.sort(res.crests, function(a, b) return (a.order or 9) < (b.order or 9) end)
    end

    -- Also check bag count for Coffer Key Shards (item 245635 / 229899) if currency was 0
    if res.keyShards == 0 and C_Item and type(C_Item.GetItemCount) == "function" then
        for _, itemID in ipairs({ 245635, 229899 }) do
            local okC, cnt = pcall(C_Item.GetItemCount, itemID, true)
            if okC and SafeNum(cnt, 0) > 0 then
                res.keyShards = SafeNum(cnt, 0)
                break
            end
        end
    end

    return res
end

local function ScanRaidLockouts()
    local lockouts = {}
    if type(GetNumSavedInstances) ~= "function" or type(GetSavedInstanceInfo) ~= "function" then
        return lockouts
    end
    local diffShortMap = {
        [17] = { tag = "LFR", hex = "94A3B8", ord = 1 },
        [14] = { tag = "N",   hex = "22C55E", ord = 2 },
        [15] = { tag = "H",   hex = "38BDF8", ord = 3 },
        [16] = { tag = "M",   hex = "A855F7", ord = 4 },
    }
    local okN, num = pcall(GetNumSavedInstances)
    num = okN and SafeNum(num, 0) or 0
    for i = 1, num do
        local okI, name, _, reset, difficulty, locked, extended, _, isRaid, _, _, numEncounters, encounterProgress = pcall(GetSavedInstanceInfo, i)
        if okI and isRaid and (locked or extended) and SafeNum(reset, 0) > 0 and SafeNum(encounterProgress, 0) > 0 then
            local dm = diffShortMap[SafeNum(difficulty, 0)] or { tag = "R", hex = "CBD5E1", ord = 0 }
            table.insert(lockouts, {
                name   = SafeStr(name, "Raid"),
                diff   = dm.tag,
                hex    = dm.hex,
                ord    = dm.ord,
                killed = SafeNum(encounterProgress, 0),
                total  = SafeNum(numEncounters, 0),
            })
        end
    end
    table.sort(lockouts, function(a, b) return (a.ord or 0) > (b.ord or 0) end)
    return lockouts
end

local function ScanBountifulDelves()
    local results = {}
    if not (C_Map and C_AreaPoiInfo and type(C_AreaPoiInfo.GetDelvesForMap) == "function" and type(C_AreaPoiInfo.GetAreaPOIInfo) == "function") then
        return results
    end
    local visited = {}
    local seenPoi = {}
    local function ScanMapTree(mapID, depth)
        if not mapID or visited[mapID] or depth > 3 then return end
        visited[mapID] = true
        local okD, delvePOIs = pcall(C_AreaPoiInfo.GetDelvesForMap, mapID)
        if okD and type(delvePOIs) == "table" then
            local mapInfo = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
            local zoneName = (mapInfo and not SafeIsSecret(mapInfo.name)) and SafeStr(mapInfo.name, "") or ""
            for _, poiID in ipairs(delvePOIs) do
                if not seenPoi[poiID] then
                    local okP, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, poiID)
                    if okP and type(info) == "table" and not SafeIsSecret(info.atlasName) then
                        local atlas = SafeStr(info.atlasName, ""):lower()
                        if atlas:find("bountiful", 1, true) then
                            seenPoi[poiID] = true
                            table.insert(results, {
                                name  = SafeStr(info.name, "Bountiful Delve"),
                                zone  = zoneName,
                                mapID = mapID,
                            })
                        end
                    end
                end
            end
        end
        if type(C_Map.GetMapChildrenInfo) == "function" then
            local okC, children = pcall(C_Map.GetMapChildrenInfo, mapID)
            if okC and type(children) == "table" then
                for _, child in ipairs(children) do
                    if type(child) == "table" and child.mapID then
                        ScanMapTree(child.mapID, depth + 1)
                    end
                end
            end
        end
    end
    -- Scan player's current continent + Cosmic/Azeroth roots (Midnight / Khaz Algar zones)
    local curMap = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if curMap then
        local root = curMap
        for _ = 1, 4 do
            local mi = C_Map.GetMapInfo and C_Map.GetMapInfo(root)
            if mi and mi.parentMapID and mi.parentMapID > 0 and mi.mapType and mi.mapType > 2 then
                root = mi.parentMapID
            else
                break
            end
        end
        ScanMapTree(root, 0)
    end
    -- Also scan known expansion continents (2274 Khaz Algar, 2537 Quel'Thalas / Midnight)
    for _, contID in ipairs({ 2537, 2274 }) do
        ScanMapTree(contID, 0)
    end
    table.sort(results, function(a, b) return SafeStr(a.name, "") < SafeStr(b.name, "") end)
    return results
end

local function ScanGreatVaultTracks()
    local tracks = {
        raid  = { unlocked = 0, total = 3, maxProgress = 0, maxThreshold = 6, slots = {} },
        mplus = { unlocked = 0, total = 3, maxProgress = 0, maxThreshold = 8, slots = {} },
        world = { unlocked = 0, total = 3, maxProgress = 0, maxThreshold = 8, slots = {} },
        hasAvailableReward = false,
    }
    if not C_WeeklyRewards then return tracks end

    if type(C_WeeklyRewards.HasAvailableRewards) == "function" then
        local okR, hasR = pcall(C_WeeklyRewards.HasAvailableRewards)
        if okR and hasR == true then
            tracks.hasAvailableReward = true
        end
    end

    local enumT = _G.Enum and _G.Enum.WeeklyRewardChestThresholdType
    local typeMap = {
        { key = "raid",  t = (enumT and enumT.Raid) or 3 },
        { key = "mplus", t = (enumT and enumT.Activities) or 1 },
        { key = "world", t = (enumT and enumT.World) or 6 },
    }

    if type(C_WeeklyRewards.GetActivities) == "function" then
        for _, entry in ipairs(typeMap) do
            local okA, acts = pcall(C_WeeklyRewards.GetActivities, entry.t)
            local dst = tracks[entry.key]
            if okA and type(acts) == "table" then
                table.sort(acts, function(a, b)
                    return SafeNum(a and a.index, 0) < SafeNum(b and b.index, 0)
                end)
                dst.total = math.max(3, #acts)
                for _, act in ipairs(acts) do
                    local prog = SafeNum(act.progress, 0)
                    local thresh = SafeNum(act.threshold, 1)
                    local level = SafeNum(act.level, 0)
                    local unlocked = (prog >= thresh and thresh > 0)
                    local ilvl = 0
                    if unlocked and act.id and type(C_WeeklyRewards.GetExampleRewardItemHyperlinks) == "function" then
                        local okL, link = pcall(C_WeeklyRewards.GetExampleRewardItemHyperlinks, act.id)
                        if okL and type(link) == "string" and link ~= "" and C_Item and type(C_Item.GetDetailedItemLevelInfo) == "function" then
                            local okI, lv = pcall(C_Item.GetDetailedItemLevelInfo, link)
                            if okI then ilvl = SafeNum(lv, 0) end
                        end
                    end
                    if unlocked then dst.unlocked = dst.unlocked + 1 end
                    if prog > dst.maxProgress then dst.maxProgress = prog end
                    if thresh > dst.maxThreshold then dst.maxThreshold = thresh end
                    table.insert(dst.slots, {
                        index     = SafeNum(act.index, #dst.slots + 1),
                        progress  = prog,
                        threshold = thresh,
                        level     = level,
                        unlocked  = unlocked,
                        ilvl      = ilvl,
                    })
                end
            end
        end
    end

    return tracks
end

local function ScanOwnedKeystone()
    if not C_MythicPlus then return nil end
    local mapID = (type(C_MythicPlus.GetOwnedKeystoneChallengeMapID) == "function") and C_MythicPlus.GetOwnedKeystoneChallengeMapID() or nil
    local level = (type(C_MythicPlus.GetOwnedKeystoneLevel) == "function") and C_MythicPlus.GetOwnedKeystoneLevel() or nil
    mapID = SafeNum(mapID, 0)
    level = SafeNum(level, 0)
    if mapID <= 0 or level <= 0 then return nil end
    local mapName = ""
    if C_ChallengeMode and type(C_ChallengeMode.GetMapUIInfo) == "function" then
        local ok, n = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
        if ok and type(n) == "string" and not SafeIsSecret(n) then
            mapName = n
        end
    end
    return { mapID = mapID, level = level, name = mapName }
end

local function ApplyWeeklyRollover(db)
    local resetEpoch = GetCurrentResetEpoch()
    local chars = db.characters or {}
    for _, ch in pairs(chars) do
        if type(ch) == "table" and SafeNum(ch.resetEpoch, 0) > 0 and ch.resetEpoch < resetEpoch then
            -- Previous week's progress rolled over: if they unlocked any slots last week, flag reward ready
            local hadUnlocked = false
            if type(ch.vault) == "table" then
                for _, tk in ipairs({ "raid", "mplus", "world" }) do
                    local tr = ch.vault[tk]
                    if type(tr) == "table" then
                        if SafeNum(tr.unlocked, 0) > 0 then hadUnlocked = true end
                        tr.unlocked = 0
                        tr.maxProgress = 0
                        tr.slots = {}
                    end
                end
                if hadUnlocked then
                    ch.vault.hasAvailableReward = true
                end
            end
            ch.keystone = nil
            ch.resetEpoch = resetEpoch
        end
    end
    for _, task in ipairs(db.customTasks or {}) do
        if type(task) == "table" and SafeNum(task.resetEpoch, 0) > 0 and task.resetEpoch < resetEpoch then
            task.doneAcct = false
            task.doneChars = {}
            task.resetEpoch = resetEpoch
        end
    end
end

local function SyncDynamicBagsAlts(db)
    if not db.syncDynamicBags then return end
    local bagsDB = _G.DynamicBagsDB
    local bagChars = bagsDB and bagsDB.vault and bagsDB.vault.characters
    if type(bagChars) ~= "table" then return end
    for cKey, bData in pairs(bagChars) do
        if type(cKey) == "string" and type(bData) == "table" then
            if type(db.characters[cKey]) ~= "table" then
                local nPart, rPart = cKey:match("^([^%-]+)%-(.+)$")
                db.characters[cKey] = {
                    key        = cKey,
                    name       = SafeStr(bData.name, nPart or cKey),
                    realm      = SafeStr(bData.realm, rPart or ""),
                    classFile  = SafeStr(bData.classFile or bData.class, "WARRIOR"),
                    level      = SafeNum(bData.level, 80),
                    ilvl       = 0,
                    rating     = 0,
                    gold       = SafeNum(bData.gold or bData.money, 0),
                    specName   = "",
                    resetEpoch = GetCurrentResetEpoch(),
                    vault      = {
                        raid  = { unlocked = 0, total = 3, maxProgress = 0, maxThreshold = 6, slots = {} },
                        mplus = { unlocked = 0, total = 3, maxProgress = 0, maxThreshold = 8, slots = {} },
                        world = { unlocked = 0, total = 3, maxProgress = 0, maxThreshold = 8, slots = {} },
                        hasAvailableReward = false,
                    },
                    currencies = { catalyst = 0, catalystMax = 0, cofferKeys = 0, keyShards = 0, crests = {} },
                    lastSeen   = SafeNum(bData.lastSeen, 0),
                    fromBags   = true,
                }
            else
                local cur = db.characters[cKey]
                if SafeNum(bData.gold or bData.money, 0) > 0 and SafeNum(cur.gold, 0) == 0 then
                    cur.gold = SafeNum(bData.gold or bData.money, 0)
                end
            end
        end
    end
end

local RefreshEmbeddedUI -- forward decl

function DynamicVault:SnapshotCurrentCharacter(silent)
    local db = EnsureDB()
    if IsModuleDisabledInSuite("DynamicVault") or not db.enabled then return end
    ApplyWeeklyRollover(db)
    SyncDynamicBagsAlts(db)

    local pKey = GetPlayerKey()
    if not pKey then return end
    local name = SafeStr(UnitName("player"), "")
    local realm = SafeStr(GetRealmName(), ""):gsub("%s+", "")
    local _, classFile = UnitClass("player")
    local level = SafeNum(UnitLevel("player"), 1)
    local avgIlvl, eqIlvl = 0, 0
    if type(GetAverageItemLevel) == "function" then
        local okI, a, e = pcall(GetAverageItemLevel)
        if okI then
            avgIlvl = math.floor(SafeNum(a, 0) + 0.5)
            eqIlvl  = math.floor(SafeNum(e, 0) + 0.5)
        end
    end
    local rating = 0
    if C_ChallengeMode and type(C_ChallengeMode.GetOverallDungeonScore) == "function" then
        local okS, sc = pcall(C_ChallengeMode.GetOverallDungeonScore)
        if okS then rating = SafeNum(sc, 0) end
    end
    local specName = ""
    if type(GetSpecialization) == "function" and type(GetSpecializationInfo) == "function" then
        local idx = GetSpecialization()
        if idx then
            local _, sName = GetSpecializationInfo(idx)
            specName = SafeStr(sName, "")
        end
    end
    local gold = (type(GetMoney) == "function") and SafeNum(GetMoney(), 0) or 0

    local existing = db.characters[pKey] or {}
    existing.key        = pKey
    existing.name       = name
    existing.realm      = realm
    existing.classFile  = SafeStr(classFile, existing.classFile or "WARRIOR")
    existing.level      = level
    existing.ilvl       = (eqIlvl > 0) and eqIlvl or avgIlvl
    existing.rating     = rating
    existing.gold       = gold
    existing.specName   = specName
    existing.resetEpoch = GetCurrentResetEpoch()
    existing.vault        = ScanGreatVaultTracks()
    existing.currencies   = ScanCharacterCurrencies()
    existing.keystone     = ScanOwnedKeystone()
    existing.raidLockouts = ScanRaidLockouts()
    existing.lastSeen     = (type(time) == "function") and time() or 0
    existing.fromBags     = false

    db.characters[pKey] = existing
    local bDelves = ScanBountifulDelves()
    if #bDelves > 0 then
        db.bountifulDelves = bDelves
    end

    if not silent and RefreshEmbeddedUI then
        RefreshEmbeddedUI()
    end
end

function DynamicVault:OpenBlizzardVault()
    if InCombatLockdown and InCombatLockdown() then
        Print("Cannot open the Great Vault during combat.")
        return
    end
    if C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
        pcall(C_AddOns.LoadAddOn, "Blizzard_WeeklyRewards")
    elseif type(LoadAddOn) == "function" then
        pcall(LoadAddOn, "Blizzard_WeeklyRewards")
    end
    if type(_G.WeeklyRewards_ShowUI) == "function" then
        pcall(_G.WeeklyRewards_ShowUI)
    elseif _G.WeeklyRewardsFrame and type(_G.WeeklyRewardsFrame.Show) == "function" then
        pcall(_G.WeeklyRewardsFrame.Show, _G.WeeklyRewardsFrame)
    else
        Print("Great Vault UI is unavailable right now.")
    end
end

function DynamicVault:GetStatusText()
    local db = EnsureDB()
    if IsModuleDisabledInSuite("DynamicVault") or not db.enabled then
        return "|cFFF43F5EDisabled|r"
    end
    local pKey = GetPlayerKey()
    local ch = pKey and db.characters[pKey]
    if ch and type(ch.vault) == "table" then
        local totalSlots = SafeNum(ch.vault.raid and ch.vault.raid.unlocked, 0)
            + SafeNum(ch.vault.mplus and ch.vault.mplus.unlocked, 0)
            + SafeNum(ch.vault.world and ch.vault.world.unlocked, 0)
        if ch.vault.hasAvailableReward then
            return "|cFFFBBF24Reward Ready!|r"
        end
        return string.format("|cFF10B981%d/9 Vault Slots|r", totalSlots)
    end
    return "|cFF10B981Active|r"
end

-- ============================================================================
-- 5. UI BUILDERS (100% DESIGN_SYSTEM.md COMPLIANT)
-- ============================================================================
local activeEmbeddedRoot = nil

local function CreateSectionBox(parent, yOffset)
    local surf = GetTheme()
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    ApplyBackdrop(box, { 0.031, 0.039, 0.055, 0.72 }, { 1, 1, 1, 0.08 })
    return box
end

-- 2-Line Tall 36px L-Bracket Section Header (DESIGN_SYSTEM.md)
local function CreateSectionHeader(parent, yOffset, title, subtitle)
    local _, acc = GetTheme()
    local hdr = CreateFrame("Frame", nil, parent)
    hdr:SetHeight(36)
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    hdr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)

    local vBar = CreateSolidTex(hdr, "ARTWORK", 1, acc.r, acc.g, acc.b, 1.0)
    vBar:SetWidth(3)
    vBar:SetPoint("TOPLEFT", hdr, "TOPLEFT", 0, -2)
    vBar:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 0, 2)

    local hRule = CreateSolidTex(hdr, "ARTWORK", 1, acc.r, acc.g, acc.b, 0.35)
    hRule:SetHeight(1)
    hRule:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 0, 0)
    hRule:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)

    local tFs = hdr:CreateFontString(nil, "OVERLAY")
    SetFontSafe(tFs, 11.5, "")
    tFs:SetPoint("TOPLEFT", hdr, "TOPLEFT", 10, -3)
    tFs:SetPoint("TOPRIGHT", hdr, "TOPRIGHT", -4, -3)
    tFs:SetJustifyH("LEFT")
    tFs:SetWordWrap(false)
    tFs:SetTextColor(acc.r, acc.g, acc.b, 1.0)
    tFs:SetText(title)

    local sFs = hdr:CreateFontString(nil, "OVERLAY")
    SetFontSafe(sFs, 9.5, "")
    sFs:SetPoint("TOPLEFT", tFs, "BOTTOMLEFT", 0, -2)
    sFs:SetPoint("TOPRIGHT", hdr, "TOPRIGHT", -4, -18)
    sFs:SetJustifyH("LEFT")
    sFs:SetWordWrap(false)
    sFs:SetTextColor(0.58, 0.65, 0.74, 0.95)
    sFs:SetText(subtitle or "")

    return hdr, -44
end

local function CreateStyledButton(parent, label, width, height, primary, onClick)
    local surf, acc = GetTheme()
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 110, height or 24)
    local baseBg = primary and { acc.r * 0.42, acc.g * 0.42, acc.b * 0.42, 0.96 } or { 0.078, 0.090, 0.122, 0.96 }
    local baseBd = primary and { acc.r, acc.g, acc.b, 0.95 } or surf.border
    ApplyBackdrop(btn, baseBg, baseBd)

    local fs = btn:CreateFontString(nil, "OVERLAY")
    SetFontSafe(fs, 10.5, "")
    fs:SetPoint("CENTER")
    fs:SetTextColor(primary and 1 or 0.88, primary and 1 or 0.92, primary and 1 or 0.96, 1)
    fs:SetText(label)
    btn.label = fs

    btn:SetScript("OnEnter", function(s)
        local _, a = GetTheme()
        ApplyBackdrop(s, { a.r * 0.50, a.g * 0.50, a.b * 0.50, 0.98 }, { a.r, a.g, a.b, 1.0 })
        fs:SetTextColor(1, 1, 1, 1)
    end)
    btn:SetScript("OnLeave", function(s)
        ApplyBackdrop(s, baseBg, baseBd)
        fs:SetTextColor(primary and 1 or 0.88, primary and 1 or 0.92, primary and 1 or 0.96, 1)
    end)
    btn:SetScript("OnClick", function()
        if type(onClick) == "function" then onClick(btn) end
    end)
    return btn
end

-- Option 3 Coral-Rose OffBar Segmented Switch Card (Off LEFT 68 / Enabled RIGHT 84 inside 156x26)
local function CreateSegmentedSwitchCard(parent, yOffset, title, desc, getter, setter)
    local surf, acc = GetTheme()
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetHeight(60)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    ApplyBackdrop(card, surf.card, { 1, 1, 1, 0.06 })

    local track = CreateFrame("Frame", nil, card, "BackdropTemplate")
    track:SetSize(156, 26)
    track:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    ApplyBackdrop(track, { 0.043, 0.051, 0.071, 0.98 }, { 1, 1, 1, 0.08 })

    local titleFs = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(titleFs, 11.5, "")
    titleFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -9)
    titleFs:SetPoint("RIGHT", track, "LEFT", -14, 0)
    titleFs:SetJustifyH("LEFT")
    titleFs:SetWordWrap(false)
    titleFs:SetTextColor(0.95, 0.97, 1.0, 1.0)
    titleFs:SetText(title)

    local descFs = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(descFs, 9.5, "")
    descFs:SetPoint("TOPLEFT", titleFs, "BOTTOMLEFT", 0, -3)
    descFs:SetPoint("RIGHT", track, "LEFT", -14, 0)
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
    local offBar = CreateSolidTex(btnOff, "OVERLAY", 2, 0.973, 0.443, 0.443, 0.90) -- #F87171 Coral-Rose OffBar
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
            ApplyBackdrop(btnOff, { 0.043, 0.051, 0.071, 0.0 }, { 0, 0, 0, 0 })
            offFs:SetTextColor(0.52, 0.58, 0.68, 0.90)
            offBar:Hide()
            ApplyBackdrop(btnOn, { a.r * 0.42, a.g * 0.42, a.b * 0.42, 0.98 }, { a.r, a.g, a.b, 0.95 })
            onFs:SetTextColor(1, 1, 1, 1)
        else
            ApplyBackdrop(btnOff, { 0.118, 0.141, 0.188, 0.98 }, { 0.392, 0.455, 0.545, 0.90 })
            offFs:SetTextColor(0.886, 0.910, 0.941, 1)
            offBar:Show()
            ApplyBackdrop(btnOn, { 0.043, 0.051, 0.071, 0.0 }, { 0, 0, 0, 0 })
            onFs:SetTextColor(0.52, 0.58, 0.68, 0.90)
        end
    end

    btnOff:SetScript("OnClick", function()
        setter(false)
        UpdateVisual()
    end)
    btnOn:SetScript("OnClick", function()
        setter(true)
        UpdateVisual()
    end)
    UpdateVisual()
    return card, -66
end

-- 256x26 Sleek Precision Track Slider Card (DESIGN_SYSTEM.md)
local function CreateSliderCard(parent, yOffset, title, desc, minVal, maxVal, step, getter, setter, formatFn)
    local surf, acc = GetTheme()
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetHeight(60)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    ApplyBackdrop(card, surf.card, { 1, 1, 1, 0.06 })

    local host = CreateFrame("Frame", nil, card)
    host:SetSize(256, 26)
    host:SetPoint("RIGHT", card, "RIGHT", -12, 0)

    local titleFs = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(titleFs, 11.5, "")
    titleFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -9)
    titleFs:SetPoint("RIGHT", host, "LEFT", -14, 0)
    titleFs:SetJustifyH("LEFT")
    titleFs:SetWordWrap(false)
    titleFs:SetTextColor(0.95, 0.97, 1.0, 1.0)
    titleFs:SetText(title)

    local descFs = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(descFs, 9.5, "")
    descFs:SetPoint("TOPLEFT", titleFs, "BOTTOMLEFT", 0, -3)
    descFs:SetPoint("RIGHT", host, "LEFT", -14, 0)
    descFs:SetJustifyH("LEFT")
    descFs:SetJustifyV("TOP")
    descFs:SetWordWrap(true)
    if descFs.SetMaxLines then descFs:SetMaxLines(2) end
    descFs:SetTextColor(0.58, 0.65, 0.74, 0.95)
    descFs:SetText(desc or "")

    local valFs = host:CreateFontString(nil, "OVERLAY")
    SetFontSafe(valFs, 11, "")
    valFs:SetPoint("RIGHT", host, "RIGHT", 0, 0)
    valFs:SetWidth(52)
    valFs:SetJustifyH("RIGHT")
    valFs:SetWordWrap(false)
    valFs:SetTextColor(acc.r, acc.g, acc.b, 1.0)

    local slider = CreateFrame("Slider", nil, host)
    slider:SetOrientation("HORIZONTAL")
    slider:SetPoint("LEFT", host, "LEFT", 0, 0)
    slider:SetPoint("RIGHT", valFs, "LEFT", -10, 0)
    slider:SetHeight(4)
    slider:SetHitRectInsets(0, 0, -10, -10)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(false)
    slider:EnableMouse(true)
    slider:EnableMouseWheel(true)

    local hairline = CreateSolidTex(slider, "BACKGROUND", -1, 1, 1, 1, 0.14)
    hairline:SetPoint("TOPLEFT", slider, "TOPLEFT", -1, 1)
    hairline:SetPoint("BOTTOMRIGHT", slider, "BOTTOMRIGHT", 1, -1)

    local trackBg = CreateSolidTex(slider, "BACKGROUND", 0, 0.035, 0.039, 0.051, 0.98)
    trackBg:SetAllPoints()

    local fill = CreateSolidTex(slider, "ARTWORK", 1, acc.r, acc.g, acc.b, 0.85)
    fill:SetPoint("TOPLEFT", slider, "TOPLEFT", 0, 0)
    fill:SetPoint("BOTTOMLEFT", slider, "BOTTOMLEFT", 0, 0)
    fill:SetWidth(1)

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(6, 14)
    thumb:SetColorTexture(0.97, 0.98, 1.00, 1.0)
    if thumb.SetSnapToPixelGrid then
        thumb:SetSnapToPixelGrid(false)
        thumb:SetTexelSnappingBias(0)
    end
    slider:SetThumbTexture(thumb)

    local isDragging = false
    local suppressCallback = false
    local lastCommittedValue = nil

    local function SnapValue(v)
        local stp = step or 1
        local safeV = math.max(minVal, math.min(maxVal, SafeNum(v, minVal)))
        local snapped = math.floor(((safeV - minVal) / stp) + 0.5) * stp + minVal
        return math.max(minVal, math.min(maxVal, snapped))
    end

    local function SyncVal(v, rawVal)
        local _, curAcc = GetTheme()
        local posVal = rawVal or v
        local pct = (maxVal > minVal) and ((posVal - minVal) / (maxVal - minVal)) or 0
        pct = math.max(0, math.min(1, pct))
        local w = slider:GetWidth()
        if not w or w <= 0 then w = 194 end
        fill:SetColorTexture(curAcc.r, curAcc.g, curAcc.b, 0.85)
        fill:SetWidth(math.max(1, w * pct))
        if isDragging or (slider.IsMouseOver and slider:IsMouseOver()) then
            thumb:SetColorTexture(curAcc.r, curAcc.g, curAcc.b, 1.0)
        else
            thumb:SetColorTexture(0.97, 0.98, 1.00, 1.0)
        end
        valFs:SetTextColor(curAcc.r, curAcc.g, curAcc.b, 1.0)
        valFs:SetText(formatFn and formatFn(v) or tostring(v))
    end

    local function RefreshSlider()
        suppressCallback = true
        local cur = SnapValue(getter())
        lastCommittedValue = cur
        slider:SetValue(cur)
        SyncVal(cur, cur)
        suppressCallback = false
    end

    local function UpdateFromCursor()
        if isDragging and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            isDragging = false
            slider:SetScript("OnUpdate", nil)
            RefreshSlider()
            return
        end
        local scale = (slider.GetEffectiveScale and slider:GetEffectiveScale()) or 1
        local cx = (GetCursorPosition() / scale)
        local left, tw = slider:GetLeft(), slider:GetWidth()
        if left and tw and tw > 0 then
            local pct = math.max(0, math.min(1, (cx - left) / tw))
            slider:SetValue(minVal + pct * (maxVal - minVal))
        end
    end

    RefreshSlider()
    C_Timer.After(0, RefreshSlider)
    slider:SetScript("OnSizeChanged", function()
        local r = SnapValue(slider:GetValue())
        SyncVal(r, slider:GetValue())
    end)
    slider:SetScript("OnEnter", function(self)
        local r = SnapValue(self:GetValue())
        SyncVal(r, self:GetValue())
        if GameTooltip then
            local _, curAcc = GetTheme()
            local hex = string.format("%02X%02X%02X", math.floor(curAcc.r * 255 + 0.5), math.floor(curAcc.g * 255 + 0.5), math.floor(curAcc.b * 255 + 0.5))
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(string.format("|cFF%sLeft-Click / Drag:|r |cFFE2E8F0Adjust value|r", hex))
            GameTooltip:AddLine(string.format("|cFF%sMousewheel:|r |cFFE2E8F0Fine-tune by 1 step|r", hex))
            GameTooltip:Show()
        end
    end)
    slider:SetScript("OnLeave", function(self)
        local r = SnapValue(self:GetValue())
        SyncVal(r, self:GetValue())
        if GameTooltip then GameTooltip:Hide() end
    end)
    slider:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            isDragging = true
            UpdateFromCursor()
            self:SetScript("OnUpdate", UpdateFromCursor)
        end
    end)
    slider:SetScript("OnMouseUp", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
        RefreshSlider()
    end)
    slider:SetScript("OnHide", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
        local r = SnapValue(getter())
        SyncVal(r, r)
    end)
    slider:SetScript("OnMouseWheel", function(_, delta)
        local cur = SnapValue(getter())
        local nxt = SnapValue(cur + (delta * (step or 1)))
        lastCommittedValue = nxt
        setter(nxt)
        RefreshSlider()
    end)
    slider:SetScript("OnValueChanged", function(_, v)
        if suppressCallback then return end
        local snapped = SnapValue(v)
        SyncVal(snapped, v)
        if snapped ~= lastCommittedValue then
            lastCommittedValue = snapped
            setter(snapped)
        end
    end)

    return card, -66
end

-- ============================================================================
-- 6. WORKSPACE RENDERER (EMBEDDED IN /ds & STANDALONE /dv)
-- ============================================================================
local function GetSortedCharacters(db)
    local list = {}
    local pKey = GetPlayerKey()
    for cKey, ch in pairs(db.characters or {}) do
        if type(ch) == "table" then
            local lvl = SafeNum(ch.level, 1)
            local passLvl = (not db.filterMaxLevelOnly) or (lvl >= SafeNum(db.minLevelFilter, 80)) or (cKey == pKey)
            if passLvl then
                table.insert(list, ch)
            end
        end
    end

    local mode = db.sortMode or "VAULT"
    table.sort(list, function(a, b)
        local fa = db.favourites[a.key] and true or false
        local fb = db.favourites[b.key] and true or false
        if fa ~= fb then return fa end
        if a.key == pKey and b.key ~= pKey then return true end
        if b.key == pKey and a.key ~= pKey then return false end

        if mode == "ILVL" then
            if SafeNum(a.ilvl, 0) ~= SafeNum(b.ilvl, 0) then
                return SafeNum(a.ilvl, 0) > SafeNum(b.ilvl, 0)
            end
        elseif mode == "RATING" then
            if SafeNum(a.rating, 0) ~= SafeNum(b.rating, 0) then
                return SafeNum(a.rating, 0) > SafeNum(b.rating, 0)
            end
        elseif mode == "VAULT" then
            local va = SafeNum(a.vault and a.vault.raid and a.vault.raid.unlocked, 0)
                + SafeNum(a.vault and a.vault.mplus and a.vault.mplus.unlocked, 0)
                + SafeNum(a.vault and a.vault.world and a.vault.world.unlocked, 0)
            local vb = SafeNum(b.vault and b.vault.raid and b.vault.raid.unlocked, 0)
                + SafeNum(b.vault and b.vault.mplus and b.vault.mplus.unlocked, 0)
                + SafeNum(b.vault and b.vault.world and b.vault.world.unlocked, 0)
            if va ~= vb then return va > vb end
        end
        return SafeStr(a.name, "") < SafeStr(b.name, "")
    end)
    return list
end

local function CreateVaultTrackWidget(parent, label, trackData)
    local wrap = CreateFrame("Frame", nil, parent)
    wrap:SetSize(148, 22)

    local lbl = wrap:CreateFontString(nil, "OVERLAY")
    SetFontSafe(lbl, 9.5, "")
    lbl:SetPoint("LEFT", wrap, "LEFT", 0, 0)
    lbl:SetWidth(42)
    lbl:SetJustifyH("LEFT")
    lbl:SetWordWrap(false)
    lbl:SetTextColor(0.62, 0.69, 0.78, 1.0)
    lbl:SetText(label)

    local unlocked = SafeNum(trackData and trackData.unlocked, 0)
    local slots = (trackData and type(trackData.slots) == "table") and trackData.slots or {}

    for idx = 1, 3 do
        local slot = slots[idx]
        local isDone = (slot and slot.unlocked) or (idx <= unlocked)
        local pip = CreateFrame("Frame", nil, wrap, "BackdropTemplate")
        pip:SetSize(32, 16)
        pip:SetPoint("LEFT", wrap, "LEFT", 44 + ((idx - 1) * 35), 0)
        if isDone then
            ApplyBackdrop(pip, { 0.063, 0.725, 0.506, 0.28 }, { 0.063, 0.725, 0.506, 0.90 })
        else
            ApplyBackdrop(pip, { 0.078, 0.090, 0.122, 0.92 }, { 0.145, 0.165, 0.212, 0.90 })
        end
        local pFs = pip:CreateFontString(nil, "OVERLAY")
        SetFontSafe(pFs, 9, "")
        pFs:SetPoint("CENTER")
        if isDone then
            local ilvl = SafeNum(slot and slot.ilvl, 0)
            pFs:SetText(ilvl > 0 and tostring(ilvl) or "OK")
            pFs:SetTextColor(0.55, 0.98, 0.78, 1.0)
        else
            local prog = SafeNum(slot and slot.progress, SafeNum(trackData and trackData.maxProgress, 0))
            local th = SafeNum(slot and slot.threshold, 0)
            pFs:SetText((th > 0) and string.format("%d/%d", math.min(prog, th), th) or "-")
            pFs:SetTextColor(0.45, 0.52, 0.62, 0.95)
        end
    end
    return wrap
end

local function RenderVaultEmbedded(parent)
    if not parent then return end
    if activeEmbeddedRoot and activeEmbeddedRoot:GetParent() == parent then
        activeEmbeddedRoot:Hide()
        activeEmbeddedRoot:SetParent(nil)
    end

    local db = EnsureDB()
    ApplyWeeklyRollover(db)
    SyncDynamicBagsAlts(db)

    local surf, acc = GetTheme()
    local root = CreateFrame("Frame", nil, parent)
    root:SetAllPoints(parent)
    activeEmbeddedRoot = root

    -- Top 3-Tab Recessed Bevel Bar (1:1 DESIGN_SYSTEM.md: 14/-16 margins, 34px height, #0B0D12)
    local tabBar = CreateFrame("Frame", nil, root, "BackdropTemplate")
    tabBar:SetHeight(34)
    tabBar:SetPoint("TOPLEFT", root, "TOPLEFT", 14, -10)
    tabBar:SetPoint("TOPRIGHT", root, "TOPRIGHT", -16, -10)
    ApplyBackdrop(tabBar, { 0.043, 0.051, 0.071, 0.98 }, { 1, 1, 1, 0.08 })

    local tabs = {
        { id = 1, label = "Account Matrix" },
        { id = 2, label = "Weekly Checklist" },
        { id = 3, label = "Settings & Maintenance" },
    }
    local tabBtns = {}

    local function ReflowVaultTabBar()
        local w = tabBar:GetWidth()
        if not w or w <= 60 then return end
        local usable = w - 8 - (4 * (#tabBtns - 1))
        local each = math.floor(usable / #tabBtns)
        for i, btn in ipairs(tabBtns) do
            btn:ClearAllPoints()
            btn:SetHeight(26)
            if i == 1 then
                btn:SetPoint("LEFT", tabBar, "LEFT", 4, 0)
                btn:SetWidth(each)
            elseif i == #tabBtns then
                btn:SetPoint("LEFT", tabBtns[i - 1], "RIGHT", 4, 0)
                btn:SetPoint("RIGHT", tabBar, "RIGHT", -4, 0)
            else
                btn:SetPoint("LEFT", tabBtns[i - 1], "RIGHT", 4, 0)
                btn:SetWidth(each)
            end
        end
    end

    local function StyleVaultTabs()
        local _, a = GetTheme()
        for _, btn in ipairs(tabBtns) do
            local active = (db.activeSubTab == btn.tabId)
            if active then
                ApplyBackdrop(btn, { a.r * 0.42, a.g * 0.42, a.b * 0.42, 0.98 }, { a.r, a.g, a.b, 0.95 })
                btn.label:SetTextColor(1, 1, 1, 1)
            else
                ApplyBackdrop(btn, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 })
                btn.label:SetTextColor(0.68, 0.74, 0.82, 1.0)
            end
        end
    end

    for _, t in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, tabBar, "BackdropTemplate")
        btn.tabId = t.id
        local fs = btn:CreateFontString(nil, "OVERLAY")
        SetFontSafe(fs, 11, "")
        fs:SetPoint("CENTER")
        fs:SetText(t.label)
        btn.label = fs
        btn:SetScript("OnEnter", function(s)
            if db.activeSubTab ~= s.tabId then
                local _, a = GetTheme()
                ApplyBackdrop(s, { 0.105, 0.122, 0.162, 0.98 }, { a.r, a.g, a.b, 0.65 })
                fs:SetTextColor(0.95, 0.97, 1.0, 1.0)
            end
        end)
        btn:SetScript("OnLeave", function() StyleVaultTabs() end)
        btn:SetScript("OnClick", function(s)
            db.activeSubTab = s.tabId
            RenderVaultEmbedded(parent)
        end)
        table.insert(tabBtns, btn)
    end
    tabBar:SetScript("OnSizeChanged", ReflowVaultTabBar)
    tabBar:SetScript("OnShow", ReflowVaultTabBar)
    ReflowVaultTabBar()
    C_Timer.After(0, ReflowVaultTabBar)
    StyleVaultTabs()

    -- ScrollFrame anchored directly -8px below tabBar + 4px Obsidian Scrollbar
    local scrollFrame = CreateFrame("ScrollFrame", nil, root)
    scrollFrame:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -8)
    scrollFrame:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", 0, -8)
    scrollFrame:SetPoint("BOTTOM", root, "BOTTOM", 0, 10)
    scrollFrame:EnableMouseWheel(true)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(600)
    scrollFrame:SetScrollChild(scrollContent)

    local track = CreateFrame("Frame", nil, root, "BackdropTemplate")
    track:SetWidth(4)
    track:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 10, -2)
    track:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 10, 2)
    track:EnableMouse(true)
    track:SetHitRectInsets(-5, -5, 0, 0)
    ApplyBackdrop(track, { 0.043, 0.051, 0.071, 0.85 }, { 0, 0, 0, 0 })

    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(4)
    thumb:SetHeight(48)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    thumb:EnableMouse(true)
    thumb:SetHitRectInsets(-5, -5, 0, 0)
    thumb.tex = CreateSolidTex(thumb, "OVERLAY", 2, 0.38, 0.45, 0.56, 0.85)
    thumb.tex:SetAllPoints()

    local function SyncThumbColor()
        local _, a = GetTheme()
        if thumb.isDragging then
            thumb.tex:SetColorTexture(a.r, a.g, a.b, 1.0)
        elseif thumb.isHovered then
            thumb.tex:SetColorTexture(a.r, a.g, a.b, 0.90)
        else
            thumb.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
        end
    end

    local function UpdateScrollBar()
        if scrollFrame.UpdateScrollChildRect then pcall(scrollFrame.UpdateScrollChildRect, scrollFrame) end
        SyncThumbColor()
        local viewH = scrollFrame:GetHeight() or 1
        local totalH = scrollContent:GetHeight() or 1
        local maxScroll = math.max(0, totalH - viewH)
        if maxScroll <= 1 then
            track:Hide()
            thumb:Hide()
            scrollFrame:SetVerticalScroll(0)
            return
        end
        track:Show()
        thumb:Show()
        local cur = math.max(0, math.min(maxScroll, scrollFrame:GetVerticalScroll() or 0))
        local trackH = track:GetHeight() or 1
        local thumbH = math.max(24, math.floor(trackH * math.min(1, viewH / totalH) + 0.5))
        local travel = math.max(1, trackH - thumbH)
        thumb:SetHeight(thumbH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -math.floor((cur / maxScroll) * travel + 0.5))
    end

    local function ScrollVaultFromCursor()
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            thumb.isDragging = false
            thumb:SetScript("OnUpdate", nil)
            track:SetScript("OnUpdate", nil)
            SyncThumbColor()
            return
        end
        local viewH = scrollFrame:GetHeight() or 0
        local totalH = scrollContent:GetHeight() or 0
        local trackH = track:GetHeight() or 0
        local maxScroll = math.max(0, totalH - viewH)
        if maxScroll <= 1 or trackH <= 1 then return end
        local tTop = track:GetTop()
        local eff = track:GetEffectiveScale() or 1
        if not tTop or eff <= 0 then return end
        local _, cy = GetCursorPosition()
        local relY = math.max(0, math.min(trackH, tTop - (cy / eff)))
        local thumbH = thumb:GetHeight() or 24
        local travel = math.max(1, trackH - thumbH)
        local pct = math.max(0, math.min(1, (relY - (thumbH * 0.5)) / travel))
        scrollFrame:SetVerticalScroll(pct * maxScroll)
        UpdateScrollBar()
    end

    local function ScrollByDelta(delta)
        local viewH = scrollFrame:GetHeight() or 1
        local totalH = scrollContent:GetHeight() or 1
        local maxScroll = math.max(0, totalH - viewH)
        local nextPos = math.max(0, math.min(maxScroll, (scrollFrame:GetVerticalScroll() or 0) - (delta * 38)))
        scrollFrame:SetVerticalScroll(nextPos)
        UpdateScrollBar()
    end

    thumb:SetScript("OnEnter", function(self)
        self.isHovered = true
        SyncThumbColor()
    end)
    thumb:SetScript("OnLeave", function(self)
        self.isHovered = false
        SyncThumbColor()
    end)
    thumb:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then
            self.isDragging = true
            SyncThumbColor()
            ScrollVaultFromCursor()
            self:SetScript("OnUpdate", ScrollVaultFromCursor)
        end
    end)
    thumb:SetScript("OnMouseUp", function(self, btn)
        if btn == "LeftButton" then
            self.isDragging = false
            self:SetScript("OnUpdate", nil)
            SyncThumbColor()
        end
    end)
    thumb:SetScript("OnHide", function(self)
        self.isDragging = false
        self.isHovered = false
        self:SetScript("OnUpdate", nil)
        SyncThumbColor()
    end)
    track:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then
            thumb.isDragging = true
            SyncThumbColor()
            ScrollVaultFromCursor()
            self:SetScript("OnUpdate", ScrollVaultFromCursor)
        end
    end)
    track:SetScript("OnMouseUp", function(self, btn)
        if btn == "LeftButton" then
            thumb.isDragging = false
            self:SetScript("OnUpdate", nil)
            SyncThumbColor()
        end
    end)
    track:SetScript("OnHide", function(self)
        thumb.isDragging = false
        self:SetScript("OnUpdate", nil)
        SyncThumbColor()
    end)

    scrollFrame:SetScript("OnMouseWheel", function(_, delta) ScrollByDelta(delta) end)
    track:SetScript("OnMouseWheel", function(_, delta) ScrollByDelta(delta) end)
    thumb:SetScript("OnMouseWheel", function(_, delta) ScrollByDelta(delta) end)
    scrollFrame:SetScript("OnSizeChanged", function(_, w)
        if w and w > 40 then scrollContent:SetWidth(w) end
        UpdateScrollBar()
    end)
    scrollFrame:SetScript("OnShow", UpdateScrollBar)

    local y = 0
    local tabId = db.activeSubTab or 1

    if tabId == 1 then
        -- Top Live Telemetry & Quick Action Banner
        local banner = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
        banner:SetHeight(48)
        banner:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, y)
        banner:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, y)
        ApplyBackdrop(banner, { 0.043, 0.051, 0.071, 0.96 }, { acc.r, acc.g, acc.b, 0.45 })

        local secsLeft = (C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset) and SafeNum(C_DateAndTime.GetSecondsUntilWeeklyReset(), 0) or 0
        local pKey = GetPlayerKey()
        local curChar = pKey and db.characters[pKey]
        local hasReward = curChar and curChar.vault and curChar.vault.hasAvailableReward

        local openBtn = CreateStyledButton(banner, "Open Great Vault", 128, 26, true, function()
            DynamicVault:OpenBlizzardVault()
        end)
        openBtn:SetPoint("RIGHT", banner, "RIGHT", -12, 0)

        local scanBtn = CreateStyledButton(banner, "Refresh", 68, 26, false, function()
            DynamicVault:SnapshotCurrentCharacter(false)
        end)
        scanBtn:SetPoint("RIGHT", openBtn, "LEFT", -6, 0)
        scanBtn:HookScript("OnEnter", function(s)
            if GameTooltip then
                GameTooltip:SetOwner(s, "ANCHOR_TOP")
                GameTooltip:SetText("Refresh Character Data", 1, 1, 1)
                GameTooltip:AddLine("Re-reads your current character's Great Vault progress, Keystones, Crests, and Coffer Keys right now.", 0.82, 0.86, 0.92, true)
                GameTooltip:Show()
            end
        end)
        scanBtn:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

        local bTitle = banner:CreateFontString(nil, "OVERLAY")
        SetFontSafe(bTitle, 11.5, "")
        bTitle:SetPoint("TOPLEFT", banner, "TOPLEFT", 14, -8)
        bTitle:SetPoint("RIGHT", scanBtn, "LEFT", -10, 0)
        bTitle:SetJustifyH("LEFT")
        bTitle:SetWordWrap(false)
        bTitle:SetTextColor(0.95, 0.97, 1.0, 1.0)
        bTitle:SetText(string.format("Weekly Reset in |cFF38BDF8%s|r%s",
            FormatTimeRemaining(secsLeft),
            hasReward and "   |   |cFFFBBF24GREAT VAULT REWARD READY!|r" or ""))

        local bSub = banner:CreateFontString(nil, "OVERLAY")
        SetFontSafe(bSub, 9.5, "")
        bSub:SetPoint("TOPLEFT", bTitle, "BOTTOMLEFT", 0, -2)
        bSub:SetPoint("RIGHT", scanBtn, "LEFT", -10, 0)
        bSub:SetJustifyH("LEFT")
        bSub:SetWordWrap(false)
        bSub:SetTextColor(0.60, 0.67, 0.76, 1.0)
        local charCount, totalGold, totalKeys, readyCount = 0, 0, 0, 0
        for _, cData in pairs(db.characters or {}) do
            if type(cData) == "table" then
                charCount = charCount + 1
                totalGold = totalGold + SafeNum(cData.gold, 0)
                totalKeys = totalKeys + SafeNum(cData.currencies and cData.currencies.cofferKeys, 0)
                if cData.vault and cData.vault.hasAvailableReward then readyCount = readyCount + 1 end
            end
        end
        local wbGold = (_G.DynamicBagsDB and _G.DynamicBagsDB.vault and SafeNum(_G.DynamicBagsDB.vault.warbandGold, 0)) or 0
        totalGold = totalGold + wbGold
        bSub:SetText(string.format("%d Alts  |  Account Gold: |cFFFCD34D%s|r  |  Total Keys: |cFFFBBF24%d|r%s",
            charCount, FormatGoldCompact(totalGold), totalKeys,
            readyCount > 0 and string.format("  |  |cFFFBBF24%d Vault(s) Ready|r", readyCount) or ""))

        y = y - 56

        -- Filter & Sort Strip
        local bar = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
        bar:SetHeight(34)
        bar:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, y)
        bar:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, y)
        ApplyBackdrop(bar, surf.card, { 1, 1, 1, 0.06 })

        local sortOrder = { "VAULT", "ILVL", "RATING", "NAME" }
        local sortLabels = { VAULT = "Sort: Vault Slots", ILVL = "Sort: Item Level", RATING = "Sort: M+ Rating", NAME = "Sort: Name" }
        local sortBtn = CreateStyledButton(bar, sortLabels[db.sortMode or "VAULT"] or "Sort: Vault Slots", 124, 22, false, function()
            local idx = 1
            for i, m in ipairs(sortOrder) do if m == db.sortMode then idx = i break end end
            db.sortMode = sortOrder[(idx % #sortOrder) + 1]
            RenderVaultEmbedded(parent)
        end)
        sortBtn:SetPoint("LEFT", bar, "LEFT", 8, 0)

        local lvlBtn = CreateStyledButton(bar, db.filterMaxLevelOnly and string.format("Level %d+: ON", SafeNum(db.minLevelFilter, 80)) or "Show: All Levels", 118, 22, db.filterMaxLevelOnly, function()
            db.filterMaxLevelOnly = not db.filterMaxLevelOnly
            RenderVaultEmbedded(parent)
        end)
        lvlBtn:SetPoint("LEFT", sortBtn, "RIGHT", 6, 0)

        local hintFs = bar:CreateFontString(nil, "OVERLAY")
        SetFontSafe(hintFs, 9.5, "")
        hintFs:SetPoint("LEFT", lvlBtn, "RIGHT", 10, 0)
        hintFs:SetPoint("RIGHT", bar, "RIGHT", -10, 0)
        hintFs:SetJustifyH("RIGHT")
        hintFs:SetWordWrap(false)
        hintFs:SetTextColor(0.55, 0.62, 0.72, 0.95)
        hintFs:SetText("Star (*) pins alts | Log in once to sync")

        y = y - 42

        -- Today's Bountiful Delves Compact Strip (when active delves discovered)
        if db.showBountifulDelves ~= false and type(db.bountifulDelves) == "table" and #db.bountifulDelves > 0 then
            local bdBar = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
            bdBar:SetHeight(30)
            bdBar:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, y)
            bdBar:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, y)
            ApplyBackdrop(bdBar, { 0.043, 0.051, 0.071, 0.96 }, { 0.96, 0.62, 0.04, 0.45 })

            local dNames = {}
            for i = 1, math.min(#db.bountifulDelves, 5) do
                local d = db.bountifulDelves[i]
                local zPart = (d.zone and d.zone ~= "") and (" (" .. d.zone .. ")") or ""
                table.insert(dNames, SafeStr(d.name, "Delve") .. zPart)
            end
            local bdFs = bdBar:CreateFontString(nil, "OVERLAY")
            SetFontSafe(bdFs, 9.5, "")
            bdFs:SetPoint("LEFT", bdBar, "LEFT", 12, 0)
            bdFs:SetPoint("RIGHT", bdBar, "RIGHT", -12, 0)
            bdFs:SetJustifyH("LEFT")
            bdFs:SetWordWrap(false)
            bdFs:SetTextColor(0.88, 0.92, 0.98, 1.0)
            bdFs:SetText("|cFFFBBF24Today's Bountiful Delves:|r  " .. table.concat(dNames, "  |  "))
            y = y - 38
        end

        -- Character Matrix Cards
        local sorted = GetSortedCharacters(db)
        if #sorted == 0 then
            local emptyBox = CreateSectionBox(scrollContent, y)
            emptyBox:SetHeight(64)
            local eFs = emptyBox:CreateFontString(nil, "OVERLAY")
            SetFontSafe(eFs, 11, "")
            eFs:SetPoint("LEFT", emptyBox, "LEFT", 14, 0)
            eFs:SetPoint("RIGHT", emptyBox, "RIGHT", -14, 0)
            eFs:SetJustifyH("CENTER")
            eFs:SetWordWrap(true)
            eFs:SetTextColor(0.65, 0.72, 0.80, 1)
            eFs:SetText("No characters recorded yet. Click Refresh to snapshot your current character.")
            y = y - 74
        else
            for _, ch in ipairs(sorted) do
                local isMe = (ch.key == pKey)
                local cardH = (db.showCurrencies ~= false) and 86 or 64
                local card = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
                card:SetHeight(cardH)
                card:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, y)
                card:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, y)
                local bdCol = isMe and { acc.r, acc.g, acc.b, 0.72 } or { 1, 1, 1, 0.08 }
                ApplyBackdrop(card, surf.card, bdCol)

                -- Favourite Star Button
                local isFav = db.favourites[ch.key] and true or false
                local starBtn = CreateFrame("Button", nil, card)
                starBtn:SetSize(20, 20)
                starBtn:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -7)
                local starFs = starBtn:CreateFontString(nil, "OVERLAY")
                SetFontSafe(starFs, 12, "")
                starFs:SetPoint("CENTER")
                starFs:SetText(isFav and "*" or ".")
                starFs:SetTextColor(isFav and 0.98 or 0.40, isFav and 0.75 or 0.46, isFav and 0.14 or 0.56, 1)
                starBtn:SetScript("OnClick", function()
                    db.favourites[ch.key] = not db.favourites[ch.key]
                    RenderVaultEmbedded(parent)
                end)

                -- Right Telemetry (iLvl, M+ Rating, Keystone, Reward Badge, Remove)
                local rightX = -10
                if not isMe then
                    local delBtn = CreateFrame("Button", nil, card)
                    delBtn:SetSize(18, 18)
                    delBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -8)
                    local delFs = delBtn:CreateFontString(nil, "OVERLAY")
                    SetFontSafe(delFs, 10, "")
                    delFs:SetPoint("CENTER")
                    delFs:SetText("x")
                    delFs:SetTextColor(0.55, 0.62, 0.72, 0.9)
                    delBtn:SetScript("OnEnter", function() delFs:SetTextColor(0.957, 0.247, 0.369, 1) end)
                    delBtn:SetScript("OnLeave", function() delFs:SetTextColor(0.55, 0.62, 0.72, 0.9) end)
                    delBtn:SetScript("OnClick", function()
                        db.characters[ch.key] = nil
                        RenderVaultEmbedded(parent)
                    end)
                    rightX = -30
                end

                local metaParts = {}
                if ch.vault and ch.vault.hasAvailableReward then
                    table.insert(metaParts, "|cFFFBBF24[REWARD READY]|r")
                end
                if SafeNum(ch.ilvl, 0) > 0 then
                    table.insert(metaParts, string.format("|cFFE2E8F0iLvl %d|r", SafeNum(ch.ilvl, 0)))
                else
                    table.insert(metaParts, string.format("|cFF94A3B8Lv %d|r", SafeNum(ch.level, 1)))
                end
                if SafeNum(ch.rating, 0) > 0 then
                    table.insert(metaParts, string.format("|cFF38BDF8M+ %d|r", SafeNum(ch.rating, 0)))
                end
                if db.showKeystones ~= false and type(ch.keystone) == "table" and SafeNum(ch.keystone.level, 0) > 0 then
                    local kName = SafeStr(ch.keystone.name, "Key")
                    if #kName > 16 then kName = kName:sub(1, 15) .. "." end
                    table.insert(metaParts, string.format("|cFFA855F7+%d %s|r", ch.keystone.level, kName))
                end
                if db.showRaidLockouts ~= false and type(ch.raidLockouts) == "table" and #ch.raidLockouts > 0 then
                    local lo = ch.raidLockouts[1]
                    table.insert(metaParts, string.format("|cFF%s%d/%d %s|r", lo.hex or "38BDF8", SafeNum(lo.killed, 0), SafeNum(lo.total, 0), SafeStr(lo.diff, "R")))
                end

                local metaFs = card:CreateFontString(nil, "OVERLAY")
                SetFontSafe(metaFs, 10, "")
                metaFs:SetPoint("TOPRIGHT", card, "TOPRIGHT", rightX, -10)
                metaFs:SetJustifyH("RIGHT")
                metaFs:SetWordWrap(false)
                metaFs:SetText(table.concat(metaParts, "   "))

                -- Character Identity Line (clamped cleanly left of right telemetry)
                local hex = GetClassHex(ch.classFile)
                local nameFs = card:CreateFontString(nil, "OVERLAY")
                SetFontSafe(nameFs, 11.5, "")
                nameFs:SetPoint("LEFT", starBtn, "RIGHT", 4, 0)
                nameFs:SetPoint("RIGHT", metaFs, "LEFT", -8, 0)
                nameFs:SetJustifyH("LEFT")
                nameFs:SetWordWrap(false)
                local specTxt = (ch.specName and ch.specName ~= "") and ("  |cFF64748B" .. ch.specName .. "|r") or ""
                nameFs:SetText(string.format("|cFF%s%s|r |cFF64748B-%s|r%s", hex, SafeStr(ch.name, "?"), SafeStr(ch.realm, ""), specTxt))

                -- 3 Great Vault Track Rows (Raid / M+ / Delves) proportioned cleanly
                local v = ch.vault or {}
                local trackRow = CreateFrame("Frame", nil, card)
                trackRow:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -34)
                trackRow:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -34)
                trackRow:SetHeight(22)
                local wRaid   = CreateVaultTrackWidget(trackRow, "Raid",   v.raid)
                local wMplus  = CreateVaultTrackWidget(trackRow, "Myth+",  v.mplus)
                local wDelves = CreateVaultTrackWidget(trackRow, "Delves", v.world)
                local function ReflowTrackRow()
                    local rw = trackRow:GetWidth() or 516
                    if rw < 180 then return end
                    local colW = math.floor((rw - 12) / 3)
                    wRaid:ClearAllPoints()
                    wRaid:SetPoint("LEFT", trackRow, "LEFT", 0, 0)
                    wMplus:ClearAllPoints()
                    wMplus:SetPoint("LEFT", trackRow, "LEFT", colW + 6, 0)
                    wDelves:ClearAllPoints()
                    wDelves:SetPoint("LEFT", trackRow, "LEFT", (colW + 6) * 2, 0)
                end
                trackRow:SetScript("OnSizeChanged", ReflowTrackRow)
                ReflowTrackRow()

                -- Currencies & Gold Bottom Strip
                if db.showCurrencies ~= false then
                    local cur = ch.currencies or {}
                    local cParts = {}
                    if SafeNum(cur.cofferKeys, 0) > 0 or SafeNum(cur.keyShards, 0) > 0 then
                        table.insert(cParts, string.format("|cFFFBBF24Keys:|r %d (Shards: %d)", SafeNum(cur.cofferKeys, 0), SafeNum(cur.keyShards, 0)))
                    else
                        table.insert(cParts, "|cFF64748BKeys:|r 0")
                    end
                    if SafeNum(cur.catalyst, 0) > 0 or SafeNum(cur.catalystMax, 0) > 0 then
                        table.insert(cParts, string.format("|cFF38BDF8Catalyst:|r %d", SafeNum(cur.catalyst, 0)))
                    end
                    for _, cr in ipairs(cur.crests or {}) do
                        local capTxt = (SafeNum(cr.maxQty, 0) > 0) and string.format("/%d", SafeNum(cr.maxQty, 0)) or ""
                        table.insert(cParts, string.format("|cFF%s%s:|r %d%s", cr.hex or "94A3B8", cr.short or "Crest", SafeNum(cr.qty, 0), capTxt))
                    end
                    if SafeNum(ch.gold, 0) > 0 then
                        table.insert(cParts, string.format("|cFFFCD34D%s|r", FormatGoldCompact(ch.gold)))
                    end
                    local curFs = card:CreateFontString(nil, "OVERLAY")
                    SetFontSafe(curFs, 9.5, "")
                    curFs:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 12, 9)
                    curFs:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -12, 9)
                    curFs:SetJustifyH("LEFT")
                    curFs:SetWordWrap(false)
                    curFs:SetTextColor(0.76, 0.82, 0.90, 0.95)
                    curFs:SetText(table.concat(cParts, "   |   "))
                end

                y = y - (cardH + 8)
            end
        end

    elseif tabId == 2 then
        -- Tab 2: Weekly Checklist (Auto-Tracked + Custom Weekly Tasks)
        local pKey = GetPlayerKey()
        local ch = pKey and db.characters[pKey]
        local v = (ch and ch.vault) or {}
        local cur = (ch and ch.currencies) or {}

        local sec1 = CreateSectionBox(scrollContent, y)
        local sy = -10
        local _, dyh = CreateSectionHeader(sec1, sy, "AUTO-TRACKED WEEKLY PROGRESS", "Read-only live progress from Blizzard (updates automatically -- no manual clicking needed).")
        sy = sy + dyh

        local autoRows = {
            {
                title = "Claim Weekly Great Vault Reward",
                done  = not (v.hasAvailableReward == true),
                pill  = (v.hasAvailableReward == true) and "|cFFFBBF24UNCLAIMED|r" or "|cFF10B981CLAIMED|r",
            },
            {
                title = "World & Delves Track (3/3 Vault Slots)",
                done  = SafeNum(v.world and v.world.unlocked, 0) >= 3,
                pill  = string.format("%d / 3 Slots (%d/%d)", SafeNum(v.world and v.world.unlocked, 0), SafeNum(v.world and v.world.maxProgress, 0), SafeNum(v.world and v.world.maxThreshold, 8)),
            },
            {
                title = "Mythic+ Track (3/3 Vault Slots)",
                done  = SafeNum(v.mplus and v.mplus.unlocked, 0) >= 3,
                pill  = string.format("%d / 3 Slots (%d/%d)", SafeNum(v.mplus and v.mplus.unlocked, 0), SafeNum(v.mplus and v.mplus.maxProgress, 0), SafeNum(v.mplus and v.mplus.maxThreshold, 8)),
            },
            {
                title = "Raid Track (3/3 Vault Slots)",
                done  = SafeNum(v.raid and v.raid.unlocked, 0) >= 3,
                pill  = string.format("%d / 3 Slots (%d/%d)", SafeNum(v.raid and v.raid.unlocked, 0), SafeNum(v.raid and v.raid.maxProgress, 0), SafeNum(v.raid and v.raid.maxThreshold, 6)),
            },
            {
                title = "Bountiful Delve Keys & Shards",
                done  = SafeNum(cur.cofferKeys, 0) > 0,
                pill  = string.format("%d Keys  |  %d Shards", SafeNum(cur.cofferKeys, 0), SafeNum(cur.keyShards, 0)),
            },
        }

        for _, rowDef in ipairs(autoRows) do
            local row = CreateFrame("Frame", nil, sec1, "BackdropTemplate")
            row:SetHeight(34)
            row:SetPoint("TOPLEFT", sec1, "TOPLEFT", 12, sy)
            row:SetPoint("TOPRIGHT", sec1, "TOPRIGHT", -12, sy)
            ApplyBackdrop(row, surf.card, { 1, 1, 1, 0.06 })

            -- Non-interactive 3px status bar (distinguishes read-only live stats from clickable Custom Tasks below)
            local bar = CreateSolidTex(row, "OVERLAY", 2,
                rowDef.done and 0.063 or 0.28,
                rowDef.done and 0.725 or 0.34,
                rowDef.done and 0.506 or 0.44,
                0.95)
            bar:SetSize(3, 20)
            bar:SetPoint("LEFT", row, "LEFT", 10, 0)

            local pFs = row:CreateFontString(nil, "OVERLAY")
            SetFontSafe(pFs, 10, "")
            pFs:SetPoint("RIGHT", row, "RIGHT", -12, 0)
            pFs:SetWordWrap(false)
            pFs:SetTextColor(0.75, 0.82, 0.90, 1.0)
            pFs:SetText(rowDef.pill)

            local tFs = row:CreateFontString(nil, "OVERLAY")
            SetFontSafe(tFs, 11, "")
            tFs:SetPoint("LEFT", bar, "RIGHT", 10, 0)
            tFs:SetPoint("RIGHT", pFs, "LEFT", -10, 0)
            tFs:SetJustifyH("LEFT")
            tFs:SetWordWrap(false)
            tFs:SetTextColor(rowDef.done and 0.78 or 0.96, rowDef.done and 0.86 or 0.98, rowDef.done and 0.92 or 1.0, 1.0)
            tFs:SetText(rowDef.title)

            sy = sy - 40
        end

        local sec1H = math.abs(sy) + 8
        sec1:SetHeight(sec1H)
        y = y - (sec1H + 10)

        -- Custom Weekly Tasks Section
        local sec2 = CreateSectionBox(scrollContent, y)
        local sy2 = -10
        local _, dy2h = CreateSectionHeader(sec2, sy2, "CUSTOM WEEKLY CHECKLIST", "Add personal character or account-wide weekly chores (automatically resets every weekly maintenance).")
        sy2 = sy2 + dy2h

        local addBar = CreateFrame("Frame", nil, sec2, "BackdropTemplate")
        addBar:SetHeight(34)
        addBar:SetPoint("TOPLEFT", sec2, "TOPLEFT", 12, sy2)
        addBar:SetPoint("TOPRIGHT", sec2, "TOPRIGHT", -12, sy2)
        ApplyBackdrop(addBar, { 0.043, 0.051, 0.071, 0.98 }, { 1, 1, 1, 0.08 })

        local newScope = "CHAR"
        local scopeBtn = CreateStyledButton(addBar, "Scope: Char", 86, 22, false, function(s)
            newScope = (newScope == "CHAR") and "ACCT" or "CHAR"
            s.label:SetText(newScope == "CHAR" and "Scope: Char" or "Scope: Acct")
        end)
        scopeBtn:SetPoint("RIGHT", addBar, "RIGHT", -94, 0)

        local eb = CreateFrame("EditBox", nil, addBar)
        eb:SetPoint("LEFT", addBar, "LEFT", 10, 0)
        eb:SetPoint("RIGHT", scopeBtn, "LEFT", -8, 0)
        eb:SetHeight(24)
        eb:SetAutoFocus(false)
        SetFontSafe(eb, 10.5, "")
        eb:SetTextColor(0.95, 0.97, 1.0, 1.0)

        local ph = eb:CreateFontString(nil, "OVERLAY")
        SetFontSafe(ph, 10, "")
        ph:SetPoint("LEFT", eb, "LEFT", 2, 0)
        ph:SetTextColor(0.45, 0.52, 0.62, 0.9)
        ph:SetText("Type a weekly task (e.g. Weekly World Boss, Profession Knowledge)...")
        eb:SetScript("OnTextChanged", function(self) ph:SetShown((self:GetText() or "") == "") end)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        local function AddCustomTask()
            local txt = strtrim(eb:GetText() or "")
            if txt == "" then return end
            table.insert(db.customTasks, {
                id         = tostring(time()) .. "_" .. tostring(math.random(100, 999)),
                title      = txt,
                scope      = newScope,
                doneAcct   = false,
                doneChars  = {},
                resetEpoch = GetCurrentResetEpoch(),
            })
            eb:SetText("")
            RenderVaultEmbedded(parent)
        end

        eb:SetScript("OnEnterPressed", function(self) self:ClearFocus(); AddCustomTask() end)
        local addBtn = CreateStyledButton(addBar, "+ Add Task", 82, 22, true, AddCustomTask)
        addBtn:SetPoint("RIGHT", addBar, "RIGHT", -6, 0)

        sy2 = sy2 - 42

        for idx, task in ipairs(db.customTasks or {}) do
            local isAcct = (task.scope == "ACCT")
            local isDone = isAcct and (task.doneAcct == true) or (pKey and task.doneChars and task.doneChars[pKey] == true) or false

            local row = CreateFrame("Frame", nil, sec2, "BackdropTemplate")
            row:SetHeight(34)
            row:SetPoint("TOPLEFT", sec2, "TOPLEFT", 12, sy2)
            row:SetPoint("TOPRIGHT", sec2, "TOPRIGHT", -12, sy2)
            ApplyBackdrop(row, surf.card, { 1, 1, 1, 0.06 })

            local chk = CreateFrame("Button", nil, row, "BackdropTemplate")
            chk:SetSize(16, 16)
            chk:SetPoint("LEFT", row, "LEFT", 12, 0)
            ApplyBackdrop(chk, { 0.043, 0.051, 0.071, 0.98 }, isDone and { acc.r, acc.g, acc.b, 0.95 } or surf.border)
            if isDone then
                local dot = CreateSolidTex(chk, "OVERLAY", 2, acc.r, acc.g, acc.b, 1.0)
                dot:SetSize(8, 8)
                dot:SetPoint("CENTER")
            end
            chk:SetScript("OnClick", function()
                if isAcct then
                    task.doneAcct = not task.doneAcct
                elseif pKey then
                    task.doneChars = task.doneChars or {}
                    task.doneChars[pKey] = not task.doneChars[pKey]
                end
                RenderVaultEmbedded(parent)
            end)

            local delBtn = CreateFrame("Button", nil, row)
            delBtn:SetSize(20, 20)
            delBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            local delFs = delBtn:CreateFontString(nil, "OVERLAY")
            SetFontSafe(delFs, 10.5, "")
            delFs:SetPoint("CENTER")
            delFs:SetText("x")
            delFs:SetTextColor(0.55, 0.62, 0.72, 0.9)
            delBtn:SetScript("OnEnter", function() delFs:SetTextColor(0.957, 0.247, 0.369, 1) end)
            delBtn:SetScript("OnLeave", function() delFs:SetTextColor(0.55, 0.62, 0.72, 0.9) end)
            delBtn:SetScript("OnClick", function()
                table.remove(db.customTasks, idx)
                RenderVaultEmbedded(parent)
            end)

            local scopeTag = row:CreateFontString(nil, "OVERLAY")
            SetFontSafe(scopeTag, 9.5, "")
            scopeTag:SetPoint("RIGHT", delBtn, "LEFT", -8, 0)
            scopeTag:SetWordWrap(false)
            scopeTag:SetTextColor(isAcct and 0.98 or 0.58, isAcct and 0.75 or 0.65, isAcct and 0.14 or 0.74, 1.0)
            scopeTag:SetText(isAcct and "[ACCOUNT]" or "[CHAR]")

            local tFs = row:CreateFontString(nil, "OVERLAY")
            SetFontSafe(tFs, 11, "")
            tFs:SetPoint("LEFT", chk, "RIGHT", 10, 0)
            tFs:SetPoint("RIGHT", scopeTag, "LEFT", -10, 0)
            tFs:SetJustifyH("LEFT")
            tFs:SetWordWrap(false)
            tFs:SetTextColor(isDone and 0.55 or 0.95, isDone and 0.62 or 0.97, isDone and 0.70 or 1.0, 1.0)
            tFs:SetText(SafeStr(task.title, "Weekly Task"))

            sy2 = sy2 - 40
        end

        local sec2H = math.abs(sy2) + 8
        sec2:SetHeight(sec2H)
        y = y - (sec2H + 10)

    elseif tabId == 3 then
        -- Tab 3: Settings & Maintenance
        local sec1 = CreateSectionBox(scrollContent, y)
        local sy = -10
        local hdr1, dyh = CreateSectionHeader(sec1, sy, "TRACKING & MATRIX DISPLAY", "Configure Great Vault reminders, Alt Vault syncing, and card details.")
        sy = sy + dyh

        local _, dy1 = CreateSegmentedSwitchCard(sec1, sy, "Enable DynamicVault Module",
            "Automatically snapshot Great Vault slots, Crests, Delve Keys, and Keystones across all characters.",
            function() return db.enabled end,
            function(v) db.enabled = v; if DynamicVault.RefreshOverlays then DynamicVault:RefreshOverlays() end end)
        sy = sy + dy1

        local _, dyDock = CreateSegmentedSwitchCard(sec1, sy, "Dock Account Strip on Top of Great Vault",
            "Automatically display your Reset timer, Delve Keys, Crests, and all alts' Vault slots directly on top of Blizzard's Great Vault window (zero extra buttons to click).",
            function() return db.dockOnGreatVault ~= false end,
            function(v) db.dockOnGreatVault = v; if DynamicVault.RefreshOverlays then DynamicVault:RefreshOverlays() end end)
        sy = sy + dyDock

        local _, dyPrepCap = CreateSegmentedSwitchCard(sec1, sy, "Show Great Vault on Top Info Bar",
            "Integrates a compact Great Vault capsule directly into DynamicPrep's Top Info Bar (Left-Click /dv, Right-Click Great Vault, hover for all alts). Zero extra screen boxes.",
            function()
                return _G.DynamicPrepDB and _G.DynamicPrepDB.segments and _G.DynamicPrepDB.segments.vault == true
            end,
            function(v)
                if type(_G.DynamicPrepDB) == "table" then
                    _G.DynamicPrepDB.segments = _G.DynamicPrepDB.segments or {}
                    _G.DynamicPrepDB.segments.vault = (v == true)
                    if _G.DynamicPrep and type(_G.DynamicPrep.RefreshBar) == "function" then
                        pcall(_G.DynamicPrep.RefreshBar, _G.DynamicPrep)
                    end
                end
            end)
        sy = sy + dyPrepCap

        local _, dy2 = CreateSegmentedSwitchCard(sec1, sy, "Great Vault Ready Login Reminder",
            "Print a subtle chat reminder on login when your current character has an unclaimed Great Vault reward.",
            function() return db.loginVaultReminder end,
            function(v) db.loginVaultReminder = v end)
        sy = sy + dy2

        local _, dy3 = CreateSegmentedSwitchCard(sec1, sy, "Sync Alts & Gold from DynamicBags",
            "Automatically include characters already indexed by DynamicBags Alt Vault in your Account Matrix.",
            function() return db.syncDynamicBags end,
            function(v) db.syncDynamicBags = v end)
        sy = sy + dy3

        local _, dy4 = CreateSegmentedSwitchCard(sec1, sy, "Show Keys, Crests & Gold Strip",
            "Display Restored Coffer Keys, Shards, Catalyst charges, seasonal Crests, and Gold on each character card.",
            function() return db.showCurrencies ~= false end,
            function(v) db.showCurrencies = v end)
        sy = sy + dy4

        local _, dy5 = CreateSegmentedSwitchCard(sec1, sy, "Show Owned Keystone on Alt Cards",
            "Display each character's current Mythic+ Keystone level and dungeon name next to their rating.",
            function() return db.showKeystones ~= false end,
            function(v) db.showKeystones = v end)
        sy = sy + dy5

        local _, dy6 = CreateSliderCard(sec1, sy, "Minimum Level Filter Threshold",
            "Characters below this level are hidden when the Level filter is active on Tab 1.",
            1, 90, 1,
            function() return db.minLevelFilter or 80 end,
            function(v) db.minLevelFilter = v end,
            function(v) return string.format("Lv %d+", v) end)
        sy = sy + dy6

        local sec1H = math.abs(sy) + 8
        sec1:SetHeight(sec1H)
        y = y - (sec1H + 10)

        local sec2 = CreateSectionBox(scrollContent, y)
        local sy2 = -10
        local _, dy2h = CreateSectionHeader(sec2, sy2, "MAINTENANCE & DEFAULTS", "Reset DynamicVault settings or clear cached alt snapshots cleanly.")
        sy2 = sy2 + dy2h

        local rstBtn = CreateStyledButton(sec2, "Reset DynamicVault Defaults", 190, 26, false, function()
            DynamicVault:ResetModuleDefaults()
        end)
        rstBtn:SetPoint("TOPLEFT", sec2, "TOPLEFT", 14, sy2)

        local clrBtn = CreateStyledButton(sec2, "Clear Other Alts", 130, 26, false, function()
            local pKey = GetPlayerKey()
            local keep = pKey and db.characters[pKey] or nil
            db.characters = {}
            if pKey and keep then db.characters[pKey] = keep end
            Print("Cleared cached alt snapshots (kept current character).")
            RenderVaultEmbedded(parent)
        end)
        clrBtn:SetPoint("LEFT", rstBtn, "RIGHT", 8, 0)

        sy2 = sy2 - 36
        local sec2H = math.abs(sy2) + 8
        sec2:SetHeight(sec2H)
        y = y - (sec2H + 10)
    end

    scrollContent:SetHeight(math.max(120, math.abs(y) + 12))
    C_Timer.After(0, function()
        local w = scrollFrame:GetWidth()
        if w and w > 40 then scrollContent:SetWidth(w) end
        UpdateScrollBar()
    end)
    return root
end

RefreshEmbeddedUI = function()
    if activeEmbeddedRoot and activeEmbeddedRoot:IsShown() and activeEmbeddedRoot:GetParent() then
        RenderVaultEmbedded(activeEmbeddedRoot:GetParent())
    end
    if DynamicVault.RefreshOverlays then
        DynamicVault:RefreshOverlays()
    end
end

function DynamicVault:ResetModuleDefaults()
    local db = EnsureDB()
    local keepChars = db.characters
    local keepTasks = db.customTasks
    local keepFavs  = db.favourites
    wipe(db)
    CopyDefaults(db, DEFAULTS)
    db.characters  = keepChars or {}
    db.customTasks = keepTasks or {}
    db.favourites  = keepFavs or {}
    Print("Module settings restored to defaults.")
    RefreshEmbeddedUI()
end

-- ============================================================================
-- 7. GREAT VAULT TOP DOCK & OPTIONAL ON-SCREEN OVERLAY (ZERO MINIMAP BUTTONS)
-- ============================================================================
local vaultDockFrame = nil
local vaultDockHooked = false
local screenOverlayFrame = nil

local function ShowCharacterVaultTooltip(owner, ch)
    if not owner or not ch or not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
    local hex = GetClassHex(ch.classFile)
    GameTooltip:AddLine(string.format("|cFF%s%s|r |cFF64748B-%s|r", hex, SafeStr(ch.name, "?"), SafeStr(ch.realm, "")), 1, 1, 1)
    if SafeNum(ch.ilvl, 0) > 0 or SafeNum(ch.rating, 0) > 0 then
        GameTooltip:AddLine(string.format("iLvl %d   |   M+ Rating %d", SafeNum(ch.ilvl, 0), SafeNum(ch.rating, 0)), 0.80, 0.86, 0.94)
    end
    local v = ch.vault or {}
    if v.hasAvailableReward then
        GameTooltip:AddLine("GREAT VAULT REWARD READY TO CLAIM!", 0.98, 0.75, 0.14)
    end
    GameTooltip:AddLine(" ")
    local function AddTrackLine(lbl, tr)
        local u = SafeNum(tr and tr.unlocked, 0)
        local mp = SafeNum(tr and tr.maxProgress, 0)
        local mt = SafeNum(tr and tr.maxThreshold, 0)
        local ilvls = {}
        local nextNeed = nil
        for _, sl in ipairs((tr and tr.slots) or {}) do
            if sl.unlocked and SafeNum(sl.ilvl, 0) > 0 then
                table.insert(ilvls, tostring(sl.ilvl))
            elseif not sl.unlocked and not nextNeed and SafeNum(sl.threshold, 0) > mp then
                nextNeed = SafeNum(sl.threshold, 0) - mp
            end
        end
        local extra = (#ilvls > 0) and ("  [" .. table.concat(ilvls, "/") .. "]") or ""
        if nextNeed and nextNeed > 0 then
            extra = extra .. string.format("  (+%d next)", nextNeed)
        end
        local right = string.format("%d/3 (%d/%d)%s", u, mp, mt, extra)
        GameTooltip:AddDoubleLine(lbl, right, 0.65, 0.72, 0.82, u > 0 and 0.35 or 0.55, u > 0 and 0.92 or 0.62, u > 0 and 0.68 or 0.70)
    end
    AddTrackLine("Raid", v.raid)
    AddTrackLine("Mythic+", v.mplus)
    AddTrackLine("World / Delves", v.world)

    if type(ch.raidLockouts) == "table" and #ch.raidLockouts > 0 then
        GameTooltip:AddLine(" ")
        for _, lo in ipairs(ch.raidLockouts) do
            GameTooltip:AddDoubleLine(SafeStr(lo.name, "Raid"), string.format("|cFF%s%d/%d %s|r", lo.hex or "38BDF8", SafeNum(lo.killed, 0), SafeNum(lo.total, 0), SafeStr(lo.diff, "R")), 0.65, 0.72, 0.82, 1, 1, 1)
        end
    end

    local cur = ch.currencies or {}
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Delve Keys / Shards", string.format("%d / %d", SafeNum(cur.cofferKeys, 0), SafeNum(cur.keyShards, 0)), 0.65, 0.72, 0.82, 0.98, 0.80, 0.25)
    if SafeNum(cur.catalyst, 0) > 0 or SafeNum(cur.catalystMax, 0) > 0 then
        GameTooltip:AddDoubleLine("Catalyst Charges", tostring(SafeNum(cur.catalyst, 0)), 0.65, 0.72, 0.82, 0.22, 0.74, 0.97)
    end
    for _, cr in ipairs(cur.crests or {}) do
        local capTxt = (SafeNum(cr.maxQty, 0) > 0) and string.format(" / %d", SafeNum(cr.maxQty, 0)) or ""
        GameTooltip:AddDoubleLine(SafeStr(cr.name, cr.short or "Crest"), tostring(SafeNum(cr.qty, 0)) .. capTxt, 0.65, 0.72, 0.82, 0.92, 0.95, 1.0)
    end
    if type(ch.keystone) == "table" and SafeNum(ch.keystone.level, 0) > 0 then
        GameTooltip:AddDoubleLine("Keystone", string.format("+%d %s", ch.keystone.level, SafeStr(ch.keystone.name, "")), 0.65, 0.72, 0.82, 0.75, 0.52, 0.98)
    end
    if SafeNum(ch.gold, 0) > 0 then
        GameTooltip:AddDoubleLine("Gold", FormatGoldCompact(ch.gold), 0.65, 0.72, 0.82, 0.99, 0.83, 0.30)
    end
    local dbRef = EnsureDB()
    if type(dbRef.bountifulDelves) == "table" and #dbRef.bountifulDelves > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Today's Bountiful Delves:", 0.98, 0.75, 0.14)
        for i = 1, math.min(#dbRef.bountifulDelves, 5) do
            local d = dbRef.bountifulDelves[i]
            GameTooltip:AddDoubleLine("  " .. SafeStr(d.name, "Delve"), SafeStr(d.zone, ""), 0.88, 0.92, 0.98, 0.58, 0.65, 0.74)
        end
    end
    GameTooltip:Show()
end

local function RefreshGreatVaultDock()
    local db = EnsureDB()
    local wf = _G.WeeklyRewardsFrame
    if IsModuleDisabledInSuite("DynamicVault") or not db.enabled or db.dockOnGreatVault == false
        or not (wf and wf.IsShown and wf:IsShown()) then
        if vaultDockFrame then vaultDockFrame:Hide() end
        return
    end

    local surf, acc = GetOverlayTheme()
    if not vaultDockFrame then
        local bar = CreateFrame("Frame", "DynamicVaultBlizzDock", wf, "BackdropTemplate")
        bar:SetHeight(58)
        bar:SetFrameStrata("HIGH")
        bar:SetFrameLevel((wf:GetFrameLevel() or 1) + 5)
        bar:EnableMouse(true)

        bar.topAcc = CreateSolidTex(bar, "OVERLAY", 2, acc.r, acc.g, acc.b, 1.0)
        bar.topAcc:SetHeight(2)
        bar.topAcc:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
        bar.topAcc:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -1, -1)

        bar.headText = bar:CreateFontString(nil, "OVERLAY")
        SetFontSafe(bar.headText, 11, "")
        bar.headText:SetPoint("TOPLEFT", bar, "TOPLEFT", 10, -7)
        bar.headText:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -124, -7)
        bar.headText:SetJustifyH("LEFT")
        bar.headText:SetWordWrap(false)

        bar.openMatrixBtn = CreateStyledButton(bar, "Full Matrix (/dv)", 108, 20, false, function()
            DynamicVault:Open()
        end)
        bar.openMatrixBtn:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -8, -5)

        bar.chips = {}
        vaultDockFrame = bar
    end

    local bar = vaultDockFrame
    bar:SetParent(wf)
    bar:SetFrameLevel((wf:GetFrameLevel() or 1) + 5)
    ApplyBackdrop(bar, surf.bg, { acc.r, acc.g, acc.b, 0.72 })
    bar.topAcc:SetColorTexture(acc.r, acc.g, acc.b, 1.0)

    -- WeeklyRewardsFrame's outer bounds extend 10px past its visible panel on left/right and 8px on top/bottom
    -- (and external skins like EllesmereUI reparent BorderContainer to a hidden frame).
    -- Anchoring directly to wf with a 10px horizontal inset and -2px/+2px vertical offset aligns flush with the
    -- visible Vault panel edge with a clean 6px gap on both stock Blizzard and skinned Vault frames.
    local sorted = GetSortedCharacters(db)
    local showAltRow = (#sorted >= 2)
    bar:SetHeight(showAltRow and 62 or 34)

    bar:ClearAllPoints()
    local uiTop = (UIParent and UIParent.GetTop and UIParent:GetTop()) or 1080
    local wfTop = (wf.GetTop and wf:GetTop()) or 600
    if (uiTop - wfTop) < 60 then
        bar:SetPoint("TOPLEFT", wf, "BOTTOMLEFT", 10, 2)
        bar:SetPoint("TOPRIGHT", wf, "BOTTOMRIGHT", -10, 2)
    else
        bar:SetPoint("BOTTOMLEFT", wf, "TOPLEFT", 10, -2)
        bar:SetPoint("BOTTOMRIGHT", wf, "TOPRIGHT", -10, -2)
    end

    bar.headText:ClearAllPoints()
    if showAltRow then
        bar.headText:SetPoint("TOPLEFT", bar, "TOPLEFT", 12, -8)
        bar.headText:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -124, -8)
        bar.openMatrixBtn:ClearAllPoints()
        bar.openMatrixBtn:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -8, -6)
    else
        bar.headText:SetPoint("LEFT", bar, "LEFT", 12, 0)
        bar.headText:SetPoint("RIGHT", bar, "RIGHT", -124, 0)
        bar.openMatrixBtn:ClearAllPoints()
        bar.openMatrixBtn:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
    end

    local secsLeft = (C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset) and SafeNum(C_DateAndTime.GetSecondsUntilWeeklyReset(), 0) or 0
    local pKey = GetPlayerKey()
    local curCh = pKey and db.characters[pKey]
    local cur = (curCh and curCh.currencies) or {}
    local sep = "  |cFF475569|||r  "
    local parts = {
        string.format("|cFFCBD5E1Dynamic|r|cFFFFFFFFVault|r%s|cFF94A3B8Reset:|r |cFF38BDF8%s|r", sep, FormatTimeRemaining(secsLeft)),
        string.format("|cFFFBBF24Keys:|r %d (%d Shards)", SafeNum(cur.cofferKeys, 0), SafeNum(cur.keyShards, 0)),
    }
    if SafeNum(cur.catalyst, 0) > 0 then
        table.insert(parts, string.format("|cFF38BDF8Catalyst:|r %d", SafeNum(cur.catalyst, 0)))
    end
    for _, cr in ipairs(cur.crests or {}) do
        table.insert(parts, string.format("|cFF%s%s:|r %d", cr.hex or "94A3B8", cr.short or "Crest", SafeNum(cr.qty, 0)))
    end
    bar.headText:SetText(table.concat(parts, sep))

    -- Render Row 2 alt vault chips ONLY when 2+ characters are tracked (prevents bare empty space on single-char profiles)
    for _, chip in ipairs(bar.chips) do chip:Hide() end
    if bar.altLabel then bar.altLabel:SetShown(showAltRow) end
    if showAltRow then
        if not bar.altLabel then
            bar.altLabel = bar:CreateFontString(nil, "OVERLAY")
            SetFontSafe(bar.altLabel, 9.5, "")
            bar.altLabel:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 12, 11)
            bar.altLabel:SetTextColor(0.55, 0.62, 0.72, 1)
            bar.altLabel:SetText("Alts:")
        end
        bar.altLabel:Show()
        local dockW = (bar.GetWidth and SafeNum(bar:GetWidth(), 0)) or 0
        if dockW < 400 then
            local rawW = (wf and wf.GetWidth and SafeNum(wf:GetWidth(), 860)) or 860
            dockW = rawW - 20
        end
        local barW = math.max(400, dockW)
        local maxChips = math.max(1, math.min(8, math.floor((barW - 52) / 146)))
        local xPos = 44
        for i = 1, math.min(#sorted, maxChips) do
            local ch = sorted[i]
            local chip = bar.chips[i]
            if not chip then
                chip = CreateFrame("Button", nil, bar, "BackdropTemplate")
                chip:SetSize(140, 24)
                chip.fs = chip:CreateFontString(nil, "OVERLAY")
                SetFontSafe(chip.fs, 9.5, "")
                chip.fs:SetPoint("LEFT", chip, "LEFT", 7, 0)
                chip.fs:SetPoint("RIGHT", chip, "RIGHT", -7, 0)
                chip.fs:SetJustifyH("LEFT")
                chip.fs:SetWordWrap(false)
                bar.chips[i] = chip
            end
            chip:ClearAllPoints()
            chip:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", xPos, 6)
            xPos = xPos + 146

            local v = ch.vault or {}
            local rU = SafeNum(v.raid and v.raid.unlocked, 0)
            local mU = SafeNum(v.mplus and v.mplus.unlocked, 0)
            local dU = SafeNum(v.world and v.world.unlocked, 0)
            local hasRew = (v.hasAvailableReward == true)
            local hex = GetClassHex(ch.classFile)
            local shortName = SafeStr(ch.name, "?")
            if #shortName > 9 then shortName = shortName:sub(1, 8) .. "." end
            chip.fs:SetText(string.format("|cFF%s%s|r %s",
                hex, shortName,
                hasRew and "|cFFFBBF24REWARD!|r" or string.format("|cFF94A3B8R%d M%d D%d|r", rU, mU, dU)))
            if hasRew then
                ApplyBackdrop(chip, { 0.96, 0.62, 0.04, 0.18 }, { 0.96, 0.62, 0.04, 0.90 })
            elseif ch.key == pKey then
                ApplyBackdrop(chip, { acc.r * 0.22, acc.g * 0.22, acc.b * 0.22, 0.92 }, { acc.r, acc.g, acc.b, 0.85 })
            else
                ApplyBackdrop(chip, surf.card, surf.border)
            end
            chip:SetScript("OnEnter", function(s) ShowCharacterVaultTooltip(s, ch) end)
            chip:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            chip:SetScript("OnClick", function() DynamicVault:Open() end)
            chip:Show()
        end
    end

    bar:Show()
end

local function HookWeeklyRewardsFrame()
    if vaultDockHooked then return end
    local wf = _G.WeeklyRewardsFrame
    if not wf or type(wf.HookScript) ~= "function" then return end
    vaultDockHooked = true
    wf:HookScript("OnShow", function()
        DynamicVault:SnapshotCurrentCharacter(true)
        RefreshGreatVaultDock()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, RefreshGreatVaultDock)
        end
    end)
    wf:HookScript("OnHide", function()
        if vaultDockFrame then vaultDockFrame:Hide() end
    end)
end

local function RefreshScreenOverlay(forceCreate)
    if screenOverlayFrame then
        screenOverlayFrame:Hide()
    end
    return nil
end

function DynamicVault:GetOverlayFrame(forceCreate)
    if not screenOverlayFrame and forceCreate then
        RefreshScreenOverlay(true)
    end
    return screenOverlayFrame
end

function DynamicVault:SaveOverlayPosition(pt, relPt, x, y)
    local db = EnsureDB()
    db.overlayPos = { pt or "TOP", relPt or pt or "TOP", math.floor((x or 0) + 0.5), math.floor((y or -42) + 0.5) }
end

function DynamicVault:ResetOverlayPosition()
    local db = EnsureDB()
    db.overlayPos = { "TOP", "TOP", 0, -42 }
    db.overlayScale = 1.0
    db.overlayOpacity = 0.96
    db.overlayBorderStyle = "ACCENT"
    RefreshScreenOverlay(false)
end

function DynamicVault:GetPrepBarCapsuleData()
    local db = EnsureDB()
    local pKey = GetPlayerKey()
    local ch = pKey and db.characters and db.characters[pKey]
    local v = (ch and ch.vault) or {}
    local total = SafeNum(v.raid and v.raid.unlocked, 0) + SafeNum(v.mplus and v.mplus.unlocked, 0) + SafeNum(v.world and v.world.unlocked, 0)
    if v.hasAvailableReward then
        return "|cFFFBBF24Vault: REWARD!|r", true
    end
    local col = (total > 0) and "34D399" or "94A3B8"
    return string.format("Vault |cFF%s%d/9|r", col, total), false
end

function DynamicVault:PopulatePrepBarTooltip(tooltip)
    if not tooltip then return end
    local db = EnsureDB()
    local pKey = GetPlayerKey()
    local ch = pKey and db.characters and db.characters[pKey]
    local v = (ch and ch.vault) or {}
    local cur = (ch and ch.currencies) or {}
    local secsLeft = (C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset) and SafeNum(C_DateAndTime.GetSecondsUntilWeeklyReset(), 0) or 0

    tooltip:AddLine("|cFFCBD5E1Dynamic|r|cFFFFFFFFVault|r  Great Vault Summary", 1, 1, 1)
    if v.hasAvailableReward then
        tooltip:AddLine("|cFFFBBF24Unclaimed Great Vault Reward Ready!|r", 0.98, 0.75, 0.14)
    end
    tooltip:AddDoubleLine("Raid / M+ / Delves:", string.format("R %d/3  |  M+ %d/3  |  D %d/3",
        SafeNum(v.raid and v.raid.unlocked, 0),
        SafeNum(v.mplus and v.mplus.unlocked, 0),
        SafeNum(v.world and v.world.unlocked, 0)), 0.72, 0.78, 0.86, 1, 1, 1)
    tooltip:AddDoubleLine("Coffer Keys / Reset:", string.format("|cFFFBBF24%d Keys|r  |  |cFF38BDF8%s|r",
        SafeNum(cur.cofferKeys, 0), FormatTimeRemaining(secsLeft)), 0.72, 0.78, 0.86, 1, 1, 1)

    local sorted = GetSortedCharacters(db)
    if #sorted > 1 then
        tooltip:AddLine(" ")
        tooltip:AddLine("Account Characters:", 0.64, 0.72, 0.82)
        for i = 1, math.min(#sorted, 8) do
            local alt = sorted[i]
            local av = alt.vault or {}
            local hex = GetClassHex(alt.classFile)
            local right = (av.hasAvailableReward == true)
                and "|cFFFBBF24REWARD READY|r"
                or string.format("R %d/3  M+ %d/3  D %d/3", SafeNum(av.raid and av.raid.unlocked, 0), SafeNum(av.mplus and av.mplus.unlocked, 0), SafeNum(av.world and av.world.unlocked, 0))
            tooltip:AddDoubleLine(string.format("|cFF%s%s|r", hex, SafeStr(alt.name, "?")), right, 1, 1, 1, 0.78, 0.85, 0.94)
        end
    end
    tooltip:AddLine(" ")
    tooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Open DynamicVault Account Matrix (/dv)|r", 1, 1, 1)
    tooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Open Blizzard Great Vault|r", 1, 1, 1)
end

function DynamicVault:RefreshOverlays()
    HookWeeklyRewardsFrame()
    RefreshGreatVaultDock()
    RefreshScreenOverlay()
    if _G.DynamicPrep and type(_G.DynamicPrep.RefreshBar) == "function" then
        pcall(_G.DynamicPrep.RefreshBar, _G.DynamicPrep)
    end
end

-- ============================================================================
-- 8. STANDALONE SHELL & SUITE REGISTRATION
-- ============================================================================
local standaloneWin = nil

function DynamicVault:Open()
    if _G.DynamicSuite and type(_G.DynamicSuite.OpenModule) == "function" and not IsModuleDisabledInSuite("DynamicVault") then
        _G.DynamicSuite:OpenModule("vault")
        return
    end
    if not standaloneWin then
        local surf, acc = GetTheme()
        local f = CreateFrame("Frame", "DynamicVaultStandaloneFrame", UIParent, "BackdropTemplate")
        f:SetSize(780, 560)
        f:SetPoint("CENTER")
        f:SetMovable(true)
        f:SetResizable(true)
        if f.SetResizeBounds then f:SetResizeBounds(740, 480, 1280, 860) end
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameStrata("HIGH")
        ApplyBackdrop(f, surf.bg, { acc.r, acc.g, acc.b, 0.90 })
        if type(_G.UISpecialFrames) == "table" then
            local seen = false
            for _, n in ipairs(_G.UISpecialFrames) do
                if n == "DynamicVaultStandaloneFrame" then seen = true; break end
            end
            if not seen then table.insert(_G.UISpecialFrames, "DynamicVaultStandaloneFrame") end
        end

        local hdr = CreateFrame("Frame", nil, f, "BackdropTemplate")
        hdr:SetHeight(40)
        hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        hdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
        ApplyBackdrop(hdr, surf.header, surf.border)

        local topLine = CreateSolidTex(hdr, "OVERLAY", 4, acc.r, acc.g, acc.b, 1.0)
        topLine:SetHeight(2)
        topLine:SetPoint("TOPLEFT", hdr, "TOPLEFT", 0, 0)
        topLine:SetPoint("TOPRIGHT", hdr, "TOPRIGHT", 0, 0)
        f.topLine = topLine

        local closeBtn = CreateStyledButton(hdr, "X", 26, 24, false, function() f:Hide() end)
        closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -10, 0)

        local title = hdr:CreateFontString(nil, "OVERLAY")
        SetFontSafe(title, 13, "")
        title:SetPoint("LEFT", hdr, "LEFT", 14, 0)
        title:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
        title:SetJustifyH("LEFT")
        title:SetWordWrap(false)
        title:SetText(string.format("|cFFCBD5E1Dynamic|r|cFFFFFFFFVault|r |cFF64748Bv%s|r", VERSION))

        local footer = CreateFrame("Frame", nil, f, "BackdropTemplate")
        footer:SetHeight(36)
        footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
        footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
        ApplyBackdrop(footer, surf.header, surf.border)

        local resetBtn = CreateStyledButton(footer, "Reset DynamicVault", 148, 24, false, function()
            DynamicVault:ResetModuleDefaults()
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
        grip:SetScript("OnEnter", function()
            local _, a = GetTheme()
            gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
            gripTex:SetDesaturated(false)
            gripTex:SetVertexColor(a.r, a.g, a.b, 0.95)
        end)
        grip:SetScript("OnLeave", function()
            gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
            gripTex:SetDesaturated(true)
            gripTex:SetVertexColor(0.55, 0.58, 0.65, 0.75)
        end)
        grip:SetScript("OnMouseDown", function(_, btn)
            if btn == "LeftButton" then
                f:StartSizing("BOTTOMRIGHT")
            elseif btn == "RightButton" then
                f:SetSize(780, 560)
            end
        end)
        grip:SetScript("OnMouseUp", function()
            f:StopMovingOrSizing()
        end)

        local body = CreateFrame("Frame", nil, f)
        body:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, 0)
        body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
        f.body = body
        standaloneWin = f
    end
    DynamicVault:SnapshotCurrentCharacter(true)
    RenderVaultEmbedded(standaloneWin.body)
    standaloneWin:Show()
end

function DynamicVault:ApplyTheme()
    local surf, acc = GetTheme()
    if standaloneWin then
        ApplyBackdrop(standaloneWin, surf.bg, { acc.r, acc.g, acc.b, 0.90 })
        if standaloneWin.topLine then
            standaloneWin.topLine:SetColorTexture(acc.r, acc.g, acc.b, 1.0)
        end
    end
    if type(RefreshScreenOverlay) == "function" then
        pcall(RefreshScreenOverlay)
    end
    if type(RefreshGreatVaultDock) == "function" then
        pcall(RefreshGreatVaultDock)
    end
    if activeEmbeddedRoot and activeEmbeddedRoot:IsShown() and activeEmbeddedRoot:GetParent() then
        pcall(RenderVaultEmbedded, activeEmbeddedRoot:GetParent())
    end
end

DynamicVault.RenderEmbedded      = function(self, parent) return RenderVaultEmbedded(parent or self) end
DynamicVault.ApplyThemeToUI      = function() return DynamicVault:ApplyTheme() end
DynamicVault.RefreshTheme        = function() return DynamicVault:ApplyTheme() end
DynamicVault.ResetDefaults       = function() return DynamicVault:ResetModuleDefaults() end
DynamicVault.ResetModule         = function() return DynamicVault:ResetModuleDefaults() end
DynamicVault.Reset               = function() return DynamicVault:ResetModuleDefaults() end

DynamicVault.CHANGELOG = {
    {
        version = VERSION,
        date = "25/11/2026",
        entries = {
            { type = "UI", text = "Pass 6 Standalone Parity, 3-Way Scrollbar & 800x520 Clamping (25/11/2026): Made DynamicVaultStandaloneFrame resizable (740x480 to 1280x860) with a 40px header, 36px Reset/Reload footer, 14x14 live-accent resize grip, and ApplyTheme border repaint; upgraded the workspace scrollbar to full 3-way interaction (mousewheel, track click-to-jump, and draggable thumb with live accent highlight); right-clamped Tab 1 banner titles, filter hint, character names, proportional Raid/Myth+/Delves tracks, and Tab 2 checklist rows for clean 800x520 layout; tightened Tab 3 switch titles; and fixed the empty-state prompt ('Click Refresh to snapshot your current character.')." },
            { type = "UI", text = "Release v2.7.0 (21/11/2026): Standardised settings toggle switches (68px Off / 84px Enabled inside 156x26px) and 256x26px Precision Track sliders (6x14px thumb, 52px readout, mousewheel & hover highlight), and anchored card titles/descriptions relative to right-hand controls with 2-line wrapping so nothing clips at 800x520." },
            { type = "FIX", text = "Release v2.6.9 (21/11/2026): Fixed a Great Vault top dock width calculation error when 2 or more alts are tracked, enabled Escape key closing on the standalone /dv window, cleaned up legacy /dv overlay hints to point to DynamicPrep's Top Info Bar, and registered DynamicVault's changelog with DynamicSuite." },
            { type = "NEW", text = "Initial v2.5.0 Release (19/11/2026): Added DynamicVault (/dv, /dynamicvault) with Account-Wide Great Vault Matrix (Raid, Mythic+, and World/Delves 3-slot progress and target iLvl), live Restored Coffer Keys / Shards / Catalyst / Seasonal Crests tracking, Weekly Reset countdown and automatic rollover, Owned Keystone details, Auto-Tracked & Custom Weekly Checklists, 1-click Open Great Vault anywhere (/dv open), and full DynamicSuite + DynamicBags Alt Vault integration." },
        },
    },
}

local function RegisterWithDynamicSuite()
    _G.DynamicSuite = _G.DynamicSuite or {}
    _G.DynamicSuite.modules = _G.DynamicSuite.modules or {}
    _G.DynamicSuite.Changelogs = _G.DynamicSuite.Changelogs or {}
    _G.DynamicSuite.Changelogs["DynamicVault"] = DynamicVault.CHANGELOG
    _G.DynamicSuite.Changelogs["vault"] = DynamicVault.CHANGELOG

    local registration = {
        id = "vault",
        key = "DynamicVault",
        name = "DynamicVault",
        title = "DynamicVault",
        subtitle = "Great Vault, Crests & Weeklies",
        version = VERSION,
        order = 80,
        icon = ICON_COLOR,
        fallbackIcon = ICON_COLOR,
        iconWhite = ICON_WHITE,
        iconAccent = ICON_ACCENT,
        slash = "/dv",
        category = "Great Vault, Currencies & Weekly Tracker",
        desc = "Account-wide Great Vault matrix (Raid, M+, Delves), Restored Coffer Keys, Catalyst, Crests, owned Keystones, and auto-resetting Weekly Checklists.",
        conflictRegistry = {
            conflicts        = {},
            hardConflicts    = {},
            partialConflicts = { "SavedInstances", "Altoholic", "ChoreTracker", "WeeklyKnowledge", "PermoksAccountManager" },
            softConflicts    = { "SavedInstances", "Altoholic", "ChoreTracker", "WeeklyKnowledge", "PermoksAccountManager" },
            category         = "Account Vault & Weekly Tracking",
        },
        GetStatusText = function() return DynamicVault:GetStatusText() end,
        RenderEmbedded = function(a, b)
            local parent = (type(a) == "table" and a.CreateFrame == nil and b) and b or a
            DynamicVault:SnapshotCurrentCharacter(true)
            return RenderVaultEmbedded(parent)
        end,
        RenderUI = function(a, b)
            local parent = (type(a) == "table" and a.CreateFrame == nil and b) and b or a
            DynamicVault:SnapshotCurrentCharacter(true)
            return RenderVaultEmbedded(parent)
        end,
        ApplyTheme          = function() DynamicVault:ApplyTheme() end,
        ApplyThemeToUI      = function() DynamicVault:ApplyTheme() end,
        RefreshTheme        = function() DynamicVault:ApplyTheme() end,
        ResetDefaults       = function() DynamicVault:ResetModuleDefaults() end,
        ResetModuleDefaults = function() DynamicVault:ResetModuleDefaults() end,
        ResetModule         = function() DynamicVault:ResetModuleDefaults() end,
        Reset               = function() DynamicVault:ResetModuleDefaults() end,
        changelog           = DynamicVault.CHANGELOG,
    }

    _G.DynamicSuite.modules["vault"]        = registration
    _G.DynamicSuite.modules["DynamicVault"] = registration
    if type(_G.DynamicSuite.RegisterModule) == "function" then
        pcall(_G.DynamicSuite.RegisterModule, _G.DynamicSuite, registration)
    end
end

-- ============================================================================
-- 8. EVENTS & SLASH COMMANDS
-- ============================================================================
local evt = CreateFrame("Frame")
evt:RegisterEvent("ADDON_LOADED")
evt:RegisterEvent("PLAYER_LOGIN")
evt:RegisterEvent("PLAYER_ENTERING_WORLD")
evt:RegisterEvent("WEEKLY_REWARDS_UPDATE")
evt:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
evt:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
evt:RegisterEvent("BAG_UPDATE_DELAYED")

local snapshotQueued = false
local function QueueSnapshot()
    if snapshotQueued then return end
    snapshotQueued = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.6, function()
            snapshotQueued = false
            DynamicVault:SnapshotCurrentCharacter(false)
        end)
    else
        snapshotQueued = false
        DynamicVault:SnapshotCurrentCharacter(false)
    end
end

local loginReminded = false
evt:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_FOLDER or arg1 == "DynamicSuite" or arg1 == "DynamicVault" then
            EnsureDB()
            RegisterWithDynamicSuite()
        elseif arg1 == "Blizzard_WeeklyRewards" then
            HookWeeklyRewardsFrame()
            RefreshGreatVaultDock()
        end
    elseif event == "PLAYER_LOGIN" then
        EnsureDB()
        RegisterWithDynamicSuite()
        HookWeeklyRewardsFrame()
        QueueSnapshot()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if arg1 == true or arg2 == true then
            C_Timer.After(2.0, function()
                DynamicVault:SnapshotCurrentCharacter(true)
                DynamicVault:RefreshOverlays()
                local db = EnsureDB()
                if not loginReminded and db.enabled and db.loginVaultReminder and not IsModuleDisabledInSuite("DynamicVault") then
                    local pKey = GetPlayerKey()
                    local ch = pKey and db.characters[pKey]
                    if ch and ch.vault and ch.vault.hasAvailableReward then
                        loginReminded = true
                        Print("Your |cFFFBBF24Great Vault reward is ready to claim!|r Type |cFF38BDF8/dv open|r to preview it.")
                    end
                end
            end)
        end
    elseif event == "WEEKLY_REWARDS_UPDATE" or event == "CURRENCY_DISPLAY_UPDATE" or event == "CHALLENGE_MODE_MAPS_UPDATE" then
        QueueSnapshot()
    elseif event == "BAG_UPDATE_DELAYED" then
        if activeEmbeddedRoot and activeEmbeddedRoot:IsShown() then
            QueueSnapshot()
        end
    end
end)

_G.DynamicVault_OnAddonCompartmentClick = function()
    DynamicVault:Open()
end

_G.SLASH_DYNAMICVAULT1 = "/dv"
_G.SLASH_DYNAMICVAULT2 = "/dynamicvault"
_G.SlashCmdList["DYNAMICVAULT"] = function(msg)
    local cmd = strtrim((msg or ""):lower())
    if cmd == "open" or cmd == "vault" then
        DynamicVault:OpenBlizzardVault()
    elseif cmd == "overlay" or cmd == "hud" then
        Print("Great Vault status now lives in DynamicPrep's Top Info Bar. Enable 'Great Vault' in DynamicPrep -> Bar Layout & Style, or under DynamicVault -> Settings & Maintenance.")
    elseif cmd == "scan" or cmd == "refresh" then
        DynamicVault:SnapshotCurrentCharacter(false)
        Print("Refreshed current character Great Vault, Currencies, and Keystone snapshot.")
    elseif cmd == "reset" then
        DynamicVault:ResetModuleDefaults()
    else
        DynamicVault:Open()
    end
end
