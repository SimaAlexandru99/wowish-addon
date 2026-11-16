-- Wowish "take me there": with ShortestPathForever installed, ask it for the real route (walking, flights,
-- boats, portals; it draws the route on the map and minimap). Without it, a waypoint (TomTom or the game's pin)
-- plus the straight-line minimap guide. Only on an explicit click or command, never in combat.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
local _, ns = ...

local OWNER = "Wowish" -- how ShortestPathForever knows our journeys apart from its own and other addons'

-- ShortestPathForever's public API (ShortestPathForever.API, places as uiMapID + 0..1 fractions), or nil.
local function planner()
  local spf = rawget(_G, "ShortestPathForever")
  local api = type(spf) == "table" and spf.API
  return type(api) == "table" and type(api.Navigate) == "function" and api or nil
end
ns.RoutePlanner = planner

-- Seconds by the fastest route from here, or nil (no planner, unknown position, unreachable).
function ns.RouteSeconds(place)
  local api = planner()
  local map, x, y = ns.PlayerPosition()
  if not (api and api.Estimate and x) then return nil end
  local ok, seconds = pcall(api.Estimate, map, x, y, place.map, place.x, place.y)
  return ok and type(seconds) == "number" and seconds or nil
end

-- Returns "route", "tomtom", "native", "chat" or "combat".
function ns.TakeMeThere(place, title)
  if ns.inCombat() then return "combat" end
  ns.ClearWaypoint()
  local api = planner()
  if api then
    local ok, started = xpcall(function() return api.Navigate(OWNER, place.map, place.x, place.y, title) end,
      ns.report)
    if ok and started then return "route" end
  end
  local how = ns.SetWaypoint(place, title)
  if how ~= "combat" then ns.StartGuide(place, title) end
  return how
end

-- Stops what Wowish started: our ShortestPathForever journey, waypoint and minimap guide. True if anything stopped.
function ns.StopNavigation()
  local stopped = false
  local api = planner()
  if api and api.Cancel then
    local ok, cancelled = pcall(api.Cancel, OWNER) -- only ends a journey we own
    stopped = ok and cancelled == true
  end
  if ns.GuideActive() then
    ns.StopGuide()
    stopped = true
  end
  return ns.ClearWaypoint() or stopped
end
