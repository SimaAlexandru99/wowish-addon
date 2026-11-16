-- Wowish waypoints, only on an explicit player command: TomTom if loaded, else the client's own
-- user waypoint, else coordinates in chat. Never persistent, never in combat.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
local _, ns = ...

local tomtomUid, nativePlace -- what we set; nativePlace = { map, x, y }

function ns.FormatPlace(place)
  return string.format("%s %.1f, %.1f", ns.MapName(place.map), place.x * 100, place.y * 100)
end

-- Is the client's user waypoint still the one we placed? (The player may have moved or replaced it.)
local function isOurs(p)
  if not C_Map.GetUserWaypoint then return true end -- cannot tell: keep the old behaviour
  local cur = C_Map.GetUserWaypoint()
  local pos = cur and cur.position
  if not (pos and pos.GetXY) or cur.uiMapID ~= p.map then return false end
  local x, y = pos:GetXY()
  return math.abs(x - p.x) < 1e-3 and math.abs(y - p.y) < 1e-3
end

function ns.ClearWaypoint()
  local cleared = false
  if tomtomUid and TomTom and TomTom.RemoveWaypoint then
    TomTom:RemoveWaypoint(tomtomUid)
    cleared = true
  end
  if nativePlace and C_Map and C_Map.ClearUserWaypoint and isOurs(nativePlace) then
    C_Map.ClearUserWaypoint() -- only the one we set; never touch a waypoint the player placed
    cleared = true
  end
  tomtomUid, nativePlace = nil, nil
  return cleared
end

-- place = { map = uiMapId, x, y (0..1) }. Returns "tomtom", "native", "chat" or "combat".
function ns.SetWaypoint(place, title)
  if ns.inCombat() then return "combat" end
  ns.ClearWaypoint()
  if TomTom and TomTom.AddWaypoint then
    tomtomUid = TomTom:AddWaypoint(place.map, place.x, place.y, {
      title = title, from = "Wowish", persistent = false, minimap = true, world = true, crazy = true,
    })
    if tomtomUid then return "tomtom" end -- TomTom refused (e.g. unknown map): try the native pin
  end
  local M = C_Map
  if M and M.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates
      and (not M.CanSetUserWaypointOnMap or M.CanSetUserWaypointOnMap(place.map)) then
    local ok = pcall(M.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(place.map, place.x, place.y))
    if ok then
      nativePlace = { map = place.map, x = place.x, y = place.y }
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
      end
      return "native"
    end
  end
  return "chat"
end
