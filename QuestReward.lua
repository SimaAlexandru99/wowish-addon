-- Wowish quest reward hint: when a quest offers two or more rewards to choose from, mark the one we recommend
-- and say why in chat. Never picks it: the player still clicks. Recommendation, kept simple on purpose: an armor
-- piece of your class's armor type (or a cloak, ring, neck, trinket) with a higher item level than what you wear
-- in that slot; otherwise the reward that sells for the most. Weapons are not compared.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local L = ns.L

local ARMOR, MISC = 4, 0 -- item class Armor; armor subclass Miscellaneous (rings, necks, trinkets)
local CLOTH, LEATHER, MAIL, PLATE = 1, 2, 3, 4
local SLOTS = { INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 },
  INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
  INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 } }
local RETRIES, RETRY_DELAY = 3, 0.3 -- item data is often not cached when the window opens

-- The armor type this class should wear now (mail and plate from level 40).
function ns.ArmorType()
  local _, class = UnitClass("player")
  local at40 = (UnitLevel("player") or 1) >= 40
  if class == "WARRIOR" or class == "PALADIN" then return at40 and PLATE or MAIL end
  if class == "HUNTER" or class == "SHAMAN" then return at40 and MAIL or LEATHER end
  if class == "ROGUE" or class == "DRUID" then return LEATHER end
  return CLOTH
end

local function ilvl(link)
  return link and C_Item.GetDetailedItemLevelInfo(link) or nil
end

-- Item level gained over what you wear in its slot (the lower one for rings and trinkets), or nil when the
-- reward is not an armor piece we compare.
local function gain(link)
  local _, _, _, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(link)
  local slots = SLOTS[equipLoc]
  if classID ~= ARMOR or not slots then return nil end
  if subClassID ~= MISC and equipLoc ~= "INVTYPE_CLOAK" and subClassID ~= ns.ArmorType() then return nil end
  local worn
  for _, slot in ipairs(slots) do
    local level = ilvl(GetInventoryItemLink("player", slot)) or 0 -- empty slot: anything is better
    if not worn or level < worn then worn = level end
  end
  local minLevel = select(5, C_Item.GetItemInfo(link))
  if minLevel and minLevel > (UnitLevel("player") or 1) then return nil end -- cannot wear it yet
  local level = ilvl(link)
  return level and level - worn, level, worn
end

-- choice index, reason text; nil while item data is still loading (or fewer than two choices).
function ns.RewardPick()
  local n = GetNumQuestChoices() or 0
  if n < 2 then return nil end
  local best, bestGain, richest, top, reason
  for i = 1, n do
    local link = GetQuestItemLink("choice", i)
    if not link then return nil end
    local up, level, worn = gain(link)
    if up and up > 0 and (not bestGain or up > bestGain) then
      best, bestGain = i, up
      reason = string.format(L["upgrade: item level %d over your %d"], level, worn)
    end
    local _, _, count = GetQuestItemInfo("choice", i)
    local price = select(11, C_Item.GetItemInfo(link))
    if not price then return nil end
    local value = price * (count or 1)
    if not top or value > top then richest, top = i, value end
  end
  if best then return best, reason end
  if top <= 0 then return nil end
  return richest, string.format(L["sells for the most: %s (weapons are not compared)"], ns.Money(top))
end

local glows = {} -- our textures on the reward buttons, by button

local function hideGlows()
  for _, t in pairs(glows) do t:Hide() end
end

local function glow(index)
  local frame = (QuestInfoFrame and QuestInfoFrame.rewardsFrame) or QuestInfoRewardsFrame
  for _, b in pairs(frame and frame.RewardButtons or {}) do
    if b.type == "choice" and b:GetID() == index and b:IsShown() then
      local t = glows[b]
      if not t then
        t = b:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        t:SetBlendMode("ADD")
        t:SetAllPoints(b.Icon or b)
        glows[b] = t
      end
      t:Show()
    end
  end
end

local function show(tries)
  if ns.db.rewardHint == false or ns.inCombat() then return end
  local index, reason = ns.RewardPick()
  if not index then
    if tries < RETRIES and (GetNumQuestChoices() or 0) >= 2 then
      C_Timer.After(RETRY_DELAY, function() show(tries + 1) end)
    end
    return
  end
  glow(index)
  ns.Say(string.format(L["quest reward: %s, %s."], GetQuestItemLink("choice", index) or "?", reason))
end

local events = CreateFrame("Frame")
events:RegisterEvent("QUEST_COMPLETE")
events:RegisterEvent("QUEST_FINISHED")
events:SetScript("OnEvent", function(_, event)
  hideGlows()
  if event == "QUEST_COMPLETE" then
    -- next frame: the reward buttons are laid out by then
    C_Timer.After(0, function() xpcall(function() show(0) end, ns.report) end)
  end
end)
