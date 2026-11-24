-- ============================================================================
-- DynamicDialogue - Obsidian Quest & Gossip Reader
-- World of Warcraft Retail (12.1.5 / 12.1.7, Interface 120105, 120107)
-- Pure ASCII Only (NonASCII: 0, HasBOM: False) | Zero-Taint Midnight Engine
-- ============================================================================

local addonName = ...
local ADDON_FOLDER = (type(addonName) == "string" and addonName ~= "") and addonName or "DynamicSuite"

local function ResolveAddonVersion(folderName, fallback)
    local fb = fallback or "2.9.1"
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

local VERSION = ResolveAddonVersion(ADDON_FOLDER, "2.9.1")
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
    { addon = "DialogueUI", label = "DialogueUI" },
    { addon = "DialogUI",   label = "DialogUI" },
    { addon = "Immersion",  label = "Immersion" },
    { addon = "Storyline",  label = "Storyline" },
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

    -- Layer 1: Exact known competing dialogue replacement addons (never skinning-only addons)
    for _, entry in ipairs(KNOWN_DIALOGUE_ADDONS) do
        if SafeIsAddOnLoaded(entry.addon) then
            return true, entry.label, entry.label .. " is loaded"
        end
    end

    -- Layer 1b: Smart feature-level check for EllesmereUI QoL (only when dialogue replacement is explicitly enabled)
    if SafeIsAddOnLoaded("EllesmereUIQoL") or SafeIsAddOnLoaded("EllesmereUI_QoL") then
        local eq = _G.EllesmereUIQoLDB or (_G.EllesmereUIDB and _G.EllesmereUIDB.qol)
        if type(eq) == "table" then
            if eq.dialogueUI == true or eq.dialogUI == true or eq.questDialogue == true or eq.gossipReplacement == true then
                return true, "EllesmereUI Quality of Life", "EllesmereUI QoL dialogue replacement is enabled"
            end
        end
    end

    -- Layer 2: Central DynamicSuite read-only conflict probe (explicitly ignores skinning-only addons)
    if _G.DynamicSuite and type(_G.DynamicSuite.ProbeBlizzardFrameConflict) == "function" then
        local ok, conflicted, ownerLabel, reason = pcall(_G.DynamicSuite.ProbeBlizzardFrameConflict, _G.DynamicSuite, "DIALOGUE")
        if ok and conflicted == true then
            return true, ownerLabel or "External Dialogue Addon", reason or "Another dialogue addon is active"
        end
    end

    return false, nil, nil
end

function DynamicDialogue:IsYielding()
    local yielding = self:GetYieldInfo()
    return yielding == true
end

function DynamicDialogue:GetDetailedStatus()
    if IsModuleDisabledInSuite() then
        return "Paused", "Paused (Off in Sidebar)", "DynamicDialogue is switched off in the DynamicSuite sidebar."
    end
    local db = EnsureDB()
    if not db.enabled then
        return "Paused", "Paused", "Reader is switched off in DynamicDialogue settings (/dd to turn it back on)."
    end
    if db.replaceQuests == false and db.replaceGossip == false then
        return "Paused", "Paused", "Both Quest and NPC Gossip replacement are switched off in /dd settings."
    end
    local yielding, addonLabel, reason = self:GetYieldInfo()
    if yielding then
        local who = tostring(addonLabel or "External Addon")
        local why = (type(reason) == "string" and reason ~= "") and reason or "active"
        return "Yielding", "Yielding (" .. who .. ")", "Standing aside for " .. who .. " (" .. why .. ")."
    end
    if db.replaceQuests ~= false and db.replaceGossip ~= false then
        return "Active", "Active", "Replacing Quest and NPC Gossip windows (hold Shift while talking to use Blizzard's default window)."
    elseif db.replaceQuests ~= false then
        return "Active", "Active", "Replacing Quest windows only (NPC Gossip is set to Blizzard's default window)."
    end
    return "Active", "Active", "Replacing NPC Gossip windows only (Quests are set to Blizzard's default window)."
end

function DynamicDialogue:GetStatusText()
    local _, shortLabel = self:GetDetailedStatus()
    return shortLabel
end

-- ============================================================================
-- 4. OBSIDIAN IN-GAME QUEST & GOSSIP READER ENGINE
-- ============================================================================
local readerFrame = nil
local currentMode = nil       -- "GOSSIP", "GREETING", "DETAIL", "PROGRESS", "COMPLETE", "CONFIRM", "PREVIEW"
local activeSessionKind = nil -- "GOSSIP", "QUEST", "CONFIRM", "PREVIEW"
local activeConfirmKind = nil -- "GOSSIP", "QUEST_ACCEPT", "BINDER"
local activeConfirmDestructive = false
local confirmEnteredAt = 0
local currentOptions = {}     -- { { label, tag, tagColor, icon, iconDesaturated, onClick } }
local selectedChoiceIndex = nil
local suppressedFrames = {}
local pendingCombatRestore = {}
local suppressionHooked = {}
local applyingSuppression = {}
local activeBypassGossip = false
local interactionSeq = 0

local function IsCustomGossipTextureKit(eventTextureKit)
    if _G.DelvesDifficultyPickerFrame and _G.DelvesDifficultyPickerFrame.IsShown and _G.DelvesDifficultyPickerFrame:IsShown() then
        return true, "delves-difficulty-picker"
    end
    if _G.DelvesCompanionConfigurationFrame and _G.DelvesCompanionConfigurationFrame.IsShown and _G.DelvesCompanionConfigurationFrame:IsShown() then
        return true, "delves-companion"
    end
    if _G.LorewalkingFrame and _G.LorewalkingFrame.IsShown and _G.LorewalkingFrame:IsShown() then
        return true, "lorewalking"
    end
    if type(eventTextureKit) == "string" and not SafeIsSecret(eventTextureKit) and eventTextureKit ~= "" then
        if eventTextureKit:lower() ~= "default" then
            return true, eventTextureKit
        end
    end
    local gf = _G.GossipFrame
    local gfKit = gf and gf.textureKit
    if type(gfKit) == "string" and not SafeIsSecret(gfKit) and gfKit ~= "" then
        if gfKit:lower() ~= "default" then
            return true, gfKit
        end
    end
    return false, nil
end

local function SnapshotFramePoints(bf)
    local pts = {}
    if type(bf.GetNumPoints) == "function" and type(bf.GetPoint) == "function" then
        local okN, numPts = pcall(bf.GetNumPoints, bf)
        if okN and type(numPts) == "number" and numPts > 0 then
            for i = 1, numPts do
                local okP, pt, relTo, relPt, x, y = pcall(bf.GetPoint, bf, i)
                if okP and pt then
                    table.insert(pts, { pt, relTo, relPt, SafeNum(x, 0), SafeNum(y, 0) })
                end
            end
        end
    end
    return pts
end

local function ApplySuppressionLock(bf)
    if not bf or InCombatLockdown() or applyingSuppression[bf] then return end
    if bf.IsForbidden and bf:IsForbidden() then return end
    applyingSuppression[bf] = true
    pcall(function()
        if type(bf.SetAlpha) == "function" then
            bf:SetAlpha(0)
        end
        if type(bf.EnableMouse) == "function" then
            bf:EnableMouse(false)
        end
        if type(bf.SetClampedToScreen) == "function" then
            bf:SetClampedToScreen(false)
        end
        if type(bf.ClearAllPoints) == "function" and type(bf.SetPoint) == "function" and _G.UIParent then
            bf:ClearAllPoints()
            bf:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", -10000, 10000)
        end
    end)
    applyingSuppression[bf] = nil
end

local function EnsureSuppressionHooks(bf)
    if not bf or suppressionHooked[bf] then return end
    if bf.IsForbidden and bf:IsForbidden() then return end
    suppressionHooked[bf] = true

    if type(bf.HookScript) == "function" then
        pcall(bf.HookScript, bf, "OnShow", function(self)
            if suppressedFrames[self] and not applyingSuppression[self] and not InCombatLockdown() then
                ApplySuppressionLock(self)
            end
        end)
    end
    if type(_G.hooksecurefunc) == "function" then
        if type(bf.SetAlpha) == "function" then
            pcall(_G.hooksecurefunc, bf, "SetAlpha", function(self)
                if suppressedFrames[self] and not applyingSuppression[self] and not InCombatLockdown() then
                    ApplySuppressionLock(self)
                end
            end)
        end
        if type(bf.SetPoint) == "function" then
            pcall(_G.hooksecurefunc, bf, "SetPoint", function(self)
                if suppressedFrames[self] and not applyingSuppression[self] and not InCombatLockdown() then
                    ApplySuppressionLock(self)
                end
            end)
        end
    end
