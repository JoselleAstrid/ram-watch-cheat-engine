-- New Super Marisa Land (Ver 1.10, which has the Extra levels)



-- Imports.

-- First make sure that the imported modules get de-cached as needed. That way,
-- if we change the code in those modules and then re-run the script, we won't
-- need to restart Cheat Engine to see the code changes take effect.

package.loaded.utils = nil
local utils = require 'utils'
local readIntLE = utils.readIntLE
local subclass = utils.subclass

package.loaded.game = nil
local gameModule = require 'game'

package.loaded.valuetypes = nil
local valuetypes = require 'valuetypes'
local V = valuetypes.V
local MV = valuetypes.MV
local Block = valuetypes.Block
local Value = valuetypes.Value
local MemoryValue = valuetypes.MemoryValue
local FloatType = valuetypes.FloatTypeLE
local IntType = valuetypes.IntTypeLE
local ShortType = valuetypes.ShortTypeLE
local ByteType = valuetypes.ByteType
local SignedIntType = valuetypes.SignedIntTypeLE
local SignedShortType = valuetypes.SignedShortTypeLE
local SignedByteType = valuetypes.SignedByteType
local StringType = valuetypes.StringType
local BinaryType = valuetypes.BinaryType



local NSML = subclass(gameModule.Game)
NSML.exeName = '6kinoko.exe'
NSML.framerate = 60

NSML.layoutModuleNames = {'newsupermarisaland_layouts'}

function NSML:init(options)
  gameModule.Game.init(self, options)
  
  self.addrs = {}
  self:initConstantAddresses()
end

local GV = NSML.blockValues



function NSML:initConstantAddresses()
  self.addrs.o = getAddress(self.exeName)
  
  -- Static value that increases by 1 once per frame.
  self.frameCounterAddress = self.addrs.o + 0x11B750
  -- Static instruction that runs once per frame. (This is just the
  -- instruction that updates the above)
  self.oncePerFrameAddress = self.addrs.o + 0xE0F3
end



-- These addresses can change more frequently, so we specify them as
-- functions that can be run continually.

function NSML:updateRefPointer()
  -- Not sure what this is meant to point to exactly, but when this pointer
  -- changes value, many other relevant addresses (like the settings
  -- slider value) move by the same amount as the value change.
  self.addrs.refPointer = readIntLE(self.addrs.o + 0x114424, 4)
end

function NSML:updateMarisaSpriteAddress()
  -- Not sure if this is actually the sprite count. It generally goes
  -- up/down along with sprite creation and erasure. But it could be the
  -- index of a particular sprite.
  self.spriteCount = readIntLE(self.addrs.o + 0x114354, 4)
  self.addrs.spritePtrArrayStart = readIntLE(self.addrs.o + 0x114344, 4)
  
  if self.spriteCount < 2 then
    -- There is no Marisa sprite (see below), and no valid sprite in the
    -- location where we'd normally look.
    -- Possible situations: transitioning from an empty room like in
    -- Hakurei Shrine, entering a level, or exiting to the title screen.
    self.addrs.marisaSprite = nil
    return
  end
  
  -- Marisa's sprite seems to be the second to last sprite most of the time.
  -- TODO: Cover the cases where it's not. Only example so far is the start of
  -- 7-4, after walking right a bit to see the cactus-holding fairies.
  local arrayOffset = (self.spriteCount - 2) * 4
  self.addrs.marisaSprite =
    readIntLE(self.addrs.spritePtrArrayStart + arrayOffset, 4)
end

function NSML:updateAddresses()
  self:updateRefPointer()
  self:updateMarisaSpriteAddress()
end



-- Values that don't exist if Marisa's sprite doesn't exist.
local MarisaValue = {}
NSML.MarisaValue = MarisaValue

function MarisaValue:isValid()
  local valid = (self.game.addrs.marisaSprite ~= nil)
  if not valid then self.invalidDisplay = "<No Marisa sprite>" end
  return valid
end



-- Memory values at static addresses (from the beginning of the game memory).
local StaticValue = subclass(MemoryValue)
NSML.StaticValue = StaticValue

function StaticValue:getAddress()
  return self.game.addrs.o + self.offset
end



-- Memory values that are a constant offset from the refPointer.
local RefValue = subclass(MemoryValue)
NSML.RefValue = RefValue

function RefValue:getAddress()
  return self.game.addrs.refPointer + self.offset
end



-- Memory values that are a constant offset from Marisa's sprite start.
local MarisaStateValue = subclass(MemoryValue, MarisaValue)
NSML.MarisaStateValue = MarisaStateValue

function MarisaStateValue:getAddress()
  return self.game.addrs.marisaSprite + self.offset
end



GV.posX = MV("Pos X", 0xF0, MarisaStateValue, FloatType)
GV.posY = MV("Pos Y", 0xF4, MarisaStateValue, FloatType)
GV.posX.displayDefaults = {signed=false, beforeDecimal=4, afterDecimal=2}
GV.posY.displayDefaults = {signed=false, beforeDecimal=4, afterDecimal=2}

GV.velX = MV("Vel X", 0x100, MarisaStateValue, FloatType)
GV.velY = MV("Vel Y", 0x104, MarisaStateValue, FloatType)
GV.velX.displayDefaults = {signed=true, beforeDecimal=2, afterDecimal=2}
GV.velY.displayDefaults = {signed=true, beforeDecimal=2, afterDecimal=2}


GV.pos = V(subclass(Value, MarisaValue))
GV.pos.label = "Pos"
function GV.pos:updateValue()
  self.game.posX:update()
  self.game.posY:update()
end
function GV.pos:displayValue(options)
  return (
    self.game.posX:display({nolabel=true}, options)
    ..", "..self.game.posY:display({nolabel=true}, options)
  )
end


-- TODO: This pointer doesn't work. Find a working one.
-- GV.timerTicks = MV("Timer ticks", 0x194404, RefValue, IntType)
-- TODO: This pointer doesn't work. Find a working one.
-- TODO: Divide by 2 to get frames in 60 FPS; otherwise it's in 120 FPS
-- GV.timerFrames = MV("Timer frames", 0x3AA8C, RefValue, IntType)

-- GV.timer = V(Value)
-- GV.timer.label = "Timer"
-- function GV.timer:displayValue(options)
--   local totalFrames = self.game.timerFrames:get()
--   local ticks = (totalFrames - (totalFrames % 30)) / 30
--   local frames = totalFrames % 30
--   return string.format("%dT %02dF", ticks, frames)
-- end


return NSML

