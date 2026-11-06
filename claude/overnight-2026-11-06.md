# Overnight session, 6 Nov 2026

GOAL: "Put that stuff in the description, find more things to do in an overnight session" - the Roblox Timber's
game page lists the codes and new features; then more fixes and popular-game features, keeping the Godot game as
the core; publish-ready, CI green, pushed to claude/roblox-islands-factory-game-u7anm4.
STARTED: 14:23 UTC   ENDS: 22:23 UTC (8 hours)

## Queue (most wanted first)
[x] 1. The game page's description: codes and what's new, set from GitHub (Open Cloud), checked it landed
[x] 2. Golden tree: the phone shows when the next one comes ("in 6 min") or where it is now; the server hears who
       felled it
[x] 3. Analytics (Roblox AnalyticsService): the Getting started steps as an onboarding funnel, and money in and
       out as economy events, so the Creator Dashboard shows where new players stop
[-] 4. "Favourite Timber?" prompt once, after the first truckload sold - only if the API is confirmed
[x] 5. More badges for tonight's features: golden tree felled, a week's streak, all of a day's jobs done (icons too)
[x] 6. All three jobs done in a day: a bonus and a toast
[ ] 7. Engine check: analytics and the new pieces run in a real Roblox server without warnings
[ ] 8. Docs: publish README (badges, analytics), roblox-style.md, the description
[ ] 9. Republish the final build
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
    take-downs) and out (shop, land) as economy events - Analytics.luau; harness records; 2 playtest checks - 15:25
[x] Engine check: analytics enum names and the golden countdown in a real server - 15:30

## Parked
- "Favourite Timber?" prompt: AvatarEditorService:PromptSetFavorite is documented for assets and bundles only;
  experiences are mentioned only on the DevForum. Not guessing.
- The description on the game page: needs the API key's universe.place Write permission (your Creator Dashboard),
  then run "Roblox assets and publishing" with "description" ticked - or paste roblox/publish/description.txt.
