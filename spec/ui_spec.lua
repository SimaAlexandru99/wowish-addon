local mock = require("spec.wow_mock")
local FILES = { "Core.lua", "Locale.lua", "Questie.lua",
  "Waypoint.lua", "MinimapGuide.lua", "Navigation.lua", "RulesCommon.lua", "RulesHunter.lua", "RulesFund.lua",
  "UI.lua", "Welcome.lua",
  "SettingsPanel.lua" }

local function slash(msg) SlashCmdList.WOWISH(msg) end

describe("UI", function()
  local ns
  local function setTips(list)
    ns.suggestions = list
    for _, cb in ipairs(ns.callbacks) do cb(list) end
  end
  local TIPS = {
    { id = "talents", kind = "talent", priority = 95, what = "Spend 1 point.", why = "Power." },
    { id = "turnin:1413", kind = "quest", priority = 90, what = "Turn in 2 quests.", why = "XP.",
      waypoint = { map = 1413, x = 0.5, y = 0.4, title = "Wowish: Q (Thork)" } },
    { id = "bags", kind = "bags", priority = 65, what = "Bags almost full.", why = "Loot." },
  }

  before_each(function()
    mock.reset()
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
  end)

  it("registers /wowish and the Addon Compartment entry", function()
    assert.equal("/wowish", SLASH_WOWISH1)
    assert.is_function(SlashCmdList.WOWISH)
    assert.is_function(Wowish_OnAddonCompartmentClick)
  end)

  it("asks for fresh tips when the window opens", function()
    slash("")
    assert.equal(1, #mock.timers) -- throttled update scheduled
  end)

  it("toggles the window from slash and compartment, Escape-closable", function()
    slash("")
    assert.is_true(ns.IsShown())
    assert.same({ "WowishFrame" }, UISpecialFrames)
    Wowish_OnAddonCompartmentClick()
    assert.is_false(ns.IsShown())
  end)

  it("refuses to open in combat and hides when combat starts", function()
    mock.combat = true
    slash("")
    assert.is_false(ns.IsShown())
    assert.matches("in combat", mock.lastChat())
    mock.combat = false
    slash("show")
    assert.is_true(ns.IsShown())
    mock.fire("PLAYER_REGEN_DISABLED")
    assert.is_false(ns.IsShown())
  end)

  describe("cards", function()
    before_each(function()
      slash("")
      setTips(TIPS)
    end)

    local function cards()
      local out = {}
      for _, f in ipairs(mock.frames) do
        if f.template == "BackdropTemplate" and f.shown then out[#out + 1] = f end
      end
      return out
    end

    it("shows one card per tip, waypoint button only when a place is known", function()
      local c = cards()
      assert.equal(3, #c)
      assert.equal("|cffffd1001.|r Spend 1 point.", c[1].what.text)
      assert.equal("Interface\\Icons\\INV_Misc_Book_11", c[1].icon.texture)
      assert.is_false(c[1].go.shown)
      assert.is_true(c[2].go.shown)
    end)

    it("hides a tip for the session until its text changes", function()
      cards()[1].hide:Click()
      assert.equal(2, #ns.Visible())
      assert.equal(2, #cards())
      setTips(TIPS)
      assert.equal(2, #ns.Visible())
      local changed = { { id = "talents", kind = "talent", priority = 95, what = "Spend 2 points.", why = "" } }
      setTips(changed)
      assert.equal(1, #ns.Visible())
    end)

    it("numbers waypoints by visible position", function()
      cards()[1].hide:Click()
      slash("go 1")
      assert.same({ map = 1413, x = 0.5, y = 0.4 }, mock.waypoint)
      assert.matches("waypoint set: Wowish: Q %(Thork%) %(The Barrens 50%.0, 40%.0%)", mock.lastChat())
    end)

    it("shows the empty state only when nothing is left", function()
      local function emptyShown()
        for _, w in ipairs(mock.widgets) do
          if (rawget(w, "text") or ""):find("^Nothing urgent") then return w.shown end
        end
      end
      assert.is_false(emptyShown())
      setTips({})
      assert.equal(0, #cards())
      assert.is_true(emptyShown())
    end)
  end)

  describe("/wowish go", function()
    before_each(function() setTips(TIPS) end)

    it("explains tips without a place and unknown numbers", function()
      slash("go 1")
      assert.matches("tip 1 has no known place", mock.lastChat())
      slash("go 9")
      assert.matches("there is no tip 9", mock.lastChat())
    end)

    it("falls back to coordinates in chat, and clear removes only ours", function()
      mock.canWaypoint = false
      slash("go 2")
      assert.matches("Go to The Barrens 50%.0, 40%.0", mock.lastChat())
      mock.canWaypoint = true
      slash("go 2")
      slash("clear")
      assert.is_nil(mock.waypoint)
      assert.matches("waypoint removed", mock.lastChat())
      slash("clear")
      assert.matches("no Wowish waypoint", mock.lastChat())
    end)

    it("shows help for unknown input and survives errors", function()
      slash("  HELP ")
      assert.matches("/wowish go N", mock.lastChat())
      ns.Go = function() error("boom") end
      slash("go 1")
      assert.matches("error: .*boom", mock.lastChat())
      assert.matches("boom", mock.reported[1])
    end)
  end)

  describe("login line", function()
    it("prints once after the first evaluation following login", function()
      ns.RegisterRule({ id = "t", evaluate = function() return { { id = "x", priority = 1, what = "Do X." } } end })
      mock.fire("PLAYER_LOGIN")
      mock.flush()
      assert.equal("|cff33ff99Wowish|r: 1 tip. #1: Do X. (/wowish)", mock.lastChat())
      local n = #mock.chat
      ns.Evaluate()
      assert.equal(n, #mock.chat)
    end)

    it("says nothing urgent, and stays silent when turned off", function()
      mock.fire("PLAYER_LOGIN")
      mock.flush()
      assert.matches("nothing urgent", mock.lastChat())
      mock.chat = {}
      ns.db.loginLine = false
      mock.fire("PLAYER_LOGIN")
      mock.flush()
      assert.equal(0, #mock.chat)
    end)
  end)

  describe("level-up line", function()
    before_each(function() ns.rules, ns.ruleById = {}, {} end) -- only the tips each test registers
    local function rule(id, what)
      ns.RegisterRule({ id = id, evaluate = function() return { { id = id, priority = 50, what = what } } end })
    end
    local function levelUp() mock.fire("PLAYER_LEVEL_UP", 24); mock.flush() end

    it("sums up the trainer and talent tips with the cost", function()
      rule("trainer", "Visit your class trainer: 2 new spells.")
      rule("talents", "You have 1 unspent talent point.")
      levelUp()
      local line = mock.lastChat()
      assert.matches("Level 24: ", line)
      assert.matches("Visit your class trainer: 2 new spells%.", line)
      assert.matches("You have 1 unspent talent point%.", line)
      assert.matches("Next class training: about %d+g", line)
    end)

    it("says nothing when nothing is due, or when turned off", function()
      rule("bags", "Bags almost full.")
      levelUp()
      assert.equal(0, #mock.chat)
      rule("talents", "You have 1 unspent talent point.")
      ns.db.levelLine = false
      levelUp()
      assert.equal(0, #mock.chat)
    end)

    it("is not used up by a hidden tip's notification before the evaluation", function()
      rule("talents", "You have 1 unspent talent point.")
      mock.fire("PLAYER_LEVEL_UP", 24)
      ns.NotifyChanged() -- the player hid a card within the throttle
      assert.equal(0, #mock.chat)
      mock.flush()
      assert.matches("Level 24: You have 1 unspent", mock.lastChat())
    end)

    it("waits for the end of combat", function()
      rule("talents", "You have 1 unspent talent point.")
      mock.combat = true
      levelUp()
      assert.equal(0, #mock.chat)
      mock.combat = false
      mock.fire("PLAYER_REGEN_ENABLED")
      mock.flush()
      assert.matches("Level 24: You have 1 unspent", mock.lastChat())
    end)
  end)

  it("restores saved position and scale", function()
    ns.db.pos, ns.db.scale = { "TOPLEFT", "TOPLEFT", 100, -50 }, 0.9
    slash("")
    assert.equal(0.9, _G.WowishFrame.scale)
    assert.same({ "TOPLEFT", UIParent, "TOPLEFT", 100, -50 }, _G.WowishFrame.point)
  end)

  it("prints a report to paste into bug reports", function()
    ns.RegisterRule({ id = "broken", evaluate = function() error("boom") end })
    ns.Evaluate()
    mock.chat = {}
    slash("report")
    assert.matches("Wowish v0%.3%.0%-test | game 1%.60%.1 %(70938%) | enUS", mock.chat[1])
    assert.matches("QuestieDB: missing | TomTom: no | ShortestPathForever: no", mock.chat[2])
    assert.matches("tips: %d+ | hidden: 0 | failing rules: broken", mock.chat[3])
    assert.matches("error 1: .*boom", mock.chat[4])
    for i = 1, 5 do ns.report("e" .. i) end
    assert.same({ "e5", "e4", "e3" }, ns.recentErrors) -- newest first, only three kept
  end)

  it("formats the update age", function()
    assert.equal("not updated yet", ns.AgeText(nil))
    assert.equal("updated just now", ns.AgeText(mock.now - 30))
    assert.equal("updated 3 min ago", ns.AgeText(mock.now - 200))
  end)
end)
