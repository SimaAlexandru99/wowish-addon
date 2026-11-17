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

local LANDING = 60 -- seconds after a Hearthstone cast in which the arrival is taken as the inn

local cast -- GetTime() of the last Hearthstone cast still waiting for its arrival

-- Stores where the player stands as the inn; true when it did.
local function remember()
  local map, x, y = ns.PlayerPosition()
  if x == nil or ns.db == nil then return false end
  local name = GetBindLocation and GetBindLocation()
  ns.db.hearth[ns.CharKey()] = { map = map, x = x, y = y, name = name }
  return true
end

-- The bind location is named after the inn's subzone, or the zone in a city: only there is the arrival the inn
-- (a zone event can fire before the teleport, and a late one would record wherever the player walked in).
local function atBind()
  local bind = GetBindLocation and GetBindLocation()
  if type(bind) ~= "string" or bind == "" then return false end
  return bind == (GetSubZoneText and GetSubZoneText()) or bind == (GetZoneText and GetZoneText())
    or bind == (GetRealZoneText and GetRealZoneText())
end

local frame = CreateFrame("Frame")
for _, ev in ipairs({ "HEARTHSTONE_BOUND", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED" }) do
  frame:RegisterEvent(ev)
end
if frame.RegisterUnitEvent then
  frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
else
  frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end
frame:SetScript("OnEvent", function(_, event, unit, _, spellID)
  xpcall(function()
    if event == "HEARTHSTONE_BOUND" then
      remember()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
      -- only a flag: this fires in combat
      if unit == "player" and not (issecretvalue and issecretvalue(spellID)) and spellID == 8690 then
        cast = GetTime()
      end
    elseif cast then
      if GetTime() - cast > LANDING then
        cast = nil
      elseif atBind() and remember() then -- position unknown during the loading screen: the next event retries
        cast = nil
      end
    end
  end, ns.report)
end)
ns.frame:RegisterEvent("BAG_UPDATE_COOLDOWN")
ns.frame:RegisterEvent("HEARTHSTONE_BOUND")

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
  local start, duration = C_Container.GetItemCooldown(STONE)
  local left = (type(start) == "number" and type(duration) == "number" and start > 0 and duration > 0)
    and (start + duration - GetTime()) or 0
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
