-- Wowish services: class trainers, flight masters and repair NPCs, found once per session in QuestieDB.
-- QuestieDB has no index by NPC flag, so this walks its ~15k NPC ids in the background with a small time budget
-- per frame (no stutter), pauses in combat, and keeps only NPCs friendly to the player with one known spawn.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local L = ns.L

local BUDGET_MS = 2 -- per frame
local KINDS = { trainer = "TRAINER", flight = "FLIGHT_MASTER", repair = "REPAIR" } -- LibQuestieDB.Enum.npcFlags keys

local state = "idle" -- idle | scanning | done | unavailable
local found, ids, index, flags, letter
local runner = CreateFrame("Frame")

-- Flags are single bits; Lua 5.1 has no bit operators.
local function has(mask, flag)
  return flag ~= nil and math.floor(mask / flag) % 2 == 1
end

local function step()
  local lib = ns.Questie()
  local started = debugprofilestop()
  while index <= #ids do
    local id = ids[index]
    index = index + 1
    local mask = lib.Npc.npcFlags(id)
    if mask and mask > 0 then
      for kind, key in pairs(KINDS) do
        if has(mask, flags[key]) and (lib.Npc.friendlyToFaction(id) or ""):find(letter, 1, true) then
          local p = ns.NpcPlace(id)
          if p then found[kind][#found[kind] + 1] = { id = id, place = p, subName = lib.Npc.subName(id) } end
        end
      end
    end
    if debugprofilestop() - started > BUDGET_MS then return end
  end
  state = "done"
  runner:SetScript("OnUpdate", nil)
  ns.RequestUpdate() -- tips can now point at the nearest trainer or repair NPC
end

function ns.StartServiceScan()
  if state ~= "idle" then return end
  local lib = ns.Questie()
  local enum = lib and lib.Enum and lib.Enum.npcFlags
  if not (enum and lib.Npc and lib.Npc.GetAllIds and lib.Npc.npcFlags) then
    state = "unavailable"
    return
  end
  ids, index, flags = lib.Npc.GetAllIds(), 1, enum
  letter = (UnitFactionGroup("player") or "Horde"):sub(1, 1)
  found = { trainer = {}, flight = {}, repair = {} }
  state = "scanning"
  runner:SetScript("OnUpdate", function()
    if ns.inCombat() then return end -- nothing in combat; carries on after
    local ok = xpcall(step, ns.report)
    if not ok then -- a QuestieDB change: stop quietly, tips keep working without these places
      state = "unavailable"
      runner:SetScript("OnUpdate", nil)
    end
  end)
end

function ns.ServiceScanState()
  return state
end

-- Remember where the player opened a repairing vendor or their class trainer (works without QuestieDB).
function ns.LearnPlace(kind)
  if not ns.db then return end
  local map, x, y = ns.PlayerPosition()
  if not (map and x and y) then return end
  local name = UnitName("npc")
  if issecretvalue and issecretvalue(name) then name = nil end
  local class = kind == "trainer" and select(2, UnitClass("player")) or nil
  ns.db.places[kind][map .. ":" .. math.floor(x * 200) .. ":" .. math.floor(y * 200)] = {
    map = map, x = x, y = y, name = name, faction = (UnitFactionGroup("player") or "Horde"):sub(1, 1), class = class }
end

-- Nearest service of a kind on the player's continent (straight distance), optionally filtered:
-- entry { id, place = { map, x, y, name }, subName } from the scan, or { place, class, learned = true } from a
-- visited place; yards.
function ns.NearestService(kind, filter)
  local list = {}
  if state == "done" then for _, e in ipairs(found[kind]) do list[#list + 1] = e end end
  local mine = (UnitFactionGroup("player") or "Horde"):sub(1, 1)
  for _, p in pairs(ns.db and ns.db.places and ns.db.places[kind] or {}) do
    if type(p) == "table" and p.faction == mine and type(p.map) == "number"
        and type(p.x) == "number" and type(p.y) == "number" then
      list[#list + 1] = { place = { map = p.map, x = p.x, y = p.y, name = p.name }, class = p.class, learned = true }
    end
  end
  local best, bestD
  for _, e in ipairs(list) do
    if not filter or filter(e) then
      local east, north = ns.GuideOffset(e.place)
      if east then
        local d = east * east + north * north
        if not bestD or d < bestD then best, bestD = e, d end
      end
    end
  end
  return best, bestD and math.sqrt(bestD)
end

ns.NEAR_YARDS, ns.NEAR_BOOST = 200, 8

-- A service tip moves up and says so when its NPC is close. Distance, not IsResting(): a village inn rests too.
function ns.NearBoost(tip, yards)
  if type(yards) == "number" and yards <= ns.NEAR_YARDS then
    tip.priority = math.min(100, tip.priority + ns.NEAR_BOOST)
    tip.why = tip.why .. " " .. string.format(L["It is right here: %d yards away."], math.floor(yards + 0.5))
  end
  return tip
end

local merchant = CreateFrame("Frame")
merchant:RegisterEvent("MERCHANT_SHOW")
merchant:SetScript("OnEvent", function()
  xpcall(function()
    if CanMerchantRepair and CanMerchantRepair() then ns.LearnPlace("repair") end
  end, ns.report)
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
  C_Timer.After(10, ns.StartServiceScan) -- after the login rush
end)
