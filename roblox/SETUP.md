# Setting up Timber for Roblox

About 20 minutes. You need Roblox Studio and VS Code, both of which you have.

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
   - 35 trees of all seven species in a ring around the spawn
   - a green log truck just ahead of you
3. Try the core loop:
   - **Peel:** walk to a tree and **left click** it with the white dot on the bark. Bark sheets fall off. With bare
     hands it hurts, except on the grey shagbark hickories.
   - **Carry:** look at a sheet and press **E** to pick it up, and **E** again to drop it in the truck bed.
   - **Sell:** hold **E** on the truck's "Ship to the mill" prompt. You get money; check the player list at the top
     right.
4. **Two players:** go to the **Test** tab > **Clients and Servers** > **2 Players** > **Start**. Peel a tree in one
   window and watch the bark come off in the other.

**When something goes wrong,** copy the red lines from the Output window (in the client windows and the server
window) and send them to me.

## Saving your work in Studio
- **The code** lives in the `roblox` folder (and Git), not in the place file. Rojo puts it into Studio each time you
  connect.
- **What you build by hand in Studio** (the map, models) lives in the place: use **File > Publish to Roblox** to
  keep it.
