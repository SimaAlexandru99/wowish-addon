-- Wowish Hunter module: vendor ammo that matches the equipped ranged weapon and your level.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
-- Our own table of standard vendor ammo (item id, required level), checked against the installed
-- QuestieDB item data on 2026-11-16. Vendor locations come from QuestieDB at run time, if present.
local _, ns = ...
local L = ns.L

local AMMO = {
  arrow = { { id = 2512, level = 1, name = "Rough Arrow" }, { id = 2515, level = 10, name = "Sharp Arrow" },
    { id = 3030, level = 25, name = "Razor Arrow" }, { id = 11285, level = 40, name = "Jagged Arrow" } },
  bullet = { { id = 2516, level = 1, name = "Light Shot" }, { id = 2519, level = 10, name = "Heavy Shot" },
    { id = 3033, level = 25, name = "Solid Shot" }, { id = 11284, level = 40, name = "Accurate Slugs" } },
}

local function weaponAmmo()
  local sub = Enum and Enum.ItemWeaponSubclass or {}
  local weapon = Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2
  return weapon, {
    [sub.Bows or 2] = "arrow", [sub.Crossbow or 18] = "arrow", [sub.Guns or 3] = "bullet",
  }
end

-- Projectile item subclasses (same values HunterSuite uses on Forever; not in the API docs).
local PROJECTILE, PROJECTILE_SUB = 6, { arrow = 2, bullet = 3 }

local function itemName(entry)
  return (C_Item.GetItemNameByID and C_Item.GetItemNameByID(entry.id)) or entry.name
end

-- Highest vendor-ammo tier of this kind in the bags (0 = none), and whether the bags also hold other ammo
-- of the same kind (crafted, dropped, quest). Quivers and ammo pouches count here.
local function ownedTier(tiers, kind)
  local tierOf, best, other = {}, 0, false
  for i, t in ipairs(tiers) do tierOf[t.id] = i end
  for bag = 0, 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local tier = info and tierOf[info.itemID]
      if tier then
        if tier > best then best = tier end
      elseif info then
        local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(info.itemID)
        if classID == PROJECTILE and subClassID == PROJECTILE_SUB[kind] then other = true end
      end
    end
  end
  return best, other
end

local function nearestVendor(itemID)
  local list = ns.ItemVendors(itemID, UnitFactionGroup("player") or "Horde")
  local pmap, px, py = ns.PlayerPosition()
  local best, bestDist
  for _, p in ipairs(list) do
    if p.map == pmap then
      local d = px and ((p.x - px) ^ 2 + (p.y - py) ^ 2) or 0
      if not bestDist or d < bestDist then best, bestDist = p, d end
    end
  end
  return best
end

-- The ammo a Hunter's ranged weapon takes: kind ("arrow" | "bullet"), our vendor tiers of it, and the highest
-- tier usable at this level (0 = none). nil for other classes, thrown weapons and wands.
function ns.HunterAmmo()
  local _, class = UnitClass("player")
  if class ~= "HUNTER" then return nil end
  local weapon = GetInventoryItemID("player", INVSLOT_RANGED or 18)
  if not weapon then return nil end
  local weaponClass, ammoFor = weaponAmmo()
  local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(weapon)
  local kind = classID == weaponClass and ammoFor[subClassID]
  if not kind then return nil end
  local tiers, lvl, want = AMMO[kind], UnitLevel("player"), 0
  for i, t in ipairs(tiers) do
    if t.level <= lvl then want = i end
  end
  return kind, tiers, want
end

ns.RegisterRule({
  id = "ammo", events = { "PLAYER_LEVEL_UP", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }, -- the vendor waypoint is on the current map
  evaluate = function()
    local kind, tiers, want = ns.HunterAmmo()
    if not kind then return {} end -- not a Hunter, or thrown, wand or no ranged weapon: no ammo
    local have, other = ownedTier(tiers, kind)
    -- shortcut: ammo outside our vendor table counts as good enough (its level is not checked); fine for a hint
    if want == 0 or have >= want or other then return {} end

    local target = tiers[want]
    local s = { id = "ammo:" .. target.id, kind = "ammo",
      why = L["Ammo adds damage to every shot; vendor ammo of your level is cheap and much stronger."] }
    if have == 0 then
      s.priority = 88
      s.what = string.format(L["No %s in your bags: buy %s."], kind == "arrow" and L["arrows"] or L["bullets"],
        itemName(target))
    else
      s.priority = 85
      s.what = string.format(L["Upgrade your ammo: buy %s (level %d) instead of %s."], itemName(target),
        target.level, itemName(tiers[have]))
    end
    local vendor = nearestVendor(target.id)
    if vendor then
      s.waypoint = { map = vendor.map, x = vendor.x, y = vendor.y,
        title = string.format("Wowish: %s (%s)", itemName(target), vendor.name or "?") }
      s.why = s.why .. " " .. string.format(L["%s sells it on your current map."], vendor.name or "?")
    end
    return { s }
  end,
})
