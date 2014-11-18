# ram-watch-cheat-engine

RAM watch display examples, using Lua scripts in Cheat Engine.

Basic use of Cheat Engine lets you display RAM values in real time while a game is running, but with the Lua scripting feature, you can get a much more customized display, which has several advantages:

* You can limit the number of decimal places in a float, perform math on values and display the result, deal with arbitrary pointer schemes, deal with weird data formats like mixed little/big endian, and so on.
* You're not constrained to Cheat Engine's normal display, which has small text and doesn't update at 60 frames per second.
* With a script, it's much easier to build upon previous results. Instead of entering the same pointer base for 10 different cheat table entries, you can save that pointer to a Lua variable and re-use that variable.
* You can add GUI elements to your custom display that just make your work easier. The examples here show how to make a button that starts recording values to a .txt file (which can then be pasted into a spreadsheet for further analysis, e.g. making a graph of your character's speed).

Included here are examples for a few Dolphin emulator games, and a PC game.


# What you'll need

* The Lua scripts in this repository. Download the ZIP of this repository, and extract it somewhere on your computer.

* Cheat Engine, a software that lets you read, scan, and manipulate memory values of running programs: http://www.cheatengine.org/ These scripts have mainly been tested with Cheat Engine 6.3 (64-bit version). If you have problems getting the scripts to work on later versions, feel free to post a GitHub issue here.

* A code editor that supports Lua syntax highlighting. I personally use JEdit.


# Getting it to run

If you are using this for a Dolphin game: Open `dolphin.lua` that you downloaded from this repository, and edit it according to the steps in that file's comments. The easiest way is to download a specific version of Dolphin listed in `dolphin.lua`, and uncomment the line for that version, as explained there. You can download specific versions here: https://dolphin-emu.org/download/

Start up Cheat Engine. In the Cheat Engine menu, go to Table -> Show Cheat Table Lua Script. Paste the following script in there:

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

You need to edit the first two lines of this script:

1. in place of `"sample"`, put the name of the game-specific script you want to run. The `games` directory contains the game-specific scripts. Try to get an existing game script running as a first step, even if you're not particularly interested in RAM watching any of those games. Pick a game script and enter its name in double quotes; for example, if it's `sample.lua`, enter `"sample"`.

2. After `local scriptDir = `, enter the file path to the location where you extracted this repository's ZIP file. If it's a Windows file path, you need to put two backslashes `\\` whenever you really mean one backslash. Do not end the file path with any slashes or backslashes. For example, if the `utils.lua` that you extracted is located at `C:\Cheat Engine\RAM watch scripts\utils.lua`, then this line should say `local scriptDir = "C:\\Cheat Engine\\RAM watch scripts"`.

Start up the game you want to RAM watch. (In Dolphin, this means starting Dolphin and then starting the game of your choice.) Then in Cheat Engine, open your game's process (e.g. Dolphin.exe).

Now, click the Execute Script button at the bottom of the Lua script window. If all went well, a little window should appear, displaying RAM values from the game. (If it's a Dolphin game and you have it paused, you will have to advance at least one frame for the values to display.)

(TODO: Trying different layouts; Saving the script for next session; Making your own game specific script)


# Performance note

Running one of these scripts alongside your game may cause the game to run slower. Generally, it seems to get worse if you've clicked Execute Script many times while testing, and in this case closing and re-opening Cheat Engine may make it better. But I could be wrong.

If you can identify a particular part of the example scripts that is making things slow, feel free to post a GitHub issue about it, and I'll look into it.


# Future plans

* Tutorial video.
* Make an example script for a PC game that is easier to acquire.
* Port to MHS (Memory Hacking Software)? It's more popular than Cheat Engine among speedrunners/TASers at this time of writing, perhaps for good reason since the UI seems a lot cleaner. However, porting these scripts is dependent on (1) MHS's capacity for customizable GUIs, and (2) whether I'm any good at coding in C, which is MHS's scripting language. If anyone else is up for the task, feel free to do it.


# Acknowledgments

Masterjun, for writing the RAM watch script (2013/08/26) that this project was based on: http://pastebin.com/vUCmhwMQ
