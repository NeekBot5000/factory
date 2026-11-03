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

## Turning on the game's own sounds (once)
All the Godot game's sounds (chops, the axe, whooshes, coins, the breeze, birds and the guitar music) are in one
audio file, `roblox/sounds/timber-sounds.ogg`. Roblox can only play audio that's been uploaded to it, so upload it
once:
1. In Studio, open **View > Asset Manager**, click **Bulk Import** (the button with the arrow), and pick
   `timber-sounds.ogg`. (Or upload it on create.roblox.com > Creations > Development Items > Audio.)
2. When it shows up under **Audio**, right-click it > **Copy Asset ID**.
3. Send me the number. I'll put it in `Config.SoundSheetId`, and Live Sync brings it into your place.

Until then, a few of Roblox's built-in sounds stand in.

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
2. The server builds a test world:
   - 40 trees of all seven species, with six right by the spawn
   - a green log truck on your left and the TimberMart tool stall on your right
3. Follow the goal at the top of the screen (a bouncing arrow marks where to go):
   - **Peel:** walk to a tree and **left click** it with the white dot on the bark. Bark sheets fall off. With bare
     hands it stings, except on the grey shagbark hickories.
   - **Carry:** look at a sheet and press **E** to pick it up, and **E** again to drop it in the truck bed.
   - **Sell:** hold **E** on the truck's "Ship to the mill" prompt. The money counter at the top counts up.
   - **Buy:** hold **E** at the TimberMart stall and buy the hatchet. It appears in your hotbar (key **1**).
4. **Two players:** go to the **Test** tab > **Clients and Servers** > **2 Players** > **Start**. Peel a tree in one
   window and watch the bark come off in the other.

**When something goes wrong,** copy the red lines from the Output window (in the client windows and the server
window) and send them to me.

## Saving your work in Studio
- **The code** lives in the `roblox` folder (and Git), not in the place file. Rojo puts it into Studio each time you
  connect.
- **What you build by hand in Studio** (the map, models) lives in the place: use **File > Publish to Roblox** to
  keep it.
