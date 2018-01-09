# Write a game script

When your Cheat Table script specifies a game called `mygame`, the Lua framework looks for a Lua file called `mygame.lua`. How do we write this Lua file?


## Write a Dolphin game script

This is pretty much the bare minimum code required for a Dolphin game's script:

```lua
package.loaded.utils = nil
local utils = require 'utils'
local subclass = utils.subclass

package.loaded.dolphin = nil
local dolphin = require 'dolphin'

local MyGame = subclass(dolphin.DolphinGame)

MyGame.supportedGameVersions = {
  na = 'GAME01',
}

MyGame.layoutModuleNames = {'mygame_layouts'}
MyGame.framerate = 60

return MyGame

```

- `supportedGameVersions` was mostly covered [here](games_versions_layouts_options.md#game-versions).

  - To find the 6-character game ID of your Gamecube/Wii game, open Dolphin and right-click your game on the game list. Select Properties. The game ID should be on the title bar of the Properties window. The Info tab also has the game ID.
  
  - For the record, the game ID is only really needed if you don't have a [constantGameStartAddress](different_dolphin.md#optional-constantgamestartaddress). Still, it's easy to find the game ID, and it can be useful for anyone else who wants to use your script. Also, if your script supports multiple versions, you can use an `if`-`else` block to compute addresses differently depending on the game ID.
 
- `layoutModuleNames` specifies which Lua file(s) have layouts for this game, as covered [here](games_versions_layouts_options.md#finding-the-layout-scripts-for-a-particular-game). Note that this can be a comma-separated list of files, like `{'mygame_layouts', 'mygame_layouts_extra'}`.

- `framerate` should be how many frames per second the game runs in.

  - If your game can run at full speed in Dolphin, you can see the game's framerate in the title bar of most Dolphin versions.
  
  - Most Dolphin or PC games run at 60 or 30 frames per second, though some PC games might vary the framerate.
  
  - The framerate currently isn't needed in a lot of layouts. One use is to convert between seconds and frames accurately on data-recording layouts, such as F-Zero GX's `kmhRecording`.

- You can name the `MyGame` variable whatever you want.


## Write and run a layout

[This previous tutorial section](custom_layout.md#recognized-layout-locations-for-your-game) covered the three recognized layout locations for a game.

In this tutorial section, you're defining the game script on your own, so using `layoutModuleNames` makes the most sense.

Make a layouts file for your game (for example, `mygame_layouts.lua`) and add it to `layoutModuleNames`. In the new Lua file, add the very simple layout from [this previous tutorial's example](custom_layout.md#run-a-layout-defined-in-custom_layoutslua).

Then, edit your Cheat Table script with the correct game name and layout name. Click Execute Script. If it worked, then you've successfully run the Lua framework for your own game!


## Finding RAM addresses

To make the game script actually useful, we'll need to add RAM addresses to it. But first we need to find some interesting RAM addresses to display.

This is a matter of learning how to use Cheat Engine with the game you're analyzing. It's knowledge that's not specific to this Lua framework. Try the following:

- [aldelaro's Dolphin + Cheat Engine tutorial](http://tasvideos.org/forum/viewtopic.php?t=17735). If you know CE but haven't used it with Dolphin, note the requirement to add Big Endian value types.

- Cheat Engine's built-in tutorial (open Cheat Engine, then Help -> Cheat Engine Tutorial)

- The [below section](#defining-pointers-and-dynamic-ram-values) explaining pointers and how to find them


## Defining RAM values in the game script


### Defining and accessing base addresses

One key consideration in the Lua scripts is: when should each piece of code run? Here are some possibilities:
 
1. Once only, when the Lua file is first loaded
2. Once only, after some initial setup, including processing the `RWCEOptions`
3. Continually as the script runs, after initial setup is complete

For example, let's consider the game start address of a Dolphin game (assuming we don't use [constantGameStartAddress](different_dolphin.md#optional-constantgamestartaddress)).

We need the Dolphin game's ID to scan for the game start address, so 1 won't work. The game start address does not change as long as we don't restart the game, so 3 would be pretty wasteful (imagine doing a Cheat Engine scan on every game frame!). Option 2 is what we need here. Here's what it looks like:

```lua
function MyGame:init(options)
  dolphin.DolphinGame.init(self, options)

  self.startAddress = self:getGameStartAddress()
end
```

`self:getGameStartAddress()` runs the scan, and we save the result to `self.startAddress` for access later.

The pre-defined `getGameStartAddress` function is only available for Dolphin games. But if you have a non-Dolphin game, it's still useful to find some kind of start address for your game's memory. So you'd replace the `self:getGameStartAddress()` line with the calculations that apply to your game.


### Defining and displaying static RAM values

Let's say you've done some RAM scanning, and found that your X position (a float) is located 0x1082B4 after the start address. How do we get this value and display it?

Here's a function that uses `startAddress` to read the X position from memory, and returns that position as a text string:

```lua
function MyGame:xPositionDisplay()
  local xPositionAddress = self.startAddress + 0x1082B4
  local xPosition = utils.readFloatBE(xPositionAddress)
  return "X position: " .. utils.floatToStr(xPosition)
end
```

- `readFloatBE()` reads a Big-Endian float from the specified memory address. Big Endian is used in Gamecube and Wii game memory. Little Endian is usually used in PC games. There are also functions available like `readFloatLE()` and `readIntBE()` (for integers).

- `floatToStr()` goes from a float value to a text string. It accepts a few options. For example, you can use `utils.floatToStr(xPosition, {afterDecimal=5})` to display 5 decimal places.

- `"X position: "` is a simple text string. You can put `..` between two strings to concatenate (combine) them.

How often should this code be run? Only once, or continually as the script runs? Well, if your position is changing, the only way to display your current position is to continually read your position from memory.

So we'll tell the layout to run this code continually. We can do this by passing a function into `addItem()`.

```lua
layouts.xPosition = subclass(Layout)
function layouts.xPosition:init()
  self:setUpdatesPerSecond(15)
  self.window:setSize(400, 300)

  self:addLabel{x=6, y=6}
  self:addItem(self.game.xPositionDisplay)
end
```

Note that we could have moved the addition operation `self.startAddress + 0x1082B4` so that it's only done once, instead of once per frame. However, this line is very light work for a computer - access variable, do addition, set variable - so it's very unlikely to impact performance.

So far so good. `xPositionDisplay()` is only 5 lines of code - not too outrageous. But once you start finding more and more RAM addresses, those 5 lines can get pretty repetitive. Maybe copy-paste isn't so hard, but the code might end up being hard to read and maintain. Can we do better?

How about 2 lines per RAM address?:

```lua
package.loaded.valuetypes = nil
local valuetypes = require 'valuetypes'

local StaticValue = subclass(valuetypes.MemoryValue)
function StaticValue:getAddress()
  return self.game.startAddress + self.offset
end

MyGame.blockValues.xPosition = valuetypes.MV(
  "X position", 0x1082B4, StaticValue, valuetypes.FloatTypeBE)
MyGame.blockValues.yPosition = valuetypes.MV(
  "Y position", 0x1082B8, StaticValue, valuetypes.FloatTypeBE)
MyGame.blockValues.zPosition = valuetypes.MV(
  "Z position", 0x1082BC, StaticValue, valuetypes.FloatTypeBE)
```

And here's how you would display it:

```lua
layouts.position = subclass(Layout)
function layouts.position:init()
  self:setUpdatesPerSecond(15)
  self.window:setSize(400, 300)

  self:addLabel{x=6, y=6}
  self:addItem(self.game.xPosition)
  self:addItem(self.game.yPosition)
  self:addItem(self.game.zPosition)
end
```

There's a lot more happening behind the scenes now, and explaining it all here might be too much. But hopefully it's clear what you need to change for each value you add:

- The name after `MyGame.blockValues` and `self.game` (these must match). Example: `xPosition`
- The text label. Example: `"X position"`
- The address offset from the `startAddress`. Example: `0x1082B4`
- The value type. Example: `FloatTypeBE` (Float Big Endian)

You can give aliases to a few of the names to shorten the definitions further:

```lua
local GV = MyGame.blockValues
local MV = valuetypes.MV
local FloatType = valuetypes.FloatTypeBE

GV.xPosition = MV("X position", 0x1082B4, StaticValue, FloatType)
GV.yPosition = MV("Y position", 0x1082B8, StaticValue, FloatType)
GV.zPosition = MV("Z position", 0x1082BC, StaticValue, FloatType)
```


### Defining pointers and dynamic RAM values

So far, we've learned how to work with RAM addresses that are based off of the game start address. But this is something that Cheat Engine's basic interface can handle well too, given that the game start address changes rarely (on average, maybe once every few months' worth of Dolphin updates).

However, Cheat Engine's basic interface can be clunky when working with pointers. This is an area where this Lua framework can help a lot.

Basically, a pointer is a RAM value whose purpose is to track the address of another RAM value (or a block of multiple RAM values). In general, the pointer's value isn't going to be exactly the same number as the address it tracks. But whenever the address moves by X bytes, the pointer's value should increase or decrease by that same amount, X.

For a pointer scanning method using emulator savestates, see the end of [this post](http://tasvideos.org/forum/viewtopic.php?p=431008#431008). If that doesn't get the results you want, a more sophisticated method is described in the "How to find a pointer path using Dolphin's debugger" section of [this post](http://tasvideos.org/forum/viewtopic.php?p=457290#457290) by aldelaro.

Let's say that you've found your character's life bar value, and the address moves when you enter a different level. You've found a pointer to the life bar address. This pointer's address is the game start address plus 0x240C78. The life bar address equals (game start address + pointer's value - 0x7FFFDB60). How do we get the remaining life value?

```lua
local pointerAddress = self.startAddress + 0x240C78
local remainingLifeAddress =
  self.startAddress + utils.readIntBE(pointerAddress) - 0x7FFFDB60
local remainingLife = utils.readFloatBE(remainingLifeAddress)
```

Pointer values are always integers. Pointers should be Big Endian if defined within a game using Big Endian, like any Gamecube/Wii game. Hence the use of `readIntBE()`. If it's a PC game, you'd probably use `readIntLE()`.

We need to read `remainingLife` continually as the script runs, but what about `remainingLifeAddress`? That depends on how often the pointer changes. Some pointers are determined on game startup, and then never change unless the game is restarted. It might make sense to compute `remainingLifeAddress` only once in that case. If the pointer changes mid-game, you'll have to consider whether to accept the inconvenience of re-executing the script on a pointer change, or accept the tiny performance hit of doing an extra memory read operation per frame. Most likely, though, this one memory read is not going to hurt performance much.

However, often, a single pointer will point to a memory block that has a lot of interesting memory values. They are probably related memory values, and maybe you'll even be interested in displaying 20 of them in the same layout. Could reading the pointer 20 times per frame hurt performance significantly? Maybe, maybe not; it's hard to say what your computer will decide to do regarding memory caching. But to help mitigate this concern, the Lua framework recognizes a function called `updateAddresses()` where you can put common pointer calculations. If this function is defined, it's run once per frame.

```lua
function MyGame:updateAddresses()
  local pointerAddress = self.startAddress + 0x240C78
  self.pointerValue =
    self.startAddress + utils.readIntBE(pointerAddress) - 0x80000000
end
```

If you're wondering where the `0x80000000` comes from: In Dolphin games, the raw numeric difference between a pointer value and an address it points to is often quite large. For pointers in F-Zero GX and Super Mario Galaxy, if you first add the start address and subtract `0x80000000`, you always get pointer offsets that are much smaller and more manageable. So it makes sense to do that addition and subtraction in advance. Then, for each individual value based on that pointer, add the remaining small offset in order to read the value.

Here's how we might use the `pointerValue`. Let's bring in the same level of sophistication that we used for static addresses, too. 

```lua
package.loaded.valuetypes = nil
local valuetypes = require 'valuetypes'

local GV = MyGame.blockValues
local MV = valuetypes.MV
local FloatType = valuetypes.FloatTypeBE
local IntType = valuetypes.IntTypeBE

local PointerBasedValue = subclass(valuetypes.MemoryValue)
function PointerBasedValue:getAddress()
  return self.game.pointerValue + self.offset
end

GV.remainingLife = MV(
  "Remaining life", 0x24A0, PointerBasedValue, FloatType)
GV.numberOfLives = MV(
  "Number of lives", 0x24B0, PointerBasedValue, IntType)
GV.levelTimer = MV(
  "Level timer", 0x376C, PointerBasedValue, IntType)
```

Layout usage hasn't changed.

```lua
layouts.lifeAndTimer = subclass(Layout)
function layouts.lifeAndTimer:init()
  self:setUpdatesPerSecond(15)
  self.window:setSize(400, 300)

  self:addLabel{x=6, y=6}
  self:addItem(self.game.remainingLife)
  self:addItem(self.game.numberOfLives)
  self:addItem(self.game.levelTimer)
end
```


### Full example

Let's put together the previous `MyGame` code snippets. We've demonstrated how to display static addresses and dynamic addresses with a reasonably small amount of code.

`mygame.lua`:

```lua
package.loaded.utils = nil
local utils = require 'utils'
local subclass = utils.subclass

package.loaded.dolphin = nil
local dolphin = require 'dolphin'

package.loaded.valuetypes = nil
local valuetypes = require 'valuetypes'


local MyGame = subclass(dolphin.DolphinGame)

MyGame.supportedGameVersions = {
  na = 'GAME01',
}

MyGame.layoutModuleNames = {'mygame_layouts'}
MyGame.framerate = 60

function MyGame:init(options)
  dolphin.DolphinGame.init(self, options)

  self.startAddress = self:getGameStartAddress()
end

function MyGame:updateAddresses()
  local pointerAddress = self.startAddress + 0x240C78
  self.pointerValue =
    self.startAddress + utils.readIntBE(pointerAddress) - 0x80000000
end


local GV = MyGame.blockValues
local MV = valuetypes.MV
local FloatType = valuetypes.FloatTypeBE
local IntType = valuetypes.IntTypeBE

local StaticValue = subclass(valuetypes.MemoryValue)
function StaticValue:getAddress()
  return self.game.startAddress + self.offset
end

local PointerBasedValue = subclass(valuetypes.MemoryValue)
function PointerBasedValue:getAddress()
  return self.game.pointerValue + self.offset
end


GV.xPosition = MV("X position", 0x1082B4, StaticValue, FloatType)
GV.yPosition = MV("Y position", 0x1082B8, StaticValue, FloatType)
GV.zPosition = MV("Z position", 0x1082BC, StaticValue, FloatType)

GV.remainingLife = MV(
  "Remaining life", 0x24A0, PointerBasedValue, FloatType)
GV.numberOfLives = MV(
  "Number of lives", 0x24B0, PointerBasedValue, IntType)
GV.levelTimer = MV(
  "Level timer", 0x376C, PointerBasedValue, IntType)


return MyGame

```

`mygame_layouts.lua`:

```lua
package.loaded.utils = nil
local utils = require 'utils'
local subclass = utils.subclass

package.loaded.layouts = nil
local layoutsModule = require 'layouts'
local Layout = layoutsModule.Layout


local layouts = {}


layouts.position = subclass(Layout)
function layouts.position:init()
  self:setUpdatesPerSecond(15)
  self.window:setSize(400, 300)

  self:addLabel{x=6, y=6}
  self:addItem(self.game.xPosition)
  self:addItem(self.game.yPosition)
  self:addItem(self.game.zPosition)
end

layouts.lifeAndTimer = subclass(Layout)
function layouts.lifeAndTimer:init()
  self:setUpdatesPerSecond(15)
  self.window:setSize(400, 300)

  self:addLabel{x=6, y=6}
  self:addItem(self.game.remainingLife)
  self:addItem(self.game.numberOfLives)
  self:addItem(self.game.levelTimer)
end


return {
  layouts = layouts,
}
```


## Further coding advice

Even with the tricks we've seen so far, as you add more values and make more complicated displays, you may end up with some long or hard-to-manage Lua scripts. Can you do something about it? Well, ultimately, you'll probably need to [learn more about Lua](http://www.lua.org/start.html).

If you want to stick to learning by example, I recommend having a detailed look at `metroidprime.lua` in the `games` folder. It doesn't go far beyond what this tutorial covers, but you might still learn a thing or two, and at least it should be a good review.

The other pre-defined scripts, particularly F-Zero GX and Super Mario Galaxy, can be quite complicated. Still, you can try just skimming those files until you see something that looks vaguely interesting or understandable; then see if you can copy some part of it into your game's script.

For more about coding layouts, [see this earlier tutorial section](custom_layout.md).

Try the [debugging and troubleshooting page](../debugging.md) when your script runs into errors.


## Where to put your game scripts

The predefined game scripts are located in the `games` folder.

You can put your game scripts here as well, and it will work that way. But just like layout files, it might be better to put your game scripts in [separate folders](custom_layout.md#define-custom-layouts-in-separate-folders) specified by `RWCEExtraDirectories`.

As before, make sure no two Lua files have the same name, regardless of which folders they're in.


## Subclassing an existing game script

Suppose you've found an interesting memory value in F-Zero GX, and it isn't in the existing game script `fzerogx.lua`. You want to make a RAM display which uses this value, along with other values and functions in `fzerogx.lua`.

You could edit `fzerogx.lua` directly, or you could copy the contents of `fzerogx.lua` to another game script and then make your change. But this isn't recommended for more than one or two simple changes. It's easy to lose track of your changes if you grab an updated version of `fzerogx.lua` from GitHub sometime later.

A cleaner method is to subclass the game class defined in `fzerogx.lua`, instead of subclassing `Game` or `DolphinGame`:

```lua
package.loaded.fzerogx = nil
local GX = require 'fzerogx'

local MyGame = subclass(GX)

-- Then define only the things you want to change and add.
```

It's worth clarifying here what `subclass()` actually does. It's basically just "make a copy". If there's a `GX.somefield`, then `MyGame.somefield` becomes a copy of that.

- For the more programming inclined: Lua doesn't have a concept of classes and subclasses by default. `subclass()` is defined in this framework's `utils.lua`. It's called subclass to be in line with the similar concept in other programming languages, but it lacks common subclassing features like "super". There's a concept in Lua known as metatables which seems to be commonly used to implement subclassing, but this Lua framework opted to keep the implementation very simple. This framework's implementation also supports multiple-subclassing with very straightforward semantics: copy fields from object 1, then copy fields from object 2 while overwriting same-name fields.

Since `fzerogx.lua`'s game class already defines stuff like framerate, game versions, and pointers, you don't have to redefine all of that in your Lua file. Only redefine and add the things that you want to be different. The rest of your game module should function the same as `fzerogx.lua`.

And now, if you grab an updated version of `fzerogx.lua` from GitHub, your extension of the script can remain unchanged and still work.

Your extension CAN still break, if the functions your extension depends on have changed. But in general, that's not going to happen on every single update. And if you do have to fix something, it's easier to find what to fix when the code you wrote is in a separate Lua file.

What if you also want the predefined layouts in `fzerogx_layouts.lua` to work with your game script extension? You can either add `fzerogx_layouts` to your extension's `layoutModuleNames`, or [have your layouts file grab layouts from fzerogx_layouts.lua](custom_layout.md#define-custom-layouts-in-multiple-files).

---

[Back to the tutorial index](index.md)
