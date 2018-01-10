# Tutorial: Get a RAM watch script up and running


## Downloads and installations

1. Download the Lua scripts in this GitHub repository.

   - On this repository's main page, there should be a "Clone or download" button. Click it, then click "Download ZIP". Extract the .zip file somewhere on your computer.
   
   - Alternatively, if you're familiar with Git, you can do a `git clone`.

1. Download Cheat Engine: http://www.cheatengine.org/downloads.php

   - This project's Lua scripts are meant to work with Cheat Engine 6.3 or later, with the latest version being recommended.

   - Windows: The bigger link at the top has the installer download option, with third-party software recommendation included. Read a couple of paragraphs down on the page to find a non-installer option, as a .rar archive file. You'll need a recent version of 7-Zip or WinRAR to extract the archive.
   
   - Mac: It seems there's only an installer option available, and the Cheat Engine version is a bit old (6.2 at this time of writing), but might still work fine with this Lua framework.
   
   - Linux: You'll have to download both Cheat Engine and the CE "Server". Then run the server in Linux, run CE itself in Wine, and connect the two processes. This should let you use Cheat Engine on games running in Linux.

1. Download and install Dolphin 5.0, 64-bit: https://dolphin-emu.org/download/

   - If you have a different Dolphin version and don't feel like downloading 5.0, you'll need to [scan for a couple of addresses](different_dolphin.md) before you execute your script. Note: Development versions like 5.0-3967 are different from 5.0 for our purposes.

   - If you don't want to run a Dolphin game, things might get tricky because this tutorial focuses on Dolphin first. You'll probably have to keep reading until the [non-Dolphin page](non_dolphin.md) before you can run a script.

   - Dolphin properly supports Linux, so it doesn't have to run in Wine.
   
1. Obtain an ISO for a Gamecube or Wii game that has a script available in this GitHub repository. See [this guide](https://dolphin-emu.org/docs/guides/ripping-games/) on how to rip an ISO from a GC/Wii game disc. The games with scripts available are:
   
   - F-Zero GX, North American version (Game ID: GFZE01)
   
   - Metroid Prime, North American version (GM8E01) [revision 0-00](http://www.metroid2002.com/version_differences_version_number.php)
     
     - If you're not sure whether you have 0-00: Right-click the game in Dolphin, click Properties, and click the Info tab. Revision should be 0.
     
   - Sonic Adventure DX: Director's Cut, North American version (GXSE8P)
   
   - Sonic Adventure 2: Battle, North American version (GSNE8P)
       
   - Super Mario Galaxy; North American (RMGE01), European (RMGP01), or Japanese (RMGJ01) version
   
   - Super Mario Galaxy 2, North American version (SB4E01)
   
   - Alternatively, if you know someone with a script for a different game, then you can use that script and game instead. There is a later tutorial section on [writing your own game script](write_game_script.md), but for now it's just easier if you can try out an existing script first.


## Running
   
1. Start Dolphin 5.0. Start your game. Get into a part of the game where you can move your character: enter a file in Metroid Prime or Super Mario Galaxy, start a race in F-Zero GX, etc. You can pause emulation for now.

1. Start Cheat Engine.

   - Double-clicking `Cheat Engine.exe` should work. It's a launcher which will choose `cheatengine-i386.exe` on 32-bit systems, and `cheatengine-x86_64.exe` on 64-bit systems. ([Source](http://forum.cheatengine.org/viewtopic.php?t=572868))
   
1. In Cheat Engine, go to Edit -> Settings. Go to Scan Settings. Make sure MEM_MAPPED is checked. (Leave MEM_PRIVATE and MEM_IMAGE checked as well.)
   
1. In Cheat Engine, click the computer icon to select a process. Open Dolphin.exe.
   
1. In the Cheat Engine menu, go to Table -> Show Cheat Table Lua Script. Paste the following script in there:

    ```lua
    RWCEMainDirectory = [[C:/path/to/ram-watch-cheat-engine]]
    
    RWCEOptions = {
      gameModuleName = 'metroidprime',
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

1. Change the first line of the script: After `RWCEMainDirectory = `, enter the path to the folder where you extracted this repository's ZIP file. Either forward slashes or backslashes should be fine. Do not end the file path with a slash or backslash. For example, if the `runner.lua` file that you extracted is located at `C:/Games/ram-watch-cheat-engine/runner.lua`, then this line should say `RWCEMainDirectory = [[C:/Games/ram-watch-cheat-engine]]`.
    
1. Change the `gameModuleName`, `gameVersion`, and `layoutName` according to the game you've chosen:
    
    Game | Version | `gameModuleName` | `gameVersion` | `layoutName`
    --- | --- | --- | --- | ---
    F-Zero GX | North America | `'fzerogx'` | `'na'` | `'racerInfo'`
    Metroid Prime | North America 0-00 | `'metroidprime'` | `'na_0_00'` | `'positionAndVelocity'`
    Sonic Adventure DX: Director's Cut | North America | `'sonicadventuredx'` | `'na'` | `'coordsAndInputs'`
    Sonic Adventure 2: Battle | North America | `'sonicadventure2battle'` | `'na'` | `'coordsAndInputs'`
    Super Mario Galaxy | North America | `'supermariogalaxy'` | `'na'` | `'positionAndInputs'`
    Super Mario Galaxy | Europe | `'supermariogalaxy'` | `'eu'` | `'positionAndInputs'`
    Super Mario Galaxy | Japan | `'supermariogalaxy'` | `'jp'` | `'positionAndInputs'`
    Super Mario Galaxy 2 | North America | `'supermariogalaxy2'` | `'na'` | `'positionAndInputs'`

1. Click the Execute Script button at the bottom of the Lua script window. If all went well, a new window should appear, displaying RAM values from the game.

   - If you've paused emulation in Dolphin, you may have to advance at least one frame for the values to display.

   - If you got an error, check the error message. To try the script again, click Execute Script again. A new display window will pop up. You can close the old display window, as it'll no longer update.
   
   - If you need help, copy the entire error message and paste it when you ask for help. (Note: The latest Lua error appears BELOW previous errors in the Lua Engine window.)
   
   - To stop running the script, close the RAM display window.

1. Save a Cheat Table file for your next session.

   - Click the save icon in Cheat Engine and save as a .CT file.
   
   - Next time you want to use the RAM watch script, you can open this Cheat Table file instead of having to paste/type the Lua code again.

---

You're off to a good start if you made it this far. Try the next [tutorial](index.md) section!
