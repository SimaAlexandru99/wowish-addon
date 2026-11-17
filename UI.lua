-- Wowish main window, slash command, Addon Compartment entry and login line.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
-- Native Blizzard templates only (ButtonFrameTemplate etc., used the same way by Forever addons).
-- Nothing opens on its own except the optional one-line chat summary at login.
local _, ns = ...
local L = ns.L

local WIDTH, GAP = 540, 6
local MIN_HEIGHT, MAX_HEIGHT, CHROME = 230, 620, 92 -- the window grows with its cards; title+footer = CHROME
local ICONS = {
  quest = "Interface\\GossipFrame\\ActiveQuestIcon",
  talent = "Interface\\Icons\\INV_Misc_Book_11",
  bags = "Interface\\Icons\\INV_Misc_Bag_08",
  ammo = "Interface\\Icons\\INV_Ammo_Arrow_02",
  zone = "Interface\\Icons\\INV_Misc_Map_01",
  trainer = "Interface\\Icons\\INV_Misc_Book_09",
  repair = "Interface\\Icons\\Trade_BlackSmithing",
  fund = "Interface\\Icons\\INV_Misc_Coin_02",
  commissions = "Interface\\Icons\\INV_Crate_01",
}

ns.dismissed = {} -- [suggestion id] = text when hidden; the tip returns once its text changes

function ns.Say(msg)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Wowish|r: " .. tostring(msg)) end
end

-- Suggestions the player has not hidden this session.
function ns.Visible()
  local out = {}
  for _, s in ipairs(ns.suggestions) do
    if ns.dismissed[s.id] ~= s.what then out[#out + 1] = s end
  end
  return out
end

function ns.AgeText(t)
  if not t then return L["not updated yet"] end
  local s = math.max(0, time() - t)
  if s < 60 then return L["updated just now"] end
  return string.format(L["updated %d min ago"], math.floor(s / 60))
end

local frame, scroll, content, sub, empty, settingsButton
local cards = {}

-- Open a game window for a tip. Only the world map: opening the spellbook, talents or bags from addon code
-- taints them, and the game then blocks their action-bar and item buttons in combat (seen in game:
-- ADDON_ACTION_BLOCKED on MultiBarBottomLeftButton1:SetShown). Those tips name the player's own key instead.
local PANELS = {
  map = function(mapID)
    if OpenWorldMap then OpenWorldMap(mapID) return true end
  end,
  commissions = function() -- CommissionsForever routes to every hand-in through ShortestPathForever
    local a = ns.CommissionsAPI and ns.CommissionsAPI()
    if not (a and a.NavigateActiveAssignments and a.NavigateActiveAssignments()) then
      ns.Say(L["Commissions Forever could not start a route (it needs Shortest Path Forever)."])
    end
    return true
  end,
}
local ACTION_LABEL = { map = "Map", commissions = "Take me there" }

-- "Press N to open your talents." from the player's own key binding (only reads settings).
local HINTS = {
  talents = { "TOGGLETALENTS", "Press %s to open your talents.", "Open your talents from the game menu." },
  spellbook = { "TOGGLESPELLBOOK", "Press %s to open your spellbook.", "Open your spellbook from the game menu." },
  bags = { "OPENALLBAGS", "Press %s to open your bags.", "Open your bags from the bag bar." },
}
function ns.KeyHint(kind)
  local h = HINTS[kind]
  if not h then return nil end
  local key = GetBindingKey and GetBindingKey(h[1])
  if key then return string.format(L[h[2]], (GetBindingText and GetBindingText(key)) or key) end
  return L[h[3]]
end

function ns.OpenPanel(kind, arg)
  if ns.inCombat() then return false end
  local open = PANELS[kind]
  local ok, done = pcall(open or function() end, arg)
  if ok and done then return true end
  ns.Say(L["this window cannot be opened from here; use its key binding."])
  return false
end

local function savePosition()
  local point, _, relPoint, x, y = frame:GetPoint()
  ns.db.pos = { point, relPoint, x, y }
end

function ns.ApplyLayout()
  if not frame then return end
  frame:SetScale(ns.db.scale or 1)
  frame:ClearAllPoints()
  local p = ns.db.pos
  if p then frame:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else frame:SetPoint("CENTER") end
end

local function newCard(i)
  local c = CreateFrame("Frame", nil, content, "BackdropTemplate")
  c:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  c:SetBackdropColor(0, 0, 0, 0.45)
  c:SetBackdropBorderColor(0.4, 0.4, 0.4)
  c:SetWidth(WIDTH - 50)
  c.icon = c:CreateTexture(nil, "ARTWORK")
  c.icon:SetSize(28, 28)
  c.icon:SetPoint("TOPLEFT", 8, -8)
  -- small grey "x", only while the mouse is over the card
  c.hide = CreateFrame("Button", nil, c)
  c.hide:SetSize(16, 16)
  c.hide:SetPoint("TOPRIGHT", -4, -4)
  c.hide:SetNormalFontObject("GameFontDisable")
  c.hide:SetHighlightFontObject("GameFontHighlight")
  c.hide:SetText("x")
  c.hide:Hide()
  c.hide:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L["Hide this tip. It comes back when things change."], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  c.hide:SetScript("OnLeave", function()
    GameTooltip:Hide()
    if not c:IsMouseOver() then c.hide:Hide() end
  end)
  c.go = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
  c.go:SetSize(90, 20)
  c.go:SetPoint("TOPRIGHT", -24, -6)
  c.what = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  c.what:SetJustifyH("LEFT")
  c.what:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 8, 0)
  c.why = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  c.why:SetJustifyH("LEFT")
  c.why:SetPoint("TOPLEFT", c.what, "BOTTOMLEFT", 0, -3)
  c:EnableMouse(true)
  c:SetScript("OnLeave", function()
    GameTooltip:Hide()
    if not c.hide:IsMouseOver() then c.hide:Hide() end
  end)
  cards[i] = c
  return c
