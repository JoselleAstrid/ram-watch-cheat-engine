# Run a specific game and layout


## Browse the Lua files for a game and layout

1. Get a code editor that supports Lua syntax highlighting. It's generally easier to read code with syntax highlighting:

   <img src="img/code-editor_no-highlighting.png" width="400" />
   <img src="img/code-editor_highlighting.png" width="400" />

   - JEdit and Notepad++ are pretty basic code editors that should work.
   
   - If you don't have a code editor and don't feel like downloading one, you can probably still get through this tutorial with just Notepad. If you're writing layouts or game scripts later, though, you'll most likely want a code editor.

   - If you end up writing a lot of Lua, consider ZeroBrane Studio for features like code completion and jumping to definitions.

1. Look in the `games` folder. Ignore the files containing the word "layouts" for the moment. You'll see files like `fzerogx.lua` and `supermariogalaxy.lua`. Pick a game that you have an ISO for.

   - If you can't get an ISO for any of those games, you'll have to get to the [game script section](write_game_script.md) in order to run a script.
   
1. Open the game's Lua file in your code editor. Do a Ctrl+F for `supportedGameVersions`. The first result should show which game versions are supported by the game script. For example: 

    ```lua
    GX.supportedGameVersions = {
      na = 'GFZE01',
      us = 'GFZE01',
    }
    ```
    
   This shows support for the North American version, which is also aliased as the US version.
   
   In this case there is basically only one version supported. But if there are multiple distinct versions supported, make a note of which version you want to use.
   
1. Now look at the layouts for the game you picked. F-Zero GX's layouts should be in `games/fzerogx_layouts.lua`. Both Super Mario Galaxy 1 and 2 have layouts in `games/supermariogalaxy_layouts.lua`. Open your game's layouts file in your code editor.

   Let the indentation and line spacing guide you when browsing this file. The majority of a layouts file is formatted like this:

    ```lua
    layouts.addressTest = subclass(Layout)
    function layouts.addressTest:init()
      -- ...
    end
    
    
    layouts.kmhRecording = subclass(Layout)
    function layouts.kmhRecording:init()
      -- ...
    end
    
    
    layouts.energy = subclass(Layout)
    function layouts.energy:init(numOfRacers)
      -- ...
    end
    ```
    
   The names of the layouts here are `addressTest`, `kmhRecording`, and `energy`. Pick a layout that seems interesting, and make a note of the name.
   
   - For Super Mario Galaxy 1 and 2, some layouts will say `-- SMG1 only` or `-- SMG2 only` above the layout definition. If you're going to run SMG1, avoid the layouts that say SMG2 only, and vice versa.


## Running

1. Start Dolphin, and start your game. You can pause emulation for now.

1. Start Cheat Engine. Click the computer icon to select a process. Open Dolphin.exe.
   
1. In the Cheat Engine menu, go to Table -> Show Cheat Table Lua Script. Paste the following script in there:

    ```lua
    RWCEMainDirectory = [[C:/path/to/ram-watch-cheat-engine]]
    
    RWCEOptions = {
      gameModuleName = 'yourgamenamehere',
      gameVersion = 'yourgameversionhere',
      layoutName = 'yourlayoutnamehere',
    
      -- Addresses for Dolphin 5.0
      frameCounterAddress = 0x00E8CF60,
      oncePerFrameAddress = 0x004F4495,
    }
    
    local loaderFile, errorMessage = loadfile(RWCEMainDirectory .. '/loader.lua')
    if errorMessage then error(errorMessage) end
    loaderFile()
    ```
    
