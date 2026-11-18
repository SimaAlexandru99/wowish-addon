# Changelog

## v0.6.2 (unreleased)
- `/wowish hide N` hides tip N from the keyboard, the same as the card's x.
- Tests for the repair thresholds (20% and 5%) and for the new command.

## v0.6.1
- Hearthstone hint: when your inn is within 300 yards of a tip's place and you are far from it, the card and the
  "Take me there" chat line say your Hearthstone is ready (or ready in under 5 minutes). Wowish learns where your
  inn is when you set it or land there, and never uses the stone for you. Left to ShortestPathForever when it is
  installed. Can be turned off in the settings.
- Quests that give no XP: with three or more unfinished grey quests in your log, a low tip names them.
- Quest log space: a tip when two or fewer slots are left, higher when the log is full; it names the grey quests
  to drop first. Wowish never abandons a quest.
- The class trainer is recognised on clients in any language, so training costs and the visited trainer are
  recorded there too.

## v0.6.0
- Places you visited: Wowish remembers where you opened a repairing vendor or your class trainer, so the repair and
  trainer tips have Take me there without QuestieDB too.
- Right here: a repair or trainer tip moves up the list and says the distance when its NPC is within 200 yards.
- Level-up line: after a level-up, one chat line with the new spells at your trainer, about what they cost and your
  unspent talent points. Nothing when there is nothing to do. Can be turned off in the settings.

## v0.5.0
- Quest rewards: when a quest lets you choose, Wowish marks the reward worth taking and says why in chat: a higher
  item level of your armor type, else the one that sells for the most (weapons are not compared). You still pick
  it. Can be turned off in the settings.

## v0.4.0
- Optional vendor helpers, all off until you turn them on: sell grey items, repair, and for Hunters top up ammo to
  the stacks you set (1-10, default 3). Only while a vendor window you opened is shown, never in combat; hold Shift
  as it opens to skip. One chat line says what was done. With OneForAll or Polestar loaded, Wowish leaves selling
  and repairs to them. Ammo never spends the gold kept for riding.
- Gold plan: the riding card now says what is free to spend once the riding gold is saved, and what the next class
  training costs (as your trainer asked at this level, else an estimate).

## v0.3.0
- Gold for riding: save from level 30 for Apprentice Riding (level 40) and from 50 for Journeyman Riding (level 60),
  then the way to your race's riding trainer.
- Commissions ready: with Commissions Forever installed, a card when a commission in your log has all its
  materials in your bags; its button routes to the hand-ins.
- "Take me there" says when it replaced a route another addon had started.
- Minimap button flashes once when a new tip arrives.
