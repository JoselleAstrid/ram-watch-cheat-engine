package.loaded.utils = nil
local utils = require 'utils'
local subclass = utils.subclass

package.loaded.valuetypes = nil
local valuetypes = require 'valuetypes'

package.loaded.layouts = nil
local layoutsModule = require 'layouts'
local Layout = layoutsModule.Layout


local layouts = {}

local narrowWindowWidth = 144
local dolphinNativeResolutionHeight = 528
local margin = 6
local fontSize = 12
-- alt: Lucida Console
local fixedWidthFontName = "Consolas"
-- Cheat Engine uses blue-green-red order for some reason
local inputColor = 0x880000


layouts.addressTest = subclass(Layout)
function layouts.addressTest:init(window, game)
  self:setTimerUpdateMethod(200)  -- Update every 200 ms (5x per second)

  self.windowSize = {400, 300}
  
  self:addLabel{
    x=margin, y=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  self:addItem(game:F(
    function()
      local names = {'o', 'refPointer', 'messageInfoPointer', 'posBlock'}
      local lines = {}
      for _, name in pairs(names) do
        table.insert(
          lines, name..": "..utils.intToHexStr(self.game.addrs[name]))
      end
      return table.concat(lines, '\n')
    end
  ))
  
  Layout.init(self, window, game)
end


layouts.stageTime = subclass(Layout)
function layouts.stageTime:init(window, game)
  self:setBreakpointUpdateMethod()

  self.windowSize = {400, 100}
  
  self:addLabel{
    x=margin, y=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  self:addItem(game:V(game.StageTime))
  
  Layout.init(self, window, game)
end


layouts.velocityAndInputs = subclass(Layout)
function layouts.velocityAndInputs:init(window, game)
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.windowSize = {narrowWindowWidth, dolphinNativeResolutionHeight}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}
  
  self:addLabel()
  self:addItem(game:V(game.Velocity, "Y"))
  self:addItem(game:V(game.Velocity, "XZ"))
  self:addItem(game:V(game.Velocity, "XYZ"))
  self:addItem(game.pos)
  
  self:addLabel()
  self:addItem(game:F(game.inputDisplay), {shake=true, spin=true})
  
  self:addImage(
    game.StickInputImage, {size=100, x=10, foregroundColor=inputColor})
    
  self:addLabel()
  self:addItem(game:V(game.StageTime))
  
  Layout.init(self, window, game)
end


layouts.velYRecording = subclass(Layout)
function layouts.velYRecording:init(window, game)
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.windowSize = {400, 130}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  
  self:addLabel()
  self:addItem(game:V(game.StageTime))
  
  self:addLabel()
  self:addItem(game:V(game.Velocity, "Y"))
  
  self:addFileWriter(
    game:V(game.Velocity, "Y"), "ram_watch_output.txt",
    {beforeDecimal=1, afterDecimal=10})
  
  Layout.init(self, window, game)
end


layouts.messages = subclass(Layout)
function layouts.messages:init(window, game)
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()

  self.windowSize = {160, dolphinNativeResolutionHeight}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}
  
  self:addLabel()
  self:addItem(game.textProgress)
  self:addItem(game.alphaReq)
  self:addItem(game.fadeRate)
  
  self:addLabel()
  self:addItem(game:F(game.inputDisplay), {shake=true, spin=true})
  
  self:addImage(
    game.StickInputImage, {size=100, x=10, foregroundColor=inputColor})
  
  self:addLabel()
  self:addItem(game:V(game.StageTime))
  
  Layout.init(self, window, game)
end


layouts.testClasses = subclass(Layout)
function layouts.testClasses:init(window, game)
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.windowSize = {500, 800}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  
  self.tilt = game:V(game.Tilt)
  
  self:addLabel()
  self:addItem(game:V(game.StageTime))
  self:addItem(game:V(game.Velocity, "Y"))
  self:addItem(game:V(game.Velocity, "XZ"))
  self:addItem(game:V(game.Velocity, "XYZ"))
  self:addItem(utils.curry(self.tilt.displayRotation, self.tilt))
  self:addItem(utils.curry(self.tilt.displayDiff, self.tilt))
  self:addItem(game:V(game.UpwardVelocity))
  self:addItem(game:V(game.LateralVelocity))
  self:addItem(game:V(game.UpwardVelocityLastJump))
  self:addItem(game:V(game.UpVelocityTiltBonus))
  self:addItem(game:V(game.AnchoredDistance, "XZ"))
  self:addItem(game:V(game.AnchoredHeight))
  self:addItem(game:V(valuetypes.MaxValue, game.pos.y))
  self:addItem(game:V(valuetypes.AverageValue, game:V(game.LateralVelocity)))
  
  self:addLabel()
  self:addItem(game:F(game.inputDisplay), {shake=true, spin=true})
  
  self:addImage(
    game.StickInputImage, {size=100, x=10, foregroundColor=inputColor})
  
  Layout.init(self, window, game)
end


layouts.tilt1 = subclass(Layout)
function layouts.tilt1:init(window, game)
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.windowSize = {narrowWindowWidth, dolphinNativeResolutionHeight}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}
  
  self.velUp = game:V(game.UpwardVelocity)
  
  self:addLabel()
  self:addItem(game.downVectorGravity)
  self:addItem(game.upVectorTilt)
  self:addItem(game:V(game.UpwardVelocityLastJump),
    {beforeDecimal=2, afterDecimal=3})
  self:addItem(game:V(valuetypes.RateOfChange, self.velUp, "Up Accel"),
    {signed=true, beforeDecimal=2, afterDecimal=3})
  self:addItem(game:V(game.UpVelocityTiltBonus))
  
  Layout.init(self, window, game)
end


layouts.tilt2 = subclass(Layout)
function layouts.tilt2:init(window, game)
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.windowSize = {narrowWindowWidth, dolphinNativeResolutionHeight}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}
  
  self.velUp = game:V(game.UpwardVelocity)
  
  self:addLabel()
  self:addItem(game:V(game.UpwardVelocityLastJump),
    {beforeDecimal=2, afterDecimal=3})
  self:addItem(game:V(valuetypes.RateOfChange, self.velUp, "Up Accel"),
    {signed=true, beforeDecimal=2, afterDecimal=3})
  self:addItem(game:V(game.UpVelocityTiltBonus))
  
  self:addLabel{fontColor=inputColor}
  self:addItem(game:F(game.inputDisplay), {shake=true, spin=true})
  
  self:addImage(
    game.StickInputImage, {size=100, x=10, foregroundColor=inputColor})
  
  self:addLabel()
  self:addItem(game:V(game.StageTime))
  
  Layout.init(self, window, game)
end



return {
  layouts = layouts,
}
