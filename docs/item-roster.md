# Item roster for a full game (design only, nothing here is implemented yet)

**Goal:** enough tool variety that every price tier has something new to try, and every tool *plays*
differently: a new shape of strip, a new reach, a new rhythm, a new way of moving things. No recolours.

**Current roster:** 26 tools plus the phone (not counting bare hands). **Target for a full game:** about 40-45 across six
categories and five tiers. Below, each category has *slots* (roles). Existing tools fill some; the rest are
candidates, with the one I'd pick marked **★**.

Sizes say how much new code each needs, judged against what the game can already do. The tool table already
supports radius, cooldown, multi-hit, layers, through-both-layers, rings, grids, auto-fire, hold tools,
vacuum cones, saw speed and bucking, so many new tools are mostly data plus a model:
**S** = mostly a new tools-table entry + model, **M** = a new behaviour on top of an existing one, **L** = a new system.

## Tiers (money you'd have when you can afford it)

| Tier | Price band | Feel |
|---|---|---|
| T0 Starter | $0-50 | hands, first hatchet |
| T1 Early | $50-500 | first specialised tools, first saw |
| T2 Mid | $500-2,500 | power tools, mining, first machines |
| T3 Late | $2,500-8,000 | automation, big strippers, iron tier |
| T4 Endgame | $8,000-30,000 | showpiece tools that change how you play |

---

## 1. Axes (swing to strip): 10 slots

