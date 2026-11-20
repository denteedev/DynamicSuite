-- ============================================================================
-- DynamicDialogue v2.6.0 - Obsidian Quest & Gossip Reader
-- World of Warcraft Retail (12.1.5, Interface 120105)
-- Pure ASCII Only (NonASCII: 0, HasBOM: False) | Zero-Taint Midnight Engine
-- ============================================================================

local addonName = ...
local ADDON_FOLDER = (type(addonName) == "string" and addonName ~= "") and addonName or "DynamicSuite"

local function ResolveAddonVersion(folderName, fallback)
    local fb = fallback or "2.7.1"
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

local VERSION = ResolveAddonVersion(ADDON_FOLDER, "2.7.1")
if ShouldYieldToOtherInstall(ADDON_FOLDER, "DynamicDialogue", VERSION, _G.DynamicDialogue) then
    return
end

local DynamicDialogue = _G.DynamicDialogue or {}
_G.DynamicDialogue = DynamicDialogue
DynamicDialogue.VERSION        = VERSION
DynamicDialogue.version        = VERSION
DynamicDialogue._loadedBySuite = (ADDON_FOLDER == "DynamicSuite")
DynamicDialogue._loadedVersion = VERSION

-- ============================================================================
-- 1. SAFE HELPERS, CONSTANTS & ASSET PATHS
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

local function SafeIsAddOnLoaded(name)
    if type(name) ~= "string" or name == "" then return false end
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
        local ok, res = pcall(C_AddOns.IsAddOnLoaded, name)
        return ok and res == true
    end
    if type(_G.IsAddOnLoaded) == "function" then
        local ok, res = pcall(_G.IsAddOnLoaded, name)
        return ok and res == true
    end
    return false
end

local function IsModuleDisabledInSuite()
    local dsDB = _G.DynamicSuiteDB
    local dis = dsDB and dsDB.global and dsDB.global.disabledModules
    if type(dis) ~= "table" then return false end
    return (dis["DynamicDialogue"] == true) or (dis["dialogue"] == true)
end

local MEDIA_BASE   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\"
local ICON_COLOR   = MEDIA_BASE .. "Icons\\icon_mod_dialogue.tga"
local ICON_WHITE   = ICON_COLOR
local ICON_ACCENT  = ICON_COLOR
local CHIME_QUEST  = MEDIA_BASE .. "Sounds\\ds_bloom.ogg"

local KNOWN_DIALOGUE_ADDONS = {
    { addon = "DialogueUI",      label = "DialogueUI" },
    { addon = "DialogUI",        label = "DialogUI" },
    { addon = "Immersion",       label = "Immersion" },
    { addon = "Storyline",       label = "Storyline" },
    { addon = "QuestFrameFixer", label = "QuestFrameFixer" },
}

local DEFAULTS = {
    enabled             = true,
    replaceQuests       = true,
    replaceGossip       = true,
    enableNumberHotkeys = true,
    enableSpaceConfirm  = true,
    shiftBypassNative   = true,
    hideInCombat        = true,
    autoYield           = true,
    frameScale          = 1.0,
    backdropAlpha       = 0.96,
    fontSize            = 13,
    borderStyle         = "ACCENT", -- "ACCENT", "DARK", "NONE"
    showTypeBadge       = true,
    showRewardTooltips  = true,
    playCompleteChime   = true,
    pos                 = { point = "CENTER", relPoint = "CENTER", x = 0, y = -90 },
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
    if type(_G.DynamicDialogueDB) ~= "table" then
        _G.DynamicDialogueDB = {}
    end
    CopyDefaults(DEFAULTS, _G.DynamicDialogueDB)
    return _G.DynamicDialogueDB
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFB923C[DynamicDialogue]|r " .. tostring(msg or ""))
end

-- ============================================================================
-- 2. THEME & FONT HELPERS (LIVE SYNC WITH DYNAMICSUITE)
-- ============================================================================
local function GetSuiteUI()
    return _G.DynamicSuite and _G.DynamicSuite.UI
end

local function GetAccentColor()
    local ui = GetSuiteUI()
    if ui and type(ui.GetActiveAccentColor) == "function" then
        local ok, r, g, b = pcall(ui.GetActiveAccentColor)
        if ok and type(r) == "table" and r.r then
            return r.r, r.g, r.b
        elseif ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return r, g, b
        end
    end
    return 0.796, 0.835, 0.882 -- Obsidian Silver #CBD5E1 fallback
end

local function GetAccentHex()
    local r, g, b = GetAccentColor()
    return string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function GetSurfaceColors()
    local ui = GetSuiteUI()
    if ui and type(ui.GetSurfaceColors) == "function" then
        local ok, s = pcall(ui.GetSurfaceColors)
        if ok and type(s) == "table" and s.HEADER_BG then
            return s
        end
    end
    return {
        HEADER_BG   = { r = 0.015, g = 0.018, b = 0.024, a = 1.00 },
        PANEL_BG    = { r = 0.035, g = 0.039, b = 0.051, a = 0.99 },
        CARD_BG     = { r = 0.055, g = 0.063, b = 0.082, a = 0.96 },
        CELL_BG     = { r = 0.078, g = 0.090, b = 0.122, a = 0.96 },
        CELL_BORDER = { r = 0.145, g = 0.165, b = 0.212, a = 0.95 },
    }
end

local function GetPillFillAlpha()
    local g = _G.DynamicSuiteDB and _G.DynamicSuiteDB.global
    local a = g and tonumber(g.pillFillAlpha)
    return a or 0.42
end

local function GetFontPath()
    local ui = GetSuiteUI()
    if ui and type(ui.GetFontPath) == "function" then
        local ok, p = pcall(ui.GetFontPath)
        if ok and type(p) == "string" and p ~= "" then return p end
    end
    return "Fonts\\FRIZQT__.TTF"
end

local function ApplyFont(fs, size, flags)
    if not fs then return end
    local ok = pcall(fs.SetFont, fs, GetFontPath(), size or 12, flags or "")
    if not ok then
        pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size or 12, flags or "")
    end
end

local function SolidTex(parent, layer, sublevel, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    t:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
    if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
    return t
end

local function CreatePixelBorder(parent, r, g, b, a, sublevel)
    local sl = sublevel or 4
    local bdr = {
        top    = SolidTex(parent, "OVERLAY", sl, r, g, b, a),
        bottom = SolidTex(parent, "OVERLAY", sl, r, g, b, a),
        left   = SolidTex(parent, "OVERLAY", sl, r, g, b, a),
        right  = SolidTex(parent, "OVERLAY", sl, r, g, b, a),
    }
    bdr.top:SetHeight(1)
    bdr.top:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    bdr.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    bdr.bottom:SetHeight(1)
    bdr.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bdr.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bdr.left:SetWidth(1)
    bdr.left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    bdr.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bdr.right:SetWidth(1)
    bdr.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    bdr.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    function bdr:SetColor(nr, ng, nb, na)
        self.top:SetColorTexture(nr, ng, nb, na)
        self.bottom:SetColorTexture(nr, ng, nb, na)
        self.left:SetColorTexture(nr, ng, nb, na)
        self.right:SetColorTexture(nr, ng, nb, na)
    end
    function bdr:SetShown(show)
        self.top:SetShown(show)
        self.bottom:SetShown(show)
        self.left:SetShown(show)
        self.right:SetShown(show)
    end
    return bdr
end

local function FormatGoldText(copper)
    local c = math.floor(SafeNum(copper, 0))
    if c <= 0 then return "" end
    local g = math.floor(c / 10000)
    local s = math.floor((c % 10000) / 100)
    local cp = c % 100
    local parts = {}
    if g > 0 then table.insert(parts, string.format("|cFFFACC15%dg|r", g)) end
    if s > 0 then table.insert(parts, string.format("|cFFCBD5E1%ds|r", s)) end
    if cp > 0 or #parts == 0 then table.insert(parts, string.format("|cFFFB923C%dc|r", cp)) end
    return table.concat(parts, " ")
end

local QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 },
    [1] = { 0.96, 0.96, 0.96 },
    [2] = { 0.12, 1.00, 0.00 },
    [3] = { 0.00, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 },
    [5] = { 1.00, 0.50, 0.00 },
    [6] = { 0.90, 0.80, 0.50 },
    [7] = { 0.00, 0.80, 1.00 },
}

-- ============================================================================
-- 3. ZERO-TAINT DYNAMIC CONFLICT & BLIZZARD FRAME PROBE ENGINE
-- ============================================================================
function DynamicDialogue:GetYieldInfo()
    local db = EnsureDB()
    if db.autoYield == false then
        return false, nil, nil
    end

    -- Layer 1: Exact known competing dialogue addons
    for _, entry in ipairs(KNOWN_DIALOGUE_ADDONS) do
        if SafeIsAddOnLoaded(entry.addon) then
            return true, entry.label, "Known dialogue replacement addon loaded"
        end
    end

    -- Layer 1b: Smart feature-level check for EllesmereUIQoL / EllesmereUI_QoL
    if SafeIsAddOnLoaded("EllesmereUIQoL") or SafeIsAddOnLoaded("EllesmereUI_QoL") then
        local eq = _G.EllesmereUIQoLDB or (_G.EllesmereUIDB and _G.EllesmereUIDB.qol)
        if type(eq) == "table" then
            if eq.dialogueUI == true or eq.dialogUI == true or eq.questDialogue == true or eq.gossipReplacement == true then
                return true, "EllesmereUI Quality of Life", "EllesmereUI QoL dialogue replacement is enabled"
            end
        end
    end

    -- Layer 2: Central DynamicSuite read-only Blizzard frame/event ownership probe
    if _G.DynamicSuite and type(_G.DynamicSuite.ProbeBlizzardFrameConflict) == "function" then
        local ok, conflicted, ownerLabel, reason = pcall(_G.DynamicSuite.ProbeBlizzardFrameConflict, _G.DynamicSuite, "DIALOGUE")
        if ok and conflicted == true then
            return true, ownerLabel or "External Dialogue Addon", reason or "Blizzard Quest or Gossip frames are being handled by another addon"
        end
    else
        -- Standalone read-only fallback probe: Retail 12.1.5 registers GOSSIP_SHOW / QUEST_DETAIL on GossipFrame / QuestFrame.
        -- Only yield to an unknown external addon if the loaded Blizzard frame AND UIParent both have the event unregistered.
        local gossipOverridden = false
        if _G.GossipFrame and type(_G.GossipFrame.IsEventRegistered) == "function"
            and _G.UIParent and type(_G.UIParent.IsEventRegistered) == "function" then
            local okGF, regGF = pcall(_G.GossipFrame.IsEventRegistered, _G.GossipFrame, "GOSSIP_SHOW")
            local okUP, regUP = pcall(_G.UIParent.IsEventRegistered, _G.UIParent, "GOSSIP_SHOW")
            if (okGF and regGF == false) and (okUP and regUP == false) then
                gossipOverridden = true
            end
        end
        local questOverridden = false
        if _G.QuestFrame and type(_G.QuestFrame.IsEventRegistered) == "function"
            and _G.UIParent and type(_G.UIParent.IsEventRegistered) == "function" then
            local okQF, regQF = pcall(_G.QuestFrame.IsEventRegistered, _G.QuestFrame, "QUEST_DETAIL")
            local okUP, regUP = pcall(_G.UIParent.IsEventRegistered, _G.UIParent, "QUEST_DETAIL")
            if (okQF and regQF == false) and (okUP and regUP == false) then
                questOverridden = true
            end
        end
        if gossipOverridden or questOverridden then
            return true, "External Dialogue Addon", "Blizzard Quest or Gossip frames are being handled by another addon"
        end
    end

    return false, nil, nil
end

function DynamicDialogue:IsYielding()
    local yielding = self:GetYieldInfo()
    return yielding == true
end

function DynamicDialogue:GetStatusText()
    if IsModuleDisabledInSuite() then return "Disabled" end
    local db = EnsureDB()
    if not db.enabled then return "Paused" end
    local yielding, addonLabel = self:GetYieldInfo()
    if yielding then
        return "Yielding (" .. tostring(addonLabel or "External") .. ")"
    end
    return "Active"
end

-- ============================================================================
-- 4. OBSIDIAN IN-GAME QUEST & GOSSIP READER ENGINE
-- ============================================================================
local readerFrame = nil
local currentMode = nil       -- "GOSSIP", "GREETING", "DETAIL", "PROGRESS", "COMPLETE", "PREVIEW"
local currentOptions = {}     -- { { label, tag, tagColor, icon, onClick } }
local selectedChoiceIndex = nil
local suppressedBlizzFrame = nil
local blizzRestoreAlpha = 1
local blizzRestoreMouse = true

