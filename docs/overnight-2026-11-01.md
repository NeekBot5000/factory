GOAL: "test more things and do more things to publish a finished game on itch"
STARTED: 03:34 UTC   ENDS: 11:34 UTC

QUEUE
[x] 1. itch-ready packaging in CI (web zip w/ index.html at root, win zip, linux zip) + docs/itch-release.md upload steps
[x] 2. Local web export + boot in headless Chromium (playwright): no console errors, screenshot
[x] 3. Credits + licenses (Godot MIT, fonts OFL), version number on title, CHANGELOG
[x] 4. Quit button (desktop only), fullscreen toggle (F11 + settings)
[x] 5. Save robustness: corrupt/empty/old save files don't crash; test
[x] 6. Save/load roundtrip for carts, drones, rails, curves, ports, deck machines (SaveTest)
[x] 7. Performance: big-factory benchmark, find + fix hotspots
[x] 8. In-game Guide (computer/phone) explaining machines & systems
[x] 9. Progression/balance audit from a fresh game; fix walls
[x] 10. itch page copy, 5 screenshots, 630x500 cover in docs/itch/
[x] 11. Edge-case bug sweep (take down carts/drones with cells, wires to deleted machines, etc.)
[x] 12. Web input: pointer lock / click-to-play / focus loss pause
[x] 13. README update for rails/drones/ports; review tonight's diff

DONE
[x] Web export boots in headless Chromium, no errors; found NEW GAME BUG (title reappears, old world kept: reset() saved via scene savers). Fixed, SaveTest covers it — Game.gd, Main.gd — 03:40
[x] SaveTest: carts/deck/cell, drones dials, rails+curve, socket cell, drilled spots roundtrip — 03:41
[x] Credits.gd (Godot MIT + fonts), v1.0.0 on title, Quit (desktop), Quit to title, Fullscreen + F11, hand hidden on title — 03:50
[x] CI: Timber-itch artifact (web/windows/linux zips + README.txt, THIRD-PARTY.txt, LICENSES) — dist/, build.yml; CHANGELOG.md — 03:55
[x] Saves: temp file + swap + .bak fallback; wrong-typed values default; fullscreen remembered; verified rename works in browser IndexedDB — Game.gd, SaveTest — 04:00
[x] Perf: CPU fine (2.7 ms/frame big factory). Draw calls 33.8k -> 12.2k: LowPoly.bake merges machine parts into vertex-colour surfaces, sockets/plugs baked, wire cable one mesh, no shadows on slats/borders — LowPoly.gd, Builds.gd, Wire.gd, Machine.gd, Machines.gd, tests/PerfBench — 04:25
[x] Field Guide (12 topics) in Esc menu; tutorial step 7 text fixed (box opens with click, not E) — Guide.gd, Tutorial.gd — 04:27
[x] Balance probe: $/min per axe; Combo Axe was 2x the $900 greataxe for $250 -> capped 4 hits, $550 — Player.gd, Tools.gd — 04:31
[x] itch kit: 6 screenshots, 630x500 cover, page text + upload guide — docs/itch/, tests/StoreShots, tools/make_cover.py — 04:36
[x] Pause on focus loss; tests for take-down of carts/drones/socketed machines — Main.gd, FactoryTest — 04:42
[x] README updated (v1.0, rails/drones/sockets, menus, releasing) — 04:45
[x] Timber icon + loading splash — icon.svg, assets/splash.png, project.godot — 04:39
[x] Review pass: re-read tonight's diff; Guide resize wording fixed; itch AI-disclosure + cover size verified with sources — 04:44
[x] Browser round trip: New Game, Esc, Guide, Fullscreen (really fullscreen), Quit to title -> Continue — all work — 04:50
[x] Sweep test: all 72 builds built/hinted/used/saved/taken down/loaded back — FactoryTest — 04:47
[x] Soak test covers cells on sockets, rails, wireless/dials; 8 seeds clean — SoakTest — 04:50
[x] Keys by physical position (AZERTY/QWERTZ) incl. browser check; InputTest AZERTY case — Player.gd, BuildMenu.gd — 04:53
[x] New game looks down at the hatchet; hatchet no longer sticks out through the block side; TutorialTest covers — Main.gd — 04:57
[x] CI smoke-tests the exported Linux binary (600 frames, no script errors) — build.yml — 04:57
[x] Menus checked at 4:3 and ultrawide; Guide Controls page — 05:02

PARKED
