# Overnight session, 6 Nov 2026

GOAL: "Put that stuff in the description, find more things to do in an overnight session" - the Roblox Timber's
game page lists the codes and new features; then more fixes and popular-game features, keeping the Godot game as
the core; publish-ready, CI green, pushed to claude/roblox-islands-factory-game-u7anm4.
STARTED: 14:23 UTC   ENDS: 22:23 UTC (8 hours)

## Queue (most wanted first)
[-] 1. The game page's description: codes and what's new, set from GitHub (Open Cloud) - written; landing it needs a key permission (Parked)
[x] 2. Golden tree: the phone shows when the next one comes ("in 6 min") or where it is now; the server hears who
       felled it
[x] 3. Analytics (Roblox AnalyticsService): the Getting started steps as an onboarding funnel, and money in and
       out as economy events, so the Creator Dashboard shows where new players stop
[-] 4. "Favourite Timber?" prompt once, after the first truckload sold - only if the API is confirmed
[x] 5. More badges for tonight's features: golden tree felled, a week's streak, all of a day's jobs done (icons too)
[x] 6. All three jobs done in a day: a bonus and a toast
[x] 7. Engine check: analytics and the new pieces run in a real Roblox server without warnings
[x] 8. Docs: publish README (badges, analytics), roblox-style.md, the description
[x] 11. Community: a one-time "like and favourite" ask after the first sale; a group reward (off until there's a
        group)
[x] 12. A "what's new" thumbnail for the game page (the features players click for: golden tree, daily jobs)
[x] 13. Rush hour: double pay at the mill for the first 5 minutes of every hour (UTC)
[x] 9. Republish the final build (16:36, after CI green on 6dd0e84)
[ ] 10. Review and polish pass, morning report

## Done
[x] Description: roblox/publish/description.txt (885 chars: what's new, CODES with amounts, controls). The Roblox
    assets workflow puts it on the game page via Open Cloud (Place description) with "description" or "publish"
    ticked; a playtest check keeps its codes the same as Config.Codes. First run: Roblox answered 403 "Scope not
    authorized" - the API key needs universe.place Write (steps in roblox/publish/README.md). The step only warns
    on a publish run, so publishing stays green - 14:40
[x] Golden tree: the phone says where it is now or when the next comes; the server hears who felled it - 15:05
[x] All three of a day's jobs done: +$50 once - JobsService.ALL_BONUS - 15:05
[x] Badges golden, week, jobs (Config.Badges, icons by tools/make_roblox_art.py, README list) - 15:05
[x] Roblox analytics: Getting started steps as an onboarding funnel; money in (mill, daily, jobs, codes,
    take-downs) and out (shop, land) as economy events - Analytics.luau; harness records; 2 playtest checks - 15:08
[x] Engine check: analytics enum names and the golden countdown in a real server - 15:11
[x] Golden tree heads-up a minute before; the phone's jobs header says what all three pay (Config.JobsAllBonus);
    docs: roblox-style.md, publish README (analytics, new badges) - 15:20
[x] Engine check: 19 of 19, no warnings (analytics names, golden countdown) - 15:21
[x] Lint pass (luau-analyze): EconomyService read `upgrading` as a global before its local was declared (the
    flag was dead; the level check covered it), plus an unused colour, a shadowed variable and an unused
    variable. All fixed; CI now fails on any lint warning (type errors left out: Roblox's types) - 15:35
[x] CommunityService: like-and-favourite toast once after the first truckload; Config.Group reward ($200 once for
    members, id 0 = off); both kept on New game; README 3b3 says how to make the group. Playtest 236 - 15:33
[x] What's-new thumbnail: roblox/publish/thumbnail_0_new.jpg (the truck screenshot with the four new things on it;
    no faked golden-tree picture) - tools/make_roblox_art.py, README - 15:38
[x] CI with the lint gate: green steps through the Roblox tests on 77d7aab - 15:42
[x] Review of today's server diff (jobs bonus, golden loop, funnel, community): nothing wrong found - 15:45
[x] Rush hour: Config.RushHour (5 min, 2x), EconomyService.rushActive in worth(), announced at the start and 5
    minutes before, phone line; playtest pins it off like the wood of the day; description and roblox-style.md
    mention it (description 959 chars). Playtest 237, client 46 - 16:00
[x] Bug: the truck's price (the sign over the bed and "[E] ship $...") is worked out on the client from each piece's
    raw value, so it left out the wood of the day (since yesterday) and rush hour, and promised less than the mill
    paid. It now counts both, as the server does (Config.WoodBonus shared). Client check: $2, $3 with the wood, $6
    in rush hour. Playtest 237, client 47 - 16:20
[x] Bug: logs in the truck weren't counted in its price at all (the client only added up loose pieces), and the
    client's log value left out the 1.2x for a clean log, so the "worth $..." hint on a clean log was low too.
    Both match the mill now. Client 48 - 16:30

## Parked
- "Favourite Timber?" prompt: AvatarEditorService:PromptSetFavorite is documented for assets and bundles only;
  experiences are mentioned only on the DevForum. Not guessing.
- The description on the game page: needs the API key's universe.place Write permission (your Creator Dashboard),
  then run "Roblox assets and publishing" with "description" ticked - or paste roblox/publish/description.txt.
