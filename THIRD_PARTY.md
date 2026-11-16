# Third-party material

## OneForAll — class trainer spell data
- File: `TrainerData.lua` (copied from OneForAll 6.2.9, `Data/TrainerSpells.lua`).
- Copyright (C) 2026 Smoergi. License: GPL-3.0-or-later.
- Origin stated by OneForAll: generated from the WoW Forever client database (SkillLineAbility / SpellLevels).
- Modified 2026-11-16 for Wowish: the table is assigned to the Wowish addon namespace instead of OneForAll's.
  The rows are unchanged.
- `RulesTrainer.lua` follows the known-rank and race-mask approach of OneForAll's `UI/TrainerSpells.lua`.

## Runtime only (not copied)
- QuestieDB: quest finishers, vendors and zone maps are read at run time through `LibQuestieDB` when installed.
