-- ============================================================================
-- DynamicMail - Smart Inbox Collection, Alt Vault Picker & Express Attach
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

local VERSION = ResolveAddonVersion(ADDON_FOLDER, "2.11.2")
if ShouldYieldToOtherInstall(ADDON_FOLDER, "DynamicMail", VERSION, _G.DynamicMail) then
    return
end

local DM_NS = {}
local isInitialized = false

local function IsModuleDisabledInSuite(modName)
    local key = modName or "DynamicMail"
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

local ADDON_NAME = "DynamicMail"
local DynamicMail = _G.DynamicMail or CreateFrame("Frame", "DynamicMailCoreFrame", UIParent)
_G.DynamicMail = DynamicMail
DM_NS.DynamicMail = DynamicMail
DynamicMail._loadedBySuite = (ADDON_FOLDER == "DynamicSuite")
DynamicMail._loadedVersion = VERSION
DynamicMail.VERSION = VERSION
DynamicMail.version = VERSION

local ICON_COLOR        = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_mail.tga"
local ICON_WHITE        = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_white.tga"
local ICON_ACCENT       = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_accent.tga"
local ICON_CHEVRON_DOWN = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga"
local ICON_CHEVRON_UP   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga"
local ICON_COG          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_cog.tga"
local ICON_SPARK        = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_spark.tga"

-- ============================================================================
-- 1. SAFE RUNTIME HELPERS (MIDNIGHT 12.1.5 SECRET & COMBAT GUARDS)
-- ============================================================================
local function SafeIsSecret(val)
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

local function SafeStr(val, fallback)
    if val == nil or SafeIsSecret(val) then return fallback or "" end
    local ok, str = pcall(tostring, val)
    if not ok or SafeIsSecret(str) then return fallback or "" end
    return str
end

local function SafeNum(val, fallback)
    if val == nil or SafeIsSecret(val) then return fallback or 0 end
    local n = tonumber(val)
    if n == nil or SafeIsSecret(n) then return fallback or 0 end
    return n
end

local function Print(msg)
    local hex = "38BDF8"
    if _G.DynamicSuite and type(_G.DynamicSuite.GetActiveAccentHex) == "function" then
        local ok, h = pcall(_G.DynamicSuite.GetActiveAccentHex)
        if ok and type(h) == "string" and #h == 6 then hex = h end
    end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF%sDynamicMail:|r |cFFE2E8F0%s|r", hex, tostring(msg or "")))
    end
end

local function FormatCopper(copper)
    local c = math.max(0, math.floor(SafeNum(copper, 0)))
    local gold = math.floor(c / 10000)
    local silver = math.floor((c % 10000) / 100)
    local cop = c % 100
    local gTex = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t"
    local sTex = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t"
    local cTex = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t"
    local function commaInt(n)
        local s = tostring(n)
        local rev = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return rev
    end
    if gold > 0 then
        return string.format("|cFFFFD700%s|r%s |cFFC0C0C0%02d|r%s", commaInt(gold), gTex, silver, sTex)
    elseif silver > 0 then
        return string.format("|cFFC0C0C0%d|r%s |cFFEDA55F%02d|r%s", silver, sTex, cop, cTex)
    else
        return string.format("|cFFEDA55F%d|r%s", cop, cTex)
    end
end

local function NormalizeRealmNoSpace(realm)
    local r = SafeStr(realm, "")
    return r:gsub("[%s%-']", "")
end

local function GetPlayerKeyAndParts()
    local name = (type(UnitName) == "function") and SafeStr(UnitName("player"), "") or ""
    if name == "" or name == "Unknown" or name == _G.UNKNOWNOBJECT then
        name = "Player"
    end
    local realm = (type(GetRealmName) == "function") and SafeStr(GetRealmName(), "") or ""
    if realm == "" then realm = "Realm" end
    local full = name .. "-" .. realm
    return full, name, realm
end

local function FormatRecipientForMail(name, realm)
    local n = SafeStr(name, "")
    local r = SafeStr(realm, "")
    if n == "" then return "" end
    local _, _, myRealm = GetPlayerKeyAndParts()
    if r == "" or NormalizeRealmNoSpace(r):lower() == NormalizeRealmNoSpace(myRealm):lower() then
        return n
    end
    return n .. "-" .. r:gsub("%s+", "")
end

-- ============================================================================
-- 2. DATABASE DEFAULTS & CROSS-CHARACTER SNAPSHOT
-- ============================================================================
local DEFAULTS = {
    enabled                 = true,
    mailboxBarEnabled       = true,
    recipientPanelEnabled   = true,
    syncDynamicBagsVault    = true,
    showAltGold             = true,
    sortFavouritesFirst     = true,
    rememberRecent          = true,
    recentLimit             = 25,
    historyLimit            = 30,

    openInterval            = 0.14,
    keepFreeBagSlots        = 1,
    protectUnreadText       = true,
    collectGoldWhenBagsFull = true,
    ahIncludeAllNonCodGold  = false,
    deleteEmptyLetters      = true,
    deleteEmptySystemMail   = false,
    printBatchSummary       = true,
    playFinishSound         = true,

    altClickAttach          = true,
    autoFillSubject         = true,
    clearAfterSend          = true,
    autoOpenBagsAtMail      = false,
    showQuickAttachBar      = true,
    showQuickGoldBar        = true,
    showPendingAltBadge     = true,
    restoreLastRecipient    = false,
    shiftClickInboxLoot     = true,
    warnExpiringMail        = true,
    mailSkinMode            = "OBSIDIAN", -- "OBSIDIAN" (Suite Obsidian & Accent, default) or "AUTO" (match EllesmereUI/ElvUI)

    activeSubTab            = 1,
    activePickerTab         = "ALTS", -- "ALTS", "RECENT", "GUILD", "FRIENDS"
    safetyDrawerOpen        = true,
    altDrawerOpen           = true,

    lastRecipient           = "",
    favourites              = {},
    recentRecipients        = {},
    knownChars              = {},
    sentWatch               = {},
    historyLog              = {},
    stats = {
        totalCopperLooted   = 0,
        totalItemsLooted    = 0,
        totalMailsLooted    = 0,
        totalMailsSent      = 0,
    },
}

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = {}
            end
            CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function EnsureDB()
    if type(_G.DynamicMailDB) ~= "table" then
        _G.DynamicMailDB = {}
    end
    CopyDefaults(_G.DynamicMailDB, DEFAULTS)
    if not _G.DynamicMailDB.skinDefaultMigrated267 then
        if _G.DynamicMailDB.mailSkinMode == "AUTO" then
            _G.DynamicMailDB.mailSkinMode = "OBSIDIAN"
        end
        _G.DynamicMailDB.skinDefaultMigrated267 = true
    end
    return _G.DynamicMailDB
end

local function RecordCurrentCharacterSnapshot()
    local db = EnsureDB()
    local fullKey, name, realm = GetPlayerKeyAndParts()
    if name == "Player" then return end
    local _, classFile = UnitClass("player")
    local faction = UnitFactionGroup("player") or "Neutral"
    local level = (type(UnitLevel) == "function") and SafeNum(UnitLevel("player"), 80) or 80
    local money = (type(GetMoney) == "function") and SafeNum(GetMoney(), 0) or 0
    db.knownChars[fullKey] = {
        key       = fullKey,
        name      = name,
        realm     = realm,
        fullName  = fullKey,
        classFile = SafeStr(classFile, "PRIEST"),
        faction   = SafeStr(faction, "Neutral"),
        level     = level,
        money     = money,
        lastSeen  = time and time() or 0,
    }
end

local function AppendHistoryLog(entryType, summary, copperDelta)
    local db = EnsureDB()
    local limit = math.max(10, math.min(50, SafeNum(db.historyLimit, 30)))
    local stamp = date and date("%H:%M") or "--:--"
    local entry = {
        timeStr = stamp,
        dayStr  = date and date("%d/%m") or "",
        kind    = entryType or "MAIL",
        summary = SafeStr(summary, ""),
        copper  = SafeNum(copperDelta, 0),
    }
    table.insert(db.historyLog, 1, entry)
    while #db.historyLog > limit do
        table.remove(db.historyLog)
    end
end

-- ============================================================================
-- 3. THEME INTEGRATION (DYNAMICSUITE / STANDALONE OBSIDIAN PALETTE)
-- ============================================================================
local DEFAULT_SURFACE = {
    bg     = { 0.024, 0.027, 0.035, 0.98 },
    header = { 0.039, 0.043, 0.055, 0.98 },
    card   = { 0.043, 0.051, 0.071, 0.96 },
    panel  = { 0.035, 0.039, 0.051, 0.98 },
    border = { 0.145, 0.165, 0.212, 0.95 },
}

local function GetTheme()
    local surf = {
        bg     = DEFAULT_SURFACE.bg,
        header = DEFAULT_SURFACE.header,
        card   = DEFAULT_SURFACE.card,
        panel  = DEFAULT_SURFACE.panel,
        border = DEFAULT_SURFACE.border,
    }
    local acc = { r = 0.220, g = 0.741, b = 0.973, hex = "38BDF8" }

    if _G.DynamicSuite and type(_G.DynamicSuite.GetSuiteAccent) == "function" then
        local okA, r, g, b, hex = pcall(_G.DynamicSuite.GetSuiteAccent, _G.DynamicSuite)
        if okA and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            acc.r, acc.g, acc.b = r, g, b
            if type(hex) == "string" and #hex == 6 then
                acc.hex = hex
            else
                acc.hex = string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
            end
        end
    elseif _G.DynamicSuite and _G.DynamicSuite.UI then
        local ui = _G.DynamicSuite.UI
        if type(ui.GetActiveAccentColor) == "function" then
            local okA, r, g, b, hex = pcall(ui.GetActiveAccentColor)
            if okA and type(r) == "number" and type(g) == "number" and type(b) == "number" then
                acc.r, acc.g, acc.b = r, g, b
                if type(hex) == "string" and #hex == 6 then
                    acc.hex = hex
                else
                    acc.hex = string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
                end
            end
        end
    end
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.GetActiveSurfaceColors) == "function" then
        local okS, s = pcall(_G.DynamicSuite.UI.GetActiveSurfaceColors)
        if okS and type(s) == "table" then
            surf.bg     = s.bg or s.frameBg or surf.bg
            surf.header = s.header or s.topBar or surf.header
            surf.card   = s.card or s.cardBg or surf.card
            surf.panel  = s.panel or s.bg or surf.panel
            surf.border = s.border or surf.border
        end
    elseif _G.DynamicSuite and type(_G.DynamicSuite.GetActiveAccentHex) == "function" and acc.hex == "38BDF8" then
        local okH, hex = pcall(_G.DynamicSuite.GetActiveAccentHex)
        if okH and type(hex) == "string" and #hex == 6 then
            acc.hex = hex
            acc.r = (tonumber(hex:sub(1, 2), 16) or 56) / 255
            acc.g = (tonumber(hex:sub(3, 4), 16) or 189) / 255
            acc.b = (tonumber(hex:sub(5, 6), 16) or 248) / 255
        end
    end

    if _G.DynamicSuite and type(_G.DynamicSuite.GetActiveAccentColor) == "function" and not (_G.DynamicSuite.UI and _G.DynamicSuite.UI.GetActiveAccentColor) then
        local okC, r, g, b = pcall(_G.DynamicSuite.GetActiveAccentColor)
        if okC and type(r) == "number" then
            acc.r, acc.g, acc.b = r, g, b
            acc.hex = string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
        end
    end

    return surf, acc
end

local RefreshInboxToolbarUI -- forward decl
local RefreshSendPickerUI   -- forward decl
local ellesmereFacade = nil
local ellesmereHooked = false

local function EnsureEllesmereSkinRegistered()
    if ellesmereHooked then return end
    if type(_G.EllesmereUI) == "table" and type(_G.EllesmereUI.RegisterSkin) == "function" then
        ellesmereHooked = true
        pcall(_G.EllesmereUI.RegisterSkin, "DynamicMail", function(S)
            ellesmereFacade = S
            if type(S) == "table" and type(S.OnLooksChanged) == "function" then
                S.OnLooksChanged(function()
                    if _G.DynamicSuite and _G.DynamicSuite._isHubLoaded then
                        local syncExt = _G.DynamicSuiteDB and _G.DynamicSuiteDB.global and (_G.DynamicSuiteDB.global.syncExternalUI == true)
                        if not syncExt then return end
                    end
                    if RefreshInboxToolbarUI then RefreshInboxToolbarUI() end
                    if RefreshSendPickerUI then RefreshSendPickerUI() end
                end)
            end
            if RefreshInboxToolbarUI then RefreshInboxToolbarUI() end
            if RefreshSendPickerUI then RefreshSendPickerUI() end
        end)
    end
end

local function GetOverlayTheme()
    local surf, acc = GetTheme()
    return surf, acc
end

local function SetFontSafe(fs, size, flags)
    if not fs then return end
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.SetFont) == "function" then
        pcall(_G.DynamicSuite.UI.SetFont, fs, size or 11, flags or "", 0.96, 0.97, 0.99, 1.0)
        return
    end
    local fontPath = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.ttf"
    if not fs:SetFont(fontPath, size or 11, flags or "") then
        fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 11, flags or "")
    end
end

local function ApplyBackdrop(frame, bgCol, borderCol, edgeSize)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile     = false, tileSize = 0, edgeSize = edgeSize or 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    if bgCol then
        frame:SetBackdropColor(bgCol[1] or 0.04, bgCol[2] or 0.05, bgCol[3] or 0.07, bgCol[4] or 0.96)
    end
    if borderCol then
        frame:SetBackdropBorderColor(borderCol[1] or 0.145, borderCol[2] or 0.165, borderCol[3] or 0.212, borderCol[4] or 0.95)
    end
end

local function CreateSolidTex(parent, layer, subLayer, r, g, b, a)
    local tex = parent:CreateTexture(nil, layer or "ARTWORK", nil, subLayer or 0)
    tex:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
    if tex.SetSnapToPixelGrid then
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
    end
    return tex
end

-- ============================================================================
-- 4. RECIPIENT DIRECTORY ENGINE (ALTS / RECENT / GUILD / FRIENDS)
-- ============================================================================
local function GetClassColorHex(classFile)
    local cf = SafeStr(classFile, "PRIEST"):upper()
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[cf] and RAID_CLASS_COLORS[cf].colorStr then
        return RAID_CLASS_COLORS[cf].colorStr:sub(3, 8)
    end
    if C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
        local ok, col = pcall(C_ClassColor.GetClassColor, cf)
        if ok and col and col.GenerateHexColor then
            local h = col:GenerateHexColor()
            if type(h) == "string" and #h >= 8 then
                return h:sub(3, 8)
            end
        end
    end
    return "CBD5E1"
end

local function BuildRecipientList(category, filterText)
    local db = EnsureDB()
    local cat = tostring(category or "ALTS"):upper()
    local q = tostring(filterText or ""):lower():match("^%s*(.-)%s*$") or ""
    local _, myName, myRealm = GetPlayerKeyAndParts()
    local myFullLower = (myName .. "-" .. NormalizeRealmNoSpace(myRealm)):lower()
    local favs = type(db.favourites) == "table" and db.favourites or {}
    local rows = {}
    local seen = {}

    local function MatchesFilter(display, sendTarget, realm)
        if q == "" then return true end
        local hay = (SafeStr(display, "") .. " " .. SafeStr(sendTarget, "") .. " " .. SafeStr(realm, "")):lower()
        return hay:find(q, 1, true) ~= nil
    end

    if cat == "ALTS" then
        local pooled = {}
        -- 1. Live DynamicBags Vault characters (shared account-wide snapshot)
        if db.syncDynamicBagsVault and type(_G.DynamicBagsDB) == "table"
            and type(_G.DynamicBagsDB.vault) == "table"
            and type(_G.DynamicBagsDB.vault.characters) == "table" then
            for ck, rec in pairs(_G.DynamicBagsDB.vault.characters) do
                if type(rec) == "table" then
                    local cName = SafeStr(rec.name, "")
                    local cRealm = SafeStr(rec.realm, myRealm)
                    if cName == "" and type(ck) == "string" then
                        cName, cRealm = ck:match("^([^%-]+)%-(.+)$")
                        cName = cName or ck
                        cRealm = cRealm or myRealm
                    end
                    if cName and cName ~= "" then
                        local normKey = (cName .. "-" .. NormalizeRealmNoSpace(cRealm)):lower()
                        pooled[normKey] = {
                            name      = cName,
                            realm     = cRealm,
                            classFile = SafeStr(rec.class or rec.classFile, "PRIEST"),
                            faction   = SafeStr(rec.faction, "Neutral"),
                            money     = SafeNum(rec.money or rec.copper, 0),
                            level     = SafeNum(rec.level, 80),
                            source    = "Vault",
                        }
                    end
                end
            end
        end
        -- 2. Merge own DynamicMailDB knownChars (standalone parity & fresher copper)
        for ck, rec in pairs(db.knownChars or {}) do
            if type(rec) == "table" and SafeStr(rec.name, "") ~= "" then
                local cName = SafeStr(rec.name, "")
                local cRealm = SafeStr(rec.realm, myRealm)
                local normKey = (cName .. "-" .. NormalizeRealmNoSpace(cRealm)):lower()
                local cur = pooled[normKey]
                if not cur then
                    pooled[normKey] = {
                        name      = cName,
                        realm     = cRealm,
                        classFile = SafeStr(rec.classFile, "PRIEST"),
                        faction   = SafeStr(rec.faction, "Neutral"),
                        money     = SafeNum(rec.money, 0),
                        level     = SafeNum(rec.level, 80),
                        source    = "Alt",
                    }
                else
                    if SafeNum(rec.money, -1) >= 0 then
                        cur.money = SafeNum(rec.money, cur.money)
                    end
                    if SafeStr(rec.classFile, "") ~= "" then
                        cur.classFile = SafeStr(rec.classFile, cur.classFile)
                    end
                end
            end
        end

        for normKey, rec in pairs(pooled) do
            if normKey ~= myFullLower then
                local sendTarget = FormatRecipientForMail(rec.name, rec.realm)
                local favKey = sendTarget:lower()
                local isFav = (favs[favKey] == true) or (favs[normKey] == true)
                local watch = (db.showPendingAltBadge ~= false and type(db.sentWatch) == "table") and db.sentWatch[normKey] or nil
                local watchSuffix = ""
                if type(watch) == "table" and ((SafeNum(watch.copper, 0) > 0) or (SafeNum(watch.items, 0) > 0)) then
                    local partsW = {}
                    if SafeNum(watch.items, 0) > 0 then
                        table.insert(partsW, string.format("%d item%s", watch.items, watch.items == 1 and "" or "s"))
                    end
                    if SafeNum(watch.copper, 0) > 0 then
                        table.insert(partsW, FormatCopper(watch.copper))
                    end
                    watchSuffix = string.format("  |cFFFBBF24[Sent: %s]|r", table.concat(partsW, ", "))
                end
                if MatchesFilter(rec.name, sendTarget, rec.realm) then
                    local baseSub = (NormalizeRealmNoSpace(rec.realm):lower() == NormalizeRealmNoSpace(myRealm):lower())
                        and (db.showAltGold and FormatCopper(rec.money) or "Same Realm")
                        or (rec.realm .. (db.showAltGold and ("  " .. FormatCopper(rec.money)) or ""))
                    table.insert(rows, {
                        name       = rec.name,
                        realm      = rec.realm,
                        sendTarget = sendTarget,
                        favKey     = favKey,
                        classFile  = rec.classFile,
                        money      = rec.money,
                        subText    = baseSub .. watchSuffix,
                        isFav      = isFav,
                        canFav     = true,
                    })
                end
            end
        end

        table.sort(rows, function(a, b)
            if db.sortFavouritesFirst and a.isFav ~= b.isFav then
                return a.isFav
            end
            return a.name:lower() < b.name:lower()
        end)

    elseif cat == "RECENT" then
        for _, item in ipairs(db.recentRecipients or {}) do
            local target = type(item) == "table" and SafeStr(item.target, "") or SafeStr(item, "")
            if target ~= "" and not seen[target:lower()] then
                seen[target:lower()] = true
                local baseName, rlm = target:match("^([^%-]+)%-(.+)$")
                baseName = baseName or target
                rlm = rlm or myRealm
                local favKey = target:lower()
                local isFav = (favs[favKey] == true)
                local cFile = type(item) == "table" and SafeStr(item.classFile, "PRIEST") or "PRIEST"
                if MatchesFilter(baseName, target, rlm) then
                    table.insert(rows, {
                        name       = baseName,
                        realm      = rlm,
                        sendTarget = target,
                        favKey     = favKey,
                        classFile  = cFile,
                        subText    = (type(item) == "table" and SafeStr(item.lastTime, "")) ~= "" and ("Sent " .. SafeStr(item.lastTime, "")) or rlm,
                        isFav      = isFav,
                        canFav     = true,
                    })
                end
            end
        end
        if db.sortFavouritesFirst then
            table.sort(rows, function(a, b)
                if a.isFav ~= b.isFav then return a.isFav end
                return false
            end)
        end

    elseif cat == "GUILD" then
        if type(IsInGuild) == "function" and IsInGuild() then
            if C_GuildInfo and type(C_GuildInfo.GuildRoster) == "function" then
                pcall(C_GuildInfo.GuildRoster)
            end
            local numGuild = (type(GetNumGuildMembers) == "function") and SafeNum(GetNumGuildMembers(), 0) or 0
            local cap = math.min(numGuild, 250)
            for i = 1, cap do
                local ok, fullName, rankName, _, level, _, _, _, _, isOnline, _, classFile = pcall(GetGuildRosterInfo, i)
                if ok and type(fullName) == "string" and fullName ~= "" and not SafeIsSecret(fullName) then
                    local baseName, rlm = fullName:match("^([^%-]+)%-(.+)$")
                    baseName = baseName or fullName
                    rlm = rlm or myRealm
                    local normKey = (baseName .. "-" .. NormalizeRealmNoSpace(rlm)):lower()
                    if normKey ~= myFullLower and not seen[normKey] then
                        seen[normKey] = true
                        local sendTarget = FormatRecipientForMail(baseName, rlm)
                        if MatchesFilter(baseName, sendTarget, rankName) then
                            table.insert(rows, {
                                name       = baseName,
                                realm      = rlm,
                                sendTarget = sendTarget,
                                favKey     = sendTarget:lower(),
                                classFile  = SafeStr(classFile, "PRIEST"),
                                subText    = SafeStr(rankName, "Member") .. (isOnline and " |cFF22C55E(Online)|r" or ""),
                                isOnline   = isOnline and true or false,
                                isFav      = (favs[sendTarget:lower()] == true),
                                canFav     = true,
                            })
                        end
                    end
                end
            end
            table.sort(rows, function(a, b)
                if db.sortFavouritesFirst and a.isFav ~= b.isFav then return a.isFav end
                if a.isOnline ~= b.isOnline then return a.isOnline end
                return a.name:lower() < b.name:lower()
            end)
        end

    elseif cat == "FRIENDS" then
        if C_FriendList and type(C_FriendList.GetNumFriends) == "function" then
            local nFr = SafeNum(C_FriendList.GetNumFriends(), 0)
            for i = 1, nFr do
                local ok, info = pcall(C_FriendList.GetFriendInfoByIndex, i)
                if ok and type(info) == "table" and SafeStr(info.name, "") ~= "" then
                    local baseName, rlm = SafeStr(info.name, ""):match("^([^%-]+)%-(.+)$")
                    baseName = baseName or SafeStr(info.name, "")
                    rlm = rlm or myRealm
                    local sendTarget = FormatRecipientForMail(baseName, rlm)
                    local key = sendTarget:lower()
                    if not seen[key] and MatchesFilter(baseName, sendTarget, rlm) then
                        seen[key] = true
                        table.insert(rows, {
                            name       = baseName,
                            realm      = rlm,
                            sendTarget = sendTarget,
                            favKey     = key,
                            classFile  = SafeStr(info.className, "PRIEST"),
                            subText    = info.connected and "|cFF22C55EFriend (Online)|r" or "Friend",
                            isOnline   = info.connected and true or false,
                            isFav      = (favs[key] == true),
                            canFav     = true,
                        })
                    end
                end
            end
        end
        if C_BattleNet and type(C_BattleNet.GetNumFriends) == "function" and type(C_BattleNet.GetFriendAccountInfo) == "function" then
            local okB, bTotal = pcall(C_BattleNet.GetNumFriends)
            local nBn = okB and SafeNum(bTotal, 0) or 0
            for i = 1, math.min(nBn, 150) do
                local okAcc, acc = pcall(C_BattleNet.GetFriendAccountInfo, i)
                if okAcc and type(acc) == "table" and type(acc.gameAccountInfo) == "table" then
                    local ga = acc.gameAccountInfo
                    if ga.clientProgram == _G.BNET_CLIENT_WOW and ga.wowProjectID == 1 and SafeStr(ga.characterName, "") ~= "" then
                        local cName = SafeStr(ga.characterName, "")
                        local cRealm = SafeStr(ga.realmName, myRealm)
                        local sendTarget = FormatRecipientForMail(cName, cRealm)
                        local key = sendTarget:lower()
                        if not seen[key] and MatchesFilter(cName, sendTarget, SafeStr(acc.accountName, "")) then
                            seen[key] = true
                            table.insert(rows, {
                                name       = cName,
                                realm      = cRealm,
                                sendTarget = sendTarget,
                                favKey     = key,
                                classFile  = SafeStr(ga.className, "PRIEST"),
                                subText    = "BNet: " .. SafeStr(acc.accountName, cRealm),
                                isOnline   = true,
                                isFav      = (favs[key] == true),
                                canFav     = true,
                            })
                        end
                    end
                end
            end
        end
        table.sort(rows, function(a, b)
            if db.sortFavouritesFirst and a.isFav ~= b.isFav then return a.isFav end
            if a.isOnline ~= b.isOnline then return a.isOnline end
            return a.name:lower() < b.name:lower()
        end)
    end

    return rows
