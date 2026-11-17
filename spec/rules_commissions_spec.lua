local mock = require("spec.wow_mock")
local FILES = { "Core.lua", "Locale.lua", "Questie.lua", "Waypoint.lua", "MinimapGuide.lua", "Navigation.lua",
  "RulesCommissions.lua", "UI.lua" }

describe("commissions ready", function()
  local ns, rows, routed, listener
  local function commissions()
    return ns.ruleById.commissions.evaluate()
  end

  before_each(function()
    mock.reset()
    rows, routed, listener = {}, 0, nil
    _G.CommissionsForever = { API = {
      Materials = function()
        if rows == "loading" then return nil, "loading" end
        return rows
      end,
      Subscribe = function(cb) listener = cb return function() end end,
      NavigateActiveAssignments = function() routed = routed + 1 return routed < 2 end,
    } }
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
  end)

  it("counts a commission only when every material of it is in the bags", function()
    rows = {
      { questID = 10, itemID = 1, have = 20, need = 20 }, { questID = 10, itemID = 2, have = 5, need = 5 },
      { questID = 11, itemID = 3, have = 20, need = 20 }, { questID = 11, itemID = 4, have = 1, need = 5 },
      { questID = 12, itemID = 5, have = 9, need = nil }, -- unknown need: not ready
      { questID = nil, itemID = 6, have = 99, need = 10 }, -- not in the log yet
      { questID = 13, itemID = 7, have = 10, need = 10 },
    }
    assert.same({ 10, 13 }, ns.ReadyCommissions())
    local s = commissions()[1]
    assert.equal("Commissions ready to hand in: 2 commissions.", s.what)
    assert.equal("commissions", s.action.open)
    rows[#rows].have = 9
    assert.equal("Commissions ready to hand in: 1 commission.", commissions()[1].what)
  end)

  it("is quiet while it loads, with nothing ready, and without the addon", function()
    rows = "loading"
    assert.equal(0, #commissions())
    rows = { { questID = 10, itemID = 1, have = 1, need = 20 } }
    assert.equal(0, #commissions())
    _G.CommissionsForever = nil
    assert.equal(0, #commissions())
  end)

  it("refreshes when Commissions Forever says its rows changed", function()
    mock.fire("PLAYER_LOGIN")
    assert.is_function(listener)
    mock.flush() -- the login update
    listener({ materials = 1 })
    assert.equal(1, #mock.timers)
  end)

  it("its button asks Commissions Forever for the route, and says so when it cannot", function()
    rows = { { questID = 10, itemID = 1, have = 20, need = 20 } }
    assert.is_true(ns.OpenPanel("commissions"))
    assert.equal(1, routed)
    assert.is_true(ns.OpenPanel("commissions"))
    assert.matches("could not start a route", mock.chat[#mock.chat])
  end)

  it("has Romanian texts", function()
    rows = { { questID = 10, itemID = 1, have = 20, need = 20 } }
    ns.db.locale = "roRO"
    assert.equal("Comisioane gata de predat: 1 comision.", commissions()[1].what)
  end)
end)
