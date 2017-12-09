-- This is a sample script for Metroid Prime.
-- It's simpler and less structured than the other game scripts
-- (F-Zero GX, Super Mario Galaxy, etc.).
-- It's meant to be easier to follow (or at least to imitate) for anyone new
-- to these Lua scripts.



-- Imports.

-- package.loaded.<module> ensures that the module gets de-cached as needed.
-- That way, if we change the code in those modules and then re-run the script,
-- we won't need to restart Cheat Engine to see the code changes take effect.
package.loaded.utils = nil
local utils = require 'utils'
local subclass = utils.subclass

package.loaded.dolphin = nil
local dolphin = require 'dolphin'

package.loaded.valuetypes = nil
local valuetypes = require "valuetypes"
local V = valuetypes.V
local MV = valuetypes.MV
local MemoryValue = valuetypes.MemoryValue
local FloatType = valuetypes.FloatTypeBE
local Vector3Value = valuetypes.Vector3Value



local MP1 = subclass(dolphin.DolphinGame)

MP1.supportedGameVersions = {
  -- Only revision 0-00 has been tested.
  -- http://www.metroid2002.com/version_differences_version_number.php
  na_0_00 = 'GM8E01',
  us_0_00 = 'GM8E01',
}

-- Layouts specific to this game module can be found in metroidprime_layouts.lua.
MP1.layoutModuleNames = {'metroidprime_layouts'}
-- This game runs at 60 frames per second. A few layouts and functions need
-- to know the framerate for their calculations.
MP1.framerate = 60

function MP1:init(options)
  dolphin.DolphinGame.init(self, options)

  self.addrs = {}
  self:initConstantAddresses()
end



-- These are addresses that should stay constant for the most part,
-- as long as the game start address is constant.
function MP1:initConstantAddresses()
  self.addrs.o = self:getGameStartAddress()
end

-- If there are any addresses that can change during the game, calculate
-- them in this function, which will be called on every frame.
function MP1:updateAddresses()
  -- We don't have any dynamic addresses for this game yet,
  -- so we'll just do nothing here.
end



-- Values at static addresses (from the beginning of the game memory).
MP1.StaticValue = subclass(MemoryValue)

function MP1.StaticValue:getAddress()
  return self.game.addrs.o + self.offset
end



-- Position.
MP1.blockValues.posX = MV("Pos X", 0x46B9BC, MP1.StaticValue, FloatType)
MP1.blockValues.posY = MV("Pos Y", 0x46B9CC, MP1.StaticValue, FloatType)
MP1.blockValues.posZ = MV("Pos Z", 0x46B9DC, MP1.StaticValue, FloatType)

-- Velocity.
MP1.blockValues.velX = MV("Vel X", 0x46BAB4, MP1.StaticValue, FloatType)
MP1.blockValues.velY = MV("Vel Y", 0x46BAB8, MP1.StaticValue, FloatType)
MP1.blockValues.velZ = MV("Vel Z", 0x46BABC, MP1.StaticValue, FloatType)

-- We can also use a Vector3Value to group a set of coordinates together.
MP1.blockValues.pos = V(
  subclass(Vector3Value),
  MP1.blockValues.posX,
  MP1.blockValues.posY,
  MP1.blockValues.posZ
)
MP1.blockValues.pos.label = "Position"


return MP1
