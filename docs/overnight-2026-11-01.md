# Overnight session, 1 Nov 2026

**Goal (your words):** "test more things and do more things to publish a finished game on itch"

**Timing:** started 03:34 UTC, planned to 11:34. The queue, a review pass and two extra rounds of testing were done
by about 05:20 UTC, so I stopped there instead of inventing new features. Everything is committed and pushed; every CI
run tonight was green.

## Bugs found and fixed

| Bug | How it was found | Fix |
|---|---|---|
| **New Game didn't start a new game.** It showed the title again, and the old world came back | Playing the web build in a headless browser | `Game.reset()` saved through the scene's savers, writing the old world straight back. They're cleared first now, and New Game skips the title once. `SaveTest` covers it |
| A save cut off half way (tab closed mid-write) would lose the world | Review | Saves go to a temp file and swap in; the old save is kept as `.bak` and loaded if the main one is broken |
| A save with the wrong kind of values could stop loading | Review | Every value is type-checked and falls back to its default |
| The fullscreen setting was never remembered | Writing the save test | Added to the default settings |
| Tutorial step 7 said "open the box with E" (E picks it up; clicking opens it) | Checking the guide against the code | Text fixed |
| The hatchet in the chopping block stuck out through its side | Looking at a fresh start | Blade now buried in the top, handle up and out |
| A new player started looking over the hatchet, which sat just below the screen | Same | A new game starts looking down at it |
| Crates sometimes didn't empty: ore scraped to a stop inside (1 in 15 test runs) | A test failure, then 30-trial repros | A hop and a push towards the middle of the door: 0 failures in 90 trials |
| WASD sat in odd places on AZERTY/QWERTZ keyboards | Review for itch players | Keys go by position, not label (checked in the browser too) |
| The web export contained stray `.import` files | Reading the CI log | `build/.gdignore` |
| The Combo Axe ($250) out-earned the $900 Greataxe by more than 2 to 1 | A $/minute probe for every axe | Capped at 4 hits and $550 |

## Release work

- **Credits screen** (title and pause): the Godot licence, the font credits, and the engine's third-party list.
- **Version 1.0.0** on the title screen, `CHANGELOG.md`.
- **Quit** on desktop builds (not on web, where it can't work), **Quit to title** in the pause menu.
- **Fullscreen** toggle in settings and on F11.
- **Field Guide** in the pause menu: 13 topics (controls, tools, building, power, logic, making things, moving
  things, farming, mining, rails, drones, growing). It explains what things do, not what to build.
- **Pause when the window loses focus** (alt-tab, another browser tab).
- **New icon** (a log end and an axe) and a **loading splash**. The Windows `.exe` gets the icon and file details.
  The Windows export step passed, but I couldn't see the icon on a Windows machine.
- **itch.io kit** in `docs/itch/`:
  - six 1280x720 screenshots and a 630x500 cover
  - the page text, embed settings and tags
  - the AI-disclosure guidance (with sources)
  - step-by-step upload instructions
- **CI packaging:** every push now builds the `Timber-itch` artifact: web, Windows and Linux zips, each with a player
  README (controls) and the licence files.
- **`tools/push_itch.sh`** pushes later updates with butler.
- **`tools/run_tests.sh`** runs every suite locally the way CI judges them.
- **README** brought up to date.

## Performance

- **CPU:** a big test factory (240 belts, 120 wired machines, 300 ore chunks, carts and drones) takes about 2.7 ms
  per frame, well under budget.
- **Draw calls:** the real problem was the graphics card's load. That same factory needed **33,800 draw calls**
  (about 85 per conveyor belt). It's down to **about 12,200**:
  - `LowPoly.bake` merges each finished machine's still parts into one or two vertex-coloured surfaces.
  - Sockets and wire plugs are merged the same way, and each wire is a single mesh.
  - Paper-thin parts no longer cast shadows.
  - I compared screenshots before and after: everything looks the same.
- **Memory:** flat over 3 minutes of a running factory, so no leaks.
- `tests/PerfBench` re-measures all of this.

## Testing added tonight

- **Browser** (headless Chromium, tonight's web export):
  - boots with no errors, New Game, walking, Esc menu, Guide, Fullscreen (really fullscreen), Quit to title and back
    to Continue
  - saves land in the browser's storage
  - all of it also works inside a **cross-origin iframe**, the way itch embeds games
- **New suites:**
  - **Sweep:** all 72 builds are built, read, used, saved and reloaded, taken down, and loaded back from a save.
  - **Shop:** every shop item can be bought and delivered.
  - **Saves:** carts, drones, rails, curves, cells in sockets and drilled spots survive a restart; damaged saves
    still load.
  - **Take-downs:** taking down carts, drones and machines with cells in them gives back what was inside.
  - **AZERTY:** walking works with the key in W's place.
  - **Fresh start:** a new game starts looking down at the hatchet, and E takes it.
- **CI smoke test of the shipped Linux game:** CI starts the real exported program and runs it for 600 frames.
- **Soak test:** now also drops cells on sockets, lays and turns rails, and changes channels. 8 seeds clean.
- **Repeat runs:** the whole suite ran 4 more times back to back with no failures.

## Decisions waiting on you (my recommendation first)

1. **Your name in the credits and on the page.** It says "Made by NeekBot5000, with Claude" (`MADE_BY` in
   `scripts/Credits.gd`, plus `dist/README.txt` and `docs/itch/README.md`). Recommendation: keep the handle unless you
   want your real name on it.
2. **The feedback link** in the pause menu points at GitHub issues, which need a GitHub account. Recommendation: once
   the itch page exists, point `FEEDBACK_URL` in `scripts/SettingsMenu.gd` at its comments.
3. **Price.** Recommendation: free, with optional donations ("you want people playing, not money").
4. **AI disclosure** on itch: answer Yes (code and text). Ticking graphics and sound too is the cautious choice,
   though those are made by the game's own code. Recommendation: tick all four; it costs nothing.
5. **Labrys and Greataxe look weak for their price** (about $565 and $763 a minute of peeling, against $867 for the
   $400 Scraper). I left them alone because they're meant to feel different. Recommendation: a small radius buff,
   if you agree.
6. **Rebindable keys and gamepad support** aren't there. Physical-position keys cover other keyboard layouts.
   Recommendation: wait for player feedback.

## Not done / not verified

- I couldn't open the live GitHub Pages site from here (the sandbox's proxy blocks github.io). The deploy job reported
  success.
- I couldn't run the Windows build. Its icon and file details were set, and the export passed.
- Nothing was uploaded to itch.io. That's yours to do from `docs/itch/README.md`.