end

local function fillCard(c, i, s)
  c.icon:SetTexture(ICONS[s.kind] or ICONS.quest)
  local action = s.waypoint and "waypoint" or (s.action and s.action.open)
  local textWidth = (WIDTH - 50) - 52 - (action and 118 or 26)
  c.what:SetWidth(textWidth)
  c.why:SetWidth(textWidth)
  c.go:SetText(action == "waypoint" and L["Take me there"] or L[ACTION_LABEL[action] or "Map"])
  c.what:SetText(string.format("|cffffd100%d.|r %s", i, s.what)) -- same number as /wowish go N
  local seconds = s.waypoint and ns.RouteSeconds and ns.RouteSeconds(s.waypoint)
  local hint = s.hint and ns.KeyHint(s.hint)
  c.why:SetText((s.why or "") .. (seconds and string.format(L[" About %d min by the fastest route."],
    math.max(1, math.floor(seconds / 60 + 0.5))) or "") .. (hint and (" |cffffd100" .. hint .. "|r") or ""))
  if i == 1 then c:SetBackdropBorderColor(1, 0.82, 0) else c:SetBackdropBorderColor(0.4, 0.4, 0.4) end
  c:SetScript("OnEnter", function(self) -- full text: the card shortens long lists
    c.hide:Show()
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(s.what, 1, 1, 1, true)
    for _, line in ipairs(s.details or {}) do GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
    GameTooltip:Show()
  end)
  c.go:SetShown(action ~= nil)
  c.go:SetScript("OnClick", function()
    if action == "waypoint" then ns.Go(i) else ns.OpenPanel(action, s.action.arg) end
  end)
  c.hide:SetScript("OnClick", function()
    ns.dismissed[s.id] = s.what
    ns.NotifyChanged() -- window, minimap badge and next-tip bar follow
  end)
  local h = math.max(44, c.what:GetStringHeight() + c.why:GetStringHeight() + 22)
  c:SetHeight(h)
  return h
end

