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
      local names = {
        'o', 'refPointer', 'racerStateBlocks', 'racerState2Blocks',
        'machineBaseStatsBlocks', 'machineBaseStatsBlocks2',
      }
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


layouts.kmhRecording = subclass(Layout)
function layouts.kmhRecording:init(window, game)
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()
  
  self.windowSize = {400, 130}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  
  local racer = game:getBlock(game.Racer)
    
  self:addLabel()
  self:addItem(game.settingsSlider)
  self:addItem(racer.kmh)
  
  self:addFileWriter(
    racer.kmh, "ram_watch_output.txt",
    {beforeDecimal=1, afterDecimal=10})
  
  Layout.init(self, window, game)
end


layouts.energy = subclass(Layout)
function layouts.energy:init(window, game, numOfRacers)
  numOfRacers = numOfRacers or 6
  
  self:setTimerUpdateMethod(50)  -- Update every 50 ms (20x per second)
  self:activateAutoPositioningY()
  
  self.windowSize = {400, 23*numOfRacers + 25}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  
  self:addLabel()
  for n = 1, numOfRacers do
    self:addItem(game:getBlock(game.Racer, n).energy)
  end
  
  Layout.init(self, window, game)
end


layouts.energyEditable = subclass(Layout)
function layouts.energyEditable:init(window, game, numOfRacers)
  numOfRacers = numOfRacers or 6
  
  self:setTimerUpdateMethod(50)  -- Update every 50 ms (20x per second)
  self:activateAutoPositioningY()
  
  self.windowSize = {520, 28*numOfRacers + 25}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  
  for n = 1, numOfRacers do
    self:addEditableValue(game:getBlock(game.Racer, n).energy, {buttonX=400})
  end
  
  Layout.init(self, window, game)
end


layouts.position = subclass(Layout)
function layouts.position:init(window, game, numOfRacers)
  numOfRacers = numOfRacers or 1
  
  self:setTimerUpdateMethod(50)  -- Update every 50 ms (20x per second)
  self:activateAutoPositioningY()
  
  self.windowSize = {350, 23*4*numOfRacers + 25}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}
  
  self:addLabel()
  for n = 1, numOfRacers do
    self:addItem(game:getBlock(game.Racer, n).pos)
  end
  
  Layout.init(self, window, game)
end


layouts.oneMachineStat = subclass(Layout)
function layouts.oneMachineStat:init(window, game, statName, numOfRacers)
  statName = statName or 'accel'
  numOfRacers = numOfRacers or 6
  
  self:setTimerUpdateMethod(200)  -- Update every 200 ms (5x per second)
  self:activateAutoPositioningY()
  
  self.windowSize = {500, 23*2*numOfRacers + 25}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  
  self:addLabel()
  for n = 1, numOfRacers do
    local stat = game:getBlock(game.Racer, n)[statName]
    self:addItem(stat)
    self:addItem(
      function ()
        if stat.displayBase then
          return stat:displayBase()
        else
          return "<No base>"
        end
      end
    )
  end
  
  Layout.init(self, window, game)
end


layouts.allMachineStats = subclass(Layout)
function layouts.allMachineStats:init(window, game)
  self:setTimerUpdateMethod(200)  -- Update every 200 ms (5x per second)
  self:activateAutoPositioningY()
  
  self.windowSize = {400, 700}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  
  local racer = game:getBlock(game.Racer)
  
  self:addLabel()
  for _, statName in pairs(game.statNames) do
    self:addItem(
      function ()
        local stat = racer[statName]
        if stat.displayCurrentAndBase then
          return stat:displayCurrentAndBase()
        else
          return stat:display()
        end
      end)
  end
  
  Layout.init(self, window, game)
end


