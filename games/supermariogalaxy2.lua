-- Super Mario Galaxy 2



-- Imports

-- First make sure that the imported modules get de-cached as needed. That way,
-- if we change the code in those modules and then re-run the script, we won't
-- need to restart Cheat Engine to see the code changes take effect.
package.loaded.utils = nil
package.loaded.utils_math = nil
package.loaded.valuetypes = nil
package.loaded._supermariogalaxyshared = nil

local utils = require "utils"
local utils_math = require "utils_math"
local vtypes = require "valuetypes"
local SMGshared = require "_supermariogalaxyshared"

local readIntBE = utils.readIntBE
local subclass = utils.subclass

local MemoryValue = vtypes.MemoryValue
local FloatValue = vtypes.FloatValue
local IntValue = vtypes.IntValue
local ShortValue = vtypes.ShortValue
local ByteValue = vtypes.ByteValue
local SignedIntValue = vtypes.SignedIntValue
local StringValue = vtypes.StringValue
local BinaryValue = vtypes.BinaryValue
local Vector3Value = vtypes.Vector3Value



local SMG2 = subclass(SMGshared)

-- Shares layouts with SMG1.
SMG2.layoutModuleNames = {'supermariogalaxy_layouts'}

function SMG2:init(options)
  SMGshared.init(self, options)
  
  if options.gameVersion == 'US' then
    self.gameId = "SB4E01"
    self.refPointerOffset = 0xC7A2C8
  else
    error("gameVersion not supported: " .. options.gameVersion)
  end
  
  self.addrs = {}
  self:initConstantAddresses()
end



-- These are addresses that should stay constant for the most part,
-- as long as the game start address is constant.

function SMG2:initConstantAddresses()
  self.addrs.o = self:getGameStartAddress()
  
  -- It's useful to have an address where there's always a ton of zeros.
  -- We can use this address as the result when an address computation
  -- is invalid. Zeros are better than unreadable memory (results in
  -- error) or garbage values.
  -- This group of zeros should go on for 0x20000 to 0x30000 bytes.
  self.addrs.zeros = self.addrs.o + 0x754000
end



-- These addresses can change more frequently, so we specify them as
-- functions that can be run continually.

function SMG2:updateRefPointer()
  -- Not sure what this is meant to point to exactly, but when this pointer
  -- changes value, some other relevant addresses
  -- move by the same amount as the value change.
  self.addrs.refPointer =
    self.addrs.o
    + readIntBE(self.addrs.o + self.refPointerOffset, 4)
    - 0x80000000
end

function SMG2:updateRefPointer2()
  -- Another reference pointer.
  self.addrs.refPointer2 =
    self.addrs.o
    + readIntBE(self.addrs.o + 0x10824F0, 4)
    - 0x80000000
end

function SMG2:updatePosRefPointer()
  -- Another reference pointer, which can be used to find position values.

  local ptrValue = readIntBE(self.addrs.refPointer + 0x750, 4)
  
  if ptrValue < 0x80000000 or ptrValue > 0x90000000 then
    -- Rough check that we do not have a valid pointer. This happens when
    -- switching between Mario and Luigi. In this case, we'll give up
    -- on finding the position and read a bunch of zeros instead.
    self.addrs.posRefPointer = self.addrs.zeros
  end
  
  self.addrs.posRefPointer = self.addrs.o + ptrValue - 0x80000000
end

function SMG2:updateAddresses()
  self:updateRefPointer()
  self:updateRefPointer2()
  self:updatePosRefPointer()
end



-- Shortcuts for creating Values and MemoryValues.
local function V(...)
  return SMG2:VDeferredInit(...)
end
local function MV(...)
  return SMG2:MVDeferredInit(...)
end


-- Values at static addresses (from the beginning of the game memory).
SMG2.StaticValue = subclass(MemoryValue)

function SMG2.StaticValue:getAddress()
  return self.game.addrs.o + self.offset
end


-- Values that are a constant offset from the refPointer.
SMG2.RefValue = subclass(MemoryValue)

function SMG2.RefValue:getAddress()
  return self.game.addrs.refPointer + self.offset
end


-- Values that are a constant offset from another reference pointer.
SMG2.Ref2Value = subclass(MemoryValue)

function SMG2.Ref2Value:getAddress()
  return self.game.addrs.refPointer2 + self.offset
end


-- Values that are a constant offset from the position values' location.
SMG2.PosRefValue = subclass(MemoryValue)

function SMG2.PosRefValue:getAddress()
  return self.game.addrs.posRefPointer + self.offset
end



-- General-interest state values.

SMG2.generalState1a = MV(
  "State bits 01-08", -0x51FC, SMG2.PosRefValue, BinaryValue,
  {binarySize=8, binaryStartBit=7}
)
SMG2.generalState1b = MV(
  "State bits 09-16", -0x51FB, SMG2.PosRefValue, BinaryValue,
  {binarySize=8, binaryStartBit=7}
)
SMG2.generalState1c = MV(
  "State bits 17-24", -0x51FA, SMG2.PosRefValue, BinaryValue,
  {binarySize=8, binaryStartBit=7}
)
SMG2.generalState1d = MV(
  "State bits 25-32", -0x51F9, SMG2.PosRefValue, BinaryValue,
  {binarySize=8, binaryStartBit=7}
)
function SMG2:onGround()
  return (self.generalState1a:get()[2] == 1)
end



