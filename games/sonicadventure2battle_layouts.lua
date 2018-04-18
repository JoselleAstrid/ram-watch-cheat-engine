package.loaded.utils = nil
local utils = require 'utils'
local subclass = utils.subclass

package.loaded.layouts = nil
local layoutsModule = require 'layouts'
local Layout = layoutsModule.Layout

local layouts = {}

local fixedWidthFontName = "Consolas"

local inputColor = 0x880000

-- normal is for non-hunting stages
layouts.normal = subclass(Layout)
function layouts.normal:init()
  
  local game = self.game
  self.margin = 6
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.window:setSize(240, 540)
  self.labelDefaults = {fontSize=11, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}
  
  self:addLabel()
  
  --Time
  self:addItem(function(...) return self.game:displayTime(...) end)
  
  --Speed
  self:addItem(function(...) return self.game:displaySpeed(...) end)
  
  --Position
  self:addItem(function(...) return self.game:displayPosition(...) end)
  
  --Rotation
  self:addItem(function(...) return self.game:displayRotation(...) end)
  
  --Misc
  self:addItem(function(...) return self.game:displayMisc(...) end)
  
  self:addLabel{fontColor=inputColor}
  self:addItem("Inputs")
  self:addItem(function(...) return self.game:displayAllButtons(...) end)
  
  self:addLabel{foregroundColor=inputColor}
  
  self:addImage(
    self.game.ControllerLRImage, {game}, {foregroundColor=inputColor})
	
  self:addLabel{foregroundColor=inputColor}
  self:addImage(
    self.game.ControllerStickImage, {game}, {foregroundColor=inputColor})

  self:addLabel{fontColor=inputColor}
  self:addItem(function(...) return self.game:displayAnalogPosition(...) end)
  
end

-- hunting is for Knuckles's and Rouge's missions 1, 4 and 5 (except Route 280)
layouts.hunting = subclass(Layout)
function layouts.hunting:init()
  
  local game = self.game
  self.margin = 6
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.window:setSize(240, 540)
  self.labelDefaults = {fontSize=11, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}
  
  self:addLabel()
  
  --Time
  self:addItem(function(...) return self.game:displayTime(...) end)
  
  --Speed
  self:addItem(function(...) return self.game:displayhSpeed(...) end)
  
  --Position
  self:addItem(function(...) return self.game:displayhPosition(...) end)
  
  --Rotation
  self:addItem(function(...) return self.game:displayhRotation(...) end)
  
  --Misc
  self:addItem(function(...) return self.game:displayhMisc(...) end)
  
  self:addLabel{fontColor=inputColor}
  self:addItem("Inputs")
  self:addItem(function(...) return self.game:displayAllButtons(...) end)
  
  self:addLabel{foregroundColor=inputColor}
  
  self:addImage(
    self.game.ControllerLRImage, {game}, {foregroundColor=inputColor})
	
  self:addLabel{foregroundColor=inputColor}
  self:addImage(
    self.game.ControllerStickImage, {game}, {foregroundColor=inputColor})

  self:addLabel{fontColor=inputColor}
  self:addItem(function(...) return self.game:displayAnalogPosition(...) end)
  
end

layouts.recording = subclass(Layout)
function layouts.recording:init()

  local game = self.game
  self.margin = 6
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.window:setSize(240, 540)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}
  
  -- Watch XPos, FSpeed, YPos and VSpeed
  
  self:addLabel()
  
  self:addItem(self.game.fSpeed)
  self:addItem(self.game.vSpeed)
  
  self:addItem(self.game.xPos)
  self:addItem(self.game.yPos)
  
  self:addFileWriter(
    self.game.fSpeed, "fspd_output.txt",
    {beforeDecimal=1, afterDecimal=10})
	
  self:addFileWriter(
    self.game.vSpeed, "vspd_output.txt",
    {beforeDecimal=1, afterDecimal=10})

  self:addFileWriter(
    self.game.xPos, "xpos_output.txt",
    {beforeDecimal=1, afterDecimal=10})
	
  self:addFileWriter(
    self.game.yPos, "ypos_output.txt",
    {beforeDecimal=1, afterDecimal=10})
	
end

return {
  layouts = layouts,
}