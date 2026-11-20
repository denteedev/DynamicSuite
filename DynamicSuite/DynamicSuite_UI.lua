--[[
    DynamicSuite - DynamicSuite_UI.lua
    Obsidian Core Design System for DynamicSuite (v1.4.0)
    980x680 Resizable Window, C++ Two-Point Anchor Stretching (Zero OnUpdate Resize Lag),
    Clean 3-Zone Top Header, Left Suite Rail (DYNAMIC MODULES + SUITE STUDIO & TOOLS),
    Theme & Font Studio, External Addon Conflict Detector & Auto-Yield Engine, Guided Setup, and HUD Edit Mode.
    Zero external dependencies. Pure Blizzard Retail API 12.1.5+ precision.
]]

local addonName, rawAddonTable = ...
local ADDON_FOLDER = (type(addonName) == "string" and addonName ~= "") and addonName or "DynamicSuite"
_G.DynamicSuite = _G.DynamicSuite or {}
_G.DynamicSuite.HasUnifiedModuleConflictBanner = true
_G.DynamicSuite._sharedAddonTable = _G.DynamicSuite._sharedAddonTable or rawAddonTable or {}
local addonTable = _G.DynamicSuite._sharedAddonTable
local DynamicSuite = _G.DynamicSuite

local CONTEXT_TABS = {
    { key = "outdoor", label = "Outdoor" },
    { key = "delve",   label = "Delves" },
    { key = "dungeon", label = "Dungeons" },
    { key = "raid",    label = "Raid" },
    { key = "pvp",     label = "PvP" },
}
local STANDALONE_FRAME_NAMES = { "DynamicFPSMainFrame", "DynamicFPSStandaloneFrame", "DynamicFrameMainFrame", "DynamicZoomStandaloneFrame", "DynamicMarkerMainFrame", "DynamicPrepMainFrame", "DynamicGroupMainFrame", "DynamicBagsStandaloneFrame", "DynamicChatStandaloneFrame", "DynamicMailStandaloneWindow", "DynamicVaultStandaloneFrame", "DynamicDialogueStandaloneFrame" }

local selectedTabKey = "outdoor"
local selectedAltKey = nil
local searchFilter = ""
local securityFilter = "ALL" -- "ALL", "CORE", "FROZEN"
local activeWorkspaceView = "DYNAMICLOAD" -- "DYNAMICLOAD", "PEER_MODULE", "THEME_STUDIO", "GUIDED_SETUP", "EDIT_MODE"
local selectedPeerModuleKey = nil
local isToastSubTabActive = false

local mainFrame = nil
local contextMenuFrame = nil
local altDropdownFrame = nil
local clickCatcher = nil
local supportDialog = nil
local changelogDialog = nil
local dsColorPicker = nil
local collapsedParents = {}

--------------------------------------------------------------------------------
-- OBSIDIAN CORE THEME, SURFACE & FONT ENGINE
--------------------------------------------------------------------------------
local UI = {}
addonTable.UI = UI

function UI.FormatTooltipCommand(cmdText, actionText, cmdHex)
    local hex = (type(cmdHex) == "string" and cmdHex:gsub("^|cFF", ""):gsub("^|c", ""):gsub("^#", "")) or "34D399"
    if #hex == 8 then hex = hex:sub(3, 8) end
    if #hex ~= 6 then hex = "34D399" end
    local cmd = tostring(cmdText or "")
    if cmd ~= "" and not cmd:match(":$") then
        cmd = cmd .. ":"
    end
    return string.format("|cFF%s%s|r |cFFE2E8F0%s|r", hex:upper(), cmd, tostring(actionText or ""))
end
_G.DynamicSuite = _G.DynamicSuite or {}
_G.DynamicSuite.FormatTooltipCommand = UI.FormatTooltipCommand

-- 17 Unique Non-Repeating Accent Swatches (4 Secondary Brand Presets + 13 WoW Class Colors per DESIGN_SYSTEM.md Section 1.2)
local ACCENT_PRESETS = {
    { key = "ALERT_GOLD",     name = "Alert Gold",               r = 0.961, g = 0.722, b = 0.180, hex = "F5B82E" },
    { key = "ASTRAL_COBALT",  name = "Astral Cobalt",            r = 0.376, g = 0.647, b = 0.980, hex = "60A5FA" },
    { key = "EMERALD_MINT",   name = "Emerald Mint",             r = 0.063, g = 0.725, b = 0.506, hex = "10B981" },
    { key = "OBSIDIAN_SLATE", name = "Obsidian Slate",           r = 0.796, g = 0.835, b = 0.882, hex = "CBD5E1" },
    { key = "DEATHKNIGHT",    name = "Death Knight Red",         r = 0.77,  g = 0.12,  b = 0.23,  hex = "C41E3A" },
    { key = "DEMONHUNTER",    name = "Demon Hunter Magenta",     r = 0.64,  g = 0.19,  b = 0.79,  hex = "A330C9" },
    { key = "DRUID",          name = "Druid Orange",             r = 1.00,  g = 0.49,  b = 0.04,  hex = "FF7C0A" },
    { key = "EVOKER",         name = "Evoker Emerald",           r = 0.20,  g = 0.58,  b = 0.50,  hex = "33937F" },
    { key = "HUNTER",         name = "Hunter Green",             r = 0.67,  g = 0.83,  b = 0.45,  hex = "ABD473" },
    { key = "MAGE",           name = "Mage Light Blue",          r = 0.25,  g = 0.78,  b = 0.92,  hex = "3FC7EB" },
    { key = "MONK",           name = "Monk Jade",                r = 0.00,  g = 1.00,  b = 0.60,  hex = "00FF98" },
    { key = "PALADIN",        name = "Paladin Pink",             r = 0.96,  g = 0.55,  b = 0.73,  hex = "F58CBA" },
    { key = "PRIEST",         name = "Priest White",             r = 1.00,  g = 1.00,  b = 1.00,  hex = "FFFFFF" },
    { key = "ROGUE",          name = "Rogue Yellow",             r = 1.00,  g = 0.96,  b = 0.41,  hex = "FFF569" },
    { key = "SHAMAN",         name = "Shaman Blue",              r = 0.00,  g = 0.44,  b = 0.87,  hex = "0070DE" },
    { key = "WARLOCK",        name = "Warlock Purple",           r = 0.53,  g = 0.53,  b = 0.93,  hex = "8788EE" },
    { key = "WARRIOR",        name = "Warrior Tan",              r = 0.78,  g = 0.61,  b = 0.43,  hex = "C79C6E" },
}
UI.ACCENT_PRESETS = ACCENT_PRESETS

local SURFACE_THEMES = {
    ["MIDNIGHT_BLACK"] = {
        name   = "Midnight Pitch Black (Default)",
        header = { r = 0.015, g = 0.018, b = 0.024, a = 1.00 }, -- #040506
        rail   = { r = 0.024, g = 0.027, b = 0.035, a = 1.00 }, -- #060709
        panel  = { r = 0.035, g = 0.039, b = 0.051, a = 0.99 }, -- #090A0D
        card   = { r = 0.055, g = 0.063, b = 0.082, a = 0.96 }, -- #0E1015
    },
    ["OBSIDIAN_DARK"] = {
        name   = "Obsidian Dark",
        header = { r = 0.035, g = 0.039, b = 0.051, a = 1.00 }, -- #090A0D
        rail   = { r = 0.047, g = 0.055, b = 0.071, a = 0.99 }, -- #0C0E12
        panel  = { r = 0.067, g = 0.075, b = 0.094, a = 0.98 }, -- #111318
        card   = { r = 0.090, g = 0.102, b = 0.129, a = 0.95 }, -- #171A21
    },
    ["SLATE_STEEL"] = {
        name   = "Slate Steel",
        header = { r = 0.055, g = 0.067, b = 0.090, a = 1.00 },
        rail   = { r = 0.071, g = 0.086, b = 0.114, a = 0.99 },
        panel  = { r = 0.090, g = 0.106, b = 0.141, a = 0.98 },
        card   = { r = 0.118, g = 0.137, b = 0.180, a = 0.96 },
    },
    ["SMOKED_GLASS"] = {
        name   = "Smoked Glass",
        header = { r = 0.045, g = 0.055, b = 0.075, a = 0.92 },
        rail   = { r = 0.055, g = 0.067, b = 0.090, a = 0.88 },
        panel  = { r = 0.075, g = 0.090, b = 0.118, a = 0.86 },
        card   = { r = 0.102, g = 0.122, b = 0.157, a = 0.84 },
    },
}
UI.SURFACE_THEMES = SURFACE_THEMES

local FONT_FAMILY_ORDER = {
    { key = "EXPRESSWAY",       label = "Expressway" },
    { key = "EXPRESSWAY_BOLD",  label = "Expressway Bold" },
    { key = "EXPRESSWAY_CAPS",  label = "Expressway CAPS" },
    { key = "POPPINS",          label = "Poppins" },
    { key = "AVANT_GARDE",      label = "Avant Garde" },
    { key = "FIRA_SANS",        label = "Fira Sans" },
    { key = "FIRA_SANS_BOLD",   label = "Fira Sans Bold" },
    { key = "FIRA_SANS_LIGHT",  label = "Fira Sans Light" },
    { key = "UBUNTU",           label = "Ubuntu" },
    { key = "BARLOW_CONDENSED", label = "Barlow Condensed" },
    { key = "CHANGA",           label = "Changa" },
    { key = "RUSSO_ONE",        label = "Russo One" },
    { key = "CINZEL",           label = "Cinzel Decorative" },
    { key = "HWT_ARTZ",         label = "HWT Artz" },
    { key = "KMT_NINJA_NARUTO", label = "KMT Ninja Naruto" },
    { key = "ARIAL_NARROW",     label = "Arial Narrow" },
    { key = "ARIAL_BOLD",       label = "Arial Bold" },
    { key = "HOMESPUN",         label = "Homespun" },
    { key = "FRIZ_QUADRATA",    label = "Friz Quadrata" },
    { key = "MODERN_SANS",      label = "2002" },
    { key = "RPG_SERIF",        label = "Morpheus" },
}
UI.FONT_FAMILY_ORDER = FONT_FAMILY_ORDER

-- Complete 26-Font EllesmereUI Library (1:1 Name Matching & File Resolution)
local EUI_COMPLETE_FONT_LIBRARY = {
    { key = "EXPRESSWAY",          name = "Expressway",          file = "Expressway.ttf",          bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.TTF" },
    { key = "EXPRESSWAY_BOLD",     name = "Expressway Bold",     file = "Expressway Bold.ttf",     bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway Bold.ttf" },
    { key = "EXPRESSWAY_CAPS",     name = "Expressway CAPS",     file = "Expressway CAPS.ttf",     bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway CAPS.ttf" },
    { key = "POPPINS",             name = "Poppins",             file = "Poppins.ttf",             bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Poppins.ttf" },
    { key = "AVANT_GARDE",         name = "Avant Garde",         file = "Avant Garde.ttf",         bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Avant Garde Naowh.ttf" },
    { key = "EXO",                 name = "Exo",                 file = "Exo.ttf" },
    { key = "FIRA_SANS",           name = "Fira Sans",           file = "FiraSans Medium.ttf",     bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Medium.ttf" },
    { key = "FIRA_SANS_BOLD",      name = "Fira Sans Bold",      file = "FiraSans Bold.ttf",       bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Bold.ttf" },
    { key = "FIRA_SANS_LIGHT",     name = "Fira Sans Light",     file = "FiraSans Light.ttf",      bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Light.ttf" },
    { key = "UBUNTU",              name = "Ubuntu",              file = "Ubuntu.ttf",              bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Ubuntu.ttf" },
    { key = "BARLOW_CONDENSED",    name = "Barlow Condensed",    file = "Barlow Condensed.ttf",    bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Barlow Condensed.ttf" },
    { key = "CHANGA",              name = "Changa",              file = "Changa.ttf",              bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Changa.ttf" },
    { key = "RUSSO_ONE",           name = "Russo One",           file = "Russo One.ttf",           bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Russo One.ttf" },
    { key = "CINZEL",              name = "Cinzel Decorative",   file = "Cinzel Decorative.ttf",   bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Cinzel Decorative.ttf" },
    { key = "FUTURE_X_BLACK",      name = "Future X Black",      file = "Future X Black.ttf" },
    { key = "GOTHAM_NARROW_ULTRA", name = "Gotham Narrow Ultra", file = "Gotham Narrow Ultra.ttf" },
    { key = "GOTHAM_NARROW",       name = "Gotham Narrow",       file = "Gotham Narrow.ttf" },
    { key = "HWT_ARTZ",            name = "HWT Artz",            file = "HWT Artz.ttf",            bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\HWT Artz.ttf" },
    { key = "KMT_KIMBERLEY",       name = "KMT Kimberley",       file = "KMT Kimberley.ttf" },
    { key = "KMT_NINJA_NARUTO",    name = "KMT Ninja Naruto",    file = "KMT Ninja Naruto.ttf",    bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\KMT Ninja Naruto.ttf" },
    { key = "ARIAL_NARROW",        name = "Arial Narrow",        file = "Arial Narrow.ttf",        bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Arial Narrow.ttf" },
    { key = "ARIAL_BOLD",          name = "Arial Bold",          file = "Arial Bold.ttf",          bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Arial Bold.ttf" },
    { key = "HOMESPUN",            name = "Homespun",            file = "Homespun.ttf",            bundled = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Homespun.ttf", flags = "MONOCHROME,OUTLINE", scale = 0.92 },
    { key = "FRIZ_QUADRATA",       name = "Friz Quadrata",           file = "FRIZQT__.TTF",            bundled = "Fonts\\FRIZQT__.TTF",            section = "BLIZZARD" },
    { key = "MODERN_SANS",         name = "2002",                    file = "2002.TTF",                bundled = "Fonts\\2002.TTF",                section = "BLIZZARD" },
    { key = "BLIZZ_2002B",         name = "2002 Bold",               file = "2002B.TTF",               bundled = "Fonts\\2002B.TTF",               section = "BLIZZARD", scale = 0.98 },
    { key = "BLIZZ_ARIALN",        name = "Arial Narrow (Blizzard)", file = "ARIALN.TTF",              bundled = "Fonts\\ARIALN.TTF",              section = "BLIZZARD", scale = 1.02 },
    { key = "RPG_SERIF",           name = "Morpheus",                file = "MORPHEUS.TTF",            bundled = "Fonts\\MORPHEUS.TTF",            section = "BLIZZARD", scale = 1.06 },
    { key = "BLIZZ_SKURRI",        name = "Skurri",                  file = "SKURRI.TTF",              bundled = "Fonts\\SKURRI.TTF",              section = "BLIZZARD", scale = 1.02 },
}

local FONT_FAMILIES = {
    ["EXPRESSWAY"] = {
        name = "Expressway",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.ttf", "Fonts\\2002.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.00, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.55,
    },
    ["EXPRESSWAY_BOLD"] = {
        name = "Expressway Bold",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway Bold.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway Bold.ttf", "Fonts\\2002B.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 0.98, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.60,
    },
    ["EXPRESSWAY_CAPS"] = {
        name = "Expressway CAPS",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway CAPS.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway CAPS.ttf", "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.ttf", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 0.98, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.55,
    },
    ["POPPINS"] = {
        name = "Poppins",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Poppins.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Poppins.ttf", "Fonts\\2002.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 0.98, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.50,
    },
    ["AVANT_GARDE"] = {
        name = "Avant Garde",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Avant Garde Naowh.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Avant Garde Naowh.ttf", "Fonts\\2002.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 0.98, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.55,
    },
    ["FIRA_SANS"] = {
        name = "Fira Sans",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Medium.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Medium.ttf", "Fonts\\2002.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.00, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.50,
    },
    ["FIRA_SANS_BOLD"] = {
        name = "Fira Sans Bold",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Bold.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Bold.ttf", "Fonts\\2002B.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 0.98, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.60,
    },
    ["FIRA_SANS_LIGHT"] = {
        name = "Fira Sans Light",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Light.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\FiraSans Light.ttf", "Fonts\\2002.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.02, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.45,
    },
    ["UBUNTU"] = {
        name = "Ubuntu",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Ubuntu.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Ubuntu.ttf", "Fonts\\2002.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.00, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.50,
    },
    ["BARLOW_CONDENSED"] = {
        name = "Barlow Condensed",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Barlow Condensed.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Barlow Condensed.ttf", "Fonts\\ARIALN.TTF", "Fonts\\2002.TTF" },
        sizeScale = 1.06, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.45,
    },
    ["CHANGA"] = {
        name = "Changa",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Changa.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Changa.ttf", "Fonts\\2002.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.00, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.50,
    },
    ["RUSSO_ONE"] = {
        name = "Russo One",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Russo One.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Russo One.ttf", "Fonts\\2002B.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 0.95, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.60,
    },
    ["CINZEL"] = {
        name = "Cinzel Decorative",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Cinzel Decorative.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Cinzel Decorative.ttf", "Fonts\\MORPHEUS.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.02, defaultFlags = "", shadowOff = 1.3, shadowAlpha = 0.80,
    },
    ["HWT_ARTZ"] = {
        name = "HWT Artz",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\HWT Artz.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\HWT Artz.ttf", "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway Bold.ttf", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.02, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.55,
    },
    ["KMT_NINJA_NARUTO"] = {
        name = "KMT Ninja Naruto",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\KMT Ninja Naruto.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\KMT Ninja Naruto.ttf", "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway Bold.ttf", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 0.96, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.55,
    },
    ["ARIAL_NARROW"] = {
        name = "Arial Narrow",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Arial Narrow.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Arial Narrow.ttf", "Fonts\\ARIALN.TTF", "Fonts\\2002.TTF" },
        sizeScale = 1.02, defaultFlags = "", shadowOff = 0.9, shadowAlpha = 0.45,
    },
    ["ARIAL_BOLD"] = {
        name = "Arial Bold",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Arial Bold.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Arial Bold.ttf", "Fonts\\2002B.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 0.96, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.55,
    },
    ["HOMESPUN"] = {
        name = "Homespun",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Homespun.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Homespun.ttf", "Fonts\\ARIALN.TTF", "Fonts\\2002.TTF" },
        sizeScale = 0.92, defaultFlags = "MONOCHROME,OUTLINE", shadowOff = 0, shadowAlpha = 0,
    },
    ["FRIZ_QUADRATA"] = {
        name = "Friz Quadrata",
        path = "Fonts\\FRIZQT__.TTF",
        candidates = { "Fonts\\FRIZQT__.TTF", "Fonts\\2002.TTF" },
        sizeScale = 1.00, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.55,
    },
    ["MODERN_SANS"] = {
        name = "2002",
        path = "Fonts\\2002.TTF",
        candidates = { "Fonts\\2002.TTF", "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.ttf", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.00, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.45,
    },
    ["RPG_SERIF"] = {
        name = "Morpheus",
        path = "Fonts\\MORPHEUS.TTF",
        candidates = { "Fonts\\MORPHEUS.TTF", "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Cinzel Decorative.ttf", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.06, defaultFlags = "", shadowOff = 1.4, shadowAlpha = 0.85,
    },
    ["BLIZZ_2002B"] = {
        name = "2002 Bold",
        path = "Fonts\\2002B.TTF",
        candidates = { "Fonts\\2002B.TTF", "Fonts\\2002.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 0.98, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.55,
    },
    ["BLIZZ_ARIALN"] = {
        name = "Arial Narrow (Blizzard)",
        path = "Fonts\\ARIALN.TTF",
        candidates = { "Fonts\\ARIALN.TTF", "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Arial Narrow.ttf", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.02, defaultFlags = "", shadowOff = 0.9, shadowAlpha = 0.45,
    },
    ["BLIZZ_SKURRI"] = {
        name = "Skurri",
        path = "Fonts\\SKURRI.TTF",
        candidates = { "Fonts\\SKURRI.TTF", "Fonts\\FRIZQT__.TTF" },
        sizeScale = 1.02, defaultFlags = "", shadowOff = 1.2, shadowAlpha = 0.70,
    },
    ["COMPACT_NARROW"] = {
        name = "Arial Narrow",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Arial Narrow.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Arial Narrow.ttf", "Fonts\\ARIALN.TTF", "Fonts\\2002.TTF" },
        sizeScale = 1.00, defaultFlags = "", shadowOff = 0.8, shadowAlpha = 0.35,
    },
    ["CLEAN_TECHNICAL"] = {
        name = "Russo One",
        path = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Russo One.ttf",
        candidates = { "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Russo One.ttf", "Fonts\\2002B.TTF", "Fonts\\ARHei.TTF" },
        sizeScale = 0.95, defaultFlags = "", shadowOff = 1, shadowAlpha = 0.55,
    },
}
UI.FONT_FAMILIES = FONT_FAMILIES

-- Register bundled DynamicSuite fonts with LibSharedMedia-3.0 if present
do
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM.Register then
        for _, item in ipairs(FONT_FAMILY_ORDER) do
            local entry = FONT_FAMILIES[item.key]
            if entry and entry.path then
                pcall(LSM.Register, LSM, "font", item.label, entry.path)
            end
        end
    end
end

UI.COLORS = {
    HEADER_BG    = { r = 0.015, g = 0.018, b = 0.024, a = 1.00 }, -- #040506 (MIDNIGHT_BLACK default)
    RAIL_BG      = { r = 0.024, g = 0.027, b = 0.035, a = 1.00 }, -- #060709
    PANEL_BG     = { r = 0.035, g = 0.039, b = 0.051, a = 0.99 }, -- #090A0D
    CARD_BG      = { r = 0.055, g = 0.063, b = 0.082, a = 0.96 }, -- #0E1015
    CELL_BG      = { r = 0.078, g = 0.090, b = 0.122, a = 0.96 }, -- #14171F Neutral Interactive Cell
    CELL_BORDER  = { r = 0.145, g = 0.165, b = 0.212, a = 0.95 }, -- #252A36 Neutral Cell Border
    BORDER       = { r = 1.00,  g = 1.00,  b = 1.00,  a = 0.07 },
    BORDER_OUTER = { r = 1.00,  g = 1.00,  b = 1.00,  a = 0.15 },
    ACCENT       = { r = 0.796, g = 0.835, b = 0.882, a = 1.00 }, -- Updated dynamically
    GOLD         = { r = 0.961, g = 0.722, b = 0.180, a = 1.00 }, -- #F5B82E (ALWAYS ON / CORE / WARNING)
    CYAN         = { r = 0.220, g = 0.741, b = 0.973, a = 1.00 }, -- #38BDF8 (NEVER LOAD / FROZEN)
    EMERALD      = { r = 0.133, g = 0.773, b = 0.369, a = 1.00 }, -- #22C55E (LIVE / READY / ZERO CONFLICTS)
    CRIMSON      = { r = 0.937, g = 0.267, b = 0.267, a = 1.00 }, -- #EF4444 (DISABLED / HIDDEN / DANGER)
    ROW_ODD      = { r = 1.00,  g = 1.00,  b = 1.00,  a = 0.025 },
    ROW_EVEN     = { r = 0.00,  g = 0.00,  b = 0.00,  a = 0.18 },
    ROW_HOVER    = { r = 1.00,  g = 1.00,  b = 1.00,  a = 0.065 },
    TEXT_TITLE   = { r = 0.97,  g = 0.98,  b = 1.00,  a = 0.98 },
    TEXT_DIM     = { r = 0.58,  g = 0.64,  b = 0.72,  a = 1.00 },
    BTN_BG       = { r = 0.078, g = 0.090, b = 0.122, a = 0.96 }, -- Matches CELL_BG (#14171F)
    BTN_HOVER    = { r = 0.135, g = 0.153, b = 0.192, a = 1.00 },
    BTN_BORDER   = { r = 0.145, g = 0.165, b = 0.212, a = 0.95 }, -- Matches CELL_BORDER (#252A36)
}
if _G.DynamicSuite then
    _G.DynamicSuite.UI = _G.DynamicSuite.UI or {}
    _G.DynamicSuite.UI.COLORS = UI.COLORS
end

function UI.GetActiveAccentColor()
    local g = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
    local key = g.accentKey or "AUTO_CLASS"
    if key == "CUSTOM" and g.customAccent then
        local r = g.customAccent.r or 0.796
        local gCol = g.customAccent.g or 0.835
        local b = g.customAccent.b or 0.882
        local hex = string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(gCol * 255 + 0.5), math.floor(b * 255 + 0.5))
        return r, gCol, b, hex
    elseif key == "AUTO_CLASS" then
        local _, classFile = UnitClass("player")
        local cc = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
        if cc then
            local hex = cc.colorStr or string.format("%02X%02X%02X", math.floor(cc.r * 255 + 0.5), math.floor(cc.g * 255 + 0.5), math.floor(cc.b * 255 + 0.5))
            hex = hex:gsub("^|c", ""):gsub("^#", "")
            if #hex == 8 then hex = hex:sub(3, 8) end
            return cc.r, cc.g, cc.b, hex:upper()
        end
    end
    for _, p in ipairs(ACCENT_PRESETS) do
        if p.key == key then
            return p.r, p.g, p.b, p.hex
        end
    end
    local _, classFile = UnitClass("player")
    local cc = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
    if cc then
        local hex = cc.colorStr or string.format("%02X%02X%02X", math.floor(cc.r * 255 + 0.5), math.floor(cc.g * 255 + 0.5), math.floor(cc.b * 255 + 0.5))
        hex = hex:gsub("^|c", ""):gsub("^#", "")
        if #hex == 8 then hex = hex:sub(3, 8) end
        return cc.r, cc.g, cc.b, hex:upper()
    end
    return 0.796, 0.835, 0.882, "CBD5E1"
end

function UI.GetActiveSurfaceKey()
    local g = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
    local key = g.surfaceTheme
    if not key or not SURFACE_THEMES[key] then
        key = "MIDNIGHT_BLACK"
        g.surfaceTheme = key
    end
    return key
end

function UI.GetActiveSurfaceColors()
    local key = UI.GetActiveSurfaceKey()
    return SURFACE_THEMES[key] or SURFACE_THEMES["MIDNIGHT_BLACK"]
end

function UI.RefreshPaletteCache()
    local ar, ag, ab = UI.GetActiveAccentColor()
    UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b = ar, ag, ab

    local surf = UI.GetActiveSurfaceColors()
    UI.COLORS.HEADER_BG = surf.header
    UI.COLORS.RAIL_BG   = surf.rail
    UI.COLORS.PANEL_BG  = surf.panel
    UI.COLORS.CARD_BG   = surf.card
end

local fontProbeFS = nil
local resolvedFontPaths = {}

local fontProbeCache = {}
local function CanSetFontPath(path)
    if not path or type(path) ~= "string" or path == "" then return false end
    if fontProbeCache[path] ~= nil then return fontProbeCache[path] end
    if not fontProbeFS then
        fontProbeFS = UIParent:CreateFontString(nil, "BACKGROUND")
        fontProbeFS:Hide()
    end
    local ok, applied = pcall(fontProbeFS.SetFont, fontProbeFS, path, 12, "")
    local fetched = ok and fontProbeFS:GetFont() or nil
    local valid = (ok and applied ~= false and fetched ~= nil)
    fontProbeCache[path] = valid
    return valid
end

local function NormalizeFontKey(rawName)
    return tostring(rawName or "EXPRESSWAY"):upper():gsub("[^A-Z0-9]+", "_"):gsub("^_+", ""):gsub("_+$", "")
end

local FONT_SECTION_BUCKETS = { builtin = {}, blizzard = {}, external = {} }
local function NormFontPath(p)
    return tostring(p or ""):lower():gsub("/", "\\")
end

function UI.SyncEllesmereUIFontLibrary(forceExternalScan)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local eui = _G.EllesmereUI
    local hasEUI = (type(eui) == "table") or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("EllesmereUI"))
    local euiMediaBase = (eui and type(eui.MEDIA_PATH) == "string" and eui.MEDIA_PATH ~= "" and eui.MEDIA_PATH) or "Interface\\AddOns\\EllesmereUI\\media\\"
    if not euiMediaBase:match("[\\/]$") then
        euiMediaBase = euiMediaBase .. "\\"
    end

    local euiKnownByKey = {}
    local euiKnownByName = {}
    for _, def in ipairs(EUI_COMPLETE_FONT_LIBRARY) do
        euiKnownByKey[def.key] = def
        euiKnownByName[def.name:lower()] = def
    end

    local builtinItems = {}
    local blizzardItems = {}
    local externalItems = {}
    local activeOrder = {}
    local seenKeys = {}
    local seenPaths = {}
    local seenNames = {}

    local function RegisterOrUpdateFontEntry(fKey, fName, fFile, bundledPath, scale, flags, sectionTag, sourceTag)
        local cands = {}
        if LSM and LSM.Fetch then
            local ok, lsmPath = pcall(LSM.Fetch, LSM, "font", fName, true)
            if ok and type(lsmPath) == "string" and lsmPath ~= "" then
                table.insert(cands, lsmPath)
            end
        end
        if eui then
            if type(eui.FONTS) == "table" and eui.FONTS[fName] then
                local eVal = eui.FONTS[fName]
                local fileOrPath = (type(eVal) == "table" and (eVal.path or eVal.file)) or (type(eVal) == "string" and eVal) or nil
                if fileOrPath then
                    if fileOrPath:find("[\\/]") then
                        table.insert(cands, fileOrPath)
                    else
                        table.insert(cands, euiMediaBase .. "fonts\\" .. fileOrPath)
                    end
                end
            end
            if type(eui.FONT_PATHS) == "table" and type(eui.FONT_PATHS[fName]) == "string" then
                table.insert(cands, eui.FONT_PATHS[fName])
            end
        end
        if fFile then
            if fFile:find("[\\/]") then
                table.insert(cands, fFile)
            else
                table.insert(cands, euiMediaBase .. "fonts\\" .. fFile)
                table.insert(cands, "Interface\\AddOns\\EllesmereUI\\media\\fonts\\" .. fFile)
                table.insert(cands, "Interface\\AddOns\\EllesmereUI\\Media\\Fonts\\" .. fFile)
                table.insert(cands, "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\" .. fFile)
            end
        end
        if bundledPath then
            table.insert(cands, bundledPath)
        end
        table.insert(cands, "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.ttf")
        table.insert(cands, "Fonts\\FRIZQT__.TTF")

        local existing = FONT_FAMILIES[fKey]
        local primaryPath = cands[1] or (existing and existing.path) or bundledPath or "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.ttf"
        FONT_FAMILIES[fKey] = {
            name = fName,
            path = primaryPath,
            candidates = cands,
            sizeScale = scale or (existing and existing.sizeScale) or 1.00,
            defaultFlags = flags or (existing and existing.defaultFlags) or "",
            shadowOff = (existing and existing.shadowOff) or 1,
            shadowAlpha = (existing and existing.shadowAlpha) or 0.55,
            section = sectionTag,
            source = sourceTag,
        }

        local chosen = nil
        local validFound = false
        for _, cand in ipairs(cands) do
            if CanSetFontPath(cand) then
                chosen = cand
                validFound = true
                break
            end
        end
        chosen = chosen or primaryPath
        resolvedFontPaths[fKey] = chosen
        FONT_FAMILIES[fKey].resolvedPath = chosen
        FONT_FAMILIES[fKey].validOnDisk = validFound
        return chosen, validFound
    end

    if hasEUI and eui and type(eui.FONT_ORDER) == "table" and #eui.FONT_ORDER > 0 then
        for _, rawItem in ipairs(eui.FONT_ORDER) do
            local fName = (type(rawItem) == "table" and (rawItem.name or rawItem.label or rawItem[1])) or (type(rawItem) == "string" and rawItem) or nil
            local fFile = (type(rawItem) == "table" and (rawItem.file or rawItem.path or rawItem[2])) or nil
            if fName and fName ~= "" then
                local known = euiKnownByName[fName:lower()]
                local fKey = (known and known.key) or NormalizeFontKey(fName)
                local sec = (known and known.section) or "BUILTIN"
                if not seenKeys[fKey] then
                    seenKeys[fKey] = true
                    local chosen = RegisterOrUpdateFontEntry(
                        fKey,
                        fName,
                        fFile or (known and known.file),
                        known and known.bundled,
                        known and known.scale,
                        known and known.flags,
                        sec,
                        "Built-in"
                    )
                    local item = { key = fKey, label = fName, section = sec }
                    if sec == "BLIZZARD" then
                        table.insert(blizzardItems, item)
                    else
                        table.insert(builtinItems, item)
                    end
                    seenNames[fName:lower()] = true
                    if chosen then seenPaths[NormFontPath(chosen)] = true end
                end
            end
        end
    end

    for _, def in ipairs(EUI_COMPLETE_FONT_LIBRARY) do
        if not seenKeys[def.key] then
            local canInclude = hasEUI or (def.bundled ~= nil)
            if def.section == "BLIZZARD" then
                canInclude = CanSetFontPath(def.bundled or def.file)
            elseif not canInclude and LSM and LSM.Fetch then
                local ok, fetched = pcall(LSM.Fetch, LSM, "font", def.name, true)
                if ok and type(fetched) == "string" and fetched ~= "" and CanSetFontPath(fetched) then
                    canInclude = true
                end
            end
            if canInclude then
                seenKeys[def.key] = true
                local sec = def.section or "BUILTIN"
                local chosen = RegisterOrUpdateFontEntry(def.key, def.name, def.file, def.bundled, def.scale, def.flags, sec, (sec == "BLIZZARD") and "Blizzard" or "Built-in")
                local item = { key = def.key, label = def.name, section = sec }
                if sec == "BLIZZARD" then
                    table.insert(blizzardItems, item)
                else
                    table.insert(builtinItems, item)
                end
                seenNames[def.name:lower()] = true
                if chosen then seenPaths[NormFontPath(chosen)] = true end
            end
        end
    end

    -- External SharedMedia-3.0, DBM, BigWigs, WeakAuras, ElvUI Fonts
    local extList = {}
    local sharedCore = _G.DynamicSuite
    if sharedCore and type(sharedCore.GetSharedFonts) == "function" then
        local fReg = sharedCore:GetSharedFonts(forceExternalScan and true or false)
        if fReg and type(fReg.external) == "table" then
            extList = fReg.external
        end
    elseif LSM and type(LSM.HashTable) == "function" then
        local okH, hTbl = pcall(LSM.HashTable, LSM, "font")
        if okH and type(hTbl) == "table" then
            for fName, fPath in pairs(hTbl) do
                if type(fName) == "string" and type(fPath) == "string" and fPath ~= "" then
                    table.insert(extList, {
                        value = "LSM:" .. fName,
                        name = fName,
                        label = fName .. " (SharedMedia)",
                        path = fPath,
                        source = "SharedMedia",
                    })
                end
            end
            table.sort(extList, function(a, b) return a.name:lower() < b.name:lower() end)
        end
    end

    for _, ext in ipairs(extList) do
        local eKey = ext.value
        local ePath = ext.path
        local eName = ext.name or ext.label or eKey
        if type(eKey) == "string" and type(ePath) == "string" and ePath ~= "" and CanSetFontPath(ePath) then
            local normP = NormFontPath(ePath)
            local normN = tostring(eName):lower()
            if not seenKeys[eKey] and not seenPaths[normP] and not seenNames[normN] then
                seenKeys[eKey] = true
                seenPaths[normP] = true
                seenNames[normN] = true
                FONT_FAMILIES[eKey] = {
                    name = eName,
                    label = ext.label or eName,
                    path = ePath,
                    candidates = { ePath, "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.ttf", "Fonts\\FRIZQT__.TTF" },
                    resolvedPath = ePath,
                    validOnDisk = true,
                    sizeScale = 1.00,
                    defaultFlags = "",
                    shadowOff = 1,
                    shadowAlpha = 0.55,
                    isExternal = true,
                    section = "EXTERNAL",
                    source = ext.source or "SharedMedia",
                }
                resolvedFontPaths[eKey] = ePath
                table.insert(externalItems, {
                    key = eKey,
                    label = ext.label or eName,
                    name = eName,
                    section = "EXTERNAL",
                    source = ext.source or "SharedMedia",
                })
            end
        end
    end

    FONT_SECTION_BUCKETS = {
        builtin = builtinItems,
        blizzard = blizzardItems,
        external = externalItems,
    }
    for _, item in ipairs(builtinItems) do table.insert(activeOrder, item) end
    for _, item in ipairs(blizzardItems) do table.insert(activeOrder, item) end
    for _, item in ipairs(externalItems) do table.insert(activeOrder, item) end

    if #activeOrder > 0 then
        FONT_FAMILY_ORDER = activeOrder
        UI.FONT_FAMILY_ORDER = activeOrder
    end
    return FONT_FAMILY_ORDER
end

function UI.BuildFontDropdownOptions(forceScan)
    UI.SyncEllesmereUIFontLibrary(forceScan)
    local opts = {}
    if #FONT_SECTION_BUCKETS.builtin > 0 then
        table.insert(opts, { isHeader = true, label = "BUILT-IN SUITE FONTS" })
        for _, fItem in ipairs(FONT_SECTION_BUCKETS.builtin) do
            table.insert(opts, { value = fItem.key, label = fItem.label, fontKey = fItem.key, section = "BUILTIN" })
        end
    end
    if #FONT_SECTION_BUCKETS.blizzard > 0 then
        table.insert(opts, { isHeader = true, label = "BLIZZARD" })
        for _, fItem in ipairs(FONT_SECTION_BUCKETS.blizzard) do
            table.insert(opts, { value = fItem.key, label = fItem.label, fontKey = fItem.key, section = "BLIZZARD" })
        end
    end
    if #FONT_SECTION_BUCKETS.external > 0 then
        table.insert(opts, { isHeader = true, label = "SHAREDMEDIA / ADDONS" })
        for _, fItem in ipairs(FONT_SECTION_BUCKETS.external) do
            table.insert(opts, { value = fItem.key, label = fItem.label, fontKey = fItem.key, section = "EXTERNAL" })
        end
    end
    return opts
end

local function IsFontKeyValidOnDisk(fKey)
    local fDef = fKey and FONT_FAMILIES[fKey]
    if not fDef then return false end
    local rp = resolvedFontPaths[fKey] or fDef.resolvedPath or fDef.path
    return CanSetFontPath(rp)
end

function UI.GetActiveFontKey()
    local g = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
    local key = g.fontKey or g.fontFamily
    if key and not IsFontKeyValidOnDisk(key) then
        UI.SyncEllesmereUIFontLibrary(false)
        if not IsFontKeyValidOnDisk(key) then
            local lowerKey = tostring(key):lower():gsub("^lsm:", ""):gsub("^dbm:", ""):gsub("^bw:", ""):gsub("^wa:", ""):gsub("^elv:", "")
            for fKey, fDef in pairs(FONT_FAMILIES) do
                if (fDef.name == key or fKey == key or (fDef.name and fDef.name:lower() == lowerKey)) and IsFontKeyValidOnDisk(fKey) then
                    key = fKey
                    break
                end
            end
        end
        if not IsFontKeyValidOnDisk(key) then
            for fKey, fDef in pairs(FONT_FAMILIES) do
                if fDef.name and string.find(string.lower(fDef.name), tostring(key):lower(), 1, true) and IsFontKeyValidOnDisk(fKey) then
                    key = fKey
                    break
                end
            end
        end
    end
    if not key or not IsFontKeyValidOnDisk(key) then
        -- Preserve external SavedVariables key if addons have not finished loading yet, while falling back cleanly at runtime
        if not g.fontKey and not g.fontFamily then
            g.fontFamily = "EXPRESSWAY"
            g.fontKey = "EXPRESSWAY"
        end
        return "EXPRESSWAY"
    end
    return key
end

local fontLibraryResolved = false
local lastAppliedFontKey = nil

local function ResolveAllFontFamilyPaths(forceSync)
    if fontLibraryResolved and not forceSync then return end
    UI.SyncEllesmereUIFontLibrary(forceSync)
    for key, entry in pairs(FONT_FAMILIES) do
        local chosen = nil
        if entry.candidates then
            for _, cand in ipairs(entry.candidates) do
                if CanSetFontPath(cand) then
                    chosen = cand
                    break
                end
            end
        end
        chosen = chosen or entry.path or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        resolvedFontPaths[key] = chosen
        entry.resolvedPath = chosen
    end
    fontLibraryResolved = true
end

function UI.GetFont(fontKeyOverride)
    local key = fontKeyOverride or UI.GetActiveFontKey()
    if not FONT_FAMILIES[key] then
        UI.SyncEllesmereUIFontLibrary(false)
    end
    if not FONT_FAMILIES[key] then key = "EXPRESSWAY" end
    if not resolvedFontPaths[key] then
        ResolveAllFontFamilyPaths(false)
    end
    local entry = FONT_FAMILIES[key] or FONT_FAMILIES["EXPRESSWAY"]
    local candidate = resolvedFontPaths[key] or (entry and entry.path)
    if CanSetFontPath(candidate) then
        return candidate, entry
    end
    local fallbackEntry = FONT_FAMILIES["EXPRESSWAY"]
    local fbPath = resolvedFontPaths["EXPRESSWAY"] or ("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.ttf")
    if not CanSetFontPath(fbPath) then
        fbPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    end
    return fbPath, fallbackEntry or entry
end

local registeredFontStrings = setmetatable({}, { __mode = "k" })

local function ApplyFontToWidget(fs, forceReflow)
    if not fs or not fs.SetFont or fs.ignoreSuiteFont then return end
    local key = fs._fixedFontKey or UI.GetActiveFontKey()
    local fontPath, entry = UI.GetFont(key)

    if not fs._dsBaseFontSize then
        local _, existingSize, existingFlags = fs:GetFont()
        fs._dsBaseFontSize = fs._dsFontSize or existingSize or 11
        fs._dsBaseFontFlags = fs._dsFontFlags or existingFlags or ""
    end

    local baseSize = fs._dsFontSize or fs._dsBaseFontSize or 11
    local scale = (entry and entry.sizeScale) or 1.0
    local finalSize = math.max(8, math.floor((baseSize * scale) + 0.5))

    local baseFlags = fs._dsFontFlags or fs._dsBaseFontFlags or ""
    local finalFlags = baseFlags
    if entry and entry.defaultFlags and entry.defaultFlags ~= "" then
        if finalFlags == "" then
            finalFlags = entry.defaultFlags
        end
    end

    if not forceReflow and fs._appliedFontPath == fontPath and fs._appliedFontSize == finalSize and fs._appliedFontFlags == finalFlags then
        return
    end
    fs._appliedFontPath = fontPath
    fs._appliedFontSize = finalSize
    fs._appliedFontFlags = finalFlags

    local ok = pcall(fs.SetFont, fs, fontPath, finalSize, finalFlags)
    if not ok or (fs.GetFont and not fs:GetFont()) then
        local fallback = (GameFontNormal and GameFontNormal:GetFont()) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        pcall(fs.SetFont, fs, fallback, finalSize, finalFlags)
    end

    if fs.SetShadowColor and fs.SetShadowOffset then
        local sAlpha = (entry and entry.shadowAlpha) or 0
        local sOff = (entry and entry.shadowOff) or 0
        if sAlpha > 0 and sOff > 0 then
            fs:SetShadowColor(0, 0, 0, sAlpha)
            fs:SetShadowOffset(sOff, -sOff)
        else
            fs:SetShadowColor(0, 0, 0, 0)
            fs:SetShadowOffset(0, 0)
        end
    end
end

function UI.SetFont(fs, size, flags, r, g, b, a)
    if not fs then return end
    fs._dsFontSize = size or 12
    fs._dsBaseFontSize = size or 12
    fs._dsFontFlags = flags or ""
    fs._dsBaseFontFlags = flags or ""
    registeredFontStrings[fs] = true

    ApplyFontToWidget(fs, false)
    if r and fs.SetTextColor then
        fs:SetTextColor(r, g or 1, b or 1, a or 1)
    end
end

function UI.ApplyFontRecursively(frame)
    if not frame then return end
    if frame.GetObjectType and frame:GetObjectType() == "EditBox" and frame.SetFont then
        registeredFontStrings[frame] = true
        ApplyFontToWidget(frame, false)
    end
    if frame.GetRegions then
        local numRegions = select("#", frame:GetRegions())
        for i = 1, numRegions do
            local reg = select(i, frame:GetRegions())
            if reg and reg.GetObjectType and reg:GetObjectType() == "FontString" then
                registeredFontStrings[reg] = true
                ApplyFontToWidget(reg, false)
            end
        end
    end
    if frame.GetChildren then
        local numChildren = select("#", frame:GetChildren())
        for i = 1, numChildren do
            local child = select(i, frame:GetChildren())
            if child then
                UI.ApplyFontRecursively(child)
            end
        end
    end
end

function UI.RefreshAllFonts(forceAll)
    ResolveAllFontFamilyPaths(forceAll)
    local curKey = UI.GetActiveFontKey()
    if not forceAll and lastAppliedFontKey == curKey then
        return
    end
    lastAppliedFontKey = curKey
    for fs in pairs(registeredFontStrings) do
        ApplyFontToWidget(fs, true)
    end
    local g = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
    if g.syncThemeToToast ~= false then
        if _G.DynamicLoadToastFrame then UI.ApplyFontRecursively(_G.DynamicLoadToastFrame) end
        if _G.DynamicPrepBarFrame then UI.ApplyFontRecursively(_G.DynamicPrepBarFrame) end
        if _G.DynamicMarkerTargetBar then UI.ApplyFontRecursively(_G.DynamicMarkerTargetBar) end
        if _G.DynamicMarkerFlareBar then UI.ApplyFontRecursively(_G.DynamicMarkerFlareBar) end
    end
end

function UI.DisablePixelSnap(tex)
    if not tex then return end
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
end

function UI.SolidTex(parent, layer, sublevel, r, g, b, a)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    tex:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
    UI.DisablePixelSnap(tex)
    return tex
end

function UI.CreateChevronDown(parent, point, relTo, relPoint, xOff, yOff, r, g, b, a)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(12, 12)
    holder:SetPoint(point or "RIGHT", relTo or parent, relPoint or "RIGHT", xOff or -8, yOff or 0)

    local cr, cg, cb, ca = r or 1, g or 1, b or 1, a or 0.72

    local tex = holder:CreateTexture(nil, "OVERLAY", nil, 3)
    tex:SetAllPoints()
    tex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga")
    tex:SetVertexColor(cr, cg, cb, ca)

    holder.tex = tex
    if parent then
        parent.chevronTex = tex
    end
    holder.SetColor = function(_, nr, ng, nb, na)
        tex:SetVertexColor(nr, ng, nb, na or 1)
    end
    holder.SetOpen = function(_, isOpen)
        if isOpen then
            local ar, ag, ab = UI.GetActiveAccentColor()
            tex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga")
            tex:SetVertexColor(ar, ag, ab, 1.0)
        else
            tex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga")
            tex:SetVertexColor(cr, cg, cb, ca)
        end
    end
    return holder
end

function UI.SetChevronState(btn, isOpen)
    if not btn then return end
    if btn.chevron and btn.chevron.SetOpen then
        btn.chevron:SetOpen(isOpen)
    elseif btn.chevronTex then
        if isOpen then
            local ar, ag, ab = UI.GetActiveAccentColor()
            btn.chevronTex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga")
            btn.chevronTex:SetVertexColor(ar, ag, ab, 1.0)
        else
            btn.chevronTex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga")
            btn.chevronTex:SetVertexColor(0.75, 0.80, 0.88, 0.85)
        end
    end
end

function UI.GetActiveAccentHex()
    local ar, ag, ab = UI.GetActiveAccentColor()
    local ri = math.floor(math.max(0, math.min(1, ar or 0.80)) * 255 + 0.5)
    local gi = math.floor(math.max(0, math.min(1, ag or 0.84)) * 255 + 0.5)
    local bi = math.floor(math.max(0, math.min(1, ab or 0.88)) * 255 + 0.5)
    return string.format("%02X%02X%02X", ri, gi, bi)
end

function UI.FormatTwoToneBrand(secondWord)
    local suffix = tostring(secondWord or "Suite"):gsub("^Dynamic", "")
    if suffix == "" then suffix = "Suite" end
    return string.format("|cFFF3F5F8Dynamic|r|cFF%s%s|r", UI.GetActiveAccentHex(), suffix)
end

local MODULE_ICON_PATHS = {
    ["DynamicLoad"]   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_load.tga",
    ["load"]          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_load.tga",
    ["DynamicMarker"] = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_marker.tga",
    ["marker"]        = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_marker.tga",
    ["DynamicZoom"]   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_zoom.tga",
    ["zoom"]          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_zoom.tga",
    ["DynamicFPS"]    = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_fps.tga",
    ["fps"]           = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_fps.tga",
    ["DynamicPrep"]   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_prep.tga",
    ["prep"]          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_prep.tga",
    ["DynamicGroup"]  = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_group.tga",
    ["group"]         = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_group.tga",
    ["DynamicBags"]   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_bags.tga",
    ["bags"]          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_bags.tga",
    ["DynamicChat"]   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_chat.tga",
    ["chat"]          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_chat.tga",
    ["DynamicMail"]   = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_mail.tga",
    ["mail"]          = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_mail.tga",
    ["DynamicVault"]    = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_vault.tga",
    ["vault"]           = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_vault.tga",
    ["DynamicDialogue"] = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_dialogue.tga",
    ["dialogue"]        = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_dialogue.tga",
}

function UI.GetModuleIconPath(modKey, fallbackIcon)
    local keyStr = tostring(modKey or "")
    local shortStr = keyStr:gsub("^Dynamic", ""):lower()
    return MODULE_ICON_PATHS[keyStr] or MODULE_ICON_PATHS[shortStr] or fallbackIcon or "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_load.tga"
end

function UI.DrawBrandEmblem(parentFrame, size)
    if not parentFrame then return end
    if addonTable.PopulateBrandLogo then
        addonTable.PopulateBrandLogo(parentFrame, size or 22)
    else
        local tgaW = parentFrame:CreateTexture(nil, "ARTWORK", nil, 4)
        tgaW:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 1, -1)
        tgaW:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -1, 1)
        tgaW:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_white.tga")
        if not tgaW:GetTexture() then
            tgaW:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\logo_stem_white.tga")
        end
        tgaW:SetVertexColor(0.96, 0.97, 0.99, 1)
        local tgaA = parentFrame:CreateTexture(nil, "ARTWORK", nil, 5)
        tgaA:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 1, -1)
        tgaA:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -1, 1)
        tgaA:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_accent.tga")
        if not tgaA:GetTexture() then
            tgaA:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\logo_loop_mask.tga")
        end
        local ar, ag, ab = UI.GetActiveAccentColor()
        tgaA:SetVertexColor(ar, ag, ab, 1)
        function parentFrame:SetAccentColor(r, g, b, a)
            tgaW:SetVertexColor(0.96, 0.97, 0.99, a or 1)
            tgaA:SetVertexColor(r or 0.80, g or 0.84, b or 0.88, a or 1)
        end
    end
end

function UI.GetOnePixel(frame)
    local _, physHeight = GetPhysicalScreenSize()
    if not physHeight or physHeight <= 0 then physHeight = 1080 end
    local scale = (frame and frame.GetEffectiveScale and frame:GetEffectiveScale()) or UIParent:GetEffectiveScale() or 1
    if scale <= 0 then scale = 1 end
    return (768 / physHeight) / scale
end

function UI.CreatePixelBorder(frame, r, g, b, a, sublevel)
    if not frame or not frame.CreateTexture then return nil end
    local px = UI.GetOnePixel(frame)
    local lvl = sublevel or 2
    local border = {
        top    = UI.SolidTex(frame, "OVERLAY", lvl, r, g, b, a),
        bottom = UI.SolidTex(frame, "OVERLAY", lvl, r, g, b, a),
        left   = UI.SolidTex(frame, "OVERLAY", lvl, r, g, b, a),
        right  = UI.SolidTex(frame, "OVERLAY", lvl, r, g, b, a),
    }

    border.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    border.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    border.top:SetHeight(px)

    border.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    border.bottom:SetHeight(px)

    border.left:SetPoint("TOPLEFT", border.top, "BOTTOMLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", border.bottom, "TOPLEFT", 0, 0)
    border.left:SetWidth(px)

    border.right:SetPoint("TOPRIGHT", border.top, "BOTTOMRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", border.bottom, "TOPRIGHT", 0, 0)
    border.right:SetWidth(px)

    frame.dsBorder = {
        SetColor = function(_, cr, cg, cb, ca)
            border.top:SetColorTexture(cr, cg, cb, ca)
            border.bottom:SetColorTexture(cr, cg, cb, ca)
            border.left:SetColorTexture(cr, cg, cb, ca)
            border.right:SetColorTexture(cr, cg, cb, ca)
        end,
        SetThickness = function(_, mult)
            local p = UI.GetOnePixel(frame) * (mult or 1)
            border.top:SetHeight(p)
            border.bottom:SetHeight(p)
            border.left:SetWidth(p)
            border.right:SetWidth(p)
        end,
        Hide = function()
            border.top:Hide(); border.bottom:Hide(); border.left:Hide(); border.right:Hide()
        end,
        Show = function()
            border.top:Show(); border.bottom:Show(); border.left:Show(); border.right:Show()
        end,
    }
    return border
end

--------------------------------------------------------------------------------
-- Global Square Dot Checkbox Factory (Section 2.2 / Design System)
--------------------------------------------------------------------------------
function UI.CreateSquareCheckbox(parent, size)
    local sz = size or 14
    local cb = CreateFrame("Button", nil, parent)
    cb:SetSize(sz, sz)

    cb.bg = UI.SolidTex(cb, "BACKGROUND", 2, 0.024, 0.028, 0.039, 0.98)
    cb.bg:SetAllPoints()
    UI.CreatePixelBorder(cb, 0.165, 0.192, 0.259, 0.95, 3)

    local innerDot = UI.SolidTex(cb, "OVERLAY", 3, 1, 1, 1, 1.0)
    innerDot:SetPoint("CENTER", cb, "CENTER", 0, 0)
    innerDot:Hide()
    cb.innerDot = innerDot

    function cb:SetVisualState(stateKey)
        self.visualState = stateKey or "UNCHECKED"
        local ar, ag, ab = UI.GetActiveAccentColor()
        if stateKey == "CHECKED" then
            self.innerDot:SetSize(8, 8)
            self.innerDot:SetColorTexture(ar, ag, ab, 1.0)
            self.innerDot:Show()
            self.dsBorder:SetColor(ar, ag, ab, 0.95)
        elseif stateKey == "LOCKED" then
            self.innerDot:SetSize(8, 8)
            self.innerDot:SetColorTexture(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1.0)
            self.innerDot:Show()
            self.dsBorder:SetColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.95)
        elseif stateKey == "FROZEN" then
            self.innerDot:SetSize(8, 2)
            self.innerDot:SetColorTexture(UI.COLORS.CYAN.r, UI.COLORS.CYAN.g, UI.COLORS.CYAN.b, 1.0)
            self.innerDot:Show()
            self.dsBorder:SetColor(UI.COLORS.CYAN.r, UI.COLORS.CYAN.g, UI.COLORS.CYAN.b, 0.85)
        else -- UNCHECKED
            self.innerDot:Hide()
            self.dsBorder:SetColor(0.165, 0.192, 0.259, 0.95)
        end
    end

    function cb:GetVisualState()
        return self.visualState or "UNCHECKED"
    end

    cb:SetVisualState("UNCHECKED")
    return cb
end

_G.DynamicSuite = _G.DynamicSuite or {}
_G.DynamicSuite.UI = _G.DynamicSuite.UI or {}
_G.DynamicSuite.UI.CreateSquareCheckbox = UI.CreateSquareCheckbox

--------------------------------------------------------------------------------
-- Hybrid L-Bracket Section Header Factory (Section 2.4 / Design System)
--------------------------------------------------------------------------------
function UI.CreateSectionHeader(parent, arg2, arg3, subtitleText, padOverride)
    local text, yOffset
    if type(arg2) == "number" then
        yOffset = arg2
        text = arg3
    else
        text = arg2
        yOffset = arg3
    end

    local padX = padOverride or (parent and parent.innerPadX) or 0
    local hasSub = (subtitleText and subtitleText ~= "")
    local hdr = CreateFrame("Frame", nil, parent)
    hdr:SetHeight(hasSub and 36 or 20)
    hdr.hasSub = hasSub
    local y = yOffset or 0
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
    hdr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -padX, y)

    local ar, ag, ab = UI.GetActiveAccentColor()

    -- Vertical Pill: 3px wide x 34px tall (when subtitle present) solid texture in 100% Suite Accent at TOPLEFT (0, -1)
    local leftBar = UI.SolidTex(hdr, "ARTWORK", 1, ar, ag, ab, 1.0)
    leftBar:SetSize(3, hasSub and 34 or 16)
    leftBar:SetPoint("TOPLEFT", hdr, "TOPLEFT", 0, -1)
    hdr.leftBar = leftBar

    -- Bottom Underline: 1px tall solid texture in Suite Accent (alpha = 0.35) anchored from TOPLEFT, leftBar, BOTTOMLEFT, 0, 0 across to BOTTOMRIGHT, hdr, BOTTOMRIGHT, 0, 0
    local bottomLine = UI.SolidTex(hdr, "ARTWORK", 1, ar, ag, ab, 0.35)
    bottomLine:SetHeight(1)
    bottomLine:SetPoint("TOPLEFT", leftBar, "BOTTOMLEFT", 0, 0)
    bottomLine:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
    hdr.bottomLine = bottomLine
    hdr.botLine = bottomLine

    -- Line 1: 11pt Bold Uppercase Suite Accent font string
    local title = hdr:CreateFontString(nil, "OVERLAY")
    if hasSub then
        title:SetPoint("TOPLEFT", leftBar, "TOPRIGHT", 8, 0)
    else
        title:SetPoint("LEFT", leftBar, "RIGHT", 8, 0)
    end
    UI.SetFont(title, 11, "", ar, ag, ab, 1.0)
    if text then
        title:SetText(string.upper(text))
    end
    hdr.title = title

    if hasSub then
        local sub = hdr:CreateFontString(nil, "OVERLAY")
        sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
        sub:SetPoint("RIGHT", hdr, "RIGHT", -12, 0)
        sub:SetJustifyH("LEFT")
        sub:SetWordWrap(false)
        UI.SetFont(sub, 10, "", 0.64, 0.70, 0.78, 1.0)
        sub:SetText(subtitleText)
        hdr.subtitle = sub
    end

    function hdr:SetText(newText)
        if self.title then
            self.title:SetText(string.upper(newText or ""))
        end
    end

    function hdr:RefreshAccent()
        local r, g, b = UI.GetActiveAccentColor()
        if self.leftBar then self.leftBar:SetColorTexture(r, g, b, 1.0) end
        if self.bottomLine then self.bottomLine:SetColorTexture(r, g, b, 0.35) end
        if self.title then self.title:SetTextColor(r, g, b, 1.0) end
        if self.subtitle then self.subtitle:SetTextColor(0.64, 0.70, 0.78, 1.0) end
    end

    return hdr
end

_G.DynamicSuite.UI.CreateSectionHeader = UI.CreateSectionHeader

function UI.IsNegativePillOption(val, label)
    if val == false or val == 0 or val == "0" then return true end
    local s = string.upper(tostring(val or label or ""))
    local lbl = string.upper(tostring(label or ""))
    if s == "OFF" or s == "DISABLED" or s == "NONE" or s == "MUTED" or s == "HIDDEN" or s == "NEVER" or s == "BLIZZARD_DEFAULT" then
        return true
    end
    if lbl == "OFF" or lbl == "DISABLED" or lbl == "NONE" or lbl == "MUTED" or lbl == "HIDDEN" or lbl == "NEVER" or lbl == "RESET TO PREVIOUS" then
        return true
    end
    return false
end
_G.DynamicSuite.UI.IsNegativePillOption = UI.IsNegativePillOption

local function ApplyFlatButtonVisual(btn, isHovered)
    if not btn or not btn.bg or not btn.dsBorder then return end
    local ar, ag, ab = UI.GetActiveAccentColor()
    local isActive = btn.isSelected
    if isActive == nil then
        isActive = btn.isPrimary
    end
    local col = btn.selectedColor
    local cr = (col and col.r) or ar
    local cg = (col and col.g) or ag
    local cb = (col and col.b) or ab

    if isActive and btn.isNegativeOpt then
        if not btn.OffBar then
            local offBar = UI.SolidTex(btn, "OVERLAY", 4, 0.973, 0.443, 0.443, 0.85)
            offBar:SetHeight(1.5)
            offBar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
            offBar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
            btn.OffBar = offBar
        end
        btn.OffBar:SetColorTexture(0.973, 0.443, 0.443, 0.85)
        btn.OffBar:Show()
        if isHovered then
            btn.bg:SetColorTexture(0.141, 0.169, 0.224, 0.98)
            btn.dsBorder:SetColor(0.471, 0.545, 0.651, 0.95)
        else
            btn.bg:SetColorTexture(0.118, 0.141, 0.188, 0.98)
            btn.dsBorder:SetColor(0.392, 0.455, 0.545, 0.90)
        end
        if btn.label then btn.label:SetTextColor(0.886, 0.910, 0.941, 1.0) end
        return
    end

    if btn.OffBar then btn.OffBar:Hide() end

    if btn.isEditHudButton then
        if isActive or isHovered then
            btn.bg:SetColorTexture(0.18, 0.09, 0.03, 0.98)
            btn.dsBorder:SetColor(0.976, 0.451, 0.086, 1.0)
            if btn.label then btn.label:SetTextColor(1, 1, 1, 1) end
        else
            btn.bg:SetColorTexture(0.043, 0.051, 0.071, 0.96)
            btn.dsBorder:SetColor(0.976, 0.451, 0.086, 0.85)
            if btn.label then btn.label:SetTextColor(0.976, 0.984, 1.0, 1.0) end
        end
        return
    end

    if isActive then
        local g = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local fillAlpha = (g and g.pillFillAlpha) or 0.42
        local hoverAlpha = math.min(0.65, fillAlpha + 0.10)
        if isHovered then
            btn.bg:SetColorTexture(cr, cg, cb, hoverAlpha)
            btn.dsBorder:SetColor(cr, cg, cb, 1.0)
            if btn.label then btn.label:SetTextColor(1, 1, 1, 1) end
        else
            btn.bg:SetColorTexture(cr, cg, cb, fillAlpha)
            btn.dsBorder:SetColor(cr, cg, cb, 0.95)
            if btn.label then
                if btn.keepColoredLabelWhenSelected then
                    btn.label:SetTextColor(cr, cg, cb, 1)
                else
                    btn.label:SetTextColor(1, 1, 1, 1)
                end
            end
        end
    else
        if isHovered then
            btn.bg:SetColorTexture(UI.COLORS.BTN_HOVER.r, UI.COLORS.BTN_HOVER.g, UI.COLORS.BTN_HOVER.b, 1.0)
            if btn.isNegativeOpt then
                btn.dsBorder:SetColor(0.392, 0.455, 0.545, 0.85)
            else
                btn.dsBorder:SetColor(cr, cg, cb, 0.75)
            end
            if btn.label then btn.label:SetTextColor(1, 1, 1, 1) end
        else
            if btn.idleBgColor then
                btn.bg:SetColorTexture(btn.idleBgColor.r, btn.idleBgColor.g, btn.idleBgColor.b, btn.idleBgColor.a or 0.96)
            else
                local idleBgAlpha = btn.idleBgAlpha or 0.94
                btn.bg:SetColorTexture(UI.COLORS.BTN_BG.r, UI.COLORS.BTN_BG.g, UI.COLORS.BTN_BG.b, idleBgAlpha)
            end
            if btn.idleBorderColor then
                btn.dsBorder:SetColor(btn.idleBorderColor.r, btn.idleBorderColor.g, btn.idleBorderColor.b, btn.idleBorderColor.a or 0.35)
            else
                btn.dsBorder:SetColor(UI.COLORS.BTN_BORDER.r, UI.COLORS.BTN_BORDER.g, UI.COLORS.BTN_BORDER.b, UI.COLORS.BTN_BORDER.a)
            end
            if btn.label then
                if btn.idleTextColor then
                    btn.label:SetTextColor(btn.idleTextColor.r, btn.idleTextColor.g, btn.idleTextColor.b, btn.idleTextColor.a or 1)
                else
                    btn.label:SetTextColor(0.86, 0.88, 0.92, 0.95)
                end
            end
        end
    end
end

local function CreateFlatButton(parent, width, height, text, isPrimary)
    UI.RefreshPaletteCache()
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width or 100, height or 24)
    btn.isPrimary = isPrimary
    btn.isSelected = (isPrimary == true)

    local bgCol = isPrimary and UI.COLORS.ACCENT or UI.COLORS.BTN_BG
    local bgAlpha = isPrimary and 0.28 or 0.94
    btn.bg = UI.SolidTex(btn, "BACKGROUND", 1, bgCol.r, bgCol.g, bgCol.b, bgAlpha)
    btn.bg:SetAllPoints()

    local bColor = isPrimary and UI.COLORS.ACCENT or UI.COLORS.BTN_BORDER
    local bAlpha = isPrimary and 0.95 or UI.COLORS.BTN_BORDER.a
    UI.CreatePixelBorder(btn, bColor.r, bColor.g, bColor.b, bAlpha, 2)

    btn._minWidth = width or 100
    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", btn, "LEFT", 6, 0)
    label:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    if label.SetMaxLines then label:SetMaxLines(1) end
    UI.SetFont(label, 11, "", 1, 1, 1, 0.94)
    btn.label = label

    local rawSetText = label.SetText
    function btn:UpdateAutoWidth()
        if not self._autoExpandWidth then return end
        local rawTxt = (label.GetText and label:GetText()) or ""
        local cleanTxt = tostring(rawTxt):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
        local ok, uw = pcall(function()
            return (label.GetUnboundedStringWidth and label:GetUnboundedStringWidth()) or label:GetStringWidth() or 0
        end)
        local measuredW = (ok and type(uw) == "number" and uw > 0) and uw or (#cleanTxt * 6.8)
        local targetW = math.max(self._minWidth or 66, math.ceil(measuredW + 20))
        if math.abs((self:GetWidth() or 0) - targetW) > 1 then
            self:SetWidth(targetW)
        end
    end
    label.SetText = function(selfFs, newTxt)
        rawSetText(selfFs, newTxt or "")
        btn:UpdateAutoWidth()
    end
    label:SetText(text or "")
    btn:HookScript("OnShow", function(self) self:UpdateAutoWidth() end)

    function btn:SetSelected(isSel, customCol)
        self.isSelected = (isSel == true)
        if customCol ~= nil then
            self.selectedColor = customCol
        end
        ApplyFlatButtonVisual(self, self:IsMouseOver())
    end

    function btn:RefreshVisual()
        ApplyFlatButtonVisual(self, self:IsMouseOver())
    end

    btn:SetScript("OnEnter", function(self)
        ApplyFlatButtonVisual(self, true)
        if self.OnCustomEnter then self:OnCustomEnter() end
    end)

    btn:SetScript("OnLeave", function(self)
        ApplyFlatButtonVisual(self, false)
        if self.OnCustomLeave then self:OnCustomLeave() end
    end)

    ApplyFlatButtonVisual(btn, false)
    return btn
end


UI.CreateFlatButton = CreateFlatButton
UI.ApplyFlatButtonVisual = ApplyFlatButtonVisual

local function CreateEditHudButton(parent, labelOrTargetKey, onClickOrWidth, heightOpt)
    local hudKey = nil
    local labelText = "Edit HUD"
    local onClickFn = nil
    local btnW = 86
    local btnH = (type(heightOpt) == "number" and heightOpt) or 22

    if type(labelOrTargetKey) == "string" then
        if labelOrTargetKey == "TOAST" or labelOrTargetKey == "PREP" or labelOrTargetKey == "TARGET"
            or labelOrTargetKey == "FLARE" or labelOrTargetKey == "prepBuffs" or labelOrTargetKey == "CHAT" or labelOrTargetKey == "VAULT" then
            hudKey = labelOrTargetKey
        elseif labelOrTargetKey ~= "" then
            labelText = labelOrTargetKey
        end
    end
    if type(onClickOrWidth) == "function" then
        onClickFn = onClickOrWidth
    elseif type(onClickOrWidth) == "number" then
        btnW = onClickOrWidth
    end
    if type(heightOpt) == "function" then
        onClickFn = heightOpt
    end

    local btn = CreateFlatButton(parent, btnW, btnH, labelText, false)
    btn.isEditHudButton = true
    ApplyFlatButtonVisual(btn, false)
    btn:SetScript("OnClick", function(selfBtn, mouseBtn)
        if onClickFn then
            onClickFn(selfBtn, mouseBtn)
        elseif hudKey and addonTable.EnterHudEditMode then
            addonTable.EnterHudEditMode(hudKey, true)
        elseif hudKey and _G.DynamicSuite and _G.DynamicSuite.EnterHudEditMode then
            _G.DynamicSuite.EnterHudEditMode(hudKey, true)
        end
    end)
    btn.OnCustomEnter = function(selfBtn)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Edit HUD", 1, 1, 1)
        GameTooltip:AddLine("Opens HUD Edit Mode with this HUD element selected so you can move, align, or scale it.", 0.82, 0.86, 0.92, true)
        GameTooltip:Show()
    end
    btn.OnCustomLeave = function()
        if GameTooltip then GameTooltip:Hide() end
    end
    return btn
end
UI.CreateEditHudButton = CreateEditHudButton
addonTable.CreateEditHudButton = CreateEditHudButton
_G.DynamicSuite = _G.DynamicSuite or {}
_G.DynamicSuite.CreateEditHudButton = CreateEditHudButton

local registeredPopupClosers = {}
function UI.RegisterPopupCloser(key, closeFn)
    if key ~= nil and type(closeFn) == "function" then
        registeredPopupClosers[key] = closeFn
    elseif type(key) == "function" and closeFn == nil then
        table.insert(registeredPopupClosers, key)
    end
end
addonTable.RegisterPopupCloser = UI.RegisterPopupCloser
_G.DynamicSuite.UI = _G.DynamicSuite.UI or UI
_G.DynamicSuite.UI.RegisterPopupCloser = UI.RegisterPopupCloser
_G.DynamicSuite.RegisterPopupCloser = UI.RegisterPopupCloser

local function RunRegisteredPopupClosers()
    for _, fn in pairs(registeredPopupClosers) do
        if type(fn) == "function" then
            pcall(fn)
        end
    end
end
UI.RunRegisteredPopupClosers = RunRegisteredPopupClosers

local function CloseAltDropdown()
    if altDropdownFrame then altDropdownFrame:Hide() end
    if addonTable._closeDLAltDropdown then addonTable._closeDLAltDropdown() end
end
UI.CloseAltDropdown = CloseAltDropdown

local function CloseContextMenu()
    if contextMenuFrame then contextMenuFrame:Hide() end
    if altDropdownFrame then altDropdownFrame:Hide() end
    if addonTable._closeDLContextMenu then addonTable._closeDLContextMenu() end
    if clickCatcher and (not UI.IsDropdownPopupShown or not UI.IsDropdownPopupShown()) then
        clickCatcher:Hide()
    end
end
UI.CloseContextMenu = CloseContextMenu

UI.CloseAllPopups = function()
    CloseContextMenu()
    CloseAltDropdown()
    if _G.DynamicSuiteHudSelectorPopup and _G.DynamicSuiteHudSelectorPopup:IsShown() then
        _G.DynamicSuiteHudSelectorPopup:Hide()
    end
    RunRegisteredPopupClosers()
end
_G.DynamicSuite.UI.CloseAllPopups = UI.CloseAllPopups

local function GetClickCatcher()
    if not clickCatcher then
        clickCatcher = CreateFrame("Button", "DynamicLoadClickCatcher", UIParent)
        clickCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
        clickCatcher:SetFrameLevel(100)
        clickCatcher:SetAllPoints(UIParent)
        clickCatcher:EnableMouse(true)
        clickCatcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        clickCatcher:SetScript("OnClick", function()
            if UI.CloseAllPopups then
                UI.CloseAllPopups()
            else
                CloseContextMenu()
            end
        end)
        clickCatcher:Hide()
    end
    return clickCatcher
end
UI.GetClickCatcher = GetClickCatcher

local function OpenAltDropdown(anchorFrame, f)
    if addonTable.OpenAltDropdown then
        addonTable.OpenAltDropdown(anchorFrame, f)
    end
end
UI.OpenAltDropdown = OpenAltDropdown

local function RefreshAddonTree(scrollChild, resetScroll)
    if addonTable.RefreshAddonTree then
        addonTable.RefreshAddonTree(scrollChild, resetScroll)
    end
end

addonTable.GetSelectedTabKey = function() return selectedTabKey end
addonTable.SetSelectedTabKey = function(v)
    selectedTabKey = v or "outdoor"
    if addonTable._syncDLStateFromSuite then
        addonTable._syncDLStateFromSuite(selectedTabKey, securityFilter, isToastSubTabActive)
    end
end
addonTable.GetSecurityFilter = function() return securityFilter end
addonTable.SetSecurityFilter = function(v)
    securityFilter = v or "ALL"
    if addonTable._syncDLStateFromSuite then
        addonTable._syncDLStateFromSuite(selectedTabKey, securityFilter, isToastSubTabActive)
    end
end
addonTable.GetIsToastSubTabActive = function() return isToastSubTabActive end
addonTable.SetIsToastSubTabActive = function(v)
    isToastSubTabActive = (v == true)
    if addonTable._syncDLStateFromSuite then
        addonTable._syncDLStateFromSuite(selectedTabKey, securityFilter, isToastSubTabActive)
    end
end
addonTable.GetActiveWorkspaceView = function() return activeWorkspaceView end
addonTable._syncSuiteStateFromDL = function(tabK, secF, toastSub)
    if tabK ~= nil then selectedTabKey = tabK end
    if secF ~= nil then securityFilter = secF end
    if toastSub ~= nil then isToastSubTabActive = toastSub end
end
--------------------------------------------------------------------------------
-- Built-In Support Modal & Built-In Changelog Modal
--------------------------------------------------------------------------------
local function CreateSupportModal(parent)
    if supportDialog then return supportDialog end

    local dlg = CreateFrame("Frame", "DynamicLoadSupportDialog", parent or UIParent, "BackdropTemplate")
    dlg:SetSize(390, 170)
    dlg:SetPoint("CENTER", parent or UIParent, "CENTER", 0, 20)
    dlg:SetFrameStrata("FULLSCREEN_DIALOG")
    dlg:SetToplevel(true)
    dlg:EnableMouse(true)
    dlg:SetClampedToScreen(true)

    dlg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    dlg:SetBackdropColor(0.04, 0.05, 0.07, 0.98)
    dlg:SetBackdropBorderColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.85)

    local topBar = UI.SolidTex(dlg, "OVERLAY", 2, UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1)
    topBar:SetPoint("TOPLEFT", dlg, "TOPLEFT", 1, -1)
    topBar:SetPoint("TOPRIGHT", dlg, "TOPRIGHT", -1, -1)
    topBar:SetHeight(2)

    local closeBtn = CreateFrame("Button", nil, dlg)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", dlg, "TOPRIGHT", -6, -6)
    local closeText = closeBtn:CreateFontString(nil, "OVERLAY")
    closeText:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    UI.SetFont(closeText, 12, "", 0.7, 0.7, 0.7, 1)
    closeText:SetText("X")
    closeBtn:SetScript("OnClick", function() dlg:Hide() end)

    local icon = dlg:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("TOPLEFT", dlg, "TOPLEFT", 16, -14)
    icon:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_support.tga")
    icon:SetVertexColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1)

    local title = dlg:CreateFontString(nil, "OVERLAY")
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    UI.SetFont(title, 13, "", UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1)
    title:SetText("Support DynamicSuite & DynamicLoad")

    local subtext = dlg:CreateFontString(nil, "OVERLAY")
    subtext:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -8)
    subtext:SetPoint("RIGHT", dlg, "RIGHT", -16, 0)
    subtext:SetJustifyH("LEFT")
    UI.SetFont(subtext, 11, "", 0.9, 0.9, 0.9, 1)
    subtext:SetText("Enjoying the suite? Buying a coffee keeps raid updates, performance tuning, and feature polish brewing!")

    local editContainer = CreateFrame("Frame", nil, dlg, "BackdropTemplate")
    editContainer:SetSize(358, 26)
    editContainer:SetPoint("TOPLEFT", subtext, "BOTTOMLEFT", 0, -10)
    editContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    editContainer:SetBackdropColor(0.02, 0.02, 0.03, 1.0)
    editContainer:SetBackdropBorderColor(UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.6)

    local editBox = CreateFrame("EditBox", "DynamicLoadKofiEditBox", editContainer)
    editBox:SetPoint("LEFT", editContainer, "LEFT", 8, 0)
    editBox:SetPoint("RIGHT", editContainer, "RIGHT", -8, 0)
    editBox:SetHeight(20)
    editBox:SetAutoFocus(false)
    UI.SetFont(editBox, 11, "", 1, 1, 1, 1)
    editBox:SetText("https://ko-fi.com/dentee")

    editBox:SetScript("OnEscapePressed", function() dlg:Hide() end)
    editBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    editBox:SetScript("OnTextChanged", function(self, isUserInput)
        if isUserInput then
            self:SetText("https://ko-fi.com/dentee")
            self:HighlightText()
        end
    end)

    local helper = dlg:CreateFontString(nil, "OVERLAY")
    helper:SetPoint("TOPLEFT", editContainer, "BOTTOMLEFT", 0, -6)
    UI.SetFont(helper, 10, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 1)
    helper:SetText("Press |cFFFFFFFFCtrl+C|r to copy URL, then paste into your browser.")

    local doneBtn = CreateFlatButton(dlg, 80, 22, "Done", true)
    doneBtn:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -16, 12)
    doneBtn:SetScript("OnClick", function() dlg:Hide() end)

    dlg:SetScript("OnShow", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    table.insert(UISpecialFrames, "DynamicLoadSupportDialog")
    dlg:Hide()
    supportDialog = dlg
    return supportDialog
end

function addonTable.ShowSupportDialog()
    if addonTable.OpenWorkspaceView then
        if mainFrame and mainFrame:IsShown() and activeWorkspaceView == "SUPPORT_VIEW" then
            addonTable.OpenWorkspaceView("DYNAMICLOAD")
        else
            addonTable.OpenWorkspaceView("SUPPORT_VIEW")
        end
        return
    end
    local dlg = CreateSupportModal(mainFrame)
    if dlg:IsShown() then dlg:Hide() else dlg:Show() end
end

local function CreateChangelogModal(parent)
    if changelogDialog then return changelogDialog end

    local dlg = CreateFrame("Frame", "DynamicLoadChangelogDialog", parent or UIParent, "BackdropTemplate")
    dlg:SetSize(520, 360)
    dlg:SetPoint("CENTER", parent or UIParent, "CENTER", 0, 10)
    dlg:SetFrameStrata("FULLSCREEN_DIALOG")
    dlg:SetToplevel(true)
    dlg:EnableMouse(true)
    dlg:SetClampedToScreen(true)

    dlg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    dlg:SetBackdropColor(0.04, 0.05, 0.07, 0.99)
    dlg:SetBackdropBorderColor(UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.85)

    local topBar = UI.SolidTex(dlg, "OVERLAY", 2, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 1)
    topBar:SetPoint("TOPLEFT", dlg, "TOPLEFT", 1, -1)
    topBar:SetPoint("TOPRIGHT", dlg, "TOPRIGHT", -1, -1)
    topBar:SetHeight(2)

    local title = dlg:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", dlg, "TOPLEFT", 18, -14)
    UI.SetFont(title, 14, "", 1, 1, 1, 0.98)
    local liveVer = addonTable.ADDON_VERSION or "2.3.2"
    title:SetText("DynamicLoad & DynamicSuite - Changelog (v" .. liveVer .. " - 18/11/2026)")

    local closeBtn = CreateFrame("Button", nil, dlg)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", dlg, "TOPRIGHT", -8, -8)
    local closeText = closeBtn:CreateFontString(nil, "OVERLAY")
    closeText:SetPoint("CENTER")
    UI.SetFont(closeText, 12, "", 0.7, 0.7, 0.7, 1)
    closeText:SetText("X")
    closeBtn:SetScript("OnClick", function() dlg:Hide() end)

    local body = dlg:CreateFontString(nil, "OVERLAY")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
    body:SetPoint("RIGHT", dlg, "RIGHT", -18, 0)
    body:SetJustifyH("LEFT")
    body:SetSpacing(4)
    UI.SetFont(body, 11, "", 0.88, 0.90, 0.94, 1)
    body:SetText(
        "|cFF38BDF8v" .. liveVer .. " (11/11/2026) - DynamicSuite Hub & Suite-Wide Synchronisation|r\n" ..
        "- |cFFFFFFFFResolved /ds & /dl Client Freeze|r: Fixed ApplySuiteThemeAndGeometry re-entrancy recursion, cached font path resolution, and hardened UI.CreatePixelBorder & BuildAddonHierarchy.\n" ..
        "- |cFFFFFFFFFull-Width Horizontal Chevron Sub-Drawers|r: Upgraded DynamicMarker, DynamicZoom, DynamicFPS, and DynamicPrep collapsible sub-drawers to 24px horizontal chevron bars (Sub-Settings (N)) inside outer bordered group cards.\n" ..
        "- |cFFFFFFFFDynamicPrep Secret Aura & Hex Fixes|r: Added _AreAurasSecret / _IsAuraIndexSecret combat guards and sanitized 8-digit ARGB hex codes in the Top Info Bar.\n" ..
        "- |cFFFFFFFFDynamicGroup LFG Hardening|r: Added securityDisableSetText & IsSecretValue guards for Application Note auto-fill, dynamic resultID resolution, and hook collision guards.\n" ..
        "- |cFFFFFFFFDesign System v1.3.0 Standardisation|r: Square dot checkboxes, connected L-bracket section headers, 3-button inline load mode pills, and 5-zone full-width top bevel track."
    )

    local doneBtn = CreateFlatButton(dlg, 96, 24, "Close", true)
    doneBtn:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -16, 14)
    doneBtn:SetScript("OnClick", function() dlg:Hide() end)

    table.insert(UISpecialFrames, "DynamicLoadChangelogDialog")
    dlg:Hide()
    changelogDialog = dlg
    return changelogDialog
end

function addonTable.ToggleChangelogModal()
    if addonTable.OpenWorkspaceView then
        if mainFrame and mainFrame:IsShown() and activeWorkspaceView == "CHANGELOG_VIEW" then
            addonTable.OpenWorkspaceView("DYNAMICLOAD")
        else
            addonTable.OpenWorkspaceView("CHANGELOG_VIEW")
        end
        return
    end
    local dlg = CreateChangelogModal(mainFrame)
    if dlg:IsShown() then dlg:Hide() else dlg:Show() end
end

--------------------------------------------------------------------------------
-- Custom Color Picker & Slider Helpers
--------------------------------------------------------------------------------
local function RGBtoHSV(r, g, b)
    local maxC = math.max(r, g, b)
    local minC = math.min(r, g, b)
    local d = maxC - minC
    local h, s, v = 0, (maxC == 0 and 0 or d / maxC), maxC
    if d > 0.0001 then
        if maxC == r then
            h = ((g - b) / d) % 6
        elseif maxC == g then
            h = ((b - r) / d) + 2
        else
            h = ((r - g) / d) + 4
        end
        h = h * 60
        if h < 0 then h = h + 360 end
    end
    return h, s, v
end

local function HSVtoRGB(h, s, v)
    if s <= 0 then return v, v, v end
    h = (h % 360) / 60
    local i = math.floor(h)
    local f = h - i
    local p = v * (1 - s)
    local q = v * (1 - s * f)
    local t = v * (1 - s * (1 - f))
    if i == 0 then return v, t, p
    elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v
    else return v, p, q end
end

local function FormatHex6(r, g, b)
    local ri = math.floor(math.max(0, math.min(1, r or 0)) * 255 + 0.5)
    local gi = math.floor(math.max(0, math.min(1, g or 0)) * 255 + 0.5)
    local bi = math.floor(math.max(0, math.min(1, b or 0)) * 255 + 0.5)
    return string.format("%02X%02X%02X", ri, gi, bi)
end

local function ParseHex6(str)
    if not str then return nil end
    local clean = str:gsub("^#", ""):gsub("^|c%x%x", ""):gsub("|r$", ""):trim()
    if #clean == 6 and clean:match("^%x+$") then
        local r = tonumber(clean:sub(1, 2), 16) / 255
        local g = tonumber(clean:sub(3, 4), 16) / 255
        local b = tonumber(clean:sub(5, 6), 16) / 255
        return r, g, b
    end
    return nil
end

local function PushRecentColor(r, g, b, a)
    local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
    if not gTbl then return end
    gTbl.recentColors = gTbl.recentColors or {}
    local hex = FormatHex6(r, g, b)
    local list = gTbl.recentColors
    for i = #list, 1, -1 do
        if list[i] and FormatHex6(list[i].r, list[i].g, list[i].b) == hex then
            table.remove(list, i)
        end
    end
    table.insert(list, 1, { r = r, g = g, b = b, a = a or 1.0 })
    while #list > 8 do
        table.remove(list)
    end
    if DynamicLoadDB then
        DynamicLoadDB.recentColors = CopyTable(list)
    end
end
addonTable.PushRecentColor = PushRecentColor

local function OpenDSColorPicker(anchorFrame, titleText, initialColor, hasOpacity, callback)
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow and IsShiftKeyDown() then
        local r = (initialColor and initialColor.r) or 0.8
        local g = (initialColor and initialColor.g) or 0.84
        local b = (initialColor and initialColor.b) or 0.88
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            hasOpacity = false,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                PushRecentColor(nr, ng, nb, 1.0)
                if callback then callback(nr, ng, nb, 1.0) end
            end,
            cancelFunc = function()
                if callback then callback(r, g, b, 1.0) end
            end,
        })
        return
    end

    if not dsColorPicker then
        local cp = CreateFrame("Frame", "DynamicLoadColorPicker", UIParent)
        cp:SetSize(268, 340)
        cp:SetFrameStrata("TOOLTIP")
        cp:SetToplevel(true)
        cp:SetClampedToScreen(true)
        cp:EnableMouse(true)
        cp:SetMovable(true)
        cp:RegisterForDrag("LeftButton")
        cp:SetScript("OnDragStart", cp.StartMoving)
        cp:SetScript("OnDragStop", cp.StopMovingOrSizing)

        cp.bg = UI.SolidTex(cp, "BACKGROUND", 0, 0.04, 0.05, 0.07, 0.99)
        cp.bg:SetAllPoints()
        UI.CreatePixelBorder(cp, 1, 1, 1, 0.18, 4)

        local hdr = cp:CreateFontString(nil, "OVERLAY")
        hdr:SetPoint("TOPLEFT", cp, "TOPLEFT", 14, -10)
        UI.SetFont(hdr, 12, "", 1, 1, 1, 0.95)
        hdr:SetText("Custom Colour Picker")
        cp.hdr = hdr

        local closeBtn = CreateFrame("Button", nil, cp)
        closeBtn:SetSize(20, 20)
        closeBtn:SetPoint("TOPRIGHT", cp, "TOPRIGHT", -8, -6)
        local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
        closeTxt:SetPoint("CENTER")
        UI.SetFont(closeTxt, 12, "", 0.65, 0.65, 0.65, 1)
        closeTxt:SetText("X")
        cp.closeBtn = closeBtn

        local svPad = CreateFrame("Frame", nil, cp)
        svPad:SetSize(192, 144)
        svPad:SetPoint("TOPLEFT", cp, "TOPLEFT", 14, -34)
        svPad:EnableMouse(true)
        UI.CreatePixelBorder(svPad, 1, 1, 1, 0.18, 5)
        cp.svPad = svPad

        local svHue = svPad:CreateTexture(nil, "BACKGROUND", nil, 0)
        svHue:SetAllPoints()
        svHue:SetColorTexture(1, 0, 0, 1)
        cp.svHue = svHue

        local svWhite = svPad:CreateTexture(nil, "BORDER", nil, 1)
        svWhite:SetAllPoints()
        svWhite:SetColorTexture(1, 1, 1, 1)
        if svWhite.SetGradient and CreateColor then
            svWhite:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 0))
        end

        local svBlack = svPad:CreateTexture(nil, "ARTWORK", nil, 2)
        svBlack:SetAllPoints()
        svBlack:SetColorTexture(1, 1, 1, 1)
        if svBlack.SetGradient and CreateColor then
            svBlack:SetGradient("VERTICAL", CreateColor(0, 0, 0, 1), CreateColor(0, 0, 0, 0))
        end

        local svCursor = CreateFrame("Frame", nil, svPad)
        svCursor:SetSize(10, 10)
        UI.CreatePixelBorder(svCursor, 1, 1, 1, 1.0, 6)
        cp.svCursor = svCursor

        local hueBar = CreateFrame("Frame", nil, cp)
        hueBar:SetSize(22, 144)
        hueBar:SetPoint("TOPLEFT", svPad, "TOPRIGHT", 10, 0)
        hueBar:EnableMouse(true)
        UI.CreatePixelBorder(hueBar, 1, 1, 1, 0.18, 5)
        cp.hueBar = hueBar

        local hueStops = {
            { 1, 0, 0,  1, 1, 0 },
            { 1, 1, 0,  0, 1, 0 },
            { 0, 1, 0,  0, 1, 1 },
            { 0, 1, 1,  0, 0, 1 },
            { 0, 0, 1,  1, 0, 1 },
            { 1, 0, 1,  1, 0, 0 },
        }
        local segH = 144 / 6
        for i, st in ipairs(hueStops) do
            local seg = hueBar:CreateTexture(nil, "ARTWORK")
            seg:SetSize(22, segH)
            seg:SetPoint("TOPLEFT", hueBar, "TOPLEFT", 0, -((i - 1) * segH))
            seg:SetColorTexture(1, 1, 1, 1)
            if seg.SetGradient and CreateColor then
                seg:SetGradient("VERTICAL", CreateColor(st[4], st[5], st[6], 1), CreateColor(st[1], st[2], st[3], 1))
            end
        end

        local hueThumb = UI.SolidTex(hueBar, "OVERLAY", 6, 1, 1, 1, 1)
        hueThumb:SetSize(24, 3)
        cp.hueThumb = hueThumb

        local previewSwatch = CreateFrame("Frame", nil, cp)
        previewSwatch:SetSize(28, 22)
        previewSwatch:SetPoint("TOPLEFT", svPad, "BOTTOMLEFT", 0, -10)
        UI.CreatePixelBorder(previewSwatch, 1, 1, 1, 0.25, 3)
        previewSwatch.tex = UI.SolidTex(previewSwatch, "ARTWORK", 1, 0.8, 0.84, 0.88, 1)
        previewSwatch.tex:SetAllPoints()
        cp.previewSwatch = previewSwatch

        local hexLabel = cp:CreateFontString(nil, "OVERLAY")
        hexLabel:SetPoint("LEFT", previewSwatch, "RIGHT", 8, 0)
        UI.SetFont(hexLabel, 11, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 1)
        hexLabel:SetText("HEX #")

        local hexBoxFrame = CreateFrame("Frame", nil, cp)
        hexBoxFrame:SetSize(78, 22)
        hexBoxFrame:SetPoint("LEFT", hexLabel, "RIGHT", 4, 0)
        hexBoxFrame.bg = UI.SolidTex(hexBoxFrame, "BACKGROUND", 0, 0.02, 0.02, 0.03, 0.95)
        hexBoxFrame.bg:SetAllPoints()
        UI.CreatePixelBorder(hexBoxFrame, 1, 1, 1, 0.15, 2)

        local hexInput = CreateFrame("EditBox", nil, hexBoxFrame)
        hexInput:SetPoint("LEFT", hexBoxFrame, "LEFT", 6, 0)
        hexInput:SetPoint("RIGHT", hexBoxFrame, "RIGHT", -4, 0)
        hexInput:SetHeight(20)
        hexInput:SetAutoFocus(false)
        hexInput:SetMaxLetters(6)
        UI.SetFont(hexInput, 11, "", 1, 1, 1, 0.95)
        cp.hexInput = hexInput

        local recentHdr = cp:CreateFontString(nil, "OVERLAY")
        recentHdr:SetPoint("TOPLEFT", previewSwatch, "BOTTOMLEFT", 0, -12)
        UI.SetFont(recentHdr, 9, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 1)
        recentHdr:SetText("RECENTLY PICKED (ACCOUNT-WIDE)")

        cp.recentBtns = {}
        for i = 1, 8 do
            local rBtn = CreateFrame("Button", nil, cp)
            rBtn:SetSize(24, 20)
            rBtn:SetPoint("TOPLEFT", recentHdr, "BOTTOMLEFT", (i - 1) * 30, -5)
            rBtn.tex = UI.SolidTex(rBtn, "ARTWORK", 1, 0.1, 0.1, 0.1, 0.5)
            rBtn.tex:SetAllPoints()
            UI.CreatePixelBorder(rBtn, 1, 1, 1, 0.14, 3)
            cp.recentBtns[i] = rBtn
        end

        local applyBtn = CreateFlatButton(cp, 114, 24, "Apply Colour", true)
        applyBtn:SetPoint("BOTTOMLEFT", cp, "BOTTOMLEFT", 14, 12)
        cp.applyBtn = applyBtn

        local cancelBtn = CreateFlatButton(cp, 114, 24, "Cancel", false)
        cancelBtn:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT", -14, 12)
        cp.cancelBtn = cancelBtn

        table.insert(UISpecialFrames, "DynamicLoadColorPicker")
        dsColorPicker = cp
    end

    local cp = dsColorPicker
    cp.hdr:SetText(titleText or "Custom Colour Picker")
    local origR = initialColor and initialColor.r or 0.796
    local origG = initialColor and initialColor.g or 0.835
    local origB = initialColor and initialColor.b or 0.882
    local origA = initialColor and initialColor.a or 1.0

    local curH, curS, curV = RGBtoHSV(origR, origG, origB)
    local curA = origA

    local function UpdateVisualsAndNotify(notifyCallback)
        local r, g, b = HSVtoRGB(curH, curS, curV)
        local hr, hg, hb = HSVtoRGB(curH, 1, 1)
        cp.svHue:SetColorTexture(hr, hg, hb, 1)

        local padW, padH = cp.svPad:GetSize()
        cp.svCursor:ClearAllPoints()
        cp.svCursor:SetPoint("CENTER", cp.svPad, "BOTTOMLEFT", curS * padW, curV * padH)

        local barH = cp.hueBar:GetHeight()
        cp.hueThumb:ClearAllPoints()
        cp.hueThumb:SetPoint("CENTER", cp.hueBar, "TOP", 0, -((curH / 360) * barH))

        cp.previewSwatch.tex:SetColorTexture(r, g, b, 1)
        if not cp.hexInput:HasFocus() then
            cp.hexInput:SetText(FormatHex6(r, g, b))
        end

        if notifyCallback and callback then
            callback(r, g, b, curA)
        end
    end

    local function RefreshRecentSwatches()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        local list = (gTbl and gTbl.recentColors) or (DynamicLoadDB and DynamicLoadDB.recentColors) or {}
        for i = 1, 8 do
            local btn = cp.recentBtns[i]
            local c = list[i]
            if c then
                btn.tex:SetColorTexture(c.r, c.g, c.b, 1)
                btn.dsBorder:SetColor(1, 1, 1, 0.24)
                btn:Enable()
                btn:SetScript("OnClick", function()
                    curH, curS, curV = RGBtoHSV(c.r, c.g, c.b)
                    UpdateVisualsAndNotify(true)
                end)
            else
                btn.tex:SetColorTexture(0.08, 0.08, 0.08, 0.45)
                btn.dsBorder:SetColor(1, 1, 1, 0.08)
                btn:Disable()
                btn:SetScript("OnClick", nil)
            end
        end
    end

    local function UpdateSVFromCursor()
        local scale = cp.svPad:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        cx, cy = cx / scale, cy / scale
        local left, bottom, w, h = cp.svPad:GetLeft(), cp.svPad:GetBottom(), cp.svPad:GetWidth(), cp.svPad:GetHeight()
        if left and bottom and w > 0 and h > 0 then
            local newS = math.max(0, math.min(1, (cx - left) / w))
            local newV = math.max(0, math.min(1, (cy - bottom) / h))
            if math.abs(newS - curS) > 0.001 or math.abs(newV - curV) > 0.001 then
                curS = newS
                curV = newV
                UpdateVisualsAndNotify(true)
            end
        end
    end

    cp.svPad:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            UpdateSVFromCursor()
            self:SetScript("OnUpdate", function(s)
                if not IsMouseButtonDown("LeftButton") then
                    s:SetScript("OnUpdate", nil)
                    return
                end
                UpdateSVFromCursor()
            end)
        end
    end)
    cp.svPad:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    cp.svPad:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)

    local function UpdateHueFromCursor()
        local scale = cp.hueBar:GetEffectiveScale()
        local _, cy = GetCursorPosition()
        cy = cy / scale
        local top, h = cp.hueBar:GetTop(), cp.hueBar:GetHeight()
        if top and h > 0 then
            local pct = math.max(0, math.min(1, (top - cy) / h))
            local newH = pct * 359.9
            if math.abs(newH - curH) > 0.05 then
                curH = newH
                UpdateVisualsAndNotify(true)
            end
        end
    end

    cp.hueBar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            UpdateHueFromCursor()
            self:SetScript("OnUpdate", function(s)
                if not IsMouseButtonDown("LeftButton") then
                    s:SetScript("OnUpdate", nil)
                    return
                end
                UpdateHueFromCursor()
            end)
        end
    end)
    cp.hueBar:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    cp.hueBar:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)

    cp.hexInput:SetScript("OnEnterPressed", function(self)
        local nr, ng, nb = ParseHex6(self:GetText())
        if nr then
            curH, curS, curV = RGBtoHSV(nr, ng, nb)
            self:ClearFocus()
            UpdateVisualsAndNotify(true)
        else
            self:ClearFocus()
            UpdateVisualsAndNotify(false)
        end
    end)

    cp.applyBtn:SetScript("OnClick", function()
        local r, g, b = HSVtoRGB(curH, curS, curV)
        PushRecentColor(r, g, b, curA)
        if callback then callback(r, g, b, curA) end
        cp:Hide()
    end)

    local function CancelColorPick()
        if callback then callback(origR, origG, origB, origA) end
        cp:Hide()
    end
    cp.cancelBtn:SetScript("OnClick", CancelColorPick)
    cp.closeBtn:SetScript("OnClick", CancelColorPick)

    RefreshRecentSwatches()
    UpdateVisualsAndNotify(false)

    cp:ClearAllPoints()
    if anchorFrame then
        cp:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -6)
    else
        cp:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    cp:Show()
end

local function CreateDSOptionSlider(parent, width, minVal, maxVal, stepVal, formatFunc, getValFunc, setValFunc)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width or 256, 26)
    holder:EnableMouse(true)
    holder:EnableMouseWheel(true)

    local ar0, ag0, ab0 = UI.GetActiveAccentColor()
    local valText = holder:CreateFontString(nil, "OVERLAY")
    valText:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
    valText:SetWidth(52)
    valText:SetJustifyH("RIGHT")
    UI.SetFont(valText, 11, "", ar0, ag0, ab0, 1.0)
    holder.valText = valText

    local track = CreateFrame("Frame", nil, holder)
    track:SetPoint("LEFT", holder, "LEFT", 0, 0)
    track:SetPoint("RIGHT", valText, "LEFT", -10, 0)
    track:SetHeight(4)
    track.bg = UI.SolidTex(track, "BACKGROUND", 0, 0.035, 0.039, 0.051, 0.98)
    track.bg:SetAllPoints()
    track.border = UI.CreatePixelBorder(track, 1, 1, 1, 0.14, 1)

    local fill = UI.SolidTex(track, "ARTWORK", 1, ar0, ag0, ab0, 0.85)
    fill:SetPoint("TOPLEFT", track, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 1, 1)
    fill:SetWidth(1)
    track.FillBar = fill

    local thumb = UI.SolidTex(track, "OVERLAY", 3, 0.97, 0.98, 1.00, 1.0)
    thumb:SetSize(6, 14)
    if thumb.SetSnapToPixelGrid then
        thumb:SetSnapToPixelGrid(false)
        thumb:SetTexelSnappingBias(0)
    end
    holder.thumb = thumb

    local isDragging = false
    local lastCommittedValue = nil

    local function SnapValue(v)
        v = math.max(minVal, math.min(maxVal, v))
        if stepVal and stepVal > 0 then
            v = math.floor((v - minVal) / stepVal + 0.5) * stepVal + minVal
        end
        return math.max(minVal, math.min(maxVal, v))
    end

    local function RefreshSliderVisual(v, rawPct)
        local ar, ag, ab = UI.GetActiveAccentColor()
        fill:SetColorTexture(ar, ag, ab, 0.85)
        valText:SetTextColor(ar, ag, ab, 1.0)
        if isDragging or holder:IsMouseOver() then
            thumb:SetColorTexture(ar, ag, ab, 1.0)
        else
            thumb:SetColorTexture(0.97, 0.98, 1.00, 1.0)
        end
        local cur = SnapValue((type(v) == "number" and v) or getValFunc() or minVal)
        local pct = rawPct
        if pct == nil then
            pct = (maxVal > minVal) and ((cur - minVal) / (maxVal - minVal)) or 0
        end
        pct = math.max(0, math.min(1, pct))
        local tw = track:GetWidth()
        if not tw or tw <= 0 then tw = (width or 256) - 62 end
        fill:SetWidth(math.max(1, pct * math.max(1, tw - 2)))
        thumb:ClearAllPoints()
        thumb:SetPoint("CENTER", track, "LEFT", pct * tw, 0)
        valText:SetText(formatFunc and formatFunc(cur) or tostring(cur))
    end
    holder.RefreshVisual = RefreshSliderVisual
    holder.RefreshValue = RefreshSliderVisual

    local function UpdateFromCursor()
        if isDragging and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            isDragging = false
            holder:SetScript("OnUpdate", nil)
            RefreshSliderVisual()
            return
        end
        local scale = track:GetEffectiveScale()
        local cx = GetCursorPosition() / scale
        local left, tw = track:GetLeft(), track:GetWidth()
        if left and tw and tw > 0 then
            local pct = math.max(0, math.min(1, (cx - left) / tw))
            local stepped = SnapValue(minVal + pct * (maxVal - minVal))
            if stepped ~= lastCommittedValue then
                lastCommittedValue = stepped
                setValFunc(stepped)
            end
            RefreshSliderVisual(stepped, pct)
        end
    end

    holder:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            isDragging = true
            UpdateFromCursor()
            self:SetScript("OnUpdate", UpdateFromCursor)
        end
    end)
    holder:SetScript("OnMouseUp", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
        RefreshSliderVisual()
    end)
    holder:SetScript("OnHide", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
    end)
    holder:SetScript("OnEnter", function(self)
        RefreshSliderVisual()
        if GameTooltip then
            local ar, ag, ab = UI.GetActiveAccentColor()
            local hex = string.format("%02X%02X%02X", math.floor(ar * 255 + 0.5), math.floor(ag * 255 + 0.5), math.floor(ab * 255 + 0.5))
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(string.format("|cFF%sLeft-Click / Drag:|r |cFFE2E8F0Adjust value|r", hex))
            GameTooltip:AddLine(string.format("|cFF%sMousewheel:|r |cFFE2E8F0Fine-tune by 1 step|r", hex))
            GameTooltip:Show()
        end
    end)
    holder:SetScript("OnLeave", function()
        RefreshSliderVisual()
        if GameTooltip then GameTooltip:Hide() end
    end)
    holder:SetScript("OnMouseWheel", function(_, delta)
        local cur = getValFunc() or minVal
        local step = stepVal or ((maxVal - minVal) / 20)
        local newVal = SnapValue(cur + (delta > 0 and step or -step))
        lastCommittedValue = newVal
        setValFunc(newVal)
        RefreshSliderVisual(newVal)
    end)
    holder:SetScript("OnShow", function()
        C_Timer.After(0, function() RefreshSliderVisual() end)
    end)

    return holder
end
_G.DynamicSuite.UI.CreateSliderControl = CreateDSOptionSlider


    function UI.CreateSegmentedPills(parent, optionsList, getValFn, setValFn)
        local container = CreateFrame("Frame", nil, parent)
        container:SetHeight(26)
        local pills = {}
        local totalW = 0
        for idx, opt in ipairs(optionsList or {}) do
            local lbl = tostring(opt.label or opt.value or ""):gsub("^|cff%x%x%x%x%x%x", ""):gsub("|r$", "")
            local minW = opt.width or 66
            local pBtn = CreateFlatButton(container, minW, 24, lbl, false)
            pBtn._explicitWidth = opt.width
            local strW = pBtn.label and pBtn.label:GetStringWidth() or (#lbl * 7)
            local pillW = math.max(minW, math.ceil(strW + 32))
            pBtn:SetWidth(pillW)
            pBtn.optVal = opt.value
            pBtn.baseLabel = lbl
            pBtn.isNegativeOpt = UI.IsNegativePillOption(opt.value, lbl)
            pBtn.idleBgColor = { r = 0.078, g = 0.090, b = 0.122, a = 0.95 }
            pBtn.idleBorderColor = { r = 0.145, g = 0.165, b = 0.212, a = 0.95 }
            pBtn.idleTextColor = { r = 0.68, g = 0.72, b = 0.80, a = 1 }

            local offBar = UI.SolidTex(pBtn, "OVERLAY", 4, 0.973, 0.443, 0.443, 0.85)
            offBar:SetHeight(1.5)
            offBar:SetPoint("BOTTOMLEFT", pBtn, "BOTTOMLEFT", 1, 1)
            offBar:SetPoint("BOTTOMRIGHT", pBtn, "BOTTOMRIGHT", -1, 1)
            offBar:Hide()
            pBtn.OffBar = offBar

            local checkTex = UI.SolidTex(pBtn, "OVERLAY", 3, 1, 1, 1, 0.98)
            checkTex:SetSize(6, 6)
            checkTex:SetPoint("LEFT", pBtn, "LEFT", 8, 0)
            checkTex:Hide()
            pBtn.checkTex = checkTex

            if idx == 1 then
                pBtn:SetPoint("LEFT", container, "LEFT", 0, 0)
            else
                pBtn:SetPoint("LEFT", pills[idx - 1], "RIGHT", 4, 0)
                totalW = totalW + 4
            end
            totalW = totalW + pillW
            pBtn:SetScript("OnClick", function()
                if setValFn then setValFn(opt.value) end
                container:RefreshValue()
            end)
            pills[idx] = pBtn
        end
        container:SetWidth(math.max(80, totalW))

        function container:RefreshValue()
            local curVal = getValFn and getValFn()
            local ar, ag, ab = UI.GetActiveAccentColor()
            local accentCol = { r = ar, g = ag, b = ab }
            local recomputedW = 0
            for idx, pBtn in ipairs(pills) do
                local isSel = (pBtn.optVal == curVal)
                pBtn:SetSelected(isSel, accentCol)
                local rawW = pBtn.label and ((pBtn.label.GetUnboundedStringWidth and pBtn.label:GetUnboundedStringWidth()) or pBtn.label:GetStringWidth()) or 0
                local strW = math.max(rawW or 0, #(pBtn.baseLabel or "") * 6.8)
                local pillW = math.max(pBtn._explicitWidth or 66, pBtn._minWidth or 66, math.ceil(strW + 20))
                pBtn:SetWidth(pillW)
                if idx > 1 then recomputedW = recomputedW + 4 end
                recomputedW = recomputedW + pillW
                if pBtn.checkTex then
                    pBtn.checkTex:Hide()
                    pBtn.checkTex:SetColorTexture(1, 1, 1, 0.98)
                end
                if pBtn.label then
                    pBtn.label:ClearAllPoints()
                    if isSel then
                        pBtn.label:SetPoint("LEFT", pBtn, "LEFT", 6, 0)
                        pBtn.label:SetPoint("RIGHT", pBtn, "RIGHT", -6, 0)
                    else
                        pBtn.label:SetPoint("LEFT", pBtn, "LEFT", 6, 0)
                        pBtn.label:SetPoint("RIGHT", pBtn, "RIGHT", -6, 0)
                    end
                    pBtn.label:SetJustifyH("CENTER")
                end
            end
            container:SetWidth(math.max(80, recomputedW))
        end

        container:HookScript("OnShow", function(self) self:RefreshValue() end)
        container:RefreshValue()
        return container
    end

    local function CreateSpaciousOptionRow(parentFrame, rowIndex, rowTitle, rowDesc)
        local row = CreateFrame("Frame", nil, parentFrame)
        local yPos = -52 - ((rowIndex - 1) * 58)
        row:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, yPos)
        row:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", 0, yPos)
        row:SetHeight(52)
        row._titleTopY = -10
        row._subGapY = -3

        row.bg = UI.SolidTex(row, "BACKGROUND", 0, UI.COLORS.CARD_BG.r, UI.COLORS.CARD_BG.g, UI.COLORS.CARD_BG.b, 0.92)
        row.bg:SetAllPoints()
        UI.CreatePixelBorder(row, 1, 1, 1, 0.08, 2)

        local t = row:CreateFontString(nil, "OVERLAY")
        t:SetPoint("TOPLEFT", row, "TOPLEFT", 16, row._titleTopY)
        t:SetPoint("RIGHT", row, "RIGHT", -420, 0)
        t:SetJustifyH("LEFT")
        t:SetWordWrap(false)
        UI.SetFont(t, 12, "", 1, 1, 1, 0.96)
        t:SetText(rowTitle)
        row.titleText = t
        row.title = t

        local d = row:CreateFontString(nil, "OVERLAY")
        d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, row._subGapY)
        d:SetPoint("RIGHT", row, "RIGHT", -420, 0)
        d:SetJustifyH("LEFT")
        d:SetWordWrap(true); if d.SetMaxLines then d:SetMaxLines(2) end
        UI.SetFont(d, 10, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 0.92)
        d:SetText(rowDesc)
        row.descText = d
        row.sub = d

        function row:BindRightControl(ctrl)
            if not ctrl then return end
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", row, "TOPLEFT", 16, row._titleTopY or -10)
            t:SetPoint("RIGHT", ctrl, "LEFT", -16, 0)
            d:ClearAllPoints()
            d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, row._subGapY or -3)
            d:SetPoint("RIGHT", ctrl, "LEFT", -16, 0)
        end

        return row
    end
UI.CreateSpaciousOptionRow = CreateSpaciousOptionRow
UI.CreateDSOptionSlider = CreateDSOptionSlider
UI.OpenDSColorPicker = OpenDSColorPicker

--------------------------------------------------------------------------------
-- Main Interface (/dl & /ds) - 980x680 Resizable Window, 3-Zone Header & Left Suite Rail
--------------------------------------------------------------------------------
function addonTable.CreateMainConfigUI()
    if mainFrame and mainFrame._initComplete then return mainFrame end
    UI.CloseAllPopups = UI.CloseAllPopups or function() end
    if DynamicLoadDB and (DynamicLoadDB.stagedProfile or DynamicLoadDB.loadedProfile or DynamicLoadDB.activeProfile) then
        selectedTabKey = DynamicLoadDB.stagedProfile or DynamicLoadDB.loadedProfile or DynamicLoadDB.activeProfile
        if addonTable.SetSelectedTabKey then addonTable.SetSelectedTabKey(selectedTabKey) end
    end
    UI.RefreshPaletteCache()

    local g = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
    if g.windowWidth and g.windowWidth < 980 then g.windowWidth = 1040 end
    if DynamicLoadDB and DynamicLoadDB.windowWidth and DynamicLoadDB.windowWidth < 980 then DynamicLoadDB.windowWidth = 1040 end
    local PANEL_W = math.max(980, math.min(1440, g.windowWidth or (DynamicLoadDB and DynamicLoadDB.windowWidth) or 1040))
    local PANEL_H = math.max(640, math.min(920,  g.windowHeight or (DynamicLoadDB and DynamicLoadDB.windowHeight) or 680))
    local RAIL_W  = 204
    local HDR_H   = 46
    local DOCK_H  = 38

    local f = _G.DynamicSuiteMainFrame or _G.DynamicLoadMainFrame or CreateFrame("Frame", "DynamicSuiteMainFrame", UIParent); _G.DynamicSuiteMainFrame = f; _G.DynamicLoadMainFrame = f; mainFrame = f; addonTable.mainFrame = f
    f:SetSize(PANEL_W, PANEL_H)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then
        f:SetResizeBounds(980, 640, 1440, 920)
    else
        if f.SetMinResize then f:SetMinResize(980, 640) end
        if f.SetMaxResize then f:SetMaxResize(1440, 920) end
    end
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:RegisterForDrag("LeftButton")

    local rawSavedScale = g.windowScale or (DynamicLoadDB and DynamicLoadDB.windowScale) or 1.0
    local savedScale = math.max(0.80, math.min(1.20, math.floor((rawSavedScale * 20) + 0.5) / 20))
    f:SetScale(savedScale)

    local savedAlpha = math.max(0.50, math.min(1.00, g.windowAlpha or (DynamicLoadDB and DynamicLoadDB.windowAlpha) or 0.98))
    f:SetAlpha(savedAlpha)

    function addonTable.UpdateMainWindowClampInsets(targetFrame)
        local wf = targetFrame or mainFrame
        if not wf then return end
        local w = (wf.GetWidth and wf:GetWidth()) or 1040
        local h = (wf.GetHeight and wf:GetHeight()) or 680
        local keepVisibleX = math.max(96, math.floor(w * 0.12))
        local allowOffX = math.max(0, w - keepVisibleX)
        local allowOffBottom = math.max(0, h - 48)
        if wf.SetClampedToScreen then wf:SetClampedToScreen(true) end
        if wf.SetClampRectInsets then
            -- Allow ~88% off left/right and down to 48px top header, while keeping top <= 0 inside UIParent
            wf:SetClampRectInsets(allowOffX, -allowOffX, 0, allowOffBottom)
        end
    end

    function addonTable.SaveMainWindowPosition(targetFrame)
        local wf = targetFrame or mainFrame
        if not wf or not wf.GetCenter or not UIParent or not UIParent.GetCenter then return end
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or nil
        if not gTbl then return end
        local fCx, fCy = wf:GetCenter()
        local uCx, uCy = UIParent:GetCenter()
        if not fCx or not fCy or not uCx or not uCy then return end
        local fScale = (wf.GetEffectiveScale and wf:GetEffectiveScale()) or 1
        local uScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        if fScale <= 0 then fScale = 1 end
        if uScale <= 0 then uScale = 1 end
        local relScale = fScale / uScale
        local lx = math.floor(((fCx - uCx) / relScale) + 0.5)
        local ly = math.floor(((fCy - uCy) / relScale) + 0.5)
        gTbl.windowPos = { point = "CENTER", relativePoint = "CENTER", x = lx, y = ly }
    end

    function addonTable.ApplySavedMainWindowPosition(targetFrame)
        local wf = targetFrame or mainFrame
        if not wf then return end
        addonTable.UpdateMainWindowClampInsets(wf)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local pos = gTbl.windowPos
        if type(pos) == "table" and pos.x ~= nil and pos.y ~= nil then
            local fScale = (wf.GetEffectiveScale and wf:GetEffectiveScale()) or 1
            local uScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
            if fScale <= 0 then fScale = 1 end
            if uScale <= 0 then uScale = 1 end
            local relScale = fScale / uScale
            local screenW = ((UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920) / relScale
            local screenH = ((UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080) / relScale
            local w = (wf.GetWidth and wf:GetWidth()) or 1040
            local h = (wf.GetHeight and wf:GetHeight()) or 680
            local keepVisibleX = math.max(96, math.floor(w * 0.12))
            local allowOffX = math.max(0, w - keepVisibleX)
            local allowOffBottom = math.max(0, h - 48)
            local minX = -(screenW / 2) + (w / 2) - allowOffX
            local maxX = (screenW / 2) - (w / 2) + allowOffX
            local minY = -(screenH / 2) + (h / 2) - allowOffBottom
            local maxY = (screenH / 2) - (h / 2)
            local cx = math.max(minX, math.min(maxX, tonumber(pos.x) or 0))
            local cy = math.max(minY, math.min(maxY, tonumber(pos.y) or 0))
            cx = math.floor(cx + 0.5)
            cy = math.floor(cy + 0.5)
            pos.x = cx
            pos.y = cy
            wf:ClearAllPoints()
            wf:SetPoint("CENTER", UIParent, "CENTER", cx, cy)
        else
            wf:ClearAllPoints()
            wf:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end

    function addonTable.ResetMainWindowPosition()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or nil
        if gTbl then
            gTbl.windowPos = nil
        end
        if mainFrame then
            addonTable.UpdateMainWindowClampInsets(mainFrame)
            mainFrame:ClearAllPoints()
            mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        print("|cFFCBD5E1DynamicSuite:|r Window position reset to center.")
    end

    function addonTable.ReclampMainWindowToScreen()
        if mainFrame then
            addonTable.ApplySavedMainWindowPosition(mainFrame)
        end
    end

    addonTable.ApplySavedMainWindowPosition(f)

    f:SetScript("OnDragStart", function(self)
        CloseContextMenu()
        if dsColorPicker then dsColorPicker:Hide() end
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        addonTable.SaveMainWindowPosition(self)
    end)

    -- Zero-FPS-Drop C++ Anchor Stretching: OnSizeChanged only updates scrollChild width & thin scrollbar
    f:SetScript("OnSizeChanged", function(_, newW, newH)
        addonTable.UpdateMainWindowClampInsets(f)
        if f.SyncWorkspaceGeometry then
            f.SyncWorkspaceGeometry()
        end
        if f.scrollChild and f.scrollFrame then
            local sw = f.scrollFrame:GetWidth()
            if sw and sw > 50 then
                f.scrollChild:SetWidth(sw)
            else
                f.scrollChild:SetWidth(math.max(400, (newW or 980) - RAIL_W - 30))
            end
        end
        if f.ReflowDlTopTrack then
            f.ReflowDlTopTrack()
        end
        if f.UpdateThinScrollBar then
            f.UpdateThinScrollBar()
        end
        if f.UpdateRailScrollBar then
            f.UpdateRailScrollBar()
        end
    end)

    f:HookScript("OnHide", function()
        if InCombatLockdown() and not addonTable._suppressCombatManualClose then
            if addonTable._combatCollapsedState then
                addonTable._combatCollapsedState.manuallyClosedInCombat = true
                addonTable._combatCollapsedState.wasOpen = false
            end
        end
    end)

    table.insert(UISpecialFrames, "DynamicLoadMainFrame")
    f:Hide()

    f.bg = UI.SolidTex(f, "BACKGROUND", 0, UI.COLORS.PANEL_BG.r, UI.COLORS.PANEL_BG.g, UI.COLORS.PANEL_BG.b, UI.COLORS.PANEL_BG.a)
    f.bg:SetAllPoints()
    UI.CreatePixelBorder(f, 1, 1, 1, UI.COLORS.BORDER_OUTER.a, 4)
    f.themeCards = {}

    local pName = addonTable.GetPlayer and addonTable.GetPlayer() or UnitName("player")
    local altPillBtn
    local PopulatePendingReloadTooltip
    local UpdateStatusBar
    local railModuleCards = {}
    local RefreshLeftRailVisuals
    local UpdateAllTabVisuals
    local UpdateAutoToggleVisual
    -- CreateSpaciousOptionRow is defined at file scope
    local floatingEditPill

    ----------------------------------------------------------------------------
    -- 1. CLEAN 3-ZONE TOP HEADER BAR (46px Height - Zero Squished Status Bar)
    --    Zone 1 (Left):   L10-B D-Monogram + "DynamicSuite" + Clickable [v1.3.0]
    --    Zone 2 (Center): Spacious 1-Line Live Context Status Capsule
    --    Zone 3 (Right):  ONLY [All Characters v] + [X] Close Button
    ----------------------------------------------------------------------------
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    header:SetHeight(HDR_H)
    f.header = header

    header.bg = UI.SolidTex(header, "BACKGROUND", 1, UI.COLORS.HEADER_BG.r, UI.COLORS.HEADER_BG.g, UI.COLORS.HEADER_BG.b, 1.0)
    header.bg:SetAllPoints()

    header.accentTop = UI.SolidTex(header, "OVERLAY", 5, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 1)
    header.accentTop:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    header.accentTop:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
    header.accentTop:SetHeight(2)
    f.headerAccentTop = header.accentTop

    header.divider = UI.SolidTex(header, "OVERLAY", 2, 1, 1, 1, UI.COLORS.BORDER.a)
    header.divider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    header.divider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    header.divider:SetHeight(1)

    local combatBanner = CreateFrame("Frame", nil, f)
    combatBanner:SetHeight(24)
    combatBanner:SetPoint("TOPLEFT", f, "TOPLEFT", RAIL_W + 1, -HDR_H)
    combatBanner:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -HDR_H)
    combatBanner:SetFrameLevel(header:GetFrameLevel() + 15)
    combatBanner.bg = UI.SolidTex(combatBanner, "BACKGROUND", 0, 0.16, 0.10, 0.02, 0.96)
    combatBanner.bg:SetAllPoints()
    combatBanner.border = UI.SolidTex(combatBanner, "BORDER", 1, 0.96, 0.62, 0.04, 0.55)
    combatBanner.border:SetPoint("BOTTOMLEFT", combatBanner, "BOTTOMLEFT", 0, 0)
    combatBanner.border:SetPoint("BOTTOMRIGHT", combatBanner, "BOTTOMRIGHT", 0, 0)
    combatBanner.border:SetHeight(1)
    combatBanner.dot = UI.SolidTex(combatBanner, "OVERLAY", 2, 0.96, 0.62, 0.04, 1)
    combatBanner.dot:SetSize(6, 6)
    combatBanner.dot:SetPoint("LEFT", combatBanner, "LEFT", 12, 0)
    combatBanner.label = combatBanner:CreateFontString(nil, "OVERLAY")
    combatBanner.label:SetPoint("LEFT", combatBanner.dot, "RIGHT", 8, 0)
    UI.SetFont(combatBanner.label, 11, "", 0.99, 0.80, 0.30, 0.98)
    combatBanner.label:SetText("In Combat \226\128\148 Protected settings locked until combat ends")
    combatBanner:Hide()
    f.combatBanner = combatBanner

    -- Zone 1 (Left): L10-B Two-Tone Colinear Speed-Cut "D" Brand Logo + Title + Clickable [v1.3.0]
    local emblemBg = CreateFrame("Frame", nil, header)
    emblemBg:SetSize(28, 28)
    emblemBg:SetPoint("LEFT", header, "LEFT", 14, 0)
    emblemBg.tex = UI.SolidTex(emblemBg, "BACKGROUND", 1, 0.04, 0.05, 0.07, 0.98)
    emblemBg.tex:SetAllPoints()
    UI.CreatePixelBorder(emblemBg, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.85, 3)
    UI.DrawBrandEmblem(emblemBg, 28)
    f.emblemBg = emblemBg

    do
    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetPoint("LEFT", emblemBg, "RIGHT", 10, 0)
    UI.SetFont(title, 15, "", 1, 1, 1, 0.98)
    title:SetText(UI.FormatTwoToneBrand("Suite"))
    f.headerTitle = title

    local verPill = CreateFlatButton(header, 1, 20, "", false)
    verPill:SetPoint("LEFT", title, "RIGHT", 0, 0)
    verPill:Hide()
    f.verPill = verPill

    -- Zone 3 (Right): [All Characters v] + [-] Minimize + [X] Close Button
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(26, 26)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -12, 0)
    closeBtn.bg = UI.SolidTex(closeBtn, "BACKGROUND", 2, 1, 1, 1, 0.03)
    closeBtn.bg:SetAllPoints()
    UI.CreatePixelBorder(closeBtn, 1, 1, 1, 0.12, 3)

    local closeLine1 = UI.SolidTex(closeBtn, "OVERLAY", 3, 1, 1, 1, 0.70)
    closeLine1:SetSize(12, 1.5)
    closeLine1:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    if closeLine1.SetRotation then closeLine1:SetRotation(math.rad(45)) end

    local closeLine2 = UI.SolidTex(closeBtn, "OVERLAY", 3, 1, 1, 1, 0.70)
    closeLine2:SetSize(12, 1.5)
    closeLine2:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    if closeLine2.SetRotation then closeLine2:SetRotation(math.rad(-45)) end

    closeBtn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(1, 0.25, 0.25, 0.18)
        self.dsBorder:SetColor(1, 0.35, 0.35, 0.75)
        closeLine1:SetColorTexture(1, 0.35, 0.35, 1)
        closeLine2:SetColorTexture(1, 0.35, 0.35, 1)
    end)
    closeBtn:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(1, 1, 1, 0.03)
        self.dsBorder:SetColor(1, 1, 1, 0.12)
        closeLine1:SetColorTexture(1, 1, 1, 0.70)
        closeLine2:SetColorTexture(1, 1, 1, 0.70)
    end)
    closeBtn:SetScript("OnClick", function()
        f._minimizedForHudDrag = false
        if f.minimizedBar then f.minimizedBar:Hide() end
        if UI.CloseAllPopups then UI.CloseAllPopups() end
        f:Hide()
        CloseContextMenu()
    end)

    local minBtn = CreateFrame("Button", nil, header)
    minBtn:SetSize(26, 26)
    minBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    minBtn.bg = UI.SolidTex(minBtn, "BACKGROUND", 2, 1, 1, 1, 0.03)
    minBtn.bg:SetAllPoints()
    UI.CreatePixelBorder(minBtn, 1, 1, 1, 0.12, 3)

    local minBarLine = UI.SolidTex(minBtn, "OVERLAY", 3, 1, 1, 1, 0.75)
    minBarLine:SetSize(10, 2)
    minBarLine:SetPoint("CENTER", minBtn, "CENTER", 0, 0)
    minBtn:SetScript("OnEnter", function(self)
        local ar, ag, ab = UI.GetActiveAccentColor()
        self.bg:SetColorTexture(ar, ag, ab, 0.18)
        self.dsBorder:SetColor(ar, ag, ab, 0.85)
        minBarLine:SetColorTexture(1, 1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Minimize DynamicSuite", 1, 1, 1)
        GameTooltip:AddLine("Collapses the window into a compact floating bar so you can inspect your UI.", 0.82, 0.86, 0.92, true)
        GameTooltip:Show()
    end)
    minBtn:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(1, 1, 1, 0.03)
        self.dsBorder:SetColor(1, 1, 1, 0.12)
        minBarLine:SetColorTexture(1, 1, 1, 0.75)
        GameTooltip:Hide()
    end)
    minBtn:SetScript("OnClick", function()
        if not f.minimizedBar then
            local mb = CreateFrame("Frame", "DynamicSuiteMinimizedBar", UIParent)
            mb:SetSize(528, 38)
            function mb:RestoreSavedPosition()
                local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
                local pos = gTbl.minimizedBarPos
                self:ClearAllPoints()
                if type(pos) == "table" and pos.x ~= nil and pos.y ~= nil then
                    self:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or pos.point or "CENTER", pos.x, pos.y)
                else
                    self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                end
            end
            mb:RestoreSavedPosition()
            mb:SetFrameStrata("DIALOG")
            mb:SetToplevel(true)
            mb:SetClampedToScreen(true)
            mb:EnableMouse(true)
            mb:SetMovable(true)
            mb:RegisterForDrag("LeftButton")
            mb:SetScript("OnDragStart", mb.StartMoving)
            mb:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                local cx, cy = self:GetCenter()
                local ux, uy = UIParent:GetCenter()
                if cx and cy and ux and uy then
                    local dx = math.floor((cx - ux) + 0.5)
                    local dy = math.floor((cy - uy) + 0.5)
                    self:ClearAllPoints()
                    self:SetPoint("CENTER", UIParent, "CENTER", dx, dy)
                    local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
                    if gTbl then
                        gTbl.minimizedBarPos = { point = "CENTER", relPoint = "CENTER", x = dx, y = dy }
                    end
                end
            end)
            mb.bg = UI.SolidTex(mb, "BACKGROUND", 0, 0.03, 0.035, 0.048, 0.98)
            mb.bg:SetAllPoints()
            UI.CreatePixelBorder(mb, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.95, 3)

            local mbLogo = CreateFrame("Frame", nil, mb)
            mbLogo:SetSize(22, 22)
            mbLogo:SetPoint("LEFT", mb, "LEFT", 13, 0)
            UI.CreatePixelBorder(mbLogo, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.85, 3)
            UI.DrawBrandEmblem(mbLogo, 22)
            mb.logo = mbLogo

            local mbCloseBtn = CreateFrame("Button", nil, mb)
            mbCloseBtn:SetSize(26, 26)
            mbCloseBtn:SetPoint("RIGHT", mb, "RIGHT", -12, 0)
            mbCloseBtn.bg = UI.SolidTex(mbCloseBtn, "BACKGROUND", 2, 1, 1, 1, 0.03)
            mbCloseBtn.bg:SetAllPoints()
            UI.CreatePixelBorder(mbCloseBtn, 1, 1, 1, 0.12, 3)

            local mbCloseLine1 = UI.SolidTex(mbCloseBtn, "OVERLAY", 3, 1, 1, 1, 0.70)
            mbCloseLine1:SetSize(12, 1.5)
            mbCloseLine1:SetPoint("CENTER", mbCloseBtn, "CENTER", 0, 0)
            if mbCloseLine1.SetRotation then mbCloseLine1:SetRotation(math.rad(45)) end

            local mbCloseLine2 = UI.SolidTex(mbCloseBtn, "OVERLAY", 3, 1, 1, 1, 0.70)
            mbCloseLine2:SetSize(12, 1.5)
            mbCloseLine2:SetPoint("CENTER", mbCloseBtn, "CENTER", 0, 0)
            if mbCloseLine2.SetRotation then mbCloseLine2:SetRotation(math.rad(-45)) end

            mbCloseBtn:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(1, 0.25, 0.25, 0.18)
                self.dsBorder:SetColor(1, 0.35, 0.35, 0.75)
                mbCloseLine1:SetColorTexture(1, 0.35, 0.35, 1)
                mbCloseLine2:SetColorTexture(1, 0.35, 0.35, 1)
            end)
            mbCloseBtn:SetScript("OnLeave", function(self)
                self.bg:SetColorTexture(1, 1, 1, 0.03)
                self.dsBorder:SetColor(1, 1, 1, 0.12)
                mbCloseLine1:SetColorTexture(1, 1, 1, 0.70)
                mbCloseLine2:SetColorTexture(1, 1, 1, 0.70)
            end)
            mbCloseBtn:SetScript("OnClick", function()
                if UI.CloseAllPopups then UI.CloseAllPopups() end
                mb:Hide()
                f:Hide()
            end)
            mb.closeBtn = mbCloseBtn

            local mbRestoreBtn = CreateFlatButton(mb, 118, 26, "Restore Window", true)
            mbRestoreBtn:SetPoint("RIGHT", mbCloseBtn, "LEFT", -6, 0)
            mbRestoreBtn.isSelected = true
            mbRestoreBtn:SetScript("OnClick", function()
                mb:Hide()
                f:Show()
            end)
            mb.restoreBtn = mbRestoreBtn

            local mbHudBtn = CreateFlatButton(mb, 68, 26, "HUD", false)
            mbHudBtn:SetPoint("RIGHT", mbRestoreBtn, "LEFT", -6, 0)
            local mbHudIcon = mbHudBtn:CreateTexture(nil, "OVERLAY", nil, 3)
            mbHudIcon:SetSize(12, 12)
            mbHudIcon:SetPoint("LEFT", mbHudBtn, "LEFT", 9, 0)
            mbHudIcon:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_grid.tga")
            mbHudIcon:SetVertexColor(1, 1, 1, 0.98)
            mbHudBtn.iconTex = mbHudIcon
            mbHudBtn.label:ClearAllPoints()
            mbHudBtn.label:SetPoint("LEFT", mbHudIcon, "RIGHT", 5, 0)
            mbHudBtn.label:SetPoint("RIGHT", mbHudBtn, "RIGHT", -6, 0)
            mbHudBtn.label:SetJustifyH("CENTER")
            mbHudBtn:SetScript("OnClick", function()
                mb:Hide()
                if addonTable.EnterHudEditMode then
                    addonTable.EnterHudEditMode("ALL")
                else
                    addonTable.OpenWorkspaceView("EDIT_MODE")
                end
            end)
            mb.hudBtn = mbHudBtn

            local mbTitle = mb:CreateFontString(nil, "OVERLAY")
            mbTitle:SetPoint("LEFT", mbLogo, "RIGHT", 10, 0)
            mbTitle:SetPoint("RIGHT", mbHudBtn, "LEFT", -10, 0)
            mbTitle:SetJustifyH("LEFT")
            mbTitle:SetWordWrap(false)
            UI.SetFont(mbTitle, 12, "", 1, 1, 1, 1)
            mbTitle:SetText(UI.FormatTwoToneBrand("Suite") .. "   |cFF94A3B8Window Minimized|r")
            mb.title = mbTitle

            function mb:ReflowBarWidth()
                self:SetSize(528, 38)
            end
            mb:SetScript("OnShow", function(self)
                self:ReflowBarWidth()
            end)
            mb:ReflowBarWidth()
            f.minimizedBar = mb
        end
        local ar, ag, ab = UI.GetActiveAccentColor()
        local surf = UI.GetActiveSurfaceColors()
        f.minimizedBar.bg:SetColorTexture(surf.header.r, surf.header.g, surf.header.b, 0.98)
        f.minimizedBar.dsBorder:SetColor(ar, ag, ab, 0.95)
        if f.minimizedBar.logo and f.minimizedBar.logo.SetAccentColor then
            f.minimizedBar.logo:SetAccentColor(ar, ag, ab, 1)
        end
        f.minimizedBar.title:SetText(UI.FormatTwoToneBrand("Suite") .. "  |cFF94A3B8(Minimized)|r")
        if f.minimizedBar.restoreBtn then
            f.minimizedBar.restoreBtn:SetSelected(true, { r = ar, g = ag, b = ab })
        end
        if f.minimizedBar.hudBtn then
            f.minimizedBar.hudBtn:SetSelected(false)
        end
        if f.minimizedBar.ReflowBarWidth then f.minimizedBar:ReflowBarWidth() end
        if f.minimizedBar.RestoreSavedPosition then f.minimizedBar:RestoreSavedPosition() end
        UI.CloseAllPopups()
        f:Hide()
        f.minimizedBar:Show()
    end)

    local hdrHudBtn = CreateFlatButton(header, 68, 26, "HUD", true)
    hdrHudBtn:SetPoint("RIGHT", minBtn, "LEFT", -6, 0)
    local hdrHudIcon = hdrHudBtn:CreateTexture(nil, "OVERLAY", nil, 3)
    hdrHudIcon:SetSize(12, 12)
    hdrHudIcon:SetPoint("LEFT", hdrHudBtn, "LEFT", 9, 0)
    hdrHudIcon:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_grid.tga")
    hdrHudIcon:SetVertexColor(1, 1, 1, 0.98)
    hdrHudBtn.iconTex = hdrHudIcon
    hdrHudBtn.label:ClearAllPoints()
    hdrHudBtn.label:SetPoint("LEFT", hdrHudIcon, "RIGHT", 5, 0)
    hdrHudBtn.label:SetPoint("RIGHT", hdrHudBtn, "RIGHT", -6, 0)
    hdrHudBtn.label:SetJustifyH("CENTER")
    hdrHudBtn:SetScript("OnClick", function()
        if addonTable.EnterHudEditMode then
            addonTable.EnterHudEditMode("ALL")
        else
            addonTable.OpenWorkspaceView("EDIT_MODE")
        end
    end)
    hdrHudBtn.OnCustomEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("HUD Edit Mode", 1, 1, 1)
        GameTooltip:AddLine("Unlock, align, and scale all 4 on-screen DynamicSuite HUD bars.", 0.82, 0.86, 0.92, true)
        GameTooltip:Show()
    end
    hdrHudBtn.OnCustomLeave = function()
        GameTooltip:Hide()
    end
    f.hdrHudBtn = hdrHudBtn

    altPillBtn = CreateFlatButton(header, 96, 26, "Global", false)
    altPillBtn:SetPoint("RIGHT", hdrHudBtn, "LEFT", -6, 0)
    altPillBtn.label:ClearAllPoints()
    altPillBtn.label:SetPoint("LEFT", altPillBtn, "LEFT", 10, 0)
    altPillBtn.chevron = UI.CreateChevronDown(altPillBtn, "RIGHT", altPillBtn, "RIGHT", -8, 0, 1, 1, 1, 0.65)
    altPillBtn:SetScript("OnClick", function(self)
        OpenAltDropdown(self, f)
    end)
    altPillBtn:HookScript("OnHide", function()
        CloseAltDropdown()
    end)
    altPillBtn.OnCustomEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Profile Scope & Alt Cloner", 1, 1, 1)
        GameTooltip:AddLine("Switch between Global (Account-Wide) and Character-Specific profiles, or clone loadouts from an alt.", 0.82, 0.86, 0.92, true)
        GameTooltip:Show()
    end
    altPillBtn.OnCustomLeave = function()
        GameTooltip:Hide()
    end
    f.altPillBtn = altPillBtn

    local function RefreshScopePillLabel()
        local curScope = (addonTable.GetCharScopeMode and addonTable.GetCharScopeMode()) or "GLOBAL"
        if curScope == "CHARACTER" then
            local cName = (addonTable.GetPlayer and addonTable.GetPlayer()) or (UnitName("player") or "Char")
            local _, pClass = UnitClass("player")
            local pColor = (RAID_CLASS_COLORS and pClass and RAID_CLASS_COLORS[pClass]) or UI.COLORS.ACCENT
            altPillBtn.label:SetText(string.format("|cFF%02x%02x%02x%s|r", pColor.r * 255, pColor.g * 255, pColor.b * 255, cName))
        else
            altPillBtn.label:SetText("Global")
        end
    end
    f.RefreshScopePillLabel = RefreshScopePillLabel
    RefreshScopePillLabel()

    -- Zone 2 (Center): Spacious 1-Line Live Context Status Capsule (Anchored 14px right of title!)
    local statusCapsule = CreateFrame("Button", nil, header)
    statusCapsule:ClearAllPoints()
    statusCapsule:SetPoint("LEFT", title, "RIGHT", 14, 0)
    statusCapsule:SetPoint("RIGHT", altPillBtn, "LEFT", -12, 0)
    statusCapsule:SetHeight(26)
    statusCapsule.bg = UI.SolidTex(statusCapsule, "BACKGROUND", 2, 1, 1, 1, 0.025)
    statusCapsule.bg:SetAllPoints()
    UI.CreatePixelBorder(statusCapsule, 1, 1, 1, 0.08, 3)
    f.statusBox = statusCapsule
    f.statusCapsule = statusCapsule

    local statusContentHolder = CreateFrame("Frame", nil, statusCapsule)
    statusContentHolder:SetSize(200, 20)
    statusContentHolder:SetPoint("CENTER", statusCapsule, "CENTER", 0, 0)

    local statusPip = UI.SolidTex(statusContentHolder, "OVERLAY", 5, 0.133, 0.773, 0.369, 1.0)
    statusPip:SetSize(6, 6)
    statusPip:SetPoint("LEFT", statusContentHolder, "LEFT", 0, 0)
    f.statusPip = statusPip

    local statusText = statusContentHolder:CreateFontString(nil, "OVERLAY")
    statusText:SetPoint("LEFT", statusPip, "RIGHT", 7, 0)
    statusText:SetPoint("RIGHT", statusCapsule, "RIGHT", -14, 0)
    statusText:SetJustifyH("LEFT")
    statusText:SetWordWrap(false)
    UI.SetFont(statusText, 11, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 1)
    f.statusText = statusText

    local lastStatusRawStr = ""
    local function SetStatusCapsuleDisplay(rawStr)
        lastStatusRawStr = rawStr or ""
        local clean = tostring(lastStatusRawStr):gsub("^|c%x%x%x%x%x%x%x%x%*|r%s*", ""):gsub("^%*%s*", ""):gsub("%s+|%s+", "  |  ")
        if clean:find("Loaded:") then
            statusPip:Hide()
            statusText:ClearAllPoints()
            statusText:SetPoint("LEFT", statusContentHolder, "LEFT", 0, 0)
            statusText:SetPoint("RIGHT", statusCapsule, "RIGHT", -14, 0)
        else
            statusPip:Show()
            statusText:ClearAllPoints()
            statusText:SetPoint("LEFT", statusPip, "RIGHT", 7, 0)
            statusText:SetPoint("RIGHT", statusCapsule, "RIGHT", -14, 0)
        end
        UI.SetFont(statusText, 11, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 1)
        statusText:SetText(clean)
        local boxW = statusCapsule:GetWidth() or 510
        if boxW < 200 then boxW = 510 end
        local tw = statusText:GetStringWidth() or 220
        if (tw + 36) > boxW then
            UI.SetFont(statusText, 10, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 1)
            statusText:SetText(clean)
            tw = statusText:GetStringWidth() or 200
        end
        local maxW = math.max(120, boxW - 28)
        local pad = statusPip:IsShown() and 14 or 0
        statusContentHolder:SetWidth(math.min(maxW, tw + pad))
    end
    statusCapsule:SetScript("OnSizeChanged", function()
        if lastStatusRawStr ~= "" then
            SetStatusCapsuleDisplay(lastStatusRawStr)
        end
    end)

    PopulatePendingReloadTooltip = function(ownerFrame, anchorPt)
        if addonTable.GetSelectedTabKey then selectedTabKey = addonTable.GetSelectedTabKey() end
        local deltaCount, pendingMap = 0, {}
        if addonTable.CalculateAddonDelta then
            deltaCount, pendingMap = addonTable.CalculateAddonDelta(selectedTabKey)
        end
        GameTooltip:SetOwner(ownerFrame, anchorPt or "ANCHOR_BOTTOM")
        GameTooltip:SetText("Live Profile & Pending Reload Status", 1, 1, 1)
        if deltaCount and deltaCount > 0 and pendingMap then
            GameTooltip:AddLine(string.format("%d Addon Change(s) Pending Reload:", deltaCount), 0.96, 0.72, 0.18)
            local shown = 0
            for addonKey, willLoad in pairs(pendingMap) do
                shown = shown + 1
                if shown <= 12 then
                    if willLoad then
                        GameTooltip:AddLine(string.format("  |cFF22C55E+ %s (Will Load)|r", tostring(addonKey)), 1, 1, 1)
                    else
                        GameTooltip:AddLine(string.format("  |cFFF59E0B- %s (Will Unload)|r", tostring(addonKey)), 1, 1, 1)
                    end
                end
            end
            if shown > 12 then
                GameTooltip:AddLine(string.format("  ...and %d more", shown - 12), 0.70, 0.74, 0.80)
            end
            GameTooltip:AddLine(" ")
            if securityFilter == "PENDING" then
                GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Return addon list to All Addons view|r", 1, 1, 1)
            else
                GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Filter addon list to Pending Reload changes|r", 1, 1, 1)
            end
        else
            GameTooltip:AddLine("All addons are in sync with the current session (0 Pending Reload).", 0.133, 0.773, 0.369)
            if securityFilter == "PENDING" then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Return to All Addons view|r", 1, 1, 1)
            end
        end

        if addonTable.IsManualOverrideActive and addonTable.IsManualOverrideActive() then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cFFF5B82EManual Override Active:|r |cFFE2E8F0Profile locked to chosen loadout.|r", 1, 1, 1)
            GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFF22C55E[Resume Auto-Switch]|r |cFFE2E8F0(Restore automatic zone switching)|r", 1, 1, 1)
        end
        GameTooltip:Show()
    end

    f.PopulatePendingReloadTooltip = PopulatePendingReloadTooltip
    local resumePromptFrame = nil
    local function ShowResumePrompt(anchor)
        CloseContextMenu()
        if not resumePromptFrame then
            resumePromptFrame = CreateFrame("Frame", "DynamicLoadResumePrompt", UIParent)
            resumePromptFrame:SetSize(290, 86)
            resumePromptFrame:SetFrameStrata("TOOLTIP")
            resumePromptFrame:SetClampedToScreen(true)
            resumePromptFrame.bg = UI.SolidTex(resumePromptFrame, "BACKGROUND", 0, 0.043, 0.051, 0.071, 0.98)
            resumePromptFrame.bg:SetAllPoints()
            UI.CreatePixelBorder(resumePromptFrame, 0.96, 0.72, 0.18, 0.95, 3)

            local pTitle = resumePromptFrame:CreateFontString(nil, "OVERLAY")
            pTitle:SetPoint("TOPLEFT", resumePromptFrame, "TOPLEFT", 12, -10)
            pTitle:SetPoint("TOPRIGHT", resumePromptFrame, "TOPRIGHT", -12, -10)
            pTitle:SetJustifyH("LEFT")
            UI.SetFont(pTitle, 11, "", 0.96, 0.72, 0.18, 1)
            pTitle:SetText("Manual Profile Override Active")
            resumePromptFrame.title = pTitle

            local pDesc = resumePromptFrame:CreateFontString(nil, "OVERLAY")
            pDesc:SetPoint("TOPLEFT", pTitle, "BOTTOMLEFT", 0, -4)
            pDesc:SetPoint("TOPRIGHT", pTitle, "BOTTOMRIGHT", 0, -4)
            pDesc:SetJustifyH("LEFT")
            UI.SetFont(pDesc, 10, "", 0.82, 0.86, 0.92, 0.95)
            pDesc:SetText("Resume automatic zone profile switching?")
            resumePromptFrame.desc = pDesc

            local resumeBtn = CreateFlatButton(resumePromptFrame, 150, 22, "Resume Auto-Switch", true)
            resumeBtn:SetPoint("BOTTOMLEFT", resumePromptFrame, "BOTTOMLEFT", 10, 10)
            resumeBtn:SetScript("OnClick", function()
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION or 856)
                if addonTable.ResumeAutoSwitch then
                    addonTable.ResumeAutoSwitch()
                end
                selectedTabKey = (DynamicLoadDB and DynamicLoadDB.stagedProfile) or (addonTable.GetLoadedProfile and addonTable.GetLoadedProfile()) or "outdoor"
                if addonTable.SetSelectedTabKey then addonTable.SetSelectedTabKey(selectedTabKey) end
                resumePromptFrame:Hide()
                if clickCatcher then clickCatcher:Hide() end
                if f.UpdateAllTabVisuals then f.UpdateAllTabVisuals() end
                if f.scrollChild then RefreshAddonTree(f.scrollChild) end
                UpdateStatusBar()
            end)

            local cancelBtn = CreateFlatButton(resumePromptFrame, 108, 22, "Keep Manual", false)
            cancelBtn:SetPoint("BOTTOMRIGHT", resumePromptFrame, "BOTTOMRIGHT", -10, 10)
            cancelBtn:SetScript("OnClick", function()
                PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE or 857)
                resumePromptFrame:Hide()
                if clickCatcher then clickCatcher:Hide() end
            end)
            f.resumePromptFrame = resumePromptFrame
        end

        local catcher = GetClickCatcher()
        catcher:Show()
        resumePromptFrame:ClearAllPoints()
        resumePromptFrame:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
        resumePromptFrame:Show()
    end

    local isDraggingStatusCapsule = false
    statusCapsule:RegisterForClicks("LeftButtonUp")
    statusCapsule:RegisterForDrag("LeftButton")
    statusCapsule:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            isDraggingStatusCapsule = false
        end
    end)
    statusCapsule:SetScript("OnDragStart", function()
        isDraggingStatusCapsule = true
        CloseContextMenu()
        if dsColorPicker then dsColorPicker:Hide() end
        GameTooltip:Hide()
        f:StartMoving()
    end)
    statusCapsule:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
    end)

    local function GetStatusCapsuleAction()
        if activeWorkspaceView ~= "DYNAMICLOAD" then
            return "NONE", 0
        end
        local deltaCount = 0
        if addonTable.CalculateAddonDelta then
            deltaCount = addonTable.CalculateAddonDelta(selectedTabKey) or 0
        end
        if addonTable.IsManualOverrideActive and addonTable.IsManualOverrideActive() then
            return "RESUME_AUTO", deltaCount
        end
        if deltaCount > 0 then
            return "TOGGLE_PENDING", deltaCount
        end
        if securityFilter == "PENDING" then
            return "EXIT_EMPTY_PENDING", 0
        end
        return "NONE", 0
    end

    local function ResolveActiveStatusModuleTitle()
        if (activeWorkspaceView == "PEER_HOST" or activeWorkspaceView == "PEER_MODULE") and selectedPeerModuleKey then
            for _, m in ipairs(addonTable.SUITE_MODULE_LIST or {}) do
                if m.key == selectedPeerModuleKey or m.addonName == selectedPeerModuleKey or m.id == selectedPeerModuleKey then
                    return m.title or m.name or m.addonName or selectedPeerModuleKey
                end
            end
            local regMod = _G.DynamicSuite and _G.DynamicSuite.modules and _G.DynamicSuite.modules[selectedPeerModuleKey]
            if regMod and (regMod.title or regMod.name) then
                return regMod.title or regMod.name
            end
            return tostring(selectedPeerModuleKey)
        elseif activeWorkspaceView == "THEME_STUDIO" then
            return "Suite Studio"
        elseif activeWorkspaceView == "GUIDED_SETUP" then
            return "Guided Setup & Conflict Scanner"
        elseif activeWorkspaceView == "CHANGELOG_VIEW" then
            return "DynamicSuite Changelog"
        end
        return "DynamicSuite"
    end

    local function ShowStatusCapsuleTooltip(self)
        if activeWorkspaceView == "DYNAMICLOAD" then
            PopulatePendingReloadTooltip(self, "ANCHOR_BOTTOM")
        else
            local modTitle = ResolveActiveStatusModuleTitle()
            local curText = (statusText and statusText:GetText()) or lastStatusRawStr or ""
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(string.format("%s - Live Status", modTitle), 1, 1, 1)
            if curText ~= "" then
                GameTooltip:AddLine(curText, 0.82, 0.86, 0.92, true)
            end
            GameTooltip:Show()
        end
    end

    statusCapsule:SetScript("OnEnter", function(self)
        local action = GetStatusCapsuleAction()
        if action ~= "NONE" then
            self.bg:SetColorTexture(1, 1, 1, 0.055)
            self.dsBorder:SetColor(1, 1, 1, 0.20)
        else
            self.bg:SetColorTexture(1, 1, 1, 0.025)
            self.dsBorder:SetColor(1, 1, 1, 0.08)
        end
        ShowStatusCapsuleTooltip(self)
    end)
    statusCapsule:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(1, 1, 1, 0.025)
        self.dsBorder:SetColor(1, 1, 1, 0.08)
        GameTooltip:Hide()
    end)
    statusCapsule:SetScript("OnClick", function(self)
        if isDraggingStatusCapsule then
            isDraggingStatusCapsule = false
            return
        end
        local action = GetStatusCapsuleAction()
        if action == "NONE" then
            return
        end
        if action == "RESUME_AUTO" then
            ShowResumePrompt(self)
            return
        end

        isToastSubTabActive = false
        if addonTable.SetIsToastSubTabActive then addonTable.SetIsToastSubTabActive(false) end
        if f.toastConfigPanel then f.toastConfigPanel:Hide() end
        if f.toolbar then f.toolbar:Show() end
        if f.telemetryStrip then f.telemetryStrip:Show() end
        if f.scrollFrame then f.scrollFrame:Show() end
        if f.scrollTrack then f.scrollTrack:Show() end
        if action == "EXIT_EMPTY_PENDING" then
            securityFilter = "ALL"
        else
            securityFilter = (securityFilter == "PENDING") and "ALL" or "PENDING"
        end
        if addonTable.SetSecurityFilter then addonTable.SetSecurityFilter(securityFilter) end
        if f.UpdateFilterChips then f.UpdateFilterChips() end
        if f.scrollFrame then
            f.scrollFrame._lastUserScroll = 0
            f.scrollFrame:SetVerticalScroll(0)
        end
        if f.scrollChild then RefreshAddonTree(f.scrollChild, true) end
        if f.UpdateAllTabVisuals then f.UpdateAllTabVisuals() end
        local nextAction = GetStatusCapsuleAction()
        if nextAction ~= "NONE" then
            self.bg:SetColorTexture(1, 1, 1, 0.055)
            self.dsBorder:SetColor(1, 1, 1, 0.20)
        else
            self.bg:SetColorTexture(1, 1, 1, 0.025)
            self.dsBorder:SetColor(1, 1, 1, 0.08)
        end
        if GameTooltip:IsOwned(self) then
            ShowStatusCapsuleTooltip(self)
        end
    end)

    UpdateStatusBar = function(skipDeltaScan)
        local deltaCount = 0
        if skipDeltaScan and f._cachedDeltaCount ~= nil then
            deltaCount = f._cachedDeltaCount
        elseif addonTable.CalculateAddonDelta then
            deltaCount = addonTable.CalculateAddonDelta(selectedTabKey) or 0
            f._cachedDeltaCount = deltaCount
        end
        if f.reloadUIBtn and f.reloadUIBtn.label then
            local ar, ag, ab = UI.GetActiveAccentColor()
            if deltaCount > 0 then
                f.reloadUIBtn.label:SetText(string.format("Reload (%d)", deltaCount))
                f.reloadUIBtn:SetSelected(true, { r = ar, g = ag, b = ab })
            elseif addonTable._pendingSuiteModuleReload then
                f.reloadUIBtn.label:SetText("Reload UI *")
                f.reloadUIBtn:SetSelected(true, { r = ar, g = ag, b = ab })
            else
                f.reloadUIBtn.label:SetText("Reload UI")
                f.reloadUIBtn:SetSelected(false)
            end
        end
        if f.UpdateResetButtonLabel then
            f.UpdateResetButtonLabel()
        end

        local accHex = UI.GetActiveAccentHex()
        if (activeWorkspaceView == "PEER_HOST" or activeWorkspaceView == "PEER_MODULE") and selectedPeerModuleKey then
            local mInfo = nil
            for _, m in ipairs(addonTable.SUITE_MODULE_LIST or {}) do
                if m.key == selectedPeerModuleKey or m.addonName == selectedPeerModuleKey or m.id == selectedPeerModuleKey then
                    mInfo = m
                    break
                end
            end
            local addonKey = (mInfo and (mInfo.addonName or mInfo.name or mInfo.key)) or selectedPeerModuleKey
            local shortKey = (mInfo and mInfo.id) or tostring(addonKey):gsub("^Dynamic", ""):lower()
            local regMod = _G.DynamicSuite and _G.DynamicSuite.modules and (_G.DynamicSuite.modules[addonKey] or _G.DynamicSuite.modules[shortKey] or _G.DynamicSuite.modules[selectedPeerModuleKey])
            if regMod and type(regMod.GetStatusText) == "function" then
                local okStatus, customStatus = pcall(regMod.GetStatusText, regMod)
                if okStatus and type(customStatus) == "string" and customStatus ~= "" then
                    SetStatusCapsuleDisplay(customStatus)
                    return
                end
            end
            if addonKey == "DynamicZoom" or shortKey == "zoom" then
                SetStatusCapsuleDisplay(string.format("Max Zoom: |cFFFFFFFF39 yd|r   |   Foliage Shield: |cFF%sActive|r   |   Skyriding & Boss Framing: |cFF22C55EON|r", accHex))
                return
            elseif addonKey == "DynamicFPS" or shortKey == "fps" then
                SetStatusCapsuleDisplay(string.format("Zone Graphics: |cFFFFFFFFActive|r   |   Spell Queue: |cFF%sAuto-Tuned|r   |   Boss Ground Effects: |cFF22C55EProtected|r", accHex))
                return
            elseif addonKey == "DynamicMarker" or shortKey == "marker" then
                SetStatusCapsuleDisplay(string.format("FocusMarker Macro: |cFFFFFFFFReady|r   |   DynamicKick: |cFF%sAuto-Spec Sync|r   |   World Flares: |cFF22C55EActive|r", accHex))
                return
            elseif addonKey == "DynamicPrep" or shortKey == "prep" then
                SetStatusCapsuleDisplay(string.format("Stat Omni-Bar: |cFFFFFFFFActive|r   |   Seasonal Folio: |cFF%sReady|r   |   Fast Auto-Loot & Repair: |cFF22C55EON|r", accHex))
                return
            elseif addonKey == "DynamicGroup" or shortKey == "group" then
                SetStatusCapsuleDisplay(string.format("Auto-Invite: |cFFFFFFFFFriends & Guild|r   |   LFG Regions: |cFF%sActive|r   |   Auto-Role: |cFF22C55EON|r", accHex))
                return
            elseif addonKey == "DynamicChat" or shortKey == "chat" then
                SetStatusCapsuleDisplay("* /ww Whisper: ON  |  Channel Tags: Compact  |  GPU Buffer: 250 Lines")
                return
            elseif mInfo then
                SetStatusCapsuleDisplay(string.format("Active Module: |cFFFFFFFF%s|r   |   Category: |cFF%s%s|r", mInfo.title or addonKey, accHex, mInfo.category or "DynamicSuite"))
                return
            end
        end

        local isOverride = (addonTable.IsManualOverrideActive and addonTable.IsManualOverrideActive()) or false
        local loadedProf = (addonTable.GetLoadedProfile and addonTable.GetLoadedProfile()) or (DynamicLoadDB and DynamicLoadDB.loadedProfile) or (DynamicLoadDB and DynamicLoadDB.activeProfile) or "outdoor"
        local envDetail = (addonTable.GetEnvironmentDetail and addonTable.GetEnvironmentDetail()) or "Outdoor"
        local profName = (DynamicLoadDB and DynamicLoadDB.profiles and DynamicLoadDB.profiles[loadedProf] and DynamicLoadDB.profiles[loadedProf].name) or loadedProf
        local stagedStr = (deltaCount > 0) and string.format("|cFFF59E0B%d Pending Reload|r", deltaCount) or "|cFF22C55EIn Sync|r"

        if isOverride then
            SetStatusCapsuleDisplay(string.format("|cFF22C55E|TInterface\\Buttons\\WHITE8X8:6:6:0:0:8:8:0:8:0:8:34:197:94|t Loaded:|r |cFFFFFFFF%s|r |cFFF5B82E[Manual]|r   |   |cFF38BDF8|TInterface\\Buttons\\WHITE8X8:6:6:0:0:8:8:0:8:0:8:56:189:248|t Location:|r |cFFFFFFFF%s|r   |   State: %s", profName, envDetail, stagedStr))
        else
            SetStatusCapsuleDisplay(string.format("|cFF22C55E|TInterface\\Buttons\\WHITE8X8:6:6:0:0:8:8:0:8:0:8:34:197:94|t Loaded:|r |cFFFFFFFF%s [Auto]|r   |   |cFF38BDF8|TInterface\\Buttons\\WHITE8X8:6:6:0:0:8:8:0:8:0:8:56:189:248|t Location:|r |cFFFFFFFF%s|r   |   State: %s", profName, envDetail, stagedStr))
        end
    end
    f.UpdateStatusBar = UpdateStatusBar
    local function DispatchHeaderTelemetryRefresh()
        if f and f.UpdateStatusBar then
            f.UpdateStatusBar(true)
        end
    end
    addonTable.UpdateHeaderTelemetry = DispatchHeaderTelemetryRefresh
    addonTable.UpdateHeaderStatus = DispatchHeaderTelemetryRefresh
    addonTable.RefreshHeaderStatus = DispatchHeaderTelemetryRefresh
    _G.DynamicSuite = _G.DynamicSuite or {}
    _G.DynamicSuite.UpdateHeaderTelemetry = DispatchHeaderTelemetryRefresh
    _G.DynamicSuite.UpdateHeaderStatus = DispatchHeaderTelemetryRefresh
    _G.DynamicSuite.RefreshHeaderStatus = DispatchHeaderTelemetryRefresh
    addonTable.GetSelectedTabForReload = function()
        if mainFrame and mainFrame:IsShown() and activeWorkspaceView == "DYNAMICLOAD" and not isToastSubTabActive then
            return selectedTabKey
        end
        return nil
    end
    end

    ----------------------------------------------------------------------------
    -- 2. UNIFIED BOTTOM CONTROL DOCK (38px Height + Bottom-Right Resize Grip)
    ----------------------------------------------------------------------------
    local footer = CreateFrame("Frame", nil, f)
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    footer:SetHeight(DOCK_H)
    f.footer = footer

    footer.bg = UI.SolidTex(footer, "BACKGROUND", 1, UI.COLORS.HEADER_BG.r, UI.COLORS.HEADER_BG.g, UI.COLORS.HEADER_BG.b, 1.0)
    footer.bg:SetAllPoints()
    footer.divider = UI.SolidTex(footer, "OVERLAY", 2, 1, 1, 1, UI.COLORS.BORDER.a)
    footer.divider:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 0)
    footer.divider:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, 0)
    footer.divider:SetHeight(1)

    do

    -- Bottom-Left Standardized Reset Dock: [Reset <ActiveModule>] + [Reset DynamicSuite] (Neutral Obsidian Idle State)
    local resetModBtn = CreateFlatButton(footer, 134, 24, "Reset DynamicLoad", false)
    resetModBtn:SetPoint("LEFT", footer, "LEFT", 14, 0)
    f.resetModBtn = resetModBtn

    local resetSuiteBtn = CreateFlatButton(footer, 132, 24, "Reset DynamicSuite", false)
    resetSuiteBtn:SetPoint("LEFT", resetModBtn, "RIGHT", 6, 0)
    f.resetSuiteBtn = resetSuiteBtn

    local resetModConfirm = false

    local blizzRestoreModal = nil
    local function ShowBlizzRestoreModal()
        if type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() then
            print("|cFF38BDF8DynamicSuite:|r Cannot restore Blizzard defaults or change addon states while in combat. Please leave combat and try again.")
            return
        end
        if not blizzRestoreModal then
            local m = CreateFrame("Frame", "DynamicSuiteBlizzRestoreModal", UIParent)
            m:SetSize(460, 248)
            m:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
            m:SetFrameStrata("FULLSCREEN_DIALOG")
            m:SetFrameLevel(300)
            m:EnableMouse(true)
            m.bg = UI.SolidTex(m, "BACKGROUND", 0, 0.043, 0.051, 0.071, 0.98)
            m.bg:SetAllPoints()
            UI.CreatePixelBorder(m, 0.937, 0.267, 0.267, 0.80, 4)

            local mTitle = m:CreateFontString(nil, "OVERLAY")
            mTitle:SetPoint("TOPLEFT", m, "TOPLEFT", 18, -16)
            UI.SetFont(mTitle, 13, "", 0.98, 0.75, 0.14, 1)
            mTitle:SetText("Restore Blizzard Defaults (Uninstall Prep)")

            local mDesc = m:CreateFontString(nil, "OVERLAY")
            mDesc:SetPoint("TOPLEFT", m, "TOPLEFT", 18, -42)
            mDesc:SetPoint("TOPRIGHT", m, "TOPRIGHT", -18, -42)
            mDesc:SetJustifyH("LEFT")
            mDesc:SetWordWrap(true)
            UI.SetFont(mDesc, 10.5, "", 0.86, 0.90, 0.95, 0.95)
            mDesc:SetText(
                "Prepares DynamicSuite for clean removal by:\n" ..
                "  - Restoring graphics, camera, spell queue, chat, and bag settings to Blizzard defaults\n" ..
                "  - Resetting Blizzard's chat window layout and tabs back to default\n" ..
                "  - Resetting DynamicMarker, DynamicPrep, DynamicChat, and suite bar positions"
            )

            local cbDisable = CreateFrame("CheckButton", nil, m)
            cbDisable:SetSize(16, 16)
            cbDisable:SetPoint("TOPLEFT", mDesc, "BOTTOMLEFT", 0, -14)
            cbDisable.bg = UI.SolidTex(cbDisable, "BACKGROUND", 0, 0.08, 0.10, 0.14, 1)
            cbDisable.bg:SetAllPoints()
            UI.CreatePixelBorder(cbDisable, 0.35, 0.45, 0.60, 0.85, 3)
            cbDisable.check = UI.SolidTex(cbDisable, "OVERLAY", 2, 0.22, 0.74, 0.97, 1)
            cbDisable.check:SetSize(10, 10)
            cbDisable.check:SetPoint("CENTER")
            cbDisable._checked = true
            cbDisable:SetScript("OnClick", function(self)
                self._checked = not self._checked
                self.check:SetShown(self._checked)
            end)

            local cbLbl = m:CreateFontString(nil, "OVERLAY")
            cbLbl:SetPoint("LEFT", cbDisable, "RIGHT", 8, 0)
            UI.SetFont(cbLbl, 10.5, "", 0.92, 0.95, 0.99, 1)
            cbLbl:SetText("Also disable DynamicSuite addons for clean uninstall")

            local btnCancel = CreateFlatButton(m, 104, 26, "Cancel", false)
            btnCancel:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -16, 14)
            btnCancel:SetScript("OnClick", function() m:Hide() end)

            local btnConfirm = CreateFlatButton(m, 164, 26, "Confirm & Reload UI", true)
            btnConfirm:SetPoint("RIGHT", btnCancel, "LEFT", -8, 0)
            btnConfirm:SetSelected(true, { r = 0.937, g = 0.267, b = 0.267 })
            btnConfirm:SetScript("OnClick", function()
                if type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() then
                    print("|cFF38BDF8DynamicSuite:|r Cannot restore Blizzard defaults while in combat. Please leave combat and try again.")
                    return
                end
                m:Hide()
                if addonTable.RestoreBlizzardDefaults then
                    addonTable.RestoreBlizzardDefaults(cbDisable._checked == true)
                end
            end)

            blizzRestoreModal = m
        end
        blizzRestoreModal:Show()
    end
    addonTable.ShowBlizzRestoreModal = ShowBlizzRestoreModal

    local suiteResetChoiceModal = nil
    local function ShowSuiteResetChoiceModal()
        if not suiteResetChoiceModal then
            local m = CreateFrame("Frame", "DynamicSuiteResetChoiceModal", UIParent)
            m:SetSize(480, 276)
            m:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
            m:SetFrameStrata("FULLSCREEN_DIALOG")
            m:SetFrameLevel(298)
            m:EnableMouse(true)
            m.bg = UI.SolidTex(m, "BACKGROUND", 0, 0.043, 0.051, 0.071, 0.98)
            m.bg:SetAllPoints()
            UI.CreatePixelBorder(m, 0.35, 0.45, 0.60, 0.85, 4)

            local mTitle = m:CreateFontString(nil, "OVERLAY")
            mTitle:SetPoint("TOPLEFT", m, "TOPLEFT", 18, -16)
            UI.SetFont(mTitle, 13, "", 0.96, 0.98, 1.0, 1)
            mTitle:SetText("Reset DynamicSuite")

            local mSub = m:CreateFontString(nil, "OVERLAY")
            mSub:SetPoint("TOPLEFT", m, "TOPLEFT", 18, -38)
            mSub:SetPoint("TOPRIGHT", m, "TOPRIGHT", -18, -38)
            mSub:SetJustifyH("LEFT")
            UI.SetFont(mSub, 10.5, "", 0.72, 0.78, 0.86, 0.95)
            mSub:SetText("Choose whether to reset DynamicSuite settings only, or restore Blizzard defaults before uninstalling:")

            -- Option 1: Reset DynamicSuite Settings
            local opt1 = CreateFrame("Button", nil, m)
            opt1:SetPoint("TOPLEFT", m, "TOPLEFT", 18, -64)
            opt1:SetPoint("TOPRIGHT", m, "TOPRIGHT", -18, -64)
            opt1:SetHeight(74)
            opt1.bg = UI.SolidTex(opt1, "BACKGROUND", 1, 0.075, 0.088, 0.120, 0.96)
            opt1.bg:SetAllPoints()
            local opt1Bdr = UI.CreatePixelBorder(opt1, 0.22, 0.74, 0.97, 0.45, 3)

            local o1Title = opt1:CreateFontString(nil, "OVERLAY")
            o1Title:SetPoint("TOPLEFT", opt1, "TOPLEFT", 12, -10)
            UI.SetFont(o1Title, 11.5, "", 0.22, 0.74, 0.97, 1)
            o1Title:SetText("1. Reset DynamicSuite Settings")

            local o1Desc = opt1:CreateFontString(nil, "OVERLAY")
            o1Desc:SetPoint("TOPLEFT", opt1, "TOPLEFT", 12, -29)
            o1Desc:SetPoint("BOTTOMRIGHT", opt1, "BOTTOMRIGHT", -12, 8)
            o1Desc:SetJustifyH("LEFT")
            o1Desc:SetJustifyV("TOP")
            o1Desc:SetWordWrap(true)
            UI.SetFont(o1Desc, 10, "", 0.82, 0.86, 0.92, 0.95)
            o1Desc:SetText("Resets your DynamicSuite profile settings to defaults without touching game settings or chat layout.")

            opt1:SetScript("OnEnter", function()
                opt1.bg:SetColorTexture(0.10, 0.12, 0.17, 0.98)
                opt1Bdr:SetColor(0.22, 0.74, 0.97, 0.90)
            end)
            opt1:SetScript("OnLeave", function()
                opt1.bg:SetColorTexture(0.075, 0.088, 0.120, 0.96)
                opt1Bdr:SetColor(0.22, 0.74, 0.97, 0.45)
            end)
            opt1:SetScript("OnClick", function()
                m:Hide()
                addonTable.ResetDynamicSuite()
                if f.scrollChild then RefreshAddonTree(f.scrollChild) end
                UpdateStatusBar()
            end)

            -- Option 2: Restore Blizzard Defaults (Uninstall Prep)
            local opt2 = CreateFrame("Button", nil, m)
            opt2:SetPoint("TOPLEFT", opt1, "BOTTOMLEFT", 0, -10)
            opt2:SetPoint("TOPRIGHT", opt1, "BOTTOMRIGHT", 0, -10)
            opt2:SetHeight(82)
            opt2.bg = UI.SolidTex(opt2, "BACKGROUND", 1, 0.085, 0.070, 0.085, 0.96)
            opt2.bg:SetAllPoints()
            local opt2Bdr = UI.CreatePixelBorder(opt2, 0.937, 0.267, 0.267, 0.55, 3)

            local o2Title = opt2:CreateFontString(nil, "OVERLAY")
            o2Title:SetPoint("TOPLEFT", opt2, "TOPLEFT", 12, -10)
            UI.SetFont(o2Title, 11.5, "", 0.98, 0.55, 0.55, 1)
            o2Title:SetText("2. Restore Blizzard Defaults (Uninstall Prep)")

            local o2Desc = opt2:CreateFontString(nil, "OVERLAY")
            o2Desc:SetPoint("TOPLEFT", opt2, "TOPLEFT", 12, -29)
            o2Desc:SetPoint("BOTTOMRIGHT", opt2, "BOTTOMRIGHT", -12, 8)
            o2Desc:SetJustifyH("LEFT")
            o2Desc:SetJustifyV("TOP")
            o2Desc:SetWordWrap(true)
            UI.SetFont(o2Desc, 10, "", 0.84, 0.88, 0.93, 0.95)
            o2Desc:SetText("Restores graphics, camera, spell queue, chat, and bag settings to Blizzard defaults, resets chat windows and HUD positions, then reloads your UI.")

            opt2:SetScript("OnEnter", function()
                opt2.bg:SetColorTexture(0.13, 0.08, 0.09, 0.98)
                opt2Bdr:SetColor(0.937, 0.267, 0.267, 0.95)
            end)
            opt2:SetScript("OnLeave", function()
                opt2.bg:SetColorTexture(0.085, 0.070, 0.085, 0.96)
                opt2Bdr:SetColor(0.937, 0.267, 0.267, 0.55)
            end)
            opt2:SetScript("OnClick", function()
                m:Hide()
                ShowBlizzRestoreModal()
            end)

            local btnCancel = CreateFlatButton(m, 104, 24, "Cancel", false)
            btnCancel:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -18, 12)
            btnCancel:SetScript("OnClick", function() m:Hide() end)

            suiteResetChoiceModal = m
        end
        suiteResetChoiceModal:Show()
    end

    local function GetActiveResetModuleName()
        if (activeWorkspaceView == "PEER_HOST" or activeWorkspaceView == "PEER_MODULE") and selectedPeerModuleKey then
            for _, m in ipairs(addonTable.SUITE_MODULE_LIST or {}) do
                if m.key == selectedPeerModuleKey or m.addonName == selectedPeerModuleKey or m.id == selectedPeerModuleKey then
                    return m.title or m.addonName or selectedPeerModuleKey
                end
            end
            return tostring(selectedPeerModuleKey)
        end
        return "DynamicLoad"
    end

    local function UpdateResetButtonLabel()
        if resetModConfirm then return end
        local modTitle = GetActiveResetModuleName()
        resetModBtn.label:SetText("Reset " .. modTitle)
        local lw = resetModBtn.label:GetStringWidth() or 110
        resetModBtn:SetWidth(math.max(126, math.floor(lw + 20)))
        resetModBtn.bg:SetColorTexture(UI.COLORS.BTN_BG.r, UI.COLORS.BTN_BG.g, UI.COLORS.BTN_BG.b, 0.94)
        resetModBtn.dsBorder:SetColor(UI.COLORS.BTN_BORDER.r, UI.COLORS.BTN_BORDER.g, UI.COLORS.BTN_BORDER.b, UI.COLORS.BTN_BORDER.a)
        resetModBtn.label:SetTextColor(0.86, 0.88, 0.92, 0.95)
    end
    f.UpdateResetButtonLabel = UpdateResetButtonLabel

    resetModBtn:SetScript("OnClick", function(self)
        local modTitle = GetActiveResetModuleName()
        if not resetModConfirm then
            resetModConfirm = true
            self.label:SetText("Confirm Reset?")
            self.bg:SetColorTexture(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.35)
            self.dsBorder:SetColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1.0)
            C_Timer.After(3.0, function()
                if resetModConfirm then
                    resetModConfirm = false
                    self.label:SetText("Cancelled (Safe)")
                    self.bg:SetColorTexture(0.10, 0.12, 0.16, 0.94)
                    self.dsBorder:SetColor(0.38, 0.45, 0.56, 0.85)
                    self.label:SetTextColor(0.68, 0.74, 0.82, 1)
                    print(string.format("%s: %s reset cancelled - no settings were changed.", UI.FormatTwoToneBrand("Suite"), modTitle))
                    C_Timer.After(1.2, function()
                        if not resetModConfirm then
                            UpdateResetButtonLabel()
                        end
                    end)
                end
            end)
        else
            resetModConfirm = false
            if modTitle == "DynamicLoad" then
                addonTable.ResetDynamicLoad()
                if f.scrollChild then RefreshAddonTree(f.scrollChild) end
            else
                local regMod = _G.DynamicSuite and _G.DynamicSuite.modules and (_G.DynamicSuite.modules[modTitle] or _G.DynamicSuite.modules[selectedPeerModuleKey])
                if regMod then
                    local rFn = regMod.ResetModule or regMod.ResetDefaults or regMod.ResetModuleDefaults or regMod.Reset
                    if type(rFn) == "function" then
                        pcall(rFn, regMod)
                    end
                    if f.peerModuleHostFrame and f.peerModuleHostFrame:IsShown() then
                        local renderFn = regMod.RenderEmbedded or regMod.Render or regMod.BuildUI or regMod.BuildConfigUI
                        if type(renderFn) == "function" then
                            local targetHost = f.peerModuleHostFrame._activeModHost or f.peerModuleHostFrame
                            pcall(renderFn, regMod.RenderEmbedded and regMod or targetHost, targetHost)
                        end
                    end
                end
            end
            UpdateResetButtonLabel()
            UpdateStatusBar()
        end
    end)

    resetSuiteBtn:SetScript("OnClick", function()
        ShowSuiteResetChoiceModal()
    end)

    -- Bottom-Right Corner Resize Grip (Zero-FPS-Drop Hardware Resize Handle)
    local resizeGrip = CreateFrame("Button", nil, footer)
    resizeGrip:SetSize(14, 14)
    resizeGrip:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -4, 4)
    resizeGrip:EnableMouse(true)

    local gripTex = resizeGrip:CreateTexture(nil, "OVERLAY", nil, 5)
    gripTex:SetAllPoints()
    gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    gripTex:SetDesaturated(true)
    gripTex:SetVertexColor(0.55, 0.58, 0.65, 0.75)

    resizeGrip:SetScript("OnEnter", function()
        gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        gripTex:SetDesaturated(false)
        gripTex:SetVertexColor(0.976, 0.451, 0.086, 0.95)
    end)
    resizeGrip:SetScript("OnLeave", function()
        gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        gripTex:SetDesaturated(true)
        gripTex:SetVertexColor(0.55, 0.58, 0.65, 0.75)
    end)
    resizeGrip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            CloseContextMenu()
            f:StartSizing("BOTTOMRIGHT")
        elseif button == "RightButton" then
            f:SetSize(1040, 680)
            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
            if gTbl then gTbl.windowWidth = 1040; gTbl.windowHeight = 680 end
            if DynamicLoadDB then DynamicLoadDB.windowWidth = 1040; DynamicLoadDB.windowHeight = 680 end
        end
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        local w, h = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        if gTbl then gTbl.windowWidth = w; gTbl.windowHeight = h end
        if DynamicLoadDB then DynamicLoadDB.windowWidth = w; DynamicLoadDB.windowHeight = h end
    end)

    -- Bottom-Right Controls: [Opacity Slider] + [Scale Slider 100%] + Compact [Reload UI]
    local reloadUIBtn = CreateFlatButton(footer, 78, 24, "Reload UI", false)
    reloadUIBtn:SetPoint("RIGHT", footer, "RIGHT", -32, 0)
    reloadUIBtn.OnCustomEnter = function(self)
        PopulatePendingReloadTooltip(self, "ANCHOR_TOP")
    end
    reloadUIBtn.OnCustomLeave = function()
        GameTooltip:Hide()
    end
    reloadUIBtn:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION or 856)
        if addonTable.ApplyProfile then
            addonTable.ApplyProfile(selectedTabKey, true)
        else
            addonTable.StageAddonProfile(selectedTabKey, true)
            ReloadUI()
        end
    end)
    f.reloadUIBtn = reloadUIBtn
    f.activateReloadBtn = reloadUIBtn

    -- Scale Slider in Bottom Dock (80% - 120%) with Discrete 5% Instant Steps (Zero Font Rasterizer Jitter)
    local SCALE_MIN, SCALE_MAX, SCALE_STEP, SCALE_W = 0.80, 1.20, 0.05, 64
    local scaleValText = footer:CreateFontString(nil, "OVERLAY")
    scaleValText:SetPoint("RIGHT", reloadUIBtn, "LEFT", -16, 0)
    scaleValText:SetWidth(38)
    scaleValText:SetJustifyH("LEFT")
    UI.SetFont(scaleValText, 10, "", 1, 1, 1, 0.85)

    local scaleHit = CreateFrame("Frame", nil, footer)
    scaleHit:SetSize(SCALE_W + 8, 20)
    scaleHit:SetPoint("RIGHT", scaleValText, "LEFT", -8, 0)
    scaleHit:EnableMouse(true)
    scaleHit:EnableMouseWheel(true)

    local scaleTrack = UI.SolidTex(scaleHit, "ARTWORK", 1, 0.035, 0.039, 0.051, 0.98)
    scaleTrack:SetSize(SCALE_W, 4)
    scaleTrack:SetPoint("CENTER", scaleHit, "CENTER", 0, 0)

    local scaleFill = UI.SolidTex(scaleHit, "ARTWORK", 2, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.85)
    scaleFill:SetPoint("TOPLEFT", scaleTrack, "TOPLEFT", 0, 0)
    scaleFill:SetPoint("BOTTOMLEFT", scaleTrack, "BOTTOMLEFT", 0, 0)
    scaleFill:SetWidth(1)

    local scaleThumb = UI.SolidTex(scaleHit, "OVERLAY", 4, 0.97, 0.98, 1.00, 1.0)
    scaleThumb:SetSize(6, 14)
    if scaleThumb.SetSnapToPixelGrid then
        scaleThumb:SetSnapToPixelGrid(false)
        scaleThumb:SetTexelSnappingBias(0)
    end

    local scaleLbl = footer:CreateFontString(nil, "OVERLAY")
    scaleLbl:SetPoint("RIGHT", scaleHit, "LEFT", -4, 0)
    UI.SetFont(scaleLbl, 10, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 0.85)
    scaleLbl:SetText("Scale")

    local pendingScale = savedScale

    local function UpdateScaleVisual(val)
        val = math.max(SCALE_MIN, math.min(SCALE_MAX, val or 1.0))
        local pct = (val - SCALE_MIN) / (SCALE_MAX - SCALE_MIN)
        local xOff = pct * SCALE_W
        scaleFill:SetWidth(math.max(1, xOff))
        scaleThumb:ClearAllPoints()
        scaleThumb:SetPoint("CENTER", scaleTrack, "LEFT", xOff, 0)
        scaleValText:SetText(string.format("%d%%", math.floor(val * 100 + 0.5)))
    end
    UpdateScaleVisual(savedScale)

    local function ApplyScaleKeepingCenter(newScale)
        local oldScale = f:GetScale() or 1.0
        if math.abs(newScale - oldScale) < 0.0005 then return end
        local cx, cy = f:GetCenter()
        f:SetScale(newScale)
        if cx and cy then
            local ratio = oldScale / newScale
            f:ClearAllPoints()
            f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx * ratio, cy * ratio)
        end
    end

    local function CommitWindowScale(val)
        val = math.floor((val or 1.0) * 20 + 0.5) / 20
        val = math.max(SCALE_MIN, math.min(SCALE_MAX, val))
        pendingScale = val
        UpdateScaleVisual(val)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        if gTbl then gTbl.windowScale = val end
        if DynamicLoadDB then DynamicLoadDB.windowScale = val end
        ApplyScaleKeepingCenter(val)
    end
    f.CommitWindowScale = CommitWindowScale

    scaleHit:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self:SetScript("OnUpdate", function(s)
                if not IsMouseButtonDown("LeftButton") then
                    s:SetScript("OnUpdate", nil)
                    CommitWindowScale(pendingScale)
                    return
                end
                local eff = scaleTrack:GetEffectiveScale()
                local cx = GetCursorPosition() / eff
                local left = scaleTrack:GetLeft()
                if left then
                    local pct = math.max(0, math.min(1, (cx - left) / SCALE_W))
                    local raw = SCALE_MIN + pct * (SCALE_MAX - SCALE_MIN)
                    local snapped = math.floor(raw * 20 + 0.5) / 20
                    snapped = math.max(SCALE_MIN, math.min(SCALE_MAX, snapped))
                    if math.abs(snapped - pendingScale) >= 0.001 then
                        pendingScale = snapped
                        UpdateScaleVisual(pendingScale)
                    end
                end
            end)
        elseif button == "RightButton" then
            CommitWindowScale(1.0)
        end
    end)
    scaleHit:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self:SetScript("OnUpdate", nil)
            CommitWindowScale(pendingScale)
        end
    end)
    scaleHit:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
    scaleHit:SetScript("OnMouseWheel", function(_, delta)
        CommitWindowScale(pendingScale + (delta > 0 and SCALE_STEP or -SCALE_STEP))
    end)

    -- Opacity Slider in Bottom Dock (50% - 100%)
    local OPA_MIN, OPA_MAX, OPA_W = 0.50, 1.00, 64
    local opaHit = CreateFrame("Frame", nil, footer)
    opaHit:SetSize(OPA_W + 8, 20)
    opaHit:SetPoint("RIGHT", scaleLbl, "LEFT", -12, 0)
    opaHit:EnableMouse(true)
    opaHit:EnableMouseWheel(true)

    local opaTrack = UI.SolidTex(opaHit, "ARTWORK", 1, 0.035, 0.039, 0.051, 0.98)
    opaTrack:SetSize(OPA_W, 4)
    opaTrack:SetPoint("CENTER", opaHit, "CENTER", 0, 0)

    local opaFill = UI.SolidTex(opaHit, "ARTWORK", 2, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.85)
    opaFill:SetPoint("TOPLEFT", opaTrack, "TOPLEFT", 0, 0)
    opaFill:SetPoint("BOTTOMLEFT", opaTrack, "BOTTOMLEFT", 0, 0)
    opaFill:SetWidth(1)

    local opaThumb = UI.SolidTex(opaHit, "OVERLAY", 4, 0.97, 0.98, 1.00, 1.0)
    opaThumb:SetSize(6, 14)
    if opaThumb.SetSnapToPixelGrid then
        opaThumb:SetSnapToPixelGrid(false)
        opaThumb:SetTexelSnappingBias(0)
    end

    local opaLabel = footer:CreateFontString(nil, "OVERLAY")
    opaLabel:SetPoint("RIGHT", opaHit, "LEFT", -4, 0)
    UI.SetFont(opaLabel, 10, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 0.85)
    opaLabel:SetText("Opacity")

    -- Center Hint Text (Strictly bounded between resetSuiteBtn and opaLabel so it never collides!)
    local dockHint = footer:CreateFontString(nil, "OVERLAY")
    dockHint:SetPoint("LEFT", resetSuiteBtn, "RIGHT", 10, 0)
    dockHint:SetPoint("RIGHT", opaLabel, "LEFT", -10, 0)
    dockHint:SetJustifyH("LEFT")
    dockHint:SetWordWrap(false)
    UI.SetFont(dockHint, 10, "", 0.431, 0.463, 0.506, 1)
    dockHint:SetText("Active Module: DynamicLoad   |cFF475569|||r   Slash: /dl")
    f.dockHint = dockHint

    local function ApplyWindowOpacity(val)
        val = math.max(OPA_MIN, math.min(OPA_MAX, val or 0.98))
        f:SetAlpha(val)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        if gTbl then gTbl.windowAlpha = val end
        if DynamicLoadDB then DynamicLoadDB.windowAlpha = val end
        local pct = (val - OPA_MIN) / (OPA_MAX - OPA_MIN)
        local xOff = pct * OPA_W
        opaFill:SetWidth(math.max(1, xOff))
        opaThumb:ClearAllPoints()
        opaThumb:SetPoint("CENTER", opaTrack, "LEFT", xOff, 0)
    end
    ApplyWindowOpacity(savedAlpha)
    f.ApplyWindowOpacity = ApplyWindowOpacity

    opaHit:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self:SetScript("OnUpdate", function(s)
                if not IsMouseButtonDown("LeftButton") then
                    s:SetScript("OnUpdate", nil)
                    return
                end
                local eff = opaTrack:GetEffectiveScale()
                local cx = GetCursorPosition() / eff
                local left = opaTrack:GetLeft()
                if left then
                    local pct = math.max(0, math.min(1, (cx - left) / OPA_W))
                    local raw = OPA_MIN + pct * (OPA_MAX - OPA_MIN)
                    local snapped = math.floor(raw * 50 + 0.5) / 50
                    if math.abs(snapped - (s._lastOpa or -1)) >= 0.001 then
                        s._lastOpa = snapped
                        ApplyWindowOpacity(snapped)
                    end
                end
            end)
        elseif button == "RightButton" then
            ApplyWindowOpacity(0.98)
        end
    end)
    opaHit:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    opaHit:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
    opaHit:SetScript("OnMouseWheel", function(_, delta)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        local cur = (gTbl and gTbl.windowAlpha) or (DynamicLoadDB and DynamicLoadDB.windowAlpha) or 0.98
        ApplyWindowOpacity(cur + (delta > 0 and 0.05 or -0.05))
    end)
    end

    ----------------------------------------------------------------------------
    -- 3. LEFT SUITE RAIL (204px Wide) - DYNAMIC MODULES + SUITE STUDIO & TOOLS
    ----------------------------------------------------------------------------
    local leftRail = CreateFrame("Frame", nil, f)
    leftRail:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -HDR_H)
    leftRail:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, DOCK_H)
    leftRail:SetWidth(RAIL_W)
    leftRail:SetFrameLevel((f:GetFrameLevel() or 1) + 5)
    if leftRail.SetClipsChildren then leftRail:SetClipsChildren(false) end
    leftRail:Show()
    f.leftRail = leftRail

    leftRail.bg = UI.SolidTex(leftRail, "BACKGROUND", 1, UI.COLORS.RAIL_BG.r, UI.COLORS.RAIL_BG.g, UI.COLORS.RAIL_BG.b, UI.COLORS.RAIL_BG.a)
    leftRail.bg:SetAllPoints()

    leftRail.divider = UI.SolidTex(leftRail, "OVERLAY", 3, 1, 1, 1, UI.COLORS.BORDER.a)
    leftRail.divider:SetPoint("TOPRIGHT", leftRail, "TOPRIGHT", 0, 0)
    leftRail.divider:SetPoint("BOTTOMRIGHT", leftRail, "BOTTOMRIGHT", 0, 0)
    leftRail.divider:SetWidth(1)

    do
    local DEFAULT_MODULE_KEYS = { "marker", "group", "prep", "vault", "dialogue", "bags", "mail", "chat", "load", "fps", "zoom" }
    UI.DEFAULT_MODULE_KEYS = DEFAULT_MODULE_KEYS

    function UI.IsUsingCustomRailOrder()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local saved = gTbl.moduleOrder
                   or (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.moduleOrder)
                   or (DynamicLoadDB and DynamicLoadDB.moduleOrder)
        return (type(saved) == "table" and #saved > 0)
    end

    function UI.GetOrderedModuleList()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local saved = gTbl.moduleOrder
                   or (_G.DynamicSuiteDB and _G.DynamicSuiteDB.global and _G.DynamicSuiteDB.global.moduleOrder)
                   or (DynamicLoadDB and DynamicLoadDB.moduleOrder)
        local list = {}
        local seen = {}

        if type(saved) == "table" and #saved > 0 then
            for _, key in ipairs(saved) do
                if not seen[key] then
                    for _, m in ipairs(addonTable.SUITE_MODULE_LIST or {}) do
                        if m.key == key or m.id == key or m.addonName == key then
                            local mKey = m.key or m.id
                            if not seen[mKey] then
                                seen[key] = true
                                seen[mKey] = true
                                if m.addonName then seen[m.addonName] = true end
                                table.insert(list, mKey)
                            end
                            break
                        end
                    end
                end
            end
        end

        for _, key in ipairs(DEFAULT_MODULE_KEYS) do
            if not seen[key] then
                seen[key] = true
                table.insert(list, key)
            end
        end

        local result = {}
        local addedModules = {}
        for _, key in ipairs(list) do
            for _, m in ipairs(addonTable.SUITE_MODULE_LIST or {}) do
                if m.key == key or m.id == key or m.addonName == key then
                    if not addedModules[m] then
                        addedModules[m] = true
                        table.insert(result, m)
                    end
                    break
                end
            end
        end
        for _, m in ipairs(addonTable.SUITE_MODULE_LIST or {}) do
            if not addedModules[m] then
                addedModules[m] = true
                table.insert(result, m)
            end
        end
        return result
    end

    function UI.MoveRailModule(targetKey, delta)
        if not targetKey then return end
        local ordered = UI.GetOrderedModuleList()
        local curIdx = nil
        for i, m in ipairs(ordered) do
            if m.key == targetKey or m.id == targetKey or m.addonName == targetKey then
                curIdx = i
                break
            end
        end
        if not curIdx then return end
        local newIdx = curIdx + delta
        newIdx = math.max(1, math.min(#ordered, newIdx))
        if newIdx == curIdx then return end

        local item = table.remove(ordered, curIdx)
        table.insert(ordered, newIdx, item)

        local newKeys = {}
        for _, m in ipairs(ordered) do
            table.insert(newKeys, m.key or m.id)
        end

        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        gTbl.moduleOrder = newKeys
        if DynamicLoadDB then DynamicLoadDB.moduleOrder = newKeys end
        if _G.DynamicSuiteDB then
            _G.DynamicSuiteDB.global = _G.DynamicSuiteDB.global or {}
            _G.DynamicSuiteDB.global.moduleOrder = newKeys
        end

        if mainFrame and mainFrame.RefreshLeftRailLayout then
            mainFrame.RefreshLeftRailLayout()
        end
    end

    function UI.SwapRailModules(key1, key2)
        if not key1 or not key2 or key1 == key2 then return end
        local ordered = UI.GetOrderedModuleList()
        local idx1, idx2 = nil, nil
        for i, m in ipairs(ordered) do
            if m.key == key1 or m.id == key1 or m.addonName == key1 then idx1 = i end
            if m.key == key2 or m.id == key2 or m.addonName == key2 then idx2 = i end
        end
        if idx1 and idx2 then
            local temp = ordered[idx1]
            ordered[idx1] = ordered[idx2]
            ordered[idx2] = temp

            local newKeys = {}
            for _, m in ipairs(ordered) do
                table.insert(newKeys, m.key or m.id)
            end
            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
            gTbl.moduleOrder = newKeys
            if DynamicLoadDB then DynamicLoadDB.moduleOrder = newKeys end
            if _G.DynamicSuiteDB then
                _G.DynamicSuiteDB.global = _G.DynamicSuiteDB.global or {}
                _G.DynamicSuiteDB.global.moduleOrder = newKeys
            end

            if mainFrame and mainFrame.RefreshLeftRailLayout then
                mainFrame.RefreshLeftRailLayout()
            end
        end
    end

    local railSwapArmedKey = nil
    local railModuleCardsByKey = {}

    -- Top-of-Rail Global Smart Search Input (184x24px Obsidian Search Bar)
    local railSearchWrap = CreateFrame("Frame", nil, leftRail)
    railSearchWrap:SetSize(RAIL_W - 20, 24)
    railSearchWrap:SetPoint("TOPLEFT", leftRail, "TOPLEFT", 10, -8)
    railSearchWrap:Show()
    railSearchWrap.bg = UI.SolidTex(railSearchWrap, "BACKGROUND", 2, 0.031, 0.039, 0.055, 0.98)
    railSearchWrap.bg:SetAllPoints()
    UI.CreatePixelBorder(railSearchWrap, 0.165, 0.192, 0.259, 0.95, 3)
    f.railSearchWrap = railSearchWrap

    local railSearchIcon = railSearchWrap:CreateTexture(nil, "OVERLAY", nil, 3)
    railSearchIcon:SetSize(12, 12)
    railSearchIcon:SetPoint("LEFT", railSearchWrap, "LEFT", 7, 0)
    railSearchIcon:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_spark.tga")
    railSearchIcon:SetVertexColor(0.62, 0.68, 0.78, 0.92)
    railSearchWrap.iconTex = railSearchIcon

    local railSearchBox = CreateFrame("EditBox", "DynamicSuiteRailSearchBox", railSearchWrap)
    railSearchBox:SetPoint("LEFT", railSearchIcon, "RIGHT", 5, 0)
    railSearchBox:SetPoint("RIGHT", railSearchWrap, "RIGHT", -20, 0)
    railSearchBox:SetHeight(20)
    railSearchBox:SetAutoFocus(false)
    UI.SetFont(railSearchBox, 10, "", 1, 1, 1, 0.96)
    railSearchBox:SetText("")
    f.railSearchBox = railSearchBox

    local railSearchPlaceholder = railSearchWrap:CreateFontString(nil, "OVERLAY")
    railSearchPlaceholder:SetPoint("LEFT", railSearchIcon, "RIGHT", 5, 0)
    railSearchPlaceholder:SetPoint("RIGHT", railSearchWrap, "RIGHT", -20, 0)
    railSearchPlaceholder:SetJustifyH("LEFT")
    railSearchPlaceholder:SetWordWrap(false)
    UI.SetFont(railSearchPlaceholder, 10, "", 0.45, 0.50, 0.58, 0.95)
    railSearchPlaceholder:SetText("Search all features...")
    f.railSearchPlaceholder = railSearchPlaceholder

    local railSearchClearBtn = CreateFrame("Button", nil, railSearchWrap)
    railSearchClearBtn:SetSize(16, 16)
    railSearchClearBtn:SetPoint("RIGHT", railSearchWrap, "RIGHT", -3, 0)
    local railSearchClearTxt = railSearchClearBtn:CreateFontString(nil, "OVERLAY")
    railSearchClearTxt:SetPoint("CENTER", 0, 0)
    UI.SetFont(railSearchClearTxt, 10, "", 0.62, 0.68, 0.78, 0.95)
    railSearchClearTxt:SetText("X")
    railSearchClearBtn.txt = railSearchClearTxt
    railSearchClearBtn:Hide()
    f.railSearchClearBtn = railSearchClearBtn

    local function UpdateRailSearchBoxVisual()
        local txt = railSearchBox:GetText() or ""
        local hasText = (txt ~= "")
        local isFocused = railSearchBox:HasFocus()
        local isSearchActive = (activeWorkspaceView == "SEARCH_VIEW")
        railSearchPlaceholder:SetShown((not hasText) and (not isFocused))
        railSearchClearBtn:SetShown(hasText or isSearchActive)
        local ar, ag, ab = UI.GetActiveAccentColor()
        if isFocused or isSearchActive then
            railSearchWrap.dsBorder:SetColor(ar, ag, ab, 0.95)
            railSearchIcon:SetVertexColor(ar, ag, ab, 1.0)
        else
            railSearchWrap.dsBorder:SetColor(0.165, 0.192, 0.259, 0.95)
            railSearchIcon:SetVertexColor(0.62, 0.68, 0.78, 0.92)
        end
    end
    f.UpdateRailSearchBoxVisual = UpdateRailSearchBoxVisual

    local function ExitSearchViewToPrevious()
        railSearchBox:SetText("")
        railSearchBox:ClearFocus()
        if activeWorkspaceView == "SEARCH_VIEW" then
            local prevView = f.preSearchWorkspaceView or "DYNAMICLOAD"
            local prevPeer = f.preSearchPeerModuleKey
            if (prevView == "PEER_HOST" or prevView == "PEER_MODULE") and prevPeer then
                addonTable.OpenPeerModule(prevPeer)
            else
                addonTable.OpenWorkspaceView(prevView)
            end
        end
        UpdateRailSearchBoxVisual()
    end
    f.ExitSearchViewToPrevious = ExitSearchViewToPrevious

    railSearchClearBtn:SetScript("OnEnter", function(selfBtn)
        selfBtn.txt:SetTextColor(1, 0.42, 0.42, 1)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
        GameTooltip:SetText("Clear Search & Return", 1, 1, 1)
        GameTooltip:AddLine("Clears your search filter and returns to the previous module workspace.", 0.82, 0.86, 0.92, true)
        GameTooltip:Show()
    end)
    railSearchClearBtn:SetScript("OnLeave", function(selfBtn)
        selfBtn.txt:SetTextColor(0.62, 0.68, 0.78, 0.95)
        GameTooltip:Hide()
    end)
    railSearchClearBtn:SetScript("OnClick", function()
        ExitSearchViewToPrevious()
    end)

    railSearchBox:SetScript("OnEditFocusGained", function()
        if activeWorkspaceView ~= "SEARCH_VIEW" then
            f.preSearchWorkspaceView = activeWorkspaceView
            f.preSearchPeerModuleKey = selectedPeerModuleKey
            addonTable.OpenWorkspaceView("SEARCH_VIEW")
        elseif f.searchView and f.searchView.Refresh then
            f.searchView.Refresh()
        end
        UpdateRailSearchBoxVisual()
    end)
    railSearchBox:SetScript("OnEditFocusLost", function()
        UpdateRailSearchBoxVisual()
    end)
    railSearchBox:SetScript("OnTextChanged", function(_, userInput)
        UpdateRailSearchBoxVisual()
        if not userInput then return end
        if activeWorkspaceView ~= "SEARCH_VIEW" then
            f.preSearchWorkspaceView = activeWorkspaceView
            f.preSearchPeerModuleKey = selectedPeerModuleKey
            addonTable.OpenWorkspaceView("SEARCH_VIEW")
        elseif f.searchView and f.searchView.Refresh then
            f.searchView.Refresh()
        end
    end)
    railSearchBox:SetScript("OnEnterPressed", function(selfBox)
        selfBox:ClearFocus()
        if f.searchView and f.searchView.TriggerTopResult then
            f.searchView.TriggerTopResult()
        end
    end)
    railSearchBox:SetScript("OnEscapePressed", function(selfBox)
        local curTxt = selfBox:GetText() or ""
        if curTxt ~= "" then
            selfBox:SetText("")
            UpdateRailSearchBoxVisual()
            if f.searchView and f.searchView.Refresh then
                f.searchView.Refresh()
            end
        else
            ExitSearchViewToPrevious()
        end
    end)

    local modSectionHdr = leftRail:CreateFontString(nil, "OVERLAY")
    modSectionHdr:SetPoint("TOPLEFT", leftRail, "TOPLEFT", 14, -38)
    UI.SetFont(modSectionHdr, 10, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 0.90)
    modSectionHdr:SetText("DYNAMIC MODULES")
    modSectionHdr:Show()
    f.modSectionHdr = modSectionHdr

    local resetSortBtn = CreateFrame("Button", nil, leftRail)
    resetSortBtn:SetSize(68, 18)
    resetSortBtn:SetPoint("TOPRIGHT", leftRail, "TOPRIGHT", -10, -35)
    f.resetSortBtn = resetSortBtn
    resetSortBtn.bg = UI.SolidTex(resetSortBtn, "BACKGROUND", 1, 0.08, 0.09, 0.12, 0.70)
    resetSortBtn.bg:SetAllPoints()
    UI.CreatePixelBorder(resetSortBtn, 1, 1, 1, 0.14, 2)
    local resetSortTxt = resetSortBtn:CreateFontString(nil, "OVERLAY")
    UI.SetFont(resetSortTxt, 9, "", 0.65, 0.70, 0.78, 0.90)
    resetSortTxt:SetPoint("CENTER", 0, 0)
    resetSortTxt:SetText("Reset Sort")
    resetSortBtn:SetScript("OnEnter", function(selfBtn)
        local ar, ag, ab = UI.GetActiveAccentColor()
        selfBtn.bg:SetColorTexture(ar, ag, ab, 0.20)
        selfBtn.dsBorder:SetColor(ar, ag, ab, 0.85)
        resetSortTxt:SetTextColor(1, 1, 1, 1)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
        GameTooltip:SetText("Reset Module Order", 1, 1, 1)
        GameTooltip:AddLine("Restores the default 4-category module layout (Combat & Group, Progression & Quests, Inventory & Social, Performance & System).", 0.82, 0.86, 0.92, true)
        GameTooltip:Show()
    end)
    resetSortBtn:SetScript("OnLeave", function(selfBtn)
        selfBtn.bg:SetColorTexture(0.08, 0.09, 0.12, 0.70)
        selfBtn.dsBorder:SetColor(1, 1, 1, 0.14)
        resetSortTxt:SetTextColor(0.65, 0.70, 0.78, 0.90)
        GameTooltip:Hide()
    end)
    resetSortBtn:SetScript("OnClick", function()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        gTbl.moduleOrder = nil
        if DynamicLoadDB then DynamicLoadDB.moduleOrder = nil end
        if _G.DynamicSuiteDB and _G.DynamicSuiteDB.global then _G.DynamicSuiteDB.global.moduleOrder = nil end
        railSwapArmedKey = nil
        if f.RefreshLeftRailLayout then
            f.RefreshLeftRailLayout()
        end
    end)

    local railStudioBtns = {}
    local railDragGhost = nil

    local function EnsureRailDragGhost()
        if railDragGhost then return railDragGhost end
        local g = CreateFrame("Frame", nil, f)
        g:SetSize(RAIL_W - 20, 35)
        g:SetFrameStrata("TOOLTIP")
        g:SetFrameLevel(200)
        g:SetAlpha(0.88)
        g.bg = UI.SolidTex(g, "BACKGROUND", 2, 0.06, 0.07, 0.10, 0.96)
        g.bg:SetAllPoints()
        local ar, ag, ab = UI.GetActiveAccentColor()
        UI.CreatePixelBorder(g, ar, ag, ab, 1.0, 3)

        g.leftBar = UI.SolidTex(g, "OVERLAY", 4, ar, ag, ab, 1)
        g.leftBar:SetPoint("TOPLEFT", g, "TOPLEFT", 0, 0)
        g.leftBar:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 0, 0)
        g.leftBar:SetWidth(3)

        local ic = g:CreateTexture(nil, "ARTWORK", nil, 3)
        ic:SetSize(16, 16)
        ic:SetPoint("LEFT", g, "LEFT", 8, 0)
        g.icon = ic

        local t = g:CreateFontString(nil, "OVERLAY")
        t:SetPoint("TOPLEFT", g, "TOPLEFT", 28, -5)
        UI.SetFont(t, 11, "", 1, 1, 1, 0.98)
        g.title = t

        local s = g:CreateFontString(nil, "OVERLAY")
        s:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 28, 4)
        s:SetPoint("RIGHT", g, "RIGHT", -8, 0)
        s:SetJustifyH("LEFT")
        s:SetWordWrap(false)
        UI.SetFont(s, 9, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 0.90)
        g.sub = s

        g:Hide()
        railDragGhost = g
        return g
    end

    local railModuleScroll = CreateFrame("Frame", nil, leftRail)
    railModuleScroll:SetPoint("TOPLEFT", leftRail, "TOPLEFT", 0, -54)
    railModuleScroll:SetPoint("BOTTOMRIGHT", leftRail, "BOTTOMRIGHT", 0, 152)
    railModuleScroll:SetWidth(RAIL_W)
    railModuleScroll:SetFrameLevel((leftRail:GetFrameLevel() or 6) + 2)
    if railModuleScroll.SetClipsChildren then railModuleScroll:SetClipsChildren(true) end
    railModuleScroll:Show()
    railModuleScroll:EnableMouseWheel(true)
    f.railModuleScroll = railModuleScroll

    local railModuleChild = CreateFrame("Frame", nil, railModuleScroll)
    railModuleChild:SetPoint("TOPLEFT", railModuleScroll, "TOPLEFT", 0, 0)
    railModuleChild:SetSize(RAIL_W, 498)
    railModuleChild:SetFrameLevel((railModuleScroll:GetFrameLevel() or 8) + 1)
    if railModuleChild.SetClipsChildren then railModuleChild:SetClipsChildren(false) end
    railModuleChild:Show()
    f.railModuleChild = railModuleChild
    f.railCards = railModuleCards

    local curRailScroll = 0

    -- 3-Way Interactive 4px Obsidian Scrollbar for Left Suite Rail
    local railScrollTrack = CreateFrame("Frame", nil, railModuleScroll)
    railScrollTrack:SetPoint("TOPRIGHT", railModuleScroll, "TOPRIGHT", -3, -2)
    railScrollTrack:SetPoint("BOTTOMRIGHT", railModuleScroll, "BOTTOMRIGHT", -3, 2)
    railScrollTrack:SetWidth(4)
    railScrollTrack:SetFrameLevel((railModuleScroll:GetFrameLevel() or 8) + 6)
    railScrollTrack:EnableMouse(true)
    railScrollTrack:EnableMouseWheel(true)
    railScrollTrack.bg = UI.SolidTex(railScrollTrack, "BACKGROUND", 1, 0.035, 0.039, 0.051, 0.90)
    railScrollTrack.bg:SetAllPoints()

    local railScrollThumb = CreateFrame("Button", nil, railScrollTrack)
    railScrollThumb:SetWidth(4)
    railScrollThumb:SetHeight(36)
    railScrollThumb:SetPoint("TOP", railScrollTrack, "TOP", 0, 0)
    railScrollThumb:EnableMouse(true)
    railScrollThumb:EnableMouseWheel(true)
    railScrollThumb.tex = UI.SolidTex(railScrollThumb, "OVERLAY", 2, 0.42, 0.47, 0.56, 0.85)
    railScrollThumb.tex:SetAllPoints()
    railScrollThumb._isDragging = false

    local function UpdateRailScrollBar()
        local visH = railModuleScroll:GetHeight() or 0
        if visH <= 10 then
            local fh = (f:GetHeight() or PANEL_H)
            visH = math.max(120, fh - HDR_H - DOCK_H - 54 - 152)
        end
        local totalH = railModuleChild:GetHeight() or 0
        local maxRange = math.max(0, totalH - visH)
        if curRailScroll > maxRange then curRailScroll = maxRange end
        if curRailScroll < 0 then curRailScroll = 0 end

        railModuleChild:ClearAllPoints()
        railModuleChild:SetPoint("TOPLEFT", railModuleScroll, "TOPLEFT", 0, curRailScroll)

        if maxRange <= 0.5 then
            railScrollTrack:Hide()
            railScrollThumb:Hide()
            return
        end
        railScrollTrack:Show()
        railScrollThumb:Show()

        local trackH = railScrollTrack:GetHeight() or 0
        if trackH <= 10 then trackH = math.max(40, visH - 4) end
        local thumbH = math.max(24, math.floor((visH / math.max(1, totalH)) * trackH))
        thumbH = math.min(trackH, thumbH)
        railScrollThumb:SetHeight(thumbH)

        local ratio = (maxRange > 0) and (curRailScroll / maxRange) or 0
        local maxThumbOff = math.max(0, trackH - thumbH)
        railScrollThumb:ClearAllPoints()
        railScrollThumb:SetPoint("TOP", railScrollTrack, "TOP", 0, -(ratio * maxThumbOff))

        if railScrollThumb._isDragging or railScrollThumb:IsMouseOver() then
            local ar, ag, ab = UI.GetActiveAccentColor()
            railScrollThumb.tex:SetColorTexture(ar, ag, ab, 1.0)
        else
            railScrollThumb.tex:SetColorTexture(0.42, 0.47, 0.56, 0.80)
        end
    end
    f.UpdateRailScrollBar = UpdateRailScrollBar

    railModuleScroll.GetVerticalScroll = function() return curRailScroll end
    railModuleScroll.SetVerticalScroll = function(_, val)
        local visH = railModuleScroll:GetHeight() or 0
        if visH <= 10 then
            visH = math.max(120, (f:GetHeight() or PANEL_H) - HDR_H - DOCK_H - 54 - 152)
        end
        local maxRange = math.max(0, (railModuleChild:GetHeight() or 0) - visH)
        curRailScroll = math.max(0, math.min(maxRange, tonumber(val) or 0))
        UpdateRailScrollBar()
    end
    railModuleScroll.UpdateScrollChildRect = UpdateRailScrollBar

    local function StepRailMouseWheel(_, delta)
        local visH = railModuleScroll:GetHeight() or 0
        if visH <= 10 then
            visH = math.max(120, (f:GetHeight() or PANEL_H) - HDR_H - DOCK_H - 54 - 152)
        end
        local maxRange = math.max(0, (railModuleChild:GetHeight() or 0) - visH)
        if maxRange <= 0.5 then
            curRailScroll = 0
            UpdateRailScrollBar()
            return
        end
        curRailScroll = math.max(0, math.min(maxRange, curRailScroll - (delta * 38)))
        UpdateRailScrollBar()
    end
    railModuleScroll:SetScript("OnMouseWheel", StepRailMouseWheel)
    railScrollTrack:SetScript("OnMouseWheel", StepRailMouseWheel)
    railScrollThumb:SetScript("OnMouseWheel", StepRailMouseWheel)

    local function StopRailThumbDrag()
        railScrollThumb._isDragging = false
        railScrollThumb:SetScript("OnUpdate", nil)
        UpdateRailScrollBar()
    end
    railScrollThumb:SetScript("OnEnter", function()
        local ar, ag, ab = UI.GetActiveAccentColor()
        railScrollThumb.tex:SetColorTexture(ar, ag, ab, 1.0)
    end)
    railScrollThumb:SetScript("OnLeave", function()
        if not railScrollThumb._isDragging then
            railScrollThumb.tex:SetColorTexture(0.42, 0.47, 0.56, 0.80)
        end
    end)
    railScrollThumb:SetScript("OnMouseDown", function(selfBtn, button)
        if button ~= "LeftButton" then return end
        selfBtn._isDragging = true
        local _, cy = GetCursorPosition()
        local scale = selfBtn:GetEffectiveScale() or 1
        if scale <= 0 then scale = 1 end
        local dragStartY = (cy or 0) / scale
        local dragStartScroll = curRailScroll
        local ar, ag, ab = UI.GetActiveAccentColor()
        selfBtn.tex:SetColorTexture(ar, ag, ab, 1.0)
        selfBtn:SetScript("OnUpdate", function()
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                StopRailThumbDrag()
                return
            end
            local _, curY = GetCursorPosition()
            local sc = selfBtn:GetEffectiveScale() or 1
            if sc <= 0 then sc = 1 end
            local dy = dragStartY - ((curY or 0) / sc)
            local visH = railModuleScroll:GetHeight() or 350
            local totalH = railModuleChild:GetHeight() or 498
            local maxRange = math.max(0, totalH - visH)
            local trackH = math.max(1, (railScrollTrack:GetHeight() or visH) - (selfBtn:GetHeight() or 24))
            if maxRange > 0 then
                curRailScroll = math.max(0, math.min(maxRange, dragStartScroll + (dy / trackH) * maxRange))
                UpdateRailScrollBar()
            end
        end)
    end)
    railScrollThumb:SetScript("OnMouseUp", StopRailThumbDrag)
    railScrollThumb:SetScript("OnHide", StopRailThumbDrag)

    railScrollTrack:SetScript("OnMouseDown", function(selfTrack, button)
        if button ~= "LeftButton" then return end
        local trackTop = selfTrack:GetTop()
        local trackH = selfTrack:GetHeight() or 0
        if not trackTop or trackH <= 10 then return end
        local _, cy = GetCursorPosition()
        local scale = selfTrack:GetEffectiveScale() or 1
        if scale <= 0 then scale = 1 end
        local clickY = trackTop - ((cy or 0) / scale)
        local thumbH = railScrollThumb:GetHeight() or 24
        local usableH = math.max(1, trackH - thumbH)
        local ratio = math.max(0, math.min(1, (clickY - (thumbH * 0.5)) / usableH))
        local visH = railModuleScroll:GetHeight() or 350
        local maxRange = math.max(0, (railModuleChild:GetHeight() or 498) - visH)
        curRailScroll = ratio * maxRange
        UpdateRailScrollBar()
    end)

    -- 4 Category Sub-Headers inside railModuleChild (shown in default grouped order)
    local railCategoryHeaders = {}
    local function GetOrCreateRailCategoryHeader(catKey, catLabel)
        local hdr = railCategoryHeaders[catKey]
        if hdr then
            if hdr.label then hdr.label:SetText(catLabel or "") end
            return hdr
        end
        hdr = CreateFrame("Frame", nil, railModuleChild)
        hdr:SetSize(RAIL_W - 20, 16)
        local ar, ag, ab = UI.GetActiveAccentColor()
        hdr.tick = UI.SolidTex(hdr, "OVERLAY", 3, ar, ag, ab, 0.85)
        hdr.tick:SetSize(2, 9)
        hdr.tick:SetPoint("LEFT", hdr, "LEFT", 0, 0)

        hdr.label = hdr:CreateFontString(nil, "OVERLAY")
        hdr.label:SetPoint("LEFT", hdr.tick, "RIGHT", 5, 0)
        hdr.label:SetJustifyH("LEFT")
        hdr.label:SetWordWrap(false)
        UI.SetFont(hdr.label, 8.5, "", 0.58, 0.65, 0.76, 0.95)
        hdr.label:SetText(catLabel or "")

        hdr.line = UI.SolidTex(hdr, "ARTWORK", 2, 1, 1, 1, 0.08)
        hdr.line:SetHeight(1)
        hdr.line:SetPoint("LEFT", hdr.label, "RIGHT", 6, 0)
        hdr.line:SetPoint("RIGHT", hdr, "RIGHT", 0, 0)

        railCategoryHeaders[catKey] = hdr
        return hdr
    end
    f.railCategoryHeaders = railCategoryHeaders

    local function CreateRailModuleCard(idx, modInfo)
        local card = CreateFrame("Button", nil, railModuleChild)
        card:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        card:SetSize(RAIL_W - 20, 35)
        card:SetPoint("TOPLEFT", railModuleChild, "TOPLEFT", 10, -((idx - 1) * 38))
        card.modInfo = modInfo
        card.railIndex = idx

        card.bg = UI.SolidTex(card, "BACKGROUND", 2, 1, 1, 1, 0.025)
        card.bg:SetAllPoints()
        UI.CreatePixelBorder(card, 1, 1, 1, 0.08, 3)

        card.leftBar = UI.SolidTex(card, "OVERLAY", 4, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 1)
        card.leftBar:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
        card.leftBar:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0)
        card.leftBar:SetWidth(3)
        card.leftBar:Hide()

        local addonKey = modInfo.addonName or modInfo.name or modInfo.key
        local shortKey = modInfo.id or modInfo.key or tostring(addonKey):gsub("^Dynamic", ""):lower()

        railModuleCardsByKey[shortKey] = card
        railModuleCardsByKey[addonKey] = card
        if modInfo.key then railModuleCardsByKey[modInfo.key] = card end

        local modIcon = card:CreateTexture(nil, "ARTWORK", nil, 3)
        modIcon:SetSize(16, 16)
        modIcon:SetPoint("LEFT", card, "LEFT", 8, 0)
        modIcon:SetTexture(UI.GetModuleIconPath(addonKey, modInfo.icon))
        modIcon:SetVertexColor(0.72, 0.76, 0.84, 0.95)
        card.modIcon = modIcon

        local mTitle = card:CreateFontString(nil, "OVERLAY")
        mTitle:SetPoint("TOPLEFT", card, "TOPLEFT", 28, -5)
        mTitle:SetJustifyH("LEFT")
        mTitle:SetWordWrap(false)
        UI.SetFont(mTitle, 11, "", 1, 1, 1, 0.96)
        mTitle:SetText(UI.FormatTwoToneBrand(modInfo.title))
        card.mTitle = mTitle

        -- Prototype Pill Toggle Switch (26x14px track + 10x10px white thumb) on top-right of module card
        local pillSwitch = CreateFrame("Button", nil, card)
        pillSwitch:SetSize(26, 14)
        pillSwitch:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -4)
        pillSwitch.bg = UI.SolidTex(pillSwitch, "BACKGROUND", 3, 0.078, 0.090, 0.118, 1.0)
        pillSwitch.bg:SetAllPoints()
        UI.CreatePixelBorder(pillSwitch, 1, 1, 1, 0.16, 4)

        local conflictPip = UI.SolidTex(card, "OVERLAY", 5, UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1.0)
        conflictPip:SetSize(5, 5)
        conflictPip:SetPoint("RIGHT", pillSwitch, "LEFT", -4, 0)
        conflictPip:Hide()
        card.conflictPip = conflictPip

        mTitle:SetPoint("RIGHT", pillSwitch, "LEFT", -6, 0)

        local pillThumb = UI.SolidTex(pillSwitch, "OVERLAY", 5, 1, 1, 1, 0.96)
        pillThumb:SetSize(10, 10)
        pillThumb:SetPoint("RIGHT", pillSwitch, "RIGHT", -2, 0)
        card.pillSwitch = pillSwitch
        card.pillThumb = pillThumb

        do
            card:RegisterForDrag("LeftButton")

            local downBtn = CreateFrame("Button", nil, card)
            downBtn:SetSize(13, 14)
            downBtn:SetPoint("RIGHT", pillSwitch, "LEFT", -4, 0)
            downBtn.bg = UI.SolidTex(downBtn, "BACKGROUND", 2, 0.08, 0.09, 0.12, 0.85)
            downBtn.bg:SetAllPoints()
            UI.CreatePixelBorder(downBtn, 1, 1, 1, 0.18, 2)
            local downIcon = downBtn:CreateTexture(nil, "OVERLAY")
            downIcon:SetSize(8, 8)
            downIcon:SetPoint("CENTER", 0, 0)
            downIcon:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga")
            downIcon:SetVertexColor(0.72, 0.76, 0.84, 0.90)
            UI.DisablePixelSnap(downIcon)
            downBtn.icon = downIcon
            local downTxt = downBtn:CreateFontString(nil, "OVERLAY")
            UI.SetFont(downTxt, 8, "", 0.72, 0.76, 0.84, 0.90)
            downTxt:SetPoint("CENTER", 0, 0)
            downTxt:SetText("v")
            downTxt:Hide()
            downBtn.txt = downTxt
            downBtn:Hide()

            local upBtn = CreateFrame("Button", nil, card)
            upBtn:SetSize(13, 14)
            upBtn:SetPoint("RIGHT", downBtn, "LEFT", -2, 0)
            upBtn.bg = UI.SolidTex(upBtn, "BACKGROUND", 2, 0.08, 0.09, 0.12, 0.85)
            upBtn.bg:SetAllPoints()
            UI.CreatePixelBorder(upBtn, 1, 1, 1, 0.18, 2)
            local upIcon = upBtn:CreateTexture(nil, "OVERLAY")
            upIcon:SetSize(8, 8)
            upIcon:SetPoint("CENTER", 0, 0)
            upIcon:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga")
            upIcon:SetVertexColor(0.72, 0.76, 0.84, 0.90)
            UI.DisablePixelSnap(upIcon)
            upBtn.icon = upIcon
            local upTxt = upBtn:CreateFontString(nil, "OVERLAY")
            UI.SetFont(upTxt, 8, "", 0.72, 0.76, 0.84, 0.90)
            upTxt:SetPoint("CENTER", 0, 0)
            upTxt:SetText("^")
            upTxt:Hide()
            upBtn.txt = upTxt
            upBtn:Hide()

            local function HookNudgeBtn(btn, delta, label)
                btn:SetScript("OnEnter", function(b)
                    local r, g, bl = UI.GetActiveAccentColor()
                    b.bg:SetColorTexture(r, g, bl, 0.25)
                    b.dsBorder:SetColor(r, g, bl, 0.90)
                    if b.icon then b.icon:SetVertexColor(1, 1, 1, 1) end
                    if b.txt then b.txt:SetTextColor(1, 1, 1, 1) end
                    GameTooltip:SetOwner(b, "ANCHOR_TOP")
                    GameTooltip:SetText(label, 1, 1, 1)
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", function(b)
                    b.bg:SetColorTexture(0.08, 0.09, 0.12, 0.85)
                    b.dsBorder:SetColor(1, 1, 1, 0.18)
                    if b.icon then b.icon:SetVertexColor(0.72, 0.76, 0.84, 0.90) end
                    if b.txt then b.txt:SetTextColor(0.72, 0.76, 0.84, 0.90) end
                    GameTooltip:Hide()
                end)
                btn:SetScript("OnClick", function()
                    UI.MoveRailModule(shortKey, delta)
                end)
            end
            HookNudgeBtn(upBtn, -1, "Move Up")
            HookNudgeBtn(downBtn, 1, "Move Down")
            card.upBtn = upBtn
            card.downBtn = downBtn

            local function UpdateNudgeVisibility()
                if card._isDragging or (not card:IsMouseOver() and not (card.upBtn and card.upBtn:IsMouseOver()) and not (card.downBtn and card.downBtn:IsMouseOver())) then
                    if card.upBtn then card.upBtn:Hide() end
                    if card.downBtn then card.downBtn:Hide() end
                    mTitle:ClearAllPoints()
                    mTitle:SetPoint("TOPLEFT", card, "TOPLEFT", 28, -5)
                    mTitle:SetPoint("RIGHT", pillSwitch, "LEFT", -6, 0)
                else
                    local totalCount = #railModuleCards > 0 and #railModuleCards or 11
                    local rIdx = card.railIndex or 1
                    local showUp = (rIdx > 1)
                    local showDown = (rIdx < totalCount)

                    if showUp and showDown then
                        downBtn:ClearAllPoints()
                        downBtn:SetPoint("RIGHT", pillSwitch, "LEFT", -4, 0)
                        downBtn:Show()
                        upBtn:ClearAllPoints()
                        upBtn:SetPoint("RIGHT", downBtn, "LEFT", -2, 0)
                        upBtn:Show()
                        mTitle:ClearAllPoints()
                        mTitle:SetPoint("TOPLEFT", card, "TOPLEFT", 28, -5)
                        mTitle:SetPoint("RIGHT", upBtn, "LEFT", -4, 0)
                    elseif showDown then
                        upBtn:Hide()
                        downBtn:ClearAllPoints()
                        downBtn:SetPoint("RIGHT", pillSwitch, "LEFT", -4, 0)
                        downBtn:Show()
                        mTitle:ClearAllPoints()
                        mTitle:SetPoint("TOPLEFT", card, "TOPLEFT", 28, -5)
                        mTitle:SetPoint("RIGHT", downBtn, "LEFT", -4, 0)
                    elseif showUp then
                        downBtn:Hide()
                        upBtn:ClearAllPoints()
                        upBtn:SetPoint("RIGHT", pillSwitch, "LEFT", -4, 0)
                        upBtn:Show()
                        mTitle:ClearAllPoints()
                        mTitle:SetPoint("TOPLEFT", card, "TOPLEFT", 28, -5)
                        mTitle:SetPoint("RIGHT", upBtn, "LEFT", -4, 0)
                    else
                        upBtn:Hide()
                        downBtn:Hide()
                        mTitle:ClearAllPoints()
                        mTitle:SetPoint("TOPLEFT", card, "TOPLEFT", 28, -5)
                        mTitle:SetPoint("RIGHT", pillSwitch, "LEFT", -6, 0)
                    end
                end
            end
            card.UpdateNudgeVisibility = UpdateNudgeVisibility
            card:HookScript("OnEnter", UpdateNudgeVisibility)
            card:HookScript("OnLeave", function()
                C_Timer.After(0.05, UpdateNudgeVisibility)
            end)
            upBtn:HookScript("OnLeave", function()
                C_Timer.After(0.05, UpdateNudgeVisibility)
            end)
            downBtn:HookScript("OnLeave", function()
                C_Timer.After(0.05, UpdateNudgeVisibility)
            end)

            card:SetScript("OnDragStart", function(self)
                railSwapArmedKey = nil
                self._isDragging = true
                if self.upBtn then self.upBtn:Hide() end
                if self.downBtn then self.downBtn:Hide() end
                mTitle:ClearAllPoints()
                mTitle:SetPoint("TOPLEFT", card, "TOPLEFT", 28, -5)
                mTitle:SetPoint("RIGHT", pillSwitch, "LEFT", -6, 0)
                self:SetAlpha(0.30)

                local ghost = EnsureRailDragGhost()
                local ar, ag, ab = UI.GetActiveAccentColor()
                if ghost.dsBorder then ghost.dsBorder:SetColor(ar, ag, ab, 1.0) end
                if ghost.leftBar then ghost.leftBar:SetColorTexture(ar, ag, ab, 1.0) end
                if ghost.icon then
                    ghost.icon:SetTexture(UI.GetModuleIconPath(addonKey, modInfo.icon))
                    ghost.icon:SetVertexColor(ar, ag, ab, 1.0)
                end
                if ghost.title then ghost.title:SetText(UI.FormatTwoToneBrand(modInfo.title or addonKey)) end
                if ghost.sub then ghost.sub:SetText(modInfo.subtitle or modInfo.desc or "") end
                ghost:Show()

                leftRail:SetScript("OnUpdate", function()
                    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                        if self:GetScript("OnDragStop") then
                            self:GetScript("OnDragStop")(self)
                        end
                        return
                    end
                    local scale = f:GetEffectiveScale() or 1
                    if scale <= 0 then scale = 1 end
                    local curX, curY = GetCursorPosition()
                    local lx = (curX or 0) / scale
                    local ly = (curY or 0) / scale

                    ghost:ClearAllPoints()
                    ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", lx, ly)

                    local railTop = leftRail:GetTop()
                    if railTop then
                        local ordered = UI.GetOrderedModuleList()
                        local scrollTop = (railModuleScroll and railModuleScroll:GetTop()) or (railTop - 54)
                        local scrollOff = (railModuleScroll and railModuleScroll:GetVerticalScroll()) or 0
                        local cursorRelY = scrollTop - ly + scrollOff
                        local targetSlot = nil
                        for i, rc in ipairs(railModuleCards) do
                            local cTop = rc._railY or ((i - 1) * 38)
                            if cursorRelY < (cTop + 19) then
                                targetSlot = i
                                break
                            end
                        end
                        if not targetSlot then
                            targetSlot = #ordered
                        end
                        targetSlot = math.max(1, math.min(#ordered, targetSlot))
                        if targetSlot ~= self.railIndex then
                            local curIdx = nil
                            for i, m in ipairs(ordered) do
                                if m.key == shortKey or m.id == shortKey or m.addonName == addonKey then
                                    curIdx = i
                                    break
                                end
                            end
                            if curIdx and curIdx ~= targetSlot then
                                local item = table.remove(ordered, curIdx)
                                table.insert(ordered, targetSlot, item)
                                local newKeys = {}
                                for _, m in ipairs(ordered) do
                                    table.insert(newKeys, m.key or m.id)
                                end
                                local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
                                gTbl.moduleOrder = newKeys
                                if DynamicLoadDB then DynamicLoadDB.moduleOrder = newKeys end
                                if _G.DynamicSuiteDB then
                                    _G.DynamicSuiteDB.global = _G.DynamicSuiteDB.global or {}
                                    _G.DynamicSuiteDB.global.moduleOrder = newKeys
                                end
                                self.railIndex = targetSlot
                                if f.RefreshLeftRailLayout then
                                    f.RefreshLeftRailLayout()
                                end
                            end
                        end
                    end
                end)
            end)

            card:SetScript("OnDragStop", function(self)
                leftRail:SetScript("OnUpdate", nil)
                if railDragGhost then railDragGhost:Hide() end
                if self._isDragging then
                    self._isDragging = false
                    if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
                        pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION)
                    end
                end
                if f.RefreshLeftRailLayout then
                    f.RefreshLeftRailLayout()
                end
                if self.UpdateNudgeVisibility then
                    self.UpdateNudgeVisibility()
                end
            end)
            card:SetScript("OnHide", function(self)
                if self._isDragging then
                    self._isDragging = false
                    leftRail:SetScript("OnUpdate", nil)
                    if railDragGhost then railDragGhost:Hide() end
                    self:SetAlpha(1.0)
                end
            end)
            leftRail:SetScript("OnHide", function(self)
                self:SetScript("OnUpdate", nil)
                if railDragGhost then railDragGhost:Hide() end
            end)
        end

        pillSwitch:SetScript("OnClick", function()
            if addonKey == "DynamicLoad" then
                selectedPeerModuleKey = nil
                addonTable.OpenWorkspaceView("DYNAMICLOAD")
                return
            end
            local hasAddon = C_AddOns.GetAddOnInfo(addonKey) ~= nil
            local regMod = (DynamicSuite and DynamicSuite.modules and (DynamicSuite.modules[addonKey] or DynamicSuite.modules[shortKey] or DynamicSuite.modules[modInfo.key])) or _G[addonKey]
            local isInstalled = hasAddon or (regMod ~= nil)
            if isInstalled then
                local cur = hasAddon and (C_AddOns.GetAddOnEnableState(addonKey, pName) or 0) or 2
                local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
                gTbl.disabledModules = gTbl.disabledModules or {}
                local isExplicitDis = (addonTable.IsSuiteModuleExplicitlyDisabled and addonTable.IsSuiteModuleExplicitlyDisabled(addonKey))
                    or gTbl.disabledModules[addonKey] or gTbl.disabledModules[shortKey]
                    or (_G.DynamicSuiteDB and _G.DynamicSuiteDB.disabledModules and (_G.DynamicSuiteDB.disabledModules[addonKey] or _G.DynamicSuiteDB.disabledModules[shortKey]))
                local isCurrentlyOn = (not isExplicitDis) and ((regMod ~= nil) or cur > 0)
                if isCurrentlyOn then
                    if hasAddon and addonKey ~= "DynamicSuite" then
                        C_AddOns.DisableAddOn(addonKey, pName)
                        C_AddOns.DisableAddOn(addonKey)
                    end
                    gTbl.disabledModules[addonKey] = true
                    if shortKey and shortKey ~= "" then
                        gTbl.disabledModules[shortKey] = true
                    end
                    if _G.DynamicSuiteDB then
                        _G.DynamicSuiteDB.disabledModules = _G.DynamicSuiteDB.disabledModules or {}
                        _G.DynamicSuiteDB.disabledModules[addonKey] = true
                        if shortKey and shortKey ~= "" then
                            _G.DynamicSuiteDB.disabledModules[shortKey] = true
                        end
                    end
                    if regMod and type(regMod.OnDisableInSuite) == "function" then
                        pcall(regMod.OnDisableInSuite, regMod)
                    end
                    if addonKey == "DynamicChat" and _G.DynamicChat and type(_G.DynamicChat.TeardownDisabledState) == "function" then
                        pcall(_G.DynamicChat.TeardownDisabledState, _G.DynamicChat, true)
                    end
                    if addonKey == "DynamicMail" and _G.DynamicMail and type(_G.DynamicMail.TeardownDisabledState) == "function" then
                        pcall(_G.DynamicMail.TeardownDisabledState, _G.DynamicMail)
                    end
                    addonTable._pendingSuiteModuleReload = true
                    if selectedPeerModuleKey == addonKey and activeWorkspaceView == "PEER_HOST" then
                        addonTable.OpenWorkspaceView("PEER_MODULE")
                    end
                else
                    if hasAddon and addonKey ~= "DynamicSuite" and addonKey ~= "DynamicMarker" then
                        C_AddOns.EnableAddOn(addonKey, pName)
                        C_AddOns.EnableAddOn(addonKey)
                    end
                    if gTbl.disabledModules then
                        gTbl.disabledModules[addonKey] = nil
                        gTbl.disabledModules[shortKey] = nil
                    end
                    if _G.DynamicSuiteDB and _G.DynamicSuiteDB.disabledModules then
                        _G.DynamicSuiteDB.disabledModules[addonKey] = nil
                        _G.DynamicSuiteDB.disabledModules[shortKey] = nil
                    end
                    if regMod and type(regMod.OnEnableInSuite) == "function" then
                        pcall(regMod.OnEnableInSuite, regMod)
                    end
                    addonTable._pendingSuiteModuleReload = true
                    if regMod and regMod._disabledAtStartup then
                        if DynamicSuite and DynamicSuite.Print then
                            DynamicSuite.Print(string.format("%s enabled. Type /reload to finish activating it.", modInfo.title or addonKey))
                        end
                    end
                    if selectedPeerModuleKey == addonKey and activeWorkspaceView == "PEER_MODULE" then
                        if regMod and (not regMod._disabledAtStartup) and type(regMod.RenderEmbedded or regMod.Render or regMod.BuildUI or regMod.BuildConfigUI) == "function" then
                            card:GetScript("OnClick")(card, "LeftButton")
                            return
                        end
                    end
                end
                if f.RefreshLeftRailVisuals then f.RefreshLeftRailVisuals() end
                if f.scrollChild then RefreshAddonTree(f.scrollChild) end
                if UpdateStatusBar then UpdateStatusBar() end
                if f.peerView and f.peerView:IsShown() and f.peerView.Refresh then f.peerView.Refresh() end
            else
                selectedPeerModuleKey = addonKey
                addonTable.OpenWorkspaceView("PEER_MODULE")
            end
        end)

        -- Bottom line: Left-aligned subtitle + Right-aligned slash command (without parentheses)
        local mSlash = card:CreateFontString(nil, "OVERLAY")
        mSlash:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -8, 4)
        UI.SetFont(mSlash, 9, "", 0.48, 0.53, 0.60, 0.90)
        mSlash:SetText(modInfo.slash)
        card.mSlash = mSlash

        local mSub = card:CreateFontString(nil, "OVERLAY")
        mSub:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 28, 4)
        mSub:SetPoint("RIGHT", mSlash, "LEFT", -6, 0)
        mSub:SetJustifyH("LEFT")
        mSub:SetWordWrap(false)
        UI.SetFont(mSub, 9, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 0.85)
        mSub:SetText(modInfo.subtitle or modInfo.desc)
        card.mSub = mSub

        card:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                if not railSwapArmedKey then
                    railSwapArmedKey = shortKey
                elseif railSwapArmedKey == shortKey or railSwapArmedKey == addonKey then
                    railSwapArmedKey = nil
                else
                    UI.SwapRailModules(railSwapArmedKey, shortKey)
                    railSwapArmedKey = nil
                end
                if RefreshLeftRailVisuals then RefreshLeftRailVisuals() end
                return
            end

            if railSwapArmedKey then
                if railSwapArmedKey ~= shortKey and railSwapArmedKey ~= addonKey then
                    UI.SwapRailModules(railSwapArmedKey, shortKey)
                    railSwapArmedKey = nil
                    if RefreshLeftRailVisuals then RefreshLeftRailVisuals() end
                    return
                else
                    railSwapArmedKey = nil
                    if RefreshLeftRailVisuals then RefreshLeftRailVisuals() end
                    return
                end
            end

            if UI.CloseAllPopups then UI.CloseAllPopups() end
            for _, stName in ipairs(STANDALONE_FRAME_NAMES or {}) do
                local stFrame = _G[stName]
                if stFrame and stFrame.IsShown and stFrame:IsShown() and stFrame.Hide then
                    stFrame:Hide()
                end
            end
            if addonKey == "DynamicLoad" then
                selectedPeerModuleKey = nil
                f.lastModuleView = "DYNAMICLOAD"
                f.lastPeerModuleKey = nil
                f.lastModuleTitle = "DynamicLoad"
                addonTable.OpenWorkspaceView("DYNAMICLOAD")
            else
                f.lastPeerModuleKey = addonKey
                f.lastModuleTitle = modInfo.title or addonKey
                local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
                local isExplicitDis = (addonTable.IsSuiteModuleExplicitlyDisabled and addonTable.IsSuiteModuleExplicitlyDisabled(addonKey))
                    or (gTbl.disabledModules and (gTbl.disabledModules[addonKey] or gTbl.disabledModules[shortKey]))
                    or (_G.DynamicSuiteDB and _G.DynamicSuiteDB.disabledModules and (_G.DynamicSuiteDB.disabledModules[addonKey] or _G.DynamicSuiteDB.disabledModules[shortKey]))
                if not isExplicitDis and addonKey ~= "DynamicSuite" and addonKey ~= "DynamicMarker" and C_AddOns.GetAddOnInfo(addonKey) then
                    C_AddOns.EnableAddOn(addonKey, pName)
                    C_AddOns.EnableAddOn(addonKey)
                    if gTbl.disabledModules then
                        gTbl.disabledModules[addonKey] = nil
                        gTbl.disabledModules[shortKey] = nil
                    end
                    if _G.DynamicSuiteDB and _G.DynamicSuiteDB.disabledModules then
                        _G.DynamicSuiteDB.disabledModules[addonKey] = nil
                        _G.DynamicSuiteDB.disabledModules[shortKey] = nil
                    end
                end
                local regMod = (DynamicSuite and DynamicSuite.modules and (DynamicSuite.modules[addonKey] or DynamicSuite.modules[shortKey] or DynamicSuite.modules[modInfo.key])) or _G[addonKey]
                if (not isExplicitDis) and (not (regMod and regMod._disabledAtStartup)) and (regMod or C_AddOns.IsAddOnLoaded(addonKey)) and regMod then
                    local renderFn = regMod.RenderEmbedded or regMod.Render or regMod.BuildUI or regMod.BuildConfigUI
                    if type(renderFn) == "function" then
                        selectedPeerModuleKey = addonKey
                        activeWorkspaceView = "PEER_HOST"
                        f.lastModuleView = "PEER_HOST"
                        if f.dlView then f.dlView:Hide() end
                        if f.peerView then f.peerView:Hide() end
                        if f.themeView then f.themeView:Hide() end
                        if f.setupView then f.setupView:Hide() end
                        if f.editView then f.editView:Hide() end
                        if f.changelogView then f.changelogView:Hide() end
                        if f.supportView then f.supportView:Hide() end
                        if f.searchView then f.searchView:Hide() end
                        if f.railSearchBox and f.railSearchBox:HasFocus() then f.railSearchBox:ClearFocus() end
                        if addonTable.SetToastEditMode then addonTable.SetToastEditMode(false) end

                        if f.SyncWorkspaceGeometry then f.SyncWorkspaceGeometry() end
                        local hostParent = f.workspace or f
                        if hostParent and hostParent.Show then hostParent:Show() end
                        if not f.peerModuleHostFrame then
                            local host = CreateFrame("Frame", "DynamicSuitePeerHostFrame", hostParent)
                            host:SetPoint("TOPLEFT", hostParent, "TOPLEFT", 0, 0)
                            host:SetPoint("BOTTOMRIGHT", hostParent, "BOTTOMRIGHT", 0, 0)
                            host:SetFrameLevel((hostParent:GetFrameLevel() or 6) + 2)
                            if host.SetClipsChildren then host:SetClipsChildren(false) end
                            f.peerModuleHostFrame = host
                            f.peerContainer = host
                        end
                        local host = f.peerModuleHostFrame
                        host:SetFrameLevel((hostParent:GetFrameLevel() or 6) + 2)
                        if host.SetClipsChildren then host:SetClipsChildren(false) end
                        if (host:GetWidth() or 0) <= 0 or (host:GetHeight() or 0) <= 0 then
                            local hw = (hostParent:GetWidth() or 0) > 0 and hostParent:GetWidth() or ((f:GetWidth() or PANEL_W) - RAIL_W - 2)
                            local hh = (hostParent:GetHeight() or 0) > 0 and hostParent:GetHeight() or ((f:GetHeight() or PANEL_H) - HDR_H - DOCK_H)
                            host:SetSize(math.max(500, hw), math.max(300, hh))
                        end
                        host.moduleContainers = host.moduleContainers or {}
                        local modHost = host.moduleContainers[addonKey]
                        if not modHost then
                            if addonKey ~= "DynamicSuite" and addonKey ~= "DynamicMarker" and C_AddOns.GetAddOnInfo(addonKey) then
                                C_AddOns.EnableAddOn(addonKey, pName)
                                C_AddOns.EnableAddOn(addonKey)
                            end
                            if gTbl.disabledModules then
                                gTbl.disabledModules[addonKey] = nil
                                gTbl.disabledModules[shortKey] = nil
                            end
                            if _G.DynamicSuiteDB and _G.DynamicSuiteDB.disabledModules then
                                _G.DynamicSuiteDB.disabledModules[addonKey] = nil
                                _G.DynamicSuiteDB.disabledModules[shortKey] = nil
                            end
                            modHost = CreateFrame("Frame", nil, host)
                            modHost:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
                            modHost:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
                            modHost:SetFrameLevel((host:GetFrameLevel() or 8) + 1)
                            if modHost.SetClipsChildren then modHost:SetClipsChildren(false) end
                            host.moduleContainers[addonKey] = modHost
                        end
                        modHost:SetFrameLevel((host:GetFrameLevel() or 8) + 1)
                        if modHost.SetClipsChildren then modHost:SetClipsChildren(false) end
                        if (modHost:GetWidth() or 0) <= 0 or (modHost:GetHeight() or 0) <= 0 then
                            local hw = (host:GetWidth() or 0) > 0 and host:GetWidth() or ((f:GetWidth() or PANEL_W) - RAIL_W - 2)
                            local hh = (host:GetHeight() or 0) > 0 and host:GetHeight() or ((f:GetHeight() or PANEL_H) - HDR_H - DOCK_H)
                            modHost:SetSize(math.max(500, hw), math.max(300, hh))
                        end
                        if host._activeModHost and host._activeModHost ~= modHost then
                            host._activeModHost:Hide()
                        end
                        host:Show()
                        modHost:Show()
                        host._activeModHost = modHost

                        if f.verPill and f.verPill.label then
                            local mVer = (regMod and regMod.version) or addonTable.ADDON_VERSION or "2.2.0"
                            f.verPill.label:SetText("v" .. tostring(mVer))
                        end
                        UpdateStatusBar(true)
                        if f.dockHint then
                            f.dockHint:SetText(string.format("Active Module: %s   |cFF475569|||r   Slash: %s", modInfo.title or addonKey, modInfo.slash or "/ds"))
                        end
                        if f.UpdateModuleConflictBanner then
                            f.UpdateModuleConflictBanner(addonKey)
                        end

                        if regMod.RenderEmbedded then
                            pcall(regMod.RenderEmbedded, regMod, modHost)
                        else
                            pcall(renderFn, modHost)
                        end
                        if not modHost._dsSubDrawersNormalized and UI.NormalizeEmbeddedSubDrawers then
                            modHost._dsSubDrawersNormalized = true
                            UI.NormalizeEmbeddedSubDrawers(modHost)
                        end
                        if f.RefreshLeftRailVisuals then f.RefreshLeftRailVisuals() end
                    else
                        selectedPeerModuleKey = addonKey
                        f.lastModuleView = "PEER_MODULE"
                        addonTable.OpenWorkspaceView("PEER_MODULE")
                    end
                else
                    selectedPeerModuleKey = addonKey
                    f.lastModuleView = "PEER_MODULE"
                    addonTable.OpenWorkspaceView("PEER_MODULE")
                end
            end
        end)

        table.insert(railModuleCards, card)
        return card
    end

    for idx, modInfo in ipairs(UI.GetOrderedModuleList()) do
        CreateRailModuleCard(idx, modInfo)
    end

    local function RefreshLeftRailLayout()
        if leftRail then leftRail:Show() end
        if railModuleScroll then railModuleScroll:Show() end
        if railModuleChild then railModuleChild:Show() end
        if f.railSearchWrap then f.railSearchWrap:Show() end
        if f.modSectionHdr then f.modSectionHdr:Show() end
        if f.resetSortBtn then f.resetSortBtn:Show() end
        if f.studioSectionHdr then f.studioSectionHdr:Show() end
        if f.railStudioBtns then
            for _, sBtn in ipairs(f.railStudioBtns) do
                if sBtn and sBtn.Show then sBtn:Show() end
            end
        end

        local ordered = UI.GetOrderedModuleList()
        local isCustom = UI.IsUsingCustomRailOrder and UI.IsUsingCustomRailOrder()
        wipe(railModuleCards)

        for _, hdr in pairs(railCategoryHeaders) do
            if hdr and hdr.Hide then hdr:Hide() end
        end

        local curY = 0
        if not isCustom and type(addonTable.SUITE_RAIL_CATEGORIES) == "table" and #addonTable.SUITE_RAIL_CATEGORIES > 0 then
            local modByKey = {}
            for _, modInfo in ipairs(ordered) do
                local aKey = modInfo.addonName or modInfo.name or modInfo.key
                local sKey = modInfo.id or modInfo.key or tostring(aKey):gsub("^Dynamic", ""):lower()
                if sKey then modByKey[sKey] = modInfo end
                if aKey then modByKey[aKey] = modInfo end
                if modInfo.key then modByKey[modInfo.key] = modInfo end
            end

            local placed = {}
            local cardIdx = 0
            for catIdx, catDef in ipairs(addonTable.SUITE_RAIL_CATEGORIES) do
                local catMods = {}
                for _, mKey in ipairs(catDef.modules or {}) do
                    local mInfo = modByKey[mKey]
                    if mInfo and not placed[mInfo] then
                        placed[mInfo] = true
                        table.insert(catMods, mInfo)
                    end
                end
                if #catMods > 0 then
                    if catIdx > 1 then
                        curY = curY + 4
                    end
                    local hdr = GetOrCreateRailCategoryHeader(catDef.key, catDef.label)
                    hdr:ClearAllPoints()
                    hdr:SetPoint("TOPLEFT", railModuleChild, "TOPLEFT", 10, -curY)
                    hdr:Show()
                    curY = curY + 17

                    for _, modInfo in ipairs(catMods) do
                        cardIdx = cardIdx + 1
                        local aKey = modInfo.addonName or modInfo.name or modInfo.key
                        local sKey = modInfo.id or modInfo.key or tostring(aKey):gsub("^Dynamic", ""):lower()
                        local card = railModuleCardsByKey[sKey] or railModuleCardsByKey[aKey] or (modInfo.key and railModuleCardsByKey[modInfo.key])
                        if not card then
                            card = CreateRailModuleCard(cardIdx, modInfo)
                        end
                        if card then
                            card.modInfo = modInfo
                            if card.modIcon then
                                card.modIcon:SetTexture(UI.GetModuleIconPath(aKey, modInfo.icon))
                            end
                            card:ClearAllPoints()
                            card:SetPoint("TOPLEFT", railModuleChild, "TOPLEFT", 10, -curY)
                            card.railIndex = cardIdx
                            card._railY = curY
                            card:Show()
                            if card.UpdateNudgeVisibility then
                                card.UpdateNudgeVisibility()
                            end
                            table.insert(railModuleCards, card)
                            curY = curY + 38
                        end
                    end
                end
            end

            -- Append any extra/third-party registered modules not in the 4 core categories
            for _, modInfo in ipairs(ordered) do
                if not placed[modInfo] then
                    cardIdx = cardIdx + 1
                    local aKey = modInfo.addonName or modInfo.name or modInfo.key
                    local sKey = modInfo.id or modInfo.key or tostring(aKey):gsub("^Dynamic", ""):lower()
                    local card = railModuleCardsByKey[sKey] or railModuleCardsByKey[aKey] or (modInfo.key and railModuleCardsByKey[modInfo.key])
                    if not card then
                        card = CreateRailModuleCard(cardIdx, modInfo)
                    end
                    if card then
                        card.modInfo = modInfo
                        if card.modIcon then
                            card.modIcon:SetTexture(UI.GetModuleIconPath(aKey, modInfo.icon))
                        end
                        card:ClearAllPoints()
                        card:SetPoint("TOPLEFT", railModuleChild, "TOPLEFT", 10, -curY)
                        card.railIndex = cardIdx
                        card._railY = curY
                        card:Show()
                        if card.UpdateNudgeVisibility then
                            card.UpdateNudgeVisibility()
                        end
                        table.insert(railModuleCards, card)
                        curY = curY + 38
                    end
                end
            end
        else
            for idx, modInfo in ipairs(ordered) do
                local aKey = modInfo.addonName or modInfo.name or modInfo.key
                local sKey = modInfo.id or modInfo.key or tostring(aKey):gsub("^Dynamic", ""):lower()
                local card = railModuleCardsByKey[sKey] or railModuleCardsByKey[aKey] or (modInfo.key and railModuleCardsByKey[modInfo.key])
                if not card then
                    card = CreateRailModuleCard(idx, modInfo)
                end
                if card then
                    card.modInfo = modInfo
                    if card.modIcon then
                        card.modIcon:SetTexture(UI.GetModuleIconPath(aKey, modInfo.icon))
                    end
                    card:ClearAllPoints()
                    card:SetPoint("TOPLEFT", railModuleChild, "TOPLEFT", 10, -curY)
                    card.railIndex = idx
                    card._railY = curY
                    card:Show()
                    if card.UpdateNudgeVisibility then
                        card.UpdateNudgeVisibility()
                    end
                    table.insert(railModuleCards, card)
                    curY = curY + 38
                end
            end
        end

        railModuleChild:SetHeight(math.max(1, curY + 4))
        UpdateRailScrollBar()
        if RefreshLeftRailVisuals then
            RefreshLeftRailVisuals()
        end
    end
    f.RefreshLeftRailLayout = RefreshLeftRailLayout
    mainFrame.RefreshLeftRailLayout = RefreshLeftRailLayout
    RefreshLeftRailLayout()

    -- Bottom Section of Left Suite Rail: SUITE STUDIO & TOOLS (Compact 31px Neutral Obsidian Cards)
    local studioSectionHdr = leftRail:CreateFontString(nil, "OVERLAY")
    studioSectionHdr:SetPoint("BOTTOMLEFT", leftRail, "BOTTOMLEFT", 14, 138)
    UI.SetFont(studioSectionHdr, 10, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 0.90)
    studioSectionHdr:SetText("SUITE STUDIO & TOOLS")
    studioSectionHdr:Show()
    f.studioSectionHdr = studioSectionHdr

    local studioItems = {
        {
            key = "EDIT_MODE",
            label = "Edit Mode (HUDs)",
            sub = "Move & Scale Suite Bars",
            slash = "/ds hud",
            icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_grid.tga",
            yBottom = 102,
        },
        {
            key = "THEME_STUDIO",
            label = "Suite Studio",
            sub = "Theme, Fonts & Windows",
            slash = "/ds studio",
            icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_palette.tga",
            yBottom = 68,
        },
        {
            key = "GUIDED_SETUP",
            label = "Guided Setup",
            sub = "60s Setup & Conflict Check",
            icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_spark.tga",
            yBottom = 34,
            hasConflictBadge = true,
        },
    }

    for _, sItem in ipairs(studioItems) do
        local sBtn = CreateFrame("Button", nil, leftRail)
        sBtn:SetSize(RAIL_W - 20, 31)
        sBtn:SetPoint("BOTTOMLEFT", leftRail, "BOTTOMLEFT", 10, sItem.yBottom)
        sBtn.viewKey = sItem.key

        sBtn.bg = UI.SolidTex(sBtn, "BACKGROUND", 2, 0.078, 0.090, 0.122, 0.94)
        sBtn.bg:SetAllPoints()
        UI.CreatePixelBorder(sBtn, 0.141, 0.161, 0.212, 0.95, 3)

        local iconTex = sBtn:CreateTexture(nil, "ARTWORK", nil, 3)
        iconTex:SetSize(14, 14)
        iconTex:SetPoint("LEFT", sBtn, "LEFT", 8, 0)
        iconTex:SetTexture(sItem.icon)
        iconTex:SetVertexColor(0.72, 0.76, 0.84, 0.95)
        sBtn.iconTex = iconTex

        local sSlash = nil
        if sItem.slash then
            sSlash = sBtn:CreateFontString(nil, "OVERLAY")
            sSlash:SetPoint("TOPRIGHT", sBtn, "TOPRIGHT", -6, -5)
            UI.SetFont(sSlash, 9, "", 0.48, 0.53, 0.60, 0.90)
            sSlash:SetText(sItem.slash)
        end

        local sTitle = sBtn:CreateFontString(nil, "OVERLAY")
        sTitle:SetPoint("TOPLEFT", sBtn, "TOPLEFT", 26, -4)
        if sSlash then
            sTitle:SetPoint("RIGHT", sSlash, "LEFT", -4, 0)
        else
            sTitle:SetPoint("RIGHT", sBtn, "RIGHT", sItem.hasConflictBadge and -48 or -8, 0)
        end
        sTitle:SetJustifyH("LEFT")
        sTitle:SetWordWrap(false)
        UI.SetFont(sTitle, 11, "", 0.95, 0.97, 1.0, 1)
        sTitle:SetText(sItem.label)
        sBtn.label = sTitle

        local sSub = sBtn:CreateFontString(nil, "OVERLAY")
        sSub:SetPoint("BOTTOMLEFT", sBtn, "BOTTOMLEFT", 26, 3)
        sSub:SetPoint("RIGHT", sBtn, "RIGHT", -6, 0)
        sSub:SetJustifyH("LEFT")
        sSub:SetWordWrap(false)
        UI.SetFont(sSub, 9, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 0.88)
        sSub:SetText(sItem.sub)
        sBtn.subLabel = sSub

        if sItem.hasConflictBadge then
            -- Subtle 6x6 emerald status pip (#22C55E) when 0 conflicts exist
            local okPip = UI.SolidTex(sBtn, "OVERLAY", 5, 0.133, 0.773, 0.369, 1.0)
            okPip:SetSize(6, 6)
            okPip:SetPoint("TOPRIGHT", sBtn, "TOPRIGHT", -10, -7)
            sBtn.okPip = okPip

            local badgePill = CreateFrame("Frame", nil, sBtn)
            badgePill:SetSize(34, 14)
            badgePill:SetPoint("TOPRIGHT", sBtn, "TOPRIGHT", -8, -4)
            badgePill.bg = UI.SolidTex(badgePill, "BACKGROUND", 3, UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.20)
            badgePill.bg:SetAllPoints()
            UI.CreatePixelBorder(badgePill, UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.75, 4)
            badgePill:Hide()

            local cBadge = badgePill:CreateFontString(nil, "OVERLAY")
            cBadge:SetPoint("CENTER", badgePill, "CENTER", 0, 0)
            UI.SetFont(cBadge, 9, "", UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1)
            cBadge:SetText("! 1")
            sBtn.conflictBadge = cBadge
            sBtn.conflictPill = badgePill
            f.guidedSetupRailBtn = sBtn
        end

        sBtn:SetScript("OnClick", function()
            if UI.CloseAllPopups then UI.CloseAllPopups() end
            if sItem.key == "EDIT_MODE" and addonTable.EnterHudEditMode then
                addonTable.EnterHudEditMode("ALL")
            else
                addonTable.OpenWorkspaceView(sItem.key)
            end
        end)
        table.insert(railStudioBtns, sBtn)
    end

    -- Bottom Utility Row in Left Rail: [Changelog] + [Support]
    local function GetSuiteChangelogSignature()
        local parts = { tostring(addonTable.ADDON_VERSION or "1.3.0") }
        local clReg = _G.DynamicSuite and _G.DynamicSuite.Changelogs
        if type(clReg) == "table" then
            for _, k in ipairs({ "DynamicLoad", "DynamicMarker", "DynamicZoom", "DynamicFPS", "DynamicPrep", "DynamicGroup", "DynamicBags", "DynamicChat", "DynamicMail", "DynamicVault", "DynamicDialogue" }) do
                local c = clReg[k]
                if type(c) == "table" then
                    local entries = c.entries or {}
                    local firstTxt = (entries[1] and (entries[1].text or entries[1].title)) or ""
                    parts[#parts + 1] = string.format("%s:%s:%s:%d:%s", k, tostring(c.version or ""), tostring(c.date or ""), #entries, tostring(firstTxt):sub(1, 32))
                end
            end
        end
        if f and type(f.dsChangelogModules) == "table" then
            for _, m in ipairs(f.dsChangelogModules) do
                local items = m.items or {}
                local firstTitle = (items[1] and items[1].title) or ""
                parts[#parts + 1] = string.format("%s:%s:%s:%d:%s", tostring(m.key or ""), tostring(m.ver or ""), tostring(m.date or ""), #items, tostring(firstTitle):sub(1, 32))
            end
        end
        return table.concat(parts, "|")
    end
    f.GetSuiteChangelogSignature = GetSuiteChangelogSignature

    local railChangelogBtn = CreateFlatButton(leftRail, 90, 22, "Changelog", false)
    railChangelogBtn:SetPoint("BOTTOMLEFT", leftRail, "BOTTOMLEFT", 10, 7)
    railChangelogBtn.viewKey = "CHANGELOG_VIEW"
    local clIcon = railChangelogBtn:CreateTexture(nil, "OVERLAY", nil, 3)
    clIcon:SetSize(12, 12)
    clIcon:SetPoint("LEFT", railChangelogBtn, "LEFT", 6, 0)
    clIcon:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_changelog.tga")
    clIcon:SetVertexColor(0.72, 0.76, 0.84, 0.95)
    railChangelogBtn.iconTex = clIcon

    f.railChangelogBtn = railChangelogBtn
    railChangelogBtn.OnCustomEnter = function(self)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local curVer = addonTable.ADDON_VERSION or "1.3.0"
        local curSig = GetSuiteChangelogSignature()
        local seenSig = gTbl.lastSeenChangelogSig or (DynamicLoadDB and DynamicLoadDB.lastSeenChangelogSig)
        local seenVer = gTbl.lastSeenChangelogVer or (DynamicLoadDB and DynamicLoadDB.lastSeenChangelogVer)
        if seenSig ~= curSig or seenVer ~= curVer then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("New Update Installed (v" .. curVer .. ")", UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b)
            GameTooltip:AddLine("Click to view the latest release notes and clear this notification.", 0.90, 0.92, 0.96, true)
            GameTooltip:Show()
        end
    end
    railChangelogBtn.OnCustomLeave = function()
        GameTooltip:Hide()
    end

    railChangelogBtn.label:ClearAllPoints()
    railChangelogBtn.label:SetPoint("LEFT", clIcon, "RIGHT", 4, 0)
    railChangelogBtn.label:SetPoint("RIGHT", railChangelogBtn, "RIGHT", -3, 0)
    railChangelogBtn.label:SetJustifyH("CENTER")
    railChangelogBtn:SetScript("OnClick", function()
        if UI.CloseAllPopups then UI.CloseAllPopups() end
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        local curVer = addonTable.ADDON_VERSION or "1.3.0"
        local curSig = GetSuiteChangelogSignature()
        if gTbl then
            gTbl.lastSeenChangelogVer = curVer
            gTbl.lastSeenChangelogSig = curSig
        end
        if DynamicLoadDB then
            DynamicLoadDB.lastSeenChangelogVer = curVer
            DynamicLoadDB.lastSeenChangelogSig = curSig
        end
        addonTable.OpenWorkspaceView("CHANGELOG_VIEW")
    end)
    table.insert(railStudioBtns, railChangelogBtn)

    local railSupportBtn = CreateFlatButton(leftRail, 88, 22, "Support", false)
    railSupportBtn:SetPoint("BOTTOMRIGHT", leftRail, "BOTTOMRIGHT", -10, 7)
    railSupportBtn.viewKey = "SUPPORT_VIEW"
    local supIcon = railSupportBtn:CreateTexture(nil, "OVERLAY", nil, 3)
    supIcon:SetSize(12, 12)
    supIcon:SetPoint("LEFT", railSupportBtn, "LEFT", 10, 0)
    supIcon:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_support.tga")
    supIcon:SetVertexColor(0.72, 0.76, 0.84, 0.95)
    railSupportBtn.iconTex = supIcon
    railSupportBtn.label:ClearAllPoints()
    railSupportBtn.label:SetPoint("LEFT", supIcon, "RIGHT", 4, 0)
    railSupportBtn.label:SetPoint("RIGHT", railSupportBtn, "RIGHT", -4, 0)
    railSupportBtn.label:SetJustifyH("CENTER")
    railSupportBtn:SetScript("OnClick", function()
        if UI.CloseAllPopups then UI.CloseAllPopups() end
        addonTable.OpenWorkspaceView("SUPPORT_VIEW")
    end)
    table.insert(railStudioBtns, railSupportBtn)
    f.railStudioBtns = railStudioBtns
    f.studioItems = railStudioBtns
    for _, sBtn in ipairs(railStudioBtns) do
        if sBtn and sBtn.Show then sBtn:Show() end
    end

    RefreshLeftRailVisuals = function()
        UI.RefreshPaletteCache()
        local ar, ag, ab = UI.GetActiveAccentColor()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}

        if f.headerTitle then
            f.headerTitle:SetText(UI.FormatTwoToneBrand("Suite"))
        end

        if f.railCategoryHeaders then
            for _, hdr in pairs(f.railCategoryHeaders) do
                if hdr and hdr.tick then
                    hdr.tick:SetColorTexture(ar, ag, ab, 0.85)
                end
            end
        end
        if f.UpdateRailScrollBar then
            f.UpdateRailScrollBar()
        end

        for _, card in ipairs(railModuleCards) do
            local mKey = card.modInfo.addonName or card.modInfo.name or card.modInfo.key
            local shortKey = card.modInfo.id or tostring(mKey):gsub("^Dynamic", ""):lower()
            local isSel = (activeWorkspaceView == "DYNAMICLOAD" and mKey == "DynamicLoad")
                       or ((activeWorkspaceView == "PEER_MODULE" or activeWorkspaceView == "PEER_HOST") and (selectedPeerModuleKey == mKey or selectedPeerModuleKey == card.modInfo.key or selectedPeerModuleKey == card.modInfo.id))
            local isDisabledBySuite = (addonTable.IsSuiteModuleExplicitlyDisabled and addonTable.IsSuiteModuleExplicitlyDisabled(mKey))
                       or (gTbl.disabledModules and (gTbl.disabledModules[mKey] or gTbl.disabledModules[card.modInfo.key]))
                       or (_G.DynamicSuiteDB and _G.DynamicSuiteDB.disabledModules and (_G.DynamicSuiteDB.disabledModules[mKey] or _G.DynamicSuiteDB.disabledModules[card.modInfo.key]))
            local regMod = (DynamicSuite and DynamicSuite.modules and (DynamicSuite.modules[mKey] or DynamicSuite.modules[shortKey] or DynamicSuite.modules[card.modInfo.key])) or _G[mKey]
            local isLoaded = (regMod ~= nil)
                          or (mKey == "DynamicLoad" and (addonTable.IsDynamicLoadModuleLoaded == true or C_AddOns.IsAddOnLoaded("DynamicLoad")))
                          or (mKey ~= "DynamicLoad" and C_AddOns.IsAddOnLoaded(mKey))
            local enableState = 0
            if not isLoaded then
                if card._cachedEnableState == nil then
                    card._cachedEnableState = C_AddOns.GetAddOnInfo(mKey) and (C_AddOns.GetAddOnEnableState(mKey, pName) or 0) or 0
                end
                enableState = card._cachedEnableState
            else
                enableState = 1
            end
            local isSwitchOn = (not isDisabledBySuite) and (isLoaded or enableState > 0)
            local isArmed = (railSwapArmedKey ~= nil and (railSwapArmedKey == shortKey or railSwapArmedKey == mKey or railSwapArmedKey == card.modInfo.key or railSwapArmedKey == card.modInfo.id))

            if isArmed then
                card.mTitle:SetText(string.format("|cFFFBBF24>> Swap: %s <<|r", card.modInfo.title or mKey))
                card.bg:SetColorTexture(0.98, 0.75, 0.14, 0.18)
                card.dsBorder:SetColor(0.98, 0.75, 0.14, 1.0)
            else
                local baseTitle = UI.FormatTwoToneBrand(card.modInfo.title or mKey)
                card.mTitle:SetText(isSwitchOn and baseTitle or (baseTitle .. "  |cFF64748B[Off]|r"))
                if isSel then
                    card.bg:SetColorTexture(ar, ag, ab, 0.16)
                    card.dsBorder:SetColor(ar, ag, ab, 0.88)
                else
                    card.bg:SetColorTexture(0.078, 0.090, 0.122, 0.85)
                    card.dsBorder:SetColor(0.141, 0.161, 0.212, 0.85)
                end
            end
            card:SetAlpha(card._isDragging and 0.30 or ((isSwitchOn or isSel or isArmed) and 1.0 or 0.45))
            if card.modIcon then
                card.modIcon:SetTexture(UI.GetModuleIconPath(mKey, card.modInfo and card.modInfo.icon))
                if isArmed then
                    card.modIcon:SetVertexColor(0.98, 0.75, 0.14, 1.0)
                elseif isSel then
                    card.modIcon:SetVertexColor(ar, ag, ab, 1.0)
                else
                    card.modIcon:SetVertexColor(0.72, 0.76, 0.84, 0.95)
                end
            end

            if card.pillSwitch and card.pillThumb then
                card.pillThumb:ClearAllPoints()
                if isSwitchOn then
                    card.pillSwitch.bg:SetColorTexture(ar, ag, ab, isSel and 0.82 or 0.62)
                    card.pillSwitch.dsBorder:SetColor(ar, ag, ab, 0.95)
                    card.pillThumb:SetColorTexture(1, 1, 1, 0.98)
                    card.pillThumb:SetPoint("RIGHT", card.pillSwitch, "RIGHT", -2, 0)
                else
                    card.pillSwitch.bg:SetColorTexture(0.078, 0.090, 0.118, 1.0)
                    card.pillSwitch.dsBorder:SetColor(1, 1, 1, 0.14)
                    card.pillThumb:SetColorTexture(0.45, 0.50, 0.58, 0.85)
                    card.pillThumb:SetPoint("LEFT", card.pillSwitch, "LEFT", 2, 0)
                end
            end

            card.leftBar:SetColorTexture(ar, ag, ab, 1)
            card.leftBar:SetShown(isSel)

            if card.conflictPip then
                local hasUnackHard, hasUnackSoft = false, false
                if addonTable.GetCachedModuleConflictFlags then
                    hasUnackHard, hasUnackSoft = addonTable.GetCachedModuleConflictFlags(mKey)
                elseif addonTable.GetModuleConflicts then
                    local _, modHard, modSoft = addonTable.GetModuleConflicts(mKey)
                    for _, hc in ipairs(modHard) do
                        if not hc.isAcknowledged then hasUnackHard = true; break end
                    end
                    for _, sc in ipairs(modSoft) do
                        if not sc.isAcknowledged then hasUnackSoft = true; break end
                    end
                end
                if hasUnackHard then
                    card.conflictPip:SetColorTexture(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1.0)
                    card.conflictPip:Show()
                elseif hasUnackSoft then
                    card.conflictPip:SetColorTexture(0.220, 0.741, 0.973, 0.95)
                    card.conflictPip:Show()
                else
                    card.conflictPip:Hide()
                end
            end
        end

        local totalUnresolved, tier1Unresolved, tier2Unresolved = 0, 0, 0
        if addonTable.GetUnresolvedConflictCount then
            totalUnresolved, tier1Unresolved, tier2Unresolved = addonTable.GetUnresolvedConflictCount()
        end
        if f.guidedSetupRailBtn then
            local pill = f.guidedSetupRailBtn.conflictPill
            local badge = f.guidedSetupRailBtn.conflictBadge
            local okPip = f.guidedSetupRailBtn.okPip
            if totalUnresolved > 0 then
                if okPip then okPip:Hide() end
                if pill and badge then
                    pill.bg:SetColorTexture(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.20)
                    pill.dsBorder:SetColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.80)
                    UI.SetFont(badge, 8.5, "", UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1)
                    badge:SetText(string.format("! %d", totalUnresolved))
                    local bw = badge:GetStringWidth() or 22
                    pill:ClearAllPoints()
                    pill:SetPoint("TOPRIGHT", f.guidedSetupRailBtn, "TOPRIGHT", -6, -4)
                    pill:SetSize(math.max(28, math.ceil(bw + 10)), 13)
                    pill:Show()
                end
            else
                if pill then pill:Hide() end
                if okPip then okPip:Hide() end
            end
        end

        local curVer = addonTable.ADDON_VERSION or "2.2.0"
        local curSig = f.GetSuiteChangelogSignature and f.GetSuiteChangelogSignature() or curVer
        local seenVer = gTbl.lastSeenChangelogVer or (DynamicLoadDB and DynamicLoadDB.lastSeenChangelogVer)
        local seenSig = gTbl.lastSeenChangelogSig or (DynamicLoadDB and DynamicLoadDB.lastSeenChangelogSig)
        local hasUnreadChangelog = ((seenVer ~= curVer) or (seenSig ~= curSig)) and (activeWorkspaceView ~= "CHANGELOG_VIEW")
        if f.hdrHudBtn then f.hdrHudBtn:SetSelected(true, { r = ar, g = ag, b = ab }) end

        if f.verPill then
            if hasUnreadChangelog then
                f.verPill:SetSelected(true, UI.COLORS.GOLD)
                f.verPill.label:SetTextColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1)
            elseif activeWorkspaceView == "CHANGELOG_VIEW" then
                f.verPill:SetSelected(true, { r = ar, g = ag, b = ab })
            else
                f.verPill:SetSelected(false)
            end
        end

        for _, sBtn in ipairs(railStudioBtns) do
            local isSel = (activeWorkspaceView == sBtn.viewKey)
            local isUnreadCl = (sBtn.viewKey == "CHANGELOG_VIEW") and hasUnreadChangelog and (not isSel)
            if isUnreadCl then
                if sBtn.SetSelected then
                    sBtn:SetSelected(true, UI.COLORS.GOLD)
                end
                if sBtn.iconTex then
                    sBtn.iconTex:SetVertexColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1.0)
                end
                sBtn.bg:SetColorTexture(UI.COLORS.GOLD.r * 0.28, UI.COLORS.GOLD.g * 0.28, UI.COLORS.GOLD.b * 0.12, 0.96)
                sBtn.dsBorder:SetColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.98)
                sBtn.label:SetTextColor(1, 1, 1, 1)
            else
                if sBtn.SetSelected then
                    sBtn:SetSelected(isSel, { r = ar, g = ag, b = ab })
                end
                if sBtn.iconTex then
                    if isSel then
                        sBtn.iconTex:SetVertexColor(ar, ag, ab, 1.0)
                    else
                        sBtn.iconTex:SetVertexColor(0.72, 0.76, 0.84, 0.95)
                    end
                end
                if isSel then
                    sBtn.bg:SetColorTexture(ar, ag, ab, 0.24)
                    sBtn.dsBorder:SetColor(ar, ag, ab, 0.92)
                    sBtn.label:SetTextColor(1, 1, 1, 1)
                else
                    sBtn.bg:SetColorTexture(0.078, 0.090, 0.122, 0.94)
                    sBtn.dsBorder:SetColor(0.141, 0.161, 0.212, 0.90)
                    sBtn.label:SetTextColor(0.88, 0.91, 0.96, 1)
                end
            end
        end
    end
    f.RefreshLeftRailVisuals = RefreshLeftRailVisuals
    RefreshLeftRailLayout()
    end

    ----------------------------------------------------------------------------
    -- 4. MAIN RIGHT-HAND WORKSPACE CONTAINER (Two-Point C++ Anchored)
    ----------------------------------------------------------------------------
    local workspace = CreateFrame("Frame", nil, f)
    workspace:SetPoint("TOPLEFT", f, "TOPLEFT", RAIL_W + 1, -HDR_H)
    workspace:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, DOCK_H)
    workspace:SetFrameLevel((f:GetFrameLevel() or 1) + 5)
    if workspace.SetClipsChildren then workspace:SetClipsChildren(false) end
    if (workspace:GetWidth() or 0) <= 0 or (workspace:GetHeight() or 0) <= 0 then
        workspace:SetSize(math.max(500, (f:GetWidth() or PANEL_W) - RAIL_W - 2), math.max(300, (f:GetHeight() or PANEL_H) - HDR_H - DOCK_H))
    end
    workspace:Show()
    f.workspace = workspace

    local function SyncWorkspaceGeometry()
        if not workspace then return end
        local fw = (f:GetWidth() or 0)
        local fh = (f:GetHeight() or 0)
        if fw < 980 then fw = PANEL_W end
        if fh < 640 then fh = PANEL_H end
        workspace:ClearAllPoints()
        workspace:SetPoint("TOPLEFT", f, "TOPLEFT", RAIL_W + 1, -HDR_H)
        workspace:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, DOCK_H)
        workspace:SetFrameLevel((f:GetFrameLevel() or 1) + 5)
        if workspace.SetClipsChildren then workspace:SetClipsChildren(false) end
        if (workspace:GetWidth() or 0) <= 0 or (workspace:GetHeight() or 0) <= 0 then
            workspace:SetSize(math.max(500, fw - RAIL_W - 2), math.max(300, fh - HDR_H - DOCK_H))
        end
        workspace:Show()
    end
    f.SyncWorkspaceGeometry = SyncWorkspaceGeometry

    ----------------------------------------------------------------------------
    -- 4A. UNIFIED TOP-OF-MODULE CONFLICT & AUTO-YIELD BANNER (HARD / SOFT TIERS)
    ----------------------------------------------------------------------------
    do
        local mcBanner = CreateFrame("Frame", nil, workspace)
        mcBanner:SetPoint("TOPLEFT", workspace, "TOPLEFT", 14, -8)
        mcBanner:SetPoint("TOPRIGHT", workspace, "TOPRIGHT", -16, -8)
        mcBanner:SetHeight(50)
        mcBanner:SetFrameLevel((workspace:GetFrameLevel() or 2) + 25)
        mcBanner.bg = UI.SolidTex(mcBanner, "BACKGROUND", 1, 0.12, 0.08, 0.04, 0.96)
        mcBanner.bg:SetAllPoints()
        UI.CreatePixelBorder(mcBanner, UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.85, 3)

        local mcLeftBar = UI.SolidTex(mcBanner, "OVERLAY", 4, UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1.0)
        mcLeftBar:SetPoint("TOPLEFT", mcBanner, "TOPLEFT", 0, 0)
        mcLeftBar:SetPoint("BOTTOMLEFT", mcBanner, "BOTTOMLEFT", 0, 0)
        mcLeftBar:SetWidth(3)
        mcBanner.leftBar = mcLeftBar

        local mcBtnSecondary = CreateFlatButton(mcBanner, 134, 24, "Open DynamicLoad", false)
        mcBtnSecondary._autoExpandWidth = true
        mcBtnSecondary:SetPoint("RIGHT", mcBanner, "RIGHT", -10, 0)
        mcBanner.btnSecondary = mcBtnSecondary

        local mcBtnPrimary = CreateFlatButton(mcBanner, 152, 24, "Disable Conflict", true)
        mcBtnPrimary._autoExpandWidth = true
        mcBtnPrimary:SetPoint("RIGHT", mcBtnSecondary, "LEFT", -6, 0)
        mcBanner.btnPrimary = mcBtnPrimary

        local mcTitle = mcBanner:CreateFontString(nil, "OVERLAY")
        mcTitle:SetPoint("TOPLEFT", mcBanner, "TOPLEFT", 12, -8)
        mcTitle:SetPoint("RIGHT", mcBtnPrimary, "LEFT", -10, 0)
        mcTitle:SetJustifyH("LEFT")
        mcTitle:SetWordWrap(false)
        UI.SetFont(mcTitle, 11, "", UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1.0)
        mcBanner.title = mcTitle

        local mcSub = mcBanner:CreateFontString(nil, "OVERLAY")
        mcSub:SetPoint("TOPLEFT", mcTitle, "BOTTOMLEFT", 0, -3)
        mcSub:SetPoint("RIGHT", mcBtnPrimary, "LEFT", -10, 0)
        mcSub:SetJustifyH("LEFT")
        mcSub:SetWordWrap(false)
        UI.SetFont(mcSub, 9.5, "", 0.86, 0.89, 0.94, 0.95)
        mcBanner.sub = mcSub

        mcBanner:Hide()
        f.moduleConflictBanner = mcBanner

        local function ApplyWorkspaceHostTopOffset(topOffsetPx)
            local yOff = -(tonumber(topOffsetPx) or 0)
            local wsLevel = (workspace:GetFrameLevel() or 6)
            if f.dlView then
                f.dlView:ClearAllPoints()
                f.dlView:SetPoint("TOPLEFT", workspace, "TOPLEFT", 0, yOff)
                f.dlView:SetPoint("BOTTOMRIGHT", workspace, "BOTTOMRIGHT", 0, 0)
                f.dlView:SetFrameLevel(wsLevel + 2)
                if f.dlView.SetClipsChildren then f.dlView:SetClipsChildren(false) end
                if (f.dlView:GetWidth() or 0) <= 0 or (f.dlView:GetHeight() or 0) <= 0 then
                    local ww = (workspace:GetWidth() or 0) > 0 and workspace:GetWidth() or ((f:GetWidth() or PANEL_W) - RAIL_W - 2)
                    local wh = (workspace:GetHeight() or 0) > 0 and workspace:GetHeight() or ((f:GetHeight() or PANEL_H) - HDR_H - DOCK_H)
                    f.dlView:SetSize(math.max(500, ww), math.max(300, wh + yOff))
                end
            end
            if f.peerModuleHostFrame then
                f.peerModuleHostFrame:ClearAllPoints()
                f.peerModuleHostFrame:SetPoint("TOPLEFT", workspace, "TOPLEFT", 0, yOff)
                f.peerModuleHostFrame:SetPoint("BOTTOMRIGHT", workspace, "BOTTOMRIGHT", 0, 0)
                f.peerModuleHostFrame:SetFrameLevel(wsLevel + 2)
                if f.peerModuleHostFrame.SetClipsChildren then f.peerModuleHostFrame:SetClipsChildren(false) end
                if (f.peerModuleHostFrame:GetWidth() or 0) <= 0 or (f.peerModuleHostFrame:GetHeight() or 0) <= 0 then
                    local ww = (workspace:GetWidth() or 0) > 0 and workspace:GetWidth() or ((f:GetWidth() or PANEL_W) - RAIL_W - 2)
                    local wh = (workspace:GetHeight() or 0) > 0 and workspace:GetHeight() or ((f:GetHeight() or PANEL_H) - HDR_H - DOCK_H)
                    f.peerModuleHostFrame:SetSize(math.max(500, ww), math.max(300, wh + yOff))
                end
            end
        end
        f.ApplyWorkspaceHostTopOffset = ApplyWorkspaceHostTopOffset

        function f.UpdateModuleConflictBanner(explicitModKey)
            local isModuleView = (activeWorkspaceView == "DYNAMICLOAD" or activeWorkspaceView == "PEER_HOST" or activeWorkspaceView == "PEER_MODULE")
            if not isModuleView then
                mcBanner:Hide()
                ApplyWorkspaceHostTopOffset(0)
                return
            end

            local activeModKey = explicitModKey
            if not activeModKey then
                if activeWorkspaceView == "DYNAMICLOAD" then
                    activeModKey = "DynamicLoad"
                else
                    activeModKey = selectedPeerModuleKey
                end
            end
            if not activeModKey or not addonTable.GetModuleConflicts then
                mcBanner:Hide()
                ApplyWorkspaceHostTopOffset(0)
                return
            end

            local _, hardList, softList = addonTable.GetModuleConflicts(activeModKey)
            if #hardList > 0 then
                local primary = hardList[1]
                local cAddon = primary.conflictAddon
                local cFriendly = primary.friendlyName or cAddon
                local extraCount = #hardList - 1
                local nameDisplay = (extraCount > 0) and string.format("%s (+%d more)", cAddon, extraCount) or cAddon

                mcBanner:SetHeight(50)
                mcBanner.bg:SetColorTexture(0.13, 0.08, 0.04, 0.96)
                mcBanner.dsBorder:SetColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.88)
                mcBanner.leftBar:SetColorTexture(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1.0)

                mcTitle:ClearAllPoints()
                mcTitle:SetPoint("TOPLEFT", mcBanner, "TOPLEFT", 12, -8)
                mcTitle:SetPoint("RIGHT", mcBtnPrimary, "LEFT", -10, 0)
                UI.SetFont(mcTitle, 10.5, "", UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1.0)
                if cAddon == "DecorVendor" then
                    mcTitle:SetText("Raid Marker Blocked: Decor Vendor taints Blizzard's /tm command (SetRaidTarget).")
                else
                    mcTitle:SetText(string.format("Conflict Detected: %s is currently active and may cause UI errors or blocked actions.", nameDisplay))
                end

                mcSub:Show()
                UI.SetFont(mcSub, 9.5, "", 0.84, 0.88, 0.94, 0.95)
                if cAddon == "DecorVendor" then
                    mcSub:SetText("Disable Decor Vendor (Set to Never) and completely Exit & Restart World of Warcraft (/reload alone will not clear it).")
                else
                    mcSub:SetText(string.format("Both %s and %s replace %s. Disable %s or manage it in DynamicLoad.", cFriendly, primary.dynamicModule or activeModKey, (primary.category or "this UI"):lower(), cFriendly))
                end

                local dlLoaded = (addonTable.IsDynamicLoadModuleLoaded == true) or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("DynamicLoad"))
                if activeModKey ~= "DynamicLoad" and dlLoaded then
                    mcBtnSecondary:Show()
                    mcBtnSecondary.label:SetText("Open DynamicLoad")
                    local sw = (mcBtnSecondary.label.GetStringWidth and mcBtnSecondary.label:GetStringWidth()) or 106
                    mcBtnSecondary:SetWidth(math.max(122, math.ceil(sw + 20)))
                    mcBtnSecondary:SetSelected(false)
                    mcBtnSecondary:SetScript("OnClick", function()
                        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
                        addonTable.OpenWorkspaceView("DYNAMICLOAD")
                    end)
                    mcBtnPrimary:ClearAllPoints()
                    mcBtnPrimary:SetPoint("RIGHT", mcBtnSecondary, "LEFT", -6, 0)
                else
                    mcBtnSecondary:Hide()
                    mcBtnPrimary:ClearAllPoints()
                    mcBtnPrimary:SetPoint("RIGHT", mcBanner, "RIGHT", -10, 0)
                end

                mcBtnPrimary:Show()
                if mcBanner._pendingReloadFor == cAddon then
                    if cAddon == "DecorVendor" then
                        mcBanner.dsBorder:SetColor(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 0.88)
                        mcBanner.leftBar:SetColorTexture(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.b and UI.COLORS.EMERALD.g or 0.725, UI.COLORS.EMERALD.b, 1.0)
                        mcTitle:SetText("Decor Vendor Disabled (Set to Never) - Exit & Restart Required.")
                        mcSub:SetText("Please completely Exit & Restart World of Warcraft now (/reload alone will not clear SetRaidTarget taint).")
                        mcBtnPrimary:Hide()
                        mcBtnSecondary:Hide()
                    else
                        mcBtnPrimary.label:SetText("Reload UI Now")
                        mcBtnPrimary:SetWidth(124)
                        mcBtnPrimary:SetSelected(true, UI.COLORS.EMERALD)
                        mcSub:SetText(string.format("%s has been disabled and locked to [Never]. Click 'Reload UI Now' to complete unloading.", cFriendly))
                        mcBtnPrimary:SetScript("OnClick", function()
                            if type(_G.ReloadUI) == "function" then
                                _G.ReloadUI()
                            end
                        end)
                    end
                else
                    local disText = (cAddon == "DecorVendor") and "Disable DecorVendor (Never)" or ("Use " .. tostring(primary.dynamicModule or activeModKey) .. " Only")
                    if cAddon ~= "DecorVendor" and #disText > 24 then disText = "Use Dynamic Only" end
                    mcBtnPrimary.label:SetText(disText)
                    local pw = (mcBtnPrimary.label.GetStringWidth and mcBtnPrimary.label:GetStringWidth()) or 110
                    mcBtnPrimary:SetWidth(math.max(128, math.ceil(pw + 22)))
                    mcBtnPrimary:SetSelected(true, UI.COLORS.GOLD)
                    mcBtnPrimary:SetScript("OnClick", function()
                        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
                        for _, hItem in ipairs(hardList) do
                            if addonTable.QuarantineRaidTaintAddon and hItem.conflictAddon == "DecorVendor" then
                                addonTable.QuarantineRaidTaintAddon("DecorVendor")
                            else
                                if C_AddOns and C_AddOns.DisableAddOn then
                                    pcall(C_AddOns.DisableAddOn, hItem.conflictAddon)
                                end
                                if addonTable.ResolveConflict then
                                    addonTable.ResolveConflict(hItem.dynamicModule or activeModKey, hItem.conflictAddon, "USE_DYNAMIC")
                                end
                            end
                        end
                        mcBanner._pendingReloadFor = cAddon
                        if cAddon == "DecorVendor" then
                            mcBanner.dsBorder:SetColor(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 0.88)
                            mcBanner.leftBar:SetColorTexture(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 1.0)
                            mcTitle:SetText("Decor Vendor Disabled (Set to Never) - Exit & Restart Required.")
                            mcSub:SetText("Please completely Exit & Restart World of Warcraft now (/reload alone will not clear SetRaidTarget taint).")
                            mcBtnPrimary:Hide()
                            mcBtnSecondary:Hide()
                        else
                            mcTitle:SetText(string.format("Conflict Resolved: %s disabled for next session.", cFriendly))
                            mcSub:SetText(string.format("%s is now disabled and set to [Never]. Click 'Reload UI Now' to apply cleanly.", cFriendly))
                            mcBtnPrimary.label:SetText("Reload UI Now")
                            mcBtnPrimary:SetWidth(124)
                            mcBtnPrimary:SetSelected(true, UI.COLORS.EMERALD)
                            mcBtnPrimary:SetScript("OnClick", function()
                                if type(_G.ReloadUI) == "function" then
                                    _G.ReloadUI()
                                end
                            end)
                        end
                        if f.RefreshLeftRailVisuals then f.RefreshLeftRailVisuals() end
                        if f.scrollChild and RefreshAddonTree then RefreshAddonTree(f.scrollChild) end
                    end)
                end

                mcBanner:Show()
                ApplyWorkspaceHostTopOffset(56)
            else
                if mcBanner._pendingReloadFor == "DecorVendor" then
                    mcBanner:SetHeight(50)
                    mcBanner.bg:SetColorTexture(0.035, 0.039, 0.051, 0.96)
                    mcBanner.dsBorder:SetColor(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 0.88)
                    mcBanner.leftBar:SetColorTexture(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 1.0)
                    mcTitle:ClearAllPoints()
                    mcTitle:SetPoint("TOPLEFT", mcBanner, "TOPLEFT", 12, -8)
                    mcTitle:SetPoint("RIGHT", mcBanner, "RIGHT", -12, 0)
                    UI.SetFont(mcTitle, 10.5, "", UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 1.0)
                    mcTitle:SetText("Decor Vendor Disabled (Set to Never) - Exit & Restart Required.")
                    mcSub:Show()
                    UI.SetFont(mcSub, 9.5, "", 0.84, 0.88, 0.94, 0.95)
                    mcSub:SetText("Please completely Exit & Restart World of Warcraft now (/reload alone will not clear SetRaidTarget taint).")
                    mcBtnPrimary:Hide()
                    mcBtnSecondary:Hide()
                    mcBanner:Show()
                    ApplyWorkspaceHostTopOffset(56)
                else
                    mcBanner._pendingReloadFor = nil
                    mcBanner:Hide()
                    ApplyWorkspaceHostTopOffset(0)
                end
            end
        end
    end


    ----------------------------------------------------------------------------
    -- VIEW A: DYNAMICLOAD WORKSPACE (Mounted by DynamicLoad_UI.lua when present)
    ----------------------------------------------------------------------------
    f.EnsureDynamicLoadWorkspaceMounted = function()
        if (not f._dlWorkspaceMounted or not f.dlView) and addonTable.MountDynamicLoadWorkspace then
            f._dlWorkspaceMounted = true
            addonTable.MountDynamicLoadWorkspace(f, workspace)
        end
        if f.dlView then
            f.dlView:SetFrameLevel((workspace:GetFrameLevel() or 6) + 2)
            if f.dlView.SetClipsChildren then f.dlView:SetClipsChildren(false) end
        end
    end
    f.EnsureDynamicLoadWorkspaceMounted()

    ----------------------------------------------------------------------------
    -- VIEW E: PEER MODULE PREVIEW CARD (When clicking /dm, /dz, /dfps, /dprep, /dgroup)
    ----------------------------------------------------------------------------
    local peerView = CreateFrame("Frame", nil, workspace)
    peerView:SetAllPoints()
    peerView:SetFrameLevel((workspace:GetFrameLevel() or 6) + 2)
    if peerView.SetClipsChildren then peerView:SetClipsChildren(false) end
    peerView:Hide()
    f.peerView = peerView
    f.peerContainer = f.peerModuleHostFrame or peerView

    do
    local peerCard = CreateFrame("Frame", nil, peerView)
    table.insert(f.themeCards, peerCard)
    peerCard:SetPoint("TOPLEFT", peerView, "TOPLEFT", 24, -24)
    peerCard:SetPoint("TOPRIGHT", peerView, "TOPRIGHT", -24, -24)
    peerCard:SetHeight(240)
    peerCard.bg = UI.SolidTex(peerCard, "BACKGROUND", 0, UI.COLORS.CARD_BG.r, UI.COLORS.CARD_BG.g, UI.COLORS.CARD_BG.b, 0.96)
    peerCard.bg:SetAllPoints()
    UI.CreatePixelBorder(peerCard, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.65, 2)

    local peerTitle = peerCard:CreateFontString(nil, "OVERLAY")
    peerTitle:SetPoint("TOPLEFT", peerCard, "TOPLEFT", 20, -18)
    UI.SetFont(peerTitle, 16, "", 1, 1, 1, 0.98)

    local peerCat = peerCard:CreateFontString(nil, "OVERLAY")
    peerCat:SetPoint("TOPLEFT", peerTitle, "BOTTOMLEFT", 0, -6)
    UI.SetFont(peerCat, 12, "", UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 1)

    local peerDesc = peerCard:CreateFontString(nil, "OVERLAY")
    peerDesc:SetPoint("TOPLEFT", peerCat, "BOTTOMLEFT", 0, -14)
    peerDesc:SetPoint("RIGHT", peerCard, "RIGHT", -20, 0)
    peerDesc:SetJustifyH("LEFT")
    peerDesc:SetSpacing(3)
    UI.SetFont(peerDesc, 11, "", 0.86, 0.88, 0.92, 1)

    local peerStatus = peerCard:CreateFontString(nil, "OVERLAY")
    peerStatus:SetPoint("BOTTOMLEFT", peerCard, "BOTTOMLEFT", 20, 22)
    UI.SetFont(peerStatus, 11, "", UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1)

    local peerToggleBtn = CreateFlatButton(peerCard, 176, 28, "Enable Module", true)
    peerToggleBtn:SetPoint("BOTTOMRIGHT", peerCard, "BOTTOMRIGHT", -20, 18)

    local peerBackBtn = CreateFlatButton(peerCard, 150, 28, "Back to DynamicLoad", false)
    peerBackBtn:SetPoint("RIGHT", peerToggleBtn, "LEFT", -10, 0)
    peerBackBtn:SetScript("OnClick", function()
        addonTable.OpenWorkspaceView("DYNAMICLOAD")
    end)

    peerView.Refresh = function()
        local mInfo = nil
        for _, m in ipairs(addonTable.SUITE_MODULE_LIST or {}) do
            if m.key == selectedPeerModuleKey or m.addonName == selectedPeerModuleKey or m.id == selectedPeerModuleKey then
                mInfo = m
                break
            end
        end
        if not mInfo then return end

        local addonKey = mInfo.addonName or mInfo.name or mInfo.key
        local shortKey = mInfo.id or mInfo.key or tostring(addonKey):gsub("^Dynamic", ""):lower()
        peerTitle:SetText((mInfo.title or addonKey) .. "  (" .. (mInfo.slash or "/ds") .. ")")
        peerCat:SetText(mInfo.category or "DynamicSuite Module")
        peerDesc:SetText(mInfo.desc or "")

        local aName, _, _, _, aReason = C_AddOns.GetAddOnInfo(addonKey)
        local hasStandalone = (aName ~= nil) and (aReason ~= "MISSING")
        local state = hasStandalone and (C_AddOns.GetAddOnEnableState(addonKey, pName) or 0) or 0
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local isExplicitDis = (addonTable.IsSuiteModuleExplicitlyDisabled and addonTable.IsSuiteModuleExplicitlyDisabled(addonKey))
            or (gTbl.disabledModules and (gTbl.disabledModules[addonKey] or gTbl.disabledModules[shortKey]))
            or (_G.DynamicSuiteDB and _G.DynamicSuiteDB.disabledModules and (_G.DynamicSuiteDB.disabledModules[addonKey] or _G.DynamicSuiteDB.disabledModules[shortKey]))

        local regMod = (DynamicSuite and DynamicSuite.modules and (DynamicSuite.modules[addonKey] or DynamicSuite.modules[shortKey] or DynamicSuite.modules[mInfo.key])) or _G[addonKey]
        local idx = hasStandalone or (regMod ~= nil)
        if (not isExplicitDis) and regMod and (not regMod._disabledAtStartup) and type(regMod.RenderEmbedded or regMod.Render or regMod.BuildUI or regMod.BuildConfigUI) == "function" then
            if hasStandalone and addonKey ~= "DynamicSuite" and addonKey ~= "DynamicMarker" then
                C_AddOns.EnableAddOn(addonKey, pName)
                C_AddOns.EnableAddOn(addonKey)
            end
            if gTbl.disabledModules then
                gTbl.disabledModules[addonKey] = nil
                gTbl.disabledModules[shortKey] = nil
            end
            if _G.DynamicSuiteDB and _G.DynamicSuiteDB.disabledModules then
                _G.DynamicSuiteDB.disabledModules[addonKey] = nil
                _G.DynamicSuiteDB.disabledModules[shortKey] = nil
            end
            for _, card in ipairs(railModuleCards) do
                local m = card.modInfo
                local aKey = m.addonName or m.name or m.key
                if addonKey == aKey or addonKey == m.key or addonKey == m.id then
                    card:GetScript("OnClick")(card, "LeftButton")
                    return
                end
            end
        end

        if idx then
            if isExplicitDis then
                peerStatus:SetText("|cFFF5B82EStatus: Bundled in DynamicSuite (Currently Disabled via Left Suite Rail)|r")
                peerToggleBtn.label:SetText("Enable " .. (mInfo.title or addonKey))
            elseif regMod and regMod._disabledAtStartup then
                peerStatus:SetText("|cFF22C55EStatus: Enabled in DynamicSuite (Click 'Reload UI & Load' to Finish Loading)|r")
                peerToggleBtn.label:SetText("Reload UI & Load")
            elseif state > 0 then
                peerStatus:SetText("|cFF22C55EStatus: Installed & Enabled in AddOn List (Click 'Reload UI & Load' to Activate)|r")
                peerToggleBtn.label:SetText("Reload UI & Load")
            else
                peerStatus:SetText("|cFFF5B82EStatus: Installed in AddOns Folder (Currently Disabled)|r")
                peerToggleBtn.label:SetText("Enable " .. (mInfo.title or addonKey))
            end
            peerToggleBtn:Enable()
            peerToggleBtn:SetAlpha(1.0)
            peerToggleBtn:SetScript("OnClick", function()
                if hasStandalone and addonKey ~= "DynamicSuite" and addonKey ~= "DynamicMarker" then
                    C_AddOns.EnableAddOn(addonKey, pName)
                    C_AddOns.EnableAddOn(addonKey)
                end
                if gTbl.disabledModules then
                    gTbl.disabledModules[addonKey] = nil
                    gTbl.disabledModules[shortKey] = nil
                end
                if _G.DynamicSuiteDB and _G.DynamicSuiteDB.disabledModules then
                    _G.DynamicSuiteDB.disabledModules[addonKey] = nil
                    _G.DynamicSuiteDB.disabledModules[shortKey] = nil
                end
                if hasStandalone and addonKey ~= "DynamicMarker" and C_AddOns.LoadAddOn then
                    pcall(C_AddOns.LoadAddOn, addonKey)
                end
                local liveMod = (DynamicSuite and DynamicSuite.modules and (DynamicSuite.modules[addonKey] or DynamicSuite.modules[shortKey] or DynamicSuite.modules[mInfo.key])) or _G[addonKey]
                if liveMod and type(liveMod.OnEnableInSuite) == "function" then
                    pcall(liveMod.OnEnableInSuite, liveMod)
                end
                if liveMod and (not liveMod._disabledAtStartup) and type(liveMod.RenderEmbedded or liveMod.Render or liveMod.BuildUI or liveMod.BuildConfigUI) == "function" then
                    addonTable.OpenPeerModule(addonKey)
                    return
                end
                if type(_G.ReloadUI) == "function" then
                    _G.ReloadUI()
                    return
                end
                peerView.Refresh()
                RefreshLeftRailVisuals()
            end)
        else
            peerStatus:SetText("|cFFF5B82EStatus: Newly Installed in AddOns Folder (Restart WoW or Reload UI to Detect)|r")
            peerToggleBtn.label:SetText("Reload UI")
            peerToggleBtn:Enable()
            peerToggleBtn:SetAlpha(1.0)
            peerToggleBtn:SetScript("OnClick", function()
                if type(_G.ReloadUI) == "function" then
                    _G.ReloadUI()
                end
            end)
        end
    end
    end

    ----------------------------------------------------------------------------
    -- VIEW B: SUITE STUDIO (Tab 1: Theme & Typography | Tab 2: Desktop Windows & Menus)
    ----------------------------------------------------------------------------
    local themeView = CreateFrame("Frame", nil, workspace)
    themeView:SetAllPoints()
    themeView:SetFrameLevel((workspace:GetFrameLevel() or 6) + 2)
    if themeView.SetClipsChildren then themeView:SetClipsChildren(false) end
    themeView:Hide()
    f.themeView = themeView
    f.themeStudioView = themeView
    f.suiteStudioView = themeView

    do
    local activeStudioTab = 1
    themeView.activeTab = 1

    -- 1. Universal 34px #0B0D12 Recessed Top 2-Tab Bar at (14, -10) to (-16, -10)
    local studioTabBar = CreateFrame("Frame", nil, themeView)
    studioTabBar:SetPoint("TOPLEFT", themeView, "TOPLEFT", 14, -10)
    studioTabBar:SetPoint("TOPRIGHT", themeView, "TOPRIGHT", -16, -10)
    studioTabBar:SetHeight(34)
    studioTabBar.bg = UI.SolidTex(studioTabBar, "BACKGROUND", 1, 0.043, 0.051, 0.071, 0.98)
    studioTabBar.bg:SetAllPoints()
    UI.CreatePixelBorder(studioTabBar, 1, 1, 1, 0.08, 2)
    themeView.tabBar = studioTabBar

    local studioTabDefs = {
        { id = 1, label = "Theme & Typography",      icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_palette.tga" },
        { id = 2, label = "Desktop Windows & Menus", icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_grid.tga" },
    }
    local studioTabBtns = {}

    local studioHdrRow = CreateFrame("Frame", nil, themeView)
    studioHdrRow:SetPoint("TOPLEFT", studioTabBar, "BOTTOMLEFT", 0, -6)
    studioHdrRow:SetPoint("TOPRIGHT", studioTabBar, "BOTTOMRIGHT", 0, -6)
    studioHdrRow:SetHeight(24)

    local tvTitle = studioHdrRow:CreateFontString(nil, "OVERLAY")
    tvTitle:SetPoint("LEFT", studioHdrRow, "LEFT", 0, 0)
    UI.SetFont(tvTitle, 13, "", 1, 1, 1, 0.98)
    tvTitle:SetText("SUITE STUDIO")

    local tvResetBtn = CreateFlatButton(studioHdrRow, 158, 24, "Reset Theme Defaults", false)
    tvResetBtn:SetPoint("RIGHT", studioHdrRow, "RIGHT", 0, 0)

    -- Obsidian Scrollable Body Container + 4px 3-Way Interactive Scrollbar (zero clipping at 640px min height)
    local tvScroll = CreateFrame("ScrollFrame", nil, themeView)
    tvScroll:SetPoint("TOPLEFT", studioHdrRow, "BOTTOMLEFT", 0, -6)
    tvScroll:SetPoint("BOTTOMRIGHT", themeView, "BOTTOMRIGHT", -16, 10)
    tvScroll:SetClipsChildren(true)
    tvScroll:EnableMouseWheel(true)

    local tvChild = CreateFrame("Frame", nil, tvScroll)
    tvChild:SetSize(780, 847)
    tvScroll:SetScrollChild(tvChild)

    local tvTrack = CreateFrame("Frame", nil, themeView)
    tvTrack:SetWidth(4)
    tvTrack:SetPoint("TOPRIGHT", tvScroll, "TOPRIGHT", 10, -2)
    tvTrack:SetPoint("BOTTOMRIGHT", tvScroll, "BOTTOMRIGHT", 10, 2)
    tvTrack:EnableMouse(true)
    tvTrack:SetHitRectInsets(-5, -5, 0, 0)
    tvTrack.bg = UI.SolidTex(tvTrack, "BACKGROUND", 1, 1, 1, 1, 0.05)
    tvTrack.bg:SetAllPoints()

    local tvThumb = CreateFrame("Button", nil, tvTrack)
    tvThumb:SetWidth(4)
    tvThumb:SetHeight(64)
    tvThumb:SetPoint("TOP", tvTrack, "TOP", 0, 0)
    tvThumb:EnableMouse(true)
    tvThumb:SetHitRectInsets(-5, -5, 0, 0)
    tvThumb.tex = UI.SolidTex(tvThumb, "OVERLAY", 2, 0.38, 0.45, 0.56, 0.85)
    tvThumb.tex:SetAllPoints()

    local function UpdateThemeScrollbar()
        if tvScroll.UpdateScrollChildRect then
            pcall(tvScroll.UpdateScrollChildRect, tvScroll)
        end
        local trackH = tvTrack:GetHeight() or 400
        local viewH = tvScroll:GetHeight() or 400
        local contentH = tvChild:GetHeight() or 847
        if trackH <= 1 or viewH <= 1 then return end
        local maxScroll = math.max(0, contentH - viewH)
        if maxScroll <= 1 then
            tvTrack:Hide()
            tvThumb:Hide()
            tvScroll:SetVerticalScroll(0)
            return
        end
        tvTrack:Show()
        tvThumb:Show()
        local ratio = math.max(0.12, math.min(1, viewH / contentH))
        local thumbH = math.max(28, math.floor(trackH * ratio + 0.5))
        tvThumb:SetHeight(thumbH)
        local cur = math.max(0, math.min(maxScroll, tvScroll:GetVerticalScroll() or 0))
        local travel = math.max(1, trackH - thumbH)
        local yOff = -(cur / maxScroll) * travel
        tvThumb:ClearAllPoints()
        tvThumb:SetPoint("TOP", tvTrack, "TOP", 0, yOff)
        if not tvThumb.isDragging then
            if tvThumb.isHovered then
                local ar, ag, ab = UI.GetActiveAccentColor()
                tvThumb.tex:SetColorTexture(ar, ag, ab, 0.92)
            else
                tvThumb.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
            end
        end
    end

    local function ScrollThemeFromCursor()
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            tvThumb.isDragging = false
            tvThumb:SetScript("OnUpdate", nil)
            tvTrack:SetScript("OnUpdate", nil)
            if tvThumb.isHovered then
                local ar, ag, ab = UI.GetActiveAccentColor()
                tvThumb.tex:SetColorTexture(ar, ag, ab, 0.92)
            else
                tvThumb.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
            end
            return
        end
        local viewH = tvScroll:GetHeight() or 0
        local contentH = tvChild:GetHeight() or 0
        local maxScroll = math.max(0, contentH - viewH)
        if maxScroll <= 0 then return end

        local eff = tvTrack:GetEffectiveScale() or 1
        local _, cy = GetCursorPosition()
        cy = cy / eff
        local top = tvTrack:GetTop()
        local bottom = tvTrack:GetBottom()
        if top and bottom and top > bottom then
            local trackH = top - bottom
            local thumbH = tvThumb:GetHeight() or 28
            local usableH = math.max(1, trackH - thumbH)
            local offsetFromTop = (top - cy) - (thumbH * 0.5)
            local ratio = math.max(0, math.min(1, offsetFromTop / usableH))
            tvScroll:SetVerticalScroll(ratio * maxScroll)
            UpdateThemeScrollbar()
        end
    end

    tvThumb:SetScript("OnEnter", function(self)
        self.isHovered = true
        if not self.isDragging then
            local ar, ag, ab = UI.GetActiveAccentColor()
            self.tex:SetColorTexture(ar, ag, ab, 0.92)
        end
    end)
    tvThumb:SetScript("OnLeave", function(self)
        self.isHovered = false
        if not self.isDragging then
            self.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
        end
    end)
    tvThumb:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            if UI.CloseAllPopups then UI.CloseAllPopups() end
            self.isDragging = true
            local ar, ag, ab = UI.GetActiveAccentColor()
            self.tex:SetColorTexture(ar, ag, ab, 1.0)
            ScrollThemeFromCursor()
            self:SetScript("OnUpdate", ScrollThemeFromCursor)
        end
    end)
    tvThumb:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.isDragging = false
            self:SetScript("OnUpdate", nil)
            if self.isHovered then
                local ar, ag, ab = UI.GetActiveAccentColor()
                self.tex:SetColorTexture(ar, ag, ab, 0.92)
            else
                self.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
            end
        end
    end)
    tvThumb:SetScript("OnHide", function(self)
        self.isDragging = false
        self.isHovered = false
        self:SetScript("OnUpdate", nil)
        self.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
    end)

    tvTrack:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            if UI.CloseAllPopups then UI.CloseAllPopups() end
            tvThumb.isDragging = true
            local ar, ag, ab = UI.GetActiveAccentColor()
            tvThumb.tex:SetColorTexture(ar, ag, ab, 1.0)
            ScrollThemeFromCursor()
            self:SetScript("OnUpdate", ScrollThemeFromCursor)
        end
    end)
    tvTrack:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            tvThumb.isDragging = false
            self:SetScript("OnUpdate", nil)
            tvThumb.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
        end
    end)
    tvTrack:SetScript("OnHide", function(self)
        tvThumb.isDragging = false
        self:SetScript("OnUpdate", nil)
        tvThumb.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
    end)

    local function ScrollThemeByDelta(delta)
        if UI.IsDropdownPopupShown and UI.IsDropdownPopupShown() and UI.CloseAllPopups then
            UI.CloseAllPopups()
        end
        local maxScroll = math.max(0, (tvChild:GetHeight() or 847) - (tvScroll:GetHeight() or 400))
        local nextScroll = math.max(0, math.min(maxScroll, (tvScroll:GetVerticalScroll() or 0) - (delta * 44)))
        tvScroll:SetVerticalScroll(nextScroll)
        UpdateThemeScrollbar()
    end

    tvScroll:SetScript("OnMouseWheel", function(_, delta)
        ScrollThemeByDelta(delta)
    end)
    tvTrack:SetScript("OnMouseWheel", function(_, delta)
        ScrollThemeByDelta(delta)
    end)
    tvThumb:SetScript("OnMouseWheel", function(_, delta)
        ScrollThemeByDelta(delta)
    end)
    tvScroll:SetScript("OnVerticalScroll", function()
        UpdateThemeScrollbar()
    end)
    tvScroll:SetScript("OnScrollRangeChanged", function()
        UpdateThemeScrollbar()
    end)

    tvScroll:SetScript("OnSizeChanged", function(self, w)
        if w and w > 40 then
            tvChild:SetWidth(w)
        end
        UpdateThemeScrollbar()
    end)

    -- Card 1: 17 Unique Accent Swatches (9+8) + [Auto-Match Class] + [Custom Color Picker] + 8 Recent Colors
    local swatchCard = CreateFrame("Frame", nil, tvChild)
    swatchCard:SetPoint("TOPLEFT", tvChild, "TOPLEFT", 0, 0)
    swatchCard:SetPoint("TOPRIGHT", tvChild, "TOPRIGHT", 0, 0)
    swatchCard:SetHeight(162)
    swatchCard.bg = UI.SolidTex(swatchCard, "BACKGROUND", 0, UI.COLORS.CARD_BG.r, UI.COLORS.CARD_BG.g, UI.COLORS.CARD_BG.b, 0.94)
    swatchCard.bg:SetAllPoints()
    UI.CreatePixelBorder(swatchCard, 1, 1, 1, 0.08, 2)

    local scHdr = UI.CreateSectionHeader(swatchCard, -10, "ACCENT COLOUR PRESETS & CUSTOM PALETTE", "Choose from 17 curated accent swatches, auto-match your class colour, or pick a custom hex colour.", 14)

    local presetSwatchBtns, customPickBtn, autoClassBtn, studioRecentBtns = {}, nil, nil, {}
    do
    for idx, pDef in ipairs(ACCENT_PRESETS) do
        local sBtn = CreateFrame("Button", nil, swatchCard)
        sBtn:SetSize(32, 24)
        local colIdx = (idx - 1) % 9
        local rowIdx = math.floor((idx - 1) / 9)
        sBtn:SetPoint("TOPLEFT", scHdr, "BOTTOMLEFT", colIdx * 38, -8 - (rowIdx * 30))
        sBtn.pDef = pDef

        sBtn.tex = UI.SolidTex(sBtn, "ARTWORK", 1, pDef.r, pDef.g, pDef.b, 1)
        sBtn.tex:SetPoint("TOPLEFT", sBtn, "TOPLEFT", 1, -1)
        sBtn.tex:SetPoint("BOTTOMRIGHT", sBtn, "BOTTOMRIGHT", -1, 1)
        UI.CreatePixelBorder(sBtn, 1, 1, 1, 0.25, 3)

        sBtn:SetScript("OnEnter", function(self)
            self.dsBorder:SetColor(1, 1, 1, 1.0)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(pDef.name, 1, 1, 1)
            GameTooltip:Show()
        end)
        sBtn:SetScript("OnLeave", function(self)
            self.dsBorder:SetColor(1, 1, 1, self.isSelected and 1.0 or 0.22)
            GameTooltip:Hide()
        end)
        sBtn:SetScript("OnClick", function()
            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
            if gTbl then
                gTbl.accentKey = pDef.key
                gTbl.customAccent = nil
            end
            if addonTable.ApplySuiteThemeAndGeometry then addonTable.ApplySuiteThemeAndGeometry() end
            if themeView.Refresh then themeView.Refresh() end
        end)
        table.insert(presetSwatchBtns, sBtn)
    end

    -- [Auto-Match Class] + [Custom Colour Picker] + 8 Recently Picked Swatches on Right Side of Card 1
    customPickBtn = CreateFlatButton(swatchCard, 148, 26, "Custom Colour Picker", false)
    customPickBtn:SetPoint("TOPRIGHT", swatchCard, "TOPRIGHT", -16, -52)
    customPickBtn:SetScript("OnClick", function(self)
        local ar, ag, ab = UI.GetActiveAccentColor()
        OpenDSColorPicker(self, "Custom Suite Accent Colour", { r = ar, g = ag, b = ab, a = 1 }, false, function(nr, ng, nb)
            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
            if gTbl then
                gTbl.accentKey = "CUSTOM"
                gTbl.customAccent = { r = nr, g = ng, b = nb }
            end
            if addonTable.ApplySuiteThemeAndGeometry then addonTable.ApplySuiteThemeAndGeometry() end
            if themeView.Refresh then themeView.Refresh() end
        end)
    end)

    autoClassBtn = CreateFlatButton(swatchCard, 134, 26, "Auto-Match Class", false)
    autoClassBtn:SetPoint("RIGHT", customPickBtn, "LEFT", -8, 0)
    autoClassBtn:SetScript("OnClick", function()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        if gTbl then
            gTbl.accentKey = "AUTO_CLASS"
            gTbl.customAccent = nil
        end
        if addonTable.ApplySuiteThemeAndGeometry then addonTable.ApplySuiteThemeAndGeometry() end
        if themeView.Refresh then themeView.Refresh() end
    end)
    autoClassBtn.OnCustomEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Auto-Match My Class Colour", 1, 1, 1)
        GameTooltip:AddLine("Automatically adapts the accent colour to whichever class you log in on.", 0.85, 0.88, 0.92, true)
        GameTooltip:Show()
    end
    autoClassBtn.OnCustomLeave = function()
        GameTooltip:Hide()
    end

    local recentLbl = swatchCard:CreateFontString(nil, "OVERLAY")
    recentLbl:SetPoint("TOPRIGHT", customPickBtn, "BOTTOMRIGHT", 0, -10)
    UI.SetFont(recentLbl, 10, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 0.9)
    recentLbl:SetText("Recent Custom Colours:")


    for i = 1, 8 do
        local rBtn = CreateFrame("Button", nil, swatchCard)
        rBtn:SetSize(22, 20)
        rBtn:SetPoint("TOPRIGHT", recentLbl, "BOTTOMRIGHT", -((8 - i) * 25), -5)
        rBtn.tex = UI.SolidTex(rBtn, "ARTWORK", 1, 0.1, 0.1, 0.1, 0.5)
        rBtn.tex:SetPoint("TOPLEFT", rBtn, "TOPLEFT", 1, -1)
        rBtn.tex:SetPoint("BOTTOMRIGHT", rBtn, "BOTTOMRIGHT", -1, 1)
        UI.CreatePixelBorder(rBtn, 1, 1, 1, 0.25, 4)
        studioRecentBtns[i] = rBtn
    end
    end

    -- Reusable Sleek Obsidian Dropdown Control + Direction A Segmented Pills + Inline Sub-Drawer
    do
    local dsDropdownPopup = nil
    function UI.IsDropdownPopupShown()
        return dsDropdownPopup and dsDropdownPopup:IsShown() or false
    end
    local function CloseDSDropdownPopup()
        if dsDropdownPopup then
            if dsDropdownPopup.searchBox then
                dsDropdownPopup.searchBox:ClearFocus()
            end
            if dsDropdownPopup.ownerBtn then
                UI.SetChevronState(dsDropdownPopup.ownerBtn, false)
                dsDropdownPopup.ownerBtn = nil
            end
            if dsDropdownPopup:IsShown() then
                dsDropdownPopup:Hide()
            end
        end
        if clickCatcher and clickCatcher:IsShown() and (not contextMenuFrame or not contextMenuFrame:IsShown()) and (not altDropdownFrame or not altDropdownFrame:IsShown()) then
            clickCatcher:Hide()
        end
    end

    function UI.CloseAllPopups()
        CloseDSDropdownPopup()
        CloseContextMenu()
        if CloseAltDropdown then CloseAltDropdown() end
        if f.zoneTabMenu and f.zoneTabMenu:IsShown() then f.zoneTabMenu:Hide() end
        if dsColorPicker and dsColorPicker:IsShown() then dsColorPicker:Hide() end
        if clickCatcher and clickCatcher:IsShown() then clickCatcher:Hide() end
        if _G.DynamicSuiteHudSelectorPopup and _G.DynamicSuiteHudSelectorPopup:IsShown() then
            _G.DynamicSuiteHudSelectorPopup:Hide()
        end
        if UI.RunRegisteredPopupClosers then
            UI.RunRegisteredPopupClosers()
        end
    end

    function UI.CreateDropdown(parent, width, optionsList, getValFn, setValFn)
        local btn = CreateFlatButton(parent, width or 240, 26, "", false); btn._lockFixedWidth = true
        btn.idleBgColor = { r = 0.078, g = 0.090, b = 0.122, a = 0.96 }
        btn.idleBorderColor = { r = 0.145, g = 0.165, b = 0.212, a = 0.95 }
        ApplyFlatButtonVisual(btn, false)
        btn.label:ClearAllPoints()
        btn.label:SetPoint("LEFT", btn, "LEFT", 10, 0)
        btn.label:SetPoint("RIGHT", btn, "RIGHT", -24, 0)
        btn.label:SetJustifyH("LEFT")
        btn.label:SetWordWrap(false)
        btn.chevron = UI.CreateChevronDown(btn, "RIGHT", btn, "RIGHT", -8, 0, 1, 1, 1, 0.75)

        function btn:SetOptions(newOpts)
            optionsList = newOpts or {}
            self:RefreshValue()
        end

        function btn:RefreshValue()
            local curVal = getValFn and getValFn()
            local displayTxt = tostring(curVal or "")
            local activeFontKey = nil
            for _, opt in ipairs(optionsList or {}) do
                if not opt.isHeader and not opt.isEmptyNotice and opt.value == curVal then
                    displayTxt = opt.label or tostring(opt.value)
                    activeFontKey = opt.fontKey
                    break
                end
            end
            -- Strip leading "1. ", "2. ", or "* " from closed dropdown button text
            displayTxt = displayTxt:gsub("^%d+%.%s*", ""):gsub("^%*%s*", "")
            btn.label:SetText(displayTxt)
            if activeFontKey then
                btn.label._fixedFontKey = activeFontKey
                pcall(ApplyFontToWidget, btn.label, true)
            end
        end

        btn:HookScript("OnHide", function(self)
            if dsDropdownPopup and dsDropdownPopup:IsShown() and dsDropdownPopup.ownerBtn == self then
                CloseDSDropdownPopup()
            end
        end)

        btn:SetScript("OnClick", function(self)
            if self._onBeforeOpen then self:_onBeforeOpen() end
            if dsDropdownPopup and dsDropdownPopup:IsShown() and dsDropdownPopup.ownerBtn == self then
                CloseDSDropdownPopup()
                return
            end
            CloseDSDropdownPopup()
            if not dsDropdownPopup then
                dsDropdownPopup = CreateFrame("Frame", "DynamicSuiteDropdownPopup", UIParent)
                dsDropdownPopup:SetFrameStrata("TOOLTIP")
                dsDropdownPopup:SetFrameLevel(250)
                dsDropdownPopup:SetToplevel(true)
                dsDropdownPopup:SetClampedToScreen(true)
                dsDropdownPopup:EnableMouse(true)
                dsDropdownPopup.bg = UI.SolidTex(dsDropdownPopup, "BACKGROUND", 0, 0.043, 0.051, 0.071, 0.99)
                dsDropdownPopup.bg:SetAllPoints()

                -- Live search bar shown when #optionsList > 12
                local searchWrap = CreateFrame("Frame", nil, dsDropdownPopup)
                searchWrap:SetFrameLevel(256)
                searchWrap:SetHeight(24)
                searchWrap:SetPoint("TOPLEFT", dsDropdownPopup, "TOPLEFT", 6, -5)
                searchWrap:SetPoint("TOPRIGHT", dsDropdownPopup, "TOPRIGHT", -6, -5)
                local swBg = UI.SolidTex(searchWrap, "BACKGROUND", 0, 0.035, 0.042, 0.060, 0.98)
                swBg:SetAllPoints()
                UI.CreatePixelBorder(searchWrap, 1, 1, 1, 0.14, 1)
                dsDropdownPopup.searchWrap = searchWrap

                local sb = CreateFrame("EditBox", nil, searchWrap)
                sb:SetFrameLevel(257)
                sb:SetPoint("TOPLEFT", searchWrap, "TOPLEFT", 8, -2)
                sb:SetPoint("BOTTOMRIGHT", searchWrap, "BOTTOMRIGHT", -24, 2)
                sb:SetAutoFocus(false)
                sb:SetMaxLetters(64)
                UI.SetFont(sb, 11, "", 0.95, 0.97, 1.0, 1.0)
                dsDropdownPopup.searchBox = sb

                local ph = searchWrap:CreateFontString(nil, "OVERLAY")
                ph:SetPoint("LEFT", sb, "LEFT", 0, 0)
                UI.SetFont(ph, 11, "", 0.48, 0.54, 0.64, 0.90)
                ph:SetText("Search...")
                dsDropdownPopup.searchPlaceholder = ph

                local clrBtn = CreateFrame("Button", nil, searchWrap)
                clrBtn:SetSize(18, 18)
                clrBtn:SetPoint("RIGHT", searchWrap, "RIGHT", -3, 0)
                clrBtn:SetFrameLevel(258)
                local clrTxt = clrBtn:CreateFontString(nil, "OVERLAY")
                clrTxt:SetPoint("CENTER", 0, 0)
                UI.SetFont(clrTxt, 10, "", 0.62, 0.68, 0.78, 0.95)
                clrTxt:SetText("X")
                clrBtn.txt = clrTxt
                clrBtn:Hide()
                clrBtn:SetScript("OnEnter", function(cb)
                    local ca, cg, cbl = UI.GetActiveAccentColor()
                    cb.txt:SetTextColor(ca, cg, cbl, 1.0)
                end)
                clrBtn:SetScript("OnLeave", function(cb)
                    cb.txt:SetTextColor(0.62, 0.68, 0.78, 0.95)
                end)
                clrBtn:SetScript("OnClick", function()
                    sb:SetText("")
                    sb:ClearFocus()
                end)
                dsDropdownPopup.searchClear = clrBtn

                sb:SetScript("OnEscapePressed", function()
                    CloseDSDropdownPopup()
                end)

                local sf = CreateFrame("ScrollFrame", nil, dsDropdownPopup)
                sf:SetFrameLevel(252)
                sf:SetPoint("TOPLEFT", dsDropdownPopup, "TOPLEFT", 2, -4)
                sf:SetPoint("BOTTOMRIGHT", dsDropdownPopup, "BOTTOMRIGHT", -10, 4)
                sf:SetClipsChildren(true)
                sf:EnableMouseWheel(true)
                dsDropdownPopup.scrollFrame = sf

                local sc = CreateFrame("Frame", nil, sf)
                sc:SetFrameLevel(253)
                sc:SetSize(240, 100)
                sf:SetScrollChild(sc)
                dsDropdownPopup.scrollChild = sc

                local sbTrack = CreateFrame("Frame", nil, dsDropdownPopup)
                sbTrack:SetFrameLevel(261)
                sbTrack:SetWidth(4)
                sbTrack:SetPoint("TOPRIGHT", dsDropdownPopup, "TOPRIGHT", -3, -4)
                sbTrack:SetPoint("BOTTOMRIGHT", dsDropdownPopup, "BOTTOMRIGHT", -3, 4)
                sbTrack:EnableMouse(true)
                sbTrack:SetHitRectInsets(-5, -5, 0, 0)
                sbTrack.bg = UI.SolidTex(sbTrack, "ARTWORK", 1, 1, 1, 1, 0.06)
                sbTrack.bg:SetAllPoints()
                dsDropdownPopup.sbTrack = sbTrack

                local sbThumb = CreateFrame("Button", nil, sbTrack)
                sbThumb:SetFrameLevel(262)
                sbThumb:SetSize(4, 32)
                sbThumb:SetPoint("TOP", sbTrack, "TOP", 0, 0)
                sbThumb:EnableMouse(true)
                sbThumb:SetHitRectInsets(-5, -5, 0, 0)
                sbThumb.tex = UI.SolidTex(sbThumb, "OVERLAY", 2, 0.38, 0.45, 0.56, 0.85)
                sbThumb.tex:SetAllPoints()
                function sbThumb:SetColorTexture(r, g, b, a)
                    self.tex:SetColorTexture(r, g, b, a)
                end
                dsDropdownPopup.sbThumb = sbThumb

                -- High-level border frame drawn on top of ScrollFrame & itemBtns so bottom border never clips
                local borderOverlay = CreateFrame("Frame", nil, dsDropdownPopup)
                borderOverlay:SetAllPoints(dsDropdownPopup)
                borderOverlay:SetFrameLevel(260)
                UI.CreatePixelBorder(borderOverlay, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.90, 7)
                dsDropdownPopup.dsBorder = borderOverlay.dsBorder
                dsDropdownPopup.borderOverlay = borderOverlay

                local function UpdateDropdownScrollbar()
                    local viewH = sf:GetHeight() or 0
                    local totalH = sc:GetHeight() or 0
                    local maxScroll = math.max(0, totalH - viewH)
                    if maxScroll <= 1 then
                        sbTrack:Hide()
                        sbThumb:Hide()
                        sf:SetVerticalScroll(0)
                        return
                    end
                    sbTrack:Show()
                    sbThumb:Show()
                    local trackH = sbTrack:GetHeight() or viewH
                    if trackH < 16 then trackH = viewH end
                    local ratio = math.max(0.12, math.min(1, viewH / math.max(1, totalH)))
                    local thumbH = math.max(18, math.floor(trackH * ratio + 0.5))
                    sbThumb:SetSize(4, thumbH)
                    local cur = math.max(0, math.min(maxScroll, sf:GetVerticalScroll() or 0))
                    local travel = math.max(1, trackH - thumbH)
                    sbThumb:ClearAllPoints()
                    sbThumb:SetPoint("TOP", sbTrack, "TOP", 0, -(cur / maxScroll) * travel)
                    if not sbThumb.isDragging then
                        if sbThumb.isHovered then
                            local cr, cg, cb = UI.GetActiveAccentColor()
                            sbThumb.tex:SetColorTexture(cr, cg, cb, 0.92)
                        else
                            sbThumb.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
                        end
                    end
                end
                dsDropdownPopup.UpdateDropdownScrollbar = UpdateDropdownScrollbar

                local function ScrollDropdownFromCursor()
                    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                        sbThumb.isDragging = false
                        sbThumb:SetScript("OnUpdate", nil)
                        sbTrack:SetScript("OnUpdate", nil)
                        if sbThumb.isHovered then
                            local cr, cg, cb = UI.GetActiveAccentColor()
                            sbThumb.tex:SetColorTexture(cr, cg, cb, 0.92)
                        else
                            sbThumb.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
                        end
                        return
                    end
                    local viewH = sf:GetHeight() or 0
                    local totalH = sc:GetHeight() or 0
                    local maxScroll = math.max(0, totalH - viewH)
                    if maxScroll <= 0 then return end

                    local eff = sbTrack:GetEffectiveScale() or 1
                    local _, cy = GetCursorPosition()
                    cy = cy / eff
                    local top = sbTrack:GetTop()
                    local bottom = sbTrack:GetBottom()
                    if top and bottom and top > bottom then
                        local trackH = top - bottom
                        local thumbH = sbThumb:GetHeight() or 18
                        local usableH = math.max(1, trackH - thumbH)
                        local offsetFromTop = (top - cy) - (thumbH * 0.5)
                        local ratio = math.max(0, math.min(1, offsetFromTop / usableH))
                        sf:SetVerticalScroll(ratio * maxScroll)
                        UpdateDropdownScrollbar()
                    end
                end

                local function ScrollDropdownByDelta(delta)
                    local maxScroll = math.max(0, sc:GetHeight() - sf:GetHeight())
                    local nextVal = math.max(0, math.min(maxScroll, sf:GetVerticalScroll() - (delta * 26)))
                    sf:SetVerticalScroll(nextVal)
                    UpdateDropdownScrollbar()
                end

                sbThumb:SetScript("OnEnter", function(tSelf)
                    tSelf.isHovered = true
                    if not tSelf.isDragging then
                        local cr, cg, cb = UI.GetActiveAccentColor()
                        tSelf.tex:SetColorTexture(cr, cg, cb, 0.92)
                    end
                end)
                sbThumb:SetScript("OnLeave", function(tSelf)
                    tSelf.isHovered = false
                    if not tSelf.isDragging then
                        tSelf.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
                    end
                end)
                sbThumb:SetScript("OnMouseDown", function(tSelf, button)
                    if button == "LeftButton" then
                        tSelf.isDragging = true
                        local cr, cg, cb = UI.GetActiveAccentColor()
                        tSelf.tex:SetColorTexture(cr, cg, cb, 1.0)
                        ScrollDropdownFromCursor()
                        tSelf:SetScript("OnUpdate", ScrollDropdownFromCursor)
                    end
                end)
                sbThumb:SetScript("OnMouseUp", function(tSelf, button)
                    if button == "LeftButton" then
                        tSelf.isDragging = false
                        tSelf:SetScript("OnUpdate", nil)
                        if tSelf.isHovered then
                            local cr, cg, cb = UI.GetActiveAccentColor()
                            tSelf.tex:SetColorTexture(cr, cg, cb, 0.92)
                        else
                            tSelf.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
                        end
                    end
                end)
                sbThumb:SetScript("OnHide", function(tSelf)
                    tSelf.isDragging = false
                    tSelf.isHovered = false
                    tSelf:SetScript("OnUpdate", nil)
                    tSelf.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
                end)
                sbThumb:SetScript("OnMouseWheel", function(_, delta)
                    ScrollDropdownByDelta(delta)
                end)

                sbTrack:SetScript("OnMouseDown", function(trSelf, button)
                    if button == "LeftButton" then
                        sbThumb.isDragging = true
                        local cr, cg, cb = UI.GetActiveAccentColor()
                        sbThumb.tex:SetColorTexture(cr, cg, cb, 1.0)
                        ScrollDropdownFromCursor()
                        trSelf:SetScript("OnUpdate", ScrollDropdownFromCursor)
                    end
                end)
                sbTrack:SetScript("OnMouseUp", function(trSelf, button)
                    if button == "LeftButton" then
                        sbThumb.isDragging = false
                        trSelf:SetScript("OnUpdate", nil)
                        sbThumb.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
                    end
                end)
                sbTrack:SetScript("OnHide", function(trSelf)
                    sbThumb.isDragging = false
                    trSelf:SetScript("OnUpdate", nil)
                    sbThumb.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
                end)
                sbTrack:SetScript("OnMouseWheel", function(_, delta)
                    ScrollDropdownByDelta(delta)
                end)

                sf:SetScript("OnMouseWheel", function(_, delta)
                    ScrollDropdownByDelta(delta)
                end)
                sf:SetScript("OnVerticalScroll", function()
                    UpdateDropdownScrollbar()
                end)
                sf:SetScript("OnScrollRangeChanged", function()
                    UpdateDropdownScrollbar()
                end)

                dsDropdownPopup:HookScript("OnHide", function(pSelf)
                    if pSelf.searchBox then pSelf.searchBox:ClearFocus() end
                    if pSelf.ownerBtn then
                        UI.SetChevronState(pSelf.ownerBtn, false)
                        pSelf.ownerBtn = nil
                    end
                    if clickCatcher and clickCatcher:IsShown() and (not contextMenuFrame or not contextMenuFrame:IsShown()) and (not altDropdownFrame or not altDropdownFrame:IsShown()) then
                        clickCatcher:Hide()
                    end
                end)
                table.insert(UISpecialFrames, "DynamicSuiteDropdownPopup")

                dsDropdownPopup.itemBtns = {}
            end

            local ar, ag, ab = UI.GetActiveAccentColor()
            if dsDropdownPopup.borderOverlay then
                dsDropdownPopup.borderOverlay:SetFrameLevel(260)
            end
            dsDropdownPopup.dsBorder:SetColor(ar, ag, ab, 0.90)
            dsDropdownPopup.sbThumb:SetColorTexture(0.38, 0.45, 0.56, 0.85)
            dsDropdownPopup.ownerBtn = self
            UI.SetChevronState(self, true)

            local rawOpts = optionsList or {}
            local showSearch = (#rawOpts > 12)
            local searchAreaH = showSearch and 28 or 0
            local pad = 4
            local maxVisibleH = 264

            dsDropdownPopup.searchWrap:SetShown(showSearch)
            if dsDropdownPopup.searchWrap.dsBorder then
                dsDropdownPopup.searchWrap.dsBorder:SetColor(ar, ag, ab, 0.35)
            end

            local maxTextW = 0
            for _, probeOpt in ipairs(rawOpts) do
                if not probeOpt.isHeader and not probeOpt.isEmptyNotice then
                    local cleanL = tostring(probeOpt.label or probeOpt.value or ""):gsub("^%d+%.%s*", ""):gsub("^%*%s*", "")
                    maxTextW = math.max(maxTextW, #cleanL * 6.8)
                end
            end

            local function RenderDropdownRows(query)
                local qLower = tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
                if dsDropdownPopup.searchPlaceholder then
                    dsDropdownPopup.searchPlaceholder:SetShown(qLower == "" and not dsDropdownPopup.searchBox:HasFocus())
                end
                if dsDropdownPopup.searchClear then
                    dsDropdownPopup.searchClear:SetShown(qLower ~= "")
                end

                local filtered = {}
                if qLower == "" then
                    filtered = rawOpts
                else
                    local pendingHeader = nil
                    for _, opt in ipairs(rawOpts) do
                        if opt.isHeader then
                            pendingHeader = opt
                        elseif not opt.isEmptyNotice then
                            local cleanL = tostring(opt.label or opt.value or ""):gsub("^%d+%.%s*", ""):gsub("^%*%s*", "")
                            local valStr = tostring(opt.value or "")
                            if cleanL:lower():find(qLower, 1, true) or valStr:lower():find(qLower, 1, true) then
                                if pendingHeader then
                                    table.insert(filtered, pendingHeader)
                                    pendingHeader = nil
                                end
                                table.insert(filtered, opt)
                            end
                        end
                    end
                    if #filtered == 0 then
                        table.insert(filtered, { isEmptyNotice = true, label = "No matching options" })
                    end
                end

                local curVal = getValFn and getValFn()
                local yOff = 0
                local count = #filtered
                for i = 1, math.max(count, #dsDropdownPopup.itemBtns) do
                    local itemBtn = dsDropdownPopup.itemBtns[i]
                    local opt = filtered[i]
                    if opt then
                        if not itemBtn then
                            itemBtn = CreateFrame("Button", nil, dsDropdownPopup.scrollChild)
                            itemBtn:SetFrameLevel(255)
                            itemBtn:RegisterForClicks("LeftButtonUp")
                            itemBtn.bg = UI.SolidTex(itemBtn, "BACKGROUND", 1, 1, 1, 1, 0)
                            itemBtn.bg:SetAllPoints()

                            itemBtn.hdrLine = UI.SolidTex(itemBtn, "ARTWORK", 1, 1, 1, 1, 0.35)
                            itemBtn.hdrLine:SetHeight(1)
                            itemBtn.hdrLine:SetPoint("BOTTOMLEFT", itemBtn, "BOTTOMLEFT", 6, 1)
                            itemBtn.hdrLine:SetPoint("BOTTOMRIGHT", itemBtn, "BOTTOMRIGHT", -6, 1)
                            itemBtn.hdrLine:Hide()

                            itemBtn.checkIcon = itemBtn:CreateTexture(nil, "OVERLAY")
                            itemBtn.checkIcon:SetSize(10, 10)
                            itemBtn.checkIcon:SetPoint("LEFT", itemBtn, "LEFT", 8, 0)
                            itemBtn.checkIcon:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_check.tga")

                            itemBtn.lbl = itemBtn:CreateFontString(nil, "OVERLAY")
                            itemBtn.lbl:SetPoint("LEFT", itemBtn, "LEFT", 24, 0)
                            itemBtn.lbl:SetPoint("RIGHT", itemBtn, "RIGHT", -8, 0)
                            itemBtn.lbl:SetJustifyH("LEFT")
                            itemBtn.lbl:SetWordWrap(false)
                            UI.SetFont(itemBtn.lbl, 11, "", 1, 1, 1, 0.95)
                            dsDropdownPopup.itemBtns[i] = itemBtn
                        end

                        local rowH = opt.isHeader and 20 or 24
                        itemBtn:SetHeight(rowH)
                        itemBtn:SetFrameLevel(255)
                        itemBtn:ClearAllPoints()
                        itemBtn:SetPoint("TOPLEFT", dsDropdownPopup.scrollChild, "TOPLEFT", 0, -yOff)
                        itemBtn:SetPoint("TOPRIGHT", dsDropdownPopup.scrollChild, "TOPRIGHT", 0, -yOff)
                        yOff = yOff + rowH

                        if opt.isHeader then
                            itemBtn:Disable()
                            itemBtn.checkIcon:Hide()
                            itemBtn.hdrLine:Show()
                            itemBtn.hdrLine:SetColorTexture(ar, ag, ab, 0.42)
                            itemBtn.bg:SetColorTexture(0.082, 0.098, 0.137, 0.85)
                            itemBtn.lbl:ClearAllPoints()
                            itemBtn.lbl:SetPoint("LEFT", itemBtn, "LEFT", 8, 0)
                            itemBtn.lbl:SetPoint("RIGHT", itemBtn, "RIGHT", -8, 0)
                            itemBtn.lbl._fixedFontKey = nil
                            pcall(UI.SetFont, itemBtn.lbl, 10, "", ar, ag, ab, 0.95)
                            itemBtn.lbl:SetText(tostring(opt.label or ""):upper())
                            itemBtn:SetScript("OnEnter", nil)
                            itemBtn:SetScript("OnLeave", nil)
                            itemBtn:SetScript("OnClick", nil)
                        elseif opt.isEmptyNotice then
                            itemBtn:Disable()
                            itemBtn.checkIcon:Hide()
                            itemBtn.hdrLine:Hide()
                            itemBtn.bg:SetColorTexture(1, 1, 1, 0)
                            itemBtn.lbl:ClearAllPoints()
                            itemBtn.lbl:SetPoint("LEFT", itemBtn, "LEFT", 12, 0)
                            itemBtn.lbl:SetPoint("RIGHT", itemBtn, "RIGHT", -8, 0)
                            itemBtn.lbl._fixedFontKey = nil
                            pcall(UI.SetFont, itemBtn.lbl, 11, "", 0.55, 0.60, 0.70, 0.90)
                            itemBtn.lbl:SetText(tostring(opt.label or "No matching options"))
                            itemBtn:SetScript("OnEnter", nil)
                            itemBtn:SetScript("OnLeave", nil)
                            itemBtn:SetScript("OnClick", nil)
                        else
                            itemBtn:Enable()
                            itemBtn.hdrLine:Hide()
                            itemBtn.lbl:ClearAllPoints()
                            itemBtn.lbl:SetPoint("LEFT", itemBtn, "LEFT", 24, 0)
                            itemBtn.lbl:SetPoint("RIGHT", itemBtn, "RIGHT", -8, 0)

                            local isSel = (opt.value == curVal)
                            itemBtn.lbl._fixedFontKey = opt.fontKey
                            itemBtn.lbl._dsFontSize = 11
                            itemBtn.lbl._dsBaseFontSize = 11
                            pcall(ApplyFontToWidget, itemBtn.lbl, true)
                            if not itemBtn.lbl:GetFont() then
                                pcall(itemBtn.lbl.SetFont, itemBtn.lbl, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
                            end
                            local cleanOptLabel = tostring(opt.label or opt.value or ""):gsub("^%d+%.%s*", ""):gsub("^%*%s*", "")
                            itemBtn.lbl:SetText(cleanOptLabel)
                            local strW = (itemBtn.lbl.GetUnboundedStringWidth and itemBtn.lbl:GetUnboundedStringWidth()) or itemBtn.lbl:GetStringWidth() or (#cleanOptLabel * 7)
                            if strW > maxTextW then maxTextW = strW end

                            itemBtn.checkIcon:SetShown(isSel)
                            itemBtn.checkIcon:SetVertexColor(ar, ag, ab, 1.0)
                            if isSel then
                                itemBtn.bg:SetColorTexture(ar, ag, ab, 0.22)
                                itemBtn.lbl:SetTextColor(1, 1, 1, 1)
                            else
                                itemBtn.bg:SetColorTexture(1, 1, 1, 0)
                                itemBtn.lbl:SetTextColor(0.88, 0.90, 0.95, 1)
                            end
                            itemBtn:SetScript("OnEnter", function(ib)
                                ib.bg:SetColorTexture(ar, ag, ab, isSel and 0.30 or 0.16)
                                ib.lbl:SetTextColor(1, 1, 1, 1)
                            end)
                            itemBtn:SetScript("OnLeave", function(ib)
                                ib.bg:SetColorTexture(ar, ag, ab, isSel and 0.22 or 0)
                                ib.lbl:SetTextColor(isSel and 1 or 0.88, isSel and 1 or 0.90, isSel and 1 or 0.95, 1)
                            end)
                            itemBtn:SetScript("OnClick", function()
                                CloseDSDropdownPopup()
                                if setValFn then setValFn(opt.value) end
                                self:RefreshValue()
                            end)
                        end
                        itemBtn:Show()
                    elseif itemBtn then
                        itemBtn:Hide()
                    end
                end

                local totalH = math.max(24, yOff)
                local viewH = math.min(totalH, maxVisibleH)
                local hasScroll = (totalH > viewH + 1)
                local popW = math.max(self:GetWidth(), math.ceil(maxTextW + 52), 250)
                local popH = searchAreaH + viewH + (2 * pad)
                dsDropdownPopup:SetSize(popW, popH)

                local topScrollOffset = pad + searchAreaH
                dsDropdownPopup.scrollFrame:ClearAllPoints()
                dsDropdownPopup.scrollFrame:SetPoint("TOPLEFT", dsDropdownPopup, "TOPLEFT", 2, -topScrollOffset)
                dsDropdownPopup.scrollFrame:SetPoint("BOTTOMRIGHT", dsDropdownPopup, "BOTTOMRIGHT", hasScroll and -10 or -2, pad)
                dsDropdownPopup.scrollChild:SetSize(popW - (hasScroll and 12 or 4), totalH)
                dsDropdownPopup.scrollFrame:SetVerticalScroll(0)

                dsDropdownPopup.sbTrack:ClearAllPoints()
                dsDropdownPopup.sbTrack:SetPoint("TOPRIGHT", dsDropdownPopup, "TOPRIGHT", -3, -topScrollOffset)
                dsDropdownPopup.sbTrack:SetPoint("BOTTOMRIGHT", dsDropdownPopup, "BOTTOMRIGHT", -3, pad)
                dsDropdownPopup.sbTrack:SetShown(hasScroll)
                dsDropdownPopup.sbThumb:SetShown(hasScroll)
                if dsDropdownPopup.UpdateDropdownScrollbar then
                    dsDropdownPopup.UpdateDropdownScrollbar()
                end
            end

            dsDropdownPopup.searchBox:SetScript("OnTextChanged", function(sbEdit)
                if dsDropdownPopup:IsShown() and dsDropdownPopup.ownerBtn == self then
                    RenderDropdownRows(sbEdit:GetText())
                end
            end)
            dsDropdownPopup.searchBox:SetScript("OnEditFocusGained", function()
                if dsDropdownPopup.searchPlaceholder then
                    dsDropdownPopup.searchPlaceholder:Hide()
                end
            end)
            dsDropdownPopup.searchBox:SetScript("OnEditFocusLost", function(sbEdit)
                if dsDropdownPopup.searchPlaceholder then
                    dsDropdownPopup.searchPlaceholder:SetShown((sbEdit:GetText() or "") == "")
                end
            end)

            dsDropdownPopup.searchBox:SetText("")
            dsDropdownPopup.searchBox:ClearFocus()
            RenderDropdownRows("")

            local catcher = GetClickCatcher()
            catcher:SetFrameStrata("FULLSCREEN_DIALOG")
            catcher:SetFrameLevel(100)
            catcher:SetScript("OnClick", function()
                CloseDSDropdownPopup()
                CloseContextMenu()
            end)
            catcher:Show()

            dsDropdownPopup:SetFrameStrata("TOOLTIP")
            dsDropdownPopup:SetFrameLevel(250)
            dsDropdownPopup:ClearAllPoints()
            dsDropdownPopup:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -2)
            dsDropdownPopup:Show()
            dsDropdownPopup:Raise()
        end)

        btn:RefreshValue()
        return btn
    end



    -- Reusable Inline Sub-Drawer for Peer Modules (#0A0D13 recessed panel + 2px Suite Accent left border + 5x5 Accent Pip)
    function UI.CreateInlineSubDrawer(parent, anchorRow, height)
        local drawer = CreateFrame("Frame", nil, parent)
        drawer:SetHeight(height or 54)
        if anchorRow then
            drawer:SetPoint("TOPLEFT", anchorRow, "BOTTOMLEFT", 14, -3)
            drawer:SetPoint("TOPRIGHT", anchorRow, "BOTTOMRIGHT", 0, -3)
        end
        drawer.bg = UI.SolidTex(drawer, "BACKGROUND", 0, 0.039, 0.051, 0.075, 0.96)
        drawer.bg:SetAllPoints()
        UI.CreatePixelBorder(drawer, 0.145, 0.165, 0.212, 0.85, 2)
        local ar, ag, ab = UI.GetActiveAccentColor()
        drawer.leftAccent = UI.SolidTex(drawer, "OVERLAY", 3, ar, ag, ab, 1.0)
        drawer.leftAccent:SetWidth(2)
        drawer.leftAccent:SetPoint("TOPLEFT", drawer, "TOPLEFT", 0, 0)
        drawer.leftAccent:SetPoint("BOTTOMLEFT", drawer, "BOTTOMLEFT", 0, 0)

        -- Clean 5x5 Suite Accent Pip (replaces any legacy ASCII "|- " or "'- " prefix)
        drawer.pip = UI.SolidTex(drawer, "OVERLAY", 3, ar, ag, ab, 0.95)
        drawer.pip:SetSize(5, 5)
        drawer.pip:SetPoint("LEFT", drawer, "LEFT", 12, 0)

        function drawer:SetSubRowTitle(fontString, rawText)
            if not fontString then return end
            local clean = tostring(rawText or ""):gsub("^%s*[|'%-]+%s*", ""):gsub("^|%-+%s*", ""):gsub("^'%-+%s*", "")
            fontString:SetText(clean)
        end

        function drawer:RefreshAccent()
            local r, g, b = UI.GetActiveAccentColor()
            self.leftAccent:SetColorTexture(r, g, b, 1.0)
            if self.pip then
                self.pip:SetColorTexture(r, g, b, 0.95)
            end
        end
        return drawer
    end

    -- Standardized Icon-Only [ Cog v ] / [ Cog ^ ] (32px x 26px) Sub-Drawer Toggle Button
    -- Strictly square 14x14 Cog Texture + 3px gap + crisp 10x10 Chevron Texture centered as a 27px pair (offset -13.5)
    function UI.CreateSubDrawerButton(parent, onToggle)
        local ar, ag, ab = UI.GetActiveAccentColor()
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(26, 26)
        btn.bg = UI.SolidTex(btn, "BACKGROUND", 0, 0.08, 0.10, 0.14, 0.95)
        btn.bg:SetAllPoints()
        UI.CreatePixelBorder(btn, 1, 1, 1, 0.15, 2)

        local cogTex = btn:CreateTexture(nil, "ARTWORK", nil, 3)
        cogTex:SetSize(1, 1)
        cogTex:Hide()
        btn.cogTex = cogTex
        btn.Cog = cogTex

        local chevTex = btn:CreateTexture(nil, "OVERLAY", nil, 4)
        chevTex:SetSize(12, 12)
        chevTex:SetPoint("CENTER", btn, "CENTER", 0, 0)
        chevTex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga")
        chevTex:SetTexCoord(0, 1, 0, 1)
        UI.DisablePixelSnap(chevTex)
        chevTex:SetVertexColor(ar, ag, ab, 0.92)
        chevTex.SetText = function(self, txt)
            local isUp = (txt == "^")
            self:SetTexture(isUp and "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga" or "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga")
        end
        chevTex.SetTextColor = function(self, r, g, b, a)
            self:SetVertexColor(r, g, b, a or 1.0)
        end
        btn.chevTex = chevTex
        btn.chevronTex = chevTex
        btn.chev = chevTex
        btn.Chevron = chevTex

        btn._isExpanded = false
        function btn:SetExpanded(expanded)
            self._isExpanded = (expanded == true)
            local r, g, b = UI.GetActiveAccentColor()
            if self._isExpanded then
                self.bg:SetColorTexture(r, g, b, 0.22)
                self.dsBorder:SetColor(r, g, b, 0.90)
                self.cogTex:SetVertexColor(r, g, b, 1.0)
                self.chevTex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga")
                self.chevTex:SetVertexColor(r, g, b, 1.0)
            else
                self.bg:SetColorTexture(0.08, 0.10, 0.14, 0.95)
                self.dsBorder:SetColor(1, 1, 1, 0.15)
                self.cogTex:SetVertexColor(r, g, b, 0.92)
                self.chevTex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga")
                self.chevTex:SetVertexColor(r, g, b, 0.92)
            end
        end
        btn.SetOpen = btn.SetExpanded
        function btn:RefreshAccent()
            self:SetExpanded(self._isExpanded)
        end

        btn:SetScript("OnEnter", function(self)
            local r, g, b = UI.GetActiveAccentColor()
            self.dsBorder:SetColor(r, g, b, 1.0)
            self.cogTex:SetVertexColor(1, 1, 1, 1.0)
            self.chevTex:SetVertexColor(1, 1, 1, 1.0)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(self.tooltipTitle or "Advanced Options", 1, 1, 1)
                if self.tooltipBody and self.tooltipBody ~= "" then
                    GameTooltip:AddLine(self.tooltipBody, 0.78, 0.82, 0.88, true)
                end
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if GameTooltip then GameTooltip:Hide() end
            self:SetExpanded(self._isExpanded)
        end)
        btn:SetScript("OnClick", function(self)
            self:SetExpanded(not self._isExpanded)
            if type(onToggle) == "function" then
                onToggle(self._isExpanded)
            end
        end)
        return btn
    end
    UI.CreateSubDrawerTuneButton = UI.CreateSubDrawerButton

    -- Normalize any peer module sub-drawer buttons (strictly icon-only 32x26, square 14x14 cog icon, no 'Tune' text) & sub-drawer rails
    function UI.NormalizeEmbeddedSubDrawers(rootFrame)
        if not rootFrame or not rootFrame.GetChildren then return end
        local ar, ag, ab = UI.GetActiveAccentColor()
        local function Traverse(frame, depth)
            if not frame or depth > 6 then return end
            if frame.GetObjectType and frame:GetObjectType() == "Button" then
                local w, h = frame:GetWidth() or 0, frame:GetHeight() or 0
                if w >= 24 and w <= 76 and h >= 20 and h <= 32 then
                    local hasCog = false
                    for rIdx = 1, select("#", frame:GetRegions()) do
                        local reg = select(rIdx, frame:GetRegions())
                        if reg and reg.GetObjectType and reg:GetObjectType() == "Texture" then
                            local texPath = tostring(reg:GetTexture() or ""):lower()
                            if texPath:find("cog") or texPath:find("gear") then
                                hasCog = true
                                reg:Hide()
                                reg:SetAlpha(0)
                            elseif texPath:find("chevron") then
                                reg:ClearAllPoints()
                                reg:SetPoint("CENTER", frame, "CENTER", 0, 0)
                                reg:SetSize(12, 12)
                                reg:SetTexCoord(0, 1, 0, 1)
                                UI.DisablePixelSnap(reg)
                            end
                        end
                    end
                    if hasCog then
                        frame:SetSize(26, 26)
                        for rIdx = 1, select("#", frame:GetRegions()) do
                            local reg = select(rIdx, frame:GetRegions())
                            if reg and reg.GetObjectType and reg:GetObjectType() == "FontString" then
                                local txt = tostring(reg:GetText() or "")
                                if txt:lower():find("tune") then
                                    reg:SetText("")
                                    reg:Hide()
                                end
                            end
                        end
                    end
                end
            end
            -- Fix any FontString starting with ASCII branch prefix ("|- ", "'- ", "+- ") inside a sub-drawer
            if frame.GetRegions then
                for rIdx = 1, select("#", frame:GetRegions()) do
                    local reg = select(rIdx, frame:GetRegions())
                    if reg and reg.GetObjectType and reg:GetObjectType() == "FontString" then
                        local txt = reg:GetText()
                        if type(txt) == "string" and (txt:find("^%s*|%-") or txt:find("^%s*'%-") or txt:find("^%s*%+%-")) then
                            local clean = txt:gsub("^%s*[|'%+]+%-+%s*", "")
                            reg:SetText(clean)
                            if not frame._dsSubPip then
                                local pip = UI.SolidTex(frame, "OVERLAY", 3, ar, ag, ab, 0.95)
                                pip:SetSize(5, 5)
                                pip:SetPoint("RIGHT", reg, "LEFT", -6, 0)
                                frame._dsSubPip = pip
                            else
                                frame._dsSubPip:SetColorTexture(ar, ag, ab, 0.95)
                            end
                            if not frame._dsLeftRail then
                                local rail = UI.SolidTex(frame, "OVERLAY", 3, ar, ag, ab, 1.0)
                                rail:SetWidth(2)
                                rail:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
                                rail:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
                                frame._dsLeftRail = rail
                            else
                                frame._dsLeftRail:SetColorTexture(ar, ag, ab, 1.0)
                            end
                        end
                    end
                end
            end
            if frame.RefreshAccent then
                pcall(frame.RefreshAccent, frame)
            end
            if frame.GetChildren then
                for cIdx = 1, select("#", frame:GetChildren()) do
                    local child = select(cIdx, frame:GetChildren())
                    if child then
                        Traverse(child, depth + 1)
                    end
                end
            end
        end
        Traverse(rootFrame, 1)
    end

    if _G.DynamicSuite then
        _G.DynamicSuite.UI = _G.DynamicSuite.UI or UI
        _G.DynamicSuite.UI.CreateDropdown = UI.CreateDropdown
        _G.DynamicSuite.UI.CreateSegmentedPills = UI.CreateSegmentedPills
        _G.DynamicSuite.UI.CreateInlineSubDrawer = UI.CreateInlineSubDrawer
        _G.DynamicSuite.UI.CreateSubDrawerButton = UI.CreateSubDrawerButton
        _G.DynamicSuite.UI.CreateSubDrawerTuneButton = UI.CreateSubDrawerButton
        _G.DynamicSuite.UI.NormalizeEmbeddedSubDrawers = UI.NormalizeEmbeddedSubDrawers
        _G.DynamicSuite.UI.RegisterPopupCloser = UI.RegisterPopupCloser
        _G.DynamicSuite.UI.CloseAllPopups = UI.CloseAllPopups
        _G.DynamicSuite.RegisterPopupCloser = UI.RegisterPopupCloser
        _G.DynamicSuite.GetSuiteAccent = function()
            return UI.GetActiveAccentColor()
        end
    end
    end

    -- Helper: Detect Installed External UI Suite (EllesmereUI / ElvUI / LibSharedMedia-3.0) for Item #39
    local function DetectExternalUISuite()
        if _G.EllesmereUI or _G.EllesmereUIDB or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("EllesmereUI")) then
            return "EllesmereUI"
        elseif _G.ElvUI or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ElvUI")) then
            return "ElvUI"
        elseif _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true) then
            return "SharedMedia UI"
        end
        return nil
    end

    local function ApplyExternalUISync()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        if not gTbl or not gTbl.syncExternalUI then return end
        if gTbl.accentKey ~= "CUSTOM" then
            gTbl._preSyncAccentKey = gTbl.accentKey
        end
        gTbl._preSyncCustomAccent = gTbl.customAccent
        if gTbl.fontKey and gTbl.fontKey ~= "EXTERNAL_UI" then
            gTbl._preSyncFontKey = gTbl.fontKey
        elseif not gTbl._preSyncFontKey then
            gTbl._preSyncFontKey = gTbl.fontFamily or "EXPRESSWAY"
        end

        local r, g, b
        if _G.EllesmereUI and type(_G.EllesmereUI.ResolveProfileAccent) == "function" then
            local pData = (_G.EllesmereUI.GetActiveProfileData and _G.EllesmereUI.GetActiveProfileData())
            local _, ar, ag, ab = _G.EllesmereUI.ResolveProfileAccent(pData)
            r, g, b = ar, ag, ab
        end
        if (not r) and _G.EllesmereUI and type(_G.EllesmereUI.GetAccentColor) == "function" then
            r, g, b = _G.EllesmereUI.GetAccentColor()
        end
        if (not r) and _G.EllesmereUI and type(_G.EllesmereUI.ResolveThemeColor) == "function" then
            local theme = (_G.EllesmereUI.GetActiveTheme and _G.EllesmereUI.GetActiveTheme()) or "Class Colored"
            r, g, b = _G.EllesmereUI.ResolveThemeColor(theme)
        end
        if (not r) and type(_G.EllesmereUIDB) == "table" and _G.EllesmereUIDB.accentColor then
            local c = _G.EllesmereUIDB.accentColor
            r, g, b = c.r, c.g, c.b
        end
        if (not r) and _G.ELLESMERE_GREEN then
            r, g, b = _G.ELLESMERE_GREEN.r, _G.ELLESMERE_GREEN.g, _G.ELLESMERE_GREEN.b
        end
        if (not r) and _G.ElvUI and type(_G.ElvUI) == "table" and _G.ElvUI[1] then
            local E = _G.ElvUI[1]
            if E.media and E.media.rgbvaluecolor then
                local c = E.media.rgbvaluecolor
                if c.r and c.g and c.b then
                    r, g, b = c.r, c.g, c.b
                end
            end
        end
        if r and g and b then
            gTbl.accentKey = "CUSTOM"
            gTbl.customAccent = { r = r, g = g, b = b }
            if DynamicLoadDB then
                DynamicLoadDB.accentKey = "CUSTOM"
                DynamicLoadDB.customAccent = { r = r, g = g, b = b }
            end
        end

        local eFontPath, eFontName
        if _G.EllesmereUI and type(_G.EllesmereUI.GetFontPath) == "function" then
            local ok, res = pcall(_G.EllesmereUI.GetFontPath)
            if ok and type(res) == "string" and res ~= "" then eFontPath = res end
        end
        if _G.EllesmereUI and type(_G.EllesmereUI.GetFontName) == "function" then
            local ok, res = pcall(_G.EllesmereUI.GetFontName)
            if ok and type(res) == "string" and res ~= "" then eFontName = res end
        end
        if (not eFontName) and _G.EllesmereUI and type(_G.EllesmereUI.GetFontsDB) == "function" then
            local ok, fdb = pcall(_G.EllesmereUI.GetFontsDB)
            if ok and type(fdb) == "table" and type(fdb.global) == "string" then
                eFontName = fdb.global
            end
        elseif (not eFontName) and type(_G.EllesmereUIDB) == "table" and _G.EllesmereUIDB.fonts then
            eFontName = _G.EllesmereUIDB.fonts.global
        end
        if (not eFontPath) and eFontName then
            local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
            if LSM and LSM.Fetch then
                local ok, fetched = pcall(LSM.Fetch, LSM, "font", eFontName, true)
                if ok and type(fetched) == "string" and fetched ~= "" then
                    eFontPath = fetched
                end
            end
        end

        local matchedFont = nil
        if eFontName and type(eFontName) == "string" then
            for fKey, fDef in pairs(UI.FONT_FAMILIES or {}) do
                if fKey ~= "EXTERNAL_UI" and (fDef.name == eFontName or fKey == eFontName or string.find(string.lower(fDef.name), string.lower(eFontName), 1, true)) then
                    matchedFont = fKey
                    break
                end
            end
        end
        if not matchedFont and eFontPath and type(eFontPath) == "string" then
            for fKey, fDef in pairs(UI.FONT_FAMILIES or {}) do
                if fKey ~= "EXTERNAL_UI" and fDef.path and string.lower(fDef.path) == string.lower(eFontPath) then
                    matchedFont = fKey
                    break
                end
            end
        end
        if eFontPath and type(eFontPath) == "string" and eFontPath ~= "" then
            if matchedFont and UI.FONT_FAMILIES[matchedFont] then
                resolvedFontPaths[matchedFont] = eFontPath
                UI.FONT_FAMILIES[matchedFont].resolvedPath = eFontPath
            else
                UI.FONT_FAMILIES["EXTERNAL_UI"] = {
                    name = eFontName or "External UI Font",
                    path = eFontPath,
                    candidates = { eFontPath, "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Fonts\\Expressway.TTF", "Fonts\\FRIZQT__.TTF" },
                    sizeScale = 1.00,
                    defaultFlags = "",
                    shadowOff = 1,
                    shadowAlpha = 0.55,
                    resolvedPath = eFontPath,
                }
                resolvedFontPaths["EXTERNAL_UI"] = eFontPath
                matchedFont = "EXTERNAL_UI"
            end
        end
        matchedFont = matchedFont or "EXPRESSWAY"
        gTbl.fontKey = matchedFont
        gTbl.fontFamily = matchedFont
        if DynamicLoadDB then
            DynamicLoadDB.fontKey = matchedFont
            DynamicLoadDB.fontFamily = matchedFont
        end

        UI.RefreshPaletteCache()
        if addonTable.ApplySuiteThemeAndGeometry then addonTable.ApplySuiteThemeAndGeometry() end
        if f.themeView and f.themeView.Refresh then f.themeView.Refresh() end
    end

    -- Card 2: Bordered Section Container for Surface, Typography & Visual Sync (6 Compact 48px Rows)
    local surfaceSectionCard = CreateFrame("Frame", nil, tvChild)
    surfaceSectionCard:SetPoint("TOPLEFT", swatchCard, "BOTTOMLEFT", 0, -10)
    surfaceSectionCard:SetPoint("TOPRIGHT", swatchCard, "BOTTOMRIGHT", 0, -10)
    surfaceSectionCard:SetHeight(379)
    surfaceSectionCard.bg = UI.SolidTex(surfaceSectionCard, "BACKGROUND", 0, 0.031, 0.039, 0.055, 0.72)
    surfaceSectionCard.bg:SetAllPoints()
    UI.CreatePixelBorder(surfaceSectionCard, 1, 1, 1, 0.08, 2)

    local surfSecHdr = UI.CreateSectionHeader(
        surfaceSectionCard,
        -10,
        "SURFACE, TYPOGRAPHY & VISUAL SYNC",
        "Select your backdrop surface, suite font family, and cross-character sync rules.",
        14
    )

    local function CreateThemeStudioRow(parentCard, rowTitle, rowDesc, anchorAbove, gapY)
        local row = CreateSpaciousOptionRow(parentCard, 1, rowTitle, rowDesc)
        row._titleTopY = -8
        row._subGapY = -2
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", anchorAbove, "BOTTOMLEFT", 0, gapY or -6)
        row:SetPoint("TOPRIGHT", anchorAbove, "BOTTOMRIGHT", 0, gapY or -6)
        row:SetHeight(48)
        row.titleText:ClearAllPoints()
        row.titleText:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -8)
        row.titleText:SetPoint("RIGHT", row, "RIGHT", -270, 0)
        row.descText:ClearAllPoints()
        row.descText:SetPoint("TOPLEFT", row.titleText, "BOTTOMLEFT", 0, -2)
        row.descText:SetPoint("RIGHT", row, "RIGHT", -270, 0)
        return row
    end

    -- Row 1: Window Surface Theme Dropdown (4 Surface Palettes per DESIGN_SYSTEM.md Section 1.1)
    local surfRow = CreateThemeStudioRow(surfaceSectionCard, "Window Surface Theme", "Select the Obsidian backdrop palette across all DynamicSuite windows.", surfSecHdr, -8)
    local surfDropdownOpts = {
        { value = "MIDNIGHT_BLACK", label = "Midnight Pitch Black (Default)" },
        { value = "OBSIDIAN_DARK",  label = "Obsidian Dark" },
        { value = "SLATE_STEEL",    label = "Slate Steel" },
        { value = "SMOKED_GLASS",   label = "Smoked Glass (Translucent)" },
    }
    local surfDropdown = UI.CreateDropdown(surfRow, 240, surfDropdownOpts,
        function() return UI.GetActiveSurfaceKey() end,
        function(val)
            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
            if gTbl then gTbl.surfaceTheme = val end
            if DynamicLoadDB then DynamicLoadDB.surfaceTheme = val end
            UI.RefreshPaletteCache()
            activeWorkspaceView = "THEME_STUDIO"
            if addonTable.ApplySuiteThemeAndGeometry then addonTable.ApplySuiteThemeAndGeometry() end
            if f.themeView then f.themeView:Show() end
            if themeView.Refresh then themeView.Refresh() end
        end
    )
    surfDropdown:SetPoint("RIGHT", surfRow, "RIGHT", -14, 0)
    surfRow:BindRightControl(surfDropdown)

    -- Row 2: Suite Font Family Dropdown (Complete 26-Font Library when EUI present + Bundled Fonts)
    local fontRow = CreateThemeStudioRow(surfaceSectionCard, "Suite Font Family", "Select the typography family applied across headers, lists, and HUD readouts.", surfRow, -5)
    local fontDropdownOpts = UI.BuildFontDropdownOptions()
    local fontDropdown = UI.CreateDropdown(fontRow, 240, fontDropdownOpts,
        function() return UI.GetActiveFontKey() end,
        function(val)
            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
            if gTbl then
                gTbl.fontKey = val
                gTbl.fontFamily = val
            end
            if DynamicLoadDB then
                DynamicLoadDB.fontKey = val
                DynamicLoadDB.fontFamily = val
            end
            activeWorkspaceView = "THEME_STUDIO"
            if addonTable.ApplySuiteThemeAndGeometry then addonTable.ApplySuiteThemeAndGeometry() end
            if f.themeView then f.themeView:Show() end
            if themeView.Refresh then themeView.Refresh() end
        end
    )
    fontDropdown._onBeforeOpen = function(self) ResolveAllFontFamilyPaths(true); self:SetOptions(UI.BuildFontDropdownOptions(true)) end
    fontDropdown:SetPoint("RIGHT", fontRow, "RIGHT", -14, 0)
    fontRow:BindRightControl(fontDropdown)

    -- Row 3: Sync Font & Palette with Installed UI (Item #39: Direction A 2-Pill Switch [ Off | Sync with EUI / Enabled ])
    local detectedSuiteName = DetectExternalUISuite() or "Installed UI / SharedMedia"
    local extPillOnLabel = "Enabled"
    if detectedSuiteName == "EllesmereUI" then
        extPillOnLabel = "Sync with EUI"
    elseif detectedSuiteName == "ElvUI" then
        extPillOnLabel = "Sync with ElvUI"
    end
    local extSyncRow = CreateThemeStudioRow(
        surfaceSectionCard,
        "Sync Font & Palette with Installed UI",
        string.format("Auto-inherit Expressive typography and accent colours from %s.", detectedSuiteName),
        fontRow, -5
    )
    local extSyncPills = UI.CreateSegmentedPills(extSyncRow, {
        { value = false, label = "Off",          width = 68 },
        { value = true,  label = extPillOnLabel, width = 128 },
    }, function()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        return gTbl.syncExternalUI == true
    end, function(val)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        if gTbl then
            gTbl.syncExternalUI = (val == true)
            if val == true then
                ApplyExternalUISync()
            else
                gTbl.accentKey = gTbl._preSyncAccentKey or "OBSIDIAN_SLATE"
                gTbl.customAccent = gTbl._preSyncCustomAccent
                ResolveAllFontFamilyPaths()
                local restoredFont = gTbl._preSyncFontKey or "EXPRESSWAY"
                if not UI.FONT_FAMILIES[restoredFont] or restoredFont == "EXTERNAL_UI" then
                    restoredFont = "EXPRESSWAY"
                end
                local testPath = UI.GetFont(restoredFont)
                if not CanSetFontPath(testPath) then
                    restoredFont = "FRIZ_QUADRATA"
                end
                gTbl.fontKey = restoredFont
                gTbl.fontFamily = restoredFont
                if DynamicLoadDB then
                    DynamicLoadDB.accentKey = gTbl.accentKey
                    DynamicLoadDB.customAccent = gTbl.customAccent
                    DynamicLoadDB.fontKey = restoredFont
                    DynamicLoadDB.fontFamily = restoredFont
                end
                UI.RefreshPaletteCache()
            end
        end
        activeWorkspaceView = "THEME_STUDIO"
        if f.themeView then f.themeView:Show() end
        if addonTable.ApplySuiteThemeAndGeometry then addonTable.ApplySuiteThemeAndGeometry() end
        if f.themeView then f.themeView:Show() end
        if themeView.Refresh then themeView.Refresh() end
    end)
    extSyncPills:SetPoint("RIGHT", extSyncRow, "RIGHT", -14, 0)
    extSyncRow:BindRightControl(extSyncPills)

    -- Row 4: Sync Theme & Font to On-Screen HUD Bars (Direction A 2-Pill Switch [ Off | Enabled ])
    local syncRow = CreateThemeStudioRow(surfaceSectionCard, "Sync Theme & Font to On-Screen HUD Bars", "Automatically apply the active Suite Accent Colour, Surface Theme, and Font Family to all HUD bars.", extSyncRow, -5)
    local syncPills = UI.CreateSegmentedPills(syncRow, {
        { value = false, label = "Off",     width = 68 },
        { value = true,  label = "Enabled", width = 84 },
    }, function()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        return gTbl.syncThemeToToast ~= false
    end, function(val)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        if gTbl then
            gTbl.syncThemeToToast = (val == true)
            gTbl.syncThemeToHuds = val and "all" or "win"
        end
        activeWorkspaceView = "THEME_STUDIO"
        if addonTable.ApplySuiteThemeAndGeometry then addonTable.ApplySuiteThemeAndGeometry() end
        if addonTable.ApplyToastVisuals then addonTable.ApplyToastVisuals() end
        if addonTable.RefreshDisableCoreModalTheme then addonTable.RefreshDisableCoreModalTheme() end
        if f.themeView then f.themeView:Show() end
        if themeView.Refresh then themeView.Refresh() end
    end)
    syncPills:SetPoint("RIGHT", syncRow, "RIGHT", -14, 0)
    syncRow:BindRightControl(syncPills)

    -- Row 5: Preserve Window Size, Scale & Layout Across All Characters (Direction A 2-Pill Switch [ Off | Enabled ])
    local altSyncRow = CreateThemeStudioRow(surfaceSectionCard, "Preserve Window Size, Scale & Layout Across All Characters", "Share your custom window dimensions, UI scale, and HUD bar coordinates across every character.", syncRow, -5)
    local altSyncPills = UI.CreateSegmentedPills(altSyncRow, {
        { value = "char",    label = "Off",     width = 68 },
        { value = "account", label = "Enabled", width = 84 },
    }, function()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        return gTbl.layoutSyncScope or "account"
    end, function(val)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        if gTbl then gTbl.layoutSyncScope = val end
        if DynamicLoadDB then DynamicLoadDB.layoutSyncScope = val end
        activeWorkspaceView = "THEME_STUDIO"
        if f.themeView then f.themeView:Show() end
        if themeView.Refresh then themeView.Refresh() end
    end)
    altSyncPills:SetPoint("RIGHT", altSyncRow, "RIGHT", -14, 0)
    altSyncRow:BindRightControl(altSyncPills)

    -- Row 6: Active Control Fill Intensity (Direction A 3-Pill Switch [ Subtle (24%) | Balanced (32%) | Bold (42%) ])
    local fillRow = CreateThemeStudioRow(
        surfaceSectionCard,
        "Active Control Fill Intensity",
        "Adjust the colour fill strength of selected tabs, pills, and switches (24% Subtle, 32% Balanced, 42% Bold).",
        altSyncRow, -5
    )
    local fillPills = UI.CreateSegmentedPills(fillRow, {
        { value = 0.24, label = "Subtle (24%)",   width = 92 },
        { value = 0.32, label = "Balanced (32%)", width = 102 },
        { value = 0.42, label = "Bold (42%)",     width = 88 },
    }, function()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        return gTbl.pillFillAlpha or 0.42
    end, function(val)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        local nVal = tonumber(val) or 0.42
        if gTbl then gTbl.pillFillAlpha = nVal end
        if DynamicLoadDB then DynamicLoadDB.pillFillAlpha = nVal end
        activeWorkspaceView = "THEME_STUDIO"
        if addonTable.ApplySuiteThemeAndGeometry then addonTable.ApplySuiteThemeAndGeometry() end
        if f.themeView then f.themeView:Show() end
        if themeView.Refresh then themeView.Refresh() end
    end)
    fillPills:SetPoint("RIGHT", fillRow, "RIGHT", -14, 0)
    fillRow:BindRightControl(fillPills)

    -- Card 3: Bordered Section Container for Game Menu & Options Shortcuts (3 Compact 48px Rows)
    local shortcutSectionCard = CreateFrame("Frame", nil, tvChild)
    shortcutSectionCard:SetPoint("TOPLEFT", surfaceSectionCard, "BOTTOMLEFT", 0, -10)
    shortcutSectionCard:SetPoint("TOPRIGHT", surfaceSectionCard, "BOTTOMRIGHT", 0, -10)
    shortcutSectionCard:SetHeight(220)
    shortcutSectionCard.bg = UI.SolidTex(shortcutSectionCard, "BACKGROUND", 0, 0.031, 0.039, 0.055, 0.72)
    shortcutSectionCard.bg:SetAllPoints()
    UI.CreatePixelBorder(shortcutSectionCard, 1, 1, 1, 0.08, 2)

    local shortSecHdr = UI.CreateSectionHeader(
        shortcutSectionCard,
        -10,
        "GAME MENU & OPTIONS SHORTCUTS",
        "Choose which DynamicSuite shortcuts appear in the Esc Game Menu and Blizzard Options.",
        14
    )

    -- Shortcut Row 1: Game Menu: DynamicSuite Button ([ Hidden | Shown ])
    local gmSuiteRow = CreateThemeStudioRow(
        shortcutSectionCard,
        "Game Menu: DynamicSuite Button",
        "Show a 'DynamicSuite' shortcut button inside the Esc Game Menu.",
        shortSecHdr, -8
    )
    local gmSuitePills = UI.CreateSegmentedPills(gmSuiteRow, {
        { value = false, label = "Hidden", width = 68 },
        { value = true,  label = "Shown",  width = 76 },
    }, function()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        return gTbl.showGameMenuSuiteBtn ~= false
    end, function(val)
        local isShown = (val == true)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        if gTbl then gTbl.showGameMenuSuiteBtn = isShown end
        if _G.DynamicSuiteDB and _G.DynamicSuiteDB.global then
            _G.DynamicSuiteDB.global.showGameMenuSuiteBtn = isShown
        end
        if addonTable.RefreshGameMenuButtons then addonTable.RefreshGameMenuButtons() end
        if themeView.Refresh then themeView.Refresh() end
    end)
    gmSuitePills:SetPoint("RIGHT", gmSuiteRow, "RIGHT", -14, 0)
    gmSuiteRow:BindRightControl(gmSuitePills)

    -- Shortcut Row 2: Game Menu: DynamicSuite HUD Button ([ Hidden | Shown ])
    local gmHudRow = CreateThemeStudioRow(
        shortcutSectionCard,
        "Game Menu: DynamicSuite HUD Button",
        "Show a 'DynamicSuite HUD' button in the Esc Game Menu to unlock and move suite bars.",
        gmSuiteRow, -5
    )
    local gmHudPills = UI.CreateSegmentedPills(gmHudRow, {
        { value = false, label = "Hidden", width = 68 },
        { value = true,  label = "Shown",  width = 76 },
    }, function()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        return gTbl.showGameMenuHudBtn ~= false
    end, function(val)
        local isShown = (val == true)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        if gTbl then gTbl.showGameMenuHudBtn = isShown end
        if _G.DynamicSuiteDB and _G.DynamicSuiteDB.global then
            _G.DynamicSuiteDB.global.showGameMenuHudBtn = isShown
        end
        if addonTable.RefreshGameMenuButtons then addonTable.RefreshGameMenuButtons() end
        if themeView.Refresh then themeView.Refresh() end
    end)
    gmHudPills:SetPoint("RIGHT", gmHudRow, "RIGHT", -14, 0)
    gmHudRow:BindRightControl(gmHudPills)

    -- Shortcut Row 3: Replace Blizzard AddOns Button ([ Off | Enabled ])
    local replaceAddonListRow = CreateThemeStudioRow(
        shortcutSectionCard,
        "Replace Blizzard AddOns Button",
        "Open DynamicSuite instead of Blizzard's default AddOn list when clicking 'AddOns' in the Esc menu.",
        gmHudRow, -5
    )
    local replaceAddonListPills = UI.CreateSegmentedPills(replaceAddonListRow, {
        { value = false, label = "Off",     width = 68 },
        { value = true,  label = "Enabled", width = 84 },
    }, function()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        return gTbl.replaceBlizzardAddonList ~= false
    end, function(val)
        local isEnabled = (val == true)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        if gTbl then gTbl.replaceBlizzardAddonList = isEnabled end
        if _G.DynamicSuiteDB and _G.DynamicSuiteDB.global then
            _G.DynamicSuiteDB.global.replaceBlizzardAddonList = isEnabled
        end
        if themeView.Refresh then themeView.Refresh() end
    end)
    replaceAddonListPills:SetPoint("RIGHT", replaceAddonListRow, "RIGHT", -14, 0)
    replaceAddonListRow:BindRightControl(replaceAddonListPills)

    -- Tab 1 Card 3: Shared Alert & Teleport Toast HUD Configuration Card (Visibility, Border Style, Scale, Opacity, Test Toast, Edit HUD)
    local toastSectionCard = CreateFrame("Frame", nil, tvChild)
    toastSectionCard:SetPoint("TOPLEFT", surfaceSectionCard, "BOTTOMLEFT", 0, -10)
    toastSectionCard:SetPoint("TOPRIGHT", surfaceSectionCard, "BOTTOMRIGHT", 0, -10)
    toastSectionCard:SetHeight(274)
    toastSectionCard.bg = UI.SolidTex(toastSectionCard, "BACKGROUND", 0, 0.031, 0.039, 0.055, 0.72)
    toastSectionCard.bg:SetAllPoints()
    UI.CreatePixelBorder(toastSectionCard, 1, 1, 1, 0.08, 2)

    local toastSecHdr = UI.CreateSectionHeader(
        toastSectionCard,
        -10,
        "ON-SCREEN ALERT & TELEPORT TOAST HUD",
        "Customise visibility, border style, scale, and opacity for the shared Alert & Teleport Toast popup.",
        14
    )
    local toastEditHudBtn = UI.CreateEditHudButton(toastSecHdr, "TOAST")
    toastEditHudBtn:SetPoint("RIGHT", toastSecHdr, "RIGHT", 0, 2)

    local toastTestBtn = CreateFlatButton(toastSecHdr, 92, 22, "Test Toast", false)
    toastTestBtn:SetPoint("RIGHT", toastEditHudBtn, "LEFT", -6, 0)
    toastTestBtn:SetScript("OnClick", function()
        if addonTable.ShowToast then
            addonTable.ShowToast(selectedTabKey or "outdoor", 4, true)
        elseif _G.DynamicGroup and _G.DynamicGroup.ShowTeleportToast then
            pcall(_G.DynamicGroup.ShowTeleportToast, _G.DynamicGroup, "Preview Destination", "Preview Party Lead", true)
        end
    end)
    if toastSecHdr.subtitle then
        toastSecHdr.subtitle:ClearAllPoints()
        toastSecHdr.subtitle:SetPoint("TOPLEFT", toastSecHdr.title, "BOTTOMLEFT", 0, -2)
        toastSecHdr.subtitle:SetPoint("RIGHT", toastTestBtn, "LEFT", -10, 0)
    end

    local function SyncSharedToastHudVisuals()
        if addonTable.ApplyToastVisuals then pcall(addonTable.ApplyToastVisuals) end
        if _G.DynamicGroup and _G.DynamicGroup.UpdateTeleportToast then
            pcall(_G.DynamicGroup.UpdateTeleportToast, _G.DynamicGroup)
        end
        if f.toastConfigPanel and f.toastConfigPanel.RefreshControls then
            pcall(f.toastConfigPanel.RefreshControls)
        end
        if themeView.Refresh then themeView.Refresh() end
    end

    local toastVisRow = CreateThemeStudioRow(
        toastSectionCard,
        "Toast Banner Visibility",
        "Show or hide the shared Alert & Teleport Toast HUD banner across your screen.",
        toastSecHdr, -8
    )
    local toastVisPills = UI.CreateSegmentedPills(toastVisRow, {
        { value = false, label = "Hidden", width = 68 },
        { value = true,  label = "Shown",  width = 68 },
    }, function()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        if gTbl.toastEnabled ~= nil then return gTbl.toastEnabled == true end
        local tMode = (DynamicLoadDB and DynamicLoadDB.toastMode) or gTbl.toastMode
        if tMode ~= nil then return tMode ~= "OFF" end
        local dMode = (DynamicLoadDB and DynamicLoadDB.toastDisplayMode) or gTbl.toastDisplayMode
        return dMode ~= "OFF"
    end, function(val)
        local isShown = (val == true)
        local modeVal = isShown and "ALWAYS" or "OFF"
        local dispVal = isShown and "DETAILED" or "OFF"
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        if gTbl then
            gTbl.toastEnabled = isShown
            gTbl.toastMode = modeVal
            if not isShown or gTbl.toastDisplayMode == "OFF" then
                gTbl.toastDisplayMode = dispVal
            end
            gTbl.hudVisibility = gTbl.hudVisibility or {}
            gTbl.hudVisibility["TOAST"] = isShown and "ALWAYS" or "HIDDEN"
        end
        if _G.DynamicSuiteDB and _G.DynamicSuiteDB.global then
            _G.DynamicSuiteDB.global.toastEnabled = isShown
            _G.DynamicSuiteDB.global.toastMode = modeVal
            if not isShown or _G.DynamicSuiteDB.global.toastDisplayMode == "OFF" then
                _G.DynamicSuiteDB.global.toastDisplayMode = dispVal
            end
        end
        if DynamicLoadDB then
            DynamicLoadDB.toastEnabled = isShown
            DynamicLoadDB.toastMode = modeVal
            if not isShown or DynamicLoadDB.toastDisplayMode == "OFF" then
                DynamicLoadDB.toastDisplayMode = dispVal
            end
        end
        if _G.DynamicLoadToastFrame and not isShown and not _G.DynamicLoadToastFrame.isEditingMode and not InCombatLockdown() then
            _G.DynamicLoadToastFrame:Hide()
        end
        SyncSharedToastHudVisuals()
    end)
    toastVisPills:SetPoint("RIGHT", toastVisRow, "RIGHT", -14, 0)
    toastVisRow:BindRightControl(toastVisPills)

    local toastBorderRow = CreateThemeStudioRow(
        toastSectionCard,
        "Toast Border Style",
        "Choose the 1px outer frame border accent for the floating Alert & Teleport Toast.",
        toastVisRow, -5
    )
    local toastBorderPills = UI.CreateSegmentedPills(toastBorderRow, {
        { value = "ACCENT", label = "Suite Accent", width = 98 },
        { value = "SUBTLE", label = "Subtle Dark",  width = 92 },
        { value = "NONE",   label = "Borderless",   width = 84 },
    }, function()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local raw = gTbl.toastBorderStyle or (DynamicLoadDB and DynamicLoadDB.toastBorderStyle) or "ACCENT"
        if raw == "DARK" then raw = "SUBTLE" end
        return raw
    end, function(val)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        if gTbl then gTbl.toastBorderStyle = val end
        if _G.DynamicSuiteDB and _G.DynamicSuiteDB.global then
            _G.DynamicSuiteDB.global.toastBorderStyle = val
        end
        if DynamicLoadDB then DynamicLoadDB.toastBorderStyle = val end
        SyncSharedToastHudVisuals()
    end)
    toastBorderPills:SetPoint("RIGHT", toastBorderRow, "RIGHT", -14, 0)
    toastBorderRow:BindRightControl(toastBorderPills)

    local toastScaleRow = CreateThemeStudioRow(
        toastSectionCard,
        "Toast HUD Scale",
        "Adjust the size of the Alert & Teleport Toast popup (60% to 150%).",
        toastBorderRow, -5
    )
    local toastScaleSlider = CreateDSOptionSlider(
        toastScaleRow, 240, 0.60, 1.50, 0.05,
        function(v) return string.format("%d%%", math.floor((v or 1.0) * 100 + 0.5)) end,
        function()
            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
            return gTbl.toastScale or (DynamicLoadDB and DynamicLoadDB.toastScale) or 1.0
        end,
        function(val)
            local clamped = math.max(0.60, math.min(1.50, math.floor(val * 20 + 0.5) / 20))
            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
            if gTbl then gTbl.toastScale = clamped end
            if _G.DynamicSuiteDB and _G.DynamicSuiteDB.global then
                _G.DynamicSuiteDB.global.toastScale = clamped
            end
            if DynamicLoadDB then DynamicLoadDB.toastScale = clamped end
            if addonTable.ApplyToastVisuals then pcall(addonTable.ApplyToastVisuals) end
            if _G.DynamicGroup and _G.DynamicGroup.UpdateTeleportToast then
                pcall(_G.DynamicGroup.UpdateTeleportToast, _G.DynamicGroup)
            end
            if f.toastConfigPanel and f.toastConfigPanel.RefreshControls then
                pcall(f.toastConfigPanel.RefreshControls)
            end
        end
    )
    toastScaleSlider:SetPoint("RIGHT", toastScaleRow, "RIGHT", -14, 0)
    toastScaleRow:BindRightControl(toastScaleSlider)

    local toastOpacityRow = CreateThemeStudioRow(
        toastSectionCard,
        "Toast Background Opacity",
        "Adjust the dark-obsidian backdrop transparency of the Alert & Teleport Toast (20% to 100%).",
        toastScaleRow, -5
    )
    local toastOpacitySlider = CreateDSOptionSlider(
        toastOpacityRow, 240, 0.20, 1.00, 0.05,
        function(v) return string.format("%d%%", math.floor((v or 0.96) * 100 + 0.5)) end,
        function()
            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
            return gTbl.toastOpacity or gTbl.toastAlpha or (DynamicLoadDB and (DynamicLoadDB.toastOpacity or DynamicLoadDB.toastAlpha)) or 0.96
        end,
        function(val)
            local clamped = math.max(0.20, math.min(1.00, math.floor(val * 20 + 0.5) / 20))
            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
            if gTbl then
                gTbl.toastOpacity = clamped
                gTbl.toastAlpha = clamped
            end
            if _G.DynamicSuiteDB and _G.DynamicSuiteDB.global then
                _G.DynamicSuiteDB.global.toastOpacity = clamped
                _G.DynamicSuiteDB.global.toastAlpha = clamped
            end
            if DynamicLoadDB then
                DynamicLoadDB.toastOpacity = clamped
                DynamicLoadDB.toastAlpha = clamped
            end
            if addonTable.ApplyToastVisuals then pcall(addonTable.ApplyToastVisuals) end
            if _G.DynamicGroup and _G.DynamicGroup.UpdateTeleportToast then
                pcall(_G.DynamicGroup.UpdateTeleportToast, _G.DynamicGroup)
            end
            if f.toastConfigPanel and f.toastConfigPanel.RefreshControls then
                pcall(f.toastConfigPanel.RefreshControls)
            end
        end
    )
    toastOpacitySlider:SetPoint("RIGHT", toastOpacityRow, "RIGHT", -14, 0)
    toastOpacityRow:BindRightControl(toastOpacitySlider)

    ----------------------------------------------------------------------------
    -- TAB 2: DESKTOP WINDOWS & MENUS (Blizzard Desktop Window Manager + Game Menu & Options Shortcuts)
    ----------------------------------------------------------------------------
    local yieldStatusBanner, desktopWinSectionCard, winSecHdr
    local winMasterRow, winMasterPills, winSideBySideRow, winSideBySidePills, winDragRow, winDragPills, winScaleRow, winScalePills, winResetRow, winResetAllBtn
    local GetDesktopWindowsDBTable, ApplyDesktopWindowStatesSafe, ResetAllDesktopWindowsSafe, GetActiveDesktopWindowYieldAddon

    do
        GetDesktopWindowsDBTable = function()
            local dw = (_G.DynamicSuite and _G.DynamicSuite.DesktopWindows) or addonTable.DesktopWindows
            if dw and type(dw.GetDB) == "function" then
                local ok, db = pcall(dw.GetDB, dw)
                if ok and type(db) == "table" then return db end
            end
            if addonTable.GetDesktopWindowsDB then
                local ok, db = pcall(addonTable.GetDesktopWindowsDB)
                if ok and type(db) == "table" then return db end
            end
            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
            if type(gTbl) == "table" then
                if type(gTbl.desktopWindows) ~= "table" then
                    gTbl.desktopWindows = {
                        enabled = true,
                        sideBySide = true,
                        dragAnywhere = true,
                        draggable = true,
                        scrollScale = true,
                        positions = {},
                        scales = {},
                    }
                end
                return gTbl.desktopWindows
            end
            return { enabled = true, sideBySide = true, dragAnywhere = true, draggable = true, scrollScale = true, positions = {}, scales = {} }
        end

        ApplyDesktopWindowStatesSafe = function()
            local dw = (_G.DynamicSuite and _G.DynamicSuite.DesktopWindows) or addonTable.DesktopWindows
            if dw and type(dw.ApplyAllWindowStates) == "function" then
                pcall(dw.ApplyAllWindowStates, dw)
            elseif dw and type(dw.ApplyAllBlizzardWindowStates) == "function" then
                pcall(dw.ApplyAllBlizzardWindowStates, dw)
            elseif _G.DynamicPrep and type(_G.DynamicPrep.ApplyAllBlizzardWindowStates) == "function" then
                pcall(_G.DynamicPrep.ApplyAllBlizzardWindowStates, _G.DynamicPrep)
            end
        end

        ResetAllDesktopWindowsSafe = function(silent)
            local dw = (_G.DynamicSuite and _G.DynamicSuite.DesktopWindows) or addonTable.DesktopWindows
            if dw and type(dw.ResetAllWindows) == "function" then
                pcall(dw.ResetAllWindows, dw, silent == true)
            elseif dw and type(dw.ResetAllBlizzardWindows) == "function" then
                pcall(dw.ResetAllBlizzardWindows, dw, silent == true)
            elseif _G.DynamicPrep and type(_G.DynamicPrep.ResetAllBlizzardWindows) == "function" then
                pcall(_G.DynamicPrep.ResetAllBlizzardWindows, _G.DynamicPrep, silent == true)
            else
                local db = GetDesktopWindowsDBTable()
                db.positions = {}
                db.scales = {}
            end
        end

        GetActiveDesktopWindowYieldAddon = function()
            local dw = (_G.DynamicSuite and _G.DynamicSuite.DesktopWindows) or addonTable.DesktopWindows
            if dw and type(dw.GetYieldAddon) == "function" then
                local ok, res = pcall(dw.GetYieldAddon, dw)
                if ok and type(res) == "string" and res ~= "" then
                    return res
                end
            end
            if addonTable.GetBlizzardWindowYieldAddon then
                local ok, res = pcall(addonTable.GetBlizzardWindowYieldAddon)
                if ok and type(res) == "string" and res ~= "" then
                    return res
                end
            end
            if _G.DynamicPrep and type(_G.DynamicPrep.GetBlizzardWindowYieldAddon) == "function" then
                local ok, res = pcall(_G.DynamicPrep.GetBlizzardWindowYieldAddon, _G.DynamicPrep)
                if ok and type(res) == "string" and res ~= "" then
                    return res
                end
            end
            return nil
        end

        -- Calm External-Mover Yield Status Banner (Shown only when an external mover addon manages Blizzard frames)
        yieldStatusBanner = CreateFrame("Frame", nil, tvChild)
        yieldStatusBanner:SetPoint("TOPLEFT", tvChild, "TOPLEFT", 0, 0)
        yieldStatusBanner:SetPoint("TOPRIGHT", tvChild, "TOPRIGHT", 0, 0)
        yieldStatusBanner:SetHeight(54)
        yieldStatusBanner.bg = UI.SolidTex(yieldStatusBanner, "BACKGROUND", 1, 0.04, 0.11, 0.16, 0.94)
        yieldStatusBanner.bg:SetAllPoints()
        UI.CreatePixelBorder(yieldStatusBanner, 0.220, 0.741, 0.973, 0.85, 2)
        yieldStatusBanner.leftBar = UI.SolidTex(yieldStatusBanner, "OVERLAY", 4, 0.220, 0.741, 0.973, 1.0)
        yieldStatusBanner.leftBar:SetWidth(3)
        yieldStatusBanner.leftBar:SetPoint("TOPLEFT", yieldStatusBanner, "TOPLEFT", 0, 0)
        yieldStatusBanner.leftBar:SetPoint("BOTTOMLEFT", yieldStatusBanner, "BOTTOMLEFT", 0, 0)

        local yieldSetupBtn = CreateFlatButton(yieldStatusBanner, 148, 24, "Open Guided Setup", false)
        yieldSetupBtn:SetPoint("RIGHT", yieldStatusBanner, "RIGHT", -12, 0)
        yieldSetupBtn:SetSelected(true, { r = 0.220, g = 0.741, b = 0.973 })
        yieldSetupBtn:SetScript("OnClick", function()
            addonTable.OpenWorkspaceView("GUIDED_SETUP")
        end)
        yieldStatusBanner.setupBtn = yieldSetupBtn

        local yieldTitle = yieldStatusBanner:CreateFontString(nil, "OVERLAY")
        yieldTitle:SetPoint("TOPLEFT", yieldStatusBanner, "TOPLEFT", 14, -8)
        yieldTitle:SetPoint("RIGHT", yieldSetupBtn, "LEFT", -12, 0)
        yieldTitle:SetJustifyH("LEFT")
        yieldTitle:SetWordWrap(false)
        UI.SetFont(yieldTitle, 11, "", 0.220, 0.741, 0.973, 1.0)
        yieldStatusBanner.title = yieldTitle

        local yieldSub = yieldStatusBanner:CreateFontString(nil, "OVERLAY")
        yieldSub:SetPoint("TOPLEFT", yieldTitle, "BOTTOMLEFT", 0, -2)
        yieldSub:SetPoint("RIGHT", yieldSetupBtn, "LEFT", -12, 0)
        yieldSub:SetJustifyH("LEFT")
        yieldSub:SetWordWrap(true)
        UI.SetFont(yieldSub, 9.5, "", 0.82, 0.88, 0.94, 0.95)
        yieldStatusBanner.sub = yieldSub
        yieldStatusBanner:Hide()

        -- Section 1: BLIZZARD DESKTOP WINDOW MANAGER (5 Rows with 2-Line Tall 36px L-Bracket Header)
        desktopWinSectionCard = CreateFrame("Frame", nil, tvChild)
        desktopWinSectionCard:SetPoint("TOPLEFT", tvChild, "TOPLEFT", 0, 0)
        desktopWinSectionCard:SetPoint("TOPRIGHT", tvChild, "TOPRIGHT", 0, 0)
        desktopWinSectionCard:SetHeight(366)
        desktopWinSectionCard.bg = UI.SolidTex(desktopWinSectionCard, "BACKGROUND", 0, 0.031, 0.039, 0.055, 0.72)
        desktopWinSectionCard.bg:SetAllPoints()
        UI.CreatePixelBorder(desktopWinSectionCard, 1, 1, 1, 0.08, 2)

        winSecHdr = UI.CreateSectionHeader(
            desktopWinSectionCard,
            -10,
            "BLIZZARD DESKTOP WINDOW MANAGER",
            "Open Blizzard panels side-by-side (including windowed Quest Log), drag from any empty space, click to raise, and Ctrl+Scroll to scale.",
            14
        )

        local function CreateDesktopWinRow(rowTitle, rowDesc, anchorAbove, gapY)
            local row = CreateThemeStudioRow(desktopWinSectionCard, rowTitle, rowDesc, anchorAbove, gapY)
            row:SetHeight(56)
            row.titleText:ClearAllPoints()
            row.titleText:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -7)
            row.titleText:SetPoint("RIGHT", row, "RIGHT", -190, 0)
            row.descText:ClearAllPoints()
            row.descText:SetPoint("TOPLEFT", row.titleText, "BOTTOMLEFT", 0, -2)
            row.descText:SetPoint("RIGHT", row, "RIGHT", -190, 0)
            row.descText:SetWordWrap(true)
            return row
        end

        -- Row 0: Master Switch - Enable Blizzard Desktop Window Manager
        winMasterRow = CreateDesktopWinRow(
            "Enable Blizzard Desktop Window Manager",
            "Master switch for Side-by-Side (No Auto-Close), Drag Anywhere, and Ctrl+Scroll Scaling on Blizzard frames. Turn Off to leave all Blizzard windows 100% untouched (reload recommended for a completely unhooked session).",
            winSecHdr, -8
        )
        winMasterPills = UI.CreateSegmentedPills(winMasterRow, {
            { value = false, label = "Off",     width = 68 },
            { value = true,  label = "Enabled", width = 84 },
        }, function()
            local db = GetDesktopWindowsDBTable()
            return db.masterEnabled ~= false
        end, function(val)
            local isOn = (val == true)
            local db = GetDesktopWindowsDBTable()
            db.masterEnabled = isOn
            if not isOn then
                db.sideBySide = false
                db.enabled = false
                db.dragAnywhere = false
                db.draggable = false
                db.scrollScale = false
                if _G.DynamicPrepDB then
                    _G.DynamicPrepDB.blizzWinNoAutoClose = false
                    _G.DynamicPrepDB.blizzWinDraggable = false
                    _G.DynamicPrepDB.blizzWinScrollScale = false
                end
            else
                db.sideBySide = true
                db.enabled = true
                db.dragAnywhere = true
                db.draggable = true
                db.scrollScale = true
                if _G.DynamicPrepDB then
                    _G.DynamicPrepDB.blizzWinNoAutoClose = true
                    _G.DynamicPrepDB.blizzWinDraggable = true
                    _G.DynamicPrepDB.blizzWinScrollScale = true
                end
                local dw = (_G.DynamicSuite and _G.DynamicSuite.DesktopWindows) or addonTable.DesktopWindows
                if dw and type(dw.Init) == "function" then
                    pcall(dw.Init, dw)
                end
            end
            ApplyDesktopWindowStatesSafe()
            if themeView.Refresh then themeView.Refresh() end
        end)
        winMasterPills:SetPoint("RIGHT", winMasterRow, "RIGHT", -14, 0)
        winMasterRow:BindRightControl(winMasterPills)

        -- Row 1: Keep Blizzard Windows Open Side-by-Side
        winSideBySideRow = CreateDesktopWinRow(
            "Keep Blizzard Windows Open Side-by-Side",
            "Opening Character, Spellbook & Talents, Professions, Bags, Collections, or the windowed Quest Log (L) keeps existing panels open side-by-side, clicking any window brings it to the front, and Esc closes the top-most window first.",
            winMasterRow, -6
        )
        winSideBySidePills = UI.CreateSegmentedPills(winSideBySideRow, {
            { value = false, label = "Off",     width = 68 },
            { value = true,  label = "Enabled", width = 84 },
        }, function()
            local db = GetDesktopWindowsDBTable()
            if db.sideBySide ~= nil then return db.sideBySide ~= false end
            return db.enabled ~= false
        end, function(val)
            local isOn = (val == true)
            local db = GetDesktopWindowsDBTable()
            if isOn and db.masterEnabled == false then
                db.masterEnabled = true
                local dw = (_G.DynamicSuite and _G.DynamicSuite.DesktopWindows) or addonTable.DesktopWindows
                if dw and type(dw.Init) == "function" then pcall(dw.Init, dw) end
            end
            db.sideBySide = isOn
            db.enabled = isOn
            if _G.DynamicPrepDB then _G.DynamicPrepDB.blizzWinNoAutoClose = isOn end
            ApplyDesktopWindowStatesSafe()
            if themeView.Refresh then themeView.Refresh() end
        end)
        winSideBySidePills:SetPoint("RIGHT", winSideBySideRow, "RIGHT", -14, 0)
        winSideBySideRow:BindRightControl(winSideBySidePills)

        -- Row 2: Drag Blizzard Windows Anywhere (Save Position)
        winDragRow = CreateDesktopWinRow(
            "Drag Blizzard Windows Anywhere (Save Position)",
            "Left-Click and drag any Blizzard window from its title bar or any empty background space (no Alt key needed), automatically clamped on-screen and saved across sessions (Right-Click title bar to reset a single window).",
            winSideBySideRow, -6
        )
        winDragPills = UI.CreateSegmentedPills(winDragRow, {
            { value = false, label = "Off",     width = 68 },
            { value = true,  label = "Enabled", width = 84 },
        }, function()
            local db = GetDesktopWindowsDBTable()
            if db.dragAnywhere ~= nil then return db.dragAnywhere ~= false end
            return db.draggable ~= false
        end, function(val)
            local isOn = (val == true)
            local db = GetDesktopWindowsDBTable()
            if isOn and db.masterEnabled == false then
                db.masterEnabled = true
                local dw = (_G.DynamicSuite and _G.DynamicSuite.DesktopWindows) or addonTable.DesktopWindows
                if dw and type(dw.Init) == "function" then pcall(dw.Init, dw) end
            end
            db.dragAnywhere = isOn
            db.draggable = isOn
            if _G.DynamicPrepDB then _G.DynamicPrepDB.blizzWinDraggable = isOn end
            ApplyDesktopWindowStatesSafe()
            if themeView.Refresh then themeView.Refresh() end
        end)
        winDragPills:SetPoint("RIGHT", winDragRow, "RIGHT", -14, 0)
        winDragRow:BindRightControl(winDragPills)

        -- Row 3: Window Ctrl+Scroll Scaling
        winScaleRow = CreateDesktopWinRow(
            "Window Ctrl+Scroll Scaling",
            "Hold Ctrl + Mousewheel on a Blizzard window title bar for temporary session scaling (70% to 140% in 5% steps), or Ctrl + Shift + Mousewheel anywhere on a window to save permanent scale.",
            winDragRow, -6
        )
        winScalePills = UI.CreateSegmentedPills(winScaleRow, {
            { value = false, label = "Off",     width = 68 },
            { value = true,  label = "Enabled", width = 84 },
        }, function()
            local db = GetDesktopWindowsDBTable()
            return db.scrollScale ~= false
        end, function(val)
            local isOn = (val == true)
            local db = GetDesktopWindowsDBTable()
            if isOn and db.masterEnabled == false then
                db.masterEnabled = true
                local dw = (_G.DynamicSuite and _G.DynamicSuite.DesktopWindows) or addonTable.DesktopWindows
                if dw and type(dw.Init) == "function" then pcall(dw.Init, dw) end
            end
            db.scrollScale = isOn
            if _G.DynamicPrepDB then _G.DynamicPrepDB.blizzWinScrollScale = isOn end
            ApplyDesktopWindowStatesSafe()
            if themeView.Refresh then themeView.Refresh() end
        end)
        winScalePills:SetPoint("RIGHT", winScaleRow, "RIGHT", -14, 0)
        winScaleRow:BindRightControl(winScalePills)

        -- Row 4: Reset Blizzard Window Layout
        winResetRow = CreateDesktopWinRow(
            "Reset Blizzard Window Layout",
            "Restores all 31 managed Blizzard windows to default 100% scale and centred positions.",
            winScaleRow, -6
        )
        winResetAllBtn = CreateFlatButton(winResetRow, 156, 26, "Reset All Windows", false)
        winResetAllBtn:SetPoint("RIGHT", winResetRow, "RIGHT", -14, 0)
        winResetAllBtn:SetScript("OnClick", function()
            ResetAllDesktopWindowsSafe(false)
            if themeView.Refresh then themeView.Refresh() end
        end)
        winResetRow:BindRightControl(winResetAllBtn)

        -- Anchor Section 2 (GAME MENU & OPTIONS SHORTCUTS) directly below Section 1 on Tab 2
        shortcutSectionCard:ClearAllPoints()
        shortcutSectionCard:SetPoint("TOPLEFT", desktopWinSectionCard, "BOTTOMLEFT", 0, -10)
        shortcutSectionCard:SetPoint("TOPRIGHT", desktopWinSectionCard, "BOTTOMRIGHT", 0, -10)
    end

    local function GetDefaultStudioResetLabel()
        return (activeStudioTab == 2) and "Reset Window Defaults" or "Reset Theme Defaults"
    end

    local resetThemeConfirmTimer = nil
    local function CancelThemeResetConfirmation(showCancelledFeedback)
        if resetThemeConfirmTimer then
            resetThemeConfirmTimer:Cancel()
            resetThemeConfirmTimer = nil
        end
        tvResetBtn.isConfirming = false
        if showCancelledFeedback then
            tvResetBtn.label:SetText("Cancelled (Safe)")
            tvResetBtn.label:SetTextColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1)
            tvResetBtn.dsBorder:SetColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.90)
            C_Timer.After(1.2, function()
                if not tvResetBtn.isConfirming then
                    tvResetBtn.label:SetText(GetDefaultStudioResetLabel())
                    tvResetBtn.label:SetTextColor(0.86, 0.88, 0.92, 0.95)
                    tvResetBtn.dsBorder:SetColor(UI.COLORS.BTN_BORDER.r, UI.COLORS.BTN_BORDER.g, UI.COLORS.BTN_BORDER.b, UI.COLORS.BTN_BORDER.a)
                end
            end)
        else
            tvResetBtn.label:SetText(GetDefaultStudioResetLabel())
            tvResetBtn.label:SetTextColor(0.86, 0.88, 0.92, 0.95)
            tvResetBtn.dsBorder:SetColor(UI.COLORS.BTN_BORDER.r, UI.COLORS.BTN_BORDER.g, UI.COLORS.BTN_BORDER.b, UI.COLORS.BTN_BORDER.a)
        end
    end

    local function SetSuiteStudioTab(tabIdx, skipRefresh)
        local targetTab = (tonumber(tabIdx) == 2 or tabIdx == "DESKTOP_WINDOWS" or tabIdx == "WINDOWS") and 2 or 1
        if activeStudioTab ~= targetTab then
            if UI.CloseAllPopups then UI.CloseAllPopups() end
            CancelThemeResetConfirmation(false)
            activeStudioTab = targetTab
            themeView.activeTab = targetTab
            tvScroll:SetVerticalScroll(0)
        end
        if not skipRefresh and themeView.Refresh then
            themeView.Refresh()
        end
    end
    f.SetSuiteStudioTab = SetSuiteStudioTab
    themeView.SelectTab = SetSuiteStudioTab
    themeView.SelectSubTab = SetSuiteStudioTab

    for idx, tDef in ipairs(studioTabDefs) do
        local tBtn = CreateFrame("Button", nil, studioTabBar)
        tBtn:SetHeight(26)
        tBtn.bg = UI.SolidTex(tBtn, "BACKGROUND", 2, 0.078, 0.090, 0.122, 0.96)
        tBtn.bg:SetAllPoints()
        UI.CreatePixelBorder(tBtn, 0.145, 0.165, 0.212, 0.95, 3)

        local tIcon = tBtn:CreateTexture(nil, "ARTWORK", nil, 3)
        tIcon:SetSize(13, 13)
        tIcon:SetPoint("LEFT", tBtn, "LEFT", 12, 0)
        tIcon:SetTexture(tDef.icon)
        tBtn.iconTex = tIcon

        local tLbl = tBtn:CreateFontString(nil, "OVERLAY")
        tLbl:SetPoint("LEFT", tIcon, "RIGHT", 6, 0)
        tLbl:SetPoint("RIGHT", tBtn, "RIGHT", -8, 0)
        tLbl:SetJustifyH("CENTER")
        tLbl:SetWordWrap(false)
        UI.SetFont(tLbl, 11, "", 0.68, 0.74, 0.82, 1)
        tLbl:SetText(tDef.label)
        tBtn.label = tLbl

        tBtn:SetScript("OnEnter", function(self)
            if activeStudioTab ~= tDef.id then
                local cr, cg, cb = UI.GetActiveAccentColor()
                self.bg:SetColorTexture(0.10, 0.12, 0.16, 0.98)
                self.dsBorder:SetColor(cr, cg, cb, 0.65)
                self.label:SetTextColor(0.94, 0.96, 1.0, 1)
            end
        end)
        tBtn:SetScript("OnLeave", function(self)
            if activeStudioTab ~= tDef.id then
                self.bg:SetColorTexture(0.078, 0.090, 0.122, 0.96)
                self.dsBorder:SetColor(0.145, 0.165, 0.212, 0.95)
                self.label:SetTextColor(0.68, 0.74, 0.82, 1)
            end
        end)
        tBtn:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB or 841)
            SetSuiteStudioTab(tDef.id)
        end)
        studioTabBtns[idx] = tBtn
    end

    local function ReflowStudioTabBar()
        local w = studioTabBar:GetWidth() or 780
        if w < 200 then w = 780 end
        local gap = 4
        local count = #studioTabBtns
        local eachW = math.floor((w - 8 - ((count - 1) * gap)) / count)
        for i, b in ipairs(studioTabBtns) do
            b:ClearAllPoints()
            b:SetHeight(26)
            if i == 1 then
                b:SetPoint("LEFT", studioTabBar, "LEFT", 4, 0)
                b:SetWidth(eachW)
            else
                b:SetPoint("LEFT", studioTabBtns[i - 1], "RIGHT", gap, 0)
                b:SetPoint("RIGHT", studioTabBar, "RIGHT", -4, 0)
            end
        end
    end
    studioTabBar:SetScript("OnSizeChanged", ReflowStudioTabBar)

    tvResetBtn:SetScript("OnClick", function()
        if not tvResetBtn.isConfirming then
            tvResetBtn.isConfirming = true
            tvResetBtn.label:SetText("Confirm Reset?")
            tvResetBtn.label:SetTextColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1)
            tvResetBtn.dsBorder:SetColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.95)
            resetThemeConfirmTimer = C_Timer.NewTimer(3.0, function()
                CancelThemeResetConfirmation(true)
                print(string.format("%s: Suite Studio reset cancelled - no settings were changed.", UI.FormatTwoToneBrand("Suite")))
            end)
            return
        end

        if resetThemeConfirmTimer then
            resetThemeConfirmTimer:Cancel()
            resetThemeConfirmTimer = nil
        end
        tvResetBtn.isConfirming = false
        tvResetBtn.label:SetText(GetDefaultStudioResetLabel())
        tvResetBtn.label:SetTextColor(0.86, 0.88, 0.92, 0.95)

        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        if activeStudioTab == 2 then
            local db = GetDesktopWindowsDBTable()
            db.enabled      = true
            db.sideBySide   = true
            db.dragAnywhere = true
            db.draggable    = true
            db.scrollScale  = true
            if _G.DynamicPrepDB then
                _G.DynamicPrepDB.blizzWinNoAutoClose = true
                _G.DynamicPrepDB.blizzWinDraggable   = true
                _G.DynamicPrepDB.blizzWinScrollScale = true
            end
            ResetAllDesktopWindowsSafe(true)
            ApplyDesktopWindowStatesSafe()
            if gTbl then
                gTbl.showGameMenuSuiteBtn     = true
                gTbl.showGameMenuHudBtn       = true
                gTbl.replaceBlizzardAddonList = true
            end
            if _G.DynamicSuiteDB and _G.DynamicSuiteDB.global then
                _G.DynamicSuiteDB.global.showGameMenuSuiteBtn     = true
                _G.DynamicSuiteDB.global.showGameMenuHudBtn       = true
                _G.DynamicSuiteDB.global.replaceBlizzardAddonList = true
            end
            if addonTable.RefreshGameMenuButtons then addonTable.RefreshGameMenuButtons() end
            if themeView.Refresh then themeView.Refresh() end
            print(string.format("%s: Reset Desktop Windows & Game Menu shortcuts to factory defaults (Side-by-Side, Drag Anywhere, Ctrl+Scroll Scale, and 100%% centred positions).", UI.FormatTwoToneBrand("Suite")))
            return
        end

        if gTbl then
            gTbl.accentKey                = "AUTO_CLASS"
            gTbl.customAccent             = nil
            gTbl.surfaceTheme             = "MIDNIGHT_BLACK"
            gTbl.fontKey                  = "EXPRESSWAY"
            gTbl.fontFamily               = "EXPRESSWAY"
            gTbl.pillFillAlpha            = 0.42
            gTbl.syncExternalUI           = false
            gTbl.syncThemeToToast         = true
            gTbl.syncThemeToHuds          = "all"
            gTbl.layoutSyncScope          = "account"
        end
        if DynamicLoadDB then
            DynamicLoadDB.surfaceTheme = "MIDNIGHT_BLACK"
            DynamicLoadDB.accentKey    = "AUTO_CLASS"
            DynamicLoadDB.customAccent = nil
            DynamicLoadDB.fontKey      = "EXPRESSWAY"
            DynamicLoadDB.fontFamily   = "EXPRESSWAY"
            DynamicLoadDB.pillFillAlpha= 0.42
        end
        activeWorkspaceView = "THEME_STUDIO"
        if addonTable.ApplySuiteThemeAndGeometry then addonTable.ApplySuiteThemeAndGeometry() end
        if f.themeView then f.themeView:Show() end
        if themeView.Refresh then themeView.Refresh() end
        print(string.format("%s: Reset Theme & Typography settings to factory defaults (MIDNIGHT_BLACK, AUTO_CLASS, EXPRESSWAY, 42%% Bold fill).", UI.FormatTwoToneBrand("Suite")))
    end)

    local studioSectionHeaders = { scHdr, surfSecHdr, winSecHdr, shortSecHdr, toastSecHdr }
    local studioVisualBtns = { toastEditHudBtn, toastTestBtn, winResetAllBtn }
    local studioValueControls = {
        surfDropdown, extSyncPills, syncPills, altSyncPills, fillPills,
        winMasterPills, winSideBySidePills, winDragPills, winScalePills,
        gmSuitePills, gmHudPills, replaceAddonListPills,
        toastVisPills, toastBorderPills, toastScaleSlider, toastOpacitySlider,
    }

    themeView.Refresh = function()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local ar, ag, ab = UI.GetActiveAccentColor()
        local accentCol = { r = ar, g = ag, b = ab }
        local curAccentKey = gTbl.accentKey or "AUTO_CLASS"
        local fa = gTbl.pillFillAlpha or 0.42

        ReflowStudioTabBar()
        for idx, tBtn in ipairs(studioTabBtns) do
            local isSel = (idx == activeStudioTab)
            if isSel then
                tBtn.bg:SetColorTexture(ar * fa, ag * fa, ab * fa, 0.98)
                tBtn.dsBorder:SetColor(ar, ag, ab, 0.95)
                tBtn.label:SetTextColor(1, 1, 1, 1)
                tBtn.iconTex:SetVertexColor(ar, ag, ab, 1.0)
            else
                tBtn.bg:SetColorTexture(0.078, 0.090, 0.122, 0.96)
                tBtn.dsBorder:SetColor(0.145, 0.165, 0.212, 0.95)
                tBtn.label:SetTextColor(0.68, 0.74, 0.82, 1)
                tBtn.iconTex:SetVertexColor(0.68, 0.74, 0.82, 0.90)
            end
        end

        if activeStudioTab == 2 then
            tvTitle:SetText("SUITE STUDIO  |cFF64748B-|r  |cFFCBD5E1DESKTOP WINDOWS & MENUS|r")
        else
            tvTitle:SetText("SUITE STUDIO  |cFF64748B-|r  |cFFCBD5E1THEME & TYPOGRAPHY|r")
        end
        if not tvResetBtn.isConfirming then
            tvResetBtn.label:SetText(GetDefaultStudioResetLabel())
        end

        local isTab1 = (activeStudioTab == 1)
        local isTab2 = (activeStudioTab == 2)
        swatchCard:SetShown(isTab1)
        surfaceSectionCard:SetShown(isTab1)
        toastSectionCard:SetShown(isTab1)

        desktopWinSectionCard:SetShown(isTab2)
        shortcutSectionCard:SetShown(isTab2)

        if isTab2 then
            local yieldAddon = GetActiveDesktopWindowYieldAddon()
            if yieldAddon and yieldAddon ~= "" then
                yieldStatusBanner.title:SetText(string.format("Auto-Yield Active: %s Currently Manages Blizzard Windows", yieldAddon))
                yieldStatusBanner.sub:SetText(string.format("DynamicSuite automatically yields Blizzard frame dragging and scaling to %s so both addons coexist cleanly. Open Guided Setup if you prefer DynamicSuite to take priority.", yieldAddon))
                yieldStatusBanner:Show()
                desktopWinSectionCard:ClearAllPoints()
                desktopWinSectionCard:SetPoint("TOPLEFT", yieldStatusBanner, "BOTTOMLEFT", 0, -10)
                desktopWinSectionCard:SetPoint("TOPRIGHT", yieldStatusBanner, "BOTTOMRIGHT", 0, -10)
                tvChild:SetHeight(54 + 10 + 366 + 10 + 220 + 12)
            else
                yieldStatusBanner:Hide()
                desktopWinSectionCard:ClearAllPoints()
                desktopWinSectionCard:SetPoint("TOPLEFT", tvChild, "TOPLEFT", 0, 0)
                desktopWinSectionCard:SetPoint("TOPRIGHT", tvChild, "TOPRIGHT", 0, 0)
                tvChild:SetHeight(366 + 10 + 220 + 12)
            end
        else
            yieldStatusBanner:Hide()
            tvChild:SetHeight(162 + 10 + 379 + 10 + 274 + 12)
        end

        for _, hdr in ipairs(studioSectionHeaders) do
            if hdr and hdr.RefreshAccent then hdr:RefreshAccent() end
        end
        for _, vBtn in ipairs(studioVisualBtns) do
            if vBtn and vBtn.RefreshVisual then vBtn:RefreshVisual() end
        end

        for _, sBtn in ipairs(presetSwatchBtns) do
            local isSel = (curAccentKey == sBtn.pDef.key)
            sBtn.isSelected = isSel
            sBtn.dsBorder:SetColor(1, 1, 1, isSel and 1.0 or 0.22)
        end

        if autoClassBtn then
            autoClassBtn:SetSelected(curAccentKey == "AUTO_CLASS", accentCol)
        end
        if customPickBtn then
            customPickBtn:SetSelected(curAccentKey == "CUSTOM", accentCol)
        end

        local rList = gTbl.recentColors or {}
        for i = 1, 8 do
            local btn = studioRecentBtns[i]
            local c = rList[i]
            if c then
                btn.tex:SetColorTexture(c.r, c.g, c.b, 1)
                btn.dsBorder:SetColor(1, 1, 1, 0.30)
                btn:Enable()
                btn:SetScript("OnClick", function()
                    gTbl.accentKey = "CUSTOM"
                    gTbl.customAccent = { r = c.r, g = c.g, b = c.b }
                    if addonTable.ApplySuiteThemeAndGeometry then addonTable.ApplySuiteThemeAndGeometry() end
                    themeView.Refresh()
                end)
            else
                btn.tex:SetColorTexture(0.08, 0.09, 0.12, 0.65)
                btn.dsBorder:SetColor(1, 1, 1, 0.22)
                btn:Disable()
            end
        end

        if fontDropdown then
            if fontDropdown.SetOptions then fontDropdown:SetOptions(UI.BuildFontDropdownOptions(true)) elseif fontDropdown.RefreshValue then fontDropdown:RefreshValue() end
        end
        for _, ctrl in ipairs(studioValueControls) do
            if ctrl and ctrl.RefreshValue then ctrl:RefreshValue() end
        end

        local scrollW = tvScroll:GetWidth()
        if scrollW and scrollW > 40 then
            tvChild:SetWidth(scrollW)
        end
        UpdateThemeScrollbar()
        C_Timer.After(0, UpdateThemeScrollbar)
    end
    themeView:SetScript("OnShow", function()
        if themeView.Refresh then themeView.Refresh() end
    end)
    for _, tc in ipairs({ swatchCard, surfRow, fontRow, extSyncRow, syncRow, altSyncRow, fillRow, desktopWinSectionCard, winSideBySideRow, winDragRow, winScaleRow, winResetRow, shortcutSectionCard, gmSuiteRow, gmHudRow, replaceAddonListRow, toastSectionCard, toastVisRow, toastBorderRow, toastScaleRow, toastOpacityRow }) do
        table.insert(f.themeCards, tc)
    end
    end

    ----------------------------------------------------------------------------
    -- VIEW F & VIEW G: IN-SUITE CHANGELOG VIEW & SUPPORT VIEW (Items #8, #31)
    ----------------------------------------------------------------------------
    local changelogView = CreateFrame("Frame", nil, workspace)
    changelogView:SetAllPoints()
    changelogView:SetFrameLevel((workspace:GetFrameLevel() or 6) + 2)
    if changelogView.SetClipsChildren then changelogView:SetClipsChildren(false) end
    changelogView:Hide()
    f.changelogView = changelogView

    local supportView = CreateFrame("Frame", nil, workspace)
    supportView:SetAllPoints()
    supportView:SetFrameLevel((workspace:GetFrameLevel() or 6) + 2)
    if supportView.SetClipsChildren then supportView:SetClipsChildren(false) end
    supportView:Hide()
    f.supportView = supportView

    do
    local DS_LIVE_VER = tostring(addonTable.ADDON_VERSION or (_G.DynamicSuite and _G.DynamicSuite.version) or "2.3.2"):gsub("^[vV]", "")
    local DS_LIVE_VER_TAG = "v" .. DS_LIVE_VER
    local DS_CHANGELOG_MODULES = {
        {
            key = "suite",
            tabLabel = "DynamicLoad",
            ver = DS_LIVE_VER_TAG,
            date = "18/11/2026 (Retail 12.1.5)",
            title = "DynamicSuite Hub & DynamicLoad " .. DS_LIVE_VER_TAG,
            subtitle = "Context-Aware Addon Manager, Suite Studio, Desktop Window Manager & Auto-Yield Engine (/dl, /ds)",
            icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_load.tga",
            openView = "DYNAMICLOAD",
            items = {
                { badge = "NEW",      title = "v2.4.0 Release: New DynamicMail Module (/dmail), Smart Quick-Attach Presets, Alt Vault Picker & Quick Gold", desc = "Added DynamicMail as DynamicSuite's 9th dual-mode module with 1-click Inbox Open All, AH Gold, and Items Only collection; Shift+Click inbox quick-loot and Expiring (<3d) alerts; automatic COD and bag-reserve protection; a 4-tab Recipient Picker synced with DynamicBags Alt Vault (class colours, gold balances, Pending Alt Mail Sent badges & Favourite stars); 1-click Quick-Attach presets ([+ Mats], [+ BoE], [+ Warband], [+ Same]) + Quick Gold buttons ([+1k g], [+10k g], [+100k]); Alt + Left-Click Express Multi-Attach; and lifetime telemetry." },
                { badge = "FIXED",    title = "v2.3.2 Release (18/11/2026): Proactive DecorVendor /tm Quarantine Modal & Tier-1 Conflict Protection", desc = "Promoted DecorVendor ('Decor Vendor') to a Tier-1 HARD conflict under DynamicMarker across Guided Setup, module conflict banners, and /ds conflicts, and added a Midnight Pitch Black (#06070A-#090A0D) Obsidian warning modal ('Raid Marker Blocked by Addon Conflict', safely deferred until out of combat) whenever DecorVendor is active on login/reload or whenever World of Warcraft blocks SetRaidTarget() / SetRaidTargetIcon(). Includes a 1-click 'Disable <Addon> (Set to Never)' button across all DynamicLoad zone profiles, session-throttled Dismiss, and plain-English instructions to completely Exit & Restart World of Warcraft." },
                { badge = "FIXED",    title = "v2.3.2 Release (18/11/2026): Post-Combat MacroFrame Protection & Automatic Icon Grid Refresh", desc = "Protected the Blizzard Macros window (MacroFrame) inside DesktopWindows during combat lockdown so opening or viewing Macros mid-fight never detaches, moves, rescales, or hides the window, and added an automatic post-combat refresh on PLAYER_REGEN_ENABLED so all General and Character-Specific macro icons reappear cleanly across DIALOG/HIGH focus transitions and ElvUI Blizzard skinning without switching tabs or reopening the window." },
                { badge = "FIXED",    title = "v2.3.2 Release (18/11/2026): Universal Mousewheel Scrolling Across All 32 Managed Blizzard Windows", desc = "Restored smooth normal mousewheel scrolling across Collections, Achievements, Professions, Macros, Character/Reputation, Adventure Guide, Talents & Spellbook, and all 32 managed Blizzard Desktop Windows by restricting Ctrl+Scroll session scaling to the 28px top title bar and activating the window-wide Ctrl+Shift+Scroll permanent scale overlay strictly while Ctrl+Shift is held." },
                { badge = "FIXED",    title = "v2.3.1 Fix (18/11/2026): Item Socketing Esc Close, DIALOG-vs-HIGH Click-to-Front Layering, and Adventure Guide Mousewheel Scrolling", desc = "Marked session-bound interaction panels (Item Socketing, Trade, Gossip, Quest, Item Upgrade, and Revival Catalyst) as non-restorable so pressing Esc never leaves an empty Item Socketing window behind (first Esc closes Item Socketing cleanly, second Esc closes Character Info); placed the top-focused managed window on DIALOG strata and all unfocused open panels on HIGH strata (with SetToplevel disabled and root FrameLevel clamped to 1) so whichever window you click or open always sits completely on top while Cooldown Manager icons never bleed through focused or unfocused panels and Character gear slots, EllesmereUI stats panes, and TalentLoadoutManager overlays stay neatly layered; and stopped the Adventure Guide root frame and passive border chrome from swallowing mousewheel input so scrolling boss overviews, abilities, loot lists, and lore works smoothly again while preserving Ctrl+Scroll and Ctrl+Shift+Scroll scaling when Ctrl is held." },
                { badge = "NEW",      title = "v2.3.0 Release: 2-Tab Suite Studio (Theme & Typography + Desktop Windows & Menus) & /ds windows", desc = "Upgraded the Left Suite Rail 'Theme & Font' workspace into the 2-tab 'Suite Studio' (/ds studio, /ds theme, /ds windows, /ds win), pairing 'Theme & Typography' (Tab 1: 17 Accent Swatches, Surface Theme, Font Family, External UI Sync, and Toast HUD) with 'Desktop Windows & Menus' (Tab 2: Core Blizzard Desktop Window Manager, External Mover Auto-Yield Status Banner, and relocated Game Menu & Options Shortcuts)." },
                { badge = "NEW",      title = "v2.3.0 Release: Core Blizzard Desktop Window Manager (32 Panels, Windowed Quest Log, On-Screen Clamping & Empty-Space Drag)", desc = "Migrated the Blizzard Desktop Window Manager from DynamicPrep into DynamicSuite Core (DynamicSuiteDB.global.desktopWindows with automatic one-time migration from DynamicPrepDB) so window management stays active even when DynamicPrep is disabled; brought windowed WorldMapFrame / Quest Log (L) into side-by-side coexistence across all 32 managed panels; enforced scale-aware ClampDesktopWindowOffset on-screen clamping on drag, show, resize, scale, and display changes so windows never get stuck off-screen; enabled modifier-free Left-Click dragging from any empty background space (no Alt key needed) with interactive child widget protection; and added GLOBAL_MOUSE_DOWN click-to-raise z-order layering with top-most Esc dismissal." },
                { badge = "UI",       title = "v2.3.0 Release: Central Popover Auto-Close Registry (UI.RegisterPopupCloser) & 3-Way Interactive Obsidian Scrollbars", desc = "Added UI.RegisterPopupCloser(key, closeFn) invoked automatically by UI.CloseAllPopups() across window close, minimise, combat collapse, HUD Edit Mode entry, and module/tab switches; hooked owner button OnHide across all dropdowns and popovers; and upgraded all scrollbars across DynamicSuite (Suite Studio, dsDropdownPopup, Guided Setup, and Global Smart Search) and all 8 modules to full 3-way interaction (Mousewheel, Left-Click & Drag thumb with cursor-release guard and Suite Accent highlight, and Left-Click track jump)." },
                { badge = "NEW",      title = "Shared Media Discovery (LibSharedMedia-3.0, DBM, EXBOSS, BigWigs, WeakAuras, ElvUI) & Searchable Grouped Pickers", desc = "Upgraded Theme & Font Studio (and standalone DynamicMarker) plus DynamicChat to scan LibSharedMedia-3.0, DBM, EXBOSS, BigWigs, WeakAuras, and ElvUI for custom fonts and sounds alongside Built-in and Blizzard options, added grouped dropdowns with live search filtering and pcall-guarded previews, and added clean runtime fallback (Expressway for fonts, Blizzard Raid Warning for sounds) if an external pack is disabled." },
                { badge = "FIXED",    title = "Curated Blizzard Default Chat Sounds, Self-Whisper Alerts & LibSharedMedia-3.0 Cleanups (DynamicChat)", desc = "Removed temporary .wav chat sound files and LibSharedMedia .wav registration in favour of 7 native Blizzard SOUNDKIT alerts (Blizzard Raid Warning, Blizzard Whisper, Blizzard Battle.net, Blizzard Ready Check, Blizzard Map Ping, Blizzard Auction Bell, and Blizzard Quest Complete) played via PlaySound / PlaySoundFile, added CHAT NOTIFICATION SOUNDS controls in Tab 3 with clean defaults (Blizzard Whisper, Blizzard Battle.net, Blizzard Map Ping, Blizzard Raid Warning, and Say & Yell off), compact [Play] preview buttons, legacy key migration, and restored self-whisper alert playback on incoming WHISPER / BN_WHISPER messages while preserving self-suppression on group and public channels." },
                { badge = "NEW",      title = "v2.2.0 Release: DynamicPrep Blizzard Window QoL (Side-by-Side, Header/Alt+Drag, Click-to-Raise, Ctrl+Scroll Scale & Multi-Addon Coexistence)", desc = "Added Tab 3 Blizzard Window Quality of Life controls in DynamicPrep so Character, Inspect, Dressing Room, Talents & Spells, Group Finder, Great Vault, Guild & Communities, Collections, Adventure Guide, Professions, Achievements, Item Upgrade, Calendar, Macros, Merchant, Mail, and Auction House stay open side-by-side without trapping Escape (with header Pin buttons and click-to-raise layering), remember dragged header or Alt + Left-Drag anywhere positions across reloads, scale via Ctrl+Scroll (temporary session) or Ctrl+Shift+Scroll (permanent 70%-140% with Obsidian/Blaze-Orange toast), reset on header Right-Click or [Reset All Windows], exclude World Map and Game Menu cleanly out of combat, and yield silently with dynamic banner detection when BlizzMove, DeModal, MoveAny, EllesmereUI, Leatrix Plus, or ElvUI frame management is active." },
                { badge = "FIXED",    title = "v2.1.2 Release: DynamicPrep Midnight Season 2 Enchantable Slot List Fix", desc = "Updated DynamicPrep's equipped gear enchant scanner to remove false-positive missing-enchant alerts on Cloak and Wrist (which do not have enchants in Midnight) and added Head and Shoulder to the Midnight Season 2 enchantable slot list (Head, Shoulder, Chest, Legs, Feet, Ring 1, Ring 2, Main Hand, and Off-Hand weapons)." },
                { badge = "NEW",      title = "v2.1.1 Release: 3-Row 560x110 HUD Edit Inspector (Row 3 Live Appearance Bar), First-Open Left Rail & Right Workspace Anchor Fix", desc = "Upgraded DynamicSuiteEditModeModal and standalone DynamicMarkerEditModeInspector into a unified 560x110 3-row draggable inspector dock with live Row 3 controls across all 6 HUDs (Opacity 20%-100%, Border Style Accent/Dark/None, and Orientation Horiz/Vert with instant screen-bounds re-clamping); fixed first-open /ds Left Rail & first-click [+ HUD] mover initialisation; and anchored leftRail and workspace directly to DynamicSuiteMainFrame with explicit SetSize fallbacks, SetClipsChildren(false) on outer containers, and elevated FrameLevels so the right-hand DynamicLoad and peer module workspaces always render cleanly." },
                { badge = "NEW",      title = "v2.1.0 Release: Compact Draggable 560x74 HUD Edit Inspector, Hidden-By-Default Movers & Unified [Edit HUD] Cards", desc = "Redesigned the HUD Edit Mode dock into a compact 560x74 2-row draggable toolbar with a HUD Selector Dropdown (green/red status dots), non-truncated Hidden/Shown pills, Grid/Reset/Back to Suite, X/Y coordinates & nudges, Center X/Y, Scale slider (60%-150%), and 60px off-screen fail-safe edge clamping; hid disabled/Off HUD movers by default on entering HUD Edit Mode with temporary 'HIDDEN (Click Shown to Enable)' previewing when explicitly selected; and standardised Obsidian/Blaze-Orange [Edit HUD] buttons + shared ON-SCREEN ALERT & TELEPORT TOAST HUD controls across DynamicLoad, Theme & Font Studio, DynamicGroup, DynamicPrep, DynamicMarker, and DynamicChat." },
                { badge = "FIXED",    title = "v2.1.0 Release: World Flare Hardware Keybinds & Immediate Telemetry / Tab-Label Sync", desc = "Anchored DynamicMarker's secure World Flare cycle/clear buttons on-screen, removed the button-name override in SecureHandlerWrapScript so LeftButton dispatches /wm [@cursor] and /cwm all reliably in and out of combat, added Right-Click keybind clearing, and wired instant top-bar telemetry and dynamic 'World Flare Keys (...)' sub-tab updates on rebind, clear, or reset." },
                { badge = "FIXED",    title = "v2.0.9 Release: World Flare Hardware Keybinds & Custom Sequence Order", desc = "Added SecureHandlerWrapScript custom World Flare Cycle Sequence support and floating World Flare Bar icon reordering." },
                { badge = "FIXED",    title = "v1.9.9 Release: Canonical UIParent-Local HUD Coordinates, Custom Dark-Obsidian Coexistence Modal & Unified HUD Edit", desc = "Enforced a canonical UIParent-local coordinate contract for TargetBar and FlareBar (dividing by barScale strictly inside DM:SetBarCenterPoint after applying SetScale/SetSize and before SetClampedToScreen(true) so top/bottom/corner edge positions never drift across /reload at 0.70, 1.00, or 1.30 scales), replaced Blizzard's StaticPopup with a custom dark-obsidian coexistence reload modal (DynamicSuiteMarkerConflictModal with #0B0D12 backdrop, Blaze Orange #F97316 accent bar, flat Reload UI / Later buttons, ESC dismissal, and combat deferral), and suppressed the duplicate legacy HUD Edit popup inside DynamicSuite." },
                { badge = "FIXED",    title = "v1.9.8 Release: HUD Edit Edge-Drag Persistence & Flush (0, 0) Chat Clamping", desc = "Fixed Target Icon Bar and World Flare Bar coordinate round-trips across drag, Exit Edit Mode, UI_SCALE_CHANGED, and /reload by syncing bar scale and orientation before clamping and canonicalising CENTER anchors across Suite & standalone DynamicMarker; and fixed DynamicChat flush bottom-left (0, 0) positioning by disabling ChatFrame1 C++ SetClampedToScreen, measuring only the visible chat container via GetVisibleContainerExtents(), and canonicalising CHAT to BOTTOMLEFT outer-container coordinates." },
                { badge = "NEW",      title = "v1.9.7 Release: CurseForge Dual-Release Pipeline (DynamicSuite 1804382) & Hardened Coexistence", desc = "Wired full DynamicSuite (Project ID 1804382) alongside standalone DynamicMarker (Project ID 1331651) in the automated release workflow, updated all Support panels and public docs to the live CurseForge links, added code-accurate storefront documentation, and hardened ShouldYieldToOtherInstall dual-mode version coexistence across all 8 modules." },
                { badge = "FIXED",    title = "v1.9.6 Release: DynamicBags Bank/Guild Bank & Merge Hardening + Suite/Standalone Parity", desc = "Eliminated post-/reload Bank & Guild Bank flashes with SetScale suppression and GUILDBANKFRAME_OPENED handling, preserved unqueried Guild Bank tab snapshots across sessions while reflecting live withdrawals down to 0 items, enforced strict weak ordering in Sort: A-Z, hardened Drop-Anywhere slot placement, synced DynamicBags Smart Search entries, and upgraded standalone DynamicMarker's Changelog modal to stream live entries dynamically." },
                { badge = "UI",       title = "Standalone DynamicMarker Dock Parity & DynamicSuite CurseForge URL", desc = "Added the bottom-right [Reload UI] button, Opacity slider, and Scale slider to standalone DynamicMarker's footer dock, upgraded its Support modal to read-only Ctrl+C EditBoxes, and updated DynamicSuite's Support view CurseForge link to https://www.curseforge.com/wow/addons/dynamicsuite." },
                { badge = "FIXED",    title = "First-Open ESC > Options > AddOns Blank Shell & Left-Rail Rendering", desc = "Initialised RefreshLeftRailLayout() during CreateMainConfigUI(), routed ApplySuiteThemeAndGeometry() through RefreshLeftRailLayout() and all workspace view refreshes, added a guarded C_Timer.After(0, ...) post-layout refresh and Raise() on DynamicSuiteMainFrame:OnShow, and hardened HideSettingsPanelSafe() + Settings canvas OnShow theme sync so opening via ESC > Options > AddOns > DynamicSuite renders all 8 left-rail modules, active workspace, and surface theme on the very first open." },
                { badge = "FIXED",    title = "Universal 'Never' ('FROZEN') Persistence Across All Addons & Registry-Driven Conflict Resolution", desc = "Normalised all security and zone assignment operations to canonical folder names (ResolveCanonicalAddonName); made SetAddonFrozen(name, true) atomically persist 'FROZEN' across DynamicLoadDB/globalData/charData, wipe all 5 zone tables, and call C_AddOns.DisableAddOn; merged DynamicLoadDB root and globalData security tables in SyncScopeBindings() and used in-place wipe() in RestoreStash() so SavedVariables deserialization never reverts 'FROZEN' states on /reload; retired RecoverEllesmereUIState(); protected individual child 'FROZEN' / 'LOCKED' states from parent cascades; added EnforceFrozenAddonsDisabled() + a C_AddOns.EnableAddOn runtime guard; made Auto-Yield 100% read-only; treated unloaded or 'FROZEN' external addons as inactive; and added a 1-click [Use Dynamic] -> [Reload UI Now] button on soft Auto-Yield banners." },
                { badge = "FIXED",    title = "DynamicChat HUD Mover Literal '|r' Fix, EllesmereUIChat Soft-Yield & 1:1 Geometry Sync", desc = "Fixed literal '|r' escape sequences in HUD Edit Mode mover readouts by correcting escaped separator pipes ('|cFF64748B|||r' and '|cFF475569|||r'); suppressed the DynamicChat HUD mover and ChatFrame1 position overrides whenever DynamicChat is disabled or soft-yielding layout to an external chat addon (EllesmereUIChat, ElvUI Chat, Prat-3.0, Chattynator, LS: Glass); locked the HUD mover and DynamicChat backdrop container 1:1 to ChatFrame1's scale, anchor, and bounds; and lowered the Chat HUD mover backdrop alpha (0.52 selected / 0.40 unselected) so chat text remains clearly visible while positioning." },
                { badge = "FIXED",    title = "In-Combat /ww, /rl & /lg Shortcuts, Greyed-Out Ctrl-to-Release Death Button & Modifier-Free [DynamicHeal] Macro", desc = "Enabled /ww (Target Whisper), /rl (Reload UI), and /lg (Leave Group via C_PartyInfo.LeaveParty()) with combat-safe pcall + issecretvalue guards; hooked StaticPopup_OnUpdate and StaticPopup1..4 OnUpdate/OnShow/OnHide so the DEATH StaticPopup 'Release Spirit' button stays greyed out ('Hold CTRL to Release') until Ctrl is held and restores cleanly on hide/revive; and stripped all [mod]/[nomod] conditionals from [DynamicHeal] in favour of a modifier-free sequential fallback (#showtooltip + /castsequence reset=combat item:<HealthstoneID>, item:<HealPotID>) with out-of-combat cooldown reordering." },
                { badge = "FIXED",    title = "EvaluateAddonItemEffectiveState Nil Call Crash Fix in DynamicLoad Hub Tree", desc = "Fixed 'attempt to call a nil value' at DynamicLoad.lua:4724 inside EvaluateAddonItemEffectiveState when evaluating the DynamicSuite parent hub item (isDynamicSuiteHub = true) and its child modules across scoped do ... end chunks by declaring a local IsSuiteModuleExplicitlyDisabled helper in Section 2 (DynamicLoad_UI) with addonTable / DynamicSuiteDB fallbacks and defensive nil guards across GetParentSuiteStats and EvaluateAddonItemEffectiveState." },
                { badge = "NEW",      title = "Unified In-Combat Raid Buff (X/Y + MISSING) Readiness Tracker Strip Override", desc = "Removed the standalone combat banner (DynamicPrepCombatBuffAlertFrame) and unified in-combat missing class raid buffs (Mark of the Wild, Fortitude, Intellect, Skyfury, Battle Shout, Blessing of the Bronze) directly into the Readiness Tracker Strip icon format (icon + border + top-right X/Y count like 16/17 + bottom MISSING label) during combat, while suppressing personal consumables mid-fight, guarding all 12.x Midnight unit/aura checks against secret values, excluding unaccepted Battle Res targets until alive, and auto-hiding immediately on rebuff." },
                { badge = "FIXED",    title = "RefreshReadinessTrackerStrip Crash Fix, Layout Builder Restoration & Auto-Yield Banner Button Sizing", desc = "Fixed the nil-index Lua error in DynamicPrep:RefreshReadinessTrackerStrip by moving CLASS_RAID_BUFFS, PARTNER_RAID_BUFFS, SYMBIOTIC_SPELL_IDS, and SafeIsPlayerSpellKnown above all calling functions, adding defensive nil guards on all table/slot lookups, and isolating RefreshReadinessTrackerStrip in pcall so Tab 1's Top Info Bar Layout Builder capsule labels always render; and updated the module Auto-Yield banner action button to 'View Conflicts' with auto-expanding width so it never truncates." },
                { badge = "FIXED",    title = "Guided Setup Conflict Scanner Deduplication, Left-Rail Badge Fix & 3-Button Auto-Yield UX", desc = "Deduplicated conflict scanner results by (externalAddon .. '_' .. suiteModule) so DialogueUI <-> DynamicPrep never appears twice; restricted the Left Suite Rail 'Guided Setup' warning count badge strictly to unresolved HARD conflicts while rendering a non-overlapping 6x6 status dot for SOFT Auto-Yields; restyled SOFT Auto-Yield cards with a calm emerald/cyan '[Auto-Yield Active]' / '[Active & Synced]' border and badge alongside 3 balanced action buttons ('Keep Both (Auto-Yield)', 'Use [DynamicModule] Only', and 'Use [ExternalAddon] Only') persisted in SavedVariables; and shortened the 9 horizontal wizard step tab labels ('1. Conflicts', '2. Load', '3. Prep', '4. Marker', '5. Zoom', '6. FPS', '7. Group', '8. Bags', '9. Chat') so they never truncate." },
                { badge = "NEW",      title = "External Addon Conflict Detector & 2-Tier Auto-Yield Engine (/ds conflicts)", desc = "Implemented a curated 8-module External Addon Conflict Registry (DynamicBags, DynamicChat, DynamicPrep, DynamicGroup, DynamicMarker, DynamicZoom, DynamicFPS, DynamicLoad), pcall-wrapped Smart Sub-Module Detection for ElvUI (ElvUI[1].private.bags.enable / ElvUI[1].private.chat.enable) and Leatrix_Plus (_G.LeaPlusDB), HARD warning banners with 1-click Disable + Reload UI or Open DynamicLoad actions, SOFT Auto-Yield status notes (e.g. DialogueUI gossip/camera handoff), non-spam login detection, and the '/ds conflicts' diagnostic command." },
                { badge = "NEW",      title = "Unified v1.3.0 Master Workspace, Single-Source .toc Metadata & Version-Aware Duplicate-Install Guard", desc = "Consolidated the master editable workspace into D:\\DriveSync\\DynamicSuite with 1:1 deployment to WoW Retail and Google Drive sync, replaced hardcoded version strings across DynamicSuite and all 8 feature modules with live C_AddOns.GetAddOnMetadata(ADDON_FOLDER, 'Version') resolution so all Top Headers, Standalone headers, and in-game Changelog tabs stay in lockstep automatically, and upgraded the dual-mode duplicate-install guard with semantic version comparison (CompareSemVer) so the newer version always takes priority." },
                { badge = "NEW",      title = "Single-Entry DynamicSuite Consolidation & Dual-Mode Architecture", desc = "Consolidated all 8 feature modules (DynamicLoad, DynamicPrep, DynamicMarker, DynamicZoom, DynamicFPS, DynamicGroup, DynamicBags, DynamicChat) under a single WoW AddOn List entry (DynamicSuite\\Modules\\) while maintaining 100% dual-mode standalone compatibility via private per-module namespaces, dynamic ADDON_FOLDER asset resolution, dual ADDON_LOADED guards, and soft Left-Rail module enable/disable." },
                { badge = "FIXED",    title = "Locked Canonical Left Suite Rail Module Icons (icon_mod_*.tga Across All 8 Modules)", desc = "Prevented peer module registration descriptors from overwriting SUITE_MODULE_LIST's canonical 32x32 vector module icons (icon_mod_load.tga, icon_mod_marker.tga, icon_mod_zoom.tga, icon_mod_fps.tga, icon_mod_prep.tga, icon_mod_group.tga, icon_mod_bags.tga, icon_mod_chat.tga) with generic root D-emblem icon.tga paths in DynamicSuite.RegisterModule, UI.GetModuleIconPath, CreateRailModuleCard, EnsureRailDragGhost, RefreshLeftRailLayout, and RefreshLeftRailVisuals." },
                { badge = "FIXED",    title = "Labyrinth Delve Toast Anti-Spam Gate (Post-Loading-Screen Only)", desc = "Restricted automatic DynamicLoadToastFrame popups strictly to real post-loading-screen transitions (LOADING_SCREEN_ENABLED / LOADING_SCREEN_DISABLED + PLAYER_ENTERING_WORLD with a deduplicated 0.65s settle timer and per-load session latch), preventing seamless chamber crossings (ZONE_CHANGED_NEW_AREA, ZONE_CHANGED, ZONE_CHANGED_INDOORS, SCENARIO_UPDATE) or post-combat PLAYER_REGEN_ENABLED flushes from re-popping dismissed Toasts inside Labyrinth Delves." },
                { badge = "FIXED",    title = "Smart Search Stabilisation, Core/UI Field Alignment & Shared Bridge Hardening", desc = "Resolved the DynamicSuite_UI.lua:10191 nil crash on /ds (replacing non-existent CreateCardContainer and Create1PxBorder calls with UI.CreatePixelBorder and fixing UI.SolidTex factory calls across EnsureSearchHighlightFrame, resultsTrack, resultsThumb, and GetOrCreateResultCard), aligned NormalizeSearchEntry and ScoreSearchEntry fields (_kwLower, _tabLower, _catLower, seedOrder, categoryLabel, breadcrumb, viewKey, targetTitle, and MODULE_ADDON_MAP), wired Enter-key TriggerTopResult and collapsed sub-drawer auto-expansion, protected addonTable.GetSuiteGlobal and addonTable.PopulateBrandLogo in DynamicLoad_Core.lua, and verified all 9 suite addons in a headless Lua 5.1 WoW runtime harness." },
                { badge = "NEW",      title = "Global Smart Search, Intent Index & 1-Click Jump-and-Highlight Router (Pass 2)", desc = "Added the Left Suite Rail 'Search all features...' bar (/ds search <query>) and Global Feature Finder workspace indexing 198 settings across DynamicSuite and all 8 peer modules with plain-English intent synonyms, 6 live-counted category filter pills (All, Combat & Raid, FPS & Camera, HUD & Look, Bags & QoL, Group & Chat), installation-aware filtering, 1-click module/sub-tab/drawer routing, auto-scroll, and a 2.2s Suite Accent highlight pulse." },
                { badge = "FIXED",    title = "Cross-TOC Namespace Bridge & Lua 5.1 AST Hardening (DynamicSuite / DynamicLoad)", desc = "Fixed syntax errors in DynamicLoad_Core.lua:2178 and DynamicSuite_UI.lua:8748, forward-declared ApplyEnvironmentContext in DynamicLoad_Core.lua, added DynamicSuite to SUITE_MODULES auto-enable protection, updated all DynamicSuite font/icon paths to Interface\\AddOns\\DynamicSuite\\..., and verified all 11 Lua files with a strict Lua 5.1 AST & scope compiler." },
                { badge = "NEW",      title = "Game Menu & Blizzard Options Shortcuts + Scrollable Theme & Font Studio", desc = "Added 'DynamicSuite' and 'DynamicSuite HUD' shortcut buttons to the Esc Game Menu positioned cleanly above Log Out / Return to Game, added 'Open DynamicSuite HUD (/ds hud)' to Blizzard Options -> AddOns -> DynamicSuite, wrapped Theme & Font Studio in a smooth Obsidian ScrollFrame with bordered 'SURFACE, TYPOGRAPHY & VISUAL SYNC' and 'GAME MENU & OPTIONS SHORTCUTS' L-bracket sections, and added live toggles for Game Menu buttons and Blizzard AddOn List replacement." },
                { badge = "UI",       title = "Suite-Wide 'Sleek Precision Track' Sliders & Option 3 Negative Pills", desc = "Standardized all sliders across all 8 DynamicSuite modules to the 256x26px Sleek Precision Track (4px #090A0D recessed track, live Suite Accent FillBar, 6x14px Crisp White/Silver blade thumb brightening to Suite Accent on hover/drag, 52px right-aligned Suite Accent readout, 144+ FPS smooth drag with lastCommittedValue guard, click-to-seek, and mousewheel fine-tuning), and implemented Option 3 styling (#1E2430 fill, #64748B border, #E2E8F0 text, and 1.5px #F87171 bottom OffBar) for selected Off / Disabled / None / Muted / Hidden pills." },
                { badge = "FIXED",    title = "[Suite Core] Protection for DynamicChat & Auto-Enable Guard", desc = "Added DynamicChat to PROTECTED_ADDONS, CORE_SUITE_ADDONS, and EnforceProtectedSuiteModules() so zone profile switches never disable DynamicChat unless explicitly turned off via the Left Suite Rail switch." },
                { badge = "NEW",      title = "2-Tier Chat Conflict Scanner & Shared-Hook Auto-Yield", desc = "Registered DynamicChat's 8 Direct Replacement conflicts (Chattynator, Prat-3.0, BasicChatMods, Chatter, LS: Glass, Glass, PhanxChat, DejaChat) and 4 Partial Shared-Hook conflicts (WIM, Leatrix Plus, ElvUI, WindTools) into Guided Setup & the Left Rail conflict badge." },
                { badge = "UI",       title = "8-Module Single-Responsibility Architecture & QoL Boundaries (Section 3)", desc = "Reorganized Suite QoL boundaries across DynamicPrep, DynamicBags, and DynamicGroup so every setting has a single canonical home with zero duplication: Merchant, Loot & Delete automation moved to DynamicBags Tab 3, Midnight Omni Folio moved to DynamicPrep Tab 2, and Auto-Insert Mythic+ Keystone consolidated exclusively in DynamicGroup Tab 3." },
                { badge = "UI",       title = "Unified 'By Zone' / 'Always' / 'Never' Load-State Terminology", desc = "Standardized all addon load-state strings across inline row pills, suffix tags ([Always] in #FACC15 Gold, [Never] in #38BDF8 Ice-Blue, and [Suite Core] / [Suite Protected] for DynamicSuite modules), Ctrl + Right-Click popover menus, Top Filter Bar pills, legend strip, and mouseover tooltips." },
                { badge = "UI",       title = "Clash-Proof Semantic Filter Bar Styling (All, Pending, Always, Never)", desc = "Unselected filter pills now pair dark #14171F backgrounds and #252A36 borders with semantic text accents (Silver for All, Emerald #34D399 for Pending > 0, Gold #FACC15 for Always, and Ice-Blue #38BDF8 for Never), reserving filled backgrounds, bright 1px borders, and crisp white text strictly for the selected filter pill so Gold or Cyan Suite Accents never clash." },
                { badge = "FIXED",    title = "Individual Addon Tooltip Cleanup", desc = "Removed the stray 'Left-Click Row / [-]: Expand or Collapse Group' instruction from individual addon tooltips so it only appears when hovering an actual collapsible Category Header row." },
                { badge = "UI",       title = "6x6px Zone Tab Indicator Parity & Command-Prefix Tooltip Standard", desc = "Matched the Outdoor tab's cyan Location square (locationPin) to the exact 6x6px pixel-snapped dimensions of the green Loaded square (loadedDot) and top header status capsule. Standardized all mouseover tooltips across DynamicLoad and all 7 suite modules via UI.FormatTooltipCommand so only command prefixes (Left-Click:, Right-Click:, Ctrl + Right-Click:) and state badges are colored while explanatory descriptions render in Silver-White (#E2E8F0)." },
                { badge = "NEW",      title = "Disentangled Physical Location & Loaded Profile Architecture", desc = "Separated current physical zone detection from active addon session profiles via distinct SavedVariables state tracking (DynamicLoadDB.loadedProfile and DynamicLoadDB.manualOverride). Exposed inspection APIs: addonTable.GetLoadedProfile(), addonTable.GetPhysicalLocation(), addonTable.IsManualOverrideActive(), and addonTable.ResumeAutoSwitch()." },
                { badge = "FIXED",    title = "Protected Manual Profile Overrides Across Reloads", desc = "Manual profile activations are preserved across UI reloads while players remain outdoors without Auto-Switch overwriting them; seamlessly transfers back to Auto-Switch upon physically entering any instance (Dungeons, Raids, Delves, or PvP)." },
                { badge = "UI",       title = "Redesigned Header Status Capsule & 1-Click Auto-Switch Resume", desc = "Split ambiguous zone readouts into two distinct color-coded badges: Green 'Loaded: <Profile> [Manual]/[Auto]' and Cyan 'Location: <Zone>'. Clicking the status capsule while a manual override is active opens an interactive prompt to resume automatic zone switching." },
                { badge = "UI",       title = "Dual-Indicator 5-Zone Tab Badges", desc = "Upgraded top zone tabs with two independent visual indicators: a crisp 6x6 green square (loadedDot) on the right of the label for the currently loaded profile, and a matching 6x6 cyan square (locationPin) on the left of the label for the physical location, keeping tab checklist editing selection cleanly separated." },
                { badge = "UI",       title = "Standardized Suite-Wide Bottom Footer Wording", desc = "Unified the bottom dock footer status readout across all 7 modules and studio views to 'Active Module: <ModuleName>   |   Slash: <SlashCommand>', eliminating inconsistent 'Right-Click Zone to Activate & Reload | /dl' and asterisk separators." },
                { badge = "UI",       title = "Unified 2-Line Tall L-Bracket Section Headers (Section 2.4)", desc = "Standardized 36px 2-Line Tall L-Bracket Section Headers (3x34px Suite Accent vertical bar, 11pt uppercase title on Line 1, 10pt Slate-Silver explanatory subtitle on Line 2, and 1px connected horizontal underline) across all 7 modules in DynamicSuite." },
                { badge = "FIXED",    title = "Resolved /ds & /dl Client Freeze ('Not Responding')", desc = "Eliminated infinite mutual recursion in ApplySuiteThemeAndGeometry (dlModuleDescriptor.ApplyTheme self-notification guard), cached font family path resolution, removed redundant SetText reflow loops on window open, and replaced unescaped name:find regex in BuildAddonHierarchy with literal prefix comparison." },
                { badge = "FIXED",    title = "Hardened UI.CreatePixelBorder & Legend Swatch Construction", desc = "Added a frame.CreateTexture safety guard in UI.CreatePixelBorder and converted legendStrip swatch samples from Texture objects to Frame containers so CreateMainConfigUI never aborts mid-construction." },
                { badge = "UI",       title = "Design System Standardisation (DESIGN_SYSTEM.md)", desc = "Updated defaults to AUTO_CLASS accent, MIDNIGHT_BLACK surface, and 0.42 pill fill alpha; added UI.CreateSquareCheckbox, UI.CreateSectionHeader L-brackets, 3-button inline load mode pills, 5-zone full-width top bevel track, and geometric close buttons." },
                { badge = "NEW",      title = "Native 7-Tab Suite Changelog & Master Registry", desc = "Master 7-tab Changelog registry covering all suite modules (DynamicLoad, DynamicMarker, DynamicZoom, DynamicFPS, DynamicPrep, DynamicGroup, DynamicBags) with color-coded badges, unread alert tracking, and 1-click workspace navigation." },
                { badge = "NEW",      title = "7-Step Interactive Guided Setup Wizard", desc = "Dynamically adapts to your active modules with 1-click conflict resolution (Auto-Yield / Disable & Freeze), Smart Addon Scan, and hardware/spec preset cards." },
                { badge = "NEW",      title = "Unified Top-Right Scope Switcher & [+ HUD] Header Parity", desc = "Added [Global v] / [<CharName> v] scope switcher and 68x26 [+ HUD] button in the top-right header, matched 1:1 with floating bar and HUD Edit Mode." },
                { badge = "FIXED",    title = "Theme & Font Studio Dropdowns, Swatches & EUI Sync", desc = "Fixed CanSetFontPath false-positive font probing, elevated dropdown borders so the last option never clips, and added 4-sided borders to Recent Custom Colors." },
            },
        },
        {
            key = "marker",
            tabLabel = "DynamicMarker",
            ver = DS_LIVE_VER_TAG,
            date = "18/11/2026 (Retail 12.1.5)",
            title = "DynamicMarker " .. DS_LIVE_VER_TAG,
            subtitle = "Modifier-Free Target Marking, World Flares & Multi-Spec Interrupt Macro (/dm)",
            icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_marker.tga",
            openModule = "DynamicMarker",
            items = {
                { badge = "FIXED",    title = "v2.3.2 Release (18/11/2026): Proactive DecorVendor /tm Quarantine Modal & Tier-1 Conflict Protection", desc = "Promoted DecorVendor ('Decor Vendor') to a Tier-1 HARD conflict across bundled DynamicSuite and standalone DynamicMarker, and added a Midnight Pitch Black (#06070A-#090A0D) Obsidian modal ('Raid Marker Blocked by Addon Conflict', safely deferred until out of combat) whenever DecorVendor is active on login/reload or whenever World of Warcraft blocks SetRaidTarget() / SetRaidTargetIcon(). Provides 1-click 'Disable <Addon> (Set to Never)', session-throttled Dismiss, updated [DynamicMark] Macro Setup guidance, and clear instructions to completely Exit & Restart World of Warcraft." },
                { badge = "UI",       title = "v2.3.0 Release: 3-Way Interactive Obsidian Scrollbars & Central Popover Auto-Close", desc = "Upgraded DynamicMarkerDropdownPopover, embedded sub-tab pages, and the standalone Changelog modal to full 3-way interactive 4px Obsidian scrollbars (Mousewheel, Left-Click & Drag thumb with Suite Accent highlight, and Left-Click track jump), hooked OnHide on all dropdown and HUD selector owner buttons, and registered DM:CloseDropdownMenu() with UI.RegisterPopupCloser." },
                { badge = "IMPROVED", title = "v2.2.0 Release: Version & Storefront Lockstep Parity", desc = "Synchronised version metadata and duplicate-install coexistence checks cleanly to v2.2.0 for Retail 12.1.5 (Interface 120105, Midnight Season 2)." },
                { badge = "NEW",      title = "v2.1.1 Release: 3-Row 560x110 HUD Edit Inspector (Row 3 Live Appearance Bar) & Mover Visibility Fix", desc = "Upgraded DynamicMarkerEditModeInspector into a 560x110 3-row draggable inspector dock with live Row 3 appearance controls for Focus Icons and World Flares: Opacity slider (20%-100%, step 5%), Border Style segmented pills (Accent | Dark | None), Orientation toggle (Horiz | Vert) with automatic screen-bounds re-clamping, and full [Reset] recovery." },
                { badge = "FIXED",    title = "v2.1.0 World Flare Hardware Keybinds & Instant Telemetry / Sub-Tab Label Refresh", desc = "Anchored the secure flare cycle/clear buttons on-screen (1x1, alpha 0, non-mouse-blocking), removed the SecureHandlerWrapScript button override return so LeftButton reliably runs /wm [@cursor] and /cwm all cleanly in and out of combat, added Right-Click unbind, updated top Suite telemetry and 'World Flare Keys (...)' labels live on every bind/clear/reset, standardised [Edit HUD] buttons, and brought the compact 560x74 draggable HUD Edit dock with 60px fail-safe clamping and Hidden-by-default movers to both Suite and standalone DynamicMarker." },
                { badge = "FIXED",    title = "v1.9.9 Canonical UIParent-Local HUD Coordinates, Dark-Obsidian Coexistence Modal & Unified HUD Dock", desc = "Stored saved TargetBar and FlareBar X/Y coordinates strictly in unscaled UIParent-local offsets relative to screen CENTER and divided by barScale strictly inside DM:SetBarCenterPoint after SetScale/SetSize and before SetClampedToScreen(true) so top/bottom/corner edge bars stay at identical pixel coordinates across /reload at 0.70, 1.00, and 1.30 scales; added the custom dark-obsidian coexistence reload modal (ShowMarkerConflictReloadModal); and unified HUD Edit Mode across Suite & standalone modes." },
                { badge = "FIXED",    title = "v1.9.8 Scaled Edge-Drag & Reload Persistence", desc = "Synced bar scale and vertical/horizontal bar size prior to boundary clamping, canonicalised Target & Flare bar anchors to CENTER, cleared drag flags prior to final Edit Mode save, and kept SetClampedToScreen(false) so edge-pinned bars stay flush across release, /reload, and UI scale changes." },
                { badge = "NEW",      title = "v1.9.7 Live Suite Cross-Links & Hardened Coexistence", desc = "Replaced legacy URL placeholder labels across DynamicSuite & standalone DynamicMarker Support panels and docs now that DynamicSuite (Project ID 1804382) is live on CurseForge, and hardened ShouldYieldToOtherInstall semantic version yielding regardless of addon load order." },
                { badge = "UI",       title = "Standalone Scrollable Changelog Modal Parity", desc = "Upgraded standalone DynamicMarker's Changelog modal to stream live formatted entries directly from DynamicMarker.CHANGELOG.entries inside a scrollable frame matching the full suite Changelog hub." },
                { badge = "NEW",      title = "Encapsulated HUD Edit Mode, Movers & Standalone Parity", desc = "Moved HUD Edit Mode toggle state, crisp pixel-bordered movers ('DynamicMarker: Icon Bar' and 'DynamicMarker: Flare Bar'), drag-and-snap persistence directly into DynamicMarkerDB, mousewheel scaling (60%-150%), ESC-key closing, and combat-lockdown failsafe cleanly inside DynamicMarker. Registers with DynamicSuite's [+ HUD] toolbar button via RegisterHudEditCallback so no duplicate drag shields are created, and adds direct toggles in Focus/Flare Settings headers, the standalone rail, and /dm hud." },
                { badge = "NEW",      title = "One-Time FocusMarkerDB -> DynamicMarkerDB Migration Bridge", desc = "On ADDON_LOADED before defaults initialise, safely maps legacy FocusMarker bar positions, scales, visibility rules (Solo/Group/Always), orientation, and custom icon/flare ordering into DynamicMarkerDB with corrupted-table guards, setting migratedFromFocusMarker = true so legacy settings remain untouched without overwriting subsequent edits." },
                { badge = "FIXED",    title = "On-Screen Target Icon Bar & World Flare Bar Solo Visibility Fix", desc = "Centralised visibility evaluation in DM:UpdateTargetBarVisibility() and DM:UpdateFlareBarVisibility() with case-insensitive DB mode normalisation, state-driver registration ('[group] show; hide' / scope-aware variants), and immediate SetShown() evaluation; removed the workspace-open force-show override so selecting 'Group' while solo immediately hides the floating 8-icon bar even when the DynamicSuite settings panel is open." },
                { badge = "UI",       title = "Sleek Precision Track Sliders & Option 3 'Off' / 'Disabled' Pills", desc = "Upgraded DM:CreateSliderControl to the 256x26px Sleek Precision Track (4px #090A0D track, live Suite Accent FillBar, 6x14px blade thumb, smooth drag, click-to-seek, and mousewheel fine-tuning) and updated DM:CreateSegmentedPills with Option 3 negative pill styling (#1E2430 fill, #64748B border, #E2E8F0 text, and 1.5px #F87171 bottom OffBar)." },
                { badge = "UI",       title = "Command-Prefix-Only Tooltip Highlighting (Section 2.7)", desc = "Standardized all Target Bar, World Flare Bar, Interactive Keybind Capture, Focus Icon picker, and Flare Sequence card tooltips so only command prefixes (Left-Click:, Right-Click:, Drag Left/Right:, Shift+Right-Click:) are colored while action text uses Silver-White (#E2E8F0)." },
                { badge = "UI",       title = "2-Line Tall L-Bracket Section Headers (Section 2.4)", desc = "Upgraded all 6 section headers across Tabs 1-3 (Focus Target Marking, On-Screen Focus Bar HUD, World Flare Sequence, World Flare Bar HUD, [DynamicMark], and [DynamicKick]) to 36px 2-Line Tall L-Brackets with enclosed Slate-Silver subtitles." },
                { badge = "FIXED",    title = "Full-Width Horizontal Chevron Toggle Bars & Unified Group Cards", desc = "Replaced legacy small square [ ^ ] buttons on Announce Marks in Chat (Sub-Settings (1)), Show On-Screen Focus Bar (Sub-Settings (4)), and Show On-Screen World Flare Bar (Sub-Settings (4)) with full-width 24px horizontal chevron toggle bars (DM:AttachHorizontalChevronBar) and unified outer bordered group cards per DESIGN_SYSTEM.md Section 2.6." },
                { badge = "FIXED",    title = "Sub-Drawer Auto-Expand Lifecycle & Nested Sub-Card Geometry", desc = "Nested sub-setting cards now parent directly inside their outer group card (10px inset, PANEL_BG #090A0D, 1px CELL_BORDER, 2px vertical Suite Accent left bar, and 5x5px Suite Accent square pip). Toggling Off hides the chevron bar and collapses to 58px; toggling Off -> Enabled immediately expands sub-settings downward; manual chevron clicks persist in SavedVariables." },
                { badge = "UI",       title = "Standardised Individual Setting Row Cards", desc = "Updated all setting cards to distinct 58px row cards with bold uppercase Suite Accent L-bracket section headers." },
                { badge = "UI",       title = "Removed Redundant Preview & Position Bars", desc = "Completely removed preview bar rows and redundant position-on-screen buttons from Focus Icons and World Flare tabs since HUD positioning is handled via [+ HUD] / Edit Mode." },
                { badge = "FIXED",    title = "Resolved Lua Syntax Error near Line 3302", desc = "Fixed unexpected symbol syntax error caused by a duplicate prompt string in the configuration table." },
                { badge = "NEW",      title = "30x30 Square Target Icon & World Flare Pickers", desc = "Upgraded focus marker and ground flare selectors to crisp 30x30 square cells with 2px bottom active indicator bars." },
                { badge = "NEW",      title = "Modifier-Free [DynamicMark] & Multi-Spec [DynamicKick]", desc = "1-keypress focus + raid target marking, Smart Party-Only silence inside raid groups, and automatic interrupt spell syncing across all 13 classes." },
            },
        },
        {
            key = "zoom",
            tabLabel = "DynamicZoom",
            ver = DS_LIVE_VER_TAG,
            date = "16/11/2026 (Retail 12.1.5)",
            title = "DynamicZoom " .. DS_LIVE_VER_TAG,
            subtitle = "39-Yard Max Camera Zoom, Fast Scroll & See-Through Foliage (/dz)",
            icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_zoom.tga",
            openModule = "DynamicZoom",
            items = {
                { badge = "UI",       title = "v2.3.0 Release: 3-Way Interactive Obsidian Scrollbar & Central Popover Auto-Close", desc = "Upgraded DynamicZoom's workspace scrollbar to full 3-way interaction (Mousewheel, immediate Left-Click & Drag thumb with cursor-release guard and Suite Accent highlight, and Left-Click track jump), hooked OnHide on all dropdown owner buttons, and registered CloseAnyDropdown with UI.RegisterPopupCloser." },
                { badge = "UI",       title = "Right-Aligned 256px Sleek Precision Track Sliders & Option 3 'Off' Pills", desc = "Converted all full-width bottom-anchored sliders (CreateSliderCard) across Tabs 1, 2, and 3 into standard 58px right-aligned option rows (52px in sub-drawers) with 256x26px Sleek Precision Track sliders (4px #090A0D track, live Suite Accent FillBar, 6x14px blade thumb, smooth drag, click-to-seek, mousewheel fine-tuning, and right-click quick actions), and updated CreateSegmentedSwitchCard with Option 3 'Off' pill styling." },
                { badge = "UI",       title = "2-Line Tall L-Bracket Section Headers (Section 2.4)", desc = "Upgraded all 6 section headers across Tabs 1-3 (Distance Unlock, Terrain & Foliage Occlusion, Combat Auto-Zoom Profiles, Smart Indoor/Mount Rules, ActionCam Offset, and Dynamic Pitch) to 36px 2-Line Tall L-Brackets with enclosed Slate-Silver subtitles." },
                { badge = "UI",       title = "Horizontal Chevron Toggle Bar & Outer Group Border", desc = "Converted Reactive Scroll Wheel Accelerator and Foliage/Pillar sub-drawers to full-width horizontal chevron toggle bars with bracketed sub-setting counts and a unified outer container border." },
                { badge = "UI",       title = "Sub-Drawer Auto-Expand & Persistence Lifecycle", desc = "Toggling Off hides the chevron bar and sub-settings completely, enabling instantly auto-expands the sub-settings downward, and manual hide/show states persist across sessions." },
                { badge = "UI",       title = "Clean Distance Slider & Card Layout", desc = "Removed the redundant 'Apply 39 yd Max' button from the Maximum Camera Distance Unlock card so description text never wraps or clips behind the slider." },
                { badge = "NEW",      title = "Reactive Scroll Wheel Accelerator Engine", desc = "Quadratically boosts fast mousewheel flicks to glide to 39 yards in a single flick while keeping slow ticks precise." },
                { badge = "NEW",      title = "Foliage & Pillar Occlusion Shield", desc = "Fades intersecting tree branches, banners, and dungeon pillars to translucent instead of snapping your camera inward." },
                { badge = "FIXED",    title = "1:1 Workspace & Card Width Alignment", desc = "Aligned all option cards 1:1 with the 34px top bevel track and live camera readout bar, and standardized reset button labels." },
            },
        },
        {
            key = "fps",
            tabLabel = "DynamicFPS",
            ver = DS_LIVE_VER_TAG,
            date = "16/11/2026 (Retail 12.1.5)",
            title = "DynamicFPS " .. DS_LIVE_VER_TAG,
            subtitle = "Instant Per-Zone Graphics Switcher & Boss Ground-Effect Protection (/dfps)",
            icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_fps.tga",
            openModule = "DynamicFPS",
            items = {
                { badge = "UI",       title = "v2.3.0 Release: 3-Way Interactive Obsidian Scrollbar & Central Popover Auto-Close", desc = "Upgraded DynamicFPS's workspace scrollbar with track click-to-jump and Suite Accent thumb hover/drag highlights, added OnHide drag cleanup on sliders and dropdown owner buttons, and registered CloseActiveDropdownMenu with UI.RegisterPopupCloser." },
                { badge = "UI",       title = "Sleek Precision Track Sliders & Option 3 'Disabled' / 'Off' Pills", desc = "Upgraded CreateInlineSliderControl (View Distance, Environment Detail, Ground Clutter, and Custom Manual SpellQueueWindow) to the 256x26px Sleek Precision Track (4px #090A0D track, live Suite Accent FillBar, 6x14px blade thumb, smooth drag, click-to-seek, and mousewheel fine-tuning) and updated CreateSegmentedPills and CreateBinarySegmentedSwitch so 'Disabled' and 'Off' pills use Option 3 styling (#1E2430 fill, #64748B border, #E2E8F0 text, and 1.5px #F87171 bottom OffBar)." },
                { badge = "FIXED",    title = "Complete Secret-Value Sweep & Combat-Protected CVar Guard", desc = "Swept all numeric conversions in DynamicFPS through _IsSecret(), _SafeNum(), and _SafeNumber() with out-of-combat Haste/Ping caching (_dfpsCachedHaste / _dfpsCachedPing) and combat-protected CVar guards so active Mythic+ keys and boss encounters never throw secret-number errors." },
                { badge = "NEW",      title = "Quick Zone Profile Replication ('Copy From...' & 'Apply to All Zones')", desc = "Added a Quick Zone Profile Replication bar right below the Zone Preset toolbar so users can copy settings from any zone into the current zone or replicate the active zone profile across all 6 zones in 1 click." },
                { badge = "NEW",      title = "Smart Spec + Haste + Ping SpellQueueWindow Engine & Live Telemetry", desc = "Upgraded SpellQueueWindow auto-tuning to factor in both live World/Home latency and active Specialization + Haste GCD profile (Fast-GCD +95ms vs Caster +130ms), with a 3-mode selector (Smart Auto, Custom Manual, Blizzard Default) and a real-time CVar verification telemetry bar." },
                { badge = "UI",       title = "Demystified 'Revert to Saved Base' & 'Minimum Combat FPS'", desc = "Renamed 'Restore Baseline' to 'Revert to Saved Base' with a clear tooltip, and simplified 'Target FPS Floor' to 'Minimum Combat FPS' with a concise 1-sentence description and live FPS vs Protected Floor telemetry bar." },
                { badge = "UI",       title = "2-Line Tall L-Bracket Section Headers (Section 2.4)", desc = "Upgraded all 4 section headers across the Zone Graphics and FPS Guard pages (Zone Quality, Environment Geometry, Dynamic FPS Guard & SpellQueue, and Frame Rate Caps & Declutter) to 36px 2-Line Tall L-Brackets with enclosed Slate-Silver subtitles." },
                { badge = "FIXED",    title = "Full-Width Horizontal Chevron Sub-Drawers (Section 2.6)", desc = "Upgraded Dynamic Combat FPS Guard and Dynamic SpellQueueWindow sub-drawers to 24px full-width horizontal chevron toggle bars (Sub-Settings (N)) inside unified outer bordered group cards." },
                { badge = "UI",       title = "L-Menu Section Border Frames & Row Cards", desc = "Enclosed all L-bracket section headers and setting row cards across Zone Graphics and FPS Guard tabs inside outer backdrop border frames with dynamic sub-drawer reflow." },
                { badge = "NEW",      title = "Unified 7-Tab Recessed Top Bevel Track", desc = "Enclosed all 6 Zone tabs (Outdoor, Cities, Delves, Dungeons, Raid, PvP) plus [FPS Guard & Queue] inside the standardized 34px #0B0D12 bevel track." },
                { badge = "IMPROVED", title = "1-Click Hardware Tier Presets Per Zone", desc = "Instant Low-End PC, Balanced, Competitive FPS, and High-End Ultra graphics profiles per zone with zero UI reload required." },
                { badge = "IMPROVED", title = "Boss Telegraph Safety Lock", desc = "Hard-locks projected textures and essential ground swirlies ON across all Dungeon and Raid presets so boss mechanics are never hidden." },
            },
        },
        {
            key = "prep",
            tabLabel = "DynamicPrep",
            ver = DS_LIVE_VER_TAG,
            date = "16/11/2026 (Retail 12.1.5)",
            title = "DynamicPrep " .. DS_LIVE_VER_TAG,
            subtitle = "Readiness Omni-Bar, Clickable Raid Buffs & World/Survival QoL (/dprep)",
            icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_prep.tga",
            openModule = "DynamicPrep",
            items = {
                { badge = "UI",       title = "v2.3.0 Release: Relocated Blizzard Desktop Window Manager to Suite Studio (/ds windows) & 3-Way Scrollbar Upgrade", desc = "Relocated the Blizzard Desktop Window Manager from DynamicPrep Tab 3 into DynamicSuite Core ('Suite Studio -> Desktop Windows & Menus', /ds windows) with automatic SavedVariables migration and backward-compatible bridge stubs so Tab 3 focuses purely on World, Instance & Survival Automation; upgraded StyleObsidianScrollBar to full 3-way interaction; and registered DynamicPrep's dropdown and bar popover closers with UI.RegisterPopupCloser." },
                { badge = "FIXED",    title = "v2.2.0 Release: Secure Blizzard Window Probe Attribute Fix", desc = "Renamed the Blizzard window secure handler probe attribute from '_ds_probe' to 'ds_probe' inside EnsureSecureHandler() so restricted attribute validation in Blizzard's RestrictedFrames.lua passes cleanly on login and /reload without triggering an 'Invalid attribute name' Lua error." },
                { badge = "FIXED",    title = "v2.2.0 Release: Food Item Stat Benefit Tooltips on Clickable Raid Buffs HUD", desc = "Expanded ParseFoodBenefitFromTooltipText to match Midnight food wording ('gain', 'gaining', 'well fed', 'become well fed'), comma-formatted numbers (+1,250 Haste), and 'Highest Secondary Stat' (+445 Highest Sec); cached statShort and statFullLine from C_TooltipInfo.GetBagItem (with GetItemByID / GetSpellByID fallbacks) in ScanOwnedFoods; and displayed each food's exact stat benefit in the Raid Buffs HUD tooltip title and body." },
                { badge = "NEW",      title = "v2.2.0 Release: Blizzard Window QoL (Side-by-Side Panels, Header/Alt+Drag, Click-to-Raise, Ctrl+Scroll Scaling & Multi-Addon Coexistence)", desc = "Added Tab 3 controls for 'Keep Blizzard Windows Open Side-by-Side' (including Inspect, Dressing Room, Great Vault, Guild & Communities, Calendar, and Macros with compact header Pin buttons, click-to-raise layering, and clean Escape closing), 'Draggable Blizzard Windows (Save Position)' (drag headers or hold Alt + Left-Drag anywhere on a window, with Right-Click header reset and [Reset All Windows]), and 'Header Ctrl+Scroll Window Scaling' (Ctrl+Scroll for temporary session scale vs Ctrl+Shift+Scroll to save permanently between 70%-140% with an auto-fading Dark-Obsidian/Blaze-Orange toast); strictly excludes World Map and Game Menu, guards all hooks out of combat, and automatically yields with dynamic banner detection to BlizzMove, DeModal, MoveAny, EllesmereUI, Leatrix Plus, or ElvUI frame management." },
                { badge = "FIXED",    title = "v2.1.2 Release: Midnight Season 2 Enchantable Slot List Fix", desc = "Updated equipped gear enchant scanning in the Durability capsule to remove false-positive missing-enchant alerts on Cloak and Wrist (which do not have enchants in Midnight) and added Head and Shoulder to the Midnight Season 2 enchantable slot list (Head, Shoulder, Chest, Legs, Feet, Ring 1, Ring 2, Main Hand, and Off-Hand weapons)." },
                { badge = "NEW",      title = "One-Click Catalyst & Raid Combat UNIT_AURA Throttling (3.3 Hz Coalesced)", desc = "Added a 'One-Click Catalyst' QoL toggle in Tab 3 (enabled by default) that hooks ItemInteractionFrame.ButtonFrame.ActionButton and CONFIRM_ITEM_INTERACTION in Revival Catalyst mode (Enum.UIItemInteractionType.ItemConversion) to complete tier conversions in a single click without a confirmation popup or 5-second wait (hold Shift to bypass). Added an O(1) VALID_GROUP_UNITS filter ('player', 'party1'..'party4', 'raid1'..'raid40' - ignoring target, focus, mouseover, pets, nameplates, and bosses), coalesced all in-combat raid buff (16/17 MotW) and Symbiotic bond checks via a 0.30s (3.3 Hz max) C_Timer.NewTimer throttle, eliminated per-scan table allocations, and skipped Food, Flask, Weapon Oil, Augment Rune, and Bag Item Location scans during combat." },
                { badge = "FIXED",    title = "Greyed-Out Ctrl-to-Release Death Button & Modifier-Free Sequential [DynamicHeal] Macro", desc = "Hooked StaticPopup_OnUpdate and StaticPopup1..4 OnUpdate/OnShow/OnHide alongside MODIFIER_STATE_CHANGED, PLAYER_ALIVE, and PLAYER_UNGHOST so the DEATH StaticPopup 'Release Spirit' button stays natively disabled (greyed out with 'Hold CTRL to Release') every frame until Ctrl is held and restores cleanly when hidden; and stripped all [mod]/[nomod] conditionals from [DynamicHeal] in favour of a modifier-free sequential priority fallback (#showtooltip + /castsequence reset=combat item:<HealthstoneID>, item:<HealPotID> or /use item:<SingleID>) with out-of-combat cooldown reordering and post-combat sequence reset." },
                { badge = "NEW",      title = "Unified In-Combat Raid Buff (X/Y + MISSING) Readiness Tracker Strip Override", desc = "Removed the standalone combat banner (DynamicPrepCombatBuffAlertFrame) and unified in-combat missing class raid buffs (Mark of the Wild, Fortitude, Intellect, Skyfury, Battle Shout, Blessing of the Bronze) directly into the Readiness Tracker Strip icon format (icon + border + top-right X/Y count like 16/17 + bottom MISSING label) during combat, while suppressing personal consumables mid-fight, guarding all 12.x Midnight unit/aura checks against secret values, excluding unaccepted Battle Res targets until alive, and auto-hiding immediately on rebuff." },
                { badge = "FIXED",    title = "RefreshReadinessTrackerStrip Nil-Index Fix & Top Info Bar Layout Builder Restoration", desc = "Resolved the repeating nil-index Lua error at RefreshReadinessTrackerStrip by moving CLASS_RAID_BUFFS, PARTNER_RAID_BUFFS, SYMBIOTIC_SPELL_IDS, and SafeIsPlayerSpellKnown above all functions that reference them, adding defensive nil guards on all table lookups and slot frames, and wrapping RefreshReadinessTrackerStrip in pcall so Tab 1's Top Info Bar Layout Builder capsule labels always render cleanly." },
                { badge = "NEW",      title = "Symbiotic Relationship Linked-Target Detection, Exact Food Buff Stat Parser & In-Combat Brez / MotW Tracker", desc = "Scans player and party/raid units for Symbiotic Relationship (474750, 474754, and C_Spell.GetSpellName(474750) from player) plus UNIT_SPELLCAST_SUCCEEDED target caching to display 'Linked: [TankName]'; parses exact Well Fed stat benefits via C_TooltipInfo.GetUnitBuffByAuraInstanceID; and tracks in-combat Battle Rez / Ankh life-state transitions to surface a zero-taint 'Missing MotW: [PlayerName] (19/20)' alert." },
                { badge = "FIXED",    title = "0.00s Banker Gossip Selection, DialogueUI Flash Suppression & Bank Pre-Warm", desc = "Eliminated the 0.5s bank open delay and third-party DialogueUI popup flash on Banker NPCs with gossip options: auto-selects Banker, AccountBanker, and GuildBanker gossip synchronously at 0.00s on GOSSIP_SHOW, transiently suppresses DUIQuestFrame during auto-skipped gossip (restoring normal DialogueUI alpha/visibility on GOSSIP_CLOSED, PLAYER_INTERACTION_MANAGER_FRAME_SHOW, or 0.8s fallback), and pre-warms DynamicBags's companion bank window on the click frame." },
                { badge = "UI",       title = "Sleek Precision Track Sliders & Option 3 'Off' Pills", desc = "Upgraded CreateObsidianSlider (Bar Height, Bar Scale, Background Opacity, and HUD Icon Size) to the 256x26px Sleek Precision Track (4px #090A0D track, live Suite Accent FillBar, 6x14px blade thumb, smooth drag, click-to-seek, and mousewheel fine-tuning) and updated CreateSegmentedPills with Option 3 'Off' pill styling (#1E2430 fill, #64748B border, #E2E8F0 text, and 1.5px #F87171 bottom OffBar)." },
                { badge = "UI",       title = "Rebalanced Tabs 1, 2 ('Raid Buffs & Omni Folio') & 3 ('World & Survival QoL')", desc = "Moved Midnight Omni Folio Configuration from Tab 1 into Tab 2 directly beneath Clickable Raid Buffs so Tab 1 focuses exclusively on the Top Info Bar Layout Builder, and streamlined Tab 3 to focus on World, Instance & Survival Automation (Quest/Gossip, Cinematics, Resurrection, Spirit Release, and [DynamicHeal] Macro)." },
                { badge = "UI",       title = "Command-Prefix-Only Tooltip Highlighting (Section 2.7)", desc = "Standardized all Readiness Omni-Bar segment tooltips (Loot Spec, Keystone, Ready Check, Pull Timer, FPS, Ping) and Clickable Raid Buffs HUD tooltips to highlight only the command prefix (Left-Click:, Right-Click:, Shift-Click:) in color paired with Silver-White action descriptions." },
                { badge = "FIXED",    title = "Game Object, Delve & Quest Item Auto-Gossip", desc = "Removed restrictive opt.flags bitmask blocking in ShouldAutoSelectSingleGossip, added active Delve detection (C_DelvesUI.HasActiveDelve / C_PartyInfo.IsDelveInProgress), safely defaulted nil quest/option tables in GOSSIP_SHOW, and registered ITEM_TEXT_READY." },
                { badge = "NEW",      title = "Mid-Combat Raid Buff Tracking & '4/5' (Active/Total) Badge", desc = "Clickable Raid Buffs remain active during combat, boss encounters, and Mythic+ keys with SafeHasAura / _unitAuraStateCache fallback and 'active/total' (e.g. '4/5' or '19/20') missing group buff badge formatting." },
                { badge = "UI",       title = "2-Line Tall L-Bracket Section Headers (Section 2.4)", desc = "Upgraded all 5 section headers across Tabs 1-3 (Readiness Omni-Bar & Telemetry Segments, Omni-Bar Layout, Pre-Pull Consumable Scanner, [DynamicHeal] Macro, and Vendor/Loot/Quest Automation) to 36px 2-Line Tall L-Brackets with enclosed Slate-Silver subtitles." },
                { badge = "FIXED",    title = "Complete Quest Auto-Accept, Turn-In & (Quest) Gossip Engine", desc = "Isolated HandleQuestAndGossip from IsYieldingSharedHooks(), added Enum.GossipOptionRecFlags.QuestLabelPrepend (flags == 1) & quest icon detection, registered QUEST_ACCEPT_CONFIRM & QUEST_AUTOCOMPLETE, added CanAutoProgressQuest() gold protection, and added 0.05s deferred QuestFrame retries (hold Shift to bypass)." },
                { badge = "FIXED",    title = "Secret Aura Taint Protection (GetBuffDataByIndex)", desc = "Resolved 'GetBuffDataByIndex(): Auras cannot be accessed when secret' by adding _AreAurasSecret and _IsAuraIndexSecret pre-checks, pcall wrappers, and deferred post-combat aura refresh." },
                { badge = "FIXED",    title = "Top Info Bar Hex Color Sanitization", desc = "Fixed '0a48%' and '0a+19 BV' text corruption on the Readiness Bar by sanitizing 8-digit ARGB hex strings from GetSuiteAccent into clean 6-digit RRGGBB hex codes before formatting |cFF color sequences." },
                { badge = "FIXED",    title = "Full-Width Horizontal Chevron Sub-Drawers (Section 2.6)", desc = "Upgraded Secondary Stat Order, Clickable Raid Buffs & Consumable HUD, Auto-Repair Gear, and Auto-Sell Poor (Grey) Junk sub-drawers to 24px full-width horizontal chevron toggle bars (Sub-Settings (N)) inside unified outer group borders." },
                { badge = "NEW",      title = "Auto-Skip Gossip & Quest Automation", desc = "Auto-triggers single-option dungeon, Delve, and raid interactables (even in combat) and open-world dialogues while filtering NPC service icons and destructive/hearth/exit prompts. Automatically accepts and turns in quests; hold Shift to bypass." },
                { badge = "NEW",      title = "Midnight Clickable Raid Buffs & Consumable HUD", desc = "Upgraded consumable scanner for Midnight: 2-tier quality badges (Rank 2 Gold / Rank 1 Silver), deep Well Fed stat-food detection (Impossibly Royal Roast 255847), Hearty [H] vs Normal badges, 1-click Weapon Oil auto-apply, and [DynamicHeal] Silvermoon Health Potions." },
                { badge = "PERF",     title = "Mythic+ Secret-Value Shield & O(1) Fast-Path", desc = "Keystone secret-value protection and 0.0019 ms/tick zero-GC fast-path with /dprep simkey diagnostic benchmark to eliminate secret-number Lua errors and combat hitching." },
            },
        },
        {
            key = "group",
            tabLabel = "DynamicGroup",
            ver = DS_LIVE_VER_TAG,
            date = "16/11/2026 (Retail 12.1.5)",
            title = "DynamicGroup " .. DS_LIVE_VER_TAG,
            subtitle = "Premade LFG Datacenter Region Filter, Live Roster & Auto-Invite Engine (/dgroup)",
            icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_group.tga",
            openModule = "DynamicGroup",
            items = {
                { badge = "UI",       title = "v2.3.0 Release: 3-Way Interactive Obsidian Scrollbar & Central Popover Auto-Close", desc = "Upgraded CreateObsidianScrollArea with track click-to-jump and Suite Accent thumb hover/drag highlights, hooked OnHide across LFG Mini-Bar pills and workspace dropdowns, and registered CloseActiveDropdown with UI.RegisterPopupCloser." },
                { badge = "UI",       title = "Option 3 'Off' Pill Styling (Section 2.9)", desc = "Updated AttachSegmentedSwitchToCard across all 3 tabs so selected 'Off' pills use Option 3 styling (#1E2430 Slate-Charcoal fill, #64748B Slate-Silver border, #E2E8F0 Silver-White text, and 1.5px #F87171 bottom OffBar)." },
                { badge = "UI",       title = "Consolidated Single-Home M+ Keystone Auto-Slotting", desc = "Consolidated Auto-Insert Mythic+ Keystone exclusively inside DynamicGroup Tab 3 (Party & Keystone Automation) with automatic SavedVariables migration from DynamicPrepDB.autoSlotKeystone." },
                { badge = "UI",       title = "Command-Prefix-Only Tooltip Highlighting (Section 2.7)", desc = "Standardized all LFG Mini-Bar and Datacenter Region filter pill tooltips to highlight only the command prefix (Left-Click:, Hold Shift / Alt:) in color paired with Silver-White action descriptions." },
                { badge = "UI",       title = "Bordered Section Containers & 2-Line Tall L-Bracket Headers (Section 2.4)", desc = "Grouped all flat setting cards across Tabs 1-3 into bordered section containers (14px horizontal insets) with 36px 2-Line Tall L-Bracket headers and enclosed Slate-Silver subtitles." },
                { badge = "FIXED",    title = "Pending Leader Region Preservation & Direct liveResultID 1-Click Sign-Up", desc = "Preserves groups with pending or secret leaderName (regionKey = PENDING) so unticking a region (Reg 5/6) never blanks out the list, fetches authoritative unfiltered results from C_LFGList.GetSearchResults(), strips async-filtered rows in-place only when not hovered, and opens LFGListApplicationDialog_Show directly with liveResultID." },
                { badge = "FIXED",    title = "Async Region Filtering (LATAM / BR) & Party Utility Filter", desc = "Removed duplicate Ragnaros/Nemesis realm mappings, preserved panel._dgRawResults across refreshes, hooked LFG_LIST_SEARCH_RESULT_UPDATED & LFGListSearchPanel_UpdateResults to strip filtered regions as soon as leaderName resolves, and replaced Fit: Role with Party Utility Filter (Util: All / Lust / CR / Both)." },
                { badge = "FIXED",    title = "Direct Row OnClick Hook for 1-Click Sign-Up", desc = "Hooked entry:HookScript('OnClick') directly on ScrollBox rows inside OnLFGListSearchEntryUpdate and added next-frame deferred cursor snapping on LFGListApplicationDialog." },
                { badge = "FIXED",    title = "EllesmereUIGroupFinder LFG ScrollBox Conflict Fix", desc = "Auto-suppresses EllesmereUIGroupFinder's hidden ScrollBox overlay when DynamicGroup filtering is active, restores ScrollBox/SignUpButton alpha, hooks ExtraPasses fallback, and adds EllesmereUIGroupFinder to the 1-Click Conflict Scanner." },
                { badge = "FIXED",    title = "Protected & Secret LFG Application Note Guards", desc = "Added securityDisableSetText and IsSecretValue(curText) guards when auto-filling LFGApplicationDialog.Description and dialog._dgSnapped tracking when restoring dialog cursor snap positions." },
                { badge = "NEW",      title = "On-The-Fly LFG Mini-Bar & Premade Group Badges", desc = "Datacenter Region popover ([OCE], [US-W], [US-C], [US-E], [LATAM], [BR]), Leader M+ Score, Lust/CR badges, and Party Utility filtering directly above Blizzard's Premade panel." },
            },
        },
        {
            key = "bags",
            tabLabel = "DynamicBags",
            ver = DS_LIVE_VER_TAG,
            date = "18/11/2026 (Retail 12.1.5)",
            title = "DynamicBags " .. DS_LIVE_VER_TAG,
            subtitle = "Zero-Lag Virtual Category Bags, Remote Bank & Alt Inventory Vault (/dbag)",
            icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_bags.tga",
            openModule = "DynamicBags",
            items = {
                { badge = "FIXED",    title = "v2.3.2 Release (18/11/2026): 1-Click Housing Decor Non-Tradeable Confirmation & Smooth Mousewheel Scrolling", desc = "Clicking Open (N) or scrolling Alt+MouseWheel now uses and confirms refundable/trade-timer Housing Decor items in one click out of combat (supporting Retail 12.1.5 pooled StaticPopup dialogs, END_BOUND_TRADEABLE, and USE_NO_REFUND_CONFIRM while strictly ignoring manual bag clicks, dungeon/raid loot rolls, and non-Decor items); and restored smooth mousewheel scrolling across DynamicBags, DynamicBank, and settings scroll areas whenever Ctrl+Shift is not held." },
                { badge = "FIXED",    title = "v2.3.1 Release (18/11/2026): Clean ESC & B Keybind Window Closing & Escape-First Search Clear", desc = "Fixed ESC and B keybind closing across DynamicBags and DynamicBank with top-most one-window-at-a-time Escape priority (DynamicBank -> DynamicBags -> Blizzard panels -> Game Menu), Escape-first search clearing when focused or unfocused, and reliable two-way B toggling." },
                { badge = "UI",       title = "v2.3.0 Release: 3-Way Interactive Obsidian Scrollbars, Searchable Dropdowns & Central Popover Auto-Close", desc = "Upgraded U.CreateScrollArea across DynamicBagsFrame, DynamicBagsBankFrame, and the settings workspace with track click-to-jump and Suite Accent thumb hover/drag highlights; added live search filtering and 3-way scrolling to U.ShowMenu when entries exceed 12; and registered U.CloseMenu with UI.RegisterPopupCloser." },
                { badge = "NEW",      title = "Dual-Mode Ctrl+Scroll Window Scaling, Header Controls Tooltip & Scale-Aware Docked Bank Alignment", desc = "Added 70%-140% (5% steps, out of combat) scaling across DynamicBags and companion DynamicBank (Personal Bank, Warband Bank, and Guild Bank): Ctrl + Scroll across the full header scales temporarily for the current open session (resetting on hide), Ctrl + Shift + Scroll anywhere on either window (header, item grid ScrollFrame, or footer) saves bagScale / bankScale permanently without hijacking normal scrolling or Ctrl+Click item previews, Right-Click anywhere on the empty header resets scale to 100%, matching Blaze-Orange (#F97316) DynamicBags / DynamicBank Window Controls tooltips appear on header hover (hiding cleanly on OnLeave/OnDragStart) alongside an auto-fading Dark-Obsidian (#0B0D12) / Blaze-Orange (#F97316) readout pill, and scale-aware anchor math keeps a docked DynamicBank flush beside DynamicBags at any scale." },
                { badge = "FIXED",    title = "Zero-Flash Bank/Guild Bank After /reload, Merge & Automation Hardening", desc = "Added Scale+Alpha suppression and GUILDBANKFRAME_OPENED handling so Guild Bank and Bank never flash Blizzard frames after /reload, preserved unqueried Guild Bank tab snapshots across sessions while reflecting live tab withdrawals down to 0 items, fixed strict weak ordering in Sort: A-Z for uncached items, verified compatible slot placement across Reagent bags and Guild Bank tab permissions, prevented Guild Bank T1-Tn badge collisions and view-only item alpha overwrites, synchronised Tab 3 Auto-Repair/Auto-Sell keys, guarded fast auto-loot bursts, and expanded /dbag slash commands (/dbag merge, clear, bank, warband, guild, help)." },
                { badge = "FIXED",    title = "Header Button Overlap Fix, 0.00s Bank Pre-Warm & Deferred Tooltip Snapshots", desc = "Eliminated Row 1 header button overlap ('View: Bags' vs 'Clear') across all column and icon-size slider settings by trimming redundant 'Char: ' and 'View: ' prefixes, auto-fitting dropdown widths with mouseover tooltips ('Character & Alt Vault' and 'Active Inventory View'), enforcing dynamic minimum header width floors on DynamicBagsFrame and DynamicBagsBankFrame (640px), centring narrow item grids inside the scroll area, pre-warming DynamicBank at 0.00s on Banker gossip selection, and deferring full bank tooltip snapshots off the open frame for zero-stutter bank opening." },
                { badge = "FIXED",    title = "Normalised Stack-Key & Event-Driven Multi-Pass Stack Merger (DynamicBags & DynamicBank)", desc = "Fixed 'Merge' failing to combine split consumable/reagent stacks with differing hyperlink linkLevel, specID, or modifier suffixes by normalising stack keys via U.GetMergeStackKey (itemID + craft/reagent quality tier + bound state), removed C_Container.SortBags / SortBankBags / SortAccountBankBags slot-lock collisions from U.Restack and U.RestackBank, and upgraded U.MergePartialStacksAcrossBags and U.MergeGuildBankTabStacks to an event-driven multi-pass state machine (BAG_UPDATE_DELAYED / GUILDBANKBAGSLOTS_CHANGED) that pairs disjoint slots per pass and merges overflow remainders automatically." },
                { badge = "UI",       title = "Sleek Precision Track Sliders & Option 3 'Off' / 'None' Pills", desc = "Upgraded all numeric geometry controls (Bag Columns, Bank Columns, Slot Icon Size, Category Spacing, and Icon Font Size) in U.AddCard to 256x26px Sleek Precision Track sliders (4px #090A0D track, live Suite Accent FillBar, 6x14px blade thumb, smooth drag, click-to-seek, and mousewheel fine-tuning) and applied Option 3 negative pill styling to all 'Off' / 'None' pills across Tabs 1-3." },
                { badge = "NEW",      title = "Merchant, Loot & Inventory Automation (Tab 3)", desc = "Migrated Auto-Repair Equipment (with collapsible Sub-Settings (1) Funding Priority drawer: Guild Bank First / Personal Gold Only), Auto-Sell Grey Junk, Faster Auto-Loot, and Auto-Fill 'DELETE' Item Confirmation from DynamicPrep into DynamicBags Tab 3 with automatic SavedVariables migration." },
                { badge = "UI",       title = "Command-Prefix-Only Tooltip Highlighting (Section 2.7)", desc = "Standardized all item pinning, category header, bank transfer, currency tracker, category priority chip, and preset button tooltips to highlight only the command prefix in color paired with Silver-White action descriptions." },
                { badge = "UI",       title = "2-Line Tall L-Bracket Section Headers (Section 2.4)", desc = "Upgraded all 7 section headers across Tabs 1-3 (View Mode & Presets, Category Priority & Sub-Splitting, Grid Geometry, Slot Corner Badges, Visual Highlights, Auto-Open Triggers, and Alt & Warband Vault) to 36px 2-Line Tall L-Brackets with enclosed Slate-Silver subtitles." },
                { badge = "UI",       title = "L-Menu Section Border Frames & Grouped Tab Options", desc = "Grouped all settings across all 3 configuration tabs into bordered section containers with connected L-bracket section headers (14px horizontal insets, DESIGN_SYSTEM.md Section 2.4)." },
                { badge = "NEW",      title = "Midnight 2-Tier Consumable Quality Badges", desc = "Added Gold Tier 2 and Silver Tier 1 corner quality badge rendering for Midnight consumables alongside gear ilvl badges without overlapping stack counts." },
                { badge = "UI",       title = "DynamicBank Header Settings Cog", desc = "Added a 26x24 obsidian settings cog button to the DynamicBank header toolbar next to Pin and Close for instant 1-click access to bag and bank configuration." },
                { badge = "FIXED",    title = "WUE & BoE Corner Badge Persistence", desc = "Hardened Warband Until Equipped (WUE) and Bind on Equip (BoE) corner badge detection and persistence across live bags, Character Bank, and Warband Bank snapshots." },
                { badge = "FIXED",    title = "Equipment Set Bag:Slot Strict Matching", desc = "Eliminated duplicate itemID Equipment Set false-positives by enforcing strict bag:slot matching for live bags and isolating currently worn gear." },
                { badge = "NEW",      title = "Zero-Lag Virtual Category Bags & Bank Vault", desc = "Items grouped and sorted ahead of time in memory; 12 reorderable categories, Alt+Right-Click item pinning, and worldwide alt/Warband inventory browser." },
            },
        },
        {
            key = "chat",
            tabLabel = "DynamicChat",
            ver = DS_LIVE_VER_TAG,
            date = "16/11/2026 (Retail 12.1.5)",
            title = "DynamicChat " .. DS_LIVE_VER_TAG,
            subtitle = "Target Whisper (/ww), Sound Alerts, Smoked-Glass Chat Skin & History Retention (/dchat)",
            icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_chat.tga",
            openModule = "DynamicChat",
            items = {
                { badge = "FIXED",    title = "v2.3.0 Release: Font Dropdown Popover & 3-Way Scrollbar Upgrade, PrintMsg Fixes & Custom Reload Modal", desc = "Fixed OpenFontDropdownMenu activeDropdownMenu tracking, click-catcher activation, owner button OnHide auto-close, and chevron sync; upgraded DynamicChatFontDropdownMenu, DynamicChatSoundDropdownPopover, CreateObsidianScrollArea, and DynamicChatHistoryModal to full 3-way interactive 4px Obsidian scrollbars; replaced undefined PrintChat calls with PrintMsg across keyword saving, custom sound testing/adding, and /dc mute; replaced StaticPopupDialogs['DYNAMICCHAT_RELOAD_PROMPT'] with DynamicChatReloadPromptModal (#0B0D12 dark-obsidian + #F97316 Blaze Orange modal); and registered CloseActiveDropdown with UI.RegisterPopupCloser." },
                { badge = "NEW",      title = "External Sound Discovery (LibSharedMedia-3.0, DBM, EXBOSS, BigWigs, WeakAuras, ElvUI), Curated Blizzard Default Sounds & Self-Whisper Alerts", desc = "Removed temporary .wav sound files and LibSharedMedia .wav registration in favour of 7 curated native Blizzard SOUNDKIT alerts (Blizzard Raid Warning, Blizzard Whisper, Blizzard Battle.net, Blizzard Ready Check, Blizzard Map Ping, Blizzard Auction Bell, and Blizzard Quest Complete) with dual PlaySound / PlaySoundFile routing; configured clean Blizzard defaults across Tab 3's CHAT NOTIFICATION SOUNDS section (Whisper & Battle.net Whisper, Guild & Officer Chat, Party & Instance Chat, Raid & Raid Warning, and Say & Yell off by default) with automatic legacy ds_*/ex_* key migration, dropdown preview on selection, compact [Play] buttons, and 1.5s anti-spam cooldowns; added runtime LibSharedMedia-3.0, DBM, EXBOSS, BigWigs, WeakAuras, and ElvUI sound scanning with safe fallback to Blizzard Raid Warning and searchable grouped dropdowns; and restored self-whisper alert playback on incoming WHISPER / BN_WHISPER events while keeping self-message suppression active for group and public channels." },
                { badge = "FIXED",    title = "v1.9.8 Flush (0, 0) Bottom-Left Clamping & Persistence", desc = "Disabled C++ SetClampedToScreen(true) on ChatFrame1 whenever DynamicChat manages layout, restricted composite clamping solely to visible container extents (GetVisibleContainerExtents), and canonicalised CHAT to BOTTOMLEFT outer-container coordinates so (0, 0) sits flush at the bottom-left screen corner." },
                { badge = "FIXED",    title = "Accurate Frozen/Unloaded Conflict Detection & Universal 'Use DynamicChat' Takeover", desc = "Updated IsAddonLoadedNow, IsAddonActiveInSession, and IsEllesmereUIChatSubModuleEnabled so any external chat addon set to 'FROZEN' (Never) in DynamicLoad or overridden via 'USE_DYNAMIC' / 'RUN_BOTH' is treated as inactive (false), and prevented IsEllesmereUIChatSubModuleEnabled from falling back to parent EllesmereUI when EllesmereUIChat is installed as a separate sub-addon on disk and unloaded." },
                { badge = "PERF",     title = "Zero-Allocation Raid Combat Path & Fast Tab Alert Flash", desc = "Fast-pathed FCF_StartAlertFlash and FCF_StopAlertFlash during InCombatLockdown() to style only the single flashing tab instead of running full LayoutDockedChatTabs table allocations on every combat tab flash; added an O(1) '/' prefix check in TryConvertTargetWhisperEditBox; reused pre-allocated URL capture tables; and skipped RefreshLeftRailTelemetry() on UPDATE_INVENTORY_DURABILITY during combat." },
                { badge = "FIXED",    title = "HUD Mover Literal '|r' Text Fix, EllesmereUIChat Soft-Yield & 1:1 ChatFrame1 Geometry Sync", desc = "Fixed literal '|r' characters in HUD Edit Mode mover readouts ('|cFF64748B|||r' / '|cFF475569|||r'); hid the DynamicChat HUD mover and skipped ChatFrame1 position overrides whenever DynamicChat is disabled or soft-yielding to an external chat addon (EllesmereUIChat, ElvUI Chat, Prat-3.0, Chattynator, LS: Glass); synced SetScale(ChatFrame1:GetScale()) and 1:1 backdrop bounds across ChatFrame1, the DynamicChat container panel, and the HUD mover during and after HUD Edit Mode; and lowered the Chat HUD mover backdrop alpha (0.52 / 0.40) so underlying chat lines remain legible." },
                { badge = "FIXED",    title = "In-Combat /ww (Whisper Target), /rl (Reload UI) & /lg (Leave Group) Shortcuts", desc = "Enabled /ww (Quick Whisper Target), /rl (Reload UI), and /lg (Leave Group via C_PartyInfo.LeaveParty()) to work reliably as both instant editbox space-triggers ('/ww ') and registered slash commands on Enter, wrapping all target unit checks in pcall + issecretvalue guards and isolating BN_WHISPER / secret tellTarget editboxes." },
                { badge = "FIXED",    title = "ChatFrameEditBox BN_WHISPER Secret-Number Taint Fix & EllesmereUI Conflict Check", desc = "Eliminated direct EditBox widget script hooks on ChatFrame1EditBox so /ww and /lg use standard SlashCmdList registrations and hooksecurefunc post-hooks; added defensive issecretvalue(editBox:GetAttribute('tellTarget')) and issecretvalue(editBox.header:GetStringWidth()) guards across all EditBox handlers; restricted ChatFrame1EditBox font and anchor adjustments strictly to passive init skinning; and registered EllesmereUI (and EllesmereUIChat / EllesmereUI_Chat) in the Core Conflict Registry under DynamicChat." },
                { badge = "FIXED",    title = "Zero-Taint Secret-String Hotfix (3-Channel URL Filter), Private URL Capture, Full Chat History Modal & 1-Click Rail Link Copy", desc = "Eliminated Retail 12.1.5 secret-string taint by restricting ChatFrame_AddMessageEventFilter strictly to Guild, Officer, and Custom Channels while capturing Whisper/BNet/Party/Raid/Say links via an isolated private Frame listener (_urlCaptureFrame) into a 15-entry session ring buffer merged into DynamicChatHistoryModal's 'Recent Links:' pill bar; added a Suite-Accent link indicator dot and Shift-Click / Middle-Click 1-click link copy shortcut on the Left Rail Copy button; and fixed DynamicChatHistoryModal active-tab extraction, ScrollChild EditBox rendering, and header text layout." },
                { badge = "FIXED",    title = "Overflow Whisper Tab Clipping, Self-Whisper Testing, 'Blizzard Default' & LSM FileDataID Playback, and Tab Mousewheel Nil Fix", desc = "Stopped GeneralDockManager 38px left of the < / > navigation buttons (TOPRIGHT -30) with hardware child clipping (dock:SetClipsChildren(true)) and GeneralDockManagerScrollFrame suppression; hard-locked hiddenByScroll tabs with ClearAllPoints(), Hide(), and an OnShow guard hook (plus FCF_SetWindowName / FCF_CopyChatSettings / BN_FRIEND_INFO_CHANGED hooks) so overflow whisper/BNet tabs never stick out over the tab arrows; enabled self-whisper sound testing on CHAT_MSG_WHISPER / CHAT_MSG_BN_WHISPER; added numeric FileDataID support for LibSharedMedia-3.0 sound packs and BUILTIN_SOUND_LIBRARY; added a 2.0s unmute window + next-tick PlaySoundFile(567482/567421, outChan) playback so 'Blizzard Default' and built-in whisper chimes play reliably in dropdown previews and in-game without double-chiming or 300s tellTimer lockouts; kept sound alerts active alongside shared-hook addons; and hoisted RefreshTabNavButtonsVisuals above OnTabBarMouseWheel." },
                { badge = "NEW",      title = "Per-Channel Sound Alert Engine & 4th 'Sound Alerts' Sub-Tab (Built-In + LibSharedMedia-3.0)", desc = "Added a dedicated 4th 'Sound Alerts' tab supporting custom incoming alert sounds across 11 chat channels (Whisper, Battle.net Whisper, Party, Party Leader, Raid, Raid Leader & Warning, Instance, Guild, Officer, Say & Yell, and Custom Channels) with 12 built-in WoW sounds, automatic LibSharedMedia-3.0 sound discovery, inline [>] menu preview buttons, Right-Click closed-dropdown replay, native Blizzard whisper double-chime prevention, combat filter modes, and anti-spam cooldowns." },
                { badge = "UI",       title = "Option 3 'Off' / 'Reset to Previous' Pill Styling (Section 2.9)", desc = "Updated AttachSegmentedSwitchToCard and AttachMultiPillSelectorToCard across Tabs 1-4 so selected 'Off' and 'Reset to Previous' pills use Option 3 styling (#1E2430 fill, #64748B border, #E2E8F0 text, and 1.5px #F87171 bottom OffBar)." },
                { badge = "NEW",      title = "Signature /ww Target Whisper & /lg Leave Group Engine", desc = "Live EditBox header conversion when typing '/ww ' with a friendly player targeted (converting to native C++ WHISPER state before pressing Enter), alongside dedicated /rl (reload UI) and /lg (leave group) quick commands." },
                { badge = "NEW",      title = "Combat & Mythic+ Whisper Protection (Zero Whisper Filter Hooks)", desc = "Never registers ChatFrame_AddMessageEventFilter on whisper events, skips regex URL scanning in combat/M+, and rescues incoming whispers via ChatFrame1's unhooked C++ AddMessage if external UI suites (like EllesmereUI) drop them mid-pull." },
                { badge = "NEW",      title = "GPU & Framerate Chat Buffer Optimizer (SetMaxLines)", desc = "Caps ChatFrame1..10 line retention via SetMaxLines ([ 120 Lines | 250 Lines | 500 Lines | 1000 Lines ], default 250) out of combat to prevent chat-history vertex buffer bloat over long raid/M+ sessions, with zero SavedVariables chat log bloat." },
                { badge = "NEW",      title = "2-Tier Chat Conflict Scanner & Shared-Hook Auto-Yield Engine", desc = "Detects Direct Replacement chat addons (Chattynator, Prat 3.0, BasicChatMods, Chatter, LS: Glass, Glass, PhanxChat, DejaChat) with 1-click [Use DynamicChat] freeze or [Keep <Addon>], plus Partial Shared-Hook auto-yield (WIM, Leatrix Plus, ElvUI, WindTools)." },
                { badge = "NEW",      title = "Zero-Taint Compact Channel Tags, Arrow History & Clickable URLs", desc = "Replaces verbose channel prefixes with clean [P], [PL], [R], [RL], [RW], [I], [IL], [G], and [O] tags via global format strings, enables Up/Down arrow history without Alt, and opens DynamicChatCopyPopup on URL clicks." },
            },
        },
        {
            key = "mail",
            tabLabel = "DynamicMail",
            ver = DS_LIVE_VER_TAG,
            date = "18/11/2026 (Retail 12.1.5)",
            title = "DynamicMail " .. DS_LIVE_VER_TAG,
            subtitle = "1-Click Inbox Open All / AH Gold, Alt Vault Recipient Picker & Express Bag Attach (/dmail)",
            icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_mail.tga",
            openModule = "DynamicMail",
            items = {
                { badge = "NEW",      title = "v2.4.0 Release: Smart Inbox Collection, Quick-Attach Presets, Alt Vault Picker & Quick Gold", desc = "Launched DynamicMail (/dmail, /dynamicmail) with 1-click Open All, AH Gold, and Items Only buttons below MailFrame; Shift+Click quick-loot & Expiring (<3d) mail alerts; strict COD protection and free bag-slot reserve; a 4-tab Obsidian Recipient Picker beside Send Mail (Alts synced from DynamicBags Vault with class colours, gold & Pending Sent Mail badges, Recent, Guild, and Friends with Favourite stars); 1-click Quick-Attach presets ([+ Mats], [+ BoE], [+ Warband], [+ Same]) with Equipment Set & Soulbound safety; Quick Gold buttons ([+1k g], [+10k g], [+100k]); Alt + Left-Click bag attach; and lifetime gold & item telemetry." },
            },
        },
        {
            key = "vault",
            tabLabel = "DynamicVault",
            ver = DS_LIVE_VER_TAG,
            date = "19/11/2026 (Retail 12.1.5)",
            title = "DynamicVault " .. DS_LIVE_VER_TAG,
            subtitle = "Account Great Vault Matrix, Raid Lockouts, Bountiful Delves & Weekly Checklist (/dv)",
            icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_vault.tga",
            openModule = "DynamicVault",
            items = {
                { badge = "NEW",      title = "v2.5.0 Release: Account-Wide Great Vault Matrix, Raid Lockouts & Bountiful Delves Scanner", desc = "Launched DynamicVault (/dv, /dynamicvault) as the 10th integrated module with an automatic flush-width Great Vault top dock (zero minimap buttons, EllesmereUI/ElvUI Auto-Match skinning), Raid/M+/Delves 3-slot Vault progress + Next-Slot calculator, per-character Raid Boss Lockouts (LFR/N/H/M), live Today's Bountiful Delves scanner, Restored Coffer Keys / Shards / Catalyst / Seasonal Crest weekly cap telemetry, Account Gold & Key totals, auto-resetting Weekly Checklists, and an optional /dv overlay." },
            },
        },
        {
            key = "dialogue",
            tabLabel = "DynamicDialogue",
            ver = DS_LIVE_VER_TAG,
            date = "20/11/2026 (Retail 12.1.5)",
            title = "DynamicDialogue " .. DS_LIVE_VER_TAG,
            subtitle = "Obsidian Quest & Gossip Reader with 1-9 Hotkeys & Reward Cards (/dd)",
            icon = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_mod_dialogue.tga",
            openModule = "DynamicDialogue",
            items = {
                { badge = "NEW",      title = "v2.6.0 Release: Obsidian Quest & Gossip Reader, Hotkeys & Zero-Taint Auto-Yield", desc = "Launched DynamicDialogue (/dd, /ddlg) as the 11th integrated module with a high-contrast Obsidian Quest & Gossip reader, 1-9 option hotkeys, Space accept/continue/complete, interactive reward choice cards with hover tooltips, Shift-bypass to native Blizzard frames, draggable positioning, live Preview mode, and zero-taint dynamic yielding for DialogueUI, Immersion, Storyline, EllesmereUI QoL, and unknown Blizzard frame owners." },
            },
        },
    }
    f.dsChangelogModules = DS_CHANGELOG_MODULES

    local function ReturnToPreviousModule()
        if (f.lastModuleView == "PEER_HOST" or f.lastModuleView == "PEER_MODULE") and f.lastPeerModuleKey then
            addonTable.OpenPeerModule(f.lastPeerModuleKey)
        else
            addonTable.OpenWorkspaceView("DYNAMICLOAD")
        end
    end

    local function SyncBackBtnLabel(btn)
        if not btn or not btn.label then return end
    end

    local selectedClModIdx = 1

    -- 1. Universal 34px #0B0D12 Recessed Top Bevel Track at (14, -10) to (-16, -10) holding all 6 Module Tabs (26px tall)
    local clTabBar = CreateFrame("Frame", nil, changelogView)
    clTabBar:SetPoint("TOPLEFT", changelogView, "TOPLEFT", 14, -10)
    clTabBar:SetPoint("TOPRIGHT", changelogView, "TOPRIGHT", -16, -10)
    clTabBar:SetHeight(34)
    clTabBar.bg = UI.SolidTex(clTabBar, "BACKGROUND", 1, 0.043, 0.051, 0.071, 0.98)
    clTabBar.bg:SetAllPoints()
    UI.CreatePixelBorder(clTabBar, 1, 1, 1, 0.08, 2)

    local clTabBtns = {}
    local RefreshChangelogWorkspace

    for idx, mDef in ipairs(DS_CHANGELOG_MODULES) do
        local tBtn = CreateFrame("Button", nil, clTabBar)
        tBtn:SetHeight(26)
        tBtn.bg = UI.SolidTex(tBtn, "BACKGROUND", 2, 0.078, 0.090, 0.122, 0.96)
        tBtn.bg:SetAllPoints()
        UI.CreatePixelBorder(tBtn, 0.145, 0.165, 0.212, 0.95, 3)

        local tIcon = tBtn:CreateTexture(nil, "ARTWORK", nil, 3)
        tIcon:SetSize(13, 13)
        tIcon:SetPoint("LEFT", tBtn, "LEFT", 8, 0)
        tIcon:SetTexture(mDef.icon)
        tBtn.iconTex = tIcon

        local tLbl = tBtn:CreateFontString(nil, "OVERLAY")
        tLbl:SetPoint("LEFT", tIcon, "RIGHT", 5, 0)
        tLbl:SetPoint("RIGHT", tBtn, "RIGHT", -4, 0)
        tLbl:SetJustifyH("CENTER")
        tLbl:SetWordWrap(false)
        UI.SetFont(tLbl, 11, "", 0.68, 0.74, 0.82, 1)
        tLbl:SetText(mDef.tabLabel)
        tBtn.label = tLbl

        tBtn:SetScript("OnClick", function()
            selectedClModIdx = idx
            if RefreshChangelogWorkspace then RefreshChangelogWorkspace() end
        end)
        clTabBtns[idx] = tBtn
    end

    local function ReflowClTabBar()
        local w = clTabBar:GetWidth() or 780
        if w < 200 then w = 780 end
        local gap = 4
        local count = #clTabBtns
        local eachW = math.floor((w - 8 - ((count - 1) * gap)) / count)
        for i, b in ipairs(clTabBtns) do
            b:ClearAllPoints()
            b:SetHeight(26)
            if i == 1 then
                b:SetPoint("LEFT", clTabBar, "LEFT", 4, 0)
                b:SetWidth(eachW)
            elseif i == count then
                b:SetPoint("LEFT", clTabBtns[i - 1], "RIGHT", gap, 0)
                b:SetPoint("RIGHT", clTabBar, "RIGHT", -4, 0)
            else
                b:SetPoint("LEFT", clTabBtns[i - 1], "RIGHT", gap, 0)
                b:SetWidth(eachW)
            end
        end
    end
    clTabBar:SetScript("OnSizeChanged", ReflowClTabBar)

    -- 2. Module Release Summary Banner Bar (Aligned 1:1 with clTabBar at 0 left / 0 right, 48px tall)
    local clBanner = CreateFrame("Frame", nil, changelogView)
    clBanner:SetPoint("TOPLEFT", clTabBar, "BOTTOMLEFT", 0, -8)
    clBanner:SetPoint("TOPRIGHT", clTabBar, "BOTTOMRIGHT", 0, -8)
    clBanner:SetHeight(48)
    clBanner.bg = UI.SolidTex(clBanner, "BACKGROUND", 0, 0.031, 0.039, 0.055, 0.96)
    clBanner.bg:SetAllPoints()
    UI.CreatePixelBorder(clBanner, 0.145, 0.165, 0.212, 0.95, 2)

    local clBannerAccent = UI.SolidTex(clBanner, "OVERLAY", 4, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 1.0)
    clBannerAccent:SetWidth(2)
    clBannerAccent:SetPoint("TOPLEFT", clBanner, "TOPLEFT", 0, 0)
    clBannerAccent:SetPoint("BOTTOMLEFT", clBanner, "BOTTOMLEFT", 0, 0)

    local clBannerIcon = clBanner:CreateTexture(nil, "ARTWORK", nil, 3)
    clBannerIcon:SetSize(20, 20)
    clBannerIcon:SetPoint("LEFT", clBanner, "LEFT", 14, 0)

    local clOpenModBtn = CreateFlatButton(clBanner, 146, 24, "Open Workspace", true)
    clOpenModBtn:SetPoint("RIGHT", clBanner, "RIGHT", -12, 0)

    local clBannerDate = clBanner:CreateFontString(nil, "OVERLAY")
    clBannerDate:SetPoint("RIGHT", clOpenModBtn, "LEFT", -12, 0)
    UI.SetFont(clBannerDate, 10, "", 0.56, 0.62, 0.70, 0.95)

    local clBannerTitle = clBanner:CreateFontString(nil, "OVERLAY")
    clBannerTitle:SetPoint("TOPLEFT", clBanner, "TOPLEFT", 42, -8)
    clBannerTitle:SetPoint("RIGHT", clBannerDate, "LEFT", -10, 0)
    clBannerTitle:SetJustifyH("LEFT")
    clBannerTitle:SetWordWrap(false)
    UI.SetFont(clBannerTitle, 12, "", 1, 1, 1, 1)

    local clBannerSub = clBanner:CreateFontString(nil, "OVERLAY")
    clBannerSub:SetPoint("TOPLEFT", clBannerTitle, "BOTTOMLEFT", 0, -3)
    clBannerSub:SetPoint("RIGHT", clBannerDate, "LEFT", -10, 0)
    clBannerSub:SetJustifyH("LEFT")
    clBannerSub:SetWordWrap(false)
    UI.SetFont(clBannerSub, 10, "", 0.60, 0.66, 0.74, 0.95)

    -- 3. Scrollable Option-Card List (1:1 Width with clTabBar & clBanner + 4px Slate-Grey Scrollbar at -6px)
    local clvScroll = CreateFrame("ScrollFrame", nil, changelogView)
    clvScroll:SetPoint("TOPLEFT", clBanner, "BOTTOMLEFT", 0, -8)
    clvScroll:SetPoint("TOPRIGHT", clBanner, "BOTTOMRIGHT", 0, -8)
    clvScroll:SetPoint("BOTTOM", changelogView, "BOTTOM", 0, 10)
    clvScroll:SetClipsChildren(true)
    clvScroll:EnableMouseWheel(true)

    local clvChild = CreateFrame("Frame", nil, clvScroll)
    clvChild:SetSize(780, 400)
    clvScroll:SetScrollChild(clvChild)

    local clvTrack = CreateFrame("Frame", nil, changelogView)
    clvTrack:SetWidth(4)
    clvTrack:SetPoint("TOPRIGHT", clvScroll, "TOPRIGHT", 10, -2)
    clvTrack:SetPoint("BOTTOMRIGHT", clvScroll, "BOTTOMRIGHT", 10, 2)
    clvTrack:EnableMouse(true)
    clvTrack:SetHitRectInsets(-5, -5, 0, 0)
    clvTrack.bg = UI.SolidTex(clvTrack, "BACKGROUND", 1, 1, 1, 1, 0.05)
    clvTrack.bg:SetAllPoints()

    local clvThumb = CreateFrame("Button", nil, clvTrack)
    clvThumb:SetWidth(4)
    clvThumb:SetHeight(64)
    clvThumb:SetPoint("TOP", clvTrack, "TOP", 0, 0)
    clvThumb:EnableMouse(true)
    clvThumb:SetHitRectInsets(-5, -5, 0, 0)
    clvThumb.tex = UI.SolidTex(clvThumb, "OVERLAY", 2, 0.38, 0.45, 0.56, 0.85)
    clvThumb.tex:SetAllPoints()

    local function UpdateChangelogScrollbar()
        if clvScroll.UpdateScrollChildRect then
            pcall(clvScroll.UpdateScrollChildRect, clvScroll)
        end
        local trackH = clvTrack:GetHeight() or 0
        local viewH = clvScroll:GetHeight() or 0
        local contentH = clvChild:GetHeight() or 0
        if trackH <= 1 or viewH <= 1 then return end
        local maxScroll = math.max(0, contentH - viewH)
        if maxScroll <= 1 then
            clvTrack:Hide()
            clvThumb:Hide()
            clvScroll:SetVerticalScroll(0)
            return
        end
        clvTrack:Show()
        clvThumb:Show()
        local ratio = math.max(0.12, math.min(1, viewH / contentH))
        local thumbH = math.max(28, math.floor(trackH * ratio + 0.5))
        clvThumb:SetHeight(thumbH)
        local cur = math.max(0, math.min(maxScroll, clvScroll:GetVerticalScroll() or 0))
        local travel = math.max(1, trackH - thumbH)
        local yOff = -(cur / maxScroll) * travel
        clvThumb:ClearAllPoints()
        clvThumb:SetPoint("TOP", clvTrack, "TOP", 0, yOff)
        if not clvThumb.isDragging then
            clvThumb.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
        end
    end

    local function ScrollChangelogFromCursor()
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            clvThumb.isDragging = false
            clvThumb:SetScript("OnUpdate", nil)
            clvTrack:SetScript("OnUpdate", nil)
            clvThumb.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
            return
        end
        local viewH = clvScroll:GetHeight() or 0
        local contentH = clvChild:GetHeight() or 0
        local maxScroll = math.max(0, contentH - viewH)
        if maxScroll <= 0 then return end

        local eff = clvTrack:GetEffectiveScale() or 1
        local _, cy = GetCursorPosition()
        cy = cy / eff
        local top = clvTrack:GetTop()
        local bottom = clvTrack:GetBottom()
        if top and bottom and top > bottom then
            local trackH = top - bottom
            local thumbH = clvThumb:GetHeight() or 28
            local usableH = math.max(1, trackH - thumbH)
            local offsetFromTop = (top - cy) - (thumbH * 0.5)
            local ratio = math.max(0, math.min(1, offsetFromTop / usableH))
            clvScroll:SetVerticalScroll(ratio * maxScroll)
            UpdateChangelogScrollbar()
        end
    end

    clvThumb:SetScript("OnEnter", function(self)
        self.isHovered = true
        if not self.isDragging then
            local ar, ag, ab = UI.GetActiveAccentColor()
            self.tex:SetColorTexture(ar, ag, ab, 0.92)
        end
    end)
    clvThumb:SetScript("OnLeave", function(self)
        self.isHovered = false
        if not self.isDragging then
            self.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
        end
    end)
    clvThumb:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.isDragging = true
            local ar, ag, ab = UI.GetActiveAccentColor()
            self.tex:SetColorTexture(ar, ag, ab, 1.0)
            ScrollChangelogFromCursor()
            self:SetScript("OnUpdate", ScrollChangelogFromCursor)
        end
    end)
    clvThumb:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.isDragging = false
            self:SetScript("OnUpdate", nil)
            if self.isHovered then
                local ar, ag, ab = UI.GetActiveAccentColor()
                self.tex:SetColorTexture(ar, ag, ab, 0.92)
            else
                self.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
            end
        end
    end)
    clvThumb:SetScript("OnHide", function(self)
        self.isDragging = false
        self.isHovered = false
        self:SetScript("OnUpdate", nil)
        self.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
    end)

    clvTrack:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            clvThumb.isDragging = true
            local ar, ag, ab = UI.GetActiveAccentColor()
            clvThumb.tex:SetColorTexture(ar, ag, ab, 1.0)
            ScrollChangelogFromCursor()
            self:SetScript("OnUpdate", ScrollChangelogFromCursor)
        end
    end)
    clvTrack:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            clvThumb.isDragging = false
            self:SetScript("OnUpdate", nil)
            clvThumb.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
        end
    end)
    clvTrack:SetScript("OnHide", function(self)
        clvThumb.isDragging = false
        self:SetScript("OnUpdate", nil)
        clvThumb.tex:SetColorTexture(0.38, 0.45, 0.56, 0.85)
    end)

    local function ScrollChangelogByDelta(delta)
        local viewH = clvScroll:GetHeight() or 0
        local contentH = clvChild:GetHeight() or 0
        local maxScroll = math.max(0, contentH - viewH)
        local nextScroll = math.max(0, math.min(maxScroll, (clvScroll:GetVerticalScroll() or 0) - (delta * 44)))
        clvScroll:SetVerticalScroll(nextScroll)
        UpdateChangelogScrollbar()
    end

    clvScroll:SetScript("OnMouseWheel", function(_, delta)
        ScrollChangelogByDelta(delta)
    end)
    clvTrack:SetScript("OnMouseWheel", function(_, delta)
        ScrollChangelogByDelta(delta)
    end)
    clvThumb:SetScript("OnMouseWheel", function(_, delta)
        ScrollChangelogByDelta(delta)
    end)
    clvScroll:SetScript("OnScrollRangeChanged", function() UpdateChangelogScrollbar() end)
    clvScroll:SetScript("OnVerticalScroll", function() UpdateChangelogScrollbar() end)

    local clItemCardPool = {}
    local function AcquireClItemCard(idx)
        if clItemCardPool[idx] then return clItemCardPool[idx] end
        local c = CreateFrame("Frame", nil, clvChild)
        c.bg = UI.SolidTex(c, "BACKGROUND", 0, 0.078, 0.090, 0.122, 0.95)
        c.bg:SetAllPoints()
        UI.CreatePixelBorder(c, 0.145, 0.165, 0.212, 0.95, 2)

        local pill = CreateFrame("Frame", nil, c)
        pill:SetSize(74, 18)
        pill:SetPoint("TOPLEFT", c, "TOPLEFT", 14, -11)
        pill.bg = UI.SolidTex(pill, "BACKGROUND", 1, 0.1, 0.2, 0.15, 0.95)
        pill.bg:SetAllPoints()
        UI.CreatePixelBorder(pill, 1, 1, 1, 0.4, 3)
        pill.txt = pill:CreateFontString(nil, "OVERLAY")
        pill.txt:SetPoint("CENTER", pill, "CENTER", 0, 0)
        UI.SetFont(pill.txt, 9.5, "", 1, 1, 1, 1)
        c.pill = pill

        local title = c:CreateFontString(nil, "OVERLAY")
        title:SetPoint("LEFT", pill, "RIGHT", 10, 0)
        title:SetPoint("RIGHT", c, "RIGHT", -16, 0)
        title:SetJustifyH("LEFT")
        title:SetWordWrap(false)
        UI.SetFont(title, 12, "", 0.96, 0.98, 1.0, 1)
        c.title = title

        local desc = c:CreateFontString(nil, "OVERLAY")
        desc:SetPoint("TOPLEFT", c, "TOPLEFT", 14, -34)
        desc:SetPoint("RIGHT", c, "RIGHT", -16, 0)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        desc:SetSpacing(2)
        UI.SetFont(desc, 10.5, "", 0.62, 0.68, 0.76, 0.96)
        c.desc = desc

        clItemCardPool[idx] = c
        return c
    end

    RefreshChangelogWorkspace = function(preserveScroll)
        local prevScroll = (preserveScroll == true) and (clvScroll:GetVerticalScroll() or 0) or 0
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
        local curVer = addonTable.ADDON_VERSION or "1.3.0"
        local curSig = f.GetSuiteChangelogSignature and f.GetSuiteChangelogSignature() or curVer
        if gTbl then
            gTbl.lastSeenChangelogVer = curVer
            gTbl.lastSeenChangelogSig = curSig
        end
        if DynamicLoadDB then
            DynamicLoadDB.lastSeenChangelogVer = curVer
            DynamicLoadDB.lastSeenChangelogSig = curSig
        end
        if f.RefreshLeftRailVisuals then f.RefreshLeftRailVisuals() end

        local ar, ag, ab = UI.GetActiveAccentColor()
        local surf = UI.GetActiveSurfaceColors()
        ReflowClTabBar()

        local mDef = DS_CHANGELOG_MODULES[selectedClModIdx] or DS_CHANGELOG_MODULES[1]
        for idx, tBtn in ipairs(clTabBtns) do
            local isSel = (idx == selectedClModIdx)
            if isSel then
                local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}; local fa = gTbl.pillFillAlpha or 0.42; tBtn.bg:SetColorTexture(ar * fa, ag * fa, ab * fa, 0.98)
                tBtn.dsBorder:SetColor(ar, ag, ab, 0.95)
                tBtn.label:SetTextColor(1, 1, 1, 1)
                tBtn.iconTex:SetVertexColor(ar, ag, ab, 1.0)
            else
                tBtn.bg:SetColorTexture(0.078, 0.090, 0.122, 0.96)
                tBtn.dsBorder:SetColor(0.145, 0.165, 0.212, 0.95)
                tBtn.label:SetTextColor(0.68, 0.74, 0.82, 1)
                tBtn.iconTex:SetVertexColor(0.68, 0.74, 0.82, 0.90)
            end
        end

        clBannerAccent:SetColorTexture(ar, ag, ab, 1.0)
        clBannerIcon:SetTexture(mDef.icon)
        clBannerIcon:SetVertexColor(ar, ag, ab, 1.0)
        clBannerTitle:SetText(UI.FormatTwoToneBrand(mDef.tabLabel) .. "  |cFFFFFFFF" .. (mDef.ver or ("v" .. curVer)) .. "|r")
        clBannerSub:SetText(mDef.subtitle or "")
        clBannerDate:SetText(mDef.date or "")

        clOpenModBtn.label:SetText("Open " .. mDef.tabLabel)
        local bw = clOpenModBtn.label:GetStringWidth() or 110
        clOpenModBtn:SetWidth(math.max(134, math.ceil(bw + 24)))
        clOpenModBtn:SetSelected(true, { r = ar, g = ag, b = ab })
        clOpenModBtn:SetScript("OnClick", function()
            if mDef.openModule then
                addonTable.OpenPeerModule(mDef.openModule)
            else
                addonTable.OpenWorkspaceView(mDef.openView or "DYNAMICLOAD")
            end
        end)

        local sw = clvScroll:GetWidth() or 780
        if sw < 200 then sw = 780 end
        clvChild:SetWidth(sw)

        local yCursor = 0
        local items = mDef.items or {}
        for i, item in ipairs(items) do
            local card = AcquireClItemCard(i)
            card.bg:SetColorTexture(surf.card.r, surf.card.g, surf.card.b, 0.95)
            card.dsBorder:SetColor(0.145, 0.165, 0.212, 0.95)

            local bType = item.badge or "NEW"
            card.pill.txt:SetText(bType)
            if bType == "NEW" or bType == "FEATURE" then
                card.pill:SetWidth(60)
                card.pill.bg:SetColorTexture(0.063 * 0.28, 0.725 * 0.28, 0.506 * 0.28, 0.98)
                card.pill.dsBorder:SetColor(0.063, 0.725, 0.506, 0.95)
                card.pill.txt:SetTextColor(0.204, 0.827, 0.600, 1)
            elseif bType == "FIXED" or bType == "FIX" then
                card.pill:SetWidth(58)
                card.pill.bg:SetColorTexture(0.961 * 0.24, 0.722 * 0.24, 0.180 * 0.24, 0.98)
                card.pill.dsBorder:SetColor(0.961, 0.722, 0.180, 0.95)
                card.pill.txt:SetTextColor(0.980, 0.800, 0.220, 1)
            elseif bType == "PERF" then
                card.pill:SetWidth(54)
                card.pill.bg:SetColorTexture(0.220 * 0.28, 0.740 * 0.28, 0.970 * 0.28, 0.98)
                card.pill.dsBorder:SetColor(0.220, 0.740, 0.970, 0.95)
                card.pill.txt:SetTextColor(0.350, 0.850, 1.000, 1)
            elseif bType == "UI" then
                card.pill:SetWidth(44)
                card.pill.bg:SetColorTexture(0.650 * 0.25, 0.400 * 0.25, 0.950 * 0.25, 0.98)
                card.pill.dsBorder:SetColor(0.650, 0.400, 0.950, 0.95)
                card.pill.txt:SetTextColor(0.780, 0.580, 1.000, 1)
            else
                card.pill:SetWidth(76)
                card.pill.bg:SetColorTexture(ar * 0.24, ag * 0.24, ab * 0.24, 0.98)
                card.pill.dsBorder:SetColor(ar, ag, ab, 0.95)
                card.pill.txt:SetTextColor(1, 1, 1, 1)
            end

            card.title:SetText(item.title or "")
            card.desc:SetWidth(math.max(380, sw - 30))
            card.desc:SetText(item.desc or "")
            local dH = math.max(14, card.desc:GetStringHeight() or 16)
            local cardH = 34 + dH + 12

            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", clvChild, "TOPLEFT", 0, -yCursor)
            card:SetPoint("TOPRIGHT", clvChild, "TOPRIGHT", 0, -yCursor)
            card:SetHeight(cardH)
            card:Show()
            yCursor = yCursor + cardH + 8
        end

        for i = #items + 1, #clItemCardPool do
            clItemCardPool[i]:Hide()
        end

        clvChild:SetHeight(math.max(1, yCursor))
        if clvScroll.UpdateScrollChildRect then
            pcall(clvScroll.UpdateScrollChildRect, clvScroll)
        end
        local viewH = clvScroll:GetHeight() or 0
        local maxScroll = math.max(0, yCursor - viewH)
        clvScroll:SetVerticalScroll(math.max(0, math.min(maxScroll, prevScroll)))
        UpdateChangelogScrollbar()
    end

    clvScroll:SetScript("OnSizeChanged", function()
        if changelogView:IsShown() and RefreshChangelogWorkspace then
            RefreshChangelogWorkspace(true)
        end
    end)

    changelogView.Refresh = function()
        if (f.lastModuleView == "PEER_HOST" or f.lastModuleView == "PEER_MODULE") and f.lastPeerModuleKey then
            for idx, mDef in ipairs(DS_CHANGELOG_MODULES) do
                if mDef.openModule == f.lastPeerModuleKey or mDef.tabLabel == f.lastPeerModuleKey then
                    selectedClModIdx = idx
                    break
                end
            end
        end
        RefreshChangelogWorkspace(false)
        C_Timer.After(0, function()
            if changelogView:IsShown() and RefreshChangelogWorkspace then
                RefreshChangelogWorkspace(true)
            end
        end)
    end
    changelogView:SetScript("OnShow", function()
        if changelogView.Refresh then changelogView.Refresh() end
    end)
    local spvTitle = supportView:CreateFontString(nil, "OVERLAY")
    spvTitle:SetPoint("TOPLEFT", supportView, "TOPLEFT", 14, -14)
    UI.SetFont(spvTitle, 14, "", 1, 1, 1, 0.98)
    spvTitle:SetText("SUPPORT DYNAMICSUITE DEVELOPMENT")

    local spvBackBtn = CreateFlatButton(supportView, 156, 24, "", false)
    spvBackBtn:Hide()

    local spvCard = CreateFrame("Frame", nil, supportView)
    table.insert(f.themeCards, spvCard)
    spvCard:SetPoint("TOPLEFT", supportView, "TOPLEFT", 14, -44)
    spvCard:SetPoint("TOPRIGHT", supportView, "TOPRIGHT", -16, -44)
    spvCard:SetHeight(284)
    spvCard.bg = UI.SolidTex(spvCard, "BACKGROUND", 0, UI.COLORS.CARD_BG.r, UI.COLORS.CARD_BG.g, UI.COLORS.CARD_BG.b, 0.95)
    spvCard.bg:SetAllPoints()
    UI.CreatePixelBorder(spvCard, 1, 1, 1, 0.08, 2)

    local spvIcon = spvCard:CreateTexture(nil, "OVERLAY")
    spvIcon:SetSize(24, 24)
    spvIcon:SetPoint("TOPLEFT", spvCard, "TOPLEFT", 18, -18)
    spvIcon:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_support.tga")

    local spvHdr = spvCard:CreateFontString(nil, "OVERLAY")
    spvHdr:SetPoint("LEFT", spvIcon, "RIGHT", 10, 0)
    UI.SetFont(spvHdr, 13, "", 1, 1, 1, 1)
    spvHdr:SetText("Thank You for Using DynamicSuite!")

    local spvDesc = spvCard:CreateFontString(nil, "OVERLAY")
    spvDesc:SetPoint("TOPLEFT", spvIcon, "BOTTOMLEFT", 0, -12)
    spvDesc:SetPoint("RIGHT", spvCard, "RIGHT", -18, 0)
    spvDesc:SetJustifyH("LEFT")
    spvDesc:SetSpacing(3)
    UI.SetFont(spvDesc, 11, "", 0.85, 0.88, 0.93, 1)
    spvDesc:SetText("If DynamicSuite saves you load screen time, boosts your raid FPS, or keeps your UI clean, you can support ongoing development or share feedback via the links below (click any box and press Ctrl+C):")

    local function CreateCopyLinkRow(yOff, labelTxt, urlTxt)
        local lbl = spvCard:CreateFontString(nil, "OVERLAY")
        lbl:SetPoint("TOPLEFT", spvCard, "TOPLEFT", 18, yOff)
        UI.SetFont(lbl, 11, "", 0.72, 0.76, 0.84, 1)
        lbl:SetText(labelTxt)

        local ebWrap = CreateFrame("Frame", nil, spvCard)
        ebWrap:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -4)
        ebWrap:SetPoint("RIGHT", spvCard, "RIGHT", -18, 0)
        ebWrap:SetHeight(26)
        ebWrap.bg = UI.SolidTex(ebWrap, "BACKGROUND", 1, 0.035, 0.042, 0.058, 0.98)
        ebWrap.bg:SetAllPoints()
        UI.CreatePixelBorder(ebWrap, 1, 1, 1, 0.14, 2)

        local eb = CreateFrame("EditBox", nil, ebWrap)
        eb:SetPoint("LEFT", ebWrap, "LEFT", 10, 0)
        eb:SetPoint("RIGHT", ebWrap, "RIGHT", -10, 0)
        eb:SetHeight(22)
        eb:SetAutoFocus(false)
        UI.SetFont(eb, 11, "", 1, 1, 1, 0.96)
        eb:SetText(urlTxt)
        eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnChar", function(self) self:SetText(urlTxt); self:HighlightText() end)
    end

    CreateCopyLinkRow(-96,  "Buy the Developer a Coffee (Ko-fi):", "https://ko-fi.com/dentee")
    CreateCopyLinkRow(-156, "CurseForge Project Page & Feedback:", "https://www.curseforge.com/wow/addons/dynamicsuite")
    CreateCopyLinkRow(-216, "Direct Contact & Feedback (Email):", "denteedev@gmail.com")

    supportView.Refresh = function()
        SyncBackBtnLabel(spvBackBtn)
        local ar, ag, ab = UI.GetActiveAccentColor()
        spvIcon:SetVertexColor(ar, ag, ab, 1.0)
    end
    supportView:SetScript("OnShow", function()
        if supportView.Refresh then supportView.Refresh() end
    end)
    end

    ----------------------------------------------------------------------------
    -- VIEW C: MULTI-STEP GUIDED SETUP WIZARD & ACTIVE ADDON CONFLICT SCANNER
    ----------------------------------------------------------------------------
    local setupView = CreateFrame("Frame", nil, workspace)
    setupView:SetAllPoints()
    setupView:SetFrameLevel((workspace:GetFrameLevel() or 6) + 2)
    if setupView.SetClipsChildren then setupView:SetClipsChildren(false) end
    setupView:Hide()
    f.setupView = setupView
    f.guidedSetupView = setupView

    do
    local currentGuidedIdx = 1
    local lastGuidedStepKey = nil

    -- Top Segmented Step Bar Container
    local stepNavBar = CreateFrame("Frame", nil, setupView)
    stepNavBar:SetPoint("TOPLEFT", setupView, "TOPLEFT", 14, -8)
    stepNavBar:SetPoint("TOPRIGHT", setupView, "TOPRIGHT", -16, -8)
    stepNavBar:SetHeight(34)
    stepNavBar.bg = UI.SolidTex(stepNavBar, "BACKGROUND", 0, 0.043, 0.051, 0.071, 0.98)
    stepNavBar.bg:SetAllPoints()
    UI.CreatePixelBorder(stepNavBar, 1, 1, 1, 0.08, 2)

    local stepPillBtns = {}
    for i = 1, 10 do
        local spBtn = CreateFlatButton(stepNavBar, 100, 26, "", false)
        spBtn.label:ClearAllPoints()
        spBtn.label:SetPoint("LEFT", spBtn, "LEFT", 3, 0)
        spBtn.label:SetPoint("RIGHT", spBtn, "RIGHT", -3, 0)
        UI.SetFont(spBtn.label, 10, "", 1, 1, 1, 0.94)
        spBtn:Hide()
        stepPillBtns[i] = spBtn
    end

    -- Bottom Uninstall Prep Card (Restore Blizzard Defaults)
    local uninstallPrepCard = CreateFrame("Frame", nil, setupView)
    uninstallPrepCard:SetPoint("BOTTOMLEFT", setupView, "BOTTOMLEFT", 14, 10)
    uninstallPrepCard:SetPoint("BOTTOMRIGHT", setupView, "BOTTOMRIGHT", -16, 10)
    uninstallPrepCard:SetHeight(48)
    uninstallPrepCard.bg = UI.SolidTex(uninstallPrepCard, "BACKGROUND", 0, 0.068, 0.055, 0.068, 0.95)
    uninstallPrepCard.bg:SetAllPoints()
    UI.CreatePixelBorder(uninstallPrepCard, 0.937, 0.267, 0.267, 0.45, 2)

    local upTitle = uninstallPrepCard:CreateFontString(nil, "OVERLAY")
    upTitle:SetPoint("TOPLEFT", uninstallPrepCard, "TOPLEFT", 14, -8)
    UI.SetFont(upTitle, 11.5, "", 0.98, 0.62, 0.62, 1)
    upTitle:SetText("Restore Blizzard Defaults (Uninstall Prep)")

    local upDesc = uninstallPrepCard:CreateFontString(nil, "OVERLAY")
    upDesc:SetPoint("TOPLEFT", upTitle, "BOTTOMLEFT", 0, -2)
    upDesc:SetPoint("RIGHT", uninstallPrepCard, "RIGHT", -220, 0)
    upDesc:SetJustifyH("LEFT")
    upDesc:SetWordWrap(false)
    UI.SetFont(upDesc, 10, "", 0.78, 0.83, 0.90, 0.92)
    upDesc:SetText("Resets game settings, chat windows, and graphics back to Blizzard defaults before uninstalling.")

    local upBtn = CreateFlatButton(uninstallPrepCard, 194, 26, "Restore Blizzard Defaults...", false)
    upBtn:SetPoint("RIGHT", uninstallPrepCard, "RIGHT", -12, 0)
    upBtn.dsBorder:SetColor(0.937, 0.267, 0.267, 0.65)
    upBtn.label:SetTextColor(0.98, 0.74, 0.74, 0.98)
    upBtn:SetScript("OnClick", function()
        if addonTable.ShowBlizzRestoreModal then
            addonTable.ShowBlizzRestoreModal()
        end
    end)

    -- Main Wizard Card Container
    local wizCard = CreateFrame("Frame", nil, setupView)
    table.insert(f.themeCards, wizCard)
    wizCard:SetPoint("TOPLEFT", stepNavBar, "BOTTOMLEFT", 0, -10)
    wizCard:SetPoint("BOTTOMRIGHT", uninstallPrepCard, "TOPRIGHT", 0, 8)
    wizCard.bg = UI.SolidTex(wizCard, "BACKGROUND", 0, UI.COLORS.CARD_BG.r, UI.COLORS.CARD_BG.g, UI.COLORS.CARD_BG.b, 0.95)
    wizCard.bg:SetAllPoints()
    UI.CreatePixelBorder(wizCard, 1, 1, 1, 0.08, 2)

    -- Wizard Card Header Row
    local wizHdrTitle = wizCard:CreateFontString(nil, "OVERLAY")
    wizHdrTitle:SetPoint("TOPLEFT", wizCard, "TOPLEFT", 16, -14)
    wizHdrTitle:SetJustifyH("LEFT")
    wizHdrTitle:SetWordWrap(false)
    UI.SetFont(wizHdrTitle, 12, "", UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 1)

    local wizOpenModBtn = CreateFlatButton(wizCard, 168, 22, "Open Module", false)
    wizOpenModBtn:Hide()
    wizOpenModBtn:SetPoint("TOPRIGHT", wizCard, "TOPRIGHT", -16, -11)

    local simToggleBtn = CreateFlatButton(wizCard, 64, 22, "Demo", false)
    simToggleBtn:SetPoint("TOPRIGHT", wizCard, "TOPRIGHT", -16, -11)

    local resolveAllBtn = CreateFlatButton(wizCard, 76, 22, "Resolve", false)
    resolveAllBtn:SetPoint("RIGHT", simToggleBtn, "LEFT", -6, 0)

    local wizHdrDiv = UI.SolidTex(wizCard, "OVERLAY", 2, 1, 1, 1, 0.07)
    wizHdrDiv:SetPoint("TOPLEFT", wizCard, "TOPLEFT", 14, -40)
    wizHdrDiv:SetPoint("TOPRIGHT", wizCard, "TOPRIGHT", -14, -40)
    wizHdrDiv:SetHeight(1)

    local wizDesc = wizCard:CreateFontString(nil, "OVERLAY")
    wizDesc:SetPoint("TOPLEFT", wizCard, "TOPLEFT", 16, -48)
    wizDesc:SetPoint("TOPRIGHT", wizCard, "TOPRIGHT", -16, -48)
    wizDesc:SetJustifyH("LEFT")
    wizDesc:SetWordWrap(true)
    UI.SetFont(wizDesc, 11, "", 0.86, 0.89, 0.94, 1)

    -- Step Content Area (Between wizDesc and Bottom Navigation Footer)
    local wizBody = CreateFrame("Frame", nil, wizCard)
    wizBody:SetPoint("TOPLEFT", wizCard, "TOPLEFT", 16, -82)
    wizBody:SetPoint("BOTTOMRIGHT", wizCard, "BOTTOMRIGHT", -16, 48)

    -- Bottom Wizard Navigation Bar
    local wizFooterDiv = UI.SolidTex(wizCard, "OVERLAY", 2, 1, 1, 1, 0.07)
    wizFooterDiv:SetPoint("BOTTOMLEFT", wizCard, "BOTTOMLEFT", 14, 42)
    wizFooterDiv:SetPoint("BOTTOMRIGHT", wizCard, "BOTTOMRIGHT", -14, 42)
    wizFooterDiv:SetHeight(1)

    local wizPrevBtn = CreateFlatButton(wizCard, 136, 26, "< Previous Step", false)
    wizPrevBtn:SetPoint("BOTTOMLEFT", wizCard, "BOTTOMLEFT", 16, 10)

    local wizNextBtn = CreateFlatButton(wizCard, 210, 26, "Next Step >", true)
    wizNextBtn:SetPoint("BOTTOMRIGHT", wizCard, "BOTTOMRIGHT", -16, 10)

    local wizFooterInfo = wizCard:CreateFontString(nil, "OVERLAY")
    wizFooterInfo:SetPoint("LEFT", wizPrevBtn, "RIGHT", 10, 0)
    wizFooterInfo:SetPoint("RIGHT", wizNextBtn, "LEFT", -10, 0)
    wizFooterInfo:SetJustifyH("CENTER")
    wizFooterInfo:SetWordWrap(false)
    UI.SetFont(wizFooterInfo, 10, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 0.90)

    -- Step 1 Sub-Pane: Conflict Cards + 3 Theme Choice Cards
    local step1Pane = CreateFrame("Frame", nil, wizBody)
    step1Pane:SetAllPoints()

    local zeroConflictBanner = CreateFrame("Frame", nil, step1Pane)
    zeroConflictBanner:SetPoint("TOPLEFT", step1Pane, "TOPLEFT", 0, 0)
    zeroConflictBanner:SetPoint("TOPRIGHT", step1Pane, "TOPRIGHT", 0, 0)
    zeroConflictBanner:SetHeight(48)
    zeroConflictBanner.bg = UI.SolidTex(zeroConflictBanner, "BACKGROUND", 1, 0.05, 0.16, 0.09, 0.85)
    zeroConflictBanner.bg:SetAllPoints()
    UI.CreatePixelBorder(zeroConflictBanner, UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 0.65, 3)

    local zcText = zeroConflictBanner:CreateFontString(nil, "OVERLAY")
    zcText:SetPoint("LEFT", zeroConflictBanner, "LEFT", 14, 0)
    UI.SetFont(zcText, 11, "", UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 1)
    zcText:SetText("OK - Zero Active Addon Conflicts Detected! (Click 'Demo Conflicts' above to preview conflict cards)")

    -- 3 Interactive Theme Choice Cards at Bottom of Step 1 (Obsidian Slate, Auto-Match Class, Custom Accent & Font)
    local themeChoiceRow = CreateFrame("Frame", nil, step1Pane)
    themeChoiceRow:SetPoint("BOTTOMLEFT", step1Pane, "BOTTOMLEFT", 0, 0)
    themeChoiceRow:SetPoint("BOTTOMRIGHT", step1Pane, "BOTTOMRIGHT", 0, 0)
    themeChoiceRow:SetHeight(104)

    -- Scrollable Conflict List Container (fills available height above themeChoiceRow; scrollbar shows only when cards overflow)
    local conflictScrollFrame = CreateFrame("ScrollFrame", nil, step1Pane)
    conflictScrollFrame:SetPoint("TOPLEFT", step1Pane, "TOPLEFT", 0, 0)
    conflictScrollFrame:SetPoint("BOTTOMRIGHT", themeChoiceRow, "TOPRIGHT", 0, 12)
    conflictScrollFrame:EnableMouseWheel(true)
    conflictScrollFrame:SetClipsChildren(true)

    local conflictScrollChild = CreateFrame("Frame", nil, conflictScrollFrame)
    conflictScrollChild:SetWidth(740)
    conflictScrollChild:SetHeight(1)
    conflictScrollChild:EnableMouseWheel(true)
    conflictScrollFrame:SetScrollChild(conflictScrollChild)

    local conflictScrollTrack = CreateFrame("Frame", nil, step1Pane)
    conflictScrollTrack:SetPoint("TOPLEFT", conflictScrollFrame, "TOPRIGHT", 12, 0)
    conflictScrollTrack:SetPoint("BOTTOMLEFT", conflictScrollFrame, "BOTTOMRIGHT", 12, 0)
    conflictScrollTrack:SetWidth(6)
    conflictScrollTrack:EnableMouse(true)
    conflictScrollTrack:SetHitRectInsets(-5, -5, 0, 0)
    conflictScrollTrack.bg = UI.SolidTex(conflictScrollTrack, "BACKGROUND", 1, 0.035, 0.042, 0.058, 0.94)
    conflictScrollTrack.bg:SetAllPoints()
    UI.CreatePixelBorder(conflictScrollTrack, 0.22, 0.26, 0.34, 0.85, 2)

    local conflictScrollThumb = CreateFrame("Button", nil, conflictScrollTrack)
    conflictScrollThumb:SetPoint("TOP", conflictScrollTrack, "TOP", 0, 0)
    conflictScrollThumb:SetSize(6, 36)
    conflictScrollThumb:EnableMouse(true)
    conflictScrollThumb:SetHitRectInsets(-5, -5, 0, 0)
    conflictScrollThumb.tex = UI.SolidTex(conflictScrollThumb, "OVERLAY", 2, 0.56, 0.65, 0.78, 0.92)
    conflictScrollThumb.tex:SetPoint("TOPLEFT", conflictScrollThumb, "TOPLEFT", 1, -1)
    conflictScrollThumb.tex:SetPoint("BOTTOMRIGHT", conflictScrollThumb, "BOTTOMRIGHT", -1, 1)

    local conflictCards = {}

    local function UpdateConflictScrollbar()
        local paneH = step1Pane:GetHeight() or 340
        if paneH < 140 then paneH = 340 end
        local viewH = conflictScrollFrame:GetHeight()
        if not viewH or viewH < 80 then
            viewH = math.max(120, paneH - 104 - 12)
        end

        local ch = conflictScrollChild:GetHeight() or 1
        local maxScroll = math.max(0, ch - viewH)
        local needsScroll = (maxScroll > 2)

        local paneW = step1Pane:GetWidth() or 760
        if paneW < 120 then paneW = 760 end
        local targetW = math.max(400, paneW - (needsScroll and 18 or 0))

        conflictScrollFrame:ClearAllPoints()
        conflictScrollFrame:SetPoint("TOPLEFT", step1Pane, "TOPLEFT", 0, 0)
        conflictScrollFrame:SetPoint("BOTTOMRIGHT", themeChoiceRow, "TOPRIGHT", needsScroll and -18 or 0, 12)
        conflictScrollChild:SetWidth(targetW)

        for _, cCard in ipairs(conflictCards) do
            if cCard:IsShown() and cCard.LayoutButtons then
                cCard:LayoutButtons()
            end
        end

        if not needsScroll then
            conflictScrollTrack:Hide()
            conflictScrollThumb:Hide()
            conflictScrollFrame:SetVerticalScroll(0)
            return
        end

        conflictScrollTrack:Show()
        conflictScrollThumb:Show()
        local trackH = conflictScrollTrack:GetHeight()
        if not trackH or trackH < 20 then trackH = viewH end
        local ratioH = math.max(0.12, math.min(1, viewH / math.max(1, ch)))
        local thumbH = math.max(24, math.floor(ratioH * trackH + 0.5))
        conflictScrollThumb:SetHeight(thumbH)
        local cur = math.min(maxScroll, conflictScrollFrame:GetVerticalScroll() or 0)
        if cur ~= (conflictScrollFrame:GetVerticalScroll() or 0) then
            conflictScrollFrame:SetVerticalScroll(cur)
        end
        local ratio = (maxScroll > 0) and (cur / maxScroll) or 0
        local yOff = -math.floor(ratio * math.max(0, trackH - thumbH))
        conflictScrollThumb:ClearAllPoints()
        conflictScrollThumb:SetPoint("TOP", conflictScrollTrack, "TOP", 0, yOff)
        if not conflictScrollThumb.isDragging then
            if conflictScrollThumb.isHovered then
                local ar, ag, ab = UI.GetActiveAccentColor()
                conflictScrollThumb.tex:SetColorTexture(ar, ag, ab, 0.92)
            else
                conflictScrollThumb.tex:SetColorTexture(0.56, 0.65, 0.78, 0.92)
            end
        end
    end

    local function ScrollConflictFromCursor()
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            conflictScrollThumb.isDragging = false
            conflictScrollThumb:SetScript("OnUpdate", nil)
            conflictScrollTrack:SetScript("OnUpdate", nil)
            if conflictScrollThumb.isHovered then
                local ar, ag, ab = UI.GetActiveAccentColor()
                conflictScrollThumb.tex:SetColorTexture(ar, ag, ab, 0.92)
            else
                conflictScrollThumb.tex:SetColorTexture(0.56, 0.65, 0.78, 0.92)
            end
            return
        end
        local vh = conflictScrollFrame:GetHeight() or 294
        local maxScroll = math.max(0, (conflictScrollChild:GetHeight() or 1) - vh)
        if maxScroll <= 2 then return end

        local eff = conflictScrollTrack:GetEffectiveScale() or 1
        local _, cy = GetCursorPosition()
        cy = cy / eff
        local top = conflictScrollTrack:GetTop()
        local bottom = conflictScrollTrack:GetBottom()
        if top and bottom and top > bottom then
            local trackH = top - bottom
            local thumbH = conflictScrollThumb:GetHeight() or 24
            local usableH = math.max(1, trackH - thumbH)
            local offsetFromTop = (top - cy) - (thumbH * 0.5)
            local ratio = math.max(0, math.min(1, offsetFromTop / usableH))
            conflictScrollFrame:SetVerticalScroll(ratio * maxScroll)
            UpdateConflictScrollbar()
        end
    end

    local function ScrollConflictList(delta)
        local vh = conflictScrollFrame:GetHeight() or 294
        local maxScroll = math.max(0, (conflictScrollChild:GetHeight() or 1) - vh)
        if maxScroll <= 2 then return end
        local cur = conflictScrollFrame:GetVerticalScroll() or 0
        local nxt = math.max(0, math.min(maxScroll, cur - (delta * 38)))
        conflictScrollFrame:SetVerticalScroll(nxt)
        UpdateConflictScrollbar()
    end

    conflictScrollThumb:SetScript("OnEnter", function(self)
        self.isHovered = true
        if not self.isDragging then
            local ar, ag, ab = UI.GetActiveAccentColor()
            self.tex:SetColorTexture(ar, ag, ab, 0.92)
        end
    end)
    conflictScrollThumb:SetScript("OnLeave", function(self)
        self.isHovered = false
        if not self.isDragging then
            self.tex:SetColorTexture(0.56, 0.65, 0.78, 0.92)
        end
    end)
    conflictScrollThumb:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.isDragging = true
            local ar, ag, ab = UI.GetActiveAccentColor()
            self.tex:SetColorTexture(ar, ag, ab, 1.0)
            ScrollConflictFromCursor()
            self:SetScript("OnUpdate", ScrollConflictFromCursor)
        end
    end)
    conflictScrollThumb:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.isDragging = false
            self:SetScript("OnUpdate", nil)
            if self.isHovered then
                local ar, ag, ab = UI.GetActiveAccentColor()
                self.tex:SetColorTexture(ar, ag, ab, 0.92)
            else
                self.tex:SetColorTexture(0.56, 0.65, 0.78, 0.92)
            end
        end
    end)
    conflictScrollThumb:SetScript("OnHide", function(self)
        self.isDragging = false
        self.isHovered = false
        self:SetScript("OnUpdate", nil)
        self.tex:SetColorTexture(0.56, 0.65, 0.78, 0.92)
    end)
    conflictScrollThumb:SetScript("OnMouseWheel", function(_, delta)
        ScrollConflictList(delta)
    end)

    conflictScrollTrack:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            conflictScrollThumb.isDragging = true
            local ar, ag, ab = UI.GetActiveAccentColor()
            conflictScrollThumb.tex:SetColorTexture(ar, ag, ab, 1.0)
            ScrollConflictFromCursor()
            self:SetScript("OnUpdate", ScrollConflictFromCursor)
        end
    end)
    conflictScrollTrack:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            conflictScrollThumb.isDragging = false
            self:SetScript("OnUpdate", nil)
            conflictScrollThumb.tex:SetColorTexture(0.56, 0.65, 0.78, 0.92)
        end
    end)
    conflictScrollTrack:SetScript("OnHide", function(self)
        conflictScrollThumb.isDragging = false
        self:SetScript("OnUpdate", nil)
        conflictScrollThumb.tex:SetColorTexture(0.56, 0.65, 0.78, 0.92)
    end)
    conflictScrollTrack:SetScript("OnMouseWheel", function(_, delta)
        ScrollConflictList(delta)
    end)

    conflictScrollFrame:SetScript("OnMouseWheel", function(_, delta)
        ScrollConflictList(delta)
    end)
    conflictScrollFrame:SetScript("OnVerticalScroll", function()
        UpdateConflictScrollbar()
    end)
    conflictScrollFrame:SetScript("OnScrollRangeChanged", function()
        UpdateConflictScrollbar()
    end)
    conflictScrollChild:SetScript("OnMouseWheel", function(_, delta)
        ScrollConflictList(delta)
    end)

    step1Pane:SetScript("OnSizeChanged", function()
        if step1Pane:IsShown() and conflictScrollFrame:IsShown() then
            UpdateConflictScrollbar()
        end
    end)

    local function EnsureConflictCard(i)
        if conflictCards[i] then return conflictCards[i] end
        local cCard = CreateFrame("Frame", nil, conflictScrollChild)
        local yOff = -((i - 1) * 74)
        cCard:SetPoint("TOPLEFT", conflictScrollChild, "TOPLEFT", 0, yOff)
        cCard:SetPoint("TOPRIGHT", conflictScrollChild, "TOPRIGHT", 0, yOff)
        cCard:SetHeight(68)
        cCard:EnableMouseWheel(true)
        cCard:SetScript("OnMouseWheel", function(_, delta) ScrollConflictList(delta) end)
        cCard.bg = UI.SolidTex(cCard, "BACKGROUND", 1, 0.04, 0.12, 0.11, 0.92)
        cCard.bg:SetAllPoints()
        UI.CreatePixelBorder(cCard, 0.133, 0.773, 0.650, 0.80, 3)

        cCard.leftBar = UI.SolidTex(cCard, "OVERLAY", 4, 0.133, 0.773, 0.650, 1.0)
        cCard.leftBar:SetPoint("TOPLEFT", cCard, "TOPLEFT", 0, 0)
        cCard.leftBar:SetPoint("BOTTOMLEFT", cCard, "BOTTOMLEFT", 0, 0)
        cCard.leftBar:SetWidth(3)

        local statusPill = CreateFrame("Frame", nil, cCard)
        statusPill:SetSize(148, 17)
        statusPill:SetPoint("TOPRIGHT", cCard, "TOPRIGHT", -12, -5)
        statusPill.bg = UI.SolidTex(statusPill, "BACKGROUND", 2, 0.05, 0.22, 0.18, 0.88)
        statusPill.bg:SetAllPoints()
        UI.CreatePixelBorder(statusPill, 0.133, 0.773, 0.650, 0.85, 3)
        cCard.statusPill = statusPill

        local statusText = statusPill:CreateFontString(nil, "OVERLAY")
        statusText:SetPoint("CENTER", statusPill, "CENTER", 0, 0)
        UI.SetFont(statusText, 9.5, "", 0.204, 0.890, 0.680, 1)
        cCard.statusText = statusText

        cCard.btnUseDynamic = CreateFlatButton(cCard, 240, 22, "Use DynamicSuite Only", false)
        cCard.btnUseDynamic.label:ClearAllPoints()
        cCard.btnUseDynamic.label:SetPoint("LEFT", cCard.btnUseDynamic, "LEFT", 14, 0)
        cCard.btnUseDynamic.label:SetPoint("RIGHT", cCard.btnUseDynamic, "RIGHT", -14, 0)
        cCard.btnUseDynamic:EnableMouseWheel(true)
        cCard.btnUseDynamic:SetScript("OnMouseWheel", function(_, delta) ScrollConflictList(delta) end)

        cCard.btnKeepOther = CreateFlatButton(cCard, 240, 22, "Use External Only", false)
        cCard.btnKeepOther.label:ClearAllPoints()
        cCard.btnKeepOther.label:SetPoint("LEFT", cCard.btnKeepOther, "LEFT", 14, 0)
        cCard.btnKeepOther.label:SetPoint("RIGHT", cCard.btnKeepOther, "RIGHT", -14, 0)
        cCard.btnKeepOther:EnableMouseWheel(true)
        cCard.btnKeepOther:SetScript("OnMouseWheel", function(_, delta) ScrollConflictList(delta) end)

        local function LayoutConflictCardButtons(self)
            local cw = conflictScrollChild:GetWidth()
            local w = (cw and cw >= 120) and cw or (self:GetWidth() or 740)
            if w < 120 then w = 740 end
            local gap = 10
            local totalW = w - 24
            local eachW = math.max(150, math.floor((totalW - gap) / 2))
            self.btnUseDynamic:ClearAllPoints()
            self.btnUseDynamic:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 12, 5)
            self.btnUseDynamic:SetSize(eachW, 22)

            self.btnKeepOther:ClearAllPoints()
            self.btnKeepOther:SetPoint("LEFT", self.btnUseDynamic, "RIGHT", gap, 0)
            self.btnKeepOther:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -12, 5)
            self.btnKeepOther:SetHeight(22)
        end
        cCard.LayoutButtons = LayoutConflictCardButtons
        cCard:SetScript("OnSizeChanged", LayoutConflictCardButtons)

        cCard.title = cCard:CreateFontString(nil, "OVERLAY")
        cCard.title:SetPoint("TOPLEFT", cCard, "TOPLEFT", 12, -5)
        cCard.title:SetPoint("RIGHT", statusPill, "LEFT", -10, 0)
        cCard.title:SetJustifyH("LEFT")
        cCard.title:SetWordWrap(false)
        UI.SetFont(cCard.title, 11, "", 1, 1, 1, 0.98)

        cCard.desc = cCard:CreateFontString(nil, "OVERLAY")
        cCard.desc:SetPoint("TOPLEFT", cCard, "TOPLEFT", 12, -21)
        cCard.desc:SetPoint("TOPRIGHT", cCard, "TOPRIGHT", -12, -21)
        cCard.desc:SetJustifyH("LEFT")
        cCard.desc:SetWordWrap(false)
        UI.SetFont(cCard.desc, 10, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 0.95)

        cCard:Hide()
        conflictCards[i] = cCard
        return cCard
    end

    local themeChoiceHdr = themeChoiceRow:CreateFontString(nil, "OVERLAY")
    themeChoiceHdr:SetPoint("TOPLEFT", themeChoiceRow, "TOPLEFT", 0, 0)
    UI.SetFont(themeChoiceHdr, 10, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 0.95)
    themeChoiceHdr:SetText("QUICK VISUAL THEME & ALT SYNC:")

    local themeChoiceCards = {}
    for i = 1, 3 do
        local tc = CreateFrame("Button", nil, themeChoiceRow)
        tc:SetHeight(82)
        tc.bg = UI.SolidTex(tc, "BACKGROUND", 1, 0.078, 0.090, 0.122, 0.96)
        tc.bg:SetAllPoints()
        UI.CreatePixelBorder(tc, 0.145, 0.165, 0.212, 0.95, 3)

        tc.badge = tc:CreateFontString(nil, "OVERLAY")
        tc.badge:SetPoint("TOPRIGHT", tc, "TOPRIGHT", -10, -8)
        UI.SetFont(tc.badge, 9, "", UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 1)

        tc.title = tc:CreateFontString(nil, "OVERLAY")
        tc.title:SetPoint("TOPLEFT", tc, "TOPLEFT", 12, -8)
        tc.title:SetPoint("RIGHT", tc.badge, "LEFT", -6, 0)
        tc.title:SetJustifyH("LEFT")
        tc.title:SetWordWrap(false)
        UI.SetFont(tc.title, 11, "", 1, 1, 1, 1)

        tc.desc = tc:CreateFontString(nil, "OVERLAY")
        tc.desc:SetPoint("TOPLEFT", tc.title, "BOTTOMLEFT", 0, -5)
        tc.desc:SetPoint("BOTTOMRIGHT", tc, "BOTTOMRIGHT", -10, 6)
        tc.desc:SetJustifyH("LEFT")
        tc.desc:SetJustifyV("TOP")
        tc.desc:SetWordWrap(true)
        UI.SetFont(tc.desc, 10, "", 0.62, 0.68, 0.76, 0.95)

        themeChoiceCards[i] = tc
    end

    themeChoiceRow:SetScript("OnSizeChanged", function(self, w)
        if not w or w < 100 then return end
        local gap = 10
        local cw = math.floor((w - (gap * 2)) / 3)
        for i = 1, 3 do
            local tc = themeChoiceCards[i]
            tc:ClearAllPoints()
            if i == 1 then
                tc:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
                tc:SetWidth(cw)
            elseif i == 2 then
                tc:SetPoint("LEFT", themeChoiceCards[1], "RIGHT", gap, 0)
                tc:SetWidth(cw)
            else
                tc:SetPoint("LEFT", themeChoiceCards[2], "RIGHT", gap, 0)
                tc:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
            end
        end
    end)

    -- Steps 2..7 Sub-Pane: Info Banner + Up to 4 Interactive Choice Cards (2x2 Grid)
    local stepModPane = CreateFrame("Frame", nil, wizBody)
    stepModPane:SetAllPoints()
    stepModPane:Hide()

    local modSummaryBox = CreateFrame("Frame", nil, stepModPane)
    modSummaryBox:SetPoint("TOPLEFT", stepModPane, "TOPLEFT", 0, 0)
    modSummaryBox:SetPoint("TOPRIGHT", stepModPane, "TOPRIGHT", 0, 0)
    modSummaryBox:SetHeight(86)
    modSummaryBox.bg = UI.SolidTex(modSummaryBox, "BACKGROUND", 1, 0.035, 0.042, 0.058, 0.98)
    modSummaryBox.bg:SetAllPoints()
    UI.CreatePixelBorder(modSummaryBox, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.45, 2)

    local modSummaryText = modSummaryBox:CreateFontString(nil, "OVERLAY")
    modSummaryText:SetPoint("TOPLEFT", modSummaryBox, "TOPLEFT", 14, -10)
    modSummaryText:SetPoint("BOTTOMRIGHT", modSummaryBox, "BOTTOMRIGHT", -14, 10)
    modSummaryText:SetJustifyH("LEFT")
    modSummaryText:SetJustifyV("TOP")
    modSummaryText:SetSpacing(3)
    modSummaryText:SetWordWrap(true)
    UI.SetFont(modSummaryText, 11, "", 0.85, 0.89, 0.95, 1)

    local modChoiceGrid = CreateFrame("Frame", nil, stepModPane)
    modChoiceGrid:SetPoint("TOPLEFT", modSummaryBox, "BOTTOMLEFT", 0, -12)
    modChoiceGrid:SetPoint("BOTTOMRIGHT", stepModPane, "BOTTOMRIGHT", 0, 0)

    local modChoiceCards = {}
    for i = 1, 4 do
        local mc = CreateFrame("Button", nil, modChoiceGrid)
        mc:SetHeight(104)
        mc.bg = UI.SolidTex(mc, "BACKGROUND", 1, 0.078, 0.090, 0.122, 0.96)
        mc.bg:SetAllPoints()
        UI.CreatePixelBorder(mc, 0.145, 0.165, 0.212, 0.95, 3)

        mc.badge = mc:CreateFontString(nil, "OVERLAY")
        mc.badge:SetPoint("TOPRIGHT", mc, "TOPRIGHT", -12, -10)
        UI.SetFont(mc.badge, 10, "", UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 1)

        mc.title = mc:CreateFontString(nil, "OVERLAY")
        mc.title:SetPoint("TOPLEFT", mc, "TOPLEFT", 14, -10)
        mc.title:SetPoint("RIGHT", mc.badge, "LEFT", -8, 0)
        mc.title:SetJustifyH("LEFT")
        mc.title:SetWordWrap(false)
        UI.SetFont(mc.title, 12, "", 1, 1, 1, 1)

        mc.desc = mc:CreateFontString(nil, "OVERLAY")
        mc.desc:SetPoint("TOPLEFT", mc.title, "BOTTOMLEFT", 0, -6)
        mc.desc:SetPoint("BOTTOMRIGHT", mc, "BOTTOMRIGHT", -14, 10)
        mc.desc:SetJustifyH("LEFT")
        mc.desc:SetJustifyV("TOP")
        mc.desc:SetSpacing(2)
        mc.desc:SetWordWrap(true)
        UI.SetFont(mc.desc, 10.5, "", 0.64, 0.70, 0.78, 0.95)

        mc:Hide()
        modChoiceCards[i] = mc
    end

    local markerFlareKeybindBox = CreateFrame("Frame", nil, stepModPane)
    markerFlareKeybindBox:SetPoint("TOPLEFT", modChoiceCards[1], "BOTTOMLEFT", 0, -10)
    markerFlareKeybindBox:SetPoint("TOPRIGHT", modChoiceCards[2], "BOTTOMRIGHT", 0, -10)
    markerFlareKeybindBox:SetPoint("BOTTOM", stepModPane, "BOTTOM", 0, 0)
    markerFlareKeybindBox.bg = UI.SolidTex(markerFlareKeybindBox, "BACKGROUND", 1, 0.045, 0.052, 0.072, 0.98)
    markerFlareKeybindBox.bg:SetAllPoints()
    UI.CreatePixelBorder(markerFlareKeybindBox, 0.145, 0.165, 0.212, 0.95, 2)
    markerFlareKeybindBox:Hide()

    local mfNote = markerFlareKeybindBox:CreateFontString(nil, "OVERLAY")
    mfNote:SetPoint("TOPLEFT", markerFlareKeybindBox, "TOPLEFT", 14, -10)
    mfNote:SetPoint("TOPRIGHT", markerFlareKeybindBox, "TOPRIGHT", -14, -10)
    mfNote:SetJustifyH("LEFT")
    mfNote:SetWordWrap(true)
    UI.SetFont(mfNote, 10.5, "", 0.80, 0.85, 0.93, 0.96)
    mfNote:SetText("|cFFF5B82EWorld Flare Hotkeys (Optional):|r Start Unbound so they never overwrite F4/F5. Click to bind, Right-click to unbind.")

    local markerKeybindRefreshers = {}
    local function CreateSetupFlareKeyRow(yOff, rowTitle, rowSub, dbKey)
        local row = CreateFrame("Frame", nil, markerFlareKeybindBox)
        row:SetPoint("TOPLEFT", markerFlareKeybindBox, "TOPLEFT", 12, yOff)
        row:SetPoint("TOPRIGHT", markerFlareKeybindBox, "TOPRIGHT", -12, yOff)
        row:SetHeight(34)
        row.bg = UI.SolidTex(row, "BACKGROUND", 1, 0.072, 0.084, 0.114, 0.96)
        row.bg:SetAllPoints()
        UI.CreatePixelBorder(row, 1, 1, 1, 0.08, 2)

        local capBtn = CreateFlatButton(row, 204, 24, "Unbound (Click to Bind)", false)
        capBtn:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        capBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        local titleFs = row:CreateFontString(nil, "OVERLAY")
        titleFs:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -5)
        titleFs:SetPoint("RIGHT", capBtn, "LEFT", -10, 0)
        titleFs:SetJustifyH("LEFT")
        titleFs:SetWordWrap(false)
        UI.SetFont(titleFs, 11, "", 1, 1, 1, 0.96)
        titleFs:SetText(rowTitle)

        local subFs = row:CreateFontString(nil, "OVERLAY")
        subFs:SetPoint("TOPLEFT", titleFs, "BOTTOMLEFT", 0, -2)
        subFs:SetPoint("RIGHT", capBtn, "LEFT", -10, 0)
        subFs:SetJustifyH("LEFT")
        subFs:SetWordWrap(false)
        UI.SetFont(subFs, 9.5, "", 0.62, 0.68, 0.78, 0.92)
        subFs:SetText(rowSub)

        local function ReadBoundKey()
            local db = _G.DynamicMarkerDB or (_G.DynamicMarker and _G.DynamicMarker.db)
            local k = db and db[dbKey]
            return (type(k) == "string") and k or ""
        end

        local function CommitBoundKey(newKey)
            if type(_G.DynamicMarkerDB) ~= "table" then
                _G.DynamicMarkerDB = {}
            end
            _G.DynamicMarkerDB[dbKey] = newKey
            local dm = _G.DynamicMarker
            if type(dm) == "table" then
                if type(dm.db) == "table" then
                    dm.db[dbKey] = newKey
                end
                if type(dm.ApplyFlareKeybinds) == "function" then pcall(dm.ApplyFlareKeybinds, dm) end
                if type(dm.RefreshKeybindTelemetryAndTabTitle) == "function" then pcall(dm.RefreshKeybindTelemetryAndTabTitle, dm) end
                if type(dm.RefreshAll) == "function" then pcall(dm.RefreshAll, dm) end
            end
        end

        function capBtn:RefreshKey()
            local k = ReadBoundKey()
            local isBound = (k ~= "" and k ~= "NONE")
            local _, _, _, hex = UI.GetActiveAccentColor()
            if not isBound then
                self.label:SetText("|cFF94A3B8Unbound (Click to Bind)|r")
            else
                self.label:SetText(string.format("|cFF%s[%s]|r  |cFF94A3B8(Click Rebind)|r", hex or "F5B82E", k))
            end
        end

        function capBtn:StopCapture(commitKey)
            self.isCapturing = false
            self:EnableKeyboard(false)
            self:SetScript("OnKeyDown", nil)
            self:SetScript("OnMouseDown", nil)
            self.dsBorder:SetColor(UI.COLORS.BTN_BORDER.r, UI.COLORS.BTN_BORDER.g, UI.COLORS.BTN_BORDER.b, UI.COLORS.BTN_BORDER.a)
            if commitKey ~= nil then
                CommitBoundKey(commitKey)
            end
            self:RefreshKey()
        end

        capBtn:SetScript("OnClick", function(s, mouseBtn)
            if mouseBtn == "RightButton" then
                s:StopCapture("")
                return
            end
            if s.isCapturing then
                s:StopCapture(nil)
                return
            end
            s.isCapturing = true
            s.label:SetText("|cFFF59E0BPress key (Esc cancel, Del unbind)|r")
            s.dsBorder:SetColor(0.96, 0.62, 0.04, 0.95)
            s:EnableKeyboard(true)
            if s.SetPropagateKeyboardInput then
                s:SetPropagateKeyboardInput(false)
            end
            s:SetScript("OnKeyDown", function(btnSelf, key)
                if key == "ESCAPE" then
                    btnSelf:StopCapture(nil)
                    return
                end
                if key == "BACKSPACE" or key == "DELETE" then
                    btnSelf:StopCapture("")
                    return
                end
                if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
                    return
                end
                local prefix = ""
                if IsAltKeyDown() then prefix = prefix .. "ALT-" end
                if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
                if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
                btnSelf:StopCapture(prefix .. key)
            end)
            s:SetScript("OnMouseDown", function(btnSelf, mBtn)
                local hasMod = IsAltKeyDown() or IsControlKeyDown() or IsShiftKeyDown()
                if (mBtn == "LeftButton" or mBtn == "RightButton") and not hasMod then return end
                local prefix = ""
                if IsAltKeyDown() then prefix = prefix .. "ALT-" end
                if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
                if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
                local mapped = mBtn
                if mBtn == "LeftButton" then mapped = "BUTTON1"
                elseif mBtn == "RightButton" then mapped = "BUTTON2"
                elseif mBtn == "MiddleButton" then mapped = "BUTTON3"
                elseif type(mBtn) == "string" then mapped = string.upper(mBtn)
                end
                btnSelf:StopCapture(prefix .. mapped)
            end)
        end)

        capBtn.OnCustomEnter = function(s)
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText("Interactive Keybind Capture", 1, 1, 1)
            GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Press any key, modifier combo, or mouse button (MB3/MB4/MB5). Press Esc to cancel, or Backspace/Delete to unbind.|r", 1, 1, 1, true)
            GameTooltip:AddLine("|cFFF87171Right-Click:|r |cFFE2E8F0Clear Keybind (Unbind)|r", 1, 1, 1, true)
            GameTooltip:Show()
        end
        capBtn.OnCustomLeave = function(s)
            if GameTooltip:IsOwned(s) then GameTooltip:Hide() end
        end

        table.insert(markerKeybindRefreshers, function()
            capBtn:RefreshKey()
        end)
    end

    CreateSetupFlareKeyRow(-38, "Cycle World Flare Keybind (Optional)", "Places enabled ground markers at [@cursor] in sequence. Click to bind, Right-click to unbind.", "flareCycleKey")
    CreateSetupFlareKeyRow(-78, "Clear All Flares Keybind (Optional)", "Clears all active ground flares (/cwm all). Click to bind, Right-click to unbind.", "flareClearKey")

    local function RefreshMarkerFlareKeybinds()
        for _, fn in ipairs(markerKeybindRefreshers) do
            fn()
        end
    end
    if type(_G.DynamicMarker) == "table" then
        _G.DynamicMarker._refreshSuiteSetupKeys = function()
            RefreshMarkerFlareKeybinds()
        end
    end

    local function LayoutModChoiceGrid(numCards, stepKey)
        local w = modChoiceGrid:GetWidth() or 760
        if w < 100 then w = 760 end
        local gap = 10
        local halfW = math.floor((w - gap) / 2)
        local cardH = (stepKey == "marker" and 90) or (numCards > 2 and 96 or 116)
        for i = 1, 4 do
            local mc = modChoiceCards[i]
            if i <= numCards then
                local row = math.floor((i - 1) / 2)
                local col = (i - 1) % 2
                mc:ClearAllPoints()
                mc:SetHeight(cardH)
                if col == 0 then
                    mc:SetPoint("TOPLEFT", modChoiceGrid, "TOPLEFT", 0, -(row * 106))
                    mc:SetWidth(halfW)
                else
                    mc:SetPoint("TOPLEFT", modChoiceCards[i - 1], "TOPRIGHT", gap, 0)
                    mc:SetPoint("TOPRIGHT", modChoiceGrid, "TOPRIGHT", 0, -(row * 106))
                end
                mc:Show()
            else
                mc:Hide()
            end
        end
    end
    modChoiceGrid:SetScript("OnSizeChanged", function()
        if stepModPane:IsShown() and stepModPane.activeNumCards then
            LayoutModChoiceGrid(stepModPane.activeNumCards, stepModPane.activeStepKey)
        end
    end)

    local function StyleChoiceCard(card, isSelected)
        local ar, ag, ab = UI.GetActiveAccentColor()
        if isSelected then
            card.bg:SetColorTexture(0.063, 0.220, 0.155, 0.45)
            card.dsBorder:SetColor(0.063, 0.725, 0.506, 0.95)
            card.badge:SetTextColor(0.204, 0.827, 0.600, 1)
        else
            card.bg:SetColorTexture(0.078, 0.090, 0.122, 0.96)
            card.dsBorder:SetColor(0.145, 0.165, 0.212, 0.95)
            card.badge:SetTextColor(ar, ag, ab, 0.95)
        end
    end

    local function BuildActiveGuidedSteps()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local steps = {
            {
                key = "theme",
                pill = "1. Conflicts",
                title = "STEP 1: CONFLICT SCANNER, VISUAL THEME & ACCOUNT-WIDE ALT SYNC",
                desc = "DynamicSuite checks for overlapping addons (auto-freezing disabled addons in DynamicLoad so zone switches never re-enable them) and syncs your layout across all alts.",
                actionLabel = "Open Suite Studio",
                onAction = function() addonTable.OpenWorkspaceView("THEME_STUDIO") end,
            },
        }

        local function IsModActive(addonKey)
            if addonKey == "DynamicLoad" then return true end
            local isDis = (addonTable.IsSuiteModuleExplicitlyDisabled and addonTable.IsSuiteModuleExplicitlyDisabled(addonKey))
                or (gTbl.disabledModules and gTbl.disabledModules[addonKey])
                or (_G.DynamicSuiteDB and _G.DynamicSuiteDB.disabledModules and _G.DynamicSuiteDB.disabledModules[addonKey])
            local shortKey = tostring(addonKey):gsub("^Dynamic", ""):lower()
            local regMod = (DynamicSuite and DynamicSuite.modules and (DynamicSuite.modules[addonKey] or DynamicSuite.modules[shortKey])) or _G[addonKey]
            local isLoaded = C_AddOns.IsAddOnLoaded(addonKey) or (regMod ~= nil)
            local st = C_AddOns.GetAddOnInfo(addonKey) and (C_AddOns.GetAddOnEnableState(addonKey, pName) or 0) or 0
            return (not isDis) and (isLoaded or st > 0)
        end

        if IsModActive("DynamicLoad") then
            table.insert(steps, {
                key = "load",
                pill = (#steps + 1) .. ". Load",
                title = "DYNAMICLOAD - SMART ADDON SCANNER & OUTDOOR SAFE HARBOR",
                desc = "DynamicLoad scans your installed addons and prepares a safe combat profile so non-combat economy/collection addons never slow down Dungeons or Raids.",
                actionLabel = "Open DynamicLoad (/dl)",
                onAction = function() addonTable.OpenWorkspaceView("DYNAMICLOAD") end,
                summaryText = "|cFF38BDF8Smart Addon Scan Summary:|r\n" ..
                    "- |cFFFACC15Suite Core Modules Active Across All 5 Zones:|r DynamicLoad, DynamicMarker, DynamicZoom, DynamicFPS, DynamicPrep, DynamicGroup, DynamicBags, DynamicChat, DynamicMail\n" ..
                    "- |cFF22C55ERoutes Economy & Collection Addons to Outdoor Safe Harbor:|r TSM, Auctionator, AllTheThings, RareScanner, HandyNotes, TomTom\n" ..
                    "- |cFFCBD5E1New Addon Protection:|r Any future addon you install defaults safely to Outdoor Only until you approve it.",
                choices = {
                    {
                        title = "Apply Smart Addon Scan",
                        badge = "Recommended",
                        isSelected = function() return gTbl.guidedSetupDone == true end,
                        desc = "Keeps your Suite Core modules active across all 5 zone profiles and routes heavy non-combat utility addons to Outdoor Only (By Zone).",
                        onClick = function(card)
                            local res = addonTable.ApplySmartAddonScan()
                            card.badge:SetText(string.format("Applied (%d Routed)!", res.outdoorCount or 0))
                            StyleChoiceCard(card, true)
                            if f.scrollChild then RefreshAddonTree(f.scrollChild) end
                            UpdateStatusBar()
                        end,
                    },
                    {
                        title = "Review Addon List Manually",
                        badge = "Open Checklist ->",
                        isSelected = function() return false end,
                        desc = "Open the full DynamicLoad checklist to configure addons as By Zone, Always, or Never.",
                        onClick = function()
                            addonTable.OpenWorkspaceView("DYNAMICLOAD")
                        end,
                    },
                },
            })
        end

        if IsModActive("DynamicPrep") then
            table.insert(steps, {
                key = "prep",
                pill = (#steps + 1) .. ". Prep",
                title = "DYNAMICPREP - WOWHEAD SPEC FOLIO & EVERYDAY QOL ESSENTIALS",
                desc = "Auto-loads your specialisation's Recommended Stat Priority for Midnight Omni Folio and enables lightweight everyday convenience automation.",
                actionLabel = "Open DynamicPrep (/dprep)",
                onAction = function() addonTable.OpenPeerModule("DynamicPrep") end,
                summaryText = "|cFF38BDF8DynamicPrep Readiness Bar & Quick QoL:|r\n" ..
                    "- |cFF22C55ELive Readiness Bar:|r Displays Primary Stat, Secondary Stats, Spec/Loot, Great Vault, Keystone, Durability, and FPS/Ping.\n" ..
                    "- |cFFF5B82ELead/Assist Smart Visibility:|r Ready Check (+ RC) and Pull Timer (> Pull) automatically appear when you are Party/Raid Lead or Assist.",
                choices = {
                    {
                        title = "Auto-Load Wowhead Spec Folio Presets",
                        badge = "Enabled for All 39 Specs",
                        isSelected = function()
                            return (not _G.DynamicPrepDB) or (not _G.DynamicPrepDB.omniFolio) or (_G.DynamicPrepDB.omniFolio.presetMode ~= "CUSTOM")
                        end,
                        desc = "Automatically sets your Mythic+, Raid, Delve, and PvP Omni Folio target stats based on your active specialisation's stat priority.",
                        onClick = function(card)
                            if _G.DynamicPrep and _G.DynamicPrep.ApplyWowheadPresetForCurrentSpec then
                                pcall(_G.DynamicPrep.ApplyWowheadPresetForCurrentSpec, _G.DynamicPrep, false)
                            end
                            card.badge:SetText("Wowhead Preset Loaded!")
                            StyleChoiceCard(card, true)
                        end,
                    },
                    {
                        title = "Enable All World & Survival QoL Features",
                        badge = "Replaces EnhanceQoL",
                        isSelected = function()
                            return (not _G.DynamicPrepDB) or (_G.DynamicPrepDB.autoQuestGossip ~= false and _G.DynamicPrepDB.autoHealMacroEnabled ~= false)
                        end,
                        desc = "Enables Smart Quest & Gossip Automation, Auto-Skip Seen Cinematics, Auto-Accept Resurrection, Smart Auto-Release Spirit, and [DynamicHeal] macro.",
                        onClick = function(card)
                            if _G.DynamicPrepDB then
                                _G.DynamicPrepDB.autoQuestGossip = true
                                _G.DynamicPrepDB.cinematicMode = "BOTH"
                                _G.DynamicPrepDB.autoRezMode = "OUT_OF_COMBAT"
                                _G.DynamicPrepDB.autoReleaseMode = "WIPE_AND_CTRL"
                                _G.DynamicPrepDB.autoHealMacroEnabled = true
                            end
                            if _G.DynamicBagsDB then
                                _G.DynamicBagsDB.autoRepairEnabled = true
                                _G.DynamicBagsDB.autoSellGrey = true
                                _G.DynamicBagsDB.autoSellJunk = true
                                _G.DynamicBagsDB.fastAutoLoot = true
                                _G.DynamicBagsDB.autoFillDelete = true
                            end
                            if _G.DynamicGroupDB then
                                _G.DynamicGroupDB.autoInsertKeystone = true
                            end
                            if _G.DynamicPrep and _G.DynamicPrep.UpdateHealMacro then
                                pcall(_G.DynamicPrep.UpdateHealMacro, _G.DynamicPrep, false)
                            end
                            if _G.DynamicPrep and _G.DynamicPrep.UpdateTalkingHeadSuppression then
                                pcall(_G.DynamicPrep.UpdateTalkingHeadSuppression, _G.DynamicPrep)
                            end
                            card.badge:SetText("All QoL Enabled!")
                            StyleChoiceCard(card, true)
                        end,
                    },
                },
            })
        end

        if IsModActive("DynamicMarker") then
            table.insert(steps, {
                key = "marker",
                pill = (#steps + 1) .. ". Marker",
                title = "DYNAMICMARKER - 1-CLICK MACROS, FOCUS ICON & WORLD FLARES",
                desc = "Set up your modifier-free [DynamicMark] macro and multi-spec [DynamicKick] interrupt macro (Mouseover > Focus > Target) in a single click.",
                actionLabel = "Open DynamicMarker (/dm)",
                onAction = function() addonTable.OpenPeerModule("DynamicMarker") end,
                summaryText = "|cFF38BDF8DynamicMarker Automation:|r\n" ..
                    "- |cFF22C55E[DynamicMark] & [DynamicKick] Macros:|r Focuses and marks your target cleanly, plus auto-swaps class interrupts on spec change.\n" ..
                    "- |cFFF5B82EWorld Flare Hotkeys (Unbound by Default):|r Start Unbound so your F4/F5 bindings stay untouched unless assigned below or in /dm flares.",
                choices = {
                    {
                        title = "1-Click Create Both Macros + Alt Auto-Sync",
                        badge = "Click to Create",
                        isSelected = function()
                            return _G.DynamicMarker and _G.DynamicMarker.FindFocusMacroIndex and ((_G.DynamicMarker:FindFocusMacroIndex() or 0) > 0)
                        end,
                        desc = "Creates [DynamicMark] in General Macros AND creates [DynamicKick] per character with automatic spec-swap interrupt detection.",
                        onClick = function(card)
                            if _G.DynamicMarker then
                                if _G.DynamicMarker.CreateOrUpdateFocusMarkerMacro then pcall(_G.DynamicMarker.CreateOrUpdateFocusMarkerMacro, _G.DynamicMarker, true) end
                                if _G.DynamicMarker.CreateOrUpdateDynamicKickMacro then pcall(_G.DynamicMarker.CreateOrUpdateDynamicKickMacro, _G.DynamicMarker, true) end
                            end
                            card.badge:SetText("Both Macros Created!")
                            StyleChoiceCard(card, true)
                        end,
                    },
                    {
                        title = "Open World Flare Keys Tab (/dm flares)",
                        badge = "Optional Hotkeys",
                        isSelected = function()
                            local db = _G.DynamicMarkerDB or (_G.DynamicMarker and _G.DynamicMarker.db)
                            local c1 = db and db.flareCycleKey
                            local c2 = db and db.flareClearKey
                            return (type(c1) == "string" and c1 ~= "" and c1 ~= "NONE")
                                or (type(c2) == "string" and c2 ~= "" and c2 ~= "NONE")
                        end,
                        desc = "World Flare hotkeys start Unbound by default. Assign or unbind them right below, or open /dm flares to reorder the 8 markers.",
                        onClick = function()
                            addonTable.OpenPeerModule("DynamicMarker")
                        end,
                    },
                },
            })
        end

        if IsModActive("DynamicZoom") then
            table.insert(steps, {
                key = "zoom",
                pill = (#steps + 1) .. ". Zoom",
                title = "DYNAMICZOOM - 39-YARD MAX CAMERA & SEE-THROUGH FOLIAGE",
                desc = "Unlock the maximum 39-yard tactical overview and stop tree branches, doorways, or dungeon pillars from snapping your camera inward.",
                actionLabel = "Open DynamicZoom (/dz)",
                onAction = function() addonTable.OpenPeerModule("DynamicZoom") end,
                summaryText = "|cFF38BDF8How DynamicZoom Smooths Your Camera:|r\n" ..
                    "- |cFF22C55EFast Scroll Wheel Boost:|r One fast mousewheel flick glides smoothly to 39 yards while slow ticks step precisely.\n" ..
                    "- |cFFF5B82ESee-Through Trees & Dungeon Pillars:|r Fades intersecting trees and pillars to translucent instead of jerking your camera forward.",
                choices = {
                    {
                        title = "39-Yard Max Distance + Ignore Trees & Pillars",
                        badge = "Recommended",
                        isSelected = function()
                            return (not _G.DynamicZoomDB) or ((_G.DynamicZoomDB.maxZoomYards or 39) >= 39 and _G.DynamicZoomDB.indirectVisibility ~= false)
                        end,
                        desc = "Keeps your camera at the full 39-yard distance and glides smoothly past trees, banners, water surfaces, and dungeon pillars.",
                        onClick = function(card)
                            if _G.DynamicZoomDB then
                                _G.DynamicZoomDB.maxZoomYards = 39
                                _G.DynamicZoomDB.indirectVisibility = true
                                _G.DynamicZoomDB.reactiveScrollEnabled = true
                            end
                            if _G.DynamicZoom then
                                if _G.DynamicZoom.ApplyEngineSettings then pcall(_G.DynamicZoom.ApplyEngineSettings, _G.DynamicZoom) end
                                if _G.DynamicZoom.SmoothZoomTo then pcall(_G.DynamicZoom.SmoothZoomTo, _G.DynamicZoom, 39, 0.50) end
                            end
                            card.badge:SetText("39 yd Max Applied!")
                            StyleChoiceCard(card, true)
                        end,
                    },
                    {
                        title = "Customise Automatic Zone Zoom",
                        badge = "Open Modes ->",
                        isSelected = function() return false end,
                        desc = "Fine-tune per-zone target distances across Raids, Mythic+, Delves, Open World, and optional NPC dialogue framing.",
                        onClick = function()
                            addonTable.OpenPeerModule("DynamicZoom")
                        end,
                    },
                },
            })
        end

        if IsModActive("DynamicFPS") then
            local selectedTier = ( _G.DynamicFPSDB and _G.DynamicFPSDB.activePresets and _G.DynamicFPSDB.activePresets.RAID ) or "COMPETITIVE"
            local function ApplyTierToAllCombatZones(tierKey, card)
                if _G.DynamicFPS and _G.DynamicFPS.ApplyStarterPresetToZone then
                    for _, zk in ipairs({ "CITIES", "DELVES", "DUNGEONS", "RAID", "PVP" }) do
                        pcall(_G.DynamicFPS.ApplyStarterPresetToZone, zk, tierKey)
                    end
                    if tierKey == "LOW" then
                        pcall(_G.DynamicFPS.ApplyStarterPresetToZone, "OUTDOOR", "LOW")
                    elseif tierKey == "BALANCED" then
                        pcall(_G.DynamicFPS.ApplyStarterPresetToZone, "OUTDOOR", "BALANCED")
                    else
                        pcall(_G.DynamicFPS.ApplyStarterPresetToZone, "OUTDOOR", "ULTRA")
                    end
                end
                selectedTier = tierKey
                setupView.Refresh()
            end
            table.insert(steps, {
                key = "fps",
                pill = (#steps + 1) .. ". FPS",
                title = "DYNAMICFPS - PICK YOUR PC HARDWARE TIER (INSTANT GRAPHICS SWITCHING)",
                desc = "Click your PC tier below to pre-configure all 6 Zone Graphics tabs. Boss ground swirlies and projected textures are 100% hard-locked ON.",
                actionLabel = "Open DynamicFPS (/dfps)",
                onAction = function() addonTable.OpenPeerModule("DynamicFPS") end,
                choices = {
                    {
                        title = "Competitive Raid & Mythic+ FPS",
                        badge = (selectedTier == "COMPETITIVE") and "Active Tier" or "Most Popular",
                        isSelected = function() return selectedTier == "COMPETITIVE" end,
                        desc = "Maximizes combat frame rates in Dungeons, Cities & Raids (Low Shadows, Essential Spell Visuals, Zero Compute) while keeping Outdoor Ultra.",
                        onClick = function(card) ApplyTierToAllCombatZones("COMPETITIVE", card) end,
                    },
                    {
                        title = "Low-End PC / Laptop Saver",
                        badge = (selectedTier == "LOW") and "Active Tier" or "Click to Apply",
                        isSelected = function() return selectedTier == "LOW" end,
                        desc = "Protects Outdoor, Capital Cities & Raids from lag spikes by lowering view distance, ground clutter, and shadows everywhere.",
                        onClick = function(card) ApplyTierToAllCombatZones("LOW", card) end,
                    },
                    {
                        title = "Balanced Visuals & Smooth FPS",
                        badge = (selectedTier == "BALANCED") and "Active Tier" or "Click to Apply",
                        isSelected = function() return selectedTier == "BALANCED" end,
                        desc = "Rich outdoor visuals with instant automatic graphics reductions when entering Raids, Mythic+, or busy cities.",
                        onClick = function(card) ApplyTierToAllCombatZones("BALANCED", card) end,
                    },
                    {
                        title = "High-End PC Ultra",
                        badge = (selectedTier == "ULTRA") and "Active Tier" or "Click to Apply",
                        isSelected = function() return selectedTier == "ULTRA" end,
                        desc = "High visual quality across all zones while keeping your spell queue smooth and boss ground effects visible.",
                        onClick = function(card) ApplyTierToAllCombatZones("ULTRA", card) end,
                    },
                },
            })
        end

        if IsModActive("DynamicGroup") then
            table.insert(steps, {
                key = "group",
                pill = (#steps + 1) .. ". Group",
                title = "DYNAMICGROUP - LFG REGION FILTER, LIVE ROSTER & 1-CLICK SIGN-UP",
                desc = "Upgrades Blizzard's Premade Groups window in-place with Datacentre Region badges, Leader M+ Score, 5-slot class role dots, and 1-Click Sign-Up.",
                actionLabel = "Open DynamicGroup (/dgroup)",
                onAction = function() addonTable.OpenPeerModule("DynamicGroup") end,
                summaryText = "|cFF38BDF8DynamicGroup Premade LFG & Party Engine:|r\n" ..
                    "- |cFF22C55EDatacentre Region Filtering:|r Filter Premade LFG groups by OCE, US-West, US-Central, US-East, Latin America, and Brazil.\n" ..
                    "- |cFFF5B82EWhisper Keyword & Friend/Guild Auto-Invite:|r Instant party invites via custom whisper keywords plus Queue Protection Shield.",
                choices = {
                    {
                        title = "Upgrade Blizzard Premade Groups In-Place",
                        badge = "Active",
                        isSelected = function() return (not _G.DynamicGroupDB) or (_G.DynamicGroupDB.lfgFilterEnabled ~= false) end,
                        desc = "Adds Region tags ([OCE], [US-W], [US-C], [US-E], [LATAM], [BR]), Leader IO, Lust/CR badges, and 5-slot role pills inside LFG.",
                        onClick = function(card)
                            if _G.DynamicGroupDB then
                                _G.DynamicGroupDB.lfgFilterEnabled = true
                                _G.DynamicGroupDB.overlayMode = "FULL"
                            end
                            card.badge:SetText("LFG Upgrade Active!")
                            StyleChoiceCard(card, true)
                        end,
                    },
                    {
                        title = "Enable 1-Click Sign-Up & Auto-Role",
                        badge = "Active",
                        isSelected = function() return (not _G.DynamicGroupDB) or (_G.DynamicGroupDB.oneClickSignUp ~= false) end,
                        desc = "Automatically selects your active specialisation role, pre-fills your note, and signs up in 1 click (hold Shift/Alt to customise).",
                        onClick = function(card)
                            if _G.DynamicGroupDB then
                                _G.DynamicGroupDB.oneClickSignUp = true
                                _G.DynamicGroupDB.autoSelectRole = true
                            end
                            card.badge:SetText("1-Click Sign-Up Active!")
                            StyleChoiceCard(card, true)
                        end,
                    },
                },
            })
        end

        if IsModActive("DynamicBags") then
            table.insert(steps, {
                key = "bags",
                pill = (#steps + 1) .. ". Bags",
                title = "DYNAMICBAGS - VIRTUAL CATEGORIES & ALT VAULT",
                desc = "Zero-lag virtual category sorting, alt vault remote viewing, and native Blizzard bag replacement (/dbag).",
                actionLabel = "Open DynamicBags (/dbag)",
                onAction = function() addonTable.OpenPeerModule("DynamicBags") end,
                summaryText = "|cFF38BDF8DynamicBags Zero-Lag Virtual Sorting Engine:|r\n" ..
                    "- |cFF22C55EVirtual Category Sorting:|r Pre-computes layout in memory so opening bags never triggers a server sort.\n" ..
                    "- |cFFF5B82EBuilt-In Alt Vault:|r Remote read-only viewing of alts & Warband Bank + aggregated tooltip item counts.",
                choices = {
                    {
                        title = "Mythic+ & Raid Ready Preset",
                        badge = "Recommended",
                        isSelected = function()
                            return _G.DynamicBagsDB and (_G.DynamicBagsDB.preset == "MYTHIC" or _G.DynamicBagsDB.replaceBlizzardBags ~= false)
                        end,
                        desc = "Enables virtual categories (Keystones, Consumables, Gear Sets, BoE/WUE, Junk) and replaces default Blizzard bags on 'B'.",
                        onClick = function(card)
                            if _G.DynamicBags and _G.DynamicBags.U and _G.DynamicBags.U.ApplyPreset then
                                pcall(_G.DynamicBags.U.ApplyPreset, "MYTHIC")
                            end
                            card.badge:SetText("Preset Active!")
                            StyleChoiceCard(card, true)
                        end,
                    },
                    {
                        title = "Enable All Auto-Open Triggers",
                        badge = "Active",
                        isSelected = function()
                            return _G.DynamicBagsDB and _G.DynamicBagsDB.autoOpen and _G.DynamicBagsDB.autoOpen.bank == true
                        end,
                        desc = "Opens DynamicBags automatically when visiting Bankers, Vendors, Mailboxes, Item Upgrade, and Catalysts.",
                        onClick = function(card)
                            if _G.DynamicBagsDB and _G.DynamicBagsDB.autoOpen then
                                for k in pairs(_G.DynamicBagsDB.autoOpen) do
                                    _G.DynamicBagsDB.autoOpen[k] = true
                                end
                            end
                            card.badge:SetText("Triggers Active!")
                            StyleChoiceCard(card, true)
                        end,
                    },
                },
            })
        end

        if IsModActive("DynamicChat") then
            table.insert(steps, {
                key = "chat",
                pill = (#steps + 1) .. ". Chat",
                title = "DYNAMICCHAT - TARGET WHISPER (/WW), CHANNEL TAGS & GPU BUFFER",
                desc = "Instant target whisper (/ww), combat whisper protection, compact [P]/[R]/[G] channel tags, and chat history cap (/dchat).",
                actionLabel = "Open DynamicChat (/dchat)",
                onAction = function() addonTable.OpenPeerModule("DynamicChat") end,
                summaryText = "|cFF38BDF8DynamicChat Engine:|r\n" ..
                    "- |cFF22C55ESignature /ww Target Whisper:|r Converts '/ww ' in the chat box into a direct whisper to your friendly player target.\n" ..
                    "- |cFFF5B82ECombat Whisper Rescue & Memory Cap:|r Rescues dropped combat whispers, shortens [P]/[R]/[G]/[I] tags, and caps chat history at 250 lines.",
                choices = {
                    {
                        title = "Enable All Chat QoL & GPU Buffer Optimizations",
                        badge = "Recommended",
                        isSelected = function()
                            return not _G.DynamicChatDB or (_G.DynamicChatDB.enableTargetWhisper ~= false and _G.DynamicChatDB.shortChannelNames ~= false)
                        end,
                        desc = "Enables /ww Target Whisper, Combat Whisper Protection, [P]/[R]/[G] compact channel tags, and the 250-line GPU buffer cap.",
                        onClick = function(card)
                            if _G.DynamicChat and _G.DynamicChat.ApplyAllEngineSettings then
                                if _G.DynamicChatDB then
                                    _G.DynamicChatDB.enableTargetWhisper = true
                                    _G.DynamicChatDB.protectCombatWhispers = true
                                    _G.DynamicChatDB.enableGPUBufferCap = true
                                    _G.DynamicChatDB.maxChatLines = 250
                                    _G.DynamicChatDB.shortChannelNames = true
                                    _G.DynamicChatDB.arrowHistoryNoAlt = true
                                    _G.DynamicChatDB.fastChatScroll = true
                                    _G.DynamicChatDB.clickableURLs = true
                                end
                                pcall(_G.DynamicChat.ApplyAllEngineSettings, _G.DynamicChat)
                            end
                            card.badge:SetText("Chat QoL Active!")
                            StyleChoiceCard(card, true)
                        end,
                    },
                    {
                        title = "Reset Whisper After Sending (Non-Sticky)",
                        badge = "Active",
                        isSelected = function()
                            return not _G.DynamicChatDB or _G.DynamicChatDB.stickyWhisper == false
                        end,
                        desc = "Returns your typing box to Party, Raid, or Guild after sending a whisper so you never accidentally whisper callouts.",
                        onClick = function(card)
                            if _G.DynamicChatDB then _G.DynamicChatDB.stickyWhisper = false end
                            if _G.DynamicChat and _G.DynamicChat.ApplyStickyChannels then
                                pcall(_G.DynamicChat.ApplyStickyChannels, _G.DynamicChat)
                            end
                            card.badge:SetText("Non-Sticky Active!")
                            StyleChoiceCard(card, true)
                        end,
                    },
                },
            })
        end

        if IsModActive("DynamicMail") then
            table.insert(steps, {
                key = "mail",
                pill = (#steps + 1) .. ". Mail",
                title = "DYNAMICMAIL - INBOX AUTOMATION, ALT PICKER & EXPRESS ATTACH",
                desc = "1-click Open All, AH Gold, and Items Only collection with bag-reserve protection plus an Obsidian Alt Vault recipient picker (/dmail).",
                actionLabel = "Open DynamicMail (/dmail)",
                onAction = function() addonTable.OpenPeerModule("DynamicMail") end,
                summaryText = "|cFF38BDF8DynamicMail Automation:|r\n" ..
                    "- |cFF22C55ESmart Inbox Bar:|r Open All, AH Gold, and Items Only buttons below MailFrame with strict COD & free bag-slot reserve guards.\n" ..
                    "- |cFFF5B82EAlt Vault Picker & Express Attach:|r Syncs alts & gold from DynamicBags Vault and lets you Alt + Left-Click bag items into Send Mail.",
                choices = {
                    {
                        title = "Enable Inbox Bar, Alt Picker & Express Attach",
                        badge = "Recommended",
                        isSelected = function()
                            return (not _G.DynamicMailDB) or (_G.DynamicMailDB.mailboxBarEnabled ~= false and _G.DynamicMailDB.recipientPanelEnabled ~= false and _G.DynamicMailDB.altClickAttach ~= false)
                        end,
                        desc = "Enables Open All / AH Gold / Items Only mailbox buttons, the 4-tab Recipient Picker, DynamicBags Vault sync, and Alt + Left-Click attach.",
                        onClick = function(card)
                            if _G.DynamicMailDB then
                                _G.DynamicMailDB.enabled = true
                                _G.DynamicMailDB.mailboxBarEnabled = true
                                _G.DynamicMailDB.recipientPanelEnabled = true
                                _G.DynamicMailDB.syncDynamicBagsVault = true
                                _G.DynamicMailDB.altClickAttach = true
                            end
                            card.badge:SetText("Mail Tools Active!")
                            StyleChoiceCard(card, true)
                        end,
                    },
                    {
                        title = "Reserve 2 Free Bag Slots During Open All",
                        badge = "Safe Mode",
                        isSelected = function()
                            return _G.DynamicMailDB and (_G.DynamicMailDB.keepFreeBagSlots or 1) >= 2
                        end,
                        desc = "Pauses item looting once 2 bag slots remain free while continuing to collect pure Auction House gold payouts.",
                        onClick = function(card)
                            if _G.DynamicMailDB then
                                _G.DynamicMailDB.keepFreeBagSlots = 2
                                _G.DynamicMailDB.collectGoldWhenBagsFull = true
                            end
                            card.badge:SetText("2-Slot Reserve Set!")
                            StyleChoiceCard(card, true)
                        end,
                    },
                },
            })
        end

        return steps
    end

    local function LayoutStepPills(steps)
        local w = stepNavBar:GetWidth() or 780
        if w < 100 then w = 780 end
        local count = #steps
        local gap = 4
        local eachW = math.floor((w - 8 - ((count - 1) * gap)) / math.max(1, count))
        local ar, ag, ab = UI.GetActiveAccentColor()
        local accentCol = { r = ar, g = ag, b = ab }

        for i = 1, 10 do
            local btn = stepPillBtns[i]
            local sDef = steps[i]
            if sDef then
                btn.label:SetText(sDef.pill)
                btn:ClearAllPoints()
                if i == 1 then
                    btn:SetPoint("LEFT", stepNavBar, "LEFT", 4, 0)
                    btn:SetWidth(eachW)
                elseif i == count then
                    btn:SetPoint("LEFT", stepPillBtns[i - 1], "RIGHT", gap, 0)
                    btn:SetPoint("RIGHT", stepNavBar, "RIGHT", -4, 0)
                else
                    btn:SetPoint("LEFT", stepPillBtns[i - 1], "RIGHT", gap, 0)
                    btn:SetWidth(eachW)
                end
                btn:SetSelected(i == currentGuidedIdx, accentCol)
                btn:SetScript("OnClick", function()
                    currentGuidedIdx = i
                    setupView.Refresh()
                end)
                btn:Show()
            else
                btn:Hide()
            end
        end
    end
    stepNavBar:SetScript("OnSizeChanged", function()
        if setupView:IsShown() and setupView.Refresh then
            setupView.Refresh()
        end
    end)

    setupView.Refresh = function()
        local steps = BuildActiveGuidedSteps()
        if currentGuidedIdx > #steps then currentGuidedIdx = 1 end
        if currentGuidedIdx < 1 then currentGuidedIdx = 1 end
        local step = steps[currentGuidedIdx]
        if not step then return end

        local ar, ag, ab = UI.GetActiveAccentColor()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        LayoutStepPills(steps)

        wizHdrTitle:SetTextColor(ar, ag, ab, 1)
        wizHdrTitle:SetText(string.format("STEP %d OF %d - %s", currentGuidedIdx, #steps, step.title))
        wizDesc:SetText(step.desc or "")

        wizOpenModBtn.label:SetText(step.actionLabel or "Open Module")
        local lw = wizOpenModBtn.label:GetStringWidth() or 120
        wizOpenModBtn:SetWidth(math.max(148, math.ceil(lw + 24)))
        wizOpenModBtn:SetScript("OnClick", function()
            if step.onAction then step.onAction() end
        end)

        local enabledCount = math.max(1, #steps - 1)
        wizFooterInfo:SetText(string.format("Tailored to your %d active module%s  *  Synced across alts", enabledCount, enabledCount == 1 and "" or "s"))

        if currentGuidedIdx > 1 then
            wizPrevBtn:Show()
            wizPrevBtn:SetScript("OnClick", function()
                currentGuidedIdx = currentGuidedIdx - 1
                setupView.Refresh()
            end)
        else
            wizPrevBtn:Hide()
        end

        if currentGuidedIdx < #steps then
            local nextStep = steps[currentGuidedIdx + 1]
            wizNextBtn.label:SetText(string.format("Next Step (%s) >", nextStep.pill:gsub("^%d+%.%s*", "")))
            local nw = wizNextBtn.label:GetStringWidth() or 150
            wizNextBtn:SetWidth(math.max(180, math.ceil(nw + 28)))
            wizNextBtn:SetSelected(true, { r = 0.063, g = 0.725, b = 0.506 })
            wizNextBtn:SetScript("OnClick", function()
                currentGuidedIdx = currentGuidedIdx + 1
                setupView.Refresh()
            end)
        else
            wizNextBtn.label:SetText("Finish Guided Setup (Save)")
            wizNextBtn:SetWidth(204)
            wizNextBtn:SetSelected(true, { r = 0.063, g = 0.725, b = 0.506 })
            wizNextBtn:SetScript("OnClick", function()
                gTbl.guidedSetupDone = true
                addonTable.OpenWorkspaceView("DYNAMICLOAD")
            end)
        end

        if step.key == "theme" then
            if lastGuidedStepKey ~= "theme" then
                conflictScrollFrame:SetVerticalScroll(0)
            end
            lastGuidedStepKey = "theme"
            step1Pane:Show()
            stepModPane:Hide()
            wizOpenModBtn:Hide()
            simToggleBtn:ClearAllPoints()
            simToggleBtn:SetPoint("TOPRIGHT", wizCard, "TOPRIGHT", -16, -11)
            simToggleBtn:Show()
            local simOn = addonTable.GetSimulatedConflictPreview and addonTable.GetSimulatedConflictPreview()
            simToggleBtn:SetWidth(64)
            simToggleBtn.label:SetText("Demo")
            simToggleBtn:SetSelected(simOn == true, UI.COLORS.GOLD)

            local rawConflicts = addonTable.ScanAllConflicts and addonTable.ScanAllConflicts(true, true) or {}
            local conflicts = {}
            local seenConflictKeys = {}
            for _, cItem in ipairs(rawConflicts) do
                local dKey = cItem.conflictKey or (tostring(cItem.conflictAddon or "") .. "_" .. tostring(cItem.dynamicModule or ""))
                if not seenConflictKeys[dKey] then
                    seenConflictKeys[dKey] = true
                    table.insert(conflicts, cItem)
                end
            end
            local unacknowledgedCount = addonTable.GetUnresolvedConflictCount and addonTable.GetUnresolvedConflictCount() or 0
            RefreshLeftRailVisuals()

            resolveAllBtn:ClearAllPoints()
            resolveAllBtn:SetPoint("RIGHT", simToggleBtn, "LEFT", -6, 0)
            resolveAllBtn:Show()
            wizHdrTitle:SetPoint("RIGHT", resolveAllBtn, "LEFT", -10, 0)

            if #conflicts > 0 then
                if unacknowledgedCount > 0 then
                    wizHdrTitle:SetText(string.format("STEP %d OF %d - CONFLICT SCANNER (%d ACTIVE)", currentGuidedIdx, #steps, unacknowledgedCount))
                    resolveAllBtn:SetWidth(124)
                    resolveAllBtn.label:SetText("Use All Dynamic")
                    resolveAllBtn:Enable()
                    resolveAllBtn:SetAlpha(1.0)
                    resolveAllBtn:SetSelected(true, UI.COLORS.GOLD)
                    resolveAllBtn:SetScript("OnClick", function()
                        for _, item in ipairs(conflicts) do
                            if not item.isAcknowledged then
                                local act
                                if item.tier == 2 or item.isGranular then
                                    act = "PRIORITISE_DYNAMIC"
                                else
                                    act = "USE_DYNAMIC"
                                end
                                addonTable.ResolveConflict(item.dynamicModule, item.conflictAddon, act, item.isSimulated)
                            end
                        end
                        setupView.Refresh()
                        if f.scrollChild then RefreshAddonTree(f.scrollChild) end
                        UpdateStatusBar()
                    end)
                elseif addonTable._conflictPendingReload then
                    wizHdrTitle:SetText(string.format("STEP %d OF %d - CONFLICT SCANNER (RELOAD REQUIRED)", currentGuidedIdx, #steps))
                    resolveAllBtn:SetWidth(118)
                    resolveAllBtn.label:SetText("Reload UI Now")
                    resolveAllBtn:Enable()
                    resolveAllBtn:SetAlpha(1.0)
                    resolveAllBtn:SetSelected(true, UI.COLORS.EMERALD)
                    resolveAllBtn:SetScript("OnClick", function()
                        if type(_G.ReloadUI) == "function" then
                            _G.ReloadUI()
                        end
                    end)
                else
                    wizHdrTitle:SetText(string.format("STEP %d OF %d - CONFLICT SCANNER (ALL RESOLVED)", currentGuidedIdx, #steps))
                    resolveAllBtn:SetWidth(124)
                    resolveAllBtn.label:SetText("Use All Dynamic")
                    resolveAllBtn:SetSelected(false)
                    resolveAllBtn:Disable()
                    resolveAllBtn:SetAlpha(0.40)
                    resolveAllBtn.bg:SetColorTexture(0.06, 0.07, 0.09, 0.65)
                    resolveAllBtn.dsBorder:SetColor(1, 1, 1, 0.08)
                    resolveAllBtn.label:SetTextColor(0.48, 0.52, 0.58, 0.85)
                    resolveAllBtn:SetScript("OnClick", nil)
                end
            else
                resolveAllBtn:SetWidth(76)
                resolveAllBtn.label:SetText("Resolve")
                resolveAllBtn:SetSelected(false)
                resolveAllBtn:Disable()
                resolveAllBtn:SetAlpha(0.40)
                resolveAllBtn.bg:SetColorTexture(0.06, 0.07, 0.09, 0.65)
                resolveAllBtn.dsBorder:SetColor(1, 1, 1, 0.08)
                resolveAllBtn.label:SetTextColor(0.48, 0.52, 0.58, 0.85)
                resolveAllBtn:SetScript("OnClick", nil)
            end

            if #conflicts == 0 then
                zeroConflictBanner:Show()
                conflictScrollFrame:SetVerticalScroll(0)
                conflictScrollFrame:Hide()
                conflictScrollTrack:Hide()
                for _, cCard in ipairs(conflictCards) do cCard:Hide() end
            else
                zeroConflictBanner:Hide()
                conflictScrollFrame:Show()
                local checkTex = string.format("|TInterface\\AddOns\\%s\\Media\\Icons\\icon_check.tga:10:10:0:0:16:16:0:16:0:16:52:211:153|t", ADDON_FOLDER)
                for i, item in ipairs(conflicts) do
                    local cCard = EnsureConflictCard(i)
                    if item then
                        local cleanFriendly = (addonTable.FRIENDLY_CONFLICT_NAMES and addonTable.FRIENDLY_CONFLICT_NAMES[item.conflictAddon])
                            or item.friendlyName
                            or item.conflictAddon:gsub("_", " ")
                        cleanFriendly = cleanFriendly:gsub("%s*%[Preview%]", "")
                        local shortExternal = cleanFriendly:gsub("%s*%b()", "")
                        if shortExternal == "" then
                            shortExternal = item.conflictAddon:gsub("_", " ")
                        end

                        local cleanModName = item.dynamicModule or "DynamicSuite"
                        if cleanModName == "bags" then cleanModName = "DynamicBags"
                        elseif cleanModName == "chat" then cleanModName = "DynamicChat"
                        elseif cleanModName == "mail" then cleanModName = "DynamicMail"
                        elseif cleanModName == "load" then cleanModName = "DynamicLoad"
                        elseif cleanModName == "marker" then cleanModName = "DynamicMarker"
                        elseif cleanModName == "zoom" then cleanModName = "DynamicZoom"
                        elseif cleanModName == "fps" then cleanModName = "DynamicFPS"
                        elseif cleanModName == "prep" then cleanModName = "DynamicPrep"
                        elseif cleanModName == "group" then cleanModName = "DynamicGroup"
                        elseif cleanModName == "studio" or cleanModName == "STUDIO" or cleanModName == "DynamicSuite" or cleanModName == "DesktopWindows" then cleanModName = "DynamicSuite (Suite Studio)" end

                        local activeChoice = item.resolvedAction
                        local isTier2 = (item.tier == 2 or item.isGranular == true)
                        local isDecorVendor = (item.conflictAddon == "DecorVendor")

                        cCard.title:SetText(string.format("%s  <->  %s", cleanFriendly, cleanModName))
                        if isDecorVendor then
                            cCard.btnUseDynamic.label:SetText("Disable Decor Vendor (Set to Never)")
                            cCard.btnKeepOther.label:SetText("Keep Decor Vendor")
                        elseif isTier2 then
                            cCard.btnUseDynamic.label:SetText("Prioritise DynamicSuite Features")
                            cCard.btnKeepOther.label:SetText("Yield Features to " .. shortExternal)
                        else
                            cCard.btnUseDynamic.label:SetText("Use " .. cleanModName .. " Only")
                            cCard.btnKeepOther.label:SetText("Use " .. shortExternal .. " Only")
                        end

                        local emeraldSel = { r = 0.063, g = 0.725, b = 0.506 }
                        local skySel     = { r = 0.220, g = 0.741, b = 0.973 }

                        if isDecorVendor then
                            if activeChoice == "USE_DYNAMIC" then
                                cCard.bg:SetColorTexture(0.024, 0.039, 0.031, 0.96)
                                cCard.dsBorder:SetColor(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 0.85)
                                cCard.leftBar:SetColorTexture(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 1.0)
                                cCard.statusPill.bg:SetColorTexture(0.035, 0.14, 0.10, 0.92)
                                cCard.statusPill.dsBorder:SetColor(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 0.90)
                                cCard.statusText:SetTextColor(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 1.0)
                                cCard.statusText:SetText(string.format("[%s Disabled - Exit & Restart]", checkTex))
                                cCard.desc:SetText("Resolved: Decor Vendor is disabled and set to [Never]. Exit & Restart World of Warcraft to clear /tm taint.")
                            elseif activeChoice == "KEEP_OTHER" then
                                cCard.bg:SetColorTexture(0.035, 0.039, 0.051, 0.96)
                                cCard.dsBorder:SetColor(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 0.85)
                                cCard.leftBar:SetColorTexture(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 1.0)
                                cCard.statusPill.bg:SetColorTexture(0.035, 0.14, 0.10, 0.92)
                                cCard.statusPill.dsBorder:SetColor(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 0.90)
                                cCard.statusText:SetTextColor(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 1.0)
                                cCard.statusText:SetText(string.format("[%s Keeping Decor Vendor]", checkTex))
                                cCard.desc:SetText("Keeping Decor Vendor enabled and disabling DynamicMarker.")
                            else
                                cCard.bg:SetColorTexture(0.13, 0.08, 0.04, 0.96)
                                cCard.dsBorder:SetColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.88)
                                cCard.leftBar:SetColorTexture(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1.0)
                                cCard.statusPill.bg:SetColorTexture(0.16, 0.10, 0.04, 0.95)
                                cCard.statusPill.dsBorder:SetColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.90)
                                cCard.statusText:SetTextColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1.0)
                                cCard.statusText:SetText("[! /tm Taint Conflict]")
                                cCard.desc:SetText("Action Required: Decor Vendor taints Blizzard's /tm raid marker command. Disable it (Set to Never) and restart the game.")
                            end
                        elseif isTier2 then
                            if activeChoice == "PRIORITISE_DYNAMIC" then
                                cCard.bg:SetColorTexture(0.04, 0.14, 0.09, 0.92)
                                cCard.dsBorder:SetColor(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 0.85)
                                cCard.leftBar:SetColorTexture(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 1.0)
                                cCard.statusPill.bg:SetColorTexture(0.05, 0.22, 0.14, 0.90)
                                cCard.statusPill.dsBorder:SetColor(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 0.90)
                                cCard.statusText:SetTextColor(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 1.0)
                                cCard.statusText:SetText(string.format("[%s Prioritising DynamicSuite]", checkTex))
                                cCard.desc:SetText(string.format("Both addons stay enabled. %s owns overlapping features and guards against double-firing.", cleanModName))
                            elseif activeChoice == "YIELD_TO_EXTERNAL" then
                                cCard.bg:SetColorTexture(0.04, 0.11, 0.16, 0.92)
                                cCard.dsBorder:SetColor(skySel.r, skySel.g, skySel.b, 0.85)
                                cCard.leftBar:SetColorTexture(skySel.r, skySel.g, skySel.b, 1.0)
                                cCard.statusPill.bg:SetColorTexture(0.05, 0.16, 0.24, 0.90)
                                cCard.statusPill.dsBorder:SetColor(skySel.r, skySel.g, skySel.b, 0.90)
                                cCard.statusText:SetTextColor(skySel.r, skySel.g, skySel.b, 1.0)
                                cCard.statusText:SetText(item.isAutoYielded and string.format("[%s Auto-Yield Active]", checkTex) or string.format("[%s Yielding to %s]", checkTex, shortExternal))
                                cCard.desc:SetText(string.format("Both addons stay enabled. Overlapping %s sub-toggles are off while core features stay active.", cleanModName))
                            else
                                cCard.bg:SetColorTexture(0.05, 0.10, 0.15, 0.92)
                                cCard.dsBorder:SetColor(skySel.r, skySel.g, skySel.b, 0.80)
                                cCard.leftBar:SetColorTexture(skySel.r, skySel.g, skySel.b, 1.0)
                                cCard.statusPill.bg:SetColorTexture(0.06, 0.15, 0.22, 0.90)
                                cCard.statusPill.dsBorder:SetColor(skySel.r, skySel.g, skySel.b, 0.85)
                                cCard.statusText:SetTextColor(skySel.r, skySel.g, skySel.b, 1.0)
                                cCard.statusText:SetText("[QoL Overlap]")
                                cCard.desc:SetText(string.format("Both %s and %s can stay enabled. Choose which addon handles overlapping %s.", cleanFriendly, cleanModName, item.yieldFeature or "QoL features"))
                            end
                        elseif activeChoice == "USE_DYNAMIC" then
                            cCard.bg:SetColorTexture(0.04, 0.14, 0.09, 0.92)
                            cCard.dsBorder:SetColor(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 0.85)
                            cCard.leftBar:SetColorTexture(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 1.0)
                            cCard.statusPill.bg:SetColorTexture(0.05, 0.22, 0.14, 0.90)
                            cCard.statusPill.dsBorder:SetColor(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 0.90)
                            cCard.statusText:SetTextColor(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 1.0)
                            cCard.statusText:SetText(string.format("[%s Using %s - Reload UI]", checkTex, cleanModName))
                            cCard.desc:SetText(string.format("Resolved: %s is disabled and frozen in DynamicLoad [Never]. Click 'Reload UI Now' to apply.", cleanFriendly))
                        elseif activeChoice == "KEEP_OTHER" then
                            cCard.bg:SetColorTexture(0.04, 0.14, 0.09, 0.92)
                            cCard.dsBorder:SetColor(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 0.85)
                            cCard.leftBar:SetColorTexture(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 1.0)
                            cCard.statusPill.bg:SetColorTexture(0.05, 0.22, 0.14, 0.90)
                            cCard.statusPill.dsBorder:SetColor(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 0.90)
                            cCard.statusText:SetTextColor(UI.COLORS.EMERALD.r, UI.COLORS.EMERALD.g, UI.COLORS.EMERALD.b, 1.0)
                            cCard.statusText:SetText(string.format("[%s Using %s - Reload UI]", checkTex, shortExternal))
                            cCard.desc:SetText(string.format("Resolved: %s module is disabled and frozen in DynamicLoad [Never]. Click 'Reload UI Now' to apply.", cleanModName))
                        else
                            cCard.bg:SetColorTexture(0.14, 0.08, 0.05, 0.92)
                            cCard.dsBorder:SetColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.85)
                            cCard.leftBar:SetColorTexture(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1.0)
                            cCard.statusPill.bg:SetColorTexture(0.24, 0.14, 0.05, 0.90)
                            cCard.statusPill.dsBorder:SetColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 0.90)
                            cCard.statusText:SetTextColor(UI.COLORS.GOLD.r, UI.COLORS.GOLD.g, UI.COLORS.GOLD.b, 1.0)
                            cCard.statusText:SetText("[! Action Required]")
                            if item.conflictAddon == "SimpleAddonManager" then
                                cCard.desc:SetText("Both addons manage your AddOn list. Choose one to avoid conflicts.")
                            elseif item.conflictAddon == "FocusMarker" then
                                cCard.desc:SetText("DynamicMarker replaces FocusMarker and automatically imports your saved settings.")
                            else
                                cCard.desc:SetText(string.format("Action Required: %s and %s are both enabled (or queued). Choose one and Reload UI.", cleanFriendly, cleanModName))
                            end
                        end

                        local stW = cCard.statusText:GetStringWidth() or 120
                        cCard.statusPill:SetWidth(math.max(126, math.ceil(stW + 20)))

                        if isDecorVendor then
                            if activeChoice == nil then
                                cCard.btnUseDynamic:SetSelected(true, UI.COLORS.GOLD)
                                cCard.btnKeepOther:SetSelected(false)
                            else
                                cCard.btnUseDynamic:SetSelected(activeChoice == "USE_DYNAMIC", emeraldSel)
                                cCard.btnKeepOther:SetSelected(activeChoice == "KEEP_OTHER", emeraldSel)
                            end
                        elseif isTier2 then
                            if activeChoice == nil then
                                cCard.btnUseDynamic:SetSelected(true, emeraldSel)
                            else
                                cCard.btnUseDynamic:SetSelected(activeChoice == "PRIORITISE_DYNAMIC", emeraldSel)
                            end
                            cCard.btnKeepOther:SetSelected(activeChoice == "YIELD_TO_EXTERNAL", skySel)
                        else
                            if activeChoice == nil then
                                cCard.btnUseDynamic:SetSelected(true, UI.COLORS.GOLD)
                            else
                                cCard.btnUseDynamic:SetSelected(activeChoice == "USE_DYNAMIC", emeraldSel)
                            end
                            cCard.btnKeepOther:SetSelected(activeChoice == "KEEP_OTHER", emeraldSel)
                        end

                        cCard.btnUseDynamic:SetScript("OnClick", function()
                            local act = (isTier2 and "PRIORITISE_DYNAMIC" or "USE_DYNAMIC")
                            if isDecorVendor and addonTable.QuarantineRaidTaintAddon and not item.isSimulated then
                                addonTable.QuarantineRaidTaintAddon("DecorVendor")
                            else
                                addonTable.ResolveConflict(item.dynamicModule, item.conflictAddon, act, item.isSimulated)
                            end
                            setupView.Refresh()
                            if f.scrollChild then RefreshAddonTree(f.scrollChild) end
                            UpdateStatusBar()
                        end)
                        cCard.btnKeepOther:SetScript("OnClick", function()
                            local act = (isTier2 and "YIELD_TO_EXTERNAL" or "KEEP_OTHER")
                            addonTable.ResolveConflict(item.dynamicModule, item.conflictAddon, act, item.isSimulated)
                            setupView.Refresh()
                            if f.scrollChild then RefreshAddonTree(f.scrollChild) end
                            UpdateStatusBar()
                        end)
                        if cCard.LayoutButtons then
                            cCard:LayoutButtons()
                        end
                        cCard:Show()
                    end
                end
                for idx = #conflicts + 1, #conflictCards do
                    conflictCards[idx]:Hide()
                end
                conflictScrollChild:SetHeight(math.max(1, (#conflicts * 74) - 6))
                UpdateConflictScrollbar()
            end

            -- Populate 3 Theme Choice Cards at bottom of Step 1 (AUTO_CLASS is default per DESIGN_SYSTEM.md)
            local curAccent = gTbl.accentKey or "AUTO_CLASS"
            local tDefs = {
                {
                    title = "Auto-Match Class",
                    badge = (curAccent == "AUTO_CLASS") and "Selected (Default)" or "Click to Equip",
                    isSel = (curAccent == "AUTO_CLASS"),
                    desc = "Automatically tints borders, active tabs, and HUD accents to match whichever class you log into.",
                    onClick = function()
                        gTbl.accentKey = "AUTO_CLASS"
                        gTbl.customAccent = nil
                        addonTable.ApplySuiteThemeAndGeometry()
                        setupView.Refresh()
                    end,
                },
                {
                    title = "Obsidian Slate",
                    badge = (curAccent == "OBSIDIAN_SLATE") and "Selected (Slate)" or "Click to Equip",
                    isSel = (curAccent == "OBSIDIAN_SLATE"),
                    desc = "Signature dark tactical slate (#CBD5E1) with crisp silver highlights across all windows and HUD bars.",
                    onClick = function()
                        gTbl.accentKey = "OBSIDIAN_SLATE"
                        gTbl.customAccent = nil
                        addonTable.ApplySuiteThemeAndGeometry()
                        setupView.Refresh()
                    end,
                },
                {
                    title = "Suite Studio (Theme, Fonts & Windows)",
                    badge = (curAccent ~= "OBSIDIAN_SLATE" and curAccent ~= "AUTO_CLASS") and "Custom Active" or "Open Studio ->",
                    isSel = (curAccent ~= "OBSIDIAN_SLATE" and curAccent ~= "AUTO_CLASS"),
                    desc = "Open Suite Studio to pick from 17 swatches, custom hex colours, 26 font families, and Blizzard Desktop Window settings.",
                    onClick = function()
                        addonTable.OpenWorkspaceView("THEME_STUDIO")
                    end,
                },
            }
            for i = 1, 3 do
                local tc = themeChoiceCards[i]
                local td = tDefs[i]
                tc.title:SetText(td.title)
                tc.badge:SetText(td.badge)
                tc.desc:SetText(td.desc)
                StyleChoiceCard(tc, td.isSel)
                tc:SetScript("OnClick", td.onClick)
            end
            if themeChoiceRow:GetWidth() and themeChoiceRow:GetWidth() > 100 then
                themeChoiceRow:GetScript("OnSizeChanged")(themeChoiceRow, themeChoiceRow:GetWidth())
            end
        else
            lastGuidedStepKey = step.key
            conflictScrollFrame:SetVerticalScroll(0)
            conflictScrollFrame:Hide()
            conflictScrollTrack:Hide()
            step1Pane:Hide()
            stepModPane:Show()
            simToggleBtn:Hide()
            resolveAllBtn:Hide()
            wizOpenModBtn:ClearAllPoints()
            wizOpenModBtn:SetPoint("TOPRIGHT", wizCard, "TOPRIGHT", -16, -11)
            wizOpenModBtn:Show()
            wizHdrTitle:SetPoint("RIGHT", wizOpenModBtn, "LEFT", -10, 0)

            if step.summaryText and step.summaryText ~= "" then
                modSummaryBox:Show()
                modSummaryBox.dsBorder:SetColor(ar, ag, ab, 0.45)
                modSummaryText:SetText(step.summaryText)
                modChoiceGrid:ClearAllPoints()
                modChoiceGrid:SetPoint("TOPLEFT", modSummaryBox, "BOTTOMLEFT", 0, -12)
                modChoiceGrid:SetPoint("BOTTOMRIGHT", stepModPane, "BOTTOMRIGHT", 0, 0)
            else
                modSummaryBox:Hide()
                modChoiceGrid:ClearAllPoints()
                modChoiceGrid:SetPoint("TOPLEFT", stepModPane, "TOPLEFT", 0, 0)
                modChoiceGrid:SetPoint("BOTTOMRIGHT", stepModPane, "BOTTOMRIGHT", 0, 0)
            end

            local choices = step.choices or {}
            stepModPane.activeNumCards = #choices
            stepModPane.activeStepKey = step.key
            LayoutModChoiceGrid(#choices, step.key)
            for i, cDef in ipairs(choices) do
                local mc = modChoiceCards[i]
                if mc then
                    local isSel = cDef.isSelected and cDef.isSelected() or false
                    mc.title:SetText(cDef.title or "")
                    mc.badge:SetText(cDef.badge or "")
                    mc.desc:SetText(cDef.desc or "")
                    StyleChoiceCard(mc, isSel)
                    mc:SetScript("OnClick", function(self)
                        if cDef.onClick then cDef.onClick(self) end
                    end)
                end
            end
            if step.key == "marker" then
                if type(_G.DynamicMarker) == "table" then
                    _G.DynamicMarker._refreshSuiteSetupKeys = function()
                        RefreshMarkerFlareKeybinds()
                        local c2 = modChoiceCards[2]
                        local d2 = choices[2]
                        if c2 and d2 and d2.isSelected then
                            StyleChoiceCard(c2, d2.isSelected())
                        end
                    end
                end
                RefreshMarkerFlareKeybinds()
                markerFlareKeybindBox:Show()
            else
                markerFlareKeybindBox:Hide()
            end
        end
    end

    simToggleBtn:SetScript("OnClick", function()
        local cur = addonTable.GetSimulatedConflictPreview and addonTable.GetSimulatedConflictPreview()
        addonTable.SetSimulatedConflictPreview(not cur)
        setupView.Refresh()
    end)

    addonTable.SelectGuidedSetupStep = function(idx)
        currentGuidedIdx = idx or 1
        lastGuidedStepKey = nil
        conflictScrollFrame:SetVerticalScroll(0)
        if setupView.Refresh then
            setupView.Refresh()
        end
    end

    setupView:HookScript("OnShow", function()
        conflictScrollFrame:SetVerticalScroll(0)
        UpdateConflictScrollbar()
    end)
    setupView:HookScript("OnHide", function()
        conflictScrollFrame:SetVerticalScroll(0)
    end)
    end

    ----------------------------------------------------------------------------
    -- VIEW D: PROTOTYPE HUD EDIT MODE -- POSITIONING PALETTE & 16PX SNAP GRID
    ----------------------------------------------------------------------------
    local editView = CreateFrame("Frame", nil, workspace)
    editView:SetAllPoints()
    editView:SetFrameLevel((workspace:GetFrameLevel() or 6) + 2)
    if editView.SetClipsChildren then editView:SetClipsChildren(false) end
    editView:Hide()
    f.editView = editView

    do
    local evCard = CreateFrame("Frame", nil, editView)
    table.insert(f.themeCards, evCard)
    evCard:SetPoint("TOPLEFT", editView, "TOPLEFT", 20, -20)
    evCard:SetPoint("TOPRIGHT", editView, "TOPRIGHT", -20, -20)
    evCard:SetHeight(160)
    evCard.bg = UI.SolidTex(evCard, "BACKGROUND", 0, UI.COLORS.CARD_BG.r, UI.COLORS.CARD_BG.g, UI.COLORS.CARD_BG.b, 0.96)
    evCard.bg:SetAllPoints()
    UI.CreatePixelBorder(evCard, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.80, 2)

    local evTitle = evCard:CreateFontString(nil, "OVERLAY")
    evTitle:SetPoint("TOPLEFT", evCard, "TOPLEFT", 18, -16)
    UI.SetFont(evTitle, 14, "", UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 1)
    evTitle:SetText("EDIT MODE - POSITIONING PALETTE")

    local evDesc = evCard:CreateFontString(nil, "OVERLAY")
    evDesc:SetPoint("TOPLEFT", evTitle, "BOTTOMLEFT", 0, -8)
    evDesc:SetPoint("RIGHT", evCard, "RIGHT", -18, 0)
    evDesc:SetJustifyH("LEFT")
    evDesc:SetWordWrap(true)
    UI.SetFont(evDesc, 11, "", 0.88, 0.90, 0.94, 1)
    evDesc:SetText("Click below to hide the main window, display the full-screen alignment grid, and unlock all 4 Suite HUD bars for precision positioning.")

    local launchEditModalBtn = CreateFlatButton(evCard, 230, 30, "Launch Positioning Palette", true)
    launchEditModalBtn:SetPoint("BOTTOMLEFT", evCard, "BOTTOMLEFT", 18, 18)
    launchEditModalBtn:SetScript("OnClick", function()
        if addonTable.EnterHudEditMode then
            addonTable.EnterHudEditMode("ALL")
        end
    end)

    local selectedHudTarget = "TOAST" -- "TOAST", "PREP", "TARGET", "FLARE", "prepBuffs", "CHAT"
    local isHudEditModeActive = false
    local isExitingHudEditMode = false
    local hudTargetMeta = {
        ["TOAST"]     = { label = "Alert Toast",     header = "POSITIONING: ALERT TOAST",     owner = "DynamicLoad",   defPoint = "TOP",        defRelPoint = "TOP",        defX = 0, defY = -140 },
        ["PREP"]      = { label = "Prep Bar",        header = "POSITIONING: PREP BAR",        owner = "DynamicPrep",   defPoint = "TOP",        defRelPoint = "TOP",        defX = 0, defY = -16  },
        ["TARGET"]    = { label = "Focus Icons",     header = "POSITIONING: FOCUS ICONS",     owner = "DynamicMarker", defPoint = "CENTER",     defRelPoint = "CENTER",     defX = 0, defY = -140 },
        ["FLARE"]     = { label = "World Flare Bar", header = "POSITIONING: WORLD FLARE BAR", owner = "DynamicMarker", defPoint = "CENTER",     defRelPoint = "CENTER",     defX = 0, defY = -182 },
        ["prepBuffs"] = { label = "Prep Raid Buffs", header = "POSITIONING: PREP RAID BUFFS", owner = "DynamicPrep",   defPoint = "CENTER",     defRelPoint = "CENTER",     defX = 0, defY = 140  },
        ["CHAT"]      = { label = "Chat Frame",      header = "POSITIONING: CHAT FRAME",      owner = "DynamicChat",   defPoint = "BOTTOMLEFT", defRelPoint = "BOTTOMLEFT", defX = 0, defY = 0    },
        ["VAULT"]     = { label = "Vault Overlay",   header = "POSITIONING: VAULT OVERLAY",   owner = "DynamicVault",  defPoint = "TOP",        defRelPoint = "TOP",        defX = 0, defY = -42  },
    }
    -- 7 HUD targets for the Master HUD Edit Mode selector
    local hudTargetDefs = {
        { key = "TOAST",     label = "Alert Toast",   w = 110 },
        { key = "PREP",      label = "Prep Bar",      w = 98 },
        { key = "TARGET",    label = "Focus Icons",   w = 110 },
        { key = "FLARE",     label = "World Flares",  w = 120 },
        { key = "prepBuffs", label = "Raid Buffs",    w = 108 },
        { key = "CHAT",      label = "Chat Frame",    w = 116 },
        { key = "VAULT",     label = "Vault Overlay", w = 116 },
    }

    local snapGridOverlay = nil
    local editModeInspectorModal = nil

    local function GetActiveSnapMode()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local val = gTbl.hudSnapMode
        if val == nil then
            return "MAGNET"
        elseif val == false or val == 0 or val == "OFF" then
            return "OFF"
        elseif val == 16 or val == 32 then
            return val
        end
        return "MAGNET"
    end

    local function EnsureSnapGridOverlay()
        if snapGridOverlay then return snapGridOverlay end
        local grid = CreateFrame("Frame", "DynamicSuiteSnapGridOverlay", UIParent)
        grid:SetAllPoints(UIParent)
        grid:SetFrameStrata("BACKGROUND")
        grid:SetFrameLevel(1)
        grid:EnableMouse(false)
        grid:Hide()
        grid.minorLines = {}

        local screenW = math.ceil(GetScreenWidth() or 1920)
        local screenH = math.ceil(GetScreenHeight() or 1080)
        local halfW = math.ceil(screenW / 2)
        local halfH = math.ceil(screenH / 2)

        for x = 16, halfW, 16 do
            local alpha = (x % 64 == 0) and 0.065 or 0.025
            local vPos = UI.SolidTex(grid, "BACKGROUND", 1, 1, 1, 1, alpha)
            vPos:SetWidth(1)
            vPos:SetPoint("TOP", grid, "TOP", x, 0)
            vPos:SetPoint("BOTTOM", grid, "BOTTOM", x, 0)
            table.insert(grid.minorLines, vPos)

            local vNeg = UI.SolidTex(grid, "BACKGROUND", 1, 1, 1, 1, alpha)
            vNeg:SetWidth(1)
            vNeg:SetPoint("TOP", grid, "TOP", -x, 0)
            vNeg:SetPoint("BOTTOM", grid, "BOTTOM", -x, 0)
            table.insert(grid.minorLines, vNeg)
        end

        for y = 16, halfH, 16 do
            local alpha = (y % 64 == 0) and 0.065 or 0.025
            local hPos = UI.SolidTex(grid, "BACKGROUND", 1, 1, 1, 1, alpha)
            hPos:SetHeight(1)
            hPos:SetPoint("LEFT", grid, "LEFT", 0, y)
            hPos:SetPoint("RIGHT", grid, "RIGHT", 0, y)
            table.insert(grid.minorLines, hPos)

            local hNeg = UI.SolidTex(grid, "BACKGROUND", 1, 1, 1, 1, alpha)
            hNeg:SetHeight(1)
            hNeg:SetPoint("LEFT", grid, "LEFT", 0, -y)
            hNeg:SetPoint("RIGHT", grid, "RIGHT", 0, -y)
            table.insert(grid.minorLines, hNeg)
        end

        local ar, ag, ab = UI.GetActiveAccentColor()
        local centerV = UI.SolidTex(grid, "ARTWORK", 3, ar, ag, ab, 0.55)
        centerV:SetWidth(1.5)
        centerV:SetPoint("TOP", grid, "TOP", 0, 0)
        centerV:SetPoint("BOTTOM", grid, "BOTTOM", 0, 0)
        grid.centerV = centerV

        local centerH = UI.SolidTex(grid, "ARTWORK", 3, ar, ag, ab, 0.55)
        centerH:SetHeight(1.5)
        centerH:SetPoint("LEFT", grid, "LEFT", 0, 0)
        centerH:SetPoint("RIGHT", grid, "RIGHT", 0, 0)
        grid.centerH = centerH

        snapGridOverlay = grid
        return snapGridOverlay
    end

    local function IsChatHudTargetOwned()
        if addonTable.IsSuiteModuleExplicitlyDisabled and addonTable.IsSuiteModuleExplicitlyDisabled("DynamicChat") then
            return false
        end
        if not _G.DynamicChat then
            return false
        end
        if type(_G.DynamicChat.IsChatFrameLayoutOwned) == "function" then
            local ok, owned = pcall(_G.DynamicChat.IsChatFrameLayoutOwned, _G.DynamicChat)
            if ok then return owned == true end
        end
        if type(_G.DynamicChat.IsExternalChatEngineLoaded) == "function" then
            local ok, ext = pcall(_G.DynamicChat.IsExternalChatEngineLoaded, _G.DynamicChat)
            if ok and ext then return false end
        end
        return true
    end

    local function GetLiveHudFrame(targetKey)
        if targetKey == "TOAST" then
            if addonTable.EnsureToastFrame then
                return addonTable.EnsureToastFrame()
            elseif addonTable.CreateToastFrame then
                return addonTable.CreateToastFrame()
            end
            return _G.DynamicLoadToastFrame
        elseif targetKey == "PREP" then
            if _G.DynamicPrep then
                if not _G.DynamicPrep.db and _G.DynamicPrep.InitDB then
                    pcall(_G.DynamicPrep.InitDB, _G.DynamicPrep)
                end
                if not _G.DynamicPrepBarFrame then
                    if _G.DynamicPrep.InitBar then
                        pcall(_G.DynamicPrep.InitBar, _G.DynamicPrep)
                    elseif _G.DynamicPrep.InitOmniBar then
                        pcall(_G.DynamicPrep.InitOmniBar, _G.DynamicPrep)
                    elseif _G.DynamicPrep.CreatePrepBar then
                        pcall(_G.DynamicPrep.CreatePrepBar, _G.DynamicPrep)
                    end
                end
            end
            return _G.DynamicPrepBarFrame
        elseif targetKey == "TARGET" then
            if _G.DynamicMarker then
                if not _G.DynamicMarker.db and _G.DynamicMarker.InitDB then
                    pcall(_G.DynamicMarker.InitDB, _G.DynamicMarker)
                end
                if not _G.DynamicMarkerTargetBar and _G.DynamicMarker.InitTargetBar then
                    pcall(_G.DynamicMarker.InitTargetBar, _G.DynamicMarker)
                end
            end
            return _G.DynamicMarkerTargetBar
        elseif targetKey == "FLARE" then
            if _G.DynamicMarker then
                if not _G.DynamicMarker.db and _G.DynamicMarker.InitDB then
                    pcall(_G.DynamicMarker.InitDB, _G.DynamicMarker)
                end
                if not _G.DynamicMarkerFlareBar and _G.DynamicMarker.InitFlareBar then
                    pcall(_G.DynamicMarker.InitFlareBar, _G.DynamicMarker)
                end
            end
            return _G.DynamicMarkerFlareBar
        elseif targetKey == "prepBuffs" then
            -- Clickable Raid Buffs HUD, registered by DynamicPrep in _G.DynamicSuite.hudFrames["prepBuffs"]
            if _G.DynamicPrep and not _G.DynamicPrep.db and _G.DynamicPrep.InitDB then
                pcall(_G.DynamicPrep.InitDB, _G.DynamicPrep)
            end
            local hf = _G.DynamicSuite and _G.DynamicSuite.hudFrames and _G.DynamicSuite.hudFrames["prepBuffs"]
            if not hf and _G.DynamicPrep and not InCombatLockdown() then
                local initFn = _G.DynamicPrep.InitClickableBuffBar or _G.DynamicPrep.CreateClickableBuffBar
                if type(initFn) == "function" then
                    local ok, bar = pcall(initFn, _G.DynamicPrep)
                    hf = (ok and bar) or (_G.DynamicSuite and _G.DynamicSuite.hudFrames and _G.DynamicSuite.hudFrames["prepBuffs"])
                end
            end
            return hf or _G.DynamicPrepClickableBuffBar
        elseif targetKey == "CHAT" then
            if not IsChatHudTargetOwned() then
                return nil
            end
            return _G.ChatFrame1
        elseif targetKey == "VAULT" then
            if _G.DynamicVault and type(_G.DynamicVault.GetOverlayFrame) == "function" then
                local ok, ov = pcall(_G.DynamicVault.GetOverlayFrame, _G.DynamicVault, true)
                if ok and ov then return ov end
            end
            return _G.DynamicVaultScreenOverlay
        end
        return nil
    end

    local function EnsureAllEditModeHudFramesInitialized()
        for _, k in ipairs({ "TOAST", "PREP", "TARGET", "FLARE", "prepBuffs", "VAULT" }) do
            GetLiveHudFrame(k)
        end
        if IsChatHudTargetOwned() and _G.DynamicChat and _G.DynamicChat.ApplySavedChatFramePosition then
            pcall(_G.DynamicChat.ApplySavedChatFramePosition, _G.DynamicChat)
        end
        if _G.DynamicMarker and _G.DynamicMarker.RegisterWithSuiteHudEditMode and not _G.DynamicMarker._registeredSuiteHudCallback then
            pcall(_G.DynamicMarker.RegisterWithSuiteHudEditMode, _G.DynamicMarker)
        end
    end

    -- Read current HUD coordinates from the live frame or peer SavedVariables without moving the frame
    local function ReadPeerOrLiveHudPos(targetKey)
        if targetKey == "CHAT" then
            if not IsChatHudTargetOwned() then
                return nil
            end
            if _G.DynamicChat and _G.DynamicChat.GetLiveOuterBottomLeft then
                local ok, pt, relPt, lx, ly = pcall(_G.DynamicChat.GetLiveOuterBottomLeft, _G.DynamicChat)
                if ok and lx ~= nil and ly ~= nil then
                    return pt or "BOTTOMLEFT", relPt or "BOTTOMLEFT", math.floor(lx + 0.5), math.floor(ly + 0.5)
                end
            end
            if type(_G.DynamicChatDB) == "table" and type(_G.DynamicChatDB.chatFramePos) == "table" then
                local pos = _G.DynamicChatDB.chatFramePos
                if pos.x ~= nil and pos.y ~= nil then
                    if _G.DynamicChat and _G.DynamicChat.ClampChatFrameCoords then
                        local okC, cx, cy = pcall(_G.DynamicChat.ClampChatFrameCoords, _G.DynamicChat, pos.x, pos.y, pos.width, pos.height, pos.point or pos.relativePoint or pos.relPoint)
                        if okC and cx ~= nil and cy ~= nil then
                            return "BOTTOMLEFT", "BOTTOMLEFT", cx, cy
                        end
                    end
                    return "BOTTOMLEFT", "BOTTOMLEFT", math.max(0, math.floor(pos.x + 0.5)), math.max(0, math.floor(pos.y + 0.5))
                end
            end
            return "BOTTOMLEFT", "BOTTOMLEFT", 0, 0
        end
        local liveFrame = GetLiveHudFrame(targetKey)
        if targetKey == "TARGET" or targetKey == "FLARE" then
            if _G.DynamicMarker and _G.DynamicMarker.SyncBarScaleAndSizeToDB then
                pcall(_G.DynamicMarker.SyncBarScaleAndSizeToDB, _G.DynamicMarker, liveFrame, targetKey)
            end
            if _G.DynamicMarker and type(_G.DynamicMarker.GetCanonicalHUDPosition) == "function" then
                local okP, cPt, cRel, cx, cy = pcall(_G.DynamicMarker.GetCanonicalHUDPosition, _G.DynamicMarker, targetKey)
                if okP and cPt and cx ~= nil and cy ~= nil then
                    return cPt, cRel or "CENTER", cx, cy
                end
            end
        end
        if liveFrame and liveFrame.GetPoint and targetKey ~= "TARGET" and targetKey ~= "FLARE" then
            local pt, _, relPt, lx, ly = liveFrame:GetPoint(1)
            if pt and lx ~= nil and ly ~= nil then
                return pt, relPt or pt, math.floor(lx + 0.5), math.floor(ly + 0.5)
            end
        end
        if (targetKey == "TARGET" or targetKey == "FLARE") and type(_G.DynamicMarkerDB) == "table" then
            local db = _G.DynamicMarkerDB.global or _G.DynamicMarkerDB.profile or _G.DynamicMarkerDB
            if targetKey == "TARGET" then
                local pos = db.targetBarPos or _G.DynamicMarkerDB.targetBarPos or db.targetPos or _G.DynamicMarkerDB.targetPos
                if type(pos) == "table" and pos.x ~= nil and pos.y ~= nil then
                    local tpt, trp, tx, ty = pos.point or "CENTER", pos.relPoint or pos.point or "CENTER", math.floor(pos.x + 0.5), math.floor(pos.y + 0.5)
                    if _G.DynamicMarker and _G.DynamicMarker.ConvertAnchorToCenterLocal and (tpt ~= "CENTER" or trp ~= "CENTER") then
                        local okC, cx, cy, cPt, cRel = pcall(_G.DynamicMarker.ConvertAnchorToCenterLocal, _G.DynamicMarker, liveFrame, tpt, trp, tx, ty, "TARGET")
                        if okC and cx ~= nil and cy ~= nil then return cPt or "CENTER", cRel or "CENTER", cx, cy end
                    end
                    return tpt, trp, tx, ty
                end
                local tx = db.targetBarX or _G.DynamicMarkerDB.targetBarX or db.barX or _G.DynamicMarkerDB.barX
                local ty = db.targetBarY or _G.DynamicMarkerDB.targetBarY or db.barY or _G.DynamicMarkerDB.barY
                local tpt = db.targetBarPoint or _G.DynamicMarkerDB.targetBarPoint or db.barPoint or _G.DynamicMarkerDB.barPoint or "CENTER"
                local trp = db.targetBarRelPoint or _G.DynamicMarkerDB.targetBarRelPoint or tpt
                if tx ~= nil and ty ~= nil then
                    if _G.DynamicMarker and _G.DynamicMarker.ConvertAnchorToCenterLocal and (tpt ~= "CENTER" or trp ~= "CENTER") then
                        local okC, cx, cy, cPt, cRel = pcall(_G.DynamicMarker.ConvertAnchorToCenterLocal, _G.DynamicMarker, liveFrame, tpt, trp, tx, ty, "TARGET")
                        if okC and cx ~= nil and cy ~= nil then return cPt or "CENTER", cRel or "CENTER", cx, cy end
                    end
                    return tpt, trp, math.floor(tx + 0.5), math.floor(ty + 0.5)
                end
            else
                local pos = db.flareBarPos or _G.DynamicMarkerDB.flareBarPos or db.flarePos or _G.DynamicMarkerDB.flarePos
                if type(pos) == "table" and pos.x ~= nil and pos.y ~= nil then
                    local fpt, frp, fx, fy = pos.point or "CENTER", pos.relPoint or pos.point or "CENTER", math.floor(pos.x + 0.5), math.floor(pos.y + 0.5)
                    if _G.DynamicMarker and _G.DynamicMarker.ConvertAnchorToCenterLocal and (fpt ~= "CENTER" or frp ~= "CENTER") then
                        local okC, cx, cy, cPt, cRel = pcall(_G.DynamicMarker.ConvertAnchorToCenterLocal, _G.DynamicMarker, liveFrame, fpt, frp, fx, fy, "FLARE")
                        if okC and cx ~= nil and cy ~= nil then return cPt or "CENTER", cRel or "CENTER", cx, cy end
                    end
                    return fpt, frp, fx, fy
                end
                local fx = db.flareBarX or _G.DynamicMarkerDB.flareBarX
                local fy = db.flareBarY or _G.DynamicMarkerDB.flareBarY
                local fpt = db.flareBarPoint or _G.DynamicMarkerDB.flareBarPoint or "CENTER"
                local frp = db.flareBarRelPoint or _G.DynamicMarkerDB.flareBarRelPoint or fpt
                if fx ~= nil and fy ~= nil then
                    if _G.DynamicMarker and _G.DynamicMarker.ConvertAnchorToCenterLocal and (fpt ~= "CENTER" or frp ~= "CENTER") then
                        local okC, cx, cy, cPt, cRel = pcall(_G.DynamicMarker.ConvertAnchorToCenterLocal, _G.DynamicMarker, liveFrame, fpt, frp, fx, fy, "FLARE")
                        if okC and cx ~= nil and cy ~= nil then return cPt or "CENTER", cRel or "CENTER", cx, cy end
                    end
                    return fpt, frp, math.floor(fx + 0.5), math.floor(fy + 0.5)
                end
            end
        elseif targetKey == "PREP" and type(_G.DynamicPrepDB) == "table" then
            local db = _G.DynamicPrepDB.global or _G.DynamicPrepDB.profile or _G.DynamicPrepDB
            local pos = db.omniBarPos or _G.DynamicPrepDB.omniBarPos or db.pos or _G.DynamicPrepDB.pos
            if type(pos) == "table" and pos.x ~= nil and pos.y ~= nil then
                return pos.point or "TOP", pos.relPoint or pos.point or "TOP", math.floor(pos.x + 0.5), math.floor(pos.y + 0.5)
            end
            local px = db.barX or _G.DynamicPrepDB.barX or db.x or _G.DynamicPrepDB.x
            local py = db.barY or _G.DynamicPrepDB.barY or db.y or _G.DynamicPrepDB.y
            local ppt = db.barPoint or _G.DynamicPrepDB.barPoint or db.point or _G.DynamicPrepDB.point or "TOP"
            local prp = db.barRelPoint or _G.DynamicPrepDB.barRelPoint or ppt
            if px ~= nil and py ~= nil then
                return ppt, prp, math.floor(px + 0.5), math.floor(py + 0.5)
            end
        elseif targetKey == "prepBuffs" and _G.DynamicPrep and _G.DynamicPrep.GetSavedBuffBarPosition then
            local ok, bpt, brp, bx, by = pcall(_G.DynamicPrep.GetSavedBuffBarPosition, _G.DynamicPrep)
            if ok and bpt and bx ~= nil and by ~= nil then
                return bpt, brp or bpt, math.floor(bx + 0.5), math.floor(by + 0.5)
            end
        elseif targetKey == "VAULT" then
            local pos = _G.DynamicVaultDB and _G.DynamicVaultDB.overlayPos
            if type(pos) == "table" and #pos >= 4 then
                return pos[1] or "TOP", pos[2] or pos[1] or "TOP", math.floor((pos[3] or 0) + 0.5), math.floor((pos[4] or -42) + 0.5)
            end
        end
        return nil
    end

    local function IngestLiveHudPositions()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        gTbl.hudPositions = gTbl.hudPositions or {}
        for _, k in ipairs({ "PREP", "TARGET", "FLARE", "prepBuffs", "CHAT", "VAULT" }) do
            local pt, relPt, lx, ly = ReadPeerOrLiveHudPos(k)
            if pt and lx ~= nil and ly ~= nil then
                gTbl.hudPositions[k] = { point = pt, relPoint = relPt or pt, x = lx, y = ly }
            end
        end
    end

    local function GetStoredHudPos(targetKey)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        gTbl.hudPositions = gTbl.hudPositions or {}
        if targetKey == "TOAST" then
            local pos = gTbl.toastPos or (DynamicLoadDB and DynamicLoadDB.toastPos) or { point = "TOP", relPoint = "TOP", x = 0, y = -140 }
            return pos.point or "TOP", pos.relPoint or pos.point or "TOP", pos.x or 0, pos.y or -140
        end
        local pt, relPt, lx, ly = ReadPeerOrLiveHudPos(targetKey)
        if pt and lx ~= nil and ly ~= nil then
            return pt, relPt or pt, lx, ly
        end
        local saved = gTbl.hudPositions[targetKey]
        if saved and saved.x ~= nil and saved.y ~= nil then
            return saved.point or "TOP", saved.relPoint or "TOP", saved.x, saved.y
        end
        local meta = hudTargetMeta[targetKey] or hudTargetMeta["TOAST"]
        return meta.defPoint or "TOP", meta.defRelPoint or "TOP", meta.defX or 0, meta.defY or -100
    end

    local function PersistPeerHudPosition(targetKey, pt, relPt, rx, ry)
        if targetKey == "TARGET" or targetKey == "FLARE" then
            local function WriteMarkerTbl(tbl)
                if type(tbl) ~= "table" then return end
                if targetKey == "TARGET" then
                    tbl.targetBarPoint    = pt
                    tbl.targetBarRelPoint = relPt
                    tbl.targetBarX        = rx
                    tbl.targetBarY        = ry
                    tbl.barPoint          = pt
                    tbl.barRelPoint       = relPt
                    tbl.barX              = rx
                    tbl.barY              = ry
                    if type(tbl.targetBarPos) == "table" then
                        tbl.targetBarPos.point = pt; tbl.targetBarPos.relPoint = relPt; tbl.targetBarPos.x = rx; tbl.targetBarPos.y = ry
                    else
                        tbl.targetBarPos = { point = pt, relPoint = relPt, x = rx, y = ry }
                    end
                    if type(tbl.targetPos) == "table" then
                        tbl.targetPos.point = pt; tbl.targetPos.relPoint = relPt; tbl.targetPos.x = rx; tbl.targetPos.y = ry
                    else
                        tbl.targetPos = { point = pt, relPoint = relPt, x = rx, y = ry }
                    end
                    if type(tbl.targetBar) == "table" then
                        tbl.targetBar.point = pt; tbl.targetBar.relPoint = relPt; tbl.targetBar.x = rx; tbl.targetBar.y = ry
                    end
                else
                    tbl.flareBarPoint    = pt
                    tbl.flareBarRelPoint = relPt
                    tbl.flareBarX        = rx
                    tbl.flareBarY        = ry
                    if type(tbl.flareBarPos) == "table" then
                        tbl.flareBarPos.point = pt; tbl.flareBarPos.relPoint = relPt; tbl.flareBarPos.x = rx; tbl.flareBarPos.y = ry
                    else
                        tbl.flareBarPos = { point = pt, relPoint = relPt, x = rx, y = ry }
                    end
                    if type(tbl.flarePos) == "table" then
                        tbl.flarePos.point = pt; tbl.flarePos.relPoint = relPt; tbl.flarePos.x = rx; tbl.flarePos.y = ry
                    else
                        tbl.flarePos = { point = pt, relPoint = relPt, x = rx, y = ry }
                    end
                    if type(tbl.flareBar) == "table" then
                        tbl.flareBar.point = pt; tbl.flareBar.relPoint = relPt; tbl.flareBar.x = rx; tbl.flareBar.y = ry
                    end
                end
            end
            if type(_G.DynamicMarkerDB) == "table" then
                WriteMarkerTbl(_G.DynamicMarkerDB)
                WriteMarkerTbl(_G.DynamicMarkerDB.global)
                WriteMarkerTbl(_G.DynamicMarkerDB.profile)
                if type(_G.DynamicMarkerDB.profiles) == "table" then
                    for _, pTbl in pairs(_G.DynamicMarkerDB.profiles) do
                        WriteMarkerTbl(pTbl)
                    end
                end
                if type(_G.DynamicMarkerDB.char) == "table" then
                    for _, cTbl in pairs(_G.DynamicMarkerDB.char) do
                        WriteMarkerTbl(cTbl)
                    end
                end
            end
            if _G.DynamicMarker and _G.DynamicMarker.WriteHUDCoordsToDB then
                pcall(_G.DynamicMarker.WriteHUDCoordsToDB, _G.DynamicMarker, targetKey, pt or "CENTER", relPt or pt or "CENTER", rx, ry)
            end
        elseif targetKey == "PREP" then
            local function WritePrepTbl(tbl)
                if type(tbl) ~= "table" then return end
                tbl.barPoint    = pt
                tbl.barRelPoint = relPt
                tbl.barX        = rx
                tbl.barY        = ry
                tbl.point       = pt
                tbl.relPoint    = relPt
                tbl.x           = rx
                tbl.y           = ry
                if type(tbl.omniBarPos) == "table" then
                    tbl.omniBarPos.point = pt; tbl.omniBarPos.relPoint = relPt; tbl.omniBarPos.x = rx; tbl.omniBarPos.y = ry
                else
                    tbl.omniBarPos = { point = pt, relPoint = relPt, x = rx, y = ry }
                end
                if type(tbl.pos) == "table" then
                    tbl.pos.point = pt; tbl.pos.relPoint = relPt; tbl.pos.x = rx; tbl.pos.y = ry
                end
            end
            if type(_G.DynamicPrepDB) == "table" then
                WritePrepTbl(_G.DynamicPrepDB)
                WritePrepTbl(_G.DynamicPrepDB.global)
                WritePrepTbl(_G.DynamicPrepDB.profile)
                if type(_G.DynamicPrepDB.profiles) == "table" then
                    for _, pTbl in pairs(_G.DynamicPrepDB.profiles) do
                        WritePrepTbl(pTbl)
                    end
                end
                if type(_G.DynamicPrepDB.char) == "table" then
                    for _, cTbl in pairs(_G.DynamicPrepDB.char) do
                        WritePrepTbl(cTbl)
                    end
                end
            end
        elseif targetKey == "CHAT" then
            if not IsChatHudTargetOwned() then
                return
            end
            if _G.DynamicChat and _G.DynamicChat.SaveChatFramePosition then
                local cf = _G.ChatFrame1
                local w = (cf and cf.GetWidth and cf:GetWidth()) or 430
                local h = (cf and cf.GetHeight and cf:GetHeight()) or 200
                pcall(_G.DynamicChat.SaveChatFramePosition, _G.DynamicChat, "BOTTOMLEFT", "BOTTOMLEFT", rx, ry, w, h)
            elseif type(_G.DynamicChatDB) == "table" then
                local cf = _G.ChatFrame1
                _G.DynamicChatDB.chatFramePos = {
                    point         = "BOTTOMLEFT",
                    relativePoint = "BOTTOMLEFT",
                    relPoint      = "BOTTOMLEFT",
                    x             = math.max(0, math.floor((rx or 0) + 0.5)),
                    y             = math.max(0, math.floor((ry or 0) + 0.5)),
                    width         = (cf and cf.GetWidth and math.floor(cf:GetWidth() + 0.5)) or 430,
                    height        = (cf and cf.GetHeight and math.floor(cf:GetHeight() + 0.5)) or 200,
                }
            end
        elseif targetKey == "VAULT" then
            if _G.DynamicVault and type(_G.DynamicVault.SaveOverlayPosition) == "function" then
                pcall(_G.DynamicVault.SaveOverlayPosition, _G.DynamicVault, pt, relPt, rx, ry)
            elseif type(_G.DynamicVaultDB) == "table" then
                _G.DynamicVaultDB.overlayPos = { pt or "TOP", relPt or pt or "TOP", rx, ry }
            end
        end
    end

    local EDGE_SNAP_THRESHOLD = 11
    local BAR_SNAP_THRESHOLD  = 9

    local function GetAnchorFraction(pointStr)
        local pt = type(pointStr) == "string" and pointStr:upper() or "CENTER"
        local fx = 0.5
        local fy = 0.5
        if pt:find("LEFT", 1, true) then
            fx = 0.0
        elseif pt:find("RIGHT", 1, true) then
            fx = 1.0
        end
        if pt:find("BOTTOM", 1, true) then
            fy = 0.0
        elseif pt:find("TOP", 1, true) then
            fy = 1.0
        end
        return fx, fy
    end

    local function GetChatExtraInsetsLocal(targetKey)
        if targetKey ~= "CHAT" then
            return 0, 0, 0, 0
        end
        if _G.DynamicChat and _G.DynamicChat.GetVisibleContainerExtents then
            local ok, lEx, rEx, tEx, bEx = pcall(_G.DynamicChat.GetVisibleContainerExtents, _G.DynamicChat)
            if ok and lEx ~= nil then
                return math.max(0, tonumber(lEx) or 0),
                       math.max(0, tonumber(rEx) or 0),
                       math.max(0, tonumber(tEx) or 0),
                       math.max(0, tonumber(bEx) or 0)
            end
        end
        if _G.DynamicChat and _G.DynamicChat.GetCompositeChatInsets then
            local ok, lIn, rIn, tIn, bIn = pcall(_G.DynamicChat.GetCompositeChatInsets, _G.DynamicChat)
            if ok and lIn then
                return math.max(0, -(tonumber(lIn) or -36)),
                       math.max(0, tonumber(rIn) or 8),
                       math.max(0, tonumber(tIn) or 28),
                       math.max(0, -(tonumber(bIn) or -6))
            end
        end
        return 36, 8, 28, 6
    end

    local function EnsureSnapGuideOverlay()
        local ov = _G.DynamicSuiteSnapGuideOverlay
        if not ov then
            ov = CreateFrame("Frame", "DynamicSuiteSnapGuideOverlay", UIParent)
            ov:SetAllPoints(UIParent)
            ov:SetFrameStrata("FULLSCREEN_DIALOG")
            ov:SetFrameLevel(200)
            ov:EnableMouse(false)

            local vLine = ov:CreateTexture(nil, "OVERLAY")
            if vLine.SetSnapToPixelGrid then vLine:SetSnapToPixelGrid(false) end
            if vLine.SetTexelSnappingBias then vLine:SetTexelSnappingBias(0) end
            vLine:Hide()
            ov.vLine = vLine

            local hLine = ov:CreateTexture(nil, "OVERLAY")
            if hLine.SetSnapToPixelGrid then hLine:SetSnapToPixelGrid(false) end
            if hLine.SetTexelSnappingBias then hLine:SetTexelSnappingBias(0) end
            hLine:Hide()
            ov.hLine = hLine

            ov.HideGuides = function()
                if ov.vLine then ov.vLine:Hide() end
                if ov.hLine then ov.hLine:Hide() end
            end

            ov.ShowGuides = function(gx, gy, r, g, b)
                local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
                local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
                local cr, cg, cb = r or 0.22, g or 0.74, b or 0.97
                if gx ~= nil then
                    ov.vLine:ClearAllPoints()
                    ov.vLine:SetColorTexture(cr, cg, cb, 0.85)
                    if gx <= 1 then
                        ov.vLine:SetWidth(2)
                        ov.vLine:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
                        ov.vLine:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
                    elseif gx >= screenW - 1 then
                        ov.vLine:SetWidth(2)
                        ov.vLine:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
                        ov.vLine:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
                    else
                        ov.vLine:SetWidth(1.5)
                        ov.vLine:SetPoint("TOP", UIParent, "BOTTOMLEFT", gx, screenH)
                        ov.vLine:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", gx, 0)
                    end
                    ov.vLine:Show()
                else
                    ov.vLine:Hide()
                end

                if gy ~= nil then
                    ov.hLine:ClearAllPoints()
                    ov.hLine:SetColorTexture(cr, cg, cb, 0.85)
                    if gy <= 1 then
                        ov.hLine:SetHeight(2)
                        ov.hLine:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
                        ov.hLine:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
                    elseif gy >= screenH - 1 then
                        ov.hLine:SetHeight(2)
                        ov.hLine:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
                        ov.hLine:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
                    else
                        ov.hLine:SetHeight(1.5)
                        ov.hLine:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, gy)
                        ov.hLine:SetPoint("RIGHT", UIParent, "BOTTOMLEFT", screenW, gy)
                    end
                    ov.hLine:Show()
                else
                    ov.hLine:Hide()
                end
            end
        end
        return ov
    end

    local function HideSnapGuides()
        local ov = _G.DynamicSuiteSnapGuideOverlay
        if ov and ov.HideGuides then
            ov.HideGuides()
        end
    end

    local function UpdateSnapGuides(gx, gy)
        if gx == nil and gy == nil then
            HideSnapGuides()
            return
        end
        local ov = EnsureSnapGuideOverlay()
        local ar, ag, ab = UI.GetActiveAccentColor()
        ov.ShowGuides(gx, gy, ar, ag, ab)
    end

    local function ResolveExistingHudFrame(targetKey)
        if targetKey == "TOAST" then
            return _G.DynamicLoadToastFrame
        elseif targetKey == "PREP" then
            return _G.DynamicPrepBarFrame
        elseif targetKey == "TARGET" then
            return _G.DynamicMarkerTargetBar
        elseif targetKey == "FLARE" then
            return _G.DynamicMarkerFlareBar
        elseif targetKey == "prepBuffs" then
            return (_G.DynamicSuite and _G.DynamicSuite.hudFrames and _G.DynamicSuite.hudFrames["prepBuffs"]) or _G.DynamicPrepClickableBuffBar
        elseif targetKey == "CHAT" then
            if not IsChatHudTargetOwned() then return nil end
            return _G.ChatFrame1
        elseif targetKey == "VAULT" then
            return _G.DynamicVaultScreenOverlay
        end
        return nil
    end

    local function CollectAllActiveHudFrames()
        local out = {}
        local seen = {}
        for _, hDef in ipairs(hudTargetDefs) do
            if hDef.key ~= "ALL" then
                local f = ResolveExistingHudFrame(hDef.key)
                if f and not seen[f] and f.IsShown and f:IsShown() then
                    seen[f] = true
                    table.insert(out, f)
                end
            end
        end
        if _G.DynamicSuite and type(_G.DynamicSuite.hudElements) == "table" then
            for _, entry in pairs(_G.DynamicSuite.hudElements) do
                if type(entry) == "table" and entry.frame and not seen[entry.frame] and entry.frame.IsShown and entry.frame:IsShown() then
                    seen[entry.frame] = true
                    table.insert(out, entry.frame)
                end
            end
        end
        return out
    end

    local function CollectPeerHudBoundsUIParent(excludeFrame, uScale)
        local bounds = {}
        local seen = {}
        if excludeFrame then seen[excludeFrame] = true end
        local function AddFrame(f, keyHint)
            if not f or seen[f] then return end
            seen[f] = true
            if not (f.IsShown and f:IsShown()) then return end
            if not (f.GetCenter and f.GetWidth and f.GetHeight) then return end
            local oFScale = (f.GetEffectiveScale and f:GetEffectiveScale()) or uScale
            if oFScale <= 0 then oFScale = uScale end
            local oRelScale = oFScale / uScale
            local oW = (f:GetWidth() or 0) * oRelScale
            local oH = (f:GetHeight() or 0) * oRelScale
            if oW <= 1 or oH <= 1 then return end
            local oCxLocal, oCyLocal = f:GetCenter()
            if not oCxLocal or not oCyLocal then return end
            local oCx = oCxLocal * oRelScale
            local oCy = oCyLocal * oRelScale
            local lEx, rEx, tEx, bEx = GetChatExtraInsetsLocal(keyHint)
            table.insert(bounds, {
                left   = oCx - (oW / 2) - (lEx * oRelScale),
                right  = oCx + (oW / 2) + (rEx * oRelScale),
                bottom = oCy - (oH / 2) - (bEx * oRelScale),
                top    = oCy + (oH / 2) + (tEx * oRelScale),
                cx     = oCx,
                cy     = oCy,
            })
        end
        for _, hDef in ipairs(hudTargetDefs) do
            if hDef.key ~= "ALL" then
                AddFrame(ResolveExistingHudFrame(hDef.key), hDef.key)
            end
        end
        if _G.DynamicSuite and type(_G.DynamicSuite.hudElements) == "table" then
            for _, entry in pairs(_G.DynamicSuite.hudElements) do
                if type(entry) == "table" and entry.frame then
                    AddFrame(entry.frame, nil)
                end
            end
        end
        return bounds
    end

    -- Helper: returns UIParent dimensions and frame size in hudFrame's own local coordinate space.
    -- In WoW's C++ layout engine, frame:SetPoint(pt, UIParent, relPt, xOfs, yOfs) interprets (xOfs, yOfs)
    -- in frame's own scaled local coordinate space (UIParent offset = xOfs * (frameScale / uiParentScale)).
    local function GetHudLocalScreenExtents(hudFrame, targetKey)
        local isMarkerHud = (targetKey == "TARGET" or targetKey == "FLARE")
        if isMarkerHud and _G.DynamicMarker and _G.DynamicMarker.SyncBarScaleAndSizeToDB then
            pcall(_G.DynamicMarker.SyncBarScaleAndSizeToDB, _G.DynamicMarker, hudFrame, targetKey)
        end
        local uScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        if uScale <= 0 then uScale = 1 end

        local relScale
        if isMarkerHud then
            relScale = (hudFrame and hudFrame.GetScale and hudFrame:GetScale()) or nil
            if not relScale or relScale <= 0 then
                local g = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
                if g and type(g.hudScales) == "table" and tonumber(g.hudScales[targetKey]) then
                    relScale = tonumber(g.hudScales[targetKey])
                elseif _G.DynamicMarker and _G.DynamicMarker.db and type(_G.DynamicMarker.db) == "table" then
                    local dmDb = _G.DynamicMarker.db
                    relScale = tonumber((targetKey == "TARGET") and (dmDb.targetBarScale or dmDb.barScale) or dmDb.flareBarScale)
                elseif type(_G.DynamicMarkerDB) == "table" then
                    relScale = tonumber((targetKey == "TARGET") and (_G.DynamicMarkerDB.targetBarScale or _G.DynamicMarkerDB.barScale) or _G.DynamicMarkerDB.flareBarScale)
                end
            end
            if not relScale or relScale <= 0 then relScale = 1 end
        else
            local rawFScale = (hudFrame and hudFrame.GetEffectiveScale and hudFrame:GetEffectiveScale()) or uScale
            if rawFScale <= 0 then rawFScale = uScale end
            relScale = rawFScale / uScale
            if relScale <= 0 then relScale = 1 end
        end

        local fScale = uScale * relScale
        local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
        local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
        local uiW_local = screenW / relScale
        local uiH_local = screenH / relScale
        local frameW = (hudFrame and hudFrame.GetWidth and hudFrame:GetWidth()) or 0
        local frameH = (hudFrame and hudFrame.GetHeight and hudFrame:GetHeight()) or 0
        if isMarkerHud then
            if frameW <= 1 or frameH <= 1 then
                local dmDb = (_G.DynamicMarker and _G.DynamicMarker.db) or _G.DynamicMarkerDB
                local oriVal = (type(dmDb) == "table") and ((targetKey == "FLARE") and (dmDb.flareBarOrientation or dmDb.flareOrientation) or (dmDb.targetBarOrientation or dmDb.orientation)) or nil
                local isVert = (oriVal == "VERTICAL")
                frameW = isVert and 40 or 292
                frameH = isVert and 292 or 40
            end
        else
            if frameW <= 0 then frameW = 160 end
            if frameH <= 0 then frameH = 40 end
        end
        return uiW_local, uiH_local, fScale, uScale, relScale, frameW, frameH
    end

    -- Unified Screen-Edge/Center & Bar-to-Bar Magnetic Snapping + Hard Screen-Boundary Clamping
    local function ClampHudCoordsToScreen(hudFrame, targetKey, usePt, useRelPt, rawX, rawY, enableSnap)
        if (targetKey == "TARGET" or targetKey == "FLARE") and _G.DynamicMarker and _G.DynamicMarker.SyncBarScaleAndSizeToDB then
            pcall(_G.DynamicMarker.SyncBarScaleAndSizeToDB, _G.DynamicMarker, hudFrame, targetKey)
        end
        local inPt = usePt or ((targetKey == "TARGET" or targetKey == "FLARE" or targetKey == "prepBuffs") and "CENTER" or ((targetKey == "CHAT") and "BOTTOMLEFT" or "TOP"))
        local inRelPt = useRelPt or inPt
        local _, _, _, uScale, relScale, frameW, frameH = GetHudLocalScreenExtents(hudFrame, targetKey)
        local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
        local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
        local screenCx = screenW / 2
        local screenCy = screenH / 2

        local visW = (frameW or 0) * relScale
        local visH = (frameH or 0) * relScale
        local halfW = math.max(0, visW / 2)
        local halfH = math.max(0, visH / 2)
        local lEx, rEx, tEx, bEx = GetChatExtraInsetsLocal(targetKey)
        local leftExtraVis   = lEx * relScale
        local rightExtraVis  = rEx * relScale
        local topExtraVis    = tEx * relScale
        local bottomExtraVis = bEx * relScale

        local inX = tonumber(rawX) or 0
        local inY = tonumber(rawY) or 0
        local isMarkerCanonical = (targetKey == "TARGET" or targetKey == "FLARE")
        local coordScale = isMarkerCanonical and 1.0 or relScale
        local candCx, candCy
        if targetKey == "CHAT" and (inPt == "BOTTOMLEFT" or inRelPt == "BOTTOMLEFT") then
            candCx = (inX * relScale) + leftExtraVis + halfW
            candCy = (inY * relScale) + bottomExtraVis + halfH
        else
            local inPfx, inPfy = GetAnchorFraction(inPt)
            local inRfx, inRfy = GetAnchorFraction(inRelPt)
            local refX = inRfx * screenW
            local refY = inRfy * screenH
            local anchorVisX = refX + (inX * coordScale)
            local anchorVisY = refY + (inY * coordScale)
            candCx = anchorVisX + (0.5 - inPfx) * visW
            candCy = anchorVisY + (0.5 - inPfy) * visH
        end

        local cleanPt, cleanRelPt
        if targetKey == "TARGET" or targetKey == "FLARE" then
            cleanPt, cleanRelPt = "CENTER", "CENTER"
        elseif targetKey == "CHAT" then
            cleanPt, cleanRelPt = "BOTTOMLEFT", "BOTTOMLEFT"
        else
            cleanPt, cleanRelPt = inPt, inRelPt
        end

        local guideX, guideY = nil, nil
        local snapMode = GetActiveSnapMode()
        local bypassSnap = (IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown())
        if enableSnap and not bypassSnap then
            if snapMode == "MAGNET" or snapMode == nil then
                local candL = candCx - halfW - leftExtraVis
                local candR = candCx + halfW + rightExtraVis
                local candB = candCy - halfH - bottomExtraVis
                local candT = candCy + halfH + topExtraVis

                local bestDeltaX, bestGX = nil, nil
                local bestDeltaY, bestGY = nil, nil

                local function ConsiderX(delta, gLine, limit)
                    if math.abs(delta) <= limit then
                        if bestDeltaX == nil or math.abs(delta) < math.abs(bestDeltaX) then
                            bestDeltaX = delta
                            bestGX = gLine
                        end
                    end
                end
                local function ConsiderY(delta, gLine, limit)
                    if math.abs(delta) <= limit then
                        if bestDeltaY == nil or math.abs(delta) < math.abs(bestDeltaY) then
                            bestDeltaY = delta
                            bestGY = gLine
                        end
                    end
                end

                -- Screen-edge & center magnetic snapping (~11px in UIParent coordinates)
                ConsiderX(0 - candL, 0, EDGE_SNAP_THRESHOLD)
                ConsiderX(screenW - candR, screenW, EDGE_SNAP_THRESHOLD)
                ConsiderX(screenCx - candCx, screenCx, EDGE_SNAP_THRESHOLD)

                ConsiderY(0 - candB, 0, EDGE_SNAP_THRESHOLD)
                ConsiderY(screenH - candT, screenH, EDGE_SNAP_THRESHOLD)
                ConsiderY(screenCy - candCy, screenCy, EDGE_SNAP_THRESHOLD)

                -- Bar-to-bar flush stacking & flush alignment across all visible HUDs (~9px)
                local peers = CollectPeerHudBoundsUIParent(hudFrame, uScale)
                for _, peer in ipairs(peers) do
                    ConsiderX(peer.right - candL, peer.right, BAR_SNAP_THRESHOLD)
                    ConsiderX(peer.left - candR, peer.left, BAR_SNAP_THRESHOLD)
                    ConsiderX(peer.left - candL, peer.left, BAR_SNAP_THRESHOLD)
                    ConsiderX(peer.right - candR, peer.right, BAR_SNAP_THRESHOLD)
                    ConsiderX(peer.cx - candCx, peer.cx, BAR_SNAP_THRESHOLD)

                    ConsiderY(peer.bottom - candT, peer.bottom, BAR_SNAP_THRESHOLD)
                    ConsiderY(peer.top - candB, peer.top, BAR_SNAP_THRESHOLD)
                    ConsiderY(peer.top - candT, peer.top, BAR_SNAP_THRESHOLD)
                    ConsiderY(peer.bottom - candB, peer.bottom, BAR_SNAP_THRESHOLD)
                    ConsiderY(peer.cy - candCy, peer.cy, BAR_SNAP_THRESHOLD)
                end

                if bestDeltaX ~= nil then
                    candCx = candCx + bestDeltaX
                    guideX = bestGX
                end
                if bestDeltaY ~= nil then
                    candCy = candCy + bestDeltaY
                    guideY = bestGY
                end
            elseif snapMode == 16 or snapMode == 32 then
                local step = snapMode * relScale
                if math.abs(candCx - screenCx) <= EDGE_SNAP_THRESHOLD then
                    candCx = screenCx
                    guideX = screenCx
                elseif step > 0 then
                    candCx = screenCx + math.floor(((candCx - screenCx) / step) + 0.5) * step
                end
                if math.abs(candCy - screenCy) <= EDGE_SNAP_THRESHOLD then
                    candCy = screenCy
                    guideY = screenCy
                elseif step > 0 then
                    candCy = screenCy + math.floor(((candCy - screenCy) / step) + 0.5) * step
                end
            end
        end

        -- Hard screen-boundary clamping ALWAYS takes final precedence
        local minCx = halfW + leftExtraVis
        local maxCx = screenW - halfW - rightExtraVis
        local minCy = halfH + bottomExtraVis
        local maxCy = screenH - halfH - topExtraVis

        if minCx > maxCx then
            candCx = screenCx
        else
            if candCx < minCx then
                candCx = minCx
                if guideX ~= nil and guideX ~= 0 then guideX = nil end
            elseif candCx > maxCx then
                candCx = maxCx
                if guideX ~= nil and guideX ~= screenW then guideX = nil end
            end
        end

        if minCy > maxCy then
            candCy = screenCy
        else
            if candCy < minCy then
                candCy = minCy
                if guideY ~= nil and guideY ~= 0 then guideY = nil end
            elseif candCy > maxCy then
                candCy = maxCy
                if guideY ~= nil and guideY ~= screenH then guideY = nil end
            end
        end

        local outX, outY
        if targetKey == "CHAT" then
            local rawOutX = (candCx - halfW - leftExtraVis) / relScale
            local rawOutY = (candCy - halfH - bottomExtraVis) / relScale
            outX = math.floor(rawOutX + 0.5)
            outY = math.floor(rawOutY + 0.5)
            local maxLocalX = math.max(0, (maxCx - minCx) / relScale)
            local maxLocalY = math.max(0, (maxCy - minCy) / relScale)
            outX = math.max(0, math.min(math.floor(maxLocalX + 1e-6), outX))
            outY = math.max(0, math.min(math.floor(maxLocalY + 1e-6), outY))
        else
            local pfx, pfy = GetAnchorFraction(cleanPt)
            local rfx, rfy = GetAnchorFraction(cleanRelPt)
            local outRefX = rfx * screenW
            local outRefY = rfy * screenH
            local rawOutX = ((candCx - (0.5 - pfx) * visW) - outRefX) / coordScale
            local rawOutY = ((candCy - (0.5 - pfy) * visH) - outRefY) / coordScale
            outX = math.floor(rawOutX + 0.5)
            outY = math.floor(rawOutY + 0.5)

            local minLocalX = ((minCx - (0.5 - pfx) * visW) - outRefX) / coordScale
            local maxLocalX = ((maxCx - (0.5 - pfx) * visW) - outRefX) / coordScale
            local minLocalY = ((minCy - (0.5 - pfy) * visH) - outRefY) / coordScale
            local maxLocalY = ((maxCy - (0.5 - pfy) * visH) - outRefY) / coordScale

            if minLocalX <= maxLocalX then
                local loX = math.ceil(minLocalX - 1e-6)
                local hiX = math.floor(maxLocalX + 1e-6)
                if loX <= hiX then
                    outX = math.max(loX, math.min(hiX, outX))
                end
            else
                outX = math.floor((((screenCx - (0.5 - pfx) * visW) - outRefX) / coordScale) + 0.5)
            end

            if minLocalY <= maxLocalY then
                local loY = math.ceil(minLocalY - 1e-6)
                local hiY = math.floor(maxLocalY + 1e-6)
                if loY <= hiY then
                    outY = math.max(loY, math.min(hiY, outY))
                end
            else
                outY = math.floor((((screenCy - (0.5 - pfy) * visH) - outRefY) / coordScale) + 0.5)
            end
        end

        return cleanPt, cleanRelPt, outX, outY, guideX, guideY
    end

    local function SetStoredHudPos(targetKey, pt, relPt, x, y)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local cleanPt = pt or "TOP"
        local cleanRelPt = relPt or cleanPt
        local liveFrame = GetLiveHudFrame(targetKey)
        local rx, ry
        cleanPt, cleanRelPt, rx, ry = ClampHudCoordsToScreen(liveFrame, targetKey, cleanPt, cleanRelPt, x or 0, y or 0, false)
        if targetKey == "TOAST" then
            if addonTable.SetToastPresetPosition then
                addonTable.SetToastPresetPosition(cleanPt, cleanRelPt, rx, ry)
            end
            return
        end
        gTbl.hudPositions = gTbl.hudPositions or {}
        local posEntry = { point = cleanPt, relPoint = cleanRelPt, x = rx, y = ry, xOfs = rx, yOfs = ry }
        gTbl.hudPositions[targetKey] = posEntry
        if targetKey == "TARGET" then
            gTbl.hudPositions["TargetBar"] = posEntry
            gTbl.hudPositions["target"] = posEntry
            gTbl.hudPositions["DynamicMarkerTargetBar"] = posEntry
        elseif targetKey == "FLARE" then
            gTbl.hudPositions["FlareBar"] = posEntry
            gTbl.hudPositions["flare"] = posEntry
            gTbl.hudPositions["DynamicMarkerFlareBar"] = posEntry
        elseif targetKey == "PREP" then
            gTbl.hudPositions["PrepBar"] = posEntry
            gTbl.hudPositions["prep"] = posEntry
            gTbl.hudPositions["DynamicPrepBarFrame"] = posEntry
        elseif targetKey == "CHAT" then
            gTbl.hudPositions["ChatFrame"] = posEntry
            gTbl.hudPositions["chat"] = posEntry
            gTbl.hudPositions["ChatFrame1"] = posEntry
        end
        PersistPeerHudPosition(targetKey, cleanPt, cleanRelPt, rx, ry)

        if liveFrame and targetKey ~= "CHAT" and not InCombatLockdown() then
            if targetKey == "TARGET" or targetKey == "FLARE" then
                if _G.DynamicMarker and type(_G.DynamicMarker.SetBarCenterPoint) == "function" then
                    pcall(_G.DynamicMarker.SetBarCenterPoint, _G.DynamicMarker, liveFrame, rx, ry, targetKey)
                elseif liveFrame.ClearAllPoints and liveFrame.SetPoint then
                    local s = (liveFrame.GetScale and liveFrame:GetScale()) or 1.0
                    if s <= 0 then s = 1.0 end
                    if liveFrame.SetClampRectInsets then liveFrame:SetClampRectInsets(0, 0, 0, 0) end
                    liveFrame:ClearAllPoints()
                    liveFrame:SetPoint(cleanPt, UIParent, cleanRelPt, rx / s, ry / s)
                    if liveFrame.SetClampedToScreen then liveFrame:SetClampedToScreen(true) end
                end
            elseif liveFrame.ClearAllPoints and liveFrame.SetPoint then
                liveFrame:ClearAllPoints()
                liveFrame:SetPoint(cleanPt, UIParent, cleanRelPt, rx, ry)
            end
            if liveFrame.SaveEditPosition then
                liveFrame._dmSuppressSuiteNotify = true
                if _G.DynamicMarker then _G.DynamicMarker._suppressSuiteNotify = true end
                pcall(liveFrame.SaveEditPosition, liveFrame, cleanPt, cleanRelPt, rx, ry, true)
                if _G.DynamicMarker then _G.DynamicMarker._suppressSuiteNotify = nil end
                liveFrame._dmSuppressSuiteNotify = nil
            end
            if liveFrame.editMover and liveFrame.editMover.RefreshMoverVisual then
                pcall(liveFrame.editMover.RefreshMoverVisual, liveFrame.editMover)
            end
        elseif targetKey == "CHAT" and _G.DynamicChat and _G.DynamicChat._dsDragShield and _G.DynamicChat._dsDragShield.UpdateOverlay then
            local _, _, liveX, liveY = ReadPeerOrLiveHudPos("CHAT")
            _G.DynamicChat._dsDragShield:UpdateOverlay(liveX or rx, liveY or ry, selectedHudTarget == "CHAT" or selectedHudTarget == "ALL")
        end
    end

    -- Read the frame's current live anchor & offset in canonical coordinate space
    local function GetLiveHudLocalOffset(hudFrame, targetKey)
        if targetKey == "CHAT" then
            local pt, relPt, lx, ly = ReadPeerOrLiveHudPos("CHAT")
            if pt and lx ~= nil and ly ~= nil then
                return pt, relPt or "BOTTOMLEFT", lx, ly
            end
            return "BOTTOMLEFT", "BOTTOMLEFT", 0, 0
        end
        local prevPt, prevRelPt, storedX, storedY = GetStoredHudPos(targetKey)
        local usePt = (prevPt == "CENTER" or targetKey == "TARGET" or targetKey == "FLARE" or targetKey == "prepBuffs") and "CENTER" or "TOP"
        local useRelPt = (usePt == "CENTER") and "CENTER" or "TOP"
        if not hudFrame then
            return usePt, useRelPt, math.floor((storedX or 0) + 0.5), math.floor((storedY or 0) + 0.5)
        end
        local uiW_local, uiH_local, _, _, relScale = GetHudLocalScreenExtents(hudFrame, targetKey)
        local fCx, fCy = hudFrame:GetCenter()
        if not fCx or not fCy then
            return usePt, useRelPt, math.floor((storedX or 0) + 0.5), math.floor((storedY or 0) + 0.5)
        end
        if targetKey == "TARGET" or targetKey == "FLARE" then
            local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
            local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
            local curX = (fCx * relScale) - (screenW * 0.5)
            local curY = (fCy * relScale) - (screenH * 0.5)
            return "CENTER", "CENTER", math.floor(curX + 0.5), math.floor(curY + 0.5)
        end
        local curX = fCx - (uiW_local / 2)
        local curY
        if usePt == "CENTER" then
            curY = fCy - (uiH_local / 2)
        else
            local fTop = (hudFrame.GetTop and hudFrame:GetTop()) or fCy
            curY = fTop - uiH_local
        end
        return usePt, useRelPt, math.floor(curX + 0.5), math.floor(curY + 0.5)
    end

    -- Apply Screen-Edge/Center & Bar-to-Bar Magnetic Snapping + Hard Screen-Boundary Clamping
    local function ComputeSnappedAndClampedHudCoords(hudFrame, targetKey, rawX, rawY, usePt, useRelPt, enableSnap)
        return ClampHudCoordsToScreen(hudFrame, targetKey, usePt, useRelPt, rawX, rawY, enableSnap ~= false)
    end

    local function ComputeDraggedHudCoords(hudFrame, targetKey)
        local usePt, useRelPt, curX, curY = GetLiveHudLocalOffset(hudFrame, targetKey)
        return ClampHudCoordsToScreen(hudFrame, targetKey, usePt, useRelPt, curX, curY, true)
    end

    local HUD_SCALE_MIN, HUD_SCALE_MAX, HUD_SCALE_STEP = 0.60, 1.50, 0.05

    local function GetHudScale(targetKey)
        local key = (targetKey == "ALL" or not targetKey) and "TOAST" or targetKey
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local raw = 1.0
        if key == "TOAST" then
            raw = gTbl.toastScale or (DynamicLoadDB and DynamicLoadDB.toastScale) or (_G.DynamicLoadToastFrame and _G.DynamicLoadToastFrame.GetScale and _G.DynamicLoadToastFrame:GetScale()) or 1.0
        elseif key == "PREP" then
            raw = (_G.DynamicPrep and _G.DynamicPrep.db and (_G.DynamicPrep.db.barScale or _G.DynamicPrep.db.scale))
                or (_G.DynamicPrepDB and ((_G.DynamicPrepDB.global and _G.DynamicPrepDB.global.barScale) or (_G.DynamicPrepDB.profile and _G.DynamicPrepDB.profile.barScale) or _G.DynamicPrepDB.barScale or _G.DynamicPrepDB.scale))
                or (_G.DynamicPrepBarFrame and _G.DynamicPrepBarFrame.GetScale and _G.DynamicPrepBarFrame:GetScale())
                or (gTbl.hudScales and gTbl.hudScales["PREP"])
                or 1.0
        elseif key == "TARGET" then
            raw = (_G.DynamicMarker and _G.DynamicMarker.db and (_G.DynamicMarker.db.targetBarScale or _G.DynamicMarker.db.barScale))
                or (_G.DynamicMarkerDB and ((_G.DynamicMarkerDB.global and _G.DynamicMarkerDB.global.targetBarScale) or (_G.DynamicMarkerDB.profile and _G.DynamicMarkerDB.profile.targetBarScale) or _G.DynamicMarkerDB.targetBarScale or _G.DynamicMarkerDB.barScale))
                or (_G.DynamicMarkerTargetBar and _G.DynamicMarkerTargetBar.GetScale and _G.DynamicMarkerTargetBar:GetScale())
                or (gTbl.hudScales and gTbl.hudScales["TARGET"])
                or 1.0
        elseif key == "FLARE" then
            raw = (_G.DynamicMarker and _G.DynamicMarker.db and _G.DynamicMarker.db.flareBarScale)
                or (_G.DynamicMarkerDB and ((_G.DynamicMarkerDB.global and _G.DynamicMarkerDB.global.flareBarScale) or (_G.DynamicMarkerDB.profile and _G.DynamicMarkerDB.profile.flareBarScale) or _G.DynamicMarkerDB.flareBarScale))
                or (_G.DynamicMarkerFlareBar and _G.DynamicMarkerFlareBar.GetScale and _G.DynamicMarkerFlareBar:GetScale())
                or (gTbl.hudScales and gTbl.hudScales["FLARE"])
                or 1.0
        elseif key == "prepBuffs" then
            raw = (_G.DynamicPrep and _G.DynamicPrep.db and _G.DynamicPrep.db.raidBuffs and _G.DynamicPrep.db.raidBuffs.hudScale)
                or (gTbl.hudScales and gTbl.hudScales["prepBuffs"])
                or (GetLiveHudFrame("prepBuffs") and GetLiveHudFrame("prepBuffs"):GetScale())
                or 1.0
        elseif key == "CHAT" then
            raw = (_G.DynamicChatDB and _G.DynamicChatDB.chatFrameScale)
                or (gTbl.hudScales and gTbl.hudScales["CHAT"])
                or (_G.ChatFrame1 and _G.ChatFrame1.GetScale and _G.ChatFrame1:GetScale())
                or 1.0
        elseif key == "VAULT" then
            raw = (_G.DynamicVaultDB and _G.DynamicVaultDB.overlayScale)
                or (gTbl.hudScales and gTbl.hudScales["VAULT"])
                or (_G.DynamicVaultScreenOverlay and _G.DynamicVaultScreenOverlay.GetScale and _G.DynamicVaultScreenOverlay:GetScale())
                or 1.0
        end
        local snapped = math.floor((tonumber(raw) or 1.0) * 20 + 0.5) / 20
        return math.max(HUD_SCALE_MIN, math.min(HUD_SCALE_MAX, snapped))
    end

    local function SetHudScale(targetKey, val)
        local snapped = math.floor((tonumber(val) or 1.0) * 20 + 0.5) / 20
        snapped = math.max(HUD_SCALE_MIN, math.min(HUD_SCALE_MAX, snapped))
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        gTbl.hudScales = gTbl.hudScales or {}

        local targets = (targetKey == "ALL") and { "TOAST", "PREP", "TARGET", "FLARE", "prepBuffs" } or { targetKey or "TOAST" }
        for _, k in ipairs(targets) do
            gTbl.hudScales[k] = snapped
            if k == "TOAST" then
                gTbl.toastScale = snapped
                if DynamicLoadDB then DynamicLoadDB.toastScale = snapped end
                if _G.DynamicLoadToastFrame and _G.DynamicLoadToastFrame.SetScale and not InCombatLockdown() then
                    _G.DynamicLoadToastFrame:SetScale(snapped)
                end
                if addonTable.ApplyToastVisuals then
                    pcall(addonTable.ApplyToastVisuals)
                end
            elseif k == "PREP" then
                if type(_G.DynamicPrepDB) == "table" then
                    _G.DynamicPrepDB.barScale = snapped
                    _G.DynamicPrepDB.scale = snapped
                    if type(_G.DynamicPrepDB.global) == "table" then _G.DynamicPrepDB.global.barScale = snapped; _G.DynamicPrepDB.global.scale = snapped end
                    if type(_G.DynamicPrepDB.profile) == "table" then _G.DynamicPrepDB.profile.barScale = snapped; _G.DynamicPrepDB.profile.scale = snapped end
                end
                if _G.DynamicPrep and type(_G.DynamicPrep.db) == "table" then
                    _G.DynamicPrep.db.barScale = snapped
                    _G.DynamicPrep.db.scale = snapped
                end
                local lf = GetLiveHudFrame("PREP")
                if lf and lf.SetScale and not InCombatLockdown() then lf:SetScale(snapped) end
                if _G.DynamicPrep and _G.DynamicPrep.ApplyBarGeometry then
                    pcall(_G.DynamicPrep.ApplyBarGeometry, _G.DynamicPrep)
                end
            elseif k == "TARGET" then
                if type(_G.DynamicMarkerDB) == "table" then
                    _G.DynamicMarkerDB.targetBarScale = snapped
                    _G.DynamicMarkerDB.barScale = snapped
                    if type(_G.DynamicMarkerDB.global) == "table" then _G.DynamicMarkerDB.global.targetBarScale = snapped; _G.DynamicMarkerDB.global.barScale = snapped end
                    if type(_G.DynamicMarkerDB.profile) == "table" then _G.DynamicMarkerDB.profile.targetBarScale = snapped; _G.DynamicMarkerDB.profile.barScale = snapped end
                end
                if _G.DynamicMarker and type(_G.DynamicMarker.db) == "table" then
                    _G.DynamicMarker.db.targetBarScale = snapped
                    _G.DynamicMarker.db.barScale = snapped
                end
                local lf = GetLiveHudFrame("TARGET")
                if lf and lf.SetScale and not InCombatLockdown() then lf:SetScale(snapped) end
                if _G.DynamicMarker and _G.DynamicMarker.RefreshTargetBar then
                    pcall(_G.DynamicMarker.RefreshTargetBar, _G.DynamicMarker)
                end
            elseif k == "FLARE" then
                if type(_G.DynamicMarkerDB) == "table" then
                    _G.DynamicMarkerDB.flareBarScale = snapped
                    if type(_G.DynamicMarkerDB.global) == "table" then _G.DynamicMarkerDB.global.flareBarScale = snapped end
                    if type(_G.DynamicMarkerDB.profile) == "table" then _G.DynamicMarkerDB.profile.flareBarScale = snapped end
                end
                if _G.DynamicMarker and type(_G.DynamicMarker.db) == "table" then
                    _G.DynamicMarker.db.flareBarScale = snapped
                end
                local lf = GetLiveHudFrame("FLARE")
                if lf and lf.SetScale and not InCombatLockdown() then lf:SetScale(snapped) end
                if _G.DynamicMarker and _G.DynamicMarker.RefreshFlareBar then
                    pcall(_G.DynamicMarker.RefreshFlareBar, _G.DynamicMarker)
                end
            elseif k == "prepBuffs" then
                if _G.DynamicPrep and type(_G.DynamicPrep.db) == "table" and type(_G.DynamicPrep.db.raidBuffs) == "table" then
                    _G.DynamicPrep.db.raidBuffs.hudScale = snapped
                end
                local lf = GetLiveHudFrame("prepBuffs")
                if lf and lf.SetScale and not InCombatLockdown() then lf:SetScale(snapped) end
            elseif k == "CHAT" then
                if type(_G.DynamicChatDB) == "table" then
                    _G.DynamicChatDB.chatFrameScale = snapped
                end
                local lf = GetLiveHudFrame("CHAT")
                if lf and lf.SetScale and not InCombatLockdown() then lf:SetScale(snapped) end
                if _G.DynamicChat and _G.DynamicChat.ApplySleekChatSkin then
                    pcall(_G.DynamicChat.ApplySleekChatSkin, _G.DynamicChat)
                end
            elseif k == "VAULT" then
                if type(_G.DynamicVaultDB) == "table" then
                    _G.DynamicVaultDB.overlayScale = snapped
                end
                local lf = GetLiveHudFrame("VAULT")
                if lf and lf.SetScale and not InCombatLockdown() then lf:SetScale(snapped) end
                if _G.DynamicVault and _G.DynamicVault.RefreshOverlays then
                    pcall(_G.DynamicVault.RefreshOverlays, _G.DynamicVault)
                end
            end

            if not InCombatLockdown() then
                local sPt, sRelPt, sX, sY = GetStoredHudPos(k)
                SetStoredHudPos(k, sPt, sRelPt, sX, sY)
            end

            local liveHud = GetLiveHudFrame(k)
            if liveHud and liveHud._dsDragShield and liveHud._dsDragShield.UpdateOverlay then
                local _, _, cx, cy = GetStoredHudPos(k)
                local isSel = (selectedHudTarget == k or selectedHudTarget == "ALL")
                liveHud._dsDragShield:UpdateOverlay(cx, cy, isSel)
            elseif liveHud and liveHud.editMover and liveHud.editMover.RefreshMoverVisual then
                pcall(liveHud.editMover.RefreshMoverVisual, liveHud.editMover)
            end
        end
    end

    local HUD_OPACITY_MIN, HUD_OPACITY_MAX, HUD_OPACITY_STEP = 0.20, 1.00, 0.05

    local function GetDefaultHudOpacity(targetKey)
        return (targetKey == "CHAT") and 0.25 or 0.95
    end

    local function SnapHudOpacity(val, targetKey)
        local num = tonumber(val)
        if not num then num = GetDefaultHudOpacity(targetKey) end
        local snapped = math.floor(num * 20 + 0.5) / 20
        return math.max(HUD_OPACITY_MIN, math.min(HUD_OPACITY_MAX, snapped))
    end

    local function NormalizeHudBorderStyle(style, forToast)
        local s = type(style) == "string" and style:upper() or "ACCENT"
        if s == "SUBTLE" or s == "DARK" then
            return forToast and "SUBTLE" or "DARK"
        elseif s == "NONE" then
            return "NONE"
        end
        return "ACCENT"
    end

    local function DoesHudSupportOrientation(targetKey)
        return (targetKey == "TARGET" or targetKey == "FLARE" or targetKey == "prepBuffs")
    end

    local function GetHudOpacity(targetKey)
        local key = (targetKey == "ALL" or not targetKey) and "TOAST" or targetKey
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local raw = nil
        if key == "TOAST" then
            raw = gTbl.toastOpacity or gTbl.toastAlpha or (DynamicLoadDB and (DynamicLoadDB.toastOpacity or DynamicLoadDB.toastAlpha))
        elseif key == "PREP" then
            raw = (_G.DynamicPrep and _G.DynamicPrep.db and _G.DynamicPrep.db.barOpacity)
                or (_G.DynamicPrepDB and ((_G.DynamicPrepDB.global and _G.DynamicPrepDB.global.barOpacity) or (_G.DynamicPrepDB.profile and _G.DynamicPrepDB.profile.barOpacity) or _G.DynamicPrepDB.barOpacity))
                or (gTbl.hudOpacities and gTbl.hudOpacities["PREP"])
        elseif key == "prepBuffs" then
            raw = (_G.DynamicPrep and _G.DynamicPrep.db and _G.DynamicPrep.db.raidBuffs and _G.DynamicPrep.db.raidBuffs.hudOpacity)
                or (gTbl.hudOpacities and gTbl.hudOpacities["prepBuffs"])
        elseif key == "TARGET" then
            raw = (_G.DynamicMarker and _G.DynamicMarker.db and _G.DynamicMarker.db.targetBarOpacity)
                or (_G.DynamicMarkerDB and ((_G.DynamicMarkerDB.global and _G.DynamicMarkerDB.global.targetBarOpacity) or (_G.DynamicMarkerDB.profile and _G.DynamicMarkerDB.profile.targetBarOpacity) or _G.DynamicMarkerDB.targetBarOpacity))
                or (gTbl.hudOpacities and gTbl.hudOpacities["TARGET"])
        elseif key == "FLARE" then
            raw = (_G.DynamicMarker and _G.DynamicMarker.db and _G.DynamicMarker.db.flareBarOpacity)
                or (_G.DynamicMarkerDB and ((_G.DynamicMarkerDB.global and _G.DynamicMarkerDB.global.flareBarOpacity) or (_G.DynamicMarkerDB.profile and _G.DynamicMarkerDB.profile.flareBarOpacity) or _G.DynamicMarkerDB.flareBarOpacity))
                or (gTbl.hudOpacities and gTbl.hudOpacities["FLARE"])
        elseif key == "CHAT" then
            raw = (_G.DynamicChat and _G.DynamicChat.db and _G.DynamicChat.db.chatBgAlpha)
                or (_G.DynamicChatDB and _G.DynamicChatDB.chatBgAlpha)
                or (gTbl.hudOpacities and gTbl.hudOpacities["CHAT"])
        elseif key == "VAULT" then
            raw = (_G.DynamicVaultDB and _G.DynamicVaultDB.overlayOpacity)
                or (gTbl.hudOpacities and gTbl.hudOpacities["VAULT"])
        end
        return SnapHudOpacity(raw, key)
    end

    local function SetHudOpacity(targetKey, val)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        gTbl.hudOpacities = gTbl.hudOpacities or {}
        local targets = (targetKey == "ALL") and { "TOAST", "PREP", "TARGET", "FLARE", "prepBuffs" } or { targetKey or "TOAST" }
        for _, k in ipairs(targets) do
            local snapped = SnapHudOpacity(val, k)
            gTbl.hudOpacities[k] = snapped
            if k == "TOAST" then
                gTbl.toastOpacity = snapped
                gTbl.toastAlpha = snapped
                if DynamicLoadDB then
                    DynamicLoadDB.toastOpacity = snapped
                    DynamicLoadDB.toastAlpha = snapped
                end
                if _G.DynamicSuiteDB and _G.DynamicSuiteDB.global then
                    _G.DynamicSuiteDB.global.toastOpacity = snapped
                    _G.DynamicSuiteDB.global.toastAlpha = snapped
                end
                if addonTable.ApplyToastVisuals then
                    pcall(addonTable.ApplyToastVisuals)
                end
                if _G.DynamicGroup and _G.DynamicGroup.UpdateTeleportToast then
                    pcall(_G.DynamicGroup.UpdateTeleportToast, _G.DynamicGroup, false)
                end
                if f.toastConfigPanel and f.toastConfigPanel.RefreshControls then
                    pcall(f.toastConfigPanel.RefreshControls)
                end
                if isHudEditModeActive and _G.DynamicLoadToastFrame then
                    local isVis = addonTable.IsHudTargetShown and addonTable.IsHudTargetShown("TOAST")
                    local visAlpha = isVis and snapped or math.min(snapped, 0.65)
                    _G.DynamicLoadToastFrame:SetAlpha(visAlpha)
                    if _G.DynamicLoadToastFrame._dsDragShield and _G.DynamicLoadToastFrame._dsDragShield.SetIgnoreParentAlpha then
                        _G.DynamicLoadToastFrame._dsDragShield:SetIgnoreParentAlpha(true)
                    end
                end
            elseif k == "PREP" then
                if type(_G.DynamicPrepDB) == "table" then
                    _G.DynamicPrepDB.barOpacity = snapped
                    if type(_G.DynamicPrepDB.global) == "table" then _G.DynamicPrepDB.global.barOpacity = snapped end
                    if type(_G.DynamicPrepDB.profile) == "table" then _G.DynamicPrepDB.profile.barOpacity = snapped end
                end
                if _G.DynamicPrep and type(_G.DynamicPrep.db) == "table" then
                    _G.DynamicPrep.db.barOpacity = snapped
                end
                if _G.DynamicPrep and _G.DynamicPrep.ApplyBarGeometry then
                    pcall(_G.DynamicPrep.ApplyBarGeometry, _G.DynamicPrep)
                end
                local lf = GetLiveHudFrame("PREP")
                if isHudEditModeActive and lf and lf.SetAlpha then
                    local isVis = addonTable.IsHudTargetShown and addonTable.IsHudTargetShown("PREP")
                    lf:SetAlpha(isVis and snapped or math.min(snapped, 0.60))
                end
            elseif k == "prepBuffs" then
                if _G.DynamicPrep and type(_G.DynamicPrep.db) == "table" then
                    _G.DynamicPrep.db.raidBuffs = _G.DynamicPrep.db.raidBuffs or {}
                    _G.DynamicPrep.db.raidBuffs.hudOpacity = snapped
                end
                if type(_G.DynamicPrepDB) == "table" then
                    _G.DynamicPrepDB.raidBuffs = _G.DynamicPrepDB.raidBuffs or {}
                    _G.DynamicPrepDB.raidBuffs.hudOpacity = snapped
                    if type(_G.DynamicPrepDB.global) == "table" then
                        _G.DynamicPrepDB.global.raidBuffs = _G.DynamicPrepDB.global.raidBuffs or {}
                        _G.DynamicPrepDB.global.raidBuffs.hudOpacity = snapped
                    end
                    if type(_G.DynamicPrepDB.profile) == "table" then
                        _G.DynamicPrepDB.profile.raidBuffs = _G.DynamicPrepDB.profile.raidBuffs or {}
                        _G.DynamicPrepDB.profile.raidBuffs.hudOpacity = snapped
                    end
                end
                if _G.DynamicPrep and _G.DynamicPrep.RefreshClickableBuffs then
                    pcall(_G.DynamicPrep.RefreshClickableBuffs, _G.DynamicPrep, true)
                end
                local lf = GetLiveHudFrame("prepBuffs")
                if isHudEditModeActive and lf and lf.SetAlpha then
                    local isVis = addonTable.IsHudTargetShown and addonTable.IsHudTargetShown("prepBuffs")
                    lf:SetAlpha(isVis and snapped or math.min(snapped, 0.60))
                end
            elseif k == "TARGET" then
                if type(_G.DynamicMarkerDB) == "table" then
                    _G.DynamicMarkerDB.targetBarOpacity = snapped
                    if type(_G.DynamicMarkerDB.global) == "table" then _G.DynamicMarkerDB.global.targetBarOpacity = snapped end
                    if type(_G.DynamicMarkerDB.profile) == "table" then _G.DynamicMarkerDB.profile.targetBarOpacity = snapped end
                end
                if _G.DynamicMarker and type(_G.DynamicMarker.db) == "table" then
                    _G.DynamicMarker.db.targetBarOpacity = snapped
                end
                if _G.DynamicMarker and _G.DynamicMarker.RefreshTargetBar then
                    pcall(_G.DynamicMarker.RefreshTargetBar, _G.DynamicMarker)
                end
                if isHudEditModeActive and _G.DynamicMarker and _G.DynamicMarker.SyncEditBarStates then
                    pcall(_G.DynamicMarker.SyncEditBarStates, _G.DynamicMarker)
                end
            elseif k == "FLARE" then
                if type(_G.DynamicMarkerDB) == "table" then
                    _G.DynamicMarkerDB.flareBarOpacity = snapped
                    if type(_G.DynamicMarkerDB.global) == "table" then _G.DynamicMarkerDB.global.flareBarOpacity = snapped end
                    if type(_G.DynamicMarkerDB.profile) == "table" then _G.DynamicMarkerDB.profile.flareBarOpacity = snapped end
                end
                if _G.DynamicMarker and type(_G.DynamicMarker.db) == "table" then
                    _G.DynamicMarker.db.flareBarOpacity = snapped
                end
                if _G.DynamicMarker and _G.DynamicMarker.RefreshFlareBar then
                    pcall(_G.DynamicMarker.RefreshFlareBar, _G.DynamicMarker)
                end
                if isHudEditModeActive and _G.DynamicMarker and _G.DynamicMarker.SyncEditBarStates then
                    pcall(_G.DynamicMarker.SyncEditBarStates, _G.DynamicMarker)
                end
            elseif k == "CHAT" then
                if type(_G.DynamicChatDB) == "table" then
                    _G.DynamicChatDB.chatBgAlpha = snapped
                end
                if _G.DynamicChat and type(_G.DynamicChat.db) == "table" then
                    _G.DynamicChat.db.chatBgAlpha = snapped
                end
                if _G.DynamicChat and _G.DynamicChat.ApplySleekChatSkin then
                    pcall(_G.DynamicChat.ApplySleekChatSkin, _G.DynamicChat)
                end
                if _G.ChatFrame1 and _G.ChatFrame1.SetAlpha then
                    _G.ChatFrame1:SetAlpha(1.0)
                end
            elseif k == "VAULT" then
                if type(_G.DynamicVaultDB) == "table" then
                    _G.DynamicVaultDB.overlayOpacity = snapped
                end
                if _G.DynamicVault and _G.DynamicVault.RefreshOverlays then
                    pcall(_G.DynamicVault.RefreshOverlays, _G.DynamicVault)
                end
            end

            local liveHud = GetLiveHudFrame(k)
            if liveHud and liveHud._dsDragShield then
                if liveHud._dsDragShield.SetIgnoreParentAlpha then
                    liveHud._dsDragShield:SetIgnoreParentAlpha(true)
                end
                if liveHud._dsDragShield.UpdateOverlay then
                    local _, _, cx, cy = GetStoredHudPos(k)
                    local isSel = (selectedHudTarget == k or selectedHudTarget == "ALL")
                    liveHud._dsDragShield:UpdateOverlay(cx, cy, isSel)
                end
            elseif liveHud and liveHud.editMover and liveHud.editMover.RefreshMoverVisual then
                pcall(liveHud.editMover.RefreshMoverVisual, liveHud.editMover)
            end
        end
    end

    local function GetHudBorderStyle(targetKey)
        local key = (targetKey == "ALL" or not targetKey) and "TOAST" or targetKey
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        local raw = nil
        if key == "TOAST" then
            raw = gTbl.toastBorderStyle or (DynamicLoadDB and DynamicLoadDB.toastBorderStyle)
        elseif key == "PREP" then
            raw = (_G.DynamicPrep and _G.DynamicPrep.db and _G.DynamicPrep.db.hudBorderStyle)
                or (_G.DynamicPrepDB and ((_G.DynamicPrepDB.global and _G.DynamicPrepDB.global.hudBorderStyle) or (_G.DynamicPrepDB.profile and _G.DynamicPrepDB.profile.hudBorderStyle) or _G.DynamicPrepDB.hudBorderStyle))
                or (gTbl.hudBorderStyles and gTbl.hudBorderStyles["PREP"])
        elseif key == "prepBuffs" then
            raw = (_G.DynamicPrep and _G.DynamicPrep.db and _G.DynamicPrep.db.raidBuffs and _G.DynamicPrep.db.raidBuffs.hudBorderStyle)
                or (gTbl.hudBorderStyles and gTbl.hudBorderStyles["prepBuffs"])
        elseif key == "TARGET" then
            raw = (_G.DynamicMarker and _G.DynamicMarker.db and (_G.DynamicMarker.db.targetBarBorderStyle or _G.DynamicMarker.db.hudBorderStyle))
                or (_G.DynamicMarkerDB and ((_G.DynamicMarkerDB.global and (_G.DynamicMarkerDB.global.targetBarBorderStyle or _G.DynamicMarkerDB.global.hudBorderStyle)) or (_G.DynamicMarkerDB.profile and (_G.DynamicMarkerDB.profile.targetBarBorderStyle or _G.DynamicMarkerDB.profile.hudBorderStyle)) or _G.DynamicMarkerDB.targetBarBorderStyle or _G.DynamicMarkerDB.hudBorderStyle))
                or (gTbl.hudBorderStyles and gTbl.hudBorderStyles["TARGET"])
        elseif key == "FLARE" then
            raw = (_G.DynamicMarker and _G.DynamicMarker.db and (_G.DynamicMarker.db.flareBarBorderStyle or _G.DynamicMarker.db.hudBorderStyle))
                or (_G.DynamicMarkerDB and ((_G.DynamicMarkerDB.global and (_G.DynamicMarkerDB.global.flareBarBorderStyle or _G.DynamicMarkerDB.global.hudBorderStyle)) or (_G.DynamicMarkerDB.profile and (_G.DynamicMarkerDB.profile.flareBarBorderStyle or _G.DynamicMarkerDB.profile.hudBorderStyle)) or _G.DynamicMarkerDB.flareBarBorderStyle or _G.DynamicMarkerDB.hudBorderStyle))
                or (gTbl.hudBorderStyles and gTbl.hudBorderStyles["FLARE"])
        elseif key == "CHAT" then
            raw = (_G.DynamicChat and _G.DynamicChat.db and _G.DynamicChat.db.chatBorderStyle)
                or (_G.DynamicChatDB and _G.DynamicChatDB.chatBorderStyle)
                or (gTbl.hudBorderStyles and gTbl.hudBorderStyles["CHAT"])
        elseif key == "VAULT" then
            raw = (_G.DynamicVaultDB and _G.DynamicVaultDB.overlayBorderStyle)
                or (gTbl.hudBorderStyles and gTbl.hudBorderStyles["VAULT"])
        end
        return NormalizeHudBorderStyle(raw, false)
    end

    local function SetHudBorderStyle(targetKey, style)
        local norm = NormalizeHudBorderStyle(style, false)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        gTbl.hudBorderStyles = gTbl.hudBorderStyles or {}
        local targets = (targetKey == "ALL") and { "TOAST", "PREP", "TARGET", "FLARE", "prepBuffs" } or { targetKey or "TOAST" }
        for _, k in ipairs(targets) do
            gTbl.hudBorderStyles[k] = norm
            if k == "TOAST" then
                local toastVal = NormalizeHudBorderStyle(norm, true)
                gTbl.toastBorderStyle = toastVal
                if DynamicLoadDB then DynamicLoadDB.toastBorderStyle = toastVal end
                if _G.DynamicSuiteDB and _G.DynamicSuiteDB.global then
                    _G.DynamicSuiteDB.global.toastBorderStyle = toastVal
                end
                if addonTable.ApplyToastVisuals then
                    pcall(addonTable.ApplyToastVisuals)
                end
                if _G.DynamicGroup and _G.DynamicGroup.UpdateTeleportToast then
                    pcall(_G.DynamicGroup.UpdateTeleportToast, _G.DynamicGroup, false)
                end
                if f.toastConfigPanel and f.toastConfigPanel.RefreshControls then
                    pcall(f.toastConfigPanel.RefreshControls)
                end
            elseif k == "PREP" then
                if type(_G.DynamicPrepDB) == "table" then
                    _G.DynamicPrepDB.hudBorderStyle = norm
                    if type(_G.DynamicPrepDB.global) == "table" then _G.DynamicPrepDB.global.hudBorderStyle = norm end
                    if type(_G.DynamicPrepDB.profile) == "table" then _G.DynamicPrepDB.profile.hudBorderStyle = norm end
                end
                if _G.DynamicPrep and type(_G.DynamicPrep.db) == "table" then
                    _G.DynamicPrep.db.hudBorderStyle = norm
                end
                if _G.DynamicPrep and _G.DynamicPrep.ApplyBarBorderStyle then
                    pcall(_G.DynamicPrep.ApplyBarBorderStyle, _G.DynamicPrep)
                elseif _G.DynamicPrep and _G.DynamicPrep.ApplyBarGeometry then
                    pcall(_G.DynamicPrep.ApplyBarGeometry, _G.DynamicPrep)
                end
            elseif k == "prepBuffs" then
                if _G.DynamicPrep and type(_G.DynamicPrep.db) == "table" then
                    _G.DynamicPrep.db.raidBuffs = _G.DynamicPrep.db.raidBuffs or {}
                    _G.DynamicPrep.db.raidBuffs.hudBorderStyle = norm
                end
                if type(_G.DynamicPrepDB) == "table" then
                    _G.DynamicPrepDB.raidBuffs = _G.DynamicPrepDB.raidBuffs or {}
                    _G.DynamicPrepDB.raidBuffs.hudBorderStyle = norm
                    if type(_G.DynamicPrepDB.global) == "table" then
                        _G.DynamicPrepDB.global.raidBuffs = _G.DynamicPrepDB.global.raidBuffs or {}
                        _G.DynamicPrepDB.global.raidBuffs.hudBorderStyle = norm
                    end
                    if type(_G.DynamicPrepDB.profile) == "table" then
                        _G.DynamicPrepDB.profile.raidBuffs = _G.DynamicPrepDB.profile.raidBuffs or {}
                        _G.DynamicPrepDB.profile.raidBuffs.hudBorderStyle = norm
                    end
                end
                if _G.DynamicPrep and _G.DynamicPrep.RefreshClickableBuffs then
                    pcall(_G.DynamicPrep.RefreshClickableBuffs, _G.DynamicPrep, true)
                end
            elseif k == "TARGET" then
                if type(_G.DynamicMarkerDB) == "table" then
                    _G.DynamicMarkerDB.targetBarBorderStyle = norm
                    _G.DynamicMarkerDB.hudBorderStyle = norm
                    if type(_G.DynamicMarkerDB.global) == "table" then
                        _G.DynamicMarkerDB.global.targetBarBorderStyle = norm
                        _G.DynamicMarkerDB.global.hudBorderStyle = norm
                    end
                    if type(_G.DynamicMarkerDB.profile) == "table" then
                        _G.DynamicMarkerDB.profile.targetBarBorderStyle = norm
                        _G.DynamicMarkerDB.profile.hudBorderStyle = norm
                    end
                end
                if _G.DynamicMarker and type(_G.DynamicMarker.db) == "table" then
                    _G.DynamicMarker.db.targetBarBorderStyle = norm
                    _G.DynamicMarker.db.hudBorderStyle = norm
                end
                if _G.DynamicMarker and _G.DynamicMarker.RefreshTargetBar then
                    pcall(_G.DynamicMarker.RefreshTargetBar, _G.DynamicMarker)
                end
            elseif k == "FLARE" then
                if type(_G.DynamicMarkerDB) == "table" then
                    _G.DynamicMarkerDB.flareBarBorderStyle = norm
                    _G.DynamicMarkerDB.hudBorderStyle = norm
                    if type(_G.DynamicMarkerDB.global) == "table" then
                        _G.DynamicMarkerDB.global.flareBarBorderStyle = norm
                        _G.DynamicMarkerDB.global.hudBorderStyle = norm
                    end
                    if type(_G.DynamicMarkerDB.profile) == "table" then
                        _G.DynamicMarkerDB.profile.flareBarBorderStyle = norm
                        _G.DynamicMarkerDB.profile.hudBorderStyle = norm
                    end
                end
                if _G.DynamicMarker and type(_G.DynamicMarker.db) == "table" then
                    _G.DynamicMarker.db.flareBarBorderStyle = norm
                    _G.DynamicMarker.db.hudBorderStyle = norm
                end
                if _G.DynamicMarker and _G.DynamicMarker.RefreshFlareBar then
                    pcall(_G.DynamicMarker.RefreshFlareBar, _G.DynamicMarker)
                end
            elseif k == "CHAT" then
                if type(_G.DynamicChatDB) == "table" then
                    _G.DynamicChatDB.chatBorderStyle = norm
                end
                if _G.DynamicChat and type(_G.DynamicChat.db) == "table" then
                    _G.DynamicChat.db.chatBorderStyle = norm
                end
                if _G.DynamicChat and _G.DynamicChat.ApplySleekChatSkin then
                    pcall(_G.DynamicChat.ApplySleekChatSkin, _G.DynamicChat)
                end
            elseif k == "VAULT" then
                if type(_G.DynamicVaultDB) == "table" then
                    _G.DynamicVaultDB.overlayBorderStyle = norm
                end
                if _G.DynamicVault and _G.DynamicVault.RefreshOverlays then
                    pcall(_G.DynamicVault.RefreshOverlays, _G.DynamicVault)
                end
            end

            local liveHud = GetLiveHudFrame(k)
            if liveHud and liveHud._dsDragShield and liveHud._dsDragShield.UpdateOverlay then
                local _, _, cx, cy = GetStoredHudPos(k)
                local isSel = (selectedHudTarget == k or selectedHudTarget == "ALL")
                liveHud._dsDragShield:UpdateOverlay(cx, cy, isSel)
            elseif liveHud and liveHud.editMover and liveHud.editMover.RefreshMoverVisual then
                pcall(liveHud.editMover.RefreshMoverVisual, liveHud.editMover)
            end
        end
    end

    local function GetHudOrientation(targetKey)
        local key = (targetKey == "ALL" or not targetKey) and "TOAST" or targetKey
        if not DoesHudSupportOrientation(key) then
            return "HORIZONTAL"
        end
        local raw = nil
        if key == "TARGET" then
            raw = (_G.DynamicMarker and _G.DynamicMarker.db and (_G.DynamicMarker.db.targetBarOrientation or _G.DynamicMarker.db.orientation))
                or (_G.DynamicMarkerDB and ((_G.DynamicMarkerDB.global and (_G.DynamicMarkerDB.global.targetBarOrientation or _G.DynamicMarkerDB.global.orientation)) or (_G.DynamicMarkerDB.profile and (_G.DynamicMarkerDB.profile.targetBarOrientation or _G.DynamicMarkerDB.profile.orientation)) or _G.DynamicMarkerDB.targetBarOrientation or _G.DynamicMarkerDB.orientation))
        elseif key == "FLARE" then
            raw = (_G.DynamicMarker and _G.DynamicMarker.db and (_G.DynamicMarker.db.flareBarOrientation or _G.DynamicMarker.db.flareOrientation))
                or (_G.DynamicMarkerDB and ((_G.DynamicMarkerDB.global and (_G.DynamicMarkerDB.global.flareBarOrientation or _G.DynamicMarkerDB.global.flareOrientation)) or (_G.DynamicMarkerDB.profile and (_G.DynamicMarkerDB.profile.flareBarOrientation or _G.DynamicMarkerDB.profile.flareOrientation)) or _G.DynamicMarkerDB.flareBarOrientation or _G.DynamicMarkerDB.flareOrientation))
        elseif key == "prepBuffs" then
            raw = _G.DynamicPrep and _G.DynamicPrep.db and _G.DynamicPrep.db.raidBuffs and _G.DynamicPrep.db.raidBuffs.orientation
        end
        return (type(raw) == "string" and raw:upper() == "VERTICAL") and "VERTICAL" or "HORIZONTAL"
    end

    local function SetHudOrientation(targetKey, orient)
        local val = (type(orient) == "string" and orient:upper() == "VERTICAL") and "VERTICAL" or "HORIZONTAL"
        if not DoesHudSupportOrientation(targetKey) then
            return
        end
        if targetKey == "TARGET" then
            if type(_G.DynamicMarkerDB) == "table" then
                _G.DynamicMarkerDB.targetBarOrientation = val
                _G.DynamicMarkerDB.orientation = val
                if type(_G.DynamicMarkerDB.global) == "table" then
                    _G.DynamicMarkerDB.global.targetBarOrientation = val
                    _G.DynamicMarkerDB.global.orientation = val
                end
                if type(_G.DynamicMarkerDB.profile) == "table" then
                    _G.DynamicMarkerDB.profile.targetBarOrientation = val
                    _G.DynamicMarkerDB.profile.orientation = val
                end
            end
            if _G.DynamicMarker and type(_G.DynamicMarker.db) == "table" then
                _G.DynamicMarker.db.targetBarOrientation = val
                _G.DynamicMarker.db.orientation = val
            end
            if _G.DynamicMarker and _G.DynamicMarker.RefreshTargetBar then
                pcall(_G.DynamicMarker.RefreshTargetBar, _G.DynamicMarker)
            end
        elseif targetKey == "FLARE" then
            if type(_G.DynamicMarkerDB) == "table" then
                _G.DynamicMarkerDB.flareBarOrientation = val
                _G.DynamicMarkerDB.flareOrientation = val
                if type(_G.DynamicMarkerDB.global) == "table" then
                    _G.DynamicMarkerDB.global.flareBarOrientation = val
                    _G.DynamicMarkerDB.global.flareOrientation = val
                end
                if type(_G.DynamicMarkerDB.profile) == "table" then
                    _G.DynamicMarkerDB.profile.flareBarOrientation = val
                    _G.DynamicMarkerDB.profile.flareOrientation = val
                end
            end
            if _G.DynamicMarker and type(_G.DynamicMarker.db) == "table" then
                _G.DynamicMarker.db.flareBarOrientation = val
                _G.DynamicMarker.db.flareOrientation = val
            end
            if _G.DynamicMarker and _G.DynamicMarker.RefreshFlareBar then
                pcall(_G.DynamicMarker.RefreshFlareBar, _G.DynamicMarker)
            end
        elseif targetKey == "prepBuffs" then
            if _G.DynamicPrep and type(_G.DynamicPrep.db) == "table" then
                _G.DynamicPrep.db.raidBuffs = _G.DynamicPrep.db.raidBuffs or {}
                _G.DynamicPrep.db.raidBuffs.orientation = val
            end
            if _G.DynamicPrep and _G.DynamicPrep.RefreshClickableBuffs then
                pcall(_G.DynamicPrep.RefreshClickableBuffs, _G.DynamicPrep, true)
            end
        end

        if not InCombatLockdown() then
            local sPt, sRelPt, sX, sY = GetStoredHudPos(targetKey)
            SetStoredHudPos(targetKey, sPt, sRelPt, sX, sY)
        end

        local liveHud = GetLiveHudFrame(targetKey)
        if liveHud and liveHud._dsDragShield and liveHud._dsDragShield.UpdateOverlay then
            local _, _, cx, cy = GetStoredHudPos(targetKey)
            local isSel = (selectedHudTarget == targetKey or selectedHudTarget == "ALL")
            liveHud._dsDragShield:UpdateOverlay(cx, cy, isSel)
        elseif liveHud and liveHud.editMover and liveHud.editMover.RefreshMoverVisual then
            pcall(liveHud.editMover.RefreshMoverVisual, liveHud.editMover)
        end
        if isHudEditModeActive and (targetKey == "TARGET" or targetKey == "FLARE") and _G.DynamicMarker and _G.DynamicMarker.SyncEditBarStates then
            pcall(_G.DynamicMarker.SyncEditBarStates, _G.DynamicMarker)
        end
    end

    local SyncAllEditModeHuds

    local explicitlyPreviewedHiddenHud = nil

    local function IsHudParentModuleActive(targetKey)
        if targetKey == "CHAT" then
            return IsChatHudTargetOwned()
        end
        local meta = hudTargetMeta[targetKey]
        local owner = meta and meta.owner
        if targetKey == "TOAST" then
            local loadDisabled = addonTable.IsSuiteModuleExplicitlyDisabled and addonTable.IsSuiteModuleExplicitlyDisabled("DynamicLoad")
            local grpDisabled = addonTable.IsSuiteModuleExplicitlyDisabled and addonTable.IsSuiteModuleExplicitlyDisabled("DynamicGroup")
            return not (loadDisabled and grpDisabled)
        end
        if owner and addonTable.IsSuiteModuleExplicitlyDisabled and addonTable.IsSuiteModuleExplicitlyDisabled(owner) then
            return false
        end
        if owner and not _G[owner] then
            return false
        end
        return true
    end

    local function GetHudVisibility(targetKey)
        if targetKey == "ALL" or not targetKey then
            return GetHudVisibility("TOAST") or GetHudVisibility("PREP") or GetHudVisibility("TARGET") or GetHudVisibility("FLARE")
        end
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        if targetKey == "TOAST" then
            if gTbl.toastEnabled ~= nil then
                return gTbl.toastEnabled == true
            end
            if DynamicLoadDB and DynamicLoadDB.toastEnabled ~= nil then
                return DynamicLoadDB.toastEnabled == true
            end
            local tMode = (DynamicLoadDB and DynamicLoadDB.toastMode) or gTbl.toastMode
            if tMode ~= nil then
                return tMode ~= "OFF"
            end
            local dMode = (DynamicLoadDB and DynamicLoadDB.toastDisplayMode) or gTbl.toastDisplayMode
            return dMode ~= "OFF"
        elseif targetKey == "PREP" then
            local dm = (_G.DynamicPrep and _G.DynamicPrep.db and _G.DynamicPrep.db.displayMode)
                or (_G.DynamicPrepDB and ((_G.DynamicPrepDB.global and _G.DynamicPrepDB.global.displayMode) or (_G.DynamicPrepDB.profile and _G.DynamicPrepDB.profile.displayMode) or _G.DynamicPrepDB.displayMode))
                or (gTbl.hudVisibility and gTbl.hudVisibility["PREP"])
            return (dm ~= "HIDDEN" and dm ~= "OFF" and dm ~= false)
        elseif targetKey == "TARGET" then
            local tv = (_G.DynamicMarker and _G.DynamicMarker.db and _G.DynamicMarker.db.targetBarVisibility)
                or (_G.DynamicMarkerDB and ((_G.DynamicMarkerDB.global and _G.DynamicMarkerDB.global.targetBarVisibility) or (_G.DynamicMarkerDB.profile and _G.DynamicMarkerDB.profile.targetBarVisibility) or _G.DynamicMarkerDB.targetBarVisibility))
                or (gTbl.hudVisibility and gTbl.hudVisibility["TARGET"])
            return (tv ~= "HIDDEN" and tv ~= "OFF" and tv ~= false)
        elseif targetKey == "FLARE" then
            local fv = (_G.DynamicMarker and _G.DynamicMarker.db and _G.DynamicMarker.db.flareBarVisibility)
                or (_G.DynamicMarkerDB and ((_G.DynamicMarkerDB.global and _G.DynamicMarkerDB.global.flareBarVisibility) or (_G.DynamicMarkerDB.profile and _G.DynamicMarkerDB.profile.flareBarVisibility) or _G.DynamicMarkerDB.flareBarVisibility))
                or (gTbl.hudVisibility and gTbl.hudVisibility["FLARE"])
            return (fv ~= "HIDDEN" and fv ~= "OFF" and fv ~= false)
        elseif targetKey == "prepBuffs" then
            local rb = _G.DynamicPrep and _G.DynamicPrep.db and _G.DynamicPrep.db.raidBuffs
            if type(rb) == "table" then return rb.enabled and true or false end
            local hv = gTbl.hudVisibility and gTbl.hudVisibility["prepBuffs"]
            return (hv ~= "HIDDEN" and hv ~= "OFF" and hv ~= false)
        elseif targetKey == "CHAT" then
            local hv = gTbl.hudVisibility and gTbl.hudVisibility["CHAT"]
            return (hv ~= "HIDDEN" and hv ~= "OFF" and hv ~= false)
        elseif targetKey == "VAULT" then
            if type(_G.DynamicVaultDB) == "table" then
                return _G.DynamicVaultDB.showScreenOverlay == true
            end
            return false
        end
        return true
    end

    local function IsHudNormallyShown(targetKey)
        if not IsHudParentModuleActive(targetKey) then
            return false
        end
        return GetHudVisibility(targetKey) == true
    end
    addonTable.IsHudTargetShown = IsHudNormallyShown

    local function ShouldShowHudMoverInEditMode(targetKey)
        if not isHudEditModeActive then
            return false
        end
        if IsHudNormallyShown(targetKey) then
            return true
        end
        return (explicitlyPreviewedHiddenHud == targetKey) and (selectedHudTarget == targetKey)
    end

    local function SelectDefaultVisibleHudTarget()
        for _, hDef in ipairs(hudTargetDefs) do
            if IsHudNormallyShown(hDef.key) then
                return hDef.key
            end
        end
        for _, hDef in ipairs(hudTargetDefs) do
            if IsHudParentModuleActive(hDef.key) then
                return hDef.key
            end
        end
        return "TOAST"
    end

    local function SetHudVisibility(targetKey, isShown)
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        gTbl.hudVisibility = gTbl.hudVisibility or {}
        local targets = (targetKey == "ALL") and { "TOAST", "PREP", "TARGET", "FLARE", "prepBuffs" } or { targetKey or "TOAST" }
        for _, k in ipairs(targets) do
            gTbl.hudVisibility[k] = isShown and "ALWAYS" or "HIDDEN"
            if isHudEditModeActive and k == selectedHudTarget then
                if isShown then
                    if explicitlyPreviewedHiddenHud == k then
                        explicitlyPreviewedHiddenHud = nil
                    end
                else
                    explicitlyPreviewedHiddenHud = k
                end
            end
            if k == "TOAST" then
                local modeVal = isShown and "ALWAYS" or "OFF"
                local dispVal = isShown and "DETAILED" or "OFF"
                if DynamicLoadDB then
                    DynamicLoadDB.toastEnabled = (isShown == true)
                    DynamicLoadDB.toastMode = modeVal
                    if not isShown or DynamicLoadDB.toastDisplayMode == "OFF" then
                        DynamicLoadDB.toastDisplayMode = dispVal
                    end
                end
                if _G.DynamicSuiteDB and _G.DynamicSuiteDB.global then
                    _G.DynamicSuiteDB.global.toastEnabled = (isShown == true)
                    _G.DynamicSuiteDB.global.toastMode = modeVal
                    if not isShown or _G.DynamicSuiteDB.global.toastDisplayMode == "OFF" then
                        _G.DynamicSuiteDB.global.toastDisplayMode = dispVal
                    end
                end
                gTbl.toastEnabled = (isShown == true)
                gTbl.toastMode = modeVal
                if not isShown or gTbl.toastDisplayMode == "OFF" then
                    gTbl.toastDisplayMode = dispVal
                end
                if _G.DynamicLoadToastFrame and not InCombatLockdown() then
                    if isShown then _G.DynamicLoadToastFrame:Show() else _G.DynamicLoadToastFrame:Hide() end
                end
                if f.themeView and f.themeView.Refresh and f.themeView:IsShown() then
                    f.themeView.Refresh()
                end
                if f.toastConfigPanel and f.toastConfigPanel.RefreshControls then
                    pcall(f.toastConfigPanel.RefreshControls)
                end
                if _G.DynamicGroup and _G.DynamicGroup.UpdateTeleportToast then
                    pcall(_G.DynamicGroup.UpdateTeleportToast, _G.DynamicGroup)
                end
            elseif k == "PREP" then
                local modeVal = isShown and "ALWAYS" or "HIDDEN"
                if _G.DynamicPrep and type(_G.DynamicPrep.db) == "table" then
                    _G.DynamicPrep.db.displayMode = modeVal
                end
                if type(_G.DynamicPrepDB) == "table" then
                    _G.DynamicPrepDB.displayMode = modeVal
                    if type(_G.DynamicPrepDB.global) == "table" then _G.DynamicPrepDB.global.displayMode = modeVal end
                    if type(_G.DynamicPrepDB.profile) == "table" then _G.DynamicPrepDB.profile.displayMode = modeVal end
                end
                local lf = GetLiveHudFrame("PREP")
                if lf and not InCombatLockdown() then
                    if isShown then lf:Show() else lf:Hide() end
                end
                if _G.DynamicPrep and _G.DynamicPrep.RefreshBar then
                    pcall(_G.DynamicPrep.RefreshBar, _G.DynamicPrep)
                end
            elseif k == "TARGET" then
                local modeVal = isShown and "ALWAYS" or "HIDDEN"
                if _G.DynamicMarker and type(_G.DynamicMarker.db) == "table" then
                    _G.DynamicMarker.db.targetBarVisibility = modeVal
                end
                if type(_G.DynamicMarkerDB) == "table" then
                    _G.DynamicMarkerDB.targetBarVisibility = modeVal
                    if type(_G.DynamicMarkerDB.global) == "table" then _G.DynamicMarkerDB.global.targetBarVisibility = modeVal end
                    if type(_G.DynamicMarkerDB.profile) == "table" then _G.DynamicMarkerDB.profile.targetBarVisibility = modeVal end
                end
                local lf = GetLiveHudFrame("TARGET")
                if lf and not InCombatLockdown() then
                    if isShown then lf:Show() else lf:Hide() end
                end
                if _G.DynamicMarker and _G.DynamicMarker.RefreshTargetBar then
                    pcall(_G.DynamicMarker.RefreshTargetBar, _G.DynamicMarker)
                end
            elseif k == "FLARE" then
                local modeVal = isShown and "ALWAYS" or "HIDDEN"
                if _G.DynamicMarker and type(_G.DynamicMarker.db) == "table" then
                    _G.DynamicMarker.db.flareBarVisibility = modeVal
                end
                if type(_G.DynamicMarkerDB) == "table" then
                    _G.DynamicMarkerDB.flareBarVisibility = modeVal
                    if type(_G.DynamicMarkerDB.global) == "table" then _G.DynamicMarkerDB.global.flareBarVisibility = modeVal end
                    if type(_G.DynamicMarkerDB.profile) == "table" then _G.DynamicMarkerDB.profile.flareBarVisibility = modeVal end
                end
                local lf = GetLiveHudFrame("FLARE")
                if lf and not InCombatLockdown() then
                    if isShown then lf:Show() else lf:Hide() end
                end
                if _G.DynamicMarker and _G.DynamicMarker.RefreshFlareBar then
                    pcall(_G.DynamicMarker.RefreshFlareBar, _G.DynamicMarker)
                end
            elseif k == "prepBuffs" then
                if _G.DynamicPrep and type(_G.DynamicPrep.db) == "table" and type(_G.DynamicPrep.db.raidBuffs) == "table" then
                    _G.DynamicPrep.db.raidBuffs.enabled = isShown and true or false
                end
                if _G.DynamicPrep and _G.DynamicPrep.RefreshClickableBuffs then
                    pcall(_G.DynamicPrep.RefreshClickableBuffs, _G.DynamicPrep, true)
                end
            elseif k == "CHAT" then
                local lf = GetLiveHudFrame("CHAT")
                if lf and not InCombatLockdown() then
                    if isShown then lf:Show() else lf:Hide() end
                end
                if _G.DynamicChat and _G.DynamicChat.ApplySleekChatSkin then
                    pcall(_G.DynamicChat.ApplySleekChatSkin, _G.DynamicChat)
                end
            elseif k == "VAULT" then
                if type(_G.DynamicVaultDB) == "table" then
                    _G.DynamicVaultDB.showScreenOverlay = (isShown == true)
                end
                if _G.DynamicVault and _G.DynamicVault.RefreshOverlays then
                    pcall(_G.DynamicVault.RefreshOverlays, _G.DynamicVault)
                end
            end
        end
        if SyncAllEditModeHuds then
            SyncAllEditModeHuds(true)
        end
    end

    -- Full-Surface Drag Shield over any HUD in Edit Mode (blocks child left/right-clicks, dims HUD, and overlays Name + Scale + (X, Y) centered on top)
    local function GetHudStateCarrier(hudFrame, targetKey)
        if targetKey == "CHAT" and _G.DynamicChat then
            return _G.DynamicChat
        end
        return hudFrame
    end

    local function AttachOrUpdateDragShield(hudFrame, targetKey, activeMode)
        if targetKey == "CHAT" and not IsChatHudTargetOwned() then
            if _G.DynamicChat and _G.DynamicChat.HideHudEditMover then
                pcall(_G.DynamicChat.HideHudEditMover, _G.DynamicChat)
            end
            return
        end
        if not hudFrame then return end
        local stateCarrier = GetHudStateCarrier(hudFrame, targetKey)
        if (targetKey == "TARGET" or targetKey == "FLARE") and _G.DynamicMarker and _G.DynamicMarker.HasEncapsulatedHudMovers then
            stateCarrier._dsEditModeActive = false
            stateCarrier._dsDragging = false
            if stateCarrier._dsDragShield then
                stateCarrier._dsDragShield:SetScript("OnUpdate", nil)
                stateCarrier._dsDragShield:Hide()
            end
            return
        end
        if not activeMode then
            stateCarrier._dsEditModeActive = false
            stateCarrier._dsDragging = false
            if targetKey == "CHAT" then
                if IsChatHudTargetOwned() then
                    if hudFrame.SetClampRectInsets then hudFrame:SetClampRectInsets(0, 0, 0, 0) end
                    if hudFrame.SetClampedToScreen then hudFrame:SetClampedToScreen(false) end
                    if hudFrame.SetUserPlaced then hudFrame:SetUserPlaced(true) end
                end
            elseif targetKey == "TARGET" or targetKey == "FLARE" then
                if hudFrame.SetClampRectInsets then hudFrame:SetClampRectInsets(0, 0, 0, 0) end
                if hudFrame.SetClampedToScreen then hudFrame:SetClampedToScreen(false) end
            else
                if hudFrame.SetClampedToScreen then hudFrame:SetClampedToScreen(true) end
            end
            if stateCarrier._dsDragShield then
                stateCarrier._dsDragShield:SetScript("OnUpdate", nil)
                if stateCarrier._dsDragShield.resizeGrip then
                    stateCarrier._dsDragShield.resizeGrip:SetScript("OnUpdate", nil)
                end
                stateCarrier._dsDragShield:Hide()
            end
            return
        end
        stateCarrier._dsEditModeActive = true
        if hudFrame.SetClampedToScreen then hudFrame:SetClampedToScreen(false) end
        if hudFrame.mover and hudFrame.mover.Hide then hudFrame.mover:Hide() end
        if hudFrame.editDragShield and hudFrame.editDragShield.Hide then hudFrame.editDragShield:Hide() end
        if not stateCarrier._dsDragShield then
            local ar, ag, ab = UI.GetActiveAccentColor()
            local shieldParent = (targetKey == "CHAT") and UIParent or hudFrame
            local shield = CreateFrame("Button", nil, shieldParent)
            if shield.SetIgnoreParentAlpha then shield:SetIgnoreParentAlpha(true) end
            if targetKey == "CHAT" then
                shield:SetFrameStrata("DIALOG")
                local cfScale = (hudFrame.GetScale and hudFrame:GetScale()) or 1.0
                if shield.SetScale then pcall(shield.SetScale, shield, cfScale) end
                local lIn, rIn, tIn, bIn = -36, 8, 36, -32
                if _G.DynamicChat and _G.DynamicChat.GetChatMoverBoxInsets then
                    local ok, l, r, t, b = pcall(_G.DynamicChat.GetChatMoverBoxInsets, _G.DynamicChat)
                    if ok and l ~= nil then lIn, rIn, tIn, bIn = l, r, t, b end
                end
                local chatPanel = (_G.DynamicChat and _G.DynamicChat.GetPrimaryBackdropPanel and _G.DynamicChat:GetPrimaryBackdropPanel()) or nil
                if chatPanel then
                    shield:SetPoint("TOPLEFT", chatPanel, "TOPLEFT", 0, 0)
                    shield:SetPoint("BOTTOMRIGHT", chatPanel, "BOTTOMRIGHT", 0, 0)
                else
                    shield:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", lIn, tIn)
                    shield:SetPoint("BOTTOMRIGHT", hudFrame, "BOTTOMRIGHT", rIn, bIn)
                end
            else
                shield:SetFrameStrata("HIGH")
                shield:SetAllPoints(hudFrame)
            end
            shield:SetFrameLevel(math.max((hudFrame:GetFrameLevel() or 10) + 50, 80))
            shield:EnableMouse(true)
            shield:EnableMouseWheel(true)
            shield:RegisterForClicks("AnyUp", "AnyDown")
            shield:RegisterForDrag("LeftButton")
            if shield.SetClampRectInsets then shield:SetClampRectInsets(0, 0, 0, 0) end
            if hudFrame.SetClampRectInsets then hudFrame:SetClampRectInsets(0, 0, 0, 0) end
            if shield.SetClampedToScreen then shield:SetClampedToScreen(false) end

            local initBgAlpha = (targetKey == "CHAT") and 0.50 or 0.78
            shield.bg = UI.SolidTex(shield, "BACKGROUND", 0, 0.02, 0.025, 0.035, initBgAlpha)
            shield.bg:SetAllPoints()

            local badgeFrame = CreateFrame("Frame", nil, shield)
            if badgeFrame.SetIgnoreParentAlpha then badgeFrame:SetIgnoreParentAlpha(true) end
            badgeFrame:SetAllPoints(shield)
            badgeFrame:SetFrameLevel(shield:GetFrameLevel() + 5)
            UI.CreatePixelBorder(badgeFrame, ar, ag, ab, 1.0, 3)
            shield.badgeFrame = badgeFrame
            shield.dsBorder = badgeFrame.dsBorder

            local overlayText = badgeFrame:CreateFontString(nil, "OVERLAY", nil, 5)
            overlayText:SetPoint("CENTER", badgeFrame, "CENTER", 0, 0)
            overlayText:SetJustifyH("CENTER")
            overlayText:SetWordWrap(false)
            UI.SetFont(overlayText, 11, "", 1, 1, 1, 1)
            shield.overlayText = overlayText

            shield.UpdateOverlay = function(self, lx, ly, isSelected)
                if targetKey == "CHAT" then
                    if not IsChatHudTargetOwned() then
                        self:Hide()
                        return
                    end
                    local cfScale = (hudFrame.GetScale and hudFrame:GetScale()) or 1.0
                    if self.SetScale then pcall(self.SetScale, self, cfScale) end
                    local lIn, rIn, tIn, bIn = -36, 8, 36, -32
                    if _G.DynamicChat and _G.DynamicChat.GetChatMoverBoxInsets then
                        local ok, l, r, t, b = pcall(_G.DynamicChat.GetChatMoverBoxInsets, _G.DynamicChat)
                        if ok and l ~= nil then lIn, rIn, tIn, bIn = l, r, t, b end
                    end
                    local chatPanel = (_G.DynamicChat and _G.DynamicChat.GetPrimaryBackdropPanel and _G.DynamicChat:GetPrimaryBackdropPanel()) or nil
                    self:ClearAllPoints()
                    if chatPanel then
                        self:SetPoint("TOPLEFT", chatPanel, "TOPLEFT", 0, 0)
                        self:SetPoint("BOTTOMRIGHT", chatPanel, "BOTTOMRIGHT", 0, 0)
                    else
                        self:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", lIn, tIn)
                        self:SetPoint("BOTTOMRIGHT", hudFrame, "BOTTOMRIGHT", rIn, bIn)
                    end
                    if lx == nil or ly == nil then
                        local _, _, liveX, liveY = GetLiveHudLocalOffset(hudFrame, "CHAT")
                        lx, ly = liveX, liveY
                    end
                end
                local r, g, b = UI.GetActiveAccentColor()
                local aHex = UI.GetActiveAccentHex()
                local meta = hudTargetMeta[targetKey] or hudTargetMeta["TOAST"]
                local curPct = math.floor(GetHudScale(targetKey) * 100 + 0.5)
                local isVis = GetHudVisibility(targetKey)
                local isModActive = IsHudParentModuleActive(targetKey)
                if self.bg then
                    if targetKey == "CHAT" then
                        self.bg:SetColorTexture(0.02, 0.025, 0.035, isSelected and 0.52 or 0.40)
                    else
                        self.bg:SetColorTexture(0.02, 0.025, 0.035, isSelected and 0.82 or 0.68)
                    end
                end
                if self.dsBorder then
                    if self.dsBorder.SetThickness then
                        self.dsBorder:SetThickness(isSelected and 2 or 1)
                    end
                    if isSelected then
                        self.dsBorder:SetColor(r, g, b, 1.0)
                    else
                        self.dsBorder:SetColor(0.18, 0.20, 0.25, 0.30)
                    end
                end
                if self.overlayText then
                    local sizeInfo = ""
                    if targetKey == "CHAT" and hudFrame and hudFrame.GetWidth and hudFrame.GetHeight then
                        sizeInfo = string.format("  |cFF64748B|||r  |cFF94A3B8%dx%d|r", math.floor((hudFrame:GetWidth() or 430) + 0.5), math.floor((hudFrame:GetHeight() or 200) + 0.5))
                    end
                    if not isModActive then
                        self.overlayText:SetAlpha(isSelected and 1.0 or 0.85)
                        self.overlayText:SetText(string.format("|cFF94A3B8%s|r  |cFF64748B|||r  |cFFEF4444DISABLED (Module Off)|r  |cFF64748B|||r  |cFF94A3B8X: %d, Y: %d|r%s", meta.label, lx or 0, ly or 0, sizeInfo))
                    elseif not isVis then
                        self.overlayText:SetAlpha(isSelected and 1.0 or 0.85)
                        self.overlayText:SetText(string.format("|cFF94A3B8%s|r  |cFF64748B|||r  |cFFEF4444HIDDEN (Click Shown to Enable)|r  |cFF64748B|||r  |cFF94A3B8X: %d, Y: %d|r%s", meta.label, lx or 0, ly or 0, sizeInfo))
                    elseif isSelected then
                        self.overlayText:SetAlpha(1.0)
                        self.overlayText:SetText(string.format("|cFF%s%s|r  |cFF64748B|||r  |cFFF3F5F8Scale: %d%%|r  |cFF64748B|||r  |cFFF3F5F8X: %d, Y: %d|r%s", aHex, meta.label, curPct, lx or 0, ly or 0, sizeInfo))
                    else
                        self.overlayText:SetAlpha(0.85)
                        self.overlayText:SetText(string.format("|cFF94A3B8%s|r  |cFF475569|||r  |cFF64748BScale: %d%%|r  |cFF475569|||r  |cFF64748BX: %d, Y: %d|r%s", meta.label, curPct, lx or 0, ly or 0, sizeInfo))
                    end
                end
                if self.resizeGrip then
                    if self.resizeGrip.lineH then self.resizeGrip.lineH:SetColorTexture(r, g, b, isSelected and 1.0 or 0.55) end
                    if self.resizeGrip.lineV then self.resizeGrip.lineV:SetColorTexture(r, g, b, isSelected and 1.0 or 0.55) end
                end
            end

            -- Unified Bottom-Right Corner Resize Grip for Chat Frame ("CHAT")
            if targetKey == "CHAT" then
                local grip = CreateFrame("Button", nil, shield)
                grip:SetSize(14, 14)
                grip:SetPoint("BOTTOMRIGHT", shield, "BOTTOMRIGHT", -4, 4)
                grip:SetFrameLevel(shield:GetFrameLevel() + 12)
                grip:EnableMouse(true)
                grip:RegisterForDrag("LeftButton")

                local gripTex = grip:CreateTexture(nil, "OVERLAY", nil, 5)
                gripTex:SetAllPoints()
                gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
                gripTex:SetDesaturated(true)
                gripTex:SetVertexColor(0.55, 0.58, 0.65, 0.75)

                grip:SetScript("OnEnter", function(selfGrip)
                    gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
                    gripTex:SetDesaturated(false)
                    gripTex:SetVertexColor(0.976, 0.451, 0.086, 0.95)
                    GameTooltip:SetOwner(selfGrip, "ANCHOR_TOP")
                    GameTooltip:SetText("Resize Chat Frame", 1, 1, 1)
                    GameTooltip:AddLine("Drag to resize your chat window (width 240-1200, height 100-900).", 0.82, 0.86, 0.92, true)
                    GameTooltip:Show()
                end)
                grip:SetScript("OnLeave", function()
                    gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
                    gripTex:SetDesaturated(true)
                    gripTex:SetVertexColor(0.55, 0.58, 0.65, 0.75)
                    GameTooltip:Hide()
                end)
                grip:SetScript("OnDragStart", function(selfGrip)
                    if selectedHudTarget ~= "CHAT" and addonTable.OnHudTargetSelected then
                        addonTable.OnHudTargetSelected("CHAT")
                    end
                    stateCarrier._dsDragging = true
                    local _, _, _, uScale, relScale = GetHudLocalScreenExtents(hudFrame, "CHAT")
                    local cxRaw, cyRaw = GetCursorPosition()
                    selfGrip._startCurUIParentX = (cxRaw or 0) / uScale
                    selfGrip._startCurUIParentY = (cyRaw or 0) / uScale
                    selfGrip._startRelScale = relScale
                    selfGrip._startW = (hudFrame.GetWidth and hudFrame:GetWidth()) or 430
                    selfGrip._startH = (hudFrame.GetHeight and hudFrame:GetHeight()) or 200
                    local _, _, startOffX, startOffY = GetLiveHudLocalOffset(hudFrame, "CHAT")
                    selfGrip._startOffX = startOffX
                    selfGrip._startOffY = startOffY
                    selfGrip:SetScript("OnUpdate", function()
                        if not IsMouseButtonDown("LeftButton") or InCombatLockdown() then
                            selfGrip:SetScript("OnUpdate", nil)
                            return
                        end
                        local uiW_local, uiH_local, _, curUScale, curRelScale = GetHudLocalScreenExtents(hudFrame, "CHAT")
                        local lEx, rEx, tEx, bEx = GetChatExtraInsetsLocal("CHAT")
                        local rxRaw, ryRaw = GetCursorPosition()
                        local curUIParentX = (rxRaw or 0) / curUScale
                        local curUIParentY = (ryRaw or 0) / curUScale
                        local dW = (curUIParentX - (selfGrip._startCurUIParentX or curUIParentX)) / curRelScale
                        local dH = ((selfGrip._startCurUIParentY or curUIParentY) - curUIParentY) / curRelScale
                        local maxAllowedW = math.min(1200, math.max(240, math.floor(uiW_local - lEx - rEx)))
                        local maxAllowedH = math.min(900, math.max(100, math.floor(uiH_local - tEx - bEx)))
                        local newW = math.floor(math.max(240, math.min(maxAllowedW, (selfGrip._startW or 430) + dW)) + 0.5)
                        local newH = math.floor(math.max(100, math.min(maxAllowedH, (selfGrip._startH or 200) + dH)) + 0.5)
                        local actualDH = newH - (selfGrip._startH or 200)
                        local rawOffX = math.max(0, selfGrip._startOffX or 0)
                        local rawOffY = math.max(0, (selfGrip._startOffY or 0) - actualDH)
                        hudFrame:SetSize(newW, newH)
                        local _, _, newOffX, newOffY = ComputeSnappedAndClampedHudCoords(hudFrame, "CHAT", rawOffX, rawOffY, "BOTTOMLEFT", "BOTTOMLEFT", false)
                        if newW == selfGrip._lastW and newH == selfGrip._lastH and newOffX == selfGrip._lastX and newOffY == selfGrip._lastY then
                            return
                        end
                        hudFrame:ClearAllPoints()
                        hudFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", lEx + newOffX, bEx + newOffY)
                        selfGrip._lastW = newW
                        selfGrip._lastH = newH
                        selfGrip._lastX = newOffX
                        selfGrip._lastY = newOffY
                        if _G.DynamicChat and _G.DynamicChat.ApplySleekChatSkin then
                            pcall(_G.DynamicChat.ApplySleekChatSkin, _G.DynamicChat)
                        end
                        if shield.UpdateOverlay then
                            shield:UpdateOverlay(newOffX, newOffY, true)
                        end
                        if editModeInspectorModal and editModeInspectorModal.UpdateLiveCoordReadout then
                            editModeInspectorModal.UpdateLiveCoordReadout(newOffX, newOffY)
                        end
                    end)
                end)
                grip:SetScript("OnHide", function(selfGrip)
                    selfGrip:SetScript("OnUpdate", nil)
                    stateCarrier._dsDragging = false
                end)
                grip:SetScript("OnDragStop", function(selfGrip)
                    selfGrip:SetScript("OnUpdate", nil)
                    stateCarrier._dsDragging = false
                    local finalW = selfGrip._lastW or (hudFrame.GetWidth and hudFrame:GetWidth()) or 430
                    local finalH = selfGrip._lastH or (hudFrame.GetHeight and hudFrame:GetHeight()) or 200
                    local _, _, finalX, finalY = GetLiveHudLocalOffset(hudFrame, "CHAT")
                    finalX = selfGrip._lastX or finalX
                    finalY = selfGrip._lastY or finalY
                    if _G.DynamicChat and _G.DynamicChat.SaveChatFramePosition then
                        pcall(_G.DynamicChat.SaveChatFramePosition, _G.DynamicChat, "BOTTOMLEFT", "BOTTOMLEFT", finalX, finalY, finalW, finalH)
                    end
                    SetStoredHudPos("CHAT", "BOTTOMLEFT", "BOTTOMLEFT", finalX, finalY)
                    if shield.UpdateOverlay then
                        shield:UpdateOverlay(finalX, finalY, true)
                    end
                    if editModeInspectorModal and editModeInspectorModal.RefreshState then
                        editModeInspectorModal.RefreshState()
                    end
                end)
                shield.resizeGrip = grip
            end

            shield:SetScript("OnClick", function()
                if addonTable.OnHudTargetSelected then
                    addonTable.OnHudTargetSelected(targetKey)
                end
            end)
            shield:SetScript("OnMouseWheel", function(self, delta)
                if selectedHudTarget ~= targetKey and selectedHudTarget ~= "ALL" and addonTable.OnHudTargetSelected then
                    addonTable.OnHudTargetSelected(targetKey)
                end
                local curVal = GetHudScale(targetKey)
                local nextVal = curVal + (delta > 0 and HUD_SCALE_STEP or -HUD_SCALE_STEP)
                SetHudScale(targetKey, nextVal)
                local _, _, cx, cy = GetStoredHudPos(targetKey)
                if self.UpdateOverlay then
                    self:UpdateOverlay(cx, cy, true)
                end
                if editModeInspectorModal and editModeInspectorModal.RefreshState then
                    editModeInspectorModal.RefreshState()
                end
            end)
            shield:SetScript("OnDragStart", function(self)
                if selectedHudTarget ~= targetKey and selectedHudTarget ~= "ALL" and addonTable.OnHudTargetSelected then
                    addonTable.OnHudTargetSelected(targetKey)
                end
                stateCarrier._dsDragging = true
                stateCarrier._dsEditModeActive = true
                if (targetKey == "TARGET" or targetKey == "FLARE") and _G.DynamicMarker then
                    _G.DynamicMarker.isDraggingHUD = true
                end
                if hudFrame.StopMovingOrSizing then pcall(hudFrame.StopMovingOrSizing, hudFrame) end
                if hudFrame.SetClampedToScreen then hudFrame:SetClampedToScreen(false) end
                if self.SetClampedToScreen then self:SetClampedToScreen(false) end
                if hudFrame.SetClampRectInsets then hudFrame:SetClampRectInsets(0, 0, 0, 0) end
                if self.SetClampRectInsets then self:SetClampRectInsets(0, 0, 0, 0) end

                local usePt, useRelPt, startX, startY = GetLiveHudLocalOffset(hudFrame, targetKey)
                local _, _, _, uScale, relScale, frameW, frameH = GetHudLocalScreenExtents(hudFrame, targetKey)
                local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
                local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
                local rawCurX, rawCurY = GetCursorPosition()
                local startCurX = (rawCurX or 0) / uScale
                local startCurY = (rawCurY or 0) / uScale
                self._dragUsePt = usePt
                self._dragUseRelPt = useRelPt
                if targetKey == "CHAT" then
                    local startVisBLX = startX * relScale
                    local startVisBLY = startY * relScale
                    self._dragGrabVisX = startVisBLX - startCurX
                    self._dragGrabVisY = startVisBLY - startCurY
                else
                    local fCx, fCy = hudFrame.GetCenter and hudFrame:GetCenter()
                    local startVisCx, startVisCy
                    if fCx and fCy then
                        startVisCx = fCx * relScale
                        startVisCy = fCy * relScale
                    else
                        local pfx, pfy = GetAnchorFraction(usePt)
                        local rfx, rfy = GetAnchorFraction(useRelPt)
                        startVisCx = (rfx * screenW) + (startX * relScale) + (0.5 - pfx) * ((frameW or 0) * relScale)
                        startVisCy = (rfy * screenH) + (startY * relScale) + (0.5 - pfy) * ((frameH or 0) * relScale)
                    end
                    self._dragGrabVisX = startVisCx - startCurX
                    self._dragGrabVisY = startVisCy - startCurY
                end
                self._lastDragX = startX
                self._lastDragY = startY

                self:SetScript("OnUpdate", function()
                    if not IsMouseButtonDown("LeftButton") or InCombatLockdown() then
                        self:SetScript("OnUpdate", nil)
                        HideSnapGuides()
                        return
                    end
                    local _, _, _, curUScale, curRelScale, curFrameW, curFrameH = GetHudLocalScreenExtents(hudFrame, targetKey)
                    local curScreenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
                    local curScreenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
                    local cxRaw, cyRaw = GetCursorPosition()
                    local pNow = self._dragUsePt or usePt
                    local rNow = self._dragUseRelPt or useRelPt
                    local rawX, rawY
                    if targetKey == "CHAT" then
                        local rawVisBLX = ((cxRaw or 0) / curUScale) + (self._dragGrabVisX or 0)
                        local rawVisBLY = ((cyRaw or 0) / curUScale) + (self._dragGrabVisY or 0)
                        rawX = rawVisBLX / curRelScale
                        rawY = rawVisBLY / curRelScale
                        pNow, rNow = "BOTTOMLEFT", "BOTTOMLEFT"
                    else
                        local rawVisCx = ((cxRaw or 0) / curUScale) + (self._dragGrabVisX or 0)
                        local rawVisCy = ((cyRaw or 0) / curUScale) + (self._dragGrabVisY or 0)
                        local pfx, pfy = GetAnchorFraction(pNow)
                        local rfx, rfy = GetAnchorFraction(rNow)
                        rawX = ((rawVisCx - (0.5 - pfx) * ((curFrameW or 0) * curRelScale)) - (rfx * curScreenW)) / curRelScale
                        rawY = ((rawVisCy - (0.5 - pfy) * ((curFrameH or 0) * curRelScale)) - (rfy * curScreenH)) / curRelScale
                    end
                    local ptNow, relPtNow, lx, ly, gx, gy = ComputeSnappedAndClampedHudCoords(hudFrame, targetKey, rawX, rawY, pNow, rNow, true)
                    UpdateSnapGuides(gx, gy)
                    if lx == self._lastDragX and ly == self._lastDragY then
                        return
                    end
                    self._lastDragX = lx
                    self._lastDragY = ly
                    if not InCombatLockdown() then
                        if targetKey == "CHAT" then
                            local lEx, _, _, bEx = GetChatExtraInsetsLocal("CHAT")
                            hudFrame:ClearAllPoints()
                            hudFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", lEx + lx, bEx + ly)
                        else
                            hudFrame:ClearAllPoints()
                            hudFrame:SetPoint(ptNow, UIParent, relPtNow, lx, ly)
                        end
                    end
                    if targetKey == "CHAT" and _G.DynamicChat and _G.DynamicChat.ApplySleekChatSkin then
                        pcall(_G.DynamicChat.ApplySleekChatSkin, _G.DynamicChat)
                    end
                    if self.UpdateOverlay then
                        self:UpdateOverlay(lx, ly, true)
                    end
                    if editModeInspectorModal and editModeInspectorModal.UpdateLiveCoordReadout then
                        editModeInspectorModal.UpdateLiveCoordReadout(lx, ly)
                    end
                end)
            end)
            shield:SetScript("OnHide", function(self)
                self:SetScript("OnUpdate", nil)
                HideSnapGuides()
                stateCarrier._dsDragging = false
            end)
            shield:SetScript("OnDragStop", function(self)
                self:SetScript("OnUpdate", nil)
                HideSnapGuides()
                if hudFrame.StopMovingOrSizing then pcall(hudFrame.StopMovingOrSizing, hudFrame) end
                local usePt = self._dragUsePt or ((targetKey == "TARGET" or targetKey == "FLARE" or targetKey == "prepBuffs") and "CENTER" or ((targetKey == "CHAT") and "BOTTOMLEFT" or "TOP"))
                local useRelPt = self._dragUseRelPt or usePt
                local rx, ry
                if self._lastDragX ~= nil and self._lastDragY ~= nil then
                    usePt, useRelPt, rx, ry = ClampHudCoordsToScreen(hudFrame, targetKey, usePt, useRelPt, self._lastDragX, self._lastDragY, false)
                else
                    usePt, useRelPt, rx, ry = ComputeDraggedHudCoords(hudFrame, targetKey)
                end
                stateCarrier._dsDragging = false
                if (targetKey == "TARGET" or targetKey == "FLARE") and _G.DynamicMarker then
                    _G.DynamicMarker.isDraggingHUD = false
                end
                self._lastDragX = nil
                self._lastDragY = nil
                SetStoredHudPos(targetKey, usePt, useRelPt, rx, ry)
                if self.UpdateOverlay then
                    self:UpdateOverlay(rx, ry, true)
                end
                if editModeInspectorModal and editModeInspectorModal.RefreshState then
                    editModeInspectorModal.RefreshState()
                end
            end)
            stateCarrier._dsDragShield = shield
        end
        local activeShield = stateCarrier._dsDragShield
        if activeShield and activeShield.SetIgnoreParentAlpha then
            activeShield:SetIgnoreParentAlpha(true)
        end
        local isSelected = (selectedHudTarget == targetKey or selectedHudTarget == "ALL")
        local isVis = GetHudVisibility(targetKey)
        if targetKey == "CHAT" then
            hudFrame:SetAlpha(1.0)
        else
            local liveAlpha = GetHudOpacity(targetKey)
            hudFrame:SetAlpha((not isVis) and math.min(liveAlpha, 0.60) or liveAlpha)
        end
        local _, _, curX, curY = GetStoredHudPos(targetKey)
        local shieldLvl = math.max((hudFrame:GetFrameLevel() or 10) + 50, 80)
        if targetKey ~= "CHAT" then
            activeShield:SetFrameStrata("HIGH")
        end
        activeShield:SetFrameLevel(shieldLvl)
        if activeShield.badgeFrame then
            activeShield.badgeFrame:SetFrameLevel(shieldLvl + 5)
        end
        if activeShield.resizeGrip then
            activeShield.resizeGrip:SetFrameLevel(shieldLvl + 12)
        end
        if activeShield.UpdateOverlay then
            activeShield:UpdateOverlay(curX, curY, isSelected)
        end
        activeShield:Show()
    end

    local function OpenAndStyleHudTarget(targetKey)
        local target = targetKey or selectedHudTarget
        addonTable.ExitHudEditMode(false)
        if target == "TOAST" or target == "ALL" then
            addonTable.ShowConfigUI()
            isToastSubTabActive = true
            if f.toastConfigPanel then f.toastConfigPanel:Show() end
            if f.toolbar then f.toolbar:Hide() end
            if f.telemetryStrip then f.telemetryStrip:Hide() end
            if f.scrollFrame then f.scrollFrame:Hide() end
            if f.scrollTrack then f.scrollTrack:Hide() end
            if f.toastConfigPanel and f.toastConfigPanel.RefreshControls then f.toastConfigPanel.RefreshControls() end
            if f.UpdateAllTabVisuals then f.UpdateAllTabVisuals() end
        elseif target == "PREP" or target == "prepBuffs" then
            addonTable.OpenPeerModule("DynamicPrep")
        elseif target == "TARGET" or target == "FLARE" then
            addonTable.OpenPeerModule("DynamicMarker")
            local dmMod = _G.DynamicSuite and _G.DynamicSuite.modules and (_G.DynamicSuite.modules["DynamicMarker"] or _G.DynamicSuite.modules["marker"])
            if dmMod then
                local tabIdx = (target == "FLARE") and 2 or 1
                local selFn = dmMod.SelectSubTab or dmMod.SelectTab or dmMod.SetActiveTab
                if type(selFn) == "function" then
                    pcall(selFn, dmMod, tabIdx, true)
                end
            end
        elseif target == "CHAT" then
            addonTable.OpenPeerModule("DynamicChat")
        end
    end

    -- Syncs Edit Mode state and drag shields onto the real HUD frames WITHOUT overwriting their screen positions
    SyncAllEditModeHuds = function(activeMode)
        local ar, ag, ab = UI.GetActiveAccentColor()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
        if gTbl.hudShowGrid == nil then gTbl.hudShowGrid = true end
        local showGridLines = (gTbl.hudShowGrid == true)
        local snapMode = GetActiveSnapMode()
        local showCrosshair = showGridLines or (snapMode ~= "OFF")
        local grid = EnsureSnapGridOverlay()
        if grid.centerV then grid.centerV:SetColorTexture(ar, ag, ab, 0.55); grid.centerV:SetShown(showCrosshair) end
        if grid.centerH then grid.centerH:SetColorTexture(ar, ag, ab, 0.55); grid.centerH:SetShown(showCrosshair) end
        for _, mLine in ipairs(grid.minorLines or {}) do
            mLine:SetShown(showGridLines)
        end
        grid:SetShown(activeMode and (showGridLines or showCrosshair))

        if not activeMode then
            if _G.DynamicMarker then
                _G.DynamicMarker.isDraggingHUD = false
                _G.DynamicMarker._previewHiddenMoverKey = nil
            end
            for _, cb in pairs(addonTable.hudEditCallbacks or {}) do
                if type(cb) == "function" then
                    pcall(cb, false, selectedHudTarget, snapMode)
                end
            end
            addonTable.SetToastEditMode(false)
            if _G.DynamicLoadToastFrame then
                _G.DynamicLoadToastFrame._dsEditModeActive = false
                _G.DynamicLoadToastFrame._dsDragging = false
                AttachOrUpdateDragShield(_G.DynamicLoadToastFrame, "TOAST", false)
                _G.DynamicLoadToastFrame:SetAlpha(1.0)
                if not GetHudVisibility("TOAST") and not InCombatLockdown() then
                    _G.DynamicLoadToastFrame:Hide()
                end
            end
            if floatingEditPill then floatingEditPill:Hide() end
            local dmOwnsMovers = (_G.DynamicMarker and _G.DynamicMarker.HasEncapsulatedHudMovers)
            for _, k in ipairs({ "PREP", "TARGET", "FLARE", "prepBuffs", "CHAT", "VAULT" }) do
                local lf = GetLiveHudFrame(k)
                if lf then
                    local carrier = GetHudStateCarrier(lf, k)
                    carrier._dsEditModeActive = false
                    carrier._dsDragging = false
                    AttachOrUpdateDragShield(lf, k, false)
                    if (k == "TARGET" or k == "FLARE") and dmOwnsMovers then
                        carrier._wasShownBeforeEdit = nil
                    else
                        lf:SetAlpha(1.0)
                        if k ~= "CHAT" and lf.SetEditMode then
                            lf._inExternalSetEditMode = true
                            pcall(lf.SetEditMode, lf, false)
                            lf._inExternalSetEditMode = nil
                        elseif carrier._wasShownBeforeEdit == false and k ~= "CHAT" and not InCombatLockdown() then
                            lf:Hide()
                        end
                        if not GetHudVisibility(k) and k ~= "prepBuffs" and k ~= "CHAT" and not InCombatLockdown() then
                            lf:Hide()
                        end
                        carrier._wasShownBeforeEdit = nil
                    end
                end
            end
            if _G.DynamicChat and _G.DynamicChat.HideHudEditMover then
                pcall(_G.DynamicChat.HideHudEditMover, _G.DynamicChat)
            end
            if IsChatHudTargetOwned() and _G.DynamicChat and not InCombatLockdown() then
                if _G.DynamicChat.ApplySavedChatFramePosition then
                    pcall(_G.DynamicChat.ApplySavedChatFramePosition, _G.DynamicChat)
                end
                if _G.DynamicChat.ApplySleekChatSkin then
                    pcall(_G.DynamicChat.ApplySleekChatSkin, _G.DynamicChat)
                end
            end
            return
        end

        if InCombatLockdown() then
            return
        end

        if not IsChatHudTargetOwned() then
            if selectedHudTarget == "CHAT" then
                selectedHudTarget = SelectDefaultVisibleHudTarget()
            end
            if _G.DynamicChat and _G.DynamicChat.HideHudEditMover then
                pcall(_G.DynamicChat.HideHudEditMover, _G.DynamicChat)
            end
        end

        if _G.DynamicMarker then
            if _G.DynamicMarker.RegisterWithSuiteHudEditMode and not _G.DynamicMarker._registeredSuiteHudCallback then
                pcall(_G.DynamicMarker.RegisterWithSuiteHudEditMode, _G.DynamicMarker)
            end
            if explicitlyPreviewedHiddenHud == "TARGET" and selectedHudTarget == "TARGET" then
                _G.DynamicMarker._previewHiddenMoverKey = "TargetBar"
            elseif explicitlyPreviewedHiddenHud == "FLARE" and selectedHudTarget == "FLARE" then
                _G.DynamicMarker._previewHiddenMoverKey = "FlareBar"
            else
                _G.DynamicMarker._previewHiddenMoverKey = nil
            end
        end

        local suitePreviewOpts = {
            showTarget = ShouldShowHudMoverInEditMode("TARGET"),
            showFlare = ShouldShowHudMoverInEditMode("FLARE"),
            explicitlyPreviewed = explicitlyPreviewedHiddenHud,
        }
        for _, cb in pairs(addonTable.hudEditCallbacks or {}) do
            if type(cb) == "function" then
                pcall(cb, true, selectedHudTarget, snapMode, suitePreviewOpts)
            end
        end

        -- Show Alert Toast ONLY when normally active/shown OR explicitly previewed
        if ShouldShowHudMoverInEditMode("TOAST") then
            addonTable.SetToastEditMode(true, selectedTabKey)
            if _G.DynamicLoadToastFrame then
                _G.DynamicLoadToastFrame._dsEditModeActive = true
                local isToastVis = IsHudNormallyShown("TOAST")
                local toastAlpha = GetHudOpacity("TOAST")
                _G.DynamicLoadToastFrame:SetAlpha((not isToastVis) and math.min(toastAlpha, 0.65) or toastAlpha)
                if addonTable.ApplyToastVisuals then
                    pcall(addonTable.ApplyToastVisuals)
                end
                AttachOrUpdateDragShield(_G.DynamicLoadToastFrame, "TOAST", true)
            end
        else
            addonTable.SetToastEditMode(false)
            if _G.DynamicLoadToastFrame then
                _G.DynamicLoadToastFrame._dsEditModeActive = false
                _G.DynamicLoadToastFrame._dsDragging = false
                AttachOrUpdateDragShield(_G.DynamicLoadToastFrame, "TOAST", false)
                _G.DynamicLoadToastFrame:SetAlpha(1.0)
                if not _G.DynamicLoadToastFrame.isRealAlert and not InCombatLockdown() then
                    _G.DynamicLoadToastFrame:Hide()
                end
            end
        end

        -- Unlock and show active/shown (or explicitly previewed hidden) HUD frames in-place WITHOUT moving coordinates
        local dmOwnsMovers = (_G.DynamicMarker and _G.DynamicMarker.HasEncapsulatedHudMovers)
        for _, k in ipairs({ "PREP", "TARGET", "FLARE", "prepBuffs", "CHAT", "VAULT" }) do
            local showMover = ShouldShowHudMoverInEditMode(k)
            if (k == "TARGET" or k == "FLARE") and dmOwnsMovers then
                local liveFrame = GetLiveHudFrame(k)
                if liveFrame then
                    AttachOrUpdateDragShield(liveFrame, k, showMover)
                end
            else
                local liveFrame = GetLiveHudFrame(k)
                local isVis = IsHudNormallyShown(k)
                if liveFrame then
                    pcall(function()
                        local carrier = GetHudStateCarrier(liveFrame, k)
                        if showMover then
                            carrier._dsEditModeActive = true
                            if carrier._wasShownBeforeEdit == nil then
                                carrier._wasShownBeforeEdit = liveFrame:IsShown()
                            end
                            if k ~= "CHAT" and not carrier._dsDragging and liveFrame.SetEditMode then
                                liveFrame._inExternalSetEditMode = true
                                pcall(liveFrame.SetEditMode, liveFrame, true)
                                liveFrame._inExternalSetEditMode = nil
                            end
                            if k ~= "CHAT" then
                                liveFrame:Show()
                            end
                            if k == "CHAT" then
                                liveFrame:SetAlpha(1.0)
                            else
                                local liveAlpha = GetHudOpacity(k)
                                liveFrame:SetAlpha((not isVis) and math.min(liveAlpha, 0.60) or liveAlpha)
                            end
                            AttachOrUpdateDragShield(liveFrame, k, true)
                        else
                            carrier._dsEditModeActive = false
                            carrier._dsDragging = false
                            AttachOrUpdateDragShield(liveFrame, k, false)
                            if k == "CHAT" and _G.DynamicChat and _G.DynamicChat.HideHudEditMover then
                                pcall(_G.DynamicChat.HideHudEditMover, _G.DynamicChat)
                            elseif k ~= "CHAT" then
                                if liveFrame.SetEditMode then
                                    liveFrame._inExternalSetEditMode = true
                                    pcall(liveFrame.SetEditMode, liveFrame, false)
                                    liveFrame._inExternalSetEditMode = nil
                                end
                                liveFrame:SetAlpha(1.0)
                                liveFrame:Hide()
                            end
                        end
                    end)
                end
            end
        end

        if floatingEditPill then floatingEditPill:Hide() end
    end

    -- Helper to create compact Directional Arrow Buttons using Arty's vector chevron textures
    local function CreateCompactArrowBtn(parent, width, height, dir, tooltipText)
        local btn = CreateFlatButton(parent, width, height, "", false)
        local tex = btn:CreateTexture(nil, "OVERLAY")
        tex:SetSize(12, 12)
        tex:SetPoint("CENTER", btn, "CENTER", 0, 0)
        UI.DisablePixelSnap(tex)

        if dir == "DOWN" then
            tex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_down.tga")
            tex:SetRotation(0)
        elseif dir == "LEFT" then
            tex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga")
            tex:SetRotation(math.rad(90))
        elseif dir == "RIGHT" then
            tex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga")
            tex:SetRotation(math.rad(-90))
        else -- "UP"
            tex:SetTexture("Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_chevron_up.tga")
            tex:SetRotation(0)
        end
        local ar, ag, ab = UI.GetActiveAccentColor()
        tex:SetVertexColor(ar, ag, ab, 1.0)
        btn.arrowTex = tex

        function btn:RefreshAccent()
            local r, g, b = UI.GetActiveAccentColor()
            tex:SetVertexColor(r, g, b, 1.0)
        end

        btn.OnCustomEnter = function(self)
            tex:SetVertexColor(1, 1, 1, 1.0)
            local accentHex = UI.GetActiveAccentHex()
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltipText, 1, 1, 1)
            GameTooltip:AddLine("|cFF34D399Left-Click:|r |cFFE2E8F0Nudge 1 px|r   |cFF475569|||r   |cFF" .. accentHex .. "Shift-Click:|r |cFFE2E8F0Nudge 10 px|r", 1, 1, 1)
            GameTooltip:Show()
        end
        btn.OnCustomLeave = function()
            local r, g, b = UI.GetActiveAccentColor()
            tex:SetVertexColor(r, g, b, 1.0)
            GameTooltip:Hide()
        end
        return btn
    end
    UI.CreateCompactArrowBtn = CreateCompactArrowBtn

    local function NudgeSelectedHud(dx, dy)
        local targets = (selectedHudTarget == "ALL") and { "TOAST", "PREP", "TARGET", "FLARE" } or { selectedHudTarget }
        for _, k in ipairs(targets) do
            if k == "TOAST" then
                if addonTable.NudgeToastPosition then
                    addonTable.NudgeToastPosition(dx, dy)
                end
            else
                local pt, relPt, x, y = GetStoredHudPos(k)
                SetStoredHudPos(k, pt, relPt, x + dx, y + dy)
            end
        end
        SyncAllEditModeHuds(true)
        if editModeInspectorModal and editModeInspectorModal.RefreshState then
            editModeInspectorModal.RefreshState()
        end
    end

    local function ApplyQuickAlignment(alignType)
        local targets = (selectedHudTarget == "ALL") and { "TOAST", "PREP", "TARGET", "FLARE" } or { selectedHudTarget }
        local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
        local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
        for _, k in ipairs(targets) do
            local pt, _, cx, cy = GetStoredHudPos(k)
            local liveFrame = GetLiveHudFrame(k)
            if (k == "TARGET" or k == "FLARE") and _G.DynamicMarker and _G.DynamicMarker.SyncBarScaleAndSizeToDB then
                pcall(_G.DynamicMarker.SyncBarScaleAndSizeToDB, _G.DynamicMarker, liveFrame, k)
            end
            local uiW_local, uiH_local, _, _, relScale, frameW, frameH = GetHudLocalScreenExtents(liveFrame, k)
            local w = frameW or 160
            local h = frameH or 40
            if k == "CHAT" then
                local lEx, rEx, tEx, bEx = GetChatExtraInsetsLocal("CHAT")
                if alignType == "CENTER_H" then
                    SetStoredHudPos("CHAT", "BOTTOMLEFT", "BOTTOMLEFT", math.floor(((uiW_local - w - lEx - rEx) / 2) + 0.5), cy)
                elseif alignType == "CENTER_V" then
                    SetStoredHudPos("CHAT", "BOTTOMLEFT", "BOTTOMLEFT", cx, math.floor(((uiH_local - h - tEx - bEx) / 2) + 0.5))
                elseif alignType == "LEFT" then
                    SetStoredHudPos("CHAT", "BOTTOMLEFT", "BOTTOMLEFT", 0, cy)
                elseif alignType == "RIGHT" then
                    SetStoredHudPos("CHAT", "BOTTOMLEFT", "BOTTOMLEFT", math.floor((uiW_local - w - lEx - rEx) + 0.5), cy)
                elseif alignType == "TOP" then
                    SetStoredHudPos("CHAT", "BOTTOMLEFT", "BOTTOMLEFT", cx, math.floor((uiH_local - h - tEx - bEx) + 0.5))
                elseif alignType == "BOTTOM" then
                    SetStoredHudPos("CHAT", "BOTTOMLEFT", "BOTTOMLEFT", cx, 0)
                end
            elseif k == "TARGET" or k == "FLARE" then
                local visW = w * (relScale or 1.0)
                local visH = h * (relScale or 1.0)
                if alignType == "CENTER_H" then
                    SetStoredHudPos(k, "CENTER", "CENTER", 0, cy)
                elseif alignType == "CENTER_V" then
                    SetStoredHudPos(k, "CENTER", "CENTER", cx, 0)
                elseif alignType == "LEFT" then
                    SetStoredHudPos(k, "CENTER", "CENTER", math.ceil(-(screenW / 2) + (visW / 2) - 1e-6), cy)
                elseif alignType == "RIGHT" then
                    SetStoredHudPos(k, "CENTER", "CENTER", math.floor((screenW / 2) - (visW / 2) + 1e-6), cy)
                elseif alignType == "TOP" then
                    SetStoredHudPos(k, "CENTER", "CENTER", cx, math.floor((screenH / 2) - (visH / 2) + 1e-6))
                elseif alignType == "BOTTOM" then
                    SetStoredHudPos(k, "CENTER", "CENTER", cx, math.ceil(-(screenH / 2) + (visH / 2) - 1e-6))
                end
            else
                local usePt = (pt == "CENTER" or k == "prepBuffs") and "CENTER" or "TOP"
                local useRelPt = (usePt == "CENTER") and "CENTER" or "TOP"
                if alignType == "CENTER_H" then
                    SetStoredHudPos(k, usePt, useRelPt, 0, cy)
                elseif alignType == "CENTER_V" then
                    local useY = (usePt == "CENTER") and 0 or math.floor(-(uiH_local / 2) + (h / 2) + 0.5)
                    SetStoredHudPos(k, usePt, useRelPt, cx, useY)
                elseif alignType == "LEFT" then
                    local useX = math.floor(-(uiW_local / 2) + (w / 2) + 0.5)
                    SetStoredHudPos(k, usePt, useRelPt, useX, cy)
                elseif alignType == "RIGHT" then
                    local useX = math.floor((uiW_local / 2) - (w / 2) + 0.5)
                    SetStoredHudPos(k, usePt, useRelPt, useX, cy)
                elseif alignType == "TOP" then
                    local useY = (usePt == "CENTER") and math.floor((uiH_local / 2) - (h / 2) + 0.5) or 0
                    SetStoredHudPos(k, usePt, useRelPt, cx, useY)
                elseif alignType == "BOTTOM" then
                    local useY = (usePt == "CENTER") and math.floor(-(uiH_local / 2) + (h / 2) + 0.5) or math.floor(-(uiH_local - h) + 0.5)
                    SetStoredHudPos(k, usePt, useRelPt, cx, useY)
                end
            end
        end
        SyncAllEditModeHuds(true)
        if editModeInspectorModal and editModeInspectorModal.RefreshState then
            editModeInspectorModal.RefreshState()
        end
    end

    local function ApplyExactHudCoordinate(axis, numVal)
        if numVal == nil then return end
        local cleanVal = math.floor(numVal + 0.5)
        if selectedHudTarget == "ALL" then
            local _, _, baseToastX, baseToastY = GetStoredHudPos("TOAST")
            for _, k in ipairs({ "TOAST", "PREP", "TARGET", "FLARE" }) do
                local pt, relPt, cx, cy = GetStoredHudPos(k)
                local usePt = pt or "TOP"
                local useRelPt = relPt or usePt
                if axis == "X" then
                    SetStoredHudPos(k, usePt, useRelPt, cleanVal, cy)
                else
                    local dy = cleanVal - (baseToastY or -140)
                    SetStoredHudPos(k, usePt, useRelPt, cx, (cy or 0) + dy)
                end
            end
        else
            local pt, relPt, cx, cy = GetStoredHudPos(selectedHudTarget)
            local usePt = pt or "TOP"
            local useRelPt = relPt or usePt
            if axis == "X" then
                SetStoredHudPos(selectedHudTarget, usePt, useRelPt, cleanVal, cy)
            else
                SetStoredHudPos(selectedHudTarget, usePt, useRelPt, cx, cleanVal)
            end
        end
        SyncAllEditModeHuds(true)
        if editModeInspectorModal and editModeInspectorModal.RefreshState then
            editModeInspectorModal.RefreshState()
        end
    end

    isHudEditModeActive = false
    isExitingHudEditMode = false
    addonTable.IsHudEditModeActive = function()
        return isHudEditModeActive
    end

    function addonTable.ClampAllSuiteHudsToScreen()
        if InCombatLockdown and InCombatLockdown() then return end
        for _, hDef in ipairs(hudTargetDefs) do
            if hDef.key ~= "ALL" then
                if hDef.key ~= "CHAT" or IsChatHudTargetOwned() then
                    if hDef.key == "TOAST" then
                        if addonTable.ClampToastPosition then
                            pcall(addonTable.ClampToastPosition)
                        end
                    elseif hDef.key == "TARGET" and _G.DynamicMarker and _G.DynamicMarker.RefreshTargetBar then
                        pcall(_G.DynamicMarker.RefreshTargetBar, _G.DynamicMarker)
                    elseif hDef.key == "FLARE" and _G.DynamicMarker and _G.DynamicMarker.RefreshFlareBar then
                        pcall(_G.DynamicMarker.RefreshFlareBar, _G.DynamicMarker)
                    else
                        local pt, relPt, x, y = GetStoredHudPos(hDef.key)
                        SetStoredHudPos(hDef.key, pt, relPt, x, y)
                    end
                end
            end
        end
    end

    function addonTable.ResetAllHudPositions(silent)
        if InCombatLockdown and InCombatLockdown() then
            addonTable._pendingHudPositionReset = true
            if not silent then
                print("|cFF38BDF8DynamicSuite|r: |cFFF87171Cannot reset HUD positions during combat lockdown.|r Positions will reset safely after combat ends.")
            end
            return false
        end
        addonTable._pendingHudPositionReset = false
        for _, hDef in ipairs(hudTargetDefs) do
            local k = hDef.key
            if k ~= "ALL" and (k ~= "CHAT" or IsChatHudTargetOwned()) then
                local meta = hudTargetMeta[k] or hudTargetMeta["TOAST"]
                local pt = meta.defPoint or "TOP"
                local relPt = meta.defRelPoint or pt
                if k == "TOAST" then
                    SetHudScale("TOAST", 1.0)
                    SetHudOpacity("TOAST", GetDefaultHudOpacity("TOAST"))
                    SetHudBorderStyle("TOAST", "ACCENT")
                    if addonTable.SetToastPresetPosition then
                        addonTable.SetToastPresetPosition(pt, relPt, meta.defX, meta.defY)
                    end
                elseif k == "CHAT" then
                    SetHudScale("CHAT", 1.0)
                    if _G.DynamicChat and _G.DynamicChat.ResetChatFramePosition then
                        pcall(_G.DynamicChat.ResetChatFramePosition, _G.DynamicChat)
                    end
                    SetHudOpacity("CHAT", GetDefaultHudOpacity("CHAT"))
                    SetHudBorderStyle("CHAT", "ACCENT")
                    SetStoredHudPos("CHAT", pt, relPt, meta.defX, meta.defY)
                elseif k == "prepBuffs" then
                    SetHudScale("prepBuffs", 1.0)
                    SetHudOpacity("prepBuffs", GetDefaultHudOpacity("prepBuffs"))
                    SetHudBorderStyle("prepBuffs", "ACCENT")
                    SetHudOrientation("prepBuffs", "HORIZONTAL")
                    if _G.DynamicPrep and _G.DynamicPrep.ResetBuffBarHUDPosition then
                        pcall(_G.DynamicPrep.ResetBuffBarHUDPosition, _G.DynamicPrep, true)
                    end
                    SetStoredHudPos("prepBuffs", pt, relPt, meta.defX, meta.defY)
                elseif k == "TARGET" or k == "FLARE" then
                    SetHudScale(k, 1.0)
                    SetHudOpacity(k, GetDefaultHudOpacity(k))
                    SetHudBorderStyle(k, "ACCENT")
                    SetHudOrientation(k, "HORIZONTAL")
                    if _G.DynamicMarker and _G.DynamicMarker.ResetSingleHUDPosition then
                        pcall(_G.DynamicMarker.ResetSingleHUDPosition, _G.DynamicMarker, k, true)
                    end
                    SetStoredHudPos(k, pt, relPt, meta.defX, meta.defY)
                elseif k == "PREP" then
                    SetHudScale("PREP", 1.0)
                    SetHudOpacity("PREP", GetDefaultHudOpacity("PREP"))
                    SetHudBorderStyle("PREP", "ACCENT")
                    if _G.DynamicPrep and _G.DynamicPrep.ResetHUDPosition then
                        pcall(_G.DynamicPrep.ResetHUDPosition, _G.DynamicPrep, true)
                    end
                    SetStoredHudPos("PREP", pt, relPt, meta.defX, meta.defY)
                elseif k == "VAULT" then
                    SetHudScale("VAULT", 1.0)
                    SetHudOpacity("VAULT", GetDefaultHudOpacity("VAULT"))
                    SetHudBorderStyle("VAULT", "ACCENT")
                    if _G.DynamicVault and _G.DynamicVault.ResetOverlayPosition then
                        pcall(_G.DynamicVault.ResetOverlayPosition, _G.DynamicVault)
                    end
                    SetStoredHudPos("VAULT", pt, relPt, meta.defX, meta.defY)
                else
                    SetHudScale(k, 1.0)
                    SetHudOpacity(k, GetDefaultHudOpacity(k))
                    SetHudBorderStyle(k, "ACCENT")
                    SetStoredHudPos(k, pt, relPt, meta.defX, meta.defY)
                end
            end
        end
        if isHudEditModeActive then
            SyncAllEditModeHuds(true)
        end
        if editModeInspectorModal and editModeInspectorModal.RefreshState then
            editModeInspectorModal.RefreshState()
        end
        if not silent then
            print("|cFF38BDF8DynamicSuite|r: All HUD positions reset to safe screen-clamped defaults.")
        end
        return true
    end

    local function EnsureEditModeInspectorModal()
        if editModeInspectorModal then return editModeInspectorModal end

        local ar, ag, ab = UI.GetActiveAccentColor()
        local m = CreateFrame("Frame", "DynamicSuiteEditModeModal", UIParent)
        m:SetSize(560, 110)

        local function ApplyEditModalClampInsets(modal)
            local target = modal or m
            if not target then return end
            local w = (target.GetWidth and target:GetWidth()) or 560
            local h = (target.GetHeight and target:GetHeight()) or 110
            local keepVisible = 60
            local allowOffX = math.max(0, w - keepVisible)
            local allowOffY = math.max(0, h - keepVisible)
            if target.SetClampedToScreen then target:SetClampedToScreen(true) end
            if target.SetClampRectInsets then
                target:SetClampRectInsets(allowOffX, -allowOffX, -allowOffY, allowOffY)
            end
        end

        function m:RestoreSavedPosition()
            ApplyEditModalClampInsets(self)
            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
            local pos = gTbl.editModeModalPos
            self:ClearAllPoints()
            if type(pos) == "table" and pos.x ~= nil and pos.y ~= nil then
                local w = (self.GetWidth and self:GetWidth()) or 560
                local h = (self.GetHeight and self:GetHeight()) or 110
                local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
                local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
                local allowOffX = math.max(0, w - 60)
                local allowOffY = math.max(0, h - 60)
                local minX = -(screenW / 2) + (w / 2) - allowOffX
                local maxX = (screenW / 2) - (w / 2) + allowOffX
                local minY = -(screenH / 2) + (h / 2) - allowOffY
                local maxY = (screenH / 2) - (h / 2) + allowOffY
                local cx = math.max(minX, math.min(maxX, tonumber(pos.x) or 0))
                local cy = math.max(minY, math.min(maxY, tonumber(pos.y) or 0))
                self:SetPoint("CENTER", UIParent, "CENTER", cx, cy)
            else
                self:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
            end
        end
        m:RestoreSavedPosition()
        local function SaveEditModalPosition()
            m:StopMovingOrSizing()
            local cx, cy = m:GetCenter()
            local ux, uy = UIParent:GetCenter()
            if cx and cy and ux and uy then
                local dx = math.floor((cx - ux) + 0.5)
                local dy = math.floor((cy - uy) + 0.5)
                m:ClearAllPoints()
                m:SetPoint("CENTER", UIParent, "CENTER", dx, dy)
                local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal()
                if gTbl then
                    gTbl.editModeModalPos = { point = "CENTER", relPoint = "CENTER", x = dx, y = dy }
                end
            end
        end
        m:SetFrameStrata("DIALOG")
        m:SetFrameLevel(200)
        m:SetToplevel(true)
        ApplyEditModalClampInsets(m)
        m:EnableMouse(true)
        m:SetMovable(true)
        m:RegisterForDrag("LeftButton")
        m:SetScript("OnDragStart", function()
            if m.hudSelectorPopup and m.hudSelectorPopup:IsShown() then m.hudSelectorPopup:Hide() end
            m:StartMoving()
        end)
        m:SetScript("OnDragStop", SaveEditModalPosition)
        m:SetScript("OnHide", function(self)
            if self.hudSelectorPopup and self.hudSelectorPopup:IsShown() then
                self.hudSelectorPopup:Hide()
            end
            if not self._suppressInitialOnHide and isHudEditModeActive and not isExitingHudEditMode then
                addonTable.ExitHudEditMode(false)
            end
        end)
        table.insert(UISpecialFrames, "DynamicSuiteEditModeModal")
        m._suppressInitialOnHide = true
        m:Hide()
        m._suppressInitialOnHide = false

        m.bg = UI.SolidTex(m, "BACKGROUND", 0, 0.045, 0.052, 0.068, 0.98)
        m.bg:SetAllPoints()
        UI.CreatePixelBorder(m, ar, ag, ab, 0.95, 3)

        local function TightenCompactButtonLabel(b, padX)
            if b and b.label then
                local px = padX or 3
                b.label:ClearAllPoints()
                b.label:SetPoint("LEFT", b, "LEFT", px, 0)
                b.label:SetPoint("RIGHT", b, "RIGHT", -px, 0)
                b.label:SetJustifyH("CENTER")
                b.label:SetWordWrap(false)
                if b.label.SetMaxLines then b.label:SetMaxLines(1) end
            end
        end

        ------------------------------------------------------------------------
        -- Row 1: Compact Command & Selector Bar (34px tall)
        ------------------------------------------------------------------------
        local mHdr = CreateFrame("Frame", nil, m)
        mHdr:SetPoint("TOPLEFT", m, "TOPLEFT", 1, -1)
        mHdr:SetPoint("TOPRIGHT", m, "TOPRIGHT", -1, -1)
        mHdr:SetHeight(34)
        mHdr.bg = UI.SolidTex(mHdr, "BACKGROUND", 1, 0.03, 0.035, 0.048, 1.0)
        mHdr.bg:SetAllPoints()
        mHdr:EnableMouse(true)
        mHdr:RegisterForDrag("LeftButton")
        mHdr:SetScript("OnDragStart", function()
            if m.hudSelectorPopup and m.hudSelectorPopup:IsShown() then m.hudSelectorPopup:Hide() end
            m:StartMoving()
        end)
        mHdr:SetScript("OnDragStop", SaveEditModalPosition)

        local mHdrDiv = UI.SolidTex(mHdr, "OVERLAY", 2, ar, ag, ab, 0.35)
        mHdrDiv:SetPoint("BOTTOMLEFT", mHdr, "BOTTOMLEFT", 0, 0)
        mHdrDiv:SetPoint("BOTTOMRIGHT", mHdr, "BOTTOMRIGHT", 0, 0)
        mHdrDiv:SetHeight(1)

        -- Monogram Logo (18x18)
        local mLogo = CreateFrame("Frame", nil, mHdr)
        mLogo:SetSize(18, 18)
        mLogo:SetPoint("LEFT", mHdr, "LEFT", 8, 0)
        UI.CreatePixelBorder(mLogo, ar, ag, ab, 0.85, 3)
        UI.DrawBrandEmblem(mLogo, 18)
        mHdr.logo = mLogo

        -- Compact HUD Selector Dropdown (162x22)
        local hudSelectorBtn = CreateFlatButton(mHdr, 162, 22, "Alert Toast", false)
        hudSelectorBtn:SetPoint("LEFT", mLogo, "RIGHT", 6, 0)
        hudSelectorBtn.idleBgColor = { r = 0.055, g = 0.064, b = 0.088, a = 0.98 }
        hudSelectorBtn.idleBorderColor = { r = 0.165, g = 0.192, b = 0.259, a = 0.95 }
        ApplyFlatButtonVisual(hudSelectorBtn, false)

        hudSelectorBtn.visDot = UI.SolidTex(hudSelectorBtn, "OVERLAY", 3, 0.133, 0.773, 0.369, 1.0)
        hudSelectorBtn.visDot:SetSize(6, 6)
        hudSelectorBtn.visDot:SetPoint("LEFT", hudSelectorBtn, "LEFT", 7, 0)
        hudSelectorBtn.chevron = UI.CreateChevronDown(hudSelectorBtn, "RIGHT", hudSelectorBtn, "RIGHT", -6, 0, 1, 1, 1, 0.78)
        if hudSelectorBtn.label then
            hudSelectorBtn.label:ClearAllPoints()
            hudSelectorBtn.label:SetPoint("LEFT", hudSelectorBtn.visDot, "RIGHT", 5, 0)
            hudSelectorBtn.label:SetPoint("RIGHT", hudSelectorBtn, "RIGHT", -18, 0)
            hudSelectorBtn.label:SetJustifyH("LEFT")
            hudSelectorBtn.label:SetWordWrap(false)
        end

        local hudSelectorPopup = nil
        local function EnsureHudSelectorPopup()
            if hudSelectorPopup then return hudSelectorPopup end
            local pop = CreateFrame("Frame", "DynamicSuiteHudSelectorPopup", UIParent)
            pop:SetFrameStrata("TOOLTIP")
            pop:SetFrameLevel(250)
            pop:SetToplevel(true)
            pop:SetClampedToScreen(true)
            pop:EnableMouse(true)
            pop.bg = UI.SolidTex(pop, "BACKGROUND", 0, 0.043, 0.051, 0.071, 0.99)
            pop.bg:SetAllPoints()
            UI.CreatePixelBorder(pop, ar, ag, ab, 0.85, 3)

            local catcher = CreateFrame("Button", nil, pop)
            catcher:SetAllPoints(UIParent)
            catcher:SetFrameStrata("TOOLTIP")
            catcher:SetFrameLevel(245)
            catcher:RegisterForClicks("AnyDown", "AnyUp")
            catcher:SetScript("OnClick", function() pop:Hide() end)
            pop.catcher = catcher
            pop:Hide()

            pop.rows = {}
            local rowH = 22
            local gapY = 2
            local pad = 4
            for i, hDef in ipairs(hudTargetDefs) do
                local rb = CreateFlatButton(pop, 184, rowH, hDef.label, false)
                rb:SetPoint("TOPLEFT", pop, "TOPLEFT", pad, -(pad + (i - 1) * (rowH + gapY)))
                rb.hudKey = hDef.key
                rb.baseLabel = hDef.label
                rb.visDot = UI.SolidTex(rb, "OVERLAY", 3, 0.133, 0.773, 0.369, 1.0)
                rb.visDot:SetSize(6, 6)
                rb.visDot:SetPoint("LEFT", rb, "LEFT", 7, 0)
                if rb.label then
                    rb.label:ClearAllPoints()
                    rb.label:SetPoint("LEFT", rb.visDot, "RIGHT", 6, 0)
                    rb.label:SetPoint("RIGHT", rb, "RIGHT", -6, 0)
                    rb.label:SetJustifyH("LEFT")
                    rb.label:SetWordWrap(false)
                end
                rb:SetScript("OnClick", function()
                    pop:Hide()
                    if hDef.key == "CHAT" and not IsChatHudTargetOwned() then
                        return
                    end
                    addonTable.OnHudTargetSelected(hDef.key)
                end)
                pop.rows[i] = rb
            end
            pop:SetSize(192, (pad * 2) + (#hudTargetDefs * rowH) + ((#hudTargetDefs - 1) * gapY))
            pop:SetScript("OnHide", function()
                UI.SetChevronState(hudSelectorBtn, false)
            end)
            if type(UISpecialFrames) == "table" then
                local found = false
                for _, n in ipairs(UISpecialFrames) do
                    if n == "DynamicSuiteHudSelectorPopup" then found = true; break end
                end
                if not found then
                    table.insert(UISpecialFrames, "DynamicSuiteHudSelectorPopup")
                end
            end
            hudSelectorPopup = pop
            m.hudSelectorPopup = pop
            return pop
        end

        hudSelectorBtn:HookScript("OnHide", function()
            if hudSelectorPopup and hudSelectorPopup:IsShown() then
                hudSelectorPopup:Hide()
            end
        end)

        hudSelectorBtn:SetScript("OnClick", function(selfBtn)
            local pop = EnsureHudSelectorPopup()
            if pop:IsShown() then
                pop:Hide()
                return
            end
            local cr, cg, cb = UI.GetActiveAccentColor()
            local accentCol = { r = cr, g = cg, b = cb }
            if pop.dsBorder then pop.dsBorder:SetColor(cr, cg, cb, 0.85) end
            for _, rb in ipairs(pop.rows) do
                local modActive = IsHudParentModuleActive(rb.hudKey)
                local isVis = modActive and GetHudVisibility(rb.hudKey)
                rb:SetSelected(rb.hudKey == selectedHudTarget, accentCol)
                if rb.visDot then
                    rb.visDot:SetColorTexture(isVis and 0.133 or 0.937, isVis and 0.773 or 0.267, isVis and 0.369 or 0.267, 1.0)
                end
                if rb.label then
                    rb.label:SetText(modActive and rb.baseLabel or (rb.baseLabel .. " (Off)"))
                end
                rb:SetAlpha(modActive and 1.0 or 0.55)
            end
            pop:ClearAllPoints()
            pop:SetPoint("TOPLEFT", selfBtn, "BOTTOMLEFT", 0, -2)
            pop:Show()
            UI.SetChevronState(selfBtn, true)
        end)

        -- 1. Visibility 2-Pill Switch ([ Hidden | Shown ]) with explicit full-word 60x22 sizing
        local visHiddenBtn = CreateFlatButton(mHdr, 60, 22, "Hidden", false)
        visHiddenBtn.isNegativeOpt = true
        TightenCompactButtonLabel(visHiddenBtn, 3)
        visHiddenBtn:SetPoint("LEFT", hudSelectorBtn, "RIGHT", 6, 0)
        visHiddenBtn:SetScript("OnClick", function()
            SetHudVisibility(selectedHudTarget, false)
            m.RefreshState()
        end)

        local visShownBtn = CreateFlatButton(mHdr, 60, 22, "Shown", false)
        TightenCompactButtonLabel(visShownBtn, 3)
        visShownBtn:SetPoint("LEFT", visHiddenBtn, "RIGHT", 3, 0)
        visShownBtn:SetScript("OnClick", function()
            SetHudVisibility(selectedHudTarget, true)
            m.RefreshState()
        end)

        local function UpdateHudVisSwitch()
            local isVis = GetHudVisibility(selectedHudTarget)
            local r, g, b = UI.GetActiveAccentColor()
            visShownBtn:SetSelected(isVis == true, { r = r, g = g, b = b })
            visHiddenBtn:SetSelected(isVis == false, { r = r, g = g, b = b })
        end

        -- Right-Aligned Action Cluster: [Grid] [Reset] [Back to Suite] [X]
        local closeBtn = CreateFrame("Button", nil, mHdr)
        closeBtn:SetSize(22, 22)
        closeBtn:SetPoint("RIGHT", mHdr, "RIGHT", -6, 0)
        closeBtn.bg = UI.SolidTex(closeBtn, "BACKGROUND", 2, 1, 1, 1, 0.03)
        closeBtn.bg:SetAllPoints()
        UI.CreatePixelBorder(closeBtn, 1, 1, 1, 0.12, 3)

        local closeLine1 = UI.SolidTex(closeBtn, "OVERLAY", 3, 1, 1, 1, 0.70)
        closeLine1:SetSize(10, 1.5)
        closeLine1:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
        if closeLine1.SetRotation then closeLine1:SetRotation(math.rad(45)) end

        local closeLine2 = UI.SolidTex(closeBtn, "OVERLAY", 3, 1, 1, 1, 0.70)
        closeLine2:SetSize(10, 1.5)
        closeLine2:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
        if closeLine2.SetRotation then closeLine2:SetRotation(math.rad(-45)) end

        closeBtn:SetScript("OnEnter", function(self)
            self.bg:SetColorTexture(1, 0.25, 0.25, 0.18)
            self.dsBorder:SetColor(1, 0.35, 0.35, 0.75)
            closeLine1:SetColorTexture(1, 0.35, 0.35, 1)
            closeLine2:SetColorTexture(1, 0.35, 0.35, 1)
        end)
        closeBtn:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(1, 1, 1, 0.03)
            self.dsBorder:SetColor(1, 1, 1, 0.12)
            closeLine1:SetColorTexture(1, 1, 1, 0.70)
            closeLine2:SetColorTexture(1, 1, 1, 0.70)
        end)
        closeBtn:SetScript("OnClick", function()
            addonTable.ExitHudEditMode(false)
        end)

        mHdr.backBtn = CreateFlatButton(mHdr, 84, 22, "Back to Suite", true)
        TightenCompactButtonLabel(mHdr.backBtn, 3)
        mHdr.backBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
        mHdr.backBtn:SetScript("OnClick", function()
            addonTable.ExitHudEditMode(true)
        end)
        mHdr.backBtn.OnCustomEnter = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText("Return to DynamicSuite", 1, 1, 1)
            GameTooltip:AddLine("Exits HUD Edit Mode and reopens the main DynamicSuite window.", 0.82, 0.86, 0.92, true)
            GameTooltip:Show()
        end
        mHdr.backBtn.OnCustomLeave = function()
            GameTooltip:Hide()
        end

        local rowResetConfirmPending = false
        local function ResetSelectedHudLocations()
            if InCombatLockdown and InCombatLockdown() then
                print("|cFF38BDF8DynamicSuite|r: |cFFF87171Cannot reset HUD positions during combat lockdown.|r Please wait until combat ends.")
                return
            end
            if selectedHudTarget == "ALL" then
                addonTable.ResetAllHudPositions(false)
                return
            end
            local k = selectedHudTarget
            local meta = hudTargetMeta[k] or hudTargetMeta["TOAST"]
            local pt = meta.defPoint or "TOP"
            local relPt = meta.defRelPoint or pt
            if k == "TOAST" then
                SetHudScale("TOAST", 1.0)
                SetHudOpacity("TOAST", GetDefaultHudOpacity("TOAST"))
                SetHudBorderStyle("TOAST", "ACCENT")
                if addonTable.SetToastPresetPosition then
                    addonTable.SetToastPresetPosition(pt, relPt, meta.defX, meta.defY)
                end
            elseif k == "CHAT" then
                SetHudScale("CHAT", 1.0)
                if _G.DynamicChat and _G.DynamicChat.ResetChatFramePosition then
                    pcall(_G.DynamicChat.ResetChatFramePosition, _G.DynamicChat)
                end
                SetHudOpacity("CHAT", GetDefaultHudOpacity("CHAT"))
                SetHudBorderStyle("CHAT", "ACCENT")
                SetStoredHudPos("CHAT", pt, relPt, meta.defX, meta.defY)
            elseif k == "prepBuffs" then
                SetHudScale("prepBuffs", 1.0)
                SetHudOpacity("prepBuffs", GetDefaultHudOpacity("prepBuffs"))
                SetHudBorderStyle("prepBuffs", "ACCENT")
                SetHudOrientation("prepBuffs", "HORIZONTAL")
                if _G.DynamicPrep and _G.DynamicPrep.ResetBuffBarHUDPosition then
                    pcall(_G.DynamicPrep.ResetBuffBarHUDPosition, _G.DynamicPrep, true)
                end
                SetStoredHudPos("prepBuffs", pt, relPt, meta.defX, meta.defY)
            elseif k == "TARGET" or k == "FLARE" then
                SetHudScale(k, 1.0)
                SetHudOpacity(k, GetDefaultHudOpacity(k))
                SetHudBorderStyle(k, "ACCENT")
                SetHudOrientation(k, "HORIZONTAL")
                if _G.DynamicMarker and _G.DynamicMarker.ResetSingleHUDPosition then
                    pcall(_G.DynamicMarker.ResetSingleHUDPosition, _G.DynamicMarker, k, true)
                end
                SetStoredHudPos(k, pt, relPt, meta.defX, meta.defY)
            elseif k == "PREP" then
                SetHudScale("PREP", 1.0)
                SetHudOpacity("PREP", GetDefaultHudOpacity("PREP"))
                SetHudBorderStyle("PREP", "ACCENT")
                if _G.DynamicPrep and _G.DynamicPrep.ResetHUDPosition then
                    pcall(_G.DynamicPrep.ResetHUDPosition, _G.DynamicPrep, true)
                end
                SetStoredHudPos("PREP", pt, relPt, meta.defX, meta.defY)
            elseif k == "VAULT" then
                SetHudScale("VAULT", 1.0)
                SetHudOpacity("VAULT", GetDefaultHudOpacity("VAULT"))
                SetHudBorderStyle("VAULT", "ACCENT")
                if _G.DynamicVault and _G.DynamicVault.ResetOverlayPosition then
                    pcall(_G.DynamicVault.ResetOverlayPosition, _G.DynamicVault)
                end
                SetStoredHudPos("VAULT", pt, relPt, meta.defX, meta.defY)
            else
                SetHudScale(k, 1.0)
                SetHudOpacity(k, GetDefaultHudOpacity(k))
                SetHudBorderStyle(k, "ACCENT")
                SetStoredHudPos(k, pt, relPt, meta.defX, meta.defY)
            end
            SyncAllEditModeHuds(true)
            m.RefreshState()
        end

        local rowResetBtn = CreateFlatButton(mHdr, 46, 22, "Reset", false)
        TightenCompactButtonLabel(rowResetBtn, 3)
        rowResetBtn:SetPoint("RIGHT", mHdr.backBtn, "LEFT", -4, 0)
        rowResetBtn:SetScript("OnClick", function()
            if not rowResetConfirmPending then
                rowResetConfirmPending = true
                rowResetBtn.label:SetText("Sure?")
                rowResetBtn:SetSelected(true, UI.COLORS.GOLD)
                C_Timer.After(3.5, function()
                    if rowResetConfirmPending then
                        rowResetConfirmPending = false
                        rowResetBtn.label:SetText("Reset")
                        rowResetBtn:SetSelected(false)
                    end
                end)
                return
            end
            rowResetConfirmPending = false
            ResetSelectedHudLocations()
            rowResetBtn.label:SetText("Reset")
            rowResetBtn:SetSelected(false)
        end)
        rowResetBtn.OnCustomEnter = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText("Reset Location & Style", 1, 1, 1)
            GameTooltip:AddLine("Reset selected HUD position, scale, opacity, border style, and orientation back to factory defaults.", 0.78, 0.82, 0.88, true)
            GameTooltip:Show()
        end
        rowResetBtn.OnCustomLeave = function() GameTooltip:Hide() end

        local showGridBtn = CreateFlatButton(mHdr, 42, 22, "Grid", false)
        TightenCompactButtonLabel(showGridBtn, 3)
        showGridBtn:SetPoint("RIGHT", rowResetBtn, "LEFT", -4, 0)
        showGridBtn:SetScript("OnClick", function()
            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
            if gTbl.hudShowGrid == nil then gTbl.hudShowGrid = true end
            gTbl.hudShowGrid = not gTbl.hudShowGrid
            SyncAllEditModeHuds(true)
            m.RefreshState()
        end)
        showGridBtn.OnCustomEnter = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText("Toggle Alignment Grid", 1, 1, 1)
            GameTooltip:AddLine("Show or hide the screen alignment grid overlay.", 0.78, 0.82, 0.88)
            GameTooltip:Show()
        end
        showGridBtn.OnCustomLeave = function() GameTooltip:Hide() end

        ------------------------------------------------------------------------
        -- Row 2: Compact Inspector Controls (36px tall, draggable dock body)
        ------------------------------------------------------------------------
        local inspCard = CreateFrame("Frame", nil, m)
        inspCard:SetPoint("TOPLEFT", mHdr, "BOTTOMLEFT", 4, -1)
        inspCard:SetPoint("TOPRIGHT", mHdr, "BOTTOMRIGHT", -4, -1)
        inspCard:SetHeight(36)
        inspCard.bg = UI.SolidTex(inspCard, "BACKGROUND", 1, 0.075, 0.086, 0.110, 0.96)
        inspCard.bg:SetAllPoints()
        UI.CreatePixelBorder(inspCard, 1, 1, 1, 0.10, 2)
        inspCard:EnableMouse(true)
        inspCard:RegisterForDrag("LeftButton")
        inspCard:SetScript("OnDragStart", function()
            if m.hudSelectorPopup and m.hudSelectorPopup:IsShown() then m.hudSelectorPopup:Hide() end
            m:StartMoving()
        end)
        inspCard:SetScript("OnDragStop", SaveEditModalPosition)
        m.inspCard = inspCard

        -- 2. Exact X: and Y: Coordinate EditBoxes + Directional Nudge Buttons
        local function CreateCoordBox(axisKey)
            local wrap = CreateFrame("Frame", nil, inspCard)
            wrap:SetSize(44, 22)
            wrap.bg = UI.SolidTex(wrap, "BACKGROUND", 2, 0.043, 0.051, 0.071, 0.98)
            wrap.bg:SetAllPoints()
            UI.CreatePixelBorder(wrap, 0.165, 0.192, 0.259, 0.95, 3)

            local eb = CreateFrame("EditBox", nil, wrap)
            eb:SetPoint("LEFT", wrap, "LEFT", 3, 0)
            eb:SetPoint("RIGHT", wrap, "RIGHT", -3, 0)
            eb:SetHeight(18)
            eb:SetAutoFocus(false)
            eb:SetJustifyH("CENTER")
            eb:SetMaxLetters(6)
            UI.SetFont(eb, 11, "", 1, 1, 1, 0.98)

            eb:SetScript("OnEditFocusGained", function(self)
                local r, g, b = UI.GetActiveAccentColor()
                wrap.dsBorder:SetColor(r, g, b, 1.0)
                self:HighlightText()
            end)
            eb:SetScript("OnEditFocusLost", function(self)
                wrap.dsBorder:SetColor(0.165, 0.192, 0.259, 0.95)
                self:HighlightText(0, 0)
                local v = tonumber(self:GetText())
                if v ~= nil then
                    ApplyExactHudCoordinate(axisKey, v)
                elseif m.RefreshState then
                    m.RefreshState()
                end
            end)
            eb:SetScript("OnEnterPressed", function(self)
                local v = tonumber(self:GetText())
                self:ClearFocus()
                if v ~= nil then
                    ApplyExactHudCoordinate(axisKey, v)
                end
            end)
            eb:SetScript("OnEscapePressed", function(self)
                self:ClearFocus()
                if m.RefreshState then m.RefreshState() end
            end)

            local lbl = inspCard:CreateFontString(nil, "OVERLAY")
            UI.SetFont(lbl, 10, "", 0.78, 0.82, 0.90, 1)
            lbl:SetText(axisKey .. ":")

            return eb, lbl, wrap
        end

        local xCoordBox, xCoordLbl, xCoordWrap = CreateCoordBox("X")
        xCoordLbl:SetPoint("LEFT", inspCard, "LEFT", 8, 0)
        xCoordWrap:SetPoint("LEFT", xCoordLbl, "RIGHT", 3, 0)

        local yCoordBox, yCoordLbl, yCoordWrap = CreateCoordBox("Y")
        yCoordLbl:SetPoint("LEFT", xCoordWrap, "RIGHT", 6, 0)
        yCoordWrap:SetPoint("LEFT", yCoordLbl, "RIGHT", 3, 0)

        local btnLeft = CreateCompactArrowBtn(inspCard, 20, 22, "LEFT", "Nudge Left (-X)")
        btnLeft:SetPoint("LEFT", yCoordWrap, "RIGHT", 6, 0)
        btnLeft:SetScript("OnClick", function() NudgeSelectedHud(IsShiftKeyDown() and -10 or -1, 0) end)

        local btnUp = CreateCompactArrowBtn(inspCard, 20, 22, "UP", "Nudge Up (+Y)")
        btnUp:SetPoint("LEFT", btnLeft, "RIGHT", 2, 0)
        btnUp:SetScript("OnClick", function() NudgeSelectedHud(0, IsShiftKeyDown() and 10 or 1) end)

        local btnDown = CreateCompactArrowBtn(inspCard, 20, 22, "DOWN", "Nudge Down (-Y)")
        btnDown:SetPoint("LEFT", btnUp, "RIGHT", 2, 0)
        btnDown:SetScript("OnClick", function() NudgeSelectedHud(0, IsShiftKeyDown() and -10 or -1) end)

        local btnRight = CreateCompactArrowBtn(inspCard, 20, 22, "RIGHT", "Nudge Right (+X)")
        btnRight:SetPoint("LEFT", btnDown, "RIGHT", 2, 0)
        btnRight:SetScript("OnClick", function() NudgeSelectedHud(IsShiftKeyDown() and 10 or 1, 0) end)

        local arrowBtns = { btnLeft, btnUp, btnDown, btnRight }

        -- 3. Quick Center Buttons ([Center X] [Center Y])
        local centerHorizBtn = CreateFlatButton(inspCard, 58, 22, "Center X", false)
        TightenCompactButtonLabel(centerHorizBtn, 3)
        centerHorizBtn:SetPoint("LEFT", btnRight, "RIGHT", 6, 0)
        centerHorizBtn:SetScript("OnClick", function() ApplyQuickAlignment("CENTER_H") end)

        local centerVertBtn = CreateFlatButton(inspCard, 58, 22, "Center Y", false)
        TightenCompactButtonLabel(centerVertBtn, 3)
        centerVertBtn:SetPoint("LEFT", centerHorizBtn, "RIGHT", 3, 0)
        centerVertBtn:SetScript("OnClick", function() ApplyQuickAlignment("CENTER_V") end)

        -- 4. Scale Slider ([- / Slider / + / %d%%])
        local HUD_SLIDER_W = 76
        local hudScaleMinusBtn = CreateFlatButton(inspCard, 20, 22, "-", false)
        hudScaleMinusBtn:SetPoint("LEFT", centerVertBtn, "RIGHT", 8, 0)
        hudScaleMinusBtn:SetScript("OnClick", function()
            local cur = GetHudScale(selectedHudTarget)
            SetHudScale(selectedHudTarget, cur - HUD_SCALE_STEP)
            m.RefreshState()
        end)

        local hudScaleSliderHit = CreateFrame("Frame", nil, inspCard)
        hudScaleSliderHit:SetSize(HUD_SLIDER_W, 22)
        hudScaleSliderHit:SetPoint("LEFT", hudScaleMinusBtn, "RIGHT", 4, 0)
        hudScaleSliderHit:EnableMouse(true)
        hudScaleSliderHit:EnableMouseWheel(true)

        local hudScaleTrack = UI.SolidTex(hudScaleSliderHit, "ARTWORK", 1, 0.035, 0.039, 0.051, 0.98)
        hudScaleTrack:SetSize(HUD_SLIDER_W, 4)
        hudScaleTrack:SetPoint("CENTER", hudScaleSliderHit, "CENTER", 0, 0)
        UI.CreatePixelBorder(hudScaleSliderHit, 1, 1, 1, 0.0)

        local hudScaleFill = UI.SolidTex(hudScaleSliderHit, "ARTWORK", 2, ar, ag, ab, 0.85)
        hudScaleFill:SetPoint("TOPLEFT", hudScaleTrack, "TOPLEFT", 0, 0)
        hudScaleFill:SetPoint("BOTTOMLEFT", hudScaleTrack, "BOTTOMLEFT", 0, 0)
        hudScaleFill:SetWidth(1)

        local hudScaleThumb = UI.SolidTex(hudScaleSliderHit, "OVERLAY", 4, 0.97, 0.98, 1.00, 1.0)
        hudScaleThumb:SetSize(6, 14)
        if hudScaleThumb.SetSnapToPixelGrid then
            hudScaleThumb:SetSnapToPixelGrid(false)
            hudScaleThumb:SetTexelSnappingBias(0)
        end

        local hudScalePlusBtn = CreateFlatButton(inspCard, 20, 22, "+", false)
        hudScalePlusBtn:SetPoint("LEFT", hudScaleSliderHit, "RIGHT", 4, 0)
        hudScalePlusBtn:SetScript("OnClick", function()
            local cur = GetHudScale(selectedHudTarget)
            SetHudScale(selectedHudTarget, cur + HUD_SCALE_STEP)
            m.RefreshState()
        end)

        local hudScaleBadge = CreateFrame("Frame", nil, inspCard)
        hudScaleBadge:SetSize(42, 22)
        hudScaleBadge:SetPoint("LEFT", hudScalePlusBtn, "RIGHT", 4, 0)
        hudScaleBadge.bg = UI.SolidTex(hudScaleBadge, "BACKGROUND", 2, 0.043, 0.051, 0.071, 0.98)
        hudScaleBadge.bg:SetAllPoints()
        UI.CreatePixelBorder(hudScaleBadge, 0.165, 0.192, 0.259, 0.95, 3)

        local hudScaleBadgeText = hudScaleBadge:CreateFontString(nil, "OVERLAY")
        hudScaleBadgeText:SetPoint("CENTER", hudScaleBadge, "CENTER", 0, 0)
        UI.SetFont(hudScaleBadgeText, 10, "", 1, 1, 1, 0.98)
        hudScaleBadgeText:SetText("100%")

        local function UpdateHudScaleVisual(val)
            local v = math.max(HUD_SCALE_MIN, math.min(HUD_SCALE_MAX, val or 1.0))
            local pct = (v - HUD_SCALE_MIN) / (HUD_SCALE_MAX - HUD_SCALE_MIN)
            local xOff = pct * HUD_SLIDER_W
            local r, g, b = UI.GetActiveAccentColor()
            hudScaleFill:SetColorTexture(r, g, b, 0.95)
            hudScaleFill:SetWidth(math.max(1, xOff))
            hudScaleThumb:ClearAllPoints()
            hudScaleThumb:SetPoint("CENTER", hudScaleTrack, "LEFT", xOff, 0)
            hudScaleBadgeText:SetText(string.format("%d%%", math.floor(v * 100 + 0.5)))
        end

        hudScaleSliderHit:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                self:SetScript("OnUpdate", function(s)
                    if not IsMouseButtonDown("LeftButton") or InCombatLockdown() then
                        s:SetScript("OnUpdate", nil)
                        return
                    end
                    local eff = hudScaleTrack:GetEffectiveScale()
                    local cx = GetCursorPosition() / eff
                    local left = hudScaleTrack:GetLeft()
                    if left then
                        local pct = math.max(0, math.min(1, (cx - left) / HUD_SLIDER_W))
                        local raw = HUD_SCALE_MIN + pct * (HUD_SCALE_MAX - HUD_SCALE_MIN)
                        local snapped = math.floor(raw * 20 + 0.5) / 20
                        snapped = math.max(HUD_SCALE_MIN, math.min(HUD_SCALE_MAX, snapped))
                        if s._lastSnapped ~= snapped then
                            s._lastSnapped = snapped
                            if math.abs(snapped - GetHudScale(selectedHudTarget)) >= 0.01 then
                                SetHudScale(selectedHudTarget, snapped)
                            end
                            UpdateHudScaleVisual(snapped)
                        end
                    end
                end)
            elseif button == "RightButton" then
                SetHudScale(selectedHudTarget, 1.0)
                m.RefreshState()
            end
        end)
        hudScaleSliderHit:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" then
                self:SetScript("OnUpdate", nil)
                m.RefreshState()
            end
        end)
        hudScaleSliderHit:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
        hudScaleSliderHit:SetScript("OnMouseWheel", function(_, delta)
            local cur = GetHudScale(selectedHudTarget)
            SetHudScale(selectedHudTarget, cur + (delta > 0 and HUD_SCALE_STEP or -HUD_SCALE_STEP))
            m.RefreshState()
        end)

        ------------------------------------------------------------------------
        -- Row 3: Live Appearance Bar (36px tall: Opacity, Border Style, Orientation)
        ------------------------------------------------------------------------
        local inspRow3 = CreateFrame("Frame", nil, m)
        inspRow3:SetPoint("TOPLEFT", inspCard, "BOTTOMLEFT", 0, -1)
        inspRow3:SetPoint("TOPRIGHT", inspCard, "BOTTOMRIGHT", 0, -1)
        inspRow3:SetHeight(36)
        inspRow3.bg = UI.SolidTex(inspRow3, "BACKGROUND", 1, 0.075, 0.086, 0.110, 0.96)
        inspRow3.bg:SetAllPoints()
        UI.CreatePixelBorder(inspRow3, 1, 1, 1, 0.10, 2)
        inspRow3:EnableMouse(true)
        inspRow3:RegisterForDrag("LeftButton")
        inspRow3:SetScript("OnDragStart", function()
            if m.hudSelectorPopup and m.hudSelectorPopup:IsShown() then m.hudSelectorPopup:Hide() end
            m:StartMoving()
        end)
        inspRow3:SetScript("OnDragStop", SaveEditModalPosition)
        m.inspRow3 = inspRow3

        -- 1. Opacity Slider (20% - 100%, step 5%)
        local opaLbl = inspRow3:CreateFontString(nil, "OVERLAY")
        opaLbl:SetPoint("LEFT", inspRow3, "LEFT", 6, 0)
        UI.SetFont(opaLbl, 10, "", 0.78, 0.82, 0.90, 1)
        opaLbl:SetText("Opacity:")

        local OPA_SLIDER_W = 44
        local opaMinusBtn = CreateFlatButton(inspRow3, 18, 22, "-", false)
        TightenCompactButtonLabel(opaMinusBtn, 2)
        opaMinusBtn:SetPoint("LEFT", opaLbl, "RIGHT", 3, 0)
        opaMinusBtn:SetScript("OnClick", function()
            local cur = GetHudOpacity(selectedHudTarget)
            SetHudOpacity(selectedHudTarget, cur - HUD_OPACITY_STEP)
            m.RefreshState()
        end)

        local opaSliderHit = CreateFrame("Frame", nil, inspRow3)
        opaSliderHit:SetSize(OPA_SLIDER_W, 22)
        opaSliderHit:SetPoint("LEFT", opaMinusBtn, "RIGHT", 3, 0)
        opaSliderHit:EnableMouse(true)
        opaSliderHit:EnableMouseWheel(true)

        local opaTrack = UI.SolidTex(opaSliderHit, "ARTWORK", 1, 0.035, 0.039, 0.051, 0.98)
        opaTrack:SetSize(OPA_SLIDER_W, 4)
        opaTrack:SetPoint("CENTER", opaSliderHit, "CENTER", 0, 0)
        UI.CreatePixelBorder(opaSliderHit, 1, 1, 1, 0.0)

        local opaFill = UI.SolidTex(opaSliderHit, "ARTWORK", 2, ar, ag, ab, 0.85)
        opaFill:SetPoint("TOPLEFT", opaTrack, "TOPLEFT", 0, 0)
        opaFill:SetPoint("BOTTOMLEFT", opaTrack, "BOTTOMLEFT", 0, 0)
        opaFill:SetWidth(1)

        local opaThumb = UI.SolidTex(opaSliderHit, "OVERLAY", 4, 0.97, 0.98, 1.00, 1.0)
        opaThumb:SetSize(6, 14)
        if opaThumb.SetSnapToPixelGrid then
            opaThumb:SetSnapToPixelGrid(false)
            opaThumb:SetTexelSnappingBias(0)
        end

        local opaPlusBtn = CreateFlatButton(inspRow3, 18, 22, "+", false)
        TightenCompactButtonLabel(opaPlusBtn, 2)
        opaPlusBtn:SetPoint("LEFT", opaSliderHit, "RIGHT", 3, 0)
        opaPlusBtn:SetScript("OnClick", function()
            local cur = GetHudOpacity(selectedHudTarget)
            SetHudOpacity(selectedHudTarget, cur + HUD_OPACITY_STEP)
            m.RefreshState()
        end)

        local opaBadge = CreateFrame("Frame", nil, inspRow3)
        opaBadge:SetSize(34, 22)
        opaBadge:SetPoint("LEFT", opaPlusBtn, "RIGHT", 3, 0)
        opaBadge.bg = UI.SolidTex(opaBadge, "BACKGROUND", 2, 0.043, 0.051, 0.071, 0.98)
        opaBadge.bg:SetAllPoints()
        UI.CreatePixelBorder(opaBadge, 0.165, 0.192, 0.259, 0.95, 3)

        local opaBadgeText = opaBadge:CreateFontString(nil, "OVERLAY")
        opaBadgeText:SetPoint("CENTER", opaBadge, "CENTER", 0, 0)
        UI.SetFont(opaBadgeText, 10, "", 1, 1, 1, 0.98)
        opaBadgeText:SetText("95%")

        local function UpdateHudOpacityVisual(val)
            local v = SnapHudOpacity(val, selectedHudTarget)
            local pct = (v - HUD_OPACITY_MIN) / (HUD_OPACITY_MAX - HUD_OPACITY_MIN)
            local xOff = pct * OPA_SLIDER_W
            local r, g, b = UI.GetActiveAccentColor()
            opaFill:SetColorTexture(r, g, b, 0.95)
            opaFill:SetWidth(math.max(1, xOff))
            opaThumb:ClearAllPoints()
            opaThumb:SetPoint("CENTER", opaTrack, "LEFT", xOff, 0)
            opaBadgeText:SetText(string.format("%d%%", math.floor(v * 100 + 0.5)))
        end

        opaSliderHit:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                self:SetScript("OnUpdate", function(s)
                    if not IsMouseButtonDown("LeftButton") or InCombatLockdown() then
                        s:SetScript("OnUpdate", nil)
                        return
                    end
                    local eff = opaTrack:GetEffectiveScale()
                    local cx = GetCursorPosition() / eff
                    local left = opaTrack:GetLeft()
                    if left then
                        local pct = math.max(0, math.min(1, (cx - left) / OPA_SLIDER_W))
                        local raw = HUD_OPACITY_MIN + pct * (HUD_OPACITY_MAX - HUD_OPACITY_MIN)
                        local snapped = SnapHudOpacity(raw, selectedHudTarget)
                        if s._lastSnapped ~= snapped then
                            s._lastSnapped = snapped
                            if math.abs(snapped - GetHudOpacity(selectedHudTarget)) >= 0.01 then
                                SetHudOpacity(selectedHudTarget, snapped)
                            end
                            UpdateHudOpacityVisual(snapped)
                        end
                    end
                end)
            elseif button == "RightButton" then
                SetHudOpacity(selectedHudTarget, GetDefaultHudOpacity(selectedHudTarget))
                m.RefreshState()
            end
        end)
        opaSliderHit:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" then
                self:SetScript("OnUpdate", nil)
                m.RefreshState()
            end
        end)
        opaSliderHit:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
        opaSliderHit:SetScript("OnMouseWheel", function(_, delta)
            local cur = GetHudOpacity(selectedHudTarget)
            SetHudOpacity(selectedHudTarget, cur + (delta > 0 and HUD_OPACITY_STEP or -HUD_OPACITY_STEP))
            m.RefreshState()
        end)

        -- 2. Border Style Segmented Pills ([Accent] [Dark] [None]) + [Apply All]
        local bdrLbl = inspRow3:CreateFontString(nil, "OVERLAY")
        bdrLbl:SetPoint("LEFT", opaBadge, "RIGHT", 5, 0)
        UI.SetFont(bdrLbl, 10, "", 0.78, 0.82, 0.90, 1)
        bdrLbl:SetText("Border:")

        local bdrAccentBtn = CreateFlatButton(inspRow3, 42, 22, "Accent", false)
        TightenCompactButtonLabel(bdrAccentBtn, 2)
        if bdrAccentBtn.label then UI.SetFont(bdrAccentBtn.label, 10, "", 1, 1, 1, 0.94) end
        bdrAccentBtn:SetPoint("LEFT", bdrLbl, "RIGHT", 3, 0)
        bdrAccentBtn:SetScript("OnClick", function()
            SetHudBorderStyle(selectedHudTarget, "ACCENT")
            m.RefreshState()
        end)

        local bdrDarkBtn = CreateFlatButton(inspRow3, 34, 22, "Dark", false)
        TightenCompactButtonLabel(bdrDarkBtn, 2)
        if bdrDarkBtn.label then UI.SetFont(bdrDarkBtn.label, 10, "", 1, 1, 1, 0.94) end
        bdrDarkBtn:SetPoint("LEFT", bdrAccentBtn, "RIGHT", 2, 0)
        bdrDarkBtn:SetScript("OnClick", function()
            SetHudBorderStyle(selectedHudTarget, "DARK")
            m.RefreshState()
        end)

        local bdrNoneBtn = CreateFlatButton(inspRow3, 34, 22, "None", false)
        TightenCompactButtonLabel(bdrNoneBtn, 2)
        if bdrNoneBtn.label then UI.SetFont(bdrNoneBtn.label, 10, "", 1, 1, 1, 0.94) end
        bdrNoneBtn:SetPoint("LEFT", bdrDarkBtn, "RIGHT", 2, 0)
        bdrNoneBtn:SetScript("OnClick", function()
            SetHudBorderStyle(selectedHudTarget, "NONE")
            m.RefreshState()
        end)

        local applyAllBtn = CreateFlatButton(inspRow3, 52, 22, "Apply All", false)
        TightenCompactButtonLabel(applyAllBtn, 2)
        if applyAllBtn.label then UI.SetFont(applyAllBtn.label, 10, "", 1, 1, 1, 0.95) end
        applyAllBtn.idleBgColor = { r = 0.043, g = 0.051, b = 0.071, a = 0.98 } -- #0B0D12
        applyAllBtn.idleBorderColor = { r = 0.976, g = 0.451, b = 0.086, a = 0.72 } -- #F97316
        applyAllBtn.idleTextColor = { r = 0.976, g = 0.451, b = 0.086, a = 1.0 }
        ApplyFlatButtonVisual(applyAllBtn, false)
        applyAllBtn:SetPoint("LEFT", bdrNoneBtn, "RIGHT", 5, 0)
        applyAllBtn:SetScript("OnClick", function()
            if InCombatLockdown and InCombatLockdown() then
                print("|cFFF97316DynamicSuite:|r Cannot apply HUD appearance during combat lockdown.")
                return
            end
            local srcKey = (selectedHudTarget == "ALL" or not selectedHudTarget) and "TOAST" or selectedHudTarget
            local curOpa = GetHudOpacity(srcKey)
            local curBdr = GetHudBorderStyle(srcKey)
            for _, k in ipairs({ "TOAST", "PREP", "prepBuffs", "TARGET", "FLARE", "CHAT", "VAULT" }) do
                SetHudOpacity(k, curOpa)
                SetHudBorderStyle(k, curBdr)
            end
            SyncAllEditModeHuds(true)
            m.RefreshState()
            local bdrName = (curBdr == "DARK" and "Dark") or (curBdr == "NONE" and "None") or "Accent"
            print(string.format("|cFFF97316DynamicSuite:|r Applied %d%% opacity and %s border style to all 6 HUDs.", math.floor(curOpa * 100 + 0.5), bdrName))
        end)
        applyAllBtn.OnCustomEnter = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText("Apply Opacity & Border to All HUDs", 1, 1, 1)
            GameTooltip:AddLine("Copies this HUD's current Opacity and Border Style to all 6 DynamicSuite HUDs (Alert Toast, Prep Bar, Raid Buffs, Focus Icons, World Flares, and Chat Frame).", 0.82, 0.86, 0.92, true)
            GameTooltip:Show()
        end
        applyAllBtn.OnCustomLeave = function()
            if GameTooltip then GameTooltip:Hide() end
        end

        -- 3. Orientation Segmented Pills ([Horiz] [Vert]) anchored cleanly at right
        local orientVertBtn = CreateFlatButton(inspRow3, 34, 22, "Vert", false)
        TightenCompactButtonLabel(orientVertBtn, 2)
        if orientVertBtn.label then UI.SetFont(orientVertBtn.label, 10, "", 1, 1, 1, 0.94) end
        orientVertBtn:SetPoint("RIGHT", inspRow3, "RIGHT", -6, 0)
        orientVertBtn:SetScript("OnClick", function()
            if not DoesHudSupportOrientation(selectedHudTarget) then return end
            SetHudOrientation(selectedHudTarget, "VERTICAL")
            m.RefreshState()
        end)

        local orientHorizBtn = CreateFlatButton(inspRow3, 38, 22, "Horiz", false)
        TightenCompactButtonLabel(orientHorizBtn, 2)
        if orientHorizBtn.label then UI.SetFont(orientHorizBtn.label, 10, "", 1, 1, 1, 0.94) end
        orientHorizBtn:SetPoint("RIGHT", orientVertBtn, "LEFT", -2, 0)
        orientHorizBtn:SetScript("OnClick", function()
            if not DoesHudSupportOrientation(selectedHudTarget) then return end
            SetHudOrientation(selectedHudTarget, "HORIZONTAL")
            m.RefreshState()
        end)

        local orientLbl = inspRow3:CreateFontString(nil, "OVERLAY")
        orientLbl:SetPoint("RIGHT", orientHorizBtn, "LEFT", -3, 0)
        UI.SetFont(orientLbl, 10, "", 0.78, 0.82, 0.90, 1)
        orientLbl:SetText("Orient:")

        local function OnOrientButtonEnter(selfBtn)
            if not DoesHudSupportOrientation(selectedHudTarget) and GameTooltip then
                GameTooltip:SetOwner(selfBtn, "ANCHOR_BOTTOM")
                GameTooltip:SetText("Fixed Horizontal Layout", 1, 1, 1)
                GameTooltip:AddLine("This HUD uses a fixed horizontal layout and cannot be rotated vertically.", 0.78, 0.82, 0.88, true)
                GameTooltip:Show()
            end
        end
        local function OnOrientButtonLeave()
            if GameTooltip then GameTooltip:Hide() end
        end
        orientHorizBtn.OnCustomEnter = OnOrientButtonEnter
        orientHorizBtn.OnCustomLeave = OnOrientButtonLeave
        orientVertBtn.OnCustomEnter = OnOrientButtonEnter
        orientVertBtn.OnCustomLeave = OnOrientButtonLeave

        m.inspRow3 = inspRow3
        m.opaSliderHit = opaSliderHit
        m.opaBadgeText = opaBadgeText
        m.bdrAccentBtn = bdrAccentBtn
        m.bdrDarkBtn = bdrDarkBtn
        m.bdrNoneBtn = bdrNoneBtn
        m.applyAllBtn = applyAllBtn
        m.orientHorizBtn = orientHorizBtn
        m.orientVertBtn = orientVertBtn

        ------------------------------------------------------------------------
        -- Modal State Refresh & External Coordination
        ------------------------------------------------------------------------
        m.UpdateLiveCoordReadout = function(lx, ly)
            if xCoordBox and yCoordBox then
                if not (xCoordBox:HasFocus() or yCoordBox:HasFocus()) then
                    xCoordBox:SetText(string.format("%d", math.floor((lx or 0) + 0.5)))
                    yCoordBox:SetText(string.format("%d", math.floor((ly or 0) + 0.5)))
                end
            end
        end

        m.RefreshState = function()
            local r, g, b = UI.GetActiveAccentColor()
            local accentCol = { r = r, g = g, b = b }
            local surf = UI.GetActiveSurfaceColors()

            ApplyEditModalClampInsets(m)
            m.bg:SetColorTexture(surf.panel.r, surf.panel.g, surf.panel.b, 0.98)
            m.dsBorder:SetColor(r, g, b, 0.95)
            mHdr.bg:SetColorTexture(surf.header.r, surf.header.g, surf.header.b, 1.0)
            if mHdrDiv then mHdrDiv:SetColorTexture(r, g, b, 0.35) end
            if mHdr.logo and mHdr.logo.SetAccentColor then
                mHdr.logo:SetAccentColor(r, g, b, 1)
            end
            if mHdr.backBtn then
                mHdr.backBtn:SetSelected(true, accentCol)
            end
            inspCard.bg:SetColorTexture(surf.card.r, surf.card.g, surf.card.b, 0.96)
            if inspRow3 and inspRow3.bg then
                inspRow3.bg:SetColorTexture(surf.card.r, surf.card.g, surf.card.b, 0.96)
            end

            if selectedHudTarget == "CHAT" and not IsChatHudTargetOwned() then
                selectedHudTarget = SelectDefaultVisibleHudTarget()
            end

            if hudSelectorBtn and hudSelectorBtn.label then
                local meta = hudTargetMeta[selectedHudTarget] or hudTargetMeta["TOAST"]
                local modActive = IsHudParentModuleActive(selectedHudTarget)
                local isVis = modActive and GetHudVisibility(selectedHudTarget)
                hudSelectorBtn.label:SetText(meta.label or tostring(selectedHudTarget))
                if hudSelectorBtn.visDot then
                    hudSelectorBtn.visDot:SetColorTexture(isVis and 0.133 or 0.937, isVis and 0.773 or 0.267, isVis and 0.369 or 0.267, 1.0)
                end
                ApplyFlatButtonVisual(hudSelectorBtn, hudSelectorBtn:IsMouseOver())
            end

            for _, abtn in ipairs(arrowBtns) do
                if abtn.RefreshAccent then abtn:RefreshAccent() end
            end

            local _, _, cx, cy = GetStoredHudPos(selectedHudTarget == "ALL" and "TOAST" or selectedHudTarget)
            m.UpdateLiveCoordReadout(cx or 0, cy or 0)
            UpdateHudVisSwitch()

            if showGridBtn then
                local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
                local isGridOn = (gTbl.hudShowGrid ~= false)
                showGridBtn:SetSelected(isGridOn, accentCol)
            end

            UpdateHudScaleVisual(GetHudScale(selectedHudTarget))
            UpdateHudOpacityVisual(GetHudOpacity(selectedHudTarget))

            local curBdr = GetHudBorderStyle(selectedHudTarget)
            bdrAccentBtn:SetSelected(curBdr == "ACCENT", accentCol)
            bdrDarkBtn:SetSelected(curBdr == "DARK", accentCol)
            bdrNoneBtn:SetSelected(curBdr == "NONE", accentCol)

            local orientSupported = DoesHudSupportOrientation(selectedHudTarget)
            local curOrient = GetHudOrientation(selectedHudTarget)
            if orientSupported then
                orientLbl:SetAlpha(1.0)
                orientHorizBtn:SetAlpha(1.0)
                orientVertBtn:SetAlpha(1.0)
                orientHorizBtn:SetSelected(curOrient == "HORIZONTAL", accentCol)
                orientVertBtn:SetSelected(curOrient == "VERTICAL", accentCol)
            else
                orientLbl:SetAlpha(0.38)
                orientHorizBtn:SetSelected(true, accentCol)
                orientVertBtn:SetSelected(false, accentCol)
                orientHorizBtn:SetAlpha(0.38)
                orientVertBtn:SetAlpha(0.38)
            end

            if not rowResetConfirmPending then
                rowResetBtn.label:SetText("Reset")
                rowResetBtn:SetSelected(false)
            end
        end

        m.targetDropdown = {
            RefreshValue = function()
                if m.RefreshState then m.RefreshState() end
            end,
            SetValue = function(_, val)
                if val and hudTargetMeta[val] and addonTable.OnHudTargetSelected then
                    addonTable.OnHudTargetSelected(val)
                end
            end,
        }

        editModeInspectorModal = m
        return editModeInspectorModal
    end

    addonTable.OnHudTargetSelected = function(targetKey)
        if targetKey == "CHAT" and not IsChatHudTargetOwned() then
            targetKey = SelectDefaultVisibleHudTarget()
        end
        if targetKey and hudTargetMeta[targetKey] then
            selectedHudTarget = targetKey
            addonTable.selectedHudTarget = selectedHudTarget
            if not IsHudNormallyShown(targetKey) then
                explicitlyPreviewedHiddenHud = targetKey
            else
                explicitlyPreviewedHiddenHud = nil
            end
            SyncAllEditModeHuds(true)
            if editModeInspectorModal and editModeInspectorModal.RefreshState then
                editModeInspectorModal.RefreshState()
            end
        end
    end

    addonTable.OnToastPositionChanged = function()
        if editModeInspectorModal and editModeInspectorModal:IsShown() and editModeInspectorModal.RefreshState then
            SyncAllEditModeHuds(true)
            editModeInspectorModal.RefreshState()
        end
    end

    function addonTable.EnterHudEditMode(selfOrKey, maybeKey)
        if InCombatLockdown() then
            print("|cFFCBD5E1DynamicSuite:|r HUD Edit Mode cannot be opened during combat.")
            return
        end
        if not mainFrame or not mainFrame._initComplete then
            addonTable.CreateMainConfigUI()
        end
        isHudEditModeActive = true
        addonTable._isHudEditModeActive = true
        addonTable.GetHudSnapMode = GetActiveSnapMode
        EnsureAllEditModeHudFramesInitialized()
        local rawKey = (type(selfOrKey) == "table") and maybeKey or selfOrKey
        local normKey = type(rawKey) == "string" and rawKey:upper() or nil
        local explicitFromCard = (rawKey ~= nil and rawKey ~= "" and normKey ~= "ALL")
        if type(rawKey) == "string" and hudTargetMeta[rawKey] then
            selectedHudTarget = rawKey
        elseif normKey == "PREPBUFFS" then
            selectedHudTarget = "prepBuffs"
        elseif normKey and hudTargetMeta[normKey] then
            selectedHudTarget = normKey
        else
            selectedHudTarget = SelectDefaultVisibleHudTarget()
        end
        if selectedHudTarget == "CHAT" and not IsChatHudTargetOwned() then
            selectedHudTarget = SelectDefaultVisibleHudTarget()
        end
        if explicitFromCard and not IsHudNormallyShown(selectedHudTarget) then
            explicitlyPreviewedHiddenHud = selectedHudTarget
        else
            explicitlyPreviewedHiddenHud = nil
        end
        UI.CloseAllPopups()
        if f.minimizedBar then f.minimizedBar:Hide() end
        addonTable.selectedHudTarget = selectedHudTarget
        f._minimizedForHudDrag = true
        f:Hide()
        local modal = EnsureEditModeInspectorModal()
        modal:SetFrameStrata("DIALOG")
        modal:SetFrameLevel(200)
        modal._isCollapsed = false
        modal:SetSize(560, 110)
        if modal.hudSelectorPopup then modal.hudSelectorPopup:Hide() end
        if modal.inspCard then modal.inspCard:Show() end
        if modal.inspRow3 then modal.inspRow3:Show() end
        if modal.RestoreSavedPosition then modal:RestoreSavedPosition() end
        IngestLiveHudPositions()
        SyncAllEditModeHuds(true)
        modal.RefreshState()
        modal:Show()
    end

    function addonTable.ExitHudEditMode(reopenMain)
        if isExitingHudEditMode then return end
        isExitingHudEditMode = true
        isHudEditModeActive = false
        explicitlyPreviewedHiddenHud = nil
        addonTable._isHudEditModeActive = false
        HideSnapGuides()
        f._minimizedForHudDrag = false
        if _G.DynamicMarker then
            _G.DynamicMarker._previewHiddenMoverKey = nil
        end
        if editModeInspectorModal then
            if editModeInspectorModal.hudSelectorPopup and editModeInspectorModal.hudSelectorPopup:IsShown() then
                editModeInspectorModal.hudSelectorPopup:Hide()
            end
            if editModeInspectorModal:IsShown() then
                editModeInspectorModal:Hide()
            end
        end
        SyncAllEditModeHuds(false)
        if snapGridOverlay and snapGridOverlay:IsShown() then
            snapGridOverlay:Hide()
        end
        if _G.DynamicSuiteSnapGridOverlay and _G.DynamicSuiteSnapGridOverlay:IsShown() then
            _G.DynamicSuiteSnapGridOverlay:Hide()
        end
        if _G.DynamicSuiteGridOverlay and _G.DynamicSuiteGridOverlay:IsShown() then
            _G.DynamicSuiteGridOverlay:Hide()
        end
        if _G.DynamicMarkerEditModeInspector and _G.DynamicMarkerEditModeInspector:IsShown() then
            _G.DynamicMarkerEditModeInspector:Hide()
        end
        if _G.DynamicMarker and _G.DynamicMarker.SetEditMode and _G.DynamicMarker.isEditMode then
            pcall(_G.DynamicMarker.SetEditMode, _G.DynamicMarker, false, { fromSuite = true, fromCombat = InCombatLockdown() })
        end
        if _G.DynamicPrep and _G.DynamicPrep.SetEditMode then
            pcall(_G.DynamicPrep.SetEditMode, _G.DynamicPrep, false)
        end
        if _G.DynamicLoadToastFrame then
            _G.DynamicLoadToastFrame:StopMovingOrSizing()
            _G.DynamicLoadToastFrame.isEditingMode = false
            _G.DynamicLoadToastFrame.isDraggingMode = false
            if not InCombatLockdown() then
                if _G.DynamicLoadToastFrame.SetClampedToScreen then
                    _G.DynamicLoadToastFrame:SetClampedToScreen(true)
                end
                if not _G.DynamicLoadToastFrame.isRealAlert then
                    _G.DynamicLoadToastFrame:Hide()
                end
            end
            _G.DynamicLoadToastFrame:SetAlpha(1)
        end
        if reopenMain == true and not InCombatLockdown() then
            f:Show()
            if activeWorkspaceView == "EDIT_MODE" then
                addonTable.OpenWorkspaceView("DYNAMICLOAD")
            end
        end
        isExitingHudEditMode = false
    end

    _G.DynamicSuite = _G.DynamicSuite or {}
    _G.DynamicSuite.EnterHudEditMode          = addonTable.EnterHudEditMode
    _G.DynamicSuite.EnterEditMode             = addonTable.EnterHudEditMode
    _G.DynamicSuite.ExitHudEditMode           = addonTable.ExitHudEditMode
    _G.DynamicSuite.GetHudSnapMode            = GetActiveSnapMode
    _G.DynamicSuite.GetActiveHudFrames        = CollectAllActiveHudFrames
    _G.DynamicSuite.ResetAllHudPositions      = function(silent)
        if addonTable.ResetAllHudPositions then
            return addonTable.ResetAllHudPositions(silent)
        end
        return false
    end
    _G.DynamicSuite.ClampAllHudPositions      = function()
        if addonTable.ClampAllSuiteHudsToScreen then
            return addonTable.ClampAllSuiteHudsToScreen()
        end
    end
    _G.DynamicSuite.NotifyExternalHudSelected = addonTable.OnHudTargetSelected
    _G.DynamicSuite.NotifyExternalHudCoords   = function(targetKey, _, lx, ly)
        if (targetKey == selectedHudTarget or selectedHudTarget == "ALL") and editModeInspectorModal and editModeInspectorModal.UpdateLiveCoordReadout then
            editModeInspectorModal.UpdateLiveCoordReadout(lx, ly)
        end
    end
    _G.DynamicSuite.NotifyExternalHudChanged  = function()
        if editModeInspectorModal and editModeInspectorModal:IsShown() and editModeInspectorModal.RefreshState then
            editModeInspectorModal.RefreshState()
        end
    end
    if _G.DynamicLoad or addonTable.IsDynamicLoadModuleLoaded then
        _G.DynamicLoad = _G.DynamicLoad or {}
        _G.DynamicLoad.EnterHudEditMode  = addonTable.EnterHudEditMode
        _G.DynamicLoad.EnterEditMode     = addonTable.EnterHudEditMode
        _G.DynamicLoad.ExitHudEditMode   = addonTable.ExitHudEditMode
    end

    editView.Refresh = function()
        addonTable.EnterHudEditMode(selectedHudTarget)
    end
    end

    ----------------------------------------------------------------------------
    -- VIEW H: FEATURE FINDER & SMART SEARCH WORKSPACE ("SEARCH_VIEW")
    ----------------------------------------------------------------------------
    do
    local searchView = CreateFrame("Frame", nil, workspace)
    searchView:SetAllPoints()
    searchView:SetFrameLevel((workspace:GetFrameLevel() or 6) + 2)
    if searchView.SetClipsChildren then searchView:SetClipsChildren(false) end
    searchView:Hide()
    f.searchView = searchView

    local activeSearchCategory = "ALL"
    local SEARCH_CATEGORIES = addonTable.SEARCH_CATEGORIES or {
        { key = "ALL",        label = "All" },
        { key = "COMBAT",     label = "Combat & Raid" },
        { key = "FPS_CAM",    label = "FPS & Camera" },
        { key = "HUD_LOOK",   label = "HUD & Look" },
        { key = "BAGS_QOL",   label = "Bags & QoL" },
        { key = "GROUP_CHAT", label = "Group & Chat" },
    }

    -- Shared 1-Click Jump & Accent Pulse Highlight Engine
    local highlightFrame = nil
    local function EnsureSearchHighlightFrame()
        if highlightFrame then return highlightFrame end
        highlightFrame = CreateFrame("Frame", "DynamicSuiteSearchHighlightFrame", UIParent)
        highlightFrame:SetFrameStrata("DIALOG")
        highlightFrame:Hide()

        local glowBg = UI.SolidTex(highlightFrame, "BACKGROUND", 0, 0, 0, 0, 0)
        glowBg:SetAllPoints()
        highlightFrame.glowBg = glowBg

        local bTop = UI.SolidTex(highlightFrame, "OVERLAY", 2, 0, 0, 0, 0)
        bTop:SetPoint("TOPLEFT", highlightFrame, "TOPLEFT", 0, 0)
        bTop:SetPoint("TOPRIGHT", highlightFrame, "TOPRIGHT", 0, 0)
        bTop:SetHeight(2)

        local bBot = UI.SolidTex(highlightFrame, "OVERLAY", 2, 0, 0, 0, 0)
        bBot:SetPoint("BOTTOMLEFT", highlightFrame, "BOTTOMLEFT", 0, 0)
        bBot:SetPoint("BOTTOMRIGHT", highlightFrame, "BOTTOMRIGHT", 0, 0)
        bBot:SetHeight(2)

        local bLeft = UI.SolidTex(highlightFrame, "OVERLAY", 2, 0, 0, 0, 0)
        bLeft:SetPoint("TOPLEFT", highlightFrame, "TOPLEFT", 0, -2)
        bLeft:SetPoint("BOTTOMLEFT", highlightFrame, "BOTTOMLEFT", 0, 2)
        bLeft:SetWidth(2)

        local bRight = UI.SolidTex(highlightFrame, "OVERLAY", 2, 0, 0, 0, 0)
        bRight:SetPoint("TOPRIGHT", highlightFrame, "TOPRIGHT", 0, -2)
        bRight:SetPoint("BOTTOMRIGHT", highlightFrame, "BOTTOMRIGHT", 0, 2)
        bRight:SetWidth(2)

        highlightFrame.borders = { bTop, bBot, bLeft, bRight }
        highlightFrame._elapsed = 0

        highlightFrame:SetScript("OnUpdate", function(self, dt)
            self._elapsed = (self._elapsed or 0) + (dt or 0.016)
            local t = self._elapsed
            local duration = 2.25
            local target = self._targetCard
            if t >= duration or not target or not target:IsVisible() then
                self:Hide()
                self._targetCard = nil
                return
            end
            local ar, ag, ab = UI.GetActiveAccentColor()
            local borderAlpha, fillAlpha
            if t < 0.70 then
                local wave = 0.75 + 0.25 * math.sin((t / 0.70) * math.pi * 2.0)
                borderAlpha = wave
                fillAlpha = 0.20 * wave
            else
                local rem = math.max(0, 1.0 - ((t - 0.70) / (duration - 0.70)))
                local ease = rem * rem
                borderAlpha = ease
                fillAlpha = 0.16 * ease
            end
            self.glowBg:SetColorTexture(ar, ag, ab, fillAlpha)
            for _, b in ipairs(self.borders) do
                b:SetColorTexture(ar, ag, ab, borderAlpha)
            end
        end)

        return highlightFrame
    end

    local function StripWoWMarkup(str)
        if type(str) ~= "string" then return "" end
        local clean = str:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
        clean = clean:gsub("^%s+", ""):gsub("%s+$", "")
        return clean:lower()
    end

    local function FindMatchingCardFrame(root, targetNeedle)
        if not root or type(targetNeedle) ~= "string" or targetNeedle == "" then
            return nil
        end
        local needle = StripWoWMarkup(targetNeedle)
        if needle == "" then return nil end

        local bestCard = nil
        local bestScore = 0
        local bestHiddenReg = nil
        local bestHiddenScore = 0

        local function ResolveCardContainer(fontRegion)
            local curr = fontRegion:GetParent()
            local fallback = curr
            local hops = 0
            while curr and curr ~= root and curr ~= workspace and curr ~= UIParent and hops < 7 do
                hops = hops + 1
                local objType = curr.GetObjectType and curr:GetObjectType() or ""
                if objType == "ScrollFrame" then
                    break
                end
                local p = curr:GetParent()
                local pType = (p and p.GetObjectType) and p:GetObjectType() or ""
                local h = (curr.GetHeight and curr:GetHeight()) or 0
                local w = (curr.GetWidth and curr:GetWidth()) or 0
                local hasCardChrome = curr.dsBorder or curr.bg or (curr.GetBackdrop and curr:GetBackdrop())
                if hasCardChrome and h >= 22 and h <= 460 and w >= 140 then
                    return curr
                end
                if pType == "ScrollFrame" then
                    break
                end
                if p and p.GetParent and p:GetParent() and p:GetParent().GetObjectType and p:GetParent():GetObjectType() == "ScrollFrame" then
                    if h >= 22 and h <= 460 then
                        return curr
                    end
                end
                curr = p
            end
            return fallback
        end

        local function WalkFrame(frame, depth)
            if not frame or depth > 14 then return end
            if frame.GetRegions then
                local numRegions = select("#", frame:GetRegions())
                for i = 1, numRegions do
                    local reg = select(i, frame:GetRegions())
                    if reg and reg.GetObjectType and reg:GetObjectType() == "FontString" and reg.GetText then
                        local rawTxt = reg:GetText()
                        if type(rawTxt) == "string" and rawTxt ~= "" and not (issecretvalue and issecretvalue(rawTxt)) then
                            local txt = StripWoWMarkup(rawTxt)
                            if txt ~= "" then
                                local matchScore = 0
                                if txt == needle then
                                    matchScore = 100
                                elseif txt:find(needle, 1, true) == 1 then
                                    matchScore = 85
                                elseif txt:find(needle, 1, true) then
                                    matchScore = 65
                                elseif needle:find(txt, 1, true) and #txt >= 6 then
                                    matchScore = 45
                                end
                                if matchScore > 0 then
                                    if frame:IsVisible() and matchScore > bestScore then
                                        local candidate = ResolveCardContainer(reg)
                                        if candidate and candidate:IsVisible() then
                                            bestScore = matchScore
                                            bestCard = candidate
                                        end
                                    elseif matchScore > bestHiddenScore then
                                        bestHiddenScore = matchScore
                                        bestHiddenReg = reg
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if frame.GetChildren then
                local numChildren = select("#", frame:GetChildren())
                for i = 1, numChildren do
                    local child = select(i, frame:GetChildren())
                    if child then
                        WalkFrame(child, depth + 1)
                    end
                end
            end
        end

        WalkFrame(root, 1)
        if not bestCard and bestHiddenReg then
            local anc = bestHiddenReg:GetParent()
            local hops = 0
            while anc and anc ~= root and anc ~= workspace and anc ~= UIParent and hops < 8 do
                hops = hops + 1
                if anc.Show and not anc:IsShown() then
                    anc:Show()
                end
                anc = anc:GetParent()
            end
            if UI.NormalizeEmbeddedSubDrawers then
                pcall(UI.NormalizeEmbeddedSubDrawers, root)
            end
            bestCard = ResolveCardContainer(bestHiddenReg)
        end
        return bestCard
    end

    local function ScrollCardIntoView(cardFrame, root)
        if not cardFrame then return end
        local curr = cardFrame:GetParent()
        local scrollFrame = nil
        local scrollChild = nil
        local hops = 0
        while curr and curr ~= root and curr ~= UIParent and hops < 10 do
            hops = hops + 1
            local p = curr:GetParent()
            if p and p.GetObjectType and p:GetObjectType() == "ScrollFrame" and p.SetVerticalScroll then
                scrollFrame = p
                scrollChild = curr
                break
            end
            curr = p
        end
        if not scrollFrame or not scrollChild then return end
        if scrollFrame.UpdateScrollChildRect then
            pcall(scrollFrame.UpdateScrollChildRect, scrollFrame)
        end
        local childTop = scrollChild.GetTop and scrollChild:GetTop()
        local cardTop = cardFrame.GetTop and cardFrame:GetTop()
        if not childTop or not cardTop then return end
        local rawOffset = (childTop - cardTop) - 24
        local maxRange = (scrollFrame.GetVerticalScrollRange and scrollFrame:GetVerticalScrollRange()) or 0
        if maxRange < 0 then maxRange = 0 end
        local targetScroll = math.max(0, math.min(maxRange, rawOffset))
        scrollFrame:SetVerticalScroll(targetScroll)
        local onVert = scrollFrame:GetScript("OnVerticalScroll")
        if type(onVert) == "function" then
            pcall(onVert, scrollFrame, targetScroll)
        end
    end

    function UI.JumpAndHighlightCard(rootFrame, targetTitle)
        local searchRoot = rootFrame or workspace
        if not searchRoot or not searchRoot:IsShown() then return end
        if UI.NormalizeEmbeddedSubDrawers then
            pcall(UI.NormalizeEmbeddedSubDrawers, searchRoot)
        end
        local cardFrame = FindMatchingCardFrame(searchRoot, targetTitle)
        if not cardFrame then return end
        ScrollCardIntoView(cardFrame, searchRoot)
        local hl = EnsureSearchHighlightFrame()
        hl._targetCard = cardFrame
        hl._elapsed = 0
        hl:SetParent(cardFrame)
        hl:ClearAllPoints()
        hl:SetPoint("TOPLEFT", cardFrame, "TOPLEFT", -2, 2)
        hl:SetPoint("BOTTOMRIGHT", cardFrame, "BOTTOMRIGHT", 2, -2)
        hl:SetFrameLevel((cardFrame:GetFrameLevel() or 10) + 12)
        hl:Show()
    end
    addonTable.JumpAndHighlightCard = UI.JumpAndHighlightCard

    -- Top Header & Category Filter Strip
    local hdrStrip = CreateFrame("Frame", nil, searchView)
    hdrStrip:SetPoint("TOPLEFT", searchView, "TOPLEFT", 16, -12)
    hdrStrip:SetPoint("TOPRIGHT", searchView, "TOPRIGHT", -16, -12)
    hdrStrip:SetHeight(58)

    local finderTitle = hdrStrip:CreateFontString(nil, "OVERLAY")
    UI.SetFont(finderTitle, 12, "", UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 1)
    finderTitle:SetPoint("TOPLEFT", hdrStrip, "TOPLEFT", 0, -2)
    finderTitle:SetText("GLOBAL FEATURE FINDER")

    local finderCountLabel = hdrStrip:CreateFontString(nil, "OVERLAY")
    UI.SetFont(finderCountLabel, 10, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 1)
    finderCountLabel:SetPoint("TOPRIGHT", hdrStrip, "TOPRIGHT", -2, -3)
    finderCountLabel:SetJustifyH("RIGHT")
    finderCountLabel:SetText("")

    local clearFilterBtn = CreateFlatButton(hdrStrip, 84, 18, "Clear Search", false)
    clearFilterBtn:SetPoint("RIGHT", finderCountLabel, "LEFT", -10, 0)
    clearFilterBtn:Hide()

    local catPillButtons = {}
    local catStrip = CreateFrame("Frame", nil, hdrStrip)
    catStrip:SetPoint("TOPLEFT", hdrStrip, "TOPLEFT", 0, -24)
    catStrip:SetPoint("TOPRIGHT", hdrStrip, "TOPRIGHT", 0, -24)
    catStrip:SetHeight(24)

    -- Results ScrollFrame + Obsidian Scrollbar
    local resultsScroll = CreateFrame("ScrollFrame", nil, searchView)
    resultsScroll:SetPoint("TOPLEFT", hdrStrip, "BOTTOMLEFT", 0, -4)
    resultsScroll:SetPoint("BOTTOMRIGHT", searchView, "BOTTOMRIGHT", -24, 12)
    resultsScroll:EnableMouseWheel(true)

    local resultsChild = CreateFrame("Frame", nil, resultsScroll)
    resultsChild:SetSize(740, 400)
    resultsScroll:SetScrollChild(resultsChild)

    local resultsTrack = CreateFrame("Frame", nil, searchView)
    resultsTrack:SetPoint("TOPLEFT", resultsScroll, "TOPRIGHT", 4, 0)
    resultsTrack:SetPoint("BOTTOMLEFT", resultsScroll, "BOTTOMRIGHT", 4, 0)
    resultsTrack:SetWidth(6)
    resultsTrack:EnableMouse(true)
    resultsTrack:EnableMouseWheel(true)
    resultsTrack.bg = UI.SolidTex(resultsTrack, "BACKGROUND", 0, 0.05, 0.06, 0.08, 0.85)
    resultsTrack.bg:SetAllPoints()

    local resultsThumb = CreateFrame("Button", nil, resultsTrack)
    resultsThumb:SetWidth(6)
    resultsThumb:SetHeight(48)
    resultsThumb:SetPoint("TOP", resultsTrack, "TOP", 0, 0)
    resultsThumb:EnableMouse(true)
    resultsThumb:EnableMouseWheel(true)
    resultsThumb.tex = UI.SolidTex(resultsThumb, "ARTWORK", 1, 0.28, 0.34, 0.44, 0.85)
    resultsThumb.tex:SetAllPoints()

    local isDraggingSearchThumb = false
    local function RefreshSearchThumbVisual()
        if isDraggingSearchThumb or resultsThumb:IsMouseOver() then
            local ar, ag, ab = UI.GetActiveAccentColor()
            resultsThumb.tex:SetColorTexture(ar, ag, ab, 1.0)
        else
            resultsThumb.tex:SetColorTexture(0.28, 0.34, 0.44, 0.85)
        end
    end

    local function UpdateSearchScrollThumb()
        local maxRange = resultsScroll:GetVerticalScrollRange() or 0
        local trackH = resultsTrack:GetHeight() or 300
        if maxRange <= 0.5 then
            resultsThumb:Hide()
            return
        end
        resultsThumb:Show()
        local viewH = resultsScroll:GetHeight() or 300
        local totalH = viewH + maxRange
        local thumbH = math.max(28, math.min(trackH, math.floor((viewH / math.max(1, totalH)) * trackH)))
        resultsThumb:SetHeight(thumbH)
        local curScroll = resultsScroll:GetVerticalScroll() or 0
        local pct = math.max(0, math.min(1, curScroll / maxRange))
        local yOfs = -pct * math.max(0, trackH - thumbH)
        resultsThumb:ClearAllPoints()
        resultsThumb:SetPoint("TOP", resultsTrack, "TOP", 0, yOfs)
        RefreshSearchThumbVisual()
    end

    local function ScrollSearchResultsFromCursor()
        if isDraggingSearchThumb and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            isDraggingSearchThumb = false
            resultsThumb:SetScript("OnUpdate", nil)
            RefreshSearchThumbVisual()
            return
        end
        local maxRange = resultsScroll:GetVerticalScrollRange() or 0
        if maxRange <= 0 then return end
        local scale = resultsTrack:GetEffectiveScale()
        local _, cy = GetCursorPosition()
        cy = cy / scale
        local top = resultsTrack:GetTop()
        local trackH = resultsTrack:GetHeight()
        local thumbH = resultsThumb:GetHeight() or 32
        if top and trackH and trackH > thumbH then
            local pct = math.max(0, math.min(1, (top - cy - (thumbH * 0.5)) / (trackH - thumbH)))
            resultsScroll:SetVerticalScroll(pct * maxRange)
            UpdateSearchScrollThumb()
        end
    end

    resultsThumb:SetScript("OnEnter", RefreshSearchThumbVisual)
    resultsThumb:SetScript("OnLeave", RefreshSearchThumbVisual)
    resultsThumb:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            isDraggingSearchThumb = true
            RefreshSearchThumbVisual()
            self:SetScript("OnUpdate", ScrollSearchResultsFromCursor)
        end
    end)
    resultsThumb:SetScript("OnMouseUp", function(self)
        isDraggingSearchThumb = false
        self:SetScript("OnUpdate", nil)
        RefreshSearchThumbVisual()
    end)
    resultsThumb:SetScript("OnHide", function(self)
        isDraggingSearchThumb = false
        self:SetScript("OnUpdate", nil)
        RefreshSearchThumbVisual()
    end)
    resultsTrack:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            ScrollSearchResultsFromCursor()
        end
    end)

    local function OnSearchMouseWheel(_, delta)
        local cur = resultsScroll:GetVerticalScroll() or 0
        local maxRange = resultsScroll:GetVerticalScrollRange() or 0
        local nextVal = math.max(0, math.min(maxRange, cur - (delta * 44)))
        resultsScroll:SetVerticalScroll(nextVal)
        UpdateSearchScrollThumb()
    end
    resultsScroll:SetScript("OnMouseWheel", OnSearchMouseWheel)
    resultsTrack:SetScript("OnMouseWheel", OnSearchMouseWheel)
    resultsThumb:SetScript("OnMouseWheel", OnSearchMouseWheel)
    resultsScroll:SetScript("OnVerticalScroll", function()
        UpdateSearchScrollThumb()
    end)
    resultsScroll:SetScript("OnSizeChanged", function(self, w)
        if w and w > 40 then
            resultsChild:SetWidth(w)
        end
        UpdateSearchScrollThumb()
    end)

    -- Empty State Card with 1-Click Suggested Queries
    local emptyCard = CreateFrame("Frame", nil, resultsChild)
    emptyCard:SetSize(700, 174)
    emptyCard.bg = UI.SolidTex(emptyCard, "BACKGROUND", 0, UI.COLORS.CARD_BG.r, UI.COLORS.CARD_BG.g, UI.COLORS.CARD_BG.b, 0.96)
    emptyCard.bg:SetAllPoints()
    UI.CreatePixelBorder(emptyCard, 0.15, 0.18, 0.24, 0.88, 2)
    emptyCard:SetPoint("TOPLEFT", resultsChild, "TOPLEFT", 0, -8)
    emptyCard:SetPoint("TOPRIGHT", resultsChild, "TOPRIGHT", 0, -8)
    emptyCard:Hide()

    local emptyTitle = emptyCard:CreateFontString(nil, "OVERLAY")
    UI.SetFont(emptyTitle, 13, "", 1, 1, 1, 1)
    emptyTitle:SetPoint("TOP", emptyCard, "TOP", 0, -24)
    emptyTitle:SetText("No matching settings or features found")

    local emptySub = emptyCard:CreateFontString(nil, "OVERLAY")
    UI.SetFont(emptySub, 10, "", UI.COLORS.TEXT_DIM.r, UI.COLORS.TEXT_DIM.g, UI.COLORS.TEXT_DIM.b, 1)
    emptySub:SetPoint("TOP", emptyTitle, "BOTTOM", 0, -8)
    emptySub:SetWidth(580)
    emptySub:SetJustifyH("CENTER")
    emptySub:SetText("Try searching by plain-English problem (e.g. 'whisper sound', 'lag in raid', 'repair gear', 'focus interrupt') or click a popular feature below:")

    local SUGGESTED_QUERIES = {
        "Auto-Repair",
        "Whisper Sound",
        "Max Zoom",
        "Interrupt Macro",
        "OCE Filter",
        "Skip Cutscenes",
    }
    local suggestionBtns = {}
    for idx, qText in ipairs(SUGGESTED_QUERIES) do
        local sBtn = CreateFlatButton(emptyCard, 104, 24, qText, false)
        local totalW = (#SUGGESTED_QUERIES * 104) + ((#SUGGESTED_QUERIES - 1) * 8)
        local startX = -math.floor(totalW / 2) + ((idx - 1) * 112) + 52
        sBtn:SetPoint("TOP", emptySub, "BOTTOM", startX, -18)
        sBtn:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
            activeSearchCategory = "ALL"
            if f.railSearchBox then
                f.railSearchBox:SetText(qText)
                f.railSearchBox:ClearFocus()
            end
            if searchView.Refresh then
                searchView.Refresh()
            end
        end)
        suggestionBtns[idx] = sBtn
    end

    -- 1-Click Result Activation & Module/Tab/Highlight Router
    local function ActivateSearchResult(entry)
        if not entry then return end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)

        local mKey = entry.moduleKey or "STUDIO"
        local addonName = (addonTable.MODULE_ADDON_MAP and addonTable.MODULE_ADDON_MAP[mKey]) or mKey

        -- Auto-Enable & Load module if currently disabled
        if addonTable.IsSearchModuleDisabled and addonTable.IsSearchModuleDisabled(entry) then
            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
            gTbl.disabledModules = gTbl.disabledModules or {}
            gTbl.disabledModules[addonName] = nil
            gTbl.disabledModules[mKey] = nil
            local shortId = tostring(addonName):gsub("^Dynamic", ""):lower()
            gTbl.disabledModules[shortId] = nil
            if _G.DynamicSuiteDB and _G.DynamicSuiteDB.disabledModules then
                _G.DynamicSuiteDB.disabledModules[addonName] = nil
                _G.DynamicSuiteDB.disabledModules[mKey] = nil
                _G.DynamicSuiteDB.disabledModules[shortId] = nil
            end
            if addonName ~= "DynamicSuite" and addonName ~= "DynamicMarker" and C_AddOns and C_AddOns.GetAddOnInfo(addonName) then
                if C_AddOns.EnableAddOn then
                    pcall(C_AddOns.EnableAddOn, addonName, pName)
                end
                if C_AddOns.LoadAddOn and not C_AddOns.IsAddOnLoaded(addonName) then
                    pcall(C_AddOns.LoadAddOn, addonName)
                end
            end
            if addonName == "DynamicLoad" then
                addonTable.IsDynamicLoadModuleLoaded = addonTable.IsDynamicLoadModuleLoaded or C_AddOns.IsAddOnLoaded("DynamicLoad")
            end
        end

        local targetTitle = entry.highlightTitle or entry.targetTitle or entry.title

        -- 1. HUD Edit Mode Target
        if mKey == "HUD" or entry.viewKey == "EDIT_MODE" or entry.tabIndex == "EDIT_MODE" then
            if addonTable.EnterHudEditMode then
                addonTable.EnterHudEditMode(entry.hudTarget or "ALL")
            end
            return
        end

        -- 2. DynamicSuite Studio Views (Suite Studio, Changelog, Support, Guided Setup)
        if mKey == "STUDIO" or mKey == "studio" or mKey == "SETUP" or entry.viewKey == "THEME_STUDIO" or entry.viewKey == "DESKTOP_WINDOWS" or entry.viewKey == "SUITE_STUDIO_WINDOWS" then
            local vKey = entry.viewKey or (type(entry.tabIndex) == "string" and entry.tabIndex) or (mKey == "SETUP" and "GUIDED_SETUP" or "THEME_STUDIO")
            addonTable.OpenWorkspaceView(vKey)
            if f.SetSuiteStudioTab then
                if tonumber(entry.tabIndex) == 2 or vKey == "DESKTOP_WINDOWS" or vKey == "SUITE_STUDIO_WINDOWS" then
                    f.SetSuiteStudioTab(2)
                elseif tonumber(entry.tabIndex) == 1 or vKey == "SUITE_STUDIO_THEME" then
                    f.SetSuiteStudioTab(1)
                end
            end
            C_Timer.After(0.06, function()
                local root = f.themeView
                if vKey == "GUIDED_SETUP" then root = f.setupView
                elseif vKey == "CHANGELOG_VIEW" then root = f.changelogView
                elseif vKey == "SUPPORT_VIEW" then root = f.supportView
                end
                UI.JumpAndHighlightCard(root, targetTitle)
            end)
            return
        end

        -- 3. DynamicLoad (Addon Profiles vs Auto-Switching Rules)
        if mKey == "load" or mKey == "DynamicLoad" or addonName == "DynamicLoad" then
            addonTable.ShowConfigUI(true)
            if f.SelectDynamicLoadSubTab and entry.tabIndex then
                f.SelectDynamicLoadSubTab(entry.tabIndex)
            end
            C_Timer.After(0.06, function()
                local dlRoot = (entry.tabIndex == "toast_ui" and f.toastConfigPanel) or f.dlView or workspace
                UI.JumpAndHighlightCard(dlRoot, targetTitle)
            end)
            return
        end

        -- 4. Peer Modules (DynamicMarker, DynamicZoom, DynamicFPS, DynamicPrep, DynamicGroup, DynamicBags, DynamicChat)
        addonTable.OpenPeerModule(addonName)
        if entry.tabIndex ~= nil then
            local regMod = (_G.DynamicSuite and _G.DynamicSuite.modules and (_G.DynamicSuite.modules[addonName] or _G.DynamicSuite.modules[mKey])) or _G[addonName] or _G[mKey]
            if type(regMod) == "table" then
                local selFn = regMod.SelectSubTab or regMod.SelectTab or regMod.SetActiveTab
                if type(selFn) == "function" then
                    pcall(selFn, regMod, entry.tabIndex, true)
                end
            end
        end
        C_Timer.After(0.07, function()
            local hostRoot = (f.peerModuleHostFrame and f.peerModuleHostFrame:IsShown() and (f.peerModuleHostFrame._activeModHost or f.peerModuleHostFrame)) or f.peerView or workspace
            UI.JumpAndHighlightCard(hostRoot, targetTitle)
        end)
    end
    searchView.ActivateSearchResult = ActivateSearchResult

    -- Reusable Pool of Search Result Cards
    local resultCards = {}
    local CARD_H = 56
    local CARD_GAP = 6

    local function GetOrCreateResultCard(idx)
        local card = resultCards[idx]
        if card then return card end

        card = CreateFrame("Button", nil, resultsChild)
        card:SetHeight(CARD_H)
        card:RegisterForClicks("LeftButtonUp")

        card.bg = UI.SolidTex(card, "BACKGROUND", 0, 0.078, 0.090, 0.122, 0.90)
        card.bg:SetAllPoints()

        UI.CreatePixelBorder(card, 0.15, 0.18, 0.24, 0.88, 2)

        local leftBar = UI.SolidTex(card, "OVERLAY", 3, UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 0.65)
        leftBar:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
        leftBar:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 1, 1)
        leftBar:SetWidth(3)
        card.leftBar = leftBar

        local iconTex = card:CreateTexture(nil, "ARTWORK")
        iconTex:SetSize(18, 18)
        iconTex:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -10)
        if iconTex.SetSnapToPixelGrid then
            iconTex:SetSnapToPixelGrid(false)
            iconTex:SetTexelSnappingBias(0)
        end
        card.iconTex = iconTex

        local crumbText = card:CreateFontString(nil, "OVERLAY")
        UI.SetFont(crumbText, 9, "", 0.65, 0.72, 0.82, 1)
        crumbText:SetPoint("TOPLEFT", card, "TOPLEFT", 36, -7)
        crumbText:SetJustifyH("LEFT")
        card.crumbText = crumbText

        local titleText = card:CreateFontString(nil, "OVERLAY")
        UI.SetFont(titleText, 11, "", 0.96, 0.98, 1.0, 1)
        titleText:SetPoint("TOPLEFT", card, "TOPLEFT", 36, -21)
        titleText:SetJustifyH("LEFT")
        card.titleText = titleText

        local descText = card:CreateFontString(nil, "OVERLAY")
        UI.SetFont(descText, 9, "", 0.58, 0.64, 0.74, 1)
        descText:SetPoint("TOPLEFT", card, "TOPLEFT", 36, -37)
        descText:SetPoint("RIGHT", card, "RIGHT", -130, 0)
        descText:SetJustifyH("LEFT")
        descText:SetWordWrap(false)
        card.descText = descText

        local statusBadge = card:CreateFontString(nil, "OVERLAY")
        UI.SetFont(statusBadge, 9, "", 0.56, 0.64, 0.76, 1)
        statusBadge:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -8)
        statusBadge:SetJustifyH("RIGHT")
        card.statusBadge = statusBadge

        local openHint = card:CreateFontString(nil, "OVERLAY")
        UI.SetFont(openHint, 10, "", UI.COLORS.ACCENT.r, UI.COLORS.ACCENT.g, UI.COLORS.ACCENT.b, 1)
        openHint:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -12, 9)
        openHint:SetJustifyH("RIGHT")
        openHint:SetText("Jump to Setting ->")
        card.openHint = openHint

        card:SetScript("OnEnter", function(self)
            local ar, ag, ab = UI.GetActiveAccentColor()
            self.bg:SetColorTexture(ar * 0.20, ag * 0.20, ab * 0.24, 0.96)
            self.dsBorder:SetColor(ar, ag, ab, 0.92)
            self.leftBar:SetColorTexture(ar, ag, ab, 1.0)
            self.iconTex:SetVertexColor(ar, ag, ab, 1.0)
            self.openHint:SetTextColor(ar, ag, ab, 1.0)
        end)

        card:SetScript("OnLeave", function(self)
            local ar, ag, ab = UI.GetActiveAccentColor()
            local surf = UI.GetActiveSurfaceColors()
            self.bg:SetColorTexture(surf.card.r, surf.card.g, surf.card.b, 0.92)
            self.dsBorder:SetColor(0.15, 0.18, 0.24, 0.88)
            self.leftBar:SetColorTexture(ar, ag, ab, 0.65)
            self.iconTex:SetVertexColor(0.76, 0.82, 0.90, 0.95)
            self.openHint:SetTextColor(0.64, 0.72, 0.84, 0.90)
        end)

        card:SetScript("OnClick", function(self)
            if self._entry then
                ActivateSearchResult(self._entry)
            end
        end)

        resultCards[idx] = card
        return card
    end

    -- Token & Synonym Scoring Engine (< 0.05ms, Zero OnUpdate Polling)
    local function TokenizeQuery(rawQuery)
        local tokens = {}
        if type(rawQuery) ~= "string" then return tokens, "" end
        local cleaned = rawQuery:lower():gsub("^%s+", ""):gsub("%s+$", "")
        for tok in cleaned:gmatch("%S+") do
            tokens[#tokens + 1] = tok
        end
        return tokens, cleaned
    end

    local function ScoreSearchEntry(entry, tokens, fullQueryLower)
        if #tokens == 0 then
            return 1
        end
        local titleL = entry._titleLower or ""
        local kwL    = entry._kwLower or entry._keywordsLower or ""
        local descL  = entry._descLower or ""
        local modL   = entry._modLower or ""
        local crumbL = entry._tabLower or entry._crumbLower or ""
        local catL   = entry._catLower or (entry.category or ""):lower()

        local totalScore = 0
        for i = 1, #tokens do
            local tok = tokens[i]
            local tokScore = 0

            local tPos = titleL:find(tok, 1, true)
            if tPos then
                if tPos == 1 or titleL:sub(tPos - 1, tPos - 1):match("[%s%-/%(]") then
                    tokScore = tokScore + 120
                else
                    tokScore = tokScore + 85
                end
            end

            local kPos = kwL:find(tok, 1, true)
            if kPos then
                if kPos == 1 or kwL:sub(kPos - 1, kPos - 1):match("%s") then
                    tokScore = tokScore + 75
                else
                    tokScore = tokScore + 55
                end
            end

            if descL:find(tok, 1, true) then
                tokScore = tokScore + 30
            end

            if modL:find(tok, 1, true) or crumbL:find(tok, 1, true) or catL:find(tok, 1, true) then
                tokScore = tokScore + 22
            end

            -- Every token must match at least one field (AND logic across tokens)
            if tokScore == 0 then
                return 0
            end
            totalScore = totalScore + tokScore
        end

        if #fullQueryLower >= 3 and titleL:find(fullQueryLower, 1, true) then
            totalScore = totalScore + 45
        end

        return totalScore
    end

    local BRAND_SUFFIX_MAP = {
        load = "Load", DynamicLoad = "Load",
        marker = "Marker", DynamicMarker = "Marker",
        zoom = "Zoom", DynamicZoom = "Zoom",
        fps = "FPS", DynamicFPS = "FPS",
        prep = "Prep", DynamicPrep = "Prep",
        group = "Group", DynamicGroup = "Group",
        bags = "Bags", DynamicBags = "Bags",
        chat = "Chat", DynamicChat = "Chat",
        mail = "Mail", DynamicMail = "Mail",
    }
    local function FormatModuleBrandForEntry(entry)
        local mKey = entry.moduleKey or "STUDIO"
        if mKey == "STUDIO" or mKey == "studio" or mKey == "SETUP" or mKey == "HUD" or mKey == "DynamicSuite" then
            return UI.FormatTwoToneBrand("Suite")
        end
        local suffix = BRAND_SUFFIX_MAP[mKey] or tostring(entry.moduleTitle or entry.addonName or mKey):gsub("^Dynamic", "")
        return UI.FormatTwoToneBrand(suffix)
    end

    clearFilterBtn:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
        activeSearchCategory = "ALL"
        if f.railSearchBox then
            f.railSearchBox:SetText("")
            f.railSearchBox:ClearFocus()
        end
        if searchView.Refresh then
            searchView.Refresh()
        end
    end)

    local lastFilteredResults = {}
    searchView.TriggerTopResult = function()
        if lastFilteredResults and lastFilteredResults[1] and lastFilteredResults[1].entry then
            ActivateSearchResult(lastFilteredResults[1].entry)
        end
    end

    searchView.Refresh = function()
        UI.RefreshPaletteCache()
        local ar, ag, ab = UI.GetActiveAccentColor()
        local surf = UI.GetActiveSurfaceColors()

        finderTitle:SetTextColor(ar, ag, ab, 1)
        emptyCard.bg:SetColorTexture(surf.card.r, surf.card.g, surf.card.b, surf.card.a)

        local rawQuery = (f.railSearchBox and f.railSearchBox:GetText()) or ""
        local tokens, fullQueryLower = TokenizeQuery(rawQuery)
        local allInstalled = (_G.DynamicSuite and _G.DynamicSuite.GetInstalledSearchEntries and _G.DynamicSuite:GetInstalledSearchEntries()) or {}

        local catCounts = { ["ALL"] = 0 }
        for _, cDef in ipairs(SEARCH_CATEGORIES) do
            catCounts[cDef.key] = 0
        end

        local scoredAll = {}
        for _, entry in ipairs(allInstalled) do
            local sc = ScoreSearchEntry(entry, tokens, fullQueryLower)
            if sc > 0 then
                scoredAll[#scoredAll + 1] = {
                    entry = entry,
                    score = sc,
                    disabled = (addonTable.IsSearchModuleDisabled and addonTable.IsSearchModuleDisabled(entry)) or false,
                }
                catCounts["ALL"] = (catCounts["ALL"] or 0) + 1
                local eCat = entry.category or "BAGS_QOL"
                catCounts[eCat] = (catCounts[eCat] or 0) + 1
            end
        end

        table.sort(scoredAll, function(a, b)
            if a.score ~= b.score then
                return a.score > b.score
            end
            if a.disabled ~= b.disabled then
                return not a.disabled
            end
            return (a.entry.seedOrder or 9999) < (b.entry.seedOrder or 9999)
        end)

        -- Rebuild / Update Category Filter Pills with live counts
        local pillX = 0
        for idx, cDef in ipairs(SEARCH_CATEGORIES) do
            local pBtn = catPillButtons[idx]
            if not pBtn then
                pBtn = CreateFlatButton(catStrip, 110, 22, cDef.label, false)
                catPillButtons[idx] = pBtn
            end
            local cCount = catCounts[cDef.key] or 0
            local pillText = string.format("%s (%d)", cDef.label, cCount)
            pBtn.label:SetText(pillText)
            local strW = (pBtn.label.GetStringWidth and pBtn.label:GetStringWidth()) or 76
            local btnW = math.max(74, math.ceil(strW + 18))
            pBtn:SetSize(btnW, 22)
            pBtn:ClearAllPoints()
            pBtn:SetPoint("LEFT", catStrip, "LEFT", pillX, 0)
            pillX = pillX + btnW + 6

            local isCatSel = (activeSearchCategory == cDef.key)
            pBtn:SetSelected(isCatSel, { r = ar, g = ag, b = ab })
            if isCatSel then
                pBtn.label:SetTextColor(1, 1, 1, 1)
            elseif cCount == 0 then
                pBtn.label:SetTextColor(0.45, 0.50, 0.58, 0.75)
            else
                pBtn.label:SetTextColor(0.84, 0.88, 0.94, 1)
            end

            pBtn:SetScript("OnClick", function()
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
                activeSearchCategory = cDef.key
                resultsScroll:SetVerticalScroll(0)
                searchView.Refresh()
            end)
        end

        local filtered = {}
        for _, item in ipairs(scoredAll) do
            if activeSearchCategory == "ALL" or item.entry.category == activeSearchCategory then
                filtered[#filtered + 1] = item
            end
        end
        lastFilteredResults = filtered

        local hasFilter = (#tokens > 0) or (activeSearchCategory ~= "ALL")
        clearFilterBtn:SetShown(hasFilter)
        if #tokens > 0 then
            finderCountLabel:SetText(string.format("Showing |cFFFFFFFF%d|r matching setting%s", #filtered, #filtered == 1 and "" or "s"))
        else
            finderCountLabel:SetText(string.format("Browsing |cFFFFFFFF%d|r indexed setting%s across installed modules", #filtered, #filtered == 1 and "" or "s"))
        end

        for i = 1, #resultCards do
            resultCards[i]:Hide()
        end

        if #filtered == 0 then
            emptyCard:Show()
            resultsChild:SetHeight(200)
            resultsScroll:SetVerticalScroll(0)
            UpdateSearchScrollThumb()
            return
        end

        emptyCard:Hide()
        local yCursor = -2
        for idx, item in ipairs(filtered) do
            local entry = item.entry
            local card = GetOrCreateResultCard(idx)
            card._entry = entry
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", resultsChild, "TOPLEFT", 0, yCursor)
            card:SetPoint("TOPRIGHT", resultsChild, "TOPRIGHT", 0, yCursor)

            card.bg:SetColorTexture(surf.card.r, surf.card.g, surf.card.b, 0.92)
            card.dsBorder:SetColor(0.15, 0.18, 0.24, 0.88)
            card.leftBar:SetColorTexture(ar, ag, ab, 0.65)

            card.iconTex:SetTexture(entry.icon or entry.moduleIcon or "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\Media\\Icons\\icon_palette.tga")
            card.iconTex:SetVertexColor(0.76, 0.82, 0.90, 0.95)

            local brandStr = FormatModuleBrandForEntry(entry)
            local crumbStr = entry.tabLabel or entry.breadcrumb or entry.moduleTitle or "Suite"
            card.crumbText:SetText(string.format("%s   |cFF475569>|r   |cFF94A3B8%s|r", brandStr, crumbStr))
            card.titleText:SetText(entry.title or "")
            card.descText:SetText(entry.desc or "")

            if item.disabled then
                card.statusBadge:SetText("|cFFFBBF24[Module Disabled - Click to Enable & Open]|r")
                card.openHint:SetText("Enable & Jump ->")
            else
                local catLabel = (addonTable.SEARCH_CATEGORY_LABELS and addonTable.SEARCH_CATEGORY_LABELS[entry.category]) or entry.categoryLabel or entry.category or "General"
                card.statusBadge:SetText(string.format("|cFF64748B[%s]|r", catLabel))
                card.openHint:SetText("Jump to Setting ->")
            end
            card.openHint:SetTextColor(0.64, 0.72, 0.84, 0.90)

            card:Show()
            yCursor = yCursor - (CARD_H + CARD_GAP)
        end

        resultsChild:SetHeight(math.max(240, math.abs(yCursor) + 12))
        UpdateSearchScrollThumb()
    end

    function addonTable.OpenSearchView(initialQuery, categoryKey)
        if not mainFrame then
            addonTable.CreateMainConfigUI()
        end
        if type(categoryKey) == "string" and categoryKey ~= "" then
            activeSearchCategory = categoryKey
        elseif type(initialQuery) == "string" then
            activeSearchCategory = "ALL"
        end
        if type(initialQuery) == "string" and f.railSearchBox then
            f.railSearchBox:SetText(initialQuery)
        end
        addonTable.OpenWorkspaceView("SEARCH_VIEW")
    end
    end

    ----------------------------------------------------------------------------
    -- Workspace Router & Live Theme Application
    ----------------------------------------------------------------------------
    function addonTable.OpenWorkspaceView(viewKey, optionalTabIndex)
        if not mainFrame then
            addonTable.CreateMainConfigUI()
        end
        UI.CloseAllPopups()
        local requestedStudioTab = nil
        if tonumber(optionalTabIndex) == 1 or tonumber(optionalTabIndex) == 2 then
            requestedStudioTab = tonumber(optionalTabIndex)
        end
        if viewKey == "DESKTOP_WINDOWS" or viewKey == "SUITE_STUDIO_WINDOWS" or viewKey == "WINDOWS" then
            viewKey = "THEME_STUDIO"
            requestedStudioTab = requestedStudioTab or 2
        elseif viewKey == "SUITE_STUDIO_THEME" then
            viewKey = "THEME_STUDIO"
            requestedStudioTab = requestedStudioTab or 1
        elseif viewKey == "THEME" then
            viewKey = "THEME_STUDIO"
            if requestedStudioTab == nil then requestedStudioTab = 1 end
        elseif viewKey == "STUDIO" then
            viewKey = "THEME_STUDIO"
        elseif viewKey == "SETUP" then viewKey = "GUIDED_SETUP"
        elseif viewKey == "EDIT" then viewKey = "EDIT_MODE"
        elseif viewKey == "LOAD" then viewKey = "DYNAMICLOAD"
        elseif viewKey == "CHANGELOG" then viewKey = "CHANGELOG_VIEW"
        elseif viewKey == "SUPPORT" then viewKey = "SUPPORT_VIEW"
        elseif viewKey == "SEARCH" or viewKey == "FIND" then viewKey = "SEARCH_VIEW"
        end
        if viewKey ~= "SEARCH_VIEW" then
            f.lastNonSearchWorkspaceView = viewKey or "DYNAMICLOAD"
            f.lastNonSearchPeerModuleKey = selectedPeerModuleKey
        end
        activeWorkspaceView = viewKey or "DYNAMICLOAD"
        if addonTable.combatRestorePill and addonTable.combatRestorePill:IsShown() then
            addonTable.combatRestorePill:Hide()
        end
        mainFrame:Show()
        if mainFrame.Raise then
            mainFrame:Raise()
        end
        if addonTable.UpdateCombatLockState then
            addonTable.UpdateCombatLockState()
        end

        if f.peerModuleHostFrame then
            f.peerModuleHostFrame:Hide()
        end
        if f.headerTitle then
            f.headerTitle:SetText(UI.FormatTwoToneBrand("Suite"))
        end

        if f.railCategoryHeaders then
            for _, hdr in pairs(f.railCategoryHeaders) do
                if hdr and hdr.tick then
                    hdr.tick:SetColorTexture(ar, ag, ab, 0.85)
                end
            end
        end
        if f.UpdateRailScrollBar then
            f.UpdateRailScrollBar()
        end
        if f.verPill and f.verPill.label then
            f.verPill.label:SetText("v" .. (addonTable.ADDON_VERSION or "2.3.2"))
        end
        if f.dockHint then
            if activeWorkspaceView == "SEARCH_VIEW" then
                f.dockHint:SetText("Global Feature Finder   |cFF475569|||r   Slash: /ds search <keyword>")
            elseif activeWorkspaceView == "THEME_STUDIO" then
                f.dockHint:SetText("Active Module: Suite Studio   |cFF475569|||r   Slash: /ds studio")
            elseif activeWorkspaceView == "DYNAMICLOAD" then
                f.dockHint:SetText("Active Module: DynamicLoad   |cFF475569|||r   Slash: /dl")
            elseif (activeWorkspaceView == "PEER_MODULE" or activeWorkspaceView == "PEER_HOST") and selectedPeerModuleKey then
                local modTitle = tostring(selectedPeerModuleKey)
                local modSlash = "/ds"
                for _, mInfo in ipairs(addonTable.SUITE_MODULE_LIST or {}) do
                    local aKey = mInfo.addonName or mInfo.name or mInfo.key
                    if selectedPeerModuleKey == aKey or selectedPeerModuleKey == mInfo.key or selectedPeerModuleKey == mInfo.id then
                        modTitle = mInfo.title or aKey
                        modSlash = mInfo.slash or "/ds"
                        break
                    end
                end
                f.dockHint:SetText(string.format("Active Module: %s   |cFF475569|||r   Slash: %s", modTitle, modSlash))
            else
                f.dockHint:SetText("Active Module: DynamicSuite   |cFF475569|||r   Slash: /ds")
            end
        end

        if f.SyncWorkspaceGeometry then f.SyncWorkspaceGeometry() end
        if f.workspace then f.workspace:Show() end
        if f.EnsureDynamicLoadWorkspaceMounted then f.EnsureDynamicLoadWorkspaceMounted() end
        if activeWorkspaceView == "DYNAMICLOAD" and not f.dlView then
            selectedPeerModuleKey = "DynamicLoad"
            activeWorkspaceView = "PEER_MODULE"
        end
        if f.dlView then f.dlView:SetShown(activeWorkspaceView == "DYNAMICLOAD") end
        if activeWorkspaceView == "DYNAMICLOAD" and f.dlView then
            if f.navBar then f.navBar:Show() end
            if f.ReflowDlTopTrack then f.ReflowDlTopTrack() end
            if not isToastSubTabActive then
                if f.toastConfigPanel then f.toastConfigPanel:Hide() end
                if f.toolbar then f.toolbar:Show() end
                if f.telemetryStrip then f.telemetryStrip:Show() end
                if f.legendStrip then f.legendStrip:Show() end
                if f.scrollFrame then f.scrollFrame:Show() end
                if f.scrollChild then f.scrollChild:Show() end
                if f.scrollTrack then f.scrollTrack:Show() end
            end
        end
        if f.peerView then f.peerView:SetShown(activeWorkspaceView == "PEER_MODULE") end
        if f.themeView then f.themeView:SetShown(activeWorkspaceView == "THEME_STUDIO") end
        if f.setupView then f.setupView:SetShown(activeWorkspaceView == "GUIDED_SETUP") end
        if f.editView then f.editView:SetShown(activeWorkspaceView == "EDIT_MODE") end
        if f.changelogView then f.changelogView:SetShown(activeWorkspaceView == "CHANGELOG_VIEW") end
        if f.supportView then f.supportView:SetShown(activeWorkspaceView == "SUPPORT_VIEW") end
        if f.searchView then f.searchView:SetShown(activeWorkspaceView == "SEARCH_VIEW") end
        if f.UpdateModuleConflictBanner then f.UpdateModuleConflictBanner() end

        if activeWorkspaceView == "EDIT_MODE" then
            editView.Refresh()
        else
            addonTable.SetToastEditMode(false)
        end

        if activeWorkspaceView == "SEARCH_VIEW" and f.searchView and f.searchView.Refresh then
            f.searchView.Refresh()
        elseif activeWorkspaceView == "PEER_MODULE" and peerView.Refresh then
            peerView.Refresh()
        elseif activeWorkspaceView == "THEME_STUDIO" then
            if requestedStudioTab and f.SetSuiteStudioTab then
                f.SetSuiteStudioTab(requestedStudioTab, true)
            end
            if themeView.Refresh then
                themeView.Refresh()
            end
        elseif activeWorkspaceView == "GUIDED_SETUP" and setupView.Refresh then
            setupView.Refresh()
        elseif activeWorkspaceView == "CHANGELOG_VIEW" and changelogView.Refresh then
            changelogView.Refresh()
        elseif activeWorkspaceView == "SUPPORT_VIEW" and supportView.Refresh then
            supportView.Refresh()
        elseif activeWorkspaceView == "DYNAMICLOAD" then
            if f.UpdateAllTabVisuals then f.UpdateAllTabVisuals() end
            if f.UpdateFilterChips then f.UpdateFilterChips() end
            if f.RefreshTelemetryStrip then f.RefreshTelemetryStrip() end
            if f.scrollChild then RefreshAddonTree(f.scrollChild) end
        end

        if f.UpdateResetButtonLabel then f.UpdateResetButtonLabel() end
        if f.RefreshLeftRailLayout then
            f.RefreshLeftRailLayout()
        elseif RefreshLeftRailVisuals then
            RefreshLeftRailVisuals()
        end
        UpdateStatusBar()
    end

    function addonTable.OpenSuiteStudioTab(tabIdx)
        if not mainFrame then
            addonTable.CreateMainConfigUI()
        end
        local t = (tonumber(tabIdx) == 2) and 2 or 1
        addonTable.OpenWorkspaceView(t == 2 and "SUITE_STUDIO_WINDOWS" or "SUITE_STUDIO_THEME")
        if f and f.SetSuiteStudioTab then
            f.SetSuiteStudioTab(t)
        end
    end
    f.OpenSuiteStudioTab = addonTable.OpenSuiteStudioTab

    -- Item #42: Slash Command Routing Fix (Ensure /dm, /dz, /dfps, /dprep, /dgroup switch to target module AFTER f:Show())
    function addonTable.OpenPeerModule(targetKey)
        if not mainFrame then
            addonTable.CreateMainConfigUI()
        end
        UI.CloseAllPopups()
        f.pendingOpenModule = targetKey
        if addonTable.combatRestorePill and addonTable.combatRestorePill:IsShown() then
            addonTable.combatRestorePill:Hide()
        end
        mainFrame:Show()
        if mainFrame.Raise then
            mainFrame:Raise()
        end
        if addonTable.UpdateCombatLockState then
            addonTable.UpdateCombatLockState()
        end
        for _, card in ipairs(railModuleCards) do
            local m = card.modInfo
            local aKey = m.addonName or m.name or m.key
            if targetKey == aKey or targetKey == m.key or targetKey == m.id or (type(targetKey) == "string" and (targetKey:lower() == aKey:lower() or targetKey:lower() == (m.key or ""):lower())) then
                f.pendingOpenModule = nil
                card:GetScript("OnClick")(card, "LeftButton")
                return
            end
        end
        f.pendingOpenModule = nil
        selectedPeerModuleKey = targetKey
        addonTable.OpenWorkspaceView("PEER_MODULE")
    end
    if _G.DynamicSuite then
        _G.DynamicSuite.OpenModule = function(selfOrKey, maybeKey)
            local modKey = (type(selfOrKey) == "table") and maybeKey or selfOrKey
            if not modKey or modKey == "DynamicLoad" or modKey == "load" then
                addonTable.ShowConfigUI()
            else
                addonTable.OpenPeerModule(modKey)
            end
        end
        _G.DynamicSuite.SelectModule = _G.DynamicSuite.OpenModule
    end

    local isApplyingSuiteTheme = false
    function addonTable.ApplySuiteThemeAndGeometry()
        if isApplyingSuiteTheme then return end
        isApplyingSuiteTheme = true
        UI.RefreshPaletteCache()
        UI.RefreshAllFonts()
        local ar, ag, ab = UI.GetActiveAccentColor()
        local surf = UI.GetActiveSurfaceColors()
        local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}

        f.bg:SetColorTexture(surf.panel.r, surf.panel.g, surf.panel.b, surf.panel.a)
        header.bg:SetColorTexture(surf.header.r, surf.header.g, surf.header.b, surf.header.a)
        footer.bg:SetColorTexture(surf.header.r, surf.header.g, surf.header.b, surf.header.a)
        leftRail.bg:SetColorTexture(surf.rail.r, surf.rail.g, surf.rail.b, surf.rail.a)
        if f.navBar then local navBar = f.navBar
            if navBar.bg then navBar.bg:Hide() end
            if navBar.divider then navBar.divider:Hide() end
        end
        for _, cardBox in ipairs(f.themeCards or {}) do
            if cardBox and cardBox.bg then
                cardBox.bg:SetColorTexture(surf.card.r, surf.card.g, surf.card.b, surf.card.a)
            end
        end
        if f.headerAccentTop then
            f.headerAccentTop:SetColorTexture(ar, ag, ab, 1)
        end

        if f.headerTitle then
            f.headerTitle:SetText(UI.FormatTwoToneBrand("Suite"))
        end

        if f.railCategoryHeaders then
            for _, hdr in pairs(f.railCategoryHeaders) do
                if hdr and hdr.tick then
                    hdr.tick:SetColorTexture(ar, ag, ab, 0.85)
                end
            end
        end
        if f.UpdateRailScrollBar then
            f.UpdateRailScrollBar()
        end
        if f.UpdateRailSearchBoxVisual then
            f.UpdateRailSearchBoxVisual()
        end

        if f.emblemBg then
            f.emblemBg.tex:SetColorTexture(0.04, 0.05, 0.07, 0.98)
            f.emblemBg.dsBorder:SetColor(ar, ag, ab, 0.85)
            if f.emblemBg.SetAccentColor then
                f.emblemBg:SetAccentColor(ar, ag, ab, 1)
            end
        end

        if f.stageToastIconWrap and f.stageToastIconWrap.SetAccentColor then
            f.stageToastIconWrap:SetAccentColor(ar, ag, ab, 1)
        end

        if addonTable.toastFrame and addonTable.toastFrame.iconWrap and addonTable.toastFrame.iconWrap.SetAccentColor then
            addonTable.toastFrame.iconWrap:SetAccentColor(ar, ag, ab, 1)
        end

        if f.minimizedBar then
            f.minimizedBar.bg:SetColorTexture(surf.header.r, surf.header.g, surf.header.b, 0.98)
            f.minimizedBar.dsBorder:SetColor(ar, ag, ab, 0.95)
            if f.minimizedBar.logo and f.minimizedBar.logo.SetAccentColor then
                f.minimizedBar.logo:SetAccentColor(ar, ag, ab, 1)
            end
            if f.minimizedBar.title then
                f.minimizedBar.title:SetText(UI.FormatTwoToneBrand("Suite") .. "  |cFF94A3B8(Minimized)|r")
            end
            if f.minimizedBar.restoreBtn then
                if f.minimizedBar.editBtn then f.minimizedBar.editBtn:SetSelected(true, { r = ar, g = ag, b = ab }) end
            end
            if f.minimizedBar.ReflowBarWidth then
                f.minimizedBar:ReflowBarWidth()
            end
            if f.minimizedBar.RestoreSavedPosition then
                f.minimizedBar:RestoreSavedPosition()
            end
        end
        if _G.DynamicSuiteEditModeModal and _G.DynamicSuiteEditModeModal.RestoreSavedPosition then
            _G.DynamicSuiteEditModeModal:RestoreSavedPosition()
        end

        if f.suiteHubRowEmblem and f.suiteHubRowEmblem.SetAccentColor then
            f.suiteHubRowEmblem:SetAccentColor(ar, ag, ab, 1)
        end

        if f.activateReloadBtn then
            f.activateReloadBtn.bg:SetColorTexture(ar, ag, ab, 0.24)
            f.activateReloadBtn.dsBorder:SetColor(ar, ag, ab, 0.80)
        end

        if gTbl.windowWidth and gTbl.windowWidth < 980 then gTbl.windowWidth = 1040 end
        if DynamicLoadDB and DynamicLoadDB.windowWidth and DynamicLoadDB.windowWidth < 980 then DynamicLoadDB.windowWidth = 1040 end
        if gTbl.windowWidth and gTbl.windowHeight then
            f:SetSize(math.max(980, math.min(1440, gTbl.windowWidth)), math.max(640, math.min(920, gTbl.windowHeight)))
        end
        if f.peerModuleHostFrame and f.peerModuleHostFrame:IsShown() and UI.NormalizeEmbeddedSubDrawers then
            UI.NormalizeEmbeddedSubDrawers(f.peerModuleHostFrame)
        end
        if gTbl.windowScale and f.CommitWindowScale then
            f.CommitWindowScale(gTbl.windowScale)
        end
        if gTbl.windowAlpha and f.ApplyWindowOpacity then
            f.ApplyWindowOpacity(gTbl.windowAlpha)
        end

        if f.SyncWorkspaceGeometry then f.SyncWorkspaceGeometry() end
        if f.workspace then f.workspace:Show() end
        if f.EnsureDynamicLoadWorkspaceMounted then f.EnsureDynamicLoadWorkspaceMounted() end
        if activeWorkspaceView == "DYNAMICLOAD" and not f.dlView then
            selectedPeerModuleKey = "DynamicLoad"
            activeWorkspaceView = "PEER_MODULE"
        end
        if f.dlView then f.dlView:SetShown(activeWorkspaceView == "DYNAMICLOAD") end
        if activeWorkspaceView == "DYNAMICLOAD" and f.dlView then
            if f.navBar then f.navBar:Show() end
            if f.ReflowDlTopTrack then f.ReflowDlTopTrack() end
            if not isToastSubTabActive then
                if f.toastConfigPanel then f.toastConfigPanel:Hide() end
                if f.toolbar then f.toolbar:Show() end
                if f.telemetryStrip then f.telemetryStrip:Show() end
                if f.legendStrip then f.legendStrip:Show() end
                if f.scrollFrame then f.scrollFrame:Show() end
                if f.scrollChild then f.scrollChild:Show() end
                if f.scrollTrack then f.scrollTrack:Show() end
            end
        end
        if f.peerView then f.peerView:SetShown(activeWorkspaceView == "PEER_MODULE") end
        if f.peerModuleHostFrame then f.peerModuleHostFrame:SetShown(activeWorkspaceView == "PEER_HOST") end
        if f.themeView then f.themeView:SetShown(activeWorkspaceView == "THEME_STUDIO") end
        if f.setupView then f.setupView:SetShown(activeWorkspaceView == "GUIDED_SETUP") end
        if f.editView then f.editView:SetShown(activeWorkspaceView == "EDIT_MODE") end
        if f.changelogView then f.changelogView:SetShown(activeWorkspaceView == "CHANGELOG_VIEW") end
        if f.supportView then f.supportView:SetShown(activeWorkspaceView == "SUPPORT_VIEW") end
        if f.searchView then f.searchView:SetShown(activeWorkspaceView == "SEARCH_VIEW") end
        if f.UpdateModuleConflictBanner then f.UpdateModuleConflictBanner() end

        if f.UpdateAllTabVisuals then f.UpdateAllTabVisuals() end
        if f.UpdateAutoToggleVisual then f.UpdateAutoToggleVisual() end
        if f.RefreshLeftRailLayout then
            f.RefreshLeftRailLayout()
        else
            RefreshLeftRailVisuals()
        end
        if f.UpdateFilterChips then f.UpdateFilterChips() end
        if f.RefreshTelemetryStrip then f.RefreshTelemetryStrip() end
        if f.UpdateResetButtonLabel then f.UpdateResetButtonLabel() end
        if activeWorkspaceView == "SEARCH_VIEW" and f.searchView and f.searchView.Refresh then
            f.searchView.Refresh()
        elseif activeWorkspaceView == "DYNAMICLOAD" and f.scrollChild then
            RefreshAddonTree(f.scrollChild)
        elseif activeWorkspaceView == "PEER_MODULE" and f.peerView and f.peerView.Refresh then
            f.peerView.Refresh()
        elseif activeWorkspaceView == "THEME_STUDIO" and f.themeView and f.themeView.Refresh then
            f.themeView.Refresh()
        elseif activeWorkspaceView == "GUIDED_SETUP" and f.setupView and f.setupView.Refresh then
            f.setupView.Refresh()
        elseif activeWorkspaceView == "CHANGELOG_VIEW" and f.changelogView and f.changelogView.Refresh then
            f.changelogView.Refresh()
        elseif activeWorkspaceView == "SUPPORT_VIEW" and f.supportView and f.supportView.Refresh then
            f.supportView.Refresh()
        elseif activeWorkspaceView == "EDIT_MODE" and f.editView and f.editView.Refresh then
            f.editView.Refresh()
        end
        if addonTable.ApplyToastVisuals then addonTable.ApplyToastVisuals() end
        if addonTable.RefreshDisableCoreModalTheme then addonTable.RefreshDisableCoreModalTheme() end
        if f.toastConfigPanel and f.toastConfigPanel.RefreshControls and f.toastConfigPanel:IsShown() then
            f.toastConfigPanel.RefreshControls()
        end
        local notified = {}
        local function IsModDisabledForTheme(mKey, mObj)
            if not addonTable.IsSuiteModuleExplicitlyDisabled then return false end
            local checkName = (type(mObj) == "table" and (mObj.addonName or mObj.name or mObj.id)) or mKey
            return checkName and addonTable.IsSuiteModuleExplicitlyDisabled(checkName) or false
        end
        if _G.DynamicSuite and type(_G.DynamicSuite.modules) == "table" then
            for modKey, mod in pairs(_G.DynamicSuite.modules) do
                if type(mod) == "table" and not notified[mod] and modKey ~= "DynamicLoad" and modKey ~= "load" and mod.name ~= "DynamicLoad" and not IsModDisabledForTheme(modKey, mod) then
                    notified[mod] = true
                    local fn = mod.ApplyTheme or mod.ApplyThemeToUI or mod.RefreshTheme
                    if type(fn) == "function" then pcall(fn, mod) end
                end
            end
        end
        local standaloneMods = {
            { key = "DynamicMarker", obj = _G.DynamicMarker },
            { key = "DynamicPrep", obj = _G.DynamicPrep },
            { key = "DynamicFPS", obj = _G.DynamicFPS },
            { key = "DynamicZoom", obj = _G.DynamicZoom },
            { key = "DynamicGroup", obj = _G.DynamicGroup },
            { key = "DynamicBags", obj = _G.DynamicBags },
            { key = "DynamicChat", obj = _G.DynamicChat },
        }
        for _, entry in ipairs(standaloneMods) do
            local smod = entry.obj
            if type(smod) == "table" and not notified[smod] and not IsModDisabledForTheme(entry.key, smod) then
                notified[smod] = true
                local fn = smod.ApplyTheme or smod.ApplyThemeToUI or smod.RefreshTheme
                if type(fn) == "function" then pcall(fn, smod) end
            end
        end
        if _G.DynamicMarker and not IsModDisabledForTheme("DynamicMarker", _G.DynamicMarker) then
            if _G.DynamicMarker.RefreshTargetBar then pcall(_G.DynamicMarker.RefreshTargetBar, _G.DynamicMarker) end
            if _G.DynamicMarker.RefreshFlareBar then pcall(_G.DynamicMarker.RefreshFlareBar, _G.DynamicMarker) end
            if _G.DynamicMarker.RefreshAll then pcall(_G.DynamicMarker.RefreshAll, _G.DynamicMarker) end
        end
        isApplyingSuiteTheme = false
    end
    UI.ApplyThemeToMainFrame = addonTable.ApplySuiteThemeAndGeometry
    addonTable.RefreshConfigUI = addonTable.ApplySuiteThemeAndGeometry

    f:SetScript("OnShow", function(self)
        self._minimizedForHudDrag = false
        if self.minimizedBar then
            self.minimizedBar:Hide()
        end
        if floatingEditPill then
            floatingEditPill:Hide()
        end
        if _G.DynamicSuite then
            local prevFrame = _G.DynamicSuite.MainFrame or _G.DynamicSuite.mainFrame
            if prevFrame and prevFrame ~= f and prevFrame.GetPoint then
                local pt, rel, relPt, xOfs, yOfs = prevFrame:GetPoint(1)
                if pt then
                    f:ClearAllPoints()
                    f:SetPoint(pt, rel or UIParent, relPt or pt, xOfs or 0, yOfs or 0)
                end
                if prevFrame:IsShown() then
                    prevFrame:Hide()
                end
            end
            _G.DynamicSuite.MainFrame = f
            _G.DynamicSuite.mainFrame = f
        end

        if f.leftRail then f.leftRail:Show() end
        if f.railModuleScroll then f.railModuleScroll:Show() end
        if f.railModuleChild then f.railModuleChild:Show() end
        if f.railSearchWrap then f.railSearchWrap:Show() end
        if f.modSectionHdr then f.modSectionHdr:Show() end
        if f.resetSortBtn then f.resetSortBtn:Show() end
        if f.studioSectionHdr then f.studioSectionHdr:Show() end
        if f.railStudioBtns then
            for _, sBtn in ipairs(f.railStudioBtns) do
                if sBtn and sBtn.Show then sBtn:Show() end
            end
        end
        if f.SyncWorkspaceGeometry then f.SyncWorkspaceGeometry() end
        if f.workspace then f.workspace:Show() end
        addonTable.ApplySuiteThemeAndGeometry()
        if f.RefreshLeftRailLayout then f.RefreshLeftRailLayout() end
        if f.ReflowDlTopTrack then f.ReflowDlTopTrack() end
        if f.UpdateTabActiveIndicators then f.UpdateTabActiveIndicators() end
        if f.UpdateStatusBar then f.UpdateStatusBar() end
        if f.UpdateStashButton then f.UpdateStashButton() end
        if f.UpdateFilterChips then f.UpdateFilterChips() end
        if f.RefreshTelemetryStrip then f.RefreshTelemetryStrip() end
        if f.UpdateResetButtonLabel then f.UpdateResetButtonLabel() end
        if activeWorkspaceView == "DYNAMICLOAD" then
            if f.scrollFrame and f.scrollFrame.UpdateScrollChildRect then f.scrollFrame:UpdateScrollChildRect() end
            if f.scrollChild and f.scrollChild.Refresh then f.scrollChild.Refresh() end
        end
        if self.Raise then self:Raise() end

        if activeWorkspaceView == "EDIT_MODE" then
            addonTable.SetToastEditMode(true, selectedTabKey)
        else
            addonTable.SetToastEditMode(false)
        end

        if not self._postLayoutPending and C_Timer and C_Timer.After then
            self._postLayoutPending = true
            C_Timer.After(0, function()
                self._postLayoutPending = nil
                if not self:IsShown() then return end
                if self.leftRail then self.leftRail:Show() end
                if self.railModuleScroll then self.railModuleScroll:Show() end
                if self.railModuleChild then self.railModuleChild:Show() end
                if self.railSearchWrap then self.railSearchWrap:Show() end
                if self.modSectionHdr then self.modSectionHdr:Show() end
                if self.resetSortBtn then self.resetSortBtn:Show() end
                if self.studioSectionHdr then self.studioSectionHdr:Show() end
                if self.railStudioBtns then
                    for _, sBtn in ipairs(self.railStudioBtns) do
                        if sBtn and sBtn.Show then sBtn:Show() end
                    end
                end
                if self.SyncWorkspaceGeometry then self.SyncWorkspaceGeometry() end
                if self.workspace then self.workspace:Show() end
                addonTable.ApplySuiteThemeAndGeometry()
                if self.RefreshLeftRailLayout then self.RefreshLeftRailLayout() end
                if self.ReflowDlTopTrack then self.ReflowDlTopTrack() end
                if self.UpdateTabActiveIndicators then self.UpdateTabActiveIndicators() end
                if self.UpdateStatusBar then self.UpdateStatusBar() end
                if self.UpdateStashButton then self.UpdateStashButton() end
                if self.UpdateFilterChips then self.UpdateFilterChips() end
                if self.RefreshTelemetryStrip then self.RefreshTelemetryStrip() end
                if self.UpdateResetButtonLabel then self.UpdateResetButtonLabel() end
                if activeWorkspaceView == "DYNAMICLOAD" then
                    if self.scrollFrame and self.scrollFrame.UpdateScrollChildRect then self.scrollFrame:UpdateScrollChildRect() end
                    if self.scrollChild and self.scrollChild.Refresh then self.scrollChild.Refresh() end
                end
                if self.Raise then self:Raise() end
            end)
        end
    end)

    f:SetScript("OnHide", function(self)
        CloseContextMenu()
        if CloseAltDropdown then CloseAltDropdown() end
        if dsColorPicker then dsColorPicker:Hide() end
        UI.CloseAllPopups()
        if not self._minimizedForHudDrag then
            if floatingEditPill then
                floatingEditPill:Hide()
            end
            if addonTable.SetToastEditMode then
                addonTable.SetToastEditMode(false)
            end
            if _G.DynamicLoadToastFrame and not _G.DynamicLoadToastFrame.isRealAlert then
                _G.DynamicLoadToastFrame:Hide()
            end
        end
    end)

    f._initComplete = true
    mainFrame = f
    if _G.DynamicSuite then
        _G.DynamicSuite.MainFrame = mainFrame
        _G.DynamicSuite.mainFrame = mainFrame
    end
    return mainFrame
end

function addonTable.EnsureCombatRestorePill()
    if addonTable.combatRestorePill then return addonTable.combatRestorePill end
    local pill = CreateFrame("Button", "DynamicSuiteCombatPill", UIParent)
    pill:SetSize(212, 30)
    pill:SetFrameStrata("HIGH")
    pill:SetClampedToScreen(true)
    pill:SetMovable(true)
    pill:EnableMouse(true)
    pill:RegisterForDrag("LeftButton")
    local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
    local pPos = gTbl.combatPillPos
    if type(pPos) == "table" and pPos.x ~= nil and pPos.y ~= nil then
        pill:SetPoint("CENTER", UIParent, "CENTER", tonumber(pPos.x) or 0, tonumber(pPos.y) or 320)
    else
        pill:SetPoint("TOP", UIParent, "TOP", 0, -18)
    end
    pill.bg = UI.SolidTex(pill, "BACKGROUND", 0, 0.05, 0.06, 0.09, 0.94)
    pill.bg:SetAllPoints()
    UI.CreatePixelBorder(pill, 0.96, 0.62, 0.04, 0.80, 3)
    pill.dot = UI.SolidTex(pill, "OVERLAY", 2, 0.96, 0.62, 0.04, 1)
    pill.dot:SetSize(7, 7)
    pill.dot:SetPoint("LEFT", pill, "LEFT", 12, 0)
    pill.label = pill:CreateFontString(nil, "OVERLAY")
    pill.label:SetPoint("LEFT", pill.dot, "RIGHT", 8, 0)
    UI.SetFont(pill.label, 11.5, "", 0.98, 0.85, 0.45, 0.98)
    pill.label:SetText("DynamicSuite (In Combat)")
    pill:SetScript("OnDragStart", function(self) self:StartMoving() end)
    pill:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local gStore = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or nil
        if gStore and self.GetCenter and UIParent and UIParent.GetCenter then
            local cx, cy = self:GetCenter()
            local ux, uy = UIParent:GetCenter()
            if cx and cy and ux and uy then
                gStore.combatPillPos = { x = math.floor(cx - ux + 0.5), y = math.floor(cy - uy + 0.5) }
            end
        end
    end)
    pill:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.10, 0.11, 0.15, 0.98)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText("DynamicSuite (In Combat)", 0.98, 0.80, 0.25)
            GameTooltip:AddLine("Click to open in combat-safe read-only mode. Window auto-restores when combat ends.", 0.82, 0.86, 0.92, true)
            GameTooltip:Show()
        end
    end)
    pill:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.05, 0.06, 0.09, 0.94)
        if GameTooltip then GameTooltip:Hide() end
    end)
    pill:SetScript("OnClick", function()
        pill:Hide()
        local state = addonTable._combatCollapsedState
        if state then
            state.manuallyClosedInCombat = false
            if state.workspaceView == "PEER_MODULE" and state.peerModuleKey then
                addonTable.OpenPeerModule(state.peerModuleKey)
                return
            elseif state.workspaceView then
                addonTable.OpenWorkspaceView(state.workspaceView)
                return
            end
        end
        addonTable.ShowConfigUI()
    end)
    pill:Hide()
    addonTable.combatRestorePill = pill
    return pill
end

function addonTable.UpdateCombatLockState()
    if not mainFrame then return end
    local inCombat = InCombatLockdown() and true or false
    mainFrame._inCombatSafeMode = inCombat
    if mainFrame.combatBanner then
        mainFrame.combatBanner:SetShown(inCombat)
    end
    if mainFrame.UpdateStatusBar then
        mainFrame.UpdateStatusBar()
    end
end

function addonTable.OnSuiteEnterCombat()
    if mainFrame and mainFrame:IsShown() then
        addonTable.SaveMainWindowPosition(mainFrame)
        addonTable._combatCollapsedState = {
            wasOpen = true,
            workspaceView = activeWorkspaceView,
            peerModuleKey = selectedPeerModuleKey,
            manuallyClosedInCombat = false,
        }
        addonTable._suppressCombatManualClose = true
        mainFrame:Hide()
        UI.CloseAllPopups()
        addonTable._suppressCombatManualClose = false
        local pill = addonTable.EnsureCombatRestorePill()
        if pill then pill:Show() end
    end
end

function addonTable.OnSuiteLeaveCombat()
    if addonTable.combatRestorePill and addonTable.combatRestorePill:IsShown() then
        addonTable.combatRestorePill:Hide()
    end
    if mainFrame then
        addonTable.UpdateCombatLockState()
    end
    local state = addonTable._combatCollapsedState
    addonTable._combatCollapsedState = nil
    if state and state.wasOpen and not state.manuallyClosedInCombat then
        local f = addonTable.CreateMainConfigUI()
        addonTable.ApplySavedMainWindowPosition(f)
        if state.workspaceView == "PEER_MODULE" and state.peerModuleKey then
            addonTable.OpenPeerModule(state.peerModuleKey)
        else
            addonTable.OpenWorkspaceView(state.workspaceView or "DYNAMICLOAD")
        end
    end
end

function addonTable.ShowConfigUI(forceDynamicLoad)
    if not InCombatLockdown() then
        if SettingsPanel and SettingsPanel:IsShown() then
            if type(_G.HideUIPanel) == "function" then
                pcall(_G.HideUIPanel, SettingsPanel)
            end
            if SettingsPanel:IsShown() and SettingsPanel.Hide then
                pcall(SettingsPanel.Hide, SettingsPanel)
            end
        end
        if GameMenuFrame and GameMenuFrame:IsShown() and GameMenuFrame.Hide then
            pcall(GameMenuFrame.Hide, GameMenuFrame)
        end
    end
    if DynamicLoadDB and (DynamicLoadDB.stagedProfile or DynamicLoadDB.loadedProfile or DynamicLoadDB.activeProfile) then
        selectedTabKey = DynamicLoadDB.stagedProfile or DynamicLoadDB.loadedProfile or DynamicLoadDB.activeProfile
        if addonTable.SetSelectedTabKey then addonTable.SetSelectedTabKey(selectedTabKey) end
    end
    local f = addonTable.CreateMainConfigUI()
    if f and f.RefreshLeftRailLayout then
        f.RefreshLeftRailLayout()
    end
    local dlLoaded = (addonTable.IsDynamicLoadModuleLoaded == true) or C_AddOns.IsAddOnLoaded("DynamicLoad")
    if forceDynamicLoad == true or dlLoaded then
        selectedPeerModuleKey = nil
        addonTable.OpenWorkspaceView("DYNAMICLOAD")
        return f
    end
    for _, m in ipairs(UI.GetOrderedModuleList and UI.GetOrderedModuleList() or {}) do
        local aKey = m.addonName or m.name or m.key
        if aKey and aKey ~= "DynamicLoad" and (C_AddOns.IsAddOnLoaded(aKey) or (_G.DynamicSuite and _G.DynamicSuite.modules and (_G.DynamicSuite.modules[aKey] or _G.DynamicSuite.modules[m.key]))) then
            addonTable.OpenPeerModule(aKey)
            return f
        end
    end
    selectedPeerModuleKey = nil
    addonTable.OpenWorkspaceView("DYNAMICLOAD")
    return f
end

function addonTable.HideConfigUI()
    if mainFrame and mainFrame:IsShown() then
        mainFrame:Hide()
        UI.CloseAllPopups()
    end
end

if not addonTable.ClampAllSuiteHudsToScreen then
    function addonTable.ClampAllSuiteHudsToScreen()
        if InCombatLockdown and InCombatLockdown() then
            addonTable._pendingHudClamp = true
            return false
        end
        local selfFn = addonTable.ClampAllSuiteHudsToScreen
        addonTable.CreateMainConfigUI()
        if addonTable.ClampAllSuiteHudsToScreen and addonTable.ClampAllSuiteHudsToScreen ~= selfFn then
            return addonTable.ClampAllSuiteHudsToScreen()
        end
        return false
    end
end

if not addonTable.ResetAllHudPositions then
    function addonTable.ResetAllHudPositions(silent)
        if InCombatLockdown and InCombatLockdown() then
            addonTable._pendingHudPositionReset = true
            if not silent then
                print("|cFF38BDF8DynamicSuite|r: |cFFF87171Cannot reset HUD positions during combat lockdown.|r Positions will reset safely after combat ends.")
            end
            return false
        end
        local selfFn = addonTable.ResetAllHudPositions
        addonTable.CreateMainConfigUI()
        if addonTable.ResetAllHudPositions and addonTable.ResetAllHudPositions ~= selfFn then
            return addonTable.ResetAllHudPositions(silent)
        end
        return false
    end
end

if not addonTable.EnterHudEditMode then
    function addonTable.EnterHudEditMode(targetKey)
        if InCombatLockdown and InCombatLockdown() then
            print("|cFF38BDF8DynamicSuite|r: |cFFF87171Cannot enter HUD Edit Mode during combat lockdown.|r")
            return false
        end
        local selfFn = addonTable.EnterHudEditMode
        addonTable.CreateMainConfigUI()
        if addonTable.EnterHudEditMode and addonTable.EnterHudEditMode ~= selfFn then
            return addonTable.EnterHudEditMode(targetKey)
        end
        return false
    end
end

function addonTable.ToggleConfigUI(forceShow)
    if DynamicLoadDB and (DynamicLoadDB.stagedProfile or DynamicLoadDB.loadedProfile or DynamicLoadDB.activeProfile) and (not mainFrame or not mainFrame:IsShown()) then
        selectedTabKey = DynamicLoadDB.stagedProfile or DynamicLoadDB.loadedProfile or DynamicLoadDB.activeProfile
        if addonTable.SetSelectedTabKey then addonTable.SetSelectedTabKey(selectedTabKey) end
    end
    local f = addonTable.CreateMainConfigUI()
    if forceShow == true then
        addonTable.ShowConfigUI()
    elseif forceShow == false then
        f:Hide()
        UI.CloseAllPopups()
    elseif f:IsShown() then
        f:Hide()
        UI.CloseAllPopups()
    else
        addonTable.ShowConfigUI()
    end
end
addonTable.ToggleUI = addonTable.ToggleConfigUI

function UI:ToggleMainWindow(forceShow)
    addonTable.ToggleConfigUI(forceShow)
end

--------------------------------------------------------------------------------
-- Game Menu ("Esc -> AddOns" & "Esc -> DynamicSuite" / "DynamicSuite HUD") & Settings Category
--------------------------------------------------------------------------------
function addonTable.RefreshGameMenuButtons()
    -- GameMenuFrame rebuilds its button pool natively via Blizzard's own OnShow/InitButtons lifecycle.
    -- Never invoke GameMenuFrame:InitButtons() directly from addon code to prevent buttonPool taint.
end

function addonTable.HookGameMenu()
    if addonTable._gameMenuHooked then return end
    addonTable._gameMenuHooked = true

    if GameMenuFrame and not addonTable._escHudFailsafeHooked then
        addonTable._escHudFailsafeHooked = true
        GameMenuFrame:HookScript("OnShow", function()
            if addonTable._isHudEditModeActive
                or (_G.DynamicSuiteSnapGridOverlay and _G.DynamicSuiteSnapGridOverlay:IsShown())
                or (_G.DynamicSuiteGridOverlay and _G.DynamicSuiteGridOverlay:IsShown())
                or (_G.DynamicSuiteEditModeModal and _G.DynamicSuiteEditModeModal:IsShown()) then
                if addonTable.ExitHudEditMode then
                    addonTable.ExitHudEditMode(false)
                end
                if not InCombatLockdown() and GameMenuFrame.Hide then
                    GameMenuFrame:Hide()
                end
            end
        end)
    end

    -- 1. Item #38: Intercept Blizzard's AddonList ("Esc -> AddOns") so it opens DynamicLoadMainFrame when enabled
    function addonTable.OpenBlizzardAddonList()
        if type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() then
            print("|cFF38BDF8DynamicSuite:|r Cannot open Blizzard's AddOn list during combat. Please leave combat and try again.")
            return
        end
        addonTable._bypassAddonListHook = true
        if type(_G.ShowUIPanel) == "function" and _G.AddonList then
            _G.ShowUIPanel(_G.AddonList)
        elseif _G.AddonList and _G.AddonList.Show then
            _G.AddonList:Show()
        end
    end

    local function TryHookBlizzardAddonList()
        if _G.AddonList and not addonTable._blizzAddonListHooked then
            addonTable._blizzAddonListHooked = true
            _G.AddonList:HookScript("OnShow", function(self)
                if addonTable._bypassAddonListHook then
                    addonTable._bypassAddonListHook = nil
                    return
                end
                if type(_G.IsShiftKeyDown) == "function" and _G.IsShiftKeyDown() then
                    return
                end
                local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
                if gTbl.replaceBlizzardAddonList == false then
                    return
                end
                local pName = UnitName and UnitName("player")
                if (addonTable.IsAddonFrozen and addonTable.IsAddonFrozen("DynamicSuite"))
                    or (C_AddOns and C_AddOns.GetAddOnEnableState and pName and (C_AddOns.GetAddOnEnableState("DynamicSuite", pName) or 0) == 0) then
                    return
                end
                self:Hide()
                if not InCombatLockdown() and GameMenuFrame and GameMenuFrame:IsShown() then
                    GameMenuFrame:Hide()
                end
                addonTable.ShowConfigUI()
            end)
        end
    end
    TryHookBlizzardAddonList()

    -- 2. Inject "DynamicSuite" & "DynamicSuite HUD" buttons into Retail 11.0 / 12.0 GameMenuFrame
    if GameMenuFrame and GameMenuFrame.InitButtons then
        hooksecurefunc(GameMenuFrame, "InitButtons", function(self)
            TryHookBlizzardAddonList()
            if InCombatLockdown() then return end
            if not self.AddButton then return end

            local gTbl = addonTable.GetSuiteGlobal and addonTable.GetSuiteGlobal() or {}
            local showSuite = (gTbl.showGameMenuSuiteBtn ~= false)
            local showHud   = (gTbl.showGameMenuHudBtn ~= false)
            if not showSuite and not showHud then return end

            local suiteText = UI.FormatTwoToneBrand("Suite")
            local hudText   = UI.FormatTwoToneBrand("Suite") .. " HUD"

            if showSuite then
                self:AddButton(suiteText, function()
                    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION or 856)
                    if not InCombatLockdown() and GameMenuFrame and GameMenuFrame.Hide then
                        GameMenuFrame:Hide()
                    end
                    addonTable.ShowConfigUI()
                end)
            end

            if showHud then
                self:AddButton(hudText, function()
                    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION or 856)
                    if not InCombatLockdown() and GameMenuFrame and GameMenuFrame.Hide then
                        GameMenuFrame:Hide()
                    end
                    if addonTable.EnterHudEditMode then
                        addonTable.EnterHudEditMode("ALL")
                    end
                end)
            end
        end)
    end

    -- 3. Register "DynamicSuite" in Blizzard's Esc -> Options -> AddOns (Settings)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory and not _G.DynamicSuiteSettingsRegistered then
        _G.DynamicSuiteSettingsRegistered = true
        local panel = CreateFrame("Frame", "DynamicSuiteSettingsCanvas", UIParent)
        panel.name = "DynamicSuite"

        local ar, ag, ab = UI.GetActiveAccentColor()
        local card = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        card:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
        card:SetSize(560, 210)
        local cardBg = UI.SolidTex(card, "BACKGROUND", 0, 0.047, 0.055, 0.075, 0.98)
        cardBg:SetAllPoints()
        UI.CreatePixelBorder(card, ar, ag, ab, 0.75, 2)

        local emblem = CreateFrame("Frame", nil, card)
        emblem:SetSize(28, 28)
        emblem:SetPoint("TOPLEFT", card, "TOPLEFT", 18, -18)
        UI.DrawBrandEmblem(emblem, 28)

        local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("LEFT", emblem, "RIGHT", 10, 0)
        title:SetText(UI.FormatTwoToneBrand("Suite") .. "  |cff94a3b8v" .. (addonTable.ADDON_VERSION or "2.2.0") .. "|r")

        local desc = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        desc:SetPoint("TOPLEFT", emblem, "BOTTOMLEFT", 0, -14)
        desc:SetWidth(520)
        desc:SetJustifyH("LEFT")
        desc:SetText("All-in-one WoW suite: focus markers, group finder, prep bar, Great Vault, quest reader, bags, mail, chat, zone addons, FPS, and camera zoom.")

        local slashSummary = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        slashSummary:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
        slashSummary:SetWidth(520)
        slashSummary:SetJustifyH("LEFT")
        slashSummary:SetText("Slash Commands:  /ds (Main Window)   |   /ds hud (HUD Edit)   |   /ds resethud (Reset HUDs)")

        local function HideSettingsPanelSafe()
            if InCombatLockdown and InCombatLockdown() then return end
            if SettingsPanel and SettingsPanel:IsShown() then
                if type(_G.HideUIPanel) == "function" then
                    pcall(_G.HideUIPanel, SettingsPanel)
                end
                if SettingsPanel:IsShown() and SettingsPanel.Hide then
                    pcall(SettingsPanel.Hide, SettingsPanel)
                end
            end
            if GameMenuFrame and GameMenuFrame:IsShown() and GameMenuFrame.Hide then
                pcall(GameMenuFrame.Hide, GameMenuFrame)
            end
        end

        local openBtn = CreateFrame("Button", nil, card, "BackdropTemplate")
        openBtn:SetSize(162, 32)
        openBtn:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 18, 18)
        local openBg = UI.SolidTex(openBtn, "BACKGROUND", 0, ar * 0.28, ag * 0.28, ab * 0.28, 0.98)
        openBg:SetAllPoints()
        UI.CreatePixelBorder(openBtn, ar, ag, ab, 0.95, 2)
        local openLbl = openBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        openLbl:SetPoint("CENTER")
        openLbl:SetText("Open DynamicSuite")
        openBtn:SetScript("OnEnter", function()
            local cr, cg, cb = UI.GetActiveAccentColor()
            openBg:SetColorTexture(cr * 0.42, cg * 0.42, cb * 0.42, 1.0)
        end)
        openBtn:SetScript("OnLeave", function()
            local cr, cg, cb = UI.GetActiveAccentColor()
            openBg:SetColorTexture(cr * 0.28, cg * 0.28, cb * 0.28, 0.98)
        end)
        openBtn:SetScript("OnClick", function()
            HideSettingsPanelSafe()
            local opened = addonTable.ShowConfigUI()
            if opened and opened.Raise then
                opened:Raise()
            end
        end)

        panel:SetScript("OnShow", function()
            UI.RefreshPaletteCache()
            local cr, cg, cb = UI.GetActiveAccentColor()
            local surf = UI.GetActiveSurfaceColors()
            cardBg:SetColorTexture(surf.panel.r, surf.panel.g, surf.panel.b, 0.98)
            if card.dsBorder then card.dsBorder:SetColor(cr, cg, cb, 0.75) end
            if emblem and emblem.SetAccentColor then emblem:SetAccentColor(cr, cg, cb, 1) end
            title:SetText(UI.FormatTwoToneBrand("Suite") .. "  |cff94a3b8v" .. (addonTable.ADDON_VERSION or "2.2.0") .. "|r")
            openBg:SetColorTexture(cr * 0.28, cg * 0.28, cb * 0.28, 0.98)
            if openBtn.dsBorder then openBtn.dsBorder:SetColor(cr, cg, cb, 0.95) end
        end)

        local openHudBtn = CreateFrame("Button", nil, card, "BackdropTemplate")
        openHudBtn:SetSize(174, 32)
        openHudBtn:SetPoint("LEFT", openBtn, "RIGHT", 10, 0)
        local hudBg = UI.SolidTex(openHudBtn, "BACKGROUND", 0, 0.08, 0.10, 0.14, 0.96)
        hudBg:SetAllPoints()
        UI.CreatePixelBorder(openHudBtn, 1, 1, 1, 0.18, 2)
        local hudLbl = openHudBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        hudLbl:SetPoint("CENTER")
        hudLbl:SetText("HUD Edit Mode (/ds hud)")
        openHudBtn:SetScript("OnEnter", function() hudBg:SetColorTexture(0.14, 0.17, 0.22, 1.0) end)
        openHudBtn:SetScript("OnLeave", function() hudBg:SetColorTexture(0.08, 0.10, 0.14, 0.96) end)
        openHudBtn:SetScript("OnClick", function()
            HideSettingsPanelSafe()
            if addonTable.EnterHudEditMode then
                addonTable.EnterHudEditMode("ALL")
            end
        end)

        local resetHudBtn = CreateFrame("Button", nil, card, "BackdropTemplate")
        resetHudBtn:SetSize(168, 32)
        resetHudBtn:SetPoint("LEFT", openHudBtn, "RIGHT", 10, 0)
        local resetHudBg = UI.SolidTex(resetHudBtn, "BACKGROUND", 0, 0.12, 0.08, 0.09, 0.96)
        resetHudBg:SetAllPoints()
        UI.CreatePixelBorder(resetHudBtn, 0.96, 0.62, 0.04, 0.55, 2)
        local resetHudLbl = resetHudBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        resetHudLbl:SetPoint("CENTER")
        resetHudLbl:SetText("Reset HUD Positions")
        resetHudBtn:SetScript("OnEnter", function() resetHudBg:SetColorTexture(0.20, 0.12, 0.13, 1.0) end)
        resetHudBtn:SetScript("OnLeave", function() resetHudBg:SetColorTexture(0.12, 0.08, 0.09, 0.96) end)
        resetHudBtn:SetScript("OnClick", function()
            if addonTable.ResetAllHudPositions then
                addonTable.ResetAllHudPositions(false)
            end
        end)

        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "DynamicSuite")
        if ok and category then
            pcall(Settings.RegisterAddOnCategory, category)
            _G.DynamicSuiteSettingsCategoryID = category.GetID and category:GetID() or nil
        end
    end
end

addonTable.HookGameMenu()

--------------------------------------------------------------------------------
-- DynamicSuite Module Registration ("DynamicLoad" & "load")
--------------------------------------------------------------------------------
do
    _G.DynamicSuite = _G.DynamicSuite or {}
    _G.DynamicSuite.modules = _G.DynamicSuite.modules or {}
    _G.DynamicSuite.UI = UI
    _G.DynamicSuite.UI.COLORS = UI.COLORS
    _G.DynamicSuite.UI.SURFACE_THEMES = UI.SURFACE_THEMES
    _G.DynamicSuite.UI.ACCENT_PRESETS = UI.ACCENT_PRESETS
    _G.DynamicSuite.UI.FONT_FAMILIES = UI.FONT_FAMILIES
    _G.DynamicSuite.UI.FONT_FAMILY_ORDER = UI.FONT_FAMILY_ORDER
    _G.DynamicSuite.UI.GetActiveAccentColor = UI.GetActiveAccentColor
    _G.DynamicSuite.UI.GetActiveSurfaceKey = UI.GetActiveSurfaceKey
    _G.DynamicSuite.UI.GetActiveSurfaceColors = UI.GetActiveSurfaceColors
    _G.DynamicSuite.UI.GetActiveFontKey = UI.GetActiveFontKey
    _G.DynamicSuite.UI.GetFont = UI.GetFont
    _G.DynamicSuite.UI.GetFontPath = UI.GetFont
    _G.DynamicSuite.UI.SetFont = UI.SetFont
    _G.DynamicSuite.UI.ApplyFontRecursively = UI.ApplyFontRecursively
    _G.DynamicSuite.UI.SolidTex = UI.SolidTex
    _G.DynamicSuite.UI.CreateSquareCheckbox = UI.CreateSquareCheckbox
    _G.DynamicSuite.UI.CreateSectionHeader = UI.CreateSectionHeader
    _G.DynamicSuite.UI.CreateDropdown = UI.CreateDropdown
    _G.DynamicSuite.UI.CreateSegmentedPills = UI.CreateSegmentedPills
    _G.DynamicSuite.UI.CreateInlineSubDrawer = UI.CreateInlineSubDrawer
    _G.DynamicSuite.UI.CreateSubDrawerButton = UI.CreateSubDrawerButton
    _G.DynamicSuite.UI.CreateSubDrawerTuneButton = UI.CreateSubDrawerButton
    _G.DynamicSuite.UI.NormalizeEmbeddedSubDrawers = UI.NormalizeEmbeddedSubDrawers
    _G.DynamicSuite.UI.CloseAllPopups = UI.CloseAllPopups
    _G.DynamicSuite.UI.RegisterPopupCloser = UI.RegisterPopupCloser
    _G.DynamicSuite.RegisterPopupCloser = UI.RegisterPopupCloser
    _G.DynamicSuite.GetSuiteAccent = function()
        return UI.GetActiveAccentColor()
    end
    _G.DynamicSuite.GetFont = UI.GetFont
    _G.DynamicSuite.GetFontPath = UI.GetFont
    _G.DynamicSuite.OpenWorkspaceView = addonTable.OpenWorkspaceView
    _G.DynamicSuite.RegisterHudEditCallback = function(selfOrId, idOrFn, maybeFn)
        local id, fn = idOrFn, maybeFn
        if type(selfOrId) ~= "table" then
            id, fn = selfOrId, idOrFn
        end
        if id ~= nil and type(fn) == "function" then
            addonTable.hudEditCallbacks = addonTable.hudEditCallbacks or {}
            addonTable.hudEditCallbacks[id] = fn
            if addonTable._isHudEditModeActive then
                local snap = (type(addonTable.GetHudSnapMode) == "function" and addonTable.GetHudSnapMode()) or "MAGNET"
                pcall(fn, true, addonTable.selectedHudTarget, snap)
            end
        end
    end
    _G.DynamicSuite.IsHudEditModeActive = function()
        return addonTable._isHudEditModeActive == true
    end

    local dlModuleDescriptor = {
        name = "DynamicLoad",
        version = addonTable.ADDON_VERSION or "2.2.0",
        description = "Context-aware addon profile management with parent-child grouping & 3-state security matrix",
        Open = addonTable.ShowConfigUI,
        Show = addonTable.ShowConfigUI,
        Hide = addonTable.HideConfigUI,
        ToggleUI = addonTable.ToggleConfigUI,
        SelectSubTab = addonTable.SelectSubTab,
        SelectTab = addonTable.SelectSubTab,
        ResetModule = addonTable.ResetDynamicLoad,
        EvaluateEnvironment = addonTable.EvaluateCurrentEnvironment,
        ApplyTheme = function() addonTable.ApplySuiteThemeAndGeometry() end,
        ApplyThemeToUI = function() addonTable.ApplySuiteThemeAndGeometry() end,
        RefreshTheme = function() addonTable.ApplySuiteThemeAndGeometry() end,
        GetStatusText = function()
            local isOverride = (addonTable.IsManualOverrideActive and addonTable.IsManualOverrideActive()) or false
            local loadedProf = (addonTable.GetLoadedProfile and addonTable.GetLoadedProfile()) or (DynamicLoadDB and DynamicLoadDB.loadedProfile) or (DynamicLoadDB and DynamicLoadDB.activeProfile) or "outdoor"
            local envDetail = (addonTable.GetEnvironmentDetail and addonTable.GetEnvironmentDetail()) or "Outdoor"
            local deltaCount = (addonTable.CalculateAddonDelta and addonTable.CalculateAddonDelta(selectedTabKey)) or 0
            local profName = (DynamicLoadDB and DynamicLoadDB.profiles and DynamicLoadDB.profiles[loadedProf] and DynamicLoadDB.profiles[loadedProf].name) or loadedProf
            local stagedStr = (deltaCount > 0) and string.format("|cFFF5B82E%d Pending Reload|r", deltaCount) or "|cFF22C55EIn Sync|r"
            if isOverride then
                return string.format("|cFF22C55E|TInterface\\Buttons\\WHITE8X8:6:6:0:0:8:8:0:8:0:8:34:197:94|t Loaded:|r |cFFFFFFFF%s|r |cFFF5B82E[Manual]|r   |   |cFF38BDF8|TInterface\\Buttons\\WHITE8X8:6:6:0:0:8:8:0:8:0:8:56:189:248|t Location:|r |cFFFFFFFF%s|r   |   State: %s", profName, envDetail, stagedStr)
            else
                return string.format("|cFF22C55E|TInterface\\Buttons\\WHITE8X8:6:6:0:0:8:8:0:8:0:8:34:197:94|t Loaded:|r |cFFFFFFFF%s [Auto]|r   |   |cFF38BDF8|TInterface\\Buttons\\WHITE8X8:6:6:0:0:8:8:0:8:0:8:56:189:248|t Location:|r |cFFFFFFFF%s|r   |   State: %s", profName, envDetail, stagedStr)
            end
        end,
    }

    if addonTable.IsDynamicLoadModuleLoaded or C_AddOns.IsAddOnLoaded("DynamicLoad") then
        if _G.DynamicSuite.RegisterModule then
            _G.DynamicSuite:RegisterModule("DynamicLoad", dlModuleDescriptor)
        else
            _G.DynamicSuite.modules["DynamicLoad"] = dlModuleDescriptor
        end
        _G.DynamicSuite.modules["DynamicLoad"] = dlModuleDescriptor
        _G.DynamicSuite.modules["load"] = dlModuleDescriptor
    end

    _G.DynamicSuite.OpenModule = function(selfOrKey, maybeKey)
        local modKey = (type(selfOrKey) == "table") and maybeKey or selfOrKey
        if not mainFrame then
            addonTable.CreateMainConfigUI()
        end
        if not modKey then
            addonTable.ShowConfigUI()
        elseif modKey == "DynamicLoad" or modKey == "load" then
            addonTable.ShowConfigUI(true)
        elseif addonTable.OpenPeerModule then
            addonTable.OpenPeerModule(modKey)
        end
    end
    _G.DynamicSuite.SelectModule = _G.DynamicSuite.OpenModule
    if not addonTable.EnterHudEditMode then
        local stubFn
        stubFn = function(selfOrKey, maybeKey)
            local targetKey = (type(selfOrKey) == "table") and maybeKey or selfOrKey
            if not mainFrame or not mainFrame._initComplete then
                addonTable.CreateMainConfigUI()
            end
            if addonTable.EnterHudEditMode and addonTable.EnterHudEditMode ~= stubFn then
                addonTable.EnterHudEditMode(targetKey)
            end
        end
        addonTable.EnterHudEditMode = stubFn
    end

    function addonTable.OpenWorkspaceViewSafe(viewKey, optionalTabIndex)
        if not mainFrame or not mainFrame._initComplete then
            addonTable.CreateMainConfigUI()
        end
        if addonTable.OpenWorkspaceView then
            addonTable.OpenWorkspaceView(viewKey, optionalTabIndex)
        end
    end

    function addonTable.OpenPeerModuleSafe(targetKey)
        if not mainFrame or not mainFrame._initComplete then
            addonTable.CreateMainConfigUI()
        end
        if addonTable.OpenPeerModule then
            addonTable.OpenPeerModule(targetKey)
        end
    end

    if not addonTable.OpenWorkspaceView then
        local stubOpenView
        stubOpenView = function(viewKey, optionalTabIndex)
            if not mainFrame or not mainFrame._initComplete then
                addonTable.CreateMainConfigUI()
            end
            if addonTable.OpenWorkspaceView and addonTable.OpenWorkspaceView ~= stubOpenView then
                addonTable.OpenWorkspaceView(viewKey, optionalTabIndex)
            end
        end
        addonTable.OpenWorkspaceView = stubOpenView
    end

    if not addonTable.OpenPeerModule then
        local stubOpenPeer
        stubOpenPeer = function(targetKey)
            if not mainFrame or not mainFrame._initComplete then
                addonTable.CreateMainConfigUI()
            end
            if addonTable.OpenPeerModule and addonTable.OpenPeerModule ~= stubOpenPeer then
                addonTable.OpenPeerModule(targetKey)
            end
        end
        addonTable.OpenPeerModule = stubOpenPeer
    end

    function addonTable.OpenSearchViewSafe(initialQuery, categoryKey)
        if not mainFrame or not mainFrame._initComplete then
            addonTable.CreateMainConfigUI()
        end
        if addonTable.OpenSearchView then
            addonTable.OpenSearchView(initialQuery, categoryKey)
        end
    end

    if not addonTable.OpenSearchView then
        addonTable.OpenSearchView = addonTable.OpenSearchViewSafe
    end

    function addonTable.OpenSuiteStudioTabSafe(tabIdx)
        if not mainFrame or not mainFrame._initComplete then
            addonTable.CreateMainConfigUI()
        end
        local t = (tonumber(tabIdx) == 2) and 2 or 1
        if addonTable.OpenWorkspaceView then
            addonTable.OpenWorkspaceView(t == 2 and "SUITE_STUDIO_WINDOWS" or "SUITE_STUDIO_THEME")
        end
        if mainFrame and mainFrame.SetSuiteStudioTab then
            mainFrame.SetSuiteStudioTab(t)
        end
    end

    if not addonTable.OpenSuiteStudioTab then
        addonTable.OpenSuiteStudioTab = addonTable.OpenSuiteStudioTabSafe
    end

    _G.DynamicSuite = _G.DynamicSuite or {}
    _G.DynamicSuite.OpenWorkspaceView  = addonTable.OpenWorkspaceViewSafe
    _G.DynamicSuite.OpenSuiteStudioTab = addonTable.OpenSuiteStudioTabSafe
    _G.DynamicSuite.OpenSearchView     = addonTable.OpenSearchViewSafe
    _G.DynamicSuite.EnterHudEditMode   = addonTable.EnterHudEditMode
    _G.DynamicSuite.EnterEditMode      = addonTable.EnterHudEditMode
    if _G.DynamicLoad or addonTable.IsDynamicLoadModuleLoaded then
        _G.DynamicLoad = _G.DynamicLoad or {}
        _G.DynamicLoad.OpenWorkspaceView  = addonTable.OpenWorkspaceViewSafe
        _G.DynamicLoad.OpenSuiteStudioTab = addonTable.OpenSuiteStudioTabSafe
        _G.DynamicLoad.OpenSearchView     = addonTable.OpenSearchViewSafe
        _G.DynamicLoad.EnterHudEditMode   = addonTable.EnterHudEditMode
        _G.DynamicLoad.EnterEditMode      = addonTable.EnterHudEditMode
    end
end