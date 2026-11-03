# Setting up Timber for Roblox

## Fastest: Live Sync (one-time setup, then nothing)
Every push to GitHub shows up in your open Studio place within about 10 seconds. There's nothing to download each
time, and nothing to run.

**Once:**
1. Download `TimberSync.lua`: on GitHub open `roblox/plugin/TimberSync.lua`, then click the **Download raw file**
   button (the arrow at the top right of the code).
2. In Studio, go to the **Plugins** tab > **Plugins Folder**. A folder opens. Move `TimberSync.lua` into it.
3. Restart Studio.

**Each time you test:**
1. Open your Timber place (or **New > Baseplate**).
2. Click **Plugins > Timber > Live Sync** so it lights up. Studio remembers this.
   - The first time, Studio asks whether the plugin may use **github.com**, **api.github.com** and
     **raw.githubusercontent.com**. Click **Allow** for each.
3. The Output window says `[Timber] Synced to 1a2b3c4` within a few seconds. Press **Play**.

After a push, Output prints a new "Synced" line. Stop the test and press Play again to get the new version. A sync
only happens while you're editing, never in the middle of a Play test.

What it changes: the three code folders (ReplicatedStorage > Shared, ServerScriptService > Server and
StarterPlayerScripts > Client) are replaced, and the lighting and baseplate settings are applied. Anything else you
build in the place stays. **Ctrl+Z** undoes a sync. **Sync Now** pulls once without turning Live Sync on.

## Let GitHub upload assets for you (once, about 5 minutes)
Sounds and other assets go up to Roblox automatically: whenever an asset in `roblox/assets.json` is new or changes,
GitHub uploads it and commits its Roblox ID into the game, and Live Sync brings it into Studio. Right now that's the
sound sheet: every sound from the Godot game in one audio file.

**1. Make a Roblox API key**
1. Go to https://create.roblox.com/dashboard/credentials and click **Create API Key**.
2. Name it `Timber GitHub`.
3. Under **Access Permissions**, choose **Assets API** in the drop-down, click **Add API System**, and tick
   **Read** and **Write**.
   - To let GitHub publish the game too, also add **universe-places**, pick your Timber experience, and tick **Write**.