local function RestoreBlizzardFrame()
    local bf = suppressedBlizzFrame
    suppressedBlizzFrame = nil
    if bf and not InCombatLockdown() then
        pcall(bf.SetAlpha, bf, blizzRestoreAlpha or 1)
        pcall(bf.EnableMouse, bf, blizzRestoreMouse ~= false)
    end
end

local function SuppressBlizzardFrame(bf)
    if not bf or InCombatLockdown() then return end
    if suppressedBlizzFrame and suppressedBlizzFrame ~= bf then
        RestoreBlizzardFrame()
    end
    if suppressedBlizzFrame ~= bf then
        local okA, curA = pcall(bf.GetAlpha, bf)
        local okM, curM = pcall(bf.IsMouseEnabled, bf)
        blizzRestoreAlpha = (okA and type(curA) == "number" and curA > 0.05) and curA or 1
        blizzRestoreMouse = (okM and curM ~= false)
        suppressedBlizzFrame = bf
    end
    pcall(bf.SetAlpha, bf, 0)
    pcall(bf.EnableMouse, bf, false)
end

local function CloseActiveInteraction()
    local mode = currentMode
    currentMode = nil
    selectedChoiceIndex = nil
    wipe(currentOptions)
    if readerFrame then
        readerFrame:Hide()
    end
    RestoreBlizzardFrame()
    if mode == "GOSSIP" then
        if C_GossipInfo and type(C_GossipInfo.CloseGossip) == "function" then
            pcall(C_GossipInfo.CloseGossip)
        elseif type(_G.CloseGossip) == "function" then
            pcall(_G.CloseGossip)
        end
    elseif mode == "GREETING" or mode == "DETAIL" or mode == "PROGRESS" or mode == "COMPLETE" then
        if type(_G.CloseQuest) == "function" then
            pcall(_G.CloseQuest)
        end
    end
end

local function EnsureReaderFrame()
    if readerFrame then return readerFrame end
    local db = EnsureDB()
    local surf = GetSurfaceColors()
    local ar, ag, ab = GetAccentColor()

    local f = CreateFrame("Frame", "DynamicDialogueReaderFrame", UIParent)
    f:SetSize(560, 420)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(40)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:Hide()

    local pos = db.pos or DEFAULTS.pos
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", SafeNum(pos.x, 0), SafeNum(pos.y, -90))
    f:SetScale(math.max(0.70, math.min(1.40, SafeNum(db.frameScale, 1.0))))

    -- Main opaque backdrop
    f.bg = SolidTex(f, "BACKGROUND", 0, surf.PANEL_BG.r, surf.PANEL_BG.g, surf.PANEL_BG.b, SafeNum(db.backdropAlpha, 0.96))
    f.bg:SetAllPoints()
    f.border = CreatePixelBorder(f, ar, ag, ab, 0.90, 6)

    -- Header bar (40px, draggable)
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetHeight(40)
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    hdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    hdr:EnableMouse(true)
    hdr:RegisterForDrag("LeftButton")
    hdr:SetScript("OnDragStart", function()
        if not InCombatLockdown() then f:StartMoving() end
    end)
    hdr:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local p, _, rp, x, y = f:GetPoint(1)
        if p then
            local d = EnsureDB()
            d.pos = { point = p, relPoint = rp or p, x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
        end
    end)
    hdr.bg = SolidTex(hdr, "BACKGROUND", 1, surf.HEADER_BG.r, surf.HEADER_BG.g, surf.HEADER_BG.b, 1.0)
    hdr.bg:SetAllPoints()
    hdr.div = SolidTex(hdr, "OVERLAY", 2, ar, ag, ab, 0.40)
    hdr.div:SetHeight(1)
    hdr.div:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 0, 0)
    hdr.div:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
    f.hdr = hdr

    -- Accent bar left of header
    hdr.accentBar = SolidTex(hdr, "OVERLAY", 3, ar, ag, ab, 1.0)
    hdr.accentBar:SetSize(3, 24)
    hdr.accentBar:SetPoint("LEFT", hdr, "LEFT", 10, 0)

    -- Type badge pill
    local badge = CreateFrame("Frame", nil, hdr)
    badge:SetSize(74, 20)
    badge:SetPoint("LEFT", hdr.accentBar, "RIGHT", 8, 0)
    badge.bg = SolidTex(badge, "BACKGROUND", 2, ar * 0.28, ag * 0.28, ab * 0.28, 0.95)
    badge.bg:SetAllPoints()
    badge.border = CreatePixelBorder(badge, ar, ag, ab, 0.90, 4)
    badge.text = badge:CreateFontString(nil, "OVERLAY")
    badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0)
    ApplyFont(badge.text, 10, "OUTLINE")
    badge.text:SetTextColor(1, 1, 1, 1)
    f.typeBadge = badge

    -- Geometric X close button
    local closeBtn = CreateFrame("Button", nil, hdr)
    closeBtn:SetSize(26, 26)
    closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -8, 0)
    closeBtn.bg = SolidTex(closeBtn, "BACKGROUND", 2, 0.10, 0.11, 0.14, 0.85)
    closeBtn.bg:SetAllPoints()
    closeBtn.border = CreatePixelBorder(closeBtn, 0.25, 0.28, 0.36, 0.90, 4)
    local xLbl = closeBtn:CreateFontString(nil, "OVERLAY")
    xLbl:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    ApplyFont(xLbl, 12, "OUTLINE")
    xLbl:SetText("X")
    xLbl:SetTextColor(0.85, 0.88, 0.93, 1)
    closeBtn:SetScript("OnEnter", function()
        closeBtn.bg:SetColorTexture(0.80, 0.18, 0.20, 0.85)
        closeBtn.border:SetColor(0.95, 0.30, 0.30, 1)
        xLbl:SetTextColor(1, 1, 1, 1)
    end)
    closeBtn:SetScript("OnLeave", function()
        closeBtn.bg:SetColorTexture(0.10, 0.11, 0.14, 0.85)
        closeBtn.border:SetColor(0.25, 0.28, 0.36, 0.90)
        xLbl:SetTextColor(0.85, 0.88, 0.93, 1)
    end)
    closeBtn:SetScript("OnClick", function()
        CloseActiveInteraction()
    end)
    f.closeBtn = closeBtn

    -- NPC / Quest Title
    f.titleText = hdr:CreateFontString(nil, "OVERLAY")
    f.titleText:SetPoint("LEFT", badge, "RIGHT", 10, 0)
    f.titleText:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
    f.titleText:SetJustifyH("LEFT")
    f.titleText:SetWordWrap(false)
    ApplyFont(f.titleText, 14, "OUTLINE")
    f.titleText:SetTextColor(0.97, 0.98, 1.0, 1)

    -- Subtitle (Quest Title / NPC Name)
    f.subTitle = f:CreateFontString(nil, "OVERLAY")
    f.subTitle:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 16, -10)
    f.subTitle:SetPoint("TOPRIGHT", hdr, "BOTTOMRIGHT", -16, -10)
    f.subTitle:SetJustifyH("LEFT")
    f.subTitle:SetWordWrap(false)
    ApplyFont(f.subTitle, 13, "OUTLINE")
    f.subTitle:SetTextColor(ar, ag, ab, 1)

    -- Scrollable Body Container (Text + Options + Rewards)
    local scrollHolder = CreateFrame("Frame", nil, f)
    scrollHolder:SetPoint("TOPLEFT", f.subTitle, "BOTTOMLEFT", 0, -8)
    scrollHolder:SetPoint("TOPRIGHT", f.subTitle, "BOTTOMRIGHT", 0, -8)
    scrollHolder:SetPoint("BOTTOM", f, "BOTTOM", 0, 52)
    f.scrollHolder = scrollHolder

    local sf = CreateFrame("ScrollFrame", nil, scrollHolder)
    sf:SetPoint("TOPLEFT", scrollHolder, "TOPLEFT", 0, 0)
    sf:SetPoint("BOTTOMRIGHT", scrollHolder, "BOTTOMRIGHT", -10, 0)
    sf:EnableMouseWheel(true)
    f.scrollFrame = sf

    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(516)
    content:SetHeight(200)
    sf:SetScrollChild(content)
    f.content = content

    -- 4px Obsidian Scrollbar
    local track = CreateFrame("Frame", nil, scrollHolder)
    track:SetWidth(4)
    track:SetPoint("TOPRIGHT", scrollHolder, "TOPRIGHT", 0, 0)
    track:SetPoint("BOTTOMRIGHT", scrollHolder, "BOTTOMRIGHT", 0, 0)
    track.bg = SolidTex(track, "BACKGROUND", 1, 0.035, 0.039, 0.051, 0.95)
    track.bg:SetAllPoints()
    track:EnableMouse(true)

    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(4)
    thumb:SetHeight(40)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    thumb.tex = SolidTex(thumb, "OVERLAY", 3, 0.45, 0.50, 0.60, 0.85)
    thumb.tex:SetAllPoints()
    f.scrollTrack = track
    f.scrollThumb = thumb

    local function UpdateScrollBar()
        local maxRange = math.max(0, sf:GetVerticalScrollRange() or 0)
        if maxRange <= 0.5 then
            track:Hide()
            sf:SetVerticalScroll(0)
            return
        end
        track:Show()
        local trackH = math.max(1, track:GetHeight() or 200)
        local visH = math.max(1, sf:GetHeight() or 200)
        local totalH = visH + maxRange
        local thumbH = math.max(24, math.floor((visH / totalH) * trackH))
        thumb:SetHeight(thumbH)
        local cur = math.max(0, math.min(maxRange, sf:GetVerticalScroll() or 0))
        local ratio = cur / maxRange
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -math.floor(ratio * (trackH - thumbH)))
    end
    f.UpdateScrollBar = UpdateScrollBar

    sf:SetScript("OnMouseWheel", function(_, delta)
        local maxRange = math.max(0, sf:GetVerticalScrollRange() or 0)
        if maxRange <= 0.5 then return end
        local cur = sf:GetVerticalScroll() or 0
        local nextVal = math.max(0, math.min(maxRange, cur - (delta * 36)))
        sf:SetVerticalScroll(nextVal)
        UpdateScrollBar()
    end)

    -- Body text inside content
    f.bodyText = content:CreateFontString(nil, "OVERLAY")
    f.bodyText:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -2)
    f.bodyText:SetWidth(508)
    f.bodyText:SetJustifyH("LEFT")
    f.bodyText:SetJustifyV("TOP")
    f.bodyText:SetWordWrap(true)
    f.bodyText:SetSpacing(3)
    ApplyFont(f.bodyText, SafeNum(db.fontSize, 13), "")
    f.bodyText:SetTextColor(0.88, 0.91, 0.95, 1)

    -- Option button pool & reward card pool
    f.optionButtons = {}
    f.rewardCards   = {}

    -- Footer Bar (44px)
    local footer = CreateFrame("Frame", nil, f)
    footer:SetHeight(44)
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
    footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    footer.bg = SolidTex(footer, "BACKGROUND", 1, surf.HEADER_BG.r, surf.HEADER_BG.g, surf.HEADER_BG.b, 0.98)
    footer.bg:SetAllPoints()
    footer.div = SolidTex(footer, "OVERLAY", 2, 1, 1, 1, 0.08)
    footer.div:SetHeight(1)
    footer.div:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 0)
    footer.div:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, 0)
    f.footer = footer

    -- Hint text on left of footer
    f.footerHint = footer:CreateFontString(nil, "OVERLAY")
    f.footerHint:SetPoint("LEFT", footer, "LEFT", 14, 0)
    f.footerHint:SetJustifyH("LEFT")
    ApplyFont(f.footerHint, 10, "")
    f.footerHint:SetTextColor(0.60, 0.66, 0.75, 1)

    -- Secondary button (Decline / Goodbye)
    local secBtn = CreateFrame("Button", nil, footer)
    secBtn:SetSize(112, 28)
    secBtn:SetPoint("RIGHT", footer, "RIGHT", -14, 0)
    secBtn.bg = SolidTex(secBtn, "BACKGROUND", 2, surf.CELL_BG.r, surf.CELL_BG.g, surf.CELL_BG.b, 0.96)
    secBtn.bg:SetAllPoints()
    secBtn.border = CreatePixelBorder(secBtn, surf.CELL_BORDER.r, surf.CELL_BORDER.g, surf.CELL_BORDER.b, 0.95, 4)
    secBtn.label = secBtn:CreateFontString(nil, "OVERLAY")
    secBtn.label:SetPoint("CENTER", secBtn, "CENTER", 0, 0)
    ApplyFont(secBtn.label, 11, "OUTLINE")
    secBtn.label:SetTextColor(0.86, 0.90, 0.95, 1)
    secBtn:SetScript("OnEnter", function()
        secBtn.bg:SetColorTexture(0.14, 0.16, 0.21, 0.98)
        secBtn.border:SetColor(0.50, 0.56, 0.66, 1)
    end)
    secBtn:SetScript("OnLeave", function()
        local s = GetSurfaceColors()
        secBtn.bg:SetColorTexture(s.CELL_BG.r, s.CELL_BG.g, s.CELL_BG.b, 0.96)
        secBtn.border:SetColor(s.CELL_BORDER.r, s.CELL_BORDER.g, s.CELL_BORDER.b, 0.95)
    end)
    f.secBtn = secBtn

    -- Primary button (Accept / Continue / Complete)
    local priBtn = CreateFrame("Button", nil, footer)
    priBtn:SetSize(164, 28)
    priBtn:SetPoint("RIGHT", secBtn, "LEFT", -8, 0)
    priBtn.bg = SolidTex(priBtn, "BACKGROUND", 2, ar * 0.42, ag * 0.42, ab * 0.42, 0.96)
    priBtn.bg:SetAllPoints()
    priBtn.border = CreatePixelBorder(priBtn, ar, ag, ab, 0.95, 4)
    priBtn.label = priBtn:CreateFontString(nil, "OVERLAY")
    priBtn.label:SetPoint("CENTER", priBtn, "CENTER", 0, 0)
    ApplyFont(priBtn.label, 11, "OUTLINE")
    priBtn.label:SetTextColor(1, 1, 1, 1)
    priBtn:SetScript("OnEnter", function()
        local r, g, b = GetAccentColor()
        priBtn.bg:SetColorTexture(r * 0.55, g * 0.55, b * 0.55, 0.98)
    end)
    priBtn:SetScript("OnLeave", function()
        local r, g, b = GetAccentColor()
        local fa = GetPillFillAlpha()
        priBtn.bg:SetColorTexture(r * fa, g * fa, b * fa, 0.96)
    end)
    f.priBtn = priBtn

    -- Keyboard handler (1-9 hotkeys, Space accept/confirm, Escape close)
    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then return end
        local d = EnsureDB()
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            CloseActiveInteraction()
            return
        end
        if d.enableNumberHotkeys ~= false then
            local num = tonumber(key)
            if num and num >= 1 and num <= 9 and currentOptions[num] and type(currentOptions[num].onClick) == "function" then
                self:SetPropagateKeyboardInput(false)
                currentOptions[num].onClick()
                return
            end
        end
        if d.enableSpaceConfirm ~= false and key == "SPACE" then
            if f.priBtn:IsShown() and f.priBtn:IsEnabled() then
                self:SetPropagateKeyboardInput(false)
                local fn = f.priBtn:GetScript("OnClick")
                if fn then fn(f.priBtn) end
                return
            elseif #currentOptions == 1 and type(currentOptions[1].onClick) == "function" then
                self:SetPropagateKeyboardInput(false)
                currentOptions[1].onClick()
                return
            end
        end
        self:SetPropagateKeyboardInput(true)
    end)

    f:SetScript("OnHide", function()
        GameTooltip:Hide()
    end)

    readerFrame = f
    return f
