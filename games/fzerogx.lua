-- F-Zero GX
-- Tested only on the US version so far.



-- Imports.

-- First make sure that the imported modules get de-cached as needed, since
-- we may be re-running the script in the same run of Cheat Engine.
package.loaded.shared = nil
package.loaded.utils = nil
package.loaded.dolphin = nil
package.loaded.valuetypes = nil
package.loaded.valuedisplay = nil

local shared = require "shared"
local utils = require "utils"
local dolphin = require "dolphin"
local vtypes = require "valuetypes"
local vdisplay = require "valuedisplay"

local readIntBE = utils.readIntBE
local readFloatBE = utils.readFloatBE
local floatToStr = utils.floatToStr
local initLabel = utils.initLabel
local debugDisp = utils.debugDisp
local StatRecorder = utils.StatRecorder

local V = vtypes.V
local copyFields = vtypes.copyFields
local MemoryValue = vtypes.MemoryValue
local FloatValue = vtypes.FloatValue
local IntValue = vtypes.IntValue
local ShortValue = vtypes.ShortValue
local ByteValue = vtypes.ByteValue
local SignedIntValue = vtypes.SignedIntValue
local StringValue = vtypes.StringValue
local BinaryValue = vtypes.BinaryValue
local addAddressToList = vtypes.addAddressToList

local ValueDisplay = vdisplay.ValueDisplay

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



-- Functions that compute some addresses.

local gameId = "GFZE01"  -- US version
local addrs = {}
addrs.o = dolphin.getGameStartAddress(gameId)

-- Pointer that we'll use for reference.
-- Not sure what this is meant to point to exactly, but when this pointer
-- changes value, many other relevant addresses (like the settings
-- slider value) move by the same amount as the value change.
addrs.refPointer = addrs.o + readIntBE(addrs.o + 0x1B78A8, 4) - 0x80000000

addrs.machineBaseStatsBlocks = addrs.o + 0x1554000
addrs.machineBaseStatsBlocksCustom = addrs.o + 0x1555F04
  
-- A duplicate of the base stats block. We'll use this as a backup of the
-- original values, when playing with the values in the primary block.
addrs.machineBaseStatsBlocks2 = addrs.refPointer + 0x195584
addrs.machineBaseStatsBlocks2Custom = addrs.refPointer + 0x1B3A54

-- It's useful to have an address where there's always a ton of zeros.
-- We can use this address as the result when an address computation
-- is invalid. Zeros are better than unreadable memory (results in
-- error) or garbage values.
-- This group of zeros should go on for 0x60000 to 0x70000 bytes.
addrs.zeros = addrs.o + 0xB4000
  


-- These addresses can change as the game runs, so we specify them as
-- functions that can be run continually.
local computeAddr = {
  
  machineStateBlocks = function()
    local pointerAddress = addrs.refPointer + 0x22779C
    local pointerRead = readIntBE(pointerAddress, 4)
    
    if pointerRead == 0 then
      -- A race is not going on, so this address is invalid.
      return nil
    else
      return addrs.o + pointerRead - 0x80000000
    end
  end,
  
  machineState2Blocks = function()
    if addrs.machineStateBlocks == nil then return nil end
    
    local pointerAddress = addrs.machineStateBlocks - 0x20
    return addrs.o + readIntBE(pointerAddress, 4) - 0x80000000
  end,
}

local function updateAddresses()
  addrs.machineStateBlocks = computeAddr.machineStateBlocks()
  addrs.machineState2Blocks = computeAddr.machineState2Blocks()
end




-- Forward declarations.
local machineId = nil
local machineName = nil



-- GX specific classes and their supporting functions.



-- Values at static addresses (from the beginning of the game memory).
local StaticValue = {}

copyFields(StaticValue, {MemoryValue})

function StaticValue:getAddress()
  return addrs.o + self.offset
end



-- Values that are a constant offset from a certain reference pointer.
local RefValue = {}

copyFields(RefValue, {MemoryValue})

function RefValue:getAddress()
  return addrs.refPointer + self.offset
end



-- Number of machines competing in the race when it began
local numOfRaceEntrants = V("# Race entrants", 0x1BAEE0, {RefValue, ByteValue})
-- Number of human racers
local numOfHumanRacers = V("# Human racers", 0x245309, {RefValue, ByteValue})

local function machineIndexIsValid(machineIndex)
  return machineIndex < numOfRaceEntrants:get()
end

local function forMachineI(stateValueObj, machineIndex)
  -- Create a new object which is the same as the first param, except
  -- it has the specified machineIndex
  local newObj = {machineIndex = machineIndex}
  setmetatable(newObj, stateValueObj)
  stateValueObj.__index = stateValueObj

  return newObj
end



-- 0x620-byte memory block that's dense with useful information.
-- There's one such block per machine in a race.
local StateValue = {machineIndex = 0}

copyFields(StateValue, {MemoryValue})

function StateValue:getAddress()
  if addrs.machineStateBlocks == nil then return addrs.zeros end
  
  return addrs.machineStateBlocks + self.offset + (0x620 * self.machineIndex)
end

function StateValue:isValid()
  return machineIndexIsValid(self.machineIndex)
end

function StateValue:getLabel()
  if self.machineIndex == 0 then
    return self.label
  else
    if machineIndexIsValid(self.machineIndex) then
      return self.label..", "..forMachineI(machineName, self.machineIndex):get()
    else
      return self.label..", ".."rival "..self.machineIndex
    end
  end
end

function StateValue:getDisplay(label, value)
  if label == nil then label = self:getLabel() end
  if value == nil then value = self:get() end
  
  if not machineIndexIsValid(self.machineIndex) then
    return string.format("Rival machine %d is N/A", self.machineIndex)
  end
  
  return label .. ": " .. self:toStrForDisplay(value)
end



-- Another memory block that has some useful information.
-- There's one such block per machine in a race. 0x760 for humans and
-- 0x820 for CPUs.
local State2Value = {machineIndex = 0}

copyFields(State2Value, {StateValue})

function State2Value:getAddress()
  if addrs.machineState2Blocks == nil then return addrs.zeros end

  local humans = numOfHumanRacers:get()
  if self.machineIndex <= humans then
    return addrs.machineState2Blocks + self.offset
    + (0x760 * self.machineIndex)
  else
    return addrs.machineState2Blocks + self.offset
    + (0x820 * (self.machineIndex - humans) + 0x760 * humans)
  end
