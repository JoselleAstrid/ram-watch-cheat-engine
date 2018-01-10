package.loaded.utils = nil
local utils = require 'utils'
local subclass = utils.subclass

package.loaded.layouts = nil
local layoutsModule = require 'layouts'
local Layout = layoutsModule.Layout

local layouts = {}

local fixedWidthFontName = "Consolas"

local inputColor = 0x880000

layouts.addressTest = subclass(Layout)
-- Displays some key addresses, as computed by the Lua framework.
-- We can double check these addresses in Cheat Engine's Memory View.
function layouts.addressTest:init()

  self:setUpdatesPerSecond(5)

  self.window:setSize(450, 200)

  self:addLabel{x=6, y=6}
  self:addItem(
    function()
      local lines = {}
      table.insert(
        lines, "startAddress: "..utils.intToHexStr(self.game.startAddress))
      table.insert(
        lines,
        "FSpeed addr: "..utils.intToHexStr(self.game.fSpeed:getAddress()))
      return table.concat(lines, '\n')
    end
  )
  
end


layouts.coordsAndInputs = subclass(Layout)
-- General use layout for TASing and stuff.
-- Speed, position, rotation, inputs.
--
-- updatesPerSecond:
--   How often this display should be updated.
--   Set this higher to see more frequent updates. The game runs at
--   60 FPS, so it doesn't make sense to set this much higher than 60.
--   Set this lower if Dolphin is stuttering too much.
--   Set to 0 to use breakpoint updates (should update on every frame more
--   reliably compared to 60, but may make Dolphin stutter more).
function layouts.coordsAndInputs:init(updatesPerSecond)

  updatesPerSecond = updatesPerSecond or 60
  
  local game = self.game
  self.margin = 6
  if updatesPerSecond == 0 then
    self:setBreakpointUpdateMethod()
  else
    self:setUpdatesPerSecond(updatesPerSecond)
  end
  self:activateAutoPositioningY()
  
  self.window:setSize(220, 460)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}
  
  self:addLabel()
  self:addItem(function(...) return self.game:displaySpeed(...) end)
  self:addItem(function(...) return self.game:displayPosition(...) end)
  self:addItem(function(...) return self.game:displayRotation(...) end)
  
  self:addItem("Input Frames Count")
  self:addItem(function(...) return self.game:displayInputTime(...) end)
  
  self:addLabel{fontColor=inputColor}
  self:addItem("Buttons")
  self:addItem(function(...) return self.game:displayAllButtons(...) end)
  
  self:addLabel{foregroundColor=inputColor}
  self:addImage(
    self.game.ControllerLRImage, {game}, {foregroundColor=inputColor})
	
  self:addLabel{foregroundColor=inputColor}
  self:addImage(
    self.game.ControllerStickImage, {game}, {foregroundColor=inputColor})
  
end


return {
  layouts = layouts,
}
