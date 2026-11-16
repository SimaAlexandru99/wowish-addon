local mock = require("spec.wow_mock")
local FILES = { "Core.lua", "Locale.lua", "Questie.lua", "Waypoint.lua", "MinimapGuide.lua",
  "Navigation.lua", "UI.lua", "MinimapButton.lua", "NextBar.lua",
  "Welcome.lua", "SettingsPanel.lua" }

local TIPS = {
  { id = "talents", kind = "talent", priority = 95, what = "Spend 1 point.", why = "Power." },
  { id = "turnin", kind = "quest", priority = 70, what = "Turn in 6 quests: A, B, C, D, ...", why = "XP.",
    details = { "A", "B", "C", "D", "E", "F" } },
}

local function shownText(pattern)
  for _, w in ipairs(mock.widgets) do
    local t = rawget(w, "text")
    if type(t) == "string" and t:find(pattern) and w.shown then return t end
  end
end

describe("access and window layout", function()
  local ns
  local function setTips(list)
    ns.suggestions = list
    ns.NotifyChanged()
  end
  local function cards()
    local out = {}
    for _, f in ipairs(mock.frames) do
      if f.template == "BackdropTemplate" and f ~= _G.WowishNextBar and f.shown then out[#out + 1] = f end
    end
    return out
  end

  before_each(function()
    mock.reset()
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
    mock.fire("PLAYER_LOGIN")
  end)

  describe("minimap button", function()
    it("is on by default and counts the visible tips", function()
      setTips(TIPS)
      local b = _G.WowishMinimapButton
      assert.is_true(b.shown)
      assert.truthy(shownText("^2$"))
      SlashCmdList.WOWISH("")
      cards()[1].hide:Click() -- hiding a tip updates the number
      assert.truthy(shownText("^1$"))
    end)

    it("flashes once when more tips arrive, never at login, in combat or with the window open", function()
      local function plays()
        for _, w in ipairs(mock.widgets) do
          if rawget(w, "animGroup") then return rawget(w.animGroup, "plays") or 0 end
        end
      end
      setTips({ TIPS[1] }) -- first count after login: no flash
      assert.equal(0, plays())
      setTips(TIPS)
      assert.equal(1, plays())
      setTips(TIPS) -- same count
      setTips({ TIPS[1] }) -- fewer
      assert.equal(1, plays())
      mock.combat = true
      setTips(TIPS)
      assert.equal(1, plays())
      mock.combat = false
      setTips({ TIPS[1] })
      SlashCmdList.WOWISH("") -- window open: the cards already show it
      setTips(TIPS)
      assert.equal(1, plays())
    end)

    it("left-click toggles the window, right-click opens settings", function()
      local b = _G.WowishMinimapButton
      b.scripts.OnClick(b, "LeftButton")
      assert.is_true(ns.IsShown())
      b.scripts.OnClick(b, "LeftButton")
      assert.is_false(ns.IsShown())
      b.scripts.OnClick(b, "RightButton")
      assert.equal(4242, mock.openedCategory)
    end)

    it("shows the count and the #1 tip in its tooltip", function()
      setTips(TIPS)
      local b = _G.WowishMinimapButton
      b.scripts.OnEnter(b)
      assert.same({ "Wowish", "2 tips", "1. Spend 1 point.", "Left-click: open. Right-click: settings. Drag: move." },
        mock.tooltip)
    end)

    it("moves around the minimap when dragged and remembers the angle", function()
      local b = _G.WowishMinimapButton
      mock.cursor = { 0, 100 } -- straight above the minimap centre
      b.scripts.OnDragStart(b)
      b.scripts.OnUpdate(b)
      b.scripts.OnDragStop(b)
      assert.near(90, ns.db.minimapAngle, 1e-9)
      assert.near(0, b.point[4], 1e-9)
      assert.near(75, b.point[5], 1e-9) -- radius = minimap width / 2 + 5
      assert.is_nil(b.scripts.OnUpdate)
    end)

    it("can be hidden from settings", function()
      mock.settings.Wowish_minimapButton.set(false)
      assert.is_false(_G.WowishMinimapButton.shown)
      assert.is_false(ns.db.minimapButton)
    end)
  end)

  describe("next-tip bar", function()
    it("is off by default", function()
      setTips(TIPS)
      assert.is_nil(_G.WowishNextBar)
    end)

    it("shows the #1 tip, hides in combat and when nothing is left", function()
      mock.settings.Wowish_nextBar.set(true)
      setTips(TIPS)
      local bar = _G.WowishNextBar
      assert.is_true(bar.shown)
      assert.equal("|cff33ff99Wowish:|r Spend 1 point.", bar.text.text)
      mock.combat = true
      mock.fire("PLAYER_REGEN_DISABLED")
      assert.is_false(bar.shown)
      setTips(TIPS) -- an update during combat keeps it hidden
      assert.is_false(bar.shown)
      mock.combat = false
      mock.fire("PLAYER_REGEN_ENABLED")
      assert.is_true(bar.shown)
      setTips({})
      assert.is_false(bar.shown)
    end)

    it("opens the window on click", function()
      mock.settings.Wowish_nextBar.set(true)
      setTips(TIPS)
      _G.WowishNextBar:Click()
      assert.is_true(ns.IsShown())
    end)
  end)

  describe("window", function()
    it("numbers the cards like /wowish go and outlines the first one", function()
      SlashCmdList.WOWISH("")
      setTips(TIPS)
      local c = cards()
      assert.equal("|cffffd100" .. "1.|r Spend 1 point.", c[1].what.text)
      assert.equal("|cffffd100" .. "2.|r Turn in 6 quests: A, B, C, D, ...", c[2].what.text)
    end)

    it("shows the full list in the card tooltip", function()
      SlashCmdList.WOWISH("")
      setTips(TIPS)
      local c = cards()[2]
      c.scripts.OnEnter(c)
      assert.same({ "Turn in 6 quests: A, B, C, D, ...", "A", "B", "C", "D", "E", "F" }, mock.tooltip)
    end)

    it("grows with its cards and stops growing at the cap", function()
      SlashCmdList.WOWISH("")
      setTips({})
      assert.equal(230, _G.WowishFrame.height)
      setTips(TIPS)
      local twoCards = _G.WowishFrame.height
      assert.is_true(twoCards >= 230 and twoCards < 620)
      local bar
      for _, f in ipairs(mock.frames) do if f.template == "UIPanelScrollFrameTemplate" then bar = f.ScrollBar end end
      assert.is_false(bar.shown) -- fits: no scroll bar
      local many = {}
      for i = 1, 5 do
        many[i] = { id = "t" .. i, priority = 1, what = string.rep("x", 400), why = string.rep("y", 400) }
      end
      setTips(many)
      assert.equal(620, _G.WowishFrame.height)
      assert.is_true(bar.shown) -- does not fit: scroll bar
    end)
  end)

  describe("tip buttons", function()
    local ACT = {
      { id = "talents", kind = "talent", priority = 95, what = "Spend.", why = "Power.", hint = "talents" },
      { id = "bags", kind = "bags", priority = 86, what = "Bags.", why = "Loot.", hint = "bags" },
      { id = "trainer", kind = "trainer", priority = 80, what = "Train.", why = "Ranks.", hint = "spellbook" },
      { id = "zone", kind = "zone", priority = 50, what = "Zone.", action = { open = "map", arg = 1440 } },
      { id = "turnin", kind = "quest", priority = 90, what = "Turn in.",
        waypoint = { map = 1413, x = 0.5, y = 0.5, title = "T" } },
    }
    before_each(function()
      mock.bindings = { TOGGLETALENTS = "N", OPENALLBAGS = "SHIFT-B" } -- no key set for the spellbook
      SlashCmdList.WOWISH("")
      setTips(ACT)
    end)

    it("show a button only for the map and for places", function()
      local labels = {}
      for i, c in ipairs(cards()) do labels[i] = c.go.shown and c.go.text or false end
      assert.same({ false, false, false, "Map", "Take me there" }, labels)
    end)

    it("name the player's own key for talents, spellbook and bags", function()
      local c = cards()
      assert.matches("Press N to open your talents%.", c[1].why.text)
      assert.matches("Press SHIFT%-B to open your bags%.", c[2].why.text)
      assert.matches("Open your spellbook from the game menu%.", c[3].why.text)
    end)

    it("open only the world map, and take me there for places", function()
      cards()[4].go:Click()
      assert.same({ "map:1440" }, mock.opened)
      cards()[5].go:Click()
      assert.same({ map = 1413, x = 0.5, y = 0.5 }, mock.waypoint)
    end)

    it("never call the openers that taint action bars and bags", function()
      local ls = assert(io.popen("ls *.lua"))
      for f in ls:lines() do -- every addon file, not only the ones this spec loads
        local src = assert(io.open(f)):read("*a")
        for _, name in ipairs({ "PlayerSpellsUtil", "ToggleSpellBook", "ToggleTalentFrame", "OpenAllBags",
          "ToggleAllBags", "OpenBag", "ToggleBackpack" }) do
          assert.falsy(src:find(name, 1, true), name .. " in " .. f)
        end
      end
      ls:close()
    end)

    it("show the small x only while the mouse is over the card", function()
      local c = cards()[1]
      assert.is_false(c.hide.shown)
      c.scripts.OnEnter(c)
      assert.is_true(c.hide.shown)
      c.scripts.OnLeave(c)
      assert.is_false(c.hide.shown)
      c.hide.scripts.OnEnter(c.hide)
      assert.matches("comes back when things change", mock.tooltip[#mock.tooltip])
    end)
  end)

  it("offers a key binding that toggles the window", function()
    local xml = assert(io.open("Bindings.xml")):read("*a")
    assert.truthy(xml:find('name="WOWISH_TOGGLE"', 1, true))
    assert.truthy(xml:find("Wowish_OnAddonCompartmentClick()", 1, true))
    assert.equal("Open or close Wowish", BINDING_NAME_WOWISH_TOGGLE)
    assert.equal("Wowish", BINDING_HEADER_WOWISH)
  end)
end)