end



local CustomPartId = {machineIndex = 0}
copyFields(CustomPartId, {RefValue, ByteValue})
function CustomPartId:getAddress()
  -- Player 2's custom part IDs are 0x81C0 later than P1's, and then P3's IDs
  -- are 0x81C0 later than that, and so on.
  return addrs.refPointer + self.offset + (0x81C0 * self.machineIndex)
end

local customBodyId = V("Custom body ID", 0x1C7588, {CustomPartId})
local customCockpitId = V("Custom cockpit ID", 0x1C7590, {CustomPartId})
local customBoosterId = V("Custom booster ID", 0x1C7598, {CustomPartId})
local customPartIds = {customBodyId, customCockpitId, customBoosterId}



local StatWithBase = {}

StatWithBase.extraArgs = {
  -- Base stat's offset from the start of a base-stats block
  "baseOffset",
  -- Which custom part types have a nonzero base value for this particular
  -- stat; 1 = body, 2 = cockpit, 3 = booster. Example values: {1} {3} {1,2} 
  "customPartsWithBase",
}
copyFields(StatWithBase, {StateValue})

function StatWithBase:getBaseAddressGeneral(which, baseOffset)
  -- which - 1 for the primary base stats block (changing this mid-race
  --   changes the machine performance), 2 for the second base stats block.
  -- baseOffset - offset of this particular stat from the start of the base
  --   stats block. (This parameter exists for ease of use with SizeStat)
  
  local startNonCustom = nil
  local startCustom = nil
  if which == 1 then
    startNonCustom = addrs.machineBaseStatsBlocks
    startCustom = addrs.machineBaseStatsBlocksCustom
  else  -- 2
    startNonCustom = addrs.machineBaseStatsBlocks2
    startCustom = addrs.machineBaseStatsBlocks2Custom
  end

  local thisMachineId = forMachineI(machineId, self.machineIndex):get()
  
  if thisMachineId == 50 then
    -- Custom machine.
    -- 
    -- Note: it's possible that more than one custom part has a nonzero
    -- base value here. (Check with #self.customPartsWithBase == 1)
    -- Weight and Body are the only stats where this is true. 
    -- 
    -- But handling this properly seems to take a fair bit of extra work,
    -- so no matter what we'll just get one nonzero base value.
    -- 
    -- That's still enough to fully manipulate the stats; it'll just be a bit
    -- unintuitive. e.g. to change Gallant Star-G4's weight, you have to
    -- manipulate Dread Hammer's weight (the interface doesn't let you
    -- manipulate the other two parts):
    -- 2660 to 1660 weight: change Dread Hammer's weight from 1440 to 440
    -- 2660 to 660 weight: change Dread Hammer's weight from 1440 to -560
    local idOfCustomPartWithBase = forMachineI(
      customPartIds[self.customPartsWithBase[1]], self.machineIndex):get()
      
    -- In the second base stats block, there's some extra bytes before the
    -- cockpit part stats, and again before the booster part stats.
    -- extraBytes accounts for this.
    local extraBytes = 0
    if which == 2 then
      if idOfCustomPartWithBase > 49 then extraBytes = 24 + 16
      elseif idOfCustomPartWithBase > 24 then extraBytes = 24
      end
    end
    
    return (startCustom
      + (0xB4 * idOfCustomPartWithBase) + extraBytes + baseOffset)
    
  else
    -- Non-custom machine.
    return (startNonCustom
      + (0xB4 * thisMachineId) + baseOffset)
      
  end
end

function StatWithBase:getBaseAddress()
  return self:getBaseAddressGeneral(1, self.baseOffset)
end
function StatWithBase:getBase()
  return self:read(self:getBaseAddress())
end

function StatWithBase:getBase2Address()
  return self:getBaseAddressGeneral(2, self.baseOffset)
end
function StatWithBase:getBase2()
  return self:read(self:getBase2Address())
end

function StatWithBase:getResetValue()
  return self:getBase2()
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
  return self:get() ~= self:getBase2()
end

function StatWithBase:getDisplay(label, value)
  if label == nil then label = self:getLabel() end
  if value == nil then value = self:get() end
  
  if not machineIndexIsValid(self.machineIndex) then
    return string.format("Rival machine %d is N/A", self.machineIndex)
  end
  
  local s = self:toStrForDisplay(value)
  if self:hasChanged() then
    s = s.."*"
  end
  
  return label .. ": " .. s
end



local StatTiedToBase = {}

StatTiedToBase.extraArgs = {}
copyFields(StatTiedToBase, {StatWithBase})

function StatTiedToBase:set(v)
  self:write(self:getBaseAddress(), v)
end

function StatTiedToBase:getEditFieldText()
  return self:toStrForEditField(self:getBase())
end
function StatTiedToBase:getEditWindowTitle()
  return string.format("Edit: %s (base value)", self:getLabel())
end

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
  return self:getBase() ~= self:getBase2()
end

function StatTiedToBase:addAddressesToList()
  -- We'll add two entries: actual stat and base stat.
  -- The base stat is more convenient to edit, because the actual stat usually
  -- needs disabling an instruction (which writes to the address every frame)
  -- before it can be edited.
  -- On the other hand, editing the actual stat avoids having to
  -- consider the base -> actual conversion math.
  
  -- Actual stat
  addAddressToList(self, {})
  
  -- Base stat
  addAddressToList(self, {
    address = self:getBaseAddress(),
    description = self:getLabel() .. " (base)",
  })
end



local SizeStat = {}

SizeStat.extraArgs = {"specificLabels", "formulas"}
copyFields(SizeStat, {StatWithBase})

function SizeStat:getAddress(key)
  if addrs.machineStateBlocks == nil then return addrs.zeros end

  if key == nil then key = 1 end
  return (addrs.machineStateBlocks
    + (0x620 * self.machineIndex) + self.offset[key])
end
function SizeStat:get(key)
  return self:read(self:getAddress(key))
end
  
function SizeStat:getBaseAddress(key)
  if key == nil then key = 1 end
  return self:getBaseAddressGeneral(1, self.baseOffset[key])
end
function SizeStat:getBase(key)
  return self:read(self:getBaseAddress(key))
end
  
function SizeStat:getBase2Address(key)
  if key == nil then key = 1 end
  return self:getBaseAddressGeneral(2, self.baseOffset[key])
end
function SizeStat:getBase2(key)
  return self:read(self:getBase2Address(key))
