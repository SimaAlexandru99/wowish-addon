# Wowish

A small, passive advisor for **WoW Forever** (1.60.1), for players who want no leveling guide: no route, no
arrow to follow, no quests taken for you. Out of combat it shows the few things worth doing next for your character:

- quests ready to hand in, grouped by where you hand them in;
- new spells or ranks waiting at your class trainer (and where the nearest one is);
- gear about to break, and the nearest repair NPC;
- a gold plan: saving from level 30 for Apprentice Riding at 40 (100g, 90g at Honored; paladins and warlocks
  get it from a class quest) and from 50 for Journeyman Riding at 60 (1000g), then the way to your riding trainer;
  what the next class training costs (as asked at your trainer, else an estimate) and what is free to spend;
- unspent talent points;
- bags almost full;
- where to keep questing (never a dungeon or battleground);
- Hunters: vendor ammo that matches your weapon and level;
- at a quest with rewards to choose from, the one worth taking (a higher item level of your armor type, else the
  one that sells for the most), marked and explained in chat; you still pick it.

It never acts in combat, never moves your character or casts anything for you, never takes or hands in quests,
and sets a waypoint only when you click one. English and Romanian.

Optional vendor helpers, all off until you turn them on (Options > AddOns > Wowish): sell grey items, repair, and
for Hunters top up ammo (never with the gold kept for riding). They run only while a vendor window you opened is
shown; hold Shift as it opens to skip them. With OneForAll or Polestar loaded, Wowish leaves selling and repairs to
them.

## Use
- The **minimap button** (left-click: window, right-click: settings, drag: move; the number is how many tips are
  waiting), `/wowish`, the Addon Compartment, or a key you set in Key Bindings > AddOns: open/close the window.
- Optional: a one-line bar under the minimap with the current #1 tip (Options > AddOns > Wowish).
- Hover a card for its full text and a small x to hide it. Cards with a place have Take me there, the zone tip
  has Map, and talent, trainer and bag tips name the key that opens that window. Buttons never act for you.
- `/wowish go N`: take me there for tip N. `/wowish clear`: stop it. `/wowish welcome`: the welcome screen.
  `/wowish report`: versions, helpers and recent errors, to paste into a bug report.
- After a level-up, one chat line says what is new at your trainer and whether you have talent points to spend.
- Options > AddOns > Wowish: language, login and level-up lines, window size, which tips to show.

## Optional helpers
- **QuestieDB**: adds where to go (turn-in NPCs, ammo vendors, class trainers, repair NPCs, flight masters). Read at run time; nothing is copied.
  Without it, Wowish still remembers the repair vendors and class trainers you have visited and sends you back to
  the nearest one (trainers only on an English client for now). A repair or trainer tip moves up the list when its NPC is within 200 yards.
- **TomTom**: waypoints use its arrow; without it, the game's own map pin.
- **ShortestPathForever**: "Take me there" asks it for the real route (walking, flights, boats, portals), drawn on
  the map and minimap, and cards show the travel time. Without it, Wowish draws a straight-line guide on the
  minimap (dots and an edge arrow; it does not know roads or flights).
- **Commissions Forever**: a card when a commission in your log has all its materials in your bags; its button asks
  Commissions Forever for the route to the hand-ins.

## Development
Lua 5.1 with busted and luacheck: `luacheck *.lua spec && busted`. Design: `DESIGN.md`. Releases are built by
the BigWigs packager from `v*` tags.

## License
GPL-3.0-or-later (`LICENSE`). Third-party data and credits: `THIRD_PARTY.md`.
