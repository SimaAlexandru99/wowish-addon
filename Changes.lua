-- /wowish new: what changed in the newest version, in a few chat lines. Update this table with every release.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local L = ns.L

ns.CHANGES = {
  version = "0.7.0",
  lines = {
    "Hidden tips: a Show hidden button in the window (or /wowish unhide) brings them back.",
    "Snooze: the z on a card (or /wowish snooze N) hides a tip for 30 minutes.",
    "The bar under the minimap now takes you to the #1 tip when you click it; right-click opens the window.",
    "The welcome screen has the level-up line and Hearthstone hint options.",
  },
}

function ns.WhatsNew()
  ns.Say(string.format(L["What is new in Wowish %s:"], ns.CHANGES.version))
  for _, line in ipairs(ns.CHANGES.lines) do ns.Say("- " .. L[line]) end
end