| Slot | Tier | Filled by | Candidates for empty slots |
|---|---|---|---|
| Starter | T0 | Bare Hands, Trusty Hatchet | n/a |
| Two-hit | T1 | Double-Bit Axe | n/a |
| Rhythm | T1 | Combo Axe | n/a |
| Fast & small | T1 | Twin Hatchets | n/a |
| Outer only | T1 | Bark Scraper | n/a |
| Inner only | T1 | Inner Gouge | n/a |
| **Reach** | T1 | *empty* | **★ Throwing Hatchet ($450, M):** click to throw; it spins out up to 10 m, strips a patch where it lands (great for the top of tall trunks you can't reach), then flies back to your hand. Miss and it drops; walk over to pick it up. **Pole Axe ($350, S):** 4 m reach, slow, small patch. |
| Ring / band | T2 | Ringing Axe | n/a |
| Big & slow | T2 | Crescent Labrys, Greataxe | n/a |
| **Pattern** | T2 | *empty* | **★ Spiral Axe ($1,400, M):** every hit takes a diagonal stripe that continues where the last one ended, so a run of hits winds a spiral up the trunk; keep the rhythm and the stripe widens. Satisfying to watch. **Splitting Maul ($900, M):** on a *log*, one hit splits off the whole top quarter of bark in one long sheet. |
| **Quality** | T2 | *empty* | **★ Bark Spud ($1,100, M):** the real tool for peeling bark. It's slow, but sheets come off whole and unbroken, and a whole sheet sells for 1.5x (needs the "bark quality" idea). Rewards care over speed. |
| Auto | T3 | Robo-Axe X9 | n/a |
| **Endgame** | T4 | *empty* | **★ Thunder Axe ($18,000, M):** charge by holding the button; let go and the hit cracks the bark off the *whole trunk* in one burst of flying sheets (cooldown 6 s). A showpiece moment. **Laser Debarker ($24,000, M):** hold to sweep a beam; it scorches clean lines through both layers wherever you draw. |

## 2. Saws (fell and cut): 6 slots

| Slot | Tier | Filled by | Candidates for empty slots |
|---|---|---|---|
| Fell + cut | T1 | Bow Saw | n/a |
| Logs only, split into rounds | T1 | Buck Saw | n/a |
| Fast | T2 | Chainsaw | n/a |
| **Crown work** | T1 | *empty* | **★ Pole Saw ($380, M):** 5 m reach; cuts the crown off a *standing* tree so leaves and saplings rain down, and the trunk gets easier to fell and lighter to move. **Folding Pocket Saw ($60, S):** cheapest way to fell, very slow. |
| **Big trees** | T2 | *empty* | **★ Two-Man Crosscut ($1,600, M):** huge blade, slow, but it's the only hand saw that fells the giant trees (see "big trees" below) in one go, and the cut is clean so the log is worth +20%. |
| **Endgame** | T4 | *empty* | **★ Harvester Head ($22,000, L):** hold on a tree: it fells, strips both layers and cuts it into carry-length logs in one motion. The forestry-machine fantasy. **Circular Felling Saw ($9,000, M):** instant fell, but the tree always drops where you're looking. |

## 3. Bark drills and power strippers (hold to strip): 7 slots

| Slot | Tier | Filled by | Candidates for empty slots |
|---|---|---|---|
| Continuous | T2 | Timber Auger | n/a |
| Through both layers | T2 | Hole Saw | n/a |
| Two bits | T3 | Twin Auger | n/a |
| **Area spray** | T2 | *empty* | **★ Pressure Washer ($2,200, M):** hold to blast a jet of water: bark flakes off wherever the spray lands, in a soft round patch that follows your aim. The most "satisfying video" tool in the whole game. Water mist effect, hiss sound. |
| **Logs, lengthwise** | T2 | *empty* | **★ Electric Planer ($1,300, M):** on lying logs only; drag along the log and it takes a full-length strip in one pass (the strip comes off as one long sheet). Makes logs worth stripping before shipping. |
| **Ring cutter** | T3 | *empty* | **Ring Auger ($3,600, S):** hold on a trunk: a ring of bark spins off band by band as you move up or down. |
| **Endgame** | T4 | *empty* | **★ Hydro-Debarker ($16,000, M):** pressure washer's big brother: a wide fan that takes both layers and pushes the sheets away from you in a stream (straight into a basket or onto a belt). |

## 4. Collecting and hauling: 6 slots

| Slot | Tier | Filled by | Candidates for empty slots |
|---|---|---|---|
| **Cheap gather** | T0/T1 | *empty* | **★ Leaf Rake ($40, M):** click to drag every loose piece in front of you a step toward you; piles up bark and leaves fast. The early-game answer to "picking up 50 bark sheets one by one". |
| Suction | T2 | Leaf Vacuum | n/a |
| Wide suction | T3 | Twin-Nozzle Vac | n/a |
| Launch | T3 | Cyclone Vac | n/a |
| **Push** | T2 | *empty* | **★ Leaf Blower ($900, M):** hold to blow everything in a cone away from you; herd a whole pile across the clearing into the truck bed or onto a conveyor. A natural partner to the vacuum. |
| **Heavy hauling** | T2 | *empty* | **★ Wheelbarrow ($600, M, physical):** grab its handles and push it; it carries a big load of bark, ore or a short log. Carrying is the biggest early bottleneck. **Log Tongs ($250, S):** carry one long log that's normally too heavy. |

## 5. Mining: 7 slots

| Slot | Tier | Filled by | Candidates for empty slots |
|---|---|---|---|
| Basic | T1 | Pickaxe | n/a |
| Powered | T2 | Rock Drill | n/a |
| Iron tier | T2/T3 | Steel Pickaxe, Steel Core Drill | n/a |
| **Smash** | T1 | *empty* | **★ Sledgehammer ($220, S):** slow, but one hit breaks a small rock into all its chunks at once. Different rhythm from the pickaxe. |
| **Find** | T2 | *empty* | **★ Ore Detector ($750, M):** a handheld that beeps faster near rocks with a vein inside. Pairs with a new idea: some plain-looking rocks hide ore (more reason to explore and to mine). |
| **Blast** | T3 | *empty* | **★ Dynamite + Detonator ($1,200 per box of 5, M):** stick a charge on a rock, wire it to a button with the wire spool, press: boom, the rock bursts into every chunk. Uses the circuit system you already have. |
| **Next ore tier** | T4 | *empty* | **Diamond Core Drill ($14,000, S):** needed for a third, rarer ore (e.g. gold flecks deep in the quarry) if you add one. |

## 6. Utility: 8 slots

| Slot | Tier | Filled by | Candidates for empty slots |
|---|---|---|---|
| Build | T1 | Builder's Hammer | n/a |
| Wire | T2 | Wire Spool | n/a |
| Prune | T1 | Pruning Shears | n/a |
| Phone | T1 | TimberPhone | n/a |
| **Measure** | T1 | *empty* | **★ Log Scale ($90, S):** aim at a log or a pile in a basket and the HUD line shows its weight and value. Helps decide what's worth carrying. |
| **Grow** | T1 | *empty* | **★ Watering Can ($70, S):** water a rooted sapling and it grows twice as fast for a while. Makes replanting a real loop. |
| **Climb / reach** | T2 | *empty* | **★ Climbing Spikes ($650, M):** walk up a standing trunk while you hold the jump key, to strip the high bark (alternative to the throwing hatchet). |
| **Clear** | T2 | *empty* | **Stump Grinder ($1,800, M):** grind a stump down to nothing (frees the space and drops a pile of sawdust that the compost pile turns into saplings faster). |

---

## Things these items would want (outside the items themselves)

* **Big trees:** a few giant old trees deep in the woods, too thick for normal saws (needs the Two-Man Crosscut
  or chainsaw). Gives late tools a target. M.
* **Bark quality:** whole sheets worth more than shredded bits (Bark Spud, Electric Planer). M.
* **Hidden ore in plain rocks** (Ore Detector). S.
* **Tree species values** (from the ideas doc) make the reach tools and big saws pay off differently. M.

## The pitch: the 16 I'd add, in order

Picked to fill every empty slot with the tool that plays most differently, cheapest first, so each price
tier gets something new:

1. **Leaf Rake** ($40): fixes the most tedious early moment (picking up bark one sheet at a time).
2. **Watering Can** ($70): makes replanting a loop instead of a wait.
3. **Log Scale** ($90): shows a log's or pile's weight and value before you haul it; tiny code, big clarity.
4. **Sledgehammer** ($220): a second, very different way to mine.
5. **Pole Saw** ($380): saws crowns off standing trees, so leaves and saplings rain down.
6. **Throwing Hatchet** ($450): reach the top of tall trunks; the throw-and-return is fun on its own.
7. **Wheelbarrow** ($600): the early hauling answer, before vacuums.
8. **Ore Detector** ($750): gives exploring a purpose.
9. **Leaf Blower** ($900): herd piles into the truck or onto belts.
10. **Bark Spud** ($1,100): rewards careful stripping with whole, more valuable sheets.
11. **Electric Planer** ($1,300): long satisfying strips off logs.
12. **Spiral Axe** ($1,400): a new strip *shape*, made for rhythm.
13. **Two-Man Crosscut** ($1,600): fells the giant trees.
14. **Pressure Washer** ($2,200): the signature "satisfying" tool. If you only add one, add this.
15. **Dynamite + Detonator** ($1,200 per box): uses the circuit system for a big payoff.
16. **Thunder Axe** ($18,000): the endgame showpiece; a charged hit cracks every sheet off the trunk at once.

Kept in reserve: Pole Axe, Splitting Maul, Folding Pocket Saw, Circular Felling Saw, Ring Auger, Hydro-Debarker,
Log Tongs, Diamond Core Drill, Climbing Spikes, Stump Grinder, Laser Debarker, Harvester Head.

With the 16 the roster is 43 items (42 tools plus the phone): 14 axes, 5 saws, 5 bark drills/strippers,
6 for collecting, 7 for mining and 6 utility, with something new in every tier.