end

-- ============================================================================
-- 5. BATCH INBOX COLLECTION ENGINE & CONFLICT YIELD CHECK
-- ============================================================================
local HARD_CONFLICT_ADDONS = { "Postal", "EasyMail", "CT_MailMod", "InboxMailBag", "MailCommander" }

local function IsYieldingToExternalMailAddon()
    local isAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
    if type(isAddOnLoaded) ~= "function" then return false, nil end
    for _, ext in ipairs(HARD_CONFLICT_ADDONS) do
        local ok, loaded = pcall(isAddOnLoaded, ext)
        if ok and loaded then
            local g = _G.DynamicSuiteDB and _G.DynamicSuiteDB.global
            local cKey = ext .. "_DynamicMail"
            local ack = g and g.acknowledgedConflicts and g.acknowledgedConflicts[cKey]
            if ack ~= "USE_DYNAMIC" and ack ~= "PRIORITISE_DYNAMIC" then
                return true, ext
            end
        end
    end
    return false, nil
end

local function CountFreeGeneralBagSlots()
    local free = 0
    local maxBag = _G.NUM_BAG_SLOTS or 4
    local reagentIdx = _G.Enum and _G.Enum.BagIndex and _G.Enum.BagIndex.ReagentBag
    for bag = 0, maxBag do
        if not reagentIdx or bag ~= reagentIdx then
            if C_Container and type(C_Container.GetContainerNumFreeSlots) == "function" then
                local ok, n = pcall(C_Container.GetContainerNumFreeSlots, bag)
                if ok then free = free + SafeNum(n, 0) end
            end
        end
    end
    return free
end

local function IsAuctionHouseMail(index, sender, subject)
    if type(GetInboxInvoiceInfo) == "function" then
        local ok, invType = pcall(GetInboxInvoiceInfo, index)
        if ok and type(invType) == "string" and invType ~= "" and not SafeIsSecret(invType) then
            return true
        end
    end
    local sLow = SafeStr(sender, ""):lower()
    if sLow:find("auction", 1, true) or sLow:find("black market", 1, true) then
        return true
    end
    local subjLow = SafeStr(subject, ""):lower()
    if subjLow:find("auction ", 1, true) or subjLow:find("outbid", 1, true) then
        return true
    end
    return false
end

local function GetInboxSummary()
    local numItems, totalItems = 0, 0
    if type(GetInboxNumItems) == "function" then
        local ok, n, tot = pcall(GetInboxNumItems)
        if ok then
            numItems = SafeNum(n, 0)
            totalItems = SafeNum(tot, numItems)
        end
    end
    local totalCopper, totalAttachments, codCount, unreadCount, expiringCount = 0, 0, 0, 0, 0
    for i = 1, numItems do
        local _, _, _, _, money, cod, daysLeft, hasItem, wasRead = GetInboxHeaderInfo(i)
        local m = SafeNum(money, 0)
        local c = SafeNum(cod, 0)
        local att = SafeNum(hasItem, 0)
        local dLeft = SafeNum(daysLeft, 30)
        if c > 0 then
            codCount = codCount + 1
        else
            totalCopper = totalCopper + m
        end
        totalAttachments = totalAttachments + att
        if not wasRead then
            unreadCount = unreadCount + 1
        end
        if dLeft > 0 and dLeft < 3 then
            expiringCount = expiringCount + 1
        end
    end
    return {
        numItems         = numItems,
        totalItems       = totalItems,
        totalCopper      = totalCopper,
        totalAttachments = totalAttachments,
        codCount         = codCount,
        unreadCount      = unreadCount,
        expiringCount    = expiringCount,
    }
end

local batchState = {
    active         = false,
    mode           = "ALL", -- "ALL", "AH_GOLD", "ITEMS", "CLEAN_EMPTY"
    currentIndex   = 0,
    lootedCopper   = 0,
    lootedItems    = 0,
    lootedMails    = 0,
    deletedMails   = 0,
    deleteAttempts = {},
    timerHandle    = nil,
    lastStepAt     = 0,
    waitCheckMail  = false,
}

-- RefreshInboxToolbarUI and RefreshSendPickerUI are forward-declared above EnsureEllesmereSkinRegistered.

local function StopBatchCollection(reasonMsg, isPaused)
    if not batchState.active then return end
    batchState.active = false
    if batchState.timerHandle and batchState.timerHandle.Cancel then
        pcall(batchState.timerHandle.Cancel, batchState.timerHandle)
    end
    batchState.timerHandle = nil

    local db = EnsureDB()
    local c = batchState.lootedCopper or 0
    local it = batchState.lootedItems or 0
    local m = batchState.lootedMails or 0
    local del = batchState.deletedMails or 0
    if c > 0 or it > 0 or m > 0 or del > 0 then
        db.stats.totalCopperLooted = (db.stats.totalCopperLooted or 0) + c
        db.stats.totalItemsLooted  = (db.stats.totalItemsLooted or 0) + it
        db.stats.totalMailsLooted  = (db.stats.totalMailsLooted or 0) + m
        local summary
        if c > 0 or it > 0 or m > 0 then
            summary = string.format("Collected %d item(s) across %d mail(s)", it, m)
            if del > 0 then
                summary = string.format("%s and deleted %d empty letter(s)", summary, del)
            end
        else
            summary = string.format("Deleted %d empty letter(s)", del)
        end
        AppendHistoryLog("LOOT", summary, c)
        if db.printBatchSummary then
            if c > 0 then
                Print(string.format("%s (%s).%s", summary, FormatCopper(c), reasonMsg and (" " .. reasonMsg) or ""))
            else
                Print(string.format("%s.%s", summary, reasonMsg and (" " .. reasonMsg) or ""))
            end
        end
        if db.playFinishSound and not isPaused and _G.SOUNDKIT and type(PlaySound) == "function" then
            pcall(PlaySound, _G.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "SFX")
        end
    elseif reasonMsg and reasonMsg ~= "" then
        Print(reasonMsg)
    end

    batchState.lootedCopper = 0
    batchState.lootedItems = 0
    batchState.lootedMails = 0
    batchState.deletedMails = 0
    batchState.deleteAttempts = {}
    if RefreshInboxToolbarUI then RefreshInboxToolbarUI(reasonMsg) end
end

local function ProcessNextMailStep()
    if not batchState.active then return end
    if InCombatLockdown() then
        StopBatchCollection("Paused during combat lockdown.", true)
        return
    end
    if not (_G.MailFrame and _G.MailFrame:IsShown()) then
        StopBatchCollection("Mailbox closed.", true)
        return
    end

    local db = EnsureDB()
    local numItems, totalItems = GetInboxNumItems()
    numItems = SafeNum(numItems, 0)
    totalItems = SafeNum(totalItems, numItems)

    if numItems == 0 then
        if totalItems > 0 then
            if C_Mail and type(C_Mail.CanCheckInbox) == "function" then
                local okCan, canCheck = pcall(C_Mail.CanCheckInbox)
                if okCan and canCheck and type(CheckInbox) == "function" then
                    pcall(CheckInbox)
                end
            elseif type(CheckInbox) == "function" then
                pcall(CheckInbox)
            end
            StopBatchCollection(string.format("%d additional mail(s) waiting for Blizzard's 60s inbox refresh.", totalItems), true)
        else
            StopBatchCollection(nil, false)
        end
        return
    end

    local reserve = math.max(0, math.min(8, SafeNum(db.keepFreeBagSlots, 1)))
    local freeSlots = CountFreeGeneralBagSlots()
    local bagsAtReserve = (freeSlots <= reserve)

    local targetIdx, takeMode, expectedMoney, expectedHasItem, targetDelKey = nil, nil, 0, 0, nil
    local foundItemBlockedByBags = false

    for i = numItems, 1, -1 do
        local _, _, sender, subject, money, cod, daysLeft, hasItem, wasRead, _, _, _, isGM = GetInboxHeaderInfo(i)
        local m = SafeNum(money, 0)
        local c = SafeNum(cod, 0)
        local att = SafeNum(hasItem, 0)

        if c <= 0 then
            local _, _, _, isInvoice = GetInboxText(i)
            local isAH = isInvoice or IsAuctionHouseMail(i, sender, subject)

            local delKey = string.format("%s|%s|%.2f", SafeStr(sender, ""), SafeStr(subject, ""), SafeNum(daysLeft, 0))
            local canDeleteEmpty = (att == 0 and m == 0 and not isGM and ((batchState.deleteAttempts and batchState.deleteAttempts[delKey]) or 0) < 2)
            if canDeleteEmpty and type(InboxItemCanDelete) == "function" then
                local okCan, canDel = pcall(InboxItemCanDelete, i)
                if okCan and not canDel then
                    canDeleteEmpty = false
                end
            end

            if batchState.mode == "CLEAN_EMPTY" then
                if canDeleteEmpty then
                    targetIdx = i
                    takeMode = "DELETE"
                    targetDelKey = delKey
                    break
                end
            elseif batchState.mode == "AH_GOLD" then
                if m > 0 and (isAH or db.ahIncludeAllNonCodGold) then
                    targetIdx = i
                    takeMode = "MONEY"
                    expectedMoney = m
                    break
                end
            elseif batchState.mode == "ITEMS" then
                if att > 0 then
                    if not bagsAtReserve then
                        targetIdx = i
                        takeMode = "LOOT"
                        expectedHasItem = att
                        expectedMoney = m
                        break
                    else
                        foundItemBlockedByBags = true
                    end
                end
            else -- "ALL"
                if att > 0 then
                    if not bagsAtReserve then
                        targetIdx = i
                        takeMode = "LOOT"
                        expectedHasItem = att
                        expectedMoney = m
                        break
                    else
                        foundItemBlockedByBags = true
                    end
                elseif m > 0 then
                    if (not bagsAtReserve) or db.collectGoldWhenBagsFull then
                        targetIdx = i
                        takeMode = "MONEY"
                        expectedMoney = m
                        break
                    end
                elseif (db.deleteEmptyLetters or db.deleteEmptySystemMail) and canDeleteEmpty then
                    targetIdx = i
                    takeMode = "DELETE"
                    targetDelKey = delKey
                    break
                end
            end
        end
    end

    if not targetIdx then
        if foundItemBlockedByBags then
            StopBatchCollection(string.format("Paused: bags reached your %d free-slot reserve.", reserve), true)
        elseif totalItems > numItems and C_Mail and C_Mail.CanCheckInbox and C_Mail.CanCheckInbox() and type(CheckInbox) == "function" then
            pcall(CheckInbox)
            batchState.timerHandle = C_Timer.NewTimer(0.65, ProcessNextMailStep)
        else
            StopBatchCollection(nil, false)
        end
        return
    end

    batchState.currentIndex = targetIdx
    if RefreshInboxToolbarUI then
        local stepLabel = (takeMode == "DELETE")
            and string.format("Clearing empty letter %d of %d...", targetIdx, numItems)
            or string.format("Collecting mail %d of %d...", targetIdx, numItems)
        RefreshInboxToolbarUI(stepLabel)
    end

    if takeMode == "MONEY" then
        if type(TakeInboxMoney) == "function" then
            local ok = pcall(TakeInboxMoney, targetIdx)
            if ok then
                batchState.lootedCopper = (batchState.lootedCopper or 0) + expectedMoney
                batchState.lootedMails  = (batchState.lootedMails or 0) + 1
            end
        end
    elseif takeMode == "LOOT" then
        if type(AutoLootMailItem) == "function" then
            local ok = pcall(AutoLootMailItem, targetIdx)
            if ok then
                batchState.lootedItems  = (batchState.lootedItems or 0) + 1
                batchState.lootedCopper = (batchState.lootedCopper or 0) + expectedMoney
                batchState.lootedMails  = (batchState.lootedMails or 0) + 1
            end
        end
    elseif takeMode == "DELETE" then
        -- Retail WoW requires unread empty letters to be opened via GetInboxText() before DeleteInboxItem()
        -- will permanently remove them on the server. Open unread letters on pass 1, then delete on pass 2.
        local wasRead = false
        if type(GetInboxHeaderInfo) == "function" then
            local _, _, _, _, _, _, _, _, rFlag = GetInboxHeaderInfo(targetIdx)
            wasRead = (rFlag == true)
        end
        if not wasRead and type(GetInboxText) == "function" then
            pcall(GetInboxText, targetIdx)
            if C_Timer and type(C_Timer.NewTimer) == "function" then
                batchState.timerHandle = C_Timer.NewTimer(0.26, ProcessNextMailStep)
            end
            return
        end
        if targetDelKey then
            batchState.deleteAttempts = batchState.deleteAttempts or {}
            batchState.deleteAttempts[targetDelKey] = (batchState.deleteAttempts[targetDelKey] or 0) + 1
            if batchState.deleteAttempts[targetDelKey] == 1 then
                batchState.deletedMails = (batchState.deletedMails or 0) + 1
            end
        end
        if type(DeleteInboxItem) == "function" then
            pcall(DeleteInboxItem, targetIdx)
        end
    end

    local delay = math.max(0.06, math.min(0.45, SafeNum(db.openInterval, 0.14)))
    if C_Timer and type(C_Timer.NewTimer) == "function" then
        batchState.timerHandle = C_Timer.NewTimer(delay, ProcessNextMailStep)
    end
end

function DynamicMail:StartBatchOpen(mode)
    local db = EnsureDB()
    if IsModuleDisabledInSuite("DynamicMail") or not db.enabled then return end
    if InCombatLockdown() then
        Print("Cannot collect mailbox items during combat.")
        return
    end
    if not (_G.MailFrame and _G.MailFrame:IsShown()) then return end
    if batchState.active then
        StopBatchCollection("Stopped by user.", true)
        return
    end
    batchState.active         = true
    batchState.mode           = mode or "ALL"
    batchState.lootedCopper   = 0
    batchState.lootedItems    = 0
    batchState.lootedMails    = 0
    batchState.deletedMails   = 0
    batchState.deleteAttempts = {}
    ProcessNextMailStep()
end

function DynamicMail:AbortBatchOpen()
    if batchState.active then
        StopBatchCollection("Stopped by user.", true)
    end
end

-- ============================================================================
-- 6. EXPRESS MULTI-ATTACH & SEND MAIL HOOKS
-- ============================================================================
local function FindNextFreeSendAttachmentSlot()
    local maxAttach = _G.ATTACHMENTS_MAX_SEND or 12
    for idx = 1, maxAttach do
        if type(HasSendMailItem) == "function" then
            local ok, has = pcall(HasSendMailItem, idx)
            if ok and not has then
                return idx
            end
        elseif type(GetSendMailItem) == "function" then
            local ok, itemName = pcall(GetSendMailItem, idx)
            if ok and not itemName then
                return idx
            end
        end
    end
    return nil
end

local function CountUsedSendAttachmentSlots()
    local used = 0
    local maxAttach = _G.ATTACHMENTS_MAX_SEND or 12
    for idx = 1, maxAttach do
        if type(HasSendMailItem) == "function" then
            local ok, has = pcall(HasSendMailItem, idx)
            if ok and has then used = used + 1 end
        elseif type(GetSendMailItem) == "function" then
            local ok, itemName = pcall(GetSendMailItem, idx)
            if ok and itemName then used = used + 1 end
        end
    end
    return used
