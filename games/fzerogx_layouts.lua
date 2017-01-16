package.loaded.utils = nil
local utils = require 'utils'
local subclass = utils.subclass

package.loaded.valuetypes = nil
local valuetypes = require 'valuetypes'

package.loaded.layouts = nil
local layoutsModule = require 'layouts'
local Layout = layoutsModule.Layout


local layouts = {}

local margin = 6
local fontSize = 12
-- alt: Lucida Console
local fixedWidthFontName = "Consolas"
-- Cheat Engine uses blue-green-red order for some reason
local inputColor = 0x880000



layouts.addressTest = subclass(Layout)
function layouts.addressTest:init()
  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(5)

  self.window:setSize(400, 300)

  self:addLabel{fontSize=fontSize, fontName=fixedWidthFontName}
  self:addItem(
    function()
      local names = {
        'o', 'refPointer', 'racerStateBlocks', 'racerState2Blocks',
        'machineBaseStatsBlocks', 'machineBaseStatsBlocks2',
      }
      local lines = {}
      for _, name in pairs(names) do
        table.insert(
          lines, name..": "..utils.intToHexStr(game.addrs[name]))
      end
      return table.concat(lines, '\n')
    end
  )
end


layouts.kmhRecording = subclass(Layout)
function layouts.kmhRecording:init()
  local game = self.game
  self.margin = margin
  self:setBreakpointUpdateMethod()
  self:activateAutoPositioningY()

  self.window:setSize(400, 130)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}

  local racer = game:getBlock(game.Racer)

  self:addLabel()
  self:addItem(game.settingsSlider)
  self:addItem(racer.kmh)

  self:addFileWriter(
    racer.kmh, "ram_watch_output.txt",
    {beforeDecimal=1, afterDecimal=10})
end


layouts.settingsEditable = subclass(Layout)
-- This is a little wonky. Settings edits won't take effect until you go
-- back to the settings screen. And editing to >100% on the settings screen
-- won't work unless you disable a particular instruction. This layout's
-- List button can help with that.
function layouts.settingsEditable:init()
  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(20)
  self:activateAutoPositioningY()

  self.window:setSize(420, 100)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}

  local racer = game:getBlock(game.Racer)

  self:addEditableValue(game.settingsSlider, {buttonX=300})

  self:addLabel()
  self:addItem(racer.kmh)
end


layouts.energy = subclass(Layout)
function layouts.energy:init(numOfRacers)
  numOfRacers = numOfRacers or 6

  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(20)
  self:activateAutoPositioningY()

  self.window:setSize(400, 23*numOfRacers + 25)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}

  self:addLabel()
  for n = 1, numOfRacers do
    self:addItem(game:getBlock(game.Racer, n).energy)
  end
end


layouts.energyEditable = subclass(Layout)
function layouts.energyEditable:init(numOfRacers)
  numOfRacers = numOfRacers or 6

  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(20)
  self:activateAutoPositioningY()

  self.window:setSize(520, 28*numOfRacers + 25)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}

  for n = 1, numOfRacers do
    self:addEditableValue(game:getBlock(game.Racer, n).energy, {buttonX=400})
  end
end


layouts.position = subclass(Layout)
function layouts.position:init(numOfRacers)
  numOfRacers = numOfRacers or 1

  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(20)
  self:activateAutoPositioningY()

  self.window:setSize(350, 23*4*numOfRacers + 25)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}

  self:addLabel()
  for n = 1, numOfRacers do
    self:addItem(game:getBlock(game.Racer, n).pos)
  end
end


layouts.oneMachineStat = subclass(Layout)
function layouts.oneMachineStat:init(statName, numOfRacers, withBase)
  -- For all the stat names, Ctrl+F for statNames in fzerogx.lua.
  statName = statName or 'accel'
  numOfRacers = numOfRacers or 6
  withBase = withBase or false

  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(5)
  self:activateAutoPositioningY()

  self.window:setSize(500, 23*2*numOfRacers + 25)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}

  self:addLabel()
  for n = 1, numOfRacers do
    local stat = game:getBlock(game.Racer, n)[statName]

    if withBase then
      self:addItem(stat)

      if stat.displayBase then
        self:addItem(function() return stat:displayBase() end)
      else
        self:addItem(function() return "<No base>" end)
      end
    else
      -- Don't display or even calculate the base, if possible.
      -- SizeStats might still calculate the base though.
      if stat.current then
        self:addItem(stat.current)
      else
        self:addItem(stat)
      end
    end
  end
