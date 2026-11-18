local mock = require("spec.wow_mock")
local FILES = { "Core.lua", "Locale.lua", "Questie.lua", "Waypoint.lua", "MinimapGuide.lua",
  "Navigation.lua", "UI.lua", "Changes.lua", "MinimapButton.lua", "NextBar.lua", "Welcome.lua", "SettingsPanel.lua" }

local function tips()
  return {
    { id = "a", kind = "talent", priority = 95, what = "Spend 1 point.", why = "Power." },
    { id = "b", kind = "quest", priority = 70, what = "Turn in 2 quests.", why = "XP." },
  }
end

local function shownText(pattern)
  for _, w in ipairs(mock.widgets) do
    local t = rawget(w, "text")
    if type(t) == "string" and t:find(pattern) and w.shown then return t end
  end
end

describe("hide, snooze and show hidden", function()
  local ns
  before_each(function()
    mock.reset()
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
    mock.fire("PLAYER_LOGIN")
    ns.suggestions = tips()
    ns.NotifyChanged()
  end)

  it("snoozes a tip for 30 minutes, and it returns sooner if its text changes", function()
    ns.Snooze(ns.Visible()[1])
    assert.equal(1, #ns.Visible())
    assert.equal(1, ns.HiddenCount())
    mock.now = mock.now + 1799
    assert.equal(1, #ns.Visible())
    mock.now = mock.now + 2
    assert.equal(2, #ns.Visible())
    ns.Snooze(ns.Visible()[1])
    ns.suggestions[1].what = "Spend 2 points." -- different text: not the tip that was snoozed
    assert.equal(2, #ns.Visible())
  end)

  it("brings every hidden and snoozed tip back with unhide and the window button", function()
    SlashCmdList.WOWISH("hide 1")
    SlashCmdList.WOWISH("snooze 1")
    assert.equal(0, #ns.Visible())
    ns.Show()
    assert.truthy(shownText("^Show 2 hidden$"))
    SlashCmdList.WOWISH("unhide")
    assert.equal(2, #ns.Visible())
    assert.is_nil(shownText("^Show %d+ hidden$")) -- nothing hidden: the button goes away
    SlashCmdList.WOWISH("snooze 9")
    assert.matches("there is no tip 9", mock.lastChat())
  end)

  it("the Show hidden button restores tips when clicked", function()
    ns.Show()
    SlashCmdList.WOWISH("hide 1")
    local button
    for _, w in ipairs(mock.widgets) do
      if rawget(w, "text") == "Show 1 hidden" and w.shown then button = w end
    end
    assert.truthy(button)
    button:Click()
    assert.equal(2, #ns.Visible())
  end)
end)

describe("the z button on a card", function()
  local ns, card
  before_each(function()
    mock.reset()
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
    mock.fire("PLAYER_LOGIN")
    ns.suggestions = tips()
    ns.NotifyChanged()
    ns.Show()
    for _, f in ipairs(mock.frames) do
      if f.template == "BackdropTemplate" and f.snooze and f.shown then card = card or f end
    end
  end)

  it("snoozes its tip when clicked", function()
    card.snooze:Click()
    assert.equal(1, #ns.Visible())
    assert.equal("Turn in 2 quests.", ns.Visible()[1].what)
  end)

  it("keeps the x and z shown while the mouse is over z, and hides them when it leaves both", function()
    card.scripts.OnEnter(card)
    assert.is_true(card.hide.shown)
    card.snooze.IsMouseOver = function() return true end
    card.scripts.OnLeave(card) -- the mouse moved from the card onto z
    assert.is_true(card.hide.shown)
    card.snooze.IsMouseOver = function() return false end
    card.scripts.OnLeave(card)
    assert.is_false(card.hide.shown)
  end)
end)

describe("next-tip bar click", function()
  local ns, went
  before_each(function()
    mock.reset()
    ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
    mock.fire("PLAYER_LOGIN")
    mock.settings.Wowish_nextBar.set(true)
    went = nil
    ns.Go = function(n) went = n end
  end)

  it("takes you to the #1 tip when it has a place, the window otherwise or on right-click", function()
    local list = tips()
    list[1].waypoint = { map = 1, x = 0.5, y = 0.5, title = "T" }
    ns.suggestions = list
    ns.NotifyChanged()
    local bar = _G.WowishNextBar
    bar.scripts.OnClick(bar, "LeftButton")
    assert.equal(1, went)
    assert.is_false(ns.IsShown())
    bar.scripts.OnClick(bar, "RightButton")
    assert.is_true(ns.IsShown())
  end)

  it("opens the window when the #1 tip has no place", function()
    ns.suggestions = tips()
    ns.NotifyChanged()
    local bar = _G.WowishNextBar
    bar.scripts.OnClick(bar, "LeftButton")
    assert.is_nil(went)
    assert.is_true(ns.IsShown())
  end)
end)

describe("what is new", function()
  it("/wowish new prints the version and its lines, in Romanian too", function()
    mock.reset()
    local ns = mock.load(FILES)
    mock.fire("ADDON_LOADED", "Wowish")
    SlashCmdList.WOWISH("new")
    assert.equal(1 + #ns.CHANGES.lines, #mock.chat)
    assert.matches("What is new in Wowish " .. ns.CHANGES.version, mock.chat[1])
    mock.chat = {}
    ns.db.locale = "roRO"
    SlashCmdList.WOWISH("new")
    assert.matches("Ce e nou in Wowish", mock.chat[1])
    assert.matches("Sfaturi ascunse", mock.chat[2])
  end)
end)

describe("Changes.lua", function()
  it("names the version at the top of CHANGELOG.md, so /wowish new is not stale", function()
    mock.reset()
    local ns = mock.load(FILES)
    local fh = assert(io.open("CHANGELOG.md"))
    local text = fh:read("*a")
    fh:close()
    assert.equal(text:match("\n## v([%d%.]+)"), ns.CHANGES.version)
  end)
end)
