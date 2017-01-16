-- F-Zero GX



-- Imports.

-- First make sure that the imported modules get de-cached as needed. That way,
-- if we change the code in those modules and then re-run the script, we won't
-- need to restart Cheat Engine to see the code changes take effect.

package.loaded.utils = nil
local utils = require 'utils'
local readIntBE = utils.readIntBE
local subclass = utils.subclass

package.loaded.dolphin = nil
local dolphin = require 'dolphin'

package.loaded.valuetypes = nil
local valuetypes = require 'valuetypes'
local V = valuetypes.V
local MV = valuetypes.MV
local Block = valuetypes.Block
local Value = valuetypes.Value
local MemoryValue = valuetypes.MemoryValue
local FloatType = valuetypes.FloatTypeBE
local IntType = valuetypes.IntTypeBE
local ShortType = valuetypes.ShortTypeBE
local ByteType = valuetypes.ByteType
local SignedIntType = valuetypes.SignedIntTypeBE
local SignedShortType = valuetypes.SignedShortTypeBE
local SignedByteType = valuetypes.SignedByteType
local StringType = valuetypes.StringType
local BinaryType = valuetypes.BinaryType
local Vector3Value = valuetypes.Vector3Value

package.loaded.layouts = nil
local layoutsModule = require 'layouts'



local GX = subclass(dolphin.DolphinGame)

GX.supportedGameVersions = {
  na = 'GFZE01',
  us = 'GFZE01',
}

GX.layoutModuleNames = {'fzerogx_layouts'}
GX.framerate = 60
-- Use D-Pad Left to reset max-value displays, average-value displays, etc.
GX.defaultResetButton = '<'

function GX:init(options)
  dolphin.DolphinGame.init(self, options)

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
  -- This pointer doesn't change during the game, but in some Dolphin versions
  -- it may be different between different runs of the game.
  -- So it can change if you close the game and restart it,
  -- or load a state from a different run of the game.
  self.addrs.refPointer =
    self.addrs.o
    + readIntBE(self.addrs.o + 0x30C8, 4)
    - 0x80000000
end

function GX:updateMachineStatsAndStateAddresses()
  -- A duplicate of the base stats block. We'll use this as a backup of the
  -- original values, when playing with the values in the primary block.
  self.addrs.machineBaseStatsBlocks2 = self.addrs.refPointer + 0x195660

  -- Same but for custom machines.
  self.addrs.machineBaseStatsBlocks2Custom = self.addrs.refPointer + 0x1B3B30

  -- Racer state.
  local pointer2Address = self.addrs.refPointer + 0x227878
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



local BaseStat1Value = subclass(MemoryValue)
GX.BaseStat1Value = BaseStat1Value

function BaseStat1Value:init(label, offset, extraArgs)
  self.machineOrPartId = extraArgs.machineOrPartId
  self.isCustom = extraArgs.isCustom
  MemoryValue.init(self, label, offset)
end

function BaseStat1Value:getAddress()
  if self.isCustom then
    return (self.game.addrs.machineBaseStatsBlocksCustom
      + (0xB4 * self.machineOrPartId)
      + self.offset)
  else
    return (self.game.addrs.machineBaseStatsBlocks
      + (0xB4 * self.machineOrPartId)
      + self.offset)
  end
end



local BaseStat2Value = subclass(BaseStat1Value)
GX.BaseStat2Value = BaseStat2Value

function BaseStat2Value:getAddress()
  if self.isCustom then
    -- There's some extra bytes before the cockpit part stats,
    -- and more extra bytes before the booster part stats.
    -- extraBytes accounts for this.
    local extraBytes = 0
    if self.machineOrPartId > 49 then extraBytes = 24 + 16
    elseif self.machineOrPartId > 24 then extraBytes = 24
    end
    return (self.game.addrs.machineBaseStatsBlocks2Custom
      + (0xB4 * self.machineOrPartId)
      + extraBytes
      + self.offset)
  else
    return (self.game.addrs.machineBaseStatsBlocks2
      + (0xB4 * self.machineOrPartId)
      + self.offset)
  end
end



local RacerValue = {}

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



local PlayerValue = {}

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



local CustomPartId = subclass(MemoryValue, RacerValue)
GX.CustomPartId = CustomPartId

function CustomPartId:getAddress()
  -- Player 2's custom part IDs are 0x81C0 later than P1's, and then P3's IDs
  -- are 0x81C0 later than that, and so on.
  return self.game.addrs.refPointer
    + 0x1C7664
    + (0x81C0 * self.racer.racerIndex)
    + self.offset
end



local ReplayInputValue = subclass(MemoryValue)
GX.ReplayInputValue = ReplayInputValue

function ReplayInputValue:getPointer()
  local rawPointer = readIntBE(self.game.addrs.refPointer + 0x239058, 4)
  if rawPointer == 0 then return nil end

  return self.game.addrs.o + rawPointer - 0x80000000
end

function ReplayInputValue:getAddress()
  local pointer = self:getPointer()
  local currentIndex = readIntBE(pointer + 0xA0, 2)
  local inputArrayStart = pointer + 0xA4
  local elementSize = 7
  local elementAddress = inputArrayStart + currentIndex*elementSize
  return elementAddress + self.offset