end


layouts.allMachineStats = subclass(Layout)
function layouts.allMachineStats:init(withBase)
  withBase = withBase or false

  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(5)
  self:activateAutoPositioningY()

  self.window:setSize(400, 700)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}

  local racer = game:getBlock(game.Racer)

  self:addLabel()
  for _, statName in pairs(game.statNames) do
    local stat = racer[statName]

    if withBase then
      if stat.displayCurrentAndBase then
        self:addItem(function() return stat:displayCurrentAndBase() end)
      else
        self:addItem(stat)
      end
    else
      -- Don't display or even calculate the base, if possible.
      -- SizeStats might still calculate the base though.
      if stat.current then
        self:addItem(stat.current)
      else
        self:addItem(stat)
      end
    end
  end
end


layouts.allMachineStatsEditable = subclass(Layout)
function layouts.allMachineStatsEditable:init(
  updateWithButton, initiallyShownStats)

  updateWithButton = updateWithButton or false
  -- Example: {'accel', 'boostDuration', maxSpeed'}
  -- For all the stat names, Ctrl+F for statNames in fzerogx.lua.
  initiallyShownStats = initiallyShownStats or self.game.statNames

  local game = self.game
  self.margin = 0
  self:activateAutoPositioningY('compact')

  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}

  local toggleElementsButton = self:addButton("Toggle elements")
  toggleElementsButton:setOnClick(function() self:openToggleDisplayWindow() end)

  if updateWithButton then
    local updateButton = self:addButton("Update")
    self:setButtonUpdateMethod(updateButton)  -- Update when clicking this button
    self.window:setSize(470, 25 + 27*2 + 27*#game.statNames)
  else
    self:setUpdatesPerSecond(5)
    self.window:setSize(470, 25 + 27 + 27*#game.statNames)
  end

  local racer = game:getBlock(game.Racer)

  for _, statName in pairs(game.statNames) do
    local element = self:addEditableValue(
      racer[statName], {buttonX=350, checkboxLabel=statName})

    element:setVisible(utils.isValueInTable(initiallyShownStats, statName))
  end
end


layouts.inputs = subclass(Layout)
function layouts.inputs:init(calibrated, playerNumber)
  calibrated = calibrated or false
  playerNumber = playerNumber or 1

  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(20)
  self:activateAutoPositioningY('compact')

  self.window:setSize(300, 250)

  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}

  local player = game:getBlock(game.Player, playerNumber)

  self:addLabel{foregroundColor=inputColor}
  if calibrated then
    self:addImage(
      game.CalibratedLRImage, {player}, {foregroundColor=inputColor})
    self:addImage(
      game.CalibratedStickImage, {player}, {foregroundColor=inputColor})
    self:addItem(player.calibratedInput, {LR=true, stick=true})
  else
    self:addImage(
      game.ControllerLRImage, {player}, {foregroundColor=inputColor})
    self:addImage(
      game.ControllerStickImage, {player}, {foregroundColor=inputColor})
    self:addItem(player.controllerInput, {LR=true, stick=true})
  end
end


layouts.replayInfo = subclass(Layout)
function layouts.replayInfo:init(updatesPerSecond, boostTimer, netStrafeOnly)
  -- Higher for fine-grainedness, lower for performance
  updatesPerSecond = updatesPerSecond or 30
  -- Show remaining frames and delay frames for boosts
  boostTimer = boostTimer or false
  -- Visualize net strafe value instead of a guess of L and R inputs
  netStrafeOnly = netStrafeOnly or false

  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(updatesPerSecond)
  self:activateAutoPositioningY('compact')
  self.window:setSize(300, 500)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}

  if netStrafeOnly then
    self:addImage(game.ReplayStrafeImage, {game}, {foregroundColor=inputColor})
  else
    self:addImage(game.ReplayLRImage, {game}, {foregroundColor=inputColor})
  end
  self:addImage(game.ReplaySteerImage, {game}, {foregroundColor=inputColor})

  self:addLabel{foregroundColor=inputColor}
  self:addItem(game.replayInput, {strafe=true, steer=true})

  local racer = game:getBlock(game.Racer)

  self:addLabel()
  if boostTimer then
    self:addItem(
      function() return "Boost: "..racer.controlState:boostDisplay() end)
  end
  self:addItem(racer.energy)

  self:addLabel()
  self:addItem(racer.raceTimer)
