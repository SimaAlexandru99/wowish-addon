-- Wowish rule: a commission (repeatable turn-in) in your quest log whose materials are all in your bags.
-- Reads CommissionsForever's public API (CommissionsForever.API, GPL-3.0, cjber) when it is installed; its button
-- asks CommissionsForever to route to every hand-in through ShortestPathForever. Nothing without it.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local L = ns.L

local function api()
  local cf = rawget(_G, "CommissionsForever")
  local a = type(cf) == "table" and cf.API
  return type(a) == "table" and type(a.Materials) == "function" and a or nil
end
ns.CommissionsAPI = api

-- Commission quests whose every material row is met. Rows without a quest are commissions not taken yet,
-- rows without a need are unknown: neither counts as ready.
function ns.ReadyCommissions()
  local a = api()
  if not a then return {} end
  local ok, rows = pcall(a.Materials)
  if not ok or type(rows) ~= "table" then return {} end -- nil, "loading" until its first refresh
  local met = {}
  for _, row in ipairs(rows) do
    local q = row.questID
    if q then
      local good = type(row.need) == "number" and (tonumber(row.have) or 0) >= row.need
      met[q] = (met[q] ~= false) and good
    end
  end
  local ready = {}
  for q, good in pairs(met) do
    if good then ready[#ready + 1] = q end
  end
  table.sort(ready)
  return ready
end

-- Its changes arrive on the frame after its own refresh, so the card never reads a stale list.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", function()
  local a = api()
  if a and type(a.Subscribe) == "function" then
    pcall(a.Subscribe, function() ns.RequestUpdate() end)
  end
end)

ns.RegisterRule({
  id = "commissions",
  events = { "BAG_UPDATE_DELAYED", "QUEST_LOG_UPDATE" },
  evaluate = function()
    local n = #ns.ReadyCommissions()
    if n == 0 then return {} end
    return { {
      id = "commissions", kind = "commissions", priority = 65,
      what = string.format(L["Commissions ready to hand in: %s."], ns.Count(n, "commission")),
      why = L["The materials are in your bags. Commissions Forever knows where to hand them in."],
      action = { open = "commissions" },
    } }
  end,
})
