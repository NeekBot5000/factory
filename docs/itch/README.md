# Publishing Timber on itch.io

Everything needed for the itch.io page: the files to upload, the text to paste, and the settings to pick.
Nothing here has been uploaded; you do that from your itch.io account.

## 1. Get the files

Every push builds them. On GitHub: **Actions > the latest green "Test & build" run > Artifacts > `Timber-itch`**.
Unzip it and you get three zips, one per upload:

| File | itch.io "Kind" | Notes |
|---|---|---|
| `Timber-web.zip` | HTML, **"This file will be played in the browser"** | `index.html` is at the top of the zip, as itch wants |
| `Timber-windows.zip` | Executable, tick **Windows** | `Timber.exe` plus README and licences |
| `Timber-linux.zip` | Executable, tick **Linux** | `Timber.x86_64` plus README and licences |

There is no macOS build: Godot's Mac export needs signing and notarising on a Mac to open without warnings.

## 2. Create the project (itch.io > Dashboard > Create new project)

- **Title:** Timber
- **Project URL:** e.g. `yourname.itch.io/timber`
- **Short description / tagline:** Peel bark, fell trees, and grow a one-person lumber camp into a factory of belts, rails and drones.
- **Classification:** Games
- **Kind of project:** HTML (so the browser version is the main one; the downloads still work)
- **Release status:** Released (or "In development" if you want to keep adding things and say so)
- **Pricing:** "No payments" or "Donate" with a suggested $0 (you said you want people playing, not money)
- **Uploads:** the three zips above, with the kinds in the table

### Embed options (for the web build)

- **Viewport dimensions:** 1280 x 720
- **Automatically start on page load:** off (the game needs a click for sound and the mouse anyway)
- **Fullscreen button:** on
- **Mobile friendly:** off (it needs a mouse and keyboard)
- **SharedArrayBuffer support:** not needed (the web build is exported without threads)
- **Frame options / scrollbars:** leave as they are

### Details

- **Genre:** Simulation
- **Tags** (a third-party guide says itch allows 10; the edit page shows the real limit): `3D`, `First-Person`, `Low-poly`, `Physics`, `Automation`, `Factory`, `Crafting`, `Relaxing`, `Singleplayer`, `Sandbox`
- **Generative AI disclosure:** this field is on the edit page and must be filled in: itch.io says projects that use
  generative AI without disclosing it aren't listed on its browse pages. Answer **Yes**, then tick what applies. For
  Timber that's **code** (all of it was written with Claude) and **text** (the descriptions, guide and this page).
  The 3D models, sounds and music are made by the game's own code rather than by an image or audio AI, so whether to
  also tick graphics and sound is your call - ticking them is the cautious choice. itch.io then tags the page.
  ([itch.io quality guidelines](https://itch.io/docs/creators/quality-guidelines#ai-disclosure),
  [PCGamesInsider on the rule](https://www.pcgamesinsider.biz/news/74828/devs-need-to-disclose-if-game-uses-genai-on-itchio/))
- **Inputs:** Keyboard, Mouse
- **Accessibility:** Configurable controls is not true yet; "Adjustable difficulty" no. You can leave this empty.
- **Average session:** A few hours (or "About an hour" for a first session)
- **Languages:** English
- **Links:** the GitHub repository if you want it public

## 3. Screenshots and cover

All in this folder:

- `cover_630x500.png` - the **cover image** (itch shows it in browse lists; 630x500 is the size itch's
  [getting-started docs](https://itch.io/docs/creators/getting-started) suggest)
- `01_peel.png` - peeling bark off a birch with the labrys
- `02_truck.png` - the log truck loaded with bark
- `03_factory.png` - windmill, belts, sawmill, smelter, assembler and wires
- `04_rails_drone.png` - a mining cart with a rail layer and drill rig, and a drone carrying an iron bar
- `05_build.png` - decorations around the cabin and a statue being built
- `06_shop.png` - the TimberMart shop on the cabin computer

To make them again after the game changes:
`xvfb-run -a godot --path . res://tests/StoreShots.tscn --rendering-driver opengl3 --resolution 1280x720`
(the cover is then cropped from `01_peel.png` with `tools/make_cover.py`).

## 4. The page text (paste into "Description")

---

**Timber** is a first-person lumberjack game where everything is a physics object. There is no inventory: you peel
the bark off a tree in sheets, pick the pieces up, carry them to your truck and send it to the mill.

Start with bare hands (it hurts). Buy a hatchet, then axes that hit twice, take whole rings, or chop six times a
second. Fell trees, cut logs, build furniture and decorations that are worth far more than the wood in them.

Then automate it.

- **Machines:** cranks, windmills, generators and batteries; levers, sensors and seven logic blocks; conveyor belts,
  pistons, grabber arms and sorters; a sawmill, kiln, chipper, smelter and assembler.
- **Power sockets:** wire machines together, or click a battery cell into any machine's socket.
- **Mining:** dig down for copper and iron, then set up drill rigs that dig by themselves.
- **Rails and carts:** lay track by hand, build minecarts that carry machines on their decks, and wire up the logic
  that makes them go - a rail layer and lifter let a cart walk forever on a handful of rails.
- **Drones:** steered by five wireless channels, each lifting only so much.
- **Growth:** buy more land, a bigger truck, and watch your company sign grow.

Everything you see - every model, sound and song - is made from code inside the game. It saves by itself.

**Controls:** mouse to look, WASD to move, left click to use your tool, E to pick up and use things, R to turn,
Tab for the phone, Esc for the menu. The in-game guide (Esc > Guide) has the full list and explains every machine.
Keys go by position, so AZERTY and QWERTZ keyboards work too.

Made by NeekBot5000 with Claude, in Godot 4.4.

---

## 5. Later updates

Once the page exists, `tools/push_itch.sh <your-itch-username> <folder with the three zips>` uploads a new version
with [butler](https://itch.io/docs/butler/) (install it and run `butler login` once). Bump `config/version` in
`project.godot` and add a line to `CHANGELOG.md` first. butler's uploads are separate from ones made by hand on the
website: if you start with butler, use it from the first upload (then mark the web one "played in the browser" once);
if you started by hand, delete the hand-made uploads after the first butler push.

## 6. Before you press Publish

- Play the browser version on the itch page once (click, walk, open the computer). The game was tested inside a
  cross-origin iframe like itch's (it boots, starts a new game, walks and saves), but not on itch itself.
- Saves in the browser are stored per site: the itch.io version and the GitHub Pages version don't share saves.
- If you change the feedback link in the pause menu (it points at GitHub issues now), it's `FEEDBACK_URL` in
  `scripts/SettingsMenu.gd` - your itch page's comments, for example.
