local mock = require("spec.wow_mock")
local FILES = { "Core.lua", "Locale.lua", "Questie.lua", "Waypoint.lua", "MinimapGuide.lua", "Navigation.lua",
  "UI.lua" }

-- The Barrens (1413) is 0.2 of a 20000-yard continent: 1% of the zone map = 40 yards.
local PLACE = { map = 1413, x = 0.6, y = 0.5, title = "Wowish: Q (Thork)" }

describe("navigation", function()
  local ns, calls
  local function spf(started)
    calls = {}
    _G.ShortestPathForever = { API = {
      Navigate = function(...) calls[#calls + 1] = { "Navigate", ... } return started end,
      Cancel = function(owner) calls[#calls + 1] = { "Cancel", owner } return true end,
      Estimate = function() return 250 end,
    } }
  end

  before_each(function()
    mock.reset()
    mock.playerMap, mock.playerX, mock.playerY = 1413, 0.5, 0.5
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
  end)

  describe("with ShortestPathForever", function()
    it("asks it for the route and draws nothing itself", function()
      spf(true)
      assert.equal("route", ns.TakeMeThere(PLACE, PLACE.title))
      assert.same({ "Navigate", "Wowish", 1413, 0.6, 0.5, PLACE.title }, calls[1])
      assert.is_nil(mock.waypoint)
      assert.is_false(ns.GuideActive())
    end)

    it("cancels only our own journey on /wowish clear", function()
      spf(true)
      ns.TakeMeThere(PLACE, PLACE.title)
      assert.is_true(ns.StopNavigation())
      assert.same({ "Cancel", "Wowish" }, calls[#calls])
    end)

    it("falls back to waypoint and guide when it refuses", function()
      spf(false)
      assert.equal("native", ns.TakeMeThere(PLACE, PLACE.title))
      assert.is_true(ns.GuideActive())
    end)

    it("puts the travel time on the card", function()
      spf(true)
      assert.equal(250, ns.RouteSeconds(PLACE))
      ns.suggestions = { { id = "t", priority = 90, what = "Turn in.", why = "XP.", waypoint = PLACE } }
      SlashCmdList.WOWISH("")
      ns.NotifyChanged()
      local why
      for _, f in ipairs(mock.frames) do
        if f.template == "BackdropTemplate" and f.shown then why = f.why.text end
      end
      assert.equal("XP. About 4 min by the fastest route.", why)
    end)
  end)

  describe("without a route planner", function()
    it("sets the waypoint and starts the minimap guide; clear stops both", function()
      assert.equal("native", ns.TakeMeThere(PLACE, PLACE.title))
      assert.is_true(ns.GuideActive())
      assert.is_true(ns.StopNavigation())
      assert.is_false(ns.GuideActive())
      assert.is_nil(mock.waypoint)
    end)

    it("does nothing in combat", function()
      mock.combat = true
      assert.equal("combat", ns.TakeMeThere(PLACE, PLACE.title))
      assert.is_false(ns.GuideActive())
    end)
  end)

  describe("minimap guide geometry", function()
    it("measures yards east and north on the same continent", function()
      local east, north = ns.GuideOffset({ map = 1413, x = 0.6, y = 0.5 })
      assert.near(400, east, 1e-6)
      assert.near(0, north, 1e-6)
      east, north = ns.GuideOffset({ map = 1413, x = 0.5, y = 0.4 }) -- map y up = north
      assert.near(0, east, 1e-6)
      assert.near(400, north, 1e-6)
      east = ns.GuideOffset({ map = 1440, x = 0.5, y = 0.5 }) -- Ashenvale: north-west of the player
      assert.is_true(east < 0)
    end)

    it("gives up off the continent", function()
      assert.is_nil(ns.GuideOffset({ map = 999, x = 0.5, y = 0.5 }))
    end)

    it("scales by minimap zoom and indoors", function()
      local x = ns.GuideToMinimap(100, 0) -- zoom 0 outdoors: 233.3 yd radius on a 70 px radius
      assert.near(30, x, 1e-6)
      mock.indoors = true
      assert.near(70 / 150 * 100, (ns.GuideToMinimap(100, 0)), 1e-6)
    end)

    it("follows Rotate Minimap", function()
      mock.rotate, mock.facing = true, math.pi / 2 -- facing west
      local x, y = ns.GuideToMinimap(-100, 0)       -- target to the west
      assert.near(0, x, 1e-6)
      assert.near(30, y, 1e-6)                      -- straight ahead = up
    end)
  end)

  describe("minimap guide drawing", function()
    local function tick()
      for _, f in ipairs(mock.frames) do
        if f.scripts.OnUpdate then f.scripts.OnUpdate(f, 1) end
      end
    end
    local function arrow()
      for _, w in ipairs(mock.widgets) do
        if rawget(w, "texture") == "Interface\\Minimap\\MinimapArrow" then return w end
      end
    end

    it("points the edge arrow at a far target", function()
      ns.StartGuide({ map = 1413, x = 0.9, y = 0.5 }, "far east")
      tick()
      local a = arrow()
      assert.is_true(a.shown)
      assert.near(-math.pi / 2, a.rotation, 1e-6) -- east = clockwise quarter turn
      assert.near(62, a.point[4], 1e-6)            -- on the edge: radius 70 - 8
    end)

    it("stops and says so on arrival", function()
      ns.StartGuide({ map = 1413, x = 0.501, y = 0.5 }, "here") -- 4 yards away
      tick()
      assert.is_false(ns.GuideActive())
      assert.matches("you have arrived: here", mock.lastChat())
    end)

    it("hides in combat", function()
      ns.StartGuide({ map = 1413, x = 0.9, y = 0.5 }, "far")
      tick()
      mock.combat = true
      tick()
      assert.is_false(arrow().shown)
    end)
  end)
end)
