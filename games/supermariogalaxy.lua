-- Super Mario Galaxy



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



local SMG1 = subclass(SMGshared)

SMG1.supportedGameVersions = {
  -- Wii must be set to English language.
  na = 'RMGE01',
  us = 'RMGE01',

  jp = 'RMGJ01',
  ja = 'RMGJ01',

  -- Wii must be set to English language.
  eu = 'RMGP01',
  pal = 'RMGP01',
}

SMG1.layoutModuleNames = {'supermariogalaxy_layouts'}
SMG1.framerate = 60
-- Use D-Pad Down to reset max-value displays, average-value displays, etc.
SMG1.defaultResetButton = 'v'

function SMG1:init(options)
  SMGshared.init(self, options)

  if self.gameId == 'RMGE01' then
    self.refPointerOffset = 0xF8EF88
  elseif self.gameId == 'RMGJ01' then
    self.refPointerOffset = 0xF8F328
  elseif self.gameId == 'RMGP01' then
    self.refPointerOffset = 0xF8EF88
  end

  self.addrs = {}
  self:initConstantAddresses()
end

local GV = SMG1.blockValues



-- These are addresses that should stay constant for the most part,
-- as long as the game start address is constant.

function SMG1:initConstantAddresses()
  self.addrs.o = self:getGameStartAddress()

  -- It's useful to have an address where there's always a ton of zeros.
  -- We can use this address as the result when an address computation
  -- is invalid. Zeros are better than unreadable memory (results in
  -- error) or garbage values.
  -- This group of zeros should go on for 0x20000 to 0x30000 bytes.
  self.addrs.zeros = self.addrs.o + 0x626000
end



-- These addresses can change more frequently, so we specify them as
-- functions that can be run continually.

function SMG1:updateRefPointer()
  -- Not sure what this is meant to point to exactly, but when this pointer
  -- changes value, some other relevant addresses (like pos and vel)
  -- move by the same amount as the value change.
  --
  -- This pointer value changes whenever you load a different area.
  -- It's invalid during transition screens and before the
  -- title screen.
  local rawPointer = readIntBE(self.addrs.o + self.refPointerOffset, 4)
  if rawPointer == 0 then
    self.addrs.refPointer = nil
  else
    self.addrs.refPointer = self.addrs.o + rawPointer - 0x80000000
  end
end

function SMG1:updateMessageInfoPointer()
  -- Pointer that can be used to locate various message/text related info.
  --
  -- This pointer value changes whenever you load a different area.
  local rawPointer = readIntBE(self.addrs.o + 0x9A9240, 4)
  if rawPointer == 0 then
    self.addrs.messageInfoPointer = nil
  else
    self.addrs.messageInfoPointer = self.addrs.o + rawPointer - 0x80000000
  end
end

function SMG1:updatePosBlock()
  if self.addrs.refPointer == nil then
    self.addrs.posBlock = nil
  else
    self.addrs.posBlock = self.addrs.refPointer + 0x3EEC
  end
end

function SMG1:updateAddresses()
  self:updateRefPointer()
  self:updateMessageInfoPointer()
  self:updatePosBlock()
end



-- Values at static addresses (from the beginning of the game memory).
SMG1.StaticValue = subclass(MemoryValue)

function SMG1.StaticValue:getAddress()
  return self.game.addrs.o + self.offset
end


-- Values that are a constant offset from the refPointer.
SMG1.RefValue = subclass(MemoryValue)

function SMG1.RefValue:getAddress()
  return self.game.addrs.refPointer + self.offset
end

function SMG1.RefValue:isValid()
  return self.game.addrs.refPointer ~= nil
end


-- Values that are a constant small offset from the position values' location.
SMG1.PosBlockValue = subclass(MemoryValue)

function SMG1.PosBlockValue:getAddress()
  return self.game.addrs.posBlock + self.offset
end

function SMG1.PosBlockValue:isValid()
  return self.game.addrs.posBlock ~= nil
end


-- Values that are a constant offset from the messageInfoPointer.
SMG1.MessageInfoValue = subclass(MemoryValue)

function SMG1.MessageInfoValue:getAddress()
  return self.game.addrs.messageInfoPointer + self.offset
end

function SMG1.MessageInfoValue:isValid()
  return self.game.addrs.messageInfoPointer ~= nil
end



-- General-interest state values.

GV.generalState1a = MV(
  "State bits 01-08", -0x128, SMG1.PosBlockValue, BinaryType,
  {binarySize=8, binaryStartBit=7}
)
GV.generalState1b = MV(
  "State bits 09-16", -0x127, SMG1.PosBlockValue, BinaryType,
  {binarySize=8, binaryStartBit=7}
)
GV.generalState1c = MV(
  "State bits 17-24", -0x126, SMG1.PosBlockValue, BinaryType,
  {binarySize=8, binaryStartBit=7}
)
GV.generalState1d = MV(
  "State bits 25-32", -0x125, SMG1.PosBlockValue, BinaryType,
  {binarySize=8, binaryStartBit=7}
)
function SMG1:onGround()
  return (self.generalState1a:get()[2] == 1)
end