end

local lastAltAttachTimes = {}

function DynamicMail:HandleBagSlotAltClick(bagID, slotID)
    local db = EnsureDB()
    if IsModuleDisabledInSuite("DynamicMail") or not db.enabled or not db.altClickAttach then
        return false
    end
    if InCombatLockdown() then return false end
    if not (_G.MailFrame and _G.MailFrame:IsShown() and _G.SendMailFrame and _G.SendMailFrame:IsShown()) then
        return false
    end
    local yielding = IsYieldingToExternalMailAddon()
    if yielding then return false end

    local slotKey = tostring(bagID) .. ":" .. tostring(slotID)
    local now = (type(GetTime) == "function" and GetTime()) or 0
    if (now - (lastAltAttachTimes[slotKey] or 0)) < 0.08 then
        return true
    end

    local cursorSameSlot = false
    if type(CursorHasItem) == "function" and CursorHasItem() and C_Cursor and C_Cursor.GetCursorItem then
        local okLoc, loc = pcall(C_Cursor.GetCursorItem)
        if okLoc and loc and loc.IsBagAndSlot and loc:IsBagAndSlot() and loc.GetBagAndSlot then
            local okBS, cBag, cSlot = pcall(loc.GetBagAndSlot, loc)
            if okBS and cBag == bagID and cSlot == slotID then
                cursorSameSlot = true
            end
        end
    end

    local freeIdx = FindNextFreeSendAttachmentSlot()
    if not freeIdx then
        if cursorSameSlot and type(ClearCursor) == "function" then
            ClearCursor()
        end
        Print("All 12 attachment slots are full. Send this mail or clear a slot first.")
        return true
    end

    local info = (C_Container and C_Container.GetContainerItemInfo) and C_Container.GetContainerItemInfo(bagID, slotID)
    if not info or not info.itemID then
        if cursorSameSlot and type(ClearCursor) == "function" then
            ClearCursor()
        end
        return false
    end
    if info.isLocked and not cursorSameSlot then return true end

    lastAltAttachTimes[slotKey] = now
    if not cursorSameSlot then
        if type(ClearCursor) == "function" then ClearCursor() end
        if C_Container and type(C_Container.PickupContainerItem) == "function" then
            C_Container.PickupContainerItem(bagID, slotID)
        elseif _G.PickupContainerItem then
            _G.PickupContainerItem(bagID, slotID)
        end
    end
    if type(CursorHasItem) == "function" and CursorHasItem() then
        if type(ClickSendMailItemButton) == "function" then
            pcall(ClickSendMailItemButton, freeIdx)
        end
        if type(ClearCursor) == "function" and CursorHasItem() then
            ClearCursor()
        end
        if db.autoFillSubject and _G.SendMailSubjectEditBox then
            local curSubj = SafeStr(_G.SendMailSubjectEditBox:GetText(), "")
            if curSubj == "" and info.hyperlink then
                local itemName = (C_Item and C_Item.GetItemNameByID) and C_Item.GetItemNameByID(info.hyperlink) or nil
                if not itemName and info.itemName then itemName = info.itemName end
                if type(itemName) == "string" and itemName ~= "" then
                    _G.SendMailSubjectEditBox:SetText(itemName)
                end
            end
        end
        if RefreshSendPickerUI then
            C_Timer.After(0.05, function() if RefreshSendPickerUI then RefreshSendPickerUI() end end)
        end
        return true
    end
    return false
end

local function BuildEquipSetSlotMap()
    local map = {}
    if not (C_EquipmentSet and type(C_EquipmentSet.GetEquipmentSetIDs) == "function") then
        return map
    end
    local okIds, ids = pcall(C_EquipmentSet.GetEquipmentSetIDs)
    if not okIds or type(ids) ~= "table" then return map end
    for _, setID in ipairs(ids) do
        local okLocs, locs = pcall(C_EquipmentSet.GetItemLocations, setID)
        if okLocs and type(locs) == "table" then
            for _, loc in pairs(locs) do
                if type(loc) == "number" and loc > 0 and _G.EquipmentManager_UnpackLocation then
                    local okU, player, bank, bags, voidStorage, slot, bag = pcall(_G.EquipmentManager_UnpackLocation, loc)
                    if okU and bags and type(bag) == "number" and type(slot) == "number" then
                        map[bag .. ":" .. slot] = true
                    end
                elseif type(loc) == "number" and _G.EquipmentManager_GetLocationData then
                    local okD, data = pcall(_G.EquipmentManager_GetLocationData, loc)
                    if okD and type(data) == "table" and data.isBags and type(data.bag) == "number" and type(data.slot) == "number" then
                        map[data.bag .. ":" .. data.slot] = true
                    end
                end
            end
        end
    end
    return map
end

local function InspectContainerMailCategory(bagID, slotID, equipMap)
    if not (C_Container and type(C_Container.GetContainerItemInfo) == "function") then
        return nil
    end
    local info = C_Container.GetContainerItemInfo(bagID, slotID)
    if not info or not info.itemID or info.isLocked then
        return nil
    end
    if equipMap and equipMap[bagID .. ":" .. slotID] then
        return nil
    end
    if type(C_Container.GetContainerItemPurchaseInfo) == "function" then
        local okP, refundInfo = pcall(C_Container.GetContainerItemPurchaseInfo, bagID, slotID)
        if okP and type(refundInfo) == "table" and SafeNum(refundInfo.refundSecRemaining, 0) > 0 then
            return nil
        end
    end

    local loc = _G.ItemLocation and _G.ItemLocation.CreateFromBagAndSlot and _G.ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    local isBound = (info.isBound == true)
    local isWuE = false
    if loc and loc.IsValid and loc:IsValid() then
        if C_Item and type(C_Item.IsBound) == "function" then
            local okB, bRes = pcall(C_Item.IsBound, loc)
            if okB and bRes ~= nil then isBound = (bRes == true) end
        end
        if C_Item and type(C_Item.IsBoundToAccountUntilEquipped) == "function" then
            local okW, wRes = pcall(C_Item.IsBoundToAccountUntilEquipped, loc)
            if okW and wRes then isWuE = true end
        end
    end

    local isWarbound = isWuE
    if not isWarbound and C_TooltipInfo and type(C_TooltipInfo.GetBagItem) == "function" then
        local okT, tip = pcall(C_TooltipInfo.GetBagItem, bagID, slotID)
        if okT and type(tip) == "table" and type(tip.lines) == "table" then
            local wue1 = SafeStr(_G.ITEM_ACCOUNTBOUND_UNTIL_EQUIP, "Warbound until equipped"):lower()
            local wue2 = SafeStr(_G.ITEM_BNETACCOUNTBOUND, "Warband Bound"):lower()
            local wue3 = SafeStr(_G.ITEM_BIND_TO_BNETACCOUNT, "Account Bound"):lower()
            local sb = SafeStr(_G.ITEM_SOULBOUND, "Soulbound"):lower()
            local seenSoulbound = false
            for _, ln in ipairs(tip.lines) do
                local lt = SafeStr(ln.leftText, ""):lower()
                if lt ~= "" then
                    if lt:find(wue1, 1, true) or lt:find(wue2, 1, true) or lt:find(wue3, 1, true) or lt:find("warbound", 1, true) then
                        isWarbound = true
                    elseif lt == sb then
                        seenSoulbound = true
                    end
                end
            end
            if seenSoulbound and not isWarbound then
                isBound = true
            end
        end
    end

    if isBound and not isWarbound then
        return nil
    end

    local classID = nil
    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        local okI, _, _, _, _, _, cID = pcall(C_Item.GetItemInfoInstant, info.itemID)
        if okI then classID = cID end
    end
    local IC = _G.Enum and _G.Enum.ItemClass
    if IC and classID == IC.Questitem then
        return nil
    end

    local isMat = false
    if IC then
        isMat = (classID == IC.Tradegoods or classID == IC.Profession or classID == IC.Recipe or classID == IC.Gem or classID == IC.ItemEnhancement)
    else
        isMat = (classID == 5 or classID == 7 or classID == 9 or classID == 3 or classID == 8)
    end
    local isGear = IC and (classID == IC.Armor or classID == IC.Weapon) or (classID == 4 or classID == 2)
    local isBoE = (not isBound) and isGear

    local itemName = nil
    if C_Item and type(C_Item.GetItemNameByID) == "function" and info.hyperlink then
        local okN, nStr = pcall(C_Item.GetItemNameByID, info.hyperlink)
        if okN and type(nStr) == "string" then itemName = nStr end
    end

    return {
        bagID      = bagID,
        slotID     = slotID,
        itemID     = info.itemID,
        itemName   = itemName or info.itemName,
        isMat      = isMat,
        isBoE      = isBoE,
        isWarbound = isWarbound,
    }
end

function DynamicMail:BatchAttachByPreset(presetKey)
    local db = EnsureDB()
    if IsModuleDisabledInSuite("DynamicMail") or not db.enabled then return 0 end
    if InCombatLockdown() then
        Print("Cannot attach items during combat.")
        return 0
    end
    if not (_G.MailFrame and _G.MailFrame:IsShown() and _G.SendMailFrame and _G.SendMailFrame:IsShown()) then
        Print("Open the Send Mail tab at any mailbox first.")
        return 0
    end
    local yielding = IsYieldingToExternalMailAddon()
    if yielding then return 0 end

    local key = tostring(presetKey or "MATS"):upper()
    local sameNames = {}
    if key == "SAME" then
        local maxAttach = _G.ATTACHMENTS_MAX_SEND or 12
        for idx = 1, maxAttach do
            if type(GetSendMailItem) == "function" then
                local okG, itemName = pcall(GetSendMailItem, idx)
                if okG and type(itemName) == "string" and itemName ~= "" and not SafeIsSecret(itemName) then
                    sameNames[itemName:lower()] = true
                end
            end
        end
        if not next(sameNames) then
            Print("Attach at least one item first before using [+ Same].")
            return 0
        end
    end

    local equipMap = BuildEquipSetSlotMap()
    local bagList = {}
    local maxBag = _G.NUM_BAG_SLOTS or 4
    for b = 0, maxBag do table.insert(bagList, b) end
    local reagentIdx = _G.Enum and _G.Enum.BagIndex and _G.Enum.BagIndex.ReagentBag
    if type(reagentIdx) == "number" and reagentIdx > maxBag then
        table.insert(bagList, reagentIdx)
    end

    local attached = 0
    local firstItemName = nil
    for _, bagID in ipairs(bagList) do
        local numSlots = (C_Container and C_Container.GetContainerNumSlots) and SafeNum(C_Container.GetContainerNumSlots(bagID), 0) or 0
        for slotID = 1, numSlots do
            local freeIdx = FindNextFreeSendAttachmentSlot()
            if not freeIdx then break end
            local cat = InspectContainerMailCategory(bagID, slotID, equipMap)
            if cat then
                local match = false
                if key == "MATS" then
                    match = cat.isMat and true or false
                elseif key == "BOE" then
                    match = cat.isBoE and true or false
                elseif key == "WARBAND" then
                    match = cat.isWarbound and true or false
                elseif key == "SAME" then
                    match = (type(cat.itemName) == "string" and sameNames[cat.itemName:lower()] == true)
                end
                if match then
                    if type(ClearCursor) == "function" then ClearCursor() end
                    if C_Container and type(C_Container.PickupContainerItem) == "function" then
                        C_Container.PickupContainerItem(bagID, slotID)
                    end
                    if type(CursorHasItem) == "function" and CursorHasItem() then
                        if type(ClickSendMailItemButton) == "function" then
                            pcall(ClickSendMailItemButton, freeIdx)
                        end
                        if type(ClearCursor) == "function" and CursorHasItem() then
                            ClearCursor()
                        end
                        attached = attached + 1
                        if not firstItemName then firstItemName = cat.itemName end
                    end
                end
            end
        end
        if not FindNextFreeSendAttachmentSlot() then break end
    end

    if attached > 0 then
        if db.autoFillSubject and _G.SendMailSubjectEditBox and SafeStr(_G.SendMailSubjectEditBox:GetText(), "") == "" then
            local subjLabel = (key == "MATS" and "Crafting Reagents")
                or (key == "BOE" and "BoE Gear")
                or (key == "WARBAND" and "Warbound Items")
                or firstItemName
                or "Mail Items"
            _G.SendMailSubjectEditBox:SetText(subjLabel)
        end
        Print(string.format("Attached %d item stack(s) [%s].", attached, key))
    else
        Print(string.format("No eligible mailable items found for [%s].", key))
    end
    if RefreshSendPickerUI then
        C_Timer.After(0.05, function() if RefreshSendPickerUI then RefreshSendPickerUI() end end)
    end
    return attached
end

function DynamicMail:AdjustSendGold(deltaCopper, resetToZero)
    if InCombatLockdown() or not _G.SendMailMoney then return end
    if type(MoneyInputFrame_SetCopper) ~= "function" then return end
    if resetToZero then
        pcall(MoneyInputFrame_SetCopper, _G.SendMailMoney, 0)
        return
    end
    local cur = (type(MoneyInputFrame_GetCopper) == "function") and SafeNum(MoneyInputFrame_GetCopper(_G.SendMailMoney), 0) or 0
    local myMoney = (type(GetMoney) == "function") and SafeNum(GetMoney(), 0) or 0
    local postage = 30
    local maxAllowed = math.max(0, myMoney - postage)
    local nextVal = math.max(0, math.min(maxAllowed, cur + SafeNum(deltaCopper, 0)))
    pcall(MoneyInputFrame_SetCopper, _G.SendMailMoney, nextVal)
end

function DynamicMail:GetPendingAltMailSummary(charKey)
    local db = EnsureDB()
    if type(db.sentWatch) ~= "table" then return nil end
    local k = SafeStr(charKey, ""):lower()
    if k == "" then return nil end
    local base, rlm = k:match("^([^%-]+)%-(.+)$")
    local norm = base and (base .. "-" .. NormalizeRealmNoSpace(rlm)) or k
    return db.sentWatch[norm] or db.sentWatch[k]
end

local pendingSentRecord = nil
local mailHooksInstalled = false

local function RecordSentMailTarget(recipient, subject, copperAmt, attachCount)
    local db = EnsureDB()
    local target = SafeStr(recipient, ""):match("^%s*(.-)%s*$") or ""
    if target == "" then return end
    db.lastRecipient = target
    db.stats.totalMailsSent = (db.stats.totalMailsSent or 0) + 1

    local _, _, myRealm = GetPlayerKeyAndParts()
    local tBase, tRealm = target:match("^([^%-]+)%-(.+)$")
    local tNormKey = (tBase and (tBase .. "-" .. NormalizeRealmNoSpace(tRealm)) or (target .. "-" .. NormalizeRealmNoSpace(myRealm))):lower()

    local isKnownAlt = false
    for ck, kc in pairs(db.knownChars or {}) do
        if type(kc) == "table" then
            local kNorm = (SafeStr(kc.name, "") .. "-" .. NormalizeRealmNoSpace(kc.realm)):lower()
            if kNorm == tNormKey or SafeStr(ck, ""):lower() == tNormKey then
                isKnownAlt = true
                break
            end
        end
    end
    if not isKnownAlt and type(_G.DynamicBagsDB) == "table" and type(_G.DynamicBagsDB.vault) == "table" and type(_G.DynamicBagsDB.vault.characters) == "table" then
        for ck, rec in pairs(_G.DynamicBagsDB.vault.characters) do
            if type(rec) == "table" then
                local cName = SafeStr(rec.name, "")
                local cRealm = SafeStr(rec.realm, myRealm)
                local vNorm = (cName .. "-" .. NormalizeRealmNoSpace(cRealm)):lower()
                if vNorm == tNormKey or SafeStr(ck, ""):lower() == tNormKey then
                    isKnownAlt = true
                    break
                end
            end
        end
    end

    if isKnownAlt then
        db.sentWatch = db.sentWatch or {}
        local w = db.sentWatch[tNormKey] or { copper = 0, items = 0, mails = 0 }
        w.copper = SafeNum(w.copper, 0) + SafeNum(copperAmt, 0)
        w.items  = SafeNum(w.items, 0) + SafeNum(attachCount, 0)
        w.mails  = SafeNum(w.mails, 0) + 1
        w.lastAt = time and time() or 0
        db.sentWatch[tNormKey] = w
    end

    if db.rememberRecent then
        local targetLow = target:lower()
        for i = #db.recentRecipients, 1, -1 do
            local r = db.recentRecipients[i]
            local rT = type(r) == "table" and SafeStr(r.target, "") or SafeStr(r, "")
            if rT:lower() == targetLow then
                table.remove(db.recentRecipients, i)
            end
        end
        local cFile = "PRIEST"
        for _, kc in pairs(db.knownChars or {}) do
            if type(kc) == "table" and FormatRecipientForMail(kc.name, kc.realm):lower() == targetLow then
                cFile = SafeStr(kc.classFile, "PRIEST")
                break
            end
        end
        table.insert(db.recentRecipients, 1, {
            target    = target,
            classFile = cFile,
            lastTime  = date and date("%d/%m %H:%M") or "",
        })
        local cap = math.max(5, math.min(50, SafeNum(db.recentLimit, 25)))
        while #db.recentRecipients > cap do
            table.remove(db.recentRecipients)
        end
    end

    local subjStr = SafeStr(subject, "")
    local label = subjStr ~= "" and (target .. " (" .. subjStr .. ")") or target
    AppendHistoryLog("SENT", "Sent to " .. label, SafeNum(copperAmt, 0))
end

local function InstallMailboxHooks()
    if mailHooksInstalled then return end
    mailHooksInstalled = true

    if type(hooksecurefunc) == "function" then
        if type(_G.SendMailFrame_SendMail) == "function" then
            hooksecurefunc("SendMailFrame_SendMail", function()
                if IsModuleDisabledInSuite("DynamicMail") or not EnsureDB().enabled then return end
                local r = _G.SendMailNameEditBox and SafeStr(_G.SendMailNameEditBox:GetText(), "") or ""
                local s = _G.SendMailSubjectEditBox and SafeStr(_G.SendMailSubjectEditBox:GetText(), "") or ""
                local m = (type(MoneyInputFrame_GetCopper) == "function" and _G.SendMailMoney) and SafeNum(MoneyInputFrame_GetCopper(_G.SendMailMoney), 0) or 0
                pendingSentRecord = { target = r, subject = s, money = m, attachCount = CountUsedSendAttachmentSlots() }
            end)
        end
        if type(_G.SendMailFrame_Update) == "function" then
            hooksecurefunc("SendMailFrame_Update", function()
                local db = EnsureDB()
                if db.restoreLastRecipient and db.lastRecipient ~= "" and _G.SendMailNameEditBox and _G.SendMailFrame and _G.SendMailFrame:IsShown() then
                    if SafeStr(_G.SendMailNameEditBox:GetText(), "") == "" then
                        _G.SendMailNameEditBox:SetText(db.lastRecipient)
                    end
                end
                if RefreshSendPickerUI then RefreshSendPickerUI() end
            end)
        end
        if type(_G.MailFrameTab_OnClick) == "function" then
            hooksecurefunc("MailFrameTab_OnClick", function()
                if RefreshInboxToolbarUI then RefreshInboxToolbarUI() end
                if RefreshSendPickerUI then
                    RefreshSendPickerUI()
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0.05, function() if RefreshSendPickerUI then RefreshSendPickerUI() end end)
                    end
                end
            end)
        end
        if type(_G.InboxFrameItem_OnClick) == "function" then
            hooksecurefunc("InboxFrameItem_OnClick", function(self, button)
                local db = EnsureDB()
                if IsModuleDisabledInSuite("DynamicMail") or not db.enabled or not db.shiftClickInboxLoot then return end
                if InCombatLockdown() or not IsShiftKeyDown() or button ~= "LeftButton" then return end
                local yielding = IsYieldingToExternalMailAddon()
                if yielding then return end
                local idx = self and self.index or (self and self.GetID and self:GetID())
                if type(idx) == "number" and idx > 0 then
                    local _, _, _, _, money, cod, _, hasItem = GetInboxHeaderInfo(idx)
                    if SafeNum(cod, 0) <= 0 then
                        if SafeNum(hasItem, 0) > 0 and type(AutoLootMailItem) == "function" then
                            pcall(AutoLootMailItem, idx)
                        elseif SafeNum(money, 0) > 0 and type(TakeInboxMoney) == "function" then
                            pcall(TakeInboxMoney, idx)
                        end
                    end
                end
            end)
        end
        local function DispatchBlizzardBagAltClick(self, button)
            if button == "LeftButton" and IsAltKeyDown and IsAltKeyDown()
                and not (IsControlKeyDown and IsControlKeyDown())
                and not (IsShiftKeyDown and IsShiftKeyDown()) then
                if not (_G.MailFrame and _G.MailFrame:IsShown() and _G.SendMailFrame and _G.SendMailFrame:IsShown()) then
                    return
                end
                local b, s
                if self and self.GetBagID then
                    local okB, resB = pcall(self.GetBagID, self)
                    if okB and type(resB) == "number" then b = resB end
                end
                if not b and self and self.GetParent then
                    local p = self:GetParent()
                    if p and p.GetID then
                        local okP, resP = pcall(p.GetID, p)
                        if okP and type(resP) == "number" then b = resP end
                    end
                end
                if self and self.GetID then
                    local okS, resS = pcall(self.GetID, self)
                    if okS and type(resS) == "number" then s = resS end
                end
                if type(b) == "number" and type(s) == "number" then
                    DynamicMail:HandleBagSlotAltClick(b, s)
                end
            end
        end
        if type(_G.ContainerFrameItemButtonMixin) == "table" and type(_G.ContainerFrameItemButtonMixin.OnClick) == "function" then
            hooksecurefunc(_G.ContainerFrameItemButtonMixin, "OnClick", DispatchBlizzardBagAltClick)
        end
        if type(_G.ContainerFrameItemButton_OnClick) == "function" then
            hooksecurefunc("ContainerFrameItemButton_OnClick", DispatchBlizzardBagAltClick)
        end
        if type(_G.ContainerFrameItemButton_OnModifiedClick) == "function" then
            hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", DispatchBlizzardBagAltClick)
        end
    end
