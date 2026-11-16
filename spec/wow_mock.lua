-- Minimal Mainline-family WoW API mock for busted. Only what the addon calls.
-- Reset with mock.reset() before each test; load the addon with mock.load(files).
local mock = {}
local mapAPI -- defined below, called from reset()

function mock.reset()
  mock.frames, mock.timers, mock.combat, mock.widgets = {}, {}, false, {}
  _G.WowishDB = nil

  _G.CreateFrame = function(_, name, _, template)
    local f = mock.widget({ template = template or false })
    if template == "UIPanelScrollFrameTemplate" then f.ScrollBar = mock.widget() end -- as the real template
    if name then _G[name] = f end
    mock.frames[#mock.frames + 1] = f
    return f
  end
  mock.chat = {}
  _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) mock.chat[#mock.chat + 1] = msg end }
  _G.UIParent = mock.widget()
  _G.Minimap = mock.widget({ width = 140 })
  mock.tooltip = {}
  _G.GameTooltip = mock.widget({ AddLine = function(_, text) mock.tooltip[#mock.tooltip + 1] = text end })
  mock.cursor = { 0, 0 }
  mock.opened = {} -- game windows opened by tip buttons
  _G.PlayerSpellsUtil = {
    ToggleClassTalentFrame = function() table.insert(mock.opened, "talents") end,
    ToggleSpellBookFrame = function() table.insert(mock.opened, "spellbook") end,
  }
  _G.OpenAllBags = function() table.insert(mock.opened, "bags") end
  _G.OpenWorldMap = function(map) table.insert(mock.opened, "map:" .. tostring(map)) end
  mock.bindings = {}
  _G.GetBindingKey = function(action) return mock.bindings[action] end
  _G.GetBindingText = function(key) return key end
  _G.GetCursorPosition = function() return mock.cursor[1], mock.cursor[2] end
  _G.UISpecialFrames = {}
  _G.SlashCmdList = {}
  _G.SLASH_WOWISH1 = nil
  _G.Wowish_OnAddonCompartmentClick = nil
  _G.WowishFrame = nil
  _G.ButtonFrameTemplate_HidePortrait = function() end
  _G.ButtonFrameTemplate_HideButtonBar = function() end
  mock.now = 1000000
  _G.time = function() return mock.now end
  _G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
  _G.UnitName = function() return "Tester" end
  _G.C_AddOns = { GetAddOnMetadata = function(_, key) return key == "Version" and "v0.3.0-test" or nil end }
  _G.GetBuildInfo = function() return "1.60.1", "70938" end
  _G.GetLocale = function() return "enUS" end

  -- Settings panel: mock.settings[variable] = { name, get, set }, mock.buttons[name] = onClick.
  mock.settings, mock.buttons, mock.openedCategory, mock.registeredCategory = {}, {}, nil, nil
  local category = { GetID = function() return 4242 end }
  _G.Settings = {
    VarType = { Boolean = "boolean", Number = "number" },
    RegisterVerticalLayoutCategory = function() return category end,
    RegisterProxySetting = function(_, variable, _, name, _, get, set)
      mock.settings[variable] = { name = name, get = get, set = set }
      return mock.settings[variable]
    end,
    CreateCheckboxInitializer = function(setting) return setting end,
    CreateSliderOptions = function() return { SetLabelFormatter = function() end } end,
    CreateSliderInitializer = function(setting) return setting end,
    RegisterInitializer = function() end,
    RegisterAddOnCategory = function(c) mock.registeredCategory = c end,
  }
  _G.CreateSettingsButtonInitializer = function(name, _, onClick) mock.buttons[name] = onClick end
  _G.MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
  _G.C_SettingsUtil = { OpenSettingsPanel = function(id) mock.openedCategory = id end }
  _G.securecallfunction = function(fn, ...) return fn(...) end
  _G.C_Timer = { After = function(_, fn) mock.timers[#mock.timers + 1] = fn end }
  mock.reported = {} -- errors handed to geterrorhandler(), as BugGrabber would see them
  _G.geterrorhandler = function() return function(err) mock.reported[#mock.reported + 1] = tostring(err) end end
  _G.InCombatLockdown = function() return mock.combat end
  _G.UnitAffectingCombat = function() return mock.combat end

  -- Player state the rules read. Tests overwrite these fields.
  mock.level, mock.xp, mock.xpMax = 21, 500, 1000
  mock.questLog = {}      -- entries as C_QuestLog.GetInfo returns them; set .complete / .tagID for tests
  mock.talents = { false, 0, 0 }
  mock.bags = {}          -- [bag] = { slots = n, free = n, family = n }
  _G.UnitLevel = function() return mock.level end
  _G.UnitXP = function() return mock.xp end
  _G.UnitXPMax = function() return mock.xpMax end
  local function byQuestID(id)
    for _, e in ipairs(mock.questLog) do if e.questID == id then return e end end
  end
  _G.C_QuestLog = {
    GetNumQuestLogEntries = function() return #mock.questLog end,
    GetInfo = function(i) return mock.questLog[i] end,
    IsComplete = function(id) return (byQuestID(id) or {}).complete == true end,
    GetQuestTagInfo = function(id)
      local e = byQuestID(id)
      if e and e.tagID then return { tagID = e.tagID, tradeskillLineID = e.tradeskillLineID } end
    end,
  }
  _G.C_ClassTalents = { HasUnspentTalentPoints = function() return unpack(mock.talents) end }
  _G.C_Container = {
    GetContainerNumSlots = function(bag) return (mock.bags[bag] or {}).slots or 0 end,
    GetContainerNumFreeSlots = function(bag)
      local b = mock.bags[bag] or {}
      return b.free or 0, b.family or 0
    end,
    GetContainerItemInfo = function(bag, slot)
      local id = ((mock.bags[bag] or {}).items or {})[slot]
      return id and { itemID = id, stackCount = 200 } or nil
    end,
  }
  -- Character: class, faction, equipped ranged weapon. mock.items[id] = { classID, subClassID }.
  mock.class, mock.faction, mock.ranged = "HUNTER", "Horde", nil
  mock.items = { [3036] = { 2, 2 }, [2511] = { 2, 3 }, [5000] = { 2, 18 }, [2947] = { 2, 16 },
    [15997] = { 6, 3 }, [18042] = { 6, 2 } } -- Thorium Shells (bullet), Thorium Headed Arrow
  mock.classID, mock.raceID, mock.known = 3, 2, {} -- Hunter, Orc; mock.known[spellID] = true
  _G.UnitClass = function() return mock.class, mock.class, mock.classID end
  _G.UnitRace = function() return "Orc", "Orc", mock.raceID end
  _G.C_SpellBook = { IsSpellKnown = function(id) return mock.known[id] == true end }
  _G.C_Spell = { GetSpellName = function() return nil end } -- not cached: the data name is used
  _G.UnitFactionGroup = function() return mock.faction, mock.faction end
  _G.INVSLOT_RANGED = 18
  _G.GetInventoryItemID = function(_, slot) if slot == 18 then return mock.ranged end end
  _G.Enum = { ItemClass = { Weapon = 2 }, ItemWeaponSubclass = { Bows = 2, Guns = 3, Crossbow = 18, Thrown = 16 } }
  _G.C_Item = {
    GetItemInfoInstant = function(id)
      local it = mock.items[id]
      if it then return id, nil, nil, nil, nil, it[1], it[2] end
    end,
    GetItemNameByID = function() return nil end, -- not cached yet: addon falls back to its own name
  }
  _G.LibQuestieDB = nil
  mapAPI()
end

-- Kalimdor (1414) is WORLD yards wide; each zone is a square inside it: { left, top, size } in continent units.
mock.WORLD = 20000
mock.zones = { [1414] = { 0, 0, 1 }, [1413] = { 0.5, 0.4, 0.2 }, [1440] = { 0.3, 0.1, 0.2 },
  [1456] = { 0.4, 0.6, 0.1 } }
function mock.vec(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
function mock.toContinent(map, x, y)
  local z = mock.zones[map]
  if not z then return nil end
  return z[1] + z[3] * x, z[2] + z[3] * y
end

-- Map / waypoint API. mock.playerMap/X/Y place the player; mock.waypoint records the native one.
function mapAPI()
  mock.playerMap, mock.playerX, mock.playerY = 1413, 0.5, 0.5
  mock.mapNames = { [1413] = "The Barrens", [1440] = "Ashenvale", [1456] = "Thunder Bluff" }
  mock.waypoint, mock.superTracked, mock.canWaypoint = nil, false, true
  _G.C_Map = {
    GetBestMapForUnit = function() return mock.playerMap end,
    GetPlayerMapPosition = function(map)
      if not mock.playerX then return nil end
      local x, y = mock.playerX, mock.playerY
      if map == 1414 then x, y = mock.toContinent(mock.playerMap, x, y) end
      return mock.vec(x, y)
    end,
    -- World positions as WoW stores them: world X runs north, world Y runs west (swapped against map axes).
    GetWorldPosFromMapPos = function(map, v)
      local x, y = v:GetXY()
      local cx, cy = mock.toContinent(map, x, y)
      if not cx then return nil end
      return 0, mock.vec(-cy * mock.WORLD, -cx * mock.WORLD)
    end,
    GetMapPosFromWorldPos = function(_, w)
      local wx, wy = w:GetXY()
      return 1414, mock.vec(-wy / mock.WORLD, -wx / mock.WORLD)
    end,
    GetMapInfo = function(map)
      if map == 1414 then return { name = "Kalimdor", mapType = 2 } end
      return mock.mapNames[map] and { name = mock.mapNames[map], mapType = 3, parentMapID = 1414 }
    end,
    GetMapChildrenInfo = function(map)
      if map ~= 1414 then return {} end
      local out = {}
      for id, name in pairs(mock.mapNames) do out[#out + 1] = { mapID = id, name = name } end
      return out
    end,
    CanSetUserWaypointOnMap = function() return mock.canWaypoint end,
    SetUserWaypoint = function(point) mock.waypoint = point end,
    ClearUserWaypoint = function() mock.waypoint = nil end,
    GetUserWaypoint = function()
      local w = mock.waypoint
      if w then return { uiMapID = w.map, position = { GetXY = function() return w.x, w.y end } } end
    end,
  }
  _G.UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { map = map, x = x, y = y } end }
  _G.C_SuperTrack = { SetSuperTrackedUserWaypoint = function(on) mock.superTracked = on end }
  _G.TomTom = nil
  _G.ShortestPathForever = nil
  _G.CreateVector2D = mock.vec
  mock.indoors, mock.rotate, mock.facing = false, false, 0
  _G.IsIndoors = function() return mock.indoors end
  _G.C_CVar = { GetCVarBool = function(name) return name == "rotateMinimap" and mock.rotate end }
  _G.GetPlayerFacing = function() return mock.facing end
end

-- LibQuestieDB stand-in. quests[id] = { npc = id } | { object = id }; npcs/objects[id] = { name, spawns }.
-- Zone tables are Lua source strings, as QuestieDB ships them. areaIds: 17 -> 1413, 331 -> 1440, 1638 -> 1456.
function mock.questieDB(quests, npcs, objects, contractOk, itemVendors)
  local function entity(rows)
    return {
      name = function(id) return (rows[id] or {}).name end,
      spawns = function(id) return (rows[id] or {}).spawns end,
      friendlyToFaction = function(id) return (rows[id] or {}).friendly end,
    }
  end
  _G.LibQuestieDB = {
    RequireContract = function() if contractOk == false then return false, "contract mismatch" end return true end,
    Quest = { finishedBy = function(id)
      local q = quests[id]
      if not q then return nil end
      return { q.npc and { q.npc } or nil, q.object and { q.object } or nil }
    end },
    Npc = entity(npcs or {}),
    Object = entity(objects or {}),
    Item = { vendors = function(id) return (itemVendors or {})[id] end },
    Support = { Get = function() return { private = {
      areaIdToUiMapId = "return { [17] = 1413, [331] = 1440, [1638] = 1456, [400] = 999 }",
      areaIdToUiMapIdOverride = "return { [400] = 0 }",
    } } end },
  }
end

-- Quest log helpers: header("Zone"), quest(id, title, level, opts)
function mock.header(title) return { title = title, isHeader = true } end
function mock.quest(id, title, level, opts)
  local e = { questID = id, title = title, level = level }
  for k, v in pairs(opts or {}) do e[k] = v end
  return e
end

-- Any widget: records state the tests read; every other method is a harmless no-op.
-- Text height is 12 px per started 60 characters, enough to exercise card layout.
local WIDGET = {
  RegisterEvent = function(self, ev) self.events[ev] = true end,
  UnregisterEvent = function(self, ev) self.events[ev] = nil end,
  SetScript = function(self, name, fn) self.scripts[name] = fn end,
  GetScript = function(self, name) return self.scripts[name] end,
  Show = function(self) self.shown = true end,
  Hide = function(self) self.shown = false end,
  SetShown = function(self, on) self.shown = on and true or false end,
  IsShown = function(self) return self.shown end,
  SetText = function(self, t) self.text = t end,
  GetText = function(self) return self.text end,
  SetHeight = function(self, h) self.height = h end,
  GetHeight = function(self) return self.height or 0 end,
  GetWidth = function(self) return rawget(self, "width") or 0 end,
  GetCenter = function() return 0, 0 end,
  GetEffectiveScale = function() return 1 end,
  IsMouseOver = function() return false end,
  SetScale = function(self, s) self.scale = s end,
  SetPoint = function(self, ...) self.point = { ... } end,
  GetPoint = function(self) return unpack(self.point or { "CENTER", nil, "CENTER", 0, 0 }) end,
  GetStringHeight = function(self) return 12 * math.max(1, math.ceil(#(self.text or "") / 60)) end,
  CreateFontString = function() return mock.widget() end,
  CreateTexture = function() return mock.widget() end,
  SetTexture = function(self, t) self.texture = t end,
  SetRotation = function(self, r) self.rotation = r end,
  Click = function(self) if self.scripts.OnClick then self.scripts.OnClick(self) end end,
  SetChecked = function(self, on) self.checked = on end,
  SetTitle = function(self, t) self.title = t end,
  GetChecked = function(self) return self.checked end,
  CreateAnimationGroup = function(self) self.animGroup = mock.widget() return self.animGroup end,
  CreateAnimation = function() return mock.widget() end,
  Play = function(self) self.plays = (rawget(self, "plays") or 0) + 1 end,
}
-- Widget methods the addon may call without the test caring about the effect. Each name was checked
-- against the Forever 1.60.1 widget API (wow-api get_widget_methods: Frame, Button, FontString, Texture,
-- ScrollFrame, CheckButton, Minimap, AnimationGroup, Alpha), except the template mixins marked below.
-- Any other name fails the test,
-- so a misspelt or non-existent Blizzard method is caught here instead of in game.
local NOOP = {}
for name in ([[SetSize SetWidth SetJustifyH SetJustifyV ClearAllPoints SetFrameStrata SetFrameLevel SetClampedToScreen
  RegisterForDrag RegisterForClicks EnableMouse StartMoving StopMovingOrSizing SetMovable SetWordWrap SetScrollChild
  SetNormalFontObject SetHighlightFontObject SetHighlightTexture GetZoom
  SetBlendMode SetAlpha SetAllPoints SetToFinalAlpha Stop SetFromAlpha SetToAlpha SetDuration SetSmoothing SetOrder
  SetBackdrop SetBackdropColor SetBackdropBorderColor SetOwner]]):gmatch("%S+") do -- last line: template mixins
  NOOP[name] = true
end
local function noop() end

function mock.widget(fields)
  local w = { events = {}, scripts = {}, shown = true }
  for k, v in pairs(fields or {}) do w[k] = v end
  mock.widgets[#mock.widgets + 1] = w
  return setmetatable(w, { __index = function(_, k)
    if WIDGET[k] then return WIDGET[k] end
    if NOOP[k] then return noop end
    error("mock: unknown widget method or field '" .. tostring(k) .. "'", 2)
  end })
end

function mock.lastChat() return mock.chat[#mock.chat] end

-- Fire an event on every frame registered for it (as the client does).
function mock.fire(event, ...)
  for _, f in ipairs(mock.frames) do
    if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
  end
end

-- Run pending C_Timer callbacks (one "tick"); returns how many ran.
function mock.flush()
  local due = mock.timers
  mock.timers = {}
  for _, fn in ipairs(due) do fn() end
  return #due
end

-- Load addon files in TOC order with the (addonName, ns) varargs the client passes.
function mock.load(files, addonName)
  local ns = {}
  for _, path in ipairs(files) do
    local chunk = assert(loadfile(path))
    chunk(addonName or "Wowish", ns)
  end
  return ns
end

return mock
