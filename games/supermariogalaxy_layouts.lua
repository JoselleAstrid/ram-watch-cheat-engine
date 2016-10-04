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


-- SMG1 only
layouts.addressTestSMG1 = subclass(Layout)
function layouts.addressTestSMG1:init()
  local game = self.game
  self:setTimerUpdateMethod(200)  -- Update every 200 ms (5x per second)

  self.window:setSize(400, 300)
  
  self:addLabel{
    x=margin, y=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  self:addItem(
    function ()
      local names = {'o', 'refPointer', 'messageInfoPointer', 'posBlock'}
      local lines = {}
      for _, name in pairs(names) do
        table.insert(
          lines, name..": "..utils.intToHexStr(game.addrs[name]))
      end
      return table.concat(lines, '\n')
    end
  )
end


-- SMG2 only
layouts.addressTestSMG2 = subclass(Layout)
function layouts.addressTestSMG2:init()
  local game = self.game
  self:setTimerUpdateMethod(200)  -- Update every 200 ms (5x per second)

  self.window:setSize(400, 300)
  
  self:addLabel{
    x=margin, y=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  self:addItem(game:F(
    function()
      local names = {'o', 'refPointer', 'refPointer2', 'posRefPointer'}
      local lines = {}
      for _, name in pairs(names) do
        table.insert(
          lines, name..": "..utils.intToHexStr(self.game.addrs[name]))
      end
      return table.concat(lines, '\n')
    end
  ))
end


layouts.stageTime = subclass(Layout)
function layouts.stageTime:init()
  local game = self.game
  self:setBreakpointUpdateMethod()

  self.window:setSize(400, 100)
  
  self:addLabel{
    x=margin, y=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  self:addItem(game:V(game.StageTime))
end


-- SMG2 only
layouts.stageAndFileTime = subclass(Layout)
function layouts.stageAndFileTime:init()
  local game = self.game
  self:setBreakpointUpdateMethod()

  self.window:setSize(500, 100)
  
  self:addLabel{
    x=margin, y=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  self:addItem(game:V(game.StageTime))
  self:addItem(game:V(game.FileTime))
end


layouts.velocityAndInputs = subclass(Layout)
function layouts.velocityAndInputs:init()
  local game = self.game
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.window:setSize(narrowWindowWidth, dolphinNativeResolutionHeight)
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}
  
  self:addLabel()
  self:addItem(game:V(game.Velocity, "Y"))
  self:addItem(game:V(game.Velocity, "XZ"))
  self:addItem(game:V(game.Velocity, "XYZ"))
  self:addItem(game.pos)
  
  self:addLabel{fontColor=inputColor}
  self:addItem(game:F(game.inputDisplay), {shake=true, spin=true})
  
  self:addImage(
    game.StickInputImage, {size=100, x=10, foregroundColor=inputColor})
    
  self:addLabel()
  self:addItem(game:V(game.StageTime))
end


layouts.velYRecording = subclass(Layout)
function layouts.velYRecording:init()
  local game = self.game
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.window:setSize(400, 130)
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  
  self:addLabel()
  self:addItem(game:V(game.StageTime))
  
  self:addLabel()
  self:addItem(game:V(game.Velocity, "Y"))
  
  self:addFileWriter(
    game:V(game.Velocity, "Y"), "ram_watch_output.txt",
    {beforeDecimal=1, afterDecimal=10})
end


-- SMG1 only for now
layouts.messages = subclass(Layout)
function layouts.messages:init()
  local game = self.game
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()

  self.window:setSize(160, dolphinNativeResolutionHeight)
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}
  
  self:addLabel()
  self:addItem(game.textProgress)
  self:addItem(game.alphaReq)
  self:addItem(game.fadeRate)
  
  self:addLabel{fontColor=inputColor}
  self:addItem(game:F(game.inputDisplay), {shake=true, spin=true})
  
  self:addImage(
    game.StickInputImage, {size=100, x=10, foregroundColor=inputColor})
  
  self:addLabel()
  self:addItem(game:V(game.StageTime))
end


layouts.testClasses = subclass(Layout)
function layouts.testClasses:init()
  local game = self.game
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.window:setSize(500, 800)
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
end


layouts.tilt1 = subclass(Layout)
function layouts.tilt1:init()
  local game = self.game
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.window:setSize(narrowWindowWidth, dolphinNativeResolutionHeight)
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
end


layouts.tilt2 = subclass(Layout)
function layouts.tilt2:init()
  local game = self.game
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.window:setSize(narrowWindowWidth, dolphinNativeResolutionHeight)
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
end



return {
  layouts = layouts,
}
