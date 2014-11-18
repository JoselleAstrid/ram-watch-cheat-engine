ram-watch-cheat-engine
======================

RAM watch display examples using Cheat Engine. These scripts display RAM values in real time while the game is running. Included here are examples for Dolphin emulator games and a PC game.


How to use
==========

Download the ZIP of this repository, and extract it somewhere on your computer.

If you are using this for a Dolphin game, open `dolphin.lua` and edit it according to the steps in the comments. The easiest way is to download a specific version of Dolphin listed in `dolphin.lua`, and uncomment the line for that version, as explained there.

Start up the game you want to RAM watch.

Start up Cheat Engine, and open your game's process (e.g. Dolphin.exe). In the Cheat Engine menu, go to Table -> Show Cheat Table Lua Script. Paste the following script in there:

    local name = "sample"
    local scriptDir = "C:\\path\\to\\Cheat\\Engine\\scripts\\directory"
    
    if package.loaded[name] then
      -- Not first load; clear cache
      package.loaded[name] = nil
    else
      -- First load; add our script directories to the Lua path
      package.path = package.path .. ";" .. scriptDir .. "\\?.lua"
      package.path = package.path .. ";" .. scriptDir .. "\\games\\?.lua"
    end
    require(name)

You need to edit the first two lines of this script. First, in place of `"sample"`, put the name of the game-specific script you want to run. The `games` directory contains the game-specific scripts. Try to get an existing game script running as a first step, even if you're not particularly interested in RAM watching any of those games. Pick a game script and enter its name in double quotes; for example, if it's `sample.lua`, enter `"sample"`.

Second, after `local scriptDir = `, enter the file path to the location where you extracted this repository's ZIP file. If it's a Windows file path, you need to put two backslashes `\\` whenever you really mean one backslash. Do not end the file path with any slashes or backslashes. For example, if the `utils.lua` that you extracted is located at `C:\Cheat Engine\RAM watch scripts\utils.lua`, then this line should say `local scriptDir = "C:\\Cheat Engine\\RAM watch scripts"`.

Now, click the Execute Script button at the bottom of that Cheat Engine window. If all went well, a little window should appear, displaying RAM values from the game. (If it's a Dolphin game and you have it paused, you will have to advance at least one frame for the values to display.)

(TODO: Trying different layouts; Saving the script for next session; Making your own game specific script)


Acknowledgments
===============

Masterjun, for writing the RAM watch script (2013/08/26) that this project was based on: http://pastebin.com/vUCmhwMQ