end

function DynamicDialogue:ApplyReaderTheme()
    if not readerFrame then return end
    local db = EnsureDB()
    local surf = GetSurfaceColors()
    local ar, ag, ab = GetAccentColor()
    local fa = GetPillFillAlpha()

    readerFrame:SetScale(math.max(0.70, math.min(1.40, SafeNum(db.frameScale, 1.0))))
    readerFrame.bg:SetColorTexture(surf.PANEL_BG.r, surf.PANEL_BG.g, surf.PANEL_BG.b, SafeNum(db.backdropAlpha, 0.96))
    readerFrame.hdr.bg:SetColorTexture(surf.HEADER_BG.r, surf.HEADER_BG.g, surf.HEADER_BG.b, 1.0)
    readerFrame.hdr.div:SetColorTexture(ar, ag, ab, 0.40)
    readerFrame.hdr.accentBar:SetColorTexture(ar, ag, ab, 1.0)
    readerFrame.footer.bg:SetColorTexture(surf.HEADER_BG.r, surf.HEADER_BG.g, surf.HEADER_BG.b, 0.98)

    if db.borderStyle == "NONE" then
        readerFrame.border:SetShown(false)
    elseif db.borderStyle == "DARK" then
        readerFrame.border:SetShown(true)
        readerFrame.border:SetColor(surf.CELL_BORDER.r, surf.CELL_BORDER.g, surf.CELL_BORDER.b, 0.95)
    else
        readerFrame.border:SetShown(true)
        readerFrame.border:SetColor(ar, ag, ab, 0.90)
    end

    readerFrame.typeBadge:SetShown(db.showTypeBadge ~= false)
    readerFrame.typeBadge.bg:SetColorTexture(ar * 0.28, ag * 0.28, ab * 0.28, 0.95)
    readerFrame.typeBadge.border:SetColor(ar, ag, ab, 0.90)

    readerFrame.subTitle:SetTextColor(ar, ag, ab, 1)
    ApplyFont(readerFrame.titleText, 14, "OUTLINE")
    ApplyFont(readerFrame.subTitle, 13, "OUTLINE")
    ApplyFont(readerFrame.bodyText, SafeNum(db.fontSize, 13), "")
    readerFrame.priBtn.bg:SetColorTexture(ar * fa, ag * fa, ab * fa, 0.96)
    readerFrame.priBtn.border:SetColor(ar, ag, ab, 0.95)
end

local function AcquireOptionButton(parent, index)
    local f = EnsureReaderFrame()
    local btn = f.optionButtons[index]
    if btn then return btn end
    local surf = GetSurfaceColors()
    local ar, ag, ab = GetAccentColor()

    btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(32)
    btn.bg = SolidTex(btn, "BACKGROUND", 1, surf.CARD_BG.r, surf.CARD_BG.g, surf.CARD_BG.b, 0.96)
    btn.bg:SetAllPoints()
    btn.border = CreatePixelBorder(btn, surf.CELL_BORDER.r, surf.CELL_BORDER.g, surf.CELL_BORDER.b, 0.95, 4)

    -- Keycap badge [1]..[9]
    local keycap = CreateFrame("Frame", nil, btn)
    keycap:SetSize(22, 20)
    keycap:SetPoint("LEFT", btn, "LEFT", 8, 0)
    keycap.bg = SolidTex(keycap, "BACKGROUND", 2, ar * 0.25, ag * 0.25, ab * 0.25, 0.95)
    keycap.bg:SetAllPoints()
    keycap.border = CreatePixelBorder(keycap, ar, ag, ab, 0.85, 4)
    keycap.text = keycap:CreateFontString(nil, "OVERLAY")
    keycap.text:SetPoint("CENTER", keycap, "CENTER", 0, 0)
    ApplyFont(keycap.text, 10, "OUTLINE")
    keycap.text:SetTextColor(1, 1, 1, 1)
    btn.keycap = keycap

    btn.tagText = btn:CreateFontString(nil, "OVERLAY")
    btn.tagText:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
    btn.tagText:SetJustifyH("RIGHT")
    ApplyFont(btn.tagText, 10, "OUTLINE")

    btn.label = btn:CreateFontString(nil, "OVERLAY")
    btn.label:SetPoint("LEFT", keycap, "RIGHT", 10, 0)
    btn.label:SetPoint("RIGHT", btn.tagText, "LEFT", -8, 0)
    btn.label:SetJustifyH("LEFT")
    btn.label:SetWordWrap(false)
    ApplyFont(btn.label, 12, "")
    btn.label:SetTextColor(0.95, 0.97, 1.0, 1)

    btn:SetScript("OnEnter", function()
        local r, g, b = GetAccentColor()
        local fa = GetPillFillAlpha()
        btn.bg:SetColorTexture(r * (fa * 0.65), g * (fa * 0.65), b * (fa * 0.65), 0.98)
        btn.border:SetColor(r, g, b, 0.95)
    end)
    btn:SetScript("OnLeave", function()
        local s = GetSurfaceColors()
        btn.bg:SetColorTexture(s.CARD_BG.r, s.CARD_BG.g, s.CARD_BG.b, 0.96)
        btn.border:SetColor(s.CELL_BORDER.r, s.CELL_BORDER.g, s.CELL_BORDER.b, 0.95)
    end)

    f.optionButtons[index] = btn
    return btn
end

local function AcquireRewardCard(parent, index)
    local f = EnsureReaderFrame()
    local card = f.rewardCards[index]
    if card then return card end
    local surf = GetSurfaceColors()

    card = CreateFrame("Button", nil, parent)
    card:SetSize(246, 44)
    card.bg = SolidTex(card, "BACKGROUND", 1, surf.CARD_BG.r, surf.CARD_BG.g, surf.CARD_BG.b, 0.96)
    card.bg:SetAllPoints()
    card.border = CreatePixelBorder(card, surf.CELL_BORDER.r, surf.CELL_BORDER.g, surf.CELL_BORDER.b, 0.95, 4)

    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(32, 32)
    card.icon:SetPoint("LEFT", card, "LEFT", 6, 0)
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    card.countText = card:CreateFontString(nil, "OVERLAY")
    card.countText:SetPoint("BOTTOMRIGHT", card.icon, "BOTTOMRIGHT", -1, 1)
    ApplyFont(card.countText, 10, "OUTLINE")
    card.countText:SetTextColor(1, 1, 1, 1)

    card.nameText = card:CreateFontString(nil, "OVERLAY")
    card.nameText:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 8, -2)
    card.nameText:SetPoint("RIGHT", card, "RIGHT", -8, 0)
    card.nameText:SetJustifyH("LEFT")
    card.nameText:SetWordWrap(false)
    ApplyFont(card.nameText, 11, "")

    card.subText = card:CreateFontString(nil, "OVERLAY")
    card.subText:SetPoint("BOTTOMLEFT", card.icon, "BOTTOMRIGHT", 8, 2)
    card.subText:SetPoint("RIGHT", card, "RIGHT", -8, 0)
    card.subText:SetJustifyH("LEFT")
    card.subText:SetWordWrap(false)
    ApplyFont(card.subText, 9, "")
    card.subText:SetTextColor(0.62, 0.68, 0.78, 1)

    f.rewardCards[index] = card
    return card
end

local function HidePooledWidgets()
    if not readerFrame then return end
    for _, b in ipairs(readerFrame.optionButtons) do b:Hide() end
    for _, c in ipairs(readerFrame.rewardCards) do c:Hide() end
end

