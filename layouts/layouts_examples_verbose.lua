-- In the 'games' folder, you will find many examples of layouts that use
-- various shortcut functions to be as concise as possible.
--
-- This module demonstrates some layouts that use fewer shortcut functions.
-- This results in longer layout code, but may lead to a little more
-- flexibility on how the layout is defined. If nothing else it may give
-- you a better idea of how the layout code works.

package.loaded.utils = nil
local utils = require 'utils'
local subclass = utils.subclass
local classInstantiate = utils.classInstantiate

package.loaded.utils = nil
local valuetypes = require 'valuetypes'

package.loaded.layouts = nil
local layoutsModule = require 'layouts'
local Layout = layoutsModule.Layout


local layouts = {}

local dolphinNativeResolutionHeight = 528
local X = 6
local fontSize = 12
-- alt: Arial
local generalFontName = "Calibri"
-- alt: Lucida Console
local fixedWidthFontName = "Consolas"
-- Cheat Engine uses blue-green-red order for some reason
local inputColor = 0x880000



layouts.smgVelocityAndInputsVerbose1 = subclass(Layout)
function layouts.smgVelocityAndInputsVerbose1:init(window, game)
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.windowSize = {144, dolphinNativeResolutionHeight}
  
  -- This should come BEFORE createLabel statements (so self.window and
  -- self.game are set before creating labels)
  Layout.init(self, window, game)
  
  self.mainLabel = self:createLabel{
    x=X, fontSize=fontSize, fontName=fixedWidthFontName}
  self.inputsLabel = self:createLabel{
    x=X, fontSize=fontSize, fontName=fixedWidthFontName, fontColor=inputColor}
  self.stickInputImage = classInstantiate(
    layoutsModule.StickInputImage, game, window,
    game.stickX, game.stickY,
    {size=100, x=X, foregroundColor=inputColor})
  self.timeLabel = self:createLabel{
    x=X, fontSize=fontSize, fontName=fixedWidthFontName}
  -- Set this to make the auto-positioning work
  self.uiObjs = {
    self.mainLabel, self.inputsLabel,
    self.stickInputImage.image, self.timeLabel}
  
  self.velY = game:V(game.Velocity, "Y")
  self.velXZ = game:V(game.Velocity, "XZ")
  self.velXYZ = game:V(game.Velocity, "XYZ")
  self.stageTime = game:V(game.StageTime)
end
function layouts.smgVelocityAndInputsVerbose1:update()
  local game = self.game
  game:updateAddresses()
  
  local s = table.concat({
    self.velY:display{narrow=true},
    self.velXZ:display{narrow=true},
    self.velXYZ:display{narrow=true},
    self.game.pos:display{narrow=true},
  }, "\n")
  self.mainLabel:setCaption(s)
  
  self.inputsLabel:setCaption(
    game:inputDisplay{shake=true, spin=true, narrow=true}
  )
  
  self.stickInputImage:update()
  
  self.timeLabel:setCaption(self.stageTime:display{narrow=true})
  
  if self.autoPositioningActive and not self.autoPositioningDone then
    self:autoPositionElements()
    self.autoPositioningDone = true
  end
end


return {
  layouts = layouts,
}
