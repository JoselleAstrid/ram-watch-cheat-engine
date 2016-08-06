-- Super Mario Galaxy



-- Imports.

-- First make sure that the imported modules get de-cached as needed. That way,
-- if we change the code in those modules and then re-run the script, we won't
-- need to restart Cheat Engine to see the code changes take effect.
--
-- Make sure this game module de-caches all packages that are used, directly
-- or through another module.
--
-- And don't let other modules do the de-caching, because if any of the loaded
-- modules accept state changes from outside, then having their data cleared
-- multiple times during initialization can mess things up.
package.loaded.utils = nil
package.loaded.utils_math = nil
package.loaded.dolphin = nil
package.loaded.valuetypes = nil
package.loaded.valuedisplay = nil
package.loaded._supermariogalaxyshared = nil

local utils = require "utils"
local utils_math = require "utils_math"
local dolphin = require "dolphin"
local vtypes = require "valuetypes"
local vdisplay = require "valuedisplay"
local SMGshared = require "_supermariogalaxyshared"

local readIntBE = utils.readIntBE
local readFloatBE = utils.readFloatBE
local floatToStr = utils.floatToStr
local initLabel = utils.initLabel
local debugDisp = utils.debugDisp
local StatRecorder = utils.StatRecorder
local copyFields = utils.copyFields
local subclass = utils.subclass

local Vector3 = utils_math.Vector3

local MemoryValue = vtypes.MemoryValue
local FloatValue = vtypes.FloatValue
local IntValue = vtypes.IntValue
local ShortValue = vtypes.ShortValue
local ByteValue = vtypes.ByteValue
local SignedIntValue = vtypes.SignedIntValue
local StringValue = vtypes.StringValue
local BinaryValue = vtypes.BinaryValue
local Vector3Value = vtypes.Vector3Value
local addAddressToList = vtypes.addAddressToList

local ValueDisplay = vdisplay.ValueDisplay



local SMG1 = subclass(SMGshared)

SMG1.layoutModuleNames = {'supermariogalaxy_layouts'}

function SMG1:init(options)
  SMGshared.init(self, options)
  
  if options.gameVersion == 'US' then
    self.gameId = "RMGE01"
    self.refPointerOffset = 0xF8EF88
  elseif options.gameVersion == 'JP' then
    self.gameId = "RMGJ01"
    self.refPointerOffset = 0xF8F328
  elseif options.gameVersion == 'EU' then
    self.gameId = "RMGP01"
    self.refPointerOffset = 0xF8EF88
  else
    error("gameVersion not supported: " .. options.gameVersion)
  end
  
  self.addrs = {}
  self:initConstantAddresses()
  
  for _,obj in pairs(self.vObjects) do
    obj.game = self
  end
end



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
  -- Also, it's invalid during transition screens and before the
  -- title screen.
  self.addrs.refPointer =
    self.addrs.o
    + readIntBE(self.addrs.o + self.refPointerOffset, 4)
    - 0x80000000
end
  
function SMG1:updateMessageInfoPointer()
  -- Pointer that can be used to locate various message/text related info.
  --
  -- This pointer value changes whenever you load a different area.
  self.addrs.messageInfoPointer =
    self.addrs.o + readIntBE(self.addrs.o + 0x9A9240, 4) - 0x80000000
end
  
function SMG1:updatePosBlock()
  self.addrs.posBlock = self.addrs.refPointer + 0x3EEC
end

function SMG1:updateAddresses()
  self:updateRefPointer()
  self:updateMessageInfoPointer()
  self:updatePosBlock()
end



-- SMG1 specific classes and their supporting functions.



