-- Wowish rule: save gold for Apprentice Riding at level 40, then train it.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
-- Forever facts (Icy Veins 2026-11-08, games.gg 2026-11-16): Apprentice Riding is 100g at level 40 and includes the
-- first racial mount; Honored with your home faction takes 10% off. Paladins and warlocks get riding from a level 40
-- class quest. Skyborne get no reputation discount (Wowhead 2026-11-13). Spell costs are not known here (the client
-- tells them only while a trainer window is open), so this rule never tells you to skip training.
local _, ns = ...
local L = ns.L

local RIDING_LEVEL, PRICE, HONORED_PRICE, HONORED = 40, 1000000, 900000, 6 -- copper; reaction 6 = Honored
local RIDING_SPELL = 33388 -- Apprentice Riding; shortcut: ID not confirmed in Forever, so the card stops after 41
local FIRST_LEVEL, LAST_LEVEL = 30, 41
local FREE_CLASS = { PALADIN = true, WARLOCK = true }
-- Home faction per race ID; Skyborne (95, 96) are left out on purpose: no discount for them.
local HOME = { [1] = 72, [2] = 76, [3] = 47, [4] = 69, [5] = 68, [6] = 81, [7] = 54, [8] = 530 }

local function gold(copper, up) -- up: round a shortfall up, so "0g more" never shows
  return (up and math.ceil or math.floor)(copper / 10000) .. "g"
end

-- Copper needed for riding: 0 for classes that get it from a quest, 90g at Honored with the home faction.
function ns.RidingPrice()
  local _, classFile = UnitClass("player")
  if FREE_CLASS[classFile] then return 0 end
  local faction = HOME[select(3, UnitRace("player"))]
  local data = faction and C_Reputation and C_Reputation.GetFactionDataByID(faction)
  if data and (data.reaction or 0) >= HONORED then return HONORED_PRICE, true end
  return PRICE, false
end

local function ridingKnown()
  return IsPlayerSpell and IsPlayerSpell(RIDING_SPELL) or false
end

ns.RegisterRule({
  id = "fund", events = { "PLAYER_MONEY", "PLAYER_LEVEL_UP", "UPDATE_FACTION", "PLAYER_ENTERING_WORLD" },
  evaluate = function()
    local level = UnitLevel("player") or 1
    if level < FIRST_LEVEL or level > LAST_LEVEL then return {} end
    local price, honored = ns.RidingPrice()
    if price == 0 or ridingKnown() then return {} end
    local money = GetMoney() or 0
    local why = honored and L["Your first mount comes with it. You get the Honored price."]
      or L["Your first mount comes with it. Honored with your home faction takes 10% off."]
    if level >= RIDING_LEVEL then
      if money >= price then
        return { { id = "fund", kind = "fund", priority = 85, why = why,
          what = string.format(L["Train Apprentice Riding at your race's riding trainer: you have the %s."],
            gold(price)) } }
      end
      return { { id = "fund", kind = "fund", priority = 70, why = why,
        what = string.format(L["Riding costs %s: you need %s more."], gold(price), gold(price - money, true)) } }
    end
    if money >= price then return {} end -- saved already: nothing to do until 40
    return { { id = "fund", kind = "fund", priority = level >= RIDING_LEVEL - 2 and 60 or 30,
      why = why .. " " .. L["Dual spec (50g at level 40) can wait."],
      what = string.format(L["Save for riding at level 40: %s of %s."], gold(money), gold(price)) } }
  end,
})
