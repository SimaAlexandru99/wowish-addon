-- Wowish rules for every class: completed quests, unspent talents, bag space, next zone.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
-- Rules only read client state (Forever 1.60.1 APIs checked with wow-addon-api-mcp, build 70755).
local _, ns = ...
local L = ns.L

local QUEST_EVENTS = { "QUEST_LOG_UPDATE", "PLAYER_LEVEL_UP" }
-- Turn-in ranking depends on the player's map, so it must also follow zone changes.
local TURNIN_EVENTS = { "QUEST_LOG_UPDATE", "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }

-- Quest tags that mean "not solo questing": Group, PvP, Raid, Dungeon, Raid10, Raid25 (Enum.QuestTag).
local GROUP_TAGS = { [1] = true, [41] = true, [62] = true, [81] = true, [88] = true, [89] = true }
-- Used only if this client lacks C_QuestLog.GetQuestTagInfo.
local FALLBACK_SKIP_HEADERS = {
  ["Cooking"] = true, ["Arathi Basin"] = true, ["Warsong Gulch"] = true, ["Ragefire Chasm"] = true,
  ["Wailing Caverns"] = true, ["Shadowfang Keep"] = true, ["Blackfathom Deeps"] = true, ["Razorfen Kraul"] = true,
}

local function playerLevel()
  return (UnitLevel and UnitLevel("player")) or 0
end

local function isGroupContent(questID, header)
  local QL = C_QuestLog
  if type(QL.GetQuestTagInfo) ~= "function" then return FALLBACK_SKIP_HEADERS[header] or false end
  local tag = QL.GetQuestTagInfo(questID)
  return tag ~= nil and (GROUP_TAGS[tag.tagID] or (tag.tradeskillLineID or 0) > 0) or false
end

-- shortcut: quests under collapsed headers may not be listed by GetInfo; good enough until a player reports it.
function ns.ReadQuestLog()
  local QL, out, header = C_QuestLog, {}, nil
  for i = 1, QL.GetNumQuestLogEntries() do
    local info = QL.GetInfo(i)
    if info and info.isHeader then
      header = info.title
    elseif info and info.questID and not info.isHidden and not info.isTask then
      out[#out + 1] = {
        id = info.questID, title = info.title or "?", level = info.level, header = header, -- title can be uncached
        complete = QL.IsComplete(info.questID),
        trivial = type(QL.IsQuestTrivial) == "function" and QL.IsQuestTrivial(info.questID) == true,
      }
    end
  end
  return out
end

local function allTitles(quests)
  local out = {}
  for i, q in ipairs(quests) do out[i] = q.title end
  return out
end

local function titles(quests, max)
  local names = {}
  for i = 1, math.min(#quests, max) do names[i] = quests[i].title end
  return table.concat(names, ", ") .. (#quests > max and ", ..." or "")
end

local function greyOpen()
  local out = {}
  for _, q in ipairs(ns.ReadQuestLog()) do
    if q.trivial and not q.complete then out[#out + 1] = q end
  end
  return out
end

ns.RegisterRule({
  id = "turnin", events = TURNIN_EVENTS, maxInTop = 2,
  evaluate = function()
    local done, openZones = {}, {}
    for _, q in ipairs(ns.ReadQuestLog()) do
      if q.complete then done[#done + 1] = q elseif q.header then openZones[q.header] = true end
    end
    if #done == 0 then return {} end

    -- One suggestion per turn-in map (QuestieDB); quests without a known place share one group.
    local groups, order = {}, {}
    for _, q in ipairs(done) do
      local place = ns.QuestFinisher(q.id)
      local key = place and place.map or "?"
      if not groups[key] then groups[key], order[#order + 1] = {}, key end
      table.insert(groups[key], { quest = q, place = place })
    end

    local pmap, px, py = ns.PlayerPosition()
    local function dist(e)
      if not (e.place and px and e.place.map == pmap) then return math.huge end
      return (e.place.x - px) ^ 2 + (e.place.y - py) ^ 2
    end
    local out = {}
    for _, key in ipairs(order) do
      local list = groups[key]
      table.sort(list, function(a, b)
        local da, db = dist(a), dist(b)
        if da ~= db then return da < db end
        return a.quest.title < b.quest.title
      end)
      local quests = {}
      for i, e in ipairs(list) do quests[i] = e.quest end
      local first = list[1]
      local s = { id = "turnin:" .. tostring(key), kind = "quest", details = allTitles(quests),
        why = L["Completed quests give their XP only when you hand them in."] }
      if not first.place then
        s.priority = 70
        s.what = string.format(L["Turn in %s: %s."], ns.Count(#quests, "completed quest"), titles(quests, 4))
      else
        local zone = ns.MapName(key)
        s.what = string.format(L["Turn in %s in %s: %s."], ns.Count(#quests, "quest"), zone, titles(quests, 4))
        if key == pmap then
          s.priority, s.why = 90, s.why .. " " .. L["They are on your current map."]
        elseif openZones[zone] then
          s.priority, s.why = 68, s.why .. " " .. L["You have open quests there anyway."]
        else
          s.priority, s.why = 60, s.why .. " " .. L["Worth it when you pass through."]
        end
        s.waypoint = { map = first.place.map, x = first.place.x, y = first.place.y,
          title = string.format("Wowish: %s (%s)", first.quest.title, first.place.name or "?") }
      end
      out[#out + 1] = s
    end
    return out
  end,
})

ns.RegisterRule({
  id = "talents", events = { "PLAYER_LEVEL_UP", "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE" },
  evaluate = function()
    local CT = C_ClassTalents
    if type(CT) ~= "table" or type(CT.HasUnspentTalentPoints) ~= "function" then return {} end
    local has, classPts, specPts = CT.HasUnspentTalentPoints()
    local n = (classPts or 0) + (specPts or 0)
    if not has or n <= 0 then return {} end
    return { {
      id = "talents", kind = "talent", priority = 95, hint = "talents",
      what = string.format(L["You have %s."], ns.Count(n, "unspent talent point")),
      why = L["Open your talents and spend them: an unspent point is power you are not using."],
    } }
  end,
})

-- Regular bags only: backpack + 4 bag slots. Specialty bags (quiver, ammo pouch) and the reagent bag
-- cannot hold loot, so their free slots would hide a full inventory.
ns.RegisterRule({
  id = "bags", events = { "BAG_UPDATE_DELAYED" },
  evaluate = function()
    local C, total, free = C_Container, 0, 0
    for bag = 0, 4 do
      local slots = C.GetContainerNumSlots(bag) or 0
      local nfree, family = C.GetContainerNumFreeSlots(bag)
      if slots > 0 and (family or 0) == 0 then
        total, free = total + slots, free + (nfree or 0)
      end
    end
    if total == 0 or free > 4 then return {} end
    return { {
      -- with 0 free slots loot is being lost right now
      id = "bags", kind = "bags", priority = free == 0 and 86 or 65, hint = "bags",
      state = free == 0 and "full" or "almost", -- a hidden tip comes back when the bags fill, not at every loot
      what = string.format(L["Bags almost full: %s of %d."], ns.Count(free, "free slot"), total),
      why = L["With full bags you start leaving loot behind. Sell or destroy grey items."],
    } }
  end,
})

ns.RegisterRule({
  id = "zone", events = QUEST_EVENTS,
  evaluate = function()
    local lvl, zones = playerLevel(), {}
    for _, q in ipairs(ns.ReadQuestLog()) do
      if not q.complete and q.header and q.level and math.abs(q.level - lvl) <= 3
          and not isGroupContent(q.id, q.header) then
        zones[q.header] = zones[q.header] or {}
        table.insert(zones[q.header], q)
      end
    end
    local best, quests
    for zone, list in pairs(zones) do
      if not best or #list > #quests or (#list == #quests and zone < best) then best, quests = zone, list end
    end
    if not best then return {} end
    local xpMax = UnitXPMax and UnitXPMax("player") or 0
    local xp = xpMax > 0 and string.format(L[" You are at %d%% of level %d."],
      math.floor(UnitXP("player") / xpMax * 100), lvl) or ""
    return { {
      id = "zone:" .. best, kind = "zone", priority = 50, details = allTitles(quests), state = best,
      action = { open = "map", arg = ns.ZoneMapID(best) },
      what = string.format(L["Keep questing in %s: %s at your level (%s)."],
        best, ns.Count(#quests, "open quest"), titles(quests, 3)),
      why = L["Most of your active objectives near your level are there, so the least travel per XP."] .. xp,
    } }
  end,
})

ns.RegisterRule({
  id = "greyquests", events = QUEST_EVENTS,
  evaluate = function()
    if type(C_QuestLog.IsQuestTrivial) ~= "function" then return {} end
    local list = greyOpen()
    if #list < 3 then return {} end
    return { {
      id = "greyquests", kind = "quest", priority = 35, details = allTitles(list),
      what = string.format(L["%s in your log give almost no XP now: %s."], ns.Count(#list, "quest"), titles(list, 3)),
      -- luacheck: push ignore 631
      why = L["Abandon them to free room, unless you want their rewards or the quests that follow them. Wowish never abandons a quest for you."],
      -- luacheck: pop
    } }
  end,
})

ns.RegisterRule({
  id = "questlog", events = QUEST_EVENTS,
  evaluate = function()
    local QL = C_QuestLog
    if type(QL.GetNumQuestLogEntries) ~= "function" or type(QL.GetMaxNumQuestsCanAccept) ~= "function" then
      return {}
    end
    local _, used = QL.GetNumQuestLogEntries()
    local max = QL.GetMaxNumQuestsCanAccept()
    if type(used) ~= "number" or type(max) ~= "number" or max <= 0 then return {} end
    local free = max - used
    if free > 2 then return {} end
    local s = { id = "questlog", kind = "quest", priority = free <= 0 and 80 or 60,
      state = free <= 0 and "full" or "almost",
      what = string.format(L["Quest log almost full: %s of %d."], ns.Count(math.max(free, 0), "free slot"), max),
      why = L["With a full log you cannot accept new quests."] }
    local grey = greyOpen()
    if #grey > 0 then
      s.why = s.why .. " " .. string.format(L["Grey ones to drop first: %s."], titles(grey, 3))
      s.details = allTitles(grey)
    end
    return { s }
  end,
})
