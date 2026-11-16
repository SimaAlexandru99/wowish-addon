local mock = require("spec.wow_mock")
local FILES = { "Core.lua", "Locale.lua", "RulesFund.lua" }

local G = 10000 -- copper per gold
local ORGRIMMAR, RIDING = 76, 33388

describe("gold for riding at 40", function()
  local ns
  local function fund()
    return ns.ruleById.fund.evaluate()
  end

  before_each(function()
    mock.reset()
    mock.class, mock.raceID, mock.level, mock.money = "HUNTER", 2, 34, 63 * G + 5000 -- orc, 63g 50s
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
  end)

  it("tracks savings from level 30, more urgent at 38-39", function()
    local s = fund()[1]
    assert.equal("Save for riding at level 40: 63g of 100g.", s.what)
    assert.equal(30, s.priority)
    assert.matches("Dual spec", s.why)
    mock.level = 38
    assert.equal(60, fund()[1].priority)
    mock.level = 29
    assert.equal(0, #fund())
  end)

  it("is quiet once the gold is saved before 40", function()
    mock.money = 100 * G
    assert.equal(0, #fund())
  end)

  it("takes 10% off at Honored with the home faction, never for Skyborne", function()
    mock.reputation[ORGRIMMAR] = 6
    assert.equal("Save for riding at level 40: 63g of 90g.", fund()[1].what)
    mock.reputation[ORGRIMMAR] = 5 -- Friendly
    assert.matches("of 100g", fund()[1].what)
    mock.reputation[ORGRIMMAR] = 6
    mock.raceID = 95 -- Skyborne: no discount even if Honored somewhere
    assert.matches("of 100g", fund()[1].what)
  end)

  it("says nothing to paladins and warlocks, who get riding from a class quest", function()
    for _, class in ipairs({ "PALADIN", "WARLOCK" }) do
      mock.class = class
      assert.equal(0, #fund(), class)
    end
  end)

  it("at 40: train now when the gold is there, else the exact shortfall rounded up", function()
    mock.level, mock.money = 40, 100 * G
    local s = fund()[1]
    assert.equal(85, s.priority)
    assert.matches("Train Apprentice Riding", s.what)
    mock.money = 99 * G + 5000 -- 99g 50s: 50s short shows as 1g, not 0g
    s = fund()[1]
    assert.equal(70, s.priority)
    assert.equal("Riding costs 100g: you need 1g more.", s.what)
  end)

  it("stops once riding is learned, and after level 41 in any case", function()
    mock.level, mock.money = 40, 100 * G
    mock.known[RIDING] = true
    assert.equal(0, #fund())
    mock.known[RIDING] = nil
    mock.level = 42
    assert.equal(0, #fund())
  end)

  it("has a Romanian text for every message", function()
    ns.db.locale = "roRO"
    assert.matches("^Strange pentru riding", fund()[1].what)
  end)
end)
