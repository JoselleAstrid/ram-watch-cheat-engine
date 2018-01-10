package.loaded.utils = nil
local utils = require 'utils'
local subclass = utils.subclass

package.loaded.dolphin = nil
local dolphin = require 'dolphin'

local MyGame = subclass(dolphin.DolphinGame)

MyGame.supportedGameVersions = {
  na = 'GXSE8P',
}

MyGame.layoutModuleNames = {'sonicadventuredx_layouts'}
MyGame.framerate = 60

function MyGame:init(options)
  dolphin.DolphinGame.init(self, options)

  self.startAddress = self:getGameStartAddress()
end

function MyGame:updateAddresses()
  local pointerAddress = self.startAddress + 0x7a8240
  if pointerAddress == 0 then
	self.pointerValue = nil
  else
	self.pointerValue = self.startAddress + utils.readIntBE(pointerAddress) - 0x80000000
  end
end


local valuetypes = require "valuetypes"
local V = valuetypes.V
local GV = MyGame.blockValues
local MV = valuetypes.MV
local Block = valuetypes.Block
local Value = valuetypes.Value
local FloatType = valuetypes.FloatTypeBE
local IntType = valuetypes.IntTypeBE
local ByteType = valuetypes.ByteType
local ShortType = valuetypes.ShortTypeBE
local BinaryType = valuetypes.BinaryType

package.loaded.layouts = nil
local layoutsModule = require 'layouts'

local StaticValue = subclass(valuetypes.MemoryValue)
function StaticValue:getAddress()
  return self.game.startAddress + self.offset
end

local PointerBasedValue = subclass(valuetypes.MemoryValue)
function PointerBasedValue:getAddress()
  return self.game.pointerValue + self.offset
end

-- Game addresses

GV.piece1 = MV("Piece 1", 0x841C5B, StaticValue, ByteType)
GV.piece2 = MV("Piece 2", 0x841C83, StaticValue, ByteType)
GV.piece3 = MV("Piece 3", 0x841CAB, StaticValue, ByteType)
GV.facingAngle = MV("Facing Angle", 0x7E343A, StaticValue, IntType)

GV.xPos = MV(
  "X Position", 0x7E3440, StaticValue, FloatType)
GV.yPos = MV(
  "Y Position", 0x7E3444, StaticValue, FloatType)
GV.zPos = MV(
  "Z Position", 0x7E3448, StaticValue, FloatType)
GV.xRot = MV(
  "X Rotation", 0x7E3436, StaticValue, ShortType)
GV.yRot = MV(
  "Y Rotation", 0x7E343A, StaticValue, ShortType)
GV.zRot = MV(
  "Z Rotation", 0x7E343E, StaticValue, ShortType)
  
GV.stSpeed = MV(
  "StSpeed", 0x0, PointerBasedValue, FloatType)
GV.fSpeed = MV(
  "FSpeed", 0x38, PointerBasedValue, FloatType)
GV.vSpeed = MV(
  "VSpeed", 0x3C, PointerBasedValue, FloatType)
  
-- Inputs

GV.ABXYS = MV("ABXY & Start", 0xA6CE0,
  StaticValue, BinaryType, {binarySize=8, binaryStartBit=7})
GV.DZ = MV("D-Pad & Z", 0xA6CE1,
  StaticValue, BinaryType, {binarySize=8, binaryStartBit=7})
  
GV.stickX =
  MV("X Stick", 0xA6CE2, StaticValue, ByteType)
GV.stickY =
  MV("Y Stick", 0xA6CE3, StaticValue, ByteType)
GV.xCStick =
  MV("X C-Stick", 0xA6CE4, StaticValue, ByteType)
GV.yCStick =
  MV("Y C-Stick", 0xA6CE5, StaticValue, ByteType)
GV.lShoulder =
  MV("L Shoulder", 0xA6CE6, StaticValue, ByteType)
GV.rShoulder =
  MV("R Shoulder", 0xA6CE7, StaticValue, ByteType)

-- Time

GV.centiseconds =
  MV("Centiseconds", 0x74C7AA, StaticValue, ByteType)
GV.seconds =
  MV("Seconds", 0x74C7AB, StaticValue, ByteType)
GV.minutes =
  MV("Minutes", 0x74C7AC, StaticValue, ByteType)
  
function MyGame:displaySpeed()
  local stspd = self.stSpeed:get()
  local fspd = self.fSpeed:get()
  local vspd = self.vSpeed:get()
  return string.format("Speed\n St: %f\n F: %f\n V: %f", stspd, fspd, vspd)
end

function MyGame:displayRotation()
  local xrot = self.xRot:get()
  local yrot = self.yRot:get()
  local zrot = self.zRot:get()
  return string.format("Rotation\n X: %d\n Y: %d\n Z: %d", xrot, yrot, zrot)
end

function MyGame:displayPosition()
  local xpos = self.xPos:get()
  local ypos = self.yPos:get()
  local zpos = self.zPos:get()
  return string.format("Position\n X: %f\n Y: %f\n Z: %f", xpos, ypos, zpos)
end
  
function MyGame:displayInputTime()
  local address = 0x013458A8
  return string.format(" %d", utils.readIntLE(address))
end  

function MyGame:displayTime()
  local centiFrames = self.centiseconds:get()
  local secs = self.seconds:get()
  local mins = self.minutes:get()
  
  local centi = math.floor(centiFrames * (100/60))
  
  return string.format(" %d:%02d.%02d", mins, secs, centi)
end
  
function MyGame:getButton(button)
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
  elseif button == "<" then value = self.DZ:get()[7]
  elseif button == ">" then value = self.DZ:get()[8]
  elseif button == "L" then value = self.DZ:get()[2]
  elseif button == "R" then value = self.DZ:get()[3]
  else error("Button code not recognized: " .. tostring(button))
  end

  return value
end

function MyGame:buttonDisplay(button)
  -- Return the button character ("A", "B" etc.) if the button is pressed,
  -- or a space character " " otherwise.
  local value = self:getButton(button)
  if value == 1 then
    return button
  else
    return " "
  end
end

function MyGame:displayAllButtons()
  local s = ""
  for _, button in pairs{"A", "B", "X", "Y", "S", "Z", "L", "R", "v", "<", ">", "^"} do
    s = s..self:buttonDisplay(button)
  end
  return s
end
  
  
MyGame.ControllerStickImage = subclass(layoutsModule.StickInputImage)
function MyGame.ControllerStickImage:init(window, game, options)
  options = options or {}
  options.max = options.max or 255
  options.min = options.min or 0
  options.square = options.square or true

  layoutsModule.StickInputImage.init(
    self, window,
    game.stickX, game.stickY, options)
end

MyGame.ControllerLRImage = subclass(layoutsModule.AnalogTriggerInputImage)
function MyGame.ControllerLRImage:init(window, game, options)
  options = options or {}
  options.max = options.max or 255

  layoutsModule.AnalogTriggerInputImage.init(
    self, window, game.lShoulder, game.rShoulder, options)
end

return MyGame