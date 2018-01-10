package.loaded.utils = nil
local utils = require 'utils'
local subclass = utils.subclass

package.loaded.dolphin = nil
local dolphin = require 'dolphin'

local MyGame = subclass(dolphin.DolphinGame)

MyGame.supportedGameVersions = {
  na = 'GSNE8P',
}

MyGame.layoutModuleNames = {'sonicadventure2battle_layouts'}
MyGame.framerate = 60

function MyGame:init(options)
  dolphin.DolphinGame.init(self, options)

  self.startAddress = self:getGameStartAddress()
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
local BinaryType = valuetypes.BinaryType

package.loaded.layouts = nil
local layoutsModule = require 'layouts'

local StaticValue = subclass(valuetypes.MemoryValue)
function StaticValue:getAddress()
  return self.game.startAddress + self.offset
end

-- Game addresses

GV.facingAngle = MV("Facing Angle", 0xC5D5AC, StaticValue, IntType)

GV.stSpeed = MV(
  "StSpeed", 0xC5D704, StaticValue, FloatType)
GV.fSpeed = MV(
  "FSpeed", 0xC5D724, StaticValue, FloatType)
GV.vSpeed = MV(
  "VSpeed", 0xC5D728, StaticValue, FloatType)
GV.xPos = MV(
  "XPos", 0xC5D5B4, StaticValue, FloatType)
GV.yPos = MV(
  "YPos", 0xC5D5B8, StaticValue, FloatType)
GV.zPos = MV(
  "ZPos", 0xC5D5BC, StaticValue, FloatType)

  
-- Inputs

GV.ABXYS = MV("ABXY & Start", 0x2BAB78,
  StaticValue, BinaryType, {binarySize=8, binaryStartBit=7})
GV.DZ = MV("D-Pad & Z", 0x2BAB79,
  StaticValue, BinaryType, {binarySize=8, binaryStartBit=7})
  
GV.stickX =
  MV("X Stick", 0x2BAB7A, StaticValue, ByteType)
GV.stickY =
  MV("Y Stick", 0x2BAB7B, StaticValue, ByteType)
GV.xCStick =
  MV("X C-Stick", 0x2BAB7C, StaticValue, ByteType)
GV.yCStick =
  MV("Y C-Stick", 0x2BAB7D, StaticValue, ByteType)
GV.lShoulder =
  MV("L Shoulder", 0x2BAB7E, StaticValue, ByteType)
GV.rShoulder =
  MV("R Shoulder", 0x2BAB7F, StaticValue, ByteType)

function MyGame:displaySpeed()
  local stspd = self.stSpeed:get()
  local fspd = self.fSpeed:get()
  local vspd = self.vSpeed:get()
  return string.format("Speed\n St: %f\n F: %f\n V: %f", stspd, fspd, vspd)
end

function MyGame:displayRotation()
  local yrot = self.facingAngle:get()
  return string.format("Rotation\n Y: %d", yrot)
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