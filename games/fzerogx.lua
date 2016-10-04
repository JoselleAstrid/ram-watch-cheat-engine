-- F-Zero GX
-- US version
local gameId = "GFZE01"



-- Imports.

-- First make sure that the imported modules get de-cached as needed. That way,
-- if we change the code in those modules and then re-run the script, we won't
-- need to restart Cheat Engine to see the code changes take effect.

package.loaded.utils = nil
local utils = require "utils"
local readIntBE = utils.readIntBE
local readFloatBE = utils.readFloatBE
local floatToStr = utils.floatToStr
local initLabel = utils.initLabel
local StatRecorder = utils.StatRecorder
local subclass = utils.subclass
local classInstantiate = utils.classInstantiate

package.loaded.dolphin = nil
local dolphin = require "dolphin"

package.loaded.valuetypes = nil
local valuetypes = require "valuetypes"
local V = valuetypes.V
local MV = valuetypes.MV
local Block = valuetypes.Block
local Value = valuetypes.Value
local MemoryValue = valuetypes.MemoryValue
local FloatValue = valuetypes.FloatValue
local IntValue = valuetypes.IntValue
local ShortValue = valuetypes.ShortValue
local ByteValue = valuetypes.ByteValue
local SignedIntValue = valuetypes.SignedIntValue
local SignedShortValue = valuetypes.SignedShortValue
local SignedByteValue = valuetypes.SignedByteValue
local StringValue = valuetypes.StringValue
local BinaryValue = valuetypes.BinaryValue
local Vector3Value = valuetypes.Vector3Value
local RateOfChange = valuetypes.RateOfChange
local addAddressToList = valuetypes.addAddressToList



local GX = subclass(dolphin.DolphinGame)

GX.layoutModuleNames = {'fzerogx_layouts'}

function GX:init(options)
  dolphin.DolphinGame.init(self, options)
  
  if options.gameVersion == 'US' then
    self.gameId = "GFZE01"
  else
    error("gameVersion not supported: " .. options.gameVersion)
  end
  
  self.addrs = {}
  self:initConstantAddresses()
end

local GV = GX.blockValues



-- These are addresses that should stay constant for the most part,
-- as long as the game start address is constant.

function GX:initConstantAddresses()
  self.addrs.o = self:getGameStartAddress()

  self.addrs.machineBaseStatsBlocks = self.addrs.o + 0x1554000
  self.addrs.machineBaseStatsBlocksCustom = self.addrs.o + 0x1555F04
  
  -- It's useful to have an address where there's always a ton of zeros.
  -- We can use this address as the result when an address computation
  -- is invalid. Zeros are better than unreadable memory (results in
  -- error) or garbage values.
  -- This group of zeros should go on for 0x60000 to 0x70000 bytes.
  self.addrs.zeros = self.addrs.o + 0xB4000
end
  


-- These addresses can change more frequently, so we specify them as
-- functions that can be run continually.

function GX:updateRefPointer()
  -- Not sure what this is meant to point to exactly, but when this pointer
  -- changes value, many other relevant addresses (like the settings
  -- slider value) move by the same amount as the value change.
  --
  -- This pointer doesn't change during the game, but it is different
  -- between different runs of the game. So it can change if you close the
  -- game and restart it, or load a state from a different run of the game.
  self.addrs.refPointer =
    self.addrs.o
    + readIntBE(self.addrs.o + 0x1B78A8, 4)
    - 0x80000000
end

function GX:updateMachineStatsAndStateAddresses()
  -- A duplicate of the base stats block. We'll use this as a backup of the
  -- original values, when playing with the values in the primary block.
  self.addrs.machineBaseStatsBlocks2 = self.addrs.refPointer + 0x195584
  
  -- Same but for custom machines.
  self.addrs.machineBaseStatsBlocks2Custom = self.addrs.refPointer + 0x1B3A54
  
  -- Racer state.
  local pointer2Address = self.addrs.refPointer + 0x22779C
  local pointer2Value = readIntBE(pointer2Address, 4)
  
  if pointer2Value == 0 then
    -- A race is not going on, so there are no valid racer state addresses.
    self.addrs.racerStateBlocks = nil
    self.addrs.racerState2Blocks = nil
  else
    self.addrs.racerStateBlocks = self.addrs.o + pointer2Value - 0x80000000
    
    local pointer3Address = self.addrs.racerStateBlocks - 0x20
    self.addrs.racerState2Blocks =
      self.addrs.o + readIntBE(pointer3Address, 4) - 0x80000000
  end
end

function GX:updateAddresses()
  self:updateRefPointer()
  self:updateMachineStatsAndStateAddresses()
end



-- Values at static addresses (from the beginning of the game memory).
local StaticValue = subclass(MemoryValue)
GX.StaticValue = StaticValue

function StaticValue:getAddress()
  return self.game.addrs.o + self.offset
end



-- Values that are a constant offset from the refPointer.
local RefValue = subclass(MemoryValue)
GX.RefValue = RefValue

function RefValue:getAddress()
  return self.game.addrs.refPointer + self.offset
end



-- Must be added to MachineBaseStats.
local BaseStat1Value = subclass(MemoryValue)
GX.BaseStat1Value = BaseStat1Value

function BaseStat1Value:getAddress()
  if self.block.isCustom then
    return (self.game.addrs.machineBaseStatsBlocksCustom
      + (0xB4 * self.block.machineOrPartId)
      + self.offset)
  else
    return (self.game.addrs.machineBaseStatsBlocks
      + (0xB4 * self.block.machineOrPartId)
      + self.offset)
  end
end



-- Must be added to MachineBaseStats2.
local BaseStat2Value = subclass(MemoryValue)
GX.BaseStat2Value = BaseStat2Value

function BaseStat2Value:getAddress()
  if self.block.isCustom then
    -- There's some extra bytes before the cockpit part stats,
    -- and more extra bytes before the booster part stats.
    -- extraBytes accounts for this.
    local extraBytes = 0
    if self.block.machineOrPartId > 49 then extraBytes = 24 + 16
    elseif self.block.machineOrPartId > 24 then extraBytes = 24
    end
    return (self.game.addrs.machineBaseStatsBlocks2Custom
      + (0xB4 * self.block.machineOrPartId)
      + extraBytes
      + self.offset)
  else
    return (self.game.addrs.machineBaseStatsBlocks2
      + (0xB4 * self.block.machineOrPartId)
      + self.offset)
  end
end



local RacerValue = subclass(valuetypes.BlockValue)

function RacerValue:getLabel()
  if self.racer.racerIndex == 0 then
    return self.label
  end
  
  if self.racer.machineName:isValid() then
    return string.format(
      "%s, %s", self.label, self.racer.machineName:get())
  end
  
  return self.label
end

