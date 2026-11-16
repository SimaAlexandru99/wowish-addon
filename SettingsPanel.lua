-- Wowish page in the game's Settings panel (Options > AddOns > Wowish).
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
-- Same pattern as Forever addons (AdventureGuideForever): proxy settings over WowishDB, rows added through
-- Settings.RegisterInitializer, and the panel opened through the client's own secure entry point.
local _, ns = ...
local L = ns.L

local category

local RULE_LABELS = {
  { "turnin", "Quests to hand in" }, { "talents", "Unspent talent points" }, { "bags", "Bag space" },
  { "zone", "Where to quest next" }, { "ammo", "Hunter: ammo" }, { "trainer", "Class trainer" },
  { "repair", "Repairs" }, { "fund", "Gold for riding" },
}

local function checkbox(key, name, get, set, tooltip)
  local setting = Settings.RegisterProxySetting(category, "Wowish_" .. key, Settings.VarType.Boolean,
    name, true, get, set)
  Settings.RegisterInitializer(category, Settings.CreateCheckboxInitializer(setting, nil, tooltip))
end

local function button(name, text, onClick)
  Settings.RegisterInitializer(category, CreateSettingsButtonInitializer(name, text, onClick, nil, false))
end

function ns.RegisterSettings()
  if category or type(Settings) ~= "table" or type(Settings.RegisterVerticalLayoutCategory) ~= "function" then
    return
  end
  category = Settings.RegisterVerticalLayoutCategory("Wowish")

  checkbox("locale", L["Romanian language (Romana)"], function() return ns.IsRomanian() end, function(on)
    ns.db.locale = on and "roRO" or false
    ns.OnLocaleChanged()
  end, L["Labels in this settings page change after /reload."])
  checkbox("loginLine", L["One-line summary in chat at login"],
    function() return ns.db.loginLine end, function(on) ns.db.loginLine = on end)
  checkbox("minimapButton", L["Show the minimap button"], function() return ns.db.minimapButton end, function(on)
    ns.db.minimapButton = on
    ns.UpdateMinimapButton()
  end)
  checkbox("nextBar", L["Show the next tip under the minimap"], function() return ns.db.nextBar end, function(on)
    ns.db.nextBar = on
    ns.UpdateNextBar()
  end)

  local scale = Settings.RegisterProxySetting(category, "Wowish_scale", Settings.VarType.Number or "number",
    L["Window scale"], 1, function() return ns.db.scale end, function(v)
      ns.db.scale = v
      ns.ApplyLayout()
    end)
  local options = Settings.CreateSliderOptions(0.7, 1.5, 0.05)
  if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
      return string.format("%d%%", math.floor(v * 100 + 0.5))
    end)
  end
  Settings.RegisterInitializer(category, Settings.CreateSliderInitializer(scale, options))

  for _, r in ipairs(RULE_LABELS) do
    local id = r[1]
    checkbox("rule_" .. id, L["Tips"] .. ": " .. L[r[2]], function() return ns.db.rules[id] ~= false end,
      function(on)
        if on then ns.db.rules[id] = nil else ns.db.rules[id] = false end -- only "off" is stored
        ns.RequestUpdate()
      end)
  end

  button(L["Window position"], L["Reset"], function()
    ns.db.pos = nil
    ns.ApplyLayout()
  end)
  button(L["Welcome screen"], L["Show"], function() ns.ShowWelcome() end)

  Settings.RegisterAddOnCategory(category)
end

-- Open our page. The client's restricted opener must be entered through securecallfunction
-- (calling the Lua wrapper from addon code can be blocked); otherwise tell the player where it is.
function ns.OpenSettings()
  if category and not ns.inCombat() and type(securecallfunction) == "function"
      and C_SettingsUtil and type(C_SettingsUtil.OpenSettingsPanel) == "function" then
    securecallfunction(C_SettingsUtil.OpenSettingsPanel, category:GetID())
    return true
  end
  ns.Say(L["Open Game Menu > Options > AddOns > Wowish."])
  return false
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
  local ok, err = xpcall(ns.RegisterSettings, ns.report)
  if not ok then ns.Say("settings: " .. tostring(err)) end -- the addon still works without its page
end)
