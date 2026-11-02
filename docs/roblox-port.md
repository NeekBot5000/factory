# Timber on Roblox: the plan

Roblox can't run the Godot game. Godot uses GDScript and its own renderer, physics and file formats; Roblox runs
**Luau** scripts inside **Roblox Studio** and on Roblox's servers. So this is a **rewrite**, with the Godot version as
the finished design to copy: every mechanic, number and test already exists and works.

The rewrite has started in `roblox/`: a Rojo project with the core game logic in tested Luau, and the server and
client scripts that use it (details at the end).

## What you need to do first (in order)

1. **Roblox account + Studio.**
   - Install [Roblox Studio](https://create.roblox.com/).
   - Verify your email and turn on 2-step verification. Publishing, DataStores and later the console checklist need a
     verified account.
2. **Tools on your computer.**
   - Install [VS Code](https://code.visualstudio.com/) with the **Luau Language Server** extension.
   - Install [Rojo](https://rojo.space/). It syncs the `roblox/` folder into Studio, so the code lives in Git like
     the Godot project.
   - Install the Rojo plugin in Studio.
3. **Make the place.** In Studio:
   - New > Baseplate > **File > Publish to Roblox** (keep it private).
   - **Game Settings > Security:** turn on *Enable Studio Access to API Services*, so saves work while testing.
   - **Workspace:** check that `StreamingEnabled` is on (the Rojo project turns it on).
4. **Connect the code.**
   - In a terminal in `roblox/`, run `rojo serve`.
   - In Studio, open the Rojo plugin and click **Connect**. The scripts appear in ReplicatedStorage,
     ServerScriptService and StarterPlayerScripts.
5. **Build a test forest.** Make about 30 trees by hand or with a quick command-bar script. Each tree is a **Model**:
   - **Tag:** `Tree` (Studio's Tag Editor).
   - **Attributes:** `Species` (oak, pine, birch, hickory, cedar, cork, eucalyptus), `Sectors` = 16, `Bands` = 40,
     `Radius` (studs), `Height` (studs).
   - **Parts inside:** `Core` (a wood-coloured cylinder, slightly thinner), `Trunk` (the bark-coloured cylinder over
     it), and a crown.
   - Add a truck model named `Truck_<yourUserId>` with a part named `Bed`, and a button that fires the `Ship` remote.
6. **Play with two players.** In Studio, go to **Test > Clients and Servers > 2 players**:
   - Peel bark, carry it, ship it.
   - Check that the other window sees the bark come off.
   - Check that money saves when you stop and start again.
7. **Then follow the phases below**, one at a time.

You can run the logic tests any time without Roblox: `luau tests/run.luau` in `roblox/`. The Luau command-line tools
are on [github.com/luau-lang/luau/releases](https://github.com/luau-lang/luau/releases).

## The decisions that make it work on Roblox

### 1. The server decides everything
Roblox players can run cheats on their own client. So the client only ever *asks*:
- "strip this tree at this point with this tool"
- "buy the hatchet"
- "ship my truck"

The server checks every request before acting:
- the arguments are the right types
- the tool is owned
- the cooldown has passed
- the hit point is within reach

Money, items and the bark grids exist only on the server. An item's value is an attribute the server sets when it
creates the part, so a client can't change it. (`TreeService.onStrip`, `EconomyService.ship`)

### 2. Multiplayer layout: plots in a shared forest
The Godot game is single-player. On Roblox, each server holds about 6–8 players:
- **The forest is shared.** Anyone can peel any wild tree.
- **Plots:** each player claims a plot (the Godot land system already has plots) and builds there.
- **Saves:** builds are saved relative to the plot's corner, so they load onto whichever plot the player gets on the
  next server.
- **Alternative:** a personal island per player, like Islands. Each player gets their own copy of the world, which
  makes streaming harder. Recommendation: start with plots, and add a personal island later if you want.

### 3. Scale: 1 metre = 3 studs
A Roblox character is about 5 studs tall and the Godot player 1.75 m, so 1 m ≈ 3 studs. The Godot grid of 1 m
becomes a 3-stud grid. Bark panels, belts and rails all scale with it.

### 4. Trees: a byte grid on the server, merged strips on the client
In Godot, each tree is 2 layers × 16 × ~40 panels with a mesh rebuilt on every hit. On Roblox:
- **Server (`BarkGrid`):** the panels are a Luau `buffer`, about 1.3 KB per tree with no Instances. It saves as a
  run-length string; a stripped tree is about 60 characters.
- **Untouched trees:** one MeshPart trunk, the cheapest thing possible.
- **Trees near you with bark off:** each column of panels is drawn as *runs* of the same layer, one tall Part per
  run. That's about 30–50 Parts per stripped tree, made on your client only, so they cost no network traffic.
- **Far trees:** they go back to the single trunk.
- **Option to check:** if your account can use **EditableMesh** in published games, it can replace the run Parts with
  one mesh per layer. That would be even cheaper, but EditableMesh has memory limits and publishing requirements, so
  check them before relying on it.

### 5. Loose physics items: owned by the player, capped and tidied
Every bark sheet, log and barrel is an unanchored part. These are the biggest cost on Roblox. So:
- **Network ownership:** `SetNetworkOwner(player)` on what a player creates or picks up. Their client simulates it,
  so carrying feels instant.
- **A cap:** each player has a limit on loose items (`MAX_SHEETS` = 120). The oldest are tidied away. Stacks of bark
  could merge into one "bundle" part.
- **Settling:** anchor items that have rested for about 10 seconds, and unanchor them when touched or grabbed.
  Sleeping parts are cheap, but anchored parts are cheaper.
- **Collision groups:** loose items don't collide with characters, so a pile can't fling players.
- **Carrying:** an `AlignPosition` + `AlignOrientation` pair attached to the held part, not setting its CFrame every
  frame.

### 6. Machines: anchored, ticked, never per frame
- **Machines:** anchored Models. Power is solved by `PowerGrid` 10 times a second on the server. Each machine gets a
  `Powered` attribute, written only when it changes, because every write is network traffic.
- **Conveyors:** an anchored belt part with `AssemblyLinearVelocity` carries whatever sits on it. That's Roblox's
  built-in trick, with no script per item.
- **Hoppers:** checked with `GetPartBoundsInBox` every 0.25 s, not with `Touched` events.
- **Mesh merging:** the Godot `LowPoly.bake` work maps directly. Each machine should be one or two MeshParts, not
  twenty Parts.

### 7. Carts and drones: anchored and moved in steps
Physics vehicles are expensive and jittery in multiplayer.
- **Carts:** the server moves them one rail square at a time with `PivotTo` (the Godot carts already move this way).
  Clients smooth the motion.
- **Drones:** the server moves them at 10 Hz, and clients interpolate between positions.

### 8. Saves: one compact record per player
- **DataStore:** `DataService` keeps one session-locked record per player, autosaved every 60 s and on leave and
  shutdown. For the real game, use the community **ProfileStore** module, which handles more edge cases.
- **Builds:** compact arrays `{id, x, y, z, yaw, extra}` relative to the plot, not objects. A DataStore key holds up to
  4 MB.
- **Version field:** each record carries a version, so you can migrate old saves.
- **Write limits:** never save on every action. Roblox limits how often you can write.

### 9. Sound and music: uploaded files, not code
Roblox can't generate sound from code the way the Godot game does. You need audio files:
- **Sounds:** record or make chops, clinks and thuds, and upload them. Uploading audio has a monthly free allowance.
- **Music:** use tracks from the Creator Store's licensed music library. Don't upload music you don't own.

### 10. Models: export the Godot models instead of remaking them
Godot builds every model from code. Roblox Studio's 3D Importer reads `.glb`, so **this is already done**:
- **Where they are:** `roblox/models/` holds all 116 models (every machine, decoration and tool) as `.glb` files,
  already merged into a few meshes each.
- **Importing:** **File > Import 3D** in Studio, with the scale set so 1 m = 3 studs.
- **After the Godot game changes:** run `godot --headless --path . res://tools/ExportModels.tscn` to write them again.
- **What doesn't export:** parts that move (arms, belt slats, drone rotors) come in as separate meshes inside each
  model, so the Roblox scripts can animate them.

### 11. Mobile
- **Controls:** Roblox gives a thumbstick and a jump button. `InputController` adds big on-screen buttons for Swing,
  Grab, Build and Turn through `ContextActionService`, so every action has a touch button automatically.
- **Camera:** third person by default on phones, with a crosshair in the middle of the screen. All aiming uses the
  screen centre (`ToolController`), so it's the same on every device. Players on a PC can still zoom in to first
  person.
- **UI:**
  - **Touch targets:** at least 44 px, so buttons are easy to hit.
  - **Scaling:** `UIScale` with `AutomaticSize`.
  - **Safe area:** respect notches with `ScreenInsets`.
  - **Text:** never smaller than 14 px.
- **Lighter settings:** a phone is the weakest device you need to support:
  - **Draw range:** `DETAIL_RANGE` and the streaming radius come down on phones.
  - **Shadows:** turned off on small parts.
  - **Particles:** fewer of them.

### 12. Console (Xbox / PlayStation)
- **Controls:** everything must work with a controller. `InputController` already binds:

  | Action | Button |
  |---|---|
  | Swing | R2 |
  | Grab | X |
  | Build | Y |
  | Turn | L1 |
  | Switch tools | D-pad |

- **Menus:** they need a selection highlight and must work with the D-pad (`GuiService.SelectedObject`). Nothing can
  rely on hovering with a mouse.
- **Text size:** large enough to read from across a room.
- **Console rules:** no links to outside websites (so the feedback link has to go), and the experience questionnaire
  must be filled in. Turn on the console device in the experience's settings on the Creator Dashboard. Roblox's rules
  for which experiences can appear on console change, so check the current requirements when you get there.

### 13. Performance budgets to hold to
These targets protect phones:
- **Streaming:** `StreamingEnabled` with a target radius of about 256–512 studs.
  - The cabin, truck and plot model use `ModelStreamingMode = Persistent`.
  - Machines use `Atomic`, so they stream in whole.
- **Instance count:** keep it to a few tens of thousands near the player.
- **Wasted work:** set `CanTouch` and `CanQuery` to false on decoration, and `CastShadow` to false on small parts.
- **No per-frame loops:** use timers like the services do (power 10 Hz, oil 1 Hz, cork 0.2 Hz).
- **Remote traffic:**
  - Clients send at most about 10 events a second.
  - Effects go over `UnreliableRemoteEvent`.
  - Bark changes are batched per tree.
- **Measuring:** wrap heavy code in `debug.profilebegin` (the power tick does) and measure with the MicroProfiler and
  Script Profiler on a real phone.

### 14. Safety rules that matter here
- **Names you type in:** the company sign lets you type a name. On Roblox, any text one player types that others
  see must go through `TextService:FilterStringAsync`, or the game can be taken down.
- **Price:** the game stays free with no game passes, as you asked.

## Oil on Roblox

Oil works the same as in the Godot game (added there today too):
- **Finding oil:** pockets underground (`OilField`, a deterministic noise field: most ground has none, a few pockets
  are rich). The ore detector hums low over them.
- **Oil pump:** a pumpjack built over a pocket. While powered, it fills barrels at a rate set by the richness
  (`OilService`).
- **Refinery:** one barrel becomes a fuel can and a plastic sheet.
- **Uses:**
  - Fuel runs a generator for 4 minutes. Oil barrels burn too, for less.
  - Plastic goes into the assembler for lawn chairs and buckets.
  - Barrels, fuel and plastic all sell.
- **Ideas for later:**
  - fuel for vehicles (a fuel truck, the minecart's engine)
  - pipes from pump to refinery
  - asphalt for a road that makes the truck faster

## Godot to Roblox: where each part goes

| Godot (`scripts/`) | Roblox (`roblox/src/`) | Status |
|---|---|---|
| `ForestTree.gd` (panels, species) | `shared/BarkGrid`, `shared/Config.Species`, `server/TreeService`, `client/TreeVisuals` | started, logic tested |
| `Chip.gd`, `Truck.gd`, `Game.gd` (money) | `server/EconomyService` | started |
| `Game.gd` save/load | `server/DataService` | started |
| `Circuit.gd`, `Machine.gd` | `shared/PowerGrid`, `server/MachineService` | started, logic tested |
| `Mining.gd` oil, `OilPump.gd`, refinery | `shared/OilField`, `server/OilService`, `Config.Refinery` | started, logic tested |
| `Player.gd` input | `client/InputController`, `client/ToolController` | started |
| `Builds.gd`, `Builder.gd`, `Blueprint.gd` | `server/BuildService`, `client/BuildController` | to do (phase 2) |
| `ShopUI.gd`, `Hud.gd`, `Guide.gd` | `client/Ui/*` | to do (phase 1–2) |
| `Conveyor.gd`, `Processor.gd`, `Grabber.gd`... | `server/Machines/*` | to do (phase 3) |
| `Rail.gd`, `Minecart.gd`, `Drone.gd` | `server/Vehicles/*` | to do (phase 5) |
| `Sfx.gd` (sound made by code) | uploaded audio + `client/Sound` | to do |
| tests (`tests/*.gd`) | `roblox/tests/run.luau` + play tests in Studio | started |

## Phases

| Phase | What | Rough size |
|---|---|---|
| 0 | Setup above, a test forest, the logic tests passing | a day |
| 1 | Core loop: peel bark (all species), carry, ship, the shop and tools, money saved | 1–2 weeks |
| 2 | Plots, the hammer and plans, decorations, saving builds | 1–2 weeks |
| 3 | Power, wires and sockets, belts, the production machines (sawmill, smelter, assembler) | 2–3 weeks |
| 4 | Mining and oil (pump, refinery, fuel, plastic) | 1 week |
| 5 | Rails, carts and drones | 2 weeks |
| 6 | Mobile and console pass: UI navigation, touch layout, phone performance on real devices | 1–2 weeks |
| 7 | Sounds and music, the tutorial, the guide, then publish | 1 week |

## What's in `roblox/` today

- **`default.project.json`:** the Rojo project (ReplicatedStorage.Shared, ServerScriptService.Server,
  StarterPlayerScripts.Client).
- **`src/shared/`:** pure Luau, no Roblox calls, type-checked:
  - `Config`: tools, species, products, recipes, oil
  - `BarkGrid`: bark panels in a buffer, stripping, cork regrowth, compact saving
  - `PowerGrid`: the power solver with batteries
  - `OilField`: where the oil is
  - `Economy`: values
- **`src/server/`:** `DataService` (session-locked saves), `EconomyService` (money, shop, truck), `TreeService`
  (checked stripping, bark sheets, cork regrowth), `MachineService` (10 Hz power, belts), `OilService` (pumps).
- **`src/client/`:** `InputController` (keyboard, gamepad and touch for each action), `ToolController`
  (screen-centre aiming), `TreeVisuals` (merged bark strips near you, plain trunks far away).
- **`tests/run.luau`:** 18 tests of the shared logic. Run `luau tests/run.luau`; all pass, and CI runs them on every
  push.
- **`models/`:** 116 `.glb` models exported from the Godot game, ready for Studio's 3D Importer.

**Not checked:** the server and client scripts compile, but they haven't run in Roblox, because Studio can't run in
this environment. Expect a round of small fixes the first time you connect Rojo and press Play.
