-- Wowish rule: new spells or ranks are waiting at your class trainer.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
-- Data: TrainerData.lua (from OneForAll by Smoergi). The known-rank and race logic follows OneForAll's
-- UI/TrainerSpells.lua: the client only reports the highest rank as known, so a known higher rank covers
-- the lower ones; race masks use PlayableRaceBit (race ID - 1, Skyborne races 32/33).
local _, ns = ...
local L = ns.L

local RACE_BIT = { [95] = 32, [96] = 33 } -- Skyborne High Order, Skyborne Windshaper

local function isKnown(spellID)
  local check = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsSpellKnown
  local ok, yes = pcall(check or function() end, spellID)
  if not (ok and yes) and IsPlayerSpell then ok, yes = pcall(IsPlayerSpell, spellID) end
  return ok and yes or false
end

local function raceAllowed(mask, raceID)
  if mask == 0 or not raceID then return true end
  local bit = RACE_BIT[raceID] or (raceID - 1)
  return math.floor(mask / 2 ^ bit) % 2 == 1
end

local function spellName(s)
  local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(s[2]) or s[3]
  return s[4] > 1 and (name .. " " .. s[4]) or name
end

-- Spells of the player's class the trainer would teach right now: level reached, right race, not known,
-- not taught by a quest, and for a talent chain only once its first rank is known.
function ns.TrainerSpellsDue()
  local _, _, classID = UnitClass("player")
  local list = ns.TRAINER_SPELLS and ns.TRAINER_SPELLS[classID]
  if not list then return {} end
  local level, raceID = UnitLevel("player") or 1, select(3, UnitRace("player"))
  local known = {} -- [name] = highest known rank
  for _, s in ipairs(list) do
    local name, rank = s[3], s[4]
    if rank > (known[name] or -1) and isKnown(s[2]) then known[name] = rank end
  end
  local due = {}
  for _, s in ipairs(list) do
    local lvl, name, rank, race, talent, quest = s[1], s[3], s[4], s[5], s[6], s[8]
    local have = known[name]
    if lvl <= level and not quest and raceAllowed(race, raceID)
        and not (have and have >= rank) and (not talent or have) then
      due[#due + 1] = s
    end
  end
  return due
end

-- A trainer of the player's class: QuestieDB's subname, e.g. "Hunter Trainer" (not "Pet Trainer").
local function myClassTrainer(entry)
  local sub = (entry.subName or ""):lower()
  local name, file = UnitClass("player")
  if entry.class and entry.class == file then return true end
  for _, word in ipairs({ name or "", file and (file:sub(1, 1) .. file:sub(2):lower()) or "" }) do
    if word ~= "" and sub:find(word:lower(), 1, true) then return true end
  end
  return false
end

ns.RegisterRule({
  id = "trainer", events = { "PLAYER_LEVEL_UP", "SPELLS_CHANGED",
    "ZONE_CHANGED", "PLAYER_UPDATE_RESTING" }, -- re-rank when the player walks into a town
  evaluate = function()
    local due = ns.TrainerSpellsDue()
    if #due == 0 then return {} end
    local names, all = {}, {}
    for i, s in ipairs(due) do all[i] = spellName(s) end
    for i = 1, math.min(#due, 4) do names[i] = all[i] end
    local trainer, yards
    if ns.NearestService then trainer, yards = ns.NearestService("trainer", myClassTrainer) end
    local waypoint = trainer and { map = trainer.place.map, x = trainer.place.x, y = trainer.place.y,
      title = string.format("Wowish: %s (%s)", trainer.place.name or L["a trainer you visited"],
        trainer.subName or UnitClass("player") or "?") } -- a visited place has no subname
    local tip = {
      id = "trainer", kind = "trainer", priority = 80, details = all, hint = "spellbook", waypoint = waypoint,
      what = string.format(L["Visit your class trainer: %s (%s)."], ns.Count(#due, "new spell"),
        table.concat(names, ", ") .. (#due > 4 and ", ..." or "")),
      why = L["New ranks are stronger versions of spells you already use, and trainers teach them for a small fee."],
    }
    return { ns.NearBoost and trainer and ns.NearBoost(tip, yards) or tip }
  end,
})
