-- Super Mario Galaxy 2



-- Imports

-- package.loaded.<module> ensures that the module gets de-cached as needed.
-- That way, if we change the code in those modules and then re-run the script,
-- we won't need to restart Cheat Engine to see the code changes take effect.

package.loaded.utils = nil
local utils = require "utils"
local readIntBE = utils.readIntBE
local subclass = utils.subclass

package.loaded.valuetypes = nil
local valuetypes = require "valuetypes"
local V = valuetypes.V
local MV = valuetypes.MV
local MemoryValue = valuetypes.MemoryValue
local FloatType = valuetypes.FloatTypeBE
local IntType = valuetypes.IntTypeBE
local ShortType = valuetypes.ShortTypeBE
local ByteType = valuetypes.ByteType
local SignedIntType = valuetypes.SignedIntTypeBE
local StringType = valuetypes.StringType
local BinaryType = valuetypes.BinaryType
local Vector3Value = valuetypes.Vector3Value

package.loaded._supermariogalaxyshared = nil
local SMGshared = require "_supermariogalaxyshared"



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

local GV = SMG2.blockValues



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

GV.generalState1a = MV(
  "State bits 01-08", -0x51FC, SMG2.PosRefValue, BinaryType,
  {binarySize=8, binaryStartBit=7}
)
GV.generalState1b = MV(
  "State bits 09-16", -0x51FB, SMG2.PosRefValue, BinaryType,
  {binarySize=8, binaryStartBit=7}
)
GV.generalState1c = MV(
  "State bits 17-24", -0x51FA, SMG2.PosRefValue, BinaryType,
  {binarySize=8, binaryStartBit=7}
)
GV.generalState1d = MV(
  "State bits 25-32", -0x51F9, SMG2.PosRefValue, BinaryType,
  {binarySize=8, binaryStartBit=7}
)
function SMG2:onGround()
  return (self.generalState1a:get()[2] == 1)
end



-- In-game timers.
GV.stageTimeFrames =
  MV("Stage time, frames", 0xA75D10, SMG2.StaticValue, IntType)

GV.fileTimeFrames =
  MV("File time, frames", 0xE40E4C, SMG2.StaticValue, ShortType)
function GV.fileTimeFrames:get()
  -- This is a weird combination of big endian and little endian, it seems.
  local address = self:getAddress()
  local lowPart = self:read(address)
  local highPart = self:read(address + 2)
  return (highPart * 65536) + lowPart
end



-- Position, velocity, and other coordinates related stuff.
GV.pos = V(
  Vector3Value,
  MV("Pos X", -0x8670, SMG2.PosRefValue, FloatType),
  MV("Pos Y", -0x866C, SMG2.PosRefValue, FloatType),
  MV("Pos Z", -0x8668, SMG2.PosRefValue, FloatType)
)
GV.pos.label = "Position"
GV.pos.displayDefaults = {signed=true, beforeDecimal=5, afterDecimal=1}

-- 1 frame earlier than what you see on camera.
GV.pos_early1 = V(
  Vector3Value,
  MV("Pos X", -0x8C58+0x14, SMG2.PosRefValue, FloatType),
  MV("Pos Y", -0x8C58+0x18, SMG2.PosRefValue, FloatType),
  MV("Pos Z", -0x8C58+0x1C, SMG2.PosRefValue, FloatType)
)
GV.pos_early1.label = "Position"
GV.pos_early1.displayDefaults =
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
GV.baseVel = V(
  Vector3Value,
  MV("Base Vel X", -0x8C58+0x38, SMG2.PosRefValue, FloatType),
  MV("Base Vel Y", -0x8C58+0x3C, SMG2.PosRefValue, FloatType),
  MV("Base Vel Z", -0x8C58+0x40, SMG2.PosRefValue, FloatType)
)
GV.baseVel.label = "Base Vel"
GV.baseVel.displayDefaults = {signed=true}


