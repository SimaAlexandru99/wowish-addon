local mock = require("spec.wow_mock")
local CORE = { "Core.lua" }

local function rule(id, list, extra)
  local r = { id = id, evaluate = function() return list end }
  for k, v in pairs(extra or {}) do r[k] = v end
  return r
end

describe("Core", function()
  local ns
  before_each(function()
    mock.reset()
    ns = mock.load(CORE)
  end)

  describe("saved variables", function()
    it("fills defaults and keeps the player's values", function()
      _G.WowishDB = { loginLine = false, rules = { bags = false } }
      mock.fire("ADDON_LOADED", "Wowish")
      assert.is_false(WowishDB.loginLine)
      assert.is_false(WowishDB.rules.bags)
      assert.equal(1, WowishDB.scale)
      assert.is_false(WowishDB.welcomeSeen)
      assert.equal(WowishDB, ns.db)
    end)

    it("ignores other addons and replaces a corrupt value", function()
      mock.fire("ADDON_LOADED", "SomethingElse")
      assert.is_nil(ns.db)
      _G.WowishDB = "garbage"
      mock.fire("ADDON_LOADED", "Wowish")
      assert.equal("table", type(WowishDB))
      assert.is_true(WowishDB.loginLine)
    end)
  end)

  describe("Evaluate", function()
    before_each(function() mock.fire("ADDON_LOADED", "Wowish") end)

    it("sorts by priority, caps per rule, keeps the top 5", function()
      ns.RegisterRule(rule("turnin", {
        { id = "t1", priority = 90 }, { id = "t2", priority = 80 }, { id = "t3", priority = 70 },
      }, { maxInTop = 2 }))
      ns.RegisterRule(rule("misc", {
        { id = "m1", priority = 85 }, { id = "m2", priority = 10 }, { id = "m3", priority = 20 },
        { id = "m4", priority = 30 },
      }))
      local ids = {}
      for _, s in ipairs(ns.Evaluate()) do ids[#ids + 1] = s.id end
      assert.same({ "t1", "m1", "t2", "m4", "m3" }, ids)
    end)

    it("skips disabled rules and isolates a rule that errors", function()
      ns.RegisterRule(rule("off", { { id = "o", priority = 99 } }))
      ns.RegisterRule({ id = "broken", evaluate = function() error("boom") end })
      ns.RegisterRule(rule("ok", { { id = "k", priority = 1 } }))
      ns.db.rules.off = false
      local top = ns.Evaluate()
      assert.equal(1, #top)
      assert.equal("k", top[1].id)
      assert.matches("boom", ns.errors.broken)
      assert.equal(1, #mock.reported) -- BugSack sees it too
      assert.matches("boom", mock.reported[1])
    end)

    it("reports a failing listener and still runs the others", function()
      local second
      ns.OnSuggestionsUpdated(function() error("ui broke") end)
      ns.OnSuggestionsUpdated(function() second = true end)
      ns.Evaluate()
      assert.is_true(second)
      assert.matches("ui broke", mock.reported[1])
    end)

    it("survives an error handler that itself fails", function()
      _G.geterrorhandler = function() return function() error("handler broke") end end
      ns.RegisterRule({ id = "broken", evaluate = function() error("boom") end })
      ns.RegisterRule(rule("ok", { { id = "k", priority = 1 } }))
      assert.equal("k", ns.Evaluate()[1].id)
    end)

    it("notifies listeners with the new list", function()
      local got
      ns.OnSuggestionsUpdated(function(top) got = top end)
      ns.RegisterRule(rule("ok", { { id = "k", priority = 1 } }))
      ns.Evaluate()
      assert.equal("k", got[1].id)
    end)

    it("rejects duplicate rule ids", function()
      ns.RegisterRule(rule("a", {}))
      assert.has_error(function() ns.RegisterRule(rule("a", {})) end)
    end)
  end)

  describe("update scheduling", function()
    local calls
    before_each(function()
      mock.fire("ADDON_LOADED", "Wowish")
      calls = 0
      ns.RegisterRule({ id = "r", events = { "BAG_UPDATE" }, evaluate = function() calls = calls + 1 return {} end })
    end)

    it("coalesces a burst of events into one evaluation", function()
      for _ = 1, 10 do mock.fire("BAG_UPDATE") end
      assert.equal(1, mock.flush())
      assert.equal(1, calls)
    end)

    it("never evaluates in combat and catches up after combat", function()
      mock.combat = true
      mock.fire("BAG_UPDATE")
      mock.flush()
      assert.equal(0, calls)
      assert.is_true(ns.dirty)
      mock.combat = false
      mock.fire("PLAYER_REGEN_ENABLED")
      mock.flush()
      assert.equal(1, calls)
      assert.is_false(ns.dirty)
    end)

    it("does nothing on leaving combat when nothing changed", function()
      mock.fire("PLAYER_REGEN_ENABLED")
      assert.equal(0, mock.flush())
    end)

    it("evaluates once at login", function()
      mock.fire("PLAYER_LOGIN")
      mock.flush()
      assert.equal(1, calls)
    end)
  end)
end)
