local mock = require("spec.wow_mock")
local FILES = { "Core.lua", "Locale.lua", "Questie.lua", "Waypoint.lua", "MinimapGuide.lua", "Navigation.lua",
  "TrainerData.lua", "RulesTrainer.lua", "RulesRepair.lua", "Services.lua", "UI.lua" }

-- The player stands in The Barrens (1413) at 0.5, 0.5. Area 17 = The Barrens, 331 = Ashenvale, 1638 = Thunder Bluff.
local NPCS = {
  [1] = {
    name = "Near Hunter", sub = "Hunter Trainer", flags = 16, friendly = "H", spawns = { [17] = { { 52, 50 } } } },
  [2] = {
    name = "Far Hunter", sub = "Hunter Trainer", flags = 16, friendly = "H", spawns = { [1638] = { { 50, 50 } } } },
  [3] = {
    name = "Pet Guy", sub = "Pet Trainer", flags = 16, friendly = "H", spawns = { [17] = { { 50, 51 } } } },
  [4] = {
    name = "Ally Hunter", sub = "Hunter Trainer", flags = 16, friendly = "A", spawns = { [17] = { { 50, 50 } } } },
  [5] = {
    name = "Flyer", sub = "Wind Rider Master", flags = 8, friendly = "H", spawns = { [17] = { { 51, 30 } } } },
  [6] = {
    name = "Smith", sub = "Armorer", flags = 16384 + 4, friendly = "AH", spawns = { [17] = { { 55, 55 } } } },
  [7] = {
    name = "Twice", sub = "Armorer", flags = 16384, friendly = "H", spawns = { [17] = { { 1, 1 }, { 2, 2 } } } },
  [8] = {
    name = "Nobody", sub = "Cook", flags = 0, friendly = "H", spawns = { [17] = { { 50, 50 } } } },
}

local function scan()
  for _ = 1, 100 do
    mock.clock = mock.clock + 10 -- each frame: budget exhausted after one NPC
    for _, f in ipairs(mock.frames) do
      if f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.02) end
    end
  end
end