end

function SizeStat:set(v)
  -- Change actual values directly; changing base doesn't change actual here
  for key, func in pairs(self.formulas) do
    self:write(self:getAddress(key), func(v))
  end
end

function SizeStat:addAddressesToList()
  -- Only add the actual stats here. Changing the base size values
  -- doesn't change the actual values, so no particular use in adding
  -- base values to the list.
  for key, specificLabel in pairs(self.specificLabels) do
    addAddressToList(self, {
      address = self:getAddress(key),
      description = specificLabel,
    })
  end
end



local FloatStat = {}

copyFields(FloatStat, {FloatValue})

-- For machine stats that are floats, we'll prefer trimming zeros in the
-- display so that the number looks cleaner. (Normally we keep trailing
-- zeros when the value can change rapidly, as it is jarring when the
-- display constantly gains/loses digits... but machine stats don't
-- change rapidly.)
function FloatStat:toStrForDisplay(v, precision, trimTrailingZeros)
  if precision == nil then precision = 4 end
  if trimTrailingZeros == nil then trimTrailingZeros = true end
  
  return utils.floatToStr(v, precision, trimTrailingZeros)
end



local BinaryValueTiedToBase = {}

-- It's ugly design that this class exists, as it is mostly redundant
-- with BinaryValue and StatTiedToBase. Reasons for the messiness include:
-- 1. BinaryValue having to define get(), set(), and addAddressesToList()
--    which are normally not datatype specific
-- 2. The need for involving a binary start bit into many of these kinds of
--    functions; and there is a different binary start bit for the actual
--    and base for the two binary machine stats

BinaryValueTiedToBase.extraArgs = {"baseBinaryStartBit"}
copyFields(BinaryValueTiedToBase, {StatTiedToBase, BinaryValue})
  
function BinaryValueTiedToBase:getBase()
  return self:read(self:getBaseAddress(), self.baseBinaryStartBit)
end
  
function BinaryValueTiedToBase:getBase2()
  return self:read(self:getBase2Address(), self.baseBinaryStartBit)
end

function BinaryValueTiedToBase:set(v)
  self:write(self:getBaseAddress(), self.baseBinaryStartBit, v)
end

function BinaryValueTiedToBase:hasChanged()
  local base = self:getBase()
  local base2 = self:getBase2()
  for index = 1, #base do
    if base[index] ~= base2[index] then return true end
  end
  return false
end
  
function BinaryValueTiedToBase:addAddressesToList()
  -- Actual stat
  addAddressToList(self, {})
  
  -- Base stat
  addAddressToList(self, {
    address = self:getBaseAddress(),
    description = self:getLabel() .. " (base)",
    binaryStartBit = self.baseBinaryStartBit,
  })
end



-- Accel/max speed setting; 0 (full accel) to 100 (full max speed).
local settingsSlider = V("Settings slider", 0x2453A0, {RefValue, IntValue})
function settingsSlider:getDisplay(label, value)
  if label == nil then label = self:getLabel() end
  if value == nil then value = self:get() end
  
  return label .. ": " .. self:toStrForDisplay(value) .. "%"
end 



-- There are two memory blocks containing a lot of machine state information.
local function NewStateFloat(label, stateBlockOffset)
  return V(label, stateBlockOffset, {StateValue, FloatValue})
end

machineId = V("Machine ID", 0x6, {StateValue, IntValue})
machineId.numOfBytes = 2
machineId.addressListType = vtCustom
machineId.addressListCustomTypeName = "2 Byte Big Endian"

machineName = V("Machine name", 0x3C, {StateValue, StringValue}, {maxLength=64})


-- Coordinates
local posX = NewStateFloat("Pos X", 0x7C)
local posY = NewStateFloat("Pos Y", 0x80)
local posZ = NewStateFloat("Pos Z", 0x84)
local velX = NewStateFloat("Vel X", 0x94)
local velY = NewStateFloat("Vel Y", 0x98)
local velZ = NewStateFloat("Vel Z", 0x9C)
-- Machine orientation in world coordinates
local wOrientX = NewStateFloat("W Orient X", 0xEC)
local wOrientY = NewStateFloat("W Orient Y", 0xF0)
local wOrientZ = NewStateFloat("W Orient Z", 0xF4)
-- Machine orientation in current gravity coordinates
local gOrientX = NewStateFloat("G Orient X", 0x10C)
local gOrientY = NewStateFloat("G Orient Y", 0x110)
local gOrientZ = NewStateFloat("G Orient Z", 0x114)

local function coordinatesDisplay(key, beforeDot, afterDot)
  if key == "pos" then coords = {posX, posY, posZ}
  elseif key == "vel" then coords = {velX, velY, velZ}
  elseif key == "wOrient" then coords = {wOrientZ, wOrientY, wOrientX}
  elseif key == "gOrient" then coords = {gOrientX, gOrientY, gOrientZ}
  else return nil
  end
  if beforeDot == nil then beforeDot = 4 end
  if afterDot == nil then afterDot = 1 end
  
  local format = "%+0" .. 1+beforeDot+1+afterDot .. "." .. afterDot .. "f"
  local s = string.format(
    format .. "," .. format .. "," .. format,
    coords[1]:get(), coords[2]:get(), coords[3]:get()
  )
  return s
end

local function getDirectionChange(oldDir, newDir)
  if newDir - oldDir > 180 then
    -- Probably crossing from -180 to 180
    return (newDir - oldDir) - 360
  elseif newDir - oldDir < -180 then
    -- Probably crossing from 180 to -180
    return (newDir - oldDir) + 360
  else
    return newDir - oldDir
  end
end
local lastVelocityDirUpdate = dolphin.getFrameCount()
local lastVelocityDir = 0
local velocityDirChangeStr = ""
local function XZvelocityDirDisplay()
  -- We'll make 0 degrees be facing right at the starting line. Then a higher
  -- angle as you rotate counter-clockwise, till you're facing left at 180.
  -- Below the horizontal you have negative angles.
  local degrees = math.deg(math.atan2(-velZ:get(), velX:get()))
  local degreesStr = string.format("%+07.2f°", degrees)
  
  -- Update the display showing the change in orientation.
  -- Only bother with this if the dolphin frame count is being updated,
  -- otherwise we're updating for nothing.
  local frameCount = dolphin.getFrameCount()
  if frameCount ~= lastVelocityDirUpdate then
    velocityDirChangeStr = string.format(
      "(%+07.2f°)", getDirectionChange(lastVelocityDir, degrees)
    )
    lastVelocityDirUpdate = frameCount
    lastVelocityDir = degrees
  end
  
  -- Add the orientationChangeStr even if it wasn't updated, so that we can
  -- display any old orientation change (e.g. when we are just pausing
  -- emulation).
  local s = "Moving: " .. degreesStr .. " " .. velocityDirChangeStr
  return s
