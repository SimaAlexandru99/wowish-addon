-- Wowish texts. Keys are the English text; Romanian is chosen in Wowish settings (WoW has no roRO
-- client). Romanian is written without diacritics: the default game font may not draw s/t-comma
-- (not yet checked in game).
-- Copyright (C) 2026 Wowish authors. License: GPL-3.0-or-later (see LICENSE).
local _, ns = ...

local RO = {
  -- rules
  ["Turn in %s: %s."] = "Preda %s: %s.",
  ["Turn in %s in %s: %s."] = "Preda %s in %s: %s.",
  ["Completed quests give their XP only when you hand them in."] =
    "Questurile terminate dau XP doar cand le predai.",
  ["They are on your current map."] = "Sunt pe harta pe care esti acum.",
  ["You have open quests there anyway."] = "Ai oricum questuri deschise acolo.",
  ["Worth it when you pass through."] = "Merita cand treci pe acolo.",
  ["You have %s."] = "Ai %s.",
  ["Open your talents and spend them: an unspent point is power you are not using."] =
    "Deschide talentele si cheltuieste-le: un punct necheltuit e putere nefolosita.",
  ["Bags almost full: %s of %d."] = "Bagaje aproape pline: %s din %d.",
  ["With full bags you start leaving loot behind. Sell or destroy grey items."] =
    "Cu bagajele pline incepi sa lasi loot in urma. Vinde sau distruge itemele gri.",
  ["Keep questing in %s: %s at your level (%s)."] = "Continua in %s: %s la nivelul tau (%s).",
  ["Most of your active objectives near your level are there, so the least travel per XP."] =
    "Acolo sunt cele mai multe obiective active apropiate de nivelul tau, deci cel mai putin drum pe XP.",
  [" You are at %d%% of level %d."] = " Esti la %d%% din nivelul %d.",
  ["Ammo adds damage to every shot; vendor ammo of your level is cheap and much stronger."] =
    "Munitia adauga damage la fiecare lovitura; munitia de vendor de nivelul tau e ieftina si mult mai buna.",
  ["No %s in your bags: buy %s."] = "Nu ai %s in bagaje: cumpara %s.",
  ["Upgrade your ammo: buy %s (level %d) instead of %s."] =
    "Schimba munitia: cumpara %s (nivel %d) in loc de %s.",
  ["%s sells it on your current map."] = "%s o vinde pe harta ta.",
  ["arrows"] = "sageti",
  ["Visit your class trainer: %s (%s)."] = "Mergi la trainerul de clasa: %s (%s).",
  ["New ranks are stronger versions of spells you already use, and trainers teach them for a small fee."] =
    "Rangurile noi sunt variante mai puternice ale vrajilor pe care le folosesti deja, iar trainerul le preda pe bani putini.",
  ["bullets"] = "gloante",
  -- main window, chat
  ["Wowish - what to do now"] = "Wowish - ce fac acum",
  ["Take me there"] = "Du-ma acolo",
  ["route started with ShortestPathForever: %s."] = "ruta pornita cu ShortestPathForever: %s.",
  ["It replaced the route that was already running."] = "A inlocuit ruta care era deja pornita.",
  [" About %d min by the fastest route."] = " Cam %d min pe drumul cel mai rapid.",
  ["you have arrived: %s."] = "ai ajuns: %s.",
  ["Settings"] = "Setari",
  ["Nothing urgent right now."] = "Nimic urgent acum.",
  ["Tips appear here when something needs your attention."] =
    "Sfaturile apar aici cand ceva are nevoie de atentia ta.",
  ["%s, level %d - %s"] = "%s, nivel %d - %s",
  ["not updated yet"] = "neactualizat inca",
  ["updated just now"] = "actualizat acum",
  ["updated %d min ago"] = "actualizat acum %d min",
  ["in combat: advice is paused. Try again after the fight."] =
    "in lupta: sfaturile sunt oprite. Incearca dupa lupta.",
  ["in combat: waypoints are paused."] = "in lupta: waypoint-urile sunt oprite.",
  ["there is no tip %s."] = "nu exista sfatul %s.",
  ["tip %d has no known place."] = "sfatul %d nu are un loc cunoscut.",
  ["no waypoint addon or map pin available. Go to %s."] = "nu am cum pune waypoint. Mergi la %s.",
  ["waypoint set: %s (%s)."] = "waypoint pus: %s (%s).",
  ["waypoint removed."] = "waypoint sters.",
  ["no Wowish waypoint is set."] = "niciun waypoint Wowish activ.",
  ["/wowish (window), /wowish go N (take me there), /wowish clear, /wowish welcome, /wowish report"] =
    "/wowish (fereastra), /wowish go N (du-ma acolo), /wowish clear, /wowish welcome, /wowish report",
  ["nothing urgent right now. (/wowish)"] = "nimic urgent acum. (/wowish)",
  ["%s. #1: %s (/wowish)"] = "%s. #1: %s (/wowish)",
  -- welcome
  ["Welcome to Wowish"] = "Bun venit in Wowish",
  ["Wowish looks at your character when you are out of combat and tells you the few things worth doing next: quests ready to hand in, new spells at your trainer, unspent talent points, full bags, where to quest, and (for Hunters) ammo."] =
    "Wowish se uita la personajul tau cand nu esti in lupta si iti spune putinele lucruri care merita facute acum: questuri de predat, vraji noi la trainer, puncte de talent necheltuite, bagaje pline, unde sa faci questuri si (pentru Hunteri) munitia.",
  ["Never acts in combat. Never presses a button or casts anything for you. Waypoints only when you click one."] =
    "Nu face nimic in lupta. Nu apasa niciun buton si nu da nicio vraja in locul tau. Waypoint doar cand dai tu click.",
  ["Optional helpers"] = "Ajutoare optionale",
  ["QuestieDB found: advice includes where to go."] = "QuestieDB gasit: sfaturile spun si unde sa mergi.",
  ["QuestieDB not found: advice comes without locations."] = "QuestieDB lipseste: sfaturile vin fara locatie.",
  ["TomTom found: waypoints use TomTom."] = "TomTom gasit: waypoint-urile folosesc TomTom.",
  ["TomTom not found: waypoints use the game's own map pin."] =
    "TomTom lipseste: waypoint-urile folosesc pinul de harta al jocului.",
  ["Quick setup"] = "Setare rapida",
  ["ShortestPathForever found: real routes on the map and minimap."] =
    "ShortestPathForever gasit: rute reale pe harta si pe minimap.",
  ["ShortestPathForever not found: a straight-line guide on the minimap. Install it for real routes."] =
    "ShortestPathForever lipseste: un ghid in linie dreapta pe minimap. Instaleaza-l pentru rute reale.",
  ["Romanian language (Romana)"] = "Limba romana (Romana)",
  ["Show a one-line summary in chat when I log in"] = "Arata un rezumat de o linie in chat la login",
  ["Reopen anytime: /wowish welcome"] = "Redeschizi oricand: /wowish welcome",
  ["Close"] = "Inchide",
  ["Show my advice"] = "Arata sfaturile",
  -- settings
  ["One-line summary in chat at login"] = "Rezumat de o linie in chat la login",
  ["Window scale"] = "Marimea ferestrei",
  ["Tips"] = "Sfaturi",
  ["Quests to hand in"] = "Questuri de predat",
  ["Unspent talent points"] = "Puncte de talent necheltuite",
  ["Bag space"] = "Loc in bagaje",
  ["Where to quest next"] = "Unde continui questurile",
  ["Hunter: ammo"] = "Hunter: munitie",
  ["Class trainer"] = "Trainer de clasa",
  ["Repairs"] = "Reparatii",
  ["repairs"] = "reparatii",
  ["Repair your gear: one item is at %d%% durability."] = "Repara echipamentul: un item are %d%% durabilitate.",
  ["Broken items stop giving their stats. Any armor or weapon vendor can repair them."] =
    "Itemele stricate nu mai dau statistici. Orice vendor de armuri sau arme le repara.",
  ["Nearest flight master: %s (%s). Not checked whether you know this flight path."] =
    "Cel mai apropiat zbor: %s (%s). Nu stiu daca ai descoperit deja aceasta ruta.",
  ["Gold plan (riding, training)"] = "Plan de aur (riding, antrenament)",
  ["Riding gold is ready: keep %s for %s at level %d, %s is free to spend."] = "Aurul pentru riding e strans: pastreaza %s pentru %s la nivelul %d, %s poti cheltui.",
  ["Next class training: about %s (estimate)."] = "Urmatorul antrenament de clasa: cam %s (estimare).",
  ["Next class training: %s."] = "Urmatorul antrenament de clasa: %s.",
  ["not enough gold to repair (%s)"] = "nu ai destul aur pentru reparatii (%s)",
  ["repaired (%s)"] = "reparat (%s)",
  ["ammo skipped: it would cut into your riding savings (%s)"] = "munitia sarita: ar lua din aurul pentru riding (%s)",
  ["ammo skipped: not enough gold"] = "munitia sarita: nu ai destul aur",
  ["bought %d %s (%s)"] = "cumparat %d %s (%s)",
  ["sold %s (%s)"] = "vandut %s (%s)",
  ["Off by default. Only while a vendor window you opened is shown, never in combat; hold Shift when it opens to skip."] = "Oprit implicit. Doar cat e deschisa fereastra unui vendor deschisa de tine, niciodata in lupta; tine Shift apasat cand o deschizi ca sa sari peste.",
  ["%s is loaded and does this already, so Wowish leaves it to %s."] = "%s e incarcat si face deja asta, asa ca Wowish il lasa pe %s.",
  ["Sell grey items at vendors"] = "Vinde itemele gri la vendori",
  ["Repair at vendors"] = "Repara la vendori",
  ["Hunter: restock ammo at vendors"] = "Hunter: completeaza munitia la vendori",
  ["Never spends the gold kept for riding."] = "Nu cheltuie niciodata aurul pastrat pentru riding.",
  ["Ammo stacks to keep"] = "Stive de munitie de pastrat",
  ["Save for %s at level %d: %s of %s."] = "Strange pentru %s la nivelul %d: %s din %s.",
  ["%s costs %s: you need %s more."] = "%s costa %s: iti mai trebuie %s.",
  ["Train %s at your race's riding trainer: you have the %s."] =
    "Invata %s la trainerul de riding al rasei tale: ai cei %s.",
  ["Your first mount comes with it."] = "Primul mount vine cu el.",
  ["Mounted speed goes to 100%."] = "Viteza pe mount creste la 100%.",
  ["You get the Honored price."] = "Ai pretul de Honored.",
  ["Honored with your home faction takes 10% off."] = "Honored cu factiunea ta de acasa scade pretul cu 10%.",
  ["riding trainer"] = "trainer de riding",
  ["Dual spec (50g at level 40) can wait."] = "Dual spec (50g la nivelul 40) poate astepta.",
  ["Commissions ready"] = "Comisioane gata",
  ["Commissions ready to hand in: %s."] = "Comisioane gata de predat: %s.",
  ["The materials are in your bags. Commissions Forever knows where to hand them in."] = "Materialele sunt in genti. Commissions Forever stie unde se predau.",
  ["Commissions Forever could not start a route (it needs Shortest Path Forever)."] = "Commissions Forever nu a putut porni ruta (are nevoie de Shortest Path Forever).",
  ["Window position"] = "Pozitia ferestrei",
  ["Reset"] = "Reseteaza",
  ["Welcome screen"] = "Ecranul de bun venit",
  ["Show"] = "Arata",
  ["Map"] = "Harta",
  ["Press %s to open your talents."] = "Apasa %s pentru talente.",
  ["Open your talents from the game menu."] = "Deschide talentele din meniul jocului.",
  ["Press %s to open your spellbook."] = "Apasa %s pentru cartea de vraji.",
  ["Open your spellbook from the game menu."] = "Deschide cartea de vraji din meniul jocului.",
  ["Press %s to open your bags."] = "Apasa %s pentru bagaje.",
  ["Open your bags from the bag bar."] = "Deschide bagajele din bara de bagaje.",
  ["Hide this tip. It comes back when things change."] = "Ascunde sfatul. Revine cand se schimba ceva.",
  ["this window cannot be opened from here; use its key binding."] = "fereastra asta nu se poate deschide de aici; foloseste tasta ei.",
  ["Show the minimap button"] = "Arata butonul de langa minimap",
  ["Show the next tip under the minimap"] = "Arata urmatorul sfat sub minimap",
  ["Left-click: open. Right-click: settings. Drag: move."] = "Click stanga: deschide. Click dreapta: setari. Trage: muta.",
  ["Open or close Wowish"] = "Deschide sau inchide Wowish",
  ["Labels in this settings page change after /reload."] = "Etichetele din pagina de setari se schimba dupa /reload.",
  ["Open Game Menu > Options > AddOns > Wowish."] = "Deschide Game Menu > Options > AddOns > Wowish.",
}