end


layouts.racerInfo = subclass(Layout)
function layouts.racerInfo:init(racerNumber, cpuSteerRange)
  racerNumber = racerNumber or 1
  cpuSteerRange = cpuSteerRange or false

  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(30)
  self:activateAutoPositioningY('compact')

  self.window:setSize(300, 500)

  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}

  local racer = game:getBlock(game.Racer, racerNumber)

  self:addImage(
    game.ControlStateStrafeImage, {racer},
    {cpuSteerRange=cpuSteerRange, foregroundColor=inputColor})
  self:addImage(
    game.ControlStateSteerImage, {racer},
    {cpuSteerRange=cpuSteerRange, foregroundColor=inputColor})

  self:addLabel{foregroundColor=inputColor}
  self:addItem(racer.controlState, {strafe=true, steer=true})

  self:addLabel()
  self:addItem(racer.energy)

  self:addLabel()
  self:addItem(racer.raceTimer)
end


layouts.checkpoints = subclass(Layout)
function layouts.checkpoints:init()
  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(20)
  self:activateAutoPositioningY()

  self.window:setSize(250, 400)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}

  local racer = game:getBlock(game.Racer)

  self:addLabel()
  self:addItem(racer.lapIndexPosition)
  self:addItem(racer.checkpointMain)
  self:addItem(racer.checkpointFraction)
  self:addItem(racer.checkpointLateralOffset)

  self:addLabel()
  self:addItem(racer.pos)
  self:addItem(racer.checkpointRightVector)
end


layouts.timer = subclass(Layout)
function layouts.timer:init(racerNumber, maxPrevLaps, withFrameFraction)
  racerNumber = racerNumber or 1
  maxPrevLaps = maxPrevLaps or 4
  withFrameFraction = withFrameFraction or false

  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(20)
  self:activateAutoPositioningY()

  self.window:setSize(500, 300)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}

  local racer = game:getBlock(game.Racer, racerNumber)

  self:addLabel()
  self:addItem(
    racer.raceTimer,
    {maxPrevLaps=maxPrevLaps, withFrameFraction=withFrameFraction}
  )
end


layouts.speed224 = subclass(Layout)
function layouts.speed224:init(racerNumber)
  racerNumber = racerNumber or 1

  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(20)
  self:activateAutoPositioningY()

  self.window:setSize(450, 250)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}

  local racer = game:getBlock(game.Racer, racerNumber)

  self:addLabel()
  self:addItem(racer.speed224)
  self:addItem(racer.kmh)
  self:addItem(
    function()
      return "Ratio: "..utils.floatToStr(racer.kmh:get() / racer.speed224:get())
    end
  )
end


layouts.testMisc = subclass(Layout)
function layouts.testMisc:init(racerNumber)
  racerNumber = racerNumber or 1

  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(20)
  self:activateAutoPositioningY()

  self.window:setSize(450, 250)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}

  local racer = game:getBlock(game.Racer, racerNumber)

  self:addLabel()
  self:addItem(game:V(valuetypes.RateOfChange, racer.kmh, "km/h change"))
  self:addItem(game:V(valuetypes.MaxValue, racer.kmh))
  self:addItem(game:V(valuetypes.AverageValue, racer.kmh))
end



return {
  layouts = layouts,
}