local function PopulateRewardsSection(yCursor, isChoiceMode)
    local f = EnsureReaderFrame()
    local db = EnsureDB()
    local ar, ag, ab = GetAccentColor()
    local surf = GetSurfaceColors()
    local cardIdx = 0
    local rewardsList = {}

    local numChoices = (type(_G.GetNumQuestChoices) == "function") and SafeNum(_G.GetNumQuestChoices(), 0) or 0
    local numRewards = (type(_G.GetNumQuestRewards) == "function") and SafeNum(_G.GetNumQuestRewards(), 0) or 0
    local money = (type(_G.GetRewardMoney) == "function") and SafeNum(_G.GetRewardMoney(), 0) or 0
    local xp = (type(_G.GetRewardXP) == "function") and SafeNum(_G.GetRewardXP(), 0) or 0

    if numChoices > 0 and type(_G.GetQuestItemInfo) == "function" then
        for i = 1, numChoices do
            local name, tex, count, quality = _G.GetQuestItemInfo("choice", i)
            if name then
                table.insert(rewardsList, {
                    kind = "choice",
                    index = i,
                    name = SafeStr(name),
                    icon = tex,
                    count = SafeNum(count, 1),
                    quality = SafeNum(quality, 1),
                    sub = isChoiceMode and "Click to Choose" or "Choice Reward",
                })
            end
        end
    end

    if numRewards > 0 and type(_G.GetQuestItemInfo) == "function" then
        for i = 1, numRewards do
            local name, tex, count, quality = _G.GetQuestItemInfo("reward", i)
            if name then
                table.insert(rewardsList, {
                    kind = "reward",
                    index = i,
                    name = SafeStr(name),
                    icon = tex,
                    count = SafeNum(count, 1),
                    quality = SafeNum(quality, 1),
                    sub = "Guaranteed Reward",
                })
            end
        end
    end

    if money > 0 or xp > 0 then
        local summaryParts = {}
        if xp > 0 then table.insert(summaryParts, string.format("|cFFA855F7%d XP|r", xp)) end
        if money > 0 then table.insert(summaryParts, FormatGoldText(money)) end
        table.insert(rewardsList, {
            kind = "summary",
            name = table.concat(summaryParts, "   "),
            icon = 133784, -- Gold coin icon
            count = 1,
            quality = 1,
            sub = "Quest Completion Bonus",
        })
    end

    if #rewardsList == 0 then
        return yCursor
    end

    yCursor = yCursor - 10
    local col = 0
    for _, item in ipairs(rewardsList) do
        cardIdx = cardIdx + 1
        local card = AcquireRewardCard(f.content, cardIdx)
        card:ClearAllPoints()
        local xOff = (col == 0) and 2 or 258
        card:SetPoint("TOPLEFT", f.content, "TOPLEFT", xOff, yCursor)
        card.icon:SetTexture(item.icon or 134400)
        card.countText:SetText((item.count and item.count > 1) and tostring(item.count) or "")
        card.nameText:SetText(item.name or "")
        local qc = QUALITY_COLORS[item.quality or 1] or QUALITY_COLORS[1]
        if item.kind == "summary" then
            card.nameText:SetTextColor(1, 1, 1, 1)
        else
            card.nameText:SetTextColor(qc[1], qc[2], qc[3], 1)
        end
        card.subText:SetText(item.sub or "")

        local function RefreshCardBorder()
            if item.kind == "choice" and selectedChoiceIndex == item.index then
                card.bg:SetColorTexture(ar * 0.30, ag * 0.30, ab * 0.30, 0.98)
                card.border:SetColor(ar, ag, ab, 1.0)
            else
                card.bg:SetColorTexture(surf.CARD_BG.r, surf.CARD_BG.g, surf.CARD_BG.b, 0.96)
                card.border:SetColor(qc[1] * 0.55, qc[2] * 0.55, qc[3] * 0.55, 0.85)
            end
        end
        RefreshCardBorder()

        card:SetScript("OnEnter", function(self)
            if db.showRewardTooltips ~= false and (item.kind == "choice" or item.kind == "reward") then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                pcall(GameTooltip.SetQuestItem, GameTooltip, item.kind, item.index)
                GameTooltip:Show()
            end
            card.border:SetColor(ar, ag, ab, 1.0)
        end)
        card:SetScript("OnLeave", function()
            GameTooltip:Hide()
            RefreshCardBorder()
        end)
        card:SetScript("OnClick", function()
            if item.kind == "choice" and isChoiceMode then
                selectedChoiceIndex = item.index
                -- Refresh all visible choice cards
                for j = 1, cardIdx do
                    local c = f.rewardCards[j]
                    if c and c:IsShown() and c._refreshChoice then
                        c._refreshChoice()
                    end
                end
                if f.priBtn and f.priBtn:IsShown() then
                    f.priBtn:Enable()
                    f.priBtn.label:SetText("Complete Quest [Space]")
                end
            end
        end)
        card._refreshChoice = RefreshCardBorder
        card:Show()

        col = col + 1
        if col >= 2 then
            col = 0
            yCursor = yCursor - 50
        end
    end
    if col == 1 then
        yCursor = yCursor - 50
    end
    return yCursor
end

local function RenderReaderState(opts)
    local f = EnsureReaderFrame()
    local db = EnsureDB()
    HidePooledWidgets()
    wipe(currentOptions)

    local ar, ag, ab = GetAccentColor()
    DynamicDialogue:ApplyReaderTheme()

    f.typeBadge.text:SetText(opts.badge or "DIALOGUE")
    f.titleText:SetText(opts.title or "Dialogue")
    f.subTitle:SetText(opts.subtitle or "")
    f.bodyText:SetText(opts.body or "")
    ApplyFont(f.bodyText, SafeNum(db.fontSize, 13), "")

    local bodyH = math.max(24, math.ceil(f.bodyText:GetStringHeight() or 24))
    local yCursor = -(bodyH + 14)

    -- Populate option rows (1..9 hotkeys)
    local list = opts.options or {}
    for i, opt in ipairs(list) do
        currentOptions[i] = opt
        local btn = AcquireOptionButton(f.content, i)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", f.content, "TOPLEFT", 2, yCursor)
        btn:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", -2, yCursor)
        if i <= 9 and db.enableNumberHotkeys ~= false then
            btn.keycap:Show()
            btn.keycap.text:SetText(tostring(i))
            btn.keycap.bg:SetColorTexture(ar * 0.25, ag * 0.25, ab * 0.25, 0.95)
            btn.keycap.border:SetColor(ar, ag, ab, 0.85)
            btn.label:ClearAllPoints()
            btn.label:SetPoint("LEFT", btn.keycap, "RIGHT", 10, 0)
            btn.label:SetPoint("RIGHT", btn.tagText, "LEFT", -8, 0)
        else
            btn.keycap:Hide()
            btn.label:ClearAllPoints()
            btn.label:SetPoint("LEFT", btn, "LEFT", 10, 0)
            btn.label:SetPoint("RIGHT", btn.tagText, "LEFT", -8, 0)
        end
        btn.label:SetText(opt.label or "")
        if opt.tag and opt.tag ~= "" then
            btn.tagText:SetText(opt.tag)
            local tc = opt.tagColor or { 0.98, 0.80, 0.08 }
            btn.tagText:SetTextColor(tc[1], tc[2], tc[3], 1)
        else
            btn.tagText:SetText("")
        end
        btn:SetScript("OnClick", function()
            if type(opt.onClick) == "function" then
                opt.onClick()
            end
        end)
        btn:Show()
        yCursor = yCursor - 38
    end

    -- Populate rewards if requested
    if opts.showRewards then
        yCursor = PopulateRewardsSection(yCursor, opts.isChoiceMode == true)
    end

    local totalH = math.max(80, math.abs(yCursor) + 12)
    f.content:SetHeight(totalH)
    f.scrollFrame:SetVerticalScroll(0)

    -- Dynamic height clamped nicely between 260 and 540
    local desiredH = math.max(260, math.min(540, totalH + 132))
    f:SetHeight(desiredH)

    -- Primary / Secondary footer buttons
    if opts.primaryLabel and type(opts.onPrimary) == "function" then
        f.priBtn:Show()
        f.priBtn.label:SetText(opts.primaryLabel)
        f.priBtn:SetScript("OnClick", opts.onPrimary)
        if opts.primaryDisabled then
            f.priBtn:Disable()
            f.priBtn:SetAlpha(0.50)
        else
            f.priBtn:Enable()
            f.priBtn:SetAlpha(1.0)
        end
    else
        f.priBtn:Hide()
    end

    f.secBtn:Show()
    f.secBtn.label:SetText(opts.secondaryLabel or "Close [Esc]")
    f.secBtn:SetScript("OnClick", opts.onSecondary or CloseActiveInteraction)

    local hints = {}
    if #list > 0 and db.enableNumberHotkeys ~= false then table.insert(hints, "[1-" .. math.min(9, #list) .. "] Select") end
    if opts.primaryLabel and db.enableSpaceConfirm ~= false then table.insert(hints, "[Space] Confirm") end
    table.insert(hints, "[Esc] Close")
    f.footerHint:SetText(table.concat(hints, "  |  "))

    f:Show()
    C_Timer.After(0, function()
        if f and f:IsShown() and f.UpdateScrollBar then
            f.UpdateScrollBar()
        end
    end)
end

function DynamicDialogue:ShouldIntercept(kind)
    if IsModuleDisabledInSuite() then return false end
    local db = EnsureDB()
    if not db.enabled then return false end
    if kind == "GOSSIP" and db.replaceGossip == false then return false end
    if kind == "QUEST" and db.replaceQuests == false then return false end
    if db.hideInCombat ~= false and InCombatLockdown() then return false end
    if db.shiftBypassNative ~= false and IsShiftKeyDown() then return false end
    if self:IsYielding() then return false end
    return true
end

function DynamicDialogue:ShowGossip()
    if not self:ShouldIntercept("GOSSIP") then
        RestoreBlizzardFrame()
        return
    end
    currentMode = "GOSSIP"
    SuppressBlizzardFrame(_G.GossipFrame)

    local npcName = SafeStr(_G.UnitName and _G.UnitName("npc") or _G.UnitName("target"), "NPC")
    local text = (C_GossipInfo and C_GossipInfo.GetText) and SafeStr(C_GossipInfo.GetText(), "") or ""
    local options = {}

    -- Active (Turn-in) Quests first
    if C_GossipInfo and type(C_GossipInfo.GetActiveQuests) == "function" then
        local activeQ = C_GossipInfo.GetActiveQuests() or {}
        for _, q in ipairs(activeQ) do
            local qID = q.questID
            local isComplete = (q.isComplete == true)
            table.insert(options, {
                label = SafeStr(q.title, "Active Quest"),
                tag = isComplete and "[TURN-IN]" or "[IN PROGRESS]",
                tagColor = isComplete and { 0.20, 0.83, 0.60 } or { 0.64, 0.70, 0.78 },
                onClick = function()
                    if qID and C_GossipInfo.SelectActiveQuest then
                        pcall(C_GossipInfo.SelectActiveQuest, qID)
                    end
                end,
            })
        end
    end

    -- Available Quests
    if C_GossipInfo and type(C_GossipInfo.GetAvailableQuests) == "function" then
        local availQ = C_GossipInfo.GetAvailableQuests() or {}
        for _, q in ipairs(availQ) do
            local qID = q.questID
            table.insert(options, {
                label = SafeStr(q.title, "Available Quest"),
                tag = "[QUEST]",
                tagColor = { 0.98, 0.80, 0.08 },
                onClick = function()
                    if qID and C_GossipInfo.SelectAvailableQuest then
                        pcall(C_GossipInfo.SelectAvailableQuest, qID)
                    end
                end,
            })
        end
    end

    -- Gossip Options
    if C_GossipInfo and type(C_GossipInfo.GetOptions) == "function" then
        local gOpts = C_GossipInfo.GetOptions() or {}
        for _, opt in ipairs(gOpts) do
            local optID = opt.gossipOptionID
            table.insert(options, {
                label = SafeStr(opt.name, "Dialogue Option"),
                tag = (opt.flags and opt.flags > 0) and "[OPTION]" or "",
                tagColor = { 0.38, 0.65, 0.98 },
                onClick = function()
                    if optID and C_GossipInfo.SelectOption then
                        pcall(C_GossipInfo.SelectOption, optID)
                    end
                end,
            })
        end
    end

    RenderReaderState({
        badge = "GOSSIP",
        title = npcName,
        subtitle = "Conversation & Available Options",
        body = (text ~= "") and text or "Select an option below to continue.",
        options = options,
        secondaryLabel = "Goodbye [Esc]",
    })
end

function DynamicDialogue:ShowQuestGreeting()
    if not self:ShouldIntercept("QUEST") then
        RestoreBlizzardFrame()
        return
    end
    currentMode = "GREETING"
    SuppressBlizzardFrame(_G.QuestFrame)

    local npcName = SafeStr(_G.UnitName and _G.UnitName("npc"), "Quest Giver")
    local text = (type(_G.GetGreetingText) == "function") and SafeStr(_G.GetGreetingText(), "") or ""
    local options = {}

    local numActive = (type(_G.GetNumActiveQuests) == "function") and SafeNum(_G.GetNumActiveQuests(), 0) or 0
    for i = 1, numActive do
        local title, isComplete = _G.GetActiveTitle(i)
        table.insert(options, {
            label = SafeStr(title, "Active Quest"),
            tag = isComplete and "[TURN-IN]" or "[IN PROGRESS]",
            tagColor = isComplete and { 0.20, 0.83, 0.60 } or { 0.64, 0.70, 0.78 },
            onClick = function()
                if type(_G.SelectActiveQuest) == "function" then pcall(_G.SelectActiveQuest, i) end
            end,
        })
    end

    local numAvail = (type(_G.GetNumAvailableQuests) == "function") and SafeNum(_G.GetNumAvailableQuests(), 0) or 0
    for i = 1, numAvail do
        local title = _G.GetAvailableTitle(i)
        table.insert(options, {
            label = SafeStr(title, "Available Quest"),
            tag = "[QUEST]",
            tagColor = { 0.98, 0.80, 0.08 },
            onClick = function()
                if type(_G.SelectAvailableQuest) == "function" then pcall(_G.SelectAvailableQuest, i) end
            end,
        })
    end

    RenderReaderState({
        badge = "QUESTS",
        title = npcName,
        subtitle = "Available & Active Quests",
        body = (text ~= "") and text or "Choose a quest below.",
        options = options,
        secondaryLabel = "Goodbye [Esc]",
    })
end

