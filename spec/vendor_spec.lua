local mock = require("spec.wow_mock")
local FILES = { "Core.lua", "Locale.lua", "Questie.lua", "Waypoint.lua", "MinimapGuide.lua", "Navigation.lua",
  "RulesHunter.lua", "RulesFund.lua", "Vendor.lua", "UI.lua" }

local G = 10000
local GREY, WHITE, SHARP = 900, 901, 2515 -- Sharp Arrow: level 10 vendor arrow

describe("vendor helpers", function()
  local ns
  local function visit(merchant)
    mock.merchant = merchant or { items = {} }
    mock.fire("MERCHANT_SHOW")
    while mock.flush() > 0 do end -- the sale ticks
  end

  before_each(function()
    mock.reset()
    mock.class, mock.level, mock.money = "WARRIOR", 25, 50 * G
    mock.itemInfo[GREY] = { sell = 250, stack = 20 }
    mock.itemInfo[WHITE] = { sell = 900, stack = 20 }
    mock.bags[0] = { slots = 3, items = {
      { itemID = GREY, quality = 0, stackCount = 2 },
      { itemID = WHITE, quality = 1, stackCount = 1 },
      { itemID = GREY, quality = 0, stackCount = 1, hasNoValue = true },
    } }
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
  end)

  it("does nothing until the player turns a helper on", function()
    visit({ items = {}, repairCost = 5000 })
    assert.same({}, mock.used)
    assert.is_false(mock.repaired)
    assert.equal(0, #mock.chat)
  end)

  it("sells only grey items worth money, repairs after, and says it in one line", function()
    ns.db.auto.sell, ns.db.auto.repair = true, true
    visit({ items = {}, repairCost = 12345 })
    assert.same({ { 0, 1 } }, mock.used)
    assert.is_true(mock.repaired)
    assert.equal(1, #mock.chat)
    assert.matches("sold 1 grey item %(5s%); repaired %(1g 23s%)%.$", mock.chat[1])
  end)

  it("never sells once the merchant closed, or an item that moved into the slot", function()
    ns.db.auto.sell = true
    for slot = 1, 8 do mock.bags[0].items[slot] = { itemID = GREY, quality = 0, stackCount = 1 } end
    mock.bags[0].slots = 8
    mock.merchant = { items = {} }
    mock.fire("MERCHANT_SHOW")
    assert.equal(6, #mock.used) -- first tick
    mock.itemInfo[902] = { sell = 100, stack = 1 }
    mock.bags[0].items[7] = { itemID = 902, quality = 0, stackCount = 1 } -- another grey moved in meanwhile
    mock.flush()
    assert.same({ 0, 8 }, mock.used[7]) -- slot 7 kept: not the item that was queued
    assert.equal(7, #mock.used)

    mock.used = {}
    for slot = 1, 8 do mock.bags[0].items[slot] = { itemID = GREY, quality = 0, stackCount = 1 } end
    mock.fire("MERCHANT_SHOW")
    mock.merchant = nil -- window gone without its event: a use now would equip or use the item
    mock.flush()
    assert.equal(6, #mock.used)
    mock.merchant = { items = {} }
    mock.fire("MERCHANT_CLOSED")
    mock.flush()
    assert.equal(6, #mock.used)
  end)

  it("resets an ammo stack count out of range", function()
    _G.WowishDB = { auto = { ammoStacks = 50 } }
    mock.fire("ADDON_LOADED", "Wowish")
    assert.equal(3, ns.db.auto.ammoStacks)
  end)

  it("skips everything with Shift held, in combat, and leaves sell and repair to OneForAll or Polestar", function()
    ns.db.auto.sell, ns.db.auto.repair = true, true
    mock.shift = true
    visit({ items = {}, repairCost = 100 })
    mock.shift, mock.combat = false, true
    visit({ items = {}, repairCost = 100 })
    mock.combat = false
    mock.loaded.OneForAll = true
    visit({ items = {}, repairCost = 100 })
    assert.same({}, mock.used)
    assert.is_false(mock.repaired)
    assert.equal("OneForAll", ns.VendorOwner())
  end)

  it("says when gold is short for the repair", function()
    ns.db.auto.repair, mock.money = true, 50
    visit({ items = {}, repairCost = 100 })
    assert.is_false(mock.repaired)
    assert.matches("not enough gold to repair %(1s%)", mock.chat[1])
  end)

  describe("Hunter ammo", function()
    local ARROWS = { items = { { 2512, 10, 200, 200 }, { SHARP, 50, 200, 200 } } } -- per 200 arrows

    before_each(function()
      mock.class, mock.ranged = "HUNTER", 3036 -- bow
      mock.itemInfo[SHARP] = { sell = 0, stack = 200 }
      ns.db.auto.ammo = true
    end)

    it("tops up to the stacks set with the best arrow for the level, in whole merchant stacks", function()
      mock.counts[SHARP] = 150
      visit(ARROWS)
      assert.same({ { SHARP, 200 }, { SHARP, 200 }, { SHARP, 200 } }, mock.bought) -- 3 stacks - 150 = 450, rounded up
      assert.matches("bought 600 Item 2515 %(1s 50c%)", mock.chat[1])
    end)

    it("never spends the gold kept for riding, and says so", function()
      mock.level, mock.money = 34, 100 * G + 60 -- saving for Apprentice Riding (100g): 60c to spare
      visit(ARROWS)
      assert.same({ { SHARP, 200 } }, mock.bought) -- one purchase of 50c fits
      mock.bought, mock.chat, mock.money = {}, {}, 100 * G + 10
      visit(ARROWS)
      assert.same({}, mock.bought)
      assert.matches("ammo skipped: it would cut into your riding savings %(100g%)", mock.chat[1])
    end)

    it("buys nothing above the level, nothing when off, for other classes or when stocked", function()
      mock.level = 20 -- Razor Arrow needs 25
      visit({ items = { { 3030, 100, 200, 200 } } })
      mock.level, ns.db.auto.ammo = 25, false
      visit(ARROWS)
      ns.db.auto.ammo, mock.counts[SHARP] = true, 600
      visit(ARROWS)
      mock.class, mock.counts[SHARP] = "WARRIOR", 0
      visit(ARROWS)
      assert.same({}, mock.bought)
    end)
  end)
end)