end

local function SuppressBlizzardFrame(bf)
    if not bf or InCombatLockdown() then return end
    if bf.IsForbidden and bf:IsForbidden() then return end
    if not suppressedFrames[bf] then
        local pending = pendingCombatRestore[bf]
        pendingCombatRestore[bf] = nil
        if pending then
            suppressedFrames[bf] = pending
        else
            local okA, curA = pcall(bf.GetAlpha, bf)
            local okM, curM = pcall(bf.IsMouseEnabled, bf)
            local okC, curC = pcall(bf.IsClampedToScreen, bf)
            local pts = SnapshotFramePoints(bf)
            if #pts == 1 and math.abs((pts[1][4] or 0) + 10000) < 1 and math.abs((pts[1][5] or 0) - 10000) < 1 then
                pts = {}
            end
            suppressedFrames[bf] = {
                origAlpha   = (okA and type(curA) == "number" and curA > 0.05) and curA or 1,
                origMouse   = (not okM or curM ~= false),
                origClamped = (not okC or curC ~= false),
                origPoints  = pts,
            }
        end
    end
    EnsureSuppressionHooks(bf)
    ApplySuppressionLock(bf)
end

local function ApplySavedFrameRestore(bf, saved)
    if not bf or not saved then return end
    if bf.IsForbidden and bf:IsForbidden() then return end
    pcall(function()
        if type(bf.SetAlpha) == "function" then
            bf:SetAlpha(saved.origAlpha or 1)
        end
        if InCombatLockdown() then
            pendingCombatRestore[bf] = saved
            return
        end
        pendingCombatRestore[bf] = nil
        if type(bf.SetClampedToScreen) == "function" then
            bf:SetClampedToScreen(saved.origClamped ~= false)
        end
        if type(bf.EnableMouse) == "function" then
            bf:EnableMouse(saved.origMouse ~= false)
        end
        if type(bf.ClearAllPoints) == "function" and type(bf.SetPoint) == "function" then
            bf:ClearAllPoints()
            local pts = saved.origPoints
            if type(pts) == "table" and #pts > 0 then
                for _, pt in ipairs(pts) do
                    bf:SetPoint(pt[1], pt[2] or _G.UIParent, pt[3] or pt[1], pt[4] or 0, pt[5] or 0)
                end
            elseif _G.UIParent then
                bf:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 16, -116)
            end
        end
    end)
end

local function RestoreBlizzardFrame(bf)
    if not bf then return end
    local saved = suppressedFrames[bf]
    suppressedFrames[bf] = nil
    if not saved then return end
    ApplySavedFrameRestore(bf, saved)
end

local function RestoreAllBlizzardFrames()
    local list = {}
    for bf in pairs(suppressedFrames) do
        table.insert(list, bf)
    end
    for _, bf in ipairs(list) do
        RestoreBlizzardFrame(bf)
    end
end

local function FlushPendingCombatRestores()
    if InCombatLockdown() then return end
    local list = {}
    for bf, saved in pairs(pendingCombatRestore) do
        if not suppressedFrames[bf] then
            table.insert(list, { bf = bf, saved = saved })
        end
    end
    for _, entry in ipairs(list) do
        pendingCombatRestore[entry.bf] = nil
        ApplySavedFrameRestore(entry.bf, entry.saved)
    end
end

function DynamicDialogue:IsHandlingBlizzardFrame(frameName)
    if frameName == "GossipFrame" then
        if _G.GossipFrame and suppressedFrames[_G.GossipFrame] ~= nil then
            return true
        end
        if activeBypassGossip then
            return false
        end
        return self:ShouldIntercept("GOSSIP")
    elseif frameName == "QuestFrame" then
        if _G.QuestFrame and suppressedFrames[_G.QuestFrame] ~= nil then
            return true
        end
        return self:ShouldIntercept("QUEST")
    end
    return false
end

local function IsStaticPopupVisible(which)
    if type(which) ~= "string" or which == "" or type(_G.StaticPopup_Visible) ~= "function" then
        return false
    end
    local ok, shown = pcall(_G.StaticPopup_Visible, which)
    return (ok and not SafeIsSecret(shown) and shown ~= nil and shown ~= false) and true or false
end

local function HideStaticPopupSafe(which)
    if type(which) == "string" and which ~= "" and type(_G.StaticPopup_Hide) == "function" then
        pcall(_G.StaticPopup_Hide, which)
    end
end

local function WasGossipConfirmAutoHandledByPrep(gossipID)
    local dp = _G.DynamicPrep
    if type(dp) ~= "table" or type(dp._lastAutoConfirmedGossipAt) ~= "number" then
        return false
    end
    local now = (type(_G.GetTime) == "function") and _G.GetTime() or 0
    if (now - dp._lastAutoConfirmedGossipAt) > 0.40 then
        return false
    end
    if gossipID ~= nil and dp._lastAutoConfirmedGossipID ~= nil then
        return dp._lastAutoConfirmedGossipID == gossipID
    end
    return true
end

local DESTRUCTIVE_CONFIRM_KEYWORDS = {
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
}

local function IsDestructiveConfirmText(rawText)
    if SafeIsSecret(rawText) or type(rawText) ~= "string" or rawText == "" then
        return false
    end
    local lower = rawText:lower()
    for i = 1, #DESTRUCTIVE_CONFIRM_KEYWORDS do
        if lower:find(DESTRUCTIVE_CONFIRM_KEYWORDS[i], 1, true) then
            return true
        end
    end
    return false
end

local function CloseConfirmInteraction()
    currentMode = nil
    activeSessionKind = nil
    activeConfirmKind = nil
    activeConfirmDestructive = false
    selectedChoiceIndex = nil
    wipe(currentOptions)
    if readerFrame and readerFrame:IsShown() and not InCombatLockdown() then
        readerFrame:Hide()
    end
    RestoreAllBlizzardFrames()
end

local function CloseActiveInteraction()
    local mode = currentMode
    local sess = activeSessionKind
    currentMode = nil
    activeSessionKind = nil
    activeConfirmKind = nil
    activeConfirmDestructive = false
    selectedChoiceIndex = nil
    wipe(currentOptions)
    if readerFrame then
        readerFrame:Hide()
    end
    RestoreAllBlizzardFrames()
    if mode == "GOSSIP" or sess == "GOSSIP" then
        if _G.C_GossipInfo and type(_G.C_GossipInfo.CloseGossip) == "function" then
            pcall(_G.C_GossipInfo.CloseGossip)
        elseif type(_G.CloseGossip) == "function" then
            pcall(_G.CloseGossip)
        end
    elseif mode == "GREETING" or mode == "DETAIL" or mode == "PROGRESS" or mode == "COMPLETE" or sess == "QUEST" then
        if type(_G.CloseQuest) == "function" then
            pcall(_G.CloseQuest)
        end
    end
    if mode and mode ~= "PREVIEW" and _G.C_PlayerInteractionManager and type(_G.C_PlayerInteractionManager.ClearInteraction) == "function" then
        local iEnum = _G.Enum and _G.Enum.PlayerInteractionType
        if mode == "GOSSIP" or sess == "GOSSIP" then
            if iEnum and iEnum.Gossip then
                pcall(_G.C_PlayerInteractionManager.ClearInteraction, iEnum.Gossip)
            end
        elseif iEnum and iEnum.QuestGiver then
            pcall(_G.C_PlayerInteractionManager.ClearInteraction, iEnum.QuestGiver)
        end
    end
end