-- Mario/Luigi's direction of gravity.
GV.downVectorGravity = V(
  Vector3Value,
  MV("Down X", -0x86C4, SMG2.PosRefValue, FloatType),
  MV("Down Y", -0x86C0, SMG2.PosRefValue, FloatType),
  MV("Down Z", -0x86BC, SMG2.PosRefValue, FloatType)
)
GV.downVectorGravity.label = "Grav (Down)"
GV.downVectorGravity.displayDefaults =
  {signed=true, beforeDecimal=1, afterDecimal=4}

-- Downward accel acting on Mario/Luigi.
-- Has its differences from both gravity and tilt.
-- Unlike gravity, this also responds to tilting slopes.
-- Unlike tilt, this 'straightens out' to match gravity
-- a few frames after jumping.
GV.downVectorAccel = V(
  Vector3Value,
  MV("Down X", -0x7D88, SMG2.PosRefValue, FloatType),
  MV("Down Y", -0x7D84, SMG2.PosRefValue, FloatType),
  MV("Down Z", -0x7D80, SMG2.PosRefValue, FloatType)
)
GV.downVectorAccel.label = "Down accel\ndirection"
GV.downVectorAccel.displayDefaults =
  {signed=true, beforeDecimal=1, afterDecimal=4}

-- Up vector (tilt). Offset from the gravity vector when there is tilt.
GV.upVectorTilt = V(
  Vector3Value,
  MV("Up X", -0x5018, SMG2.PosRefValue, FloatType),
  MV("Up Y", -0x5014, SMG2.PosRefValue, FloatType),
  MV("Up Z", -0x5010, SMG2.PosRefValue, FloatType)
)
GV.upVectorTilt.label = "Tilt (Up)"
GV.upVectorTilt.displayDefaults =
  {signed=true, beforeDecimal=1, afterDecimal=4}



-- Inputs and spin state.

GV.buttons1 = MV("Buttons 1", 0xB38A2E, SMG2.StaticValue, BinaryType,
  {binarySize=8, binaryStartBit=7})
GV.buttons2 = MV("Buttons 2", 0xB38A2F, SMG2.StaticValue, BinaryType,
  {binarySize=8, binaryStartBit=7})

GV.wiimoteShakeBit =
  MV("Wiimote spin bit", -0x7C4A, SMG2.PosRefValue, ByteType)
GV.nunchukShakeBit =
  MV("Nunchuk spin bit", -0x7C49, SMG2.PosRefValue, ByteType)
GV.spinCooldownTimer =
  MV("Spin cooldown timer", -0x7E19, SMG2.PosRefValue, ByteType)
GV.spinAttackTimer =
  MV("Spin attack timer", -0x7E1C, SMG2.PosRefValue, ByteType)
-- Not quite sure what this is; it keeps counting up if you do multiple
-- mini-spins in one jump
GV.spinFrames =
  MV("Spin frames", -0x7E1B, SMG2.PosRefValue, ByteType)
-- Counts up during a ground spin. If interrupted by jumping, tapping crouch
-- while standing still, etc., stops counting up.
-- Doesn't apply to a crouching spin (and couldn't find a similar value
-- that does apply to crouching spins).
GV.spinAnimationFrames =
  MV("Spin animation frames", -0x1BE1, SMG2.PosRefValue, ByteType)
-- This timer ends a little after the cooldown ends.
GV.lumaReturnAnimationTimer =
  MV("Luma return animation timer", -0x7E15, SMG2.PosRefValue, ByteType)
GV.midairSpinTimer =
  MV("Midair spin timer", -0x4E05, SMG2.PosRefValue, ByteType)
GV.midairSpinType =
  MV("Midair spin type", -0x4DE1, SMG2.PosRefValue, ByteType)
  
GV.stickX = MV("Stick X", 0xB38A8C, SMG2.StaticValue, FloatType)
GV.stickY = MV("Stick Y", 0xB38A90, SMG2.StaticValue, FloatType)



-- Some other stuff.

GV.lastJumpType =
  MV("Last jump type", -0x4DD9, SMG2.PosRefValue, ByteType)
-- Not quite sure what this is
GV.groundTurnTimer =
  MV("Ground turn timer", -0x4DFB, SMG2.PosRefValue, ByteType)
GV.unknownState =
  MV("Unknown state", -0x7D23, SMG2.PosRefValue, ByteType)


return SMG2
