# Wowish — design

**Goal:** a WoW Forever addon (1.60.1, Interface 16001) that, out of combat, tells the player the few
things worth doing next for their character, and sets a waypoint only when asked. Its only actions are opt-in
vendor helpers (`Vendor.lua`), off by default, inside a merchant window the player opened, never in combat.

## Architecture (all in game, no external tools)
```
client events ──► Core.lua: throttled (1 s), never in combat ──► rules ──► top 5 ──► UI.lua window / login line
                                                                  │
               RulesCommon.lua (turn-ins, talents, bags, next zone), RulesHunter.lua (ammo), RulesTrainer.lua
                                                                  │
         Questie.lua ── optional ──► LibQuestieDB (QuestieDB addon, contract 4): turn-in NPC, ammo vendors
         Services.lua: one background scan per session (2 ms/frame, paused in combat) of QuestieDB NPC flags
         (Enum.npcFlags TRAINER / FLIGHT_MASTER / REPAIR) -> nearest class trainer, repair NPC, flight master;
         plus the places the player visited (WowishDB.places: repairing vendors, own class trainers)
         Navigation.lua "Take me there": ShortestPathForever.API route (owner "Wowish") ► else Waypoint.lua
         (TomTom ► native pin ► chat) + MinimapGuide.lua (straight-line dots + edge arrow, honours rotateMinimap)
         Welcome.lua (first login), SettingsPanel.lua (Options > AddOns > Wowish), Locale.lua (English / Romanian)
         Access: MinimapButton.lua (own button, badge = tip count), NextBar.lua (#1 tip line, off by default),
         Bindings.xml (toggle key), Addon Compartment; all go through ns.NotifyChanged()
```

## Rule contract
`ns.RegisterRule({ id, events, maxInTop?, evaluate })`. `evaluate()` only reads client state and returns
`{ id, kind, priority 0-100, what, why, waypoint?, details?, action?, state? }`. Core sorts by priority, skips
hidden tips, then applies `maxInTop` and keeps 5, isolates a failing rule with `xpcall` and hands its error to the
client error handler (BugSack), and skips rules the player turned off (`WowishDB.rules[id] == false`). Tips may add
`details` (full list for the card tooltip) and `action` (`{ open = "map", arg }`, a button that only opens the world
map) or `hint` (`"talents"` | `"spellbook"` | `"bags"`: names the player's own key). A tip whose text carries a
counter adds `state` (a short name such as `"almost"` or `"full"`): hide and snooze hold while `state` (else `what`)
stays the same, and a hide ends once the tip goes away. Never open the spellbook, talents or bags from addon code: it taints them and the game blocks
action-bar and item buttons in combat.

| rule | priority | source |
|---|---|---|
| talents | 95 | `C_ClassTalents.HasUnspentTalentPoints` |
| turnin | 90 on your map, 70 place unknown, 68 on the way, 60 elsewhere; max 2 | `C_QuestLog` + QuestieDB finisher |
| trainer | 80, +8 when the trainer is within 200 yards | own class spells due by level/race (`TrainerData.lua`, from OneForAll), known via `C_SpellBook.IsSpellKnown` |
| repair | 90 below 5% durability, 75 below 20%, +8 when the NPC is within 200 yards | `GetInventoryItemDurability`, nearest REPAIR NPC |
| fund (gold plan) | saving 30 (60 two levels before), saved 20 (free to spend), short 70, ready 85 with the race riding trainer; the first tier still to buy, Apprentice from 30, Journeyman from 50 (a late rider keeps the Apprentice tip); next class training cost (recorded at `TRAINER_SHOW` per character and level, else 54c x level^2) | `GetMoney`, home-faction `C_Reputation` (Honored: -10%), `IsPlayerSpell` or riding skill line 762; trainers from Polestar |
| commissions | 65 when every material of a commission in the log is in the bags; button asks CommissionsForever to route to the hand-ins | `CommissionsForever.API.Materials`, `Subscribe`, `NavigateActiveAssignments` (optional addon) |
| ammo (Hunter) | 88 none of the right type, 85 outdated | weapon subclass, own ammo table, QuestieDB vendors |
| bags | 86 at 0 free regular slots (loot lost now), 65 at 1-4 | `C_Container`, bag family 0 only |
| zone | 50 | quest log headers within ±3 levels, skips dungeon/raid/PvP/profession tags |
| questlog | 60 at 2 or fewer free quest log slots, 80 when full; names the grey quests | `C_QuestLog.GetNumQuestLogEntries`, `GetMaxNumQuestsCanAccept` |
| greyquests | 35 from 3 unfinished trivial quests | `C_QuestLog.IsQuestTrivial` |

## Locations
Only from QuestieDB at run time, only for an NPC/object with exactly one spawn outside instances; otherwise the
tip has no waypoint. Nothing from QuestieDB is copied into the repo or the package.
The one other source is the player: `ns.LearnPlace` records where a repairing vendor (`MERCHANT_SHOW`) or the
player's class trainer (`TRAINER_SHOW`) was opened, per faction and class, and `ns.NearestService` uses those too.

## Never
Nothing in combat (window hides on `PLAYER_REGEN_DISABLED`, commands refuse), no input automation
(no CastSpell/UseAction/secure buttons), no network, no persistent waypoints, no pop-ups except the one-time
welcome. Own wording only; no text from guides.

License: GPL-3.0-or-later.

## Outside the tip list
- `QuestReward.lua`: on `QUEST_COMPLETE` with 2+ choices, marks one reward (own texture on the reward button) and
  says why in chat: the biggest item-level gain of an armor piece of the class's armor type (mail/plate from 40;
  cloaks, rings, necks, trinkets for all; rings and trinkets against the lower worn one), else the highest sell
  value. Weapons are not compared. Never calls `GetQuestReward`. Setting `rewardHint`.
- Hearthstone hint (`Hearth.lua`): text appended to the `why` of every tip with a waypoint (in `Core.Evaluate`) and
  printed by `ns.Go`; never a priority change, never a button. Only without ShortestPathForever. The inn is
  learned per character a second after `HEARTHSTONE_BOUND` and two seconds after a Hearthstone cast (spell 8690)
  while the zone or subzone text equals `GetBindLocation()`. Tips refresh when the stone's cooldown moves between
  silent, "soon" and "ready" (`BAG_UPDATE_COOLDOWN` plus one timer), not on every cooldown event. Shown when the inn is within 300 yards of the place, the player is over
  1000 yards away (or on another continent), item 6948 is in the bags and its cooldown is 5 minutes or less.
  Setting `hearthHint`.
- Level-up line (`UI.lua`): after `PLAYER_LEVEL_UP`, one chat line from the trainer and talents tips of the next
  evaluation (so never in combat) plus the training cost. Setting `levelLine`.
- `Vendor.lua`: opt-in helpers at an open merchant (sell greys, repair, Hunter ammo within the riding reserve).