local function ApplyReaderPosition()
    if not readerFrame or InCombatLockdown() then return end
    local db = EnsureDB()
    local scale = math.max(0.70, math.min(1.40, SafeNum(db.frameScale, 1.0)))
    readerFrame:SetScale(scale)
    local pos = (type(db.pos) == "table") and db.pos or DEFAULTS.pos
    readerFrame:ClearAllPoints()
    readerFrame:SetPoint(pos.point or "CENTER", _G.UIParent, pos.relPoint or "CENTER", SafeNum(pos.x, 0), SafeNum(pos.y, -90))
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

    readerFrame = f
    ApplyReaderPosition()

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
            d.pos = {
                point = p,
                relPoint = rp or p,
                x = math.floor(SafeNum(x, 0) + 0.5),
                y = math.floor(SafeNum(y, -90) + 0.5),
            }
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
    thumb.tex = SolidTex(thumb, "OVERLAY", 3, ar, ag, ab, 0.85)
    thumb.tex:SetAllPoints()
    f.scrollTrack = track
    f.scrollThumb = thumb

    local function UpdateScrollBar()
        if sf.UpdateScrollChildRect then pcall(sf.UpdateScrollChildRect, sf) end
        local nr, ng, nb = GetAccentColor()
        thumb.tex:SetColorTexture(nr, ng, nb, 0.85)
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
    f.footerHint:SetWordWrap(false)
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
    priBtn:SetSize(176, 28)
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

    -- Keyboard handler (1-9 hotkeys, Space accept/confirm, 1/Space double-tap confirm, Escape close)
    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then return end
        local d = EnsureDB()
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            if currentMode == "CONFIRM" and f.secBtn:IsShown() then
                local fn = f.secBtn:GetScript("OnClick")
                if fn then
                    fn(f.secBtn)
                else
                    CloseConfirmInteraction()
                end
            else
                CloseActiveInteraction()
            end
            return
        end
        if currentMode == "CONFIRM" then
            local wantSpace = (d.enableSpaceConfirm ~= false and key == "SPACE")
            local wantOne = (d.enableNumberHotkeys ~= false and key == "1")
            if wantSpace or wantOne then
                self:SetPropagateKeyboardInput(false)
                if activeConfirmDestructive then
                    return
                end
                local now = (type(_G.GetTime) == "function") and _G.GetTime() or 0
                if (now - (confirmEnteredAt or 0)) < 0.15 then
                    return
                end
                if f.priBtn:IsShown() and f.priBtn:IsEnabled() then
                    local fn = f.priBtn:GetScript("OnClick")
                    if fn then fn(f.priBtn) end
                end
                return
            end
            self:SetPropagateKeyboardInput(true)
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
        if _G.GameTooltip then _G.GameTooltip:Hide() end
        local dw = _G.DynamicSuite and _G.DynamicSuite.DesktopWindows
        if dw and type(dw.SyncAllUISpecialFrames) == "function" and not InCombatLockdown() then
            pcall(dw.SyncAllUISpecialFrames)
        end
    end)

    return f
end

function DynamicDialogue:ApplyReaderTheme()
    if not readerFrame then return end
    local db = EnsureDB()
    local surf = GetSurfaceColors()
    local ar, ag, ab = GetAccentColor()
    local fa = GetPillFillAlpha()

    ApplyReaderPosition()
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

    local showBadge = (db.showTypeBadge ~= false)
    readerFrame.typeBadge:SetShown(showBadge)
    readerFrame.typeBadge.bg:SetColorTexture(ar * 0.28, ag * 0.28, ab * 0.28, 0.95)
    readerFrame.typeBadge.border:SetColor(ar, ag, ab, 0.90)
    readerFrame.titleText:ClearAllPoints()
    if showBadge then
        readerFrame.titleText:SetPoint("LEFT", readerFrame.typeBadge, "RIGHT", 10, 0)
    else
        readerFrame.titleText:SetPoint("LEFT", readerFrame.hdr.accentBar, "RIGHT", 10, 0)
    end
    readerFrame.titleText:SetPoint("RIGHT", readerFrame.closeBtn, "LEFT", -10, 0)

    readerFrame.subTitle:SetTextColor(ar, ag, ab, 1)
    ApplyFont(readerFrame.titleText, 14, "OUTLINE")
    ApplyFont(readerFrame.subTitle, 13, "OUTLINE")
    ApplyFont(readerFrame.bodyText, SafeNum(db.fontSize, 13), "")
    readerFrame.priBtn.bg:SetColorTexture(ar * fa, ag * fa, ab * fa, 0.96)
    readerFrame.priBtn.border:SetColor(ar, ag, ab, 0.95)
    readerFrame.secBtn.bg:SetColorTexture(surf.CELL_BG.r, surf.CELL_BG.g, surf.CELL_BG.b, 0.96)
    readerFrame.secBtn.border:SetColor(surf.CELL_BORDER.r, surf.CELL_BORDER.g, surf.CELL_BORDER.b, 0.95)
    if readerFrame.scrollThumb and readerFrame.scrollThumb.tex then
        readerFrame.scrollThumb.tex:SetColorTexture(ar, ag, ab, 0.85)
    end
    for _, btn in ipairs(readerFrame.optionButtons or {}) do
        if btn.keycap then
            btn.keycap.bg:SetColorTexture(ar * 0.25, ag * 0.25, ab * 0.25, 0.95)
            btn.keycap.border:SetColor(ar, ag, ab, 0.85)
        end
    end
end

local function AcquireOptionButton(parent, index)
    local f = EnsureReaderFrame()
    local btn = f.optionButtons[index]
    if btn then return btn end
    local surf = GetSurfaceColors()
    local ar, ag, ab = GetAccentColor()

    btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(34)
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

    -- Crisp quest / gossip icon (16x16)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(16, 16)
    btn.icon:SetTexCoord(0, 1, 0, 1)

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

