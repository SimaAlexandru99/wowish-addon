-- Wowish welcome / onboarding: shown once after install (and with /wowish welcome). One screen:
-- what it does, the passive promise, which optional helpers were found, language and login line.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local L = ns.L

local WIDTH = 470
local welcome, body, helpers, setupTitle, checks, closeButton, adviceButton

local function ok(text) return "|cff3fbf3f+|r " .. text end
local function missing(text) return "|cffe0a030-|r " .. text end

function ns.HelperStatus()
  local questie = ns.Questie() and ok(L["QuestieDB found: advice includes where to go."])
    or missing(L["QuestieDB not found: advice comes without locations."])
  local tomtom = (TomTom and TomTom.AddWaypoint) and ok(L["TomTom found: waypoints use TomTom."])
    or missing(L["TomTom not found: waypoints use the game's own map pin."])
  local route = (ns.RoutePlanner and ns.RoutePlanner()) and ok(L["ShortestPathForever found: real routes on the map and minimap."])
    or missing(L["ShortestPathForever not found: a straight-line guide on the minimap. Install it for real routes."])
  return questie .. "\n" .. tomtom .. "\n" .. route
end

-- Language changed: every visible text follows, tips are recomputed in the new language.
function ns.OnLocaleChanged()
  ns.FillWelcome()
  if ns.RefreshTexts then ns.RefreshTexts() end
  ns.RequestUpdate()
end

local function checkbox(y, get, set)
  local cb = CreateFrame("CheckButton", nil, welcome, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb:SetPoint("TOPLEFT", 14, y)
  cb.label = welcome:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  cb.get = get
  cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  return cb
end

local function build()
  if welcome then return end
  welcome = CreateFrame("Frame", "WowishWelcomeFrame", UIParent, "ButtonFrameTemplate")
  if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(welcome) end
  if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(welcome) end
  welcome:SetSize(WIDTH, 508)
  welcome:SetPoint("CENTER")
  welcome:SetFrameStrata("DIALOG")
  welcome:SetClampedToScreen(true)
  table.insert(UISpecialFrames, "WowishWelcomeFrame")

  body = welcome:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  body:SetPoint("TOPLEFT", 18, -36)
  body:SetWidth(WIDTH - 36)
  body:SetJustifyH("LEFT")
  helpers = welcome:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  helpers:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -10)
  helpers:SetWidth(WIDTH - 36)
  helpers:SetJustifyH("LEFT")
  setupTitle = welcome:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  setupTitle:SetPoint("TOPLEFT", 18, -250)

  checks = {
    checkbox(-270, function() return ns.IsRomanian() end, function(on)
      ns.db.locale = on and "roRO" or false
      ns.OnLocaleChanged()
    end),
    checkbox(-296, function() return ns.db.loginLine end, function(on) ns.db.loginLine = on end),
    checkbox(-322, function() return ns.db.minimapButton end, function(on)
      ns.db.minimapButton = on
      ns.UpdateMinimapButton()
    end),
    checkbox(-348, function() return ns.db.nextBar end, function(on)
      ns.db.nextBar = on
      ns.UpdateNextBar()
    end),
    checkbox(-374, function() return ns.db.levelLine end, function(on) ns.db.levelLine = on end),
    checkbox(-400, function() return ns.db.hearthHint end, function(on) ns.db.hearthHint = on end),
  }
  welcome.helpersNote = welcome:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  welcome.helpersNote:SetPoint("TOPLEFT", 18, -432)
  welcome.helpersNote:SetWidth(WIDTH - 36)
  welcome.helpersNote:SetJustifyH("LEFT")

  closeButton = CreateFrame("Button", nil, welcome, "UIPanelButtonTemplate")
  closeButton:SetSize(110, 24)
  closeButton:SetPoint("BOTTOMRIGHT", -140, 12)
  closeButton:SetScript("OnClick", function() welcome:Hide() end)
  adviceButton = CreateFrame("Button", nil, welcome, "UIPanelButtonTemplate")
  adviceButton:SetSize(120, 24)
  adviceButton:SetPoint("BOTTOMRIGHT", -14, 12)
  adviceButton:SetScript("OnClick", function()
    welcome:Hide()
    ns.Show()
  end)
  welcome.foot = welcome:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  welcome.foot:SetPoint("BOTTOMLEFT", 18, 18)
  welcome:Hide()
end

function ns.FillWelcome()
  if not welcome then return end
  if welcome.SetTitle then welcome:SetTitle(L["Welcome to Wowish"]) end
  body:SetText(L["Wowish looks at your character when you are out of combat and tells you the few things worth doing next: quests ready to hand in, new spells at your trainer, unspent talent points, full bags, where to quest, and (for Hunters) ammo."]
    .. "\n\n|cffffd100" .. L["Never acts in combat. Never presses a button or casts anything for you. Waypoints only when you click one."]
    .. "|r\n\n|cffffd100" .. L["Optional helpers"] .. "|r")
  helpers:SetText(ns.HelperStatus())
  setupTitle:SetText(L["Quick setup"])
  checks[1].label:SetText(L["Romanian language (Romana)"])
  checks[2].label:SetText(L["Show a one-line summary in chat when I log in"])
  checks[3].label:SetText(L["Show the minimap button"])
  checks[4].label:SetText(L["Show the next tip under the minimap"])
  checks[5].label:SetText(L["Show a line in chat after a level-up"])
  checks[6].label:SetText(L["Hint when my Hearthstone is a good way to get there"])
  welcome.helpersNote:SetText(L["Vendor helpers (sell grey items, repair, Hunter ammo) are off. Turn them on in Options > AddOns > Wowish."])
  for _, cb in ipairs(checks) do cb:SetChecked(cb.get() and true or false) end
  welcome.foot:SetText(L["Reopen anytime: /wowish welcome"])
  closeButton:SetText(L["Close"])
  adviceButton:SetText(L["Show my advice"])
end

function ns.ShowWelcome()
  if ns.inCombat() then
    ns.Say(L["in combat: advice is paused. Try again after the fight."])
    return
  end
  build()
  ns.FillWelcome()
  welcome:Show()
  ns.db.welcomeSeen = true
end

function ns.IsWelcomeShown()
  return welcome ~= nil and welcome:IsShown()
end

-- First login after install: wait a moment so the default UI settles, never during combat.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
  if ns.db and not ns.db.welcomeSeen then
    C_Timer.After(3, function()
      if not ns.inCombat() and not ns.db.welcomeSeen then ns.ShowWelcome() end
    end)
  end
end)
