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

## Livestock and wildlife (chosen 26 Oct, for later)

Animals are physical like everything else, and they plug into the leaf and sapling loops. **Leaf eaters always
drop something when they eat** (you asked for this): every few leaves a goat or sheep eats, it drops a manure
lump, plus a tuft of wool (sheep) or fills its udder for milk (goat). Feeding them is what makes them produce.

| Animal | What it does | Ties into |
|---|---|---|
| **Goats** | Eat leaves dropped in their pen's trough (and nibble grass); give milk you collect in a bucket and sell | The leaf pile finally has a use |
| **Sheep** | Eat leaves too; grow wool you clip off with the **pruning shears** (a second use for them) and sell by the bundle | Shears, truck |
| **Manure** | Every fed animal drops manure now and then (a physical lump). Drop it by a rooted sapling and it grows ~3x faster; drop it in the compost pile and saplings come quicker | Saplings, compost, replanting |
| **Bees** | A hive (hammer build) makes saplings within ~10 m grow faster, and fills jars of honey to sell | Replanting |
| **Chickens** | Peck around the pen, lay eggs to sell, and add a little manure | Pen, truck |
| **Beavers** (wild) | Live by the river (Phase 3) and gnaw down nearby trees on their own; free logs if you get there first, and later a dam for the water wheel | River, logs |
| **Deer and birds** (wild) | Ambient life: deer graze and bolt when you come close; birds burst out of a crown when you chop its tree | Atmosphere |

Suggested build order: pen + trough (hammer), goats, manure as fertiliser, then sheep, bees, chickens; wildlife
once the river exists. Animals come from TimberMart in a crate like tools do.

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
