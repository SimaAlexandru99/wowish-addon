# Wowish — design

**Goal:** a passive WoW Forever addon (1.60.1, Interface 16001) that, out of combat, tells the player the few
things worth doing next for their character, and sets a waypoint only when asked.

## Architecture (all in game, no external tools)
```
client events ──► Core.lua: throttled (1 s), never in combat ──► rules ──► top 5 ──► UI.lua window / login line
                                                                  │
               RulesCommon.lua (turn-ins, talents, bags, next zone), RulesHunter.lua (ammo), RulesTrainer.lua
                                                                  │
         Questie.lua ── optional ──► LibQuestieDB (QuestieDB addon, contract 4): turn-in NPC, ammo vendors
         Services.lua: one background scan per session (2 ms/frame, paused in combat) of QuestieDB NPC flags
         (Enum.npcFlags TRAINER / FLIGHT_MASTER / REPAIR) -> nearest class trainer, repair NPC, flight master
         Navigation.lua "Take me there": ShortestPathForever.API route (owner "Wowish") ► else Waypoint.lua
         (TomTom ► native pin ► chat) + MinimapGuide.lua (straight-line dots + edge arrow, honours rotateMinimap)
         Welcome.lua (first login), SettingsPanel.lua (Options > AddOns > Wowish), Locale.lua (English / Romanian)
         Access: MinimapButton.lua (own button, badge = tip count), NextBar.lua (#1 tip line, off by default),
         Bindings.xml (toggle key), Addon Compartment; all go through ns.NotifyChanged()
```

## Rule contract
`ns.RegisterRule({ id, events, maxInTop?, evaluate })`. `evaluate()` only reads client state and returns
`{ id, kind, priority 0-100, what, why, waypoint?, details?, action? }`. Core sorts by priority, applies `maxInTop`, keeps 5,
isolates a failing rule with `xpcall` and hands its error to the client error handler (BugSack), and skips rules
the player turned off (`WowishDB.rules[id] == false`). Tips may add `details` (full list for the card tooltip) and
`action` (`{ open = "map", arg }`, a button that only opens the world map) or `hint` (`"talents"` | `"spellbook"` |
`"bags"`: names the player's own key). Never open the spellbook, talents or bags from addon code: it taints them
and the game blocks action-bar and item buttons in combat.

| rule | priority | source |
|---|---|---|
| talents | 95 | `C_ClassTalents.HasUnspentTalentPoints` |
| turnin | 90 on your map, 70 place unknown, 68 on the way, 60 elsewhere; max 2 | `C_QuestLog` + QuestieDB finisher |
| trainer | 80 | own class spells due by level/race (`TrainerData.lua`, from OneForAll), known via `C_SpellBook.IsSpellKnown` |
| repair | 90 below 5% durability, 75 below 20% | `GetInventoryItemDurability`, nearest REPAIR NPC |
| fund | saving 30 (60 two levels before), short 70, ready 85 with the race riding trainer; Apprentice 30-41, Journeyman 50-60 | `GetMoney`, home-faction `C_Reputation` (Honored: -10%), `IsPlayerSpell` or riding skill line 762; trainers from Polestar |
| ammo (Hunter) | 88 none of the right type, 85 outdated | weapon subclass, own ammo table, QuestieDB vendors |
| bags | 86 at 0 free regular slots (loot lost now), 65 at 1-4 | `C_Container`, bag family 0 only |
| zone | 50 | quest log headers within ±3 levels, skips dungeon/raid/PvP/profession tags |

## Locations
Only from QuestieDB at run time, only for an NPC/object with exactly one spawn outside instances; otherwise the
tip has no waypoint. Nothing from QuestieDB is copied into the repo or the package.

## Never
Nothing in combat (window hides on `PLAYER_REGEN_DISABLED`, commands refuse), no input automation
(no CastSpell/UseAction/secure buttons), no network, no persistent waypoints, no pop-ups except the one-time
welcome. Own wording only; no text from guides.

License: GPL-3.0-or-later.