function DynamicDialogue:ShowQuestDetail()
    if not self:ShouldIntercept("QUEST") then
        RestoreBlizzardFrame()
        return
    end
    currentMode = "DETAIL"
    selectedChoiceIndex = nil
    SuppressBlizzardFrame(_G.QuestFrame)

    local npcName = SafeStr(_G.UnitName and _G.UnitName("npc"), "Quest")
    local qTitle  = (type(_G.GetTitleText) == "function") and SafeStr(_G.GetTitleText(), "Quest") or "Quest"
    local qDesc   = (type(_G.GetQuestText) == "function") and SafeStr(_G.GetQuestText(), "") or ""
    local qObj    = (type(_G.GetObjectiveText) == "function") and SafeStr(_G.GetObjectiveText(), "") or ""
    local body = qDesc
    if qObj ~= "" then
        body = body .. "\n\n|cFF" .. GetAccentHex() .. "Objective:|r\n" .. qObj
    end

    RenderReaderState({
        badge = "QUEST",
        title = npcName,
        subtitle = qTitle,
        body = body,
        showRewards = true,
        isChoiceMode = false,
        primaryLabel = "Accept Quest [Space]",
        onPrimary = function()
            if type(_G.AcceptQuest) == "function" then
                pcall(_G.AcceptQuest)
            end
        end,
        secondaryLabel = "Decline [Esc]",
        onSecondary = function()
            if type(_G.DeclineQuest) == "function" then
                pcall(_G.DeclineQuest)
            end
            CloseActiveInteraction()
        end,
    })
end

function DynamicDialogue:ShowQuestProgress()
    if not self:ShouldIntercept("QUEST") then
        RestoreBlizzardFrame()
        return
    end
    currentMode = "PROGRESS"
    SuppressBlizzardFrame(_G.QuestFrame)

    local npcName = SafeStr(_G.UnitName and _G.UnitName("npc"), "Quest")
    local qTitle  = (type(_G.GetTitleText) == "function") and SafeStr(_G.GetTitleText(), "Quest") or "Quest"
    local qProg   = (type(_G.GetProgressText) == "function") and SafeStr(_G.GetProgressText(), "") or ""
    local canComplete = (type(_G.IsQuestCompletable) == "function") and (_G.IsQuestCompletable() == true)

    RenderReaderState({
        badge = "PROGRESS",
        title = npcName,
        subtitle = qTitle,
        body = qProg,
        primaryLabel = canComplete and "Continue [Space]" or "In Progress",
        primaryDisabled = not canComplete,
        onPrimary = function()
            if canComplete and type(_G.CompleteQuest) == "function" then
                pcall(_G.CompleteQuest)
            end
        end,
        secondaryLabel = "Close [Esc]",
    })
end

function DynamicDialogue:ShowQuestComplete()
    if not self:ShouldIntercept("QUEST") then
        RestoreBlizzardFrame()
        return
    end
    currentMode = "COMPLETE"
    selectedChoiceIndex = nil
    SuppressBlizzardFrame(_G.QuestFrame)

    local db = EnsureDB()
    local npcName = SafeStr(_G.UnitName and _G.UnitName("npc"), "Quest")
    local qTitle  = (type(_G.GetTitleText) == "function") and SafeStr(_G.GetTitleText(), "Quest") or "Quest"
    local qReward = (type(_G.GetRewardText) == "function") and SafeStr(_G.GetRewardText(), "") or ""
    local numChoices = (type(_G.GetNumQuestChoices) == "function") and SafeNum(_G.GetNumQuestChoices(), 0) or 0
    if numChoices == 1 then
        selectedChoiceIndex = 1
    end

    RenderReaderState({
        badge = "TURN-IN",
        title = npcName,
        subtitle = qTitle,
        body = qReward,
        showRewards = true,
        isChoiceMode = (numChoices > 1),
        primaryLabel = (numChoices > 1 and not selectedChoiceIndex) and "Select a Reward" or "Complete Quest [Space]",
        primaryDisabled = (numChoices > 1 and not selectedChoiceIndex),
        onPrimary = function()
            if numChoices > 1 and not selectedChoiceIndex then
                Print("Please click a reward choice before completing the quest.")
                return
            end
            if db.playCompleteChime ~= false and type(_G.PlaySoundFile) == "function" then
                pcall(_G.PlaySoundFile, CHIME_QUEST, "Master")
            end
            if type(_G.GetQuestReward) == "function" then
                pcall(_G.GetQuestReward, selectedChoiceIndex or 1)
            end
        end,
        secondaryLabel = "Close [Esc]",
    })
end

function DynamicDialogue:ShowPreview()
    currentMode = "PREVIEW"
    selectedChoiceIndex = nil
    RenderReaderState({
        badge = "PREVIEW",
        title = "Chronomancer Chromie",
        subtitle = "Obsidian Dialogue Reader Preview",
        body = "Welcome to DynamicDialogue! Press [1]-[3] to test option hotkeys, press [Space] to confirm, or drag the dark Obsidian header bar to reposition this reader anywhere on your screen.\n\nHold [Shift] while talking to any NPC to temporarily open the native Blizzard quest frame.",
        options = {
            { label = "Test Hotkey 1: Inspect Midnight Quest Layout", tag = "[QUEST]", tagColor = { 0.98, 0.80, 0.08 }, onClick = function() Print("Preview Option 1 selected.") end },
            { label = "Test Hotkey 2: Verify High-Contrast Obsidian Readability", tag = "[OPTION]", tagColor = { 0.38, 0.65, 0.98 }, onClick = function() Print("Preview Option 2 selected.") end },
            { label = "Test Hotkey 3: Close Preview Reader", tag = "[CLOSE]", tagColor = { 0.20, 0.83, 0.60 }, onClick = function() CloseActiveInteraction() end },
        },
        primaryLabel = "Accept Preview [Space]",
        onPrimary = function()
            local db = EnsureDB()
            if db.playCompleteChime ~= false and type(_G.PlaySoundFile) == "function" then
                pcall(_G.PlaySoundFile, CHIME_QUEST, "Master")
            end
            CloseActiveInteraction()
        end,
        secondaryLabel = "Close [Esc]",
    })
end

function DynamicDialogue:ResetPosition()
    local db = EnsureDB()
    db.pos = { point = "CENTER", relPoint = "CENTER", x = 0, y = -90 }
    if readerFrame then
        readerFrame:ClearAllPoints()
        readerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -90)
    end
    Print("Dialogue Reader position reset to centre.")
end

-- ============================================================================
-- 5. EMBEDDED SUITE UI & STANDALONE CONFIG PANEL (DESIGN_SYSTEM.md COMPLIANT)
-- ============================================================================
local activeEmbeddedRoot = nil
local standaloneFrame = nil

local function CreateSectionHeader(parent, titleText, subText, yOffset)
    local ar, ag, ab = GetAccentColor()
    local hdr = CreateFrame("Frame", nil, parent)
    hdr:SetHeight(36)
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset or -10)
    hdr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, yOffset or -10)

    hdr.leftBar = SolidTex(hdr, "OVERLAY", 4, ar, ag, ab, 1.0)
    hdr.leftBar:SetSize(3, 34)
    hdr.leftBar:SetPoint("TOPLEFT", hdr, "TOPLEFT", 0, -1)

    hdr.title = hdr:CreateFontString(nil, "OVERLAY")
    hdr.title:SetPoint("TOPLEFT", hdr.leftBar, "TOPRIGHT", 8, 0)
    hdr.title:SetPoint("RIGHT", hdr, "RIGHT", -12, 0)
    hdr.title:SetJustifyH("LEFT")
    hdr.title:SetWordWrap(false)
    ApplyFont(hdr.title, 11, "")
    hdr.title:SetText(string.upper(titleText or ""))
    hdr.title:SetTextColor(ar, ag, ab, 1.0)

    hdr.subtitle = hdr:CreateFontString(nil, "OVERLAY")
    hdr.subtitle:SetPoint("TOPLEFT", hdr.title, "BOTTOMLEFT", 0, -3)
    hdr.subtitle:SetPoint("RIGHT", hdr, "RIGHT", -12, 0)
    hdr.subtitle:SetJustifyH("LEFT")
    hdr.subtitle:SetWordWrap(false)
    ApplyFont(hdr.subtitle, 10, "")
    hdr.subtitle:SetText(subText or "")
    hdr.subtitle:SetTextColor(0.64, 0.70, 0.78, 1.0)

    hdr.botLine = SolidTex(hdr, "OVERLAY", 3, ar, ag, ab, 0.35)
    hdr.botLine:SetHeight(1)
    hdr.botLine:SetPoint("TOPLEFT", hdr.leftBar, "BOTTOMLEFT", 0, 0)
    hdr.botLine:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)

    return hdr
end

local function CreateToggleRow(parent, yOffset, title, desc, getter, setter)
    local surf = GetSurfaceColors()
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(60)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, yOffset)
    row.bg = SolidTex(row, "BACKGROUND", 1, surf.PANEL_BG.r, surf.PANEL_BG.g, surf.PANEL_BG.b, 0.96)
    row.bg:SetAllPoints()
    row.border = CreatePixelBorder(row, surf.CELL_BORDER.r, surf.CELL_BORDER.g, surf.CELL_BORDER.b, 0.95, 4)

    -- Option 3 Binary Toggle: [ Off (68) | Enabled (84) ] = 156x26
    local pillHolder = CreateFrame("Frame", nil, row)
    pillHolder:SetSize(156, 26)
    pillHolder:SetPoint("RIGHT", row, "RIGHT", -14, 0)

    local offBtn = CreateFrame("Button", nil, pillHolder)
    offBtn:SetSize(68, 26)
    offBtn:SetPoint("LEFT", pillHolder, "LEFT", 0, 0)
    offBtn.bg = SolidTex(offBtn, "BACKGROUND", 2, surf.CELL_BG.r, surf.CELL_BG.g, surf.CELL_BG.b, 0.96)
    offBtn.bg:SetAllPoints()
    offBtn.border = CreatePixelBorder(offBtn, surf.CELL_BORDER.r, surf.CELL_BORDER.g, surf.CELL_BORDER.b, 0.95, 4)
    offBtn.offBar = SolidTex(offBtn, "OVERLAY", 5, 0.973, 0.443, 0.443, 0.90)
    offBtn.offBar:SetHeight(1.5)
    offBtn.offBar:SetPoint("BOTTOMLEFT", offBtn, "BOTTOMLEFT", 1, 1)
    offBtn.offBar:SetPoint("BOTTOMRIGHT", offBtn, "BOTTOMRIGHT", -1, 1)
    offBtn.lbl = offBtn:CreateFontString(nil, "OVERLAY")
    offBtn.lbl:SetPoint("CENTER", offBtn, "CENTER", 0, 0)
    ApplyFont(offBtn.lbl, 11, "")
    offBtn.lbl:SetText("Off")

    local onBtn = CreateFrame("Button", nil, pillHolder)
    onBtn:SetSize(84, 26)
    onBtn:SetPoint("RIGHT", pillHolder, "RIGHT", 0, 0)
    onBtn.bg = SolidTex(onBtn, "BACKGROUND", 2, surf.CELL_BG.r, surf.CELL_BG.g, surf.CELL_BG.b, 0.96)
    onBtn.bg:SetAllPoints()
    onBtn.border = CreatePixelBorder(onBtn, surf.CELL_BORDER.r, surf.CELL_BORDER.g, surf.CELL_BORDER.b, 0.95, 4)
    onBtn.lbl = onBtn:CreateFontString(nil, "OVERLAY")
    onBtn.lbl:SetPoint("CENTER", onBtn, "CENTER", 0, 0)
    ApplyFont(onBtn.lbl, 11, "")
    onBtn.lbl:SetText("Enabled")

    local function Refresh()
        local active = (getter() == true)
        local ar, ag, ab = GetAccentColor()
        local fa = GetPillFillAlpha()
        local s = GetSurfaceColors()
        if active then
            onBtn.bg:SetColorTexture(ar * fa, ag * fa, ab * fa, 0.96)
            onBtn.border:SetColor(ar, ag, ab, 0.95)
            onBtn.lbl:SetTextColor(1, 1, 1, 1)
            offBtn.bg:SetColorTexture(s.CELL_BG.r, s.CELL_BG.g, s.CELL_BG.b, 0.96)
            offBtn.border:SetColor(s.CELL_BORDER.r, s.CELL_BORDER.g, s.CELL_BORDER.b, 0.95)
            offBtn.lbl:SetTextColor(0.58, 0.64, 0.72, 1)
            offBtn.offBar:Hide()
        else
            offBtn.bg:SetColorTexture(0.118, 0.141, 0.188, 0.98)
            offBtn.border:SetColor(0.392, 0.455, 0.545, 0.90)
            offBtn.lbl:SetTextColor(0.886, 0.910, 0.941, 1)
            offBtn.offBar:Show()
            onBtn.bg:SetColorTexture(s.CELL_BG.r, s.CELL_BG.g, s.CELL_BG.b, 0.96)
            onBtn.border:SetColor(s.CELL_BORDER.r, s.CELL_BORDER.g, s.CELL_BORDER.b, 0.95)
            onBtn.lbl:SetTextColor(0.58, 0.64, 0.72, 1)
        end
    end

    offBtn:SetScript("OnClick", function() setter(false); Refresh() end)
    onBtn:SetScript("OnClick", function() setter(true); Refresh() end)

    local tFs = row:CreateFontString(nil, "OVERLAY")
    tFs:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -9)
    tFs:SetPoint("RIGHT", pillHolder, "LEFT", -14, 0)
    tFs:SetJustifyH("LEFT")
    tFs:SetWordWrap(false)
    ApplyFont(tFs, 11.5, "")
    tFs:SetText(title)
    tFs:SetTextColor(0.97, 0.98, 1.0, 1)

    local dFs = row:CreateFontString(nil, "OVERLAY")
    dFs:SetPoint("TOPLEFT", tFs, "BOTTOMLEFT", 0, -3)
    dFs:SetPoint("RIGHT", pillHolder, "LEFT", -14, 0)
    dFs:SetJustifyH("LEFT")
    dFs:SetJustifyV("TOP")
    dFs:SetWordWrap(true)
    if dFs.SetMaxLines then dFs:SetMaxLines(2) end
    ApplyFont(dFs, 10, "")
    dFs:SetText(desc)
    dFs:SetTextColor(0.62, 0.68, 0.78, 1)

    Refresh()
    row.Refresh = Refresh
    return row
