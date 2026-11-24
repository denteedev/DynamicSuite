--[[
    DynamicBags - Zero-Lag Virtual Category Bags, Remote Bank & Alt Inventory Vault
    DynamicSuite module #7  (/dbag, /dbags)       Retail 12.1.5 / 12.1.7 (Interface 120105, 120107)
    Author: Dentee-Frostmourne

    100% original, clean-room implementation built on native Blizzard APIs only
    (C_Container, C_Item, C_TooltipInfo, C_EquipmentSet, C_NewItems, Enum.*).
    See DESIGN_SYSTEM.md for the architecture this file implements.

    Sections
      1. Constants, helpers & saved variables
      2. O(1) classifier, delta-only dirty-slot cache & equipment-set lookup
      3. Pre-computed virtual layout (no SortBags on open)
      4. Alt & Warband vault snapshots + tooltip counts
      5. Obsidian UI primitives (buttons, menus, scroll area)
      6. Secure item button pool & item visuals
      7. Inventory window
      8. Embedded 3-tab configuration workspace
      9. Auto-open, Blizzard bag replacement, auto-sell
     10. DynamicSuite registration, slash commands & event dispatcher
]]

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
if ShouldYieldToOtherInstall(ADDON_FOLDER, "DynamicBags", VERSION, _G.DynamicBags) then
    return
end
local DB_NS = {}
local isInitialized = false

local function IsModuleDisabledInSuite(modName)
    local key = modName or "DynamicBags"
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

local DynamicBags = _G.DynamicBags or CreateFrame("Frame", "DynamicBagsEventFrame")
DynamicBags.version = VERSION
_G.DynamicBags = DynamicBags
DB_NS.DynamicBags = DynamicBags
DynamicBags._loadedBySuite = (ADDON_FOLDER == "DynamicSuite")
DynamicBags._loadedVersion = VERSION

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local tinsert, tsort = table.insert, table.sort
local sformat = string.format

local WHITE = "Interface\\Buttons\\WHITE8x8"
local SLOT_GAP = 4
local SECTION_HEADER_H = 20

-- ============================================================================
-- 1. CONSTANTS, HELPERS & SAVED VARIABLES
-- ============================================================================

local S = {
    db = nil,
    slotCache = {},     -- [bagID][slot] = entry (nil = empty slot)
    slotCount = {},     -- [bagID] = number of slots
    dirtyBags = {},     -- [bagID] = true (written by BAG_UPDATE, consumed on BAG_UPDATE_DELAYED)
    bagFrames = {},     -- [bagID] = hidden parent frame carrying SetID(bagID)
    buttons = {},       -- ["bag:slot"] = secure item button
    sessionNew = {},    -- ["bag:slot:link"] = true
    setLookup = {},     -- ["bag:slot"] = equipment set name
    bindCache = {},     -- ["bag:slot:link"] = { binding, unusable }
    qualityCache = {},  -- [link or itemID] = { q, maxTiers, atlas } or false
    bagIDs = {},
    equipGen = 0,
    layout = nil,
    layoutVersion = 0,
    appliedVersion = -1,
    pendingReflow = false,
    pendingBuild = false,
    view = { char = nil, mode = "BAGS" },
    vaultVersion = 0,
    search = "",
    sessionStartMoney = nil,
    atBank = false,
    queriedGuildTabs = {},
    autoOpened = {},
    skippedOpenables = {},
    autoOpenAttempted = {},
    autoOpenRetryAfter = {},
    autoOpenFailCount = {},
    autoOpenBlacklist = {},
    quickOpenQueue = {},
    quickOpenCurrent = nil,
    quickOpenBtn = nil,
    quickOpenBatchDecorCount = 0,
    quickOpenBaseMacroText = nil,
    quickOpenPreClickStripped = false,
    pendingQuickOpenSync = false,
    decorUseConfirmCount = 0,
    decorUseConfirmExpiresAt = 0,
    decorUseConfirmSource = nil,
    decorUseConfirmToken = 0,
    decorPendingVerify = nil,
    decorActionBlocked = false,
}

local U = {}
DynamicBags.U = U

local IC = {
    Consumable = (Enum and Enum.ItemClass and Enum.ItemClass.Consumable) or 0,
    Container = (Enum and Enum.ItemClass and Enum.ItemClass.Container) or 1,
    Weapon = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2,
    Gem = (Enum and Enum.ItemClass and Enum.ItemClass.Gem) or 3,
    Armor = (Enum and Enum.ItemClass and Enum.ItemClass.Armor) or 4,
    Reagent = (Enum and Enum.ItemClass and Enum.ItemClass.Reagent) or 5,
    Tradegoods = (Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods) or 7,
    Enhancement = (Enum and Enum.ItemClass and Enum.ItemClass.ItemEnhancement) or 8,
    Recipe = (Enum and Enum.ItemClass and Enum.ItemClass.Recipe) or 9,
    Quest = (Enum and Enum.ItemClass and Enum.ItemClass.Questitem) or 12,
}
local QUALITY_POOR = (Enum and Enum.ItemQuality and Enum.ItemQuality.Poor) or 0

local KEYSTONE_ITEM_ID = 180653
local HEARTH_IDS = {
    [6948] = true, [110560] = true, [140192] = true, [556] = true, [64488] = true,
    [54452] = true, [93672] = true, [162973] = true, [163045] = true, [165669] = true,
    [165670] = true, [165802] = true, [166746] = true, [166747] = true, [168907] = true,
    [172179] = true, [180290] = true, [182773] = true, [184353] = true, [183716] = true,
    [188952] = true, [190196] = true, [190237] = true, [193588] = true, [200630] = true,
    [206195] = true, [208704] = true, [209035] = true, [210455] = true, [212337] = true,
    [228940] = true,
}

-- Display order of virtual category sections (Default / Mythic+ & Raid Order).
local CATS = {
    { key = "new",        label = "New Items" },
    { key = "consumable", label = "M+ & Raid Consumables" },
    { key = "keystone",   label = "Keystone & Hearth" },
    { key = "eqset",      label = "Equipment Sets" },
    { key = "boe",        label = "Bind on Equip" },
    { key = "gear",       label = "Gear & Weapons" },
    { key = "gems",       label = "Gems & Enchants" },
    { key = "wue",        label = "Warbound (WUE)" },
    { key = "quest",      label = "Quest" },
    { key = "craft",      label = "Crafting & Reagents" },
    { key = "misc",       label = "Miscellaneous" },
    { key = "junk",       label = "Junk" },
}
local CAT_LABEL = {}
for _, c in ipairs(CATS) do CAT_LABEL[c.key] = c.label end

-- All 12 categories shown as reorderable buttons in the workspace.
local CATEGORY_TOGGLES = {
    { key = "new",        label = "New Items",       fullLabel = "New Items" },
    { key = "consumable", label = "Consumables",     fullLabel = "M+ & Raid Consumables" },
    { key = "keystone",   label = "Keystones",       fullLabel = "Keystone & Hearth" },
    { key = "eqset",      label = "Equip Sets",      fullLabel = "Equipment Sets" },
    { key = "boe",        label = "Bind on Equip",   fullLabel = "Bind on Equip" },
    { key = "gear",       label = "Gear & Weapons",  fullLabel = "Gear & Weapons" },
    { key = "gems",       label = "Gems & Enchants", fullLabel = "Gems & Enchants" },
    { key = "wue",        label = "Warbound",        fullLabel = "Warbound (WUE)" },
    { key = "quest",      label = "Quest Items",     fullLabel = "Quest Items" },
    { key = "craft",      label = "Reagents",        fullLabel = "Trade & Reagents" },
    { key = "misc",       label = "Miscellaneous",   fullLabel = "Miscellaneous" },
    { key = "junk",       label = "Junk",            fullLabel = "Junk" },
}
local CAT_SHORT_LABEL = {}
local CAT_FULL_LABEL = {}
for _, c in ipairs(CATEGORY_TOGGLES) do
    CAT_SHORT_LABEL[c.key] = c.label
    CAT_FULL_LABEL[c.key] = c.fullLabel or c.label
end

local PRESETS = {
    MYTHIC = {
        label = "Mythic+ & Raid Ready", shortLabel = "Mythic+ & Raid", viewMode = "CATEGORY",
        order = { "new", "consumable", "keystone", "eqset", "boe", "gear", "gems", "wue", "quest", "craft", "misc", "junk" },
        cats = { new = true, consumable = true, keystone = true, eqset = true, boe = true, gear = true, gems = true, wue = true, quest = true, craft = true, misc = true, junk = true },
        splits = { splitEqSets = true, splitConsumables = true, splitGearSlots = true, splitUpgrades = false, splitBindSlots = false, splitGemsEnchants = true, splitReagents = true, splitCollectibles = true },
    },
    COLLECTOR = {
        label = "Collector & Open World", shortLabel = "Collector", viewMode = "CATEGORY",
        order = { "new", "wue", "boe", "quest", "misc", "craft", "eqset", "gear", "gems", "consumable", "keystone", "junk" },
        cats = { new = true, wue = true, boe = true, quest = true, misc = true, craft = true, eqset = true, gear = true, gems = true, consumable = true, keystone = true, junk = true },
        splits = { splitEqSets = true, splitConsumables = false, splitGearSlots = true, splitUpgrades = true, splitBindSlots = true, splitGemsEnchants = false, splitReagents = true, splitCollectibles = true },
    },
    MINIMAL = {
        label = "Minimalist Compact", shortLabel = "Minimalist", viewMode = "CATEGORY",
        order = { "new", "keystone", "consumable", "eqset", "gear", "craft", "quest", "misc", "junk", "boe", "wue", "gems" },
        cats = { new = true, keystone = true, consumable = true, eqset = true, gear = true, craft = true, quest = true, misc = true, junk = true, boe = false, wue = false, gems = false },
        splits = { splitEqSets = false, splitConsumables = false, splitGearSlots = false, splitUpgrades = false, splitBindSlots = false, splitGemsEnchants = false, splitReagents = false, splitCollectibles = false },
    },
    CUSTOM = {
        label = "Custom", shortLabel = "Custom", viewMode = "CATEGORY",
    },
}
local DEFAULTS = {
    replaceBlizzardBags = true,
    viewMode = "CATEGORY",           -- CATEGORY | GRID
    preset = "MYTHIC",               -- MYTHIC | COLLECTOR | MINIMAL | CUSTOM
    autoSort = true,
    sortBy = "QUALITY",              -- QUALITY | NAME
    autoMergeOnClose = false,
    categories = {
        new = true, keystone = true, consumable = true, eqset = true,
        gear = true, wue = true, boe = true, craft = true,
        gems = true, quest = true, misc = true, junk = true,
    },
    bagColumns = 14,
    bankColumns = 14,
    bagScale = 1.0,
    bankScale = 1.0,
    iconSize = 36,
    categorySpacing = 12,
    badges = { ilvl = true, upgrade = true, keystone = true, eqset = true, binding = true, junk = true, quality = true },
    visual = { qualityGlow = true, dimJunk = true, unusableRed = true, flashNew = true },
    fontSize = 11,
    autoOpen = {
        bank = true, auction = true, vendor = true, mail = true, trade = true,
        character = false, upgrade = true, catalyst = true, guildbank = true, crafting = true,
    },
    rememberLastBankTab = true,
    lastBankMode = "BANK",
    lastSubTabs = { BANK = 0, WARBAND = 0, GUILD = 0 },
    autoRepair = true,
    autoRepairEnabled = true,
    repairFunding = "GUILD_FIRST",
    autoSellGrey = true,
    autoSellJunk = true,
    merchantBulkBuy = true,
    autoRestockEnabled = false,
    autoRestockList = {},
    fastAutoLoot = true,
    autoFillDelete = true,
    autoOpenContainers = true,
    autoOpenHousingDecor = true,
    autoOpenKnowledgeItems = true,
    autoUnwrapItems = false,
    quickOpenEnabled = true,
    queueHousingDecor = true,
    queueKnowledgeItems = true,
    openablesSoulboundOnly = true,
    repairDrawerOpen = true,
    yieldHooks = false,
    tooltipCounts = true,
    pinnedCategories = {},
    collapsedSections = {},
    activeSubTab = 1,
    vault = { characters = {} },
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
    if type(_G.DynamicBagsDB) ~= "table" then _G.DynamicBagsDB = {} end
    if _G.DynamicBagsDB._migratedFromPrep ~= true and type(_G.DynamicPrepDB) == "table" then
        local p = _G.DynamicPrepDB
        if p.autoRepairEnabled ~= nil then
            _G.DynamicBagsDB.autoRepairEnabled = (p.autoRepairEnabled and true or false)
            _G.DynamicBagsDB.autoRepair = _G.DynamicBagsDB.autoRepairEnabled
        end
        if p.repairFunding == "GUILD_FIRST" or p.repairFunding == "OWN_ONLY" then
            _G.DynamicBagsDB.repairFunding = p.repairFunding
        end
        if p.autoSellGrey ~= nil then
            _G.DynamicBagsDB.autoSellGrey = (p.autoSellGrey and true or false)
            _G.DynamicBagsDB.autoSellJunk = _G.DynamicBagsDB.autoSellGrey
        end
        if p.fastAutoLoot ~= nil then
            _G.DynamicBagsDB.fastAutoLoot = (p.fastAutoLoot and true or false)
        end
        if p.autoFillDelete ~= nil then
            _G.DynamicBagsDB.autoFillDelete = (p.autoFillDelete and true or false)
        end
        _G.DynamicBagsDB._migratedFromPrep = true
    end
    CopyDefaults(DEFAULTS, _G.DynamicBagsDB)
    if _G.DynamicBagsDB.autoRepair == nil and _G.DynamicBagsDB.autoRepairEnabled ~= nil then
        _G.DynamicBagsDB.autoRepair = (_G.DynamicBagsDB.autoRepairEnabled and true or false)
    elseif _G.DynamicBagsDB.autoRepairEnabled == nil and _G.DynamicBagsDB.autoRepair ~= nil then
        _G.DynamicBagsDB.autoRepairEnabled = (_G.DynamicBagsDB.autoRepair and true or false)
    end
    if _G.DynamicBagsDB.autoSellGrey == nil and _G.DynamicBagsDB.autoSellJunk ~= nil then
        _G.DynamicBagsDB.autoSellGrey = (_G.DynamicBagsDB.autoSellJunk and true or false)
    end
    if _G.DynamicBagsDB.autoSellGrey ~= nil then
        _G.DynamicBagsDB.autoSellJunk = (_G.DynamicBagsDB.autoSellGrey and true or false)
    end
    S.db = _G.DynamicBagsDB
    return S.db
end
DynamicBags.InitDB = EnsureDB

local function DB()
    return S.db or EnsureDB()
end

local function IsSecret(v)
    if type(issecretvalue) == "function" then
        local ok, r = pcall(issecretvalue, v)
        if ok and r then return true end
    end
    if type(canaccessvalue) == "function" then
        local ok, r = pcall(canaccessvalue, v)
        if ok and r == false then return true end
    end
    return false
end

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7C0ADynamic|r|cFFFFFFFFBags|r: " .. tostring(msg))
    end
end

local function SafeRegister(frame, event)
    pcall(frame.RegisterEvent, frame, event)
end

local function CharKey()
    return (UnitName("player") or "Unknown") .. "-" .. (GetRealmName() or "Realm")
end

-- ---- Suite theme helpers (accent / fonts / surfaces) -----------------------

local function GetAccent()
    local suite = _G.DynamicSuite
    if suite and type(suite.GetSuiteAccent) == "function" then
        local ok, a, b, c = pcall(suite.GetSuiteAccent, suite)
        if ok then
            if type(a) == "table" then
                return tonumber(a.r or a[1]) or 1, tonumber(a.g or a[2]) or 0.486, tonumber(a.b or a[3]) or 0.039
            elseif type(a) == "number" and type(b) == "number" and type(c) == "number" then
                return a, b, c
            end
        end
    end
    local ui = _G.DynamicLoadUI
    if ui and type(ui.GetActiveAccentColor) == "function" then
        local ok, r, g, b = pcall(ui.GetActiveAccentColor)
        if ok and type(r) == "number" then return r, g, b end
    end
    return 1.0, 0.486, 0.039
end

local function GetFontPath()
    local suite = _G.DynamicSuite
    if suite and type(suite.GetFontPath) == "function" then
        local ok, p = pcall(suite.GetFontPath, suite)
        if ok and type(p) == "string" and p ~= "" then return p end
    end
    local ui = _G.DynamicLoadUI
    if ui and type(ui.GetActiveFontPath) == "function" then
        local ok, p = pcall(ui.GetActiveFontPath)
        if ok and type(p) == "string" and p ~= "" then return p end
    end
    return "Fonts\\FRIZQT__.TTF"
end

local function SetFont(fs, size, flags)
    if not fs or not fs.SetFont then return end
    local ok = fs:SetFont(GetFontPath(), size or 12, flags or "")
    if not ok then fs:SetFont("Fonts\\FRIZQT__.TTF", size or 12, flags or "") end
end

local function Backdrop(frame, bgR, bgG, bgB, bgA, edR, edG, edB, edA)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(bgR, bgG, bgB, bgA)
    frame:SetBackdropBorderColor(edR, edG, edB, edA)
end

local QUALITY_RGB = {
    [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 },
    [3] = { 0.0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 },
    [6] = { 0.9, 0.8, 0.5 }, [7] = { 0, 0.8, 1 }, [8] = { 0, 0.8, 1 },
}
local function QualityColor(q)
    local c = (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]) or nil
    if c and c.r then return c.r, c.g, c.b end
    c = QUALITY_RGB[q or 1] or QUALITY_RGB[1]
    return c[1], c[2], c[3]
end

-- ============================================================================
-- 2. CLASSIFIER, DELTA-ONLY DIRTY-SLOT CACHE & EQUIPMENT-SET LOOKUP
-- ============================================================================

local function IsKeystone(itemID, link)
    if itemID == KEYSTONE_ITEM_ID then return true end
    if link and type(link) == "string" and link:find("|Hkeystone:", 1, true) then return true end
    if C_Item and C_Item.IsItemKeystoneByID and itemID and itemID > 0 then
        local ok, r = pcall(C_Item.IsItemKeystoneByID, itemID)
        if ok and r then return true end
    end
    return false
end

-- Single-pass integer classifier. `extra` carries live-slot facts (isNew, setName, binding).
local function Classify(itemID, link, quality, classID, extra)
    local db = DB()
    local T = db.categories
    local pin = db.pinnedCategories[itemID]
    if pin and CAT_LABEL[pin] then return pin end
    if extra and extra.isNew and T.new then return "new" end
    if T.keystone and (HEARTH_IDS[itemID] or IsKeystone(itemID, link)) then return "keystone" end
    if extra and extra.setName and T.eqset then return "eqset" end
    if quality == QUALITY_POOR and T.junk then return "junk" end
    if extra and extra.binding then
        if extra.binding == "WUE" and T.wue then return "wue" end
        if extra.binding == "BOE" and T.boe then return "boe" end
    end
    if classID == IC.Consumable then
        return T.consumable and "consumable" or "misc"
    elseif classID == IC.Armor or classID == IC.Weapon then
        return (T.gear ~= false) and "gear" or "misc"
    elseif classID == IC.Tradegoods or classID == IC.Reagent or classID == IC.Recipe then
        return (T.craft ~= false) and "craft" or "misc"
    elseif classID == IC.Gem or classID == IC.Enhancement then
        return (T.gems ~= false) and "gems" or "misc"
    elseif classID == IC.Quest then
        return (T.quest ~= false) and "quest" or "misc"
    end
    return "misc"
end

local WUE_GLOBALS = { "ITEM_ACCOUNTBOUND_UNTIL_EQUIP", "ITEM_BNETACCOUNTBOUND", "ITEM_BIND_TO_BNETACCOUNT" }
local BOE_GLOBALS = { "ITEM_BIND_ON_EQUIP" }

local function MatchesGlobals(text, names)
    for _, gname in ipairs(names) do
        local g = _G[gname]
        if type(g) == "string" and g == text then return true end
    end
    return false
end

-- Tooltip scan for binding + unusable (red text). Cached by slot+link AND link+bound so it never repeats.
function U.ScanGearTooltip(e)
    local okScan = pcall(function()
        local bag = e.bag or e.rBag
        local slot = e.slot or e.rSlot
        local isPlayerBag = (type(bag) == "number" and bag >= 0 and bag <= 5)
        local canQuerySlot = (type(bag) == "number" and type(slot) == "number" and (isPlayerBag or S.atBank == true))

        if e.savedBinding and (e.remote or not canQuerySlot) then
            e.binding = (e.savedBinding ~= "NONE") and e.savedBinding or nil
            return
        end
        e.binding, e.unusable = nil, false
        local ckey = tostring(bag or e.key or "") .. ":" .. tostring(slot or "") .. ":" .. tostring(e.link or e.itemID or "")
        local cached = S.bindCache[ckey]
        if cached ~= nil then
            e.binding = (cached[1] ~= "NONE") and cached[1] or nil
            e.unusable = cached[2] or false
            return
        end
        S.bindByLinkCache = S.bindByLinkCache or {}
        local lkey = tostring(e.link or e.itemID or "") .. ":" .. (e.isBound and "1" or "0") .. ":" .. (e.inWarband and "W" or "B")
        local linkCached = S.bindByLinkCache[lkey]
        if linkCached ~= nil then
            S.bindCache[ckey] = linkCached
            e.binding = (linkCached[1] ~= "NONE") and linkCached[1] or nil
            e.unusable = linkCached[2] or false
            return
        end
        local binding, unusable = nil, false

        -- 1. Only call ItemLocation:CreateFromBagAndSlot when the container is loaded in C++ (player bags 0..5 or while at Banker)
        if canQuerySlot and ItemLocation and ItemLocation.CreateFromBagAndSlot and C_Item and C_Item.IsBoundToAccountUntilEquip then
            local okL, isWue = pcall(function()
                local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                if type(loc) == "table" and loc.HasAnyLocation and loc:HasAnyLocation() and C_Item.DoesItemExist(loc) then
                    return C_Item.IsBoundToAccountUntilEquip(loc)
                end
                return false
            end)
            if okL and isWue then binding = "WUE" end
        end

        -- 2. Scan Tooltip lines (use GetBagItem only if container is live, otherwise use GetHyperlink)
        if C_TooltipInfo then
            local ok, data = false, nil
            if canQuerySlot and C_TooltipInfo.GetBagItem then
                ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
                if not (ok and type(data) == "table" and type(data.lines) == "table" and #data.lines > 0) then
                    ok, data = false, nil
                end
            end
            if (not ok) and e.link and C_TooltipInfo.GetHyperlink then
                ok, data = pcall(C_TooltipInfo.GetHyperlink, e.link)
            end
            if ok and type(data) == "table" and type(data.lines) == "table" then
                local sawSoulbound = false
                for _, line in ipairs(data.lines) do
                    local t = line.leftText
                    if type(t) == "string" and not IsSecret(t) then
                        local tl = t:lower()
                        if MatchesGlobals(t, WUE_GLOBALS)
                            or tl:find("warbound", 1, true)
                            or tl:find("account bound", 1, true)
                            or tl:find("bnetaccountbound", 1, true) then
                            binding = "WUE"
                        elseif binding ~= "WUE" and (MatchesGlobals(t, BOE_GLOBALS) or tl:find("binds when equipped", 1, true) or tl:find("bind on equip", 1, true)) then
                            binding = "BOE"
                        elseif t == ITEM_SOULBOUND or tl:find("soulbound", 1, true) then
                            sawSoulbound = true
                        end
                    end
                    local c = line.leftColor
                    if type(c) == "table" and not unusable then
                        local okc, red = pcall(function() return c.r > 0.9 and c.g < 0.25 and c.b < 0.25 end)
                        if okc and red then unusable = true end
                    end
                end
                if sawSoulbound and binding == "BOE" then binding = nil end
            end
        end

        if not binding and e.savedBinding and e.savedBinding ~= "NONE" then
            binding = e.savedBinding
        end
        if not binding and e.inWarband and (e.classID == IC.Armor or e.classID == IC.Weapon) then
            binding = "WUE"
        end
        if not e.isBound and not e.remote and binding == nil and (e.quality or 0) >= 2 and (e.classID == IC.Armor or e.classID == IC.Weapon) then
            binding = "BOE"
        end

        local n = 0
        for _ in pairs(S.bindCache) do n = n + 1 if n > 1500 then break end end
        if n > 1500 then wipe(S.bindCache) end
        local record = { binding or "NONE", unusable and true or false }
        S.bindCache[ckey] = record
        S.bindByLinkCache[lkey] = record
        e.binding, e.unusable = binding, unusable
    end)
    if not okScan then
        e.binding = (e.savedBinding ~= "NONE" and e.savedBinding) or nil
    end
end
function U.DecodeLocation(loc)
    if EquipmentManager_GetLocationData then
        local ok, d = pcall(EquipmentManager_GetLocationData, loc)
        if ok and type(d) == "table" then
            if d.isBags and d.bag and d.slot then return d.bag, d.slot end
            if d.isBank and d.bag and d.slot then return d.bag, d.slot end
            return nil
        end
    end
    if EquipmentManager_UnpackLocation then
        local ok, _, bank, bags, _, slot, bag = pcall(EquipmentManager_UnpackLocation, loc)
        if ok and (bags or bank) and bag and slot then return bag, slot end
    end
    return nil
end

-- Rebuilds the "bag:slot" -> set name lookup. Returns true when membership changed.
function U.RefreshEquipSets()
    local old = S.setLookup
    local new = {}
    S.setByItemID = {}

    if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs then
        local ok, ids = pcall(C_EquipmentSet.GetEquipmentSetIDs)
        if ok and type(ids) == "table" then
            for _, setID in ipairs(ids) do
                local okN, name, _, _, isEquipped = pcall(C_EquipmentSet.GetEquipmentSetInfo, setID)
                local sName = (okN and type(name) == "string" and name) or "Set"
                local okL, locs = pcall(C_EquipmentSet.GetItemLocations, setID)
                local okI, itemIDs = false, nil
                if C_EquipmentSet.GetItemIDs then
                    okI, itemIDs = pcall(C_EquipmentSet.GetItemIDs, setID)
                end

                if okL and type(locs) == "table" then
                    for slotIdx, loc in pairs(locs) do
                        if type(loc) == "number" and loc > 0 and not isEquipped then
                            local bag, slot = U.DecodeLocation(loc)
                            if bag and slot then
                                local key = bag .. ":" .. slot
                                if not new[key] then
                                    new[key] = sName
                                end
                            end
                        elseif type(loc) == "number" and loc > 0 and isEquipped then
                            -- Even if a set is marked equipped, check if a piece was manually unequipped into bags
                            local bag, slot = U.DecodeLocation(loc)
                            if bag and slot then
                                local key = bag .. ":" .. slot
                                if not new[key] then
                                    new[key] = sName
                                end
                            end
                        end

                        -- Only populate S.setByItemID (used strictly for offline Warband/Bank snapshots without bag:slot)
                        -- when the set item is NOT currently equipped on the player!
                        if okI and type(itemIDs) == "table" and itemIDs[slotIdx] and itemIDs[slotIdx] > 0 then
                            local isWornOnPlayer = false
                            if EquipmentManager_GetLocationData then
                                local okD, d = pcall(EquipmentManager_GetLocationData, loc)
                                if okD and type(d) == "table" and (d.isPlayer or d.player) and not (d.isBags or d.bags or d.isBank or d.bank) then
                                    isWornOnPlayer = true
                                end
                            end
                            if not isWornOnPlayer and not isEquipped then
                                local iid = itemIDs[slotIdx]
                                if not S.setByItemID[iid] then
                                    S.setByItemID[iid] = sName
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local changed = false
    for k, v in pairs(new) do if old[k] ~= v then changed = true break end end
    if not changed then for k in pairs(old) do if new[k] == nil then changed = true break end end end
    S.setLookup = new
    return changed
end
function U.GetLiveBagIDs()
    local ids = {}
    for i = 0, (NUM_BAG_SLOTS or 4) do ids[#ids + 1] = i end
    ids[#ids + 1] = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
    return ids
end

function U.GetSlotInfo(bagID, slot)
    local ok, info = pcall(C_Container.GetContainerItemInfo, bagID, slot)
    if ok and type(info) == "table" and info.itemID then
        if IsSecret(info.hyperlink) or IsSecret(info.stackCount) then return nil end
        return info
    end
    return nil
end

function U.ComputeNew(e)
    local skey = e.key .. ":" .. tostring(e.link)
    if S.loginBaselineDone and C_NewItems and C_NewItems.IsNewItem then
        local ok, r = pcall(C_NewItems.IsNewItem, e.bag, e.slot)
        if ok and r then S.sessionNew[skey] = true end
    end
    e.isNew = S.sessionNew[skey] and true or false
end

function U.ClassifyEntry(e)
    return Classify(e.itemID, e.link, e.quality, e.classID, e)
end

-- Known 2-tier consumable overrides (e.g. Midnight Potion of Recklessness)
local KNOWN_2TIER_ITEMS = {
    [241288] = { tier = 2, maxTiers = 2 }, -- Gold quality (Tier 2)
    [241289] = { tier = 1, maxTiers = 2 }, -- Silver quality (Tier 1)
}

function U.DetectCraftQuality(link, itemID, bagID, slotID, classID, expacID)
    if not itemID and not link then return nil, nil, nil end
    if classID ~= IC.Consumable and classID ~= IC.Reagent and classID ~= IC.Tradegoods and classID ~= IC.Enhancement and classID ~= IC.Gem and classID ~= IC.Armor and classID ~= IC.Weapon then
        return nil, nil, nil
    end
    local id = itemID or (type(link) == "string" and tonumber(link:match("item:(%d+)")))
    if id and KNOWN_2TIER_ITEMS[id] then
        local k = KNOWN_2TIER_ITEMS[id]
        return k.tier, k.maxTiers, nil
    end

    S.qualityCache = S.qualityCache or {}
    local cacheKey = tostring(link or id or itemID)
    local cached = S.qualityCache[cacheKey]
    if cached ~= nil then
        if cached == false then return nil, nil, nil end
        return cached[1], cached[2], cached[3]
    end
    S.qualityCacheCount = (S.qualityCacheCount or 0) + 1
    if S.qualityCacheCount > 2000 then
        wipe(S.qualityCache)
        S.qualityCacheCount = 1
    end

    local q, atlas = nil, nil
    -- 1. Query C_TradeSkillUI for crafted quality
    if C_TradeSkillUI and C_TradeSkillUI.GetItemCraftedQualityByItemInfo then
        local ok, val = pcall(C_TradeSkillUI.GetItemCraftedQualityByItemInfo, link or id)
        if ok and type(val) == "number" and val > 0 then q = val end
    end
    -- 2. Query C_TradeSkillUI for reagent quality
    if not q and C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo then
        local ok, val = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, link or id)
        if ok and type(val) == "number" and val > 0 then q = val end
    end
    -- 3. Query C_Item for crafted quality
    if not q and C_Item and C_Item.GetItemCraftedQualityByItemInfo then
        local ok, val = pcall(C_Item.GetItemCraftedQualityByItemInfo, link or id)
        if ok and type(val) == "number" and val > 0 then q = val end
    end

    -- 4. Tooltip scan fallback via C_TooltipInfo ONLY if API returned nil
    if not q and C_TooltipInfo then
        local data = nil
        local isPlayerBag = (type(bagID) == "number" and bagID >= 0 and bagID <= 5)
        local canQuerySlot = (type(bagID) == "number" and type(slotID) == "number" and (isPlayerBag or S.atBank == true))
        if canQuerySlot and C_TooltipInfo.GetBagItem then
            local ok, d = pcall(C_TooltipInfo.GetBagItem, bagID, slotID)
            if ok and d then data = d end
        end
        if not data and link and C_TooltipInfo.GetHyperlink then
            local ok, d = pcall(C_TooltipInfo.GetHyperlink, link)
            if ok and d then data = d end
        end
        if not data and id and C_TooltipInfo.GetItemByID then
            local ok, d = pcall(C_TooltipInfo.GetItemByID, id)
            if ok and d then data = d end
        end
        if data and data.lines then
            for _, line in ipairs(data.lines) do
                if line.atlas then
                    local t = line.atlas:match("Professions%-[%w%-_]*Quality%-Tier(%d)")
                    if t then
                        atlas = line.atlas
                        if not q then q = tonumber(t) end
                        break
                    end
                end
                if line.leftText and not IsSecret(line.leftText) then
                    local a = line.leftText:match("Professions%-[%w%-_]*Quality%-Tier%d[^\"]*")
                    local t = line.leftText:match("Professions%-[%w%-_]*Quality%-Tier(%d)")
                    if t then
                        if a and not atlas then atlas = a end
                        if not q then q = tonumber(t) end
                        break
                    end
                end
            end
        end
    end

    if not q or q <= 0 then
        S.qualityCache[cacheKey] = false
        return nil, nil, nil
    end

    local maxTiers = 3
    if classID == IC.Consumable then
        if q == 3 then
            maxTiers = 3
        else
            maxTiers = 2
        end
    elseif q > 3 then
        maxTiers = 5
    end

    S.qualityCache[cacheKey] = { q, maxTiers, atlas }
    return q, maxTiers, atlas
end

function U.GetQualityAtlas(quality, maxTiers, tooltipAtlas)
    if tooltipAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(tooltipAtlas) then
        return tooltipAtlas, 1, 1, 1
    end
    if maxTiers == 2 then
        -- Midnight 2-tier consumable system:
        -- Tier 2 = Gold
        -- Tier 1 = Silver
        if quality >= 2 then
            return "Professions-Icon-Quality-Tier3-Small", 1.0, 0.84, 0.0
        else
            return "Professions-Icon-Quality-Tier2-Small", 0.78, 0.82, 0.88
        end
    elseif maxTiers == 3 then
        -- 3-tier reagent / legacy system:
        -- Tier 1 = Bronze, Tier 2 = Silver, Tier 3 = Gold
        if quality == 1 then
            return "Professions-Icon-Quality-Tier1-Small", 0.80, 0.50, 0.20
        elseif quality == 2 then
            return "Professions-Icon-Quality-Tier2-Small", 0.78, 0.82, 0.88
        else
            return "Professions-Icon-Quality-Tier3-Small", 1.0, 0.84, 0.0
        end
    else
        -- 5-tier system (Gear)
        local t = math.min(math.max(quality, 1), 5)
        return "Professions-Icon-Quality-Tier" .. t .. "-Small", 1, 1, 1
    end
end

function U.MakeEntry(bagID, slotID, info)
    local link, itemID = info.hyperlink, info.itemID or 0
    local classID, subClassID, instIcon, equipLoc = 15, 0, nil, ""
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, eqLoc, ic, cID, scID = C_Item.GetItemInfoInstant(link or itemID)
        equipLoc, instIcon, classID, subClassID = eqLoc or "", ic, cID or 15, scID or 0
    end
    local expacID = 0
    if C_Item and C_Item.GetItemInfo then
        local exp = select(15, C_Item.GetItemInfo(link or itemID))
        if type(exp) == "number" then expacID = exp end
    end
    local e = {
        key = bagID .. ":" .. slotID, bag = bagID, slot = slotID, itemID = itemID, link = link,
        count = info.stackCount or 1, quality = info.quality or 1,
        icon = info.iconFileID or instIcon, classID = classID, subClassID = subClassID,
        equipLoc = equipLoc, expacID = expacID,
        ilvl = 0, name = (type(link) == "string" and link:match("%[(.-)%]")) or "",
        locked = info.isLocked and true or false, isBound = info.isBound and true or false,
        binding = nil, unusable = false, upgrade = false, upgradeGen = -1,
    }
    if type(link) == "string" then
        e.ksLevel = tonumber(link:match("keystone:%d+:%d+:(%d+)"))
    end
    local cq, cmax, catlas = U.DetectCraftQuality(link, itemID, bagID, slotID, classID, expacID)
    e.craftQuality = cq
    e.craftMaxTiers = cmax
    e.craftAtlas = catlas
    if classID == IC.Armor or classID == IC.Weapon then
        if link and C_Item and C_Item.GetDetailedItemLevelInfo then
            local ok, v = pcall(C_Item.GetDetailedItemLevelInfo, link)
            if ok and type(v) == "number" and not IsSecret(v) then e.ilvl = v end
        end
        U.ScanGearTooltip(e)
    end
    e.setName = S.setLookup[e.key]
    U.ComputeNew(e)
    e.cat = U.ClassifyEntry(e)
    return e
end

function U.ReclassifyAll()
    for _, bagID in ipairs(S.bagIDs) do
        local bc = S.slotCache[bagID]
        if bc then
            for _, e in pairs(bc) do
                e.cat = U.ClassifyEntry(e)
            end
        end
    end
    S.layoutVersion = S.layoutVersion + 1
end

-- Consumes dirtyBags on BAG_UPDATE_DELAYED. Only re-evaluates slots whose link/count changed.
function U.ProcessDirtyBags()
    if not next(S.dirtyBags) and not S.forceFull then return end
    if #S.bagIDs == 0 then S.bagIDs = U.GetLiveBagIDs() end
    local changed = false

    if U.RefreshEquipSets() then
        for _, bagID in ipairs(S.bagIDs) do
            local bc = S.slotCache[bagID]
            if bc then
                for _, e in pairs(bc) do
                    local sn = S.setLookup[e.key]
                    if e.setName ~= sn then
                        e.setName = sn
                        e.cat = U.ClassifyEntry(e)
                        changed = true
                    end
                end
            end
        end
    end

    local dirty = S.dirtyBags
    if S.forceFull then
        dirty = {}
        for _, bagID in ipairs(S.bagIDs) do dirty[bagID] = true end
        S.forceFull = false
    end
    for bagID in pairs(dirty) do
        local n = 0
        local okN, num = pcall(C_Container.GetContainerNumSlots, bagID)
        if okN and type(num) == "number" then n = num end
        local bc = S.slotCache[bagID]
        if not bc then bc = {}; S.slotCache[bagID] = bc end
        if (S.slotCount[bagID] or 0) ~= n then changed = true end
        for slot = n + 1, (S.slotCount[bagID] or 0) do bc[slot] = nil end
        S.slotCount[bagID] = n
        for slot = 1, n do
            local info = U.GetSlotInfo(bagID, slot)
            local e = bc[slot]
            if info then
                if (not e) or e.link ~= info.hyperlink or e.count ~= info.stackCount then
                    local okE, entryObj = pcall(U.MakeEntry, bagID, slot, info); if okE and entryObj then bc[slot] = entryObj end
                    changed = true
                else
                    local locked = info.isLocked and true or false
                    if e.locked ~= locked then e.locked = locked; e.lockDirty = true end
                end
            elseif e then
                bc[slot] = nil
                changed = true
            end
        end
    end
    wipe(S.dirtyBags)

    if changed then S.layoutVersion = S.layoutVersion + 1 end
    return changed
end

function U.RecheckNewItems()
    local changed = false
    for _, bagID in ipairs(S.bagIDs) do
        local bc = S.slotCache[bagID]
        if bc then
            for _, e in pairs(bc) do
                local was = e.isNew
                U.ComputeNew(e)
                if e.isNew ~= was then
                    e.cat = U.ClassifyEntry(e)
                    changed = true
                end
            end
        end
    end
    if changed then S.layoutVersion = S.layoutVersion + 1 end
    return changed
end

-- ============================================================================
-- 3. PRE-COMPUTED VIRTUAL LAYOUT (never calls SortBags on open)
-- ============================================================================

local function SortObj(a, b)
    local db = DB()
    local anm, bnm = (a.name or ""):lower(), (b.name or ""):lower()
    local aHas, bHas = (anm ~= ""), (bnm ~= "")
    if db and db.sortBy == "NAME" then
        if aHas ~= bHas then return aHas end
        if anm ~= bnm then return anm < bnm end
    end
    local aq, bq = a.quality or 0, b.quality or 0
    if aq ~= bq then return aq > bq end
    local ai, bi = a.ilvl or 0, b.ilvl or 0
    if ai ~= bi then return ai > bi end
    if aHas ~= bHas then return aHas end
    if anm ~= bnm then return anm < bnm end
    local ac, bc = a.classID or 0, b.classID or 0
    if ac ~= bc then return ac < bc end
    local asc, bsc = a.subClassID or 0, b.subClassID or 0
    if asc ~= bsc then return asc < bsc end
    local aid, bid = a.itemID or 0, b.itemID or 0
    if aid ~= bid then return aid < bid end
    local an, bn = a.count or 0, b.count or 0
    if an ~= bn then return an > bn end
    local abag, bbag = a.bag or a.gTab or 0, b.bag or b.gTab or 0
    if abag ~= bbag then return abag < bbag end
    local aslot, bslot = a.slot or a.gSlot or 0, b.slot or b.gSlot or 0
    if aslot ~= bslot then return aslot < bslot end
    return tostring(a.key or a.rkey or "") < tostring(b.key or b.rkey or "")
end

-- Packs `objs` (each with .cat) into a pixel layout. `freeObjs` = pseudo-items shown as "Free Space".
-- Returns { placed = { {obj,x,y} }, sections = { {label,count,x,y,w} }, width, height }.
function U.GetSectionMeasureFS()
    if not S.measureFS then
        local f = CreateFrame("Frame", nil, UIParent)
        f:Hide()
        S.measureFS = f:CreateFontString(nil, "OVERLAY")
    end
    SetFont(S.measureFS, 11, "")
    return S.measureFS
end

function U.PackLayout(objs, mode, cols, size, spacing, freeObjs)
    local step = size + SLOT_GAP
    local placed, sections = {}, {}
    cols = max(4, cols or 14)

    local db = DB()
    local doSort = (db.autoSort ~= false)
    if mode == "GRID" then
        if doSort then tsort(objs, SortObj) end
        local i = 0
        for _, o in ipairs(objs) do
            placed[#placed + 1] = { obj = o, x = (i % cols) * step, y = floor(i / cols) * step }
            i = i + 1
        end
        for _, o in ipairs(freeObjs or {}) do
            placed[#placed + 1] = { obj = o, x = (i % cols) * step, y = floor(i / cols) * step }
            i = i + 1
        end
        local rows = max(1, ceil(i / cols))
        return { placed = placed, sections = sections, width = cols * step, height = rows * step }
    end

    local db = DB()
    if type(db.catOrder) ~= "table" or #db.catOrder ~= #CATS then
        db.catOrder = {}
        for i, c in ipairs(CATS) do db.catOrder[i] = c.key end
    end
    db.secPriority = db.secPriority or {}

    local catRank = {}
    for idx, ck in ipairs(db.catOrder) do catRank[ck] = idx * 100 end

    local function GetSubBucket(o)
        local cat = o.cat
        if (cat == "gear" or cat == "wue" or cat == "boe") and db.splitUpgrades == true and U.IsUpgrade(o) then
            return cat .. ":upgrade", "Gear Upgrades", (catRank[cat] or 500) - 5
        elseif cat == "eqset" and o.setName and o.setName ~= "" and db.splitEqSets ~= false then
            return "eqset:" .. o.setName, "Set: " .. o.setName, (catRank[cat] or 400) + 1
        elseif (cat == "gear" and db.splitGearSlots ~= false) or ((cat == "wue" or cat == "boe") and db.splitBindSlots == true) then
            local prefix = (cat == "wue" and "WUE ") or (cat == "boe" and "BoE ") or ""
            local eq = o.equipLoc or ""
            if o.classID == IC.Weapon or eq == "INVTYPE_WEAPON" or eq == "INVTYPE_2HWEAPON" or eq == "INVTYPE_WEAPONMAINHAND" or eq == "INVTYPE_WEAPONOFFHAND" or eq == "INVTYPE_HOLDABLE" or eq == "INVTYPE_SHIELD" or eq == "INVTYPE_RANGED" then
                return cat .. ":weap", prefix .. "Weapons & Off-Hand", (catRank[cat] or 500) + 1
            elseif eq == "INVTYPE_TRINKET" then
                return cat .. ":trink", prefix .. "Trinkets", (catRank[cat] or 500) + 2
            elseif eq == "INVTYPE_FINGER" or eq == "INVTYPE_NECK" or eq == "INVTYPE_CLOAK" then
                return cat .. ":ring", prefix .. "Rings, Neck & Cloak", (catRank[cat] or 500) + 3
            else
                return cat .. ":armor", prefix .. "Armour", (catRank[cat] or 500) + 4
            end
        elseif cat == "consumable" and db.splitConsumables ~= false then
            local sc = o.subClassID or 0
            if sc == 1 then return "cons:potion", "Potions", (catRank[cat] or 300) + 1
            elseif sc == 2 or sc == 3 then return "cons:flask", "Flasks & Phials", (catRank[cat] or 300) + 2
            elseif sc == 5 then return "cons:food", "Food & Drink", (catRank[cat] or 300) + 3
            elseif sc == 7 or sc == 8 or sc == 9 then return "cons:rune", "Runes & Vantus", (catRank[cat] or 300) + 4
            else return "cons:other", "Consumables", (catRank[cat] or 300) + 5 end
        elseif cat == "gems" and db.splitGemsEnchants ~= false then
            if o.classID == IC.Gem then
                return "gems:gem", "Socketable Gems", (catRank[cat] or 700) + 1
            else
                return "gems:ench", "Item Enchants & Enhancements", (catRank[cat] or 700) + 2
            end
        elseif cat == "craft" and db.splitReagents ~= false then
            local exp = o.expacID or 0
            local era = (exp >= 11 and "Midnight") or (exp == 10 and "War Within") or (exp == 9 and "Dragonflight") or "Legacy"
            local eraOff = (exp >= 11 and 1) or (exp == 10 and 10) or (exp == 9 and 20) or 30
            local sc = o.subClassID or 0
            local rType = "Reagents"
            if o.classID == IC.Recipe then rType = "Recipes"
            elseif sc == 9 then rType = "Herbs"
            elseif sc == 7 then rType = "Ore & Stone"
            elseif sc == 12 then rType = "Enchanting"
            elseif sc == 5 or sc == 6 then rType = "Cloth & Leather"
            elseif sc == 4 then rType = "Jewelcrafting"
            elseif sc == 8 then rType = "Cooking"
            elseif sc == 18 or sc == 19 then rType = "Finishing Reagents"
            end
            local fullLbl = era .. ": " .. rType
            return "craft:" .. fullLbl, fullLbl, (catRank[cat] or 800) + eraOff
        elseif cat == "misc" and db.splitCollectibles ~= false then
            if C_ToyBox and C_ToyBox.GetToyInfo and C_ToyBox.GetToyInfo(o.itemID) then
                return "misc:toys", "Toys & Collectibles", (catRank[cat] or 900) - 2
            elseif o.subClassID == 2 or o.subClassID == 5 then
                return "misc:mounts", "Mounts & Companions", (catRank[cat] or 900) - 1
            end
        end
        return cat, CAT_LABEL[cat] or cat, (catRank[cat] or 900)
    end
    local bucketMap = {}
    local ordered = {}
    for _, o in ipairs(objs) do
        local bKey, bLabel, defaultOrder = GetSubBucket(o)
        local b = bucketMap[bKey]
        if not b then
            b = {
                key = bKey,
                catKey = o.cat,
                label = bLabel,
                order = db.secPriority[bKey] or defaultOrder,
                items = {},
            }
            bucketMap[bKey] = b
            ordered[#ordered + 1] = b
        end
        b.items[#b.items + 1] = o
    end

    if doSort then
        for _, b in ipairs(ordered) do
            tsort(b.items, SortObj)
        end
    end
    tsort(ordered, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.label < b.label
    end)

    if freeObjs and #freeObjs > 0 then
        ordered[#ordered + 1] = { key = "free", catKey = "free", label = "Free Space", order = 99999, items = freeObjs }
    end

    -- Measure exact pixel width of each section header so we reserve enough columns and NEVER overlap titles!
    db.collapsedSections = db.collapsedSections or {}
    local mfs = U.GetSectionMeasureFS()
    for _, sec in ipairs(ordered) do
        local n = #sec.items
        local hdrCount = (sec.label == "Free Space" and sec.items[1] and sec.items[1].freeCount) or n
        local isCollapsed = (sec.key ~= "free") and (db.collapsedSections[sec.key] == true)
        sec.collapsed = isCollapsed
        local countLabel = isCollapsed and sformat("(%d)", hdrCount) or tostring(hdrCount)
        mfs:SetText(string.upper(sec.label) .. "  " .. countLabel)
        local textPx = (mfs:GetStringWidth() or (#sec.label * 7.5)) + 30
        local minColsForTitle = ceil((textPx + SLOT_GAP) / step)
        sec.hdrCount = hdrCount
        sec.itemCols = min(cols, max(1, n))
        sec.secCols  = isCollapsed and min(cols, max(2, minColsForTitle)) or min(cols, max(sec.itemCols, minColsForTitle))
    end

    -- Family-Cohesive 2D Row Packing:
    -- Sub-categories of the SAME parent family (e.g. all "eqset" sets, all "consumable" types, all "craft" reagents)
    -- pack side-by-side together, and a new parent family only shares a row if no unplaced siblings of the current family remain!
    local SEC_GAP_COLS = 0.45
    local used = {}
    local remaining = #ordered
    local curSlot, rowY, rowH = 0, 0, 0
    local curRowCatKey = nil

    while remaining > 0 do
        local pickedIdx = nil
        local availCols = cols - curSlot

        -- Determine the next primary family in line
        local leadCatKey = nil
        for idx, sec in ipairs(ordered) do
            if not used[idx] then leadCatKey = sec.catKey; break end
        end

        -- Check if the current row's family still has any unplaced sub-sections
        local curFamilyHasMore = false
        if curSlot > 0 and curRowCatKey then
            for idx, sec in ipairs(ordered) do
                if not used[idx] and sec.catKey == curRowCatKey then
                    curFamilyHasMore = true
                    break
                end
            end
        end

        for idx, sec in ipairs(ordered) do
            if not used[idx] then
                if sec.key == "free" and remaining > 1 then
                    -- Keep Free Space last
                elseif sec.secCols <= (availCols + 0.05) then
                    if curSlot == 0 then
                        pickedIdx = idx
                        break
                    elseif curFamilyHasMore then
                        -- Only pull a sibling from the SAME parent family (so Consumables never mix with EQ Sets!)
                        if sec.catKey == curRowCatKey then
                            pickedIdx = idx
                            break
                        end
                    elseif sec.catKey == leadCatKey and sec.catKey ~= "eqset" and curRowCatKey ~= "eqset" then
                        pickedIdx = idx
                        break
                    end
                end
            end
        end

        if not pickedIdx then
            if curSlot > 0 then
                rowY = rowY + rowH + spacing
                curSlot, rowH, curRowCatKey = 0, 0, nil
            else
                for idx = 1, #ordered do
                    if not used[idx] then pickedIdx = idx; break end
                end
            end
        end

        if pickedIdx then
            used[pickedIdx] = true
            remaining = remaining - 1
            local sec = ordered[pickedIdx]; curRowCatKey = sec.catKey
            local n = #sec.items
            local secCols = sec.secCols
            local itemCols = sec.itemCols
            local x0 = floor(curSlot * step + 0.5)
            local isCollapsed = sec.collapsed == true
            local rows = isCollapsed and 0 or max(1, ceil(n / itemCols))
            local secH = SECTION_HEADER_H + (isCollapsed and 0 or (rows * step))

            sections[#sections + 1] = {
                key = sec.key,
                catKey = sec.catKey,
                label = sec.label,
                order = sec.order,
                count = sec.hdrCount,
                collapsed = isCollapsed,
                items = sec.items,
                x = x0,
                y = rowY,
                w = secCols * step - SLOT_GAP,
            }
            if not isCollapsed then
                for i, o in ipairs(sec.items) do
                    local idx = i - 1
                    placed[#placed + 1] = {
                        obj = o,
                        x = x0 + (idx % itemCols) * step,
                        y = rowY + SECTION_HEADER_H + floor(idx / itemCols) * step,
                    }
                end
            end
            -- Always add SEC_GAP_COLS (18px) between side-by-side categories so POTIONS and FLASKS never touch!
            curSlot = curSlot + secCols + SEC_GAP_COLS
            if secH > rowH then rowH = secH end
        end
    end

    return { placed = placed, sections = sections, width = cols * step, height = max(step, rowY + rowH) }
end
function U.BuildLiveLayout()
    local db = DB()
    local mode = db.viewMode
    local objs, regularEmpties, allEmpties = {}, {}, {}
    local reagentID = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
    for _, bagID in ipairs(S.bagIDs) do
        local n = S.slotCount[bagID] or 0
        local bc = S.slotCache[bagID]
        for slot = 1, n do
            local e = bc and bc[slot]
            if e then
                objs[#objs + 1] = e
            else
                local empty = { key = bagID .. ":" .. slot, bag = bagID, slot = slot, empty = true, cat = "misc" }
                allEmpties[#allEmpties + 1] = empty
                if bagID ~= reagentID then regularEmpties[#regularEmpties + 1] = empty end
            end
        end
    end
    local freeObjs
    if mode == "GRID" then
        freeObjs = allEmpties
    else
        freeObjs = {}
        if #regularEmpties > 0 then
            regularEmpties[1].freeCount = #regularEmpties
            regularEmpties[1].freeTag = tostring(#regularEmpties)
            freeObjs[#freeObjs + 1] = regularEmpties[1]
        end
        local reaEmpties = #allEmpties - #regularEmpties
        if reaEmpties > 0 then
            for _, em in ipairs(allEmpties) do
                if em.bag == reagentID then
                    em.freeCount = reaEmpties
                    em.freeTag = reaEmpties .. "R"
                    freeObjs[#freeObjs + 1] = em
                    break
                end
            end
        end
    end
    S.layout = U.PackLayout(objs, mode, db.bagColumns, db.iconSize, db.categorySpacing, freeObjs)
    S.layout.version = S.layoutVersion
    S.freeRegular = #regularEmpties
    S.freeTotal = #allEmpties
    S.usedTotal = #objs
end

-- ============================================================================
-- 4. ALT & WARBAND VAULT (DynamicBagsDB.vault) + TOOLTIP COUNTS
-- ============================================================================

local function CollectBagIDs(prefixes)
    local ids = {}
    local B = Enum and Enum.BagIndex
    if B then
        local hasModernCharBank = (B.CharacterBankTab_1 ~= nil)
        local wantsCharBank = false
        for _, p in ipairs(prefixes) do
            if p == "CharacterBankTab" then
                wantsCharBank = true
                break
            end
        end
        for name, id in pairs(B) do
            if type(name) == "string" and type(id) == "number" then
                for _, p in ipairs(prefixes) do
                    if not (hasModernCharBank and wantsCharBank and (p == "Bank" or p == "Reagentbank")) then
                        if name:sub(1, #p) == p then ids[#ids + 1] = id break end
                    end
                end
            end
        end
    end
    tsort(ids)
    return ids
end

function U.ItemLevelOf(link, itemID)
    if not link or not (C_Item and C_Item.GetItemInfoInstant and C_Item.GetDetailedItemLevelInfo) then return 0 end
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(link)
    if classID == IC.Armor or classID == IC.Weapon then
        local ok, v = pcall(C_Item.GetDetailedItemLevelInfo, link)
        if ok and type(v) == "number" and not IsSecret(v) then return v end
    end
    return 0
end

-- Compact positional tuples: { itemID, link, count, ilvl, quality }
function U.SnapshotBagIDs(bagIDs, skipTooltipScan)
    local out = {}
    local widsSet = nil
    local B = Enum and Enum.BagIndex
    if B then
        widsSet = {}
        for name, id in pairs(B) do
            if type(name) == "string" and type(id) == "number" and name:sub(1, 14) == "AccountBankTab" then
                widsSet[id] = true
            end
        end
    end
    for _, bagID in ipairs(bagIDs) do
        local okN, n = pcall(C_Container.GetContainerNumSlots, bagID)
        if okN and type(n) == "number" and n > 0 then
            local bc = S.slotCache and S.slotCache[bagID]
            local inWarband = (widsSet and widsSet[bagID]) and true or false
            for slot = 1, n do
                local info = U.GetSlotInfo(bagID, slot)
                if info then
                    local cachedSlot = bc and bc[slot]
                    local bindingVal = nil
                    if cachedSlot and cachedSlot.link == info.hyperlink and cachedSlot.binding ~= nil then
                        bindingVal = cachedSlot.binding
                    elseif not skipTooltipScan then
                        local cID
                        if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
                            local _, _, _, _, _, cid = C_Item.GetItemInfoInstant(info.hyperlink or info.itemID)
                            cID = cid
                        end
                        local probe = {
                            key = bagID .. ":" .. slot, bag = bagID, slot = slot,
                            itemID = info.itemID, link = info.hyperlink,
                            classID = cID or 15, isBound = info.isBound and true or false,
                            inWarband = inWarband,
                        }
                        if cID == IC.Armor or cID == IC.Weapon then
                            U.ScanGearTooltip(probe)
                        end
                        bindingVal = probe.binding or "NONE"
                    end
                    local ilvlVal = (cachedSlot and cachedSlot.link == info.hyperlink and cachedSlot.ilvl)
                        or U.ItemLevelOf(info.hyperlink, info.itemID)
                    out[#out + 1] = {
                        info.itemID, info.hyperlink, info.stackCount or 1,
                        ilvlVal, info.quality or 1,
                        bag = bagID, slot = slot, binding = bindingVal,
                    }
                end
            end
        end
    end
    return out
end

function U.GetCharRecord()
    local db = DB()
    local key = CharKey()
    local rec = db.vault.characters[key]
    if not rec then
        rec = {}
        db.vault.characters[key] = rec
    end
    local _, class = UnitClass("player")
    rec.name = UnitName("player")
    rec.realm = GetRealmName()
    rec.class = class
    rec.level = UnitLevel("player")
    rec.gold = GetMoney and GetMoney() or 0
    rec.updated = time and time() or 0
    return rec
end

function U.SnapshotBags()
    local rec = U.GetCharRecord()
    rec.bags = U.SnapshotBagIDs(S.bagIDs)
    S.vaultVersion = S.vaultVersion + 1
end

function U.SnapshotBank(skipTooltipScan)
    local rec = U.GetCharRecord()
    local ids = CollectBagIDs({ "CharacterBankTab", "Bank", "Reagentbank" })
    if #ids > 0 then
        local snap = U.SnapshotBagIDs(ids, skipTooltipScan)
        local bTabs = nil
        if S.atBank then
            bTabs = {}
            for _, bagID in ipairs(ids) do
                local okN, slots = pcall(C_Container.GetContainerNumSlots, bagID)
                if okN and type(slots) == "number" and slots > 0 then
                    local idx = #bTabs + 1
                    local lbl = (bagID == -3 or tostring(bagID):find("Reagent")) and "Reagents" or ("Tab " .. idx)
                    bTabs[idx] = { id = idx, bagID = bagID, name = lbl, slots = slots }
                end
            end
            if #bTabs > 0 then
                rec.bankTabs = bTabs
            end
        end
        if #snap > 0 or not rec.bank or (S.atBank and bTabs and #bTabs > 0) then
            rec.bank = snap
        end
    end
    local wids = CollectBagIDs({ "AccountBankTab" })
    if #wids > 0 then
        local wsnap = U.SnapshotBagIDs(wids, skipTooltipScan)
        local wTabs = nil
        if S.atBank then
            wTabs = {}
            for _, bagID in ipairs(wids) do
                local okN, slots = pcall(C_Container.GetContainerNumSlots, bagID)
                if okN and type(slots) == "number" and slots > 0 then
                    local idx = #wTabs + 1
                    wTabs[idx] = { id = idx, bagID = bagID, name = "Tab " .. idx, slots = slots }
                end
            end
        end
        if #wsnap > 0 or (wTabs and #wTabs > 0) then
            local prevWb = DB().vault.warbandBank
            local nextItems
            if #wsnap > 0 or (S.atBank and wTabs and #wTabs > 0) then
                nextItems = wsnap
            else
                nextItems = (prevWb and prevWb.items) or {}
            end
            DB().vault.warbandBank = {
                items = nextItems,
                tabs = (wTabs and #wTabs > 0 and wTabs) or (prevWb and prevWb.tabs) or nil,
                updated = time and time() or 0,
            }
        end
    end
    S.vaultVersion = S.vaultVersion + 1
end

function U.GetVaultStateSignature(mode)
    mode = mode or S.companionMode or "BANK"
    local db = DB()
    local tuples, tabs = {}, {}
    if mode == "WARBAND" then
        local wb = db.vault and db.vault.warbandBank
        tuples = (wb and wb.items) or {}
        tabs = (wb and wb.tabs) or {}
    elseif mode == "GUILD" then
        local gb = db.vault and db.vault.guildBank
        tuples = (gb and gb.items) or {}
        tabs = (gb and gb.tabNames) or {}
    else
        local key = S.view.char or CharKey()
        local rec = db.vault and db.vault.characters and db.vault.characters[key]
        tuples = (rec and rec.bank) or {}
        tabs = (rec and rec.bankTabs) or {}
    end
    local parts = { tostring(mode), tostring(#tabs), tostring(#tuples) }
    for i = 1, #tabs do
        local tm = tabs[i]
        if type(tm) == "table" then
            parts[#parts + 1] = table.concat({
                tostring(tm.id or tm.bagID or i),
                tostring(tm.name or ""),
                tostring(tm.icon or ""),
                tostring(tm.isViewable ~= false),
                tostring(tm.canDeposit ~= false),
                tostring(tm.numWithdrawals or ""),
                tostring(tm.remainingWithdrawals or ""),
                tostring(tm.canWithdraw ~= false),
            }, "/")
        end
    end
    parts[#parts + 1] = "||"
    for i = 1, #tuples do
        local t = tuples[i]
        if type(t) == "table" then
            parts[#parts + 1] = sformat("%s:%s:%s:%s:%s:%s:%s:%s",
                tostring(t.bag or t.tab or 0),
                tostring(t.slot or 0),
                tostring(t[1] or 0),
                tostring(t[3] or 1),
                tostring(t[4] or 0),
                tostring(t[5] or 0),
                tostring(t.binding or ""),
                tostring(t.uncached and 1 or 0))
        end
    end
    return table.concat(parts, "|")
end

function U.EnsureFastBankSeed(mode)
    local db = DB()
    if mode == "WARBAND" then
        local wb = db.vault and db.vault.warbandBank
        if not (wb and type(wb.items) == "table" and #wb.items > 0) then
            pcall(U.SnapshotBank, true)
        end
    elseif mode == "BANK" then
        local rec = U.GetCharRecord()
        if not (rec and type(rec.bank) == "table" and #rec.bank > 0) then
            pcall(U.SnapshotBank, true)
        end
    end
end

function U.ScheduleSnapshot()
    if S.snapshotTimer then return end
    if C_Timer and C_Timer.NewTimer then
        S.snapshotTimer = C_Timer.NewTimer(3, function()
            S.snapshotTimer = nil
            pcall(U.SnapshotBags)
            if S.atBank then pcall(U.SnapshotBank) end
        end)
    end
end

function U.GetCharList()
    local list = {}
    local cur = CharKey()
    for key, rec in pairs(DB().vault.characters) do
        if key ~= cur then
            list[#list + 1] = { key = key, rec = rec }
        end
    end
    tsort(list, function(a, b) return a.key < b.key end)
    return list
end

function U.ClearAltCache()
    local db = DB()
    local cur = CharKey()
    local keep = db.vault.characters[cur]
    db.vault.characters = {}
    if keep then db.vault.characters[cur] = keep end
    db.vault.warbandBank = nil
    S.vaultVersion = S.vaultVersion + 1
    S.countIndex = nil
    if S.view.char or S.view.mode ~= "BAGS" then U.SetView(nil, "BAGS") end
end

function U.BuildCountIndex()
    local idx = {}
    local cur = CharKey()
    local function add(itemID, ck, where, n)
        if type(itemID) ~= "number" then return end
        local e = idx[itemID]
        if not e then e = { chars = {}, warband = 0 }; idx[itemID] = e end
        if ck then
            local c = e.chars[ck]
            if not c then c = { bags = 0, bank = 0 }; e.chars[ck] = c end
            c[where] = c[where] + (n or 1)
        else
            e.warband = e.warband + (n or 1)
        end
    end
    local vault = DB().vault
    for ck, rec in pairs(vault.characters) do
        if ck ~= cur then
            for _, t in ipairs(rec.bags or {}) do add(t[1], ck, "bags", t[3]) end
            for _, t in ipairs(rec.bank or {}) do add(t[1], ck, "bank", t[3]) end
        end
    end
    if vault.warbandBank and vault.warbandBank.items then
        for _, t in ipairs(vault.warbandBank.items) do add(t[1], nil, nil, t[3]) end
    end
    S.countIndex = idx
    S.countIndexVersion = S.vaultVersion
end

function U.AppendCountsToTooltip(tooltip, itemID)
    if not S.countIndex or S.countIndexVersion ~= S.vaultVersion then U.BuildCountIndex() end
    local e = S.countIndex[itemID]
    if not e then return end
    local lines = {}
    local vault = DB().vault
    for ck, c in pairs(e.chars) do
        local rec = vault.characters[ck]
        local nm = (rec and rec.name) or ck
        local color = rec and rec.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[rec.class]
        local hex = (color and color.colorStr) or "ffffffff"
        lines[#lines + 1] = { nm, sformat("|c%s%s|r", hex, nm), c.bags, c.bank }
    end
    tsort(lines, function(a, b) return a[1] < b[1] end)
    if #lines == 0 and e.warband == 0 then return end
    tooltip:AddLine(" ")
    tooltip:AddLine("|cFFFF7C0ADynamic|r|cFFFFFFFFBags|r", 1, 1, 1)
    for i, l in ipairs(lines) do
        if i > 6 then
            tooltip:AddLine(sformat("|cFF94A3B8+%d more characters|r", #lines - 6))
            break
        end
        tooltip:AddDoubleLine(l[2], sformat("Bags %d  Bank %d", l[3], l[4]), 1, 1, 1, 0.78, 0.82, 0.88)
    end
    if e.warband > 0 then
        tooltip:AddDoubleLine("Warband Bank", tostring(e.warband), 0.40, 0.80, 1.0, 0.78, 0.82, 0.88)
    end
end

function U.InstallTooltipHook()
    if S.tooltipHooked then return end
    if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType) then return end
    S.tooltipHooked = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if InCombatLockdown() or tooltip ~= GameTooltip then return end
        local id = type(data) == "table" and data.id
        if type(id) == "number" and not IsSecret(id) and DB().tooltipCounts then
            pcall(U.AppendCountsToTooltip, tooltip, id)
        end
        local okOwn, owner = pcall(tooltip.GetOwner, tooltip)
        if okOwn and owner and not IsSecret(owner) and owner.dbBag and owner.dbSlot and owner.dbObj and not owner.dbObj.empty then
            local ar, ag, ab = GetAccent()
            local accHex = sformat("%02X%02X%02X", floor(ar * 255 + 0.5), floor(ag * 255 + 0.5), floor(ab * 255 + 0.5))
            local pinnedCats = DB().pinnedCategories
            local pinned = pinnedCats and pinnedCats[owner.dbObj.itemID]
            local pinTxt = pinned
                and ("|cFF" .. accHex .. "Pinned:|r |cFFE2E8F0" .. (CAT_LABEL[pinned] or pinned) .. "|r  (|cFF" .. accHex .. "Alt + Right-Click:|r |cFFE2E8F0Change Category|r)")
                or ("|cFF" .. accHex .. "Alt + Right-Click:|r |cFFE2E8F0Pin to Category|r")
            pcall(tooltip.AddLine, tooltip, pinTxt, 0.886, 0.910, 0.941)
        end
    end)
end

-- ============================================================================
-- 5. OBSIDIAN UI PRIMITIVES
-- ============================================================================

U.styled = setmetatable({}, { __mode = "k" })

local COL = {
    bevel      = { 0.043, 0.051, 0.071, 0.98 },
    bevelEdge  = { 1, 1, 1, 0.08 },
    cell       = { 0.078, 0.090, 0.122, 0.96 },
    cellEdge   = { 0.145, 0.165, 0.212, 0.95 },
    cellText   = { 0.68, 0.74, 0.82, 1 },
    cardEdge   = { 0.145, 0.165, 0.212, 1.00 },
    panel      = { 0.045, 0.052, 0.068, 0.98 },
    slate      = { 0.38, 0.45, 0.56, 0.85 },
}

function U.IsNegativePillOption(val, label)
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

function U.GetPillTierUnderlineColor(val, label)
    local lbl = tostring(label or ""):upper():gsub("^|C%x%x%x%x%x%x%x%x", ""):gsub("|R", "")
    -- Tier 0: Off / Disabled / None (Slate-Charcoal pill + Coral-Rose bar #F87171)
    if U.IsNegativePillOption(val, lbl) then
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

function U.StyleButtonState(b)
    local ar, ag, ab = GetAccent()
    if b.selected then
        local tr, tg, tb, ta, isNeg = nil, nil, nil, nil, false
        if b.isPillOption then
            tr, tg, tb, ta, isNeg = U.GetPillTierUnderlineColor(b.optValue, b.optLabel or (b.label and b.label:GetText()))
        end
        if isNeg or b.isNegativeOpt then
            if b.offBar then
                b.offBar:SetColorTexture(tr or 0.973, tg or 0.443, tb or 0.443, ta or 0.90)
                b.offBar:Show()
            end
            b:SetBackdropColor(b.hover and 0.141 or 0.118, b.hover and 0.169 or 0.141, b.hover and 0.224 or 0.188, 0.98)
            b:SetBackdropBorderColor(0.392, 0.455, 0.545, 0.90)
            b.label:SetTextColor(0.886, 0.910, 0.941, 1.0)
            if b.iconTex then b.iconTex:SetVertexColor(0.886, 0.910, 0.941, 1.0) end
        else
            if b.offBar then
                if tr then
                    b.offBar:SetColorTexture(tr, tg, tb, ta)
                    b.offBar:Show()
                else
                    b.offBar:Hide()
                end
            end
            local fa = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42
            b:SetBackdropColor(ar * fa, ag * fa, ab * fa, 0.98)
            b:SetBackdropBorderColor(ar, ag, ab, 0.95)
            b.label:SetTextColor(1, 1, 1, 1)
            if b.iconTex then b.iconTex:SetVertexColor(1, 1, 1, 1) end
        end
        if b.chevronTex then b.chevronTex:SetVertexColor(1, 1, 1, 1) end
    elseif b.hover then
        if b.offBar then b.offBar:Hide() end
        b:SetBackdropColor(COL.cell[1] + 0.03, COL.cell[2] + 0.03, COL.cell[3] + 0.04, 0.98)
        b:SetBackdropBorderColor(ar, ag, ab, 0.70)
        b.label:SetTextColor(0.92, 0.95, 0.99, 1)
        if b.iconTex then b.iconTex:SetVertexColor(1, 1, 1, 1) end
        if b.chevronTex then b.chevronTex:SetVertexColor(ar, ag, ab, 1) end
    else
        if b.offBar then b.offBar:Hide() end
        b:SetBackdropColor(COL.cell[1], COL.cell[2], COL.cell[3], COL.cell[4])
        b:SetBackdropBorderColor(COL.cellEdge[1], COL.cellEdge[2], COL.cellEdge[3], COL.cellEdge[4])
        b.label:SetTextColor(COL.cellText[1], COL.cellText[2], COL.cellText[3], 1)
        if b.iconTex then b.iconTex:SetVertexColor(0.72, 0.78, 0.86, 0.95) end
        if b.chevronTex then b.chevronTex:SetVertexColor(ar, ag, ab, 0.90) end
    end
end

function U.AttachDropdownChevron(b)
    local ch = b:CreateTexture(nil, "ARTWORK")
    ch:SetSize(12, 12)
    ch:SetPoint("RIGHT", b, "RIGHT", -8, 0)
    ch:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga")
    if ch.SetSnapToPixelGrid then ch:SetSnapToPixelGrid(false); ch:SetTexelSnappingBias(0) end
    b.chevronTex = ch
    b.label:ClearAllPoints()
    b.label:SetPoint("LEFT", b, "LEFT", 8, 0)
    b.label:SetPoint("RIGHT", ch, "LEFT", -4, 0)
    b.label:SetJustifyH("CENTER")
    U.StyleButtonState(b)
    return b
end

function U.NewIconButton(parent, w, h, texPath, tooltipTitle, tooltipBody, shortText)
    local b = U.NewButton(parent, w or 26, h or 24, shortText or "")
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetSize(13, 13)
    ic:SetTexture(texPath)
    if ic.SetSnapToPixelGrid then ic:SetSnapToPixelGrid(false); ic:SetTexelSnappingBias(0) end
    b.iconTex = ic
    if shortText and shortText ~= "" then
        ic:SetPoint("LEFT", b, "LEFT", 7, 0)
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT", ic, "RIGHT", 4, 0)
        b.label:SetPoint("RIGHT", b, "RIGHT", -5, 0)
        b.label:SetJustifyH("CENTER")
        b.label:Show()
    else
        b.label:Hide()
        ic:SetPoint("CENTER", b, "CENTER", 0, 0)
    end
    U.StyleButtonState(b)
    b:HookScript("OnEnter", function(self)
        if tooltipTitle then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(tooltipTitle, 1, 1, 1)
            if tooltipBody then GameTooltip:AddLine(tooltipBody, 0.80, 0.84, 0.90, true) end
            GameTooltip:Show()
        end
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

function U.NewButton(parent, w, h, text)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    b.label = b:CreateFontString(nil, "OVERLAY")
    SetFont(b.label, 11)
    b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
    b.label:SetPoint("RIGHT", b, "RIGHT", -6, 0)
    b.label:SetJustifyH("CENTER")
    b.label:SetWordWrap(false)
    b.label:SetText(text or "")
    b.offBar = b:CreateTexture(nil, "OVERLAY")
    b.offBar:SetHeight(1.5)
    b.offBar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 1)
    b.offBar:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.offBar:SetColorTexture(0.973, 0.443, 0.443, 0.90)
    b.offBar:Hide()
    b.OffBar = b.offBar
    b.TierBar = b.offBar
    b.selected, b.hover = false, false
    function b:SetSelected(v) self.selected = v and true or false; U.StyleButtonState(self) end
    function b:SetLabel(t) self.label:SetText(t or "") end
    b:SetScript("OnEnter", function(self) self.hover = true; U.StyleButtonState(self) end)
    b:SetScript("OnLeave", function(self) self.hover = false; U.StyleButtonState(self) end)
    U.styled[b] = true
    U.StyleButtonState(b)
    return b
end

function U.RefreshStyledButtons()
    for b in pairs(U.styled) do
        if b.label then U.StyleButtonState(b) end
    end
end

-- ---- Popup menu (used by dropdowns and the Alt+Right-Click pin menu) --------

function U.CloseMenu()
    if S.menuAnchor and S.menuAnchor.chevronTex then
        S.menuAnchor.chevronTex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga")
    end
    S.menuAnchor = nil
    if S.menu then
        if S.menu.searchBox then S.menu.searchBox:ClearFocus() end
        if S.menu:IsShown() then S.menu:Hide() end
    end
    if S.menuCatcher and S.menuCatcher:IsShown() then S.menuCatcher:Hide() end
end

local function RegisterBagsPopupCloser()
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.RegisterPopupCloser) == "function" then
        pcall(_G.DynamicSuite.UI.RegisterPopupCloser, "DynamicBags", U.CloseMenu)
    end
end
RegisterBagsPopupCloser()

function U.ShowMenu(anchor, entries, minWidth)
    RegisterBagsPopupCloser()
    if S.menu and S.menu:IsShown() and S.menuAnchor == anchor then
        U.CloseMenu()
        return
    end
    U.CloseMenu()
    if anchor and anchor.HookScript and not anchor._dbagMenuOnHideHooked then
        anchor._dbagMenuOnHideHooked = true
        anchor:HookScript("OnHide", function(self)
            if S.menuAnchor == self then
                U.CloseMenu()
            end
        end)
    end
    if not S.menuCatcher then
        local c = CreateFrame("Button", nil, UIParent)
        c:SetFrameStrata("FULLSCREEN_DIALOG")
        c:SetFrameLevel(90)
        c:SetAllPoints(UIParent)
        c:RegisterForClicks("AnyUp")
        c:SetScript("OnClick", function() U.CloseMenu() end)
        c:Hide()
        S.menuCatcher = c
    end
    if not S.menu then
        local m = CreateFrame("Frame", "DynamicBagsDropdownMenu", UIParent, "BackdropTemplate")
        m:SetFrameStrata("TOOLTIP")
        m:SetFrameLevel(220)
        m:SetToplevel(true)
        m:SetClampedToScreen(true)
        m:EnableMouse(true)
        m.rows = {}
        m.measure = m:CreateFontString(nil, "OVERLAY")
        m.measure:Hide()

        local searchWrap = CreateFrame("Frame", nil, m, "BackdropTemplate")
        searchWrap:SetFrameLevel(225)
        searchWrap:SetHeight(24)
        searchWrap:SetPoint("TOPLEFT", m, "TOPLEFT", 6, -5)
        searchWrap:SetPoint("TOPRIGHT", m, "TOPRIGHT", -6, -5)
        Backdrop(searchWrap, 0.035, 0.042, 0.060, 0.98, 0.16, 0.19, 0.25, 0.90)
        m.searchWrap = searchWrap

        local sb = CreateFrame("EditBox", nil, searchWrap)
        sb:SetFrameLevel(226)
        sb:SetPoint("TOPLEFT", searchWrap, "TOPLEFT", 8, -2)
        sb:SetPoint("BOTTOMRIGHT", searchWrap, "BOTTOMRIGHT", -24, 2)
        sb:SetAutoFocus(false)
        sb:SetMaxLetters(64)
        SetFont(sb, 10.5)
        sb:SetTextColor(0.95, 0.97, 1.0, 1.0)
        sb:SetScript("OnEscapePressed", function() U.CloseMenu() end)
        m.searchBox = sb

        local ph = searchWrap:CreateFontString(nil, "OVERLAY")
        ph:SetPoint("LEFT", sb, "LEFT", 0, 0)
        SetFont(ph, 10.5)
        ph:SetTextColor(0.48, 0.54, 0.64, 0.90)
        ph:SetText("Search...")
        m.searchPlaceholder = ph

        local clrBtn = CreateFrame("Button", nil, searchWrap)
        clrBtn:SetSize(18, 18)
        clrBtn:SetPoint("RIGHT", searchWrap, "RIGHT", -3, 0)
        clrBtn:SetFrameLevel(227)
        local clrTxt = clrBtn:CreateFontString(nil, "OVERLAY")
        clrTxt:SetPoint("CENTER", 0, 0)
        SetFont(clrTxt, 9.5)
        clrTxt:SetTextColor(0.62, 0.68, 0.78, 0.95)
        clrTxt:SetText("X")
        clrBtn.txt = clrTxt
        clrBtn:Hide()
        clrBtn:SetScript("OnEnter", function(cb)
            local r2, g2, b2 = GetAccent()
            cb.txt:SetTextColor(r2, g2, b2, 1.0)
        end)
        clrBtn:SetScript("OnLeave", function(cb)
            cb.txt:SetTextColor(0.62, 0.68, 0.78, 0.95)
        end)
        clrBtn:SetScript("OnClick", function()
            sb:SetText("")
            sb:ClearFocus()
        end)
        m.searchClear = clrBtn

        local sf = CreateFrame("ScrollFrame", nil, m)
        sf:SetFrameLevel(222)
        sf:SetClipsChildren(true)
        sf:EnableMouseWheel(true)
        m.scrollFrame = sf

        local sc = CreateFrame("Frame", nil, sf)
        sc:SetFrameLevel(223)
        sc:SetSize(200, 100)
        sf:SetScrollChild(sc)
        m.scrollChild = sc

        local sbTrack = CreateFrame("Frame", nil, m, "BackdropTemplate")
        sbTrack:SetFrameLevel(224)
        sbTrack:SetWidth(4)
        sbTrack:EnableMouse(true)
        sbTrack:SetBackdrop({ bgFile = WHITE })
        sbTrack:SetBackdropColor(1, 1, 1, 0.06)
        m.sbTrack = sbTrack

        local sbThumb = CreateFrame("Button", nil, sbTrack, "BackdropTemplate")
        sbThumb:SetFrameLevel(225)
        sbThumb:SetWidth(4)
        sbThumb:SetHeight(32)
        sbThumb:SetPoint("TOP", sbTrack, "TOP", 0, 0)
        sbThumb:EnableMouse(true)
        sbThumb:SetBackdrop({ bgFile = WHITE })
        sbThumb:SetBackdropColor(0.38, 0.45, 0.56, 0.85)
        m.sbThumb = sbThumb

        local borderOverlay = CreateFrame("Frame", nil, m, "BackdropTemplate")
        borderOverlay:SetAllPoints(m)
        borderOverlay:SetFrameLevel(230)
        borderOverlay:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
        m.borderOverlay = borderOverlay

        local function RefreshMenuThumbColor()
            if sbThumb.isDragging then
                local r2, g2, b2 = GetAccent()
                sbThumb:SetBackdropColor(r2, g2, b2, 0.95)
            elseif sbThumb:IsMouseOver() then
                sbThumb:SetBackdropColor(0.52, 0.60, 0.72, 0.95)
            else
                sbThumb:SetBackdropColor(0.38, 0.45, 0.56, 0.85)
            end
        end

        local function UpdateMenuThumb()
            local maxS = max(0, (sc:GetHeight() or 0) - (sf:GetHeight() or 0))
            if maxS <= 1 then
                sbTrack:Hide()
                sf:SetVerticalScroll(0)
                return
            end
            sbTrack:Show()
            local trackH = max(20, sbTrack:GetHeight() or 180)
            local ratio = min(1, (sf:GetHeight() or 1) / max(1, sc:GetHeight() or 1))
            local thumbH = max(24, floor(trackH * ratio))
            sbThumb:SetHeight(thumbH)
            local cur = min(maxS, max(0, sf:GetVerticalScroll() or 0))
            local travel = max(1, trackH - thumbH)
            sbThumb:ClearAllPoints()
            sbThumb:SetPoint("TOP", sbTrack, "TOP", 0, -(cur / maxS) * travel)
            RefreshMenuThumbColor()
        end
        m.UpdateMenuThumb = UpdateMenuThumb

        sf:SetScript("OnMouseWheel", function(self, delta)
            local maxS = max(0, (sc:GetHeight() or 0) - (self:GetHeight() or 0))
            local nextS = min(maxS, max(0, (self:GetVerticalScroll() or 0) - delta * 26))
            self:SetVerticalScroll(nextS)
            UpdateMenuThumb()
        end)

        sbTrack:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" then return end
            local maxS = max(0, (sc:GetHeight() or 0) - (sf:GetHeight() or 0))
            if maxS <= 0 then return end
            local scale = self:GetEffectiveScale() or 1
            local _, cy = GetCursorPosition()
            cy = cy / scale
            local top, bottom = self:GetTop(), self:GetBottom()
            if top and bottom and top > bottom then
                local trackH = top - bottom
                local thumbH = sbThumb:GetHeight() or 24
                local travel = max(1, trackH - thumbH)
                local ratio = max(0, min(1, ((top - cy) - (thumbH * 0.5)) / travel))
                sf:SetVerticalScroll(ratio * maxS)
                UpdateMenuThumb()
            end
        end)

        sbThumb:SetScript("OnEnter", function() RefreshMenuThumbColor() end)
        sbThumb:SetScript("OnLeave", function() RefreshMenuThumbColor() end)
        sbThumb:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" then return end
            self.isDragging = true
            RefreshMenuThumbColor()
            local startY = select(2, GetCursorPosition()) / (self:GetEffectiveScale() or 1)
            local startScroll = sf:GetVerticalScroll() or 0
            self:SetScript("OnUpdate", function()
                if not IsMouseButtonDown("LeftButton") then
                    self.isDragging = false
                    self:SetScript("OnUpdate", nil)
                    RefreshMenuThumbColor()
                    return
                end
                local curY = select(2, GetCursorPosition()) / (self:GetEffectiveScale() or 1)
                local maxS = max(0, (sc:GetHeight() or 0) - (sf:GetHeight() or 0))
                local trackH = max(20, sbTrack:GetHeight() or 180)
                local travel = max(1, trackH - (self:GetHeight() or 24))
                sf:SetVerticalScroll(min(maxS, max(0, startScroll + ((startY - curY) / travel) * maxS)))
                UpdateMenuThumb()
            end)
        end)
        sbThumb:SetScript("OnMouseUp", function(self)
            self.isDragging = false
            self:SetScript("OnUpdate", nil)
            RefreshMenuThumbColor()
        end)
        sbThumb:SetScript("OnHide", function(self)
            self.isDragging = false
            self:SetScript("OnUpdate", nil)
            RefreshMenuThumbColor()
        end)

        m:SetScript("OnHide", function(self)
            if self.searchBox then self.searchBox:ClearFocus() end
            if S.menuAnchor and S.menuAnchor.chevronTex then
                S.menuAnchor.chevronTex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga")
            end
            S.menuAnchor = nil
            if S.menuCatcher and S.menuCatcher:IsShown() then
                S.menuCatcher:Hide()
            end
        end)
        S.menu = m
    end
    if not InCombatLockdown() and type(UISpecialFrames) == "table" and not S.menu._specialRegistered then
        S.menu._specialRegistered = true
        local found = false
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == "DynamicBagsDropdownMenu" then found = true; break end
        end
        if not found then tinsert(UISpecialFrames, "DynamicBagsDropdownMenu") end
    end
    local m = S.menu
    local ar, ag, ab = GetAccent()
    Backdrop(m, 0.043, 0.051, 0.071, 0.99, ar, ag, ab, 0.90)
    if m.borderOverlay then
        m.borderOverlay:SetFrameLevel(230)
        m.borderOverlay:SetBackdropBorderColor(ar, ag, ab, 0.90)
    end
    if m.searchWrap then
        m.searchWrap:SetBackdropBorderColor(ar, ag, ab, 0.35)
    end
    SetFont(m.measure, 11)
    local widest = 0
    for _, en in ipairs(entries) do
        m.measure:SetText(en.label or "")
        widest = max(widest, m.measure:GetStringWidth() or 0)
    end
    local showSearch = (#entries > 12)
    local searchAreaH = showSearch and 28 or 0
    m.searchWrap:SetShown(showSearch)
    local width = max(minWidth or 140, ceil(widest) + 46, showSearch and 220 or 140)
    local rowH, pad = 24, 4
    local maxVisH = 264

    local function RenderMenuRows(query)
        local qLower = tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if m.searchPlaceholder then
            m.searchPlaceholder:SetShown(qLower == "" and not m.searchBox:HasFocus())
        end
        if m.searchClear then
            m.searchClear:SetShown(qLower ~= "")
        end
        local filtered = {}
        if qLower == "" then
            filtered = entries
        else
            for _, en in ipairs(entries) do
                local cleanL = tostring(en.label or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                if cleanL:lower():find(qLower, 1, true) then
                    filtered[#filtered + 1] = en
                end
            end
            if #filtered == 0 then
                filtered[1] = { label = "No matching options", isEmptyNotice = true }
            end
        end

        for _, r in ipairs(m.rows) do r:Hide() end
        for i, en in ipairs(filtered) do
            local row = m.rows[i]
            if not row then
                row = CreateFrame("Button", nil, m.scrollChild)
                row:SetFrameLevel(225)
                row:SetHeight(rowH)
                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints()
                row.bg:SetColorTexture(1, 1, 1, 0)
                row.mark = row:CreateTexture(nil, "ARTWORK")
                row.mark:SetSize(6, 6)
                row.mark:SetPoint("LEFT", row, "LEFT", 10, 0)
                row.text = row:CreateFontString(nil, "OVERLAY")
                row.text:SetPoint("LEFT", row, "LEFT", 26, 0)
                row.text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                row.text:SetJustifyH("LEFT")
                row.text:SetWordWrap(false)
                m.rows[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", m.scrollChild, "TOPLEFT", 0, -((i - 1) * rowH))
            row:SetPoint("TOPRIGHT", m.scrollChild, "TOPRIGHT", 0, -((i - 1) * rowH))
            SetFont(row.text, 11)
            row.text:SetText(en.label or "")
            if en.isEmptyNotice then
                row:Disable()
                row.mark:Hide()
                row.bg:SetColorTexture(1, 1, 1, 0)
                row.text:SetTextColor(0.55, 0.60, 0.70, 0.90)
                row:SetScript("OnEnter", nil)
                row:SetScript("OnLeave", nil)
                row:SetScript("OnClick", nil)
            else
                row:Enable()
                if en.checked then
                    row.mark:SetColorTexture(ar, ag, ab, 1)
                    row.mark:Show()
                    row.text:SetTextColor(ar, ag, ab, 1)
                elseif en.color then
                    row.mark:Hide()
                    row.text:SetTextColor(en.color[1], en.color[2], en.color[3], 1)
                else
                    row.mark:Hide()
                    row.text:SetTextColor(0.90, 0.93, 0.97, 1)
                end
                row:SetScript("OnEnter", function(self)
                    local r2, g2, b2 = GetAccent()
                    self.bg:SetColorTexture(r2, g2, b2, 0.16)
                end)
                row:SetScript("OnLeave", function(self) self.bg:SetColorTexture(1, 1, 1, 0) end)
                row:SetScript("OnClick", function()
                    if not en.keepOpen then U.CloseMenu() end
                    if en.onClick then en.onClick() end
                end)
            end
            row:Show()
        end

        local totalH = max(rowH, #filtered * rowH)
        local viewH = min(totalH, maxVisH)
        local hasScroll = (totalH > viewH + 1)
        local topOff = pad + searchAreaH
        m:SetSize(width, topOff + viewH + pad)
        m.scrollFrame:ClearAllPoints()
        m.scrollFrame:SetPoint("TOPLEFT", m, "TOPLEFT", pad, -topOff)
        m.scrollFrame:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", hasScroll and -10 or -pad, pad)
        m.scrollChild:SetSize(width - (hasScroll and (pad + 10) or (pad * 2)), totalH)
        m.scrollFrame:SetVerticalScroll(0)
        m.sbTrack:ClearAllPoints()
        m.sbTrack:SetPoint("TOPRIGHT", m, "TOPRIGHT", -3, -topOff)
        m.sbTrack:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -3, pad)
        m.UpdateMenuThumb()
    end

    m.searchBox:SetScript("OnTextChanged", function(sbEdit)
        if m:IsShown() and S.menuAnchor == anchor then
            RenderMenuRows(sbEdit:GetText())
        end
    end)
    m.searchBox:SetScript("OnEditFocusGained", function()
        if m.searchPlaceholder then m.searchPlaceholder:Hide() end
    end)
    m.searchBox:SetScript("OnEditFocusLost", function(sbEdit)
        if m.searchPlaceholder then
            m.searchPlaceholder:SetShown((sbEdit:GetText() or "") == "")
        end
    end)
    m.searchBox:SetText("")
    m.searchBox:ClearFocus()
    RenderMenuRows("")

    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    m:SetClampedToScreen(true)
    S.menuAnchor = anchor
    if anchor and anchor.chevronTex then
        anchor.chevronTex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga")
    end
    S.menuCatcher:Show()
    m:Show()
end

-- ---- 4px slate-grey scroll area (Design\GEOMETRY_STANDARD.md) --------------

function U.CreateScrollArea(parent)
    local holder = CreateFrame("Frame", nil, parent)

    local scroll = CreateFrame("ScrollFrame", nil, holder)
    scroll:SetAllPoints(holder)
    holder._dbagForwardScroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(600, 400)
    scroll:SetScrollChild(content)

    local track = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    track:SetWidth(4)
    track:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 10, -2)
    track:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 10, 2)
    track:EnableMouse(true)
    track:SetBackdrop({ bgFile = WHITE })
    track:SetBackdropColor(1, 1, 1, 0.05)

    local thumb = CreateFrame("Button", nil, track, "BackdropTemplate")
    thumb:SetWidth(4)
    thumb:SetHeight(48)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    thumb:EnableMouse(true)
    thumb:SetBackdrop({ bgFile = WHITE })
    thumb:SetBackdropColor(COL.slate[1], COL.slate[2], COL.slate[3], COL.slate[4])

    local function RefreshThumbColor()
        if thumb.isDragging then
            local ar, ag, ab = GetAccent()
            thumb:SetBackdropColor(ar, ag, ab, 0.95)
        elseif thumb:IsMouseOver() then
            thumb:SetBackdropColor(0.52, 0.60, 0.72, 0.95)
        else
            thumb:SetBackdropColor(COL.slate[1], COL.slate[2], COL.slate[3], COL.slate[4])
        end
    end

    local function MaxScroll()
        return max(0, (content:GetHeight() or 0) - (scroll:GetHeight() or 0))
    end

    local function UpdateThumb()
        local maxS = MaxScroll()
        if maxS <= 1 then
            track:Hide()
            scroll:SetVerticalScroll(0)
            return
        end
        track:Show()
        local trackH = max(20, track:GetHeight() or 200)
        local ratio = min(1, (scroll:GetHeight() or 1) / max(1, content:GetHeight() or 1))
        local thumbH = max(28, floor(trackH * ratio))
        thumb:SetHeight(thumbH)
        local cur = min(maxS, max(0, scroll:GetVerticalScroll() or 0))
        local travel = max(1, trackH - thumbH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -(cur / maxS) * travel)
        RefreshThumbColor()
    end

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        if self._dbagScaleTarget and IsControlKeyDown and IsControlKeyDown() and IsShiftKeyDown and IsShiftKeyDown() then
            if U.StepBagOrBankScale then
                U.StepBagOrBankScale(self._dbagScaleTarget, delta, true)
            end
            return
        end
        U.CloseMenu()
        local nextS = min(MaxScroll(), max(0, (self:GetVerticalScroll() or 0) - delta * 40))
        self:SetVerticalScroll(nextS)
        UpdateThumb()
    end)

    track:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        U.CloseMenu()
        local maxS = MaxScroll()
        if maxS <= 0 then return end
        local scale = self:GetEffectiveScale() or 1
        local _, cy = GetCursorPosition()
        cy = cy / scale
        local top, bottom = self:GetTop(), self:GetBottom()
        if top and bottom and top > bottom then
            local trackH = top - bottom
            local thumbH = thumb:GetHeight() or 28
            local travel = max(1, trackH - thumbH)
            local ratio = max(0, min(1, ((top - cy) - (thumbH * 0.5)) / travel))
            scroll:SetVerticalScroll(ratio * maxS)
            UpdateThumb()
        end
    end)

    thumb:SetScript("OnEnter", function() RefreshThumbColor() end)
    thumb:SetScript("OnLeave", function() RefreshThumbColor() end)
    thumb:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        U.CloseMenu()
        self.isDragging = true
        RefreshThumbColor()
        local startY = select(2, GetCursorPosition()) / (self:GetEffectiveScale() or 1)
        local startScroll = scroll:GetVerticalScroll() or 0
        self:SetScript("OnUpdate", function()
            if not IsMouseButtonDown("LeftButton") then
                self.isDragging = false
                self:SetScript("OnUpdate", nil)
                RefreshThumbColor()
                return
            end
            local curY = select(2, GetCursorPosition()) / (self:GetEffectiveScale() or 1)
            local maxS = MaxScroll()
            local trackH = max(20, track:GetHeight() or 200)
            local travel = max(1, trackH - (self:GetHeight() or 28))
            scroll:SetVerticalScroll(min(maxS, max(0, startScroll + ((startY - curY) / travel) * maxS)))
            UpdateThumb()
        end)
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

    scroll:SetScript("OnSizeChanged", function(_, w)
        if w and w > 40 then content:SetWidth(w) end
        if holder.onWidth then holder.onWidth(w) end
        UpdateThumb()
    end)

    holder.scroll, holder.content, holder.track, holder.thumb = scroll, content, track, thumb
    holder.UpdateThumb = UpdateThumb
    function holder:ScrollToTop() scroll:SetVerticalScroll(0); UpdateThumb() end
    return holder
end

-- ============================================================================
-- 6. SECURE ITEM BUTTON POOL & ITEM VISUALS
-- ============================================================================

local function MakeEdges(parent, thickness)
    local edges = { tex = {} }
    local top = parent:CreateTexture(nil, "OVERLAY", nil, 2)
    top:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    top:SetHeight(thickness)
    local bottom = parent:CreateTexture(nil, "OVERLAY", nil, 2)
    bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(thickness)
    local left = parent:CreateTexture(nil, "OVERLAY", nil, 2)
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    left:SetWidth(thickness)
    local right = parent:CreateTexture(nil, "OVERLAY", nil, 2)
    right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(thickness)
    edges.tex = { top, bottom, left, right }
    function edges:SetColor(cr, cg, cb, ca)
        for _, t in ipairs(self.tex) do t:SetColorTexture(cr, cg, cb, ca) end
    end
    edges:SetColor(0, 0, 0, 0)
    return edges
end

function U.BuildOverlay(btn)
    local ov = CreateFrame("Frame", nil, btn)
    ov:SetAllPoints(btn)
    ov:EnableMouse(false)
    ov:SetFrameLevel(btn:GetFrameLevel() + 3)
    btn.dbOverlay = ov

    local bg = btn:CreateTexture(nil, "BACKGROUND", nil, -3)
    bg:SetAllPoints(btn)
    bg:SetColorTexture(0.05, 0.06, 0.08, 0.92)
    btn.dbBg = bg

    local icon = btn.icon or btn.Icon
    if not icon and btn.GetName and btn:GetName() then icon = _G[btn:GetName() .. "IconTexture"] end
    if not icon then
        icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    end
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn.dbIcon = icon
    if btn.Count and btn.Count.Hide then btn.Count:Hide() end
    local function KillBlizzGlow(b)
        -- Strip Blizzard's default rounded grey slot border & background textures so our crisp Obsidian border shines!
        if b.NormalTexture then b.NormalTexture:SetAlpha(0); b.NormalTexture:Hide() end
        if b.GetNormalTexture then
            local nt = b:GetNormalTexture()
            if nt then nt:SetTexture(nil); nt:SetAlpha(0); nt:Hide() end
        end
        if b.GetPushedTexture then
            local pt = b:GetPushedTexture()
            if pt then pt:SetTexture(nil); pt:SetAlpha(0); pt:Hide() end
        end
        if b.IconBorder then b.IconBorder:SetAlpha(0); b.IconBorder:Hide() end
        if b.SlotBackground then b.SlotBackground:SetAlpha(0); b.SlotBackground:Hide() end
        if b.IconQuestTexture then b.IconQuestTexture:SetAlpha(0); b.IconQuestTexture:Hide() end
        if b.NewItemTexture then b.NewItemTexture:SetAlpha(0); b.NewItemTexture:Hide() end
        if b.BattlepayItemTexture then b.BattlepayItemTexture:SetAlpha(0); b.BattlepayItemTexture:Hide() end
        if b.BagIndicator then b.BagIndicator:Hide() end
        if b.flash then b.flash:SetAlpha(0); b.flash:Hide() end
        if b.newitemglowAnim and b.newitemglowAnim.Stop then b.newitemglowAnim:Stop() end
        if b.flashAnim and b.flashAnim.Stop then b.flashAnim:Stop() end
        if b.IconOverlay then b.IconOverlay:SetAlpha(0); b.IconOverlay:Hide() end
        if b.IconOverlay2 then b.IconOverlay2:SetAlpha(0); b.IconOverlay2:Hide() end
        if b.ExtendedSlot then b.ExtendedSlot:Hide() end
    end
    KillBlizzGlow(btn)
    btn.KillBlizzGlow = KillBlizzGlow

    ov.unusable = ov:CreateTexture(nil, "ARTWORK", nil, 1)
    ov.unusable:SetAllPoints(ov)
    ov.unusable:SetColorTexture(1, 0.1, 0.1, 0.28)
    ov.unusable:Hide()

    ov.flash = ov:CreateTexture(nil, "ARTWORK", nil, 2)
    ov.flash:SetAllPoints(ov)
    ov.flash:SetColorTexture(1, 0.95, 0.45, 0.0)
    ov.flashAnim = ov.flash:CreateAnimationGroup()
    ov.flashAnim:SetLooping("BOUNCE")
    local a = ov.flashAnim:CreateAnimation("Alpha")
    a:SetFromAlpha(0.06)
    a:SetToAlpha(0.50)
    a:SetDuration(0.8)

    ov.edges = MakeEdges(ov, 2)

    local function NewFS(point, x, y)
        local fs = ov:CreateFontString(nil, "OVERLAY", nil, 6)
        fs:SetPoint(point, ov, point, x, y)
        SetFont(fs, 11, "OUTLINE")
        fs:SetText("")
        return fs
    end
    ov.count = NewFS("BOTTOMRIGHT", -2, 2)
    ov.ilvl = NewFS("TOPLEFT", 2, -2)
    ov.bind = NewFS("BOTTOMLEFT", 2, 2)
    ov.set = NewFS("BOTTOMLEFT", 2, 2)

    ov.upBg = ov:CreateTexture(nil, "OVERLAY", nil, 5)
    ov.upBg:SetSize(13, 13)
    ov.upBg:SetPoint("TOPRIGHT", ov, "TOPRIGHT", -1, -1)
    ov.upBg:SetColorTexture(0.03, 0.04, 0.06, 0.86)
    ov.upBg:Hide()

    ov.up = ov:CreateTexture(nil, "OVERLAY", nil, 6)
    ov.up:SetSize(11, 11)
    ov.up:SetPoint("CENTER", ov.upBg, "CENTER", 0, 0)
    ov.up:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga")
    if ov.up.SetSnapToPixelGrid then ov.up:SetSnapToPixelGrid(false); ov.up:SetTexelSnappingBias(0) end
    ov.up:SetVertexColor(0.20, 1.0, 0.45, 1.0)
    ov.up:Hide()

    ov.coin = ov:CreateTexture(nil, "OVERLAY", nil, 6)
    ov.coin:SetSize(12, 12)
    ov.coin:SetPoint("TOPRIGHT", ov, "TOPRIGHT", -1, -1)
    ov.coin:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    ov.coin:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    ov.coin:Hide()

    local qb = ov:CreateTexture(nil, "OVERLAY", nil, 6)
    qb:SetSize(13, 13)
    qb:SetPoint("TOPLEFT", ov, "TOPLEFT", 2, -2)
    qb:Hide()
    ov.qualityBadge = qb

    return ov
end

function U.IsUpgrade(e)
    if e.classID ~= IC.Armor and e.classID ~= IC.Weapon then return false end
    if e.upgradeGen == S.equipGen then return e.upgrade end
    e.upgradeGen = S.equipGen
    e.upgrade = false
    if e.bag and e.slot and not e.remote then
        local fn = (C_Container and C_Container.IsContainerItemAnUpgrade) or _G.IsContainerItemAnUpgrade
        if fn then
            local ok, r = pcall(fn, e.bag, e.slot)
            if ok and r then e.upgrade = true end
        end
    end
    return e.upgrade
end

function U.StyleButton(btn, obj)
    local db = DB()
    local ov, icon = btn.dbOverlay, btn.dbIcon
    if not ov or not icon then return end

    local fsz = db.fontSize or 11
    if btn.dbFontSize ~= fsz then
        btn.dbFontSize = fsz
        for _, fs in ipairs({ ov.count, ov.ilvl, ov.bind, ov.set }) do SetFont(fs, fsz, "OUTLINE") end
    end

    if (not obj) or obj.empty then
        icon:SetTexture(nil)
        icon:SetDesaturated(false)
        icon:SetAlpha(1)
        ov.count:SetText((obj and obj.freeTag) or "")
        ov.count:SetTextColor(0.68, 0.74, 0.82, 0.95)
        ov.ilvl:SetText(""); ov.bind:SetText("")
        ov.set:SetText(""); ov.up:Hide(); ov.upBg:Hide()
        if btn.KillBlizzGlow then btn:KillBlizzGlow() end
        ov.coin:Hide(); ov.unusable:Hide()
        ov.qualityBadge:Hide()
        ov.edges:SetColor(0.145, 0.165, 0.212, 0.85)
        ov.flashAnim:Stop(); ov.flash:SetAlpha(0)
        return
    end

    local tex = obj.icon
    if not tex and C_Item and C_Item.GetItemIconByID and obj.itemID then tex = C_Item.GetItemIconByID(obj.itemID) end
    icon:SetTexture(tex)
    icon:SetDesaturated(obj.locked and true or false)
    icon:SetAlpha((db.visual.dimJunk and obj.quality == QUALITY_POOR) and 0.5 or 1)

    ov.count:SetText((obj.count or 1) > 1 and tostring(obj.count) or "")
    ov.count:SetTextColor(1, 1, 1, 1)

    if db.badges.keystone and obj.ksLevel then
        local ar, ag, ab = GetAccent()
        ov.ilvl:SetText("+" .. obj.ksLevel)
        ov.ilvl:SetTextColor(ar, ag, ab, 1)
    elseif db.badges.ilvl and (obj.ilvl or 0) > 1 then
        ov.ilvl:SetText(tostring(obj.ilvl))
        local qr, qg, qb = QualityColor(obj.quality)
        ov.ilvl:SetTextColor(qr, qg, qb, 1)
    else
        ov.ilvl:SetText("")
    end

    local hasSet = (db.badges.eqset and obj.setName ~= nil)
    local hasBind = (db.badges.binding and (obj.binding == "WUE" or obj.binding == "BOE"))
    if hasSet and hasBind then
        ov.set:SetText("EQ")
        ov.set:SetTextColor(1.0, 0.72, 0.22, 1)
        ov.bind:ClearAllPoints()
        ov.bind:SetPoint("BOTTOMLEFT", ov.set, "BOTTOMRIGHT", 2, 0)
        ov.bind:SetText(obj.binding == "WUE" and "WUE" or "BoE")
        if obj.binding == "WUE" then ov.bind:SetTextColor(0.45, 0.80, 1.0, 1) else ov.bind:SetTextColor(0.35, 1.0, 0.55, 1) end
    elseif hasSet then
        ov.set:SetText("EQ")
        ov.set:SetTextColor(1.0, 0.72, 0.22, 1)
        ov.bind:SetText("")
    elseif hasBind then
        ov.set:SetText("")
        ov.bind:ClearAllPoints()
        ov.bind:SetPoint("BOTTOMLEFT", ov, "BOTTOMLEFT", 2, 2)
        if obj.binding == "WUE" then
            ov.bind:SetText("WUE"); ov.bind:SetTextColor(0.45, 0.80, 1.0, 1)
        else
            ov.bind:SetText("BoE"); ov.bind:SetTextColor(0.35, 1.0, 0.55, 1)
        end
    else
        ov.set:SetText("")
        ov.bind:SetText("")
    end

    if db.badges.upgrade and U.IsUpgrade(obj) then
        ov.upBg:Show(); ov.up:Show()
    else
        ov.upBg:Hide(); ov.up:Hide()
    end

    if db.badges.junk and obj.quality == QUALITY_POOR then ov.coin:Show() else ov.coin:Hide() end

    if db.badges.quality and obj.craftQuality and obj.craftQuality > 0 then
        local atlas, tr, tg, tb = U.GetQualityAtlas(obj.craftQuality, obj.craftMaxTiers, obj.craftAtlas)
        local isSet = false
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
            ov.qualityBadge:SetAtlas(atlas, false)
            ov.qualityBadge:SetSize(13, 13)
            ov.qualityBadge:SetVertexColor(1, 1, 1, 1)
            isSet = true
        end
        if not isSet then
            local ok = pcall(function() ov.qualityBadge:SetAtlas(atlas, false) end)
            if not ok then
                ov.qualityBadge:SetTexture("Interface\\Buttons\\WHITE8X8")
            end
            ov.qualityBadge:SetSize(10, 10)
            ov.qualityBadge:SetVertexColor(tr or 1, tg or 1, tb or 1, 0.95)
        end

        local hasTopLeftBadge = false
        if db.badges.keystone and obj.ksLevel then
            hasTopLeftBadge = true
        elseif db.badges.ilvl and (obj.ilvl or 0) > 1 then
            hasTopLeftBadge = true
        end

        ov.qualityBadge:ClearAllPoints()
        if hasTopLeftBadge then
            if hasSet or hasBind then
                if not (db.badges.upgrade and U.IsUpgrade(obj)) and not (db.badges.junk and obj.quality == QUALITY_POOR) then
                    ov.qualityBadge:SetPoint("TOPRIGHT", ov, "TOPRIGHT", -2, -2)
                else
                    ov.qualityBadge:SetPoint("BOTTOMLEFT", ov, "BOTTOMLEFT", 2, 14)
                end
            else
                ov.qualityBadge:SetPoint("BOTTOMLEFT", ov, "BOTTOMLEFT", 2, 2)
            end
        else
            ov.qualityBadge:SetPoint("TOPLEFT", ov, "TOPLEFT", 2, -2)
        end
        ov.qualityBadge:Show()
    else
        ov.qualityBadge:Hide()
    end

    if db.visual.qualityGlow and (obj.quality or 1) >= 2 then
        local qr, qg, qb = QualityColor(obj.quality)
        ov.edges:SetColor(qr, qg, qb, 0.92)
    else
        ov.edges:SetColor(0.145, 0.165, 0.212, 0.90)
    end

    if db.visual.unusableRed and obj.unusable then ov.unusable:Show() else ov.unusable:Hide() end

    if btn.KillBlizzGlow then btn:KillBlizzGlow() end
    if db.visual.flashNew and obj.isNew then
        if not ov.flashAnim:IsPlaying() then ov.flashAnim:Play() end
    else
        ov.flashAnim:Stop()
        ov.flash:SetAlpha(0)
    end
end

-- ---- Search ------------------------------------------------------------------

function U.GetDynamicIlvlHint()
    local best = 0
    if GetAverageItemLevel then
        local ok, _, eq = pcall(GetAverageItemLevel)
        if ok and type(eq) == "number" and eq > best then best = floor(eq) end
    end
    for _, bagID in ipairs(S.bagIDs or {}) do
        local bc = S.slotCache[bagID]
        if bc then
            for _, e in pairs(bc) do
                if (e.ilvl or 0) > best then best = e.ilvl end
            end
        end
    end
    if best <= 20 then best = 330 end
    local threshold = max(10, floor((best - 10) / 5) * 5)
    return threshold
end

function U.ObjMatches(o, q)
    if q == "" then return true end
    if o.empty then return false end
    local op, val = q:match("^ilvl%s*([<>]=?)%s*(%d+)$")
    if not op then op, val = q:match("^([<>]=?)%s*(%d+)$") end
    if op then
        local n, il = tonumber(val), o.ilvl or 0
        if il <= 0 then return false end
        if op == ">" then return il > n elseif op == ">=" then return il >= n
        elseif op == "<" then return il < n else return il <= n end
    end
    if q == "wue" or q == "warbound" then return o.binding == "WUE" end
    if q == "boe" then return o.binding == "BOE" end
    if q == "junk" or q == "grey" then return o.quality == QUALITY_POOR end
    if q == "new" then return o.isNew and true or false end
    if q == "upgrade" or q == "up" then return U.IsUpgrade(o) end
    if q == "set" or q == "eq" then return o.setName ~= nil end
    if q == "trinket" then return o.equipLoc == "INVTYPE_TRINKET" end
    if q == "ring" or q == "neck" then return o.equipLoc == "INVTYPE_FINGER" or o.equipLoc == "INVTYPE_NECK" end
    if q == "weapon" then return o.classID == IC.Weapon end
    if (o.name or ""):lower():find(q, 1, true) then return true end
    if o.setName and o.setName:lower():find(q, 1, true) then return true end
    return false
end

local function IsStackMatching(pattern1, pattern2)
    if type(debugstack) ~= "function" then return false end
    local ok, stack = pcall(debugstack, 1, 14, 0)
    if not ok or type(stack) ~= "string" then return false end
    if pattern1 and stack:find(pattern1, 1, true) then return true end
    if pattern2 and stack:find(pattern2, 1, true) then return true end
    return false
end

local function CompactUISpecialFramesList()
    local dw = _G.DynamicSuite and _G.DynamicSuite.DesktopWindows
    if dw and type(dw.CompactUISpecialFrames) == "function" then
        dw.CompactUISpecialFrames()
        return
    end
    local t = _G.UISpecialFrames
    if type(t) ~= "table" then return end
    local keys = {}
    for k in pairs(t) do
        if type(k) == "number" and k >= 1 and floor(k) == k then
            keys[#keys + 1] = k
        end
    end
    table.sort(keys)
    local clean = {}
    local seen = {}
    for _, k in ipairs(keys) do
        local name = t[k]
        if type(name) == "string" and name ~= "" and not seen[name] then
            seen[name] = true
            clean[#clean + 1] = name
        end
    end
    for _, k in ipairs(keys) do
        t[k] = nil
    end
    for i = 1, #clean do
        t[i] = clean[i]
    end
end

local function RemoveSpecialFrameEntry(t, frameName)
    for i = #t, 1, -1 do
        if t[i] == frameName then
            table.remove(t, i)
        end
    end
end

local function AddSpecialFrameEntry(t, frameName)
    for i = 1, #t do
        if t[i] == frameName then
            return
        end
    end
    tinsert(t, frameName)
end

function U.GetTopMostShownBagFrameName()
    if S.bankWindow and S.bankWindow:IsShown() then
        return "DynamicBagsBankFrame"
    end
    if S.window and S.window:IsShown() then
        return "DynamicBagsFrame"
    end
    if S.standalone and S.standalone:IsShown() then
        return "DynamicBagsStandaloneFrame"
    end
    return nil
end

function U.EnsureBagSpecialFrames()
    if InCombatLockdown() or type(UISpecialFrames) ~= "table" then return end
    CompactUISpecialFramesList()
    local topName = U.GetTopMostShownBagFrameName()
    local allBagFrames = { "DynamicBagsBankFrame", "DynamicBagsFrame", "DynamicBagsStandaloneFrame" }
    if topName then
        for _, fName in ipairs(allBagFrames) do
            if fName ~= topName then
                RemoveSpecialFrameEntry(UISpecialFrames, fName)
            end
        end
        AddSpecialFrameEntry(UISpecialFrames, topName)
    else
        for _, fName in ipairs({ "DynamicBagsFrame", "DynamicBagsBankFrame", "DynamicBagsStandaloneFrame" }) do
            AddSpecialFrameEntry(UISpecialFrames, fName)
        end
    end
    if not S.syncingSpecialFrames then
        S.syncingSpecialFrames = true
        local dw = _G.DynamicSuite and _G.DynamicSuite.DesktopWindows
        if dw and type(dw.SyncAllUISpecialFrames) == "function" then
            pcall(dw.SyncAllUISpecialFrames)
        end
        S.syncingSpecialFrames = false
    end
end

function U.CloseTopMostBagOnEscape()
    local topName = U.GetTopMostShownBagFrameName()
    if not topName then return false end
    local frame = _G[topName]
    if not frame or not frame:IsShown() then return false end
    local isProt = (frame.IsProtected and frame:IsProtected()) and true or false
    if InCombatLockdown() and isProt then
        if topName == "DynamicBagsFrame" then
            S.pendingCombatVis = "HIDE"
        elseif topName == "DynamicBagsBankFrame" then
            S.pendingCombatHideBank = true
        end
        return false
    end
    S.explicitClosing = (S.explicitClosing or 0) + 1
    if topName == "DynamicBagsFrame" then
        U.HideWindow()
    else
        frame:Hide()
    end
    S.explicitClosing = math.max(0, (S.explicitClosing or 1) - 1)
    return true
end

function U.ClearAllSearchBoxes()
    S.search = ""
    if S.window and S.window.searchBox then
        if S.window.searchBox:GetText() ~= "" then
            S.window.searchBox:SetText("")
        end
        S.window.searchBox:ClearFocus()
        if S.window.searchBox.clearBtn then S.window.searchBox.clearBtn:Hide() end
        if S.window.searchBox.placeholder then S.window.searchBox.placeholder:Show() end
    end
    if S.bankWindow and S.bankWindow.searchBox then
        if S.bankWindow.searchBox:GetText() ~= "" then
            S.bankWindow.searchBox:SetText("")
        end
        S.bankWindow.searchBox:ClearFocus()
        if S.bankWindow.searchBox.clearBtn then S.bankWindow.searchBox.clearBtn:Hide() end
        if S.bankWindow.searchBox.placeholder then S.bankWindow.searchBox.placeholder:Show() end
    end
    U.ApplySearch()
end

function U.AttachSearchClearAndEscape(sb, ownerWin)
    if not sb then return end
    sb:SetTextInsets(8, 22, 0, 0)
    local clr = CreateFrame("Button", nil, sb)
    clr:SetSize(16, 16)
    clr:SetPoint("RIGHT", sb, "RIGHT", -4, 0)
    clr:SetFrameLevel((sb:GetFrameLevel() or 5) + 3)
    local lbl = clr:CreateFontString(nil, "OVERLAY")
    SetFont(lbl, 11, "")
    lbl:SetPoint("CENTER", clr, "CENTER", 0, 0)
    lbl:SetText("x")
    lbl:SetTextColor(0.58, 0.64, 0.72, 1)
    clr.lbl = lbl
    clr:SetScript("OnEnter", function(self)
        local ar, ag, ab = GetAccent()
        self.lbl:SetTextColor(ar, ag, ab, 1)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Clear Search Filter (Esc)", 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    clr:SetScript("OnLeave", function(self)
        self.lbl:SetTextColor(0.58, 0.64, 0.72, 1)
        if GameTooltip then GameTooltip:Hide() end
    end)
    clr:SetScript("OnClick", function()
        U.ClearAllSearchBoxes()
    end)
    clr:Hide()
    sb.clearBtn = clr

    sb:SetScript("OnTextChanged", function(self, userInput)
        local raw = self:GetText() or ""
        local t = strtrim(raw):lower()
        if self.placeholder then self.placeholder:SetShown(raw == "") end
        if self.clearBtn then self.clearBtn:SetShown(raw ~= "") end
        if userInput ~= false then
            if S.window and S.window.searchBox and S.window.searchBox ~= self and S.window.searchBox:GetText() ~= raw then
                S.window.searchBox:SetText(raw)
            end
            if S.bankWindow and S.bankWindow.searchBox and S.bankWindow.searchBox ~= self and S.bankWindow.searchBox:GetText() ~= raw then
                S.bankWindow.searchBox:SetText(raw)
            end
        end
        if t ~= S.search then
            S.search = t
            U.ApplySearch()
        end
    end)
    sb:SetScript("OnEscapePressed", function(self)
        U.ClearAllSearchBoxes()
        if self and self.ClearFocus then
            self:ClearFocus()
        end
    end)
    sb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
end

function U.ApplySearch()
    local q = S.search or ""
    for _, btn in pairs(S.buttons) do
        local o = btn.dbObj
        btn:SetAlpha((q == "" or not o or U.ObjMatches(o, q)) and 1 or 0.28)
    end
    if S.virtualButtons then
        for _, btn in ipairs(S.virtualButtons) do
            local o = btn.dbObj
            btn:SetAlpha((q == "" or not o or U.ObjMatches(o, q)) and 1 or 0.28)
        end
    end
    if S.bankWindow and S.bankWindow:IsShown() and S.bankWindow.buttons then
        local liveWin = S.bankWindow.isLive and true or false
        for _, btn in ipairs(S.bankWindow.buttons) do
            if btn:IsShown() then
                local o = btn.dbObj
                local baseAlpha = liveWin and 1.0 or 0.82
                if liveWin and o and o.gTab and o.canWithdraw == false then
                    baseAlpha = 0.55
                end
                if q ~= "" and o and not U.ObjMatches(o, q) then
                    btn:SetAlpha(0.28)
                else
                    btn:SetAlpha(baseAlpha)
                end
            end
        end
    end
end

-- ---- Item button creation (combat-safe: never created or moved in combat) ---

function U.ShowPinMenu(btn)
    local o = btn.dbObj
    if not o or o.empty or not o.itemID then return end
    local db = DB()
    local itemID = o.itemID
    local function pin(key)
        return function()
            db.pinnedCategories[itemID] = key
            U.OnSettingChanged("reclass")
        end
    end
    local pinned = db.pinnedCategories[itemID]
    U.ShowMenu(btn, {
        { label = "Pin: Keystone & Utility",     checked = pinned == "keystone",   onClick = pin("keystone") },
        { label = "Pin: M+ & Raid Consumables",  checked = pinned == "consumable", onClick = pin("consumable") },
        { label = "Pin: Equipment Sets",         checked = pinned == "eqset",      onClick = pin("eqset") },
        { label = "Pin: Gear & Weapons",         checked = pinned == "gear",       onClick = pin("gear") },
        { label = "Pin: Warbound & BoE",         checked = pinned == "boe",        onClick = pin("boe") },
        { label = "Pin: Reagents",               checked = pinned == "craft",      onClick = pin("craft") },
        { label = "Pin: Junk",                   checked = pinned == "junk",       onClick = pin("junk") },
        { label = "Reset to Auto", color = { 0.58, 0.64, 0.72 }, onClick = function()
            db.pinnedCategories[itemID] = nil
            U.OnSettingChanged("reclass")
        end },
    }, 210)
end

function U.DepositBagItemToActiveBank(bagID, slotID)
    if InCombatLockdown() or not S.atBank or not (S.bankWindow and S.bankWindow:IsShown()) then
        return false
    end
    local info = U.GetSlotInfo(bagID, slotID)
    if not info or not info.itemID then return false end

    local mode = S.companionMode or "BANK"
    if mode ~= "BANK" and mode ~= "WARBAND" then return false end
    local subTab = S.companionSubTab or 0
    local bType = nil
    if Enum and Enum.BankType then
        bType = (mode == "WARBAND") and Enum.BankType.Account or Enum.BankType.Character
    end

    -- When a specific sub-tab (T1..TN) is selected, prefer stacking or placing into an empty slot in that tab first!
    if subTab > 0 and C_Container and C_Container.PickupContainerItem then
        local tabsMeta = U.GetVaultTabsMeta(mode)
        local targetTab = tabsMeta and tabsMeta[subTab]
        local targetBagID = targetTab and targetTab.bagID
        if targetBagID then
            local okN, numSlots = pcall(C_Container.GetContainerNumSlots, targetBagID)
            if okN and type(numSlots) == "number" and numSlots > 0 then
                local maxStack = U.GetItemMaxStack(info.itemID, info.hyperlink)
                local srcKey = (maxStack > 1) and U.GetMergeStackKey(info.itemID, info.hyperlink, bagID, slotID, info.isBound) or nil
                local dstSlot = nil

                if srcKey then
                    for s = 1, numSlots do
                        local bInfo = U.GetSlotInfo(targetBagID, s)
                        if bInfo and bInfo.itemID == info.itemID and not bInfo.isLocked and (bInfo.stackCount or 1) < maxStack then
                            local bKey = U.GetMergeStackKey(bInfo.itemID, bInfo.hyperlink, targetBagID, s, bInfo.isBound)
                            if bKey == srcKey then
                                dstSlot = s
                                break
                            end
                        end
                    end
                end
                if not dstSlot then
                    for s = 1, numSlots do
                        if U.GetSlotInfo(targetBagID, s) == nil then
                            dstSlot = s
                            break
                        end
                    end
                end
                if dstSlot then
                    if ClearCursor then pcall(ClearCursor) end
                    pcall(C_Container.PickupContainerItem, bagID, slotID)
                    pcall(C_Container.PickupContainerItem, targetBagID, dstSlot)
                    if ClearCursor then pcall(ClearCursor) end
                    return true
                end
            end
        end
    end

    if C_Container and C_Container.UseContainerItem then
        if bType ~= nil then
            pcall(C_Container.UseContainerItem, bagID, slotID, nil, bType, (mode == "WARBAND"))
        else
            pcall(C_Container.UseContainerItem, bagID, slotID)
        end
        return true
    end
    return false
end

function U.CreateSlotButton(bagID, slotID)
    local parent = S.bagFrames[bagID]
    local btn
    local ok, res = pcall(CreateFrame, "ItemButton", nil, parent, "ContainerFrameItemButtonTemplate")
    if ok and res then
        btn = res
    else
        ok, res = pcall(CreateFrame, "Button", nil, parent, "ItemButtonTemplate,SecureActionButtonTemplate")
        if ok and res then
            btn = res
            btn:RegisterForClicks("AnyUp")
            btn:RegisterForDrag("LeftButton")
            btn:SetAttribute("type2", "item")
            btn:SetAttribute("item2", bagID .. " " .. slotID)
        end
    end
    if not btn then return nil end
    btn:SetID(slotID)
    btn.dbBag, btn.dbSlot = bagID, slotID
    btn._origType2 = btn.GetAttribute and btn:GetAttribute("type2") or nil
    U.BuildOverlay(btn)
    -- Alt+Right-Click is reserved for category pinning: neutralise the secure use-action for that chord.
    btn:SetAttribute("alt-type2", "macro")
    btn:SetAttribute("alt-macrotext2", "")
    btn:HookScript("PreClick", function(self, button, down)
        if U.ClearDecorUseConfirmWindow then
            U.ClearDecorUseConfirmWindow()
        end
        if button == "RightButton" and IsAltKeyDown() then
            U.ShowPinMenu(self)
            return
        end
        -- When at a live Banker with Warband Bank (or a specific sub-tab T1..TN) active in DynamicBank,
        -- route Right-Click deposits cleanly to Enum.BankType.Account / selected tab without tainting BankFrame!
        if not InCombatLockdown() and button == "RightButton"
            and not (IsAltKeyDown and IsAltKeyDown())
            and not (IsShiftKeyDown and IsShiftKeyDown())
            and not (IsControlKeyDown and IsControlKeyDown())
            and S.atBank and S.bankWindow and S.bankWindow:IsShown()
            and (S.companionMode == "WARBAND" or (S.companionSubTab or 0) > 0) then
            self._bankIntercepted = true
            self:SetAttribute("type2", "macro")
            self:SetAttribute("macrotext2", "")
            local useKeyDown = C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("ActionButtonUseKeyDown")
            if useKeyDown == nil or down == useKeyDown or down == nil then
                U.DepositBagItemToActiveBank(self.dbBag, self.dbSlot)
            end
        end
    end)
    btn:HookScript("PostClick", function(self, button, down)
        if self._bankIntercepted and not InCombatLockdown() then
            self._bankIntercepted = nil
            self:SetAttribute("type2", self._origType2)
            self:SetAttribute("macrotext2", nil)
        end
        if not InCombatLockdown() and button == "LeftButton"
            and IsAltKeyDown and IsAltKeyDown()
            and not (IsControlKeyDown and IsControlKeyDown())
            and not (IsShiftKeyDown and IsShiftKeyDown())
            and _G.MailFrame and _G.MailFrame:IsShown()
            and _G.SendMailFrame and _G.SendMailFrame:IsShown()
            and _G.DynamicMail and type(_G.DynamicMail.HandleBagSlotAltClick) == "function" then
            local now = (type(GetTime) == "function" and GetTime()) or 0
            if (now - (self._dmLastAltClick or 0)) > 0.08 then
                self._dmLastAltClick = now
                pcall(_G.DynamicMail.HandleBagSlotAltClick, _G.DynamicMail, self.dbBag, self.dbSlot)
            end
        end
    end)
    btn:Hide()
    return btn
end

function U.EnsureButtons()
    if InCombatLockdown() then
        S.pendingBuild = true
        return false
    end
    if not S.liveContent then return false end
    for _, bagID in ipairs(S.bagIDs) do
        local pf = S.bagFrames[bagID]
        if not pf then
            pf = CreateFrame("Frame", nil, S.liveContent)
            pf:SetID(bagID)
            pf.GetBagID = function(self) return self:GetID() end
            pf:SetSize(1, 1)
            pf:SetPoint("TOPLEFT", S.liveContent, "TOPLEFT", 0, 0)
            pf:Show()
            S.bagFrames[bagID] = pf
        end
        for slot = 1, (S.slotCount[bagID] or 0) do
            local key = bagID .. ":" .. slot
            if not S.buttons[key] then
                local b = U.CreateSlotButton(bagID, slot)
                if b then S.buttons[key] = b end
            end
        end
    end
    S.pendingBuild = false
    return true
end

function U.UpdateCooldowns()
    if not (S.window and S.window:IsShown()) or S.view.char or S.view.mode ~= "BAGS" then return end
    if not (CooldownFrame_Set and C_Container and C_Container.GetContainerItemCooldown) then return end
    pcall(function()
        for _, btn in pairs(S.buttons) do
            local o = btn.dbObj
            local cd = btn.Cooldown or btn.cooldown
            if cd then
                if o and not o.empty then
                    local start, dur, enable = C_Container.GetContainerItemCooldown(o.bag, o.slot)
                    CooldownFrame_Set(cd, start or 0, dur or 0, enable and 1 or 0)
                else
                    CooldownFrame_Set(cd, 0, 0, 0)
                end
            end
        end
    end)
end

-- ---- Section headers (category titles) --------------------------------------

function U.BatchTransferSection(secItems, fromBank)
    if not secItems or #secItems == 0 then return end
    if InCombatLockdown() then
        Print("Cannot batch-transfer items while in combat.")
        return
    end
    local bankOpen = (S.atBank or S.atGuildBank) and S.bankWindow and S.bankWindow:IsShown()
    if not bankOpen then
        Print("Open a live Bank, Warband Bank, or Guild Bank window to batch-transfer a category.")
        return
    end
    local mode = S.companionMode or "BANK"
    if not U.IsVaultModeLive(mode) then
        Print("Cannot batch-transfer while viewing a read-only snapshot.")
        return
    end

    local queue = {}
    for _, o in ipairs(secItems) do
        if not o.empty then
            queue[#queue + 1] = o
        end
    end
    if #queue == 0 then return end

    local bType = nil
    if Enum and Enum.BankType then
        bType = (mode == "WARBAND") and Enum.BankType.Account or Enum.BankType.Character
    end

    local idx = 1
    local moved = 0
    local function step()
        if InCombatLockdown() then
            Print("Batch transfer paused due to combat.")
            return
        end
        if idx > #queue or idx > 60 then
            if moved > 0 then
                Print(sformat("Transferred %d item stack(s).", moved))
            end
            return
        end
        local item = queue[idx]
        idx = idx + 1
        if fromBank then
            if mode == "GUILD" and item.gTab and item.gSlot and AutoStoreGuildBankItem then
                pcall(AutoStoreGuildBankItem, item.gTab, item.gSlot)
                moved = moved + 1
            elseif item.rBag and item.rSlot and C_Container and C_Container.UseContainerItem then
                pcall(C_Container.UseContainerItem, item.rBag, item.rSlot)
                moved = moved + 1
            end
        else
            if mode == "GUILD" and item.bag and item.slot and C_Container and C_Container.UseContainerItem then
                pcall(C_Container.UseContainerItem, item.bag, item.slot)
                moved = moved + 1
            elseif item.bag and item.slot then
                if U.DepositBagItemToActiveBank and U.DepositBagItemToActiveBank(item.bag, item.slot) then
                    moved = moved + 1
                elseif C_Container and C_Container.UseContainerItem then
                    if bType ~= nil then
                        pcall(C_Container.UseContainerItem, item.bag, item.slot, nil, bType, (mode == "WARBAND"))
                    else
                        pcall(C_Container.UseContainerItem, item.bag, item.slot)
                    end
                    moved = moved + 1
                end
            end
        end
        C_Timer.After(0.08, step)
    end
    step()
end

function U.MoveSectionOrder(secKey, delta, allSections)
    if not secKey or secKey == "free" then return end
    local db = DB()
    db.secPriority = db.secPriority or {}
    -- Snapshot current visible section order into explicit integer ranks (10, 20, 30...)
    local list = {}
    local targetIdx = nil
    for i, sec in ipairs(allSections or {}) do
        if sec.key and sec.key ~= "free" then
            list[#list + 1] = sec.key
            if sec.key == secKey then targetIdx = #list end
        end
    end
    if not targetIdx then return end
    local newIdx = targetIdx + delta
    if delta == -999 then newIdx = 1 elseif delta == 999 then newIdx = #list end
    newIdx = max(1, min(#list, newIdx))
    if newIdx == targetIdx then return end
    local item = table.remove(list, targetIdx)
    table.insert(list, newIdx, item)
    for i, k in ipairs(list) do
        db.secPriority[k] = i * 10
    end
    U.OnSettingChanged("layout")
end

function U.ShowSectionHeaderMenu(hdrBtn, allSections, fromBank)
    local secKey = hdrBtn.catKey
    if not secKey or secKey == "free" then return end
    local entries = {
        { label = "Move Category Earlier (Up / Left)", onClick = function() U.MoveSectionOrder(secKey, -1, allSections) end },
        { label = "Move Category Later (Down / Right)", onClick = function() U.MoveSectionOrder(secKey, 1, allSections) end },
        { label = "Pin Category to Top of Bags", onClick = function() U.MoveSectionOrder(secKey, -999, allSections) end },
        { label = "Send Category to Bottom", onClick = function() U.MoveSectionOrder(secKey, 999, allSections) end },
    }
    if (S.atBank or S.atGuildBank) and S.bankWindow and S.bankWindow:IsShown() and hdrBtn.secItems then
        entries[#entries + 1] = {
            label = fromBank and "Withdraw Entire Category to Bags" or "Deposit Entire Category to Bank",
            color = { 0.25, 0.95, 0.50 },
            onClick = function() U.BatchTransferSection(hdrBtn.secItems, fromBank) end,
        }
    end
    entries[#entries + 1] = {
        label = "Reset All Category Order to Default",
        color = { 0.65, 0.72, 0.82 },
        onClick = function()
            DB().secPriority = {}
            U.OnSettingChanged("layout")
        end,
    }
    U.ShowMenu(hdrBtn, entries, 235)
end

function U.ApplyHeaders(content, pool, sections)
    for _, h in ipairs(pool) do h:Hide() end
    local ar, ag, ab = GetAccent()
    local fromBank = (S.bankWindow and content == S.bankWindow.content)
    for i, sec in ipairs(sections) do
        local h = pool[i]
        if not h then
            h = CreateFrame("Button", nil, content)
            h:SetHeight(SECTION_HEADER_H)
            h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            h.chevron = h:CreateTexture(nil, "ARTWORK")
            h.chevron:SetSize(9, 9)
            h.chevron:SetPoint("TOPLEFT", h, "TOPLEFT", 1, -4)
            h.chevron:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga")
            if h.chevron.SetSnapToPixelGrid then h.chevron:SetSnapToPixelGrid(false); h.chevron:SetTexelSnappingBias(0) end
            h.text = h:CreateFontString(nil, "OVERLAY")
            h.text:SetPoint("TOPLEFT", h, "TOPLEFT", 14, -2)
            h.text:SetJustifyH("LEFT")
            h.text:SetWordWrap(false)
            h.count = h:CreateFontString(nil, "OVERLAY")
            h.line = h:CreateTexture(nil, "ARTWORK")
            h.line:SetHeight(1)
            h.line:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 2)
            h.line:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 2)
            h:SetScript("OnEnter", function(self)
                if self.secKey and self.secKey ~= "free" then
                    self.text:SetTextColor(1, 1, 1, 1)
                    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
                    GameTooltip:SetText(self.fullLabel or "Category", 1, 1, 1)
                    GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Collapse or Expand Category|r", 0.886, 0.910, 0.941, true)
                    GameTooltip:AddLine("|cFF38BDF8Shift + Left-Click:|r |cFFE2E8F0Collapse or Expand All Categories|r", 0.886, 0.910, 0.941, true)
                    local ar, ag, ab = GetAccent()
                    local accHex = sformat("%02X%02X%02X", floor(ar * 255 + 0.5), floor(ag * 255 + 0.5), floor(ab * 255 + 0.5))
                    GameTooltip:AddLine("|cFF" .. accHex .. "Alt + Left-Click:|r |cFFE2E8F0Reorder Category Menu|r", 0.886, 0.910, 0.941, true)
                    if (S.atBank or S.atGuildBank) and S.bankWindow and S.bankWindow:IsShown() then
                        GameTooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Batch-Transfer Entire Category|r", 0.886, 0.910, 0.941, true)
                    end
                    GameTooltip:Show()
                end
            end)
            h:SetScript("OnLeave", function(self)
                self.text:SetTextColor(0.78, 0.82, 0.88, 1)
                GameTooltip:Hide()
            end)
            h:SetScript("OnReceiveDrag", function(self)
                if fromBank then
                    U.PlaceCursorItemInFreeBankSlot()
                else
                    U.PlaceCursorItemInFreeSlot(self.catKey == "craft")
                end
            end)
            h:SetScript("OnClick", function(self, button)
                if GetCursorInfo and GetCursorInfo() == "item" then
                    if fromBank then
                        U.PlaceCursorItemInFreeBankSlot()
                    else
                        U.PlaceCursorItemInFreeSlot(self.catKey == "craft")
                    end
                    return
                end
                if not self.secKey or self.secKey == "free" then return end
                if button == "LeftButton" then
                    if IsShiftKeyDown() then
                        if InCombatLockdown() then
                            Print("Cannot collapse or expand categories during combat.")
                            return
                        end
                        local db = DB()
                        db.collapsedSections = db.collapsedSections or {}
                        local anyExpanded = false
                        for _, s in ipairs(self.allSections or {}) do
                            if s.key and s.key ~= "free" and not (db.collapsedSections[s.key] == true) then
                                anyExpanded = true
                                break
                            end
                        end
                        for _, s in ipairs(self.allSections or {}) do
                            if s.key and s.key ~= "free" then
                                db.collapsedSections[s.key] = anyExpanded and true or nil
                            end
                        end
                        U.OnSettingChanged("layout")
                    elseif IsAltKeyDown() or IsControlKeyDown() then
                        U.ShowSectionHeaderMenu(self, self.allSections, fromBank)
                    else
                        if InCombatLockdown() then
                            Print("Cannot collapse or expand categories during combat.")
                            return
                        end
                        local db = DB()
                        db.collapsedSections = db.collapsedSections or {}
                        db.collapsedSections[self.secKey] = not (db.collapsedSections[self.secKey] == true) or nil
                        U.OnSettingChanged("layout")
                    end
                elseif button == "RightButton" then
                    if IsShiftKeyDown() then
                        U.MoveSectionOrder(self.secKey, 1, self.allSections)
                    elseif self.secItems then
                        U.BatchTransferSection(self.secItems, fromBank)
                    end
                end
            end)
            pool[i] = h
        end
        h.secKey = sec.key
        h.catKey = sec.key
        h.secItems = sec.items
        h.allSections = sections
        h.fullLabel = string.upper(sec.label)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", content, "TOPLEFT", sec.x, -sec.y)
        h:SetWidth(sec.w)

        local isCollapsed = (sec.collapsed == true)
        if h.chevron then
            if sec.key == "free" then
                h.chevron:Hide()
                h.text:ClearAllPoints()
                h.text:SetPoint("TOPLEFT", h, "TOPLEFT", 0, -2)
            else
                h.chevron:Show()
                if h.chevron.SetRotation then
                    h.chevron:SetRotation(isCollapsed and math.rad(-90) or 0)
                end
                if isCollapsed then
                    h.chevron:SetVertexColor(ar, ag, ab, 0.95)
                else
                    h.chevron:SetVertexColor(0.68, 0.74, 0.82, 0.90)
                end
                h.text:ClearAllPoints()
                h.text:SetPoint("TOPLEFT", h, "TOPLEFT", 14, -2)
            end
        end

        SetFont(h.count, 10, "")
        h.count:SetText(isCollapsed and sformat("(%d)", sec.count) or tostring(sec.count))
        h.count:SetTextColor(ar, ag, ab, 1)

        SetFont(h.text, 11, "")
        h.text:SetWidth(0)
        h.text:SetText(h.fullLabel)
        h.text:SetTextColor(0.78, 0.82, 0.88, 1)
        local leftPad = (sec.key == "free") and 0 or 14
        local maxTextW = max(24, sec.w - leftPad - (h.count:GetStringWidth() or 14) - 8)
        if (h.text:GetStringWidth() or 0) > maxTextW then
            h.text:SetWidth(maxTextW)
        end

        h.count:ClearAllPoints()
        h.count:SetPoint("LEFT", h.text, "RIGHT", 5, 0)
        h.line:SetColorTexture(1, 1, 1, 0.08)
        h:Show()
    end
end
function U.CountSlots()
    local regFree, regTotal, reaFree, reaTotal = 0, 0, 0, 0
    local reagentID = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
    for _, bagID in ipairs(S.bagIDs) do
        local n = S.slotCount[bagID] or 0
        local used = 0
        local bc = S.slotCache[bagID]
        if bc then for _ in pairs(bc) do used = used + 1 end end
        if bagID == reagentID then
            reaTotal, reaFree = reaTotal + n, reaFree + (n - used)
        else
            regTotal, regFree = regTotal + n, regFree + (n - used)
        end
    end
    return regFree, regTotal, reaFree, reaTotal
end

function U.GetBagBreakdownAndJunkValue()
    local reagentID = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
    local maxBagSlots = NUM_BAG_SLOTS or 4
    local breakdown = {}
    local junkCount, junkValue = 0, 0

    local orderedBagIDs = {}
    for bagID = 0, maxBagSlots do
        orderedBagIDs[#orderedBagIDs + 1] = bagID
    end
    orderedBagIDs[#orderedBagIDs + 1] = reagentID

    for _, bagID in ipairs(orderedBagIDs) do
        local label
        if bagID == 0 then
            label = "Backpack"
        elseif bagID == reagentID then
            label = "Reagent Bag"
        else
            label = sformat("Bag %d", bagID)
        end

        local total = 0
        if C_Container and C_Container.GetContainerNumSlots then
            local okN, n = pcall(C_Container.GetContainerNumSlots, bagID)
            if okN and type(n) == "number" and not IsSecret(n) and n > 0 then
                total = n
            end
        elseif S.slotCount[bagID] then
            total = S.slotCount[bagID]
        end

        local used = 0
        for slot = 1, total do
            local info = U.GetSlotInfo(bagID, slot)
            if info then
                used = used + 1
                if not IsSecret(info.quality) and info.quality == QUALITY_POOR and not IsSecret(info.hasNoValue) and not info.hasNoValue then
                    local cnt = (type(info.stackCount) == "number" and not IsSecret(info.stackCount) and info.stackCount > 0) and info.stackCount or 1
                    junkCount = junkCount + cnt
                    if C_Item and C_Item.GetItemInfo and info.hyperlink and not IsSecret(info.hyperlink) then
                        local okInfo, _, _, _, _, _, _, _, _, _, _, sp = pcall(C_Item.GetItemInfo, info.hyperlink)
                        if okInfo and type(sp) == "number" and not IsSecret(sp) and sp > 0 then
                            junkValue = junkValue + (sp * cnt)
                        end
                    end
                end
            end
        end

        breakdown[#breakdown + 1] = {
            bagID = bagID,
            label = label,
            free = max(0, total - used),
            total = total,
        }
    end

    return breakdown, junkCount, junkValue
end

function U.RefreshLiveOverlaysInPlace()
    for key, btn in pairs(S.buttons) do
        local bagID, slot = btn.dbBag, btn.dbSlot
        local bc = bagID and S.slotCache[bagID]
        local e = bc and bc[slot]
        btn.dbObj = e or btn.dbObj
        if btn:IsShown() then U.StyleButton(btn, e) end
    end
    U.ApplySearch()
end

function U.ApplyLive(force)
    local win = S.window
    if not win or not S.liveContent then return end
    if S.view.char or S.view.mode ~= "BAGS" then return end
    if #S.bagIDs == 0 then S.bagIDs = U.GetLiveBagIDs() end
    if not force and S.appliedVersion == S.layoutVersion and S.layout and S.layout.version == S.layoutVersion then
        return
    end
    if not S.layout or S.layout.version ~= S.layoutVersion then U.BuildLiveLayout() end

    if InCombatLockdown() then
        S.pendingReflow = true
        U.RefreshLiveOverlaysInPlace()
        return
    end
    if not U.EnsureButtons() then return end

    local layout = S.layout
    local size = DB().iconSize
    local placedKeys = {}
    for _, p in ipairs(layout.placed) do
        local o = p.obj
        local btn = S.buttons[o.key]
        if btn then
            placedKeys[o.key] = true
            if btn.dbX ~= p.x or btn.dbY ~= p.y or btn.dbSize ~= size then
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", S.liveContent, "TOPLEFT", p.x, -p.y)
                btn:SetSize(size, size)
                btn.dbX, btn.dbY, btn.dbSize = p.x, p.y, size
            end
            if not btn:IsShown() then btn:Show() end
            btn.dbObj = o
            U.StyleButton(btn, o)
        end
    end
    for key, btn in pairs(S.buttons) do
        if not placedKeys[key] then
            if btn:IsShown() then btn:Hide() end
            btn.dbObj = nil
        end
    end
    S.headerPool = S.headerPool or {}
    U.ApplyHeaders(S.liveContent, S.headerPool, layout.sections)
    S.liveContent:SetHeight(layout.height + 8)
    if S.scrollArea then S.scrollArea.content:SetHeight(layout.height + 8) end
    S.appliedVersion = layout.version
    S.pendingReflow = false
    U.ApplySearch()
    U.UpdateCooldowns()
    U.SizeWindow()
    if S.scrollArea then S.scrollArea.UpdateThumb() end
end

-- ---- Remote view (alts / bank / warband snapshots, read-only virtual slots) --

function U.GetVirtualButton(i)
    S.virtualButtons = S.virtualButtons or {}
    local btn = S.virtualButtons[i]
    if btn then return btn end
    btn = CreateFrame("Button", nil, S.remoteContent)
    btn:RegisterForClicks("AnyUp")
    U.BuildOverlay(btn)
    btn:SetScript("OnEnter", function(self)
        local o = self.dbObj
        if o and o.link and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetHyperlink, GameTooltip, o.link)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    btn:SetScript("OnClick", function(self)
        local o = self.dbObj
        if o and o.link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
            ChatEdit_InsertLink(o.link)
        end
    end)
    S.virtualButtons[i] = btn
    return btn
end

function U.GetRemoteSource()
    local v, db = S.view, DB()
    if v.mode == "WARBAND" then
        local wb = db.vault.warbandBank
        return (wb and wb.items) or {}, "Warband Bank", wb and wb.updated
    end
    local key = v.char or CharKey()
    local rec = db.vault.characters[key]
    local who = (rec and rec.name) or key
    if not rec then return {}, who, nil end
    if v.mode == "BANK" then return rec.bank or {}, who .. " - Bank", rec.updated end
    return rec.bags or {}, who .. " - Bags", rec.updated
end

function U.BuildRemoteObjs(tuples, isWarband)
    U.RefreshEquipSets()
    local objs = {}
    for i, t in ipairs(tuples) do
        local itemID, link = t[1], t[2]
        local validLink = (type(link) == "string" and link ~= "" and not IsSecret(link)) and link or nil
        local validID = (type(itemID) == "number" and itemID > 0 and not IsSecret(itemID)) and itemID or nil
        local itemRef = validLink or validID
        local classID, subClassID, icon, equipLoc = 15, 0, t.icon, ""
        if itemRef and C_Item and type(C_Item.GetItemInfoInstant) == "function" then
            local okInst, _, _, _, eqLoc, ic, cID, scID = pcall(C_Item.GetItemInfoInstant, itemRef)
            if okInst then
                equipLoc = eqLoc or ""
                icon = ic or icon
                classID = cID or 15
                subClassID = scID or 0
            end
        end
        if not icon then icon = 134400 end
        local expacID = 0
        if itemRef and C_Item and type(C_Item.GetItemInfo) == "function" then
            local okInfo, exp = pcall(function() return select(15, C_Item.GetItemInfo(itemRef)) end)
            if okInfo and type(exp) == "number" and not IsSecret(exp) then expacID = exp end
        end
        local setKey = (t.bag and t.slot) and (t.bag .. ":" .. t.slot) or nil
        local setName = (setKey and S.setLookup[setKey]) or (validID and S.setByItemID and S.setByItemID[validID]) or nil
        local o = {
            rkey = i, key = setKey or ("r" .. i), remote = true,
            bag = t.bag, slot = t.slot, rBag = t.bag, rSlot = t.slot,
            gTab = t.tab, gSlot = t.slot, locked = t.locked, uncached = t.uncached,
            savedBinding = t.binding, inWarband = isWarband and true or false,
            itemID = validID or 0, link = validLink,
            count = t[3] or 1, ilvl = t[4] or 0, quality = t[5] or 1,
            icon = icon, classID = classID, subClassID = subClassID,
            equipLoc = equipLoc, expacID = expacID, setName = setName,
            name = (validLink and validLink:match("%[(.-)%]")) or (t.uncached and "Loading item..." or ""),
        }
        if validLink then o.ksLevel = tonumber(validLink:match("keystone:%d+:%d+:(%d+)")) end
        if itemRef and (classID == IC.Armor or classID == IC.Weapon) then
            U.ScanGearTooltip(o)
        end
        if itemRef then
            local cq, cmax, catlas = U.DetectCraftQuality(validLink, validID, nil, nil, classID, expacID)
            o.craftQuality = cq
            o.craftMaxTiers = cmax
            o.craftAtlas = catlas
        end
        o.cat = Classify(validID or 0, validLink, o.quality, classID, o)
        objs[#objs + 1] = o
    end
    return objs
end
function U.ApplyRemote()
    if not S.remoteContent then return end
    local db = DB()
    local tuples, label, updated = U.GetRemoteSource()
    S.remoteLabel, S.remoteUpdated = label, updated
    local objs = U.BuildRemoteObjs(tuples, S.view.mode == "WARBAND")
    local cols = (S.view.mode == "BAGS") and db.bagColumns or db.bankColumns
    local layout = U.PackLayout(objs, db.viewMode, cols, db.iconSize, db.categorySpacing, nil)
    S.remoteLayout = layout
    local size = db.iconSize
    for _, b in ipairs(S.virtualButtons or {}) do b:Hide(); b.dbObj = nil end
    for i, p in ipairs(layout.placed) do
        local btn = U.GetVirtualButton(i)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", S.remoteContent, "TOPLEFT", p.x, -p.y)
        btn:SetSize(size, size)
        btn.dbObj = p.obj
        U.StyleButton(btn, p.obj)
        btn:Show()
    end
    S.remoteHeaderPool = S.remoteHeaderPool or {}
    U.ApplyHeaders(S.remoteContent, S.remoteHeaderPool, layout.sections)
    S.remoteContent:SetHeight(layout.height + 8)
    if S.scrollArea then S.scrollArea.content:SetHeight(layout.height + 8) end
    U.ApplySearch()
    U.SizeWindow()
    if S.scrollArea then S.scrollArea.UpdateThumb() end
end

-- ============================================================================
-- 7. INVENTORY WINDOW  (B / ToggleAllBags / /dbag bag)
-- ============================================================================

function U.PlaceCursorItemInFreeSlot(preferReagentBag)
    if not GetCursorInfo or GetCursorInfo() ~= "item" then return false end
    if InCombatLockdown() or S.view.char ~= nil or S.view.mode ~= "BAGS" then return false end

    local _, itemID, itemLink = GetCursorInfo()
    local isReagent = false
    if C_Item and C_Item.IsCraftingReagentItem and (itemLink or itemID) then
        local okR, r = pcall(C_Item.IsCraftingReagentItem, itemLink or itemID)
        if okR and r then isReagent = true end
    end
    if not isReagent and C_Item and C_Item.GetItemInfoInstant and (itemLink or itemID) then
        local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemLink or itemID)
        if classID == IC.Tradegoods or classID == IC.Reagent then
            isReagent = true
        end
    end

    local reagentID = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
    local maxRegular = NUM_BAG_SLOTS or 4
    local searchBags = {}
    if isReagent or preferReagentBag == true then
        if isReagent then
            searchBags[#searchBags + 1] = reagentID
            for bagID = 0, maxRegular do searchBags[#searchBags + 1] = bagID end
        else
            for bagID = 0, maxRegular do searchBags[#searchBags + 1] = bagID end
        end
    else
        for bagID = 0, maxRegular do searchBags[#searchBags + 1] = bagID end
    end

    for _, bagID in ipairs(searchBags) do
        local n = 0
        if C_Container and C_Container.GetContainerNumSlots then
            local okN, num = pcall(C_Container.GetContainerNumSlots, bagID)
            if okN and type(num) == "number" then n = num end
        end
        if n == 0 then n = S.slotCount[bagID] or 0 end
        for slot = 1, n do
            if U.GetSlotInfo(bagID, slot) == nil then
                if C_Container and C_Container.PickupContainerItem then
                    pcall(C_Container.PickupContainerItem, bagID, slot)
                    if GetCursorInfo() ~= "item" then
                        return true
                    end
                end
            end
        end
    end

    Print("|cFFEF4444No free compatible bag slots available.|r")
    return false
end

function U.PlaceCursorItemInFreeBankSlot()
    if not GetCursorInfo or GetCursorInfo() ~= "item" then return false end
    if InCombatLockdown() then return false end
    local mode = S.companionMode or "BANK"
    if not U.IsVaultModeLive(mode) then return false end

    if mode == "GUILD" then
        if not (GetGuildBankItemLink and PickupGuildBankItem) then return false end
        local subTab = S.companionSubTab or 0
        local candidateTabs = {}
        if subTab > 0 then
            candidateTabs[1] = subTab
        else
            local cur = (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 1
            candidateTabs[#candidateTabs + 1] = cur
            local nTabs = (GetNumGuildBankTabs and GetNumGuildBankTabs()) or 0
            for t = 1, nTabs do
                if t ~= cur then candidateTabs[#candidateTabs + 1] = t end
            end
        end
        local sawPermissionBlock = false
        for _, tab in ipairs(candidateTabs) do
            local q = U.GetGuildTabQuota(tab)
            if q and (q.isViewable == false or q.canDeposit == false) then
                sawPermissionBlock = true
            else
                for slot = 1, 98 do
                    local tex = GetGuildBankItemInfo and GetGuildBankItemInfo(tab, slot)
                    if tex == nil and GetGuildBankItemLink(tab, slot) == nil then
                        pcall(PickupGuildBankItem, tab, slot)
                        if GetCursorInfo() ~= "item" then
                            C_Timer.After(0.20, function()
                                if S.atGuildBank then pcall(U.SnapshotGuildBank) end
                                if S.bankWindow and S.bankWindow:IsShown() then U.RenderCompanionBank() end
                            end)
                            return true
                        end
                    end
                end
            end
        end
        if sawPermissionBlock then
            Print("|cFFEF4444You do not have deposit permissions for this Guild Bank tab.|r")
        else
            Print("|cFFEF4444No free slots available in this Guild Bank tab.|r")
        end
        return false
    end

    local _, itemID, itemLink = GetCursorInfo()
    local isReagent = false
    if C_Item and C_Item.IsCraftingReagentItem and (itemLink or itemID) then
        local okR, r = pcall(C_Item.IsCraftingReagentItem, itemLink or itemID)
        if okR and r then isReagent = true end
    end
    if not isReagent and C_Item and C_Item.GetItemInfoInstant and (itemLink or itemID) then
        local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemLink or itemID)
        if classID == IC.Tradegoods or classID == IC.Reagent then
            isReagent = true
        end
    end

    local candidateBags = {}
    local subTab = S.companionSubTab or 0
    local tabsMeta = (subTab > 0 and U.GetVaultTabsMeta) and U.GetVaultTabsMeta(mode) or nil
    local preferredBagID = (tabsMeta and tabsMeta[subTab] and tabsMeta[subTab].bagID ~= nil) and tabsMeta[subTab].bagID or nil
    if mode == "WARBAND" then
        local wids = CollectBagIDs({ "AccountBankTab" })
        if preferredBagID ~= nil then
            candidateBags[#candidateBags + 1] = preferredBagID
        elseif subTab > 0 and wids[subTab] then
            candidateBags[#candidateBags + 1] = wids[subTab]
        end
        for _, bid in ipairs(wids) do
            if bid ~= candidateBags[1] then candidateBags[#candidateBags + 1] = bid end
        end
    else
        local bids = CollectBagIDs({ "CharacterBankTab", "Bank", "Reagentbank" })
        if preferredBagID ~= nil then
            candidateBags[#candidateBags + 1] = preferredBagID
        elseif subTab > 0 and bids[subTab] then
            candidateBags[#candidateBags + 1] = bids[subTab]
        elseif isReagent then
            for _, bid in ipairs(bids) do
                if bid == -3 or tostring(bid):find("Reagent") then
                    candidateBags[#candidateBags + 1] = bid
                end
            end
        end
        for _, bid in ipairs(bids) do
            local isReagTab = (bid == -3 or tostring(bid):find("Reagent"))
            if isReagent or subTab > 0 or not isReagTab then
                local already = false
                for _, c in ipairs(candidateBags) do if c == bid then already = true; break end end
                if not already then candidateBags[#candidateBags + 1] = bid end
            end
        end
    end

    for _, bagID in ipairs(candidateBags) do
        local okN, n = pcall(C_Container.GetContainerNumSlots, bagID)
        if okN and type(n) == "number" and n > 0 then
            for slot = 1, n do
                if U.GetSlotInfo(bagID, slot) == nil then
                    if C_Container and C_Container.PickupContainerItem then
                        pcall(C_Container.PickupContainerItem, bagID, slot)
                        if GetCursorInfo() ~= "item" then
                            C_Timer.After(0.20, function()
                                if S.atBank then pcall(U.SnapshotBank) end
                                if S.bankWindow and S.bankWindow:IsShown() then U.RenderCompanionBank() end
                            end)
                            return true
                        end
                    end
                end
            end
        end
    end

    Print("|cFFEF4444No free compatible " .. (mode == "WARBAND" and "Warband Bank" or "Bank") .. " slots available.|r")
    return false
end

function U.GetSortMode()
    local db = DB()
    if db.autoSort == false then
        return "SLOT", "Sort: Manual"
    elseif db.sortBy == "NAME" then
        return "NAME", "Sort: A-Z"
    else
        return "QUALITY", "Sort: Quality"
    end
end

function U.SetSortMode(mode)
    local db = DB()
    if mode == "SLOT" then
        db.autoSort = false
    elseif mode == "NAME" then
        db.autoSort = true
        db.sortBy = "NAME"
    else
        db.autoSort = true
        db.sortBy = "QUALITY"
    end
    U.OnSettingChanged("layout")
end

local MAX_MERGE_PASSES = 8

function U.CanRunStackMerge()
    if InCombatLockdown() then return false end
    if GetCursorInfo and GetCursorInfo() ~= nil then return false end
    if UnitCastingInfo and UnitCastingInfo("player") ~= nil then return false end
    if UnitChannelInfo and UnitChannelInfo("player") ~= nil then return false end
    return true
end

function U.GetItemMaxStack(itemID, link)
    local maxStack = 1
    if itemID and C_Item and C_Item.GetItemMaxStackSizeByID then
        local okM, m = pcall(C_Item.GetItemMaxStackSizeByID, itemID)
        if okM and type(m) == "number" and not IsSecret(m) and m > 1 then
            maxStack = m
        end
    end
    if maxStack <= 1 and C_Item and C_Item.GetItemInfo then
        local _, _, _, _, _, _, _, sMax = C_Item.GetItemInfo(link or itemID)
        if type(sMax) == "number" and not IsSecret(sMax) and sMax > 1 then
            maxStack = sMax
        end
    end
    return maxStack
end

-- Normalised stack grouping key: strictly itemID + craft/reagent quality tier + bound state.
-- Ignores hyperlink linkLevel, specializationID, and modifier suffixes so identical stackable items always merge!
function U.GetMergeStackKey(itemID, link, bagID, slotID, isBound)
    if not itemID and type(link) == "string" and not IsSecret(link) then
        itemID = tonumber(link:match("item:(%d+)"))
    end
    if type(itemID) ~= "number" or IsSecret(itemID) then
        return nil
    end

    local classID = IC.Consumable
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, _, cID = C_Item.GetItemInfoInstant(link or itemID)
        if type(cID) == "number" and not IsSecret(cID) then
            classID = cID
        end
    end

    local qTier = 0
    if U.DetectCraftQuality then
        local t = U.DetectCraftQuality(link, itemID, bagID, slotID, classID)
        if type(t) == "number" and not IsSecret(t) and t > 0 then
            qTier = t
        end
    end
    if qTier == 0 and C_TradeSkillUI then
        if C_TradeSkillUI.GetItemCraftedQualityByItemInfo then
            local okQ, val = pcall(C_TradeSkillUI.GetItemCraftedQualityByItemInfo, link or itemID)
            if okQ and type(val) == "number" and not IsSecret(val) and val > 0 then qTier = val end
        end
        if qTier == 0 and C_TradeSkillUI.GetItemReagentQualityByItemInfo then
            local okR, val = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, link or itemID)
            if okR and type(val) == "number" and not IsSecret(val) and val > 0 then qTier = val end
        end
    end

    local boundFlag = isBound and 1 or 0
    return sformat("%d:%d:%d", itemID, qTier, boundFlag)
end

local function CancelBagMergeTimer()
    if S.bagMergeFallbackTimer then
        pcall(function() S.bagMergeFallbackTimer:Cancel() end)
        S.bagMergeFallbackTimer = nil
    end
end

local function CancelGuildMergeTimer()
    if S.guildMergeFallbackTimer then
        pcall(function() S.guildMergeFallbackTimer:Cancel() end)
        S.guildMergeFallbackTimer = nil
    end
end

function U.CancelAllPendingMerges()
    S.pendingBagMerge = false
    S.bagMergeTargetIDs = nil
    S.bagMergePassCount = 0
    CancelBagMergeTimer()

    S.pendingGuildMergeTab = nil
    S.guildMergePassCount = 0
    CancelGuildMergeTimer()
end

function U.ContinuePendingBagMerge()
    if not S.pendingBagMerge or not S.bagMergeTargetIDs then return end
    CancelBagMergeTimer()
    if not U.CanRunStackMerge() then
        S.pendingBagMerge = false
        S.bagMergeTargetIDs = nil
        S.bagMergePassCount = 0
        return
    end
    U.MergePartialStacksAcrossBags(S.bagMergeTargetIDs, true)
end

function U.MergePartialStacksAcrossBags(bagIDs, isFollowUpPass)
    if not bagIDs or #bagIDs == 0 then return 0 end
    if not U.CanRunStackMerge() then
        if isFollowUpPass then U.CancelAllPendingMerges() end
        return 0
    end
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.PickupContainerItem) then
        return 0
    end

    if not isFollowUpPass then
        CancelBagMergeTimer()
        S.bagMergePassCount = 0
        S.bagMergeTargetIDs = bagIDs
    end

    S.bagMergePassCount = (S.bagMergePassCount or 0) + 1
    if S.bagMergePassCount > MAX_MERGE_PASSES then
        S.pendingBagMerge = false
        S.bagMergeTargetIDs = nil
        CancelBagMergeTimer()
        return 0
    end

    local groups = {}
    local groupOrder = {}
    local sawLockedPartial = false

    for _, bagID in ipairs(bagIDs) do
        local okN, n = pcall(C_Container.GetContainerNumSlots, bagID)
        if okN and type(n) == "number" and n > 0 then
            for slot = 1, n do
                local info = U.GetSlotInfo(bagID, slot)
                if info and info.itemID then
                    local count = info.stackCount or 1
                    local maxStack = U.GetItemMaxStack(info.itemID, info.hyperlink)
                    if maxStack > 1 and count < maxStack then
                        if info.isLocked then
                            sawLockedPartial = true
                        else
                            local stackKey = U.GetMergeStackKey(info.itemID, info.hyperlink, bagID, slot, info.isBound)
                            if stackKey then
                                local g = groups[stackKey]
                                if not g then
                                    g = {}
                                    groups[stackKey] = g
                                    groupOrder[#groupOrder + 1] = stackKey
                                end
                                g[#g + 1] = {
                                    bag = bagID,
                                    slot = slot,
                                    count = count,
                                    maxStack = maxStack,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    -- Pair disjoint (src, dst) slots within each group so each slot is touched at most once per pass
    local moves = {}
    local needsAnotherPass = false
    for _, stackKey in ipairs(groupOrder) do
        local g = groups[stackKey]
        if g and #g >= 2 then
            local i = 1
            while (i + 1) <= #g do
                local dst = g[i]
                local src = g[i + 1]
                moves[#moves + 1] = {
                    srcBag = src.bag, srcSlot = src.slot,
                    dstBag = dst.bag, dstSlot = dst.slot,
                }
                if (dst.count + src.count) > dst.maxStack then
                    needsAnotherPass = true
                end
                i = i + 2
            end
            if #g > 2 then
                needsAnotherPass = true
            end
        end
    end

    if #moves > 0 then
        if ClearCursor then pcall(ClearCursor) end
        for _, mv in ipairs(moves) do
            if not U.CanRunStackMerge() then break end
            pcall(C_Container.PickupContainerItem, mv.srcBag, mv.srcSlot)
            pcall(C_Container.PickupContainerItem, mv.dstBag, mv.dstSlot)
            if ClearCursor then pcall(ClearCursor) end
        end
    end

    if (#moves > 0 or (isFollowUpPass and sawLockedPartial) or needsAnotherPass) and S.bagMergePassCount < MAX_MERGE_PASSES and (#moves > 0 or sawLockedPartial) then
        S.pendingBagMerge = true
        CancelBagMergeTimer()
        if C_Timer and C_Timer.NewTimer then
            S.bagMergeFallbackTimer = C_Timer.NewTimer(0.30, function()
                S.bagMergeFallbackTimer = nil
                if S.pendingBagMerge then
                    U.ContinuePendingBagMerge()
                end
            end)
        end
    else
        S.pendingBagMerge = false
        S.bagMergeTargetIDs = nil
        CancelBagMergeTimer()
        if S.atBank then
            pcall(U.SnapshotBank)
            if S.bankWindow and S.bankWindow:IsShown() then
                U.RenderCompanionBank()
            end
        end
    end

    return #moves
end

function U.ContinuePendingGuildMerge()
    local tab = S.pendingGuildMergeTab
    if not tab then return end
    CancelGuildMergeTimer()
    if not S.atGuildBank or not U.CanRunStackMerge() then
        S.pendingGuildMergeTab = nil
        S.guildMergePassCount = 0
        return
    end
    U.MergeGuildBankTabStacks(tab, true)
end

function U.IsGuildBankTabViewable(tab)
    if type(tab) ~= "number" or tab < 1 then return false end
    if type(GetGuildBankTabInfo) ~= "function" then return true end
    local ok, _, _, isViewable = pcall(GetGuildBankTabInfo, tab)
    if not ok or IsSecret(isViewable) then return false end
    return isViewable ~= false
end

-- Select/query a Guild Bank tab only when the player can view it (prevents "You don't have permission to do that").
function U.SelectGuildBankTab(tab, queryOnly)
    if not S.atGuildBank or not U.IsGuildBankTabViewable(tab) then return false end
    S.queriedGuildTabs = S.queriedGuildTabs or {}
    S.queriedGuildTabs[tab] = true
    if not queryOnly and SetCurrentGuildBankTab then pcall(SetCurrentGuildBankTab, tab) end
    if QueryGuildBankTab then pcall(QueryGuildBankTab, tab) end
    return true
end

function U.GetGuildTabMergePermission(tab)
    if type(GetGuildBankTabInfo) ~= "function" or type(tab) ~= "number" or tab < 1 then
        return false, "Guild Bank tab information is not available yet."
    end
    local ok, name, _, isViewable, canDeposit, numWithdrawals, remainingWithdrawals = pcall(GetGuildBankTabInfo, tab)
    if not ok then return false, "Guild Bank tab information is not available yet." end
    if IsSecret(isViewable) or IsSecret(canDeposit) or IsSecret(numWithdrawals) or IsSecret(remainingWithdrawals) then
        return false, "Guild Bank permissions are unavailable right now. Try again in a moment."
    end
    local label = (type(name) == "string" and name ~= "" and name) or ("Tab " .. tostring(tab))
    if isViewable == false then
        return false, "You cannot view Guild Bank " .. label .. "."
    end
    if not canDeposit then
        return false, "You do not have deposit rights for Guild Bank " .. label .. ", so stacks cannot be merged there."
    end
    if type(numWithdrawals) == "number" and numWithdrawals == 0 then
        return false, "You do not have withdrawal rights for Guild Bank " .. label .. ", so stacks cannot be merged there."
    end
    if type(remainingWithdrawals) == "number" and remainingWithdrawals == 0 then
        return false, "You have no Guild Bank withdrawals left today for " .. label .. "."
    end
    return true
end

function U.MergeGuildBankTabStacks(tab, isFollowUpPass)
    if not S.atGuildBank or not U.CanRunStackMerge() then
        if isFollowUpPass then U.CancelAllPendingMerges() end
        return 0
    end
    if not (GetGuildBankItemInfo and GetGuildBankItemLink and PickupGuildBankItem) then return 0 end
    tab = tab or (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 1
    if not U.GetGuildTabMergePermission(tab) then
        S.pendingGuildMergeTab = nil
        CancelGuildMergeTimer()
        return 0
    end

    if not isFollowUpPass then
        CancelGuildMergeTimer()
        S.guildMergePassCount = 0
    end

    S.guildMergePassCount = (S.guildMergePassCount or 0) + 1
    if S.guildMergePassCount > MAX_MERGE_PASSES then
        S.pendingGuildMergeTab = nil
        CancelGuildMergeTimer()
        return 0
    end

    local groups = {}
    local groupOrder = {}
    local sawLockedPartial = false

    for slot = 1, 98 do
        local tex, count, locked = GetGuildBankItemInfo(tab, slot)
        local link = tex and GetGuildBankItemLink(tab, slot)
        if link and not IsSecret(link) then
            local itemID = tonumber(link:match("item:(%d+)"))
            if itemID then
                local maxStack = U.GetItemMaxStack(itemID, link)
                local curCount = count or 1
                if maxStack > 1 and curCount < maxStack then
                    if locked then
                        sawLockedPartial = true
                    else
                        local stackKey = U.GetMergeStackKey(itemID, link, nil, slot, false)
                        if stackKey then
                            local g = groups[stackKey]
                            if not g then
                                g = {}
                                groups[stackKey] = g
                                groupOrder[#groupOrder + 1] = stackKey
                            end
                            g[#g + 1] = {
                                slot = slot,
                                count = curCount,
                                maxStack = maxStack,
                            }
                        end
                    end
                end
            end
        end
    end

    local moves = {}
    local needsAnotherPass = false
    for _, stackKey in ipairs(groupOrder) do
        local g = groups[stackKey]
        if g and #g >= 2 then
            local i = 1
            while (i + 1) <= #g do
                local dst = g[i]
                local src = g[i + 1]
                moves[#moves + 1] = { tab = tab, srcSlot = src.slot, dstSlot = dst.slot }
                if (dst.count + src.count) > dst.maxStack then
                    needsAnotherPass = true
                end
                i = i + 2
            end
            if #g > 2 then
                needsAnotherPass = true
            end
        end
    end

    if #moves > 0 then
        if ClearCursor then pcall(ClearCursor) end
        for _, mv in ipairs(moves) do
            if not S.atGuildBank or not U.CanRunStackMerge() then break end
            pcall(PickupGuildBankItem, mv.tab, mv.srcSlot)
            pcall(PickupGuildBankItem, mv.tab, mv.dstSlot)
            if ClearCursor then pcall(ClearCursor) end
        end
    end

    if (#moves > 0 or (isFollowUpPass and sawLockedPartial) or needsAnotherPass) and S.guildMergePassCount < MAX_MERGE_PASSES and (#moves > 0 or sawLockedPartial) then
        S.pendingGuildMergeTab = tab
        CancelGuildMergeTimer()
        if C_Timer and C_Timer.NewTimer then
            S.guildMergeFallbackTimer = C_Timer.NewTimer(0.35, function()
                S.guildMergeFallbackTimer = nil
                if S.pendingGuildMergeTab then
                    U.ContinuePendingGuildMerge()
                end
            end)
        end
    else
        S.pendingGuildMergeTab = nil
        CancelGuildMergeTimer()
        if S.atGuildBank then
            pcall(U.SnapshotGuildBank)
            if S.bankWindow and S.bankWindow:IsShown() then
                U.RenderCompanionBank()
            end
        end
    end

    return #moves
end

function U.Restack()
    if InCombatLockdown() then
        Print("Cannot merge stacks while in combat.")
        return
    end
    local bagIDs = (S.bagIDs and #S.bagIDs > 0) and S.bagIDs or U.GetLiveBagIDs()
    U.MergePartialStacksAcrossBags(bagIDs, false)
end

function U.RestackBank(mode)
    if InCombatLockdown() then
        Print("Cannot merge bank stacks while in combat.")
        return
    end
    mode = mode or S.companionMode or "BANK"
    if not U.IsVaultModeLive(mode) then
        Print("Read-Only Snapshot: Visit a Banker to merge partial stacks in your " .. (mode == "WARBAND" and "Warband Bank." or mode == "GUILD" and "Guild Bank." or "Bank."))
        return
    end

    if mode == "WARBAND" then
        if S.atGuildBank then
            Print("Warband Bank stacks can only be merged at a Banker, not at the Guild Bank.")
            return
        end
        local wids = CollectBagIDs({ "AccountBankTab" })
        U.MergePartialStacksAcrossBags(wids, false)
    elseif mode == "BANK" then
        if S.atGuildBank then
            Print("Personal Bank stacks can only be merged at a Banker, not at the Guild Bank.")
            return
        end
        local bids = CollectBagIDs({ "CharacterBankTab", "Bank", "Reagentbank" })
        U.MergePartialStacksAcrossBags(bids, false)
    elseif mode == "GUILD" then
        local activeTab = (S.companionSubTab and S.companionSubTab > 0 and S.companionSubTab) or (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 1
        local allowed, reason = U.GetGuildTabMergePermission(activeTab)
        if not allowed then
            Print(reason or "You do not have permission to merge stacks in this Guild Bank tab.")
            return
        end
        local merged = U.MergeGuildBankTabStacks(activeTab, false)
        if merged == 0 and not S.pendingGuildMergeTab then
            Print("No partial stacks to merge in Guild Bank Tab " .. tostring(activeTab) .. ".")
        end
    end
end

function U.ClearNew()
    wipe(S.sessionNew)
    if C_NewItems then
        if C_NewItems.ClearAll then pcall(C_NewItems.ClearAll) end
        if C_NewItems.RemoveNewItem then
            for _, bagID in ipairs(S.bagIDs) do
                local n = S.slotCount[bagID] or 0
                for slot = 1, n do
                    pcall(C_NewItems.RemoveNewItem, bagID, slot)
                end
            end
        end
    end
    for _, bagID in ipairs(S.bagIDs) do
        local bc = S.slotCache[bagID]
        if bc then
            for _, e in pairs(bc) do e.isNew = false end
        end
    end
    for _, btn in pairs(S.buttons) do
        if btn.KillBlizzGlow then btn:KillBlizzGlow() end
        if btn.dbOverlay and btn.dbOverlay.flashAnim then
            btn.dbOverlay.flashAnim:Stop()
            btn.dbOverlay.flash:SetAlpha(0)
        end
        if btn.dbObj then
            btn.dbObj.isNew = false
            U.StyleButton(btn, btn.dbObj)
        end
    end
    U.OnSettingChanged("reclass")
end

function U.OnSettingChanged(kind)
    if kind == "reclass" then U.ReclassifyAll() end
    S.layoutVersion = S.layoutVersion + 1
    S.layout = nil
    if S.window then
        U.UpdateHeaderLabels()
        if S.window:IsShown() then U.RenderCurrentView() end
    end
    if S.bankWindow and S.bankWindow:IsShown() then
        U.RenderCompanionBank()
    end
    if U.RefreshWorkspace then U.RefreshWorkspace() end
end

function U.ApplyPreset(key)
    local db = DB()
    db.savedPresets = db.savedPresets or {}
    local customP = db.savedPresets[key]
    local p = customP or (key ~= "CUSTOM" and PRESETS[key] or nil)
    if p then
        db.preset = key
        db.viewMode = p.viewMode or "CATEGORY"
        if type(p.order) == "table" and #p.order == #CATS then
            db.catOrder = {}
            for i, k in ipairs(p.order) do db.catOrder[i] = k end
        end
        if type(p.cats) == "table" then
            for k, v in pairs(p.cats) do db.categories[k] = v end
        end
        if type(p.splits) == "table" then
            for k, v in pairs(p.splits) do db[k] = v end
        end
        db.secPriority = {}
    else
        db.preset = "CUSTOM"
    end
    U.OnSettingChanged("reclass")
end

function U.SaveCurrentToPreset(key)
    local db = DB()
    db.savedPresets = db.savedPresets or {}
    local orderCopy, catsCopy, splitsCopy = {}, {}, {}
    for i, k in ipairs(U.EnsureCatOrder()) do orderCopy[i] = k end
    for k, v in pairs(db.categories) do catsCopy[k] = v end
    for _, sk in ipairs({ "splitEqSets", "splitConsumables", "splitGearSlots", "splitUpgrades", "splitBindSlots", "splitGemsEnchants", "splitReagents", "splitCollectibles" }) do
        splitsCopy[sk] = (db[sk] ~= false)
    end
    db.savedPresets[key] = {
        label = (PRESETS[key] and PRESETS[key].label) or "Custom",
        viewMode = db.viewMode,
        order = orderCopy,
        cats = catsCopy,
        splits = splitsCopy,
    }
    db.preset = key
    Print("Saved your current category order and sub-categories to preset: " .. ((PRESETS[key] and PRESETS[key].label) or "Custom"))
end

function U.AutoFitDropdownButton(btn, text, minW, maxW)
    if not btn or not btn.label then return minW or 92 end
    btn.label:ClearAllPoints()
    btn.label:SetPoint("LEFT", btn, "LEFT", 8, 0)
    btn.label:SetText(text or "")
    local strW = (btn.label.GetUnboundedStringWidth and btn.label:GetUnboundedStringWidth())
        or (btn.label.GetStringWidth and btn.label:GetStringWidth()) or 0
    if not strW or strW <= 0 then
        strW = #(tostring(text or "")) * 6.8
    end
    local w = max(minW or 72, min(maxW or 126, ceil(strW) + 30))
    btn:SetWidth(w)
    if btn.chevronTex then
        btn.label:SetPoint("RIGHT", btn.chevronTex, "LEFT", -4, 0)
    else
        btn.label:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    end
    return w
end

function U.UpdateHeaderLabels()
    local win = S.window
    if not win then return end
    local v, db = S.view, DB()
    local nm
    if v.char then
        local rec = db.vault.characters[v.char]
        nm = (rec and rec.name) or v.char
    else
        nm = UnitName("player") or "Player"
    end
    U.AutoFitDropdownButton(win.charBtn, nm, 92, 126)
    local modeLabel = (v.mode == "BAGS" and "Bags") or (v.mode == "BANK" and "Bank") or "Warband"
    U.AutoFitDropdownButton(win.viewBtn, modeLabel, 72, 78)
    if win.sortBtn then
        local _, sortLabel = U.GetSortMode()
        win.sortBtn:SetLabel(sortLabel)
    end
    if win.restackBtn then
        win.restackBtn:SetSelected(db.autoMergeOnClose == true)
    end
    if S.bankWindow then
        local _, sortLabel = U.GetSortMode()
        if S.bankWindow.sortBtn then
            S.bankWindow.sortBtn:SetLabel(sortLabel)
        end
        if S.bankWindow.restackBtn then
            S.bankWindow.restackBtn:SetSelected(db.autoMergeOnClose == true)
        end
    end
    local p = PRESETS[db.preset]
    win.presetBtn:SetLabel("Preset: " .. (p and p.label or "Custom"))
    local hint = U.GetDynamicIlvlHint()
    if win.searchBox and win.searchBox.placeholder then
        win.searchBox.placeholder:SetText(sformat("Search items, sets, ilvl > %d, upgrade, WUE, BoE...", hint))
    end
    if S.bankWindow and S.bankWindow.searchBox and S.bankWindow.searchBox.placeholder then
        S.bankWindow.searchBox.placeholder:SetText(sformat("Search bank items, sets, ilvl > %d, upgrade, WUE, BoE...", hint))
    end
end

function U.SizeWindow()
    local win = S.window
    if not win or InCombatLockdown() then return end
    U.UpdateHeaderLabels()
    local db = DB()
    local remote = S.view.char or S.view.mode ~= "BAGS"
    local cols = (S.view.mode == "BAGS") and db.bagColumns or db.bankColumns
    local step = db.iconSize + SLOT_GAP
    local gridW = max(200, cols * step - SLOT_GAP)
    local charW = (win.charBtn and win.charBtn:GetWidth()) or 96
    local viewW = (win.viewBtn and win.viewBtn:GetWidth()) or 74
    local leftGroupRightEdge = 1 + 130 + charW + 4 + viewW
    local rightGroupTotalWidth = 1 + 8 + 26 + 4 + 28 + 4 + 72 + 4 + 102 + 4 + 64
    local minHeaderWidth = ceil(leftGroupRightEdge + rightGroupTotalWidth + 16)
    local width = max(minHeaderWidth, gridW + 28)
    local innerW = max(gridW, width - 28)
    local xPad = max(0, floor((innerW - gridW) * 0.5))
    local layout = remote and S.remoteLayout or S.layout
    local contentH = ((layout and layout.height) or 200) + 8
    if S.liveContent and S.scrollArea and S.scrollArea.content then
        S.liveContent:ClearAllPoints()
        S.liveContent:SetPoint("TOPLEFT", S.scrollArea.content, "TOPLEFT", xPad, 0)
        S.liveContent:SetWidth(gridW)
    end
    if S.remoteContent and S.scrollArea and S.scrollArea.content then
        S.remoteContent:ClearAllPoints()
        S.remoteContent:SetPoint("TOPLEFT", S.scrollArea.content, "TOPLEFT", xPad, 0)
        S.remoteContent:SetWidth(gridW)
    end
    if S.scrollArea and S.scrollArea.content then
        S.scrollArea.content:SetWidth(innerW)
    end
    local maxH = floor((UIParent:GetHeight() or 900) * 0.82)
    local height = min(maxH, max(280, contentH + 72 + 36 + 10))
    if floor(win:GetWidth() + 0.5) ~= width or floor(win:GetHeight() + 0.5) ~= height then
        win:SetSize(width, height)
    end
end

local BAG_SCALE_MIN = 0.70
local BAG_SCALE_MAX = 1.40
local BAG_SCALE_STEP = 0.05

local function ClampWindowScale(val)
    local n = tonumber(val) or 1.0
    n = floor(n * 20 + 0.5) / 20
    if n < BAG_SCALE_MIN then n = BAG_SCALE_MIN end
    if n > BAG_SCALE_MAX then n = BAG_SCALE_MAX end
    return n
end

function U.GetActiveWindowScale(targetKind)
    local db = DB()
    if targetKind == "bank" then
        return ClampWindowScale(S.sessionBankScale or db.bankScale or 1.0)
    end
    return ClampWindowScale(S.sessionBagScale or db.bagScale or 1.0)
end

local function ApplySavedTopAlignedPos(frame, dbKey)
    if not frame or (InCombatLockdown and InCombatLockdown()) then return end
    local pos = DB()[dbKey]
    if type(pos) ~= "table" or not pos[1] then return end
    local s = (frame.GetScale and frame:GetScale()) or 1
    if s <= 0 then s = 1 end
    frame:ClearAllPoints()
    frame:SetPoint(pos[1], UIParent, pos[2] or pos[1], (pos[3] or 0) / s, (pos[4] or 0) / s)
end

function U.ApplyWindowScale(targetKind)
    if InCombatLockdown and InCombatLockdown() then return end
    if targetKind == "bank" then
        local bw = S.bankWindow
        if not bw then return end
        local sc = U.GetActiveWindowScale("bank")
        if math.abs((bw.GetScale and bw:GetScale() or 1) - sc) > 0.001 then
            bw:SetScale(sc)
        end
        if U.ApplyCompanionAnchor then U.ApplyCompanionAnchor() end
        return
    end
    local win = S.window
    if not win then return end
    local sc = U.GetActiveWindowScale("bag")
    if math.abs((win.GetScale and win:GetScale() or 1) - sc) > 0.001 then
        win:SetScale(sc)
    end
    ApplySavedTopAlignedPos(win, "windowPos")
    if S.bankWindow and S.bankWindow:IsShown() and DB().vaultDocked ~= false and U.ApplyCompanionAnchor then
        U.ApplyCompanionAnchor()
    end
end

local scaleToastFrame = nil
local function ShowBagScaleToast(anchorFrame, msg)
    if not CreateFrame then return end
    local ar, ag, ab = U.GetSuiteAccent()
    if not scaleToastFrame then
        local tf = CreateFrame("Frame", "DynamicBagsWindowScaleToast", UIParent, "BackdropTemplate")
        tf:SetSize(196, 28)
        tf:SetFrameStrata("DIALOG")
        tf:SetClampedToScreen(true)
        Backdrop(tf, 0.043, 0.051, 0.071, 0.96, ar, ag, ab, 0.90)
        local txt = tf:CreateFontString(nil, "OVERLAY")
        SetFont(txt, 11, "")
        txt:SetPoint("CENTER", tf, "CENTER", 0, 0)
        txt:SetTextColor(ar, ag, ab, 1)
        tf.text = txt
        tf:SetScript("OnUpdate", function(self, elapsed)
            self._t = (self._t or 0) + elapsed
            if self._t >= 1.40 then
                local fade = (self._t - 1.40) / 0.35
                if fade >= 1 then
                    self:Hide()
                    self:SetAlpha(1)
                    self._t = 0
                else
                    self:SetAlpha(1 - fade)
                end
            end
        end)
        scaleToastFrame = tf
    end
    Backdrop(scaleToastFrame, 0.043, 0.051, 0.071, 0.96, ar, ag, ab, 0.90)
    scaleToastFrame.text:SetTextColor(ar, ag, ab, 1)
    scaleToastFrame.text:SetText(msg or "")
    scaleToastFrame:ClearAllPoints()
    if anchorFrame then
        scaleToastFrame:SetPoint("BOTTOM", anchorFrame, "TOP", 0, 8)
    else
        scaleToastFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    end
    scaleToastFrame:SetAlpha(1)
    scaleToastFrame._t = 0
    scaleToastFrame:Show()
end

function U.StepBagOrBankScale(targetKind, delta, savePermanent)
    if InCombatLockdown and InCombatLockdown() then return end
    local isBank = (targetKind == "bank")
    local frame = isBank and S.bankWindow or S.window
    if not frame then return end
    local cur = U.GetActiveWindowScale(targetKind)
    local nextScale = ClampWindowScale(cur + ((delta or 0) > 0 and BAG_SCALE_STEP or -BAG_SCALE_STEP))
    if savePermanent then
        if isBank then
            DB().bankScale = nextScale
            S.sessionBankScale = nil
        else
            DB().bagScale = nextScale
            S.sessionBagScale = nil
        end
    else
        if isBank then
            S.sessionBankScale = nextScale
        else
            S.sessionBagScale = nextScale
        end
    end
    if isBank then
        if DB().vaultDocked == false then
            U.SaveTopAlignedPos(frame, "vaultPos")
        end
        frame:SetScale(nextScale)
        if U.ApplyCompanionAnchor then U.ApplyCompanionAnchor() end
    else
        U.SaveTopAlignedPos(frame, "windowPos")
        frame:SetScale(nextScale)
        ApplySavedTopAlignedPos(frame, "windowPos")
        if S.bankWindow and S.bankWindow:IsShown() and DB().vaultDocked ~= false and U.ApplyCompanionAnchor then
            U.ApplyCompanionAnchor()
        end
    end
    local pct = floor(nextScale * 100 + 0.5)
    ShowBagScaleToast(frame, (savePermanent and "Saved Scale: " or "Session Scale: ") .. tostring(pct) .. "%")
end

function U.ResetBagOrBankScale(targetKind)
    if InCombatLockdown and InCombatLockdown() then return end
    local isBank = (targetKind == "bank")
    local frame = isBank and S.bankWindow or S.window
    if not frame then return end
    if isBank then
        DB().bankScale = 1.0
        S.sessionBankScale = nil
        if DB().vaultDocked == false then
            U.SaveTopAlignedPos(frame, "vaultPos")
        end
        frame:SetScale(1.0)
        if U.ApplyCompanionAnchor then U.ApplyCompanionAnchor() end
    else
        DB().bagScale = 1.0
        S.sessionBagScale = nil
        U.SaveTopAlignedPos(frame, "windowPos")
        frame:SetScale(1.0)
        ApplySavedTopAlignedPos(frame, "windowPos")
        if S.bankWindow and S.bankWindow:IsShown() and DB().vaultDocked ~= false and U.ApplyCompanionAnchor then
            U.ApplyCompanionAnchor()
        end
    end
    ShowBagScaleToast(frame, "Scale Reset: 100%")
end

function U.AttachWindowScaleHandlers(targetKind, headFrame, fullFrames)
    if headFrame and headFrame.HookScript then
        if headFrame.EnableMouse then headFrame:EnableMouse(true) end
        if headFrame.EnableMouseWheel then headFrame:EnableMouseWheel(true) end
        headFrame:HookScript("OnMouseWheel", function(_, delta)
            local ctrl = IsControlKeyDown and IsControlKeyDown()
            if not ctrl then return end
            local shift = IsShiftKeyDown and IsShiftKeyDown()
            U.StepBagOrBankScale(targetKind, delta, shift and true or false)
        end)
        headFrame:HookScript("OnMouseUp", function(_, button)
            if button == "RightButton" and not (GetCursorInfo and GetCursorInfo() == "item") then
                U.ResetBagOrBankScale(targetKind)
            end
        end)
        headFrame:HookScript("OnEnter", function(selfHead)
            if not _G.GameTooltip then return end
            local title = (targetKind == "bank") and "DynamicBank Window Controls" or "DynamicBags Window Controls"
            local ar, ag, ab = U.GetSuiteAccent()
            _G.GameTooltip:SetOwner(selfHead, "ANCHOR_TOP")
            _G.GameTooltip:AddLine(title, ar, ag, ab)
            _G.GameTooltip:AddLine("Left-Drag Header: Move window position", 0.90, 0.93, 0.96)
            _G.GameTooltip:AddLine("Ctrl + Scroll Header: Scale this session (70%-140%)", 0.90, 0.93, 0.96)
            _G.GameTooltip:AddLine("Ctrl + Shift + Scroll Anywhere: Save permanent scale", 0.90, 0.93, 0.96)
            _G.GameTooltip:AddLine("Right-Click Header: Reset scale to 100%", 0.65, 0.72, 0.80)
            _G.GameTooltip:Show()
        end)
        headFrame:HookScript("OnLeave", function()
            if _G.GameTooltip then _G.GameTooltip:Hide() end
        end)
    end
    if type(fullFrames) == "table" then
        for _, f in ipairs(fullFrames) do
            if f then
                local objType = (type(f.GetObjectType) == "function") and f:GetObjectType() or nil
                if objType == "ScrollFrame" then
                    f._dbagScaleTarget = targetKind
                    if f.EnableMouseWheel then f:EnableMouseWheel(true) end
                    if type(f.GetScrollChild) == "function" then
                        local child = f:GetScrollChild()
                        if child and child.EnableMouseWheel then
                            child:EnableMouseWheel(false)
                        end
                    end
                elseif f._dbagIsScrollContent then
                    if f.EnableMouseWheel then f:EnableMouseWheel(false) end
                elseif f.EnableMouseWheel and f.HookScript then
                    f:EnableMouseWheel(true)
                    f:HookScript("OnMouseWheel", function(_, delta)
                        local ctrl = IsControlKeyDown and IsControlKeyDown()
                        local shift = IsShiftKeyDown and IsShiftKeyDown()
                        if ctrl and shift then
                            U.StepBagOrBankScale(targetKind, delta, true)
                            return
                        end
                        if f._dbagForwardScroll and f._dbagForwardScroll.GetScript then
                            local onWheel = f._dbagForwardScroll:GetScript("OnMouseWheel")
                            if type(onWheel) == "function" then
                                onWheel(f._dbagForwardScroll, delta)
                            end
                        end
                    end)
                end
            end
        end
    end
end

function U.SaveTopAlignedPos(frame, dbKey)
    local top = frame:GetTop()
    local right = frame:GetRight()
    local left = frame:GetLeft()
    local s = (frame.GetScale and frame:GetScale()) or 1
    if s <= 0 then s = 1 end
    local uiW = UIParent:GetWidth() or 1920
    local uiH = UIParent:GetHeight() or 1080
    local bagWUI = (frame:GetWidth() or 700) * s

    if top and right and dbKey == "windowPos" then
        local topUI = top * s
        local rightUI = right * s
        -- Prevent DynamicBags from being pushed so far left that a docked DynamicBank overlaps it!
        local minLeft = 8
        if S.bankWindow and S.bankWindow:IsShown() and DB().vaultDocked ~= false then
            local bs = (S.bankWindow.GetScale and S.bankWindow:GetScale()) or 1
            if bs <= 0 then bs = 1 end
            minLeft = ((S.bankWindow:GetWidth() or 620) * bs) + 18
        end
        if (rightUI - bagWUI) < minLeft then
            rightUI = minLeft + bagWUI
        end
        if rightUI > uiW - 4 then rightUI = uiW - 4 end
        local xOfs = rightUI - uiW
        local yOfs = min(-4, topUI - uiH)
        frame:ClearAllPoints()
        frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", xOfs / s, yOfs / s)
        DB()[dbKey] = { "TOPRIGHT", "TOPRIGHT", xOfs, yOfs }
    elseif top and left then
        local topUI = top * s
        local leftUI = left * s
        local xOfs = max(4, min(uiW - ((frame:GetWidth() or 600) * s) - 4, leftUI))
        local yOfs = min(-4, topUI - uiH)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", xOfs / s, yOfs / s)
        DB()[dbKey] = { "TOPLEFT", "TOPLEFT", xOfs, yOfs }
    end
end

function U.MakeFrameDraggable(targetFrame, moveFrame, onStopFn)
    if not targetFrame or not moveFrame then return end
    targetFrame:EnableMouse(true)
    targetFrame:RegisterForDrag("LeftButton")
    targetFrame:SetScript("OnDragStart", function()
        if _G.GameTooltip and _G.GameTooltip.Hide then _G.GameTooltip:Hide() end
        if InCombatLockdown() then return end
        if GetCursorInfo and GetCursorInfo() == "item" then return end
        local master = moveFrame
        if moveFrame == S.bankWindow and DB().vaultDocked ~= false and S.window and S.window:IsShown() then
            master = S.window
            moveFrame._movingMasterBag = true
        end
        master:StartMoving()
        -- Live per-frame clamp while dragging so Docked DynamicBank and DynamicBags can NEVER overlap mid-drag!
        if master == S.window and S.bankWindow and S.bankWindow:IsShown() and DB().vaultDocked ~= false then
            S.bankWindow:SetClampedToScreen(false)
            targetFrame:SetScript("OnUpdate", function()
                local ms = (master.GetScale and master:GetScale()) or 1
                local bs = (S.bankWindow.GetScale and S.bankWindow:GetScale()) or 1
                if ms <= 0 then ms = 1 end
                if bs <= 0 then bs = 1 end
                local minLeft = ((S.bankWindow:GetWidth() or 620) * bs) + 14
                local curLeft = master:GetLeft()
                if curLeft and (curLeft * ms) < minLeft then
                    master:StopMovingOrSizing()
                    U.SaveTopAlignedPos(master, "windowPos")
                    U.ApplyCompanionAnchor()
                    master:StartMoving()
                end
            end)
        end
    end)
    targetFrame:SetScript("OnDragStop", function()
        targetFrame:SetScript("OnUpdate", nil)
        if S.bankWindow then S.bankWindow:SetClampedToScreen(true) end
        if moveFrame._movingMasterBag and S.window then
            moveFrame._movingMasterBag = nil
            S.window:StopMovingOrSizing()
            U.SaveTopAlignedPos(S.window, "windowPos")
            U.ApplyCompanionAnchor()
        else
            moveFrame:StopMovingOrSizing()
            if onStopFn then onStopFn(moveFrame) end
        end
    end)
end

local function ShortNum(n)
    n = tonumber(n) or 0
    if n >= 1000000 then return sformat("%.1fM", n / 1000000)
    elseif n >= 10000 then return sformat("%.1fk", n / 1000)
    elseif BreakUpLargeNumbers then return BreakUpLargeNumbers(n)
    else return tostring(n) end
end

function U.GetTrackedCurrenciesList()
    local list = {}
    local db = DB()
    db.trackedCurrencies = db.trackedCurrencies or {}
    local usedIDs = {}

    if C_CurrencyInfo and C_CurrencyInfo.GetBackpackCurrencyInfo then
        for i = 1, 8 do
            local ok, info = pcall(C_CurrencyInfo.GetBackpackCurrencyInfo, i)
            if ok and type(info) == "table" and info.name and info.iconFileID then
                local cid = info.currencyTypesID
                if cid then usedIDs[cid] = true end
                list[#list + 1] = { id = cid, name = info.name, icon = info.iconFileID, quantity = info.quantity or 0 }
            end
        end
    end

    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        for cid, enabled in pairs(db.trackedCurrencies) do
            if enabled and not usedIDs[cid] then
                local ok, cinfo = pcall(C_CurrencyInfo.GetCurrencyInfo, cid)
                if ok and type(cinfo) == "table" and cinfo.iconFileID then
                    usedIDs[cid] = true
                    list[#list + 1] = { id = cid, name = cinfo.name, icon = cinfo.iconFileID, quantity = cinfo.quantity or 0 }
                end
            end
        end
    end
    return list
end

function U.GetTrackedCurrenciesText()
    local list = U.GetTrackedCurrenciesList()
    local parts = {}
    local maxInline = 4
    for i = 1, min(#list, maxInline) do
        local c = list[i]
        parts[#parts + 1] = sformat("|T%s:13:13:0:0:64:64:5:59:5:59|t |cFFFFFFFF%s|r", tostring(c.icon), ShortNum(c.quantity))
    end
    if #list > maxInline then
        parts[#parts + 1] = sformat("|cFF94A3B8+%d|r", #list - maxInline)
    end
    return table.concat(parts, "  ")
end

function U.ShowCurrencyPickerMenu(anchor)
    local entries = {}
    local db = DB()
    db.trackedCurrencies = db.trackedCurrencies or {}
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize and C_CurrencyInfo.GetCurrencyListInfo then
        local n = C_CurrencyInfo.GetCurrencyListSize() or 0
        for i = 1, n do
            local ok, info = pcall(C_CurrencyInfo.GetCurrencyListInfo, i)
            if ok and type(info) == "table" and not info.isHeader and info.name and (info.quantity or 0) >= 0 then
                local link = C_CurrencyInfo.GetCurrencyListLink and C_CurrencyInfo.GetCurrencyListLink(i)
                local cid = link and tonumber(link:match("currency:(%d+)"))
                if cid and #entries < 18 then
                    local isWatched = (info.isShowInBackpack == true) or (db.trackedCurrencies[cid] == true)
                    local iconTag = info.iconFileID and sformat("|T%s:13:13:0:0:64:64:5:59:5:59|t ", tostring(info.iconFileID)) or ""
                    entries[#entries + 1] = {
                        label = sformat("%s%s (%d)", iconTag, info.name, info.quantity or 0),
                        checked = isWatched,
                        keepOpen = true,
                        onClick = function()
                            if C_CurrencyInfo.SetCurrencyBackpack then
                                pcall(C_CurrencyInfo.SetCurrencyBackpack, i, not info.isShowInBackpack)
                            end
                            db.trackedCurrencies[cid] = not isWatched or nil
                            U.UpdateFooter()
                        end,
                    }
                end
            end
        end
    end
    if #entries == 0 then
        entries[#entries + 1] = { label = "Open Character -> Currency tab once to populate list", color = { 0.6, 0.65, 0.72 }, onClick = function() if ToggleCharacter then ToggleCharacter("TokenFrame") end end }
    else
        entries[#entries + 1] = { label = "Open Blizzard Currency Tab...", color = { 0.45, 0.80, 1.0 }, onClick = function() if ToggleCharacter then ToggleCharacter("TokenFrame") end end }
    end
    U.ShowMenu(anchor, entries, 250)
end

function U.FormatMoneyWithIcons(copper)
    local val = tonumber(copper) or 0
    if val < 0 then val = math.abs(val) end
    val = floor(val)
    local gold = floor(val / 10000)
    local silver = floor((val % 10000) / 100)
    local copperRem = val % 100
    local gIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"
    local sIcon = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t"
    local cIcon = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"
    local gStr = BreakUpLargeNumbers and BreakUpLargeNumbers(gold) or tostring(gold)
    if gold > 0 then
        return sformat("%s%s %02d%s %02d%s", gStr, gIcon, silver, sIcon, copperRem, cIcon)
    elseif silver > 0 then
        return sformat("%d%s %02d%s", silver, sIcon, copperRem, cIcon)
    else
        return sformat("%d%s", copperRem, cIcon)
    end
end

function U.UpdateFooter()
    local f = S.footer
    if not f or not S.window then return end
    local v = S.view
    if v.char or v.mode ~= "BAGS" then
        local age = ""
        if S.remoteUpdated and time then
            local d = max(0, time() - S.remoteUpdated)
            if d < 3600 then age = sformat(" - updated %dm ago", floor(d / 60))
            elseif d < 86400 then age = sformat(" - updated %dh ago", floor(d / 3600))
            else age = sformat(" - updated %dd ago", floor(d / 86400)) end
        end
        f.left:SetText(sformat("Viewing %s (read-only snapshot%s)", S.remoteLabel or "snapshot", age))
    else
        local rf, rt, af, at = U.CountSlots()
        f.left:SetText(sformat("Bags: %d/%d   |   Reagents: %d/%d", rf, rt, af, at))
    end
    if f.currText then
        local cStr = U.GetTrackedCurrenciesText()
        f.currText:SetText(cStr ~= "" and cStr or "|cFF64748B[+ Currencies]|r")
    end
    local money = GetMoney and GetMoney() or 0
    if v.char and DB().vault and DB().vault.characters and DB().vault.characters[v.char] and type(DB().vault.characters[v.char].gold) == "number" then
        money = DB().vault.characters[v.char].gold
    end
    f.gold:SetText(U.FormatMoneyWithIcons(money))
end

function U.RenderCurrentView()
    local win = S.window
    if not win then return end
    if next(S.slotCount) == nil then
        -- First open before any BAG_UPDATE_DELAYED has populated the cache.
        wipe(S.bindCache); S.forceFull = true
        pcall(U.ProcessDirtyBags)
    end
    local v = S.view
    if v.char == nil and v.mode == "BAGS" then
        S.remoteContent:Hide()
        S.liveContent:Show()
        U.ApplyLive(false)
    else
        S.liveContent:Hide()
        S.remoteContent:Show()
        U.ApplyRemote()
    end
    U.SizeWindow()
    U.UpdateFooter()
    U.UpdateHeaderLabels()
    if U.UpdateQuickOpenButton then U.UpdateQuickOpenButton() end
    if S.scrollArea then S.scrollArea.UpdateThumb() end
end

function U.IsVaultModeLive(mode)
    mode = mode or S.companionMode or "BANK"
    if mode == "GUILD" then
        return (S.atGuildBank == true) and (S.view.char == nil)
    else
        return (S.atBank == true) and (S.view.char == nil)
    end
end

function U.GetVaultTabsMeta(mode)
    local tabs = {}
    if mode == "GUILD" then
        local n = (GetNumGuildBankTabs and GetNumGuildBankTabs()) or 0
        for i = 1, n do
            local q = U.GetGuildTabQuota(i) or {}
            local name, icon = GetGuildBankTabInfo(i)
            tabs[#tabs + 1] = {
                id = i, name = (name and name ~= "" and name) or ("Tab " .. i), icon = icon,
                isViewable = q.isViewable, canDeposit = q.canDeposit, numWithdrawals = q.numWithdrawals,
                remainingWithdrawals = q.remainingWithdrawals, canWithdraw = q.canWithdraw,
            }
        end
        if #tabs == 0 and DB().vault.guildBank and DB().vault.guildBank.tabNames then
            for i, t in ipairs(DB().vault.guildBank.tabNames) do
                tabs[#tabs + 1] = {
                    id = i, name = t.name or ("Tab " .. i), icon = t.icon,
                    isViewable = t.isViewable, canDeposit = t.canDeposit, numWithdrawals = t.numWithdrawals,
                    remainingWithdrawals = t.remainingWithdrawals, canWithdraw = t.canWithdraw,
                }
            end
        end
    elseif mode == "WARBAND" then
        if not S.atBank and DB().vault.warbandBank and type(DB().vault.warbandBank.tabs) == "table" and #DB().vault.warbandBank.tabs > 0 then
            for i, t in ipairs(DB().vault.warbandBank.tabs) do
                tabs[#tabs + 1] = { id = i, bagID = t.bagID, name = t.name or ("Tab " .. i), slots = t.slots }
            end
        else
            local wids = CollectBagIDs({ "AccountBankTab" })
            for _, bagID in ipairs(wids) do
                local okN, slots = pcall(C_Container.GetContainerNumSlots, bagID)
                if (okN and type(slots) == "number" and slots > 0) or not S.atBank then
                    local idx = #tabs + 1
                    tabs[idx] = { id = idx, bagID = bagID, name = "Tab " .. idx }
                end
            end
        end
    else
        local key = S.view.char or CharKey()
        local rec = DB().vault.characters[key]
        if not S.atBank and rec and type(rec.bankTabs) == "table" and #rec.bankTabs > 0 then
            for i, t in ipairs(rec.bankTabs) do
                tabs[#tabs + 1] = { id = i, bagID = t.bagID, name = t.name or ("Tab " .. i), slots = t.slots }
            end
        else
            local bids = CollectBagIDs({ "CharacterBankTab", "Bank", "Reagentbank" })
            for _, bagID in ipairs(bids) do
                local okN, slots = pcall(C_Container.GetContainerNumSlots, bagID)
                if (okN and type(slots) == "number" and slots > 0) or not S.atBank then
                    local idx = #tabs + 1
                    local lbl = (bagID == -3 or tostring(bagID):find("Reagent")) and "Reagents" or ("Tab " .. idx)
                    tabs[idx] = { id = idx, bagID = bagID, name = lbl }
                end
            end
        end
    end
    return tabs
end

function U.CanPurchaseVaultTab(mode)
    if not U.IsVaultModeLive(mode) then return false, 0, nil end
    if mode == "GUILD" then
        local numTabs = (GetNumGuildBankTabs and GetNumGuildBankTabs()) or 0
        local maxTabs = MAX_BUY_GUILDBANK_TABS or 8
        if numTabs < maxTabs and (IsGuildLeader and IsGuildLeader()) and GetGuildBankTabCost then
            local cost = GetGuildBankTabCost()
            if cost and cost > 0 then
                return true, cost, function()
                    if StaticPopup_Show then StaticPopup_Show("CONFIRM_BUY_GUILDBANK_TAB")
                    elseif BuyGuildBankTab then pcall(BuyGuildBankTab) end
                end
            end
        end
    elseif mode == "WARBAND" then
        if C_Bank and C_Bank.CanPurchaseBankTab and Enum and Enum.BankType then
            local ok, canBuy = pcall(C_Bank.CanPurchaseBankTab, Enum.BankType.Account)
            if ok and canBuy then
                local cost = 0
                if C_Bank.FetchNextPurchasableBankTabData then
                    local okD, data = pcall(C_Bank.FetchNextPurchasableBankTabData, Enum.BankType.Account)
                    if okD and type(data) == "table" then cost = data.tabCost or 0 end
                end
                return true, cost, function()
                    if C_Bank.PurchaseBankTab then pcall(C_Bank.PurchaseBankTab, Enum.BankType.Account) end
                end
            end
        end
    else
        if C_Bank and C_Bank.CanPurchaseBankTab and Enum and Enum.BankType and Enum.BankType.Character then
            local ok, canBuy = pcall(C_Bank.CanPurchaseBankTab, Enum.BankType.Character)
            if ok and canBuy then
                local cost = 0
                if C_Bank.FetchNextPurchasableBankTabData then
                    local okD, data = pcall(C_Bank.FetchNextPurchasableBankTabData, Enum.BankType.Character)
                    if okD and type(data) == "table" then cost = data.tabCost or 0 end
                end
                return true, cost, function()
                    if C_Bank.PurchaseBankTab then pcall(C_Bank.PurchaseBankTab, Enum.BankType.Character) end
                end
            end
        elseif GetNumBankSlots and GetBankSlotCost then
            local numSlots, full = GetNumBankSlots()
            if not full then
                local cost = GetBankSlotCost(numSlots)
                return true, cost or 0, function()
                    if StaticPopup_Show then StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
                    elseif PurchaseSlot then pcall(PurchaseSlot) end
                end
            end
        end
    end
    return false, 0, nil
end

local function PlayBagWindowSound(isOpen)
    local playFn = _G.PlaySound
    if type(playFn) ~= "function" then return end
    local now = (_G.GetTime and _G.GetTime()) or 0
    if S.lastBagSoundAt and (now - S.lastBagSoundAt) < 0.10 and S.lastBagSoundOpen == (isOpen == true) then
        return
    end
    S.lastBagSoundAt = now
    S.lastBagSoundOpen = (isOpen == true)
    local sk = _G.SOUNDKIT
    local soundId
    if isOpen then
        soundId = (type(sk) == "table" and sk.IG_BACKPACK_OPEN) or 862
    else
        soundId = (type(sk) == "table" and sk.IG_BACKPACK_CLOSE) or 863
    end
    pcall(playFn, soundId, "SFX")
end

function U.EnsureCompanionBankWindow()
    if S.bankWindow then return S.bankWindow end
    local ar, ag, ab = GetAccent()
    local bw = CreateFrame("Frame", "DynamicBagsBankFrame", UIParent, "BackdropTemplate")
    bw:SetFrameStrata("HIGH")
    bw:SetClampedToScreen(true)
    bw:SetMovable(true)
    bw:EnableMouse(true)
    bw:SetSize(620, 540)
    if not InCombatLockdown() then
        bw:SetScale(U.GetActiveWindowScale("bank"))
    end
    Backdrop(bw, COL.panel[1], COL.panel[2], COL.panel[3], COL.panel[4], ar, ag, ab, 0.90)
    if S.window then
        bw:SetPoint("TOPRIGHT", S.window, "TOPLEFT", -10, 0)
    else
        bw:SetPoint("CENTER", UIParent, "CENTER", -220, 0)
    end
    U.EnsureBagSpecialFrames()
    bw:Hide()
    S.bankWindow = bw

    local head = CreateFrame("Frame", nil, bw)
    head:SetPoint("TOPLEFT", bw, "TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", bw, "TOPRIGHT", -1, -1)
    head:SetHeight(98)
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    local function OnVaultDragStop()
        if DB().vaultDocked == false then
            U.SaveTopAlignedPos(bw, "vaultPos")
        else
            U.SaveTopAlignedPos(S.window, "windowPos")
            U.ApplyCompanionAnchor()
        end
    end
    U.MakeFrameDraggable(bw, bw, OnVaultDragStop)
    U.MakeFrameDraggable(head, bw, OnVaultDragStop)
    bw.head = head
    head.bg = head:CreateTexture(nil, "BACKGROUND")
    head.bg:SetAllPoints()
    head.bg:SetColorTexture(0.03, 0.035, 0.048, 1)

    local title = head:CreateFontString(nil, "OVERLAY")
    SetFont(title, 13, "")
    title:SetPoint("TOPLEFT", head, "TOPLEFT", 12, -11)
    local hex = sformat("|cFF%02X%02X%02X", floor(ar * 255 + 0.5), floor(ag * 255 + 0.5), floor(ab * 255 + 0.5))
    title:SetText("|cFFF3F5F8Dynamic|r" .. hex .. "Bank|r")
    bw.title = title

    bw.tabBank = U.NewButton(head, 68, 24, "Bank")
    bw.tabBank:SetPoint("TOPLEFT", head, "TOPLEFT", 110, -6)
    bw.tabWarband = U.NewButton(head, 92, 24, "Warband")
    bw.tabWarband:SetPoint("LEFT", bw.tabBank, "RIGHT", 4, 0)
    bw.tabGuild = U.NewButton(head, 74, 24, "Guild")
    bw.tabGuild:SetPoint("LEFT", bw.tabWarband, "RIGHT", 4, 0)

    local depositBtn = U.NewButton(head, 114, 22, "Deposit Reagents")
    depositBtn:SetScript("OnClick", function()
        if not U.IsVaultModeLive(S.companionMode) then
            Print("Read-Only Snapshot: Visit a Banker to deposit reagents.")
            return
        end
        if C_Bank and C_Bank.AutoDepositItemsIntoBank and Enum and Enum.BankType then
            local bType = (S.companionMode == "WARBAND") and Enum.BankType.Account or Enum.BankType.Character
            pcall(C_Bank.AutoDepositItemsIntoBank, bType)
        elseif DepositReagentBank then
            pcall(DepositReagentBank)
        end
    end)
    bw.depositBtn = depositBtn

    local closeBtn = U.NewButton(head, 26, 24, "x")
    closeBtn:SetPoint("TOPRIGHT", head, "TOPRIGHT", -8, -6)
    closeBtn:SetScript("OnClick", function()
        S.explicitClosing = (S.explicitClosing or 0) + 1
        bw:Hide()
        S.explicitClosing = math.max(0, (S.explicitClosing or 1) - 1)
    end)

    local dockBtn = U.NewIconButton(head, 26, 24, "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_pin.tga", "Pin / Detach DynamicBank Window", "Pinned (Lit): Top-aligned side-by-side to the left of DynamicBags.\nUnpinned (Dim): Detached so you can drag DynamicBank anywhere on screen.")
    dockBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    dockBtn:SetScript("OnClick", function()
        local db = DB()
        if db.vaultDocked == false then
            db.vaultDocked = true
        else
            db.vaultDocked = false
            U.SaveTopAlignedPos(bw, "vaultPos")
        end
        U.ApplyCompanionAnchor()
        U.RenderCompanionBank()
    end)
    bw.dockBtn = dockBtn

    local cfgBtn = U.NewIconButton(head, 26, 24, "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_cog.tga", "DynamicBank Settings (/dbag)", "|cFF34D399Left-Click:|r |cFFE2E8F0Open DynamicBags / DynamicBank workspace.|r\n|cFF38BDF8Right-Click:|r |cFFE2E8F0Quick options sub-menu.|r")
    cfgBtn:SetPoint("RIGHT", dockBtn, "LEFT", -4, 0)
    cfgBtn:RegisterForClicks("AnyUp")
    cfgBtn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            U.ShowMenu(self, {
                { label = "Open DynamicBags Settings", onClick = function() DynamicBags:OpenWorkspace() end },
                { label = "Bank Columns: 10", checked = DB().bankColumns == 10, onClick = function() DB().bankColumns = 10; U.OnSettingChanged("layout") end },
                { label = "Bank Columns: 14", checked = DB().bankColumns == 14, onClick = function() DB().bankColumns = 14; U.OnSettingChanged("layout") end },
                { label = "Bank Columns: 18", checked = DB().bankColumns == 18, onClick = function() DB().bankColumns = 18; U.OnSettingChanged("layout") end },
                { label = "Toggle Alt Tooltip Counts", checked = DB().tooltipCounts, onClick = function() DB().tooltipCounts = not DB().tooltipCounts end },
            }, 210)
        else
            DynamicBags:OpenWorkspace()
        end
    end)
    bw.cfgBtn = cfgBtn

    local ICON_DIR = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\"
    local bankRestackBtn = U.NewIconButton(head, 68, 24, ICON_DIR .. "icon_grid.tga", nil, nil, "Merge")
    bankRestackBtn:SetPoint("RIGHT", cfgBtn, "LEFT", -4, 0)
    bankRestackBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bankRestackBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            local d = DB()
            d.autoMergeOnClose = not (d.autoMergeOnClose == true)
            bankRestackBtn:SetSelected(d.autoMergeOnClose)
            if S.window and S.window.restackBtn then
                S.window.restackBtn:SetSelected(d.autoMergeOnClose)
            end
            Print("Auto-Merge partial stacks on bag/bank close: " .. (d.autoMergeOnClose and "|cFF34D399Enabled|r" or "|cFF94A3B8Off|r"))
            if GameTooltip and GameTooltip:GetOwner() == bankRestackBtn then
                bankRestackBtn:GetScript("OnEnter")(bankRestackBtn)
            end
        else
            U.RestackBank(S.companionMode)
        end
    end)
    bankRestackBtn:SetScript("OnEnter", function(self)
        self.hover = true
        U.StyleButtonState(self)
        local autoState = DB().autoMergeOnClose and "|cFF34D399ON|r" or "|cFF94A3B8OFF|r"
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Merge Bank Stacks", 1, 1, 1)
        GameTooltip:AddLine("Combines split or partial item stacks (e.g. 8x + 5x -> 13x) in your active Bank, Warband Bank, or Guild Bank tab.", 0.80, 0.84, 0.90, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Merge partial bank stacks now|r", 0.886, 0.910, 0.941)
        GameTooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Toggle Auto-Merge when closing bags/bank (" .. autoState .. "|cFFE2E8F0)|r", 0.886, 0.910, 0.941)
        GameTooltip:Show()
    end)
    bankRestackBtn:SetScript("OnLeave", function(self)
        self.hover = false
        U.StyleButtonState(self)
        GameTooltip:Hide()
    end)
    bw.restackBtn = bankRestackBtn

    local _, initBankSortLbl = U.GetSortMode()
    local bankSortBtn = U.AttachDropdownChevron(U.NewButton(head, 100, 24, initBankSortLbl))
    bankSortBtn:SetPoint("RIGHT", bankRestackBtn, "LEFT", -4, 0)
    bankSortBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bankSortBtn:SetScript("OnClick", function(self, button)
        local curMode = U.GetSortMode()
        if button == "RightButton" then
            local nextMode = (curMode == "QUALITY" and "NAME") or (curMode == "NAME" and "SLOT") or "QUALITY"
            U.SetSortMode(nextMode)
        else
            U.ShowMenu(self, {
                { label = "Rarity & iLvl (Default)", checked = (curMode == "QUALITY"), onClick = function() U.SetSortMode("QUALITY") end },
                { label = "Alphabetical (A-Z)",      checked = (curMode == "NAME"),    onClick = function() U.SetSortMode("NAME") end },
                { label = "Manual / Slot Order",     checked = (curMode == "SLOT"),    onClick = function() U.SetSortMode("SLOT") end },
            }, 190)
        end
    end)
    bankSortBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Visual Category Sort Order", 1, 1, 1)
        GameTooltip:AddLine("Orders items inside each category without moving or merging split stacks in your physical bank.", 0.80, 0.84, 0.90, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Choose Sort Order (Rarity & iLvl, A-Z, or Slot Order)|r", 0.886, 0.910, 0.941)
        GameTooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Cycle Sort Order|r", 0.886, 0.910, 0.941)
        GameTooltip:Show()
    end)
    bankSortBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    bw.sortBtn = bankSortBtn

    -- Row 2 inside header: Sub-Tab Selector Bar ([All Tabs] [Tab 1] [Tab 2]... + [Deposit Reagents] + [+ Buy Tab])
    local subBar = CreateFrame("Frame", nil, head)
    subBar:SetPoint("TOPLEFT", head, "TOPLEFT", 10, -38)
    subBar:SetPoint("TOPRIGHT", head, "TOPRIGHT", -10, -38)
    subBar:SetHeight(26)
    bw.subBar = subBar
    bw.subTabBtns = {}

    local statusPill = subBar:CreateFontString(nil, "OVERLAY")
    SetFont(statusPill, 10, "")
    statusPill:SetPoint("RIGHT", subBar, "RIGHT", -2, 0)
    statusPill:SetJustifyH("RIGHT")
    bw.statusPill = statusPill

    local buyTabBtn = U.NewButton(subBar, 80, 22, "+ Buy Tab")
    buyTabBtn:SetPoint("RIGHT", subBar, "RIGHT", -2, 0)
    buyTabBtn:Hide()
    bw.buyTabBtn = buyTabBtn

    depositBtn:SetParent(subBar)
    depositBtn:SetSize(112, 22)
    depositBtn:ClearAllPoints()
    depositBtn:SetPoint("RIGHT", subBar, "RIGHT", -2, 0)

    local bankSB = CreateFrame("EditBox", nil, head, "BackdropTemplate")
    bankSB:SetAutoFocus(false)
    bankSB:SetHeight(24)
    bankSB:SetPoint("TOPLEFT", head, "TOPLEFT", 10, -68)
    bankSB:SetPoint("TOPRIGHT", head, "TOPRIGHT", -10, -68)
    SetFont(bankSB, 11, "")
    bankSB:SetTextColor(0.92, 0.95, 0.99, 1)
    Backdrop(bankSB, 0.059, 0.071, 0.094, 0.98, COL.cardEdge[1], COL.cardEdge[2], COL.cardEdge[3], 1)
    bankSB.placeholder = bankSB:CreateFontString(nil, "OVERLAY")
    SetFont(bankSB.placeholder, 11, "")
    bankSB.placeholder:SetPoint("LEFT", bankSB, "LEFT", 8, 0)
    bankSB.placeholder:SetTextColor(0.45, 0.52, 0.62, 1)
    bankSB.placeholder:SetText("Search bank items, gear sets, ilvl > 610, WUE, BoE...")
    U.AttachSearchClearAndEscape(bankSB, bw)
    bw.searchBox = bankSB

    local area = U.CreateScrollArea(bw)
    area:SetPoint("TOPLEFT", bw, "TOPLEFT", 12, -104)
    area:SetPoint("BOTTOMRIGHT", bw, "BOTTOMRIGHT", -16, 32)
    bw.scrollArea = area

    bw.content = CreateFrame("Frame", nil, area.content)
    bw.content:SetPoint("TOPLEFT", area.content, "TOPLEFT", 0, 0)
    bw.content:SetSize(580, 300)
    area.content._dbagIsScrollContent = true
    bw.content._dbagIsScrollContent = true
    U.MakeFrameDraggable(area.scroll, bw, OnVaultDragStop)
    U.MakeFrameDraggable(bw.content, bw, OnVaultDragStop)
    bw.buttons = {}
    bw.headers = {}

    local foot = CreateFrame("Frame", nil, bw)
    foot:SetPoint("BOTTOMLEFT", bw, "BOTTOMLEFT", 1, 1)
    foot:SetPoint("BOTTOMRIGHT", bw, "BOTTOMRIGHT", -1, 1)
    foot:SetHeight(26)
    foot.bg = foot:CreateTexture(nil, "BACKGROUND")
    foot.bg:SetAllPoints()
    foot.bg:SetColorTexture(0.03, 0.035, 0.048, 1)
    foot.left = foot:CreateFontString(nil, "OVERLAY")
    SetFont(foot.left, 11, "")
    foot.left:SetPoint("LEFT", foot, "LEFT", 12, 0)
    foot.left:SetTextColor(0.68, 0.74, 0.82, 1)
    bw.footer = foot
    U.MakeFrameDraggable(foot, bw, OnVaultDragStop)

    local function AttachBankCanvasDropHandler(frame)
        if not frame then return end
        frame:EnableMouse(true)
        frame:SetScript("OnReceiveDrag", function()
            U.PlaceCursorItemInFreeBankSlot()
        end)
        frame:HookScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and GetCursorInfo and GetCursorInfo() == "item" then
                U.PlaceCursorItemInFreeBankSlot()
            end
        end)
    end
    AttachBankCanvasDropHandler(bw.content)
    AttachBankCanvasDropHandler(area.scroll)
    AttachBankCanvasDropHandler(area.content)
    AttachBankCanvasDropHandler(bw)
    AttachBankCanvasDropHandler(head)
    AttachBankCanvasDropHandler(foot)
    U.AttachWindowScaleHandlers("bank", head, { bw, area, area.scroll, foot })

    local function SelectCompanionTab(mode)
        local db = DB()
        S.companionMode = mode
        if mode == "BANK" or mode == "WARBAND" then
            db.lastBankMode = mode
        end
        S.companionSubTab = U.GetRememberedSubTab and U.GetRememberedSubTab(mode) or 0
        if mode == "GUILD" and S.atGuildBank and (S.companionSubTab or 0) > 0 then
            U.SelectGuildBankTab(S.companionSubTab)
        end
        U.RenderCompanionBank()
    end
    bw.tabBank:SetScript("OnClick", function() SelectCompanionTab("BANK") end)
    bw.tabWarband:SetScript("OnClick", function() SelectCompanionTab("WARBAND") end)
    bw.tabGuild:SetScript("OnClick", function() SelectCompanionTab("GUILD") end)

    bw:SetScript("OnShow", function()
        U.EnsureBagSpecialFrames()
        if not S.escRestoringFromSearch then
            PlayBagWindowSound(true)
        end
        if not InCombatLockdown() then
            U.ApplyWindowScale("bank")
        end
        if not S.companionMode then S.companionMode = "BANK" end
        if S.companionSubTab == nil then
            S.companionSubTab = U.GetRememberedSubTab and U.GetRememberedSubTab(S.companionMode) or 0
        end
        if S._skipNextOnShowRender then return end
        U.RenderCompanionBank()
    end)
    bw:SetScript("OnHide", function()
        if (not S.explicitClosing or S.explicitClosing == 0) and not InCombatLockdown()
            and ((S.search or "") ~= "") and IsStackMatching("CloseSpecialWindows", "CloseWindows") then
            S.escRestoreBank = true
            U.CloseMenu()
            return
        end
        PlayBagWindowSound(false)
        U.CloseMenu()
        S.sessionBankScale = nil
        if not InCombatLockdown() then
            local savedScale = ClampWindowScale(DB().bankScale or 1.0)
            if math.abs((bw.GetScale and bw:GetScale() or 1) - savedScale) > 0.001 then
                bw:SetScale(savedScale)
            end
            if not IsStackMatching("CloseSpecialWindows", "CloseWindows") then
                U.EnsureBagSpecialFrames()
            end
        end
        if S._closingGuildBank or S.atGuildBank then return end
        if S._justClosedGuildBank and GetTime and (GetTime() - S._justClosedGuildBank) < 1.0 then return end
        if DB().autoMergeOnClose == true and not InCombatLockdown() and S.companionMode ~= "GUILD" and U.IsVaultModeLive(S.companionMode) then
            U.RestackBank(S.companionMode)
        end
    end)
    return bw
end

-- Normalises GetGuildBankTabInfo withdrawal math:
--   remainingWithdrawals == -1 -> Unlimited, 0 -> none left today, > 0 -> exact stacks left today.
--   numWithdrawals == 0 -> no withdrawal permission at all.
function U.ComputeGuildTabQuota(name, icon, isViewable, canDeposit, numWithdrawals, remainingWithdrawals, tab)
    local numW = (type(numWithdrawals) == "number" and not IsSecret(numWithdrawals)) and numWithdrawals or nil
    local remW = (type(remainingWithdrawals) == "number" and not IsSecret(remainingWithdrawals)) and remainingWithdrawals or nil
    if IsSecret(isViewable) then isViewable = nil end
    if IsSecret(canDeposit) then canDeposit = nil end
    local canWithdraw
    if remW == nil then
        -- Quota unknown (not streamed yet / secret): fall back to the permission flag only.
        canWithdraw = (isViewable ~= false) and (numW ~= 0)
    else
        canWithdraw = (isViewable ~= false) and (numW ~= 0) and (remW == -1 or remW > 0)
    end
    return {
        name = (type(name) == "string" and name ~= "" and name) or ("Tab " .. tostring(tab or "?")),
        icon = icon,
        isViewable = (isViewable ~= false),
        canDeposit = (canDeposit ~= false) and canDeposit ~= nil,
        numWithdrawals = numW,
        remainingWithdrawals = remW,
        canWithdraw = canWithdraw and true or false,
    }
end

-- Live quota while at the Guild Bank, otherwise the last snapshot.
function U.GetGuildTabQuota(tab)
    if type(tab) ~= "number" or tab < 1 then return nil end
    if S.atGuildBank and type(GetGuildBankTabInfo) == "function" then
        local ok, name, icon, isViewable, canDeposit, numW, remW = pcall(GetGuildBankTabInfo, tab)
        if ok then return U.ComputeGuildTabQuota(name, icon, isViewable, canDeposit, numW, remW, tab) end
    end
    local gb = DB().vault and DB().vault.guildBank
    return gb and gb.tabNames and gb.tabNames[tab] or nil
end

-- Returns plain-English withdrawal text (with colour codes) for a quota table.
function U.FormatGuildWithdrawals(q, short)
    if not q then return "|cFF94A3B8Unknown|r" end
    if q.isViewable == false then return "|cFFF87171View-Only|r" end
    if q.numWithdrawals == 0 then return "|cFFF87171" .. (short and "0 Left" or "0 Left / View-Only") .. "|r" end
    local r = q.remainingWithdrawals
    if r == -1 then return "|cFF22C55EUnlimited|r" end
    if type(r) == "number" then
        if r > 0 then return sformat("|cFFFFFFFF%d Left Today|r", r) end
        return "|cFFF87171" .. (short and "0 Left" or "0 Left / View-Only") .. "|r"
    end
    return "|cFF94A3B8Unknown|r"
end

-- Compact per-tab badge for the Guild Bank sub-tab buttons (live session only).
-- Returns nil when there is nothing useful to show (Unlimited / not streamed yet).
function U.GuildQuotaBadgeText(q)
    if type(q) ~= "table" then return nil end
    if q.isViewable == false then return "|cFFF87171x|r" end
    if q.numWithdrawals == 0 then return "|cFFF871710|r" end
    local r = q.remainingWithdrawals
    if type(r) ~= "number" or r < 0 then return nil end
    if r == 0 then return "|cFFF871710|r" end
    if r <= 2 then return sformat("|cFFF59E0B%d|r", r) end
    return sformat("|cFFE2E8F0%d|r", math.min(r, 99))
end

function U.FormatGuildGoldLimit()
    if type(GetGuildBankWithdrawMoney) ~= "function" then return nil end
    local ok, amt = pcall(GetGuildBankWithdrawMoney)
    if not ok or type(amt) ~= "number" or IsSecret(amt) then return nil end
    if amt < 0 then return "|cFF22C55EUnlimited|r" end
    local txt = (type(GetMoneyString) == "function" and GetMoneyString(amt, true))
        or (type(GetCoinTextureString) == "function" and GetCoinTextureString(amt))
        or sformat("%dg", math.floor(amt / 10000))
    return "|cFFFFFFFF" .. txt .. "|r"
end

function U.SnapshotGuildBank()
    local out = {}
    local tabNames = {}
    if not GetCurrentGuildBankTab or not GetGuildBankItemInfo or not GetGuildBankItemLink then return out end
    local numTabs = (GetNumGuildBankTabs and GetNumGuildBankTabs()) or 0
    local activeTab = GetCurrentGuildBankTab()
    if S.atGuildBank and type(activeTab) == "number" and activeTab >= 1 then
        S.queriedGuildTabs = S.queriedGuildTabs or {}
        S.queriedGuildTabs[activeTab] = true
    end
    local queriedThisPass = {}
    for tab = 1, numTabs do
        local name, icon, isViewable, canDeposit, numWithdrawals, remainingWithdrawals = GetGuildBankTabInfo(tab)
        local q = U.ComputeGuildTabQuota(name, icon, isViewable, canDeposit, numWithdrawals, remainingWithdrawals, tab)
        local canWithdraw = q.canWithdraw
        tabNames[tab] = q
        local tabEntries = {}
        local sawLiveSlotData = false
        if isViewable ~= false then
            for slot = 1, 98 do
                local tex, count, locked = GetGuildBankItemInfo(tab, slot)
                local link = GetGuildBankItemLink(tab, slot)
                if type(link) == "string" and link ~= "" and not IsSecret(link) then
                    sawLiveSlotData = true
                    local itemID = tonumber(link:match("item:(%d+)")) or 0
                    local qlt = (C_Item and C_Item.GetItemInfo and select(3, C_Item.GetItemInfo(link))) or 1
                    tabEntries[#tabEntries + 1] = { itemID, link, count or 1, U.ItemLevelOf(link, itemID), qlt or 1, tab = tab, slot = slot, icon = tex, locked = locked, canWithdraw = canWithdraw }
                elseif tex and not IsSecret(tex) then
                    sawLiveSlotData = true
                    -- Placeholder for uncached Guild Bank slot while server item link streams in
                    tabEntries[#tabEntries + 1] = { 0, nil, count or 1, 0, 1, tab = tab, slot = slot, icon = tex, locked = locked, uncached = true, canWithdraw = canWithdraw }
                end
            end
        end
        if sawLiveSlotData or (S.queriedGuildTabs and S.queriedGuildTabs[tab]) or isViewable == false then
            queriedThisPass[tab] = true
            for _, entry in ipairs(tabEntries) do
                out[#out + 1] = entry
            end
        end
    end
    if numTabs > 0 or #out > 0 or #tabNames > 0 then
        local prev = (DB().vault.guildBank and DB().vault.guildBank.items) or {}
        for _, entry in ipairs(prev) do
            if type(entry) == "table" and entry.tab and not queriedThisPass[entry.tab] then
                local tMeta = tabNames[entry.tab]
                if not tMeta or tMeta.isViewable ~= false then
                    if tMeta then entry.canWithdraw = tMeta.canWithdraw end
                    out[#out + 1] = entry
                end
            end
        end
        DB().vault.guildBank = { items = out, tabNames = tabNames, updated = time and time() or 0 }
    end
    return out
end

function U.RenderCompanionBank(forceRender)
    local bw = U.EnsureCompanionBankWindow()
    if not bw:IsShown() and forceRender ~= true then return end
    local db = DB()
    local mode = S.companionMode or "BANK"
    local subTab = S.companionSubTab or 0
    local isLive = U.IsVaultModeLive(mode)
    bw.isLive = isLive

    -- 1. Style Top Mode Tabs & Sync Sort/Merge Header Controls
    bw.tabBank:SetSelected(mode == "BANK")
    bw.tabWarband:SetSelected(mode == "WARBAND")
    bw.tabGuild:SetSelected(mode == "GUILD")
    bw.tabBank:SetAlpha((U.IsVaultModeLive("BANK") or mode == "BANK") and 1.0 or 0.48)
    bw.tabWarband:SetAlpha((U.IsVaultModeLive("WARBAND") or mode == "WARBAND") and 1.0 or 0.48)
    bw.tabGuild:SetAlpha((U.IsVaultModeLive("GUILD") or mode == "GUILD") and 1.0 or 0.48)
    if bw.sortBtn then
        local _, sortLabel = U.GetSortMode()
        bw.sortBtn:SetLabel(sortLabel)
    end
    if bw.restackBtn then
        bw.restackBtn:SetSelected(db.autoMergeOnClose == true)
        bw.restackBtn:SetAlpha(isLive and 1.0 or 0.55)
    end
    bw.depositBtn:SetShown(isLive and (mode == "BANK" or mode == "WARBAND"))

    -- 2. Keep top subBar clean (status is shown once in the bottom footer)
    bw.statusPill:SetText("")

    -- 3. [+ Buy Tab] Button Check & Deposit Reagents Anchor
    local canBuy, buyCost, buyFn = U.CanPurchaseVaultTab(mode)
    if canBuy and buyFn then
        bw.buyTabBtn:Show()
        bw.depositBtn:ClearAllPoints()
        bw.depositBtn:SetPoint("RIGHT", bw.buyTabBtn, "LEFT", -4, 0)
        bw.buyTabBtn:SetScript("OnClick", function()
            buyFn()
            C_Timer.After(0.6, function()
                if S.atBank then pcall(U.SnapshotBank) end
                if S.atGuildBank then pcall(U.SnapshotGuildBank) end
                U.RenderCompanionBank()
            end)
        end)
        bw.buyTabBtn:SetScript("OnEnter", function(self)
            U.StyleButtonState(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText("Purchase New Bank Tab", 1, 1, 1)
            if buyCost and buyCost > 0 then
                GameTooltip:AddLine("Cost: " .. U.FormatMoneyWithIcons(buyCost), 1, 0.82, 0)
            end
            GameTooltip:Show()
        end)
    else
        bw.buyTabBtn:Hide()
        bw.depositBtn:ClearAllPoints()
        bw.depositBtn:SetPoint("RIGHT", bw.subBar, "RIGHT", -2, 0)
    end

    -- 4. Sub-Tab Selector Buttons ([All] [Tab 1] [Tab 2] ...)
    local tabsMeta = U.GetVaultTabsMeta(mode)
    if subTab < 0 or subTab > #tabsMeta then
        subTab = 0
        S.companionSubTab = 0
    end
    for _, b in ipairs(bw.subTabBtns) do b:Hide() end
    local function EnsureSubBtn(idx)
        local b = bw.subTabBtns[idx]
        if not b then
            b = U.NewButton(bw.subBar, 54, 22, "")
            b:HookScript("OnEnter", function(self)
                if not self._tooltipName then return end
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:SetText(self._tooltipName, 1, 1, 1)
                if self._guildQuota then
                    local q = self._guildQuota
                    GameTooltip:AddDoubleLine("Deposit:", q.canDeposit and "|cFF22C55EYes|r" or "|cFFF87171No|r", 0.58, 0.64, 0.72)
                    GameTooltip:AddDoubleLine("Withdrawals:", U.FormatGuildWithdrawals(q), 0.58, 0.64, 0.72)
                end
                GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Filter view to this tab only.|r", 0.886, 0.910, 0.941)
                GameTooltip:Show()
            end)
            b:HookScript("OnLeave", function() GameTooltip:Hide() end)
            -- Daily withdrawal counter badge (Guild Bank sub-tabs only)
            b.quotaBadge = b:CreateFontString(nil, "OVERLAY")
            SetFont(b.quotaBadge, 8, "OUTLINE")
            b.quotaBadge:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -1)
            b.quotaBadge:SetJustifyH("RIGHT")
            b.quotaBadge:Hide()
            bw.subTabBtns[idx] = b
        end
        return b
    end

    local xOff = 0
    local allBtn = EnsureSubBtn(1)
    allBtn._tooltipName = nil
    allBtn:SetSize(48, 22)
    allBtn:ClearAllPoints()
    allBtn:SetPoint("LEFT", bw.subBar, "LEFT", xOff, 0)
    allBtn:SetLabel("All")
    if allBtn.quotaBadge then allBtn.quotaBadge:Hide() end
    allBtn:SetSelected(subTab == 0)
    allBtn:SetScript("OnClick", function()
        S.companionSubTab = 0
        db.lastSubTabs = db.lastSubTabs or { BANK = 0, WARBAND = 0, GUILD = 0 }
        db.lastSubTabs[mode] = 0
        U.RenderCompanionBank()
    end)
    allBtn:Show()
    xOff = xOff + 52

    for i, tm in ipairs(tabsMeta) do
        local tb = EnsureSubBtn(i + 1)
        local shortLbl = (tm.name == "Reagents" and "Reag") or ("T" .. i)
        tb._tooltipName = tm.name or ("Tab " .. i)
        tb._guildQuota = (mode == "GUILD") and tm or nil
        local badge = (mode == "GUILD" and isLive) and U.GuildQuotaBadgeText(tm) or nil
        local btnW = badge and 46 or 42
        tb:SetSize(btnW, 22)
        tb:ClearAllPoints()
        tb:SetPoint("LEFT", bw.subBar, "LEFT", xOff, 0)
        if tb.label then
            tb.label:ClearAllPoints()
            if badge then
                tb.label:SetPoint("LEFT", tb, "LEFT", 3, 0)
                tb.label:SetPoint("RIGHT", tb, "RIGHT", -16, 0)
            else
                tb.label:SetPoint("LEFT", tb, "LEFT", 6, 0)
                tb.label:SetPoint("RIGHT", tb, "RIGHT", -6, 0)
            end
        end
        tb:SetLabel(shortLbl)
        if tb.quotaBadge then
            if badge then
                tb.quotaBadge:SetText(badge)
                tb.quotaBadge:Show()
            else
                tb.quotaBadge:SetText("")
                tb.quotaBadge:Hide()
            end
        end
        tb:SetSelected(subTab == i)
        tb:SetScript("OnClick", function()
            S.companionSubTab = i
            db.lastSubTabs = db.lastSubTabs or { BANK = 0, WARBAND = 0, GUILD = 0 }
            db.lastSubTabs[mode] = i
            if mode == "GUILD" and S.atGuildBank then
                U.SelectGuildBankTab(i)
            end
            U.RenderCompanionBank()
        end)
        tb:Show()
        xOff = xOff + btnW + 4
    end

    -- 5. Collect and Filter Items by Selected Sub-Tab
    local tuples, label = {}, "Bank"
    local key = S.view.char or CharKey()
    local rec = db.vault.characters[key] or U.GetCharRecord()

    if mode == "WARBAND" then
        local wb = db.vault.warbandBank
        tuples = (wb and wb.items) or {}
        label = "Warband Bank"
    elseif mode == "GUILD" then
        local gb = db.vault.guildBank
        if S.atGuildBank and not (gb and type(gb.items) == "table" and #gb.items > 0) then
            U.SnapshotGuildBank()
            gb = db.vault.guildBank
        end
        tuples = (gb and gb.items) or {}
        label = "Guild Bank"
    else
        tuples = (rec and rec.bank) or {}
        label = ((rec and rec.name) or "Character") .. " - Bank"
    end

    local filtered = {}
    local targetBagID = (subTab > 0 and tabsMeta[subTab] and tabsMeta[subTab].bagID) or nil
    for _, t in ipairs(tuples) do
        if subTab == 0 then
            filtered[#filtered + 1] = t
        elseif mode == "GUILD" and t.tab == subTab then
            filtered[#filtered + 1] = t
        elseif targetBagID and t.bag == targetBagID then
            filtered[#filtered + 1] = t
        end
    end
    if subTab > 0 and tabsMeta[subTab] then
        label = label .. " (" .. (tabsMeta[subTab].name or ("Tab " .. subTab)) .. ")"
    end

    local objs = U.BuildRemoteObjs(filtered, mode == "WARBAND")
    local guildTabNames = (mode == "GUILD" and db.vault.guildBank and db.vault.guildBank.tabNames) or nil
    for idx, t in ipairs(filtered) do
        if objs[idx] then
            if t.tab and t.slot then
                objs[idx].gTab, objs[idx].gSlot = t.tab, t.slot
                local tMeta = guildTabNames and guildTabNames[t.tab]
                objs[idx].canWithdraw = (t.canWithdraw ~= false) and (not tMeta or tMeta.canWithdraw ~= false)
            end
            if t.bag and t.slot then objs[idx].rBag, objs[idx].rSlot = t.bag, t.slot end
        end
    end

    local cols = db.bankColumns or 14
    local layout = U.PackLayout(objs, db.viewMode, cols, db.iconSize, db.categorySpacing, nil)
    local size = db.iconSize
    for _, b in ipairs(bw.buttons) do b:Hide(); b.dbObj = nil end
    for i, p in ipairs(layout.placed) do
        local btn = bw.buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, bw.content)
            btn:RegisterForClicks("AnyUp")
            btn:RegisterForDrag("LeftButton")
            U.BuildOverlay(btn)
            btn.SplitStack = function(selfBtn, splitCount)
                if InCombatLockdown() then return end
                local o = selfBtn.dbObj
                if not o or not splitCount or splitCount <= 0 or not U.IsVaultModeLive(S.companionMode) then return end
                if o.gTab and o.gSlot and o.canWithdraw == false then
                    Print("Cannot withdraw from this Guild Bank tab (view-only or 0 withdrawals remaining).")
                    return
                end
                if o.gTab and o.gSlot and SplitGuildBankItem then
                    pcall(SplitGuildBankItem, o.gTab, o.gSlot, splitCount)
                elseif o.rBag and o.rSlot and C_Container and C_Container.SplitContainerItem then
                    pcall(C_Container.SplitContainerItem, o.rBag, o.rSlot, splitCount)
                end
            end
            btn:SetScript("OnEnter", function(self)
                local o = self.dbObj
                if o and GameTooltip then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if o.link then
                        pcall(GameTooltip.SetHyperlink, GameTooltip, o.link)
                    elseif o.uncached then
                        GameTooltip:SetText("Loading Guild Bank item...", 0.88, 0.91, 0.94)
                    end
                    if not U.IsVaultModeLive(S.companionMode) then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("|cFFF59E0B[Snapshot]|r |cFFE2E8F0Read-only view (not at NPC - transfers disabled).|r", 0.886, 0.910, 0.941)
                    else
                        if o.gTab then
                            local q = U.GetGuildTabQuota(o.gTab)
                            local tabLbl = sformat("Tab %d%s", o.gTab, (q and q.name and q.name ~= ("Tab " .. o.gTab)) and (" (" .. q.name .. ")") or "")
                            local wd = U.FormatGuildWithdrawals(q, true)
                            if q and q.remainingWithdrawals == -1 then
                                wd = "|cFF22C55EUnlimited Withdrawals|r"
                            elseif q and type(q.remainingWithdrawals) == "number" and q.remainingWithdrawals > 0 then
                                wd = sformat("|cFFFFFFFF%d Withdrawal%s Left|r", q.remainingWithdrawals, q.remainingWithdrawals == 1 and "" or "s")
                            elseif q and (q.remainingWithdrawals == 0 or q.numWithdrawals == 0) then
                                wd = "|cFFF871710 Withdrawals Left|r"
                            end
                            GameTooltip:AddLine(" ")
                            GameTooltip:AddLine("|cFF94A3B8" .. tabLbl .. " -|r " .. wd, 0.886, 0.910, 0.941)
                        end
                        if o.gTab and o.canWithdraw == false then
                            GameTooltip:AddLine("|cFFF87171[View-Only Tab]|r |cFFE2E8F0No withdrawals available on this tab today.|r", 0.886, 0.910, 0.941)
                        else
                            if not o.gTab then GameTooltip:AddLine(" ") end
                            GameTooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Withdraw to Bags|r", 0.886, 0.910, 0.941)
                            if (o.count or 1) > 1 then
                                GameTooltip:AddLine("|cFF34D399Shift + Left-Click:|r |cFFE2E8F0Split Stack|r", 0.886, 0.910, 0.941)
                            end
                        end
                    end
                    GameTooltip:Show()
                end
            end)
            btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            btn:SetScript("OnDragStart", function(self)
                local o = self.dbObj
                if not o or not U.IsVaultModeLive(S.companionMode) or InCombatLockdown() then return end
                if o.gTab and o.gSlot and o.canWithdraw == false then return end
                if o.gTab and o.gSlot and PickupGuildBankItem then
                    pcall(PickupGuildBankItem, o.gTab, o.gSlot)
                elseif o.rBag and o.rSlot and C_Container and C_Container.PickupContainerItem then
                    pcall(C_Container.PickupContainerItem, o.rBag, o.rSlot)
                end
            end)
            btn:SetScript("OnReceiveDrag", function(self)
                local o = self.dbObj
                if not o or not U.IsVaultModeLive(S.companionMode) or InCombatLockdown() then return end
                if o.gTab and o.gSlot and PickupGuildBankItem then
                    pcall(PickupGuildBankItem, o.gTab, o.gSlot)
                elseif o.rBag and o.rSlot and C_Container and C_Container.PickupContainerItem then
                    pcall(C_Container.PickupContainerItem, o.rBag, o.rSlot)
                end
            end)
            btn:SetScript("OnClick", function(self, button)
                local o = self.dbObj
                if not o then return end
                if o.link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() and ChatEdit_InsertLink then
                    ChatEdit_InsertLink(o.link)
                    return
                end
                if InCombatLockdown() then return end
                if GetCursorInfo and GetCursorInfo() == "item" and button == "LeftButton" and U.IsVaultModeLive(S.companionMode) then
                    if o.gTab and o.gSlot and PickupGuildBankItem then
                        pcall(PickupGuildBankItem, o.gTab, o.gSlot)
                    elseif o.rBag and o.rSlot and C_Container and C_Container.PickupContainerItem then
                        pcall(C_Container.PickupContainerItem, o.rBag, o.rSlot)
                    end
                    return
                end
                if o.gTab and o.gSlot and o.canWithdraw == false and U.IsVaultModeLive(S.companionMode) then
                    Print("Cannot withdraw from this Guild Bank tab (view-only or 0 withdrawals remaining).")
                    return
                end
                if button == "LeftButton" and IsShiftKeyDown() and U.IsVaultModeLive(S.companionMode) and (o.count or 1) > 1 and StackSplitFrame and StackSplitFrame.OpenStackSplitFrame then
                    StackSplitFrame:OpenStackSplitFrame(o.count, self, "BOTTOMLEFT", "TOPLEFT")
                elseif button == "LeftButton" and U.IsVaultModeLive(S.companionMode) then
                    if o.gTab and o.gSlot and PickupGuildBankItem then
                        pcall(PickupGuildBankItem, o.gTab, o.gSlot)
                    elseif o.rBag and o.rSlot and C_Container and C_Container.PickupContainerItem then
                        pcall(C_Container.PickupContainerItem, o.rBag, o.rSlot)
                    end
                elseif button == "RightButton" then
                    if not U.IsVaultModeLive(S.companionMode) then
                        Print("Cannot transfer items while viewing a read-only snapshot away from the NPC.")
                        return
                    end
                    if o.gTab and o.gSlot and AutoStoreGuildBankItem then
                        pcall(AutoStoreGuildBankItem, o.gTab, o.gSlot)
                    elseif S.atBank and o.rBag and o.rSlot and C_Container and C_Container.UseContainerItem then
                        pcall(C_Container.UseContainerItem, o.rBag, o.rSlot)
                    end
                end
            end)
            bw.buttons[i] = btn
        end
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", bw.content, "TOPLEFT", p.x, -p.y)
        btn:SetSize(size, size)
        btn.dbObj = p.obj
        U.StyleButton(btn, p.obj)
        local baseAlpha = isLive and 1.0 or 0.82
        if isLive and p.obj and p.obj.gTab and p.obj.canWithdraw == false then
            baseAlpha = 0.55
        end
        btn:SetAlpha(baseAlpha)
        btn:Show()
    end
    U.ApplyHeaders(bw.content, bw.headers, layout.sections)
    if (S.search or "") ~= "" then U.ApplySearch() end
    local step = size + SLOT_GAP
    local gridW = max(200, cols * step - SLOT_GAP)
    local width = max(640, gridW + 28)
    local innerW = max(gridW, width - 28)
    local xPad = max(0, floor((innerW - gridW) * 0.5))
    bw.content:ClearAllPoints()
    bw.content:SetPoint("TOPLEFT", bw.scrollArea.content, "TOPLEFT", xPad, 0)
    bw.content:SetSize(gridW, layout.height + 8)
    bw.scrollArea.content:SetSize(innerW, layout.height + 8)
    bw.scrollArea.UpdateThumb()
    local maxH = floor((UIParent:GetHeight() or 900) * 0.82)
    local height = min(maxH, max(300, layout.height + 152))
    if not InCombatLockdown() then bw:SetSize(width, height); U.ApplyCompanionAnchor() end
    local totalSlots = 0
    if mode == "GUILD" then
        local nTabs = (GetNumGuildBankTabs and GetNumGuildBankTabs()) or #tabsMeta
        totalSlots = (subTab > 0) and 98 or (max(1, nTabs) * 98)
    else
        for i, tm in ipairs(tabsMeta) do
            if subTab == 0 or subTab == i then
                local okS, sCnt = pcall(C_Container.GetContainerNumSlots, tm.bagID or 0)
                totalSlots = totalSlots + ((okS and type(sCnt) == "number" and sCnt > 0 and sCnt) or 98)
            end
        end
    end
    if not bw.footer.statusDot then
        local dot = bw.footer:CreateTexture(nil, "OVERLAY")
        dot:SetSize(7, 7)
        bw.footer.statusDot = dot
        local stText = bw.footer:CreateFontString(nil, "OVERLAY")
        SetFont(stText, 11, "")
        stText:SetPoint("LEFT", dot, "RIGHT", 5, 0)
        bw.footer.statusText = stText
    end
    if totalSlots > 0 then
        bw.footer.left:SetText(sformat("Slots: %d/%d   |", max(0, totalSlots - #objs), totalSlots))
    else
        bw.footer.left:SetText(sformat("Stacks: %d   |", #objs))
    end
    bw.footer.statusDot:ClearAllPoints()
    bw.footer.statusDot:SetPoint("LEFT", bw.footer.left, "RIGHT", 10, 0)
    if isLive then
        bw.footer.statusDot:SetColorTexture(0.133, 0.773, 0.369, 1.0) -- Emerald Green
        local status = "|cFF22C55ETransfer Ready|r"
        if mode == "GUILD" then
            if subTab > 0 then
                local q = U.GetGuildTabQuota(subTab)
                if q and q.isViewable == false then
                    bw.footer.statusDot:SetColorTexture(0.937, 0.267, 0.267, 1.0)
                    status = "|cFFEF4444View Only|r"
                elseif q and q.canWithdraw == false then
                    bw.footer.statusDot:SetColorTexture(0.961, 0.620, 0.043, 1.0) -- Amber
                    status = "|cFFF59E0BDeposit Only (0 Withdrawals Left)|r"
                else
                    status = status .. "  |cFF94A3B8-  Withdrawals:|r " .. U.FormatGuildWithdrawals(q, true)
                end
            else
                local open, viewable = 0, 0
                for t = 1, ((GetNumGuildBankTabs and GetNumGuildBankTabs()) or 0) do
                    local q = U.GetGuildTabQuota(t)
                    if q and q.isViewable ~= false then
                        viewable = viewable + 1
                        if q.canWithdraw then open = open + 1 end
                    end
                end
                status = status .. sformat("  |cFF94A3B8-  %d/%d Tabs Withdrawable  -  Hover T1-T%d for Tab Limits|r", open, viewable, math.max(1, viewable))
            end
            local gold = U.FormatGuildGoldLimit()
            if gold then
                status = status .. "  |cFF94A3B8-  Gold Today:|r " .. gold
            end
        end
        bw.footer.statusText:SetText(status)
    else
        bw.footer.statusDot:SetColorTexture(0.937, 0.267, 0.267, 1.0) -- Crimson Red
        bw.footer.statusText:SetText("|cFFEF4444View Only|r")
    end
end

function U.ApplyCompanionAnchor()
    local bw = S.bankWindow
    if not bw or InCombatLockdown() then return end
    local db = DB()
    local bs = (bw.GetScale and bw:GetScale()) or 1
    if bs <= 0 then bs = 1 end
    local function AnchorFlushLeftOfBags()
        local ms = (S.window.GetScale and S.window:GetScale()) or 1
        if ms <= 0 then ms = 1 end
        local uiW = UIParent:GetWidth() or 1920
        local uiH = UIParent:GetHeight() or 1080
        local winLeft = S.window:GetLeft()
        local winTop = S.window:GetTop()
        if winLeft and winTop then
            local winLeftUI = winLeft * ms
            local winTopUI = winTop * ms
            bw:ClearAllPoints()
            bw:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", (winLeftUI - 10 - uiW) / bs, (winTopUI - uiH) / bs)
        else
            bw:ClearAllPoints()
            bw:SetPoint("TOPRIGHT", S.window, "TOPLEFT", -10 / bs, 0)
        end
    end
    if db.vaultDocked ~= false and S.window then
        U.SaveTopAlignedPos(S.window, "windowPos")
        AnchorFlushLeftOfBags()
    else
        local vp = db.vaultPos
        bw:ClearAllPoints()
        if type(vp) == "table" and vp[1] then
            bw:SetPoint(vp[1], UIParent, vp[2] or vp[1], (vp[3] or 0) / bs, (vp[4] or 0) / bs)
        elseif S.window then
            AnchorFlushLeftOfBags()
        else
            bw:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120 / bs, -100 / bs)
        end
    end
    if bw.dockBtn then
        local isDocked = (db.vaultDocked ~= false)
        bw.dockBtn:SetLabel(isDocked and "Docked" or "Free")
        bw.dockBtn:SetSelected(isDocked)
    end
end

function U.GetRememberedSubTab(mode)
    local db = DB()
    if db.rememberLastBankTab ~= false and type(db.lastSubTabs) == "table" then
        local saved = tonumber(db.lastSubTabs[mode])
        if saved and saved >= 0 then
            return floor(saved)
        end
    end
    return 0
end

function U.OpenCompanionBank(mode, explicitSubTab, preserveLastMode)
    local db = DB()
    mode = mode or "BANK"
    S.companionMode = mode
    if not preserveLastMode and (mode == "BANK" or mode == "WARBAND") then
        db.lastBankMode = mode
    end
    if type(explicitSubTab) == "number" then
        S.companionSubTab = explicitSubTab
    else
        S.companionSubTab = U.GetRememberedSubTab(mode)
    end
    if mode == "GUILD" and S.atGuildBank and (S.companionSubTab or 0) > 0 then
        U.SelectGuildBankTab(S.companionSubTab)
    end
    U.ShowWindow()
    local bw = U.EnsureCompanionBankWindow()
    U.ApplyCompanionAnchor()
    local wasShown = bw:IsShown()
    -- Build the correct mode's grid BEFORE the window becomes visible so a stale Guild Bank view never flashes.
    U.RenderCompanionBank(true)
    if not wasShown then
        S._skipNextOnShowRender = true
        bw:Show()
        S._skipNextOnShowRender = nil
    end
end
function U.SetView(char, mode)
    if char == CharKey() then char = nil end
    S.view.char = char
    S.view.mode = mode or "BAGS"
    U.CloseMenu()
    if S.window then
        U.RenderCurrentView()
        if S.scrollArea then S.scrollArea:ScrollToTop() end
    end
end

function U.EnsureWindow()
    if S.window then return S.window end
    local db = DB()
    local ar, ag, ab = GetAccent()
    if #S.bagIDs == 0 then S.bagIDs = U.GetLiveBagIDs() end

    local win = CreateFrame("Frame", "DynamicBagsFrame", UIParent, "BackdropTemplate")
    win:SetFrameStrata("HIGH")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:SetSize(700, 520)
    local initScale = U.GetActiveWindowScale("bag")
    if not InCombatLockdown() then
        win:SetScale(initScale)
    end
    Backdrop(win, COL.panel[1], COL.panel[2], COL.panel[3], COL.panel[4], ar, ag, ab, 0.90)
    local pos = db.windowPos
    if type(pos) == "table" and pos[1] then
        local activeS = (win.GetScale and win:GetScale()) or 1
        if activeS <= 0 then activeS = 1 end
        win:SetPoint(pos[1], UIParent, pos[2] or pos[1], (pos[3] or 0) / activeS, (pos[4] or 0) / activeS)
    else
        win:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -80 / initScale, 100 / initScale)
    end
    U.EnsureBagSpecialFrames()
    win:Hide()
    S.window = win

    -- Header (drag handle) --------------------------------------------------
    local head = CreateFrame("Frame", nil, win)
    head:SetPoint("TOPLEFT", win, "TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", win, "TOPRIGHT", -1, -1)
    head:SetHeight(66)
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function()
        if not InCombatLockdown() and not (GetCursorInfo and GetCursorInfo() == "item") then
            win:StartMoving()
        end
    end)
    local function SaveBagWinPos()
        U.SaveTopAlignedPos(win, "windowPos")
        if S.bankWindow and S.bankWindow:IsShown() and DB().vaultDocked ~= false then
            U.ApplyCompanionAnchor()
        end
    end
    U.MakeFrameDraggable(win, win, SaveBagWinPos)
    U.MakeFrameDraggable(head, win, SaveBagWinPos)
    win.head = head

    head.bg = head:CreateTexture(nil, "BACKGROUND")
    head.bg:SetAllPoints()
    head.bg:SetColorTexture(0.03, 0.035, 0.048, 1)

    local emblem = head:CreateTexture(nil, "ARTWORK")
    emblem:SetSize(20, 20)
    emblem:SetPoint("TOPLEFT", head, "TOPLEFT", 10, -8)
    emblem:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_bags.tga")
    win.emblem = emblem

    local title = head:CreateFontString(nil, "OVERLAY")
    SetFont(title, 13, "")
    title:SetPoint("LEFT", emblem, "RIGHT", 6, 0)
    win.title = title

    win.charBtn = U.AttachDropdownChevron(U.NewButton(head, 96, 24, UnitName("player") or "Player"))
    win.charBtn:SetPoint("TOPLEFT", head, "TOPLEFT", 130, -6)
    win.charBtn:SetScript("OnClick", function(self)
        local entries = {
            { label = (UnitName("player") or "Player") .. " (current)", checked = (S.view.char == nil),
              onClick = function() U.SetView(nil, (S.view.mode == "WARBAND") and "BAGS" or S.view.mode) end },
        }
        for _, c in ipairs(U.GetCharList()) do
            local key = c.key
            local color = c.rec.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.rec.class]
            entries[#entries + 1] = {
                label = (c.rec.name or key) .. " - " .. (c.rec.realm or ""),
                checked = (S.view.char == key),
                color = (color and not (S.view.char == key)) and { color.r, color.g, color.b } or nil,
                onClick = function() U.SetView(key, (S.view.mode == "WARBAND") and "BAGS" or S.view.mode) end,
            }
        end
        if #entries == 1 then
            entries[#entries + 1] = { label = "No alts cached yet - log in on them once", color = { 0.58, 0.64, 0.72 }, onClick = function() end }
        end
        U.ShowMenu(self, entries, 190)
    end)
    win.charBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Character & Alt Vault", 1, 1, 1)
        GameTooltip:AddLine("Switch between your active character and cached alt inventories across your account.", 0.80, 0.84, 0.90, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Select Character Snapshot|r", 0.886, 0.910, 0.941)
        GameTooltip:Show()
    end)
    win.charBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    win.viewBtn = U.AttachDropdownChevron(U.NewButton(head, 74, 24, "Bags"))
    win.viewBtn:SetPoint("LEFT", win.charBtn, "RIGHT", 4, 0)
    win.viewBtn:SetScript("OnClick", function(self)
        U.ShowMenu(self, {
            { label = "Bags Only",               checked = not (S.bankWindow and S.bankWindow:IsShown()), onClick = function()
                S.explicitClosing = (S.explicitClosing or 0) + 1
                if S.bankWindow then S.bankWindow:Hide() end
                S.explicitClosing = math.max(0, (S.explicitClosing or 1) - 1)
                U.SetView(S.view.char, "BAGS")
            end },
            { label = "Bank Window",      checked = (S.bankWindow and S.bankWindow:IsShown() and S.companionMode == "BANK"),    onClick = function() U.OpenCompanionBank("BANK") end },
            { label = "Warband Bank Window",   checked = (S.bankWindow and S.bankWindow:IsShown() and S.companionMode == "WARBAND"), onClick = function() U.OpenCompanionBank("WARBAND") end },
            { label = "Guild Bank Window",checked = (S.bankWindow and S.bankWindow:IsShown() and S.companionMode == "GUILD"),   onClick = function() U.OpenCompanionBank("GUILD") end },
        }, 185)
    end)
    win.viewBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Active Inventory View", 1, 1, 1)
        GameTooltip:AddLine("Open or switch the companion Bank, Warband Bank, or Guild Bank window alongside your bags.", 0.80, 0.84, 0.90, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Choose Inventory / Bank View|r", 0.886, 0.910, 0.941)
        GameTooltip:Show()
    end)
    win.viewBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local closeBtn = U.NewButton(head, 26, 24, "x")
    closeBtn:SetPoint("TOPRIGHT", head, "TOPRIGHT", -8, -6)
    closeBtn:SetScript("OnClick", function() U.HideWindow() end)

    local ICON_DIR = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\"
    local cfgBtn = U.NewIconButton(head, 28, 24, ICON_DIR .. "icon_cog.tga", "DynamicBags Settings (/dbag)", "|cFF34D399Left-Click:|r |cFFE2E8F0Open the 3-tab DynamicBags configuration workspace inside DynamicSuite.|r")
    cfgBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    cfgBtn:SetScript("OnClick", function() DynamicBags:OpenWorkspace() end)

    local restackBtn = U.NewIconButton(head, 72, 24, ICON_DIR .. "icon_grid.tga", nil, nil, "Merge")
    restackBtn:SetPoint("RIGHT", cfgBtn, "LEFT", -4, 0)
    restackBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    restackBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            local d = DB()
            d.autoMergeOnClose = not (d.autoMergeOnClose == true)
            restackBtn:SetSelected(d.autoMergeOnClose)
            Print("Auto-Merge partial stacks on bag close: " .. (d.autoMergeOnClose and "|cFF34D399Enabled|r" or "|cFF94A3B8Off|r"))
            if GameTooltip and GameTooltip:GetOwner() == restackBtn then
                restackBtn:GetScript("OnEnter")(restackBtn)
            end
        else
            U.Restack()
        end
    end)
    restackBtn:SetScript("OnEnter", function(self)
        self.hover = true
        U.StyleButtonState(self)
        local autoState = DB().autoMergeOnClose and "|cFF34D399ON|r" or "|cFF94A3B8OFF|r"
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Merge Partial Stacks", 1, 1, 1)
        GameTooltip:AddLine("Combines split or partial item stacks (e.g. 8x + 5x -> 13x) across your bags.", 0.80, 0.84, 0.90, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Merge partial stacks now|r", 0.886, 0.910, 0.941)
        GameTooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Toggle Auto-Merge when closing bags (" .. autoState .. "|cFFE2E8F0)|r", 0.886, 0.910, 0.941)
        GameTooltip:Show()
    end)
    restackBtn:SetScript("OnLeave", function(self)
        self.hover = false
        U.StyleButtonState(self)
        GameTooltip:Hide()
    end)
    win.restackBtn = restackBtn

    local _, initSortLbl = U.GetSortMode()
    local sortBtn = U.AttachDropdownChevron(U.NewButton(head, 102, 24, initSortLbl))
    sortBtn:SetPoint("RIGHT", restackBtn, "LEFT", -4, 0)
    sortBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    sortBtn:SetScript("OnClick", function(self, button)
        local curMode = U.GetSortMode()
        if button == "RightButton" then
            local nextMode = (curMode == "QUALITY" and "NAME") or (curMode == "NAME" and "SLOT") or "QUALITY"
            U.SetSortMode(nextMode)
        else
            U.ShowMenu(self, {
                { label = "Rarity & iLvl (Default)", checked = (curMode == "QUALITY"), onClick = function() U.SetSortMode("QUALITY") end },
                { label = "Alphabetical (A-Z)",      checked = (curMode == "NAME"),    onClick = function() U.SetSortMode("NAME") end },
                { label = "Manual / Slot Order",     checked = (curMode == "SLOT"),    onClick = function() U.SetSortMode("SLOT") end },
            }, 190)
        end
    end)
    sortBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Visual Category Sort Order", 1, 1, 1)
        GameTooltip:AddLine("Orders items inside each category without moving or merging split stacks in your physical bags.", 0.80, 0.84, 0.90, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Choose Sort Order (Rarity & iLvl, A-Z, or Slot Order)|r", 0.886, 0.910, 0.941)
        GameTooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Cycle Sort Order|r", 0.886, 0.910, 0.941)
        GameTooltip:Show()
    end)
    sortBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    win.sortBtn = sortBtn

    local clearBtn = U.NewIconButton(head, 64, 24, ICON_DIR .. "icon_spark.tga", "Clear New Item Highlights", "|cFF34D399Left-Click:|r |cFFE2E8F0Clear all 'New Item' highlights and move newly looted items into their standard categories.|r", "Clear")
    clearBtn:SetPoint("RIGHT", sortBtn, "LEFT", -4, 0)
    clearBtn:SetScript("OnClick", U.ClearNew)

    -- Row 2: search + preset ----------------------------------------------
    win.presetBtn = U.AttachDropdownChevron(U.NewButton(head, 230, 24, "Preset: Mythic+ & Raid Ready"))
    win.presetBtn:SetPoint("TOPRIGHT", head, "TOPRIGHT", -8, -36)
    win.presetBtn:SetScript("OnClick", function(self)
        local cur = DB().preset
        local function pick(key) return function() U.ApplyPreset(key) end end
        U.ShowMenu(self, {
            { label = PRESETS.MYTHIC.label,    checked = cur == "MYTHIC",    onClick = pick("MYTHIC") },
            { label = PRESETS.COLLECTOR.label, checked = cur == "COLLECTOR", onClick = pick("COLLECTOR") },
            { label = PRESETS.MINIMAL.label,   checked = cur == "MINIMAL",   onClick = pick("MINIMAL") },
            { label = "Custom",                checked = cur == "CUSTOM",    onClick = pick("CUSTOM") },
        }, 230)
    end)

    local sb = CreateFrame("EditBox", nil, head, "BackdropTemplate")
    sb:SetAutoFocus(false)
    sb:SetHeight(24)
    sb:SetPoint("TOPLEFT", head, "TOPLEFT", 10, -36)
    sb:SetPoint("RIGHT", win.presetBtn, "LEFT", -6, 0)
    SetFont(sb, 11, "")
    sb:SetTextColor(0.92, 0.95, 0.99, 1)
    sb:SetTextInsets(8, 8, 0, 0)
    Backdrop(sb, 0.059, 0.071, 0.094, 0.98, COL.cardEdge[1], COL.cardEdge[2], COL.cardEdge[3], 1)
    sb.placeholder = sb:CreateFontString(nil, "OVERLAY")
    SetFont(sb.placeholder, 11, "")
    sb.placeholder:SetPoint("LEFT", sb, "LEFT", 8, 0)
    sb.placeholder:SetTextColor(0.45, 0.52, 0.62, 1)
    sb.placeholder:SetText("Search items, gear sets, ilvl > 610, WUE, BoE...")
    U.AttachSearchClearAndEscape(sb, win)
    win.searchBox = sb

    -- Scrolling content --------------------------------------------------------
    local area = U.CreateScrollArea(win)
    area:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -72)
    area:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -16, 34)
    S.scrollArea = area

    S.liveContent = CreateFrame("Frame", nil, area.content)
    S.liveContent:SetPoint("TOPLEFT", area.content, "TOPLEFT", 0, 0)
    S.liveContent:SetSize(600, 300)
    S.remoteContent = CreateFrame("Frame", nil, area.content)
    S.remoteContent:SetPoint("TOPLEFT", area.content, "TOPLEFT", 0, 0)
    S.remoteContent:SetSize(600, 300)
    S.remoteContent:Hide()
    area.content._dbagIsScrollContent = true
    S.liveContent._dbagIsScrollContent = true
    S.remoteContent._dbagIsScrollContent = true

    -- Footer ------------------------------------------------------------------
    local foot = CreateFrame("Frame", nil, win)
    foot:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 1, 1)
    foot:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -1, 1)
    foot:SetHeight(28)
    foot.bg = foot:CreateTexture(nil, "BACKGROUND")
    foot.bg:SetAllPoints()
    foot.bg:SetColorTexture(0.03, 0.035, 0.048, 1)
    foot.left = foot:CreateFontString(nil, "OVERLAY")
    SetFont(foot.left, 11, "")
    foot.left:SetPoint("LEFT", foot, "LEFT", 12, 0)
    foot.left:SetTextColor(0.68, 0.74, 0.82, 1)
    foot.leftBtn = CreateFrame("Button", nil, foot)
    foot.leftBtn:SetPoint("TOPLEFT", foot.left, "TOPLEFT", -4, 4)
    foot.leftBtn:SetPoint("BOTTOMRIGHT", foot.left, "BOTTOMRIGHT", 4, -4)
    foot.leftBtn:SetFrameLevel(foot:GetFrameLevel() + 2)
    foot.leftBtn:SetScript("OnEnter", function(self)
        if not S.view or S.view.char or S.view.mode ~= "BAGS" then return end
        if InCombatLockdown() and not C_Container then return end
        foot.left:SetTextColor(1, 1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:SetText("Bag Space & Junk Summary", 1, 1, 1)
        local breakdown, junkCount, junkValue = U.GetBagBreakdownAndJunkValue()
        for _, b in ipairs(breakdown) do
            if b.total > 0 then
                local rCol, gCol, bCol = 0.204, 0.827, 0.600
                if b.free == 0 then
                    rCol, gCol, bCol = 0.973, 0.443, 0.443
                elseif b.free <= 3 then
                    rCol, gCol, bCol = 0.984, 0.749, 0.141
                end
                GameTooltip:AddDoubleLine(b.label, sformat("%d / %d Free", b.free, b.total), 0.85, 0.90, 0.96, rCol, gCol, bCol)
            else
                GameTooltip:AddDoubleLine(b.label, "Not Equipped", 0.58, 0.64, 0.72, 0.58, 0.64, 0.72)
            end
        end
        GameTooltip:AddLine(" ")
        if junkCount > 0 then
            GameTooltip:AddDoubleLine(sformat("Grey Junk Value (%d):", junkCount), U.FormatMoneyWithIcons(junkValue), 0.85, 0.90, 0.96, 1, 1, 1)
        else
            GameTooltip:AddDoubleLine("Grey Junk Value:", "|cFF64748BNone|r", 0.85, 0.90, 0.96, 0.58, 0.64, 0.72)
        end
        GameTooltip:Show()
    end)
    foot.leftBtn:SetScript("OnLeave", function()
        foot.left:SetTextColor(0.68, 0.74, 0.82, 1)
        GameTooltip:Hide()
    end)
    U.MakeFrameDraggable(foot, win, function() U.SaveTopAlignedPos(win, "windowPos") end)
    U.MakeFrameDraggable(foot.leftBtn, win, function() U.SaveTopAlignedPos(win, "windowPos") end)
    U.MakeFrameDraggable(area.scroll, win, function() U.SaveTopAlignedPos(win, "windowPos") end)
    U.MakeFrameDraggable(S.liveContent, win, function() U.SaveTopAlignedPos(win, "windowPos") end)

    local function AttachCanvasDropHandler(frame)
        if not frame then return end
        frame:EnableMouse(true)
        frame:SetScript("OnReceiveDrag", function()
            U.PlaceCursorItemInFreeSlot()
        end)
        frame:HookScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and GetCursorInfo and GetCursorInfo() == "item" then
                U.PlaceCursorItemInFreeSlot()
            end
        end)
    end
    AttachCanvasDropHandler(S.liveContent)
    AttachCanvasDropHandler(area.scroll)
    AttachCanvasDropHandler(area.content)
    AttachCanvasDropHandler(win)
    AttachCanvasDropHandler(head)
    AttachCanvasDropHandler(foot)
    AttachCanvasDropHandler(foot.leftBtn)
    U.AttachWindowScaleHandlers("bag", head, { win, area, area.scroll, foot, foot.leftBtn })

    local goldBtn = CreateFrame("Button", nil, foot)
    goldBtn:SetPoint("RIGHT", foot, "RIGHT", -12, 0)
    goldBtn:SetSize(155, 24)

    local currBtn = CreateFrame("Button", nil, foot)
    currBtn:SetPoint("RIGHT", goldBtn, "LEFT", -10, 0)
    currBtn:SetPoint("LEFT", foot.left, "RIGHT", 10, 0)
    currBtn:SetHeight(24)
    currBtn.text = currBtn:CreateFontString(nil, "OVERLAY")
    SetFont(currBtn.text, 11, "")
    currBtn.text:SetPoint("RIGHT", currBtn, "RIGHT", 0, 0)
    currBtn.text:SetJustifyH("RIGHT")
    currBtn.text:SetWordWrap(false)
    foot.currText = currBtn.text
    currBtn:SetScript("OnClick", function(self) U.ShowCurrencyPickerMenu(self) end)
    currBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Tracked Currencies", 1, 1, 1)
        for _, c in ipairs(U.GetTrackedCurrenciesList()) do
            local ic = c.icon and sformat("|T%s:14:14:0:0:64:64:5:59:5:59|t ", tostring(c.icon)) or ""
            GameTooltip:AddDoubleLine(ic .. (c.name or "Currency"), BreakUpLargeNumbers and BreakUpLargeNumbers(c.quantity or 0) or tostring(c.quantity or 0), 0.85, 0.90, 0.96, 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Choose which currencies to display|r", 0.886, 0.910, 0.941)
        GameTooltip:Show()
    end)
    currBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    goldBtn.text = goldBtn:CreateFontString(nil, "OVERLAY")
    SetFont(goldBtn.text, 11, "")
    goldBtn.text:SetPoint("RIGHT", goldBtn, "RIGHT", 0, 0)
    foot.gold = goldBtn.text
    goldBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Gold", 1, 1, 1)
        local cur = GetMoney and GetMoney() or 0
        local delta = cur - (S.sessionStartMoney or cur)
        local sign = delta >= 0 and "+" or "-"
        local shown = U.FormatMoneyWithIcons(math.abs(delta))
        GameTooltip:AddDoubleLine("Session change", sign .. " " .. shown, 0.8, 0.84, 0.9, delta >= 0 and 0.3 or 1, delta >= 0 and 1 or 0.4, delta >= 0 and 0.5 or 0.4)
        if C_Bank and C_Bank.FetchDepositedMoney and Enum and Enum.BankType then
            local ok, wb = pcall(C_Bank.FetchDepositedMoney, Enum.BankType.Account)
            if ok and type(wb) == "number" then
                GameTooltip:AddDoubleLine("Warband Bank", U.FormatMoneyWithIcons(wb), 0.8, 0.84, 0.9, 1, 1, 1)
            end
        end
        local chars = U.GetCharList and U.GetCharList() or {}
        if #chars > 0 then
            GameTooltip:AddLine(" ")
            local totalAltGold = cur
            for _, c in ipairs(chars) do
                local cg = (c.rec and type(c.rec.gold) == "number") and c.rec.gold or 0
                totalAltGold = totalAltGold + cg
                local col = (c.rec and c.rec.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.rec.class]) or { r = 0.82, g = 0.86, b = 0.92 }
                GameTooltip:AddDoubleLine(c.rec.name or c.key, U.FormatMoneyWithIcons(cg), col.r, col.g, col.b, 1, 1, 1)
            end
            GameTooltip:AddDoubleLine("Characters Total", U.FormatMoneyWithIcons(totalAltGold), 0.95, 0.82, 0.25, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    goldBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    S.footer = foot

    win:SetScript("OnShow", function()
        U.EnsureBagSpecialFrames()
        if not S.escRestoringFromSearch then
            PlayBagWindowSound(true)
        end
        if not InCombatLockdown() then
            U.ApplyWindowScale("bag")
        end
        U.RenderCurrentView()
        if U.UpdateQuickOpenButton then U.UpdateQuickOpenButton() end
    end)
    win:SetScript("OnHide", function()
        if (not S.explicitClosing or S.explicitClosing == 0) and not InCombatLockdown()
            and ((S.search or "") ~= "") and IsStackMatching("CloseSpecialWindows", "CloseWindows") then
            S.escRestoreBag = true
            U.CloseMenu()
            return
        end
        PlayBagWindowSound(false)
        U.CloseMenu()
        S.sessionBagScale = nil
        if not InCombatLockdown() then
            local savedScale = ClampWindowScale(DB().bagScale or 1.0)
            if math.abs((win.GetScale and win:GetScale() or 1) - savedScale) > 0.001 then
                win:SetScale(savedScale)
            end
            ApplySavedTopAlignedPos(win, "windowPos")
            if not IsStackMatching("CloseSpecialWindows", "CloseWindows") then
                U.EnsureBagSpecialFrames()
            end
        end
        S.autoOpened = {}
        if U.UpdateQuickOpenButton then U.UpdateQuickOpenButton() end
        if DB().autoMergeOnClose == true and not InCombatLockdown() then
            U.Restack()
        end
    end)

    U.ApplyWindowTheme()
    return win
end

function U.ApplyWindowTheme()
    local win = S.window
    if not win then return end
    local ar, ag, ab = GetAccent()
    local hex = sformat("|cFF%02X%02X%02X", floor(ar * 255 + 0.5), floor(ag * 255 + 0.5), floor(ab * 255 + 0.5))
    win:SetBackdropBorderColor(ar, ag, ab, 0.90)
    win.title:SetText("|cFFF3F5F8Dynamic|r" .. hex .. "Bags|r")
    if S.quickOpenBtn and S.quickOpenBtn.ApplyAccentStyle then
        S.quickOpenBtn:ApplyAccentStyle()
    end
    U.RefreshStyledButtons()
end

local function NotifyCombatDeferredBagToggle(actionWord)
    local now = GetTime and GetTime() or 0
    if now - (S.lastCombatBagNotice or -10) >= 2.0 then
        S.lastCombatBagNotice = now
        Print("Bag window " .. (actionWord or "toggle") .. " queued until combat ends.")
    end
end

function U.RefreshAllSlotLocks()
    for bagID, bc in pairs(S.slotCache) do
        if type(bc) == "table" then
            for slotID, e in pairs(bc) do
                if type(e) == "table" then
                    local info = U.GetSlotInfo(bagID, slotID)
                    e.locked = info and info.isLocked and true or false
                    local btn = S.buttons[bagID .. ":" .. slotID]
                    if btn and btn.dbIcon then
                        btn.dbIcon:SetDesaturated(e.locked)
                    end
                end
            end
        end
    end
end

function U.ShowWindow()
    if S.window and not (S.window.IsProtected and S.window:IsProtected()) then
        S.pendingCombatVis = nil
        if not S.window:IsShown() then S.window:Show() end
        U.RefreshAllSlotLocks()
        return
    end
    if InCombatLockdown() then
        if not (S.window and S.window:IsShown()) then
            S.pendingCombatVis = "SHOW"
            NotifyCombatDeferredBagToggle("open")
        else
            S.pendingCombatVis = nil
        end
        return
    end
    S.pendingCombatVis = nil
    local win = U.EnsureWindow()
    if not win:IsShown() then win:Show() end
    U.RefreshAllSlotLocks()
end

function U.HideWindow()
    if S.window and not (S.window.IsProtected and S.window:IsProtected()) then
        S.pendingCombatVis = nil
        S.pendingCombatHideBank = nil
        if S.window:IsShown() then
            S.explicitClosing = (S.explicitClosing or 0) + 1
            S.window:Hide()
            S.explicitClosing = math.max(0, (S.explicitClosing or 1) - 1)
        end
        return
    end
    if InCombatLockdown() then
        if S.window and S.window:IsShown() then
            S.pendingCombatVis = "HIDE"
            NotifyCombatDeferredBagToggle("close")
        else
            S.pendingCombatVis = nil
        end
        return
    end
    S.pendingCombatVis = nil
    S.pendingCombatHideBank = nil
    if S.window and S.window:IsShown() then
        S.explicitClosing = (S.explicitClosing or 0) + 1
        S.window:Hide()
        S.explicitClosing = math.max(0, (S.explicitClosing or 1) - 1)
    end
end

function U.ToggleWindow()
    if S.window and not (S.window.IsProtected and S.window:IsProtected()) then
        S.pendingCombatVis = nil
        S.pendingCombatHideBank = nil
        if S.window:IsShown() then
            S.explicitClosing = (S.explicitClosing or 0) + 1
            if S.bankWindow and S.bankWindow:IsShown() and (not InCombatLockdown() or not (S.bankWindow.IsProtected and S.bankWindow:IsProtected())) then
                S.bankWindow:Hide()
            end
            S.window:Hide()
            S.explicitClosing = math.max(0, (S.explicitClosing or 1) - 1)
        else
            S.window:Show()
        end
        return
    end
    if InCombatLockdown() then
        local isCurrentlyShown = (S.window and S.window:IsShown()) and true or false
        if S.pendingCombatVis then
            S.pendingCombatVis = nil
            S.pendingCombatHideBank = nil
        else
            S.pendingCombatVis = isCurrentlyShown and "HIDE" or "SHOW"
            S.pendingCombatHideBank = (isCurrentlyShown and S.bankWindow and S.bankWindow:IsShown()) and true or false
            NotifyCombatDeferredBagToggle(isCurrentlyShown and "close" or "open")
        end
        return
    end
    S.pendingCombatVis = nil
    S.pendingCombatHideBank = nil
    local win = U.EnsureWindow()
    if win:IsShown() then
        S.explicitClosing = (S.explicitClosing or 0) + 1
        if S.bankWindow and S.bankWindow:IsShown() then
            S.bankWindow:Hide()
        end
        win:Hide()
        S.explicitClosing = math.max(0, (S.explicitClosing or 1) - 1)
    else
        win:Show()
    end
end

-- ============================================================================
-- 8. EMBEDDED 3-TAB CONFIGURATION WORKSPACE (Design\GEOMETRY_STANDARD.md)
--    34px #0B0D12 bevel at (14,-10)/(-16,-10), 26px tabs, 1:1 cards, 4px slate scrollbar.
-- ============================================================================

local TAB_DEFS = {
    { id = 1, label = "Layout & Categories" },
    { id = 2, label = "Item Badges & Glow" },
    { id = 3, label = "Automation & Alt Vault" },
}

function U.CreateSectionBox(parent, titleText, subtitleText)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box.innerPadX = 14
    Backdrop(box, COL.panel[1], COL.panel[2], COL.panel[3], COL.panel[4], COL.cardEdge[1], COL.cardEdge[2], COL.cardEdge[3], 1.0)
    box.cards = {}
    box.hdr = U.CreateSectionHeader(box, -10, titleText, subtitleText)
    return box
end

function U.CreateSectionHeader(parent, arg2, arg3, subtitleText, padOverride)
    local titleText, yOffset
    if type(arg2) == "number" then
        yOffset = arg2
        titleText = arg3
    else
        titleText = arg2
        yOffset = arg3
    end

    local padX = padOverride or (parent and parent.innerPadX) or 0
    local y = yOffset or 0
    local ar, ag, ab = GetAccent()
    local hasSub = (subtitleText and subtitleText ~= "")

    local hdr = CreateFrame("Frame", nil, parent)
    hdr:SetHeight(hasSub and 36 or 20)
    hdr.hasSub = hasSub
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
    hdr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -padX, y)

    -- Vertical Pill: 3px wide x 34px tall (when subtitle present) solid texture in 100% Suite Accent at TOPLEFT (0, -1)
    local leftBar = hdr:CreateTexture(nil, "ARTWORK")
    leftBar:SetSize(3, hasSub and 34 or 16)
    leftBar:SetPoint("TOPLEFT", hdr, "TOPLEFT", 0, -1)
    leftBar:SetColorTexture(ar, ag, ab, 1.0)
    hdr.leftBar = leftBar
    hdr.bar = leftBar

    -- Bottom Underline: 1px tall solid texture in Suite Accent (a = 0.35) anchored from BOTTOMLEFT of vertical pill to BOTTOMRIGHT of header frame
    local botLine = hdr:CreateTexture(nil, "ARTWORK")
    botLine:SetHeight(1)
    botLine:SetPoint("TOPLEFT", leftBar, "BOTTOMLEFT", 0, 0)
    botLine:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
    botLine:SetColorTexture(ar, ag, ab, 0.35)
    hdr.botLine = botLine
    hdr.line = botLine

    -- Line 1: 11pt Bold Uppercase Suite Accent text anchored 8px right of vertical pill
    local title = hdr:CreateFontString(nil, "OVERLAY")
    SetFont(title, 11, "")
    if hasSub then
        title:SetPoint("TOPLEFT", leftBar, "TOPRIGHT", 8, 0)
    else
        title:SetPoint("LEFT", leftBar, "RIGHT", 8, 0)
    end
    title:SetText(string.upper(titleText or ""))
    title:SetTextColor(ar, ag, ab, 1.0)
    hdr.title = title
    hdr.label = title

    if hasSub then
        local sub = hdr:CreateFontString(nil, "OVERLAY")
        SetFont(sub, 10, "")
        sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
        sub:SetPoint("RIGHT", hdr, "RIGHT", -12, 0)
        sub:SetJustifyH("LEFT")
        sub:SetWordWrap(false)
        sub:SetTextColor(0.64, 0.70, 0.78, 1.0)
        sub:SetText(subtitleText)
        hdr.subtitle = sub
    end

    function hdr:SetText(newText)
        if self.title then
            self.title:SetText(string.upper(newText or ""))
        end
    end

    function hdr:RefreshAccent()
        local r, g, b = GetAccent()
        if self.leftBar then self.leftBar:SetColorTexture(r, g, b, 1.0) end
        if self.botLine then self.botLine:SetColorTexture(r, g, b, 0.35) end
        if self.title then
            SetFont(self.title, 11, "")
            self.title:SetTextColor(r, g, b, 1.0)
        end
        if self.subtitle then
            SetFont(self.subtitle, 10, "")
            self.subtitle:SetTextColor(0.64, 0.70, 0.78, 1.0)
        end
    end

    return hdr, y - (hasSub and 44 or 28)
end
U.AddSectionHeader = U.CreateSectionHeader
DynamicBags.CreateSectionHeader = U.CreateSectionHeader

function U.AddSection(page, titleText, subtitleText)
    page.sections = page.sections or {}
    local sec = U.CreateSectionBox(page, titleText, subtitleText)
    page.sections[#page.sections + 1] = sec
    page.currentSection = sec
    return sec
end

function U.AddCard(page, spec)
    if not page.currentSection then
        U.AddSection(page, spec.section or "SETTINGS")
    end
    local sec = page.currentSection
    local card = CreateFrame("Frame", nil, sec, "BackdropTemplate")
    Backdrop(card, 0.078, 0.090, 0.122, 0.95, COL.cardEdge[1], COL.cardEdge[2], COL.cardEdge[3], 1)
    card.spec = spec
    card.sectionBox = sec

    card.title = card:CreateFontString(nil, "OVERLAY")
    SetFont(card.title, 11, "")
    card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -10)
    card.title:SetJustifyH("LEFT")
    card.title:SetWordWrap(false)
    local ar, ag, ab = GetAccent()
    card.title:SetTextColor(0.97, 0.98, 1.0, 1.0)
    card.title:SetText(spec.title or "")

    card.desc = card:CreateFontString(nil, "OVERLAY")
    SetFont(card.desc, 10, "")
    card.desc:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
    card.desc:SetJustifyH("LEFT")
    card.desc:SetWordWrap(true)
    if card.desc.SetMaxLines then card.desc:SetMaxLines(2) end
    card.desc:SetTextColor(0.58, 0.64, 0.72, 1)
    card.desc:SetText(spec.desc or "")

    local IsNegativePillOption = U.IsNegativePillOption

    local kind = spec.kind
    if kind == "pills" or kind == "toggle" then
        local options = spec.options
        if kind == "toggle" then
            options = {
                { value = false, label = "Off", width = 68 },
                { value = true,  label = "Enabled", width = 84 },
            }
        end
        local holder = CreateFrame("Frame", nil, card)
        local totalW = 0
        for i, opt in ipairs(options) do
            local bw = (kind == "toggle" and (opt.width or 76)) or spec.pillWidth or 128
            totalW = totalW + bw + ((i > 1) and 4 or 0)
        end
        holder:SetSize(totalW, 26)
        holder:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -17)
        card.btns = {}
        local xCur = 0
        for i, opt in ipairs(options) do
            local bw = (kind == "toggle" and (opt.width or 76)) or spec.pillWidth or 128
            local b = U.NewButton(holder, bw, 26, opt.label)
            b.isPillOption = true
            b.optValue = opt.value
            b.optLabel = opt.label
            b.isNegativeOpt = IsNegativePillOption(opt.value, opt.label)
            b:SetPoint("LEFT", holder, "LEFT", xCur, 0)
            xCur = xCur + bw + 4
            b:SetScript("OnClick", function()
                spec.set(opt.value)
                card:Refresh()
            end)
            card.btns[i] = b
        end
        card.control = holder
        if spec.subDrawer then
            local sd = spec.subDrawer
            local chevBar = CreateFrame("Button", nil, card, "BackdropTemplate")
            chevBar:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -52)
            chevBar:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -52)
            chevBar:SetHeight(24)
            Backdrop(chevBar, 0.055, 0.065, 0.090, 0.96, COL.cellEdge[1], COL.cellEdge[2], COL.cellEdge[3], 1)

            local chevIcon = chevBar:CreateTexture(nil, "ARTWORK")
            chevIcon:SetSize(11, 11)
            local chevLabel = chevBar:CreateFontString(nil, "OVERLAY")
            SetFont(chevLabel, 10, "")
            chevLabel:SetText(sd.buttonLabel or "Sub-Settings (1)")

            local totalW = 11 + 6 + 96
            chevIcon:SetPoint("LEFT", chevBar, "CENTER", -floor(totalW * 0.5), 0)
            chevLabel:SetPoint("LEFT", chevIcon, "RIGHT", 6, 0)
            chevBar.chevIcon = chevIcon
            chevBar.chevLabel = chevLabel
            card.chevBar = chevBar

            local subCard = CreateFrame("Frame", nil, card, "BackdropTemplate")
            subCard:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -82)
            subCard:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -82)
            subCard:SetHeight(48)
            Backdrop(subCard, COL.panel[1], COL.panel[2], COL.panel[3], COL.panel[4], COL.cellEdge[1], COL.cellEdge[2], COL.cellEdge[3], 1)

            local leftBar = subCard:CreateTexture(nil, "OVERLAY")
            leftBar:SetWidth(2)
            leftBar:SetPoint("TOPLEFT", subCard, "TOPLEFT", 0, -1)
            leftBar:SetPoint("BOTTOMLEFT", subCard, "BOTTOMLEFT", 0, 1)
            leftBar:SetColorTexture(ar, ag, ab, 1.0)
            subCard.leftBar = leftBar

            local pip = subCard:CreateTexture(nil, "OVERLAY")
            pip:SetSize(5, 5)
            pip:SetPoint("LEFT", subCard, "LEFT", 14, 0)
            pip:SetColorTexture(ar, ag, ab, 1.0)
            subCard.pip = pip

            local sTitle = subCard:CreateFontString(nil, "OVERLAY")
            SetFont(sTitle, 11, "")
            sTitle:SetPoint("LEFT", pip, "RIGHT", 8, 0)
            sTitle:SetTextColor(0.95, 0.96, 0.99, 1.0)
            sTitle:SetText(sd.title or "Funding Priority")
            subCard.title = sTitle

            local sOpts = sd.options or {}
            local sw = sd.pillWidth or 138
            local sHolder = CreateFrame("Frame", nil, subCard)
            sHolder:SetSize(#sOpts * sw + (#sOpts - 1) * 4, 24)
            sHolder:SetPoint("RIGHT", subCard, "RIGHT", -12, 0)
            subCard.btns = {}
            for i, sOpt in ipairs(sOpts) do
                local sb = U.NewButton(sHolder, sw, 24, sOpt.label)
                sb.isPillOption = true
                sb.optValue = sOpt.value
                sb.optLabel = sOpt.label
                sb.isNegativeOpt = IsNegativePillOption(sOpt.value, sOpt.label)
                sb:SetPoint("LEFT", sHolder, "LEFT", (i - 1) * (sw + 4), 0)
                sb:SetScript("OnClick", function()
                    sd.set(sOpt.value)
                    card:Refresh()
                end)
                subCard.btns[i] = sb
            end
            card.subCard = subCard

            local function StyleChevBar()
                local r, g, b = GetAccent()
                local isExp = sd.isExpanded and sd.isExpanded() or false
                chevIcon:SetTexture(isExp
                    and "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga"
                    or "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga")
                if chevBar.hover then
                    chevBar:SetBackdropColor(r * 0.22, g * 0.22, b * 0.22, 0.98)
                    chevBar:SetBackdropBorderColor(r, g, b, 1.0)
                    chevIcon:SetVertexColor(1, 1, 1, 1)
                    chevLabel:SetTextColor(1, 1, 1, 1)
                elseif isExp then
                    chevBar:SetBackdropColor(r * 0.14, g * 0.14, b * 0.14, 0.96)
                    chevBar:SetBackdropBorderColor(r, g, b, 0.95)
                    chevIcon:SetVertexColor(r, g, b, 1)
                    chevLabel:SetTextColor(0.95, 0.97, 1.0, 1)
                else
                    chevBar:SetBackdropColor(0.055, 0.065, 0.090, 0.96)
                    chevBar:SetBackdropBorderColor(COL.cellEdge[1], COL.cellEdge[2], COL.cellEdge[3], 1)
                    chevIcon:SetVertexColor(0.68, 0.74, 0.82, 1)
                    chevLabel:SetTextColor(0.68, 0.74, 0.82, 1)
                end
            end
            chevBar.StyleChevBar = StyleChevBar
            chevBar:SetScript("OnEnter", function(self) self.hover = true; StyleChevBar() end)
            chevBar:SetScript("OnLeave", function(self) self.hover = false; StyleChevBar() end)
            chevBar:SetScript("OnClick", function()
                if sd.toggleExpanded then sd.toggleExpanded() end
                U.RefreshWorkspace()
            end)
        end
        function card:Refresh()
            local cur = spec.get()
            if kind == "toggle" then cur = cur and true or false end
            for i, opt in ipairs(options) do self.btns[i]:SetSelected(cur == opt.value) end
            if self.chevBar and spec.subDrawer then
                local sd = spec.subDrawer
                local r, g, b = GetAccent()
                if self.subCard then
                    if self.subCard.leftBar then self.subCard.leftBar:SetColorTexture(r, g, b, 1.0) end
                    if self.subCard.pip then self.subCard.pip:SetColorTexture(r, g, b, 1.0) end
                    local sCur = sd.get and sd.get()
                    for i, sOpt in ipairs(sd.options or {}) do
                        if self.subCard.btns[i] then
                            self.subCard.btns[i]:SetSelected(sCur == sOpt.value)
                        end
                    end
                end
                if self.chevBar.StyleChevBar then self.chevBar.StyleChevBar() end
            end
        end
    elseif kind == "stepper" or kind == "slider" then
        local holder = CreateFrame("Frame", nil, card)
        holder:SetSize(256, 26)
        holder:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -17)

        local minVal = spec.min or 1
        local maxVal = spec.max or 20
        local stepVal = spec.step or 1

        card.valueText = holder:CreateFontString(nil, "OVERLAY")
        SetFont(card.valueText, 11, "")
        card.valueText:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
        card.valueText:SetWidth(52)
        card.valueText:SetJustifyH("RIGHT")
        card.valueText:SetWordWrap(false)
        card.valueText:SetTextColor(ar, ag, ab, 1.0)

        local slider = CreateFrame("Slider", nil, holder)
        slider:SetPoint("LEFT", holder, "LEFT", 0, 0)
        slider:SetPoint("RIGHT", card.valueText, "LEFT", -10, 0)
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

        local fill = slider:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("TOPLEFT", slider, "TOPLEFT", 0, 0)
        fill:SetPoint("BOTTOMLEFT", slider, "BOTTOMLEFT", 0, 0)
        fill:SetWidth(1)
        fill:SetColorTexture(ar, ag, ab, 0.85)
        slider.FillBar = fill

        local thumb = slider:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(6, 14)
        thumb:SetColorTexture(0.97, 0.98, 1.00, 1.0)
        if thumb.SetSnapToPixelGrid then
            thumb:SetSnapToPixelGrid(false)
            thumb:SetTexelSnappingBias(0)
        end
        slider:SetThumbTexture(thumb)

        local updating = false
        local isDragging = false
        local lastCommittedValue = nil

        local function SnapValue(v)
            v = max(minVal, min(maxVal, v or minVal))
            if stepVal and stepVal > 0 then
                v = floor(((v - minVal) / stepVal) + 0.5) * stepVal + minVal
            end
            return max(minVal, min(maxVal, v))
        end

        local function UpdateFillAndThumb(rawVal)
            local r, g, b = GetAccent()
            fill:SetColorTexture(r, g, b, 0.85)
            card.valueText:SetTextColor(r, g, b, 1.0)
            if isDragging or slider:IsMouseOver() then
                thumb:SetColorTexture(r, g, b, 1.0)
            else
                thumb:SetColorTexture(0.97, 0.98, 1.00, 1.0)
            end
            local v = rawVal or slider:GetValue() or minVal
            local pct = (maxVal > minVal) and ((v - minVal) / (maxVal - minVal)) or 0
            pct = max(0, min(1, pct))
            local tw = slider:GetWidth()
            if not tw or tw <= 0 then tw = 194 end
            fill:SetWidth(max(1, pct * tw))
        end

        slider:SetScript("OnValueChanged", function(_, value)
            if updating then return end
            local stepped = SnapValue(value)
            card.valueText:SetText(spec.fmt and sformat(spec.fmt, stepped) or tostring(stepped))
            UpdateFillAndThumb(value)
            if stepped ~= lastCommittedValue then
                lastCommittedValue = stepped
                spec.set(stepped)
            end
        end)

        local function UpdateSliderFromCursor()
            if isDragging and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                isDragging = false
                slider:SetScript("OnUpdate", nil)
                card:Refresh()
                return
            end
            local scale = slider:GetEffectiveScale()
            local cx = GetCursorPosition() / scale
            local left, tw = slider:GetLeft(), slider:GetWidth()
            if left and tw and tw > 0 then
                local pct = max(0, min(1, (cx - left) / tw))
                slider:SetValue(minVal + pct * (maxVal - minVal))
            end
        end

        slider:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                isDragging = true
                UpdateSliderFromCursor()
                self:SetScript("OnUpdate", UpdateSliderFromCursor)
            end
        end)
        slider:SetScript("OnMouseUp", function(self)
            isDragging = false
            self:SetScript("OnUpdate", nil)
            card:Refresh()
        end)
        slider:SetScript("OnHide", function(self)
            isDragging = false
            self:SetScript("OnUpdate", nil)
        end)
        slider:SetScript("OnEnter", function(self)
            UpdateFillAndThumb()
            if GameTooltip then
                local r, g, b = GetAccent()
                local hex = sformat("%02X%02X%02X", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(sformat("|cFF%sLeft-Click / Drag:|r |cFFE2E8F0Adjust value|r", hex))
                GameTooltip:AddLine(sformat("|cFF%sMousewheel:|r |cFFE2E8F0Fine-tune by 1 step|r", hex))
                GameTooltip:Show()
            end
        end)
        slider:SetScript("OnLeave", function()
            UpdateFillAndThumb()
            if GameTooltip then GameTooltip:Hide() end
        end)
        slider:SetScript("OnMouseWheel", function(_, delta)
            local cur = spec.get() or minVal
            local newVal = SnapValue(cur + (delta > 0 and stepVal or -stepVal))
            lastCommittedValue = newVal
            spec.set(newVal)
            card:Refresh()
        end)
        slider:SetScript("OnSizeChanged", function()
            UpdateFillAndThumb()
        end)

        card.control = holder
        function card:Refresh()
            updating = true
            local v = SnapValue(spec.get() or minVal)
            lastCommittedValue = v
            slider:SetValue(v)
            self.valueText:SetText(spec.fmt and sformat(spec.fmt, v) or tostring(v))
            UpdateFillAndThumb(v)
            updating = false
        end
    elseif kind == "chips" then
        card.chips = {}
        if spec.headerButtonLabel and spec.onHeaderButton then
            local holder = CreateFrame("Frame", nil, card)
            local w1 = spec.headerButtonWidth or 96
            local w2 = spec.headerButton2Width or 0
            holder:SetSize(w1 + (w2 > 0 and (w2 + 6) or 0), 22)
            holder:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -12)

            local hb1 = U.NewButton(holder, w1, 22, spec.headerButtonLabel)
            hb1:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
            hb1:SetScript("OnClick", function()
                S.swapSourceKey = nil
                spec.onHeaderButton()
                card:Refresh()
            end)
            card.hb1 = hb1
            if spec.headerButton2Label and spec.onHeaderButton2 then
                local hb2 = U.NewButton(holder, w2, 22, spec.headerButton2Label)
                hb2:SetPoint("RIGHT", hb1, "LEFT", -6, 0)
                hb2:SetScript("OnClick", function()
                    S.swapSourceKey = nil
                    spec.onHeaderButton2()
                    card:Refresh()
                end)
                card.hb2 = hb2
            end
            card.control = holder
        end
        for i, item in ipairs(spec.items) do
            local chip = U.NewButton(card, 150, 24, item.label)
            chip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            if spec.reorderable then
                -- Inline [<] and [>] nudge buttons on the left and right edges when hovered
                local nudL = CreateFrame("Button", nil, chip)
                nudL:SetSize(18, 22)
                nudL:SetPoint("LEFT", chip, "LEFT", 1, 0)
                nudL.txt = nudL:CreateFontString(nil, "OVERLAY")
                SetFont(nudL.txt, 11, "OUTLINE")
                nudL.txt:SetPoint("CENTER", nudL, "CENTER", 0, 0)
                nudL.txt:SetText("<")
                nudL.txt:SetTextColor(0.85, 0.92, 1.0, 1)
                nudL:Hide()
                nudL:SetScript("OnEnter", function(self) chip.hover = true; U.StyleButtonState(chip); self.txt:SetTextColor(1, 0.82, 0.2, 1) end)
                nudL:SetScript("OnLeave", function(self) self.txt:SetTextColor(0.85, 0.92, 1.0, 1); if not chip:IsMouseOver() then chip.hover = false; nudL:Hide(); chip.nudR:Hide(); U.StyleButtonState(chip) end end)
                nudL:SetScript("OnClick", function()
                    S.swapSourceKey = nil
                    if spec.moveKey and chip.itemKey then
                        spec.moveKey(chip.itemKey, -1)
                        card:Refresh()
                    end
                end)
                chip.nudL = nudL

                local nudR = CreateFrame("Button", nil, chip)
                nudR:SetSize(18, 22)
                nudR:SetPoint("RIGHT", chip, "RIGHT", -1, 0)
                nudR.txt = nudR:CreateFontString(nil, "OVERLAY")
                SetFont(nudR.txt, 11, "OUTLINE")
                nudR.txt:SetPoint("CENTER", nudR, "CENTER", 0, 0)
                nudR.txt:SetText(">")
                nudR.txt:SetTextColor(0.85, 0.92, 1.0, 1)
                nudR:Hide()
                nudR:SetScript("OnEnter", function(self) chip.hover = true; U.StyleButtonState(chip); self.txt:SetTextColor(1, 0.82, 0.2, 1) end)
                nudR:SetScript("OnLeave", function(self) self.txt:SetTextColor(0.85, 0.92, 1.0, 1); if not chip:IsMouseOver() then chip.hover = false; chip.nudL:Hide(); nudR:Hide(); U.StyleButtonState(chip) end end)
                nudR:SetScript("OnClick", function()
                    S.swapSourceKey = nil
                    if spec.moveKey and chip.itemKey then
                        spec.moveKey(chip.itemKey, 1)
                        card:Refresh()
                    end
                end)
                chip.nudR = nudR
            end
            chip:SetScript("OnClick", function(self, button)
                local curKey = self.itemKey or item.key
                if spec.reorderable then
                    -- If a category is currently armed for 2-click swap, clicking any category swaps them immediately!
                    if S.swapSourceKey then
                        local src = S.swapSourceKey
                        S.swapSourceKey = nil
                        if src ~= curKey and spec.swapKeys then
                            spec.swapKeys(src, curKey)
                        end
                        card:Refresh()
                        return
                    end
                    if IsShiftKeyDown() then
                        spec.moveKey(curKey, (button == "LeftButton") and -1 or 1)
                        card:Refresh()
                        return
                    elseif button == "RightButton" then
                        S.swapSourceKey = curKey
                        card:Refresh()
                        return
                    elseif spec.flareToggle then
                        spec.flareToggle(curKey)
                        card:Refresh()
                        return
                    end
                end
                spec.set(curKey, not spec.get(curKey))
                card:Refresh()
            end)
            chip:HookScript("OnEnter", function(self)
                if spec.reorderable then
                    if self.nudL then self.nudL:Show() end
                    if self.nudR then self.nudR:Show() end
                    local ar, ag, ab = GetAccent()
                    local accHex = sformat("%02X%02X%02X", floor(ar * 255 + 0.5), floor(ag * 255 + 0.5), floor(ab * 255 + 0.5))
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetText(self.fullLabel or item.label, 1, 1, 1)
                    if S.swapSourceKey then
                        GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Swap Position with Selected Category|r", 0.886, 0.910, 0.941)
                    else
                        GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Toggle Category On / Off|r", 0.886, 0.910, 0.941)
                        GameTooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Select to Swap with Another Category|r", 0.886, 0.910, 0.941)
                        GameTooltip:AddLine("|cFF" .. accHex .. "Click < or > Arrows:|r |cFFE2E8F0Move Priority Earlier / Later|r", 0.886, 0.910, 0.941)
                    end
                    GameTooltip:Show()
                elseif item.tooltip then
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetText(item.label, 1, 1, 1)
                    GameTooltip:AddLine(item.tooltip, 0.80, 0.85, 0.92, true)
                    GameTooltip:Show()
                end
            end)
            chip:HookScript("OnLeave", function(self)
                if self.nudL and not self.nudL:IsMouseOver() and not self.nudR:IsMouseOver() then
                    self.nudL:Hide()
                    self.nudR:Hide()
                end
                GameTooltip:Hide()
            end)
            card.chips[i] = chip
        end
        function card:Refresh()
            if self.hb2 and spec.headerButton2LabelFn then
                self.hb2:SetLabel(spec.headerButton2LabelFn())
            end
            local list = (spec.getOrderedItems and spec.getOrderedItems()) or spec.items
            local activeRank = 0
            for i, item in ipairs(list) do
                local ch = self.chips[i]
                if ch then
                    local isOn = spec.get(item.key) and true or false
                    ch.itemKey = item.key
                    ch.fullLabel = item.fullLabel or CAT_FULL_LABEL[item.key] or item.label
                    if spec.reorderable then
                        local isSwapSrc = (S.swapSourceKey == item.key)
                        if isSwapSrc then
                            ch:SetLabel(sformat(">> Swap: %s <<", item.label))
                            ch:SetAlpha(1.0)
                            ch:SetBackdropColor(0.35, 0.26, 0.04, 0.98)
                            ch:SetBackdropBorderColor(1.0, 0.82, 0.20, 1.0)
                            ch.label:SetTextColor(1.0, 0.88, 0.30, 1)
                        elseif isOn then
                            activeRank = activeRank + 1
                            ch:SetLabel(sformat("[%d]  %s", activeRank, item.label))
                            ch:SetAlpha(1.0)
                            ch:SetSelected(true)
                        else
                            ch:SetLabel(sformat("[-]  %s", item.label))
                            ch:SetAlpha(0.58)
                            ch:SetSelected(false)
                        end
                    else
                        ch:SetLabel(item.label)
                        ch:SetAlpha(1.0)
                        ch:SetSelected(isOn)
                    end
                end
            end
        end    elseif kind == "button" then
        local b = U.NewButton(card, spec.buttonWidth or 150, 26, spec.buttonLabel or "Run")
        b:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -17)
        b:SetScript("OnClick", function()
            spec.onClick()
            card:Refresh()
        end)
        card.control = b
        function card:Refresh()
            if spec.descFn then self.desc:SetText(spec.descFn()) end
        end
    else
        function card:Refresh() end
    end

    local innerRefresh = card.Refresh
    function card:Refresh()
        local ar, ag, ab = GetAccent()
        if self.title then self.title:SetTextColor(0.97, 0.98, 1.0, 1.0) end
        if innerRefresh then innerRefresh(self) end
    end

    -- Text never runs under the right-hand control.
    if card.control then
        card.title:SetPoint("RIGHT", card.control, "LEFT", -16, 0)
        card.desc:SetPoint("RIGHT", card.control, "LEFT", -16, 0)
    else
        card.title:SetPoint("RIGHT", card, "RIGHT", -16, 0)
        card.desc:SetPoint("RIGHT", card, "RIGHT", -16, 0)
    end

    sec.cards[#sec.cards + 1] = card
    page.cards[#page.cards + 1] = card
    return card
end

function U.LayoutPage(page)
    local w = page:GetWidth()
    if not w or w < 100 then
        local p = page:GetParent()
        w = (p and p:GetWidth() and p:GetWidth() > 100) and p:GetWidth() or 700
    end
    local y = 0
    for _, sec in ipairs(page.sections or {}) do
        local padX = sec.innerPadX or 14
        local cardW = max(400, w - (padX * 2))
        local sy = (sec.hdr and sec.hdr.hasSub) and 54 or 38
        if sec.hdr and sec.hdr.RefreshAccent then sec.hdr:RefreshAccent() end
        for _, card in ipairs(sec.cards or {}) do
            local h = 62
            if card.spec.kind == "chips" then
                local gap = 6
                local per = card.spec.chipsPerRow or min(4, max(1, #card.chips))
                local availW = max(360, cardW - 28)
                local chipW = floor((availW - (per - 1) * gap) / per)
                local rows = ceil(#card.chips / per)
                h = 58 + rows * 30 + 6
                for i, chip in ipairs(card.chips) do
                    local idx = i - 1
                    local col = idx % per
                    local row = floor(idx / per)
                    chip:ClearAllPoints()
                    if col == (per - 1) then
                        chip:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + col * (chipW + gap), -54 - row * 30)
                        chip:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -54 - row * 30)
                    else
                        chip:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + col * (chipW + gap), -54 - row * 30)
                        chip:SetWidth(chipW)
                    end
                end
            elseif card.chevBar and card.spec.subDrawer then
                local sd = card.spec.subDrawer
                local isParentOn = card.spec.get and card.spec.get() and true or false
                local isExpanded = sd.isExpanded and sd.isExpanded() and true or false
                if not isParentOn then
                    card.chevBar:Hide()
                    if card.subCard then card.subCard:Hide() end
                    h = 62
                elseif isExpanded then
                    card.chevBar:Show()
                    if card.subCard then card.subCard:Show() end
                    h = 140
                else
                    card.chevBar:Show()
                    if card.subCard then card.subCard:Hide() end
                    h = 84
                end
                if card.chevBar.StyleChevBar then card.chevBar.StyleChevBar() end
            end
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", sec, "TOPLEFT", padX, -sy)
            card:SetPoint("TOPRIGHT", sec, "TOPRIGHT", -padX, -sy)
            card:SetHeight(h)
            sy = sy + h + 8
        end
        local secH = (sy - 8) + 12
        sec:ClearAllPoints()
        sec:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
        sec:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -y)
        sec:SetHeight(secH)
        y = y + secH + 14
    end
    if y > 14 then y = y - 14 end
    page:SetHeight(max(1, y))
    return y
end

local function MarkCustom()
    DB().preset = "CUSTOM"
end

function U.EnsureCatOrder()
    local db = DB()
    if type(db.catOrder) ~= "table" or #db.catOrder ~= #CATS then
        db.catOrder = {}
        for i, c in ipairs(CATS) do db.catOrder[i] = c.key end
    end
    return db.catOrder
end

function U.MoveMasterCategory(catKey, delta)
    local order = U.EnsureCatOrder()
    local idx = nil
    for i, k in ipairs(order) do if k == catKey then idx = i; break end end
    if not idx then return end
    local newIdx = idx + delta
    if delta == -999 then newIdx = 1 elseif delta == 999 then newIdx = #order end
    newIdx = max(1, min(#order, newIdx))
    if newIdx == idx then return end
    local item = table.remove(order, idx)
    table.insert(order, newIdx, item)
    DB().secPriority = {}
    U.OnSettingChanged("layout")
end

function U.BuildPage1(page)
    local db = DB()
    db.replaceBlizzardBags = true
    U.AddSection(page, "VIEW MODE, SORTING & PRESETS", "Configure bag view mode, automatic sorting rules, and 1-click layout presets.")
    U.AddCard(page, {
        title = "Bag Layout Style", kind = "pills", pillWidth = 138,
        desc = "Organise items into automatic category groups, or display one combined grid.",
        options = { { value = "CATEGORY", label = "Category Groups" }, { value = "GRID", label = "Single Grid" } },
        get = function() return db.viewMode end,
        set = function(v) db.viewMode = v; MarkCustom(); U.OnSettingChanged("layout") end,
    })
    U.AddCard(page, {
        title = "Auto-Sort Items by Quality & Level", kind = "toggle",
        desc = "Automatically orders items inside each category by rarity and item level (Off keeps physical bag slot order).",
        get = function() return db.autoSort ~= false end,
        set = function(v) db.autoSort = (v and true or false); U.OnSettingChanged("layout") end,
    })
    local presetCard = U.AddCard(page, {
        title = "Category Layout Preset", kind = "pills", pillWidth = 104,
        desc = "Left-Click to apply a layout preset. Right-Click any preset to save your current category setup.",
        options = {
            { value = "MYTHIC", label = "Mythic+ & Raid" }, { value = "COLLECTOR", label = "Collector" },
            { value = "MINIMAL", label = "Minimalist" }, { value = "CUSTOM", label = "Custom" },
        },
        get = function() return db.preset end,
        set = function(v) U.ApplyPreset(v) end,
    })
    if presetCard and presetCard.btns then
        local pKeys = { "MYTHIC", "COLLECTOR", "MINIMAL", "CUSTOM" }
        local pTips = {
            { title = "Mythic+ & Raid Ready", body = "Priority order: New Items -> Consumables -> Keystones -> Equipment Sets -> BoE -> Gear -> Gems & Enchants -> Warbound -> Quest -> Reagents -> Misc -> Junk.\n\n|cFF34D399Left-Click:|r |cFFE2E8F0Apply Mythic+ & Raid preset layout.|r\n|cFF38BDF8Right-Click:|r |cFFE2E8F0Save current layout to Mythic+ & Raid.|r" },
            { title = "Collector & Open World", body = "Prioritises New Items, Warbound (WUE), Bind on Equip, Quest Items, Toys/Mounts & Reagents at the top.\n\n|cFF34D399Left-Click:|r |cFFE2E8F0Apply Collector preset layout.|r\n|cFF38BDF8Right-Click:|r |cFFE2E8F0Save current layout to Collector.|r" },
            { title = "Minimalist Compact", body = "Groups items into broad main categories with sub-category splitting turned off for a compact view.\n\n|cFF34D399Left-Click:|r |cFFE2E8F0Apply Minimalist preset layout.|r\n|cFF38BDF8Right-Click:|r |cFFE2E8F0Save current layout to Minimalist.|r" },
            { title = "Custom", body = "Your personalised category order and active sub-categories.\n\n|cFF34D399Left-Click:|r |cFFE2E8F0Apply Custom layout.|r\n|cFF38BDF8Right-Click:|r |cFFE2E8F0Save current layout to Custom.|r" },
        }
        for i, b in ipairs(presetCard.btns) do
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            local tip = pTips[i]
            local pKey = pKeys[i]
            if tip then
                b:HookScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetText(tip.title, 1, 1, 1)
                    GameTooltip:AddLine(tip.body, 0.80, 0.85, 0.92, true)
                    GameTooltip:Show()
                end)
                b:HookScript("OnLeave", function() GameTooltip:Hide() end)
            end
            b:SetScript("OnClick", function(_, button)
                if button == "RightButton" then
                    U.SaveCurrentToPreset(pKey)
                    presetCard:Refresh()
                else
                    U.ApplyPreset(pKey)
                    presetCard:Refresh()
                end
            end)
        end
    end

    local function NormalizeActiveCategoryOrder()
        local order = U.EnsureCatOrder()
        local onList, offList = {}, {}
        for _, k in ipairs(order) do
            if db.categories[k] ~= false then
                onList[#onList + 1] = k
            else
                offList[#offList + 1] = k
            end
        end
        wipe(order)
        for _, k in ipairs(onList) do order[#order + 1] = k end
        for _, k in ipairs(offList) do order[#order + 1] = k end
    end

    local function AreAllCategoriesEnabled()
        for _, c in ipairs(CATS) do
            if db.categories[c.key] == false then
                return false
            end
        end
        return true
    end

    U.AddSection(page, "CATEGORY PRIORITY & SUB-SPLITTING", "Reorder virtual categories, toggle custom groups, and split consumables or gear by slot.")
    U.AddCard(page, {
        title = "Category Order & Visibility", kind = "chips",
        reorderable = true,
        headerButtonLabel = "Reset Order",
        headerButtonWidth = 96,
        onHeaderButton = function()
            if db.savedPresets then db.savedPresets["MYTHIC"] = nil end
            db.catOrder = nil
            db.secPriority = {}
            for _, c in ipairs(CATS) do db.categories[c.key] = true end
            U.EnsureCatOrder()
            U.OnSettingChanged("reclass")
        end,
        headerButton2Label = AreAllCategoriesEnabled() and "Disable All" or "Enable All",
        headerButton2LabelFn = function()
            return AreAllCategoriesEnabled() and "Disable All" or "Enable All"
        end,
        headerButton2Width = 88,
        onHeaderButton2 = function()
            local disableAll = AreAllCategoriesEnabled()
            for _, c in ipairs(CATS) do db.categories[c.key] = not disableAll end
            NormalizeActiveCategoryOrder()
            db.secPriority = {}
            MarkCustom()
            U.OnSettingChanged("reclass")
        end,
        desc = "Left-Click to toggle On/Off. Use the < > hover arrows or Right-Click two categories to swap their positions.",
        items = CATEGORY_TOGGLES,
        getOrderedItems = function()
            NormalizeActiveCategoryOrder()
            local order = U.EnsureCatOrder()
            local out = {}
            for _, k in ipairs(order) do
                out[#out + 1] = { key = k, label = CAT_SHORT_LABEL[k] or CAT_LABEL[k] or k, fullLabel = CAT_FULL_LABEL[k] or CAT_LABEL[k] or k }
            end
            return out
        end,
        flareToggle = function(key)
            local wasOn = (db.categories[key] ~= false)
            db.categories[key] = not wasOn
            NormalizeActiveCategoryOrder()
            db.secPriority = {}
            MarkCustom()
            U.OnSettingChanged("reclass")
        end,
        swapKeys = function(k1, k2)
            if not k1 or not k2 or k1 == k2 then return end
            local order = U.EnsureCatOrder()
            local i1, i2 = nil, nil
            for i, k in ipairs(order) do
                if k == k1 then i1 = i elseif k == k2 then i2 = i end
            end
            if i1 and i2 then
                order[i1], order[i2] = order[i2], order[i1]
                db.secPriority = {}
                MarkCustom()
                U.OnSettingChanged("layout")
            end
        end,
        moveKey = function(key, delta)
            U.MoveMasterCategory(key, delta)
        end,
        get = function(key) return db.categories[key] ~= false end,
        set = function(key, v) db.categories[key] = v and true or false; NormalizeActiveCategoryOrder(); MarkCustom(); U.OnSettingChanged("reclass") end,
    })

    U.AddCard(page, {
        title = "Split Categories Into Sub-Groups", kind = "chips",
        desc = "Break large categories into focused sub-sections inside your Bags and Bank.",
        items = {
            { key = "splitEqSets",       label = "Equipment Sets by Spec", tooltip = "Splits Equipment Sets into individual sections for each saved spec/gear set (e.g. Set: Boomy, Set: Cat, Set: Tank)." },
            { key = "splitConsumables",  label = "Consumables by Type",    tooltip = "Splits Consumables into Potions, Flasks & Phials, Food & Drink, and Runes & Vantus." },
            { key = "splitGearSlots",    label = "Gear by Slot",           tooltip = "Splits non-set Gear into Weapons & Off-Hand, Trinkets, Rings/Neck/Cloak, and Armour." },
            { key = "splitUpgrades",     label = "Gear Upgrades First",    tooltip = "Pulls higher item-level gear upgrades into a dedicated 'Gear Upgrades' section." },
            { key = "splitBindSlots",    label = "BoE & Warbound by Slot", tooltip = "Splits Bind on Equip and Warbound gear into Weapons, Trinkets, Jewelry, and Armour." },
            { key = "splitGemsEnchants", label = "Gems vs. Enchants",      tooltip = "Splits Gems & Enchants into Socketable Gems and Item Enchants / Enhancements." },
            { key = "splitReagents",     label = "Reagents by Expansion",  tooltip = "Splits Trade & Reagents by Expansion (Midnight, War Within, Legacy) and Profession (Herbs, Ore, Enchanting, Cooking)." },
            { key = "splitCollectibles", label = "Toys & Mounts",          tooltip = "Separates Toys, Mounts, and Companions from general Miscellaneous items." },
        },
        get = function(key)
            if key == "splitBindSlots" or key == "splitUpgrades" then
                return db[key] == true
            end
            return db[key] ~= false
        end,
        set = function(key, v) db[key] = v and true or false; U.OnSettingChanged("layout") end,
    })

    U.AddSection(page, "GRID GEOMETRY & SLOT DIMENSIONS", "Adjust column count, icon size, slot spacing, and window scale for backpack and bank views.")
    U.AddCard(page, {
        title = "Bag Columns", kind = "slider", min = 8, max = 20, step = 1,
        desc = "Slots per row in the inventory window (8-20).",
        get = function() return db.bagColumns end,
        set = function(v) db.bagColumns = v; U.OnSettingChanged("layout") end,
    })
    U.AddCard(page, {
        title = "Bank Columns", kind = "slider", min = 10, max = 24, step = 1,
        desc = "Slots per row when viewing a bank or Warband snapshot (10-24).",
        get = function() return db.bankColumns end,
        set = function(v) db.bankColumns = v; U.OnSettingChanged("layout") end,
    })
    U.AddCard(page, {
        title = "Slot Icon Size", kind = "slider", min = 28, max = 48, step = 2, fmt = "%d px",
        desc = "Size of every item slot (28-48 px).",
        get = function() return db.iconSize end,
        set = function(v) db.iconSize = v; U.OnSettingChanged("layout") end,
    })
    U.AddCard(page, {
        title = "Category Spacing", kind = "slider", min = 8, max = 24, step = 2, fmt = "%d px",
        desc = "Vertical gap between category rows (8-24 px).",
        get = function() return db.categorySpacing end,
        set = function(v) db.categorySpacing = v; U.OnSettingChanged("layout") end,
    })
end
function U.BuildPage2(page)
    local db = DB()
    U.AddSection(page, "ITEM SLOT BADGES & TAGS", "Choose which info badges appear on the corners of your item icons. Alt + Right-Click any item in bags to pin it.")
    U.AddCard(page, {
        title = "Item Slot Badges", kind = "chips",
        desc = "Toggle corner indicators shown on item slots in your Bags, Bank, and Warband Bank.",
        items = {
            { key = "ilvl",     label = "Item Level" },
            { key = "upgrade",  label = "Upgrade Icon" },
            { key = "keystone", label = "Keystone Level (+12)" },
            { key = "eqset",    label = "Equipment Set Tag" },
            { key = "binding",  label = "BoE & Warbound Tag" },
            { key = "junk",     label = "Grey Junk Coin" },
            { key = "quality",  label = "Crafting Quality Tier" },
        },
        get = function(key) return db.badges[key] end,
        set = function(key, v) db.badges[key] = v and true or false; U.OnSettingChanged("visual") end,
    })
    U.AddSection(page, "VISUAL HIGHLIGHTS & TEXT TYPOGRAPHY", "Configure rarity border glow, new-item flash, badge font size, and dim-unusable shading.")
    U.AddCard(page, {
        title = "Item Slot Highlights", kind = "chips",
        desc = "Configure rarity border glow, unusable item shading, and new-item pulse effects.",
        items = {
            { key = "qualityGlow", label = "Rarity Border Glow" },
            { key = "dimJunk",     label = "Dim Grey Junk" },
            { key = "unusableRed", label = "Tint Unusable Red" },
            { key = "flashNew",    label = "Pulse New Items" },
        },
        get = function(key) return db.visual[key] end,
        set = function(key, v) db.visual[key] = v and true or false; U.OnSettingChanged("visual") end,
    })
    U.AddCard(page, {
        title = "Icon Font Size", kind = "slider", min = 10, max = 16, step = 1, fmt = "%d px",
        desc = "Size of the count, item level and badge text (10-16 px).",
        get = function() return db.fontSize end,
        set = function(v) db.fontSize = v; U.OnSettingChanged("visual") end,
    })
end

local AUTO_OPEN_ITEMS = {
    { key = "bank", label = "Bank" }, { key = "auction", label = "Auction House" },
    { key = "vendor", label = "Vendor" }, { key = "mail", label = "Mail" },
    { key = "trade", label = "Trade" }, { key = "character", label = "Character Panel" },
    { key = "upgrade", label = "Item Upgrade" }, { key = "catalyst", label = "Catalyst" },
    { key = "guildbank", label = "Guild Bank" }, { key = "crafting", label = "Crafting Orders" },
}

function U.BuildPage3(page)
    local db = DB()
    U.AddSection(page, "WINDOW AUTO-OPEN & CLOSE TRIGGERS", "Choose which game interactions (Bank, Merchant, Mail, Trade, Auction House) auto-open DynamicBags.")
    U.AddCard(page, {
        title = "Auto-Open Triggers", kind = "chips",
        desc = "Open DynamicBags automatically when these windows open, and close it again when they close.",
        items = AUTO_OPEN_ITEMS,
        get = function(key) return db.autoOpen[key] end,
        set = function(key, v) db.autoOpen[key] = v and true or false end,
    })
    U.AddCard(page, {
        title = "Remember Last Opened Bank & Sub-Tab (Personal / Warband)", kind = "toggle",
        desc = "Reopen DynamicBank into whichever Bank Mode (Personal Bank vs Warband Bank) and sub-tab (All vs T1..TN) you used last.",
        get = function() return db.rememberLastBankTab ~= false end,
        set = function(v) db.rememberLastBankTab = v and true or false end,
    })

    U.AddSection(page, "CROSS-CHARACTER ALT & WARBAND VAULT", "Inspect cached bags, Character Bank, and Warband Bank across all characters on your account.")
    U.AddCard(page, {
        title = "Alt & Warband Counts in Item Tooltips", kind = "toggle",
        desc = "Adds a short line showing how many of an item your other characters and Warband Bank hold.",
        get = function() return db.tooltipCounts end,
        set = function(v) db.tooltipCounts = v and true or false end,
    })
    local function CacheDesc()
        local list = U.GetCharList()
        local names = {}
        for i, c in ipairs(list) do
            if i > 6 then break end
            names[#names + 1] = c.rec.name or c.key
        end
        local wb = DB().vault.warbandBank and "Warband Bank cached" or "Warband Bank not cached yet (visit a banker)"
        if #list == 0 then return "No alts cached yet. Log in on each character once.   " .. wb end
        return sformat("%d alt(s): %s%s.   %s", #list, table.concat(names, ", "), #list > 6 and ", ..." or "", wb)
    end
    U.AddCard(page, {
        title = "Cached Characters", kind = "button", buttonLabel = "Clear Alt Cache", buttonWidth = 150,
        desc = CacheDesc(), descFn = CacheDesc,
        onClick = function() U.ClearAltCache() end,
    })

    U.AddSection(page, "MERCHANT, LOOT & INVENTORY AUTOMATION", "Automate equipment repairs, grey junk selling, single-frame fast looting, and item deletion prompts.")
    U.AddCard(page, {
        title = "Auto-Repair Equipment", kind = "toggle",
        desc = "Automatically repairs all damaged gear when opening a repair-capable vendor (Hold Shift to bypass).",
        get = function() return db.autoRepairEnabled ~= false end,
        set = function(v)
            local wasOff = (db.autoRepairEnabled == false)
            db.autoRepairEnabled = v and true or false
            db.autoRepair = db.autoRepairEnabled
            if wasOff and db.autoRepairEnabled then
                db.repairDrawerOpen = true
            end
            U.RefreshWorkspace()
        end,
        subDrawer = {
            buttonLabel = "Sub-Settings (1)",
            title = "Funding Priority",
            pillWidth = 138,
            options = {
                { value = "GUILD_FIRST", label = "Guild Bank First" },
                { value = "OWN_ONLY",    label = "Personal Gold Only" },
            },
            get = function() return db.repairFunding or "GUILD_FIRST" end,
            set = function(v) db.repairFunding = v end,
            isExpanded = function() return db.repairDrawerOpen ~= false end,
            toggleExpanded = function() db.repairDrawerOpen = (db.repairDrawerOpen == false) end,
        },
    })
    U.AddCard(page, {
        title = "Auto-Sell Grey Junk", kind = "toggle",
        desc = "Automatically sells poor-quality (grey) items in your bags when visiting any merchant.",
        get = function() return db.autoSellGrey ~= false end,
        set = function(v)
            db.autoSellGrey = v and true or false
            db.autoSellJunk = db.autoSellGrey
        end,
    })
    U.AddCard(page, {
        title = "Merchant Quick-Stack Bulk Buy (Alt + Right-Click)", kind = "toggle",
        desc = "Hold Alt and Right-Click any stackable vendor item to purchase a full stack immediately without opening the split-stack popup.",
        get = function() return db.merchantBulkBuy ~= false end,
        set = function(v) db.merchantBulkBuy = v and true or false end,
    })
    U.AddCard(page, {
        title = "Smart Vendor Auto-Restock", kind = "toggle",
        desc = "Automatically tops up items in your restock list when visiting any merchant selling them. Configure via '/dbag restock <itemID or link> <qty>', '/dbag restock list', or '/dbag restock clear'.",
        get = function() return db.autoRestockEnabled == true end,
        set = function(v) db.autoRestockEnabled = v and true or false end,
    })
    U.AddCard(page, {
        title = "Faster Auto-Loot", kind = "toggle",
        desc = "Accelerates looting by collecting all items in a single step as soon as the loot window opens.",
        get = function() return db.fastAutoLoot ~= false end,
        set = function(v) db.fastAutoLoot = v and true or false end,
    })
    U.AddCard(page, {
        title = 'Auto-Fill "DELETE" Item Confirmation', kind = "toggle",
        desc = 'Automatically fills "DELETE" into the confirmation prompt when destroying Rare or Epic items.',
        get = function() return db.autoFillDelete ~= false end,
        set = function(v) db.autoFillDelete = v and true or false end,
    })

    U.AddSection(page, "AUTO-OPEN & QUICK-OPEN QUEUE", "Automatically open Soulbound or Warband-bound gold pouches, Housing Decor, and Profession Knowledge, or queue protected items into the 1-click Open (N) header button.")
    U.AddCard(page, {
        title = "Auto-Open Soulbound Loot & Gold Pouches", kind = "toggle",
        desc = "Automatically opens Soulbound and Warband-bound gold pouches, coin satchels, and loot containers out of combat when bank, vendor, mail, trade, guild bank, and auction house windows are closed.",
        get = function() return db.autoOpenContainers ~= false end,
        set = function(v)
            db.autoOpenContainers = v and true or false
            if db.autoOpenContainers and U.ScheduleAutoOpenContainers then
                U.ScheduleAutoOpenContainers()
            end
            if U.UpdateQuickOpenButton then U.UpdateQuickOpenButton() end
        end,
    })
    U.AddCard(page, {
        title = "Auto-Open Soulbound Housing Decor", kind = "toggle",
        desc = "Automatically opens or learns Soulbound and Warband-bound Housing Decor items out of combat when bank, vendor, mail, trade, guild bank, and auction house windows are closed. Items that trigger a protected spell cast stay queued in the Open (N) button.",
        get = function() return db.autoOpenHousingDecor ~= false end,
        set = function(v)
            db.autoOpenHousingDecor = v and true or false
            if db.autoOpenHousingDecor and U.ScheduleAutoOpenContainers then
                U.ScheduleAutoOpenContainers()
            end
            if U.UpdateQuickOpenButton then U.UpdateQuickOpenButton() end
        end,
    })
    U.AddCard(page, {
        title = "Auto-Open Soulbound Profession Knowledge", kind = "toggle",
        desc = "Automatically uses or learns Soulbound and Warband-bound Profession Knowledge items (Treatises, Shards, Notes, Curios) when your character knows that profession and bank, vendor, mail, trade, guild bank, and auction house windows are closed. Protected spell casts stay queued in the Open (N) button.",
        get = function() return db.autoOpenKnowledgeItems ~= false end,
        set = function(v)
            db.autoOpenKnowledgeItems = v and true or false
            if db.autoOpenKnowledgeItems and U.ScheduleAutoOpenContainers then
                U.ScheduleAutoOpenContainers()
            end
            if U.UpdateQuickOpenButton then U.UpdateQuickOpenButton() end
        end,
    })
    U.AddCard(page, {
        title = "Auto-Unwrap & Open Wrapped Items", kind = "toggle",
        desc = "Automatically unwraps wrapped gifts and parcels out of combat when bank, vendor, mail, trade, guild bank, and auction house windows are closed. Vendor-locked or non-refundable items stay queued in Open (N) only.",
        get = function() return db.autoUnwrapItems == true end,
        set = function(v)
            db.autoUnwrapItems = v and true or false
            if db.autoUnwrapItems and U.ScheduleAutoOpenContainers then
                U.ScheduleAutoOpenContainers()
            end
            if U.UpdateQuickOpenButton then U.UpdateQuickOpenButton() end
        end,
    })
    U.AddCard(page, {
        title = "Show Open (N) Quick-Open Button for Housing Decor, Knowledge & Use: Caches", kind = "toggle",
        desc = "Displays a 1-click button in the DynamicBags header to rapidly open or learn queued Housing Decor, Profession Knowledge, and Use: caches.",
        get = function() return db.quickOpenEnabled ~= false end,
        set = function(v)
            db.quickOpenEnabled = v and true or false
            if U.UpdateQuickOpenButton then U.UpdateQuickOpenButton() end
        end,
    })
    U.AddCard(page, {
        title = "Quick-Open Queue Filters & Safety Rules", kind = "chips",
        desc = "Choose which item categories are queued into the Open (N) button and enforce strict Soulbound protection against consuming tradeable items.",
        items = {
            { key = "queueHousingDecor",      label = "Include Housing Decor",        tooltip = "Queues Housing Decor, Room Decor, and House Chest items into the 1-spot Open (N) button." },
            { key = "queueKnowledgeItems",    label = "Include Profession Knowledge", tooltip = "Queues Profession Knowledge items (Treatises, Shards, Notes) only when your character knows that profession." },
            { key = "openablesSoulboundOnly", label = "Soulbound Items Only",         tooltip = "Requires items to be Soulbound or Account-Bound so tradeable BoE / Auction House items are never consumed accidentally." },
        },
        get = function(key) return db[key] ~= false end,
        set = function(key, v)
            db[key] = v and true or false
            if U.UpdateQuickOpenButton then U.UpdateQuickOpenButton() end
            if db.autoOpenContainers ~= false and U.ScheduleAutoOpenContainers then
                U.ScheduleAutoOpenContainers()
            end
        end,
    })
end

function U.ScanConflicts()
    local conflicts = {}
    local list = (DynamicBags.CONFLICT_REGISTRY and DynamicBags.CONFLICT_REGISTRY.conflicts)
        or { "Baganator", "BetterBags", "AdiBags", "ArkInventory", "Bagnon", "Sorted", "LiteBag" }
    local charName = UnitName("player")
    for _, addonName in ipairs(list) do
        local isEnabled = false
        if C_AddOns and C_AddOns.GetAddOnEnableState then
            local ok, state = pcall(C_AddOns.GetAddOnEnableState, addonName, charName)
            if not ok or state == nil then
                ok, state = pcall(C_AddOns.GetAddOnEnableState, charName, addonName)
            end
            if ok and type(state) == "number" and state > 0 then
                isEnabled = true
            end
        end
        if not isEnabled and C_AddOns and C_AddOns.IsAddOnLoaded then
            local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, addonName)
            if ok and loaded then isEnabled = true end
        end
        if isEnabled then
            conflicts[#conflicts + 1] = addonName
        end
    end
    -- Smart Sub-Module Detection for ElvUI Bags (only flag when ElvUI[1].private.bags.enable == true)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local okLoaded, elvLoaded = pcall(C_AddOns.IsAddOnLoaded, "ElvUI")
        if okLoaded and elvLoaded then
            local okSub, elvBagsEnabled = pcall(function()
                local E = type(_G.ElvUI) == "table" and _G.ElvUI[1]
                return type(E) == "table" and type(E.private) == "table" and type(E.private.bags) == "table" and E.private.bags.enable == true
            end)
            if okSub and elvBagsEnabled then
                conflicts[#conflicts + 1] = "ElvUI"
            end
        end
    end
    return conflicts
end

function U.ResolveConflictUseDynamic(addonName)
    if not addonName then return end
    if C_AddOns and C_AddOns.DisableAddOn then
        pcall(C_AddOns.DisableAddOn, addonName)
    elseif _G.DisableAddOn then
        pcall(_G.DisableAddOn, addonName)
    end
    if type(_G.DynamicLoadDB) == "table" then
        _G.DynamicLoadDB.addonStates = _G.DynamicLoadDB.addonStates or {}
        _G.DynamicLoadDB.addonStates[addonName] = "FROZEN"
        _G.DynamicLoadDB.frozenAddons = _G.DynamicLoadDB.frozenAddons or {}
        _G.DynamicLoadDB.frozenAddons[addonName] = true
    end
    S.pendingConflictReload = addonName
    U.RefreshWorkspace()
end

function U.ResolveConflictKeepOther(addonName)
    if C_AddOns and C_AddOns.DisableAddOn and C_AddOns.GetAddOnInfo and C_AddOns.GetAddOnInfo("DynamicBags") then
        pcall(C_AddOns.DisableAddOn, "DynamicBags")
    elseif _G.DisableAddOn and C_AddOns and C_AddOns.GetAddOnInfo and C_AddOns.GetAddOnInfo("DynamicBags") then
        pcall(_G.DisableAddOn, "DynamicBags")
    end
    if type(_G.DynamicLoadDB) == "table" then
        _G.DynamicLoadDB.addonStates = _G.DynamicLoadDB.addonStates or {}
        _G.DynamicLoadDB.addonStates["DynamicBags"] = "FROZEN"
        _G.DynamicLoadDB.frozenAddons = _G.DynamicLoadDB.frozenAddons or {}
        _G.DynamicLoadDB.frozenAddons["DynamicBags"] = true
    end
    _G.DynamicSuiteDB = _G.DynamicSuiteDB or {}
    _G.DynamicSuiteDB.disabledModules = _G.DynamicSuiteDB.disabledModules or {}
    _G.DynamicSuiteDB.disabledModules["DynamicBags"] = true
    if _G.DynamicSuiteDB.global then
        _G.DynamicSuiteDB.global.disabledModules = _G.DynamicSuiteDB.global.disabledModules or {}
        _G.DynamicSuiteDB.global.disabledModules["DynamicBags"] = true
    end
    S.pendingConflictReload = "DynamicBags (keeping " .. tostring(addonName or "other addon") .. ")"
    U.RefreshWorkspace()
end

function U.RefreshWorkspace()
    local ws = S.workspace
    if not ws or not ws.root then return end
    local db = DB()
    local ar, ag, ab = GetAccent()

    if ws.conflictBanner then
        local hostedInSuite = (_G.DynamicSuite and _G.DynamicSuite.HasUnifiedModuleConflictBanner and _G.DynamicSuiteMainFrame and ws.root:GetParent() ~= UIParent)
        local conflicts = hostedInSuite and {} or U.ScanConflicts()
        if not hostedInSuite and S.pendingConflictReload then
            ws.conflictBanner:Show()
            ws.conflictBanner.title:SetText("CONFLICT RESOLUTION STAGED - RELOAD UI REQUIRED")
            ws.conflictBanner.desc:SetText(sformat("Disabled %s and set to Never Load in DynamicLoad. Click Reload UI to apply.", tostring(S.pendingConflictReload)))
            ws.conflictBanner.btnUseDynamic:Hide()
            ws.conflictBanner.btnKeepOther:Hide()
            ws.conflictBanner.btnReload:Show()
            ws.tabBar:ClearAllPoints()
            ws.tabBar:SetPoint("TOPLEFT", ws.conflictBanner, "BOTTOMLEFT", 0, -8)
            ws.tabBar:SetPoint("TOPRIGHT", ws.conflictBanner, "BOTTOMRIGHT", 0, -8)
        elseif not hostedInSuite and #conflicts > 0 then
            local primary = conflicts[1]
            local listStr = table.concat(conflicts, ", ")
            ws.conflictBanner.currentAddon = primary
            ws.conflictBanner:Show()
            ws.conflictBanner.title:SetText(sformat("Conflict Detected: %s is currently active and may cause UI errors or blocked actions.", listStr))
            ws.conflictBanner.desc:SetText("Use DynamicLoad or disable the conflicting addon below to prevent bag window or item click errors.")
            ws.conflictBanner.btnUseDynamic:SetLabel("Use DynamicBags (Disable & Set Never)")
            ws.conflictBanner.btnUseDynamic:SetSelected(true)
            ws.conflictBanner.btnUseDynamic:Show()
            ws.conflictBanner.btnKeepOther:SetLabel("Keep " .. primary)
            ws.conflictBanner.btnKeepOther:Show()
            ws.conflictBanner.btnReload:Hide()
            ws.tabBar:ClearAllPoints()
            ws.tabBar:SetPoint("TOPLEFT", ws.conflictBanner, "BOTTOMLEFT", 0, -8)
            ws.tabBar:SetPoint("TOPRIGHT", ws.conflictBanner, "BOTTOMRIGHT", 0, -8)
        else
            ws.conflictBanner:Hide()
            ws.tabBar:ClearAllPoints()
            ws.tabBar:SetPoint("TOPLEFT", ws.root, "TOPLEFT", 14, -10)
            ws.tabBar:SetPoint("TOPRIGHT", ws.root, "TOPRIGHT", -16, -10)
        end
    end

    ws.tabBar:SetBackdropBorderColor(COL.bevelEdge[1], COL.bevelEdge[2], COL.bevelEdge[3], COL.bevelEdge[4])
    for i, b in ipairs(ws.tabButtons) do b:SetSelected(db.activeSubTab == i) end
    for i, page in ipairs(ws.pages) do
        page:SetShown(db.activeSubTab == i)
        for _, sec in ipairs(page.sections or {}) do
            if sec.hdr and sec.hdr.RefreshAccent then sec.hdr:RefreshAccent() end
        end
        for _, card in ipairs(page.cards) do card:Refresh() end
    end
    local page = ws.pages[db.activeSubTab] or ws.pages[1]
    local h = U.LayoutPage(page)
    ws.scrollHolder.content:SetHeight(max(h, 1))
    ws.scrollHolder.UpdateThumb()
    U.RefreshStyledButtons()
end

function U.RenderWorkspace(arg1, arg2)
    local parent = (type(arg1) == "table" and type(arg1.GetObjectType) == "function") and arg1 or arg2
    if not parent or type(parent.GetObjectType) ~= "function" then return nil end
    DB()
    RegisterBagsPopupCloser()
    parent:Show()

    if parent.DynamicBagsContainer then
        local existing = parent.DynamicBagsContainer
        existing:ClearAllPoints()
        existing:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        existing:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
        existing:Show()
        U.RefreshWorkspace()
        return existing
    end

    local root = CreateFrame("Frame", nil, parent)
    root:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    root:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    root:SetScript("OnHide", function() U.CloseMenu() end)
    parent.DynamicBagsContainer = root

    local conflictBanner = CreateFrame("Frame", nil, root, "BackdropTemplate")
    conflictBanner:SetHeight(54)
    conflictBanner:SetPoint("TOPLEFT", root, "TOPLEFT", 14, -10)
    conflictBanner:SetPoint("TOPRIGHT", root, "TOPRIGHT", -16, -10)
    Backdrop(conflictBanner, 0.16, 0.11, 0.04, 0.96, 0.96, 0.68, 0.16, 0.90)
    conflictBanner:Hide()

    local cbBar = conflictBanner:CreateTexture(nil, "OVERLAY")
    cbBar:SetWidth(3)
    cbBar:SetPoint("TOPLEFT", conflictBanner, "TOPLEFT", 0, -1)
    cbBar:SetPoint("BOTTOMLEFT", conflictBanner, "BOTTOMLEFT", 0, 1)
    cbBar:SetColorTexture(0.96, 0.68, 0.16, 1.0)

    conflictBanner.title = conflictBanner:CreateFontString(nil, "OVERLAY")
    SetFont(conflictBanner.title, 11, "")
    conflictBanner.title:SetPoint("TOPLEFT", conflictBanner, "TOPLEFT", 12, -9)
    conflictBanner.title:SetJustifyH("LEFT")
    conflictBanner.title:SetTextColor(1.0, 0.82, 0.28, 1.0)

    conflictBanner.desc = conflictBanner:CreateFontString(nil, "OVERLAY")
    SetFont(conflictBanner.desc, 10, "")
    conflictBanner.desc:SetPoint("TOPLEFT", conflictBanner.title, "BOTTOMLEFT", 0, -4)
    conflictBanner.desc:SetJustifyH("LEFT")
    conflictBanner.desc:SetTextColor(0.88, 0.91, 0.95, 1.0)

    conflictBanner.btnKeepOther = U.NewButton(conflictBanner, 132, 26, "Keep Other")
    conflictBanner.btnKeepOther:SetPoint("RIGHT", conflictBanner, "RIGHT", -12, 0)
    conflictBanner.btnKeepOther:SetScript("OnClick", function()
        if conflictBanner.currentAddon then
            U.ResolveConflictKeepOther(conflictBanner.currentAddon)
        end
    end)

    conflictBanner.btnUseDynamic = U.NewButton(conflictBanner, 244, 26, "Use DynamicBags (Disable & Set Never)")
    conflictBanner.btnUseDynamic:SetPoint("RIGHT", conflictBanner.btnKeepOther, "LEFT", -6, 0)
    conflictBanner.btnUseDynamic:SetSelected(true)
    conflictBanner.btnUseDynamic:SetScript("OnClick", function()
        if conflictBanner.currentAddon then
            U.ResolveConflictUseDynamic(conflictBanner.currentAddon)
        end
    end)

    conflictBanner.btnReload = U.NewButton(conflictBanner, 116, 26, "Reload UI")
    conflictBanner.btnReload:SetPoint("RIGHT", conflictBanner, "RIGHT", -12, 0)
    conflictBanner.btnReload:SetSelected(true)
    conflictBanner.btnReload:SetScript("OnClick", function() ReloadUI() end)
    conflictBanner.btnReload:Hide()

    local tabBar = CreateFrame("Frame", nil, root, "BackdropTemplate")
    tabBar:SetHeight(34)
    tabBar:SetPoint("TOPLEFT", root, "TOPLEFT", 14, -10)
    tabBar:SetPoint("TOPRIGHT", root, "TOPRIGHT", -16, -10)
    Backdrop(tabBar, COL.bevel[1], COL.bevel[2], COL.bevel[3], COL.bevel[4], COL.bevelEdge[1], COL.bevelEdge[2], COL.bevelEdge[3], COL.bevelEdge[4])

    local holder = U.CreateScrollArea(root)
    holder:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -8)
    holder:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", 0, -8)
    holder:SetPoint("BOTTOM", root, "BOTTOM", 0, 10)

    local ws = { root = root, conflictBanner = conflictBanner, tabBar = tabBar, scrollHolder = holder, tabButtons = {}, pages = {} }
    S.workspace = ws

    for idx, def in ipairs(TAB_DEFS) do
        local tb = U.NewButton(tabBar, 200, 26, def.label)
        tb:SetScript("OnClick", function()
            U.CloseMenu()
            DB().activeSubTab = idx
            U.RefreshWorkspace()
            holder:ScrollToTop()
        end)
        ws.tabButtons[idx] = tb

        local page = CreateFrame("Frame", nil, holder.content)
        page:SetPoint("TOPLEFT", holder.content, "TOPLEFT", 0, 0)
        page:SetPoint("TOPRIGHT", holder.content, "TOPRIGHT", 0, 0)
        page:SetHeight(400)
        page.cards = {}
        page:Hide()
        ws.pages[idx] = page
    end
    U.BuildPage1(ws.pages[1])
    U.BuildPage2(ws.pages[2])
    U.BuildPage3(ws.pages[3])

    -- 3 equal tabs, LEFT/RIGHT anchors only (never TOP+BOTTOM) so buttons stay 26px tall.
    local function ReflowTabs()
        local w = tabBar:GetWidth()
        if not w or w < 100 then w = 760 end
        local eachW = floor((w - 8 - 8) / 3)
        for i, b in ipairs(ws.tabButtons) do
            b:ClearAllPoints()
            b:SetHeight(26)
            if i == 1 then
                b:SetPoint("LEFT", tabBar, "LEFT", 4, 0)
                b:SetWidth(eachW)
            elseif i == 2 then
                b:SetPoint("LEFT", ws.tabButtons[1], "RIGHT", 4, 0)
                b:SetWidth(eachW)
            else
                b:SetPoint("LEFT", ws.tabButtons[2], "RIGHT", 4, 0)
                b:SetPoint("RIGHT", tabBar, "RIGHT", -4, 0)
            end
        end
    end
    tabBar:SetScript("OnSizeChanged", ReflowTabs)
    ReflowTabs()

    holder.onWidth = function()
        local page = ws.pages[DB().activeSubTab] or ws.pages[1]
        local h = U.LayoutPage(page)
        holder.content:SetHeight(max(h, 1))
        holder.UpdateThumb()
    end
    root:SetScript("OnShow", function()
        C_Timer.After(0, function() ReflowTabs(); U.RefreshWorkspace() end)
    end)
    C_Timer.After(0, function() ReflowTabs(); U.RefreshWorkspace() end)
    U.RefreshWorkspace()
    return root
end

function DynamicBags:RenderEmbedded(arg1, arg2) return U.RenderWorkspace(arg1, arg2) end
function DynamicBags:BuildEmbeddedPanel(arg1, arg2) return U.RenderWorkspace(arg1, arg2) end

function DynamicBags:ApplyThemeToUI()
    U.ApplyWindowTheme()
    U.RefreshWorkspace()
    if S.window and S.window:IsShown() then U.RenderCurrentView() end
end

function DynamicBags:RestoreBlizzardDefaults()
    if type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() then
        Print("Cannot restore Blizzard defaults while in combat. Please leave combat and try again.")
        return false
    end
    if C_CVar and type(C_CVar.SetCVar) == "function" and type(C_CVar.GetCVarDefault) == "function" then
        local okDef, defVal = pcall(C_CVar.GetCVarDefault, "autoLootDefault")
        if okDef and defVal ~= nil then
            pcall(C_CVar.SetCVar, "autoLootDefault", tostring(defVal))
        end
    end
    local db = DB()
    db.replaceBlizzardBags = false
    db.fastAutoLoot = false
    Print("Restored Blizzard default bag & auto-loot settings. Reload UI to complete cleanup.")
    if type(_G.StaticPopupDialogs) == "table" and type(_G.StaticPopup_Show) == "function" then
        _G.StaticPopupDialogs["DYNAMICBAGS_RELOAD_PROMPT"] = _G.StaticPopupDialogs["DYNAMICBAGS_RELOAD_PROMPT"] or {
            text = "DynamicBags has restored Blizzard default auto-loot and bag settings. Reload UI now?",
            button1 = "Reload UI",
            button2 = "Later",
            OnAccept = function()
                if type(_G.ReloadUI) == "function" then _G.ReloadUI() end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        _G.StaticPopup_Show("DYNAMICBAGS_RELOAD_PROMPT")
    end
    return true
end

function DynamicBags:ResetModuleDefaults()
    -- Reset in place so every settings-card closure keeps pointing at the live table.
    local db = DB()
    for k in pairs(db) do
        if k ~= "vault" then db[k] = nil end
    end
    CopyDefaults(DEFAULTS, db)
    S.sessionBagScale = nil
    S.sessionBankScale = nil
    if not InCombatLockdown() then
        U.ApplyWindowScale("bag")
        U.ApplyWindowScale("bank")
    end
    wipe(S.bindCache)
    U.OnSettingChanged("reclass")
    Print("Settings restored to defaults (Alt Vault cache kept).")
end

function DynamicBags:GetStatusText()
    local db = DB()
    local rf, rt = U.CountSlots()
    local p = PRESETS[db.preset]
    local modeText = (db.viewMode == "GRID") and "Single Grid" or (p and p.shortLabel or "Categories")
    local altCount = #U.GetCharList()
    return sformat("Free Space: |cFFFFFFFF%d/%d|r   |   View: |cFFFFFFFF%s|r   |   Auto-Repair & Sell: |cFF22C55E%s|r   |   Alts Cached: |cFFFFFFFF%d|r",
        rf, rt, modeText, (db.autoRepairEnabled ~= false or db.autoSellGrey ~= false) and "ON" or "OFF", altCount)
end

local function EnsureStandalone()
    if S.standalone then return S.standalone end
    local f = CreateFrame("Frame", "DynamicBagsStandaloneFrame", UIParent, "BackdropTemplate")
    f:SetSize(900, 600)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:HookScript("OnHide", function() U.CloseMenu() end)
    local ar, ag, ab = GetAccent()
    Backdrop(f, COL.panel[1], COL.panel[2], COL.panel[3], COL.panel[4], ar, ag, ab, 0.9)
    local footer = CreateFrame("Frame", nil, f, "BackdropTemplate")
    footer:SetHeight(34)
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
    footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    Backdrop(footer, 0.02, 0.025, 0.035, 0.98, 1, 1, 1, 0.08)

    local resetBtn = U.NewButton(footer, 132, 24, "Reset DynamicBags")
    resetBtn:SetPoint("LEFT", footer, "LEFT", 12, 0)
    resetBtn:SetScript("OnClick", function()
        DynamicBags:ResetModuleDefaults()
    end)

    local blizzResetBtn = U.NewButton(footer, 168, 24, "Restore Blizzard Defaults")
    blizzResetBtn:SetPoint("LEFT", resetBtn, "RIGHT", 8, 0)
    blizzResetBtn:SetScript("OnClick", function()
        DynamicBags:RestoreBlizzardDefaults()
    end)

    local reloadBtn = U.NewButton(footer, 86, 24, "Reload UI")
    reloadBtn:SetPoint("RIGHT", footer, "RIGHT", -12, 0)
    reloadBtn:SetScript("OnClick", function()
        if ReloadUI then ReloadUI() end
    end)

    f.body = CreateFrame("Frame", nil, f)
    f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -30)
    f.body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", -1, 2)
    local t = f:CreateFontString(nil, "OVERLAY")
    SetFont(t, 13, "")
    t:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -9)
    local hex = sformat("|cFF%02X%02X%02X", floor(ar * 255 + 0.5), floor(ag * 255 + 0.5), floor(ab * 255 + 0.5))
    t:SetText("|cFFF3F5F8Dynamic|r" .. hex .. "Bags|r  settings")
    local x = U.NewButton(f, 24, 22, "x")
    x:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -4)
    x:SetScript("OnClick", function() f:Hide() end)
    f:SetScript("OnShow", function()
        U.EnsureBagSpecialFrames()
    end)
    f:SetScript("OnHide", function()
        if not InCombatLockdown() and not IsStackMatching("CloseSpecialWindows", "CloseWindows") then
            U.EnsureBagSpecialFrames()
        end
    end)
    f:Hide()
    S.standalone = f
    U.EnsureBagSpecialFrames()
    return f
end

function DynamicBags:OpenWorkspace()
    if InCombatLockdown() then
        Print("Cannot open settings workspace while in combat.")
        return
    end
    local suite = _G.DynamicSuite
    if suite and type(suite.OpenModule) == "function" then
        local ok = pcall(suite.OpenModule, suite, "DynamicBags")
        if ok then return end
    end
    local f = EnsureStandalone()
    f:Show()
    U.RenderWorkspace(f.body)
end

-- ============================================================================
-- 9. AUTO-OPEN TRIGGERS, BLIZZARD BAG REPLACEMENT & AUTO-SELL JUNK
-- ============================================================================

local TRIGGER_MAP = {
    { key = "bank",      names = { "Banker", "AccountBanker" } },
    { key = "auction",   names = { "AuctionHouse" } },
    { key = "vendor",    names = { "Merchant" } },
    { key = "mail",      names = { "MailInfo" } },
    { key = "trade",     names = { "TradePartner" } },
    { key = "upgrade",   names = { "ItemUpgrade" } },
    { key = "catalyst",  names = { "ItemInteraction" } },
    { key = "guildbank", names = { "GuildBanker" } },
    { key = "crafting",  names = { "CraftingOrder", "ProfessionsCraftingOrder", "CraftingOrderCustomer" } },
}

function U.BuildTriggerLookup()
    S.typeToKey = {}
    S.bankTypes = {}
    local PIT = Enum and Enum.PlayerInteractionType
    if not PIT then return end
    for _, t in ipairs(TRIGGER_MAP) do
        for _, n in ipairs(t.names) do
            local id = PIT[n]
            if id then S.typeToKey[id] = t.key end
        end
    end
    for _, n in ipairs({ "Banker", "AccountBanker" }) do
        if PIT[n] then S.bankTypes[PIT[n]] = true end
    end
end

function U.TriggerAutoOpenKey(key)
    if not key or not DB().autoOpen[key] then return end
    S.autoOpened[key] = true
    S.autoOpenGraceUntil = (GetTime and GetTime() or 0) + 0.25
    U.ShowWindow()
    -- Re-assert after 0.05s and 0.15s in case Blizzard's UI Panel Manager (e.g. AuctionHouseFrame on Brutosaur mount) calls CloseAllBags() on show!
    C_Timer.After(0.05, function()
        if S.autoOpened[key] then
            U.ShowWindow()
            U.HideBlizzardBags()
        end
    end)
    C_Timer.After(0.15, function()
        if S.autoOpened[key] then
            U.ShowWindow()
            U.HideBlizzardBags()
        end
    end)
end

function U.TriggerAutoCloseKey(key)
    if not key or not S.autoOpened[key] then return end
    S.autoOpened[key] = nil
    if not next(S.autoOpened) then
        S.explicitClosing = (S.explicitClosing or 0) + 1
        if S.bankWindow then S.bankWindow:Hide() end
        U.HideWindow()
        S.explicitClosing = math.max(0, (S.explicitClosing or 1) - 1)
    end
end

function U.ResolveInitialBankMode(interactionType, bankKind)
    local db = DB()
    local PIT = Enum and Enum.PlayerInteractionType
    if bankKind == "GUILD" then
        return "GUILD"
    elseif bankKind == "WARBAND" or (PIT and interactionType == PIT.AccountBanker) then
        return "WARBAND"
    elseif db.rememberLastBankTab ~= false and db.lastBankMode == "WARBAND" then
        local canUseAccount = true
        if C_Bank and type(C_Bank.CanUseBank) == "function" and Enum and Enum.BankType and Enum.BankType.Account ~= nil then
            local ok, res = pcall(C_Bank.CanUseBank, Enum.BankType.Account)
            if ok and res == false then
                canUseAccount = false
            end
        end
        if canUseAccount then
            return "WARBAND"
        end
    end
    return "BANK"
end

function U.PreWarmCompanionBank(bankKind)
    if InCombatLockdown() or IsModuleDisabledInSuite("DynamicBags") then return false end
    local db = DB()
    if not db or not db.autoOpen then return false end
    if bankKind == "GUILD" then
        if db.autoOpen.guildbank == false then return false end
        S.autoOpened.guildbank = true
    else
        if db.autoOpen.bank == false then return false end
        S.autoOpened.bank = true
    end
    local mode = U.ResolveInitialBankMode(nil, bankKind)
    S.preWarmingBank = true
    U.HideBlizzardBags()
    U.OpenCompanionBank(mode, nil, true)
    if C_Timer and C_Timer.After then
        C_Timer.After(1.0, function()
            S.preWarmingBank = false
        end)
    end
    return true
end
DynamicBags.PreWarmCompanionBank = U.PreWarmCompanionBank
DynamicBags.PreWarmBankFromGossip = U.PreWarmCompanionBank

function U.OnInteractionShow(interactionType)
    if not S.typeToKey or not next(S.typeToKey) then U.BuildTriggerLookup() end
    local key = S.typeToKey and S.typeToKey[interactionType]
    if S.bankTypes and S.bankTypes[interactionType] then
        S.atBank = true
        S.preWarmingBank = false
        U.HideBlizzardBags()
        local db = DB()
        local mode = U.ResolveInitialBankMode(interactionType, nil)
        if db.autoOpen.bank then
            U.EnsureFastBankSeed(mode)
            U.OpenCompanionBank(mode, nil, true)
            S.autoOpened.bank = true
        end
        local preSig = U.GetVaultStateSignature(mode)
        if C_Timer and C_Timer.After then
            C_Timer.After(0.05, function()
                if not S.atBank then return end
                pcall(U.SnapshotBank)
                U.ScheduleSnapshot()
                if S.bankWindow and S.bankWindow:IsShown() then
                    local postSig = U.GetVaultStateSignature(S.companionMode or mode)
                    if postSig ~= preSig then
                        U.RenderCompanionBank()
                    end
                end
            end)
        else
            pcall(U.SnapshotBank)
            U.ScheduleSnapshot()
        end
        if db.autoOpen.bank then
            return
        end
    elseif key == "guildbank" then
        S.atGuildBank = true
        S.preWarmingBank = false
        U.HideBlizzardBags()
        -- Only query the active, viewable tab on open so restricted tabs never trigger permission errors.
        U.SelectGuildBankTab((GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 1, true)
        if DB().autoOpen.guildbank then
            U.OpenCompanionBank("GUILD", nil, true)
            S.autoOpened.guildbank = true
            if (S.companionSubTab or 0) > 0 then
                U.SelectGuildBankTab(S.companionSubTab)
            end
        end
        local preSig = U.GetVaultStateSignature("GUILD")
        if C_Timer and C_Timer.After then
            C_Timer.After(0.05, function()
                if not S.atGuildBank then return end
                U.HideBlizzardBags()
                pcall(U.SnapshotGuildBank)
                if S.bankWindow and S.bankWindow:IsShown() then
                    local postSig = U.GetVaultStateSignature("GUILD")
                    if postSig ~= preSig then
                        U.RenderCompanionBank()
                    end
                end
            end)
        else
            pcall(U.SnapshotGuildBank)
        end
        if DB().autoOpen.guildbank then
            return
        end
    end
    U.TriggerAutoOpenKey(key)
end

function U.OnInteractionHide(interactionType)
    if S.bankTypes and S.bankTypes[interactionType] then
        pcall(U.SnapshotBank)
        S.atBank = false
    end
    local key = S.typeToKey and S.typeToKey[interactionType]
    if key == "guildbank" then
        pcall(U.SnapshotGuildBank)
        U.ResetGuildBankSessionState()
    end
    if not key or not S.autoOpened[key] then return end
    S.autoOpened[key] = nil
    if not next(S.autoOpened) then
        S._closingGuildBank = (key == "guildbank")
        S.explicitClosing = (S.explicitClosing or 0) + 1
        if S.bankWindow then S.bankWindow:Hide() end
        S._closingGuildBank = nil
        U.HideWindow()
        S.explicitClosing = math.max(0, (S.explicitClosing or 1) - 1)
    end
end

function U.ResetGuildBankSessionState()
    S.atGuildBank = false
    S.queriedGuildTabs = {}
    S._justClosedGuildBank = GetTime and GetTime() or 0
    S._guildBankRefreshPending = nil
    if U.CancelAllPendingMerges then pcall(U.CancelAllPendingMerges) end
    local bw = S.bankWindow
    if bw then
        -- Flush stale Guild Bank slots and headers from the frame buffer immediately.
        for _, b in ipairs(bw.buttons or {}) do b:Hide(); b.dbObj = nil end
        for _, h in pairs(bw.headers or {}) do
            if type(h) == "table" and type(h.Hide) == "function" then pcall(h.Hide, h) end
        end
    end
    if S.companionMode == "GUILD" then
        S.companionMode = "BANK"
        S.companionSubTab = U.GetRememberedSubTab and U.GetRememberedSubTab("BANK") or 0
        if S.bankWindow and S.bankWindow:IsShown() and not S.autoOpened.guildbank then
            -- Window stays open (opened manually): switch it off the stale Guild view immediately.
            U.RenderCompanionBank()
        end
    end
end

function U.HookCurrencyFrame()
    if S.currHooked then return end
    S.currHooked = true
    if C_CurrencyInfo and type(C_CurrencyInfo.SetCurrencyBackpack) == "function" then
        hooksecurefunc(C_CurrencyInfo, "SetCurrencyBackpack", function()
            C_Timer.After(0, function() if S.window and S.window:IsShown() then U.UpdateFooter() end end)
        end)
    end
    if C_CurrencyInfo and type(C_CurrencyInfo.SetCurrencyBackpackByID) == "function" then
        hooksecurefunc(C_CurrencyInfo, "SetCurrencyBackpackByID", function()
            C_Timer.After(0, function() if S.window and S.window:IsShown() then U.UpdateFooter() end end)
        end)
    end
    if type(_G.TokenFrame_Update) == "function" then
        hooksecurefunc("TokenFrame_Update", function()
            if S.window and S.window:IsShown() then U.UpdateFooter() end
        end)
    end
end

function U.HookCharacterFrame()
    U.HookCurrencyFrame()
    if S.charHooked or not CharacterFrame then return end
    S.charHooked = true
    CharacterFrame:HookScript("OnShow", function()
        if DB().autoOpen.character then
            U.ShowWindow()
            S.autoOpened.character = true
        end
    end)
    CharacterFrame:HookScript("OnHide", function()
        if S.autoOpened.character then
            S.autoOpened.character = nil
            if not next(S.autoOpened) then
        if S.bankWindow then S.bankWindow:Hide() end
        U.HideWindow()
    end
        end
    end)
end

function U.HideBlizzardBags()
    if not S.hiddenBagHolder then
        S.hiddenBagHolder = CreateFrame("Frame")
        S.hiddenBagHolder:Hide()
    end
    if InCombatLockdown() then return end
    pcall(function()
        local replace = DB().replaceBlizzardBags
        local frames = { ContainerFrameCombinedBags }
        for i = 1, 13 do frames[#frames + 1] = _G["ContainerFrame" .. i] end
        local function SuppressBankPanel(panel)
            if not panel then return end
            if replace then
                panel:SetAlpha(0)
                if panel.SetScale then pcall(panel.SetScale, panel, 0.0001) end
                panel:EnableMouse(false)
                panel:ClearAllPoints()
                panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, 5000)
            else
                panel:SetAlpha(1)
                if panel.SetScale then pcall(panel.SetScale, panel, 1) end
                panel:EnableMouse(true)
            end
            if not panel.dbShowHooked and panel.HookScript then
                panel.dbShowHooked = true
                panel:HookScript("OnShow", function(self)
                    if DB().replaceBlizzardBags then
                        self:SetAlpha(0)
                        if self.SetScale then pcall(self.SetScale, self, 0.0001) end
                        self:EnableMouse(false)
                        self:ClearAllPoints()
                        self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, 5000)
                    end
                end)
            end
        end
        SuppressBankPanel(BankFrame)
        SuppressBankPanel(GuildBankFrame)
        if not S.uiPanelPosHooked then
            S.uiPanelPosHooked = true
            local function SuppressOpenBankPanelsSafe()
                if InCombatLockdown and InCombatLockdown() then return end
                if not DB().replaceBlizzardBags then return end
                if BankFrame and BankFrame.IsShown and BankFrame:IsShown() then
                    BankFrame:SetAlpha(0)
                    if BankFrame.SetScale then pcall(BankFrame.SetScale, BankFrame, 0.0001) end
                    BankFrame:ClearAllPoints()
                    BankFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, 5000)
                end
                if GuildBankFrame and GuildBankFrame.IsShown and GuildBankFrame:IsShown() then
                    GuildBankFrame:SetAlpha(0)
                    if GuildBankFrame.SetScale then pcall(GuildBankFrame.SetScale, GuildBankFrame, 0.0001) end
                    GuildBankFrame:ClearAllPoints()
                    GuildBankFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, 5000)
                end
            end
            if type(_G.UIParentManageFramePositions) == "function" then
                hooksecurefunc("UIParentManageFramePositions", SuppressOpenBankPanelsSafe)
            end
            if type(_G.UpdateUIPanelPositions) == "function" then
                hooksecurefunc("UpdateUIPanelPositions", SuppressOpenBankPanelsSafe)
            end
        end
        for _, f in ipairs(frames) do
            if f then
                if replace then
                    if f:GetParent() ~= S.hiddenBagHolder then
                        f.dbOrigParent = f:GetParent()
                        f:SetParent(S.hiddenBagHolder)
                    end
                    if f:IsShown() then f:Hide() end
                elseif f.dbOrigParent and f:GetParent() == S.hiddenBagHolder then
                    f:SetParent(f.dbOrigParent)
                end
            end
        end
    end)
end

function U.InstallBagHooks()
    U.HideBlizzardBags()
    if S.bagHooksInstalled then return end
    S.bagHooksInstalled = true
    local function userToggle()
        if not DB().replaceBlizzardBags then return end
        -- ToggleBag/ToggleBackpack can be invoked from within ToggleAllBags: collapse to one toggle per keypress.
        local now = GetTime and GetTime() or 0
        if now - (S.lastToggle or -1) < 0.15 then return end
        S.lastToggle = now
        U.ToggleWindow()
        if not InCombatLockdown() then
            U.HideBlizzardBags()
        end
        C_Timer.After(0, U.HideBlizzardBags)
    end
    local function justHide()
        C_Timer.After(0, U.HideBlizzardBags)
    end
    for _, fname in ipairs({ "ToggleAllBags", "ToggleBackpack", "ToggleBag" }) do
        if type(_G[fname]) == "function" then hooksecurefunc(fname, userToggle) end
    end
    for _, fname in ipairs({ "OpenAllBags", "OpenBackpack", "OpenBag" }) do
        if type(_G[fname]) == "function" then hooksecurefunc(fname, justHide) end
    end
    if type(_G.CloseAllBags) == "function" then
        hooksecurefunc("CloseAllBags", function()
            if not DB().replaceBlizzardBags or InCombatLockdown() then return end
            if IsStackMatching("ToggleAllBags", "ToggleBackpack") or IsStackMatching("ToggleBag", nil) then
                return
            end
            if IsStackMatching("CloseSpecialWindows", "CloseWindows") or IsStackMatching("ToggleGameMenu", nil) then
                return
            end
            if S.autoOpenGraceUntil and GetTime and GetTime() < S.autoOpenGraceUntil then
                return
            end
            S.explicitClosing = (S.explicitClosing or 0) + 1
            if S.bankWindow and S.bankWindow:IsShown() then
                S.bankWindow:Hide()
            end
            U.HideWindow()
            S.explicitClosing = math.max(0, (S.explicitClosing or 1) - 1)
            U.EnsureBagSpecialFrames()
        end)
    end
    if not S.closeSpecialHooked and type(_G.CloseSpecialWindows) == "function" then
        S.closeSpecialHooked = true
        hooksecurefunc("CloseSpecialWindows", function()
            if InCombatLockdown() then
                S.escRestoreBag = nil
                S.escRestoreBank = nil
                return
            end
            if (S.escRestoreBag or S.escRestoreBank) and ((S.search or "") ~= "") then
                local restoreBag = S.escRestoreBag
                local restoreBank = S.escRestoreBank
                S.escRestoreBag = nil
                S.escRestoreBank = nil
                S.escRestoringFromSearch = true
                if restoreBag and S.window and not S.window:IsShown() then
                    S.window:Show()
                end
                if restoreBank and S.bankWindow and not S.bankWindow:IsShown() then
                    S._skipNextOnShowRender = true
                    S.bankWindow:Show()
                    S._skipNextOnShowRender = nil
                end
                S.escRestoringFromSearch = nil
                U.ClearAllSearchBoxes()
                U.EnsureBagSpecialFrames()
                return
            end
            S.escRestoreBag = nil
            S.escRestoreBank = nil
            if (IsStackMatching("CloseWindows", "ToggleGameMenu") or IsStackMatching("ToggleGameMenu", nil))
                and U.GetTopMostShownBagFrameName() ~= nil then
                if (S.search or "") ~= "" then
                    U.ClearAllSearchBoxes()
                    S.escClosedBagOnThisToggle = true
                elseif U.CloseTopMostBagOnEscape() then
                    S.escClosedBagOnThisToggle = true
                end
                if S.escClosedBagOnThisToggle and C_Timer and C_Timer.After then
                    C_Timer.After(0, function() S.escClosedBagOnThisToggle = nil end)
                end
            end
            U.EnsureBagSpecialFrames()
        end)
    end
    if not S.toggleGameMenuHooked and type(_G.ToggleGameMenu) == "function" then
        S.toggleGameMenuHooked = true
        hooksecurefunc("ToggleGameMenu", function()
            if not S.escClosedBagOnThisToggle then return end
            S.escClosedBagOnThisToggle = nil
            if not InCombatLockdown() and GameMenuFrame and GameMenuFrame:IsShown() then
                if type(_G.HideUIPanel) == "function" then
                    pcall(_G.HideUIPanel, GameMenuFrame)
                end
                if GameMenuFrame:IsShown() and GameMenuFrame.Hide then
                    pcall(GameMenuFrame.Hide, GameMenuFrame)
                end
            end
        end)
    end
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags.HookScript then
        ContainerFrameCombinedBags:HookScript("OnShow", justHide)
    end
end

function DynamicBags:IsYieldingSharedHooks()
    local db = DB()
    if db.yieldHooks then db.yieldHooks = false end
    return false
end

local function FormatGold(copper)
    if U and U.FormatMoneyWithIcons then
        return U.FormatMoneyWithIcons(copper)
    end
    if type(copper) ~= "number" or copper <= 0 then return "0c" end
    if GetCoinTextureString then
        return GetCoinTextureString(copper)
    end
    local g = floor(copper / 10000)
    local s = floor((copper % 10000) / 100)
    local c = copper % 100
    return sformat("%dg %ds %dc", g, s, c)
end

function DynamicBags:HandleMerchantShow()
    local db = DB()
    if IsShiftKeyDown() or self:IsYieldingSharedHooks() then return end

    local now = (type(GetTime) == "function" and GetTime()) or 0
    _G.DynamicSuite = _G.DynamicSuite or {}
    local sess = _G.DynamicSuite._merchantSession
    if type(sess) ~= "table" or (now - (sess.at or 0)) > 1.5 then
        sess = { at = now, repaired = false, sold = false }
        _G.DynamicSuite._merchantSession = sess
    end

    -- 1. Auto-Repair Equipment
    if not sess.repaired and db.autoRepairEnabled ~= false and db.autoRepair ~= false and CanMerchantRepair and CanMerchantRepair() then
        sess.repaired = true
        local repairCost, canRepair = GetRepairAllCost()
        if canRepair and type(repairCost) == "number" and repairCost > 0 then
            local repairedWithGuild = false
            if db.repairFunding == "GUILD_FIRST" and IsInGuild and IsInGuild() and CanGuildBankRepair and CanGuildBankRepair() then
                local guildMoney = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
                local guildTotal = GetGuildBankMoney and GetGuildBankMoney() or 0
                if guildMoney == -1 or guildMoney >= repairCost then
                    if guildTotal >= repairCost then
                        RepairAllItems(true)
                        repairedWithGuild = true
                        Print("Repaired all equipment using Guild Bank funds (" .. FormatGold(repairCost) .. ").")
                    end
                end
            end
            if not repairedWithGuild then
                local myMoney = GetMoney and GetMoney() or 0
                if myMoney >= repairCost then
                    RepairAllItems(false)
                    Print("Repaired all equipment using Personal Gold (" .. FormatGold(repairCost) .. ").")
                else
                    Print("|cFFEF4444Insufficient gold to repair equipment.|r")
                end
            end
        end
    end

    -- 2. Auto-Sell Grey Junk
    if not sess.sold and db.autoSellGrey ~= false and db.autoSellJunk ~= false then
        sess.sold = true
        if C_MerchantFrame and C_MerchantFrame.SellAllJunkItems and C_MerchantFrame.GetNumJunkItems then
            local okCount, numJunk = pcall(C_MerchantFrame.GetNumJunkItems)
            if okCount and type(numJunk) == "number" and numJunk > 0 then
                pcall(C_MerchantFrame.SellAllJunkItems)
            end
        else
            U.AutoSellJunk()
        end
    end

    -- 3. Smart Vendor Auto-Restock (top up configured items up to target stock)
    if not sess.restocked and db.autoRestockEnabled == true and type(db.autoRestockList) == "table" and next(db.autoRestockList) ~= nil then
        sess.restocked = true
        U.AutoRestockAtMerchant()
    end
end

local merchantBulkBuyHooked = false
function U.EnsureMerchantBulkBuyHook()
    if merchantBulkBuyHooked then return end
    if type(_G.MerchantItemButton_OnModifiedClick) == "function" and type(_G.hooksecurefunc) == "function" then
        merchantBulkBuyHooked = true
        _G.hooksecurefunc("MerchantItemButton_OnModifiedClick", function(self, button)
            local db = DB()
            if db.merchantBulkBuy == false or IsModuleDisabledInSuite("DynamicBags") then return end
            if button ~= "RightButton" or not (IsAltKeyDown and IsAltKeyDown()) then return end
            if InCombatLockdown and InCombatLockdown() then return end
            local idx = self and self.GetID and self:GetID()
            if not idx or idx <= 0 then return end
            if type(_G.GetMerchantItemMaxStack) == "function" and type(_G.BuyMerchantItem) == "function" then
                local maxStack = tonumber(_G.GetMerchantItemMaxStack(idx)) or 1
                if maxStack > 1 then
                    pcall(_G.BuyMerchantItem, idx, maxStack)
                end
            end
        end)
    end
end

function U.AutoRestockAtMerchant()
    local db = DB()
    if db.autoRestockEnabled ~= true or type(db.autoRestockList) ~= "table" or IsModuleDisabledInSuite("DynamicBags") then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if type(_G.GetMerchantNumItems) ~= "function" or type(_G.BuyMerchantItem) ~= "function" then return end

    local numMerchant = tonumber(_G.GetMerchantNumItems()) or 0
    local boughtParts = {}
    for i = 1, numMerchant do
        local itemID = (type(_G.GetMerchantItemID) == "function") and _G.GetMerchantItemID(i) or nil
        if itemID and db.autoRestockList[itemID] then
            local targetQty = tonumber(db.autoRestockList[itemID]) or 0
            local haveQty = (C_Item and C_Item.GetItemCount) and (tonumber(C_Item.GetItemCount(itemID, false)) or 0) or 0
            local missing = targetQty - haveQty
            if missing > 0 then
                local info = (C_MerchantFrame and C_MerchantFrame.GetItemInfo) and C_MerchantFrame.GetItemInfo(i) or nil
                local price = (type(info) == "table" and tonumber(info.price)) or 0
                local stackCount = (type(info) == "table" and tonumber(info.stackCount)) or 1
                if stackCount < 1 then stackCount = 1 end
                local maxStack = (type(_G.GetMerchantItemMaxStack) == "function" and tonumber(_G.GetMerchantItemMaxStack(i))) or 1
                if maxStack < 1 then maxStack = 1 end
                local playerMoney = (type(_G.GetMoney) == "function" and tonumber(_G.GetMoney())) or 0
                local unitsNeeded = math.ceil(missing / stackCount)
                if price > 0 then
                    local maxAfford = math.floor(playerMoney / price)
                    unitsNeeded = math.min(unitsNeeded, maxAfford)
                end
                local boughtTotal = 0
                while unitsNeeded > 0 do
                    local chunk = math.min(unitsNeeded, maxStack)
                    pcall(_G.BuyMerchantItem, i, chunk)
                    boughtTotal = boughtTotal + (chunk * stackCount)
                    unitsNeeded = unitsNeeded - chunk
                end
                if boughtTotal > 0 then
                    local iName = (type(info) == "table" and type(info.name) == "string" and info.name ~= "") and info.name or ("Item #" .. tostring(itemID))
                    table.insert(boughtParts, string.format("%dx %s", boughtTotal, iName))
                end
            end
        end
    end
    if #boughtParts > 0 then
        Print("Auto-Restocked: " .. table.concat(boughtParts, ", ") .. ".")
    end
end

function DynamicBags:HandleFastAutoLoot()
    local db = DB()
    if db.fastAutoLoot == false or IsShiftKeyDown() or self:IsYieldingSharedHooks() then return end
    local now = (type(GetTime) == "function" and GetTime()) or 0
    if self._lastFastLootAt and (now - self._lastFastLootAt) < 0.15 then return end
    self._lastFastLootAt = now
    local autoLootCVar = C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("autoLootDefault")
    local isModClick = IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE")
    if (autoLootCVar and not isModClick) or (not autoLootCVar and isModClick) then
        local numItems = GetNumLootItems and GetNumLootItems() or 0
        for i = numItems, 1, -1 do
            if LootSlot and (not LootSlotHasItem or LootSlotHasItem(i)) then
                pcall(LootSlot, i)
            end
        end
    end
end

function DynamicBags:SetupDeleteConfirmationHook()
    if self._deleteHookInstalled then return end
    self._deleteHookInstalled = true

    if StaticPopupDialogs then
        for _, key in ipairs({ "DELETE_GOOD_ITEM", "DELETE_GOOD_QUEST_ITEM" }) do
            local dlg = StaticPopupDialogs[key]
            if dlg then
                hooksecurefunc(dlg, "OnShow", function(s)
                    if not (DB().autoFillDelete ~= false) or IsShiftKeyDown() or DynamicBags:IsYieldingSharedHooks() then return end
                    local name = (s.GetName and s:GetName()) or ""
                    local eb = s.editBox or s.EditBox or (s.GetEditBox and s:GetEditBox()) or (name ~= "" and _G[name .. "EditBox"])
                    if eb and DELETE_ITEM_CONFIRM_STRING then
                        eb:SetText(DELETE_ITEM_CONFIRM_STRING)
                        eb:ClearFocus()
                    end
                    local b1 = s.button1 or s.Button1 or (s.GetButton1 and s:GetButton1()) or (name ~= "" and _G[name .. "Button1"])
                    if b1 and b1.Enable then
                        b1:Enable()
                    end
                end)
            end
        end
    end
end

local NON_TRADEABLE_DIALOG_KEYS = {
    END_BOUND_TRADEABLE = true,
    CONFIRM_BINDER = true,
    NON_TRADEABLE_ITEM = true,
    USE_NO_REFUND_CONFIRM = true,
    CONFIRM_USE_NO_REFUND = true,
    TRADE_POTENTIAL_REMOVE_BIND_CONFIRM = true,
    EQUIP_BIND_TRADEABLE = true,
    BIND_TRADEABLE = true,
    ACTION_WILL_BIND_ITEM = true,
}

local NON_TRADEABLE_DENY_KEYS = {
    CONFIRM_LOOT_ROLL = true,
    LOOT_BIND = true,
    LOOT_BIND_CONFIRM = true,
    CONFIRM_DISENCHANT_ROLL = true,
    DELETE_ITEM = true,
    DELETE_GOOD_ITEM = true,
    DELETE_GOOD_QUEST_ITEM = true,
    CONFIRM_DESTROY_COMMUNITY = true,
    CONFIRM_BUY_BANK_SLOT = true,
    CONFIRM_BUY_GUILDBANK_TAB = true,
    CONFIRM_PURCHASE_TOKEN_ITEM = true,
    CONFIRM_PURCHASE_NONREFUNDABLE_ITEM = true,
    CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL = true,
    CONFIRM_MAIL_ITEM_UNREFUNDABLE = true,
    PARTY_INVITE = true,
    PARTY_INVITE_XREALM = true,
    RESURRECT = true,
    RESURRECT_NO_SICKNESS = true,
    RESURRECT_NO_TIMER = true,
    DEATH = true,
    DEATH_PVP = true,
    DYNAMICBAGS_RELOAD_PROMPT = true,
}

local function GetStaticPopupButton1(popup)
    if not popup then return nil end
    if popup.button1 then return popup.button1 end
    if popup.Button1 then return popup.Button1 end
    if type(popup.GetButton1) == "function" then
        local ok, b = pcall(popup.GetButton1, popup)
        if ok and b then return b end
    end
    local name = (type(popup.GetName) == "function") and popup:GetName() or nil
    if type(name) == "string" and name ~= "" and not IsSecret(name) then
        return _G[name .. "Button1"]
    end
    return nil
end

local function GetStaticPopupTextString(popup)
    if not popup then return nil end
    local fs = popup.text or popup.Text
    if not fs and type(popup.GetTextFontString) == "function" then
        local ok, res = pcall(popup.GetTextFontString, popup)
        if ok and res then fs = res end
    end
    if not fs and type(popup.GetName) == "function" then
        local name = popup:GetName()
        if type(name) == "string" and name ~= "" and not IsSecret(name) then
            fs = _G[name .. "Text"]
        end
    end
    if fs and type(fs.GetText) == "function" then
        local ok, txt = pcall(fs.GetText, fs)
        if ok and type(txt) == "string" and not IsSecret(txt) and txt ~= "" then
            return txt
        end
    end
    return nil
end

local function IsNonTradeableDecorPopup(popup, expectedWhich)
    if not popup then return false end
    local which = popup.which
    if type(which) ~= "string" or IsSecret(which) or which == "" then
        which = expectedWhich
    end
    if type(which) == "string" and not IsSecret(which) and which ~= "" then
        if NON_TRADEABLE_DENY_KEYS[which] then
            return false
        end
        if NON_TRADEABLE_DIALOG_KEYS[which] then
            return true
        end
    end
    local txt = GetStaticPopupTextString(popup)
    if type(txt) == "string" and txt ~= "" then
        local tl = txt:lower()
        if tl:find("make this item non-tradeable", 1, true)
            or tl:find("make this item non tradeable", 1, true)
            or tl:find("make it non-tradeable", 1, true)
            or tl:find("make this item untradeable", 1, true)
            or tl:find("make this item non-refundable", 1, true)
            or (tl:find("performing this action", 1, true) and (tl:find("non-tradeable", 1, true) or tl:find("non-refundable", 1, true))) then
            return true
        end
        for _, gKey in ipairs({
            "END_BOUND_TRADEABLE",
            "CONFIRM_BINDER",
            "NON_TRADEABLE_ITEM",
            "TRADE_POTENTIAL_REMOVE_BIND_CONFIRM",
            "USE_NO_REFUND_CONFIRM",
            "CONFIRM_USE_NO_REFUND",
            "EQUIP_BIND_TRADEABLE",
            "BIND_TRADEABLE",
        }) do
            local gv = _G[gKey]
            if type(gv) == "string" and not IsSecret(gv) and gv ~= "" then
                local needle = gv:gsub("%%s", ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
                if #needle >= 12 and tl:find(needle, 1, true) then
                    return true
                end
            end
        end
    end
    return false
end

function U.ClearDecorUseConfirmWindow()
    S.decorUseConfirmCount = 0
    S.decorUseConfirmExpiresAt = 0
    S.decorUseConfirmSource = nil
    S.decorUseConfirmToken = (S.decorUseConfirmToken or 0) + 1
    S.decorPendingVerify = nil
    S.decorActionBlocked = false
end

function U.IsDecorUseConfirmActive()
    if IsModuleDisabledInSuite("DynamicBags") then return false end
    if InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player")) then
        return false
    end
    if DynamicBags:IsYieldingSharedHooks() then return false end
    if (S.decorUseConfirmCount or 0) <= 0 then return false end
    local now = (type(GetTime) == "function" and GetTime()) or 0
    if now > (S.decorUseConfirmExpiresAt or 0) then
        U.ClearDecorUseConfirmWindow()
        return false
    end
    return true
end

function U.ArmDecorUseConfirmWindow(count, source, durationSec)
    if IsModuleDisabledInSuite("DynamicBags") then
        U.ClearDecorUseConfirmWindow()
        return false
    end
    if InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player")) then
        U.ClearDecorUseConfirmWindow()
        return false
    end
    if DynamicBags:IsYieldingSharedHooks() then
        U.ClearDecorUseConfirmWindow()
        return false
    end
    local n = tonumber(count) or 0
    if n <= 0 then
        U.ClearDecorUseConfirmWindow()
        return false
    end
    local now = (type(GetTime) == "function" and GetTime()) or 0
    local ttl = tonumber(durationSec) or 1.25
    S.decorUseConfirmCount = n
    S.decorUseConfirmExpiresAt = now + ttl
    S.decorUseConfirmSource = source or "AUTO"
    local token = (S.decorUseConfirmToken or 0) + 1
    S.decorUseConfirmToken = token
    if C_Timer and C_Timer.After then
        C_Timer.After(ttl + 0.05, function()
            if S.decorUseConfirmToken == token then
                U.ClearDecorUseConfirmWindow()
            end
        end)
    end
    return true
end

function U.ScanAndConfirmDecorPopup(expectedWhich, targetPopup)
    if not U.IsDecorUseConfirmActive() then return false end
    if type(expectedWhich) == "string" and not IsSecret(expectedWhich) and NON_TRADEABLE_DENY_KEYS[expectedWhich] then
        return false
    end

    local candidates = {}
    local seenCandidates = {}
    local function AddCandidatePopup(p)
        if p and not seenCandidates[p] then
            seenCandidates[p] = true
            candidates[#candidates + 1] = p
        end
    end
    if targetPopup then
        AddCandidatePopup(targetPopup)
    else
        if expectedWhich and type(_G.StaticPopup_FindVisible) == "function" then
            local okF, vis = pcall(_G.StaticPopup_FindVisible, expectedWhich)
            if okF and vis then
                AddCandidatePopup(vis)
            end
        end
        if type(_G.StaticPopup_ForEachShownDialog) == "function" then
            pcall(_G.StaticPopup_ForEachShownDialog, function(dlg)
                AddCandidatePopup(dlg)
            end)
        end
        for i = 1, 4 do
            AddCandidatePopup(_G["StaticPopup" .. i])
        end
    end

    for _, popup in ipairs(candidates) do
        if popup and popup.IsShown and popup:IsShown() then
            local pWhich = popup.which
            local matchesExpected = (not expectedWhich)
                or (type(pWhich) ~= "string" or IsSecret(pWhich) or pWhich == "" or pWhich == expectedWhich)
            if matchesExpected and IsNonTradeableDecorPopup(popup, expectedWhich) then
                local b1 = GetStaticPopupButton1(popup)
                if b1 and b1.IsEnabled and not b1:IsEnabled() then
                    return false
                end
                local activeSource = S.decorUseConfirmSource
                S.decorUseConfirmCount = max(0, (S.decorUseConfirmCount or 1) - 1)
                if S.decorUseConfirmCount <= 0 then
                    S.decorUseConfirmExpiresAt = 0
                    S.decorUseConfirmSource = nil
                    S.decorUseConfirmToken = (S.decorUseConfirmToken or 0) + 1
                end

                -- For hardware clicks on DynamicBagsQuickOpenBtn, let the macro's
                -- /click StaticPopup1Button1 (/click StaticPopup2Button1) execute
                -- the confirmation natively without prematurely hiding the popup.
                if activeSource == "QUICK" then
                    return true
                end

                local resolvedWhich = (type(pWhich) == "string" and not IsSecret(pWhich) and pWhich ~= "") and pWhich or expectedWhich
                S.decorActionBlocked = false
                S.decorPendingVerify = {
                    popup = popup,
                    which = resolvedWhich,
                    bag = S.autoOpenActiveBag,
                    slot = S.autoOpenActiveSlot,
                    itemID = S.autoOpenActiveItemID,
                    prevCount = S.autoOpenActivePrevCount,
                }

                local dlg = (type(StaticPopupDialogs) == "table" and resolvedWhich) and StaticPopupDialogs[resolvedWhich] or nil
                if dlg and type(dlg.OnAccept) == "function" then
                    pcall(dlg.OnAccept, popup, popup.data)
                elseif resolvedWhich == "END_BOUND_TRADEABLE" and type(_G.EndBoundTradeable) == "function" then
                    pcall(_G.EndBoundTradeable, popup.data or 1)
                elseif (resolvedWhich == "CONFIRM_BINDER" or resolvedWhich == "ACTION_WILL_BIND_ITEM") and type(_G.ConfirmBindOnUse) == "function" then
                    pcall(_G.ConfirmBindOnUse)
                elseif (resolvedWhich == "USE_NO_REFUND_CONFIRM" or resolvedWhich == "CONFIRM_USE_NO_REFUND") and type(_G.ConfirmNoRefundOnUse) == "function" then
                    pcall(_G.ConfirmNoRefundOnUse)
                elseif type(_G.EndBoundTradeable) == "function" then
                    pcall(_G.EndBoundTradeable, popup.data or 1)
                elseif type(_G.ConfirmBindOnUse) == "function" then
                    pcall(_G.ConfirmBindOnUse)
                end
                return true
            end
        end
    end
    return false
end

function DynamicBags:SetupDecorNonTradeableConfirmHook()
    if not self._decorStaticPopupShowHooked and type(hooksecurefunc) == "function" and type(_G.StaticPopup_Show) == "function" then
        self._decorStaticPopupShowHooked = true
        hooksecurefunc("StaticPopup_Show", function(which)
            if not U.IsDecorUseConfirmActive() then return end
            if not U.ScanAndConfirmDecorPopup(which) and C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if U.IsDecorUseConfirmActive() then
                        U.ScanAndConfirmDecorPopup(which)
                    end
                end)
            end
        end)
    end

    if not self._decorNonTradeableDlgHooked and type(StaticPopupDialogs) == "table" and type(hooksecurefunc) == "function" then
        local dlg = StaticPopupDialogs["NON_TRADEABLE_ITEM"]
        if dlg and type(dlg.OnShow) == "function" then
            self._decorNonTradeableDlgHooked = true
            hooksecurefunc(dlg, "OnShow", function(s)
                if U.IsDecorUseConfirmActive() then
                    U.ScanAndConfirmDecorPopup("NON_TRADEABLE_ITEM", s)
                end
            end)
        end
    end

    for i = 1, 4 do
        local popup = _G["StaticPopup" .. i]
        if popup and popup.HookScript and not popup._dbagDecorConfirmHooked then
            popup._dbagDecorConfirmHooked = true
            popup:HookScript("OnShow", function(selfPopup)
                if not U.IsDecorUseConfirmActive() then return end
                if not U.ScanAndConfirmDecorPopup(selfPopup.which, selfPopup) and C_Timer and C_Timer.After then
                    C_Timer.After(0, function()
                        if U.IsDecorUseConfirmActive() and selfPopup:IsShown() then
                            U.ScanAndConfirmDecorPopup(selfPopup.which, selfPopup)
                        end
                    end)
                end
            end)
        end
    end
end

function U.AutoSellJunk()
    local db = DB()
    if db.autoSellGrey == false or db.autoSellJunk == false then return end
    if not (C_Container and C_Container.UseContainerItem) then return end
    local queue = {}
    for _, bagID in ipairs(U.GetLiveBagIDs()) do
        local okN, n = pcall(C_Container.GetContainerNumSlots, bagID)
        if okN and type(n) == "number" then
            for slot = 1, n do
                local info = U.GetSlotInfo(bagID, slot)
                if info and info.quality == QUALITY_POOR and not info.hasNoValue then
                    local price = 0
                    if C_Item and C_Item.GetItemInfo and info.hyperlink then
                        local sp = select(11, C_Item.GetItemInfo(info.hyperlink))
                        if type(sp) == "number" then price = sp end
                    end
                    queue[#queue + 1] = { bagID, slot, price * (info.stackCount or 1) }
                end
            end
        end
    end
    if #queue == 0 then return end
    local idx, total, sold = 1, 0, 0
    local function step()
        if InCombatLockdown() then
            return
        end
        if not (MerchantFrame and MerchantFrame:IsShown()) or idx > #queue or idx > 150 then
            if sold > 0 then
                Print(sformat("Sold %d junk item(s) for %s.", sold, U.FormatMoneyWithIcons(total)))
            end
            return
        end
        local q = queue[idx]
        idx = idx + 1
        pcall(C_Container.UseContainerItem, q[1], q[2])
        sold = sold + 1
        total = total + q[3]
        C_Timer.After(0.1, step)
    end
    step()
end

-- ============================================================================
-- 9B. SOULBOUND AUTO-OPEN & 1-SPOT QUICK-OPEN SECURE QUEUE BUTTON
-- ============================================================================

local BASE_PROFESSIONS = {
    "alchemy", "blacksmithing", "enchanting", "engineering",
    "herbalism", "inscription", "jewelcrafting", "leatherworking",
    "mining", "skinning", "tailoring", "cooking", "fishing", "archaeology",
}

function U.GetPlayerStandardBagIDs()
    local ids = {}
    for i = 0, (NUM_BAG_SLOTS or 4) do
        ids[#ids + 1] = i
    end
    return ids
end

function U.GetKnownProfessionNames()
    local known = {}
    local hasAny = false
    if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
        local okP, p1, p2, arch, fish, cook = pcall(GetProfessions)
        if okP then
            for _, idx in ipairs({ p1, p2, arch, fish, cook }) do
                if type(idx) == "number" then
                    local okI, name = pcall(GetProfessionInfo, idx)
                    if okI and type(name) == "string" and name ~= "" and not IsSecret(name) then
                        local nl = name:lower()
                        known[nl] = true
                        hasAny = true
                        for _, baseProf in ipairs(BASE_PROFESSIONS) do
                            if nl:find(baseProf, 1, true) then
                                known[baseProf] = true
                            end
                        end
                    end
                end
            end
        end
    end
    return known, hasAny
end

function U.HasActivePurchaseRefund(bagID, slotID)
    if C_Container and type(C_Container.GetContainerItemPurchaseInfo) == "function" then
        local ok, a, b, c = pcall(C_Container.GetContainerItemPurchaseInfo, bagID, slotID, false)
        if ok and a ~= nil then
            if type(a) == "table" then
                if not IsSecret(a.refundSeconds) and (tonumber(a.refundSeconds) or 0) > 0 then
                    return true
                end
            else
                if not IsSecret(c) and (tonumber(c) or 0) > 0 then
                    return true
                end
            end
        end
    end
    return false
end

function U.IsSlotOnCooldown(bagID, slotID)
    if C_Container and type(C_Container.GetContainerItemCooldown) == "function" then
        local ok, start, duration, enable = pcall(C_Container.GetContainerItemCooldown, bagID, slotID)
        if ok and not IsSecret(start) and not IsSecret(duration) then
            if (tonumber(start) or 0) > 0 and (tonumber(duration) or 0) > 1.5 and enable ~= 0 then
                return true
            end
        end
    end
    return false
end

local function HasProtectedItemSpell(link, itemID)
    if C_Item and type(C_Item.GetItemSpell) == "function" then
        local ok, spellName, spellID = pcall(C_Item.GetItemSpell, link or itemID)
        if ok and not IsSecret(spellName) and not IsSecret(spellID) then
            if (type(spellID) == "number" and spellID > 0) or (type(spellName) == "string" and spellName ~= "") then
                return true
            end
        end
    elseif type(GetItemSpell) == "function" then
        local ok, spellName, spellID = pcall(GetItemSpell, link or itemID)
        if ok and not IsSecret(spellName) and not IsSecret(spellID) then
            if (type(spellID) == "number" and spellID > 0) or (type(spellName) == "string" and spellName ~= "") then
                return true
            end
        end
    end
    return false
end

function U.EvaluateBagSlotOpenable(bagID, slotID, knownProfs)
    local info = U.GetSlotInfo(bagID, slotID)
    if not info or not info.itemID or info.itemID <= 0 then return nil end
    if info.isLocked then return nil end
    if HEARTH_IDS[info.itemID] or IsKeystone(info.itemID, info.hyperlink) then return nil end
    if S.skippedOpenables and S.skippedOpenables[info.itemID] then return nil end

    local link = info.hyperlink
    local classID = 15
    local subClassID = nil
    local itemType, itemSubType = "", ""
    if C_Item and C_Item.GetItemInfoInstant then
        local _, t, st, _, _, cID, subCID = C_Item.GetItemInfoInstant(link or info.itemID)
        itemType = type(t) == "string" and t or ""
        itemSubType = type(st) == "string" and st or ""
        classID = cID or 15
        subClassID = subCID
    end
    if classID == IC.Weapon or classID == IC.Armor or classID == IC.Gem or classID == IC.Enhancement or classID == IC.Recipe or classID == IC.Container then
        return nil
    end
    -- Strictly exclude standard consumables (potions, elixirs, flasks/phials, scrolls, food/drink, bandages, vantus runes).
    if classID == IC.Consumable and subClassID ~= nil and subClassID ~= 8 then
        return nil
    end
    if C_ToyBox and type(C_ToyBox.GetToyInfo) == "function" then
        local okToy, toyID = pcall(C_ToyBox.GetToyInfo, info.itemID)
        if okToy and toyID and not IsSecret(toyID) then return nil end
    end
    if C_MountJournal and type(C_MountJournal.GetMountFromItem) == "function" then
        local okMount, mountID = pcall(C_MountJournal.GetMountFromItem, info.itemID)
        if okMount and mountID and not IsSecret(mountID) then return nil end
    end
    if U.HasActivePurchaseRefund(bagID, slotID) then return nil end
    if U.IsSlotOnCooldown(bagID, slotID) then return nil end

    local isBound = (info.isBound == true)
    local isWueLoc = false
    if ItemLocation and ItemLocation.CreateFromBagAndSlot and C_Item then
        pcall(function()
            local loc = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
            if type(loc) == "table" and loc.HasAnyLocation and loc:HasAnyLocation() and C_Item.DoesItemExist and C_Item.DoesItemExist(loc) then
                if not isBound and C_Item.IsBound and C_Item.IsBound(loc) then
                    isBound = true
                end
                if C_Item.IsBoundToAccountUntilEquip and C_Item.IsBoundToAccountUntilEquip(loc) then
                    isWueLoc = true
                end
            end
        end)
    end

    local isDecorAPI = false
    if C_Housing and type(C_Housing.IsDecorItem) == "function" then
        local ok, r = pcall(C_Housing.IsDecorItem, link or info.itemID)
        if ok and r and not IsSecret(r) then isDecorAPI = true end
    end
    if not isDecorAPI and C_Item and type(C_Item.IsDecorItem) == "function" then
        local ok, r = pcall(C_Item.IsDecorItem, link or info.itemID)
        if ok and r and not IsSecret(r) then isDecorAPI = true end
    end
    if not isDecorAPI and C_Item and type(C_Item.GetItemInfo) == "function" then
        local ok, _, _, _, _, _, t6, t7 = pcall(C_Item.GetItemInfo, link or info.itemID)
        if ok then
            if type(t6) == "string" and not IsSecret(t6) and t6:lower():find("decor", 1, true) then isDecorAPI = true end
            if type(t7) == "string" and not IsSecret(t7) and t7:lower():find("decor", 1, true) then isDecorAPI = true end
        end
    end
    if not isDecorAPI then
        if itemType:lower():find("decor", 1, true) or itemSubType:lower():find("decor", 1, true) then
            isDecorAPI = true
        end
    end

    local sawSoulbound = false
    local sawAccountBound = false
    local sawWUE = isWueLoc
    local sawBoE = false
    local sawRightClickOpen = false
    local sawUseLine = false
    local sawDecorLine = isDecorAPI
    local sawKnowledgeLine = false
    local sawWrappedLine = false
    local isVendorRefundLocked = false
    local sawUseCacheLine = false
    local hasRedText = false
    local hasDisqualifyingLine = false
    local tooltipTextConcat = ""

    if C_TooltipInfo and type(C_TooltipInfo.GetBagItem) == "function" then
        local okT, data = pcall(C_TooltipInfo.GetBagItem, bagID, slotID)
        if okT and type(data) == "table" and type(data.lines) == "table" then
            for _, line in ipairs(data.lines) do
                local lc = line.leftColor
                if type(lc) == "table" and not hasRedText then
                    local okC, red = pcall(function() return lc.r > 0.9 and lc.g < 0.25 and lc.b < 0.25 end)
                    if okC and red then hasRedText = true end
                end
                local rc = line.rightColor
                if type(rc) == "table" and not hasRedText then
                    local okC, red = pcall(function() return rc.r > 0.9 and rc.g < 0.25 and rc.b < 0.25 end)
                    if okC and red then hasRedText = true end
                end

                local t = line.leftText
                if type(t) == "string" and not IsSecret(t) then
                    local tl = t:lower()
                    tooltipTextConcat = tooltipTextConcat .. " " .. tl

                    if (LOCKED and t == LOCKED) or tl == "locked" or tl:find("^locked ")
                        or tl:find("requires lockpicking", 1, true)
                        or tl:find("requires .* key")
                        or tl:find("combine %d+")
                        or tl:find("turn %d+ ")
                        or tl:find("consume %d+ ")
                        or tl:find("requires %d+ ")
                        or tl:find("teaches you how to summon this mount", 1, true)
                        or tl:find("adds this toy to your toy box", 1, true)
                        or tl:find("use: restores ", 1, true)
                        or tl:find("well fed", 1, true)
                        or tl:find("splintered spark", 1, true) then
                        hasDisqualifyingLine = true
                    end

                    if tl:find("you may sell this item to a vendor within", 1, true)
                        or tl:find("make this item non-refundable", 1, true) then
                        isVendorRefundLocked = true
                    end

                    if (ITEM_WRAPPED and t == ITEM_WRAPPED)
                        or tl:find("right click to unwrap", 1, true)
                        or tl:find("^use: unwrap")
                        or tl:find("wrapped gift", 1, true)
                        or tl:find("gift-wrapped", 1, true) then
                        sawWrappedLine = true
                    end

                    if t == ITEM_SOULBOUND or t == ITEM_BIND_ON_PICKUP
                        or tl:find("soulbound", 1, true)
                        or tl:find("binds when picked up", 1, true) then
                        sawSoulbound = true
                    end
                    if MatchesGlobals(t, WUE_GLOBALS)
                        or tl:find("warbound", 1, true)
                        or tl:find("account bound", 1, true)
                        or tl:find("binds to warband", 1, true)
                        or tl:find("bnetaccountbound", 1, true) then
                        sawAccountBound = true
                    end
                    if tl:find("until equipped", 1, true) then
                        sawWUE = true
                    end
                    if MatchesGlobals(t, BOE_GLOBALS)
                        or tl:find("binds when equipped", 1, true)
                        or tl:find("bind on equip", 1, true)
                        or tl:find("binds when used", 1, true) then
                        sawBoE = true
                    end

                    if (ITEM_OPENABLE and t == ITEM_OPENABLE)
                        or tl:find("right click to open", 1, true) then
                        sawRightClickOpen = true
                    end

                    if tl:find("^use:") or tl:find("use: ", 1, true) then
                        sawUseLine = true
                        if tl:find("^use: open") or tl:find("^use: unpack")
                            or tl:find("^use: rummage") or tl:find("^use: crack open")
                            or tl:find("^use: break open") or tl:find("^use: claim")
                            or tl:find("^use: empty") or tl:find("^use: loot")
                            or tl:find("^use: shake") or tl:find("^use: pry open")
                            or tl:find("^use: smash open") or tl:find("^use: tear open")
                            or tl:find("^use: unseal") or tl:find("^use: collect the contents")
                            or tl:find("open the ", 1, true) or tl:find("open this ", 1, true) then
                            sawUseCacheLine = true
                        end
                    end

                    if tl:find("housing decor", 1, true)
                        or tl:find("room decor", 1, true)
                        or tl:find("house chest", 1, true)
                        or tl:find("housing catalog", 1, true)
                        or tl:find("housing catalogue", 1, true)
                        or tl:find("decor catalog", 1, true) then
                        sawDecorLine = true
                    end

                    if tl:find("knowledge", 1, true) and (
                        tl:find("study to increase your", 1, true)
                        or tl:find("profession knowledge", 1, true)
                        or tl:find("specialization knowledge", 1, true)
                        or tl:find("specialisation knowledge", 1, true)
                        or tl:find("increase .* knowledge")
                        or tl:find("grants %+?%d+ .* knowledge")
                        or tl:find("gain %+?%d+ .* knowledge")
                    ) then
                        sawKnowledgeLine = true
                    end
                end
            end
        end
    end

    if hasRedText or hasDisqualifyingLine then
        return nil
    end

    local isStrictlyBound = (isBound == true) or (sawSoulbound and not sawBoE)
    local isSafeAccountBound = (sawAccountBound and not sawWUE and not sawBoE)

    local name = (type(link) == "string" and link:match("%[(.-)%]")) or info.itemName or ("Item #" .. tostring(info.itemID))
    local nameLower = type(name) == "string" and name:lower() or ""
    local isGoldOrLootSatchel = false
    if nameLower ~= "" and (sawRightClickOpen or sawUseLine or info.hasLoot == true) then
        if nameLower:find("gold pouch", 1, true)
            or nameLower:find("coin pouch", 1, true)
            or nameLower:find("coin purse", 1, true)
            or nameLower:find("coinpurse", 1, true)
            or nameLower:find("pouch of gold", 1, true)
            or nameLower:find("pouch of coins", 1, true)
            or nameLower:find("bag of gold", 1, true)
            or nameLower:find("sack of gold", 1, true)
            or nameLower:find("loot satchel", 1, true)
            or nameLower:find("gold satchel", 1, true)
            or nameLower:find("treasure satchel", 1, true)
            or nameLower:find("treasure pouch", 1, true)
            or (nameLower:find("satchel", 1, true) and (nameLower:find("gold", 1, true) or nameLower:find("coin", 1, true) or nameLower:find("loot", 1, true) or nameLower:find("bountiful", 1, true)))
            or (nameLower:find("pouch", 1, true) and (nameLower:find("gold", 1, true) or nameLower:find("coin", 1, true) or nameLower:find("overflowing", 1, true) or nameLower:find("bulging", 1, true) or nameLower:find("gilded", 1, true))) then
            isGoldOrLootSatchel = true
        end
    end

    local kind = nil
    local categoryLabel = nil

    if sawWrappedLine then
        kind = "WRAPPED"
        categoryLabel = "Wrapped Item"
    elseif sawDecorLine and (sawUseLine or info.hasLoot == true or isDecorAPI) then
        kind = "DECOR"
        categoryLabel = "Housing Decor"
    elseif sawKnowledgeLine and sawUseLine then
        local profMap = knownProfs or U.GetKnownProfessionNames()
        local matchedProf = false
        local mentionsSpecificProf = false
        for _, baseProf in ipairs(BASE_PROFESSIONS) do
            if tooltipTextConcat:find(baseProf, 1, true) then
                mentionsSpecificProf = true
                if profMap[baseProf] then
                    matchedProf = true
                    break
                end
            end
        end
        if not matchedProf then
            return nil
        end
        if not mentionsSpecificProf then
            return nil
        end
        kind = "KNOWLEDGE"
        categoryLabel = "Profession Knowledge"
    elseif info.hasLoot == true or sawRightClickOpen or isGoldOrLootSatchel then
        kind = "CONTAINER"
        categoryLabel = isGoldOrLootSatchel and "Gold / Loot Pouch" or "Loot Container"
    elseif sawUseCacheLine then
        kind = "CACHE"
        categoryLabel = "Usable Cache"
    else
        return nil
    end

    if isVendorRefundLocked and kind ~= "WRAPPED" then
        return nil
    end

    local db = DB()
    local requireBound = (db.openablesSoulboundOnly ~= false)
    if requireBound and not (isStrictlyBound or isSafeAccountBound) then
        return nil
    end

    local hasProtectedSpell = HasProtectedItemSpell(link, info.itemID)
    return {
        bag = bagID,
        slot = slotID,
        itemID = info.itemID,
        link = link,
        name = name,
        icon = info.iconFileID or 134400,
        count = info.stackCount or 1,
        quality = info.quality or 1,
        hasLoot = (info.hasLoot == true),
        sawUseLine = sawUseLine,
        isGoldOrLootSatchel = isGoldOrLootSatchel,
        hasProtectedSpell = hasProtectedSpell,
        isBound = isStrictlyBound,
        isAccountBound = isSafeAccountBound,
        isUnboundBoE = not (isStrictlyBound or isSafeAccountBound),
        isVendorRefundLocked = isVendorRefundLocked and true or false,
        kind = kind,
        categoryLabel = categoryLabel,
    }
end

function U.ScanOpenables()
    local db = DB()
    local autoList = {}
    local queueList = {}
    local instantQueue = {}
    local lootWindowQueue = {}
    local knownProfs = U.GetKnownProfessionNames()
    local now = GetTime and GetTime() or 0

    for _, bagID in ipairs(U.GetPlayerStandardBagIDs()) do
        local okN, numSlots = pcall(C_Container.GetContainerNumSlots, bagID)
        if okN and type(numSlots) == "number" and numSlots > 0 then
            for slot = 1, numSlots do
                local cand = U.EvaluateBagSlotOpenable(bagID, slot, knownProfs)
                if cand then
                    local isBoundSafe = (cand.isBound or cand.isAccountBound) and not cand.isUnboundBoE
                    local isBlacklisted = (S.autoOpenBlacklist and S.autoOpenBlacklist[cand.itemID]) and true or false
                    local onRetryCooldown = (S.autoOpenRetryAfter and (S.autoOpenRetryAfter[cand.itemID] or 0) > now) and true or false
                    local canAutoByCategory = (cand.kind == "CONTAINER" and db.autoOpenContainers ~= false)
                        or (cand.kind == "DECOR" and db.autoOpenHousingDecor ~= false)
                        or (cand.kind == "KNOWLEDGE" and db.autoOpenKnowledgeItems ~= false)
                        or (cand.kind == "WRAPPED" and db.autoUnwrapItems == true and not cand.isVendorRefundLocked)

                    if isBoundSafe and canAutoByCategory and not cand.hasProtectedSpell and not isBlacklisted and not onRetryCooldown then
                        autoList[#autoList + 1] = cand
                    end

                    local includeInQueue = false
                    if db.quickOpenEnabled ~= false then
                        if cand.kind == "DECOR" and db.queueHousingDecor ~= false then
                            includeInQueue = true
                        elseif cand.kind == "KNOWLEDGE" and db.queueKnowledgeItems ~= false then
                            includeInQueue = true
                        elseif cand.kind == "CACHE" or cand.kind == "CONTAINER" or cand.kind == "WRAPPED" then
                            includeInQueue = true
                        end
                    end
                    if includeInQueue then
                        if cand.hasLoot and not cand.sawUseLine then
                            lootWindowQueue[#lootWindowQueue + 1] = cand
                        else
                            instantQueue[#instantQueue + 1] = cand
                        end
                    end
                end
            end
        end
    end

    for _, c in ipairs(instantQueue) do queueList[#queueList + 1] = c end
    for _, c in ipairs(lootWindowQueue) do queueList[#queueList + 1] = c end

    S.quickOpenQueue = queueList
    return autoList, queueList
end
U.ScanOpenableItems = U.ScanOpenables

function U.CanRunAutoOpenContainers()
    if IsModuleDisabledInSuite("DynamicBags") then return false end
    local db = DB()
    if db.autoOpenContainers == false and db.autoOpenHousingDecor == false and db.autoOpenKnowledgeItems == false and db.autoUnwrapItems ~= true then
        return false
    end
    if InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player")) then
        return false
    end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
        return false
    end
    if (UnitCastingInfo and UnitCastingInfo("player")) or (UnitChannelInfo and UnitChannelInfo("player")) then
        return false
    end
    if LootFrame and LootFrame:IsShown() then
        return false
    end
    if S.atBank or S.atGuildBank then
        return false
    end
    if S.bankWindow and S.bankWindow:IsShown() then
        return false
    end
    for _, frameName in ipairs({
        "BankFrame",
        "AccountBankPanel",
        "GuildBankFrame",
        "MerchantFrame",
        "MailFrame",
        "SendMailFrame",
        "TradeFrame",
        "AuctionHouseFrame",
    }) do
        local f = _G[frameName]
        if f and f.IsShown and f:IsShown() then
            return false
        end
    end
    return true
end

function U.RunNextAutoOpenContainer()
    S.autoOpenTimer = nil
    if not U.CanRunAutoOpenContainers() then return end
    if not (C_Container and C_Container.UseContainerItem) then return end

    local autoList = U.ScanOpenables()
    local cand = autoList and autoList[1]
    if not cand then return end

    if HasProtectedItemSpell(cand.link, cand.itemID) then
        S.autoOpenBlacklist[cand.itemID] = true
        if not InCombatLockdown() and U.UpdateQuickOpenButton and S.window and S.window:IsShown() then
            U.UpdateQuickOpenButton()
        end
        U.ScheduleAutoOpenContainers()
        return
    end

    local prevInfo = U.GetSlotInfo(cand.bag, cand.slot)
    if not prevInfo or prevInfo.itemID ~= cand.itemID or prevInfo.isLocked then
        return
    end
    local prevCount = prevInfo.stackCount or cand.count or 1
    local now = GetTime and GetTime() or 0
    S.autoOpenRetryAfter[cand.itemID] = now + 1.0

    S.autoOpenActiveItemID = cand.itemID
    S.autoOpenActiveBag = cand.bag
    S.autoOpenActiveSlot = cand.slot
    S.autoOpenActivePrevCount = prevCount
    S.decorActionBlocked = false
    if cand.kind == "DECOR" then
        U.ArmDecorUseConfirmWindow(1, "AUTO", 0.60)
    else
        U.ClearDecorUseConfirmWindow()
    end
    local ok = pcall(C_Container.UseContainerItem, cand.bag, cand.slot)
    S.autoOpenActiveItemID = nil
    S.autoOpenActiveBag = nil
    S.autoOpenActiveSlot = nil
    S.autoOpenActivePrevCount = nil
    if not ok then
        if cand.kind == "DECOR" then
            U.ClearDecorUseConfirmWindow()
        end
        S.autoOpenFailCount[cand.itemID] = (S.autoOpenFailCount[cand.itemID] or 0) + 1
        S.autoOpenRetryAfter[cand.itemID] = now + 30.0
        if S.autoOpenFailCount[cand.itemID] >= 2 then
            S.autoOpenBlacklist[cand.itemID] = true
        end
        if not InCombatLockdown() and U.UpdateQuickOpenButton and S.window and S.window:IsShown() then
            U.UpdateQuickOpenButton()
        end
        return
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.45, function()
            local afterInfo = U.GetSlotInfo(cand.bag, cand.slot)
            local pendingVerify = S.decorPendingVerify
            local wasConsumed = (not afterInfo) or (afterInfo.itemID ~= cand.itemID) or ((afterInfo.stackCount or 1) < prevCount)
            if not wasConsumed then
                if cand.kind == "DECOR" and (S.decorActionBlocked or (pendingVerify and pendingVerify.itemID == cand.itemID)) then
                    -- Hardware click required on StaticPopup1Button1: keep the dialog open,
                    -- stop background auto-open retries for this item, and keep Open (N) ready.
                    S.autoOpenBlacklist[cand.itemID] = true
                else
                    S.autoOpenFailCount[cand.itemID] = (S.autoOpenFailCount[cand.itemID] or 0) + 1
                    S.autoOpenRetryAfter[cand.itemID] = (GetTime and GetTime() or 0) + 30.0
                    if S.autoOpenFailCount[cand.itemID] >= 2 then
                        S.autoOpenBlacklist[cand.itemID] = true
                    end
                end
            else
                S.autoOpenFailCount[cand.itemID] = 0
                S.autoOpenRetryAfter[cand.itemID] = nil
                if pendingVerify and pendingVerify.itemID == cand.itemID and not S.decorActionBlocked then
                    local pop = pendingVerify.popup
                    local pWhich = pendingVerify.which
                    if pop and pop.IsShown and pop:IsShown() and pWhich and type(_G.StaticPopup_Hide) == "function" then
                        local curW = pop.which
                        if type(curW) ~= "string" or IsSecret(curW) or curW == "" or curW == pWhich then
                            pcall(_G.StaticPopup_Hide, pWhich)
                        end
                    end
                end
                if S.decorUseConfirmSource == "AUTO" then
                    U.ClearDecorUseConfirmWindow()
                end
            end
            S.decorPendingVerify = nil
            S.decorActionBlocked = false
            if not InCombatLockdown() and U.UpdateQuickOpenButton and S.window and S.window:IsShown() then
                U.UpdateQuickOpenButton()
            end
            if U.CanRunAutoOpenContainers() then
                U.ScheduleAutoOpenContainers()
            end
        end)
    end
end

function U.ScheduleAutoOpenContainers()
    if S.autoOpenTimer then
        if S.autoOpenTimer.Cancel then pcall(S.autoOpenTimer.Cancel, S.autoOpenTimer) end
        S.autoOpenTimer = nil
    end
    if not InCombatLockdown() and U.UpdateQuickOpenButton and S.window and S.window:IsShown() then
        U.UpdateQuickOpenButton()
    end
    if not U.CanRunAutoOpenContainers() then return end
    local autoList = U.ScanOpenables()
    if not autoList or #autoList == 0 then return end
    if C_Timer and C_Timer.NewTimer then
        S.autoOpenTimer = C_Timer.NewTimer(0.35, U.RunNextAutoOpenContainer)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(0.35, U.RunNextAutoOpenContainer)
    end
end

function U.RefreshQuickOpenTooltip(btn)
    if not btn or not GameTooltip then return end
    local cur = S.quickOpenCurrent
    if not cur then
        GameTooltip:Hide()
        return
    end
    local totalCount = #(S.quickOpenQueue or {})
    local batchCount = S.quickOpenBatchCount or 1
    GameTooltip:SetOwner(btn, "ANCHOR_BOTTOM")
    if GameTooltip.SetBagItem then
        pcall(GameTooltip.SetBagItem, GameTooltip, cur.bag, cur.slot)
    else
        GameTooltip:SetText(cur.name or "Queued Item", 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    local tagText = cur.categoryLabel or "Openable"
    if cur.isUnboundBoE then
        tagText = tagText .. " |cFFF59E0B[Unbound / BoE]|r"
    else
        tagText = tagText .. " |cFF34D399[Bound]|r"
    end
    GameTooltip:AddDoubleLine("|cFF94A3B8Quick-Open Queue:|r", "|cFFFFFFFF" .. tagText .. "|r")
    if batchCount > 1 then
        GameTooltip:AddLine(sformat("|cFF34D399Left-Click / Alt+Scroll:|r |cFFE2E8F0Batch-Open %d items in 1 click (%d queued)|r", batchCount, max(1, totalCount)), 0.886, 0.910, 0.941)
    else
        GameTooltip:AddLine(sformat("|cFF34D399Left-Click / Alt+Scroll:|r |cFFE2E8F0Open / Learn (%d queued)|r", max(1, totalCount)), 0.886, 0.910, 0.941)
    end
    GameTooltip:AddLine("|cFF38BDF8Right-Click:|r |cFFE2E8F0Skip item for this session|r", 0.886, 0.910, 0.941)
    if S.skippedOpenables and next(S.skippedOpenables) ~= nil then
        GameTooltip:AddLine("|cFFF59E0BShift + Right-Click:|r |cFFE2E8F0Restore skipped items|r", 0.886, 0.910, 0.941)
    end
    GameTooltip:Show()
end

function U.SyncQuickOpenClickRegistration(btn)
    btn = btn or S.quickOpenBtn
    if not btn or InCombatLockdown() then return end
    local useKeyDown = C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("ActionButtonUseKeyDown")
    if useKeyDown then
        btn:RegisterForClicks("LeftButtonDown", "RightButtonUp")
    else
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
end

function U.ClearQuickOpenBindings(btn)
    btn = btn or S.quickOpenBtn
    if not btn or InCombatLockdown() then return end
    if ClearOverrideBindings then
        pcall(ClearOverrideBindings, btn)
    end
    S.quickOpenWheelBound = false
end

function U.EnsureQuickOpenButton()
    if S.quickOpenBtn then return S.quickOpenBtn end
    if InCombatLockdown() then
        S.pendingQuickOpenSync = true
        return nil
    end

    -- Parent strictly to UIParent (NEVER S.window or win.head) so DynamicBagsFrame never becomes protected in combat!
    local btn = CreateFrame("Button", "DynamicBagsQuickOpenBtn", UIParent, "SecureActionButtonTemplate, SecureHandlerStateTemplate, BackdropTemplate")
    btn:SetSize(112, 24)
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(30)
    U.SyncQuickOpenClickRegistration(btn)
    btn:Hide()

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(16, 16)
    btn.icon:SetPoint("LEFT", btn, "LEFT", 6, 0)
    if btn.icon.SetTexCoord then
        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    btn.label = btn:CreateFontString(nil, "OVERLAY")
    SetFont(btn.label, 11, "")
    btn.label:SetPoint("LEFT", btn.icon, "RIGHT", 5, 0)
    btn.label:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    btn.label:SetJustifyH("LEFT")
    btn.label:SetWordWrap(false)

    function btn:ApplyAccentStyle()
        local ar, ag, ab = GetAccent()
        if self.hover then
            Backdrop(self, 0.11, 0.15, 0.21, 0.98, ar, ag, ab, 1.0)
            self.label:SetTextColor(1.0, 1.0, 1.0, 1.0)
        else
            Backdrop(self, 0.07, 0.10, 0.14, 0.96, ar, ag, ab, 0.90)
            self.label:SetTextColor(0.95, 0.98, 1.0, 1.0)
        end
    end
    btn:ApplyAccentStyle()

    btn:SetScript("OnEnter", function(self)
        self.hover = true
        self:ApplyAccentStyle()
        U.RefreshQuickOpenTooltip(self)
    end)
    btn:SetScript("OnLeave", function(self)
        self.hover = false
        self:ApplyAccentStyle()
        if GameTooltip then GameTooltip:Hide() end
    end)

    btn:SetScript("PreClick", function(self, button, down)
        if button ~= "LeftButton" or InCombatLockdown() then return end
        local useKeyDown = C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("ActionButtonUseKeyDown")
        if useKeyDown ~= nil and down ~= nil and down ~= useKeyDown then
            return
        end
        local cur = S.quickOpenCurrent
        local decorCount = S.quickOpenBatchDecorCount or 0
        if (cur and cur.kind == "DECOR") or decorCount > 0 then
            -- If an unrelated StaticPopup (e.g. loot roll, delete, party invite) is
            -- already visible before clicking Open (N), strip /click StaticPopup*
            -- lines for this click so it can never confirm an unrelated dialog.
            local hasUnrelatedPopup = false
            for idx = 1, 2 do
                local pop = _G["StaticPopup" .. idx]
                if pop and pop.IsShown and pop:IsShown() and not IsNonTradeableDecorPopup(pop, pop.which) then
                    hasUnrelatedPopup = true
                    break
                end
            end
            if hasUnrelatedPopup and type(S.quickOpenBaseMacroText) == "string" then
                local stripped = S.quickOpenBaseMacroText:gsub("\n?/click StaticPopup%dButton1", "")
                self:SetAttribute("macrotext", stripped)
                self:SetAttribute("macrotext1", stripped)
                S.quickOpenPreClickStripped = true
            else
                S.quickOpenPreClickStripped = false
            end
            U.ArmDecorUseConfirmWindow(max(1, decorCount), "QUICK", 1.25)
        else
            S.quickOpenPreClickStripped = false
            U.ClearDecorUseConfirmWindow()
        end
    end)

    btn:SetScript("PostClick", function(self, button, down)
        if button == "LeftButton" and S.quickOpenPreClickStripped and not InCombatLockdown() then
            S.quickOpenPreClickStripped = false
            if type(S.quickOpenBaseMacroText) == "string" then
                self:SetAttribute("macrotext", S.quickOpenBaseMacroText)
                self:SetAttribute("macrotext1", S.quickOpenBaseMacroText)
            end
        end
        if button == "RightButton" then
            if down then return end
            if IsShiftKeyDown and IsShiftKeyDown() then
                wipe(S.skippedOpenables)
                Print("Restored all skipped Quick-Open items for this session.")
            else
                local cur = S.quickOpenCurrent
                if cur and cur.itemID then
                    S.skippedOpenables[cur.itemID] = true
                    Print("Skipped " .. tostring(cur.link or cur.name) .. " for this session (Shift+Right-Click Open button to restore).")
                end
            end
            if not InCombatLockdown() then
                U.UpdateQuickOpenButton()
                if self.hover then U.RefreshQuickOpenTooltip(self) end
            else
                S.pendingQuickOpenSync = true
            end
            return
        end

        if button == "LeftButton" and S.decorUseConfirmSource == "QUICK" and (S.decorUseConfirmCount or 0) > 0 then
            local now = (type(GetTime) == "function" and GetTime()) or 0
            S.decorUseConfirmExpiresAt = min(S.decorUseConfirmExpiresAt or (now + 0.45), now + 0.45)
            local postToken = S.decorUseConfirmToken
            if C_Timer and C_Timer.After then
                C_Timer.After(0.50, function()
                    if S.decorUseConfirmToken == postToken then
                        U.ClearDecorUseConfirmWindow()
                    end
                end)
            end
        end

        if C_Timer and C_Timer.After then
            C_Timer.After(0.10, function()
                if not InCombatLockdown() then
                    U.UpdateQuickOpenButton()
                    if self.hover and self:IsShown() then
                        U.RefreshQuickOpenTooltip(self)
                    end
                else
                    S.pendingQuickOpenSync = true
                end
            end)
        end
    end)

    S.quickOpenBtn = btn
    return btn
end

function U.UpdateQuickOpenButton()
    if InCombatLockdown() then
        S.pendingQuickOpenSync = true
        return
    end
    S.pendingQuickOpenSync = false

    local win = S.window
    local db = DB()
    local isLiveBagsShown = (win and win:IsShown() and S.view.char == nil and S.view.mode == "BAGS") and true or false

    local _, queueList = U.ScanOpenables()
    local totalStacks = #(queueList or {})
    local totalItems = 0
    for _, item in ipairs(queueList or {}) do
        totalItems = totalItems + (item.count or 1)
    end
    local headItem = queueList and queueList[1] or nil
    S.quickOpenCurrent = headItem
    S.quickOpenBatchCount = 0

    local shouldShow = (isLiveBagsShown and db.quickOpenEnabled ~= false and headItem ~= nil)

    if win and win.searchBox and win.presetBtn then
        win.searchBox:ClearAllPoints()
        win.searchBox:SetPoint("TOPLEFT", win.head, "TOPLEFT", 10, -36)
        if shouldShow then
            win.searchBox:SetPoint("RIGHT", win.presetBtn, "LEFT", -120, 0)
        else
            win.searchBox:SetPoint("RIGHT", win.presetBtn, "LEFT", -6, 0)
        end
    end

    if not shouldShow then
        S.quickOpenBatchDecorCount = 0
        S.quickOpenBaseMacroText = nil
        S.quickOpenPreClickStripped = false
        local btn = S.quickOpenBtn
        if btn then
            U.ClearQuickOpenBindings(btn)
            btn:SetAttribute("type", nil)
            btn:SetAttribute("type1", nil)
            btn:SetAttribute("item", nil)
            btn:SetAttribute("item1", nil)
            btn:SetAttribute("macrotext", nil)
            btn:SetAttribute("macrotext1", nil)
            if RegisterStateDriver then
                pcall(RegisterStateDriver, btn, "visibility", "hide")
            end
            btn:Hide()
        end
        return
    end

    local btn = U.EnsureQuickOpenButton()
    if not btn or not win then return end
    U.SyncQuickOpenClickRegistration(btn)

    btn:SetScale(win:GetScale() or 1)
    btn:SetFrameStrata(win:GetFrameStrata() or "HIGH")
    local baseLevel = (win.head and win.head:GetFrameLevel()) or win:GetFrameLevel() or 10
    btn:SetFrameLevel(baseLevel + 10)
    btn:ClearAllPoints()
    btn:SetPoint("RIGHT", win.presetBtn, "LEFT", -4, 0)

    local macroLines = {}
    local curLen = 0
    local batchDecorCount = 0
    local clickPopup1 = "/click StaticPopup1Button1"
    local clickPopup2 = "/click StaticPopup2Button1"

    local function CanAppendLines(linesToAdd)
        local extra = 0
        for i, l in ipairs(linesToAdd) do
            local needNewline = (#macroLines > 0) or (i > 1)
            extra = extra + (needNewline and (#l + 1) or #l)
        end
        return (curLen + extra) <= 255
    end

    local function AppendLines(linesToAdd)
        for _, l in ipairs(linesToAdd) do
            curLen = curLen + ((#macroLines == 0) and #l or (#l + 1))
            macroLines[#macroLines + 1] = l
        end
    end

    if headItem.hasLoot and not headItem.sawUseLine then
        local useLine = sformat("/use %d %d", headItem.bag, headItem.slot)
        AppendLines({ useLine })
        if headItem.kind == "DECOR" then
            batchDecorCount = 1
            if CanAppendLines({ clickPopup1 }) then AppendLines({ clickPopup1 }) end
            if CanAppendLines({ clickPopup2 }) then AppendLines({ clickPopup2 }) end
        end
        S.quickOpenBatchCount = 1
    else
        local usedItems = 0
        for _, cand in ipairs(queueList or {}) do
            if not (cand.hasLoot and not cand.sawUseLine) then
                local useLine = sformat("/use %d %d", cand.bag, cand.slot)
                if cand.kind == "DECOR" then
                    if CanAppendLines({ useLine, clickPopup1 }) then
                        AppendLines({ useLine, clickPopup1 })
                        batchDecorCount = batchDecorCount + 1
                        usedItems = usedItems + 1
                    else
                        break
                    end
                else
                    if CanAppendLines({ useLine }) then
                        AppendLines({ useLine })
                        usedItems = usedItems + 1
                    else
                        break
                    end
                end
            end
        end
        if usedItems == 0 then
            local fallbackLine = sformat("/use %d %d", headItem.bag, headItem.slot)
            if headItem.kind == "DECOR" and CanAppendLines({ fallbackLine, clickPopup1 }) then
                AppendLines({ fallbackLine, clickPopup1 })
                batchDecorCount = 1
            else
                AppendLines({ fallbackLine })
            end
            usedItems = 1
        end
        if batchDecorCount > 0 and CanAppendLines({ clickPopup2 }) then
            AppendLines({ clickPopup2 })
        end
        S.quickOpenBatchCount = usedItems
    end
    S.quickOpenBatchDecorCount = batchDecorCount
    local macroText = table.concat(macroLines, "\n")
    S.quickOpenBaseMacroText = macroText

    btn:SetAttribute("type", "macro")
    btn:SetAttribute("type1", "macro")
    btn:SetAttribute("macrotext", macroText)
    btn:SetAttribute("macrotext1", macroText)
    btn:SetAttribute("item", nil)
    btn:SetAttribute("item1", nil)
    btn:SetAttribute("type2", nil)
    btn:SetAttribute("item2", nil)

    btn.icon:SetTexture(headItem.icon or 134400)
    local badgeNum = max(totalStacks, totalItems)
    local prefix
    if headItem.isUnboundBoE then
        prefix = "BoE ("
    elseif badgeNum > 1 then
        prefix = "Open All ("
    else
        prefix = "Open ("
    end
    btn.label:SetText(sformat("%s%d)", prefix, badgeNum))
    local lblW = (btn.label.GetStringWidth and btn.label:GetStringWidth()) or 76
    btn:SetWidth(max(102, min(116, floor(lblW + 34))))
    btn:ApplyAccentStyle()

    if SetOverrideBindingClick and not S.quickOpenWheelBound then
        pcall(SetOverrideBindingClick, btn, true, "ALT-MOUSEWHEELUP", "DynamicBagsQuickOpenBtn", "LeftButton")
        pcall(SetOverrideBindingClick, btn, true, "ALT-MOUSEWHEELDOWN", "DynamicBagsQuickOpenBtn", "LeftButton")
        S.quickOpenWheelBound = true
    end

    if RegisterStateDriver then
        pcall(RegisterStateDriver, btn, "visibility", "[combat][petbattle][vehicleui] hide; show")
    end
    btn:Show()
    if btn.hover then
        U.RefreshQuickOpenTooltip(btn)
    end
end

-- ============================================================================
-- 10. DYNAMICSUITE REGISTRATION, SLASH COMMANDS & EVENT DISPATCHER
-- ============================================================================

DynamicBags.CONFLICT_REGISTRY = {
    conflicts = { "EllesmereUIBags", "EllesmereUI_Bags", "EllesmereUI", "Baganator", "BetterBags", "AdiBags", "ArkInventory", "Bagnon", "Sorted", "LiteBag", "Syndicator", "BaudBag", "Combuctor", "Inventorian", "ElvUI_Bags", "ElvUI" },
    hardConflicts = { "EllesmereUIBags", "EllesmereUI_Bags", "EllesmereUI", "Baganator", "BetterBags", "AdiBags", "ArkInventory", "Bagnon", "Sorted", "LiteBag", "Syndicator", "BaudBag", "Combuctor", "Inventorian", "ElvUI_Bags", "ElvUI" },
    partialConflicts = { "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL", "Scrap", "Dejunk", "SellJunk", "AutoSeller", "SpeedyAutoLoot", "AutoLootPlus", "WindTools" },
    softConflicts = { "EnhanceQoL", "Leatrix_Plus", "EllesmereUIQoL", "EllesmereUI_QoL", "Scrap", "Dejunk", "SellJunk", "AutoSeller", "SpeedyAutoLoot", "AutoLootPlus", "WindTools" },
    category = "Inventory & Bags",
}

local function RegisterWithDynamicSuite()
    _G.DynamicSuite = _G.DynamicSuite or {}
    _G.DynamicSuite.modules = _G.DynamicSuite.modules or {}
    local iconPath = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_bags.tga"
    local fallbackIconPath = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_bags.tga"
    local descriptor = {
        id = "bags", key = "bags", name = "DynamicBags", title = "DynamicBags",
        subtitle = "Bags & Alt Vault",
        version = VERSION, order = 70, slash = "/dbag",
        icon = iconPath, fallbackIcon = fallbackIconPath, iconWhite = fallbackIconPath, iconAccent = fallbackIconPath,
        desc = "Zero-lag category bags, companion Bank/Warband/Guild Bank window, alt item vault, auto-repair, auto-sell junk, and fast auto-loot.",
        conflictRegistry = DynamicBags.CONFLICT_REGISTRY,
        RenderEmbedded = function(a1, a2) return U.RenderWorkspace(a1, a2) end,
        BuildEmbeddedPanel = function(a1, a2) return U.RenderWorkspace(a1, a2) end,
        Render = function(a1, a2) return U.RenderWorkspace(a1, a2) end,
        ApplyThemeToUI = function() return DynamicBags:ApplyThemeToUI() end,
        ApplyTheme = function() return DynamicBags:ApplyThemeToUI() end,
        ResetModuleDefaults = function() return DynamicBags:ResetModuleDefaults() end,
        ResetDefaults = function() return DynamicBags:ResetModuleDefaults() end,
        ResetModule = function() return DynamicBags:ResetModuleDefaults() end,
        Reset = function() return DynamicBags:ResetModuleDefaults() end,
        OpenWorkspace = function() return DynamicBags:OpenWorkspace() end,
        Open = function() return DynamicBags:OpenWorkspace() end,
        GetStatusText = function() return DynamicBags:GetStatusText() end,
        OnDisableInSuite = function()
            if U.ClearDecorUseConfirmWindow then U.ClearDecorUseConfirmWindow() end
            S.explicitClosing = (S.explicitClosing or 0) + 1
            if S.window and not (InCombatLockdown and InCombatLockdown()) then S.window:Hide() end
            if S.bankWindow and not (InCombatLockdown and InCombatLockdown()) then S.bankWindow:Hide() end
            S.explicitClosing = math.max(0, (S.explicitClosing or 1) - 1)
            if S.quickOpenBtn and not (InCombatLockdown and InCombatLockdown()) then S.quickOpenBtn:Hide() end
            DynamicBags:UnregisterAllEvents()
        end,
        SelectSubTab = function(a1, a2, a3)
            local idx = (type(a1) == "number") and a1 or a2 or 1
            local expandDrawers = (type(a1) == "number") and a2 or a3
            DB().activeSubTab = idx
            if expandDrawers then
                DB().repairDrawerOpen = true
            end
            if U and U.RefreshWorkspace then
                U.RefreshWorkspace()
            end
            if S and S.workspace and S.workspace.scrollHolder and S.workspace.scrollHolder.ScrollToTop then
                S.workspace.scrollHolder:ScrollToTop()
            end
        end,
    }
    descriptor.SelectTab = descriptor.SelectSubTab
    DynamicBags.SelectSubTab = descriptor.SelectSubTab
    DynamicBags.SelectTab = descriptor.SelectSubTab
    _G.DynamicSuite.modules["bags"] = descriptor
    _G.DynamicSuite.modules["DynamicBags"] = descriptor
    if type(_G.DynamicSuite.RegisterModule) == "function" then
        pcall(_G.DynamicSuite.RegisterModule, _G.DynamicSuite, "bags", descriptor)
    end
end

RegisterWithDynamicSuite()

SLASH_DYNAMICBAGS1 = "/dbag"
SLASH_DYNAMICBAGS2 = "/dbags"
SlashCmdList["DYNAMICBAGS"] = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(.-)%s*$")
    if cmd == "bag" or cmd == "bags" or cmd == "inv" or cmd == "open" then
        U.ToggleWindow()
    elseif cmd == "bank" then
        U.OpenCompanionBank("BANK", nil, true)
    elseif cmd == "warband" or cmd == "wb" then
        U.OpenCompanionBank("WARBAND", nil, true)
    elseif cmd == "guild" or cmd == "gb" then
        U.OpenCompanionBank("GUILD", nil, true)
    elseif cmd == "reset" then
        DynamicBags:ResetModuleDefaults()
    elseif cmd == "restack" or cmd == "merge" then
        U.Restack()
    elseif cmd == "clearnew" or cmd == "clear" then
        U.ClearNew()
    elseif cmd == "vault clear" then
        U.ClearAltCache()
        Print("Alt & Warband cache cleared.")
    elseif cmd:match("^restock") then
        local db = DB()
        db.autoRestockList = db.autoRestockList or {}
        local rest = (msg or ""):match("^%s*[Rr][Ee][Ss][Tt][Oo][Cc][Kk]%s*(.*)$") or ""
        local sub = rest:lower():match("^%s*(.-)%s*$")
        if sub == "" or sub == "list" then
            local items = {}
            for id, qty in pairs(db.autoRestockList) do
                table.insert(items, string.format("#%d -> %d", id, qty))
            end
            if #items == 0 then
                Print("Auto-Restock list is empty. Usage: /dbag restock <itemID or link> <qty>")
            else
                Print("Auto-Restock (" .. (db.autoRestockEnabled and "ON" or "OFF") .. "): " .. table.concat(items, ", "))
            end
        elseif sub == "clear" then
            wipe(db.autoRestockList)
            Print("Cleared Auto-Restock list.")
        else
            local itemID = tonumber(rest:match("item:(%d+)")) or tonumber(rest:match("^(%d+)"))
            local qty = tonumber(rest:match("(%d+)%s*$"))
            if itemID and qty and qty > 0 then
                db.autoRestockList[itemID] = qty
                db.autoRestockEnabled = true
                Print(string.format("Added Item #%d to Auto-Restock (target: %d) and enabled Auto-Restock.", itemID, qty))
            elseif itemID and (qty == 0) then
                db.autoRestockList[itemID] = nil
                Print(string.format("Removed Item #%d from Auto-Restock.", itemID))
            else
                Print("Usage: /dbag restock <itemID or item link> <targetQty>  (use 0 to remove, or 'list' / 'clear')")
            end
        end
    elseif cmd == "help" or cmd == "?" then
        Print("Commands: /dbag (settings), /dbag bag, /dbag bank, /dbag warband, /dbag guild, /dbag merge, /dbag clear, /dbag restock, /dbag vault clear, /dbag reset")
    else
        DynamicBags:OpenWorkspace()
    end
end

local function OnBagIDSet()
    S.bagIDSet = {}
    for _, id in ipairs(S.bagIDs) do S.bagIDSet[id] = true end
end

function _G.DynamicBags_OnAddonCompartmentClick(_, buttonName)
    if buttonName == "RightButton" then
        DynamicBags:OpenWorkspace()
    else
        U.ToggleWindow()
    end
end

function U.TryAutoSelectBankerGossip()
    local db = DB()
    if not db or not db.autoOpen or (db.autoOpen.bank == false and db.autoOpen.guildbank == false) then return false end
    if InCombatLockdown() then return false end
    if IsShiftKeyDown and IsShiftKeyDown() then return false end
    if not C_GossipInfo or type(C_GossipInfo.GetOptions) ~= "function" or type(C_GossipInfo.SelectOption) ~= "function" then
        return false
    end

    if type(C_GossipInfo.GetActiveQuests) == "function" then
        local okA, activeQuests = pcall(C_GossipInfo.GetActiveQuests)
        if okA and type(activeQuests) == "table" and not IsSecret(activeQuests) and #activeQuests > 0 then
            return false
        end
    end
    if type(C_GossipInfo.GetAvailableQuests) == "function" then
        local okAv, availQuests = pcall(C_GossipInfo.GetAvailableQuests)
        if okAv and type(availQuests) == "table" and not IsSecret(availQuests) and #availQuests > 0 then
            return false
        end
    end

    local okO, options = pcall(C_GossipInfo.GetOptions)
    if not okO or type(options) ~= "table" or IsSecret(options) or #options ~= 1 then
        return false
    end

    local opt = options[1]
    if type(opt) ~= "table" or IsSecret(opt) then return false end
    local optID = not IsSecret(opt.gossipOptionID) and opt.gossipOptionID or nil
    if not optID then return false end

    local icon = not IsSecret(opt.icon) and opt.icon or nil
    local overrideIcon = not IsSecret(opt.overrideIconID) and opt.overrideIconID or nil
    local rawName = (type(opt.name) == "string" and not IsSecret(opt.name)) and opt.name:lower() or ""

    local bankKind = nil
    if rawName:find("guild bank", 1, true) or rawName:find("guild vault", 1, true) then
        bankKind = "GUILD"
    elseif rawName:find("warband bank", 1, true) or rawName:find("account bank", 1, true) then
        bankKind = "WARBAND"
    elseif (icon == 132050)
        or (overrideIcon == 132050)
        or (rawName:find("deposit box", 1, true) ~= nil)
        or (rawName:find("personal bank", 1, true) ~= nil)
        or (rawName:find("check my bank", 1, true) ~= nil)
        or (rawName:find("access my bank", 1, true) ~= nil)
        or (rawName:find("bank", 1, true) ~= nil) then
        bankKind = "BANK"
    end

    if bankKind then
        if _G.DynamicPrep and type(_G.DynamicPrep.SuppressDialogueUIForGossipSkip) == "function" then
            pcall(_G.DynamicPrep.SuppressDialogueUIForGossipSkip, _G.DynamicPrep)
        else
            if _G.DUIQuestFrame then
                pcall(function() _G.DUIQuestFrame:SetAlpha(0); _G.DUIQuestFrame:Hide() end)
            end
            if _G.GossipFrame and _G.GossipFrame.Hide then
                pcall(_G.GossipFrame.Hide, _G.GossipFrame)
            end
        end
        pcall(C_GossipInfo.SelectOption, optID)
        U.PreWarmCompanionBank(bankKind)
        return true, optID
    end
    return false
end

function U.OnLogin()
    EnsureDB()
    S.bagIDs = U.GetLiveBagIDs()
    OnBagIDSet()
    S.sessionStartMoney = GetMoney and GetMoney() or 0
    U.BuildTriggerLookup()
    U.InstallBagHooks()
    U.HideBlizzardBags()
    U.InstallTooltipHook()
    U.HookCharacterFrame()
    DynamicBags:SetupDeleteConfirmationHook()
    DynamicBags:SetupDecorNonTradeableConfirmHook()
    wipe(S.bindCache); S.forceFull = true
    pcall(U.ProcessDirtyBags)
    if not InCombatLockdown() then
        U.EnsureBagSpecialFrames()
        pcall(U.EnsureWindow)
        pcall(U.EnsureQuickOpenButton)
        pcall(U.EnsureButtons)
        pcall(U.ApplyLive, true)
    end
    S.loginBaselineDone = true
    U.ScheduleSnapshot()
    U.ScheduleAutoOpenContainers()
end

DynamicBags:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if (arg1 == ADDON_FOLDER or arg1 == "DynamicBags") and not isInitialized then
            isInitialized = true
            EnsureDB()
            RegisterWithDynamicSuite()
            if IsModuleDisabledInSuite("DynamicBags") then
                if _G.DynamicSuite and _G.DynamicSuite.modules then
                    if _G.DynamicSuite.modules["bags"] then _G.DynamicSuite.modules["bags"]._disabledAtStartup = true end
                    if _G.DynamicSuite.modules["DynamicBags"] then _G.DynamicSuite.modules["DynamicBags"]._disabledAtStartup = true end
                end
                self:UnregisterAllEvents()
                return
            end
            S.bagIDs = U.GetLiveBagIDs()
            OnBagIDSet()
            DynamicBags:SetupDeleteConfirmationHook()
            DynamicBags:SetupDecorNonTradeableConfirmHook()
        elseif arg1 == "Blizzard_GuildBankUI" or arg1 == "Blizzard_BankUI" then
            if not IsModuleDisabledInSuite("DynamicBags") then
                U.HideBlizzardBags()
            end
        end
    elseif event == "PLAYER_LOGIN" then
        EnsureDB()
        RegisterWithDynamicSuite()
        if IsModuleDisabledInSuite("DynamicBags") then
            if _G.DynamicSuite and _G.DynamicSuite.modules then
                if _G.DynamicSuite.modules["bags"] then _G.DynamicSuite.modules["bags"]._disabledAtStartup = true end
                if _G.DynamicSuite.modules["DynamicBags"] then _G.DynamicSuite.modules["DynamicBags"]._disabledAtStartup = true end
            end
            self:UnregisterAllEvents()
            return
        end
        U.OnLogin()
    elseif event == "PLAYER_ENTERING_WORLD" then
        U.HookCharacterFrame()
        DynamicBags:SetupDecorNonTradeableConfirmHook()
        if not S.loginBaselineDone then
            S.forceFull = true
            pcall(U.ProcessDirtyBags)
        end
        U.ScheduleAutoOpenContainers()
    elseif event == "BAG_UPDATE" then
        if arg1 and S.bagIDSet and S.bagIDSet[arg1] then
            S.dirtyBags[arg1] = true
        elseif S.atBank then
            U.ScheduleSnapshot()
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        pcall(U.ProcessDirtyBags)
        if S.recheckNew then
            S.recheckNew = false
            pcall(U.RecheckNewItems)
        end
        if S.window and S.window:IsShown() then
            if S.view.char == nil and S.view.mode == "BAGS" then
                U.RenderCurrentView()
            else
                U.UpdateFooter()
                U.UpdateQuickOpenButton()
            end
        elseif S.quickOpenBtn and S.quickOpenBtn:IsShown() then
            U.UpdateQuickOpenButton()
        end
        if S.atBank and S.bankWindow and S.bankWindow:IsShown() then
            pcall(U.SnapshotBank)
            U.RenderCompanionBank()
        end
        if S.pendingBagMerge and U.ContinuePendingBagMerge then
            pcall(U.ContinuePendingBagMerge)
        end
        U.ScheduleSnapshot()
        U.ScheduleAutoOpenContainers()
    elseif event == "BAG_NEW_ITEMS_UPDATED" then
        S.recheckNew = true
    elseif event == "ITEM_LOCK_CHANGED" or event == "ITEM_UNLOCKED" then
        if arg1 and arg2 then
            local bc = S.slotCache[arg1]
            local e = bc and bc[arg2]
            local btn = S.buttons[arg1 .. ":" .. arg2]
            if e or (btn and btn.dbIcon) then
                local info = U.GetSlotInfo(arg1, arg2)
                local isLocked = info and info.isLocked and true or false
                if e then e.locked = isLocked end
                if btn and btn.dbIcon then
                    btn.dbIcon:SetDesaturated(isLocked)
                end
            end
        elseif U.RefreshAllSlotLocks then
            U.RefreshAllSlotLocks()
        end
        if event == "ITEM_UNLOCKED" and not InCombatLockdown() and S.window and S.window:IsShown() then
            U.UpdateQuickOpenButton()
        end
    elseif event == "CVAR_UPDATE" then
        if arg1 == "ActionButtonUseKeyDown" and not InCombatLockdown() then
            U.SyncQuickOpenClickRegistration(S.quickOpenBtn)
        end
    elseif event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" then
        if event == "BAG_UPDATE_COOLDOWN" then
            U.UpdateCooldowns()
        end
        if S.window and S.window:IsShown() then
            U.UpdateQuickOpenButton()
        end
    elseif event == "SKILL_LINES_CHANGED" then
        if S.window and S.window:IsShown() then
            U.UpdateQuickOpenButton()
        end
    elseif event == "EQUIPMENT_SETS_CHANGED" then
        S.forceFull = true
        pcall(U.ProcessDirtyBags)
        if S.window and S.window:IsShown() then U.RenderCurrentView() end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        S.equipGen = S.equipGen + 1
        if not S.equipTimer and C_Timer and C_Timer.NewTimer then
            S.equipTimer = C_Timer.NewTimer(0.25, function()
                S.equipTimer = nil
                S.forceFull = true
                pcall(U.ProcessDirtyBags)
                if S.window and S.window:IsShown() then U.RenderCurrentView() end
            end)
        end
    elseif event == "PLAYER_MONEY" or event == "CURRENCY_DISPLAY_UPDATE" then
        if S.window and S.window:IsShown() then U.UpdateFooter() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if U.ClearDecorUseConfirmWindow then U.ClearDecorUseConfirmWindow() end
        if S.autoOpenTimer then
            if S.autoOpenTimer.Cancel then pcall(S.autoOpenTimer.Cancel, S.autoOpenTimer) end
            S.autoOpenTimer = nil
        end
        if U.CancelAllPendingMerges then U.CancelAllPendingMerges() end
        if U.ClearQuickOpenBindings then U.ClearQuickOpenBindings(S.quickOpenBtn) end
        U.CloseMenu()
    elseif event == "PLAYER_REGEN_ENABLED" then
        U.EnsureBagSpecialFrames()
        if S.pendingCombatVis then
            local targetVis = S.pendingCombatVis
            local hideBank = S.pendingCombatHideBank
            S.pendingCombatVis = nil
            S.pendingCombatHideBank = nil
            if targetVis == "SHOW" then
                U.ShowWindow()
            elseif targetVis == "HIDE" then
                if hideBank and S.bankWindow and S.bankWindow:IsShown() then
                    S.explicitClosing = (S.explicitClosing or 0) + 1
                    S.bankWindow:Hide()
                    S.explicitClosing = math.max(0, (S.explicitClosing or 1) - 1)
                end
                U.HideWindow()
            end
        end
        if S.pendingBuild or S.pendingReflow then
            S.appliedVersion = -1
            if S.window and S.window:IsShown() then U.RenderCurrentView() end
        end
        if S.pendingQuickOpenSync or (S.window and S.window:IsShown()) or (S.quickOpenBtn and S.quickOpenBtn:IsShown()) then
            U.UpdateQuickOpenButton()
        end
        U.HideBlizzardBags()
        U.ScheduleAutoOpenContainers()
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        if not S.itemDataTimer and C_Timer and C_Timer.NewTimer then
            local needsIlvlRefresh = false
            for _, bc in pairs(S.slotCache or {}) do
                for _, e in pairs(bc) do
                    if e and (e.classID == IC.Armor or e.classID == IC.Weapon) and (not e.ilvl or e.ilvl == 0) then
                        needsIlvlRefresh = true
                        break
                    end
                end
                if needsIlvlRefresh then break end
            end
            if needsIlvlRefresh then
                S.itemDataTimer = C_Timer.NewTimer(0.25, function()
                    S.itemDataTimer = nil
                    S.forceFull = true
                    pcall(U.ProcessDirtyBags)
                    if S.window and S.window:IsShown() then
                        U.RenderCurrentView()
                    end
                end)
            end
        end
    elseif event == "PLAYER_BANKSLOTS_CHANGED" or event == "BANK_TAB_SETTINGS_UPDATED" then
        if S.atBank then
            U.ScheduleSnapshot()
            if S.bankWindow and S.bankWindow:IsShown() then
                pcall(U.SnapshotBank)
                U.RenderCompanionBank()
            end
        end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        U.OnInteractionShow(arg1)
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        U.OnInteractionHide(arg1)
        U.ScheduleAutoOpenContainers()
    elseif event == "GOSSIP_SHOW" then
        local selected = U.TryAutoSelectBankerGossip()
        if selected and C_Timer and C_Timer.After then
            C_Timer.After(0.05, function()
                if not S.atBank then
                    U.TryAutoSelectBankerGossip()
                end
            end)
        end
    elseif event == "BANKFRAME_OPENED" then
        S.atBank = true
        S.preWarmingBank = false
        if _G.DUIQuestFrame and _G.DUIQuestFrame.IsShown and _G.DUIQuestFrame:IsShown() then
            pcall(_G.DUIQuestFrame.Hide, _G.DUIQuestFrame)
        end
        if _G.GossipFrame and _G.GossipFrame.IsShown and _G.GossipFrame:IsShown() then
            pcall(_G.GossipFrame.Hide, _G.GossipFrame)
        end
        if S.bankWindow and S.bankWindow:IsShown() then
            U.RenderCompanionBank()
        end
        U.ScheduleSnapshot()
    elseif event == "BANKFRAME_CLOSED" then
        pcall(U.SnapshotBank)
        S.atBank = false
        U.ScheduleAutoOpenContainers()
    elseif event == "GUILDBANKFRAME_OPENED" then
        S.atGuildBank = true
        S.preWarmingBank = false
        if not DB().replaceBlizzardBags then return end
        if _G.DUIQuestFrame and _G.DUIQuestFrame.IsShown and _G.DUIQuestFrame:IsShown() then
            pcall(_G.DUIQuestFrame.Hide, _G.DUIQuestFrame)
        end
        if _G.GossipFrame and _G.GossipFrame.IsShown and _G.GossipFrame:IsShown() then
            pcall(_G.GossipFrame.Hide, _G.GossipFrame)
        end
        U.HideBlizzardBags()
        U.SelectGuildBankTab((GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 1, true)
        if DB().autoOpen and DB().autoOpen.guildbank ~= false and not (S.bankWindow and S.bankWindow:IsShown() and S.bankWindow.mode == "GUILD") then
            U.OpenCompanionBank("GUILD", nil, true)
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                U.HideBlizzardBags()
                if S.atGuildBank then
                    pcall(U.SnapshotGuildBank)
                    if S.bankWindow and S.bankWindow:IsShown() then
                        U.RenderCompanionBank()
                    end
                end
            end)
        end
    elseif event == "GUILDBANKFRAME_CLOSED" then
        if S.atGuildBank then
            pcall(U.SnapshotGuildBank)
            U.ResetGuildBankSessionState()
        end
        U.ScheduleAutoOpenContainers()
    elseif event == "GUILDBANKBAGSLOTS_CHANGED" or event == "GUILDBANK_UPDATE_TABS" or event == "GUILDBANK_UPDATE_WITHDRAWMONEY" then
        if event == "GUILDBANKBAGSLOTS_CHANGED" and S.pendingGuildMergeTab and U.ContinuePendingGuildMerge then
            pcall(U.ContinuePendingGuildMerge)
        end
        if S.atGuildBank and S.bankWindow and S.bankWindow:IsShown() then
            if C_Timer and C_Timer.After then
                if not S._guildBankRefreshPending then
                    S._guildBankRefreshPending = true
                    C_Timer.After(0.08, function()
                        S._guildBankRefreshPending = false
                        if S.atGuildBank and S.bankWindow and S.bankWindow:IsShown() then
                            pcall(U.SnapshotGuildBank)
                            U.RenderCompanionBank()
                        end
                    end)
                end
            else
                pcall(U.SnapshotGuildBank)
                U.RenderCompanionBank()
            end
        end
    elseif event == "AUCTION_HOUSE_SHOW" then
        U.TriggerAutoOpenKey("auction")
    elseif event == "AUCTION_HOUSE_CLOSED" then
        U.TriggerAutoCloseKey("auction")
        U.ScheduleAutoOpenContainers()
    elseif event == "MAIL_SHOW" then
        U.TriggerAutoOpenKey("mail")
    elseif event == "MAIL_CLOSED" then
        U.TriggerAutoCloseKey("mail")
        U.ScheduleAutoOpenContainers()
        if U.RefreshAllSlotLocks then
            U.RefreshAllSlotLocks()
            if C_Timer and C_Timer.After then
                C_Timer.After(0.05, U.RefreshAllSlotLocks)
                C_Timer.After(0.25, U.RefreshAllSlotLocks)
            end
        end
    elseif event == "TRADE_SHOW" then
        U.TriggerAutoOpenKey("trade")
    elseif event == "TRADE_CLOSED" then
        U.TriggerAutoCloseKey("trade")
        U.ScheduleAutoOpenContainers()
    elseif event == "MERCHANT_SHOW" then
        U.EnsureMerchantBulkBuyHook()
        U.TriggerAutoOpenKey("vendor")
        DynamicBags:HandleMerchantShow()
    elseif event == "MERCHANT_CLOSED" then
        U.TriggerAutoCloseKey("vendor")
        U.ScheduleAutoOpenContainers()
    elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
        DynamicBags:HandleFastAutoLoot()
    elseif event == "LOOT_CLOSED" then
        DynamicBags._lastFastLootAt = 0
        if not InCombatLockdown() and S.window and S.window:IsShown() then
            U.UpdateQuickOpenButton()
        end
        U.ScheduleAutoOpenContainers()
    elseif event == "END_BOUND_TRADEABLE" or event == "USE_NO_REFUND_CONFIRM" then
        if U.IsDecorUseConfirmActive() and not InCombatLockdown() then
            local confirmed = false
            if event == "END_BOUND_TRADEABLE" and type(_G.EndBoundTradeable) == "function" and arg1 ~= nil and not IsSecret(arg1) then
                S.decorUseConfirmCount = max(0, (S.decorUseConfirmCount or 1) - 1)
                if S.decorUseConfirmCount <= 0 then
                    U.ClearDecorUseConfirmWindow()
                end
                local okE = pcall(_G.EndBoundTradeable, arg1)
                if okE then
                    confirmed = true
                    if type(_G.StaticPopup_Hide) == "function" then
                        pcall(_G.StaticPopup_Hide, "NON_TRADEABLE_ITEM")
                        pcall(_G.StaticPopup_Hide, "END_BOUND_TRADEABLE")
                    end
                end
            elseif event == "USE_NO_REFUND_CONFIRM" and type(_G.ConfirmNoRefundOnUse) == "function" then
                S.decorUseConfirmCount = max(0, (S.decorUseConfirmCount or 1) - 1)
                if S.decorUseConfirmCount <= 0 then
                    U.ClearDecorUseConfirmWindow()
                end
                local okC = pcall(_G.ConfirmNoRefundOnUse)
                if okC then
                    confirmed = true
                    if type(_G.StaticPopup_Hide) == "function" then
                        pcall(_G.StaticPopup_Hide, "USE_NO_REFUND_CONFIRM")
                        pcall(_G.StaticPopup_Hide, "CONFIRM_USE_NO_REFUND")
                    end
                end
            end
            if not confirmed then
                if not U.ScanAndConfirmDecorPopup() and C_Timer and C_Timer.After then
                    C_Timer.After(0, function()
                        if U.IsDecorUseConfirmActive() then
                            U.ScanAndConfirmDecorPopup()
                        end
                    end)
                end
            end
        end
    elseif event == "ADDON_ACTION_BLOCKED" then
        S.decorActionBlocked = true
        if S.autoOpenActiveItemID then
            S.autoOpenBlacklist[S.autoOpenActiveItemID] = true
            S.autoOpenActiveItemID = nil
        end
    end
end)

for _, ev in ipairs({
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "BAG_UPDATE", "BAG_UPDATE_DELAYED",
    "BAG_NEW_ITEMS_UPDATED", "ITEM_LOCK_CHANGED", "ITEM_UNLOCKED", "CVAR_UPDATE",
    "BAG_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN",
    "SKILL_LINES_CHANGED", "EQUIPMENT_SETS_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_MONEY",
    "CURRENCY_DISPLAY_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
    "GOSSIP_SHOW", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYER_BANKSLOTS_CHANGED", "BANK_TAB_SETTINGS_UPDATED",
    "ITEM_DATA_LOAD_RESULT", "GUILDBANKBAGSLOTS_CHANGED", "GUILDBANK_UPDATE_TABS", "GUILDBANK_UPDATE_WITHDRAWMONEY", "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED", "MERCHANT_SHOW",
    "MERCHANT_CLOSED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "MAIL_SHOW", "MAIL_CLOSED",
    "TRADE_SHOW", "TRADE_CLOSED", "LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED",
    "END_BOUND_TRADEABLE", "USE_NO_REFUND_CONFIRM", "ADDON_ACTION_BLOCKED",
}) do
    SafeRegister(DynamicBags, ev)
end


DynamicBags.CHANGELOG = {
    version = VERSION,
    date = "21/11/2026",
    entries = {
        { type = "UI",      text = "Release v2.7.0 - 156x26px Binary Switch Alignment & Live Accent Tooltips (21/11/2026): Standardised binary Off/Enabled option switches across all tabs to 68px Off + 84px Enabled (156x26px total) and updated Alt + Left-Click category tooltips to track the live Suite Accent colour." },
        { type = "FIX",     text = "v2.4.0 DynamicMail Alt+Left-Click Attach & Stuck Lock Release on Mail Close (18/11/2026): Removed the ActionButtonUseKeyDown edge filter blocking Alt + Left-Click mail attachments on ContainerFrameItemButton slot buttons, and updated ITEM_LOCK_CHANGED / ITEM_UNLOCKED plus MAIL_CLOSED and U.ShowWindow() lock refreshes so bag icons never stay desaturated after closing Mailbox with attached or dragged items." },
        { type = "FIX",     text = "Release v2.3.2 - 1-Click Housing Decor Non-Tradeable Confirmation & Smooth Mousewheel Scrolling (18/11/2026): Clicking Open (N) or scrolling Alt+MouseWheel now uses and confirms refundable/trade-timer Housing Decor items in one click out of combat (supporting Retail 12.1.5 pooled StaticPopup dialogs, END_BOUND_TRADEABLE, and USE_NO_REFUND_CONFIRM while keeping Open (N) ready whenever a background auto-open requires a hardware click and strictly ignoring manual bag clicks, dungeon/raid loot rolls, and non-Decor items); and restored smooth mousewheel scrolling across DynamicBags, DynamicBank (Personal, Warband, and Guild Bank), and settings scroll areas whenever Ctrl+Shift is not held." },
        { type = "FIX",     text = "ESC / B Keybind Closure, Top-Most Window Escape Priority & GameMenu Failsafe Guard (18/11/2026): Removed the conflicting GameMenuFrame OnShow hide hack from U.EnsureWindow() and added nil-hole/duplicate compaction plus single top-most Escape ordering to UISpecialFrames (DynamicBagsBankFrame -> DynamicBagsFrame -> DynamicBagsStandaloneFrame -> DynamicSuite DesktopWindows); guarded CloseAllBags against ESC calls and added a CloseSpecialWindows + ToggleGameMenu failsafe so even if DynamicBagsFrame or DynamicBagsBankFrame is protected by slot children or skipped by CloseSpecialWindows, pressing ESC reliably clears active search or closes the top-most window one at a time without opening the Options / Game Menu while preserving clean two-way B toggling before and after ESC." },
        { type = "FIX",     text = "ESC & B Keybind Window Closing, CloseAllBags & Unfocused Escape-First Search Clear (18/11/2026): Removed raw EnableKeyboard(true) and OnKeyDown capture from DynamicBagsFrame and DynamicBagsBankFrame so pressing B or ESC always reaches Blizzard's keybind and UISpecialFrames handlers without swallowing input; preserved Escape-first search clearing via OnEscapePressed when the search box is focused and a combat-guarded CloseSpecialWindows post-hook when search text is active while unfocused (restoring the open window once, clearing both search boxes, and letting the second ESC close cleanly); and updated ToggleWindow() and hooked CloseAllBags() so pressing B or CloseAllBags toggles DynamicBagsFrame (alongside DynamicBagsBankFrame when open) reliably out of combat." },
        { type = "FEATURE", text = "Shift+Click Collapse/Expand All Categories & Footer Bag Space / Junk Breakdown Tooltip (16/11/2026): Shift + Left-Click on any category header collapses all expanded categories or expands all categories at once out of combat (replacing the old single-step shift reorder action while keeping Alt + Left-Click for the reorder menu); made the bottom-left footer slot readout interactive with a hover tooltip showing per-bag free/total slots (Backpack, Bag 1-4, Reagent Bag) plus the total vendor sell value of grey/poor-quality items currently in your bags." },
        { type = "FEATURE", text = "Search Clear Button, Escape-First Clearing & Collapsible Category Headers (16/11/2026): added an inline 'x' clear button to both the DynamicBags and Unified DynamicBank search boxes, Escape-first clearing when search text is active (pressing Escape a second time closes the window cleanly), and Left-Click collapsing on virtual category headers with chevron indicators and collapsed item-count summaries saved in DynamicBagsDB (Alt+Left-Click opens the category reorder menu)." },
        { type = "FEATURE", text = "Dual-Mode Ctrl+Scroll Window Scaling, Header Controls Tooltip & Scale-Aware Docked Bank Alignment (15/11/2026): added 70%-140% (5% steps, out of combat) scaling across DynamicBagsFrame and DynamicBagsBankFrame (Personal Bank, Warband Bank, and Guild Bank). Ctrl + Scroll across the full header scales temporarily for the open session (resetting on hide); Ctrl + Shift + Scroll anywhere on the window (header, item grid ScrollFrame, or footer) saves bagScale / bankScale permanently without affecting normal wheel scrolling or Ctrl+Click item previews; Right-Click anywhere on the empty header (or Reset DynamicBags) resets scale to 100%; added DynamicBags / DynamicBank Window Controls header tooltips (auto-hiding on OnLeave/OnDragStart) and an auto-fading Dark-Obsidian (#0B0D12) / Blaze-Orange (#F97316) readout toast; and keeps docked DynamicBank flush beside DynamicBags at any scale." },
        { type = "FEATURE", text = "Unified Auto-Open for Gold Pouches, Housing Decor & Profession Knowledge (15/11/2026): expanded the automatic container opener to use/open Soulbound and Warband-bound gold pouches, coin/loot satchels, Housing Decor, and Profession Knowledge items (Treatises, Shards, Notes, Curios matching your character's known professions) out of combat when bank, vendor, mail, trade, guild bank, and auction house windows are closed. Added default-enabled 'Auto-Open Soulbound Housing Decor' and 'Auto-Open Soulbound Profession Knowledge' toggles in Tab 3, while keeping protected-spell items (via C_Item.GetItemSpell or ADDON_ACTION_BLOCKED) safely queued in the 1-click Open (N) header button with a per-item retry cooldown and session blacklist." },
        { type = "FIX",     text = "Hardened zero-flash Bank/Guild Bank opening after /reload (14/11/2026): added Scale+Alpha suppression and GUILDBANKFRAME_OPENED handling, preserved unqueried Guild Bank tab snapshots across sessions while reflecting live withdrawals down to 0 items, enforced strict weak ordering in Sort: A-Z when uncached items appear, verified compatible slot placement in Drop-Anywhere Split-Stack Placement, fixed Guild Bank T1-Tn badge overlap and view-only slot dimming, synchronised Tab 3 Auto-Repair/Auto-Sell keys, guarded fast auto-loot bursts, and expanded /dbag slash subcommands." },
        { type = "FEATURE", text = "Guild Bank Daily Withdrawal Counter (13/11/2026): each Guild Bank tab button (T1, T2...) now shows a small counter of how many item withdrawals you have left today - white when plenty remain, amber at 1-2, red at 0, and a red x for tabs you cannot view. Unlimited tabs show no counter. Counters only appear while you are at the Guild Bank." },
        { type = "FIX",     text = "Guild Bank footer and tooltip separators now use plain characters so they display correctly with every DynamicSuite font (13/11/2026)." },
        { type = "FEATURE", text = "External Addon Conflict Detector & Smart Sub-Module Inspection (12/11/2026): Curated HARD conflict detection for Baganator, BetterBags, AdiBags, ArkInventory, Bagnon, Sorted, and LiteBag, plus pcall-guarded ElvUI[1].private.bags.enable and Leatrix_Plus sub-module checks." },
        { type = "FIX",     text = "Eliminated Row 1 header button overlap ('View: Bags' vs 'Clear') across all column and icon-size slider settings: trimmed redundant 'Char: ' and 'View: ' button prefixes, added auto-fitting dropdown widths with mouseover tooltips ('Character & Alt Vault' and 'Active Inventory View'), enforced dynamic minimum header width floors on DynamicBagsFrame and DynamicBagsBankFrame (640px), centred narrow item grids cleanly inside the scroll area, pre-warmed DynamicBank at 0.00s on Banker gossip selection, and deferred full bank tooltip snapshots off the open frame for zero-stutter bank opening." },
        { type = "FIX",     text = "Switched DynamicBagsQuickOpenBtn from type='item' (which triggers Blizzard's C_Item.IsEquippableItem crash on non-equippable pouches and double-fires on Down+Up clicks) to single-edge clicks with a multi-line /use <bag> <slot> batch macro (macrotext1 up to 255 chars, opening ~22-25 instant Use: gold pouches/caches in a single click or Alt+MouseWheel scroll), disabled the blocked timer-based C_Container.UseContainerItem loop, auto-selected single Banker gossip options (e.g. Ceera in Silvermoon with DialogueUI installed) on GOSSIP_SHOW, restored missing icon_grid.tga (Merge) and icon_spark.tga (Clear) textures with crisp white selected icon tinting, and formatted all Gold footers and tooltips with Gold, Silver, and Copper coin icons and comma separators." },
        { type = "FEATURE", text = "Persisted and restored the last opened Bank Mode (Personal Bank vs Warband Bank) and per-mode Sub-Tab (All vs T1..TN across Personal, Warband, and Guild Bank) in DynamicBagsDB, with a 'Remember Last Opened Bank & Sub-Tab (Personal / Warband)' toggle in Tab 3, alt tab-count safety clamping, and untainted right-click/batch deposit routing to Enum.BankType.Account and the active sub-tab." },
        { type = "FEATURE", text = "Added Soulbound Auto-Open for <Right Click to Open> loot/gold pouches (paced at 0.35s when out of combat with all interaction frames closed) and a 1-Spot Open (N) Secure Queue Button (DynamicBagsQuickOpenBtn, parented to UIParent for 0.00% DynamicBagsFrame combat protection taint) for Housing Decor, Profession Knowledge Points (verified against known character professions), and Use: caches." },
        { type = "FIX",     text = "Enabled combat-safe bag toggling (B / ToggleAllBags) whenever DynamicBagsFrame is already initialised and unprotected, while deferring protected slot-button grid reflows and pre-registering UISpecialFrames at login for 0.00% CloseSpecialWindows taint." },
        { type = "FIX",     text = "Fixed 'Merge' failing to combine split stacks across DynamicBags and DynamicBank: added U.GetMergeStackKey (normalising stack keys strictly by itemID, crafting/reagent quality tier via U.DetectCraftQuality, and bound state while ignoring hyperlink linkLevel, specializationID, and modifier suffixes), removed C_Container.SortBags / SortBankBags / SortAccountBankBags slot-lock collisions from U.Restack and U.RestackBank, and replaced the blind 0.12s timer with an event-driven multi-pass stack merger (BAG_UPDATE_DELAYED / GUILDBANKBAGSLOTS_CHANGED) that pairs disjoint slots and automatically merges overflow remainders." },
        { type = "FEATURE", text = "Added [Sort: Quality v] and [Merge] header controls to DynamicBank (Character Bank, Warband Bank, and Guild Bank) with U.RestackBank(mode), U.MergePartialStacksAcrossBags, U.MergeGuildBankTabStacks, Shift+Left-Click stack splitting, and Drop-Anywhere Split-Stack Placement (U.PlaceCursorItemInFreeBankSlot)." },
        { type = "FIX",     text = "Eliminated the 100ms Blizzard GuildBankFrame flash on the first Guild Bank interaction after /reload by hooking Blizzard_GuildBankUI and Blizzard_BankUI on ADDON_LOADED/OnShow and opening DynamicBank synchronously (0.00s) before the 0.10s tab snapshot refresh." },
        { type = "FEATURE", text = "Added Drop-Anywhere Split-Stack Placement (U.PlaceCursorItemInFreeSlot): clicking or dropping a split stack anywhere on empty bag canvas or category headers automatically places it into the first free slot (preferring Reagent Bag for crafting reagents) without auto-merging." },
        { type = "UI",      text = "Separated Visual Category Sort Order (Sort: Quality / Sort: A-Z / Sort: Manual dropdown & right-click cycle) from Server-Side Stack Merging (Merge button with Left-Click Merge Now and Right-Click Auto-Merge on Bag Close) in the DynamicBagsFrame top-right header." },
        { type = "UI",      text = "Polished all 3 configuration tabs with plain-English titles, zero-truncation status header, standardized [ Off | Enabled ] binary toggles, smart Disable All / Enable All category toggle, and 104px preset pills." },
        { type = "UI",      text = "Converted all 5 numeric range controls (Bag Columns, Bank Columns, Slot Icon Size, Category Spacing, and Icon Font Size) to the unified Sleek Precision Track Slider with smooth drag and mousewheel support." },
        { type = "UI",      text = "Replaced literal ' v' dropdown text and '^' item upgrade text with crisp vector chevron textures (icon_chevron_down.tga and icon_chevron_up.tga) and added an Inline Conflict Resolution Banner to the workspace." },
        { type = "FEATURE", text = "Migrated Merchant, Loot & Inventory Automation (Auto-Repair Equipment with Guild/Personal Funding Priority drawer, Auto-Sell Grey Junk, Faster Auto-Loot, and Auto-Fill DELETE Confirmation) from DynamicPrep into DynamicBags Tab 3 with automatic SavedVariables migration." },
        { type = "UI",      text = "Standardized all item pinning, category header, bank transfer, currency tracker, category priority chip, and preset button tooltips to use Command-Prefix-Only Highlighting (colored command prefix + Silver-White action description)." },
        { type = "UI",      text = "Upgraded all 7 section headers across Tabs 1-3 to 36px 2-Line Tall L-Brackets with enclosed Slate-Silver subtitles (DESIGN_SYSTEM.md Section 2.4)." },
        { type = "UI",      text = "Grouped all settings across all 3 configuration tabs into bordered section containers with connected L-bracket section headers (DESIGN_SYSTEM.md Section 2.4)." },
        { type = "FEATURE", text = "Updated consumable crafting quality badges for Midnight's 2-tier system (Gold Tier 2 & Silver Tier 1 pips) alongside gear ilvl badges." },
        { type = "UI",      text = "Added a Settings Cog button to the DynamicBank header toolbar next to the Pin and Close buttons for direct access to bag and bank settings." },
        { type = "FIX",     text = "Fixed WUE & BoE corner badge detection and persistence across live bags, Character Bank, and Warband Bank snapshots." },
        { type = "FIX",     text = "Fixed duplicate itemID Equipment Set false-positives by enforcing strict bag:slot matching for live bags and excluding currently worn gear." },
        { type = "FEATURE", text = "Added 12 reorderable categories, interactive < / > & 2-click category swapping, and custom obsidian slot borders." },
    },
}
_G.DynamicSuite = _G.DynamicSuite or {}
_G.DynamicSuite.Changelogs = _G.DynamicSuite.Changelogs or {}
_G.DynamicSuite.Changelogs["DynamicBags"] = DynamicBags.CHANGELOG
_G.DynamicSuite.Changelogs["bags"] = DynamicBags.CHANGELOG