local function PopulateRewardsSection(yCursor, isChoiceMode, includeRequired)
    local f = EnsureReaderFrame()
    local db = EnsureDB()
    local ar, ag, ab = GetAccentColor()
    local surf = GetSurfaceColors()
    local cardIdx = 0
    local rewardsList = {}

    if includeRequired then
        local numReq = (type(_G.GetNumQuestItems) == "function") and SafeNum(_G.GetNumQuestItems(), 0) or 0
        if numReq > 0 and type(_G.GetQuestItemInfo) == "function" then
            for i = 1, numReq do
                local name, tex, count, quality = _G.GetQuestItemInfo("required", i)
                if name and not SafeIsSecret(name) then
                    table.insert(rewardsList, {
                        kind = "required",
                        index = i,
                        name = SafeStr(name),
                        icon = tex,
                        count = SafeNum(count, 1),
                        quality = SafeNum(quality, 1),
                        sub = "Required Item",
                    })
                end
            end
        end
    else
        local numChoices = (type(_G.GetNumQuestChoices) == "function") and SafeNum(_G.GetNumQuestChoices(), 0) or 0
        local numRewards = (type(_G.GetNumQuestRewards) == "function") and SafeNum(_G.GetNumQuestRewards(), 0) or 0
        local money = (type(_G.GetRewardMoney) == "function") and SafeNum(_G.GetRewardMoney(), 0) or 0
        local xp = (type(_G.GetRewardXP) == "function") and SafeNum(_G.GetRewardXP(), 0) or 0

        if numChoices > 0 and type(_G.GetQuestItemInfo) == "function" then
            for i = 1, numChoices do
                local name, tex, count, quality = _G.GetQuestItemInfo("choice", i)
                if name and not SafeIsSecret(name) then
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
                if name and not SafeIsSecret(name) then
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

        local addedCurrency = false
        if _G.C_QuestInfoSystem and type(_G.C_QuestInfoSystem.GetQuestRewardCurrencies) == "function" then
            local okCur, curList = pcall(_G.C_QuestInfoSystem.GetQuestRewardCurrencies)
            if okCur and type(curList) == "table" and not SafeIsSecret(curList) then
                for idx, cur in ipairs(curList) do
                    if type(cur) == "table" and not SafeIsSecret(cur) and cur.name and not SafeIsSecret(cur.name) then
                        addedCurrency = true
                        table.insert(rewardsList, {
                            kind = "currency",
                            currencyIndex = idx,
                            currencyID = (not SafeIsSecret(cur.currencyID)) and cur.currencyID or nil,
                            name = SafeStr(cur.name, "Currency"),
                            icon = (not SafeIsSecret(cur.texture)) and cur.texture or 133784,
                            count = SafeNum(cur.totalRewardAmount or cur.bonusRewardAmount, 1),
                            quality = SafeNum(cur.quality, 1),
                            sub = "Currency Reward",
                        })
                    end
                end
            end
        end
        if not addedCurrency and type(_G.GetNumRewardCurrencies) == "function" and type(_G.GetQuestCurrencyInfo) == "function" then
            local numCur = SafeNum(_G.GetNumRewardCurrencies(), 0)
            for i = 1, numCur do
                local okC, name, tex, count, curID, quality = pcall(_G.GetQuestCurrencyInfo, "reward", i)
                if okC and name and not SafeIsSecret(name) then
                    table.insert(rewardsList, {
                        kind = "currency",
                        currencyIndex = i,
                        currencyID = (not SafeIsSecret(curID)) and curID or nil,
                        name = SafeStr(name, "Currency"),
                        icon = (not SafeIsSecret(tex)) and tex or 133784,
                        count = SafeNum(count, 1),
                        quality = SafeNum(quality, 1),
                        sub = "Currency Reward",
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
            if db.showRewardTooltips ~= false then
                if item.kind == "choice" or item.kind == "reward" or item.kind == "required" then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    pcall(GameTooltip.SetQuestItem, GameTooltip, item.kind, item.index)
                    GameTooltip:Show()
                elseif item.kind == "currency" then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if item.currencyIndex and type(GameTooltip.SetQuestCurrency) == "function" then
                        pcall(GameTooltip.SetQuestCurrency, GameTooltip, "reward", item.currencyIndex)
                    elseif item.currencyID and type(GameTooltip.SetCurrencyByID) == "function" then
                        pcall(GameTooltip.SetCurrencyByID, GameTooltip, item.currencyID)
                    end
                    GameTooltip:Show()
                end
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

    local bodyStr = SafeStr(opts.body, "")
    ApplyFont(f.bodyText, SafeNum(db.fontSize, 13), "")
    local yCursor
    if bodyStr == "" then
        f.bodyText:SetText("")
        f.bodyText:Hide()
        yCursor = -4
    else
        f.bodyText:Show()
        f.bodyText:SetText(bodyStr)
        local bodyH = math.max(18, math.ceil(f.bodyText:GetStringHeight() or 18))
        yCursor = -(bodyH + 14)
    end

    -- Populate option rows (1..9 hotkeys + crisp quest/gossip icons)
    local list = opts.options or {}
    for i, opt in ipairs(list) do
        currentOptions[i] = opt
        local btn = AcquireOptionButton(f.content, i)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", f.content, "TOPLEFT", 2, yCursor)
        btn:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", -2, yCursor)

        local hasHotkey = (i <= 9 and db.enableNumberHotkeys ~= false)
        local hasIcon = (opt.icon ~= nil and opt.icon ~= "" and opt.icon ~= 0)
        if hasHotkey then
            btn.keycap:Show()
            btn.keycap.text:SetText(tostring(i))
            btn.keycap.bg:SetColorTexture(ar * 0.25, ag * 0.25, ab * 0.25, 0.95)
            btn.keycap.border:SetColor(ar, ag, ab, 0.85)
        else
            btn.keycap:Hide()
        end

        if hasIcon then
            btn.icon:SetTexture(opt.icon)
            if btn.icon.SetDesaturated then
                pcall(btn.icon.SetDesaturated, btn.icon, opt.iconDesaturated == true)
            end
            btn.icon:ClearAllPoints()
            if hasHotkey then
                btn.icon:SetPoint("LEFT", btn.keycap, "RIGHT", 8, 0)
            else
                btn.icon:SetPoint("LEFT", btn, "LEFT", 10, 0)
            end
            btn.icon:Show()
            btn.label:ClearAllPoints()
            btn.label:SetPoint("LEFT", btn.icon, "RIGHT", 7, 0)
            btn.label:SetPoint("RIGHT", btn.tagText, "LEFT", -8, 0)
        else
            btn.icon:Hide()
            btn.label:ClearAllPoints()
            if hasHotkey then
                btn.label:SetPoint("LEFT", btn.keycap, "RIGHT", 10, 0)
            else
                btn.label:SetPoint("LEFT", btn, "LEFT", 10, 0)
            end
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
        yCursor = yCursor - 40
    end

    -- Populate rewards or required items if requested
    if opts.showRewards or opts.showRequired then
        yCursor = PopulateRewardsSection(yCursor, opts.isChoiceMode == true, opts.showRequired == true)
    end

    local totalH = math.max(80, math.abs(yCursor) + 12)
    f.content:SetHeight(totalH)
    f.scrollFrame:SetVerticalScroll(0)

    -- Dynamic height clamped nicely between 260 and 540
    local desiredH = math.max(260, math.min(540, totalH + 132))
    f:SetHeight(desiredH)

    -- Primary / Secondary footer buttons
    local showSec = not opts.hideSecondary
    if showSec then
        f.secBtn:Show()
        f.secBtn.label:SetText(opts.secondaryLabel or "Close [Esc]")
        f.secBtn:SetScript("OnClick", opts.onSecondary or CloseActiveInteraction)
    else
        f.secBtn:Hide()
        f.secBtn:SetScript("OnClick", nil)
    end

    if opts.primaryLabel and type(opts.onPrimary) == "function" then
        f.priBtn:ClearAllPoints()
        if showSec then
            f.priBtn:SetPoint("RIGHT", f.secBtn, "LEFT", -8, 0)
        else
            f.priBtn:SetPoint("RIGHT", f.footer, "RIGHT", -14, 0)
        end
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

    f.footerHint:ClearAllPoints()
    f.footerHint:SetPoint("LEFT", f.footer, "LEFT", 14, 0)
    if f.priBtn:IsShown() then
        f.footerHint:SetPoint("RIGHT", f.priBtn, "LEFT", -8, 0)
    elseif showSec then
        f.footerHint:SetPoint("RIGHT", f.secBtn, "LEFT", -8, 0)
    else
        f.footerHint:SetPoint("RIGHT", f.footer, "RIGHT", -14, 0)
    end

    local hints = {}
    if currentMode == "CONFIRM" then
        if activeConfirmDestructive then
            table.insert(hints, "Click Confirm")
        else
            local cKeys = {}
            if db.enableNumberHotkeys ~= false then table.insert(cKeys, "[1]") end
            if db.enableSpaceConfirm ~= false then table.insert(cKeys, "[Space]") end
            if #cKeys > 0 then
                table.insert(hints, table.concat(cKeys, " / ") .. " Confirm")
            end
        end
        if showSec then
            table.insert(hints, "[Esc] Cancel")
        end
    else
        if #list > 0 and db.enableNumberHotkeys ~= false then table.insert(hints, "[1-" .. math.min(9, #list) .. "] Select") end
        if opts.primaryLabel and db.enableSpaceConfirm ~= false then table.insert(hints, "[Space] Confirm") end
        if showSec then
            table.insert(hints, "[Esc] Close")
        else
            table.insert(hints, "[Esc] Dismiss")
        end
    end
    f.footerHint:SetText(table.concat(hints, "  |  "))

    f:Show()
    if type(f.Raise) == "function" then
        pcall(f.Raise, f)
    end
    local dw = _G.DynamicSuite and _G.DynamicSuite.DesktopWindows
    if dw and type(dw.SyncAllUISpecialFrames) == "function" and not InCombatLockdown() then
        pcall(dw.SyncAllUISpecialFrames)
    end
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

local function ResolveNpcName(fallback)
    local rawNpc = (_G.UnitName and _G.UnitName("npc")) or nil
    if SafeIsSecret(rawNpc) or type(rawNpc) ~= "string" or rawNpc == "" then
        rawNpc = (_G.UnitName and _G.UnitName("target")) or nil
    end
    local name = SafeStr(rawNpc, "")
    if name == "" then
        name = fallback or "NPC"
    end
    return name
end

function DynamicDialogue:ShowGossip()
    if not self:ShouldIntercept("GOSSIP") then
        RestoreBlizzardFrame(_G.GossipFrame)
        return
    end
    activeSessionKind = "GOSSIP"
    currentMode = "GOSSIP"
    RestoreBlizzardFrame(_G.QuestFrame)
    SuppressBlizzardFrame(_G.GossipFrame)

    local npcName = ResolveNpcName("NPC")
    local text = (C_GossipInfo and C_GossipInfo.GetText) and SafeStr(C_GossipInfo.GetText(), "") or ""
    local options = {}

    -- Active (Turn-in / In-Progress) Quests first
    if C_GossipInfo and type(C_GossipInfo.GetActiveQuests) == "function" then
        local activeQ = C_GossipInfo.GetActiveQuests() or {}
        for _, q in ipairs(activeQ) do
            if type(q) == "table" and not SafeIsSecret(q) then
                local qID = (not SafeIsSecret(q.questID)) and q.questID or nil
                local isComplete = (not SafeIsSecret(q.isComplete) and q.isComplete == true)
                local freq = SafeNum(q.frequency, 0)
                local isDaily = (freq > 0) or (not SafeIsSecret(q.repeatable) and q.repeatable == true)
                local iconPath = isComplete
                    and (isDaily and "Interface\\GossipFrame\\DailyActiveQuestIcon" or "Interface\\GossipFrame\\ActiveQuestIcon")
                    or "Interface\\GossipFrame\\IncompleteQuestIcon"
                table.insert(options, {
                    label = SafeStr(q.title, "Active Quest"),
                    tag = isComplete and "[TURN-IN]" or "[IN PROGRESS]",
                    tagColor = isComplete and { 0.20, 0.83, 0.60 } or { 0.64, 0.70, 0.78 },
                    icon = iconPath,
                    onClick = function()
                        if qID and C_GossipInfo.SelectActiveQuest then
                            pcall(C_GossipInfo.SelectActiveQuest, qID)
                        end
                    end,
                })
            end
        end
    end

    -- Available Quests
    if C_GossipInfo and type(C_GossipInfo.GetAvailableQuests) == "function" then
        local availQ = C_GossipInfo.GetAvailableQuests() or {}
        for _, q in ipairs(availQ) do
            if type(q) == "table" and not SafeIsSecret(q) then
                local qID = (not SafeIsSecret(q.questID)) and q.questID or nil
                local freq = SafeNum(q.frequency, 0)
                local isDaily = (freq > 0) or (not SafeIsSecret(q.repeatable) and q.repeatable == true)
                local isLegendary = (not SafeIsSecret(q.isLegendary) and q.isLegendary == true)
                local iconPath = (isLegendary and "Interface\\GossipFrame\\AvailableLegendaryQuestIcon")
                    or (isDaily and "Interface\\GossipFrame\\DailyQuestIcon")
                    or "Interface\\GossipFrame\\AvailableQuestIcon"
                table.insert(options, {
                    label = SafeStr(q.title, "Available Quest"),
                    tag = "[QUEST]",
                    tagColor = { 0.98, 0.80, 0.08 },
                    icon = iconPath,
                    onClick = function()
                        if qID and C_GossipInfo.SelectAvailableQuest then
                            pcall(C_GossipInfo.SelectAvailableQuest, qID)
                        end
                    end,
                })
            end
        end
    end

    -- Gossip Options (sorted by orderIndex with original array index tie-breaker)
    if C_GossipInfo and type(C_GossipInfo.GetOptions) == "function" then
        local gOpts = C_GossipInfo.GetOptions() or {}
        local sorted = {}
        for idx, opt in ipairs(gOpts) do
            if type(opt) == "table" and not SafeIsSecret(opt) then
                table.insert(sorted, { opt = opt, idx = idx, order = SafeNum(opt.orderIndex, idx) })
            end
        end
        table.sort(sorted, function(a, b)
            if a.order ~= b.order then return a.order < b.order end
            return a.idx < b.idx
        end)
        for _, entry in ipairs(sorted) do
            local opt = entry.opt
            local optID = (not SafeIsSecret(opt.gossipOptionID) and opt.gossipOptionID ~= 0) and opt.gossipOptionID or nil
            local rawIdx = entry.idx
            local iconVal = opt.overrideIconID
            if SafeIsSecret(iconVal) or iconVal == nil or iconVal == 0 or iconVal == "" then
                iconVal = opt.icon
            end
            if SafeIsSecret(iconVal) or iconVal == nil or iconVal == 0 or iconVal == "" then
                iconVal = "Interface\\GossipFrame\\GossipGossipIcon"
            end
            local status = SafeNum(opt.status, 0)
            local isLocked = false
            if _G.Enum and _G.Enum.GossipOptionStatus then
                isLocked = (status == _G.Enum.GossipOptionStatus.Unavailable or status == _G.Enum.GossipOptionStatus.Locked)
            end
            local flags = SafeNum(opt.flags, 0)
            local tagText = isLocked and "[LOCKED]" or ((flags > 0) and "[OPTION]" or "")
            local tagColor = isLocked and { 0.97, 0.44, 0.44 } or { 0.38, 0.65, 0.98 }
            table.insert(options, {
                label = SafeStr(opt.name, "Dialogue Option"),
                tag = tagText,
                tagColor = tagColor,
                icon = iconVal,
                iconDesaturated = isLocked,
                onClick = function()
                    if optID and C_GossipInfo.SelectOption then
                        pcall(C_GossipInfo.SelectOption, optID)
                    elseif C_GossipInfo.SelectOptionByIndex then
                        pcall(C_GossipInfo.SelectOptionByIndex, rawIdx)
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
        RestoreBlizzardFrame(_G.QuestFrame)
        return
    end
    activeSessionKind = "QUEST"
    currentMode = "GREETING"
    RestoreBlizzardFrame(_G.GossipFrame)
    SuppressBlizzardFrame(_G.QuestFrame)

    local npcName = ResolveNpcName("Quest Giver")
    local text = (type(_G.GetGreetingText) == "function") and SafeStr(_G.GetGreetingText(), "") or ""
    local options = {}

    local numActive = (type(_G.GetNumActiveQuests) == "function") and SafeNum(_G.GetNumActiveQuests(), 0) or 0
    for i = 1, numActive do
        local title, isComplete = _G.GetActiveTitle(i)
        local comp = (not SafeIsSecret(isComplete) and isComplete == true)
        table.insert(options, {
            label = SafeStr(title, "Active Quest"),
            tag = comp and "[TURN-IN]" or "[IN PROGRESS]",
            tagColor = comp and { 0.20, 0.83, 0.60 } or { 0.64, 0.70, 0.78 },
            icon = comp and "Interface\\GossipFrame\\ActiveQuestIcon" or "Interface\\GossipFrame\\IncompleteQuestIcon",
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
            icon = "Interface\\GossipFrame\\AvailableQuestIcon",
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

function DynamicDialogue:ShowConfirmPrompt(opts)
    if InCombatLockdown() then return end
    opts = type(opts) == "table" and opts or {}
    activeSessionKind = "CONFIRM"
    currentMode = "CONFIRM"
    activeConfirmKind = opts.kind or "GOSSIP"
    activeConfirmDestructive = (opts.isDestructive == true)
    selectedChoiceIndex = nil
    confirmEnteredAt = (type(_G.GetTime) == "function") and _G.GetTime() or 0
    RenderReaderState({
        badge = opts.badge or "CONFIRM",
        title = opts.title or "Confirmation",
        subtitle = opts.subtitle or "",
        body = opts.body or "",
        primaryLabel = opts.primaryLabel or "Accept [Space]",
        onPrimary = opts.onPrimary,
        secondaryLabel = opts.secondaryLabel or "Cancel [Esc]",
        onSecondary = opts.onSecondary or CloseConfirmInteraction,
    })
end

function DynamicDialogue:ShowQuestDetail()
    if not self:ShouldIntercept("QUEST") then
        RestoreBlizzardFrame(_G.QuestFrame)
        return
    end
    activeSessionKind = "QUEST"
    currentMode = "DETAIL"
    activeConfirmKind = nil
    activeConfirmDestructive = false
    selectedChoiceIndex = nil
    RestoreBlizzardFrame(_G.GossipFrame)
    SuppressBlizzardFrame(_G.QuestFrame)

    local npcName = ResolveNpcName("Quest")
    local qTitle  = (type(_G.GetTitleText) == "function") and SafeStr(_G.GetTitleText(), "Quest") or "Quest"
    local qDesc   = (type(_G.GetQuestText) == "function") and SafeStr(_G.GetQuestText(), "") or ""
    local qObj    = (type(_G.GetObjectiveText) == "function") and SafeStr(_G.GetObjectiveText(), "") or ""
    local body = qDesc
    if qObj ~= "" then
        if body ~= "" then
            body = body .. "\n\n|cFF" .. GetAccentHex() .. "Objective:|r\n" .. qObj
        else
            body = "|cFF" .. GetAccentHex() .. "Objective:|r\n" .. qObj
        end
    end

    local isAutoAccept = false
    if type(_G.QuestGetAutoAccept) == "function" then
        local okAA, resAA = pcall(_G.QuestGetAutoAccept)
        if okAA and not SafeIsSecret(resAA) and resAA == true then
            isAutoAccept = true
        end
    end

    RenderReaderState({
        badge = "QUEST",
        title = npcName,
        subtitle = qTitle,
        body = body,
        showRewards = true,
        isChoiceMode = false,
        primaryLabel = isAutoAccept and "Okay [Space]" or "Accept Quest [Space]",
        onPrimary = function()
            if isAutoAccept then
                if type(_G.AcknowledgeAutoAcceptQuest) == "function" then
                    pcall(_G.AcknowledgeAutoAcceptQuest)
                elseif type(_G.AcceptQuest) == "function" then
                    pcall(_G.AcceptQuest)
                end
                CloseActiveInteraction()
            else
                if type(_G.AcceptQuest) == "function" then
                    pcall(_G.AcceptQuest)
                end
            end
        end,
        hideSecondary = isAutoAccept,
        secondaryLabel = (not isAutoAccept) and "Decline [Esc]" or nil,
        onSecondary = (not isAutoAccept) and function()
            if type(_G.DeclineQuest) == "function" then
                pcall(_G.DeclineQuest)
            end
            CloseActiveInteraction()
        end or nil,
    })
end

function DynamicDialogue:ShowQuestProgress()
    if not self:ShouldIntercept("QUEST") then
        RestoreBlizzardFrame(_G.QuestFrame)
        return
    end
    activeSessionKind = "QUEST"
    currentMode = "PROGRESS"
    RestoreBlizzardFrame(_G.GossipFrame)
    SuppressBlizzardFrame(_G.QuestFrame)

    local npcName = ResolveNpcName("Quest")
    local qTitle  = (type(_G.GetTitleText) == "function") and SafeStr(_G.GetTitleText(), "Quest") or "Quest"
    local qProg   = (type(_G.GetProgressText) == "function") and SafeStr(_G.GetProgressText(), "") or ""
    local canComplete = (type(_G.IsQuestCompletable) == "function") and (_G.IsQuestCompletable() == true)

    RenderReaderState({
        badge = "PROGRESS",
        title = npcName,
        subtitle = qTitle,
        body = qProg,
        showRequired = true,
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
        RestoreBlizzardFrame(_G.QuestFrame)
        return
    end
    activeSessionKind = "QUEST"
    currentMode = "COMPLETE"
    selectedChoiceIndex = nil
    RestoreBlizzardFrame(_G.GossipFrame)
    SuppressBlizzardFrame(_G.QuestFrame)

    local db = EnsureDB()
    local npcName = ResolveNpcName("Quest")
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
                if numChoices > 0 then
                    pcall(_G.GetQuestReward, selectedChoiceIndex or 1)
                else
                    pcall(_G.GetQuestReward)
                end
            end
        end,
        secondaryLabel = "Close [Esc]",
    })
end

function DynamicDialogue:ShowPreview()
    RestoreAllBlizzardFrames()
    activeSessionKind = "PREVIEW"
    currentMode = "PREVIEW"
    selectedChoiceIndex = nil
    RenderReaderState({
        badge = "PREVIEW",
        title = "Chronomancer Chromie",
        subtitle = "Obsidian Dialogue Reader Preview",
        body = "Welcome to DynamicDialogue! Press [1]-[3] to test option hotkeys, press [Space] to confirm, or drag the dark Obsidian header bar to reposition this reader anywhere on your screen.\n\nHold [Shift] while talking to any NPC to temporarily open the native Blizzard quest frame.",
        options = {
            { label = "Test Hotkey 1: Inspect Midnight Quest Layout", tag = "[QUEST]", tagColor = { 0.98, 0.80, 0.08 }, icon = "Interface\\GossipFrame\\AvailableQuestIcon", onClick = function() Print("Preview Option 1 selected.") end },
            { label = "Test Hotkey 2: Verify High-Contrast Obsidian Readability", tag = "[OPTION]", tagColor = { 0.38, 0.65, 0.98 }, icon = "Interface\\GossipFrame\\GossipGossipIcon", onClick = function() Print("Preview Option 2 selected.") end },
            { label = "Test Hotkey 3: Close Preview Reader", tag = "[TURN-IN]", tagColor = { 0.20, 0.83, 0.60 }, icon = "Interface\\GossipFrame\\ActiveQuestIcon", onClick = function() CloseActiveInteraction() end },
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
    ApplyReaderPosition()
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

    slider.hairline = SolidTex(slider, "BACKGROUND", -1, 1, 1, 1, 0.14)
    slider.hairline:SetPoint("TOPLEFT", slider, "TOPLEFT", -1, 1)
    slider.hairline:SetPoint("BOTTOMRIGHT", slider, "BOTTOMRIGHT", 1, -1)

    slider.bg = SolidTex(slider, "BACKGROUND", 0, 0.035, 0.039, 0.051, 0.98)
    slider.bg:SetAllPoints()

    slider.fillBar = SolidTex(slider, "ARTWORK", 2, ar, ag, ab, 0.85)
    slider.fillBar:SetPoint("TOPLEFT", slider, "TOPLEFT", 0, 0)
    slider.fillBar:SetPoint("BOTTOMLEFT", slider, "BOTTOMLEFT", 0, 0)
    slider.fillBar:SetWidth(1)

    local thumb = slider:CreateTexture(nil, "OVERLAY", nil, 5)
    thumb:SetSize(6, 14)
    thumb:SetColorTexture(0.97, 0.98, 1.0, 1.0)
    if thumb.SetSnapToPixelGrid then thumb:SetSnapToPixelGrid(false) end
    if thumb.SetTexelSnappingBias then thumb:SetTexelSnappingBias(0) end
    slider:SetThumbTexture(thumb)

    local isDragging = false
    local suppressCallback = false
    local lastCommitted = nil
    local function SnapValue(v)
        v = math.max(minVal, math.min(maxVal, tonumber(v) or minVal))
        if stepVal and stepVal > 0 then
            v = math.floor(((v - minVal) / stepVal) + 0.5) * stepVal + minVal
        end
        return math.max(minVal, math.min(maxVal, v))
    end

    local function UpdateVisual(v, rawVal)
        local r, g, b = GetAccentColor()
        local posVal = rawVal or v
        local pct = (maxVal > minVal) and ((posVal - minVal) / (maxVal - minVal)) or 0
        pct = math.max(0, math.min(1, pct))
        local w = slider:GetWidth()
        if not w or w <= 0 then w = 194 end
        slider.fillBar:SetColorTexture(r, g, b, 0.85)
        slider.fillBar:SetWidth(math.max(1, pct * w))
        if isDragging or slider:IsMouseOver() then
            thumb:SetColorTexture(r, g, b, 1.0)
        else
            thumb:SetColorTexture(0.97, 0.98, 1.0, 1.0)
        end
        valText:SetTextColor(r, g, b, 1.0)
        valText:SetText(formatFn and formatFn(v) or tostring(v))
    end

    slider:SetScript("OnValueChanged", function(_, value)
        local stepped = SnapValue(value)
        UpdateVisual(stepped, value)
        if not suppressCallback and stepped ~= lastCommitted then
            lastCommitted = stepped
            setter(stepped)
        end
    end)

    local function UpdateSliderFromCursor()
        if isDragging and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            isDragging = false
            slider:SetScript("OnUpdate", nil)
            local r = SnapValue(getter())
            suppressCallback = true
            slider:SetValue(r)
            UpdateVisual(r, r)
            suppressCallback = false
            return
        end
        local scale = slider:GetEffectiveScale() or 1
        local cx = (GetCursorPosition() / scale)
        local left, tw = slider:GetLeft(), slider:GetWidth()
        if left and tw and tw > 0 then
            local pct = math.max(0, math.min(1, (cx - left) / tw))
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
        local r = SnapValue(getter())
        suppressCallback = true
        slider:SetValue(r)
        UpdateVisual(r, r)
        suppressCallback = false
    end)
    slider:SetScript("OnHide", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
    end)
    slider:SetScript("OnEnter", function(self)
        UpdateVisual(SnapValue(self:GetValue()), self:GetValue())
        if GameTooltip then
            local r, g, b = GetAccentColor()
            local hex = string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(string.format("|cFF%sLeft-Click / Drag:|r |cFFE2E8F0Adjust value|r", hex))
            GameTooltip:AddLine(string.format("|cFF%sMousewheel:|r |cFFE2E8F0Fine-tune by 1 step|r", hex))
            GameTooltip:Show()
        end
    end)
    slider:SetScript("OnLeave", function(self)
        UpdateVisual(SnapValue(self:GetValue()), self:GetValue())
        if GameTooltip then GameTooltip:Hide() end
    end)

    slider:SetScript("OnMouseWheel", function(self, delta)
        local cur = SnapValue(getter())
        local nxt = SnapValue(cur + (delta * stepVal))
        lastCommitted = nxt
        setter(nxt)
        suppressCallback = true
        self:SetValue(nxt)
        UpdateVisual(nxt, nxt)
        suppressCallback = false
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
            function(v) db.replaceQuests = v; if root.RefreshStatus then root.RefreshStatus() end end),
        CreateToggleRow(sec1, -190, "Replace NPC Gossip Windows", "Present NPC gossip menus in a clean Obsidian reader with numbered option buttons.",
            function() return db.replaceGossip ~= false end,
            function(v) db.replaceGossip = v; if root.RefreshStatus then root.RefreshStatus() end end),
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
        local state, shortLabel, detail = DynamicDialogue:GetDetailedStatus()
        if state == "Yielding" then
            local _, label = DynamicDialogue:GetYieldInfo()
            statusLbl:SetText("|cFFFACC15Yielding|r  |cFF94A3B8-> " .. tostring(label or "External Addon") .. "|r")
            root.statusTooltipText = detail .. " Manage competing addons in Guided Setup."
        elseif state == "Active" then
            statusLbl:SetText("|cFF22C55EActive|r  |cFF94A3B8- Obsidian Reader Ready|r")
            root.statusTooltipText = detail
        else
            local subNote = (shortLabel == "Paused (Off in Sidebar)") and "Off in Sidebar" or "Reader Disabled"
            statusLbl:SetText("|cFFF87171Paused|r  |cFF94A3B8- " .. subNote .. "|r")
            root.statusTooltipText = detail
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
            { type = "FEATURE", text = "Unified Obsidian Confirm Screen & Auto-Accept Quest Fix (21/11/2026): Added a shared Obsidian Confirm screen for gossip confirmations, shared group quests, and Hearthstone innkeeper binding with 1 / Space double-tap confirmation (0.15s debounce) and Esc cancellation while leaving code-entry prompts native; and fixed auto-accepted quests to show Okay [Space] (no Decline) cleanly." },
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
local function IsGossipInteractionActive()
    if _G.GossipFrame and _G.GossipFrame.IsShown and _G.GossipFrame:IsShown() then
        return true
    end
    if _G.C_PlayerInteractionManager and type(_G.C_PlayerInteractionManager.IsInteractingNpcOfType) == "function"
        and _G.Enum and _G.Enum.PlayerInteractionType and _G.Enum.PlayerInteractionType.Gossip then
        local ok, active = pcall(_G.C_PlayerInteractionManager.IsInteractingNpcOfType, _G.Enum.PlayerInteractionType.Gossip)
        if ok and active == true then
            return true
        end
    end
    return false
end

local function IsQuestInteractionActive()
    if _G.QuestFrame and _G.QuestFrame.IsShown and _G.QuestFrame:IsShown() then
        return true
    end
    if _G.C_PlayerInteractionManager and type(_G.C_PlayerInteractionManager.IsInteractingNpcOfType) == "function"
        and _G.Enum and _G.Enum.PlayerInteractionType and _G.Enum.PlayerInteractionType.QuestGiver then
        local ok, active = pcall(_G.C_PlayerInteractionManager.IsInteractingNpcOfType, _G.Enum.PlayerInteractionType.QuestGiver)
        if ok and active == true then
            return true
        end
    end
    return false
end

local function HideNonPreviewReader()
    if currentMode == "PREVIEW" then return end
    currentMode = nil
    activeSessionKind = nil
    activeConfirmKind = nil
    activeConfirmDestructive = false
    selectedChoiceIndex = nil
    wipe(currentOptions)
    if readerFrame and readerFrame:IsShown() then
        readerFrame:Hide()
    end
end

local function HandleQuestShowEvent(showMethodName)
    if not DynamicDialogue:ShouldIntercept("QUEST") then
        HideNonPreviewReader()
        RestoreBlizzardFrame(_G.QuestFrame)
        return
    end
    interactionSeq = interactionSeq + 1
    local mySeq = interactionSeq
    activeSessionKind = "QUEST"
    RestoreBlizzardFrame(_G.GossipFrame)
    SuppressBlizzardFrame(_G.QuestFrame)
    C_Timer.After(0, function()
        if mySeq ~= interactionSeq then return end
        if IsQuestInteractionActive() and type(DynamicDialogue[showMethodName]) == "function" then
            DynamicDialogue[showMethodName](DynamicDialogue)
        else
            if activeSessionKind == "QUEST" then
                activeSessionKind = nil
            end
            RestoreBlizzardFrame(_G.QuestFrame)
        end
    end)
end

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
evt:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(evt.RegisterEvent, evt, "GOSSIP_CONFIRM")
pcall(evt.RegisterEvent, evt, "GOSSIP_CONFIRM_CANCEL")
pcall(evt.RegisterEvent, evt, "QUEST_ACCEPT_CONFIRM")
pcall(evt.RegisterEvent, evt, "CONFIRM_BINDER")
pcall(evt.RegisterEvent, evt, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE")

evt:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_FOLDER or arg1 == "DynamicSuite" or arg1 == "DynamicDialogue" then
            EnsureDB()
            RegisterWithDynamicSuite()
        end
    elseif event == "PLAYER_LOGIN" then
        EnsureDB()
        RegisterWithDynamicSuite()
    elseif event == "GOSSIP_SHOW" then
        if IsCustomGossipTextureKit(arg1) then
            activeBypassGossip = true
            HideNonPreviewReader()
            RestoreBlizzardFrame(_G.GossipFrame)
            return
        end
        activeBypassGossip = false
        if not DynamicDialogue:ShouldIntercept("GOSSIP") then
            HideNonPreviewReader()
            RestoreBlizzardFrame(_G.GossipFrame)
            return
        end
        interactionSeq = interactionSeq + 1
        local mySeq = interactionSeq
        activeSessionKind = "GOSSIP"
        RestoreBlizzardFrame(_G.QuestFrame)
        SuppressBlizzardFrame(_G.GossipFrame)
        -- Yield 1 frame so DynamicPrep's instant single-option auto-confirm can fire first without flicker
        C_Timer.After(0, function()
            if mySeq ~= interactionSeq then return end
            if IsCustomGossipTextureKit(arg1) then
                activeBypassGossip = true
                HideNonPreviewReader()
                RestoreBlizzardFrame(_G.GossipFrame)
                return
            end
            if IsGossipInteractionActive() then
                DynamicDialogue:ShowGossip()
            else
                if activeSessionKind == "GOSSIP" then
                    activeSessionKind = nil
                end
                RestoreBlizzardFrame(_G.GossipFrame)
            end
        end)
    elseif event == "QUEST_GREETING" then
        HandleQuestShowEvent("ShowQuestGreeting")
    elseif event == "QUEST_DETAIL" then
        HandleQuestShowEvent("ShowQuestDetail")
    elseif event == "QUEST_PROGRESS" then
        HandleQuestShowEvent("ShowQuestProgress")
    elseif event == "QUEST_COMPLETE" then
        HandleQuestShowEvent("ShowQuestComplete")
    elseif event == "GOSSIP_CONFIRM" then
        local gID = (not SafeIsSecret(arg1)) and tonumber(arg1) or nil
        local confirmText = SafeStr(arg2, "")
        local cost = SafeNum(arg3, 0)
        interactionSeq = interactionSeq + 1
        local mySeq = interactionSeq
        -- Yield 1 frame so DynamicPrep's opt-in instance auto-confirm can fire first without flicker
        C_Timer.After(0, function()
            if mySeq ~= interactionSeq or InCombatLockdown() then return end
            if WasGossipConfirmAutoHandledByPrep(gID) then
                if not IsGossipInteractionActive() then
                    HideNonPreviewReader()
                    RestoreAllBlizzardFrames()
                end
                return
            end
            if not DynamicDialogue:ShouldIntercept("GOSSIP") then
                return
            end
            if type(_G.StaticPopup_Visible) == "function" and not IsStaticPopupVisible("GOSSIP_CONFIRM") then
                return
            end
            HideStaticPopupSafe("GOSSIP_CONFIRM")
            local body = (confirmText ~= "") and confirmText or "Confirm this action?"
            if cost > 0 then
                body = body .. "\n\n|cFFFBBF24Cost:|r " .. FormatGoldText(cost)
            end
            local npcName = ResolveNpcName("NPC")
            local isDestructive = IsDestructiveConfirmText(confirmText)
            DynamicDialogue:ShowConfirmPrompt({
                kind = "GOSSIP",
                isDestructive = isDestructive,
                badge = isDestructive and "CAUTION" or "CONFIRM",
                title = npcName,
                subtitle = isDestructive and "Destructive Action - Click to Confirm" or "Confirmation Required",
                body = body,
                primaryLabel = isDestructive and "Confirm (Click)" or "Accept [Space]",
                onPrimary = function()
                    HideStaticPopupSafe("GOSSIP_CONFIRM")
                    CloseConfirmInteraction()
                    if gID and _G.C_GossipInfo and type(_G.C_GossipInfo.SelectOption) == "function" then
                        pcall(_G.C_GossipInfo.SelectOption, gID, "", true)
                    end
                end,
                secondaryLabel = "Cancel [Esc]",
                onSecondary = function()
                    HideStaticPopupSafe("GOSSIP_CONFIRM")
                    CloseConfirmInteraction()
                end,
            })
        end)
    elseif event == "GOSSIP_CONFIRM_CANCEL" then
        if currentMode == "CONFIRM" and activeConfirmKind == "GOSSIP" then
            CloseConfirmInteraction()
        end
    elseif event == "QUEST_ACCEPT_CONFIRM" then
        local starterName = SafeStr(arg1, "Group Member")
        local questTitle = SafeStr(arg2, "Shared Quest")
        C_Timer.After(0, function()
            if InCombatLockdown() or not DynamicDialogue:ShouldIntercept("QUEST") then
                return
            end
            if not IsStaticPopupVisible("QUEST_ACCEPT") then
                return
            end
            interactionSeq = interactionSeq + 1
            HideStaticPopupSafe("QUEST_ACCEPT")
            DynamicDialogue:ShowConfirmPrompt({
                kind = "QUEST_ACCEPT",
                badge = "SHARED QUEST",
                title = starterName,
                subtitle = questTitle,
                body = string.format('%s is sharing the quest "%s" with you.\n\nWould you like to accept this quest?', starterName, questTitle),
                primaryLabel = "Accept Quest [Space]",
                onPrimary = function()
                    HideStaticPopupSafe("QUEST_ACCEPT")
                    if type(_G.ConfirmAcceptQuest) == "function" then
                        pcall(_G.ConfirmAcceptQuest)
                    end
                    CloseConfirmInteraction()
                end,
                secondaryLabel = "Decline [Esc]",
                onSecondary = function()
                    HideStaticPopupSafe("QUEST_ACCEPT")
                    CloseConfirmInteraction()
                end,
            })
        end)
    elseif event == "CONFIRM_BINDER" then
        local innName = SafeStr(arg1, "this inn")
        if not DynamicDialogue:ShouldIntercept("GOSSIP") then
            return
        end
        interactionSeq = interactionSeq + 1
        local mySeq = interactionSeq
        HideStaticPopupSafe("CONFIRM_BINDER")
        C_Timer.After(0, function()
            if mySeq == interactionSeq and currentMode == "CONFIRM" and activeConfirmKind == "BINDER" then
                HideStaticPopupSafe("CONFIRM_BINDER")
            end
        end)
        local npcName = ResolveNpcName("Innkeeper")
        DynamicDialogue:ShowConfirmPrompt({
            kind = "BINDER",
            badge = "HEARTHSTONE",
            title = npcName,
            subtitle = innName,
            body = string.format("Set your Hearthstone home to %s?\n\nYou will return here whenever you use your Hearthstone.", innName),
            primaryLabel = "Bind Hearthstone [Space]",
            onPrimary = function()
                HideStaticPopupSafe("CONFIRM_BINDER")
                if _G.C_PlayerInteractionManager and type(_G.C_PlayerInteractionManager.ConfirmationInteraction) == "function"
                    and _G.Enum and _G.Enum.PlayerInteractionType and _G.Enum.PlayerInteractionType.Binder then
                    pcall(_G.C_PlayerInteractionManager.ConfirmationInteraction, _G.Enum.PlayerInteractionType.Binder)
                elseif type(_G.ConfirmBinder) == "function" then
                    pcall(_G.ConfirmBinder)
                end
                CloseConfirmInteraction()
            end,
            secondaryLabel = "Cancel [Esc]",
            onSecondary = function()
                HideStaticPopupSafe("CONFIRM_BINDER")
                if _G.C_PlayerInteractionManager and type(_G.C_PlayerInteractionManager.ClearInteraction) == "function"
                    and _G.Enum and _G.Enum.PlayerInteractionType and _G.Enum.PlayerInteractionType.Binder then
                    pcall(_G.C_PlayerInteractionManager.ClearInteraction, _G.Enum.PlayerInteractionType.Binder)
                end
                CloseConfirmInteraction()
            end,
        })
    elseif event == "GOSSIP_CLOSED" then
        activeBypassGossip = false
        local closeSeq = interactionSeq
        C_Timer.After(0, function()
            if activeSessionKind ~= "GOSSIP" then
                RestoreBlizzardFrame(_G.GossipFrame)
                return
            end
            if closeSeq == interactionSeq and not IsGossipInteractionActive() then
                if currentMode == "GOSSIP" or currentMode == nil then
                    HideNonPreviewReader()
                end
                RestoreBlizzardFrame(_G.GossipFrame)
            end
        end)
    elseif event == "QUEST_FINISHED" then
        local closeSeq = interactionSeq
        C_Timer.After(0, function()
            if activeSessionKind ~= "QUEST" then
                RestoreBlizzardFrame(_G.QuestFrame)
                return
            end
            if closeSeq == interactionSeq and not IsQuestInteractionActive() then
                if currentMode ~= "GOSSIP" and currentMode ~= "PREVIEW" then
                    HideNonPreviewReader()
                end
                RestoreBlizzardFrame(_G.QuestFrame)
            end
        end)
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local iEnum = _G.Enum and _G.Enum.PlayerInteractionType
        if not iEnum then return end
        if arg1 == iEnum.Gossip then
            activeBypassGossip = false
            local closeSeq = interactionSeq
            C_Timer.After(0, function()
                if activeSessionKind ~= "GOSSIP" then
                    RestoreBlizzardFrame(_G.GossipFrame)
                    return
                end
                if closeSeq == interactionSeq and not IsGossipInteractionActive() then
                    if currentMode == "GOSSIP" or currentMode == nil then
                        HideNonPreviewReader()
                    end
                    RestoreBlizzardFrame(_G.GossipFrame)
                end
            end)
        elseif arg1 == iEnum.Binder then
            if currentMode == "CONFIRM" and activeConfirmKind == "BINDER" then
                CloseConfirmInteraction()
            end
        elseif arg1 == iEnum.QuestGiver then
            local closeSeq = interactionSeq
            C_Timer.After(0, function()
                if activeSessionKind ~= "QUEST" then
                    RestoreBlizzardFrame(_G.QuestFrame)
                    return
                end
                if closeSeq == interactionSeq and not IsQuestInteractionActive() then
                    if currentMode ~= "GOSSIP" and currentMode ~= "PREVIEW" then
                        HideNonPreviewReader()
                    end
                    RestoreBlizzardFrame(_G.QuestFrame)
                end
            end)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        local db = EnsureDB()
        if db.hideInCombat ~= false then
            interactionSeq = interactionSeq + 1
            activeBypassGossip = false
            currentMode = nil
            activeSessionKind = nil
            activeConfirmKind = nil
            selectedChoiceIndex = nil
            wipe(currentOptions)
            if readerFrame and readerFrame:IsShown() then
                readerFrame:Hide()
            end
            RestoreAllBlizzardFrames()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        FlushPendingCombatRestores()
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
        local state, _, detail = DynamicDialogue:GetDetailedStatus()
        Print("Status: " .. state .. " -- " .. detail)
    else
        DynamicDialogue:Open()
    end
end