end

local function CreateSliderRow(parent, yOffset, title, desc, minVal, maxVal, stepVal, formatFn, getter, setter)
    local surf = GetSurfaceColors()
    local ar, ag, ab = GetAccentColor()
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(60)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, yOffset)
    row.bg = SolidTex(row, "BACKGROUND", 1, surf.PANEL_BG.r, surf.PANEL_BG.g, surf.PANEL_BG.b, 0.96)
    row.bg:SetAllPoints()
    row.border = CreatePixelBorder(row, surf.CELL_BORDER.r, surf.CELL_BORDER.g, surf.CELL_BORDER.b, 0.95, 4)

    -- 256x26px Sleek Precision Track Slider
    local holder = CreateFrame("Frame", nil, row)
    holder:SetSize(256, 26)
    holder:SetPoint("RIGHT", row, "RIGHT", -14, 0)

    local valText = holder:CreateFontString(nil, "OVERLAY")
    valText:SetWidth(52)
    valText:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
    valText:SetJustifyH("RIGHT")
    ApplyFont(valText, 11, "")
    valText:SetTextColor(ar, ag, ab, 1.0)

    local slider = CreateFrame("Slider", nil, holder)
    slider:SetHeight(4)
    slider:SetPoint("LEFT", holder, "LEFT", 0, 0)
    slider:SetPoint("RIGHT", valText, "LEFT", -10, 0)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(stepVal)
    slider:SetObeyStepOnDrag(false)
    slider:SetHitRectInsets(0, 0, -10, -10)
    slider:EnableMouseWheel(true)

    slider.bg = SolidTex(slider, "BACKGROUND", 1, 0.035, 0.039, 0.051, 0.98)
    slider.bg:SetAllPoints()
    slider.border = CreatePixelBorder(slider, 1, 1, 1, 0.14, 2)

    slider.fillBar = SolidTex(slider, "ARTWORK", 2, ar, ag, ab, 0.85)
    slider.fillBar:SetPoint("TOPLEFT", slider, "TOPLEFT", 1, -1)
    slider.fillBar:SetPoint("BOTTOMLEFT", slider, "BOTTOMLEFT", 1, 1)
    slider.fillBar:SetWidth(1)

    local thumb = slider:CreateTexture(nil, "OVERLAY", nil, 5)
    thumb:SetSize(6, 14)
    thumb:SetColorTexture(0.97, 0.98, 1.0, 1.0)
    if thumb.SetSnapToPixelGrid then thumb:SetSnapToPixelGrid(false) end
    if thumb.SetTexelSnappingBias then thumb:SetTexelSnappingBias(0) end
    slider:SetThumbTexture(thumb)

    local lastCommitted = nil
    local function UpdateVisual(v)
        local r, g, b = GetAccentColor()
        local pct = (maxVal > minVal) and ((v - minVal) / (maxVal - minVal)) or 0
        pct = math.max(0, math.min(1, pct))
        local w = math.max(10, slider:GetWidth() or 194)
        slider.fillBar:SetColorTexture(r, g, b, 0.85)
        slider.fillBar:SetWidth(math.max(1, pct * (w - 2)))
        valText:SetTextColor(r, g, b, 1.0)
        valText:SetText(formatFn and formatFn(v) or tostring(v))
    end

    slider:SetScript("OnValueChanged", function(_, value)
        local stepped = math.floor(((value - minVal) / stepVal) + 0.5) * stepVal + minVal
        stepped = math.max(minVal, math.min(maxVal, stepped))
        UpdateVisual(stepped)
        if stepped ~= lastCommitted then
            lastCommitted = stepped
            setter(stepped)
        end
    end)

    slider:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetValue()
        local nxt = math.max(minVal, math.min(maxVal, cur + (delta * stepVal)))
        self:SetValue(nxt)
    end)

    local tFs = row:CreateFontString(nil, "OVERLAY")
    tFs:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -9)
    tFs:SetPoint("RIGHT", holder, "LEFT", -14, 0)
    tFs:SetJustifyH("LEFT")
    tFs:SetWordWrap(false)
    ApplyFont(tFs, 11.5, "")
    tFs:SetText(title)
    tFs:SetTextColor(0.97, 0.98, 1.0, 1)

    local dFs = row:CreateFontString(nil, "OVERLAY")
    dFs:SetPoint("TOPLEFT", tFs, "BOTTOMLEFT", 0, -3)
    dFs:SetPoint("RIGHT", holder, "LEFT", -14, 0)
    dFs:SetJustifyH("LEFT")
    dFs:SetJustifyV("TOP")
    dFs:SetWordWrap(true)
    if dFs.SetMaxLines then dFs:SetMaxLines(2) end
    ApplyFont(dFs, 10, "")
    dFs:SetText(desc)
    dFs:SetTextColor(0.62, 0.68, 0.78, 1)

    local function Refresh()
        local v = SafeNum(getter(), minVal)
        lastCommitted = v
        slider:SetValue(v)
        UpdateVisual(v)
    end
    C_Timer.After(0, Refresh)
    row.Refresh = Refresh
    return row
end

