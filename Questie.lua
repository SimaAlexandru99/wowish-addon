-- Wowish: optional quest locations from QuestieDB, read at run time through its public API.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
-- Nothing from QuestieDB is copied into this addon; without QuestieDB, advice has no location.
local _, ns = ...

local CONTRACT = 4 -- LibQuestieDB contract this file was written against (src/config.lua)
local lib          -- nil: not checked yet, false: unavailable, table: LibQuestieDB
local zoneMap      -- nil: not built, false: unavailable, table: areaId -> uiMapId

-- LibQuestieDB if it is installed and speaks a compatible contract; the reason is kept for the UI.
function ns.Questie()
  if lib == nil then
    local candidate = rawget(_G, "LibQuestieDB")
    if type(candidate) ~= "table" or type(candidate.RequireContract) ~= "function" then
      lib, ns.questieStatus = false, "missing"
    else
      local ok, msg = candidate.RequireContract(CONTRACT)
      lib, ns.questieStatus = ok and candidate or false, ok and "ok" or msg
    end
  end
  return lib or nil
end

-- QuestieDB ships its zone tables as Lua source strings ("return { ... }"); the override wins.
local function asTable(src)
  if type(src) == "table" then return src end
  if type(src) ~= "string" then return nil end
  local fn = loadstring(src)
  if fn and setfenv then setfenv(fn, {}) end -- a table literal needs no globals; deny them to foreign code
  local ok, t = pcall(fn or error)
  return ok and type(t) == "table" and t or nil
end

local function uiMapFor(areaId)
  if zoneMap == nil then
    zoneMap = false
    local zdb = lib.Support and lib.Support.Get and lib.Support.Get("ZoneDB")
    local p = zdb and zdb.private or {}
    local base = asTable(p.areaIdToUiMapId)
    if base then
      zoneMap = {}
      for k, v in pairs(base) do zoneMap[k] = v end
      for k, v in pairs(asTable(p.areaIdToUiMapIdOverride) or {}) do zoneMap[k] = v end
    end
  end
  local map = zoneMap and zoneMap[areaId]
  return map ~= 0 and map or nil -- 0 = QuestieDB hides this area on purpose
end

-- One NPC/object -> { map, x, y, name } when it has exactly one spawn outside instances.
local function place(entity, id)
  local name = entity.name(id)
  local pts = {}
  for area, coords in pairs(entity.spawns(id) or {}) do
    for _, c in ipairs(coords) do
      if c[1] and c[1] >= 0 then pts[#pts + 1] = { area, c[1], c[2] } end -- negative x: inside an instance
    end
  end
  if #pts ~= 1 then return nil, #pts == 0 and "nospawn" or "ambiguous", name end -- several spawns: do not guess
  local map = uiMapFor(pts[1][1])
  if not map then return nil, "nomap", name end
  return { map = map, x = pts[1][2] / 100, y = pts[1][3] / 100, name = name }
end

local function finisher(questID)
  local fin = lib.Quest.finishedBy(questID)
  local npc, obj = fin and fin[1] and fin[1][1], fin and fin[2] and fin[2][1]
  if npc then return place(lib.Npc, npc) end
  if obj then return place(lib.Object, obj) end
  return nil, "unknown"
end

-- Place of one NPC (single spawn outside instances) or nil; QuestieDB errors count as "no place".
function ns.NpcPlace(npcID)
  if not ns.Questie() then return nil end
  local ok, p = pcall(place, lib.Npc, npcID)
  return ok and p or nil
end

-- Vendors of itemID friendly to faction ("Horde"/"Alliance") that have one known place.
local function vendors(itemID, faction)
  local letter, out = faction:sub(1, 1), {}
  for _, npc in ipairs(lib.Item.vendors(itemID) or {}) do
    if (lib.Npc.friendlyToFaction(npc) or ""):find(letter, 1, true) then
      local p = place(lib.Npc, npc)
      if p then out[#out + 1] = p end
    end
  end
  return out
end

-- QuestieDB data does not change during a session, so each answer (errors included, reported once) is kept.
-- Callers must not modify the returned tables.
local vendorCache, finisherCache = {}, {}

function ns.ItemVendors(itemID, faction)
  if not ns.Questie() then return {} end
  local key = itemID .. ":" .. faction
  if not vendorCache[key] then
    local ok, list = xpcall(function() return vendors(itemID, faction) end, ns.report)
    vendorCache[key] = ok and list or {}
  end
  return vendorCache[key]
end

-- Where to hand in questID: { map = uiMapId, x, y (0..1), name } or nil, reason, name.
function ns.QuestFinisher(questID)
  if not ns.Questie() then return nil, "noquestie" end
  local hit = finisherCache[questID]
  if not hit then
    local ok, where, reason, name = xpcall(function() return finisher(questID) end, ns.report)
    -- a QuestieDB change must not break the turn-in advice; the error was reported
    hit = ok and { where, reason, name } or { nil, "error" }
    finisherCache[questID] = hit
  end
  return hit[1], hit[2], hit[3]
end

function ns.MapName(map)
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
  return info and info.name or ("map " .. tostring(map))
end

-- uiMapId of a zone named like a quest-log header, searched among the zones of the player's continent.
-- nil when not found (then the world map just opens where the player is).
function ns.ZoneMapID(name)
  local M, map = C_Map, C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local info = map and M.GetMapInfo(map)
  while info and info.mapType and info.mapType > 2 and info.parentMapID do -- 2 = continent
    map, info = info.parentMapID, M.GetMapInfo(info.parentMapID)
  end
  for _, child in ipairs((map and M.GetMapChildrenInfo and M.GetMapChildrenInfo(map, 3, true)) or {}) do -- 3 = zone
    if child.name == name then return child.mapID end
  end
end

-- Player's uiMapId and position (0..1), or nil when the client cannot tell (instances, loading).
function ns.PlayerPosition()
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local pos = map and C_Map.GetPlayerMapPosition(map, "player")
  if not pos then return map end
  local x, y = pos:GetXY()
  return map, x, y
end
