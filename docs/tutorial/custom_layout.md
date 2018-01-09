# Write a custom layout

You'll want to learn about writing layouts if:

- The game you're interested in isn't covered in the pre-defined scripts.

- The pre-defined layouts don't quite do what you want, or you want to tweak them a bit.


## Recognized layout locations for your game

When you click Execute Script, the Lua framework looks for layouts in three places:

1. Any files specified in the game script's `layoutModuleNames`.
2. `generic_layouts.lua`, a predefined file in the `layouts` folder.
3. `custom_layouts.lua`, a file that you can define. This tutorial section covers this file.

Later, we'll explain which folders these files are allowed to be in. 


## Run a layout defined in custom_layouts.lua

Suppose you want to define a custom layout for Super Mario Galaxy. One way is to directly edit one of the pre-defined layouts in `supermariogalaxy_layouts.lua`, or add another layout in that file.

This will work, but it's not recommended if you're making more than one or two simple changes. You can easily lose track of your changes if you grab an updated version of `supermariogalaxy_layouts.lua` from this GitHub project sometime later.

The recommended way is to define your layout in a `custom_layouts.lua` file. The Lua framework will look for a file of this name, and if the file exists, the layout names defined there will be recognized by the script.

Open the `layouts` folder of the Lua framework. Create a file `custom_layouts.lua` there, and open it in a code editor. Paste in this starter code and save the file:

```lua
package.loaded.utils = nil
local utils = require 'utils'
local subclass = utils.subclass

package.loaded.layouts = nil
local layoutsModule = require 'layouts'
local Layout = layoutsModule.Layout


local layouts = {}


layouts.myTestLayout = subclass(Layout)
function layouts.myTestLayout:init()
  self:setUpdatesPerSecond(1)
  self.window:setSize(400, 300)

  self:addLabel{x=6, y=6}
  self:addItem("This is a test")
end


return {
  layouts = layouts,
}

```

Then in your Cheat Table script, set your layout name to `myTestLayout`.

Run your game and click Execute Script. You should see a layout displaying `This is a test`. This layout doesn't do much, but it's a simple test confirming that the layout from `custom_layouts.lua` is being recognized.


## Writing a custom layout

This Lua project has largely been a solo effort, and often things were coded "just clean enough" to ultimately get some game research done. As such, there's not really any formal documentation that lists the existing functions and what they do.

Your best bet for writing your own layout is to learn by example. Check out each of the `<name>_layouts.lua` files, and try running the layouts, for ideas of what you can do. You can start out by copying a layout and just making a minor change or two. Then if that works, try a bigger change, try mixing and matching parts of layouts, and so on.

That said, there are a couple of important features worth explaining in detail:


### Layout update method

You can select one of three ways for your layout to update.

1. **Timer**: Tell the layout to update roughly X times per second:

   ```lua
   self:setUpdatesPerSecond(5)
   ```
   
   This doesn't necessarily mean the layout will update exactly 5 times per second. In practice, the updates will probably be a little less frequent than that.
   
   Just think of this as a parameter which lets you trade off a smoother RAM display versus a higher performance demand. If you set the updates per second too high, your game may stutter. If you set it too low, you might miss details on values that change rapidly.
   
   If you've specified a `frameCounterAddress`, the layout will not update more than once on the same game frame, even if the updates per second number is really high.