end

function ReplayInputValue:isValid()
  local valid = self:getPointer() ~= nil
  if not valid then self.invalidDisplay = "<Replay inputs N/A>" end
  return valid
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



local StatWithBase = subclass(Value, RacerValue)
GX.StatWithBase = StatWithBase

function StatWithBase:init(
  label, offset, baseOffset, typeMixinClass,
  customPartsWithBase, extraArgs, baseExtraArgs)

  self.label = label

  -- MemoryValue containing current stat value
  self.current = self.block:MV(
    label, offset, StateValue, typeMixinClass, extraArgs)
  self.displayDefaults = self.current.displayDefaults

  -- Stuff to help create base-value objects dynamically
  self.baseOffset = baseOffset
  self.typeMixinClass = typeMixinClass
  self.customPartsWithBase = customPartsWithBase
  self.baseExtraArgs = baseExtraArgs or {}
end

function StatWithBase:updateStatBasesIfMachineChanged()
  -- Note: it's possible that more than one custom part has a nonzero
  -- base value here. (Check with #self.customPartsWithBase > 1)
  -- Weight and Body are the only stats where this is true.
  --
  -- But handling this properly seems to take a fair bit of extra work,
  -- so no matter what, we'll just get one nonzero base value.
  -- Specifically we'll get the first one, by indexing with [1].
  --
  -- That's still enough to fully manipulate the stats; it'll just be a bit
  -- unintuitive. e.g. to change Gallant Star-G4's weight, you have to
  -- manipulate the weight of the body part, Dread Hammer (the interface
  -- won't let you manipulate the other two parts):
  -- GSG4 2660 to 1660 weight: change Dread Hammer's weight from 1440 to 440
  -- GSG4 2660 to 660 weight: change Dread Hammer's weight from 1440 to -560
  local machineOrPartId = self.racer.machineId:get()

  -- If custom machine, id is 50 for P1, 51 for P2...
  local isCustom = (machineOrPartId >= 50)
  if isCustom then
    local customPartTypeWithBase = self.customPartsWithBase[1]
    machineOrPartId = self.racer:customPartIds(customPartTypeWithBase):get()
  end

  if self.baseExtraArgs.machineOrPartId == machineOrPartId
    and self.baseExtraArgs.isCustom == isCustom then
    -- Machine or part hasn't changed.
    return
  end

  self.baseExtraArgs.machineOrPartId = machineOrPartId
  self.baseExtraArgs.isCustom = isCustom

  self.base = self.block:MV(
    self.label.." (B)", self.baseOffset,
    BaseStat1Value, self.typeMixinClass, self.baseExtraArgs)
  self.base2 = self.block:MV(
    self.label.." (B)", self.baseOffset,
    BaseStat2Value, self.typeMixinClass, self.baseExtraArgs)
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
  -- Limitation: If the game or emulation is paused when you change a
  -- base value, then the current value will not reflect the change until the
  -- next frame of being unpaused.
  -- So the "this is changed" display can be misleading if you forget that.
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



local FloatStat = subclass(FloatType)
GX.FloatStat = FloatStat

-- For machine stats that are floats, we'll prefer trimming zeros in the
-- display so that the number looks cleaner. (Normally we keep trailing
-- zeros when the value can change rapidly, as it is jarring when the
-- display constantly gains/loses digits... but machine stats don't
-- change rapidly.)
FloatStat.displayDefaults = {trimTrailingZeros=true, afterDecimal=4}

-- Shortcut function, since we have a lot of state floats.
local function defineStateFloat(label, offset)
  return MV(label, offset, StateValue, FloatType)
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

function SizeStat:init(label, specificLabels, offsets, baseOffsets, formulas)
  self.label = label
  self.formulas = formulas

  self.stats = {}
  for n = 1, 4 do
    self.stats[n] = self.block:V(
      StatWithBase, specificLabels[n], offsets[n], baseOffsets[n], FloatStat,
      -- SizeStats on custom machines are always influenced by only the body,
      -- not the cockpit or booster.
      {1}
    )
  end

  -- Get display defaults from any stat. We'll pick the first.
  self.displayDefaults = self.stats[1].displayDefaults
end

function SizeStat:isValid()
  local isValid = self.stats[1]:isValid()
  self.invalidDisplay = self.stats[1].invalidDisplay
  return isValid
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



-- Number of machines competing in the race when it began
GV.numOfRacers =
  MV("# Racers", 0x1BAFBC, RefValue, ByteType)
-- Number of human racers
GV.numOfHumanRacers = MV("# Human racers", 0x2453E5, RefValue, ByteType)

-- Accel/max speed setting; 0 (full accel) to 100 (full max speed).
-- TODO: This is only for P1, find the formula for the others.
GV.settingsSlider = MV("Settings slider", 0x24547C, RefValue, IntType)
function GV.settingsSlider:displayValue(options)
  return IntType.displayValue(self, options).."%"
end


-- Custom part IDs
RV.customBodyId =
  MV("Custom body ID", 0x0, CustomPartId, ByteType)
RV.customCockpitId =
  MV("Custom cockpit ID", 0x8, CustomPartId, ByteType)
RV.customBoosterId =
  MV("Custom booster ID", 0x10, CustomPartId, ByteType)

function Racer:customPartIds(number)
  local ids = {self.customBodyId, self.customCockpitId, self.customBoosterId}
  -- 1 for body, 2 for cockpit, 3 for booster
  return ids[number]
end


RV.machineId = MV("Machine ID", 0x6, StateValue, ShortType)
RV.machineName =
  MV("Machine name", 0x3C, StateValue, StringType, {maxLength=64})

RV.accel = V(StatTiedToBase, "Accel", 0x220, 0x8, FloatStat, {3})
RV.body = V(StatTiedToBase, "Body", 0x30, 0x44, FloatStat, {1,2})
RV.boostDuration = V(StatTiedToBase, "Boost duration", 0x234, 0x38, FloatStat, {3})
RV.boostStrength = V(StatTiedToBase, "Boost strength", 0x230, 0x34, FloatStat, {3})
RV.cameraReorienting = V(StatTiedToBase, "Cam. reorienting", 0x34, 0x4C, FloatStat, {2})
RV.cameraRepositioning = V(StatTiedToBase, "Cam. repositioning", 0x38, 0x50, FloatStat, {2})
RV.drag = V(StatTiedToBase, "Drag", 0x23C, 0x40, FloatStat, {3})
RV.driftAccel = V(StatTiedToBase, "Drift accel", 0x2C, 0x1C, FloatStat, {3})
RV.grip1 = V(StatTiedToBase, "Grip 1", 0xC, 0x10, FloatStat, {1})
RV.grip2 = V(StatTiedToBase, "Grip 2", 0x24, 0x30, FloatStat, {2})
RV.grip3 = V(StatTiedToBase, "Grip 3", 0x28, 0x14, FloatStat, {1})
RV.maxSpeed = V(StatTiedToBase, "Max speed", 0x22C, 0xC, FloatStat, {3})
RV.strafe = V(StatTiedToBase, "Strafe", 0x1C, 0x28, FloatStat, {1})
RV.strafeTurn = V(StatTiedToBase, "Strafe turn", 0x18, 0x24, FloatStat, {2})
RV.trackCollision = V(StatWithBase, "Track collision", 0x588, 0x9C, FloatStat, {1})
RV.turnDecel = V(StatTiedToBase, "Turn decel", 0x238, 0x3C, FloatStat, {3})
RV.turning1 = V(StatTiedToBase, "Turn tension", 0x10, 0x18, FloatStat, {1})
RV.turning2 = V(StatTiedToBase, "Turn movement", 0x14, 0x20, FloatStat, {2})
RV.turning3 = V(StatTiedToBase, "Turn reaction", 0x20, 0x2C, FloatStat, {1})
RV.weight = V(StatTiedToBase, "Weight", 0x8, 0x4, FloatStat, {1,2,3})

RV.obstacleCollision = MV(
  "Obstacle collision", 0x584, StateValue, FloatStat)
RV.unknown48 = V(StatTiedToBase, "Unknown 48", 0x477, 0x48, ByteType, {2})
-- Actual is state bit 1; base is 0x49 / 2
RV.unknown49a = V(StatTiedToBase, "Unknown 49a", 0x0, 0x49, BinaryType, {2},
   {binarySize=1, binaryStartBit=7}, {binarySize=1, binaryStartBit=1})
-- Actual is state bit 24; base is 0x49 % 2
RV.driftCamera = V(StatTiedToBase, "Drift camera", 0x2, 0x49, BinaryType, {2},
  {binarySize=1, binaryStartBit=0}, {binarySize=1, binaryStartBit=0})

RV.frontWidth = V(SizeStat,
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
RV.frontHeight = V(SizeStat,
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
RV.frontLength = V(SizeStat,
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
RV.backWidth = V(SizeStat,
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
RV.backHeight = V(SizeStat,
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
RV.backLength = V(SizeStat,
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
  'obstacleCollision', 'unknown48', 'unknown49a', 'driftCamera',
  'frontWidth', 'frontHeight', 'frontLength',
  'backWidth', 'backHeight', 'backLength',
}


-- General-interest state values

RV.generalState1a = MV(
  "State bits 01-08", 0x0, StateValue, BinaryType,
  {binarySize=8, binaryStartBit=7}
)
RV.generalState1b = MV(
  "State bits 09-16", 0x1, StateValue, BinaryType,
  {binarySize=8, binaryStartBit=7}
)
RV.generalState1c = MV(
  "State bits 17-24", 0x2, StateValue, BinaryType,
  {binarySize=8, binaryStartBit=7}
)
RV.generalState1d = MV(
  "State bits 25-32", 0x3, StateValue, BinaryType,
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
  defineStateFloat("Pos X", 0x7C),
  defineStateFloat("Pos Y", 0x80),
  defineStateFloat("Pos Z", 0x84)
)
RV.pos.label = "Position"
RV.pos.displayDefaults = {signed=true, beforeDecimal=3, afterDecimal=3}

RV.vel = V(
  subclass(Vector3Value, RacerValue),
  defineStateFloat("Vel X", 0x94),
  defineStateFloat("Vel Y", 0x98),
  defineStateFloat("Vel Z", 0x9C)
)
RV.vel.label = "Velocity"
RV.vel.displayDefaults = {signed=true, beforeDecimal=3, afterDecimal=3}

-- Machine orientation in world coordinates
RV.wOrient = V(
  subclass(Vector3Value, RacerValue),
  defineStateFloat("W Orient X", 0xEC),
  defineStateFloat("W Orient Y", 0xF0),
  defineStateFloat("W Orient Z", 0xF4)
)
RV.wOrient.label = "Orient"
RV.wOrient.displayDefaults = {signed=true, beforeDecimal=1, afterDecimal=3}

-- Machine orientation in current gravity coordinates
RV.gOrient = V(
  subclass(Vector3Value, RacerValue),
  defineStateFloat("G Orient X", 0x10C),
  defineStateFloat("G Orient Y", 0x110),
  defineStateFloat("G Orient Z", 0x114)
)
RV.gOrient.label = "Orient (grav)"
RV.gOrient.displayDefaults = {signed=true, beforeDecimal=1, afterDecimal=3}


RV.kmh = defineStateFloat("km/h", 0x17C)
RV.energy = defineStateFloat("Energy", 0x184)
RV.boostFramesLeft = MV("Boost frames left", 0x18A, StateValue, ByteType)
RV.score = MV("Score", 0x210, StateValue, ShortType)
RV.terrainState218 = MV(
  "Terrain state", 0x218, StateValue, BinaryType,
  {binarySize=8, binaryStartBit=7}
)
RV.gripAndAirState = MV(
  "Grip and air state", 0x247, StateValue, BinaryType,
  {binarySize=8, binaryStartBit=7}
)
RV.damageLastHit = defineStateFloat("Damage, last hit", 0x4AC)
RV.boostDelay = MV("Boost delay", 0x4C6, StateValue, ShortType)
RV.boostEnergyUsageFactor =
  defineStateFloat("Boost energy usage factor", 0x4DC)
RV.terrainState4FD = MV(
  "Terrain state 4FD", 0x4FD, StateValue, BinaryType,
  {binarySize=8, binaryStartBit=7}
)
RV.generalState58F = MV(
  "State 58F", 0x58F, StateValue, BinaryType,
  {binarySize=8, binaryStartBit=7}
)


RV.trackWidth = MV("Track width", 0x5E4, State2Value, FloatType)

RV.checkpointMain = MV("Main checkpoint", 0x618, State2Value, SignedIntType)
RV.checkpointFraction = MV("CP fraction", 0x628, State2Value, FloatType)
RV.sectionCheckpoint1 = MV("Section 1 CP", 0x61C, State2Value, SignedIntType)
RV.sectionCheckpoint1Fraction = MV(
  "Section 1 CP frac", 0x62C, State2Value, FloatType)
RV.sectionCheckpoint2 = MV("Section 2 CP", 0x620, State2Value, SignedIntType)
RV.sectionCheckpoint2Fraction = MV(
  "Section 2 CP frac", 0x630, State2Value, FloatType)
RV.sectionCheckpoint3 = MV("Section 3 CP", 0x624, State2Value, SignedIntType)
RV.sectionCheckpoint3Fraction = MV(
  "Section 3 CP frac", 0x634, State2Value, FloatType)
RV.checkpointLastContact = MV("Last contact CP", 0x1CC, StateValue, IntType)
RV.checkpointLastContactFraction = MV("Last contact CP frac", 0x1D0, StateValue, FloatType)
RV.checkpointGround = MV("Ground CP", 0x680, State2Value, SignedIntType)
RV.checkpointGroundFraction = MV("Ground CP frac", 0x690, State2Value, FloatType)
RV.closestCheckpoint = MV("Closest CP", 0x5FC, State2Value, SignedIntType)
RV.checkpointNumber74 = MV("Checkpoint 74", 0x74, State2Value, SignedIntType)
RV.checkpointNumberD0 = MV("Checkpoint D0", 0xD0, State2Value, SignedIntType)
RV.checkpointNumber154 = MV("Checkpoint 154", 0x154, State2Value, SignedIntType)
RV.checkpointNumber1B0 = MV("Checkpoint 1B0", 0x1B0, State2Value, SignedIntType)
RV.checkpointNumber234 = MV("Checkpoint 234", 0x234, State2Value, SignedIntType)
RV.checkpointNumber290 = MV("Checkpoint 290", 0x290, State2Value, SignedIntType)
RV.checkpointNumber314 = MV("Checkpoint 314", 0x314, State2Value, SignedIntType)
RV.checkpointNumber370 = MV("Checkpoint 370", 0x370, State2Value, SignedIntType)

RV.checkpointLateralOffset = MV("CP lateral", 0x668, State2Value, FloatType)
RV.checkpointRightVector = V(
  subclass(Vector3Value, RacerValue),
  MV("CP Right X", 0x560, State2Value, FloatType),
  MV("CP Right Y", 0x570, State2Value, FloatType),
  MV("CP Right Z", 0x580, State2Value, FloatType)
)
RV.checkpointRightVector.label = "CP Right"
RV.checkpointRightVector.displayDefaults = {
  signed=true, beforeDecimal=1, afterDecimal=5}
RV.checkpointTrackCenter = V(
  subclass(Vector3Value, RacerValue),
  MV("CP Center X", 0x56C, State2Value, FloatType),
  MV("CP Center Y", 0x57C, State2Value, FloatType),
  MV("CP Center Z", 0x58C, State2Value, FloatType)
)
RV.checkpointTrackCenter.label = "CP Center"
RV.checkpointTrackCenter.displayDefaults = {
  signed=true, beforeDecimal=1, afterDecimal=5}

RV.lapIndex = MV("Lap index", 0x67B, State2Value, ByteType)
RV.lapIndexPosition = MV("Lap index, position", 0x67F, State2Value, SignedByteType)
RV.lapIndexGround = MV("Lap index, ground", 0x6B7, State2Value, ByteType)
RV.lapIndexPositionGround = MV("Lap index, pos/gr", 0x6BB, State2Value, SignedByteType)

RV.raceDistance = MV("Race distance", 0x658, State2Value, FloatType)
RV.lapDistance = MV("Lap distance", 0x660, State2Value, FloatType)


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
RV.collision216 = MV("Collision 216", 0x216, StateValue, IntType)
RV.speed224 = defineStateFloat("Speed 224", 0x224)
RV.boost228 = defineStateFloat("Boost 228", 0x228)
RV.slopeRateOfChange288 = defineStateFloat("Slope rate of change 288", 0x288)
RV.tilt28C = defineStateFloat("Tilt 28C", 0x28C)
RV.orientation290 = defineStateFloat("Orientation 290", 0x290)
RV.collision3D8 = defineStateFloat("Collision 3D8", 0x3D8)
RV.speed478 = defineStateFloat("Speed 478", 0x478)
RV.strafeEffect = MV("Strafe effect", 0x4B0, StateValue, SignedShortType)
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

function Timer:init(label, offset)
  self.label = label

  self.frames = self.block:MV(
    label..", frames", offset, State2Value, IntType)
  self.frameFraction = self.block:MV(
    label..", frame fraction", offset+4, State2Value, FloatType)
  self.mins = self.block:MV(
    label..", minutes", offset+8, State2Value, ByteType)
  self.secs = self.block:MV(
    label..", seconds", offset+9, State2Value, ByteType)
  self.millis = self.block:MV(
    label..", milliseconds", offset+10, State2Value, ShortType)
end

function Timer:updateValue()
  for _, key in pairs({'frames', 'frameFraction', 'mins', 'secs', 'millis'}) do
    self[key]:update()
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


local raceTimer = V(subclass(Value, RacerValue, Block))
RV.raceTimer = raceTimer

raceTimer.blockValues = {
  total = V(Timer, "Total", 0x744),
  currLap = V(Timer, "This lap", 0x6C0),
  prevLap = V(Timer, "Prev. lap", 0x6CC),
  back2Laps = V(Timer, "2 laps ago", 0x6D8),
  back3Laps = V(Timer, "3 laps ago", 0x6E4),
  back4Laps = V(Timer, "4 laps ago", 0x6F0),
  back5Laps = V(Timer, "5 laps ago", 0x6FC),
  back6Laps = V(Timer, "6 laps ago", 0x708),
  back7Laps = V(Timer, "7 laps ago", 0x714),
  back8Laps = V(Timer, "8 laps ago", 0x720),
  bestLap = V(Timer, "Best lap", 0x72C),
  sumOfFinishedLaps = V(Timer, "Sum of finished laps", 0x738),
}

function raceTimer:init()
  Block.init(self)

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

  local lines = {}
  table.insert(lines, self.total:display(options))
  table.insert(lines, self.currLap:display(options))

  local completedLaps = 0
  local finishedRace = false
  if self.racer.lapIndex:isValid() then
    completedLaps = self.racer.lapIndex:get()
    finishedRace = self.racer:finishedRace()
  end

  -- Show up to maxPrevLaps previous individual lap times
  local firstLapToShow = math.max(1, completedLaps - options.maxPrevLaps + 1)
  for lapN = firstLapToShow, completedLaps do
    local prevLapN = completedLaps - lapN + 1

    local lapOptions = {}
    utils.updateTable(lapOptions, options)
    lapOptions.label = string.format("Lap %d", lapN)

    table.insert(lines, self.prevLaps[prevLapN]:display(lapOptions))
  end

  if finishedRace then
    local finalOptions = {}
    utils.updateTable(finalOptions, options)
    finalOptions.label = "Final time"
    table.insert(lines, self.sumOfFinishedLaps:display(finalOptions))
  end

  local s = table.concat(lines, "\n")

  -- For auto-layout purposes, make this display as tall as its maximum
  -- possible height.
  local maxLines = 3 + options.maxPrevLaps
  for n = #lines + 1, maxLines do s = s.."\n" end

  return s
end


-- Controller inputs (uncalibrated)
local controllerInput = V(subclass(Value, PlayerValue))
PV.controllerInput = controllerInput

function controllerInput:init()
  local blockStart = 0x15CBD0 + (self.player.playerIndex * 0x8)

  self.ABXYS = self.block:MV("ABXY & Start", blockStart + 0,
    StaticValue, BinaryType, {binarySize=8, binaryStartBit=7})
  self.DZ = self.block:MV("D-Pad & Z", blockStart + 1,
    StaticValue, BinaryType, {binarySize=8, binaryStartBit=7})
  self.stickX = self.block:MV("Stick X", blockStart + 2, StaticValue, ByteType)
  self.stickY = self.block:MV("Stick Y", blockStart + 3, StaticValue, ByteType)
  self.CStickX = self.block:MV("C-Stick X", blockStart + 4, StaticValue, ByteType)
  self.CStickY = self.block:MV("C-Stick Y", blockStart + 5, StaticValue, ByteType)
  self.L = self.block:MV("L", blockStart + 6, StaticValue, ByteType)
  self.R = self.block:MV("R", blockStart + 7, StaticValue, ByteType)
end

function controllerInput:getButton(button)
  -- Return 1 if button is pressed, 0 otherwise.
  local value = nil
  if button == "A" then value = self.ABXYS:get()[8]
  elseif button == "B" then value = self.ABXYS:get()[7]
  elseif button == "X" then value = self.ABXYS:get()[6]
  elseif button == "Y" then value = self.ABXYS:get()[5]
  elseif button == "S" then value = self.ABXYS:get()[4]
  elseif button == "Z" then value = self.DZ:get()[4]
  elseif button == "^" then value = self.DZ:get()[5]
  elseif button == "v" then value = self.DZ:get()[6]
  elseif button == ">" then value = self.DZ:get()[7]
  elseif button == "<" then value = self.DZ:get()[8]
  else error("Button code not recognized: " .. tostring(button))
  end

  return value
end

function controllerInput:buttonDisplay(button)
  local value = self:getButton(button)
  if value == 1 then
    return button
  else
    return " "
  end
end

function controllerInput:displayAllButtons()
  local s = ""
  for _, button in pairs{"A", "B", "X", "Y", "S", "Z", "^", "v", "<", ">"} do
    s = s..self:buttonDisplay(button)
  end
  return s
end

function controllerInput:stickXDisplay()
  return utils.displayAnalog(
    self.stickX:get()-128, 'int', ">", "<", {digits=3})
end
function controllerInput:stickYDisplay()
  return utils.displayAnalog(
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

  local lines = {}

  if options.LR then table.insert(
    lines, string.format("L %s R %s", self:LDisplay(), self:RDisplay()))
  end
  if options.stick then table.insert(
    lines, string.format("%s %s", self:stickXDisplay(), self:stickYDisplay()))
  end
  table.insert(lines, self:displayAllButtons())

  return table.concat(lines, "\n")
end


-- Make the get-buttons interface a bit more uniform with other games,
-- for ease of use from classes like ResettableValue.
function Player:getButton(button)
  return self.controllerInput:getButton(button)
end


-- Post-calibration values.
-- This refers to not only stick calibration (which is user defined), but also
-- calibration that the game does to go from raw C-stick/L/R values to more
-- useful values.
local calibratedInput = V(controllerInput)
PV.calibratedInput = calibratedInput

function calibratedInput:init()
  valuetypes.initValueAsNeeded(self.player.controllerInput)

  local blockStart = 0x1BAC30 + (self.player.playerIndex * 0x20)

  self.ABXYS = self.player.controllerInput.ABXYS
  self.DZ = self.player.controllerInput.DZ
  self.stickX =
      self.block:MV("Stick X, calibrated", blockStart + 0x0, RefValue, FloatType)
  self.stickY =
      self.block:MV("Stick Y, calibrated", blockStart + 0x4, RefValue, FloatType)
  self.CStickX =
      self.block:MV("C-Stick X, calibrated", blockStart + 0x8, RefValue, FloatType)
  self.CStickY =
      self.block:MV("C-Stick Y, calibrated", blockStart + 0xC, RefValue, FloatType)
  self.L =
      self.block:MV("L, calibrated", blockStart + 0x10, RefValue, FloatType)
  self.R =
      self.block:MV("R, calibrated", blockStart + 0x14, RefValue, FloatType)
end

function calibratedInput:stickXDisplay()
  return utils.displayAnalog(
    self.stickX:get(), 'float', ">", "<", {beforeDecimal=1, afterDecimal=3})
end
function calibratedInput:stickYDisplay()
  return utils.displayAnalog(
    self.stickY:get(), 'float', "^", "v", {beforeDecimal=1, afterDecimal=3})
end
function calibratedInput:LDisplay()
  return utils.floatToStr(self.L:get(), {beforeDecimal=1, afterDecimal=3})
end
function calibratedInput:RDisplay()
  return utils.floatToStr(self.R:get(), {beforeDecimal=1, afterDecimal=3})
end


-- Replay input values.
-- You can get these during a replay, Time Attack run, or Grand Prix race.
--
-- Similar to calibrated inputs, with one notable exception:
-- For L and R, replay inputs only track net strafe (R value minus L value)
-- and a boolean saying whether L and R are both greater than zero.
-- So L 100% / R 100% and L 20% / R 20% are indistinguishable.
local replayInput = V(Value)
GV.replayInput = replayInput

function replayInput:init()
  self.buttons = self.block:MV("Buttons", 0,
    ReplayInputValue, BinaryType, {binarySize=4, binaryStartBit=7})
  self.steerX = self.block:MV("Steer X", 1, ReplayInputValue, SignedByteType)
  self.steerY = self.block:MV("Steer Y", 2, ReplayInputValue, SignedByteType)
  self.strafe = self.block:MV("Strafe", 3, ReplayInputValue, SignedByteType)
  self.accel = self.block:MV("Accel", 4, ReplayInputValue, ByteType)
  self.brake = self.block:MV("Brake", 5, ReplayInputValue, ByteType)
end

function replayInput:getButton(button)
  -- Return true if button is pressed, false otherwise.
  local value = nil
  if button == "Accel" then value = self.accel:get()
  elseif button == "Boost" then value = self.buttons:get()[2]
  elseif button == "Brake" then value = self.brake:get()
  elseif button == "L+R" then value = self.buttons:get()[4]
  elseif button == "Side" then value = self.buttons:get()[1]
  elseif button == "Spin" then value = self.buttons:get()[3]
  else error("Button code not recognized: " .. tostring(button))
  end

  return value > 0
end

function replayInput:isValid()
  return self.buttons:isValid()
end

function replayInput:buttonDisplay(button)
  local pressed = self:getButton(button)

  if pressed then
    return button
  else
    -- A number of spaces equal to the button string
    return string.rep(" ", string.len(button))
  end
end

function replayInput:display(options)
  if not self:isValid() then
    local lineCount = 2
    if options.strafe then lineCount = lineCount + 1 end
    if options.steer then lineCount = lineCount + 1 end
    return self.invalidDisplay..string.rep('\n', lineCount-1)
  end

  options = options or {}

  local lines = {}

  if options.strafe then
    local strafe = utils.displayAnalog(
      self.strafe:get(), 'int', ">", "<", {digits=3})
    local bothLR = self:buttonDisplay("L+R")
    table.insert(lines, "Strafe: "..strafe.." "..bothLR)
  end
  if options.steer then
    local steerX = utils.displayAnalog(
      self.steerX:get(), 'int', ">", "<", {digits=3})
    local steerY = utils.displayAnalog(
      self.steerY:get(), 'int', "^", "v", {digits=3})
    table.insert(lines, "Steer: "..steerX.." "..steerY)
  end

  table.insert(lines,
    self:buttonDisplay("Accel")
    .." "..self:buttonDisplay("Side"))
  table.insert(lines,
    self:buttonDisplay("Boost")
    .." "..self:buttonDisplay("Brake")
    .." "..self:buttonDisplay("Spin"))

  return table.concat(lines, "\n")
end

-- The following Values implement an approximation of how much L and R
-- are pressed. Replays don't give full L/R information.

local replayInputLOrR = V(Value)

function replayInputLOrR:init()
  if not self.game.frameCounterAddress then
    error("replayInputLOrR requires the frame counter addresses.")
  end
end

function replayInputLOrR:isValid()
  return self.game.replayInput:isValid()
end

function replayInputLOrR:updateValue()
  -- L and R may have to be considered and updated together to make a
  -- coherent guess.
  -- But since we have two values, L and R, this function will be called twice
  -- per display update. Ensure that only one value update happens.
  local currentFrame = self.game:getFrameCount()
  self.game.replayLRLastUpdate = self.game.replayLRLastUpdate or 0
  if self.game.replayLRLastUpdate == currentFrame then return end
  self.game.replayLRLastUpdate = currentFrame

  local strafe = self.game.replayInput.strafe:get()
  local bothLR = self.game.replayInput:getButton("L+R")
  local rangeMax = 100

  if bothLR then
    -- The most common cases of L+R are:
    -- 1. Pressing both all the way
    -- 2. Pressing one all the way and the other partially
    --
    -- This will probably make the input changes more 'sudden' compared to
    -- actual human inputs. However, there's not really a good way to
    -- account for this when processing replay inputs in real time
    -- (i.e. without being able to look at inputs of future frames).
    self.game.replayInputL.value = math.min(rangeMax, rangeMax-strafe)
    self.game.replayInputR.value = math.min(rangeMax, rangeMax+strafe)
  else
    -- Only one shoulder button is pressed. Easy to find the values.
    self.game.replayInputR.value = math.max(0, strafe)
    self.game.replayInputL.value = math.max(0, -strafe)
  end
end

GV.replayInputL = V(replayInputLOrR)
GV.replayInputR = V(replayInputLOrR)


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

local controlState = V(subclass(Value, RacerValue, Block))
RV.controlState = controlState

controlState.blockValues = {
  steerY = defineStateFloat("Control, steering Y", 0x1F4),
  strafe = defineStateFloat("Control, strafe", 0x1F8),
  steerX = defineStateFloat("Control, steering X", 0x1FC),
  accel = defineStateFloat("Control, accel", 0x200),
  brake = defineStateFloat("Control, brake", 0x204),
}

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

function controlState:displayAllButtons()
  return string.format("%s %s\n%s %s",
    self:buttonDisplay("Accel"),
    self:buttonDisplay("Side"),
    self:buttonDisplay("Brake"),
    self:buttonDisplay("Spin"))
end

function controlState:boostDisplay()
  if not self:isValid() then return self.invalidDisplay end

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
  if not self:isValid() then
    local lineCount = 2
    if options.strafe then lineCount = lineCount + 1 end
    if options.steer then lineCount = lineCount + 1 end
    return self.invalidDisplay..string.rep('\n', lineCount-1)
  end

  options = options or {}

  local lines = {}

  if options.strafe then
    local strafe = utils.displayAnalog(
      self.strafe:get(), 'float', ">", "<", {afterDecimal=3})
    table.insert(lines, "Strafe: "..strafe)
  end
  if options.steer then
    local steerX = utils.displayAnalog(
      self.steerX:get(), 'float', ">", "<", {afterDecimal=3})
    local steerY = utils.displayAnalog(
      self.steerY:get(), 'float', "^", "v", {afterDecimal=3})
    table.insert(lines, "Steer: "..steerX.." "..steerY)
  end

  table.insert(lines, self:displayAllButtons())

  table.insert(lines, "Boost: "..self:boostDisplay())

  return table.concat(lines, "\n")
end


GX.ControllerLRImage = subclass(layoutsModule.AnalogTriggerInputImage)
function GX.ControllerLRImage:init(window, player, options)
  options = options or {}
  options.max = options.max or 255

  layoutsModule.AnalogTriggerInputImage.init(
    self, window, player.controllerInput.L, player.controllerInput.R, options)
end

GX.ControllerStickImage = subclass(layoutsModule.StickInputImage)
function GX.ControllerStickImage:init(window, player, options)
  options = options or {}
  options.max = options.max or 255
  options.min = options.min or 0
  options.square = options.square or true

  layoutsModule.StickInputImage.init(
    self, window,
    player.controllerInput.stickX, player.controllerInput.stickY, options)
end

GX.CalibratedLRImage = subclass(layoutsModule.AnalogTriggerInputImage)
function GX.CalibratedLRImage:init(window, player, options)
  options = options or {}
  options.max = options.max or 1

  layoutsModule.AnalogTriggerInputImage.init(
    self, window, player.calibratedInput.L, player.calibratedInput.R, options)
end

GX.CalibratedStickImage = subclass(layoutsModule.StickInputImage)
function GX.CalibratedStickImage:init(window, player, options)
  options = options or {}
  options.max = options.max or 1
  options.square = options.square or true

  layoutsModule.StickInputImage.init(
    self, window,
    player.calibratedInput.stickX, player.calibratedInput.stickY, options)
end

GX.ReplayStrafeImage = subclass(layoutsModule.AnalogTwoSidedInputImage)
function GX.ReplayStrafeImage:init(window, game, options)
  options = options or {}
  options.max = options.max or 100

  layoutsModule.AnalogTwoSidedInputImage.init(
    self, window, game.replayInput.strafe, options)
end

GX.ReplayLRImage = subclass(layoutsModule.AnalogTriggerInputImage)
function GX.ReplayLRImage:init(window, game, options)
  options = options or {}
  options.max = options.max or 100

  layoutsModule.AnalogTriggerInputImage.init(
    self, window, game.replayInputL, game.replayInputR, options)
end

GX.ReplaySteerImage = subclass(layoutsModule.StickInputImage)
function GX.ReplaySteerImage:init(window, game, options)
  options = options or {}
  options.max = options.max or 100
  options.square = options.square or true

  layoutsModule.StickInputImage.init(
    self, window,
    game.replayInput.steerX, game.replayInput.steerY, options)
end

GX.ControlStateStrafeImage = subclass(layoutsModule.AnalogTwoSidedInputImage)
function GX.ControlStateStrafeImage:init(window, racer, options)
  options = options or {}
  options.cpuSteerRange = options.cpuSteerRange or false
  -- CPUs can strafe harder
  if options.cpuSteerRange then options.max = 1.35 else options.max = 1 end

  layoutsModule.AnalogTwoSidedInputImage.init(
    self, window, racer.controlState.strafe, options)
end

GX.ControlStateSteerImage = subclass(layoutsModule.StickInputImage)
function GX.ControlStateSteerImage:init(window, racer, options)
  options = options or {}
  options.square = options.square or true
  options.cpuSteerRange = options.cpuSteerRange or false
  -- CPUs can left/right steer harder
  if options.cpuSteerRange then options.max = 1.35 else options.max = 1 end

  layoutsModule.StickInputImage.init(
    self, window,
    racer.controlState.steerX, racer.controlState.steerY, options)
end


return GX
