-- Wowish vendor helpers, each one opt-in (all off by default): sell grey items, repair, restock Hunter ammo.
-- They run only while a merchant window the player opened is shown, never in combat; holding Shift when the
-- window opens skips them. One chat line says what was done.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
-- Selling slot by slot in small ticks with a re-check of every slot, and buying in whole merchant stacks, follow
-- Polestar (addon/Polestar/QoL/Vendor.lua, Buy.lua; https://github.com/fitzforge/polestar, GPL-3.0). See
-- THIRD_PARTY.md.
local _, ns = ...
local L = ns.L

local PER_TICK, INTERVAL = 6, 0.2 -- the server throttles bursts of sales
local POOR = 0                    -- Enum.ItemQuality.Poor: grey
local OTHERS = { "OneForAll", "Polestar" } -- they sell junk and repair already

-- A loaded addon that already sells junk and repairs: Wowish leaves both to it.
function ns.VendorOwner()
  local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
  if not loaded then return nil end
  for _, name in ipairs(OTHERS) do
    if loaded(name) then return name end
  end
  return nil
end

function ns.Money(copper)
  copper = math.floor(copper or 0)
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  if g > 0 then return s > 0 and string.format("%dg %ds", g, s) or (g .. "g") end
  if s > 0 then return c > 0 and string.format("%ds %dc", s, c) or (s .. "s") end
  return c .. "c"
end

local open, queue, done, owner = false, {}, nil, nil

-- Still at the merchant: a sale through UseContainerItem anywhere else would use or equip the item.
local function atMerchant()
  return open and not ns.inCombat() and not (MerchantFrame and not MerchantFrame:IsShown())
end

-- Item ID and the copper it sells for, if the slot holds a grey item worth money; nil otherwise.
local function junkAt(bag, slot)
  local info = C_Container.GetContainerItemInfo(bag, slot)
  if not info or info.isLocked or info.hasNoValue or info.quality ~= POOR or not info.itemID then return nil end
  local price = select(11, C_Item.GetItemInfo(info.itemID))
  if not price or price <= 0 then return nil end
  return info.itemID, price * (info.stackCount or 1)
end

local function repair()
  if owner or not (ns.db.auto.repair and CanMerchantRepair and CanMerchantRepair()) then return end
  local cost, can = GetRepairAllCost()
  if not can or not cost or cost <= 0 then return end
  if (GetMoney() or 0) < cost then
    done[#done + 1] = string.format(L["not enough gold to repair (%s)"], ns.Money(cost))
    return
  end
  RepairAllItems()
  done[#done + 1] = string.format(L["repaired (%s)"], ns.Money(cost))
end

local function restock()
  if not ns.db.auto.ammo or not ns.HunterAmmo then return end
  local kind, tiers, want = ns.HunterAmmo()
  if not kind or want == 0 then return end
  local tierOf, have = {}, 0
  for i, t in ipairs(tiers) do
    tierOf[t.id] = i
    have = have + (C_Item.GetItemCount(t.id) or 0)
  end
  local best, bestTier -- the merchant's best ammo of this kind for your level
  for i = 1, GetMerchantNumItems() or 0 do
    local tier = tierOf[GetMerchantItemID(i)]
    if tier and tier <= want and (not bestTier or tier > bestTier) then best, bestTier = i, tier end
  end
  if not best then return end
  local item = tiers[bestTier]
  local info = C_MerchantFrame.GetItemInfo(best)
  local price, per = info and info.price or 0, math.max(1, info and info.stackCount or 1)
  if price <= 0 or (info and info.hasExtendedCost) then return end
  local stack = select(8, C_Item.GetItemInfo(item.id)) or 200
  local need = ns.db.auto.ammoStacks * stack - have
  if need <= 0 then return end
  local purchases = math.ceil(need / per)
  local reserve = ns.RidingReserve and ns.RidingReserve() or 0
  local affordable = math.floor(math.max(0, (GetMoney() or 0) - reserve) / price)
  if affordable < purchases then
    purchases = affordable
    if purchases == 0 then
      done[#done + 1] = reserve > 0
        and string.format(L["ammo skipped: it would cut into your riding savings (%s)"], ns.Money(reserve))
        or L["ammo skipped: not enough gold"]
      return
    end
  end
  local items = purchases * per
  local max = GetMerchantItemMaxStack(best) or per
  local chunk = max >= per and (max - max % per) or per -- whole merchant stacks per purchase
  local left = items
  while left > 0 do
    local n = math.min(left, chunk)
    BuyMerchantItem(best, n)
    left = left - n
  end
  local name = info and info.name or item.name
  done[#done + 1] = string.format(L["bought %d %s (%s)"], items, name, ns.Money(purchases * price))
end

local function finish()
  if not atMerchant() then return end
  repair()
  restock()
  if #done > 0 then ns.Say(table.concat(done, "; ") .. ".") end
end

local function step()
  if not atMerchant() then return end
  local n = 0
  while #queue > 0 and n < PER_TICK do
    local s = table.remove(queue, 1)
    local id, value = junkAt(s.bag, s.slot)
    if id == s.id then -- same grey item still there: never sell what moved into the slot since
      C_Container.UseContainerItem(s.bag, s.slot)
      done.sold, done.earned = done.sold + 1, done.earned + value
      n = n + 1
    end
  end
  if #queue > 0 then return C_Timer.After(INTERVAL, step) end
  if done.sold > 0 then
    table.insert(done, 1, string.format(L["sold %s (%s)"], ns.Count(done.sold, "grey item"), ns.Money(done.earned)))
  end
  finish()
end

local function onShow()
  open, queue, done, owner = true, {}, { sold = 0, earned = 0 }, ns.VendorOwner()
  if ns.inCombat() or (IsShiftKeyDown and IsShiftKeyDown()) then return end
  if ns.db.auto.sell and not owner then
    for bag = 0, 4 do
      for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
        local id = junkAt(bag, slot)
        if id then queue[#queue + 1] = { bag = bag, slot = slot, id = id } end
      end
    end
  end
  step()
end

local events = CreateFrame("Frame")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MERCHANT_CLOSED")
events:SetScript("OnEvent", function(_, event)
  if event == "MERCHANT_CLOSED" then
    open, queue = false, {}
    return
  end
  xpcall(onShow, ns.report)
end)
