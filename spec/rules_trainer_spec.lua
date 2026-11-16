local mock = require("spec.wow_mock")
local FILES = { "Core.lua", "Locale.lua", "Questie.lua", "Waypoint.lua", "TrainerData.lua", "RulesTrainer.lua" }

describe("trainer rule", function()
  local ns
  local function tip() return ns.ruleById.trainer.evaluate()[1] end
  local function names()
    local out = {}
    for _, s in ipairs(ns.TrainerSpellsDue()) do out[#out + 1] = s[3] .. ":" .. s[4] end
    return table.concat(out, ",")
  end

  before_each(function()
    mock.reset()
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
  end)

  it("lists what a level-4 Hunter can learn, in level order", function()
    mock.level = 4
    local s = tip()
    assert.equal(80, s.priority)
    assert.equal("Visit your class trainer: 3 new spells (Track Beasts, Aspect of the Monkey, Serpent Sting).", s.what)
  end)

  it("is quiet once everything for the level is known", function()
    mock.level = 4
    mock.known = { [1494] = true, [13163] = true, [1978] = true }
    assert.same({}, ns.ruleById.trainer.evaluate())
  end)

  it("treats a known higher rank as covering the lower ones and shows ranks above 1", function()
    mock.level = 10
    mock.known = { [13549] = true } -- Serpent Sting 2 known; the client no longer reports rank 1
    local due = names()
    assert.falsy(due:find("Serpent Sting", 1, true))
    mock.known = { [1978] = true } -- only rank 1
    assert.truthy(names():find("Serpent Sting:2", 1, true))
  end)

  it("names ranks above 1 in the tip", function()
    ns.TRAINER_SPELLS[99] = { { 1, 9101, "Bolt", 1, 0, false, 0 }, { 2, 9102, "Bolt", 2, 0, false, 0 } }
    mock.classID, mock.level, mock.known = 99, 2, { [9101] = true }
    assert.equal("Visit your class trainer: 1 new spell (Bolt 2).", tip().what)
  end)

  it("leaves out spells a quest teaches (Hunter pet spells)", function()
    mock.level = 10
    local due = names()
    for _, quest in ipairs({ "Call Pet", "Tame Beast", "Feed Pet" }) do
      assert.falsy(due:find(quest, 1, true), quest)
    end
  end)

  it("respects race masks and talent chains", function()
    ns.TRAINER_SPELLS[99] = {
      { 1, 9001, "Orc Only", 0, 2, false, 0 },       -- bit 1 = race ID 2 (Orc)
      { 1, 9002, "Human Only", 0, 1, false, 0 },     -- bit 0 = race ID 1 (Human)
      { 1, 9003, "Skyborne Only", 0, 2 ^ 33, false, 0 },
      { 1, 9004, "Talent", 2, 0, true, 0 },          -- rank 2 of a talent: only once the talent is learned
    }
    mock.classID, mock.level = 99, 10
    assert.equal("Orc Only:0", names())
    mock.raceID = 96 -- Skyborne Windshaper uses bit 33
    assert.equal("Skyborne Only:0", names())
    mock.known = { [9005] = true }
    ns.TRAINER_SPELLS[99][5] = { 1, 9005, "Talent", 1, 0, true, 0 }
    assert.truthy(names():find("Talent:2", 1, true))
  end)

  it("shortens long lists and speaks Romanian", function()
    mock.level = 20
    ns.db.locale = "roRO"
    assert.matches("^Mergi la trainerul de clasa: %d+ de vraji noi %(.+, %.%.%.%)%.$", tip().what)
  end)

  it("is quiet for a class without data", function()
    mock.classID = 42
    assert.same({}, ns.ruleById.trainer.evaluate())
  end)
end)
