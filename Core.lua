-- Wowish core: saved settings, rule registry, throttled out-of-combat evaluation.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
-- Passive by design: rules only read client state; nothing here runs in combat.

local addonName, ns = ...

ns.THROTTLE = 1      -- seconds between a burst of events and the next evaluation
ns.TOP = 5           -- suggestions shown
ns.rules, ns.ruleById = {}, {}
ns.suggestions, ns.errors = {}, {}
ns.callbacks = {}

local DEFAULTS = {
  version = 1,
  welcomeSeen = false,
  locale = false,    -- false: follow the client locale
  loginLine = true,
  scale = 1,
  minimapButton = true,
  minimapAngle = 200, -- degrees around the minimap
  nextBar = false,   -- one-line "next tip" bar under the minimap
  rules = {},        -- [ruleId] = false disables a rule
}

-- Fill missing keys from defaults; keep the player's values; recurse into tables.
local function applyDefaults(db, defaults)
  for k, v in pairs(defaults) do
    if type(v) == "table" then
      if type(db[k]) ~= "table" then db[k] = {} end
      applyDefaults(db[k], v)
    elseif db[k] == nil then
      db[k] = v
    end
  end
  return db
end
ns.applyDefaults = applyDefaults

local frame = CreateFrame("Frame")
ns.frame = frame

-- rule = { id = "turnin", events = { "QUEST_LOG_UPDATE" }, maxInTop = 2, evaluate = function() return { ... } end }
-- evaluate returns a list of { id = stable string, priority = 0..100, ... } and must only read state.
function ns.RegisterRule(rule)
  assert(type(rule) == "table" and type(rule.id) == "string" and type(rule.evaluate) == "function",
    "RegisterRule needs id and evaluate")
  assert(not ns.ruleById[rule.id], "duplicate rule " .. rule.id)
  ns.rules[#ns.rules + 1] = rule
  ns.ruleById[rule.id] = rule
  for _, ev in ipairs(rule.events or {}) do frame:RegisterEvent(ev) end
end

function ns.OnSuggestionsUpdated(cb)
  ns.callbacks[#ns.callbacks + 1] = cb
end

local function inCombat()
  return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) or false
end
ns.inCombat = inCombat

local function byPriority(a, b)
  if a.priority ~= b.priority then return a.priority > b.priority end
  return a.id < b.id
end

-- Hand an error to the client's error handler (BugSack/BugGrabber, or the default script error frame)
-- without letting it stop the caller: one broken rule or listener must not hide the others.
local function report(err)
  local handler = geterrorhandler and geterrorhandler()
  if handler then pcall(handler, err) end
  return err
end
ns.report = report

function ns.Evaluate()
  local all = {}
  ns.errors = {}
  for _, rule in ipairs(ns.rules) do
    if not (ns.db and ns.db.rules[rule.id] == false) then
      local ok, res = xpcall(rule.evaluate, report)
      if not ok then
        ns.errors[rule.id] = tostring(res)
      elseif type(res) == "table" then
        for _, s in ipairs(res) do
          s.rule = rule.id
          all[#all + 1] = s
        end
      end
    end
  end
  table.sort(all, byPriority)
  local top, perRule = {}, {}
  for _, s in ipairs(all) do
    local cap = ns.ruleById[s.rule].maxInTop
    local n = perRule[s.rule] or 0
    if not cap or n < cap then
      perRule[s.rule] = n + 1
      top[#top + 1] = s
      if #top == ns.TOP then break end
    end
  end
  ns.suggestions = top
  ns.updatedAt = time()
  ns.NotifyChanged()
  return top
end

-- Tell every listener (window, minimap button, next-tip bar, login line) the list changed; a failing one is
-- reported and does not stop the others. Also used when the player hides a tip.
function ns.NotifyChanged()
  local top = ns.suggestions
  for _, cb in ipairs(ns.callbacks) do xpcall(function() cb(top) end, report) end
end

local pending = false
ns.dirty = false

-- Coalesce bursts of events into one evaluation; defer to the end of combat.
function ns.RequestUpdate()
  if pending then return end
  pending = true
  C_Timer.After(ns.THROTTLE, function()
    pending = false
    if inCombat() then
      ns.dirty = true
      return
    end
    ns.dirty = false
    ns.Evaluate()
  end)
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == addonName then
      WowishDB = applyDefaults(type(WowishDB) == "table" and WowishDB or {}, DEFAULTS)
      ns.db = WowishDB
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if ns.dirty then ns.RequestUpdate() end
  else -- PLAYER_LOGIN and every event a rule registered
    ns.RequestUpdate()
  end
end)