end

-- ============================================================================
-- 7. MAILFRAME OBSIDIAN OVERLAYS (INBOX TOOLBAR + SEND RECIPIENT PICKER)
-- ============================================================================
local inboxBar = nil
local sendPanel = nil

local function StyleObsidianOverlayBtn(btn, isPrimary)
    local surf, acc = GetOverlayTheme()
    local fillA = ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42)
    if isPrimary then
        ApplyBackdrop(btn, { acc.r * fillA, acc.g * fillA, acc.b * fillA, 0.98 }, { acc.r, acc.g, acc.b, 0.95 })
        if btn.txt then btn.txt:SetTextColor(1, 1, 1, 1) end
    else
        ApplyBackdrop(btn, surf.card or { 0.068, 0.078, 0.106, 0.98 }, surf.border)
        if btn.txt then btn.txt:SetTextColor(0.86, 0.90, 0.96, 1) end
    end
end

local function CreateOverlayActionBtn(parent, width, height, label, isPrimary, onClick, tipTitle, tipDesc)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")
    local txt = btn:CreateFontString(nil, "OVERLAY")
    SetFontSafe(txt, 10.5, "")
    txt:SetPoint("CENTER")
    txt:SetText(label)
    txt:SetWordWrap(false)
    btn.txt = txt
    btn.isPrimary = isPrimary and true or false
    StyleObsidianOverlayBtn(btn, btn.isPrimary)
    btn:SetScript("OnEnter", function(self)
        local _, acc = GetOverlayTheme()
        local fillA = ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42)
        ApplyBackdrop(self, { acc.r * (fillA + 0.14), acc.g * (fillA + 0.14), acc.b * (fillA + 0.14), 1.0 }, { acc.r, acc.g, acc.b, 1.0 })
        if self.txt then self.txt:SetTextColor(1, 1, 1, 1) end
        if tipTitle and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(tipTitle, 1, 1, 1)
            if tipDesc then
                GameTooltip:AddLine(string.format("|cFF%sLeft-Click:|r |cFFE2E8F0%s|r", acc.hex, tipDesc), 1, 1, 1, true)
            end
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        StyleObsidianOverlayBtn(self, self.isPrimary)
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    btn:SetScript("OnClick", function(self)
        if onClick then onClick(self) end
    end)
    return btn
end

local function EnsureInboxToolbar()
    if inboxBar then return inboxBar end
    if not _G.MailFrame then return nil end

    local surf, acc = GetOverlayTheme()
    local bar = CreateFrame("Frame", "DynamicMailInboxBar", _G.MailFrame, "BackdropTemplate")
    bar:SetHeight(56)
    bar:SetPoint("BOTTOMLEFT", _G.MailFrame, "TOPLEFT", 0, 6)
    bar:SetPoint("BOTTOMRIGHT", _G.MailFrame, "TOPRIGHT", 0, 6)
    bar:SetFrameStrata("HIGH")
    bar:SetFrameLevel((_G.MailFrame:GetFrameLevel() or 1) + 5)
    bar:EnableMouse(true)
    ApplyBackdrop(bar, surf.bg, { acc.r, acc.g, acc.b, 0.72 })

    local topAcc = CreateSolidTex(bar, "OVERLAY", 2, acc.r, acc.g, acc.b, 1.0)
    topAcc:SetHeight(2)
    topAcc:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    topAcc:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -1, -1)
    bar.topAcc = topAcc

    bar.btnAll = CreateOverlayActionBtn(bar, 72, 22, "Open All", true, function()
        DynamicMail:StartBatchOpen("ALL")
    end, "Open All Mail", "Collect all non-COD attachments and gold (and delete empty zero-gold/zero-item letters when enabled in settings).")
    bar.btnAll:SetPoint("TOPLEFT", bar, "TOPLEFT", 8, -7)

    bar.btnGold = CreateOverlayActionBtn(bar, 66, 22, "AH Gold", false, function()
        DynamicMail:StartBatchOpen("AH_GOLD")
    end, "Collect Auction House Gold", "Collect gold from Auction House & invoice mails without looting item stacks.")
    bar.btnGold:SetPoint("LEFT", bar.btnAll, "RIGHT", 5, 0)

    bar.btnItems = CreateOverlayActionBtn(bar, 56, 22, "Items", false, function()
        DynamicMail:StartBatchOpen("ITEMS")
    end, "Collect Attachments Only", "Loot mails with item attachments while pausing cleanly if bags hit your free-slot reserve.")
    bar.btnItems:SetPoint("LEFT", bar.btnGold, "RIGHT", 5, 0)

    bar.btnClean = CreateOverlayActionBtn(bar, 86, 22, "Clear Empty", false, function()
        DynamicMail:StartBatchOpen("CLEAN_EMPTY")
    end, "Clear Empty Letters", "Opens unread text-only letters and permanently deletes all zero-gold, zero-item notices (NPC Lost Currency, Postmaster, Auction receipts). Never deletes COD, items, gold, or GM mail.")
    bar.btnClean:SetPoint("LEFT", bar.btnItems, "RIGHT", 5, 0)

    bar.btnCfg = CreateFrame("Button", nil, bar, "BackdropTemplate")
    bar.btnCfg:SetSize(24, 22)
    bar.btnCfg:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -8, -7)
    ApplyBackdrop(bar.btnCfg, { 0.068, 0.078, 0.106, 0.98 }, surf.border)
    local cogTex = bar.btnCfg:CreateTexture(nil, "ARTWORK")
    cogTex:SetSize(13, 13)
    cogTex:SetPoint("CENTER")
    cogTex:SetTexture(ICON_COG)
    cogTex:SetVertexColor(0.84, 0.89, 0.96, 1.0)
    bar.btnCfg:SetScript("OnEnter", function(s)
        local _, a = GetOverlayTheme()
        ApplyBackdrop(s, { a.r * 0.35, a.g * 0.35, a.b * 0.35, 0.98 }, { a.r, a.g, a.b, 1.0 })
        cogTex:SetVertexColor(1, 1, 1, 1)
    end)
    bar.btnCfg:SetScript("OnLeave", function(s)
        local sf = GetOverlayTheme()
        ApplyBackdrop(s, sf.card or { 0.068, 0.078, 0.106, 0.98 }, sf.border)
        cogTex:SetVertexColor(0.84, 0.89, 0.96, 1.0)
    end)
    bar.btnCfg:SetScript("OnClick", function()
        if DynamicMail.Open then DynamicMail.Open() end
    end)

    bar.btnAbort = CreateOverlayActionBtn(bar, 58, 22, "Stop", false, function()
        DynamicMail:AbortBatchOpen()
    end, "Stop Batch Collection", "Cancel the active mailbox collection pass immediately.")
    bar.btnAbort:SetPoint("RIGHT", bar.btnCfg, "LEFT", -6, 0)
    bar.btnAbort:Hide()

    bar.statusText = bar:CreateFontString(nil, "OVERLAY")
    SetFontSafe(bar.statusText, 10.5, "")
    bar.statusText:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 10, 7)
    bar.statusText:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -10, 7)
    bar.statusText:SetJustifyH("LEFT")
    bar.statusText:SetWordWrap(false)
    bar.statusText:SetTextColor(0.80, 0.85, 0.92, 1.0)

    inboxBar = bar
    return bar
end

RefreshInboxToolbarUI = function(customNote)
    local db = EnsureDB()
    if IsModuleDisabledInSuite("DynamicMail") or not db.enabled or not db.mailboxBarEnabled
        or not (_G.MailFrame and _G.MailFrame:IsShown()) then
        if inboxBar then inboxBar:Hide() end
        return
    end
    local yielding, extName = IsYieldingToExternalMailAddon()
    if yielding then
        if inboxBar then inboxBar:Hide() end
        return
    end
    local onInbox = (not _G.SendMailFrame) or (not _G.SendMailFrame:IsShown())
    if not onInbox then
        if inboxBar then inboxBar:Hide() end
        return
    end

    local bar = EnsureInboxToolbar()
    if not bar then return end
    bar:SetFrameLevel((_G.MailFrame:GetFrameLevel() or 1) + 5)
    local surf, acc = GetOverlayTheme()
    ApplyBackdrop(bar, surf.bg, { acc.r, acc.g, acc.b, 0.72 })
    if bar.topAcc then bar.topAcc:SetColorTexture(acc.r, acc.g, acc.b, 1.0) end
    StyleObsidianOverlayBtn(bar.btnAll, true)
    StyleObsidianOverlayBtn(bar.btnGold, false)
    StyleObsidianOverlayBtn(bar.btnItems, false)
    if bar.btnClean then StyleObsidianOverlayBtn(bar.btnClean, false) end
    StyleObsidianOverlayBtn(bar.btnAbort, false)
    if bar.btnCfg then ApplyBackdrop(bar.btnCfg, surf.card or { 0.068, 0.078, 0.106, 0.98 }, surf.border) end

    -- Dock cleanly at the top of MailFrame above header chrome; only flip below tabs if near screen top
    bar:ClearAllPoints()
    local uiTop = (UIParent and UIParent.GetTop and UIParent:GetTop()) or 1080
    local mfTop = (_G.MailFrame.GetTop and _G.MailFrame:GetTop()) or 600
    if (uiTop - mfTop) < 66 then
        bar:SetPoint("TOPLEFT", _G.MailFrame, "BOTTOMLEFT", 0, -34)
        bar:SetPoint("TOPRIGHT", _G.MailFrame, "BOTTOMRIGHT", 0, -34)
    else
        bar:SetPoint("BOTTOMLEFT", _G.MailFrame, "TOPLEFT", 0, 6)
        bar:SetPoint("BOTTOMRIGHT", _G.MailFrame, "TOPRIGHT", 0, 6)
    end

    if bar.btnClean then bar.btnClean:SetShown(not batchState.active) end
    bar.btnAbort:SetShown(batchState.active)
    if type(customNote) == "string" and customNote ~= "" then
        bar.statusText:SetText(customNote)
    else
        local sum = GetInboxSummary()
        local parts = {}
        if sum.totalItems > sum.numItems then
            table.insert(parts, string.format("%d/%d mails", sum.numItems, sum.totalItems))
        else
            table.insert(parts, string.format("%d mail%s", sum.numItems, sum.numItems == 1 and "" or "s"))
        end
        if sum.totalCopper > 0 then
            table.insert(parts, FormatCopper(sum.totalCopper))
        end
        if sum.totalAttachments > 0 then
            table.insert(parts, string.format("%d item%s", sum.totalAttachments, sum.totalAttachments == 1 and "" or "s"))
        end
        if sum.codCount > 0 then
            table.insert(parts, string.format("|cFFF87171%d COD|r", sum.codCount))
        end
        if db.warnExpiringMail and SafeNum(sum.expiringCount, 0) > 0 then
            table.insert(parts, string.format("|cFFFBBF24%d Expiring (<3d)|r", sum.expiringCount))
        end
        bar.statusText:SetText(table.concat(parts, "   |   "))
    end
    bar:Show()
end

local function ClearAllSendMailAttachments()
    if InCombatLockdown() then return end
    local maxAttach = _G.ATTACHMENTS_MAX_SEND or 12
    for i = 1, maxAttach do
        if type(ClickSendMailItemButton) == "function" then
            local has = type(HasSendMailItem) == "function" and HasSendMailItem(i) or false
            if has then
                pcall(ClickSendMailItemButton, i, true)
                if type(ClearCursor) == "function" and CursorHasItem and CursorHasItem() then
                    ClearCursor()
                end
            end
        end
    end
    if RefreshSendPickerUI then RefreshSendPickerUI() end
end

