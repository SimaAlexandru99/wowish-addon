std = "lua51"
max_line_length = 120
exclude_files = { "addon", ".luarocks", "lua_modules", ".release" }

-- Globals the addon defines (SavedVariables, slash command glue).
globals = { "WowishDB", "SLASH_WOWISH1", "SlashCmdList", "UISpecialFrames", "Wowish_OnAddonCompartmentClick",
  "BINDING_HEADER_WOWISH", "BINDING_NAME_WOWISH_TOGGLE" }

-- WoW client API (Mainline family / Forever) the addon reads. Extend when a new call is added.
read_globals = {
  "CreateFrame", "C_Timer", "InCombatLockdown", "UnitAffectingCombat", "UnitName",
  "UnitLevel", "UnitXP", "UnitXPMax", "C_QuestLog", "C_ClassTalents", "C_Container",
  "C_Map", "C_SuperTrack", "UiMapPoint",
  "UnitClass", "UnitRace", "C_SpellBook", "C_Spell", "IsSpellKnown", "IsPlayerSpell", "UnitFactionGroup", "GetInventoryItemID", "INVSLOT_RANGED", "C_Item", "Enum",
  "DEFAULT_CHAT_FRAME", "UIParent", "TomTom", "time", "strtrim", "geterrorhandler", "Minimap", "GameTooltip", "GetCursorPosition",
  "CreateVector2D", "IsIndoors", "C_CVar", "GetPlayerFacing", "OpenWorldMap", "GetBindingKey", "GetBindingText", "C_AddOns", "GetAddOnMetadata", "GetBuildInfo", "GetLocale",
  "debugprofilestop", "GetInventoryItemDurability", "GetMoney", "C_Reputation", "C_SkillInfo",
  "ButtonFrameTemplate_HidePortrait", "ButtonFrameTemplate_HideButtonBar",
  "Settings", "CreateSettingsButtonInitializer", "MinimalSliderWithSteppersMixin", "C_SettingsUtil",
  "securecallfunction",
}

files["Locale.lua"] = { max_line_length = false } -- long translated sentences
files["Welcome.lua"] = { max_line_length = false } -- whole sentences are lookup keys
files["spec/**/*.lua"] = { std = "+busted", globals = { "_G" } }
