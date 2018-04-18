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

--function MyGame:updateAddresses()
--  local pointerAddress = self.startAddress + 0x7a8240
--  if pointerAddress == 0 then
--	self.pointerValue = nil
--  else
--	self.pointerValue = self.startAddress + utils.readIntBE(pointerAddress) - 0x80000000
--  end
--end


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

local PointerBasedValue = subclass(valuetypes.MemoryValue)
function PointerBasedValue:getAddress()
  return self.game.pointerValue + self.offset
end

-- Game addresses

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

GV.xSpd = MV(
  "XSpd", 0xC5D660, StaticValue, FloatType)
GV.ySpd = MV(
  "YSpd", 0xC5D664, StaticValue, FloatType)
GV.zSpd = MV(
  "ZSpd", 0xC5D668, StaticValue, FloatType)

GV.xRot = MV(
  "XRot", 0xC5D5A8, StaticValue, IntType)
GV.yRot = MV(
  "YRot", 0xC5D5AC, StaticValue, IntType)
GV.zRot = MV(
  "ZRot", 0xC5D5B0, StaticValue, IntType)

GV.hover = MV(
  "HoverTimer", 0xC5D6D0, StaticValue, IntType)


-- Hunting stages - offset = 0x260

GV.hstSpeed = MV(
  "StSpeed", 0xC5D960, StaticValue, FloatType)
GV.hfSpeed = MV(
  "FSpeed", 0xC5D984, StaticValue, FloatType)
GV.hvSpeed = MV(
  "VSpeed", 0xC5D988, StaticValue, FloatType)

GV.hxPos = MV(
  "XPos", 0xC5D814, StaticValue, FloatType)
GV.hyPos = MV(
  "YPos", 0xC5D818, StaticValue, FloatType)
GV.hzPos = MV(
  "ZPos", 0xC5D81C, StaticValue, FloatType)

GV.hxSpd = MV(
  "XSpd", 0xC5D8C0, StaticValue, FloatType)
GV.hySpd = MV(
  "YSpd", 0xC5D8C4, StaticValue, FloatType)
GV.hzSpd = MV(
  "ZSpd", 0xC5D8C8, StaticValue, FloatType)

GV.hxRot = MV(
  "XRot", 0xC5D808, StaticValue, IntType)
GV.hyRot = MV(
  "YRot", 0xC5D80C, StaticValue, IntType)
GV.hzRot = MV(
  "ZRot", 0xC5D810, StaticValue, IntType)

GV.hhover = MV(
  "HoverTimer", 0xC5D930, StaticValue, IntType)

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

-- Time

GV.frameCounter =
  MV("Frames Counter", 0x3AD858, StaticValue, IntType)
GV.centiseconds =
  MV("Centiseconds", 0x1B3DAF, StaticValue, ByteType)
GV.seconds =
  MV("Seconds", 0x1B3D6F, StaticValue, ByteType)
GV.minutes =
  MV("Minutes", 0x1B3D2F, StaticValue, ByteType)

function MyGame:displaySpeed()
  local stspd = self.stSpeed:get()
  local fspd = self.fSpeed:get()
  local vspd = self.vSpeed:get()
  local xspd = self.xSpd:get()
  local yspd = self.ySpd:get()
  local zspd = self.zSpd:get()
  return string.format("Speed\n  S: %f\n  F: %f\n  V: %f\n  X: %f\n  Y: %f\n  Z: %f", stspd, fspd, vspd, xspd, yspd, zspd)
end

function MyGame:displayhSpeed()
  local stspd = self.hstSpeed:get()
  local fspd = self.hfSpeed:get()
  local vspd = self.hvSpeed:get()
  local xspd = self.hxSpd:get()
  local yspd = self.hySpd:get()
  local zspd = self.hzSpd:get()
  return string.format("Speed\n  S: %f\n  F: %f\n  V: %f\n  X: %f\n  Y: %f\n  Z: %f", stspd, fspd, vspd, xspd, yspd, zspd)
end

function MyGame:displayRotation()
  local xrot = self.xRot:get()
  local yrot = self.yRot:get()
  local zrot = self.zRot:get()
  return string.format("Rotation\n  X: %d\n  Y: %d\n  Z: %d", xrot, yrot, zrot)
end

function MyGame:displayhRotation()
  local xrot = self.hxRot:get()
  local yrot = self.hyRot:get()
  local zrot = self.hzRot:get()
  return string.format("Rotation\n  X: %d\n  Y: %d\n  Z: %d", xrot, yrot, zrot)
end

function MyGame:displayPosition()
  local xpos = self.xPos:get()
  local ypos = self.yPos:get()
  local zpos = self.zPos:get()
  return string.format("Position\n  X: %f\n  Y: %f\n  Z: %f", xpos, ypos, zpos)
end

function MyGame:displayhPosition()
  local xpos = self.hxPos:get()
  local ypos = self.hyPos:get()
  local zpos = self.hzPos:get()
  return string.format("Position\n  X: %f\n  Y: %f\n  Z: %f", xpos, ypos, zpos)
end

function MyGame:displayTime()
  local address = 0x013458A8
  local frames = self.frameCounter:get()
  local centi = self.centiseconds:get()
  local sec = self.seconds:get()
  local minu = self.minutes:get()
  return string.format("  %02d:%02d:%02d | %d | %d\n", minu, sec, centi, frames, utils.readIntLE(address))
end

function MyGame:displayMisc()
  local hvr = self.hover:get()
  return string.format("Misc\n  Hover: %d\n", hvr)
end

function MyGame:displayhMisc()
  local hvr = self.hhover:get()
  return string.format("Misc\n  Hover: %d\n", hvr)
end

function MyGame:displayAnalogPosition()
  local xstick = self.stickX:get()
  local ystick = self.stickY:get()
  return string.format(" %3d, %d", xstick, ystick)
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
  elseif button == "<" then value = self.DZ:get()[8]
  elseif button == ">" then value = self.DZ:get()[7]
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
  options.square = options.square or false

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