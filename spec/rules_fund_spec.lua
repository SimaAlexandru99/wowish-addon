local mock = require("spec.wow_mock")
local FILES = { "Core.lua", "Locale.lua", "TrainerData.lua", "RulesFund.lua" }

local G = 10000 -- copper per gold
local ORGRIMMAR, APPRENTICE = 76, 33388

describe("gold for riding", function()
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

  it("tracks savings for Apprentice Riding from level 30, more urgent at 38-39", function()
    local s = fund()[1]
    assert.equal("Save for Apprentice Riding at level 40: 63g of 100g.", s.what)
    assert.equal(30, s.priority)
    assert.matches("Dual spec", s.why)
    mock.level = 38
    assert.equal(60, fund()[1].priority)
    mock.level = 29
    assert.equal(0, #fund())
  end)

  it("once saved before 40: a low card with what is free to spend; quiet between the tiers", function()
    mock.money = 123 * G
    local s = fund()[1]
    assert.equal(20, s.priority)
    assert.equal("Riding gold is ready: keep 100g for Apprentice Riding at level 40, 23g is free to spend.", s.what)
    mock.level, mock.money = 45, 0
    assert.equal(0, #fund())
  end)

  it("takes 10% off at Honored with the home faction, never for Skyborne", function()
    mock.reputation[ORGRIMMAR] = 6
    assert.matches("of 90g%.$", fund()[1].what)
    mock.reputation[ORGRIMMAR] = 5 -- Friendly
    assert.matches("of 100g%.$", fund()[1].what)
    mock.reputation[ORGRIMMAR] = 6
    mock.raceID = 95 -- Skyborne: no discount even if Honored somewhere
    assert.matches("of 100g%.$", fund()[1].what)
  end)

  it("skips Apprentice Riding for paladins and warlocks, not Journeyman", function()
    for _, class in ipairs({ "PALADIN", "WARLOCK" }) do
      mock.class, mock.level = class, 34
      assert.equal(0, #fund(), class)
      mock.level = 55
      assert.matches("Journeyman", fund()[1].what, class)
    end
  end)

  it("at 40: shortfall rounded up, then the way to your race's riding trainer", function()
    mock.level, mock.money = 40, 99 * G + 5000 -- 50s short shows as 1g, not 0g
    local s = fund()[1]
    assert.equal(70, s.priority)
    assert.equal("Apprentice Riding costs 100g: you need 1g more.", s.what)
    mock.money = 100 * G
    s = fund()[1]
    assert.equal(85, s.priority)
    assert.equal("Train Apprentice Riding at your race's riding trainer: you have the 100g.", s.what)
    assert.same({ 1454, "Wowish: Kildar (riding trainer)" }, { s.waypoint.map, s.waypoint.title }) -- Orgrimmar
    mock.raceID = 95
    assert.equal(2521, fund()[1].waypoint.map) -- Skyborne: Zephras Isle
  end)

  it("Journeyman at 60: 1000g, 900g at Honored", function()
    mock.level, mock.money, mock.ridingMax = 52, 400 * G, 75 -- has Apprentice
    assert.equal("Save for Journeyman Riding at level 60: 400g of 1000g.", fund()[1].what)
    mock.reputation[ORGRIMMAR] = 7
    assert.matches("of 900g%.$", fund()[1].what)
  end)

  it("stops once riding is learned: by spell, or by the riding skill when the spell ID differs", function()
    mock.level, mock.money = 40, 100 * G
    mock.known[APPRENTICE] = true
    assert.equal(0, #fund())
    mock.known[APPRENTICE] = nil
    mock.ridingMax = 75
    assert.equal(0, #fund())
    mock.level, mock.money = 60, 1000 * G
    assert.equal(85, fund()[1].priority) -- Apprentice only: Journeyman still to train
    mock.ridingMax = 150
    assert.equal(0, #fund())
  end)

  it("keeps the riding price as the reserve the vendor helpers must not spend", function()
    assert.equal(100 * G, ns.RidingReserve())
    mock.reputation[ORGRIMMAR] = 6
    assert.equal(90 * G, ns.RidingReserve())
    mock.class = "WARLOCK"
    assert.equal(0, ns.RidingReserve())
    mock.class, mock.level = "HUNTER", 45
    assert.equal(0, ns.RidingReserve())
  end)

  it("names the next class training: estimate until the trainer was seen at this level", function()
    assert.matches("Next class training: about 7g %(estimate%)%.$", fund()[1].why) -- 54c x 34^2 = 6g 24s
    mock.trainer = { { "Two-Handed Axes", "", "available", 1000 } } -- a weapon master: not class training
    mock.fire("TRAINER_SHOW")
    assert.matches("%(estimate%)", fund()[1].why)
    mock.trainer = { { "Arcane Shot", "Rank 3", "available", 1800 }, { "Track", "", "used", 900 },
      { "Volley", "", "unavailable", 9000 } }
    mock.fire("TRAINER_SHOW")
    assert.matches("Next class training: 1g%.$", fund()[1].why)
    mock.level = 36
    assert.matches("%(estimate%)", fund()[1].why)
  end)

  it("has a Romanian text for every message", function()
    ns.db.locale = "roRO"
    assert.matches("^Strange pentru Apprentice Riding", fund()[1].what)
  end)
end)