layouts.allMachineStatsEditable = subclass(Layout)
function layouts.allMachineStatsEditable:init(window, game)
  self:setTimerUpdateMethod(200)  -- Update every 200 ms (5x per second)
  self:activateAutoPositioningY()
  
  self.windowSize = {470, 28*#game.statNames + 25}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  
  local racer = game:getBlock(game.Racer)
  
  for _, statName in pairs(game.statNames) do
    self:addEditableValue(racer[statName], {buttonX=350})
  end
  
  Layout.init(self, window, game)
end


layouts.inputs = subclass(Layout)
function layouts.inputs:init(window, game, calibrated, playerNumber, narrow)
  self:setTimerUpdateMethod(50)  -- Update every 50 ms (20x per second)
  self:activateAutoPositioningY()
  
  calibrated = calibrated or false
  playerNumber = playerNumber or 1
  narrow = narrow or false
  
  if narrow then
    self.windowSize = {200, 220}
  else
    self.windowSize = {300, 150}
  end
  
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=narrow}
  
  local player = game:getBlock(game.Player, playerNumber)
  
  self:addLabel()
  if calibrated then
    self:addItem(player.calibratedInput)
  else
    self:addItem(player.controllerInput)
  end
  
  Layout.init(self, window, game)
end


layouts.replayInfo = subclass(Layout)
function layouts.replayInfo:init(window, game, racerNumber, narrow)
  self:setTimerUpdateMethod(50)  -- Update every 50 ms (20x per second)
  self:activateAutoPositioningY()
  
  racerNumber = racerNumber or 1
  narrow = narrow or false
  
  if narrow then
    self.windowSize = {200, 220}
  else
    self.windowSize = {300, 150}
  end
  
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=narrow}
  
  local racer = game:getBlock(game.Racer, racerNumber)
  
  self:addLabel()
  self:addItem(racer.controlState)
  
  Layout.init(self, window, game)
end


layouts.checkpoints = subclass(Layout)
function layouts.checkpoints:init(window, game)
  self:setTimerUpdateMethod(50)  -- Update every 50 ms (20x per second)
  self:activateAutoPositioningY()
  
  self.windowSize = {250, 400}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}
  
  local racer = game:getBlock(game.Racer)
  
  self:addLabel()
  self:addItem(racer.lapNumberPosition)
  self:addItem(racer.checkpointMain)
  self:addItem(racer.checkpointFraction)
  self:addItem(racer.checkpointLateralOffset)
  
  self:addLabel()
  self:addItem(racer.pos)
  self:addItem(racer.checkpointRightVector)
  
  Layout.init(self, window, game)
end


layouts.timer = subclass(Layout)
function layouts.timer:init(
  window, game, racerNumber, maxPrevLaps, withFrameFraction)
  
  racerNumber = racerNumber or 1
  maxPrevLaps = maxPrevLaps or 4
  withFrameFraction = withFrameFraction or false

  self:setTimerUpdateMethod(50)  -- Update every 50 ms (20x per second)
  self:activateAutoPositioningY()
  
  self.windowSize = {450, 250}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  
  local racer = game:getBlock(game.Racer, racerNumber)
  
  self:addLabel()
  self:addItem(
    racer.raceTimer,
    {maxPrevLaps=maxPrevLaps, withFrameFraction=withFrameFraction}
  )
  
  Layout.init(self, window, game)
end


layouts.speed224 = subclass(Layout)
function layouts.speed224:init(window, game, racerNumber)
  racerNumber = racerNumber or 1

  self:setTimerUpdateMethod(50)  -- Update every 50 ms (20x per second)
  self:activateAutoPositioningY()
  
  self.windowSize = {450, 250}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  
  local racer = game:getBlock(game.Racer, racerNumber)
  
  self:addLabel()
  self:addItem(racer.speed224)
  self:addItem(racer.kmh)
  self:addItem(
    function()
      return "Ratio: "..utils.floatToStr(racer.kmh:get() / racer.speed224:get())
    end
  )
  
  Layout.init(self, window, game)
end



return {
  layouts = layouts,
}
