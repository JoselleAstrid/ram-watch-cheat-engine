-- Layouts that aren't game specific.

package.loaded.utils = nil
local utils = require 'utils'
local subclass = utils.subclass

package.loaded.layouts = nil
local layoutsModule = require 'layouts'
local Layout = layoutsModule.Layout


local margin = 6
local fontSize = 12
-- alt: Lucida Console
local fixedWidthFontName = "Consolas"


local layouts = {}

layouts.frameCounterTest = subclass(Layout)
function layouts.frameCounterTest:init()
  local game = self.game
  self.margin = margin
  self:setBreakpointUpdateMethod()

  self.window:setSize(300, 100)

  self:addLabel{fontSize=fontSize, fontName=fixedWidthFontName}
  self:addItem(
    function()
      return "Frame count: "..tonumber(game:getFrameCount())
    end
  )
end

return {
  layouts = layouts,
}
