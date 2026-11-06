# Publishing Timber on Roblox

Everything the experience page needs: what to upload, the text to paste, and the settings to pick. GitHub publishes
the game itself (step 1); the page's pictures, text and settings are set on the Creator Dashboard, at
https://create.roblox.com/dashboard/creations > your Timber experience.

## 1. Publish the game
On GitHub: **Actions** > **Roblox assets and publishing** > **Run workflow**, tick **publish**, then **Run workflow**.
It builds the place from the code and replaces the experience's published version. Nothing else changes until
you make the experience public (step 4).

Before that, the **Roblox engine check** workflow should be green: it runs the game in a real Roblox server and
draws it with Roblox's renderer next to the Godot game (`roblox/tests/engine/out/`).

## 2. The pictures (Configure > Basic Info, and Places > Timber > Thumbnails)
All in this folder; made by `python3 tools/make_roblox_art.py` from the game's own screenshots (`docs/itch/`).
- **Icon:** `icon_512.png` (512x512, the half-peeled birch and the title)
- **Thumbnails**, in this order:
  1. `thumbnail_1_peel.jpg` - peeling bark off a birch, with the title
  2. `thumbnail_2_truck.jpg` - the log truck loaded with bark
  3. `thumbnail_3_factory.jpg` - windmill, belts, sawmill, smelter and wires
  4. `thumbnail_4_rails_drone.jpg` - a mining cart on rails, and a drone carrying an iron bar
  5. `thumbnail_5_build.jpg` - decorations round the cabin
  6. `thumbnail_6_shop.jpg` - TimberMart on the cabin computer

The screenshots are from the Godot version, which the Roblox version now matches (the engine check's
`pair_*.jpg` show both); the HUD on Roblox is the same.

## 3. The text (Configure > Basic Info)
- **Name:** Timber
- **Genre:** Simulation
- **Description:** `description.txt` in this folder (under Roblox's 1000 characters, with the codes). The
  "Roblox assets and publishing" workflow puts it on the game page when you run it with **description** ticked
  (or with **publish** ticked); or paste it by hand. When you change `Config.Codes`, change the CODES lines too.
  The API key needs one more permission for this: Creator Dashboard > Open Cloud > API Keys > your key > Access
  Permissions > add **universe.place** (Write) for Timber > Save. Without it Roblox answers "Scope not authorized".

## 3b. Badges (optional, recommended)
Badges show on players' profiles, which brings their friends. The game awards one for playing and one for each
trophy, as soon as it knows the badge's id.
1. Creator Dashboard > Creations > Timber > **Engagement > Badges** > **Create a Badge**, once for each icon in
   `badges/` (the file name is the trophy). Roblox lets you make a few free each day.
   Names and descriptions: welcome "Welcome to Timber" (you played!), first_tree "Timber!" (your first tree felled),
   first_machine "Machinist", thousand "$1,000 earned", first_plank "Sawyer", first_iron "Smelter",
   first_furniture "Carpenter", giant "Giant" (an ancient giant felled), legend "Legend" (the Legendary Tree
   felled), first_oil "Oil!" (your first barrel of oil), golden "Golden!" (felled the golden tree), week "7 Days"
   (a week of daily rewards in a row), jobs "Hired!" (all of a day's jobs done).
2. Copy each badge's id into `Config.Badges` in `roblox/src/shared/Config.luau` (or tell Claude the ids), then publish
   again. Players who already have the trophy get the badge next time they join.

## 3b2. Analytics (nothing to set up)
The game reports to Roblox's analytics on its own: Creator Dashboard > Creations > Timber > **Analytics**.
- **Onboarding funnel:** one step per Getting started step (take the hatchet, peel, load the truck ...): where
  new players stop.
- **Economy:** money in (the mill, daily rewards, jobs, codes, take-downs) and out (the shop, land).
The charts fill in a day or so after players come.

## 3c. Codes
`Config.Codes` (in `roblox/src/shared/Config.luau`) holds the codes players can type into the TimberPhone, and what
each pays (once per player). It starts with TIMBER ($100) and LUMBERJACK ($250). Post codes where your players
follow the game (the group wall, Discord, X); add a new one for each update and publish.

## 4. Settings
- **Configure > Questionnaire** (maturity): Roblox requires it before the game can be public. Answer what the game
  has: no blood, no gore, no romance, no gambling, no realistic weapons. The only harm is to yourself: bare hands
  and dynamite hurt you, and you faint and wake at the cabin. Roblox's form decides the label; it will likely be
  Minimal or Mild.
- **Places > Timber > Server size:** 8 is a good start. Everyone on a server shares the forest; land, builds,
  machines, track and money belong to each player and are saved with them.
- **Configure > Devices:** **Computer**, **Phone** and **Tablet**. Phones have touch buttons for everything (Swing,
  Use, Drop, Phone, Run, and Turn / Take down with the hammer), the tool bar switches tools with a tap, and the hints
  name the buttons. Nothing here can draw the game's screens (Roblox's preview renderer skips UI), so try it once in
  **Studio > Test > Device** (a phone) to check the HUD and the phone's screens fit, and to feel the controls.
- **Configure > Access:** **Public** when you're ready. Until then it stays private and only you (and your
  friends, if you allow) can join.

## 5. What can't be checked from GitHub
The engine check runs the game in a real Roblox server and draws it with Roblox's renderer, but Roblox doesn't run
physics in those cloud sessions, and nobody can join them. So, once, before going public, play it for a few
minutes (Studio > Play, or the published game): things falling and landing, the chute, the catapult, dynamite,
carrying and dropping, and how it feels on your machine.
