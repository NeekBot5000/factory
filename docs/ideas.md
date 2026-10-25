# Ideas backlog (prioritised, 25 Oct 2026)

Ranked by how much each helps a new player stick around (see `founder-assessment.md`) versus how much work
and risk it adds. "S/M/L" is rough size.

## Do next: makes the first 10 minutes work

*Decided: no goals list or tutorial hints. Players learn the game by exploring. The items below only make what's
already there easier to read; none of them tells you what to do.*

| Idea | Why | Size |
|---|---|---|
| **First sale celebration**: the truck honks and the money ticks up big | Makes the bark-to-money moment feel good | S |
| **Truck shows its load value while you carry bark toward it** (already shows when parked; make it visible from further away) | Shows the reward before the player commits | S |
| **Graphics quality toggle** (shadows, grass density, view distance) | School laptops and Chromebooks are the likely audience | S |

## Good additions: deepen what's there

| Idea | Why | Size |
|---|---|---|
| **Tree species with different value** (birch cheap/fast, pine medium, a rare golden or red tree deep in the woods) | Gives a reason to explore and a "jackpot" moment | M |
| **Bark quality grades**: a clean, whole sheet sells for more than shredded bits | Rewards skilful stripping, the game's unique hook | M |
| **Daily mill order**: "the mill wants 40 inner bark today, +50% price" | A reason to come back tomorrow (retention) | M |
| **Hand cart / wheelbarrow** (cheaper than the vacuums) | Carrying is the real bottleneck in the early game | M |
| **Water wheel / generator** (Phase 3) | Cranks need re-winding, so a line can't run on its own yet; this unlocks real automation | M |
| **Auto-stripper with an inserted axe** (Phase 2, you asked for it) | The automation payoff for the core hook | M |
| **Sensor + filter + splitter** (Phase 2) | Makes conveyor lines into actual logic | M |
| Selected vehicles: mining crawler, forwarder, rail cart with baskets | Big "wow" items for late game | L each |

*Decided 26 Oct: no animals or wildlife. Not the vibe of the game.*

## Small, hyper-specific helpers (you liked these)

Bark catcher net under a tree; tool rack that holds dropped tools; signal lamp and siren for machines; sprinkler
that speeds up nearby saplings; a doorbell button on the truck caller; a "last sale" receipt on the phone; a log
measuring tape that shows a log's value when you aim at it with the hammer.

## Consider cutting or parking

| Thing | Why | Recommendation |
|---|---|---|
| **Basketball + hoop** | Fun, but unrelated to the core loop, and the most fiddly physics in the game | Keep (it works and is tested), but don't extend it |
| **Catapult** | Works, but has no use in the economy | Keep as a toy; maybe make it launch logs onto the truck bed |
| **Inner Gouge** | Earns nothing on its own (needs outer bark removed first) | Kept with a clear hint; could be merged into the scraper as a "both layers" upgrade |
| **Bark Scraper** | Only takes outer bark, so it can't clear a tree alone | Fine as a niche tool at its new $400 price |
| **24 tools at 1 hour of play** | Too many choices too early | Gate the top tier behind the first truck sale, or show only 6-8 tools until you've earned $500 |

## Balance notes

* Tool speeds were measured tonight with `tests/Bench.tscn` (dollars per minute to clear 75% of the same tree).
  After the rebalance, speed mostly rises with price (see the overnight report). Re-run the bench whenever a tool
  is added or changed.
* Machines are priced in materials. A full conveyor line costs little stone but needs copper, which comes mostly
  from the quarry. Rocks now regrow every 75 s, so ore can't run out for good.
* The crank stores 15 s per wind (max 2 minutes). Until a generator exists, automation needs you nearby. That's
  OK as a first step, but Phase 3 power should come before many more Phase 2 machines.
* **Iron** is now needed by the advanced machines (piston 3, rotator 2, truck caller 2), which gives the Steel
  Pickaxe and the Steel Core Drill a purpose. Mining tiers: pickaxe -> rock drill (stone and copper, about 2x)
  -> steel pickaxe / steel core drill (iron).
