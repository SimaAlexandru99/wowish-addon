local mock = require("spec.wow_mock")
local FILES = { "Core.lua", "Locale.lua", "Questie.lua",
  "Waypoint.lua", "MinimapGuide.lua", "Navigation.lua", "RulesCommon.lua", "RulesHunter.lua",
  "UI.lua", "Welcome.lua", "SettingsPanel.lua" }
local H, Q = mock.header, mock.quest

local function texts()
  local out = {}
  for _, w in ipairs(mock.widgets) do
    local t = rawget(w, "text")
    if t then out[#out + 1] = t end
  end
  return table.concat(out, "\n")
end

describe("localization", function()
  local ns
  before_each(function()
    mock.reset()
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
  end)

  it("counts in English with singular and plural", function()
    assert.equal("1 quest", ns.Count(1, "quest"))
    assert.equal("0 quests", ns.Count(0, "quest"))
    assert.equal("3 free slots", ns.Count(3, "free slot"))
  end)

  it("counts in Romanian, with 'de' from 20 except numbers ending in 01-19", function()
    ns.db.locale = "roRO"
    assert.equal("1 quest", ns.Count(1, "quest"))
    assert.equal("2 questuri", ns.Count(2, "quest"))
    assert.equal("19 sloturi libere", ns.Count(19, "free slot"))
    assert.equal("20 de sloturi libere", ns.Count(20, "free slot"))
    assert.equal("101 questuri", ns.Count(101, "quest"))
    assert.equal("100 de questuri", ns.Count(100, "quest"))
  end)

  it("translates rule texts and keeps English as the fallback", function()
    mock.questLog = { H("The Barrens"), Q(1, "Done", 20, { complete = true }) }
    assert.equal("Turn in 1 completed quest: Done.", ns.ruleById.turnin.evaluate()[1].what)
    ns.db.locale = "roRO"
    assert.equal("Preda 1 quest terminat: Done.", ns.ruleById.turnin.evaluate()[1].what)
    assert.equal("not a known key", ns.L["not a known key"])
  end)

  it("has no Romanian text with diacritics and no stale keys", function()
    -- every Romanian key must be an English text the addon really uses
    local src = {}
    for _, f in ipairs(FILES) do
      local fh = assert(io.open(f))
      src[#src + 1] = fh:read("*a")
      fh:close()
    end
    src = table.concat(src)
    for key, value in pairs(ns.RO_KEYS) do
      assert.truthy(src:find(key, 1, true), "unused Romanian key: " .. key)
      assert.falsy(value:find("[\128-\255]"), "non-ASCII Romanian text: " .. value)
    end
  end)
end)

describe("welcome", function()
  local ns
  before_each(function()
    mock.reset()
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
  end)

  it("opens once after the first login and never again", function()
    mock.fire("PLAYER_LOGIN")
    mock.flush() -- evaluation + the 3 s welcome delay
    assert.is_true(ns.IsWelcomeShown())
    assert.is_true(ns.db.welcomeSeen)
    assert.matches("QuestieDB not found", texts())
    assert.matches("TomTom not found", texts())
    -- next session
    mock.reset()
    _G.WowishDB = { welcomeSeen = true }
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
    mock.fire("PLAYER_LOGIN")
    mock.flush()
    assert.is_false(ns.IsWelcomeShown())
  end)

  it("does not open in combat; /wowish welcome reopens it", function()
    mock.fire("PLAYER_LOGIN")
    mock.combat = true
    mock.flush()
    assert.is_false(ns.IsWelcomeShown())
    assert.is_false(ns.db.welcomeSeen)
    assert.equal(0, #mock.chat) -- no "in combat" message at login
    mock.combat = false
    SlashCmdList.WOWISH("welcome")
    assert.is_true(ns.IsWelcomeShown())
  end)

  it("reports helpers it finds", function()
    mock.questieDB({}, {})
    _G.TomTom = { AddWaypoint = function() end }
    assert.matches("QuestieDB found.*TomTom found.*ShortestPathForever not found", ns.HelperStatus())
    _G.ShortestPathForever = { API = { Navigate = function() end } }
    assert.matches("ShortestPathForever found", ns.HelperStatus())
  end)

  it("switches the language from its checkbox, live", function()
    ns.ShowWelcome()
    local cb
    for _, f in ipairs(mock.frames) do
      if f.template == "UICheckButtonTemplate" and rawget(f.label, "text"):find("Romanian") then cb = f end
    end
    cb:SetChecked(true)
    cb:Click()
    assert.equal("roRO", ns.db.locale)
    assert.equal("Bun venit in Wowish", _G.WowishWelcomeFrame.title)
    assert.matches("Limba romana", texts())
    assert.matches("Arata sfaturile", texts())
  end)
end)

describe("settings page", function()
  local ns
  before_each(function()
    mock.reset()
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
    mock.fire("PLAYER_LOGIN")
  end)

  it("registers under AddOns with a toggle per rule", function()
    assert.equal(4242, mock.registeredCategory:GetID())
    for _, id in ipairs({ "turnin", "talents", "bags", "zone", "ammo" }) do
      assert.truthy(ns.ruleById[id], id)
      assert.truthy(mock.settings["Wowish_rule_" .. id], id)
    end
  end)

  it("turning a rule off stores only 'off' and stops its tips", function()
    local s = mock.settings.Wowish_rule_bags
    assert.is_true(s.get())
    s.set(false)
    assert.is_false(ns.db.rules.bags)
    mock.bags = { [0] = { slots = 16, free = 0 } }
    mock.flush()
    for _, tip in ipairs(ns.suggestions) do assert.not_equal("bags", tip.rule) end
    s.set(true)
    assert.is_nil(ns.db.rules.bags)
  end)

  it("changes scale, login line and language", function()
    mock.settings.Wowish_scale.set(1.2)
    assert.equal(1.2, ns.db.scale)
    mock.settings.Wowish_loginLine.set(false)
    assert.is_false(ns.db.loginLine)
    mock.settings.Wowish_locale.set(true)
    assert.is_true(ns.IsRomanian())
  end)

  it("resets the window position and reopens the welcome", function()
    ns.db.pos = { "TOPLEFT", "TOPLEFT", 5, 5 }
    mock.buttons["Window position"]()
    assert.is_nil(ns.db.pos)
    mock.buttons["Welcome screen"]()
    assert.is_true(ns.IsWelcomeShown())
  end)

  it("opens through the secure entry point, or explains where it is", function()
    assert.is_true(ns.OpenSettings())
    assert.equal(4242, mock.openedCategory)
    mock.combat = true
    assert.is_false(ns.OpenSettings())
    assert.matches("Options > AddOns > Wowish", mock.lastChat())
  end)

  it("keeps the addon working when the settings API is missing", function()
    mock.reset()
    _G.Settings = nil
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
    mock.fire("PLAYER_LOGIN")
    assert.is_false(ns.OpenSettings())
    SlashCmdList.WOWISH("")
    assert.is_true(ns.IsShown())
  end)
end)
