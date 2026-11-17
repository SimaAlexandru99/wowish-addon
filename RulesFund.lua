-- Wowish rule, the gold plan: save for riding (Apprentice at 40, Journeyman at 60), then train it at your race's
-- trainer; the next class training cost; the riding reserve the vendor helpers (Vendor.lua) must not spend.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
-- Forever facts (Icy Veins 2026-11-08, games.gg 2026-11-16): Apprentice Riding is 100g at level 40 and includes the
-- first racial mount, Journeyman Riding 1000g at 60; Honored with your home faction takes 10% off. Paladins and
-- warlocks get Apprentice Riding from a level 40 class quest. Skyborne get no reputation discount (Wowhead
-- 2026-11-13). Spell costs are not known here (the client tells them only at an open trainer), so this rule never
-- tells you to skip training.
-- Riding trainers, home factions and the riding skill line: from Polestar (addon/Polestar/QoL/Riding.lua,
-- https://github.com/fitzforge/polestar), Copyright (C) 2026 fitzforge, GPL-3.0. See THIRD_PARTY.md.
local _, ns = ...
local L = ns.L

local HONORED, SKILL_RIDING = 6, 762 -- FactionData.reaction 6 = Honored
local TIERS = {
  { name = "Apprentice Riding", level = 40, from = 30, upto = 41, price = 1000000, spell = 33388, maxRank = 1 },
  { name = "Journeyman Riding", level = 60, from = 50, upto = 60, price = 10000000, spell = 33391, maxRank = 150 },
}
local FREE_CLASS = { PALADIN = true, WARLOCK = true } -- Apprentice only
-- By race ID: riding trainer (uiMap, 0..1) and home faction. Skyborne (95, 96): no faction, so no discount.
local SKYBORNE = { map = 2521, x = 0.535, y = 0.805, name = "Genn Fairweather" }
local RACES = {
  [1] = { faction = 72, map = 1429, x = 0.843, y = 0.649, name = "Randal Hunter" },        -- Human
  [2] = { faction = 76, map = 1454, x = 0.694, y = 0.131, name = "Kildar" },               -- Orc
  [3] = { faction = 47, map = 1426, x = 0.637, y = 0.501, name = "Ultham Ironhorn" },      -- Dwarf
  [4] = { faction = 69, map = 1438, x = 0.253, y = 0.502, name = "Jartsam" },              -- Night Elf
  [5] = { faction = 68, map = 1420, x = 0.601, y = 0.526, name = "Velma Warnam" },         -- Undead
  [6] = { faction = 81, map = 1412, x = 0.468, y = 0.620, name = "Kar Stormsinger" },      -- Tauren
  [7] = { faction = 54, map = 1426, x = 0.492, y = 0.481, name = "Binjy Featherwhistle" }, -- Gnome
  [8] = { faction = 530, map = 1411, x = 0.553, y = 0.755, name = "Xar'Ti" },              -- Troll
  [95] = SKYBORNE, [96] = SKYBORNE,
}

local function gold(copper, up) -- up: round a shortfall up, so "0g more" never shows
  return (up and math.ceil or math.floor)(copper / 10000) .. "g"
end

local function race()
  return RACES[select(3, UnitRace("player"))]
end

-- Copper the tier costs this character: 0 when a class quest gives it, 10% off at Honored with the home faction.
function ns.RidingPrice(tier)
  local _, classFile = UnitClass("player")
  if tier.level == 40 and FREE_CLASS[classFile] then return 0 end
  local r = race()
  local data = r and r.faction and C_Reputation and C_Reputation.GetFactionDataByID(r.faction)
  if data and (data.reaction or 0) >= HONORED then return tier.price * 0.9, true end
  return tier.price, false
end

-- The spell IDs are the TBC ones (not confirmed in Forever); the riding skill line answers when they do not.
local function known(tier)
  if IsPlayerSpell and IsPlayerSpell(tier.spell) then return true end
  local info = C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID and C_SkillInfo.GetSkillLineInfoByID(SKILL_RIDING)
  return info ~= nil and (tonumber(info.maxRank) or 0) >= tier.maxRank
end

-- The riding tier this character saves for now, and its price; nil outside the saving windows, when it is
-- learned already, or when a class quest gives it.
local function goal()
  local level = UnitLevel("player") or 1
  local tier
  for _, t in ipairs(TIERS) do
    if level >= t.from and level <= t.upto then tier = t end
  end
  if not tier then return nil end
  local price, honored = ns.RidingPrice(tier)
  if price == 0 or known(tier) then return nil end
  return tier, price, honored, level
end

-- Copper kept back for riding: what the vendor automations must not spend.
function ns.RidingReserve()
  local _, price = goal()
  return price or 0
end

-- Class training: what the trainer asked last time at this level (recorded while its window was open), else
-- our own rough estimate (about 206g in all from 1 to 60, growing with the level squared).
local function charKey()
  return (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "?")
end
function ns.TrainerCost()
  local level = UnitLevel("player") or 1
  local seen = ns.db and ns.db.trainerCost[charKey()]
  if type(seen) == "table" and seen.level == level and type(seen.cost) == "number" then return seen.cost, false end
  return math.floor(54 * level * level / 100 + 0.5) * 100, true -- shortcut: own curve, not trainer data
end

local recorder = CreateFrame("Frame")
recorder:RegisterEvent("TRAINER_SHOW")
recorder:RegisterEvent("TRAINER_UPDATE")
recorder:SetScript("OnEvent", function()
  if not (ns.db and GetNumTrainerServices and GetTrainerServiceInfo and GetTrainerServiceCost) then return end
  if IsTradeskillTrainer and IsTradeskillTrainer() then return end -- professions are not class training
  -- Weapon masters, riding and pet trainers open the same window: only one that lists our class's spells counts.
  -- shortcut: matched by English spell name, so other client languages keep the estimate; match by spell ID later.
  local mine = {}
  for _, row in ipairs((ns.TRAINER_SPELLS or {})[select(3, UnitClass("player"))] or {}) do mine[row[3]] = true end
  local cost, classTrainer = 0, false
  for i = 1, GetNumTrainerServices() or 0 do
    local name, _, category = GetTrainerServiceInfo(i)
    if mine[name] then classTrainer = true end
    if category == "available" then cost = cost + (tonumber((GetTrainerServiceCost(i))) or 0) end
  end
  if not classTrainer then return end
  ns.db.trainerCost[charKey()] = { level = UnitLevel("player") or 1, cost = cost }
  ns.RequestUpdate()
end)

local function trainerLine()
  local cost, estimate = ns.TrainerCost()
  if cost <= 0 then return "" end
  return " " .. string.format(estimate and L["Next class training: about %s (estimate)."]
    or L["Next class training: %s."], gold(cost, true))
end

ns.RegisterRule({
  id = "fund",
  events = { "PLAYER_MONEY", "PLAYER_LEVEL_UP", "UPDATE_FACTION", "PLAYER_ENTERING_WORLD", "SKILL_LINES_CHANGED" },
  evaluate = function()
    local tier, price, honored, level = goal()
    if not tier then return {} end
    local money = GetMoney() or 0
    local why = (tier.level == 40 and L["Your first mount comes with it."] or L["Mounted speed goes to 100%."])
      .. " " .. (honored and L["You get the Honored price."] or L["Honored with your home faction takes 10% off."])
    if level < tier.level then
      why = (tier.level == 40 and (why .. " " .. L["Dual spec (50g at level 40) can wait."]) or why) .. trainerLine()
      if money >= price then -- saved already: say what is free to spend, low in the list
        return { { id = "fund", kind = "fund", priority = 20, why = why,
          what = string.format(L["Riding gold is ready: keep %s for %s at level %d, %s is free to spend."],
            gold(price, true), tier.name, tier.level, gold(money - price)) } }
      end
      return { { id = "fund", kind = "fund", priority = level >= tier.level - 2 and 60 or 30, why = why,
        what = string.format(L["Save for %s at level %d: %s of %s."], tier.name, tier.level, gold(money),
          gold(price)) } }
    end
    if money < price then
      return { { id = "fund", kind = "fund", priority = 70, why = why,
        what = string.format(L["%s costs %s: you need %s more."], tier.name, gold(price), gold(price - money, true)) } }
    end
    local r = race()
    return { { id = "fund", kind = "fund", priority = 85, why = why,
      what = string.format(L["Train %s at your race's riding trainer: you have the %s."], tier.name, gold(price)),
      waypoint = r and { map = r.map, x = r.x, y = r.y,
        title = string.format("Wowish: %s (%s)", r.name, L["riding trainer"]) } } }
  end,
})