function RacerValue:isValid()
  if self.game.addrs.racerStateBlocks == nil then
    self.invalidDisplay = "<Race not active>"
    return false
  end
  
  local racerNumber = self.racer.racerIndex + 1
  if self.game.numOfRacers:get() < racerNumber then
    self.invalidDisplay = string.format("<Racer %d not active>", racerNumber)
    return false
  end
    
  return true
end



local PlayerValue = subclass(valuetypes.BlockValue)

function PlayerValue:getLabel()
  if self.player.playerIndex == 0 then
    return self.label
  else
    return self.label..string.format(", P%d", self.player.playerIndex + 1)
  end
end



-- 0x620-byte memory block that's dense with useful information.
-- There's one such block per racer.
local StateValue = subclass(MemoryValue, RacerValue)
GX.StateValue = StateValue

function StateValue:getAddress()
  return (self.game.addrs.racerStateBlocks
    + (0x620 * self.racer.racerIndex)
    + self.offset)
end



-- Another memory block that has some useful information.
-- There's one such block per racer. 0x760 for humans and
-- 0x820 for CPUs.
local State2Value = subclass(MemoryValue, RacerValue)
GX.State2Value = State2Value

function State2Value:getAddress()
  local humans = self.game.numOfHumanRacers:get()
  if self.racer.racerIndex <= humans then
    return self.game.addrs.racerState2Blocks + self.offset
    + (0x760 * self.racer.racerIndex)
  else
    return self.game.addrs.racerState2Blocks + self.offset
    + (0x760 * humans + 0x820 * (self.racer.racerIndex - humans))
  end
end



local CustomPartId = subclass(StateValue)
GX.CustomPartId = CustomPartId

function CustomPartId:getAddress()
  -- Player 2's custom part IDs are 0x81C0 later than P1's, and then P3's IDs
  -- are 0x81C0 later than that, and so on.
  return self.game.addrs.refPointer
    + 0x1C7588
    + (0x81C0 * self.racer.racerIndex)
    + self.offset
end



local Racer = subclass(Block)
Racer.blockAlias = 'racer'
GX.Racer = Racer
local RV = Racer.blockValues

function Racer:init(racerNumber)
  racerNumber = racerNumber or 1
  self.racerIndex = racerNumber - 1
  Block.init(self)
end

function Racer:getBlockKey(racerNumber)
  racerNumber = racerNumber or 1
  return racerNumber
end

local racerAdd = utils.curry(Racer.addWithAutomaticKey, Racer)


local Player = subclass(Block)
Player.blockAlias = 'player'
GX.Player = Player
local PV = Player.blockValues

function Player:init(playerNumber)
  playerNumber = playerNumber or 1
  self.playerIndex = playerNumber - 1
  Block.init(self)
end

function Player:getBlockKey(playerNumber)
  playerNumber = playerNumber or 1
  return playerNumber
end

function Player:add(value, distanceBetweenPlayers)
  -- Update the value's getAddress() function: the original function should
  -- assume Player 1, and we want a function that gets the address
  -- for any player.
  function f(originalGetAddress, distanceBetweenPlayers_, self_)
    local distanceFromP1 = distanceBetweenPlayers_ * self_.player.playerIndex
    return originalGetAddress(self_) + distanceFromP1
  end
  value.getAddress = utils.curry(f, value.getAddress, distanceBetweenPlayers)
  
  return Player:addWithAutomaticKey(value)
end


local MachineBaseStats = subclass(Block)
GX.MachineBaseStats = MachineBaseStats

function MachineBaseStats:init(machineOrPartId, isCustom)
  self.machineOrPartId = machineOrPartId
  self.isCustom = isCustom
  Block.init(self)
end

function MachineBaseStats:getBlockKey(machineOrPartId, isCustom)
  local key = tostring(machineOrPartId)
  if isCustom then key = key..'C' end
  return key
end


local MachineBaseStats2 = subclass(MachineBaseStats)
GX.MachineBaseStats2 = MachineBaseStats2



local StatWithBase = subclass(Value, RacerValue)
GX.StatWithBase = StatWithBase

function StatWithBase:init()
  -- MemoryValue containing current stat value
  self.current = self.racer[self.currentKey]
end

function StatWithBase:updateStatBasesIfMachineChanged()
  -- Note: it's possible that more than one custom part has a nonzero
  -- base value here. (Check with #self.customPartsWithBase == 1)
  -- Weight and Body are the only stats where this is true. 
  -- 
  -- But handling this properly seems to take a fair bit of extra work,
  -- so no matter what, we'll just get one nonzero base value.
  -- Specifically we'll get the first one, by indexing with [1].
  -- 
  -- That's still enough to fully manipulate the stats; it'll just be a bit
  -- unintuitive. e.g. to change Gallant Star-G4's weight, you have to
  -- manipulate Dread Hammer's weight (the interface doesn't let you
  -- manipulate the other two parts):
  -- 2660 to 1660 weight: change Dread Hammer's weight from 1440 to 440
  -- 2660 to 660 weight: change Dread Hammer's weight from 1440 to -560
  local machineOrPartId = self.racer.machineId:get()
  
  -- If custom machine, id is 50 for P1, 51 for P2...
  local isCustom = (machineOrPartId >= 50)
  if isCustom then
    local customPartTypeWithBase = self.customPartsWithBase[1]
    machineOrPartId = self.racer:customPartIds(customPartTypeWithBase):get()
  end
  
  if self.machineOrPartId == machineOrPartId and self.isCustom == isCustom then
    -- Machine or part hasn't changed.
    return
  end
  
  self.machineOrPartId = machineOrPartId
  self.isCustom = isCustom
  self.base =
    self.game:getBlock(MachineBaseStats, machineOrPartId, isCustom)[self.baseKey]
  self.base2 =
    self.game:getBlock(MachineBaseStats2, machineOrPartId, isCustom)[self.base2Key]
end

function StatWithBase:isValid()
  local isValid = self.current:isValid()
  self.invalidDisplay = self.current.invalidDisplay
  return isValid
end

function StatWithBase:hasChanged()
  -- Implementation: Check if the actual value and backup base value
  -- are the same.
  --
  -- Assumes you don't go into the memory and change the backup base value.
  --
  -- Assumes there is no formula between the base and actual values,
  -- though this can be changed for specific stats by overriding this function.
  --
  -- Limitation: If the game is paused, then the actual value will not reflect
  -- the base value yet. So the "this is changed" display can be misleading
  -- if you forget that.
  return not self.current:equals(self.base2)
end

function StatWithBase:getResetValue()
  return self.base2:get()
end

function StatWithBase:set(v)
  self.current:set(v)
end
function StatWithBase:strToValue(s)
  return self.current:strToValue(s)
end
function StatWithBase:toStrForEditField(v, options)
  return self.current:toStrForEditField(v, options)
