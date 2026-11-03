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

## What Timber's Roblox version now does
| Expectation | In Timber |
|---|---|
| Doing within 90 s | You spawn facing the trees with a quest pill: peel → carry → ship → buy a hatchet. A bouncing marker shows where to go next |
| Great first action | Each hit: bark-chip particles, a chop sound, a slash animation, a small camera kick, the tree shakes, and a sheet pops off |
| Chunky UI | `UiKit`: one look everywhere. Fredoka One font, thick dark outlines, rounded corners, warm wood and cream colours with a green accent, buttons that squash when pressed |
| Money feel | A big money counter at the top that counts up, a coin pop, and floating "+$12.40" numbers when you sell |
| Native tools | Bought tools are real Roblox **Tools** in your hotbar, each with its own model, kept when you respawn |
| Shop | A **TimberMart** stall. Its shop window has a turning 3D preview of each tool, its stats and its price, and a big Buy button. Hold the stall's prompt to open it, on any device |
| Lighting | Future lighting with atmosphere haze, gentle bloom, sun rays and warm colour grading |
| World | Low-poly trees with layered crowns in each species' colours, rocks, a spawn clearing, a log truck and the shop stall |
| Mobile | Touch buttons for Swing, Grab and Build at the bottom right, scale-based UI, and a shop panel that fits a phone |

## The scripted playtest
`roblox/tests/lune/playtest.luau` plays a first session through the real server scripts, with no Studio needed, and
CI runs it on every push. It covers 44 checks:
- **A new player's first minutes:** peel, carry, ship, then buy the hatchet. It got there in about two minutes of
  work.
- **Cheating:** buying what you can't afford, swinging from too far away or with a tool you don't own, spamming 20
  swings at once, and selling someone else's bark.
- **Saves:** they survive leaving and rejoining on another server, and a second server can't load a save that's still
  in use.
- **Machines and oil:** power, levers and an oil pump filling a barrel.

What it caught and what changed:
- **Bare hands could knock a new player out in under a minute.** Six swings took 36 of 100 health. Now bare-handed
  peeling never takes you below 30 health, and a one-time tip says why it hurts and what helps.
- **Every goal step works end to end,** including the rewards, which pay for the hatchet sooner.

## Not done yet (on purpose)
- **Uploaded audio:** the game uses sounds that ship with Roblox (like the classic sword's) until real chop, clink and
  coin sounds are uploaded. Those sound files haven't been checked in Studio; if one is missing it just stays silent.
- **The client side** (UI, shop window, effects) compiles, but only Studio can show it. The playtest drives the
  server, the way a client would.
- **Day/night, co-op events, daily rewards:** later. Each needs the core loop to be fun first.

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
