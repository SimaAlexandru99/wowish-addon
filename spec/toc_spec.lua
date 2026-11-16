local mock = require("spec.wow_mock")

local function readTOC()
  local headers, files = {}, {}
  for line in io.lines("Wowish.toc") do
    local k, v = line:match("^## ([%w%-]+): (.*)$")
    if k then
      headers[k] = v
    elseif line:match("%S") and not line:match("^#") then
      files[#files + 1] = line
    end
  end
  return headers, files
end

describe("Wowish.toc", function()
  local headers, files = readTOC()

  it("targets Forever and declares what the client and packager need", function()
    assert.equal("16001", headers.Interface)
    assert.equal("Wowish", headers.Title)
    assert.equal("@project-version@", headers.Version)
    assert.equal("WowishDB", headers.SavedVariables)
    assert.equal("TomTom, QuestieDB", headers.OptionalDeps)
    assert.equal("Wowish_OnAddonCompartmentClick", headers.AddonCompartmentFunc)
    assert.equal("GPL-3.0-or-later", headers["X-License"])
  end)

  it("lists every addon Lua file in the repo root, and only existing ones", function()
    local listed = {}
    for _, f in ipairs(files) do
      listed[f] = true
      assert.truthy(io.open(f), "listed but missing: " .. f)
    end
    local p = assert(io.popen("ls *.lua"))
    for f in p:lines() do assert.truthy(listed[f], "not in TOC: " .. f) end
    p:close()
  end)

  it("loads in TOC order and runs a full login without errors", function()
    mock.reset()
    mock.ranged, mock.level = 3036, 25
    mock.talents = { true, 1, 0 }
    mock.questLog = { mock.header("The Barrens"), mock.quest(1, "Done", 25, { complete = true }) }
    mock.bags = { [0] = { slots = 16, free = 1, items = { 2515 } } }
    local ns = mock.load(files)
    mock.fire("ADDON_LOADED", "Wowish")
    mock.fire("PLAYER_LOGIN")
    mock.flush()
    assert.same({}, ns.errors)
    local ids = {}
    for _, s in ipairs(ns.suggestions) do ids[#ids + 1] = s.id end
    assert.same({ "talents", "ammo:3030", "trainer", "turnin:?", "bags" }, ids)
    assert.is_true(ns.IsWelcomeShown())
    assert.matches("5 tips%. #1: You have 1 unspent talent point%.", mock.lastChat())
  end)
end)
