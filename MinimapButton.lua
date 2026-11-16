-- Wowish minimap button: left-click opens the window, right-click the settings, drag moves it around the
-- minimap. A small number shows how many tips are waiting. Own button, no libraries (LibDBIcon not needed).
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local L = ns.L

local ICON = "Interface\\Icons\\INV_Misc_Map_01"
local button, badge

local function place()
  local angle = math.rad(ns.db.minimapAngle or 200)
  local radius = Minimap:GetWidth() / 2 + 5
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- While dragging: angle from the minimap centre to the cursor.
local function follow()
  local mx, my = Minimap:GetCenter()
  local scale = Minimap:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  ns.db.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
  place()
end

local function showTooltip(self)
  local list = ns.Visible()
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("Wowish")
  if #list == 0 then
    GameTooltip:AddLine(L["Nothing urgent right now."], 0.8, 0.8, 0.8)
  else
    GameTooltip:AddLine(ns.Count(#list, "tip"), 1, 0.82, 0)
    GameTooltip:AddLine("1. " .. list[1].what, 1, 1, 1, true)
  end
  GameTooltip:AddLine(L["Left-click: open. Right-click: settings. Drag: move."], 0.5, 0.5, 0.5, true)
  GameTooltip:Show()
end

local function build()
  button = CreateFrame("Button", "WowishMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local icon = button:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture(ICON)
  icon:SetSize(20, 20)
  icon:SetPoint("TOPLEFT", 7, -5)
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  badge = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  badge:SetPoint("BOTTOMRIGHT", -3, 4)
  button:SetScript("OnClick", function(_, mouse)
    if mouse == "RightButton" then ns.OpenSettings() else ns.Toggle() end
  end)
  button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", follow) end)
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  button:SetScript("OnEnter", showTooltip)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function ns.UpdateMinimapButton()
  if not ns.db then return end
  if not ns.db.minimapButton then
    if button then button:Hide() end
    return
  end
  if not button then build() end
  place()
  local n = #ns.Visible()
  badge:SetText(n > 0 and tostring(n) or "")
  button:Show()
end
ns.OnSuggestionsUpdated(function() ns.UpdateMinimapButton() end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() ns.UpdateMinimapButton() end)
