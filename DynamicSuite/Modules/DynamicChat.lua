-- ============================================================================
-- DynamicChat v1.4.0
-- Zero-Taint Target Whisper (/ww), Combat Whisper Protection, Compact Channel Tags & GPU Buffer Optimizer
-- Retail 12.1.5 (Interface 120105) | Strict ASCII (NonASCII: 0, HasBOM: False)
-- ============================================================================

local addonName = ...
local ADDON_FOLDER = (type(addonName) == "string" and addonName ~= "") and addonName or "DynamicSuite"

local function ResolveAddonVersion(folderName, fallback)
    local fb = fallback or "2.8.0"
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

local VERSION = ResolveAddonVersion(ADDON_FOLDER, "2.8.0")
if ShouldYieldToOtherInstall(ADDON_FOLDER, "DynamicChat", VERSION, _G.DynamicChat) then
    return
end
local DC_NS = {}
local isInitialized = false

local function IsModuleDisabledInSuite(modName)
    local key = modName or "DynamicChat"
    local shortK = key:gsub("^Dynamic", ""):lower()
    if _G.DynamicSuite and type(_G.DynamicSuite.IsSuiteModuleExplicitlyDisabled) == "function" then
        local ok, res = pcall(_G.DynamicSuite.IsSuiteModuleExplicitlyDisabled, key)
        if ok and res == true then
            return true
        end
    end
    local db = _G.DynamicSuiteDB
    if type(db) == "table" then
        if type(db.disabledModules) == "table" and (db.disabledModules[key] == true or db.disabledModules[shortK] == true or db.disabledModules.DynamicChat == true or db.disabledModules.chat == true) then
            return true
        end
        if type(db.global) == "table" and type(db.global.disabledModules) == "table" and (db.global.disabledModules[key] == true or db.global.disabledModules[shortK] == true or db.global.disabledModules.DynamicChat == true or db.global.disabledModules.chat == true) then
            return true
        end
    end
    return false
end

local DynamicChat = _G.DynamicChat or CreateFrame("Frame", "DynamicChatEngineFrame")
_G.DynamicChat = DynamicChat
DC_NS.DynamicChat = DynamicChat
DynamicChat._loadedBySuite = (ADDON_FOLDER == "DynamicSuite")
DynamicChat._loadedVersion = VERSION
DynamicChat.version = VERSION

function DynamicChat:IsDisabledInSuite()
    return IsModuleDisabledInSuite("DynamicChat")
end

local function SafeRegisterUISpecialFrame(frameName)
    if type(frameName) ~= "string" or frameName == "" then return end
    if type(UISpecialFrames) ~= "table" then return end
    if InCombatLockdown and InCombatLockdown() then return end
    for i = 1, #UISpecialFrames do
        if UISpecialFrames[i] == frameName then
            return
        end
    end
    tinsert(UISpecialFrames, frameName)
end

local function PreRegisterDynamicChatSpecialFrames()
    SafeRegisterUISpecialFrame("DynamicChatHistoryModal")
    SafeRegisterUISpecialFrame("DynamicChatRailCustomizerMenu")
    SafeRegisterUISpecialFrame("DynamicChatCopyPopup")
    SafeRegisterUISpecialFrame("DynamicChatStandaloneFrame")
    SafeRegisterUISpecialFrame("DynamicChatSoundDropdownPopover")
    SafeRegisterUISpecialFrame("DynamicChatFontDropdownMenu")
    SafeRegisterUISpecialFrame("DynamicChatReloadPromptModal")
end

local ICON_MAIN         = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_chat.tga"
local ICON_WHITE        = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_white.tga"
local ICON_ACCENT       = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_accent.tga"
local ICON_CHECK        = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_check.tga"
local ICON_CHEVRON_DOWN = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga"
local ICON_CHEVRON_UP   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga"
local ICON_COG          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_cog.tga"
local ICON_SOCIAL       = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_social.tga"
local ICON_SHIELD       = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_shield.tga"
local ICON_COPY         = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_copy.tga"
local ICON_VAULT        = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_vault.tga"
local ICON_LOG          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_log.tga"
local ICON_LOCK         = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_lock.tga"

-- ============================================================================
-- 1. SECRET-VALUE & 6-CHAR HEX SANITIZATION GUARDS
-- ============================================================================

local function IsSecretValue(val)
    if issecretvalue and issecretvalue(val) then return true end
    if val == nil then return false end
    if canaccessvalue and not canaccessvalue(val) then return true end
    return false
end

local function HasAnySecretArg(...)
    local n = select("#", ...)
    for i = 1, n do
        local v = select(i, ...)
        if v ~= nil then
            if issecretvalue and issecretvalue(v) then return true end
            if canaccessvalue and not canaccessvalue(v) then return true end
        end
    end
    return false
end

local function SanitizeHex6(hex, r, g, b)
    if type(hex) == "string" and not IsSecretValue(hex) then
        local clean = hex:gsub("^|c", ""):gsub("^#", "")
        if #clean == 8 then
            clean = clean:sub(3, 8)
        end
        if #clean == 6 and clean:match("^%x%x%x%x%x%x$") then
            return clean:upper()
        end
    end
    local ri = math.max(0, math.min(255, math.floor((tonumber(r) or 0.22) * 255 + 0.5)))
    local gi = math.max(0, math.min(255, math.floor((tonumber(g) or 0.74) * 255 + 0.5)))
    local bi = math.max(0, math.min(255, math.floor((tonumber(b) or 0.97) * 255 + 0.5)))
    return string.format("%02X%02X%02X", ri, gi, bi)
end

DynamicChat.IsSecretValue = IsSecretValue
DynamicChat.SanitizeHex6  = SanitizeHex6

DynamicChat._editBoxFocused = false

function DynamicChat.SafeFrameIsShown(frame, fallback)
    if not frame or type(frame.IsShown) ~= "function" then
        return fallback and true or false
    end
    local ok, shown = pcall(frame.IsShown, frame)
    if not ok or IsSecretValue(shown) then
        return fallback and true or false
    end
    return shown == true
end

function DynamicChat.SafeEditBoxHasFocus(editBox)
    local targetEB = editBox or _G.ChatFrame1EditBox
    local sawSecret = false

    if type(_G.ChatEdit_GetActiveWindow) == "function" then
        local okW, activeWin = pcall(_G.ChatEdit_GetActiveWindow)
        if not okW or IsSecretValue(activeWin) then
            sawSecret = true
        elseif activeWin ~= nil then
            return true
        end
    end

    if targetEB then
        if type(targetEB.IsShown) == "function" then
            local okS, shown = pcall(targetEB.IsShown, targetEB)
            if not okS or IsSecretValue(shown) then
                sawSecret = true
            elseif shown == true then
                if type(targetEB.HasFocus) == "function" then
                    local okF, focused = pcall(targetEB.HasFocus, targetEB)
                    if not okF or IsSecretValue(focused) then
                        sawSecret = true
                    elseif focused == true then
                        return true
                    end
                end
            end
        elseif type(targetEB.HasFocus) == "function" then
            local okF, focused = pcall(targetEB.HasFocus, targetEB)
            if not okF or IsSecretValue(focused) then
                sawSecret = true
            elseif focused == true then
                return true
            end
        end
    end

    if sawSecret then
        return DynamicChat._editBoxFocused == true
    end
    return false
end

local function IsInCombatOrActiveKeystone()
    if InCombatLockdown and InCombatLockdown() then
        return true
    end
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        return true
    end
    if IsEncounterInProgress and IsEncounterInProgress() then
        return true
    end
    if _G.C_ChallengeMode and type(_G.C_ChallengeMode.IsChallengeModeActive) == "function" then
        local ok, active = pcall(_G.C_ChallengeMode.IsChallengeModeActive)
        if ok and active == true then
            return true
        end
    end
    return false
end

local function IsPrimaryChatDockVisible()
    local cf1 = _G.ChatFrame1
    if not cf1 then return false end
    if UIParent and not DynamicChat.SafeFrameIsShown(UIParent, true) then
        return false
    end
    if _G.C_PetBattles and type(_G.C_PetBattles.IsInBattle) == "function" then
        local okPB, inPB = pcall(_G.C_PetBattles.IsInBattle)
        if okPB and inPB == true then return false end
    end
    if DynamicChat.SafeFrameIsShown(cf1, false) then return true end
    if _G.GeneralDockManager and DynamicChat.SafeFrameIsShown(_G.GeneralDockManager, false) then
        return true
    end
    if _G.SELECTED_DOCK_FRAME and DynamicChat.SafeFrameIsShown(_G.SELECTED_DOCK_FRAME, false) then
        return true
    end
    return false
end

-- ============================================================================
-- 2. DEFAULTS, CONFLICT REGISTRY & SHORT CHANNEL FORMAT TABLE
-- ============================================================================

DynamicChat.CONFLICT_REGISTRY = {
    -- Direct Replacement Addons (kind = "DIRECT" / mode = "REPLACE")
    { addon = "Chattynator",          label = "Chattynator",                 kind = "DIRECT",  mode = "REPLACE", desc = "Overlaps chat frame handling, target whisper shortcuts, channel shorteners, and URL copying." },
    { addon = "Prat-3.0",             label = "Prat 3.0",                    kind = "DIRECT",  mode = "REPLACE", desc = "Overlaps target whisper shortcuts, short channel tags, arrow history, and URL copy." },
    { addon = "BasicChatMods",        label = "BasicChatMods",               kind = "DIRECT",  mode = "REPLACE", desc = "Overlaps short channel tags, sticky channels, and URL copy." },
    { addon = "Chatter",              label = "Chatter",                     kind = "DIRECT",  mode = "REPLACE", desc = "Overlaps target whisper shortcuts, channel formatting, and chat input history." },
    { addon = "ls_Glass",             label = "LS: Glass",                   kind = "DIRECT",  mode = "REPLACE", desc = "Replaces chat scrolling, chat input handling, and clickable URL links." },
    { addon = "LS_Glass",             label = "LS: Glass",                   kind = "DIRECT",  mode = "REPLACE", desc = "Replaces chat scrolling, chat input handling, and clickable URL links." },
    { addon = "Glass",                label = "Glass",                       kind = "DIRECT",  mode = "REPLACE", desc = "Overlaps chat scrolling, fading, and chat input handling." },
    { addon = "PhanxChat",            label = "PhanxChat",                   kind = "DIRECT",  mode = "REPLACE", desc = "Overlaps short channel names, URL copying, and sticky channels." },
    { addon = "DejaChat",             label = "DejaChat",                    kind = "DIRECT",  mode = "REPLACE", desc = "Overlaps chat frame styling, scrolling, and channel formatting." },
    -- Overlapping / Mutually Exclusive Chat Addons (all kind = "DIRECT", mode = "REPLACE")
    { addon = "EllesmereUI",          label = "EllesmereUI",                 kind = "DIRECT",  mode = "REPLACE", desc = "Conflicts with DynamicChat frame skinning, chat input anchoring, and chat layout." },
    { addon = "EllesmereUIChat",      label = "EllesmereUI Chat",            kind = "DIRECT",  mode = "REPLACE", desc = "Conflicts with DynamicChat frame skinning, chat input anchoring, and chat layout." },
    { addon = "EllesmereUI_Chat",     label = "EllesmereUI Chat",            kind = "DIRECT",  mode = "REPLACE", desc = "Conflicts with DynamicChat frame skinning, chat input anchoring, and chat layout." },
    { addon = "EnhanceQoLChatSocial", label = "EnhanceQoL (Chat & Social)",  kind = "DIRECT",  mode = "REPLACE", desc = "Overlaps channel formatting and chat social features." },
    { addon = "WIM",                  label = "WIM (WoW Instant Messenger)", kind = "DIRECT",  mode = "REPLACE", desc = "Overlaps whisper window and whisper routing." },
    { addon = "Leatrix_Plus",         label = "Leatrix Plus",                kind = "DIRECT",  mode = "REPLACE", desc = "Overlaps class-colour, short-channel, and chat scrolling." },
    { addon = "ElvUI",                label = "ElvUI (Chat)",                kind = "DIRECT",  mode = "REPLACE", desc = "Conflicts with DynamicChat frame skinning, short-channel, URL link, and chat scrolling." },
    { addon = "WindTools",            label = "ElvUI WindTools",             kind = "DIRECT",  mode = "REPLACE", desc = "Overlaps chat link and channel bar enhancements." },
}

_G.DynamicSuite = _G.DynamicSuite or {}
_G.DynamicSuite.CONFLICT_REGISTRY = _G.DynamicSuite.CONFLICT_REGISTRY or {}
_G.DynamicSuite.CONFLICT_REGISTRY["DynamicChat"] = {
    conflicts        = { "EllesmereUIChat", "EllesmereUI_Chat", "EllesmereUI", "Chattynator", "Prat-3.0", "ls_Glass", "LS_Glass", "Glass", "BasicChatMods", "Chatter", "PhanxChat", "DejaChat", "WIM", "ElvUI" },
    hardConflicts    = { "EllesmereUIChat", "EllesmereUI_Chat", "EllesmereUI", "Chattynator", "Prat-3.0", "ls_Glass", "LS_Glass", "Glass", "BasicChatMods", "Chatter", "PhanxChat", "DejaChat", "WIM", "ElvUI" },
    partialConflicts = { "EnhanceQoL", "EnhanceQoLChatSocial", "Leatrix_Plus", "WindTools" },
    softConflicts    = { "EnhanceQoL", "EnhanceQoLChatSocial", "Leatrix_Plus", "WindTools" },
    category         = "Chat & Communications",
    entries          = DynamicChat.CONFLICT_REGISTRY,
}
_G.DynamicSuite.CONFLICT_REGISTRY["chat"] = _G.DynamicSuite.CONFLICT_REGISTRY["DynamicChat"]

local function BuildBlizzardChatSoundList()
    local sk = _G.SOUNDKIT
    return {
        { value = "BLIZZ_RAID_WARNING",   label = "Blizzard Raid Warning",   soundKit = (sk and sk.RAID_WARNING) or 8959,          fileDataID = 567397, group = "BLIZZARD", source = "Blizzard" },
        { value = "BLIZZ_WHISPER",        label = "Blizzard Whisper",        soundKit = (sk and sk.TELL_MESSAGE) or 3081,          fileDataID = 567482, group = "BLIZZARD", source = "Blizzard" },
        { value = "BLIZZ_BNET_TOAST",     label = "Blizzard Battle.net",     soundKit = (sk and sk.UI_BNET_TOAST) or 18019,        fileDataID = 567421, group = "BLIZZARD", source = "Blizzard" },
        { value = "BLIZZ_READY_CHECK",    label = "Blizzard Ready Check",    soundKit = (sk and sk.READY_CHECK) or 8960,           fileDataID = 567478, group = "BLIZZARD", source = "Blizzard" },
        { value = "BLIZZ_MAP_PING",       label = "Blizzard Map Ping",       soundKit = (sk and sk.MAP_PING) or 3175,              fileDataID = 567416, group = "BLIZZARD", source = "Blizzard" },
        { value = "BLIZZ_AUCTION_BELL",   label = "Blizzard Auction Bell",   soundKit = (sk and sk.AUCTION_WINDOW_OPEN) or 5274,   fileDataID = 567499, group = "BLIZZARD", source = "Blizzard" },
        { value = "BLIZZ_QUEST_COMPLETE", label = "Blizzard Quest Complete", soundKit = (sk and sk.IG_QUEST_LIST_COMPLETE) or 878, fileDataID = 567439, group = "BLIZZARD", source = "Blizzard" },
    }
end

local BLIZZARD_SOUND_BY_KEY = {}
for _, bDef in ipairs(BuildBlizzardChatSoundList()) do
    BLIZZARD_SOUND_BY_KEY[bDef.value] = bDef
end

local function IsBuiltInBlizzardSoundKey(key)
    return type(key) == "string" and BLIZZARD_SOUND_BY_KEY[key] ~= nil
end

local SoundMgr = {}
do
    local soundBase = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Sounds\\"
    local chimesList = {
        { key = "DC_CHIME_SPARK",   short = "Spark",   label = "DynamicSuite: Spark (High Pluck)",     file = "DynamicChat_ChimeSpark.ogg" },
        { key = "DC_KEYWORD_PULSE", short = "Pulse",   label = "DynamicSuite: Pulse (Warm Bell)",      file = "DynamicChat_KeywordPulse.ogg" },
        { key = "DC_CHIME_DUO",     short = "Duo",     label = "DynamicSuite: Duo (Rising Fifth)",     file = "DynamicChat_ChimeDuo.ogg" },
        { key = "DC_CHIME_CASCADE", short = "Cascade", label = "DynamicSuite: Cascade (Crystal Harp)", file = "DynamicChat_MentionWarm.ogg" },
        { key = "DC_CHIME_ECHO",    short = "Echo",    label = "DynamicSuite: Echo (Glass Ping)",      file = "DynamicChat_ChimeEcho.ogg" },
        { key = "DC_CHIME_FOURTH",  short = "Chime",   label = "DynamicSuite: Chime (Rising Fourth)",  file = "DynamicChat_ChimeFourth.ogg" },
        { key = "DC_CHIME_BLOOM",   short = "Bloom",   label = "DynamicSuite: Bloom (Major Ninth)",    file = "DynamicChat_ChimeBloom.ogg" },
        { key = "DC_CHIME_DEWDROP", short = "Dewdrop", label = "DynamicSuite: Dewdrop (Low Bell)",     file = "DynamicChat_ChimeDewdrop.ogg" },
        { key = "DC_CHIME_RIPPLE",  short = "Ripple",  label = "DynamicSuite: Ripple (Grace Flick)",   file = "DynamicChat_ChimeRipple.ogg" },
        { key = "DC_CHIME_PRISM",   short = "Prism",   label = "DynamicSuite: Prism (Falling Triad)",  file = "DynamicChat_ChimePrism.ogg" },
    }
    local chimesMap = {}
    for _, entry in ipairs(chimesList) do
        entry.path = soundBase .. entry.file
        entry.value = entry.key
        chimesMap[entry.key] = entry
    end
    SoundMgr.chimesList = chimesList
    SoundMgr.chimesMap = chimesMap
end

local function IsBuiltInSuiteChimeKey(key)
    return type(key) == "string" and SoundMgr.chimesMap[key] ~= nil
end

function SoundMgr.IsValidCustomAudioPath(path)
    if type(path) ~= "string" then return false end
    local trimmed = path:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" then return false end
    local low = trimmed:lower()
    if low:match("%.wav$") then return false end
    return (low:match("%.ogg$") ~= nil) or (low:match("%.mp3$") ~= nil)
end

function SoundMgr.IsCustomSoundKey(key)
    return type(key) == "string" and key:sub(1, 7) == "CUSTOM:"
end

function SoundMgr.ResolveCustomSound(key)
    if not SoundMgr.IsCustomSoundKey(key) then return nil end
    local db = _G.DynamicChatDB
    if type(db) ~= "table" or type(db.customSounds) ~= "table" then return nil end
    for _, entry in ipairs(db.customSounds) do
        if type(entry) == "table" and entry.id == key and SoundMgr.IsValidCustomAudioPath(entry.path) then
            return {
                value  = entry.id,
                name   = entry.label or entry.id,
                label  = entry.label or entry.id,
                path   = entry.path,
                source = "Custom",
                group  = "CUSTOM",
            }
        end
    end
    return nil
end

function SoundMgr.IsValidSavedSoundKey(val)
    if val == "NONE" or IsBuiltInBlizzardSoundKey(val) or IsBuiltInSuiteChimeKey(val) then
        return true
    end
    if SoundMgr.ResolveCustomSound(val) ~= nil then
        return true
    end
    if type(val) == "number" then
        return true
    end
    if type(val) ~= "string" or val == "" then
        return false
    end
    local isLegacyWavKey = (val:match("^ds_") ~= nil or val:match("^ex_") ~= nil or val:lower():match("%.wav$") ~= nil)
    if isLegacyWavKey then return false end
    return (val:find("^LSM:") ~= nil) or (val:find("^DBM:") ~= nil) or (val:find("^BW:") ~= nil)
        or (val:find("^WA:") ~= nil) or (val:find("^ELV:") ~= nil) or (val:find("^EXBOSS:") ~= nil)
        or (val:find("[\\/]") ~= nil)
end

local DEFAULTS = {
    -- Tab 1: Target Whisper (/ww), Combat Whisper Protection & Input
    enableTargetWhisper         = true,
    whisperTriggerMode          = "WW",
    targetWhisperClearOnInvalid = true,
    protectCombatWhispers       = true,
    arrowHistoryNoAlt           = true,
    stickyWhisper               = false,
    stickyGroupChannels         = true,

    -- Tab 2: Sleek Obsidian Chat Skin, Left Utility Rail, Channel Tags & Formatting
    enableSleekChatSkin         = true,
    chatBgAlpha                 = 0.25,
    chatBorderStyle             = "ACCENT",
    editBoxPosition             = "BOTTOM", -- "BOTTOM" (Below Chat) | "TOP" (Above Chat Tabs)
    editBoxBackgroundMode       = "ALWAYS", -- "ALWAYS" (Seamless Smoked-Glass Dock) | "FOCUS_ONLY" (Show Only When Typing)
    hideChatButtons             = true,
    applySuiteChatFont          = true,
    chatFontKey                 = "SUITE",
    chatFontSize                = 13,
    chatFontOutline             = "OUTLINE", -- "NONE" | "OUTLINE" | "THICKOUTLINE"
    chatFontShadow              = true,
    chatLineSpacing             = 2,
    chatMessageFade             = true,
    chatFramePos                = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 0, y = 0, width = 430, height = 200 },
    chatFrameScale              = 1.0,
    leftRailMode                = "ALWAYS", -- "ALWAYS" | "HOVER" | "COMBAT_HIDE" | "OFF"
    railOrder                   = { "social", "durability", "vault", "copy", "combatlog", "lock", "settings", "scrollbottom" },
    railButtons                 = {
        social       = true,
        durability   = true,
        vault        = true,
        copy         = true,
        combatlog    = true,
        lock         = false,
        settings     = true,
        scrollbottom = true,
    },
    shortChannelNames           = false,
    classColorNames             = true,
    showTimestamps              = true,
    timestampFormat             = "%H:%M ",

    -- Tab 3: Chat Notification Sounds (Per-Channel Engine)
    enableChatSounds            = true,
    enableSoundAlerts           = true, -- Synced compatibility alias for enableChatSounds
    soundMuteInCombat           = false,
    soundOutputChannel          = "Master", -- "Master" | "SFX" | "Dialog"
    soundThrottleSec            = 1.5, -- 0 | 1.5 | 3 | 5
    channelSounds               = {
        WHISPER = "BLIZZ_WHISPER",      -- Covers CHAT_MSG_WHISPER & CHAT_MSG_BN_WHISPER
        GUILD   = "BLIZZ_BNET_TOAST",   -- Covers CHAT_MSG_GUILD & CHAT_MSG_OFFICER
        PARTY   = "BLIZZ_MAP_PING",     -- Covers CHAT_MSG_PARTY, CHAT_MSG_PARTY_LEADER, CHAT_MSG_INSTANCE_CHAT, CHAT_MSG_INSTANCE_CHAT_LEADER
        RAID    = "BLIZZ_RAID_WARNING", -- Covers CHAT_MSG_RAID, CHAT_MSG_RAID_LEADER, CHAT_MSG_RAID_WARNING
        SAY     = "NONE",               -- Covers CHAT_MSG_SAY & CHAT_MSG_YELL (Off by default so city crowd /say doesn't spam)
    },
    enableMentionAlerts         = true,
    mentionKeywords             = "",
    mentionNameSound            = "DC_CHIME_CASCADE",
    mentionKeywordSound         = "DC_KEYWORD_PULSE",
    mentionHighlightInChat      = true,
    mentionAlertToast           = true,
    customSounds                = {},

    -- Tab 4: Links, Scrolling, Chat History & Performance
    clickableURLs               = true,
    fastChatScroll              = true,
    shiftScrollLines            = 5,
    ctrlJumpScroll              = true,
    enableQuickSlash            = true,
    preserveChatHistory         = true,
    enableGPUBufferCap          = true,
    maxChatLines                = 250,
    optimizeCombatLogTab        = true,
    savedChatHistory            = {},

    -- Legacy yield flags (forced off: DynamicChat never yields)
    yieldSharedHooks            = false,
    yieldHooks                  = {},

    -- UI State
    activeSubTab                = 1,
}

local function CaptureOriginalChatStrings()
    -- Retail 12.1.5 Zero-Taint Guard: Never read/write _G.CHAT_*_GET globals so
    -- Blizzard's ChatFrameMixin:MessageEventHandler never concatenates a tainted
    -- global format string with a <secret string> message/playerLink in Raids or M+.
end

-- ============================================================================
-- 3. UTILITY, FONT & SUITE ACCENT PALETTE HELPERS
-- ============================================================================

local function GetFontPath()
    if _G.DynamicSuite and _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.GetFont) == "function" then
        local okF, pF = pcall(_G.DynamicSuite.UI.GetFont)
        if okF and type(pF) == "string" and pF ~= "" then return pF end
    end
    if _G.DynamicSuite and type(_G.DynamicSuite.GetFontPath) == "function" then
        local ok, p = pcall(_G.DynamicSuite.GetFontPath, _G.DynamicSuite)
        if ok and type(p) == "string" and p ~= "" then return p end
    end
    return "Fonts\\FRIZQT__.TTF"
end

local function SetSafeFont(fs, size, flags)
    if not fs or not fs.SetFont then return end
    local ok = fs:SetFont(GetFontPath(), size or 11, flags or "")
    if not ok then
        fs:SetFont("Fonts\\FRIZQT__.TTF", size or 11, flags or "")
    end
end

local TypographyMgr = {}

local function DisableTexPixelSnap(tex)
    if not tex then return end
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
end

local function GetSuiteAccent()
    if _G.DynamicSuite and type(_G.DynamicSuite.GetSuiteAccent) == "function" then
        local ok, a, b, c, d = pcall(_G.DynamicSuite.GetSuiteAccent, _G.DynamicSuite)
        if ok then
            if type(a) == "table" then
                local r = tonumber(a.r or a[1]) or 0.22
                local g = tonumber(a.g or a[2]) or 0.74
                local bl = tonumber(a.b or a[3]) or 0.97
                local hex6 = SanitizeHex6(a.hex, r, g, bl)
                return r, g, bl, hex6, "FF" .. hex6
            elseif type(a) == "number" and type(b) == "number" and type(c) == "number" then
                local hex6 = SanitizeHex6(d, a, b, c)
                return a, b, c, hex6, "FF" .. hex6
            end
        end
    end
    local _, classFile = UnitClass and UnitClass("player") or nil, nil
    local cc = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
    if cc then
        local hex6 = SanitizeHex6(cc.colorStr, cc.r, cc.g, cc.b)
        return cc.r, cc.g, cc.b, hex6, "FF" .. hex6
    end
    return 0.22, 0.74, 0.97, "38BDF8", "FF38BDF8"
end

local function ColorWithAccent(text)
    local _, _, _, hex6 = GetSuiteAccent()
    return "|cFF" .. hex6 .. tostring(text or "") .. "|r"
end

local function FormatTooltipCmd(cmdText, actionText, cmdHex)
    if _G.DynamicSuite and type(_G.DynamicSuite.FormatTooltipCommand) == "function" then
        return _G.DynamicSuite.FormatTooltipCommand(cmdText, actionText, cmdHex)
    end
    local hex6 = SanitizeHex6(cmdHex or "34D399", 0.204, 0.827, 0.600)
    local cmd = tostring(cmdText or "")
    if cmd ~= "" and not cmd:match(":$") then
        cmd = cmd .. ":"
    end
    return string.format("|cFF%s%s|r |cFFE2E8F0%s|r", hex6, cmd, tostring(actionText or ""))
end

local function PrintMsg(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(ColorWithAccent("Dynamic") .. "|cFFFFFFFFChat|r: " .. tostring(msg))
    end
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

local function EnsureDB()
    if type(_G.DynamicChatDB) ~= "table" then
        _G.DynamicChatDB = {}
    end
    CopyDefaults(DEFAULTS, _G.DynamicChatDB)
    -- Force target whisper shortcut mode cleanly to /ww
    _G.DynamicChatDB.whisperTriggerMode = "WW"
    if _G.DynamicChatDB.autoYieldEllesmereChat == nil then
        _G.DynamicChatDB.autoYieldEllesmereChat = true
    end
    if type(_G.DynamicChatDB.yieldHooks) ~= "table" then
        _G.DynamicChatDB.yieldHooks = {}
    end
    if not _G.DynamicChatDB._v102_smoked25 then
        _G.DynamicChatDB._v102_smoked25 = true
        if _G.DynamicChatDB.chatBgAlpha == 0.35 or _G.DynamicChatDB.chatBgAlpha == 0.72 then
            _G.DynamicChatDB.chatBgAlpha = 0.25
        end
    end
    if (_G.DynamicChatDB.chatAnchorVersion or 0) < 4 then
        _G.DynamicChatDB.chatAnchorVersion = 4
        _G.DynamicChatDB._v163_bottomLeftAnchor = true
        local curPos = _G.DynamicChatDB.chatFramePos
        local keepW = (type(curPos) == "table" and tonumber(curPos.width)) or 430
        local keepH = (type(curPos) == "table" and tonumber(curPos.height)) or 200
        _G.DynamicChatDB.chatFramePos = {
            point         = "BOTTOMLEFT",
            relativePoint = "BOTTOMLEFT",
            relPoint      = "BOTTOMLEFT",
            x             = 0,
            y             = 0,
            width         = keepW,
            height        = keepH,
        }
        _G.DynamicChatDB.editBoxPosition = "BOTTOM"
        if type(_G.DynamicSuiteDB) == "table" then
            _G.DynamicSuiteDB.chatEditBoxPosition = "BOTTOM"
            if type(_G.DynamicSuiteDB.global) == "table" and type(_G.DynamicSuiteDB.global.hudPositions) == "table" then
                _G.DynamicSuiteDB.global.hudPositions["CHAT"] = nil
            end
        end
    end
    if _G.DynamicChatDB.editBoxPosition ~= "TOP" and _G.DynamicChatDB.editBoxPosition ~= "BOTTOM" then
        local suitePos = type(_G.DynamicSuiteDB) == "table" and _G.DynamicSuiteDB.chatEditBoxPosition or nil
        _G.DynamicChatDB.editBoxPosition = (suitePos == "TOP") and "TOP" or "BOTTOM"
    end
    if type(_G.DynamicSuiteDB) == "table" then
        _G.DynamicSuiteDB.chatEditBoxPosition = _G.DynamicChatDB.editBoxPosition
    end
    if _G.DynamicChatDB.enableChatSounds == nil then
        _G.DynamicChatDB.enableChatSounds = (_G.DynamicChatDB.enableSoundAlerts ~= false)
    end
    _G.DynamicChatDB.enableChatSounds = (_G.DynamicChatDB.enableChatSounds ~= false)
    _G.DynamicChatDB.enableSoundAlerts = _G.DynamicChatDB.enableChatSounds
    _G.DynamicChatDB.soundMuteInCombat = (_G.DynamicChatDB.soundMuteInCombat == true)
    if type(_G.DynamicChatDB.channelSounds) ~= "table" then
        _G.DynamicChatDB.channelSounds = {}
    end
    if not _G.DynamicChatDB._v220_customChatSounds then
        _G.DynamicChatDB._v220_customChatSounds = true
        for _, legacyKey in ipairs({ "BN_WHISPER", "PARTY_LEADER", "RAID_LEADER", "INSTANCE", "OFFICER", "SAY_YELL", "CHANNEL" }) do
            _G.DynamicChatDB.channelSounds[legacyKey] = nil
        end
    end
    if type(_G.DynamicChatDB.customSounds) ~= "table" then
        _G.DynamicChatDB.customSounds = {}
    else
        local cleanCustom = {}
        local seenCustom = {}
        for _, entry in ipairs(_G.DynamicChatDB.customSounds) do
            if type(entry) == "table" and type(entry.id) == "string" and entry.id ~= "" and SoundMgr.IsValidCustomAudioPath(entry.path) then
                if not seenCustom[entry.id] then
                    seenCustom[entry.id] = true
                    cleanCustom[#cleanCustom + 1] = {
                        id    = entry.id,
                        label = (type(entry.label) == "string" and entry.label ~= "") and entry.label or entry.id,
                        path  = entry.path,
                    }
                end
            end
        end
        _G.DynamicChatDB.customSounds = cleanCustom
    end
    for chKey, defVal in pairs(DEFAULTS.channelSounds) do
        local cur = _G.DynamicChatDB.channelSounds[chKey]
        if cur == "DC_MENTION_WARM" then
            cur = "DC_CHIME_CASCADE"
            _G.DynamicChatDB.channelSounds[chKey] = cur
        end
        if not SoundMgr.IsValidSavedSoundKey(cur) then
            _G.DynamicChatDB.channelSounds[chKey] = defVal
        end
    end
    if _G.DynamicChatDB.enableMentionAlerts == nil then
        _G.DynamicChatDB.enableMentionAlerts = true
    end
    if type(_G.DynamicChatDB.mentionKeywords) ~= "string" then
        _G.DynamicChatDB.mentionKeywords = ""
    end
    if _G.DynamicChatDB.mentionNameSound == "DC_MENTION_WARM" then
        _G.DynamicChatDB.mentionNameSound = "DC_CHIME_CASCADE"
    end
    if not SoundMgr.IsValidSavedSoundKey(_G.DynamicChatDB.mentionNameSound) then
        _G.DynamicChatDB.mentionNameSound = DEFAULTS.mentionNameSound
    end
    if not SoundMgr.IsValidSavedSoundKey(_G.DynamicChatDB.mentionKeywordSound) then
        _G.DynamicChatDB.mentionKeywordSound = DEFAULTS.mentionKeywordSound
    end
    _G.DynamicChatDB.mentionHighlightInChat = (_G.DynamicChatDB.mentionHighlightInChat ~= false)
    _G.DynamicChatDB.mentionAlertToast = (_G.DynamicChatDB.mentionAlertToast ~= false)
    if type(_G.DynamicChatDB.chatFontKey) ~= "string" or _G.DynamicChatDB.chatFontKey == "" then
        _G.DynamicChatDB.chatFontKey = "SUITE"
    end
    local fSize = tonumber(_G.DynamicChatDB.chatFontSize) or 13
    fSize = math.floor(fSize + 0.5)
    if fSize < 10 then fSize = 10 elseif fSize > 22 then fSize = 22 end
    _G.DynamicChatDB.chatFontSize = fSize
    local fOut = _G.DynamicChatDB.chatFontOutline
    if fOut ~= "NONE" and fOut ~= "OUTLINE" and fOut ~= "THICKOUTLINE" then
        _G.DynamicChatDB.chatFontOutline = "OUTLINE"
    end
    _G.DynamicChatDB.chatFontShadow = (_G.DynamicChatDB.chatFontShadow ~= false)
    local lSpace = tonumber(_G.DynamicChatDB.chatLineSpacing) or 2
    lSpace = math.floor(lSpace + 0.5)
    if lSpace < 0 then lSpace = 0 elseif lSpace > 8 then lSpace = 8 end
    _G.DynamicChatDB.chatLineSpacing = lSpace
    _G.DynamicChatDB.chatMessageFade = (_G.DynamicChatDB.chatMessageFade ~= false)
    return _G.DynamicChatDB
end

-- ============================================================================
-- 3B. 2-TIER CHAT CONFLICT SCANNER & SHARED-HOOK AUTO-YIELD ENGINE
-- ============================================================================

local function IsExternalChatAddonFrozenOrOverridden(addonKey)
    if not addonKey then return false end
    if _G.DynamicSuite then
        if type(_G.DynamicSuite.IsExternalAddonFrozen) == "function" and _G.DynamicSuite.IsExternalAddonFrozen(addonKey) then
            return true
        end
        if type(_G.DynamicSuite.IsAddonFrozen) == "function" and _G.DynamicSuite.IsAddonFrozen(addonKey) then
            return true
        end
    end
    if type(_G.DynamicLoadDB) == "table" then
        if type(_G.DynamicLoadDB.addonStates) == "table" and _G.DynamicLoadDB.addonStates[addonKey] == "FROZEN" then
            return true
        end
        if type(_G.DynamicLoadDB.frozenAddons) == "table" and _G.DynamicLoadDB.frozenAddons[addonKey] == true then
            return true
        end
        if type(_G.DynamicLoadDB.globalData) == "table" then
            if type(_G.DynamicLoadDB.globalData.addonStates) == "table" and _G.DynamicLoadDB.globalData.addonStates[addonKey] == "FROZEN" then
                return true
            end
            if type(_G.DynamicLoadDB.globalData.frozenAddons) == "table" and _G.DynamicLoadDB.globalData.frozenAddons[addonKey] == true then
                return true
            end
        end
    end
    local conflictKey = tostring(addonKey) .. "_DynamicChat"
    if type(_G.DynamicSuiteDB) == "table" and type(_G.DynamicSuiteDB.global) == "table"
        and type(_G.DynamicSuiteDB.global.acknowledgedConflicts) == "table" then
        local ack = _G.DynamicSuiteDB.global.acknowledgedConflicts[conflictKey]
        if ack == "USE_DYNAMIC" or ack == "PREFER_DYNAMIC" or ack == "RUN_BOTH" then
            return true
        end
    end
    return false
end

local function IsAddonLoadedNow(addonKey)
    if not addonKey or not (_G.C_AddOns and type(_G.C_AddOns.IsAddOnLoaded) == "function") then
        return false
    end
    if IsExternalChatAddonFrozenOrOverridden(addonKey) then
        return false
    end
    local ok, res = pcall(_G.C_AddOns.IsAddOnLoaded, addonKey)
    return ok and (res == true) or false
end

local function IsElvUIChatSubModuleEnabled()
    if not IsAddonLoadedNow("ElvUI") then return false end
    local ok, enabled = pcall(function()
        local E = type(_G.ElvUI) == "table" and _G.ElvUI[1]
        return type(E) == "table" and type(E.private) == "table" and type(E.private.chat) == "table" and E.private.chat.enable == true
    end)
    return ok and (enabled == true) or false
end

local function IsLeatrixPlusChatSubModuleEnabled()
    if not IsAddonLoadedNow("Leatrix_Plus") then return false end
    if _G.DynamicSuite and type(_G.DynamicSuite.InspectSmartSubModuleConflict) == "function" then
        local ok, res = pcall(_G.DynamicSuite.InspectSmartSubModuleConflict, "DynamicChat", "Leatrix_Plus")
        if ok then return res == true end
    end
    local ok, enabled = pcall(function()
        local db = _G.LeaPlusDB
        if type(db) ~= "table" then return false end
        return (db["UseEasyChatResizing"] == "On") or (db["HideChatButtons"] == "On") or (db["ShortenChannelNames"] == "On") or (db["ClassColPlayer"] == "On")
    end)
    return ok and (enabled == true) or false
end

local function IsEllesmereUIChatSubModuleEnabled()
    if IsExternalChatAddonFrozenOrOverridden("EllesmereUIChat")
        or IsExternalChatAddonFrozenOrOverridden("EllesmereUI_Chat")
        or IsExternalChatAddonFrozenOrOverridden("EllesmereUI") then
        return false
    end
    if IsAddonLoadedNow("EllesmereUIChat") or IsAddonLoadedNow("EllesmereUI_Chat") then
        return true
    end
    -- When EllesmereUIChat is installed as a separate sub-addon on disk, chat skinning belongs
    -- strictly to that sub-addon. If it is not loaded, do not fall back to the parent EllesmereUI.
    if _G.C_AddOns and type(_G.C_AddOns.GetAddOnInfo) == "function" then
        if _G.C_AddOns.GetAddOnInfo("EllesmereUIChat") ~= nil or _G.C_AddOns.GetAddOnInfo("EllesmereUI_Chat") ~= nil then
            return false
        end
    end
    if not IsAddonLoadedNow("EllesmereUI") then
        return false
    end
    if _G.DynamicSuite and type(_G.DynamicSuite.InspectSmartSubModuleConflict) == "function" then
        local ok, res = pcall(_G.DynamicSuite.InspectSmartSubModuleConflict, "DynamicChat", "EllesmereUI")
        if ok then return res == true end
    end
    local ok, enabled = pcall(function()
        local edb = _G.EllesmereUIDB
        if type(edb) == "table" then
            if type(edb.chat) == "table" and edb.chat.enable == false then
                return false
            end
            if type(edb.modules) == "table" and edb.modules.chat == false then
                return false
            end
        end
        return true
    end)
    return ok and (enabled == true) or false
end

local function IsAddonActiveInSession(addonKey)
    if not addonKey or not _G.C_AddOns then return false end
    if IsExternalChatAddonFrozenOrOverridden(addonKey) then
        return false
    end
    if addonKey == "ElvUI" then
        return IsElvUIChatSubModuleEnabled()
    elseif addonKey == "Leatrix_Plus" then
        return IsLeatrixPlusChatSubModuleEnabled()
    elseif addonKey == "EllesmereUI" or addonKey == "EllesmereUIChat" or addonKey == "EllesmereUI_Chat" then
        return IsEllesmereUIChatSubModuleEnabled()
    end
    return IsAddonLoadedNow(addonKey)
end

local function IsEllesmereUILoaded()
    -- DynamicChat never yields to EllesmereUI / EllesmereUIChat.
    return false
end

local EXTERNAL_CHAT_ENGINES = {
    "Chattynator",
    "Prat-3.0",
    "ls_Glass",
    "LS_Glass",
    "Glass",
}

-- Returns true only when a direct full-chat replacement addon (Chattynator, Prat-3.0, LS: Glass) is loaded.
-- Does not treat ElvUI or EllesmereUI shared-hook auto-yield as a direct replacement so both addons stay enabled together.
function DynamicChat:IsDirectChatReplacementLoaded()
    for _, key in ipairs(EXTERNAL_CHAT_ENGINES) do
        if IsAddonLoadedNow(key) then
            return true, key
        end
    end
    return false, nil
end

-- Returns true only when DynamicChat is disabled in Suite or a direct full-chat engine (Chattynator, Prat-3.0, LS: Glass) is loaded.
-- DynamicChat NEVER yields to EllesmereUI Chat or ElvUI Chat.
function DynamicChat:IsExternalChatEngineLoaded()
    if IsModuleDisabledInSuite("DynamicChat") then
        return true, "DynamicChatDisabled"
    end
    for _, key in ipairs(EXTERNAL_CHAT_ENGINES) do
        if IsAddonLoadedNow(key) then
            return true, key
        end
    end
    return false, nil
end

function DynamicChat:IsChatFrameLayoutOwned()
    if IsModuleDisabledInSuite("DynamicChat") then
        return false
    end
    if self:IsExternalChatEngineLoaded() then
        return false
    end
    return true
end

function DynamicChat:HideHudEditMover()
    self._dsEditModeActive = false
    self._dsDragging = false
    if self._dsDragShield then
        self._dsDragShield:SetScript("OnUpdate", nil)
        if self._dsDragShield.resizeGrip then
            self._dsDragShield.resizeGrip:SetScript("OnUpdate", nil)
        end
        self._dsDragShield:Hide()
    end
    if _G.ChatFrame1 and _G.ChatFrame1.SetAlpha then
        pcall(_G.ChatFrame1.SetAlpha, _G.ChatFrame1, 1.0)
    end
end

function DynamicChat:GetAutoYieldChatAddon()
    local db = _G.DynamicChatDB
    if type(db) == "table" and db.autoYieldEllesmereChat == false then
        return nil
    end
    if IsAddonActiveInSession("EllesmereUIChat") then return "EllesmereUI Chat" end
    if IsAddonActiveInSession("EllesmereUI_Chat") then return "EllesmereUI Chat" end
    if _G.DynamicSuite and type(_G.DynamicSuite.InspectSmartSubModuleConflict) == "function" then
        local ok, active = pcall(_G.DynamicSuite.InspectSmartSubModuleConflict, "DynamicChat", "EllesmereUI")
        if ok and active == true then
            return "EllesmereUI Chat"
        end
    end
    return nil
end

function DynamicChat:IsYieldingSharedHooks()
    if self:GetAutoYieldChatAddon() ~= nil then
        return true
    end
    return false
end

function DynamicChat:HasActivePartialSuiteConflict()
    if self:GetAutoYieldChatAddon() ~= nil then
        return true
    end
    return false
end

function DynamicChat:HasActiveWIMConflict()
    return IsAddonActiveInSession("WIM")
end

function DynamicChat:ScanConflicts()
    local results = {}
    local seenLabels = {}
    local inspectSmart = _G.DynamicSuite and _G.DynamicSuite.InspectSmartSubModuleConflict
    for _, entry in ipairs(self.CONFLICT_REGISTRY or {}) do
        local isSmartAddon = (entry.addon == "EllesmereUI" or entry.addon == "ElvUI" or entry.addon == "Leatrix_Plus" or entry.addon == "EnhanceQoL")
        local isActive = false
        if isSmartAddon and type(inspectSmart) == "function" then
            local ok, subActive = pcall(inspectSmart, "DynamicChat", entry.addon)
            isActive = (ok and subActive == true)
        else
            isActive = IsAddonActiveInSession(entry.addon)
        end
        if isActive then
            local dedupeKey = (entry.kind or "DIRECT") .. ":" .. (entry.label or entry.addon)
            if not seenLabels[dedupeKey] then
                seenLabels[dedupeKey] = true
                results[#results + 1] = {
                    addon = entry.addon,
                    label = entry.label or entry.addon,
                    kind  = entry.kind or ((entry.mode == "YIELD") and "PARTIAL" or "DIRECT"),
                    mode  = entry.mode or ((entry.kind == "PARTIAL") and "YIELD" or "REPLACE"),
                    desc  = entry.desc or entry.reason or "",
                }
            end
        end
    end
    return results
end

DynamicChat.ScanActiveConflicts = DynamicChat.ScanConflicts

function DynamicChat:DisableAndFreezeConflictAddon(conflictAddon)
    if not conflictAddon then return end
    local wasLoaded = IsAddonLoadedNow(conflictAddon)
    local pName = UnitName and UnitName("player") or nil
    if _G.C_AddOns and _G.C_AddOns.DisableAddOn then
        pcall(_G.C_AddOns.DisableAddOn, conflictAddon, pName)
        pcall(_G.C_AddOns.DisableAddOn, conflictAddon)
        if conflictAddon == "ls_Glass" or conflictAddon == "LS_Glass" then
            pcall(_G.C_AddOns.DisableAddOn, "ls_Glass", pName)
            pcall(_G.C_AddOns.DisableAddOn, "ls_Glass")
            pcall(_G.C_AddOns.DisableAddOn, "LS_Glass", pName)
            pcall(_G.C_AddOns.DisableAddOn, "LS_Glass")
        end
    end

    _G.DynamicLoadDB = _G.DynamicLoadDB or {}
    _G.DynamicLoadDB.addonStates  = _G.DynamicLoadDB.addonStates or {}
    _G.DynamicLoadDB.frozenAddons = _G.DynamicLoadDB.frozenAddons or {}
    _G.DynamicLoadDB.lockedAddons = _G.DynamicLoadDB.lockedAddons or {}
    _G.DynamicLoadDB.addonStates[conflictAddon]  = "FROZEN"
    _G.DynamicLoadDB.frozenAddons[conflictAddon] = true
    _G.DynamicLoadDB.lockedAddons[conflictAddon] = nil
    if _G.DynamicLoadDB.profiles then
        for _, prof in pairs(_G.DynamicLoadDB.profiles) do
            if prof and prof.addons then
                prof.addons[conflictAddon] = false
            end
        end
    end
    if _G.DynamicLoad and type(_G.DynamicLoad.SetAddonFrozen) == "function" then
        pcall(_G.DynamicLoad.SetAddonFrozen, conflictAddon, true)
    end

    if _G.DynamicSuiteDB then
        if _G.DynamicSuiteDB.disabledModules then
            _G.DynamicSuiteDB.disabledModules["DynamicChat"] = nil
            _G.DynamicSuiteDB.disabledModules["chat"] = nil
        end
        if _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.disabledModules then
            _G.DynamicSuiteDB.global.disabledModules["DynamicChat"] = nil
            _G.DynamicSuiteDB.global.disabledModules["chat"] = nil
        end
    end

    PrintMsg(string.format("Disabled |cFFFFFFFF%s|r and locked it as |cFF38BDF8[Never]|r across all zone profiles. Using DynamicChat.", tostring(conflictAddon)))
    if wasLoaded and type(_G.ReloadUI) == "function" and not (InCombatLockdown and InCombatLockdown()) then
        _G.ReloadUI()
        return
    end
    self:ApplyAllEngineSettings()
    self:RefreshConfigUI()
    if _G.DynamicLoadMainFrame and _G.DynamicLoadMainFrame.RefreshLeftRailVisuals then
        pcall(_G.DynamicLoadMainFrame.RefreshLeftRailVisuals)
    end
end

function DynamicChat:KeepConflictAddon(conflictAddon)
    local pName = UnitName and UnitName("player") or nil
    _G.DynamicSuiteDB = _G.DynamicSuiteDB or {}
    _G.DynamicSuiteDB.disabledModules = _G.DynamicSuiteDB.disabledModules or {}
    _G.DynamicSuiteDB.disabledModules["DynamicChat"] = true
    if _G.DynamicSuiteDB.global then
        _G.DynamicSuiteDB.global.disabledModules = _G.DynamicSuiteDB.global.disabledModules or {}
        _G.DynamicSuiteDB.global.disabledModules["DynamicChat"] = true
    end
    if _G.C_AddOns and _G.C_AddOns.DisableAddOn and _G.C_AddOns.GetAddOnInfo and _G.C_AddOns.GetAddOnInfo("DynamicChat") then
        pcall(_G.C_AddOns.DisableAddOn, "DynamicChat", pName)
        pcall(_G.C_AddOns.DisableAddOn, "DynamicChat")
    end
    PrintMsg(string.format("Keeping |cFFFFFFFF%s|r active. DynamicChat has been staged as disabled on next reload.", tostring(conflictAddon or "Other Addon")))
    self:RefreshConfigUI()
    if _G.DynamicLoadMainFrame and _G.DynamicLoadMainFrame.RefreshLeftRailVisuals then
        pcall(_G.DynamicLoadMainFrame.RefreshLeftRailVisuals)
    end
end

function DynamicChat:SetAutoYieldSharedHooks(_)
    local db = EnsureDB()
    db.yieldSharedHooks = false
    if type(db.yieldHooks) == "table" then wipe(db.yieldHooks) else db.yieldHooks = {} end
    if _G.DynamicSuiteDB and type(_G.DynamicSuiteDB.global) == "table" and type(_G.DynamicSuiteDB.global.yieldHooks) == "table" then
        wipe(_G.DynamicSuiteDB.global.yieldHooks)
    end
end

-- ============================================================================
-- 4. ENGINE 1: SIGNATURE /WW TARGET WHISPER (EDITBOX + MACRO FALLBACK)
-- ============================================================================

local isConvertingEditBox = false
local suppressNextLeadingSpace = {}

-- Defensive guard for WoW 12.x Midnight Battle.net Whispers (type = "BN_WHISPER", tellTarget = <secret string>)
-- where ChatFrame1EditBoxHeader:GetStringWidth() returns a <secret number>.
local function IsEditBoxSecretOrBNWhisper(editBox)
    if not editBox then return false end
    if issecretvalue or canaccessvalue then
        if type(editBox.GetAttribute) == "function" then
            local okT, tellTarget = pcall(editBox.GetAttribute, editBox, "tellTarget")
            if okT and IsSecretValue(tellTarget) then
                return true
            end
            local okC, chatType = pcall(editBox.GetAttribute, editBox, "chatType")
            if okC and IsSecretValue(chatType) then
                return true
            end
            local okS, stickyType = pcall(editBox.GetAttribute, editBox, "stickyType")
            if okS and IsSecretValue(stickyType) then
                return true
            end
        end
        local hdr = editBox.header or (editBox.GetName and editBox:GetName() and _G[editBox:GetName() .. "Header"])
        if hdr and type(hdr.GetStringWidth) == "function" then
            local okW, w = pcall(hdr.GetStringWidth, hdr)
            if okW and IsSecretValue(w) then
                return true
            end
        end
        local hdrSuffix = editBox.headerSuffix or (editBox.GetName and editBox:GetName() and _G[editBox:GetName() .. "HeaderSuffix"])
        if hdrSuffix and type(hdrSuffix.GetStringWidth) == "function" then
            local okSW, sw = pcall(hdrSuffix.GetStringWidth, hdrSuffix)
            if okSW and IsSecretValue(sw) then
                return true
            end
        end
    end
    return false
end

local function SafeUnitFlagChat(fn, arg1, arg2)
    if type(fn) ~= "function" then return false end
    local ok, val
    if arg2 ~= nil then
        ok, val = pcall(fn, arg1, arg2)
    else
        ok, val = pcall(fn, arg1)
    end
    if not ok or val == nil or IsSecretValue(val) or (issecretvalue and issecretvalue(val)) then
        return false
    end
    return val and true or false
end

local function GetValidFriendlyPlayerTargetName()
    if not UnitExists or not UnitIsPlayer then
        return nil
    end
    if not (SafeUnitFlagChat(UnitExists, "target") and SafeUnitFlagChat(UnitIsPlayer, "target")) then
        return nil
    end
    local isFriendlyTarget = SafeUnitFlagChat(UnitIsUnit, "target", "player")
        or SafeUnitFlagChat(UnitIsFriend, "player", "target")
        or SafeUnitFlagChat(UnitInParty, "target")
        or SafeUnitFlagChat(UnitInRaid, "target")
    if not isFriendlyTarget then
        return nil
    end
    if type(_G.GetUnitName) == "function" then
        local okU, fullName = pcall(_G.GetUnitName, "target", true)
        if okU and fullName and not IsSecretValue(fullName) and not (issecretvalue and issecretvalue(fullName)) and type(fullName) == "string" and fullName ~= "" then
            return fullName:gsub("%s+", "")
        end
    end
    if type(UnitName) == "function" then
        local ok, name, realm = pcall(UnitName, "target")
        if ok and name and not IsSecretValue(name) and not (issecretvalue and issecretvalue(name)) and type(name) == "string" and name ~= "" then
            local fullTarget = (realm and not IsSecretValue(realm) and not (issecretvalue and issecretvalue(realm)) and type(realm) == "string" and realm ~= "") and (name .. "-" .. realm) or name
            return fullTarget
        end
    end
    return nil
end

local function ExecuteQuickLeaveParty()
    if IsModuleDisabledInSuite("DynamicChat") then return end
    if _G.C_PartyInfo and type(_G.C_PartyInfo.LeaveParty) == "function" then
        pcall(_G.C_PartyInfo.LeaveParty)
    elseif type(_G.LeaveParty) == "function" then
        pcall(_G.LeaveParty)
    end
end

local function MatchWhisperTriggerPrefix(txt, isSpacePress)
    if isSpacePress and txt:match("^%s*/[wW][wW]$") then
        return "", "/ww"
    end
    local rem = txt:match("^%s*/[wW][wW]%s+(.*)$")
    if rem ~= nil then return rem, "/ww" end
    return nil, nil
end

local function StripDeferredSpaceAfterWhisperConvert(editBox)
    if not editBox or not (_G.C_Timer and type(_G.C_Timer.After) == "function") then return end
    _G.C_Timer.After(0, function()
        if not editBox or isConvertingEditBox then return end
        local okC, chatType = pcall(editBox.GetAttribute, editBox, "chatType")
        if not okC or (issecretvalue and issecretvalue(chatType)) or chatType == "BN_WHISPER" then
            return
        end
        local okT, tellTarget = pcall(editBox.GetAttribute, editBox, "tellTarget")
        if not okT or (issecretvalue and issecretvalue(tellTarget)) then
            return
        end
        local ok, curTxt = pcall(editBox.GetText, editBox)
        if not ok or IsSecretValue(curTxt) or (issecretvalue and issecretvalue(curTxt)) or type(curTxt) ~= "string" then
            return
        end
        if curTxt == " " then
            isConvertingEditBox = true
            pcall(editBox.SetText, editBox, "")
            isConvertingEditBox = false
        elseif curTxt:sub(1, 1) == " " and suppressNextLeadingSpace[editBox] then
            suppressNextLeadingSpace[editBox] = nil
            isConvertingEditBox = true
            pcall(editBox.SetText, editBox, curTxt:sub(2))
            isConvertingEditBox = false
        end
        suppressNextLeadingSpace[editBox] = nil
    end)
end

local function SwitchEditBoxToTargetWhisper(editBox, fullTarget, initialText)
    if not editBox or not fullTarget then return end
    local okC, chatType = pcall(editBox.GetAttribute, editBox, "chatType")
    if not okC or (issecretvalue and issecretvalue(chatType)) or chatType == "BN_WHISPER" then
        return
    end
    local okT, tellTarget = pcall(editBox.GetAttribute, editBox, "tellTarget")
    if not okT or (issecretvalue and issecretvalue(tellTarget)) then
        return
    end
    isConvertingEditBox = true
    if type(_G.ChatEdit_ActivateChat) == "function" and not DynamicChat.SafeFrameIsShown(editBox, false) then
        pcall(_G.ChatEdit_ActivateChat, editBox)
    end
    pcall(editBox.SetAttribute, editBox, "chatType", "WHISPER")
    pcall(editBox.SetAttribute, editBox, "tellTarget", fullTarget)
    if type(_G.ChatEdit_UpdateHeader) == "function" then
        pcall(_G.ChatEdit_UpdateHeader, editBox)
    end
    local txt = initialText or ""
    pcall(editBox.SetText, editBox, txt)
    if type(editBox.SetCursorPosition) == "function" then
        pcall(editBox.SetCursorPosition, editBox, #txt)
    end
    isConvertingEditBox = false
end

local function TryConvertTargetWhisperEditBox(editBox, isSpacePress)
    if isConvertingEditBox or not editBox then return end
    if IsModuleDisabledInSuite("DynamicChat") then return end

    -- Only bail out early if chatType is BN_WHISPER or tellTarget/text is a secret value.
    -- Never block /ww on InCombatLockdown()!
    local okC, chatType = pcall(editBox.GetAttribute, editBox, "chatType")
    if not okC or (issecretvalue and issecretvalue(chatType)) or chatType == "BN_WHISPER" then
        return
    end
    local okT, tellTarget = pcall(editBox.GetAttribute, editBox, "tellTarget")
    if not okT or (issecretvalue and issecretvalue(tellTarget)) then
        return
    end

    local ok, txt = pcall(editBox.GetText, editBox)
    if not ok or IsSecretValue(txt) or (issecretvalue and issecretvalue(txt)) or type(txt) ~= "string" then return end

    if not isSpacePress and suppressNextLeadingSpace[editBox] then
        suppressNextLeadingSpace[editBox] = nil
        if txt == " " then
            isConvertingEditBox = true
            pcall(editBox.SetText, editBox, "")
            isConvertingEditBox = false
            return
        elseif txt:sub(1, 1) == " " then
            isConvertingEditBox = true
            pcall(editBox.SetText, editBox, txt:sub(2))
            isConvertingEditBox = false
            return
        end
    end

    -- Fast O(1) prefix exit so normal typing in combat never evaluates slash regexes
    if txt == "" or (txt:byte(1) ~= 47 and not txt:find("^%s*/")) then
        return
    end

    local db = EnsureDB()

    -- Instant /ww Space-Trigger: Quick Whisper Target (works in and out of combat across all chat/whisper tabs)
    if not db.enableTargetWhisper then return end
    local mode = db.whisperTriggerMode or "WW"
    local okMatch, remainder, matchedCmd = pcall(MatchWhisperTriggerPrefix, txt, isSpacePress == true, mode)
    if not okMatch or remainder == nil or IsSecretValue(remainder) then return end

    local fullTarget = GetValidFriendlyPlayerTargetName()
    if fullTarget then
        SwitchEditBoxToTargetWhisper(editBox, fullTarget, remainder or "")
        if isSpacePress and (remainder == nil or remainder == "") then
            suppressNextLeadingSpace[editBox] = true
            StripDeferredSpaceAfterWhisperConvert(editBox)
        end
    else
        isConvertingEditBox = true
        if db.targetWhisperClearOnInvalid ~= false then
            pcall(editBox.SetText, editBox, remainder or "")
            if isSpacePress and (remainder == nil or remainder == "") then
                suppressNextLeadingSpace[editBox] = true
                StripDeferredSpaceAfterWhisperConvert(editBox)
            end
        end
        isConvertingEditBox = false
        PrintMsg("Target a friendly player first to use " .. tostring(matchedCmd or "/ww") .. ".")
    end
end

-- Clear retired legacy shortcut globals so DynamicChat never collides with other addons
_G.SLASH_DYNAMICCHATTT1 = nil
_G.SLASH_DYNAMICCHATTT2 = nil
_G.SLASH_DYNAMICCHATCC1 = nil
if _G.SlashCmdList then
    _G.SlashCmdList["DYNAMICCHATTT"] = nil
    _G.SlashCmdList["DYNAMICCHATCC"] = nil
end

-- Signature Macro & Full-Line Slash Fallback (/ww <msg>)
local function HandleTargetWhisperSlashCommand(msg)
    if IsModuleDisabledInSuite("DynamicChat") then return end
    local db = EnsureDB()
    if not db.enableTargetWhisper then
        PrintMsg("Target Whisper (/ww) is currently disabled in DynamicChat (/dchat).")
        return
    end
    local fullTarget = GetValidFriendlyPlayerTargetName()
    if not fullTarget then
        PrintMsg("Target a friendly player first to use /ww.")
        return
    end

    local cleanMsg = ""
    if msg and not IsSecretValue(msg) and not (issecretvalue and issecretvalue(msg)) and type(msg) == "string" then
        cleanMsg = msg:match("^%s*(.-)%s*$") or ""
    end

    local editBox = (_G.ChatEdit_ChooseBoxForSend and _G.ChatEdit_ChooseBoxForSend())
        or (_G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.editBox)
        or _G.ChatFrame1EditBox

    if cleanMsg ~= "" then
        local inChatLockdown = (_G.C_ChatInfo and type(_G.C_ChatInfo.InChatMessagingLockdown) == "function" and _G.C_ChatInfo.InChatMessagingLockdown())
            or (type(_G.IsEncounterInProgress) == "function" and _G.IsEncounterInProgress())
        if inChatLockdown then
            if editBox then
                SwitchEditBoxToTargetWhisper(editBox, fullTarget, cleanMsg)
            end
            return
        end
        if _G.C_ChatInfo and type(_G.C_ChatInfo.SendChatMessage) == "function" then
            pcall(_G.C_ChatInfo.SendChatMessage, cleanMsg, "WHISPER", nil, fullTarget)
        elseif type(_G.SendChatMessage) == "function" then
            pcall(_G.SendChatMessage, cleanMsg, "WHISPER", nil, fullTarget)
        end
    else
        if editBox then
            SwitchEditBoxToTargetWhisper(editBox, fullTarget, "")
        elseif type(_G.ChatFrame_SendTell) == "function" then
            pcall(_G.ChatFrame_SendTell, fullTarget, _G.DEFAULT_CHAT_FRAME)
        end
    end
end

function DynamicChat:ReassertTargetWhisperSlashCommands()
    _G.SLASH_DYNAMICCHATWW1 = nil
    _G.SLASH_DYNAMICCHATWW2 = nil
    _G.SLASH_DYNAMICCHAT_WW1 = nil
    if type(_G.hash_SlashCmdList) == "table" then
        _G.hash_SlashCmdList["/WW"] = nil
    end
    if _G.SlashCmdList then
        _G.SlashCmdList["DYNAMICCHATWW"] = nil
        _G.SlashCmdList["DYNAMICCHAT_WW"] = nil
    end
    if IsModuleDisabledInSuite("DynamicChat") then
        return
    end
    local db = EnsureDB()
    if db.enableTargetWhisper ~= false then
        _G.SLASH_DYNAMICCHATWW1 = "/ww"
        if _G.SlashCmdList then
            _G.SlashCmdList["DYNAMICCHATWW"] = HandleTargetWhisperSlashCommand
        end
    end
    self:RegisterQuickSlashCommands()
end

-- ============================================================================
-- 5. ENGINE 2: ARROW HISTORY, STICKY CHANNELS & QUICK SLASH SHORTCUTS
-- ============================================================================

function DynamicChat:ApplyEditBoxSettings()
    if IsModuleDisabledInSuite("DynamicChat") or self:IsExternalChatEngineLoaded() then return end
    local db = EnsureDB()
    local useAltMode = not (db.arrowHistoryNoAlt == true)

    for i = 1, 10 do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb and eb.SetAltArrowKeyMode then
            if not (issecretvalue and (issecretvalue(eb:GetAttribute("tellTarget")) or (eb.header and issecretvalue(eb.header:GetStringWidth())))) and not IsEditBoxSecretOrBNWhisper(eb) then
                pcall(eb.SetAltArrowKeyMode, eb, useAltMode)
            end
        end
    end
end

function DynamicChat:ApplyStickyChannelSettings()
    -- Retail 12.1.5 Zero-Taint Guard:
    -- Never write to _G.ChatTypeInfo[ch].sticky from addon code. Blizzard's ChatFrameMixin:MessageEventHandler
    -- reads ChatTypeInfo[type] when formatting incoming secret strings, so mutating ChatTypeInfo taints
    -- MessageEventHandler execution.
end

function DynamicChat:RegisterQuickSlashCommands()
    if IsModuleDisabledInSuite("DynamicChat") then
        _G.SLASH_DYNAMICCHATLG1 = nil
        if _G.SlashCmdList then
            _G.SlashCmdList["DYNAMICCHATLG"] = nil
        end
        return
    end
    if not _G.SLASH_RELOAD1 and not (_G.SlashCmdList and _G.SlashCmdList["RELOAD"]) and not _G.SLASH_DYNAMICCHATRL1 then
        _G.SLASH_DYNAMICCHATRL1 = "/rl"
        _G.SlashCmdList["DYNAMICCHATRL"] = function()
            if not IsModuleDisabledInSuite("DynamicChat") and EnsureDB().enableQuickSlash ~= false and type(_G.ReloadUI) == "function" then
                _G.ReloadUI()
            end
        end
    end

    if not _G.SLASH_DYNAMICCHATLG1 then
        _G.SLASH_DYNAMICCHATLG1 = "/lg"
        _G.SlashCmdList["DYNAMICCHATLG"] = function()
            if not IsModuleDisabledInSuite("DynamicChat") and EnsureDB().enableQuickSlash ~= false then
                ExecuteQuickLeaveParty()
            end
        end
    end
end

-- ============================================================================
-- 6. ENGINE 3: SLEEK OBSIDIAN CHAT SKIN, CHANNEL TAGS, CLASS COLORS & URLS
-- ============================================================================

-- Private per-frame skin storage (NEVER write properties onto Blizzard's ChatFrame tables!)
local chatSkinStore = {}
local hookedChatTabs = {}
local hookedScrollBars = {}
local hookedScrollToBottomBtns = {}
local hookedScrollArrows = {}
local hookedSuppressedRegions = {}
local chatFrame1PosHooked = false
local editBox1PosHooked = false
local chatEditBoxSkin = nil
local tabNavFrame = nil
local editBoxFocusCallbacksHooked = false

local CHAT_BORDER_SUFFIXES = {
    "Background",
    "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture",
    "LeftTexture", "RightTexture", "BottomTexture", "TopTexture",
    "RightResizeTexture",
}

local CHAT_TAB_TEXTURE_SUFFIXES = {
    "Left", "Middle", "Right",
    "SelectedLeft", "SelectedMiddle", "SelectedRight",
    "HighlightLeft", "HighlightMiddle", "HighlightRight",
    "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "leftTexture", "middleTexture", "rightTexture",
    "leftSelectedTexture", "middleSelectedTexture", "rightSelectedTexture",
    "leftHighlightTexture", "middleHighlightTexture", "rightHighlightTexture",
    "Glow", "glow", "Flash", "flash",
}

local EDITBOX_TEXTURE_SUFFIXES = {
    "Left", "Mid", "Right",
    "FocusLeft", "FocusMid", "FocusRight",
    "HeaderSuffix",
}

local function SetRegionAlphaSafe(region, alpha)
    if region and type(region.SetAlpha) == "function" then
        pcall(region.SetAlpha, region, alpha)
    end
end

local function StripTextureSafe(region, stripTexture)
    if not region then return end
    if stripTexture then
        if type(region.SetVertexColor) == "function" then
            pcall(region.SetVertexColor, region, 0, 0, 0, 0)
        end
        if type(region.SetAlpha) == "function" then
            pcall(region.SetAlpha, region, 0)
        end
    else
        if type(region.SetVertexColor) == "function" then
            pcall(region.SetVertexColor, region, 1, 1, 1, 1)
        end
        if type(region.SetAlpha) == "function" then
            pcall(region.SetAlpha, region, 1)
        end
    end
end

local function HideAllCurrentSkinFrames()
    for _, entry in pairs(chatSkinStore) do
        if entry.panel then entry.panel:Hide() end
        if entry.tabCell then entry.tabCell:Hide() end
        if entry.tabLine then entry.tabLine:Hide() end
        if entry.leftRail then entry.leftRail:Hide() end
        if entry.scrollThumbFrame then entry.scrollThumbFrame:Hide() end
    end
    if chatEditBoxSkin then
        chatEditBoxSkin:Hide()
    end
    if tabNavFrame then
        tabNavFrame:Hide()
    end
end

-- Unified Sleek DynamicSuite Custom Scrollbar Factory (Shared by Main Chat Frames & Chat History Modal)
local function CreateDynamicChatScrollbar(parent, opts)
    opts = opts or {}
    local barWidth = opts.width or 6
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetWidth(barWidth)
    if opts.strata then
        bar:SetFrameStrata(opts.strata)
    elseif parent and type(parent.GetFrameStrata) == "function" then
        bar:SetFrameStrata(parent:GetFrameStrata() or "LOW")
    end
    bar:SetFrameLevel(opts.frameLevel or ((parent:GetFrameLevel() or 2) + 12))
    bar:EnableMouse(true)
    if bar.SetHitRectInsets then
        bar:SetHitRectInsets(-4, -3, 0, 0)
    end
    if bar.EnableMouseWheel then
        bar:EnableMouseWheel(true)
    end

    local trackBg = bar:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0.04, 0.05, 0.07, 0.65)
    DisableTexPixelSnap(trackBg)
    bar.trackBg = trackBg

    local trackBorder = bar:CreateTexture(nil, "BORDER")
    trackBorder:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    trackBorder:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    trackBorder:SetWidth(1)
    trackBorder:SetColorTexture(1, 1, 1, 0.08)
    DisableTexPixelSnap(trackBorder)
    bar.trackBorder = trackBorder

    local thumb = CreateFrame("Button", nil, bar)
    thumb:SetPoint("TOP", bar, "TOP", 0, 0)
    thumb:SetSize(barWidth, 28)
    thumb:SetFrameStrata(bar:GetFrameStrata())
    thumb:SetFrameLevel(bar:GetFrameLevel() + 2)
    thumb:EnableMouse(true)
    if thumb.SetHitRectInsets then
        thumb:SetHitRectInsets(-4, -3, -2, -2)
    end
    thumb:RegisterForClicks("LeftButtonUp", "LeftButtonDown")

    local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
    thumbTex:SetAllPoints()
    thumbTex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
    DisableTexPixelSnap(thumbTex)
    thumb.tex = thumbTex
    bar.thumb = thumb

    bar._maxValue = 0
    bar._value = 0
    bar._visibleRatio = 1
    bar._isDragging = false
    bar._isHovered = false
    bar._autoHide = (opts.autoHide ~= false)
    bar._hoverCheckFn = opts.isHoveredFn
    bar._scrollRevealUntil = 0
    bar._currentAlpha = bar._autoHide and 0 or 1
    bar._pollElapsed = 0
    bar._onValueChanged = opts.onValueChanged
    bar._onMouseWheel = opts.onMouseWheel
    bar:SetAlpha(bar._currentAlpha)

    if bar.SetScript then
        bar:SetScript("OnMouseWheel", function(self, delta)
            if type(self._onMouseWheel) == "function" then
                self._onMouseWheel(delta)
            end
        end)
    end

    function bar:NotifyScrollActivity()
        if not self._autoHide then return end
        self._scrollRevealUntil = GetTime() + 1.5
    end

    function bar:UpdateVisuals()
        if self._isHovered or self._isDragging then
            local ar, ag, ab = GetSuiteAccent()
            self.thumb.tex:SetColorTexture(ar, ag, ab, 1.0)
        else
            self.thumb.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
        end
    end

    function bar:UpdateState(currentVal, maxVal, visibleRatio)
        maxVal = math.max(0, tonumber(maxVal) or 0)
        currentVal = math.max(0, math.min(maxVal, tonumber(currentVal) or 0))
        self._maxValue = maxVal
        self._value = currentVal
        self._visibleRatio = math.max(0.06, math.min(1, tonumber(visibleRatio) or 1))

        if maxVal <= 0.5 and self._autoHide then
            self._currentAlpha = 0
            self:SetAlpha(0)
            self:Hide()
            return
        end
        self:Show()
        if not self._autoHide then
            self._currentAlpha = 1
            self:SetAlpha(1)
        end

        local trackH = self:GetHeight() or 0
        if trackH <= 4 then return end

        local thumbH = math.max(20, math.min(trackH, math.floor(trackH * self._visibleRatio + 0.5)))
        if maxVal <= 0.5 then
            thumbH = trackH
        end
        self.thumb:SetHeight(thumbH)

        local travel = math.max(0, trackH - thumbH)
        local frac = (maxVal > 0) and (currentVal / maxVal) or 0
        local topOffset = math.floor(travel * frac + 0.5)
        self.thumb:ClearAllPoints()
        self.thumb:SetPoint("TOP", self, "TOP", 0, -topOffset)
        self.thumb:SetPoint("LEFT", self, "LEFT", 0, 0)
        self.thumb:SetPoint("RIGHT", self, "RIGHT", 0, 0)
        self:UpdateVisuals()
    end

    thumb:SetScript("OnEnter", function()
        bar._isHovered = true
        bar:UpdateVisuals()
    end)
    thumb:SetScript("OnLeave", function()
        bar._isHovered = false
        bar:UpdateVisuals()
    end)

    thumb:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or bar._maxValue <= 0 then return end
        bar._isDragging = true
        bar:NotifyScrollActivity()
        local _, cursorY = GetCursorPosition()
        local scale = bar:GetEffectiveScale() or 1
        bar._dragStartY = cursorY / scale
        bar._dragStartVal = bar._value
        bar:UpdateVisuals()
    end)

    thumb:SetScript("OnMouseUp", function()
        if bar._isDragging then
            bar._isDragging = false
            bar:NotifyScrollActivity()
            bar:UpdateVisuals()
        end
    end)

    thumb:SetScript("OnHide", function()
        bar._isDragging = false
        bar._isHovered = false
        bar:UpdateVisuals()
    end)

    if thumb.EnableMouseWheel then
        thumb:EnableMouseWheel(true)
        thumb:SetScript("OnMouseWheel", function(_, delta)
            if type(bar._onMouseWheel) == "function" then
                bar._onMouseWheel(delta)
            end
        end)
    end

    bar:SetScript("OnHide", function(self)
        self._isDragging = false
        self._isHovered = false
        self:UpdateVisuals()
    end)

    bar:SetScript("OnUpdate", function(self, elapsed)
        if self._isDragging then
            if not IsMouseButtonDown("LeftButton") then
                self._isDragging = false
                self:NotifyScrollActivity()
                self:UpdateVisuals()
            else
                self:NotifyScrollActivity()
                local trackH = self:GetHeight() or 0
                local thumbH = self.thumb:GetHeight() or 20
                local travel = math.max(1, trackH - thumbH)
                local _, cursorY = GetCursorPosition()
                local scale = self:GetEffectiveScale() or 1
                local curY = cursorY / scale
                local deltaY = self._dragStartY - curY -- dragging down increases topOffset/value
                local newVal = math.max(0, math.min(self._maxValue, self._dragStartVal + (deltaY / travel) * self._maxValue))
                if type(self._onValueChanged) == "function" then
                    self._onValueChanged(newVal)
                end
            end
        end

        if self._autoHide and self._hoverCheckFn then
            self._pollElapsed = (self._pollElapsed or 0) + (elapsed or 0.016)
            local isAnimating = (self._currentAlpha > 0.005 and self._currentAlpha < 0.995)
            local scrollActive = (GetTime() < (self._scrollRevealUntil or 0))
            if self._isDragging or isAnimating or scrollActive or self._pollElapsed >= 0.05 then
                self._pollElapsed = 0
                local wantVisible = (self._maxValue > 0.5) and (self._isDragging or scrollActive or self._hoverCheckFn())
                local targetAlpha = wantVisible and 1 or 0
                if self._currentAlpha ~= targetAlpha then
                    local rate = (targetAlpha > self._currentAlpha) and 8.0 or 4.0
                    local step = (elapsed or 0.016) * rate
                    if step < 0.04 then step = 0.04 end
                    if targetAlpha > self._currentAlpha then
                        self._currentAlpha = math.min(1, self._currentAlpha + step)
                    else
                        self._currentAlpha = math.max(0, self._currentAlpha - step)
                    end
                    self:SetAlpha(self._currentAlpha)
                end
            end
        end
    end)

    bar:SetScript("OnEnter", function()
        bar._isHovered = true
        bar:UpdateVisuals()
    end)
    bar:SetScript("OnLeave", function()
        bar._isHovered = false
        bar:UpdateVisuals()
    end)

    bar:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or self._maxValue <= 0 then return end
        self:NotifyScrollActivity()
        local top = self:GetTop()
        local bot = self:GetBottom()
        if not top or not bot or top <= bot then return end
        local _, cursorY = GetCursorPosition()
        local scale = self:GetEffectiveScale() or 1
        local relY = (top - (cursorY / scale)) / (top - bot)
        relY = math.max(0, math.min(1, relY))
        local targetVal = relY * self._maxValue
        if type(self._onValueChanged) == "function" then
            self._onValueChanged(targetVal)
        end
    end)

    bar:SetScript("OnSizeChanged", function(self)
        if self:IsShown() then
            self:UpdateState(self._value, self._maxValue, self._visibleRatio)
        end
    end)

    return bar
end

-- Scrollable Full Chat History Copy Modal (DynamicChatHistoryModal, 620x440px)
local chatHistoryModal = nil

local HISTORY_URL_PATTERNS = {
    "(https?://[%w%._%-/%?&#=~%%:%+@!%$,;*%(%)]+)",
    "(www%.[%w%._%-/%?&#=~%%:%+@!%$,;*%(%)]+)",
    "(discord%.gg/[%w%._%-/%?&#=~%%]+)",
    "(wago%.io/[%w%._%-/%?&#=~%%]+)",
    "(curseforge%.com/[%w%._%-/%?&#=~%%]+)",
    "(raider%.io/[%w%._%-/%?&#=~%%:%+@!%$,;*%(%)]+)",
    "(wowhead%.com/[%w%._%-/%?&#=~%%:%+@!%$,;*%(%)]+)",
    "(mythictrap%.com/[%w%._%-/%?&#=~%%:%+@!%$,;*%(%)]+)",
    "(archon%.gg/[%w%._%-/%?&#=~%%:%+@!%$,;*%(%)]+)",
    "(warcraftlogs%.com/[%w%._%-/%?&#=~%%:%+@!%$,;*%(%)]+)",
    "(youtu%.be/[%w%._%-/%?&#=~%%:%+@!%$,;*%(%)]+)",
    "(youtube%.com/[%w%._%-/%?&#=~%%:%+@!%$,;*%(%)]+)",
}

local function DecodeDynamicChatLinkPayload(payload)
    if type(payload) ~= "string" then return payload end
    return (payload:gsub("%%%%3[aA]", ":"):gsub("%%3[aA]", ":"):gsub("%%7[cC]", "|"))
end

local function ExtractURLsFromText(text, outList, seenMap)
    if not text or IsSecretValue(text) or type(text) ~= "string" or text == "" then return end
    local okProbe = pcall(string.find, text, "", 1, true)
    if not okProbe then return end
    pcall(function()
        for _, pat in ipairs(HISTORY_URL_PATTERNS) do
            for rawUrl in text:gmatch(pat) do
                local cleanUrl = rawUrl:gsub("[%,%.%;%:%)%]%!%?]+$", "")
                cleanUrl = DecodeDynamicChatLinkPayload(cleanUrl)
                if cleanUrl ~= "" and not seenMap[cleanUrl] then
                    seenMap[cleanUrl] = true
                    outList[#outList + 1] = cleanUrl
                end
            end
        end
    end)
end

local function RecordCapturedSessionURL(cleanUrl, sourceEvent)
    if not cleanUrl or IsSecretValue(cleanUrl) or type(cleanUrl) ~= "string" or cleanUrl == "" then return end
    cleanUrl = DecodeDynamicChatLinkPayload(cleanUrl)
    if cleanUrl == "" then return end
    local buf = DynamicChat._recentCapturedURLs
    if type(buf) ~= "table" then
        buf = {}
        DynamicChat._recentCapturedURLs = buf
    end
    for i = #buf, 1, -1 do
        if buf[i] and buf[i].url == cleanUrl then
            table.remove(buf, i)
        end
    end
    buf[#buf + 1] = {
        url = cleanUrl,
        event = sourceEvent or "CHAT",
        time = (type(_G.GetTime) == "function" and _G.GetTime()) or 0,
    }
    while #buf > 15 do
        table.remove(buf, 1)
    end
    DynamicChat._latestCapturedURL = cleanUrl
    DynamicChat._hasUnreadCapturedURL = true
    if DynamicChat.RefreshLeftRailTelemetry then
        DynamicChat:RefreshLeftRailTelemetry()
    end
end

local function SanitizeChatHistoryString(text)
    if not text or IsSecretValue(text) or type(text) ~= "string" or text == "" then
        return nil
    end
    local okClean, cleaned = pcall(function()
        local s = text
        s = s:gsub("||", "\127PIPE\127")
        s = s:gsub("|T.-|t", "")
        s = s:gsub("|A.-|a", "")
        s = s:gsub("|K.-|k", "[BNet]")
        s = s:gsub("|Haddon:DynamicChat:([^|]+)|h%[(.-)%]|h", function(encoded, label)
            local dec = DecodeDynamicChatLinkPayload(encoded)
            return (dec and dec ~= "") and dec or label
        end)
        s = s:gsub("|Hurl:([^|]+)|h%[(.-)%]|h", "%1")
        s = s:gsub("|Hdcurl:([^|]+)|h%[(.-)%]|h", "%1")
        s = s:gsub("|H.-|h(.-)|h", "%1")
        s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
        s = s:gsub("|cn[^:]+:", "")
        s = s:gsub("|r", "")
        s = s:gsub("|n", "\n")
        s = s:gsub("\127PIPE\127", "|")
        return s
    end)
    if not okClean or IsSecretValue(cleaned) or type(cleaned) ~= "string" then
        return nil
    end
    cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")
    if cleaned == "" then return nil end
    return cleaned
end

local function StripSecretOrExtractLine(cf, idx)
    if not cf or type(cf.GetMessageInfo) ~= "function" then return nil end
    local ok, text = pcall(cf.GetMessageInfo, cf, idx)
    if not ok or IsSecretValue(text) or type(text) ~= "string" or text == "" then
        return nil
    end
    return SanitizeChatHistoryString(text)
end

local function ResolveActiveChatFrame(targetChatFrame)
    if targetChatFrame and type(targetChatFrame.GetNumMessages) == "function" then
        return targetChatFrame
    end
    if type(_G.FCF_GetCurrentChatFrame) == "function" then
        local ok, cur = pcall(_G.FCF_GetCurrentChatFrame)
        if ok and cur and type(cur.GetNumMessages) == "function" then
            return cur
        end
    end
    if _G.SELECTED_CHAT_FRAME and type(_G.SELECTED_CHAT_FRAME.GetNumMessages) == "function" then
        return _G.SELECTED_CHAT_FRAME
    end
    if _G.SELECTED_DOCK_FRAME and type(_G.SELECTED_DOCK_FRAME.GetNumMessages) == "function" then
        return _G.SELECTED_DOCK_FRAME
    end
    return _G.ChatFrame1
end

local function GetChatFrameTabTitle(cf)
    if not cf then return "General" end
    local cfName = cf.GetName and cf:GetName()
    local tab = cfName and _G[cfName .. "Tab"]
    if tab then
        local fs = tab.Text or (tab.GetFontString and tab:GetFontString())
        if fs and type(fs.GetText) == "function" then
            local ok, t = pcall(fs.GetText, fs)
            if ok and t and not IsSecretValue(t) and type(t) == "string" and t ~= "" then
                local clean = t:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                if clean ~= "" then return clean end
            end
        end
    end
    if cf.name and not IsSecretValue(cf.name) and type(cf.name) == "string" and cf.name ~= "" then
        return cf.name
    end
    return cfName or "General"
end

local function ResolveChatTabLabel(cf, tab, tabName, entry)
    if not cf or not tab then return nil, nil end
    local fs = tab.Text or (tabName and _G[tabName .. "Text"]) or (tab.GetFontString and tab:GetFontString())
    if not fs then return nil, nil end

    local chatType = (not IsSecretValue(cf.chatType) and type(cf.chatType) == "string") and cf.chatType or nil
    local isBNWhisperTab = (chatType == "BN_WHISPER" or chatType == "BN_CONVERSATION")
    local isWhisperTab   = isBNWhisperTab or (chatType == "WHISPER") or (cf.isTemporary == true)

    -- Midnight 12.1.5 Zero-Taint Guard: Battle.net / Whisper temporary tab names may be secret strings
    -- already rendered on fs by Blizzard. Never overwrite a secret tab label with "ChatFrame11".
    if type(fs.GetText) == "function" then
        local okExisting, existingTxt = pcall(fs.GetText, fs)
        if okExisting and existingTxt ~= nil and IsSecretValue(existingTxt) then
            if type(fs.Show) == "function" then pcall(fs.Show, fs) end
            if type(fs.SetAlpha) == "function" then pcall(fs.SetAlpha, fs, 1.0) end
            return fs, nil
        end
    end
    if cf.isTemporary == true and (IsSecretValue(cf.name) or IsSecretValue(cf.chatTarget)) then
        if type(fs.Show) == "function" then pcall(fs.Show, fs) end
        if type(fs.SetAlpha) == "function" then pcall(fs.SetAlpha, fs, 1.0) end
        return fs, nil
    end

    local rawLabel = nil
    local cfID = cf.GetID and cf:GetID()
    if type(cfID) == "number" and cfID > 0 and not cf.isTemporary then
        local infoName = nil
        if type(_G.GetChatWindowInfo) == "function" then
            local ok, n = pcall(_G.GetChatWindowInfo, cfID)
            if ok and not IsSecretValue(n) and type(n) == "string" and n ~= "" then
                infoName = n
            end
        end
        if not infoName and type(_G.FCF_GetChatWindowInfo) == "function" then
            local ok, n = pcall(_G.FCF_GetChatWindowInfo, cfID)
            if ok and not IsSecretValue(n) and type(n) == "string" and n ~= "" then
                infoName = n
            end
        end
        rawLabel = infoName
    end

    if (not rawLabel or rawLabel == "") and type(fs.GetText) == "function" then
        local okTxt, curTxt = pcall(fs.GetText, fs)
        if okTxt and not IsSecretValue(curTxt) and type(curTxt) == "string" and curTxt ~= "" and not curTxt:match("^ChatFrame%d+$") then
            rawLabel = curTxt
        end
    end

    if (not rawLabel or rawLabel == "") and not IsSecretValue(cf.name) and type(cf.name) == "string" and cf.name ~= "" and not cf.name:match("^ChatFrame%d+$") then
        rawLabel = cf.name
    end

    if (not rawLabel or rawLabel == "") and isWhisperTab and not IsSecretValue(cf.chatTarget) and type(cf.chatTarget) == "string" and cf.chatTarget ~= "" then
        rawLabel = cf.chatTarget
    end

    if not rawLabel or rawLabel == "" then
        if cf.isTemporary == true then
            -- Temporary whisper/BNet tab not yet populated by Blizzard; leave fs untouched so FCF_SetWindowName can set it.
            if type(fs.Show) == "function" then pcall(fs.Show, fs) end
            if type(fs.SetAlpha) == "function" then pcall(fs.SetAlpha, fs, 1.0) end
            return fs, nil
        elseif cfID == 1 then rawLabel = _G.GENERAL or "General"
        elseif cfID == 2 then rawLabel = _G.COMBAT_LOG or "Combat Log"
        else rawLabel = GetChatFrameTabTitle(cf) end
    end

    local cleanFull = tostring(rawLabel):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    if entry and (not entry.fullTabLabel or cleanFull:find("-", 1, true)) then
        entry.fullTabLabel = cleanFull
    end

    local displayLabel = cleanFull
    if isWhisperTab and not isBNWhisperTab and cleanFull:find("-", 1, true) then
        local shortName = cleanFull:match("^([^%-]+)")
        if shortName and shortName ~= "" then
            displayLabel = shortName
        end
    end

    if type(fs.SetText) == "function" then
        local okCur, curTxt = pcall(fs.GetText, fs)
        if not okCur or (not IsSecretValue(curTxt) and curTxt ~= displayLabel) then
            pcall(fs.SetText, fs, displayLabel)
        end
    end
    if type(fs.Show) == "function" then pcall(fs.Show, fs) end
    if type(fs.SetAlpha) == "function" then pcall(fs.SetAlpha, fs, 1.0) end
    return fs, displayLabel
end

local function EnsureChatHistoryModal()
    if chatHistoryModal then return chatHistoryModal end

    local modal = CreateFrame("Frame", "DynamicChatHistoryModal", UIParent, "BackdropTemplate")
    modal:SetSize(620, 440)
    modal:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    modal:SetFrameStrata("DIALOG")
    modal:SetToplevel(true)
    modal:SetClampedToScreen(true)
    modal:SetMovable(true)
    modal:EnableMouse(true)
    modal:RegisterForDrag("LeftButton")
    modal:SetScript("OnDragStart", modal.StartMoving)
    modal:SetScript("OnDragStop", modal.StopMovingOrSizing)
    modal:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    local ar, ag, ab = GetSuiteAccent()
    modal:SetBackdropColor(0.035, 0.039, 0.051, 0.98) -- #090A0D
    modal:SetBackdropBorderColor(ar, ag, ab, 0.95)
    SafeRegisterUISpecialFrame("DynamicChatHistoryModal")

    local topBar = modal:CreateTexture(nil, "OVERLAY")
    topBar:SetHeight(2)
    topBar:SetPoint("TOPLEFT", modal, "TOPLEFT", 1, -1)
    topBar:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -1, -1)
    topBar:SetColorTexture(ar, ag, ab, 1.0)
    modal.topBar = topBar

    local closeBtn = CreateFrame("Button", nil, modal, "BackdropTemplate")
    closeBtn:SetSize(22, 20)
    closeBtn:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -8, -6)
    closeBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    closeBtn:SetBackdropColor(0.078, 0.090, 0.122, 0.96)
    closeBtn:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95)
    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(closeTxt, 10, "")
    closeTxt:SetPoint("CENTER", 0, 0)
    closeTxt:SetTextColor(0.92, 0.95, 0.99, 1.0)
    closeTxt:SetText("X")
    closeBtn:SetScript("OnClick", function() modal:Hide() end)
    modal.closeBtn = closeBtn

    local selBtn = CreateFrame("Button", nil, modal, "BackdropTemplate")
    selBtn:SetSize(72, 20)
    selBtn:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -34, -6)
    selBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    selBtn:SetBackdropColor(0.078, 0.090, 0.122, 0.96)
    selBtn:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95)
    local selTxt = selBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(selTxt, 9.5, "")
    selTxt:SetPoint("CENTER", 0, 0)
    selTxt:SetTextColor(0.92, 0.95, 0.99, 1.0)
    selTxt:SetText("Select All")
    selBtn:SetScript("OnClick", function()
        if modal.editBox then
            modal.editBox:SetFocus()
            modal.editBox:HighlightText()
        end
    end)
    modal.selBtn = selBtn

    local title = modal:CreateFontString(nil, "OVERLAY")
    SetSafeFont(title, 11, "")
    title:SetPoint("TOPLEFT", modal, "TOPLEFT", 14, -10)
    title:SetPoint("RIGHT", selBtn, "LEFT", -12, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetTextColor(ar, ag, ab, 1.0)
    title:SetText("CHAT HISTORY - General")
    modal.title = title

    -- Recent Links Quick-Copy Strip (shown when 1+ URLs exist in this chat tab)
    local linkBar = CreateFrame("Frame", nil, modal, "BackdropTemplate")
    linkBar:SetPoint("TOPLEFT", modal, "TOPLEFT", 14, -32)
    linkBar:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -14, -32)
    linkBar:SetHeight(26)
    linkBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    linkBar:SetBackdropColor(0.065, 0.075, 0.100, 0.96)
    linkBar:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95)
    linkBar:Hide()
    modal.linkBar = linkBar

    local linkLbl = linkBar:CreateFontString(nil, "OVERLAY")
    SetSafeFont(linkLbl, 9.5, "")
    linkLbl:SetPoint("LEFT", linkBar, "LEFT", 8, 0)
    linkLbl:SetTextColor(0.64, 0.72, 0.82, 1.0)
    linkLbl:SetText("Recent Links:")
    linkBar.label = linkLbl
    linkBar.pills = {}

    local boxWrap = CreateFrame("Frame", nil, modal, "BackdropTemplate")
    boxWrap:SetPoint("TOPLEFT", modal, "TOPLEFT", 14, -32)
    boxWrap:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -14, 28)
    boxWrap:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    boxWrap:SetBackdropColor(0.055, 0.063, 0.082, 0.98) -- #0E1015
    boxWrap:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95) -- #252A36
    modal.boxWrap = boxWrap

    local hint = modal:CreateFontString(nil, "OVERLAY")
    SetSafeFont(hint, 9.5, "")
    hint:SetPoint("BOTTOMLEFT", modal, "BOTTOMLEFT", 14, 8)
    hint:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -14, 8)
    hint:SetJustifyH("RIGHT")
    hint:SetWordWrap(false)
    hint:SetTextColor(0.58, 0.64, 0.72, 1.0)
    hint:SetText("Press Ctrl+C to copy  |  Esc to close")
    modal.hint = hint

    local sf = CreateFrame("ScrollFrame", "DynamicChatHistoryModalScrollFrame", boxWrap)
    sf:SetPoint("TOPLEFT", boxWrap, "TOPLEFT", 8, -8)
    sf:SetPoint("BOTTOMRIGHT", boxWrap, "BOTTOMRIGHT", -18, 8)
    sf:EnableMouseWheel(true)
    modal.scrollFrame = sf

    local histScrollBar = CreateDynamicChatScrollbar(boxWrap, {
        width = 6,
        autoHide = false,
        onValueChanged = function(newVal)
            sf:SetVerticalScroll(newVal)
        end,
        onMouseWheel = function(delta)
            local maxRange = sf:GetVerticalScrollRange() or 0
            local cur = sf:GetVerticalScroll() or 0
            local step = 36
            local nextVal = math.max(0, math.min(maxRange, cur - (delta * step)))
            sf:SetVerticalScroll(nextVal)
        end,
    })
    histScrollBar:SetPoint("TOPRIGHT", boxWrap, "TOPRIGHT", -6, -8)
    histScrollBar:SetPoint("BOTTOMRIGHT", boxWrap, "BOTTOMRIGHT", -6, 8)
    modal.customScrollBar = histScrollBar

    local function SyncHistoryScrollBar()
        local maxRange = sf:GetVerticalScrollRange() or 0
        local curScroll = sf:GetVerticalScroll() or 0
        local viewH = sf:GetHeight() or 360
        local visRatio = viewH / math.max(1, viewH + maxRange)
        histScrollBar:UpdateState(curScroll, maxRange, visRatio)
    end

    sf:SetScript("OnMouseWheel", function(self, delta)
        local maxRange = self:GetVerticalScrollRange() or 0
        local cur = self:GetVerticalScroll() or 0
        local step = 36
        local nextVal = math.max(0, math.min(maxRange, cur - (delta * step)))
        self:SetVerticalScroll(nextVal)
    end)
    sf:SetScript("OnScrollRangeChanged", function() SyncHistoryScrollBar() end)
    sf:SetScript("OnVerticalScroll", function() SyncHistoryScrollBar() end)

    local eb = CreateFrame("EditBox", "DynamicChatHistoryModalEditBox", sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    if _G.ChatFontNormal then
        eb:SetFontObject(_G.ChatFontNormal)
    end
    SetSafeFont(eb, 11, "")
    if eb.SetMaxLetters then eb:SetMaxLetters(0) end
    if eb.SetCountInvisibleLetters then pcall(eb.SetCountInvisibleLetters, eb, false) end
    if eb.SetTextInsets then eb:SetTextInsets(4, 10, 4, 4) end
    eb:SetWidth(556)
    eb:SetHeight(360)
    eb:SetTextColor(0.92, 0.95, 0.99, 1.0)
    eb:SetScript("OnEscapePressed", function() modal:Hide() end)
    eb:SetScript("OnTextChanged", function(self, userInput)
        if type(_G.ScrollingEdit_OnTextChanged) == "function" then
            pcall(_G.ScrollingEdit_OnTextChanged, self, sf)
        end
        if userInput and modal.currentText and self:GetText() ~= modal.currentText then
            self:SetText(modal.currentText)
            self:HighlightText()
        end
        SyncHistoryScrollBar()
    end)
    eb:SetScript("OnCursorChanged", function(self, x, y, w, h)
        if type(_G.ScrollingEdit_OnCursorChanged) == "function" then
            pcall(_G.ScrollingEdit_OnCursorChanged, self, x, y, w, h)
        end
        SyncHistoryScrollBar()
    end)
    sf:SetScrollChild(eb)
    sf:SetScript("OnSizeChanged", function(self, w)
        if w and w > 24 then
            eb:SetWidth(w - 10)
        end
        SyncHistoryScrollBar()
    end)
    modal.editBox = eb

    modal:Hide()
    chatHistoryModal = modal
    return modal
end

local railPopoverFrame = nil
local railPopoverClickCatcher = nil

function DynamicChat:ShowFullChatHistoryModal(targetChatFrame)
    if railPopoverFrame and railPopoverFrame:IsShown() then
        railPopoverFrame:Hide()
    end
    if railPopoverClickCatcher and railPopoverClickCatcher:IsShown() then
        railPopoverClickCatcher:Hide()
    end
    local cf = ResolveActiveChatFrame(targetChatFrame)
    if not cf then return end
    local modal = EnsureChatHistoryModal()
    local ar, ag, ab = GetSuiteAccent()
    modal:SetBackdropBorderColor(ar, ag, ab, 0.95)
    if modal.topBar then modal.topBar:SetColorTexture(ar, ag, ab, 1.0) end
    local activeTabName = GetChatFrameTabTitle(cf)
    if modal.title then
        SetSafeFont(modal.title, 11, "")
        modal.title:SetTextColor(ar, ag, ab, 1.0)
        modal.title:SetText("CHAT HISTORY - " .. tostring(activeTabName))
    end
    if modal.editBox then
        if _G.ChatFontNormal then
            modal.editBox:SetFontObject(_G.ChatFontNormal)
        end
        SetSafeFont(modal.editBox, 11, "")
    end

    local lines = {}
    local recentURLs = {}
    local seenURLs = {}
    local db = EnsureDB()
    local maxLines = math.min(500, math.max(50, tonumber(db.maxChatLines) or 500))
    if cf == _G.ChatFrame1 and db.preserveChatHistory ~= false and db.enableGPUBufferCap ~= false and type(db.savedChatHistory) == "table" and #db.savedChatHistory > 0 then
        local savedHist = db.savedChatHistory
        local savedStart = math.max(1, #savedHist - maxLines + 1)
        for sIdx = savedStart, #savedHist do
            local item = savedHist[sIdx]
            local rawSaved = type(item) == "table" and (item.t or item.text) or nil
            local cleanSaved = SanitizeChatHistoryString(rawSaved)
            if cleanSaved then
                lines[#lines + 1] = cleanSaved
                ExtractURLsFromText(cleanSaved, recentURLs, seenURLs)
            end
        end
        if #lines > 0 then
            lines[#lines + 1] = "--- Saved From Previous Session ---"
        end
    end
    local total = (type(cf.GetNumMessages) == "function" and cf:GetNumMessages()) or 0
    local startIdx = math.max(1, total - maxLines + 1)
    for idx = startIdx, total do
        local line = StripSecretOrExtractLine(cf, idx)
        if line then
            lines[#lines + 1] = line
            ExtractURLsFromText(line, recentURLs, seenURLs)
        end
    end
    if type(DynamicChat._recentCapturedURLs) == "table" then
        for _, item in ipairs(DynamicChat._recentCapturedURLs) do
            local u = item and item.url
            if u and not IsSecretValue(u) and type(u) == "string" and u ~= "" and not seenURLs[u] then
                seenURLs[u] = true
                recentURLs[#recentURLs + 1] = u
            end
        end
    end
    if #recentURLs > 0 then
        DynamicChat._latestCapturedURL = recentURLs[#recentURLs]
    end
    local lineCount = #lines
    if lineCount == 0 then
        lines[1] = "No copyable messages in this chat tab."
        lineCount = 1
    end

    -- Populate Recent Links Quick-Copy Strip (most recent up to 3 links)
    local linkBar = modal.linkBar
    if linkBar then
        for _, p in ipairs(linkBar.pills) do p:Hide() end
        if #recentURLs > 0 then
            linkBar:Show()
            modal.boxWrap:ClearAllPoints()
            modal.boxWrap:SetPoint("TOPLEFT", modal, "TOPLEFT", 14, -62)
            modal.boxWrap:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -14, 28)
            local maxPills = math.min(3, #recentURLs)
            local xOff = 84
            for i = 1, maxPills do
                local url = recentURLs[#recentURLs - i + 1]
                local pill = linkBar.pills[i]
                if not pill then
                    pill = CreateFrame("Button", nil, linkBar, "BackdropTemplate")
                    pill:SetHeight(18)
                    pill:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8x8",
                        edgeFile = "Interface\\Buttons\\WHITE8x8",
                        edgeSize = 1,
                    })
                    pill.txt = pill:CreateFontString(nil, "OVERLAY")
                    SetSafeFont(pill.txt, 9.5, "")
                    pill.txt:SetPoint("LEFT", pill, "LEFT", 6, 0)
                    pill.txt:SetPoint("RIGHT", pill, "RIGHT", -6, 0)
                    pill.txt:SetJustifyH("CENTER")
                    pill.txt:SetWordWrap(false)
                    linkBar.pills[i] = pill
                end
                local shortLabel = url:gsub("^https?://", ""):gsub("^www%.", "")
                if #shortLabel > 24 then
                    shortLabel = shortLabel:sub(1, 22) .. ".."
                end
                local pillW = math.min(168, math.max(84, (#shortLabel * 6) + 18))
                pill:SetWidth(pillW)
                pill:ClearAllPoints()
                pill:SetPoint("LEFT", linkBar, "LEFT", xOff, 0)
                xOff = xOff + pillW + 6
                pill:SetBackdropColor(0.08, 0.10, 0.14, 0.96)
                pill:SetBackdropBorderColor(ar, ag, ab, 0.75)
                pill.txt:SetTextColor(0.95, 0.97, 1.0, 1.0)
                pill.txt:SetText(i == 1 and ("Copy: " .. shortLabel) or shortLabel)
                pill:SetScript("OnEnter", function(selfBtn)
                    selfBtn:SetBackdropBorderColor(ar, ag, ab, 1.0)
                    if _G.GameTooltip then
                        _G.GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
                        _G.GameTooltip:SetText("Click to Copy Link", ar, ag, ab)
                        _G.GameTooltip:AddLine(url, 0.92, 0.95, 0.99, true)
                        _G.GameTooltip:Show()
                    end
                end)
                pill:SetScript("OnLeave", function(selfBtn)
                    selfBtn:SetBackdropBorderColor(ar, ag, ab, 0.75)
                    if _G.GameTooltip then _G.GameTooltip:Hide() end
                end)
                pill:SetScript("OnClick", function()
                    DynamicChat:ShowURLCopyPopup(url)
                end)
                pill:Show()
            end
        else
            linkBar:Hide()
            modal.boxWrap:ClearAllPoints()
            modal.boxWrap:SetPoint("TOPLEFT", modal, "TOPLEFT", 14, -32)
            modal.boxWrap:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -14, 28)
        end
    end

    local fullText = table.concat(lines, "\n")
    modal.currentText = fullText
    modal:Show()
    modal:Raise()

    local sf = modal.scrollFrame
    local eb = modal.editBox
    local sfW = (sf and sf:GetWidth()) or 556
    if sfW <= 24 then sfW = 556 end
    local sfH = (sf and sf:GetHeight()) or 340
    if sfH <= 24 then sfH = 340 end
    eb:SetWidth(sfW - 12)
    eb:SetHeight(math.max(sfH, lineCount * 16 + 32))
    eb:SetText(fullText)

    if _G.C_Timer and type(_G.C_Timer.After) == "function" then
        _G.C_Timer.After(0, function()
            if not modal:IsShown() then return end
            local liveW = (sf and sf:GetWidth()) or sfW
            local liveH = (sf and sf:GetHeight()) or sfH
            if liveW > 24 then eb:SetWidth(liveW - 12) end
            local strH = (eb.GetStringHeight and eb:GetStringHeight()) or (lineCount * 16)
            eb:SetHeight(math.max(liveH, strH + 32, lineCount * 16 + 32))
            if sf and sf.UpdateScrollChildRect then
                pcall(sf.UpdateScrollChildRect, sf)
            end
            if sf and sf.GetVerticalScrollRange and sf.SetVerticalScroll then
                local maxScroll = sf:GetVerticalScrollRange() or 0
                if maxScroll > 0 then
                    sf:SetVerticalScroll(maxScroll)
                else
                    sf:SetVerticalScroll(0)
                end
            end
            eb:SetFocus()
            eb:HighlightText()
        end)
    else
        if sf and sf.UpdateScrollChildRect then pcall(sf.UpdateScrollChildRect, sf) end
        if sf and sf.GetVerticalScrollRange and sf.SetVerticalScroll then
            sf:SetVerticalScroll(sf:GetVerticalScrollRange() or 0)
        end
        eb:SetFocus()
        eb:HighlightText()
    end
end

local function ComputeOnlineFriendsAndGuildCount()
    local totalOnline = 0
    local wowFriends = 0
    local bnOnline = 0
    local guildOnline = 0
    if _G.C_FriendList and type(_G.C_FriendList.GetNumOnlineFriends) == "function" then
        local ok, n = pcall(_G.C_FriendList.GetNumOnlineFriends)
        if ok and type(n) == "number" and not IsSecretValue(n) then
            wowFriends = math.max(0, n)
        end
    end
    if type(_G.BNGetNumFriends) == "function" then
        local ok, _, numBNetOnline = pcall(_G.BNGetNumFriends)
        if ok and type(numBNetOnline) == "number" and not IsSecretValue(numBNetOnline) then
            bnOnline = math.max(0, numBNetOnline)
        end
    end
    if type(_G.IsInGuild) == "function" and _G.IsInGuild() and type(_G.GetNumGuildMembers) == "function" then
        local ok, _, numOnlineMax = pcall(_G.GetNumGuildMembers)
        if ok and type(numOnlineMax) == "number" and not IsSecretValue(numOnlineMax) then
            guildOnline = math.max(0, numOnlineMax)
        end
    end
    totalOnline = wowFriends + bnOnline + guildOnline
    return totalOnline, wowFriends + bnOnline, guildOnline
end

local function ComputeEquipmentDurabilityPct()
    if type(_G.GetInventoryItemDurability) ~= "function" then
        return 100
    end
    local lowestPct = 100
    local curSum, maxSum = 0, 0
    for slot = 1, 18 do
        local ok, cur, max = pcall(_G.GetInventoryItemDurability, slot)
        if ok and type(cur) == "number" and type(max) == "number" and not IsSecretValue(cur) and not IsSecretValue(max) and max > 0 then
            curSum = curSum + cur
            maxSum = maxSum + max
            local pct = math.floor((cur / max) * 100 + 0.5)
            if pct < lowestPct then
                lowestPct = pct
            end
        end
    end
    if maxSum > 0 then
        local avgPct = math.floor((curSum / maxSum) * 100 + 0.5)
        return math.min(lowestPct, avgPct), lowestPct, avgPct
    end
    return 100, 100, 100
end

local RAIL_WIDGET_DEFS = {
    { key = "social",       label = "Social & Guild",     shortLabel = "Social",      icon = ICON_SOCIAL,       isTelemetry = true },
    { key = "durability",   label = "Durability (%)",     shortLabel = "Durability",  icon = ICON_SHIELD,       isTelemetry = true },
    { key = "vault",        label = "Great Vault & M+",   shortLabel = "Great Vault", icon = ICON_VAULT,        isTelemetry = false },
    { key = "copy",         label = "Copy & Clear Chat",  shortLabel = "Copy Chat",   icon = ICON_COPY,         isTelemetry = false },
    { key = "combatlog",    label = "Combat Log Toggle",  shortLabel = "Combat Log",  icon = ICON_LOG,          isTelemetry = false },
    { key = "lock",         label = "Lock & Fade Chat",   shortLabel = "Lock/Fade",   icon = ICON_LOCK,         isTelemetry = false },
    { key = "settings",     label = "Settings (/dchat)",  shortLabel = "Settings",    icon = ICON_COG,          isTelemetry = false, isBottom = true },
    { key = "scrollbottom", label = "Scroll to Bottom",   shortLabel = "Scroll Down", icon = ICON_CHEVRON_DOWN, isTelemetry = false, isBottom = true },
}

local function HasGreatVaultRewardReady()
    if _G.C_WeeklyRewards and type(_G.C_WeeklyRewards.HasAvailableRewards) == "function" then
        local ok, avail = pcall(_G.C_WeeklyRewards.HasAvailableRewards)
        if ok and avail == true and not IsSecretValue(avail) then
            return true
        end
    end
    return false
end

local function LayoutChatLeftRail(rail)
    if not rail or not rail.buttonsByKey then return end
    local db = EnsureDB()
    local rb = db.railButtons or DEFAULTS.railButtons
    local order = db.railOrder or DEFAULTS.railOrder

    local yTop = -4
    for _, key in ipairs(order) do
        local btn = rail.buttonsByKey[key]
        if btn and not btn.isBottomDocked then
            if rb[key] ~= false then
                btn:ClearAllPoints()
                btn:SetPoint("TOP", rail, "TOP", 0, yTop)
                btn:Show()
                yTop = yTop - (btn:GetHeight() + 2)
            else
                btn:Hide()
            end
        end
    end

    local bottomBtn = rail.buttonsByKey["scrollbottom"]
    local cogBtn    = rail.buttonsByKey["settings"]
    local yBot = 4
    if bottomBtn then
        if rb.scrollbottom ~= false then
            bottomBtn:ClearAllPoints()
            bottomBtn:SetPoint("BOTTOM", rail, "BOTTOM", 0, yBot)
            bottomBtn:Show()
            yBot = yBot + bottomBtn:GetHeight() + 2
        else
            bottomBtn:Hide()
        end
    end
    if cogBtn then
        if rb.settings ~= false then
            cogBtn:ClearAllPoints()
            cogBtn:SetPoint("BOTTOM", rail, "BOTTOM", 0, yBot)
            cogBtn:Show()
        else
            cogBtn:Hide()
        end
    end
end

function DynamicChat:RefreshLeftRailTelemetry()
    local cf1 = _G.ChatFrame1
    local entry = cf1 and chatSkinStore[cf1]
    local rail = entry and entry.leftRail
    if not rail then return end

    local db = EnsureDB()
    local mode = db.leftRailMode or "ALWAYS"
    local skinEnabled = (db.enableSleekChatSkin ~= false) and not self:IsExternalChatEngineLoaded()

    if not skinEnabled or mode == "OFF" or not IsPrimaryChatDockVisible() then
        rail:Hide()
        return
    end

    if mode == "COMBAT_HIDE" and InCombatLockdown and InCombatLockdown() then
        rail:SetAlpha(0)
        rail:Show()
    elseif mode == "HOVER" then
        local activeCF = _G.SELECTED_DOCK_FRAME or cf1
        local isHover = rail:IsMouseOver()
            or (entry.panel and entry.panel:IsMouseOver())
            or cf1:IsMouseOver()
            or (activeCF and activeCF.IsMouseOver and activeCF:IsMouseOver())
        if rail.buttonsByKey then
            for _, b in pairs(rail.buttonsByKey) do
                if b:IsShown() and b:IsMouseOver() then isHover = true; break end
            end
        end
        rail:SetAlpha(isHover and 1.0 or 0.14)
        rail:Show()
    else
        rail:SetAlpha(1.0)
        rail:Show()
    end

    LayoutChatLeftRail(rail)

    local ar, ag, ab = GetSuiteAccent()

    -- 1. Social Online Count (icon on top, crisp count below)
    if rail.socialBtn and rail.socialBtn.subText then
        local totalOnline = ComputeOnlineFriendsAndGuildCount()
        rail.socialBtn.subText:SetText(tostring(totalOnline))
        if rail.socialBtn:IsMouseOver() then
            if rail.socialBtn.icon then rail.socialBtn.icon:SetVertexColor(ar, ag, ab, 1.0) end
            rail.socialBtn.subText:SetTextColor(1, 1, 1, 1.0)
        else
            if rail.socialBtn.icon then rail.socialBtn.icon:SetVertexColor(0.66, 0.72, 0.80, 0.90) end
            rail.socialBtn.subText:SetTextColor(ar, ag, ab, 0.95)
        end
    end

    -- 2. Equipment Durability % (shield icon on top, % below)
    if rail.durBtn and rail.durBtn.subText then
        local durPct = ComputeEquipmentDurabilityPct()
        rail.durBtn.subText:SetText(tostring(durPct) .. "%")
        if durPct < 30 then
            rail.durBtn.subText:SetTextColor(0.97, 0.44, 0.44, 1.0) -- #F87171 Red
            if rail.durBtn.icon and not rail.durBtn:IsMouseOver() then
                rail.durBtn.icon:SetVertexColor(0.97, 0.44, 0.44, 0.95)
            end
        elseif durPct < 50 then
            rail.durBtn.subText:SetTextColor(0.98, 0.75, 0.14, 1.0) -- #FBBF24 Amber
            if rail.durBtn.icon and not rail.durBtn:IsMouseOver() then
                rail.durBtn.icon:SetVertexColor(0.98, 0.75, 0.14, 0.95)
            end
        else
            rail.durBtn.subText:SetTextColor(0.92, 0.95, 0.99, 0.95) -- Crisp White
            if rail.durBtn.icon and not rail.durBtn:IsMouseOver() then
                rail.durBtn.icon:SetVertexColor(0.66, 0.72, 0.80, 0.90)
            end
        end
    end

    -- 3. Great Vault Indicator on vaultBtn
    if rail.vaultBtn and rail.vaultBtn.icon then
        local hasReward = HasGreatVaultRewardReady()
        if hasReward then
            if not rail.vaultBtn:IsMouseOver() then
                rail.vaultBtn.icon:SetVertexColor(0.98, 0.80, 0.08, 1.0) -- #FACC15 Gold
            end
            if rail.vaultBtn.dot then
                rail.vaultBtn.dot:SetColorTexture(0.98, 0.80, 0.08, 1.0)
                rail.vaultBtn.dot:Show()
            end
        else
            if not rail.vaultBtn:IsMouseOver() then
                rail.vaultBtn.icon:SetVertexColor(0.62, 0.68, 0.76, 0.88)
            end
            if rail.vaultBtn.dot then
                rail.vaultBtn.dot:Hide()
            end
        end
    end

    -- 3b. Captured Link Indicator on copyBtn
    if rail.copyBtn and rail.copyBtn.icon then
        local hasUnreadLink = (DynamicChat._hasUnreadCapturedURL == true and DynamicChat._latestCapturedURL ~= nil)
        if hasUnreadLink then
            if not rail.copyBtn:IsMouseOver() then
                rail.copyBtn.icon:SetVertexColor(ar, ag, ab, 1.0)
            end
            if rail.copyBtn.dot then
                rail.copyBtn.dot:SetColorTexture(ar, ag, ab, 1.0)
                rail.copyBtn.dot:Show()
            end
        else
            if not rail.copyBtn:IsMouseOver() then
                rail.copyBtn.icon:SetVertexColor(0.62, 0.68, 0.76, 0.88)
            end
            if rail.copyBtn.dot then
                rail.copyBtn.dot:Hide()
            end
        end
    end

    -- 4. Combat Log Indicator on logBtn
    if rail.logBtn and rail.logBtn.icon then
        local isLogging = (type(_G.LoggingCombat) == "function" and _G.LoggingCombat() == true)
        if isLogging then
            if not rail.logBtn:IsMouseOver() then
                rail.logBtn.icon:SetVertexColor(0.20, 0.83, 0.60, 1.0) -- #34D399 Emerald
            end
            if rail.logBtn.dot then
                rail.logBtn.dot:SetColorTexture(0.20, 0.83, 0.60, 1.0)
                rail.logBtn.dot:Show()
            end
        else
            if not rail.logBtn:IsMouseOver() then
                rail.logBtn.icon:SetVertexColor(0.62, 0.68, 0.76, 0.88)
            end
            if rail.logBtn.dot then
                rail.logBtn.dot:Hide()
            end
        end
    end

    -- 5. Lock / Fade Indicator on lockBtn
    if rail.lockBtn and rail.lockBtn.icon then
        local isLocked = (cf1.isLocked and true or false)
        if not isLocked then
            if not rail.lockBtn:IsMouseOver() then
                rail.lockBtn.icon:SetVertexColor(0.98, 0.75, 0.14, 1.0) -- #FBBF24 Amber when unlocked
            end
            if rail.lockBtn.dot then
                rail.lockBtn.dot:SetColorTexture(0.98, 0.75, 0.14, 1.0)
                rail.lockBtn.dot:Show()
            end
        else
            if not rail.lockBtn:IsMouseOver() then
                rail.lockBtn.icon:SetVertexColor(0.62, 0.68, 0.76, 0.88)
            end
            if rail.lockBtn.dot then
                rail.lockBtn.dot:Hide()
            end
        end
    end

    -- 6. Scroll-to-Bottom indicator on bottomBtn
    if rail.bottomBtn and rail.bottomBtn.icon then
        local activeCF = _G.SELECTED_DOCK_FRAME or cf1
        local atBottom = true
        if activeCF and type(activeCF.AtBottom) == "function" then
            local ok, res = pcall(activeCF.AtBottom, activeCF)
            if ok and res == false then
                atBottom = false
            end
        end
        if not atBottom then
            rail.bottomBtn.icon:SetVertexColor(0.98, 0.75, 0.14, 1.0) -- #FBBF24 Bright Amber alert
            if rail.bottomBtn.dot then
                rail.bottomBtn.dot:SetColorTexture(ar, ag, ab, 1.0)
                rail.bottomBtn.dot:Show()
            end
        else
            if rail.bottomBtn:IsMouseOver() then
                rail.bottomBtn.icon:SetVertexColor(ar, ag, ab, 1.0)
            else
                rail.bottomBtn.icon:SetVertexColor(0.58, 0.64, 0.72, 0.35)
            end
            if rail.bottomBtn.dot then
                rail.bottomBtn.dot:Hide()
            end
        end
    end

    if DynamicChat.railChipGrid and DynamicChat.railChipGrid.RefreshValue then
        DynamicChat.railChipGrid:RefreshValue()
    end
end

local function CreateRailButton(rail, isTelemetry, iconTexture, subLabel, isBottomDocked)
    local btn = CreateFrame("Button", nil, rail, "BackdropTemplate")
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(22)
    btn:SetSize(32, isTelemetry and 26 or 22)
    btn.isBottomDocked = (isBottomDocked == true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    btn:SetBackdropColor(1, 1, 1, 0.00)

    local ic = btn:CreateTexture(nil, "ARTWORK")
    if isTelemetry then
        ic:SetSize(12, 12)
        ic:SetPoint("TOP", btn, "TOP", 0, -2)
    else
        ic:SetSize(13, 13)
        ic:SetPoint("CENTER", btn, "CENTER", 0, 0)
    end
    ic:SetTexture(iconTexture)
    ic:SetVertexColor(0.62, 0.68, 0.76, 0.88)
    DisableTexPixelSnap(ic)
    btn.icon = ic

    if isTelemetry then
        local t2 = btn:CreateFontString(nil, "OVERLAY")
        SetSafeFont(t2, 8.5, "")
        t2:SetPoint("BOTTOM", btn, "BOTTOM", 0, 1)
        t2:SetTextColor(0.92, 0.95, 0.99, 0.95)
        t2:SetText(subLabel or "")
        btn.subText = t2
    end

    local dot = btn:CreateTexture(nil, "OVERLAY")
    dot:SetSize(4, 4)
    dot:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -3, -3)
    DisableTexPixelSnap(dot)
    dot:Hide()
    btn.dot = dot

    btn:SetScript("OnEnter", function(self)
        local ar, ag, ab = GetSuiteAccent()
        self:SetBackdropColor(1, 1, 1, 0.06)
        if self.icon then
            self.icon:SetVertexColor(ar, ag, ab, 1.0)
        end
        if self.subText then
            self.subText:SetTextColor(1, 1, 1, 1.0)
        end
        DynamicChat:RefreshLeftRailTelemetry()
        if self.tooltipFunc then
            self.tooltipFunc(self)
        end
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(1, 1, 1, 0.00)
        if self.icon then
            self.icon:SetVertexColor(0.62, 0.68, 0.76, 0.88)
        end
        if _G.GameTooltip then _G.GameTooltip:Hide() end
        DynamicChat:RefreshLeftRailTelemetry()
    end)

    return btn
end

local function EnsureRailPopoverClickCatcher()
    if railPopoverClickCatcher then return railPopoverClickCatcher end
    local cc = CreateFrame("Button", nil, UIParent)
    cc:SetFrameStrata("DIALOG")
    cc:SetFrameLevel(1)
    cc:SetAllPoints(UIParent)
    cc:EnableMouse(true)
    cc:RegisterForClicks("AnyUp", "AnyDown")
    cc:SetScript("OnClick", function()
        if railPopoverFrame and railPopoverFrame:IsShown() then
            railPopoverFrame:Hide()
        end
        cc:Hide()
    end)
    railPopoverClickCatcher = cc
    return cc
end

local function ShowLeftRailCustomizerMenu(anchorBtn)
    if railPopoverFrame and railPopoverFrame:IsShown() then
        railPopoverFrame:Hide()
        if railPopoverClickCatcher then railPopoverClickCatcher:Hide() end
        return
    end
    if anchorBtn and not anchorBtn._dcRailPopHooked then
        anchorBtn._dcRailPopHooked = true
        anchorBtn:HookScript("OnHide", function()
            if railPopoverFrame and railPopoverFrame:IsShown() then
                railPopoverFrame:Hide()
            end
            if railPopoverClickCatcher and railPopoverClickCatcher:IsShown() then
                railPopoverClickCatcher:Hide()
            end
        end)
    end
    if not railPopoverFrame then
        local pop = CreateFrame("Frame", "DynamicChatRailCustomizerMenu", UIParent, "BackdropTemplate")
        pop:SetSize(226, 268)
        pop:SetFrameStrata("TOOLTIP")
        pop:SetFrameLevel(220)
        pop:SetToplevel(true)
        pop:SetClampedToScreen(true)
        pop:EnableMouse(true)
        pop:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        pop:SetBackdropColor(0.043, 0.051, 0.071, 0.99)
        SafeRegisterUISpecialFrame("DynamicChatRailCustomizerMenu")
        local borderOverlay = CreateFrame("Frame", nil, pop, "BackdropTemplate")
        borderOverlay:SetAllPoints(pop)
        borderOverlay:SetFrameLevel(pop:GetFrameLevel() + 10)
        borderOverlay:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        pop.borderOverlay = borderOverlay
        pop:HookScript("OnHide", function()
            if railPopoverClickCatcher and railPopoverClickCatcher:IsShown() then
                railPopoverClickCatcher:Hide()
            end
        end)

        local hdr = pop:CreateFontString(nil, "OVERLAY")
        SetSafeFont(hdr, 10, "")
        hdr:SetPoint("TOPLEFT", pop, "TOPLEFT", 10, -8)
        hdr:SetText("LEFT RAIL BUTTONS & MODE")
        pop.hdr = hdr

        local modeWrap = CreateFrame("Frame", nil, pop)
        modeWrap:SetPoint("TOPLEFT", pop, "TOPLEFT", 8, -26)
        modeWrap:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -8, -26)
        modeWrap:SetHeight(22)
        pop.modeBtns = {}
        local modes = {
            { key = "ALWAYS",      label = "Always" },
            { key = "HOVER",       label = "Hover" },
            { key = "COMBAT_HIDE", label = "OOC" },
            { key = "OFF",         label = "Off" },
        }
        for idx, m in ipairs(modes) do
            local mb = CreateFrame("Button", nil, modeWrap, "BackdropTemplate")
            mb:SetSize(50, 20)
            mb:SetPoint("LEFT", modeWrap, "LEFT", (idx - 1) * 53, 0)
            mb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            mb.modeKey = m.key
            mb.lbl = mb:CreateFontString(nil, "OVERLAY")
            SetSafeFont(mb.lbl, 9.5, "")
            mb.lbl:SetPoint("CENTER", 0, 0)
            mb.lbl:SetText(m.label)
            mb:SetScript("OnClick", function()
                EnsureDB().leftRailMode = m.key
                DynamicChat:ApplySavedChatFramePosition()
                DynamicChat:ApplySleekChatSkin()
                DynamicChat:RefreshConfigUI()
                pop:RefreshMenu()
            end)
            pop.modeBtns[idx] = mb
        end

        pop.rows = {}
        for idx, def in ipairs(RAIL_WIDGET_DEFS) do
            local r = CreateFrame("Button", nil, pop, "BackdropTemplate")
            r:SetSize(210, 24)
            r:SetPoint("TOPLEFT", pop, "TOPLEFT", 8, -54 - (idx - 1) * 25)
            r:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            r.widgetKey = def.key

            local ic = r:CreateTexture(nil, "ARTWORK")
            ic:SetSize(12, 12)
            ic:SetPoint("LEFT", r, "LEFT", 8, 0)
            ic:SetTexture(def.icon)
            DisableTexPixelSnap(ic)
            r.icon = ic

            local txt = r:CreateFontString(nil, "OVERLAY")
            SetSafeFont(txt, 10, "")
            txt:SetPoint("LEFT", ic, "RIGHT", 8, 0)
            txt:SetText(def.label)
            r.txt = txt

            local stateTxt = r:CreateFontString(nil, "OVERLAY")
            SetSafeFont(stateTxt, 9.5, "")
            stateTxt:SetPoint("RIGHT", r, "RIGHT", -8, 0)
            r.stateTxt = stateTxt

            r:SetScript("OnClick", function()
                local db = EnsureDB()
                db.railButtons = db.railButtons or {}
                db.railButtons[def.key] = (db.railButtons[def.key] == false) and true or false
                DynamicChat:RefreshLeftRailTelemetry()
                DynamicChat:RefreshConfigUI()
                pop:RefreshMenu()
            end)
            pop.rows[idx] = r
        end

        function pop:RefreshMenu()
            local ar, ag, ab = GetSuiteAccent()
            local db = EnsureDB()
            local curMode = db.leftRailMode or "ALWAYS"
            local rb = db.railButtons or DEFAULTS.railButtons
            self:SetBackdropBorderColor(ar, ag, ab, 0.92)
            if self.borderOverlay then
                self.borderOverlay:SetBackdropBorderColor(ar, ag, ab, 0.92)
            end
            self.hdr:SetTextColor(ar, ag, ab, 1.0)

            for _, mb in ipairs(self.modeBtns) do
                local isSel = (mb.modeKey == curMode)
                if isSel then
                    if mb.modeKey == "OFF" then
                        mb:SetBackdropColor(0.118, 0.141, 0.188, 0.98)
                        mb:SetBackdropBorderColor(0.392, 0.455, 0.545, 0.90)
                        mb.lbl:SetTextColor(0.886, 0.910, 0.941, 1.0)
                    else
                        mb:SetBackdropColor(ar * 0.40, ag * 0.40, ab * 0.40, 0.98)
                        mb:SetBackdropBorderColor(ar, ag, ab, 0.95)
                        mb.lbl:SetTextColor(1, 1, 1, 1)
                    end
                else
                    mb:SetBackdropColor(0.078, 0.090, 0.122, 0.94)
                    mb:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.90)
                    mb.lbl:SetTextColor(0.62, 0.68, 0.76, 1)
                end
            end

            for _, r in ipairs(self.rows) do
                local on = (rb[r.widgetKey] ~= false)
                if on then
                    r:SetBackdropColor(ar * 0.18, ag * 0.18, ab * 0.18, 0.95)
                    r:SetBackdropBorderColor(ar, ag, ab, 0.65)
                    r.icon:SetVertexColor(ar, ag, ab, 1.0)
                    r.txt:SetTextColor(0.96, 0.98, 1.0, 1.0)
                    r.stateTxt:SetText("|cFF34D399ON|r")
                else
                    r:SetBackdropColor(0.065, 0.075, 0.098, 0.90)
                    r:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.75)
                    r.icon:SetVertexColor(0.45, 0.50, 0.58, 0.75)
                    r.txt:SetTextColor(0.55, 0.60, 0.68, 0.90)
                    r.stateTxt:SetText("|cFF64748BOFF|r")
                end
            end
        end

        railPopoverFrame = pop
    end

    local cc = EnsureRailPopoverClickCatcher()
    cc:Show()
    railPopoverFrame:ClearAllPoints()
    railPopoverFrame:SetPoint("BOTTOMLEFT", anchorBtn, "BOTTOMRIGHT", 8, 0)
    railPopoverFrame:RefreshMenu()
    railPopoverFrame:Show()
    railPopoverFrame:Raise()
end

local function EnsureChatLeftRail(entry, panel)
    if entry.leftRail then return entry.leftRail end

    local rail = CreateFrame("Frame", nil, UIParent)
    rail:SetFrameStrata("MEDIUM")
    rail:SetFrameLevel(20)
    rail:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    rail:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    rail:SetWidth(34)
    rail.buttonsByKey = {}

    -- 1. social - Social / Guild Online Button (icon_social.tga + numeric badge)
    local socialBtn = CreateRailButton(rail, true, ICON_SOCIAL, "0", false)
    socialBtn.tooltipFunc = function(self)
        if not _G.GameTooltip then return end
        local _, _, _, hex6 = GetSuiteAccent()
        local totalOnline, friendsOnline, guildOnline = ComputeOnlineFriendsAndGuildCount()
        _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        _G.GameTooltip:AddLine("|cFF" .. hex6 .. "Social & Guild Overview|r")
        _G.GameTooltip:AddLine(string.format("|cFF94A3B8Friends Online:|r |cFFF8FAFC%d|r   |cFF94A3B8Guild Online:|r |cFFF8FAFC%d|r   |cFF94A3B8Total:|r |cFF%s%d|r", friendsOnline, guildOnline, hex6, totalOnline))
        _G.GameTooltip:AddLine(" ")
        _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", "Toggle Friends List", "34D399"))
        _G.GameTooltip:AddLine(FormatTooltipCmd("Right-Click:", "Toggle Guild & Communities", "38BDF8"))
        _G.GameTooltip:Show()
    end
    socialBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if type(_G.ToggleGuildFrame) == "function" then pcall(_G.ToggleGuildFrame) end
        else
            if type(_G.ToggleFriendsFrame) == "function" then pcall(_G.ToggleFriendsFrame) end
        end
    end)
    rail.socialBtn = socialBtn
    rail.buttonsByKey["social"] = socialBtn

    -- 2. durability - Equipment Durability Button (icon_shield.tga + 100%)
    local durBtn = CreateRailButton(rail, true, ICON_SHIELD, "100%", false)
    durBtn.tooltipFunc = function(self)
        if not _G.GameTooltip then return end
        local _, _, _, hex6 = GetSuiteAccent()
        local _, lowestPct, avgPct = ComputeEquipmentDurabilityPct()
        _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        _G.GameTooltip:AddLine("|cFF" .. hex6 .. "Equipment Durability (Dur)|r")
        _G.GameTooltip:AddLine(string.format("|cFF94A3B8Lowest Slot:|r |cFFF8FAFC%d%%|r   |cFF94A3B8Average:|r |cFFF8FAFC%d%%|r", lowestPct or 100, avgPct or 100))
        _G.GameTooltip:AddLine(" ")
        _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", "Toggle Character Equipment Sheet", "34D399"))
        _G.GameTooltip:AddLine(FormatTooltipCmd("Right-Click:", "Toggle DynamicBags Inventory", "38BDF8"))
        _G.GameTooltip:Show()
    end
    durBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if _G.DynamicBags and _G.DynamicBags.U and type(_G.DynamicBags.U.ToggleWindow) == "function" then
                pcall(_G.DynamicBags.U.ToggleWindow)
            elseif type(_G.ToggleAllBags) == "function" then
                pcall(_G.ToggleAllBags)
            end
        else
            if type(_G.ToggleCharacter) == "function" then
                pcall(_G.ToggleCharacter, "PaperDollFrame")
            end
        end
    end)
    rail.durBtn = durBtn
    rail.buttonsByKey["durability"] = durBtn

    -- 3. vault - Great Vault & Mythic+ Button (icon_vault.tga)
    local vaultBtn = CreateRailButton(rail, false, ICON_VAULT, nil, false)
    vaultBtn.tooltipFunc = function(self)
        if not _G.GameTooltip then return end
        local _, _, _, hex6 = GetSuiteAccent()
        local hasReward = HasGreatVaultRewardReady()
        _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        _G.GameTooltip:AddLine("|cFF" .. hex6 .. "Great Vault & Mythic+ Progress|r")
        _G.GameTooltip:AddLine("|cFF94A3B8Weekly Vault Status:|r " .. (hasReward and "|cFFFACC15[Reward Ready to Claim!]|r" or "|cFFE2E8F0View Raid, M+ & World Vault Slots|r"))
        _G.GameTooltip:AddLine(" ")
        _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", "Open Great Vault UI anywhere in the world", "34D399"))
        _G.GameTooltip:AddLine(FormatTooltipCmd("Right-Click:", "Toggle Group Finder / Mythic+ Dungeons", "38BDF8"))
        _G.GameTooltip:Show()
    end
    vaultBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if type(_G.PVEFrame_ToggleFrame) == "function" then
                pcall(_G.PVEFrame_ToggleFrame)
            end
        else
            if _G.C_AddOns and type(_G.C_AddOns.LoadAddOn) == "function" then
                pcall(_G.C_AddOns.LoadAddOn, "Blizzard_WeeklyRewards")
            end
            if _G.WeeklyRewardsFrame and type(_G.WeeklyRewardsFrame.SetShown) == "function" then
                pcall(_G.WeeklyRewardsFrame.SetShown, _G.WeeklyRewardsFrame, not _G.WeeklyRewardsFrame:IsShown())
            end
        end
    end)
    rail.vaultBtn = vaultBtn
    rail.buttonsByKey["vault"] = vaultBtn

    -- 4. copy - Copy & Clear Chat Button (icon_copy.tga)
    local copyBtn = CreateRailButton(rail, false, ICON_COPY, nil, false)
    copyBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    copyBtn.tooltipFunc = function(self)
        if not _G.GameTooltip then return end
        local _, _, _, hex6 = GetSuiteAccent()
        _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        _G.GameTooltip:AddLine("|cFF" .. hex6 .. "Copy & Clear Chat History|r")
        _G.GameTooltip:AddLine("|cFF94A3B8Opens a scrollable copy window with recent messages and clickable link pills from the active chat tab.|r", 1, 1, 1, true)
        local latestURL = DynamicChat._latestCapturedURL
        if latestURL and not IsSecretValue(latestURL) and type(latestURL) == "string" and latestURL ~= "" then
            _G.GameTooltip:AddLine(" ")
            _G.GameTooltip:AddLine("|cFF94A3B8Latest Link:|r |cFF" .. hex6 .. latestURL .. "|r", 1, 1, 1, true)
        end
        _G.GameTooltip:AddLine(" ")
        _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", "Open Full Chat History & Recent Links Window (Ctrl+C)", "34D399"))
        _G.GameTooltip:AddLine(FormatTooltipCmd("Shift-Click / Middle-Click:", "Copy Latest Link (Ctrl+C)", hex6))
        _G.GameTooltip:AddLine(FormatTooltipCmd("Right-Click:", "Clear messages in the active chat tab", "38BDF8"))
        _G.GameTooltip:Show()
    end
    copyBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            local targetCF = ResolveActiveChatFrame()
            if targetCF and type(targetCF.Clear) == "function" then
                pcall(targetCF.Clear, targetCF)
            end
            if targetCF == _G.ChatFrame1 or not targetCF then
                EnsureDB().savedChatHistory = {}
            end
        elseif button == "MiddleButton" or (button == "LeftButton" and IsShiftKeyDown and IsShiftKeyDown()) then
            local latestURL = DynamicChat._latestCapturedURL
            if not latestURL or latestURL == "" then
                local cf = ResolveActiveChatFrame()
                if cf and type(cf.GetNumMessages) == "function" then
                    local foundList, seenMap = {}, {}
                    local total = cf:GetNumMessages() or 0
                    for idx = math.max(1, total - 100), total do
                        local line = StripSecretOrExtractLine(cf, idx)
                        if line then
                            ExtractURLsFromText(line, foundList, seenMap)
                        end
                    end
                    if #foundList > 0 then
                        latestURL = foundList[#foundList]
                        DynamicChat._latestCapturedURL = latestURL
                    end
                end
            end
            if latestURL and latestURL ~= "" then
                DynamicChat:ShowURLCopyPopup(latestURL)
            else
                DynamicChat:ShowFullChatHistoryModal(ResolveActiveChatFrame())
            end
        else
            DynamicChat:ShowFullChatHistoryModal(ResolveActiveChatFrame())
        end
    end)
    rail.copyBtn = copyBtn
    rail.buttonsByKey["copy"] = copyBtn

    -- 5. combatlog - Combat Log Toggle Button (icon_log.tga + Emerald dot when logging)
    local logBtn = CreateRailButton(rail, false, ICON_LOG, nil, false)
    logBtn.tooltipFunc = function(self)
        if not _G.GameTooltip then return end
        local _, _, _, hex6 = GetSuiteAccent()
        local isLogging = (type(_G.LoggingCombat) == "function" and _G.LoggingCombat() == true)
        local stateBadge = isLogging and "|cFF34D399[Active]|r" or "|cFF94A3B8[Inactive]|r"
        _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        _G.GameTooltip:AddLine("|cFF" .. hex6 .. "WoW Combat Logging (/combatlog)|r")
        _G.GameTooltip:AddLine("|cFF94A3B8Combat Logging:|r " .. stateBadge)
        _G.GameTooltip:AddLine(" ")
        _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", "Toggle WoW Combat Logging On or Off", "34D399"))
        _G.GameTooltip:AddLine(FormatTooltipCmd("Right-Click:", "Open DynamicFPS (/dfps) Performance Guard", "38BDF8"))
        _G.GameTooltip:Show()
    end
    logBtn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if _G.DynamicSuite and type(_G.DynamicSuite.OpenModule) == "function" then
                _G.DynamicSuite:OpenModule("DynamicFPS")
            elseif _G.SlashCmdList and type(_G.SlashCmdList["DYNAMICFPS"]) == "function" then
                _G.SlashCmdList["DYNAMICFPS"]("")
            end
        else
            if type(_G.LoggingCombat) == "function" then
                local nextState = not (_G.LoggingCombat() == true)
                pcall(_G.LoggingCombat, nextState)
                PrintMsg("Combat Logging: " .. (nextState and "|cFF34D399ENABLED|r" or "|cFF94A3B8DISABLED|r"))
            end
        end
        DynamicChat:RefreshLeftRailTelemetry()
        if self:IsMouseOver() and self.tooltipFunc then
            self.tooltipFunc(self)
        end
    end)
    rail.logBtn = logBtn
    rail.buttonsByKey["combatlog"] = logBtn

    -- 6. lock - Position / Resize Chat in [+ HUD] Edit Mode & Fade Button (icon_lock.tga)
    local lockBtn = CreateRailButton(rail, false, ICON_LOCK, nil, false)
    lockBtn.tooltipFunc = function(self)
        if not _G.GameTooltip then return end
        local _, _, _, hex6 = GetSuiteAccent()
        local cf1 = _G.ChatFrame1
        local isFading = (cf1 and cf1.GetFading and cf1:GetFading()) and true or false
        local hasSavedPos = (EnsureDB().chatFramePos ~= nil)
        _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        _G.GameTooltip:AddLine("|cFF" .. hex6 .. "Chat Position ([+ HUD] Edit Mode), Fade & Zone Profiles|r")
        _G.GameTooltip:AddLine(string.format("|cFF94A3B8Position:|r %s   |cFF94A3B8Text Fade:|r %s",
            hasSavedPos and "|cFF34D399[Custom HUD Saved]|r" or "|cFFE2E8F0[Default]|r",
            isFading and "|cFF34D399[Enabled]|r" or "|cFF94A3B8[Off]|r"))
        _G.GameTooltip:AddLine(" ")
        _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", "Open [+ HUD] Edit Mode to Move, Snap & Resize Chat Frame", "34D399"))
        _G.GameTooltip:AddLine(FormatTooltipCmd("Right-Click:", "Toggle Chat Text Auto-Fading On or Off", "38BDF8"))
        _G.GameTooltip:AddLine(FormatTooltipCmd("Shift-Click:", "Open DynamicLoad (/dl) Zone Profile Switcher", hex6))
        _G.GameTooltip:Show()
    end
    lockBtn:SetScript("OnClick", function(self, button)
        local cf1 = _G.ChatFrame1
        if IsShiftKeyDown and IsShiftKeyDown() then
            if _G.DynamicSuite and type(_G.DynamicSuite.OpenModule) == "function" then
                _G.DynamicSuite:OpenModule("DynamicLoad")
            elseif _G.SlashCmdList and type(_G.SlashCmdList["DYNAMICLOAD"]) == "function" then
                _G.SlashCmdList["DYNAMICLOAD"]("")
            end
            return
        end
        if not cf1 then return end
        if button == "RightButton" then
            if cf1.GetFading and cf1.SetFading then
                local nextFade = not (cf1:GetFading() == true)
                for i = 1, 10 do
                    local f = _G["ChatFrame" .. i]
                    if f and f.SetFading then pcall(f.SetFading, f, nextFade) end
                end
                PrintMsg("Chat Text Auto-Fading: " .. (nextFade and "|cFF34D399ENABLED|r" or "|cFF94A3B8OFF|r"))
            end
        else
            if _G.DynamicSuite and type(_G.DynamicSuite.EnterHudEditMode) == "function" then
                if _G.GameTooltip then _G.GameTooltip:Hide() end
                _G.DynamicSuite.EnterHudEditMode("CHAT")
                return
            end
            local nextLock = not (cf1.isLocked and true or false)
            if type(_G.FCF_SetLocked) == "function" then
                pcall(_G.FCF_SetLocked, cf1, nextLock)
            end
            PrintMsg("ChatFrame1: " .. (nextLock and "|cFF34D399LOCKED|r" or "|cFFFBBF24UNLOCKED|r"))
        end
        DynamicChat:RefreshLeftRailTelemetry()
        if self:IsMouseOver() and self.tooltipFunc then
            self.tooltipFunc(self)
        end
    end)
    rail.lockBtn = lockBtn
    rail.buttonsByKey["lock"] = lockBtn

    -- 7. settings - DynamicChat Settings & Quick Rail Customizer (ICON_COG, docked at bottom above scrollbottom)
    local cogBtn = CreateRailButton(rail, false, ICON_COG, nil, true)
    cogBtn.tooltipFunc = function(self)
        if not _G.GameTooltip then return end
        local _, _, _, hex6 = GetSuiteAccent()
        _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        _G.GameTooltip:AddLine("|cFF" .. hex6 .. "DynamicChat Settings & Left Rail Menu|r")
        _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", "Open DynamicChat (/dchat) workspace", "34D399"))
        _G.GameTooltip:AddLine(FormatTooltipCmd("Right-Click:", "Customise Left Rail buttons & visibility mode", "38BDF8"))
        _G.GameTooltip:Show()
    end
    cogBtn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ShowLeftRailCustomizerMenu(self)
        else
            DynamicChat:OpenWorkspace()
        end
    end)
    rail.cogBtn = cogBtn
    rail.buttonsByKey["settings"] = cogBtn

    -- 8. scrollbottom - Scroll to Bottom Button (ICON_CHEVRON_DOWN, docked at bottom of rail)
    local bottomBtn = CreateRailButton(rail, false, ICON_CHEVRON_DOWN, nil, true)
    bottomBtn.tooltipFunc = function(self)
        if not _G.GameTooltip then return end
        local _, _, _, hex6 = GetSuiteAccent()
        _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        _G.GameTooltip:AddLine("|cFF" .. hex6 .. "Scroll to Bottom|r")
        _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", "Jump to the latest message in the active chat tab", "34D399"))
        _G.GameTooltip:Show()
    end
    bottomBtn:SetScript("OnClick", function()
        local targetCF = _G.SELECTED_DOCK_FRAME or _G.ChatFrame1
        if targetCF and type(targetCF.ScrollToBottom) == "function" then
            pcall(targetCF.ScrollToBottom, targetCF)
        end
        DynamicChat:RefreshLeftRailTelemetry()
    end)
    rail.bottomBtn = bottomBtn
    rail.buttonsByKey["scrollbottom"] = bottomBtn

    LayoutChatLeftRail(rail)
    entry.leftRail = rail
    return rail
end

local function GetDynamicEditBoxPromptHint(db)
    db = db or EnsureDB()
    if db.enableTargetWhisper == false then
        return "Press Enter to chat..."
    end
    return "Press Enter to chat or type /ww to whisper target..."
end

local function EnsureSleekEditBoxBar()
    if chatEditBoxSkin then return chatEditBoxSkin end
    local bar = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    bar:SetFrameStrata("BACKGROUND")
    bar:SetFrameLevel(3)
    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bar:SetBackdropColor(0, 0, 0, 0)
    bar:SetBackdropBorderColor(0, 0, 0, 0)
    local ar, ag, ab = GetSuiteAccent()

    local leftBar = bar:CreateTexture(nil, "OVERLAY")
    leftBar:SetWidth(2)
    leftBar:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    leftBar:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 1, 1)
    leftBar:SetColorTexture(ar, ag, ab, 0.55)
    DisableTexPixelSnap(leftBar)
    bar.leftBar = leftBar

    local promptHint = bar:CreateFontString(nil, "OVERLAY")
    SetSafeFont(promptHint, 10, "")
    promptHint:SetPoint("LEFT", bar, "LEFT", 10, 0)
    promptHint:SetPoint("RIGHT", bar, "RIGHT", -10, 0)
    promptHint:SetJustifyH("LEFT")
    promptHint:SetWordWrap(false)
    promptHint:SetTextColor(0.58, 0.64, 0.72, 0.55)
    promptHint:SetText(GetDynamicEditBoxPromptHint())
    bar.promptHint = promptHint

    bar:Hide()
    chatEditBoxSkin = bar
    return bar
end

local passiveSkinnedEditBoxes = {}

local function ApplyPassiveEditBoxSkinOnInit(editBox, cfName, skinEnabled, syncFont, fontPath)
    if not editBox then return end
    if IsEllesmereUILoaded() then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if IsEditBoxSecretOrBNWhisper(editBox) then
        return
    end

    local state = passiveSkinnedEditBoxes[editBox]
    if not state then
        state = {}
        passiveSkinnedEditBoxes[editBox] = state
    end

    if state.skinEnabled ~= skinEnabled then
        state.skinEnabled = skinEnabled
        for _, suffix in ipairs(EDITBOX_TEXTURE_SUFFIXES) do
            StripTextureSafe(_G[cfName .. "EditBox" .. suffix], skinEnabled)
        end
        if editBox.Left then StripTextureSafe(editBox.Left, skinEnabled) end
        if editBox.Mid then StripTextureSafe(editBox.Mid, skinEnabled) end
        if editBox.Right then StripTextureSafe(editBox.Right, skinEnabled) end
        if editBox.FocusLeft then StripTextureSafe(editBox.FocusLeft, skinEnabled) end
        if editBox.FocusMid then StripTextureSafe(editBox.FocusMid, skinEnabled) end
        if editBox.FocusRight then StripTextureSafe(editBox.FocusRight, skinEnabled) end
        if editBox.NineSlice then SetRegionAlphaSafe(editBox.NineSlice, skinEnabled and 0 or 1) end
    end

    if syncFont and state.fontPath ~= fontPath then
        state.fontPath = fontPath
        if editBox.GetFont and editBox.SetFont then
            local okEF, _, ebSize, ebFlags = pcall(editBox.GetFont, editBox)
            local safeEbSize = (okEF and not IsSecretValue(ebSize) and type(ebSize) == "number" and ebSize >= 9 and ebSize <= 28) and ebSize or 13
            local safeEbFlags = (okEF and not IsSecretValue(ebFlags) and type(ebFlags) == "string") and ebFlags or ""
            pcall(editBox.SetFont, editBox, fontPath, safeEbSize, safeEbFlags)
        end
        if editBox.header and editBox.header.SetFont then
            pcall(editBox.header.SetFont, editBox.header, fontPath, 13, "")
        end
        if editBox.headerSuffix and editBox.headerSuffix.SetFont then
            pcall(editBox.headerSuffix.SetFont, editBox.headerSuffix, fontPath, 13, "")
        end
    end
end

local function RefreshSleekEditBoxBarColor(editBox, hasFocusOverride)
    if not chatEditBoxSkin then return end
    if IsEllesmereUILoaded() then
        chatEditBoxSkin:Hide()
        return
    end
    local targetEB = editBox or _G.ChatFrame1EditBox
    if targetEB and IsEditBoxSecretOrBNWhisper(targetEB) then
        return
    end
    local db = EnsureDB()
    local bgAlpha = tonumber(db.chatBgAlpha) or 0.25
    local ar, ag, ab = GetSuiteAccent()
    local cr, cg, cb = ar, ag, ab
    if targetEB and targetEB.GetAttribute then
        local ok, chatType = pcall(targetEB.GetAttribute, targetEB, "chatType")
        if ok and chatType and not IsSecretValue(chatType) and not (issecretvalue and issecretvalue(chatType)) and _G.ChatTypeInfo and _G.ChatTypeInfo[chatType] then
            local info = _G.ChatTypeInfo[chatType]
            cr = tonumber(info.r) or ar
            cg = tonumber(info.g) or ag
            cb = tonumber(info.b) or ab
        end
    end
    if cr > 0.88 and cg > 0.88 and cb > 0.88 then
        cr, cg, cb = 0.72, 0.78, 0.86
    end

    local hasFocus
    if hasFocusOverride ~= nil and not IsSecretValue(hasFocusOverride) then
        hasFocus = (hasFocusOverride == true)
    else
        hasFocus = DynamicChat.SafeEditBoxHasFocus(targetEB)
    end

    if hasFocus then
        chatEditBoxSkin:SetFrameStrata("LOW")
        chatEditBoxSkin:SetFrameLevel(5)
        chatEditBoxSkin:SetBackdropColor(0.035, 0.039, 0.051, 0.94) -- #090A0D low-glare focused dock
        chatEditBoxSkin:SetBackdropBorderColor(cr, cg, cb, 0.40)
        if chatEditBoxSkin.leftBar then
            chatEditBoxSkin.leftBar:SetWidth(2)
            chatEditBoxSkin.leftBar:SetColorTexture(cr, cg, cb, 0.90)
            chatEditBoxSkin.leftBar:Show()
        end
        if chatEditBoxSkin.promptHint then
            chatEditBoxSkin.promptHint:Hide()
        end
    else
        -- When idle, entry.panel already provides the unified Smoked-Glass background and border,
        -- so chatEditBoxSkin's own backdrop/border stays 100% transparent (zero seam or double-shading!).
        chatEditBoxSkin:SetFrameStrata("BACKGROUND")
        chatEditBoxSkin:SetFrameLevel(3)
        chatEditBoxSkin:SetBackdropColor(0, 0, 0, 0)
        chatEditBoxSkin:SetBackdropBorderColor(0, 0, 0, 0)
        if chatEditBoxSkin.leftBar then
            chatEditBoxSkin.leftBar:SetWidth(2)
            local bStyle = db.chatBorderStyle or "ACCENT"
            if bStyle == "DARK" or bStyle == "SUBTLE" or bStyle == "NONE" then
                chatEditBoxSkin.leftBar:SetColorTexture(0.392, 0.455, 0.545, 0.55) -- Slate #64748B
            else
                chatEditBoxSkin.leftBar:SetColorTexture(ar, ag, ab, 0.55)
            end
            chatEditBoxSkin.leftBar:SetShown(bgAlpha > 0.02)
        end
        if chatEditBoxSkin.promptHint then
            SetSafeFont(chatEditBoxSkin.promptHint, 10, "")
            chatEditBoxSkin.promptHint:SetText(GetDynamicEditBoxPromptHint(db))
            chatEditBoxSkin.promptHint:SetShown(bgAlpha > 0.02)
        end
    end
end

local function CollectAllChatFrames()
    local list = {}
    local seen = {}
    local maxBase = tonumber(_G.NUM_CHAT_WINDOWS) or 10
    if maxBase < 10 then maxBase = 10 end
    for i = 1, math.max(maxBase, 20) do
        local name = "ChatFrame" .. i
        local cf = _G[name]
        if cf and not seen[cf] then
            seen[cf] = true
            list[#list + 1] = { cf = cf, index = i, name = name }
        end
    end
    if type(_G.CHAT_FRAMES) == "table" then
        for _, frameName in ipairs(_G.CHAT_FRAMES) do
            if not IsSecretValue(frameName) and type(frameName) == "string" then
                local cf = _G[frameName]
                if cf and not seen[cf] then
                    seen[cf] = true
                    local idx = tonumber(frameName:match("^ChatFrame(%d+)$")) or (#list + 1)
                    list[#list + 1] = { cf = cf, index = idx, name = frameName }
                end
            end
        end
    end
    return list
end

local hookedSideClutterBtns = {}

local function SetSideClutterButtonSuppressed(btn, suppress)
    if not btn then return end
    if suppress then
        SetRegionAlphaSafe(btn, 0)
        if type(btn.EnableMouse) == "function" then
            pcall(btn.EnableMouse, btn, false)
        end
        if type(btn.Hide) == "function" then
            pcall(btn.Hide, btn)
        end
        if not hookedSideClutterBtns[btn] and type(btn.HookScript) == "function" then
            hookedSideClutterBtns[btn] = true
            btn:HookScript("OnShow", function(selfBtn)
                local db = EnsureDB()
                if not DynamicChat:IsExternalChatEngineLoaded() and db.enableSleekChatSkin ~= false and db.hideChatButtons ~= false then
                    SetRegionAlphaSafe(selfBtn, 0)
                    if type(selfBtn.EnableMouse) == "function" then
                        pcall(selfBtn.EnableMouse, selfBtn, false)
                    end
                    if type(selfBtn.Hide) == "function" then
                        pcall(selfBtn.Hide, selfBtn)
                    end
                end
            end)
        end
    else
        if type(btn.Show) == "function" then
            pcall(btn.Show, btn)
        end
        if type(btn.EnableMouse) == "function" then
            pcall(btn.EnableMouse, btn, true)
        end
        SetRegionAlphaSafe(btn, 1)
    end
end

local function HookSuppressOnShow(reg, clearTex)
    if not reg or hookedSuppressedRegions[reg] or type(reg.HookScript) ~= "function" then return end
    hookedSuppressedRegions[reg] = true
    reg:HookScript("OnShow", function(selfReg)
        if not DynamicChat:IsExternalChatEngineLoaded() and EnsureDB().enableSleekChatSkin ~= false then
            if clearTex and type(selfReg.SetTexture) == "function" then
                pcall(selfReg.SetTexture, selfReg, nil)
            end
            SetRegionAlphaSafe(selfReg, 0)
            if type(selfReg.Hide) == "function" then
                pcall(selfReg.Hide, selfReg)
            end
        end
    end)
end

local function SuppressBlizzardChatBackground(cf, cfName, skinEnabled)
    if not cf then return end
    cfName = cfName or (cf.GetName and cf:GetName()) or "ChatFrame1"
    local bg = _G[cfName .. "Background"] or cf.Background
    if bg then
        if skinEnabled then
            if type(bg.SetColorTexture) == "function" then
                pcall(bg.SetColorTexture, bg, 0, 0, 0, 0)
            end
            if type(bg.SetVertexColor) == "function" then
                pcall(bg.SetVertexColor, bg, 0, 0, 0, 0)
            end
            SetRegionAlphaSafe(bg, 0)
            if type(bg.Hide) == "function" then
                pcall(bg.Hide, bg)
            end
            HookSuppressOnShow(bg, false)
        else
            if type(bg.Show) == "function" then
                pcall(bg.Show, bg)
            end
            if type(bg.SetVertexColor) == "function" then
                pcall(bg.SetVertexColor, bg, 1, 1, 1, 0.25)
            end
            SetRegionAlphaSafe(bg, 0.25)
        end
    end

    for _, suffix in ipairs(CHAT_BORDER_SUFFIXES) do
        if suffix ~= "Background" then
            local tex = _G[cfName .. suffix] or cf[suffix]
            if tex then
                if skinEnabled then
                    if type(tex.SetTexture) == "function" then
                        pcall(tex.SetTexture, tex, nil)
                    end
                    StripTextureSafe(tex, true)
                    if type(tex.Hide) == "function" then
                        pcall(tex.Hide, tex)
                    end
                    HookSuppressOnShow(tex, true)
                else
                    if type(tex.Show) == "function" then
                        pcall(tex.Show, tex)
                    end
                    StripTextureSafe(tex, false)
                end
            end
        end
    end

    local resizeBtn = _G[cfName .. "ResizeButton"] or cf.ResizeButton
    if resizeBtn then
        if skinEnabled then
            SetRegionAlphaSafe(resizeBtn, 0)
            if type(resizeBtn.Hide) == "function" then
                pcall(resizeBtn.Hide, resizeBtn)
            end
            HookSuppressOnShow(resizeBtn, false)
        else
            SetRegionAlphaSafe(resizeBtn, 1)
        end
    end

    if cf.Background then
        SetRegionAlphaSafe(cf.Background, skinEnabled and 0 or 0.25)
        if skinEnabled and type(cf.Background.Hide) == "function" then
            pcall(cf.Background.Hide, cf.Background)
            HookSuppressOnShow(cf.Background, false)
        end
    end
    if cf.NineSlice then
        SetRegionAlphaSafe(cf.NineSlice, skinEnabled and 0 or 1)
        if skinEnabled and type(cf.NineSlice.Hide) == "function" then
            pcall(cf.NineSlice.Hide, cf.NineSlice)
            HookSuppressOnShow(cf.NineSlice, false)
        end
    end
    SetRegionAlphaSafe(_G[cfName .. "ButtonFrameBackground"], skinEnabled and 0 or 1)
end

local function GetScrollBarThumbFrame(sb)
    if not sb then return nil end
    if type(sb.GetThumb) == "function" then
        local ok, th = pcall(sb.GetThumb, sb)
        if ok and th then return th end
    end
    if sb.Track and sb.Track.Thumb then
        return sb.Track.Thumb
    end
    if sb.ThumbTexture then
        return sb.ThumbTexture
    end
    return nil
end

local function HideScrollBarDefaultArt(sb, thumb)
    if not sb then return end
    if sb.Background then StripTextureSafe(sb.Background, true) end
    if sb.Backplate then StripTextureSafe(sb.Backplate, true) end
    if sb.ThumbTexture then StripTextureSafe(sb.ThumbTexture, true) end
    if sb.Track then
        if sb.Track.Begin then StripTextureSafe(sb.Track.Begin, true) end
        if sb.Track.Middle then StripTextureSafe(sb.Track.Middle, true) end
        if sb.Track.End then StripTextureSafe(sb.Track.End, true) end
        if type(sb.Track.GetRegions) == "function" then
            for _, reg in ipairs({ sb.Track:GetRegions() }) do
                StripTextureSafe(reg, true)
            end
        end
    end
    if type(sb.GetRegions) == "function" then
        for _, reg in ipairs({ sb:GetRegions() }) do
            StripTextureSafe(reg, true)
        end
    end
    if thumb then
        -- Ensure MinimalScrollBar ThreeSliceButtonMixin always retains valid atlas names on Begin/Middle/End
        -- so C_Texture.GetAtlasInfo(self.Begin:GetAtlas()) in MinimalScrollBar.lua:55 never receives nil!
        if thumb.Begin and type(thumb.Begin.GetAtlas) == "function" and not thumb.Begin:GetAtlas() and type(thumb.upBeginTexture) == "string" then
            pcall(thumb.Begin.SetAtlas, thumb.Begin, thumb.upBeginTexture, true)
        end
        if thumb.Middle and type(thumb.Middle.GetAtlas) == "function" and not thumb.Middle:GetAtlas() and type(thumb.upMiddleTexture) == "string" then
            pcall(thumb.Middle.SetAtlas, thumb.Middle, thumb.upMiddleTexture, true)
        end
        if thumb.End and type(thumb.End.GetAtlas) == "function" and not thumb.End:GetAtlas() and type(thumb.upEndTexture) == "string" then
            pcall(thumb.End.SetAtlas, thumb.End, thumb.upEndTexture, true)
        end
        if thumb.Begin then StripTextureSafe(thumb.Begin, true) end
        if thumb.Middle then StripTextureSafe(thumb.Middle, true) end
        if thumb.End then StripTextureSafe(thumb.End, true) end
        if type(thumb.GetRegions) == "function" then
            for _, reg in ipairs({ thumb:GetRegions() }) do
                StripTextureSafe(reg, true)
            end
        end
    end
end

local function SafeIsRegionMouseOver(region)
    if not region or type(region.IsMouseOver) ~= "function" then return false end
    if type(region.IsVisible) == "function" then
        local okV, vis = pcall(region.IsVisible, region)
        if not okV or IsSecretValue(vis) or vis ~= true then return false end
    end
    local ok, over = pcall(region.IsMouseOver, region)
    if not ok or IsSecretValue(over) then return false end
    return over == true
end

local function IsChatAreaHovered(cf, entry)
    if not cf then return false end
    local csb = entry and entry.customScrollBar
    if csb then
        if csb._isDragging then return true end
        if SafeIsRegionMouseOver(csb) or SafeIsRegionMouseOver(csb.thumb) then
            return true
        end
    end
    if SafeIsRegionMouseOver(cf) then return true end
    if entry and entry.panel and SafeIsRegionMouseOver(entry.panel) then
        return true
    end
    local cfName = (type(cf.GetName) == "function") and cf:GetName() or nil
    if cfName then
        local ownTab = _G[cfName .. "Tab"]
        if SafeIsRegionMouseOver(ownTab) then return true end
        local ownEB = cf.editBox or _G[cfName .. "EditBox"]
        if SafeIsRegionMouseOver(ownEB) then return true end
    end
    if cf.isDocked then
        local cf1 = _G.ChatFrame1
        if cf1 then
            if SafeIsRegionMouseOver(cf1) then return true end
            local cf1Entry = chatSkinStore[cf1]
            if cf1Entry and cf1Entry.panel and SafeIsRegionMouseOver(cf1Entry.panel) then
                return true
            end
        end
        if type(_G.DOCKED_CHAT_FRAMES) == "table" then
            for _, dcf in ipairs(_G.DOCKED_CHAT_FRAMES) do
                if dcf then
                    local dName = (type(dcf.GetName) == "function") and dcf:GetName() or nil
                    if dName and SafeIsRegionMouseOver(_G[dName .. "Tab"]) then
                        return true
                    end
                end
            end
        end
        if SafeIsRegionMouseOver(_G.ChatFrame1EditBox) then return true end
    end
    local ebBar = EnsureSleekEditBoxBar and EnsureSleekEditBoxBar()
    if ebBar and SafeIsRegionMouseOver(ebBar) then
        return true
    end
    return false
end

local function GetChatScrollMetrics(cf)
    if not cf then return 0, 0, 0, 1, 1 end
    local function SafeChatNum(fn, argIdx)
        if type(fn) ~= "function" then return nil end
        local ok, r1, r2 = pcall(fn, cf)
        if not ok then return nil end
        local val = (argIdx == 2) and r2 or r1
        if val == nil or IsSecretValue(val) then return nil end
        return tonumber(val)
    end

    local numMsgs = SafeChatNum(cf.GetNumMessages) or 0
    if numMsgs < 0 then numMsgs = 0 end

    local curScroll = SafeChatNum(cf.GetScrollOffset) or SafeChatNum(cf.GetCurrentScroll) or 0
    if curScroll < 0 then curScroll = 0 end

    local visibleLines = SafeChatNum(cf.GetNumVisibleLines) or SafeChatNum(cf.GetNumLinesDisplayed)
    if not visibleLines or visibleLines < 1 then
        local cfHeight = SafeChatNum(cf.GetHeight) or 200
        if cfHeight < 14 then cfHeight = 200 end
        local fontSize = SafeChatNum(cf.GetFont, 2) or 14
        if fontSize < 6 then fontSize = 14 end
        local spacing = SafeChatNum(cf.GetSpacing) or 2
        if spacing < 0 then spacing = 2 end
        local lineH = math.max(8, fontSize + spacing)
        visibleLines = math.max(1, math.floor(cfHeight / lineH))
    end

    local maxScroll = SafeChatNum(cf.GetMaxScrollRange)
    if maxScroll == nil then
        maxScroll = math.max(0, numMsgs - visibleLines)
    elseif maxScroll < 0 then
        maxScroll = 0
    end
    if curScroll > maxScroll then
        maxScroll = curScroll
    end

    local totalLines = visibleLines + maxScroll
    local visRatio = (maxScroll > 0 and totalLines > 0) and math.min(1, visibleLines / totalLines) or 1
    return numMsgs, curScroll, maxScroll, visRatio, visibleLines
end

local function RefreshChatScrollBarVisibility(cf, isScrollActivity)
    if not cf then return end
    local entry = chatSkinStore[cf]
    if not entry then return end

    if DynamicChat:IsExternalChatEngineLoaded() or EnsureDB().enableSleekChatSkin == false then
        if entry.customScrollBar then
            entry.customScrollBar:Hide()
        end
        if entry.scrollThumbFrame then
            entry.scrollThumbFrame:Hide()
        end
        return
    end

    local sb = cf.ScrollBar
    if sb then
        local thumb = GetScrollBarThumbFrame(sb)
        HideScrollBarDefaultArt(sb, thumb)
        SetRegionAlphaSafe(sb, 0)
        if type(sb.EnableMouse) == "function" then pcall(sb.EnableMouse, sb, false) end
    end

    local csb = entry.customScrollBar
    if not csb then return end

    if not DynamicChat.SafeFrameIsShown(cf, false) or (cf.isDocked and _G.SELECTED_DOCK_FRAME and _G.SELECTED_DOCK_FRAME ~= cf) then
        csb:Hide()
        return
    end

    if isScrollActivity and csb.NotifyScrollActivity then
        csb:NotifyScrollActivity()
    end

    local _, curScroll, maxScroll, visRatio = GetChatScrollMetrics(cf)
    -- ScrollingMessageFrame GetScrollOffset() is 0 at bottom and maxScroll at top; invert for top-down scrollbar
    csb:UpdateState(maxScroll - curScroll, maxScroll, visRatio)
end

local function ReskinChatScrollBarAndBottomButton(cf, entry, skinEnabled)
    if not cf or not entry then return end

    -- 1. Hide cf.ScrollToBottomButton completely (Left Utility Rail already provides the Scroll-to-Bottom chevron)
    local stb = cf.ScrollToBottomButton
    if stb then
        if skinEnabled then
            SetRegionAlphaSafe(stb, 0)
            if type(stb.Hide) == "function" then pcall(stb.Hide, stb) end
            if not hookedScrollToBottomBtns[stb] and type(stb.HookScript) == "function" then
                hookedScrollToBottomBtns[stb] = true
                stb:HookScript("OnShow", function(selfBtn)
                    if not DynamicChat:IsExternalChatEngineLoaded() and EnsureDB().enableSleekChatSkin ~= false then
                        SetRegionAlphaSafe(selfBtn, 0)
                        if type(selfBtn.Hide) == "function" then pcall(selfBtn.Hide, selfBtn) end
                    end
                end)
            end
        else
            SetRegionAlphaSafe(stb, 1)
        end
    end

    -- 2. Suppress Blizzard's stock ScrollBar and attach our unified custom DynamicSuite scrollbar
    local sb = cf.ScrollBar
    if sb then
        if not skinEnabled then
            SetRegionAlphaSafe(sb, 1)
            if type(sb.EnableMouse) == "function" then pcall(sb.EnableMouse, sb, true) end
        else
            for _, arrowBtn in ipairs({ sb.Back, sb.Forward, sb.ScrollUpButton, sb.ScrollDownButton }) do
                if arrowBtn then
                    SetRegionAlphaSafe(arrowBtn, 0)
                    if type(arrowBtn.EnableMouse) == "function" then pcall(arrowBtn.EnableMouse, arrowBtn, false) end
                    if type(arrowBtn.Hide) == "function" then pcall(arrowBtn.Hide, arrowBtn) end
                    if not hookedScrollArrows[arrowBtn] and type(arrowBtn.HookScript) == "function" then
                        hookedScrollArrows[arrowBtn] = true
                        arrowBtn:HookScript("OnShow", function(selfArr)
                            if not DynamicChat:IsExternalChatEngineLoaded() and EnsureDB().enableSleekChatSkin ~= false then
                                SetRegionAlphaSafe(selfArr, 0)
                                if type(selfArr.Hide) == "function" then pcall(selfArr.Hide, selfArr) end
                            end
                        end)
                    end
                end
            end
            local thumb = GetScrollBarThumbFrame(sb)
            HideScrollBarDefaultArt(sb, thumb)
            SetRegionAlphaSafe(sb, 0)
            if type(sb.EnableMouse) == "function" then pcall(sb.EnableMouse, sb, false) end
        end
    end

    if not skinEnabled then
        if entry.customScrollBar then entry.customScrollBar:Hide() end
        if entry.scrollThumbFrame then entry.scrollThumbFrame:Hide() end
        return
    end

    local hostPanel = entry.panel or (cf.isDocked and _G.ChatFrame1 and chatSkinStore[_G.ChatFrame1] and chatSkinStore[_G.ChatFrame1].panel) or cf
    local targetStrata = (type(cf.GetFrameStrata) == "function" and cf:GetFrameStrata()) or "LOW"
    local targetLevel = ((type(cf.GetFrameLevel) == "function" and cf:GetFrameLevel()) or 2) + 12
    if not entry.customScrollBar then
        entry.customScrollBar = CreateDynamicChatScrollbar(hostPanel, {
            width = 5,
            strata = targetStrata,
            frameLevel = targetLevel,
            autoHide = true,
            isHoveredFn = function()
                return IsChatAreaHovered(cf, entry)
            end,
            onValueChanged = function(newVal)
                if type(cf.SetScrollOffset) ~= "function" or entry._syncingScrollBar then return end
                entry._syncingScrollBar = true
                local _, _, maxScroll = GetChatScrollMetrics(cf)
                if maxScroll <= 0 and entry.customScrollBar and (entry.customScrollBar._maxValue or 0) > 0 then
                    maxScroll = entry.customScrollBar._maxValue
                end
                local targetOffset = math.max(0, math.min(maxScroll, math.floor(maxScroll - newVal + 0.5)))
                pcall(cf.SetScrollOffset, cf, targetOffset)
                if cf.ScrollBar and type(cf.ScrollBar.SetScrollPercentage) == "function" and maxScroll > 0 then
                    local pct = math.max(0, math.min(1, newVal / maxScroll))
                    pcall(cf.ScrollBar.SetScrollPercentage, cf.ScrollBar, pct)
                end
                entry._syncingScrollBar = false
                RefreshChatScrollBarVisibility(cf, true)
            end,
            onMouseWheel = function(delta)
                if not delta or IsSecretValue(delta) then return end
                if delta > 0 and type(cf.ScrollUp) == "function" then
                    pcall(cf.ScrollUp, cf)
                elseif delta < 0 and type(cf.ScrollDown) == "function" then
                    pcall(cf.ScrollDown, cf)
                end
                RefreshChatScrollBarVisibility(cf, true)
            end,
        })
    elseif entry.customScrollBar:GetParent() ~= hostPanel then
        entry.customScrollBar:SetParent(hostPanel)
    end
    entry.customScrollBar._hoverCheckFn = function()
        return IsChatAreaHovered(cf, entry)
    end

    local csb = entry.customScrollBar
    csb:SetFrameStrata(targetStrata)
    csb:SetFrameLevel(targetLevel)
    if csb.thumb then
        csb.thumb:SetFrameStrata(targetStrata)
        csb.thumb:SetFrameLevel(targetLevel + 2)
    end
    csb:ClearAllPoints()
    csb:SetPoint("TOPRIGHT", cf, "TOPRIGHT", 6, -2)
    csb:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 6, 2)

    if not hookedScrollBars[cf] then
        hookedScrollBars[cf] = true
        if type(cf.HookScript) == "function" then
            cf:HookScript("OnShow", function(selfCF) RefreshChatScrollBarVisibility(selfCF, false) end)
            cf:HookScript("OnHide", function(selfCF) RefreshChatScrollBarVisibility(selfCF, false) end)
            cf:HookScript("OnSizeChanged", function(selfCF) RefreshChatScrollBarVisibility(selfCF, false) end)
            cf:HookScript("OnMouseWheel", function(selfCF) RefreshChatScrollBarVisibility(selfCF, true) end)
        end
        for _, fnName in ipairs({ "ScrollUp", "ScrollDown", "ScrollToTop", "ScrollToBottom", "PageUp", "PageDown", "SetScrollOffset", "UpdateVisibleLines" }) do
            if type(cf[fnName]) == "function" then
                hooksecurefunc(cf, fnName, function(selfCF)
                    RefreshChatScrollBarVisibility(selfCF, true)
                end)
            end
        end
        if type(cf.AddMessage) == "function" then
            hooksecurefunc(cf, "AddMessage", function(selfCF)
                RefreshChatScrollBarVisibility(selfCF, false)
            end)
        end
    end

    RefreshChatScrollBarVisibility(cf, false)
end

local function StripBlizzardTabTextures(tab, tabName, skinEnabled)
    if not tab then return end
    for _, tSuffix in ipairs(CHAT_TAB_TEXTURE_SUFFIXES) do
        local gTex = _G[tabName .. tSuffix]
        if gTex then StripTextureSafe(gTex, skinEnabled) end
        if tab[tSuffix] then StripTextureSafe(tab[tSuffix], skinEnabled) end
    end
    if type(tab.GetHighlightTexture) == "function" then
        local ok, ht = pcall(tab.GetHighlightTexture, tab)
        if ok and ht then StripTextureSafe(ht, skinEnabled) end
    end
    -- Completely suppress Blizzard's rounded middle tab glow/flash textures (e.g. ChatFrame*TabGlow)
    -- so unread whispers use our sleek full-width tabCell/tabLine highlight instead of a rounded lump.
    for _, glowReg in ipairs({ _G[tabName .. "Glow"], tab.glow, tab.Glow, _G[tabName .. "Flash"], tab.flash, tab.Flash }) do
        if glowReg then
            if skinEnabled then
                if type(glowReg.SetTexture) == "function" then
                    pcall(glowReg.SetTexture, glowReg, nil)
                end
                StripTextureSafe(glowReg, true)
                if type(glowReg.Hide) == "function" then
                    pcall(glowReg.Hide, glowReg)
                end
                HookSuppressOnShow(glowReg, true)
            else
                StripTextureSafe(glowReg, false)
            end
        end
    end
end

local function IsChatTabAlerting(cf, tab, tabName, entry)
    if not cf then return false end
    if _G.SELECTED_DOCK_FRAME == cf then
        if entry then entry.isAlerting = false end
        return false
    end
    if entry and entry.isAlerting then
        return true
    end
    if not IsSecretValue(cf.alerting) and cf.alerting == true then
        return true
    end
    if type(_G.UIFrameIsFlashing) == "function" then
        local glowReg = (tab and (tab.glow or tab.Glow)) or (tabName and _G[tabName .. "Glow"])
        if glowReg then
            local ok, flashing = pcall(_G.UIFrameIsFlashing, glowReg)
            if ok and flashing == true then
                return true
            end
        end
    end
    return false
end

-- Forward declarations for tab bar scrolling & navigation
local tabScrollOffset = 1
local lastMaxStartIdx = 1
local lastFirstVisIdx = 1
local lastLastVisIdx  = 1
local lastDockedTabsSnapshot = {}
local pendingEnsureSelectedTabVisible = nil
local OnTabBarMouseWheel
local ScrollDockedTabViewport
local CycleSelectedDockTab
local RefreshTabNavButtonsVisuals

local function StyleSingleChatTab(cf, tab, cfName, skinEnabled, syncFont, fontPath, ar, ag, ab)
    if not cf or not tab then return end
    local entry = chatSkinStore[cf]
    if not entry then
        entry = {}
        chatSkinStore[cf] = entry
    end

    local tabName = cfName .. "Tab"
    StripBlizzardTabTextures(tab, tabName, skinEnabled)

    if skinEnabled and not hookedChatTabs[tab] and tab.HookScript then
        hookedChatTabs[tab] = cf
        if tab.RegisterForClicks then
            pcall(tab.RegisterForClicks, tab, "LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
        end
        if tab.EnableMouseWheel then
            pcall(tab.EnableMouseWheel, tab, true)
        end
        tab:HookScript("OnShow", function(selfTab)
            local ownerCF = hookedChatTabs[selfTab]
            if not ownerCF or DynamicChat:IsExternalChatEngineLoaded() or EnsureDB().enableSleekChatSkin == false then return end
            local ownerEntry = chatSkinStore[ownerCF]
            if ownerEntry and ownerEntry.hiddenByScroll then
                if not (InCombatLockdown and InCombatLockdown()) and type(selfTab.ClearAllPoints) == "function" then
                    pcall(selfTab.ClearAllPoints, selfTab)
                end
                if type(selfTab.Hide) == "function" then
                    pcall(selfTab.Hide, selfTab)
                end
                if ownerEntry.tabCell then ownerEntry.tabCell:Hide() end
                if ownerEntry.tabLine then ownerEntry.tabLine:Hide() end
            end
        end)
        tab:HookScript("OnMouseWheel", function(selfTab, delta)
            if OnTabBarMouseWheel then
                OnTabBarMouseWheel(selfTab, delta)
            end
        end)
        tab:HookScript("OnClick", function(selfTab, button)
            if button == "MiddleButton" then
                local ownerCF = hookedChatTabs[selfTab]
                if ownerCF and ownerCF.isTemporary and type(_G.FCF_Close) == "function" then
                    pcall(_G.FCF_Close, ownerCF)
                end
            end
        end)
        tab:HookScript("OnEnter", function(selfTab)
            local ownerCF = hookedChatTabs[selfTab]
            if not ownerCF or DynamicChat:IsExternalChatEngineLoaded() or EnsureDB().enableSleekChatSkin == false then return end
            local a1, a2, a3 = GetSuiteAccent()
            StyleSingleChatTab(ownerCF, selfTab, ownerCF:GetName() or "ChatFrame1", true, EnsureDB().applySuiteChatFont ~= false, GetFontPath(), a1, a2, a3)
            if _G.GameTooltip then
                local ownerEntry = chatSkinStore[ownerCF]
                local tabFS = (selfTab.GetFontString and selfTab:GetFontString()) or selfTab.Text
                local rawLabel = (ownerEntry and ownerEntry.fullTabLabel) or (tabFS and tabFS.GetText and tabFS:GetText()) or (ownerCF.name) or "Chat Tab"
                if not IsSecretValue(rawLabel) and type(rawLabel) == "string" and rawLabel ~= "" then
                    _G.GameTooltip:SetOwner(selfTab, "ANCHOR_TOP")
                    _G.GameTooltip:ClearLines()
                    _G.GameTooltip:AddLine(rawLabel, 1, 1, 1)
                    if ownerCF.isTemporary then
                        _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", "Switch to Whisper Tab", "34D399"), 0.886, 0.910, 0.941)
                        _G.GameTooltip:AddLine(FormatTooltipCmd("Middle-Click:", "Close Whisper Tab", "F87171"), 0.886, 0.910, 0.941)
                    else
                        _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", "Switch to Chat Tab", "34D399"), 0.886, 0.910, 0.941)
                    end
                    _G.GameTooltip:AddLine(FormatTooltipCmd("Scroll Up / Down:", "Scroll Tabs Left / Right", "F59E0B"), 0.886, 0.910, 0.941)
                    _G.GameTooltip:AddLine(FormatTooltipCmd("Right-Click:", "Tab Options Menu", "38BDF8"), 0.886, 0.910, 0.941)
                    _G.GameTooltip:Show()
                end
            end
        end)
        tab:HookScript("OnLeave", function(selfTab)
            local ownerCF = hookedChatTabs[selfTab]
            if _G.GameTooltip and _G.GameTooltip:GetOwner() == selfTab then
                _G.GameTooltip:Hide()
            end
            if not ownerCF or DynamicChat:IsExternalChatEngineLoaded() or EnsureDB().enableSleekChatSkin == false then return end
            local a1, a2, a3 = GetSuiteAccent()
            StyleSingleChatTab(ownerCF, selfTab, ownerCF:GetName() or "ChatFrame1", true, EnsureDB().applySuiteChatFont ~= false, GetFontPath(), a1, a2, a3)
        end)
    end

    -- If this tab is currently scrolled outside the visible Top Tab Header Bar viewport, keep it and its cells hidden!
    if skinEnabled and entry.hiddenByScroll then
        if not (InCombatLockdown and InCombatLockdown()) and type(tab.ClearAllPoints) == "function" then
            pcall(tab.ClearAllPoints, tab)
        end
        if DynamicChat.SafeFrameIsShown(tab, false) then
            pcall(tab.Hide, tab)
        end
        if entry.tabCell then entry.tabCell:Hide() end
        if entry.tabLine then entry.tabLine:Hide() end
        return
    end

    -- Detect temporary Whisper / Battle.net Whisper conversation tabs (e.g. ChatFrame11+)
    local chatType = (not IsSecretValue(cf.chatType) and type(cf.chatType) == "string") and cf.chatType or nil
    local isBNWhisperTab = (chatType == "BN_WHISPER" or chatType == "BN_CONVERSATION")
    local isWhisperTab   = isBNWhisperTab or (chatType == "WHISPER") or (cf.isTemporary == true)
    local isAlertingTab  = IsChatTabAlerting(cf, tab, tabName, entry)

    local convIcon = tab.conversationIcon or _G[tabName .. "ConversationIcon"]
    if convIcon then
        if skinEnabled and convIcon.SetVertexColor then
            if isBNWhisperTab then
                pcall(convIcon.SetVertexColor, convIcon, 0.49, 0.83, 0.99, 0.95) -- Crisp BNet Ice-Blue
            else
                pcall(convIcon.SetVertexColor, convIcon, 0.96, 0.82, 1.00, 0.95) -- Crisp Whisper Orchid-Pink
            end
        elseif not skinEnabled and convIcon.SetVertexColor then
            pcall(convIcon.SetVertexColor, convIcon, 1, 1, 1, 1)
        end
    end

    -- Prevent Blizzard's FCFTab_UpdateAlpha from dimming unselected tab text to 20%-40% alpha
    -- and ensure the entire tab cell is 100% clickable & mousewheel-scrollable at LOW strata Level 15
    if skinEnabled then
        if tab.SetAlpha then pcall(tab.SetAlpha, tab, 1.0) end
        if tab.SetHitRectInsets then pcall(tab.SetHitRectInsets, tab, 0, 0, 0, 0) end
        if tab.EnableMouse then pcall(tab.EnableMouse, tab, true) end
        if tab.EnableMouseWheel then pcall(tab.EnableMouseWheel, tab, true) end
        if tab.SetFrameStrata then pcall(tab.SetFrameStrata, tab, "LOW") end
        if tab.SetFrameLevel then pcall(tab.SetFrameLevel, tab, 15) end
    end

    local fs = tab.Text or _G[tabName .. "Text"] or (tab.GetFontString and tab:GetFontString())
    local isSelectedTab = (_G.SELECTED_DOCK_FRAME == cf) or (not cf.isDocked and DynamicChat.SafeFrameIsShown(cf, false))
    local isHoveredTab  = SafeIsRegionMouseOver(tab)

    if skinEnabled and (cf == _G.ChatFrame1 or cf.isDocked) then
        fs = ResolveChatTabLabel(cf, tab, tabName, entry) or fs
        if isWhisperTab and convIcon then
            if fs then
                pcall(function()
                    fs:ClearAllPoints()
                    fs:SetWidth(0)
                    fs:SetPoint("LEFT", tab, "LEFT", 20, 0)
                    fs:SetPoint("RIGHT", tab, "RIGHT", -5, 0)
                    fs:SetJustifyH("LEFT")
                    if fs.SetJustifyV then fs:SetJustifyV("MIDDLE") end
                    fs:SetWordWrap(false)
                end)
            end
            pcall(function()
                convIcon:ClearAllPoints()
                convIcon:SetSize(11, 11)
                convIcon:SetPoint("LEFT", tab, "LEFT", 6, 0)
                convIcon:Show()
            end)
        else
            if convIcon and not isWhisperTab and type(convIcon.Hide) == "function" then
                pcall(convIcon.Hide, convIcon)
            end
            if fs then
                pcall(function()
                    fs:ClearAllPoints()
                    fs:SetWidth(0)
                    fs:SetPoint("LEFT", tab, "LEFT", 5, 0)
                    fs:SetPoint("RIGHT", tab, "RIGHT", -5, 0)
                    fs:SetJustifyH("CENTER")
                    if fs.SetJustifyV then fs:SetJustifyV("MIDDLE") end
                    fs:SetWordWrap(false)
                end)
            end
        end
    end

    if fs then
        if syncFont and fs.SetFont then
            pcall(fs.SetFont, fs, fontPath, 11, "")
        end
        if fs.SetWordWrap then
            pcall(fs.SetWordWrap, fs, false)
        end
        if fs.SetShadowColor and fs.SetShadowOffset then
            pcall(fs.SetShadowColor, fs, 0, 0, 0, 0.95)
            pcall(fs.SetShadowOffset, fs, 1, -1)
        end
        if skinEnabled and fs.SetTextColor then
            if isSelectedTab or isHoveredTab or isAlertingTab then
                fs:SetTextColor(0.98, 0.99, 1.00, 1.00) -- #F8FAFC Crisp White
            elseif isBNWhisperTab then
                fs:SetTextColor(0.56, 0.88, 1.00, 1.00) -- #8FE0FF High-Contrast BNet Cyan
            elseif isWhisperTab then
                fs:SetTextColor(0.97, 0.82, 1.00, 1.00) -- #F8D0FF High-Contrast Whisper Lavender-Pink
            else
                fs:SetTextColor(0.58, 0.64, 0.72, 0.95) -- #94A3B8 Muted Slate
            end
        end
    end

    if skinEnabled and DynamicChat.SafeFrameIsShown(tab, false) then
        if not entry.tabCell then
            local tc = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            tc:SetFrameStrata("BACKGROUND")
            tc:SetFrameLevel(3)
            tc:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            local rDiv = tc:CreateTexture(nil, "BORDER")
            rDiv:SetWidth(1)
            rDiv:SetPoint("TOPRIGHT", tc, "TOPRIGHT", 0, 0)
            rDiv:SetPoint("BOTTOMRIGHT", tc, "BOTTOMRIGHT", 0, 0)
            rDiv:SetColorTexture(1, 1, 1, 0.06)
            DisableTexPixelSnap(rDiv)
            tc.rightDiv = rDiv
            entry.tabCell = tc
        end
        local tc = entry.tabCell
        tc:SetFrameStrata("BACKGROUND")
        tc:SetFrameLevel(3)
        local hostCF = (cf.isDocked and _G.ChatFrame1) or cf
        local hostScale = (hostCF and hostCF.GetScale and hostCF:GetScale()) or 1.0
        if tc.SetScale then pcall(tc.SetScale, tc, hostScale) end
        tc:ClearAllPoints()
        tc:SetPoint("LEFT", tab, "LEFT", 0, 0)
        tc:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
        if hostCF then
            tc:SetPoint("TOP", hostCF, "TOP", 0, 28)
            tc:SetPoint("BOTTOM", hostCF, "TOP", 0, 4)
        else
            tc:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
            tc:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
        end
        if isSelectedTab then
            tc:SetBackdropColor(0.08, 0.09, 0.12, 0.55) -- #14171F Active Tab Fill
        elseif isHoveredTab then
            tc:SetBackdropColor(0.08, 0.09, 0.12, 0.45)
        elseif isAlertingTab then
            if isBNWhisperTab then
                tc:SetBackdropColor(0.22, 0.74, 0.97, 0.24)
            elseif isWhisperTab then
                tc:SetBackdropColor(0.91, 0.47, 0.98, 0.24)
            else
                tc:SetBackdropColor(ar, ag, ab, 0.22)
            end
        elseif isBNWhisperTab then
            tc:SetBackdropColor(0.22, 0.74, 0.97, 0.10)
        elseif isWhisperTab then
            tc:SetBackdropColor(0.91, 0.47, 0.98, 0.10)
        else
            tc:SetBackdropColor(0.02, 0.025, 0.035, 0.35) -- Subtle Smoked Inactive Fill
        end
        tc:Show()

        if not entry.tabLine then
            local tl = CreateFrame("Frame", nil, UIParent)
            tl:SetFrameStrata("BACKGROUND")
            tl:SetFrameLevel(5)
            tl:SetHeight(2)
            tl.tex = tl:CreateTexture(nil, "OVERLAY")
            tl.tex:SetAllPoints()
            DisableTexPixelSnap(tl.tex)
            entry.tabLine = tl
        end
        local tl = entry.tabLine
        tl:SetFrameStrata("BACKGROUND")
        tl:SetFrameLevel(5)
        if tl.SetScale then pcall(tl.SetScale, tl, hostScale) end
        tl:ClearAllPoints()
        tl:SetPoint("BOTTOMLEFT", tc, "BOTTOMLEFT", 0, 0)
        tl:SetPoint("BOTTOMRIGHT", tc, "BOTTOMRIGHT", 0, 0)
        if isSelectedTab or isAlertingTab then
            tl:SetHeight(2)
            if isBNWhisperTab then
                tl.tex:SetColorTexture(0.22, 0.74, 0.97, 1.0) -- #38BDF8 BNet Cyan
            elseif isWhisperTab then
                tl.tex:SetColorTexture(0.91, 0.47, 0.98, 1.0) -- #E879F9 Whisper Orchid-Pink
            else
                tl.tex:SetColorTexture(ar, ag, ab, 1.0)
            end
            tl:Show()
        elseif isWhisperTab then
            tl:SetHeight(1.5)
            if isBNWhisperTab then
                tl.tex:SetColorTexture(0.22, 0.74, 0.97, 0.75)
            else
                tl.tex:SetColorTexture(0.91, 0.47, 0.98, 0.75)
            end
            tl:Show()
        else
            tl:Hide()
        end
    else
        if entry.tabCell then entry.tabCell:Hide() end
        if entry.tabLine then entry.tabLine:Hide() end
    end
end

-- Scrollable & Paginated Top Chat Tab Bar Engine + Left (<) & Right (>) Navigation Buttons:
-- Keeps every chat tab at a comfortable, fully readable width even when 10-20 whisper tabs are open,
-- and provides Mousewheel Up (Left) / Down (Right) scrolling plus Left (<) and Right (>) assist buttons.
local isLayingOutDockedTabs = false
local LayoutDockedChatTabs

ScrollDockedTabViewport = function(deltaSteps)
    local total = #lastDockedTabsSnapshot
    if total <= 1 then return end
    local target = math.max(1, math.min(lastMaxStartIdx, tabScrollOffset + deltaSteps))
    if target ~= tabScrollOffset then
        tabScrollOffset = target
        local ar, ag, ab = GetSuiteAccent()
        LayoutDockedChatTabs(EnsureDB().enableSleekChatSkin ~= false, EnsureDB().applySuiteChatFont ~= false, GetFontPath(), ar, ag, ab)
    end
end

CycleSelectedDockTab = function(deltaDir)
    local total = #lastDockedTabsSnapshot
    if total <= 1 then return end
    local curCF = _G.SELECTED_DOCK_FRAME or _G.ChatFrame1
    local curIdx = 1
    for i, item in ipairs(lastDockedTabsSnapshot) do
        if item.cf == curCF then
            curIdx = i
            break
        end
    end
    local nextIdx = curIdx + deltaDir
    -- Skip ChatFrame2 (Combat Log) when cycling with wheel/arrows if another tab exists after it,
    -- so rapid tab cycling never pauses on the Combat Log unless it is the target edge tab.
    if nextIdx >= 1 and nextIdx <= total and lastDockedTabsSnapshot[nextIdx] and lastDockedTabsSnapshot[nextIdx].cf == _G.ChatFrame2 then
        local skipIdx = nextIdx + deltaDir
        if skipIdx >= 1 and skipIdx <= total then
            nextIdx = skipIdx
        end
    end
    nextIdx = math.max(1, math.min(total, nextIdx))
    local targetItem = lastDockedTabsSnapshot[nextIdx]
    if targetItem and targetItem.cf then
        pendingEnsureSelectedTabVisible = targetItem.cf
        if type(_G.FCF_SelectDockFrame) == "function" then
            pcall(_G.FCF_SelectDockFrame, targetItem.cf)
        end
        local ar, ag, ab = GetSuiteAccent()
        LayoutDockedChatTabs(EnsureDB().enableSleekChatSkin ~= false, EnsureDB().applySuiteChatFont ~= false, GetFontPath(), ar, ag, ab)
    end
end

RefreshTabNavButtonsVisuals = function(ar, ag, ab)
    if not tabNavFrame or not tabNavFrame:IsShown() then return end
    local total = #lastDockedTabsSnapshot
    local hiddenLeft  = math.max(0, lastFirstVisIdx - 1)
    local hiddenRight = math.max(0, total - lastLastVisIdx)

    local leftAlertType  = nil
    local rightAlertType = nil
    for i = 1, lastFirstVisIdx - 1 do
        local item = lastDockedTabsSnapshot[i]
        if item and item.cf then
            local entry = chatSkinStore[item.cf]
            if IsChatTabAlerting(item.cf, item.tab, (item.name or "") .. "Tab", entry) then
                local ct = (not IsSecretValue(item.cf.chatType) and type(item.cf.chatType) == "string") and item.cf.chatType or nil
                leftAlertType = (ct == "BN_WHISPER" or ct == "BN_CONVERSATION") and "BNET" or "WHISPER"
                break
            end
        end
    end
    for i = lastLastVisIdx + 1, total do
        local item = lastDockedTabsSnapshot[i]
        if item and item.cf then
            local entry = chatSkinStore[item.cf]
            if IsChatTabAlerting(item.cf, item.tab, (item.name or "") .. "Tab", entry) then
                local ct = (not IsSecretValue(item.cf.chatType) and type(item.cf.chatType) == "string") and item.cf.chatType or nil
                rightAlertType = (ct == "BN_WHISPER" or ct == "BN_CONVERSATION") and "BNET" or "WHISPER"
                break
            end
        end
    end

    local function UpdateSingleNavBtn(btn, hiddenCount, alertType)
        if not btn then return end
        local isHovered = (btn.IsMouseOver and btn:IsMouseOver()) and true or false
        if isHovered then
            btn:SetBackdropColor(0.08, 0.09, 0.12, 0.72)
            btn.arrowTex:SetVertexColor(1.0, 1.0, 1.0, 1.0)
        elseif alertType == "BNET" then
            btn:SetBackdropColor(0.22, 0.74, 0.97, 0.22)
            btn.arrowTex:SetVertexColor(0.56, 0.88, 1.00, 1.0)
        elseif alertType == "WHISPER" then
            btn:SetBackdropColor(0.91, 0.47, 0.98, 0.22)
            btn.arrowTex:SetVertexColor(0.97, 0.82, 1.00, 1.0)
        elseif hiddenCount > 0 then
            btn:SetBackdropColor(0.04, 0.05, 0.07, 0.55)
            btn.arrowTex:SetVertexColor(ar, ag, ab, 1.0)
        elseif lastMaxStartIdx <= 1 then
            btn:SetBackdropColor(0.02, 0.025, 0.035, 0.35)
            btn.arrowTex:SetVertexColor(0.64, 0.70, 0.78, 0.85)
        else
            btn:SetBackdropColor(0.02, 0.025, 0.035, 0.30)
            btn.arrowTex:SetVertexColor(0.42, 0.47, 0.55, 0.45)
        end

        if btn.bottomLine then
            if alertType == "BNET" then
                btn.bottomLine:SetHeight(2)
                btn.bottomLine:SetColorTexture(0.22, 0.74, 0.97, 1.0)
                btn.bottomLine:Show()
            elseif alertType == "WHISPER" then
                btn.bottomLine:SetHeight(2)
                btn.bottomLine:SetColorTexture(0.91, 0.47, 0.98, 1.0)
                btn.bottomLine:Show()
            elseif hiddenCount > 0 then
                btn.bottomLine:SetHeight(1.5)
                btn.bottomLine:SetColorTexture(ar, ag, ab, 0.85)
                btn.bottomLine:Show()
            else
                btn.bottomLine:Hide()
            end
        end
    end

    UpdateSingleNavBtn(tabNavFrame.leftBtn, hiddenLeft, leftAlertType)
    UpdateSingleNavBtn(tabNavFrame.rightBtn, hiddenRight, rightAlertType)
end

OnTabBarMouseWheel = function(_, delta)
    if not delta or delta == 0 then return end
    -- Scroll Up (delta > 0) = Left (-1), Scroll Down (delta < 0) = Right (+1)
    local dir = (delta > 0) and -1 or 1
    local step = (IsShiftKeyDown and IsShiftKeyDown()) and (dir * 3) or dir
    if (IsControlKeyDown and IsControlKeyDown()) or lastMaxStartIdx <= 1 then
        CycleSelectedDockTab(dir)
    else
        local prevOffset = tabScrollOffset
        ScrollDockedTabViewport(step)
        if tabScrollOffset == prevOffset then
            CycleSelectedDockTab(dir)
        end
    end
    local a1, a2, a3 = GetSuiteAccent()
    LayoutDockedChatTabs(EnsureDB().enableSleekChatSkin ~= false, EnsureDB().applySuiteChatFont ~= false, GetFontPath(), a1, a2, a3)
    RefreshTabNavButtonsVisuals(a1, a2, a3)
end

local function ShowTabNavTooltip(btn, isLeft)
    if not _G.GameTooltip then return end
    local total = #lastDockedTabsSnapshot
    local hiddenLeft  = math.max(0, lastFirstVisIdx - 1)
    local hiddenRight = math.max(0, total - lastLastVisIdx)

    _G.GameTooltip:SetOwner(btn, "ANCHOR_TOP")
    _G.GameTooltip:ClearLines()
    if isLeft then
        _G.GameTooltip:AddLine("Scroll Chat Tabs Left (<)", 1, 1, 1)
    else
        _G.GameTooltip:AddLine("Scroll Chat Tabs Right (>)", 1, 1, 1)
    end
    _G.GameTooltip:AddLine(string.format("Showing Tabs %d-%d of %d", lastFirstVisIdx, lastLastVisIdx, total), 0.58, 0.64, 0.72)

    if isLeft and hiddenLeft > 0 then
        local names = {}
        for i = 1, lastFirstVisIdx - 1 do
            local item = lastDockedTabsSnapshot[i]
            if item and item.cf then
                local entry = chatSkinStore[item.cf]
                local lbl = (entry and entry.fullTabLabel) or (item.cf.name) or item.name or "Tab"
                if not IsSecretValue(lbl) and type(lbl) == "string" then
                    names[#names + 1] = lbl
                end
            end
        end
        if #names > 0 then
            _G.GameTooltip:AddLine("Hidden Left (" .. hiddenLeft .. "): " .. table.concat(names, ", "), 0.96, 0.82, 1.00, true)
        end
    elseif (not isLeft) and hiddenRight > 0 then
        local names = {}
        for i = lastLastVisIdx + 1, total do
            local item = lastDockedTabsSnapshot[i]
            if item and item.cf then
                local entry = chatSkinStore[item.cf]
                local lbl = (entry and entry.fullTabLabel) or (item.cf.name) or item.name or "Tab"
                if not IsSecretValue(lbl) and type(lbl) == "string" then
                    names[#names + 1] = lbl
                end
            end
        end
        if #names > 0 then
            _G.GameTooltip:AddLine("Hidden Right (" .. hiddenRight .. "): " .. table.concat(names, ", "), 0.96, 0.82, 1.00, true)
        end
    end

    if isLeft then
        _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click / Scroll Up:", "Scroll Tabs Left", "34D399"), 0.886, 0.910, 0.941)
        _G.GameTooltip:AddLine(FormatTooltipCmd("Shift + Click:", "Jump to First Tab", "F59E0B"), 0.886, 0.910, 0.941)
        _G.GameTooltip:AddLine(FormatTooltipCmd("Right-Click:", "Previous Chat Screen", "38BDF8"), 0.886, 0.910, 0.941)
    else
        _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click / Scroll Down:", "Scroll Tabs Right", "34D399"), 0.886, 0.910, 0.941)
        _G.GameTooltip:AddLine(FormatTooltipCmd("Shift + Click:", "Jump to Last Tab", "F59E0B"), 0.886, 0.910, 0.941)
        _G.GameTooltip:AddLine(FormatTooltipCmd("Right-Click:", "Next Chat Screen", "38BDF8"), 0.886, 0.910, 0.941)
    end
    _G.GameTooltip:Show()
end

local function EnsureTabNavButtons()
    if tabNavFrame then return tabNavFrame end

    local nav = CreateFrame("Frame", nil, UIParent)
    nav:SetFrameStrata("LOW")
    nav:SetFrameLevel(18)
    nav:SetSize(38, 24)
    nav:EnableMouse(true)
    nav:EnableMouseWheel(true)
    nav:SetScript("OnMouseWheel", OnTabBarMouseWheel)

    local function CreateNavBtn(isLeft)
        local btn = CreateFrame("Button", nil, nav, "BackdropTemplate")
        btn:SetSize(19, 24)
        btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:EnableMouseWheel(true)
        btn:SetScript("OnMouseWheel", OnTabBarMouseWheel)

        local lDiv = btn:CreateTexture(nil, "BORDER")
        lDiv:SetWidth(1)
        lDiv:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        lDiv:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
        lDiv:SetColorTexture(1, 1, 1, 0.08)
        DisableTexPixelSnap(lDiv)
        btn.leftDiv = lDiv

        local tex = btn:CreateTexture(nil, "OVERLAY")
        tex:SetSize(10, 10)
        tex:SetPoint("CENTER", btn, "CENTER", 0, 0)
        tex:SetTexture(ICON_CHEVRON_UP)
        tex:SetRotation(isLeft and math.rad(90) or math.rad(-90))
        DisableTexPixelSnap(tex)
        btn.arrowTex = tex

        local bLine = btn:CreateTexture(nil, "OVERLAY")
        bLine:SetHeight(1.5)
        bLine:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
        bLine:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        DisableTexPixelSnap(bLine)
        bLine:Hide()
        btn.bottomLine = bLine

        btn:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                CycleSelectedDockTab(isLeft and -1 or 1)
                local a1, a2, a3 = GetSuiteAccent()
                LayoutDockedChatTabs(EnsureDB().enableSleekChatSkin ~= false, EnsureDB().applySuiteChatFont ~= false, GetFontPath(), a1, a2, a3)
                RefreshTabNavButtonsVisuals(a1, a2, a3)
                if _G.GameTooltip and _G.GameTooltip:GetOwner() == btn then
                    ShowTabNavTooltip(btn, isLeft)
                end
                return
            end
            if IsShiftKeyDown and IsShiftKeyDown() then
                if isLeft then
                    if tabScrollOffset > 1 then
                        tabScrollOffset = 1
                        local a1, a2, a3 = GetSuiteAccent()
                        LayoutDockedChatTabs(EnsureDB().enableSleekChatSkin ~= false, EnsureDB().applySuiteChatFont ~= false, GetFontPath(), a1, a2, a3)
                    elseif lastDockedTabsSnapshot[1] and lastDockedTabsSnapshot[1].cf and type(_G.FCF_SelectDockFrame) == "function" then
                        pcall(_G.FCF_SelectDockFrame, lastDockedTabsSnapshot[1].cf)
                    end
                else
                    if tabScrollOffset < lastMaxStartIdx then
                        tabScrollOffset = lastMaxStartIdx
                        local a1, a2, a3 = GetSuiteAccent()
                        LayoutDockedChatTabs(EnsureDB().enableSleekChatSkin ~= false, EnsureDB().applySuiteChatFont ~= false, GetFontPath(), a1, a2, a3)
                    elseif #lastDockedTabsSnapshot > 0 and lastDockedTabsSnapshot[#lastDockedTabsSnapshot].cf and type(_G.FCF_SelectDockFrame) == "function" then
                        pcall(_G.FCF_SelectDockFrame, lastDockedTabsSnapshot[#lastDockedTabsSnapshot].cf)
                    end
                end
                local a1, a2, a3 = GetSuiteAccent()
                LayoutDockedChatTabs(EnsureDB().enableSleekChatSkin ~= false, EnsureDB().applySuiteChatFont ~= false, GetFontPath(), a1, a2, a3)
                RefreshTabNavButtonsVisuals(a1, a2, a3)
                return
            end
            if lastMaxStartIdx > 1 then
                local prev = tabScrollOffset
                ScrollDockedTabViewport(isLeft and -1 or 1)
                if tabScrollOffset == prev then
                    CycleSelectedDockTab(isLeft and -1 or 1)
                end
            else
                CycleSelectedDockTab(isLeft and -1 or 1)
            end
            local a1, a2, a3 = GetSuiteAccent()
            LayoutDockedChatTabs(EnsureDB().enableSleekChatSkin ~= false, EnsureDB().applySuiteChatFont ~= false, GetFontPath(), a1, a2, a3)
            RefreshTabNavButtonsVisuals(a1, a2, a3)
            if _G.GameTooltip and _G.GameTooltip:GetOwner() == btn then
                ShowTabNavTooltip(btn, isLeft)
            end
        end)

        btn:SetScript("OnEnter", function(selfBtn)
            local a1, a2, a3 = GetSuiteAccent()
            RefreshTabNavButtonsVisuals(a1, a2, a3)
            ShowTabNavTooltip(selfBtn, isLeft)
        end)
        btn:SetScript("OnLeave", function(selfBtn)
            if _G.GameTooltip and _G.GameTooltip:GetOwner() == selfBtn then
                _G.GameTooltip:Hide()
            end
            local a1, a2, a3 = GetSuiteAccent()
            RefreshTabNavButtonsVisuals(a1, a2, a3)
        end)

        return btn
    end

    nav.leftBtn = CreateNavBtn(true)
    nav.leftBtn:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, 0)
    nav.leftBtn:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 0, 0)

    nav.rightBtn = CreateNavBtn(false)
    nav.rightBtn:SetPoint("TOPRIGHT", nav, "TOPRIGHT", 0, 0)
    nav.rightBtn:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", 0, 0)

    nav:Hide()
    tabNavFrame = nav
    return nav
end

LayoutDockedChatTabs = function(skinEnabled, syncFont, fontPath, ar, ag, ab)
    if isLayingOutDockedTabs then return end
    if DynamicChat:IsExternalChatEngineLoaded() then return end
    local cf1 = _G.ChatFrame1
    local dock = _G.GeneralDockManager
    if not cf1 or not dock then return end

    if not skinEnabled then
        SetSideClutterButtonSuppressed(_G.GeneralDockManagerOverflowButton, false)
        if _G.GeneralDockManagerScrollFrame then
            SetRegionAlphaSafe(_G.GeneralDockManagerScrollFrame, 1)
        end
        if type(dock.SetClipsChildren) == "function" then
            pcall(dock.SetClipsChildren, dock, false)
        end
        if tabNavFrame then tabNavFrame:Hide() end
        for _, entry in pairs(chatSkinStore) do
            entry.hiddenByScroll = false
        end
        return
    end

    isLayingOutDockedTabs = true
    pcall(function()
        local db = EnsureDB()
        local hasLeftRail = (db.leftRailMode ~= "OFF")
        local headerLeftX = hasLeftRail and -2 or -8

        -- Hide Blizzard's overflow dropdown button ('v') and native GeneralDockManagerScrollFrame
        -- so our sleek < and > navigation buttons manage the right edge without fighting Blizzard's scroll frame.
        for _, dockClutter in ipairs({ _G.GeneralDockManagerOverflowButton, _G.GeneralDockManagerScrollFrame }) do
            if dockClutter then
                SetRegionAlphaSafe(dockClutter, 0)
                if type(dockClutter.EnableMouse) == "function" then
                    pcall(dockClutter.EnableMouse, dockClutter, false)
                end
                if type(dockClutter.Hide) == "function" then
                    pcall(dockClutter.Hide, dockClutter)
                end
                HookSuppressOnShow(dockClutter, false)
            end
        end

        -- Collect all active docked tabs in visual dock order
        local dockedTabs = {}
        local seenCF = {}
        if type(dock.DOCKED_CHAT_FRAMES) == "table" then
            for _, cf in ipairs(dock.DOCKED_CHAT_FRAMES) do
                if cf and not seenCF[cf] then
                    local cfName = (cf.GetName and cf:GetName()) or nil
                    local tab = cfName and _G[cfName .. "Tab"]
                    if tab and (DynamicChat.SafeFrameIsShown(tab, false) or cf == cf1 or cf.isDocked) then
                        seenCF[cf] = true
                        dockedTabs[#dockedTabs + 1] = { cf = cf, tab = tab, name = cfName }
                    end
                end
            end
        end

        local allFrames = CollectAllChatFrames()
        for _, item in ipairs(allFrames) do
            local cf = item.cf
            local cfName = item.name
            local tab = cfName and _G[cfName .. "Tab"]
            if cf and tab and not seenCF[cf] and (cf == cf1 or cf.isDocked) and (DynamicChat.SafeFrameIsShown(tab, false) or (chatSkinStore[cf] and chatSkinStore[cf].hiddenByScroll)) then
                seenCF[cf] = true
                dockedTabs[#dockedTabs + 1] = { cf = cf, tab = tab, name = cfName }
            end
        end

        lastDockedTabsSnapshot = dockedTabs
        local numTabs = #dockedTabs

        if not (InCombatLockdown and InCombatLockdown()) then
            local dockRightX = (numTabs > 1) and (8 - 38) or 8
            dock:ClearAllPoints()
            dock:SetPoint("BOTTOMLEFT", cf1, "TOPLEFT", headerLeftX, 4)
            dock:SetPoint("BOTTOMRIGHT", cf1, "TOPRIGHT", dockRightX, 4)
            dock:SetHeight(24)
            if type(dock.SetClipsChildren) == "function" then
                pcall(dock.SetClipsChildren, dock, true)
            end
        end

        if numTabs == 0 then
            if tabNavFrame then tabNavFrame:Hide() end
            return
        end

        local cf1W = (cf1.GetWidth and cf1:GetWidth()) or 430
        if IsSecretValue(cf1W) or type(cf1W) ~= "number" or cf1W < 180 then cf1W = 430 end
        local barWidth = math.max(180, math.floor(cf1W - headerLeftX + 8))

        local nav = EnsureTabNavButtons()
        local navWidth = (numTabs > 1) and 38 or 0
        local availWidth = math.max(120, barWidth - navWidth)

        if numTabs > 1 and IsPrimaryChatDockVisible() then
            local cf1Scale = (cf1.GetScale and cf1:GetScale()) or 1.0
            if nav.SetScale then pcall(nav.SetScale, nav, cf1Scale) end
            nav:ClearAllPoints()
            nav:SetPoint("BOTTOMRIGHT", cf1, "TOPRIGHT", 8, 4)
            nav:SetSize(38, 24)
            nav:Show()
        else
            nav:Hide()
        end

        local naturalWidths = {}
        local totalNatural = 0

        for idx, item in ipairs(dockedTabs) do
            local cf = item.cf
            local tab = item.tab
            local cfName = item.name
            local tabName = cfName .. "Tab"

            local entry = chatSkinStore[cf]
            if not entry then
                entry = {}
                chatSkinStore[cf] = entry
            end

            -- Reparent overflow tabs out of GeneralDockManagerScrollFrameChild directly to GeneralDockManager
            -- so GeneralDockManagerScrollFrame never clips their mouse hit-box!
            if not (InCombatLockdown and InCombatLockdown()) and tab.GetParent and tab.SetParent then
                local curParent = tab:GetParent()
                if curParent ~= dock then
                    pcall(tab.SetParent, tab, dock)
                end
            end

            local chatType = (not IsSecretValue(cf.chatType) and type(cf.chatType) == "string") and cf.chatType or nil
            local isBNWhisperTab = (chatType == "BN_WHISPER" or chatType == "BN_CONVERSATION")
            local isWhisperTab   = isBNWhisperTab or (chatType == "WHISPER") or (cf.isTemporary == true)

            local convIcon = tab.conversationIcon or _G[tabName .. "ConversationIcon"]
            local fs = ResolveChatTabLabel(cf, tab, tabName, entry) or tab.Text or _G[tabName .. "Text"] or (tab.GetFontString and tab:GetFontString())

            if syncFont and fs and fs.SetFont then
                pcall(fs.SetFont, fs, fontPath, 11, "")
            end

            local rawTextW = 48
            if fs then
                local okW, w = pcall(function()
                    if type(fs.SetWidth) == "function" then
                        fs:SetWidth(0)
                    end
                    if type(fs.GetUnboundedStringWidth) == "function" then
                        return fs:GetUnboundedStringWidth()
                    elseif type(fs.GetStringWidth) == "function" then
                        return fs:GetStringWidth()
                    end
                    return 48
                end)
                if okW and not IsSecretValue(w) and type(w) == "number" and w > 8 then
                    rawTextW = w
                elseif isWhisperTab and IsSecretValue(w) then
                    rawTextW = 78
                end
            end

            local padW = (isWhisperTab and convIcon) and 26 or 16
            local minNatW = (isWhisperTab and convIcon) and 58 or 48
            local natW = math.max(minNatW, math.min(130, math.ceil(rawTextW + padW)))
            naturalWidths[idx] = natW
            totalNatural = totalNatural + natW
        end

        -- Compute maximum valid scroll start index so scrolling all the way right packs the rightmost tabs cleanly
        local maxStartIdx = 1
        if totalNatural > availWidth then
            local tailSum = 0
            maxStartIdx = numTabs
            for i = numTabs, 1, -1 do
                if tailSum + naturalWidths[i] <= availWidth or i == numTabs then
                    tailSum = tailSum + naturalWidths[i]
                    maxStartIdx = i
                else
                    break
                end
            end
        end
        lastMaxStartIdx = maxStartIdx

        -- If a specific tab was just selected/opened, ensure tabScrollOffset brings it into the visible viewport
        if pendingEnsureSelectedTabVisible then
            local targetCF = pendingEnsureSelectedTabVisible
            pendingEnsureSelectedTabVisible = nil
            local targetIdx = nil
            for i, item in ipairs(dockedTabs) do
                if item.cf == targetCF then
                    targetIdx = i
                    break
                end
            end
            if targetIdx then
                if targetIdx < tabScrollOffset then
                    tabScrollOffset = targetIdx
                else
                    local sumCheck = 0
                    local reachesTarget = false
                    for i = tabScrollOffset, targetIdx do
                        sumCheck = sumCheck + naturalWidths[i]
                    end
                    if sumCheck <= availWidth then
                        reachesTarget = true
                    end
                    if not reachesTarget then
                        local backSum = 0
                        local newStart = targetIdx
                        for i = targetIdx, 1, -1 do
                            if backSum + naturalWidths[i] <= availWidth or i == targetIdx then
                                backSum = backSum + naturalWidths[i]
                                newStart = i
                            else
                                break
                            end
                        end
                        tabScrollOffset = newStart
                    end
                end
            end
        end

        tabScrollOffset = math.max(1, math.min(maxStartIdx, tabScrollOffset))

        -- Determine visible slice [firstVisIdx .. lastVisIdx] that fits inside availWidth at full readable widths
        local firstVisIdx = tabScrollOffset
        local lastVisIdx  = firstVisIdx
        local visSum = 0
        for i = firstVisIdx, numTabs do
            if visSum + naturalWidths[i] <= availWidth or i == firstVisIdx then
                visSum = visSum + naturalWidths[i]
                lastVisIdx = i
            else
                break
            end
        end

        lastFirstVisIdx = firstVisIdx
        lastLastVisIdx  = lastVisIdx

        local visCount = (lastVisIdx - firstVisIdx + 1)
        local finalWidths = {}
        local slack = math.max(0, availWidth - visSum)
        local extraPerTab = (visCount > 0) and math.floor(slack / visCount) or 0
        local remainder   = (visCount > 0) and (slack - (extraPerTab * visCount)) or 0

        for i = firstVisIdx, lastVisIdx do
            local w = naturalWidths[i] + extraPerTab
            if i == lastVisIdx then
                w = w + remainder
            end
            finalWidths[i] = math.min(availWidth, w)
        end

        for idx, item in ipairs(dockedTabs) do
            local cf = item.cf
            local tab = item.tab
            local cfName = item.name
            local tabName = cfName .. "Tab"
            local entry = chatSkinStore[cf]

            if idx < firstVisIdx or idx > lastVisIdx then
                entry.hiddenByScroll = true
                if not (InCombatLockdown and InCombatLockdown()) and type(tab.ClearAllPoints) == "function" then
                    pcall(tab.ClearAllPoints, tab)
                end
                if tab.Hide then pcall(tab.Hide, tab) end
                if entry.tabCell then entry.tabCell:Hide() end
                if entry.tabLine then entry.tabLine:Hide() end
                StyleSingleChatTab(cf, tab, cfName, skinEnabled, syncFont, fontPath, ar, ag, ab)
            else
                entry.hiddenByScroll = false
                local w = finalWidths[idx] or naturalWidths[idx] or 64

                if InCombatLockdown and InCombatLockdown() then
                    DynamicChat._pendingTabLayoutAfterCombat = true
                else
                    pcall(function()
                        if not DynamicChat.SafeFrameIsShown(tab, false) then
                            tab:Show()
                        end
                        tab:ClearAllPoints()
                        if idx == firstVisIdx then
                            tab:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 0, 0)
                        else
                            tab:SetPoint("BOTTOMLEFT", dockedTabs[idx - 1].tab, "BOTTOMRIGHT", 0, 0)
                        end
                        tab:SetSize(w, 24)
                    end)
                end

                local chatType = (not IsSecretValue(cf.chatType) and type(cf.chatType) == "string") and cf.chatType or nil
                local isBNWhisperTab = (chatType == "BN_WHISPER" or chatType == "BN_CONVERSATION")
                local isWhisperTab   = isBNWhisperTab or (chatType == "WHISPER") or (cf.isTemporary == true)
                local convIcon = tab.conversationIcon or _G[tabName .. "ConversationIcon"]
                local fs = tab.Text or _G[tabName .. "Text"] or (tab.GetFontString and tab:GetFontString())

                if isWhisperTab and convIcon then
                    -- Never anchor fs (tab.Text) to convIcon! Blizzard's FCF_SetTemporaryWindowType
                    -- anchors convIcon to tab.Text, so anchoring tab.Text to convIcon causes a circular SetPoint error.
                    if fs then
                        pcall(function()
                            fs:ClearAllPoints()
                            fs:SetWidth(0)
                            fs:SetPoint("LEFT", tab, "LEFT", 20, 0)
                            fs:SetPoint("RIGHT", tab, "RIGHT", -5, 0)
                            fs:SetJustifyH("LEFT")
                            if fs.SetJustifyV then fs:SetJustifyV("MIDDLE") end
                            fs:SetWordWrap(false)
                        end)
                    end
                    pcall(function()
                        convIcon:ClearAllPoints()
                        convIcon:SetSize(11, 11)
                        convIcon:SetPoint("LEFT", tab, "LEFT", 6, 0)
                        convIcon:Show()
                    end)
                else
                    if convIcon and not isWhisperTab and type(convIcon.Hide) == "function" then
                        pcall(convIcon.Hide, convIcon)
                    end
                    if fs then
                        pcall(function()
                            fs:ClearAllPoints()
                            fs:SetWidth(0)
                            fs:SetPoint("LEFT", tab, "LEFT", 5, 0)
                            fs:SetPoint("RIGHT", tab, "RIGHT", -5, 0)
                            fs:SetJustifyH("CENTER")
                            if fs.SetJustifyV then fs:SetJustifyV("MIDDLE") end
                            fs:SetWordWrap(false)
                        end)
                    end
                end

                StyleSingleChatTab(cf, tab, cfName, skinEnabled, syncFont, fontPath, ar, ag, ab)
            end
        end

        RefreshTabNavButtonsVisuals(ar, ag, ab)
    end)
    isLayingOutDockedTabs = false
end

function DynamicChat:GetPrimaryBackdropPanel()
    if not self:IsChatFrameLayoutOwned() then
        return nil
    end
    local cf1 = _G.ChatFrame1
    local entry = cf1 and chatSkinStore[cf1]
    if entry and entry.panel and entry.panel:IsShown() then
        return entry.panel
    end
    return nil
end

function DynamicChat:GetVisibleContainerExtents()
    if not self:IsChatFrameLayoutOwned() then
        return 0, 0, 0, 0
    end
    local db = EnsureDB()
    if db.enableSleekChatSkin == false then
        return 0, 0, 0, 0
    end
    local hasLeftRail = (db.leftRailMode ~= "OFF")
    local leftExt = hasLeftRail and 36 or 8
    local rightExt = 8
    local topExt = 28
    local bottomExt = 6
    return leftExt, rightExt, topExt, bottomExt
end

function DynamicChat:GetChatMoverBoxInsets()
    local leftExt, rightExt, topExt, bottomExt = self:GetVisibleContainerExtents()
    return -leftExt, rightExt, topExt, -bottomExt
end

function DynamicChat:GetOuterFrameBottomLeftOffsets()
    local leftExt, _, _, bottomExt = self:GetVisibleContainerExtents()
    return leftExt, bottomExt
end

function DynamicChat:GetCompositeChatInsets()
    local leftExt, rightExt, topExt, bottomExt = self:GetVisibleContainerExtents()
    return -leftExt, rightExt, topExt, -bottomExt
end

function DynamicChat:GetLiveOuterBottomLeft()
    local cf = _G.ChatFrame1
    local db = EnsureDB()
    local curW = math.floor(math.max(240, math.min(1200, (cf and cf.GetWidth and cf:GetWidth()) or 430)) + 0.5)
    local curH = math.floor(math.max(100, math.min(900, (cf and cf.GetHeight and cf:GetHeight()) or 200)) + 0.5)
    if not cf then
        return "BOTTOMLEFT", "BOTTOMLEFT", 0, 0, curW, curH
    end
    local fScale = (cf.GetEffectiveScale and cf:GetEffectiveScale()) or 1
    local uScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if fScale <= 0 then fScale = 1 end
    if uScale <= 0 then uScale = 1 end
    local relScale = fScale / uScale
    if relScale <= 0 then relScale = 1 end

    local leftExt, _, _, bottomExt = self:GetVisibleContainerExtents()
    local outerPanel = (db.enableSleekChatSkin ~= false) and self.GetPrimaryBackdropPanel and self:GetPrimaryBackdropPanel() or nil
    if outerPanel and outerPanel.IsShown and outerPanel:IsShown() and outerPanel.GetLeft and outerPanel.GetBottom then
        local oL = outerPanel:GetLeft()
        local oB = outerPanel:GetBottom()
        if oL and oB then
            local pScale = (outerPanel.GetEffectiveScale and outerPanel:GetEffectiveScale()) or fScale
            if pScale <= 0 then pScale = fScale end
            local pRelScale = pScale / uScale
            local outerX = math.floor(((oL * pRelScale) / relScale) + 0.5)
            local outerY = math.floor(((oB * pRelScale) / relScale) + 0.5)
            return "BOTTOMLEFT", "BOTTOMLEFT", outerX, outerY, curW, curH
        end
    end
    if cf.GetLeft and cf.GetBottom then
        local cL = cf:GetLeft()
        local cB = cf:GetBottom()
        if cL and cB then
            local outerX = math.floor((cL - leftExt) + 0.5)
            local outerY = math.floor((cB - bottomExt) + 0.5)
            return "BOTTOMLEFT", "BOTTOMLEFT", outerX, outerY, curW, curH
        end
    end
    if type(db.chatFramePos) == "table" and db.chatFramePos.x ~= nil and db.chatFramePos.y ~= nil then
        local cx, cy, cw, ch = self:ClampChatFrameCoords(db.chatFramePos.x, db.chatFramePos.y, db.chatFramePos.width or curW, db.chatFramePos.height or curH, db.chatFramePos.point)
        return "BOTTOMLEFT", "BOTTOMLEFT", cx, cy, cw, ch
    end
    return "BOTTOMLEFT", "BOTTOMLEFT", 0, 0, curW, curH
end

function DynamicChat:ClampChatFrameCoords(x, y, w, h, anchorPt)
    local cf = _G.ChatFrame1
    local fScale = (cf and cf.GetEffectiveScale and cf:GetEffectiveScale()) or 1
    local uScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if fScale <= 0 then fScale = 1 end
    if uScale <= 0 then uScale = 1 end
    local relScale = fScale / uScale
    if relScale <= 0 then relScale = 1 end

    local screenW = ((UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920) / relScale
    local screenH = ((UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080) / relScale

    local leftExt, rightExt, topExt, bottomExt = self:GetVisibleContainerExtents()
    local maxAllowedW = math.max(240, math.min(1200, math.floor(screenW - leftExt - rightExt)))
    local maxAllowedH = math.max(100, math.min(900, math.floor(screenH - topExt - bottomExt)))
    local curW = math.max(240, math.min(maxAllowedW, tonumber(w) or (cf and cf.GetWidth and cf:GetWidth()) or 430))
    local curH = math.max(100, math.min(maxAllowedH, tonumber(h) or (cf and cf.GetHeight and cf:GetHeight()) or 200))

    local outerX = tonumber(x) or 0
    local outerY = tonumber(y) or 0
    if anchorPt == "CENTER" then
        outerX = (screenW / 2) + outerX - (curW / 2) - leftExt
        outerY = (screenH / 2) + outerY - (curH / 2) - bottomExt
    end

    local maxOuterX = math.max(0, math.floor(screenW - curW - leftExt - rightExt))
    local maxOuterY = math.max(0, math.floor(screenH - curH - topExt - bottomExt))
    outerX = math.max(0, math.min(maxOuterX, outerX))
    outerY = math.max(0, math.min(maxOuterY, outerY))

    return math.floor(outerX + 0.5), math.floor(outerY + 0.5), math.floor(curW + 0.5), math.floor(curH + 0.5)
end

local origBlizzBtnAnchors = {}

local function CacheOriginalButtonAnchors(f)
    if not f or origBlizzBtnAnchors[f] or type(f.GetNumPoints) ~= "function" then return end
    local pts = {}
    local ok, n = pcall(f.GetNumPoints, f)
    if ok and type(n) == "number" and n > 0 then
        for idx = 1, n do
            local okP, pt, relTo, relPt, xOfs, yOfs = pcall(f.GetPoint, f, idx)
            if okP and pt then
                pts[#pts + 1] = { pt, relTo, relPt, xOfs or 0, yOfs or 0 }
            end
        end
    end
    if #pts > 0 then
        origBlizzBtnAnchors[f] = pts
    end
end

local function RestoreOriginalButtonAnchors(f)
    local pts = f and origBlizzBtnAnchors[f]
    if not pts or type(f.ClearAllPoints) ~= "function" then return end
    pcall(function()
        f:ClearAllPoints()
        for _, p in ipairs(pts) do
            f:SetPoint(p[1], p[2], p[3], p[4], p[5])
        end
    end)
end

do
    local BLIZZ_FONTS = {
        { value = "BLIZZ_FRIZQT",   label = "Friz Quadrata (Blizzard)",   path = "Fonts\\FRIZQT__.TTF",   source = "Blizzard" },
        { value = "BLIZZ_2002",     label = "2002 (Blizzard)",            path = "Fonts\\2002.TTF",       source = "Blizzard" },
        { value = "BLIZZ_2002B",    label = "2002 Bold (Blizzard)",       path = "Fonts\\2002B.TTF",      source = "Blizzard" },
        { value = "BLIZZ_ARIALN",   label = "Arial Narrow (Blizzard)",    path = "Fonts\\ARIALN.TTF",     source = "Blizzard" },
        { value = "BLIZZ_MORPHEUS", label = "Morpheus (Blizzard)",        path = "Fonts\\MORPHEUS.TTF",   source = "Blizzard" },
        { value = "BLIZZ_SKURRI",   label = "Skurri (Blizzard)",          path = "Fonts\\SKURRI.TTF",     source = "Blizzard" },
    }
    local BLIZZ_BY_KEY = {}
    for _, b in ipairs(BLIZZ_FONTS) do
        BLIZZ_BY_KEY[b.value] = b
    end

    function TypographyMgr.ResolveFontPath(fontKey)
        if not fontKey or fontKey == "" or fontKey == "SUITE" then
            return GetFontPath()
        end
        if BLIZZ_BY_KEY[fontKey] then
            return BLIZZ_BY_KEY[fontKey].path
        end
        if _G.DynamicSuite then
            if type(_G.DynamicSuite.ResolveFontChoice) == "function" then
                local ok, p, _, usedFallback = pcall(_G.DynamicSuite.ResolveFontChoice, _G.DynamicSuite, fontKey)
                if ok and type(p) == "string" and p ~= "" and not usedFallback then
                    return p
                end
            end
            if type(_G.DynamicSuite.GetSharedFonts) == "function" then
                local okR, fReg = pcall(_G.DynamicSuite.GetSharedFonts, _G.DynamicSuite, false)
                if okR and type(fReg) == "table" and type(fReg.byKey) == "table" and fReg.byKey[fontKey] then
                    local p = fReg.byKey[fontKey].path
                    if type(p) == "string" and p ~= "" then return p end
                end
            end
            if _G.DynamicSuite.UI and type(_G.DynamicSuite.UI.FONT_FAMILIES) == "table" then
                local entry = _G.DynamicSuite.UI.FONT_FAMILIES[fontKey]
                if type(entry) == "table" then
                    local p = entry.resolvedPath or entry.path
                    if type(p) == "string" and p ~= "" then return p end
                end
            end
        end
        return GetFontPath()
    end

    function TypographyMgr.GetFontOptions()
        local out = {
            { value = "SUITE", label = "Use Suite Theme Font (Default)", group = "DYNAMICSUITE", source = "DynamicSuite" },
        }
        local seen = { SUITE = true }

        local builtinItems = {}
        local uiFonts = _G.DynamicSuite and _G.DynamicSuite.UI and _G.DynamicSuite.UI.FONT_FAMILIES
        if type(uiFonts) == "table" then
            for fKey, entry in pairs(uiFonts) do
                if type(fKey) == "string" and fKey ~= "EXTERNAL_UI" and type(entry) == "table" then
                    local fName = entry.name or fKey
                    if not seen[fKey] then
                        seen[fKey] = true
                        builtinItems[#builtinItems + 1] = {
                            value  = fKey,
                            label  = fName,
                            group  = "BUILTIN FONTS",
                            source = "DynamicSuite",
                            path   = entry.resolvedPath or entry.path,
                        }
                    end
                end
            end
            table.sort(builtinItems, function(a, b) return (a.label or "") < (b.label or "") end)
        else
            builtinItems[#builtinItems + 1] = {
                value  = "EXPRESSWAY",
                label  = "Expressway",
                group  = "BUILTIN FONTS",
                source = "DynamicChat",
                path   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.ttf",
            }
            seen["EXPRESSWAY"] = true
        end
        for _, item in ipairs(builtinItems) do
            out[#out + 1] = item
        end

        for _, b in ipairs(BLIZZ_FONTS) do
            if not seen[b.value] then
                seen[b.value] = true
                out[#out + 1] = {
                    value  = b.value,
                    label  = b.label,
                    group  = "BLIZZARD FONTS",
                    source = b.source,
                    path   = b.path,
                }
            end
        end

        if _G.DynamicSuite and type(_G.DynamicSuite.GetSharedFonts) == "function" then
            local okR, fReg = pcall(_G.DynamicSuite.GetSharedFonts, _G.DynamicSuite, false)
            if okR and type(fReg) == "table" and type(fReg.external) == "table" then
                local extItems = {}
                for _, ext in ipairs(fReg.external) do
                    local key = ext.value or ext.name
                    if type(key) == "string" and key ~= "" and not seen[key] then
                        seen[key] = true
                        extItems[#extItems + 1] = {
                            value  = key,
                            label  = ext.label or ext.name or key,
                            group  = "SHAREDMEDIA & ADDON FONTS",
                            source = ext.source or "SharedMedia",
                            path   = ext.path,
                        }
                    end
                end
                table.sort(extItems, function(a, b) return (a.label or "") < (b.label or "") end)
                for _, item in ipairs(extItems) do
                    out[#out + 1] = item
                end
            end
        end

        return out
    end

    function TypographyMgr.GetFontLabel(fontKey)
        if not fontKey or fontKey == "" or fontKey == "SUITE" then
            return "Use Suite Theme Font (Default)"
        end
        if BLIZZ_BY_KEY[fontKey] then
            return BLIZZ_BY_KEY[fontKey].label
        end
        local uiFonts = _G.DynamicSuite and _G.DynamicSuite.UI and _G.DynamicSuite.UI.FONT_FAMILIES
        if type(uiFonts) == "table" and type(uiFonts[fontKey]) == "table" then
            return uiFonts[fontKey].name or fontKey
        end
        if _G.DynamicSuite and type(_G.DynamicSuite.GetSharedFonts) == "function" then
            local okR, fReg = pcall(_G.DynamicSuite.GetSharedFonts, _G.DynamicSuite, false)
            if okR and type(fReg) == "table" and type(fReg.byKey) == "table" and fReg.byKey[fontKey] then
                return fReg.byKey[fontKey].label or fReg.byKey[fontKey].name or fontKey
            end
        end
        return tostring(fontKey)
    end

    function TypographyMgr.ApplyToEditBox(eb, fontPath, size, flags, hasShadow)
        if not eb then return end
        local ebSize = math.max(11, math.min(size, 18))
        if eb.SetFont then
            local ok, setOk = pcall(eb.SetFont, eb, fontPath, ebSize, flags)
            if not ok or setOk == false then
                pcall(eb.SetFont, eb, "Fonts\\FRIZQT__.TTF", ebSize, flags)
            end
        end
        if eb.SetShadowOffset then
            pcall(eb.SetShadowOffset, eb, hasShadow and 1 or 0, hasShadow and -1 or 0)
        end
        if eb.SetShadowColor then
            pcall(eb.SetShadowColor, eb, 0, 0, 0, hasShadow and 0.90 or 0)
        end
        if eb.header and eb.header.SetFont then
            local okH, setH = pcall(eb.header.SetFont, eb.header, fontPath, ebSize, flags)
            if not okH or setH == false then
                pcall(eb.header.SetFont, eb.header, "Fonts\\FRIZQT__.TTF", ebSize, flags)
            end
        end
    end

    function TypographyMgr.ApplyToSingleFrame(cf, cfName, fontPath, size, flags, hasShadow, spacing, fading)
        if not cf then return end
        if cf.SetFont then
            local ok, setOk = pcall(cf.SetFont, cf, fontPath, size, flags)
            if not ok or setOk == false then
                pcall(cf.SetFont, cf, "Fonts\\FRIZQT__.TTF", size, flags)
            end
        end
        if cf.SetShadowOffset then
            pcall(cf.SetShadowOffset, cf, hasShadow and 1 or 0, hasShadow and -1 or 0)
        end
        if cf.SetShadowColor then
            pcall(cf.SetShadowColor, cf, 0, 0, 0, hasShadow and 0.90 or 0)
        end
        if cf.SetSpacing then
            pcall(cf.SetSpacing, cf, spacing)
        end
        if cf.SetFading then
            pcall(cf.SetFading, cf, fading)
        end
        if fading and cf.SetTimeVisible then
            pcall(cf.SetTimeVisible, cf, 120)
        end
        local eb = cfName and _G[cfName .. "EditBox"]
        if eb then
            TypographyMgr.ApplyToEditBox(eb, fontPath, size, flags, hasShadow)
        end
    end

    function TypographyMgr.InstallHooks()
        if TypographyMgr.hooksInstalled then return end
        TypographyMgr.hooksInstalled = true
        if type(_G.hooksecurefunc) == "function" then
            if type(_G.FCF_SetChatWindowFontSize) == "function" then
                hooksecurefunc("FCF_SetChatWindowFontSize", function()
                    if TypographyMgr.applying then return end
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0, function()
                            DynamicChat:ApplyChatFrameTypography()
                        end)
                    end
                end)
            end
            if type(_G.FCF_OpenTemporaryWindow) == "function" then
                hooksecurefunc("FCF_OpenTemporaryWindow", function()
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0, function()
                            DynamicChat:ApplyChatFrameTypography()
                        end)
                    end
                end)
            end
        end
    end
end

function DynamicChat:ApplyChatFrameTypography()
    if IsModuleDisabledInSuite("DynamicChat") or self:IsExternalChatEngineLoaded() then
        return
    end
    TypographyMgr.InstallHooks()

    local db = EnsureDB()
    local fontPath = TypographyMgr.ResolveFontPath(db.chatFontKey)
    local size = tonumber(db.chatFontSize) or 13
    if size < 10 then size = 10 elseif size > 22 then size = 22 end
    local out = db.chatFontOutline
    local flags = ""
    if out == "OUTLINE" then
        flags = "OUTLINE"
    elseif out == "THICKOUTLINE" then
        flags = "THICKOUTLINE"
    end
    local hasShadow = (db.chatFontShadow ~= false)
    local spacing = tonumber(db.chatLineSpacing) or 2
    if spacing < 0 then spacing = 0 elseif spacing > 8 then spacing = 8 end
    local fading = (db.chatMessageFade ~= false)

    TypographyMgr.applying = true
    local allFrames = CollectAllChatFrames()
    local seenEditBox = {}
    for _, item in ipairs(allFrames) do
        TypographyMgr.ApplyToSingleFrame(item.cf, item.name, fontPath, size, flags, hasShadow, spacing, fading)
        local eb = item.name and _G[item.name .. "EditBox"]
        if eb then seenEditBox[eb] = true end
    end
    if _G.ChatFrame1EditBox and not seenEditBox[_G.ChatFrame1EditBox] then
        TypographyMgr.ApplyToEditBox(_G.ChatFrame1EditBox, fontPath, size, flags, hasShadow)
    end
    TypographyMgr.applying = false
end

function DynamicChat:ApplySleekChatSkin()
    -- Auto-yield 100% of chat frame skinning when EllesmereUIChat, Chattynator, Prat-3.0, or LS: Glass is loaded
    if self:IsExternalChatEngineLoaded() then
        HideAllCurrentSkinFrames()
        self:HideHudEditMover()
        return
    end

    local db = EnsureDB()
    local skinEnabled = (db.enableSleekChatSkin ~= false)
    local hideBtns    = skinEnabled and (db.hideChatButtons ~= false)
    local syncFont    = (db.applySuiteChatFont ~= false)
    local bgAlpha     = tonumber(db.chatBgAlpha) or 0.25
    local ar, ag, ab  = GetSuiteAccent()
    local fontPath    = GetFontPath()

    -- Retail 12.1.5 Zero-Taint Guard:
    -- Never overwrite _G.DEFAULT_CHATFRAME_ALPHA or _G.CHAT_FRAME_TAB_*_ALPHA globals.
    -- Tab alpha is enforced directly via tab:SetAlpha(1.0) in StyleSingleChatTab.

    -- Align GeneralDockManager inside the 24px Top Tab Header Bar (y = +4 to +28 above ChatFrame1)
    -- with 4px inner clearance between the tab strip and the ScrollingMessageFrame viewport.
    if _G.GeneralDockManager and _G.ChatFrame1 and not (InCombatLockdown and InCombatLockdown()) then
        if skinEnabled then
            local headerLeftX = (db.leftRailMode ~= "OFF") and -2 or -8
            local dockRightX  = (#lastDockedTabsSnapshot > 1) and (8 - 38) or 8
            pcall(function()
                _G.GeneralDockManager:ClearAllPoints()
                _G.GeneralDockManager:SetPoint("BOTTOMLEFT", _G.ChatFrame1, "TOPLEFT", headerLeftX, 4)
                _G.GeneralDockManager:SetPoint("BOTTOMRIGHT", _G.ChatFrame1, "TOPRIGHT", dockRightX, 4)
                _G.GeneralDockManager:SetHeight(24)
                if type(_G.GeneralDockManager.SetClipsChildren) == "function" then
                    _G.GeneralDockManager:SetClipsChildren(true)
                end
            end)
        else
            pcall(function()
                if type(_G.GeneralDockManager.SetClipsChildren) == "function" then
                    _G.GeneralDockManager:SetClipsChildren(false)
                end
            end)
        end
    end

    -- Side Clutter Buttons (Voice/Channel/Menu/Social Toast)
    -- Must call Hide() + EnableMouse(false) + OnShow hook when hideBtns is true so invisible Blizzard buttons
    -- never sit over the Left Utility Rail and steal clicks from Scroll-to-Bottom, Settings, or Durability!
    SetSideClutterButtonSuppressed(_G.ChatFrameChannelButton, hideBtns)
    SetSideClutterButtonSuppressed(_G.ChatFrameMenuButton, hideBtns)
    SetSideClutterButtonSuppressed(_G.ChatFrameToggleVoiceDeafenButton, hideBtns)
    SetSideClutterButtonSuppressed(_G.ChatFrameToggleVoiceMuteButton, hideBtns)
    SetSideClutterButtonSuppressed(_G.QuickJoinToastButton, hideBtns)

    local allFrames = CollectAllChatFrames()
    local activeFrameSet = {}

    for _, item in ipairs(allFrames) do
        local cf     = item.cf
        local i      = item.index
        local cfName = item.name
        local tab    = _G[cfName .. "Tab"]
        local eb     = _G[cfName .. "EditBox"]
        if cf then
            activeFrameSet[cf] = true
            -- 1. Completely strip Blizzard's native ChatFrameBackground, NineSlice & 9-slice border textures (No Box-in-a-Box!)
            SuppressBlizzardChatBackground(cf, cfName, skinEnabled)
            SetSideClutterButtonSuppressed(_G[cfName .. "ButtonFrame"], hideBtns)
            SetSideClutterButtonSuppressed(_G[cfName .. "MinimizeButton"], hideBtns)
            if cf.buttonFrame and cf.buttonFrame ~= _G[cfName .. "ButtonFrame"] then
                SetSideClutterButtonSuppressed(cf.buttonFrame, hideBtns)
            end

            -- 2. Passively skin EditBox & Header font on init (never inside a hook that runs before/replaces UpdateHeader,
            --    and never when tellTarget or header:GetStringWidth() is a secret value)
            if eb then
                ApplyPassiveEditBoxSkinOnInit(eb, cfName, skinEnabled, syncFont, fontPath)
            end

            -- 3. UIParent-Hosted Borderless Smoked-Glass Canvas (Enclosing 24px Top Tab Header Bar + 34px Left Utility Rail + Chat Text)
            local entry = chatSkinStore[cf]
            if not entry then
                entry = {}
                chatSkinStore[cf] = entry
            end

            local isDockedChild = (i > 1 and cf.isDocked)
            local isPrimaryDockVisible = (i == 1) and IsPrimaryChatDockVisible()
            local shouldShowPanel = skinEnabled and (isPrimaryDockVisible or (not isDockedChild and DynamicChat.SafeFrameIsShown(cf, false)))
            if shouldShowPanel then
                if not entry.panel then
                    local p = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
                    p:SetFrameStrata("BACKGROUND")
                    p:SetFrameLevel(1)
                    p:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8x8",
                        edgeFile = "Interface\\Buttons\\WHITE8x8",
                        edgeSize = 1,
                    })

                    -- Full-width Top Tab Header Bar tint (0.02, 0.025, 0.035, 0.40) so the header strip to the right of the last tab is uniform
                    local headerBg = p:CreateTexture(nil, "BACKGROUND", nil, 1)
                    headerBg:SetColorTexture(0.02, 0.025, 0.035, 0.40)
                    DisableTexPixelSnap(headerBg)
                    p.headerBg = headerBg

                    -- 1px horizontal hairline separating the 24px Top Tab Header Bar from the chat text
                    local headerDiv = p:CreateTexture(nil, "BORDER")
                    headerDiv:SetHeight(1)
                    headerDiv:SetColorTexture(1, 1, 1, 0.06)
                    DisableTexPixelSnap(headerDiv)
                    p.headerDiv = headerDiv

                    -- 1px horizontal interior divider separating the fused EditBox dock from the chat frame
                    local footerDiv = p:CreateTexture(nil, "BORDER")
                    footerDiv:SetHeight(1)
                    footerDiv:SetColorTexture(1, 1, 1, 0.08)
                    DisableTexPixelSnap(footerDiv)
                    footerDiv:Hide()
                    p.footerDiv = footerDiv

                    -- 1px vertical hairline separating the 34px Left Utility Rail from the chat text
                    local railDiv = p:CreateTexture(nil, "BORDER")
                    railDiv:SetWidth(1)
                    railDiv:SetColorTexture(1, 1, 1, 0.06)
                    DisableTexPixelSnap(railDiv)
                    p.railDiv = railDiv

                    entry.panel = p
                end
                local p = entry.panel
                local hasLeftRail = (i == 1 and db.leftRailMode ~= "OFF")
                local leftPad = hasLeftRail and -36 or -8
                local divLeftX = hasLeftRail and 34 or 0
                local isTopEB = (i == 1 and db.editBoxPosition == "TOP")
                local alwaysShadedEB = (i == 1 and db.editBoxBackgroundMode ~= "FOCUS_ONLY")
                local topPad = 28
                local botPad = -6
                local topRailInset = 0
                local botRailInset = 0
                local cfScale = (cf.GetScale and cf:GetScale()) or 1.0
                if p.SetScale then pcall(p.SetScale, p, cfScale) end

                p:ClearAllPoints()
                local isBottomLeftOwned = (i == 1 and self:IsChatFrameLayoutOwned() and type(db.chatFramePos) == "table"
                    and (db.chatFramePos.point == "BOTTOMLEFT" or db.chatFramePos.relativePoint == "BOTTOMLEFT" or db.chatFramePos.relPoint == "BOTTOMLEFT"))
                if isBottomLeftOwned then
                    local outerX = math.max(0, tonumber(db.chatFramePos.x) or 0)
                    local outerY = math.max(0, tonumber(db.chatFramePos.y) or 0)
                    local cfW = tonumber(db.chatFramePos.width) or (cf:GetWidth() or 430)
                    local cfH = tonumber(db.chatFramePos.height) or (cf:GetHeight() or 200)
                    if p.SetClampRectInsets then p:SetClampRectInsets(0, 0, 0, 0) end
                    if p.SetClampedToScreen then p:SetClampedToScreen(false) end
                    -- Panel always hugs ChatFrame1; ChatFrame1 sits at (leftOffset + outerX, bottomOffset + outerY)
                    -- so the panel's bottom-left pixel lands exactly on (outerX, outerY) of UIParent.
                    p:SetPoint("TOPLEFT", cf, "TOPLEFT", leftPad, topPad)
                    p:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 8, botPad)
                    if not self._applyingChatPos and not DynamicChat._dsDragging and not DynamicChat._dsEditModeActive and not (InCombatLockdown and InCombatLockdown()) then
                        self._applyingChatPos = true
                        pcall(function()
                            cf:SetUserPlaced(true)
                            if cf.SetClampRectInsets then cf:SetClampRectInsets(0, 0, 0, 0) end
                            if cf.SetClampedToScreen then cf:SetClampedToScreen(false) end
                            if _G.ChatFrame1Background then
                                if _G.ChatFrame1Background.SetClampRectInsets then _G.ChatFrame1Background:SetClampRectInsets(0, 0, 0, 0) end
                                if _G.ChatFrame1Background.SetClampedToScreen then _G.ChatFrame1Background:SetClampedToScreen(false) end
                            end
                            if _G.ChatFrame1EditBox and not IsEditBoxSecretOrBNWhisper(_G.ChatFrame1EditBox) then
                                if _G.ChatFrame1EditBox.SetClampRectInsets then _G.ChatFrame1EditBox:SetClampRectInsets(0, 0, 0, 0) end
                                if _G.ChatFrame1EditBox.SetClampedToScreen then _G.ChatFrame1EditBox:SetClampedToScreen(false) end
                            end
                            cf:SetSize(cfW, cfH)
                            cf:ClearAllPoints()
                            cf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (-leftPad) + outerX, (-botPad) + outerY)
                        end)
                        self._applyingChatPos = false
                    end
                else
                    p:SetPoint("TOPLEFT", cf, "TOPLEFT", leftPad, topPad)
                    p:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 8, botPad)
                end
                p:SetBackdropColor(0.035, 0.039, 0.051, bgAlpha) -- #090A0D Unbroken Smoked-Glass Canvas
                local bStyle = db.chatBorderStyle or "ACCENT"
                if bStyle == "NONE" then
                    p:SetBackdropBorderColor(0, 0, 0, 0)
                elseif bStyle == "DARK" or bStyle == "SUBTLE" then
                    p:SetBackdropBorderColor(0.18, 0.22, 0.28, 0.85)
                else
                    p:SetBackdropBorderColor(ar, ag, ab, 0.85)
                end

                if p.headerDiv then
                    p.headerDiv:ClearAllPoints()
                    if isBottomLeftOwned then
                        p.headerDiv:SetPoint("TOPLEFT", p, "TOPLEFT", divLeftX, -(topPad - 4))
                        p.headerDiv:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -(topPad - 4))
                    else
                        p.headerDiv:SetPoint("TOPLEFT", cf, "TOPLEFT", leftPad + divLeftX, 4)
                        p.headerDiv:SetPoint("TOPRIGHT", cf, "TOPRIGHT", 8, 4)
                    end
                    p.headerDiv:Show()
                end

                if p.footerDiv then
                    if alwaysShadedEB then
                        p.footerDiv:ClearAllPoints()
                        p.footerDiv:SetColorTexture(1, 1, 1, 0.08)
                        if isTopEB then
                            p.footerDiv:SetPoint("TOPLEFT", cf, "TOPLEFT", 0, -26)
                            p.footerDiv:SetPoint("TOPRIGHT", cf, "TOPRIGHT", 0, -26)
                        else
                            p.footerDiv:SetPoint("BOTTOMLEFT", cf, "BOTTOMLEFT", 0, 26)
                            p.footerDiv:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 0, 26)
                        end
                        p.footerDiv:Show()
                    else
                        p.footerDiv:Hide()
                    end
                end

                if i == 1 and cf.FontStringContainer and cf.FontStringContainer.ClearAllPoints and cf.FontStringContainer.SetPoint and not (InCombatLockdown and InCombatLockdown()) then
                    pcall(function()
                        local fsc = cf.FontStringContainer
                        fsc:ClearAllPoints()
                        if isTopEB then
                            fsc:SetPoint("TOPLEFT", cf, "TOPLEFT", 0, -28)
                            fsc:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 0, 0)
                        else
                            fsc:SetPoint("TOPLEFT", cf, "TOPLEFT", 0, 0)
                            fsc:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 0, 28)
                        end
                        fsc._dgEmbeddedPad = true
                    end)
                end

                if p.headerBg and p.headerDiv then
                    p.headerBg:ClearAllPoints()
                    p.headerBg:SetPoint("TOPLEFT", p, "TOPLEFT", divLeftX, topRailInset)
                    p.headerBg:SetPoint("BOTTOMRIGHT", p.headerDiv, "TOPRIGHT", 0, 0)
                    p.headerBg:Show()
                end

                if p.railDiv then
                    if hasLeftRail then
                        p.railDiv:ClearAllPoints()
                        p.railDiv:SetPoint("TOPLEFT", p, "TOPLEFT", 34, topRailInset)
                        p.railDiv:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 34, botRailInset)
                        p.railDiv:Show()
                    else
                        p.railDiv:Hide()
                    end
                end

                p:Show()

                if i == 1 and self:IsChatFrameLayoutOwned() and not DynamicChat._dsEditModeActive and not DynamicChat._dsDragging and not (InCombatLockdown and InCombatLockdown()) then
                    pcall(function()
                        if cf.SetClampRectInsets then cf:SetClampRectInsets(0, 0, 0, 0) end
                        if cf.SetClampedToScreen then cf:SetClampedToScreen(false) end
                        if _G.ChatFrame1Background then
                            if _G.ChatFrame1Background.SetClampRectInsets then _G.ChatFrame1Background:SetClampRectInsets(0, 0, 0, 0) end
                            if _G.ChatFrame1Background.SetClampedToScreen then _G.ChatFrame1Background:SetClampedToScreen(false) end
                        end
                        if _G.ChatFrame1EditBox and not IsEditBoxSecretOrBNWhisper(_G.ChatFrame1EditBox) then
                            if _G.ChatFrame1EditBox.SetClampRectInsets then _G.ChatFrame1EditBox:SetClampRectInsets(0, 0, 0, 0) end
                            if _G.ChatFrame1EditBox.SetClampedToScreen then _G.ChatFrame1EditBox:SetClampedToScreen(false) end
                        end
                    end)
                end

                if hasLeftRail then
                    local rail = EnsureChatLeftRail(entry, p)
                    rail:ClearAllPoints()
                    rail:SetPoint("TOPLEFT", p, "TOPLEFT", 0, topRailInset)
                    rail:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, botRailInset)
                    rail:Show()
                    LayoutChatLeftRail(rail)
                elseif entry.leftRail then
                    entry.leftRail:Hide()
                end

                -- If the user turns 'Hide Default Blizzard Side Buttons' Off while Sleek Chat Skin is active,
                -- dock ChatFrame1ButtonFrame, ChatFrameMenuButton, and QuickJoinToastButton cleanly along the outside left/top of entry.panel!
                if i == 1 and not hideBtns and not (InCombatLockdown and InCombatLockdown()) then
                    local bf1 = _G.ChatFrame1ButtonFrame or cf.buttonFrame
                    if bf1 and type(bf1.ClearAllPoints) == "function" then
                        CacheOriginalButtonAnchors(bf1)
                        pcall(function()
                            bf1:ClearAllPoints()
                            bf1:SetPoint("TOPLEFT", p, "TOPLEFT", -30, -2)
                            bf1:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", -30, 30)
                        end)
                    end
                    if _G.ChatFrameMenuButton and type(_G.ChatFrameMenuButton.ClearAllPoints) == "function" then
                        CacheOriginalButtonAnchors(_G.ChatFrameMenuButton)
                        pcall(function()
                            _G.ChatFrameMenuButton:ClearAllPoints()
                            _G.ChatFrameMenuButton:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", -29, 2)
                        end)
                    end
                    if _G.QuickJoinToastButton and type(_G.QuickJoinToastButton.ClearAllPoints) == "function" then
                        CacheOriginalButtonAnchors(_G.QuickJoinToastButton)
                        pcall(function()
                            _G.QuickJoinToastButton:ClearAllPoints()
                            _G.QuickJoinToastButton:SetPoint("BOTTOMLEFT", p, "TOPLEFT", -30, 4)
                        end)
                    end
                end
            else
                if entry.panel then entry.panel:Hide() end
                if entry.leftRail then entry.leftRail:Hide() end
                if i == 1 and not skinEnabled and not (InCombatLockdown and InCombatLockdown()) then
                    RestoreOriginalButtonAnchors(_G.ChatFrame1ButtonFrame or cf.buttonFrame)
                    RestoreOriginalButtonAnchors(_G.ChatFrameMenuButton)
                    RestoreOriginalButtonAnchors(_G.QuickJoinToastButton)
                end
            end

            -- 4. Reskin cf.ScrollBar (3px Auto-Fade Track) & Hide cf.ScrollToBottomButton
            ReskinChatScrollBarAndBottomButton(cf, entry, skinEnabled)

            -- 5. Flat Top Tab Header Bar Cells & Full-Width 2px Suite Accent Underline
            if tab then
                StyleSingleChatTab(cf, tab, cfName, skinEnabled, syncFont, fontPath, ar, ag, ab)
            end
        end
    end

    -- 5b. Proportionally fit all docked tabs (including multiple Whisper / BNet Whisper tabs) inside the Top Tab Header Bar
    LayoutDockedChatTabs(skinEnabled, syncFont, fontPath, ar, ag, ab)

    -- Hide any orphaned tabCell/tabLine from closed temporary Whisper tabs
    for cf, entry in pairs(chatSkinStore) do
        local cfName = (cf.GetName and cf:GetName()) or ""
        local tab = (cfName ~= "" and _G[cfName .. "Tab"]) or nil
        if not activeFrameSet[cf] or not tab or not DynamicChat.SafeFrameIsShown(tab, false) or not skinEnabled then
            if entry.tabCell then entry.tabCell:Hide() end
            if entry.tabLine then entry.tabLine:Hide() end
        end
        local isPrimaryCF = (cf == _G.ChatFrame1) and IsPrimaryChatDockVisible()
        if not activeFrameSet[cf] or (not isPrimaryCF and (not DynamicChat.SafeFrameIsShown(cf, false) or (cf ~= _G.ChatFrame1 and cf.isDocked))) or not skinEnabled then
            if entry.panel then entry.panel:Hide() end
            if entry.leftRail then entry.leftRail:Hide() end
            if cf == _G.ChatFrame1 and not skinEnabled and cf.FontStringContainer and cf.FontStringContainer._dgEmbeddedPad and not (InCombatLockdown and InCombatLockdown()) then
                pcall(function()
                    cf.FontStringContainer:ClearAllPoints()
                    cf.FontStringContainer:SetAllPoints(cf)
                    cf.FontStringContainer._dgEmbeddedPad = nil
                end)
            end
        end
        if not activeFrameSet[cf] or not DynamicChat.SafeFrameIsShown(cf, false) or not skinEnabled then
            if entry.scrollThumbFrame then entry.scrollThumbFrame:Hide() end
        end
    end

    self:RefreshLeftRailTelemetry()

    -- 6. UIParent-Hosted Sleek Obsidian EditBox Bar (embedded inside ChatFrame1 bounds, 26px tall)
    -- Passively yield EditBox anchoring and bar skinning when EllesmereUI is loaded so both addons coexist with zero BN_WHISPER taint.
    local ebBar = EnsureSleekEditBoxBar()
    if skinEnabled and _G.ChatFrame1EditBox and not IsEllesmereUILoaded() then
        local eb1 = _G.ChatFrame1EditBox
        local cf1 = _G.ChatFrame1
        local isTopEB = (db.editBoxPosition == "TOP")
        local alwaysShadedEB = (db.editBoxBackgroundMode ~= "FOCUS_ONLY")
        local ebSecret = IsEditBoxSecretOrBNWhisper(eb1)
        if cf1 and not ebSecret and not (InCombatLockdown and InCombatLockdown()) then
            local state = passiveSkinnedEditBoxes[eb1]
            if not state then
                state = {}
                passiveSkinnedEditBoxes[eb1] = state
            end
            local function ApplyEditBoxAnchorNow()
                if DynamicChat._applyingEditBoxPos or not cf1 then return end
                if InCombatLockdown and InCombatLockdown() then return end
                local curEB = _G.ChatFrame1EditBox
                if not curEB or IsEditBoxSecretOrBNWhisper(curEB) then return end
                local curDB = EnsureDB()
                local curTop = (curDB.editBoxPosition == "TOP")
                DynamicChat._applyingEditBoxPos = true
                pcall(function()
                    if curEB.SetClampRectInsets then curEB:SetClampRectInsets(0, 0, 0, 0) end
                    if curEB.SetClampedToScreen then curEB:SetClampedToScreen(false) end
                    curEB:ClearAllPoints()
                    if curTop then
                        curEB:SetPoint("TOPLEFT", cf1, "TOPLEFT", 0, 0)
                        curEB:SetPoint("BOTTOMRIGHT", cf1, "TOPRIGHT", 0, -26)
                    else
                        curEB:SetPoint("BOTTOMLEFT", cf1, "BOTTOMLEFT", 0, 0)
                        curEB:SetPoint("TOPRIGHT", cf1, "BOTTOMRIGHT", 0, 26)
                    end
                end)
                DynamicChat._applyingEditBoxPos = false
            end
            if not editBox1PosHooked and type(eb1.SetPoint) == "function" then
                editBox1PosHooked = true
                hooksecurefunc(eb1, "SetPoint", function()
                    if DynamicChat._applyingEditBoxPos or DynamicChat._dsDragging or DynamicChat._dsEditModeActive then return end
                    if InCombatLockdown and InCombatLockdown() then
                        DynamicChat._pendingChatPosAfterCombat = true
                        return
                    end
                    if not DynamicChat:IsChatFrameLayoutOwned() then return end
                    local curDB = EnsureDB()
                    if curDB.enableSleekChatSkin == false or IsEllesmereUILoaded() then return end
                    local cf1Now = _G.ChatFrame1
                    if cf1Now then
                        cf1 = cf1Now
                        ApplyEditBoxAnchorNow()
                    end
                end)
            end
            local anchorKey = tostring(cf1) .. ":" .. (isTopEB and "TOP" or "BOT")
            local okPt, _, relTo = pcall(eb1.GetPoint, eb1, 1)
            if state.anchorKey ~= anchorKey or not okPt or relTo ~= cf1 then
                state.anchorKey = anchorKey
                ApplyEditBoxAnchorNow()
            end
        end
        local cf1Scale = (cf1 and cf1.GetScale and cf1:GetScale()) or 1.0
        if ebBar.SetScale then pcall(ebBar.SetScale, ebBar, cf1Scale) end
        ebBar:ClearAllPoints()
        if cf1 then
            if isTopEB then
                ebBar:SetPoint("TOPLEFT", cf1, "TOPLEFT", 0, 0)
                ebBar:SetPoint("BOTTOMRIGHT", cf1, "TOPRIGHT", 0, -26)
            else
                ebBar:SetPoint("BOTTOMLEFT", cf1, "BOTTOMLEFT", 0, 0)
                ebBar:SetPoint("TOPRIGHT", cf1, "BOTTOMRIGHT", 0, 26)
            end
        else
            ebBar:SetPoint("TOPLEFT", _G.ChatFrame1EditBox, "TOPLEFT", 2, -2)
            ebBar:SetPoint("BOTTOMRIGHT", _G.ChatFrame1EditBox, "BOTTOMRIGHT", -2, 2)
        end
        local hasFocus = DynamicChat.SafeEditBoxHasFocus(_G.ChatFrame1EditBox)
        RefreshSleekEditBoxBarColor(_G.ChatFrame1EditBox, hasFocus)
        ebBar:SetShown((hasFocus or alwaysShadedEB) and true or false)
    else
        ebBar:Hide()
    end

    if not editBoxFocusCallbacksHooked then
        editBoxFocusCallbacksHooked = true
        if _G.EventRegistry and type(_G.EventRegistry.RegisterCallback) == "function" then
            _G.EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusGained", function(_, editBox)
                DynamicChat._editBoxFocused = true
                if DynamicChat:IsExternalChatEngineLoaded() or IsEllesmereUILoaded() or EnsureDB().enableSleekChatSkin == false then
                    if chatEditBoxSkin then chatEditBoxSkin:Hide() end
                    return
                end
                local curDB = EnsureDB()
                local isTopEB = (curDB.editBoxPosition == "TOP")
                local bar = EnsureSleekEditBoxBar()
                local targetBox = editBox or _G.ChatFrame1EditBox
                if targetBox then
                    -- Never mutate targetBox anchors inside OnEditBoxFocusGained (which runs during Activate -> UpdateHeader);
                    -- only position our external UIParent-hosted bar.
                    local cf1 = _G.ChatFrame1
                    bar:ClearAllPoints()
                    if cf1 and targetBox == _G.ChatFrame1EditBox then
                        if isTopEB then
                            bar:SetPoint("TOPLEFT", cf1, "TOPLEFT", 0, 0)
                            bar:SetPoint("BOTTOMRIGHT", cf1, "TOPRIGHT", 0, -26)
                        else
                            bar:SetPoint("BOTTOMLEFT", cf1, "BOTTOMLEFT", 0, 0)
                            bar:SetPoint("TOPRIGHT", cf1, "BOTTOMRIGHT", 0, 26)
                        end
                    else
                        bar:SetPoint("TOPLEFT", targetBox, "TOPLEFT", 2, -2)
                        bar:SetPoint("BOTTOMRIGHT", targetBox, "BOTTOMRIGHT", -2, 2)
                    end
                    RefreshSleekEditBoxBarColor(targetBox, true)
                    bar:Show()
                end
            end, DynamicChat)

            _G.EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusLost", function()
                DynamicChat._editBoxFocused = false
                if not chatEditBoxSkin then return end
                local curDB = EnsureDB()
                if DynamicChat:IsExternalChatEngineLoaded() or curDB.enableSleekChatSkin == false or curDB.editBoxBackgroundMode == "FOCUS_ONLY" then
                    chatEditBoxSkin:Hide()
                else
                    RefreshSleekEditBoxBarColor(_G.ChatFrame1EditBox, false)
                    chatEditBoxSkin:Show()
                end
            end, DynamicChat)
        end

        if type(_G.ChatEdit_UpdateHeader) == "function" then
            hooksecurefunc("ChatEdit_UpdateHeader", function(editBox)
                if not editBox then return end
                if IsEditBoxSecretOrBNWhisper(editBox) then
                    return
                end
                if not DynamicChat:IsExternalChatEngineLoaded() and EnsureDB().enableSleekChatSkin ~= false then
                    RefreshSleekEditBoxBarColor(editBox)
                end
            end)
        end

        local function OnBlizzardChatBackgroundUpdate(chatFrame)
            if DynamicChat:IsExternalChatEngineLoaded() then return end
            local db = EnsureDB()
            local cf1 = _G.ChatFrame1
            if cf1 and type(db.chatFramePos) == "table" and not DynamicChat._dsEditModeActive and not DynamicChat._dsDragging and not (InCombatLockdown and InCombatLockdown()) then
                pcall(function()
                    if cf1.SetClampRectInsets then cf1:SetClampRectInsets(0, 0, 0, 0) end
                    if cf1.SetClampedToScreen then cf1:SetClampedToScreen(false) end
                end)
            end
            if db.enableSleekChatSkin == false then return end
            if chatFrame and type(chatFrame) == "table" and type(chatFrame.GetName) == "function" then
                SuppressBlizzardChatBackground(chatFrame, chatFrame:GetName(), true)
            else
                for idx = 1, 10 do
                    local f = _G["ChatFrame" .. idx]
                    if f then SuppressBlizzardChatBackground(f, "ChatFrame" .. idx, true) end
                end
            end
        end

        if type(_G.FCF_SetWindowAlpha) == "function" then
            hooksecurefunc("FCF_SetWindowAlpha", OnBlizzardChatBackgroundUpdate)
        end
        if type(_G.FCF_SetWindowColor) == "function" then
            hooksecurefunc("FCF_SetWindowColor", OnBlizzardChatBackgroundUpdate)
        end
        if type(_G.FloatingChatFrame_UpdateBackgroundAnchors) == "function" then
            hooksecurefunc("FloatingChatFrame_UpdateBackgroundAnchors", OnBlizzardChatBackgroundUpdate)
        end
        if type(_G.FCF_FadeInChatFrame) == "function" then
            hooksecurefunc("FCF_FadeInChatFrame", OnBlizzardChatBackgroundUpdate)
        end
        if type(_G.FCF_FadeOutChatFrame) == "function" then
            hooksecurefunc("FCF_FadeOutChatFrame", OnBlizzardChatBackgroundUpdate)
        end

        local dockUpdatePending = false
        local function OnBlizzardDockOrTabUpdate()
            if dockUpdatePending then return end
            dockUpdatePending = true
            local function RunDockSync()
                dockUpdatePending = false
                if not DynamicChat:IsExternalChatEngineLoaded() then
                    if EnsureDB().enableSleekChatSkin ~= false then
                        DynamicChat:ApplySleekChatSkin()
                    end
                    if DynamicChat.HookAllChatFramesAndEditBoxes then
                        DynamicChat:HookAllChatFramesAndEditBoxes()
                    end
                    if DynamicChat.OptimizeCombatLogTab then
                        DynamicChat:OptimizeCombatLogTab()
                    end
                end
            end
            if _G.C_Timer and type(_G.C_Timer.After) == "function" then
                _G.C_Timer.After(0, RunDockSync)
            else
                RunDockSync()
            end
        end

        if type(_G.FCF_SelectDockFrame) == "function" then
            hooksecurefunc("FCF_SelectDockFrame", function(selectedFrame)
                if DynamicChat:IsExternalChatEngineLoaded() then return end
                local db = EnsureDB()
                if db.enableSleekChatSkin ~= false then
                    if selectedFrame then
                        pendingEnsureSelectedTabVisible = selectedFrame
                        local selEntry = chatSkinStore[selectedFrame]
                        if selEntry then selEntry.isAlerting = false end
                    end
                    local ar, ag, ab = GetSuiteAccent()
                    local syncFont = (db.applySuiteChatFont ~= false)
                    local fontPath = GetFontPath()
                    LayoutDockedChatTabs(true, syncFont, fontPath, ar, ag, ab)
                    local frames = CollectAllChatFrames()
                    for _, item in ipairs(frames) do
                        local cf = item.cf
                        local cfName = item.name
                        local tab = _G[cfName .. "Tab"]
                        if cf and tab then
                            StyleSingleChatTab(cf, tab, cfName, true, syncFont, fontPath, ar, ag, ab)
                        end
                        if cf then
                            local entry = chatSkinStore[cf]
                            if entry then
                                if cf == selectedFrame or DynamicChat.SafeFrameIsShown(cf, false) then
                                    ReskinChatScrollBarAndBottomButton(cf, entry, true)
                                else
                                    if entry.customScrollBar then
                                        entry.customScrollBar:Hide()
                                    end
                                    if entry.scrollThumbFrame then
                                        entry.scrollThumbFrame:Hide()
                                    end
                                end
                            end
                        end
                    end
                    DynamicChat:RefreshLeftRailTelemetry()
                end
                if DynamicChat.OptimizeCombatLogTab then
                    DynamicChat:OptimizeCombatLogTab()
                end
            end)
        end
        if type(_G.FCF_StartAlertFlash) == "function" then
            hooksecurefunc("FCF_StartAlertFlash", function(chatFrame)
                if DynamicChat:IsExternalChatEngineLoaded() or EnsureDB().enableSleekChatSkin == false then return end
                if not chatFrame then return end
                local entry = chatSkinStore[chatFrame]
                if not entry then
                    entry = {}
                    chatSkinStore[chatFrame] = entry
                end
                if _G.SELECTED_DOCK_FRAME ~= chatFrame then
                    entry.isAlerting = true
                end
                local a1, a2, a3 = GetSuiteAccent()
                local syncFont = EnsureDB().applySuiteChatFont ~= false
                local fontPath = GetFontPath()
                if InCombatLockdown and InCombatLockdown() then
                    local cfName = (chatFrame.GetName and chatFrame:GetName()) or nil
                    local tab = cfName and _G[cfName .. "Tab"]
                    if tab then
                        StyleSingleChatTab(chatFrame, tab, cfName, true, syncFont, fontPath, a1, a2, a3)
                    end
                    RefreshTabNavButtonsVisuals(a1, a2, a3)
                    return
                end
                LayoutDockedChatTabs(true, syncFont, fontPath, a1, a2, a3)
            end)
        end
        if type(_G.FCF_StopAlertFlash) == "function" then
            hooksecurefunc("FCF_StopAlertFlash", function(chatFrame)
                if DynamicChat:IsExternalChatEngineLoaded() or EnsureDB().enableSleekChatSkin == false then return end
                if not chatFrame then return end
                local entry = chatSkinStore[chatFrame]
                if entry then
                    entry.isAlerting = false
                end
                local a1, a2, a3 = GetSuiteAccent()
                local syncFont = EnsureDB().applySuiteChatFont ~= false
                local fontPath = GetFontPath()
                if InCombatLockdown and InCombatLockdown() then
                    local cfName = (chatFrame.GetName and chatFrame:GetName()) or nil
                    local tab = cfName and _G[cfName .. "Tab"]
                    if tab then
                        StyleSingleChatTab(chatFrame, tab, cfName, true, syncFont, fontPath, a1, a2, a3)
                    end
                    RefreshTabNavButtonsVisuals(a1, a2, a3)
                    return
                end
                LayoutDockedChatTabs(true, syncFont, fontPath, a1, a2, a3)
            end)
        end
        local function OnBlizzardImmediateTabLayout()
            if not DynamicChat:IsExternalChatEngineLoaded() and EnsureDB().enableSleekChatSkin ~= false then
                local a1, a2, a3 = GetSuiteAccent()
                LayoutDockedChatTabs(true, EnsureDB().applySuiteChatFont ~= false, GetFontPath(), a1, a2, a3)
            end
            OnBlizzardDockOrTabUpdate()
        end
        if type(_G.FCF_OpenTemporaryWindow) == "function" then
            hooksecurefunc("FCF_OpenTemporaryWindow", OnBlizzardImmediateTabLayout)
        end
        if type(_G.FCF_SetTemporaryWindowType) == "function" then
            hooksecurefunc("FCF_SetTemporaryWindowType", OnBlizzardImmediateTabLayout)
        end
        if type(_G.FCFDock_UpdateTabs) == "function" then
            hooksecurefunc("FCFDock_UpdateTabs", OnBlizzardImmediateTabLayout)
        end
        if type(_G.FCF_Close) == "function" then
            hooksecurefunc("FCF_Close", OnBlizzardImmediateTabLayout)
        end
        if type(_G.FCF_DockUpdate) == "function" then
            hooksecurefunc("FCF_DockUpdate", OnBlizzardImmediateTabLayout)
        end
        if type(_G.FCF_SetWindowName) == "function" then
            hooksecurefunc("FCF_SetWindowName", OnBlizzardImmediateTabLayout)
        end
        if type(_G.FCF_CopyChatSettings) == "function" then
            hooksecurefunc("FCF_CopyChatSettings", OnBlizzardImmediateTabLayout)
        end
        if type(_G.FCFTab_UpdateAlpha) == "function" then
            hooksecurefunc("FCFTab_UpdateAlpha", function(chatFrame)
                if DynamicChat:IsExternalChatEngineLoaded() or EnsureDB().enableSleekChatSkin == false then return end
                if not chatFrame or type(chatFrame.GetName) ~= "function" then return end
                local cfName = chatFrame:GetName()
                local tab = cfName and _G[cfName .. "Tab"]
                if tab then
                    local a1, a2, a3 = GetSuiteAccent()
                    StyleSingleChatTab(chatFrame, tab, cfName, true, EnsureDB().applySuiteChatFont ~= false, GetFontPath(), a1, a2, a3)
                end
            end)
        end
        if type(_G.FCFTab_UpdateColors) == "function" then
            hooksecurefunc("FCFTab_UpdateColors", function(tab)
                if DynamicChat:IsExternalChatEngineLoaded() or EnsureDB().enableSleekChatSkin == false then return end
                if not tab or type(tab.GetName) ~= "function" then return end
                local tabName = tab:GetName()
                local cfName = tabName and tabName:match("^(ChatFrame%d+)Tab$")
                local cf = cfName and _G[cfName]
                if cf then
                    local a1, a2, a3 = GetSuiteAccent()
                    StyleSingleChatTab(cf, tab, cfName, true, EnsureDB().applySuiteChatFont ~= false, GetFontPath(), a1, a2, a3)
                end
            end)
        end
    end
end

local function RefreshChatFrameTextLayout()
    -- Retail 12.1.5 Zero-Taint Guard:
    -- Never call cf:ScrollUp(), cf:ScrollDown(), or cf:ScrollToBottom() from timers or position updates,
    -- which mutates ScrollingMessageFrameMixin state on ChatFrame1.
end

local chatPosReassertPending = false
local function ScheduleChatPosReassert()
    if chatPosReassertPending then return end
    chatPosReassertPending = true
    local function RunReassert()
        chatPosReassertPending = false
        if DynamicChat:IsExternalChatEngineLoaded() then return end
        local cf = _G.ChatFrame1
        if not cf or DynamicChat._applyingChatPos or DynamicChat._dsDragging or DynamicChat._dsEditModeActive then return end
        local db = EnsureDB()
        if type(db.chatFramePos) == "table" and not (InCombatLockdown and InCombatLockdown()) then
            DynamicChat:ApplySavedChatFramePosition()
        end
    end
    if _G.C_Timer and type(_G.C_Timer.After) == "function" then
        _G.C_Timer.After(0, RunReassert)
    else
        RunReassert()
    end
end

function DynamicChat:ApplySavedChatFramePosition()
    if not self:IsChatFrameLayoutOwned() then
        self:HideHudEditMover()
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        self._pendingChatPosAfterCombat = true
        return
    end
    local cf = _G.ChatFrame1
    if not cf then return end

    if not chatFrame1PosHooked and type(cf.SetPoint) == "function" then
        chatFrame1PosHooked = true
        local function OnExternalChatGeometryChange()
            if DynamicChat._applyingChatPos or DynamicChat._dsDragging or DynamicChat._dsEditModeActive then return end
            if not DynamicChat:IsChatFrameLayoutOwned() then return end
            local db = EnsureDB()
            if type(db.chatFramePos) == "table" then
                if InCombatLockdown and InCombatLockdown() then
                    DynamicChat._pendingChatPosAfterCombat = true
                elseif cf then
                    pcall(function()
                        if cf.SetClampRectInsets then cf:SetClampRectInsets(0, 0, 0, 0) end
                        if cf.SetClampedToScreen then cf:SetClampedToScreen(false) end
                        cf:SetUserPlaced(true)
                    end)
                    DynamicChat:ApplySavedChatFramePosition()
                end
                ScheduleChatPosReassert()
            end
        end
        hooksecurefunc(cf, "SetPoint", OnExternalChatGeometryChange)
        if type(cf.SetSize) == "function" then
            hooksecurefunc(cf, "SetSize", OnExternalChatGeometryChange)
        end
        if type(cf.SetWidth) == "function" then
            hooksecurefunc(cf, "SetWidth", OnExternalChatGeometryChange)
        end
        if type(cf.SetHeight) == "function" then
            hooksecurefunc(cf, "SetHeight", OnExternalChatGeometryChange)
        end
        if type(cf.ApplySystemAnchor) == "function" then
            hooksecurefunc(cf, "ApplySystemAnchor", OnExternalChatGeometryChange)
        end
        if _G.EditModeChatFrameSystemMixin and type(_G.EditModeChatFrameSystemMixin.ApplySystemAnchor) == "function" then
            hooksecurefunc(_G.EditModeChatFrameSystemMixin, "ApplySystemAnchor", function(frame)
                if frame == _G.ChatFrame1 then
                    OnExternalChatGeometryChange()
                end
            end)
        end
        if type(_G.FCF_RestorePositionAndDimensions) == "function" then
            hooksecurefunc("FCF_RestorePositionAndDimensions", function(chatFrame)
                if chatFrame ~= _G.ChatFrame1 then return end
                OnExternalChatGeometryChange()
            end)
        end
        if type(_G.FCF_SavePositionAndDimensions) == "function" then
            hooksecurefunc("FCF_SavePositionAndDimensions", function(chatFrame)
                if chatFrame ~= _G.ChatFrame1 then return end
                OnExternalChatGeometryChange()
            end)
        end
        if type(_G.FCF_PositionChatFrame) == "function" then
            hooksecurefunc("FCF_PositionChatFrame", function(chatFrame)
                if chatFrame ~= _G.ChatFrame1 then return end
                OnExternalChatGeometryChange()
            end)
        end
        if type(_G.FloatingChatFrame_UpdateBackgroundAnchors) == "function" then
            hooksecurefunc("FloatingChatFrame_UpdateBackgroundAnchors", function(chatFrame)
                if chatFrame ~= _G.ChatFrame1 then return end
                if DynamicChat._applyingChatPos or DynamicChat._dsDragging or DynamicChat._dsEditModeActive then return end
                if not DynamicChat:IsChatFrameLayoutOwned() then return end
                local db = EnsureDB()
                if type(db.chatFramePos) == "table" then
                    if InCombatLockdown and InCombatLockdown() then
                        DynamicChat._pendingChatPosAfterCombat = true
                    else
                        pcall(function()
                            if chatFrame.SetClampRectInsets then chatFrame:SetClampRectInsets(0, 0, 0, 0) end
                            if chatFrame.SetClampedToScreen then chatFrame:SetClampedToScreen(false) end
                            chatFrame:SetUserPlaced(true)
                        end)
                        OnExternalChatGeometryChange()
                    end
                end
            end)
        end
        if type(_G.UIParent_ManageFramePositions) == "function" then
            hooksecurefunc("UIParent_ManageFramePositions", OnExternalChatGeometryChange)
        end
        if _G.EditModeManagerFrame and type(_G.EditModeManagerFrame.UpdateSystemAnchorInfo) == "function" then
            hooksecurefunc(_G.EditModeManagerFrame, "UpdateSystemAnchorInfo", function(self, frame)
                if frame == _G.ChatFrame1 then
                    OnExternalChatGeometryChange()
                end
            end)
        end
        if _G.EditModeManagerFrame and type(_G.EditModeManagerFrame.UpdateSystems) == "function" then
            hooksecurefunc(_G.EditModeManagerFrame, "UpdateSystems", OnExternalChatGeometryChange)
        end
        if _G.EditModeManagerFrame and type(_G.EditModeManagerFrame.UpdateBottomActionBarPositions) == "function" then
            hooksecurefunc(_G.EditModeManagerFrame, "UpdateBottomActionBarPositions", OnExternalChatGeometryChange)
        end
        if _G.EditModeManagerFrame and type(_G.EditModeManagerFrame.RestoreLayouts) == "function" then
            hooksecurefunc(_G.EditModeManagerFrame, "RestoreLayouts", OnExternalChatGeometryChange)
        end
        if _G.EditModeManagerFrame and type(_G.EditModeManagerFrame.OnEditModeExit) == "function" then
            hooksecurefunc(_G.EditModeManagerFrame, "OnEditModeExit", OnExternalChatGeometryChange)
        end
        if _G.EditModeManagerFrame and type(_G.EditModeManagerFrame.ExitEditMode) == "function" then
            hooksecurefunc(_G.EditModeManagerFrame, "ExitEditMode", OnExternalChatGeometryChange)
        end
        if type(cf.HookScript) == "function" then
            pcall(cf.HookScript, cf, "OnShow", OnExternalChatGeometryChange)
        end
    end

    local db = EnsureDB()
    local pos = db.chatFramePos
    self._applyingChatPos = true
    pcall(function()
        cf:SetMovable(true)
        cf:SetResizable(true)
        cf:SetUserPlaced(true)
        local sc = tonumber(db.chatFrameScale)
        if sc and sc >= 0.50 and sc <= 2.00 then
            cf:SetScale(sc)
        end
        -- Disable C++ SetClampedToScreen whenever DynamicChat manages ChatFrame1 because ClampChatFrameCoords
        -- performs exact visible-container clamping and Blizzard's FloatingChatFrame_UpdateBackgroundAnchors
        -- resets C++ ClampRectInsets to (-35, 35, 26, -50), which would push ChatFrame1 ~30px above bottom!
        if cf.SetClampRectInsets then cf:SetClampRectInsets(0, 0, 0, 0) end
        if cf.SetClampedToScreen then cf:SetClampedToScreen(false) end
        if _G.ChatFrame1Background then
            if _G.ChatFrame1Background.SetClampRectInsets then _G.ChatFrame1Background:SetClampRectInsets(0, 0, 0, 0) end
            if _G.ChatFrame1Background.SetClampedToScreen then _G.ChatFrame1Background:SetClampedToScreen(false) end
        end
        if _G.ChatFrame1EditBox and not IsEditBoxSecretOrBNWhisper(_G.ChatFrame1EditBox) then
            if _G.ChatFrame1EditBox.SetClampRectInsets then _G.ChatFrame1EditBox:SetClampRectInsets(0, 0, 0, 0) end
            if _G.ChatFrame1EditBox.SetClampedToScreen then _G.ChatFrame1EditBox:SetClampedToScreen(false) end
        end

        if type(pos) ~= "table" then
            local _, _, initX, initY, initW, initH = self:GetLiveOuterBottomLeft()
            pos = {
                point         = "BOTTOMLEFT",
                relativePoint = "BOTTOMLEFT",
                relPoint      = "BOTTOMLEFT",
                x             = initX,
                y             = initY,
                width         = initW,
                height        = initH,
            }
            db.chatFramePos = pos
        end

        local anchorPt = pos.point or pos.relativePoint or pos.relPoint or "BOTTOMLEFT"
        local clampedX, clampedY, clampedW, clampedH = self:ClampChatFrameCoords(
            tonumber(pos.x) or 0,
            tonumber(pos.y) or 0,
            tonumber(pos.width) or (cf:GetWidth() or 430),
            tonumber(pos.height) or (cf:GetHeight() or 200),
            anchorPt
        )
        pos.point         = "BOTTOMLEFT"
        pos.relativePoint = "BOTTOMLEFT"
        pos.relPoint      = "BOTTOMLEFT"
        pos.x             = clampedX
        pos.y             = clampedY
        pos.width         = clampedW
        pos.height        = clampedH

        local leftExt, rightExt, topExt, bottomExt = self:GetVisibleContainerExtents()
        local prevW = cf:GetWidth() or 0
        local prevH = cf:GetHeight() or 0
        local skinEntry = chatSkinStore and chatSkinStore[cf]
        local outerPanel = skinEntry and skinEntry.panel
        cf:SetSize(clampedW, clampedH)
        cf:ClearAllPoints()
        cf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", leftExt + clampedX, bottomExt + clampedY)
        if outerPanel and db.enableSleekChatSkin ~= false then
            if outerPanel.SetScale then pcall(outerPanel.SetScale, outerPanel, (cf.GetScale and cf:GetScale()) or 1.0) end
            if outerPanel.SetClampRectInsets then outerPanel:SetClampRectInsets(0, 0, 0, 0) end
            if outerPanel.SetClampedToScreen then outerPanel:SetClampedToScreen(false) end
            outerPanel:ClearAllPoints()
            outerPanel:SetPoint("TOPLEFT", cf, "TOPLEFT", -leftExt, topExt)
            outerPanel:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", rightExt, -bottomExt)
        end
        if math.abs(prevW - clampedW) > 0.5 or math.abs(prevH - clampedH) > 0.5 then
            RefreshChatFrameTextLayout(cf)
        end
    end)
    self._applyingChatPos = false
    self:ApplySleekChatSkin()
end

function DynamicChat:SaveChatFramePosition(pt, relPt, x, y, w, h)
    if not self:IsChatFrameLayoutOwned() then return end
    local cf = _G.ChatFrame1
    local db = EnsureDB()
    db.chatAnchorVersion = 5
    local curW = tonumber(w) or (cf and cf:GetWidth()) or 430
    local curH = tonumber(h) or (cf and cf:GetHeight()) or 200
    local anchorHint = (pt == "BOTTOMLEFT" or relPt == "BOTTOMLEFT") and "BOTTOMLEFT" or (pt or "BOTTOMLEFT")
    local clampedX, clampedY, clampedW, clampedH = self:ClampChatFrameCoords(
        tonumber(x) or 0,
        tonumber(y) or 0,
        curW,
        curH,
        anchorHint
    )
    db.chatFramePos = {
        point         = "BOTTOMLEFT",
        relativePoint = "BOTTOMLEFT",
        relPoint      = "BOTTOMLEFT",
        x             = clampedX,
        y             = clampedY,
        width         = clampedW,
        height        = clampedH,
    }
    self:ApplySavedChatFramePosition()
end

function DynamicChat:ResetChatFramePosition()
    local db = EnsureDB()
    db.chatFramePos = {
        point         = "BOTTOMLEFT",
        relativePoint = "BOTTOMLEFT",
        relPoint      = "BOTTOMLEFT",
        x             = 0,
        y             = 0,
        width         = 430,
        height        = 200,
    }
    db.chatFrameScale = 1.0
    db.chatBgAlpha = 0.25
    db.chatBorderStyle = "ACCENT"
    if not self:IsChatFrameLayoutOwned() then
        self:ApplySleekChatSkin()
        return
    end
    local cf = _G.ChatFrame1
    if cf and not (InCombatLockdown and InCombatLockdown()) then
        self._applyingChatPos = true
        pcall(function()
            cf:SetScale(1.0)
            cf:SetSize(430, 200)
        end)
        self._applyingChatPos = false
    end
    self:ApplySavedChatFramePosition()
    self:ApplySleekChatSkin()
end

function DynamicChat:ApplyShortChannelNames()
    -- Retail 12.1.5 Zero-Taint Guard:
    -- Never overwrite _G.CHAT_RAID_GET, _G.CHAT_PARTY_GET, _G.CHAT_INSTANCE_CHAT_GET, etc.
    -- In Retail 12.1.5 Raids & Mythic+, Blizzard's ChatFrameMixin:MessageEventHandler
    -- concatenates _G["CHAT_"..type.."_GET"] .. arg1 where arg1 and playerLink are
    -- <secret string> values. Mutating _G.CHAT_*_GET taints that global slot and throws:
    -- "attempt to perform string conversion on a secret string value (execution tainted by 'DynamicChat')".
end

function DynamicChat:ApplyClassColorNames()
    if InCombatLockdown and InCombatLockdown() then return end
    if self:IsExternalChatEngineLoaded() then return end
    if self:IsYieldingSharedHooks() and self:HasActivePartialSuiteConflict() then return end
    local db = EnsureDB()
    if _G.C_CVar and type(_G.C_CVar.SetCVar) == "function" then
        local targetVal = (db.classColorNames ~= false) and "0" or "1"
        local curVal = nil
        if type(_G.C_CVar.GetCVar) == "function" then
            local ok, v = pcall(_G.C_CVar.GetCVar, "chatClassColorOverride")
            if ok and not IsSecretValue(v) then curVal = tostring(v) end
        end
        if curVal ~= targetVal then
            if _G.DynamicSuite and _G.DynamicSuite.SnapshotCVar then
                _G.DynamicSuite.SnapshotCVar("chatClassColorOverride")
            end
            pcall(_G.C_CVar.SetCVar, "chatClassColorOverride", targetVal)
        end
    end
end

function DynamicChat:ApplyTimestampSettings()
    if InCombatLockdown and InCombatLockdown() then return end
    if self:IsExternalChatEngineLoaded() then return end
    if self:IsYieldingSharedHooks() and self:HasActivePartialSuiteConflict() then return end
    local db = EnsureDB()
    if _G.C_CVar and type(_G.C_CVar.SetCVar) == "function" then
        local fmt = "none"
        if db.showTimestamps ~= false and type(db.timestampFormat) == "string" and db.timestampFormat ~= "" and db.timestampFormat ~= "none" then
            fmt = db.timestampFormat
        end
        local curVal = nil
        if type(_G.C_CVar.GetCVar) == "function" then
            local ok, v = pcall(_G.C_CVar.GetCVar, "showTimestamps")
            if ok and not IsSecretValue(v) then curVal = tostring(v) end
        end
        if curVal ~= fmt then
            if _G.DynamicSuite and _G.DynamicSuite.SnapshotCVar then
                _G.DynamicSuite.SnapshotCVar("showTimestamps")
            end
            pcall(_G.C_CVar.SetCVar, "showTimestamps", fmt)
        end
    end
end

-- Sleek Obsidian 1-Line URL Copy Dialog (DynamicChatCopyPopup)
local urlCopyPopup = nil

local function EnsureURLCopyPopup()
    if urlCopyPopup then return urlCopyPopup end

    local pop = CreateFrame("Frame", "DynamicChatCopyPopup", UIParent, "BackdropTemplate")
    pop:SetSize(500, 96)
    pop:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
    pop:SetFrameStrata("DIALOG")
    pop:SetToplevel(true)
    pop:SetClampedToScreen(true)
    pop:SetMovable(true)
    pop:EnableMouse(true)
    pop:RegisterForDrag("LeftButton")
    pop:SetScript("OnDragStart", pop.StartMoving)
    pop:SetScript("OnDragStop", pop.StopMovingOrSizing)
    pop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    local ar, ag, ab = GetSuiteAccent()
    pop:SetBackdropColor(0.035, 0.039, 0.051, 0.98) -- #090A0D
    pop:SetBackdropBorderColor(ar, ag, ab, 0.95)
    SafeRegisterUISpecialFrame("DynamicChatCopyPopup")

    local topBar = pop:CreateTexture(nil, "OVERLAY")
    topBar:SetHeight(2)
    topBar:SetPoint("TOPLEFT", pop, "TOPLEFT", 1, -1)
    topBar:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -1, -1)
    topBar:SetColorTexture(ar, ag, ab, 1.0)
    pop.topBar = topBar

    local closeBtn = CreateFrame("Button", nil, pop, "BackdropTemplate")
    closeBtn:SetSize(22, 20)
    closeBtn:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -8, -6)
    closeBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    closeBtn:SetBackdropColor(0.078, 0.090, 0.122, 0.96)
    closeBtn:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95)
    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(closeTxt, 10, "")
    closeTxt:SetPoint("CENTER", 0, 0)
    closeTxt:SetTextColor(0.92, 0.95, 0.99, 1.0)
    closeTxt:SetText("X")
    closeBtn:SetScript("OnClick", function() pop:Hide() end)
    pop.closeBtn = closeBtn

    local title = pop:CreateFontString(nil, "OVERLAY")
    SetSafeFont(title, 11, "")
    title:SetPoint("TOPLEFT", pop, "TOPLEFT", 14, -10)
    title:SetPoint("RIGHT", closeBtn, "LEFT", -12, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetTextColor(ar, ag, ab, 1.0)
    title:SetText("COPY LINK")
    pop.title = title

    local boxWrap = CreateFrame("Frame", nil, pop, "BackdropTemplate")
    boxWrap:SetPoint("TOPLEFT", pop, "TOPLEFT", 14, -30)
    boxWrap:SetPoint("BOTTOMRIGHT", pop, "BOTTOMRIGHT", -14, 26)
    boxWrap:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    boxWrap:SetBackdropColor(0.055, 0.063, 0.082, 0.98) -- #0E1015
    boxWrap:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95) -- #252A36
    pop.boxWrap = boxWrap

    local hint = pop:CreateFontString(nil, "OVERLAY")
    SetSafeFont(hint, 9.5, "")
    hint:SetPoint("BOTTOMLEFT", pop, "BOTTOMLEFT", 14, 8)
    hint:SetPoint("BOTTOMRIGHT", pop, "BOTTOMRIGHT", -14, 8)
    hint:SetJustifyH("RIGHT")
    hint:SetWordWrap(false)
    hint:SetTextColor(0.58, 0.64, 0.72, 1.0)
    hint:SetText("Press Ctrl+C to copy  |  Esc to close")
    pop.hint = hint

    local eb = CreateFrame("EditBox", "DynamicChatCopyPopupEditBox", boxWrap)
    eb:SetAutoFocus(false)
    if _G.ChatFontNormal then
        eb:SetFontObject(_G.ChatFontNormal)
    end
    eb:SetPoint("LEFT", boxWrap, "LEFT", 10, 0)
    eb:SetPoint("RIGHT", boxWrap, "RIGHT", -10, 0)
    eb:SetHeight(24)
    SetSafeFont(eb, 11, "")
    eb:SetTextColor(0.97, 0.98, 1.00, 1.0)
    eb:SetScript("OnEscapePressed", function() pop:Hide() end)
    eb:SetScript("OnEnterPressed", function() pop:Hide() end)
    eb:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    eb:SetScript("OnMouseUp", function(self)
        self:HighlightText()
    end)
    eb:SetScript("OnChar", function(self)
        if pop.currentURL then
            self:SetText(pop.currentURL)
            self:HighlightText()
        end
    end)
    pop.editBox = eb

    pop:Hide()
    urlCopyPopup = pop
    return pop
end

function DynamicChat:ShowURLCopyPopup(url)
    if not url or IsSecretValue(url) or type(url) ~= "string" or url == "" then return end
    url = DecodeDynamicChatLinkPayload(url)
    DynamicChat._hasUnreadCapturedURL = false
    if DynamicChat.RefreshLeftRailTelemetry then
        DynamicChat:RefreshLeftRailTelemetry()
    end
    if railPopoverFrame and railPopoverFrame:IsShown() then
        railPopoverFrame:Hide()
    end
    if railPopoverClickCatcher and railPopoverClickCatcher:IsShown() then
        railPopoverClickCatcher:Hide()
    end
    local pop = EnsureURLCopyPopup()
    local ar, ag, ab = GetSuiteAccent()
    pop:SetBackdropBorderColor(ar, ag, ab, 0.95)
    if pop.topBar then pop.topBar:SetColorTexture(ar, ag, ab, 1.0) end
    if pop.title then
        SetSafeFont(pop.title, 11, "")
        pop.title:SetTextColor(ar, ag, ab, 1.0)
        pop.title:SetText("COPY LINK")
    end
    if pop.editBox then
        if _G.ChatFontNormal then
            pop.editBox:SetFontObject(_G.ChatFontNormal)
        end
        SetSafeFont(pop.editBox, 11, "")
    end
    pop.currentURL = url
    pop:Show()
    pop:Raise()
    pop.editBox:SetText(url)
    pop.editBox:SetFocus()
    pop.editBox:HighlightText()
end

local URL_MATCH_PATTERNS = {
    "(https?://[%w%._%-/%?&#=~%%:%+@!%$,;*%(%)]+)",
    "(www%.[%w%._%-/%?&#=~%%:%+@!%$,;*%(%)]+)",
    "(discord%.gg/[%w%._%-/%?&#=~%%]+)",
    "(wago%.io/[%w%._%-/%?&#=~%%]+)",
    "(curseforge%.com/[%w%._%-/%?&#=~%%]+)",
    "(raider%.io/[%w%._%-/%?&#=~%%:%+@!%$,;*%(%)]+)",
    "(wowhead%.com/[%w%._%-/%?&#=~%%:%+@!%$,;*%(%)]+)",
    "(mythictrap%.com/[%w%._%-/%?&#=~%%:%+@!%$,;*%(%)]+)",
    "(archon%.gg/[%w%._%-/%?&#=~%%:%+@!%$,;*%(%)]+)",
    "(warcraftlogs%.com/[%w%._%-/%?&#=~%%:%+@!%$,;*%(%)]+)",
    "(youtu%.be/[%w%._%-/%?&#=~%%:%+@!%$,;*%(%)]+)",
    "(youtube%.com/[%w%._%-/%?&#=~%%:%+@!%$,;*%(%)]+)",
}

local function EncodeDynamicChatLinkPayload(url)
    if type(url) ~= "string" then return "" end
    return (url:gsub("|", ""):gsub(":", "%%3A"))
end

local function HasCandidateURL(msg)
    if IsSecretValue(msg) or type(msg) ~= "string" then
        return false
    end
    local ok, found = pcall(function()
        if msg:find("https://", 1, true)
            or msg:find("http://", 1, true)
            or msg:find("discord.gg/", 1, true)
            or msg:find("wago.io/", 1, true)
            or msg:find("curseforge.com/", 1, true)
            or msg:find("raider.io/", 1, true)
            or msg:find("wowhead.com/", 1, true)
            or msg:find("mythictrap.com/", 1, true)
            or msg:find("archon.gg/", 1, true)
            or msg:find("warcraftlogs.com/", 1, true)
            or msg:find("youtu.be/", 1, true)
            or msg:find("youtube.com/", 1, true)
            or msg:find("www.", 1, true) then
            return true
        end
        return false
    end)
    return (ok and found == true) or false
end

local hookedEditBoxes  = {}
local hookedChatFrames = {}

local chatFrame2TabPreClickHooked = false

function DynamicChat:OptimizeCombatLogTab()
    if self:IsExternalChatEngineLoaded() then return end
    local db = EnsureDB()
    if db.optimizeCombatLogTab == false then return end

    local cf2 = _G.ChatFrame2
    if not cf2 then return end

    -- 1. Retail 12.1.5 Zero-Taint Guard:
    -- Never call cf2:SetMaxLines() on ChatFrame2 (which taints ChatFrame2.historyBuffer.maxElements).

    -- 2. Suppress the default CombatLogQuickButtonFrame filter bar so it never collides with the 24px Top Tab Header Bar or causes layout lag
    local qbfCustom = _G.CombatLogQuickButtonFrame_Custom
    local qbfMain   = _G.CombatLogQuickButtonFrame
    for _, qbf in ipairs({ qbfCustom, qbfMain }) do
        if qbf and db.enableSleekChatSkin ~= false then
            SetSideClutterButtonSuppressed(qbf, true)
            HookSuppressOnShow(qbf, false)
        end
    end

    -- 3. Hook ChatFrame2Tab PreClick once so switching to the Combat Log tab only trims runaway (> 1500) combat log backlogs while preserving post-wipe review
    local tab2 = _G.ChatFrame2Tab
    if tab2 and not chatFrame2TabPreClickHooked and type(tab2.HookScript) == "function" then
        chatFrame2TabPreClickHooked = true
        tab2:HookScript("PreClick", function()
            if DynamicChat:IsExternalChatEngineLoaded() or EnsureDB().optimizeCombatLogTab == false then return end
            local c2 = _G.ChatFrame2
            if not c2 then return end
            local shouldTrim = false
            if type(c2.GetNumMessages) == "function" then
                local okN, numM = pcall(c2.GetNumMessages, c2)
                if okN and not IsSecretValue(numM) and type(numM) == "number" and numM > 1500 then
                    shouldTrim = true
                end
            end
            if not shouldTrim and _G.Blizzard_CombatLog_CurrentSettings and type(_G.Blizzard_CombatLog_CurrentSettings.entries) == "table" then
                if #_G.Blizzard_CombatLog_CurrentSettings.entries > 1500 then
                    shouldTrim = true
                end
            end
            if shouldTrim then
                if type(_G.Blizzard_CombatLog_Clear) == "function" then
                    pcall(_G.Blizzard_CombatLog_Clear)
                elseif type(c2.Clear) == "function" then
                    pcall(c2.Clear, c2)
                end
            end
        end)
    end
end

-- Chat History Retention & Combat Log Tab Optimizer
function DynamicChat:ApplyGPUBufferSettings()
    -- Retail 12.1.5 Zero-Taint Guard:
    -- Never call cf:SetMaxLines() on Blizzard's ChatFrame1 ScrollingMessageFrameMixin,
    -- which mutates self.historyBuffer.maxElements from addon code and taints self.historyBuffer
    -- when Raid/M+ <secret string> messages are pushed.
    self:OptimizeCombatLogTab()
end

local reloadHooksInstalled = false

function DynamicChat:SaveChatHistorySnapshot()
    local db = EnsureDB()
    if db.preserveChatHistory == false or db.enableGPUBufferCap == false then
        db.savedChatHistory = {}
        return
    end
    local cf = _G.ChatFrame1
    if not cf or type(cf.GetNumMessages) ~= "function" or type(cf.GetMessageInfo) ~= "function" then
        return
    end
    local okN, total = pcall(cf.GetNumMessages, cf)
    if not okN or IsSecretValue(total) or type(total) ~= "number" or total <= 0 then
        return
    end
    local maxSave = math.min(500, math.max(20, tonumber(db.maxChatLines) or 100))
    local startIdx = math.max(1, total - maxSave + 1)
    local out = {}
    for idx = startIdx, total do
        local okM, text, r, g, b = pcall(cf.GetMessageInfo, cf, idx)
        if okM and text and not IsSecretValue(text) and type(text) == "string" and text ~= "" then
            local okDiv, isDiv = pcall(string.find, text, "Chat History Restored", 1, true)
            if not (okDiv and isDiv) then
                local sr = (not IsSecretValue(r) and tonumber(r)) or 1
                local sg = (not IsSecretValue(g) and tonumber(g)) or 1
                local sb = (not IsSecretValue(b) and tonumber(b)) or 1
                out[#out + 1] = {
                    t = text,
                    r = math.floor(sr * 1000 + 0.5) / 1000,
                    g = math.floor(sg * 1000 + 0.5) / 1000,
                    b = math.floor(sb * 1000 + 0.5) / 1000,
                }
            end
        end
    end
    db.savedChatHistory = out
end

function DynamicChat:SaveChatHistoryOnLogout()
    return self:SaveChatHistorySnapshot()
end

function DynamicChat:RestoreChatHistorySnapshot()
    if self._chatHistoryRestored then return end
    self._chatHistoryRestored = true
    -- Retail 12.1.5 Zero-Taint Guard:
    -- Never call cf1:AddMessage() or cf1:ScrollToBottom() on Blizzard's live ChatFrame1,
    -- which taints cf1.historyBuffer and cf1.fontStringPool when secret strings arrive.
    -- Instead, db.savedChatHistory is preserved in memory and prepended above a
    -- "--- Saved From Previous Session ---" divider inside DynamicChat:ShowFullChatHistoryModal().
end

function DynamicChat:RestoreSavedChatHistory()
    return self:RestoreChatHistorySnapshot()
end

function DynamicChat:InstallReloadSnapshotHooks()
    if IsModuleDisabledInSuite("DynamicChat") then return end
    if reloadHooksInstalled then return end
    reloadHooksInstalled = true
    if type(_G.ReloadUI) == "function" then
        hooksecurefunc("ReloadUI", function()
            if not IsModuleDisabledInSuite("DynamicChat") then
                DynamicChat:SaveChatHistorySnapshot()
            end
        end)
    end
    if _G.C_UI and type(_G.C_UI.Reload) == "function" then
        hooksecurefunc(_G.C_UI, "Reload", function()
            if not IsModuleDisabledInSuite("DynamicChat") then
                DynamicChat:SaveChatHistorySnapshot()
            end
        end)
    end
end

local hookedEditBoxes = {}

function DynamicChat:HookAllChatFramesAndEditBoxes()
    if IsModuleDisabledInSuite("DynamicChat") then return end
    local allFrames = CollectAllChatFrames()
    for _, item in ipairs(allFrames) do
        local cf = item.cf
        if cf and cf.HookScript and not hookedChatFrames[cf] then
            hookedChatFrames[cf] = true
            cf:HookScript("OnMouseWheel", function(selfFrame, delta)
                local db = EnsureDB()
                if DynamicChat:IsExternalChatEngineLoaded() then return end
                if IsInCombatOrActiveKeystone() then return end
                if db.fastChatScroll and delta and not IsSecretValue(delta) and not (DynamicChat:IsYieldingSharedHooks() and DynamicChat:HasActivePartialSuiteConflict()) then
                    if IsControlKeyDown and IsControlKeyDown() and db.ctrlJumpScroll ~= false then
                        if delta > 0 then
                            if selfFrame.ScrollToTop then pcall(selfFrame.ScrollToTop, selfFrame) end
                        elseif delta < 0 then
                            if selfFrame.ScrollToBottom then pcall(selfFrame.ScrollToBottom, selfFrame) end
                        end
                    elseif IsShiftKeyDown and IsShiftKeyDown() then
                        local extra = math.max(1, (tonumber(db.shiftScrollLines) or 5) - 1)
                        if delta > 0 then
                            if selfFrame.ScrollUp then
                                for _ = 1, extra do pcall(selfFrame.ScrollUp, selfFrame) end
                            end
                        elseif delta < 0 then
                            if selfFrame.ScrollDown then
                                for _ = 1, extra do pcall(selfFrame.ScrollDown, selfFrame) end
                            end
                        end
                    end
                end
                DynamicChat:RefreshLeftRailTelemetry()
            end)
        end
    end

    local maxWindows = math.max(10, tonumber(_G.NUM_CHAT_WINDOWS) or 10)
    for i = 1, maxWindows do
        self:HookSingleEditBox(_G["ChatFrame" .. i .. "EditBox"])
    end
end

function DynamicChat:HookSingleEditBox(eb)
    if eb and eb.HookScript and not hookedEditBoxes[eb] then
        hookedEditBoxes[eb] = true
        eb:HookScript("OnTextChanged", function(selfEb)
            TryConvertTargetWhisperEditBox(selfEb, false)
        end)
    end
end

function DynamicChat:InstallChatHooks()
    if IsModuleDisabledInSuite("DynamicChat") then return end
    if self.hooksInstalled then return end
    self.hooksInstalled = true

    self:HookAllChatFramesAndEditBoxes()

    -- 2. Global EditBox Lifecycle Post-Hooks via hooksecurefunc (OnTextChanged + OnSpacePressed)
    if type(_G.ChatEdit_OnTextChanged) == "function" then
        hooksecurefunc("ChatEdit_OnTextChanged", function(editBox)
            TryConvertTargetWhisperEditBox(editBox, false)
        end)
    end
    if _G.ChatFrameEditBoxMixin and type(_G.ChatFrameEditBoxMixin.OnTextChanged) == "function" then
        hooksecurefunc(_G.ChatFrameEditBoxMixin, "OnTextChanged", function(editBox)
            TryConvertTargetWhisperEditBox(editBox, false)
        end)
    end
    if type(_G.ChatEdit_OnSpacePressed) == "function" then
        hooksecurefunc("ChatEdit_OnSpacePressed", function(editBox)
            TryConvertTargetWhisperEditBox(editBox, true)
        end)
    end
    if _G.ChatFrameEditBoxMixin and type(_G.ChatFrameEditBoxMixin.OnSpacePressed) == "function" then
        hooksecurefunc(_G.ChatFrameEditBoxMixin, "OnSpacePressed", function(editBox)
            TryConvertTargetWhisperEditBox(editBox, true)
        end)
    end
    if type(_G.FCF_OpenTemporaryWindow) == "function" then
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            DynamicChat:HookAllChatFramesAndEditBoxes()
        end)
    end
    if type(_G.ChatEdit_ActivateChat) == "function" then
        hooksecurefunc("ChatEdit_ActivateChat", function(editBox)
            DynamicChat:HookSingleEditBox(editBox)
            if DynamicChat:IsExternalChatEngineLoaded() then return end
            if not editBox then return end
            if IsEditBoxSecretOrBNWhisper(editBox) then
                return
            end
            if editBox.SetAltArrowKeyMode then
                local useAltMode = not (EnsureDB().arrowHistoryNoAlt == true)
                pcall(editBox.SetAltArrowKeyMode, editBox, useAltMode)
            end
        end)
    end

    -- 3. Retail 12.1.5 Zero-Taint Architecture:
    -- NEVER call ChatFrame_AddMessageEventFilter (zero filters in Blizzard's chatFilters table).
    -- _urlCaptureFrame is the sole, 100% isolated URL capture listener feeding DynamicChat._recentCapturedURLs,
    -- the Left Rail Copy button's unread accent dot + Shift-Click / Middle-Click 1-click Copy Latest Link popup,
    -- and DynamicChatHistoryModal's clickable "Recent Links:" pill bar.
    if not self._urlCaptureFrame then
        local capFrame = CreateFrame("Frame")
        local captureEvents = {
            "CHAT_MSG_WHISPER",
            "CHAT_MSG_WHISPER_INFORM",
            "CHAT_MSG_BN_WHISPER",
            "CHAT_MSG_BN_WHISPER_INFORM",
            "CHAT_MSG_PARTY",
            "CHAT_MSG_PARTY_LEADER",
            "CHAT_MSG_RAID",
            "CHAT_MSG_RAID_LEADER",
            "CHAT_MSG_RAID_WARNING",
            "CHAT_MSG_INSTANCE_CHAT",
            "CHAT_MSG_INSTANCE_CHAT_LEADER",
            "CHAT_MSG_GUILD",
            "CHAT_MSG_OFFICER",
            "CHAT_MSG_SAY",
            "CHAT_MSG_YELL",
            "CHAT_MSG_CHANNEL",
            "CHAT_MSG_COMMUNITIES_CHANNEL",
        }
        for _, ev in ipairs(captureEvents) do
            pcall(capFrame.RegisterEvent, capFrame, ev)
        end
        local reusableFoundList = {}
        local reusableSeenMap = {}
        capFrame:SetScript("OnEvent", function(_, event, msg)
            if IsModuleDisabledInSuite("DynamicChat") then return end
            if IsSecretValue(msg) then
                return
            end
            if IsInCombatOrActiveKeystone() then
                return
            end
            if type(msg) ~= "string" or msg == "" then
                return
            end
            if not HasCandidateURL(msg) then return end
            if type(reusableFoundList) == "table" then wipe(reusableFoundList) else reusableFoundList = {} end
            if type(reusableSeenMap) == "table" then wipe(reusableSeenMap) else reusableSeenMap = {} end
            ExtractURLsFromText(msg, reusableFoundList, reusableSeenMap)
            for _, cleanUrl in ipairs(reusableFoundList) do
                RecordCapturedSessionURL(cleanUrl, event)
            end
        end)
        self._urlCaptureFrame = capFrame
    end

    if not self.setItemRefHooked then
        self.setItemRefHooked = true
        local function HandleDynamicChatLinkClick(link)
            if not link or IsSecretValue(link) or type(link) ~= "string" then return end
            if DynamicChat:IsExternalChatEngineLoaded() then return end
            if DynamicChat:IsYieldingSharedHooks() and DynamicChat:HasActivePartialSuiteConflict() then return end
            local encoded = link:match("^addon:DynamicChat:(.+)$") or link:match("^url:(.+)$") or link:match("^dcurl:(.+)$")
            if encoded and EnsureDB().clickableURLs then
                local decodedUrl = DecodeDynamicChatLinkPayload(encoded)
                if _G.ItemRefTooltip and _G.ItemRefTooltip:IsShown() then
                    _G.ItemRefTooltip:Hide()
                end
                DynamicChat:ShowURLCopyPopup(decodedUrl)
            end
        end
        if _G.EventRegistry and type(_G.EventRegistry.RegisterCallback) == "function" then
            pcall(_G.EventRegistry.RegisterCallback, _G.EventRegistry, "SetItemRef", function(_, link)
                HandleDynamicChatLinkClick(link)
            end, DynamicChat)
        end
        if type(_G.SetItemRef) == "function" then
            hooksecurefunc("SetItemRef", function(link)
                HandleDynamicChatLinkClick(link)
            end)
        end
    end

    if not self.sendChatHooked then
        self.sendChatHooked = true
        local function RecordSentChatType(_, chatType)
            if not IsSecretValue(chatType) and type(chatType) == "string" and type(_G.GetTime) == "function" then
                self._lastSentByType = self._lastSentByType or {}
                self._lastSentByType[chatType:upper()] = _G.GetTime()
            end
        end
        if _G.C_ChatInfo and type(_G.C_ChatInfo.SendChatMessage) == "function" then
            hooksecurefunc(_G.C_ChatInfo, "SendChatMessage", RecordSentChatType)
        end
        if type(_G.SendChatMessage) == "function" then
            hooksecurefunc("SendChatMessage", RecordSentChatType)
        end
    end
end

-- ============================================================================
-- 6B. ENGINE 4: PER-CHANNEL CHAT NOTIFICATION SOUND ENGINE
-- ============================================================================

local BLIZZARD_WHISPER_SOUND_FIDS = { 567482, 567421 }

local SOUND_CHANNEL_DEFS = {
    {
        key        = "WHISPER",
        title      = "Whisper & Battle.net Whisper",
        desc       = "Plays when you receive an incoming character whisper or Battle.net whisper (including self-whispers).",
        defaultVal = "BLIZZ_WHISPER",
    },
    {
        key        = "GUILD",
        title      = "Guild & Officer Chat",
        desc       = "Plays when a guildmate posts in Guild or Officer chat (ignores messages you send).",
        defaultVal = "BLIZZ_BNET_TOAST",
    },
    {
        key        = "PARTY",
        title      = "Party & Instance Chat",
        desc       = "Plays when a group member posts in Party, Party Leader, or LFD/LFR/Battleground Instance chat.",
        defaultVal = "BLIZZ_MAP_PING",
    },
    {
        key        = "RAID",
        title      = "Raid & Raid Warning",
        desc       = "Plays when someone posts in Raid, Raid Leader, or Raid Warning chat.",
        defaultVal = "BLIZZ_RAID_WARNING",
    },
    {
        key        = "SAY",
        title      = "Say & Yell",
        desc       = "Plays when nearby players use Say or Yell (None by default so busy city hubs stay quiet).",
        defaultVal = "NONE",
    },
}

local SOUND_CHANNEL_DEF_BY_KEY = {}
for _, def in ipairs(SOUND_CHANNEL_DEFS) do
    SOUND_CHANNEL_DEF_BY_KEY[def.key] = def
end

local CHAT_EVENT_TO_SOUND_CHANNEL = {
    CHAT_MSG_WHISPER              = { key = "WHISPER", sentType = "WHISPER" },
    CHAT_MSG_BN_WHISPER           = { key = "WHISPER", sentType = "BN_WHISPER" },
    CHAT_MSG_GUILD                = { key = "GUILD",   sentType = "GUILD" },
    CHAT_MSG_OFFICER              = { key = "GUILD",   sentType = "OFFICER" },
    CHAT_MSG_PARTY                = { key = "PARTY",   sentType = "PARTY" },
    CHAT_MSG_PARTY_LEADER         = { key = "PARTY",   sentType = "PARTY" },
    CHAT_MSG_INSTANCE_CHAT        = { key = "PARTY",   sentType = "INSTANCE_CHAT" },
    CHAT_MSG_INSTANCE_CHAT_LEADER = { key = "PARTY",   sentType = "INSTANCE_CHAT" },
    CHAT_MSG_RAID                 = { key = "RAID",    sentType = "RAID" },
    CHAT_MSG_RAID_LEADER          = { key = "RAID",    sentType = "RAID" },
    CHAT_MSG_RAID_WARNING         = { key = "RAID",    sentType = "RAID_WARNING" },
    CHAT_MSG_SAY                  = { key = "SAY",     sentType = "SAY" },
    CHAT_MSG_YELL                 = { key = "SAY",     sentType = "YELL" },
}

local lastChannelSoundTime = {}

local function IsSafeAccessibleValue(val)
    if val == nil then return false end
    if IsSecretValue(val) then return false end
    if type(_G.canaccessvalue) == "function" then
        local okCan, canAccess = pcall(_G.canaccessvalue, val)
        if okCan and not canAccess then
            return false
        end
    end
    return true
end

local dcStandaloneSoundCache = {
    scanned = false,
    blizzard = {},
    external = {},
    byKey = {},
}

local function CleanExternalSoundName(rawText)
    if not IsSafeAccessibleValue(rawText) then return "" end
    local s = tostring(rawText or "")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    return s:match("^%s*(.-)%s*$") or ""
end

local function LooksLikeSoundAsset(val)
    if type(val) == "number" then
        return IsSafeAccessibleValue(val) and val > 0
    end
    if type(val) ~= "string" or not IsSafeAccessibleValue(val) or val == "" then
        return false
    end
    if val:find("[\\/]") then return true end
    local low = val:lower()
    return (low:match("%.wav$") ~= nil) or (low:match("%.ogg$") ~= nil) or (low:match("%.mp3$") ~= nil)
end

function DynamicChat:ScanExternalSounds(force)
    local suite = _G.DynamicSuite
    if suite and type(suite.GetSharedSounds) == "function" then
        local sReg = suite:GetSharedSounds(force)
        dcStandaloneSoundCache.scanned = true
        return sReg
    end
    if dcStandaloneSoundCache.scanned and not force then
        return dcStandaloneSoundCache
    end

    local blizz = BuildBlizzardChatSoundList()
    local ext = {}
    local byKey = {}
    local seenKeys = {}
    local skipPaths = {}
    local skipNames = {}

    for _, bDef in ipairs(blizz) do
        byKey[bDef.value] = bDef
    end

    local function AddExternalCandidate(prefix, rawName, rawPath, srcTag)
        if not IsSafeAccessibleValue(rawName) or not LooksLikeSoundAsset(rawPath) then return end
        local cleanName = CleanExternalSoundName(rawName)
        if cleanName == "" then return end
        if skipNames[cleanName:lower()] then return end
        if type(rawPath) == "string" and skipPaths[rawPath:lower():gsub("/", "\\")] then return end
        local key = prefix .. ":" .. cleanName
        if seenKeys[key] then return end
        seenKeys[key] = true
        local entry = {
            value  = key,
            name   = cleanName,
            label  = srcTag and (cleanName .. " (" .. srcTag .. ")") or cleanName,
            path   = rawPath,
            source = srcTag or "SharedMedia",
            group  = "EXTERNAL",
        }
        if type(rawPath) == "number" then
            entry.fileDataID = rawPath
        end
        byKey[key] = entry
        if not byKey[cleanName] then byKey[cleanName] = entry end
        table.insert(ext, entry)
    end

    local lsm = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
    if not lsm and type(_G.ElvUI) == "table" and type(_G.ElvUI[1]) == "table" and type(_G.ElvUI[1].Libs) == "table" then
        lsm = _G.ElvUI[1].Libs.LSM
    end
    if lsm then
        if type(lsm.HashTable) == "function" then
            local okH, hTbl = pcall(lsm.HashTable, lsm, "sound")
            if okH and type(hTbl) == "table" then
                for kName, kPath in pairs(hTbl) do
                    if type(kName) == "string" then
                        AddExternalCandidate("LSM", kName, kPath, "SharedMedia")
                    end
                end
            end
        end
        if type(lsm.List) == "function" and type(lsm.Fetch) == "function" then
            local okL, lList = pcall(lsm.List, lsm, "sound")
            if okL and type(lList) == "table" then
                for _, lName in ipairs(lList) do
                    if type(lName) == "string" then
                        local okF, fPath = pcall(lsm.Fetch, lsm, "sound", lName, true)
                        if okF and fPath then
                            AddExternalCandidate("LSM", lName, fPath, "SharedMedia")
                        end
                    end
                end
            end
        end
    end

    if type(_G.DBM) == "table" then
        local dbmTables = {}
        if type(_G.DBM.Sounds) == "table" then table.insert(dbmTables, _G.DBM.Sounds) end
        if type(_G.DBM.Sound) == "table" then table.insert(dbmTables, _G.DBM.Sound) end
        for _, tbl in ipairs(dbmTables) do
            for k, v in pairs(tbl) do
                if type(v) == "table" then
                    local nm = v.text or v.name or v.label or (type(k) == "string" and k) or nil
                    local p = v.value or v.path or v.sound
                    if nm and p then AddExternalCandidate("DBM", tostring(nm), p, "DBM") end
                elseif type(k) == "string" and LooksLikeSoundAsset(v) then
                    AddExternalCandidate("DBM", k, v, "DBM")
                elseif type(v) == "string" and LooksLikeSoundAsset(k) then
                    AddExternalCandidate("DBM", v, k, "DBM")
                end
            end
        end
    end

    local bwTbl = (type(_G.BigWigs) == "table" and _G.BigWigs.Sounds) or (type(_G.BigWigsLoader) == "table" and _G.BigWigsLoader.Sounds)
    if type(bwTbl) == "table" then
        for k, v in pairs(bwTbl) do
            if type(k) == "string" and LooksLikeSoundAsset(v) then
                AddExternalCandidate("BW", k, v, "BigWigs")
            end
        end
    end

    if type(_G.WeakAuras) == "table" then
        local waTbl = _G.WeakAuras.sound_types or _G.WeakAuras.sounds
        if type(waTbl) == "table" then
            for k, v in pairs(waTbl) do
                if type(v) == "string" and LooksLikeSoundAsset(k) then
                    AddExternalCandidate("WA", v, k, "WeakAuras")
                elseif type(k) == "string" and LooksLikeSoundAsset(v) then
                    AddExternalCandidate("WA", k, v, "WeakAuras")
                end
            end
        end
    end

    if type(_G.ElvUI) == "table" and type(_G.ElvUI[1]) == "table" and type(_G.ElvUI[1].Media) == "table" then
        local eSounds = _G.ElvUI[1].Media.Sounds
        if type(eSounds) == "table" then
            for k, v in pairs(eSounds) do
                if type(k) == "string" and LooksLikeSoundAsset(v) then
                    AddExternalCandidate("ELV", k, v, "ElvUI")
                end
            end
        end
    end

    for _, globalKey in ipairs({ "EXBOSS", "EX_Boss", "ExBoss" }) do
        local ex = _G[globalKey]
        if type(ex) == "table" then
            local sub = ex.Sounds or ex.sounds or ex.Sound
            if type(sub) == "table" then
                for k, v in pairs(sub) do
                    if IsSafeAccessibleValue(k) and IsSafeAccessibleValue(v) then
                        if type(k) == "string" and LooksLikeSoundAsset(v) then
                            AddExternalCandidate("EXBOSS", k, v, "EXBOSS")
                        elseif type(v) == "string" and LooksLikeSoundAsset(k) then
                            AddExternalCandidate("EXBOSS", v, k, "EXBOSS")
                        end
                    end
                end
            end
        end
    end

    table.sort(ext, function(a, b)
        return (a.name or a.label):lower() < (b.name or b.label):lower()
    end)

    dcStandaloneSoundCache.blizzard = blizz
    dcStandaloneSoundCache.external = ext
    dcStandaloneSoundCache.byKey = byKey
    dcStandaloneSoundCache.scanned = true
    return dcStandaloneSoundCache
end

local function ResolveChannelSound(soundKey)
    if not soundKey or soundKey == "" or soundKey == "NONE" then
        return nil, false
    end
    if type(soundKey) == "string" and (soundKey:match("^ds_") or soundKey:match("^ex_") or soundKey:lower():match("%.wav$")) then
        local fb = BLIZZARD_SOUND_BY_KEY["BLIZZARD_RAID_WARNING"] or BLIZZARD_SOUND_BY_KEY["BLIZZ_RAID_WARNING"] or BuildBlizzardChatSoundList()[1]
        return fb, true
    end
    if SoundMgr.chimesMap[soundKey] then
        return SoundMgr.chimesMap[soundKey], false
    end
    local customHit = SoundMgr.ResolveCustomSound(soundKey)
    if customHit then
        return customHit, false
    end
    if IsBuiltInBlizzardSoundKey(soundKey) then
        return BLIZZARD_SOUND_BY_KEY[soundKey], false
    end
    local suite = _G.DynamicSuite
    if suite and type(suite.ResolveSoundChoice) == "function" then
        local hit, isFb = suite:ResolveSoundChoice(soundKey, "BLIZZ_RAID_WARNING")
        if hit then return hit, isFb end
    end
    local reg = DynamicChat:ScanExternalSounds(false)
    local hit = reg.byKey and reg.byKey[soundKey]
    if not hit then
        reg = DynamicChat:ScanExternalSounds(true)
        hit = reg.byKey and reg.byKey[soundKey]
    end
    if not hit and type(soundKey) == "string" then
        local stripped = soundKey:gsub("^LSM:", ""):gsub("^DBM:", ""):gsub("^BW:", ""):gsub("^WA:", ""):gsub("^ELV:", ""):gsub("^EXBOSS:", "")
        hit = reg.byKey and reg.byKey[stripped]
    end
    if hit then
        return hit, false
    end
    local fb = (reg.byKey and reg.byKey["BLIZZ_RAID_WARNING"]) or BuildBlizzardChatSoundList()[1]
    return fb, true
end

local function GetSoundOptionsForChannel(_)
    local opts = {
        { value = "NONE", label = "None (Muted)" },
    }

    table.insert(opts, { isHeader = true, label = "DYNAMICSUITE CHIMES" })
    for _, chime in ipairs(SoundMgr.chimesList) do
        opts[#opts + 1] = {
            value = chime.key,
            label = chime.label,
            path  = chime.path,
        }
    end

    local customList = EnsureDB().customSounds
    if type(customList) == "table" and #customList > 0 then
        table.insert(opts, { isHeader = true, label = "CUSTOM SOUNDS" })
        for _, cs in ipairs(customList) do
            if type(cs) == "table" and cs.id and cs.path then
                opts[#opts + 1] = {
                    value = cs.id,
                    label = cs.label or cs.id,
                    path  = cs.path,
                }
            end
        end
    end

    local reg = DynamicChat:ScanExternalSounds(true)
    local blizzList = (reg and type(reg.blizzard) == "table" and #reg.blizzard > 0 and reg.blizzard) or BuildBlizzardChatSoundList()
    table.insert(opts, { isHeader = true, label = "BLIZZARD" })
    for _, bItem in ipairs(blizzList) do
        opts[#opts + 1] = {
            value      = bItem.value,
            label      = bItem.label,
            soundKit   = bItem.soundKit,
            fileDataID = bItem.fileDataID,
        }
    end

    local extList = (reg and type(reg.external) == "table") and reg.external or {}
    if #extList > 0 then
        table.insert(opts, { isHeader = true, label = "SHAREDMEDIA / ADDONS" })
        for _, ext in ipairs(extList) do
            opts[#opts + 1] = {
                value      = ext.value,
                label      = ext.label or ext.name or ext.value,
                path       = ext.path,
                fileDataID = ext.fileDataID,
                source     = ext.source,
            }
        end
    end
    return opts
end

local function GetSoundSlotValue(slotKey)
    local db = EnsureDB()
    if slotKey == "MENTION_NAME" then
        return db.mentionNameSound or DEFAULTS.mentionNameSound
    elseif slotKey == "MENTION_KEYWORD" then
        return db.mentionKeywordSound or DEFAULTS.mentionKeywordSound
    end
    local def = SOUND_CHANNEL_DEF_BY_KEY[slotKey]
    local chSounds = db.channelSounds or DEFAULTS.channelSounds
    return chSounds[slotKey] or (def and def.defaultVal) or "NONE"
end

local function SetSoundSlotValue(slotKey, val)
    local curDB = EnsureDB()
    if slotKey == "MENTION_NAME" then
        curDB.mentionNameSound = val
    elseif slotKey == "MENTION_KEYWORD" then
        curDB.mentionKeywordSound = val
    else
        curDB.channelSounds = curDB.channelSounds or {}
        curDB.channelSounds[slotKey] = val
        if slotKey == "WHISPER" then
            DynamicChat:ApplyWhisperDefaultSoundMuteState()
        end
    end
end

local function GetSoundSlotTitle(slotKey)
    if slotKey == "MENTION_NAME" then return "Name Mention Sound" end
    if slotKey == "MENTION_KEYWORD" then return "Keyword Trigger Sound" end
    local def = SOUND_CHANNEL_DEF_BY_KEY[slotKey]
    return (def and def.title) or "Channel Sound"
end

local function GetSoundOptionLabel(channelKey, val)
    if not val or val == "" then
        val = GetSoundSlotValue(channelKey)
    end
    if val == "NONE" then
        return "None (Muted)"
    end
    local soundDef, isFallback = ResolveChannelSound(val)
    if soundDef then
        if isFallback then
            return (soundDef.label or "Blizzard Raid Warning") .. " (Fallback)"
        end
        return soundDef.label or soundDef.name or tostring(val)
    end
    return "Blizzard Raid Warning"
end

function DynamicChat:ApplyWhisperDefaultSoundMuteState()
    local db = EnsureDB()
    local alertsActive = (not IsModuleDisabledInSuite("DynamicChat")) and (db.enableChatSounds ~= false) and (not self:IsDirectChatReplacementLoaded())

    if alertsActive then
        -- Mute Blizzard's native 567482/567421 whisper chimes while DynamicChat custom sounds are active
        -- so incoming whispers play only your selected DynamicChat chime (or stay silent when Muted).
        if type(_G.MuteSoundFile) == "function" then
            for _, fid in ipairs(BLIZZARD_WHISPER_SOUND_FIDS) do
                pcall(_G.MuteSoundFile, fid)
            end
        end
    else
        if type(_G.UnmuteSoundFile) == "function" then
            for _, fid in ipairs(BLIZZARD_WHISPER_SOUND_FIDS) do
                pcall(_G.UnmuteSoundFile, fid)
            end
        end
    end
end

function DynamicChat:PlaySoundOptionKey(soundKey, channelKey, isPreview)
    local db = EnsureDB()
    local outChan = db.soundOutputChannel or "Master"
    if outChan ~= "Master" and outChan ~= "SFX" and outChan ~= "Dialog" then
        outChan = "Master"
    end

    if not soundKey or soundKey == "" or soundKey == "NONE" then
        return false
    end

    local soundDef = ResolveChannelSound(soundKey)
    if not soundDef then
        return false
    end

    if not isPreview then
        self:ApplyWhisperDefaultSoundMuteState()
    end

    -- Temporarily unmute native Blizzard whisper FID only when explicitly playing Blizzard Whisper / BNet Toast
    local unmutedFid = nil
    if soundDef.fileDataID and (soundDef.fileDataID == 567482 or soundDef.fileDataID == 567421) and type(_G.UnmuteSoundFile) == "function" then
        unmutedFid = soundDef.fileDataID
        pcall(_G.UnmuteSoundFile, unmutedFid)
    end

    local played = false
    if type(soundDef.soundKit) == "number" then
        if type(_G.PlaySound) == "function" then
            local okK, willPlay = pcall(_G.PlaySound, soundDef.soundKit, outChan)
            played = (okK and willPlay ~= false)
        end
        if not played and type(soundDef.fileDataID) == "number" and type(_G.PlaySoundFile) == "function" then
            local okF, willPlay = pcall(_G.PlaySoundFile, soundDef.fileDataID, outChan)
            played = (okF and willPlay ~= false)
        end
    elseif type(soundDef.fileDataID) == "number" or type(soundDef.path) == "number" then
        local fid = soundDef.fileDataID or soundDef.path
        if type(_G.PlaySoundFile) == "function" then
            local okF, willPlay = pcall(_G.PlaySoundFile, fid, outChan)
            played = (okF and willPlay ~= false)
        end
    elseif type(soundDef.path) == "string" and soundDef.path ~= "" then
        if type(_G.PlaySoundFile) == "function" then
            local okF, willPlay = pcall(_G.PlaySoundFile, soundDef.path, outChan)
            played = (okF and willPlay ~= false)
        end
    end

    if unmutedFid and _G.C_Timer and type(_G.C_Timer.After) == "function" then
        _G.C_Timer.After(0.25, function()
            DynamicChat:ApplyWhisperDefaultSoundMuteState()
        end)
    end

    return played
end

function DynamicChat:PlaySuiteChime(chimeKey)
    local entry = SoundMgr.chimesMap[chimeKey] or SoundMgr.chimesList[1]
    local played = false
    if entry and type(_G.PlaySoundFile) == "function" then
        local okF, willPlay = pcall(_G.PlaySoundFile, entry.path, "SFX")
        played = (okF and willPlay ~= false)
    end
    if not played and _G.DEFAULT_CHAT_FRAME and type(_G.DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        _G.DEFAULT_CHAT_FRAME:AddMessage(ColorWithAccent("DynamicChat:") .. " Could not play chime. Newly added .ogg files require a full WoW client restart to load.")
    end
    return played
end

function DynamicChat:PreviewSuiteChimePack()
    if _G.DEFAULT_CHAT_FRAME and type(_G.DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        _G.DEFAULT_CHAT_FRAME:AddMessage(ColorWithAccent("DynamicChat:") .. " Auditioning 10-chime DynamicSuite pack on SFX (Spark, Pulse, Duo, Cascade, Echo, Chime, Bloom, Dewdrop, Ripple, Prism)...")
    end
    for idx, entry in ipairs(SoundMgr.chimesList) do
        local delay = (idx - 1) * 0.65
        if delay == 0 then
            self:PlaySuiteChime(entry.key)
        elseif _G.C_Timer and type(_G.C_Timer.After) == "function" then
            local k = entry.key
            _G.C_Timer.After(delay, function()
                DynamicChat:PlaySuiteChime(k)
            end)
        end
    end
end

do
    local mentionToastFrame = nil

    local function GetChatSharedToastStyle()
        if _G.DynamicSuite and type(_G.DynamicSuite.GetSharedToastStyle) == "function" then
            local ok, st = pcall(_G.DynamicSuite.GetSharedToastStyle)
            if ok and type(st) == "table" then return st end
        end
        local ar, ag, ab = GetSuiteAccent()
        local g = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global) or {}
        return {
            scale = math.max(0.60, math.min(1.50, tonumber(g.toastScale) or 1.0)),
            opacity = math.max(0.20, math.min(1.00, tonumber(g.toastOpacity or g.toastAlpha) or 0.96)),
            borderStyle = tostring(g.toastBorderStyle or "ACCENT"):upper(),
            duration = tonumber(g.toastDuration) or 8,
            pos = g.toastPos or { point = "TOP", relPoint = "TOP", x = 0, y = -140 },
            bgR = 0.035, bgG = 0.039, bgB = 0.051,
            ar = ar, ag = ag, ab = ab,
        }
    end

    function DynamicChat:ApplyMentionToastVisuals()
        local f = mentionToastFrame
        if not f then return end
        if InCombatLockdown and InCombatLockdown() then return end
        local st = GetChatSharedToastStyle()
        f:SetScale(st.scale or 1.0)
        f:SetBackdropColor(st.bgR or 0.035, st.bgG or 0.039, st.bgB or 0.051, st.opacity or 0.96)
        local bStyle = tostring(st.borderStyle or "ACCENT"):upper()
        if bStyle == "NONE" or bStyle == "BORDERLESS" then
            f:SetBackdropBorderColor(0, 0, 0, 0)
        elseif bStyle == "DARK" or bStyle == "SUBTLE" then
            f:SetBackdropBorderColor(0.20, 0.24, 0.32, 0.95)
        else
            f:SetBackdropBorderColor(st.ar, st.ag, st.ab, 0.92)
        end
        if f.iconBorder then
            f.iconBorder:SetBackdropBorderColor(st.ar, st.ag, st.ab, 0.85)
        end
        if f.iconTex then
            f.iconTex:SetVertexColor(st.ar, st.ag, st.ab, 1.0)
        end
        if f:IsShown() and _G.DynamicSuite and type(_G.DynamicSuite.RestackAllToasts) == "function" then
            pcall(_G.DynamicSuite.RestackAllToasts)
        end
    end

    function SoundMgr.ShowMentionAlertToast(kindLabel, senderName, snippet)
        if not _G.UIParent then return end
        if InCombatLockdown and InCombatLockdown() then return end
        if not mentionToastFrame then
            local f = CreateFrame("Button", "DynamicChatMentionToast", _G.UIParent, "BackdropTemplate")
            f:SetSize(410, 74)
            f:SetFrameStrata("HIGH")
            f:SetToplevel(true)
            f:SetClampedToScreen(true)
            f:EnableMouse(true)
            f:RegisterForClicks("RightButtonUp")
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
            ic:SetSize(30, 30)
            ic:SetPoint("CENTER", iconBorder, "CENTER", 0, 0)
            ic:SetTexture(ICON_MAIN)
            f.iconBorder = iconBorder
            f.iconTex = ic

            f.title = f:CreateFontString(nil, "OVERLAY")
            SetSafeFont(f.title, 12, "")
            f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -11)
            f.title:SetPoint("RIGHT", f, "RIGHT", -14, 0)
            f.title:SetJustifyH("LEFT")
            f.title:SetWordWrap(false)

            f.body = f:CreateFontString(nil, "OVERLAY")
            SetSafeFont(f.body, 11, "")
            f.body:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -5)
            f.body:SetPoint("RIGHT", f, "RIGHT", -14, 0)
            f.body:SetJustifyH("LEFT")
            f.body:SetWordWrap(false)
            f.body:SetTextColor(0.88, 0.92, 0.97, 1.0)

            f.subtext = f:CreateFontString(nil, "OVERLAY")
            SetSafeFont(f.subtext, 10, "")
            f.subtext:SetPoint("TOPLEFT", f.body, "BOTTOMLEFT", 0, -5)
            f.subtext:SetPoint("RIGHT", f, "RIGHT", -14, 0)
            f.subtext:SetJustifyH("LEFT")
            f.subtext:SetWordWrap(false)
            f.subtext:SetText("|cFF38BDF8Right-Click:|r |cFF94A3B8Dismiss|r")

            local animGroup = f:CreateAnimationGroup()
            local holdAnim = animGroup:CreateAnimation("Animation")
            holdAnim:SetDuration(8)
            holdAnim:SetOrder(1)
            local fadeAnim = animGroup:CreateAnimation("Alpha")
            fadeAnim:SetFromAlpha(1)
            fadeAnim:SetToAlpha(0)
            fadeAnim:SetDuration(1.2)
            fadeAnim:SetOrder(2)
            animGroup:SetScript("OnFinished", function()
                f:Hide()
                f:SetAlpha(1)
            end)
            f.animGroup = animGroup
            f.holdAnim = holdAnim

            f:SetScript("OnClick", function(selfT, button)
                if button == "RightButton" then
                    selfT.animGroup:Stop()
                    selfT:Hide()
                    selfT:SetAlpha(1)
                end
            end)
            f:SetScript("OnEnter", function(selfT)
                selfT.animGroup:Pause()
                selfT:SetAlpha(1)
            end)
            f:SetScript("OnLeave", function(selfT)
                local curSt = GetChatSharedToastStyle()
                if (curSt.duration or 8) > 0 then
                    selfT.animGroup:Play()
                end
            end)
            f:HookScript("OnHide", function()
                if _G.DynamicSuite and type(_G.DynamicSuite.RestackAllToasts) == "function" then
                    pcall(_G.DynamicSuite.RestackAllToasts)
                end
            end)

            f:Hide()
            mentionToastFrame = f
        end

        DynamicChat:ApplyMentionToastVisuals()
        local who = (type(senderName) == "string" and senderName ~= "") and senderName or "Player"
        mentionToastFrame.title:SetText("|cFFCBD5E1Dynamic|r|cFFFFFFFFChat|r  |cFF475569|||r  " .. ColorWithAccent(kindLabel) .. "  |cFFF8FAFCfrom " .. who .. "|r")
        local cleanSnap = tostring(snippet or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        if #cleanSnap > 68 then
            cleanSnap = cleanSnap:sub(1, 65) .. "..."
        end
        mentionToastFrame.body:SetText(cleanSnap ~= "" and cleanSnap or "Matched your name or alert keyword in chat.")
        mentionToastFrame.animGroup:Stop()
        mentionToastFrame:SetAlpha(1.0)
        mentionToastFrame:Show()
        if _G.DynamicSuite and type(_G.DynamicSuite.RestackAllToasts) == "function" then
            pcall(_G.DynamicSuite.RestackAllToasts)
        else
            local stPos = GetChatSharedToastStyle().pos or { point = "TOP", relPoint = "TOP", x = 0, y = -140 }
            mentionToastFrame:ClearAllPoints()
            mentionToastFrame:SetPoint(stPos.point or "TOP", _G.UIParent, stPos.relPoint or stPos.point or "TOP", tonumber(stPos.x) or 0, tonumber(stPos.y) or -140)
        end
        if _G.DynamicSuite and type(_G.DynamicSuite.PlaySharedToastSound) == "function" then
            pcall(_G.DynamicSuite.PlaySharedToastSound)
        end
        local dur = tonumber(GetChatSharedToastStyle().duration) or 8
        if dur > 0 then
            mentionToastFrame.holdAnim:SetDuration(dur)
            mentionToastFrame.animGroup:Play()
        end
    end

    local function EscapeLuaPattern(str)
        return (str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
    end

    local function ContainsWholeWordCI(haystackLower, termLower)
        if termLower == "" then return false end
        local esc = EscapeLuaPattern(termLower)
        local sIdx, eIdx = haystackLower:find(esc)
        while sIdx do
            local beforeOk = (sIdx == 1) or not haystackLower:sub(sIdx - 1, sIdx - 1):match("[%w_]")
            local afterOk  = (eIdx == #haystackLower) or not haystackLower:sub(eIdx + 1, eIdx + 1):match("[%w_]")
            if beforeOk and afterOk then
                return true, sIdx, eIdx
            end
            sIdx, eIdx = haystackLower:find(esc, eIdx + 1)
        end
        return false
    end

    function SoundMgr.HighlightMatchedTerm(msgText, term)
        local ok, result = pcall(function()
            local lowerMsg = msgText:lower()
            local lowerTerm = term:lower()
            local matched, sIdx, eIdx = ContainsWholeWordCI(lowerMsg, lowerTerm)
            if not matched or not sIdx then return msgText end
            local orig = msgText:sub(sIdx, eIdx)
            return msgText:sub(1, sIdx - 1) .. ColorWithAccent(orig) .. msgText:sub(eIdx + 1)
        end)
        return (ok and type(result) == "string") and result or msgText
    end

    function SoundMgr.CheckMentionOrKeywordMatch(arg1, db)
        if db.enableMentionAlerts == false then return nil, nil end
        if not IsSafeAccessibleValue(arg1) or type(arg1) ~= "string" or arg1 == "" then
            return nil, nil
        end
        local ok, kind, term = pcall(function()
            local low = arg1:lower()
            if type(_G.UnitName) == "function" then
                local okN, pName = pcall(_G.UnitName, "player")
                if okN and IsSafeAccessibleValue(pName) and type(pName) == "string" and #pName >= 2 then
                    if ContainsWholeWordCI(low, pName:lower()) then
                        return "NAME", pName
                    end
                end
            end
            local rawKw = db.mentionKeywords
            if type(rawKw) == "string" and rawKw ~= "" then
                for piece in rawKw:gmatch("[^,]+") do
                    local kw = piece:gsub("^%s+", ""):gsub("%s+$", "")
                    if #kw >= 2 and ContainsWholeWordCI(low, kw:lower()) then
                        return "KEYWORD", kw
                    end
                end
            end
            return nil, nil
        end)
        if ok then
            return kind, term
        end
        return nil, nil
    end
end

function DynamicChat:HandleIncomingChatSoundEvent(event, arg2, arg12, arg1)
    if IsModuleDisabledInSuite("DynamicChat") then return end
    local mapEntry = CHAT_EVENT_TO_SOUND_CHANNEL[event]
    if not mapEntry then return end
    if self:IsDirectChatReplacementLoaded() then return end

    local db = EnsureDB()

    -- 1. Optional Mute in Combat / Boss Encounters
    if db.soundMuteInCombat then
        local inCombatOrBoss = (InCombatLockdown and InCombatLockdown()) or (IsEncounterInProgress and IsEncounterInProgress())
        if inCombatOrBoss then
            return
        end
    end

    -- 2. Self-Message Suppression (Secret-Value Guarded via sender GUID & UnitName)
    -- Bypass suppression on incoming whisper events (CHAT_MSG_WHISPER / CHAT_MSG_BN_WHISPER) so self-whispers play normally.
    local isIncomingWhisper = (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER")
    if not isIncomingWhisper then
        local guidChecked = false
        if IsSafeAccessibleValue(arg12) and type(arg12) == "string" and arg12 ~= "" and type(_G.UnitGUID) == "function" then
            local okG, pGuid = pcall(_G.UnitGUID, "player")
            if okG and IsSafeAccessibleValue(pGuid) and type(pGuid) == "string" and pGuid ~= "" then
                guidChecked = true
                if arg12 == pGuid then
                    return
                end
            end
        end
        local nameChecked = false
        if IsSafeAccessibleValue(arg2) and type(arg2) == "string" and arg2 ~= "" and type(_G.UnitName) == "function" then
            local okN, pName = pcall(_G.UnitName, "player")
            local okFN, fullPlayer = false, nil
            if type(_G.GetUnitName) == "function" then
                okFN, fullPlayer = pcall(_G.GetUnitName, "player", true)
            end
            if okN and IsSafeAccessibleValue(pName) and type(pName) == "string" and pName ~= "" then
                nameChecked = true
                if arg2 == pName then
                    return
                end
                if okFN and IsSafeAccessibleValue(fullPlayer) and type(fullPlayer) == "string" and fullPlayer ~= "" and arg2 == fullPlayer then
                    return
                end
                if not guidChecked then
                    local shortSender = arg2:match("^([^%-]+)") or arg2
                    if shortSender == pName then
                        return
                    end
                end
            end
        end
        if (not guidChecked and IsSecretValue(arg12)) or (not nameChecked and IsSecretValue(arg2)) then
            local nowSent = (type(_G.GetTime) == "function" and _G.GetTime()) or 0
            local sentType = mapEntry.sentType
            local lastSent = (self._lastSentByType and sentType and self._lastSentByType[sentType]) or 0
            if nowSent > 0 and (nowSent - lastSent) <= 0.45 then
                return
            end
        end
    end

    local now = (type(_G.GetTime) == "function" and _G.GetTime()) or 0

    -- 3. Name & Keyword Mention Alerts (Secret-Value Guarded)
    local mentionKind, matchedTerm = SoundMgr.CheckMentionOrKeywordMatch(arg1, db)
    if mentionKind then
        local slotKey = (mentionKind == "NAME") and "MENTION_NAME" or "MENTION_KEYWORD"
        local prevM = lastChannelSoundTime[slotKey] or 0
        if now == 0 or (now - prevM) >= 1.0 then
            lastChannelSoundTime[slotKey] = now
            if db.enableChatSounds ~= false then
                local mSoundKey = (mentionKind == "NAME")
                    and (db.mentionNameSound or DEFAULTS.mentionNameSound)
                    or  (db.mentionKeywordSound or DEFAULTS.mentionKeywordSound)
                if mSoundKey and mSoundKey ~= "NONE" then
                    self:PlaySoundOptionKey(mSoundKey, slotKey, false)
                end
            end
            local senderSafe = (IsSafeAccessibleValue(arg2) and type(arg2) == "string") and (arg2:match("^([^%-]+)") or arg2) or "Player"
            local kindLabel = (mentionKind == "NAME") and "Name Mention" or ("Keyword: " .. tostring(matchedTerm))
            if db.mentionAlertToast ~= false then
                SoundMgr.ShowMentionAlertToast(kindLabel, senderSafe, arg1)
            end
            if db.mentionHighlightInChat ~= false and _G.DEFAULT_CHAT_FRAME and type(_G.DEFAULT_CHAT_FRAME.AddMessage) == "function" then
                local hiMsg = SoundMgr.HighlightMatchedTerm(arg1, matchedTerm)
                _G.DEFAULT_CHAT_FRAME:AddMessage(ColorWithAccent("[" .. kindLabel .. "]") .. " |cFFF8FAFC" .. senderSafe .. ":|r " .. hiMsg)
            end
        end
        return
    end

    -- 4. Standard Per-Channel Sound Alerts
    if db.enableChatSounds == false then return end

    local channelKey = mapEntry.key
    local def = SOUND_CHANNEL_DEF_BY_KEY[channelKey]
    local chSounds = db.channelSounds or DEFAULTS.channelSounds
    local soundKey = chSounds[channelKey] or (def and def.defaultVal) or "NONE"
    if not soundKey or soundKey == "" or soundKey == "NONE" then
        return
    end

    -- 5. Per-Channel Anti-Spam Cooldown
    local throttle = tonumber(db.soundThrottleSec)
    if throttle == nil then throttle = 1.5 end
    if throttle > 0 and now > 0 then
        local prev = lastChannelSoundTime[channelKey] or 0
        if (now - prev) < throttle then
            return
        end
        lastChannelSoundTime[channelKey] = now
    end

    self:PlaySoundOptionKey(soundKey, channelKey, false)
end

function DynamicChat:TeardownDisabledState(fromLiveToggle)
    HideAllCurrentSkinFrames()
    self:HideHudEditMover()
    if _G.DynamicSuiteEditModeModal and _G.DynamicSuiteEditModeModal:IsShown() and _G.DynamicSuiteEditModeModal.RefreshState then
        pcall(_G.DynamicSuiteEditModeModal.RefreshState)
    end
    if railPopoverFrame and railPopoverFrame:IsShown() then railPopoverFrame:Hide() end
    if railPopoverClickCatcher and railPopoverClickCatcher:IsShown() then railPopoverClickCatcher:Hide() end
    if chatHistoryModal and chatHistoryModal:IsShown() then chatHistoryModal:Hide() end
    if urlCopyPopup and urlCopyPopup:IsShown() then urlCopyPopup:Hide() end

    self:ReassertTargetWhisperSlashCommands()
    self:ApplyWhisperDefaultSoundMuteState()

    self:UnregisterAllEvents()
    if not isInitialized then
        self:RegisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_LOGIN")
    end
    if self._urlCaptureFrame then
        self._urlCaptureFrame:UnregisterAllEvents()
    end

    if fromLiveToggle or next(chatSkinStore) ~= nil then
        SetSideClutterButtonSuppressed(_G.ChatFrameChannelButton, false)
        SetSideClutterButtonSuppressed(_G.ChatFrameMenuButton, false)
        SetSideClutterButtonSuppressed(_G.ChatFrameToggleVoiceDeafenButton, false)
        SetSideClutterButtonSuppressed(_G.ChatFrameToggleVoiceMuteButton, false)
        SetSideClutterButtonSuppressed(_G.QuickJoinToastButton, false)
        SetSideClutterButtonSuppressed(_G.GeneralDockManagerOverflowButton, false)
        SetSideClutterButtonSuppressed(_G.CombatLogQuickButtonFrame_Custom, false)
        SetSideClutterButtonSuppressed(_G.CombatLogQuickButtonFrame, false)

        if _G.GeneralDockManagerScrollFrame then
            SetRegionAlphaSafe(_G.GeneralDockManagerScrollFrame, 1)
            if type(_G.GeneralDockManagerScrollFrame.Show) == "function" then
                pcall(_G.GeneralDockManagerScrollFrame.Show, _G.GeneralDockManagerScrollFrame)
            end
        end
        if _G.GeneralDockManager and type(_G.GeneralDockManager.SetClipsChildren) == "function" then
            pcall(_G.GeneralDockManager.SetClipsChildren, _G.GeneralDockManager, false)
        end

        local allFrames = CollectAllChatFrames()
        for _, item in ipairs(allFrames) do
            local cf = item.cf
            local i = item.index
            local cfName = item.name
            local tab = cfName and _G[cfName .. "Tab"] or nil
            if cf then
                SuppressBlizzardChatBackground(cf, cfName, false)
                SetSideClutterButtonSuppressed(_G[cfName .. "ButtonFrame"], false)
                SetSideClutterButtonSuppressed(_G[cfName .. "MinimizeButton"], false)
                if cf.buttonFrame and cf.buttonFrame ~= _G[cfName .. "ButtonFrame"] then
                    SetSideClutterButtonSuppressed(cf.buttonFrame, false)
                end
                if i == 1 and not (InCombatLockdown and InCombatLockdown()) then
                    RestoreOriginalButtonAnchors(_G.ChatFrame1ButtonFrame or cf.buttonFrame)
                    RestoreOriginalButtonAnchors(_G.ChatFrameMenuButton)
                    RestoreOriginalButtonAnchors(_G.QuickJoinToastButton)
                end
                local entry = chatSkinStore[cf]
                if entry then
                    entry.hiddenByScroll = false
                    ReskinChatScrollBarAndBottomButton(cf, entry, false)
                end
                if tab then
                    StripBlizzardTabTextures(tab, cfName .. "Tab", false)
                    if not (InCombatLockdown and InCombatLockdown()) and (cf == _G.ChatFrame1 or cf.isDocked) and type(tab.Show) == "function" then
                        pcall(tab.Show, tab)
                    end
                end
            end
        end

        if not (InCombatLockdown and InCombatLockdown()) and _G.GeneralDockManager and type(_G.FCFDock_UpdateTabs) == "function" then
            pcall(_G.FCFDock_UpdateTabs, _G.GeneralDockManager)
        end
    end

    if fromLiveToggle then
        PrintMsg("DynamicChat disabled and hidden. Click 'Reload UI' (/reload) to let Blizzard or EllesmereUI cleanly reclaim ChatFrame1.")
    end
end

function DynamicChat:ApplyAllEngineSettings()
    if IsModuleDisabledInSuite("DynamicChat") then
        self:TeardownDisabledState(false)
        return
    end
    self:ReassertTargetWhisperSlashCommands()
    self:ApplyWhisperDefaultSoundMuteState()
    self:ApplySavedChatFramePosition()
    self:ApplySleekChatSkin()
    self:ApplyChatFrameTypography()
    self:ApplyShortChannelNames()
    self:ApplyEditBoxSettings()
    self:ApplyStickyChannelSettings()
    self:ApplyGPUBufferSettings()
    self:RegisterQuickSlashCommands()
    self:InstallChatHooks()
    self:InstallReloadSnapshotHooks()
end

-- ============================================================================
-- 7. STATUS TEXT & 3-TAB OBSIDIAN WORKSPACE UI (DESIGN_SYSTEM.MD COMPLIANT)
-- ============================================================================

local function GetChatStatusText()
    local db = EnsureDB()
    local cmdLabel = "/ww"
    local wwStr  = db.enableTargetWhisper and "ON" or "OFF"
    local extLoaded, extKey = DynamicChat:IsExternalChatEngineLoaded()
    if extLoaded then
        local extName = extKey or "External UI"
        return string.format("* %s Whisper: %s  |  Chat Skin: Managed by %s", cmdLabel, wwStr, extName)
    end
    local skinStr = (db.enableSleekChatSkin ~= false) and "Smoked Glass" or "Blizzard"
    local histStr = (db.preserveChatHistory ~= false and db.enableGPUBufferCap ~= false) and ("Saved (" .. tostring(tonumber(db.maxChatLines) or 250) .. " Lines)") or "Off"
    return string.format("* %s Whisper: %s  |  Chat Skin: %s  |  Chat History: %s", cmdLabel, wwStr, skinStr, histStr)
end

function DynamicChat:GetStatusText()
    return GetChatStatusText()
end

local activeDropdownMenu = nil
local dropdownClickCatcher = nil
local soundDropdownPopover = nil
local fontDropdownMenu = nil

local function CloseActiveDropdown()
    if activeDropdownMenu then
        activeDropdownMenu:Hide()
        activeDropdownMenu = nil
    end
    if soundDropdownPopover and soundDropdownPopover:IsShown() then
        soundDropdownPopover:Hide()
    end
    if fontDropdownMenu and fontDropdownMenu:IsShown() then
        fontDropdownMenu:Hide()
    end
    if dropdownClickCatcher then
        dropdownClickCatcher:Hide()
    end
    if railPopoverFrame and railPopoverFrame:IsShown() then
        railPopoverFrame:Hide()
    end
    if railPopoverClickCatcher and railPopoverClickCatcher:IsShown() then
        railPopoverClickCatcher:Hide()
    end
end
DynamicChat.CloseActiveDropdown = CloseActiveDropdown

local function RegisterDynamicChatPopupClosers()
    local ui = _G.DynamicSuite and _G.DynamicSuite.UI
    if ui and type(ui.RegisterPopupCloser) == "function" then
        pcall(ui.RegisterPopupCloser, "DynamicChat", CloseActiveDropdown)
    end
end
RegisterDynamicChatPopupClosers()

local function CreateObsidianScrollArea(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -52)
    holder:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -16, 10)

    local scrollFrame = CreateFrame("ScrollFrame", nil, holder)
    scrollFrame:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(780, 480)
    scrollFrame:SetScrollChild(content)

    local track = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    track:SetWidth(4)
    track:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 10, -2)
    track:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 10, 2)
    track:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    track:SetBackdropColor(1, 1, 1, 0.05)
    track:EnableMouse(true)

    local thumb = CreateFrame("Button", nil, track, "BackdropTemplate")
    thumb:SetWidth(4)
    thumb:SetHeight(48)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    thumb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    thumb:SetBackdropColor(0.38, 0.45, 0.56, 0.85)
    thumb:EnableMouse(true)
    thumb:RegisterForClicks("LeftButtonUp", "LeftButtonDown")

    local function RefreshThumbColor()
        if thumb._isDragging or thumb._isHovered then
            local ar, ag, ab = GetSuiteAccent()
            thumb:SetBackdropColor(ar, ag, ab, 1.0)
        else
            thumb:SetBackdropColor(0.38, 0.45, 0.56, 0.85)
        end
    end

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
        RefreshThumbColor()
    end

    local function StepScrollByDelta(delta)
        CloseActiveDropdown()
        local maxScroll = math.max(0, (content:GetHeight() or 0) - (scrollFrame:GetHeight() or 0))
        local nextScroll = math.min(maxScroll, math.max(0, (scrollFrame:GetVerticalScroll() or 0) - (delta * 36)))
        scrollFrame:SetVerticalScroll(nextScroll)
        UpdateThumb()
    end

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        StepScrollByDelta(delta)
    end)
    track:EnableMouseWheel(true)
    track:SetScript("OnMouseWheel", function(_, delta)
        StepScrollByDelta(delta)
    end)
    thumb:EnableMouseWheel(true)
    thumb:SetScript("OnMouseWheel", function(_, delta)
        StepScrollByDelta(delta)
    end)

    track:SetScript("OnMouseDown", function(selfT, button)
        if button ~= "LeftButton" then return end
        CloseActiveDropdown()
        local maxScroll = math.max(0, (content:GetHeight() or 0) - (scrollFrame:GetHeight() or 0))
        if maxScroll <= 1 then return end
        local top = selfT:GetTop()
        local bot = selfT:GetBottom()
        if not top or not bot or top <= bot then return end
        local scale = selfT:GetEffectiveScale() or 1
        local curY = select(2, GetCursorPosition()) / scale
        local trackH = top - bot
        local thumbH = thumb:GetHeight() or 28
        local travel = math.max(1, trackH - thumbH)
        local clickOff = (top - curY) - (thumbH * 0.5)
        local pct = math.max(0, math.min(1, clickOff / travel))
        scrollFrame:SetVerticalScroll(pct * maxScroll)
        UpdateThumb()
    end)

    thumb:SetScript("OnEnter", function(self)
        self._isHovered = true
        RefreshThumbColor()
    end)
    thumb:SetScript("OnLeave", function(self)
        self._isHovered = false
        RefreshThumbColor()
    end)

    thumb:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        CloseActiveDropdown()
        self._isDragging = true
        RefreshThumbColor()
        local startY = select(2, GetCursorPosition()) / (self:GetEffectiveScale() or 1)
        local lastY = startY
        local startScroll = scrollFrame:GetVerticalScroll() or 0
        local elapsedAcc = 0
        self:SetScript("OnUpdate", function(_, elapsed)
            if not IsMouseButtonDown("LeftButton") then
                self._isDragging = false
                self:SetScript("OnUpdate", nil)
                RefreshThumbColor()
                return
            end
            elapsedAcc = elapsedAcc + (elapsed or 0)
            if elapsedAcc < 0.016 then return end
            elapsedAcc = 0
            local curY = select(2, GetCursorPosition()) / (self:GetEffectiveScale() or 1)
            if math.abs(curY - lastY) < 0.5 then return end
            lastY = curY
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
        self._isDragging = false
        self:SetScript("OnUpdate", nil)
        RefreshThumbColor()
    end)
    thumb:SetScript("OnHide", function(self)
        self._isDragging = false
        self._isHovered = false
        self:SetScript("OnUpdate", nil)
        RefreshThumbColor()
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
    holder.track = track
    return holder
end

-- Design A: 2-Line Tall L-Bracket Section Header (36px height, DESIGN_SYSTEM.md Section 2.4)
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
    subtitle:SetTextColor(0.64, 0.70, 0.78, 1.0) -- #A3B3C7 Slate-Silver
    subtitle:SetText(subtitleText or "")
    subtitle:SetShown(hasSub)
    hdr.subtitle = subtitle

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
DynamicChat.CreateSectionHeader = CreateSectionHeader

local function CreateSectionBox(page, titleText, subtitleText, root)
    local box = CreateFrame("Frame", nil, page, "BackdropTemplate")
    box.innerPadX = 14
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    box:SetBackdropColor(0.055, 0.063, 0.082, 0.96) -- #0E1015 CARD_BG
    box:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95) -- #252A36 CELL_BORDER
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

local function CreateCardRow(parent, height, titleText, descText, tooltipTitle, tooltipCmdText)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetHeight(height or 60)
    card.baseHeight = height or 60
    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    card:SetBackdropColor(0.078, 0.090, 0.122, 0.95) -- #14171F CELL_BG
    card:SetBackdropBorderColor(0.145, 0.165, 0.212, 1.00) -- #252A36 CELL_BORDER

    card.title = card:CreateFontString(nil, "OVERLAY")
    SetSafeFont(card.title, 11, "")
    card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -10)
    card.title:SetPoint("RIGHT", card, "RIGHT", -16, 0)
    card.title:SetJustifyH("LEFT")
    card.title:SetWordWrap(false)
    card.title:SetTextColor(0.97, 0.98, 1.00, 1.00) -- Crisp White #F8FAFC
    card.title:SetText(titleText or "")

    card.desc = card:CreateFontString(nil, "OVERLAY")
    SetSafeFont(card.desc, 10, "")
    card.desc:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
    card.desc:SetPoint("RIGHT", card, "RIGHT", -16, 0)
    card.desc:SetJustifyH("LEFT")
    card.desc:SetWordWrap(true)
    if card.desc.SetMaxLines then card.desc:SetMaxLines(2) end
    card.desc:SetTextColor(0.58, 0.64, 0.72)
    card.desc:SetText(descText or "")

    if tooltipTitle or tooltipCmdText then
        card:EnableMouse(true)
        card:SetScript("OnEnter", function(self)
            if _G.GameTooltip then
                _G.GameTooltip:SetOwner(self, "ANCHOR_TOP")
                _G.GameTooltip:ClearLines()
                _G.GameTooltip:AddLine(tooltipTitle or titleText or "DynamicChat", 1, 1, 1)
                if descText and descText ~= "" then
                    _G.GameTooltip:AddLine(descText, 0.72, 0.78, 0.86, true)
                end
                if tooltipCmdText and tooltipCmdText ~= "" then
                    _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", tooltipCmdText, "34D399"), 0.886, 0.910, 0.941)
                end
                _G.GameTooltip:Show()
            end
        end)
        card:SetScript("OnLeave", function()
            if _G.GameTooltip then _G.GameTooltip:Hide() end
        end)
    end

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

-- Direction A: 2-Pill Segmented Switch ([ Off | Enabled ]) with Unbounded String Width Contract & Option 3 Negative Pill Styling + 6-Tier Semantic Underline
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

local function AttachSegmentedSwitchToCard(card, getValue, onToggle, offText, onText, tooltipAction)
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
    offBtn.label:SetPoint("CENTER", offBtn, "CENTER", 0, 0)
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
    onBtn.label = onBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(onBtn.label, 11, "")
    onBtn.label:SetPoint("CENTER", onBtn, "CENTER", 0, 0)
    onBtn.label:SetText(onText or "Enabled")

    function wrap:RefreshValue()
        SetSafeFont(offBtn.label, 11, "")
        SetSafeFont(onBtn.label, 11, "")

        local rawOff = (offBtn.label.GetUnboundedStringWidth and offBtn.label:GetUnboundedStringWidth()) or offBtn.label:GetStringWidth() or 0
        local offW = math.max(58, math.ceil(math.max(rawOff, 24) + 24))
        local rawOn = (onBtn.label.GetUnboundedStringWidth and onBtn.label:GetUnboundedStringWidth()) or onBtn.label:GetStringWidth() or 0
        local onW = math.max(88, math.ceil(math.max(rawOn, 48) + 28))
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
            onBtn.label:SetTextColor(0.98, 0.99, 1.00)
        else
            offBtn.OffBar:Show()
            offBtn:SetBackdropColor(0.118, 0.141, 0.188, 0.98)
            offBtn:SetBackdropBorderColor(0.392, 0.455, 0.545, 0.90)
            offBtn.label:SetTextColor(0.886, 0.910, 0.941)

            onBtn:SetBackdropColor(0.059, 0.071, 0.094, 0)
            onBtn:SetBackdropBorderColor(0, 0, 0, 0)
            onBtn.label:SetTextColor(0.55, 0.60, 0.68)
        end
    end

    local function ShowSwitchTooltip(ownerBtn)
        if not _G.GameTooltip then return end
        _G.GameTooltip:SetOwner(ownerBtn, "ANCHOR_TOP")
        _G.GameTooltip:ClearLines()
        _G.GameTooltip:AddLine((card.title and card.title:GetText()) or "DynamicChat Setting", 1, 1, 1)
        _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", tooltipAction or "Toggle this DynamicChat setting On or Off.", "34D399"), 0.886, 0.910, 0.941)
        _G.GameTooltip:Show()
    end

    offBtn:SetScript("OnEnter", ShowSwitchTooltip)
    offBtn:SetScript("OnLeave", function() if _G.GameTooltip then _G.GameTooltip:Hide() end end)
    onBtn:SetScript("OnEnter", ShowSwitchTooltip)
    onBtn:SetScript("OnLeave", function() if _G.GameTooltip then _G.GameTooltip:Hide() end end)

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
local function EnsureDropdownClickCatcher()
    if dropdownClickCatcher then return dropdownClickCatcher end
    local cc = CreateFrame("Button", nil, UIParent)
    cc:SetFrameStrata("DIALOG")
    cc:SetFrameLevel(15)
    cc:SetAllPoints(UIParent)
    cc:EnableMouse(true)
    cc:RegisterForClicks("AnyUp", "AnyDown")
    cc:SetScript("OnClick", function()
        CloseActiveDropdown()
    end)
    cc:Hide()
    dropdownClickCatcher = cc
    return cc
end

local function EnsureSoundDropdownPopover()
    if soundDropdownPopover then return soundDropdownPopover end
    local menu = CreateFrame("Frame", "DynamicChatSoundDropdownPopover", UIParent, "BackdropTemplate")
    menu:SetFrameStrata("TOOLTIP")
    menu:SetFrameLevel(220)
    menu:SetToplevel(true)
    menu:SetClampedToScreen(true)
    menu:SetWidth(316)
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    local ar0, ag0, ab0 = GetSuiteAccent()
    menu:SetBackdropColor(0.043, 0.051, 0.071, 0.99)
    menu:SetBackdropBorderColor(ar0, ag0, ab0, 0.92)
    menu:EnableMouse(true)
    SafeRegisterUISpecialFrame("DynamicChatSoundDropdownPopover")

    local borderOverlay = CreateFrame("Frame", nil, menu, "BackdropTemplate")
    borderOverlay:SetAllPoints(menu)
    borderOverlay:SetFrameLevel(menu:GetFrameLevel() + 10)
    borderOverlay:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    borderOverlay:SetBackdropBorderColor(ar0, ag0, ab0, 0.92)
    menu.borderOverlay = borderOverlay

    local searchWrap = CreateFrame("Frame", nil, menu, "BackdropTemplate")
    searchWrap:SetHeight(24)
    searchWrap:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -5)
    searchWrap:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -6, -5)
    searchWrap:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    searchWrap:SetBackdropColor(0.035, 0.042, 0.060, 0.98)
    searchWrap:SetBackdropBorderColor(0.16, 0.19, 0.25, 0.90)
    menu.searchWrap = searchWrap

    local sb = CreateFrame("EditBox", nil, searchWrap)
    sb:SetPoint("TOPLEFT", searchWrap, "TOPLEFT", 8, -2)
    sb:SetPoint("BOTTOMRIGHT", searchWrap, "BOTTOMRIGHT", -24, 2)
    sb:SetAutoFocus(false)
    sb:SetMaxLetters(64)
    SetSafeFont(sb, 10.5, "")
    sb:SetTextColor(0.95, 0.97, 1.0, 1.0)
    menu.searchBox = sb

    local ph = searchWrap:CreateFontString(nil, "OVERLAY")
    ph:SetPoint("LEFT", sb, "LEFT", 0, 0)
    SetSafeFont(ph, 10.5, "")
    ph:SetTextColor(0.48, 0.54, 0.64, 0.90)
    ph:SetText("Search sounds...")
    menu.searchPlaceholder = ph

    local clrBtn = CreateFrame("Button", nil, searchWrap)
    clrBtn:SetSize(18, 18)
    clrBtn:SetPoint("RIGHT", searchWrap, "RIGHT", -3, 0)
    local clrTxt = clrBtn:CreateFontString(nil, "OVERLAY")
    clrTxt:SetPoint("CENTER", 0, 0)
    SetSafeFont(clrTxt, 9.5, "")
    clrTxt:SetTextColor(0.62, 0.68, 0.78, 0.95)
    clrTxt:SetText("X")
    clrBtn.txt = clrTxt
    clrBtn:Hide()
    clrBtn:SetScript("OnEnter", function(cb)
        local ar, ag, ab = GetSuiteAccent()
        cb.txt:SetTextColor(ar, ag, ab, 1.0)
    end)
    clrBtn:SetScript("OnLeave", function(cb)
        cb.txt:SetTextColor(0.62, 0.68, 0.78, 0.95)
    end)
    clrBtn:SetScript("OnClick", function()
        sb:SetText("")
        sb:ClearFocus()
    end)
    menu.searchClear = clrBtn

    sb:SetScript("OnEscapePressed", function()
        CloseActiveDropdown()
    end)

    local sf = CreateFrame("ScrollFrame", nil, menu)
    sf:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -33)
    sf:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -10, 4)
    sf:SetClipsChildren(true)

    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(300, 100)
    sf:SetScrollChild(content)

    local track = CreateFrame("Frame", nil, menu, "BackdropTemplate")
    track:SetWidth(4)
    track:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -3, -34)
    track:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -3, 5)
    track:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    track:SetBackdropColor(1, 1, 1, 0.06)
    track:EnableMouse(true)

    local thumb = CreateFrame("Button", nil, track, "BackdropTemplate")
    thumb:SetWidth(4)
    thumb:SetHeight(32)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    thumb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    thumb:SetBackdropColor(0.38, 0.45, 0.56, 0.90)
    thumb:EnableMouse(true)
    thumb:RegisterForClicks("LeftButtonUp", "LeftButtonDown")

    local function RefreshMenuThumbColor()
        if thumb._isDragging or thumb._isHovered then
            local ar, ag, ab = GetSuiteAccent()
            thumb:SetBackdropColor(ar, ag, ab, 1.0)
        else
            thumb:SetBackdropColor(0.38, 0.45, 0.56, 0.90)
        end
    end

    local function UpdateMenuThumb()
        local maxScroll = math.max(0, (content:GetHeight() or 0) - (sf:GetHeight() or 0))
        if maxScroll <= 1 then
            track:Hide()
            sf:SetVerticalScroll(0)
            return
        end
        track:Show()
        thumb:Show()
        local trackH = math.max(20, track:GetHeight() or 180)
        local ratio = math.min(1, (sf:GetHeight() or 1) / math.max(1, content:GetHeight() or 1))
        local thumbH = math.max(24, math.floor(trackH * ratio))
        thumb:SetHeight(thumbH)

        local cur = math.min(maxScroll, math.max(0, sf:GetVerticalScroll() or 0))
        local travel = math.max(1, trackH - thumbH)
        local yOff = -(cur / maxScroll) * travel
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, yOff)
        RefreshMenuThumbColor()
    end

    local function StepSoundMenuScroll(delta)
        local maxScroll = math.max(0, (content:GetHeight() or 0) - (sf:GetHeight() or 0))
        local nextScroll = math.min(maxScroll, math.max(0, (sf:GetVerticalScroll() or 0) - (delta * 26)))
        sf:SetVerticalScroll(nextScroll)
        UpdateMenuThumb()
    end

    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(_, delta)
        StepSoundMenuScroll(delta)
    end)
    track:EnableMouseWheel(true)
    track:SetScript("OnMouseWheel", function(_, delta)
        StepSoundMenuScroll(delta)
    end)
    thumb:EnableMouseWheel(true)
    thumb:SetScript("OnMouseWheel", function(_, delta)
        StepSoundMenuScroll(delta)
    end)

    track:SetScript("OnMouseDown", function(selfT, button)
        if button ~= "LeftButton" then return end
        local maxScroll = math.max(0, (content:GetHeight() or 0) - (sf:GetHeight() or 0))
        if maxScroll <= 1 then return end
        local top = selfT:GetTop()
        local bot = selfT:GetBottom()
        if not top or not bot or top <= bot then return end
        local scale = selfT:GetEffectiveScale() or 1
        local curY = select(2, GetCursorPosition()) / scale
        local trackH = top - bot
        local thumbH = thumb:GetHeight() or 24
        local travel = math.max(1, trackH - thumbH)
        local clickOff = (top - curY) - (thumbH * 0.5)
        local pct = math.max(0, math.min(1, clickOff / travel))
        sf:SetVerticalScroll(pct * maxScroll)
        UpdateMenuThumb()
    end)

    thumb:SetScript("OnEnter", function(self)
        self._isHovered = true
        RefreshMenuThumbColor()
    end)
    thumb:SetScript("OnLeave", function(self)
        self._isHovered = false
        RefreshMenuThumbColor()
    end)

    thumb:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self._isDragging = true
        RefreshMenuThumbColor()
        local startY = select(2, GetCursorPosition()) / (self:GetEffectiveScale() or 1)
        local lastY = startY
        local startScroll = sf:GetVerticalScroll() or 0
        local elapsedAcc = 0
        self:SetScript("OnUpdate", function(_, elapsed)
            if not IsMouseButtonDown("LeftButton") then
                self._isDragging = false
                self:SetScript("OnUpdate", nil)
                RefreshMenuThumbColor()
                return
            end
            elapsedAcc = elapsedAcc + (elapsed or 0)
            if elapsedAcc < 0.016 then return end
            elapsedAcc = 0
            local curY = select(2, GetCursorPosition()) / (self:GetEffectiveScale() or 1)
            if math.abs(curY - lastY) < 0.5 then return end
            lastY = curY
            local dy = startY - curY
            local maxScroll = math.max(0, (content:GetHeight() or 0) - (sf:GetHeight() or 0))
            local trackH = math.max(20, track:GetHeight() or 180)
            local travel = math.max(1, trackH - (self:GetHeight() or 24))
            local nextScroll = math.min(maxScroll, math.max(0, startScroll + (dy / travel) * maxScroll))
            sf:SetVerticalScroll(nextScroll)
            UpdateMenuThumb()
        end)
    end)
    thumb:SetScript("OnMouseUp", function(self)
        self._isDragging = false
        self:SetScript("OnUpdate", nil)
        RefreshMenuThumbColor()
    end)
    thumb:SetScript("OnHide", function(self)
        self._isDragging = false
        self._isHovered = false
        self:SetScript("OnUpdate", nil)
        RefreshMenuThumbColor()
    end)

    menu.scrollFrame = sf
    menu.content = content
    menu.track = track
    menu.thumb = thumb
    menu.UpdateMenuThumb = UpdateMenuThumb
    menu.rows = {}
    menu:Hide()

    menu:SetScript("OnHide", function(self)
        if self.searchBox then self.searchBox:ClearFocus() end
        if dropdownClickCatcher and dropdownClickCatcher:IsShown() then
            dropdownClickCatcher:Hide()
        end
        local prevOwner = self.ownerBtn
        self.ownerBtn = nil
        if activeDropdownMenu == self then
            activeDropdownMenu = nil
        end
        if prevOwner then
            if prevOwner.chevron then
                prevOwner.chevron:SetTexture(ICON_CHEVRON_DOWN)
            end
            if prevOwner.RefreshValue then
                prevOwner:RefreshValue()
            end
        end
    end)

    soundDropdownPopover = menu
    return menu
end

local function OpenSoundDropdownMenu(ownerBtn, channelKey)
    RegisterDynamicChatPopupClosers()
    local menu = EnsureSoundDropdownPopover()
    if activeDropdownMenu == menu and menu:IsShown() and menu.ownerBtn == ownerBtn then
        CloseActiveDropdown()
        return
    end
    CloseActiveDropdown()

    if ownerBtn and not ownerBtn._dcDropdownOnHideHooked then
        ownerBtn._dcDropdownOnHideHooked = true
        ownerBtn:HookScript("OnHide", CloseActiveDropdown)
    end

    local ar, ag, ab = GetSuiteAccent()
    local fillAlpha = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42
    menu:SetBackdropBorderColor(ar, ag, ab, 0.92)
    if menu.borderOverlay then
        menu.borderOverlay:SetBackdropBorderColor(ar, ag, ab, 0.92)
    end
    menu.ownerBtn = ownerBtn
    if menu.searchWrap then
        menu.searchWrap:SetBackdropBorderColor(ar, ag, ab, 0.40)
    end

    local rawOptions = GetSoundOptionsForChannel(channelKey)
    local maxTextW = 240
    for _, opt in ipairs(rawOptions) do
        if not opt.isHeader and not opt.isEmptyNotice then
            maxTextW = math.max(maxTextW, #(tostring(opt.label or "")) * 6.5)
        end
    end
    local popW = math.max(316, math.min(440, math.ceil(maxTextW + 78)))

    local curVal = GetSoundSlotValue(channelKey)

    local showSearch = (#rawOptions > 12)
    local searchAreaH = showSearch and 29 or 0
    menu.searchWrap:SetShown(showSearch)
    local maxVisH = 286

    local function RenderSoundRows(query)
        local qLower = tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if menu.searchPlaceholder then
            menu.searchPlaceholder:SetShown(qLower == "" and not menu.searchBox:HasFocus())
        end
        if menu.searchClear then
            menu.searchClear:SetShown(qLower ~= "")
        end

        local options = {}
        if qLower == "" then
            options = rawOptions
        else
            local pendingHdr = nil
            for _, opt in ipairs(rawOptions) do
                if opt.isHeader then
                    pendingHdr = opt
                elseif not opt.isEmptyNotice then
                    local lStr = tostring(opt.label or "")
                    local vStr = tostring(opt.value or "")
                    if lStr:lower():find(qLower, 1, true) or vStr:lower():find(qLower, 1, true) then
                        if pendingHdr then
                            table.insert(options, pendingHdr)
                            pendingHdr = nil
                        end
                        table.insert(options, opt)
                    end
                end
            end
            if #options == 0 then
                table.insert(options, { isEmptyNotice = true, label = "No matching sounds" })
            end
        end

        local totalContentH = 0
        for _, opt in ipairs(options) do
            totalContentH = totalContentH + (opt.isHeader and 20 or 26)
        end
        local viewH = math.min(maxVisH, math.max(26, totalContentH))
        local hasScrollbar = (totalContentH > viewH + 1)
        local rowWidth = popW - (hasScrollbar and 16 or 8)
        local menuH = searchAreaH + viewH + 8

        menu:SetSize(popW, menuH)
        local topOff = 4 + searchAreaH
        menu.scrollFrame:ClearAllPoints()
        menu.scrollFrame:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -topOff)
        menu.scrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", hasScrollbar and -12 or -4, 4)
        menu.track:ClearAllPoints()
        menu.track:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -3, -(topOff + 1))
        menu.track:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -3, 5)
        menu.content:SetSize(rowWidth, math.max(26, totalContentH))

        local yOff = 0
        for i = 1, math.max(#options, #menu.rows) do
            local row = menu.rows[i]
            local opt = options[i]
            if opt then
                if not row then
                    row = CreateFrame("Frame", nil, menu.content, "BackdropTemplate")
                    row:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8x8",
                        edgeFile = "Interface\\Buttons\\WHITE8x8",
                        edgeSize = 1,
                    })

                    local hdrLine = row:CreateTexture(nil, "ARTWORK")
                    hdrLine:SetHeight(1)
                    hdrLine:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 4, 1)
                    hdrLine:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 1)
                    hdrLine:Hide()
                    row.hdrLine = hdrLine

                    local selBtn = CreateFrame("Button", nil, row)
                    selBtn:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
                    selBtn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -26, 0)
                    selBtn:RegisterForClicks("LeftButtonUp")

                    local checkTex = selBtn:CreateTexture(nil, "ARTWORK")
                    checkTex:SetSize(10, 10)
                    checkTex:SetPoint("LEFT", selBtn, "LEFT", 7, 0)
                    checkTex:SetTexture(ICON_CHECK)
                    DisableTexPixelSnap(checkTex)
                    row.checkTex = checkTex

                    local lbl = selBtn:CreateFontString(nil, "OVERLAY")
                    SetSafeFont(lbl, 10.5, "")
                    lbl:SetPoint("LEFT", selBtn, "LEFT", 22, 0)
                    lbl:SetPoint("RIGHT", selBtn, "RIGHT", -4, 0)
                    lbl:SetJustifyH("LEFT")
                    lbl:SetWordWrap(false)
                    row.label = lbl
                    row.selBtn = selBtn

                    local prevBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
                    prevBtn:SetSize(20, 20)
                    prevBtn:SetPoint("RIGHT", row, "RIGHT", -3, 0)
                    prevBtn:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8x8",
                        edgeFile = "Interface\\Buttons\\WHITE8x8",
                        edgeSize = 1,
                    })
                    prevBtn:RegisterForClicks("LeftButtonUp")
                    local pTxt = prevBtn:CreateFontString(nil, "OVERLAY")
                    SetSafeFont(pTxt, 9.5, "")
                    pTxt:SetPoint("CENTER", prevBtn, "CENTER", 0, 0)
                    pTxt:SetText(">")
                    prevBtn.text = pTxt
                    row.prevBtn = prevBtn

                    menu.rows[i] = row
                end

                local rH = opt.isHeader and 20 or 26
                row:SetHeight(rH - 2)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", menu.content, "TOPLEFT", 0, -yOff - 1)
                row:SetWidth(rowWidth)
                yOff = yOff + rH

                if opt.isHeader then
                    row.selBtn:Hide()
                    row.prevBtn:Hide()
                    row.checkTex:Hide()
                    row.hdrLine:Show()
                    row.hdrLine:SetColorTexture(ar, ag, ab, 0.45)
                    row:SetBackdropColor(0.082, 0.098, 0.137, 0.90)
                    row:SetBackdropBorderColor(0, 0, 0, 0)
                    if not row.hdrLbl then
                        local hl = row:CreateFontString(nil, "OVERLAY")
                        hl:SetPoint("LEFT", row, "LEFT", 8, 0)
                        hl:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                        hl:SetJustifyH("LEFT")
                        hl:SetWordWrap(false)
                        row.hdrLbl = hl
                    end
                    SetSafeFont(row.hdrLbl, 9.5, "")
                    row.hdrLbl:SetTextColor(ar, ag, ab, 0.95)
                    row.hdrLbl:SetText(tostring(opt.label or ""):upper())
                    row.hdrLbl:Show()
                elseif opt.isEmptyNotice then
                    if row.hdrLbl then row.hdrLbl:Hide() end
                    row.hdrLine:Hide()
                    row.selBtn:Hide()
                    row.prevBtn:Hide()
                    row.checkTex:Hide()
                    row:SetBackdropColor(0.055, 0.063, 0.082, 0.70)
                    row:SetBackdropBorderColor(0, 0, 0, 0)
                    if not row.hdrLbl then
                        local hl = row:CreateFontString(nil, "OVERLAY")
                        hl:SetPoint("LEFT", row, "LEFT", 10, 0)
                        hl:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                        hl:SetJustifyH("LEFT")
                        row.hdrLbl = hl
                    end
                    SetSafeFont(row.hdrLbl, 10.5, "")
                    row.hdrLbl:SetTextColor(0.55, 0.62, 0.72, 0.90)
                    row.hdrLbl:SetText(tostring(opt.label or "No matching sounds"))
                    row.hdrLbl:Show()
                else
                    if row.hdrLbl then row.hdrLbl:Hide() end
                    row.hdrLine:Hide()
                    row.selBtn:Show()

                    local isSel = (opt.value == curVal)
                    local canPreview = (opt.value ~= "NONE")
                    SetSafeFont(row.label, 10.5, "")
                    row.label:SetText(opt.label)

                    local function RefreshRowStyle(hoverMain, hoverPrev)
                        local r1, g1, b1 = GetSuiteAccent()
                        if isSel then
                            row:SetBackdropColor(r1 * fillAlpha, g1 * fillAlpha, b1 * fillAlpha, 0.96)
                            row:SetBackdropBorderColor(r1, g1, b1, 0.90)
                            row.label:SetTextColor(1, 1, 1, 1)
                            row.checkTex:SetVertexColor(r1, g1, b1, 1)
                            row.checkTex:Show()
                        elseif hoverMain then
                            row:SetBackdropColor(0.118, 0.141, 0.188, 0.96)
                            row:SetBackdropBorderColor(r1, g1, b1, 0.65)
                            row.label:SetTextColor(0.98, 0.99, 1.00, 1)
                            row.checkTex:Hide()
                        else
                            row:SetBackdropColor(0.065, 0.075, 0.098, 0.90)
                            row:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.65)
                            row.label:SetTextColor(0.82, 0.86, 0.92, 1)
                            row.checkTex:Hide()
                        end

                        if canPreview then
                            row.prevBtn:Show()
                            SetSafeFont(row.prevBtn.text, 9.5, "")
                            if hoverPrev then
                                row.prevBtn:SetBackdropColor(r1 * 0.45, g1 * 0.45, b1 * 0.45, 0.98)
                                row.prevBtn:SetBackdropBorderColor(r1, g1, b1, 0.98)
                                row.prevBtn.text:SetTextColor(1, 1, 1, 1)
                            else
                                row.prevBtn:SetBackdropColor(0.043, 0.051, 0.071, 0.95)
                                row.prevBtn:SetBackdropBorderColor(0.24, 0.28, 0.36, 0.90)
                                row.prevBtn.text:SetTextColor(r1, g1, b1, 0.95)
                            end
                        else
                            row.prevBtn:Hide()
                        end
                    end

                    RefreshRowStyle(false, false)

                    row.selBtn:SetScript("OnEnter", function(selfBtn)
                        RefreshRowStyle(true, false)
                        if _G.GameTooltip then
                            _G.GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                            _G.GameTooltip:ClearLines()
                            _G.GameTooltip:AddLine(opt.label, 1, 1, 1)
                            if opt.source then
                                _G.GameTooltip:AddLine("Source: " .. tostring(opt.source), 0.68, 0.74, 0.82)
                            end
                            _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", "Select this alert sound and play a confirmation chime.", "34D399"), 0.886, 0.910, 0.941)
                            _G.GameTooltip:Show()
                        end
                    end)
                    row.selBtn:SetScript("OnLeave", function()
                        RefreshRowStyle(false, false)
                        if _G.GameTooltip then _G.GameTooltip:Hide() end
                    end)
                    row.selBtn:SetScript("OnClick", function()
                        SetSoundSlotValue(channelKey, opt.value)
                        if opt.value ~= "NONE" then
                            DynamicChat:PlaySoundOptionKey(opt.value, channelKey, true)
                        end
                        if ownerBtn and ownerBtn.RefreshValue then
                            ownerBtn:RefreshValue()
                        end
                        CloseActiveDropdown()
                    end)

                    row.prevBtn:SetScript("OnEnter", function(selfBtn)
                        RefreshRowStyle(false, true)
                        if _G.GameTooltip then
                            _G.GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                            _G.GameTooltip:ClearLines()
                            _G.GameTooltip:AddLine("Preview: " .. opt.label, 1, 1, 1)
                            _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", "Play sound preview without closing this menu.", "38BDF8"), 0.886, 0.910, 0.941)
                            _G.GameTooltip:Show()
                        end
                    end)
                    row.prevBtn:SetScript("OnLeave", function()
                        RefreshRowStyle(false, false)
                        if _G.GameTooltip then _G.GameTooltip:Hide() end
                    end)
                    row.prevBtn:SetScript("OnClick", function()
                        DynamicChat:PlaySoundOptionKey(opt.value, channelKey, true)
                    end)
                end
                row:Show()
            elseif row then
                row:Hide()
            end
        end

        menu.scrollFrame:SetVerticalScroll(0)
        menu.UpdateMenuThumb()
    end

    menu.searchBox:SetScript("OnTextChanged", function(sbEdit)
        if menu:IsShown() and menu.ownerBtn == ownerBtn then
            RenderSoundRows(sbEdit:GetText())
        end
    end)
    menu.searchBox:SetScript("OnEditFocusGained", function()
        if menu.searchPlaceholder then menu.searchPlaceholder:Hide() end
    end)
    menu.searchBox:SetScript("OnEditFocusLost", function(sbEdit)
        if menu.searchPlaceholder then menu.searchPlaceholder:SetShown((sbEdit:GetText() or "") == "") end
    end)

    menu.searchBox:SetText("")
    menu.searchBox:ClearFocus()
    RenderSoundRows("")

    local cc = EnsureDropdownClickCatcher()
    cc:Show()

    menu:ClearAllPoints()
    local menuH = menu:GetHeight() or 280
    local btnBottom = ownerBtn.GetBottom and ownerBtn:GetBottom() or 300
    if btnBottom and btnBottom < (menuH + 24) then
        menu:SetPoint("BOTTOMRIGHT", ownerBtn, "TOPRIGHT", 0, 2)
    else
        menu:SetPoint("TOPRIGHT", ownerBtn, "BOTTOMRIGHT", 0, -2)
    end

    menu:Show()
    menu.UpdateMenuThumb()
    activeDropdownMenu = menu
    if ownerBtn.RefreshValue then
        ownerBtn:RefreshValue()
    end
end

local function AttachSoundDropdownToCard(card, channelKey)
    local def = SOUND_CHANNEL_DEF_BY_KEY[channelKey]

    local playBtn = CreateFrame("Button", nil, card, "BackdropTemplate")
    playBtn:SetSize(48, 26)
    playBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -17)
    playBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    playBtn:RegisterForClicks("LeftButtonUp")

    local playTxt = playBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(playTxt, 10.5, "")
    playTxt:SetPoint("CENTER", playBtn, "CENTER", 0, 0)
    playTxt:SetText("Play")
    playBtn.label = playTxt

    local btn = CreateFrame("Button", nil, card, "BackdropTemplate")
    btn:SetSize(176, 26)
    btn:SetPoint("RIGHT", playBtn, "LEFT", -6, 0)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    AnchorCardTextToRightWidget(card, btn)

    local lbl = btn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(lbl, 10.5, "")
    lbl:SetPoint("LEFT", btn, "LEFT", 10, 0)
    lbl:SetPoint("RIGHT", btn, "RIGHT", -24, 0)
    lbl:SetJustifyH("LEFT")
    lbl:SetWordWrap(false)
    btn.label = lbl

    local chev = btn:CreateTexture(nil, "ARTWORK")
    chev:SetSize(10, 10)
    chev:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    chev:SetTexture(ICON_CHEVRON_DOWN)
    DisableTexPixelSnap(chev)
    btn.chevron = chev

    local bar = btn:CreateTexture(nil, "OVERLAY")
    bar:SetHeight(1.5)
    bar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
    bar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    DisableTexPixelSnap(bar)
    btn.tierBar = bar

    local function RefreshPlayButtonVisual(isHovered)
        local curVal = GetSoundSlotValue(channelKey)
        local ar, ag, ab = GetSuiteAccent()
        local isMuted = (curVal == "NONE" or curVal == "")
        SetSafeFont(playBtn.label, 10.5, "")
        if isMuted then
            playBtn:SetBackdropColor(0.043, 0.051, 0.071, 0.72)
            playBtn:SetBackdropBorderColor(0.16, 0.19, 0.24, 0.70)
            playBtn.label:SetTextColor(0.42, 0.48, 0.56, 0.70)
        elseif isHovered then
            playBtn:SetBackdropColor(ar * 0.24, ag * 0.24, ab * 0.24, 0.98)
            playBtn:SetBackdropBorderColor(ar, ag, ab, 1.0)
            playBtn.label:SetTextColor(1, 1, 1, 1)
        else
            playBtn:SetBackdropColor(0.043, 0.051, 0.071, 0.96)
            playBtn:SetBackdropBorderColor(ar, ag, ab, 0.72)
            playBtn.label:SetTextColor(ar, ag, ab, 1.0)
        end
    end

    function btn:RefreshValue()
        local db = EnsureDB()
        local curVal = GetSoundSlotValue(channelKey)
        local textLabel = GetSoundOptionLabel(channelKey, curVal)
        local ar, ag, ab = GetSuiteAccent()
        local fillAlpha = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42
        local isOpen = (activeDropdownMenu and activeDropdownMenu:IsShown() and activeDropdownMenu.ownerBtn == self)
        local masterOn = (db.enableChatSounds ~= false)

        SetSafeFont(self.label, 10.5, "")
        self.label:SetText(textLabel)
        self.chevron:SetTexture(isOpen and ICON_CHEVRON_UP or ICON_CHEVRON_DOWN)

        if curVal == "NONE" then
            self:SetBackdropColor(0.078, 0.090, 0.122, 0.96)
            self:SetBackdropBorderColor(isOpen and ar or 0.22, isOpen and ag or 0.26, isOpen and ab or 0.34, 0.92)
            self.label:SetTextColor(0.68, 0.74, 0.82, 0.95)
            self.chevron:SetVertexColor(0.68, 0.74, 0.82, 0.90)
            self.tierBar:SetColorTexture(0.973, 0.443, 0.443, 0.85)
            self.tierBar:Show()
        else
            self:SetBackdropColor(ar * (fillAlpha * 0.65), ag * (fillAlpha * 0.65), ab * (fillAlpha * 0.65), 0.96)
            self:SetBackdropBorderColor(ar, ag, ab, 0.95)
            self.label:SetTextColor(0.98, 0.99, 1.00, 1.0)
            self.chevron:SetVertexColor(1, 1, 1, 0.95)
            self.tierBar:SetColorTexture(ar, ag, ab, 0.95)
            self.tierBar:Show()
        end

        self:SetAlpha(masterOn and 1.0 or 0.58)
        playBtn:SetAlpha(masterOn and 1.0 or 0.58)
        RefreshPlayButtonVisual(false)
    end

    playBtn:SetScript("OnEnter", function(selfBtn)
        RefreshPlayButtonVisual(true)
        if not _G.GameTooltip then return end
        local curVal = GetSoundSlotValue(channelKey)
        local curLabel = GetSoundOptionLabel(channelKey, curVal)
        _G.GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
        _G.GameTooltip:ClearLines()
        _G.GameTooltip:AddLine("Preview: " .. GetSoundSlotTitle(channelKey), 1, 1, 1)
        if curVal == "NONE" then
            _G.GameTooltip:AddLine("Currently set to None (Muted). Choose a sound effect in the dropdown to preview.", 0.82, 0.86, 0.92, true)
        else
            _G.GameTooltip:AddLine("Selected Sound: " .. ColorWithAccent(curLabel), 0.82, 0.86, 0.92)
            _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", "Play '" .. curLabel .. "' preview now.", "38BDF8"), 0.886, 0.910, 0.941)
        end
        _G.GameTooltip:Show()
    end)
    playBtn:SetScript("OnLeave", function()
        RefreshPlayButtonVisual(false)
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)
    playBtn:SetScript("OnClick", function()
        local curVal = GetSoundSlotValue(channelKey)
        if curVal and curVal ~= "NONE" then
            DynamicChat:PlaySoundOptionKey(curVal, channelKey, true)
        end
    end)

    btn:SetScript("OnEnter", function(selfBtn)
        if not _G.GameTooltip then return end
        local curVal = GetSoundSlotValue(channelKey)
        local curLabel = GetSoundOptionLabel(channelKey, curVal)
        _G.GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
        _G.GameTooltip:ClearLines()
        _G.GameTooltip:AddLine(GetSoundSlotTitle(channelKey), 1, 1, 1)
        _G.GameTooltip:AddLine("Current Sound: " .. ColorWithAccent(curLabel), 0.82, 0.86, 0.92)
        _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", "Choose a sound effect (selecting automatically previews).", "34D399"), 0.886, 0.910, 0.941)
        _G.GameTooltip:AddLine(FormatTooltipCmd("Right-Click:", "Replay current sound effect.", "38BDF8"), 0.886, 0.910, 0.941)
        _G.GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)

    btn:SetScript("OnClick", function(selfBtn, mouseBtn)
        if mouseBtn == "RightButton" then
            local curVal = GetSoundSlotValue(channelKey)
            DynamicChat:PlaySoundOptionKey(curVal, channelKey, true)
            return
        end
        OpenSoundDropdownMenu(selfBtn, channelKey)
    end)
    if not btn._dcDropdownOnHideHooked then
        btn._dcDropdownOnHideHooked = true
        btn:HookScript("OnHide", function(selfBtn)
            if activeDropdownMenu and activeDropdownMenu:IsShown() and activeDropdownMenu.ownerBtn == selfBtn then
                CloseActiveDropdown()
            end
        end)
    end

    btn:RefreshValue()
    card.playBtn = playBtn
    card.toggleBtn = btn
    return btn
end

-- Read-Only Midnight 12.1.5 Status Badge for Permanent Zero-Taint Protections
local function AttachReadOnlyStatusBadgeToCard(card, badgeText, tooltipDetail)
    local badge = CreateFrame("Frame", nil, card, "BackdropTemplate")
    badge:SetSize(164, 24)
    badge:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -18)
    badge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    badge:SetBackdropColor(0.06, 0.16, 0.11, 0.96)
    badge:SetBackdropBorderColor(0.133, 0.773, 0.369, 0.85)
    badge:EnableMouse(true)

    local dot = badge:CreateTexture(nil, "OVERLAY")
    dot:SetSize(6, 6)
    dot:SetPoint("LEFT", badge, "LEFT", 10, 0)
    dot:SetColorTexture(0.133, 0.773, 0.369, 1.0)

    local lbl = badge:CreateFontString(nil, "OVERLAY")
    SetSafeFont(lbl, 10, "")
    lbl:SetPoint("LEFT", dot, "RIGHT", 6, 0)
    lbl:SetTextColor(0.20, 0.90, 0.50, 1.0)
    lbl:SetText(badgeText or "Always Protected (12.1.5)")
    local lw = (lbl.GetStringWidth and lbl:GetStringWidth()) or 128
    badge:SetWidth(math.max(148, math.ceil(lw + 30)))

    AnchorCardTextToRightWidget(card, badge)

    badge:SetScript("OnEnter", function(selfBadge)
        if not _G.GameTooltip then return end
        _G.GameTooltip:SetOwner(selfBadge, "ANCHOR_TOP")
        _G.GameTooltip:ClearLines()
        _G.GameTooltip:AddLine((card.title and card.title:GetText()) or "Midnight 12.1.5 Protection", 1, 1, 1)
        _G.GameTooltip:AddLine(tooltipDetail or "Permanently enabled to keep whisper and Battle.net messages error-free in combat.", 0.82, 0.86, 0.92, true)
        _G.GameTooltip:Show()
    end)
    badge:SetScript("OnLeave", function()
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)

    function badge:RefreshValue()
        SetSafeFont(lbl, 10, "")
    end

    card.toggleBtn = badge
    return badge
end

-- Direction A: Multi-Pill Segmented Selector (3-Pill or 4-Pill) with Unbounded String Width Contract
local function AttachMultiPillSelectorToCard(card, options, getValue, onSelect, tooltipAction)
    local wrap = CreateFrame("Frame", nil, card, "BackdropTemplate")
    wrap:SetSize(240, 26)
    wrap:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -17)
    wrap:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    wrap:SetBackdropColor(0.059, 0.071, 0.094, 0.98)
    wrap:SetBackdropBorderColor(0.145, 0.165, 0.212, 1.00)

    AnchorCardTextToRightWidget(card, wrap)

    wrap.pills = {}
    for idx, opt in ipairs(options or {}) do
        local btn = CreateFrame("Button", nil, wrap, "BackdropTemplate")
        btn:SetHeight(24)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn.optValue = opt.value
        btn.optLabel = opt.label or tostring(opt.value)
        btn.isNegativeOpt = IsNegativePillOption(opt.value, btn.optLabel)
        btn.label = btn:CreateFontString(nil, "OVERLAY")
        SetSafeFont(btn.label, 10.5, "")
        btn.label:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.label:SetText(btn.optLabel)

        btn.OffBar = btn:CreateTexture(nil, "OVERLAY")
        btn.OffBar:SetHeight(1.5)
        btn.OffBar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
        btn.OffBar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        btn.OffBar:SetColorTexture(0.973, 0.443, 0.443, 0.90)
        btn.OffBar:Hide()
        btn.TierBar = btn.OffBar

        btn:SetScript("OnEnter", function(selfBtn)
            if not _G.GameTooltip then return end
            _G.GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
            _G.GameTooltip:ClearLines()
            _G.GameTooltip:AddLine((card.title and card.title:GetText()) or "DynamicChat Option", 1, 1, 1)
            _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", tooltipAction or ("Select " .. tostring(btn.optLabel) .. "."), "34D399"), 0.886, 0.910, 0.941)
            _G.GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            if _G.GameTooltip then _G.GameTooltip:Hide() end
        end)

        btn:SetScript("OnClick", function()
            CloseActiveDropdown()
            if getValue() ~= btn.optValue then
                onSelect(btn.optValue)
                wrap:RefreshValue()
                if _G.DynamicSuite and type(_G.DynamicSuite.RefreshHeaderStatus) == "function" then
                    pcall(_G.DynamicSuite.RefreshHeaderStatus)
                end
            end
        end)

        wrap.pills[idx] = btn
    end

    function wrap:RefreshValue()
        local curVal = getValue()
        local ar, ag, ab = GetSuiteAccent()
        local fillAlpha = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42
        local totalW = 2

        for idx, btn in ipairs(self.pills) do
            SetSafeFont(btn.label, 10.5, "")
            local rawW = (btn.label.GetUnboundedStringWidth and btn.label:GetUnboundedStringWidth()) or btn.label:GetStringWidth() or 0
            local pillW = math.max(66, math.ceil(math.max(rawW, 34) + 20))
            btn:SetWidth(pillW)
            btn:ClearAllPoints()
            if idx == 1 then
                btn:SetPoint("LEFT", self, "LEFT", 1, 0)
            else
                btn:SetPoint("LEFT", self.pills[idx - 1], "RIGHT", 1, 0)
            end
            totalW = totalW + pillW + (idx > 1 and 1 or 0)

            local isSel = (btn.optValue == curVal)
            if isSel then
                local tr, tg, tb, ta, isNeg = GetPillTierUnderlineColor(btn.optValue, btn.optLabel)
                if isNeg or btn.isNegativeOpt then
                    btn.OffBar:SetColorTexture(tr or 0.973, tg or 0.443, tb or 0.443, ta or 0.90)
                    btn.OffBar:Show()
                    btn:SetBackdropColor(0.118, 0.141, 0.188, 0.98)
                    btn:SetBackdropBorderColor(0.392, 0.455, 0.545, 0.90)
                    btn.label:SetTextColor(0.886, 0.910, 0.941)
                else
                    btn:SetBackdropColor(ar * fillAlpha, ag * fillAlpha, ab * fillAlpha, 0.96)
                    btn:SetBackdropBorderColor(ar, ag, ab, 0.95)
                    btn.label:SetTextColor(0.98, 0.99, 1.00)
                    if tr then
                        btn.OffBar:SetColorTexture(tr, tg, tb, ta)
                        btn.OffBar:Show()
                    else
                        btn.OffBar:Hide()
                    end
                end
            else
                btn.OffBar:Hide()
                btn:SetBackdropColor(0.059, 0.071, 0.094, 0)
                btn:SetBackdropBorderColor(0, 0, 0, 0)
                btn.label:SetTextColor(0.58, 0.64, 0.72)
            end
        end
        self:SetSize(totalW, 26)
    end

    wrap:RefreshValue()
    card.toggleBtn = wrap
    return wrap
end

do
    local function OpenFontDropdownMenu(ownerBtn)
        RegisterDynamicChatPopupClosers()
        if activeDropdownMenu and activeDropdownMenu == fontDropdownMenu and fontDropdownMenu:IsShown() and fontDropdownMenu.ownerBtn == ownerBtn then
            CloseActiveDropdown()
            return
        end
        CloseActiveDropdown()

        if ownerBtn and not ownerBtn._dcDropdownOnHideHooked then
            ownerBtn._dcDropdownOnHideHooked = true
            ownerBtn:HookScript("OnHide", CloseActiveDropdown)
        end

        if not fontDropdownMenu then
            local m = CreateFrame("Frame", "DynamicChatFontDropdownMenu", UIParent, "BackdropTemplate")
            m:SetFrameStrata("TOOLTIP")
            m:SetFrameLevel(220)
            m:SetToplevel(true)
            m:SetSize(290, 310)
            m:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            m:SetClampedToScreen(true)
            m:EnableMouse(true)
            SafeRegisterUISpecialFrame("DynamicChatFontDropdownMenu")

            local borderOverlay = CreateFrame("Frame", nil, m, "BackdropTemplate")
            borderOverlay:SetAllPoints(m)
            borderOverlay:SetFrameLevel(m:GetFrameLevel() + 10)
            borderOverlay:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            local arB, agB, abB = GetSuiteAccent()
            borderOverlay:SetBackdropBorderColor(arB, agB, abB, 0.92)
            m.borderOverlay = borderOverlay

            local sb = CreateFrame("EditBox", nil, m, "BackdropTemplate")
            sb:SetHeight(24)
            sb:SetPoint("TOPLEFT", m, "TOPLEFT", 8, -8)
            sb:SetPoint("TOPRIGHT", m, "TOPRIGHT", -8, -8)
            sb:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            sb:SetAutoFocus(false)
            sb:SetTextInsets(8, 24, 0, 0)
            SetSafeFont(sb, 10.5, "")
            sb:SetTextColor(0.95, 0.96, 0.98, 1)
            sb:SetScript("OnEscapePressed", function() CloseActiveDropdown() end)
            m.searchBox = sb

            local ph = sb:CreateFontString(nil, "OVERLAY")
            SetSafeFont(ph, 10, "")
            ph:SetPoint("LEFT", sb, "LEFT", 8, 0)
            ph:SetText("Search fonts (Blizzard, Suite, SharedMedia)...")
            ph:SetTextColor(0.45, 0.50, 0.58, 0.9)
            m.searchPlaceholder = ph

            local clrBtn = CreateFrame("Button", nil, sb)
            clrBtn:SetSize(18, 18)
            clrBtn:SetPoint("RIGHT", sb, "RIGHT", -3, 0)
            local clrTxt = clrBtn:CreateFontString(nil, "OVERLAY")
            clrTxt:SetPoint("CENTER", 0, 0)
            SetSafeFont(clrTxt, 9.5, "")
            clrTxt:SetTextColor(0.62, 0.68, 0.78, 0.95)
            clrTxt:SetText("X")
            clrBtn.txt = clrTxt
            clrBtn:Hide()
            clrBtn:SetScript("OnEnter", function(cb)
                local rA, gA, bA = GetSuiteAccent()
                cb.txt:SetTextColor(rA, gA, bA, 1.0)
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
            sf:SetPoint("TOPLEFT", sb, "BOTTOMLEFT", 0, -6)
            sf:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -14, 8)
            sf:SetClipsChildren(true)
            sf:EnableMouseWheel(true)
            m.scrollFrame = sf

            local sc = CreateFrame("Frame", nil, sf)
            sc:SetSize(260, 1)
            sf:SetScrollChild(sc)
            m.scrollChild = sc

            local track = CreateFrame("Frame", nil, m, "BackdropTemplate")
            track:SetWidth(4)
            track:SetPoint("TOPRIGHT", m, "TOPRIGHT", -5, -38)
            track:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -5, 8)
            track:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            track:SetBackdropColor(1, 1, 1, 0.06)
            track:EnableMouse(true)
            m.track = track

            local thumb = CreateFrame("Button", nil, track, "BackdropTemplate")
            thumb:SetWidth(4)
            thumb:SetHeight(32)
            thumb:SetPoint("TOP", track, "TOP", 0, 0)
            thumb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            thumb:SetBackdropColor(0.38, 0.45, 0.56, 0.90)
            thumb:EnableMouse(true)
            thumb:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
            m.thumb = thumb

            local function RefreshFontThumbColor()
                if thumb._isDragging or thumb._isHovered then
                    local rA, gA, bA = GetSuiteAccent()
                    thumb:SetBackdropColor(rA, gA, bA, 1.0)
                else
                    thumb:SetBackdropColor(0.38, 0.45, 0.56, 0.90)
                end
            end

            m.UpdateMenuThumb = function()
                local maxScroll = math.max(0, (sc:GetHeight() or 0) - (sf:GetHeight() or 1))
                if maxScroll <= 1 then
                    track:Hide()
                    sf:SetVerticalScroll(0)
                    return
                end
                track:Show()
                thumb:Show()
                local trackH = math.max(20, track:GetHeight() or 200)
                local viewH = math.max(1, sf:GetHeight() or 200)
                local totalH = math.max(1, sc:GetHeight() or viewH)
                local ratio = math.min(1, viewH / totalH)
                local thumbH = math.max(24, math.floor(trackH * ratio))
                thumb:SetHeight(thumbH)

                local cur = math.min(maxScroll, math.max(0, sf:GetVerticalScroll() or 0))
                local travel = math.max(1, trackH - thumbH)
                local yOff = -(cur / maxScroll) * travel
                thumb:ClearAllPoints()
                thumb:SetPoint("TOP", track, "TOP", 0, yOff)
                RefreshFontThumbColor()
            end

            local function StepFontMenuScroll(delta)
                local maxScroll = math.max(0, (sc:GetHeight() or 0) - (sf:GetHeight() or 1))
                local nextS = math.max(0, math.min(maxScroll, (sf:GetVerticalScroll() or 0) - delta * 28))
                sf:SetVerticalScroll(nextS)
                m.UpdateMenuThumb()
            end

            sf:SetScript("OnMouseWheel", function(_, delta)
                StepFontMenuScroll(delta)
            end)
            track:EnableMouseWheel(true)
            track:SetScript("OnMouseWheel", function(_, delta)
                StepFontMenuScroll(delta)
            end)
            thumb:EnableMouseWheel(true)
            thumb:SetScript("OnMouseWheel", function(_, delta)
                StepFontMenuScroll(delta)
            end)

            track:SetScript("OnMouseDown", function(selfT, button)
                if button ~= "LeftButton" then return end
                local maxScroll = math.max(0, (sc:GetHeight() or 0) - (sf:GetHeight() or 1))
                if maxScroll <= 1 then return end
                local top = selfT:GetTop()
                local bot = selfT:GetBottom()
                if not top or not bot or top <= bot then return end
                local scale = selfT:GetEffectiveScale() or 1
                local curY = select(2, GetCursorPosition()) / scale
                local trackH = top - bot
                local thumbH = thumb:GetHeight() or 24
                local travel = math.max(1, trackH - thumbH)
                local clickOff = (top - curY) - (thumbH * 0.5)
                local pct = math.max(0, math.min(1, clickOff / travel))
                sf:SetVerticalScroll(pct * maxScroll)
                m.UpdateMenuThumb()
            end)

            thumb:SetScript("OnEnter", function(self)
                self._isHovered = true
                RefreshFontThumbColor()
            end)
            thumb:SetScript("OnLeave", function(self)
                self._isHovered = false
                RefreshFontThumbColor()
            end)

            thumb:SetScript("OnMouseDown", function(self, button)
                if button ~= "LeftButton" then return end
                self._isDragging = true
                RefreshFontThumbColor()
                local startY = select(2, GetCursorPosition()) / (self:GetEffectiveScale() or 1)
                local lastY = startY
                local startScroll = sf:GetVerticalScroll() or 0
                local elapsedAcc = 0
                self:SetScript("OnUpdate", function(_, elapsed)
                    if not IsMouseButtonDown("LeftButton") then
                        self._isDragging = false
                        self:SetScript("OnUpdate", nil)
                        RefreshFontThumbColor()
                        return
                    end
                    elapsedAcc = elapsedAcc + (elapsed or 0)
                    if elapsedAcc < 0.016 then return end
                    elapsedAcc = 0
                    local curY = select(2, GetCursorPosition()) / (self:GetEffectiveScale() or 1)
                    if math.abs(curY - lastY) < 0.5 then return end
                    lastY = curY
                    local dy = startY - curY
                    local maxScroll = math.max(0, (sc:GetHeight() or 0) - (sf:GetHeight() or 1))
                    local trackH = math.max(20, track:GetHeight() or 200)
                    local travel = math.max(1, trackH - (self:GetHeight() or 24))
                    local nextScroll = math.min(maxScroll, math.max(0, startScroll + (dy / travel) * maxScroll))
                    sf:SetVerticalScroll(nextScroll)
                    m.UpdateMenuThumb()
                end)
            end)
            thumb:SetScript("OnMouseUp", function(self)
                self._isDragging = false
                self:SetScript("OnUpdate", nil)
                RefreshFontThumbColor()
            end)
            thumb:SetScript("OnHide", function(self)
                self._isDragging = false
                self._isHovered = false
                self:SetScript("OnUpdate", nil)
                RefreshFontThumbColor()
            end)

            m:SetScript("OnHide", function(self)
                if self.searchBox then self.searchBox:ClearFocus() end
                if dropdownClickCatcher and dropdownClickCatcher:IsShown() then
                    dropdownClickCatcher:Hide()
                end
                local prevOwner = self.ownerBtn
                self.ownerBtn = nil
                if activeDropdownMenu == self then
                    activeDropdownMenu = nil
                end
                if prevOwner then
                    if prevOwner.chevron then
                        prevOwner.chevron:SetTexture(ICON_CHEVRON_DOWN)
                    end
                    if prevOwner.RefreshValue then
                        prevOwner:RefreshValue()
                    end
                end
            end)

            m.rows = {}
            m:Hide()
            fontDropdownMenu = m
        end

        local m = fontDropdownMenu
        m.ownerBtn = ownerBtn
        local ar, ag, ab = GetSuiteAccent()
        m:SetBackdropColor(0.043, 0.051, 0.071, 0.99)
        m:SetBackdropBorderColor(ar, ag, ab, 0.92)
        if m.borderOverlay then
            m.borderOverlay:SetBackdropBorderColor(ar, ag, ab, 0.92)
        end
        m.searchBox:SetBackdropColor(0.035, 0.042, 0.060, 0.98)
        m.searchBox:SetBackdropBorderColor(ar, ag, ab, 0.40)

        local function RenderFontRows(filterText)
            local q = string.lower(string.gsub(filterText or "", "^%s*(.-)%s*$", "%1"))
            if m.searchPlaceholder then
                m.searchPlaceholder:SetShown(q == "" and not m.searchBox:HasFocus())
            end
            if m.searchClear then
                m.searchClear:SetShown(q ~= "")
            end
            local opts = TypographyMgr.GetFontOptions()
            local items = {}
            local lastGroup = nil
            for _, opt in ipairs(opts) do
                local lblLow = string.lower(opt.label or "")
                local srcLow = string.lower(opt.source or "")
                if q == "" or string.find(lblLow, q, 1, true) or string.find(srcLow, q, 1, true) then
                    if opt.group ~= lastGroup then
                        lastGroup = opt.group
                        items[#items + 1] = { isHeader = true, label = opt.group }
                    end
                    items[#items + 1] = { isHeader = false, opt = opt }
                end
            end

            local curKey = EnsureDB().chatFontKey or "SUITE"
            local yOff = 0
            local sc = m.scrollChild
            for idx, entry in ipairs(items) do
                local row = m.rows[idx]
                if not row then
                    row = CreateFrame("Button", nil, sc, "BackdropTemplate")
                    row:SetHeight(22)
                    row:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8x8",
                        edgeFile = "Interface\\Buttons\\WHITE8x8",
                        edgeSize = 1,
                    })
                    row.label = row:CreateFontString(nil, "OVERLAY")
                    row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
                    row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                    row.label:SetJustifyH("LEFT")
                    row.label:SetWordWrap(false)
                    m.rows[idx] = row
                end

                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, -yOff)
                row:SetPoint("TOPRIGHT", sc, "TOPRIGHT", 0, -yOff)

                if entry.isHeader then
                    row:SetHeight(18)
                    row:EnableMouse(false)
                    row:SetBackdropColor(0, 0, 0, 0)
                    row:SetBackdropBorderColor(0, 0, 0, 0)
                    SetSafeFont(row.label, 9, "OUTLINE")
                    row.label:SetText(entry.label)
                    row.label:SetTextColor(ar, ag, ab, 0.95)
                    row:SetScript("OnEnter", nil)
                    row:SetScript("OnLeave", nil)
                    row:SetScript("OnClick", nil)
                    yOff = yOff + 20
                else
                    local opt = entry.opt
                    local isSel = (curKey == opt.value)
                    row:SetHeight(23)
                    row:EnableMouse(true)
                    local previewPath = opt.path or TypographyMgr.ResolveFontPath(opt.value)
                    local okF = row.label:SetFont(previewPath, 11, "")
                    if not okF then SetSafeFont(row.label, 11, "") end
                    row.label:SetText(opt.label)

                    local function StyleFontRow(hovered)
                        if isSel then
                            row:SetBackdropColor(ar * 0.24, ag * 0.24, ab * 0.24, 0.98)
                            row:SetBackdropBorderColor(ar, ag, ab, 0.95)
                            row.label:SetTextColor(1, 1, 1, 1)
                        elseif hovered then
                            row:SetBackdropColor(0.11, 0.13, 0.17, 0.96)
                            row:SetBackdropBorderColor(0.28, 0.33, 0.42, 0.90)
                            row.label:SetTextColor(0.95, 0.97, 1, 1)
                        else
                            row:SetBackdropColor(0.065, 0.075, 0.098, 0.88)
                            row:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.60)
                            row.label:SetTextColor(0.84, 0.88, 0.94, 1)
                        end
                    end
                    StyleFontRow(false)
                    row:SetScript("OnEnter", function() StyleFontRow(true) end)
                    row:SetScript("OnLeave", function() StyleFontRow(false) end)
                    row:SetScript("OnClick", function()
                        EnsureDB().chatFontKey = opt.value
                        DynamicChat:ApplyChatFrameTypography()
                        if ownerBtn and ownerBtn.RefreshValue then ownerBtn:RefreshValue() end
                        CloseActiveDropdown()
                    end)
                    yOff = yOff + 25
                end
                row:Show()
            end

            for idx = #items + 1, #m.rows do
                m.rows[idx]:Hide()
            end
            sc:SetHeight(math.max(1, yOff))
            m.scrollFrame:SetVerticalScroll(0)
            m.UpdateMenuThumb()
        end

        m.searchBox:SetScript("OnTextChanged", function(sbEdit)
            if m:IsShown() and m.ownerBtn == ownerBtn then
                RenderFontRows(sbEdit:GetText())
            end
        end)
        m.searchBox:SetScript("OnEditFocusGained", function()
            if m.searchPlaceholder then m.searchPlaceholder:Hide() end
        end)
        m.searchBox:SetScript("OnEditFocusLost", function(sbEdit)
            if m.searchPlaceholder then m.searchPlaceholder:SetShown((sbEdit:GetText() or "") == "") end
        end)

        m.searchBox:SetText("")
        m.searchBox:ClearFocus()
        if m.searchPlaceholder then m.searchPlaceholder:Show() end
        if m.searchClear then m.searchClear:Hide() end
        RenderFontRows("")

        local cc = EnsureDropdownClickCatcher()
        cc:Show()

        m:ClearAllPoints()
        local menuH = m:GetHeight() or 310
        local btnBottom = ownerBtn.GetBottom and ownerBtn:GetBottom() or 300
        if btnBottom and btnBottom < (menuH + 24) then
            m:SetPoint("BOTTOMRIGHT", ownerBtn, "TOPRIGHT", 0, 2)
        else
            m:SetPoint("TOPRIGHT", ownerBtn, "BOTTOMRIGHT", 0, -2)
        end

        m:Show()
        m.UpdateMenuThumb()
        activeDropdownMenu = m
        if ownerBtn.chevron then
            ownerBtn.chevron:SetTexture(ICON_CHEVRON_UP)
        end
        if ownerBtn.RefreshValue then
            ownerBtn:RefreshValue()
        end
    end

    function TypographyMgr.AttachFontDropdownToCard(card)
        local btn = CreateFrame("Button", nil, card, "BackdropTemplate")
        btn:SetSize(224, 26)
        btn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -17)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        AnchorCardTextToRightWidget(card, btn)

        local lbl = btn:CreateFontString(nil, "OVERLAY")
        SetSafeFont(lbl, 10.5, "")
        lbl:SetPoint("LEFT", btn, "LEFT", 10, 0)
        lbl:SetPoint("RIGHT", btn, "RIGHT", -24, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetWordWrap(false)
        btn.label = lbl

        local chev = btn:CreateTexture(nil, "ARTWORK")
        chev:SetSize(10, 10)
        chev:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
        chev:SetTexture(ICON_CHEVRON_DOWN)
        DisableTexPixelSnap(chev)
        btn.chevron = chev

        local bar = btn:CreateTexture(nil, "OVERLAY")
        bar:SetHeight(1.5)
        bar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
        bar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        DisableTexPixelSnap(bar)
        btn.tierBar = bar

        btn.RefreshValue = function(self)
            local ar, ag, ab = GetSuiteAccent()
            local curKey = EnsureDB().chatFontKey or "SUITE"
            local isOpen = (activeDropdownMenu and activeDropdownMenu:IsShown() and activeDropdownMenu.ownerBtn == self)
            SetSafeFont(self.label, 10.5, "")
            self.label:SetText(TypographyMgr.GetFontLabel(curKey))
            self:SetBackdropColor(0.065, 0.075, 0.098, 0.96)
            self:SetBackdropBorderColor(isOpen and ar or 0.24, isOpen and ag or 0.28, isOpen and ab or 0.36, 0.95)
            self.label:SetTextColor(0.95, 0.97, 1, 1)
            self.chevron:SetTexture(isOpen and ICON_CHEVRON_UP or ICON_CHEVRON_DOWN)
            self.chevron:SetVertexColor(ar, ag, ab, 0.95)
            self.tierBar:SetColorTexture(ar, ag, ab, 0.85)
        end

        btn:SetScript("OnEnter", function(selfBtn)
            local ar, ag, ab = GetSuiteAccent()
            selfBtn:SetBackdropColor(ar * 0.14, ag * 0.14, ab * 0.14, 0.98)
            selfBtn:SetBackdropBorderColor(ar, ag, ab, 1.0)
            if _G.GameTooltip then
                _G.GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
                _G.GameTooltip:ClearLines()
                _G.GameTooltip:AddLine("Chat Font Family", 1, 1, 1)
                _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", "Browse built-in, Blizzard, and SharedMedia fonts.", "34D399"), 0.886, 0.910, 0.941)
                _G.GameTooltip:AddLine(FormatTooltipCmd("Right-Click:", "Reset to Use Suite Theme Font (Default).", "FBBF24"), 0.886, 0.910, 0.941)
                _G.GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function(selfBtn)
            selfBtn:RefreshValue()
            if _G.GameTooltip then _G.GameTooltip:Hide() end
        end)
        btn:SetScript("OnClick", function(selfBtn, mouseBtn)
            if mouseBtn == "RightButton" then
                EnsureDB().chatFontKey = "SUITE"
                DynamicChat:ApplyChatFrameTypography()
                selfBtn:RefreshValue()
                CloseActiveDropdown()
                return
            end
            OpenFontDropdownMenu(selfBtn)
        end)
        if not btn._dcDropdownOnHideHooked then
            btn._dcDropdownOnHideHooked = true
            btn:HookScript("OnHide", function(selfBtn)
                if activeDropdownMenu and activeDropdownMenu:IsShown() and activeDropdownMenu.ownerBtn == selfBtn then
                    CloseActiveDropdown()
                end
            end)
        end

        btn:RefreshValue()
        card.toggleBtn = btn
        return btn
    end

    function TypographyMgr.AttachSliderToCard(card, minVal, maxVal, stepVal, suffix, getValue, onChanged, tooltipAction)
        local wrap = CreateFrame("Frame", nil, card)
        wrap:SetSize(256, 26)
        wrap:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -17)
        AnchorCardTextToRightWidget(card, wrap)

        local valText = wrap:CreateFontString(nil, "OVERLAY")
        SetSafeFont(valText, 11, "")
        valText:SetPoint("RIGHT", wrap, "RIGHT", 0, 0)
        valText:SetWidth(52)
        valText:SetJustifyH("RIGHT")
        valText:SetWordWrap(false)

        local slider = CreateFrame("Slider", nil, wrap)
        slider:SetPoint("LEFT", wrap, "LEFT", 0, 0)
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

        local fillTex = slider:CreateTexture(nil, "ARTWORK")
        fillTex:SetPoint("TOPLEFT", slider, "TOPLEFT", 0, 0)
        fillTex:SetPoint("BOTTOMLEFT", slider, "BOTTOMLEFT", 0, 0)
        fillTex:SetWidth(1)
        DisableTexPixelSnap(fillTex)

        local thumbTex = slider:CreateTexture(nil, "OVERLAY")
        thumbTex:SetSize(6, 14)
        thumbTex:SetColorTexture(0.973, 0.980, 0.988, 1.0) -- #F8FAFC at rest
        DisableTexPixelSnap(thumbTex)
        slider:SetThumbTexture(thumbTex)

        local isDragging = false
        local lastCommitted = nil

        local function SnapValue(v)
            v = math.max(minVal, math.min(maxVal, tonumber(v) or minVal))
            if stepVal and stepVal > 0 then
                v = math.floor(((v - minVal) / stepVal) + 0.5) * stepVal + minVal
            end
            return math.max(minVal, math.min(maxVal, v))
        end

        local function UpdateSliderVisual(rawVal)
            local ar, ag, ab = GetSuiteAccent()
            fillTex:SetColorTexture(ar, ag, ab, 0.85)
            valText:SetTextColor(ar, ag, ab, 1.0)
            if isDragging or slider:IsMouseOver() then
                thumbTex:SetColorTexture(ar, ag, ab, 1.0)
            else
                thumbTex:SetColorTexture(0.973, 0.980, 0.988, 1.0)
            end
            local v = rawVal or slider:GetValue() or minVal
            local pct = (maxVal > minVal) and ((v - minVal) / (maxVal - minVal)) or 0
            if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
            local tw = slider:GetWidth()
            if not tw or tw <= 0 then tw = 194 end
            fillTex:SetWidth(math.max(1, pct * tw))
            SetSafeFont(valText, 11, "")
            valText:SetText(tostring(SnapValue(v)) .. (suffix or ""))
        end

        wrap.RefreshValue = function()
            wrap._refreshing = true
            local v = SnapValue(getValue())
            lastCommitted = v
            slider:SetValue(v)
            UpdateSliderVisual(v)
            wrap._refreshing = false
        end

        local function UpdateSliderFromCursor()
            if isDragging and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                isDragging = false
                slider:SetScript("OnUpdate", nil)
                wrap:RefreshValue()
                return
            end
            local scale = slider:GetEffectiveScale() or 1
            local cx = (select(1, GetCursorPosition()) or 0) / scale
            local left, tw = slider:GetLeft(), slider:GetWidth()
            if left and tw and tw > 0 then
                local pct = math.max(0, math.min(1, (cx - left) / tw))
                slider:SetValue(minVal + pct * (maxVal - minVal))
            end
        end

        slider:SetScript("OnSizeChanged", function()
            UpdateSliderVisual(slider:GetValue())
        end)

        slider:SetScript("OnValueChanged", function(_, rawVal)
            local stepped = SnapValue(rawVal)
            UpdateSliderVisual(rawVal)
            if not wrap._refreshing and stepped ~= lastCommitted then
                lastCommitted = stepped
                onChanged(stepped)
            end
        end)

        slider:SetScript("OnMouseDown", function(selfS, button)
            if button == "LeftButton" then
                CloseActiveDropdown()
                isDragging = true
                UpdateSliderFromCursor()
                selfS:SetScript("OnUpdate", UpdateSliderFromCursor)
            end
        end)
        slider:SetScript("OnMouseUp", function(selfS)
            isDragging = false
            selfS:SetScript("OnUpdate", nil)
            wrap:RefreshValue()
        end)
        slider:SetScript("OnHide", function(selfS)
            isDragging = false
            selfS:SetScript("OnUpdate", nil)
        end)
        slider:SetScript("OnMouseWheel", function(_, delta)
            CloseActiveDropdown()
            local cur = SnapValue(getValue())
            local newVal = SnapValue(cur + (delta > 0 and stepVal or -stepVal))
            if newVal ~= lastCommitted then
                lastCommitted = newVal
                onChanged(newVal)
            end
            wrap:RefreshValue()
        end)

        slider:SetScript("OnEnter", function(selfS)
            UpdateSliderVisual(slider:GetValue())
            if _G.GameTooltip then
                _G.GameTooltip:SetOwner(selfS, "ANCHOR_TOP")
                _G.GameTooltip:ClearLines()
                _G.GameTooltip:AddLine((card.title and card.title:GetText()) or "Slider", 1, 1, 1)
                _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click / Drag:", tooltipAction or "Adjust value.", "34D399"), 0.886, 0.910, 0.941)
                _G.GameTooltip:AddLine(FormatTooltipCmd("Mousewheel:", "Fine-tune by 1 step.", "38BDF8"), 0.886, 0.910, 0.941)
                _G.GameTooltip:Show()
            end
        end)
        slider:SetScript("OnLeave", function()
            UpdateSliderVisual(slider:GetValue())
            if _G.GameTooltip then _G.GameTooltip:Hide() end
        end)

        wrap:RefreshValue()
        card.toggleBtn = wrap
        return wrap
    end
end

local function GetActiveChatConflicts()
    local active = {}
    if not (_G.C_AddOns and type(_G.C_AddOns.IsAddOnLoaded) == "function") then
        return active
    end
    for _, entry in ipairs(DynamicChat.CONFLICT_REGISTRY or {}) do
        local isLoaded = _G.C_AddOns.IsAddOnLoaded(entry.addon)
        local isEnabled = (_G.C_AddOns.GetAddOnEnableState and (_G.C_AddOns.GetAddOnEnableState(entry.addon) or 0) > 0) or false
        if isLoaded or isEnabled then
            active[#active + 1] = entry.label or entry.addon
        end
    end
    return active
end

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
                        cardY = cardY - (card:GetHeight() or 60) - 6
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
    end
end

local function RenderChatEmbedded(arg1, arg2)
    local parent = (type(arg1) == "table" and type(arg1.GetObjectType) == "function") and arg1 or arg2
    if not parent or type(parent.GetObjectType) ~= "function" then return nil end

    EnsureDB()
    RegisterDynamicChatPopupClosers()
    parent:Show()

    if parent.DynamicChatContainer then
        local existing = parent.DynamicChatContainer
        existing:ClearAllPoints()
        existing:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        existing:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
        existing:Show()
        DynamicChat.embeddedRoot = existing
        DynamicChat:RefreshConfigUI()
        return existing
    end

    local root = CreateFrame("Frame", nil, parent)
    root:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    root:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    root:Show()
    root:SetScript("OnHide", function()
        CloseActiveDropdown()
    end)

    parent.DynamicChatContainer = root
    DynamicChat.embeddedRoot = root

    -- Top 3-Tab Segmented Bevel Bar (34px height at 14, -10 / -16, -10)
    local tabBar = CreateFrame("Frame", nil, root, "BackdropTemplate")
    tabBar:SetHeight(34)
    tabBar:SetPoint("TOPLEFT", root, "TOPLEFT", 14, -10)
    tabBar:SetPoint("TOPRIGHT", root, "TOPRIGHT", -16, -10)
    tabBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    tabBar:SetBackdropColor(0.043, 0.051, 0.071, 0.98) -- #0B0D12
    tabBar:SetBackdropBorderColor(1, 1, 1, 0.08)

    local tabDefs = {
        { id = 1, label = "Target Whisper & Input" },
        { id = 2, label = "Chat Look & Sidebar" },
        { id = 3, label = "Sound Alerts" },
        { id = 4, label = "Links, Scroll & History" },
    }

    root.tabButtons = {}
    root.tabPages = {}
    root.allControls = {}

    -- 2-Tier Inline Conflict Resolution Card (Shown at the top of DynamicChat when conflicts are detected; hidden when #conflicts == 0)
    local cScan = CreateFrame("Frame", nil, root, "BackdropTemplate")
    cScan:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -8)
    cScan:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", 0, -8)
    cScan:SetHeight(124)
    cScan:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    cScan:SetBackdropColor(0.035, 0.039, 0.051, 0.99)
    cScan:SetBackdropBorderColor(0.961, 0.722, 0.180, 0.85)
    cScan:Hide()
    root.conflictCard = cScan

    local csRescanBtn = CreateFrame("Button", nil, cScan, "BackdropTemplate")
    csRescanBtn:SetSize(116, 22)
    csRescanBtn:SetPoint("TOPRIGHT", cScan, "TOPRIGHT", -14, -10)
    csRescanBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    csRescanBtn:SetBackdropColor(0.078, 0.090, 0.122, 0.96)
    csRescanBtn:SetBackdropBorderColor(0.24, 0.28, 0.36, 0.95)
    csRescanBtn.txt = csRescanBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(csRescanBtn.txt, 10, "")
    csRescanBtn.txt:SetPoint("CENTER")
    csRescanBtn.txt:SetTextColor(0.92, 0.95, 0.99, 1.0)
    csRescanBtn.txt:SetText("Rescan Addons")
    csRescanBtn:SetScript("OnClick", function()
        DynamicChat:RefreshConfigUI()
    end)

    local csHdr = CreateSectionHeader(
        cScan,
        -10,
        "ACTIVE CHAT CONFLICT SCANNER & COMPATIBILITY",
        "Overlapping chat addons detected - choose which addon manages your chat, or share features automatically.",
        14
    )
    csHdr.title:SetPoint("RIGHT", csRescanBtn, "LEFT", -12, 0)
    root.sectionHeaders = root.sectionHeaders or {}
    root.sectionHeaders[#root.sectionHeaders + 1] = csHdr

    cScan.rows = {}
    for i = 1, 2 do
        local crow = CreateFrame("Frame", nil, cScan, "BackdropTemplate")
        crow:SetHeight(52)
        crow:SetPoint("TOPLEFT", cScan, "TOPLEFT", 14, -54 - (i - 1) * 56)
        crow:SetPoint("TOPRIGHT", cScan, "TOPRIGHT", -14, -54 - (i - 1) * 56)
        crow:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        crow:SetBackdropColor(0.055, 0.063, 0.082, 0.96)
        crow:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95)

        crow.actionBtn = CreateFrame("Button", nil, crow, "BackdropTemplate")
        crow.actionBtn:SetSize(i == 1 and 144 or 236, 26)
        crow.actionBtn:SetPoint("RIGHT", crow, "RIGHT", -10, 0)
        crow.actionBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        crow.actionBtn.txt = crow.actionBtn:CreateFontString(nil, "OVERLAY")
        SetSafeFont(crow.actionBtn.txt, 10.5, "")
        crow.actionBtn.txt:SetPoint("CENTER")
        crow.actionBtn.txt:SetTextColor(1, 1, 1, 1)

        if i == 1 then
            crow.secondaryBtn = CreateFrame("Button", nil, crow, "BackdropTemplate")
            crow.secondaryBtn:SetSize(148, 26)
            crow.secondaryBtn:SetPoint("RIGHT", crow.actionBtn, "LEFT", -8, 0)
            crow.secondaryBtn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            crow.secondaryBtn:SetBackdropColor(0.078, 0.090, 0.122, 0.96)
            crow.secondaryBtn:SetBackdropBorderColor(0.24, 0.28, 0.36, 0.95)
            crow.secondaryBtn.txt = crow.secondaryBtn:CreateFontString(nil, "OVERLAY")
            SetSafeFont(crow.secondaryBtn.txt, 10.5, "")
            crow.secondaryBtn.txt:SetPoint("CENTER")
            crow.secondaryBtn.txt:SetTextColor(0.88, 0.92, 0.96, 1)
        end

        crow.title = crow:CreateFontString(nil, "OVERLAY")
        SetSafeFont(crow.title, 11, "")
        crow.title:SetPoint("TOPLEFT", crow, "TOPLEFT", 12, -9)
        crow.title:SetJustifyH("LEFT")
        crow.title:SetWordWrap(false)

        crow.desc = crow:CreateFontString(nil, "OVERLAY")
        SetSafeFont(crow.desc, 10, "")
        crow.desc:SetPoint("TOPLEFT", crow.title, "BOTTOMLEFT", 0, -3)
        crow.desc:SetPoint("RIGHT", crow.secondaryBtn or crow.actionBtn, "LEFT", -12, 0)
        crow.desc:SetJustifyH("LEFT")
        crow.desc:SetWordWrap(false)

        crow:Hide()
        cScan.rows[i] = crow
    end

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
        page:SetHeight(420)
        page.orderedCards = {}
        page:Hide()
        root.tabPages[idx] = page

        tBtn:SetScript("OnClick", function()
            CloseActiveDropdown()
            EnsureDB().activeSubTab = idx
            DynamicChat:RefreshConfigUI()
        end)

        root.tabButtons[idx] = tBtn
    end

    local function ReflowChatTabBar()
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
        local nTabs = math.max(1, #root.tabButtons)
        local totalGap = 4 * (nTabs + 1)
        local eachW = math.floor((w - totalGap) / nTabs)
        for i, b in ipairs(root.tabButtons) do
            b:ClearAllPoints()
            b:SetHeight(26)
            if i == 1 then
                b:SetPoint("LEFT", tabBar, "LEFT", 4, 0)
                b:SetWidth(eachW)
            elseif i < nTabs then
                b:SetPoint("LEFT", root.tabButtons[i - 1], "RIGHT", 4, 0)
                b:SetWidth(eachW)
            else
                b:SetPoint("LEFT", root.tabButtons[i - 1], "RIGHT", 4, 0)
                b:SetPoint("RIGHT", tabBar, "RIGHT", -4, 0)
            end
        end
    end
    tabBar:SetScript("OnSizeChanged", ReflowChatTabBar)
    tabBar:HookScript("OnShow", function() C_Timer.After(0, ReflowChatTabBar) end)
    root.ReflowChatTabBar = ReflowChatTabBar
    C_Timer.After(0, ReflowChatTabBar)

    -- ========================================================================
    -- TAB 1: Target Whisper (/ww) & Input
    -- ========================================================================
    local page1 = root.tabPages[1]
    local sec1a = CreateSectionBox(
        page1,
        "INSTANT TARGET WHISPER (/WW) & BOSS FIGHT PROTECTION",
        "Quickly whisper your current friendly target by typing /ww, and keep whispers visible during boss fights.",
        root
    )
    local sec1b = CreateSectionBox(
        page1,
        "MESSAGE HISTORY ARROWS & CHANNEL MEMORY",
        "Use the Up and Down arrow keys to repeat messages and choose which chat channels stay selected.",
        root
    )

    local c1_tt = CreateCardRow(sec1a, 60,
        "Instant Target Whisper (/ww)",
        "Type '/ww ' in chat to immediately whisper the friendly player you are targeting, or use '/ww <message>' in macros.",
        "Instant Target Whisper (/ww)",
        "Turn on instant '/ww' target whispers in the chat box and macros."
    )
    AttachSegmentedSwitchToCard(c1_tt,
        function() return EnsureDB().enableTargetWhisper end,
        function(val)
            EnsureDB().enableTargetWhisper = val
            DynamicChat:ReassertTargetWhisperSlashCommands()
            RefreshSleekEditBoxBarColor(_G.ChatFrame1EditBox)
        end,
        "Off", "Enabled",
        "Toggle Instant Target Whisper (/ww)."
    )
    sec1a.orderedCards[#sec1a.orderedCards + 1] = c1_tt
    root.allControls[#root.allControls + 1] = c1_tt

    local c1_clear = CreateCardRow(sec1a, 60,
        "Clear '/ww' If You Have No Friendly Target",
        "Automatically clears '/ww ' from your chat box and shows a helpful reminder if you aren't targeting a friendly player.",
        "Clear '/ww' Without Friendly Target",
        "Clear '/ww ' automatically when you do not have a friendly player targeted."
    )
    AttachSegmentedSwitchToCard(c1_clear,
        function() return EnsureDB().targetWhisperClearOnInvalid ~= false end,
        function(val)
            EnsureDB().targetWhisperClearOnInvalid = val
        end,
        "Off", "Enabled",
        "Toggle clearing '/ww ' when no friendly player is targeted."
    )
    sec1a.orderedCards[#sec1a.orderedCards + 1] = c1_clear
    root.allControls[#root.allControls + 1] = c1_clear

    local c1_protect = CreateCardRow(sec1a, 62,
        "Protect Whispers During Boss Fights & Mythic+",
        "Permanently isolates Whisper and Battle.net channels from message filters so secret combat strings never block incoming whispers.",
        "Protect Whispers in Boss Fights & M+",
        "Keep incoming whispers and Battle.net messages reliable during boss fights and Mythic+ keys."
    )
    AttachReadOnlyStatusBadgeToCard(c1_protect,
        "Always Protected",
        "Always active: DynamicChat leaves Whisper and Battle.net messages untouched so combat messages never cause errors."
    )
    sec1a.orderedCards[#sec1a.orderedCards + 1] = c1_protect
    root.allControls[#root.allControls + 1] = c1_protect

    local c1_arrow = CreateCardRow(sec1b, 60,
        "Use Up & Down Arrows to Repeat Sent Messages",
        "Press the Up and Down arrow keys while typing in chat to cycle through your recently sent messages without holding Alt.",
        "Up & Down Arrow Message History",
        "Cycle through your previously sent chat messages using the Up and Down arrow keys."
    )
    AttachSegmentedSwitchToCard(c1_arrow,
        function() return EnsureDB().arrowHistoryNoAlt end,
        function(val)
            EnsureDB().arrowHistoryNoAlt = val
            DynamicChat:ApplyEditBoxSettings()
        end,
        "Off", "Enabled",
        "Toggle Up and Down arrow history in the chat input box."
    )
    sec1b.orderedCards[#sec1b.orderedCards + 1] = c1_arrow
    root.allControls[#root.allControls + 1] = c1_arrow

    local c1_stickyW = CreateCardRow(sec1b, 60,
        "Remember Whisper Channel After Sending",
        "When set to 'Reset to Previous' (Recommended), pressing Enter after sending a whisper returns your chat box to Party, Raid, or Guild chat.",
        "Remember Whisper Channel",
        "Choose whether your chat box stays locked on Whisper or returns to your previous group channel after sending."
    )
    AttachSegmentedSwitchToCard(c1_stickyW,
        function() return EnsureDB().stickyWhisper == true end,
        function(val)
            EnsureDB().stickyWhisper = val
            DynamicChat:ApplyStickyChannelSettings()
        end,
        "Reset to Previous", "Keep Sticky",
        "Choose whether Whisper resets to your previous channel or stays sticky."
    )
    sec1b.orderedCards[#sec1b.orderedCards + 1] = c1_stickyW
    root.allControls[#root.allControls + 1] = c1_stickyW

    local c1_stickyG = CreateCardRow(sec1b, 60,
        "Remember Party, Raid, Instance & Guild Channels",
        "Keeps your chat box on your current group or guild channel after you send a message.",
        "Remember Group & Guild Channels",
        "Keep Party, Raid, Instance, Guild, and Officer channels selected between messages."
    )
    AttachSegmentedSwitchToCard(c1_stickyG,
        function() return EnsureDB().stickyGroupChannels ~= false end,
        function(val)
            EnsureDB().stickyGroupChannels = val
            DynamicChat:ApplyStickyChannelSettings()
        end,
        "Off", "Enabled",
        "Toggle keeping Party, Raid, Instance, and Guild channels selected."
    )
    sec1b.orderedCards[#sec1b.orderedCards + 1] = c1_stickyG
    root.allControls[#root.allControls + 1] = c1_stickyG

    -- ========================================================================
    -- TAB 2: Chat Look, Sidebar & Formatting
    -- ========================================================================
    local page2 = root.tabPages[2]
    local sec2_skin = CreateSectionBox(
        page2,
        "SMOKED-GLASS CHAT WINDOW & LEFT SHORTCUT BAR",
        "Customise the smoked-glass chat frame, top tab bar, font, and left-hand shortcut buttons.",
        root
    )
    local chatEditHudBtn
    if _G.DynamicSuite and type(_G.DynamicSuite.CreateEditHudButton) == "function" then
        chatEditHudBtn = _G.DynamicSuite.CreateEditHudButton(sec2_skin, "CHAT")
    else
        chatEditHudBtn = CreateFrame("Button", nil, sec2_skin, "BackdropTemplate")
        chatEditHudBtn:SetSize(86, 22)
        chatEditHudBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        local ar0, ag0, ab0 = GetSuiteAccent()
        chatEditHudBtn:SetBackdropColor(0.043, 0.051, 0.071, 0.96)
        chatEditHudBtn:SetBackdropBorderColor(ar0, ag0, ab0, 0.85)
        chatEditHudBtn.label = chatEditHudBtn:CreateFontString(nil, "OVERLAY")
        SetSafeFont(chatEditHudBtn.label, 11, "")
        chatEditHudBtn.label:SetPoint("CENTER", 0, 0)
        chatEditHudBtn.label:SetText("Edit HUD")
        chatEditHudBtn.label:SetTextColor(0.976, 0.984, 1.00, 1)
        chatEditHudBtn:SetScript("OnEnter", function(s)
            local ar, ag, ab = GetSuiteAccent()
            s:SetBackdropColor(ar * 0.22, ag * 0.22, ab * 0.22, 0.98)
            s:SetBackdropBorderColor(ar, ag, ab, 1.0)
        end)
        chatEditHudBtn:SetScript("OnLeave", function(s)
            local ar, ag, ab = GetSuiteAccent()
            s:SetBackdropColor(0.043, 0.051, 0.071, 0.96)
            s:SetBackdropBorderColor(ar, ag, ab, 0.85)
        end)
        chatEditHudBtn:SetScript("OnClick", function()
            if _G.DynamicSuite and type(_G.DynamicSuite.EnterHudEditMode) == "function" then
                _G.DynamicSuite.EnterHudEditMode("CHAT")
            end
        end)
    end
    chatEditHudBtn:SetPoint("TOPRIGHT", sec2_skin, "TOPRIGHT", -14, -7)
    if sec2_skin.hdr then
        if sec2_skin.hdr.title then
            sec2_skin.hdr.title:SetPoint("RIGHT", chatEditHudBtn, "LEFT", -10, 0)
            sec2_skin.hdr.title:SetWordWrap(false)
        end
        if sec2_skin.hdr.subtitle then
            sec2_skin.hdr.subtitle:SetPoint("RIGHT", chatEditHudBtn, "LEFT", -10, 0)
        end
    end
    local sec2_typo = CreateSectionBox(
        page2,
        "CHAT TYPOGRAPHY & READABILITY",
        "Customise the font family, text size, outline, drop shadow, line spacing, and message fading across all chat windows.",
        root
    )
    local sec2a = CreateSectionBox(
        page2,
        "COMPACT CHANNEL TAGS",
        "Keep channel names clean and readable across Party, Raid, Instance, and Guild chat.",
        root
    )
    local sec2b = CreateSectionBox(
        page2,
        "CLASS COLOURS & MESSAGE TIMESTAMPS",
        "Colour player names by their class and show the time each message was received.",
        root
    )

    local c2_skin = CreateCardRow(sec2_skin, 62,
        "Smoked-Glass Chat Window & Top Tab Bar",
        "Gives your chat window a clean smoked-glass background, sleek top tabs, and a left shortcut bar.",
        "Smoked-Glass Chat Window & Top Tab Bar",
        "Toggle DynamicChat's smoked-glass chat window, Top Tab Bar, Left Shortcut Bar, and input box style."
    )
    AttachSegmentedSwitchToCard(c2_skin,
        function() return EnsureDB().enableSleekChatSkin ~= false end,
        function(val)
            EnsureDB().enableSleekChatSkin = val
            DynamicChat:ApplySavedChatFramePosition()
            DynamicChat:ApplySleekChatSkin()
        end,
        "Off", "Enabled",
        "Toggle Smoked-Glass Chat Window & Top Tab Bar."
    )
    sec2_skin.orderedCards[#sec2_skin.orderedCards + 1] = c2_skin
    root.allControls[#root.allControls + 1] = c2_skin

    local c2_alpha = CreateCardRow(sec2_skin, 62,
        "Chat Window Background Opacity",
        "Choose how transparent or solid the chat window background looks (Smoked 25% is default).",
        "Chat Window Background Opacity",
        "Select the background opacity of your chat window."
    )
    AttachMultiPillSelectorToCard(c2_alpha,
        {
            { value = 0.00, label = "Clear 0%" },
            { value = 0.25, label = "Smoked 25%" },
            { value = 0.72, label = "Obsidian 72%" },
            { value = 0.92, label = "Solid 92%" },
        },
        function()
            local a = tonumber(EnsureDB().chatBgAlpha) or 0.25
            if a <= 0.10 then return 0.00 end
            if a <= 0.55 then return 0.25 end
            if a <= 0.82 then return 0.72 end
            return 0.92
        end,
        function(val)
            EnsureDB().chatBgAlpha = tonumber(val) or 0.25
            EnsureDB().enableSleekChatSkin = true
            DynamicChat:ApplySleekChatSkin()
            if c2_skin.toggleBtn and c2_skin.toggleBtn.RefreshValue then
                c2_skin.toggleBtn:RefreshValue()
            end
        end,
        "Select chat window background opacity."
    )
    sec2_skin.orderedCards[#sec2_skin.orderedCards + 1] = c2_alpha
    root.allControls[#root.allControls + 1] = c2_alpha

    local c2_ebPos = CreateCardRow(sec2_skin, 62,
        "Chat Typing Box Position",
        "Dock the chat typing box flush along the bottom of your chat window or above the top tab bar.",
        "Chat Typing Box Position",
        "Choose whether the chat typing box is docked below the chat window or above the top tab bar."
    )
    AttachMultiPillSelectorToCard(c2_ebPos,
        {
            { value = "BOTTOM", label = "Bottom (Below Chat)" },
            { value = "TOP",    label = "Top (Above Tabs)" },
        },
        function() return (EnsureDB().editBoxPosition == "TOP") and "TOP" or "BOTTOM" end,
        function(val)
            local chosen = (val == "TOP") and "TOP" or "BOTTOM"
            EnsureDB().editBoxPosition = chosen
            if type(_G.DynamicSuiteDB) == "table" then
                _G.DynamicSuiteDB.chatEditBoxPosition = chosen
            end
            DynamicChat:ApplySavedChatFramePosition()
            DynamicChat:ApplySleekChatSkin()
        end,
        "Select chat typing box position (Bottom or Top)."
    )
    sec2_skin.orderedCards[#sec2_skin.orderedCards + 1] = c2_ebPos
    root.allControls[#root.allControls + 1] = c2_ebPos

    local c2_ebBgMode = CreateCardRow(sec2_skin, 62,
        "Chat Typing Box Shading",
        "Keep the typing box shaded to match your smoked-glass chat window so the frame never looks like it is floating, or only show it while typing.",
        "Chat Typing Box Shading",
        "Choose whether the typing box dock stays shaded at all times or only appears while typing."
    )
    AttachMultiPillSelectorToCard(c2_ebBgMode,
        {
            { value = "FOCUS_ONLY", label = "When Typing Only" },
            { value = "ALWAYS",     label = "Always Shaded" },
        },
        function() return (EnsureDB().editBoxBackgroundMode == "FOCUS_ONLY") and "FOCUS_ONLY" or "ALWAYS" end,
        function(val)
            EnsureDB().editBoxBackgroundMode = (val == "FOCUS_ONLY") and "FOCUS_ONLY" or "ALWAYS"
            DynamicChat:ApplySavedChatFramePosition()
            DynamicChat:ApplySleekChatSkin()
        end,
        "Select chat typing box shading mode."
    )
    sec2_skin.orderedCards[#sec2_skin.orderedCards + 1] = c2_ebBgMode
    root.allControls[#root.allControls + 1] = c2_ebBgMode

    local c2_btns = CreateCardRow(sec2_skin, 60,
        "Hide Default Blizzard Side Buttons",
        "Hides Blizzard's bulky default Voice, Channel, and Social buttons next to the chat frame so they never block your Left Shortcut Bar.",
        "Hide Default Blizzard Side Buttons",
        "Hide default Blizzard side buttons so they never overlap the Left Shortcut Bar."
    )
    AttachSegmentedSwitchToCard(c2_btns,
        function() return EnsureDB().hideChatButtons ~= false end,
        function(val)
            EnsureDB().hideChatButtons = val
            DynamicChat:ApplySavedChatFramePosition()
            DynamicChat:ApplySleekChatSkin()
        end,
        "Off", "Enabled",
        "Toggle hiding default Blizzard side buttons."
    )
    sec2_skin.orderedCards[#sec2_skin.orderedCards + 1] = c2_btns
    root.allControls[#root.allControls + 1] = c2_btns

    local c2_font = CreateCardRow(sec2_skin, 60,
        "Match Chat Font with DynamicSuite",
        "Uses your chosen DynamicSuite font for chat tabs and the typing box while keeping your current chat text size.",
        "Match Chat Font with DynamicSuite",
        "Sync chat tabs and input text with your selected DynamicSuite font."
    )
    AttachSegmentedSwitchToCard(c2_font,
        function() return EnsureDB().applySuiteChatFont ~= false end,
        function(val)
            EnsureDB().applySuiteChatFont = val
            DynamicChat:ApplySleekChatSkin()
        end,
        "Off", "Enabled",
        "Toggle matching chat font with DynamicSuite."
    )
    sec2_skin.orderedCards[#sec2_skin.orderedCards + 1] = c2_font
    root.allControls[#root.allControls + 1] = c2_font

    local c2_railMode = CreateCardRow(sec2_skin, 62,
        "Left Shortcut Bar Visibility",
        "Choose when the left-hand shortcut bar is visible next to your chat window (or Right-Click the Cog icon on the chat bar).",
        "Left Shortcut Bar Visibility",
        "Select whether the Left Shortcut Bar is Always shown, shown on Mouseover, hidden in Combat, or Off."
    )
    AttachMultiPillSelectorToCard(c2_railMode,
        {
            { value = "OFF",         label = "Off" },
            { value = "COMBAT_HIDE", label = "Combat Hide" },
            { value = "HOVER",       label = "Mouseover" },
            { value = "ALWAYS",      label = "Always" },
        },
        function() return EnsureDB().leftRailMode or "ALWAYS" end,
        function(val)
            EnsureDB().leftRailMode = val
            DynamicChat:ApplySavedChatFramePosition()
            DynamicChat:ApplySleekChatSkin()
        end,
        "Select Left Shortcut Bar visibility mode."
    )
    sec2_skin.orderedCards[#sec2_skin.orderedCards + 1] = c2_railMode
    root.allControls[#root.allControls + 1] = c2_railMode

    local c2_railChips = CreateCardRow(sec2_skin, 86,
        "Left Shortcut Bar Buttons",
        "Click any button below to show or hide it on the left side of your chat window.",
        "Left Shortcut Bar Buttons",
        "Choose which shortcut icons appear on the Left Shortcut Bar."
    )
    do
        local chipHolder = CreateFrame("Frame", nil, c2_railChips)
        chipHolder:SetSize(386, 52)
        chipHolder:SetPoint("RIGHT", c2_railChips, "RIGHT", -14, 0)
        AnchorCardTextToRightWidget(c2_railChips, chipHolder)

        chipHolder.chips = {}
        for idx, def in ipairs(RAIL_WIDGET_DEFS) do
            local colIdx = (idx - 1) % 4
            local rowIdx = math.floor((idx - 1) / 4)
            local cb = CreateFrame("Button", nil, chipHolder, "BackdropTemplate")
            cb:SetSize(93, 24)
            cb:SetPoint("TOPLEFT", chipHolder, "TOPLEFT", colIdx * 97, -rowIdx * 28)
            cb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            cb.widgetKey = def.key

            local ic = cb:CreateTexture(nil, "ARTWORK")
            ic:SetSize(11, 11)
            ic:SetPoint("LEFT", cb, "LEFT", 6, 0)
            ic:SetTexture(def.icon)
            DisableTexPixelSnap(ic)
            cb.icon = ic

            local lbl = cb:CreateFontString(nil, "OVERLAY")
            SetSafeFont(lbl, 9.5, "")
            lbl:SetPoint("LEFT", ic, "RIGHT", 5, 0)
            lbl:SetPoint("RIGHT", cb, "RIGHT", -4, 0)
            lbl:SetJustifyH("LEFT")
            lbl:SetWordWrap(false)
            lbl:SetText(def.shortLabel)
            cb.label = lbl

            cb:SetScript("OnEnter", function(selfBtn)
                if not _G.GameTooltip then return end
                _G.GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
                _G.GameTooltip:ClearLines()
                _G.GameTooltip:AddLine(def.label, 1, 1, 1)
                _G.GameTooltip:AddLine(FormatTooltipCmd("Left-Click:", "Show or hide " .. def.label .. " on the Left Shortcut Bar.", "34D399"), 0.886, 0.910, 0.941)
                _G.GameTooltip:Show()
            end)
            cb:SetScript("OnLeave", function()
                if _G.GameTooltip then _G.GameTooltip:Hide() end
            end)
            cb:SetScript("OnClick", function()
                local db = EnsureDB()
                db.railButtons = db.railButtons or {}
                db.railButtons[def.key] = (db.railButtons[def.key] == false) and true or false
                DynamicChat:RefreshLeftRailTelemetry()
                chipHolder:RefreshValue()
            end)
            chipHolder.chips[idx] = cb
        end

        function chipHolder:RefreshValue()
            local db = EnsureDB()
            local rb = db.railButtons or DEFAULTS.railButtons
            local ar, ag, ab = GetSuiteAccent()
            local fillAlpha = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42
            for _, cb in ipairs(self.chips) do
                SetSafeFont(cb.label, 9.5, "")
                local on = (rb[cb.widgetKey] ~= false)
                if on then
                    cb:SetBackdropColor(ar * fillAlpha, ag * fillAlpha, ab * fillAlpha, 0.96)
                    cb:SetBackdropBorderColor(ar, ag, ab, 0.95)
                    cb.icon:SetVertexColor(1, 1, 1, 1.0)
                    cb.label:SetTextColor(0.98, 0.99, 1.00, 1.0)
                else
                    cb:SetBackdropColor(0.065, 0.075, 0.098, 0.92)
                    cb:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.85)
                    cb.icon:SetVertexColor(0.45, 0.50, 0.58, 0.75)
                    cb.label:SetTextColor(0.55, 0.60, 0.68, 0.90)
                end
            end
        end

        chipHolder:RefreshValue()
        c2_railChips.toggleBtn = chipHolder
        DynamicChat.railChipGrid = chipHolder
    end
    sec2_skin.orderedCards[#sec2_skin.orderedCards + 1] = c2_railChips
    root.allControls[#root.allControls + 1] = c2_railChips

    do
        local c2_typoFont = CreateCardRow(sec2_typo, 62,
            "Chat Font Family",
            "Choose your chat message font or follow your active DynamicSuite Theme & Font Studio selection.",
            "Chat Font Family",
            "Select the font family used across ChatFrame1..10 and the typing box."
        )
        TypographyMgr.AttachFontDropdownToCard(c2_typoFont)
        sec2_typo.orderedCards[#sec2_typo.orderedCards + 1] = c2_typoFont
        root.allControls[#root.allControls + 1] = c2_typoFont

        local c2_typoSize = CreateCardRow(sec2_typo, 60,
            "Chat Font Size",
            "Adjust chat message text size from 10 px to 22 px across all chat windows.",
            "Chat Font Size",
            "Drag to set chat message font size (10 px to 22 px)."
        )
        TypographyMgr.AttachSliderToCard(c2_typoSize, 10, 22, 1, " px",
            function() return tonumber(EnsureDB().chatFontSize) or 13 end,
            function(val)
                EnsureDB().chatFontSize = val
                DynamicChat:ApplyChatFrameTypography()
            end,
            "Adjust chat font size between 10 px and 22 px."
        )
        sec2_typo.orderedCards[#sec2_typo.orderedCards + 1] = c2_typoSize
        root.allControls[#root.allControls + 1] = c2_typoSize

        local c2_typoOutline = CreateCardRow(sec2_typo, 62,
            "Font Outline",
            "Add a crisp dark outline around chat text so messages stay readable over bright spell effects.",
            "Font Outline",
            "Choose None, Thin Outline, or Thick Outline for chat text."
        )
        AttachMultiPillSelectorToCard(c2_typoOutline,
            {
                { value = "NONE",         label = "None" },
                { value = "OUTLINE",      label = "Thin Outline" },
                { value = "THICKOUTLINE", label = "Thick Outline" },
            },
            function() return EnsureDB().chatFontOutline or "OUTLINE" end,
            function(val)
                EnsureDB().chatFontOutline = val
                DynamicChat:ApplyChatFrameTypography()
            end,
            "Select chat text outline thickness."
        )
        sec2_typo.orderedCards[#sec2_typo.orderedCards + 1] = c2_typoOutline
        root.allControls[#root.allControls + 1] = c2_typoOutline

        local c2_typoShadow = CreateCardRow(sec2_typo, 60,
            "Text Drop Shadow",
            "Render a subtle (1, -1) dark drop shadow behind chat letters for extra contrast.",
            "Text Drop Shadow",
            "Toggle crisp drop shadows behind chat text."
        )
        AttachSegmentedSwitchToCard(c2_typoShadow,
            function() return EnsureDB().chatFontShadow ~= false end,
            function(val)
                EnsureDB().chatFontShadow = val
                DynamicChat:ApplyChatFrameTypography()
            end,
            "Off", "Enabled",
            "Toggle chat text drop shadow."
        )
        sec2_typo.orderedCards[#sec2_typo.orderedCards + 1] = c2_typoShadow
        root.allControls[#root.allControls + 1] = c2_typoShadow

        local c2_typoSpacing = CreateCardRow(sec2_typo, 60,
            "Line Spacing",
            "Add vertical breathing room between chat lines (0 px compact to 8 px airy).",
            "Line Spacing",
            "Drag to adjust vertical spacing between chat lines (0 px to 8 px)."
        )
        TypographyMgr.AttachSliderToCard(c2_typoSpacing, 0, 8, 1, " px",
            function() return tonumber(EnsureDB().chatLineSpacing) or 2 end,
            function(val)
                EnsureDB().chatLineSpacing = val
                DynamicChat:ApplyChatFrameTypography()
            end,
            "Adjust line spacing between 0 px and 8 px."
        )
        sec2_typo.orderedCards[#sec2_typo.orderedCards + 1] = c2_typoSpacing
        root.allControls[#root.allControls + 1] = c2_typoSpacing

        local c2_typoFade = CreateCardRow(sec2_typo, 60,
            "Auto-Fade Old Messages",
            "Smoothly fade out older chat messages after 2 minutes, or keep them visible permanently.",
            "Auto-Fade Old Messages",
            "Toggle whether older chat lines fade out after 2 minutes."
        )
        AttachSegmentedSwitchToCard(c2_typoFade,
            function() return EnsureDB().chatMessageFade ~= false end,
            function(val)
                EnsureDB().chatMessageFade = val
                DynamicChat:ApplyChatFrameTypography()
            end,
            "Off", "Enabled",
            "Toggle automatic fading of old chat messages."
        )
        sec2_typo.orderedCards[#sec2_typo.orderedCards + 1] = c2_typoFade
        root.allControls[#root.allControls + 1] = c2_typoFade
    end

    local c2_short = CreateCardRow(sec2a, 64,
        "Safe Channel Names in Raids & Mythic+",
        "Keeps Blizzard's built-in channel labels intact so Raid and Mythic+ chat messages never cause UI errors.",
        "Safe Channel Names in Raids & Mythic+",
        "Keep channel names protected against combat chat errors in Raids and Mythic+ dungeons."
    )
    AttachReadOnlyStatusBadgeToCard(c2_short,
        "Always Protected",
        "Always active: DynamicChat preserves Blizzard's default channel labels so protected raid messages stay error-free."
    )
    sec2a.orderedCards[#sec2a.orderedCards + 1] = c2_short
    root.allControls[#root.allControls + 1] = c2_short

    local c2_class = CreateCardRow(sec2b, 60,
        "Show Player Class Colours in Chat",
        "Automatically colours player names in chat to match their class (Druid orange, Mage blue, Paladin pink, etc.).",
        "Show Player Class Colours",
        "Automatically colour player names by their class in all chat channels."
    )
    AttachSegmentedSwitchToCard(c2_class,
        function() return EnsureDB().classColorNames ~= false end,
        function(val)
            EnsureDB().classColorNames = val
            DynamicChat:ApplyClassColorNames()
        end,
        "Off", "Enabled",
        "Toggle class-coloured player names in chat."
    )
    sec2b.orderedCards[#sec2b.orderedCards + 1] = c2_class
    root.allControls[#root.allControls + 1] = c2_class

    local c2_ts = CreateCardRow(sec2b, 62,
        "Chat Message Timestamps",
        "Adds the time each message was received (such as 01:32) to the start of every chat line.",
        "Chat Message Timestamps",
        "Choose the time format shown in front of chat messages."
    )
    AttachMultiPillSelectorToCard(c2_ts,
        {
            { value = "none",      label = "Off" },
            { value = "%H:%M ",    label = "24h (01:32)" },
            { value = "%I:%M %p ", label = "12h (01:32 PM)" },
            { value = "%H:%M:%S ", label = "HH:MM:SS" },
        },
        function()
            local db = EnsureDB()
            if db.showTimestamps == false or db.timestampFormat == "none" then
                return "none"
            end
            return db.timestampFormat or "%H:%M "
        end,
        function(val)
            local db = EnsureDB()
            if val == "none" then
                db.showTimestamps = false
                db.timestampFormat = "none"
            else
                db.showTimestamps = true
                db.timestampFormat = val
            end
            DynamicChat:ApplyTimestampSettings()
        end,
        "Select chat message timestamp format."
    )
    sec2b.orderedCards[#sec2b.orderedCards + 1] = c2_ts
    root.allControls[#root.allControls + 1] = c2_ts

    -- ========================================================================
    -- TAB 3: Sound Alerts (Chat Notification Sounds + Per-Channel Config)
    -- ========================================================================
    local page3 = root.tabPages[3]
    local sec3_sounds = CreateSectionBox(
        page3,
        "CHAT NOTIFICATION SOUNDS",
        "Per-channel chat notification alerts with Blizzard built-in sounds, SharedMedia/DBM/EXBOSS/BigWigs/WeakAuras support, and anti-spam cooldowns. Selecting a sound previews it automatically, or click [Play].",
        root
    )
    local sec3_rules = CreateSectionBox(
        page3,
        "AUDIO OUTPUT & ANTI-SPAM",
        "Choose which World of Warcraft audio volume slider controls chat chimes and set the per-channel anti-spam cooldown.",
        root
    )

    local c3_sndMaster = CreateCardRow(sec3_sounds, 60,
        "Chat Notification Sounds",
        "Master switch for per-channel incoming chat sound effects (automatically ignores outgoing messages sent by you).",
        "Chat Notification Sounds",
        "Turn custom per-channel chat notification sounds On or Off."
    )
    AttachSegmentedSwitchToCard(c3_sndMaster,
        function() return EnsureDB().enableChatSounds ~= false end,
        function(val)
            local db = EnsureDB()
            db.enableChatSounds = val
            db.enableSoundAlerts = val
            DynamicChat:ApplyWhisperDefaultSoundMuteState()
            DynamicChat:RefreshConfigUI()
        end,
        "Off", "Enabled",
        "Toggle Custom Chat Notification Sounds."
    )
    sec3_sounds.orderedCards[#sec3_sounds.orderedCards + 1] = c3_sndMaster
    root.allControls[#root.allControls + 1] = c3_sndMaster

    local c3_sndCombatMute = CreateCardRow(sec3_sounds, 60,
        "Mute Sounds in Combat",
        "Silence incoming chat notification sounds during combat lockdown and active raid or dungeon boss encounters.",
        "Mute Sounds in Combat",
        "Silence incoming chat notification chimes while in combat or a boss encounter."
    )
    AttachSegmentedSwitchToCard(c3_sndCombatMute,
        function() return EnsureDB().soundMuteInCombat == true end,
        function(val)
            EnsureDB().soundMuteInCombat = (val == true)
        end,
        "Off", "Enabled",
        "Toggle muting chat notification sounds during combat."
    )
    sec3_sounds.orderedCards[#sec3_sounds.orderedCards + 1] = c3_sndCombatMute
    root.allControls[#root.allControls + 1] = c3_sndCombatMute

    for _, chDef in ipairs(SOUND_CHANNEL_DEFS) do
        local cRow = CreateCardRow(sec3_sounds, 60,
            chDef.title,
            chDef.desc,
            chDef.title,
            "Select a sound effect for " .. chDef.title .. " (auto-previews on selection, or click [Play] beside the dropdown)."
        )
        AttachSoundDropdownToCard(cRow, chDef.key)
        sec3_sounds.orderedCards[#sec3_sounds.orderedCards + 1] = cRow
        root.allControls[#root.allControls + 1] = cRow
    end

    local c3_sndOut = CreateCardRow(sec3_rules, 62,
        "Audio Output Channel",
        "Choose which World of Warcraft volume slider controls your chat notification chimes (Master plays even if sound effects are lowered).",
        "Audio Output Channel",
        "Select the audio output channel for chat notification sounds."
    )
    AttachMultiPillSelectorToCard(c3_sndOut,
        {
            { value = "Master", label = "Master" },
            { value = "SFX",    label = "SFX" },
            { value = "Dialog", label = "Dialogue" },
        },
        function()
            local ch = EnsureDB().soundOutputChannel or "Master"
            if ch ~= "Master" and ch ~= "SFX" and ch ~= "Dialog" then return "Master" end
            return ch
        end,
        function(val)
            EnsureDB().soundOutputChannel = val
        end,
        "Select audio output channel (Master, SFX, or Dialogue)."
    )
    sec3_rules.orderedCards[#sec3_rules.orderedCards + 1] = c3_sndOut
    root.allControls[#root.allControls + 1] = c3_sndOut

    local c3_sndCooldown = CreateCardRow(sec3_rules, 62,
        "Anti-Spam Cooldown",
        "Prevents rapid-fire messages in the same chat channel from playing chimes repeatedly within a short window.",
        "Anti-Spam Cooldown",
        "Select the minimum cooldown between notification chimes on the same chat channel."
    )
    AttachMultiPillSelectorToCard(c3_sndCooldown,
        {
            { value = 0,   label = "Off" },
            { value = 1.5, label = "1.5s" },
            { value = 3,   label = "3s" },
            { value = 5,   label = "5s" },
        },
        function()
            local t = tonumber(EnsureDB().soundThrottleSec)
            if t == nil then return 1.5 end
            if t <= 0.1 then return 0 end
            if t <= 2.0 then return 1.5 end
            if t <= 4.0 then return 3 end
            return 5
        end,
        function(val)
            EnsureDB().soundThrottleSec = tonumber(val) or 0
        end,
        "Select per-channel anti-spam cooldown."
    )
    sec3_rules.orderedCards[#sec3_rules.orderedCards + 1] = c3_sndCooldown
    root.allControls[#root.allControls + 1] = c3_sndCooldown

    local function CreateObsidianEditBox(parent, width, height, placeholder)
        local boxWrap = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        boxWrap:SetSize(width, height or 24)
        boxWrap:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        boxWrap:SetBackdropColor(0.043, 0.051, 0.071, 0.98) -- #0B0D12
        boxWrap:SetBackdropBorderColor(0.20, 0.24, 0.30, 0.95)

        local eb = CreateFrame("EditBox", nil, boxWrap)
        eb:SetPoint("LEFT", boxWrap, "LEFT", 8, 0)
        eb:SetPoint("RIGHT", boxWrap, "RIGHT", -8, 0)
        eb:SetHeight((height or 24) - 4)
        eb:SetAutoFocus(false)
        SetSafeFont(eb, 10.5, "")
        eb:SetTextColor(0.976, 0.984, 1.00, 1)

        local ph = boxWrap:CreateFontString(nil, "OVERLAY")
        SetSafeFont(ph, 10, "")
        ph:SetPoint("LEFT", boxWrap, "LEFT", 8, 0)
        ph:SetPoint("RIGHT", boxWrap, "RIGHT", -8, 0)
        ph:SetJustifyH("LEFT")
        ph:SetWordWrap(false)
        ph:SetTextColor(0.45, 0.50, 0.58, 0.90)
        ph:SetText(placeholder or "")
        boxWrap.placeholder = ph
        boxWrap.editBox = eb

        local function UpdatePlaceholder()
            ph:SetShown((eb:GetText() or "") == "" and not eb:HasFocus())
        end
        eb:SetScript("OnEditFocusGained", function()
            local ar, ag, ab = GetSuiteAccent()
            boxWrap:SetBackdropBorderColor(ar, ag, ab, 0.95)
            UpdatePlaceholder()
        end)
        eb:SetScript("OnEditFocusLost", function()
            boxWrap:SetBackdropBorderColor(0.20, 0.24, 0.30, 0.95)
            UpdatePlaceholder()
        end)
        eb:SetScript("OnTextChanged", UpdatePlaceholder)
        eb:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
        UpdatePlaceholder()
        return boxWrap
    end

    local function CreateAccentActionButton(parent, width, height, labelText, onClick)
        local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        btn:SetSize(width, height or 24)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        local ar0, ag0, ab0 = GetSuiteAccent()
        btn:SetBackdropColor(0.043, 0.051, 0.071, 0.96) -- #0B0D12
        btn:SetBackdropBorderColor(ar0, ag0, ab0, 0.85)
        btn.label = btn:CreateFontString(nil, "OVERLAY")
        SetSafeFont(btn.label, 10, "")
        btn.label:SetPoint("CENTER", 0, 0)
        btn.label:SetText(labelText)
        btn.label:SetTextColor(0.976, 0.984, 1.00, 1)
        function btn:RefreshAccent()
            local ar, ag, ab = GetSuiteAccent()
            if self:IsMouseOver() then
                self:SetBackdropColor(ar * 0.24, ag * 0.24, ab * 0.24, 0.98)
                self:SetBackdropBorderColor(ar, ag, ab, 1.0)
            else
                self:SetBackdropColor(0.043, 0.051, 0.071, 0.96)
                self:SetBackdropBorderColor(ar, ag, ab, 0.85)
            end
        end
        btn:SetScript("OnEnter", function(s)
            local ar, ag, ab = GetSuiteAccent()
            s:SetBackdropColor(ar * 0.24, ag * 0.24, ab * 0.24, 0.98)
            s:SetBackdropBorderColor(ar, ag, ab, 1.0)
        end)
        btn:SetScript("OnLeave", function(s)
            local ar, ag, ab = GetSuiteAccent()
            s:SetBackdropColor(0.043, 0.051, 0.071, 0.96)
            s:SetBackdropBorderColor(ar, ag, ab, 0.85)
        end)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    -- Section 3C: Name & Keyword Mention Alerts
    local sec3_mentions = CreateSectionBox(
        page3,
        "NAME & KEYWORD MENTION ALERTS",
        "Get notified with a distinct chime, chat highlight, or alert banner when someone mentions your character name or a custom keyword.",
        root
    )

    local c3_mEnable = CreateCardRow(sec3_mentions, 60,
        "Enable Mention & Keyword Alerts",
        "Automatically detects your active character name and custom keywords in incoming chat (always ignores messages sent by you).",
        "Enable Mention & Keyword Alerts",
        "Turn Name and Keyword Mention Alerts On or Off."
    )
    AttachSegmentedSwitchToCard(c3_mEnable,
        function() return EnsureDB().enableMentionAlerts ~= false end,
        function(val)
            EnsureDB().enableMentionAlerts = (val == true)
            DynamicChat:RefreshConfigUI()
        end,
        "Off", "Enabled",
        "Toggle Name & Keyword Mention Alerts."
    )
    sec3_mentions.orderedCards[#sec3_mentions.orderedCards + 1] = c3_mEnable
    root.allControls[#root.allControls + 1] = c3_mEnable

    local c3_mKeywords = CreateCardRow(sec3_mentions, 64,
        "Custom Keywords",
        "Comma-separated words to watch for (e.g. dentee, lust, brez, innervate). Whole-word, case-insensitive.",
        "Custom Keywords",
        "Type comma-separated keywords and click Save."
    )
    local kwSaveBtn = CreateAccentActionButton(c3_mKeywords, 58, 24, "Save", nil)
    kwSaveBtn:SetPoint("RIGHT", c3_mKeywords, "RIGHT", -14, 0)
    local kwBox = CreateObsidianEditBox(c3_mKeywords, 210, 24, "e.g. dentee, lust, brez, innervate")
    kwBox:SetPoint("RIGHT", kwSaveBtn, "LEFT", -6, 0)
    kwBox.editBox:SetText(EnsureDB().mentionKeywords or "")
    local function SaveKeywords()
        local raw = kwBox.editBox:GetText() or ""
        local trimmed = raw:gsub("^%s+", ""):gsub("%s+$", "")
        EnsureDB().mentionKeywords = trimmed
        kwBox.editBox:ClearFocus()
        PrintMsg("Saved mention keywords.")
    end
    kwSaveBtn:SetScript("OnClick", SaveKeywords)
    kwBox.editBox:SetScript("OnEnterPressed", SaveKeywords)
    function kwBox:RefreshValue()
        if not self.editBox:HasFocus() then
            self.editBox:SetText(EnsureDB().mentionKeywords or "")
        end
    end
    c3_mKeywords.toggleBtn = kwBox
    AnchorCardTextToRightWidget(c3_mKeywords, kwBox)
    sec3_mentions.orderedCards[#sec3_mentions.orderedCards + 1] = c3_mKeywords
    root.allControls[#root.allControls + 1] = c3_mKeywords

    local c3_mNameSnd = CreateCardRow(sec3_mentions, 60,
        "Name Mention Sound",
        "Chime played when another player mentions your active character name in chat.",
        "Name Mention Sound",
        "Choose a sound effect for direct character name mentions."
    )
    AttachSoundDropdownToCard(c3_mNameSnd, "MENTION_NAME")
    sec3_mentions.orderedCards[#sec3_mentions.orderedCards + 1] = c3_mNameSnd
    root.allControls[#root.allControls + 1] = c3_mNameSnd

    local c3_mKwSnd = CreateCardRow(sec3_mentions, 60,
        "Keyword Trigger Sound",
        "Chime played when an incoming message matches one of your saved custom keywords.",
        "Keyword Trigger Sound",
        "Choose a sound effect for custom keyword matches."
    )
    AttachSoundDropdownToCard(c3_mKwSnd, "MENTION_KEYWORD")
    sec3_mentions.orderedCards[#sec3_mentions.orderedCards + 1] = c3_mKwSnd
    root.allControls[#root.allControls + 1] = c3_mKwSnd

    local c3_mHighlight = CreateCardRow(sec3_mentions, 60,
        "Highlight Mention in Chat",
        "Prints a highlighted alert in your chat window whenever your name or a keyword is mentioned.",
        "Highlight Mention in Chat",
        "Toggle accent-highlighted chat callouts for mentions and keywords."
    )
    AttachSegmentedSwitchToCard(c3_mHighlight,
        function() return EnsureDB().mentionHighlightInChat ~= false end,
        function(val) EnsureDB().mentionHighlightInChat = (val == true) end,
        "Off", "Enabled",
        "Toggle chat highlight callouts for mentions."
    )
    sec3_mentions.orderedCards[#sec3_mentions.orderedCards + 1] = c3_mHighlight
    root.allControls[#root.allControls + 1] = c3_mHighlight

    local c3_mToast = CreateCardRow(sec3_mentions, 60,
        "Mention Alert Toast",
        "Shows a shared alert banner when your name or a keyword matches. Style and position follow Suite Studio's Shared Alert Toast settings.",
        "Mention Alert Toast",
        "Toggle shared floating alert toast banners for chat mentions and keywords."
    )
    AttachSegmentedSwitchToCard(c3_mToast,
        function() return EnsureDB().mentionAlertToast ~= false end,
        function(val) EnsureDB().mentionAlertToast = (val == true) end,
        "Off", "Enabled",
        "Toggle floating alert toast banners."
    )
    sec3_mentions.orderedCards[#sec3_mentions.orderedCards + 1] = c3_mToast
    root.allControls[#root.allControls + 1] = c3_mToast

    -- Section 3D: Custom Sound File Manager (.ogg / .mp3)
    local sec3_custom = CreateSectionBox(
        page3,
        "CUSTOM SOUND FILES",
        "Register your own .ogg or .mp3 files (relative to Interface\\AddOns\\...) to use in any channel or mention dropdown. .wav files are blocked for Retail 12.1.5 compatibility.",
        root
    )

    local c3_addCustom = CreateCardRow(sec3_custom, 72,
        "Add Custom Sound",
        "Enter a display name and file path (e.g. Interface\\AddOns\\MySounds\\bell.ogg).",
        "Add Custom Sound",
        "Add a custom .ogg or .mp3 sound file to all DynamicChat sound dropdowns."
    )
    local csTestBtn = CreateAccentActionButton(c3_addCustom, 68, 24, "Test Play", nil)
    csTestBtn:SetPoint("RIGHT", c3_addCustom, "RIGHT", -14, 0)
    local csAddBtn = CreateAccentActionButton(c3_addCustom, 48, 24, "Add", nil)
    csAddBtn:SetPoint("RIGHT", csTestBtn, "LEFT", -6, 0)
    local csPathBox = CreateObsidianEditBox(c3_addCustom, 178, 24, "Interface\\AddOns\\...\\file.ogg")
    csPathBox:SetPoint("RIGHT", csAddBtn, "LEFT", -6, 0)
    local csNameBox = CreateObsidianEditBox(c3_addCustom, 96, 24, "Label")
    csNameBox:SetPoint("RIGHT", csPathBox, "LEFT", -6, 0)
    AnchorCardTextToRightWidget(c3_addCustom, csNameBox)

    csTestBtn:SetScript("OnClick", function()
        local p = (csPathBox.editBox:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if not SoundMgr.IsValidCustomAudioPath(p) then
            PrintMsg("Please enter a valid .ogg or .mp3 path (.wav is not supported).")
            return
        end
        local outChan = EnsureDB().soundOutputChannel or "Master"
        if type(_G.PlaySoundFile) == "function" then
            local okF, willPlay = pcall(_G.PlaySoundFile, p, outChan)
            if not (okF and willPlay ~= false) then
                PrintMsg("Could not play file. Ensure the path is valid and restart WoW if the file was just added.")
            end
        end
    end)

    local MAX_CUSTOM_SOUND_ROWS = 6
    local customSoundRows = {}

    local function RefreshCustomSoundRows()
        local list = EnsureDB().customSounds or {}
        for i = 1, MAX_CUSTOM_SOUND_ROWS do
            local rowCard = customSoundRows[i]
            local entry = list[i]
            if rowCard then
                if entry then
                    rowCard._customEntry = entry
                    rowCard.title:SetText(entry.label or entry.id)
                    rowCard.desc:SetText(entry.path or "")
                    rowCard:Show()
                else
                    rowCard._customEntry = nil
                    rowCard:Hide()
                end
            end
        end
        if root and root.RefreshLayout then
            root:RefreshLayout()
        end
    end

    csAddBtn:SetScript("OnClick", function()
        local lbl = (csNameBox.editBox:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local p   = (csPathBox.editBox:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if not SoundMgr.IsValidCustomAudioPath(p) then
            PrintMsg("Only .ogg and .mp3 sound files are supported (.wav files are blocked).")
            return
        end
        if lbl == "" then
            lbl = p:match("([^\\/]+)%.[^%.]+$") or "Custom Sound"
        end
        local db = EnsureDB()
        db.customSounds = db.customSounds or {}
        if #db.customSounds >= MAX_CUSTOM_SOUND_ROWS then
            PrintMsg("Maximum of " .. MAX_CUSTOM_SOUND_ROWS .. " custom sounds reached. Delete one to add another.")
            return
        end
        local slug = lbl:lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
        if slug == "" then slug = "sound" end
        local id = "CUSTOM:" .. slug .. "_" .. tostring(#db.customSounds + 1)
        for _, existing in ipairs(db.customSounds) do
            if existing.id == id then
                id = id .. "_" .. tostring(math.floor((_G.GetTime and _G.GetTime() or 1) * 100))
                break
            end
        end
        db.customSounds[#db.customSounds + 1] = {
            id    = id,
            label = lbl,
            path  = p,
        }
        csNameBox.editBox:SetText("")
        csPathBox.editBox:SetText("")
        csNameBox.editBox:ClearFocus()
        csPathBox.editBox:ClearFocus()
        RefreshCustomSoundRows()
        DynamicChat:RefreshConfigUI()
        PrintMsg("Added custom sound: " .. lbl)
    end)

    sec3_custom.orderedCards[#sec3_custom.orderedCards + 1] = c3_addCustom
    root.allControls[#root.allControls + 1] = c3_addCustom

    for i = 1, MAX_CUSTOM_SOUND_ROWS do
        local rowCard = CreateCardRow(sec3_custom, 54, "Custom Sound", "", nil, nil)
        local delBtn = CreateAccentActionButton(rowCard, 56, 22, "Delete", function()
            if not rowCard._customEntry then return end
            local targetId = rowCard._customEntry.id
            local db = EnsureDB()
            local newList = {}
            for _, item in ipairs(db.customSounds or {}) do
                if item.id ~= targetId then
                    newList[#newList + 1] = item
                end
            end
            db.customSounds = newList
            EnsureDB()
            RefreshCustomSoundRows()
            DynamicChat:RefreshConfigUI()
        end)
        delBtn:SetPoint("RIGHT", rowCard, "RIGHT", -14, 0)
        local playBtn = CreateAccentActionButton(rowCard, 50, 22, "Play", function()
            if not rowCard._customEntry then return end
            DynamicChat:PlaySoundOptionKey(rowCard._customEntry.id, nil, true)
        end)
        playBtn:SetPoint("RIGHT", delBtn, "LEFT", -6, 0)
        AnchorCardTextToRightWidget(rowCard, playBtn)
        rowCard:Hide()
        customSoundRows[i] = rowCard
        sec3_custom.orderedCards[#sec3_custom.orderedCards + 1] = rowCard
    end
    RefreshCustomSoundRows()

    -- ========================================================================
    -- TAB 4: Links, Scroll & History
    -- ========================================================================
    local page4 = root.tabPages[4]
    local sec3a = CreateSectionBox(
        page4,
        "CLICKABLE WEB LINKS & FAST SCROLLING",
        "Click web links in chat to copy them and use Shift or Ctrl with your mousewheel to scroll faster.",
        root
    )
    local sec3b = CreateSectionBox(
        page4,
        "CHAT HISTORY, RELOAD RETENTION & COMBAT LOG SPEED",
        "Keep your recent chat messages after reloading and stop the Combat Log tab from freezing.",
        root
    )
    local sec3c = CreateSectionBox(
        page4,
        "QUICK SLASH COMMANDS & ADDON COMPATIBILITY",
        "Handy everyday chat commands (/rl, /lg) and automatic compatibility with other UI suites.",
        root
    )

    local c3_urls = CreateCardRow(sec3a, 62,
        "Clickable Web Links (Discord, Wago, CurseForge)",
        "Turns web addresses in chat into clickable links that open a quick Ctrl+C copy box.",
        "Clickable Web Links",
        "Click web links in chat to open a pre-highlighted Ctrl+C copy box."
    )
    AttachSegmentedSwitchToCard(c3_urls,
        function() return EnsureDB().clickableURLs end,
        function(val)
            EnsureDB().clickableURLs = val
        end,
        "Off", "Enabled",
        "Toggle clickable web links in chat."
    )
    sec3a.orderedCards[#sec3a.orderedCards + 1] = c3_urls
    root.allControls[#root.allControls + 1] = c3_urls

    local c3_scroll = CreateCardRow(sec3a, 62,
        "Fast Mousewheel Scrolling (Shift & Ctrl)",
        "Hold Shift while scrolling the mousewheel to scroll 5 lines at a time, or hold Ctrl to jump straight to the top or bottom of chat.",
        "Fast Mousewheel Scrolling (Shift & Ctrl)",
        "Hold Shift (5 lines) or Ctrl (top/bottom) while scrolling the mousewheel in chat."
    )
    AttachSegmentedSwitchToCard(c3_scroll,
        function() return EnsureDB().fastChatScroll end,
        function(val)
            EnsureDB().fastChatScroll = val
            EnsureDB().ctrlJumpScroll = val
        end,
        "Off", "Enabled",
        "Toggle Shift (5 lines) and Ctrl (top/bottom) mousewheel chat scrolling."
    )
    sec3a.orderedCards[#sec3a.orderedCards + 1] = c3_scroll
    root.allControls[#root.allControls + 1] = c3_scroll

    local c3_gpuCap = CreateCardRow(sec3b, 62,
        "Save Chat History Across Reloads & Logins",
        "Remembers your recent chat messages so your chat window isn't wiped blank when you type /reload or switch characters.",
        "Save Chat History Across Reloads",
        "Save and restore your recent chat messages across UI reloads and logins."
    )
    AttachSegmentedSwitchToCard(c3_gpuCap,
        function() return EnsureDB().preserveChatHistory ~= false and EnsureDB().enableGPUBufferCap ~= false end,
        function(val)
            EnsureDB().preserveChatHistory = val
            EnsureDB().enableGPUBufferCap = val
            if not val then
                EnsureDB().savedChatHistory = {}
            end
            DynamicChat:ApplyGPUBufferSettings()
        end,
        "Off", "Enabled",
        "Toggle saving chat history across /reload and logins."
    )
    sec3b.orderedCards[#sec3b.orderedCards + 1] = c3_gpuCap
    root.allControls[#root.allControls + 1] = c3_gpuCap

    local c3_gpuLines = CreateCardRow(sec3b, 62,
        "Saved Chat History Limit",
        "Choose how many recent chat messages are saved and restored when you reload your UI (250 Lines recommended).",
        "Saved Chat History Limit",
        "Select how many recent chat messages to save across reloads."
    )
    AttachMultiPillSelectorToCard(c3_gpuLines,
        {
            { value = 50,  label = "50 Lines" },
            { value = 100, label = "100 Lines" },
            { value = 250, label = "250 Lines" },
            { value = 500, label = "500 Lines" },
        },
        function()
            local n = tonumber(EnsureDB().maxChatLines) or 250
            if n <= 60 then return 50 end
            if n <= 150 then return 100 end
            if n <= 350 then return 250 end
            return 500
        end,
        function(val)
            EnsureDB().maxChatLines = tonumber(val) or 250
            EnsureDB().preserveChatHistory = true
            EnsureDB().enableGPUBufferCap = true
            DynamicChat:ApplyGPUBufferSettings()
            if c3_gpuCap.toggleBtn and c3_gpuCap.toggleBtn.RefreshValue then
                c3_gpuCap.toggleBtn:RefreshValue()
            end
        end,
        "Select how many recent chat messages are saved."
    )
    sec3b.orderedCards[#sec3b.orderedCards + 1] = c3_gpuLines
    root.allControls[#root.allControls + 1] = c3_gpuLines

    local c3_combatLogOpt = CreateCardRow(sec3b, 62,
        "Instant Combat Log Tab (Prevent Freeze)",
        "Caps the background Combat Log tab buffer and hides its redundant filter bar so clicking 'Combat Log' never lags or freezes your game.",
        "Instant Combat Log Tab",
        "Keep the Combat Log tab lightweight so switching tabs is always instant."
    )
    AttachSegmentedSwitchToCard(c3_combatLogOpt,
        function() return EnsureDB().optimizeCombatLogTab ~= false end,
        function(val)
            EnsureDB().optimizeCombatLogTab = val
            DynamicChat:OptimizeCombatLogTab()
        end,
        "Off", "Enabled",
        "Toggle Instant Combat Log Tab lag prevention."
    )
    sec3b.orderedCards[#sec3b.orderedCards + 1] = c3_combatLogOpt
    root.allControls[#root.allControls + 1] = c3_combatLogOpt

    local c3_slash = CreateCardRow(sec3c, 60,
        "Enable '/rl' (Reload UI) & '/lg' (Leave Group)",
        "Lets you type '/rl' in chat to quickly reload your interface and '/lg' to immediately leave your current party or instance group.",
        "Enable '/rl' & '/lg' Shortcuts",
        "Enable '/rl' (Reload UI) and '/lg' (Leave Group) chat shortcuts."
    )
    AttachSegmentedSwitchToCard(c3_slash,
        function() return EnsureDB().enableQuickSlash ~= false end,
        function(val)
            EnsureDB().enableQuickSlash = val
            DynamicChat:RegisterQuickSlashCommands()
        end,
        "Off", "Enabled",
        "Toggle '/rl' and '/lg' chat shortcuts."
    )
    sec3c.orderedCards[#sec3c.orderedCards + 1] = c3_slash
    root.allControls[#root.allControls + 1] = c3_slash

    LayoutPageCards(page1)
    LayoutPageCards(page2)
    LayoutPageCards(page3)
    LayoutPageCards(page4)
    DynamicChat:RefreshConfigUI()
    return root
end

function DynamicChat:RefreshConfigUI()
    local root = self.embeddedRoot
    if not root then return end
    local db = EnsureDB()
    local activeTab = tonumber(db.activeSubTab) or 1
    local maxTabs = (root.tabPages and #root.tabPages > 0) and #root.tabPages or 4
    if activeTab < 1 or activeTab > maxTabs then activeTab = 1 end

    local ar, ag, ab = GetSuiteAccent()
    local fillAlpha = (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.pillFillAlpha) or 0.42

    if root.ReflowChatTabBar then root.ReflowChatTabBar() end
    for idx, btn in ipairs(root.tabButtons or {}) do
        SetSafeFont(btn.text, 11, "")
        local isSel = (idx == activeTab)
        if isSel then
            btn:SetBackdropColor(ar * fillAlpha, ag * fillAlpha, ab * fillAlpha, 0.98)
            btn:SetBackdropBorderColor(ar, ag, ab, 0.95)
            btn.text:SetTextColor(1, 1, 1, 1)
        else
            btn:SetBackdropColor(0.078, 0.090, 0.122, 0.96)
            btn:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95)
            btn.text:SetTextColor(0.68, 0.74, 0.82, 1)
        end
    end

    -- Refresh 2-Tier Inline Conflict Resolution Card (only shown in standalone mode when an unresolved DIRECT chat replacement conflict exists)
    if root.conflictCard and root.scrollHolder and root.tabBar then
        local hostedInSuite = (_G.DynamicSuite and _G.DynamicSuite.HasUnifiedModuleConflictBanner and _G.DynamicSuiteMainFrame and root:GetParent() ~= UIParent)
        local conflicts = hostedInSuite and {} or self:ScanConflicts()
        local cScan = root.conflictCard
        local directEntry = nil
        local partialLabels = {}
        local partialDescs = {}
        for _, c in ipairs(conflicts) do
            if c.kind == "DIRECT" and not directEntry then
                directEntry = c
            elseif c.kind == "PARTIAL" then
                partialLabels[#partialLabels + 1] = c.label or c.addon
                if c.desc and c.desc ~= "" then
                    partialDescs[#partialDescs + 1] = c.desc
                end
            end
        end

        root.scrollHolder:ClearAllPoints()
        if not directEntry or hostedInSuite then
            cScan:Hide()
            root.scrollHolder:SetPoint("TOPLEFT", root.tabBar, "BOTTOMLEFT", 0, -8)
            root.scrollHolder:SetPoint("TOPRIGHT", root.tabBar, "BOTTOMRIGHT", 0, -8)
            root.scrollHolder:SetPoint("BOTTOM", root, "BOTTOM", 0, 10)
        else
            if directEntry.addon == "EllesmereUIChat" then
                table.insert(partialLabels, 1, "EllesmereUI Chat")
            end

            local rowY = -54
            local row1 = cScan.rows[1]
            if directEntry then
                row1:ClearAllPoints()
                row1:SetPoint("TOPLEFT", cScan, "TOPLEFT", 14, rowY)
                row1:SetPoint("TOPRIGHT", cScan, "TOPRIGHT", -14, rowY)
                SetSafeFont(row1.title, 11, "")
                SetSafeFont(row1.desc, 10, "")
                SetSafeFont(row1.actionBtn.txt, 10.5, "")
                row1.title:SetText(string.format("|cFFFFFFFF%s|r  |cFFF5B82E[Direct Chat Replacement]|r", directEntry.label or directEntry.addon))
                row1.desc:SetText(string.format("|cFFF5B82EConflict Detected: %s is currently active and may cause UI errors or blocked actions.|r", directEntry.label or directEntry.addon))
                row1.actionBtn:SetBackdropColor(ar * fillAlpha, ag * fillAlpha, ab * fillAlpha, 0.98)
                row1.actionBtn:SetBackdropBorderColor(ar, ag, ab, 0.95)
                row1.actionBtn.txt:SetText("Use DynamicChat Only")
                row1.actionBtn:SetScript("OnClick", function()
                    DynamicChat:DisableAndFreezeConflictAddon(directEntry.addon)
                end)
                if row1.secondaryBtn then
                    SetSafeFont(row1.secondaryBtn.txt, 10.5, "")
                    local keepTxt = "Use " .. (directEntry.label or directEntry.addon) .. " Only"
                    if #keepTxt > 22 then keepTxt = "Use Other Only" end
                    row1.secondaryBtn.txt:SetText(keepTxt)
                    row1.secondaryBtn:SetScript("OnClick", function()
                        DynamicChat:KeepConflictAddon(directEntry.addon)
                    end)
                end
                row1:Show()
                rowY = rowY - 56
            else
                row1:Hide()
            end

            if cScan.rows[2] then
                cScan.rows[2]:Hide()
            end

            local scanH = math.abs(rowY) + 8
            cScan:SetHeight(scanH)
            cScan:Show()
            root.scrollHolder:SetPoint("TOPLEFT", cScan, "BOTTOMLEFT", 0, -10)
            root.scrollHolder:SetPoint("TOPRIGHT", cScan, "BOTTOMRIGHT", 0, -10)
            root.scrollHolder:SetPoint("BOTTOM", root, "BOTTOM", 0, 10)
        end
    end

    for _, hdr in ipairs(root.sectionHeaders or {}) do
        if hdr.RefreshAccent then hdr:RefreshAccent() end
    end

    for _, c in ipairs(trackedCardRows) do
        if c.title then c.title:SetTextColor(0.97, 0.98, 1.0, 1.0) end
    end

    for idx, page in ipairs(root.tabPages or {}) do
        LayoutPageCards(page)
        if idx == activeTab then
            page:Show()
            root.scrollHolder.content:SetHeight(math.max(1, page:GetHeight() or 1))
        else
            page:Hide()
        end
    end

    for _, ctrl in ipairs(root.allControls or {}) do
        if ctrl.title then SetSafeFont(ctrl.title, 11, "") end
        if ctrl.desc then SetSafeFont(ctrl.desc, 10, "") end
        if ctrl.toggleBtn and ctrl.toggleBtn.RefreshValue then ctrl.toggleBtn:RefreshValue() end
    end

    if root.scrollHolder and root.scrollHolder.thumb then
        root.scrollHolder.thumb:SetBackdropColor(0.38, 0.45, 0.56, 0.85)
    end
    if root.scrollHolder and root.scrollHolder.UpdateThumb then
        root.scrollHolder.UpdateThumb()
    end
end

function DynamicChat._ApplyChatThemeToUI()
    if IsModuleDisabledInSuite("DynamicChat") then
        DynamicChat:TeardownDisabledState(false)
        DynamicChat:RefreshConfigUI()
        return
    end
    DynamicChat:ApplySleekChatSkin()
    DynamicChat:ApplyChatFrameTypography()
    if DynamicChat.ApplyMentionToastVisuals then
        DynamicChat:ApplyMentionToastVisuals()
    end
    DynamicChat:RefreshConfigUI()
    if DynamicChat.standaloneFrame and DynamicChat.standaloneFrame:IsShown() then
        local ar, ag, ab = GetSuiteAccent()
        DynamicChat.standaloneFrame:SetBackdropBorderColor(ar, ag, ab, 0.75)
        if DynamicChat.standaloneFrame.statusText then
            DynamicChat.standaloneFrame.statusText:SetText(GetChatStatusText())
        end
    end
end

function DynamicChat._ResetChatModuleDefaults()
    CloseActiveDropdown()
    local existingHistory = (type(_G.DynamicChatDB) == "table" and type(_G.DynamicChatDB.savedChatHistory) == "table") and _G.DynamicChatDB.savedChatHistory or {}
    _G.DynamicChatDB = nil
    local db = EnsureDB()
    db.savedChatHistory = existingHistory
    DynamicChat:ApplyAllEngineSettings()
    DynamicChat:RefreshConfigUI()
    PrintMsg("Reset all DynamicChat settings to factory defaults.")
end

-- ============================================================================
-- 8. STANDALONE SHELL (/dchat & /dc Fallback) & _G.DYNAMICSUITE REGISTRATION
-- ============================================================================

function DynamicChat._EnsureStandaloneWindow()
    if DynamicChat.standaloneFrame then return DynamicChat.standaloneFrame end

    local f = CreateFrame("Frame", "DynamicChatStandaloneFrame", UIParent, "BackdropTemplate")
    f:SetSize(880, 600)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
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
    f:SetBackdropColor(0.035, 0.039, 0.051, 0.98)
    local ar, ag, ab = GetSuiteAccent()
    f:SetBackdropBorderColor(ar, ag, ab, 0.75)
    SafeRegisterUISpecialFrame("DynamicChatStandaloneFrame")

    local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
    header:SetHeight(42)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    header:SetBackdropColor(0.015, 0.018, 0.024, 1.00)

    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(20, 20)
    logo:SetPoint("LEFT", header, "LEFT", 12, 0)
    logo:SetTexture(ICON_MAIN)
    logo:SetVertexColor(ar, ag, ab, 1.0)
    f.logoTex = logo

    local title = header:CreateFontString(nil, "OVERLAY")
    SetSafeFont(title, 14, "")
    title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    title:SetText("|cFFCBD5E1Dynamic|r|cFFFFFFFFChat|r " .. ColorWithAccent("v" .. DynamicChat.version))
    f.titleText = title

    local status = header:CreateFontString(nil, "OVERLAY")
    SetSafeFont(status, 11, "")
    status:SetPoint("CENTER", header, "CENTER", 20, 0)
    status:SetTextColor(0.58, 0.66, 0.78)
    status:SetText(GetChatStatusText())
    f.statusText = status

    local closeBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
    closeBtn:SetSize(26, 24)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -10, 0)
    closeBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    closeBtn:SetBackdropColor(0.078, 0.090, 0.122, 0.96)
    closeBtn:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95)
    closeBtn.txt = closeBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(closeBtn.txt, 11, "")
    closeBtn.txt:SetPoint("CENTER", 0, 0)
    closeBtn.txt:SetText("X")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local footer = CreateFrame("Frame", nil, f, "BackdropTemplate")
    footer:SetHeight(36)
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
    footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    footer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    footer:SetBackdropColor(0.015, 0.018, 0.024, 1.00)

    local dockHint = footer:CreateFontString(nil, "OVERLAY")
    SetSafeFont(dockHint, 10, "")
    dockHint:SetPoint("LEFT", footer, "LEFT", 14, 0)
    dockHint:SetTextColor(0.58, 0.64, 0.72, 1.0)
    dockHint:SetText("Active Module: DynamicChat   |cFF475569|||r   Slash: /dchat")
    f.dockHint = dockHint

    local blizzResetBtn = CreateFrame("Button", nil, footer, "BackdropTemplate")
    blizzResetBtn:SetSize(166, 24)
    blizzResetBtn:SetPoint("RIGHT", footer, "RIGHT", -24, 0)
    blizzResetBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    blizzResetBtn:SetBackdropColor(0.09, 0.06, 0.07, 0.96)
    blizzResetBtn:SetBackdropBorderColor(0.937, 0.267, 0.267, 0.55)
    blizzResetBtn.txt = blizzResetBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(blizzResetBtn.txt, 10, "")
    blizzResetBtn.txt:SetPoint("CENTER", 0, 0)
    blizzResetBtn.txt:SetTextColor(0.98, 0.72, 0.72, 0.96)
    blizzResetBtn.txt:SetText("Restore Blizzard Defaults")
    blizzResetBtn:SetScript("OnClick", function()
        DynamicChat:RestoreBlizzardDefaults()
    end)

    local resetModBtn = CreateFrame("Button", nil, footer, "BackdropTemplate")
    resetModBtn:SetSize(128, 24)
    resetModBtn:SetPoint("RIGHT", blizzResetBtn, "LEFT", -8, 0)
    resetModBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    resetModBtn:SetBackdropColor(0.078, 0.090, 0.122, 0.96)
    resetModBtn:SetBackdropBorderColor(0.145, 0.165, 0.212, 0.95)
    resetModBtn.txt = resetModBtn:CreateFontString(nil, "OVERLAY")
    SetSafeFont(resetModBtn.txt, 10, "")
    resetModBtn.txt:SetPoint("CENTER", 0, 0)
    resetModBtn.txt:SetTextColor(0.86, 0.88, 0.92, 0.95)
    resetModBtn.txt:SetText("Reset DynamicChat")
    resetModBtn:SetScript("OnClick", function()
        DynamicChat:ResetModuleDefaults()
    end)

    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 6, -4)
    body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", -6, 4)
    f.body = body

    -- Unified Bottom-Right Corner Resize Grip (14x14, -4/4, Slate at rest -> #F97316 Blaze Orange hover)
    local resizeGrip = CreateFrame("Button", nil, footer)
    resizeGrip:SetSize(14, 14)
    resizeGrip:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -4, 4)
    resizeGrip:SetFrameLevel(footer:GetFrameLevel() + 4)
    resizeGrip:EnableMouse(true)

    local gripTex = resizeGrip:CreateTexture(nil, "OVERLAY", nil, 5)
    gripTex:SetAllPoints()
    gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    gripTex:SetDesaturated(true)
    gripTex:SetVertexColor(0.55, 0.58, 0.65, 0.75)

    resizeGrip:SetScript("OnEnter", function()
        local ar, ag, ab = GetSuiteAccent()
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
            f:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
    end)

    RenderChatEmbedded(body)
    f:HookScript("OnHide", CloseActiveDropdown)
    f:Hide()
    DynamicChat.standaloneFrame = f
    return f
end

function DynamicChat._OpenChatWorkspace()
    if railPopoverFrame and railPopoverFrame:IsShown() then
        railPopoverFrame:Hide()
    end
    if railPopoverClickCatcher and railPopoverClickCatcher:IsShown() then
        railPopoverClickCatcher:Hide()
    end
    if _G.DynamicSuite and type(_G.DynamicSuite.OpenModule) == "function" then
        local ok = pcall(_G.DynamicSuite.OpenModule, _G.DynamicSuite, "DynamicChat")
        if ok then return end
    end
    if _G.DynamicLoadUI and type(_G.DynamicLoadUI.OpenToModule) == "function" then
        local ok = pcall(_G.DynamicLoadUI.OpenToModule, _G.DynamicLoadUI, "chat")
        if ok then return end
    end
    local f = DynamicChat._EnsureStandaloneWindow()
    local ar, ag, ab = GetSuiteAccent()
    f:SetBackdropBorderColor(ar, ag, ab, 0.75)
    if f.logoTex then f.logoTex:SetVertexColor(ar, ag, ab, 1.0) end
    if f.titleText then
        f.titleText:SetText("|cFFCBD5E1Dynamic|r|cFFFFFFFFChat|r " .. ColorWithAccent("v" .. DynamicChat.version))
    end
    if f.statusText then
        f.statusText:SetText(GetChatStatusText())
    end
    RenderChatEmbedded(f.body)
    f:Show()
    DynamicChat:RefreshConfigUI()
end

function DynamicChat:RenderEmbedded(arg1, arg2)
    return RenderChatEmbedded(arg1, arg2)
end

function DynamicChat:BuildEmbeddedPanel(arg1, arg2)
    return RenderChatEmbedded(arg1, arg2)
end

function DynamicChat:ApplyThemeToUI()
    return DynamicChat._ApplyChatThemeToUI()
end

function DynamicChat:ApplyTheme()
    return DynamicChat._ApplyChatThemeToUI()
end

local reloadPromptModal = nil

local function ShowDynamicChatReloadPromptModal()
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    CloseActiveDropdown()
    if not reloadPromptModal then
        local modal = CreateFrame("Frame", "DynamicChatReloadPromptModal", UIParent, "BackdropTemplate")
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
        modal:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        local ar0, ag0, ab0 = GetSuiteAccent()
        modal:SetBackdropColor(0.043, 0.051, 0.071, 0.98)
        modal:SetBackdropBorderColor(ar0, ag0, ab0, 0.95)
        SafeRegisterUISpecialFrame("DynamicChatReloadPromptModal")

        local topAccent = modal:CreateTexture(nil, "OVERLAY")
        topAccent:SetHeight(2)
        topAccent:SetPoint("TOPLEFT", modal, "TOPLEFT", 1, -1)
        topAccent:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -1, -1)
        topAccent:SetColorTexture(ar0, ag0, ab0, 1.0)
        modal.topAccent = topAccent

        local closeBtn = CreateFrame("Button", nil, modal, "BackdropTemplate")
        closeBtn:SetSize(22, 20)
        closeBtn:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -10, -10)
        closeBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        closeBtn:SetBackdropColor(0.078, 0.090, 0.122, 0.96)
        closeBtn:SetBackdropBorderColor(0.200, 0.240, 0.310, 0.95)
        local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
        SetSafeFont(closeTxt, 10, "")
        closeTxt:SetPoint("CENTER", 0, 0)
        closeTxt:SetTextColor(0.92, 0.95, 0.99, 1.0)
        closeTxt:SetText("X")
        closeBtn:SetScript("OnEnter", function(selfBtn)
            local ar, ag, ab = GetSuiteAccent()
            selfBtn:SetBackdropColor(ar * 0.36, ag * 0.36, ab * 0.36, 1.0)
            selfBtn:SetBackdropBorderColor(ar, ag, ab, 1.0)
            closeTxt:SetTextColor(1, 1, 1, 1)
        end)
        closeBtn:SetScript("OnLeave", function(selfBtn)
            selfBtn:SetBackdropColor(0.078, 0.090, 0.122, 0.96)
            selfBtn:SetBackdropBorderColor(0.200, 0.240, 0.310, 0.95)
            closeTxt:SetTextColor(0.92, 0.95, 0.99, 1.0)
        end)
        closeBtn:SetScript("OnClick", function() modal:Hide() end)

        local title = modal:CreateFontString(nil, "OVERLAY")
        SetSafeFont(title, 12, "")
        title:SetPoint("TOPLEFT", modal, "TOPLEFT", 18, -14)
        title:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)
        title:SetJustifyH("LEFT")
        title:SetText(ColorWithAccent("DynamicChat") .. "  |cFF94A3B8-- Restore Blizzard Defaults|r")
        modal.title = title

        local headerSep = modal:CreateTexture(nil, "ARTWORK")
        headerSep:SetHeight(1)
        headerSep:SetPoint("TOPLEFT", modal, "TOPLEFT", 18, -38)
        headerSep:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -18, -38)
        headerSep:SetColorTexture(0.200, 0.240, 0.310, 0.65)

        local body = modal:CreateFontString(nil, "OVERLAY")
        SetSafeFont(body, 10.5, "")
        body:SetPoint("TOPLEFT", modal, "TOPLEFT", 18, -50)
        body:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -18, -50)
        body:SetJustifyH("LEFT")
        body:SetJustifyV("TOP")
        body:SetSpacing(3)
        body:SetTextColor(0.886, 0.910, 0.941, 1.0)
        body:SetText("DynamicChat has restored Blizzard default chat settings and windows.\n\nReload UI now to complete cleanup?")
        modal.body = body

        local function CreateModalButton(parent, label, width, height, isPrimary, onClick)
            local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
            btn:SetSize(width, height)
            btn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            btn.txt = btn:CreateFontString(nil, "OVERLAY")
            SetSafeFont(btn.txt, 10.5, "")
            btn.txt:SetPoint("CENTER", btn, "CENTER", 0, 0)
            btn.txt:SetText(label)

            local function ApplyState(hover)
                if isPrimary then
                    local ar, ag, ab = GetSuiteAccent()
                    if hover then
                        btn:SetBackdropColor(ar * 0.36, ag * 0.36, ab * 0.36, 1.0)
                        btn:SetBackdropBorderColor(ar, ag, ab, 1.0)
                        btn.txt:SetTextColor(1.0, 1.0, 1.0, 1.0)
                    else
                        btn:SetBackdropColor(ar * 0.24, ag * 0.24, ab * 0.24, 0.96)
                        btn:SetBackdropBorderColor(ar, ag, ab, 0.95)
                        btn.txt:SetTextColor(1.0, 1.0, 1.0, 0.98)
                    end
                else
                    if hover then
                        btn:SetBackdropColor(0.150, 0.180, 0.240, 1.0)
                        btn:SetBackdropBorderColor(0.320, 0.380, 0.480, 1.0)
                        btn.txt:SetTextColor(1.0, 1.0, 1.0, 1.0)
                    else
                        btn:SetBackdropColor(0.090, 0.110, 0.150, 0.96)
                        btn:SetBackdropBorderColor(0.200, 0.240, 0.310, 0.95)
                        btn.txt:SetTextColor(0.796, 0.835, 0.882, 1.0)
                    end
                end
            end
            btn.RefreshStyle = ApplyState
            ApplyState(false)
            btn:SetScript("OnEnter", function() ApplyState(true) end)
            btn:SetScript("OnLeave", function() ApplyState(false) end)
            btn:SetScript("OnClick", onClick)
            return btn
        end

        modal.reloadBtn = CreateModalButton(modal, "Reload UI", 138, 28, true, function()
            modal:Hide()
            if type(_G.ReloadUI) == "function" then
                _G.ReloadUI()
            end
        end)
        modal.reloadBtn:SetPoint("BOTTOMRIGHT", modal, "BOTTOM", -6, 16)

        modal.laterBtn = CreateModalButton(modal, "Later", 138, 28, false, function()
            modal:Hide()
        end)
        modal.laterBtn:SetPoint("BOTTOMLEFT", modal, "BOTTOM", 6, 16)

        modal:Hide()
        reloadPromptModal = modal
    end
    local arShow, agShow, abShow = GetSuiteAccent()
    reloadPromptModal:SetBackdropBorderColor(arShow, agShow, abShow, 0.95)
    if reloadPromptModal.topAccent then reloadPromptModal.topAccent:SetColorTexture(arShow, agShow, abShow, 1.0) end
    if reloadPromptModal.title then reloadPromptModal.title:SetText(ColorWithAccent("DynamicChat") .. "  |cFF94A3B8-- Restore Blizzard Defaults|r") end
    if reloadPromptModal.reloadBtn and reloadPromptModal.reloadBtn.RefreshStyle then reloadPromptModal.reloadBtn.RefreshStyle(false) end
    if reloadPromptModal.laterBtn and reloadPromptModal.laterBtn.RefreshStyle then reloadPromptModal.laterBtn.RefreshStyle(false) end
    SafeRegisterUISpecialFrame("DynamicChatReloadPromptModal")
    reloadPromptModal:Show()
    reloadPromptModal:Raise()
end

function DynamicChat:RestoreBlizzardDefaults()
    if type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() then
        PrintMsg("Cannot restore Blizzard chat defaults while in combat. Please leave combat and try again.")
        return false
    end
    local chatCVars = {
        "chatClassColorOverride", "showTimestamps", "chatStyle",
        "whisperMode", "wholeChatWindowClickable", "removeChatDelay", "chatMouseScroll",
    }
    if C_CVar and type(C_CVar.SetCVar) == "function" and type(C_CVar.GetCVarDefault) == "function" then
        for _, cvarName in ipairs(chatCVars) do
            local okDef, defVal = pcall(C_CVar.GetCVarDefault, cvarName)
            if okDef and defVal ~= nil then
                pcall(C_CVar.SetCVar, cvarName, tostring(defVal))
            end
        end
    end
    if type(_G.FCF_ResetChatWindows) == "function" then
        pcall(_G.FCF_ResetChatWindows)
    end
    if type(_G.DynamicChatDB) == "table" then
        _G.DynamicChatDB.chatFramePos = nil
    end
    PrintMsg("Restored Blizzard default chat settings and windows. Reload UI to complete cleanup.")
    ShowDynamicChatReloadPromptModal()
    return true
end

function DynamicChat:ResetModuleDefaults()
    return DynamicChat._ResetChatModuleDefaults()
end

function DynamicChat:ResetDefaults()
    return DynamicChat._ResetChatModuleDefaults()
end

function DynamicChat:OpenWorkspace()
    return DynamicChat._OpenChatWorkspace()
end

function DynamicChat:Open()
    return DynamicChat._OpenChatWorkspace()
end

function DynamicChat._RegisterWithDynamicSuite()
    _G.DynamicSuite = _G.DynamicSuite or {}
    _G.DynamicSuite.modules = _G.DynamicSuite.modules or {}
    RegisterDynamicChatPopupClosers()

    local descriptor = {
        id                 = "chat",
        key                = "DynamicChat",
        name               = "DynamicChat",
        title              = "DynamicChat",
        sub                = "Target /ww & Chat QoL",
        subtitle           = "Target /ww & Chat QoL",
        desc               = "Instant /ww target whispers, smoked-glass chat skin with left shortcut bar, clickable links, and saved chat history across reloads.",
        slash              = "/dchat",
        version            = DynamicChat.version,
        order              = 80,
        icon               = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_chat.tga",
        fallbackIcon       = ICON_MAIN,
        iconWhite          = ICON_WHITE,
        iconAccent         = ICON_ACCENT,
        conflictRegistry   = _G.DynamicSuite.CONFLICT_REGISTRY["DynamicChat"],
        RenderEmbedded     = function(arg1, arg2) return RenderChatEmbedded(arg1, arg2) end,
        BuildEmbeddedPanel = function(arg1, arg2) return RenderChatEmbedded(arg1, arg2) end,
        Render             = function(arg1, arg2) return RenderChatEmbedded(arg1, arg2) end,
        ApplyThemeToUI     = DynamicChat._ApplyChatThemeToUI,
        ApplyTheme         = DynamicChat._ApplyChatThemeToUI,
        ResetModuleDefaults = DynamicChat._ResetChatModuleDefaults,
        ResetDefaults      = DynamicChat._ResetChatModuleDefaults,
        ResetModule        = DynamicChat._ResetChatModuleDefaults,
        Reset              = DynamicChat._ResetChatModuleDefaults,
        OpenWorkspace      = DynamicChat._OpenChatWorkspace,
        Open               = DynamicChat._OpenChatWorkspace,
        CloseActiveDropdown = CloseActiveDropdown,
        ClosePopups        = CloseActiveDropdown,
        GetStatusText      = function() return GetChatStatusText() end,
        OnDisableInSuite   = function()
            DynamicChat:TeardownDisabledState(true)
        end,
        OnEnableInSuite    = function()
            if _G.DynamicSuite and _G.DynamicSuite.modules then
                if _G.DynamicSuite.modules["chat"] then _G.DynamicSuite.modules["chat"]._disabledAtStartup = nil end
                if _G.DynamicSuite.modules["DynamicChat"] then _G.DynamicSuite.modules["DynamicChat"]._disabledAtStartup = nil end
            end
            if DynamicChat.RegisterRuntimeEvents then
                DynamicChat:RegisterRuntimeEvents()
            end
            PreRegisterDynamicChatSpecialFrames()
            DynamicChat:ApplyAllEngineSettings()
            if DynamicChat.RefreshConfigUI then
                DynamicChat:RefreshConfigUI()
            end
        end,
        SelectSubTab       = function(a1, a2)
            local idx = (type(a1) == "number") and a1 or a2 or 1
            EnsureDB().activeSubTab = idx
            if DynamicChat.RefreshConfigUI then
                DynamicChat:RefreshConfigUI()
            end
        end,
    }
    descriptor.SelectTab = descriptor.SelectSubTab
    DynamicChat.SelectSubTab = descriptor.SelectSubTab
    DynamicChat.SelectTab = descriptor.SelectSubTab

    function _G.DynamicChat_OnAddonCompartmentClick()
        DynamicChat._OpenChatWorkspace()
    end

    _G.DynamicSuite.modules["chat"] = descriptor
    _G.DynamicSuite.modules["DynamicChat"] = descriptor

    DynamicChat.CHANGELOG = {
        version = DynamicChat.version or VERSION,
        date = "22/11/2026",
        entries = {
            { type = "FIX",      text = "Chat Input Box Focus Error Fix (22/11/2026): Fixed a Retail 12.1.5 Lua error that could appear when action bars shifted or Blizzard refreshed the layout while the chat input box had a protected focus state. DynamicChat now tracks chat focus through Blizzard's focus events and checks input box visibility safely across both DynamicSuite and standalone DynamicChat." },
            { type = "UI",       text = "Release v2.7.0 - Unified Mention Alert Toast & Live Suite Accent Polish (21/11/2026): Upgraded DynamicChatMentionToast to the shared 410x74 Obsidian alert toast style (live Suite Accent, Scale, Opacity, Border Style, Auto-Fade Duration, Sound, Right-Click dismissal, and clean vertical stacking under suite toasts), clamped Chat Skin section header titles beside the Edit HUD button at 800x520, and replaced Blaze Orange focus borders, action buttons, font menu borders, and Restore Blizzard Defaults modal chrome with the live Suite Accent." },
            { type = "FIX",      text = "Font Dropdown Popover, 3-Way Interactive Scrollbars, Custom Reload Prompt & Chat Feedback (16/11/2026): Fixed the Chat Font Family dropdown menu so clicking outside the menu, pressing Escape, or switching tabs closes it cleanly and updates its arrow icon; upgraded the font picker, sound picker, and settings scrollbars to support mousewheel scrolling, dragging the scrollbar handle (with Suite Accent colour highlight), and clicking anywhere on the track to jump; fixed chat confirmation messages when saving mention keywords, testing or adding custom sounds, and using '/dc mute'; and replaced the default Blizzard reload popup when restoring chat defaults with a custom dark-obsidian and Blaze Orange confirmation window." },
            { type = "FIX",      text = "Embedded ChatFrame1 EditBox Dock & Zero Position Shift (16/11/2026): Embedded ebBar and ChatFrame1EditBox directly inside ChatFrame1's own 26px bottom (or top) bounds and padded ChatFrame1.FontStringContainer by 28px so the newest chat line never overlaps the EditBox; locked GetCompositeChatInsets() / GetVisibleContainerExtents() to constant (-leftExt, 8, 28, -6) insets regardless of 'Always Shaded' vs 'Only When Typing' so toggling EditBox shading never shifts ChatFrame1's screen position." },
            { type = "FEATURE",  text = "External Sound Discovery (LibSharedMedia-3.0, DBM, EXBOSS, BigWigs, WeakAuras, ElvUI), Curated Blizzard Default Sounds & Self-Whisper Alerts (15/11/2026): Removed temporary .wav sound files and LibSharedMedia .wav registration in favour of 7 curated native Blizzard SOUNDKIT alerts (Blizzard Raid Warning, Blizzard Whisper, Blizzard Battle.net, Blizzard Ready Check, Blizzard Map Ping, Blizzard Auction Bell, and Blizzard Quest Complete) with dual PlaySound / PlaySoundFile routing; set clean channel defaults (Blizzard Whisper, Blizzard Battle.net, Blizzard Map Ping, Blizzard Raid Warning, and Say & Yell muted by default) with automatic migration from legacy ds_*/ex_* keys; added runtime LibSharedMedia-3.0, DBM, EXBOSS, BigWigs, WeakAuras, and ElvUI sound scanning with late-load refresh and safe fallback to Blizzard Raid Warning; restored self-whisper alert playback on incoming CHAT_MSG_WHISPER / CHAT_MSG_BN_WHISPER events while keeping self-message suppression active for group and public channels; and upgraded channel sound dropdowns with Blizzard / SharedMedia headers, inline [>] previews, scrolling, a live search filter, and dedicated [Play] buttons." },
            { type = "FIX",      text = "Flush Bottom-Left (0, 0) Chat Clamping & Persistence (14/11/2026): Enforced ChatFrame1:SetClampedToScreen(false) whenever DynamicChat manages layout, added GetVisibleContainerExtents() and GetLiveOuterBottomLeft() so clamping measures only the visible chat container frame without external button or negative bottom EditBox overhangs, and canonicalised chatFramePos to BOTTOMLEFT outer-container coordinates so dragging or nudging to X = 0, Y = 0 sits flush against the bottom-left screen corner across HUD Edit toggles, UI scale events, and /reload." },
            { type = "FIX",      text = "Unified /ww Instant Target Whisper Across All Chat/Whisper EditBoxes (13/11/2026): Kept /ww as the instant target whisper trigger with self-targeting (UnitIsUnit('target', 'player')) using GetUnitName('target', true), separated group leave cleanly into /lg, called ChatEdit_UpdateHeader before SetText + SetCursorPosition so 'Tell <TargetName>:' updates immediately on spacebar even inside existing whisper tabs, and hooked all 1..NUM_CHAT_WINDOWS editboxes plus FCF_OpenTemporaryWindow and ChatEdit_ActivateChat regardless of external chat addons." },
            { type = "FIX",      text = "Removed Auto-Yield & Asserted Full DynamicChat Priority Over EllesmereUI Chat / ElvUI Chat (13/11/2026): DynamicChat no longer yields chat frame skinning, tab styling, EditBox anchoring, or bottom-left 0px positioning to EllesmereUI Chat or ElvUI Chat. Cleared legacy yieldSharedHooks and yieldHooks flags on load, removed the Tab 3 Compatibility Mode (Auto-Yield) card, and enforced strict 2-button mutual exclusion ('Use DynamicChat Only' vs 'Use [Addon] Only') in the Conflict Scanner." },
            { type = "FIX",      text = "Accurate Frozen/Unloaded Conflict Detection & Universal 'Use DynamicChat' Takeover (12/11/2026): Updated IsAddonLoadedNow, IsAddonActiveInSession, and IsEllesmereUIChatSubModuleEnabled so any external chat addon set to 'FROZEN' (Never) in DynamicLoad or overridden via 'USE_DYNAMIC' / 'RUN_BOTH' is treated as inactive (false), and prevented IsEllesmereUIChatSubModuleEnabled from falling back to parent EllesmereUI when EllesmereUIChat is installed as a separate sub-addon on disk and unloaded." },
            { type = "PERF",     text = "Zero-Allocation Raid Combat Path (12/11/2026): Fast-pathed FCF_StartAlertFlash and FCF_StopAlertFlash during InCombatLockdown() to style only the flashing tab (StyleSingleChatTab + RefreshTabNavButtonsVisuals) instead of running full LayoutDockedChatTabs table allocations on every combat tab flash; added an O(1) '/' prefix check in TryConvertTargetWhisperEditBox so normal typing in combat never evaluates slash regexes; reused pre-allocated URL capture tables in _urlCaptureFrame; and skipped RefreshLeftRailTelemetry() on UPDATE_INVENTORY_DURABILITY during combat." },
            { type = "FIX",      text = "HUD Mover |r Text Fix, EllesmereUIChat / Disable Gate Yield & 1:1 ChatFrame1 Mover Sync (12/11/2026): Fixed literal '|r' escape codes on the HUD Edit Mode overlay label, hid the DynamicChat HUD mover and skipped ChatFrame1 size/position overrides whenever DynamicChat is disabled or soft-yielding to an external chat addon (EllesmereUIChat, ElvUI, Prat-3.0, Chattynator, LS: Glass), locked the HUD mover and DynamicChat backdrop container 1:1 to ChatFrame1's live anchor, scale, width, and height, and lowered the HUD mover backdrop opacity so chat text remains visible while dragging." },
            { type = "FIX",      text = "In-Combat /ww (Whisper Target) & /lg (Leave Group) Shortcuts (12/11/2026): Wired /lg for fast group exit and /ww ('/ww ' space-trigger and '/ww <msg>' Enter trigger) with pcall + issecretvalue guards on UnitExists('target'), UnitIsPlayer('target'), and GetUnitName('target', true); and hooked OnTextChanged + OnSpacePressed with early bailout restricted strictly to BN_WHISPER or secret text/tellTarget values." },
            { type = "FIX",      text = "ChatFrameEditBox BN_WHISPER Secret-Number Taint Fix & EllesmereUI Conflict Detection (12/11/2026): Eliminated direct EditBox widget script hooks (OnChar / OnSpacePressed) on ChatFrame1EditBox so /ww relies strictly on SlashCmdList['DYNAMICCHATWW'] and hooksecurefunc post-hooks; added IsEditBoxSecretOrBNWhisper and explicit issecretvalue(editBox:GetAttribute('tellTarget')) / issecretvalue(editBox.header:GetStringWidth()) guards across TryConvertTargetWhisperEditBox, HandleTargetWhisperSlashCommand, ApplyPassiveEditBoxSkinOnInit, RefreshSleekEditBoxBarColor, ChatEdit_UpdateHeader, and ChatEdit_ActivateChat; restricted ChatFrame1EditBox font, texture, and anchor styling to passive init skinning (never inside OnEditBoxFocusGained or before UpdateHeader); and registered EllesmereUI (plus EllesmereUIChat / EllesmereUI_Chat) in the Core Conflict Registry under DynamicChat." },
            { type = "FEATURE",  text = "External Addon Conflict Detector & Smart Sub-Module Inspection (12/11/2026): Added pcall-guarded ElvUI[1].private.chat.enable and Leatrix_Plus sub-module inspection so ElvUI and Leatrix_Plus are only flagged when their chat sub-modules are active, alongside HARD conflict detection for Prat-3.0, Chattynator, ls_Glass, BasicChatMods, and Chatter and SOFT Auto-Yield for WIM." },
            { type = "FIX",      text = "0x Secret-String Taint Architecture (Zero ChatFrame_AddMessageEventFilter, Zero Startup CVar Writes & Zero ChatFrame1/2 Mixin Mutations): Eliminated 100% of 'attempt to perform string conversion on a secret string value (execution tainted by DynamicChat)' in Retail 12.1.5 by removing all ChatFrame_AddMessageEventFilter registrations (keeping _urlCaptureFrame as the sole, 100% isolated URL capture listener across all chat channels with IsSecretValue(msg) guarded first before any type/string check), removing startup/zone/combat C_CVar.SetCVar('showTimestamps') and C_CVar.SetCVar('chatClassColorOverride') calls so _G.CHAT_TIMESTAMP_FORMAT is never tainted on login or reload, prepending saved previous-session history inside DynamicChatHistoryModal instead of calling cf1:AddMessage / cf1:ScrollToBottom, turning RefreshChatFrameTextLayout and ApplyStickyChannelSettings into safe no-ops, removing cf2:SetMaxLines(300) and _G.DEFAULT_CHATFRAME_ALPHA / _G.CHAT_FRAME_TAB_*_ALPHA writes, and moving _dsEditModeActive / _dsDragging / _dsDragShield off ChatFrame1 onto DynamicChat." },
            { type = "FIX",      text = "Zero-Taint Secret-String Hotfix (Strict 3-Channel URL_FILTER_EVENTS), Private URL Capture Listener & 1-Click Left Rail Link Copy: Eliminated 'attempt to perform string conversion on a secret string value (execution tainted by DynamicChat)' in Retail 12.1.5 by restricting ChatFrame_AddMessageEventFilter strictly to CHAT_MSG_GUILD, CHAT_MSG_OFFICER, and CHAT_MSG_CHANNEL (never tainting ChatFrameUtil.ProcessMessageEventFilters / ChatFrameMixin:MessageEventHandler on Whispers, BNet, Party, Raid, Instance, or Say/Yell); added an isolated private event listener (_urlCaptureFrame) with string.find pcall probing to capture links across Whispers, BNet, Party, Raid, and Say/Yell into a 15-entry in-memory ring buffer merged into DynamicChatHistoryModal's 'Recent Links:' pill bar; added a Suite-Accent unread link indicator dot and Shift-Click / Middle-Click 1-click link copy shortcut on the Left Rail Copy button; and fixed DynamicChatHistoryModal active-tab extraction, ScrollChild EditBox rendering, and header text layout." },
            { type = "FIX",      text = "Synchronised DynamicChat.version to 1.2.0, guarded HandleTargetWhisperSlashCommand (/ww) against C_ChatInfo.InChatMessagingLockdown() and IsEncounterInProgress() by falling back to native EditBox population, guarded LayoutDockedChatTabs and UISpecialFrames registrations against InCombatLockdown() (pre-registering modal frame names at login and flushing deferred tab layouts on PLAYER_REGEN_ENABLED), and throttled scrollbar thumb OnUpdate scripts with OnMouseUp and OnHide cleanup." },
            { type = "FIX",      text = "Overflow Whisper Tab Clipping, Self-Whisper Testing, 'Blizzard Default' & LSM FileDataID Playback, and Tab Mousewheel Nil Fix: Stopped GeneralDockManager 38px left of the < / > navigation buttons (TOPRIGHT -30) with hardware child clipping (dock:SetClipsChildren(true)) and GeneralDockManagerScrollFrame suppression; hard-locked hiddenByScroll tabs with ClearAllPoints(), Hide(), and an OnShow guard hook (plus FCF_SetWindowName / FCF_CopyChatSettings / BN_FRIEND_INFO_CHANGED hooks) so overflow whisper/BNet tabs never stick out over the tab arrows; enabled self-whisper sound testing on CHAT_MSG_WHISPER / CHAT_MSG_BN_WHISPER; added numeric FileDataID support for LibSharedMedia-3.0 sound packs and BUILTIN_SOUND_LIBRARY; added a 2.0s unmute window + next-tick PlaySoundFile(567482/567421, outChan) playback so 'Blizzard Default' and built-in whisper chimes play reliably in dropdown previews and in-game without double-chiming or 300s tellTimer lockouts; kept sound alerts active alongside shared-hook addons; and hoisted RefreshTabNavButtonsVisuals above OnTabBarMouseWheel." },
            { type = "NEW",      text = "Per-Channel Sound Alert Engine & 4th 'Sound Alerts' Sub-Tab (Built-In + LibSharedMedia-3.0): Added a dedicated 4th 'Sound Alerts' tab supporting custom incoming alert sounds across 11 chat channels (Whisper, Battle.net Whisper, Party, Party Leader, Raid, Raid Leader & Warning, Instance, Guild, Officer, Say & Yell, and Custom Channels) with 12 built-in WoW SoundKits, automatic LibSharedMedia-3.0 sound discovery, inline [>] menu preview buttons, Right-Click closed-dropdown replay, native Blizzard whisper double-chime prevention (MuteSoundFile 567482/567421), secret-value safe self-message suppression, combat filter modes, and per-channel anti-spam cooldowns." },
            { type = "FIX",      text = "Fixed RestoreChatHistorySnapshot Nil Crash, Persistent Tab Arrows & Left Rail Across Docked Tabs, Whisper Tab Vertical Centering, and /ww First-Space Conversion: Hoisted IsInCombatOrActiveKeystone() above RefreshChatFrameTextLayout, added IsPrimaryChatDockVisible() so the < / > tab scroll arrows and Left Shortcut Rail remain visible when viewing Combat Log, Loot, Trade, or Whisper tabs, hooked FCF_SetTemporaryWindowType + vertically centred whisper tab labels, and hardened /ww EditBox conversion on the first Spacebar press (including cross-faction party/raid targets and PLAYER_LOGIN slash re-assertion)." },
            { type = "NEW",      text = "Scrollable Top Chat Tab Bar with Mousewheel + Left (<) & Right (>) Buttons (LayoutDockedChatTabs & EnsureTabNavButtons): Replaced tab-shrinking compression with a readable scrollable tab viewport so tabs never shrink into unreadable slivers even with 20+ whisper tabs open. Added Mousewheel Up (Scroll Left) and Mousewheel Down (Scroll Right) across all tabs, docked sleek Left (<) and Right (>) assist buttons on the right end of the Top Tab Header Bar (with Suite Accent / Whisper Pink / BNet Cyan unread indicators, Shift-Click jump to first/last tab, and Right-Click active chat screen cycling), stripped '-RealmName' suffixes on character whisper tab labels (preserving the full name in tooltips), suppressed Blizzard's rounded middle tab Glow/Flash texture, and added Middle-Click whisper tab closing." },
            { type = "FIX",      text = "Zero-Gap 0px Screen-Edge Persistence Across /reload & Blizzard Side Button Docking: Disabled C++ SetClampedToScreen (SetClampRectInsets(0,0,0,0) + SetClampedToScreen(false)) whenever DynamicChatDB.chatFramePos is active so Blizzard's FloatingChatFrame_UpdateBackgroundAnchors (-35/-50 C++ ClampRectInsets) can never push ChatFrame1 ~18px off the bottom/left screen edge after /reload; removed FCF_SavePositionAndDimensions from SaveChatFramePosition, preserved raw pos.x/pos.y in ApplySavedChatFramePosition, hooked SetSize/SetWidth/SetHeight/ApplySystemAnchor with next-frame re-assertion, and expanded GetCompositeChatInsets + external left/top docking for ChatFrame1ButtonFrame, ChatFrameMenuButton, and QuickJoinToastButton when 'Hide Default Blizzard Side Buttons' is turned Off." },
            { type = "NEW",      text = "Fused Unbroken Smoked-Glass EditBox Dock, Top-Line Text Fix & 0px Bottom Screen Clamp: Fused ChatFrame1's Smoked-Glass frame into one seamless piece of glass enclosing the Top Tab Bar (y = +5..+29), Left Utility Rail, Chat Text, and Bottom EditBox Dock (y = -6..-32 or Top y = +29..+55) with an interior 1px p.footerDiv hairline, idle 0% transparent editBox bar (zero double-darkening or seam), tightened p.headerDiv to y = +5 with deferred history restoration and RefreshChatFrameTextLayout to fix top-line text slicing, and synced GetCompositeChatInsets (-36, 8, 29/55, -32/-6) with FCF_RestorePositionAndDimensions hooks to permanently eliminate bottom gaps and post-reload drift." },
            { type = "IMPROVED", text = "Unpinned Top Conflict Banner & Tab 3 Shared-Hook Card: Auto-hid the top conflict banner whenever no unresolved DIRECT chat replacement addon is active (or when shared-hook addons like EnhanceQoLChatSocial / Leatrix Plus / ElvUI / WIM are auto-yielded), reclaiming 56px of vertical workspace, and added a dedicated 'Shared-Hook Compatibility (Auto-Yield)' card inside Tab 3." },
            { type = "FIX",      text = "Fixed Invisible Blizzard Side Buttons Stealing Left Rail Clicks: Added SetSideClutterButtonSuppressed (calling Hide(), EnableMouse(false), and hooking OnShow) on ChatFrameMenuButton, ChatFrameChannelButton, ChatFrameToggleVoiceDeafenButton, ChatFrameToggleVoiceMuteButton, QuickJoinToastButton, ChatFrame*ButtonFrame, and MinimizeButton, and elevated the Left Utility Rail to MEDIUM strata (FrameLevel 20/22) so Scroll-to-Bottom, Settings, and Durability buttons are never blocked by invisible Blizzard frames." },
            { type = "FIX",      text = "Instant Combat Log Tab & Debounced Tab Switching: Eliminated the client freeze when clicking the 'Combat Log' tab (ChatFrame2) by capping ChatFrame2 to 60 lines out of combat, hiding CombatLogQuickButtonFrame_Custom so it never collides with the 24px Top Tab Header Bar, hooking ChatFrame2Tab PreClick to trim/clear oversized combat log backlogs before WoW renders them, and upgrading FCF_SelectDockFrame + OnBlizzardDockOrTabUpdate with a lightweight fast-path and frame-debounced dock sync." },
            { type = "NEW",      text = "Save Chat History Across Reloads & Logins: Added 'Save Chat History Across Reloads & Logins' (preserveChatHistory = true) and 'Saved Chat History Limit' ([ 50 Lines | 100 Lines | 250 Lines | 500 Lines ]) on Tab 3 to save up to 250 non-secret ChatFrame1 messages on PLAYER_LOGOUT / ReloadUI and restore them on PLAYER_LOGIN." },
            { type = "FIX",      text = "Composite Screen Clamping & Flush EditBox Alignment: Anchored ChatFrame1EditBox and its Obsidian EditBox bar flush with the outer left and right edges of the Smoked-Glass container (including the 34px Left Utility Rail) and implemented composite screen boundary clamping (GetCompositeChatInsets & ClampChatFrameCoords) so the Left Utility Rail, Top Tab Bar, and bottom EditBox are never pushed off-screen." },
            { type = "IMPROVED", text = "Plain-English Rewrite Across Tabs 1, 2 & 3: Rewrote all technical developer jargon across DynamicChat's 3-tab workspace and status bar into clear, everyday Australian/British player English." },
            { type = "NEW",      text = "[+ HUD] Edit Mode 'Chat Frame' Target & Bottom-Right Resize Grip: Added 'Chat Frame' ('CHAT') as the 6th target in DynamicSuite's unified [+ HUD] Edit Mode (accessible via the top header [+ HUD] button or Left-Clicking the Lock icon on DynamicChat's Left Utility Rail) with live drag, 1px/10px directional nudge, grid snap, exact X/Y coordinate entry, scale slider, bottom-right resize grip (240..1200 x 100..900), and persistent SetPoint re-assertion over Blizzard Edit Mode." },
            { type = "FIX",      text = "Eliminated Inner Dark Box, Vertical Right Border Line & Top Text Clipping: Removed CHAT_FRAME_TAB_NORMAL_*_ALPHA = 1.0 and set DEFAULT_CHATFRAME_ALPHA = 0 so Blizzard's FCF_FadeInChatFrame / FCF_FadeOutChatFrame never forces ChatFrame1Background or ChatFrame1RightTexture to 100% alpha; hardened SuppressBlizzardChatBackground with Hide() + OnShow hooks across Background, all 8 border textures, and ResizeButton; and raised the 24px Top Tab Header Bar to y = +10..+34 (with BACKGROUND strata tab cells and full-width p.headerBg tint) for a clean +10px top text clearance buffer." },
            { type = "IMPROVED", text = "True In-Place Blizzard ChatFrame, Tab & 3px Auto-Fade ScrollBar Reskin: Eliminated the double-box background and 24px top gap by permanently stripping ChatFrame1..10Background, NineSlice, and all 8 border textures (guarded via FCF_SetWindowAlpha, FCF_SetWindowColor, and FloatingChatFrame_UpdateBackgroundAnchors hooks), tightening the 24px Top Tab Header Bar, stripping Blizzard's rounded tab textures across FCFTab_UpdateColors/FCFTab_UpdateAlpha with a full-width 2px Suite Accent active bottom bar, hiding ScrollToBottomButton, and reskinning ChatFrame.ScrollBar into a 3px auto-fading track over a borderless Smoked 25% glass backdrop." },
            { type = "FIX",     text = "Temporary Whisper Tab Skinning (ChatFrame11+) & High-Contrast Chat Tab Typography: Expanded ApplySleekChatSkin (via CollectAllChatFrames and StyleSingleChatTab) to skin all temporary Whisper and Battle.net Whisper tabs in _G.CHAT_FRAMES (ChatFrame11+) and hooked FCF_OpenTemporaryWindow, FCFDock_UpdateTabs, FCFTab_UpdateAlpha, FCFTab_UpdateColors, and FCF_Close. Eliminated dim/washed-out tab labels by locking CHAT_FRAME_TAB_*_ALPHA to 1.0, upgrading tab text to 11.5pt OUTLINE + drop shadow in Crisp White (#FFFFFF active/hover), Bright Silver-White (#E2E8F0 unselected), and Whisper Lavender-Pink (#F8D0FF) / BNet Cyan (#8FE0FF) with a semantic bottom whisper bar." },
            { type = "FIX",     text = "Raid & Mythic+ Secret-String Zero-Taint Fix: Eliminated the Retail 12.1.5 Raid taint error ('attempt to perform string conversion on a secret string value (execution tainted by DynamicChat)') by never overwriting global _G.CHAT_*_GET format strings (which ChatFrameMixin:MessageEventHandler concatenates with <secret string> raid messages and playerLinks), never calling ScrollingMessageFrameMixin Lua mutators (cf:SetFont, cf:SetMaxLines, or ChatFrame1.AddMessage hooks) that taint cf.fontStringPool / cf.historyBuffer, and isolating URL message filters from Raid, Party, Instance, Say, Yell, and Whisper channels with full HasAnySecretArg(...) + IsEncounterInProgress() bailouts." },
            { type = "NEW",     text = "Sleek Monochrome Icon Left Utility Rail, 1-Click Great Vault & Customizer Menu: Upgraded the 36px Left Vertical Utility Rail with crisp monochrome .tga icons (icon_social, icon_shield, icon_vault, icon_copy, icon_log, icon_lock, icon_cog, icon_chevron_down) + numeric badges, replacing text labels ('SOC', 'DUR', 'CPY/TXT', 'LOG/CLR'). Added 8 customizable rail widgets (Social & Guild, Durability %, 1-Click Great Vault & M+, Copy & Clear Chat, Combat Log Toggle, Chat Lock/Fade & Zone Profiles, Settings + Right-Click Rail Customizer Popover, and Scroll to Bottom) plus Tab 2 visibility modes (Always, Mouseover, Combat Hide, Off) and an 8-chip toggle grid." },
            { type = "NEW",     text = "Smoked-Glass Chat Container, 26px Top Tab Header Bar & 36px Left Utility Rail: Upgraded DynamicChat's UIParent-hosted chat skin to a unified Smoked-Glass container (#090A0D at 35% default alpha) enclosing a 26px Top Tab Header Bar (with smoked tab cells and a 2px Suite Accent active underline) and a 36px Left Vertical Utility Rail." },
            { type = "NEW",     text = "Zero-Taint Native C++ Chat Timestamps (showTimestamps): Added a 4-pill Timestamp selector on Tab 2 ([ Off | 24h (01:32) | 12h (01:32 PM) | HH:MM:SS ]) backed by Blizzard's native C++ 'showTimestamps' CVar with 0.00% AddMessage taint." },
            { type = "NEW",     text = "EllesmereUIChat & EnhanceQoL Conflict / Auto-Yield Protection: Detects EllesmereUIChat and automatically yields all overlapping skin, channel, EditBox, URL, scroll, and SetMaxLines hooks (plus uses OnChar/OnSpacePressed and private hook tables with 0 properties written to ChatFrame tables) so EllesmereUIChat runs with 0.00% interference, or lets you 1-click [Use DynamicChat] to replace it." },
            { type = "NEW",     text = "Signature /ww Target Whisper Engine: Live EditBox conversion transforms '/ww ' into Blizzard's native C++ WHISPER state so pressing Enter executes Blizzard's native ChatEdit_SendText with zero combat or Mythic+ taint." },
            { type = "NEW",     text = "Combat & Mythic+ Whisper Protection + Zero-Bloat Buffer Guard: Never registers ChatFrame_AddMessageEventFilter on whisper or raid/instance events, skips regex URL scanning during combat/encounters/active M+ keys, and stores zero chat message logs in SavedVariables." },
        },
    }
    _G.DynamicSuite.Changelogs = _G.DynamicSuite.Changelogs or {}
    _G.DynamicSuite.Changelogs["DynamicChat"] = DynamicChat.CHANGELOG
    _G.DynamicSuite.Changelogs["chat"] = DynamicChat.CHANGELOG

    if type(_G.DynamicSuite.RegisterModule) == "function" then
        pcall(_G.DynamicSuite.RegisterModule, _G.DynamicSuite, "chat", descriptor)
    end
end

DynamicChat._RegisterWithDynamicSuite()

SLASH_DYNAMICCHAT1 = "/dchat"
SLASH_DYNAMICCHAT2 = "/dc"
SLASH_DYNAMICCHAT3 = "/dynamicchat"
SlashCmdList["DYNAMICCHAT"] = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(.-)%s*$")
    if cmd == "reset" then
        DynamicChat._ResetChatModuleDefaults()
    elseif cmd == "history" then
        DynamicChat:ShowFullChatHistoryModal(ResolveActiveChatFrame())
    elseif cmd == "copy" or cmd == "url" then
        DynamicChat:ShowURLCopyPopup("https://www.curseforge.com/wow/addons")
    elseif cmd == "testaudio" then
        DynamicChat:PreviewSuiteChimePack()
    elseif cmd == "mute" then
        local db = EnsureDB()
        local nextState = (db.enableChatSounds == false)
        db.enableChatSounds = nextState
        db.enableSoundAlerts = nextState
        DynamicChat:ApplyWhisperDefaultSoundMuteState()
        DynamicChat:RefreshConfigUI()
        PrintMsg("Chat notification sounds " .. (nextState and "enabled." or "muted (saved chimes preserved)."))
    else
        DynamicChat._OpenChatWorkspace()
    end
end

-- ============================================================================
-- 9. EVENT DISPATCHER
-- ============================================================================

function DynamicChat:RegisterRuntimeEvents()
    if IsModuleDisabledInSuite("DynamicChat") then return end
    local RUNTIME_EVENTS = {
        "PLAYER_LOGOUT",
        "PLAYER_ENTERING_WORLD",
        "PLAYER_REGEN_DISABLED",
        "PLAYER_REGEN_ENABLED",
        "UPDATE_CHAT_WINDOWS",
        "UPDATE_FLOATING_CHAT_WINDOWS",
        "DISPLAY_SIZE_CHANGED",
        "UI_SCALE_CHANGED",
        "EDIT_MODE_LAYOUTS_UPDATED",
        "FRIENDLIST_UPDATE",
        "BN_FRIEND_INFO_CHANGED",
        "GUILD_ROSTER_UPDATE",
        "UPDATE_INVENTORY_DURABILITY",
        "WEEKLY_REWARDS_UPDATE",
    }
    local function SafeRegisterEvent(frame, eventName)
        if not frame or not eventName then return end
        if _G.C_EventUtils and type(_G.C_EventUtils.IsEventValid) == "function" then
            if not _G.C_EventUtils.IsEventValid(eventName) then
                return
            end
        end
        frame:RegisterEvent(eventName)
    end
    for _, ev in ipairs(RUNTIME_EVENTS) do
        SafeRegisterEvent(self, ev)
    end
    for chatEvt in pairs(CHAT_EVENT_TO_SOUND_CHANNEL) do
        SafeRegisterEvent(self, chatEvt)
    end
end

DynamicChat:RegisterEvent("ADDON_LOADED")
DynamicChat:RegisterEvent("PLAYER_LOGIN")

DynamicChat:SetScript("OnEvent", function(self, event, arg1, arg2, _, _, _, _, _, _, _, _, _, arg12)
    if event == "ADDON_LOADED" then
        if (arg1 == ADDON_FOLDER or arg1 == "DynamicChat") and not isInitialized then
            isInitialized = true
            EnsureDB()
            CaptureOriginalChatStrings()
            DynamicChat._RegisterWithDynamicSuite()
            if IsModuleDisabledInSuite("DynamicChat") then
                if _G.DynamicSuite and _G.DynamicSuite.modules then
                    if _G.DynamicSuite.modules["chat"] then _G.DynamicSuite.modules["chat"]._disabledAtStartup = true end
                    if _G.DynamicSuite.modules["DynamicChat"] then _G.DynamicSuite.modules["DynamicChat"]._disabledAtStartup = true end
                end
                self:TeardownDisabledState(false)
                return
            end
            self:RegisterRuntimeEvents()
            self:ReassertTargetWhisperSlashCommands()
            self:ApplyWhisperDefaultSoundMuteState()
            self:ApplyShortChannelNames()
            self:RegisterQuickSlashCommands()
        end
    elseif event == "PLAYER_LOGIN" then
        EnsureDB()
        DynamicChat._RegisterWithDynamicSuite()
        if IsModuleDisabledInSuite("DynamicChat") then
            if _G.DynamicSuite and _G.DynamicSuite.modules then
                if _G.DynamicSuite.modules["chat"] then _G.DynamicSuite.modules["chat"]._disabledAtStartup = true end
                if _G.DynamicSuite.modules["DynamicChat"] then _G.DynamicSuite.modules["DynamicChat"]._disabledAtStartup = true end
            end
            self:TeardownDisabledState(false)
            return
        end
        self:RegisterRuntimeEvents()
        PreRegisterDynamicChatSpecialFrames()
        self:ScanExternalSounds(true)
        self:ApplyAllEngineSettings()
        if _G.C_Timer and type(_G.C_Timer.After) == "function" then
            _G.C_Timer.After(0.15, function()
                if not IsModuleDisabledInSuite("DynamicChat") then
                    self:ReassertTargetWhisperSlashCommands()
                    self:ApplyWhisperDefaultSoundMuteState()
                end
            end)
            _G.C_Timer.After(1.5, function()
                if not IsModuleDisabledInSuite("DynamicChat") then
                    self:ScanExternalSounds(true)
                    if self.configPanel and self.configPanel:IsShown() then
                        self:RefreshConfigUI()
                    end
                end
            end)
        end
    elseif IsModuleDisabledInSuite("DynamicChat") then
        self:TeardownDisabledState(false)
        return
    elseif event == "PLAYER_LOGOUT" then
        self:SaveChatHistorySnapshot()
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:ReassertTargetWhisperSlashCommands()
        self:ApplyWhisperDefaultSoundMuteState()
        self:ApplySleekChatSkin()
        self:ApplySavedChatFramePosition()
        self:ApplySleekChatSkin()
        self:ApplyEditBoxSettings()
        self:ApplyStickyChannelSettings()
        self:ApplyGPUBufferSettings()
        if _G.C_Timer and type(_G.C_Timer.After) == "function" then
            _G.C_Timer.After(0.0, function()
                if not IsModuleDisabledInSuite("DynamicChat") then
                    self:ApplySavedChatFramePosition()
                    self:ApplySleekChatSkin()
                end
            end)
            _G.C_Timer.After(0.15, function()
                if not IsModuleDisabledInSuite("DynamicChat") then
                    self:ApplySavedChatFramePosition()
                    self:ApplySleekChatSkin()
                    self:RestoreChatHistorySnapshot()
                end
            end)
            _G.C_Timer.After(0.50, function()
                if not IsModuleDisabledInSuite("DynamicChat") then
                    self:ApplySavedChatFramePosition()
                    self:ApplySleekChatSkin()
                end
            end)
        else
            self:RestoreChatHistorySnapshot()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        self:RefreshLeftRailTelemetry()
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:ApplyGPUBufferSettings()
        self:RefreshLeftRailTelemetry()
        if self._pendingChatPosAfterCombat then
            self._pendingChatPosAfterCombat = false
            self:ApplySavedChatFramePosition()
            self:ApplySleekChatSkin()
        end
        if self._pendingTabLayoutAfterCombat then
            self._pendingTabLayoutAfterCombat = false
            if not self:IsExternalChatEngineLoaded() and EnsureDB().enableSleekChatSkin ~= false then
                local a1, a2, a3 = GetSuiteAccent()
                LayoutDockedChatTabs(true, EnsureDB().applySuiteChatFont ~= false, GetFontPath(), a1, a2, a3)
            end
        end
    elseif event == "FRIENDLIST_UPDATE"
        or event == "BN_FRIEND_INFO_CHANGED"
        or event == "GUILD_ROSTER_UPDATE"
        or event == "UPDATE_INVENTORY_DURABILITY"
        or event == "WEEKLY_REWARDS_UPDATE" then
        if event == "UPDATE_INVENTORY_DURABILITY" and (InCombatLockdown and InCombatLockdown()) then
            return
        end
        self:RefreshLeftRailTelemetry()
        if event == "BN_FRIEND_INFO_CHANGED" and not self:IsExternalChatEngineLoaded() and EnsureDB().enableSleekChatSkin ~= false then
            local a1, a2, a3 = GetSuiteAccent()
            LayoutDockedChatTabs(true, EnsureDB().applySuiteChatFont ~= false, GetFontPath(), a1, a2, a3)
        end
    elseif event == "UPDATE_CHAT_WINDOWS"
        or event == "UPDATE_FLOATING_CHAT_WINDOWS"
        or event == "DISPLAY_SIZE_CHANGED"
        or event == "UI_SCALE_CHANGED"
        or event == "EDIT_MODE_LAYOUTS_UPDATED" then
        self:ApplySleekChatSkin()
        self:ApplySavedChatFramePosition()
        self:ApplySleekChatSkin()
        if _G.C_Timer and type(_G.C_Timer.After) == "function" then
            _G.C_Timer.After(0.0, function()
                if not IsModuleDisabledInSuite("DynamicChat") then
                    self:ApplySavedChatFramePosition()
                    self:ApplySleekChatSkin()
                end
            end)
            _G.C_Timer.After(0.15, function()
                if not IsModuleDisabledInSuite("DynamicChat") then
                    self:ApplySavedChatFramePosition()
                    self:ApplySleekChatSkin()
                end
            end)
            _G.C_Timer.After(0.50, function()
                if not IsModuleDisabledInSuite("DynamicChat") then
                    self:ApplySavedChatFramePosition()
                    self:ApplySleekChatSkin()
                end
            end)
        end
    elseif CHAT_EVENT_TO_SOUND_CHANNEL[event] then
        self:HandleIncomingChatSoundEvent(event, arg2, arg12, arg1)
    end
end)
