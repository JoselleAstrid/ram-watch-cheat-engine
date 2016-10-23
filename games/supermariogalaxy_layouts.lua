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
  self.margin = margin
  self:setUpdatesPerSecond(5)

  self.window:setSize(400, 300)
  
  self:addLabel{fontSize=fontSize, fontName=fixedWidthFontName}
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
  self.margin = margin
  self:setUpdatesPerSecond(5)

  self.window:setSize(400, 300)
  
  self:addLabel{fontSize=fontSize, fontName=fixedWidthFontName}
  self:addItem(
    function()
      local names = {'o', 'refPointer', 'refPointer2', 'posRefPointer'}
      local lines = {}
      for _, name in pairs(names) do
        table.insert(
          lines, name..": "..utils.intToHexStr(game.addrs[name]))
      end
      return table.concat(lines, '\n')
    end
  )
end


layouts.stageTime = subclass(Layout)
function layouts.stageTime:init()
  local game = self.game
  self.margin = margin
  self:setBreakpointUpdateMethod()

  self.window:setSize(400, 100)
  
  self:addLabel{fontSize=fontSize, fontName=fixedWidthFontName}
  self:addItem(game.stageTime)
end


-- SMG2 only
layouts.stageAndFileTime = subclass(Layout)
function layouts.stageAndFileTime:init()
  local game = self.game
  self.margin = margin
  self:setBreakpointUpdateMethod()

  self.window:setSize(500, 100)
  
  self:addLabel{fontSize=fontSize, fontName=fixedWidthFontName}
  self:addItem(game.stageTime)
  self:addItem(game.fileTime)
end


layouts.velocityAndInputs = subclass(Layout)
function layouts.velocityAndInputs:init()
  local game = self.game
  self.margin = margin
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.window:setSize(narrowWindowWidth, dolphinNativeResolutionHeight)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}
  
  self:addLabel()
  self:addItem(game:V(game.Velocity, "Y"))
  self:addItem(game:V(game.Velocity, "XZ"))
  self:addItem(game:V(game.Velocity, "XYZ"))
  self:addItem(game.pos)
  
  self:addLabel{fontColor=inputColor}
  self:addItem(game.input, {shake=true, spin=true, stick=true})
  
  self:addImage(
    layoutsModule.StickInputImage,
    {game.stickX, game.stickY},
    {foregroundColor=inputColor})
    
  self:addLabel()
  self:addItem(game.stageTime)
end


layouts.inputsHorizontal = subclass(Layout)
function layouts.inputsHorizontal:init()
  local game = self.game
  self.margin = margin
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningX()
  
  self.window:setSize(550, 110)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}
    
  self:addLabel()
  self:addItem(game.stageTime)
  
  self:addLabel()
  self:addItem("Buttons")
  self:addItem(function(...) return game.input:displayAllButtons(...) end)
  self:addItem(game.spinStatus)
  
  self:addImage(
    layoutsModule.StickInputImage,
    {game.stickX, game.stickY})
end


layouts.velYRecording = subclass(Layout)
function layouts.velYRecording:init()
  local game = self.game
  self.margin = margin
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.window:setSize(400, 130)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}
  
  self:addLabel()
  self:addItem(game.stageTime)
  
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
  self.margin = margin
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()

  self.window:setSize(160, dolphinNativeResolutionHeight)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}
  
  self:addLabel()
  self:addItem(game.textProgress)
  self:addItem(game.alphaReq)
  self:addItem(game.fadeRate)
  
  self:addLabel{fontColor=inputColor}
  self:addItem(game.input, {shake=true, spin=true, stick=true})
  
  self:addImage(
    layoutsModule.StickInputImage,
    {game.stickX, game.stickY},
    {foregroundColor=inputColor})
  
  self:addLabel()
  self:addItem(game.stageTime)
end


layouts.testClasses = subclass(Layout)
function layouts.testClasses:init(character)
  character = character or 'mario'
  
  local game = self.game
  game.character = character
  self.margin = margin
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.window:setSize(500, 800)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}
  
  self:addLabel()
  self:addItem(game.stageTime)
  self:addItem(game:V(game.Velocity, "Y"))
  self:addItem(game:V(game.Velocity, "XZ"))
  self:addItem(game:V(game.Velocity, "XYZ"))
  self:addItem(function(...) return game.tilt:displayRotation(...) end)
  self:addItem(function(...) return game.tilt:displayDiff(...) end)
  self:addItem(game.upwardVelocity)
  self:addItem(game.lateralVelocity)
  self:addItem(game.upwardVelocityLastJump)
  self:addItem(game.upVelocityTiltBonus)
  self:addItem(game:V(game.AnchoredDistance, "XZ"))
  self:addItem(game.anchoredHeight)
  self:addItem(game:V(valuetypes.MaxValue, game.pos.y))
  self:addItem(game:V(valuetypes.AverageValue, game.lateralVelocity))
  
  self:addLabel{fontColor=inputColor}
  self:addItem(game.input, {shake=true, spin=true, stick=true})
  
  self:addImage(
    layoutsModule.StickInputImage,
    {game.stickX, game.stickY},
    {foregroundColor=inputColor})
end


layouts.tilt1 = subclass(Layout)
function layouts.tilt1:init(character)
  -- Specify the character you're playing as to make the tilt-bonus accurate.
  character = character or 'mario'
  
  local game = self.game
  game.character = character
  self.margin = margin
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.window:setSize(narrowWindowWidth, dolphinNativeResolutionHeight)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}
  
  self:addLabel()
  self:addItem(game.downVectorGravity)
  self:addItem(game.upVectorTilt)
  self:addItem(game.upwardVelocityLastJump,
    {beforeDecimal=2, afterDecimal=3})
  self:addItem(game:V(valuetypes.RateOfChange, game.upwardVelocity, "Up Accel"),
    {signed=true, beforeDecimal=2, afterDecimal=3})
  self:addItem(game.upVelocityTiltBonus)
end


layouts.tilt2 = subclass(Layout)
function layouts.tilt2:init(character)
  -- Specify the character you're playing as to make the tilt-bonus accurate.
  character = character or 'mario'
  
  local game = self.game
  game.character = character
  self.margin = margin
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.window:setSize(narrowWindowWidth, dolphinNativeResolutionHeight)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}
  
  self:addLabel()
  self:addItem(game.upwardVelocityLastJump,
    {beforeDecimal=2, afterDecimal=3})
  self:addItem(game:V(valuetypes.RateOfChange, game.upwardVelocity, "Up Accel"),
    {signed=true, beforeDecimal=2, afterDecimal=3})
  self:addItem(game.upVelocityTiltBonus)
  
  self:addLabel{fontColor=inputColor}
  self:addItem(game.input, {shake=true, spin=true, stick=true})
  
  self:addImage(
    layoutsModule.StickInputImage,
    {game.stickX, game.stickY},
    {foregroundColor=inputColor})
  
  self:addLabel()
  self:addItem(game.stageTime)
end



return {
  layouts = layouts,
}
