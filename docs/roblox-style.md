# What makes a Roblox game feel high-effort, and what Timber does about it

Research done on 3 Nov 2026. The sources are listed at the bottom. Many search results were SEO filler, so only the
points that several sources agreed on, or that Roblox's own docs state, made it in.

## What's popular right now
- **Genres:** roleplay leads the all-time charts (Brookhaven). Simulators and tycoons are still huge (Pet Simulator
  99, Bee Swarm, Retail and Theme Park Tycoon 2). The breakouts of 2025–26 are simple, social loops: *Steal a
  Brainrot*, *Grow a Garden*, *Fish It*, *Sell Lemons*, and *99 Nights in the Forest*.
- **Hybrids are rising:** simulators mixed with tycoon management or RPG combat. Timber is one already: it's a
  gathering simulator that turns into a factory tycoon.
- **The closest hit to Timber is *99 Nights in the Forest*:**
  - **Gameplay:** chopping wood in forest clearings, cabins, and co-op for up to 25 players.
  - **Look:** blocky models made moody with **lighting and sound**, not detailed models.
  - **Lesson:** stylised lighting and sound do most of the work.

## What players expect from the look and feel
1. **The first 90 seconds decide everything.** Players should be *doing* the main action straight away and learn by
   doing, not by reading. Make the first action feel great (sound, animation, feedback). Aim for an "aha" moment
   within about 5 minutes, such as a first tool or first big sale.
2. **Cartoony, chunky UI is the default.**
   - **Shape:** rounded corners (8–12 px), thick outlines (`UIStroke`), bold rounded fonts.
   - **Colours and icons:** colour-coded buttons, big clear icons, little text.
   - **Layout:** a big money counter, and floating "+$" numbers when you earn.
3. **Mobile first.**
   - **Touch targets:** at least 44–48 px.
   - **Sizing:** scale-based, with an aspect-ratio constraint on panels.
   - **Placement:** action buttons at the bottom, where thumbs rest.
4. **Juice on every action.**
   - **Tools:** sound, particles, a little camera kick, and a tween on whatever you touched.
   - **Numbers:** they count up instead of jumping.
   - **Buttons:** they squash when pressed.
5. **Roblox-native controls.** Tools sit in the **standard backpack/hotbar** (1–9 keys, tap on mobile) and swing with
   the standard slash animation. Players already know how these work.
6. **A clear next goal on screen at all times.** That means a quest pill ("Peel 5 bark sheets 2/5") and a marker
   over where to go.

## What Timber's Roblox version does now: the Godot game, not a generic Roblox game
The research above shaped an earlier pass, which used a chunky Roblox-style UI, a hotbar, quest pills and prompts.
After that, the brief changed to *make it exactly like the Godot version*, so the Roblox port now copies the Godot
game's own design, piece by piece:

| Godot (file) | Roblox now |
|---|---|
| First person, 75° view, no mouse pointer (Player.gd) | `LockFirstPerson`, field of view 75, the pointer hidden. The HUD's crosshair is the only aim mark |
| The arm in view: red sleeve, plaid cuffs, flat karate hand or a fist on the tool, swing shapes per tool (Player.gd) | `ViewModel`: built from the same measurements; it chops, karate-chops, sweeps (double-bit, forehand then backhand) or slams (labrys, greataxe), sways as you walk and rises on equip |
| Swing timing: the blade lands partway through (impact), the double-bit twice; sounds by outcome (Player.gd) | `ToolController`: the same cooldowns, impact points and reach. Bark → chop/axe (higher for the inner layer), bare wood → chop_wood, ground → thud with dirt, a bare-handed miss → whoosh |
| HUD: money top right (counts up, pops), health bottom left only when hurt, tool bar with icons and keys, hint line, toasts, crosshair ring sized to the bark circle (Hud.gd) | `Hud`: the same layout, colours, fonts (Nunito, Fredoka) and behaviour. Roblox's player list, backpack and health bar are off |
| Getting started panel, top left (Tutorial.gd) | `TutorialService` plus the HUD panel: take the hatchet, peel, load the truck, send it, save up, buy |
| E uses / grabs, Q drops a tool on the ground, 1-9 and the wheel pick tools (Player.gd) | Same keys. No Roblox Tools or backpack, and no ProximityPrompts |
| The truck: "[E] ship $X", horn, drives to the mill, pays on arrival, comes back (Truck.gd) | `EconomyService`: the same, with the engine running on the road and the load's value on its sign |
| Health: bare hands hurt 6 a hit, it regrows after 3 s at 5 a second, "ouch" under 40, at 0 you faint and wake at the start (Player.gd) | A `Health` script replaces Roblox's, and fainting fades the screen to black and back |
| Sounds: all made by Sfx.gd, footsteps by surface every 0.7 m (0.9 sprinting) | The same sounds from the uploaded sheet. Roblox's own character sounds (footsteps, jump, landing) are replaced with nothing |
| Walk 4.2 m/s, sprint 6.8 (Shift), jump 4.6 m/s | 12.6 and 20.4 studs a second (3 studs to the metre), jump height matched |
| TimberMart on the computer (ShopUI.gd) | The same layout and colours, opened with E on the computer in the cabin |

