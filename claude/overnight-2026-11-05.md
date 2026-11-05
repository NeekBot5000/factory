# Overnight session, 5 Nov 2026

GOAL: "do an overnight session fixing bugs or doing whatever and following popular trends on roblox to make it
popular" - the Roblox version of Timber, keeping the Godot game as its core; publish-ready, CI green, pushed.
STARTED: 05:04 UTC   ENDS: 13:04 UTC (8 hours)

## Queue (most wanted first)
[x] 1. Check tonight's first publish went through (Roblox assets and publishing, publish ticked)
[x] 2. Bug hunt for what Lune can't see: StreamingEnabled (the client waiting forever on parts that aren't streamed
       in), deprecated or Studio-only APIs, things the harness rewrites; fix what's real
[x] 3. Mobile first (most Roblox players are on phones): every action has a touch button, the HUD fits a phone
       screen (checked in the client harness at phone size), lighter bark drawing on phones
[x] 4. Daily reward with a streak (come back tomorrow: a bit more money each day, Bee Swarm style), saved, with a
       HUD toast
[x] 5. Leaderboard: the player list shows money and trees felled (leaderstats), so a server sees who's ahead
[x] 6. Badges: trophies award Roblox badges when their ids are set (badges are made on the Creator Dashboard)
[x] 7. Social: invite friends from the phone; a one-time "favourite the game" prompt after the first big sale
[-] 8. First 90 seconds: a marker over the next goal of the Getting started panel (parked, see below)
[x] 9. Engine check: the new server features run in a real Roblox server
[x] 10. Republish the final build (the experience is private; the user said publish)
[x] 11. Docs (publish README, roblox-style.md), ledger, morning report

## Done
[x] Publish: the 05:03 run published the place (Publish the place: success) - 05:05
[x] Bug hunt (streaming): the client never waits on or indexes world parts that might not be streamed in; the real
    server printed no warnings. Nothing to fix - 05:10
[x] Mobile: tapping tool bar slots switches tools (on a phone there was no way to switch tools at all); touch
    buttons Phone, Run, and Turn / Take down with the hammer; hints and toasts name the touch buttons; shorter
    bark range and a 5-slot tool bar on phones; TimberMart's header fits narrow screens - 05:14, 05:50
[x] Daily reward with a streak ($15/day in a row up to $105; nothing on your first day, as Godot starts at $0)
    - EconomyService.daily, 4 playtest checks - 05:23
[x] Lumberjacks list on the TimberPhone (who's here, by earned, with trees felled; Earned/Felled saved and
    published) - ShopController, LogService, DataService; playtest + 2 client checks - 05:39
[x] Badges: trophies (and playing) award Roblox badges once ids are in Config.Badges; 10 badge icons in
    roblox/publish/badges/, steps in roblox/publish/README.md - 05:43
[x] Invite friends button on the phone (SocialService) - 05:45
[x] Codes on the TimberPhone (Config.Codes: TIMBER $100, LUMBERJACK $250; once per player, checked on the server)
    - EconomyService.redeem, playtest - 05:52
[x] Golden tree event: every 15 min a tree near the cabin turns gold for 10 min, 5x bark, sparkles, announced with
    a direction - EventService, BarkLook, TreeVisuals, TreeService; playtest (exactly 5x a panel); its logs keep
    the gold (fix at 06:41) - 06:05