-- In-game timers.
SMG2.stageTimeFrames =
  MV("Stage time, frames", 0xA75D10, SMG2.StaticValue, IntValue)

SMG2.fileTimeFrames =
  MV("File time, frames", 0xE40E4C, SMG2.StaticValue, ShortValue)
function SMG2.fileTimeFrames:get()
  -- This is a weird combination of big endian and little endian, it seems.
  local address = self:getAddress()
  local lowPart = self:read(address)
  local highPart = self:read(address + 2)
  return (highPart * 65536) + lowPart
end



-- Position, velocity, and other coordinates related stuff.
SMG2.pos = V(
  Vector3Value,
  MV("Pos X", -0x8670, SMG2.PosRefValue, FloatValue),
  MV("Pos Y", -0x866C, SMG2.PosRefValue, FloatValue),
  MV("Pos Z", -0x8668, SMG2.PosRefValue, FloatValue)
)
SMG2.pos.label = "Position"
SMG2.pos.displayDefaults = {signed=true, beforeDecimal=5, afterDecimal=1}

-- 1 frame earlier than what you see on camera.
SMG2.pos_early1 = V(
  Vector3Value,
  MV("Pos X", -0x8C58+0x14, SMG2.PosRefValue, FloatValue),
  MV("Pos Y", -0x8C58+0x18, SMG2.PosRefValue, FloatValue),
  MV("Pos Z", -0x8C58+0x1C, SMG2.PosRefValue, FloatValue)
)
SMG2.pos_early1.label = "Position"
SMG2.pos_early1.displayDefaults =
  {signed=true, beforeDecimal=5, afterDecimal=1}
  

-- Velocity directly from a memory value.
-- Not all kinds of movement are covered. For example, launch stars and
-- riding moving platforms aren't accounted for.
--
-- It's usually preferable to use velocity based on position change, because
-- that's more accurate to observable velocity. But this velocity value
-- can still have its uses. For example, this is actually the velocity
-- observed on the NEXT frame, so if we want advance knowledge of the velocity,
-- then we might use this.
SMG2.baseVel = V(
  Vector3Value,
  MV("Base Vel X", -0x8C58+0x38, SMG2.PosRefValue, FloatValue),
  MV("Base Vel Y", -0x8C58+0x3C, SMG2.PosRefValue, FloatValue),
  MV("Base Vel Z", -0x8C58+0x40, SMG2.PosRefValue, FloatValue)
)
SMG2.baseVel.label = "Base Vel"
SMG2.baseVel.displayDefaults = {signed=true}


-- Mario/Luigi's direction of gravity.
SMG2.downVectorGravity = V(
  Vector3Value,
  MV("Down X", -0x86C4, SMG2.PosRefValue, FloatValue),
  MV("Down Y", -0x86C0, SMG2.PosRefValue, FloatValue),
  MV("Down Z", -0x86BC, SMG2.PosRefValue, FloatValue)
)
SMG2.downVectorGravity.label = "Grav (Down)"
SMG2.downVectorGravity.displayDefaults =
  {signed=true, beforeDecimal=1, afterDecimal=4}

-- Downward accel acting on Mario/Luigi.
-- TODO: Clarify what this is
SMG2.downVectorAccel = V(
  Vector3Value,
  MV("Down X", -0x7D88, SMG2.PosRefValue, FloatValue),
  MV("Down Y", -0x7D84, SMG2.PosRefValue, FloatValue),
  MV("Down Z", -0x7D80, SMG2.PosRefValue, FloatValue)
)
SMG2.downVectorAccel.label = "Down accel\ndirection"
SMG2.downVectorAccel.displayDefaults =
  {signed=true, beforeDecimal=1, afterDecimal=4}

-- Up vector (tilt). Offset from the gravity vector when there is tilt.
SMG2.upVectorTilt = V(
  Vector3Value,
  MV("Up X", -0x5018, SMG2.PosRefValue, FloatValue),
  MV("Up Y", -0x5014, SMG2.PosRefValue, FloatValue),
  MV("Up Z", -0x5010, SMG2.PosRefValue, FloatValue)
)
SMG2.upVectorTilt.label = "Tilt (Up)"
SMG2.upVectorTilt.displayDefaults =
  {signed=true, beforeDecimal=1, afterDecimal=4}



-- Inputs and spin state.

SMG2.buttons1 = MV("Buttons 1", 0xB38A2E, SMG2.StaticValue, BinaryValue,
  {binarySize=8, binaryStartBit=7})
SMG2.buttons2 = MV("Buttons 2", 0xB38A2F, SMG2.StaticValue, BinaryValue,
  {binarySize=8, binaryStartBit=7})

SMG2.wiimoteShakeBit =
  MV("Wiimote spin bit", -0x7C4A, SMG2.PosRefValue, ByteValue)
SMG2.nunchukShakeBit =
  MV("Nunchuk spin bit", -0x7C49, SMG2.PosRefValue, ByteValue)
SMG2.spinCooldownTimer =
  MV("Spin cooldown timer", -0x7E19, SMG2.PosRefValue, ByteValue)
SMG2.spinAttackTimer =
  MV("Spin attack timer", -0x7E1C, SMG2.PosRefValue, ByteValue)

SMG2.stickX = MV("Stick X", 0xB38A8C, SMG2.StaticValue, FloatValue)
SMG2.stickY = MV("Stick Y", 0xB38A90, SMG2.StaticValue, FloatValue)


return SMG2
