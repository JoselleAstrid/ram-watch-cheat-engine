-- Imports.

package.loaded.utils = nil
local utils = require 'utils'
local subclass = utils.subclass

package.loaded.layouts = nil
local layoutsModule = require 'layouts'
local Layout = layoutsModule.Layout


local layouts = {}

local windowWidth = 144
local dolphinNativeResolutionHeight = 528
local X = 6
local fontSize = 12
-- alt: Arial
local generalFontName = "Calibri"
-- alt: Lucida Console
local fixedWidthFontName = "Consolas"
-- Cheat Engine uses blue-green-red order for some reason
local inputColor = 0x880000



local layoutAddressDebug = {
  
  init = function(window)
    updateMethod = "timer"
    updateTimeInterval = 100
    
    window:setSize(400, 300)
    
    vars.label = initLabel(window, 10, 5, "", 14)
    -- utils.setDebugLabel(initLabel(window, 10, 5, "", 9))
  
    vars.addresses = {
      "o", "refPointer", "posBlock",
    }
  end,
  
  update = function()
    local s = ""
    for _, name in pairs(vars.addresses) do
      s = s..name..": "
      vars.label:setCaption(s)
      if computeAddr[name] ~= nil then
        addrs[name] = computeAddr[name]()
      end
      s = s..utils.intToHexStr(addrs[name]).."\n"
      vars.label:setCaption(s)
    end
  end,
}

local layoutStageTime = {
  
  init = function(window)
    updateMethod = "timer"
    updateTimeInterval = 16
    
    -- Set the display window's size.
    window:setSize(400, 100)
  
    -- Add a blank label to the window at position (10,5). In the update
    -- function, which is called regularly as the game runs, we'll update
    -- the label text.
    vars.label = initLabel(window, 10, 5, "")
  end,
  
  update = function()
    updateAddresses()
    
    vars.label:setCaption(stageTimeDisplay())
  end,
}

local layoutVelocity = {
  
  init = function(window)
    updateMethod = "breakpoint"
    
    window:setSize(500, 200)
    
    vars.label = initLabel(window, 10, 5, "", 13, fixedWidthFontName)
    --utils.setDebugLabel(initLabel(window, 20, 165, "DEBUG"))
    
    updateAddresses()
    
    vars.velocityY = Velocity("Y")
    vars.velocityXZ = Velocity("XZ")
    vars.velocityXYZ = Velocity("XYZ")
  end,
  
  update = function()
    updateAddresses()
    
    vars.label:setCaption(
      table.concat({
        stageTimeDisplay(),
        vars.velocityY:display(),
        vars.velocityXZ:display(),
        vars.velocityXYZ:display(),
        pos:display(),
      }, "\n")
    )
  end,
}

local layoutRecording = {
  
  init = function(window)
    updateMethod = "breakpoint"
    
    window:setSize(400, 130)
  
    vars.label = initLabel(window, 10, 5, "", 16, fixedWidthFontName)
    --utils.setDebugLabel(initLabel(window, 200, 5, ""))
    
    vars.velocityY = Velocity("Y")
    vars.statRecorder = StatRecorder:new(window, 90)
  end,
  
  update = function()
    updateAddresses()
    
    vars.label:setCaption(
      table.concat({
        stageTimeDisplay(),
        vars.velocityY:display(),
      }, "\n")
    )
    
    if vars.statRecorder.currentlyTakingStats then
      local s = vars.velocityY:display{beforeDecimal=1, afterDecimal=10}
      vars.statRecorder:takeStat(s)
    end
  end,
}

local layoutMessages = {
  
  init = function(window)
    updateMethod = "breakpoint"
  
    window:setSize(162, 528)
  
    vars.inputsLabel = initLabel(window, 6, 64, "", 12, fixedWidthFontName)
    local imageY = 134
    vars.timeLabel = initLabel(window, 6, 248, "", 12, fixedWidthFontName)
    vars.messageLabel = initLabel(window, 6, 330, "", 12, fixedWidthFontName)
  
    -- vars.timeLabel = initLabel(window, 6, 5, "", 12, fixedWidthFontName)
    -- vars.messageLabel = initLabel(window, 6, 88, "", 12, fixedWidthFontName)
    -- vars.inputsLabel = initLabel(window, 6, 338, "", 12, fixedWidthFontName)
    -- local imageY = 410
    
    -- vars.inputsLabel = initLabel(window, 6, 88, "", 12, fixedWidthFontName)
    -- local imageY = 160
    -- vars.messageLabel = initLabel(window, 6, 284, "", 12, fixedWidthFontName)
    
    -- utils.setDebugLabel(initLabel(window, 10, 515, "", 8, fixedWidthFontName))
    
    -- Graphical display of stick input
    vars.stickInputImage = newStickInputImage(
      window,
      100,    -- size
      10, imageY    -- x, y position
    )
  end,
  
  update = function()
    updateAddresses()
    
    vars.timeLabel:setCaption(stageTimeDisplay("narrow"))
    
    local s = table.concat({
      textProgress:display{narrow=true},
      alphaReq:display{narrow=true},
      fadeRate:display{narrow=true},
    }, "\n")
    vars.messageLabel:setCaption(s)
    
    vars.inputsLabel:setCaption(
      inputDisplay("spin", "compact")
    )
    vars.stickInputImage:update()
  end,
}


layouts.inputsOldWay = subclass(Layout)
  