local function CreateActionButton(parent, width, height, text, isAccent, onClick)
    local surf = GetSurfaceColors()
    local ar, ag, ab = GetAccentColor()
    local fa = GetPillFillAlpha()
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)
    if isAccent then
        btn.bg = SolidTex(btn, "BACKGROUND", 2, ar * fa, ag * fa, ab * fa, 0.96)
        btn.border = CreatePixelBorder(btn, ar, ag, ab, 0.95, 4)
    else
        btn.bg = SolidTex(btn, "BACKGROUND", 2, surf.CELL_BG.r, surf.CELL_BG.g, surf.CELL_BG.b, 0.96)
        btn.border = CreatePixelBorder(btn, surf.CELL_BORDER.r, surf.CELL_BORDER.g, surf.CELL_BORDER.b, 0.95, 4)
    end
    btn.bg:SetAllPoints()
    btn.lbl = btn:CreateFontString(nil, "OVERLAY")
    btn.lbl:SetPoint("CENTER", btn, "CENTER", 0, 0)
    ApplyFont(btn.lbl, 11, "")
    btn.lbl:SetText(text)
    btn.lbl:SetTextColor(1, 1, 1, 1)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function RenderDialogueEmbedded(parent)
    if not parent then return nil end
    local db = EnsureDB()
    local surf = GetSurfaceColors()
    local ar, ag, ab = GetAccentColor()

    if parent._ddRoot then
        parent._ddRoot:Show()
        if parent._ddRoot.RefreshAll then parent._ddRoot.RefreshAll() end
        activeEmbeddedRoot = parent._ddRoot
        return parent._ddRoot
    end

    local root = CreateFrame("Frame", nil, parent)
    root:SetAllPoints(parent)
    parent._ddRoot = root
    activeEmbeddedRoot = root

    -- 34px Obsidian Equal-Width 2-Tab Bar (#0B0D12, matches Suite standard)
    local tabBar = CreateFrame("Frame", nil, root)
    tabBar:SetHeight(34)
    tabBar:SetPoint("TOPLEFT", root, "TOPLEFT", 14, -10)
    tabBar:SetPoint("TOPRIGHT", root, "TOPRIGHT", -16, -10)
    tabBar.bg = SolidTex(tabBar, "BACKGROUND", 1, 0.043, 0.051, 0.071, 0.98)
    tabBar.bg:SetAllPoints()
    tabBar.border = CreatePixelBorder(tabBar, surf.CELL_BORDER.r, surf.CELL_BORDER.g, surf.CELL_BORDER.b, 0.95, 4)

    local activeSubTab = db.activeSubTab or 1
    if activeSubTab ~= 1 and activeSubTab ~= 2 then activeSubTab = 1 end

    local tabDefs = {
        { id = 1, label = "Reader & Controls" },
        { id = 2, label = "Appearance & Sound" },
    }
    local subTabBtns = {}
    for idx, td in ipairs(tabDefs) do
        local tb = CreateFrame("Button", nil, tabBar)
        tb:SetHeight(24)
        tb.bg = SolidTex(tb, "BACKGROUND", 1, surf.CELL_BG.r, surf.CELL_BG.g, surf.CELL_BG.b, 0.96)
        tb.bg:SetAllPoints()
        tb.border = CreatePixelBorder(tb, surf.CELL_BORDER.r, surf.CELL_BORDER.g, surf.CELL_BORDER.b, 0.95, 4)
        tb.txt = tb:CreateFontString(nil, "OVERLAY")
        tb.txt:SetPoint("CENTER", 0, 0)
        ApplyFont(tb.txt, 11, "")
        tb.txt:SetText(td.label)
        tb._tabId = td.id
        subTabBtns[idx] = tb
    end

    local function ReflowTabBar()
        local w = tabBar:GetWidth() or 700
        if w < 200 then w = 700 end
        local pad = 6
        local gap = 6
        local tabW = math.max(110, math.floor((w - (pad * 2) - gap) / 2))
        for i, tb in ipairs(subTabBtns) do
            tb:ClearAllPoints()
            tb:SetWidth(tabW)
            tb:SetPoint("LEFT", tabBar, "LEFT", pad + ((i - 1) * (tabW + gap)), 0)
        end
    end
    tabBar:SetScript("OnSizeChanged", ReflowTabBar)
    tabBar:HookScript("OnShow", function() C_Timer.After(0, ReflowTabBar) end)
    ReflowTabBar()

    -- ScrollFrame (-8px below 34px tabBar) + 4px 3-way Obsidian Scrollbar
    local sf = CreateFrame("ScrollFrame", nil, root)
    sf:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -8)
    sf:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", 0, -8)
    sf:SetPoint("BOTTOM", root, "BOTTOM", 0, 10)
    sf:SetClipsChildren(true)
    sf:EnableMouseWheel(true)

    local child = CreateFrame("Frame", nil, sf)
    child:SetWidth(760)
    child:SetHeight(520)
    sf:SetScrollChild(child)

    -- Dedicated 44px Action & Status Strip inside scrollable canvas
    local actionStrip = CreateFrame("Frame", nil, child)
    actionStrip:SetHeight(44)
    actionStrip:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    actionStrip:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, 0)
    actionStrip.bg = SolidTex(actionStrip, "BACKGROUND", 0, 0.043, 0.051, 0.071, 0.96)
    actionStrip.bg:SetAllPoints()
    actionStrip.border = CreatePixelBorder(actionStrip, surf.CELL_BORDER.r, surf.CELL_BORDER.g, surf.CELL_BORDER.b, 0.95, 4)

    local resetPosBtn = CreateActionButton(actionStrip, 112, 26, "Reset Position", false, function()
        DynamicDialogue:ResetPosition()
    end)
    resetPosBtn:SetPoint("RIGHT", actionStrip, "RIGHT", -12, 0)

    local previewBtn = CreateActionButton(actionStrip, 122, 26, "Preview Reader", true, function()
        DynamicDialogue:ShowPreview()
    end)
    previewBtn:SetPoint("RIGHT", resetPosBtn, "LEFT", -8, 0)

    local statusHit = CreateFrame("Frame", nil, actionStrip)
    statusHit:SetPoint("LEFT", actionStrip, "LEFT", 14, 0)
    statusHit:SetPoint("RIGHT", previewBtn, "LEFT", -12, 0)
    statusHit:SetHeight(26)
    statusHit:EnableMouse(true)

    local statusLbl = statusHit:CreateFontString(nil, "OVERLAY")
    statusLbl:SetPoint("LEFT", statusHit, "LEFT", 0, 0)
    statusLbl:SetPoint("RIGHT", statusHit, "RIGHT", 0, 0)
    statusLbl:SetJustifyH("LEFT")
    statusLbl:SetWordWrap(false)
    ApplyFont(statusLbl, 11, "")
    root.statusLbl = statusLbl
    root.statusTooltipText = ""
    statusHit:SetScript("OnEnter", function(s)
        if GameTooltip and root.statusTooltipText and root.statusTooltipText ~= "" then
            GameTooltip:SetOwner(s, "ANCHOR_BOTTOMLEFT")
            GameTooltip:AddLine("DynamicDialogue Status", 1, 1, 1)
            GameTooltip:AddLine(root.statusTooltipText, 0.80, 0.85, 0.92, true)
            GameTooltip:Show()
        end
    end)
    statusHit:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    local track = CreateFrame("Frame", nil, root)
    track:SetWidth(4)
    track:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 10, -2)
    track:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 10, 2)
    track:EnableMouse(true)
    track:SetHitRectInsets(-5, -5, 0, 0)
    track.bg = SolidTex(track, "BACKGROUND", 1, 0.043, 0.051, 0.071, 0.85)
    track.bg:SetAllPoints()

    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(4)
    thumb:SetHeight(48)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    thumb:EnableMouse(true)
    thumb:SetHitRectInsets(-5, -5, 0, 0)
    thumb.tex = SolidTex(thumb, "OVERLAY", 2, ar, ag, ab, 0.78)
    thumb.tex:SetAllPoints()

    local function UpdateScrollBar()
        if sf.UpdateScrollChildRect then pcall(sf.UpdateScrollChildRect, sf) end
        local nr, ng, nb = GetAccentColor()
        if thumb.isDragging then
            thumb.tex:SetColorTexture(nr, ng, nb, 1.0)
        elseif thumb.isHovered then
            thumb.tex:SetColorTexture(nr, ng, nb, 0.92)
        else
            thumb.tex:SetColorTexture(nr, ng, nb, 0.78)
        end
        local viewH = sf:GetHeight() or 0
        local totalH = child:GetHeight() or 0
        local trackH = track:GetHeight() or 0
        if viewH <= 1 or trackH <= 1 then return end
        local maxScroll = math.max(0, totalH - viewH)
        if maxScroll <= 1 then
            track:Hide()
            thumb:Hide()
            sf:SetVerticalScroll(0)
            return
        end
        track:Show()
        thumb:Show()
        local cur = math.max(0, math.min(maxScroll, sf:GetVerticalScroll() or 0))
        local thumbH = math.max(24, math.floor(trackH * math.min(1, viewH / totalH) + 0.5))
        local travel = math.max(1, trackH - thumbH)
        thumb:SetHeight(thumbH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -math.floor((cur / maxScroll) * travel + 0.5))
    end

    local function ScrollDialogueFromCursor()
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            thumb.isDragging = false
            thumb:SetScript("OnUpdate", nil)
            track:SetScript("OnUpdate", nil)
            UpdateScrollBar()
            return
        end
        local viewH = sf:GetHeight() or 0
        local totalH = child:GetHeight() or 0
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
        local ratio = math.max(0, math.min(1, (relY - (thumbH * 0.5)) / travel))
        sf:SetVerticalScroll(ratio * maxScroll)
        UpdateScrollBar()
    end

    thumb:SetScript("OnEnter", function(self)
        self.isHovered = true
        UpdateScrollBar()
    end)
    thumb:SetScript("OnLeave", function(self)
        self.isHovered = false
        UpdateScrollBar()
    end)
    thumb:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.isDragging = true
            ScrollDialogueFromCursor()
            self:SetScript("OnUpdate", ScrollDialogueFromCursor)
        end
    end)
    thumb:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.isDragging = false
            self:SetScript("OnUpdate", nil)
            UpdateScrollBar()
        end
    end)
    thumb:SetScript("OnHide", function(self)
        self.isDragging = false
        self.isHovered = false
        self:SetScript("OnUpdate", nil)
    end)
    track:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            thumb.isDragging = true
            ScrollDialogueFromCursor()
            self:SetScript("OnUpdate", ScrollDialogueFromCursor)
        end
    end)
    track:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            thumb.isDragging = false
            self:SetScript("OnUpdate", nil)
            UpdateScrollBar()
        end
    end)
    track:SetScript("OnHide", function(self)
        thumb.isDragging = false
        self:SetScript("OnUpdate", nil)
    end)

    local function ScrollByDelta(delta)
        local viewH = sf:GetHeight() or 0
        local totalH = child:GetHeight() or 0
        local maxScroll = math.max(0, totalH - viewH)
        sf:SetVerticalScroll(math.max(0, math.min(maxScroll, (sf:GetVerticalScroll() or 0) - (delta * 42))))
        UpdateScrollBar()
    end
    sf:SetScript("OnSizeChanged", function(_, w)
        if w and w > 100 then child:SetWidth(w) end
        UpdateScrollBar()
    end)
    sf:SetScript("OnShow", UpdateScrollBar)
    sf:SetScript("OnMouseWheel", function(_, delta) ScrollByDelta(delta) end)
    track:SetScript("OnMouseWheel", function(_, delta) ScrollByDelta(delta) end)
    thumb:SetScript("OnMouseWheel", function(_, delta) ScrollByDelta(delta) end)

    local refreshables = {}

    -- Tab 1: Reader & Controls (exact tight height for 60px rows + 8px gap + 14px bottom pad)
    local sec1 = CreateFrame("Frame", nil, child)
    sec1:SetPoint("TOPLEFT", actionStrip, "BOTTOMLEFT", 0, -10)
    sec1:SetPoint("TOPRIGHT", actionStrip, "BOTTOMRIGHT", 0, -10)
    local sec1H = 54 + (6 * 68) - 8 + 14 -- 468px
    sec1:SetHeight(sec1H)
    sec1.bg = SolidTex(sec1, "BACKGROUND", 0, surf.CARD_BG.r, surf.CARD_BG.g, surf.CARD_BG.b, 0.96)
    sec1.bg:SetAllPoints()
    sec1.border = CreatePixelBorder(sec1, surf.CELL_BORDER.r, surf.CELL_BORDER.g, surf.CELL_BORDER.b, 0.95, 4)

    local sec1Hdr = CreateSectionHeader(sec1, "QUEST & GOSSIP READER", "Clean, easy-to-read dialogue window with 1-9 option keys and Spacebar confirm.", -10)

    local rows1 = {
        CreateToggleRow(sec1, -54,  "Enable DynamicDialogue Reader", "Master switch for the Obsidian Quest & Gossip reader.",
            function() return db.enabled == true end,
            function(v) db.enabled = v; if not v then CloseActiveInteraction() end; if root.RefreshStatus then root.RefreshStatus() end end),
        CreateToggleRow(sec1, -122, "Replace Quest Dialogue Windows", "Present Quest Detail, Progress, Greeting, and Turn-In in Obsidian cards with reward tooltips.",
            function() return db.replaceQuests ~= false end,
            function(v) db.replaceQuests = v end),
        CreateToggleRow(sec1, -190, "Replace NPC Gossip Windows", "Present NPC gossip menus in a clean Obsidian reader with numbered option buttons.",
            function() return db.replaceGossip ~= false end,
            function(v) db.replaceGossip = v end),
        CreateToggleRow(sec1, -258, "1-9 Number Option Hotkeys", "Press keys 1 through 9 out of combat to pick gossip or quest options immediately.",
            function() return db.enableNumberHotkeys ~= false end,
            function(v) db.enableNumberHotkeys = v end),
        CreateToggleRow(sec1, -326, "Space Bar Accept & Complete", "Press Space out of combat to Accept, Continue, or Complete the active quest.",
            function() return db.enableSpaceConfirm ~= false end,
            function(v) db.enableSpaceConfirm = v end),
        CreateToggleRow(sec1, -394, "Hold Shift for Native Blizzard Frame", "Hold Shift while interacting with an NPC to bypass DynamicDialogue for that interaction.",
            function() return db.shiftBypassNative ~= false end,
            function(v) db.shiftBypassNative = v end),
    }
    for _, r in ipairs(rows1) do table.insert(refreshables, r) end

    -- Tab 2: Appearance & Sound (exact tight height; auto-yielding managed centrally in Guided Setup)
    local sec2 = CreateFrame("Frame", nil, child)
    sec2:SetPoint("TOPLEFT", actionStrip, "BOTTOMLEFT", 0, -10)
    sec2:SetPoint("TOPRIGHT", actionStrip, "BOTTOMRIGHT", 0, -10)
    local sec2H = 54 + (4 * 68) - 8 + 14 -- 332px
    sec2:SetHeight(sec2H)
    sec2.bg = SolidTex(sec2, "BACKGROUND", 0, surf.CARD_BG.r, surf.CARD_BG.g, surf.CARD_BG.b, 0.96)
    sec2.bg:SetAllPoints()
    sec2.border = CreatePixelBorder(sec2, surf.CELL_BORDER.r, surf.CELL_BORDER.g, surf.CELL_BORDER.b, 0.95, 4)

    local sec2Hdr = CreateSectionHeader(sec2, "APPEARANCE & SOUND", "Adjust reader scale, panel opacity, body text size, and quest completion chime.", -10)

    local rows2 = {
        CreateSliderRow(sec2, -54, "Reader Scale", "Adjust overall size of the Obsidian dialogue reader (70% - 140%).",
            0.70, 1.40, 0.05, function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return db.frameScale or 1.0 end,
            function(v) db.frameScale = v; DynamicDialogue:ApplyReaderTheme() end),
        CreateSliderRow(sec2, -122, "Backdrop Opacity", "Control Obsidian panel opacity behind quest text (50% - 100%).",
            0.50, 1.00, 0.05, function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            function() return db.backdropAlpha or 0.96 end,
            function(v) db.backdropAlpha = v; DynamicDialogue:ApplyReaderTheme() end),
        CreateSliderRow(sec2, -190, "Dialogue Font Size", "Body text size for quest descriptions and gossip lore (11pt - 18pt).",
            11, 18, 1, function(v) return string.format("%dpt", math.floor(v + 0.5)) end,
            function() return db.fontSize or 13 end,
            function(v) db.fontSize = v; DynamicDialogue:ApplyReaderTheme() end),
        CreateToggleRow(sec2, -258, "Quest Complete Signature Chime", "Play the DynamicSuite Bloom chime when completing a quest.",
            function() return db.playCompleteChime ~= false end,
            function(v) db.playCompleteChime = v end),
    }
    for _, r in ipairs(rows2) do table.insert(refreshables, r) end

    local function ApplySubTab()
        local nr, ng, nb = GetAccentColor()
        local pAlpha = GetPillFillAlpha()
        sec1:SetShown(activeSubTab == 1)
        sec2:SetShown(activeSubTab == 2)
        child:SetHeight(44 + 10 + ((activeSubTab == 1) and sec1H or sec2H) + 12)
        sf:SetVerticalScroll(0)
        for _, tb in ipairs(subTabBtns) do
            if tb._tabId == activeSubTab then
                tb.bg:SetColorTexture(nr * pAlpha, ng * pAlpha, nb * pAlpha, 0.98)
                tb.border:SetColor(nr, ng, nb, 0.95)
                tb.txt:SetTextColor(1, 1, 1, 1)
            else
                tb.bg:SetColorTexture(surf.CELL_BG.r, surf.CELL_BG.g, surf.CELL_BG.b, 0.96)
                tb.border:SetColor(surf.CELL_BORDER.r, surf.CELL_BORDER.g, surf.CELL_BORDER.b, 0.95)
                tb.txt:SetTextColor(0.75, 0.80, 0.88, 1)
            end
        end
        UpdateScrollBar()
    end

    for _, tb in ipairs(subTabBtns) do
        tb:SetScript("OnClick", function()
            activeSubTab = tb._tabId
            db.activeSubTab = tb._tabId
            ApplySubTab()
        end)
    end

    local function RefreshStatus()
        local yielding, label, reason = DynamicDialogue:GetYieldInfo()
        if yielding then
            statusLbl:SetText("|cFFFACC15Yielding|r  |cFF94A3B8-> " .. tostring(label or "External Addon") .. "|r")
            root.statusTooltipText = "Automatically yielding to " .. tostring(label or "External Addon") .. " (" .. tostring(reason or "Active") .. "). Manage competing addons in Guided Setup."
        elseif db.enabled then
            statusLbl:SetText("|cFF22C55EActive|r  |cFF94A3B8- Obsidian Reader Ready|r")
            root.statusTooltipText = "Active - Talk to any quest giver or gossip NPC to open the Obsidian reader."
        else
            statusLbl:SetText("|cFFF87171Paused|r  |cFF94A3B8- Reader Disabled|r")
            root.statusTooltipText = "Paused - Enable DynamicDialogue Reader below to activate the Obsidian Quest & Gossip reader."
        end
    end
    root.RefreshStatus = RefreshStatus

    root.RefreshAll = function()
        local nr, ng, nb = GetAccentColor()
        for _, hdr in ipairs({ sec1Hdr, sec2Hdr }) do
            if hdr then
                if hdr.leftBar then hdr.leftBar:SetColorTexture(nr, ng, nb, 1.0) end
                if hdr.title then hdr.title:SetTextColor(nr, ng, nb, 1.0) end
                if hdr.botLine then hdr.botLine:SetColorTexture(nr, ng, nb, 0.35) end
            end
        end
        ApplySubTab()
        RefreshStatus()
        for _, r in ipairs(refreshables) do
            if r.Refresh then r.Refresh() end
        end
    end
    ApplySubTab()
    RefreshStatus()

    return root
