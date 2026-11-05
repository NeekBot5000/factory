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
- **Description** (paste; it fits Roblox's 1000 characters):

---
Peel it. Fell it. Build something bigger.

Timber is a first-person lumberjack game where everything is a real object. There's no inventory: peel the bark
off a tree in sheets, pick the pieces up, carry them to your truck and send it to the mill.

Start with bare hands (it hurts). Buy a hatchet, then axes that hit twice, take whole rings or chop six times a
second. Fell trees, saw logs, build furniture and decorations worth far more than the wood in them.

Then automate it: wire cranks, windmills and generators to belts, sawmills, smelters and assemblers. Mine copper
and iron, lay rails for carts, send drones, pump oil, and grow a one-person camp into a factory.

Controls: WASD to move, click to swing, E to grab and use, Q to drop, 1-9 or the mouse wheel for tools.
---

## 4. Settings
- **Configure > Questionnaire** (maturity): Roblox requires it before the game can be public. Answer what the game
  has: no blood, no gore, no romance, no gambling, no realistic weapons. The only harm is to yourself: bare hands
  and dynamite hurt you, and you faint and wake at the cabin. Roblox's form decides the label; it will likely be
  Minimal or Mild.
- **Places > Timber > Server size:** 8 is a good start. Everyone on a server shares the forest; land, builds,
  machines, track and money belong to each player and are saved with them.
- **Configure > Devices:** **Computer** first. The game has touch buttons for phones and tablets, but they haven't
  been tried on a real phone yet: try **Studio > Test > Device** (a phone) before ticking Phone and Tablet.
- **Configure > Access:** **Public** when you're ready. Until then it stays private and only you (and your
  friends, if you allow) can join.

## 5. What can't be checked from GitHub
The engine check runs the game in a real Roblox server and draws it with Roblox's renderer, but Roblox doesn't run
physics in those cloud sessions, and nobody can join them. So, once, before going public, play it for a few
minutes (Studio > Play, or the published game): things falling and landing, the chute, the catapult, dynamite,
carrying and dropping, and how it feels on your machine.
