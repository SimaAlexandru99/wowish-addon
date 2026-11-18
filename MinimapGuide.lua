-- Wowish minimap guide: when no route planner is installed, a few dots on the minimap point from the player
-- toward the target, with an arrow on the minimap's edge while the target is beyond it. A straight line only:
-- it does not know roads, walls or flight paths (ShortestPathForever draws real routes when installed).
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
local _, ns = ...

local DOTS, ARRIVED_YARDS, TICK = 6, 10, 0.1
-- shortcut: minimap diameter in yards per zoom level (the values pin libraries use); verify in game if the
-- dots drift from TomTom's minimap pin.
local OUTDOOR = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }
local INDOOR = { [0] = 300, 240, 180, 120, 80, 50 }

local frame, dots, arrow, target, elapsed = nil, {}, nil, nil, 0

local function vec(x, y)
  if CreateVector2D then return CreateVector2D(x, y) end
  return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end

-- Continent map that contains uiMapID (2 = continent), or nil.
local function continentOf(map)
  local info = map and C_Map.GetMapInfo(map)
  while info and info.mapType and info.mapType > 2 and info.parentMapID do
    map, info = info.parentMapID, C_Map.GetMapInfo(info.parentMapID)
  end
  return info and info.mapType == 2 and map or nil
end

-- Position of a place on the continent map cont, or nil when it is not on that continent.
local function onContinent(place, cont)
  local continentID, world = C_Map.GetWorldPosFromMapPos(place.map, vec(place.x, place.y))
  if not world then return nil end
  local _, pos = C_Map.GetMapPosFromWorldPos(continentID, world, cont)
  return pos
end

-- Offset player -> place in yards, east and north, or nil when not on the same continent. With `from` (another
-- place), the offset is measured from it instead of from the player.
-- Both points are projected onto the continent map, whose orientation (x east, y south) is known.
function ns.GuideOffset(place, from)
  local cont = continentOf(from and from.map or C_Map.GetBestMapForUnit("player"))
  if not cont then return nil end
  local ppos
  if from then ppos = onContinent(from, cont) else ppos = C_Map.GetPlayerMapPosition(cont, "player") end
  if not ppos then return nil end
  local tpos = onContinent(place, cont)
  if not tpos then return nil end
  -- the continent's size in yards along each map axis; world axes are swapped against map axes, so measure
  -- distances instead of reading one world coordinate
  local function yards(mx, my)
    local _, a = C_Map.GetWorldPosFromMapPos(cont, vec(0, 0))
    local _, b = C_Map.GetWorldPosFromMapPos(cont, vec(mx, my))
    local ax, ay = a:GetXY()
    local bx, by = b:GetXY()
    return math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
  end
  local px, py = ppos:GetXY()
  local tx, ty = tpos:GetXY()
  return (tx - px) * yards(1, 0), (py - ty) * yards(0, 1) -- map y grows southward
end

local function radiusYards()
  local zoom = Minimap:GetZoom() or 0
  local sizes = (IsIndoors and IsIndoors()) and INDOOR or OUTDOOR
  return (sizes[zoom] or sizes[0]) / 2
end

-- East/north yards -> minimap pixels, following "Rotate Minimap".
function ns.GuideToMinimap(east, north)
  if C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("rotateMinimap") then
    local f = GetPlayerFacing() or 0 -- radians counter-clockwise from north
    east, north = east * math.cos(f) + north * math.sin(f), -east * math.sin(f) + north * math.cos(f)
  end
  local scale = (Minimap:GetWidth() / 2) / radiusYards()
  return east * scale, north * scale
end

local function hideMarks()
  for _, d in ipairs(dots) do d:Hide() end
  if arrow then arrow:Hide() end
end

local function draw()
  local east, north = ns.GuideOffset(target)
  if not east or ns.inCombat() then return hideMarks() end
  if math.sqrt(east * east + north * north) <= ARRIVED_YARDS then
    local name = target.title or ns.FormatPlace(target)
    ns.StopGuide()
    ns.Say(string.format(ns.L["you have arrived: %s."], name))
    return
  end
  local x, y = ns.GuideToMinimap(east, north)
  local edge = Minimap:GetWidth() / 2 - 8
  local dist = math.sqrt(x * x + y * y)
  local reach = math.min(dist, edge)
  for i, d in ipairs(dots) do
    local t = reach * i / (DOTS + 1) / dist
    d:ClearAllPoints()
    d:SetPoint("CENTER", Minimap, "CENTER", x * t, y * t)
    d:Show()
  end
  arrow:ClearAllPoints()
  arrow:SetPoint("CENTER", Minimap, "CENTER", x * reach / dist, y * reach / dist)
  arrow:SetRotation(math.atan2(-x, y)) -- texture points up; positive rotation is counter-clockwise
  arrow:Show()
end

local function build()
  frame = CreateFrame("Frame", nil, Minimap)
  for i = 1, DOTS do
    local d = Minimap:CreateTexture(nil, "OVERLAY")
    d:SetTexture("Interface\\COMMON\\Indicator-Yellow")
    d:SetSize(8, 8)
    dots[i] = d
  end
  arrow = Minimap:CreateTexture(nil, "OVERLAY")
  arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
  arrow:SetSize(24, 24)
  frame:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < TICK or not target then return end
    elapsed = 0
    draw()
  end)
end

function ns.StartGuide(place, title)
  if not frame then build() end
  target = { map = place.map, x = place.x, y = place.y, title = title }
  elapsed = TICK -- draw on the next frame
  frame:Show()
end

function ns.StopGuide()
  target = nil
  if frame then frame:Hide() end
  hideMarks()
end

function ns.GuideActive()
  return target ~= nil
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", hideMarks) -- the next tick after combat draws them again
