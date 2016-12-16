package.loaded.utils = nil
local utils = require 'utils'
local subclass = utils.subclass

package.loaded.layouts = nil
local layoutsModule = require 'layouts'
local Layout = layoutsModule.Layout


local layouts = {}

local margin = 6
local fontSize = 12
-- alt: Lucida Console
local fixedWidthFontName = "Consolas"
-- Cheat Engine uses blue-green-red order for some reason
local inputColor = 0x880000



layouts.addressTest = subclass(Layout)
function layouts.addressTest:init()
  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(5)

  self.window:setSize(400, 300)

  self:addLabel{fontSize=fontSize, fontName=fixedWidthFontName}
  self:addItem(
    function()
      local names = {
        'o', 'refPointer', 'spritePtrArrayStart', 'marisaSprite',
      }
      local lines = {}
      for _, name in pairs(names) do
        table.insert(
          lines, name..": "..utils.intToHexStr(game.addrs[name]))
      end
      return table.concat(lines, '\n')
    end
  )
end


layouts.posVel = subclass(Layout)
function layouts.posVel:init()
  local game = self.game
  self.margin = margin
  self:setUpdatesPerSecond(60)

  self.window:setSize(400, 200)

  self:addLabel{fontSize=fontSize, fontName=fixedWidthFontName}
  self:addItem(game.pos)
  self:addItem(game.velX)
  self:addItem(game.velY)
  self:addItem(
    function() return "Frame count: "..tostring(game:getFrameCount()) end)
end



return {
  layouts = layouts,
}