-- Unlike SMG2, SMG1 does not exactly have an in-game timer. However, this
-- address seems to be the next best thing.
-- It counts up by 1 per frame starting from the level-beginning cutscenes.
-- It also pauses for a few frames when you get the star.
-- It resets to 0 if you die.
GV.stageTimeFrames =
  MV("Stage time, frames", 0x9ADE58, SMG1.StaticValue, IntType)



-- Position, velocity, and other coordinates related stuff.
GV.pos = V(
  Vector3Value,
  MV("Pos X", 0x0, SMG1.PosBlockValue, FloatType),
  MV("Pos Y", 0x4, SMG1.PosBlockValue, FloatType),
  MV("Pos Z", 0x8, SMG1.PosBlockValue, FloatType)
)
GV.pos.label = "Position"
GV.pos.displayDefaults = {signed=true, beforeDecimal=5, afterDecimal=1}

GV.pos_early1 = V(
  Vector3Value,
  MV("Pos X", 0x18DC, SMG1.RefValue, FloatType),
  MV("Pos Y", 0x18E0, SMG1.RefValue, FloatType),
  MV("Pos Z", 0x18E4, SMG1.RefValue, FloatType)
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
  MV("Base Vel X", 0x78, SMG1.PosBlockValue, FloatType),
  MV("Base Vel Y", 0x7C, SMG1.PosBlockValue, FloatType),
  MV("Base Vel Z", 0x80, SMG1.PosBlockValue, FloatType)
)
GV.baseVel.label = "Base Vel"
GV.baseVel.displayDefaults = {signed=true}


-- Mario/Luigi's direction of gravity.
GV.upVectorGravity = V(
  Vector3Value,
  MV("Up X", 0x6A3C, SMG1.RefValue, FloatType),
  MV("Up Y", 0x6A40, SMG1.RefValue, FloatType),
  MV("Up Z", 0x6A44, SMG1.RefValue, FloatType)
)
GV.upVectorGravity.label = "Grav (Up)"
GV.upVectorGravity.displayDefaults =
  {signed=true, beforeDecimal=1, afterDecimal=4}

GV.downVectorGravity = V(
  Vector3Value,
  MV("Up X", 0x1B10, SMG1.RefValue, FloatType),
  MV("Up Y", 0x1B14, SMG1.RefValue, FloatType),
  MV("Up Z", 0x1B18, SMG1.RefValue, FloatType)
)
GV.downVectorGravity.label = "Grav (Down)"
GV.downVectorGravity.displayDefaults =
  {signed=true, beforeDecimal=1, afterDecimal=4}

-- Up vector (tilt). Offset from the gravity up vector when there is tilt.
GV.upVectorTilt = V(
  Vector3Value,
  MV("Up X", 0xC0, SMG1.PosBlockValue, FloatType),
  MV("Up Y", 0xC4, SMG1.PosBlockValue, FloatType),
  MV("Up Z", 0xC8, SMG1.PosBlockValue, FloatType)
)
GV.upVectorTilt.label = "Tilt (Up)"
GV.upVectorTilt.displayDefaults =
  {signed=true, beforeDecimal=1, afterDecimal=4}



-- Inputs and spin state.

GV.buttons1 = MV("Buttons 1", 0x61D342, SMG1.StaticValue, BinaryType,
  {binarySize=8, binaryStartBit=7})
GV.buttons2 = MV("Buttons 2", 0x61D343, SMG1.StaticValue, BinaryType,
  {binarySize=8, binaryStartBit=7})

GV.wiimoteShakeBit =
  MV("Wiimote shake bit", 0x27F0, SMG1.RefValue, ByteType)
GV.nunchukShakeBit =
  MV("Nunchuk shake bit", 0x27F1, SMG1.RefValue, ByteType)
GV.spinCooldownTimer =
  MV("Spin cooldown timer", 0x2217, SMG1.RefValue, ByteType)
GV.spinAttackTimer =
  MV("Spin attack timer", 0x2214, SMG1.RefValue, ByteType)
-- When this timer is inactive, its value is 180
GV.midairSpinTimer =
  MV("Midair spin timer", 0x41BF, SMG1.RefValue, ByteType)
GV.midairSpinType =
  MV("Midair spin state", 0x41E7, SMG1.RefValue, ByteType)

GV.stickX = MV("Stick X", 0x61D3A0, SMG1.StaticValue, FloatType)
GV.stickY = MV("Stick Y", 0x61D3A4, SMG1.StaticValue, FloatType)



-- Some other stuff.

-- Jump, double jump or rainbow star jump, triple jump,
-- bonk or forward facing slope jump, sideflip, long jump, backflip, wall jump,
-- midair spin, ?, ledge hop, spring topman bounce, enemy bounce,
-- jump off swing / pull star release / after planet landing / spin out of water
GV.lastJumpType =
  MV("Last jump type", 0x41EF, SMG1.RefValue, ByteType)
-- Not quite sure what this is
GV.groundTurnTimer =
  MV("Ground turn timer", 0x41CB, SMG1.RefValue, ByteType)



-- Text.

GV.textProgress =
  MV("Text progress", 0x2D39C, SMG1.MessageInfoValue, IntType)
GV.alphaReq =
  MV("Alpha req", 0x2D3B0, SMG1.MessageInfoValue, FloatType)
GV.fadeRate =
  MV("Fade rate", 0x2D3B4, SMG1.MessageInfoValue, FloatType)


return SMG1
