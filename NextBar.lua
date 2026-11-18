-- Wowish next-tip bar: one quiet line under the minimap with the current #1 tip (off by default).
-- Click: take me there for the #1 tip (the window if it has no place); right-click: the window.
-- Hidden in combat and when there is nothing to do. Never flashes or plays sounds.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local L = ns.L

local bar

local function build()
  bar = CreateFrame("Button", "WowishNextBar", UIParent, "BackdropTemplate")
  bar:SetSize(230, 22)
  bar:SetPoint("TOP", Minimap, "BOTTOM", 0, -22)
  bar:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
  bar:SetBackdropColor(0, 0, 0, 0.5)
  bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.text:SetPoint("LEFT", 6, 0)
  bar.text:SetPoint("RIGHT", -6, 0)
  bar.text:SetJustifyH("LEFT")
  bar.text:SetWordWrap(false)
  bar:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  bar:SetScript("OnClick", function(_, button)
    local first = ns.Visible()[1]
    if button ~= "RightButton" and first and first.waypoint then ns.Go(1) else ns.Toggle() end
  end)
  bar:SetScript("OnEnter", function(self)
    local first = ns.Visible()[1]
    if not first then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(first.what, 1, 1, 1, true)
    GameTooltip:AddLine(first.why or "", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(first.waypoint and L["Click: take me there. Right-click: window."] or L["Click: window."],
      1, 0.82, 0, true)
    GameTooltip:Show()
  end)
  bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function ns.UpdateNextBar()
  if not ns.db then return end
  local first = ns.Visible()[1]
  if not ns.db.nextBar or not first or ns.inCombat() then
    if bar then bar:Hide() end
    return
  end
  if not bar then build() end
  bar.text:SetText("|cff33ff99Wowish:|r " .. first.what)
  bar:Show()
end
ns.OnSuggestionsUpdated(function() ns.UpdateNextBar() end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_DISABLED" then
    if bar then bar:Hide() end
  else
    ns.UpdateNextBar()
  end
end)