end
local lastOrientationUpdate = dolphin.getFrameCount()
local lastOrientation = 0
local orientationChangeStr = ""
local function XZorientationDisplay()
  -- Note that wOrient seems to have X and Z switched, compared to pos/vel,
  -- hence the order of the components here.
  local degrees = math.deg(math.atan2(wOrientX:get(), -wOrientZ:get()))
  local degreesStr = string.format("%+07.2f°", degrees)
  
  local frameCount = dolphin.getFrameCount()
  if frameCount ~= lastOrientationUpdate then
    orientationChangeStr = string.format(
      "(%+07.2f°)", getDirectionChange(lastOrientation, degrees)
    )
    lastOrientationUpdate = frameCount
    lastOrientation = degrees
  end
  
  local s = "Facing: " .. degreesStr .. " " .. orientationChangeStr
  return s
end


-- General-interest state values
local generalState1a = V(
  "State bits 01-08", 0x0, {StateValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
local generalState1b = V(
  "State bits 09-16", 0x1, {StateValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
local generalState1c = V(
  "State bits 17-24", 0x2, {StateValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
local generalState1d = V(
  "State bits 25-32", 0x3, {StateValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
local kmh = NewStateFloat("km/h (next)", 0x17C)
local energy = NewStateFloat("Energy", 0x184)
local boostFramesLeft = V("Boost frames left", 0x18A, {StateValue, ByteValue})
local checkpointNumber = NewStateFloat("Checkpoint number", 0x1CC)
local progressToNextCheckpoint = NewStateFloat("Progress to next checkpoint", 0x1D0)
local score = V("Score", 0x210, {StateValue, ShortValue})
local terrainState218 = V(
  "Terrain state", 0x218, {StateValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
local gripAndAirState = V(
  "Grip and air state", 0x247, {StateValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
local damageLastHit = NewStateFloat("Damage, last hit", 0x4AC)
local boostDelay = V("Boost delay", 0x4C6, {StateValue, ShortValue})
local boostEnergyUsageFactor = NewStateFloat("Boost energy usage factor", 0x4DC)
local terrainState4FD = V(
  "Terrain state 4FD", 0x4FD, {StateValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
local generalState58F = V(
  "State 58F", 0x58F, {StateValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
local lapNumber = V("Lap number", 0x67B, {State2Value, ByteValue})
local lapNumberPosition = V("Lap number (position)", 0x67F, {State2Value, ByteValue, SignedIntValue})



-- Physics related
local gripA4 = NewStateFloat("Grip A4", 0xA4)
local collisionC4 = NewStateFloat("Collision C4", 0xC4)
local accelC8 = NewStateFloat("Accel C8", 0xC8)
local stabilityCC = NewStateFloat("Stability CC", 0xCC)
local aerialTilt = NewStateFloat("Aerial Tilt", 0x180)
local boost18C = NewStateFloat("Boost 18C", 0x18C)
local stability198 = NewStateFloat("Stability 198", 0x198)
local stability19C = NewStateFloat("Stability 19C", 0x19C)
local stability1A0 = NewStateFloat("Stability 1A0", 0x1A0)
local stability1A4 = NewStateFloat("Stability 1A4", 0x1A4)
local stability1A8 = NewStateFloat("Stability 1A8", 0x1A8)
local stability1AC = NewStateFloat("Stability 1AC", 0x1AC)
local stability1B0 = NewStateFloat("Stability 1B0", 0x1B0)
local stability1B4 = NewStateFloat("Stability 1B4", 0x1B4)
local stability1B8 = NewStateFloat("Stability 1B8", 0x1B8)
local groundContact = NewStateFloat("Ground contact", 0x1C8)
local collision216 = V("Collision 216", 0x216, {StateValue, IntValue})
local speed224 = NewStateFloat("Speed 224", 0x224)
local boost228 = NewStateFloat("Boost 228", 0x228)
local slopeRateOfChange288 = NewStateFloat("Slope rate of change 288", 0x288)
local tilt28C = NewStateFloat("Tilt 28C", 0x28C)
local orientation290 = NewStateFloat("Orientation 290", 0x290)
local collision3D8 = NewStateFloat("Collision 3D8", 0x3D8)
local speed478 = NewStateFloat("Speed 478", 0x478)
local strafeEffect = V("Strafe effect", 0x4B0, {StateValue, ShortValue, SignedIntValue})
local stability4B4 = NewStateFloat("Stability 4B4", 0x4B4)
local turnReactionInput = NewStateFloat("T. reaction input", 0x4D4)
local turnReactionEffect = NewStateFloat("T. reaction effect", 0x4D8)
local collision500X = NewStateFloat("Collision 500, X", 0x500)
local collision500Y = NewStateFloat("Collision 500, Y", 0x504)
local collision500Z = NewStateFloat("Collision 500, Z", 0x508)
local turning580 = NewStateFloat("Turning 580", 0x580)
local collision5C4 = NewStateFloat("Collision 5C4", 0x5C4)
local turning5C8 = NewStateFloat("Turning 5C8", 0x5C8)
local turning5CC = NewStateFloat("Turning 5CC", 0x5CC)
local unknown5D0 = NewStateFloat("Unknown 5D0", 0x5D0)
local unknown5D4 = NewStateFloat("Unknown 5D4", 0x5D4)



-- Controller inputs

-- Digital inputs
local input = {}
input.ABXYS = V("ABXY & Start", 0x15CBD0, {StaticValue, BinaryValue},
  {binarySize=8, binaryStartBit=7})
input.DZ = V("D-Pad & Z", 0x15CBD1, {StaticValue, BinaryValue},
  {binarySize=8, binaryStartBit=7})
  
-- Analog inputs, raw/uncalibrated integers
input.stickXRaw = V("Stick X, Raw", 0x15CBD2, {StaticValue, ByteValue})
input.stickYRaw = V("Stick Y, Raw", 0x15CBD3, {StaticValue, ByteValue})
input.CStickXRaw = V("C-Stick X", 0x15CBD4, {StaticValue, ByteValue})
input.CStickYRaw = V("C-Stick Y", 0x15CBD5, {StaticValue, ByteValue})
input.LRaw = V("L, Raw", 0x15CBD6, {StaticValue, ByteValue})
input.RRaw = V("R, Raw", 0x15CBD7, {StaticValue, ByteValue})

-- Analog inputs, calibrated floats 
input.stickX = V("Stick X", 0x1BAB54, {RefValue, FloatValue})
input.stickY = V("Stick Y", 0x1BAB58, {RefValue, FloatValue})
input.CStickX = V("C-Stick X", 0x1BAB5C, {RefValue, FloatValue})
input.CStickY = V("C-Stick Y", 0x1BAB60, {RefValue, FloatValue})
input.L = V("L", 0x1BAB64, {RefValue, FloatValue})
input.R = V("R", 0x1BAB68, {RefValue, FloatValue})

function displayAnalog(v, format, posSymbol, negSymbol)
  -- Display a signed analog value, e.g. something that ranges
  -- anywhere from -100 to 100.
  local s = string.format(format, math.abs(v))
  if v == 0 then s = "  "..s
  elseif v > 0 then s = posSymbol.." "..s
  else s = negSymbol.." "..s end
  return s
end

function input.button(buttonName)
  local value = nil
  if buttonName == "A" then
    value = input.ABXYS:get()[8]
  elseif buttonName == "B" then
    value = input.ABXYS:get()[7]
  elseif buttonName == "X" then
    value = input.ABXYS:get()[6]
  elseif buttonName == "Y" then
    value = input.ABXYS:get()[5]
  elseif buttonName == "S" then
    value = input.ABXYS:get()[4]
  elseif buttonName == "Z" then
    value = input.DZ:get()[4]
  end
  if value == 1 then
    return buttonName
  else
    return " "
  end
end

function input.displayRaw()
  local stickX = displayAnalog(input.stickXRaw:get()-128, "%03d", ">", "<")
  local stickY = displayAnalog(input.stickYRaw:get()-128, "%03d", "^", "v")
  local stick = stickX .. "," .. stickY
  local L = string.format("%03d", input.LRaw:get())
  local R = string.format("%03d", input.RRaw:get())
  local buttons = string.format("%s%s%s%s%s%s",
    input.button("A"), input.button("B"), input.button("X"),
    input.button("Y"), input.button("S"), input.button("Z")
  )
  local s = string.format(
    "L %s      %s R\n"
    .."Stick:  %s\n"
    .."Buttons:  %s",
    L, R, stick, buttons
  )
  return s
end

function input.displayCalibrated()
  -- This version doesn't use the full stick range (in accordance to your
  -- calibration) and doesn't use the full L/R range (only the range
  -- that the game recognizes?).
  local stickX = displayAnalog(input.stickX:get()*100.0, "%05.1f", ">", "<")
  local stickY = displayAnalog(input.stickY:get()*100.0, "%05.1f", "^", "v")
  local stick = stickX .. "," .. stickY
  local L = string.format("%05.1f", input.L:get()*100.0)
  local R = string.format("%05.1f", input.R:get()*100.0)
  local buttons = string.format("%s%s%s%s%s%s",
    input.button("A"), input.button("B"), input.button("X"),
    input.button("Y"), input.button("S"), input.button("Z")
  )
  local s = string.format(
    "L %s      %s R\n"
    .."Stick:  %s\n"
    .."Buttons:  %s",
    L, R, stick, buttons
  )
  return s
end

-- Racer control state; useful for CPUs and Replays.
-- This differs from previous input-related values since
-- if you're not actually controlling your racer (e.g. in a
-- menu, or pressing buttons when watching a replay), then
-- these don't register accordingly.
-- Limitation: We only know the net strafe amount (R minus L).

local controlSteerY = NewStateFloat("Control, steering Y", 0x1F4)
local controlStrafe = NewStateFloat("Control, strafe", 0x1F8)
local controlSteerX = NewStateFloat("Control, steering X", 0x1FC)
local controlAccel = NewStateFloat("Control, accel", 0x200)
local controlBrake = NewStateFloat("Control, brake", 0x204)

local controlState = {}
function controlState.button(buttonName)
  if buttonName == "A" then
    -- Can only be at two float values: 1.0 or 0.0.
    if controlAccel:get() > 0.5 then return "A" else return " " end
  elseif buttonName == "Brake" then
    if controlBrake:get() > 0.5 then return "Brake" else return "     " end
  elseif buttonName == "Side" then
    -- Can only be at 1 or 0.
    if generalState1b:get()[7] == 1 then return "Side" else return "    " end
  elseif buttonName == "Spin" then
    if generalState1d:get()[5] == 1 then return "Spin" else return "    " end
  end
end
function controlState.boost()
  local framesLeft = boostFramesLeft:get()
  local delay = boostDelay:get()
  if framesLeft > 0 then return string.format("%03d", framesLeft)
  elseif delay > 0 then return string.format("+%02d", delay)
  else return "   "
  end
end
function controlState.display()
  local steerX = displayAnalog(controlSteerX:get()*100.0, "%05.1f", ">", "<")
  local steerY = displayAnalog(controlSteerY:get()*100.0, "%05.1f", "^", "v")
  local steer = steerX .. "   " .. steerY
  local strafe = displayAnalog(controlStrafe:get()*100.0, "%05.1f", ">", "<")
  local buttons = string.format("%s %s %s %s",
    controlState.button("A"),
    controlState.button("Side"),
    controlState.button("Brake"),
    controlState.button("Spin")
  )
  local boost = controlState.boost()
  local s = string.format(
    "Strafe: %s\n"
    .."Stick:  %s\n"
    .."        %s\n"
    .."Boost:  %s\n",
    strafe, steer, buttons, boost
  )
  return s
end



-- Race timer

local timer = {}

local TimeStruct = {}
function TimeStruct:new(label, offset, machineIndexP)
  -- Make an object of the "class" TimeStruct.
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  
  obj.label = label
  obj.frames = V(label..", frames", offset, {State2Value, IntValue})
  obj.frameFraction = V(label..", frame fraction", offset+4, {State2Value, FloatValue})
  obj.mins = V(label..", minutes", offset+8, {State2Value, ByteValue})
  obj.secs = V(label..", seconds", offset+9, {State2Value, ByteValue})
  obj.millis = V(label..", milliseconds", offset+10, {State2Value, ShortValue})
  
  local machineIndex = machineIndexP
  if machineIndex == nil then machineIndex = 0 end
  
  if machineIndex ~= 0 then
    obj.frames = forMachineI(obj.frames)
    obj.frameFraction = forMachineI(obj.frameFraction)
    obj.mins = forMachineI(obj.mins)
    obj.secs = forMachineI(obj.secs)
    obj.millis = forMachineI(obj.millis)
  end
  return obj
end

timer.total = TimeStruct:new("Total", 0x744)
timer.currLap = TimeStruct:new("This lap", 0x6C0)
timer.prevLap = TimeStruct:new("Prev. lap", 0x6CC)
timer.back2Laps = TimeStruct:new("2 laps ago", 0x6D8)
timer.back3Laps = TimeStruct:new("3 laps ago", 0x6E4)
timer.back4Laps = TimeStruct:new("4 laps ago", 0x6F0)
timer.back5Laps = TimeStruct:new("5 laps ago", 0x6FC)
timer.back6Laps = TimeStruct:new("6 laps ago", 0x708)
timer.back7Laps = TimeStruct:new("7 laps ago", 0x714)
timer.back8Laps = TimeStruct:new("8 laps ago", 0x720)
timer.bestLap = TimeStruct:new("Best lap", 0x72C)
timer.sumOfFinishedLaps = TimeStruct:new("Sum of finished laps", 0x738)
timer.prevLaps = {
  timer.prevLap, timer.back2Laps, timer.back3Laps, timer.back4Laps,
  timer.back5Laps, timer.back6Laps, timer.back7Laps, timer.back8Laps,
}

function timer.display(struct, labelP, withFrameFractionP)
  -- struct is a TimeStruct object whose values we want to display.
  -- labelP can be a string or nil (not passed), in which case
  --   struct.label is used as the label.
  -- withFrameFractionP can be true/false or nil (not passed).
  local label = nil
  if labelP then label = labelP
  else label = struct.label end
  
  local withFrameFraction = nil
  if withFrameFractionP then withFrameFraction = withFrameFractionP
  else withFrameFraction = false end
  
  local s = string.format(
    "%s: %d'%02d\"%03d", label,
    struct.mins:get(), struct.secs:get(), struct.millis:get()
  )
  if withFrameFraction then
    s = s.." + "..string.format("%.4f", struct.frameFraction:get())
  end
  return s
end

function timer.raceDisplay()
  local s = nil
  -- General state bit 16 should indicate whether the race is done.
  if generalState1b:get()[8] == 0 then 
    s = timer.display(timer.total)
  else
    s = timer.display(timer.sumOfFinishedLaps, "Final")
  end
  
  s = s.."\n"..timer.display(timer.currLap)  
  local completedLaps = lapNumber:get()
  
  for lapN = math.max(1,completedLaps-3), completedLaps do
    local prevLapN = completedLaps - lapN + 1
    s = s.."\n"..timer.display(
      timer.prevLaps[prevLapN], string.format("Lap %d", lapN)
    )
  end
  return s
end



-- Machine stats

local function NewMachineStatFloat(label, offset, baseOffset, customPartsWithBase)
  return V(
    label, offset, {StatTiedToBase, FloatStat},
    {baseOffset=baseOffset, customPartsWithBase=customPartsWithBase}
  )
end

local accel = NewMachineStatFloat("Accel", 0x220, 0x8, {3})
local body = NewMachineStatFloat("Body", 0x30, 0x44, {1,2})
local boostInterval = NewMachineStatFloat("Boost interval", 0x234, 0x38, {3})
local boostStrength = NewMachineStatFloat("Boost strength", 0x230, 0x34, {3})
local cameraReorienting = NewMachineStatFloat("Cam. reorienting", 0x34, 0x4C, {2})
local cameraRepositioning = NewMachineStatFloat("Cam. repositioning", 0x38, 0x50, {2})
local drag = NewMachineStatFloat("Drag", 0x23C, 0x40, {3})
local driftAccel = NewMachineStatFloat("Drift accel", 0x2C, 0x1C, {3}) 
local grip1 = NewMachineStatFloat("Grip 1", 0xC, 0x10, {1})
local grip2 = NewMachineStatFloat("Grip 2", 0x24, 0x30, {2})
local grip3 = NewMachineStatFloat("Grip 3", 0x28, 0x14, {1})
local maxSpeed = NewMachineStatFloat("Max speed", 0x22C, 0xC, {3})
local obstacleCollision = V(
  "Obstacle collision", 0x584, {StateValue, FloatStat}, nil
)
local strafe = NewMachineStatFloat("Strafe", 0x1C, 0x28, {1})
local strafeTurn = NewMachineStatFloat("Strafe turn", 0x18, 0x24, {2})
local trackCollision = V(
  "Track collision", 0x588, {StatWithBase, FloatStat},
  {baseOffset=0x9C, customPartsWithBase={1}}
)
local turnDecel = NewMachineStatFloat("Turn decel", 0x238, 0x3C, {3})
local turning1 = NewMachineStatFloat("Turn tension", 0x10, 0x18, {1})
local turning2 = NewMachineStatFloat("Turn movement", 0x14, 0x20, {2})
local turning3 = NewMachineStatFloat("Turn reaction", 0x20, 0x2C, {1})
local weight = NewMachineStatFloat("Weight", 0x8, 0x4, {1,2,3})
local unknown48 = V(
  "Unknown 48", 0x477, {StatTiedToBase, ByteValue},
  {baseOffset=0x48, customPartsWithBase={2}}
)

-- Actual is state bit 1; base is 0x49 / 2
local unknown49a = V(
  "Unknown 49a", 0x0, {BinaryValueTiedToBase},
  {baseOffset=0x49, customPartsWithBase={2},
   binarySize=1, binaryStartBit=7, baseBinaryStartBit=1}
)
-- Actual is state bit 24; base is 0x49 % 2
local unknown49b = V(
  "Drift camera", 0x2, {BinaryValueTiedToBase},
  {baseOffset=0x49, customPartsWithBase={2},
   binarySize=1, binaryStartBit=0, baseBinaryStartBit=0}
)

local frontWidth = V(
  "Size, front width",
  {0x24C, 0x2A8, 0x3B4, 0x3E4},
  {SizeStat, FloatStat},
  {
    baseOffset={0x54, 0x60, 0x84, 0x90},
    customPartsWithBase={1},
    specificLabels={
      "Tilt, front width, right",
      "Tilt, front width, left",
      "Wall collision, front width, right",
      "Wall collision, front width, left",
    },
    formulas={
      function(v) return v end,
      function(v) return -v end,
      function(v) return v+0.2 end,
      function(v) return -(v+0.2) end,
    },
  }
)
local frontHeight = V(
  "Size, front width",
  {0x250, 0x2AC, 0x3B8, 0x3E8},
  {SizeStat, FloatStat},
  {
    baseOffset={0x58, 0x64, 0x88, 0x94},
    customPartsWithBase={1},
    specificLabels={
      "Tilt, front height, right",
      "Tilt, front height, left",
      "Wall collision, front height, right",
      "Wall collision, front height, left",
    },
    formulas={
      function(v) return v end,
      function(v) return v end,
      function(v) return v-0.1 end,
      function(v) return v-0.1 end,
    },
  }
)
local frontLength = V(
  "Size, front length",
  {0x254, 0x2B0, 0x3BC, 0x3EC},
  {SizeStat, FloatStat},
  {
    baseOffset={0x5C, 0x68, 0x8C, 0x98},
    customPartsWithBase={1},
    specificLabels={
      "Tilt, front length, right",
      "Tilt, front length, left",
      "Wall collision, front length, right",
      "Wall collision, front length, left",
    },
    formulas={
      function(v) return v end,
      function(v) return v end,
      function(v) return v-0.2 end,
      function(v) return v-0.2 end,
    },
  }
)
local backWidth = V(
  "Size, back width",
  {0x304, 0x360, 0x414, 0x444},
  {SizeStat, FloatStat},
  {
    baseOffset={0x6C, 0x78, 0x9C, 0xA8},
    customPartsWithBase={1},
    specificLabels={
      "Tilt, back width, right",
      "Tilt, back width, left",
      "Wall collision, back width, right",
      "Wall collision, back width, left",
    },
    formulas={
      function(v) return v end,
      function(v) return -v end,
      function(v)
        -- Black Bull is 0.3, everyone else is 0.2
        if machineId:get() == 29 then return v+0.3 else return v+0.2 end
      end,
      function(v)
        if machineId:get() == 29 then return -(v+0.3) else return -(v+0.2) end
      end,
    },
  }
)
local backHeight = V(
  "Size, back height",
  {0x308, 0x364, 0x418, 0x448},
  {SizeStat, FloatStat},
  {
    baseOffset={0x70, 0x7C, 0xA0, 0xAC},
    customPartsWithBase={1},
    specificLabels={
      "Tilt, back height, right",
      "Tilt, back height, left",
      "Wall collision, back height, right",
      "Wall collision, back height, left",
    },
    formulas={
      function(v) return v end,
      function(v) return v end,
      function(v) return v-0.1 end,
      function(v) return v-0.1 end,
    },
  }
)
local backLength = V(
  "Size, back length",
  {0x30C, 0x368, 0x41C, 0x44C},
  {SizeStat, FloatStat},
  {
    baseOffset={0x74, 0x80, 0xA4, 0xB0},
    customPartsWithBase={1},
    specificLabels={
      "Tilt, back length, right",
      "Tilt, back length, left",
      "Wall collision, back length, right",
      "Wall collision, back length, left",
    },
    formulas={
      function(v) return v end,
      function(v) return v end,
      function(v) return v+0.2 end,
      function(v) return v+0.2 end,
    },
  }
)



machineStats = {
  accel, body, boostInterval, boostStrength,
  cameraReorienting, cameraRepositioning, drag, driftAccel,
  grip1, grip2, grip3, maxSpeed, obstacleCollision,
  strafeTurn, strafe, trackCollision, turnDecel,
  turning1, turning2, turning3, weight,
  backLength, backWidth, frontLength, frontWidth,
  unknown48, unknown49a, unknown49b,
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



-- GUI window layouts.

local vars = {}
local updateMethod = nil
local updateTimeInterval = nil
local updateButton = nil
local generalFontName = "Calibri"  -- alt: Arial
local fixedWidthFontName = "Consolas"  -- alt: Lucida Console

local layoutAddressDebug = {
  
  init = function(window)
    updateMethod = "timer"
    updateTimeInterval = 100
    
    window:setSize(400, 300)
    
    vars.label = initLabel(window, 10, 5, "", 14)
    shared.debugLabel = initLabel(window, 10, 5, "", 9)
  
    vars.addressesToCompute = {
      "refPointer", "machineStateBlocks", "machineState2Blocks",
      "machineBaseStatsBlocks", "machineBaseStatsBlocks2",
    }
  end,
  
  update = function()
    local s = "o: "..utils.intToHexStr(addrs.o).."\n"
    
    for _, name in pairs(vars.addressesToCompute) do
      s = s..name..": "
      vars.label:setCaption(s)
      addrs[name] = computeAddr[name]()
      s = s..utils.intToHexStr(addrs[name]).."\n"
      vars.label:setCaption(s)
    end
  end,
}

local layoutKmhRecording = {
  
  init = function(window)
    -- Using a breakpoint that runs on every frame should guarantee that we
    -- get one value per frame, which is important for stat recording.
    updateMethod = "breakpoint"
    
    -- Set the display window's size.
    window:setSize(300, 200)
  
    -- Add a blank label to the window at position (10,5). In the update
    -- function, which is called on every frame, we'll update the label text.
    vars.label = initLabel(window, 10, 5, "")
    
    --shared.debugLabel = initLabel(window, 10, 160, "<debug>")
    
    vars.statRecorder = StatRecorder:new(window, 90)
    
    vars.kmh = nil
  end,
  
  update = function()
    updateAddresses()
    vars.label:setCaption(
      table.concat(
        {
          settingsSlider:getDisplay(),
          kmh:getDisplay("km/h", vars.kmh, 3, false)
        },
        "\n"
      )
    )
    
    if vars.statRecorder.currentlyTakingStats then
      local s = kmh:toStrForEditField(vars.kmh)
      vars.statRecorder:takeStat(s)
    end
    
    -- The kmh address has the km/h that will be displayed onscreen on the
    -- NEXT frame, so we order the code accordingly to display the CURRENT
    -- frame's km/h.
    vars.kmh = kmh:get()
  end,
}

local layoutEnergy = {
  
  init = function(window)
    updateMethod = "timer"
    updateTimeInterval = 50
    
    window:setSize(400, 300)
  
    vars.label = initLabel(window, 10, 5, "")
    
    vars.energies = {}
    vars.energies[0] = energy
    for i = 1, 5 do
      vars.energies[i] = forMachineI(energy, i)
    end
  end,
  
  update = function()
    updateAddresses()
    vars.label:setCaption(
      table.concat(
        {
          vars.energies[0]:getDisplay(),
          vars.energies[1]:getDisplay(),
          vars.energies[2]:getDisplay(),
          vars.energies[3]:getDisplay(),
          vars.energies[4]:getDisplay(),
          vars.energies[5]:getDisplay(),
          numOfRaceEntrants:getDisplay(),
        },
        "\n"
      )
    )
  end,
}

local layoutEnergy2 = {
  
  init = function(window)
    updateMethod = "timer"
    updateTimeInterval = 50
  
    window:setSize(650, 300)
  
    vars.label = initLabel(window, 10, 5, "", 14)
    
    local trackedValues = {energy}
    for i = 1, 5 do
      table.insert(trackedValues, forMachineI(energy, i))
    end

    local initiallyActive = {}
    for k, v in pairs(trackedValues) do initiallyActive[k] = v end
    
    vars.display = ValueDisplay:new(
      window, vars.label, updateAddresses, trackedValues, initiallyActive, 320)
  end,
  
  update = function()
    vars.display:update()
  end,
}

local layoutOneMachineStat = {
  
  init = function(window)
    updateMethod = "timer"
    updateTimeInterval = 50
  
    window:setSize(300, 130)
  
    vars.label = initLabel(window, 10, 5, "")
  end,
  
  update = function()
    updateAddresses()
    vars.label:setCaption(
      table.concat(
        {
          turning2:getDisplay(turning2:getLabel().." (B)", turning2:getBase()),
          turning2:getDisplay(),
        },
        "\n"
      )
    )
  end,
}



local layoutMachineStats = {
  
  init = function(window)
    updateMethod = "timer"
    updateTimeInterval = 50
  
    window:setSize(550, 570)
  
    vars.label = initLabel(window, 10, 5, "", 14)
    --shared.debugLabel = initLabel(window, 10, 350, "")

    local trackedValues = machineStats
    local initiallyActive = {accel, maxSpeed, weight}
    
    vars.display = ValueDisplay:new(
      window, vars.label, updateAddresses, trackedValues, initiallyActive)
  end,
  
  update = function()
    vars.display:update()
  end,
}



local layoutMachineStats2 = {
  
  -- Version that updates the display with an update button,
  -- instead of automatically on every frame.
  
  init = function(window)
    updateMethod = "button"
  
    window:setSize(550, 570)
  
    vars.label = initLabel(window, 10, 5, "", 14)
    --shared.debugLabel = initLabel(window, 10, 350, "")

    local trackedValues = machineStats
    local initiallyActive = {accel, maxSpeed, weight}
    
    vars.display = ValueDisplay:new(
      window, vars.label, updateAddresses, trackedValues, initiallyActive)
    
    updateButton = createButton(window)
    updateButton:setPosition(10, 460)
    updateButton:setCaption("Update")
    local font = updateButton:getFont()
    font:setSize(12)
  end,
  
  update = function()
    vars.display:update()
  end,
}



local layoutReplayInfo = {
  
  init = function(window)
    updateMethod = "timer"
    updateTimeInterval = 16
  
    window:setSize(400, 450)
    
    vars.timeAndEnergyLabel = initLabel(window, 10, 10, "", 14) 
    vars.inputsLabel = initLabel(window, 10, 300, "", 14, fixedWidthFontName)
    --shared.debugLabel = initLabel(window, 10, 400, "ABC", 12, fixedWidthFontName)
  end,
  
  update = function()
    updateAddresses()
    
    vars.timeAndEnergyLabel:setCaption(
      energy:getDisplay()
      .."\n\n"..timer.raceDisplay()
    )
    
    vars.inputsLabel:setCaption(controlState.display())  -- Works for replays/CPUs
    --vars.inputsLabel:setCaption(input.displayCalibrated())  -- Post calibration input
    --vars.inputsLabel:setCaption(input.displayRaw())  -- Raw input
  end,
}



local layoutSpeed224 = {
  
  init = function(window)
    updateMethod = "timer"
    updateTimeInterval = 16
  
    window:setSize(550, 500)
    
    vars.mainLabel = initLabel(window, 10, 5, "", 18)
    vars.velocityLabel = initLabel(window, 10, 100, "", 18)
    vars.inputsLabel = initLabel(window, 10, 300, "", 14, fixedWidthFontName)
    --shared.debugLabel = initLabel(window, 10, 500, "ABC", 12, fixedWidthFontName)
    
    local trackedValues = {
      speed224,
      kmh,
    }
    local initiallyActive = {
      speed224,
      kmh,
    }
    
    vars.display = ValueDisplay:new(
      window, vars.mainLabel, updateAddresses, trackedValues, initiallyActive, 320)
  end,
  
  update = function()
    vars.display:update()
    
    local velMag = math.sqrt(velX:get()^2 + velY:get()^2 + velZ:get()^2)
    local velMagOverKmhStr = string.format("%.6f", velMag / kmh:get())
    local kmhOverSpeed224Str = string.format("%.3f", kmh:get() / speed224:get())
    vars.velocityLabel:setCaption(table.concat({
      "Vel: "..coordinatesDisplay("vel", 4, 1),
      "velMag/kmh: "..velMagOverKmhStr,
      "kmh/speed224: "..kmhOverSpeed224Str,
    }, "\n"))
    vars.inputsLabel:setCaption(controlState.display())
  end,
}



-- *** CHOOSE YOUR LAYOUT HERE ***
local layout = layoutMachineStats



-- Initializing the GUI window.

local window = createForm(true)
-- Put it in the center of the screen.
window:centerScreen()
-- Or you can put it somewhere specific.
--window:setPosition(500, 0)
-- Set the window title.
window:setCaption("RAM Display")
-- Customize the labels' default font.
local font = window:getFont()
font:setName(generalFontName)
font:setSize(16)

layout.init(window)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


dolphin.setupDisplayUpdates(
  updateMethod, layout.update, window, updateTimeInterval, updateButton)

