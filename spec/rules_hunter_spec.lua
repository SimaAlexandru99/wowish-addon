local mock = require("spec.wow_mock")
local FILES = { "Core.lua", "Locale.lua", "Questie.lua",
  "Waypoint.lua", "RulesCommon.lua", "RulesHunter.lua" }

local BOW, GUN, XBOW, THROWN = 3036, 2511, 5000, 2947

describe("hunter ammo rule", function()
  local ns
  local function ammo()
    return ns.ruleById.ammo.evaluate()
  end
  local function load()
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
  end
  local function bagWith(...)
    mock.bags = { [0] = { slots = 16, items = { ... } } }
  end

  before_each(function()
    mock.reset()
    mock.ranged, mock.level = BOW, 25
  end)

  it("suggests the level-25 arrow over Sharp Arrow for a bow", function()
    load()
    bagWith(2515)
    local s = ammo()[1]
    assert.equal("ammo:3030", s.id)
    assert.equal(85, s.priority)
    assert.matches("buy Razor Arrow %(level 25%) instead of Sharp Arrow", s.what)
  end)

  it("follows the weapon, not the bags: gun with old arrows and Heavy Shot -> Solid Shot", function()
    mock.ranged = GUN
    load()
    bagWith(2512, 2519)
    local s = ammo()[1]
    assert.equal("ammo:3033", s.id)
    assert.matches("instead of Heavy Shot", s.what)
  end)

  it("trusts other ammo of the right kind (crafted, dropped) and stays quiet", function()
    load()
    bagWith(18042) -- Thorium Headed Arrow: not in the vendor table
    assert.same({}, ammo())
    bagWith(2512, 18042)
    assert.same({}, ammo())
  end)

  it("ignores other ammo of the wrong kind", function()
    mock.ranged = GUN
    load()
    bagWith(18042) -- arrows with a gun
    assert.equal(88, ammo()[1].priority)
  end)

  it("treats a crossbow like a bow", function()
    mock.ranged = XBOW
    load()
    bagWith(2515)
    assert.equal("ammo:3030", ammo()[1].id)
  end)

  it("warns louder when there is no matching ammo at all", function()
    mock.ranged = GUN
    load()
    bagWith(2515) -- arrows only
    local s = ammo()[1]
    assert.equal(88, s.priority)
    assert.matches("No bullets in your bags: buy Solid Shot", s.what)
  end)

  it("is quiet when the best ammo for the level is already in the bags", function()
    load()
    bagWith(2515, 3030)
    assert.same({}, ammo())
    bagWith(3030, 2515) -- best tier first: the lower one found later must not win
    assert.same({}, ammo())
    mock.level = 24
    bagWith(2515)
    assert.same({}, ammo())
  end)

  it("is quiet for other classes, thrown weapons and an empty ranged slot", function()
    load()
    bagWith()
    mock.class = "MAGE"
    assert.same({}, ammo())
    mock.class, mock.ranged = "HUNTER", THROWN
    assert.same({}, ammo())
    mock.ranged = nil
    assert.same({}, ammo())
  end)

  it("uses the client's localized item name when it has one", function()
    load()
    bagWith(2515)
    _G.C_Item.GetItemNameByID = function(id) return id == 3030 and "Fleche rasoir" or "Fleche aceree" end
    assert.matches("buy Fleche rasoir %(level 25%) instead of Fleche aceree", ammo()[1].what)
  end)

  describe("vendor from QuestieDB", function()
    before_each(function()
      mock.questieDB({}, {
        [1] = { name = "HordeNear", friendly = "H", spawns = { [17] = { { 55, 55 } } } },
        [2] = { name = "HordeFar", friendly = "AH", spawns = { [17] = { { 90, 90 } } } },
        [3] = { name = "AllianceOnly", friendly = "A", spawns = { [17] = { { 50, 50 } } } },
        [4] = { name = "OtherMap", friendly = "H", spawns = { [331] = { { 50, 50 } } } },
        [5] = { name = "Roamer", friendly = "H", spawns = { [17] = { { 51, 51 }, { 52, 52 } } } },
      }, {}, true, { [3030] = { 1, 2, 3, 4, 5 } })
    end)

    it("points at the nearest friendly single-spawn vendor on your map", function()
      load()
      bagWith(2515)
      local s = ammo()[1]
      assert.equal("Wowish: Razor Arrow (HordeNear)", s.waypoint.title)
      assert.near(0.55, s.waypoint.x, 1e-9)
      assert.matches("HordeNear sells it", s.why)
    end)

    it("respects faction", function()
      mock.faction = "Alliance"
      load()
      bagWith(2515)
      assert.equal("Wowish: Razor Arrow (AllianceOnly)", ammo()[1].waypoint.title)
    end)

    it("gives no waypoint when no vendor is on your map", function()
      mock.playerMap = 1456
      load()
      bagWith(2515)
      local s = ammo()[1]
      assert.is_nil(s.waypoint)
      assert.equal("ammo:3030", s.id)
    end)
  end)
end)