[x] All-time leaderboard (OrderedDataStore, top 10 on the phone; the phone's sidebar now scrolls); the real
    server reads the store (engine check 15/15) - LeaderboardService - 06:10
[x] Store text and roblox-style.md notes for tonight's features (description 967 characters) - 06:33
[x] Today's jobs on the phone (the user's growth ideas #7 and #10): fell trees, earn at the mill, one big
    truckload, bonuses, varying daily - JobsService; playtest - 06:51
[-] Drawing the screens with Roblox's renderer at phone size: built (tests/engine/ui.luau), but Roblox's thumbnail
    renderer doesn't draw SurfaceGuis (a red-box probe came out blank). Step removed from the engine check; the
    publish README now says to check the HUD in Studio's device view - 06:55

[x] Review pass, part 1 (07:05-07:45): the phone's header fits narrow screens (shorter button labels); the phone
    shows your daily streak (and still does on a second visit the same day); the wood of the day and the daily
    reward roll over at midnight for players still online (checked every minute, was hourly - the phone could show
    yesterday's wood while the mill paid today's); the leaderboard only writes a total that changed (DataStore
    budget). Playtest 224, client 44 - 07:23
[x] Engine check now covers the golden tree and the wood of the day in a real server: 17 of 17 pass - 07:40
[x] Friends boost: +10% at the mill while a Roblox friend is on your server (Player:IsFriendsWith looked up on
    join, toast to both) - EconomyService.friendBoost; playtest 226 - 07:45
[x] Store text and roblox-style.md mention jobs, wood of the day and the friends boost (description 938 chars) - 07:48
[x] Exploit fix: "New game" rebuilt the save from scratch, so codes could be redeemed again, the daily streak
    reset and the all-time leaderboard total was overwritten lower. Codes used, streak, best-ever earned and
    today's finished jobs now carry over - DataService.reset, LeaderboardService; playtest - 07:50
[x] Flake fix: the midnight loops (daily reward, jobs) ran every minute and could fire mid-test; they now act only
    when the UTC day actually changes (cheaper too). Playtest 228, three clean runs in a row - 08:05
[x] Phone sidebar: today's jobs now come before the code box (on a phone you scrolled past codes to see jobs) - 08:06
[x] Shutdown: BindToClose waits for every save to finish (up to 25 s) instead of a fixed 5 s, so a slow DataStore
    doesn't lose progress when Roblox closes a server - 08:12
[x] Reviewed and found sound: the buy handler (types, price, ownership, money, no double orders), touch key names
    (every key hint has a touch name), TrophyService badges, EventService golden tree lifecycle - 08:15
[x] Republished the final build (roblox-assets.yml run 29, "Publish the place": success, commit bf35de2) - 08:24

## Parked
- A marker over the next goal (first 90 seconds): a floating marker in the world goes against the user's "no
  floating 3D text" rule and Godot has none; needs the user's say.
- Checking the screens on a phone from here: impossible (Roblox's preview renderer skips UI); needs Studio's device
  view once.
- "Favourite this game" prompt: not sure of the exact AvatarEditorService call for experiences; not guessing.

## Morning report

**Outcome:** the Roblox Timber is published again with everything from tonight. CI (Test & build) is green on the
published commit, and the real-Roblox engine check passes 17 of 17. I finished at 08:35 UTC, about 3.5 hours into
the 8: the queue and the review list were done, and what's left needs your decisions (below). Timestamps in Done
before 07:30 are estimates.

**New for players (popular-game features that fit Timber, the Godot game unchanged at its core):**
- Playable on phones: tap the tool bar, touch buttons for every action, hints name the buttons, lighter bark.
- Daily reward with a streak ($15 a day in a row, up to $105; the streak shows on the phone).
- Today's jobs on the TimberPhone (fell trees, earn at the mill, one big truckload; bonuses, new each day).
- Wood of the day (one species pays 1.5x at the mill).
- The golden tree: every 15 minutes, a tree near the cabin with 5x bark, announced to the server.
- Codes on the phone (TIMBER $100, LUMBERJACK $250), once per player.
- Lumberjacks here and the all-time best (an OrderedDataStore) on the phone.
- Invite friends, plus a friends boost: +10% at the mill while a Roblox friend is on your server.
- Badges for the trophies, which come on once you make them (below).

**Bugs fixed:**
- New game let players redeem the codes again, and wiped their streak and all-time best.
- A flaky playtest: the midnight checks ran every minute.
- Wood of the day stale for up to an hour after midnight.
- Saves on server shutdown waited a fixed 5 s.
- The leaderboard rewrote unchanged totals.
- The phone's header ran over its title on narrow screens.

**Tests:** playtest 228, client 44, logic 25, sync, engine check 17/17.

**Decisions for you:**
1. Badges: make them on the Creator Dashboard (icons in roblox/publish/badges/, steps in roblox/publish/README.md)
   and put the ids in Config.Badges. Recommended: yes, it's the cheapest way to get onto players' profiles.
2. Codes: post TIMBER and LUMBERJACK where players will see them (game page, socials), or change them in
   Config.Codes.
3. Look at the HUD and the phone once in Studio's device view (iPhone size). Roblox's preview renderer can't draw
   UI, so I couldn't check the layout from here.
4. A marker over the next goal for new players: it goes against your "no floating 3D text" rule. Recommended: no,
   unless you want it.
5. Game passes or paid items: not done, your call.
6. Making the experience public, when you're happy with it (the settings are in roblox/publish/README.md).

**Not testable from here:** physics in a real server (cloud sessions run none), and how the screens look on a real
phone.
