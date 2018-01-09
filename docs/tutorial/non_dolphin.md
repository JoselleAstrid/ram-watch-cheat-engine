# Non-Dolphin scripts

We've occasionally noted small differences between Dolphin and non-Dolphin scripts, but in the interest of keeping the tutorial streamlined, we haven't gone far out of the way for non-Dolphin yet. This section aims to cover some important differences for non-Dolphin games.


## A minimal non-Dolphin game script

Compared to [a Dolphin game script](write_game_script.md#write-a-dolphin-game-script), this isn't too different:

```lua
package.loaded.utils = nil
local utils = require 'utils'
local subclass = utils.subclass

package.loaded.game = nil
local gameModule = require 'game'

local MyGame = subclass(gameModule.Game)

MyGame.layoutModuleNames = {'mygame_layouts'}
MyGame.framerate = 60

return MyGame

```

- We now subclass `Game` instead of `DolphinGame`.

- There's no `supportedGameVersions`. This is not to suggest that game versions are unimportant for non-Dolphin games. It just means we know how to handle game versions uniformly for Dolphin games, but not for any game ever. If you want your non-Dolphin script to support multiple game versions, then you can implement that on your own.


## Game start address

The Lua framework provides a `getGameStartAddress()` function which only works for Dolphin games. The function was [covered here](write_game_script.md#defining-and-accessing-base-addresses).

Non-Dolphin emulators and games, in general, will have different methods for getting a useful start address.

For PC games, here is one common way to get a useful start address - use Cheat Engine's built-in function `getAddress` and pass in the executable filename of your game:

```lua
function MyGame:init(options)
  gameModule.Game.init(self, options)

  self.startAddress = getAddress('mygame.exe')
end
```

The [constantGameStartAddress](different_dolphin.md#optional-constantgamestartaddress) option is not available for non-Dolphin games. This isn't a problem though, because if your non-Dolphin game's start address is constant (say, 0x800000), then you simply use the line `self.startAddress = 0x800000`.


## `frameCounterAddress` and `oncePerFrameAddress`

Non-Dolphin games still need to define these addresses to run breakpoint-based layouts (which update once every frame). However, there are differences from [how it works for Dolphin](different_dolphin.md).

First of all, these addresses aren't specified as options in the Cheat Table script. You'll have to define the address computations directly in the game script:

```lua
function MyGame:init(options)
  gameModule.Game.init(self, options)

  self.startAddress = getAddress('mygame.exe')

  self.frameCounterAddress = self.startAddress + 0x10B750
  self.oncePerFrameAddress = self.startAddress + 0xE0F7
end
```

The reason is that the Dolphin way of computing these addresses (start address + constant value) might not work for every other emulator and game ever. Maybe in some games, the most suitable addresses would end up being pointer based, requiring a more complex computation.

Finding the addresses [basically works the same way as Dolphin](different_dolphin.md#finding-the-framecounteraddress), with a couple of differences.

If you're running a non-emulated PC game, you might not have a way to frame advance. However, you can still try repeated scans for an increased value (without specifying how much it has increased by).
  
In Dolphin 5.0, there will be 2 green (static) addresses which are based off of Dolphin.exe. However, there is no general rule across other emulators and games. So, it may not be obvious which frame counter is the best to pick.
  
- Note that games tend to have a lot of "smaller" frame counters which reset under certain conditions. Try going through different menus and levels to get most of the counters to reset. Then use one of the remaining counters as your `frameCounterAddress`.
    
- When you open the Memory Viewer dialog for a potential `frameCounterAddress`, you probably want to see your game's .exe filename (as opposed to a different .exe or a .dll) followed by a hexadecimal address. However, this process hasn't been tested with many PC games, so it's possible that there are some games where you can't find a `frameCounterAddress` like this.


## Reading memory values

When you read from game memory, you need to figure out whether to use Big Endian functions like `readFloatBE()`, or Little Endian functions like `readFloatLE()`.
 
Gamecube and Wii games use Big Endian. Most PC games use Little Endian. If you are using an emulator for a system other than Gamecube/Wii, you should look up the endianness of that system.
