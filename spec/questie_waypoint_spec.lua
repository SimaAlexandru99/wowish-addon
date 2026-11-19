local mock = require("spec.wow_mock")
local FILES = { "Core.lua", "Locale.lua", "Questie.lua",
  "Waypoint.lua", "RulesCommon.lua" }
local H, Q = mock.header, mock.quest

local function turnins(ns)
  for id in pairs(ns.ruleById) do ns.db.rules[id] = (id == "turnin") end
  return ns.Evaluate()
end

describe("QuestieDB integration", function()
  local ns
  local function load()
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
  end
  before_each(mock.reset)

  it("works without QuestieDB: no place, status 'missing'", function()
    load()
    local place, reason = ns.QuestFinisher(1)
    assert.is_nil(place)
    assert.equal("noquestie", reason)
    assert.equal("missing", ns.questieStatus)
  end)

  it("refuses an incompatible contract", function()
    mock.questieDB({}, {}, {}, false)
    load()
    assert.is_nil(ns.Questie())
    assert.equal("contract mismatch", ns.questieStatus)
  end)

  it("maps a single-spawn NPC to uiMapId and 0..1 coordinates", function()
    mock.questieDB({ [10] = { npc = 3429 } }, { [3429] = { name = "Thork", spawns = { [17] = { { 51.9, 30.4 } } } } })
    load()
    local p = ns.QuestFinisher(10)
    assert.same({ map = 1413, name = "Thork" }, { map = p.map, name = p.name })
    assert.near(0.519, p.x, 1e-9)
    assert.near(0.304, p.y, 1e-9)
  end)

  it("uses an object finisher when there is no NPC", function()
    mock.questieDB({ [11] = { object = 99 } }, {}, { [99] = { name = "Chest", spawns = { [331] = { { 10, 20 } } } } })
    load()
    assert.equal(1440, ns.QuestFinisher(11).map)
  end)

  it("never guesses: several spawns, no spawn, instance-only, hidden area", function()
    mock.questieDB(
      { [1] = { npc = 1 }, [2] = { npc = 2 }, [3] = { npc = 3 }, [4] = { npc = 4 } },
      {
        [1] = { name = "Twice", spawns = { [17] = { { 1, 1 }, { 2, 2 } } } },
        [2] = { name = "Nowhere", spawns = {} },
        [3] = { name = "Inside", spawns = { [17] = { { -1, -1 } } } },
        [4] = { name = "Hidden", spawns = { [400] = { { 5, 5 } } } }, -- override maps area 400 to 0
      })
    load()
    local expected = { "ambiguous", "nospawn", "nospawn", "nomap" }
    for id = 1, 4 do
      local place, reason = ns.QuestFinisher(id)
      assert.is_nil(place)
      assert.equal(expected[id], reason, "quest " .. id)
    end
  end)

  it("asks QuestieDB once per quest and per vendor item in a session", function()
    mock.questieDB({ [10] = { npc = 3429 } },
      { [3429] = { name = "Thork", friendly = "AH", spawns = { [17] = { { 51.9, 30.4 } } } } },
      {}, true, { [3030] = { 3429 } })
    local calls = { quest = 0, item = 0 }
    local finishedBy, vendorsOf = _G.LibQuestieDB.Quest.finishedBy, _G.LibQuestieDB.Item.vendors
    _G.LibQuestieDB.Quest.finishedBy = function(id) calls.quest = calls.quest + 1 return finishedBy(id) end
    _G.LibQuestieDB.Item.vendors = function(id) calls.item = calls.item + 1 return vendorsOf(id) end
    load()
    for _ = 1, 3 do
      assert.equal(1413, ns.QuestFinisher(10).map)
      assert.equal(1, #ns.ItemVendors(3030, "Horde"))
    end
    assert.same({ quest = 1, item = 1 }, calls)
    ns.ItemVendors(3030, "Alliance") -- other faction: its own answer
    assert.equal(2, calls.item)
  end)

  it("reports a QuestieDB error once, not on every evaluation", function()
    mock.questieDB({}, {})
    _G.LibQuestieDB.Quest.finishedBy = function() error("schema changed") end
    load()
    for _ = 1, 3 do assert.equal("error", select(2, ns.QuestFinisher(1))) end
    assert.equal(1, #mock.reported)
  end)

  it("reads QuestieDB zone tables without access to globals", function()
    mock.questieDB({ [10] = { npc = 1 } }, { [1] = { name = "N", spawns = { [17] = { { 50, 50 } } } } })
    local zdb = _G.LibQuestieDB.Support.Get()
    _G.LibQuestieDB.Support.Get = function()
      -- a global write lands in the sandbox; a global read sees nothing (LibQuestieDB exists outside)
      zdb.private.areaIdToUiMapId = "WowishDB = 'pwned'; return { [17] = LibQuestieDB and 1440 or 1413 }"
      return zdb
    end
    load()
    assert.equal(1413, ns.QuestFinisher(10).map)
    assert.is_not_equal("pwned", _G.WowishDB)
  end)

  it("survives a QuestieDB that throws", function()
    mock.questieDB({}, {})
    _G.LibQuestieDB.Quest.finishedBy = function() error("schema changed") end
    load()
    local place, reason = ns.QuestFinisher(1)
    assert.is_nil(place)
    assert.equal("error", reason)
    assert.matches("schema changed", mock.reported[1])
  end)

  describe("turn-in advice with locations", function()
    before_each(function()
      mock.questieDB(
        { [1] = { npc = 1 }, [2] = { npc = 2 }, [3] = { npc = 3 }, [4] = { npc = 4 }, [5] = { npc = 5 } },
        {
          [1] = { name = "Near", spawns = { [17] = { { 52, 52 } } } },
          [2] = { name = "Far", spawns = { [17] = { { 90, 90 } } } },
          [3] = { name = "Ash", spawns = { [331] = { { 10, 10 } } } },
          [4] = { name = "Bluff", spawns = { [1638] = { { 40, 40 } } } },
          [5] = { name = "Twice", spawns = { [17] = { { 1, 1 }, { 2, 2 } } } },
        })
      load()
      mock.questLog = {
        H("The Barrens"), Q(2, "FarQ", 20, { complete = true }), Q(1, "NearQ", 20, { complete = true }),
        Q(5, "Unknown", 20, { complete = true }),
        H("Ashenvale"), Q(3, "AshQ", 22, { complete = true }), Q(6, "OpenAsh", 22),
        H("Mulgore"), Q(4, "BluffQ", 20, { complete = true }),
      }
    end)

    it("groups by map and ranks: here > unknown > on the way > elsewhere", function()
      local byId = {}
      for _, s in ipairs(turnins(ns)) do byId[s.id] = s end
      local all = ns.ruleById.turnin.evaluate()
      assert.equal(4, #all)
      local prio = {}
      for _, s in ipairs(all) do prio[s.id] = s.priority end
      assert.same({ ["turnin:1413"] = 90, ["turnin:?"] = 70, ["turnin:1440"] = 68, ["turnin:1456"] = 60 }, prio)
      assert.equal(2, #ns.Visible()) -- maxInTop = 2
      assert.matches("Turn in 2 quests in The Barrens: NearQ, FarQ", byId["turnin:1413"].what)
    end)

    it("re-ranks after a zone change", function()
      ns.Evaluate()
      assert.equal("turnin:1413", ns.suggestions[1].id)
      mock.playerMap = 1440 -- travelled to Ashenvale
      mock.fire("ZONE_CHANGED_NEW_AREA")
      mock.flush()
      local prio = {}
      for _, s in ipairs(ns.ruleById.turnin.evaluate()) do prio[s.id] = s.priority end
      assert.equal(90, prio["turnin:1440"])
      assert.equal(60, prio["turnin:1413"])
      assert.equal("turnin:1440", ns.suggestions[1].id)
    end)

    it("points the waypoint at the nearest turn-in on your map", function()
      local here = ns.ruleById.turnin.evaluate()[1]
      assert.equal(1413, here.waypoint.map)
      assert.near(0.52, here.waypoint.x, 1e-9)
      assert.equal("Wowish: NearQ (Near)", here.waypoint.title)
    end)
  end)
end)

describe("waypoints", function()
  local ns
  local place = { map = 1413, x = 0.5, y = 0.25 }
  before_each(function()
    mock.reset()
    ns = mock.load(FILES)
  end)

  it("prefers TomTom and removes only its own waypoint", function()
    local added, removed = {}, {}
    _G.TomTom = {
      AddWaypoint = function(_, map, x, y, opts) added[#added + 1] = { map, x, y, opts } return "uid1" end,
      RemoveWaypoint = function(_, uid) removed[#removed + 1] = uid end,
    }
    assert.equal("tomtom", ns.SetWaypoint(place, "T"))
    assert.same({ 1413, 0.5, 0.25 }, { added[1][1], added[1][2], added[1][3] })
    assert.is_false(added[1][4].persistent)
    assert.equal("Wowish", added[1][4].from)
    assert.is_nil(mock.waypoint)
    assert.is_true(ns.ClearWaypoint())
    assert.same({ "uid1" }, removed)
  end)

  it("falls back to the native waypoint and super-tracks it", function()
    assert.equal("native", ns.SetWaypoint(place, "T"))
    assert.same({ map = 1413, x = 0.5, y = 0.25 }, mock.waypoint)
    assert.is_true(mock.superTracked)
    ns.ClearWaypoint()
    assert.is_nil(mock.waypoint)
  end)

  it("does not clear a pin the player placed after ours", function()
    assert.equal("native", ns.SetWaypoint(place, "T"))
    mock.waypoint = { map = 1440, x = 0.1, y = 0.1 } -- player moved the pin
    assert.is_false(ns.ClearWaypoint())
    assert.same({ map = 1440, x = 0.1, y = 0.1 }, mock.waypoint)
  end)

  it("falls back to the native pin when TomTom refuses", function()
    _G.TomTom = { AddWaypoint = function() return nil end, RemoveWaypoint = function() end }
    assert.equal("native", ns.SetWaypoint(place, "T"))
    assert.same({ map = 1413, x = 0.5, y = 0.25 }, mock.waypoint)
  end)

  it("does not clear a waypoint the player set", function()
    mock.waypoint = { map = 1, x = 0, y = 0 }
    assert.is_false(ns.ClearWaypoint())
    assert.same({ map = 1, x = 0, y = 0 }, mock.waypoint)
  end)

  it("falls back to chat when the map takes no waypoint", function()
    mock.canWaypoint = false
    assert.equal("chat", ns.SetWaypoint(place, "T"))
    assert.matches("The Barrens 50%.0, 25%.0", ns.FormatPlace(place))
  end)

  it("refuses in combat", function()
    mock.combat = true
    assert.equal("combat", ns.SetWaypoint(place, "T"))
    assert.is_nil(mock.waypoint)
  end)
end)
