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
        'o', 'refPointer', 'machineStateBlocks', 'machineState2Blocks',
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
  
  local state = game:getMachineState()
    
  self:addLabel()
  self:addItem(game.settingsSlider)
  self:addItem(state.kmh)
  
  self:addFileWriter(
    state.kmh, "ram_watch_output.txt",
    {beforeDecimal=1, afterDecimal=10})
  
  Layout.init(self, window, game)
end


-- TODO: Support this as a parameterized layout, passing in numOfMachines
layouts.energy = subclass(Layout)
function layouts.energy:init(window, game, numOfMachines)
  numOfMachines = numOfMachines or 6
  
  self:setTimerUpdateMethod(50)  -- Update every 50 ms (20x per second)
  self:activateAutoPositioningY()
  
  -- TODO: Determine window's height dynamically from numOfMachines
  self.windowSize = {400, 300}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  
  self:addLabel()
  for i = 0, numOfMachines-1 do
    self:addItem(game:getMachineState(i).energy)
  end
  
  Layout.init(self, window, game)
end


-- TODO: Support this as a parameterized layout
layouts.oneMachineStat = subclass(Layout)
function layouts.oneMachineStat:init(window, game, numOfMachines, statName)
  numOfMachines = numOfMachines or 6
  statName = statName or 'accel'
  
  self:setTimerUpdateMethod(200)  -- Update every 200 ms (5x per second)
  self:activateAutoPositioningY()
  
  -- TODO: Determine window's height dynamically from numOfMachines
  self.windowSize = {500, 320}
  self.labelDefaults = {
    x=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  
  self:addLabel()
  for i = 0, numOfMachines-1 do
    self:addItem(game:getMachineState(i)[statName])
    self:addItem(
      function () return game:getMachineState(i)[statName]:displayBase() end)
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
  
  local state = game:getMachineState()
  
  self:addLabel()
  for _, statName in pairs(game.statNames) do
    self:addItem(
      function ()
        local stat = state[statName]
        if stat.displayCurrentAndBase then
          return stat:displayCurrentAndBase()
        else
          return stat:display()
        end
      end)
  end
  
  Layout.init(self, window, game)
end



return {
  layouts = layouts,
}