local function EnsureSendPickerPanel()
    if sendPanel then return sendPanel end
    if not _G.MailFrame then return nil end

    local surf, acc = GetTheme()
    local panel = CreateFrame("Frame", "DynamicMailSendPickerPanel", _G.MailFrame, "BackdropTemplate")
    panel:SetWidth(262)
    panel:SetPoint("TOPLEFT", _G.MailFrame, "TOPRIGHT", 6, 0)
    panel:SetPoint("BOTTOMLEFT", _G.MailFrame, "BOTTOMRIGHT", 6, 0)
    panel:SetFrameStrata("HIGH")
    panel:EnableMouse(true)
    ApplyBackdrop(panel, surf.bg, { acc.r, acc.g, acc.b, 0.72 })

    local topBar = CreateSolidTex(panel, "OVERLAY", 2, acc.r, acc.g, acc.b, 1.0)
    topBar:SetHeight(2)
    topBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
    topBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
    panel.topBar = topBar

    local hdr = panel:CreateFontString(nil, "OVERLAY")
    SetFontSafe(hdr, 11.5, "")
    hdr:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
    hdr:SetText("|cFFCBD5E1Recipient|r |cFFFFFFFFPicker|r")
    panel.hdr = hdr

    local cfgBtn = CreateFrame("Button", nil, panel, "BackdropTemplate")
    cfgBtn:SetSize(22, 20)
    cfgBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -8)
    ApplyBackdrop(cfgBtn, { 0.068, 0.078, 0.106, 0.98 }, surf.border)
    local cogTex = cfgBtn:CreateTexture(nil, "ARTWORK")
    cogTex:SetSize(12, 12)
    cogTex:SetPoint("CENTER")
    cogTex:SetTexture(ICON_COG)
    cogTex:SetVertexColor(0.84, 0.89, 0.96, 1.0)
    cfgBtn:SetScript("OnClick", function()
        if DynamicMail.Open then DynamicMail.Open() end
    end)
    panel.cfgBtn = cfgBtn

    -- 4 Category Tabs: Alts | Recent | Guild | Friends
    local tabTrack = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    tabTrack:SetHeight(28)
    tabTrack:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -32)
    tabTrack:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -32)
    ApplyBackdrop(tabTrack, surf.header, surf.border)
    panel.tabTrack = tabTrack

    local tabDefs = {
        { key = "ALTS",    label = "Alts" },
        { key = "RECENT",  label = "Recent" },
        { key = "GUILD",   label = "Guild" },
        { key = "FRIENDS", label = "Friends" },
    }
    panel.tabBtns = {}
    for idx, td in ipairs(tabDefs) do
        local tb = CreateFrame("Button", nil, tabTrack, "BackdropTemplate")
        tb:SetHeight(22)
        tb.key = td.key
        local txt = tb:CreateFontString(nil, "OVERLAY")
        SetFontSafe(txt, 10, "")
        txt:SetPoint("CENTER")
        txt:SetText(td.label)
        tb.txt = txt
        tb:SetScript("OnClick", function()
            EnsureDB().activePickerTab = td.key
            RefreshSendPickerUI()
        end)
        panel.tabBtns[idx] = tb
    end
    tabTrack:SetScript("OnSizeChanged", function(self, w)
        if not w or w < 40 then return end
        local gap = 3
        local eachW = (w - 8 - ((#panel.tabBtns - 1) * gap)) / #panel.tabBtns
        for idx, tb in ipairs(panel.tabBtns) do
            tb:ClearAllPoints()
            tb:SetWidth(eachW)
            if idx == 1 then
                tb:SetPoint("LEFT", self, "LEFT", 4, 0)
            else
                tb:SetPoint("LEFT", panel.tabBtns[idx - 1], "RIGHT", gap, 0)
            end
        end
    end)

    -- Search Filter Box + Inline 'x' Clear Button
    local sbHolder = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    sbHolder:SetHeight(24)
    sbHolder:SetPoint("TOPLEFT", tabTrack, "BOTTOMLEFT", 0, -6)
    sbHolder:SetPoint("TOPRIGHT", tabTrack, "BOTTOMRIGHT", 0, -6)
    ApplyBackdrop(sbHolder, { 0.035, 0.039, 0.051, 0.98 }, surf.border)
    panel.sbHolder = sbHolder

    local clearBtn = CreateFrame("Button", nil, sbHolder)
    clearBtn:SetSize(18, 18)
    clearBtn:SetPoint("RIGHT", sbHolder, "RIGHT", -3, 0)
    local clearTxt = clearBtn:CreateFontString(nil, "OVERLAY")
    SetFontSafe(clearTxt, 10.5, "")
    clearTxt:SetPoint("CENTER")
    clearTxt:SetText("x")
    clearTxt:SetTextColor(0.64, 0.70, 0.78, 1)
    clearBtn:Hide()

    local sb = CreateFrame("EditBox", nil, sbHolder)
    sb:SetPoint("LEFT", sbHolder, "LEFT", 8, 0)
    sb:SetPoint("RIGHT", clearBtn, "LEFT", -2, 0)
    sb:SetHeight(20)
    sb:SetAutoFocus(false)
    SetFontSafe(sb, 10.5, "")
    sb:SetTextColor(0.95, 0.97, 1.0, 1)
    local ph = sb:CreateFontString(nil, "OVERLAY")
    SetFontSafe(ph, 10.5, "")
    ph:SetPoint("LEFT", sb, "LEFT", 0, 0)
    ph:SetText("Filter recipient...")
    ph:SetTextColor(0.45, 0.52, 0.62, 0.9)

    sb:SetScript("OnEscapePressed", function(self)
        if SafeStr(self:GetText(), "") ~= "" then
            self:SetText("")
        end
        self:ClearFocus()
    end)
    sb:SetScript("OnTextChanged", function(self)
        local txt = SafeStr(self:GetText(), "")
        ph:SetShown(txt == "")
        clearBtn:SetShown(txt ~= "")
        RefreshSendPickerUI()
    end)
    clearBtn:SetScript("OnClick", function()
        sb:SetText("")
        sb:ClearFocus()
    end)
    panel.searchBox = sb

    -- Footer Bar inside Send Panel (Express Attach Status + Clear Queue)
    local foot = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    foot:SetHeight(44)
    foot:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 8)
    foot:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 8)
    ApplyBackdrop(foot, { 0.035, 0.039, 0.051, 0.98 }, surf.border)
    panel.foot = foot

    panel.attachLabel = foot:CreateFontString(nil, "OVERLAY")
    SetFontSafe(panel.attachLabel, 10, "")
    panel.attachLabel:SetPoint("TOPLEFT", foot, "TOPLEFT", 8, -6)
    panel.attachLabel:SetPoint("TOPRIGHT", foot, "TOPRIGHT", -74, -6)
    panel.attachLabel:SetJustifyH("LEFT")
    panel.attachLabel:SetTextColor(0.76, 0.82, 0.90, 1)

    panel.hintLabel = foot:CreateFontString(nil, "OVERLAY")
    SetFontSafe(panel.hintLabel, 9.5, "")
    panel.hintLabel:SetPoint("BOTTOMLEFT", foot, "BOTTOMLEFT", 8, 6)
    panel.hintLabel:SetPoint("BOTTOMRIGHT", foot, "BOTTOMRIGHT", -74, 6)
    panel.hintLabel:SetJustifyH("LEFT")
    panel.hintLabel:SetTextColor(0.55, 0.63, 0.72, 1)
    panel.hintLabel:SetText("Alt + Left-Click bag items to attach")

    panel.btnClearAttach = CreateOverlayActionBtn(foot, 60, 24, "Clear", false, function()
        ClearAllSendMailAttachments()
    end, "Clear Attached Items", "Return all currently attached items back to your bags.")
    panel.btnClearAttach:SetPoint("RIGHT", foot, "RIGHT", -6, 0)

    -- Quick Attach & Quick Gold Action Dock (above footer)
    local quickBar = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    quickBar:SetHeight(52)
    quickBar:SetPoint("BOTTOMLEFT", foot, "TOPLEFT", 0, 5)
    quickBar:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", 0, 5)
    ApplyBackdrop(quickBar, { 0.035, 0.039, 0.051, 0.98 }, surf.border)
    panel.quickBar = quickBar

    local qaDefs = {
        { key = "MATS",    label = "+ Mats",    tip = "Attach Crafting Reagents, Recipes, Gems & Enchants (up to 12 slots)." },
        { key = "BOE",     label = "+ BoE",     tip = "Attach unbound Bind-on-Equip gear (skips Equipment Manager sets)." },
        { key = "WARBAND", label = "+ Warband", tip = "Attach Warbound Until Equipped (WuE) and Account-Bound items." },
        { key = "SAME",    label = "+ Same",    tip = "Find and attach more stacks matching items already queued in Send Mail." },
    }
    panel.qaBtns = {}
    for idx, qd in ipairs(qaDefs) do
        local qb = CreateOverlayActionBtn(quickBar, 56, 20, qd.label, false, function()
            DynamicMail:BatchAttachByPreset(qd.key)
        end, "Quick Attach: " .. qd.label, qd.tip)
        panel.qaBtns[idx] = qb
    end

    local qgDefs = {
        { delta = 10000000,   reset = false, label = "+1k g",  tip = "Add 1,000g to the Send Mail gold field." },
        { delta = 100000000,  reset = false, label = "+10k g", tip = "Add 10,000g to the Send Mail gold field." },
        { delta = 1000000000, reset = false, label = "+100k",  tip = "Add 100,000g to the Send Mail gold field." },
        { delta = 0,          reset = true,  label = "Reset",  tip = "Reset Send Mail attached gold back to 0g." },
    }
    panel.qgBtns = {}
    for idx, gd in ipairs(qgDefs) do
        local gb = CreateOverlayActionBtn(quickBar, 56, 20, gd.label, false, function()
            DynamicMail:AdjustSendGold(gd.delta, gd.reset)
        end, "Quick Gold: " .. gd.label, gd.tip)
        panel.qgBtns[idx] = gb
    end
    quickBar:SetScript("OnSizeChanged", function(self, w)
        if not w or w < 60 then return end
        local gap = 4
        local eachW = math.floor((w - 10 - (3 * gap)) / 4)
        for idx, qb in ipairs(panel.qaBtns) do
            qb:ClearAllPoints()
            qb:SetWidth(eachW)
            if idx == 1 then
                qb:SetPoint("TOPLEFT", self, "TOPLEFT", 5, -5)
            else
                qb:SetPoint("LEFT", panel.qaBtns[idx - 1], "RIGHT", gap, 0)
            end
        end
        for idx, gb in ipairs(panel.qgBtns) do
            gb:ClearAllPoints()
            gb:SetWidth(eachW)
            if idx == 1 then
                gb:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 5, 5)
            else
                gb:SetPoint("LEFT", panel.qgBtns[idx - 1], "RIGHT", gap, 0)
            end
        end
    end)

    -- Scrollable Recipient List with 3-Way Interactive 4px Obsidian Scrollbar
    local listFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", sbHolder, "BOTTOMLEFT", 0, -6)
    listFrame:SetPoint("TOPRIGHT", sbHolder, "BOTTOMRIGHT", 0, -6)
    listFrame:SetPoint("BOTTOM", quickBar, "TOP", 0, 5)
    ApplyBackdrop(listFrame, { 0.030, 0.035, 0.046, 0.98 }, surf.border)
    panel.listFrame = listFrame

    local scroll = CreateFrame("ScrollFrame", nil, listFrame)
    scroll:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 2, -2)
    scroll:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -10, 2)
    scroll:EnableMouseWheel(true)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(220)
    child:SetHeight(1)
    scroll:SetScrollChild(child)

    local track = CreateFrame("Frame", nil, listFrame, "BackdropTemplate")
    track:SetWidth(6)
    track:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -2, -4)
    track:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -2, 4)
    ApplyBackdrop(track, { 0.05, 0.06, 0.08, 0.9 }, { 1, 1, 1, 0.06 })

    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(4)
    thumb:SetHeight(28)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    thumbTex:SetAllPoints()
    thumbTex:SetColorTexture(0.45, 0.52, 0.64, 0.75)

    local function UpdatePickerScroll()
        local viewH = scroll:GetHeight() or 1
        local contH = child:GetHeight() or 1
        local maxS = math.max(0, contH - viewH)
        local curS = math.max(0, math.min(maxS, scroll:GetVerticalScroll() or 0))
        local _, a = GetTheme()
        if thumb.isDragging or thumb:IsMouseOver() then
            thumbTex:SetColorTexture(a.r, a.g, a.b, 0.95)
        else
            thumbTex:SetColorTexture(0.45, 0.52, 0.64, 0.75)
        end
        if maxS <= 0 then
            thumb:Hide()
            return
        end
        thumb:Show()
        local trackH = math.max(20, track:GetHeight() or 100)
        local thumbH = math.max(24, math.min(trackH, math.floor(trackH * (viewH / contH))))
        thumb:SetHeight(thumbH)
        local travel = math.max(1, trackH - thumbH)
        local yOff = (curS / maxS) * travel
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -yOff)
    end

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local viewH = self:GetHeight() or 1
        local maxS = math.max(0, (child:GetHeight() or 1) - viewH)
        local nextS = math.max(0, math.min(maxS, (self:GetVerticalScroll() or 0) - (delta * 36)))
        self:SetVerticalScroll(nextS)
        UpdatePickerScroll()
    end)
    track:EnableMouse(true)
    track:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local _, cy = GetCursorPosition()
        cy = cy / (self:GetEffectiveScale() or 1)
        local topY = self:GetTop() or cy
        local h = math.max(1, self:GetHeight() or 100)
        local pct = math.max(0, math.min(1, (topY - cy) / h))
        local maxS = math.max(0, (child:GetHeight() or 1) - (scroll:GetHeight() or 1))
        scroll:SetVerticalScroll(pct * maxS)
        UpdatePickerScroll()
    end)
    local function OnPickerThumbUpdate(self)
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            self.isDragging = false
            self:SetScript("OnUpdate", nil)
            UpdatePickerScroll()
            return
        end
        local _, curY = GetCursorPosition()
        curY = curY / (self:GetEffectiveScale() or 1)
        local dy = (self.startY or curY) - curY
        local viewH = scroll:GetHeight() or 1
        local maxS = math.max(0, (child:GetHeight() or 1) - viewH)
        local travel = math.max(1, (track:GetHeight() or 100) - (self:GetHeight() or 24))
        scroll:SetVerticalScroll(math.max(0, math.min(maxS, (self.startScroll or 0) + (dy / travel) * maxS)))
        UpdatePickerScroll()
    end
    thumb:SetScript("OnEnter", function() UpdatePickerScroll() end)
    thumb:SetScript("OnLeave", function() UpdatePickerScroll() end)
    thumb:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self.isDragging = true
        local _, cy = GetCursorPosition()
        self.startY = cy / (self:GetEffectiveScale() or 1)
        self.startScroll = scroll:GetVerticalScroll() or 0
        UpdatePickerScroll()
        self:SetScript("OnUpdate", OnPickerThumbUpdate)
    end)
    thumb:SetScript("OnMouseUp", function(self)
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
        UpdatePickerScroll()
    end)
    thumb:SetScript("OnHide", function(self)
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
    end)

    panel.rowPool = {}
    panel.emptyText = child:CreateFontString(nil, "OVERLAY")
    SetFontSafe(panel.emptyText, 10.5, "")
    panel.emptyText:SetPoint("TOP", child, "TOP", 0, -24)
    panel.emptyText:SetWidth(200)
    panel.emptyText:SetTextColor(0.55, 0.62, 0.72, 1)
    panel.emptyText:SetText("No matching recipients found.")
    panel.emptyText:Hide()

    panel.scroll = scroll
    panel.child = child
    panel.UpdateScroll = UpdatePickerScroll

    sendPanel = panel
    return panel
end

RefreshSendPickerUI = function()
    local db = EnsureDB()
    if IsModuleDisabledInSuite("DynamicMail") or not db.enabled or not db.recipientPanelEnabled
        or not (_G.MailFrame and _G.MailFrame:IsShown())
        or not (_G.SendMailFrame and _G.SendMailFrame:IsShown()) then
        if sendPanel then sendPanel:Hide() end
        return
    end
    local yielding = IsYieldingToExternalMailAddon()
    if yielding then
        if sendPanel then sendPanel:Hide() end
        return
    end

    local panel = EnsureSendPickerPanel()
    if not panel then return end

    local surf, acc = GetOverlayTheme()
    local fillA = ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42)
    ApplyBackdrop(panel, surf.bg, { acc.r, acc.g, acc.b, 0.72 })
    if panel.topBar then panel.topBar:SetColorTexture(acc.r, acc.g, acc.b, 1.0) end
    ApplyBackdrop(panel.tabTrack, surf.header, surf.border)
    ApplyBackdrop(panel.listFrame, surf.panel or { 0.030, 0.035, 0.046, 0.98 }, surf.border)
    if panel.foot then ApplyBackdrop(panel.foot, surf.panel or { 0.035, 0.039, 0.051, 0.98 }, surf.border) end
    if panel.sbHolder then ApplyBackdrop(panel.sbHolder, surf.header or { 0.035, 0.039, 0.051, 0.98 }, surf.border) end
    if panel.cfgBtn then ApplyBackdrop(panel.cfgBtn, surf.card or { 0.068, 0.078, 0.106, 0.98 }, surf.border) end

    -- Auto-dodge EllesmereUIMailAltList (if shown on right edge) and right viewport edge cleanly
    panel:ClearAllPoints()
    local mfLeft  = (_G.MailFrame.GetLeft and _G.MailFrame:GetLeft()) or 200
    local mfRight = (_G.MailFrame.GetRight and _G.MailFrame:GetRight()) or 400
    local uiRight = (UIParent and UIParent.GetRight and UIParent:GetRight()) or 1920
    local altList = _G.EllesmereUIMailAltList
    if altList and altList.IsShown and altList:IsShown() then
        local altRight = (altList.GetRight and altList:GetRight()) or (mfRight + 210)
        if mfLeft >= 272 then
            panel:SetPoint("TOPRIGHT", _G.MailFrame, "TOPLEFT", -6, 0)
            panel:SetPoint("BOTTOMRIGHT", _G.MailFrame, "BOTTOMLEFT", -6, 0)
        elseif (altRight + 272) <= uiRight then
            panel:SetPoint("TOPLEFT", altList, "TOPRIGHT", 6, 0)
            panel:SetPoint("BOTTOMLEFT", altList, "BOTTOMRIGHT", 6, 0)
        else
            panel:SetPoint("TOPRIGHT", _G.MailFrame, "TOPLEFT", -6, 0)
            panel:SetPoint("BOTTOMRIGHT", _G.MailFrame, "BOTTOMLEFT", -6, 0)
        end
    elseif (mfRight + 272) > uiRight then
        panel:SetPoint("TOPRIGHT", _G.MailFrame, "TOPLEFT", -6, 0)
        panel:SetPoint("BOTTOMRIGHT", _G.MailFrame, "BOTTOMLEFT", -6, 0)
    else
        panel:SetPoint("TOPLEFT", _G.MailFrame, "TOPRIGHT", 6, 0)
        panel:SetPoint("BOTTOMLEFT", _G.MailFrame, "BOTTOMRIGHT", 6, 0)
    end

    local curCat = db.activePickerTab or "ALTS"
    for _, tb in ipairs(panel.tabBtns) do
        if tb.key == curCat then
            ApplyBackdrop(tb, { acc.r * fillA, acc.g * fillA, acc.b * fillA, 0.98 }, { acc.r, acc.g, acc.b, 0.95 })
            tb.txt:SetTextColor(1, 1, 1, 1)
        else
            ApplyBackdrop(tb, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
            tb.txt:SetTextColor(0.62, 0.68, 0.78, 1)
        end
    end

    local usedAttach = CountUsedSendAttachmentSlots()
    panel.attachLabel:SetText(string.format("Attached: |cFF%s%d / 12|r", acc.hex, usedAttach))
    StyleObsidianOverlayBtn(panel.btnClearAttach, false)
    if panel.quickBar then
        local showQuick = (db.showQuickAttachBar ~= false) or (db.showQuickGoldBar ~= false)
        panel.quickBar:SetShown(showQuick)
        panel.listFrame:ClearAllPoints()
        panel.listFrame:SetPoint("TOPLEFT", panel.sbHolder, "BOTTOMLEFT", 0, -6)
        panel.listFrame:SetPoint("TOPRIGHT", panel.sbHolder, "BOTTOMRIGHT", 0, -6)
        if showQuick then
            local wantH = ((db.showQuickAttachBar ~= false) and (db.showQuickGoldBar ~= false)) and 52 or 28
            panel.quickBar:SetHeight(wantH)
            for _, qb in ipairs(panel.qaBtns or {}) do
                qb:SetShown(db.showQuickAttachBar ~= false)
                StyleObsidianOverlayBtn(qb, false)
            end
            for _, gb in ipairs(panel.qgBtns or {}) do
                gb:SetShown(db.showQuickGoldBar ~= false)
                StyleObsidianOverlayBtn(gb, false)
            end
            panel.listFrame:SetPoint("BOTTOM", panel.quickBar, "TOP", 0, 5)
        else
            panel.listFrame:SetPoint("BOTTOM", panel.foot, "TOP", 0, 6)
        end
    end

    local listW = math.max(180, (panel.scroll:GetWidth() or 220) - 2)
    panel.child:SetWidth(listW)

    local query = panel.searchBox and SafeStr(panel.searchBox:GetText(), "") or ""
    local items = BuildRecipientList(curCat, query)

    local yOff = 2
    for idx, entry in ipairs(items) do
        local row = panel.rowPool[idx]
        if not row then
            row = CreateFrame("Button", nil, panel.child, "BackdropTemplate")
            row:SetHeight(34)
            row.nameFS = row:CreateFontString(nil, "OVERLAY")
            SetFontSafe(row.nameFS, 11, "")
            row.nameFS:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
            row.nameFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", -28, -4)
            row.nameFS:SetJustifyH("LEFT")
            row.nameFS:SetWordWrap(false)

            row.subFS = row:CreateFontString(nil, "OVERLAY")
            SetFontSafe(row.subFS, 9.5, "")
            row.subFS:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 4)
            row.subFS:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -28, 4)
            row.subFS:SetJustifyH("LEFT")
            row.subFS:SetWordWrap(false)
            row.subFS:SetTextColor(0.60, 0.66, 0.75, 1)

            row.favBtn = CreateFrame("Button", nil, row)
            row.favBtn:SetSize(22, 22)
            row.favBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.favTxt = row.favBtn:CreateFontString(nil, "OVERLAY")
            SetFontSafe(row.favTxt, 12, "")
            row.favTxt:SetPoint("CENTER")

            row:SetScript("OnEnter", function(s)
                local _, a = GetTheme()
                ApplyBackdrop(s, { a.r * 0.22, a.g * 0.22, a.b * 0.22, 0.96 }, { a.r, a.g, a.b, 0.85 })
            end)
            row:SetScript("OnLeave", function(s)
                local sf = GetTheme()
                ApplyBackdrop(s, sf.card, sf.border)
            end)
            panel.rowPool[idx] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel.child, "TOPLEFT", 2, -yOff)
        row:SetPoint("TOPRIGHT", panel.child, "TOPRIGHT", -2, -yOff)
        ApplyBackdrop(row, surf.card, surf.border)

        local cHex = GetClassColorHex(entry.classFile)
        row.nameFS:SetText(string.format("|cFF%s%s|r", cHex, entry.name))
        row.subFS:SetText(entry.subText or "")

        row.favBtn:SetShown(entry.canFav == true)
        if entry.isFav then
            row.favTxt:SetText("*")
            row.favTxt:SetTextColor(0.98, 0.80, 0.20, 1.0)
        else
            row.favTxt:SetText("+")
            row.favTxt:SetTextColor(0.42, 0.48, 0.58, 0.85)
        end

        row.favBtn:SetScript("OnClick", function()
            local d = EnsureDB()
            d.favourites = d.favourites or {}
            if d.favourites[entry.favKey] then
                d.favourites[entry.favKey] = nil
            else
                d.favourites[entry.favKey] = true
            end
            RefreshSendPickerUI()
        end)

        row:SetScript("OnClick", function()
            if _G.SendMailNameEditBox then
                _G.SendMailNameEditBox:SetText(entry.sendTarget)
                if _G.SendMailNameEditBox.ClearFocus then _G.SendMailNameEditBox:ClearFocus() end
                if _G.SendMailSubjectEditBox and SafeStr(_G.SendMailSubjectEditBox:GetText(), "") == "" then
                    _G.SendMailSubjectEditBox:SetFocus()
                end
            end
        end)

        row:Show()
        yOff = yOff + 37
    end

    for idx = #items + 1, #panel.rowPool do
        panel.rowPool[idx]:Hide()
    end

    panel.emptyText:SetShown(#items == 0)
    panel.child:SetHeight(math.max(48, yOff + 4))
    panel:Show()
    panel.UpdateScroll()
end

-- ============================================================================
-- 8. MODULE RESET, STATUS TEXT & EMBEDDED 3-TAB OBSIDIAN UI (/dmail)
-- ============================================================================
local activeEmbeddedRoot = nil
local standaloneWindow = nil
local activeDropdown = nil

local function CloseAnyDropdown()
    if activeDropdown and activeDropdown.Hide then
        activeDropdown:Hide()
    end
    activeDropdown = nil
end

local function RegisterMailPopupCloser()
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.RegisterPopupCloser) == "function" then
        pcall(_G.DynamicSuite.UI.RegisterPopupCloser, "DynamicMail", CloseAnyDropdown)
    end
end

function DynamicMail:GetStatusText()
    local db = EnsureDB()
    local sum = GetInboxSummary()
    local altsCount = 0
    for _ in pairs(db.knownChars or {}) do altsCount = altsCount + 1 end
    if _G.MailFrame and _G.MailFrame:IsShown() then
        return string.format("Mailbox Open: |cFFFFFFFF%d|r mails   |   Reserve: |cFFFFFFFF%d|r bag slots   |   Tracked Alts: |cFF22C55E%d|r",
            sum.numItems, db.keepFreeBagSlots or 1, altsCount)
    end
    return string.format("Reserve: |cFFFFFFFF%d slot(s)|r   |   Alt Attach: |cFF22C55E%s|r   |   Total Looted: %s",
        db.keepFreeBagSlots or 1, db.altClickAttach and "ON" or "OFF", FormatCopper(db.stats and db.stats.totalCopperLooted or 0))
end

local function CreateStyledButton(parent, label, width, height, isPrimary, onClick)
    local surf, acc = GetTheme()
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 120, height or 24)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")
    local txt = btn:CreateFontString(nil, "OVERLAY")
    SetFontSafe(txt, 11, "")
    txt:SetPoint("CENTER")
    txt:SetText(label or "")
    btn.txt = txt
    local function StyleRest()
        local s, a = GetTheme()
        local fillA = ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42)
        if isPrimary then
            ApplyBackdrop(btn, { a.r * fillA, a.g * fillA, a.b * fillA, 0.98 }, { a.r, a.g, a.b, 0.95 })
            txt:SetTextColor(1, 1, 1, 1)
        else
            ApplyBackdrop(btn, { 0.068, 0.078, 0.106, 0.98 }, s.border)
            txt:SetTextColor(0.86, 0.90, 0.96, 1)
        end
    end
    StyleRest()
    btn:SetScript("OnEnter", function()
        local _, a = GetTheme()
        local fillA = ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42)
        ApplyBackdrop(btn, { a.r * (fillA + 0.12), a.g * (fillA + 0.12), a.b * (fillA + 0.12), 0.98 }, { a.r, a.g, a.b, 1.0 })
        txt:SetTextColor(1, 1, 1, 1)
    end)
    btn:SetScript("OnLeave", StyleRest)
    btn:SetScript("OnClick", function(self)
        CloseAnyDropdown()
        if onClick then onClick(self) end
    end)
    return btn