describe("services", function()
  local ns
  before_each(function()
    mock.reset()
    mock.playerMap, mock.playerX, mock.playerY = 1413, 0.5, 0.5
    mock.questieDB({}, NPCS)
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
  end)

  it("scans in the background after login and keeps friendly single-spawn services", function()
    mock.fire("PLAYER_LOGIN")
    assert.equal("idle", ns.ServiceScanState())
    mock.flush() -- the 10 s delay
    assert.equal("scanning", ns.ServiceScanState())
    scan()
    assert.equal("done", ns.ServiceScanState())
    assert.equal("Pet Guy", ns.NearestService("trainer").place.name) -- nearest of any trainer kind
    assert.equal("Flyer", ns.NearestService("flight").place.name)
    assert.equal("Smith", ns.NearestService("repair").place.name) -- Twice has two spawns: skipped
  end)

  it("spreads the work over frames and pauses in combat", function()
    local t = 0
    _G.debugprofilestop = function() t = t + 1 return t end -- every check costs 1 ms: 2 ms budget = ~2 NPCs a frame
    ns.StartServiceScan()
    local runner
    for _, f in ipairs(mock.frames) do if f.scripts.OnUpdate then runner = f end end
    runner.scripts.OnUpdate(runner, 0)
    assert.equal("scanning", ns.ServiceScanState()) -- 8 NPCs do not fit in one frame
    mock.combat = true
    for _ = 1, 20 do runner.scripts.OnUpdate(runner, 0) end
    assert.equal("scanning", ns.ServiceScanState()) -- paused in combat
    mock.combat = false
    for _ = 1, 20 do
      local tick = runner.scripts.OnUpdate -- removed once the scan is done
      if tick then tick(runner, 0) end
    end
    assert.equal("done", ns.ServiceScanState())
  end)

  it("is unavailable without QuestieDB and then finds nothing", function()
    _G.LibQuestieDB = nil
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
    ns.StartServiceScan()
    assert.equal("unavailable", ns.ServiceScanState())
    assert.is_nil(ns.NearestService("trainer"))
  end)

  describe("places you visited", function()
    local function visit(kind)
      mock.merchant = { repairCost = 100 }
      if kind == "repair" then mock.fire("MERCHANT_SHOW") else ns.LearnPlace("trainer") end
    end

    it("uses a learned repair place when QuestieDB is absent", function()
      _G.LibQuestieDB = nil
      visit("repair")
      mock.playerX = 0.6
      local e, yards = ns.NearestService("repair")
      assert.equal("Vendor Joe", e.place.name)
      assert.is_true(yards > 0)
      mock.durability = { [7] = { 15, 100 } }
      assert.equal("Wowish: Vendor Joe (repairs)", ns.ruleById.repair.evaluate()[1].waypoint.title)
    end)

    it("ignores a place learned by the other faction", function()
      visit("repair")
      mock.faction = "Alliance"
      assert.is_nil(ns.NearestService("repair"))
    end)

    it("ignores a trainer place of another class in the trainer rule", function()
      visit("trainer")
      mock.class = "MAGE"
      mock.level = 4
      assert.is_nil(ns.NearestService("trainer", function(e) return e.class == "MAGE" end))
      assert.same({}, { ns.ruleById.trainer.evaluate()[1].waypoint })
    end)

    it("sends the trainer tip to a visited trainer of the player's class", function()
      mock.secretNames["Vendor Joe"] = true -- no name stored
      visit("trainer")
      mock.level = 4
      local w = ns.ruleById.trainer.evaluate()[1].waypoint
      assert.equal(1413, w.map)
      assert.matches("a trainer you visited", w.title)
    end)

    it("skips a malformed entry without error", function()
      ns.db.places.repair["bad"] = { map = 1413, y = 0.5, faction = "H" }
      assert.is_nil(ns.NearestService("repair"))
      ns.db.places.repair["odd"] = { map = 1413, x = 0.5, y = 0.5, faction = "H", name = {} }
      mock.durability = { [7] = { 15, 100 } }
      assert.matches("a vendor you visited", ns.ruleById.repair.evaluate()[1].waypoint.title)
    end)

    it("stores a secret NPC name as no name", function()
      mock.secretNames["Vendor Joe"] = true
      visit("repair")
      local _, p = next(ns.db.places.repair)
      assert.is_nil(p.name)
    end)
  end)

  describe("with the scan done", function()
    before_each(function()
      ns.StartServiceScan()
      scan()
    end)

    it("sends the trainer tip to the nearest trainer of the player's class", function()
      mock.level = 4
      local s = ns.ruleById.trainer.evaluate()[1]
      assert.equal("Wowish: Near Hunter (Hunter Trainer)", s.waypoint.title)
      assert.equal(1413, s.waypoint.map)
    end)

    it("moves the trainer tip up and says so when the trainer is within 200 yards", function()
      mock.level = 4
      local s = ns.ruleById.trainer.evaluate()[1] -- Near Hunter is 80 yards away
      assert.equal(88, s.priority)
      assert.matches("It is right here: 80 yards away", s.why)
      mock.playerX, mock.playerY = 0.6, 0.6
      s = ns.ruleById.trainer.evaluate()[1]
      assert.equal(80, s.priority)
      assert.is_nil(s.why:find("right here", 1, true))
    end)

    it("does the same for the repair tip", function()
      mock.durability = { [7] = { 15, 100 } }
      local s = ns.ruleById.repair.evaluate()[1] -- Smith is 283 yards away
      assert.equal(75, s.priority)
      assert.is_nil(s.why:find("right here", 1, true))
      mock.playerX, mock.playerY = 0.54, 0.54
      s = ns.ruleById.repair.evaluate()[1]
      assert.equal(83, s.priority)
      assert.matches("It is right here: 57 yards away", s.why)
    end)

    it("never lifts a tip above 100", function()
      assert.equal(100, ns.NearBoost({ priority = 97, why = "x" }, 10).priority)
      assert.equal(97, ns.NearBoost({ priority = 97, why = "x" }, nil).priority)
    end)

    it("warns about gear before it breaks, louder when almost broken", function()
      mock.durability = { [5] = { 50, 100 }, [7] = { 30, 100 } }
      assert.same({}, ns.ruleById.repair.evaluate())
      mock.durability[7] = { 15, 100 }
      local s = ns.ruleById.repair.evaluate()[1]
      assert.equal(75, s.priority)
      assert.matches("one item is at 15%% durability", s.what)
      assert.equal("Wowish: Smith (Armorer)", s.waypoint.title)
      mock.durability[7] = { 4, 100 }
      assert.equal(90, ns.ruleById.repair.evaluate()[1].priority)
    end)

    it("names the nearest flight master for far targets when there is no route planner", function()
      local far = { map = 1440, x = 0.5, y = 0.5 } -- Ashenvale, thousands of yards away
      assert.equal("Flyer", ns.FlightHint(far).place.name)
      assert.is_nil(ns.FlightHint({ map = 1413, x = 0.52, y = 0.5 })) -- 80 yards: walk
      _G.ShortestPathForever = { API = { Navigate = function() return true end } }
      assert.is_nil(ns.FlightHint(far))
    end)

    it("prints the flight hint after a plain waypoint", function()
      ns.suggestions = { { id = "t", priority = 90, what = "Far quest.",
        waypoint = { map = 1440, x = 0.5, y = 0.5, title = "Wowish: far" } } }
      SlashCmdList.WOWISH("go 1")
      assert.matches("Nearest flight master: Flyer", mock.lastChat())
    end)
  end)
end)

describe("repair rule thresholds", function()
  local ns
  before_each(function()
    mock.reset()
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
  end)

  it("stays quiet at 20% and above, and when nothing can break", function()
    assert.same({}, ns.ruleById.repair.evaluate())
    mock.durability[1] = { 20, 100 }
    assert.same({}, ns.ruleById.repair.evaluate())
  end)

  it("speaks below 20% and is urgent below 5%, using the lowest item", function()
    mock.durability[1] = { 100, 100 }
    mock.durability[2] = { 19, 100 }
    local tip = ns.ruleById.repair.evaluate()[1]
    assert.equal(75, tip.priority)
    mock.durability[3] = { 4, 100 }
    assert.equal(90, ns.ruleById.repair.evaluate()[1].priority)
  end)
end)
