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
function layouts.frameCounterTest:init(window, game)
  self:setBreakpointUpdateMethod()

  self.windowSize = {300, 100}
  
  self:addLabel{
    x=margin, y=margin, fontSize=fontSize, fontName=fixedWidthFontName}
  self:addItem(game:F(
    function()
      return "Frame count: "..tonumber(self.game:getFrameCount())
    end
  ))
  
  Layout.init(self, window, game)
end

return {
  layouts = layouts,
}
