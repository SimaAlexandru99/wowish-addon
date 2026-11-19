-- /wowish new: what changed in the newest version, in a few chat lines. Update this table with every release.
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local L = ns.L

ns.CHANGES = {
  version = "0.7.1",
  lines = {
    "Hidden and snoozed tips no longer take a place in the top 5.",
    "A hidden bag, quest log, repair or gold tip stays hidden until the situation changes, not just a number.",
    "Missed Apprentice Riding at 40? The gold plan keeps it as your goal.",
  },
}

function ns.WhatsNew()
  ns.Say(string.format(L["What is new in Wowish %s:"], ns.CHANGES.version))
  for _, line in ipairs(ns.CHANGES.lines) do ns.Say("- " .. L[line]) end
end