## What popular Roblox games do, and what Timber does about it (5 Nov 2026)
The Godot game is the core; these are the Roblox habits added around it, chosen because the research (sources
below, and the 2026 retention write-ups: daily hooks, timed events, social features and mobile first come up again
and again) agrees they keep players coming back:
- **Mobile first:** every action has a touch button (Swing, Use, Drop, Phone, Run; Turn and Take down with the
  hammer), the tool bar switches tools with a tap, hints name the buttons, phones draw bark over a shorter range,
  and the engine check draws the HUD and the phone at a phone's size.
- **A reason to come back tomorrow:** a daily reward that grows each day in a row ($15 up to $105), from the second
  day, so the first day still starts at $0 as in Godot.
- **Timed server events:** the golden tree, every 15 minutes, with 5x bark, announced to the server.
- **Codes:** typed into the TimberPhone, each paying once (`Config.Codes`).
- **Leaderboards:** who's on this server and the all-time best, on the TimberPhone (Roblox's own player list would
  cover the money counter and take the phone's Tab key).
- **Badges** for the trophies and for playing, once they're made on the Creator Dashboard (`Config.Badges`).
- **Inviting friends** from the TimberPhone.
Not done, on purpose: game passes and paid items (a decision for you), a floating marker over the next goal (no
floating 3D text in this game), and anything that changes the Godot game's own loop.

## The scripted playtest
`roblox/tests/lune/playtest.luau` plays the game through the real server scripts, with no Studio needed, and CI
runs it on every push (210 checks). `roblox/tests/lune/client.luau` runs the client scripts the same way (38 checks).
It covers:
- **A new player's first minutes:** take the hatchet, peel, carry, ship, save up, then buy the Double-Bit Axe.
- **Every tool:** the axes, saws, drills, planer, washer, shears, vacuums and blower, rake, watering can, scale,
  pickaxes, sledge, rock and core drills, detector and dynamite.
- **Building:** plans filled with dropped materials, land plots, take-down, and builds that do things (campfire,
  compost, catapult, hoop, hammock, baskets).
- **Machines:** power (crank, windmill, generator, battery), switches and logic, sensors, belts, the sawmill,
  smelter, kiln, chipper, assembler, oil pump and refinery, crate, planter, sprinkler, grabber, piston, sorter,
  wireless, feller, drill rig, charger, rotator (and pistons clamping things to it), rails and minecarts, and drones.
- **Cheating:** buying what you can't afford, swinging from too far away or with a tool that isn't in your hand,
  spamming 20 swings at once, taking someone else's dropped tool, and using things from across the map.
- **Saves:** money, tools, land, builds, machine state, wires and laid track survive leaving and rejoining on another
  server, and a second server can't load a save that's still in use. The world (stumps, logs, grown trees) is saved
  by the server.

## What's still different from the Godot game
Everything in the Godot game now has a Roblox version, built from Godot's own numbers and meshes. These are the
known gaps and differences:
- **Studio-only checks:** the playtests run the real scripts in Lune, without Roblox's physics or renderer. These
  still need a look in Studio:
  - how the imported meshes look in Roblox's lighting;
  - how things fall, slide (the chute) and fly (catapult, dynamite);
  - whether carts and drones move smoothly on screen (the server moves them 20 times a second);
  - the feel of the arm.
- **Multiplayer choices:** land, builds, machines, track and trophies belong to each player and are saved with them.
  The forest and rocks are shared by everyone on a server.
- **Old groundwork:** `MachineService` and `OilService` (with `PowerGrid` and `OilField`) were the first machine
  scripts. The real machines now live in `CircuitService`, `ProductionService` and `FactoryService`. The old two only
  drive models tagged `Machine` or `OilPump`, which nothing in the game makes any more, so they could be removed
  along with their old playtest block.

## Sources
- [Exitlag: Roblox genres in 2026](https://www.exitlag.com/blog/roblox-game-genres-and-popularity/)
- [Statista: most visited Roblox games](https://www.statista.com/statistics/1220905/roblox-most-visited-games)
- [RoWatcher: most popular games by live players](https://rowatcher.com/news/the-most-popular-roblox-games-right-now-ranked-by-live-players)
- [RoWatcher: genre opportunity map 2026](https://rowatcher.com/news/roblox-genre-opportunity-map-2026-where-smart-developers-are-building-next)
- [creation.dev: Roblox UI best practices](https://www.creation.dev/blog/roblox-ui-design-best-practices)
- [DevForum: how to recreate such UI style](https://devforum.roblox.com/t/how-to-recreate-such-ui-style/1943553)
- [RoWatcher: your first 90 seconds](https://rowatcher.com/news/your-first-90-seconds-are-destroying-roblox-retention)
- [RoWatcher: onboarding in 90 seconds](https://rowatcher.com/news/roblox-onboarding-in-90-seconds-or-your-game-is-already-dead)
- [Roblox docs: engagement analytics](https://create.roblox.com/docs/production/analytics/engagement)
- [DevForum: real game feel on Roblox](https://devforum.roblox.com/t/real-game-feel-and-execution-on-roblox/4199862)
- [Wikipedia: list of Roblox games](https://en.wikipedia.org/wiki/List_of_Roblox_games)
- [games.gg: 99 Nights in the Forest](https://games.gg/zh-Hant/99-nights-in-the-forest/)
