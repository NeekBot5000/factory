# Overnight session, 26 Oct 2026 (05:20-13:20 UTC, 8 hours assumed: no duration was given)

**Goal (your words):** bug fixes; QoL features "like better sounds or environment textures"; make up enough
axes, drills, saws and other items for a full game, don't implement them, and pitch the best ones at the end.


## Done

### Sound
* **Clipping fixed:** the most-played sounds (axe, chop, chop_wood) peaked at full scale and distorted into a
  harsh buzz on every swing. Every sound now goes through a soft limiter.
* **Warmer noise:** noisy sounds use low-passed noise instead of raw white noise (less hiss).
* **New:** a quiet endless breeze; footsteps that match the floor (grass/dirt, wood, stone); rock crack per
  chunk, crumble when a rock breaks, rock-drill grind, piston thunk and hiss, wire snip, a deep thump when a
  felled tree lands, and a quiet hum from running belts.
* **Positional:** pistons, the truck caller, the truck horn, belts and landing trees sound from where they are.
* **Chainsaw** has a real two-stroke engine that idles while held and revs while cutting (it used to retrigger
  a short drill sample 20 times a second); the **vacuum** sounds like rushing air (it was the truck's diesel
  engine, pitched up).
* **Impact sounds:** ore chunks clunk and logs thud when they hit something hard.
* Sounds are now built in the background after startup instead of all at once (about 200 ms less loading on
  desktop, more in a browser).
* 20 voices instead of 10, so a running drill no longer cuts other sounds off. (`scripts/Sfx.gd`)

### Environment
* **Ground detail** drawn by shader (no texture files): soft lighter/darker patches, drier yellow-green areas
  and fine grain on the grass; tiny pebbles and ruts on dirt. Low-poly shapes and colours unchanged.
* **Stone:** a weathered-granite grain with small dark pits on every rock. (`scripts/Ground.gd`)
* **Clouds:** a handful of low-poly clouds drifting slowly.

### QoL
* **Esc pause menu:** mouse sensitivity, field of view, volume, graphics (Auto or a fixed level), all saved.
  In a browser, Esc releases the mouse before the game sees it, so losing the mouse mid-play opens it too.
* **Money counter** rolls up to the new total and pops when you earn.
* **More settings:** invert mouse, head bob on/off, and an FPS counter (handy for testing on a weak laptop).
* **Shift + 1-9** picks your 10th-18th tool (there are 26 now).
* **Taking down a pillar** also takes down whatever was built on it (it used to be left floating).
* **Graphics Low/Lowest** also turn off the new ground and stone detail, to save frames on weak GPUs.

### Bugs and tests
* **New controls test** (`tests/InputTest.tscn`, in CI): every key and mouse binding through real input
  events (the old X-key bug slipped through because tests called functions directly). All controls pass.
* **Dropped tools could fall through the ground** and be lost (found because the controls test failed 1 run
  in 6). Thicker collision and continuous collision for tool items, plus a safety net that puts any loose
  item that ends up under the ground back on top.
* **Autosave hitch:** with 600 loose bark pieces a save took 27 ms and wrote 218 KB; now 13 ms and 73 KB
  (an empty world: 7 ms to 1 ms). Trees remember whether they've been touched instead of being scanned every
  save; positions round to the millimetre; bark pieces share one table of tree descriptions. Old saves load.
* **CI is stricter:** it now fails on engine errors too, not just script errors. That caught a physics
  error from the new tree-landing sound, which is fixed.
* **Long-session check:** 20 simulated minutes of chopping, felling, shipping, autosaves, regrowing rocks and
  saplings. No errors, and no leak (object count rises only with the bark lying around).
* **Stability:** every suite run 3 more times (27 runs) plus 4 extra soak seeds: all clean.

### Design
* **`docs/item-roster.md`:** a full-game roster: six categories, five price tiers, slots, candidates, and the
  16 items I'd add.

## Final summary (stopped at 06:05 UTC, about 7 hours early)

My queue and the review pass are done, and everything left needs a decision from you, so I stopped rather
than invent work. 19 commits, all pushed. All 9 test suites pass.

## Open questions (recommendation first)

1. **Which roster items to build first?** Recommendation: **Pressure Washer** (the signature satisfying
   tool), **Leaf Rake** (fixes the tedious early pickup) and **Throwing Hatchet** (reach and fun), then work
   down the list of 16 in `docs/item-roster.md`.
2. **Birdsong:** the forest has quiet bird chirps in the background (it always has). You said no animals;
   keep the chirps as atmosphere, or remove them? Recommendation: keep them; there are no birds to see.
3. **Ground and stone detail:** it's subtle on purpose. If you'd like it stronger (or gone), it's one number
   each in `scripts/Ground.gd`.