local function build()
  if frame then return frame end
  frame = CreateFrame("Frame", "WowishFrame", UIParent, "ButtonFrameTemplate")
  if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(frame) end
  if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(frame) end
  frame:SetSize(WIDTH, MIN_HEIGHT)
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(f)
    f:StopMovingOrSizing()
    savePosition()
  end)
  table.insert(UISpecialFrames, "WowishFrame") -- Escape closes it

  sub = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sub:SetPoint("TOPLEFT", 16, -30)
  scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 10, -48)
  scroll:SetPoint("BOTTOMRIGHT", -30, 36)
  content = CreateFrame("Frame", nil, scroll)
  content:SetSize(WIDTH - 50, 1)
  scroll:SetScrollChild(content)

  empty = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  empty:SetPoint("TOP", 0, -40)
  empty:SetWidth(WIDTH - 80)

  if ns.OpenSettings then
    settingsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    settingsButton:SetSize(90, 22)
    settingsButton:SetPoint("BOTTOMRIGHT", -12, 8)
    settingsButton:SetScript("OnClick", function() ns.OpenSettings() end)
  end
  ns.RefreshTexts()
  ns.ApplyLayout()
  frame:Hide()
  return frame
end

-- Static labels; called again when the language changes.
function ns.RefreshTexts()
  if not frame then return end
  if frame.SetTitle then frame:SetTitle(L["Wowish - what to do now"]) end
  empty:SetText(L["Nothing urgent right now."] .. "\n\n|cffaaaaaa" ..
    L["Tips appear here when something needs your attention."] .. "|r")
  if settingsButton then settingsButton:SetText(L["Settings"]) end
  ns.Render()
end