4. Under **Security**, add `0.0.0.0/0` to **Accepted IP Addresses** (GitHub's machines change address).
5. Click **Save & Generate Key**, then **Copy Key to Clipboard**.

**2. Give it to GitHub**
1. On the repository page, go to **Settings > Secrets and variables > Actions**.
2. **Secrets** tab > **New repository secret**: name `ROBLOX_API_KEY`, and paste the key.
3. **Variables** tab > **New repository variable**: name `ROBLOX_USER_ID`, value your Roblox user ID. It's the number
   in your profile's web address, `roblox.com/users/<this number>/profile`.

**3. Run it**
1. **Actions** tab > **Roblox assets and publishing** > **Run workflow**.
2. In about a minute it commits `Roblox: new asset ids from the upload`. Live Sync picks that up, and the next Play
   test has every sound: the breeze, the birds, the music, and each chop.

After that it runs by itself whenever an asset changes.

**Publishing the game from GitHub (optional):** add two more variables, `ROBLOX_UNIVERSE_ID` and `ROBLOX_PLACE_ID`.
Find both in the Creator Dashboard: open the experience, then the **...** menu on it, or its place's **...** menu,
and choose **Copy Universe ID** or **Copy Place ID**. Then **Run workflow** with **publish** ticked. It replaces the
published place with the code from GitHub, so anything built only by hand in Studio isn't included.

## Let GitHub look at the game in Roblox itself (optional, recommended)
The **Roblox engine check** workflow (`tools/roblox_engine.py`) tests the game in Roblox itself, not just in the
Lune stand-in:
- Roblox's own renderer draws the world from the same 10 views as the Godot game, so the two can be compared side by
  side (`roblox/tests/engine/out/pair_<view>.jpg`).
- A real Roblox server runs the game and checks the physics, the meshes and any errors
  (`roblox/tests/engine/out/engine.json`). It uses a *saved* version of your place, so the published game isn't
  touched.

It needs three more permissions on the same API key, and the two variables from the section above:
1. Open https://create.roblox.com/dashboard/credentials, then the Timber key, then **Edit**.
2. Under **Access Permissions**, add each of these and tick what's listed:
   - **Legacy Assets**: **Manage** (lets it download what Roblox made of the uploaded models);
   - **universe-places**: your Timber experience, **Write**;
   - **Luau execution sessions** (`universe.place.luau-execution-session`): your Timber experience, **Write**.
3. Save the key. The secret on GitHub stays the same.
4. Add the repository variables `ROBLOX_UNIVERSE_ID` and `ROBLOX_PLACE_ID` if you haven't (see above).
5. Run **Actions** > **Roblox engine check** > **Run workflow**. The results are committed back to the branch.

If a permission is missing, the run's log names the step Roblox refused.

## Control Studio with Claude on your computer (optional)
Roblox Studio has a built-in MCP server. With it, a Claude running *on your computer* (the Claude desktop app or
Claude Code) can read your place, edit scripts, run Luau, insert assets and start Play tests.
1. In Studio, open **Assistant**, then click **...** > **Manage MCP Servers**.
2. Turn on **Enable Studio as MCP server**.
3. Under **Quick connect**, turn on **Claude Desktop** or **Claude Code**, then restart that app.
4. A green dot under the switch means it's connected.

The cloud sessions that write this code can't reach your computer, so they use Live Sync and GitHub instead.

## Quick start: no installs (2 minutes)
1. Get `Timber.rbxl`, the whole game as one Roblox place file:
   - **On GitHub:** **Actions** > the latest green **Test & build** run > **Artifacts** > **Timber-roblox**.
   - **Or** use the file Claude sent you.
2. Double-click it, or in Studio choose **File > Open from File**.
3. Press **Play**.

This is enough to try the game. To work on the code from VS Code, with changes appearing in Studio as you save, do the
full setup below. It takes about 20 minutes.

## 1. Get the project onto your computer
- **With Git** (in a terminal): `git clone https://github.com/NeekBot5000/factory.git`
- **Without Git:** on the GitHub page for the repository, use **Code > Download ZIP**, then unzip it.

The Roblox part is the `roblox` folder inside it.

## 2. Install Rojo (with Rokit)
Rojo syncs the code from the `roblox` folder into Studio. Rokit installs Rojo at exactly the version the project
names in `rokit.toml` (7.7.1).

**Windows**
1. Download the latest `rokit-...-windows-x86_64.zip` from https://github.com/rojo-rbx/rokit/releases and unzip it.
2. Open a terminal in that folder (right-click > Open in Terminal) and run `.\rokit.exe self-install`.
3. Close the terminal and open a new one, so it finds Rokit.

**Mac**
1. Open Terminal and run: `curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash`
2. Close Terminal and open it again.

**Then, on either**
1. In the terminal, go to the project's `roblox` folder, for example
   `cd C:\Users\you\Downloads\factory\roblox` (Windows) or `cd ~/Downloads/factory/roblox` (Mac).
2. Run `rokit install` and say yes if it asks to trust the tool.
3. Run `rojo --version`. It should print `Rojo 7.7.1`.

If Rokit gives you trouble, you can skip it: the **Rojo** extension in VS Code can install Rojo for you (step 4).

## 3. Install the Rojo plugin in Studio
- Run `rojo plugin install` in the terminal, then **restart Roblox Studio**.
- A **Rojo** button appears under the **Plugins** tab.

## 4. Set up VS Code
1. Open the `roblox` folder in VS Code (**File > Open Folder**).
2. Install two extensions from the Extensions panel:
   - **Luau Language Server** (by JohnnyMorganz): autocomplete and error checking for Roblox code.
   - **Rojo - Roblox Studio Sync** (by evaera): optional. It runs `rojo serve` from a button, and can install Rojo
     if step 2 didn't work.

## 5. Make the experience in Studio
1. In Studio, choose **New > Baseplate**.
2. **File > Publish to Roblox**:
   - Name it *Timber*.
   - Leave it **private** for now. A brand-new experience stays private until you make it public.
3. Open **Game Settings** (Home tab) > **Security** and turn on **Enable Studio Access to API Services**, then
   **Save**. Without this, money doesn't save while you test in Studio; the game still runs and warns you in the
   Output window.
4. Open **View > Output**. Any errors appear there.

## 6. Connect the code
1. In the terminal, in the `roblox` folder, run `rojo serve`.
   - It prints `Rojo server listening on port 34872`.
   - Leave this terminal open while you work.
2. In Studio, go to **Plugins > Rojo > Connect**.
3. The game's scripts appear:
   - **ReplicatedStorage > Shared**: the game logic
   - **ServerScriptService > Server**: the server scripts
   - **StarterPlayer > StarterPlayerScripts > Client**: the client scripts
4. From now on, saving a file in VS Code updates Studio straight away.

## 7. First play test
1. Press **Play** (F5).
2. You're in first person on the cabin porch, like in the Godot game. The world is the Godot game's: the same
   ground, every tree where it stands in Godot, the cabin, the chopping block with the old hatchet in it, and the
   green log truck parked beside the cabin. (The Godot meshes load in a few seconds after you press Play; simple
   stand-ins show until they do.)
3. Follow **Getting started** at the top left. The controls are the Godot game's:
   - **E** on the chopping block takes the hatchet. **1**-**9** or the mouse wheel switch tools; **Q** puts the one in
     your hand down, and **E** on it picks it up again.
   - **Left click** a tree to peel its bark. Bare hands hurt on everything but the grey shagbark hickory, and if
     you keep going you faint and wake up on the porch.
   - **E** on a bark sheet picks it up, and **E** again drops it. Put some in the back of the truck.
   - **E** on the truck sends it to the mill. It honks and drives off down the road, and you're paid when it gets
     there.
   - **E** on the computer in the cabin opens TimberMart. Buying puts in an order: the delivery van brings a box to
     the dock; click it to open it and **E** takes what's inside. **Shift** sprints.
   - **Hold** the button with saws, drills, the planer, the pressure washer and the vacuums; **hold and let go** with
     the Thunder Axe. **Tab** opens the TimberPhone once you have one.
   - Put a sapling down on open ground and leave it: it grows into a tree in five minutes.
4. **Two players:** go to the **Test** tab > **Clients and Servers** > **2 Players** > **Start**. Peel a tree in one
   window and watch the bark come off in the other.

**When something goes wrong,** copy the red lines from the Output window (in the client windows and the server
window) and send them to me.

## Saving your work in Studio
- **The code** lives in the `roblox` folder (and Git), not in the place file. Rojo puts it into Studio each time you
  connect.
- **What you build by hand in Studio** (the map, models) lives in the place: use **File > Publish to Roblox** to
  keep it.