end

local function CreateSectionBox(parent, yTop)
    local surf = GetTheme()
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box.innerPadX = 14
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yTop)
    box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yTop)
    ApplyBackdrop(box, surf.panel or DEFAULT_SURFACE.panel, surf.border)
    return box
end

local function CreateSectionHeader(parent, yOffset, titleText, subtitleText)
    local _, acc = GetTheme()
    local padX = (parent and parent.innerPadX) or 0
    local hdr = CreateFrame("Frame", nil, parent)
    hdr:SetHeight(36)
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, yOffset)
    hdr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -padX, yOffset)

    local leftBar = CreateSolidTex(hdr, "ARTWORK", 1, acc.r, acc.g, acc.b, 1.0)
    leftBar:SetSize(3, 34)
    leftBar:SetPoint("TOPLEFT", hdr, "TOPLEFT", 0, -1)

    local botLine = CreateSolidTex(hdr, "ARTWORK", 1, acc.r, acc.g, acc.b, 0.35)
    botLine:SetHeight(1)
    botLine:SetPoint("TOPLEFT", leftBar, "BOTTOMLEFT", 0, 0)
    botLine:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)

    local txt = hdr:CreateFontString(nil, "OVERLAY")
    SetFontSafe(txt, 11, "")
    txt:SetPoint("TOPLEFT", leftBar, "TOPRIGHT", 8, 0)
    txt:SetPoint("RIGHT", hdr, "RIGHT", -12, 0)
    txt:SetJustifyH("LEFT")
    txt:SetWordWrap(false)
    txt:SetTextColor(acc.r, acc.g, acc.b, 1.0)
    txt:SetText(string.upper(titleText or ""))

    local sub = hdr:CreateFontString(nil, "OVERLAY")
    SetFontSafe(sub, 10, "")
    sub:SetPoint("TOPLEFT", txt, "BOTTOMLEFT", 0, -3)
    sub:SetPoint("RIGHT", hdr, "RIGHT", -12, 0)
    sub:SetJustifyH("LEFT")
    sub:SetWordWrap(false)
    sub:SetTextColor(0.64, 0.70, 0.78, 1.0)
    sub:SetText(subtitleText or "")

    return hdr, -44
end

local function CreateCard(parent, height, yOffset, isSubDrawer)
    local surf, acc = GetTheme()
    local padX = (parent and parent.innerPadX) or 0
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetHeight(height or 56)
    if isSubDrawer then
        card:SetPoint("TOPLEFT", parent, "TOPLEFT", padX + 10, yOffset)
        card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(padX + 10), yOffset)
        ApplyBackdrop(card, { 0.035, 0.039, 0.051, 0.98 }, { 0.145, 0.165, 0.212, 0.95 })
        local leftBar = card:CreateTexture(nil, "OVERLAY")
        leftBar:SetWidth(2)
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