1. Change the `RWCEMainDirectory` line as described in the [first tutorial section](run.md#running).

1. In place of `yourgamenamehere`, put the name of the game script you want to use.

   - For example, if you want to use `fzerogx.lua`, then edit this line to read `gameModuleName = 'fzerogx',`.

1. In place of `yourgameversionhere`, specify the game version you want to use.

   - For example, if you want the version specified in `fzerogx.lua` as `na = 'GFZE01',`, then edit this line to read `gameVersion = 'na',` or `gameVersion = 'NA',`. Game versions are not case sensitive.

1. In place of `yourlayoutnamehere`, put the name of the layout you want to use.

   - For example, edit this line to read `layoutName = 'kmhRecording',`. Layout names ARE case sensitive.

1. Click the Execute Script button at the bottom of the Lua script window. If all went well, a new window should appear, displaying RAM values from the game.

   - If you've got a paused Dolphin game, you may have to advance at least one frame for the values to display.
   
   - Making the pre-defined layouts robust is an ongoing effort. Some layouts get an error if you run them in a menu or during game startup. If this happens, make sure you are in the middle of gameplay before clicking Execute Script.
   
   - If you still got an error, check the error message. If you need help, copy the entire error message and paste it when you ask for help. (Note: The latest Lua error appears BELOW previous errors in the Lua Engine window.)
   
   - For certain layouts (the breakpoint based ones), closing the RAM display window will unavoidably cause an error on the next frame the game runs. It's a bit annoying, but don't worry about it. It shouldn't have any consequence other than making a debug-view window pop up (which you can also close).

1. Go back to the layouts Lua file and pick a different layout. Edit the layout name, and click Execute Script again. A new window should appear with the new layout. (You can now close the old layout window, as it's no longer in use.)

   - Some of the layouts will show a button that, when clicked, will start recording RAM values to a `ram_watch_output.txt` file. This file will be in one of two places: (A) The same folder as the .CT (cheat table) file you have open, or (B) The same folder as the Cheat Engine .exe file, if you don't have a .CT file open.
   
   
## Layouts with options

Some layouts support options that let you tweak the layout. Let's go through a few examples.

```lua
layouts.energy = subclass(Layout)
function layouts.energy:init(numOfRacers)
  numOfRacers = numOfRacers or 6

  -- ...
end
```
    
There is one option available here: `numOfRacers`. The line `numOfRacers = numOfRacers or 6` shows that the default value is `6`. This is the value of `numOfRacers` if you don't specify a value yourself.
   
If the default value is a number, you can try specifying a different number and see how the layout changes. In this example, you might try `1` or `8`.
   
Here's how you specify layout options:

```lua
...

RWCEOptions = {
  gameModuleName = 'yourgamenamehere',
  gameVersion = 'yourgameversionhere',
  layoutName = 'yourlayoutnamehere',
  layoutOptions = {8},

  ...
}

...
```
   
That is, we add a `layoutOptions = {...},` line, where our options are listed between the curly braces.
   
- If you're coming from other programming languages and you're wondering what this `{}` syntax is, you can read about [Lua tables](http://lua-users.org/wiki/TablesTutorial).
   
Here's an example of a layout with multiple options:
    
```lua
layouts.inputs = subclass(Layout)
function layouts.inputs:init(calibrated, playerNumber)
  calibrated = calibrated or false
  playerNumber = playerNumber or 1

  -- ...
end
```
    
The options here are `calibrated` and `playerNumber`.
    
We might specify the options as `layoutOptions = {true, 2},` here. When there's multiple options, you need to separate them with commas.
   
If an option's default value is `true` or `false`, you can assume both `true` and `false` are valid values for that option. These are Lua's boolean values.
    
From here, hopefully most of the layouts' options will be either self-explanatory, simple to figure out with experimentation, or explained by a code comment (comments are the lines starting with `--`). If you think any of the pre-defined layouts have unclear options, you can [ask about it](/README.md#support).


## Window-level options

The following options are available regardless of your layout:

```lua
...

RWCEOptions = {
  ...
  
  windowPosition = {300, 500},

  ...
}

...
```

- The `windowPosition` line puts the RAM display window 300 pixels from the left edge of your computer screen, and 500 pixels from the top edge. If you don't specify `windowPosition`, the window appears near the center of the screen. You can drag the window wherever you want, of course, but it can be convenient to make the window start at a specific spot automatically.

---

[Back to the tutorial index](index.md)
