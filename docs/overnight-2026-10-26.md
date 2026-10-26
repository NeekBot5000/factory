# Overnight session, 26 Oct 2026 (05:20-13:20 UTC, 8 hours assumed: no duration was given)

**Goal (your words):** bug fixes; QoL features "like better sounds or environment textures"; make up enough
axes, drills, saws and other items for a full game, don't implement them, and pitch the best ones at the end.

*Checkpoint, updated as work lands.*

## Done so far

### Sound
* **Clipping fixed:** the most-played sounds (axe, chop, chop_wood) peaked at full scale and distorted into a
  harsh buzz on every swing. Every sound now goes through a soft limiter.
* **Warmer noise:** noisy sounds use low-passed noise instead of raw white noise (less hiss).
* **New:** a quiet endless breeze; footsteps that match the floor (grass/dirt, wood, stone); rock crack per
  chunk, crumble when a rock breaks, rock-drill grind, piston thunk and hiss, wire snip, a deep thump when a
  felled tree lands, and a quiet hum from running belts.
* **Positional:** pistons, the truck caller, the truck horn, belts and landing trees sound from where they are.
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

### Bugs and tests
* **New controls test** (`tests/InputTest.tscn`, in CI): every key and mouse binding through real input
  events (the old X-key bug slipped through because tests called functions directly). All controls pass.

### Design
* **`docs/item-roster.md`:** a full-game roster: six categories, five price tiers, slots, candidates, and the
  16 items I'd add.
