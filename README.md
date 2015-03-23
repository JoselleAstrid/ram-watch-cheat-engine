# ram-watch-cheat-engine

RAM watch display examples, using Lua scripts in Cheat Engine.

Basic use of Cheat Engine lets you display RAM values in real time while a game is running, but with scripting you can get a much more customized display, which has several advantages:

* You're not constrained to Cheat Engine's address list display. You can set your font size and style, limit the number of decimal places in a float, perform math on values and display the result, deal with arbitrary pointer schemes, deal with weird data formats like mixed little/big endian, and so on.
* With a script, it's much easier to build upon previous results. Instead of entering the same pointer base for 10 different cheat table entries, you can save that pointer to a Lua variable and re-use that variable.
* You can add GUI elements to your custom display that just make your work easier. The examples here show how to make a button that starts recording values to a .txt file (which can then be pasted into a spreadsheet for further analysis, e.g. making a graph of your character's speed).

Included here are examples for a few Dolphin emulator games, and a PC game.


# What you'll need

* The Lua scripts in this repository. Download the ZIP of this repository, and extract it somewhere on your computer.

* Cheat Engine, a software that lets you read, scan, and manipulate memory values of running programs: http://www.cheatengine.org/

  * If you want a non-installable version of Cheat Engine (which also skips the recommendation of other software), go to the "Downloads" link on the left menu and find the appropriate download link.

  * These Lua scripts are meant to work with Cheat Engine 6.3 or later. If you have problems getting the scripts to work on any version from 6.3 or later, feel free to post a GitHub issue here.
  
  * As of 2015/03/23, there is no Mac version of this program.
 
* (If you're using this for a Dolphin game) A 64-bit version of the Dolphin emulator.

* A code editor that supports Lua syntax highlighting. I personally use JEdit or Notepad++.


# How to use

### Running for the first time

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

1. In place of `"sample"`, put the name of the game-specific script you want to run. The `games` directory contains the game-specific scripts. Try to get an existing game script running as a first step, even if you're not particularly interested in RAM watching any of those games. Pick a game script and enter its name in double quotes; for example, if it's `sample.lua`, enter `"sample"`.

2. After `local scriptDir = `, enter the file path to the location where you extracted this repository's ZIP file. If it's a Windows file path, you need to put two backslashes `\\` whenever you really mean one backslash. Do not end the file path with any slashes or backslashes. For example, if the `utils.lua` that you extracted is located at `C:\Cheat Engine\RAM watch scripts\utils.lua`, then this line should say `local scriptDir = "C:\\Cheat Engine\\RAM watch scripts"`.

Start up the game you want to RAM watch. For Dolphin, this means starting Dolphin and then starting the game of your choice. Then in Cheat Engine, open your game's process (e.g. Dolphin.exe).

Now, click the Execute Script button at the bottom of the Lua script window. If all went well, a little window should appear, displaying RAM values from the game. (If it's a Dolphin game and you have it paused, you will have to advance at least one frame for the values to display.)

If you get an error, check the error message. (Note: The latest Lua error appears BELOW previous errors in the Lua Engine window.) The error message may have suggestions for you to fix the situation. For example, it may tell you to specify an address in `dolphin.lua`.

### Saving a Cheat Table for next session

With Lua scripts, you don't have to save addresses to the address list in Cheat Engine's normal UI. However, it's still useful to save a cheat table (.CT) file to save the script where you've specified the game `name` and your `scriptDir`. So click the save icon in Cheat Engine and save as a .CT file. Next time you do RAM watching, you can open this cheat table instead of having to paste in the Lua script again.

Note: Cheat Engine sometimes crashes when you are trying to open a cheat table. I think this either happens if you open it too quickly after starting Cheat Engine, or open it too quickly after selecting your game's process. If it happens to you, then you'll have to move a little slower next time. It's not a huge deal, but it can be annoying if you have to keep re-opening Cheat Engine for whatever reason.

### Trying different GUI layouts

In each game-specific script (such as `fzerogx.lua` for F-Zero GX), there's a line that says `*** CHOOSE YOUR LAYOUT HERE ***`.

Above that line you can find the names of the various layouts; for example, `sample.lua` has `layoutA` and `layoutB`.

Below that line you can specify which display layout you want to use. Try editing this line of code to specify a different layout, then save your changes. Go back to Cheat Engine and click Execute Script again. A new window should appear with the new layout. (You can now close the old window, as it's no longer in use.)

Some of the example layouts include a button that lets you take RAM values to a `stats.txt` file. This file will be in one of two places: (A) The same directory as the cheat table you have open, or (B) The same directory as the Cheat Engine .exe file, if you don't have a cheat table open. The file will contain one value per line, with one value taken per frame. You can copy the entire file's contents and paste into a spreadsheet column for further analysis.

### Making your own game specific script

If you are ready to do some scripting of your own, I recommend starting with `sample.lua`. This is the simplest script to understand. The other scripts have more structure to them, which can be useful if you have a bunch of possible RAM values to look at or a bunch of different layouts. But to start off, start by using `sample.lua` as a template, modify the code within layoutA or layoutB, and try it out.

Tips if (more like when) your script isn't working as expected:

* If your script gets an error, the game will pause and Cheat Engine will make the Memory View and Lua Engine windows pop up. If you try to close the Memory View window, the game will resume and will probably error again immediately. The cleanest way to get out of this is to re-open the game process in Cheat Engine. This will deactivate the Lua script until you click Execute Script again.
* There is a debug-display function included, called `debugDisp`. This lets you show debug values on your display window. Open `utils.lua` and locate the part that says `local function debugDisp`. Read the comments above that part to find out how to use `debugDisp`. I recommend using this in conjunction with `utils.intToHexStr`, which lets you display memory addresses in hex.

### Common issues

* The Dolphin game scripts may be prone to errors while the Dolphin game is just starting up. If you need to restart a Dolphin game for whatever reason and you don't want the script to get an error, first use the previous tip of deactivating the Lua script by re-selecting Dolphin.exe in Cheat Engine. Then, once your game has reached the title screen or something, try executing the script again.
* If you're having trouble getting any Dolphin memory values to show properly, it's possible that the script can't find the game start address for your version of Dolphin. Try a different Dolphin version and see if that works fine. If a certain Dolphin version doesn't seem to work, feel free to post a GitHub issue here saying so.


# Performance note

Running one of these scripts alongside your game may cause the game to run slower, especially if the script uses a breakpoint to run the code. Using Cheat Engine's Timer class has noticeably better performance than using breakpoints, even for very simple Lua scripts. (Credit to Miles for finding that the Timer class was better.)

Also, it seems like the script may run slower if you've clicked Execute Script many times while testing, and in this case closing and re-opening Cheat Engine may make it better. (But I could be wrong.)

If you can identify a particular part of the example scripts that is making things slow, feel free to post a GitHub issue about it, and I'll look into it.


# Future plans

* Tutorial video.
* Make an example script for a PC game that is easier to acquire.
* Port to MHS (Memory Hacking Software)? It's more popular than Cheat Engine among speedrunners/TASers at this time of writing, perhaps for good reason since the UI seems a lot cleaner. However, porting these scripts is dependent on (1) MHS's capacity for customizable GUIs, and (2) whether I'm any good at coding in C, which is MHS's scripting language. If anyone else is up for the task, feel free to go for it.


# Acknowledgments

Masterjun, for writing the RAM watch script (2013/08/26) that this project was based on: http://pastebin.com/vUCmhwMQ
