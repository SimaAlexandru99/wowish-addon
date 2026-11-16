local mock = require("spec.wow_mock")
local FILES = { "Core.lua", "Locale.lua", "Questie.lua",
  "Waypoint.lua", "RulesCommon.lua" }
local H, Q = mock.header, mock.quest

local function only(ns, ruleId)
  for id in pairs(ns.ruleById) do ns.db.rules[id] = (id == ruleId) end
  return ns.Evaluate()
end

describe("common rules", function()
  local ns
  before_each(function()
    mock.reset()
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
  end)

  it("registers the four rules with their events", function()
    for _, id in ipairs({ "turnin", "talents", "bags", "zone" }) do assert.truthy(ns.ruleById[id], id) end
    assert.truthy(ns.frame.events.QUEST_LOG_UPDATE)
    assert.truthy(ns.frame.events.BAG_UPDATE_DELAYED)
    assert.truthy(ns.frame.events.TRAIT_CONFIG_UPDATED)
    assert.truthy(ns.frame.events.ZONE_CHANGED_NEW_AREA)
    assert.truthy(ns.frame.events.PLAYER_ENTERING_WORLD)
  end)

  describe("quest log", function()
    it("keeps the header, skips hidden quests and bonus objectives", function()
      mock.questLog = {
        H("The Barrens"), Q(1, "A", 20), Q(2, "Hidden", 20, { isHidden = true }), Q(3, "Bonus", 20, { isTask = true }),
        H("Ashenvale"), Q(4, "B", 22, { complete = true }),
      }
      table.insert(mock.questLog, Q(5, nil, 20)) -- title not cached yet
      local log = ns.ReadQuestLog()
      assert.equal(3, #log)
      assert.equal("?", log[3].title)
      assert.same({ "The Barrens", false }, { log[1].header, log[1].complete })
      assert.same({ "Ashenvale", true }, { log[2].header, log[2].complete })
    end)
  end)

  describe("turnin", function()
    it("lists completed quests and stays quiet without any", function()
      mock.questLog = { H("The Barrens"), Q(1, "Open", 20), Q(2, "Done", 20, { complete = true }) }
      local top = only(ns, "turnin")
      assert.equal(1, #top)
      assert.matches("Turn in 1 completed quest: Done%.", top[1].what)
      mock.questLog = { H("The Barrens"), Q(1, "Open", 20) }
      assert.equal(0, #only(ns, "turnin"))
    end)

    it("shortens long lists", function()
      mock.questLog = { H("Z") }
      for i = 1, 6 do mock.questLog[#mock.questLog + 1] = Q(i, "Q" .. i, 20, { complete = true }) end
      assert.matches("Turn in 6 .-: Q1, Q2, Q3, Q4, %.%.%.%.$", only(ns, "turnin")[1].what)
    end)
  end)

  describe("talents", function()
    it("sums class and spec points", function()
      mock.talents = { true, 1, 2 }
      local top = only(ns, "talents")
      assert.matches("You have 3 unspent", top[1].what)
      assert.equal(95, top[1].priority)
    end)

    it("is quiet with no points or without the API", function()
      mock.talents = { false, 0, 0 }
      assert.equal(0, #only(ns, "talents"))
      _G.C_ClassTalents = nil
      assert.equal(0, #only(ns, "talents"))
    end)
  end)

  describe("bags", function()
    it("warns at 4 free regular slots and ignores quiver and reagent bag", function()
      mock.bags = {
        [0] = { slots = 16, free = 2 }, [1] = { slots = 10, free = 2 },
        [2] = { slots = 18, free = 18, family = 1 }, -- quiver: free slots do not count
        [5] = { slots = 30, free = 30 },               -- reagent bag: never read
      }
      local top = only(ns, "bags")
      assert.matches("4 free slots of 26", top[1].what)
      assert.equal(65, top[1].priority)
      mock.bags[0].free, mock.bags[1].free = 0, 0
      assert.equal(86, only(ns, "bags")[1].priority) -- nothing fits: loot is lost now
      mock.bags[0].free, mock.bags[1].free = 3, 2
      assert.equal(0, #only(ns, "bags"))
    end)
  end)

  describe("zone", function()
    it("picks the zone with most open quests near your level", function()
      mock.level = 21
      mock.questLog = {
        H("The Barrens"), Q(1, "B1", 20), Q(2, "B2", 22), Q(3, "B3", 30), -- 30 is too high
        H("Ashenvale"), Q(4, "A1", 21), Q(5, "Adone", 21, { complete = true }),
      }
      local top = only(ns, "zone")
      assert.matches("Keep questing in The Barrens: 2 open quest", top[1].what)
      assert.matches("50%% of level 21", top[1].why)
      assert.same({ open = "map", arg = 1413 }, top[1].action) -- The Barrens on the player's continent
    end)

    it("never suggests dungeon, raid, PvP or profession quests", function()
      mock.level = 18
      mock.questLog = {
        H("Wailing Caverns"), Q(1, "W1", 18, { tagID = 81 }), Q(2, "W2", 18, { tagID = 81 }),
        Q(3, "W3", 18, { tagID = 81 }),
        H("Warsong Gulch"), Q(4, "PvP", 18, { tagID = 41 }), Q(5, "PvP2", 18, { tagID = 41 }),
        H("Cooking"), Q(6, "C1", 18, { tagID = 0, tradeskillLineID = 185 }),
        Q(7, "C2", 18, { tagID = 0, tradeskillLineID = 185 }),
        H("The Barrens"), Q(8, "B1", 18),
      }
      assert.matches("in The Barrens: 1 open", only(ns, "zone")[1].what)
    end)

    it("falls back to known headers when the tag API is missing", function()
      mock.level = 18
      mock.questLog = { H("Wailing Caverns"), Q(1, "W1", 18), Q(2, "W2", 18), H("The Barrens"), Q(3, "B1", 18) }
      _G.C_QuestLog.GetQuestTagInfo = nil
      assert.matches("in The Barrens", only(ns, "zone")[1].what)
    end)

    it("is quiet when nothing fits", function()
      mock.questLog = { H("Far"), Q(1, "X", 40) }
      assert.equal(0, #only(ns, "zone"))
    end)
  end)
end)
