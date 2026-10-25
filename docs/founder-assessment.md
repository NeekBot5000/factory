# Timber: does this game have potential? (founder-style check, 25 Oct 2026)

Written with the Founder OS *validate-idea* method: sharpen the problem, find the riskiest assumption, design the
cheapest test that could prove it wrong, and decide in advance what result means "keep going".

## Verdict in one paragraph

Timber has one genuinely unusual hook: **peeling a tree layer by layer as real physical pieces**, then carrying
and shipping those pieces with no inventory. Nothing else in the "lumber tycoon" space feels like that, and the
tool variety (24 tools that each work differently) leans into it well. But right now the only person who has
played it is you. The game has grown sideways (machines, mining, basketball, catapults) much faster than anyone
has checked whether a stranger enjoys the **first ten minutes**. That's the single thing that decides whether
the rest matters. The potential is real but unproven, and you can prove or disprove it in about a week, for free.

## 1. The problem, in a player's words

> "I love Lumber Tycoon / Islands-style grinding: chop stuff, sell it, buy a better axe, and eventually build a
> factory that does it for me. But on Roblox it's all clicking on blocks, and I can't play it at school or on my
> laptop without Roblox. I want something where the chopping itself feels good and the factory is mine."

* **Who:** 10-18 year-olds who already play Roblox tycoon/factory games, plus older players who like
  "satisfying" physics sandboxes (power-washer, tree-felling and factory games).
* **What they cope with today:** Roblox games (free, huge, social), Steam sandbox games (paid), browser
  portals like CrazyGames/Poki (free, instant).
* **How often:** daily, in short sessions. This is a *time-filling* need, not a painful one. The bar for
  holding attention is high and the competition is free and good.

## 2. The assumption stack (riskiest first)

| # | Assumption | Type | Risk |
|---|---|---|---|
| 1 | **A stranger who opens the link keeps playing past 10 minutes and comes back another day** | demand / retention | **Highest.** Unknown, and fatal if false |
| 2 | A stranger can figure out what to do without being told (there's no tutorial or goals now) | solution | High: a new player spawns with $0, bare hands and no hint |
| 3 | Players can find the game (a github.io link has no built-in audience; the Roblox crowd lives on Roblox) | reachability | High, but cheap to fix with free portals |
| 4 | It runs well enough in a browser on a typical school laptop or Chromebook | solution | Medium: the web build is ~10 MB (fine), frame rate on weak GPUs is untested |
| 5 | The machine and automation layer is what keeps people around long-term | demand | Medium; only matters if #1 passes |
| 6 | It could ever make money | business | Irrelevant for now; don't think about it until #1 passes |

**Riskiest assumption: #1 (retention of strangers).** If it fails, the machines, Phase 2 and Phase 3 don't
matter. If it passes, you have something people want and everything else is execution.

## 3. The cheapest experiment that could prove it wrong

**"10 strangers, one week."**

1. Upload the existing web build (the `Timber-web` artifact from any green CI run) to **itch.io** as a free
   browser game. Free, about 20 minutes, no money involved.
2. Post it in **one or two** places where strangers try small games and give feedback: r/godot's weekly
   showcase, r/WebGames, or an itch.io devlog. (Not friends or family: they'll be nice to you instead of honest.)
3. Ask exactly three questions in the post: *What did you do first? When did you stop, and why? Would you come
   back tomorrow?*
4. Watch itch.io's own stats (views, plays, average play time). They're built in; nothing to add to the game.

**Set the bar now, before posting:**

* **Pass:** at least 10 strangers play, at least **half play 10+ minutes**, and at least **3** say they'd come back
  (or comment asking for more).
* **Fail:** most stop within 3 minutes, or nobody can tell what to do.

## 4. Decision rule

* **Pass:** keep building the factory side (Phase 2/3), and start posting a short devlog every week or two.
* **Fail because people got lost:** fix onboarding (below) and re-run the same test. Don't add machines first.
* **Fail because it's just not fun once understood:** double down on the bark-stripping feel (the unique part)
  and cut side features, or treat Timber as a learning project and keep it for yourself. That's also a fine outcome.

Next Founder OS skill after the test: `customer-interviews` (to read the feedback honestly), then `scope-mvp`
(to decide which of the 30+ ideas actually make the cut).

## What I found while playtesting tonight (evidence, not opinion)

* **The first two minutes are the weakest part.** You spawn with nothing and no goal. The loop (strip bark,
  carry it to the truck, press E to ship, use the computer to buy a hatchet) is discoverable only by
  experimenting. This is the most likely reason a stranger would leave.
* **Economy:** before tonight, cheap tools beat expensive ones. The $160 double-bit axe outperformed tools
  costing 4-13x more, and the $2,400 auger beat the $6,500 robo-axe. Rebalanced with a benchmark
  (`tests/Bench.tscn`), so speed now mostly rises with price. Details in the overnight report.
* **Bugs fixed tonight:** you couldn't remove anything you built; a crash after snipping a crown bare and then
  chopping that tree; snipped crowns regrew (with free saplings) on reload; rocks never came back; the toolbar
  ran off the screen with many tools.
* **Scope:** 24 tools, 18 buildables, 8 machines, and a queue of ~20 more machines. That's a lot of surface for
  one person to keep bug-free. Each new system multiplies the interactions that can break.

## What you need to do (only you can)

1. ~~Decide on onboarding.~~ **Decided: no goals list; players learn by exploring.** That makes the strangers
   test more important: watch whether people work out "strip bark -> truck -> computer" on their own. If most
   do, the discovery is part of the fun. If most quit before their first sale, look at what the world itself can
   show (things you can see, not text), for example the truck parked where you spawn already does some of that.
2. **Run the 10-strangers test** (upload to itch.io, post once, read the replies). This needs your accounts, and
   posting publicly is your decision, not mine.
3. **Try it on a weak machine** (a school laptop or Chromebook) and tell me the frame rate and anything that
   felt laggy.
4. **Pick a direction after the test**, using the decision rule above. Hold off on Phase 2/3 machines until then, or
   at least keep them small.

## What I'll do (Claude, on your go)

* Graphics already step down on their own on slow machines; add a manual setting if you want one.
* Keep running the balance bench whenever tools are added, so prices stay honest.
* Keep tests and CI green for every change; tonight CI also learned to fail on script errors.
* Continue Phase 2/3 machines in small, tested slices once you've decided direction.

*Unverified:* nothing here is market data. The audience description is a reasoned guess, which is exactly what
the 10-strangers test is for.