local function CreateSegmentedSwitchCard(parent, yOffset, titleText, descText, getter, setter, isSubDrawer, onChange)
    local cardHeight = isSubDrawer and 52 or 56
    local card = CreateCard(parent, cardHeight, yOffset, isSubDrawer)
    local surf, acc = GetTheme()

    local title = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(title, 11, "")
    if isSubDrawer then
        title:SetPoint("TOPLEFT", card, "TOPLEFT", 22, -8)
        local pip = card:CreateTexture(nil, "OVERLAY")
        pip:SetSize(5, 5)
        pip:SetPoint("RIGHT", title, "LEFT", -6, 0)
        pip:SetColorTexture(acc.r, acc.g, acc.b, 0.95)
    else
        title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -9)
    end
    title:SetText(titleText)
    title:SetTextColor(0.97, 0.98, 1.0, 1.0)
    card.title = title

    local pillGroup = CreateFrame("Frame", nil, card, "BackdropTemplate")
    pillGroup:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    ApplyBackdrop(pillGroup, surf.header, surf.border)
    title:SetPoint("RIGHT", pillGroup, "LEFT", -14, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)

    local offBtn = CreateFrame("Button", nil, pillGroup, "BackdropTemplate")
    offBtn:SetPoint("LEFT", pillGroup, "LEFT", 1, 0)
    local offTxt = offBtn:CreateFontString(nil, "OVERLAY")
    SetFontSafe(offTxt, 11, "")
    offTxt:SetPoint("CENTER")
    offTxt:SetText("Off")
    offBtn:SetSize(68, 22)
    local offBar = offBtn:CreateTexture(nil, "OVERLAY")
    offBar:SetHeight(1.5)
    offBar:SetPoint("BOTTOMLEFT", offBtn, "BOTTOMLEFT", 1, 1)
    offBar:SetPoint("BOTTOMRIGHT", offBtn, "BOTTOMRIGHT", -1, 1)
    offBar:SetColorTexture(0.973, 0.443, 0.443, 0.85)
    offBar:Hide()

    local onBtn = CreateFrame("Button", nil, pillGroup, "BackdropTemplate")
    onBtn:SetPoint("RIGHT", pillGroup, "RIGHT", -1, 0)
    local onTxt = onBtn:CreateFontString(nil, "OVERLAY")
    SetFontSafe(onTxt, 11, "")
    onTxt:SetPoint("CENTER")
    onTxt:SetText("Enabled")
    onBtn:SetSize(84, 22)
    pillGroup:SetSize(156, 26)

    local desc = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(desc, 10.5, "")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    desc:SetPoint("RIGHT", pillGroup, "LEFT", -14, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    if desc.SetMaxLines then desc:SetMaxLines(2) end
    desc:SetText(descText)
    desc:SetTextColor(0.62, 0.68, 0.76, 1.0)

    local function UpdateVisual()
        local isOn = getter() and true or false
        local _, a = GetTheme()
        local fillA = ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42)
        if isOn then
            offBar:Hide()
            ApplyBackdrop(offBtn, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
            offTxt:SetTextColor(0.55, 0.62, 0.70, 1.0)
            ApplyBackdrop(onBtn, { a.r * fillA, a.g * fillA, a.b * fillA, 0.98 }, { a.r, a.g, a.b, 0.95 })
            onTxt:SetTextColor(1, 1, 1, 1)
        else
            offBar:Show()
            ApplyBackdrop(offBtn, { 0.118, 0.141, 0.188, 0.98 }, { 0.392, 0.455, 0.545, 0.90 })
            offTxt:SetTextColor(0.886, 0.910, 0.941, 1.0)
            ApplyBackdrop(onBtn, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
            onTxt:SetTextColor(0.55, 0.62, 0.70, 1.0)
        end
    end

    offBtn:SetScript("OnClick", function()
        CloseAnyDropdown()
        if getter() then
            setter(false)
            UpdateVisual()
            if onChange then onChange(false) end
        end
    end)
    onBtn:SetScript("OnClick", function()
        CloseAnyDropdown()
        if not getter() then
            setter(true)
            UpdateVisual()
            if onChange then onChange(true) end
        end
    end)
    UpdateVisual()
    return card, -(cardHeight + 6)
end

local function CreateMultiPillCard(parent, yOffset, titleText, descText, options, getter, setter, onChange)
    local card = CreateCard(parent, 58, yOffset, false)
    local surf = GetTheme()

    local title = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(title, 11, "")
    title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -9)
    title:SetText(titleText)
    title:SetTextColor(0.97, 0.98, 1.0, 1.0)
    card.title = title

    local pillGroup = CreateFrame("Frame", nil, card, "BackdropTemplate")
    pillGroup:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    ApplyBackdrop(pillGroup, surf.header, surf.border)
    title:SetPoint("RIGHT", pillGroup, "LEFT", -16, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)

    local btns = {}
    local totalW = 4
    for idx, opt in ipairs(options) do
        local b = CreateFrame("Button", nil, pillGroup, "BackdropTemplate")
        local bTxt = b:CreateFontString(nil, "OVERLAY")
        SetFontSafe(bTxt, 10.5, "")
        bTxt:SetPoint("CENTER")
        bTxt:SetText(opt.label)
        local w = math.max(66, math.ceil((bTxt:GetStringWidth() or 40) + 20))
        b:SetSize(w, 22)
        b.value = opt.value
        b.txt = bTxt
        if idx == 1 then
            b:SetPoint("LEFT", pillGroup, "LEFT", 2, 0)
        else
            b:SetPoint("LEFT", btns[idx - 1], "RIGHT", 2, 0)
            totalW = totalW + 2
        end
        totalW = totalW + w
        btns[idx] = b
    end
    pillGroup:SetSize(totalW, 26)

    local desc = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(desc, 10.5, "")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    desc:SetPoint("RIGHT", pillGroup, "LEFT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    if desc.SetMaxLines then desc:SetMaxLines(2) end
    desc:SetText(descText)
    desc:SetTextColor(0.62, 0.68, 0.76, 1.0)

    local function RefreshPills()
        local cur = getter()
        local _, a = GetTheme()
        local fillA = ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42)
        for _, b in ipairs(btns) do
            if b.value == cur then
                ApplyBackdrop(b, { a.r * fillA, a.g * fillA, a.b * fillA, 0.98 }, { a.r, a.g, a.b, 0.95 })
                b.txt:SetTextColor(1, 1, 1, 1)
            else
                ApplyBackdrop(b, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
                b.txt:SetTextColor(0.62, 0.68, 0.78, 1)
            end
        end
    end
    for _, b in ipairs(btns) do
        b:SetScript("OnClick", function()
            setter(b.value)
            RefreshPills()
            if onChange then onChange(b.value) end
        end)
    end
    RefreshPills()
    return card, -64
end

local function CreateSliderCard(parent, yOffset, titleText, descText, minVal, maxVal, stepVal, formatFn, getter, setter, onChange)
    local card = CreateCard(parent, 58, yOffset, false)
    local _, acc = GetTheme()
    stepVal = stepVal or 1

    local title = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(title, 11, "")
    title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -9)
    title:SetText(titleText)
    title:SetTextColor(0.97, 0.98, 1.0, 1.0)
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

    local desc = card:CreateFontString(nil, "OVERLAY")
    SetFontSafe(desc, 10.5, "")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    desc:SetPoint("RIGHT", holder, "LEFT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    if desc.SetMaxLines then desc:SetMaxLines(2) end
    desc:SetText(descText)
    desc:SetTextColor(0.62, 0.68, 0.76, 1.0)

    local fill = track:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
    fill:SetWidth(1)
    fill:SetColorTexture(acc.r, acc.g, acc.b, 0.85)

    local thumb = track:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(6, 14)
    thumb:SetColorTexture(0.97, 0.98, 1.00, 1.0)
    if thumb.SetSnapToPixelGrid then
        thumb:SetSnapToPixelGrid(false)
        thumb:SetTexelSnappingBias(0)
    end
    track:SetThumbTexture(thumb)

    local isDragging, isInit, lastCommitted = false, false, nil
    local function RoundStep(v)
        v = math.max(minVal, math.min(maxVal, v or minVal))
        local r = math.floor(((v - minVal) / stepVal) + 0.5) * stepVal + minVal
        return math.max(minVal, math.min(maxVal, tonumber(string.format("%.2f", r)) or r))
    end
    local function UpdateFill(v, rawVal)
        local _, a = GetTheme()
        fill:SetColorTexture(a.r, a.g, a.b, 0.85)
        thumb:SetColorTexture((isDragging or track:IsMouseOver()) and a.r or 0.97, (isDragging or track:IsMouseOver()) and a.g or 0.98, (isDragging or track:IsMouseOver()) and a.b or 1.0, 1.0)
        local pct = ((rawVal or v) - minVal) / math.max(0.001, maxVal - minVal)
        pct = math.max(0, math.min(1.0, pct))
        local w = track:GetWidth()
        if not w or w <= 4 then w = 194 end
        fill:SetWidth(math.max(1, w * pct))
        valBadge:SetText(formatFn and formatFn(v) or tostring(v))
        valBadge:SetTextColor(a.r, a.g, a.b, 1.0)
    end

    local cur = RoundStep(getter() or minVal)
    lastCommitted = cur
    isInit = true
    track:SetValue(cur)
    UpdateFill(cur, cur)
    isInit = false

    track:SetScript("OnSizeChanged", function()
        local r = RoundStep(track:GetValue())
        UpdateFill(r, track:GetValue())
    end)
    track:SetScript("OnValueChanged", function(_, val)
        if isInit then return end
        local r = RoundStep(val)
        UpdateFill(r, val)
        if r ~= lastCommitted then
            lastCommitted = r
            setter(r)
            if onChange then onChange(r) end
        end
    end)
    local function UpdateFromCursor(self)
        if isDragging and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            isDragging = false
            self:SetScript("OnUpdate", nil)
            return
        end
        local cx = GetCursorPosition() / (self:GetEffectiveScale() or 1)
        local left, tw = self:GetLeft(), self:GetWidth()
        if left and tw and tw > 0 then
            local pct = math.max(0, math.min(1, (cx - left) / tw))
            self:SetValue(minVal + pct * (maxVal - minVal))
        end
    end
    track:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then
            isDragging = true
            UpdateFromCursor(self)
            self:SetScript("OnUpdate", UpdateFromCursor)
        end
    end)
    track:SetScript("OnMouseUp", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
        local r = RoundStep(getter() or minVal)
        isInit = true; self:SetValue(r); UpdateFill(r, r); isInit = false
    end)
    track:SetScript("OnHide", function(self) isDragging = false; self:SetScript("OnUpdate", nil) end)
    track:SetScript("OnEnter", function(self)
        UpdateFill(RoundStep(self:GetValue()), self:GetValue())
        if GameTooltip then
            local _, a = GetTheme()
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(string.format("|cFF%sLeft-Click / Drag:|r |cFFE2E8F0Adjust value|r", a.hex))
            GameTooltip:AddLine(string.format("|cFF%sMousewheel:|r |cFFE2E8F0Fine-tune by 1 step|r", a.hex))
            GameTooltip:Show()
        end
    end)
    track:SetScript("OnLeave", function(self)
        UpdateFill(RoundStep(self:GetValue()), self:GetValue())
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    track:SetScript("OnMouseWheel", function(self, delta)
        local r = RoundStep((getter() or minVal) + (delta > 0 and stepVal or -stepVal))
        self:SetValue(r)
    end)
    return card, -64
end

local function RefreshHostTelemetry()
    if _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
        pcall(_G.DynamicSuite.RefreshHeaderStatus)
    end
    if standaloneWindow and standaloneWindow.statusText and standaloneWindow:IsShown() then
        standaloneWindow.statusText:SetText(DynamicMail:GetStatusText())
    end
    RefreshInboxToolbarUI()
    RefreshSendPickerUI()
end

local function RenderMailEmbedded(parent)
    if not parent then return end
    RegisterMailPopupCloser()
    CloseAnyDropdown()
    local db = EnsureDB()
    local surf, acc = GetTheme()

    if parent.dmailRoot then
        parent.dmailRoot:Hide()
        parent.dmailRoot:SetParent(nil)
        parent.dmailRoot = nil
    end

    local root = CreateFrame("Frame", nil, parent)
    root:SetAllPoints(parent)
    parent.dmailRoot = root
    activeEmbeddedRoot = root
    root:SetScript("OnHide", CloseAnyDropdown)

    local tabBar = CreateFrame("Frame", nil, root, "BackdropTemplate")
    tabBar:SetHeight(34)
    tabBar:SetPoint("TOPLEFT", root, "TOPLEFT", 14, -10)
    tabBar:SetPoint("TOPRIGHT", root, "TOPRIGHT", -16, -10)
    ApplyBackdrop(tabBar, { 0.043, 0.051, 0.071, 0.98 }, { 1, 1, 1, 0.08 }) -- #0B0D12 bevel track

    local subTabs = {
        { id = 1, label = "Inbox & Automation" },
        { id = 2, label = "Sending & Alt Picker" },
        { id = 3, label = "History, Stats & Reset" },
    }
    local tabButtons = {}
    for idx, tInfo in ipairs(subTabs) do
        local tb = CreateFrame("Button", nil, tabBar, "BackdropTemplate")
        tb:SetHeight(26)
        local lbl = tb:CreateFontString(nil, "OVERLAY")
        SetFontSafe(lbl, 11, "")
        lbl:SetPoint("LEFT", tb, "LEFT", 6, 0)
        lbl:SetPoint("RIGHT", tb, "RIGHT", -6, 0)
        lbl:SetJustifyH("CENTER")
        lbl:SetWordWrap(false)
        lbl:SetText(tInfo.label)
        tb.label = lbl
        tb.subId = tInfo.id
        tb.hover = false
        tabButtons[idx] = tb
    end

    local scrollFrame = CreateFrame("ScrollFrame", nil, root)
    scrollFrame:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -8)
    scrollFrame:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", 0, -8)
    scrollFrame:SetPoint("BOTTOM", root, "BOTTOM", 0, 10)
    scrollFrame:EnableMouseWheel(true)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(760)
    scrollContent:SetHeight(1)
    scrollFrame:SetScrollChild(scrollContent)

    local function ReflowMailTabBar()
        local w = tabBar:GetWidth()
        if not w or w < 100 then
            w = (root:GetWidth() and root:GetWidth() > 100) and (root:GetWidth() - 30) or 760
        end
        local sfW = scrollFrame and scrollFrame:GetWidth()
        if sfW and sfW > 100 then
            scrollContent:SetWidth(sfW)
        elseif w > 100 then
            scrollContent:SetWidth(w)
        end
        local nTabs = math.max(1, #tabButtons)
        local totalGap = 4 * (nTabs + 1)
        local eachW = math.floor((w - totalGap) / nTabs)
        for idx, tb in ipairs(tabButtons) do
            tb:ClearAllPoints()
            tb:SetHeight(26)
            if idx == 1 then
                tb:SetPoint("LEFT", tabBar, "LEFT", 4, 0)
                tb:SetWidth(eachW)
            elseif idx < nTabs then
                tb:SetPoint("LEFT", tabButtons[idx - 1], "RIGHT", 4, 0)
                tb:SetWidth(eachW)
            else
                tb:SetPoint("LEFT", tabButtons[idx - 1], "RIGHT", 4, 0)
                tb:SetPoint("RIGHT", tabBar, "RIGHT", -4, 0)
            end
        end
    end
    tabBar:SetScript("OnSizeChanged", ReflowMailTabBar)
    tabBar:HookScript("OnShow", function() C_Timer.After(0, ReflowMailTabBar) end)
    ReflowMailTabBar()

    local track = CreateFrame("Frame", nil, root, "BackdropTemplate")
    track:SetWidth(4)
    track:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 10, -2)
    track:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 10, 2)
    track:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    track:SetBackdropColor(1, 1, 1, 0.05)

    local thumb = CreateFrame("Button", nil, track, "BackdropTemplate")
    thumb:SetWidth(4)
    thumb:SetHeight(48)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    thumbTex:SetAllPoints()
    thumbTex:SetColorTexture(0.45, 0.52, 0.64, 0.75)

    local function UpdateScrollbar()
        local viewH = scrollFrame:GetHeight() or 1
        local contH = scrollContent:GetHeight() or 1
        local maxS = math.max(0, contH - viewH)
        local curS = math.max(0, math.min(maxS, scrollFrame:GetVerticalScroll() or 0))
        local _, a = GetTheme()
        thumbTex:SetColorTexture((thumb.isDragging or thumb:IsMouseOver()) and a.r or 0.45, (thumb.isDragging or thumb:IsMouseOver()) and a.g or 0.52, (thumb.isDragging or thumb:IsMouseOver()) and a.b or 0.64, (thumb.isDragging or thumb:IsMouseOver()) and 0.95 or 0.75)
        if maxS <= 0 then thumb:Hide(); return end
        thumb:Show()
        local trackH = math.max(20, track:GetHeight() or 200)
        local thumbH = math.max(28, math.min(trackH, math.floor(trackH * (viewH / contH))))
        thumb:SetHeight(thumbH)
        local travel = math.max(1, trackH - thumbH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -(curS / maxS) * travel)
    end
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxS = math.max(0, (scrollContent:GetHeight() or 1) - (self:GetHeight() or 1))
        self:SetVerticalScroll(math.max(0, math.min(maxS, (self:GetVerticalScroll() or 0) - (delta * 38))))
        UpdateScrollbar()
    end)
    track:EnableMouse(true)
    track:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local _, cy = GetCursorPosition()
        cy = cy / (self:GetEffectiveScale() or 1)
        local pct = math.max(0, math.min(1, ((self:GetTop() or cy) - cy) / math.max(1, self:GetHeight() or 100)))
        local maxS = math.max(0, (scrollContent:GetHeight() or 1) - (scrollFrame:GetHeight() or 1))
        scrollFrame:SetVerticalScroll(pct * maxS)
        UpdateScrollbar()
    end)
    local function OnThumbUpdate(self)
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            self.isDragging = false; self:SetScript("OnUpdate", nil); UpdateScrollbar(); return
        end
        local _, cy = GetCursorPosition()
        cy = cy / (self:GetEffectiveScale() or 1)
        local maxS = math.max(0, (scrollContent:GetHeight() or 1) - (scrollFrame:GetHeight() or 1))
        local travel = math.max(1, (track:GetHeight() or 200) - (self:GetHeight() or 28))
        scrollFrame:SetVerticalScroll(math.max(0, math.min(maxS, (self.startScroll or 0) + (((self.startY or cy) - cy) / travel) * maxS)))
        UpdateScrollbar()
    end
    thumb:SetScript("OnEnter", UpdateScrollbar)
    thumb:SetScript("OnLeave", UpdateScrollbar)
    thumb:SetScript("OnMouseDown", function(self, btn)
        if btn ~= "LeftButton" then return end
        self.isDragging = true
        local _, cy = GetCursorPosition()
        self.startY = cy / (self:GetEffectiveScale() or 1)
        self.startScroll = scrollFrame:GetVerticalScroll() or 0
        UpdateScrollbar()
        self:SetScript("OnUpdate", OnThumbUpdate)
    end)
    thumb:SetScript("OnMouseUp", function(self) self.isDragging = false; self:SetScript("OnUpdate", nil); UpdateScrollbar() end)
    thumb:SetScript("OnHide", function(self) self.isDragging = false; self:SetScript("OnUpdate", nil) end)
    scrollFrame:SetScript("OnSizeChanged", function(_, w)
        if w and w > 80 then scrollContent:SetWidth(w) end
        UpdateScrollbar()
    end)

    local function RefreshTabVisuals()
        local _, a = GetTheme()
        local fillA = ((_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42)
        for _, tb in ipairs(tabButtons) do
            if db.activeSubTab == tb.subId then
                ApplyBackdrop(tb, { a.r * fillA, a.g * fillA, a.b * fillA, 0.98 }, { a.r, a.g, a.b, 0.95 })
                tb.label:SetTextColor(1, 1, 1, 1)
            elseif tb.hover then
                ApplyBackdrop(tb, { 0.105, 0.122, 0.165, 0.98 }, { a.r, a.g, a.b, 0.75 })
                tb.label:SetTextColor(0.95, 0.97, 1.0, 1)
            else
                ApplyBackdrop(tb, { 0.078, 0.090, 0.122, 0.96 }, { 0.145, 0.165, 0.212, 0.95 })
                tb.label:SetTextColor(0.68, 0.74, 0.82, 1)
            end
        end
    end

    local function PopulateActiveTab()
        local children = { scrollContent:GetChildren() }
        for _, ch in ipairs(children) do ch:Hide(); ch:SetParent(nil) end

        local tabId = db.activeSubTab or 1
        local y = 0

        local liveBar = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
        liveBar:SetHeight(28)
        liveBar:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, y)
        liveBar:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, y)
        ApplyBackdrop(liveBar, { 0.065, 0.075, 0.100, 0.96 }, surf.border)
        local liveText = liveBar:CreateFontString(nil, "OVERLAY")
        SetFontSafe(liveText, 11, "")
        liveText:SetPoint("LEFT", liveBar, "LEFT", 12, 0)
        liveText:SetPoint("RIGHT", liveBar, "RIGHT", -12, 0)
        liveText:SetJustifyH("LEFT")
        liveText:SetWordWrap(false)
        liveText:SetTextColor(0.88, 0.93, 1.0, 1.0)
        liveText:SetText(DynamicMail:GetStatusText())
        y = y - 36

        if tabId == 1 then
            local sec1 = CreateSectionBox(scrollContent, y)
            local sy = -10
            local _, dy = CreateSectionHeader(sec1, sy, "INBOX COLLECTION & BAG SAFETY", "Fast 1-click Open All, AH Gold, and Items Only with strict COD & free-slot protection.")
            sy = sy + dy

            local _, dy1 = CreateSegmentedSwitchCard(sec1, sy, "Mailbox Quick Action Bar",
                "Show Open All, AH Gold, and Items Only buttons cleanly above the Mailbox window (or below if at screen top).",
                function() return db.mailboxBarEnabled end,
                function(v) db.mailboxBarEnabled = v; RefreshHostTelemetry() end, false)
            sy = sy + dy1

            local _, dy2 = CreateMultiPillCard(sec1, sy, "Collection Speed",
                "Delay between automated inbox takes (Balanced 0.14s works reliably on busy realms).",
                {
                    { value = 0.08, label = "Fast 0.08s" },
                    { value = 0.14, label = "Balanced 0.14s" },
                    { value = 0.25, label = "Safe 0.25s" },
                },
                function() return db.openInterval end,
                function(v) db.openInterval = v end)
            sy = sy + dy2

            local _, dy3 = CreateSliderCard(sec1, sy, "Free Bag Slots to Keep Open",
                "Pause looting mail items when free general bag slots reach this reserve (0 to 8).",
                0, 8, 1, function(v) return string.format("%d slot%s", v, v == 1 and "" or "s") end,
                function() return db.keepFreeBagSlots end,
                function(v) db.keepFreeBagSlots = v; RefreshHostTelemetry() end)
            sy = sy + dy3

            local _, dy4 = CreateSegmentedSwitchCard(sec1, sy, "Collect Gold When Bags Are Full",
                "Continue looting pure-gold and AH payout mails even after bags reach your free-slot reserve.",
                function() return db.collectGoldWhenBagsFull end,
                function(v) db.collectGoldWhenBagsFull = v end, false)
            sy = sy + dy4

            local _, dy5 = CreateSegmentedSwitchCard(sec1, sy, "Include Non-Auction Gold in [AH Gold]",
                "Also collect direct player-to-player gold mails (non-COD) when clicking AH Gold.",
                function() return db.ahIncludeAllNonCodGold end,
                function(v) db.ahIncludeAllNonCodGold = v end, false)
            sy = sy + dy5

            local sec1H = math.abs(sy) + 8
            sec1:SetHeight(sec1H)
            y = y - (sec1H + 10)

            local sec2 = CreateSectionBox(scrollContent, y)
            local sy2 = -10
            local _, dy2h = CreateSectionHeader(sec2, sy2, "NOTIFICATIONS & CLEANUP", "Summary chat alerts and optional automatic deletion of empty mail receipts.")
            sy2 = sy2 + dy2h

            local _, dy6 = CreateSegmentedSwitchCard(sec2, sy2, "Chat Batch Summary with Coin Icons",
                "Print total items collected and Gold/Silver/Copper earned when a pass finishes.",
                function() return db.printBatchSummary end,
                function(v) db.printBatchSummary = v end, false)
            sy2 = sy2 + dy6

            local _, dy7 = CreateSegmentedSwitchCard(sec2, sy2, "Play Subtle Sound on Batch Finish",
                "Play a crisp confirmation sound when inbox collection completes.",
                function() return db.playFinishSound end,
                function(v) db.playFinishSound = v end, false)
            sy2 = sy2 + dy7

            local _, dy8 = CreateSegmentedSwitchCard(sec2, sy2, "Auto-Delete Empty Letters on Open All",
                "Automatically delete empty text-only letters (NPC Lost Currency, Postmaster, Auction receipts, and read/unread notices with zero gold and zero items) during Open All. Never deletes COD, items, gold, or GM mail.",
                function() return db.deleteEmptyLetters end,
                function(v) db.deleteEmptyLetters = v; db.deleteEmptySystemMail = v end, false)
            sy2 = sy2 + dy8

            local _, dy9 = CreateSegmentedSwitchCard(sec2, sy2, "Shift-Click Inbox Row to Quick-Loot",
                "Hold Shift and Left-Click any non-COD inbox letter to loot its gold or items without opening it.",
                function() return db.shiftClickInboxLoot end,
                function(v) db.shiftClickInboxLoot = v end, false)
            sy2 = sy2 + dy9

            local _, dy10 = CreateSegmentedSwitchCard(sec2, sy2, "Warn on Expiring Mail (< 3 Days Left)",
                "Highlight expiring mails in the Mailbox Quick Action Bar when fewer than 3 days remain.",
                function() return db.warnExpiringMail end,
                function(v) db.warnExpiringMail = v; RefreshInboxToolbarUI() end, false)
            sy2 = sy2 + dy10

            local sec2H = math.abs(sy2) + 8
            sec2:SetHeight(sec2H)
            y = y - (sec2H + 10)

        elseif tabId == 2 then
            local sec1 = CreateSectionBox(scrollContent, y)
            local sy = -10
            local _, dyh = CreateSectionHeader(sec1, sy, "ALT VAULT & RECIPIENT SIDE PANEL", "1-click class-coloured Alts, Recent targets, Guildmates, and Friends beside Send Mail.")
            sy = sy + dyh

            local _, dy1 = CreateSegmentedSwitchCard(sec1, sy, "Show Recipient Picker Beside Send Mail",
                "Dock the 4-tab Recipient Picker (Alts / Recent / Guild / Friends) cleanly next to the Mailbox window.",
                function() return db.recipientPanelEnabled end,
                function(v) db.recipientPanelEnabled = v; RefreshHostTelemetry() end, false)
            sy = sy + dy1

            local _, dy2 = CreateSegmentedSwitchCard(sec1, sy, "Sync Account Alts from DynamicBags Vault",
                "Automatically populate all alts already scanned in DynamicBags Alt Vault with class colours and gold.",
                function() return db.syncDynamicBagsVault end,
                function(v) db.syncDynamicBagsVault = v; RefreshSendPickerUI() end, false)
            sy = sy + dy2

            local _, dy3 = CreateSegmentedSwitchCard(sec1, sy, "Show Alt Gold Balances in Picker",
                "Display each character's last cached gold beneath their name in the Alts list.",
                function() return db.showAltGold end,
                function(v) db.showAltGold = v; RefreshSendPickerUI() end, false)
            sy = sy + dy3

            local _, dy4 = CreateSegmentedSwitchCard(sec1, sy, "Sort Starred Favourites First & Remember Recent",
                "Pin Favourite characters at the top and auto-save recent recipients after every sent mail.",
                function() return db.sortFavouritesFirst end,
                function(v) db.sortFavouritesFirst = v; db.rememberRecent = v; RefreshSendPickerUI() end, false)
            sy = sy + dy4

            local _, dy5 = CreateSliderCard(sec1, sy, "Recent Recipients Kept",
                "Maximum number of recently mailed characters kept in the Recent tab (10 to 50).",
                10, 50, 5, function(v) return tostring(v) end,
                function() return db.recentLimit end,
                function(v) db.recentLimit = v end)
            sy = sy + dy5

            local sec1H = math.abs(sy) + 8
            sec1:SetHeight(sec1H)
            y = y - (sec1H + 10)

            local sec2 = CreateSectionBox(scrollContent, y)
            local sy2 = -10
            local _, dy2h = CreateSectionHeader(sec2, sy2, "QUICK SENDING & ATTACHMENTS", "Streamline mailing reagents, Warband gear, and crafting orders to alts.")
            sy2 = sy2 + dy2h

            local _, dy6 = CreateSegmentedSwitchCard(sec2, sy2, "Alt + Left-Click Bag Item to Attach",
                "Quickly attach items from DynamicBags or Blizzard bags directly into Send Mail slots (up to 12).",
                function() return db.altClickAttach end,
                function(v) db.altClickAttach = v; RefreshHostTelemetry() end, false)
            sy2 = sy2 + dy6

            local _, dy7 = CreateSegmentedSwitchCard(sec2, sy2, "Auto-Fill Subject on Empty Subject",
                "Automatically fill the Subject box with the first attached item's name when left blank.",
                function() return db.autoFillSubject end,
                function(v) db.autoFillSubject = v end, false)
            sy2 = sy2 + dy7

            local _, dy8 = CreateSegmentedSwitchCard(sec2, sy2, "Open Bags Automatically at Mailbox",
                "Automatically show your bags when interacting with any mailbox out of combat.",
                function() return db.autoOpenBagsAtMail end,
                function(v) db.autoOpenBagsAtMail = v end, false)
            sy2 = sy2 + dy8

            local _, dy9 = CreateSegmentedSwitchCard(sec2, sy2, "Quick-Attach Preset Buttons",
                "Display 1-click batch attachment preset buttons (+ Mats / BoE / Warband / Same) in the Send Mail Recipient Picker.",
                function() return db.showQuickAttachBar end,
                function(v) db.showQuickAttachBar = v; RefreshSendPickerUI() end, false)
            sy2 = sy2 + dy9

            local _, dy10 = CreateSegmentedSwitchCard(sec2, sy2, "Quick-Gold Buttons",
                "Display 1-click gold increment buttons (+1k / +10k / +100k / Reset) in the Send Mail Recipient Picker.",
                function() return db.showQuickGoldBar end,
                function(v) db.showQuickGoldBar = v; RefreshSendPickerUI() end, false)
            sy2 = sy2 + dy10

            local _, dy11 = CreateSegmentedSwitchCard(sec2, sy2, "Pending Alt Badges & Last Recipient",
                "Badge alts after sending them gold or items (clears when that alt opens mail) and restore last target.",
                function() return db.showPendingAltBadge end,
                function(v) db.showPendingAltBadge = v; db.restoreLastRecipient = v; RefreshSendPickerUI() end, false)
            sy2 = sy2 + dy11

            local sec2H = math.abs(sy2) + 8
            sec2:SetHeight(sec2H)
            y = y - (sec2H + 10)

        else -- tabId == 3
            local sec1 = CreateSectionBox(scrollContent, y)
            local sy = -10
            local _, dyh = CreateSectionHeader(sec1, sy, "MAILBOX LIFETIME STATS & ACTIVITY LOG", "Session and account-wide gold collected, items looted, and recent mail history.")
            sy = sy + dyh

            local statCard = CreateCard(sec1, 58, sy, false)
            local statFS = statCard:CreateFontString(nil, "OVERLAY")
            SetFontSafe(statFS, 11, "")
            statFS:SetPoint("LEFT", statCard, "LEFT", 14, 0)
            statFS:SetPoint("RIGHT", statCard, "RIGHT", -14, 0)
            statFS:SetJustifyH("LEFT")
            statFS:SetJustifyV("MIDDLE")
            statFS:SetWordWrap(true)
            if statFS.SetMaxLines then statFS:SetMaxLines(2) end
            statFS:SetTextColor(0.90, 0.94, 0.99, 1)
            local st = db.stats or {}
            statFS:SetText(string.format("Gold Looted: %s    |    Items Collected: |cFFFFFFFF%d|r    |    Batches: |cFFFFFFFF%d|r    |    Sent: |cFFFFFFFF%d|r",
                FormatCopper(st.totalCopperLooted or 0), SafeNum(st.totalItemsLooted, 0), SafeNum(st.totalMailsLooted, 0), SafeNum(st.totalMailsSent, 0)))
            sy = sy - 64

            local logs = db.historyLog or {}
            local logCardH = math.max(64, math.min(240, 18 + (#logs * 22)))
            local logCard = CreateCard(sec1, logCardH, sy, false)
            if #logs == 0 then
                local emptyFS = logCard:CreateFontString(nil, "OVERLAY")
                SetFontSafe(emptyFS, 10.5, "")
                emptyFS:SetPoint("CENTER")
                emptyFS:SetTextColor(0.55, 0.62, 0.72, 1)
                emptyFS:SetText("No mail activity recorded yet. Visit any mailbox to get started.")
            else
                local ly = -10
                for idx = 1, math.min(#logs, 10) do
                    local item = logs[idx]
                    local rowFS = logCard:CreateFontString(nil, "OVERLAY")
                    SetFontSafe(rowFS, 10.5, "")
                    rowFS:SetPoint("TOPLEFT", logCard, "TOPLEFT", 12, ly)
                    rowFS:SetPoint("TOPRIGHT", logCard, "TOPRIGHT", -12, ly)
                    rowFS:SetJustifyH("LEFT")
                    rowFS:SetWordWrap(false)
                    local badgeHex = (item.kind == "SENT") and "38BDF8" or "22C55E"
                    local cStr = (SafeNum(item.copper, 0) > 0) and ("  (" .. FormatCopper(item.copper) .. ")") or ""
                    rowFS:SetText(string.format("|cFF64748B[%s %s]|r  |cFF%s[%s]|r  |cFFE2E8F0%s|r%s",
                        SafeStr(item.dayStr, ""), SafeStr(item.timeStr, ""), badgeHex, SafeStr(item.kind, "MAIL"), SafeStr(item.summary, ""), cStr))
                    ly = ly - 21
                end
            end
            sy = sy - (logCardH + 8)

            local clearLogBtn = CreateStyledButton(sec1, "Clear Activity Log", 150, 24, false, function()
                EnsureDB().historyLog = {}
                PopulateActiveTab()
                Print("Activity log cleared.")
            end)
            clearLogBtn:SetPoint("TOPLEFT", sec1, "TOPLEFT", 14, sy)
            sy = sy - 32

            local sec1H = math.abs(sy) + 8
            sec1:SetHeight(sec1H)
            y = y - (sec1H + 10)

            local sec2 = CreateSectionBox(scrollContent, y)
            local sy2 = -10
            local _, dy2h = CreateSectionHeader(sec2, sy2, "MODULE DEFAULTS & MAINTENANCE", "Restore default DynamicMail settings while keeping your alt roster intact.")
            sy2 = sy2 + dy2h

            local rstBtn = CreateStyledButton(sec2, "Reset DynamicMail Defaults", 190, 26, false, function()
                DynamicMail:ResetModuleDefaults()
            end)
            rstBtn:SetPoint("TOPLEFT", sec2, "TOPLEFT", 14, sy2)
            sy2 = sy2 - 36

            local sec2H = math.abs(sy2) + 8
            sec2:SetHeight(sec2H)
            y = y - (sec2H + 10)
        end

        scrollContent:SetHeight(math.max(100, math.abs(y) + 12))
        scrollFrame:SetVerticalScroll(0)
        UpdateScrollbar()
    end

    for _, tb in ipairs(tabButtons) do
        tb:SetScript("OnEnter", function(self)
            self.hover = true
            RefreshTabVisuals()
        end)
        tb:SetScript("OnLeave", function(self)
            self.hover = false
            RefreshTabVisuals()
        end)
        tb:SetScript("OnClick", function()
            CloseAnyDropdown()
            db.activeSubTab = tb.subId
            RefreshTabVisuals()
            PopulateActiveTab()
        end)
    end

    DynamicMail.SelectSubTab = function(selfOrIdx, maybeIdx)
        local idx = (type(selfOrIdx) == "number") and selfOrIdx or maybeIdx or 1
        db.activeSubTab = idx
        RefreshTabVisuals()
        PopulateActiveTab()
    end
    DynamicMail.SelectTab = DynamicMail.SelectSubTab

    RefreshTabVisuals()
    PopulateActiveTab()

    C_Timer.After(0, function()
        ReflowMailTabBar()
        UpdateScrollbar()
    end)
end

local function EnsureStandaloneWindow()
    if standaloneWindow then return standaloneWindow end
    local surf = GetTheme()
    local win = CreateFrame("Frame", "DynamicMailStandaloneWindow", UIParent, "BackdropTemplate")
    win:SetSize(880, 600)
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    win:SetFrameStrata("HIGH")
    win:SetMovable(true)
    win:SetResizable(true)
    if win.SetResizeBounds then win:SetResizeBounds(760, 480, 1280, 860) end
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    win:SetScript("OnHide", CloseAnyDropdown)
    ApplyBackdrop(win, surf.bg, surf.border)
    if type(UISpecialFrames) == "table" then
        local exists = false
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == "DynamicMailStandaloneWindow" then exists = true; break end
        end
        if not exists then table.insert(UISpecialFrames, "DynamicMailStandaloneWindow") end
    end

    local header = CreateFrame("Frame", nil, win, "BackdropTemplate")
    header:SetPoint("TOPLEFT", win, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", win, "TOPRIGHT", -1, -1)
    header:SetHeight(44)
    ApplyBackdrop(header, surf.header, surf.border)

    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(26, 26)
    logo:SetPoint("LEFT", header, "LEFT", 14, 0)
    logo:SetTexture(ICON_COLOR)

    local brandTitle = header:CreateFontString(nil, "OVERLAY")
    SetFontSafe(brandTitle, 15, "")
    brandTitle:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    brandTitle:SetWordWrap(false)
    brandTitle:SetText("|cFFCBD5E1Dynamic|r|cFFFFFFFFMail|r  |cFF64748Bv" .. VERSION .. "|r")

    local closeBtn = CreateStyledButton(header, "X", 28, 24, false, function()
        CloseAnyDropdown()
        win:Hide()
    end)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -10, 0)

    local statusText = header:CreateFontString(nil, "OVERLAY")
    SetFontSafe(statusText, 11, "")
    statusText:SetPoint("LEFT", brandTitle, "RIGHT", 14, 0)
    statusText:SetPoint("RIGHT", closeBtn, "LEFT", -12, 0)
    statusText:SetJustifyH("RIGHT")
    statusText:SetWordWrap(false)
    statusText:SetTextColor(0.75, 0.82, 0.90, 1.0)
    statusText:SetText(DynamicMail:GetStatusText())
    win.statusText = statusText

    local footer = CreateFrame("Frame", nil, win, "BackdropTemplate")
    footer:SetHeight(36)
    footer:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 1, 1)
    footer:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -1, 1)
    ApplyBackdrop(footer, surf.header, surf.border)

    local resetBtn = CreateStyledButton(footer, "Reset DynamicMail", 150, 24, false, function()
        DynamicMail:ResetModuleDefaults()
    end)
    resetBtn:SetPoint("LEFT", footer, "LEFT", 14, 0)

    local reloadBtn = CreateStyledButton(footer, "Reload UI", 96, 24, false, function()
        if type(ReloadUI) == "function" then ReloadUI() end
    end)
    reloadBtn:SetPoint("RIGHT", footer, "RIGHT", -32, 0)

    local body = CreateFrame("Frame", nil, win)
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 6, -6)
    body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", -6, 4)
    win.body = body

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
    grip:SetScript("OnMouseDown", function(_, mBtn) if mBtn == "LeftButton" then win:StartSizing("BOTTOMRIGHT") end end)
    grip:SetScript("OnMouseUp", function() win:StopMovingOrSizing() end)

    standaloneWindow = win
    return win
end

function DynamicMail:ResetModuleDefaults()
    local cur = _G.DynamicMailDB
    local preservedChars = (type(cur) == "table" and type(cur.knownChars) == "table") and cur.knownChars or {}
    local preservedFavs  = (type(cur) == "table" and type(cur.favourites) == "table") and cur.favourites or {}
    _G.DynamicMailDB = {}
    local db = EnsureDB()
    db.knownChars = preservedChars
    db.favourites = preservedFavs
    if activeEmbeddedRoot and activeEmbeddedRoot:GetParent() and activeEmbeddedRoot:IsShown() then
        RenderMailEmbedded(activeEmbeddedRoot:GetParent())
    end
    RefreshHostTelemetry()
    Print("Module settings restored to defaults.")
end

local function OpenMailWorkspace()
    if not IsModuleDisabledInSuite("DynamicMail") then
        if _G.DynamicSuite and type(_G.DynamicSuite.OpenModule) == "function" then
            local ok = pcall(_G.DynamicSuite.OpenModule, _G.DynamicSuite, "DynamicMail")
            if ok then return end
        end
        if _G.DynamicLoadUI and type(_G.DynamicLoadUI.OpenToModule) == "function" then
            local ok = pcall(_G.DynamicLoadUI.OpenToModule, "DynamicMail")
            if ok then return end
        end
    end
    local win = EnsureStandaloneWindow()
    win:Show()
    win:Raise()
    win.statusText:SetText(DynamicMail:GetStatusText())
    RenderMailEmbedded(win.body)
end

function DynamicMail:TeardownDisabledState()
    StopBatchCollection(nil, true)
    if inboxBar then inboxBar:Hide() end
    if sendPanel then sendPanel:Hide() end
end

DynamicMail.RenderEmbedded      = function(self, parent) return RenderMailEmbedded(parent or self) end
DynamicMail.ApplyTheme          = function()
    if RefreshInboxToolbarUI then RefreshInboxToolbarUI() end
    if RefreshSendPickerUI then RefreshSendPickerUI() end
    if activeEmbeddedRoot and activeEmbeddedRoot:GetParent() and activeEmbeddedRoot:IsShown() then
        RenderMailEmbedded(activeEmbeddedRoot:GetParent())
    end
    RefreshHostTelemetry()
end
DynamicMail.ApplyThemeToUI      = DynamicMail.ApplyTheme
DynamicMail.ResetDefaults       = function() return DynamicMail:ResetModuleDefaults() end
DynamicMail.ResetModule         = function() return DynamicMail:ResetModuleDefaults() end
DynamicMail.Reset               = function() return DynamicMail:ResetModuleDefaults() end
DynamicMail.Open                = function() return OpenMailWorkspace() end

-- ============================================================================
-- 9. DYNAMICSUITE REGISTRATION, SEARCH ENTRIES & CHANGELOG
-- ============================================================================
DynamicMail.SEARCH_ENTRIES = {
    { moduleKey = "mail", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Inbox & Automation",
      title = "Mailbox Quick Action Bar",
      desc = "Show 1-click Open All, AH Gold, and Items Only buttons docked cleanly above the Blizzard Mailbox window (flipping below only near the top of the screen).",
      keywords = "mail mailbox inbox open all ah gold attachments bar" },
    { moduleKey = "mail", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Inbox & Automation",
      title = "Free Bag Slots to Keep Open",
      desc = "Automatically pause looting mail items when free general bag slots drop to your saved reserve.",
      keywords = "mail free bag slots reserve pause full bags guard" },
    { moduleKey = "mail", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Inbox & Automation",
      title = "Collect Gold When Bags Are Full",
      desc = "Continue collecting Auction House payouts and non-COD gold even when bags are at reserve.",
      keywords = "mail gold auction house ah payout bags full" },
    { moduleKey = "mail", category = "BAGS_QOL", tabIndex = 2, tabLabel = "Sending & Alt Picker",
      title = "Show Recipient Picker Beside Send Mail",
      desc = "Display the 4-tab Obsidian Recipient Picker (Alts, Recent, Guild, Friends) next to Send Mail.",
      keywords = "mail recipient alt picker vault guild friends warband" },
    { moduleKey = "mail", category = "BAGS_QOL", tabIndex = 2, tabLabel = "Sending & Alt Picker",
      title = "Sync Account Alts from DynamicBags Vault",
      desc = "Populate class-coloured alts and gold balances directly from DynamicBags Alt Vault character snapshots.",
      keywords = "mail sync alt vault dynamicbags character gold" },
    { moduleKey = "mail", category = "BAGS_QOL", tabIndex = 2, tabLabel = "Sending & Alt Picker",
      title = "Alt + Left-Click Bag Item to Attach",
      desc = "Quickly attach bag items directly into Send Mail slots with Alt + Left-Click.",
      keywords = "mail express attach alt left click bags send item" },
    { moduleKey = "mail", category = "BAGS_QOL", tabIndex = 2, tabLabel = "Sending & Alt Picker",
      title = "Quick-Attach Preset Buttons",
      desc = "Fill up to 12 Send Mail attachment slots with reagents, BoE gear, Warbound items, or matching stacks in 1 click.",
      keywords = "mail quick attach mats boe warbound same reagent stacks bulk" },
    { moduleKey = "mail", category = "BAGS_QOL", tabIndex = 1, tabLabel = "Inbox & Automation",
      title = "Shift-Click Inbox Row & Expiring Mail Alerts",
      desc = "Shift + Left-Click inbox rows to loot instantly and highlight mails with fewer than 3 days remaining.",
      keywords = "mail shift click quick loot expiring alert days left" },
    { moduleKey = "mail", category = "BAGS_QOL", tabIndex = 3, tabLabel = "History, Stats & Reset",
      title = "Mailbox Lifetime Stats & Activity Log",
      desc = "View lifetime gold looted, items collected, sent mail counts, and recent mailbox history.",
      keywords = "mail history log gold looted stats telemetry reset" },
}

DynamicMail.CHANGELOG = {
    {
        version = VERSION,
        date = "25/11/2026",
        entries = {
            { type = "UI", text = "Release v2.10.2 - Pass 6 800x520 Clamping & Plain-English Copy Hygiene (25/11/2026): Clamped the standalone header status readout cleanly between brandTitle and closeBtn; right-clamped section headers, multi-pill cards, and slider titles against their controls; enabled 2-line wrapping on Tab 3's Lifetime Stats summary card; shortened long Tab 2 switch labels; and replaced raw internal names ('MailFrame', 'DynamicBagsDB', 'Sending QoL', 'Open & Del', 'Clear G') with plain Australian English ('the Mailbox window', 'DynamicBags Alt Vault', 'Quick Sending & Attachments', 'Clear Empty', and 'Reset')." },
            { type = "UI", text = "Release v2.7.0 (21/11/2026): Standardised binary Off/Enabled switches to 68px Off / 84px Enabled (156x26px) and clamped card titles directly to the left of right-hand switches for clean 800x520 framing." },
            { type = "FIX", text = "Release v2.6.9 (21/11/2026): Guarded suite window routing when DynamicMail is disabled inside DynamicSuite, aligned the standalone resize handle with the active Suite Accent, updated Quick Action Bar search copy, and standardised the module changelog structure." },
            { type = "NEW", text = "Auto-Delete Empty Letters & 1-Click Clear Empty Button (19/11/2026): Added the 'Auto-Delete Empty Letters on Open All' option (enabled by default) and a dedicated 1-click [Clear Empty] button on DynamicMailInboxBar to wipe empty NPC notices (Lost Currency, Postmaster), Auction receipts, and zero-gold/zero-item letters without opening each one manually, while always protecting COD, items, gold, and GM mail." },
            { type = "UI", text = "Suite-Matched 3-Tab Top Bar & 4px Scrollbar Alignment (18/11/2026): Updated the /dmail and /ds workspace top 3-tab bevel bar (14/-16px margins, #0B0D12 container, #14171F inactive card fill and #252A36 borders with hover highlight, equal-width 4px-gapped tab sizing, -8px direct scroll-area anchor, and 4px Obsidian scrollbar track) to match DynamicSuite, DynamicBags, and DynamicChat 1:1." },
            { type = "FIX", text = "Top-Docked Inbox Bar, Left Suite Rail Entry, Express Alt+Click & External UI Coexistence (18/11/2026): Registered 'mail' in DynamicSuite's Left Suite Rail order; moved DynamicMailInboxBar cleanly above MailFrame so bottom inbox/send tabs never cover it; fixed Alt + Left-Click attaching across both DynamicBags and Blizzard bags regardless of ActionButtonUseKeyDown or cursor lock state; and auto-docked DynamicMailSendPickerPanel cleanly away from external alt lists." },
            { type = "NEW", text = "Smart Bulk-Attach Presets, Quick Gold & Pending Alt Mail Tracking (18/11/2026): Added 1-click Quick-Attach preset buttons ([+ Mats], [+ BoE], [+ Warband], [+ Same]) with Equipment Manager & Soulbound protection; [+1k g] / [+10k g] / [+100k] / [Clear G] Quick-Gold buttons; Pending Alt Mail Sent badges in the Alts picker (auto-clearing when that alt visits a mailbox); Shift + Left-Click inbox row quick-loot; and Expiring (<3d) mailbox alerts." },
            { type = "NEW", text = "Initial v2.4.0 Release (18/11/2026): Added DynamicMail (/dmail, /dynamicmail) with 1-click Inbox Open All, AH Gold, and Items Only collection; automatic COD and bag-reserve protection; 4-tab Recipient Picker (Alts synced from DynamicBags Vault with class colours & gold, Recent, Guild, and Friends with Favourite pinning); Alt + Left-Click Express Multi-Attach from bags; auto-subject fill; lifetime gold & item totals; and full DynamicSuite + standalone compatibility." },
        },
    },
}

local function RegisterWithDynamicSuite()
    _G.DynamicSuite = _G.DynamicSuite or {}
    _G.DynamicSuite.modules = _G.DynamicSuite.modules or {}

    local registration = {
        id = "mail",
        key = "DynamicMail",
        name = "DynamicMail",
        title = "DynamicMail",
        subtitle = "Inbox, Alts & Gold Mail",
        version = VERSION,
        order = 75,
        icon = ICON_COLOR,
        fallbackIcon = ICON_COLOR,
        iconWhite = ICON_WHITE,
        iconAccent = ICON_ACCENT,
        slash = "/dmail",
        category = "Mailbox Automation, Alt Picker & Express Attach",
        desc = "1-click Open All, AH Gold, and Items Only mailbox collection, DynamicBags Alt Vault recipient picker, and Alt+Left-Click bag attach.",
        conflictRegistry = {
            conflicts        = { "Postal", "EasyMail", "CT_MailMod", "InboxMailBag", "MailCommander" },
            hardConflicts    = { "Postal", "EasyMail", "CT_MailMod", "InboxMailBag", "MailCommander" },
            partialConflicts = { "TradeSkillMaster", "Leatrix_Plus", "EnhanceQoL", "ElvUI" },
            softConflicts    = { "TradeSkillMaster", "Leatrix_Plus", "EnhanceQoL", "ElvUI" },
            category         = "Mailbox & Auction Gold",
        },
        GetStatusText = function() return DynamicMail:GetStatusText() end,
        RenderEmbedded = function(a, b)
            local parent = (type(a) == "table" and a.CreateFrame == nil and b) and b or a
            return RenderMailEmbedded(parent)
        end,
        Render = function(a, b)
            local parent = (type(a) == "table" and a.CreateFrame == nil and b) and b or a
            return RenderMailEmbedded(parent)
        end,
        ApplyTheme          = DynamicMail.ApplyTheme,
        ResetDefaults       = function() DynamicMail:ResetModuleDefaults() end,
        ResetModuleDefaults = function() DynamicMail:ResetModuleDefaults() end,
        ResetModule         = function() DynamicMail:ResetModuleDefaults() end,
        Reset               = function() DynamicMail:ResetModuleDefaults() end,
        Open                = OpenMailWorkspace,
        OnDisableInSuite    = function() DynamicMail:TeardownDisabledState() end,
        OnEnableInSuite     = function() RefreshHostTelemetry() end,
        SelectSubTab        = function(a1, a2) DynamicMail:SelectSubTab(a1, a2) end,
        SelectTab           = function(a1, a2) DynamicMail:SelectSubTab(a1, a2) end,
        searchEntries       = DynamicMail.SEARCH_ENTRIES,
        SEARCH_ENTRIES      = DynamicMail.SEARCH_ENTRIES,
        CHANGELOG           = DynamicMail.CHANGELOG,
    }

    _G.DynamicSuite.modules["mail"] = registration
    _G.DynamicSuite.modules["DynamicMail"] = registration
    _G.DynamicSuite.Changelogs = _G.DynamicSuite.Changelogs or {}
    _G.DynamicSuite.Changelogs["DynamicMail"] = DynamicMail.CHANGELOG
    _G.DynamicSuite.Changelogs["mail"] = DynamicMail.CHANGELOG
    if type(_G.DynamicSuite.RegisterModule) == "function" then
        pcall(_G.DynamicSuite.RegisterModule, _G.DynamicSuite, "mail", registration)
    end
end

RegisterWithDynamicSuite()

function _G.DynamicMail_OnAddonCompartmentClick()
    OpenMailWorkspace()
end

-- ============================================================================
-- 10. EVENT LOOP & SLASH COMMANDS (/dmail, /dynamicmail)
-- ============================================================================
DynamicMail:RegisterEvent("ADDON_LOADED")
DynamicMail:RegisterEvent("PLAYER_LOGIN")
DynamicMail:RegisterEvent("PLAYER_MONEY")
DynamicMail:RegisterEvent("MAIL_SHOW")
DynamicMail:RegisterEvent("MAIL_INBOX_UPDATE")
DynamicMail:RegisterEvent("MAIL_CLOSED")
DynamicMail:RegisterEvent("MAIL_SEND_SUCCESS")
DynamicMail:RegisterEvent("MAIL_FAILED")
DynamicMail:RegisterEvent("BAG_UPDATE_DELAYED")
DynamicMail:RegisterEvent("PLAYER_REGEN_DISABLED")

DynamicMail:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_FOLDER or arg1 == "DynamicSuite" or arg1 == "DynamicMail" then
            if not isInitialized then
                isInitialized = true
                EnsureDB()
                RegisterWithDynamicSuite()
            end
        end
        if arg1 == "EllesmereUIBlizzardSkin" or arg1 == "EllesmereUI" then
            EnsureEllesmereSkinRegistered()
        end
        if arg1 == "Blizzard_MailFrame" then
            InstallMailboxHooks()
        end
    elseif event == "PLAYER_LOGIN" then
        EnsureDB()
        RecordCurrentCharacterSnapshot()
        EnsureEllesmereSkinRegistered()
        InstallMailboxHooks()
        RegisterWithDynamicSuite()
    elseif event == "PLAYER_MONEY" then
        RecordCurrentCharacterSnapshot()
    elseif event == "MAIL_SHOW" then
        EnsureEllesmereSkinRegistered()
        RecordCurrentCharacterSnapshot()
        InstallMailboxHooks()
        local db = EnsureDB()
        local _, pName, pRealm = GetPlayerKeyAndParts()
        local myNormKey = (pName .. "-" .. NormalizeRealmNoSpace(pRealm)):lower()
        if type(db.sentWatch) == "table" and db.sentWatch[myNormKey] then
            db.sentWatch[myNormKey] = nil
        end
        if not IsModuleDisabledInSuite("DynamicMail") and db.enabled then
            if db.autoOpenBagsAtMail and not InCombatLockdown() and type(OpenAllBags) == "function" then
                pcall(OpenAllBags)
            end
            C_Timer.After(0.05, function()
                RefreshInboxToolbarUI()
                RefreshSendPickerUI()
            end)
            C_Timer.After(0.18, function()
                if _G.MailFrame and _G.MailFrame:IsShown() then
                    RefreshInboxToolbarUI()
                    RefreshSendPickerUI()
                end
            end)
        end
    elseif event == "MAIL_INBOX_UPDATE" then
        if _G.MailFrame and _G.MailFrame:IsShown() then
            RefreshInboxToolbarUI()
        end
    elseif event == "MAIL_CLOSED" then
        StopBatchCollection(nil, true)
        if inboxBar then inboxBar:Hide() end
        if sendPanel then sendPanel:Hide() end
    elseif event == "MAIL_SEND_SUCCESS" then
        if pendingSentRecord then
            RecordSentMailTarget(pendingSentRecord.target, pendingSentRecord.subject, pendingSentRecord.money, pendingSentRecord.attachCount)
            pendingSentRecord = nil
        end
        RecordCurrentCharacterSnapshot()
        C_Timer.After(0.05, function()
            if RefreshSendPickerUI then RefreshSendPickerUI() end
        end)
    elseif event == "MAIL_FAILED" then
        pendingSentRecord = nil
    elseif event == "BAG_UPDATE_DELAYED" then
        if _G.MailFrame and _G.MailFrame:IsShown() and _G.SendMailFrame and _G.SendMailFrame:IsShown() then
            RefreshSendPickerUI()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if batchState.active then
            StopBatchCollection("Paused during combat lockdown.", true)
        end
    end
end)

SLASH_DYNAMICMAIL1 = "/dmail"
SLASH_DYNAMICMAIL2 = "/dynamicmail"
SlashCmdList["DYNAMICMAIL"] = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(.-)%s*$")
    if cmd == "open" or cmd == "all" then
        DynamicMail:StartBatchOpen("ALL")
    elseif cmd == "gold" or cmd == "ah" then
        DynamicMail:StartBatchOpen("AH_GOLD")
    elseif cmd == "items" or cmd == "loot" then
        DynamicMail:StartBatchOpen("ITEMS")
    elseif cmd == "mats" or cmd == "boe" or cmd == "warband" or cmd == "same" then
        DynamicMail:BatchAttachByPreset(cmd)
    elseif cmd == "stop" or cmd == "abort" then
        DynamicMail:AbortBatchOpen()
    elseif cmd == "reset" then
        DynamicMail:ResetModuleDefaults()
    else
        OpenMailWorkspace()
    end
end