function ns.Render()
  if not (frame and frame:IsShown()) then return end
  local list = ns.Visible()
  local name, level = UnitName("player"), UnitLevel("player")
  sub:SetText(string.format(L["%s, level %d - %s"], tostring(name), level or 0, ns.AgeText(ns.updatedAt)))
  local y = 0
  for i, s in ipairs(list) do
    local c = cards[i] or newCard(i)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", 0, -y)
    y = y + fillCard(c, i, s) + GAP
    c:Show()
  end
  for i = #list + 1, #cards do cards[i]:Hide() end
  empty:SetShown(#list == 0)
  content:SetHeight(math.max(y, 1))
  frame:SetHeight(math.min(MAX_HEIGHT, math.max(MIN_HEIGHT, y + CHROME)))
  if scroll.ScrollBar then scroll.ScrollBar:SetShown(y + CHROME > MAX_HEIGHT) end -- only when it cannot fit
end
ns.OnSuggestionsUpdated(function() ns.Render() end)

function ns.Show()
  if ns.inCombat() then
    ns.Say(L["in combat: advice is paused. Try again after the fight."])
    return
  end
  build():Show()
  ns.Render()
  ns.RequestUpdate() -- show what we have now, refresh within a second (map may have changed)
end

function ns.Toggle()
  if frame and frame:IsShown() then frame:Hide() else ns.Show() end
end

function ns.IsShown()
  return frame ~= nil and frame:IsShown()
end

-- Waypoint for visible tip n (the number shown in the window and in /wowish go N).
function ns.Go(n)
  local s = ns.Visible()[n]
  if not s then return ns.Say(string.format(L["there is no tip %s."], tostring(n))) end
  local w = s.waypoint
  if not w then return ns.Say(string.format(L["tip %d has no known place."], n)) end
  local how, replaced = ns.TakeMeThere(w, w.title)
  if how == "combat" then return ns.Say(L["in combat: waypoints are paused."]) end
  if how == "route" then
    ns.Say(string.format(L["route started with ShortestPathForever: %s."], w.title))
    if replaced then ns.Say(L["It replaced the route that was already running."]) end
    return
  end
  if how == "chat" then
    ns.Say(string.format(L["no waypoint addon or map pin available. Go to %s."], ns.FormatPlace(w)))
  else
    ns.Say(string.format(L["waypoint set: %s (%s)."], w.title, ns.FormatPlace(w)))
  end
  local fm = ns.FlightHint and ns.FlightHint(w)
  if fm then
    ns.Say(string.format(L["Nearest flight master: %s (%s). Not checked whether you know this flight path."],
      fm.place.name or "?", ns.FormatPlace(fm.place)))
  end
end

-- One block a player can copy into a bug report: versions, helpers, what the rules are doing, recent errors.
function ns.ReportLines()
  if ns.Questie then ns.Questie() end -- fresh helper status even if no tip needed QuestieDB yet
  local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local version = meta and meta("Wowish", "Version") or "?"
  local game, gameBuild = "?", "?"
  if GetBuildInfo then game, gameBuild = GetBuildInfo() end
  local failing = {}
  for id in pairs(ns.errors) do failing[#failing + 1] = id end
  table.sort(failing)
  local lines = {
    string.format("Wowish %s | game %s (%s) | %s", version, tostring(game), tostring(gameBuild),
      GetLocale and GetLocale() or "?"),
    string.format("QuestieDB: %s | TomTom: %s | ShortestPathForever: %s", tostring(ns.questieStatus or "not checked"),
      (TomTom and TomTom.AddWaypoint) and "yes" or "no", (ns.RoutePlanner and ns.RoutePlanner()) and "yes" or "no"),
    string.format("tips: %d | failing rules: %s", #ns.suggestions,
      #failing > 0 and table.concat(failing, ", ") or "none"),
  }
  for i, err in ipairs(ns.recentErrors) do lines[#lines + 1] = string.format("error %d: %s", i, err) end
  return lines
end

local function onSlash(msg)
  msg = strtrim((msg or ""):lower())
  local n = msg:match("^go%s+(%d+)$")
  if msg == "" or msg == "show" then
    ns.Toggle()
  elseif n then
    ns.Go(tonumber(n))
  elseif msg == "clear" then
    ns.Say(ns.StopNavigation() and L["waypoint removed."] or L["no Wowish waypoint is set."])
  elseif msg == "report" then
    for _, line in ipairs(ns.ReportLines()) do ns.Say(line) end
  elseif msg == "welcome" and ns.ShowWelcome then
    ns.ShowWelcome()
  else
    ns.Say(L["/wowish (window), /wowish go N (take me there), /wowish clear, /wowish welcome, /wowish report"])
  end
end

SLASH_WOWISH1 = "/wowish"
SlashCmdList.WOWISH = function(msg)
  local ok, err = xpcall(function() onSlash(msg) end, ns.report)
  if not ok then ns.Say("error: " .. tostring(err)) end
end

-- Addon Compartment (TOC: ## AddonCompartmentFunc) and the key binding (Bindings.xml) call this global.
function Wowish_OnAddonCompartmentClick()
  ns.Toggle()
end
BINDING_HEADER_WOWISH = "Wowish"
BINDING_NAME_WOWISH_TOGGLE = L["Open or close Wowish"]

-- Login line: once, after the first evaluation that follows login.
local loginPending, levelPending = false, nil
ns.OnSuggestionsUpdated(function(top)
  if levelPending and not loginPending then
    local level, parts, trainer = levelPending, {}, false
    levelPending = nil
    if not ns.db.levelLine then return end
    for _, tip in ipairs(top) do
      if tip.rule == "trainer" or tip.rule == "talents" then
        parts[#parts + 1] = tip.what
        trainer = trainer or tip.rule == "trainer"
      end
    end
    if #parts == 0 then return end
    ns.Say(string.format(L["Level %d: %s"], level, table.concat(parts, " ")) .. (trainer and ns.TrainerLine() or ""))
    return
  end
  if not loginPending then return end
  loginPending = false
  levelPending = nil -- the login line wins
  if not ns.db.loginLine then return end
  if #top == 0 then
    ns.Say(L["nothing urgent right now. (/wowish)"])
  else
    ns.Say(string.format(L["%s. #1: %s (/wowish)"], ns.Count(#top, "tip"), top[1].what))
  end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function(_, event, level)
  if event == "PLAYER_LOGIN" then
    loginPending = true
  elseif event == "PLAYER_LEVEL_UP" then
    levelPending = level or UnitLevel("player")
  elseif frame and frame:IsShown() then -- combat started: get out of the way
    frame:Hide()
  end
end)
