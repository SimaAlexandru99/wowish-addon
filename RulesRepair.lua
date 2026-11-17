-- Wowish rule: repair gear before it breaks, with the nearest repair NPC as destination.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local L = ns.L

local FIRST, LAST = 1, 19 -- equipped inventory slots

-- Lowest durability of the equipped items, 0..1, or nil when nothing can break.
function ns.LowestDurability()
  local lowest
  for slot = FIRST, LAST do
    local cur, max = GetInventoryItemDurability(slot)
    if cur and max and max > 0 then
      local r = cur / max
      if not lowest or r < lowest then lowest = r end
    end
  end
  return lowest
end

ns.RegisterRule({
  id = "repair", events = { "UPDATE_INVENTORY_DURABILITY", "PLAYER_ENTERING_WORLD" },
  evaluate = function()
    local r = ns.LowestDurability()
    if not r or r >= 0.2 then return {} end
    local npc = ns.NearestService and ns.NearestService("repair")
    return { {
      id = "repair", kind = "repair", priority = r < 0.05 and 90 or 75,
      what = string.format(L["Repair your gear: one item is at %d%% durability."], math.floor(r * 100)),
      why = L["Broken items stop giving their stats. Any armor or weapon vendor can repair them."],
      waypoint = npc and { map = npc.place.map, x = npc.place.x, y = npc.place.y,
        title = string.format("Wowish: %s (%s)", npc.place.name or L["a vendor you visited"],
          npc.subName or L["repairs"]) },
    } }
  end,
})