function layouts.inputsOldWay:init(window, game)
  self.window = window
  self.game = game
  
  self:setBreakpointUpdateMethod()
  
  self.window:setSize(windowWidth, dolphinNativeResolutionHeight)
  
  self.coordsLabel = self:createLabel{
    x=X, fontSize=fontSize, fontName=fixedWidthFontName}
  self.inputsLabel = self:createLabel{
    x=X, fontSize=fontSize, fontName=fixedWidthFontName, fontColor=inputColor}
  self.timeLabel = self:createLabel{
    x=X, fontSize=fontSize, fontName=fixedWidthFontName}
  
  -- Graphical display of stick input
  -- self.stickInputImage = game.newStickInputImage(
  --   window,
  --   100,    -- size
  --   10, 0,    -- x, y position
  --   inputColor
  -- )
  self.windowElements = {self.coordsLabel, self.timeLabel}
  -- self.windowElements = {self.coordsLabel, self.inputsLabel, self.stickInputImage.image, self.timeLabel}
  self.windowElementsPositioned = false
  
  -- self.debugLabel = self:createLabel{
  --   x=X, fontSize=8, fontName=fixedWidthFontName}
  
  -- Some of the value objects might need valid addresses during initialization.
  game:updateAddresses()
  
  -- self.velocityX = Velocity("X")
  -- self.velocityY = Velocity("Y")
  -- self.velocityZ = Velocity("Z")
  
  self.velUp = game:V(game.UpwardVelocity)
  self.upwardAccel = game:V(game.RateOfChange, self.velUp, "Up Accel")
  self.upwardVelocityLastJump = game:V(game.UpwardVelocityLastJump)
  self.tilt = game:V(game.Tilt)
  self.upVelocityTiltBonus = game:V(game.UpVelocityTiltBonus)
  --self.speedLateral = LateralVelocity()
  
  --self.speedXZ = Velocity("XZ")
  
  --self.velY = Velocity("Y")
  --self.speedXYZ = Velocity("XYZ")
  --self.anchoredDistXZ = ResettableValue(AnchoredDistance("XZ"))
  --self.anchoredMaxDistY = ResettableValue(MaxValue(AnchoredDistance("Y")))
  --self.anchoredMaxHeight = ResettableValue(MaxValue(AnchoredHeight()))
  --self.averageSpeedXZ = ResettableValue(AverageValue(Velocity("XZ")))
  
  --self.accelY = RateOfChange(self.velY, "Y Accel")
end
  
function layouts.inputsOldWay:update()
  local game = self.game

  game:updateAddresses()
  
  self.timeLabel:setCaption(game:stageTimeDisplay("narrow"))
  
  local s = table.concat({
    -- self.velocityX:display{narrow=true},
    -- self.velocityY:display{narrow=true},
    -- self.velocityZ:display{narrow=true},
    
    --game.downVectorGravity:display{narrow=true},
    --game.upVectorTilt:display{narrow=true},
    self.upwardVelocityLastJump:display{narrow=true, beforeDecimal=2, afterDecimal=3},
    self.upwardAccel:display{narrow=true, signed=true, beforeDecimal=2, afterDecimal=3},
    self.upVelocityTiltBonus:display{narrow=true},
    
    --self.velUp:display{narrow=true},
    --self.speedLateral:display{narrow=true},
    --game.pos:display{narrow=true},
    
    --self.speedXZ:display{narrow=true},
    --self.anchoredMaxDistY:display(),
    --self.anchoredMaxHeight:display{narrow=true},
    --"Base Spd XZ:\n "..utils.floatToStr(baseSpeedXZ),
    --self.accelY:display{narrow=true},
    --self.tilt:displayRotation(),
    --self.tilt:displayDiff{narrow=true},
    --"On ground:\n "..tostring(game:onGround()),
    
    --self.averageSpeedXZ:display{narrow=true},
    --self.anchoredDistXZ:display{narrow=true},
    
  }, "\n")
  self.coordsLabel:setCaption(s)
  
  -- self.inputsLabel:setCaption(
  --   game:inputDisplay("both", "compact")
  -- )
  -- self.stickInputImage:update()
  
  if not self.windowElementsPositioned then
    self:positionWindowElements(self.windowElements)
    self.windowElementsPositioned = true
  end
end


layouts.inputs = subclass(Layout)

function layouts.inputs:init(window, game)
  self:setBreakpointUpdateMethod()
  
  self.windowSize = {windowWidth, dolphinNativeResolutionHeight}
  
  -- TODO: Be able to specify label defaults: X, fontSize, fontName
  
  self.velUp = game:V(game.UpwardVelocity)
  
  self:addLabel{x=X, fontSize=fontSize, fontName=fixedWidthFontName}
  -- self:addItem(game.downVectorGravity, {narrow=true})
  -- self:addItem(game.upVectorTilt, {narrow=true})
  self:addItem(game:V(game.UpwardVelocityLastJump),
    {narrow=true, beforeDecimal=2, afterDecimal=3})
  self:addItem(game:V(game.RateOfChange, self.velUp, "Up Accel"),
    {narrow=true, signed=true, beforeDecimal=2, afterDecimal=3})
  self:addItem(game:V(game.UpVelocityTiltBonus), {narrow=true})
  
  self:addLabel{
    x=X, fontSize=fontSize, fontName=fixedWidthFontName, color=inputColor}
  -- TODO: Make this display function's interface more uniform with others
  self:addItem(utils.curry(game.inputDisplay, game, "both", "compact"))
  
  self:addImage(
    game.StickInputImage, {size=100, x=10, color=inputColor})
  
  self:addLabel{x=X, fontSize=fontSize, fontName=fixedWidthFontName}
  -- TODO: Make this display function's interface more uniform with others
  self:addItem(utils.curry(game.stageTimeDisplay, game), {narrow=true})
  
  Layout.init(self, window, game)
end



return {
  layouts = layouts,
}
