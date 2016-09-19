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

-- TODO: Get this working again...
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


-- TODO: Support this as a parameterized layout, passing in numOfRacers
layouts.energy = subclass(Layout)
function layouts.energy:init(window, game, numOfRacers)
  numOfRacers = numOfRacers or 6
  
  self:setTimerUpdateMethod(50)  -- Update every 50 ms (20x per second)
  self:activateAutoPositioningY()
  
  -- TODO: Determine window's height dynamically from numOfRacers
  self.windowSize = {400, 300}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  
  self:addLabel()
  for i = 0, numOfRacers-1 do
    self:addItem(game:getBlock(game.Racer, i).energy)
  end
  
  Layout.init(self, window, game)
end


layouts.position = subclass(Layout)
function layouts.position:init(window, game)
  self:setTimerUpdateMethod(50)  -- Update every 50 ms (20x per second)
  self:activateAutoPositioningY()
  
  self.windowSize = {350, 200}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}
  
  self:addLabel()
  self:addItem(game:getBlock(game.Racer).pos)
  self:addItem(game:getBlock(game.Racer, 1).pos)
  
  Layout.init(self, window, game)
end


-- TODO: Support this as a parameterized layout
layouts.oneMachineStat = subclass(Layout)
function layouts.oneMachineStat:init(window, game, numOfRacers, statName)
  numOfRacers = numOfRacers or 6
  statName = statName or 'accel'
  
  self:setTimerUpdateMethod(200)  -- Update every 200 ms (5x per second)
  self:activateAutoPositioningY()
  
  -- TODO: Determine window's height dynamically from numOfRacers
  self.windowSize = {500, 320}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  
  self:addLabel()
  for i = 0, numOfRacers-1 do
    self:addItem(game:getBlock(game.Racer, i)[statName])
    self:addItem(
      function ()
        return game:getBlock(game.Racer, i)[statName]:displayBase()
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



return {
  layouts = layouts,
}
