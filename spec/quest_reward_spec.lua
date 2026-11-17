local mock = require("spec.wow_mock")
local FILES = { "Core.lua", "Locale.lua", "RulesFund.lua", "Vendor.lua", "QuestReward.lua", "UI.lua" }

describe("quest reward hint", function()
  local ns, buttons
  local function complete()
    mock.fire("QUEST_COMPLETE")
    for _ = 1, 5 do mock.flush() end
  end

  before_each(function()
    mock.reset()
    mock.class, mock.level = "WARRIOR", 30 -- wears mail until 40
    mock.links = {
      mailHands = { 24, "INVTYPE_HAND", 4, 3, 300 }, plateHands = { 30, "INVTYPE_HAND", 4, 4, 900 },
      ring = { 22, "INVTYPE_FINGER", 4, 0, 100 }, sword = { 40, "INVTYPE_WEAPON", 2, 7, 2500 },
      oldHands = { 18, "INVTYPE_HAND", 4, 3, 50 }, ring1 = { 25, "INVTYPE_FINGER", 4, 0, 1 },
      ring2 = { 15, "INVTYPE_FINGER", 4, 0, 1 },
    }
    mock.worn = { [10] = "oldHands", [11] = "ring1", [12] = "ring2" }
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
    buttons = {}
    for i = 1, 3 do buttons[i] = mock.widget({ type = "choice", id = i, Icon = mock.widget() }) end
    _G.QuestInfoRewardsFrame = mock.widget({ RewardButtons = buttons })
  end)

  it("recommends the biggest item level upgrade of your armor type, marks it and says why", function()
    mock.choices = { { "plateHands", 1 }, { "mailHands", 1 }, { "sword", 1 } }
    assert.same({ 2, "upgrade: item level 24 over your 18" }, { ns.RewardPick() })
    complete()
    assert.matches("quest reward: mailHands, upgrade: item level 24 over your 18%.$", mock.chat[1])
    assert.equal(1, #mock.chat)
    assert.is_true(buttons[2].shown and true)
    local marked = 0
    for _, w in ipairs(mock.widgets) do
      if rawget(w, "texture") == "Interface\\Buttons\\CheckButtonHilight" and w.shown then marked = marked + 1 end
    end
    assert.equal(1, marked)
    mock.fire("QUEST_FINISHED")
    for _, w in ipairs(mock.widgets) do
      if rawget(w, "texture") == "Interface\\Buttons\\CheckButtonHilight" then assert.is_false(w.shown) end
    end
  end)

  it("compares rings with the lower of the two worn", function()
    mock.choices = { { "ring", 1 }, { "sword", 1 } }
    assert.same({ 1, "upgrade: item level 22 over your 15" }, { ns.RewardPick() })
    mock.class, mock.level = "MAGE", 30 -- a ring suits every class
    assert.equal(1, (ns.RewardPick()))
  end)

  it("without an upgrade: the one that sells for the most, weapons only by price", function()
    mock.worn[10] = "plateHands"
    mock.choices = { { "mailHands", 2 }, { "sword", 1 } }
    assert.same({ 2, "sells for the most: 25s (weapons are not compared)" }, { ns.RewardPick() })
    mock.level = 40 -- plate now: plate hands of a higher level would be the upgrade
    mock.worn[10] = "oldHands"
    mock.choices = { { "plateHands", 1 }, { "mailHands", 1 } }
    assert.equal(1, (ns.RewardPick()))
  end)

  it("waits for item data, needs two choices, and can be turned off", function()
    mock.choices = { { "unknown", 1 }, { "sword", 1 } }
    assert.is_nil(ns.RewardPick())
    complete()
    assert.equal(0, #mock.chat)
    mock.choices = { { "sword", 1 } }
    assert.is_nil(ns.RewardPick())
    mock.choices = { { "mailHands", 1 }, { "sword", 1 } }
    ns.db.rewardHint = false
    complete()
    assert.equal(0, #mock.chat)
  end)
end)
