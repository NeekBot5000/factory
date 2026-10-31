# Tree species sheet (design draft)

For roadmap items 41-58 and 381. Each species takes something **real** about its bark and turns it into a mechanic,
so every new tree peels differently instead of being a recolour. Values are relative to oak = 1.0.

Rule of thumb for the build order: the first six after the current three (oak, birch, pine) should each introduce a
*new way bark comes off*.

| # | Species | Real bark fact | Game mechanic | Inner colour | Biome | Value | Tool needed |
|---|---|---|---|---|---|---|---|
| 1 | **Oak** (have) | Thick, ridged, plated | The baseline | warm orange-brown | meadow | 1.0 | any |
| 2 | **Birch** (have) | White papery outer layer that lifts off; flammable oils (good tinder) | Peels in thin curls; sheets sell as tinder bundles to the gas station | pale salmon | birch hills | 0.9 | any |
| 3 | **Pine** (have) | Plated, resinous | Resin beads on cuts, collect as amber/resin (item 33) | amber-orange | everywhere | 0.8 | any |
| 4 | **Shagbark hickory** | Long shaggy strips that curl outward, loose at both ends | Strips can be *pulled off by hand* (bare hands become useful on this one tree) | tan | deep forest | 1.1 | hands / any |
| 5 | **Western red cedar** | Fibrous, stringy bark that comes loose in long strips; easier to peel in spring/autumn when sap runs; inner bark traditionally made into rope, mats and clothing | Planer/draw-knife makes *very* long strips; cedar strips can be braided into rope at a bench (rope = winch/zipline material). Peels easier in spring and autumn | deep red-brown | lakeshore | 1.6 | any; draw knife best |
| 6 | **Ponderosa pine** | Orange-cinnamon bark broken into jigsaw-puzzle plates; smells of vanilla/butterscotch in warm sun | Bark comes off as *puzzle plates* (each plate one sheet, satisfying pop); on sunny days a vanilla-scented particle shimmer (no text) marks the warmest trees | yellow-orange | pine mountain | 1.2 | any |
| 7 | **Pacific madrone** | Thin red cinnamon bark that peels off in summer to reveal smooth green bark that ripens to deep red | Peels itself slowly in summer (loose curls you can grab); the exposed green turns red over in-game days, then can be peeled again: a *renewable* bark tree | green → red | dry hills | 1.4 | hands / scraper |
| 8 | **Rainbow eucalyptus** | Freshly exposed inner bark is bright green and shifts through blue, purple, orange and red as it ages | Peeled patches change colour over days; aged sheets are worth more; a fully aged trunk is a rainbow (item 381) | green → rainbow | misty valley | 2.0 (aged) | any |
| 9 | **Cork oak** | Outer bark is cork; it can be stripped completely and grows back (commercially every ~9 years) | Strip the cork without hurting the tree; it *regrows* over a few in-game weeks. Cork sells per kilo; leave the tree standing | cinnamon under cork | dry hills | 1.5 (cork) | scraper / spud only (axes damage it) |
| 10 | **Giant sequoia** | Very thick fibrous bark (up to ~18-24 in), dry not resinous, chars slowly instead of burning | The "ancient giants": bark comes off in thick fibrous slabs, takes many hits; immune to lightning fires (it chars); needs the crosscut or chainsaw to fell | rust red | ancient grove | 3.0 | crosscut / chainsaw to fell |
| 11 | **Sugar maple** | Sap boils down about 40:1 into syrup; tapping season ends when nights stop freezing or buds open | Tap in late winter/early spring; collect sap buckets; evaporate 40 sap → 1 syrup (item 106). Bright orange crown in autumn | creamy | meadow edges | 1.2 (+syrup) | tap + bucket |
| 12 | **Sycamore** | Flaky bark that exfoliates in patches, mottled like camouflage | Patches pop off on their own when the trunk is hit nearby (chain peels); mottled sheets | cream-green | river banks | 1.0 | any |
| 13 | **Cherry** | Smooth shiny bark with horizontal stripes (lenticels) | Peels in horizontal ribbons around the trunk (ring-style) | reddish-pink | orchard hills | 1.5 | ringing axe best |
| 14 | **Willow** | Soft, flexible | Easy to strip, low value, grows fast; good for beginners in the swamp | yellow | swamp | 0.6 | any |
| 15 | **Snow pine** (fantasy) | — | Frost layer to break first (sledge/washer); ice chips sparkle | blue-white | mountain top | 1.8 | sledge, then any |
| 16 | **Glowwood** (fantasy) | — | Inner bark glows at night; sheets used as lamps | cyan glow | misty valley | 2.5 | any, at night |
| 17 | **Ember tree** (fantasy) | — | Charred outer bark near the volcano vent; hot inner bark sizzles in water | ember orange | volcanic ridge | 2.2 | gloves + any |
| 18 | **Crystal tree** (secret) | — | Bark shatters into glassy shards with a chime | clear/violet | hidden cave grove | 5.0 | thunder axe or sledge |
| 19 | **Petrified tree** (secret) | — | Stone bark: needs mining tools; drops "petrified wood" collectible | grey-brown | quarry | 4.0 | pickaxe / rock drill |

**Suggested first wave** (each adds a new peel behaviour): shagbark hickory (pull by hand), ponderosa (puzzle plates),
cedar (long strips + rope), madrone (self-peeling, renewable), cork oak (renewable, special tool), rainbow eucalyptus
(colour over time).

**Notes**
- Keep the low-poly look: each species needs only its colours, a bark pattern in the shader, a crown shape, and its
  peel rule.
- "Renewable" trees (madrone, cork oak) give the late game a farming loop without animals.
- Facts above come from field-guide and agency pages (sources below), except the cherry and willow rows, which are
  general knowledge I didn't check tonight. The fantasy species are made up.

## Sources
[Western redcedar, UW Bothell](https://www.uwb.edu/wetland/plants/thuja-plicata) ·
[Western red cedar, SFU](https://www.sfu.ca/halkeb/html/plants/redcedar.htm) ·
[Ponderosa pine, US FWS](https://www.fws.gov/story/2024-05/know-your-trees-ponderosa-pine) ·
[Ponderosa pine identification, UVM](https://libraryexhibits.uvm.edu/omeka/exhibits/show/uvmtrees/ponderosa-pine-introduction/ponderosa-pine-identification) ·
[Pacific madrone, NPS](https://www.nps.gov/articles/pacific-madrone.htm) ·
[Pacific madrone, Oregon State Extension](https://extension.oregonstate.edu/sites/default/files/documents/ec1619.pdf) ·
[Rainbow eucalyptus, Science Friday](https://www.sciencefriday.com/articles/rainbow-in-a-tree/) ·
[Giant sequoia bark, AskNature](https://asknature.org/strategy/giant-sequoia-bark-shields-trees-from-flames/) ·
[Maple syrup, Michigan DNR](https://www.michigan.gov/dnr/0,4570,7-350-79119_104319_105740---,00.html) ·
[Sugaring process, American Maple Museum](https://maplemuseum.com/pages/sugaring-process.html) ·
[Tree bark identification](https://goodandbeautiful.com/blog/tree-bark-identification) ·
[Bark ID, NY State Parks](https://nystateparks.blog/2025/11/26/bark-buds-and-beyond-a-guide-to-identifying-winter-trees/)