SMG1.vObjects = {}
-- Wrapper around vtypes.V() to save the object in a table. Later we'll
-- iterate over this table and add a game attribute to each object. (We
-- can't get the game attribute yet.)
local function V(...)
  local obj = vtypes.V(...)
  table.insert(SMG1.vObjects, obj)
  return obj
end

-- TODO: Check if needed.
-- Here is another idea for a vtypes.V() wrapper, where we would delay the
-- call of vtypes.V() until the initialization of the Game. This may be
-- needed if some V() calls require the game attribute to be set.
--
-- SMG1.VCreationCallables = {}
-- local function V(...)
--   local function createVObj(vArgsTable, game)
--     -- Pass in the V() args as a standard argument list,
--     -- which we can get by using unpack() on the argument table.
--     local obj = vtypes.V(unpack(vArgsTable))
--     obj.game = game
--     return obj
--   end
--   -- Curry in the vtypes.V() args as a table right now.
--   -- Let the caller pass in game.
--   table.insert(SMG1.VCreationCallables, utils.curry(createVObj, {...}))
-- end



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



-- Values that are a constant small offset from the position values' location.
SMG1.PosBlockValue = subclass(MemoryValue)

function SMG1.PosBlockValue:getAddress()
  return self.game.addrs.posBlock + self.offset
end



-- Values that are a constant offset from the messageInfoPointer.
SMG1.MessageInfoValue = subclass(MemoryValue)

function SMG1.MessageInfoValue:getAddress()
  return self.game.addrs.messageInfoPointer + self.offset
end


  
-- Unlike SMG2, SMG1 does not exactly have an in-game timer. However, this
-- address seems to be the next best thing.
-- It counts up by 1 per frame starting from the level-beginning cutscenes.
-- It also pauses for a few frames when you get the star.
-- It resets to 0 if you die.
SMG1.stageTimeFrames =
  V("Stage time, frames", 0x9ADE58, {SMG1.StaticValue, IntValue})



-- Inputs and spin state.

SMG1.buttons1 = V("Buttons 1", 0x61D342, {SMG1.StaticValue, BinaryValue},
  {binarySize=8, binaryStartBit=7})
SMG1.buttons2 = V("Buttons 2", 0x61D343, {SMG1.StaticValue, BinaryValue},
  {binarySize=8, binaryStartBit=7})

SMG1.wiimoteSpinBit = V("Wiimote spin bit", 0x27F0, {SMG1.RefValue, ByteValue})
SMG1.nunchukSpinBit = V("Nunchuk spin bit", 0x27F1, {SMG1.RefValue, ByteValue})
SMG1.spinCooldownTimer =
  V("Spin cooldown timer", 0x2217, {SMG1.RefValue, ByteValue})
SMG1.spinAttackTimer =
  V("Spin attack timer", 0x2214, {SMG1.RefValue, ByteValue})

SMG1.stickX = V("Stick X", 0x61D3A0, {SMG1.StaticValue, FloatValue})
SMG1.stickY = V("Stick Y", 0x61D3A4, {SMG1.StaticValue, FloatValue})



-- General-interest state values.

SMG1.generalState1a = V(
  "State bits 01-08", -0x128, {SMG1.PosBlockValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
SMG1.generalState1b = V(
  "State bits 09-16", -0x127, {SMG1.PosBlockValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
SMG1.generalState1c = V(
  "State bits 17-24", -0x126, {SMG1.PosBlockValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
SMG1.generalState1d = V(
  "State bits 25-32", -0x125, {SMG1.PosBlockValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
function SMG1:onGround()
  return (self.generalState1a:get()[2] == 1)
end
  


-- Position, velocity, and other coordinates related stuff.

SMG1.pos = Vector3Value:new(
  V("Pos X", 0x0, {SMG1.PosBlockValue, FloatValue}),
  V("Pos Y", 0x4, {SMG1.PosBlockValue, FloatValue}),
  V("Pos Z", 0x8, {SMG1.PosBlockValue, FloatValue}),
  "Position"
)
SMG1.pos.displayDefaults = {signed=true, beforeDecimal=5, afterDecimal=1}

SMG1.pos_early1 = Vector3Value:new(
  V("Pos X", 0x18DC, {SMG1.RefValue, FloatValue}),
  V("Pos Y", 0x18E0, {SMG1.RefValue, FloatValue}),
  V("Pos Z", 0x18E4, {SMG1.RefValue, FloatValue}),
  "Position"
)
SMG1.pos_early1.displayDefaults =
  {signed=true, beforeDecimal=5, afterDecimal=1}

-- Mario/Luigi's direction of gravity.
SMG1.upVectorGravity = Vector3Value:new(
  V("Up X", 0x6A3C, {SMG1.RefValue, FloatValue}),
  V("Up Y", 0x6A40, {SMG1.RefValue, FloatValue}),
  V("Up Z", 0x6A44, {SMG1.RefValue, FloatValue}),
  "Grav (Up)"
)
SMG1.upVectorGravity.displayDefaults =
  {signed=true, beforeDecimal=1, afterDecimal=4}

SMG1.downVectorGravity = Vector3Value:new(
  V("Up X", 0x1B10, {SMG1.RefValue, FloatValue}),
  V("Up Y", 0x1B14, {SMG1.RefValue, FloatValue}),
  V("Up Z", 0x1B18, {SMG1.RefValue, FloatValue}),
  "Grav (Down)"
)
SMG1.downVectorGravity.displayDefaults =
  {signed=true, beforeDecimal=1, afterDecimal=4}

-- Up vector (tilt). Offset from the gravity up vector when there is tilt.
SMG1.upVectorTilt = Vector3Value:new(
  V("Up X", 0xC0, {SMG1.PosBlockValue, FloatValue}),
  V("Up Y", 0xC4, {SMG1.PosBlockValue, FloatValue}),
  V("Up Z", 0xC8, {SMG1.PosBlockValue, FloatValue}),
  "Tilt (Up)"
)
SMG1.upVectorTilt.displayDefaults =
  {signed=true, beforeDecimal=1, afterDecimal=4}


-- Velocity directly from a memory value.
-- Not all kinds of movement are covered. For example, launch stars and
-- riding moving platforms aren't accounted for.
--
-- It's usually preferable to use velocity based on position change, because
-- that's more accurate to observable velocity. But this velocity value
-- can still have its uses. For example, this is actually the velocity
-- observed on the NEXT frame, so if we want advance knowledge of the velocity,
-- then we might use this.
SMG1.baseVel = Vector3Value:new(
  V("Base Vel X", 0x78, {SMG1.PosBlockValue, FloatValue}),
  V("Base Vel Y", 0x7C, {SMG1.PosBlockValue, FloatValue}),
  V("Base Vel Z", 0x80, {SMG1.PosBlockValue, FloatValue}),
  "Base Vel"
)
SMG1.baseVel.displayDefaults = {signed=true}



-- Text.

SMG1.textProgress =
  V("Text progress", 0x2D39C, {SMG1.MessageInfoValue, IntValue})
SMG1.alphaReq =
  V("Alpha req", 0x2D3B0, {SMG1.MessageInfoValue, FloatValue})
SMG1.fadeRate =
  V("Fade rate", 0x2D3B4, {SMG1.MessageInfoValue, FloatValue})



return SMG1