end
function StatWithBase:getEditFieldText()
  return self.current:getEditFieldText()
end

function StatWithBase:getAddressListEntries()
  -- We won't add the base stat; it's not all that useful since editing it
  -- doesn't change the actual stat mid-race.
  return self.current:getAddressListEntries()
end

function StatWithBase:updateValue()
  -- TODO: Call this less frequently?
  self:updateStatBasesIfMachineChanged()
  
  self.current:update()
  self.base:update()
  self.base2:update()
end

function StatWithBase:displayValue(options)
  local s = self.current:displayValue(options)
  if self:hasChanged() then
    s = s.."*"
  end
  return s
end

function StatWithBase:displayBase(options)
  -- Use self:getLabel() to ensure the machine name is included
  -- when racerIndex > 0.
  options = options or {}
  options.label = options.label or self:getLabel().." (B)"
  
  if self:isValid() then
    return self.base:display(options)
  end
  -- If not valid, self.base might not be set, so we just use self:display()
  return self:display(options)
end

function StatWithBase:displayCurrentAndBaseValues(options)
  local current = self.current:displayValue(options)
  local base = self.base:displayValue(options)
  local star = ""
  if self:hasChanged() then star = "*" end
  local s = string.format(
    "%s%s (B=%s)",
    current, star, base)
  return s
end

function StatWithBase:displayCurrentAndBase(options)
  options = options or {}
  
  if self:isValid() then
    options.valueDisplayFunction =
      utils.curry(self.displayCurrentAndBaseValues, self)
    return self:display(options)
  end
  -- If not valid, just use self:display(),
  -- which should display the invalid-value message
  return self:display(options)
end


-- This is a stat whose state value changes when the base value changes,
-- even during mid-race.
-- This is convenient when we want to edit the value, because editing
-- the state value directly requires disabling the instruction(s) that are
-- writing to it, while editing the base value doesn't require this.

local StatTiedToBase = subclass(StatWithBase)
GX.StatTiedToBase = StatTiedToBase

