-- Layouts to use with metroidprime.lua.

package.loaded.utils = nil
local utils = require 'utils'
local subclass = utils.subclass

package.loaded.layouts = nil
local layoutsModule = require 'layouts'
local Layout = layoutsModule.Layout



local layouts = {}


layouts.positionAndVelocity = subclass(Layout)
function layouts.positionAndVelocity:init()
  self:setUpdatesPerSecond(30)

  self.window:setSize(400, 200)

  self:addLabel{x=6, y=6, fontSize=12, fontName="Consolas"}
  self:addItem(self.game.posX)
  self:addItem(self.game.posY)
  self:addItem(self.game.posZ)
  self:addItem(self.game.velX)
  self:addItem(self.game.velY)
  self:addItem(self.game.velZ)
end


layouts.displayExamples = subclass(Layout)
function layouts.displayExamples:init()
  self:setUpdatesPerSecond(30)
  -- Let's have multiple labels which are spaced vertically across the window
  -- automatically.
  self:activateAutoPositioningY()

  self.window:setSize(400, 250)
  self.labelDefaults = {fontSize=12, fontName="Consolas"}

  self:addLabel()
  -- You can specify display options.
  self:addItem(self.game.posX, {afterDecimal=5, beforeDecimal=5, signed=true})
  -- Display a Vector3Value.
  self:addItem(self.game.pos, {narrow=true})

  self:addLabel()
  -- addItem() can take a string constant.
  self:addItem("----------")

  self:addLabel()
  -- addItem() can take a function that returns a string.
  self:addItem(
    function()
      local vx = self.game.velX:get()
      local vy = self.game.velY:get()
      local speedXY = math.sqrt(vx*vx + vy*vy)
      return "Speed XY: "..utils.floatToStr(speedXY)
    end
  )
end


layouts.positionRecording = subclass(Layout)
function layouts.positionRecording:init()
  -- This update method ensures that we record every frame, but this may incur
  -- a performance hit. If you want performance and it's OK to miss frames,
  -- use setUpdatesPerSecond() instead.
  self:setBreakpointUpdateMethod()

  self:activateAutoPositioningY()

  self.window:setSize(400, 160)
  self.labelDefaults = {fontSize=12, fontName="Consolas"}

  -- Display position.
  self:addLabel()
  self:addItem(self.game.posX)
  self:addItem(self.game.posY)
  self:addItem(self.game.posZ)

  local tabSeparatedPosition = function()
    local positionComponents = {
      self.game.posX:display{afterDecimal=8, nolabel=true},
      self.game.posY:display{afterDecimal=8, nolabel=true},
      self.game.posZ:display{afterDecimal=8, nolabel=true},
    }
    return table.concat(positionComponents, '\t')
  end

  -- This adds a GUI element with a button. Click the button to start recording
  -- stats to a file. For every frame of recording, one line is added to
  -- the file.
  --
  -- Look for the output .txt file in:
  -- A. The folder you saved your .CT file
  -- B. The folder with your Cheat Engine installation, if not running from a
  -- saved .CT file
  --
  -- Because we separated the data elements with linebreaks and tabs (\t), we
  -- can easily paste the .txt contents into a spreadsheet for analysis.
  self:addFileWriter(
    tabSeparatedPosition, 'ram_watch_output.txt')
end



return {
  layouts = layouts,
}

