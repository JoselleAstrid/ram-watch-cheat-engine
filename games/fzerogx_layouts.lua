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
-- Displays the addresses of key memory blocks, as computed by the Lua
-- framework.
-- We can double check these addresses in Cheat Engine's Memory View to see
-- if they indeed look like the start of the block. If it doesn't look right,
-- then maybe something is wrong; e.g. maybe a particular pointer in our code
-- doesn't work in all possible cases.
function layouts.addressTest:init()
  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(5)

  self.window:setSize(500, 300)

  self:addLabel{fontSize=fontSize, fontName=fixedWidthFontName}
  self:addItem(
    function()
      local names = {
        'o', 'refPointer', 'racerStateBlocks', 'racerState2Blocks',
        'machineBaseStatsBlocks', 'machineBaseStatsBlocksCustom',
        'machineBaseStatsBlocks2', 'machineBaseStatsBlocks2Custom',
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
-- Provides controls for recording km/h data to a file.
-- The data will go in a file named ram_watch_output.txt. The folder will be
-- either A) the same folder as the Cheat Table you have open, or B) the
-- folder of your Cheat Engine executable, if you don't have a Cheat Table
-- open.
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
-- Displays machine settings along with an Edit button, and a List button
-- which adds the settings value to Cheat Engine's address list.
--
-- Editing is a little wonky. Settings edits won't take effect until you go
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
-- Displays energy values for one or more racers.
--
-- numOfRacers:
--   How many racers you want to display energy for.
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
-- Displays energy values for one or more racers. Each energy value has an
-- Edit button next to it, and a List button which adds the value to Cheat
-- Engine's address list.
--
-- numOfRacers:
--   How many racers you want to display energy for.
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
-- Displays position values for one or more racers.
--
-- numOfRacers:
--   How many racers you want to display positions for.
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
-- Displays a particular machine stat for one or more racers.
--
-- statName:
--   Name of the stat you want to show. Put it in quotes. Example: 'accel'
--   To see all the available stat names, Ctrl+F for statNames in fzerogx.lua.
-- numOfRacers:
--   How many racers you want to display this stat for.
-- withBase:
--   true if you want to display base values as well as actual values.
--   false if you just want actual values.
function layouts.oneMachineStat:init(statName, numOfRacers, withBase)
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
-- Displays all machine stats.
--
-- racerNumber:
--   1 for Player 1, 2 for Player 2 or 1st CPU, 3 for P3 or 2nd CPU, etc.
-- withBase:
--   true if you want to display base values as well as actual values.
--   false if you just want actual values.
function layouts.allMachineStats:init(racerNumber, withBase)
  racerNumber = racerNumber or 1
  withBase = withBase or false

  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(5)
  self:activateAutoPositioningY()

  local windowWidth = 400
  if racerNumber ~= 1 then windowWidth = windowWidth + 200 end
  self.window:setSize(windowWidth, 700)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}

  local racer = game:getBlock(game.Racer, racerNumber)

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
-- Displays all (or some) machine stats with Edit buttons next to them.
--
-- Note: the Edit buttons will usually edit base stat values, which may not
-- match the actual stat values. This is because base stats are easier to edit.
-- Editing actual stats directly usually requires disabling some code
-- instructions.
-- There are also List buttons which add a stat's base and actual values
-- to the Cheat Engine address list. This can help you edit actual stats
-- directly if you want to go through the trouble.
--
-- Note: Editing base stat values might not take effect on CPUs until the
-- next race. Like, you might have to go back to the menus and select a course,
-- etc.
--
-- racerNumber:
--   1 for Player 1, 2 for Player 2 or 1st CPU, 3 for P3 or 2nd CPU, etc.
-- updateWithButton:
--   true if you want the layout to update only when you click a button
--   (a little nicer for Dolphin performance). false if you want the layout to
--   auto-update a few times per second (more convenient to use).
-- initiallyShownStats:
--   Here you can specify just a few stats to show on the layout window
--   initially. Example: {'accel', 'boostDuration', 'maxSpeed'}
--   To see all the available stat names, Ctrl+F for statNames in fzerogx.lua.
function layouts.allMachineStatsEditable:init(
  racerNumber, updateWithButton, initiallyShownStats)

  racerNumber = racerNumber or 1
  updateWithButton = updateWithButton or false
  initiallyShownStats = initiallyShownStats or self.game.statNames

  local game = self.game
  self.margin = 0
  self:activateAutoPositioningY('compact')

  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}

  local toggleElementsButton = self:addButton("Toggle elements")
  toggleElementsButton:setOnClick(function() self:openToggleDisplayWindow() end)
  
  local buttonX = 350
  if racerNumber ~= 1 then buttonX = buttonX + 200 end
  local windowWidth = buttonX + 120

  if updateWithButton then
    local updateButton = self:addButton("Update")
    -- Update when clicking this button
    self:setButtonUpdateMethod(updateButton)
    self.window:setSize(windowWidth, 25 + 27*2 + 27*#game.statNames)
  else
    self:setUpdatesPerSecond(5)
    self.window:setSize(windowWidth, 25 + 27 + 27*#game.statNames)
  end

  local racer = game:getBlock(game.Racer, racerNumber)

  for _, statName in pairs(game.statNames) do
    local element = self:addEditableValue(
      racer[statName], {buttonX=buttonX, checkboxLabel=statName})

    element:setVisible(utils.isValueInTable(initiallyShownStats, statName))
  end
end


layouts.inputs = subclass(Layout)
-- Displays controller inputs for a human racer.
-- Does not work for CPUs or Replay mode.
--
-- calibrated:
--   true if you want to display values AFTER calibration is accounted for.
--   false if you want to display the controller's raw values.
--   Calibration includes 1) stick calibration as defined by your in-game
--   calibration settings, and 2) L/R calibration as defined by the game
--   (e.g. you don't need to push L/R all the way down to get max strafe power).
-- playerNumber:
--   1 for Player 1, 2 for Player 2, etc.
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
-- Displays controls for the player racer in modes that support replays.
-- Works in Time Attack, Grand Prix, instant replays, and Replay mode.
--
-- updatesPerSecond:
--   How often this display should be updated.
--   Set this higher to see more frames of input display (GX runs at
--   60 FPS, so it doesn't make sense to set this much higher than 60).
--   Set this lower if Dolphin is stuttering too much.
-- boostTimer:
--   true if you want to display remaining frames and delay frames for boosts.
--   false if you don't want to display this.
--   Delay frames are displayed with a plus + symbol.
-- netStrafeOnly:
--   true if you want to display L/R input as simply the net strafe amount
--   (R input minus L input).
--   false if you want to display a prediction of how much both L and R are
--   pressed. Replay info only gives us the net strafe and whether both L+R are
--   pressed or not, which is why this is just a prediction. It can give more
--   info, but in some cases it can be misleading.
-- windowWidth:
--   Width of the display window. This is configurable to facilitate using
--   this layout for video recording.
-- windowHeight:
--   Height of the display window.
function layouts.replayInfo:init(
  updatesPerSecond, boostTimer, netStrafeOnly, windowWidth, windowHeight)
  
  updatesPerSecond = updatesPerSecond or 30
  boostTimer = boostTimer or false
  netStrafeOnly = netStrafeOnly or false
  windowWidth = windowWidth or 300
  windowHeight = windowHeight or 500

  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(updatesPerSecond)
  self:activateAutoPositioningY('compact')
  self.window:setSize(windowWidth, windowHeight)
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
-- Displays controls and other info for any racer.
-- Works in any live race, but not for Replays.
-- Works for CPUs.
--
-- racerNumber:
--   1 for Player 1, 2 for Player 2 or 1st CPU, 3 for P3 or 2nd CPU, etc.
-- cpuSteerRange:
--   true if you want to display stick and L/R input with CPU limits
--   (1.35 times that of human racers). Use this if your racerNumber
--   corresponds to a CPU racer.
--   false if you want to display with human limits.
function layouts.racerInfo:init(racerNumber, cpuSteerRange)
  racerNumber = racerNumber or 1
  cpuSteerRange = cpuSteerRange or false

  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(30)
  self:activateAutoPositioningY('compact')

  local windowWidth = 300
  if racerNumber ~= 1 then windowWidth = windowWidth + 200 end
  self.window:setSize(windowWidth, 500)

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
-- Displays checkpoint related info for any racer.
-- Works in any race or replay, and for CPUs.
--
-- racerNumber:
--   1 for Player 1, 2 for Player 2 or 1st CPU, 3 for P3 or 2nd CPU, etc.
function layouts.checkpoints:init(racerNumber)
  racerNumber = racerNumber or 1
  
  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(20)
  self:activateAutoPositioningY()

  local windowWidth = 250
  if racerNumber ~= 1 then windowWidth = windowWidth + 200 end
  self.window:setSize(windowWidth, 370)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}
  self.itemDisplayDefaults = {narrow=true}

  local racer = game:getBlock(game.Racer, racerNumber)

  self:addLabel()
  self:addItem(racer.lapIndexPosition)
  self:addItem(racer.checkpointMain)
  self:addItem(racer.checkpointFraction)
  self:addItem(racer.checkpointLateralOffset)

  self:addLabel()
  self:addItem(racer.raceDistance)
  self:addItem(racer.pos)
end


layouts.timer = subclass(Layout)
-- Displays timer and lap time info for any racer.
-- Works in any race or replay, and for CPUs.
--
-- racerNumber:
--   1 for Player 1, 2 for Player 2 or 1st CPU, 3 for P3 or 2nd CPU, etc.
-- maxPrevLaps:
--   Max number of previous lap times to include on the display.
--   You can set this as high as 8.
function layouts.timer:init(racerNumber, maxPrevLaps)
  racerNumber = racerNumber or 1
  maxPrevLaps = maxPrevLaps or 4

  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(20)
  self:activateAutoPositioningY()

  local windowWidth = 400
  if racerNumber ~= 1 then windowWidth = windowWidth + 200 end
  self.window:setSize(windowWidth, 300)
  self.labelDefaults = {fontSize=fontSize, fontName=fixedWidthFontName}

  local racer = game:getBlock(game.Racer, racerNumber)

  self:addLabel()
  self:addItem(
    racer.raceTimer,
    {maxPrevLaps=maxPrevLaps}
  )
end


layouts.speed224 = subclass(Layout)
-- Displays "speed 224" (base speed?) value for any racer.
-- Works in any race or replay, and for CPUs.
--
-- racerNumber:
--   1 for Player 1, 2 for Player 2 or 1st CPU, 3 for P3 or 2nd CPU, etc.
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
-- Tests miscellaneous functions/values.
--
-- racerNumber:
--   1 for Player 1, 2 for Player 2 or 1st CPU, 3 for P3 or 2nd CPU, etc.
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