function StatTiedToBase:hasChanged()
  -- Implementation: Check if the primary and backup base values are different.
  --
  -- Assumes that you only change this stat by changing its base
  -- values, rather than the actual value.
  --
  -- Does not fully account for base -> actual formulas in two ways:
  -- (1) Actual values of other stats could be changed by changing the base
  -- value of Accel (it's special that way).
  -- (2) Actual values could stay the same even when the base value
  -- is different. For example, Turn decel's actual value may be locked at
  -- 0.01 for a variety of base values.
  --
  -- Limitation: If the game is paused, then the actual value will not reflect
  -- the base value yet. So the "this is changed" display can be misleading
  -- if you forget that.
  return not self.base:equals(self.base2)
end

function StatTiedToBase:set(v)
  self.base:set(v)
end
function StatTiedToBase:strToValue(s)
  return self.base:strToValue(s)
end
function StatTiedToBase:toStrForEditField(v, options)
  return self.base:toStrForEditField(v, options)
end
function StatTiedToBase:getEditFieldText()
  return self.base:getEditFieldText()
end
function StatTiedToBase:getEditWindowTitle()
  return string.format("Edit: %s (base value)", self:getLabel())
end

function StatTiedToBase:getAddressListEntries()
  local entries = {}
  for _, e in pairs(self.current:getAddressListEntries()) do
    table.insert(entries, e)
  end
  for _, e in pairs(self.base:getAddressListEntries()) do
    table.insert(entries, e)
  end
  return entries
end


-- Machine-size stats.
--
-- There are 24 such stats, but they have a lot of redundancy in practice.
-- For example, it seems that no machine has a different back length on the
-- left side versus the right side. And the tilt vs. wall collision values
-- are always a constant offset from each other.
--
-- We'll put the 24 machine-size coordinates in 6 objects, with each object
-- having 4 coordinates within a constant offset/factor.

local SizeStat = subclass(Value)
GX.SizeStat = SizeStat

function SizeStat:init()
  self.stats = {}
  for n = 1, 4 do
    table.insert(self.stats, self.racer[self.statKeys[n]])
  end
end

function SizeStat:isValid()
  return (
    self.stats[1]:isValid() and self.stats[2]:isValid()
    and self.stats[3]:isValid() and self.stats[4]:isValid()
  )
end

function SizeStat:hasChanged()
  -- If we only call set() of this class then it'd suffice to check stat 1,
  -- but here we check for tweaking of individual stats as well.
  return (
    self.stats[1]:hasChanged() or self.stats[2]:hasChanged()
    or self.stats[3]:hasChanged() or self.stats[4]:hasChanged()
  )
end

function SizeStat:getResetValue()
  return self.stats[1]:getResetValue()
end

function SizeStat:set(v)
  -- Take v to be the value for stat 1. Use the formulas to find appropriate
  -- values for the other stats.
  -- If you want more customization, and are fine with seeing phenomena you'd
  -- never see in normal play (e.g. left side 'heavier' than right), then call
  -- mySizeStat.stats[n]:set(v) instead.
  for n = 1, 4 do
    self.stats[n]:set(
      -- A couple of formulas require the machine ID.
      -- The other formulas will just safely ignore the ID.
      self.formulas[n](v, self.racer.machineId:get())
    )
  end
end
function SizeStat:strToValue(s)
  return self.stats[1]:strToValue(s)
end
function SizeStat:toStrForEditField(v, options)
  return self.stats[1]:toStrForEditField(v, options)
end
function SizeStat:getEditFieldText()
  return self.stats[1]:getEditFieldText()
end

function SizeStat:getAddressListEntries()
  local entries = {}
  for n = 1, 4 do
    for _, e in pairs(self.stats[n]:getAddressListEntries()) do
      table.insert(entries, e)
    end
  end
  return entries
end

SizeStat.getLabel = StateValue.getLabel

function SizeStat:updateValue()
  self.stats[1]:updateValue()
end

function SizeStat:displayValue(options)
  return self.stats[1]:displayValue(options)
end
function SizeStat:displayBase(options)
  options = options or {}
  options.label = options.label or self:getLabel().." (B)"
  return self.stats[1]:displayBase(options)
end
function SizeStat:displayCurrentAndBase(options)
  options = options or {}
  options.label = options.label or self:getLabel()
  return self.stats[1]:displayCurrentAndBase(options)
end



local FloatStat = subclass(FloatValue)
GX.FloatStat = FloatStat

-- For machine stats that are floats, we'll prefer trimming zeros in the
-- display so that the number looks cleaner. (Normally we keep trailing
-- zeros when the value can change rapidly, as it is jarring when the
-- display constantly gains/loses digits... but machine stats don't
-- change rapidly.)
FloatStat.displayDefaults = {trimTrailingZeros=true, afterDecimal=4}



local function defineStateFloat(label, offset)
  return MV(label, offset, StateValue, FloatValue)
end

local function defineStatWithBase(
    label, offset, baseOffset,
    valueClass, typeMixinClass, customPartsWithBase,
    extraArgs, baseExtraArgs)
  local obj = V(valueClass)
  
  obj.label = label
  obj.baseOffset = baseOffset
  obj.customPartsWithBase = customPartsWithBase
  obj.baseExtraArgs = baseExtraArgs
  
  -- Add to the current stats
  local current = MV(label, offset, StateValue, typeMixinClass, extraArgs)
  obj.currentKey = Racer:addWithAutomaticKey(current)
  obj.displayDefaults = current.displayDefaults
  
  -- Add to the base stats
  obj.baseKey = MachineBaseStats:addWithAutomaticKey(
    MV(
      label.." (B)", baseOffset,
      BaseStat1Value, typeMixinClass, baseExtraArgs))
  obj.base2Key = MachineBaseStats2:addWithAutomaticKey(
    MV(
      label.." (B)", baseOffset,
      BaseStat2Value, typeMixinClass, baseExtraArgs))
  
  return obj
end

local function defineSizeStat(
    label, specificLabels, offsets, baseOffsets, formulas)
  local obj = V(SizeStat)
  
  obj.label = label
  obj.statKeys = {}
  for n = 1, 4 do
    local stat = defineStatWithBase(
      specificLabels[n], offsets[n], baseOffsets[n],
      StatWithBase, FloatStat,
      -- SizeStats on custom machines are always influenced by only the body,
      -- not the cockpit or booster.
      {1}
    )
    table.insert(obj.statKeys, Racer:addWithAutomaticKey(stat))
    
    if n == 1 then obj.displayDefaults = stat.displayDefaults end
  end
  
  obj.formulas = formulas
  
  return obj
end



-- Number of machines competing in the race when it began
GV.numOfRacers =
  MV("# Racers", 0x1BAEE0, RefValue, ByteValue)
-- Number of human racers
GV.numOfHumanRacers = MV("# Human racers", 0x245309, RefValue, ByteValue)

-- Accel/max speed setting; 0 (full accel) to 100 (full max speed).
-- TODO: This is only for P1, find the formula for the others.
GV.settingsSlider = MV("Settings slider", 0x2453A0, RefValue, IntValue)
function GV.settingsSlider:displayValue(options)
  return IntValue.displayValue(self, options).."%"
end


-- Custom part IDs
RV.customBodyId =
  MV("Custom body ID", 0x0, CustomPartId, ByteValue)
RV.customCockpitId =
  MV("Custom cockpit ID", 0x8, CustomPartId, ByteValue)
RV.customBoosterId =
  MV("Custom booster ID", 0x10, CustomPartId, ByteValue)

function Racer:customPartIds(number)
  local ids = {self.customBodyId, self.customCockpitId, self.customBoosterId}
  -- 1 for body, 2 for cockpit, 3 for booster
  return ids[number]
end

  
RV.machineId = MV("Machine ID", 0x6, StateValue, ShortValue)
RV.machineName =
  MV("Machine name", 0x3C, StateValue, StringValue, {maxLength=64})

RV.accel = defineStatWithBase(
  "Accel", 0x220, 0x8, StatTiedToBase, FloatStat, {3})
RV.body = defineStatWithBase(
  "Body", 0x30, 0x44, StatTiedToBase, FloatStat, {1,2})
RV.boostDuration = defineStatWithBase(
  "Boost duration", 0x234, 0x38, StatTiedToBase, FloatStat, {3})
RV.boostStrength = defineStatWithBase(
  "Boost strength", 0x230, 0x34, StatTiedToBase, FloatStat, {3})
RV.cameraReorienting = defineStatWithBase(
  "Cam. reorienting", 0x34, 0x4C, StatTiedToBase, FloatStat, {2})
RV.cameraRepositioning = defineStatWithBase(
  "Cam. repositioning", 0x38, 0x50, StatTiedToBase, FloatStat, {2})
RV.drag = defineStatWithBase(
  "Drag", 0x23C, 0x40, StatTiedToBase, FloatStat, {3})
RV.driftAccel = defineStatWithBase(
  "Drift accel", 0x2C, 0x1C, StatTiedToBase, FloatStat, {3}) 
RV.grip1 = defineStatWithBase(
  "Grip 1", 0xC, 0x10, StatTiedToBase, FloatStat, {1})
RV.grip2 = defineStatWithBase(
  "Grip 2", 0x24, 0x30, StatTiedToBase, FloatStat, {2})
RV.grip3 = defineStatWithBase(
  "Grip 3", 0x28, 0x14, StatTiedToBase, FloatStat, {1})
RV.maxSpeed = defineStatWithBase(
  "Max speed", 0x22C, 0xC, StatTiedToBase, FloatStat, {3})
RV.strafe = defineStatWithBase(
  "Strafe", 0x1C, 0x28, StatTiedToBase, FloatStat, {1})
RV.strafeTurn = defineStatWithBase(
  "Strafe turn", 0x18, 0x24, StatTiedToBase, FloatStat, {2})
RV.trackCollision = defineStatWithBase(
  "Track collision", 0x588, 0x9C, StatWithBase, FloatStat, {1})
RV.turnDecel = defineStatWithBase(
  "Turn decel", 0x238, 0x3C, StatTiedToBase, FloatStat, {3})
RV.turning1 = defineStatWithBase(
  "Turn tension", 0x10, 0x18, StatTiedToBase, FloatStat, {1})
RV.turning2 = defineStatWithBase(
  "Turn movement", 0x14, 0x20, StatTiedToBase, FloatStat, {2})
RV.turning3 = defineStatWithBase(
  "Turn reaction", 0x20, 0x2C, StatTiedToBase, FloatStat, {1})
RV.weight = defineStatWithBase(
  "Weight", 0x8, 0x4, StatTiedToBase, FloatStat, {1,2,3})
  
RV.obstacleCollision = MV(
  "Obstacle collision", 0x584, StateValue, FloatStat)
RV.unknown48 = defineStatWithBase(
  "Unknown 48", 0x477, 0x48, StatTiedToBase, ByteValue, {2})
-- Actual is state bit 1; base is 0x49 / 2
RV.unknown49a = defineStatWithBase(
  "Unknown 49a", 0x0, 0x49, StatTiedToBase, BinaryValue, {2},
   {binarySize=1, binaryStartBit=7}, {binarySize=1, binaryStartBit=1})
-- Actual is state bit 24; base is 0x49 % 2
RV.unknown49b = defineStatWithBase(
  "Drift camera", 0x2, 0x49, StatTiedToBase, BinaryValue, {2},
  {binarySize=1, binaryStartBit=0}, {binarySize=1, binaryStartBit=0})
  
RV.frontWidth = defineSizeStat(
  "Size, front width",
  -- Specific labels
  {
    "Tilt, front width, right",
    "Tilt, front width, left",
    "Wall collision, front width, right",
    "Wall collision, front width, left",
  },
  -- Offsets
  {0x24C, 0x2A8, 0x3B4, 0x3E4},
  -- Base-block offsets
  {0x54, 0x60, 0x84, 0x90},
  -- Formulas
  {
    function(v) return v end,
    function(v) return -v end,
    function(v) return v+0.2 end,
    function(v) return -(v+0.2) end,
  }
)
RV.frontHeight = defineSizeStat(
  "Size, front height",
  {
    "Tilt, front height, right",
    "Tilt, front height, left",
    "Wall collision, front height, right",
    "Wall collision, front height, left",
  },
  {0x250, 0x2AC, 0x3B8, 0x3E8},
  {0x58, 0x64, 0x88, 0x94},
  {
    function(v) return v end,
    function(v) return v end,
    function(v) return v-0.1 end,
    function(v) return v-0.1 end,
  }
)
RV.frontLength = defineSizeStat(
  "Size, front length",
  {
    "Tilt, front length, right",
    "Tilt, front length, left",
    "Wall collision, front length, right",
    "Wall collision, front length, left",
  },
  {0x254, 0x2B0, 0x3BC, 0x3EC},
  {0x5C, 0x68, 0x8C, 0x98},
  {
    function(v) return v end,
    function(v) return v end,
    function(v) return v-0.2 end,
    function(v) return v-0.2 end,
  }
)
RV.backWidth = defineSizeStat(
  "Size, back width",
  {
    "Tilt, back width, right",
    "Tilt, back width, left",
    "Wall collision, back width, right",
    "Wall collision, back width, left",
  },
  {0x304, 0x360, 0x414, 0x444},
  {0x6C, 0x78, 0x9C, 0xA8},
  {
    function(v) return v end,
    function(v) return -v end,
    -- For these formulas, Black Bull is +0.3, everyone else is +0.2
    function(v, machineId)
      if machineId == 29 then return v+0.3 else return v+0.2 end
    end,
    function(v, machineId)
      if machineId == 29 then return -(v+0.3) else return -(v+0.2) end
    end,
  }
)
RV.backHeight = defineSizeStat(
  "Size, back height",
  {
    "Tilt, back height, right",
    "Tilt, back height, left",
    "Wall collision, back height, right",
    "Wall collision, back height, left",
  },
  {0x308, 0x364, 0x418, 0x448},
  {0x70, 0x7C, 0xA0, 0xAC},
  {
    function(v) return v end,
    function(v) return v end,
    function(v) return v-0.1 end,
    function(v) return v-0.1 end,
  }
)
RV.backLength = defineSizeStat(
  "Size, back length",
  {
    "Tilt, back length, right",
    "Tilt, back length, left",
    "Wall collision, back length, right",
    "Wall collision, back length, left",
  },
  {0x30C, 0x368, 0x41C, 0x44C},
  {0x74, 0x80, 0xA4, 0xB0},
  {
    function(v) return v end,
    function(v) return v end,
    function(v) return v+0.2 end,
    function(v) return v+0.2 end,
  }
)

GX.statNames = {
  'accel', 'body', 'boostDuration', 'boostStrength', 'cameraReorienting',
  'cameraRepositioning', 'drag', 'driftAccel', 'grip1', 'grip2', 'grip3',
  'maxSpeed', 'strafe', 'strafeTurn', 'trackCollision', 'turnDecel',
  'turning1', 'turning2', 'turning3', 'weight',
  'obstacleCollision', 'unknown48', 'unknown49a', 'unknown49b',
  'frontWidth', 'frontHeight', 'frontLength',
  'backWidth', 'backHeight', 'backLength',
}

  
-- General-interest state values

RV.generalState1a = MV(
  "State bits 01-08", 0x0, StateValue, BinaryValue,
  {binarySize=8, binaryStartBit=7}
)
RV.generalState1b = MV(
  "State bits 09-16", 0x1, StateValue, BinaryValue,
  {binarySize=8, binaryStartBit=7}
)
RV.generalState1c = MV(
  "State bits 17-24", 0x2, StateValue, BinaryValue,
  {binarySize=8, binaryStartBit=7}
)
RV.generalState1d = MV(
  "State bits 25-32", 0x3, StateValue, BinaryValue,
  {binarySize=8, binaryStartBit=7}
)
function Racer:sideAttackOn()
  return (self.generalState1b:get()[7] == 1)
end
function Racer:finishedRace()
  return (self.generalState1b:get()[8] == 1)
end
function Racer:spinAttackOn()
  return (self.generalState1d:get()[5] == 1)
end


-- Coordinates

RV.pos = V(
  subclass(Vector3Value, RacerValue),
  Racer:addWithAutomaticKey(defineStateFloat("Pos X", 0x7C)),
  Racer:addWithAutomaticKey(defineStateFloat("Pos Y", 0x80)),
  Racer:addWithAutomaticKey(defineStateFloat("Pos Z", 0x84))
)
RV.pos.label = "Position"
RV.pos.displayDefaults = {signed=true, beforeDecimal=3, afterDecimal=3}

RV.vel = V(
  subclass(Vector3Value, RacerValue),
  Racer:addWithAutomaticKey(defineStateFloat("Vel X", 0x94)),
  Racer:addWithAutomaticKey(defineStateFloat("Vel Y", 0x98)),
  Racer:addWithAutomaticKey(defineStateFloat("Vel Z", 0x9C))
)
RV.vel.label = "Velocity"
RV.vel.displayDefaults = {signed=true, beforeDecimal=3, afterDecimal=3}

-- Machine orientation in world coordinates
RV.wOrient = V(
  subclass(Vector3Value, RacerValue),
  Racer:addWithAutomaticKey(defineStateFloat("W Orient X", 0xEC)),
  Racer:addWithAutomaticKey(defineStateFloat("W Orient Y", 0xF0)),
  Racer:addWithAutomaticKey(defineStateFloat("W Orient Z", 0xF4))
)
RV.wOrient.label = "Orient"
RV.wOrient.displayDefaults = {signed=true, beforeDecimal=1, afterDecimal=3}

-- Machine orientation in current gravity coordinates
RV.gOrient = V(
  subclass(Vector3Value, RacerValue),
  Racer:addWithAutomaticKey(defineStateFloat("G Orient X", 0x10C)),
  Racer:addWithAutomaticKey(defineStateFloat("G Orient Y", 0x110)),
  Racer:addWithAutomaticKey(defineStateFloat("G Orient Z", 0x114))
)
RV.gOrient.label = "Orient (grav)"
RV.gOrient.displayDefaults = {signed=true, beforeDecimal=1, afterDecimal=3}


RV.kmh = defineStateFloat("km/h (next)", 0x17C)
RV.energy = defineStateFloat("Energy", 0x184)
RV.boostFramesLeft = MV("Boost frames left", 0x18A, StateValue, ByteValue)
RV.score = MV("Score", 0x210, StateValue, ShortValue)
RV.terrainState218 = MV(
  "Terrain state", 0x218, StateValue, BinaryValue,
  {binarySize=8, binaryStartBit=7}
)
RV.gripAndAirState = MV(
  "Grip and air state", 0x247, StateValue, BinaryValue,
  {binarySize=8, binaryStartBit=7}
)
RV.damageLastHit = defineStateFloat("Damage, last hit", 0x4AC)
RV.boostDelay = MV("Boost delay", 0x4C6, StateValue, ShortValue)
RV.boostEnergyUsageFactor =
  defineStateFloat("Boost energy usage factor", 0x4DC)
RV.terrainState4FD = MV(
  "Terrain state 4FD", 0x4FD, StateValue, BinaryValue,
  {binarySize=8, binaryStartBit=7}
)
RV.generalState58F = MV(
  "State 58F", 0x58F, StateValue, BinaryValue,
  {binarySize=8, binaryStartBit=7}
)


RV.trackWidth = MV("Track width", 0x5E4, State2Value, FloatValue)

RV.checkpointMain = MV("Main checkpoint", 0x618, State2Value, SignedIntValue)
RV.checkpointFraction = MV("CP fraction", 0x628, State2Value, FloatValue)
RV.checkpointLateralOffset = MV("CP lateral", 0x668, State2Value, FloatValue)
RV.checkpointRightVector = V(
  subclass(Vector3Value, RacerValue),
  Racer:addWithAutomaticKey(MV("CP Right X", 0x560, State2Value, FloatValue)),
  Racer:addWithAutomaticKey(MV("CP Right Y", 0x570, State2Value, FloatValue)),
  Racer:addWithAutomaticKey(MV("CP Right Z", 0x580, State2Value, FloatValue))
)
RV.checkpointRightVector.label = "CP Right"
RV.checkpointRightVector.displayDefaults = {
  signed=true, beforeDecimal=1, afterDecimal=5}
RV.sectionCheckpoint = MV("Section CP", 0x61C, State2Value, SignedIntValue)
RV.checkpointPositional = MV("Positional CP", 0x5FC, State2Value, SignedIntValue)
RV.checkpointLastContact = MV("Last contact CP", 0x1CC, StateValue, IntValue)
RV.checkpointGround = MV("Ground CP", 0x680, State2Value, SignedIntValue)
RV.checkpointNumber74 = MV("Checkpoint 74", 0x74, State2Value, SignedIntValue)
RV.checkpointNumberD0 = MV("Checkpoint D0", 0xD0, State2Value, SignedIntValue)
RV.checkpointNumber154 = MV("Checkpoint 154", 0x154, State2Value, SignedIntValue)
RV.checkpointNumber1B0 = MV("Checkpoint 1B0", 0x1B0, State2Value, SignedIntValue)
RV.checkpointNumber234 = MV("Checkpoint 234", 0x234, State2Value, SignedIntValue)
RV.checkpointNumber290 = MV("Checkpoint 290", 0x290, State2Value, SignedIntValue)
RV.checkpointNumber314 = MV("Checkpoint 314", 0x314, State2Value, SignedIntValue)
RV.checkpointNumber370 = MV("Checkpoint 370", 0x370, State2Value, SignedIntValue)

RV.lapNumber = MV("Lap num", 0x67B, State2Value, ByteValue)
RV.lapNumberPosition = MV("Lap num, position", 0x67F, State2Value, SignedByteValue)
RV.lapNumberGround = MV("Lap num, ground", 0x6B7, State2Value, ByteValue)
RV.lapNumberPositionGround = MV("Lap num, pos/gr", 0x6BB, State2Value, SignedByteValue)


-- Physics related
RV.gripA4 = defineStateFloat("Grip A4", 0xA4)
RV.collisionC4 = defineStateFloat("Collision C4", 0xC4)
RV.accelC8 = defineStateFloat("Accel C8", 0xC8)
RV.stabilityCC = defineStateFloat("Stability CC", 0xCC)
RV.aerialTilt = defineStateFloat("Aerial Tilt", 0x180)
RV.boost18C = defineStateFloat("Boost 18C", 0x18C)
RV.stability198 = defineStateFloat("Stability 198", 0x198)
RV.stability19C = defineStateFloat("Stability 19C", 0x19C)
RV.stability1A0 = defineStateFloat("Stability 1A0", 0x1A0)
RV.stability1A4 = defineStateFloat("Stability 1A4", 0x1A4)
RV.stability1A8 = defineStateFloat("Stability 1A8", 0x1A8)
RV.stability1AC = defineStateFloat("Stability 1AC", 0x1AC)
RV.stability1B0 = defineStateFloat("Stability 1B0", 0x1B0)
RV.stability1B4 = defineStateFloat("Stability 1B4", 0x1B4)
RV.stability1B8 = defineStateFloat("Stability 1B8", 0x1B8)
RV.groundContact = defineStateFloat("Ground contact", 0x1C8)
RV.collision216 = MV("Collision 216", 0x216, StateValue, IntValue)
RV.speed224 = defineStateFloat("Speed 224", 0x224)
RV.boost228 = defineStateFloat("Boost 228", 0x228)
RV.slopeRateOfChange288 = defineStateFloat("Slope rate of change 288", 0x288)
RV.tilt28C = defineStateFloat("Tilt 28C", 0x28C)
RV.orientation290 = defineStateFloat("Orientation 290", 0x290)
RV.collision3D8 = defineStateFloat("Collision 3D8", 0x3D8)
RV.speed478 = defineStateFloat("Speed 478", 0x478)
RV.strafeEffect = MV("Strafe effect", 0x4B0, StateValue, SignedShortValue)
RV.stability4B4 = defineStateFloat("Stability 4B4", 0x4B4)
RV.turnReactionInput = defineStateFloat("T. reaction input", 0x4D4)
RV.turnReactionEffect = defineStateFloat("T. reaction effect", 0x4D8)
RV.collision500X = defineStateFloat("Collision 500, X", 0x500)
RV.collision500Y = defineStateFloat("Collision 500, Y", 0x504)
RV.collision500Z = defineStateFloat("Collision 500, Z", 0x508)
RV.turning580 = defineStateFloat("Turning 580", 0x580)
RV.collision5C4 = defineStateFloat("Collision 5C4", 0x5C4)
RV.turning5C8 = defineStateFloat("Turning 5C8", 0x5C8)
RV.turning5CC = defineStateFloat("Turning 5CC", 0x5CC)
RV.unknown5D0 = defineStateFloat("Unknown 5D0", 0x5D0)
RV.unknown5D4 = defineStateFloat("Unknown 5D4", 0x5D4)


local Timer = subclass(Value, RacerValue)
GX.Timer = Timer

function Timer.define(label, offset)
  local obj = V(Timer)

  obj.label = label
  
  local add = utils.curry(Racer.addWithAutomaticKey, Racer)
  obj.keys = {}
  obj.keys.frames = add(MV(label..", frames", offset,
    State2Value, IntValue))
  obj.keys.frameFraction = add(MV(label..", frame fraction", offset+4,
    State2Value, FloatValue))
  obj.keys.mins = add(MV(label..", minutes", offset+8,
    State2Value, ByteValue))
  obj.keys.secs = add(MV(label..", seconds", offset+9,
    State2Value, ByteValue))
  obj.keys.millis = add(MV(label..", milliseconds", offset+10,
    State2Value, ShortValue))
    
  return obj
end

function Timer:init()
  for name, key in pairs(self.keys) do
    self[name] = self.racer[key]
  end
end

function Timer:updateValue()
  for name, key in pairs(self.keys) do
    self[name]:update()
  end
end

function Timer:displayValue(options)
  options = options or {}
  
  local s = string.format(
    "%d'%02d\"%03d", self.mins:get(), self.secs:get(), self.millis:get()
  )
  if options.withFrameFraction then
    s = s.." + "..string.format("%.4f", self.frameFraction:get())
  end
  return s
end


local raceTimer = V(subclass(Value, RacerValue))
RV.raceTimer = raceTimer

raceTimer.keys = {}
raceTimer.keys.total = racerAdd(Timer.define("Total", 0x744))
raceTimer.keys.currLap = racerAdd(Timer.define("This lap", 0x6C0))
raceTimer.keys.prevLap = racerAdd(Timer.define("Prev. lap", 0x6CC))
raceTimer.keys.back2Laps = racerAdd(Timer.define("2 laps ago", 0x6D8))
raceTimer.keys.back3Laps = racerAdd(Timer.define("3 laps ago", 0x6E4))
raceTimer.keys.back4Laps = racerAdd(Timer.define("4 laps ago", 0x6F0))
raceTimer.keys.back5Laps = racerAdd(Timer.define("5 laps ago", 0x6FC))
raceTimer.keys.back6Laps = racerAdd(Timer.define("6 laps ago", 0x708))
raceTimer.keys.back7Laps = racerAdd(Timer.define("7 laps ago", 0x714))
raceTimer.keys.back8Laps = racerAdd(Timer.define("8 laps ago", 0x720))
raceTimer.keys.bestLap = racerAdd(Timer.define("Best lap", 0x72C))
raceTimer.keys.sumOfFinishedLaps =
  racerAdd(Timer.define("Sum of finished laps", 0x738))

function raceTimer:init()
  for name, key in pairs(self.keys) do
    self[name] = self.racer[key]
  end
  
  self.prevLaps = {
    self.prevLap, self.back2Laps, self.back3Laps,
    self.back4Laps, self.back5Laps, self.back6Laps,
    self.back7Laps, self.back8Laps,
  }
end

function raceTimer:display(options)
  options = options or {}
  options.maxPrevLaps = options.maxPrevLaps or 4
  -- The game only saves 8 previous laps
  if options.maxPrevLaps > 8 then options.maxPrevLaps = 8 end
  
  s = self.total:display(options).."\n"..self.currLap:display(options)
  
  if not self.racer.lapNumber:isValid() then return s end
  
  -- Show up to maxPrevLaps previous individual lap times
  local completedLaps = self.racer.lapNumber:get()
  local firstLapToShow = math.max(1, completedLaps - options.maxPrevLaps + 1)
  for lapN = firstLapToShow, completedLaps do
    local prevLapN = completedLaps - lapN + 1
    
    local lapOptions = {}
    utils.updateTable(lapOptions, options)
    lapOptions.label = string.format("Lap %d", lapN)
    
    s = s.."\n"..self.prevLaps[prevLapN]:display(lapOptions)
  end
  
  if self.racer:finishedRace() then
    s = s.."\n"..self.sumOfFinishedLaps:display(options)
  end
  
  return s
end


function GX:displayAnalog(v, valueType, posSymbol, negSymbol, options)
  -- Display a signed analog value, e.g. something that ranges
  -- anywhere from -100 to +100.
  -- Can provide custom positive/negative symbols such as > and <.
  local s = nil
  if valueType == 'int' then s = utils.intToStr(math.abs(v), options)
  elseif valueType == 'float' then s = utils.floatToStr(math.abs(v), options)
  else error("Unsupported valueType: "..tostring(valueType))
  end
  
  if v == 0 then s = "  "..s
  elseif v > 0 then s = posSymbol.." "..s
  else s = negSymbol.." "..s end
  return s
end


-- Controller inputs (uncalibrated)
local controllerInput = V(subclass(Value, PlayerValue))
PV.controllerInput = controllerInput

controllerInput.keys = {
  ABXYS = Player:add(MV("ABXY & Start", 0x15CBD0, StaticValue, BinaryValue,
    {binarySize=8, binaryStartBit=7}), 8),
  DZ = Player:add(MV("D-Pad & Z", 0x15CBD1, StaticValue, BinaryValue,
    {binarySize=8, binaryStartBit=7}), 8),
  stickX = Player:add(MV("Stick X", 0x15CBD2, StaticValue, ByteValue), 8),
  stickY = Player:add(MV("Stick Y", 0x15CBD3, StaticValue, ByteValue), 8),
  CStickX = Player:add(MV("C-Stick X", 0x15CBD4, StaticValue, ByteValue), 8),
  CStickY = Player:add(MV("C-Stick Y", 0x15CBD5, StaticValue, ByteValue), 8),
  L = Player:add(MV("L", 0x15CBD6, StaticValue, ByteValue), 8),
  R = Player:add(MV("R", 0x15CBD7, StaticValue, ByteValue), 8),
}

function controllerInput:init()
  for name, key in pairs(self.keys) do
    self[name] = self.player[key]
  end
end

function controllerInput:buttonDisplay(buttonName)
  local value = nil
  if buttonName == "A" then value = self.ABXYS:get()[8]
  elseif buttonName == "B" then value = self.ABXYS:get()[7]
  elseif buttonName == "X" then value = self.ABXYS:get()[6]
  elseif buttonName == "Y" then value = self.ABXYS:get()[5]
  elseif buttonName == "S" then value = self.ABXYS:get()[4]
  elseif buttonName == "Z" then value = self.DZ:get()[4]
  end
  
  if value == 1 then
    return buttonName
  else
    return " "
  end
end

function controllerInput:stickXDisplay()
  return self.game:displayAnalog(
    self.stickX:get()-128, 'int', ">", "<", {digits=3})
end
function controllerInput:stickYDisplay()
  return self.game:displayAnalog(
    self.stickY:get()-128, 'int', "^", "v", {digits=3})
end
function controllerInput:LDisplay()
  return utils.intToStr(self.L:get(), {digits=3})
end
function controllerInput:RDisplay()
  return utils.intToStr(self.R:get(), {digits=3})
end

function controllerInput:display(options)
  if not self:isValid() then return self.invalidDisplay end
  
  options = options or {}
  
  local stickX = self:stickXDisplay()
  local stickY = self:stickYDisplay()
  local L = self:LDisplay()
  local R = self:RDisplay()
  local buttons = string.format("%s%s%s%s%s%s",
    self:buttonDisplay("A"), self:buttonDisplay("B"), self:buttonDisplay("X"),
    self:buttonDisplay("Y"), self:buttonDisplay("S"), self:buttonDisplay("Z")
  )
  
  if options.narrow then
    -- Use less horizontal space
    return string.format(
      "L %s R %s\n"
      .."%s %s\n"
      .."%s",
      L, R, stickX, stickY, buttons
    )
  else
    return string.format(
      "        L %s   R %s\n"
      .."Stick:  %s   %s\n"
      .."  %s",
      L, R, stickX, stickY, buttons
    )
  end
end


-- Post-calibration values.
-- This refers to not only stick calibration (which is user defined), but also
-- calibration that the game does to go from raw C-stick/L/R values to more
-- useful values.
local calibratedInput = V(subclass(controllerInput))
PV.calibratedInput = calibratedInput

calibratedInput.keys = {
  ABXYS = controllerInput.keys.ABXYS,
  DZ = controllerInput.keys.DZ,
  stickX = Player:add(
    MV("Stick X, calibrated", 0x1BAB54, RefValue, FloatValue), 0x20),
  stickY = Player:add(
    MV("Stick Y, calibrated", 0x1BAB58, RefValue, FloatValue), 0x20),
  CStickX = Player:add(
    MV("C-Stick X, calibrated", 0x1BAB5C, RefValue, FloatValue), 0x20),
  CStickY = Player:add(
    MV("C-Stick Y, calibrated", 0x1BAB60, RefValue, FloatValue), 0x20),
  L = Player:add(
    MV("L, calibrated", 0x1BAB64, RefValue, FloatValue), 0x20),
  R = Player:add(
    MV("R, calibrated", 0x1BAB68, RefValue, FloatValue), 0x20),
}

function calibratedInput:stickXDisplay()
  return self.game:displayAnalog(
    self.stickX:get()*100.0, 'float', ">", "<", {beforeDecimal=3, afterDecimal=1})
end
function calibratedInput:stickYDisplay()
  return self.game:displayAnalog(
    self.stickY:get()*100.0, 'float', "^", "v", {beforeDecimal=3, afterDecimal=1})
end
function calibratedInput:LDisplay()
  return utils.floatToStr(self.L:get()*100.0, {beforeDecimal=3, afterDecimal=1})
end
function calibratedInput:RDisplay()
  return utils.floatToStr(self.R:get()*100.0, {beforeDecimal=3, afterDecimal=1})
end


-- Racer control state.
-- Unlike controller input, this:
-- - corresponds directly to controls (accel, brake, etc.) rather than buttons
-- - is only active during races
-- - lets you view controls for CPUs and Replays
-- And because it fits in better here, a display of the boost status (time
-- remaining, delay frames) is also included.
--
-- Limitation: We only know the net strafe amount (R minus L), not the
-- input amounts for each shoulder. Since no L or R results in different
-- properties from full L+R, we know this means we're missing some info.
  
local controlState = V(subclass(Value, RacerValue))
RV.controlState = controlState

controlState.keys = {
  steerY = racerAdd(defineStateFloat("Control, steering Y", 0x1F4)),
  strafe = racerAdd(defineStateFloat("Control, strafe", 0x1F8)),
  steerX = racerAdd(defineStateFloat("Control, steering X", 0x1FC)),
  accel = racerAdd(defineStateFloat("Control, accel", 0x200)),
  brake = racerAdd(defineStateFloat("Control, brake", 0x204)),
}

function controlState:init()
  for name, key in pairs(self.keys) do
    self[name] = self.racer[key]
  end
end

function controlState:buttonDisplay(buttonName)
  if buttonName == "Accel" then
    -- Can only be at two float values: 1.0 or 0.0.
    if self.accel:get() > 0.5 then return "Accel" else return "     " end
  elseif buttonName == "Brake" then
    if self.brake:get() > 0.5 then return "Brake" else return "     " end
  elseif buttonName == "Side" then
    -- Can only be at 1 or 0.
    if self.racer:sideAttackOn() then return "Side"
      else return "    " end
  elseif buttonName == "Spin" then
    if self.racer:spinAttackOn() then return "Spin"
      else return "    " end
  end
end

function controlState:boostDisplay()
  local framesLeft = self.racer.boostFramesLeft:get()
  local delay = self.racer.boostDelay:get()
  
  if framesLeft > 0 then
    -- Show boost frames left
    return utils.intToStr(framesLeft, {digits=3})
  elseif delay > 0 then
    -- Show boost delay frames with a + in front of the number
    return utils.intToStr(delay, {signed=true, digits=2})
  else
    return "   "
  end
end

function controlState:display(options)
  if not self:isValid() then return self.invalidDisplay end
  
  options = options or {}
  
  local steerX = self.game:displayAnalog(
    self.steerX:get()*100.0, 'float', ">", "<", {beforeDecimal=3, afterDecimal=1})
  local steerY = self.game:displayAnalog(
    self.steerY:get()*100.0, 'float', "^", "v", {beforeDecimal=3, afterDecimal=1})
  local strafe = self.game:displayAnalog(
    self.strafe:get()*100.0, 'float', ">", "<", {beforeDecimal=3, afterDecimal=1})
  
  if options.narrow then
    -- Use less horizontal space
    return string.format(
      "Strafe:\n%s\n"
      .."Steer:\n%s %s\n"
      .."  %s %s\n"
      .."  %s %s\n"
      .."Boost:\n%s",
      strafe, steerX, steerY,
      self:buttonDisplay("Accel"), self:buttonDisplay("Side"),
      self:buttonDisplay("Brake"), self:buttonDisplay("Spin"),
      self:boostDisplay()
    )
  else
    return string.format(
      "Strafe: %s\n"
      .."Steer:  %s   %s\n"
      .."  %s  %s  %s  %s\n"
      .."Boost:  %s",
      strafe, steerX, steerY,
      self:buttonDisplay("Accel"), self:buttonDisplay("Side"),
      self:buttonDisplay("Brake"), self:buttonDisplay("Spin"),
      self:boostDisplay()
    )
  end
end


return GX
