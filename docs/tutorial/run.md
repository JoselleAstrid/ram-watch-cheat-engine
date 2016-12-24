# Tutorial: Get a RAM watch script up and running


## Downloads and installations

1. Download the Lua scripts in this GitHub repository.

   - On this repository's main page, there should be a "Clone or download" button. Click it, then click "Download ZIP". Extract the .zip file somewhere on your computer.
   
   - Alternatively, if you're familiar with Git, you can do a `git clone`.

1. Download Cheat Engine. Either get the installable file and install it, or download the .rar archive file and extract it: http://www.cheatengine.org/downloads.php

   - Read a couple of paragraphs down on the page to find the archive file. As of Cheat Engine 6.6, you'll need a recent version of 7-Zip or WinRAR to extract the archive.

   - The Lua scripts are meant to work with Cheat Engine 6.3 or later, with the latest version being recommended.
   
   - To run in Linux, you'll have to download both Cheat Engine and the CE "Server". Then run the server in Linux, run CE itself in Wine, and connect the two processes. This should let you use Cheat Engine on games running in Linux.

   - As of Cheat Engine 6.6, there is no Mac version available.

1. Download and install Dolphin 5.0, 64-bit: https://dolphin-emu.org/download/

   - If you have a different Dolphin version and don't feel like downloading 5.0, you'll need to [scan for a couple of addresses](different_dolphin.md) before you execute your script.

   - If you don't want to run a Dolphin game, things might get tricky because this tutorial focuses on Dolphin first. You'll probably have to read on until the [non-Dolphin page](non_dolphin.md) before you can run a script.

   - Dolphin properly supports Linux, so it doesn't have to run in Wine.
   
1. Obtain a Metroid Prime ISO, North American [version 0-00](http://www.metroid2002.com/version_differences_version_number.php).

   - If you don't have this Metroid Prime ISO, but you have another Gamecube/Wii ISO which has a corresponding Lua script here (e.g. Super Mario Galaxy NA/EU/JP), skip to: [Run a specific game and layout](choose_game_and_layout.md).
   
   - If you're not sure whether you have version 0-00: Right-click the game in Dolphin, click Properties, and click the Info tab. Revision should be 0.


## Running
   
1. Start Dolphin 5.0. Start Metroid Prime, and enter a file. You can pause emulation for now.

1. Start Cheat Engine.

   - `Cheat Engine.exe` should work. It's a launcher which will choose `cheatengine-i386.exe` on 32-bit systems, and `cheatengine-x86_64.exe` on 64-bit systems. ([Source](http://forum.cheatengine.org/viewtopic.php?t=572868))
   
1. In Cheat Engine, go to Edit -> Settings. Go to Scan Settings. Make sure MEM_MAPPED is checked. (Leave MEM_PRIVATE and MEM_IMAGE checked as well.)
   
1. In Cheat Engine, click the computer icon to select a process. Open Dolphin.exe.
   
1. In the Cheat Engine menu, go to Table -> Show Cheat Table Lua Script. Paste the following script in there:

    ```lua
    RWCEMainDirectory = [[C:/path/to/ram-watch-cheat-engine]]
    
    RWCEOptions = {
      gameModuleName = 'sample',
      gameVersion = 'na_0_00',
      layoutName = 'positionAndVelocity',
    
      -- Addresses for Dolphin 5.0
      frameCounterAddress = 0x00E8CF60,
      oncePerFrameAddress = 0x004F4495,
    }
    
    local loaderFile, errorMessage = loadfile(RWCEMainDirectory .. '/loader.lua')
    if errorMessage then error(errorMessage) end
    loaderFile()
    ```

1. Change the first line of this script: After `RWCEMainDirectory = `, enter the path to the folder where you extracted this repository's ZIP file. Either forward slashes or backslashes should be fine. Do not end the file path with a slash or backslash. For example, if the `runner.lua` file that you extracted is located at `C:/Games/ram-watch-cheat-engine/runner.lua`, then this line should say `RWCEMainDirectory = [[C:/Games/ram-watch-cheat-engine]]`.

1. Click the Execute Script button at the bottom of the Lua script window. If all went well, a new window should appear, displaying RAM values from the game.

   - If you've got a paused Dolphin game, you may have to advance at least one frame for the values to display.

   - If you got an error, check the error message. To try the script again, click Execute Script again. A new display window will pop up. You can close the old display window, as it'll no longer update.
   
   - If you need help, copy the entire error message and paste it when you ask for help. (Note: The latest Lua error appears BELOW previous errors in the Lua Engine window.)
   
   - To stop running the script, close the RAM display window.

1. Save a Cheat Table file for your next session.

   - Click the save icon in Cheat Engine and save as a .CT file.
   
   - Next time you want to use a RAM watch script, you can open this Cheat Table file instead of having to type the Lua code again.

---

You're off to a good start if you made it this far. Try the next [tutorial](index.md) section!
