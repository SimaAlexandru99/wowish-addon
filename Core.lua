-- Wowish core: saved settings, rule registry, throttled out-of-combat evaluation.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
-- Rules only read client state and nothing runs in combat. The one exception that acts is Vendor.lua: opt-in
-- helpers that run only inside a merchant window the player opened.

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
  levelLine = true,
  scale = 1,
  minimapButton = true,
  minimapAngle = 200, -- degrees around the minimap
  nextBar = false,   -- one-line "next tip" bar under the minimap
  rewardHint = true, -- mark the recommended quest reward (QuestReward.lua)
  rules = {},        -- [ruleId] = false disables a rule
  auto = { sell = false, repair = false, ammo = false, ammoStacks = 3 }, -- vendor helpers, opt-in
  places = { repair = {}, trainer = {} }, -- learned NPC places: key -> { map, x, y, name, faction, class }
  hearth = {},       -- ["Name-Realm"] = { map, x, y, name }: where the inn is (Hearth.lua)
  hearthHint = true,
  trainerCost = {},  -- ["Name-Realm"] = { level, cost }: class training seen at the trainer
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

-- Values a hand-edited or old WowishDB may hold in the wrong shape: reset them instead of failing later
-- (a string scale or a short position would stop the window from opening).
local function sanitize(db)
  if type(db.scale) ~= "number" or db.scale < 0.7 or db.scale > 1.5 then db.scale = 1 end
  if type(db.minimapAngle) ~= "number" then db.minimapAngle = 200 end
  local stacks = db.auto.ammoStacks
  if type(stacks) ~= "number" or stacks < 1 or stacks > 10 then db.auto.ammoStacks = 3 end
  local p = db.pos
  if p ~= nil and not (type(p) == "table" and type(p[1]) == "string" and type(p[2]) == "string"
      and type(p[3]) == "number" and type(p[4]) == "number") then
    db.pos = nil
  end
  return db
end
ns.sanitize = sanitize

-- "1g 5s", "40s", "7c": copper as the player reads it.
function ns.Money(copper)
  copper = math.floor(copper or 0)
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  if g > 0 then return s > 0 and string.format("%dg %ds", g, s) or (g .. "g") end
  if s > 0 then return c > 0 and string.format("%ds %dc", s, c) or (s .. "s") end
  return c .. "c"
end

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
ns.recentErrors = {} -- the last three, for /wowish report
local function report(err)
  table.insert(ns.recentErrors, 1, tostring(err):sub(1, 160))
  ns.recentErrors[4] = nil
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
          if s.waypoint and ns.HearthHint then -- outside the rule's xpcall: must not stop the other tips
            local fine, hint = xpcall(function() return ns.HearthHint(s.waypoint) end, report)
            if fine and hint then s.why = (s.why or "") .. " " .. hint end
          end
          all[#all + 1] = s
        end
      end
    end
  end
  table.sort(all, byPriority)
  -- A hide lasts one episode: once the tip is gone or its state changed, the same advice may come back later.
  local current = {}
  for _, s in ipairs(all) do current[s.id] = s.state or s.what end
  for id, key in pairs(ns.dismissed) do
    if current[id] ~= key then ns.dismissed[id] = nil end
  end
  ns.suggestions = all -- every tip; ns.Visible() picks what is shown
  ns.updatedAt = time()
  ns.evals = (ns.evals or 0) + 1 -- lets a listener tell a fresh evaluation from a hidden tip's notification
  ns.NotifyChanged()
  return ns.Visible()
end

local SNOOZE = 1800 -- seconds
ns.dismissed = {} -- [suggestion id] = state (or text) when hidden; the tip returns once that changes
ns.snoozed = {} -- [suggestion id] = { state (or text), time it comes back }

-- A tip's `state` names its situation ("almost" or "full"), so a counter in its text does not undo a hide.
local function hidden(s)
  local key = s.state or s.what
  if key ~= nil and ns.dismissed[s.id] == key then return true end
  local z = ns.snoozed[s.id]
  -- shortcut: a snoozed tip returns at the next refresh after its time, not at the exact second
  return z ~= nil and z[1] == key and z[2] > time()
end

-- The tips shown: by priority, without hidden or snoozed ones, at most maxInTop per rule and ns.TOP in all.
function ns.Visible()
  local out, perRule = {}, {}
  for _, s in ipairs(ns.suggestions) do
    if not hidden(s) then
      local rule = s.rule and ns.ruleById[s.rule] -- tests set tips without a rule
      local cap, n = rule and rule.maxInTop, perRule[s.rule] or 0
      if not cap or n < cap then
        if cap then perRule[s.rule] = n + 1 end
        out[#out + 1] = s
        if #out == ns.TOP then break end
      end
    end
  end
  return out
end

function ns.HiddenCount()
  local n = 0
  for _, s in ipairs(ns.suggestions) do
    if hidden(s) then n = n + 1 end
  end
  return n
end

function ns.Hide(s)
  ns.dismissed[s.id] = s.state or s.what
  ns.NotifyChanged()
end

function ns.Snooze(s)
  ns.snoozed[s.id] = { s.state or s.what, time() + SNOOZE }
  ns.NotifyChanged()
end

function ns.ShowHidden()
  for k in pairs(ns.dismissed) do ns.dismissed[k] = nil end
  for k in pairs(ns.snoozed) do ns.snoozed[k] = nil end
  ns.NotifyChanged()
end

-- Tell every listener (window, minimap button, next-tip bar, login line) the list changed; a failing one is
-- reported and does not stop the others. Also used when the player hides a tip.
function ns.NotifyChanged()
  local top = ns.Visible()
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
      WowishDB = sanitize(applyDefaults(type(WowishDB) == "table" and WowishDB or {}, DEFAULTS))
      ns.db = WowishDB
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if ns.dirty then ns.RequestUpdate() end
  else -- PLAYER_LOGIN and every event a rule registered
    ns.RequestUpdate()
  end
end)