end

function DynamicDialogue:ApplyTheme()
    self:ApplyReaderTheme()
    if activeEmbeddedRoot and activeEmbeddedRoot.RefreshAll then
        activeEmbeddedRoot.RefreshAll()
    end
end

function DynamicDialogue:ResetModuleDefaults()
    _G.DynamicDialogueDB = {}
    EnsureDB()
    self:ResetPosition()
    self:ApplyReaderTheme()
    if activeEmbeddedRoot and activeEmbeddedRoot.RefreshAll then
        activeEmbeddedRoot.RefreshAll()
    end
    Print("All DynamicDialogue settings reset to defaults.")
end

function DynamicDialogue:Open()
    if _G.DynamicSuite and type(_G.DynamicSuite.OpenModule) == "function" and not IsModuleDisabledInSuite() then
        _G.DynamicSuite:OpenModule("dialogue")
        return
    end
    if not standaloneFrame then
        local surf = GetSurfaceColors()
        local ar, ag, ab = GetAccentColor()
        local sf = CreateFrame("Frame", "DynamicDialogueStandaloneFrame", UIParent)
        sf:SetSize(820, 620)
        sf:SetPoint("CENTER")
        sf:SetFrameStrata("DIALOG")
        sf:SetMovable(true)
        sf:EnableMouse(true)
        sf:SetClampedToScreen(true)
        sf:RegisterForDrag("LeftButton")
        sf:SetScript("OnDragStart", sf.StartMoving)
        sf:SetScript("OnDragStop", sf.StopMovingOrSizing)
        sf.bg = SolidTex(sf, "BACKGROUND", 0, surf.PANEL_BG.r, surf.PANEL_BG.g, surf.PANEL_BG.b, 0.99)
        sf.bg:SetAllPoints()
        sf.border = CreatePixelBorder(sf, ar, ag, ab, 0.90, 6)

        local hdr = CreateFrame("Frame", nil, sf)
        hdr:SetHeight(40)
        hdr:SetPoint("TOPLEFT", sf, "TOPLEFT", 1, -1)
        hdr:SetPoint("TOPRIGHT", sf, "TOPRIGHT", -1, -1)
        hdr.bg = SolidTex(hdr, "BACKGROUND", 1, surf.HEADER_BG.r, surf.HEADER_BG.g, surf.HEADER_BG.b, 1.0)
        hdr.bg:SetAllPoints()
        local title = hdr:CreateFontString(nil, "OVERLAY")
        title:SetPoint("LEFT", hdr, "LEFT", 14, 0)
        ApplyFont(title, 14, "OUTLINE")
        title:SetText("|cFFCBD5E1Dynamic|r|cFFFFFFFFDialogue|r  |cFF94A3B8v" .. VERSION .. "|r")

        local closeBtn = CreateActionButton(hdr, 28, 24, "X", false, function() sf:Hide() end)
        closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -8, 0)

        local body = CreateFrame("Frame", nil, sf)
        body:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, 0)
        body:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 0, 0)
        RenderDialogueEmbedded(body)

        table.insert(UISpecialFrames, "DynamicDialogueStandaloneFrame")
        standaloneFrame = sf
    end
    standaloneFrame:Show()
end

-- ============================================================================
-- 6. SUITE REGISTRATION & CHANGELOG
-- ============================================================================
DynamicDialogue.CHANGELOG = {
    {
        version = VERSION,
        date = "21/11/2026",
        entries = {
            { type = "UI",      text = "Release v2.7.0 (21/11/2026): Upgraded DynamicDialogue to the universal 34px #0B0D12 equal-width 2-tab header bar, dedicated 44px Action & Status strip inside the settings canvas, crisp non-outlined card fonts, standardised 156x26px (68px Off / 84px Enabled) binary switches, and 2-line wrapped descriptions so every row fits cleanly down to 800x520." },
            { type = "FIX",     text = "Release v2.6.9 (21/11/2026): Fixed first-open FontString rendering and overlapping sub-tab cards, added the 4px Obsidian settings scrollbar, matched standalone title colours, and fixed the Retail 12.1.5 Blizzard Quest/Gossip conflict check so clean installs show Active cleanly." },
            { type = "FEATURE", text = "Initial Release of DynamicDialogue (20/11/2026): High-contrast Obsidian Quest & Gossip Reader with 1-9 number hotkeys, Space bar Accept/Continue/Complete, interactive reward choice cards with item tooltips, Shift-bypass for native Blizzard frames, draggable reader positioning, live Preview mode, and automatic yielding for DialogueUI, Immersion, Storyline, EllesmereUI QoL, and other dialogue addons." },
        },
    },
}

local function RegisterWithDynamicSuite()
    if type(_G.DynamicSuite) ~= "table" then return end
    _G.DynamicSuite.modules = _G.DynamicSuite.modules or {}
    _G.DynamicSuite.Changelogs = _G.DynamicSuite.Changelogs or {}
    _G.DynamicSuite.Changelogs["DynamicDialogue"] = DynamicDialogue.CHANGELOG
    _G.DynamicSuite.Changelogs["dialogue"] = DynamicDialogue.CHANGELOG

    local registration = {
        key          = "DynamicDialogue",
        name         = "DynamicDialogue",
        title        = "DynamicDialogue",
        subtitle     = "Obsidian Quest & Gossip Reader",
        version      = VERSION,
        order        = 85,
        icon         = ICON_COLOR,
        fallbackIcon = ICON_COLOR,
        iconWhite    = ICON_WHITE,
        iconAccent   = ICON_ACCENT,
        slash        = "/dd",
        category     = "Quest & Gossip Dialogue Reader",
        desc         = "Clean, easy-to-read Quest and Gossip reader with 1-9 option hotkeys, Spacebar accept and turn-in, clear reward cards, and automatic yielding to other dialogue addons.",
        conflictRegistry = {
            conflicts        = { "DialogueUI", "DialogUI", "Immersion", "Storyline" },
            hardConflicts    = { "DialogueUI", "DialogUI", "Immersion", "Storyline" },
            partialConflicts = { "EllesmereUIQoL", "EllesmereUI_QoL", "EnhanceQoL", "AutoTurnIn", "Leatrix_Plus" },
            softConflicts    = { "EllesmereUIQoL", "EllesmereUI_QoL", "EnhanceQoL", "AutoTurnIn", "Leatrix_Plus" },
            category         = "Quest & Gossip Dialogue Reader",
        },
        GetStatusText = function() return DynamicDialogue:GetStatusText() end,
        RenderEmbedded = function(a, b)
            local parent = (type(a) == "table" and a.CreateFrame == nil and b) and b or a
            return RenderDialogueEmbedded(parent)
        end,
        RenderUI = function(a, b)
            local parent = (type(a) == "table" and a.CreateFrame == nil and b) and b or a
            return RenderDialogueEmbedded(parent)
        end,
        ApplyTheme          = function() DynamicDialogue:ApplyTheme() end,
        ApplyThemeToUI      = function() DynamicDialogue:ApplyTheme() end,
        RefreshTheme        = function() DynamicDialogue:ApplyTheme() end,
        ResetDefaults       = function() DynamicDialogue:ResetModuleDefaults() end,
        ResetModuleDefaults = function() DynamicDialogue:ResetModuleDefaults() end,
        ResetModule         = function() DynamicDialogue:ResetModuleDefaults() end,
        Reset               = function() DynamicDialogue:ResetModuleDefaults() end,
        changelog           = DynamicDialogue.CHANGELOG,
    }

    _G.DynamicSuite.modules["dialogue"]        = registration
    _G.DynamicSuite.modules["DynamicDialogue"] = registration
    if type(_G.DynamicSuite.RegisterModule) == "function" then
        pcall(_G.DynamicSuite.RegisterModule, _G.DynamicSuite, registration)
    end
end

-- ============================================================================
-- 7. EVENTS & SLASH COMMANDS
-- ============================================================================
local evt = CreateFrame("Frame")
evt:RegisterEvent("ADDON_LOADED")
evt:RegisterEvent("PLAYER_LOGIN")
evt:RegisterEvent("GOSSIP_SHOW")
evt:RegisterEvent("GOSSIP_CLOSED")
evt:RegisterEvent("QUEST_GREETING")
evt:RegisterEvent("QUEST_DETAIL")
evt:RegisterEvent("QUEST_PROGRESS")
evt:RegisterEvent("QUEST_COMPLETE")
evt:RegisterEvent("QUEST_FINISHED")
evt:RegisterEvent("PLAYER_REGEN_DISABLED")

evt:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_FOLDER or arg1 == "DynamicSuite" or arg1 == "DynamicDialogue" then
            EnsureDB()
            RegisterWithDynamicSuite()
        end
    elseif event == "PLAYER_LOGIN" then
        EnsureDB()
        RegisterWithDynamicSuite()
    elseif event == "GOSSIP_SHOW" then
        -- Yield 1 frame so DynamicPrep's instant single-option auto-confirm can fire first without flicker
        C_Timer.After(0, function()
            if _G.GossipFrame and _G.GossipFrame:IsShown() then
                DynamicDialogue:ShowGossip()
            end
        end)
    elseif event == "QUEST_GREETING" then
        C_Timer.After(0, function()
            if _G.QuestFrame and _G.QuestFrame:IsShown() then
                DynamicDialogue:ShowQuestGreeting()
            end
        end)
    elseif event == "QUEST_DETAIL" then
        C_Timer.After(0, function()
            if _G.QuestFrame and _G.QuestFrame:IsShown() then
                DynamicDialogue:ShowQuestDetail()
            end
        end)
    elseif event == "QUEST_PROGRESS" then
        C_Timer.After(0, function()
            if _G.QuestFrame and _G.QuestFrame:IsShown() then
                DynamicDialogue:ShowQuestProgress()
            end
        end)
    elseif event == "QUEST_COMPLETE" then
        C_Timer.After(0, function()
            if _G.QuestFrame and _G.QuestFrame:IsShown() then
                DynamicDialogue:ShowQuestComplete()
            end
        end)
    elseif event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" then
        if currentMode ~= "PREVIEW" then
            currentMode = nil
            selectedChoiceIndex = nil
            wipe(currentOptions)
            if readerFrame then readerFrame:Hide() end
            RestoreBlizzardFrame()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        local db = EnsureDB()
        if db.hideInCombat ~= false and readerFrame and readerFrame:IsShown() then
            readerFrame:Hide()
        end
    end
end)

_G.DynamicDialogue_OnAddonCompartmentClick = function()
    DynamicDialogue:Open()
end

_G.SLASH_DYNAMICDIALOGUE1 = "/dd"
_G.SLASH_DYNAMICDIALOGUE2 = "/ddlg"
_G.SLASH_DYNAMICDIALOGUE3 = "/dynamicdialogue"
_G.SlashCmdList["DYNAMICDIALOGUE"] = function(msg)
    local cmd = strtrim((msg or ""):lower())
    if cmd == "preview" or cmd == "test" then
        DynamicDialogue:ShowPreview()
    elseif cmd == "reset" then
        DynamicDialogue:ResetPosition()
    elseif cmd == "status" then
        local yielding, label, reason = DynamicDialogue:GetYieldInfo()
        if yielding then
            Print("Status: Yielding to " .. tostring(label) .. " (" .. tostring(reason or "") .. ").")
        else
            Print("Status: " .. DynamicDialogue:GetStatusText() .. ".")
        end
    else
        DynamicDialogue:Open()
    end
end