-- Counted nouns: { singular, plural }.
local NOUNS = {
  en = { ["completed quest"] = { "completed quest", "completed quests" }, quest = { "quest", "quests" },
    ["unspent talent point"] = { "unspent talent point", "unspent talent points" },
    ["free slot"] = { "free slot", "free slots" }, ["open quest"] = { "open quest", "open quests" },
    tip = { "tip", "tips" }, ["new spell"] = { "new spell", "new spells" },
    commission = { "commission", "commissions" }, ["grey item"] = { "grey item", "grey items" } },
  ro = { ["completed quest"] = { "quest terminat", "questuri terminate" }, quest = { "quest", "questuri" },
    ["unspent talent point"] = { "punct de talent necheltuit", "puncte de talent necheltuite" },
    ["free slot"] = { "slot liber", "sloturi libere" }, ["open quest"] = { "quest deschis", "questuri deschise" },
    tip = { "sfat", "sfaturi" }, ["new spell"] = { "vraja noua", "vraji noi" },
    commission = { "comision", "comisioane" }, ["grey item"] = { "item gri", "iteme gri" } },
}

function ns.IsRomanian()
  return ns.db ~= nil and ns.db.locale == "roRO"
end

ns.L = setmetatable({}, { __index = function(_, key)
  return ns.IsRomanian() and RO[key] or key
end })

-- "1 quest", "3 quests"; Romanian adds "de" from 20 on, except numbers ending in 01-19 ("20 de questuri").
function ns.Count(n, noun)
  local ro = ns.IsRomanian()
  local forms = (ro and NOUNS.ro or NOUNS.en)[noun] or { noun, noun }
  if n == 1 then return "1 " .. forms[1] end
  local r = n % 100
  if ro and n > 0 and (r == 0 or r >= 20) then return n .. " de " .. forms[2] end
  return n .. " " .. forms[2]
end

ns.RO_KEYS = RO -- for the test that every Romanian key is a real English text