2. **Breakpoint**: Tell the layout to update exactly once per game frame:

   ```lua
   self:setBreakpointUpdateMethod()
   ```
   
   Some types of layouts need once-per-frame updates to work well. For example, suppose you can find a value for your character's speed, but you can't find one for acceleration (change in speed). In that case, you can calculate acceleration as the current speed minus the previous frame's speed. But if you missed the previous frame, then you get the combined acceleration over two frames, which is probably not what you want. This is one case where you should use a breakpoint update method.
   
   You must specify a `frameCounterAddress` and `oncePerFrameAddress` for this update method to work. [Here's how to do it for Dolphin](different_dolphin.md). Differences for non-Dolphin games are [explained here](non_dolphin.md#framecounteraddress-and-onceperframeaddress).
   
   Naturally, this update method can be pretty demanding on performance, and the game will stutter if you've got a demanding game and an average computer. There isn't really a way around this. If you need a smooth playing experience, you'll have to find a way to make your layout work with less-frequent Timer updates.
   
3. **Button**: Tell the layout to update whenever a button is clicked:

   ```lua
   local updateButton = self:addButton("Update")
   self:setButtonUpdateMethod(updateButton)
   ```
   
   The first line adds a button to the layout, with "Update" as the button text. The second line sets things up so that the layout updates whenever this button is clicked.
   
   Using an update button can be useful if the display values don't change often and you want to really reduce the load on your CPU.


### Auto-positioning of layout elements

You can give text labels, buttons, etc. a specific position on the display window with the `x` and `y` options:

```lua
self:addLabel{x=6, y=6}
```

`x` is measured in pixels from the left edge of the window, and `y` is measured in pixels from the top edge.

But if you have several layout elements (say, 4 labels), it's a tedious trial and error process to position the elements evenly and without overlap. And often, you just want to lay out the elements from top to bottom. Well, there's an auto-positioning solution for that:

```lua
  self:activateAutoPositioningY()
  
  self:addLabel()
  self:addItem(...)
  self:addLabel()
  self:addItem(...)
```

The `self:activateAutoPositioningY()` line sets things up so that the elements are spaced out evenly from the top to bottom of the window.

If you want to lay out the elements compactly instead of filling the entire window, use `self:activateAutoPositioningY('compact')`.

If you want to lay out the elements horizontally instead of vertically, use `activateAutoPositioningX` - changing the Y to an X.

The auto-positioning system isn't perfect. To keep performance high, element sizes are only computed on the first one or two frames that the layout script runs. So, if an element's size changes while the layout is running, the computed positions may not work so well anymore.

- To mitigate this issue with auto Y positioning, any function-based display items ([demonstrated later](write_game_script.md#defining-and-displaying-static-ram-values)) should try to always return the same number of newline characters.

- To mitigate this issue with auto X positioning, try to pad your displayed numbers with zeroes or spaces so that the display width doesn't change.


## Define custom layouts in multiple files

If you find yourself writing a lot of layouts, especially across multiple games, you might find it annoying that you have to cram all of your layouts into one `custom_layouts.lua` file.

To remedy this, you can have your `custom_layouts.lua` grab layouts from one or more other files. Here's what `custom_layouts.lua` should look like to accomplish that:

```lua
package.loaded.utils = nil
local utils = require 'utils'
local subclass = utils.subclass

package.loaded.layouts = nil
local layoutsModule = require 'layouts'
local Layout = layoutsModule.Layout


local customLayoutModuleNames = {
  'my_generic_layouts',
  'more_galaxy_layouts',
}

local layouts = {}

for _, layoutModuleName in pairs(customLayoutModuleNames) do
  package.loaded[layoutModuleName] = nil
  local layoutModule = require(layoutModuleName)

  for name, layout in pairs(layoutModule.layouts) do
    layouts[name] = layout
  end
end


return {
  layouts = layouts,
}

```

The part you need to change is `customLayoutModuleNames`. This example code would load layouts from `my_generic_layouts.lua` and `more_galaxy_layouts.lua`.

Meanwhile, `my_generic_layouts.lua` and `more_galaxy_layouts.lua` should follow the [first example](#run-a-layout-defined-in-custom_layoutslua) of a custom layouts file.

Two things to keep in mind:

- Make sure no two Lua files have the same name, regardless of which folder they're in. This also means you can't give your files the same name as a pre-defined file, like `fzerogx_layouts.lua` or `utils.lua`. If there is a name clash, only one of the conflicting files will be loaded.

- Make sure no two layouts have the same name, counting all Lua files across the [three recognized layout locations](#recognized-layout-locations-for-your-game). If there is a name clash, only one of the conflicting layouts will be loaded.


## Define custom layouts in separate folders

As explained earlier, if you directly edit `supermariogalaxy_layouts.lua` and then grab an updated version of this file from GitHub sometime later, you might lose track of your changes.

Depending on your workflow, it might also be risky to keep your custom files in the Lua framework's `layouts` folder. You might decide to re-download the whole framework, forgetting that you had custom files in a folder of your old copy.

To avoid this situation, you can put your custom layout files in a completely separate folder on your computer. Then, specify the additional folder(s) with `RWCEExtraDirectories` in your Cheat Table script:

```lua
RWCEMainDirectory = [[C:/path/to/ram-watch-cheat-engine]]
RWCEExtraDirectories = {
  [[C:/different/path/to/another/directory]],
  [[C:/yet/another/path]],
}

...
```

Similarly to the `RWCEMainDirectory`, forward slashes and backslashes are fine, and you shouldn't put a slash at the end.

If `custom_layouts.lua` and all the files it `require`s are in the `RWCEMainDirectory` or `RWCEExtraDirectories`, then the Lua framework should find all of your layouts without problems.

As before, make sure no two Lua files have the same name, regardless of which folders they're in.
 
Specifying extra directories also works for [custom game scripts](write_game_script.md), not just layouts.

One thing to be careful about with `RWCEExtraDirectories`. If you run your script once, and then you later need to change or fix `RWCEExtraDirectories`, you'll have to close and re-open Cheat Engine for your change to be recognized. It's kind of a pain, but hopefully you don't have to do this often. We might look into making this nicer in a later version of the framework.

---

[Back to the tutorial index](index.md)
