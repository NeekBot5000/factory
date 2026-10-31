# Steam launch kit (drafts)

Companion to `docs/steam-roadmap.md`. Concrete drafts you can edit, written from the research in that doc. Nothing
here has been published anywhere.

---

## 1. Store page draft

**Working title:** Timber *(see roadmap item 302: consider a more searchable name or subtitle, e.g. "Timber: Lumber
Co." or "Bark & Barrow")*

**Short description** (Steam caps this at roughly 300 characters; this is about 230):

> Peel bark off trees one satisfying sheet at a time, fell giants, saw logs and haul them to the mill. Build belts,
> machines and a lumber business in a cozy low-poly forest, alone or with up to 3 friends. Every chip of bark is real.

Why it's shaped like this: it names the verb first (peeling, the PowerWash-style hook), then the progression
(fell, saw, haul, automate), then the selling points shoppers filter on (cozy, co-op, physics). A Steam Page Analyzer
guide notes that simulation pages should show both *accessible* and *complex*; the first sentence is the accessible
part, the second the depth.

**Top tags** (first five matter most; describe the sub-genre, skip generic ones like "Indie"):
1. Simulation
2. Automation
3. Co-op (once co-op exists; until then: Physics)
4. Building
5. Cozy

Next tags: Physics, First-Person, Sandbox, Crafting, Relaxing, Base Building, Resource Management, Online Co-Op,
Atmospheric, Stylized, Low-poly, Singleplayer.

**About section outline** (short paragraphs, each with a GIF above it):
1. *Peel it, sheet by sheet* (GIF: a long bark strip tearing off a birch)
2. *Fell giants* (GIF: a huge tree tipping, leaves raining down)
3. *Every piece is real* (GIF: bark sheets tumbling into the truck bed)
4. *Build a timber business* (GIF: belts carrying logs into a sawmill)
5. *40+ tools* (GIF: quick cuts of the throwing hatchet, pressure washer, thunder axe)
6. *Better with friends* (GIF: two players carrying a log, one falling over)
7. Feature bullet list (species, biomes, machines, co-op, Steam Deck, achievements)

**Capsule art brief** (commission a professional; it's the most-seen image). Official sizes since August 2024: main
capsule 1232x706, header 920x430, small 462x174, vertical 748x896; screenshots 1920x1080 or larger, 16:9
([Steamworks: graphical assets](https://partner.steamgames.com/doc/store/assets)).
- Must read at the tiny search-result size (~120x45 px is a common test).
- One idea: a lumberjack mid-swing, a giant tree beginning to fall behind them, bark sheets flying toward the camera,
  warm sunrise light, bold chunky logo on the right.
- Keep the low-poly look so the capsule matches the screenshots.

**Screenshots** (8-12, no UI clutter, each shows a different thing):
1. Peeling close-up with sheets flying
2. A giant tree falling in golden light
3. A stripped trunk gleaming, a pile of bark below
4. The truck loaded to the brim at the cabin
5. A factory of belts and saws at dusk with lamps on
6. Two or three players working one tree (once co-op exists)
7. The quarry with pistons and dynamite smoke
8. A wide landscape shot of the forest and lake
9. The cabin interior with trophies on the wall
10. The pressure washer jet carving a pattern into bark

---

## 2. Trailer shot list (60 seconds)

Rules from the research: gameplay in the first 4-5 seconds, no logos first. Trailer editor Derek Lieu's order (as
reported) is *genre, then hook, then content*, with the hook inside the first 10-15 seconds and the audio planned first.
Many shoppers skip trailers entirely, so the screenshots carry as much weight.
[GameDiscoverCo: getting to the hook](https://newsletter.gamediscover.co/p/how-to-get-to-your-games-hook-quick),
[wnhub: gameplay first](https://wnhub.io/news/analytics/item-237)

| Time | Shot | Sound |
|---|---|---|
| 0-3 s | Close-up: hatchet bites, a big sheet of bark peels and tumbles | crisp chop, tearing |
| 3-6 s | A row of quick peels with different tools (spud, washer, spiral axe) | rhythmic cuts on the beat |
| 6-10 s | "TIMBER!" a giant tree falls, slow-mo, leaves rain | creak, thump, music starts |
| 10-16 s | Saw the log, roll it, load the truck, money counter rolls up | saw, thud, ka-ching |
| 16-24 s | Shop montage: new tools arriving in boxes, throwing hatchet throw-and-catch | upbeat |
| 24-34 s | Automation: belts, pistons, rotator, sawmill, a factory at night | machine rhythm in the music |
| 34-44 s | Co-op chaos: friends carrying a log, a basket flung, dynamite on a rock | laughter-worthy beats |
| 44-52 s | Calm: sunrise over the forest, cabin, rocking chair | music softens |
| 52-56 s | Logo | |
| 56-60 s | "Wishlist on Steam" + platforms | |

Also cut 3-4 **vertical 10-second loops** from the same footage for TikTok/Shorts: one peel, one tree fall, one factory,
one co-op fail. Seamless loops do best.

---

## 3. Demo plan (Next Fest)

Research consensus: about 20-30 minutes of the best content, a strong opening, and an ending that leaves people wanting
more. Launch the demo weeks before Next Fest, not on its first day.

1. **Start**: wake at the cabin at sunrise; the hatchet lies on the porch, a birch in reach (teaches by placement,
   no tutorial text, per your rule).
2. **0-5 min**: peel your first trees, sell bark at the truck, buy the bow saw.
3. **5-12 min**: fell a tree (big moment), saw it, load and send the truck. First real money.
4. **12-20 min**: pick from 4-5 starter tools (throwing hatchet, scraper, rake, shears, pickaxe); first hammer build
   (a basket or a chute).
5. **20-30 min**: first machines (crank, button, conveyor) teased; a giant ancient tree visible across the lake that you
   can't reach yet.
6. **End**: a money cap or day limit; the screen fades on the giant tree with "Full game: wishlist on Steam" on the
   phone screen (diegetic).
7. **Keep the demo save** so it carries over to the full game (players love not losing progress).

---

## 4. Co-op technical plan (Godot 4 + Steam)

The hardest item on the roadmap. A plan in stages, so each stage ships something.

**Stage 0: Remote Play Together (days, not weeks).** Turn it on in Steamworks and test with a friend. The host's game
streams to friends, who control their own input... but Timber has one camera, so this is really "pass the controller"
or a second local player. Hydroneer used split-screen with Remote Play; that needs a second local player and camera,
which is real work. *Recommendation: skip straight to Stage 1 unless split-screen is wanted anyway.*

**Stage 1: lobbies and players (1-2 weeks).**
- GodotSteam (GDExtension 4.4+) + a lobby layer such as LinkUx (Steam lobbies, room codes, relay/NAT traversal handled
  by Steam).
- Host is the server. Each player is a `CharacterBody3D` the client moves itself (client-authoritative movement, the
  host sanity-checks speed). Sync position, look direction, held tool and swing state with a `MultiplayerSynchronizer`
  at ~20 Hz, interpolated on other peers.
- Visible player body (a simple low-poly lumberjack) with the held tool in hand.

**Stage 2: world state (2-4 weeks).**
- **The host owns all physics.** Clients don't simulate loose bodies; they receive transforms.
- **Tool hits are requests**: a client's swing sends "hit at point P with tool T"; the host strips the bark and spawns
  the chips. Bark layers are byte arrays already, so a strip can be sent as a small diff (which panels went to 0).
- **Spawning** with `MultiplayerSpawner` (chips, logs, ores, leaves, builds).
- **Throttle**: sync transforms for bodies near any player at 10-20 Hz; far or sleeping bodies send nothing. Bark chips
  are the bulk (up to 600), so sleeping ones must cost zero bandwidth.
- **Held items: hand authority to the holder.** When a player grabs something, transfer that body's authority (and its
  synchronizer's) to them, so carrying feels instant; give it back on drop. This is the approach Roadside Research used
  for responsive physics co-op.
- Machines and circuits run on the host only; clients see results (belt positions, piston plates).

**Stage 3: joining mid-game and saves (1-2 weeks).**
- A joining client loads the world from the host's save data (the save system already serialises everything: trees,
  logs, chips, builds, wires), then switches to live sync.
- Only the host saves. Clients' tool unlocks belong to the shared world.

**Steam basics with GodotSteam:** achievements and stats are covered; rich presence has an official tutorial
(localised tokens in a .vdf, then `setRichPresence("steam_display", token)`)
([GodotSteam: rich presence](https://godotsteam.com/tutorials/rich_presence/)); for cloud saves the simplest route is
Steam Auto-Cloud (set in Steamworks to sync the save folder, no code).

**Stage 4: polish.** Proximity voice (Steam voice via GodotSteam), emotes, ping marker, name tags only on a held key
(your no-floating-text rule could allow this as an exception, or skip names and rely on shirt colours).

**Things that will need care:**
- Jolt physics isn't deterministic across machines, so don't try lockstep; stay host-authoritative.
- The throwing hatchet, vacuum and wheelbarrow carry many bodies at once; give their contents to the holder too, or
  freeze them as children while carried (the wheelbarrow already does this).
- Test with artificial lag (100-200 ms) early.

---

## Sources

See `docs/steam-roadmap.md` (Part 1 and the source list). Additional for this doc:
[Godot forum: physics authority](https://forum.godotengine.org/t/how-to-change-multiplayer-authority-for-interactable-objects/132685),
[Godot forum: syncing RigidBody3D](https://forum.godotengine.org/t/how-do-i-sync-rigidbody3d-properly-in-multiplayer/129584),
[Steam Page Analyzer: simulation pages](https://www.steampageanalyzer.com/optimize/simulation),
[presskit.gg: Steam page guide](https://presskit.gg/field-guides/steam-page-optimization-guide).

---

## 5. Achievements draft (60)

Steam achievements show up in friends' activity feeds, so funny names are free marketing. Mix of easy, progression,
silly and secret. Hidden ones marked (H).

**First steps:** Timber! (fell a tree) · Bald Spot (strip a whole trunk bare) · Paper Trail (first truckload sold) ·
Hands-On (strip 50 panels with bare hands) · Open Wide (open your first delivery box) · Phone Home (buy the phone) ·
Lumberjack (own 5 tools) · Tool Wall (own 20 tools) · Full Shed (own every tool)

**Peeling:** Sheet Happens (a single sheet of 30+ panels) · Inside Out (sell 1,000 panels of inner bark) · Clean Sweep
(strip 100 trees bare) · Combo Breaker (max out the combo axe) · Spiral Staircase (a spiral round a whole trunk) ·
Power Washed (strip 500 panels with the pressure washer) · Planed Sailing (plane a log end to end) · Thunderstruck (strip
a tree with one thunder strike)

**Felling and logs:** Domino (fell a tree onto another tree) · Giant Slayer (fell an ancient giant) · Clean Cut (sell a
crosscut log) · Rounds on Me (buck a log into rounds) · Heavy Lifter (carry a 3 m log) · Locked In (lock a log with the
hammer) · Crown Jewel (cut a crown off with the pole saw)

**Throwing hatchet:** Boomerang (catch it 10 times) · Long Shot (strip bark 11+ m away) · Woodpecker (hit the same tree 5
throws in a row) · (H) Nice Catch (catch it while jumping)

**Money:** Pocket Change ($100) · Small Business ($1,000) · Lumber Baron ($10,000) · Tycoon ($100,000) · Big Haul (one
truckload worth $500+) · Spend It All (drop to $0 after buying something)

**Mining and blasting:** Rock On (break a rock) · Hidden Gem (find ore inside a plain rock) · Ironclad (mine iron) ·
Sledge Fund (burst a rock in one blow) · Kaboom (set off dynamite) · Chain Reaction (set off 3 charges at once) · (H) Too
Close (get hurt by your own dynamite)

**Building and machines:** Basket Case (build a basket) · Barrow Boy (fill a wheelbarrow and push it 50 m) · Live Wire
(power a machine) · Conveyor Belter (10 belts in one line) · Round the Bend (send something round a belt turn) · Clamp
Down (clamp something with a piston against a rotator) · Push It (push something with a piston) · Truck Stop (send the
truck with the truck caller)

**Nature:** Green Thumb (plant a sapling that grows into a tree) · Watered Down (water 10 saplings) · Rake It In (rake 100
things) · Leaf Peeper (snip 500 leaves) · Blown Away (blow something 15 m with the leaf blower)

**Silly/secret:** (H) Ouch (faint from bare-hand chopping) · (H) Nap Time (lie in the hammock for a full minute) · (H)
Slam Dunk (score with the basketball) · (H) Air Mail (fling a full basket 10 m) · (H) Weighed Down (weigh something over
1,000 kg on the log scale)

---

## 6. Contracts and customers (design draft)

Roadmap item 152: goals for a session without a checklist. Contracts arrive as messages on the phone from a few
customers with portraits and personalities. Accept or ignore; nothing is ever required.

| Customer | Wants | Pays | Personality |
|---|---|---|---|
| **The Mill** (Rosa) | Logs of a given species and minimum length | steady, +20% over truck price | brisk, practical |
| **Furniture Workshop** (Ade) | Clean planks, dry wood, specific species | high for quality | picky, generous |
| **Paper Plant** | Bulk chips/bark, lots of it | low per unit, big volume | corporate, terse |
| **The Collector** (Mr. Vale) | Rare items: amber, aged rainbow sheets, petrified wood | very high | eccentric, mysterious |
| **Gas Station** | Firewood and birch tinder bundles in winter | small, quick | friendly |
| **The Town** | Big project orders (bridge, stadium) in stages | huge, plus the town grows | community |

**Rules that keep it cozy:**
- Deadlines measured in in-game days and generous; missing one just means a smaller bonus next time.
- Always 2-3 open offers to pick from; new ones arrive each morning.
- Each customer's offers get bigger as you complete theirs (a relationship without a UI meter: their messages get
  warmer and they send small gifts, e.g. a tool skin).
- Delivery is physical: load the right items into the truck (or a marked crate) and send it.
- Contracts surface the new mechanics naturally (a cedar order nudges you to the lakeshore), which is your "learn it
  yourself" rule done through the world rather than a tutorial.
