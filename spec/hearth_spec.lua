local mock = require("spec.wow_mock")
local FILES = { "Core.lua", "Locale.lua", "Questie.lua", "Waypoint.lua", "MinimapGuide.lua", "Navigation.lua",
  "RulesFund.lua", "Services.lua", "Hearth.lua", "UI.lua", "SettingsPanel.lua" }

-- The player stands in The Barrens (1413) at 0.5, 0.5; a zone map is 4000 yards wide, so 0.01 of it is 40 yards.
local FLYER = { [1] = { name = "Flyer", sub = "Wind Rider Master", flags = 8, friendly = "H",
  spawns = { [17] = { { 51, 30 } } } } }
local KEY = "Tester-Realm"
local FAR = { map = 1440, x = 0.5, y = 0.5 } -- Ashenvale, thousands of yards from the player

describe("hearth hint", function()
  local ns
  local function ready() -- inn 80 yards from FAR, stone in the bags and off cooldown
    ns.db.hearth[KEY] = { map = 1440, x = 0.52, y = 0.5, name = "Orgrimmar" }
    mock.counts[6948] = 1
  end
  local function chat() return table.concat(mock.chat, "\n") end

  before_each(function()
    mock.reset()
    mock.questieDB({}, FLYER)
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
  end)

  describe("learns the inn", function()
    it("when the bind changes, and nothing when the position is unknown", function()
      mock.fire("HEARTHSTONE_BOUND")
      assert.same({ map = 1413, x = 0.5, y = 0.5, name = "Orgrimmar" }, ns.db.hearth[KEY])
      ns.db.hearth[KEY] = nil
      mock.playerX = nil
      mock.fire("HEARTHSTONE_BOUND")
      assert.is_nil(ns.db.hearth[KEY])
    end)

    it("after a Hearthstone cast and the arrival", function()
      mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 8690)
      assert.is_nil(ns.db.hearth[KEY]) -- the cast alone stores nothing
      mock.fire("PLAYER_ENTERING_WORLD")
      assert.equal(1413, ns.db.hearth[KEY].map)
      ns.db.hearth[KEY] = nil
      mock.fire("ZONE_CHANGED") -- the cast was used up
      assert.is_nil(ns.db.hearth[KEY])
    end)

    it("waits for a known position, and only records in the bind area within a minute", function()
      mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 8690)
      mock.playerX = nil -- loading screen
      mock.fire("PLAYER_ENTERING_WORLD")
      assert.is_nil(ns.db.hearth[KEY])
      mock.playerX = 0.5
      mock.zone = "The Barrens" -- a zone event before the teleport: not the bind area
      mock.fire("ZONE_CHANGED")
      assert.is_nil(ns.db.hearth[KEY])
      mock.zone = "Orgrimmar"
      mock.fire("ZONE_CHANGED_NEW_AREA")
      assert.equal("Orgrimmar", ns.db.hearth[KEY].name)

      ns.db.hearth[KEY] = nil
      mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 8690)
      mock.time = mock.time + 61 -- too late: the player may have walked anywhere
      mock.fire("ZONE_CHANGED")
      assert.is_nil(ns.db.hearth[KEY])
    end)

    it("ignores other spells and secret spell IDs", function()
      mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1234)
      mock.fire("PLAYER_ENTERING_WORLD")
      assert.is_nil(ns.db.hearth[KEY])
      mock.secretNames[8690] = true
      mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 8690)
      mock.fire("PLAYER_ENTERING_WORLD")
      assert.is_nil(ns.db.hearth[KEY])
    end)
  end)

  describe("ns.HearthHint", function()
    before_each(ready)

    it("is ready when the inn is near the place and the player is far", function()
      local text, state = ns.HearthHint(FAR)
      assert.equal("Your Hearthstone is ready: Orgrimmar is 80 yards from there.", text)
      assert.equal("ready", state)
    end)

    it("says soon with a short cooldown", function()
      mock.cooldowns[6948] = { 4800, 320 } -- 120 s left
      local text, state = ns.HearthHint(FAR)
      assert.equal("Your Hearthstone is ready in under 5 min: Orgrimmar is 80 yards from there.", text)
      assert.equal("soon", state)
    end)

    it("counts an unknown player position as far", function()
      mock.playerX = nil
      assert.equal("ready", select(2, ns.HearthHint(FAR)))
    end)

    it("is silent when it does not help", function()
      assert.is_nil(ns.HearthHint({ map = 1440, x = 0.62, y = 0.5 })) -- inn 480 yards away
      assert.is_nil(ns.HearthHint({ map = 1413, x = 0.6, y = 0.5 })) -- the player is 400 yards away already
      mock.cooldowns[6948] = { 4000, 2000 } -- 1000 s left
      assert.is_nil(ns.HearthHint(FAR))
      mock.cooldowns[6948] = nil
      mock.bind = "Thunder Bluff" -- re-bound without us seeing it
      assert.is_nil(ns.HearthHint(FAR))
      mock.bind = "Orgrimmar"
      ns.db.hearthHint = false
      assert.is_nil(ns.HearthHint(FAR))
      ns.db.hearthHint = true
      mock.counts[6948] = 0
      assert.is_nil(ns.HearthHint(FAR))
      mock.counts[6948] = 1
      assert.truthy(ns.HearthHint(FAR))
      _G.ShortestPathForever = { API = { Navigate = function() return true end } }
      assert.is_nil(ns.HearthHint(FAR))
    end)
  end)

  describe("on the cards and in chat", function()
    before_each(function()
      ready()
      ns.RegisterRule({ id = "t", evaluate = function() return {
        { id = "t:way", priority = 50, what = "Far.", why = "Because.", waypoint = { map = 1440, x = 0.5, y = 0.5,
          title = "Wowish: far" } },
        { id = "t:none", priority = 40, what = "Here.", why = "Fine." },
      } end })
    end)

    it("appends the hint to a tip with a waypoint, keeping its priority", function()
      ns.Evaluate()
      assert.equal("Because. Your Hearthstone is ready: Orgrimmar is 80 yards from there.", ns.suggestions[1].why)
      assert.equal(50, ns.suggestions[1].priority)
      assert.equal("Fine.", ns.suggestions[2].why)
    end)

    describe("after Take me there", function()
      before_each(function()
        ns.StartServiceScan()
        for _ = 1, 100 do
          mock.clock = mock.clock + 10
          for _, f in ipairs(mock.frames) do
            if f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.02) end
          end
        end
        ns.Evaluate()
      end)

      it("prints only the hearth line when the stone is ready", function()
        SlashCmdList.WOWISH("go 1")
        assert.matches("Your Hearthstone is ready:", chat())
        assert.is_nil(chat():find("Nearest flight master", 1, true))
      end)

      it("prints both lines when the stone is ready soon", function()
        mock.cooldowns[6948] = { 4800, 320 }
        SlashCmdList.WOWISH("go 1")
        assert.matches("Your Hearthstone is ready in under 5 min", chat())
        assert.matches("Nearest flight master: Flyer", chat())
      end)

      it("prints the flight line as before without a hint", function()
        mock.counts[6948] = 0
        SlashCmdList.WOWISH("go 1")
        assert.is_nil(chat():find("Hearthstone", 1, true))
        assert.matches("Nearest flight master: Flyer", chat())
      end)
    end)
  end)

  it("has a settings checkbox", function()
    ns.RegisterSettings()
    mock.settings.Wowish_hearthHint.set(false)
    assert.is_false(ns.db.hearthHint)
  end)
end)
