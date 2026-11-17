# Wowish

A small, passive advisor for **WoW Forever** (1.60.1), for players who want no leveling guide: no route, no
arrow to follow, no quests taken for you. Out of combat it shows the few things worth doing next for your character:

- quests ready to hand in, grouped by where you hand them in;
- new spells or ranks waiting at your class trainer (and where the nearest one is);
- gear about to break, and the nearest repair NPC;
- gold for riding: saving from level 30 for Apprentice Riding at 40 (100g, 90g at Honored; paladins and warlocks
  get it from a class quest) and from 50 for Journeyman Riding at 60 (1000g), then the way to your riding trainer;
- unspent talent points;
- bags almost full;
- where to keep questing (never a dungeon or battleground);
- Hunters: vendor ammo that matches your weapon and level.

It never acts in combat, never presses a button or casts anything for you, and sets a waypoint only when you
click one. English and Romanian.

## Use
- The **minimap button** (left-click: window, right-click: settings, drag: move; the number is how many tips are
  waiting), `/wowish`, the Addon Compartment, or a key you set in Key Bindings > AddOns: open/close the window.
- Optional: a one-line bar under the minimap with the current #1 tip (Options > AddOns > Wowish).
- Hover a card for its full text and a small x to hide it. Cards with a place have Take me there, the zone tip
  has Map, and talent, trainer and bag tips name the key that opens that window. Buttons never act for you.
- `/wowish go N`: take me there for tip N. `/wowish clear`: stop it. `/wowish welcome`: the welcome screen.
  `/wowish report`: versions, helpers and recent errors, to paste into a bug report.
- Options > AddOns > Wowish: language, login line, window size, which tips to show.

## Optional helpers
- **QuestieDB**: adds where to go (turn-in NPCs, ammo vendors, class trainers, repair NPCs, flight masters). Read at run time; nothing is copied.
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
