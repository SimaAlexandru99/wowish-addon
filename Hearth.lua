-- Wowish Hearthstone hint: says when the Hearthstone puts the player close to a tip's place. Text only, never uses
-- the stone. Learns where the inn is (per character) when the player binds or lands there; skipped when
-- ShortestPathForever is installed, because it already routes with the Hearthstone.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local L = ns.L

local STONE = 6948
local INN_YARDS = 300 -- the inn must be this close to the place
local FAR_YARDS = 1000 -- the player must be at least this far already
local SOON = 300 -- seconds of cooldown still worth mentioning

-- Stores where the player stands as the inn; true when it did.
local function remember()
  local map, x, y = ns.PlayerPosition()
  if x == nil or ns.db == nil then return false end
  local name = GetBindLocation and GetBindLocation()
  ns.db.hearth[ns.CharKey()] = { map = map, x = x, y = y, name = name }
  ns.RequestUpdate()
  return true
end

-- The bind location is named after the inn's subzone, or the zone in a city.
local function atBind()
  local bind = GetBindLocation and GetBindLocation()
  if type(bind) ~= "string" or bind == "" then return false end
  return bind == (GetSubZoneText and GetSubZoneText()) or bind == (GetZoneText and GetZoneText())
    or bind == (GetRealZoneText and GetRealZoneText())
end

-- After a Hearthstone cast the player stands at the inn. A short timer, not zone events: an event can fire
-- before the teleport, and none fires when the cast started in the inn's own subzone. Timers wait out a loading
-- screen; the position can still be unknown on the first frame after it, hence the retries.
local function landed(tries)
  if not atBind() then return end
  if not remember() and tries > 0 then
    C_Timer.After(3, function() xpcall(function() landed(tries - 1) end, ns.report) end)
  end
end

-- Cooldown seconds left on the stone; the global cooldown (a second or two after any cast) counts as ready.
local function cooldownLeft()
  local start, duration = C_Container.GetItemCooldown(STONE)
  if type(start) ~= "number" or type(duration) ~= "number" or start <= 0 or duration <= 2 then return 0 end
  return math.max(0, start + duration - GetTime())
end

-- BAG_UPDATE_COOLDOWN fires for every cooldown, so the tips are refreshed only when the stone moves between
-- silent, "soon" and "ready"; one timer wakes us at the next boundary, where no event fires.
local lastState, timer
local function watch()
  local left = cooldownLeft()
  local state = left <= 0 and "ready" or left <= SOON and "soon" or "silent"
  if state ~= lastState then
    lastState = state
    ns.RequestUpdate()
  end
  if left > 0 and not timer then
    timer = true
    C_Timer.After((left > SOON and left - SOON or left) + 1, function()
      timer = nil
      xpcall(watch, ns.report)
    end)
  end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("HEARTHSTONE_BOUND")
frame:RegisterEvent("BAG_UPDATE_COOLDOWN")
if frame.RegisterUnitEvent then
  frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
else
  frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end
frame:SetScript("OnEvent", function(_, event, unit, _, spellID)
  xpcall(function()
    if event == "HEARTHSTONE_BOUND" then
      C_Timer.After(1, function() xpcall(remember, ns.report) end) -- the new bind name may not be readable yet
    elseif event == "BAG_UPDATE_COOLDOWN" then
      watch()
    elseif unit == "player" and not (issecretvalue and issecretvalue(spellID)) and spellID == 8690 then
      -- only a timer: this fires in combat
      C_Timer.After(2, function() xpcall(function() landed(2) end, ns.report) end)
    end
  end, ns.report)
end)

local function length(e, n) return math.sqrt(e * e + n * n) end

-- Text and state ("ready" | "soon") when the Hearthstone is a good way to reach place, else nil.
function ns.HearthHint(place)
  if not ns.db or not ns.db.hearthHint or (ns.RoutePlanner and ns.RoutePlanner()) then return nil end
  local inn = ns.db.hearth[ns.CharKey()]
  if type(inn) ~= "table" or type(inn.map) ~= "number" or type(inn.x) ~= "number" or type(inn.y) ~= "number" then
    return nil
  end
  if type(inn.name) == "string" and inn.name ~= GetBindLocation() then return nil end -- re-bound unseen
  if C_Item.GetItemCount(STONE) <= 0 then return nil end
  local left = cooldownLeft()
  if left > SOON then return nil end
  local e, n = ns.GuideOffset(place, inn)
  if not e then return nil end
  local yards = length(e, n)
  if yards > INN_YARDS then return nil end
  local pe, pn = ns.GuideOffset(place) -- nil (other continent, no position) counts as far
  if type(pe) == "number" and length(pe, pn) <= FAR_YARDS then return nil end
  local where = type(inn.name) == "string" and inn.name or L["your inn"]
  local d = math.floor(yards + 0.5)
  if left <= 0 then
    return string.format(L["Your Hearthstone is ready: %s is %d yards from there."], where, d), "ready"
  end
  return string.format(L["Your Hearthstone is ready in under 5 min: %s is %d yards from there."], where, d), "soon"
end
